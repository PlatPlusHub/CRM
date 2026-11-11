# Change Request — SPEC-303

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 48 audits `customer_consents` and records it, not repaired: nothing material was found, so one test pins what the slice measured and no test held, and the disposition record sets the surface `AUDITED`.

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `2cc8fea`, on the live local catalog, ranks `customer_consents` first: Exposure 6, coverage 18, NOT-RECORDED (runner-up `document_retention_policies` 6/36). The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** This table is the customer's advertising-data decision (PH8-4, SPEC-240): `app.claim_conversion_deliveries` sends a `qualified_phone_call` only when `app.customer_consent_status` reads `granted`. The one writer is `app.record_customer_consent` (SECURITY DEFINER): tenant and actor from the session, `app.authorize('CREATE_CUSTOMER')` (permission, plus step-up for the roles `app.requires_mfa` names), the customer row lock, refusal of a merged identity, insert. `authenticated` holds SELECT only under RLS; the table is append-only (BEFORE UPDATE and DELETE), its actor derived, its codes catalog-checked, and it is exempt from the subscription write gate (test 35: a withdrawal must be recordable).
- **Measured at `2cc8fea`** on the local stack with committed probe fixtures (an active tenant with an `owner` and an `employee`, a tenant whose subscription then ends, an attacker tenant), every axis held or is a recorded design position:
  - **Held:** a trainee refused CREATE_CUSTOMER; INSERT, UPDATE and DELETE refused at the table (no grant); the table owner's UPDATE refused (append-only); another tenant's owner refused; `ad_personalization` refused (CHECK); `fax` refused (catalog); blank evidence stored NULL with the server's actor; a merge of a customer with a newer DENIED into one with an older GRANT leaves both reading `denied`, the merged identity refuses new decisions, and the survivor's new GRANT governs both; an archived, never-merged customer still takes a withdrawal.
  - **Positions:** an `owner` at `aal1` is refused step-up and records at `aal2`, while an `employee`, whose role is not MFA-bound, records at `aal1`; any CREATE_CUSTOMER holder decides for any customer of the tenant (customers carry no branch scope), which is SPEC-240's choice of authority. A tenant whose writes the subscription gate refuses still records a GRANT, not only a withdrawal: the decision is the customer's own fact, and refusing it would leave the record false.
  - **DC-15:** `service_role`'s TRUNCATE empties the table; no trigger refuses TRUNCATE on any append-only table. The consequence fails closed (no record reads as unspecified, never `granted`), and on Primary `service_role` also holds INSERT (read-only, 2026-11-11), so it is `service_role`'s blast radius, deliberately untouched by SPEC-124 and PAR-5, recorded and not pinned because those grants differ by environment.
- **What is pinned where.** Tests 142, 144, 143 and 35 already pin the door, the server's actor and time, input, privilege, tenant, append-only, latest-wins, the billing withdrawal, the claim and the merge record; SPEC-244 recorded the two-session merge proofs. Test 163 adds only what the slice measured and no test held: step-up in both directions, the archived withdrawal and the lapsed tenant's GRANT.
- **Earn it and worth it.** No repair is owed, so no migration: a record-only contract, the SPEC-228, SPEC-229 and SPEC-259 shape. The register is unchanged (no finding).

## Risks

- **None to the database.** No migration, function, policy, grant or trigger changes; Primary `vrvtsxexkiiiivlkdxzp` is not written and Secondary `brplkqmbzffpxqgkkdzo` is never contacted. The DATABASE protocol of `-Finish` resets the local ORVION database, as every DATABASE Finish does.
- **A future change to step-up, the billing gate or archive handling** now turns test 163 red where it changes what the slice measured; that is the purpose.
- **Gate 1 of this contract is DELEGATED** under the owner's instructions (class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo; run mode 2 for slice 6, 2026-11-11 ~18:20 Cairo), recorded outside this repository; never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-303-the-consent-record-audit.md`
- `supabase/tests/163_the_consent_record_audit_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql`
- `supabase/migrations/20261007120000_a_conversion_is_sent_only_on_google_success.sql`
- `supabase/migrations/20261007190000_the_merge_record_is_written_only_by_the_merge.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql`
- `supabase/tests/143_a_conversion_is_sent_only_on_google_success_test.sql`
- `supabase/tests/144_the_merge_record_is_written_only_by_the_merge_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/verify_database.sql`
- `.github/workflows/migration-ci.yml`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql` (the table, `app.record_customer_consent`, `app.customer_consent_status`) and `20261007190000_the_merge_record_is_written_only_by_the_merge.sql`
- `changes/SPEC-240-a-google-ads-call-qualifies-as-a-phone-call.md`; `changes/SPEC-244-the-merge-record-is-written-only-by-the-merge.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_GAP_REGISTER.md` (PAR-5, DC-15); `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: record-only. Test 163 pins step-up in both directions on the one writer (an `owner` at `aal1` refused, at `aal2` recorded; an `employee` recorded at `aal1`, attributed by the server), the archived never-merged withdrawal, and the lapsed tenant's GRANT with its premise (an ordinary customer write refused); the disposition record sets `customer_consents` `AUDITED` / `ADVERSARIAL` with coverage 49 of 78; the manifest suite figure moves to 163 files / 3086 assertions.

Pass 2 Adversarial Review: each part was challenged on the prototype. Repeating the door, tenant, privilege and input assertions in test 163 was rejected: they were re-measured, held, and are pinned by tests 142 and 144. Pinning `service_role`'s TRUNCATE was rejected: its grants differ by environment (PAR-5), so a local pin would measure the platform, and DC-15 owns that blast radius. A TRUNCATE trigger on the append-only tables was rejected for this slice: it would be a schema change for a consequence that fails closed, on a role SPEC-124 deliberately left untouched. Billing-gating a GRANT was rejected: the decision is the customer's own fact and a refusal would leave the record false. A branch scope on consent decisions was rejected: customers carry no branch scope, and SPEC-240 chose CREATE_CUSTOMER as the authority. Re-probing concurrency was rejected: SPEC-244 recorded the two-session merge proofs. A gap-register row was rejected: there is no finding. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-11. Re-measured on byte-identical files in a disposable clone of `2cc8fea` with the project-local CLI 3.0.0: test 163 alone (9/9), the three mutants each installed and restored md5-identical, the probes as the causal negative, the clean reset, pgTAP Pass A and B, the three declared HTTP suites, smoke, the generators and repository consistency; Primary read read-only for `service_role`'s grants on the append-only tables.

Selected Version: SPEC-303; selected: record-only (SPEC-228, SPEC-229 and SPEC-259 shape): one test pinning what the slice measured and no test held, the disposition AUDITED with coverage 49 of 78, and the suite figure; no migration, no register row, no hosted write; proven on byte-identical files by the full local protocol, three killed mutants and the probes

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Test 163 | `supabase/tests` | WRITE | SHA-256 `69276505dce88f89cb65ab1910632fffdbc518980963e6382073cece3de44b85`, md5 `1cd3282306de8af41d8c2904c49cc789`, 9076 bytes, LF, ASCII, `plan(9)`: 9/9 on the prototype. |
| The consent writer, reader and claim | `app.record_customer_consent`; `app.customer_consent_status`; `app.claim_conversion_deliveries` | UNAFFECTED | No body, grant, policy or trigger changes; the writer's `md5(prosrc)` with its three triggers reads `44ac35592d16fd1c06df648e6e6ca62b`/3 before and after the mutants. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=163, Tests=3086`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 163/3086, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/625 catalog). 163 files whose literal `plan(N)` values sum to 3086. |
| The surface recorded | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22 and 24 | WRITE | Test 163's `-- ATTACK-CLASSES:` line declares the ten classes with CONCURRENCY, REPLAY and OBSERVABILITY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Coverage 49: 25 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 29 `NOT-RECORDED`; all 49 `ADVERSARIAL`. |
| Measured state that moves | manifest suite figure; `ai-map.json` and `repository-index.md` | WRITE | 162 → 163 files and 3077 → 3086 assertions (Check 15). Migrations 258, tables 78 and client RPCs 80 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 4 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC changes; the generator's output is identical to the stored file. It is in Write Scope because Check L3 regenerates it. |
| The gap register | `MASTER_GAP_REGISTER.md` | UNAFFECTED | No finding; positions and DC-15 are recorded in the disposition row. |
| Primary and Secondary | hosted databases | UNAFFECTED | Nothing links, pushes or deploys; Primary was only read, read-only. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | With the records applied on the prototype and no contract present, consistency reports exactly one item, Check 22's pointer to this contract's file, which allocation creates; Checks 15, 21 and 24 pass. |
| The four CI-only guard self-tests | `scripts/test_*_guard.ps1`; `orvion-acceptance` | VERIFY | Unchanged scripts, run by `orvion-acceptance` on the exact candidate SHA before `main` may move to it; not run locally. |
| Active task and generated discovery | Native Boot and manifest projections | WRITE | Existing pointer and completion synchronization and the native generator only. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Selected bytes and baseline anchors | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 1 | Step 3 | Step 4 |
| Own native profiles and fresh verification | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: none of the controls that govern this record is added or changed: `app.record_customer_consent` and its `app.authorize('CREATE_CUSTOMER')` (step-up per `app.requires_mfa`), the append-only, actor and catalog triggers, the missing table grants, RLS tenant isolation and the subscription gate's exemption.

Added Property: the measured behaviour is executable, so the suite turns red when it changes: step-up is charged on the one writer exactly where the role is MFA-bound; an archive is not a merge; billing never decides the customer's consent in either direction.

Causal Negative: the probes (`customer_consents` slice records, before any test existed) measured the same behaviour; each mutant below, installed, turns its assertions red.

Positive Test Design: one active tenant with an `owner` and an `employee` and two customers, one archived without a merge; a second tenant whose subscription ends after its customer is written. Positive controls: the owner at `aal2` and the employee at `aal1` record, and the archived and lapsed decisions record.

Negative Test Design:
- **Auth:** the owner at `aal1` is refused 42501 with `multi-factor authentication required for this role`.
- **Business:** the employee's later GRANT is current and attributed to the employee; the lapsed tenant's GRANT is current.
- **State:** the archived customer's withdrawal is current.
- **Premise:** the lapsed tenant's ordinary customer write is refused 42501.

Non-Empty Population Obligation: the fixture holds two tenants, three users, three role grants, three customers and three subscriptions before the first assertion; each refusal is asserted by exact SQLSTATE and each decision by its exact status.

Mutation Obligation: each mutant was installed inside test 163's own rolled-back transaction on the prototype stack, proven installed, run, then rolled back; the writer's `md5(prosrc)` and trigger count were proven equal (`44ac3559`/3) with 0 failures unmutated.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | step-up removed from the writer | 163 assertion 1 |
| M2 | the subscription write gate applied to consents | 163 assertions 8–9 |
| M3 | archived customers refused | 163 assertions 5–6 |

Post-Implementation Proof Obligation: all of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts and repository consistency.

## Implementation Steps

1. Check whether `supabase/tests/163_the_consent_record_audit_test.sql` contains `plan(9)`; if so record Already Applied when its Git blob is b636fc860e16127d63e5beb48fcb87b011743c5e, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 163, 9 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 48 -- `customer_consents` audited and recorded, not repaired.
   --
   -- ATTACK-CLASSES: AUTH STATE BUSINESS DOOR TENANT PRIVILEGE INPUT CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
   --   DOOR, TENANT, PRIVILEGE, INPUT -- attacked again in this slice and held; their assertions live in `142_...`
   --     (no table door, the server's actor and time, another tenant refused, CREATE_CUSTOMER required, only granted
   --     or denied) and `144_...` (a merged identity takes no decision, a newer DENIED on a merged identity governs),
   --     so they are not repeated here.
   --   OBSERVABILITY=N/A -- the record is its own audit trail: append-only, with the server's actor and time (142);
   --     a decision emits no event by SPEC-240's design.
   --   CONCURRENCY=N/A -- pgTAP runs one session; SPEC-244 recorded the two-session proofs of a merge against a
   --     decision on either identity, both orders.
   --   REPLAY=N/A -- every decision is a new record by design; no token, nonce or idempotency key.
   --
   -- What this file adds is what the slice measured and no test held:
   --   AUTH: the one writer charges step-up exactly where `app.requires_mfa` does -- an owner at aal1 is refused, at
   --     aal2 records -- and an employee, whose role is not MFA-bound, records at aal1. That is SPEC-240's choice of
   --     CREATE_CUSTOMER as the authority, recorded as a position: whoever captures a customer captures its decision.
   --   STATE: an archived customer that was never merged still takes a withdrawal (only the merge record refuses).
   --   BUSINESS: a tenant whose writes the subscription gate refuses still records a GRANT, not only a withdrawal: the
   --     decision is the customer's own fact, and refusing it would leave the record false. Position; test 35 states
   --     the exemption's reason for withdrawals.
   -- Not pinned: `service_role` TRUNCATE empties the table (no trigger refuses TRUNCATE on any append-only table).
   --   It fails closed (no record reads as unspecified, never granted) and is DC-15's service_role blast radius;
   --   `service_role` grants differ by environment (PAR-5), so a local pin would measure the platform.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(9);

   insert into auth.users (id, email) values
     ('16300000-0000-0000-0000-0000000000a1','owner@c163.test'),
     ('16300000-0000-0000-0000-0000000000a2','emp@c163.test'),
     ('16300000-0000-0000-0000-0000000000a3','lapsed@c163.test');
   insert into public.tenants (id, name, slug, status) values
     ('16300000-0000-0000-0000-000000000001','Consent Travel','consent-travel-163','active'),
     ('16300000-0000-0000-0000-000000000002','Lapsed Travel','lapsed-travel-163','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, created_at)
   select t, sp.id, 'active', now() - interval '2 days' from public.subscription_plans sp,
     (values ('16300000-0000-0000-0000-000000000001'::uuid), ('16300000-0000-0000-0000-000000000002'::uuid)) v(t)
   where sp.plan_code = 'enterprise';
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('16300000-0000-0000-0000-000000000011','16300000-0000-0000-0000-000000000001','Owner','owner@c163.test',true,'16300000-0000-0000-0000-0000000000a1'),
     ('16300000-0000-0000-0000-000000000012','16300000-0000-0000-0000-000000000001','Handler','emp@c163.test',true,'16300000-0000-0000-0000-0000000000a2'),
     ('16300000-0000-0000-0000-000000000021','16300000-0000-0000-0000-000000000002','Lapsed handler','lapsed@c163.test',true,'16300000-0000-0000-0000-0000000000a3');
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.t, v.u, r.id, 'tenant'
   from (values ('16300000-0000-0000-0000-000000000001'::uuid,'16300000-0000-0000-0000-000000000011'::uuid,'owner'),
                ('16300000-0000-0000-0000-000000000001','16300000-0000-0000-0000-000000000012','employee'),
                ('16300000-0000-0000-0000-000000000002','16300000-0000-0000-0000-000000000021','employee')) v(t,u,rc)
   join public.roles r on r.code = v.rc;
   -- d1 A and d2 B in the active tenant, B archived without a merge; d3 G in the tenant whose billing then ends.
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('16300000-0000-0000-0000-0000000000d1','16300000-0000-0000-0000-000000000001','person','A'),
     ('16300000-0000-0000-0000-0000000000d2','16300000-0000-0000-0000-000000000001','person','B'),
     ('16300000-0000-0000-0000-0000000000d3','16300000-0000-0000-0000-000000000002','person','G');
   update public.customers set is_archived = true, archived_at = now(), archived_by = '16300000-0000-0000-0000-000000000011',
          archive_reason = 'left' where id = '16300000-0000-0000-0000-0000000000d2';
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at, ends_at, created_at)
   select '16300000-0000-0000-0000-000000000002', id, 'active', now() - interval '2 days', now() - interval '1 day', now() - interval '1 day'
   from public.subscription_plans where plan_code = 'enterprise';

   create function pg_temp.st(p_tenant text, p_customer text) returns text language sql as $$
     select coalesce(app.customer_consent_status(p_tenant::uuid, p_customer::uuid, 'ad_user_data'), 'null')
   $$;

   -- =============================================================================================
   -- 1-4. AUTH: step-up is charged where the role is MFA-bound, and only there.
   -- =============================================================================================
   set local role authenticated;
   select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
   select throws_ok(
     $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d1','ad_user_data','denied','phone','asked to stop')$$,
     '42501', 'multi-factor authentication required for this role',
     'AUTH: an owner without step-up cannot record a consent decision');
   select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
   select lives_ok(
     $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d1','ad_user_data','denied','phone','asked to stop')$$,
     'POSITIVE CONTROL: the same owner with step-up records it');
   select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a2","aal":"aal1"}',true);
   select lives_ok(
     $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d1','ad_user_data','granted','phone','agreed on the call')$$,
     'AUTH (position, SPEC-240): an employee, whose role is not MFA-bound, records a decision at aal1');
   reset role;
   select set_config('request.jwt.claims','',true);
   select is(
     pg_temp.st('16300000-0000-0000-0000-000000000001','16300000-0000-0000-0000-0000000000d1') || '/' ||
     (select c.created_by::text from public.customer_consents c
       where c.customer_id = '16300000-0000-0000-0000-0000000000d1' order by c.seq desc limit 1),
     'granted/16300000-0000-0000-0000-000000000012',
     'BUSINESS: the employee''s later GRANT is the current decision, attributed to the employee');

   -- =============================================================================================
   -- 5-6. STATE: an archive is not a merge.
   -- =============================================================================================
   set local role authenticated;
   select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a2","aal":"aal1"}',true);
   select lives_ok(
     $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d2','ad_user_data','denied','email',null)$$,
     'STATE: an archived customer that was never merged still takes a withdrawal');
   reset role;
   select set_config('request.jwt.claims','',true);
   select is(pg_temp.st('16300000-0000-0000-0000-000000000001','16300000-0000-0000-0000-0000000000d2'), 'denied',
     '...and it is the current decision');

   -- =============================================================================================
   -- 7-9. BUSINESS: billing never decides the customer's consent, in either direction.
   -- =============================================================================================
   set local role authenticated;
   select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a3","aal":"aal1"}',true);
   select throws_ok(
     $$update public.customers set full_name = 'G2' where id = '16300000-0000-0000-0000-0000000000d3'$$,
     '42501', null,
     'PREMISE: the tenant''s billing has ended -- an ordinary customer write is refused');
   select lives_ok(
     $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d3','ad_user_data','granted','phone',null)$$,
     'BUSINESS (position): the customer''s GRANT is recorded whatever the tenant''s billing state');
   reset role;
   select set_config('request.jwt.claims','',true);
   select is(pg_temp.st('16300000-0000-0000-0000-000000000002','16300000-0000-0000-0000-0000000000d3'), 'granted',
     '...and it is the current decision');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is b636fc860e16127d63e5beb48fcb87b011743c5e.

2. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**49 of 78 recorded · 25 `; if so record Already Applied when its Git blob is bbd4b7f10e22b0eab2e6f1a844ea99a881f77160, and otherwise stop and report. Otherwise make exactly these 4 edits (the freshness entry, coverage 49 of 78 and the customer_consents row), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-11 (**slice 47 — `user_role_assignments` selected by Exposure 7, coverage 684; runner-up `customer_consents` at 6/18.** Coverage **47 → 48 of 78**. URA-1: a `ceo` at `aal1` re-pointed live role grants by direct UPDATE (an employee to owner, the owner's grant to another user, a scope, a start). URA-2: none of it was recorded, at `aal2` either. URA-3: a lone owner demoted their own grant and left the tenant with no administrator. SPEC-302 closes all three here, so the row is `AUDITED`.)
   ```
   with
   ```text
   Last updated: 2026-11-11 (**slice 48 — `customer_consents` selected by Exposure 6, coverage 18; runner-up `document_retention_policies` at 6/36.** Coverage **48 → 49 of 78**. No finding: the writer's step-up, the archived customer's withdrawal and the lapsed tenant's GRANT are pinned; the door, tenant, privilege and input attacks held again and stay pinned by tests 142 and 144; `service_role`'s TRUNCATE is DC-15's. SPEC-303 records it, so the row is `AUDITED`. No other row changed.)

   Previously: 2026-11-11 (**slice 47 — `user_role_assignments` selected by Exposure 7, coverage 684; runner-up `customer_consents` at 6/18.** Coverage **47 → 48 of 78**. URA-1: a `ceo` at `aal1` re-pointed live role grants by direct UPDATE (an employee to owner, the owner's grant to another user, a scope, a start). URA-2: none of it was recorded, at `aal2` either. URA-3: a lone owner demoted their own grant and left the tenant with no administrator. SPEC-302 closes all three here, so the row is `AUDITED`.)
   ```

   b) replace the line
   ```text
   **48 of 78 recorded · 24 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 30 `NOT-RECORDED`.**
   ```
   with
   ```text
   **49 of 78 recorded · 25 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 29 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 48 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 49 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `customer_consents` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `customer_consents` | **AUDITED** | ADVERSARIAL | `SPEC-303-the-consent-record-audit` | — | `163_the_consent_record_audit_test.sql` (9 assertions, ten attack classes declared, CONCURRENCY, REPLAY and OBSERVABILITY N/A) proves that the one writer, `app.record_customer_consent`, charges step-up exactly where `app.requires_mfa` does: an `owner` at `aal1` is refused and the same owner at `aal2` records, while an `employee`, whose role is not MFA-bound, records at `aal1` and the server attributes the decision to the employee. An archived customer that was never merged still takes a withdrawal. A tenant whose billing has ended, refused an ordinary customer write, still records the customer's GRANT, which is then current. Mutants M1-M3 (step-up removed from the writer, the billing gate applied to consents, archived customers refused), each installed and restored md5-identical, are each killed. No finding. Re-measured and held, pinned by `142_...` and `144_...`: no table door, append-only for the table owner too, the server's actor and time, CREATE_CUSTOMER required, another tenant refused, only `ad_user_data` with granted or denied, the channel catalog, blank evidence stored NULL; a merged identity refuses new decisions and the survivor's newer decision governs both. Positions: any CREATE_CUSTOMER holder decides for any customer of the tenant (SPEC-240's authority; customers carry no branch scope); a lapsed tenant records a GRANT as well as a withdrawal, because the decision is the customer's own fact (test 35 states the exemption for withdrawals). Swept and classified as non-defects: `app.customer_consent_status` is `postgres`-only and its one consumer, `app.claim_conversion_deliveries`, gates `qualified_phone_call` on `granted`; the two-session merge proofs are SPEC-244's; `service_role`'s TRUNCATE empties the table with no trigger refusing it, fails closed (no record reads as unspecified, never granted) and is DC-15's `service_role` blast radius (PAR-5), not pinned because those grants differ by environment |
   ```

   The resulting file's Git blob is bbd4b7f10e22b0eab2e6f1a844ea99a881f77160.

3. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **163 files / 3086 assertions**`; if so record Already Applied when its Git blob is 0b9c4115c7f052872163f6f477e2b5305991e9ae, and otherwise stop and report. Otherwise make exactly this one edit (the suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: Last fully verified 2026-11-11. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 258 migrations** (latest `20261111140000`), ledger `dec3a3dbe82e0568e8d98e5418f23436`, full-function-surface hash `1273cd1b48c879d51aedce0e9818f89b` (337 functions) identical on both; structural-surface hash `48183b9ce5d79728a1a952f38cbfbbc3` (3,152 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-11-11; ledger **read FROM Primary** (GUARD-1). **80 client RPCs**. Suite **162 files / 3077 assertions** (Pass A = Pass B, 2026-11-11).
   ```
   with
   ```text
   Live state: Last fully verified 2026-11-11. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 258 migrations** (latest `20261111140000`), ledger `dec3a3dbe82e0568e8d98e5418f23436`, full-function-surface hash `1273cd1b48c879d51aedce0e9818f89b` (337 functions) identical on both; structural-surface hash `48183b9ce5d79728a1a952f38cbfbbc3` (3,152 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-11-11; ledger **read FROM Primary** (GUARD-1). **80 client RPCs**. Suite **163 files / 3086 assertions** (Pass A = Pass B, 2026-11-11).
   ```

   The resulting file's Git blob is 0b9c4115c7f052872163f6f477e2b5305991e9ae.

4. **Check** for a `Local certification` Execution Log entry. If absent:
   - Confirm that `supabase/tests` holds 163 files whose literal `plan(N)` values sum to 3086; if either differs, stop.
   - Regenerate `ai-map.json` and `repository-index.md` (stored LF) with the canonical generator, and confirm the API-contract generator's output is identical to `MASTER_API_CONTRACT.md`.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] Test 163 is the frozen bytes; `check: blob supabase/tests/163_the_consent_record_audit_test.sql b636fc860e16127d63e5beb48fcb87b011743c5e`
- [ ] The disposition record carries `customer_consents` AUDITED / ADVERSARIAL and coverage 49 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md bbd4b7f10e22b0eab2e6f1a844ea99a881f77160`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **163 files / 3086 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @2cc8fea589d8c37cbc59cd2482664e5698c65ded`
- [ ] Migration CI remains exact; `check: same .github/workflows/migration-ci.yml @2cc8fea589d8c37cbc59cd2482664e5698c65ded`
- [ ] The consent writer's migration remains exact; `check: same supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql @2cc8fea589d8c37cbc59cd2482664e5698c65ded`
- [ ] No file under `supabase/migrations/` changed and no database object was created, altered or dropped; Primary `vrvtsxexkiiiivlkdxzp` was not written and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1–M3 are each killed with installation and restoration proven.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-303: Batch 6 Slice 48 — the consent record audited and recorded, no finding (customer_consents AUDITED, 49 of 78); native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline 2cc8fea589d8c37cbc59cd2482664e5698c65ded and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `8a28aa9473d993af7b42dc748a44c6db910a976d` |
| `_ORVION_CANONICAL/manifest.md` | `c186702e413dee1cf1aeb70201ba7b01771c6041` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md, SPEC-240, SPEC-244 and SPEC-259 at 2cc8fea589d8c37cbc59cd2482664e5698c65ded; the owner's instructions of 2026-11-08 and 2026-11-11 (recorded outside this repository). This is the one Draft for this surface, finalized after the adversarial review and the evidence refresh its Draft Assurance records; correctness remains native and independent.
