# Change Request — SPEC-213

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make `public.offline_conversions.source_event_seq` writable only by the session-less platform path, so a signed-in session can neither set it on INSERT nor change it on UPDATE, while `app.map_outcomes_to_conversions` keeps writing it exactly as it does today.

## Business Reason

Batch 6 Slice 13 selected `offline_conversions` by measurement (`scripts/batch6_select_target.ps1`: Exposure **14**, tied with `quotations` and ranked first on the coverage tie-break, 50 against 74). One defect reproduced against the clean local stack at `a7ff994`, recorded here as **CONV-6**:

- `source_event_seq` is the idempotency key the mapper writes from a real event's global `seq`. Its unique index spans every tenant, the mapper resolves a conflict on it with `ON CONFLICT DO NOTHING`, and CONV-1's deferral recovery closes a deferral as mapped whenever any row holds that key. `authenticated` holds table-level INSERT and UPDATE on the table and nothing guards the column, so a signed-in owner of one tenant could write values into it. Measured: tenant A's owner at `aal2` wrote the next 50 values, tenant B's next `lead_qualified` event received one of them, and the mapper then produced **0** conversions for tenant B where the unmodified control produced **1**. The cursor advanced, no finding was recorded, and a rerun recovered nothing. The same write by UPDATE succeeded. A lapsed tenant's deferred conversion was closed as *"the conversion was mapped on a later run"* with no conversion existing.
- The loss is silent, permanent and crosses tenants, and the conversion it removes is revenue evidence that would otherwise have reached the tenant's advertising platform.

## Risks

- **Breaking the mapper is the main risk.** The guard exempts the session-less path, and the mapper swallows its own errors into `scheduled_job_findings`, so a guard that refused the mapper would show up only as missing conversions. The permanent test therefore asserts the mapper's *outcomes* (a conversion exists, is held by the right tenant, is not duplicated, and a deferral closes truthfully) rather than its return value, and the mutation that removes the session-less exemption was measured to turn five of those assertions red.
- **Narrowing a door that tests pin.** `64_acquisition_lineage_test.sql` pins that an owner may update a conversion's value, and `78_marketing_conversion_integrity_test.sql` pins direct INSERT through the table door. The guard refuses only a change to `source_event_seq`. Measured on a prototype: every one of the ten existing files naming this surface passes with identical counts, and the whole suite passes (118 files, 1958 assertions, 0 failures).
- **Primary deployment is irreversible** and is gated by an explicit owner authorization inside Step 6, not by this contract's approval alone.
- Not repairing leaves any tenant owner able to erase another tenant's offline conversions without trace.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-213-conversion-provenance-is-platform-written.md`
- `supabase/migrations/20260923120000_conversion_provenance_is_platform_written.sql`
- `supabase/tests/119_conversion_provenance_is_platform_written_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607049300_outcome_conversion_mapper.sql`
- `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql`
- `supabase/tests/09_conversion_delivery_lease_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/13_conversion_identity_snapshot_test.sql`
- `supabase/tests/64_acquisition_lineage_test.sql`
- `supabase/tests/66_scheduled_job_isolation_test.sql`
- `supabase/tests/78_marketing_conversion_integrity_test.sql`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`
- `reports/README.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`

## Required Reading

- `reports/master/MASTER_SURFACE_DISPOSITION.md` — the `offline_conversions` row and the Coverage section
- `reports/master/MASTER_GAP_REGISTER.md` — CONV-1 (the deferral recovery that relies on this key), CONV-4, CONV-5, and the `USR-5` row this contract's new row follows
- `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql` — `app.map_outcomes_to_conversions` as it stands
- `supabase/tests/66_scheduled_job_isolation_test.sql` — the mapper fixture shape reused by the new test
- `ENGINEERING_METHOD.md §4` — the DATABASE protocol, and that Primary for this repository is only `vrvtsxexkiiiivlkdxzp`
- `reports/master/MASTER_INTEGRATION_CATALOG.md §0` — deployment topology; Secondary `brplkqmbzffpxqgkkdzo` is never a CRM target
- `reports/evidence/primary-ledger-evidence.json` — the current recorded Primary reading and its `read_query`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_care_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_storage_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| a signed-in session may no longer set or change `offline_conversions.source_event_seq` | `app.map_outcomes_to_conversions` (the only writer of the column) | VERIFY | Runs session-less; the prototype preserved conversion, second-run idempotency and deferral recovery, pinned by the new file's outcome assertions |
| same | `app.record_offline_conversion` | UNAFFECTED | Never names the column; the new file's assertion 1 calls it as a signed-in owner and it succeeds |
| same | `app.claim_conversion_deliveries` | UNAFFECTED | Reads the table and never writes this column; `09_conversion_delivery_lease_test.sql` and `13_conversion_identity_snapshot_test.sql` pass with identical counts on the prototype |
| same | the ten pgTAP files naming this surface (`09`, `13`, `36`, `53`, `57`, `58`, `64`, `66`, `78`, `111`) | VERIFY | Measured baseline against prototype: identical ok/not-ok counts in every file, 0 failures |
| a new trigger and trigger function exist on `public.offline_conversions` | the whole pgTAP suite, including `10_grant_model_test.sql`'s bespoke-guard population and the function-inventory class tests | UNAFFECTED | Measured with the prototype applied: 118 files, 1958 assertions, 0 failures |
| same | `reports/master/MASTER_API_CONTRACT.md` (GENERATED, Check L3) | VERIFY | Regenerated from the prototype-applied stack into a scratch path: byte-identical to the committed file. It is in Write Scope because the Gate derives it for any migration contract |
| same | `scripts/verify_database.sql` | UNAFFECTED | Against the prototype: `ALL CHECKS PASSED (77 tables, … 71/621 catalog …)` |
| same | the six HTTP suites in Additional Verification | VERIFY | Each exited 0 against the prototype-applied stack: 33, 120, 40, 74, 122 and 60 passed |
| migration set 219 → 220, function surface +1, structural surface | `reports/evidence/primary-ledger-evidence.json`; `_ORVION_CANONICAL/manifest.md` `Live state:` | WRITE | Rewritten from a post-deployment Primary read (GUARD-1), never from a repository list |
| pgTAP suite 118 → 119 files and its declared assertion total | `_ORVION_CANONICAL/manifest.md` `Live state:` (Check 15) | WRITE | Remeasured after the new file lands, never incremented on paper |
| finding CONV-6 | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Check 22 rejects a disposition row citing an unregistered id |
| `offline_conversions` disposition and coverage 13 → 14 of 77 | `reports/master/MASTER_SURFACE_DISPOSITION.md`; the manifest's `Batch 6 surface coverage` line | WRITE | Check 22 recomputes the Coverage totals from the rows; Check 24 requires the cited file's `-- ATTACK-CLASSES:` line and a negative assertion |
| dated content added to both Master documents | Check 21 freshness headers | WRITE | Each document's `Last updated:` moves in the same step that adds its dated content |
| any | `scripts/batch6_select_target.ps1` | UNAFFECTED | Stores nothing and reads the disposition file; the row change removes this surface from its NOT-RECORDED candidates |
| any | `reports/README.md`; the manifest's `Narrative:` field | UNAFFECTED | No session report is written; this contract is the immutable evidence artifact, as `SPEC-206` and `SPEC-160` already did |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| pgTAP Pass A and Pass B, the six HTTP suites and `verify_database.sql` green on a clean reset that includes the migration | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Check 22 / Check 24 — disposition rows, Coverage totals, cited finding ids and the cited test file agree | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Check 21 — each Master document's `Last updated:` is not older than its newest dated content | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Check 9 / Check 19 — manifest migration figures and the recorded Primary ledger agree with the repository | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 9 |
| Check 15 — manifest declared assertion total equals the `plan(N)` sum | AFTER_IRREVERSIBLE_ACTION | Step 2 | Step 7 | Step 9 |
| Check 7 — `ai-map.json` live_state equals the manifest by value | BEFORE_COMPLETION | Step 7 | Step 8 | Step 9 |
| Check 5 — `_ORVION_CANONICAL/manifest.md` inside its 7000-character budget | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: The house idiom is reused — `(select auth.uid()) is null` as the platform path, and a table-specific `forbid_*` BEFORE trigger — but no existing control expresses this rule. `app.guard_write_capability` decides which permission a write costs, and the actor here holds it. `app.forbid_acquisition_lineage_rewrite` is UPDATE-only and deliberately admits NULL → value, which is exactly the write to refuse, and INSERT never reaches it. Narrowing grants to a per-column allowlist was rejected: PostgreSQL column revokes cannot override the table-level grant, so the table-level INSERT and UPDATE would be removed and 16 columns re-granted for each, an allowlist every future column must remember, with no stronger guarantee. A tenant-scoped foreign key to `events` was rejected as incomplete: `(tenant_id, seq)` on `events` is not unique, and even with that constraint a tenant could still write the key of one of its own events.

Added Property: `source_event_seq` is provenance only the platform writes; no signed-in session, whatever its permissions, can set it on INSERT or change it on UPDATE.

Causal Negative: reproduced against unmodified `a7ff994` on the local stack. Tenant A's owner at `aal2` inserted rows holding the next 50 global `seq` values; tenant B's next `lead_qualified` event received one of them; the mapper produced 0 conversions for tenant B (control: 1), advanced its cursor, recorded no finding and recovered nothing on rerun. The same write by UPDATE succeeded, and a lapsed tenant's deferral closed as mapped with no conversion existing.

Positive Test Design: the manual RPC records a conversion; a signed-in direct INSERT that leaves the column NULL succeeds; a signed-in UPDATE that does not move the column succeeds; the session-less mapper converts tenant B's outcome with tenant B holding its key; a second mapper run adds nothing; a lapsed tenant's outcome is deferred and, once the tenant is writable again, is converted for that tenant and its deferral closes as mapped because it was.

Negative Test Design: a signed-in owner at `aal2`, holding MANAGE_MARKETING_CAMPAIGN so that no permission, MFA or RLS control can be the refuser, is refused SQLSTATE `42501` with the exact message `offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it` for: INSERT of a not-yet-used value; INSERT of another tenant's existing event value; UPDATE from NULL to a value; UPDATE replacing a mapper-written value; UPDATE clearing a mapper-written value; INSERT of a deferred event's value.

Non-Empty Population Obligation: every outcome assertion names a specific event `seq` or lead and asserts the holding tenant or an exact count of 1, so none can pass by selecting nothing; the final assertion that tenant A holds no stray provenance is paired with the positive assertion that the mapper did write tenant A's own conversion.

Mutation Obligation: each load-bearing predicate independently killed, against the migration's own text — (i) trigger removed: in-file, dropping the trigger inside a savepoint makes the same INSERT succeed; (ii) INSERT forgotten (`before update` only): the INSERT refusals fail; (iii) UPDATE forgotten (`before insert` only): the UPDATE refusals fail; (iv) system/session decision inverted (`is not null`): the refusals fail and the mapper outcomes fail; (v) session-less exemption removed (the mapper treated as a session): the mapper outcome assertions fail while the session refusals still hold.

Post-Implementation Proof Obligation: `npx supabase test db` reports 0 failures and the assertions executed equal the sum of the literal `plan(N)` declarations across `supabase/tests`; the new file passes 16 of 16.

## Implementation Steps

1. **Check:** a file matching `supabase/migrations/20260923120000_*.sql` exists. If present, record Already Applied. Otherwise create `supabase/migrations/20260923120000_conversion_provenance_is_platform_written.sql` containing a leading comment block that names `SPEC-213 / CONV-6` and states the rule, followed by exactly these three statements and nothing else: (a) `create or replace function app.forbid_session_provenance_write() returns trigger language plpgsql set search_path = ''` whose body returns `new` when `(select auth.uid()) is null`; on `INSERT` raises when `new.source_event_seq is not null`; otherwise raises when `new.source_event_seq is distinct from old.source_event_seq`; and returns `new` — each raise using SQLSTATE `42501` and the message `offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it`; (b) `revoke execute on function app.forbid_session_provenance_write() from public;` (c) `create trigger offline_conversions_forbid_session_provenance_write before insert or update on public.offline_conversions for each row execute function app.forbid_session_provenance_write();`. The migration must not be `security definer`, must not change any grant, policy, index, constraint or other trigger, and must not modify `app.map_outcomes_to_conversions`.

2. **Check:** `supabase/tests/119_conversion_provenance_is_platform_written_test.sql` exists. If present, record Already Applied. Otherwise create it in the `begin; select plan(16); … select finish(); rollback;` shape, carrying the line `-- ATTACK-CLASSES: DOOR TENANT PRIVILEGE STATE REPLAY BUSINESS OBSERVABILITY AUTH=N/A INPUT=N/A CONCURRENCY=N/A` with the reason for each `N/A` stated in the header, and asserting in this order exactly the sixteen items of this contract's Positive Test Design, Negative Test Design and Mutation Obligation (i): assertions 1-3 the three signed-in positive controls; 4-6 the INSERT-of-unused-value, INSERT-of-another-tenant's-value and UPDATE-from-NULL refusals; 7 the in-file mutation control; 8-9 mapper conversion held by tenant B and second-run idempotency; 10-11 the replace and clear refusals on a mapper-written value; 12 the deferral positive control; 13 the deferred-value INSERT refusal; 14-15 the recovered conversion held by tenant B and its truthful deferral note; 16 tenant A holds no stray provenance. Every refusal is asserted with `throws_ok` on SQLSTATE `42501` and the exact message from Step 1. The signed-in actor is an `owner` at `aal2`. Every session-less step clears `request.jwt.claims` after `reset role`, because `reset role` does not clear the claim and the guard reads `auth.uid()`.

3. **Check:** `reports/master/MASTER_GAP_REGISTER.md` contains a row whose first cell is `CONV-6`. If present, record Already Applied. Otherwise insert, immediately after the `USR-5` row and separated by one blank line as the table's rows are, one row in the table's existing thirteen-column format: ID `CONV-6`; a bold title stating that a signed-in session could write `offline_conversions.source_event_seq` and so erase another tenant's offline conversion silently; category `integrity · tenant isolation`; severity **High**; `R`; batch `6`; `A`; `✅`; a status cell beginning `**✅ FIXED 2026-09-23 (SPEC-213, `20260923120000`).**` followed by the measured reproduction from this contract's Business Reason and the repair in one sentence; an EMPTY Owner Decision cell; source `SPEC-213`; added `09-23`; updated `09-23`. In the same step, prepend a new `Last updated: 2026-09-23 (…)` entry describing CONV-6 and demote the current one to `Previously:` in the file's existing voice. Change no other row.

4. **Check:** `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `offline_conversions` row reads `NOT-RECORDED`. If it does not, record Already Applied. Otherwise set that row to disposition `PARTIAL`, assurance `ADVERSARIAL`, session `SPEC-213-conversion-provenance-is-platform-written`, findings `CONV-6`, and a Next cell stating that provenance and tenant isolation were swept and CONV-6 closed by `119_...`, and that two axes remain unswept by choice: signed-in writes by an authorised MANAGE_MARKETING_CAMPAIGN holder to the identity snapshot, value and time after creation (where `64_...` pins value updates as intended), and creation-event parity for direct-DML rows. Update the Coverage summary to `14 of 77 recorded · 6 `AUDITED` · 7 `AUDITED-OPEN` · 1 `PARTIAL` · 0 `EXEMPT` · 63 `NOT-RECORDED`` and its sentence to `All 14 recorded surfaces stand at `ADVERSARIAL``. In the same step, prepend a new `Last updated: 2026-09-23 (…)` entry for slice 13 and demote the current one to `Previously:`. Change no other row.

5. **Check:** the Execution Log contains an entry headed `Pre-deploy readiness gate`. If present, record Already Applied. Otherwise perform the gate and record every item's measured result in the Execution Log; the first item that does not hold is a STOP, and nothing is deployed while it stands:
   - a clean `npx supabase db reset` completed;
   - pgTAP **Pass A** (`npx supabase test db`) ran with 0 failures, and the assertions executed equal the `plan(N)` sum;
   - the six Additional Verification suites ran in the listed order, each exiting 0;
   - pgTAP **Pass B** ran after those suites with 0 failures;
   - `scripts/verify_database.sql` completed with `ALL CHECKS PASSED`;
   - the five mutants of the Mutation Obligation were each applied to the text of Step 1's migration inside one rolled-back transaction ahead of Step 2's file body, against the clean-reset stack with the migration's own trigger dropped inside that transaction first, and each turned red exactly the assertions this contract names for it; the unmutated text turned none red;
   - `pwsh -NoProfile -File scripts/generate-api-contract.ps1` regenerates `reports/master/MASTER_API_CONTRACT.md` byte-identically;
   - `git status --porcelain` shows no path outside this contract's Write Scope;
   - `supabase/migrations/` contains exactly one migration absent from the recorded Primary ledger, and it is the file Step 1 created;
   - `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` is run and its result recorded. Exactly three failure classes are admissible, all the same bounded undeployed state: `MIGRATION STATE DRIFT`; `SUITE FIGURE DRIFT`; and RECOVER-1 / Check 19 only when its `only in repository` set is exactly `20260923120000_conversion_provenance_is_platform_written` and its `only on Primary` set is empty. Any other failure is a STOP.

6. **Check:** `reports/evidence/primary-ledger-evidence.json`'s `ledger` array contains an entry beginning `20260923120000`. If present, record Already Applied. Otherwise, **first confirm that the owner has explicitly authorized Primary deployment of SPEC-213 after Step 5 was recorded, and record that authorization in the Execution Log; without it, set `Blocker:` to the owner gate and STOP here.** Then, in this order and stopping at the first step that does not hold: (a) confirm the target is project ref `vrvtsxexkiiiivlkdxzp` by reading it live through the `supabase-primary` connector, and that it is not Secondary `brplkqmbzffpxqgkkdzo`; (b) read Primary's migration ledger with the exact query recorded in the evidence file's `read_query`; (c) prove `20260923120000` is absent and the ledger equals the recorded evidence (same `migration_count` and `ledger_fingerprint`); (d) apply ONLY Step 1's migration through the connector's migration-apply call; (e) if the connector assigns its own version, normalise it in Primary's ledger to `20260923120000`, as already done for `20260909060754` and `20260909114354`; (f) re-read Primary's full ledger with the same query; (g) rewrite the evidence file from that post-deployment reading, including the function-surface and structural-surface hashes read FROM Primary; (h) prove repository, local and Primary hold the same migration identities; (i) run `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1` and record its result. If any post-deployment operation fails, STOP and report Primary's exact state as read; do not re-apply and do not author a corrective migration.

7. **Check:** `_ORVION_CANONICAL/manifest.md`'s `Batch 6 surface coverage` line reads `14 of 77`. If it does, record Already Applied. Otherwise, after Step 6, update by measurement only: set that line to `14 of 77` (fourteen at `ADVERSARIAL`); remeasure and rewrite every mutable figure in `Live state:` — migration count and latest identity, ledger fingerprint, function-surface hash and function count, structural-surface hash and object count, test-file count and declared assertion total, and the HTTP assertion total — from measurement, never by incrementing; set `Last Completed` to SPEC-213 REPLACING the SPEC-212 entry; and set `Next capability` to Batch 6 Slice 14 ranked by `scripts/batch6_select_target.ps1`, keeping the standing facts that follow it. Do not modify `Narrative:`. The `Live state:` sentence may claim Primary parity only if Step 6 read Primary and proved it.

8. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` equal the manifest's by value. If they agree, record Already Applied. Otherwise regenerate with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and normalise the file to LF before committing. Repeat after every commit in this lifecycle that changes the manifest, including Approve and Complete.

9. **Check:** the Execution Log contains an entry headed `Post-deploy verification`. If present, record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1`, `pwsh -NoProfile -File scripts/check_primary_ledger.ps1` and `pwsh -NoProfile -File scripts/check_repository_consistency.ps1`, and record each exit code; all three must exit 0.

## Acceptance Criteria

- [x] `supabase/migrations/20260923120000_conversion_provenance_is_platform_written.sql` exists and contains exactly the function, the revoke and the trigger Step 1 names, with no `security definer`, grant, policy, index or constraint change.
- [x] `public.offline_conversions` carries exactly one trigger executing `app.forbid_session_provenance_write`, firing `BEFORE INSERT OR UPDATE`, and `app.forbid_session_provenance_write` grants no `EXECUTE` to `PUBLIC`.
- [x] `app.map_outcomes_to_conversions`, every RLS policy and every grant on `public.offline_conversions` are identical to their definitions at the start of this Change Request.
- [x] `supabase/tests/119_conversion_provenance_is_platform_written_test.sql` exists, declares `-- ATTACK-CLASSES:` from the closed vocabulary, plans 16, contains `throws_ok`, and contains the in-file mutation control that drops the trigger inside a savepoint.
- [x] Every refusal in that file asserts SQLSTATE `42501` and the exact message Step 1 names, and its signed-in actor is an `owner` at `aal2`.
- [x] `npx supabase test db` reports 0 failures and the assertions executed equal the sum of the literal `plan(N)` declarations across `supabase/tests`.
- [x] The Execution Log records all five mutants of the Mutation Obligation, each turning red exactly the assertions this contract names for it, and the unmutated migration turning none red.
- [x] `reports/master/MASTER_API_CONTRACT.md` is byte-identical to its state at the start of this Change Request.
- [x] `reports/master/MASTER_GAP_REGISTER.md` carries a `CONV-6` row, FIXED by SPEC-213, with an empty Owner Decision cell, and its `Last updated:` entry is dated 2026-09-23.
- [x] `reports/master/MASTER_SURFACE_DISPOSITION.md` records `offline_conversions` as `PARTIAL` / `ADVERSARIAL` citing `SPEC-213-conversion-provenance-is-platform-written` and `CONV-6`, its Next cell names both unswept axes, and its Coverage summary reads 14 of 77 with one `PARTIAL`.
- [x] `reports/evidence/primary-ledger-evidence.json` names `project_ref` `vrvtsxexkiiiivlkdxzp`, contains `20260923120000` in its `ledger` array, and its `migration_count` and `ledger_fingerprint` are consistent with that array.
- [x] The repository migration filename set, the local migration set and the Primary ledger recorded in that evidence file contain the same migration identities.
- [x] `_ORVION_CANONICAL/manifest.md` records Batch 6 coverage as 14 of 77, names SPEC-213 as `Last Completed` in place of SPEC-212, names Batch 6 Slice 14 as `Next capability`, and writes every mutable `Live state:` figure from a post-deployment measurement.
- [x] `ai-map.json`'s live_state copies of `Last Completed`, `Active Change Request` and `Next capability` match the manifest by value, and the file is stored with LF line endings.
- [x] The Execution Log records the owner's explicit Primary deployment authorization before the deployment, and the pre-deploy readiness gate's measured result for every item.
- [x] No file outside this contract's Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-23 — Candidate tournament (before Approval) and Steps 1-4

Outcome: Complete

Evidence gathered before this contract was frozen, all local, synthetic and rolled back:

- **Reproduction** at `a7ff994`: control run 1 conversion for tenant B; with tenant A's owner at `aal2` holding the next 50 `seq` values, 0 — the attacker's tenant held B's key, the cursor advanced past it, no finding was written, a rerun recovered nothing. UPDATE of an existing row onto a future value succeeded. A lapsed tenant's deferral closed as "the conversion was mapped on a later run" with no conversion. Held: `aal1` (MFA), `employee` (permission), cross-tenant INSERT and relocation (RLS), cross-tenant lead reference (FK), unknown event type, DELETE (no grant), lineage rewrite.
- **Candidate A**, run as a prefix to the 119 file inside one rolled-back transaction: 16/16. Baseline (no guard): 10 of the then-15 assertions red — every refusal plus the outcomes that show the loss (tenant B's conversion, idempotent rerun, recovered deferral, stray provenance).
- **Mutants against A's text** (then-15-assertion file): M1 trigger removed — 10 red, same set as baseline; M2 INSERT forgotten — INSERT refusals red; M3 UPDATE forgotten — UPDATE refusals red; M4 decision inverted — refusals and mapper outcomes red; M5 session-less exemption removed — mapper outcomes red, session refusals still green. Each red for its own reason; unmutated A none red. The in-file savepoint mutation (assertion 7) was added afterwards and passes on A.
- **Differential**: the ten existing files naming this surface (`09`, `13`, `36`, `53`, `57`, `58`, `64`, `66`, `78`, `111`) gave identical ok/not-ok counts on baseline and on A, all 0 failures. The whole suite with A prefixed: 118 files, 1958 ok, 0 not ok.
- **Generated and smoke surfaces** with A applied to the local stack: `MASTER_API_CONTRACT.md` regenerated to a scratch path byte-identical; `verify_database.sql` `ALL CHECKS PASSED (… 71/621 catalog …)`; the six Additional Verification suites each exited 0 (33, 120, 40, 74, 122, 60 passed — `verify_api_end_to_end.ps1` after a clean reset, because it refuses to run over its own earlier fixtures).
- **B** rejected under WORTH IT and **C** rejected as incomplete, both without being built; reasons in Notes.
- Local stack reset to the repository after the prototype; trigger count 0 confirmed.
- Pre-Approval evaluator run read-only on the Draft: `PASS` with profiles `DATABASE,REPOSITORY`; the same table with the Check 9/19 gate moved to Step 5 returned `FAIL:mandatory gate at step 5 lies inside the red window 1..7`. The real Approve commit reported `APPROVAL_EVIDENCE: PASS`.

Step results:
- Step 1: Applied — migration byte-identical to the prototype that passed (SHA-256 prefix `8EEF18094829247B`).
- Step 2: Applied — test byte-identical to the prototype that passed 16/16 (SHA-256 prefix `608B9680A510C310`).
- Step 3: Applied — `CONV-6` row after `USR-5`, empty Owner Decision cell; `Last updated: 2026-09-23`.
- Step 4: Applied — `offline_conversions` `PARTIAL` / `ADVERSARIAL`; Coverage 14 of 77, one `PARTIAL`, 63 `NOT-RECORDED`; `Last updated: 2026-09-23`. Checks 21, 22 and 24 clean; the only consistency failures are `MIGRATION STATE DRIFT`, `SUITE FIGURE DRIFT` and RECOVER-1 naming exactly `20260923120000_conversion_provenance_is_platform_written` as repository-only.

Commits: the In Progress transition only. Steps 1-4 stand applied in the working tree and are committed together with the post-deployment steps, as SPEC-203 did: the pre-commit hook runs repository consistency, which cannot be green while the migration is undeployed (it refused this commit with `REPOSITORY_CONSISTENCY_FAILED` on exactly the three bounded classes above).
### 2026-09-23 — Pre-deploy readiness gate (Step 5)

Outcome: Blocked

The first attempt was voided when the workstation restarted and Docker Desktop was down; every item below is from the re-run on a freshly started stack.

Step results:
- Step 5: Applied — every item held:
  - clean `npx supabase db reset`: exit 0; the reset database carries `offline_conversions_forbid_session_provenance_write` and its latest migration is `20260923120000`.
  - pgTAP **Pass A**: `Files=119, Tests=1974`, `Result: PASS`; the literal `plan(N)` sum across `supabase/tests` is **1974**.
  - Additional Verification, in order, each exit 0: `verify_api_end_to_end` 33 passed, `verify_role_journeys` 120, `verify_care_journeys` 40, `verify_journey_branches` 74, `verify_lifecycle_branches` 122, `verify_storage_end_to_end` 60 — 449 in total, 0 failed.
  - pgTAP **Pass B** after those suites, no reset: `Files=119, Tests=1974`, `Result: PASS`.
  - `scripts/verify_database.sql`: `ALL CHECKS PASSED (77 tables, … 71/621 catalog …)`.
  - Mutants of Step 1's text, each in one rolled-back transaction ahead of the 119 body with the real trigger dropped first: unmutated 16/16; M1 protection removed (no-op body) red 4,5,6,7,8,9,10,11,13,14,16; M2 INSERT forgotten red 4,5,7,8,9,10,11,13,14,16 with 6 green; M3 UPDATE forgotten red 6,8,9,10,11,16 with 4,5,13 green; M4 decision inverted red 4-16 except none of 1-3; M5 session-less exemption removed red 8,9,10,11,12,14,15 with every session refusal (4,5,6,13) green. Where 7 turns red it is the duplicate of the value 4 just admitted, and 10-11 under M5 turn red because the mapper never wrote tenant A's row — both consequences of the same missing predicate, not another control. Trigger present again after all six runs.
  - `scripts/generate-api-contract.ps1`: `MASTER_API_CONTRACT.md` byte-identical.
  - `git status`: only the four Write Scope paths of Steps 1-4.
  - Exactly one migration absent from the recorded Primary ledger: `20260923120000_conversion_provenance_is_platform_written` — SHA-256 `475d09cc75fab67705bb39b7ac57503e83c6040a50ce49dca2d3e4ba7fc858c9`. Test SHA-256 `fcafcdeb7261ba166afcd7c4a11224066827c7802cafbdfa5ba4d524a37a9b8f`.
  - `check_repository_consistency.ps1`: 6 issues, all three admissible classes and nothing else — `MIGRATION STATE DRIFT` (count, latest, fingerprint), `SUITE FIGURE DRIFT` (files, assertions), RECOVER-1 with `only in repository` exactly `20260923120000_conversion_provenance_is_platform_written` and no `only on Primary` set.
- Step 6: Not started — the owner has not authorized Primary deployment.

Commits: this commit (contract synchronization only; Steps 1-4 remain in the working tree for the reason recorded in the previous entry).

Blocker: Step 6 requires the owner's explicit authorization to deploy `20260923120000` to Primary `vrvtsxexkiiiivlkdxzp`. The owner's standing instruction for this slice withholds it until the local proof is presented. Nothing has been sent to Primary and Secondary has not been contacted.
### 2026-09-23 — Step 6: owner authorization and pre-deployment preconditions

Outcome: Complete

- **Owner authorization**, given after Step 5 was recorded: "AUTHORIZED: proceed with Slice 13 Primary deployment", limited to this contract's proven implementation, target `vrvtsxexkiiiivlkdxzp`, migration `20260923120000_conversion_provenance_is_platform_written.sql` with expected SHA-256 `475d09cc…58c9`, at approved HEAD `09e3114a061619b79156200caca49d9ac16cf284`; Secondary excluded.
- HEAD re-read: `09e3114a061619b79156200caca49d9ac16cf284` — matches.
- Migration SHA-256 recomputed: `475d09cc75fab67705bb39b7ac57503e83c6040a50ce49dca2d3e4ba7fc858c9` — matches.
- (a) Target read live through the `supabase-primary` connector: `https://vrvtsxexkiiiivlkdxzp.supabase.co` — Primary, not Secondary `brplkqmbzffpxqgkkdzo`.
- (b)(c) Primary ledger read before deployment with the recorded `read_query`: count **219**, fingerprint `dd2427080e9cfb5e8d1d162bf818360f`, latest `20260920120000`, `20260923120000` ABSENT — equal to the recorded evidence, so exactly one migration is pending.
### 2026-09-23 — Steps 6-9: Primary deployment and post-deploy verification

Outcome: Complete

Step results:
- Step 6: Applied — (d) `supabase-primary` `apply_migration` with the exact text of Step 1's file (SHA-256 `475d09cc…58c9`) and nothing else: success. (e) The connector assigned `20260923190332`; that one row was normalised to `20260923120000`. (f) Full ledger re-read with the recorded `read_query`: count **220**, fingerprint `3ab05c984755ffbca5b44ba9557b83dd`, `20260923120000` present once. (g) Function surface read FROM Primary with the Check L2/P2 expression: `36eb361586ebcc6cbd0398b691e2111a`, 299 functions; `scripts/parity_surface.sql` run on Primary: `_combined` `1d5093214909ed9638c928f02e959a12`, 3031 objects, and all ten per-surface hashes equal the local stack's. Evidence file rewritten from those readings at `09/23/2026 19:05:17`, `repository_head` `09e3114`; the ledger array was admitted only after its ordered md5 equalled Primary's fingerprint. (h) Repository filenames, local ledger and Primary ledger are the same 220 identities. (i) `check_database_parity_evidence.ps1` first exited 1 on Check L5 alone — the manifest still published the pre-deployment hashes, which Step 7 exists to replace; P1, P2, P4 and L3 all matched.
- Step 7: Applied — remeasured and rewritten: 220 migrations, latest `20260923120000`, ledger `3ab05c98…`, function surface `36eb3615…` (299), structural surface `1d509321…` (3,031), 77 tables, 71/621 catalog, 8 reporting views, 79 client RPCs, suite 119 files / 1974 assertions, 449 HTTP assertions; coverage 14 of 77; `Last Completed` SPEC-213 replacing SPEC-212; `Next capability` Batch 6 Slice 14. Manifest 6690 characters.
- Step 8: Applied — `ai-map.json` regenerated and stored LF.
- Step 9: Applied — `check_database_parity_evidence.ps1` exit 0 (`DATABASE PARITY: CLEAN`; `PRIMARY PARITY EVIDENCE: CLEAN`), `check_primary_ledger.ps1` exit 0 (`RECOVER-1 LEDGER EVIDENCE: CLEAN`), `check_repository_consistency.ps1` exit 0 (`REPOSITORY CONSISTENCY: CLEAN`).

No second repair was needed or attempted. Secondary was not contacted.

Commits: this commit (Steps 1-9).
## Verification Notes

### 2026-09-23 — Review

Verdict: Confirmed Complete

Findings: re-checked against the live repository, the local stack and the recorded Primary reading, not against the Execution Log.
- The migration contains the function, the revoke and the `BEFORE INSERT OR UPDATE` trigger and nothing else: no `security definer`, grant, policy, index or constraint. It is the only migration added since `a7ff994`, so `app.map_outcomes_to_conversions`, every policy and every grant on the table are untouched; the `grants` surface still hashes `402bf96caafc025268889650138405e8`, the value PAR-5 recorded.
- The local catalog shows exactly one trigger executing `app.forbid_session_provenance_write`, `BEFORE INSERT OR UPDATE ON public.offline_conversions`, and `PUBLIC` holds no `EXECUTE` on it. Primary's trigger and structural surfaces equal local's.
- `119_…` declares `-- ATTACK-CLASSES:`, plans 16, and carries six `throws_ok`, each on `42501` with the exact message, as an `owner` at `aal2`, plus the savepoint mutation control.
- `-Finish` returned `LOCAL_CERTIFY: READY`; pgTAP ran 119 files / 1974 tests against a plan sum of 1974.
- `MASTER_API_CONTRACT.md` is byte-identical to `a7ff994`. `CONV-6` is registered with an empty Owner Decision cell; the disposition row, the Coverage totals and both freshness headers are as specified.
- The evidence file names `vrvtsxexkiiiivlkdxzp`, holds 220 identities including `20260923120000`, and equals the repository and local sets. The manifest publishes 14 of 77, SPEC-213 as `Last Completed`, Slice 14 as `Next capability` and the post-deployment figures; `ai-map.json` agrees (Check 7 clean) and is stored LF.
- Files changed since `a7ff994`: exactly the nine Write Scope paths other than `MASTER_API_CONTRACT.md`, which did not need to change.

Recommendation to human: Set Status to Complete
## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

Candidate selection, recorded so it is not re-litigated. Three designs were compared on one invariant: a signed-in session must not control `source_event_seq`, while the session-less mapper still writes it. **A** (this contract) was prototyped in rolled-back transactions and passed its full matrix, the ten-file differential and the whole suite. **B** (column privileges) was rejected under WORTH IT without being built, because it needs the table-level INSERT and UPDATE removed and 16 columns re-granted for each, an allowlist every future column must remember, with no stronger guarantee. **C** (a tenant-scoped foreign key to `events`) was rejected as incomplete without being built, because a tenant could still write the key of one of its own events, and it would add a unique constraint to the audit spine.

Deliberately not absorbed: signed-in writes by an authorised owner to the identity snapshot, value or time after creation, and creation-event parity for direct-DML rows. Both are named in the disposition row's Next cell rather than registered as findings, because neither was classified in this slice.
