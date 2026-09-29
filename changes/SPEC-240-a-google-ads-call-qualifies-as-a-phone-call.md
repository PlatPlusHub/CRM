# Change Request — SPEC-240

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close PH8-4, the fifth Google Ads conversion. When a lead whose immutable first-touch `lead_source_code` is `google_ads_call` qualifies, the one qualification fact becomes `qualified_phone_call` INSTEAD OF `qualified_lead`, with or without a click. Such a conversion is delivered only on its customer's latest recorded `ad_user_data` consent, and only with something Google can match on.

Deliver the three authorities this needs, and nothing more:
- the mapper's classification;
- one E.164 authority, `app.e164_phone`;
- AUDIT-4's first slice, `public.customer_consents`, with one writer and one merge-aware reader, on ADR-0019's documented exclusion route.

Record PH8-10, the Google attribution prerequisite the owner must verify, and CONV-9 and CONV-10, found on the way and not repaired. This is the fourth contract of the Phase-8 Activation Closure and closes `MASTER_INTEGRATION_CATALOG.md` §2b item 2, except its external prerequisite.

## Business Reason

The manifest's next capability is the Phase-8 Activation Closure, and §2b item 2 is its next condition. The owner decided PH8-4 on 2026-09-28:
- one qualification fact, classified by the immutable first-touch source, never both conversions;
- no second call-qualification truth, no telephony and no call duration;
- no click required;
- `eventSource` `PHONE`;
- the E.164 phone, hashed at the edge;
- fail-closed consent from ORVION's authority, where a call is never itself consent.

- **Google, re-read 2026-09-29 (first-party only).**
  - **Data Manager is ORVION's current offline/ECL delivery path.** Since 15 June 2026, offline-conversion and enhanced-conversions-for-leads *uploads* are migrated to the Data Manager API and blocked in the Google Ads API for developer tokens not already allowlisted (`support.google.com/google-ads/answer/15713840`). That block applies to the upload path ORVION uses. Google's native call-conversion import (`UploadCallConversions`, by caller ID) is a separate, still-documented Google Ads mechanism with Google Forwarding Number requirements (`google-ads/api/docs/conversions/upload-calls`, updated 2026-09-23); it is not ORVION's route.
  - **An identifier is required, and `userData` alone satisfies the API.** An event needs "at least one of" a click id, session attributes, `userData` or an IP address (`data-manager/api/devguides/events/google-ads/offline/send-events`, updated 2026-09-24).
  - **`PHONE` is current.** The enum describes it as "generated from a phone call"; it was added in v1.2 and is required for offline events (`reference/rpc/google.ads.datamanager.v1`, updated 2026-09-25; release notes 2025-08-06).
  - **Phone format.** `phone_number` is SHA-256 "after normalization (E164 standard)", with the plus sign and country code (`get-started/formatting`).
  - **Consent values.** `Consent.adUserData` is a `ConsentStatus` of `CONSENT_STATUS_UNSPECIFIED`, `CONSENT_GRANTED` or `CONSENT_DENIED`. The processing error `PROCESSING_ERROR_REASON_UNKNOWN_CONSENT` arises when consent "could not be determined".
  - **Transaction id.** `transactionId` deduplicates within a conversion action, and a repeat is handled as an adjustment.
  - **Customer data policy.** It requires disclosure of third-party sharing, consent "where legally required", and the EU user consent policy where it applies.
  - **The nuance, resolved as far as evidence allows.** Three things are distinct:
    - **(A) The Data Manager API schema:** `userData` alone satisfies its identifier requirement.
    - **(B) Google Ads enhanced conversions for leads:** Help says a GCLID "is required if you are not using a tag to collect user-provided data". ORVION has no front end, tag or GTM container, and a caller from a call ad may never visit a site.
    - **(C) Google's native call-conversion import:** a separate mechanism that relies on Google Forwarding Numbers, not the ORVION Data Manager/ECL route.
  - **Conclusion.** ORVION may truthfully create the `qualified_phone_call` candidate and satisfy its own identity and consent rules. Whether Google Ads attributes and credits a click-less one is an account-configuration fact nobody can prove from here. It is **PH8-10**, an owner/provider prerequisite, and nothing in the database depends on it. A schema-valid request is not provider success, and the five-conversion certification must not claim that a click-less call was credited.
- **PH8-4 (reproduced).** Measured on the local stack at `6c48fbb`, rolled back. Four leads were qualified through `app.advance_lead` by their assigned handler, and the real mapper and claim were run:

  | Lead | Today | Owner-decided |
  | --- | --- | --- |
  | `google_ads_form`, consented click | 1 `qualified_lead`, claimed | the same |
  | `google_ads_call`, consented click | **1 `qualified_lead`**, claimed, counted under the wrong action | 1 `qualified_phone_call` |
  | `google_ads_call`, no click | **nothing**: the mapper requires a click | 1 `qualified_phone_call` |
  | `google_ads_call`, local number `01000000844` | nothing | formed; never sent without a guessed prefix |

  - **Replay.** A second run added 0.
  - **Lineage.** `lead_source_code` is set NOT NULL at creation, and `leads_forbid_acquisition_lineage_rewrite` refused a platform rewrite (`42501`).
  - **The lead state machine is acyclic** (`contacted -> qualified` only), and `leads_emit_qualified` fires once on entry, so a lead has at most one `lead_qualified`.
- **Phone identity, measured.**
  - **Accepted formats.** `customers.primary_phone` accepts `01001234567`, `00201001234567`, `+0100`, `+201001234567x12` and `callmemaybe`. Its CHECK and `app.normalize_phone` only strip `[[:space:]().-]`.
  - **The snapshot.** `offline_conversions.customer_phone` snapshots that value, and the claim returns it raw.
  - **No country anywhere.** No tenant, branch or customer carries a country. The only country columns are passport and destination, and neither says where a phone is registered. A local `01…` number cannot be told from another country's without guessing. `MASTER_INTEGRATION_CATALOG.md` §2a correction 3 therefore put a normalizer in the n8n workflow, a second authority.
- **Consent, measured.**
  - **Click-level consent is the only authority.** `attribution_clicks.consent_ad_user_data` is written once by `app.capture_attribution_click`, the integration role's RPC.
  - **The claim reads it by inner join,** so a conversion with no click can never be claimed.
  - **No customer-level record exists.** `customers.marketing_opt_in` is an undated boolean, and no later migration added a consent record.
  - **So a phone-origin lead has no consent authority at all.**
- **Where consent blocks.** The existing architecture forms every conversion and gates at the claim (PH8-2). A conversion that is not eligible stays in `offline_conversions` with no delivery row. PH8-4 keeps that shape: the qualification is CRM truth and never disappears, and only delivery is gated. PH8-2's observability surface is not required for the fifth conversion and is not absorbed.
- **The repair.**
  - **Mapper.** The mapper's INSERT classifies through one `lateral`: a `lead_qualified` whose lead's first-touch source is `google_ads_call` is `qualified_phone_call`, and such a row does not need a click. Nothing else in the mapper changes.
  - **E.164.** `app.e164_phone(text)` returns `app.normalize_phone(value)` only when it matches `^\+[1-9][0-9]{6,14}$`, the validator in Google's own Google Ads API sample, and otherwise returns NULL. It is IMMUTABLE, SQL, executable by `postgres` only.
  - **Consent record.** `public.customer_consents` is append-only (`app.forbid_mutation`) and holds:
    - `tenant_id`, `customer_id` and `purpose_code` (`ad_user_data` only);
    - `consent_status_code` (`granted` or `denied`; unspecified is the absence of a record);
    - `channel_code` (the existing `channel_code` catalog) and optional `evidence`;
    - `created_by` (derived by `app.derive_created_by`) and `created_at` (`now()`, evidence only);
    - a `seq` identity, the only ordering authority;
    - tenant-qualified foreign keys to `customers` and `users`.
  - **Consent access.**
    - RLS is `tenant_isolation`, for select only.
    - `authenticated` holds SELECT and nothing else.
    - The one writer is `app.record_customer_consent`, a SECURITY DEFINER function that takes neither actor nor time. It authorizes CREATE_CUSTOMER, verifies the customer is in the caller's tenant, locks the customer row `FOR NO KEY UPDATE`, refuses a merged-away identity by naming its survivor, and inserts. Its one HTTP endpoint is `public.record_customer_consent`.
    - The one reader is `app.customer_consent_status`: the latest `seq` among the records of the **logical** customer, or NULL. It walks `customer_identity_merges` up from the given id to the survivor and back down through every identity merged into it, at any depth, so any member's id gives the same answer.
  - **Merge (Gate-1 amendment; ADR-0019's documented route).** ADR-0019 makes every customer referrer follow the merge by default, and says a referrer that must not be blindly re-pointed goes on the documented exclusion list and is handled explicitly. Consent evidence is append-only and must stay attributable to the identity it was given for, so `customer_consents` joins `customer_identity_merges` on that list. Both are one-name edits in `app.merge_customer_identity`, whose body is otherwise unchanged. The reader handles consent explicitly, as above. Two consequences follow:
    - A merged identity's newer DENIED beats the survivor's older GRANTED, and a survivor's newer DENIED beats a merged identity's older GRANTED.
    - After a merge, every new decision is written to the survivor.
  - **Ordering.** `created_at` defaults to `now()`, the recording transaction's start, so it cannot order decisions. The order is `seq`, a table identity allocated at INSERT:
    - The writer inserts only after taking the customer's row lock, and the lock is held to commit. So two decisions for one customer are serialized, and the later-serialized one gets the higher `seq`.
    - A merge takes both customers `FOR UPDATE`, which serializes it against both writers, and a merged-away identity takes no new decision. So after a merge, every decision for the logical customer is serialized on the survivor's row.
    - Decisions recorded on two identities *before* anyone knew they were one person had no common lock to serialize on. `seq`, allocated in insert order, still orders them deterministically.
  - **Claim eligibility.** A `qualified_phone_call` is claimable only when all three hold:
    - it has a `source_event_seq`;
    - its customer's current `ad_user_data` status is `granted`;
    - it carries an E.164 phone, an email, or a consented click id.

    Every other conversion is claimed on its click's consent, exactly as before.
  - **Claim output.**
    - A click's ids travel only under that click's own consent.
    - A phone row reports consent `granted` with personalization NULL.
    - The phone returned for every row is `app.e164_phone(customer_phone)`.
- **Ordering, measured with two real sessions** (local disposable state, committed, then reset).
  - **Two writers.** B's transaction began first (`now()` 15:29:43.60). A began at 15:29:44.38 and recorded `granted` under the lock.
    - B called the writer at 15:29:45.61. While A held the lock, `pg_stat_activity` showed B waiting on `Lock/transactionid`.
    - B's insert returned at 15:29:47.41, after A's commit at 15:29:47.40.
    - Result: A has `seq` 48 and a later `created_at`; B (`denied`) has `seq` 49 and a `created_at` 0.8 s earlier. The reader returns `denied`; ordering by `created_at` would have returned `granted`.
  - **Merge against writer.** An owner merged S into T and held the transaction for 3 s. A writer naming S, started meanwhile, waited on the lock and was then refused: `customer was merged into <T> -- record consent for the surviving customer`. It could only read the merge row after the merge committed, which proves it waited. Nothing was recorded.
- **Exposure.** Primary holds 0 tenants, leads and offline conversions, and no workflow exists. The defect is latent until the first Google Ads call lead qualifies.

## Risks

- **A qualification counted twice would be one call uploaded as two conversions.** Mitigated:
  - `offline_conversions.source_event_seq` is unique, and the classification yields one type per row.
  - Mutant M1b, dual-routing with the key intact, keeps one row per event. M1, with the key dropped too, and M12, a replay without the key, are killed.
  - A hand-recorded `qualified_phone_call` is never claimed (assertion 18; M14).
- **Consent coerced to granted.** Denied, withdrawn and absent are each refused by name (assertions 9, 15 and 16; mutants M5, M6, M7 and M13). A click's denial is never overridden for its own identifiers (L8; M11 and M15), and the click path never reads the customer record (L7; M17).
- **A malformed or guessed phone reaching Google.** The claim returns only `app.e164_phone`'s result (assertions 15 and 23; M8 and M9). A local number stays in the snapshot as CRM truth and never leaves.
- **The claim's phone column changes for the four click-path types too.** It is intended: one authority, not one per type. Today a non-E.164 phone reaches the workflow raw, and §2a correction 3 tells the workflow to drop it. No workflow exists, so no consumer changes behaviour; the phone Google would receive is identical.
- **A new table carries every catalog-driven obligation.** The prototype's full suite named six, and each is met by conformance or classification, not exemption by convenience:
  - **Test 14:** the tenant-qualified foreign key on `created_by`.
  - **Test 83:** `app.derive_created_by`, the actor trigger every attributed table uses.
  - **Tests 53 and 102:** their pinned inventories gain the endpoint and the table (83 → 84, 77 → 78).
  - **Test 89:** classifies the mapper's read of `lead_source_code` as reading and refusing nothing.
  - **Test 35:** exempts the table from the subscription write gate on `user_permission_grants`' revocation reasoning. A withdrawal must be recordable whatever the billing state, and assertions 20–22 prove it.
  - **The smoke script** `verify_database.sql` pins the table count (77 → 78). It was found by running it, not by reading it.
  - **The declared HTTP suite** `verify_api_end_to_end.ps1` gains two checks, so the endpoint carries HTTP evidence like the other 79: an employee records a new customer's consent through the RPC, and the same employee's POST to the table is refused.
- **A merge hiding a decision.** Ignoring a merged identity's history would not fail closed: a source's newer DENIED would be hidden behind the target's older GRANTED. The reader reads the logical customer instead (assertions 27–30, 32, 34 and 35; mutants M22 and M24). The evidence is never re-pointed or rewritten (assertion 31; M20 and M24), and a merge of consented customers succeeds (assertion 26).
- **The merge function's body is replaced** to add one name to its exclusion list. Its FK discovery, collision handling, locking, audit row and event are byte-identical. Test 71 (the merge suite), Test 79 and Test 111 pass unchanged.
- **Ordering by time.** `created_at` is evidence only. Assertion 37 pins that a later-serialized DENIED with an earlier `created_at` governs (mutant M23), and the two-session proof above measured the live case.
- **Primary deployment adds a table, four functions and three triggers, and replaces three function bodies in production** (the mapper, the claim and the merge). It requires separate exact-byte owner authorization (Gate 2). Approving this contract does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-240-a-google-ads-call-qualifies-as-a-phone-call.md`
- `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql`
- `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/89_finance_periphery_parent_state_test.sql`
- `supabase/tests/102_financial_account_identity_and_definer_surface_test.sql`
- `scripts/verify_database.sql`
- `scripts/verify_api_end_to_end.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/architecture-decision-records.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607049200_offline_conversion_core.sql`
- `supabase/migrations/202607049300_outcome_conversion_mapper.sql`
- `supabase/migrations/202607050500_conversion_identity_snapshot.sql`
- `supabase/migrations/202607056700_acquisition_lineage_is_first_touch.sql`
- `supabase/migrations/20260928140000_a_payment_conversion_finds_its_lead_through_its_invoice.sql`
- `supabase/tests/01_rls_coverage_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/14_tenant_qualified_fk_test.sql`
- `supabase/tests/64_acquisition_lineage_test.sql`
- `supabase/tests/66_scheduled_job_isolation_test.sql`
- `supabase/tests/71_customer_identity_merge_test.sql`
- `supabase/tests/79_customer_data_integrity_test.sql`
- `supabase/tests/83_actor_attribution_test.sql`
- `supabase/tests/119_conversion_provenance_is_platform_written_test.sql`
- `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`
- `supabase/tests/139_qualified_lead_and_booking_are_recorded_on_every_door_test.sql`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `_ORVION_CANONICAL/24_entity_registry.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `reports/architecture-decision-records.md` ADR-0019, ADR-0023, ADR-0024, ADR-0025
- `reports/master/MASTER_GAP_REGISTER.md` (PH8-2, PH8-3, PH8-4, AUDIT-4, CONV-6, CONV-8); `reports/master/MASTER_INTEGRATION_CATALOG.md` §1, §2a, §2b
- Current local `app.map_outcomes_to_conversions`, `app.claim_conversion_deliveries`, `app.record_offline_conversion`, `app.normalize_phone`, `app.merge_customer_identity`, `app.derive_created_by`, `app.forbid_mutation`, `app.forbid_acquisition_lineage_rewrite`, `app.emit_lead_qualified`
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

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A `lead_qualified` whose lead's first-touch source is `google_ads_call` maps to `qualified_phone_call`, click or no click | `offline_conversions`; the five Google Ads actions (§1); Tests 64, 66, 119, 137 and 139, which map leads | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `6c48fbb`: migration SHA-256 `4889af581f5759bbd7e9c3a075835942604a374b151624e2916d8132b90ec126`, Test-142 SHA-256 `d858cf644d38945458673623c1af0752e3987ab1ae254ad6a5d37edf7453f2c2`. Tests 64, 66 and 119 use `google_ads_call` leads and count conversions by lead and by event, never by type, and pass unchanged. Tests 137 and 139 use `google_ads_form` and pass unchanged. |
| `app.claim_conversion_deliveries`: the phone path's eligibility, the click identifiers under their own consent, the phone through `app.e164_phone` | the future delivery workflow (§2a); Test 09 (lease), Test 119 | VERIFY | The signature and columns are unchanged. Every click-path row is claimed exactly as before, and a click-path row's ids and consent are unchanged, because its click consent is already `granted`. Only its phone becomes E.164 or NULL. §2a correction 3 and a new correction 12 record the workflow's side. |
| New `public.customer_consents`, `app.record_customer_consent`, `public.record_customer_consent`, `app.customer_consent_status`, `app.e164_phone` | Tests 01, 10, 14, 35, 53, 83, 89, 102 (catalog-driven); `scripts/verify_database.sql`; `scripts/verify_api_end_to_end.ps1`; `MASTER_API_CONTRACT.md`; Check 22 | WRITE | Tests 01, 10, 14 and 83 pass by conformance. Tests 35, 53, 89 and 102, the smoke script and the HTTP suite are edited as Risks states. The disposition record gains a `NOT-RECORDED` row. The API contract gains one endpoint and one table in Step 7. |
| `app.merge_customer_identity` excludes `customer_consents` from re-pointing, and the consent reader follows `customer_identity_merges` | every merge; Tests 71, 79 and 111; ADR-0019 | WRITE | The only change is one name added to the documented exclusion list. Local definition md5: pre-repair `58ce524303afbb2ccb7dd25626a8f6ca`, repaired `375a663c0b700498b78c029c5ce07e15`. Tests 71, 79 and 111 pass unchanged. ADR-0019 gains an appended bullet recording the second documented exclusion. |
| Suite, smoke and every HTTP door | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, on a clean reset from a scratch worktree at `6c48fbb`, in `-Finish`'s order, on the final bytes after the Gate-1 amendment: focused Test 142 38/38; pgTAP Pass A 142 files / 2570 assertions PASS (the 2532 existing, four of them re-pinned, plus 38 new); HTTP suites 35 + 40 + 74 + 122 + 120 + 60 = 451 passed, 0 failed; Pass B without reset 142 / 2570 PASS; local surfaces: 239 migrations, ledger `66f7ce11526941ed7ab4e675b3fd4e28`, functions `78339ac07ebd500811850ad5bf04f302`/318, structural `77bba1da1535be6fcfee07aff2ca118c`/3102; smoke `ALL CHECKS PASSED (78 tables, …)`, exit 0. The generator reports 80 RPC endpoints, all 80 with HTTP evidence. |
| Measured state that moves | manifest (`Live state`, suite figure, table and RPC counts, coverage, open decisions, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19, 22, 25 | WRITE | 238 → 239 migrations, latest `20260929160000`; 77 → 78 tables; 79 → 80 client RPCs; 449 → 451 HTTP assertions; 141 → 142 files and 2532 → 2570 assertions; coverage 31 of 77 → 31 of 78. PH8-10 joins the open owner decisions. Primary values are written only from fresh post-deploy readings. |
| Findings, disposition, ADR and the activation list | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `MASTER_INTEGRATION_CATALOG.md` §1, §2a, §2b; `architecture-decision-records.md` ADR-0019; Checks 2, 11, 14, 16, 21, 22, 24, 25 | WRITE | PH8-4 becomes fixed. ADR-0019 gains the appended exclusion bullet. AUDIT-4 gains its first slice and PH8-3 its engineering half, both staying open on their owner decisions. PH8-10, CONV-9 and CONV-10 are new. §2b item 2 closes except PH8-10, and the registry row stays `NOT OPERATIONAL`. No other row changes. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the declared HTTP suite, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| PH8-3, PH8-4, PH8-10, AUDIT-4, CONV-9, CONV-10, both disposition rows and §2a/§2b accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The manifest's open-decision line carries every registered decision | BEFORE_COMPLETION | Step 3 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: the mapper and claim of ADR-0023's outbox, with the mapper's unique `source_event_seq` as the one-event-one-conversion key and the claim as the delivery gate PH8-2 describes. The acquisition lineage `leads_forbid_acquisition_lineage_rewrite` already freezes. `app.normalize_phone`, extended by one predicate rather than duplicated. The append-only (`app.forbid_mutation`), actor (`app.derive_created_by`), catalog (`app.enforce_catalog_codes`) and tenant-isolation mechanisms every audited table uses. The `events`/`record_event` sole-writer shape, where the grant is the gate. New structure is only the consent record, because no existing structure can hold a dated, attributed, purpose-scoped, withdrawable decision. The alternatives were rejected:
- **A new lead status, qualification RPC or `phone_call_qualified` event:** a second qualification truth.
- **Classifying on a logged `phone_call` interaction, call duration or the latest source:** mutable, and not what the owner decided (mutant M4).
- **Emitting both conversions and letting Google choose:** double counting (M1).
- **Normalizing in the mapper, the snapshot, the trigger or n8n:** a second authority each.
- **E.164 at entry, a CHECK on `customers.primary_phone`:** a local number is valid CRM contact data for ORVION's own calls, so this needs PH8-3's owner policy.
- **Storing the SHA-256:** provider wire format in the CRM.
- **Consent as `customers` columns with history in `events`:** two representations of one fact, and a table door that cannot carry the channel or evidence.
- **Consent as `events` alone:** fragile reconstruction for every read.
- **Reusing `marketing_opt_in`:** undated, unattributed, not purpose-scoped and not withdrawable as history.
- **Reusing click consent for the phone path:** a call lead may have no click, and the owner kept the two authorities distinct.
- **A generic consent, preference or CMP framework:** no second consumer exists.
- **Consent that does not follow a merge (the first Gate-1 draft):** the survivor would ignore a merged identity's newer DENIED, which does not fail closed. Rejected by the owner.
- **Normal merge participation (re-pointing):** it would make every consent record updatable, weakening append-only. It would need a second, immutable "recorded-for customer" column to stay attributable, and a bespoke trigger admitting only that update.
- **Copying a merged identity's records onto the survivor:** it fabricates evidence, and fresh `seq` values would let an older GRANTED outrank a newer DENIED.
- **Omitting the foreign key to keep the table out of the merge:** it hides the exclusion instead of documenting it (ADR-0019) and gives up integrity (assertion 38; M26).
- **Ordering by `created_at`, or by a timestamp plus a random id:** `now()` is the transaction's start, not its serialization point (assertion 37; M23).

Added Property: Every `lead_qualified` becomes exactly one conversion. A lead whose immutable first-touch source is `google_ads_call` becomes `qualified_phone_call`, click or no click, and any other attributed lead becomes `qualified_lead`. A `qualified_phone_call` reaches delivery only when all three hold:
- it came from a real event;
- its customer's latest recorded `ad_user_data` decision is `granted`;
- it carries an E.164 phone, an email or a click id whose own consent is granted.

No phone leaves the claim unless it is already E.164. A consent decision is recorded only through one writer, with the server's actor and time. It is never rewritten, re-pointed or hidden by a merge, and it is always recordable. The effective decision of a logical customer is its latest by `seq`, across every identity merged into it, and decisions serialized on one customer take `seq` in serial order. A future lead writer, qualification door or delivery consumer inherits all of it without knowing it exists.

Causal Negative: On the local stack at `6c48fbb`, in a rolled-back transaction, four leads were qualified through `app.advance_lead` and the real mapper and claim were run. The consented-click `google_ads_call` lead became `qualified_lead` and was claimed under the Qualified Lead action. The click-less `google_ads_call` leads became nothing. The table stored `01001234567`, `+0100` and `callmemaybe` as phones, which the claim returns raw. No customer-level consent record existed. With the prototype's mapper and claim replaced by their pre-repair bodies, Test 142 fails assertions 11, 12, 15, 16, 18 and 35. With the first draft's merge-blind reader (M22), it fails 27–30, 32, 34 and 35.

Positive Test Design: As the tenant's owner at `aal2`, assign eight leads to an `employee` handler. The handler logs a phone call on each, records consent decisions through `app.record_customer_consent`, and qualifies seven leads through `app.advance_lead` and the eighth at the table door. Then run the real mapper and claim. The leads are:
- two `google_ads_form` leads with a click, one consented and one denied;
- two `google_ads_call` leads with a click, one consented and one denied;
- four click-less `google_ads_call` leads, whose customers have, in turn: denied then granted; a local number only; granted then withdrawn; and no record.

Later, record the unrecorded customer's consent and claim again, and record a withdrawal while the tenant is `read_only`. Then, with the tenant writable again, record decisions on nine further customers and let the owner merge them:
- S1 (granted) into T1 (nothing);
- S2 (a newer denied) into T2 (an older granted), where S2 carries a qualified Google Ads call lead, L9;
- S3 (an older granted) into T3 (a newer denied);
- X1 (a newer denied) into X2 (an older granted), then X2 into X3.

Read each logical customer from every member's id. Claim, record a new grant on T2, and claim again.

Negative Test Design:
- **The table door.** A session cannot INSERT a consent record with a forged actor or time (`42501`), cannot record `unspecified` (`23514`), and without CREATE_CUSTOMER is refused (`42501 permission denied: CREATE_CUSTOMER`).
- **Another tenant.** It cannot record consent for this tenant's customer through the HTTP endpoint (`customer is not in your tenant`), and sees none of its records.
- **Rewrites.** Even the platform cannot rewrite a record (`append-only table`).
- **Lineage.** No write can change a lead's first-touch source (`42501`).
- **Delivery refusals.** The claim does not deliver:
  - the local-number, withdrawn and never-consented phone conversions;
  - the form lead whose click consent is denied, although its customer consented;
  - a hand-recorded `qualified_phone_call`.
- **Replay.** A rewound mapper cursor re-maps nothing, and a second claim claims nothing.
- **E.164.** `app.e164_phone` returns NULL for local, 00-prefixed, malformed, extended, too-short and too-long values, and NULL for NULL.
- **Merge.** A merged identity's newer DENIED is not hidden by the survivor's older GRANTED, even at delivery (L9 is not claimed).
- **Merged identity.** A merged identity refuses a new decision, naming its survivor.
- **History.** Every record survives five merges unchanged.
- **Tenant.** Another tenant's read of the same customer id is NULL.
- **Order.** A later-`seq` DENIED with an earlier `created_at` governs.
- **Foreign key.** Even the platform cannot record consent for a customer outside the record's tenant (`23503`).

Non-Empty Population Obligation: Two tenants with active enterprise subscriptions. Tenant one has an owner, an `employee` handler and a user holding no role, one branch and department, eight customers with eight leads, four consented or denied Google Ads clicks, and nine merge customers, one with a Google Ads call lead. Tenant two has an owner.

Mutation Obligation: Out of file, record the md5 of a surface covering:
- the six function definitions, the merge included;
- the consent table's triggers, ACL and constraints;
- the `offline_conversions` indexes.

For each mutant: install it, prove the md5 differs, run Test 142 and require every planned assertion to run with no ERROR line, restore, and prove the md5 matches. A mutant whose installation is not proven is a harness error, never a killed mutant.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | a call lead yields both conversions, the unique key dropped | 11, 12 |
| M2 | every qualified lead is `qualified_phone_call` | 11 |
| M3 | a call lead stays `qualified_lead` | 11 |
| M4 | the source is a logged phone call, not the first-touch source | 11 |
| M5 | `denied` is deliverable | 15 |
| M6 | no record counts as `granted` | 15 |
| M7 | a valid phone bypasses consent | 15 |
| M8 | the raw phone leaves the claim | 15 |
| M9 | a local number gains `+20` | 23 |
| M10 | a click id is required | 15 |
| M11 | a genuine click id is withheld | 15 |
| M12 | the replay key is removed | 13 |
| M13 | the first record wins | 9 |
| M14 | a hand-recorded `qualified_phone_call` is deliverable | 18 |
| M15 | the phone path reads click consent | 15 |
| M16 | no identifier is required | 16 |
| M17 | the click path reads customer consent | 16 |
| M18 | `authenticated` gains INSERT and UPDATE | 1, 3 |
| M19 | the actor is not derived | 2 |
| M20 | the append-only trigger is dropped | 8 |
| M21 | the subscription gate is attached | 21 |
| M22 | the reader ignores merged identities | 28 |
| M23 | the reader orders by `created_at` | 37 |
| M24 | the merge re-points consent | 26 |
| M25 | a merged identity takes new decisions | 33 |
| M26 | the customer foreign key is dropped | 38 |

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the out-of-file mutations and the unrepaired counterfactual;
- the generated artifacts;
- fresh Primary evidence, parity evidence and the Primary ledger check;
- repository consistency and `git diff --check`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql` is absent. If absent, create it LF with SHA-256 `4889af581f5759bbd7e9c3a075835942604a374b151624e2916d8132b90ec126`. It holds exactly the objects Business Reason names, with EXECUTE revoked from PUBLIC on every new function:
   - `app.e164_phone`;
   - `public.customer_consents`, with its index, RLS policy, grants and three triggers;
   - `app.record_customer_consent`, granted to `authenticated`;
   - `public.record_customer_consent`, granted to `authenticated`;
   - `app.customer_consent_status`;
   - `app.merge_customer_identity`, identical to its live body except that its exclusion list also names `customer_consents`;
   - `app.map_outcomes_to_conversions` and `app.claim_conversion_deliveries`, each identical to its live body except for the changes Business Reason names.

   It changes no other function, grant, policy or table. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql` is absent. If absent, create it LF with SHA-256 `d858cf644d38945458673623c1af0752e3987ab1ae254ad6a5d37edf7453f2c2`. It is one transaction-rolled-back pgTAP file with `select plan(38);`. Its `-- ATTACK-CLASSES:` line reads `BUSINESS REPLAY STATE INPUT PRIVILEGE TENANT DOOR OBSERVABILITY AUTH=N/A CONCURRENCY=N/A`, and its header states each `N/A` reason. It implements the Positive and Negative Test Design and the privilege shape of the new functions.

   Then edit four existing tests and two verification scripts LF, each only as Risks states, with SHA-256 values:
   - `supabase/tests/35_subscription_write_gate_test.sql` `f45669b2c060a7b052801556741ecff623e7911ba0b7363efc6e0ffcbb978e4c`;
   - `supabase/tests/53_api_surface_test.sql` `692fe1b53385c29c95c1b5ed7758668ab355c3ae868cd30acc47cd87f83caef0`;
   - `supabase/tests/89_finance_periphery_parent_state_test.sql` `c9eda44f5d7b5da25749fe1d86c3a880bec05f614fffa1cff56af2a6f34a314e`;
   - `supabase/tests/102_financial_account_identity_and_definer_surface_test.sql` `13810971123cc8ce02934f4facb20cf8557c98c823eff63f51e98b5bca40b562`;
   - `scripts/verify_database.sql` `9d8ebe57306a6f7973d0dc85d3afe65bced8ff08986433ef2e5fba2493d79b98`;
   - `scripts/verify_api_end_to_end.ps1` `5a2b72d159fe7a2f2acbd2155cf30b7b59586c45e73b9009143db15f7cd0b727`.

   If a target carries different content, stop.
3. **Check** whether the PH8-4 block in `reports/master/MASTER_GAP_REGISTER.md` still lacks a `FIXED` line. If it does, make these changes and nothing else:
   - **Freshness.** Add a dated freshness entry and demote the previous one to `Previously:`.
   - **PH8-4.** Insert a first bullet stating it is fixed by SPEC-240 (`20260929160000`), pending Primary deployment. Give the mechanism, the measurement, what `142_...` proves, and pointers to PH8-10 and CONV-9.
   - **PH8-3.** Insert a first bullet stating its engineering half is closed by `app.e164_phone`, that no country is stored, and that the owner decision is unchanged.
   - **AUDIT-4.** Insert a first bullet stating the first slice is delivered for `ad_user_data` only, with its shape, and that the owner decision on other purposes and the counsel question are unchanged.
   - **PH8-10.** Insert a block before PH8-5, with **Status:** OPEN (external prerequisite) and **Owner:** owner (Google Ads UI verification). Give the first-party evidence of Business Reason, what ORVION does meanwhile, and when it closes.
   - **AUDIT-4's bullet** also states the merge semantics and that a merged identity takes no new decision. **PH8-10's evidence** uses Business Reason's A/B/C wording.
   - **CONV-9 and CONV-10.** Insert both rows after CONV-8, each Sev `Low`, Req/Opt `R`, Batch `8`, Mig `—`, Cert `📋`, Status `OPEN`, Owner Decision `—`, Source this contract, dates `09-29`. Give each its measurement or cause, latency and reopening trigger.

   In `reports/master/MASTER_SURFACE_DISPOSITION.md`:
   - add a dated freshness entry and demote the previous one;
   - insert `| \`customer_consents\` | NOT-RECORDED | — | — | — | — |` before `customer_contact_methods`;
   - set Coverage to `31 of 78 recorded · … · 47 NOT-RECORDED`;
   - in the `offline_conversions` row, set the CR to this contract and append a dated SPEC-240 note. The row stays `PARTIAL`.

   In `reports/master/MASTER_INTEGRATION_CATALOG.md`:
   - in the Google Ads registry row, replace the clause that `qualified_phone_call` is not yet produced, keeping `NOT OPERATIONAL`;
   - append a dated note to §2a correction 3 that the claim now returns E.164 or NULL and the workflow must never normalize;
   - add §2a correction 12, the phone path's consent, `eventSource` and click-id rules for the workflow;
   - qualify the re-verification paragraph's phone-only sentence with PH8-10;
   - extend §2b item 2 with a 2026-09-29 note that it is closed by SPEC-240 except PH8-10.

   In `reports/architecture-decision-records.md`, append to ADR-0019 one dated bullet recording `customer_consents` as its second documented exclusion and how the reader handles it. Change no other text.

   Applied to `6c48fbb`, these edits produce LF SHA-256 values: register `71d9970c532c6bd846678ea2e3afffc6405735ac064c447a61e8d0530f97ce81`, disposition `e127a6a311ace9bbfc3cf70c1d57dd91f19e48ede29cda57d02dbe480b5f9356`, catalog `32a50529011fbe3939c48e0b40ee45f07bb2fc150ccdd4918e10cb01e7909ef6`, ADR `9999e48a137a050cdfc56e89456a19d594c83adc2c5bb239e19a3588fcbb19ae`. If a target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused test;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the mutation evidence and the unrepaired counterfactual;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only: undeployed Primary and parity drift, and the manifest's migration, suite, endpoint and open-decision drift that Step 7 restores. Read a fresh Primary baseline, read-only:
   - the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - the tenant, lead, customer, event and offline-conversion counts;
   - the current definition md5 of the mapper, the claim and the merge;
   - the absence of every new object.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD and the exact hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested;
   - the guarded ledger-normalization conditions.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260929160000_a_google_ads_call_qualifies_as_a_phone_call`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the three pre-repair md5 values.
   - On an exact match, apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, and the new functions' security modes, `search_path` and EXECUTE ACLs. Also read the table's RLS, policy, grants and triggers.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`:
     - set `Live state` from the same readings: the migration count and latest version, the ledger and surface hashes and counts, 78 tables, 80 client RPCs and 451 HTTP assertions;
     - confirm that `supabase/tests` holds 142 files whose literal `plan(N)` values sum to 2570, then set the suite figure to `Suite **142 files / 2570 assertions**`; if either differs, stop;
     - set coverage to 31 of 78;
     - add PH8-10 to `Open owner decisions`;
     - set `Last Completed` to SPEC-240 / PH8-4, keeping the manifest within 7000 characters (the prototype of this step measured 6968).
   - Mark PH8-4 `DEPLOYED` in the register.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Set the Runtime Checkpoint to DONE, so that Step 8's `-Finish` runs in VERIFY mode.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following:
     - transition to Complete;
     - keep `Next capability` as the Phase-8 Activation Closure with Slice 31 paused;
     - clear `Active Change Request`;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] Each qualification of an attributed or `google_ads_call` lead becomes exactly one conversion keyed to its own `lead_qualified`: `qualified_phone_call` for a first-touch `google_ads_call` lead with or without a click, and `qualified_lead` otherwise. A logged phone call does not change the type, the source cannot be rewritten, and a rewound mapper re-maps nothing.
- [ ] `public.customer_consents` is written only through `app.record_customer_consent`. Each record carries the server's actor and time. It refuses `unspecified`, callers without CREATE_CUSTOMER and other tenants' customers, is invisible across tenants, is never rewritten, and is recordable while the tenant is billing-restricted.
- [ ] `app.customer_consent_status` returns the latest record by `seq` of the logical customer, the same from any member's id: denied-then-granted is `granted`, granted-then-denied is `denied`, and no record is NULL.
- [ ] A customer merge neither erases nor hides a decision, and succeeds with consent records present:
  - a source GRANTED into an unrecorded target is `granted`;
  - a source's newer DENIED over a target's older GRANTED is `denied`, including at delivery;
  - a source's older GRANTED under a target's newer DENIED is `denied`;
  - after two sequential merges the newest decision governs;
  - a new decision on the survivor governs, and a merged identity refuses one;
  - every record is unchanged, and another tenant reads nothing.
- [ ] The effective order is `seq`, never a timestamp. Two concurrent decisions for one customer are serialized by its row lock, and the later-serialized one governs. Measured with two live sessions and pinned by assertion 37.
- [ ] The claim delivers a `qualified_phone_call` only when it came from a real event, its customer's current consent is `granted`, and it carries an E.164 phone, an email or a consented click id. It keeps a genuine consented click id, needs none, and withholds one whose own consent was denied. It never delivers a withdrawn, never-consented or hand-recorded one, or one with nothing to match on.
- [ ] Every click-path conversion is claimed on its click's consent exactly as before. The customer's consent never admits one.
- [ ] No phone leaves the claim unless `app.e164_phone` returns it. `app.e164_phone` never guesses a country, and a conversion that is not eligible stays recorded with its snapshot and no delivery.
- [ ] `app.record_customer_consent` is SECURITY DEFINER with an empty `search_path`, executable by `authenticated` and through one HTTP endpoint for signed-in callers only. `app.customer_consent_status` and `app.e164_phone` are executable by `postgres` only.
- [ ] Mutants M1 to M26 are each killed, with installation and restoration md5-proven and no aborted run. On the pre-repair mapper and claim, Test 142 fails assertions 11, 12, 15, 16, 18 and 35.
- [ ] Register and records:
  - PH8-4 is registered fixed and deployed.
  - ADR-0019 records `customer_consents` as its second documented exclusion.
  - PH8-3 and AUDIT-4 record their delivered halves and stay open on their owner decisions.
  - PH8-10, CONV-9 and CONV-10 are registered open, and PH8-10 is on the manifest's open-decision line.
  - `customer_consents` is `NOT-RECORDED`, `offline_conversions` stays `PARTIAL`, and §2b item 2 is closed except PH8-10.
  - The Google Ads registry row stays `NOT OPERATIONAL`.
  - Every other row and the recorded coverage are unchanged.
- [ ] The migration, the five tests and the two scripts match their SHA-256 values. Primary, the recorded evidence, the manifest (239 migrations; 142 files / 2570 assertions; 78 tables), the API contract and `ai-map.json` agree.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-29 — Owner approval (Human Gate 1)

The owner approved the exact Draft SHA `f62a0002590a358964c0f464c84a9c0896fbe260` (CR SHA-256 `79bc18bea8b05aa244c2a8fdf5005ae4fdef5a710f34551988695f071b39d0a0`) and its frozen seventeen-path Write Scope. The approval covers Approve, In Progress, Steps 1-4 and the full local proof only. Primary stays read-only and needs Human Gate 2; Secondary `brplkqmbzffpxqgkkdzo` is never contacted.

The approval is bound to two SHA-256 values:
- migration `20260929160000`: `4889af581f5759bbd7e9c3a075835942604a374b151624e2916d8132b90ec126`;
- Test 142: `d858cf644d38945458673623c1af0752e3987ab1ae254ad6a5d37edf7453f2c2`.

The owner's decisions, as the amended Draft states them:
1. **The consent writer uses CREATE_CUSTOMER.** No consent permission is added. Same-tenant verification, the server-derived actor and time, no direct table write door, and the unauthorized and cross-tenant negative tests are retained.
2. **Merge: the amended design is approved.** `customer_consents` is an explicit ADR-0019 exception to blind re-pointing. Consent evidence stays immutable and attributed to the identity it was recorded for, and the effective consent of a merged logical customer includes the full history of every identity merged into the survivor, at any depth. The following are permanent requirements:
   - a merged-away identity refuses new consent;
   - new consent is recorded against the survivor;
   - a newer source DENIED beats an older target GRANTED, and a newer target DENIED beats an older source GRANTED;
   - sequential merges preserve history;
   - post-merge decisions override older group history;
   - cross-tenant reads and writes fail.
3. **Ordering: `seq` is the authority.** `created_at` is evidence only and never decides. Serialization by the customer and merge locks is retained, including the proven property that a transaction which began earlier but records after waiting on the lock takes the later `seq` and governs.
4. **Click versus customer consent:**
   - The customer's `ad_user_data` grant authorizes the customer's identity path.
   - A click whose own consent is denied is never included as an identifier.
   - Neither decision is read as the other.
   - A row left with `userData` alone remains subject to PH8-10.
5. **Billing:** consent grants and withdrawals stay recordable while subscription writes are restricted. The exemption covers consent evidence only.
6. **PH8-10 stays OPEN**, in the accepted wording: "Data Manager is ORVION's current offline/ECL delivery path. Google's native call-conversion import is a separate mechanism with Google Forwarding Number requirements." No click-less Google attribution is claimed from the schema alone.

Any material architecture or semantic change from this Draft invalidates Gate 1.

Revalidation before approval:
- HEAD was the Draft, a child of `5caa678`, which is a child of the certified `6c48fbb`. `origin/main` was at `6c48fbb`, and the tree was clean.
- The committed Draft hashes to the approved value.
- A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE and REPOSITORY, seven permanent-control paths in scope). Two mutated copies returned FAIL (a gate at Step 4 inside the red window 1..7) and INDETERMINATE (the Mutation Obligation removed).
- The prototype files in the scratch worktree hash to the two approved values.

## Verification Notes

None yet.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

- **EARN IT.** PH8-4 was reproduced through the real mapper and claim:
  - a qualified Google Ads call counted under the wrong action, or not at all;
  - raw, unnormalizable phones reached the claim;
  - no consent authority existed for a phone-origin lead.

  Each gap blocks the fifth conversion, and nothing else in this contract is built.
- **WORTH IT.**
  - One classification expression and one claim predicate, on existing mechanisms.
  - One predicate over the existing phone normalizer.
  - One append-only table with one writer and one reader, AUDIT-4's first slice, which the owner named.
  - No new status, event type, permission, catalog, telephony surface or Google field.
- **SIMPLIFY IT WITHOUT WEAKENING.**
  - One qualification fact, one acquisition authority, one E.164 authority and one consent authority per path.
  - The delivery edge hashes and never decides.
  - A future lead writer, qualification door or consumer inherits every rule.
  - Tests are behavioural and pinned by 26 mutants, not SQL text.
  - The merge change is one name on ADR-0019's existing exclusion list, not a second identity system.
- **Future change cost.**
  - A Google payload change touches only the workflow (§2a).
  - A default-country policy (PH8-3) changes one function body.
  - A new consent purpose adds one CHECK value and a reader call.
- **Owner Gate-1 decisions (2026-09-29), applied by this amendment of Draft `5caa678`:**
  1. **APPROVED:** CREATE_CUSTOMER authorizes the writer. The writer independently verifies same-tenant ownership, neither actor nor time can be forged, and the table has no write door. Assertions 3, 5 and 6 pin the unauthorized and cross-tenant refusals.
  2. **REJECTED and replaced:** consent now follows the logical customer through the merge record, as Business Reason states.
  3. **APPROVED, with separate authorities.** The customer's grant authorizes the customer's first-party identity. A click whose own consent is denied is never sent as an identifier. Neither decision is read as the other. A row left with `userData` only remains subject to PH8-10.
  4. **APPROVED:** consent decisions are compliance facts, recordable while subscription writes are restricted. The exemption covers consent recording only, never delivery, platform status or retry rules.
  5. **APPROVED, wording tightened:** PH8-10 stays open until provider or account evidence shows a click-less phone event is attributed and credited.
- **Deliberately not changed:**
  - PH8-2 and DELIV-1, the observability surface: not required here, and the ineligible rows stay recorded.
  - PH8-3's default-country policy: an owner decision.
  - AUDIT-4's other purposes: Phase 10.
  - CONV-9 and CONV-10: recorded.
  - `app.record_offline_conversion`, `customers` and every merge behaviour except the one exclusion: unchanged.
  - PH8-9 and the workflow: their own contracts, next.
  - The registered worktree `owt/p2` is untouched.
