-- SPEC-152 / WP-03 -- subscription state governs business writes at the write layer.
--
-- THE DEFECT (live, not merely absent). `app.plan_allows` gated on
--   s.subscription_status_code in ('trial','active','grace_period','read_only')
-- which is inverted at BOTH ends of the owner's ratified rule:
--   * `read_only` was in the allow-list, so a read-only tenant could WRITE;
--   * `suspended` / `expired` / `cancelled` were excluded from a function that gates permissions
--     generally, so those tenants were denied READS -- the opposite of the export guarantee that
--     exists so a lapsed tenant can still inspect and export its own data.
--
-- WHY THE GATE IS NOT IN `has_permission` (measured during alignment, not assumed):
--   57 of 89 write policies call app.has_permission; 32 DO NOT, across 32 distinct tables --
--   including customers, suppliers, passengers, quotation_items, lead_assignments,
--   lead_interactions, conversation_messages, offline_conversions and financial_accounts. A gate
--   inside has_permission would therefore have left most CRM work available to a suspended tenant.
--
-- MECHANISM. One trigger function attached per gated table, following the existing
-- enforce_catalog_codes / enforce_status_transition / enforce_archive_authority precedent. It fires
-- on every write path -- RPC, direct PostgREST DML, and any future client -- regardless of which
-- policy admitted the write, which is the only property that answers "what happens if the intended
-- RPC is not used?". Triggers do not fire on SELECT, so reads remain available as a property of the
-- mechanism rather than something maintained by hand.
--
-- Canon 35 §8 settles the layer without a business decision: it names
-- `subscriptions.subscription_status_code` as the authority for access gating and expressly permits
-- deciding the enforcement layer at implementation. It also flags `tenants.status` as a competing
-- second source -- deliberately NOT used here (it is set by provision_tenant and enforced nowhere;
-- introducing it would create the second gate canon warns against).

-- ---------------------------------------------------------------------------------------------
-- 1. plan_allows returns to its single job: does the PLAN include this feature.
--    Subscription STATE is no longer its concern -- that is the trigger's, below.
-- ---------------------------------------------------------------------------------------------
create or replace function app.plan_allows(p_feature_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select case
        when p_feature_code is null then true
        else coalesce((
            select fe.is_enabled
            from public.subscriptions s
            join public.feature_entitlements fe
              on fe.subscription_plan_id = s.subscription_plan_id
             and fe.feature_code = p_feature_code
            where s.tenant_id = app.current_tenant_id()
            order by s.created_at desc
            limit 1
        ), true)
    end
$$;

-- ---------------------------------------------------------------------------------------------
-- 2. The authority. SECURITY DEFINER because a restricted tenant's user may not hold
--    VIEW_SUBSCRIPTION_STATUS, yet the gate must still be able to read the state.
--    A tenant with NO subscription row is treated as restricted: `provision_tenant` does not create
--    one, so without this an unprovisioned-subscription tenant would fail OPEN through
--    plan_allows' coalesce(..., true). Reads stay available either way.
-- ---------------------------------------------------------------------------------------------
create or replace function app.subscription_allows_write(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce((
        select s.subscription_status_code in ('trial', 'active', 'grace_period')
        from public.subscriptions s
        where s.tenant_id = p_tenant_id
        order by s.created_at desc
        limit 1
    ), false)
$$;

-- PostgreSQL grants EXECUTE to PUBLIC by default; the repository's model is an explicit grant to the
-- intended role and nothing else, guarded by `10_grant_model_test.sql`.
revoke execute on function app.subscription_allows_write(uuid) from public;
grant  execute on function app.subscription_allows_write(uuid) to authenticated;

create or replace function app.enforce_subscription_write_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row    jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
    v_tenant uuid  := (v_row ->> 'tenant_id')::uuid;
    v_status text;
begin
    -- A global/platform row carries no tenant. Nothing to gate.
    if v_tenant is null then
        return case when tg_op = 'DELETE' then old else new end;
    end if;

    if app.subscription_allows_write(v_tenant) then
        return case when tg_op = 'DELETE' then old else new end;
    end if;

    select s.subscription_status_code into v_status
    from public.subscriptions s
    where s.tenant_id = v_tenant
    order by s.created_at desc
    limit 1;

    raise exception
        'subscription state "%" does not permit writes on %.% (reads remain available so the tenant can inspect and export its own data)',
        coalesce(v_status, 'none'), tg_table_schema, tg_table_name
        using errcode = 'insufficient_privilege';
end;
$$;

revoke execute on function app.enforce_subscription_write_gate() from public;

-- ---------------------------------------------------------------------------------------------
-- 3. Attachment. Generated over the tenant-scoped tables rather than listed by hand, so no table
--    can be forgotten; `35_subscription_write_gate_test.sql` asserts the coverage in both
--    directions, which is what keeps the generation honest.
--
--    EXEMPTIONS -- each a deliberate, tested hole, derived from canon and from the owner's own
--    purpose rather than invented:
--
--    subscriptions, subscription_payment_proofs, documents, document_versions, document_links
--        The reactivation path itself. Canon 28: "Tenant users may upload proof but cannot approve
--        their own subscription renewal." Gate these and a lapsed tenant could never get out.
--        `documents` is here for a reason found by TESTING rather than by reading:
--        `subscription_payment_proofs.document_id` is NOT NULL, so uploading proof necessarily
--        creates a `documents` row first. Gating documents would have silently broken the one path
--        out of a suspended subscription -- the exemption list looked complete until the test ran.
--        This is deliberately broader than the reactivation path alone; the narrowing trade-off is
--        acceptable today because document STORAGE does not yet exist (WP-04) so the surface is
--        metadata only, and WP-04 should revisit whether a narrower proof-upload path is warranted.
--    events, security_events
--        The audit spine (already governed by WP-00's record_event) and the auth/security history.
--        A suspended tenant still logs in to read its data, and that must still be recorded.
--    notification_deliveries, usage_counters, offline_conversion_deliveries
--        Platform/system bookkeeping, not tenant business work. Gating the last one would strand an
--        in-flight n8n lease when a tenant lapses mid-delivery, turning a billing state into a
--        stuck integration.
--    users, user_role_assignments, user_branch_assignments, branches, departments
--        Identity and organization administration. `app.provision_tenant` writes users and
--        user_role_assignments BEFORE any subscription exists, so gating them would make a
--        just-provisioned tenant unusable and would turn the still-open trial-plan business
--        decision into a blocker. These already require MANAGE_USERS / MANAGE_BRANCHES /
--        MANAGE_DEPARTMENTS at the table level (SPEC-138), so they are not an open door; the
--        commercial surface a subscription actually pays for is what stays gated.
-- ---------------------------------------------------------------------------------------------
do $$
declare
    r record;
    v_exempt text[] := array[
        'subscriptions', 'subscription_payment_proofs',
        'documents', 'document_versions', 'document_links',
        'events', 'security_events',
        'notification_deliveries', 'usage_counters', 'offline_conversion_deliveries',
        'users', 'user_role_assignments', 'user_branch_assignments',
        'branches', 'departments'
    ];
begin
    for r in
        select c.relname
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        join pg_attribute a on a.attrelid = c.oid and a.attname = 'tenant_id' and a.attnum > 0 and not a.attisdropped
        where n.nspname = 'public'
          and c.relkind = 'r'
          and not (c.relname = any (v_exempt))
        order by c.relname
    loop
        execute format(
            'create trigger %I before insert or update or delete on public.%I
               for each row execute function app.enforce_subscription_write_gate()',
            r.relname || '_enforce_subscription_write_gate', r.relname);
    end loop;
end;
$$;
