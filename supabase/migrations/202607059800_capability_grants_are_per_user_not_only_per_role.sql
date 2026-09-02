-- RBAC-3 -- capability grants become per-USER, not only per-role (OWNER DIRECTIVE, 2026-09-02).
--
-- THE DECISION THIS IMPLEMENTS is recorded as **ADR-0027**. The owner relaxed the standing "do not
-- redesign RBAC" constraint and asked for an evidence-based choice between preserving, refactoring
-- and rebuilding. The answer, from measurement rather than preference, is **REFACTOR THE GRANT
-- MODEL AND PRESERVE THE ENFORCEMENT PLANE**, and the measurement is decisive:
--
--     app.has_permission is resolved by  60 RLS policies
--                                        61 triggers
--                                        76 functions
--     role_permissions is the ONLY foreign key into public.permissions (297 rows, 72 permissions)
--
-- Every enforcement site in ORVION already delegates the decision to one function. So the owner's
-- end-state -- every capability independently grantable and revocable per user -- is a change to how
-- that ONE function RESOLVES a grant, not to how anything ENFORCES it. A rebuild would rewrite 197
-- enforcement sites to reach the same behaviour, and each rewritten site is a chance to lose a rule
-- that was earned by a defect (SEC-1b, SEC-1c, PAR-4, BOOK-1, ADMIN-1, FIN-10). That is maximum risk
-- for zero security gain, and it is why rebuilding was rejected.
--
-- WHAT WAS ACTUALLY MISSING, measured: there is **no path from a user to a permission** except
-- through a role. That is the whole gap. It makes four owner requirements impossible today --
-- per-user grant, per-user revoke, deny, and "role as a bundle you can override" -- and it is closed
-- by one table and one function body.
--
-- CURRENT BEST PRACTICE WAS CHECKED, AND IT AGREES WITH THE EXISTING SHAPE:
--   * Supabase's own RBAC guidance is a `role_permissions` table consulted at query time through a
--     SECURITY DEFINER function used by RLS -- which is exactly what ORVION already has. ORVION is
--     in fact stricter: it resolves the actor from `public.users` rather than a JWT claim, so a
--     revocation takes effect on the next statement with no token staleness. That is why permissions
--     are NOT moved into custom claims here.
--   * PostgreSQL row security is default-deny with no matching policy, and combines PERMISSIVE
--     policies with OR and RESTRICTIVE with AND. ORVION already runs default-deny on 75/75 tables.
--   * Deny-overrides-grant is the settled industry rule (AWS IAM explicit deny, Azure RBAC deny
--     assignments, Azure DevOps group deny). This migration adopts it verbatim rather than inventing
--     precedence: an active deny wins over any grant, role or user.
--   * OWASP prefers ABAC to RBAC for fine-grained logic. ORVION is already a hybrid -- the decision
--     composes role grants with tenant, branch/department/assigned scope, plan entitlement and MFA
--     level -- so the fine-grained requirement is met without a policy engine, which the owner
--     explicitly excluded and which nothing here needs.
--
-- WHAT THIS MIGRATION DOES NOT DO, deliberately: it does not touch a single RLS policy, guard
-- trigger, RPC or grant. The enforcement plane is unchanged and unchallenged, so no existing
-- authorization rule can be lost in the move. It also does not migrate any existing grant: role
-- grants keep working exactly as before, and this table is purely additive. **No privilege is
-- expanded by this migration** -- with the table empty, `has_permission` returns precisely what it
-- returned before, which assertion 1 of the new test pins.

-- =================================================================================================
-- 1. DASHBOARD METADATA on the permission catalog. The owner's dashboard needs to render capabilities
--    grouped, and to separate View from Manage. Both are DERIVED, not invented:
--      * `capability_group` comes from canon 28's own section headings (CRM, Booking, Finance,
--        Documents, Marketing, Organization, Subscription, API) -- a permission's group is the
--        section its matrix row appears in, and 68 of 72 are placed that way.
--      * `action_kind` comes from canon 28's own naming convention: `VIEW_*` is a read gate.
--    Both are DATA, not code, so the owner can regroup or rename from the dashboard without a
--    migration -- which matters, because canon files ASSIGN_SUPPLIER under Booking and
--    MANAGE_SUPPLIER_CREDIT under Finance, while the owner thinks of both as "Supplier Management".
--    That disagreement is a labelling preference and is now the owner's to set, not code's to fix.
-- =================================================================================================
alter table public.permissions
    add column if not exists capability_group text,
    add column if not exists action_kind text not null default 'manage';

alter table public.permissions
    drop constraint if exists permissions_action_kind_check;
alter table public.permissions
    add constraint permissions_action_kind_check check (action_kind in ('view', 'manage'));

update public.permissions set action_kind = 'view' where key like 'VIEW\_%';

do $$
declare r record;
begin
    for r in select * from (values
        ('API',          array['ACCESS_API_FULL','ACCESS_API_READ_ONLY']),
        ('Booking',      array['ALLOW_ISSUE_WITH_NEGATIVE_BALANCE','APPROVE_BOOKING','ASSIGN_SUPPLIER','CANCEL_BOOKING','CREATE_BOOKING','CREATE_BOOKING_ITEM','ENTER_COST','ENTER_SELLING_PRICE','ISSUE_BOOKING','REFUND_BOOKING','REISSUE_BOOKING','UPDATE_BOOKING_ITEM_STATUS']),
        ('CRM',          array['ACCEPT_QUOTATION','ASSIGN_LEAD','ASSIGN_TASK','CLOSE_CONVERSATION','CLOSE_LEAD','COMPLETE_TASK','CREATE_COMPLAINT','CREATE_CUSTOMER','CREATE_LEAD','CREATE_QUOTATION','CREATE_SERVICE_REQUEST','CREATE_TASK','ESCALATE_CONVERSATION','MERGE_CUSTOMER_IDENTITY','REASSIGN_LEAD','RESOLVE_COMPLAINT','RESOLVE_SERVICE_REQUEST','SEND_MESSAGE','SEND_QUOTATION','VIEW_ASSIGNED_LEADS','VIEW_ASSIGNED_TASKS','VIEW_COMPLAINT','VIEW_CONVERSATION','VIEW_DEPARTMENT_QUEUE','VIEW_DEPARTMENT_TASK_QUEUE','VIEW_SERVICE_REQUEST']),
        ('Documents',    array['ARCHIVE_DOCUMENT','CREATE_DOCUMENT_VERSION','UPLOAD_DOCUMENT','VIEW_TRAVEL_DOCUMENTS']),
        ('Finance',      array['APPROVE_FINANCE','CREATE_EXCHANGE_RATE_ADJUSTMENT','CREATE_INVOICE','CREATE_JOURNAL_ENTRY','CREATE_RECEIPT','EDIT_LOCKED_COST','RECORD_PAYMENT','RECORD_REFUND','REVIEW_APPROVAL_REQUEST','SET_EXCHANGE_RATE','VIEW_FINANCIAL_DOCUMENTS','MANAGE_SUPPLIER_CREDIT']),
        ('Marketing',    array['MANAGE_MARKETING_CAMPAIGN','VIEW_MARKETING_DASHBOARD']),
        ('Organization', array['MANAGE_BRANCHES','MANAGE_DEPARTMENTS','MANAGE_PERMISSIONS','MANAGE_ROLES','MANAGE_TENANT_SETTINGS','MANAGE_USERS','VIEW_ALL_BRANCHES','VIEW_BRANCH_DATA']),
        ('Subscription', array['MANAGE_SUBSCRIPTION','REVIEW_SUBSCRIPTION_PAYMENT','VIEW_SUBSCRIPTION_STATUS'])
    ) as t(grp, keys)
    loop
        update public.permissions set capability_group = r.grp where key = any(r.keys);
    end loop;
end $$;

-- ARCHIVE_RECORD, VIEW_ADVANCED_DASHBOARDS and VIEW_DEPARTMENT_RECORDS are LEFT NULL on purpose.
-- Canon 28 places none of them in a permission section: ARCHIVE_RECORD's own description says
-- "documents keep ARCHIVE_DOCUMENT", so filing it under Documents would be wrong; VIEW_DEPARTMENT_
-- RECORDS spans bookings, booking items AND quotations, which canon splits across two sections; and
-- VIEW_ADVANCED_DASHBOARDS appears only in the plan-feature list. Guessing a group for them would be
-- invention, and a NULL group is honest: the dashboard should surface ungrouped capabilities so the
-- owner places them, rather than silently filing them somewhere plausible.

comment on column public.permissions.capability_group is
'Dashboard grouping, derived from canon 28 section headings. DATA not code: the owner may regroup '
'from the administration dashboard without a migration. NULL means canon places the permission in no '
'section -- surface it as ungrouped rather than guessing.';
comment on column public.permissions.action_kind is
'view | manage. Derived from canon 28''s naming convention (VIEW_* is a read gate). Lets the '
'dashboard offer View-only and View+Manage independently for a capability that has both.';

-- =================================================================================================
-- 2. THE MISSING EDGE: user -> permission. Modelled on `user_role_assignments`, which is the
--    repository's own template for an administered identity table (SPEC-138), copied rather than
--    reinvented: same lifecycle columns, same per-command MANAGE_* RLS shape, same grant set.
--
--    `effect` carries grant OR deny in ONE table rather than two, because precedence is a property of
--    the pair and splitting them across tables would let the two disagree about which row is live.
-- =================================================================================================
create table if not exists public.user_permission_grants (
    id            uuid primary key default gen_random_uuid(),
    tenant_id     uuid not null references public.tenants(id) on delete restrict,
    user_id       uuid not null,
    permission_id uuid not null references public.permissions(id) on delete restrict,
    effect        text not null check (effect in ('grant', 'deny')),
    reason        text,
    starts_at     timestamptz not null default now(),
    ends_at       timestamptz,
    is_active     boolean not null default true,
    -- Composite as well: `14_tenant_qualified_fk_test.sql` assertion 1 caught the single-column
    -- version of this the first time it ran, which is TENANT-1's rule enforced by its own guard --
    -- a single-column FK to `users` would let one tenant's row name another tenant's actor. NULL
    -- created_by (the session-less path) still satisfies it under MATCH SIMPLE.
    created_by    uuid,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    -- Composite, per TENANT-1: a single-column FK to `users` would let a grant point at a user in
    -- another tenant. `users_tenant_id_id_key` exists precisely so this can be written.
    constraint user_permission_grants_user_fkey
        foreign key (tenant_id, user_id) references public.users (tenant_id, id) on delete restrict,
    constraint user_permission_grants_created_by_fkey
        -- RESTRICT, not SET NULL: `verify_database.sql` CHECK 7 (the Referential Action Standard)
        -- allows only RESTRICT here, and it caught the SET NULL version. ORVION is archive-oriented
        -- and deletes no users, so restrict is also the honest reading -- an audit row must not
        -- quietly lose the actor who created it.
        foreign key (tenant_id, created_by) references public.users (tenant_id, id) on delete restrict,
    -- One live row per (user, permission, effect). A user may hold at most one grant row and one deny
    -- row for a capability; deny wins, so the pair is meaningful rather than contradictory.
    constraint user_permission_grants_unique unique (tenant_id, user_id, permission_id, effect),
    constraint user_permission_grants_period check (ends_at is null or ends_at > starts_at)
);

create index if not exists user_permission_grants_lookup_idx
    on public.user_permission_grants (tenant_id, user_id, permission_id)
    where is_active;

alter table public.user_permission_grants enable row level security;

-- Read is tenant-wide: a user must be able to see why they hold what they hold, and the dashboard
-- must render the matrix. Writes cost MANAGE_PERMISSIONS -- which canon 28 already defines, which
-- `owner` and `ceo` already hold, and which until now governed nothing at all (RBAC-2's class).
-- This is that permission's first real enforcement, not a new one invented for the purpose.
drop policy if exists scope_read on public.user_permission_grants;
create policy scope_read on public.user_permission_grants for select to authenticated
    using (tenant_id = (select app.current_tenant_id()));

drop policy if exists scope_insert on public.user_permission_grants;
create policy scope_insert on public.user_permission_grants for insert to authenticated
    with check (tenant_id = (select app.current_tenant_id())
                and (select app.has_permission('MANAGE_PERMISSIONS')));

drop policy if exists scope_update on public.user_permission_grants;
create policy scope_update on public.user_permission_grants for update to authenticated
    using (tenant_id = (select app.current_tenant_id())
           and (select app.has_permission('MANAGE_PERMISSIONS')))
    with check (tenant_id = (select app.current_tenant_id())
                and (select app.has_permission('MANAGE_PERMISSIONS')));

-- SELECT/INSERT/UPDATE only. No DELETE grant to `authenticated`, deliberately: this session measured
-- that `authenticated` holds zero DELETE on all 75 tables, and revocation here is `is_active = false`
-- exactly as `revoke_user_role` already works -- which also keeps the audit trail, where a DELETE
-- would destroy it.
grant select, insert, update on public.user_permission_grants to authenticated;
grant all on public.user_permission_grants to service_role;

-- =================================================================================================
-- 3. ACTOR ATTRIBUTION AND AUDIT. Both are the repository's existing patterns.
-- =================================================================================================
drop trigger if exists user_permission_grants_derive_created_by on public.user_permission_grants;
create trigger user_permission_grants_derive_created_by
    before insert or update on public.user_permission_grants
    for each row execute function app.derive_created_by();

drop trigger if exists user_permission_grants_set_updated_at on public.user_permission_grants;
create trigger user_permission_grants_set_updated_at
    before update on public.user_permission_grants
    for each row execute function moddatetime(updated_at);

-- `permission_granted` and `permission_revoked` are ALREADY in the event_type catalog and have had
-- no producer since it was seeded -- EVT-2's class, where registered vocabulary waits for the
-- capability that legitimately emits it. This is that capability; no event type is invented.
create or replace function app.emit_permission_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $FN$
declare
    -- Scalars, not a record: plpgsql binds referenced variables as query parameters before the
    -- statement runs, so reading a field of an unassigned RECORD raises 55000 before any branch can
    -- short-circuit. This is the shape `app.emit_role_change` uses for the same reason.
    v_tenant uuid; v_user uuid; v_perm uuid; v_effect text;
    v_was_live boolean; v_now_live boolean; v_key text;
begin
    if tg_op = 'DELETE' then
        v_tenant := old.tenant_id; v_user := old.user_id; v_perm := old.permission_id;
        v_effect := old.effect;
        v_was_live := old.is_active and (old.ends_at is null or old.ends_at > now());
        v_now_live := false;
    elsif tg_op = 'INSERT' then
        v_tenant := new.tenant_id; v_user := new.user_id; v_perm := new.permission_id;
        v_effect := new.effect;
        v_was_live := false;
        v_now_live := new.is_active and (new.ends_at is null or new.ends_at > now());
    else
        v_tenant := new.tenant_id; v_user := new.user_id; v_perm := new.permission_id;
        v_effect := new.effect;
        v_was_live := old.is_active and (old.ends_at is null or old.ends_at > now());
        v_now_live := new.is_active and (new.ends_at is null or new.ends_at > now());
    end if;

    -- Only a change in EFFECTIVE privilege is an event. An edit to `reason` is not a privilege change
    -- and must not fill the audit spine with noise.
    if v_was_live = v_now_live then
        return null;
    end if;

    select p.key into v_key from public.permissions p where p.id = v_perm;

    perform app.record_event(
        v_tenant,
        case when (v_effect = 'grant') = v_now_live then 'permission_granted' else 'permission_revoked' end,
        'user', v_user,
        (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = v_tenant),
        null, null, null,
        jsonb_build_object('permission_key', v_key, 'effect', v_effect, 'now_live', v_now_live),
        'warning');
    return null;
end;
$FN$;

revoke all on function app.emit_permission_change() from public;

drop trigger if exists user_permission_grants_emit_change on public.user_permission_grants;
create trigger user_permission_grants_emit_change
    after insert or update or delete on public.user_permission_grants
    for each row execute function app.emit_permission_change();

-- =================================================================================================
-- 4. THE ONE FUNCTION THAT CHANGES. Resolution order, and nothing else about ORVION, is what moves:
--
--       active DENY (user)  ->  refused, unconditionally
--       active GRANT (user) ->  held
--       role grant          ->  held
--       then, in every case, the PLAN gate
--
--    Deny is unconditional because that is the settled industry rule and because the weaker reading
--    ("deny only cancels a role grant") cannot express "this user must never have this", which is the
--    owner's requirement 5. The plan gate stays composed LAST for both paths: canon 28 states "Plan
--    denial overrides user role permission", so a tenant administrator must not be able to grant past
--    a commercial entitlement -- the one thing a per-user grant must NOT be able to do.
-- =================================================================================================
create or replace function app.has_permission(p_permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $FN$
    with me as (
        select u.id, u.tenant_id
        from public.users u
        where u.auth_user_id = (select auth.uid())
          and u.is_active
          and u.tenant_id = app.current_tenant_id()
    ),
    perm as (
        select p.id, p.required_feature_code
        from public.permissions p
        where p.key = p_permission_key and p.is_active
    ),
    override as (
        select g.effect
        from public.user_permission_grants g
        join me on me.id = g.user_id and me.tenant_id = g.tenant_id
        join perm on perm.id = g.permission_id
        where g.is_active
          and g.starts_at <= now()
          and (g.ends_at is null or g.ends_at > now())
    )
    select
        -- An active deny ends the question. Checked first and independently of every grant path.
        not exists (select 1 from override where effect = 'deny')
        and (
            exists (select 1 from override where effect = 'grant')
            or exists (
                select 1
                from me
                join public.user_role_assignments ura
                    on ura.user_id = me.id
                   and ura.tenant_id = me.tenant_id
                   and ura.is_active
                   and (ura.ends_at is null or ura.ends_at > now())
                join public.roles r on r.id = ura.role_id and r.is_active
                join public.role_permissions rp on rp.role_id = ura.role_id
                join perm on perm.id = rp.permission_id
            )
        )
        and app.plan_allows((select required_feature_code from perm));
$FN$;

revoke all on function app.has_permission(text) from public;
grant execute on function app.has_permission(text) to authenticated;

comment on function app.has_permission(text) is
'The single authorization decision point: 60 RLS policies, 61 triggers and 76 functions resolve '
'through it. Order is deny-override > per-user grant > role grant, then the plan entitlement gate '
'(canon 28: plan denial overrides user role permission, so a tenant admin cannot grant past a '
'commercial entitlement). ADR-0027.';

-- =================================================================================================
-- 5. EXPLAINABILITY. "Why does this user hold this?" must be answerable without reading SQL, both
--    for the dashboard and for an audit. It reports the same four inputs the decision uses, so it
--    cannot drift into being a second opinion: it is the decision, itemised.
-- =================================================================================================
create or replace function app.effective_permissions(p_user_id uuid default null)
returns table (
    permission_key   text,
    capability_group text,
    action_kind      text,
    from_role        boolean,
    user_grant       boolean,
    user_deny        boolean,
    plan_allows      boolean,
    effective        boolean
)
language sql
stable
security definer
set search_path = ''
as $FN$
    with target as (
        select coalesce(p_user_id, app.current_user_id()) as uid,
               app.current_tenant_id() as tid
    ),
    rows as (
        select p.key as k,
               p.capability_group as g,
               p.action_kind as a,
               exists (select 1
                         from public.user_role_assignments ura
                         join public.roles r on r.id = ura.role_id and r.is_active
                         join public.role_permissions rp
                              on rp.role_id = ura.role_id and rp.permission_id = p.id
                        where ura.user_id = (select uid from target)
                          and ura.tenant_id = (select tid from target)
                          and ura.is_active and (ura.ends_at is null or ura.ends_at > now())) as fr,
               exists (select 1 from public.user_permission_grants ug
                        where ug.user_id = (select uid from target)
                          and ug.tenant_id = (select tid from target)
                          and ug.permission_id = p.id and ug.effect = 'grant' and ug.is_active
                          and ug.starts_at <= now() and (ug.ends_at is null or ug.ends_at > now())) as ugr,
               exists (select 1 from public.user_permission_grants ud
                        where ud.user_id = (select uid from target)
                          and ud.tenant_id = (select tid from target)
                          and ud.permission_id = p.id and ud.effect = 'deny' and ud.is_active
                          and ud.starts_at <= now() and (ud.ends_at is null or ud.ends_at > now())) as udn,
               app.plan_allows(p.required_feature_code) as pa
        from public.permissions p
        where p.is_active
          -- A caller may itemise their OWN permissions freely; itemising someone else's is reading
          -- the tenant's access matrix, which is what MANAGE_PERMISSIONS governs.
          and ((select uid from target) = app.current_user_id()
               or app.has_permission('MANAGE_PERMISSIONS'))
    )
    -- The precedence rule is restated here in exactly the order `has_permission` applies it, and
    -- assertion 11 of the new test proves the two agree for EVERY permission and every actor -- so a
    -- future edit to one that is not made to the other fails a test rather than misleading a reader.
    select k, g, a, fr, ugr, udn, pa,
           (not udn) and (ugr or fr) and pa
    from rows
$FN$;

revoke all on function app.effective_permissions(uuid) from public;
grant execute on function app.effective_permissions(uuid) to authenticated;

-- =================================================================================================
-- 6. THE OWNER'S SUPPLIER DECISION. "The owner is explicitly authorizing Finance Manager access to
--    Supplier Management", and directs that the previous restriction not be preserved merely because
--    the old role lacked ASSIGN_SUPPLIER.
--
--    The real ORVION supplier capabilities, enumerated from the implementation rather than guessed:
--      * ASSIGN_SUPPLIER        -- create/edit a supplier, and link an internal supplier. Measured:
--                                  it gates exactly `app.create_supplier`, `app.link_internal_supplier`
--                                  and the `suppliers` / `internal_supplier_links` table doors, and
--                                  nothing else in the system.
--      * MANAGE_SUPPLIER_CREDIT -- set the credit ceiling (SUP-3, `202607059700`).
--      * VIEW_FINANCIAL_DOCUMENTS -- read the ceiling and the supplier balance.
--    There is NO separate "view supplier" capability: `suppliers` is readable tenant-wide under
--    `tenant_isolation`, so a VIEW_SUPPLIER permission would be a NEW read restriction on every role,
--    not an expression of this decision. It is not invented here.
--
--    Expressed as a ROLE grant rather than a per-user override, deliberately: the owner's decision is
--    about the Finance Manager *role*, and roles are exactly the bundles this architecture keeps.
--    Using the new override table for a whole-role decision would put a role-level fact in the
--    per-user layer -- the duplicated-authority mistake this repository keeps finding.
-- =================================================================================================
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where p.key = 'ASSIGN_SUPPLIER'
  and r.code = 'finance_manager'
on conflict do nothing;
