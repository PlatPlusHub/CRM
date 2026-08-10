-- Migration: fix_customer_identity_merge_event
-- Repository audit (2026-08-10) found app.merge_customer_identity (202607044900) emits event
-- code 'customer_merged', which was never a registered event_type -- canon 27 defines this exact
-- event as 'customer_identity_merged' (Severity: critical). The mismatch was latent until
-- 202607049100 hardened app.record_event to reject unregistered codes; from that point on every
-- call to app.merge_customer_identity aborted with "unknown event_type_code: customer_merged"
-- (reproduced live against a clean db reset). Canon already defines the correct vocabulary, so the
-- RPC is corrected to match canon -- the catalog is not touched. Body is otherwise byte-identical
-- to 202607044900; signature is unchanged so CREATE OR REPLACE preserves the existing grants.
create or replace function app.merge_customer_identity(
    p_source_customer_id uuid,
    p_target_customer_id uuid,
    p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_src_archived boolean;
    r record;
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

    -- ADR-0019: re-point every referrer of customers(id) discovered from the catalogs, except the
    -- merge audit table itself. A new table referencing customers automatically participates; to opt a
    -- referrer out, add it to this exclusion list with a documented reason and handle it explicitly.
    for r in
        select cl.relname as tbl, att.attname as col
        from pg_constraint c
        join pg_class cl on cl.oid = c.conrelid
        join pg_namespace n on n.oid = cl.relnamespace
        join pg_attribute att on att.attrelid = c.conrelid and att.attnum = c.conkey[1]
        where c.contype = 'f'
          and c.confrelid = 'public.customers'::regclass
          and n.nspname = 'public'
          and cl.relname not in ('customer_identity_merges')  -- audit of the merge itself
    loop
        execute format('update public.%I set %I = $1 where %I = $2', r.tbl, r.col, r.col)
            using p_target_customer_id, p_source_customer_id;
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
$$;
