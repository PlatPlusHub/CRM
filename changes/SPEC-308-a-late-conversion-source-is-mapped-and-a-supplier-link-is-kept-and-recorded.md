# Change Request — SPEC-308

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 52 makes the conversion mapper wait for every conversion source event that has taken its seq but not yet committed, so that a qualification, booking, payment or issuance that commits after a later one is still mapped. It also records every internal supplier link on every door and keeps each link as it was written, so no conversion is lost to commit order and no fulfilment record is made or rewritten unrecorded (CONV-11, ISL-1, ISL-2).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `ca2c189`, on the live local catalog, ranks `events` first (Exposure 6, coverage 400), then `scheduled_job_findings` (5/18) and `internal_supplier_links` (5/18), all NOT-RECORDED. Under the owner's instructions of 2026-11-14, this slice's entry grouped the selector's next three surfaces in one contract per product. Each surface keeps its own finding rows, migration or test, and disposition row. The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.**
  - `app.map_outcomes_to_conversions` turns four source events (`lead_qualified`, `booking_created`, `payment_recorded`, `booking_issued`) into the offline conversions delivered to Google Ads. It reads them past its cursor in `integration_cursors` and moves the cursor to the highest `seq` it read.
  - `events.seq` is a `generated always` identity: it is assigned at insert and becomes visible at commit, so seqs do not become visible in order.
  - `internal_supplier_links` is the append-only record of which branch and department fulfil a booking item. Its RPC `app.link_internal_supplier` records `internal_supplier_linked`. SUP-1 brought the RPC's rules to the table door, which every ASSIGN_SUPPLIER holder may write.
- **Measured at `ca2c189`** on the local stack. The fixtures were one tenant with an owner, a ceo, a senior employee and two employees in two branches, plus another tenant, two Google Ads call leads, a booking with two items and a link.
  - **CONV-11 (Medium).** Two sessions qualified the two leads, taking seqs 129 and 130. The session holding 130 committed first, and the mapper ran while 129 was still open: it mapped 130 and moved `outcome_conversion_mapper` to 130. After 129 committed, the next run mapped nothing, so that lead's `qualified_phone_call` was never formed. CONV-1's deferral covers a lapsed tenant, not a late commit.
  - **ISL-1 (Low).** A `senior_employee` holding ASSIGN_SUPPLIER linked an item at the table door, and the tenant's events did not move. The same link through the RPC recorded `internal_supplier_linked`.
  - **ISL-2 (Low).** The same senior re-pointed a link's provider to another branch, moved the link to another booking item and back-dated it to 2019, each by UPDATE, and nothing was recorded. The RPC describes the table as append-only and SUP-1 calls it an append-only log, but nothing enforced it.
  - **Why ISL-1 and ISL-2 are Low.** This is SUP-1's measured reason, re-measured here: nothing reads the table but its RPC and `app.guard_write_capability`.
- **The repair: two migrations.**
  - `20261114160000` (CONV-11):
    - `app.record_event`, for the four source types only, takes `pg_advisory_xact_lock_shared` on the key `hashtextextended('app.map_outcomes_to_conversions', 0)` before the event takes its seq, and holds it to commit.
    - `app.map_outcomes_to_conversions` first calls `pg_try_advisory_lock` on the same key. While any source writer is open, it maps nothing and returns 0, and the next run retries from the same cursor.
    - Otherwise it reads `max(seq)` as its horizon, releases the lock at once, and reads both forward windows only up to that horizon. No source seq at or below the horizon can still commit.
    - No writer waits on the mapper, and the mapper waits on no writer. The key form is `app.process_lead_sla`'s.
    - Unchanged: the cursor, the idempotency key, the CONV-1 deferral window and every other rule, and both functions' signatures, security mode and grants.
  - `20261114170000` (ISL-1, ISL-2):
    - `app.emit_internal_supplier_linked` (AFTER INSERT, SECURITY DEFINER, empty `search_path`, executable by no client role) records every link as `internal_supplier_linked`, with the actor, the link id and both org units, at canon 27's `info`. This is SPEC-215's emitter form.
    - `app.link_internal_supplier` no longer records its own event. It hands its reason over through `app.transition_reason`, which the emitter consumes (SPEC-237's pattern), so the RPC records once.
    - `internal_supplier_links_append_only` (BEFORE UPDATE OR DELETE, `app.forbid_mutation`) makes the table append-only for every writer. A new provider is a new link.
  - No grant, policy, RPC signature, event code or cursor rule changes.
- **`scheduled_job_findings` is recorded with no finding.** The mapper's deferral path writes it unchanged. It has no client grant, and its two functions are executable by no client role (tests 66 and 119).
- **Existing files that move, each for a stated reason.**
  - `_ORVION_CANONICAL/27_event_catalog.md`: what `internal_supplier_linked` records.
  - No existing test moves. The generated `MASTER_API_CONTRACT.md` is reproduced byte-identically on the final bytes; it is in Write Scope only because mandatory Check L3 regenerates it, and an Acceptance Criterion proves it unchanged.
- **Swept and found sound, pinned rather than changed:**
  - No client role inserts, updates or deletes an event, and `app.forbid_mutation` binds the table owner too.
  - `app.record_event` refuses another tenant and is not served over REST (API-1).
  - Another branch's and another tenant's events are not read (AUDIT-6).
  - `scheduled_job_findings` refuses an owner at `aal2` to read, insert or call either function.
  - At the link door, an employee without ASSIGN_SUPPLIER and an owner at `aal1` are refused. There is no DELETE grant, and another tenant reads no link.
- **Recorded positions, not repaired:**
  - A signed-in session may call `app.record_event` for its own tenant over a direct database connection, never through the API (API-1's position).
  - A link's `created_at` is caller-supplied on INSERT and read by nothing that decides (SPEC-216's schema-wide question).
  - Links are readable tenant-wide (ids and org units only).
  - A mapper run that meets an open source writer maps nothing, and the next run retries.
- **Latent on Primary.** `vrvtsxexkiiiivlkdxzp` holds 0 tenants, 0 events, 0 offline conversions, 0 findings and 0 links, and the mapper cursor is 0 (read-only, 2026-11-14, ledger 263). No stored row is affected and no data repair is needed.

## Risks

- **A mapper run that meets an open source writer maps nothing** and returns 0. The cursor does not move, and the next run maps what it skipped. A conversion is delayed by at most one run interval per open writer, never lost. Source transactions are single RPC calls, so a writer open at every run is not expected. No run was measured skipping twice.
- **Every conversion source event takes a shared advisory lock** and holds it to commit. Shared locks never conflict with each other, so source writers do not wait on one another. The mapper holds the exclusive form only between its try and its horizon read, never while it writes.
- **The link table is append-only for every writer**, the platform included. A correction is a new link. No consumer reads links, and no existing test updates or deletes one.
- **Trigger order.** The new AFTER INSERT emitter records after the existing BEFORE guards admit the row. The new BEFORE UPDATE OR DELETE refusal fires before any other trigger on those operations, and the existing triggers are unchanged.
- **Primary deployment is irreversible.** It runs only under the exact-SHA Gate-2 record of Step 9, and approval of this contract does not authorize it. Both migrations deploy in one sitting. If a stop falls between them, the half-deployed state is recorded in the Execution Log when it happens. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions, recorded outside this repository and never as a human-typed digest:
  - class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo
  - publish, promote and hosted deploy, ~12:05 Cairo
  - slice 10 in run mode 2, with the slice's own grouping decision, 2026-11-14 ~16:20 Cairo

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-308-a-late-conversion-source-is-mapped-and-a-supplier-link-is-kept-and-recorded.md`
- `supabase/migrations/20261114160000_a_conversion_source_event_is_mapped_even_when_it_commits_late.sql`
- `supabase/migrations/20261114170000_an_internal_supplier_link_is_appended_and_recorded_on_every_door.sql`
- `supabase/tests/169_a_conversion_source_event_is_mapped_even_when_it_commits_late_test.sql`
- `supabase/tests/170_an_internal_supplier_link_is_appended_and_recorded_on_every_door_test.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042600_create_event_and_notification_tables.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `supabase/migrations/202607045900_link_internal_supplier.sql`
- `supabase/migrations/202607049300_outcome_conversion_mapper.sql`
- `supabase/migrations/202607053000_event_write_path_integrity.sql`
- `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql`
- `supabase/migrations/202607058600_a_task_changes_hands_only_with_authority.sql`
- `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql`
- `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql`
- `supabase/migrations/20261114140000_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code.sql`
- `supabase/tests/34_event_write_path_test.sql`
- `supabase/tests/66_scheduled_job_isolation_test.sql`
- `supabase/tests/119_conversion_provenance_is_platform_written_test.sql`
- `scripts/verify_database.sql`
- `scripts/generate-api-contract.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/readiness_population.ps1`
- `scripts/parity_surface.sql`
- `scripts/check_database_parity.ps1`
- `scripts/check_primary_ledger.ps1`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `reports/architecture-decision-records.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `supabase/migrations/202607049300_outcome_conversion_mapper.sql` (the mapper and its cursor)
- `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql` (CONV-1's deferral and `scheduled_job_findings`)
- `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql` (the mapper's current body)
- `supabase/migrations/202607053000_event_write_path_integrity.sql` (`app.record_event`)
- `supabase/migrations/202607045900_link_internal_supplier.sql` and `202607058600_a_task_changes_hands_only_with_authority.sql` (the link table and SUP-1)
- `changes/SPEC-215-supplier-creation-is-recorded.md` (the AFTER INSERT emitter form)
- `changes/SPEC-237-conversion-source-door-parity.md` (`app.transition_reason`)
- `reports/master/MASTER_GAP_REGISTER.md` (CONV-1…CONV-10, SUP-1, API-1, AUDIT-6)
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11

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
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Three surfaces are covered in one contract.

- **`events`.** `app.record_event` takes the shared form of one advisory key for the four source types, and the mapper tries the exclusive form without waiting before it reads its horizon. Its forward windows stop at that horizon.
- **`internal_supplier_links`.** One AFTER INSERT emitter records every link, the RPC hands over its reason, and one BEFORE UPDATE OR DELETE refusal keeps the table append-only.
- **`scheduled_job_findings`.** It is recorded with no change.
- **Tests and records.**
  - Test 169 pins the lock, its form, its release and the horizon, beside one mapped qualification and its replay.
  - Test 170 pins the record on both doors, the consumed reason, append-only for every writer and a session-less link.
  - The register records three new rows, the disposition records the three surfaces, and canon 27 says what `internal_supplier_linked` records.

Pass 2 Adversarial Review: The design was challenged on the prototype.

- **Rejected designs:**
  - **An exclusive transaction lock that the mapper holds through its writes.** It could deadlock: the mapper's inserts take KEY SHARE on the rows a source writer has locked FOR UPDATE, while that writer waits on the mapper.
  - **A snapshot horizon (`pg_snapshot_xmin`, xid8 on each event).** It would add a column. The mapper tests run in one transaction, so their own events would sit above any xmin, and nine of them would stop proving what they prove.
  - **Moving the cursor only to the lowest open seq.** PostgreSQL does not expose another session's uncommitted identity values, so it cannot be read.
  - **Recording the link event inside the RPC and the door separately.** It would record the RPC's links twice. One emitter is the SPEC-215 form, and the reason hand-over is SPEC-237's.
  - **Revoking UPDATE from `authenticated` instead of a refusal trigger.** A grant binds only client roles, while the history must hold for every writer, the platform included (mutant M2 removes the refusal and is killed).
  - **Copying the selector's next target into the manifest** (SPEC-270; SPEC-278's cancellation).
- **Attacks run on the final bytes.**
  - The two-session harness maps the late qualification on the next run and refuses every rewrite.
  - Every existing test that touches the three surfaces passes, and so does the full suite.
  - The generated API contract does not move.
  - Each held behavior was probed and holds.

Pass 3 Evidence Refresh: 2026-11-14.

- **Re-measured** on byte-identical files in a disposable clone of `ca2c189`, with the project-local CLI 3.0.0:
  - the clean reset
  - tests 169 and 170 alone, and pgTAP Pass A and B
  - the three declared HTTP suites and smoke
  - the probes and the two-session harness, before and after
  - all nine mutants and the two causal negatives
  - the structural fingerprints before and after
  - the API-contract generator (identical), the map generator and repository consistency
- **Read read-only on hosted.** Primary and Founder Secondary were read for their ledgers, tenants, events, findings and links.

Selected Version: SPEC-308; selected: the smallest repair that closes CONV-11, ISL-1 and ISL-2 (a shared advisory lock that every conversion source event holds to commit and the mapper tries without waiting before it takes its horizon; an AFTER INSERT emitter that records every supplier link on every door; the link table append-only; no grant, policy, RPC signature, event code or cursor rule changed), proven on byte-identical files by the full local protocol, the two-session harness before and after, nine killed mutants and the two causal negatives

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A conversion source event holds the mapper's key, in its shared form, from before its seq to commit; the mapper maps only up to a horizon taken while no source writer is open | every caller of `app.record_event` that records `lead_qualified`, `booking_created`, `payment_recorded` or `booking_issued`; the emitters of SPEC-237, SPEC-238 and SPEC-239; `app.map_outcomes_to_conversions` and the integration role that runs it; `integration_cursors`; `offline_conversions` | WRITE | Migration SHA-256 `38f8419e49b8a4a899ac94dac8ec21460a2dab0d29796cb11f8e4f4aec962eb9`, md5 `bad439fd0afb9c2b281ee56ac7e66c3c`, 15551 bytes, LF, ASCII. `md5(prosrc)` of `app.record_event` is `63c530c75036e3b50c21ca7e2222415a` (was `2aca012e796cea969ca542028ed34c49`); of the mapper, `103290e8791a537d15c0192b27469861` (was `2b3dce415e5968e633e5e856cd30f953`). Both stay SECURITY DEFINER with their ACLs unchanged. A run that meets an open source writer returns 0 with the cursor unchanged. Tests 34, 36, 66, 89, 119, 137, 139-142 and 144 pass unchanged. |
| Every internal supplier link is recorded once, on every door, and is never changed or deleted | the link door of every ASSIGN_SUPPLIER holder; `app.link_internal_supplier`; readers of `public.events`; canon 27 | WRITE | Migration SHA-256 `df7d6433c9c1bd4c6485bf73b627e761c38f931d768fa4a20297bc294065a057`, md5 `e7ab821346241cb45d4e72f7a8ba2f70`, 6149 bytes, LF, ASCII. The RPC's `md5(prosrc)` is `53a7eecb49d9d43e04d59939d7a3b533` (was `7cfbd5ce3b0f035b428f654d14dd5f4f`), still SECURITY INVOKER with its signature and ACL unchanged. The emitter's is `2ab772b33b2e17c270f0b7c16d936b40`, SECURITY DEFINER, ACL `{postgres=X/postgres}`. Triggers: `internal_supplier_links_emit_linked` AFTER INSERT and `internal_supplier_links_append_only` BEFORE UPDATE OR DELETE. The code `internal_supplier_linked` is unchanged at `info`. Tests 53, 57, 58 and 81 pass unchanged. |
| The mapper's deferral record | `scheduled_job_findings`; `app.record_job_finding`; `app.resolve_job_finding`; `app.scheduled_job_health` | UNAFFECTED | The deferral window and its findings are unchanged. Tests 66 and 119 pass unchanged. |
| A clean reset holds both | the local stack; `supabase_migrations.schema_migrations` | WRITE | A clean reset gives 265 migrations, latest `20261114170000`, ledger `2a17e52e8270cf7bb2e546dbb0c9f591`. `events` carries 1 trigger and `internal_supplier_links` 5, of which 2 are new. Catalog 71/626. |
| Tests 169 and 170 | `supabase/tests` | WRITE | Test 169: SHA-256 `3dd91b7482963b2aa66a778e3ec53cfc11ff466e4ba8bea5590eec903e35c269`, md5 `4a80dd090ae21009c4c848f28fb45b98`, 5201 bytes, `plan(10)`: 10/10. Test 170: SHA-256 `cf099ff047d5503cccfb28d4114ef104fd7deaccaff4c349038b49a0694306eb`, md5 `ef873e0bd2ff4b034e1836f8111f65f6`, 9446 bytes, `plan(11)`: 11/11. Each LF, ASCII. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=170, Tests=3172`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 170/3172, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/626 catalog). The 170 files' literal `plan(N)` values sum to 3172. No existing test and no line of `scripts/verify_database.sql` moves. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (263): functions `0b3b9c82bb521f6744950201471196a6`/346, triggers `d241997ceaab37c02327503b4e2587cb`/332, `_combined` `f87d6fee4ce1857bc3f35672c7ef8a4e`/3169, equal to the recorded Primary evidence. After (265, local): functions `58dc8cf1aaec56b1ba63eabf7391ac0a`/347 (+1), triggers `b4a4d2babd4fa85cf46268d2b934268a`/334 (+2), `_combined` `aeb5931b5df96106439433dce07cfe2a`/3172. Policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged. Step 11 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3); `scripts/generate-api-contract.ps1` | VERIFY | No RPC is added or removed, and no signature or grant changes. `app.record_event` stays unexposed (API-1). On the final bytes the generator's output equals the committed contract byte for byte. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 263 → 265 migrations, latest `20261114170000`, ledger fingerprint `2a17e52e8270cf7bb2e546dbb0c9f591`; 168 → 170 files and 3151 → 3172 assertions; coverage 54 → 57 of 78. Tables (78) and client RPCs (80) do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 12 names `Current Module` and `Next capability` only to leave them unchanged. Each line keeps its ratified text and pin. |
| CONV-11, ISL-1 and ISL-2 fixed; three surfaces recorded; canon 27 | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `27_event_catalog.md`; Checks 21, 22, 24, 25, 29 | WRITE | No CONV-11, ISL-1 or ISL-2 row exists at `ca2c189`. Tests 169 and 170 each declare the ten classes with their N/A classes reasoned. Test 170 carries negative assertions and names both `internal_supplier_links` and `events`, and test 119 names `scheduled_job_findings`, so Check 24 admits `ADVERSARIAL` for all three. Test 169 carries none: its concurrency proof is the two-session harness. Each new row has Owner `—` and is settled. Coverage 57: 33 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 21 `NOT-RECORDED`; all 57 `ADVERSARIAL`. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–7 applied and the contract present, consistency reports exactly the measured-state items: 263 vs 265 migrations, the latest version, the ledger fingerprint, 168 vs 170 files, 3151 vs 3172 assertions, and the Primary-evidence record. Checks 21–29 pass. Step 11 makes the measured-state items true, and the one implementation commit is made only after it. |
| The four CI-only guard self-tests | `scripts/test_*_guard.ps1`; `orvion-acceptance` | VERIFY | The scripts are unchanged. `orvion-acceptance` runs them on the exact candidate SHA before `main` may move to it. Their controls require the measured state of Step 11, so they are not run locally (timed once in slice 47: 618 s locally, 84 s in hosted CI). |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 10 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, probes, mutants and causal negatives hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 8 |
| Primary lacks both target migrations, and its ledger and structure equal the recorded evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 10 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 11 | Step 12 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 3 | Step 11 | Step 12 |
| The map matches its generator | BEFORE_COMPLETION | Step 1 | Step 11 | Step 12 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: Nothing makes the cursor wait for a seq that is assigned but not yet visible, records a door link, or keeps a link unchanged.

- The mapper advances its cursor to the highest `seq` it read, which is visible only once its writer commits.
- CONV-1's deferral covers a lapsed tenant, never a late commit.
- `app.process_lead_sla`'s try-lock keeps two passes of one job apart. It does not order a job against its sources.
- `app.link_internal_supplier` records its own link only.
- `app.guard_write_capability` and SUP-1's rule trigger decide who may write a link and what it may say, not whether a written link may change.

Added Property: For every writer:

- every conversion source event whose seq the mapper's cursor passes was committed when the mapper took its horizon, so the mapper maps it on that run or a later one;
- every internal supplier link is recorded once with its actor;
- no link is ever changed or deleted.

Causal Negative: On the `ca2c189` schema (the stack reset to `20261114140000`), test 169 fails assertions 3–6 and test 170 fails 1, 3 and 5–11. They fail the same assertions with the pre-repair `app.record_event`, mapper and RPC restored and the two new triggers removed: the same set both ways. There, the two-session harness leaves the late qualification unmapped, and the probes record no door link and accept a link's provider, item and date rewritten by UPDATE.

Positive Test Design: One tenant with a Giza and an Alex branch, a senior employee, a booking with two items, and a Google Ads call lead. Positive controls:

- a qualification is mapped once, and a second run adds nothing;
- a senior's door link and RPC link are each recorded once;
- a session-less link is recorded with no actor;
- a link's first provider is still the one written.

Negative Test Design: by attack class, as follows.
- **Concurrency:** a source event holds the shared lock to commit, and an event that is no source takes none. The mapper tries the exclusive form without waiting, releases it, and stops both forward reads at its horizon. The race itself is the two-session harness: before the repair the late seq is never mapped; after it, the run that meets the open writer maps nothing and the next run maps both.
- **Replay:** a second mapper run adds nothing.
- **Door:** a link made at the table door is recorded like one made through the RPC.
- **State:** a link's provider, item and date cannot be rewritten in place, by a session or by a session-less writer, and no writer deletes one.
- **Privilege:** the emitter is SECURITY DEFINER with no client EXECUTE; the append-only refusal binds the session-less writer too.
- **Observability:** the RPC's link is recorded once with its reason, and the next link in the same transaction carries none.
- **Auth, tenant and input:** the existing guards cover these, unchanged (tests 34, 57, 58 and 81).

Non-Empty Population Obligation: Each test's fixture holds its tenant, branches, users, roles and rows before the first assertion: in 169 a call lead, and in 170 a booking with two items and a senior employee. Each refusal is asserted by its SQLSTATE and exact message, and each record by its exact fields.

Mutation Obligation: Each mutant is installed inside its test's own rolled-back transaction, proven installed by a diag line (the md5 of the slice functions and the table's trigger count), run, and rolled back. The restored shape is read after the last mutant. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| 169 M1 | no source event takes the lock | 169 assertions 3 and 4 |
| 169 M2 | one source type (`booking_issued`) missing from the lock | 169 assertion 4 |
| 169 M3 | the mapper does not try the lock | 169 assertion 5 |
| 169 M4 | one forward read ignores the horizon | 169 assertion 6 |
| 169 M5 | the mapper keeps its lock | 169 assertion 9 |
| 170 M1 | the emitter trigger dropped | 170 assertions 1, 3, 4, 5 and 10 |
| 170 M2 | the append-only trigger dropped | 170 assertions 1, 6–9 and 11 |
| 170 M3 | the reason not consumed | 170 assertion 5 |
| 170 M4 | the RPC's pre-repair body: it records too | 170 assertion 4 |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI:

- the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the generated artifacts, repository consistency and the recorded Primary evidence.

Before Step 10: the focused tests, the probes and the two-session harness, the mutants, the causal negatives and the fresh Primary baseline of Step 8.

## Implementation Steps

1. Check whether `supabase/migrations/20261114160000_a_conversion_source_event_is_mapped_even_when_it_commits_late.sql` contains `CONV-11 -- Batch 6 slice 10`; if so record Already Applied when its Git blob is 03bb907860a50895db5135d8d92778d397c5a8a6, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the events migration: the source lock in record_event and the mapper's horizon), and change nothing else:

   ```text
   -- CONV-11 -- Batch 6 slice 10 (`events`).
   --
   -- THE RULE. `app.map_outcomes_to_conversions` reads conversion source events past its cursor and
   -- moves the cursor to the highest seq it read. A seq is taken when the event is inserted, but the
   -- event becomes visible only when its transaction commits, so seqs do not become visible in order.
   -- Measured before this migration (two sessions, local stack): session A recorded `lead_qualified`
   -- for lead L1 (seq 129) and held its transaction open; session B recorded `lead_qualified` for L2
   -- (seq 130) and committed; the mapper ran, mapped L2 and moved the cursor to 130; A committed; the
   -- next run mapped nothing. L1's qualification never became a conversion, and nothing recorded
   -- that it was lost. The same holds for `booking_created`, `payment_recorded` and `booking_issued`.
   --
   -- THE REPAIR. Every conversion source event is recorded under the shared form of one advisory lock,
   -- held to its commit, and the mapper takes the exclusive form only for the instant it reads its
   -- horizon (the highest committed seq). Granted, it proves no source writer is open, so every source
   -- seq up to the horizon has ended and any later one is taken after it; the run maps only up to the
   -- horizon. Refused, the run maps nothing and the next run retries from the same cursor: a delay,
   -- never a loss. The lock is never held while the mapper writes, so it cannot deadlock with a
   -- writer's row locks, and a writer waits at most for one read of `max(seq)`.
   --
   -- NOT CHANGED: every grant, policy, table and index; every other line of both functions, among them
   -- `record_event`'s authority, validation and insert, and the mapper's window, deferral, recovery
   -- and cursor update. No event type, severity or payload changes.
   create or replace function app.record_event(p_tenant_id uuid, p_event_type_code text, p_entity_type text, p_entity_id uuid, p_actor_user_id uuid DEFAULT NULL::uuid, p_previous_state text DEFAULT NULL::text, p_new_state text DEFAULT NULL::text, p_reason text DEFAULT NULL::text, p_payload jsonb DEFAULT NULL::jsonb, p_severity_code text DEFAULT 'info'::text)
    RETURNS uuid
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO ''
   AS $function$
   declare
       v_event          uuid;
       v_session_tenant uuid := app.current_tenant_id();
       v_tenant         uuid;
       v_actor          uuid;
   begin
       -- Tenant and actor authority. A user session may only ever write into its own tenant, as
       -- itself; a system path (no session) supplies the tenant and may not name a human actor.
       if v_session_tenant is not null then
           if p_tenant_id is distinct from v_session_tenant then
               raise exception 'record_event: tenant % is not the caller''s tenant %',
                   p_tenant_id, v_session_tenant
                   using errcode = 'insufficient_privilege';
           end if;
           v_tenant := v_session_tenant;
           v_actor  := app.current_user_id();
       else
           if p_tenant_id is null then
               raise exception 'record_event: no active tenant and no tenant supplied'
                   using errcode = 'insufficient_privilege';
           end if;
           if p_actor_user_id is not null then
               raise exception 'record_event: a system-context event may not name an actor'
                   using errcode = 'insufficient_privilege';
           end if;
           v_tenant := p_tenant_id;
           v_actor  := null;
       end if;

       if not exists (
           select 1 from public.catalog_values
           where catalog_type_code = 'event_type' and code = p_event_type_code
       ) then
           raise exception 'unknown event_type_code: % (register it in 27_event_catalog.md + the event_type catalog first)', p_event_type_code;
       end if;
       if not exists (
           select 1 from public.catalog_values
           where catalog_type_code = 'event_severity_code' and code = p_severity_code
       ) then
           raise exception 'unknown severity_code: %', p_severity_code;
       end if;

       -- CONV-11: a conversion source event takes its seq under the shared form of the mapper's lock
       -- and keeps it to commit, so the mapper never takes its horizon while such a writer is open.
       if p_event_type_code in ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued') then
           perform pg_advisory_xact_lock_shared(hashtextextended('app.map_outcomes_to_conversions', 0));
       end if;

       -- created_at is intentionally not in the column list: it is the server-side default, so no
       -- caller -- RPC or direct -- can backdate an event.
       insert into public.events (
           tenant_id, event_type_code, severity_code, actor_user_id, entity_type, entity_id,
           previous_state, new_state, reason, payload
       )
       values (
           v_tenant, p_event_type_code, p_severity_code, v_actor, p_entity_type, p_entity_id,
           p_previous_state, p_new_state, p_reason, p_payload
       )
       returning id into v_event;
       return v_event;
   end;
   $function$;

   create or replace function app.map_outcomes_to_conversions(p_batch integer DEFAULT 500)
    RETURNS integer
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO ''
   AS $function$
   declare
       v_cursor bigint;
       v_max_seq bigint;
       v_inserted integer := 0;
       v_horizon bigint;
   begin
       -- CONV-11: the horizon. Every conversion source event is written under the shared form of this
       -- lock (`app.record_event`), held to its commit, so the exclusive form is granted only when no
       -- such writer is open: every source seq up to the highest committed seq has then ended, and
       -- any later one is taken after it. The lock is held only to read that seq, never while this
       -- run writes, so it cannot deadlock with a writer's row locks; when a writer is open this run
       -- maps nothing and the next run retries from the same cursor.
       if not pg_try_advisory_lock(hashtextextended('app.map_outcomes_to_conversions', 0)) then
           return 0;
       end if;
       begin
           select coalesce(max(seq), 0) into v_horizon from public.events;
       exception when others then
           perform pg_advisory_unlock(hashtextextended('app.map_outcomes_to_conversions', 0));
           raise;
       end;
       perform pg_advisory_unlock(hashtextextended('app.map_outcomes_to_conversions', 0));
       select last_seq into v_cursor
       from public.integration_cursors
       where name = 'outcome_conversion_mapper'
       for update;

       begin
           -- The forward window, exactly as before. Deferred seqs are all BELOW the cursor, so they
           -- cannot influence where the cursor lands.
           select max(sub.seq) into v_max_seq from (
               select e.seq from public.events e
               where e.seq > v_cursor
                 and e.seq <= v_horizon
                 and e.event_type_code in
                     ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
               order by e.seq
               limit p_batch
           ) sub;

           with candidate as (
               select e.seq
               from public.events e
               where e.seq > v_cursor
                 and e.seq <= v_horizon
                 and e.event_type_code in
                     ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
               order by e.seq
               limit p_batch
           ),
           -- CONV-1: everything a previous run deferred whose tenant may be written again. Bounded by
           -- the recorded set, which is empty in normal operation and self-limiting otherwise -- unlike
           -- a "re-scan history for events with no conversion row" sweep, whose permanently
           -- unconvertible remainder grows without bound.
           recovered as (
               select f.source_seq as seq
               from public.scheduled_job_findings f
               where f.job_name = 'map_outcomes_to_conversions'
                 and f.finding_type_code = 'item_deferred'
                 and f.resolved_at is null
                 and f.source_seq is not null
                 and app.subscription_allows_write(f.tenant_id)
               order by f.source_seq
               limit p_batch
           ),
           due as (
               select seq from candidate
               union
               select seq from recovered
           ),
           batch as (
               select e.seq, e.tenant_id, e.event_type_code, e.entity_type, e.entity_id, e.payload,
                      e.created_at
               from public.events e
               join due d on d.seq = e.seq
           ),
           resolved as (
               select b.seq, b.tenant_id, b.created_at,
                      case b.event_type_code
                          when 'lead_qualified'   then 'qualified_lead'
                          when 'booking_created'  then 'booking_created'
                          when 'payment_recorded' then 'payment_received'
                          when 'booking_issued'   then 'ticket_issued'
                      end as conversion_type,
                      coalesce(
                          case when b.event_type_code = 'lead_qualified' then b.entity_id end,
                          case when b.event_type_code = 'booking_created'
                               then (b.payload ->> 'lead_id')::uuid end,
                          case when b.event_type_code = 'booking_issued' then bk.lead_id end,
                          case when b.event_type_code = 'payment_recorded' then pbk.lead_id end
                      ) as lead_id,
                      case when b.event_type_code = 'payment_recorded' then p.id end as payment_id,
                      case when b.event_type_code in ('booking_created', 'booking_issued')
                           then b.entity_id
                           when b.event_type_code = 'payment_recorded'
                           then coalesce(p.booking_id, pinv.booking_id) end
                           as booking_id,
                      case when b.event_type_code = 'payment_recorded' then p.amount end as conv_value,
                      case when b.event_type_code = 'payment_recorded' then p.currency_code end
                           as conv_ccy
               from batch b
               left join public.bookings bk
                      on b.event_type_code = 'booking_issued' and bk.id = b.entity_id
               left join public.payments p
                      on b.event_type_code = 'payment_recorded' and p.id = b.entity_id
               -- CONV-7: the invoice the payment paid, as its own event records it.
               left join public.invoices pinv
                      on b.event_type_code = 'payment_recorded'
                     and pinv.id = (b.payload ->> 'invoice_id')::uuid
                     and pinv.tenant_id = b.tenant_id
               left join public.bookings pbk
                      on pbk.id = coalesce(p.booking_id, pinv.booking_id)
                     and pbk.tenant_id = b.tenant_id
           )
           insert into public.offline_conversions
               (tenant_id, lead_id, booking_id, payment_id, attribution_click_id,
                conversion_event_type_code, conversion_value, currency_code,
                conversion_at, source_event_seq,
                customer_id, customer_email, customer_phone)
           select r.tenant_id, l.id, r.booking_id, r.payment_id, l.attribution_click_id,
                  k.conversion_type, r.conv_value, r.conv_ccy, r.created_at, r.seq,
                  cu.id, cu.primary_email, cu.primary_phone
           from resolved r
           join public.leads l on l.id = r.lead_id
           -- PH8-4: ONE qualification fact. A lead whose first-touch source is a Google Ads call is
           -- the phone-call conversion INSTEAD OF the lead one -- never both, since one event is one
           -- row -- and it is formed without a click.
           cross join lateral (
               select case when r.conversion_type = 'qualified_lead'
                            and l.lead_source_code = 'google_ads_call'
                           then 'qualified_phone_call'
                           else r.conversion_type end as conversion_type
           ) k
           left join public.customers cu
                  on cu.id = l.customer_id and cu.tenant_id = r.tenant_id
           where (l.attribution_click_id is not null or k.conversion_type = 'qualified_phone_call')
             -- SPEC-152 gate awareness. One restricted tenant's row would otherwise abort this whole
             -- set-based INSERT and leave `integration_cursors` un-advanced, stalling the mapper for
             -- every tenant on every subsequent run. What the filter must NOT do is lose the row --
             -- see the deferral recorded below.
             and app.subscription_allows_write(r.tenant_id)
           on conflict (source_event_seq) where source_event_seq is not null do nothing;

           get diagnostics v_inserted = row_count;

           -- CONV-1, the half that was missing: record what the gate filtered out, BEFORE the cursor
           -- moves past it. Restricted only -- an event whose lead carries no attribution click was
           -- never a conversion and is not deferred work.
           perform app.record_job_finding(
                       'map_outcomes_to_conversions', 'item_deferred', d.tenant_id, 'event', null,
                       d.seq, null,
                       'subscription state did not permit writes when this event was first mapped')
           from (
               select e.seq, e.tenant_id
               from public.events e
               where e.seq > v_cursor
                 and e.seq <= v_max_seq
                 and e.event_type_code in
                     ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
                 and not app.subscription_allows_write(e.tenant_id)
           ) d;

           -- Anything now carried into offline_conversions is done, whichever run mapped it.
           update public.scheduled_job_findings f
              set resolved_at = now(),
                  resolution_note = 'the conversion was mapped on a later run'
            where f.job_name = 'map_outcomes_to_conversions'
              and f.finding_type_code = 'item_deferred'
              and f.resolved_at is null
              and exists (select 1 from public.offline_conversions oc
                           where oc.source_event_seq = f.source_seq);

           -- A deferral whose tenant is writable again and which STILL produced no conversion was not
           -- deferred work at all -- the lead carries no attribution click, so it was never eligible.
           -- Closed rather than retried forever, which is what would grow this table without bound.
           update public.scheduled_job_findings f
              set resolved_at = now(),
                  resolution_note = 'reconsidered while writable; this event maps to no attributed lead'
            where f.job_name = 'map_outcomes_to_conversions'
              and f.finding_type_code = 'item_deferred'
              and f.resolved_at is null
              and app.subscription_allows_write(f.tenant_id)
              and not exists (select 1 from public.offline_conversions oc
                               where oc.source_event_seq = f.source_seq);

           if v_max_seq is not null then
               update public.integration_cursors
               set last_seq = v_max_seq, updated_at = now()
               where name = 'outcome_conversion_mapper';
           end if;

       exception when others then
           -- The cursor is deliberately NOT advanced here: an un-advanced cursor means the batch is
           -- retried, which is the safe failure. What must not happen is the failure being invisible.
           perform app.record_job_finding(
               'map_outcomes_to_conversions', 'item_failed', null, 'integration_cursor', null,
               v_cursor, sqlstate, sqlerrm);
           return 0;
       end;

       return coalesce(v_inserted, 0);
   end;
   $function$;
   ```

   The resulting file's Git blob is 03bb907860a50895db5135d8d92778d397c5a8a6.

2. Check whether `supabase/migrations/20261114170000_an_internal_supplier_link_is_appended_and_recorded_on_every_door.sql` contains `ISL-1, ISL-2 -- Batch 6 slice 10`; if so record Already Applied when its Git blob is 05dba10af68f95fbd3e7ff107998fc7fdea40e02, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the link migration: the emitter, the RPC's reason hand-over and append-only), and change nothing else:

   ```text
   -- ISL-1, ISL-2 -- Batch 6 slice 10 (`internal_supplier_links`).
   --
   -- THE RULE. A link records which branch and department fulfil a booking item for its owning unit.
   -- `app.link_internal_supplier` appends one ("history preserved; latest row = current provider")
   -- and records `internal_supplier_linked`. `authenticated` holds table-level INSERT and UPDATE, and
   -- PostgREST serves both beside the RPC. Measured before this migration (local stack, a
   -- `senior_employee` holding ASSIGN_SUPPLIER, at aal1 as that role allows):
   --   ISL-1  a link inserted at the table door added no event, where the RPC's added one;
   --   ISL-2  an UPDATE moved a link's provider from Alex to Giza, moved it to another booking item
   --          and back-dated it to 2019, and none of it was recorded: the history the RPC appends
   --          could be rewritten in place.
   --
   -- THE REPAIR, in existing shapes. One AFTER INSERT trigger is the single producer of the event
   -- (SPEC-215's `suppliers_emit_created`), so the RPC loses its own `record_event` call, which would
   -- otherwise record every RPC link twice; the RPC hands the trigger its reason through
   -- `app.transition_reason`, which the trigger consumes (SPEC-237). The actor and time are
   -- `record_event`'s: the session's user, or none on a session-less path. A BEFORE UPDATE OR DELETE
   -- trigger on `app.forbid_mutation` makes the table append-only for every writer, the owner included,
   -- as `events` is: a new provider is a new row, which is what the RPC always did.
   --
   -- NOT CHANGED: every grant, policy and constraint; the integrity and capability guards; the event's
   -- type, entity, severity and payload keys (the payload values are read from the row the guard
   -- derived); and every other line of `app.link_internal_supplier`. A link's caller-supplied
   -- `created_at` on INSERT stays a recorded position (SPEC-216's question, as slices 7-9).
   create or replace function app.link_internal_supplier(p_booking_item_id uuid, p_provider_branch_id uuid, p_provider_department_id uuid, p_reason text DEFAULT NULL::text)
    RETURNS uuid
    LANGUAGE plpgsql
    SET search_path TO ''
   AS $function$
   declare
       v_tenant uuid := app.current_tenant_id();
       v_item record;
       v_req_branch uuid;
       v_req_dept uuid;
       v_link uuid;
   begin
       if v_tenant is null then
           raise exception 'no active tenant for caller';
       end if;
       perform app.authorize('ASSIGN_SUPPLIER');

       select bi.id, bi.base_status_code, bi.is_archived,
              bi.owner_branch_id, bi.owner_department_id,
              b.branch_id as booking_branch_id, b.department_id as booking_department_id,
              b.booking_status_code, b.is_archived as booking_archived
         into v_item
       from public.booking_items bi
       join public.bookings b on b.id = bi.booking_id and b.tenant_id = v_tenant
       where bi.id = p_booking_item_id and bi.tenant_id = v_tenant;
       if not found then
           raise exception 'booking item is not in your tenant';
       end if;
       if v_item.is_archived or v_item.base_status_code in ('cancelled', 'no_show') then
           raise exception 'cannot link a supplier to a % booking item', v_item.base_status_code;
       end if;
       if v_item.booking_archived or v_item.booking_status_code in ('completed', 'cancelled') then
           raise exception 'cannot link a supplier to an item on a % booking', v_item.booking_status_code;
       end if;

       -- Requester = the item's owning org unit (fallback to the booking's branch/department).
       v_req_branch := coalesce(v_item.owner_branch_id, v_item.booking_branch_id);
       v_req_dept   := coalesce(v_item.owner_department_id, v_item.booking_department_id);

       -- Provider org unit must be a department-within-branch in the caller's tenant.
       if not exists (
           select 1 from public.departments d
           where d.id = p_provider_department_id
             and d.branch_id = p_provider_branch_id
             and d.tenant_id = v_tenant
       ) then
           raise exception 'provider department does not belong to provider branch in your tenant';
       end if;

       -- Append a new fulfilment record (history preserved; latest row = current provider). Its event is
       -- recorded by `internal_supplier_links_emit_linked` on every door; this RPC only hands it the
       -- caller's reason (SPEC-237's `app.transition_reason`).
       perform set_config('app.transition_reason', coalesce(p_reason, ''), true);
       insert into public.internal_supplier_links (
           tenant_id, booking_item_id, provider_branch_id, provider_department_id,
           requester_branch_id, requester_department_id
       )
       values (
           v_tenant, p_booking_item_id, p_provider_branch_id, p_provider_department_id,
           v_req_branch, v_req_dept
       )
       returning id into v_link;

       return v_link;
   end;
   $function$;

   create or replace function app.emit_internal_supplier_linked()
   returns trigger
   language plpgsql
   security definer
   set search_path to ''
   as $fn$
   declare
       v_reason text := nullif(current_setting('app.transition_reason', true), '');
   begin
       perform app.record_event(
           new.tenant_id, 'internal_supplier_linked', 'booking_item', new.booking_item_id,
           app.current_user_id(), null, null, v_reason,
           jsonb_build_object('link_id', new.id,
                              'provider_branch_id', new.provider_branch_id,
                              'provider_department_id', new.provider_department_id,
                              'requester_branch_id', new.requester_branch_id,
                              'requester_department_id', new.requester_department_id),
           'info');
       -- Consumed: a later link in the same transaction carries only its own reason.
       perform set_config('app.transition_reason', '', true);
       return null;
   end;
   $fn$;

   revoke execute on function app.emit_internal_supplier_linked() from public;

   create trigger internal_supplier_links_emit_linked
       after insert on public.internal_supplier_links
       for each row execute function app.emit_internal_supplier_linked();

   create trigger internal_supplier_links_append_only
       before update or delete on public.internal_supplier_links
       for each row execute function app.forbid_mutation();
   ```

   The resulting file's Git blob is 05dba10af68f95fbd3e7ff107998fc7fdea40e02.

3. Check whether `supabase/tests/169_a_conversion_source_event_is_mapped_even_when_it_commits_late_test.sql` contains `plan(10)`; if so record Already Applied when its Git blob is b96649cac86917ef99cfe457abc84e4f76ebf4fb, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 169, 10 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 52 (events, CONV-11) --
   -- a conversion source event is mapped even when it commits after a later one (`20261114160000`).
   -- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR=N/A STATE=N/A INPUT=N/A CONCURRENCY REPLAY PRIVILEGE=N/A BUSINESS OBSERVABILITY=N/A
   --   AUTH, TENANT, DOOR, PRIVILEGE=N/A -- no authority changes: `record_event` keeps its tenant and actor rules
   --     (test 34), and the mapper stays platform-only (tests 36, 66, 119).
   --   STATE, INPUT=N/A -- no column, value or lifecycle changes; the mapper's window and deferral are tests 36, 66, 137-142.
   --   OBSERVABILITY=N/A -- a skipped run records nothing by design: it is retried from the same cursor.
   --   CONCURRENCY -- the defect needs two live sessions, which pgTAP does not have. It is proven by slice 52's
   --     two-session harness with and without the repair (a source seq still open when the mapper ran is mapped by the
   --     next run); here the lock it rests on is pinned: who takes it, in which form, and that the mapper releases it.
   --   REPLAY -- a second run adds nothing (the source seq is the idempotency key, unchanged).
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(10);

   insert into public.tenants (id, name, slug, status) values
     ('16900000-0000-0000-0000-000000000001','Mapper Travel','mapper-travel-169','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '16900000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('16900000-0000-0000-0000-00000000000a','16900000-0000-0000-0000-000000000001','Giza','giza-169');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('16900000-0000-0000-0000-0000000000c1','16900000-0000-0000-0000-000000000001','16900000-0000-0000-0000-00000000000a','sales','Giza Sales');
   -- A Google Ads call lead: its qualification forms a conversion with no click (PH8-4).
   insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title) values
     ('16900000-0000-0000-0000-0000000000e1','16900000-0000-0000-0000-000000000001','16900000-0000-0000-0000-00000000000a','16900000-0000-0000-0000-0000000000c1','google_ads_call','new','Call lead');

   -- The lock, as `pg_locks` names a bigint advisory key.
   create function pg_temp.held(p_mode text) returns int language sql as $$
     select count(*)::int from pg_locks
      where locktype = 'advisory' and pid = pg_backend_pid() and mode = p_mode and objsubid = 1
        and classid::bigint = ((hashtextextended('app.map_outcomes_to_conversions', 0) >> 32) & 4294967295)
        and objid::bigint = (hashtextextended('app.map_outcomes_to_conversions', 0) & 4294967295) $$;

   select is(pg_temp.held('ShareLock'), 0, 'the fixture took no source lock');

   select app.record_event('16900000-0000-0000-0000-000000000001', 'lead_contacted', 'lead',
                           '16900000-0000-0000-0000-0000000000e1');
   select is(pg_temp.held('ShareLock'), 0, 'an event that is no conversion source takes no lock');

   select app.record_event('16900000-0000-0000-0000-000000000001', 'lead_qualified', 'lead',
                           '16900000-0000-0000-0000-0000000000e1');
   select is(pg_temp.held('ShareLock'), 1, 'a conversion source event is recorded under the shared form of the mapper''s lock, held to commit');

   select ok(
     (select prosrc from pg_proc where oid = 'app.record_event(uuid,text,text,uuid,uuid,text,text,text,jsonb,text)'::regprocedure)
       ~ $re$if p_event_type_code in \('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued'\) then\s+perform pg_advisory_xact_lock_shared\(hashtextextended\('app\.map_outcomes_to_conversions', 0\)\);$re$,
     'exactly the four source types the mapper reads take it');

   select ok(
     (select prosrc from pg_proc where oid = 'app.map_outcomes_to_conversions(integer)'::regprocedure)
       ~ $re$if not pg_try_advisory_lock\(hashtextextended\('app\.map_outcomes_to_conversions', 0\)\) then\s+return 0;$re$,
     'the mapper takes the exclusive form without waiting, and maps nothing when a source writer is open');

   select is(
     (select count(*)::int from regexp_matches(
        (select prosrc from pg_proc where oid = 'app.map_outcomes_to_conversions(integer)'::regprocedure),
        'and e\.seq <= v_horizon', 'g')),
     2, 'both reads of the forward window stop at the horizon');

   -- In this one transaction the source writer is the mapper's own session, so the lock is granted.
   select is(app.map_outcomes_to_conversions(100000) >= 1, true, 'the mapper runs');
   select is(
     (select count(*)::int from public.offline_conversions
      where tenant_id = '16900000-0000-0000-0000-000000000001' and lead_id = '16900000-0000-0000-0000-0000000000e1'
        and conversion_event_type_code = 'qualified_phone_call'),
     1, 'the qualification is mapped once');
   select is(pg_temp.held('ExclusiveLock'), 0, 'the mapper released its lock: no source writer waits on it');

   select is(app.map_outcomes_to_conversions(100000), 0, 'REPLAY: a second run adds nothing');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is b96649cac86917ef99cfe457abc84e4f76ebf4fb.

4. Check whether `supabase/tests/170_an_internal_supplier_link_is_appended_and_recorded_on_every_door_test.sql` contains `plan(11)`; if so record Already Applied when its Git blob is d4e2901ff0bffe38168a2d484b2f6e5efc88d4cb, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 170, 11 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 52 (internal_supplier_links, ISL-1 and ISL-2) --
   -- an internal supplier link is appended, never rewritten, and recorded on every door (`20261114170000`).
   -- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR STATE INPUT=N/A CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY
   --   AUTH=N/A -- ASSIGN_SUPPLIER and its step-up are the unchanged capability guard (tests 57, 58).
   --   TENANT=N/A -- tenant isolation is the unchanged policy and composite foreign keys (test 81).
   --   INPUT=N/A -- the department-in-branch and item-state rules are the unchanged integrity guard (test 81).
   --   CONCURRENCY, REPLAY=N/A -- each link is its own row; appending twice is two links, as through the RPC.
   --   BUSINESS=N/A -- a link carries no money.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(11);

   insert into auth.users (id, email) values
     ('17000000-0000-0000-0000-0000000000a1','senior@c170.test');
   insert into public.tenants (id, name, slug, status) values
     ('17000000-0000-0000-0000-000000000001','Link Travel','link-travel-170','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '17000000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-000000000001','Giza','giza-170'),
     ('17000000-0000-0000-0000-00000000000b','17000000-0000-0000-0000-000000000001','Alex','alex-170');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('17000000-0000-0000-0000-0000000000c1','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-00000000000a','sales','Giza Sales'),
     ('17000000-0000-0000-0000-0000000000c2','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-00000000000b','sales','Alex Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('17000000-0000-0000-0000-000000000011','17000000-0000-0000-0000-000000000001','Senior','senior@c170.test',true,'17000000-0000-0000-0000-0000000000a1');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000011','17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '17000000-0000-0000-0000-000000000001', '17000000-0000-0000-0000-000000000011', r.id, 'tenant'
   from public.roles r where r.code = 'senior_employee';
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('17000000-0000-0000-0000-0000000000d1','17000000-0000-0000-0000-000000000001','person','Link Customer');
   insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                                owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
     ('17000000-0000-0000-0000-0000000000f1','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1','17000000-0000-0000-0000-0000000000d1','17000000-0000-0000-0000-000000000011','17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1','draft','Link booking','BK-170-1');
   insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code, currency_code, cost_amount, selling_amount) values
     ('17000000-0000-0000-0000-0000000000f2','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f1','flight_ticket','draft','USD',100,120),
     ('17000000-0000-0000-0000-0000000000f3','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f1','hotel','draft','USD',50,60);

   create function pg_temp.linked(p_link uuid) returns setof public.events language sql as $$
     select * from public.events where event_type_code = 'internal_supplier_linked' and payload ->> 'link_id' = p_link::text $$;

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.internal_supplier_links'::regclass and not tgisinternal
        and tgname in ('internal_supplier_links_emit_linked', 'internal_supplier_links_append_only')),
     2, 'both triggers are installed on internal_supplier_links');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"17000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

   select lives_ok(
     $$insert into public.internal_supplier_links (id, tenant_id, booking_item_id, provider_branch_id, provider_department_id,
                                                   requester_branch_id, requester_department_id)
       values ('17000000-0000-0000-0000-0000000000e1','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f2',
               '17000000-0000-0000-0000-00000000000b','17000000-0000-0000-0000-0000000000c2',
               '17000000-0000-0000-0000-00000000000b','17000000-0000-0000-0000-0000000000c2')$$,
     'a senior employee links an item to Alex at the table door');

   reset role;
   select is(
     (select count(*)::int from pg_temp.linked('17000000-0000-0000-0000-0000000000e1') e join public.users u on u.id = e.actor_user_id
      where u.full_name = 'Senior' and e.entity_type = 'booking_item' and e.entity_id = '17000000-0000-0000-0000-0000000000f2'
        and e.payload ->> 'provider_branch_id' = '17000000-0000-0000-0000-00000000000b'
        and e.payload ->> 'requester_branch_id' = '17000000-0000-0000-0000-00000000000a' and e.reason is null),
     1, 'ISL-1: the door link is recorded once, by its actor, with the derived requester');
   set local role authenticated;

   create temp table rpc_link on commit drop as
   select app.link_internal_supplier('17000000-0000-0000-0000-0000000000f3', '17000000-0000-0000-0000-00000000000b',
                                     '17000000-0000-0000-0000-0000000000c2', 'Alex holds the hotel allotment') as id;
   insert into public.internal_supplier_links (id, tenant_id, booking_item_id, provider_branch_id, provider_department_id,
                                               requester_branch_id, requester_department_id)
   values ('17000000-0000-0000-0000-0000000000e2','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f3',
           '17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1',
           '17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1');

   reset role;
   select is(
     (select count(*) || '/' || count(*) filter (where reason = 'Alex holds the hotel allotment')
      from pg_temp.linked((select id from rpc_link))),
     '1/1', 'the RPC link is recorded once, not twice, with the caller''s reason');
   select is(
     (select count(*)::int from pg_temp.linked('17000000-0000-0000-0000-0000000000e2') where reason is null),
     1, 'the reason is consumed: the next link in the same transaction carries none');
   set local role authenticated;

   select throws_ok(
     $$update public.internal_supplier_links set provider_branch_id = '17000000-0000-0000-0000-00000000000a',
                                                 provider_department_id = '17000000-0000-0000-0000-0000000000c1'
       where id = '17000000-0000-0000-0000-0000000000e1'$$,
     'P0001', 'append-only table: UPDATE is not permitted on internal_supplier_links',
     'ISL-2: a link''s provider cannot be rewritten in place');

   select throws_ok(
     $$update public.internal_supplier_links set booking_item_id = '17000000-0000-0000-0000-0000000000f3', created_at = '2019-01-01'
       where id = '17000000-0000-0000-0000-0000000000e1'$$,
     'P0001', 'append-only table: UPDATE is not permitted on internal_supplier_links',
     '...nor moved to another item or back-dated');

   reset role;
   select set_config('request.jwt.claims', null, true);

   select throws_ok(
     $$update public.internal_supplier_links set provider_branch_id = provider_branch_id where id = '17000000-0000-0000-0000-0000000000e1'$$,
     'P0001', 'append-only table: UPDATE is not permitted on internal_supplier_links',
     'append-only binds every writer, a session-less one too');

   select throws_ok(
     $$delete from public.internal_supplier_links where id = '17000000-0000-0000-0000-0000000000e1'$$,
     'P0001', 'append-only table: DELETE is not permitted on internal_supplier_links',
     '...and no writer deletes a link');

   insert into public.internal_supplier_links (id, tenant_id, booking_item_id, provider_branch_id, provider_department_id,
                                               requester_branch_id, requester_department_id)
   values ('17000000-0000-0000-0000-0000000000e3','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f2',
           '17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1',
           '17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1');
   select is(
     (select count(*)::int from pg_temp.linked('17000000-0000-0000-0000-0000000000e3') where actor_user_id is null),
     1, 'a session-less link is recorded too, with no actor');

   select is(
     (select provider_branch_id from public.internal_supplier_links where id = '17000000-0000-0000-0000-0000000000e1'),
     '17000000-0000-0000-0000-00000000000b'::uuid, 'the first link still names Alex: a new provider is a new row');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is d4e2901ff0bffe38168a2d484b2f6e5efc88d4cb.

5. Check whether `_ORVION_CANONICAL/27_event_catalog.md` contains `Created by every internal supplier link`; if so record Already Applied when its Git blob is 74bdd64ed44adcef823378dc3f194c7ad6b46610, and otherwise stop and report. Otherwise make exactly this one edit (the internal_supplier_linked entry: what it records), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   ## internal_supplier_linked

   Severity: info

   ```
   insert
   ```text
   Created by every internal supplier link, through `app.link_internal_supplier` or the table door, with the actor, the link id and the provider and requester org units, and the reason the RPC was given (ISL-1, SPEC-308). A link is never changed or deleted: a new provider is a new link (ISL-2).

   ```

   The resulting file's Git blob is 74bdd64ed44adcef823378dc3f194c7ad6b46610.

6. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| CONV-11 |`; if so record Already Applied when its Git blob is b9af14bc5f144cbd60bf62185cfc4f819336bcd4, and otherwise stop and report. Otherwise make exactly these 2 edits (the Slice 52 freshness entry and three new rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-14 (**Slice 51 — `exchange_rates`, `user_permission_grants` and `catalog_values` selected live at Exposure 6, coverage 66, 88 and 102, in one contract (the owner's grouping, 2026-11-14).** **FX-5**, **FX-6**, **RBAC-7** and **CAT-7** (High) and **CAT-8** and **CAT-9** (Medium) are new and fixed, and the last half of **USR-3** is fixed. Rates, permission grants and tenant catalog values were written from password-only sessions; a rate that recorded money cites was rewritten in place; a live grant moved from one user to another unrecorded; a tenant extended platform-owned catalog families and renamed a value under the rows that use it. SPEC-307 charges step-up at all three doors, keeps a cited rate and a used value fixed, and records every rate set and every grant move. STEPUP-1 gains a note. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-14 (**Slice 52 — `events`, `scheduled_job_findings` and `internal_supplier_links` selected live at Exposure 6 and 5, coverage 400, 18 and 18, in one contract (P1's grouping, 2026-11-14).** **CONV-11** (Medium) and **ISL-1** and **ISL-2** (Low) are new and fixed. A conversion source event that committed after a later one was never mapped, because the mapper's seq cursor had already passed it; an internal supplier link made at the table door was not recorded, and a link's provider, item and date were rewritten in place unrecorded. SPEC-308 keeps the mapper behind every open source writer, records every link on every door, and makes the links append-only. `scheduled_job_findings` was audited with no finding. No other row changed.)

   Previously: 2026-11-14 (**Slice 51 — `exchange_rates`, `user_permission_grants` and `catalog_values` selected live at Exposure 6, coverage 66, 88 and 102, in one contract (the owner's grouping, 2026-11-14).** **FX-5**, **FX-6**, **RBAC-7** and **CAT-7** (High) and **CAT-8** and **CAT-9** (Medium) are new and fixed, and the last half of **USR-3** is fixed. Rates, permission grants and tenant catalog values were written from password-only sessions; a rate that recorded money cites was rewritten in place; a live grant moved from one user to another unrecorded; a tenant extended platform-owned catalog families and renamed a value under the rows that use it. SPEC-307 charges step-up at all three doors, keeps a cited rate and a used value fixed, and records every rate set and every grant move. STEPUP-1 gains a note. No other row changed.)
   ```

   b) immediately after the line
   ```text
   | CAT-9 | **An owner or ceo wrote tenant catalog values from a password-only (`aal1`) session** | security · authorization | Medium | R | 6 | M | ✅ | **✅ FIXED 2026-11-14 (SPEC-307, `20261114140000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-307; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `b44cad9`: the write policy charges `MANAGE_TENANT_SETTINGS` through `app.has_permission`, never the step-up; an `aal1` `owner` added a supplier type. The table is a named member of STEPUP-1; this reproduces it, with CAT-7 and CAT-8 as the consequences a password alone reached. **Repaired:** `app.guard_catalog_value_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role), on every session write: `app.authorize('MANAGE_TENANT_SETTINGS')`, permission and step-up; a value only in one of the four families whose `catalog_types.ownership_type` is `tenant_extendable_system`; never `is_system`; and an UPDATE keeps the value's tenant, family and code (a replaced value is added anew and the old one deactivated, which `app.enforce_catalog_codes` already allows). Label, order and activation stay editable. A session-less platform write is exempt. `168_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code_test.sql` pins it. | — | SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record | 11-14 | 11-14 |
   ```
   insert
   ```text
   | CONV-11 | **A conversion source event that committed after a later one was never mapped: the mapper's seq cursor had already passed it** | offline conversion · integrity | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-308, `20261114160000`); Primary deployment pending.** **MEASURED** at `ca2c189` with two live sessions: two Google Ads call leads were qualified, taking seqs 129 and 130; the session holding 130 committed first, and `app.map_outcomes_to_conversions` ran while 129 was still open. It mapped 130 and advanced `outcome_conversion_mapper` to 130; when 129 committed, the next run mapped nothing, and that lead's `qualified_phone_call` was never formed. `events.seq` is an identity, assigned at insert and visible at commit, so a cursor that passes a seq not yet visible skips it for ever; CONV-1's deferral covers a lapsed tenant, not a late commit. Latent: Primary holds no event and no conversion. **Repaired:** `app.record_event` takes the shared form of a transaction-level advisory lock keyed on the mapper for the four source types the mapper reads (`lead_qualified`, `booking_created`, `payment_recorded`, `booking_issued`) before the event takes its seq, and holds it to commit. `app.map_outcomes_to_conversions` first tries the exclusive form without waiting: while any source writer is open it maps nothing and returns 0, and the next run retries from the same cursor; otherwise it reads `max(seq)` as its horizon, releases the lock at once, and reads its forward window only up to that horizon, so no source seq at or below it can still commit. No writer waits on the mapper and the mapper waits on no writer. The cursor, the idempotency key, the CONV-1 deferral and every other rule are unchanged. `169_a_conversion_source_event_is_mapped_even_when_it_commits_late_test.sql` pins the lock and the horizon; the race itself is proven by the slice's two-session harness, before and after. | — | SPEC-308-a-late-conversion-source-is-mapped-and-a-supplier-link-is-kept-and-recorded | 11-14 | 11-14 |
   | ISL-1 | **An internal supplier link made at the table door was not recorded, though the same link through its RPC was** | audit completeness | Low | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-308, `20261114170000`); Primary deployment pending.** **MEASURED** at `ca2c189`: a `senior_employee` holding ASSIGN_SUPPLIER linked a booking item at the table door and the tenant's events did not move, while the same link through `app.link_internal_supplier` recorded `internal_supplier_linked`. SUP-1 (`202607058600`) brought the RPC's rules to the door; its record was left behind. Severity is Low by SUP-1's measured reason, re-measured at `ca2c189`: nothing reads the table but its RPC and `app.guard_write_capability`. **Repaired:** `app.emit_internal_supplier_linked` (AFTER INSERT, SECURITY DEFINER, empty `search_path`, executable by no client role) records every link, through the RPC or the table door, as `internal_supplier_linked` with the actor, the link id and both org units; `app.link_internal_supplier` no longer records its own and hands its reason over through `app.transition_reason` (SPEC-237's pattern), which the emitter consumes, so the RPC records once. `internal_supplier_links_append_only` (BEFORE UPDATE OR DELETE, `app.forbid_mutation`) makes the table append-only for every writer: a new provider is a new link. `170_an_internal_supplier_link_is_appended_and_recorded_on_every_door_test.sql` pins both. | — | SPEC-308-a-late-conversion-source-is-mapped-and-a-supplier-link-is-kept-and-recorded | 11-14 | 11-14 |
   | ISL-2 | **A link's provider, booking item and date were rewritten in place, and nothing was recorded** | integrity · audit completeness | Low | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-308, `20261114170000`); Primary deployment pending.** **MEASURED** at `ca2c189`: the same senior re-pointed a link's provider from one branch to another, moved the link to another booking item, and back-dated it to 2019, each by UPDATE, and nothing was recorded. `app.link_internal_supplier` describes the table as append-only (history preserved; the latest row is the current provider) and SUP-1 calls it an append-only log, but nothing enforced it: the table carries an UPDATE grant and no guard of its own. Severity is Low by SUP-1's measured reason, re-measured at `ca2c189`: nothing reads the table but its RPC and `app.guard_write_capability`. **Repaired:** `app.emit_internal_supplier_linked` (AFTER INSERT, SECURITY DEFINER, empty `search_path`, executable by no client role) records every link, through the RPC or the table door, as `internal_supplier_linked` with the actor, the link id and both org units; `app.link_internal_supplier` no longer records its own and hands its reason over through `app.transition_reason` (SPEC-237's pattern), which the emitter consumes, so the RPC records once. `internal_supplier_links_append_only` (BEFORE UPDATE OR DELETE, `app.forbid_mutation`) makes the table append-only for every writer: a new provider is a new link. `170_an_internal_supplier_link_is_appended_and_recorded_on_every_door_test.sql` pins both. | — | SPEC-308-a-late-conversion-source-is-mapped-and-a-supplier-link-is-kept-and-recorded | 11-14 | 11-14 |
   ```

   The resulting file's Git blob is b9af14bc5f144cbd60bf62185cfc4f819336bcd4.

7. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**57 of 78 recorded · 33 `; if so record Already Applied when its Git blob is 64b470b49e50d6509db3188923a986ecb5d19a48, and otherwise stop and report. Otherwise make exactly these 6 edits (the freshness entry, coverage 57 of 78 and the three surface rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-14 (**slice 51 — `exchange_rates`, `user_permission_grants` and `catalog_values` selected by Exposure 6, coverage 66, 88 and 102, in one contract.** Coverage **51 → 54 of 78**. FX-5 and FX-6: a rate that recorded money cites was rewritten in place, and rates were set from password-only sessions. USR-3 and RBAC-7: grants were written from password-only sessions, and a live grant moved between users unrecorded. CAT-7, CAT-8 and CAT-9: a tenant extended platform-owned families, renamed a value in use, and wrote values from password-only sessions. SPEC-307 closes all of them here, so the three rows are `AUDITED`.)
   ```
   with
   ```text
   Last updated: 2026-11-14 (**slice 52 — `events`, `scheduled_job_findings` and `internal_supplier_links` selected by Exposure 6 and 5, coverage 400, 18 and 18, in one contract.** Coverage **54 → 57 of 78**. CONV-11: a conversion source event that committed late was never mapped. ISL-1 and ISL-2: a link made at the table door was not recorded, and a link was rewritten in place unrecorded. SPEC-308 closes all of them here; `scheduled_job_findings` holds with no finding, so the three rows are `AUDITED`.)

   Previously: 2026-11-14 (**slice 51 — `exchange_rates`, `user_permission_grants` and `catalog_values` selected by Exposure 6, coverage 66, 88 and 102, in one contract.** Coverage **51 → 54 of 78**. FX-5 and FX-6: a rate that recorded money cites was rewritten in place, and rates were set from password-only sessions. USR-3 and RBAC-7: grants were written from password-only sessions, and a live grant moved between users unrecorded. CAT-7, CAT-8 and CAT-9: a tenant extended platform-owned families, renamed a value in use, and wrote values from password-only sessions. SPEC-307 closes all of them here, so the three rows are `AUDITED`.)
   ```

   b) replace the line
   ```text
   **54 of 78 recorded · 30 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 24 `NOT-RECORDED`.**
   ```
   with
   ```text
   **57 of 78 recorded · 33 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 21 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 54 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 57 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `events` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `events` | **AUDITED** | ADVERSARIAL | `SPEC-308-a-late-conversion-source-is-mapped-and-a-supplier-link-is-kept-and-recorded` | CONV-11 | `169_a_conversion_source_event_is_mapped_even_when_it_commits_late_test.sql` (10 assertions; CONCURRENCY, REPLAY and BUSINESS declared, the rest N/A) pins that the four conversion source types, and no other event, take the shared form of the mapper's lock and hold it to commit; that the mapper tries the exclusive form without waiting, releases it, and reads both forward windows only up to its horizon; and that a qualification is mapped once and a second run adds nothing. The race itself needs two live sessions and is proven by the slice's harness: before the repair the qualification that committed late was never mapped; after it, the run that met the open writer mapped nothing and the next run mapped both. Tests 34, 36, 66, 119, 137 and 139-142 pass unchanged. **Swept and classified as non-defects:** no client role may insert, update or delete an event (no grants; `app.forbid_mutation` binds the table owner too); `app.record_event` refuses another tenant and is not served over REST (404, API-1); another branch's and another tenant's events are not read (AUDIT-6). **Recorded positions:** a signed-in session may call `app.record_event` for its own tenant over a direct database connection, never through the API (API-1's position); a mapper run that meets an open source writer maps nothing, and the next scheduled run retries from the same cursor. 0 hosted events. |
   ```

   e) replace the line
   ```text
   | `internal_supplier_links` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `internal_supplier_links` | **AUDITED** | ADVERSARIAL | `SPEC-308-a-late-conversion-source-is-mapped-and-a-supplier-link-is-kept-and-recorded` | ISL-1, ISL-2 | `170_an_internal_supplier_link_is_appended_and_recorded_on_every_door_test.sql` (11 assertions; DOOR, STATE, PRIVILEGE and OBSERVABILITY declared, the rest N/A) proves that a link made at the table door is recorded once, by its actor, with the requester the door derives; that a link made through the RPC is recorded once, not twice, with the caller's reason, and the reason does not carry over to the next link; that no writer, a session-less one included, rewrites a link's provider, item or date, or deletes it; and that a session-less link is recorded with no actor. Tests 53, 57, 58 and 81 pass unchanged. **Swept and classified as non-defects:** an employee without ASSIGN_SUPPLIER and an `owner` at `aal1` are refused (`app.guard_write_capability`); no DELETE grant; another tenant reads no link. **Recorded positions:** `created_at` is caller-supplied on INSERT and read by nothing that decides (SPEC-216's schema-wide question); links are readable tenant-wide, ids and org units only. 0 hosted links. |
   ```

   f) replace the line
   ```text
   | `scheduled_job_findings` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `scheduled_job_findings` | **AUDITED** | ADVERSARIAL | `SPEC-308-a-late-conversion-source-is-mapped-and-a-supplier-link-is-kept-and-recorded` | — | `66_scheduled_job_isolation_test.sql` proves that a tenant user is not even granted the table (42501), and `119_conversion_provenance_is_platform_written_test.sql` (its classes declared) that the mapper's deferral is written as a finding and closed as mapped on the platform path; both pass unchanged beside CONV-11's repair, which leaves the deferral path as it was. **Swept and classified as non-defects** (an `owner` at `aal2`): no read, insert or update grant to any client role; `app.record_job_finding` and `app.resolve_job_finding` are executable by no client role. Platform-only, record-only rows; nothing changed, so no test was added. 0 hosted findings. |
   ```

   The resulting file's Git blob is 64b470b49e50d6509db3188923a986ecb5d19a48.

8. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–7 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the two migrations and tests 169 and 170, which must equal Consumer Closure;
   - on the local stack holding the migrations: the four functions' `md5(prosrc)`, security mode and ACL, the triggers of `events` and `internal_supplier_links`, and the catalog count; tests 169 and 170 alone; the probes and the two-session harness; the nine mutants, with the restored shape proven equal;
   - the causal negatives: the stack before the migrations, then the stack restored with them;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migrations;
   - the API-contract generator, whose output must equal `MASTER_API_CONTRACT.md`; the map generator, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary and the measured-state items of Consumer Closure.

   Then read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of both target migrations;
   - the function and structural surfaces;
   - the triggers of the two tables and the four functions' `md5(prosrc)`;
   - the tenant, event, offline conversion, finding and link counts.

   Record the predicted delta. If any reading differs, stop.
9. **Check** that an exact-SHA Gate-2 record for the two migrations is in the Execution Log. It is either the owner's own, or one marked DELEGATED that names this contract, each migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If it is absent, write it only when Step 8 passed and those instructions cover migrations that drop no table or column and delete or rewrite no business row. Otherwise stop after Step 8 and present the Gate-2 package.
10. **Check** which of `20261114160000_a_conversion_source_event_is_mapped_even_when_it_commits_late` and `20261114170000_an_internal_supplier_link_is_appended_and_recorded_on_every_door` Primary `vrvtsxexkiiiivlkdxzp` lacks. If Step 9 is recorded, deploy each one it lacks in version order, in one sitting:
    - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, the target's absence, the business counts and the triggers of the two tables.
    - On an exact match, prove the transmitted text's md5 server-side, then apply only that migration through the Primary connector.
    - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row other than this contract's own versions, its stored statement md5 equal to the file's, and no existing target version.
    - If a stop falls between the two, record the half-deployed ledger in the Execution Log before anything else.

    Then read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of the two tables; the four functions' `md5(prosrc)`, security mode and ACL; and the business counts. Never contact Secondary `brplkqmbzffpxqgkkdzo`.
11. **Check** that fresh Primary evidence contains each of the two new migrations exactly once. If so:
    - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
    - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the client RPC figure unchanged.
    - Confirm that `supabase/tests` holds 170 files whose literal `plan(N)` values sum to 3172, then set `Suite **170 files / 3172 assertions**`. If either differs, stop.
    - In the register, replace each `` | 🛡 | **FIXED 2026-11-14 locally (SPEC-308, `V`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-14 (SPEC-308, `V`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-308; the fresh Primary ledger, functions and structure equal local.** ``, for V `20261114160000` (the one row CONV-11) and `20261114170000` (the two rows ISL-1 and ISL-2). Each span's one leading and one trailing space are delimiters, not text. Change nothing else in the register.
    - Confirm that the canonical API-contract generator still reproduces `MASTER_API_CONTRACT.md` unchanged, and regenerate `ai-map.json` and `repository-index.md` (stored LF) with the canonical generator.
    - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once. The pre-commit Gate must admit it.

    If Primary is unproven, stop.
12. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
    - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
    - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, make the Complete commit:
      - transition to Complete and tick the Acceptance Criteria and the Review Gate;
      - clear `Active Change Request` and set `Last Completed` from Notes;
      - leave `Next capability` and `Current Module` unchanged;
      - regenerate `ai-map.json` and `repository-index.md` LF.
    - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] The events migration is the frozen bytes; `check: blob supabase/migrations/20261114160000_a_conversion_source_event_is_mapped_even_when_it_commits_late.sql 03bb907860a50895db5135d8d92778d397c5a8a6`
- [ ] The link migration is the frozen bytes; `check: blob supabase/migrations/20261114170000_an_internal_supplier_link_is_appended_and_recorded_on_every_door.sql 05dba10af68f95fbd3e7ff107998fc7fdea40e02`
- [ ] Test 169 is the frozen bytes; `check: blob supabase/tests/169_a_conversion_source_event_is_mapped_even_when_it_commits_late_test.sql b96649cac86917ef99cfe457abc84e4f76ebf4fb`
- [ ] Test 170 is the frozen bytes; `check: blob supabase/tests/170_an_internal_supplier_link_is_appended_and_recorded_on_every_door_test.sql d4e2901ff0bffe38168a2d484b2f6e5efc88d4cb`
- [ ] Canon 27 says what `internal_supplier_linked` records; `check: has _ORVION_CANONICAL/27_event_catalog.md "Created by every internal supplier link"`
- [ ] The disposition record carries the three surfaces AUDITED / ADVERSARIAL and coverage 57 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 64b470b49e50d6509db3188923a986ecb5d19a48`
- [ ] The three register rows are fixed and deployed; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-308"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **170 files / 3172 assertions**"`
- [ ] The API contract is unchanged; `check: same reports/master/MASTER_API_CONTRACT.md @ca2c189569984c6532af62ad2f9c5ec61ede0944`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @ca2c189569984c6532af62ad2f9c5ec61ede0944`
- [ ] The event write path's table remains exact; `check: same supabase/migrations/202607042600_create_event_and_notification_tables.sql @ca2c189569984c6532af62ad2f9c5ec61ede0944`
- [ ] The smoke catalog count remains exact; `check: same scripts/verify_database.sql @ca2c189569984c6532af62ad2f9c5ec61ede0944`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the two authorized migrations, with at most one guarded ledger rename for each and no business-data write, after a recorded Step 8 readiness gate and Step 9 Gate-2 record. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] The nine mutants are each killed with installation proven and the restored shape read, and the two causal negatives and the two-session harness, before and after, are recorded.

## Execution Log

### 2026-11-14 — Steps 1–7 applied

- **Lifecycle:** allocate `49c8138`, Approve `ef05f89` (APPROVAL_EVIDENCE PASS; 12 of 14 criteria Gate-checked), DELEGATED Gate 1 recorded in Verification Notes.
- **Steps 1–7** by the literal-step replay, each result at its pinned blob: migrations `03bb907860a50895db5135d8d92778d397c5a8a6` and `05dba10af68f95fbd3e7ff107998fc7fdea40e02`; tests 169 `b96649cac86917ef99cfe457abc84e4f76ebf4fb` and 170 `d4e2901ff0bffe38168a2d484b2f6e5efc88d4cb`; canon 27 `74bdd64ed44adcef823378dc3f194c7ad6b46610`; register `b9af14bc5f144cbd60bf62185cfc4f819336bcd4`; disposition `64b470b49e50d6509db3188923a986ecb5d19a48`; 0 mismatches. Uncommitted until Step 11: the pre-commit guard refuses the measured-state items before the deploy.

### 2026-11-14 — Pre-deploy readiness gate (Step 8)

From the main checkout at HEAD `ef05f89`, Steps 1–7 applied and uncommitted, project-local CLI 3.0.0, the local stack recreated by the rig, one logged script (17:19–17:21 Cairo):
- **Bytes**, all LF (0 CR) and ASCII, equal to Consumer Closure. Migration `20261114160000` SHA-256 `38f8419e49b8a4a899ac94dac8ec21460a2dab0d29796cb11f8e4f4aec962eb9`, md5 `bad439fd0afb9c2b281ee56ac7e66c3c`, 15551 bytes; `20261114170000` SHA-256 `df7d6433c9c1bd4c6485bf73b627e761c38f931d768fa4a20297bc294065a057`, md5 `e7ab821346241cb45d4e72f7a8ba2f70`, 6149 bytes. Test 169 SHA-256 `3dd91b7482963b2aa66a778e3ec53cfc11ff466e4ba8bea5590eec903e35c269`, md5 `4a80dd090ae21009c4c848f28fb45b98`, 5201 bytes; 170 `cf099ff047d5503cccfb28d4114ef104fd7deaccaff4c349038b49a0694306eb`, md5 `ef873e0bd2ff4b034e1836f8111f65f6`, 9446 bytes.
- **Causal negative.** `db reset --version 20261114140000`: 263 migrations, ledger `5df6fd8c73bbe79255e09e30bdc78378`; `md5(prosrc)` of `app.link_internal_supplier` `7cfbd5ce3b0f035b428f654d14dd5f4f`, the mapper `2b3dce415e5968e633e5e856cd30f953`, `app.record_event` `2ee83b1756511b1e69481487960496b8` (this checkout stores `202607053000` with LF; the prototype's CRLF copy gives `2aca012e796cea969ca542028ed34c49`; the whitespace-normalized function surface is equal); no emitter; 4 triggers on the two tables; catalog 71/626. Test 169 FAIL [3–6], 170 FAIL [1, 3, 5–11]. The two-session harness: the session holding seq 29 committed first, the mapper ran while seq 28 was open, mapped 1 and moved the cursor to 29; after 28 committed the next run mapped 0, so lead 1 was never mapped. Probes: a senior's door link recorded nothing; a link's provider, item and date rewritten by UPDATE, unrecorded. CONV-11, ISL-1 and ISL-2 reproduced.
- **Fingerprints** (`scripts/parity_surface.sql`). Before (263): functions `0b3b9c82bb521f6744950201471196a6`/346, triggers `d241997ceaab37c02327503b4e2587cb`/332, `_combined` `f87d6fee4ce1857bc3f35672c7ef8a4e`/3169. After a clean reset (265, latest `20261114170000`, ledger `2a17e52e8270cf7bb2e546dbb0c9f591`): functions `58dc8cf1aaec56b1ba63eabf7391ac0a`/347, triggers `b4a4d2babd4fa85cf46268d2b934268a`/334, `_combined` `aeb5931b5df96106439433dce07cfe2a`/3172; the other eight surfaces unchanged.
- **Shape.** `md5(prosrc)`: `app.record_event` `63c530c75036e3b50c21ca7e2222415a` and the mapper `103290e8791a537d15c0192b27469861`, each SECURITY DEFINER with its ACL unchanged; `app.link_internal_supplier` `53a7eecb49d9d43e04d59939d7a3b533`, SECURITY INVOKER, ACL unchanged; `app.emit_internal_supplier_linked` `2ab772b33b2e17c270f0b7c16d936b40`, SECURITY DEFINER, `{postgres=X/postgres}`. Triggers added: `internal_supplier_links_emit_linked` and `internal_supplier_links_append_only` (`events` 1, `internal_supplier_links` 5); catalog 71/626.
- **Focused tests:** 169 10/10 and 170 11/11, PASS. On the final bytes the harness's run that met the open writer mapped 0 with the cursor unchanged, and the next run mapped both leads; the door link and the RPC link are each recorded once; every UPDATE of a link is refused; the held behaviors hold.
- **Mutants**, each proven installed and restored: 169 M1 fails 3, 4; M2 4; M3 5; M4 6; M5 9; CN 3–6. 170 M1 fails 1, 3, 4, 5, 10; M2 1, 6–9, 11; M3 5; M4 4; CN 1, 3, 5–11. Nine mutants and two causal negatives, all killed; the restored shapes equal.
- **Generators, scope and diff.** The API-contract generator's output equals `MASTER_API_CONTRACT.md` byte for byte; `generate-ai-map.ps1 -Check` exit 0. Only the seven Step 1–7 paths changed; `git diff --check` clean.
- **Consistency:** exactly the six expected pre-deploy items, the same as the sandbox: 263 vs 265 migrations, latest, ledger fingerprint, 168 vs 170 files, 3151 vs 3172 assertions, RECOVER-1 (Primary evidence).
- **Fresh Primary baseline**, read-only (15:21:51 UTC by the server clock, through the Primary write connector inside `BEGIN TRANSACTION READ ONLY`): URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 263 `5df6fd8c73bbe79255e09e30bdc78378`, latest `20261114140000`, both targets absent by version and by name; `app.link_internal_supplier` `7cfbd5ce3b0f035b428f654d14dd5f4f`, the mapper `67890da2083509aa6296badb53eb32ba`, `app.record_event` `772056474af88054a207c3ff02b0ed9a` (the stored text's line endings differ from both local copies; the whitespace-normalized function surface is equal), each with its local security mode and ACL; no emitter; the 4 triggers of the two tables equal to the local stack at 263; `internal_supplier_linked` at 68; catalog 71/626; 0 tenants, 0 events, 0 offline conversions, 0 findings, 0 links; mapper cursor 0. `parity_surface.sql`: every surface equal to the local stack at 263, `_combined` `f87d6fee4ce1857bc3f35672c7ef8a4e`/3169, equal to the recorded evidence.
- **Predicted delta:** ledger 265 `2a17e52e…`; functions `58dc8cf1…`/347; triggers `b4a4d2ba…`/334; `_combined` `aeb5931b…`/3172; the four function hashes of Shape (the deployed text is the LF files); the two new triggers; catalog 71/626 unchanged; business counts unchanged.

### 2026-11-14 — Gate 2 (Step 9), DELEGATED

DELEGATED exact-SHA Gate-2 record for SPEC-308, to Primary `vrvtsxexkiiiivlkdxzp` only, in version order and in one sitting: `supabase/migrations/20261114160000_a_conversion_source_event_is_mapped_even_when_it_commits_late.sql`, SHA-256 `38f8419e49b8a4a899ac94dac8ec21460a2dab0d29796cb11f8e4f4aec962eb9`, md5 `bad439fd0afb9c2b281ee56ac7e66c3c`, 15551 bytes; `supabase/migrations/20261114170000_an_internal_supplier_link_is_appended_and_recorded_on_every_door.sql`, SHA-256 `df7d6433c9c1bd4c6485bf73b627e761c38f931d768fa4a20297bc294065a057`, md5 `e7ab821346241cb45d4e72f7a8ba2f70`, 6149 bytes; under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo), 2026-11-11 (Batch 6 decisions 1-9 ~19:50 Cairo), 2026-11-12 (priority order waiving no gate ~12:20 Cairo) and 2026-11-14 (one contract per product ~11:30 Cairo; no credential rotation ~12:30 Cairo; slice 10 in run mode 2 and BP-32's one-sitting deploy ~16:20 Cairo), recorded outside this repository. Step 8 passed. The migrations' top-level statements are four `create or replace function`, one `revoke execute` and two `create trigger`: they drop no table or column and delete or rewrite no business row. Not a human-typed digest. Secondary `brplkqmbzffpxqgkkdzo` is not a target.

### 2026-11-14 — Primary deployment (Step 10)

Through the Primary write connector from this VS Code session, 15:24–15:26 UTC by the server clock, in version order and in one sitting; Secondary `brplkqmbzffpxqgkkdzo` not contacted:
- **Immediate re-read before each, exact match** (inside `BEGIN TRANSACTION READ ONLY`). HEAD `ef05f890d07aed47fbaab1667890bbcd2a3850ea`; the two files' SHA-256 as in Step 8; URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`. Before `20261114160000` (15:24:14 UTC): ledger 263 `5df6fd8c73bbe79255e09e30bdc78378`, both targets absent by version and by name, functions and triggers as in Step 8. Before `20261114170000` (15:25:33 UTC): ledger 264 `f6f71e89ec027b0a23dd33b5b339ac1d`, equal to the migration files through `20261114160000`, its two functions at their Step 8 hashes. Each time 0 tenants, 0 events, 0 offline conversions, 0 findings, 0 links, 626 catalog values.
- **Transmitted text** proven server-side in the same read, each equal to its file: md5 `bad439fd0afb9c2b281ee56ac7e66c3c` and `e7ab821346241cb45d4e72f7a8ba2f70`. Each applied once with `apply_migration` under its own name.
- **Guarded renames.** The connector stored versions `20261114152451` and `20261114152558`: each time exactly one new row other than this contract's own versions, one stored statement with the file's md5 and byte count (15551, 6149), no existing target. One guarded `UPDATE` each (row count required 1) renamed them to `20261114160000` and `20261114170000`. The half-deployed window (15:24–15:26 UTC) closed inside the sitting.
- **Fresh reads** (15:26:15 UTC). Ledger 265 `2a17e52e8270cf7bb2e546dbb0c9f591`, latest `20261114170000`, equal to the migration files; `parity_surface.sql`: functions `58dc8cf1aaec56b1ba63eabf7391ac0a`/347, triggers `b4a4d2babd4fa85cf46268d2b934268a`/334, the other eight surfaces unchanged, `_combined` `aeb5931b5df96106439433dce07cfe2a`/3172, each equal to the local stack after a clean reset; the four functions' `md5(prosrc)` equal to Step 8 (`63c530c7…`, `103290e8…`, `53a7eecb…`, `2ab772b3…`), with their security modes and ACLs as local; the six triggers of the two tables equal to local, with `internal_supplier_links_emit_linked` and `internal_supplier_links_append_only` added; `internal_supplier_linked` at 68; catalog 71/626; 0 tenants, 0 events, 0 offline conversions, 0 findings, 0 links; mapper cursor 0. No business row was written.

### 2026-11-14 — Post-deploy records (Step 11)

- `reports/evidence/primary-ledger-evidence.json` from the Step 10 readings only (read 2026-11-14T15:26:15Z): 265 entries whose fingerprint recomputes to `2a17e52e…`, functions `58dc8cf1…`/347, structure `aeb5931b…`/3172.
- Manifest `Live state` set from the same readings; the client RPC figure unchanged. `supabase/tests` holds 170 files whose literal `plan(N)` sum to 3172; `Suite **170 files / 3172 assertions**`.
- The three register rows (CONV-11, ISL-1, ISL-2) replaced with the DEPLOYED text, 1 + 2 spans, nothing else changed.
- The canonical API-contract generator reproduces `MASTER_API_CONTRACT.md` byte for byte (unchanged); `ai-map.json` and `repository-index.md` regenerate byte-identical, LF.
- Runtime Checkpoint DONE; Status Approved → In Progress; one implementation commit.
## Verification Notes

None.


### 2026-11-14 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo), 2026-11-11 (Batch 6 decisions 1-9 ~19:50 Cairo), 2026-11-12 (priority order waiving no gate ~12:20 Cairo) and 2026-11-14 (one contract per product ~11:30 Cairo; no credential rotation ~12:30 Cairo; slice 10 in run mode 2 with its own grouping decision ~16:20 Cairo); Draft SHA-256 06D601712A9955B4ED170F5F3DDAB97495F254E854680EC314AE326192DEEA52, decision SHA-256 10D6D87B4C3B94915BE08EAC5D37DC9EA5FD3C2BABCDA7DCA9B933EDCC425C09. No fabricated human future-digest approval. Gate 2 (Primary deploy) is a separate exact-SHA record in Step 9. Immediately before allocation the hash, the Draft blob 426af85f9c9cfdbb4634ed325308da0f78f4de48, all 3 source anchors, the baseline HEAD ca2c189569984c6532af62ad2f9c5ec61ede0944 against refreshed origin/main ca2c189569984c6532af62ad2f9c5ec61ede0944 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 49c8138. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-308: Batch 6 Slice 52 — a conversion source event that commits late is still mapped; every internal supplier link is recorded on every door and never rewritten (CONV-11, ISL-1, ISL-2), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline ca2c189569984c6532af62ad2f9c5ec61ede0944 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `_ORVION_CANONICAL/27_event_catalog.md` | `0a78f239febc8960c704a30f44a55517123ec57f` |
| `reports/master/MASTER_GAP_REGISTER.md` | `81a45eaa3e3ad4a31d0af8c7bac5c3d898e1beb7` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `415a82bc414669369fd7647ca163c5df0cb467f4` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md and ENGINEERING_METHOD.md; SPEC-215, SPEC-237 and SPEC-307 at ca2c189569984c6532af62ad2f9c5ec61ede0944; the owner's instructions of 2026-11-08 and 2026-11-14 (recorded outside this repository). This is the one Draft for these surfaces, finalized after the adversarial review and the evidence refresh that its Draft Assurance records. Correctness remains native and independent.
