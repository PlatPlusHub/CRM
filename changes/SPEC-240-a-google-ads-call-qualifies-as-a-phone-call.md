# Change Request — SPEC-240

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close PH8-4, the fifth Google Ads conversion. When a lead whose immutable first-touch `lead_source_code` is `google_ads_call` qualifies, the one qualification fact becomes `qualified_phone_call` INSTEAD OF `qualified_lead`, with or without a click. Such a conversion is delivered only on its customer's latest recorded `ad_user_data` consent, and only with something Google can match on.

Deliver the three authorities this needs, and nothing more:
- the mapper's classification;
- one E.164 authority, `app.e164_phone`;
- AUDIT-4's first slice, `public.customer_consents`, with one writer and one reader.

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
  - **Data Manager is the only path.** Since 15 June 2026, offline and enhanced-conversions-for-leads uploads are blocked in the Google Ads API (`support.google.com/google-ads/answer/15713840`).
  - **An identifier is required, and `userData` alone satisfies the API.** An event needs "at least one of" a click id, session attributes, `userData` or an IP address (`data-manager/api/devguides/events/google-ads/offline/send-events`, updated 2026-09-24).
  - **`PHONE` is current.** The enum describes it as "generated from a phone call"; it was added in v1.2 and is required for offline events (`reference/rpc/google.ads.datamanager.v1`, updated 2026-09-25; release notes 2025-08-06).
  - **Phone format.** `phone_number` is SHA-256 "after normalization (E164 standard)", with the plus sign and country code (`get-started/formatting`).
  - **Consent values.** `Consent.adUserData` is a `ConsentStatus` of `CONSENT_STATUS_UNSPECIFIED`, `CONSENT_GRANTED` or `CONSENT_DENIED`. The processing error `PROCESSING_ERROR_REASON_UNKNOWN_CONSENT` arises when consent "could not be determined".
  - **Transaction id.** `transactionId` deduplicates within a conversion action, and a repeat is handled as an adjustment.
  - **Customer data policy.** It requires disclosure of third-party sharing, consent "where legally required", and the EU user consent policy where it applies.
  - **The nuance, resolved as far as evidence allows.** Google Ads Help says a GCLID "is required if you are not using a tag to collect user-provided data". ORVION has no front end, tag or GTM container, and a caller from a call ad may never visit a site. Google's native call path, call-conversion import by caller ID with a Google forwarding number, is a Google Ads API service the Data Manager API does not offer.
  - **Conclusion.** The API accepts a click-less phone conversion. Whether Google Ads attributes one is an account-configuration fact nobody can prove from here. It is **PH8-10**, an owner/UI prerequisite, and nothing in the database depends on it.
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
    - `created_by` (derived by `app.derive_created_by`) and `created_at` (`now()`);
    - a `seq` identity.
  - **Consent access.**
    - RLS is `tenant_isolation`, for select only.
    - `authenticated` holds SELECT and nothing else.
    - The one writer is `app.record_customer_consent`, a SECURITY DEFINER function that takes neither actor nor time, authorizes CREATE_CUSTOMER and locks the customer so `seq` follows commit order. Its one HTTP endpoint is `public.record_customer_consent`.
    - The one reader is `app.customer_consent_status`: the latest `seq`, or NULL.
  - **Claim eligibility.** A `qualified_phone_call` is claimable only when all three hold:
    - it has a `source_event_seq`;
    - its customer's current `ad_user_data` status is `granted`;
    - it carries an E.164 phone, an email, or a consented click id.

    Every other conversion is claimed on its click's consent, exactly as before.
  - **Claim output.**
    - A click's ids travel only under that click's own consent.
    - A phone row reports consent `granted` with personalization NULL.
    - The phone returned for every row is `app.e164_phone(customer_phone)`.
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
- **Consent does not follow a customer merge.** `app.merge_customer_identity` re-points every foreign key to `customers`. The consent record deliberately has none on `customer_id`, so a merge leaves it with the identity it was given for, and the survivor keeps only its own. This fails closed. The alternative is an owner decision below.
- **Primary deployment adds a table, four functions and three triggers, and replaces two function bodies in production.** It requires separate exact-byte owner authorization (Gate 2). Approving this contract does not authorize it.

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
- `supabase/tests/83_actor_attribution_test.sql`
- `supabase/tests/119_conversion_provenance_is_platform_written_test.sql`
- `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`
- `supabase/tests/139_qualified_lead_and_booking_are_recorded_on_every_door_test.sql`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `_ORVION_CANONICAL/24_entity_registry.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/architecture-decision-records.md`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `reports/architecture-decision-records.md` ADR-0023, ADR-0024, ADR-0025
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
| A `lead_qualified` whose lead's first-touch source is `google_ads_call` maps to `qualified_phone_call`, click or no click | `offline_conversions`; the five Google Ads actions (§1); Tests 64, 66, 119, 137 and 139, which map leads | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `6c48fbb`: migration SHA-256 `7a7e171544a92b34f148c96325bf4e2367fdcff09f090602f6f94fcf7c38a066`, Test-142 SHA-256 `edf3fcdbaf3406c38e4b712dffacc328b1d818b7726f4c49d146d8db12931584`. Tests 64, 66 and 119 use `google_ads_call` leads and count conversions by lead and by event, never by type, and pass unchanged. Tests 137 and 139 use `google_ads_form` and pass unchanged. |
| `app.claim_conversion_deliveries`: the phone path's eligibility, the click identifiers under their own consent, the phone through `app.e164_phone` | the future delivery workflow (§2a); Test 09 (lease), Test 119 | VERIFY | The signature and columns are unchanged. Every click-path row is claimed exactly as before, and a click-path row's ids and consent are unchanged, because its click consent is already `granted`. Only its phone becomes E.164 or NULL. §2a correction 3 and a new correction 12 record the workflow's side. |
| New `public.customer_consents`, `app.record_customer_consent`, `public.record_customer_consent`, `app.customer_consent_status`, `app.e164_phone` | Tests 01, 10, 14, 35, 53, 83, 89, 102 (catalog-driven); `scripts/verify_database.sql`; `scripts/verify_api_end_to_end.ps1`; `MASTER_API_CONTRACT.md`; Check 22 | WRITE | Tests 01, 10, 14 and 83 pass by conformance. Tests 35, 53, 89 and 102, the smoke script and the HTTP suite are edited as Risks states. The disposition record gains a `NOT-RECORDED` row. The API contract gains one endpoint and one table in Step 7. |
| `customers` may carry consent records that a merge does not move | `app.merge_customer_identity` | VERIFY | No foreign key on `customer_id`, so the merge loop does not see the table, and the merge is unchanged. |
| Suite, smoke and every HTTP door | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, on a clean reset from a scratch worktree at `6c48fbb`, in `-Finish`'s order: focused Test 142 25/25; pgTAP Pass A 142 files / 2557 assertions PASS (the 2532 existing, four of them re-pinned, plus 25 new); HTTP suites 35 + 40 + 74 + 122 + 120 + 60 = 451 passed, 0 failed; Pass B without reset 142 / 2557 PASS; smoke `ALL CHECKS PASSED (78 tables, …)`, exit 0. The generator reports 80 RPC endpoints, all 80 with HTTP evidence. |
| Measured state that moves | manifest (`Live state`, suite figure, table and RPC counts, coverage, open decisions, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19, 22, 25 | WRITE | 238 → 239 migrations, latest `20260929160000`; 77 → 78 tables; 79 → 80 client RPCs; 449 → 451 HTTP assertions; 141 → 142 files and 2532 → 2557 assertions; coverage 31 of 77 → 31 of 78. PH8-10 joins the open owner decisions. Primary values are written only from fresh post-deploy readings. |
| Findings, disposition and the activation list | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `MASTER_INTEGRATION_CATALOG.md` §1, §2a, §2b; Checks 2, 11, 14, 16, 21, 22, 24, 25 | WRITE | PH8-4 becomes fixed. AUDIT-4 gains its first slice and PH8-3 its engineering half, both staying open on their owner decisions. PH8-10, CONV-9 and CONV-10 are new. §2b item 2 closes except PH8-10, and the registry row stays `NOT OPERATIONAL`. No other row changes. |

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
- **A foreign key from the consent record to `customers`:** `app.merge_customer_identity` would re-point it, and `app.forbid_mutation` would then abort every merge of a consented customer.

Added Property: Every `lead_qualified` becomes exactly one conversion. A lead whose immutable first-touch source is `google_ads_call` becomes `qualified_phone_call`, click or no click, and any other attributed lead becomes `qualified_lead`. A `qualified_phone_call` reaches delivery only when all three hold:
- it came from a real event;
- its customer's latest recorded `ad_user_data` decision is `granted`;
- it carries an E.164 phone, an email or a click id whose own consent is granted.

No phone leaves the claim unless it is already E.164. A consent decision is recorded only through one writer, with the server's actor and time, is never rewritten, and is always recordable. A future lead writer, qualification door or delivery consumer inherits all of it without knowing it exists.

Causal Negative: On the local stack at `6c48fbb`, in a rolled-back transaction, four leads were qualified through `app.advance_lead` and the real mapper and claim were run. The consented-click `google_ads_call` lead became `qualified_lead` and was claimed under the Qualified Lead action. The click-less `google_ads_call` leads became nothing. The table stored `01001234567`, `+0100` and `callmemaybe` as phones, which the claim returns raw. No customer-level consent record existed. With the prototype's mapper and claim replaced by their pre-repair bodies, Test 142 fails assertions 11, 12, 15, 16 and 18.

Positive Test Design: As the tenant's owner at `aal2`, assign eight leads to an `employee` handler. The handler logs a phone call on each, records consent decisions through `app.record_customer_consent`, and qualifies seven leads through `app.advance_lead` and the eighth at the table door. Then run the real mapper and claim. The leads are:
- two `google_ads_form` leads with a click, one consented and one denied;
- two `google_ads_call` leads with a click, one consented and one denied;
- four click-less `google_ads_call` leads, whose customers have, in turn: denied then granted; a local number only; granted then withdrawn; and no record.

Later, record the unrecorded customer's consent and claim again, and record a withdrawal while the tenant is `read_only`.

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

Non-Empty Population Obligation: Two tenants with active enterprise subscriptions. Tenant one has an owner, an `employee` handler and a user holding no role, one branch and department, eight customers with eight leads, and four consented or denied Google Ads clicks. Tenant two has an owner.

Mutation Obligation: Out of file, record the md5 of a surface covering:
- the five function definitions;
- the consent table's triggers and ACL;
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

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the out-of-file mutations and the unrepaired counterfactual;
- the generated artifacts;
- fresh Primary evidence, parity evidence and the Primary ledger check;
- repository consistency and `git diff --check`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql` is absent. If absent, create it LF with SHA-256 `7a7e171544a92b34f148c96325bf4e2367fdcff09f090602f6f94fcf7c38a066`. It holds exactly the objects Business Reason names, with EXECUTE revoked from PUBLIC on every new function:
   - `app.e164_phone`;
   - `public.customer_consents`, with its index, RLS policy, grants and three triggers;
   - `app.record_customer_consent`, granted to `authenticated`;
   - `public.record_customer_consent`, granted to `authenticated`;
   - `app.customer_consent_status`;
   - `app.map_outcomes_to_conversions` and `app.claim_conversion_deliveries`, each identical to its live body except for the changes Business Reason names.

   It changes no other function, grant, policy or table. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql` is absent. If absent, create it LF with SHA-256 `edf3fcdbaf3406c38e4b712dffacc328b1d818b7726f4c49d146d8db12931584`. It is one transaction-rolled-back pgTAP file with `select plan(25);`. Its `-- ATTACK-CLASSES:` line reads `BUSINESS REPLAY STATE INPUT PRIVILEGE TENANT DOOR OBSERVABILITY AUTH=N/A CONCURRENCY=N/A`, and its header states each `N/A` reason. It implements the Positive and Negative Test Design and the privilege shape of the new functions.

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

   Applied to `6c48fbb`, these edits produce LF SHA-256 values: register `cb80ae2dbaef3ed7076c1da297ccb545b4ee80d52ac0a2c24f78edcd4c10e723`, disposition `e127a6a311ace9bbfc3cf70c1d57dd91f19e48ede29cda57d02dbe480b5f9356`, catalog `32a50529011fbe3939c48e0b40ee45f07bb2fc150ccdd4918e10cb01e7909ef6`. If a target already carries different content, stop.
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
   - the current definition md5 of the mapper and the claim;
   - the absence of every new object.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD and the exact hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested;
   - the guarded ledger-normalization conditions.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260929160000_a_google_ads_call_qualifies_as_a_phone_call`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the two pre-repair md5 values.
   - On an exact match, apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, and the new functions' security modes, `search_path` and EXECUTE ACLs. Also read the table's RLS, policy, grants and triggers.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`:
     - set `Live state` from the same readings: the migration count and latest version, the ledger and surface hashes and counts, 78 tables, 80 client RPCs and 451 HTTP assertions;
     - confirm that `supabase/tests` holds 142 files whose literal `plan(N)` values sum to 2557, then set the suite figure to `Suite **142 files / 2557 assertions**`; if either differs, stop;
     - set coverage to 31 of 78;
     - add PH8-10 to `Open owner decisions`;
     - set `Last Completed` to SPEC-240 / PH8-4, keeping the manifest within 7000 characters (the prototype of this step measured 6955).
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
- [ ] `app.customer_consent_status` returns the latest record: denied-then-granted is `granted`, granted-then-denied is `denied`, and no record is NULL.
- [ ] The claim delivers a `qualified_phone_call` only when it came from a real event, its customer's current consent is `granted`, and it carries an E.164 phone, an email or a consented click id. It keeps a genuine consented click id, needs none, and withholds one whose own consent was denied. It never delivers a withdrawn, never-consented or hand-recorded one, or one with nothing to match on.
- [ ] Every click-path conversion is claimed on its click's consent exactly as before. The customer's consent never admits one.
- [ ] No phone leaves the claim unless `app.e164_phone` returns it. `app.e164_phone` never guesses a country, and a conversion that is not eligible stays recorded with its snapshot and no delivery.
- [ ] `app.record_customer_consent` is SECURITY DEFINER with an empty `search_path`, executable by `authenticated` and through one HTTP endpoint for signed-in callers only. `app.customer_consent_status` and `app.e164_phone` are executable by `postgres` only.
- [ ] Mutants M1 to M21 are each killed, with installation and restoration md5-proven and no aborted run. On the pre-repair mapper and claim, Test 142 fails assertions 11, 12, 15, 16 and 18.
- [ ] Register and records:
  - PH8-4 is registered fixed and deployed.
  - PH8-3 and AUDIT-4 record their delivered halves and stay open on their owner decisions.
  - PH8-10, CONV-9 and CONV-10 are registered open, and PH8-10 is on the manifest's open-decision line.
  - `customer_consents` is `NOT-RECORDED`, `offline_conversions` stays `PARTIAL`, and §2b item 2 is closed except PH8-10.
  - The Google Ads registry row stays `NOT OPERATIONAL`.
  - Every other row and the recorded coverage are unchanged.
- [ ] The migration, the five tests and the two scripts match their SHA-256 values. Primary, the recorded evidence, the manifest (239 migrations; 142 files / 2557 assertions; 78 tables), the API contract and `ai-map.json` agree.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

None.

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
  - Tests are behavioural and pinned by 21 mutants, not SQL text.
- **Future change cost.**
  - A Google payload change touches only the workflow (§2a).
  - A default-country policy (PH8-3) changes one function body.
  - A new consent purpose adds one CHECK value and a reader call.
- **Owner decisions requested at Gate 1**, each with the recommended answer:
  1. **The consent writer's permission** is CREATE_CUSTOMER, held by every role that handles customers, rather than a new permission.
  2. **Consent does not follow a customer merge** and fails closed. The alternative, a foreign key plus a merge that carries consent, changes `app.merge_customer_identity`.
  3. **A phone conversion whose click consent is denied** is delivered on the customer's own grant with the click id withheld: each authority governs its own data. The alternative is to refuse the conversion whenever any attached click was denied.
  4. **Consent is recordable while billing-restricted,** for grants as well as withdrawals, since one trigger cannot tell them apart.
  5. **PH8-10 is accepted as the owner's Google Ads verification,** and the five-conversion certification waits on it for click-less calls.
- **Deliberately not changed:**
  - PH8-2 and DELIV-1, the observability surface: not required here, and the ineligible rows stay recorded.
  - PH8-3's default-country policy: an owner decision.
  - AUDIT-4's other purposes: Phase 10.
  - CONV-9 and CONV-10: recorded.
  - `app.record_offline_conversion` and `customers`: unchanged.
  - PH8-9 and the workflow: their own contracts, next.
  - The registered worktree `owt/p2` is untouched.
