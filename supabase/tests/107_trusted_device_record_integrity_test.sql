-- pgTAP: Batch 6 slice 7 -- trusted_devices, the device record its own subject could rewrite.
--
-- ATTACK-CLASSES: AUTH DOOR STATE INPUT PRIVILEGE OBSERVABILITY REPLAY TENANT=N/A BUSINESS=N/A CONCURRENCY=N/A
--
-- TENANT=N/A       canon 34 / ADR-0017 put device trust outside tenant scope: the table carries no
--                  `tenant_id` and keys only to `auth.users`, because a device is trusted before any
--                  tenant is chosen. The isolation boundary is the HUMAN, and it is attacked under
--                  AUTH (assertions 8-10), not skipped.
-- BUSINESS=N/A     no money, no canon-28 permission, no business state machine trades against this
--                  row. Its invariants are who may write it and what the record may claim.
-- CONCURRENCY=N/A  the one read-modify-write path, `app.record_trusted_device`, is a single
--                  INSERT .. ON CONFLICT statement against a UNIQUE index
--                  (`trusted_devices_user_device_key`, `202607059500`), so the database serialises
--                  it. There is no check-then-write window in SQL to race.
--
-- WHAT THIS FILE PINS:
--
-- 1-3   are TD-1. `status_code` accepted ANY text before `202607061700`: `SUPER_TRUSTED_FOREVER`
--       was stored verbatim by the subject at `aal1`, while the family `trusted_device_status` had
--       been seeded and active since `202607043100`. 2 and 3 are the anti-over-fix controls -- the
--       three real values must still be writable, or the repair would have made the table unusable
--       rather than correct.
--
-- 4-7   are TD-2, the BOOK-3 question answered for this surface: does direct DML bypass what the
--       RPC charges? It did. `app.record_trusted_device` says in its own body that the FIRST
--       verification is the one worth keeping, and a direct UPDATE rewrote `verified_at`,
--       `first_seen_at` and `created_at` freely. `throws_ok` on 42501 rather than `is()` on the
--       data, because a trigger refusal is a hard refusal and cannot degrade into a silent no-op.
--
-- 8-10  are the boundaries that HELD before the repair and must keep holding. They are the reason
--       TD-1/TD-2 are Medium and not High, so they are asserted rather than assumed: a subject
--       cannot plant a device on another human, cannot touch another human's row, and cannot steal
--       one by moving `auth_user_id` to itself. 10 asserts on the DATA, so the victim row is real.
--
-- 11-13 are the anti-tautology and anti-over-revoke controls. If the repair had broken the three
--       SECURITY INVOKER RPCs it would have been a regression dressed as a fix, so the test CALLS
--       them rather than inspecting them: record (11), re-record for idempotence and the
--       first-verification rule together (12), and revoke (13).
--
-- 14    is the grant model pinned by MEMBERSHIP, not by count. `trusted_devices` KEEPS
--       INSERT/SELECT/UPDATE precisely because `app.record_trusted_device` is SECURITY INVOKER --
--       the opposite of the OTP-1 repair one migration earlier, and the reason this slice is not a
--       copy of that one.
--
-- 15    IS THE LOAD-BEARING ONE, and it is why TD-3 could be deferred rather than guessed.
--       `trusted_devices` is a RECORD, not a GATE: nothing in this database reads it to decide
--       anything. `app.mfa_satisfied()` consults `app.requires_mfa()` and the JWT `aal` claim and
--       nothing else, and no RLS policy anywhere references the table. That single condition is
--       what keeps non-durable revocation (TD-3) and any residual record forgery at INTEGRITY and
--       away from PRIVILEGE. The assertion names the full consumer set rather than counting it, so
--       neither an addition NOR a substitution can pass. The day device trust is wired into an
--       authorization path, this fails -- and TD-3 has to be answered before that lands, which is
--       exactly when the answer is derivable.

create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

-- =============================================================================================
-- FIXTURE. Two humans: a cross-identity assertion whose foreign row does not exist is the
-- vacuous-security-test class (AGENTS.md §6), and assertion 10 asserts on the DATA.
-- =============================================================================================
insert into auth.users (id, email) values
  ('07000000-0000-0000-0000-0000000000a1','subject@td7.test'),
  ('07000000-0000-0000-0000-0000000000a2','victim@td7.test');

insert into public.trusted_devices (id, auth_user_id, device_identifier, status_code, verified_at)
values ('07000000-0000-0000-0000-0000000000d1','07000000-0000-0000-0000-0000000000a1',
        'subject-laptop','trusted', now() - interval '30 days'),
       ('07000000-0000-0000-0000-0000000000d2','07000000-0000-0000-0000-0000000000a2',
        'victim-laptop','trusted', now() - interval '30 days');

-- The subject at `aal1`: the level a device-trust record is created and read at.
select set_config('request.jwt.claims','{"sub":"07000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
set local role authenticated;

-- =============================================================================================
-- TD-1 -- the seeded vocabulary is authoritative at the point of use.
-- =============================================================================================

select throws_ok(
  $$insert into public.trusted_devices (auth_user_id, device_identifier, status_code)
    values ('07000000-0000-0000-0000-0000000000a1','forged-device','SUPER_TRUSTED_FOREVER')$$,
  '23514',
  null,
  'TD-1 INSERT: an invented status_code is refused -- this exact string was STORED VERBATIM before 202607061700, while trusted_device_status had been seeded expired/revoked/trusted since 202607043100');

select throws_ok(
  $$update public.trusted_devices set status_code = 'not_a_real_status'
     where id = '07000000-0000-0000-0000-0000000000d1'$$,
  '23514',
  null,
  'TD-1 UPDATE: the same refusal on the update path -- the catalog trigger validates a column the statement actually changed, on both doors');

select lives_ok(
  $$update public.trusted_devices set status_code = 'expired'
     where id = '07000000-0000-0000-0000-0000000000d1'$$,
  'ANTI-OVER-FIX: the three REAL family values are still writable -- the repair narrowed the vocabulary to the seeded one, it did not freeze the column');

-- =============================================================================================
-- TD-2 -- the door enforces what app.record_trusted_device charges.
-- =============================================================================================

select throws_ok(
  $$update public.trusted_devices set verified_at = now() + interval '73 years'
     where id = '07000000-0000-0000-0000-0000000000d1'$$,
  '42501',
  null,
  'TD-2: verified_at may not be rewritten -- the RPC says "the FIRST verification is the one worth keeping" and a direct UPDATE moved it decades into the future before this migration');

select throws_ok(
  $$update public.trusted_devices set first_seen_at = '2001-01-01'
     where id = '07000000-0000-0000-0000-0000000000d1'$$,
  '42501',
  null,
  'TD-2: first_seen_at may not be backdated -- a subject could make a device look long-established in the one record a security investigation would read');

select throws_ok(
  $$update public.trusted_devices set created_at = '2001-01-01'
     where id = '07000000-0000-0000-0000-0000000000d1'$$,
  '42501',
  null,
  'TD-2: created_at may not be backdated either -- both timestamps were rewritable in the same statement before the repair');

select throws_ok(
  $$update public.trusted_devices set device_identifier = 'some-other-device'
     where id = '07000000-0000-0000-0000-0000000000d1'$$,
  '42501',
  null,
  'TD-2: the device a record is ABOUT may not be swapped -- renaming it would make the row attest a verification that never happened for that device');

-- =============================================================================================
-- AUTH -- the boundaries that already held, asserted rather than assumed.
-- =============================================================================================

select throws_ok(
  $$insert into public.trusted_devices (auth_user_id, device_identifier, status_code)
    values ('07000000-0000-0000-0000-0000000000a2','planted-device','trusted')$$,
  '42501',
  null,
  'AUTH: a device cannot be planted on ANOTHER human -- owner_only WITH CHECK, held before the repair and still held after it');

select is(
  (select count(*)::int from public.trusted_devices where auth_user_id = '07000000-0000-0000-0000-0000000000a2'),
  0,
  'AUTH: the other human''s device is not merely unwritable, it is INVISIBLE -- owner_only USING, and the row genuinely exists (asserted on data, not on a refusal)');

-- Attempted as the subject, as a bare statement: the USING clause hides the row, so this is a
-- silent zero-row no-op rather than an error -- which is exactly why the assertion that follows
-- reads GROUND TRUTH as the owner instead of trusting the refusal.
update public.trusted_devices set auth_user_id = '07000000-0000-0000-0000-0000000000a1'
 where device_identifier = 'victim-laptop';

reset role;

select is(
  (select auth_user_id::text from public.trusted_devices where device_identifier = 'victim-laptop'),
  '07000000-0000-0000-0000-0000000000a2',
  'PRIVILEGE: a row cannot be STOLEN by moving auth_user_id to self -- verified against ground truth READ AS THE OWNER, because an RLS refusal on this path is a silent no-op and a zero-row result would look identical to a successful theft the attacker simply cannot see');

select set_config('request.jwt.claims','{"sub":"07000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
set local role authenticated;

-- =============================================================================================
-- ANTI-TAUTOLOGY -- the three SECURITY INVOKER RPCs must still work. Called, not inspected.
-- =============================================================================================

select lives_ok(
  $$select app.record_trusted_device('rpc-registered-device')$$,
  'ANTI-TAUTOLOGY: app.record_trusted_device still works -- it is SECURITY INVOKER, so it writes with the caller''s own privileges and would break if this slice had copied OTP-1''s revoke');

select is(
  (with reagain as (select app.record_trusted_device('subject-laptop') as rid)
   select d.verified_at from reagain r join public.trusted_devices d on d.id = r.rid),
  now() - interval '30 days',
  'ANTI-TAUTOLOGY + TD-2 TOGETHER: re-recording an EXISTING device returns its own row and leaves verified_at at the fixture''s value -- the RPC''s coalesce() and the new trigger agree, which is the proof the door did not narrow the sanctioned path');

select lives_ok(
  $$select app.revoke_trusted_device('07000000-0000-0000-0000-0000000000d1')$$,
  'ANTI-TAUTOLOGY: app.revoke_trusted_device still works -- it changes status_code and revoked_at, both of which the rewrite guard deliberately permits');

-- =============================================================================================
-- THE GRANT MODEL, AND THE CONDITION THAT BOUNDS THIS SLICE.
-- =============================================================================================

reset role;

select is(
  (select string_agg(privilege_type, ',' order by privilege_type)
     from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'trusted_devices' and grantee = 'authenticated'),
  'INSERT,SELECT,UPDATE',
  'the write grant is KEPT and named by membership -- unlike otp_challenges one migration earlier, app.record_trusted_device is SECURITY INVOKER and revoking here would break the sanctioned path, so TD-1/TD-2 are doors and not a revoke');

select is(
  (select coalesce(string_agg(distinct src, ',' order by src), '')
     from (
       select n.nspname || '.' || p.proname as src
         from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where p.prosrc like '%trusted_devices%'
          and n.nspname in ('app','public')
       union all
       select 'POLICY:' || c.relname
         from pg_policy pol join pg_class c on c.oid = pol.polrelid
        where coalesce(pg_get_expr(pol.polqual, pol.polrelid), '')
              || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') like '%trusted_devices%'
     ) s),
  'app.emit_creation_event,app.emit_entity_event,app.forbid_trusted_device_record_rewrite,app.my_trusted_devices,app.record_trusted_device,app.revoke_trusted_device,public.my_trusted_devices',
  'THE CONDITION THAT BOUNDS THIS SLICE: trusted_devices is a RECORD, not a GATE -- this is its ENTIRE mention set, every member a writer, a self-read or this slice''s own guard, and NO policy anywhere references it. app.mfa_satisfied() consults requires_mfa() and the JWT aal claim only. That is why TD-3 (is revocation durable?) is a deferred design question and not an open hole. Matching is on function TEXT and so includes the two emit_* helpers, which only NAME the table in a comment explaining that it carries no tenant_id: deliberately over-inclusive, because a tripwire that errs toward review is the safe direction and a false negative here would let a gate slip in unnoticed');

select * from finish();
rollback;
