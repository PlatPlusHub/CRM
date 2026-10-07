# Change Request — SPEC-243

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
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

Resume Step: 1
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

- [ ] Ingestion records Google's request id and leaves the delivery `ingested`; ingestion, `PROCESSING`, `REQUEST_STATUS_UNKNOWN`, `PARTIAL_SUCCESS` and `FAILED` never make it `sent`, and no sent event is recorded for them.
- [ ] Only `SUCCESS` for the delivery's own request makes it `sent`, with exactly one `offline_conversion_sent` from `ingested`; a repeated `SUCCESS` returns `sent` and records nothing; `FAILED` after `sent` is refused.
- [ ] An `ingested` delivery is never re-claimed and never lease-swept; it is due for a status check 30 minutes after ingestion and then at most hourly; 26 hours after ingestion the claim fails it with `PROVIDER_DEADLINE` and re-claims the conversion.
- [ ] `FAILED`, `PARTIAL_SUCCESS`, a material `fieldWarnings` entry, a `validateOnly` run and an ingestion error each become `failed` and re-claimable under the retry ceiling of 5, and every retry carries the same `transaction_id`.
- [ ] A request id is required, well-formed and unique across deliveries and tenants; a delivery takes at most one; a status for another request or for an obsolete attempt is refused.
- [ ] `transaction_id` is the conversion's id, except that a mapped `ticket_issued` carries its source event's booking, so an issue and a reissue of one booking share it; it is never read from `offline_conversions.booking_id`.
- [ ] No door, the platform included, can write `sent` without a recorded `SUCCESS` or `ingested` without a request id.
- [ ] The four delivery RPCs are SECURITY DEFINER with an empty `search_path` and executable by `orvion_integration` only; `app.record_conversion_delivery_result` no longer exists; a phone conversion without consent is still not claimed.
- [ ] Mutants M1 to M17 are each killed, with installation and restoration md5-proven. The pre-repair causal negative and the three two-session proofs are recorded.
- [ ] Register and records: PH8-9 is fixed and deployed; PH8-5 records `transaction_id`; catalog §2/§2a describe the new contract, §2b item 3 is closed, item 6 exists and its order points to roadmap 32; roadmap 32 records the owner's 2026-10-07 sequence; EC-1 names its surface set; canon 21, 24, 25 and 26 list `ingested`. CONV-9, CONV-10, BOOK-11, BOOK-12 and PAY-5 are unchanged; the Google Ads registry row stays `NOT OPERATIONAL`; no new planning document exists.
- [ ] The migration, the two tests, the smoke script and the eight Step-3 documents matched their frozen SHA-256 values when applied. Primary, the recorded evidence, the manifest (240 migrations; 143 files / 2615 assertions; 71/622 catalog), the API contract and `ai-map.json` agree.
- [ ] The manifest names Foundation Completion Programme Batch 6 Slice 31 as the next capability, with no Active Change Request.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

- **EARN IT.** PH8-9 was reproduced through the real claim and acknowledgement on the pre-repair schema. The planning edits are the owner's 2026-10-07 order and the EC-1 count that SPEC-240 made stale; nothing else is touched.
- **WORTH IT.** One state, five columns, three RPCs replacing one, and three lines in the claim. No new table, event type, permission or ledger.
- **SIMPLIFY IT WITHOUT WEAKENING.** The database owns the state machine and n8n stays transport. Each transition locks its row and judges it under the lock. A CHECK makes the central invariant hold on every door. The tests are behavioural and pinned by 17 mutants, not SQL text.
- **Owner delegation (2026-10-07).** The owner authorized this bounded task to proceed through Draft, Pre-Approval Evidence, Approved, In Progress, implementation, local verification and Review without pausing for routine acknowledgements, provided its objective stays PH8-9 plus the direct planning consumers and no new material owner decision appears. That delegation does not authorize any Primary write: Gate 2 is required.
- **Deliberately not changed:** the mapper, consent, identity and E.164 rules (SPEC-240); the n8n workflow; PH8-10; BOOK-11, BOOK-12, PAY-5, CONV-9 and CONV-10; `MASTER_SURFACE_DISPOSITION.md`; the registered worktrees `owt/p2` and `C:\w234`.
