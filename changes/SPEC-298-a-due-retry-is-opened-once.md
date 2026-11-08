# Change Request — SPEC-298

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 43 makes a notification delivery's attempt number unique per chain, so that overlapping dispatchers open a due retry once and send it once (ND-1).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `a21a0ec`, on the live local catalog, ranks `notification_deliveries` first: Exposure 7, coverage 42, NOT-RECORDED (runner-up `approval_requests` 7/52). The manifest's Next capability names that selector, never a copy of its result.
- **The rule.** `app.claim_notification_deliveries` states "two concurrent dispatchers safe". Its step 3 (the claim) is, by `for update ... skip locked`. Its step 2 (open the due retry) is not: its `not exists` cannot see another dispatcher's uncommitted attempt N+1, and nothing made (notification_id, channel_code, attempt_number) unique; `notification_deliveries_chain_idx` is a plain index.
- **Measured at `a21a0ec`** on the local stack: one `email` delivery at attempt 1, failed six minutes earlier, so its retry was due. Session A ran `begin; claim('email',50); pg_sleep(4); commit;`, session B ran the same claim 1.5 s later. The chain ended `1 failed, 2 pending claimed, 2 pending claimed`, and each session's claim returned the notification once: **ND-1 (Medium)**, the recipient is sent the same message twice. The sleep only widens the window; any two overlapping calls may interleave this way.
- **The repair.** A UNIQUE constraint `notification_deliveries_attempt_key` on (notification_id, channel_code, attempt_number) replaces the chain index it makes redundant, and step 2 adds `on conflict on constraint notification_deliveries_attempt_key do nothing`. The second dispatcher waits on the first one's key, finds it taken and claims other work; a direct duplicate on any path raises 23505. The constraint is named because the function's OUT parameters are `notification_id` and `attempt_number`, so a column-list conflict target is ambiguous in PL/pgSQL. The rest of the function is the `202607060900` body unchanged; `create or replace` keeps its owner and grants.
- **Writers, read from the catalog.** The claim and `app.record_notification_delivery_result` (EXECUTE `orvion_integration` only); `app.process_lead_sla` and both credit-threshold evaluators each insert one attempt 1 for a notification they have just created, so none can collide with the key. `authenticated` holds SELECT only; no Edge Function reads or writes the table.
- **Swept and found sound, pinned rather than changed:** the recipient reads its deliveries and a same-tenant peer and a rival read none; `authenticated` cannot write the table or execute the claim or result RPCs; a late result raises (test 100, `MASTER_INTEGRATION_CATALOG` §2a item 6).
- **Recorded positions, not repaired:** `app.record_notification_delivery_result` accepts a result for a pending row no dispatcher claimed; only `orvion_integration` can call it. Reopening trigger: a second integration identity. A send that outlives the 30-minute lease is failed and retried, so a slow provider can still receive the message twice: the lease trade-off SPEC-123 chose. `notification_deliveries_notification_id_idx` is now covered by the key's leading column and is left alone (housekeeping, not this finding).
- **Latent on Primary:** `vrvtsxexkiiiivlkdxzp` holds 0 tenants and 0 notification deliveries, with 0 duplicate attempt groups (read-only, 2026-11-08), so `add constraint` cannot fail there and no data repair is needed.

## Risks

- **A duplicate already stored would stop the migration.** `add constraint` refuses it with 23505 and the whole migration rolls back before anything changes (observed on a stack holding the probe's duplicate). Step 5 reads Primary for duplicates, and Step 7 re-reads them immediately before deployment.
- **The second dispatcher now waits** on the first one's uncommitted attempt instead of duplicating it: 2.6 s in the race, the length of the first transaction. Its claim then skips that notification and serves the rest.
- **Index change.** The plain chain index is dropped and the constraint's own unique index on the same columns serves the retry read; the index count stays 300.
- **Primary deployment is irreversible** and runs only under the exact-SHA Gate-2 record of Step 6. Approval of this contract does not authorize it. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish and promote ~12:05; run slice 1 through its exit without the owner ~17:30), recorded outside this repository; never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-298-a-due-retry-is-opened-once.md`
- `supabase/migrations/20261108120000_a_due_retry_is_opened_once.sql`
- `supabase/tests/158_a_due_retry_is_opened_once_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607060900_a_delivery_obligation_that_is_attempted_retried_and_abandoned.sql`
- `supabase/migrations/202607061000_the_sla_records_its_delivery_obligation_like_every_other_alert.sql`
- `supabase/tests/100_notification_delivery_lifecycle_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/parity_surface.sql`
- `scripts/check_database_parity.ps1`
- `scripts/check_primary_ledger.ps1`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/architecture-decision-records.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `supabase/migrations/202607060900_a_delivery_obligation_that_is_attempted_retried_and_abandoned.sql` (the claim and the chain index)
- `supabase/tests/100_notification_delivery_lifecycle_test.sql` (the lifecycle it pins)
- `reports/master/MASTER_GAP_REGISTER.md`; `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11
- `changes/SPEC-278-a-used-ledger-account-keeps-its-meaning.md` and `changes/SPEC-279-the-ledger-account-slice-is-closed-and-published.md` (the last Primary-deploying slice and its correction)

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: SPEC-298-V1 adds a UNIQUE constraint on (notification_id, channel_code, attempt_number) in place of the plain chain index and makes the claim's step 2 skip a taken attempt with `on conflict on constraint`; test 158 pins the key, the skip, the replay, the injection, the privileges and the door, and the register and disposition record ND-1 and the surface.

Pass 2 Adversarial Review: SPEC-298-V2 challenged each part. An advisory or row lock was rejected: it protects only the claim path, while the key covers every writer. A column-list conflict target was rejected: the function's OUT parameters make it ambiguous. Keeping the chain index beside the key was rejected as a duplicate mechanism (EC-11). An ORDER BY for deadlock avoidance was tried and dropped: both sessions used the same plan, so it was not earned. Failing the claim instead of skipping was rejected: it would stall every other delivery in the batch. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-08. SPEC-298-V3 re-measured on byte-identical files in a disposable clone of `a21a0ec` with the project-local CLI 3.0.0: the clean reset, test 158, pgTAP Pass A and B, the three HTTP suites, smoke, the race, both mutants, the causal negative, the structural fingerprints before and after, the generators and repository consistency (Consumer Closure); and read Primary read-only for its ledger, its project URL and its duplicate-attempt groups.

Selected Version: SPEC-298-V3; selected: the smallest repair that closes ND-1 on every write path (one key replacing a redundant index, one conflict clause), proven on byte-identical files by the full local protocol, two killed mutants, the race and the causal negative

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The attempt number is unique per (notification, channel) | `app.claim_notification_deliveries` step 2; the three producers; any platform writer | WRITE | Migration SHA-256 `e0fc6b11ab72f70200c960ca9527cf423726cd19ec86c04d580f8168ec0bdfaf`, md5 `120df9bf5eddeb04d41f3605f199bfcc`, 12767 bytes, LF, ASCII. A clean reset gives 254 migrations, latest `20261108120000`, claim `md5(prosrc)` `6781ead55e0e44ff4f829845ce584153`. A second attempt 1 is refused 23505 on the platform path; another channel's attempt 1 lands. |
| A due retry is opened once under overlapping dispatchers | the dispatcher (`orvion_integration`); the recipient | WRITE | Two-session race on the final bytes: A `BEGIN 1 COMMIT`, B waited 2.6 s and returned 0, chain `1:failed, 2:pending:claimed` once. |
| The chain index is replaced by the key's own index | the retry read in step 2 | WRITE | Same columns; index count 300 before and after; the full suite and the HTTP suites pass. |
| The lifecycle, the lease, the ceiling and the backoff | test 100; `app.record_notification_delivery_result`; `app.process_lead_sla`; both credit evaluators | VERIFY | Only step 2 of the function body changes; test 100 and every other pgTAP file pass. |
| Test 158 | `supabase/tests` | WRITE | SHA-256 `77c39a84e1f838874df4bcce5c2b89662aa3a63ee2e00660f74895ce3d6f6380`, md5 `2ba2e1b9b7c182a9806a19f8619bd535`, 12439 bytes, LF, ASCII, `plan(16)`: 16/16. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites | VERIFY | Pass A `Files=158, Tests=3010`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 158/3010, PASS. 158 files whose literal `plan(N)` values sum to 3010. |
| Smoke | `scripts/verify_database.sql` | VERIFY | `ALL CHECKS PASSED` (78 tables, 71/623 catalog). No table, catalog value, policy, grant or transition is added. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (253): `_combined` `56625ae4118e1ddc85bab99114b17899`/3136, equal to the recorded Primary evidence. After (254): functions `c9b4d9a1f8a5d6f400e6d64d266f3887`/332, constraints `96ccb990b5c3b6554b95f2539fbfcd45`/528 (+1), indexes `9f7369db0309dd9cd935172bf145f54c`/300, `_combined` `2a15deb38b76a75b9da991b955ea31b3`/3137; the rest unchanged. Step 8 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC is added, removed or changed in signature; the generator regenerates it identical (80 RPCs). In Write Scope because a migration makes Check L3 apply. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 253 → 254 migrations, latest `20261108120000`, ledger fingerprint `7e7a7fcfd603322c545f7bbc8322c789`; 157 → 158 files and 2994 → 3010 assertions; coverage 43 → 44 of 78. Catalog 71/623, tables 78 and client RPCs 80 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 9 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin, so the selector and the disposition record name the next slice and the coverage. |
| ND-1 fixed; the surface recorded | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25, 29 | WRITE | No `ND-` row exists at `a21a0ec`. Test 158's `-- ATTACK-CLASSES:` line declares eight classes with BUSINESS and OBSERVABILITY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. The ND-1 row has Owner `—` and is settled. Coverage 44: 20 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 34 `NOT-RECORDED`. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–4 applied, consistency reports exactly seven measured-state items (253 vs 254 migrations, latest, ledger fingerprint, 157 vs 158 files, 2994 vs 3010 assertions, the Primary-evidence record twice) and Checks 21–29 pass. Step 8 makes them true; the one implementation commit is made only after it. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 7 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, mutants, race and causal negative hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Primary holds no duplicate attempt and lacks the target migration | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 7 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 8 | Step 9 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 8 | Step 9 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 8 | Step 9 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 8 | Step 9 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: Step 3's `for update ... skip locked` serializes the claim of an existing row, and step 2's `not exists` stops a second retry only against committed rows. `notification_deliveries_chain_idx` is not unique. No constraint, lock or trigger stops two transactions from each inserting attempt N+1.

Added Property: For every writer, a (notification, channel) chain holds each attempt number at most once, and a dispatcher that meets another's attempt skips it instead of sending it again.

Causal Negative: On a clean reset with the migration held aside (253 migrations), test 158 fails assertions 1–3 and 6–7, then aborts at 7 of 16, and the two-session race returns 1 to session B after 0.1 s with the chain `1:failed, 2:pending:claimed, 2:pending:claimed`: ND-1 reproduced.

Positive Test Design: One tenant with a recipient, a peer and a rival tenant; one `email` delivery at attempt 1 failed past its backoff. Positive controls: another channel's attempt 1 lands; the claim opens attempt 2 once and claims it; the chain reads `1:failed, 2:pending:claimed`; the recipient reads its 3 deliveries.

Negative Test Design:
- **Key:** a second attempt 1 on the platform path is refused 23505.
- **Replay:** a second claim opens nothing.
- **Injection:** with the key dropped in a savepoint, a second attempt 2 is stored; after rollback it is refused again.
- **Tripwire:** the claim's text names the constraint in its `on conflict` (labelled as a text check).
- **Privilege:** the claim is SECURITY DEFINER with an empty `search_path`; only `orvion_integration` may execute the claim, and `authenticated` and `anon` may execute neither the claim nor the result RPC.
- **State:** a late result raises.
- **Door and tenancy:** an `authenticated` insert is refused 42501; the peer and the rival read none.

Non-Empty Population Obligation: The fixture holds one tenant with three users, a rival tenant with one, one notification with three deliveries, and one due retry. Each refusal is asserted by exact SQLSTATE, the chain by its exact text, and the reads by exact counts.

Mutation Obligation: Each mutant is installed on the prototype stack, proven installed by a changed fingerprint, run against test 158 and the race, then restored and proven equal (`md5(prosrc)` `6781ead55e0e44ff4f829845ce584153`, the key present) with 16/16 before the next. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | the key dropped | 158 assertions 1 and 3; the claim errors 42704, so both race sessions fail closed and nothing is sent |
| M2 | the `on conflict` clause removed | 158 assertion 10; in the race B waits 2.6 s then fails 23505 and claims nothing |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts, repository consistency and the recorded Primary evidence. Before Step 7: the focused tests, the mutants, the race, the causal negative and the fresh Primary baseline of Step 5.

## Implementation Steps

1. Check whether `supabase/migrations/20261108120000_a_due_retry_is_opened_once.sql` contains `SPEC-298 (Batch 6 Slice 43, ND-1)`; if so record Already Applied when its Git blob is 333baa4296c37421ec126da166f282c72935702d, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the migration: the attempt key replaces the chain index, and the claim names it in step 2), and change nothing else:

   ```text
   -- SPEC-298 (Batch 6 Slice 43, ND-1) -- a due retry is opened once, however many dispatchers claim
   -- at the same moment.
   --
   -- =================================================================================================
   -- THE MEASURED DEFECT
   --
   -- `app.claim_notification_deliveries` says "two concurrent dispatchers safe". Its step 3 (the
   -- claim) is, by `for update ... skip locked`. Its step 2 (open the due retry) is not: the
   -- `not exists` that stops a second retry cannot see another dispatcher's UNCOMMITTED attempt N+1,
   -- and nothing made (notification_id, channel_code, attempt_number) unique -- the chain index that
   -- serves the retry read was a plain index.
   --
   -- Measured 2026-11-08 at a21a0ec on the local stack: one `email` delivery at attempt 1, failed six
   -- minutes earlier, so its retry was due. Session A ran `begin; claim('email',50); pg_sleep(4);
   -- commit;` and session B ran `claim('email',50)` 1.5 s later. The chain ended `1 failed, 2 pending
   -- claimed, 2 pending claimed`, and each session's claim returned the notification once: the
   -- recipient is sent the same message twice. The sleep only widens the window; any two overlapping
   -- calls may interleave this way.
   --
   -- =================================================================================================
   -- THE REPAIR, AND WHY THIS SHAPE
   --
   -- 1. The attempt number is unique per chain: a UNIQUE CONSTRAINT on (notification_id,
   --    channel_code, attempt_number) replaces the plain chain index, which it makes redundant (the
   --    retry read still walks the same columns, backwards). A second attempt N on any path -- the
   --    claim, a producer, the platform -- is refused 23505. Every producer writes attempt 1 for a
   --    notification it has just created, once (read from the catalog), so none can collide.
   -- 2. Step 2 names that constraint in `on conflict ... do nothing`. A second dispatcher whose
   --    insert meets the first one's uncommitted attempt N+1 WAITS for it; if the first commits, the
   --    second inserts nothing and goes on to claim other work; if the first rolls back, the second
   --    opens the retry itself. A constraint rather than a bare unique index because the function's
   --    own OUT parameters are named `notification_id` and `attempt_number`, so a column-list
   --    conflict target would be ambiguous inside PL/pgSQL; `on constraint` is not.
   --
   -- Everything else in the function is the 202607060900 body unchanged, step 2 aside: the lease, the ceiling,
   -- the backoff, the claim, the payload. `create or replace` keeps its owner and its grants
   -- (EXECUTE for `orvion_integration` only).
   --
   -- WHAT IS DELIBERATELY NOT CHANGED, each recorded as a position in the disposition record:
   --   * `app.record_notification_delivery_result` accepts a result for a pending row no dispatcher
   --     claimed; only `orvion_integration` can call it. Reopening trigger: a second integration
   --     identity.
   --   * A send that outlives the 30-minute lease is failed and retried, so a slow provider can still
   --     receive the message twice. That is the lease trade-off SPEC-123 chose and this table copied.
   --   * `notification_deliveries_notification_id_idx` is now covered by the key's leading column. It
   --     is left alone: removing it is housekeeping, not this finding.
   --
   -- Primary: a duplicate (notification_id, channel_code, attempt_number) already stored there would
   -- make `add constraint` fail, and the whole migration with it, before anything changes. The
   -- readiness gate reads Primary for one before deployment.

   alter table public.notification_deliveries
       add constraint notification_deliveries_attempt_key
       unique (notification_id, channel_code, attempt_number);

   drop index public.notification_deliveries_chain_idx;

   comment on constraint notification_deliveries_attempt_key on public.notification_deliveries is
       'SPEC-298 (ND-1): one row per attempt number per chain, so two dispatchers can never both open attempt N+1. Named by the on-conflict clause of app.claim_notification_deliveries step 2.';

   create or replace function app.claim_notification_deliveries(
       p_channel_code text,
       p_batch integer default 50
   )
   returns table (
       delivery_id            uuid,
       notification_id        uuid,
       tenant_id              uuid,
       attempt_number         integer,
       recipient_user_id      uuid,
       recipient_email        text,
       recipient_name         text,
       notification_type_code text,
       title                  text,
       body                   text,
       related_entity_type    text,
       related_entity_id      uuid
   )
   language plpgsql
   security definer
   set search_path = ''
   as $$
   declare
       -- The lease. Identical to SPEC-123's, and identical for the same reason: it is long enough that
       -- a healthy run never trips it and short enough that a dead run is recovered within one
       -- operator's attention span.
       c_lease        constant interval := interval '30 minutes';
       -- The ceiling. NOT re-derived from external practice -- this is the number SPEC-123 already
       -- chose for this repository's outbox, and two outboxes disagreeing about how many times ORVION
       -- tries before giving up would be a difference with no reason behind it.
       c_max_attempts constant integer  := 5;
       -- The backoff base. 5 * 2^(n-1) => 5, 10, 20, 40 minutes; the fifth attempt falls about 75
       -- minutes after the first failure. Widening rather than immediate, which is the one point on
       -- which transactional-email practice is unanimous and on which SPEC-123's no-backoff model
       -- cannot be copied.
       c_backoff_base constant interval := interval '5 minutes';
       v_row record;
   begin
       if p_channel_code is null then
           raise exception 'p_channel_code is required';
       end if;
       if p_batch is null or p_batch < 1 then
           raise exception 'p_batch must be at least 1';
       end if;

       -- ---------------------------------------------------------------------------------------------
       -- STEP 0 -- expire leases. A run that died between claim and acknowledgement leaves a row
       -- `pending` with `claimed_at` set and no result. Without this it is stranded for ever, which is
       -- PH8-1's defect on the conversion side, avoided here rather than repeated.
       for v_row in
           update public.notification_deliveries d
           set delivery_status_code = 'failed',
               failed_at = now(),
               error_message = 'LEASE_EXPIRED: no delivery result recorded within ' || c_lease::text
                               || '; attempt terminated by app.claim_notification_deliveries'
           where d.channel_code = p_channel_code
             and d.delivery_status_code = 'pending'
             and d.claimed_at is not null
             and d.claimed_at < now() - c_lease
           returning d.id, d.tenant_id, d.notification_id, d.attempt_number
       loop
           perform app.record_event(
               v_row.tenant_id, 'notification_delivery_failed', 'notification', v_row.notification_id,
               null, 'pending', 'failed',
               'LEASE_EXPIRED: no delivery result recorded within the lease window',
               jsonb_build_object('delivery_id', v_row.id, 'channel_code', p_channel_code,
                                  'attempt_number', v_row.attempt_number, 'expired_lease', true,
                                  'lease_interval', c_lease::text),
               'warning');
       end loop;

       -- ---------------------------------------------------------------------------------------------
       -- STEP 1 -- dead-letter the exhausted. A chain is exhausted when its newest attempt has FAILED
       -- and that attempt is the ceiling. Marked terminal so step 2 stops re-opening it and so the row
       -- states that ORVION gave up, rather than leaving an operator to infer it from a count.
       for v_row in
           update public.notification_deliveries d
           set delivery_status_code = 'dead_lettered'
           where d.channel_code = p_channel_code
             and d.delivery_status_code = 'failed'
             and d.attempt_number >= c_max_attempts
             and not exists (
                   select 1 from public.notification_deliveries later
                   where later.notification_id = d.notification_id
                     and later.channel_code = d.channel_code
                     and later.attempt_number > d.attempt_number)
           returning d.id, d.tenant_id, d.notification_id, d.attempt_number, d.error_message
       loop
           perform app.record_event(
               v_row.tenant_id, 'notification_delivery_dead_lettered', 'notification',
               v_row.notification_id, null, 'failed', 'dead_lettered',
               'Delivery abandoned after exhausting its retry ceiling',
               jsonb_build_object('delivery_id', v_row.id, 'channel_code', p_channel_code,
                                  'attempts', v_row.attempt_number,
                                  'last_error', v_row.error_message),
               'warning');
       end loop;

       -- ---------------------------------------------------------------------------------------------
       -- STEP 2 -- open the retries that are due. A new ROW at attempt N+1, never a mutation of the
       -- failed one: the failure and its own error message stay on the record.
       --
       -- SPEC-298 (ND-1): the `not exists` below cannot see another dispatcher's uncommitted attempt
       -- N+1, so the unique key decides: the insert waits on that key and skips it once taken.
       --
       -- `not exists (pending or sent or dead_lettered)` is the whole eligibility rule and it is
       -- deliberately expressed over the chain rather than over this row: it stops a second retry being
       -- opened while one is in flight, stops retrying something already delivered, and stops reviving
       -- something step 1 has just abandoned.
       insert into public.notification_deliveries
           (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number)
       select d.tenant_id, d.notification_id, d.channel_code, 'pending', d.attempt_number + 1
       from public.notification_deliveries d
       where d.channel_code = p_channel_code
         and d.delivery_status_code = 'failed'
         and d.attempt_number < c_max_attempts
         and d.failed_at is not null
         -- The backoff, DERIVED rather than stored. This expression is the single authority for the
         -- retry schedule in the whole system.
         and d.failed_at + (c_backoff_base * (2 ^ (d.attempt_number - 1))) <= now()
         and not exists (
               select 1 from public.notification_deliveries other
               where other.notification_id = d.notification_id
                 and other.channel_code = d.channel_code
                 and (other.attempt_number > d.attempt_number
                      or other.delivery_status_code in ('pending', 'sent', 'dead_lettered')))
       on conflict on constraint notification_deliveries_attempt_key do nothing;

       -- ---------------------------------------------------------------------------------------------
       -- STEP 3 -- claim. `for update ... skip locked` is what makes two concurrent dispatchers safe:
       -- the second call skips rows the first has locked instead of blocking behind them or handing
       -- back the same work twice.
       --
       -- The ORDER BY sits INSIDE the locking sub-select, which is the form PostgreSQL's own Caution
       -- note about `ORDER BY` with a locking clause at READ COMMITTED recommends.
       --
       -- `claimed_at is null` -- not `< now() - lease` -- because step 0 has already converted every
       -- expired lease into a failure, so anything still pending and claimed is genuinely in flight.
       return query
       with claimed as (
           update public.notification_deliveries d
           set claimed_at = now()
           where d.id in (
               select c.id
               from public.notification_deliveries c
               where c.channel_code = p_channel_code
                 and c.delivery_status_code = 'pending'
                 and c.claimed_at is null
               order by c.created_at, c.id
               limit p_batch
               for update skip locked
           )
           returning d.id, d.notification_id, d.tenant_id, d.attempt_number
       )
       select c.id, c.notification_id, c.tenant_id, c.attempt_number,
              n.target_user_id, u.email, u.full_name,
              n.notification_type_code, n.title, n.body,
              n.related_entity_type, n.related_entity_id
       from claimed c
       join public.notifications n on n.id = c.notification_id
       join public.users u on u.id = n.target_user_id;
   end;
   $$;

   -- `create or replace` kept the ACL; restated so the grant model is visible in this file too.
   revoke execute on function app.claim_notification_deliveries(text, integer) from public;
   grant execute on function app.claim_notification_deliveries(text, integer) to orvion_integration;
   ```

   The resulting file's Git blob is 333baa4296c37421ec126da166f282c72935702d.

2. Check whether `supabase/tests/158_a_due_retry_is_opened_once_test.sql` contains `plan(16)`; if so record Already Applied when its Git blob is 970d8be98908c82c174ddb684c32eac673027eed, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 158, 16 assertions), and change nothing else:

   ```text
   -- pgTAP: SPEC-298 (Batch 6 Slice 43, ND-1) -- a due retry is opened once (`20261108120000`).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY REPLAY PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
   --   BUSINESS=N/A -- a delivery carries no money and re-denominates no history; sending one message
   --     twice is CONCURRENCY's question.
   --   OBSERVABILITY=N/A -- opening a retry is not a canon-27 event; each attempt's result is, and
   --     `100_...` pins those events.
   --   CONCURRENCY -- two overlapping dispatchers need two live sessions, which pgTAP does not have.
   --     The race is proven by SPEC-298's two-session harness, with and without the repair; here the
   --     key it rests on is pinned, injected and re-asserted.
   --
   -- ND-1: `app.claim_notification_deliveries` step 2 opened attempt N+1 behind a `not exists` that
   -- cannot see another dispatcher's uncommitted attempt N+1, and nothing made the attempt number
   -- unique per chain. Two overlapping claims each opened and claimed attempt 2, so the recipient was
   -- sent the same message twice. The repair makes (notification_id, channel_code, attempt_number)
   -- unique and has step 2 skip a key another dispatcher holds.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(16);

   insert into auth.users (id, email) values
     ('15800000-0000-0000-0000-0000000000a1','rec@c158.test'),
     ('15800000-0000-0000-0000-0000000000a2','peer@c158.test'),
     ('15800000-0000-0000-0000-0000000000a3','rival@c158b.test');
   insert into public.tenants (id, name, slug, status) values
     ('15800000-0000-0000-0000-000000000001','C158 Travel','c158-travel','active'),
     ('15800000-0000-0000-0000-000000000002','C158 Rival','c158-rival','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select t, sp.id, 'active' from public.subscription_plans sp,
     unnest(array['15800000-0000-0000-0000-000000000001'::uuid,'15800000-0000-0000-0000-000000000002'::uuid]) t
   where sp.plan_code = 'enterprise';
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('15800000-0000-0000-0000-000000000011','15800000-0000-0000-0000-000000000001','Recipient','rec@c158.test',true,'15800000-0000-0000-0000-0000000000a1'),
     ('15800000-0000-0000-0000-000000000012','15800000-0000-0000-0000-000000000001','Peer','peer@c158.test',true,'15800000-0000-0000-0000-0000000000a2'),
     ('15800000-0000-0000-0000-000000000021','15800000-0000-0000-0000-000000000002','Rival','rival@c158b.test',true,'15800000-0000-0000-0000-0000000000a3');
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.t, v.u, r.id, 'tenant'
   from (values ('15800000-0000-0000-0000-000000000001'::uuid,'15800000-0000-0000-0000-000000000011'::uuid),
                ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-000000000012'),
                ('15800000-0000-0000-0000-000000000002','15800000-0000-0000-0000-000000000021')) v(t,u)
   join public.roles r on r.code = 'employee';
   insert into public.notifications (id, tenant_id, target_user_id, notification_type_code, title, body) values
     ('15800000-0000-0000-0000-0000000000f1','15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-000000000011','supplier_balance','Alert','Body');
   -- Attempt 1 on email, failed six minutes ago: its retry is due (backoff 5 minutes).
   insert into public.notification_deliveries (id, tenant_id, notification_id, channel_code, delivery_status_code, attempt_number, claimed_at, failed_at, error_message) values
     ('15800000-0000-0000-0000-0000000000d1','15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','failed',1,
      now() - interval '7 minutes', now() - interval '6 minutes','provider said 421');

   create function pg_temp.as_(sub text) returns text language sql as $$
     select set_config('request.jwt.claims', json_build_object('sub', sub, 'aal', 'aal1')::text, true) $$;
   create function pg_temp.chain() returns text language sql as $$
     select string_agg(attempt_number || ':' || delivery_status_code || ':' || (claimed_at is not null)::text, ','
                       order by attempt_number, claimed_at is null)
       from public.notification_deliveries
      where notification_id = '15800000-0000-0000-0000-0000000000f1' and channel_code = 'email' $$;

   -- =============================================================================================
   -- 1-2. THE KEY. One row per attempt number per chain, replacing the plain chain index.
   -- =============================================================================================
   select is(
     (select pg_get_constraintdef(oid) from pg_constraint
       where conrelid = 'public.notification_deliveries'::regclass and conname = 'notification_deliveries_attempt_key'),
     'UNIQUE (notification_id, channel_code, attempt_number)',
     'ND-1: (notification_id, channel_code, attempt_number) is unique -- two dispatchers can never both hold attempt N+1');
   select is(
     (select count(*)::int from pg_indexes
       where schemaname = 'public' and indexname = 'notification_deliveries_chain_idx'),
     0,
     'ND-1: the plain chain index is gone, replaced by the key that covers the same columns (EC-11: no duplicate mechanism)');

   -- =============================================================================================
   -- 3-4. INPUT. A second attempt 1 is refused on the platform path; the key is per channel.
   -- =============================================================================================
   select throws_ok($$
     insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code)
     values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','pending')$$,
     '23505', null,
     'INPUT: a second attempt 1 on the same chain is refused 23505, even for the platform (postgres) writer');
   select lives_ok($$
     insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code)
     values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','whatsapp','pending')$$,
     'POSITIVE CONTROL: attempt 1 of the same notification on another channel is its own chain and is accepted');

   -- =============================================================================================
   -- 5-7. THE CLAIM still opens a due retry, exactly once, and claims it in the same call.
   -- =============================================================================================
   select is(
     (select count(*)::int from app.claim_notification_deliveries('email', 50) c
       where c.notification_id = '15800000-0000-0000-0000-0000000000f1'),
     1,
     'POSITIVE CONTROL: the claim opens the due retry and returns it once');
   select is(pg_temp.chain(), '1:failed:true,2:pending:true',
     'POSITIVE CONTROL: the chain is attempt 1 failed and one attempt 2, claimed -- the failure is preserved, never mutated');
   select is(
     (select count(*)::int from app.claim_notification_deliveries('email', 50) c
       where c.notification_id = '15800000-0000-0000-0000-0000000000f1')
     || '|' || pg_temp.chain(),
     '0|1:failed:true,2:pending:true',
     'REPLAY: a second claim returns nothing for this notification and opens no further attempt');

   -- =============================================================================================
   -- 8-9. INJECTION (PAR-4, TEST-3). Without the key a second attempt 2 lands; restored, it is refused.
   -- =============================================================================================
   savepoint no_key;
   alter table public.notification_deliveries drop constraint notification_deliveries_attempt_key;
   insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number)
   values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','pending',2);
   select is(pg_temp.chain(), '1:failed:true,2:pending:true,2:pending:false',
     'INJECTION: with the key dropped, a second attempt 2 is stored -- the state two racing dispatchers produced (ND-1)');
   rollback to savepoint no_key;
   select throws_ok($$
     insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number)
     values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','pending',2)$$,
     '23505', null,
     'INJECTION RE-ASSERTED: after the rollback the key is back and the second attempt 2 is refused 23505');

   -- =============================================================================================
   -- 10. THE CLAIM SKIPS A HELD KEY. A diagnostic tripwire, labelled as one: it reads the function's
   --     text, so it proves the clause is present, not that it works. The two-session harness is the
   --     evidence that it works; this only fails loudly if the clause is ever edited away.
   -- =============================================================================================
   select ok(
     position('on conflict on constraint notification_deliveries_attempt_key do nothing'
              in pg_get_functiondef('app.claim_notification_deliveries(text,integer)'::regprocedure)) > 0,
     'TRIPWIRE (diagnostic): step 2 skips an attempt another dispatcher holds instead of failing the whole claim');

   -- =============================================================================================
   -- 11-13. PRIVILEGE, AUTH and STATE: the claim is still a definer RPC for the integration role only.
   -- =============================================================================================
   select is(
     (select p.prosecdef::text || '|' || coalesce(array_to_string(p.proconfig, ','), '')
        from pg_proc p where p.oid = 'app.claim_notification_deliveries(text,integer)'::regprocedure),
     'true|search_path=""',
     'PRIVILEGE: the replaced claim is still SECURITY DEFINER with an empty search_path');
   select is(
     has_function_privilege('orvion_integration','app.claim_notification_deliveries(text,integer)','execute')::text
     || '|' || has_function_privilege('authenticated','app.claim_notification_deliveries(text,integer)','execute')::text
     || '|' || has_function_privilege('anon','app.claim_notification_deliveries(text,integer)','execute')::text
     || '|' || has_function_privilege('authenticated','app.record_notification_delivery_result(uuid,boolean,jsonb,text)','execute')::text,
     'true|false|false|false',
     'AUTH: only orvion_integration may claim; neither authenticated nor anon may claim or record a result -- create or replace kept the ACL');
   select throws_ok($$
     select app.record_notification_delivery_result('15800000-0000-0000-0000-0000000000d1', true, null, null)$$,
     'P0001', null,
     'STATE: a result for the failed attempt 1 raises -- only a pending delivery can be resolved');

   -- =============================================================================================
   -- 14-16. DOOR and TENANT, swept and pinned: no signed-in write; a delivery is read by its recipient only.
   -- =============================================================================================
   set local role authenticated;
   select pg_temp.as_('15800000-0000-0000-0000-0000000000a1');
   select throws_ok($$
     insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number)
     values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','pending',3)$$,
     '42501', null,
     'DOOR: the recipient cannot write a delivery at the table (authenticated holds SELECT only)');
   select is(
     (select count(*)::int from public.notification_deliveries
       where notification_id = '15800000-0000-0000-0000-0000000000f1'),
     3,
     'TENANT POSITIVE CONTROL: the recipient reads its three deliveries (email 1 and 2, whatsapp 1)');
   select pg_temp.as_('15800000-0000-0000-0000-0000000000a2');
   select set_config('c158.peer', (select count(*)::text from public.notification_deliveries
       where notification_id = '15800000-0000-0000-0000-0000000000f1'), true);
   select pg_temp.as_('15800000-0000-0000-0000-0000000000a3');
   select is(
     current_setting('c158.peer') || '|' || (select count(*)::text from public.notification_deliveries
       where notification_id = '15800000-0000-0000-0000-0000000000f1'),
     '0|0',
     'TENANT: a same-tenant peer and a rival tenant''s user each read none of them');
   reset role;

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 970d8be98908c82c174ddb684c32eac673027eed.

3. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| ND-1 |`; if so record Already Applied when its Git blob is 754751e3d1b7041453973aef755d6b5fd0297405, and otherwise stop and report. Otherwise make exactly these 2 edits (the Slice 43 freshness entry and the ND-1 row), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-10-21 (**SPEC-292: AUD-01d fixes the hostile-calendar test precondition.** The existing guard and every required gate remain unchanged.)
   ```
   with
   ```text
   Last updated: 2026-11-08 (**Slice 43 — `notification_deliveries` selected live at Exposure 7, coverage 42; runner-up `approval_requests` at 7/52.** **ND-1** (Medium) is new and fixed. Two overlapping runs of `app.claim_notification_deliveries` each opened attempt 2 of the same due retry and each claimed it, so its recipient would be sent the same message twice. SPEC-298 makes the attempt number unique per chain and has the claim skip an attempt another run has opened. No other row changed.)

   Previously: 2026-10-21 (**SPEC-292: AUD-01d fixes the hostile-calendar test precondition.** The existing guard and every required gate remain unchanged.)
   ```

   b) immediately after the line
   ```text
   | COA-2 | **The chart-of-accounts table door let a finance manager without step-up change the chart the seed RPC refuses them** | security / authorization | Medium | R | 6 | M | ✅ | **✅ FIXED 2026-10-13 (SPEC-278, `20261013120000`), DEPLOYED to Primary under separate exact-byte owner authorization; the fresh Primary ledger, function surface and all ten structural surfaces match local.** STEPUP-1's member on this table, reproduced and consequence-classified by COA-1. **MEASURED** at `4347817`, rolled back: every COA-1 write was made by a `finance_manager` at `aal1`, where `app.seed_default_chart_of_accounts` and `app.create_journal_entry` both refuse with `multi-factor authentication required for this role`; the table's policies ask only `app.has_permission`. **Repaired:** the same guard charges `app.authorize('CREATE_JOURNAL_ENTRY')` on every signed-in INSERT and UPDATE, so the door charges what the seed RPC charges, step-up included (42501); the session-less platform write is exempt, as for every capability guard. `10_grant_model_test` assertion 9's list grows from ten to eleven, justified in the test; `29_...`'s employee refusal now comes from the guard, for the same missing permission. Pinned by `157_...` and mutants M5–M7, each killed | — | SPEC-278-a-used-ledger-account-keeps-its-meaning | 10-13 | 10-13 |
   ```
   insert
   ```text
   | ND-1 | **Two overlapping dispatchers could each open the same due notification retry and both send it** | integrity / delivery | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-08 locally (SPEC-298, `20261108120000`); Primary deployment pending.** **MEASURED** at `a21a0ec` on the local stack: one `email` delivery at attempt 1, failed six minutes earlier, so its retry was due; session A ran `begin; select app.claim_notification_deliveries('email', 50); select pg_sleep(4); commit;` and session B ran the same claim 1.5 s later. The chain ended attempt 1 failed and attempt 2 pending and claimed twice, and each session's claim returned the notification once: its recipient would be sent the same message twice. The sleep only widens the window. The claim's step 3 is safe by `for update skip locked`; its step 2, which opens the due retry, was not, because its `not exists` cannot see another run's uncommitted attempt N+1 and nothing made (notification_id, channel_code, attempt_number) unique. **Repaired:** the unique constraint `notification_deliveries_attempt_key` replaces the plain chain index, and step 2 names it in `on conflict ... do nothing`, so a second run waits on the first run's key and skips it (race rerun: session B waited 2.6 s, returned nothing and the chain holds one attempt 2); a second attempt N on any path is refused 23505. Every producer (`app.process_lead_sla` and both credit evaluators) writes attempt 1 for a notification it has just created, so none can collide. No email is sent today (MAIL-1), so no recipient was affected. Pinned by `158_...` and mutants M1 (the key dropped) and M2 (the on-conflict clause removed), each killed, M2 also by the race | — | SPEC-298-a-due-retry-is-opened-once | 11-08 | 11-08 |
   ```

   The resulting file's Git blob is 754751e3d1b7041453973aef755d6b5fd0297405.

4. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**44 of 78 recorded · 20 `; if so record Already Applied when its Git blob is f42ec9a678d708545b7aa4d25e46249c146a9a82, and otherwise stop and report. Otherwise make exactly these 4 edits (the freshness entry, coverage 44 of 78 and the notification_deliveries row), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-10-13 (**slice 42 — `chart_of_accounts` selected by Exposure 7, coverage 38; runner-up `notification_deliveries` at 7/42.** Coverage **42 → 43 of 78**. COA-1: after a 1000 sale was posted to it, a finance manager retyped revenue account 4000 to `expense` and recoded it, and Cost of Sales took its code, with no event. COA-2: every such write was made at `aal1`, where the seed RPC charges step-up. SPEC-278 closes both, so the row is `AUDITED`, with its recorded positions and their reopening triggers. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-08 (**slice 43 — `notification_deliveries` selected by Exposure 7, coverage 42; runner-up `approval_requests` at 7/52.** Coverage **43 → 44 of 78**. ND-1: two overlapping dispatchers each opened attempt 2 of the same due retry and each claimed it, so its recipient would be sent the message twice. SPEC-298 closes it, so the row is `AUDITED`, with its recorded positions and their reopening triggers. No other row changed.)

   Previously: 2026-10-13 (**slice 42 — `chart_of_accounts` selected by Exposure 7, coverage 38; runner-up `notification_deliveries` at 7/42.** Coverage **42 → 43 of 78**. COA-1: after a 1000 sale was posted to it, a finance manager retyped revenue account 4000 to `expense` and recoded it, and Cost of Sales took its code, with no event. COA-2: every such write was made at `aal1`, where the seed RPC charges step-up. SPEC-278 closes both, so the row is `AUDITED`, with its recorded positions and their reopening triggers. No other row changed.)
   ```

   b) replace the line
   ```text
   **43 of 78 recorded · 19 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 35 `NOT-RECORDED`.**
   ```
   with
   ```text
   **44 of 78 recorded · 20 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 34 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 43 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 44 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `notification_deliveries` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `notification_deliveries` | **AUDITED** | ADVERSARIAL | `SPEC-298-a-due-retry-is-opened-once` | ND-1 | `158_a_due_retry_is_opened_once_test.sql` (16 assertions, eight attack classes declared, BUSINESS and OBSERVABILITY N/A) proves that a due retry is opened once and claimed once, that a second attempt N is refused 23505 even for the platform writer, that a replayed claim opens nothing, and that with the key dropped a second attempt 2 is stored (injection, re-asserted after rollback). The two-session race and mutants M1 (key dropped) and M2 (on-conflict removed) were each killed on the prototype; the causal negative on the unrepaired 253 migrations reproduced two claimed attempt-2 rows. **Swept and sound:** a recipient reads its own deliveries (3) and a same-tenant peer and a rival tenant read none; `authenticated` holds no write grant on the table and cannot execute the claim or result RPCs (42501); the claim and result RPCs are SECURITY DEFINER with an empty `search_path` and executable only by `orvion_integration`; a late acknowledgement raises; every producer writes attempt 1 once. **Recorded positions, not repaired:** `app.record_notification_delivery_result` accepts a result for a pending row no dispatcher claimed; only `orvion_integration` can call it. Reopening trigger: a second integration identity. A send that outlives the 30-minute lease is failed and retried, so a slow provider can still receive the message twice; this is the lease trade-off SPEC-123 chose. Reopening trigger: a provider whose send can outlast the lease. `notification_deliveries_notification_id_idx` is now covered by the key's leading column and is left alone as housekeeping. |
   ```

   The resulting file's Git blob is f42ec9a678d708545b7aa4d25e46249c146a9a82.

5. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–4 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the migration and test 158, which must equal Consumer Closure;
   - on the local stack holding the migration: `md5(prosrc)` of the claim, the key and the absent chain index; test 158 and test 100 alone; the race; mutants M1 and M2, each restoration proven equal;
   - the causal negative on a local stack without the migration, then the stack restored with it;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
   - the API-contract and map generators, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary and the seven measured-state items of Consumer Closure.

   Read a fresh Primary baseline, read-only: the project URL, the full ordered ledger and the absence of the target migration; the function and structural surfaces; the constraints and indexes of `notification_deliveries`; the tenant and delivery counts and the duplicate (notification_id, channel_code, attempt_number) groups, which must be 0. Record the predicted delta. If any reading differs, stop.
6. **Check** that an exact-SHA Gate-2 record for the migration is in the Execution Log: the owner's own, or one marked DELEGATED naming this contract, the migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's 2026-11-08 instructions under which it is taken. If absent, write it only when Step 5 passed and those instructions cover a migration that drops no table or column and deletes or rewrites no business row; otherwise stop after Step 5 and present the Gate-2 package.
7. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261108120000_a_due_retry_is_opened_once`. If it is absent and Step 6 is recorded:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the duplicate groups and the constraints and indexes of `notification_deliveries`.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the constraints and indexes of `notification_deliveries`; the claim's `md5(prosrc)`, security mode and ACL; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
8. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the catalog figure `71/623` and the HTTP figure unchanged.
   - Confirm that `supabase/tests` holds 158 files whose literal `plan(N)` values sum to 3010, then set `Suite **158 files / 3010 assertions**`. If either differs, stop.
   - In the ND-1 row of the register, replace the text `` | 🛡 | **FIXED 2026-11-08 locally (SPEC-298, `20261108120000`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-08 (SPEC-298, `20261108120000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of this contract; the fresh Primary ledger, functions and structure equal local.** `` (each span's one leading and one trailing space are delimiters, not text), and change nothing else in the register.
   - Regenerate `MASTER_API_CONTRACT.md`, `ai-map.json` and `repository-index.md` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.

   If Primary is unproven, stop.
9. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] The migration is the frozen bytes; `check: blob supabase/migrations/20261108120000_a_due_retry_is_opened_once.sql 333baa4296c37421ec126da166f282c72935702d`
- [ ] Test 158 is the frozen bytes; `check: blob supabase/tests/158_a_due_retry_is_opened_once_test.sql 970d8be98908c82c174ddb684c32eac673027eed`
- [ ] The disposition record carries `notification_deliveries` AUDITED / ADVERSARIAL and coverage 44 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md f42ec9a678d708545b7aa4d25e46249c146a9a82`
- [ ] ND-1 is fixed and deployed in the register; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of this contract"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **158 files / 3010 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @a21a0ec8c91e863fdd0ad86082bd93dfe1a77ba8`
- [ ] The originating claim migration remains exact; `check: same supabase/migrations/202607060900_a_delivery_obligation_that_is_attempted_retried_and_abandoned.sql @a21a0ec8c91e863fdd0ad86082bd93dfe1a77ba8`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write, after a recorded Step 5 readiness gate and Step 6 Gate-2 record; Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1 and M2 are each killed with installation and restoration proven, and the causal negative is recorded.

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

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-298: Batch 6 Slice 43 — a due notification retry is opened once (ND-1), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline a21a0ec8c91e863fdd0ad86082bd93dfe1a77ba8 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_GAP_REGISTER.md` | `346f88e53111ecc5dde7fcbc73c6527f66fceca8` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `338ecd651b27f942a40d7f8ddedb79e722a8ee52` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md, SPEC-278 and SPEC-279 at a21a0ec8c91e863fdd0ad86082bd93dfe1a77ba8; the owner's instructions of 2026-11-08 (recorded outside this repository). Three identified snapshots and selection reasons are retained externally; correctness remains native and independent.

Snapshot identities: V1 E813C5BB652E0241B801340416063611B650B7C3AFCE34B8B1D901452EB7F746; V2 F0B7DF1C2A0D26BF2F246D6334A5A1673923549D8C8F7274497CF374CBD544BB. V3 adds this linkage and the final selection; its own SHA-256 is external.
