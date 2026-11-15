# Change Request — SPEC-309

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 53 records every conversation message once, on every door, and moves its conversation with it, and takes a signed-in door message's times from the clock as the RPC does. It also normalizes every customer identity signal on every door and lets no client rewrite one, so the duplicate check compares like with like and no signal is moved, retyped or rewritten unrecorded (CHAT-3, CHAT-4, CUST-13, CUST-14).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `d38eb19`, on the live local catalog, ranks `conversation_messages` (Exposure 5, coverage 24), `customer_identity_signals` (5/24) and `offline_conversion_deliveries` (5/34) next, all NOT-RECORDED. Under the owner's instructions of 2026-11-15, this slice's entry grouped the selector's next three surfaces in one contract per product. Each surface keeps its own finding rows, migration or test, and disposition row. The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.**
  - `conversation_messages` holds what was said in a conversation. Its RPC `app.send_conversation_message` stamps the time from the clock, stores a blank text as none, moves the conversation's `updated_at` and records `conversation_message_sent` or `conversation_message_received`, which `app.customer_timeline` reads. `authenticated` holds table-level INSERT beside the RPC, and PostgREST serves it.
  - `customer_identity_signals` holds the phones, WhatsApp numbers, emails and document numbers by which a customer was identified. `app.find_customer_duplicates` reads them, normalized, to warn before a second record of the same person is created. `app.create_customer` writes them normalized and only inserts; the merge (SECURITY DEFINER) moves them. `authenticated` holds table-level INSERT and UPDATE, and the table has no rewrite guard.
  - `offline_conversion_deliveries` holds each conversion's delivery to Google Ads. `authenticated` holds SELECT only, and its three writers are SECURITY DEFINER and executable by `orvion_integration` only.
- **Measured at `d38eb19`** on the local stack. The fixtures were one tenant with an owner, an employee holding SEND_MESSAGE and CREATE_CUSTOMER, a trainee without them and an employee who cannot see the conversation, plus another tenant, two customers, an open WhatsApp conversation and its messages and signals.
  - **CUST-13 (Medium).** The employee rewrote a phone signal, moved another to a second customer, turned an email into a passport number, back-dated one to 2019 and re-set its source, each by UPDATE at the table door, and nothing was recorded. `app.find_customer_duplicates` then warned against the wrong customer and no longer warned against the right one.
  - **CUST-14 (Medium).** A phone `+20 100 765 4321` and an email `Two@CB.test` added at the door were stored as typed. The duplicate check, which compares normalized values, found neither: NORM-1 at a second door.
  - **CHAT-3 (Low).** A message inserted at the table door recorded no event and left its conversation's `updated_at` unmoved, so it was missing from the customer timeline. The same message through the RPC did both.
  - **CHAT-4 (Low).** The same door kept `sent_at` in 2019 and `received_at` a year ahead on one outbound message, and a text of three spaces, where the RPC derives both times and stores none.
  - **Why CHAT-3 and CHAT-4 are Low.** This is CHAT-2's precedent on the same surface, and nothing reads `sent_at` or `received_at` (`app.forbid_message_rewrite` only freezes them).
  - **Why CUST-13 and CUST-14 are Medium, not NORM-1's High.** Identity evidence that misdirects or misses the advisory duplicate warning; the customers uniqueness guard reads `customers`, not signals.
- **The repair: two migrations.**
  - `20261115180000` (CHAT-3, CHAT-4):
    - The signed-in INSERT arm of `app.derive_message_sender`, which already derives the sender (ATTR-4, `202607057000`), also derives `sent_at`, `received_at` and a blank text exactly as the RPC does. A session-less insert keeps its own times, as it keeps its own sender.
    - `app.emit_conversation_message` (AFTER INSERT, SECURITY DEFINER, empty `search_path`, executable by no client role) moves the conversation and records `conversation_message_sent` or `conversation_message_received` with the actor, the message id and its direction, at canon 27's `info`. This is SPEC-215's emitter form.
    - `app.send_conversation_message` no longer moves the conversation or records its own event, so the RPC records once. Its signature, security mode and grant are unchanged.
  - `20261115180100` (CUST-13, CUST-14):
    - UPDATE on `customer_identity_signals` is revoked from `authenticated`, so the grant matches the writers (`202607056100`'s shape). No client path updates a signal, and the merge, which does, is SECURITY DEFINER.
    - `app.normalize_identity_signal` (BEFORE INSERT OR UPDATE OF the value and the type, empty `search_path`, executable by no client role) applies the duplicate reader's own `app.normalize_phone` and `app.normalize_email` on every door. A value that normalizes to nothing is refused by the existing NOT NULL.
  - No policy, constraint, RPC signature or event code changes.
- **`offline_conversion_deliveries` is recorded with no finding.** It has no client write path: SELECT only, and its three writers are executable by `orvion_integration` only (tests 09, 10, 13, 35, 58, 142 and 143).
- **Existing files that move, each for a stated reason.**
  - `_ORVION_CANONICAL/27_event_catalog.md`: what `conversation_message_sent` and `conversation_message_received` record.
  - `reports/master/MASTER_API_CONTRACT.md`: the generated contract moves in exactly two rows. `send_conversation_message` no longer touches `conversations` itself, and `customer_identity_signals` loses its client UPDATE (`SIU-` → `SI--`).
  - No existing test moves.
- **Swept and found sound, pinned rather than changed:**
  - The message sender is derived on the signed-in door, and a closed conversation refuses a message on both doors.
  - A message's text and times are immutable, and no client role deletes a message or a signal, an owner at `aal2` included.
  - Another tenant and an employee who cannot see the conversation are refused and read nothing; the trainee is refused; anonymous REST is refused.
  - No client role reaches a delivery write, over SQL or REST.
- **Recorded positions, not repaired:**
  - A message's `created_at` is caller-supplied on INSERT (SPEC-216's schema-wide question).
  - A message's `external_message_id` and `metadata` stay writable after the insert by design (`app.forbid_message_rewrite`).
  - Signals are readable tenant-wide, as the duplicate check needs, and record no event on any door, the RPC's included.
  - Correcting a wrong signal stays a product question: a new signal is a new row, and nothing deletes one.
  - Deliveries are readable tenant-wide.
- **Latent on Primary.** `vrvtsxexkiiiivlkdxzp` holds 0 tenants, 0 conversation messages, 0 identity signals and 0 deliveries (read-only, 2026-11-15, ledger 265). No stored row is affected and no data repair is needed.

## Risks

- **Trigger order.** The new AFTER INSERT emitter records after the existing BEFORE guards admit the message. The time derivation runs inside the existing BEFORE INSERT sender trigger. The new BEFORE INSERT OR UPDATE normalizer runs beside the existing signal triggers, and the existing triggers are unchanged.
- **A signal can no longer be updated by a client.** The merge, SECURITY DEFINER, still moves signals to the survivor; it updates only the customer, so the normalizer does not fire on it. No existing test updates a signal as a client.
- **A session-less writer keeps its own message times**, as it keeps its own sender: a provider integration replaying a message it received earlier records its real time. Its message is recorded with no actor.
- **Primary deployment is irreversible.** It runs only under the exact-SHA Gate-2 record of Step 9, and approval of this contract does not authorize it. Both migrations deploy in one sitting. If a stop falls between them, the half-deployed state is recorded in the Execution Log when it happens. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions, recorded outside this repository and never as a human-typed digest:
  - class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo
  - publish, promote and hosted deploy, ~12:05 Cairo
  - slice 11 in run mode 1, with the slice's own grouping decision, 2026-11-15 ~19:50 Cairo

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-309-a-conversation-message-is-timed-and-recorded-and-an-identity-signal-is-normalized-and-never-rewritten.md`
- `supabase/migrations/20261115180000_a_conversation_message_is_timed_and_recorded_on_every_door.sql`
- `supabase/migrations/20261115180100_a_customer_identity_signal_is_normalized_and_never_rewritten.sql`
- `supabase/tests/171_a_conversation_message_is_timed_and_recorded_on_every_door_test.sql`
- `supabase/tests/172_a_customer_identity_signal_is_normalized_and_never_rewritten_test.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042100_create_crm_core_tables.sql`
- `supabase/migrations/202607042400_create_crm_extension_tables.sql`
- `supabase/migrations/202607043000_create_marketing_and_offline_conversion_tables.sql`
- `supabase/migrations/202607042600_create_event_and_notification_tables.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `supabase/migrations/202607044800_customer_identity.sql`
- `supabase/migrations/202607044900_merge_customer_identity.sql`
- `supabase/migrations/202607050300_canonical_input_and_catalog_governance.sql`
- `supabase/migrations/202607050900_customer_service_write_paths.sql`
- `supabase/migrations/202607052100_duplicate_prevention.sql`
- `supabase/migrations/202607056100_write_grants_match_the_writers.sql`
- `supabase/migrations/202607057000_capability_on_the_insert_path_and_a_message_that_cannot_be_forged.sql`
- `supabase/migrations/20261007120000_a_conversion_is_sent_only_on_google_success.sql`
- `supabase/tests/17_employee_walkthrough_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/57_write_capability_map_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/67_care_capability_and_message_integrity_test.sql`
- `supabase/tests/71_customer_identity_merge_test.sql`
- `supabase/tests/88_parent_state_on_every_door_test.sql`
- `supabase/tests/111_customer_surface_test.sql`
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
- `supabase/migrations/202607057000_capability_on_the_insert_path_and_a_message_that_cannot_be_forged.sql` (`app.derive_message_sender` and ATTR-4)
- `supabase/migrations/202607050900_customer_service_write_paths.sql` (`app.send_conversation_message`)
- `supabase/migrations/202607044800_customer_identity.sql` and `202607044900_merge_customer_identity.sql` (the signals and the merge)
- `supabase/migrations/202607050300_canonical_input_and_catalog_governance.sql` (`app.normalize_phone`, `app.normalize_email`; NORM-1)
- `supabase/migrations/202607052100_duplicate_prevention.sql` (`app.find_customer_duplicates`)
- `supabase/migrations/202607056100_write_grants_match_the_writers.sql` (the grant shape)
- `changes/SPEC-126-canonical-input-and-catalog-governance.md` (the normalizers)
- `changes/SPEC-215-supplier-creation-is-recorded.md` (the AFTER INSERT emitter form)
- `changes/SPEC-216-document-door-parity.md` (the caller-supplied `created_at` position)
- `changes/SPEC-237-conversion-source-door-parity.md` (door parity)
- `reports/master/MASTER_GAP_REGISTER.md` (CHAT-1, CHAT-2, NORM-1, ATTR-4)
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11

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

Pass 1 Design: Three surfaces are covered in one contract.

- **`conversation_messages`.** The signed-in INSERT arm of the existing sender derivation also derives the times and the blank text; one AFTER INSERT emitter moves the conversation and records every message once; the RPC hands both over.
- **`customer_identity_signals`.** UPDATE is revoked from `authenticated`, and one BEFORE INSERT OR UPDATE normalizer applies the duplicate reader's normalizers on every door.
- **`offline_conversion_deliveries`.** It is recorded with no change.
- **Tests and records.**
  - Test 171 pins the emitter, the derived door times and text, the refused back-dating, the record and the conversation's move on both doors, and a session-less message keeping its time with no actor.
  - Test 172 pins the normalizer, the grants, normalized door signals found by the duplicate check, the refused empty value, move and retype, and the RPC's normalized seed.
  - The register records four new rows, the disposition records the three surfaces, and canon 27 says what the two message events record.

Pass 2 Adversarial Review: The design was challenged on the prototype.

- **Rejected designs:**
  - **Recording the door message's event separately beside the RPC's.** It would record the RPC's messages twice. One emitter is the SPEC-215 form (mutant 171 M3 restores the RPC's own record and is killed).
  - **A refusal trigger on signal UPDATE instead of the revoke.** The merge, SECURITY DEFINER, must still move signals to the survivor; a trigger would bind it too. The revoke binds only client roles, as `202607056100` did (mutant 172 M2 grants UPDATE again and is killed).
  - **A new time trigger beside the sender derivation.** The existing BEFORE INSERT arm already runs on every signed-in door, so the times are derived there, once.
  - **Deriving a session-less message's times too.** A provider integration replays messages with their real times; it keeps them, as it keeps its sender (mutant 171 M6 derives them and is killed).
  - **Copying the selector's next target into the manifest** (SPEC-270; SPEC-278's cancellation).
- **Attacks run on the final bytes.**
  - The probes, as an employee at `aal1`, an owner at `aal2`, a trainee, a non-viewer, another tenant and anonymous REST, close all four findings and hold every swept behavior.
  - Every existing test that touches the three surfaces passes, and so does the full suite.
  - The generated API contract moves in exactly its two rows.

Pass 3 Evidence Refresh: 2026-11-15.

- **Re-measured** on byte-identical files in a disposable clone of `d38eb19`, with the project-local CLI 3.0.0:
  - the clean reset
  - tests 171 and 172 alone, and pgTAP Pass A and B
  - the three declared HTTP suites and smoke
  - the probes, before and after
  - all ten mutants and the two causal negatives
  - the structural fingerprints before and after
  - the API-contract generator (two rows), the map generator and repository consistency
- **Read read-only on hosted.** Primary and Founder Secondary were read for their ledgers, tenants, messages, signals and deliveries.

Selected Version: SPEC-309; selected: the smallest repair that closes CHAT-3, CHAT-4, CUST-13 and CUST-14 (one AFTER INSERT emitter that records every message once and moves its conversation on every door, the RPC handing both over; the signed-in INSERT arm of the existing sender derivation also deriving the times and the blank text as the RPC does; signal UPDATE revoked from authenticated and one normalizer on every door; no policy, RPC signature or event code changed), proven on byte-identical files by the full local protocol, the hostile-role probes before and after, ten killed mutants and the two causal negatives

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A signed-in door message takes its times and text as the RPC's; every message, on every door, moves its conversation and is recorded once | the message door of every SEND_MESSAGE holder; `app.send_conversation_message`; `app.derive_message_sender`; `conversations.updated_at`; readers of `public.events`, `app.customer_timeline` among them; canon 27 | WRITE | Migration SHA-256 `288c93415d7785effd742c3a5dd21a24de7235fdcdc979d031160e560a725146`, md5 `4580e0f416fe029640e1aa363a22d284`, 5574 bytes, LF, ASCII. `md5(prosrc)` of `app.derive_message_sender` is `d45f3cf3bb44c382318781198913d760` (was `59730a817a59ef6ffafa958c1f836118`), still SECURITY INVOKER with its ACL unchanged; of the RPC, `df0036ff85a7dd0cf91a4a396b4a0c15` (was `bdd07290a439bb85d7705db48ccf5b29`), still SECURITY INVOKER with its signature and ACL unchanged. The emitter's is `82c07dd349d70435f528acc3cc9928e6`, SECURITY DEFINER, ACL `{postgres=X/postgres}`. Trigger: `conversation_messages_emit_recorded` AFTER INSERT. The codes `conversation_message_sent` and `conversation_message_received` are unchanged at `info`. Tests 17, 53, 57, 58, 67 and 88 pass unchanged. |
| Every identity signal is stored normalized, on every door, and no client rewrites one | the signal door of every CREATE_CUSTOMER holder; `app.create_customer`; `app.find_customer_duplicates`; `app.merge_customer_identity` | WRITE | Migration SHA-256 `e1a8113e6890e2e8e09c6b9644f6c441a3bca22fdf0f8bbda2fc71cbeff5fec1`, md5 `45c0077a417fc1e450c879c203e32d2e`, 2824 bytes, LF, ASCII. `authenticated` keeps INSERT and SELECT and loses UPDATE. The normalizer's `md5(prosrc)` is `c057ff319168853ff728be3bb26b62b3`, SECURITY INVOKER, ACL `{postgres=X/postgres}`. Trigger: `customer_identity_signals_normalize_value` BEFORE INSERT OR UPDATE OF `signal_value`, `signal_type_code`. The merge still moves signals. Tests 57, 58, 71, 79, 87, 89 and 111 pass unchanged. |
| Deliveries | `offline_conversion_deliveries`; `app.claim_conversion_deliveries`; `app.record_conversion_ingestion`; `app.record_conversion_provider_status` | UNAFFECTED | No grant, policy, trigger or writer changes. Tests 09, 10, 13, 35, 58, 142 and 143 pass unchanged. |
| A clean reset holds both | the local stack; `supabase_migrations.schema_migrations` | WRITE | A clean reset gives 267 migrations, latest `20261115180100`, ledger `8be9389fce4d3f330674d2ed083278ca`. `conversation_messages` carries 7 triggers (was 6), `customer_identity_signals` 4 (was 3) and `offline_conversion_deliveries` 1. Catalog 71/626. |
| Tests 171 and 172 | `supabase/tests` | WRITE | Test 171: SHA-256 `10768ec5c1e26cd15e5b71fe4d8fbe6891b8451627941b7c48e4ccdb5107bc65`, md5 `03ec7ff7e2e8f7d28e573e04c38a7df5`, 7940 bytes, `plan(11)`: 11/11. Test 172: SHA-256 `45acbf3c337c55e75ea67ca2156daec208a5694e94e39875f8ceb6136087b06d`, md5 `93b76a89ce103769c1b4d5af0bb7fa80`, 6829 bytes, `plan(10)`: 10/10. Each LF, ASCII. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=172, Tests=3193`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 172/3193, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/626 catalog). The 172 files' literal `plan(N)` values sum to 3193. No existing test and no line of `scripts/verify_database.sql` moves. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (265): functions `58dc8cf1aaec56b1ba63eabf7391ac0a`/347, triggers `b4a4d2babd4fa85cf46268d2b934268a`/334, grants `6727f6d89168b7aec4c06f131bef75bc`/189, `_combined` `aeb5931b5df96106439433dce07cfe2a`/3172, equal to the recorded Primary evidence. After (267, local): functions `b13e66125d5ea63134310305faf3ee7e`/349 (+2), triggers `246b4ca76492cd46629f538f2ed1b108`/336 (+2), grants `5cfb09c3344a26c5513989ef3c358ff1`/188 (-1), `_combined` `88c35cab62c01ed7433d57402c8ee72c`/3175. Policies, constraints, columns, views, indexes, status transitions and RLS are unchanged. Step 11 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3); `scripts/generate-api-contract.ps1` | WRITE | No RPC is added or removed, and no signature or EXECUTE grant changes. On the final bytes the generator's output differs from the baseline contract in exactly two rows: `send_conversation_message` no longer lists `conversations` among the tables it touches, and `customer_identity_signals` reads `SI--` (was `SIU-`). The committed contract equals the generator's output. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 265 → 267 migrations, latest `20261115180100`, ledger fingerprint `8be9389fce4d3f330674d2ed083278ca`; 170 → 172 files and 3172 → 3193 assertions; coverage 57 → 60 of 78. Tables (78) and client RPCs (80) do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 12 names `Current Module` and `Next capability` only to leave them unchanged. Each line keeps its ratified text and pin. |
| CHAT-3, CHAT-4, CUST-13 and CUST-14 fixed; three surfaces recorded; canon 27 | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `27_event_catalog.md`; Checks 21, 22, 24, 25, 29 | WRITE | No CHAT-3, CHAT-4, CUST-13 or CUST-14 row exists at `d38eb19`. Tests 171 and 172 each declare the ten classes with their N/A classes reasoned and carry negative assertions; 171 names `conversation_messages` and 172 names `customer_identity_signals`, and test 143 names `offline_conversion_deliveries`, so Check 24 admits `ADVERSARIAL` for all three. Each new row has Owner `—` and is settled. Coverage 60: 36 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 18 `NOT-RECORDED`; all 60 `ADVERSARIAL`. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–7 applied and the contract present, consistency reports exactly the measured-state items: 265 vs 267 migrations, the latest version, the ledger fingerprint, 170 vs 172 files, 3172 vs 3193 assertions, and the Primary-evidence record. Checks 21–29 pass. Step 11 makes the measured-state items true, and the one implementation commit is made only after it. |
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
| The map and the API contract match their generators | BEFORE_COMPLETION | Step 1 | Step 11 | Step 12 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: Nothing records a door message, takes a signed-in door message's times from the clock, normalizes a door signal, or keeps a client from rewriting a signal.

- `app.send_conversation_message` records and moves its own messages only, and stamps only its own times.
- `app.derive_message_sender` derives the sender, not the times or the text.
- `app.forbid_message_rewrite` freezes a message after its insert, not what the insert says.
- `app.create_customer` normalizes only its own signals; the signals' check requires a trimmed value, not a normalized one.
- `app.guard_write_capability` decides who may write a signal, not whether a written signal may change.

Added Property: For every signed-in writer:

- every conversation message is recorded once with its actor and moves its conversation, and its times are the clock's;
- every identity signal is stored as the duplicate check normalizes it;
- no client changes a signal after it is written.

A session-less message keeps its own times and is recorded with no actor.

Causal Negative: On the `d38eb19` schema (the stack reset to `20261114170000`), test 171 fails assertions 1, 3–7 and 11, and test 172 fails 1, 2, 4–8 and 10. They fail the same assertions with the pre-repair sender derivation and RPC restored, the two new triggers removed and UPDATE granted again: 171 fails 1, 3–7 and 11 and 172 fails 1, 2, 4–8 and 10, the same set both ways. There, the probes record no door message, keep a caller's times and a blank text, store door signals as typed, and accept a signal moved, retyped and back-dated by UPDATE.

Positive Test Design: One tenant with a Giza branch, a sales department, an employee and an owner, two customers and an open WhatsApp conversation two days old. Positive controls:

- a door message and an RPC message are each recorded once, and the conversation moves to now;
- an inbound door message with a blank text is stored with none and recorded as received;
- a session-less message keeps its time and is recorded with no actor;
- a door phone and email are stored normalized and found by the duplicate check;
- the RPC's own phone is seeded normalized.

Negative Test Design: by attack class, as follows.
- **Door:** a message or a signal written at the table door is timed, normalized and recorded like one written through the RPC.
- **Input:** a caller's `sent_at` in 2019, a `received_at` a year ahead and a blank text are replaced by the clock and none; a phone `( - )` that normalizes to nothing is refused (23502).
- **Privilege:** the emitter is SECURITY DEFINER with no client EXECUTE; `authenticated` holds INSERT and SELECT on signals but not UPDATE or DELETE; an employee cannot move a signal to another customer and an owner at `aal2` cannot retype one (42501).
- **Observability:** the RPC's message is recorded once, the door's with its actor and direction.
- **State:** the employee cannot back-date the derived time afterwards (42501, the unchanged rewrite guard).
- **Auth, tenant, concurrency, replay and business:** the existing guards cover these, unchanged (tests 57, 58, 67, 88 and 111).

Non-Empty Population Obligation: Each test's fixture holds its tenant, branch, department, users, roles and rows before the first assertion: in 171 an open conversation and its customer, and in 172 two customers, an employee and an owner. Each refusal is asserted by its SQLSTATE, and each record by its exact fields.

Mutation Obligation: Each mutant is installed inside its test's own rolled-back transaction, proven installed by a diag line (the md5 of the slice functions, the table's trigger count and the signal UPDATE grant), run, and rolled back. The restored shape is read after the last mutant. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| 171 M1 | the emitter trigger dropped | 171 assertions 1, 4, 5, 7, 8 and 11 |
| 171 M2 | the emitter does not move the conversation | 171 assertion 5 |
| 171 M3 | the RPC's pre-repair body: it records too | 171 assertion 8 |
| 171 M4 | the door times not derived | 171 assertions 3, 6 and 7 |
| 171 M5 | the blank text kept | 171 assertions 6 and 7 |
| 171 M6 | a session-less message's times derived too | 171 assertion 10 |
| 172 M1 | the normalizer trigger dropped | 172 assertions 1, 4, 5, 6 and 10 |
| 172 M2 | UPDATE granted to `authenticated` again | 172 assertions 2, 7, 8 and 10 |
| 172 M3 | the phone not normalized | 172 assertions 4, 5, 6 and 10 |
| 172 M4 | the email not normalized | 172 assertions 4, 5 and 10 |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI:

- the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the generated artifacts, repository consistency and the recorded Primary evidence.

Before Step 10: the focused tests, the probes, the mutants, the causal negatives and the fresh Primary baseline of Step 8.

## Implementation Steps

1. Check whether `supabase/migrations/20261115180000_a_conversation_message_is_timed_and_recorded_on_every_door.sql` contains `CHAT-3, CHAT-4 -- Batch 6 slice 11`; if so record Already Applied when its Git blob is 0a0feaaca957fe7593dc68c677775299d20324b8, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the message migration: the derived door times and text, the emitter, the RPC's hand-over), and change nothing else:

   ```text
   -- CHAT-3, CHAT-4 -- Batch 6 slice 11 (`conversation_messages`).
   --
   -- THE RULE. A message is sent or received inside a conversation. `app.send_conversation_message`
   -- stamps its time from the clock (`sent_at` for outbound, `received_at` for inbound), stores a blank
   -- text as none, moves the conversation's `updated_at` and records `conversation_message_sent` or
   -- `conversation_message_received`. `authenticated` holds table-level INSERT beside the RPC, and
   -- PostgREST serves it. Measured before this migration (local stack, an `employee` holding
   -- SEND_MESSAGE, at aal1 as that role allows):
   --   CHAT-3  a message inserted at the table door added no event and left its conversation's
   --           `updated_at` where it was, where the RPC's did both: a conversation could change with
   --           no record and without rising in any list ordered by activity;
   --   CHAT-4  the same door accepted `sent_at` 2019 and `received_at` 2099 on one outbound message,
   --           and kept a text of three spaces, where the RPC derives both times and stores none.
   --
   -- THE REPAIR, in existing shapes. The signed-in INSERT arm of `app.derive_message_sender`, which
   -- already derives the sender (ATTR-4, `202607057000`), now also derives the two times and the blank text exactly
   -- as the RPC does; a session-less insert (a provider integration replaying a message it received
   -- earlier) keeps its own times, as it keeps its own sender. One AFTER INSERT trigger is the single
   -- producer of the event and of the conversation's move (SPEC-215's shape, slice 10's
   -- `internal_supplier_links_emit_linked`), so the RPC loses its own `update` and `record_event`,
   -- which would otherwise record every RPC message twice. The actor is `app.current_user_id()`: the
   -- session's user, or none on a session-less path.
   --
   -- NOT CHANGED: every grant, policy and constraint; the sender, parent-state, rewrite and
   -- capability guards; the event's types, entity, severity and payload keys; and every other line of
   -- `app.send_conversation_message`. A message's caller-supplied `created_at` on INSERT stays a
   -- recorded position (SPEC-216's question, as slices 7-10), and `external_message_id` and `metadata`
   -- stay writable after the insert by design (`app.forbid_message_rewrite`).
   create or replace function app.derive_message_sender()
    RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
   AS $function$
   begin
       if (select auth.uid()) is null then
           return new;
       end if;
       if tg_op = 'INSERT' then
           new.sender_user_id := app.current_user_id();
           -- The RPC's derivation, on every signed-in door (CHAT-4).
           new.message_text := nullif(btrim(new.message_text), '');
           new.sent_at := case when new.message_direction_code = 'inbound' then null else now() end;
           new.received_at := case when new.message_direction_code = 'inbound' then now() else null end;
       else
           new.sender_user_id := old.sender_user_id;   -- immutable
       end if;
       return new;
   end
   $function$;

   create or replace function app.send_conversation_message(p_conversation_id uuid, p_message_direction_code text, p_sender_type_code text, p_body text DEFAULT NULL::text)
    RETURNS uuid
    LANGUAGE plpgsql
    SET search_path TO ''
   AS $function$
   declare
       v_tenant uuid := app.current_tenant_id();
       v_actor uuid;
       v_id uuid;
       v_status text;
   begin
       if v_tenant is null then raise exception 'no active tenant for caller'; end if;
       perform app.authorize('SEND_MESSAGE');

       select conversation_status_code into v_status
       from public.conversations where id = p_conversation_id and tenant_id = v_tenant;
       if v_status is null then raise exception 'conversation not found in your tenant'; end if;
       if v_status = 'closed' then
           raise exception 'conversation is closed; reopen it before sending a message'; end if;

       select id into v_actor from public.users
       where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

       -- Its event and the conversation's move are recorded by `conversation_messages_emit_recorded`
       -- on every door (CHAT-3).
       insert into public.conversation_messages (
           tenant_id, conversation_id, sender_type_code, message_direction_code, message_text,
           sender_user_id, sent_at, received_at
       ) values (
           v_tenant, p_conversation_id, p_sender_type_code, p_message_direction_code,
           nullif(btrim(p_body), ''), v_actor,
           case when p_message_direction_code = 'inbound' then null else now() end,
           case when p_message_direction_code = 'inbound' then now() else null end
       ) returning id into v_id;

       return v_id;
   end;
   $function$;

   create or replace function app.emit_conversation_message()
   returns trigger
   language plpgsql
   security definer
   set search_path to ''
   as $fn$
   begin
       update public.conversations set updated_at = now()
       where id = new.conversation_id and tenant_id = new.tenant_id;

       perform app.record_event(
           new.tenant_id,
           case when new.message_direction_code = 'inbound'
                then 'conversation_message_received' else 'conversation_message_sent' end,
           'conversation', new.conversation_id, app.current_user_id(), null, null, null,
           jsonb_build_object('message_id', new.id, 'direction', new.message_direction_code),
           'info');
       return null;
   end;
   $fn$;

   revoke execute on function app.emit_conversation_message() from public;

   create trigger conversation_messages_emit_recorded
       after insert on public.conversation_messages
       for each row execute function app.emit_conversation_message();
   ```

   The resulting file's Git blob is 0a0feaaca957fe7593dc68c677775299d20324b8.

2. Check whether `supabase/migrations/20261115180100_a_customer_identity_signal_is_normalized_and_never_rewritten.sql` contains `CUST-13, CUST-14 -- Batch 6 slice 11`; if so record Already Applied when its Git blob is 56daf0d42f6b21d7bdb4956d540ee67dd3328c17, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the signal migration: UPDATE revoked and the normalizer on every door), and change nothing else:

   ```text
   -- CUST-13, CUST-14 -- Batch 6 slice 11 (`customer_identity_signals`).
   --
   -- THE RULE. A signal is a phone, WhatsApp number, email or document number by which a customer was
   -- identified; `app.find_customer_duplicates` reads them to warn before a second record of the same
   -- person is created. `app.create_customer` writes them, normalized (`app.normalize_phone`,
   -- `app.normalize_email`), and only ever INSERTs; `app.merge_customer_identity` (SECURITY DEFINER)
   -- moves them to the survivor. `authenticated` holds table-level INSERT and UPDATE, and PostgREST
   -- serves both. Measured before this migration (local stack, an `employee` holding CREATE_CUSTOMER,
   -- at aal1 as that role allows):
   --   CUST-13  an UPDATE moved a phone signal from one customer to another and turned an email signal
   --            into a passport number, unrecorded: the duplicate check then warned against the wrong
   --            customer and no longer warned against the right one;
   --   CUST-14  a phone inserted at the door as `+20 100 765 4321` and an email as `Two@CB.test` were
   --            stored as typed, so the duplicate check, which compares normalized values, never matched
   --            them.
   --
   -- THE REPAIR, in existing shapes. UPDATE is revoked from `authenticated`, so the grant matches the
   -- writers, as `202607056100_write_grants_match_the_writers` did for the tables no invoker writes:
   -- no client path updates a signal, and the merge, which does, is SECURITY DEFINER. One BEFORE INSERT
   -- OR UPDATE OF the value trigger applies the duplicate reader's own normalization on every door, so a
   -- stored signal and a searched value always compare alike; a value that normalizes to nothing is
   -- refused by the existing NOT NULL, as the RPC never stores one.
   --
   -- NOT CHANGED: the INSERT and SELECT grants, the policy, the check, the foreign keys and the
   -- capability guard; `app.create_customer`, `app.find_customer_duplicates` and the merge. Correcting a
   -- wrong signal stays a product question (a new signal is a new row; nothing deletes one).
   revoke update on public.customer_identity_signals from authenticated;

   create or replace function app.normalize_identity_signal()
   returns trigger
   language plpgsql
   set search_path to ''
   as $fn$
   begin
       new.signal_value := case
           when new.signal_type_code in ('phone', 'whatsapp') then app.normalize_phone(new.signal_value)
           when new.signal_type_code = 'email' then app.normalize_email(new.signal_value)
           else new.signal_value end;
       return new;
   end;
   $fn$;

   revoke execute on function app.normalize_identity_signal() from public;

   create trigger customer_identity_signals_normalize_value
       before insert or update of signal_value, signal_type_code on public.customer_identity_signals
       for each row execute function app.normalize_identity_signal();
   ```

   The resulting file's Git blob is 56daf0d42f6b21d7bdb4956d540ee67dd3328c17.

3. Check whether `supabase/tests/171_a_conversation_message_is_timed_and_recorded_on_every_door_test.sql` contains `plan(11)`; if so record Already Applied when its Git blob is 169dd0faab469bf43117c50974277a27bb1b3a2d, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 171, 11 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 53 (conversation_messages, CHAT-3 and CHAT-4) --
   -- a conversation message is timed and recorded on every door (`20261115180000`).
   -- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE=N/A BUSINESS=N/A OBSERVABILITY
   --   AUTH=N/A -- SEND_MESSAGE is the unchanged capability guard (tests 57, 58, 67).
   --   TENANT=N/A -- tenant and parent visibility are the unchanged policy (tests 67, 88).
   --   STATE=N/A -- a closed conversation is the unchanged parent-state guard (test 88).
   --   CONCURRENCY, REPLAY=N/A -- each message is its own row; sending twice is two messages, as through the RPC.
   --   PRIVILEGE=N/A -- no grant changes; the sender and rewrite guards are unchanged (test 67).
   --   BUSINESS=N/A -- a message carries no money.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(11);

   insert into auth.users (id, email) values
     ('17100000-0000-0000-0000-0000000000a1','employee@c171.test');
   insert into public.tenants (id, name, slug, status) values
     ('17100000-0000-0000-0000-000000000001','Message Travel','message-travel-171','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '17100000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('17100000-0000-0000-0000-00000000000a','17100000-0000-0000-0000-000000000001','Giza','giza-171');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('17100000-0000-0000-0000-0000000000c1','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-00000000000a','sales','Giza Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('17100000-0000-0000-0000-000000000011','17100000-0000-0000-0000-000000000001','Employee','employee@c171.test',true,'17100000-0000-0000-0000-0000000000a1');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-000000000011','17100000-0000-0000-0000-00000000000a','17100000-0000-0000-0000-0000000000c1',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '17100000-0000-0000-0000-000000000001', '17100000-0000-0000-0000-000000000011', r.id, 'tenant'
   from public.roles r where r.code = 'employee';
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('17100000-0000-0000-0000-0000000000d1','17100000-0000-0000-0000-000000000001','person','Message Customer');
   insert into public.conversations (id, tenant_id, customer_id, owner_user_id, owner_branch_id, owner_department_id,
                                     current_branch_id, current_department_id, channel_code, conversation_status_code,
                                     created_at, updated_at) values
     ('17100000-0000-0000-0000-0000000000f1','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-0000000000d1',
      '17100000-0000-0000-0000-000000000011','17100000-0000-0000-0000-00000000000a','17100000-0000-0000-0000-0000000000c1',
      '17100000-0000-0000-0000-00000000000a','17100000-0000-0000-0000-0000000000c1','whatsapp','open',
      now() - interval '2 days', now() - interval '2 days');

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.conversation_messages'::regclass and not tgisinternal
        and tgname = 'conversation_messages_emit_recorded'),
     1, 'the emitter is installed on conversation_messages');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"17100000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

   select lives_ok(
     $$insert into public.conversation_messages (id, tenant_id, conversation_id, sender_type_code, message_direction_code,
                                                 message_text, sent_at, received_at)
       values ('17100000-0000-0000-0000-0000000000e1','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-0000000000f1',
               'user','outbound','  door  ','2019-01-01',now() + interval '1 year')$$,
     'an employee sends a message at the table door, naming 2019 and a year ahead');
   select throws_ok(
     $$update public.conversation_messages set sent_at = '2019-01-01'
       where id = '17100000-0000-0000-0000-0000000000e1'$$,
     '42501', null, 'CHAT-4: the employee cannot back-date the derived time afterwards');

   reset role;
   select is(
     (select count(*)::int from public.events e join public.users u on u.id = e.actor_user_id
      where e.event_type_code = 'conversation_message_sent' and u.full_name = 'Employee'
        and e.entity_type = 'conversation' and e.entity_id = '17100000-0000-0000-0000-0000000000f1'
        and e.payload ->> 'message_id' = '17100000-0000-0000-0000-0000000000e1' and e.payload ->> 'direction' = 'outbound'),
     1, 'CHAT-3: the door message is recorded once, by its actor, on its conversation');
   select ok(
     (select updated_at = now() from public.conversations where id = '17100000-0000-0000-0000-0000000000f1'),
     'CHAT-3: the door message moves its conversation');
   select is(
     (select message_text || ' sent=' || (sent_at = now()) || ' recv=' || coalesce(received_at::text, 'none')
      from public.conversation_messages where id = '17100000-0000-0000-0000-0000000000e1'),
     'door sent=true recv=none', 'CHAT-4: the door message''s times and text are derived, not supplied');
   set local role authenticated;

   insert into public.conversation_messages (id, tenant_id, conversation_id, sender_type_code, message_direction_code,
                                             message_text, sent_at)
   values ('17100000-0000-0000-0000-0000000000e2','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-0000000000f1',
           'customer','inbound','   ','2019-01-01');
   create temp table rpc_msg on commit drop as
   select app.send_conversation_message('17100000-0000-0000-0000-0000000000f1', 'outbound', 'user', '  hi  ') as id;

   reset role;
   select is(
     (select coalesce(m.message_text, 'none') || ' sent=' || coalesce(m.sent_at::text, 'none') || ' recv=' || (m.received_at = now())
             || ' events=' || (select count(*) from public.events e where e.event_type_code = 'conversation_message_received'
                                and e.payload ->> 'message_id' = m.id::text)
      from public.conversation_messages m where m.id = '17100000-0000-0000-0000-0000000000e2'),
     'none sent=none recv=true events=1', 'an inbound door message is received now, holds no blank text and is recorded as received');
   select is(
     (select count(*)::int from public.events where payload ->> 'message_id' = (select id from rpc_msg)::text),
     1, 'the RPC message is recorded once, not twice');
   select is(
     (select message_text || ' sent=' || (sent_at = now()) from public.conversation_messages where id = (select id from rpc_msg)),
     'hi sent=true', 'the RPC message keeps its trimmed text and its time');

   select set_config('request.jwt.claims', null, true);
   insert into public.conversation_messages (id, tenant_id, conversation_id, sender_type_code, message_direction_code,
                                             message_text, received_at)
   values ('17100000-0000-0000-0000-0000000000e3','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-0000000000f1',
           'customer','inbound','replayed','2026-01-01');
   select is(
     (select received_at::date::text from public.conversation_messages where id = '17100000-0000-0000-0000-0000000000e3'),
     '2026-01-01', 'a session-less integration keeps the time it received the message');
   select is(
     (select count(*)::int from public.events
      where payload ->> 'message_id' = '17100000-0000-0000-0000-0000000000e3' and actor_user_id is null),
     1, 'a session-less message is recorded too, with no actor');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 169dd0faab469bf43117c50974277a27bb1b3a2d.

4. Check whether `supabase/tests/172_a_customer_identity_signal_is_normalized_and_never_rewritten_test.sql` contains `plan(10)`; if so record Already Applied when its Git blob is 8336f5c1d946c0b7b8b179499bbf57c558918345, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 172, 10 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 53 (customer_identity_signals, CUST-13 and CUST-14) --
   -- a customer identity signal is normalized and never rewritten (`20261115180100`).
   -- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
   --   AUTH=N/A -- CREATE_CUSTOMER is the unchanged capability guard (tests 57, 58).
   --   TENANT=N/A -- tenant isolation is the unchanged policy and composite foreign keys.
   --   STATE=N/A -- a signal has no state.
   --   CONCURRENCY, REPLAY=N/A -- each signal is its own row; adding one twice is two signals, as through the RPC.
   --   BUSINESS=N/A -- a signal carries no money.
   --   OBSERVABILITY=N/A -- signals record no event on any door, the RPC's included; the customer's creation is recorded.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(10);

   insert into auth.users (id, email) values
     ('17200000-0000-0000-0000-0000000000a1','employee@c172.test'),
     ('17200000-0000-0000-0000-0000000000a2','owner@c172.test');
   insert into public.tenants (id, name, slug, status) values
     ('17200000-0000-0000-0000-000000000001','Signal Travel','signal-travel-172','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '17200000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('17200000-0000-0000-0000-00000000000a','17200000-0000-0000-0000-000000000001','Giza','giza-172');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('17200000-0000-0000-0000-0000000000c1','17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-00000000000a','sales','Giza Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('17200000-0000-0000-0000-000000000011','17200000-0000-0000-0000-000000000001','Employee','employee@c172.test',true,'17200000-0000-0000-0000-0000000000a1'),
     ('17200000-0000-0000-0000-000000000012','17200000-0000-0000-0000-000000000001','Owner','owner@c172.test',true,'17200000-0000-0000-0000-0000000000a2');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-000000000011','17200000-0000-0000-0000-00000000000a','17200000-0000-0000-0000-0000000000c1',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '17200000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
   from (values ('17200000-0000-0000-0000-000000000011'::uuid, 'employee'), ('17200000-0000-0000-0000-000000000012', 'owner')) v(u, c)
   join public.roles r on r.code = v.c;
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('17200000-0000-0000-0000-0000000000d1','17200000-0000-0000-0000-000000000001','person','Signal One'),
     ('17200000-0000-0000-0000-0000000000d2','17200000-0000-0000-0000-000000000001','person','Signal Two');

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.customer_identity_signals'::regclass and not tgisinternal
        and tgname = 'customer_identity_signals_normalize_value'),
     1, 'the normalizer is installed on customer_identity_signals');
   select is(
     (select string_agg(p || '=' || has_table_privilege('authenticated', 'public.customer_identity_signals', p), ' ' order by p)
      from unnest(array['DELETE', 'INSERT', 'SELECT', 'UPDATE']) p),
     'DELETE=false INSERT=true SELECT=true UPDATE=false', 'CUST-13: authenticated may add and read a signal, never rewrite or delete one');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"17200000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

   select lives_ok(
     $$insert into public.customer_identity_signals (id, tenant_id, customer_id, signal_type_code, signal_value) values
       ('17200000-0000-0000-0000-0000000000e1','17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-0000000000d2','phone','+20 100 765 4321'),
       ('17200000-0000-0000-0000-0000000000e2','17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-0000000000d2','email','Two@CB.test')$$,
     'an employee adds a raw phone and a mixed-case email at the table door');
   select is(
     (select string_agg(signal_type_code || ':' || signal_value, ',' order by signal_type_code)
      from public.customer_identity_signals where customer_id = '17200000-0000-0000-0000-0000000000d2'),
     'email:two@cb.test,phone:+201007654321', 'CUST-14: the door stores each value as the duplicate reader compares it');
   select is(
     (select string_agg(matched_signal_type, ',' order by matched_signal_type)
      from app.find_customer_duplicates(p_phone => '+201007654321', p_email => 'two@cb.test')
      where customer_id = '17200000-0000-0000-0000-0000000000d2'),
     'email,phone', 'CUST-14: the duplicate check finds the customer by both');
   select throws_ok(
     $$insert into public.customer_identity_signals (tenant_id, customer_id, signal_type_code, signal_value)
       values ('17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-0000000000d2','phone','( - )')$$,
     '23502', null, 'a phone that normalizes to nothing is refused, as the RPC never stores one');

   select throws_ok(
     $$update public.customer_identity_signals set customer_id = '17200000-0000-0000-0000-0000000000d1'
       where id = '17200000-0000-0000-0000-0000000000e1'$$,
     '42501', null, 'CUST-13: an employee cannot move a signal to another customer');
   select set_config('request.jwt.claims', '{"sub":"17200000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select throws_ok(
     $$update public.customer_identity_signals set signal_type_code = 'passport_number'
       where id = '17200000-0000-0000-0000-0000000000e2'$$,
     '42501', null, 'CUST-13: the owner at aal2 cannot turn an email signal into a passport number');

   select set_config('request.jwt.claims', '{"sub":"17200000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
   create temp table rpc_customer on commit drop as
   select app.create_customer('person', 'RPC Three', p_primary_phone => ' +20 (100) 555-0000 ') as id;
   select is(
     (select string_agg(signal_type_code || ':' || signal_value, ',') from public.customer_identity_signals
      where customer_id = (select id from rpc_customer)),
     'phone:+201005550000', 'the RPC still seeds its normalized signal');

   reset role;
   select is(
     (select string_agg(signal_type_code || ':' || signal_value, ',' order by signal_type_code)
      from public.customer_identity_signals where customer_id = '17200000-0000-0000-0000-0000000000d2'),
     'email:two@cb.test,phone:+201007654321', 'CUST-13: both signals stay on the customer they were added to');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 8336f5c1d946c0b7b8b179499bbf57c558918345.

5. Check whether `_ORVION_CANONICAL/27_event_catalog.md` contains `Created by every outbound conversation message`; if so record Already Applied when its Git blob is 674b32d83e880da1ddbb9dfe7a0e04f2e22eae7c, and otherwise stop and report. Otherwise make exactly these 2 edits (the two conversation message entries: what they record), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   ## conversation_message_received

   Severity: info

   ```
   insert
   ```text
   Created by every inbound conversation message, through `app.send_conversation_message` or the table door, on its conversation, with the actor (none on a session-less integration path), the message id and its direction; the conversation's `updated_at` moves with it (CHAT-3, SPEC-309). On a signed-in door the message's time is the clock's, never the caller's (CHAT-4).

   ```

   b) immediately after the lines
   ```text
   ## conversation_message_sent

   Severity: info

   ```
   insert
   ```text
   Created by every outbound conversation message, through `app.send_conversation_message` or the table door, on its conversation, with the actor (none on a session-less integration path), the message id and its direction; the conversation's `updated_at` moves with it (CHAT-3, SPEC-309). On a signed-in door the message's time is the clock's, never the caller's (CHAT-4).

   ```

   The resulting file's Git blob is 674b32d83e880da1ddbb9dfe7a0e04f2e22eae7c.

6. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| CUST-13 |`; if so record Already Applied when its Git blob is adf596562e468af6e7a721829a0ab737b905662f, and otherwise stop and report. Otherwise make exactly these 2 edits (the Slice 53 freshness entry and four new rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-14 (**Slice 52 — `events`, `scheduled_job_findings` and `internal_supplier_links` selected live at Exposure 6 and 5, coverage 400, 18 and 18, in one contract (P1's grouping, 2026-11-14).** **CONV-11** (Medium) and **ISL-1** and **ISL-2** (Low) are new and fixed. A conversion source event that committed after a later one was never mapped, because the mapper's seq cursor had already passed it; an internal supplier link made at the table door was not recorded, and a link's provider, item and date were rewritten in place unrecorded. SPEC-308 keeps the mapper behind every open source writer, records every link on every door, and makes the links append-only. `scheduled_job_findings` was audited with no finding. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-15 (**Slice 53 — `conversation_messages`, `customer_identity_signals` and `offline_conversion_deliveries` selected live at Exposure 5, coverage 24, 24 and 34, in one contract (P1's grouping, 2026-11-15).** **CUST-13** and **CUST-14** (Medium) and **CHAT-3** and **CHAT-4** (Low) are new and fixed. A customer identity signal was rewritten, moved or retyped at the table door unrecorded, and a signal added there was stored as typed, so the duplicate check misread or missed it; a message inserted at the table door was not recorded, did not move its conversation, and kept caller-supplied times and a blank text. SPEC-309 normalizes every signal on every door and makes signals un-rewritable by any client, and derives and records every signed-in message on every door. `offline_conversion_deliveries` was audited with no finding. No other row changed.)

   Previously: 2026-11-14 (**Slice 52 — `events`, `scheduled_job_findings` and `internal_supplier_links` selected live at Exposure 6 and 5, coverage 400, 18 and 18, in one contract (P1's grouping, 2026-11-14).** **CONV-11** (Medium) and **ISL-1** and **ISL-2** (Low) are new and fixed. A conversion source event that committed after a later one was never mapped, because the mapper's seq cursor had already passed it; an internal supplier link made at the table door was not recorded, and a link's provider, item and date were rewritten in place unrecorded. SPEC-308 keeps the mapper behind every open source writer, records every link on every door, and makes the links append-only. `scheduled_job_findings` was audited with no finding. No other row changed.)
   ```

   b) immediately after the line
   ```text
   | ISL-2 | **A link's provider, booking item and date were rewritten in place, and nothing was recorded** | integrity · audit completeness | Low | R | 6 | M | ✅ | **✅ FIXED 2026-11-14 (SPEC-308, `20261114170000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-308; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `ca2c189`: the same senior re-pointed a link's provider from one branch to another, moved the link to another booking item, and back-dated it to 2019, each by UPDATE, and nothing was recorded. `app.link_internal_supplier` describes the table as append-only (history preserved; the latest row is the current provider) and SUP-1 calls it an append-only log, but nothing enforced it: the table carries an UPDATE grant and no guard of its own. Severity is Low by SUP-1's measured reason, re-measured at `ca2c189`: nothing reads the table but its RPC and `app.guard_write_capability`. **Repaired:** `app.emit_internal_supplier_linked` (AFTER INSERT, SECURITY DEFINER, empty `search_path`, executable by no client role) records every link, through the RPC or the table door, as `internal_supplier_linked` with the actor, the link id and both org units; `app.link_internal_supplier` no longer records its own and hands its reason over through `app.transition_reason` (SPEC-237's pattern), which the emitter consumes, so the RPC records once. `internal_supplier_links_append_only` (BEFORE UPDATE OR DELETE, `app.forbid_mutation`) makes the table append-only for every writer: a new provider is a new link. `170_an_internal_supplier_link_is_appended_and_recorded_on_every_door_test.sql` pins both. | — | SPEC-308-a-late-conversion-source-is-mapped-and-a-supplier-link-is-kept-and-recorded | 11-14 | 11-14 |
   ```
   insert
   ```text
   | CUST-13 | **An identity signal was rewritten, moved to another customer or retyped in place, unrecorded, and the duplicate check then warned against the wrong customer** | CRM identity · integrity · audit completeness | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-15 locally (SPEC-309, `20261115180100`); Primary deployment pending.** **MEASURED** at `d38eb19`: an `employee` holding CREATE_CUSTOMER, at `aal1` as that role allows, rewrote a customer's phone signal, moved another phone signal to a second customer, turned an email signal into a passport number, back-dated a signal to 2019 and re-set its source, each by UPDATE at the table door, and nothing was recorded. `app.find_customer_duplicates` reads these rows to warn before a second record of the same person is created: it then warned against the wrong customer and no longer against the right one. `app.create_customer` only ever inserts a signal and `app.merge_customer_identity` (SECURITY DEFINER) is the only writer that moves one, yet `authenticated` held table-level UPDATE and the table had no rewrite guard. Severity is Medium: an unrecorded rewrite of identity evidence that misdirects the duplicate warning; not NORM-1's High, because the customers uniqueness guard reads `customers`, not signals. **Repaired:** UPDATE is revoked from `authenticated`, so the grant matches the writers (`202607056100`'s shape): no client path updates a signal, and `app.merge_customer_identity`, which moves them, is SECURITY DEFINER. `app.normalize_identity_signal` (BEFORE INSERT OR UPDATE OF the value and type) applies the duplicate reader's own `app.normalize_phone` and `app.normalize_email` on every door, so a stored signal and a searched value always compare alike; a value that normalizes to nothing is refused by the existing NOT NULL, as the RPC never stores one. `172_a_customer_identity_signal_is_normalized_and_never_rewritten_test.sql` pins both. | — | SPEC-309-a-conversation-message-is-timed-and-recorded-and-an-identity-signal-is-normalized-and-never-rewritten | 11-15 | 11-15 |
   | CUST-14 | **A signal added at the table door was stored as typed, so the duplicate check, which compares normalized values, never matched it** | CRM identity · data integrity | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-15 locally (SPEC-309, `20261115180100`); Primary deployment pending.** **MEASURED** at `d38eb19`: the same employee added a phone as `+20 100 765 4321` and an email as `Two@CB.test` at the table door; both were stored as typed and `app.find_customer_duplicates` found neither, while the same values through `app.create_customer` are stored normalized and found. This is NORM-1's defect (SPEC-126 normalized the single write path) recurring at the second door. Severity is Medium, below NORM-1's High: it misses only the advisory duplicate warning and does not defeat the customers uniqueness guard. **Repaired:** UPDATE is revoked from `authenticated`, so the grant matches the writers (`202607056100`'s shape): no client path updates a signal, and `app.merge_customer_identity`, which moves them, is SECURITY DEFINER. `app.normalize_identity_signal` (BEFORE INSERT OR UPDATE OF the value and type) applies the duplicate reader's own `app.normalize_phone` and `app.normalize_email` on every door, so a stored signal and a searched value always compare alike; a value that normalizes to nothing is refused by the existing NOT NULL, as the RPC never stores one. `172_a_customer_identity_signal_is_normalized_and_never_rewritten_test.sql` pins both. | — | SPEC-309-a-conversation-message-is-timed-and-recorded-and-an-identity-signal-is-normalized-and-never-rewritten | 11-15 | 11-15 |
   | CHAT-3 | **A message inserted at the table door was not recorded and did not move its conversation, though the same message through its RPC did both** | CRM conversations · audit completeness | Low | R | 6 | M | 🛡 | **FIXED 2026-11-15 locally (SPEC-309, `20261115180000`); Primary deployment pending.** **MEASURED** at `d38eb19`: an `employee` holding SEND_MESSAGE, at `aal1`, inserted an outbound message at the table door; the tenant's events did not move and the conversation's `updated_at` stayed where it was, while the same message through `app.send_conversation_message` recorded `conversation_message_sent` and moved it. `app.customer_timeline` reads a conversation's events, so a door message was missing from the customer's timeline and its conversation did not rise in any list ordered by activity. Severity is Low by CHAT-2's precedent on the same surface: a direct-door write that omits its event. **Repaired:** the signed-in INSERT arm of `app.derive_message_sender`, which already derives the sender (ATTR-4, `202607057000`), now derives `sent_at`, `received_at` and a blank text exactly as `app.send_conversation_message` does; a session-less insert (a provider integration replaying a message it received earlier) keeps its own times, as it keeps its own sender. `app.emit_conversation_message` (AFTER INSERT, SECURITY DEFINER, empty `search_path`, executable by no client role) is the single producer of the conversation's move and of `conversation_message_sent` or `conversation_message_received`, with the actor, the message id and its direction, on every door; the RPC no longer does either itself, so it records once. `171_a_conversation_message_is_timed_and_recorded_on_every_door_test.sql` pins both. | — | SPEC-309-a-conversation-message-is-timed-and-recorded-and-an-identity-signal-is-normalized-and-never-rewritten | 11-15 | 11-15 |
   | CHAT-4 | **A message inserted at the table door kept caller-supplied sent and received times and a blank text** | CRM conversations · integrity | Low | R | 6 | M | 🛡 | **FIXED 2026-11-15 locally (SPEC-309, `20261115180000`); Primary deployment pending.** **MEASURED** at `d38eb19`: the same employee inserted one outbound message with `sent_at` in 2019 and `received_at` in 2099, and both were kept; another kept a blank text and no time at all. The RPC derives both times from the clock by direction and stores a blank text as none. Severity is Low, re-measured at `d38eb19`: no function reads `sent_at` or `received_at` (`pg_proc` and the migrations); `app.forbid_message_rewrite` only freezes them. **Repaired:** the signed-in INSERT arm of `app.derive_message_sender`, which already derives the sender (ATTR-4, `202607057000`), now derives `sent_at`, `received_at` and a blank text exactly as `app.send_conversation_message` does; a session-less insert (a provider integration replaying a message it received earlier) keeps its own times, as it keeps its own sender. `app.emit_conversation_message` (AFTER INSERT, SECURITY DEFINER, empty `search_path`, executable by no client role) is the single producer of the conversation's move and of `conversation_message_sent` or `conversation_message_received`, with the actor, the message id and its direction, on every door; the RPC no longer does either itself, so it records once. `171_a_conversation_message_is_timed_and_recorded_on_every_door_test.sql` pins both. | — | SPEC-309-a-conversation-message-is-timed-and-recorded-and-an-identity-signal-is-normalized-and-never-rewritten | 11-15 | 11-15 |
   ```

   The resulting file's Git blob is adf596562e468af6e7a721829a0ab737b905662f.

7. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**60 of 78 recorded · 36 `; if so record Already Applied when its Git blob is e15e3f863bc568f1d5af1b940de8b0b5f4b1963b, and otherwise stop and report. Otherwise make exactly these 6 edits (the freshness entry, coverage 60 of 78 and the three surface rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-14 (**slice 52 — `events`, `scheduled_job_findings` and `internal_supplier_links` selected by Exposure 6 and 5, coverage 400, 18 and 18, in one contract.** Coverage **54 → 57 of 78**. CONV-11: a conversion source event that committed late was never mapped. ISL-1 and ISL-2: a link made at the table door was not recorded, and a link was rewritten in place unrecorded. SPEC-308 closes all of them here; `scheduled_job_findings` holds with no finding, so the three rows are `AUDITED`.)
   ```
   with
   ```text
   Last updated: 2026-11-15 (**slice 53 — `conversation_messages`, `customer_identity_signals` and `offline_conversion_deliveries` selected by Exposure 5, coverage 24, 24 and 34, in one contract.** Coverage **57 → 60 of 78**. CHAT-3 and CHAT-4: a message inserted at the table door was not recorded, did not move its conversation, and kept caller-supplied times and a blank text. CUST-13 and CUST-14: a signal was rewritten in place unrecorded, and a signal added at the door was stored as typed, so the duplicate check misread or missed it. SPEC-309 closes all of them here; `offline_conversion_deliveries` holds with no finding, so the three rows are `AUDITED`.)

   Previously: 2026-11-14 (**slice 52 — `events`, `scheduled_job_findings` and `internal_supplier_links` selected by Exposure 6 and 5, coverage 400, 18 and 18, in one contract.** Coverage **54 → 57 of 78**. CONV-11: a conversion source event that committed late was never mapped. ISL-1 and ISL-2: a link made at the table door was not recorded, and a link was rewritten in place unrecorded. SPEC-308 closes all of them here; `scheduled_job_findings` holds with no finding, so the three rows are `AUDITED`.)
   ```

   b) replace the line
   ```text
   **57 of 78 recorded · 33 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 21 `NOT-RECORDED`.**
   ```
   with
   ```text
   **60 of 78 recorded · 36 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 18 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 57 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 60 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `conversation_messages` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `conversation_messages` | **AUDITED** | ADVERSARIAL | `SPEC-309-a-conversation-message-is-timed-and-recorded-and-an-identity-signal-is-normalized-and-never-rewritten` | CHAT-3, CHAT-4 | `171_a_conversation_message_is_timed_and_recorded_on_every_door_test.sql` (11 assertions; DOOR, INPUT and OBSERVABILITY declared, the rest N/A) proves that a message inserted at the table door is recorded once, by its actor, on its conversation, and moves the conversation; that its times and text are derived, so a named 2019 and a received time a year ahead are not kept, and the derived time cannot be back-dated afterwards; that an inbound door message is received now, holds no blank text and is recorded as received; that an RPC message is recorded once, not twice, and keeps its trimmed text and time; and that a session-less integration keeps the time it received a message and is recorded with no actor. Tests 17, 53, 57, 58, 67 and 88 pass unchanged. **Swept and classified as non-defects:** a message's text and times are not rewritten after the insert (`app.forbid_message_rewrite`); no DELETE grant; the sender is derived, never named; a closed conversation refuses a message on both doors; another tenant's conversation, and another branch's for an employee who cannot see it, refuse a write and show nothing; a role without SEND_MESSAGE is refused on both doors; anonymous REST is refused (401). **Recorded positions:** `created_at` is caller-supplied on INSERT and read by nothing that decides (SPEC-216's schema-wide question); `external_message_id` and `metadata` stay writable after the insert by design (`app.forbid_message_rewrite`); a session-less writer keeps its own times and sender. 0 hosted messages. |
   ```

   e) replace the line
   ```text
   | `customer_identity_signals` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `customer_identity_signals` | **AUDITED** | ADVERSARIAL | `SPEC-309-a-conversation-message-is-timed-and-recorded-and-an-identity-signal-is-normalized-and-never-rewritten` | CUST-13, CUST-14 | `172_a_customer_identity_signal_is_normalized_and_never_rewritten_test.sql` (10 assertions; DOOR, INPUT and PRIVILEGE declared, the rest N/A) proves that `authenticated` may add and read a signal and never rewrite or delete one; that a raw phone and a mixed-case email added at the table door are stored as the duplicate reader compares them, and the duplicate check finds the customer by both; that a phone which normalizes to nothing is refused; that an employee cannot move a signal to another customer and an `owner` at `aal2` cannot retype one; and that `app.create_customer` still seeds its normalized signal. Tests 57, 58, 89 and 111 pass unchanged. **Swept and classified as non-defects:** no DELETE grant (an employee and an `owner` at `aal2`); a role without CREATE_CUSTOMER is refused; another tenant reads no signal and cannot add one; anonymous REST is refused (401). **Recorded positions:** signals are readable tenant-wide, as the duplicate check needs; signals record no event on any door, the RPC's included, and the customer's creation is recorded; `created_at` is caller-supplied on INSERT (SPEC-216's question); correcting a wrong signal stays a product question (a new signal is a new row; nothing deletes one). 0 hosted signals. |
   ```

   f) replace the line
   ```text
   | `offline_conversion_deliveries` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `offline_conversion_deliveries` | **AUDITED** | ADVERSARIAL | `SPEC-309-a-conversation-message-is-timed-and-recorded-and-an-identity-signal-is-normalized-and-never-rewritten` | — | Tests 09, 10, 13, 35, 58, 142 and 143 pin the delivery checks (provider request shape and uniqueness, status vocabulary, `sent` only on provider SUCCESS, `ingested` only with a request id) and the platform write path, and all pass unchanged beside this contract, which does not touch the table. **Swept and classified as non-defects** (an employee, and an `owner` at `aal2`): `authenticated` holds SELECT only, so a delivery insert, update or delete is refused (42501), and REST refuses the table write (401); `app.claim_conversion_deliveries`, `app.record_conversion_ingestion` and `app.record_conversion_provider_status` are SECURITY DEFINER and executable by `orvion_integration` only, so an owner is refused and REST does not serve the claim (404); another tenant reads no delivery. **Recorded position:** deliveries are readable tenant-wide (`tenant_isolation`). Platform-written rows; nothing changed, so no test was added. 0 hosted deliveries. |
   ```

   The resulting file's Git blob is e15e3f863bc568f1d5af1b940de8b0b5f4b1963b.

8. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–7 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the two migrations and tests 171 and 172, which must equal Consumer Closure;
   - on the local stack holding the migrations: the four functions' `md5(prosrc)`, security mode and ACL, the triggers of `conversation_messages`, `customer_identity_signals` and `offline_conversion_deliveries`, the signal UPDATE grant and the catalog count; tests 171 and 172 alone; the probes; the ten mutants, with the restored shape proven equal;
   - the causal negatives: the stack before the migrations, then the stack restored with them;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migrations;
   - the API-contract generator, whose output must differ from the baseline contract in exactly the two rows of Consumer Closure and equal `MASTER_API_CONTRACT.md`; the map generator, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary and the measured-state items of Consumer Closure.

   Then read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of both target migrations;
   - the function, grant and structural surfaces;
   - the triggers of the three tables and the four functions' `md5(prosrc)`;
   - the tenant, conversation, message, signal, delivery and event counts.

   Record the predicted delta. If any reading differs, stop.
9. **Check** that an exact-SHA Gate-2 record for the two migrations is in the Execution Log. It is either the owner's own, or one marked DELEGATED that names this contract, each migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If it is absent, write it only when Step 8 passed and those instructions cover migrations that drop no table or column and delete or rewrite no business row. Otherwise stop after Step 8 and present the Gate-2 package.
10. **Check** which of `20261115180000_a_conversation_message_is_timed_and_recorded_on_every_door` and `20261115180100_a_customer_identity_signal_is_normalized_and_never_rewritten` Primary `vrvtsxexkiiiivlkdxzp` lacks. If Step 9 is recorded, deploy each one it lacks in version order, in one sitting:
    - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, the target's absence, the business counts and the triggers of the three tables.
    - On an exact match, prove the transmitted text's md5 server-side, then apply only that migration through the Primary connector.
    - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row other than this contract's own versions, its stored statement md5 equal to the file's, and no existing target version.
    - If a stop falls between the two, record the half-deployed ledger in the Execution Log before anything else.

    Then read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of the three tables; the four functions' `md5(prosrc)`, security mode and ACL; the signal UPDATE grant; and the business counts. Never contact Secondary `brplkqmbzffpxqgkkdzo`.
11. **Check** that fresh Primary evidence contains each of the two new migrations exactly once. If so:
    - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
    - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the client RPC figure unchanged.
    - Confirm that `supabase/tests` holds 172 files whose literal `plan(N)` values sum to 3193, then set `Suite **172 files / 3193 assertions**`. If either differs, stop.
    - In the register, replace each `` | 🛡 | **FIXED 2026-11-15 locally (SPEC-309, `V`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-15 (SPEC-309, `V`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-309; the fresh Primary ledger, functions and structure equal local.** ``, for V `20261115180000` (the two rows CHAT-3 and CHAT-4) and `20261115180100` (the two rows CUST-13 and CUST-14). Each span's one leading and one trailing space are delimiters, not text. Change nothing else in the register.
    - Regenerate `MASTER_API_CONTRACT.md` with the canonical generator, which must change it only in the two rows of Consumer Closure, and regenerate `ai-map.json` and `repository-index.md` (stored LF) with the canonical generator.
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

- [ ] The message migration is the frozen bytes; `check: blob supabase/migrations/20261115180000_a_conversation_message_is_timed_and_recorded_on_every_door.sql 0a0feaaca957fe7593dc68c677775299d20324b8`
- [ ] The signal migration is the frozen bytes; `check: blob supabase/migrations/20261115180100_a_customer_identity_signal_is_normalized_and_never_rewritten.sql 56daf0d42f6b21d7bdb4956d540ee67dd3328c17`
- [ ] Test 171 is the frozen bytes; `check: blob supabase/tests/171_a_conversation_message_is_timed_and_recorded_on_every_door_test.sql 169dd0faab469bf43117c50974277a27bb1b3a2d`
- [ ] Test 172 is the frozen bytes; `check: blob supabase/tests/172_a_customer_identity_signal_is_normalized_and_never_rewritten_test.sql 8336f5c1d946c0b7b8b179499bbf57c558918345`
- [ ] Canon 27 says what a conversation message records; `check: has _ORVION_CANONICAL/27_event_catalog.md "Created by every outbound conversation message"`
- [ ] The disposition record carries the three surfaces AUDITED / ADVERSARIAL and coverage 60 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md e15e3f863bc568f1d5af1b940de8b0b5f4b1963b`
- [ ] The four register rows are fixed and deployed; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-309"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **172 files / 3193 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @d38eb19bab1c5727b090ec1ce877a64a200bfc3d`
- [ ] The message sender's origin migration remains exact; `check: same supabase/migrations/202607057000_capability_on_the_insert_path_and_a_message_that_cannot_be_forged.sql @d38eb19bab1c5727b090ec1ce877a64a200bfc3d`
- [ ] The smoke catalog count remains exact; `check: same scripts/verify_database.sql @d38eb19bab1c5727b090ec1ce877a64a200bfc3d`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the two authorized migrations, with at most one guarded ledger rename for each and no business-data write, after a recorded Step 8 readiness gate and Step 9 Gate-2 record. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] The ten mutants are each killed with installation proven and the restored shape read, and the two causal negatives and the probes, before and after, are recorded.

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

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-309: Batch 6 Slice 53 — a conversation message is timed and recorded on every door; a customer identity signal is normalized on every door and never rewritten (CHAT-3, CHAT-4, CUST-13, CUST-14), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline d38eb19bab1c5727b090ec1ce877a64a200bfc3d and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `_ORVION_CANONICAL/27_event_catalog.md` | `74bdd64ed44adcef823378dc3f194c7ad6b46610` |
| `reports/master/MASTER_GAP_REGISTER.md` | `32d45feaee349a34633d899203c1dc87c223a9d1` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `64b470b49e50d6509db3188923a986ecb5d19a48` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md and ENGINEERING_METHOD.md; SPEC-126, SPEC-215, SPEC-216, SPEC-237 and SPEC-308 at d38eb19bab1c5727b090ec1ce877a64a200bfc3d; the owner's instructions of 2026-11-08 and 2026-11-15 (recorded outside this repository). This is the one Draft for these surfaces, finalized after the adversarial review and the evidence refresh that its Draft Assurance records. Correctness remains native and independent.
