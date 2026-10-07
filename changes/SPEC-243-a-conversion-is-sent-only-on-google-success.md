# Change Request — SPEC-243

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Close PH8-9: a Google Data Manager ingestion acknowledgement is not a successful ORVION delivery. ORVION keeps the provider's request identity on the delivery, keeps the delivery out of every re-claim and lease sweep while Google processes it, and marks it `sent` only on Google's terminal SUCCESS for that request. Record the owner's 2026-10-07 execution order in the authorities that own it, so that after this contract the next capability is Foundation Completion Programme Batch 6 Slice 31.

This is the fifth contract of the Phase-8 Activation Closure and closes `MASTER_INTEGRATION_CATALOG.md` §2b item 3. It builds no n8n workflow, repairs no Batch-6 finding and does not touch PH8-10.

## Business Reason

- **The defect, measured on the pre-repair schema at `67007fb`** (local stack, rolled back). A consented `qualified_lead` conversion was claimed. `app.record_conversion_delivery_result(id, true, '{"requestId":"REQ-CN"}', null)`, the only acknowledgement, made the delivery `sent` and recorded one `offline_conversion_sent`. The only delivery RPCs were the claim and that acknowledgement. A later Google FAILED, recorded through the same function, was refused (`delivery … is sent — only pending deliveries can be resolved`). With the delivery aged 48 hours, the claim re-claimed nothing. A conversion Google rejects after ingestion is therefore lost as permanently as correction 1's `validateOnly` case. Exposure: Primary holds 0 conversions and 0 deliveries, and no workflow exists, so the defect is latent until the first delivery.
- **Google, re-read 2026-10-07 (first-party only).**
  - `POST https://datamanager.googleapis.com/v1/events:ingest` returns `requestId` and `fieldWarnings[]` (`reason`, `description`, `field` in the `FieldViolation` path format); `validateOnly` validates without executing. Scope `https://www.googleapis.com/auth/datamanager` (reference pages updated 2026-09-10 and 2026-07-28).
  - `GET https://datamanager.googleapis.com/v1/requestStatus:retrieve?requestId=…` returns `requestStatusPerDestination[]`, each with `requestStatus`: `REQUEST_STATUS_UNKNOWN` ("unknown"), `PROCESSING`, `SUCCESS` ("processing succeeded for all records without errors; warnings may exist"), `PARTIAL_SUCCESS` ("some records succeeded, others failed"), `FAILED` ("processing failed for all records"), with `errorInfo.errorCounts[]` and `warningInfo.warningCounts[]` aggregated by reason (updated 2026-09-10).
  - Diagnostics guide (updated 2026-10-07): wait 30 minutes, then poll; processing takes up to 24 hours; back-off ×1.3 capped at 60 minutes; diagnostics exist only for successful requests where `validateOnly` is not set; an error rejects a record, a warning means part of it was ignored.
  - Limits (updated 2026-10-07): ingestion 100,000 requests a day and 300 a minute per project; all other services 50,000 a day and 300 a minute; 2,000 events and 10 destinations per request. The one-event-per-request design of correction 11 stands: at one first check and at most hourly checks for 26 hours, about 27 status reads per delivery, far inside 50,000 a day for one agency.
  - Offline send-events guide: `eventSource` is required; `transactionId` deduplicates within a conversion action, a matching transaction updates the value and supplements missing user data, a non-matching one creates a new conversion.
  - **One contradiction, recorded and resolved:** the guide's prose names `CALL` as an `eventSource` example, but the reference enum is `EVENT_SOURCE_UNSPECIFIED`, `WEB`, `APP`, `IN_STORE`, `PHONE`, `MESSAGE`, `OTHER`. The reference is authoritative, so correction 9's `PHONE` stands. Nothing in this contract depends on it.
- **The repair.** One table, one more state, no second ledger:
  - **State.** `ingested` is registered on `offline_conversion_delivery_status`. It sits between `pending` (claimed, under the 30-minute pre-send lease) and the terminal result.
  - **Columns** on `offline_conversion_deliveries`: `provider_request_id`, `ingested_at`, `provider_status_code`, `provider_status_payload`, `provider_checked_at`. Four CHECKs: a request id and its ingestion time exist together, and the id is 1–256 non-space characters; `ingested` requires a request id; a provider status is Google's vocabulary and requires a request; and `sent` requires a recorded `SUCCESS` (`is not distinct from`, so a NULL status cannot pass). A partial unique index makes one request name one delivery.
  - **`app.record_conversion_ingestion(delivery, request_id, error, response)`** replaces the boolean `app.record_conversion_delivery_result`, which is dropped. Exactly one of a request id (`pending` → `ingested`) or an error (`pending` → `failed` + `offline_conversion_failed`). Only a `pending` delivery can record its ingestion, so a run that lost its lease cannot attach a request.
  - **`app.conversion_status_checks_due(platform, batch)`**, read-only: an `ingested` delivery 30 minutes after ingestion, then at most hourly — never more often than Google's documented back-off after the first check.
  - **`app.record_conversion_provider_status(delivery, request_id, status, response)`**: Google's answer only for that delivery's own request. `PROCESSING` and `REQUEST_STATUS_UNKNOWN` stay `ingested`; `SUCCESS` → `sent` with one `offline_conversion_sent`, and a repeated `SUCCESS` returns `sent` and records nothing; `FAILED` and `PARTIAL_SUCCESS` (which a one-event request cannot legitimately return) → `failed` + `offline_conversion_failed`, re-claimable. Any other state, or another request's id, is refused.
  - **`app.claim_conversion_deliveries`** never re-claims an `ingested` delivery; its unchanged 30-minute lease sweep reads only `pending`; a new Step 0b fails an `ingested` delivery 26 hours after ingestion (two hours past Google's maximum) with `PROVIDER_DEADLINE`. Its OUT list gains `transaction_id`, so the function is re-created.
  - **Transaction identity (owner direction, register PH8-9, 2026-09-29).** `transaction_id` is `offline_conversions.id`, except that a `ticket_issued` formed from a `booking_issued` event carries that event's `entity_id`, the booking, so an issue and a reissue of one booking are one acquisition to Google. It is read from the append-only source event, never from the conversion's `booking_id`, which a session can update. No new-sale flag exists in the data model and none is invented; a distinct identity waits for a business fact that records a genuinely new incremental sale.
- **What stays:** the mapper, consent and identity rules, the retry ceiling of 5, every grant and policy. No Google wire format beyond the request id and status enters the CRM; payload, hashing, OAuth and the polling transport stay in the workflow. `validateOnly` cannot become `sent`, because `sent` needs a `SUCCESS` Google provides only for non-`validateOnly` requests, and the workflow records a `validateOnly` run as an error.
- **The owner's execution order (2026-10-07).** PH8-9 now; then Batch 6 resumes at Slice 31, ranked by `scripts/batch6_select_target.ps1`, until EC-1…EC-11 hold; then a bounded revalidation of the conversion boundary; then the n8n workflow; then the Direct Call Quality Feedback Loop as an explicit acceptance milestone; then PH8-10's evidence; then the Smart Bidding handoff when earned; then Phase 8 closes. Roadmap 32 owns the order and catalog §2b the conditions, so neither restates the other. It supersedes the 2026-09-28 rule that Slice 31 waits for the whole closure, which also made Batch 6 wait for a workflow roadmap 32 gates behind Batch 6.
- **EC-1's wording.** `MASTER_EXECUTION_PLAN.md` EC-1 reads "All **77** tables" while its surface set, derived from `supabase/migrations/**` and owned by `MASTER_SURFACE_DISPOSITION.md`, has held 78 since SPEC-240. EC-1 now names that set, which keeps its meaning and cannot go stale. Dated entries that said 77 when 77 was true are unchanged.
- **Placed, not repaired here:** BOOK-11 and BOOK-12 (Batch 6), PAY-5 (Batch 6 / FIN-7), CONV-9 (after PH8-10), CONV-10 (before any manual-conversion surface). Each keeps its register row and trigger.

## Risks

- **A delivery reaching `sent` without Google's SUCCESS.** Mitigated on every door: the only writer of `sent` is the `SUCCESS` branch, and a table CHECK refuses `sent` without a recorded `SUCCESS` even for the platform (assertion 44; mutant M15). Ingestion, `PROCESSING`, `UNKNOWN`, `PARTIAL_SUCCESS` and `FAILED` each fail to produce it (assertions 7–9, 20, 23, 32, 36; M1, M4, M5, M9).
- **A conversion stranded in `ingested`.** Mitigated by the 26-hour deadline in the same claim call that sweeps the lease (assertions 37–38; M6). The conversion is then re-claimed under the same transaction identity, which Google deduplicates.
- **A double count at Google.** A re-send after a crash or a deadline carries the same `transaction_id` (assertions 33, 41, 42; M11, M12). A run that dies after Google ingested but before recording the request is recovered by the unchanged lease, under the same identity (assertion 41). Distributed exactly-once transport is not claimed.
- **An obsolete or foreign answer overwriting a delivery.** A status names its delivery and that delivery's request; another request, a retried attempt or a terminal row is refused (assertions 24, 30, 34, 35; M8, M10). A request id is unique across deliveries and tenants (assertion 11; M16).
- **Replacing the claim and dropping the boolean RPC.** The claim's body is the SPEC-240 body with three additions: `ingested` in its exclusion list, Step 0b, and the `transaction_id` column. Every other line is byte-identical. Tests 13, 137 and 142 pass unchanged against it. Test 09 reached `sent` through the boolean and is rewritten to reach it through ingestion and `SUCCESS`. No workflow exists, so no consumer breaks; a stale caller of the dropped signature fails with "function does not exist" rather than marking anything `sent`.
- **Primary deployment** adds one catalog value, five columns, four CHECKs and one index; re-creates the claim; drops one function; and adds three. Primary must hold 0 deliveries at deployment for the CHECKs to validate. It requires separate exact-byte owner authorization (Gate 2). Approving this contract does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-243-a-conversion-is-sent-only-on-google-success.md`
- `supabase/migrations/20261007120000_a_conversion_is_sent_only_on_google_success.sql`
- `supabase/tests/143_a_conversion_is_sent_only_on_google_success_test.sql`
- `supabase/tests/09_conversion_delivery_lease_test.sql`
- `scripts/verify_database.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `_ORVION_CANONICAL/24_entity_registry.md`
- `_ORVION_CANONICAL/25_catalog_registry.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607049200_offline_conversion_core.sql`
- `supabase/migrations/202607050100_conversion_delivery_lease.sql`
- `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/13_conversion_identity_snapshot_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/102_financial_account_identity_and_definer_surface_test.sql`
- `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`
- `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/architecture-decision-records.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `reports/master/MASTER_INTEGRATION_CATALOG.md` §1, §2, §2a, §2b; `reports/master/MASTER_GAP_REGISTER.md` (PH8-5, PH8-8, PH8-9, PH8-10, CONV-9, CONV-10)
- `_ORVION_CANONICAL/32_execution_roadmap.md` Phase 8; `reports/master/MASTER_EXECUTION_PLAN.md` exit criteria
- Current local `app.claim_conversion_deliveries`, `app.record_conversion_delivery_result`, `app.map_outcomes_to_conversions`, `app.record_event`, `app.enforce_catalog_codes`
- The Google first-party pages named in Business Reason

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

- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A delivery is `sent` only on Google's terminal `SUCCESS`; `ingested` holds an accepted request | the future workflow (§2, §2a corrections 1, 6, 8, 11); Tests 09 and 13; `offline_conversion_sent`/`_failed` consumers | WRITE | The prototype was applied as a real migration on a clean reset in scratch worktree `C:\w243` at `67007fb`: migration SHA-256 `4746ad7c439c56b551ce69596fb06f88c31f8fa2dcb29455bbafbb16d14d43a5`, Test 143 SHA-256 `95a6d9c0b802b7d1b5a226f45fa31faa0ef6f4a4a17446f06f0dc0cc032e67e0` (45/45). Test 09 reached `sent` through the dropped boolean and is rewritten (SHA-256 `f73c8fd6614fb1f8f6a125ce43fc0150dfdc094508d93bf48b1e9c1d10d11292`), 17/17. Test 13 sets `failed` at the table and passes unchanged. The two event types are unchanged; `sent`'s event now records `previous_state` `ingested`. §2 steps 5–6 and corrections 1, 4, 6, 8 and 11 state the workflow's side. |
| The claim's OUT list gains `transaction_id`; `ingested` joins its exclusion; Step 0b deadline | Tests 09, 13, 137, 142; correction 4 | VERIFY | Tests 137 (`select *`) and 142 (named columns) pass unchanged. Every other line of the SPEC-240 body is byte-identical. |
| One catalog value (`ingested`) | `scripts/verify_database.sql` CHECK 6b; `enforce_catalog_codes` | WRITE | The smoke pin moves 621 → 622 (SHA-256 `33c0cfdb3e5ac09c88109bb98a4c081483feb32220993b28438b41bd0187be7f`); measured `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`, exit 0. |
| Three new SECURITY DEFINER functions and one dropped, all integration-only | Tests 10, 53, 58, 102; `MASTER_API_CONTRACT.md`; smoke CHECK 10 | VERIFY | None is executable by `authenticated` or `anon`, so Tests 53 and 102 and the API contract do not move: the generator reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables, byte-identical. Tests 10 and 58 pass unchanged. |
| Suite, smoke and every HTTP door | full pgTAP; the six HTTP suites | VERIFY | On the prototype, on a clean reset, in `-Finish`'s order: pgTAP Pass A 143 files / 2615 assertions PASS (2570 + 45); HTTP 35 + 40 + 74 + 122 + 120 + 60 = 451 passed, 0 failed, each exit 0; Pass B 143 / 2615 PASS; smoke exit 0. |
| Measured state that moves | manifest (`Live state`, suite figure, catalog figure, Last Completed, Next capability, Current Module, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 9, 15, 19 | WRITE | Repository consistency on the prototype reports exactly the six expected pre-deploy issues (three migration-state drifts, two suite-figure drifts, RECOVER-1). 239 → 240 migrations, latest `20261007120000`, predicted ledger `5907e3b5a170d153797aff8cb08ca20e`; 142 → 143 files, 2570 → 2615 assertions; catalog 621 → 622. Tables (78), client RPCs (80), HTTP assertions (451) and coverage (31 of 78) do not move. `ai-map.json` differs only in `generated_at`. Primary values are written only from fresh post-deploy readings. |
| CI-only guard self-tests | `scripts/test_*_guard.ps1` (four) | VERIFY | Future-date 18/0 and status-contradiction 33/0 pass on the prototype. Primary-ledger (2 failed) and cold-start (9 failed) fail only their CONTROL cases, which require a clean repository and therefore fail on any undeployed migration; on the baseline they pass 13/0 and 34/0. No pinned figure moves: the open-decision line keeps MAIL-1, RET-1 and PH8-10. Re-run after Step 7. |
| PH8-9 fixed; PH8-5's identifier refined; §2b order, item 3 closed and item 6 added; roadmap order; EC-1; canon delivery states | `MASTER_GAP_REGISTER.md`; `MASTER_INTEGRATION_CATALOG.md`; `32_execution_roadmap.md`; `MASTER_EXECUTION_PLAN.md`; canon 21, 24, 25, 26; Checks 2, 6, 11, 14, 16, 21, 25, 26 | WRITE | Prototype SHA-256 values: register `721368eeb1953dff0cd9a7c9ad8bfaa392d8fd6700f4429a308ed3d73551b0fd`, catalog `7576ac293402af9f86b94670762412ca23ef9ea63f54bb15d7f4fd5da04d5257`, plan `c9267ea5025d73543c74bf596c6c4c4e9b31c69c98fbb26de2254973b8739793`, canon 21 `b884d21ee709f8a12cc5ab420067b3f1c35cab88fcecc41633845d62156927a1`, 24 `3da8ca4c0368ac2c5df5f16417e67de85bcaee247295a1d840239e42378f5831`, 25 `3302740d14312a4da25af9dc54ed33763a5a86d0ec3919ba56a3857ac1583f41`, 26 `ca413df6c5f77b5a8f12e19286fc75a23dd8f64bd0abcf1fb183c6f1207cc8c6`, roadmap `b20f48ae934dabb141c06fd21a82ca11964d554977908ee8b6a1ec4b586ddcd0`. Checks 2, 6, 11, 14, 16, 21, 25 and 26 are clean on the prototype. No new planning document; the disposition record does not move (`offline_conversion_deliveries` stays `NOT-RECORDED`). |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| PH8-5, PH8-9, the catalog, roadmap, plan and canon edits describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: ADR-0023's outbox — one `offline_conversion_deliveries` row per attempt, the claim with its lease sweep and retry ceiling, the event spine through `app.record_event`, catalog enforcement through `app.enforce_catalog_codes`, and SECURITY DEFINER RPCs granted to `orvion_integration` alone. The only new structure is the provider request on the existing row and one catalog value, because no existing column or state can hold "Google accepted this request and has not yet answered". Rejected:
- **Extending the boolean** to mean both "accepted" and "processed": the ambiguity is the defect.
- **A second ledger** of provider requests: two representations of one attempt.
- **Hiding the request inside `pending`**: the lease sweep and every reader would have to know a sub-state.
- **Polling state only in n8n**: lost on a restart, and the database could not refuse an illegal transition.
- **An indefinite in-progress state**: replaced by the 26-hour deadline.
- **`booking_id` as the reissue identity**: a session can update it.
- **A new event type for ingestion**: the row records the request and its time; the sent and failed events carry the request id.

Added Property: A delivery is `sent` only when Google reported `SUCCESS` for that delivery's own recorded request, and only once. An accepted request is held as `ingested`; it is never re-claimed or lease-swept, it is due for a status check 30 minutes after ingestion and then at most hourly, and it is failed by a 26-hour deadline. `FAILED` and `PARTIAL_SUCCESS` re-enter the existing retry path under the same Google transaction identity. A reissue of one booking shares that booking's identity. No door, the platform included, can write `sent` without a recorded `SUCCESS`.

Causal Negative: The pre-repair measurement in Business Reason, at `67007fb`: an ingestion acknowledgement made a delivery `sent` with a sent event, a later FAILED was refused, and the conversion was never re-claimed. On the prototype, a direct `UPDATE … set delivery_status_code = 'sent'` passed the first draft's CHECK (`provider_status_code = 'SUCCESS'`, NULL for an unresolved row) and was refused only after the CHECK became `is not distinct from` (assertion 44).

Positive Test Design: As the platform, with no session, two tenants: thirteen consented conversions of tenant one covering all five types, one phone call without consent, and one conversion of tenant two. Two `booking_issued` events of one booking and one of another source three ticket conversions. Claim them; record ingestion; poll through `PROCESSING`, `REQUEST_STATUS_UNKNOWN` and `SUCCESS`; fail one through `FAILED`, one through `PARTIAL_SUCCESS`, one by the deadline, one at ingestion by a material `fieldWarnings` entry, one as a `validateOnly` run, and one by a crash before its request was recorded; re-claim each.

Negative Test Design: Ingestion, `PROCESSING`, `REQUEST_STATUS_UNKNOWN`, `PARTIAL_SUCCESS` and `FAILED` never make `sent`. An `ingested` delivery is neither re-claimed nor lease-swept. An empty or malformed request id, a missing one, or a request id with an error is refused. A second request on an ingested delivery is refused, and a request id already attached to another tenant's delivery raises `23505`. A status for another request, an unknown status, a late answer for an obsolete attempt, `FAILED` after `sent`, and a second `SUCCESS` event are each refused or recorded nowhere. The platform cannot write `sent` without `SUCCESS`, or `ingested` without a request. A phone conversion without consent is not claimed.

Non-Empty Population Obligation: Two tenants with active enterprise subscriptions; tenant one has one branch, department, three customers, one lead, one consented click, one consent record and fourteen conversions; tenant two has one of each. Five source events are recorded.

Mutation Obligation: Out of file, record the md5 of a surface covering the four functions' definitions, the table's constraints and its indexes. For each mutant: install it, prove the md5 differs, run Test 143, record the failing assertions and how many of 45 ran, restore, and prove the md5 matches the base. A mutant whose installation is not proven is a harness error, never a kill. A run may stop after the named assertion has failed, when the mutated state makes a later unguarded call raise; the kill is the named failure.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | ingestion writes `sent` with a forged `SUCCESS` | 8 |
| M2 | `ingested` is re-claimable | 16 |
| M3 | the lease sweeps `ingested` | 17 |
| M4 | `PROCESSING` is `sent` | 20 |
| M5 | `PARTIAL_SUCCESS` is `sent` | 36 |
| M6 | no provider deadline | 38 |
| M7 | a repeated `SUCCESS` re-emits | 29 |
| M8 | a stale request resolves a newer attempt | 35 |
| M9 | `REQUEST_STATUS_UNKNOWN` is `sent` | 23 |
| M10 | `FAILED` after `sent` is accepted | 30 |
| M11 | the reissue identity is ignored | 6, 42 |
| M12 | the identity is read from `booking_id` | 6, 42 |
| M13 | no 30-minute wait before the first check | 18 |
| M14 | the last check is ignored | 21 |
| M15 | the `sent` CHECK is dropped | 44 |
| M16 | request-id uniqueness is dropped | 11 |
| M17 | the request-id shape CHECK is dropped | 12, 13 |

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused tests, a clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the out-of-file mutations and the pre-repair causal negative;
- the two-session proofs: an ingestion committed by one connection is read as `ingested`, unclaimable and due by another; two concurrent `SUCCESS` calls produce one sent event; two concurrent ingestions attach one request;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261007120000_a_conversion_is_sent_only_on_google_success.sql` is absent. If absent, create it LF and ASCII, byte-identical to the prototype in `C:\w243`, with SHA-256 `4746ad7c439c56b551ce69596fb06f88c31f8fa2dcb29455bbafbb16d14d43a5` (24382 bytes). It holds exactly the objects Business Reason names: the `ingested` catalog value; the five columns, four CHECKs and partial unique index on `offline_conversion_deliveries`; `app.claim_conversion_deliveries`, dropped and re-created as the SPEC-240 body plus the three additions Risks names; `app.record_conversion_delivery_result(uuid, boolean, jsonb, text)` dropped; and `app.record_conversion_ingestion`, `app.conversion_status_checks_due` and `app.record_conversion_provider_status`, each SECURITY DEFINER with an empty `search_path`, EXECUTE revoked from PUBLIC and `authenticated` and granted to `orvion_integration`. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/143_a_conversion_is_sent_only_on_google_success_test.sql` is absent. If absent, create it LF and ASCII, byte-identical to the prototype, with SHA-256 `95a6d9c0b802b7d1b5a226f45fa31faa0ef6f4a4a17446f06f0dc0cc032e67e0` and `select plan(45);`. Its `-- ATTACK-CLASSES:` line reads `BUSINESS REPLAY STATE INPUT PRIVILEGE TENANT DOOR OBSERVABILITY AUTH=N/A CONCURRENCY=N/A`, and its header states each `N/A` reason. Then make two LF edits, each byte-identical to the prototype:
   - `supabase/tests/09_conversion_delivery_lease_test.sql`: the one block that called `app.record_conversion_delivery_result(…, true, …)` now records ingestion and `SUCCESS`, SHA-256 `f73c8fd6614fb1f8f6a125ce43fc0150dfdc094508d93bf48b1e9c1d10d11292`;
   - `scripts/verify_database.sql`: CHECK 6b's pin and its two mentions move 621 → 622 with a dated reason, SHA-256 `33c0cfdb3e5ac09c88109bb98a4c081483feb32220993b28438b41bd0187be7f`.

   If a target carries content other than its `67007fb` bytes or its frozen value, stop.
3. **Check** whether the PH8-9 row of `reports/master/MASTER_GAP_REGISTER.md` already leads its status with `✅ FIXED 2026-10-07 by SPEC-243`. If not, apply the prototype's edits, each byte-identical to its frozen value, and nothing else:
   - **Register** (`721368eeb1953dff0cd9a7c9ad8bfaa392d8fd6700f4429a308ed3d73551b0fd`): a 2026-10-07 freshness entry, the previous one demoted to `Previously:`; PH8-9 fixed by SPEC-243, pending Primary deployment, with its mechanism, the measurement and Test 143, and `Updated` `10-07`; PH8-5 gains one dated sentence on `transaction_id`, `Updated` `10-07`.
   - **Catalog** (`7576ac293402af9f86b94670762412ca23ef9ea63f54bb15d7f4fd5da04d5257`): the registry row's surface and status; §0's pointer to §2's acknowledgement RPCs; §2 step 2's `transaction_id`, step 5 rewritten for ingestion and a new step 6 for status; dated notes on corrections 1, 4, 6, 8 and 11; the 2026-10-07 re-read in the re-verification paragraph; §2b's order paragraph, item 3 closed, item 4 after Batch 6 and naming corrections 1–12, and a new item 6, the Direct Call Quality Feedback Loop.
   - **Plan** (`c9267ea5025d73543c74bf596c6c4c4e9b31c69c98fbb26de2254973b8739793`): a 2026-10-07 freshness entry, the previous one demoted; EC-1's criterion names its surface set.
   - **Canon** 21 (`b884d21ee709f8a12cc5ab420067b3f1c35cab88fcecc41633845d62156927a1`), 24 (`3da8ca4c0368ac2c5df5f16417e67de85bcaee247295a1d840239e42378f5831`), 25 (`3302740d14312a4da25af9dc54ed33763a5a86d0ec3919ba56a3857ac1583f41`) and 26 (`ca413df6c5f77b5a8f12e19286fc75a23dd8f64bd0abcf1fb183c6f1207cc8c6`): `ingested` in each delivery-state list; canon 21's rule that acceptance is not `sent`; canon 26's `pending → sent` row replaced by `pending → ingested`, `ingested → sent` and `ingested → failed`.
   - **Roadmap 32** (`b20f48ae934dabb141c06fd21a82ca11964d554977908ee8b6a1ec4b586ddcd0`): Phase 8's dated pointer to §2b, the owner's 2026-10-07 execution sequence (A–H), and the outbox deliverable's RPC names.

   If a target carries content other than its `67007fb` bytes or its frozen value, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset and the focused Tests 143 and 09;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the mutation evidence, the pre-repair causal negative and the three two-session proofs of the Post-Implementation Proof Obligation;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only: undeployed Primary, the six pre-deploy repository-consistency issues, and the guard self-test CONTROL failures they cause. Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - the tenant, conversion, delivery and event counts;
   - the current definition md5 of the claim and the boolean acknowledgement;
   - the absence of every new object.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package:
   - the current HEAD and the exact hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested;
   - the guarded ledger-normalization conditions.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261007120000_a_conversion_is_sent_only_on_google_success`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the pre-repair md5 values.
   - On an exact match, apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the four functions' security modes, `search_path` and EXECUTE ACLs; the absence of the dropped function; the table's columns, constraints and indexes; the catalog value; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings: the date, the migration count and latest version, the ledger and surface hashes and counts, the catalog figure `71/622`, and 451 HTTP assertions last passed on the Step-4 date. Confirm that `supabase/tests` holds 143 files whose literal `plan(N)` values sum to 2615, then set `Suite **143 files / 2615 assertions**`; if either differs, stop.
   - Mark PH8-9 `DEPLOYED` with Cert `✅` in the register.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE, so that Step 8's `-Finish` runs in VERIFY mode.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following in the Complete commit:
     - transition to Complete and clear `Active Change Request`;
     - set `Last Completed` to SPEC-243 / PH8-9;
     - set `Current Module` to Foundation Completion Programme Batch 6;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 31**, ranked by `scripts/batch6_select_target.ps1`, followed by the Phase-8 order roadmap 32 owns, keeping its closed-chapter and standing-fact sentences;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [x] Ingestion records Google's request id and leaves the delivery `ingested`; ingestion, `PROCESSING`, `REQUEST_STATUS_UNKNOWN`, `PARTIAL_SUCCESS` and `FAILED` never make it `sent`, and no sent event is recorded for them.
- [x] Only `SUCCESS` for the delivery's own request makes it `sent`, with exactly one `offline_conversion_sent` from `ingested`; a repeated `SUCCESS` returns `sent` and records nothing; `FAILED` after `sent` is refused.
- [x] An `ingested` delivery is never re-claimed and never lease-swept; it is due for a status check 30 minutes after ingestion and then at most hourly; 26 hours after ingestion the claim fails it with `PROVIDER_DEADLINE` and re-claims the conversion.
- [x] `FAILED`, `PARTIAL_SUCCESS`, a material `fieldWarnings` entry, a `validateOnly` run and an ingestion error each become `failed` and re-claimable under the retry ceiling of 5, and every retry carries the same `transaction_id`.
- [x] A request id is required, well-formed and unique across deliveries and tenants; a delivery takes at most one; a status for another request or for an obsolete attempt is refused.
- [x] `transaction_id` is the conversion's id, except that a mapped `ticket_issued` carries its source event's booking, so an issue and a reissue of one booking share it; it is never read from `offline_conversions.booking_id`.
- [x] No door, the platform included, can write `sent` without a recorded `SUCCESS` or `ingested` without a request id.
- [x] The four delivery RPCs are SECURITY DEFINER with an empty `search_path` and executable by `orvion_integration` only; `app.record_conversion_delivery_result` no longer exists; a phone conversion without consent is still not claimed.
- [x] Mutants M1 to M17 are each killed, with installation and restoration md5-proven. The pre-repair causal negative and the three two-session proofs are recorded.
- [x] Register and records: PH8-9 is fixed and deployed; PH8-5 records `transaction_id`; catalog §2/§2a describe the new contract, §2b item 3 is closed, item 6 exists and its order points to roadmap 32; roadmap 32 records the owner's 2026-10-07 sequence; EC-1 names its surface set; canon 21, 24, 25 and 26 list `ingested`. CONV-9, CONV-10, BOOK-11, BOOK-12 and PAY-5 are unchanged; the Google Ads registry row stays `NOT OPERATIONAL`; no new planning document exists.
- [x] The migration, the two tests, the smoke script and the eight Step-3 documents matched their frozen SHA-256 values when applied. Primary, the recorded evidence, the manifest (240 migrations; 143 files / 2615 assertions; 71/622 catalog), the API contract and `ai-map.json` agree.
- [x] The manifest names Foundation Completion Programme Batch 6 Slice 31 as the next capability, with no Active Change Request.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

None.

### 2026-10-07 — Owner-delegated approval and execution start

The owner's directive of 2026-10-07 authorized this bounded PH8-9 task to proceed through Draft, Pre-Approval Evidence, Approved, In Progress, implementation, local verification and Review without pausing for routine acknowledgements, on condition that the objective stays PH8-9 plus its direct planning consumers, no unrelated architecture is added, the Write Scope stays justified and no new material owner decision appears. It does not authorize any Primary write; Gate 2 is required.

- Draft `d970dd6`; a read-only evaluation of it returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE and REPOSITORY). Two mutated copies were refused: a gate moved to Step 4 inside the red window 2..7 (`FAIL`), and a removed Mutation Obligation (`INDETERMINATE`).
- Approved at `302f569`; its pre-commit Gate reported `APPROVAL_EVIDENCE: PASS`.
- In Progress from this commit. Resume Step 1. Primary stays read-only until Gate 2; Secondary `brplkqmbzffpxqgkkdzo` is never contacted.

### 2026-10-07 — Steps 1-3 applied (uncommitted until after deployment)

- **Step 1: Applied.** The migration was absent and was created LF and ASCII, byte-identical to the prototype: SHA-256 `4746ad7c439c56b551ce69596fb06f88c31f8fa2dcb29455bbafbb16d14d43a5`, md5 `6d63f73e7d03beadac97836ea02ef2d1`, 24382 bytes.
- **Step 2: Applied.** Test 143 (`95a6d9c0…`, `plan(45)`), Test 09 (`f73c8fd6…`) and `scripts/verify_database.sql` (`33c0cfdb…`) match their frozen SHA-256 values. Both edited targets held their `67007fb` bytes first.
- **Step 3: Applied.** The PH8-9 row did not lead with the FIXED line. Register `721368ee…`, catalog `7576ac29…`, plan `c9267ea5…`, canon 21 `b884d21e…`, 24 `3da8ca4c…`, 25 `3302740d…`, 26 `ca413df6…` and roadmap `b20f48ae…` match their frozen values; every target held its `67007fb` bytes first.

Per the DATABASE sequencing, these twelve paths stay uncommitted until Primary is deployed and the manifest remeasured.

### 2026-10-07 — Pre-deploy readiness gate

Run on HEAD `5de1915` with every Step 1-3 file at its frozen hash.

- **Reset:** a clean local reset to 240 migrations, latest `20261007120000`.
- **Focused:** Tests 143 and 09, 62/62 (45 + 17).
- **pgTAP Pass A:** 143 files / 2615 assertions PASS.
- **HTTP suites:** `verify_api_end_to_end` 35, `verify_care_journeys` 40, `verify_journey_branches` 74, `verify_lifecycle_branches` 122 (the declared suite), `verify_role_journeys` 120, `verify_storage_end_to_end` 60: 451 passed, 0 failed, each exit 0.
- **pgTAP Pass B,** without reset: 143 / 2615 PASS.
- **Smoke:** `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`, exit 0. Plan sum: 143 files, 2615 assertions.
- **Mutation:** base surface md5 `a6c85aab17521c8a7e89168132a3d352` (the four functions' definitions, the table's constraints and indexes). Each installation was proven by a changed md5 and each restoration by the base md5; the final md5 equals the base. All 17 were killed:

  | Mutant | Failing assertions | Ran of 45 |
  | --- | --- | --- |
  | M1 ingestion writes `sent` | 8, 17, 19 | 19 |
  | M2 `ingested` re-claimable | 16, 17 | 18 |
  | M3 lease sweeps `ingested` | 17 | 18 |
  | M4 `PROCESSING` is `sent` | 20, 21, 22 | 22 |
  | M5 `PARTIAL_SUCCESS` is `sent` | 36 | 45 |
  | M6 no provider deadline | 38 | 45 |
  | M7 repeated `SUCCESS` re-emits | 29, 30, 31 | 45 |
  | M8 stale request resolves newer | 24, 27, 35 | 45 |
  | M9 `UNKNOWN` is `sent` | 23 | 25 |
  | M10 `FAILED` after `sent` | 30, 31 | 45 |
  | M11 reissue identity ignored | 6, 42 | 45 |
  | M12 identity from `booking_id` | 6, 42 | 45 |
  | M13 no 30-minute wait | 18 | 45 |
  | M14 last check ignored | 21 | 45 |
  | M15 `sent` CHECK dropped | 44 | 45 |
  | M16 request-id uniqueness dropped | 11 | 45 |
  | M17 request-id shape dropped | 12, 13 | 31 |

  Six runs stop after their named assertion failed, because the mutated state makes a later unguarded call raise (M1-M4, M9, M17); the Mutation Obligation admits that and the kill is the named failure. The identical harness on the prototype gave identical results.
- **Causal negative (pre-repair schema, `67007fb`, rolled back):** claimed 1; the boolean acknowledgement of an ingestion made the delivery `sent` with 1 sent event; the only delivery RPCs were `claim_conversion_deliveries` and `record_conversion_delivery_result`; a later FAILED was refused (`delivery … is sent — only pending deliveries can be resolved`); re-claimed after 48 hours: 0.
- **Two-session proofs** (prototype schema, disposable committed state, reset afterwards):
  - an ingestion committed by backend 409 was read by backend 416 as `ingested` with `REQ-LIVE-143`; its claim took 0; aged 31 minutes, it was due with its request id;
  - two concurrent `SUCCESS` calls: B waited on `Lock/transactionid` from 17:36:21.40 until A committed at 17:36:24.005, then returned `sent`; 1 sent event; state `sent`/`SUCCESS`;
  - two concurrent ingestions of one delivery: B waited on A's lock and was refused (`… is ingested -- only a pending delivery can record its ingestion`); the request is `REQ-LIVE-A` alone.
- **Generators:** `MASTER_API_CONTRACT.md` regenerates byte-identical (80 RPC endpoints, 80 with HTTP evidence, 8 views, 74 tables). `ai-map.json` differs only in `generated_at` and was restored until Step 7.
- **Scope, diff check and consistency:** the twelve changed paths are all in Write Scope; `git diff --check` exited 0. Repository consistency reports exactly the six expected pre-deploy issues: three migration-state drifts, two suite-figure drifts and RECOVER-1.
- **Guard self-tests (prototype):** future-date 18/0 and status-contradiction 33/0; primary-ledger and cold-start fail only their clean-repository CONTROL cases (baseline 13/0 and 34/0). Re-run at Step 7.

**Fresh Primary baseline,** read-only from `https://vrvtsxexkiiiivlkdxzp.supabase.co`:
- **Ledger:** 239 migrations, `66f7ce11526941ed7ab4e675b3fd4e28`, equal to the recorded evidence; latest `20260929160000`. The target is absent by version and by name.
- **Function surface:** `78339ac07ebd500811850ad5bf04f302`/318.
- **Structural surfaces:** functions `78339ac0…`/318, triggers `d07aa82d…`/306, policies `b67d466a…`/125, constraints `623c6b38…`/521, grants `ebdcfde6…`/195, columns `2d54cc2a…`/1129, views `10bb212a…`/16, indexes `cdaa3b83…`/298, status_transitions `db2165c7…`/115, rls_enabled `c117cbf7…`/79, `_combined` `77bba1da1535be6fcfee07aff2ca118c`/3102 — equal to the recorded evidence.
- **Pre-repair definition md5:** claim `55b47389de51be40a8cd2252126d3f69` (equal to SPEC-240's deployed value), boolean acknowledgement `5df2b44ce26f3eeb3c1c8adbaf7b8ff3`.
- **Absent:** the `ingested` catalog value, the three new functions, the five columns, the four CHECKs and the index.
- **Business rows:** 0 tenants, offline conversions, deliveries, events and attribution clicks; 621 catalog values.

**Predicted delta,** equal to the local post-migration surface:
- **Ledger:** 240 migrations, latest `20261007120000`, fingerprint `5907e3b5a170d153797aff8cb08ca20e`.
- **Surfaces:** functions `e6bb8dd300da86442ff8bcd942912d94`/320 (+2: three added, one dropped, the claim re-created); triggers, policies, grants, views, status_transitions and rls_enabled unchanged; constraints `cea733efe840d1579bc55f541de54c2d`/525 (+4); columns `448db887b387a7b7974675beca4d502e`/1134 (+5); indexes `56872e87068cc220c988957980511eae`/299 (+1); `_combined` `f8062e9459f894e1f4e0a5b8ef0b0efc`/3114.
- **Catalog:** 622 values. **Business rows:** none written.

Stopped at Step 5: Human Gate 2.
### 2026-10-07 — Human Gate 2: owner authorization

The owner authorized deployment to Primary `vrvtsxexkiiiivlkdxzp` of exactly `supabase/migrations/20261007120000_a_conversion_is_sent_only_on_google_success.sql`, SHA-256 `4746ad7c439c56b551ce69596fb06f88c31f8fa2dcb29455bbafbb16d14d43a5`, md5 `6d63f73e7d03beadac97836ea02ef2d1`, with the focused test `143_a_conversion_is_sent_only_on_google_success_test.sql` at SHA-256 `95a6d9c0b802b7d1b5a226f45fa31faa0ef6f4a4a17446f06f0dc0cc032e67e0`. Conditions, any mismatch voiding it: HEAD `c8d77a1` or the exact expected pre-deployment state; both hashes unchanged; Primary at 239 migrations with latest `20260929160000`; `20261007120000` absent; the PH8-9 objects absent; business counts compatible with the recorded evidence; Secondary never contacted. The authorization continues through deployment verification, Review, Complete, publication, exact-SHA candidate CI, promotion, `REMOTE_CERTIFY: READY` and synchronization, ending with the next capability set to Batch 6 Slice 31. It does not authorize n8n.
### 2026-10-07 — Step 6: Primary deployment

**Prewrite recheck, every condition exact:** HEAD `c8d77a17a529c22a0c23caae60b2bf920c6cd818`; migration SHA-256 `4746ad7c…`, md5 `6d63f73e…`, 24382 bytes, 0 CR, 0 non-ASCII; Test 143 `95a6d9c0…`; only the twelve in-scope Step 1-3 paths dirty; project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 239, `66f7ce11…`, latest `20260929160000`, target absent by version and name; claim `55b47389…` and boolean acknowledgement `5df2b44c…` unchanged; the catalog value, three functions, five columns, four CHECKs and index absent; 0 tenants, conversions, deliveries, events and clicks; 621 catalog values.

**Write:**
- The text to transmit was first proven server-side, read-only, to hash to md5 `6d63f73e7d03beadac97836ea02ef2d1` and 24382 bytes.
- That text was applied through `apply_migration` as `a_conversion_is_sent_only_on_google_success`. The connector assigned the temporary version `20261007182839`; its single stored statement has md5 `6d63f73e…` and 24382 bytes, equal to the file.
- One guarded CTE UPDATE renamed only that row to `20261007120000`. The guard required 240 rows, the other 239 hashing to the baseline, the statement md5 to match, and no existing target. All four were true; 1 row renamed.

**Fresh postwrite reads, every value equal to the frozen prediction:**
- **Ledger:** 240, `5907e3b5a170d153797aff8cb08ca20e`, latest `20261007120000`, present once; the temporary version is gone.
- **Surfaces:** functions `e6bb8dd3…`/320, triggers `d07aa82d…`/306, policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `ebdcfde6…`/195, columns `448db887…`/1134, views `10bb212a…`/16, indexes `56872e87…`/299, status_transitions `db2165c7…`/115, rls_enabled `c117cbf7…`/79, `_combined` `f8062e9459f894e1f4e0a5b8ef0b0efc`/3114.
- **Functions:** `app.record_conversion_delivery_result` is absent. The claim (`d72b27bb50c289b9170667db849dad67`), `app.record_conversion_ingestion` (`6a9b6929dd221ee13e49a8bc61b6a69c`), `app.conversion_status_checks_due` (`fe9d52eeef4c1e02aa91a278ca020457`) and `app.record_conversion_provider_status` (`401eeb377845eeae8149b11fbbecdf65`) are byte-identical to local, SECURITY DEFINER, owned by `postgres`, `search_path=""`, ACL `{postgres=X, orvion_integration=X}` only.
- **Table:** the five columns in order after `created_at`; the four CHECKs validated; the partial unique index `offline_conversion_deliveries_provider_request_id_key`; 78 public tables.
- **Catalog:** `ingested` (`Ingested`, sort 5, active); 622 values.
- **Business rows:** 0 tenants, conversions, deliveries, events and clicks.

No business-data write and no reproduction was made on Primary. Secondary `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-10-07 — Step 7: evidence and measured state

- `reports/evidence/primary-ledger-evidence.json` was rewritten from the fresh readings only: 240 migrations, `5907e3b5…`, functions `e6bb8dd3…`/320, structural `f8062e94…`/3114, commit `c8d77a1`; its ledger equals the repository's migration files.
- `supabase/tests` holds 143 files whose `plan(N)` values sum to 2615. The manifest's `Live state` now reads 240 migrations, latest `20261007120000`, the same hashes and counts, 78 tables, `71/622` catalog, 80 client RPCs, `Suite **143 files / 2615 assertions**` and 451 HTTP assertions last passed 2026-10-07. The manifest measures 6599 characters.
- PH8-9 is marked DEPLOYED with Cert `✅`.
- `MASTER_API_CONTRACT.md` regenerates byte-identical; `ai-map.json` was regenerated and stored LF.
- The four guard self-tests pass: future-date 18/0, status-contradiction 33/0, primary-ledger 13/0, cold-start 34/0.
- `check_primary_ledger.ps1` `RECOVER-1 LEDGER EVIDENCE: CLEAN`; `check_database_parity_evidence.ps1` `PRIMARY PARITY EVIDENCE: CLEAN`; repository consistency exit 0; `git diff --check` exit 0.
- The Runtime Checkpoint is DONE, so Step 8's `-Finish` runs in VERIFY mode.
### 2026-10-07 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` on the clean committed execution HEAD `17b5623` in VERIFY mode, profiles DATABASE and REPOSITORY. The first run stopped at its first command: `npx supabase db reset` exited 1 with `error running container: exit 1` during "Initialising schema", while the database container itself came back healthy. Recovery attempt 1: the same reset run alone with `--debug` exited 0 at 240 migrations, so the failure was a transient helper-container exit, not a migration defect. The second `-Finish` passed every mandatory verification and returned `LOCAL_CERTIFY: READY`:
- reset; pgTAP Pass A; the declared `verify_lifecycle_branches.ps1`; pgTAP Pass B; smoke;
- `check_database_parity_evidence.ps1`; repository consistency; `git diff --check`; `check_primary_ledger.ps1`.
## Verification Notes

None.

### 2026-10-07 — Independent Review of execution commit `17b5623`

Reviewed the committed tree against the approved Draft `d970dd6`, the owner's Gate-2 authorization and the frozen seventeen-path Write Scope, not against the Execution Log.
- **Scope.** `67007fb..17b5623` changes sixteen paths, all in Write Scope; `MASTER_API_CONTRACT.md` regenerates byte-identical and is unchanged; `MASTER_SURFACE_DISPOSITION.md` and every Out-of-Scope file are untouched.
- **Frozen bytes.** The committed migration (`4746ad7c…`), Test 143 (`95a6d9c0…`), Test 09 (`f73c8fd6…`), the smoke script (`33c0cfdb…`), catalog (`7576ac29…`), plan (`c9267ea5…`), canon 21, 24, 25, 26 and roadmap 32 hash to their frozen values. The register differs from its Step-3 value by exactly one line, the PH8-9 row's Step-7 `DEPLOYED` status and Cert `✅`.

Acceptance, re-checked against the committed bytes, the certified run and the Primary readback:
1. **Ingestion is not delivery.** Assertions 7–9, 20, 23, 32, 36 and 39–40: ingestion records the request and leaves `ingested`; `PROCESSING`, `REQUEST_STATUS_UNKNOWN`, `PARTIAL_SUCCESS`, `FAILED`, a material `fieldWarnings` entry and a `validateOnly` run never make `sent` or a sent event. Mutants M1, M4, M5 and M9 are killed.
2. **SUCCESS, once.** Assertions 26–30: only `SUCCESS` for the delivery's own request makes `sent`, with one event from `ingested`; a repeat returns `sent` and records nothing; `FAILED` after `sent` is refused (M7, M10). The two-session proof gave one event for two concurrent `SUCCESS` calls.
3. **Pending lifecycle.** Assertions 16–22 and 37–38: never re-claimed, never lease-swept, due 30 minutes after ingestion and then at most hourly, failed by the 26-hour deadline and re-claimed (M2, M3, M6, M13, M14). The committed ingestion survived a new connection in the live proof.
4. **Retry.** Assertions 32–33, 36, 38–43: every failure path re-enters the existing retry path under the ceiling of 5 with the same `transaction_id`.
5. **Request identity.** Assertions 10–15, 24, 34–35: required, well-formed, unique across deliveries and tenants, one per delivery; another request's or an obsolete attempt's status is refused (M8, M16, M17). Two concurrent ingestions attached one request.
6. **Reissue.** Assertions 6 and 42: an issue and a reissue of one booking share the booking from the source event; `booking_id` is never read (M11, M12).
7. **Doors.** Assertions 44–45: the platform cannot write `sent` without `SUCCESS` or `ingested` without a request (M15).
8. **Authority shape.** Assertions 1–3 and the Primary readback: four SECURITY DEFINER RPCs with an empty `search_path`, ACL `{postgres, orvion_integration}`; the boolean is absent on Primary and locally; assertion 5 keeps the unconsented phone call unclaimed.
9. **Mutation.** M1–M17 killed with md5-proven install and restore, identical on the prototype and the main checkout; the causal negative and three two-session proofs are recorded.
10. **Records.** PH8-9 fixed and deployed; PH8-5 records `transaction_id`; catalog §2/§2a, §2b item 3, item 6 and its order paragraph; roadmap 32's 2026-10-07 sequence; EC-1's surface-set criterion; `ingested` in canon 21, 24, 25 and 26. CONV-9, CONV-10, BOOK-11, BOOK-12 and PAY-5 rows are byte-identical to `67007fb`; the Google Ads registry row stays `NOT OPERATIONAL`; no new planning document exists.
11. **Agreement.** Primary, the evidence and the manifest agree: 240 migrations, `5907e3b5…`, functions `e6bb8dd3…`/320, structural `f8062e94…`/3114, 143 files / 2615 assertions, `71/622`; RECOVER-1 and parity evidence CLEAN; the four guard self-tests pass.
12. **Handoff.** The Complete commit sets the next capability to Batch 6 Slice 31 with no Active Change Request.
13. **Primary.** Only the authorized bytes (statement md5 `6d63f73e…`) and the one guarded rename; 0 business rows before and after; Secondary was never contacted.
14. **Scope.** No file outside Write Scope was created, modified or deleted.

Not built, as directed: the n8n workflow, the Direct Call Quality Feedback Loop, PH8-10, and Slice 31.

Verdict: Confirmed Complete

Recommendation to human: Set Status to Complete
## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created or deleted.
- [x] No section was added, removed or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **EARN IT.** PH8-9 was reproduced through the real claim and acknowledgement on the pre-repair schema. The planning edits are the owner's 2026-10-07 order and the EC-1 count that SPEC-240 made stale; nothing else is touched.
- **WORTH IT.** One state, five columns, three RPCs replacing one, and three lines in the claim. No new table, event type, permission or ledger.
- **SIMPLIFY IT WITHOUT WEAKENING.** The database owns the state machine and n8n stays transport. Each transition locks its row and judges it under the lock. A CHECK makes the central invariant hold on every door. The tests are behavioural and pinned by 17 mutants, not SQL text.
- **Owner delegation (2026-10-07).** The owner authorized this bounded task to proceed through Draft, Pre-Approval Evidence, Approved, In Progress, implementation, local verification and Review without pausing for routine acknowledgements, provided its objective stays PH8-9 plus the direct planning consumers and no new material owner decision appears. That delegation does not authorize any Primary write: Gate 2 is required.
- **Deliberately not changed:** the mapper, consent, identity and E.164 rules (SPEC-240); the n8n workflow; PH8-10; BOOK-11, BOOK-12, PAY-5, CONV-9 and CONV-10; `MASTER_SURFACE_DISPOSITION.md`; the registered worktrees `owt/p2` and `C:\w234`.
