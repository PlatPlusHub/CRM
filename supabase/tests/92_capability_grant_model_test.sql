-- pgTAP: RBAC-3 / ADR-0027 -- capability grants are per-USER, not only per-role.
--
-- The owner's requirement is that every capability be independently grantable and revocable for an
-- individual user, that roles remain overridable bundles rather than hard boundaries, and that View
-- and Manage stay separable. This file proves the resolution rule that makes all of that true:
--
--     active DENY (user)  ->  refused, unconditionally
--     active GRANT (user) ->  held
--     role grant          ->  held
--     then, always, the PLAN entitlement gate
--
-- Two things are deliberately proven that a weaker file would skip. First, that granting one
-- capability changes EXACTLY one -- measured as a set difference, not as a spot check, because
-- "it works" and "it changed nothing else" are different claims. Second, that the explainer
-- (`app.effective_permissions`) agrees with the decision function for EVERY permission, so the
-- dashboard can never show an answer the database would not enforce.
create extension if not exists pgtap with schema extensions;

begin;
select plan(26);

insert into auth.users (id, email, email_confirmed_at) values
  ('92000000-0000-0000-0000-0000000000a1','emp@rbac92.test',   now()),
  ('92000000-0000-0000-0000-0000000000a2','owner@rbac92.test', now()),
  ('92000000-0000-0000-0000-0000000000a3','starter@rbac92.test', now());
insert into public.tenants (id, name, slug, status) values
  ('92000000-0000-0000-0000-000000000001','RBAC92','rbac92','active'),
  ('92000000-0000-0000-0000-000000000002','RBAC92 Starter','rbac92-starter','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '92000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '92000000-0000-0000-0000-000000000002', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code='starter';
insert into public.branches (id, tenant_id, name, slug) values
  ('92000000-0000-0000-0000-00000000000a','92000000-0000-0000-0000-000000000001','HQ','rbac92-hq'),
  ('92000000-0000-0000-0000-00000000000b','92000000-0000-0000-0000-000000000002','HQ','rbac92s-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('92000000-0000-0000-0000-0000000000c1','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-00000000000a','sales','Sales'),
  ('92000000-0000-0000-0000-0000000000c2','92000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-00000000000b','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('92000000-0000-0000-0000-000000000011','92000000-0000-0000-0000-000000000001','Emp','emp@rbac92.test',true,'92000000-0000-0000-0000-0000000000a1'),
  ('92000000-0000-0000-0000-000000000012','92000000-0000-0000-0000-000000000001','Owner','owner@rbac92.test',true,'92000000-0000-0000-0000-0000000000a2'),
  ('92000000-0000-0000-0000-000000000013','92000000-0000-0000-0000-000000000002','Starter Owner','starter@rbac92.test',true,'92000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000011','92000000-0000-0000-0000-00000000000a','92000000-0000-0000-0000-0000000000c1',true),
  ('92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000012','92000000-0000-0000-0000-00000000000a','92000000-0000-0000-0000-0000000000c1',true),
  ('92000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000013','92000000-0000-0000-0000-00000000000b','92000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant' from (values
  ('92000000-0000-0000-0000-000000000001'::uuid,'92000000-0000-0000-0000-000000000011'::uuid,'employee'),
  ('92000000-0000-0000-0000-000000000001'::uuid,'92000000-0000-0000-0000-000000000012'::uuid,'owner'),
  ('92000000-0000-0000-0000-000000000002'::uuid,'92000000-0000-0000-0000-000000000013'::uuid,'owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;

insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code, phone) values
  ('92000000-0000-0000-0000-0000000000e1','92000000-0000-0000-0000-000000000001','Nile Air','airline', 1000, 'EGP', '+20 100 000 0001');

-- The baseline is captured AS the actor, so it is that actor's own resolved view rather than a
-- privileged one; the temp table therefore has to be writable by that role.
create temporary table snap(k text) on commit drop;
grant all on snap to authenticated;

-- =============================================================================================
-- 1-3. STRUCTURE, including the two invariants this table must NOT break.
-- =============================================================================================
select is(
  (select count(*)::int from pg_policies where schemaname='public' and tablename='user_permission_grants'),
  3,
  'RBAC-3: user_permission_grants carries per-command policies (read / insert / update), the SPEC-138 shape');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_schema='public' and table_name='user_permission_grants'
      and grantee='authenticated' and privilege_type='DELETE'),
  0,
  '...and NO delete grant -- revocation is is_active=false, so the zero-DELETE invariant and the audit trail both survive');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='app' and p.proname in ('has_permission','effective_permissions','emit_permission_change')
      and array_to_string(p.proconfig,',') like '%search_path=%'),
  3,
  '...and every function this migration touched pins search_path (PostgreSQL function-security guidance)');

-- =============================================================================================
-- 4-6. NO SILENT EXPANSION. With no override rows, an actor resolves EXACTLY their role bundle.
--      This is the assertion that would catch a refactor that accidentally widened anything.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);

insert into snap select permission_key from app.effective_permissions() where effective;

select is(
  (select count(*)::int from public.user_permission_grants),
  0,
  'CONTROL: no per-user override rows exist yet -- the baseline below is the pure role bundle');

select is(
  (select count(*)::int from snap),
  (select count(distinct p.key)::int
     from public.role_permissions rp
     join public.permissions p on p.id = rp.permission_id and p.is_active
     join public.roles r on r.id = rp.role_id and r.code = 'employee'
    where app.plan_allows(p.required_feature_code)),
  'NO EXPANSION: with the table empty the actor holds exactly their role bundle -- the refactor changed resolution, not reach');

select is(
  app.has_permission('MANAGE_SUPPLIER_CREDIT'), false,
  'CONTROL: the employee does NOT hold MANAGE_SUPPLIER_CREDIT by role -- the premise of the grant below');

-- =============================================================================================
-- 7-11. INDIVIDUAL GRANT ADDS A CAPABILITY, AND ONLY THAT ONE.
-- =============================================================================================
reset role;
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000011', p.id, 'grant', 'test'
from public.permissions p where p.key='MANAGE_SUPPLIER_CREDIT';

select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(app.has_permission('MANAGE_SUPPLIER_CREDIT'), true,
  'GRANT: an individual user grant adds a capability their role does not carry');

select is(
  (select coalesce(string_agg(permission_key, ','), '')
     from app.effective_permissions()
    where effective and permission_key not in (select k from snap)),
  'MANAGE_SUPPLIER_CREDIT',
  'ISOLATION: ...and EXACTLY one capability changed -- measured as a set difference, not spot-checked');

select lives_ok(
  $$update public.suppliers set credit_limit_amount = 4444
     where id = '92000000-0000-0000-0000-0000000000e1'$$,
  '...and it is BEHAVIOURAL, not just a flag: the actor can now set a supplier ceiling');

-- Orthogonality in the direction no seeded role can express any more, now that finance_manager holds
-- both. This actor holds MANAGE_SUPPLIER_CREDIT and nothing else supplier-related.
select throws_ok(
  $$update public.suppliers set phone = '+20 100 000 0009'
     where id = '92000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'ORTHOGONAL: MANAGE_SUPPLIER_CREDIT grants NOTHING else -- an ordinary supplier edit is still refused');

select throws_ok(
  $$select credit_limit_amount from public.suppliers where id = '92000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'VIEW vs MANAGE: ...and the actor still cannot READ the ceiling -- Manage did not confer View');

-- =============================================================================================
-- 12-15. DENY OVERRIDES A ROLE BUNDLE -- the "Finance Manager minus Refund Approval" requirement.
-- =============================================================================================
reset role;
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000011', p.id, 'deny', 'test'
from public.permissions p where p.key='CREATE_LEAD';

select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.role_permissions rp
     join public.permissions p on p.id=rp.permission_id and p.key='CREATE_LEAD'
     join public.roles r on r.id=rp.role_id and r.code='employee'),
  1,
  'CONTROL: the employee ROLE genuinely grants CREATE_LEAD -- so the refusal below is the override, not an absence');

select is(app.has_permission('CREATE_LEAD'), false,
  'DENY: an individual deny removes a capability the role bundle grants -- roles are overridable, not hard boundaries');

select is(
  (select coalesce(string_agg(permission_key, ','), '')
     from app.effective_permissions()
    where not effective and permission_key in (select k from snap)),
  'CREATE_LEAD',
  'ISOLATION: ...and exactly one capability was removed');

reset role;
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000011', p.id, 'grant', 'conflicting'
from public.permissions p where p.key='CREATE_LEAD';
select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(app.has_permission('CREATE_LEAD'), false,
  'DENY WINS: with BOTH a grant and a deny live, deny takes precedence -- the settled industry rule (AWS/Azure explicit deny), adopted rather than invented');

-- =============================================================================================
-- 16-18. REVOCATION AND EXPIRY. A capability must be removable, and a lapsed grant must lapse.
-- =============================================================================================
reset role;
update public.user_permission_grants g set is_active = false
from public.permissions p where p.id = g.permission_id and p.key = 'CREATE_LEAD' and g.effect = 'deny';
select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(app.has_permission('CREATE_LEAD'), true,
  'REVOKE: deactivating the deny restores the role bundle -- revocation is is_active=false, not a delete');

reset role;
-- Both bounds move: the `user_permission_grants_period` CHECK refuses ends_at <= starts_at, and it
-- refused the first draft of this very statement. An expired grant is a real period in the past, not
-- an end date before its own beginning.
update public.user_permission_grants g
   set starts_at = now() - interval '2 days', ends_at = now() - interval '1 day'
from public.permissions p where p.id = g.permission_id and p.key = 'MANAGE_SUPPLIER_CREDIT';
select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(app.has_permission('MANAGE_SUPPLIER_CREDIT'), false,
  'EXPIRY: a grant past its ends_at stops applying -- time bounds match user_role_assignments rather than inventing a second lifecycle');

select throws_ok(
  $$update public.suppliers set credit_limit_amount = 5555
     where id = '92000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and the behaviour follows the flag: the ceiling write is refused again');

-- =============================================================================================
-- 19. THE PLAN GATE STILL WINS. A tenant administrator must not be able to grant past a commercial
--     entitlement -- canon 28: "Plan denial overrides user role permission".
-- =============================================================================================
-- First, tenant isolation on the new table itself. The session is still acting as TENANT 1's
-- employee, so `derive_created_by` stamps a tenant-1 actor onto a tenant-2 row -- and the composite
-- FK refuses it. This is TENANT-1's rule holding on a table added years after it, and it is asserted
-- rather than worked around because the first draft of the statement below hit it for real.
reset role;
select throws_ok(
  $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
    select '92000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000013', p.id, 'grant'
    from public.permissions p where p.key='MANAGE_SUPPLIER_CREDIT'$$,
  '23503', null,
  'TENANT ISOLATION: a grant cannot record an actor from another tenant -- the composite created_by FK, not a convention');

select set_config('request.jwt.claims', null, true);
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '92000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000013', p.id, 'grant', 'plan test'
from public.permissions p where p.key='MANAGE_SUPPLIER_CREDIT';
select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select is(app.has_permission('MANAGE_SUPPLIER_CREDIT'), false,
  'PLAN GATE: a per-user grant CANNOT reach past the plan entitlement -- the starter plan disables finance_lite, and the owner of that tenant is still refused');

-- =============================================================================================
-- 20. EXPLAINABILITY AGREES WITH ENFORCEMENT, for every permission. If these ever disagree the
--     dashboard would show an answer the database does not honour.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(
  (select count(*)::int from app.effective_permissions() e
    where e.effective is distinct from app.has_permission(e.permission_key)),
  0,
  'EXPLAINABILITY: app.effective_permissions agrees with app.has_permission for EVERY permission -- the explainer is the decision itemised, not a second opinion');

-- =============================================================================================
-- 21-22. SECURITY. Who may administer capabilities, and can the subject escalate themselves?
-- =============================================================================================
select is(app.has_permission('MANAGE_PERMISSIONS'), false,
  'CONTROL: the employee holds no MANAGE_PERMISSIONS');

select throws_ok(
  $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
    select '92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000011', p.id, 'grant'
    from public.permissions p where p.key='MANAGE_USERS'$$,
  '42501', null,
  'NO SELF-ESCALATION: the subject of a grant cannot write the grant table -- RLS charges MANAGE_PERMISSIONS, so naming yourself in the row buys nothing');

-- =============================================================================================
-- 23-24. PAR-4 DEFECT INJECTION on the decision itself. The deny is what is being proven, so the
--        mutation removes the DENY ROW and the behaviour must flip -- and the row's presence is
--        asserted first, so a mutation that silently did nothing cannot pass as a result.
-- =============================================================================================
reset role;
update public.user_permission_grants g set is_active = true
from public.permissions p where p.id = g.permission_id and p.key = 'CREATE_LEAD' and g.effect = 'deny';

select is(
  (select count(*)::int from public.user_permission_grants g
     join public.permissions p on p.id = g.permission_id
    where p.key = 'CREATE_LEAD' and g.effect = 'deny' and g.is_active),
  1,
  'CONTROL: the deny row is live before the mutation -- the harness is measuring a real row, not an absent one');

savepoint before_mutation;
delete from public.user_permission_grants g
using public.permissions p
where p.id = g.permission_id and p.key = 'CREATE_LEAD' and g.effect = 'deny';

select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(app.has_permission('CREATE_LEAD'), true,
  'MUTATION: remove the deny row and the capability returns -- so the refusal above is this row and this precedence rule, not a coincidence');

reset role;
rollback to savepoint before_mutation;

-- The restore half, and it is not decoration: a `rollback to savepoint` also rolls back pgTAP's own
-- counter, so with the mutation as the LAST assertion `finish()` reported "planned 25 but ran 24"
-- while every assertion had in fact passed. A bookkeeping mismatch that still prints `ok` is exactly
-- the kind of quiet wrongness this suite is built to refuse, so the pair is closed properly instead.
select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(app.has_permission('CREATE_LEAD'), false,
  '...and with the deny row restored the refusal returns -- the pair is what makes the mutation load-bearing');

select * from finish();
rollback;
