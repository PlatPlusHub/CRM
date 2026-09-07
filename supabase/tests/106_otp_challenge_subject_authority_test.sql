-- pgTAP: Batch 6 slice 6 -- otp_challenges, the challenge its own subject could answer.
--
-- ATTACK-CLASSES: AUTH DOOR STATE INPUT PRIVILEGE REPLAY OBSERVABILITY TENANT=N/A BUSINESS=N/A CONCURRENCY=N/A
--
-- TENANT=N/A       canon 34 puts this table outside tenant scope entirely: it carries no `tenant_id`
--                  and no membership `user_id`, keyed only to `auth.users`. The isolation boundary
--                  here is the HUMAN, not the tenant, and it is attacked under AUTH (assertion 8).
-- BUSINESS=N/A     the table encodes no business rule -- no money, no state machine anyone trades
--                  against, no canon-28 permission. Its only invariant is who may write it.
-- CONCURRENCY=N/A  there is no read-modify-write path to race: after this migration `authenticated`
--                  cannot write the table at all, and no function reads a row to decide anything
--                  (measured: ZERO functions in `app` or `public` reference `otp_challenges`).
--                  A race needs two writers and there is now at most one.
--
-- WHAT THIS FILE PINS, and why each assertion exists rather than being decoration:
--
-- 1-6   are the OTP-1 repair. Every one of them SUCCEEDED before `202607061600`, reproduced at
--       `aal1` -- the exact authentication level an OTP challenge exists to resolve -- as the
--       challenged user against their OWN row. Self-verification, attempt-counter reset, expiry
--       extension, delivery-address capture and forging a pre-verified challenge were all stored.
--       They are `throws_ok` and not `is()` because a grant refusal is a hard refusal: unlike an RLS
--       USING clause, it cannot degrade into a silent zero-row no-op that a data assertion would
--       have to catch after the fact.
--
-- 7-9   are the anti-over-revoke controls, and they are the reason the repair is a REVOKE of two
--       privileges rather than three. Reading that a code was sent to you is not authority over it,
--       so SELECT is retained (7) while the cross-identity boundary stays blind (8) and `anon`
--       stays locked out entirely (9). Assertion 9 is also the evidence that refutes this slice's
--       own premise: the manifest predicted "correctly unguarded -- it is pre-authentication", and
--       a table `anon` cannot touch is not a pre-authentication surface.
--
-- 10    is the anti-tautology control. Assertions 1-6 would pass equally against a table nobody can
--       write for any reason -- including one accidentally revoked from every role, or dropped. 10
--       proves the platform side is still open, so the repair narrowed authority rather than
--       destroying the table's purpose.
--
-- 11-14 prove the repair was SURGICAL rather than a blanket sweep of the canon-34 family, which is
--       the shape a careless fix would have taken. The three tables are three different situations
--       and the test refuses to blur them: `trusted_devices` KEEPS its grant because
--       `app.record_trusted_device` is SECURITY INVOKER and would break without it (13 proves it
--       still works, rather than assuming), and `totp_enrollments` KEEPS its grant because whether
--       disabling an MFA factor requires re-authentication is a policy question canon does not
--       answer -- OTP-2. Assertion 14 pins that KNOWN-OPEN state deliberately: a registered open
--       finding that silently changes shape is worse than one nobody wrote down.
--
-- 15-16 are the PAX-4 correction, made executable. `202607061400` recorded that 20 tables "have no
--       trigger that calls app.authorize or app.has_permission at all" and read that as 20
--       ungoverned writes. Re-measured: 15 of the 20 carry the capability check inside the RLS
--       POLICY instead of a trigger, so the count was of ENFORCEMENT SITES OF ONE KIND and the
--       inference drawn from it was about GOVERNANCE. These two assertions exist so the corrected
--       number cannot quietly drift back to the proxy: if a future change moves a capability check
--       from a policy into a trigger, or removes one, the numbers move and this file fails.

create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

-- =============================================================================================
-- FIXTURE. Two humans, because a cross-identity assertion whose foreign row does not exist is the
-- vacuous-security-test class (AGENTS.md §6). Assertion 8 asserts on the DATA, so the victim row
-- must genuinely be there for a zero to mean anything.
-- =============================================================================================
insert into auth.users (id, email) values
  ('06000000-0000-0000-0000-0000000000a1','subject@otp6.test'),
  ('06000000-0000-0000-0000-0000000000a2','victim@otp6.test');

insert into public.otp_challenges (id, auth_user_id, status_code, sent_to_email, expires_at, failed_attempts)
values ('06000000-0000-0000-0000-0000000000c1','06000000-0000-0000-0000-0000000000a1',
        'pending','subject@otp6.test', now() - interval '1 hour', 2),
       ('06000000-0000-0000-0000-0000000000c2','06000000-0000-0000-0000-0000000000a2',
        'pending','victim@otp6.test', now() + interval '5 minutes', 0);

-- The subject, holding an `aal1` session: primary factor accepted, second factor NOT yet presented.
select set_config('request.jwt.claims','{"sub":"06000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
set local role authenticated;

-- =============================================================================================
-- 1-6. THE SUBJECT IS NO LONGER THE AUTHORITY OVER ITS OWN CHALLENGE.
-- =============================================================================================
select throws_ok(
  $$insert into public.otp_challenges (auth_user_id, status_code, sent_to_email, expires_at, verified_at)
    values ('06000000-0000-0000-0000-0000000000a1','verified','subject@otp6.test', now() + interval '100 years', now())$$,
  '42501', null,
  'a caller cannot FORGE a pre-verified challenge for themselves -- this INSERT was stored before 202607061600');

select throws_ok(
  $$update public.otp_challenges set status_code = 'verified', verified_at = now()
     where id = '06000000-0000-0000-0000-0000000000c1'$$,
  '42501', null,
  '...nor SELF-VERIFY an expired, unverified challenge at aal1 -- the second factor cannot be satisfied by the party presenting it');

select throws_ok(
  $$update public.otp_challenges set failed_attempts = 0
     where id = '06000000-0000-0000-0000-0000000000c1'$$,
  '42501', null,
  '...nor RESET the attempt counter an OTP lockout would consult -- the party being counted no longer keeps the count');

select throws_ok(
  $$update public.otp_challenges set expires_at = now() + interval '100 years'
     where id = '06000000-0000-0000-0000-0000000000c1'$$,
  '42501', null,
  '...nor EXTEND its own expiry, which is the replay window');

select throws_ok(
  $$update public.otp_challenges set sent_to_email = 'attacker@evil.test'
     where id = '06000000-0000-0000-0000-0000000000c1'$$,
  '42501', null,
  '...nor REDIRECT where the code is delivered');

select throws_ok(
  $$delete from public.otp_challenges where id = '06000000-0000-0000-0000-0000000000c1'$$,
  '42501', null,
  '...nor DESTROY the record of its own failed attempts');

-- =============================================================================================
-- 7-9. WHAT THE REPAIR DELIBERATELY DID NOT TAKE AWAY, AND WHAT IT NEVER GAVE.
-- =============================================================================================
select is(
  (select count(*)::int from public.otp_challenges where id = '06000000-0000-0000-0000-0000000000c1'),
  1,
  'SELECT is RETAINED: a human can still see that a code was issued to them -- observing is not authority, and owner_only already scopes it');

select is(
  (select count(*)::int from public.otp_challenges where auth_user_id = '06000000-0000-0000-0000-0000000000a2'),
  0,
  'and canon 34 row-ownership still holds: another human''s challenge is invisible -- asserted on the DATA, because a USING clause hides rows rather than raising');

reset role;
set local role anon;
select throws_ok(
  $$select count(*) from public.otp_challenges$$,
  '42501', null,
  'anon cannot reach this table AT ALL -- the evidence that refutes "pre-authentication": an unauthenticated caller was never able to use it');

-- =============================================================================================
-- 10. ANTI-TAUTOLOGY. 1-6 would pass against a table nobody can write, or one that was dropped.
-- =============================================================================================
reset role;
set local role service_role;
select lives_ok(
  $$insert into public.otp_challenges (auth_user_id, status_code, sent_to_email, expires_at)
    values ('06000000-0000-0000-0000-0000000000a1','pending','subject@otp6.test', now() + interval '5 minutes')$$,
  'the PLATFORM can still issue a challenge -- the repair narrowed who may write, it did not make the table unusable');

reset role;
select set_config('request.jwt.claims', '', true);

-- =============================================================================================
-- 11-14. THE REPAIR WAS SURGICAL. Three canon-34 tables, three different situations.
-- =============================================================================================
select is(
  (select string_agg(distinct privilege_type, ',' order by privilege_type)
     from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'otp_challenges' and grantee = 'authenticated'),
  'SELECT',
  'otp_challenges: authenticated is left with SELECT and nothing else');

select is(
  (select string_agg(distinct privilege_type, ',' order by privilege_type)
     from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'trusted_devices' and grantee = 'authenticated'),
  'INSERT,SELECT,UPDATE',
  'trusted_devices KEEPS its write grant -- it is load-bearing, not residue');

select set_config('request.jwt.claims','{"sub":"06000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
set local role authenticated;
select lives_ok(
  $$select app.record_trusted_device('otp6-own-device')$$,
  '...and that is WHY: app.record_trusted_device is SECURITY INVOKER, so a family-wide revoke would have broken it -- proved by calling it, not by reading it');
reset role;
select set_config('request.jwt.claims', '', true);

select is(
  (select string_agg(distinct privilege_type, ',' order by privilege_type)
     from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'totp_enrollments' and grantee = 'authenticated'),
  'INSERT,SELECT,UPDATE',
  'totp_enrollments KEEPS its write grant and that is OTP-2, pinned OPEN on purpose: MFA self-disable at aal1 is reproducible, and whether it should require step-up is a policy question canon does not answer');

-- =============================================================================================
-- 15-16. THE PAX-4 CORRECTION, MADE EXECUTABLE.
-- =============================================================================================
select is(
  (with named(t) as (values
     ('branches'),('catalog_values'),('chart_of_accounts'),('departments'),('exchange_rates'),
     ('journal_entries'),('journal_entry_lines'),('lead_interactions'),('subscriptions'),('tenants'),
     ('users'),('user_branch_assignments'),('user_permission_grants'),('otp_challenges'),
     ('totp_enrollments'),('trusted_devices'),('campaign_daily_metrics'),('document_retention_policies'),
     ('exchange_rate_adjustments'),('subscription_payment_proofs'))
   select count(*)::int from named n
    where coalesce((select bool_or(coalesce(pg_get_expr(p.polqual, p.polrelid),'') ||
                                   coalesce(pg_get_expr(p.polwithcheck, p.polrelid),'') ~* '(has_permission|authorize)')
                      from pg_policy p
                     where p.polrelid = ('public.' || n.t)::regclass and p.polcmd in ('a','w')), false)),
  15,
  'PAX-4 CORRECTED: 15 of the 20 tables it counted as having "no capability trigger" carry the capability check inside the RLS POLICY -- the count measured enforcement sites of one kind and was read as governance');

select is(
  (with named(t) as (values
     ('branches'),('catalog_values'),('chart_of_accounts'),('departments'),('exchange_rates'),
     ('journal_entries'),('journal_entry_lines'),('lead_interactions'),('subscriptions'),('tenants'),
     ('users'),('user_branch_assignments'),('user_permission_grants'),('otp_challenges'),
     ('totp_enrollments'),('trusted_devices'),('campaign_daily_metrics'),('document_retention_policies'),
     ('exchange_rate_adjustments'),('subscription_payment_proofs'))
   select coalesce(string_agg(n.t, ',' order by n.t), '') from named n
    where not coalesce((select bool_or(coalesce(pg_get_expr(p.polqual, p.polrelid),'') ||
                                       coalesce(pg_get_expr(p.polwithcheck, p.polrelid),'') ~* '(has_permission|authorize)')
                          from pg_policy p
                         where p.polrelid = ('public.' || n.t)::regclass and p.polcmd in ('a','w')), false)),
  'campaign_daily_metrics,lead_interactions,otp_challenges,totp_enrollments,trusted_devices',
  '...and PAX-4''s genuinely uncovered set is these FIVE, each already dispositioned or registered -- named rather than counted, so a new member cannot hide inside a number that still reads 5');

select * from finish();
rollback;
