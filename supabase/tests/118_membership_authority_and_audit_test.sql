-- pgTAP: SPEC-203 -- USR-1 and USR-2. A membership change costs the same authority, and leaves the
-- same trace, through every door.
--
-- ATTACK-CLASSES: AUTH TENANT DOOR PRIVILEGE STATE INPUT OBSERVABILITY BUSINESS REPLAY=N/A CONCURRENCY=N/A
--
-- Two measured defects, reproduced against the unmodified baseline before a line was written:
--
-- USR-1 -- `public.users` had no emitter at all, the only member of the canon-34
-- identity-and-access family in that position. One actor created a membership, deactivated a
-- colleague and unbound a third human by direct DML and the tenant's event count stayed flat; the
-- same `user_created` fact through `app.create_tenant_user` moved it by one, because that function
-- recorded its own event.
--
-- USR-2 -- the same administrative act cost a step-up through the RPC and nothing through the
-- table. `app.authorize` is permission AND MFA; the four RLS policies call `app.has_permission`,
-- which is permission only. Measured: `has_permission('MANAGE_USERS')` true and `mfa_satisfied()`
-- false, RPC refused 42501, and the equivalent direct INSERT, deactivation and identity re-point
-- all succeeded in the same transaction.
--
-- REPLAY and CONCURRENCY are declared N/A with reasons rather than left blank. There is no
-- replayable token, nonce or idempotency key on this surface -- a membership write carries no
-- artifact that could be presented twice -- and there is no interleaving whose outcome depends on
-- ordering: `users_tenant_email_key`, `users_tenant_email_lower_key` and `users_tenant_auth_key`
-- already decide every race on this table, and SPEC-159-A proved those, not this contract.
--
-- The non-empty population rule is applied throughout: an event-count assertion that passes
-- because it selected nothing is the exact failure this surface is being repaired for, so every
-- count is pinned to a named entity and every zero is paired with a positive control.
create extension if not exists pgtap with schema extensions;

begin;
select plan(43);

-- =================================================================================================
-- FIXTURE. Two tenants, because tenant isolation is one of the attacked classes.
-- Every membership below is inserted SESSION-LESS, which is itself the provisioning path, so the
-- events these rows emit are the first evidence in the file rather than incidental setup.
-- =================================================================================================
insert into auth.users (id, email, email_confirmed_at) values
  ('78000000-0000-0000-0000-0000000000a1','admin@ma.test', now()),
  ('78000000-0000-0000-0000-0000000000a2','emp@ma.test',   now()),
  ('78000000-0000-0000-0000-0000000000a3','claim@ma.test', now()),
  ('78000000-0000-0000-0000-0000000000b1','admin@mb.test', now());

insert into public.tenants (id, name, slug, status) values
  ('78000000-0000-0000-0000-000000000001','MA Travel','ma-travel','active'),
  ('78000000-0000-0000-0000-000000000002','MB Travel','mb-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t
cross join public.subscription_plans sp
where t.id in ('78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000002')
  and sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('78000000-0000-0000-0000-00000000000a','78000000-0000-0000-0000-000000000001','Cairo','ma-cairo'),
  ('78000000-0000-0000-0000-00000000000b','78000000-0000-0000-0000-000000000002','Giza','mb-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('78000000-0000-0000-0000-0000000000c1','78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-00000000000a','sales','Sales'),
  ('78000000-0000-0000-0000-0000000000c2','78000000-0000-0000-0000-000000000002','78000000-0000-0000-0000-00000000000b','sales','Sales');

insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('78000000-0000-0000-0000-000000000011','78000000-0000-0000-0000-000000000001','MA Admin','admin@ma.test',true,'78000000-0000-0000-0000-0000000000a1'),
  ('78000000-0000-0000-0000-000000000012','78000000-0000-0000-0000-000000000001','MA Emp','emp@ma.test',true,'78000000-0000-0000-0000-0000000000a2'),
  -- UNCLAIMED, and the email matches a verified identity: the ordinary invite awaiting its human.
  ('78000000-0000-0000-0000-000000000013','78000000-0000-0000-0000-000000000001','MA Claimant','claim@ma.test',true,null),
  -- UNCLAIMED and role-bearing, with NO identity anywhere holding this address. This is the row the
  -- self-claim carve-out is attacked with.
  ('78000000-0000-0000-0000-000000000014','78000000-0000-0000-0000-000000000001','MA Exec','exec@ma.test',true,null),
  ('78000000-0000-0000-0000-000000000021','78000000-0000-0000-0000-000000000002','MB Admin','admin@mb.test',true,'78000000-0000-0000-0000-0000000000b1');

insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000011','78000000-0000-0000-0000-00000000000a','78000000-0000-0000-0000-0000000000c1',true),
  ('78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000012','78000000-0000-0000-0000-00000000000a','78000000-0000-0000-0000-0000000000c1',true),
  ('78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000013','78000000-0000-0000-0000-00000000000a','78000000-0000-0000-0000-0000000000c1',true),
  ('78000000-0000-0000-0000-000000000002','78000000-0000-0000-0000-000000000021','78000000-0000-0000-0000-00000000000b','78000000-0000-0000-0000-0000000000c2',true);

insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000011', r.id,'tenant'
from public.roles r where r.code = 'owner';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000012', r.id,'tenant'
from public.roles r where r.code = 'employee';
-- The claimant is an ORDINARY EMPLOYEE. A CEO fixture here would hide exactly the regression this
-- assertion exists to catch, because a CEO holds MANAGE_USERS and would never reach the carve-out.
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000013', r.id,'tenant'
from public.roles r where r.code = 'employee';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '78000000-0000-0000-0000-000000000002','78000000-0000-0000-0000-000000000021', r.id,'tenant'
from public.roles r where r.code = 'owner';

-- =================================================================================================
-- 1-3. THE SHAPE OF THE REPAIR, pinned before any behaviour is attacked, because an acceptance file
--      that only measures outcomes cannot tell a missing trigger from a silent one.
-- =================================================================================================
select is(
  (select count(*)::int from pg_trigger
    where tgrelid = 'public.users'::regclass and not tgisinternal
      and tgname = 'users_guard_membership_authority'
      and tgtype = 23),
  1,
  'exactly one BEFORE INSERT OR UPDATE guard on public.users, and it does NOT name DELETE');

select is(
  (select count(*)::int from pg_trigger
    where tgrelid = 'public.users'::regclass and not tgisinternal
      and tgname = 'users_emit_membership_change'
      and tgtype = 21),
  1,
  'exactly one AFTER INSERT OR UPDATE emitter on public.users, and it does NOT name DELETE');

-- The generic guard is the one that decides a full bypass from a column the attacking statement
-- supplies (LEAD-1). It must not be here, and its absence is asserted rather than assumed.
select is(
  (select count(*)::int from pg_trigger t join pg_proc p on p.oid = t.tgfoid
    where t.tgrelid = 'public.users'::regclass and not t.tgisinternal
      and p.proname = 'guard_write_capability'),
  0,
  'public.users carries NO guard_write_capability trigger -- the bespoke guard reads no attacker-supplied column');

-- =================================================================================================
-- 4-5. THE SESSION-LESS PLATFORM PATH stays open and stays audited. Provisioning writes these rows
--      before any session exists; if the guard charged it a permission, a tenant could not be born.
--      Exempt from the CHECK, never from the RECORD.
-- =================================================================================================
select lives_ok(
  $$insert into public.users (id, tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000015','78000000-0000-0000-0000-000000000001','MA Platform','platform@ma.test',true)$$,
  'a SESSION-LESS membership INSERT is permitted -- the exemption provisioning depends on');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_created'
      and entity_id = '78000000-0000-0000-0000-000000000015'
      and actor_user_id is null),
  1,
  '...and is still AUDITED, with no actor invented for it -- population pinned to one named membership');

-- =================================================================================================
-- 6-10. USR-2 -- THE DISCRIMINATING PAIR. One actor, one moment, two doors.
--       Assertion 6 is the control that makes the other four mean something: testing a denial with
--       an actor who LACKS the permission would prove nothing, because RLS would filter the row out
--       and the statement would touch nothing at all. The real gap was an actor who HOLDS
--       MANAGE_USERS and has not stepped up.
-- =================================================================================================
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(
  (select app.has_permission('MANAGE_USERS')::text || '/' || app.mfa_satisfied()::text),
  'true/false',
  'CONTROL: this actor HOLDS MANAGE_USERS and has NOT stepped up -- the gap is step-up, not permission');

select throws_ok(
  $$select app.create_tenant_user('RPC Person','rpc@ma.test')$$,
  '42501', null,
  'aal1 + MANAGE_USERS: the RPC door refuses -- app.authorize is permission AND MFA');

select throws_ok(
  $$insert into public.users (tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000001','DML Person','dml@ma.test',true)$$,
  '42501', null,
  'aal1 + MANAGE_USERS: the equivalent TABLE door now refuses too -- USR-2, the cheaper route is closed');

select throws_ok(
  $$update public.users set is_active = false
     where id = '78000000-0000-0000-0000-000000000012'$$,
  '42501', null,
  'aal1: deactivating a colleague by direct DML refuses -- RLS let the row through, the guard did not');

select throws_ok(
  $$update public.users set auth_user_id = null
     where id = '78000000-0000-0000-0000-000000000012'$$,
  '42501', null,
  'aal1: unbinding a human from their membership by direct DML refuses');

-- =================================================================================================
-- 11-15. THE CARVE-OUT, ATTACKED -- and the incidental defences named rather than credited.
--
--        The self-claim exemption reads `new`, which is the shape of BOOK-5 / LEAD-1 / PAX-3. It is
--        admissible only because it is NOT what decides the outcome.
--
--        MEASURED, and this is the part that would have been reported wrongly if the refusals had
--        simply been counted: BEFORE triggers fire in ALPHABETICAL order, so
--        `users_enforce_identity_binding` runs before `users_guard_membership_authority`. Whenever
--        the membership email still diverges from the identity being bound, that control refuses
--        23514 FIRST and the authority check is never reached. Reading those refusals as proof that
--        the guard holds would be exactly the INCIDENTAL DEFENSE != INTENTIONAL CONTROL error the
--        `leads` slice recorded.
--
--        So the incidental defence is REMOVED and the same attacks are re-run against the
--        authorization model alone (12-13), which is the LEAD-1 method. Assertion 14 needs no
--        removal, because moving the email to match makes identity binding PASS on its own terms.
--        Assertion 15 pins how narrow the carve-out is: it exempts UNCLAIMED rows only.
--
--        The positive control that proves the carve-out is genuinely reachable is not here -- it is
--        assertions 30-32, the ordinary employee who does claim their membership.
-- =================================================================================================
select throws_ok(
  $$update public.users set auth_user_id = '78000000-0000-0000-0000-0000000000a1'
     where id = '78000000-0000-0000-0000-000000000014'$$,
  '23514', null,
  'aal1: seizing an UNCLAIMED role-bearing membership is refused 23514 by identity binding -- an INDEPENDENT control that reads auth.users, not the attacker''s image');

savepoint incidental_removed;
reset role;
drop trigger users_enforce_identity_binding on public.users;
set local role authenticated;

select throws_ok(
  $$update public.users set auth_user_id = '78000000-0000-0000-0000-0000000000a1', is_active = false
     where id = '78000000-0000-0000-0000-000000000014'$$,
  '42501', null,
  'with the incidental defence REMOVED, moving is_active alongside the claim is refused 42501 by the authorization model ITSELF');

select throws_ok(
  $$update public.users set auth_user_id = '78000000-0000-0000-0000-0000000000a1', is_platform_user = true
     where id = '78000000-0000-0000-0000-000000000014'$$,
  '42501', null,
  '...and so is moving is_platform_user -- USR-4''s aal1 half closes by consequence, because the guard charges on every column');

reset role;
rollback to savepoint incidental_removed;
set local role authenticated;

select throws_ok(
  $$update public.users set auth_user_id = '78000000-0000-0000-0000-0000000000a1', email = 'admin@ma.test'
     where id = '78000000-0000-0000-0000-000000000014'$$,
  '42501', null,
  'and with every control STANDING, moving the email to match leaves the carve-out and is refused 42501 by the guard');

select throws_ok(
  $$update public.users set auth_user_id = '78000000-0000-0000-0000-0000000000a1'
     where id = '78000000-0000-0000-0000-000000000011'$$,
  '42501', null,
  'the carve-out is NARROW: re-asserting a binding on an ALREADY-CLAIMED membership is refused 42501 -- it exempts unclaimed rows, not "pointing at myself"');

-- =================================================================================================
-- 16-25. THE SAME ACTOR, STEPPED UP. Denial first, then the positive control that proves every
--        refusal above was about the step-up and not about the fixture. Each event count is pinned
--        to one named membership so no assertion can pass on an empty selection.
-- =================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.users (id, tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000016','78000000-0000-0000-0000-000000000001','MA Hire','hire@ma.test',true)$$,
  'POSITIVE CONTROL: the same actor, stepped up, performs the same direct INSERT');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_created'
      and entity_id = '78000000-0000-0000-0000-000000000016'
      and actor_user_id = '78000000-0000-0000-0000-000000000011'),
  1,
  '...and it is audited ONCE, attributed to the administrator -- the actor is resolved, not nulled');

select lives_ok(
  $$update public.users set is_active = false
     where id = '78000000-0000-0000-0000-000000000016'$$,
  'an administrator at aal2 may deactivate a membership');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_deactivated'
      and entity_id = '78000000-0000-0000-0000-000000000016'
      and severity_code = 'security'
      and previous_state = 'active' and new_state = 'inactive'),
  1,
  '...and deactivation is RECORDED at security severity with both states -- the spine held none of this before');

select lives_ok(
  $$update public.users set is_active = true
     where id = '78000000-0000-0000-0000-000000000016'$$,
  'an administrator at aal2 may reactivate a membership');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_reactivated'
      and entity_id = '78000000-0000-0000-0000-000000000016'
      and severity_code = 'security'),
  1,
  '...and reactivation is a DISTINCT recorded fact, not the absence of a deactivation');

select lives_ok(
  $$update public.users set auth_user_id = '78000000-0000-0000-0000-0000000000a2'
     where id = '78000000-0000-0000-0000-000000000012'$$,
  'an administrator at aal2 may re-point an identity binding (here, re-asserting the same human)');

select lives_ok(
  $$update public.users set auth_user_id = null
     where id = '78000000-0000-0000-0000-000000000012'$$,
  '...and may unbind one');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_identity_bound'
      and entity_id = '78000000-0000-0000-0000-000000000012'
      and severity_code = 'security'
      and previous_state = '78000000-0000-0000-0000-0000000000a2'
      and new_state is null),
  1,
  'the unbinding is RECORDED, carrying the identity it moved FROM -- the least visible privileged act on this table');

-- THE NOISE CONTROL. An emitter that fired on every UPDATE would fill the security stream until
-- nobody read it. Paired with the counts above, which are non-zero, so this zero is discriminating
-- rather than vacuous.
update public.users set full_name = 'MA Hire Renamed'
 where id = '78000000-0000-0000-0000-000000000016';

select is(
  (select count(*)::int from public.events
    where entity_id = '78000000-0000-0000-0000-000000000016'
      and event_type_code in ('user_deactivated','user_reactivated','user_identity_bound')),
  2,
  'an UPDATE that changes only full_name emits NOTHING -- still just the deactivation and the reactivation');

-- =================================================================================================
-- 26-27. ONE PRODUCER, NOT TWO. `app.create_tenant_user` lost its own record_event call in the same
--        migration that added the emitter. The prototype measured 2 here while both were in place,
--        which is why that removal is causally required and not cosmetic.
-- =================================================================================================
select lives_ok(
  $$select app.create_tenant_user('RPC Person','rpc@ma.test')$$,
  'POSITIVE CONTROL: the same actor, stepped up, reaches the RPC door too');

select is(
  (select count(*)::int from public.events e
    where e.event_type_code = 'user_created'
      and e.entity_id = (select id from public.users where email = 'rpc@ma.test')),
  1,
  'app.create_tenant_user produces EXACTLY ONE user_created -- one producer on the table, not two');

-- =================================================================================================
-- 28-29. SELF-DEACTIVATION, and the null actor it necessarily records.
--        This is a CONSEQUENCE of app.current_user_id() requiring is_active while an AFTER trigger
--        observes the post-image. It is pinned as a stated property so it cannot be rediscovered
--        later as a defect, and it is also why authority is charged BEFORE and not AFTER: an
--        authority check evaluated after this statement would refuse the administrator their own
--        exit.
-- =================================================================================================
select lives_ok(
  $$update public.users set is_active = false
     where id = '78000000-0000-0000-0000-000000000011'$$,
  'an administrator at aal2 may deactivate their OWN membership -- the reason the guard is BEFORE');

-- READ AS THE PLATFORM, not as the actor. The administrator has just deactivated themselves, so
-- app.current_tenant_id() now resolves to nothing for their session and RLS on public.events hides
-- every row from them. Asserting through that session would measure the reader's visibility rather
-- than what was recorded -- the ground-truth lesson from the trusted_devices slice.
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_deactivated'
      and entity_id = '78000000-0000-0000-0000-000000000011'
      and actor_user_id is null),
  1,
  '...and it records a NULL actor, because current_user_id() requires is_active and AFTER sees the post-image');

update public.users set is_active = true where id = '78000000-0000-0000-0000-000000000011';

-- =================================================================================================
-- 30-32. THE EMPLOYEE REGRESSION. An ordinary employee holds no MANAGE_USERS, so a guard that
--        charged it on every session-backed write would make app.activate_membership() impossible
--        for the only people it exists for. This is the assertion the carve-out is FOR.
-- =================================================================================================
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select lives_ok(
  $$select * from app.activate_membership()$$,
  'an EMPLOYEE claimant at aal1, holding no MANAGE_USERS, still claims their own membership');

select is(
  (select auth_user_id from public.users where id = '78000000-0000-0000-0000-000000000013'),
  '78000000-0000-0000-0000-0000000000a3'::uuid,
  '...and the claim actually landed -- the lives_ok above is not passing on a no-op');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_identity_bound'
      and entity_id = '78000000-0000-0000-0000-000000000013'
      and actor_user_id = '78000000-0000-0000-0000-000000000013'),
  1,
  '...and the claim is AUDITED exactly once, attributed to the claimant -- IDENT-2, closed by the same emitter');

-- =================================================================================================
-- 33-35. THE OTHER LEGITIMATE BOUNDARIES, proven SEPARATELY rather than with one privileged fixture
--        that could hide an employee regression.
-- =================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.users (tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000001','Emp Hire','emphire@ma.test',true)$$,
  '42501', null,
  'an EMPLOYEE holding no MANAGE_USERS cannot create a membership, stepped up or not');

reset role;
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000b1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.users (tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000001','Cross Hire','cross@ma.test',true)$$,
  '42501', null,
  'a FOREIGN tenant administrator, fully stepped up, cannot insert into another tenant');

update public.users set tenant_id = '78000000-0000-0000-0000-000000000002'
 where id = '78000000-0000-0000-0000-000000000016';

-- Cross-tenant relocation fails SILENTLY -- RLS filters the row out, so the statement raises
-- nothing and touches nothing. A silent no-op can only be verified against GROUND TRUTH, which
-- means reading it back as the platform and not through the attacker's own visibility.
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select tenant_id from public.users where id = '78000000-0000-0000-0000-000000000016'),
  '78000000-0000-0000-0000-000000000001'::uuid,
  '...and cannot relocate another tenant''s membership across the boundary -- a silent no-op, verified against ground truth');

-- =================================================================================================
-- 36-43. MUTATION CONTROLS. Each load-bearing predicate is removed inside a savepoint and the
--        discriminating result is measured to MOVE, then restored and measured to move back. A
--        mutation that an unrelated earlier guard also kills measures that guard, not this one, so
--        each pair below is aimed at a scenario only its own predicate can decide.
-- =================================================================================================

-- (i) THE GUARD ITSELF. Without it, the aal1 direct INSERT that assertion 9 refuses must succeed.
savepoint mut_guard;
drop trigger users_guard_membership_authority on public.users;
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.users (tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000001','Mutant Person','mutant@ma.test',true)$$,
  'MUTATION (i): with the guard dropped, the aal1 direct INSERT SUCCEEDS -- the refusal was the guard''s');

reset role;
select set_config('request.jwt.claims', null, true);
rollback to savepoint mut_guard;

select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.users (tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000001','Mutant Person','mutant@ma.test',true)$$,
  '42501', null,
  'MUTATION (i) RESTORED: the same statement is refused again -- the kill is the guard and nothing else');

reset role;
select set_config('request.jwt.claims', null, true);

-- (ii) THE EMITTER. Without it, the user_deactivated count assertion 19 relies on must read zero.
savepoint mut_emit;
drop trigger users_emit_membership_change on public.users;
update public.users set is_active = false where id = '78000000-0000-0000-0000-000000000015';

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_deactivated'
      and entity_id = '78000000-0000-0000-0000-000000000015'),
  0,
  'MUTATION (ii): with the emitter dropped, a real deactivation records NOTHING -- the baseline defect, restored');

rollback to savepoint mut_emit;
update public.users set is_active = false where id = '78000000-0000-0000-0000-000000000015';

select is(
  (select count(*)::int from public.events
    where event_type_code = 'user_deactivated'
      and entity_id = '78000000-0000-0000-0000-000000000015'),
  1,
  'MUTATION (ii) RESTORED: the identical statement is recorded once -- the emitter is what records it');

-- (iii) THE SESSION-LESS BRANCH. Removing only `auth.uid() is null` must break provisioning, and
--       nothing else in the function can rescue it.
savepoint mut_sessionless;
create or replace function app.guard_membership_authority()
returns trigger language plpgsql security definer set search_path = ''
as $mut$
begin
    if tg_op = 'UPDATE' then
        if old.auth_user_id is null
           and new.auth_user_id = (select auth.uid())
           and new.tenant_id        is not distinct from old.tenant_id
           and new.email            is not distinct from old.email
           and new.is_active        is not distinct from old.is_active
           and new.is_platform_user is not distinct from old.is_platform_user
        then
            return new;
        end if;
    end if;
    perform app.authorize('MANAGE_USERS');
    return new;
end;
$mut$;

select throws_ok(
  $$insert into public.users (tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000001','Platform Two','platform2@ma.test',true)$$,
  '42501', null,
  'MUTATION (iii): without the auth.uid() is null branch, the SESSION-LESS platform write breaks');

rollback to savepoint mut_sessionless;

select lives_ok(
  $$insert into public.users (tenant_id, full_name, email, is_active)
    values ('78000000-0000-0000-0000-000000000001','Platform Two','platform2@ma.test',true)$$,
  'MUTATION (iii) RESTORED: the identical statement succeeds again -- that one branch is what provisioning depends on');

-- (iv) THE SELF-CLAIM CARVE-OUT. Removing only that branch must break the employee claimant, and
--      the claimant is an ordinary employee precisely so nothing else can rescue them.
savepoint mut_carveout;
create or replace function app.guard_membership_authority()
returns trigger language plpgsql security definer set search_path = ''
as $mut$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    perform app.authorize('MANAGE_USERS');
    return new;
end;
$mut$;

update public.users set auth_user_id = null where id = '78000000-0000-0000-0000-000000000013';
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select throws_ok(
  $$select * from app.activate_membership()$$,
  '42501', null,
  'MUTATION (iv): without the self-claim carve-out, the EMPLOYEE claimant can no longer claim their own membership');

reset role;
select set_config('request.jwt.claims', null, true);
rollback to savepoint mut_carveout;

-- Unbound again by the platform path, so the restored control attacks the same state the mutant did.
update public.users set auth_user_id = null where id = '78000000-0000-0000-0000-000000000013';
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select lives_ok(
  $$select * from app.activate_membership()$$,
  'MUTATION (iv) RESTORED: the same employee claims the same membership again -- that one branch is the whole regression');

reset role;
select set_config('request.jwt.claims', null, true);

select finish();
rollback;
