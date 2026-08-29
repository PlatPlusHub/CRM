-- CUST-1 -- `app.merge_customer_identity` archived the source, wrote the audit row, emitted a
-- CRITICAL `customer_identity_merged` event, returned the target id... and re-pointed nothing.
--
-- REPRODUCED, as an `owner` holding MERGE_CUSTOMER_IDENTITY:
--
--     BEFORE  notes  src=1  tgt=0
--     MERGE returned: 3b26956e-...            <- reports success
--     AFTER   notes  src=1  tgt=0             <- NOTHING MOVED
--     source archived: true                    <- the history is now behind an archived customer
--     audit rows: 1        critical events: 1  <- both claim a merge that did not happen
--
-- ROOT CAUSE, and it is a REGRESSION INTRODUCED BY AN EARLIER FIX. The re-pointing loop discovered
-- referrers from `pg_constraint` and took the local column as `c.conkey[1]` -- the FIRST column of
-- the foreign key. That was correct when it was written, because the FKs were single-column
-- `customer_id`. **TENANT-1 (SPEC-128, 2026-08-21) made every tenant-scoped FK composite** --
-- `(tenant_id, customer_id) REFERENCES customers(tenant_id, id)` -- to close a cross-tenant
-- reference hole. From that moment `conkey[1]` was `tenant_id` on all sixteen referrers, and the
-- generated statement became:
--
--     update public.customer_notes set tenant_id = <target CUSTOMER id> where tenant_id = <source CUSTOMER id>
--
-- A tenant id never equals a customer id, so it matched zero rows and failed silently. The merge has
-- been a no-op with a convincing audit trail since 2026-08-21.
--
-- WHY NOTHING CAUGHT IT. The only tests naming this function are
-- `07_event_vocabulary_registry_test` (its event code is registered) and `53_api_surface_test` (the
-- endpoint exists). AUDIT-1/SPEC-120 broke it once before -- an unregistered event code aborted every
-- call -- and the guard added in response verified the VOCABULARY, not the BEHAVIOUR. A guard that
-- checks the name of the event a function emits cannot notice that the function did nothing else.
--
-- ---------------------------------------------------------------------------------------------
-- THE FIX: pair conkey with confkey and take the column that actually references customers.id.
-- ---------------------------------------------------------------------------------------------
-- Position N of `conkey` corresponds to position N of `confkey`, so the local column that references
-- `customers.id` is the one whose partner is `id` -- regardless of how many columns the FK has or
-- what order they are declared in. The same pairing yields the local `tenant_id` partner, which is
-- now used as an extra predicate: this function is SECURITY DEFINER and therefore RLS-blind, so
-- scoping every UPDATE to the verified tenant is defence the previous version did not have.
--
-- It also FAILS CLOSED. If a referrer's FK has no column paired with `customers.id`, the function
-- raises instead of skipping it -- silently skipping a referrer is precisely the failure being
-- fixed, and a merge that half-completes is worse than one that refuses.
--
-- ---------------------------------------------------------------------------------------------
-- AND THE COLLISION THE FIX EXPOSES, which is the normal case rather than an edge case.
-- ---------------------------------------------------------------------------------------------
-- `customer_contact_methods` carries two unique indexes keyed on `customer_id`:
--   * `..._unique_value_idx`        (tenant_id, customer_id, contact_method_type_code, value)
--   * `..._one_primary_per_type_idx`(tenant_id, customer_id, contact_method_type_code) WHERE is_primary
-- Two customers being merged are duplicates OF EACH OTHER -- they will very often share an email or
-- phone, and they will nearly always each have a PRIMARY of the same type. Re-pointing alone would
-- therefore raise a unique violation on the most ordinary merge there is. Making the loop correct
-- without handling this would replace a silent no-op with a loud failure, which is not a fix.
--
-- Two resolutions, and NEITHER invents policy -- both are forced by the schema plus this function's
-- own contract that the TARGET is the surviving identity:
--   1. A source contact method whose (type, value) already exists on the target is DELETED. The
--      value is not lost: it is already on the surviving customer. Keeping it is impossible.
--   2. A source PRIMARY of a type the target already has a primary for is DEMOTED, not discarded.
--      The target's primary wins because the target is the record that survives; the source's value
--      is preserved as a non-primary contact method.

create or replace function app.merge_customer_identity(
    p_source_customer_id uuid,
    p_target_customer_id uuid,
    p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_src_archived boolean;
    r record;
    v_sql text;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('MERGE_CUSTOMER_IDENTITY');

    if p_source_customer_id = p_target_customer_id then
        raise exception 'source and target customer must differ';
    end if;

    -- Both customers must exist in the caller's tenant (DEFINER bypasses RLS, so verify explicitly).
    select is_archived into v_src_archived
    from public.customers where id = p_source_customer_id and tenant_id = v_tenant;
    if not found then
        raise exception 'source customer is not in your tenant';
    end if;
    if v_src_archived then
        raise exception 'source customer is already archived (merged?)';
    end if;
    if not exists (
        select 1 from public.customers where id = p_target_customer_id and tenant_id = v_tenant
    ) then
        raise exception 'target customer is not in your tenant';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- CUST-1 step 1: resolve the contact-method collisions BEFORE re-pointing, or the unique indexes
    -- refuse the merge. See the header -- the target is the surviving identity, so it keeps its
    -- primaries, and a value it already holds is not duplicated onto it.
    delete from public.customer_contact_methods s
     where s.tenant_id = v_tenant
       and s.customer_id = p_source_customer_id
       and exists (
           select 1 from public.customer_contact_methods t
            where t.tenant_id = v_tenant
              and t.customer_id = p_target_customer_id
              and t.contact_method_type_code = s.contact_method_type_code
              and t.value = s.value);

    update public.customer_contact_methods s
       set is_primary = false
     where s.tenant_id = v_tenant
       and s.customer_id = p_source_customer_id
       and s.is_primary
       and exists (
           select 1 from public.customer_contact_methods t
            where t.tenant_id = v_tenant
              and t.customer_id = p_target_customer_id
              and t.contact_method_type_code = s.contact_method_type_code
              and t.is_primary);

    -- ADR-0019: re-point every referrer of customers(id) discovered from the catalogs, except the
    -- merge audit table itself. A new table referencing customers automatically participates; to opt
    -- a referrer out, add it to this exclusion list with a documented reason and handle it explicitly.
    --
    -- CUST-1: the local column is the one PAIRED WITH `customers.id` by ordinal position -- never
    -- the first column of the key, which is what broke (see the header). `tenant_col` is its
    -- partner for `customers.tenant_id`. The old token is deliberately not written here: test 71
    -- asserts its ABSENCE from this body, and a comment quoting it would defeat the assertion.
    for r in
        select cl.relname                                            as tbl,
               max(a.attname) filter (where fa.attname = 'id')        as customer_col,
               max(a.attname) filter (where fa.attname = 'tenant_id') as tenant_col
        from pg_constraint c
        join pg_class cl on cl.oid = c.conrelid
        join pg_namespace n on n.oid = cl.relnamespace
        join unnest(c.conkey)  with ordinality lk(attnum, ord) on true
        join unnest(c.confkey) with ordinality fk(attnum, ord) on fk.ord = lk.ord
        join pg_attribute a  on a.attrelid  = c.conrelid and a.attnum  = lk.attnum
        join pg_attribute fa on fa.attrelid = c.confrelid and fa.attnum = fk.attnum
        where c.contype = 'f'
          and c.confrelid = 'public.customers'::regclass
          and n.nspname = 'public'
          and cl.relname not in ('customer_identity_merges')  -- audit of the merge itself
        group by c.oid, cl.relname
    loop
        -- FAIL CLOSED. Skipping a referrer we cannot resolve is exactly the defect being fixed.
        if r.customer_col is null then
            raise exception
                'merge aborted: the foreign key on public.% has no column referencing customers.id', r.tbl;
        end if;

        v_sql := format('update public.%I set %I = $1 where %I = $2', r.tbl, r.customer_col, r.customer_col);
        if r.tenant_col is not null then
            v_sql := v_sql || format(' and %I = $3', r.tenant_col);
            execute v_sql using p_target_customer_id, p_source_customer_id, v_tenant;
        else
            execute v_sql using p_target_customer_id, p_source_customer_id;
        end if;
    end loop;

    -- Audit record (source, target, performed-by, reason, timestamp) -- complete business traceability.
    insert into public.customer_identity_merges (
        tenant_id, source_customer_id, target_customer_id, merged_by, reason
    )
    values (v_tenant, p_source_customer_id, p_target_customer_id, v_actor, p_reason);

    -- Archive the source (soft; history preserved, never physical delete).
    update public.customers
    set is_archived = true,
        archived_at = now(),
        archived_by = v_actor,
        archive_reason = coalesce(p_reason, 'merged into ' || p_target_customer_id::text),
        updated_at = now()
    where id = p_source_customer_id;

    -- Mandated sensitive event (28). Canon 27 registers this as 'customer_identity_merged',
    -- Severity: critical -- corrected from the unregistered 'customer_merged'/'warning' pair.
    perform app.record_event(
        v_tenant, 'customer_identity_merged', 'customer', p_target_customer_id, v_actor, null, null, p_reason,
        jsonb_build_object('source_customer_id', p_source_customer_id,
                           'target_customer_id', p_target_customer_id),
        'critical'
    );

    return p_target_customer_id;
end;
$fn$;
