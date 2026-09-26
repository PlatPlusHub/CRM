# Change Request — SPEC-223

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Preserve the traveller identity actually ticketed on a frozen manifest entry: `booking_item_passengers` carries its own identity snapshot, derived from the reusable `passengers` profile until the PAX-5 freeze and changed afterwards only by an authorized, reasoned, server-stamped correction, while the profile stays freely editable.

## Business Reason

Batch 6 Slice 22 selected `passengers` live at Exposure 10, coverage 70; `bookings` was runner-up at 10/228. PAX-7, reproduced in a rolled-back local transaction: an `employee` at `aal2` holding CREATE_BOOKING_ITEM but not CORRECT_PASSENGER_MANIFEST was refused swapping the traveller on an issued booking's manifest entry (`42501 permission denied: CORRECT_PASSENGER_MANIFEST`), then directly UPDATEd the linked passenger's name, passport number and date of birth (1 row); the issued manifest then read `Mona Replacement / Z9999999` instead of `Ahmed Original`, with no reason, no correction actor and no new event. Canon 28 (§210 rule: a manifest freezes at issue; a post-issue correction requires CORRECT_PASSENGER_MANIFEST, a fresh reason and a server stamp) was defeated by editing the person instead of the link, because the manifest dereferences the mutable profile. Owner decision 2026-09-26 (Option 1): `passengers` stays a reusable, editable profile (future travel, passport and visa renewal, corrected data); the identity ticketed at the freeze point is preserved on the manifest link, and later profile edits must not rewrite it. Exposure today is nil: Primary holds 0 passengers and 0 manifest links, and no ticketing integration reads the manifest.

## Risks

- The PAX-5 lifecycle enforcer and the shared `app.guard_write_capability` are both restated; each change must be exactly the measured additions and nothing else.
- A profile edit now cascades a no-op touch onto that traveller's manifest rows; every trigger on `booking_item_passengers` must stay silent or correct for a touch.
- Primary deployment adds columns, grants, two changed functions, one new function and one trigger; it requires separate exact-byte owner authorization after local proof.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-223-frozen-traveller-identity-snapshot.md`
- `supabase/migrations/20260926130000_frozen_traveller_identity_snapshot.sql`
- `supabase/tests/128_frozen_traveller_identity_snapshot_test.sql`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/20260909132000_the_manifest_freezes_when_the_ticket_is_issued.sql`
- `supabase/migrations/20260909133000_a_manifest_change_is_a_business_event.sql`
- `supabase/migrations/20260926120000_marketing_campaign_step_up_parity.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/44_passenger_financial_authority_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/104_booking_item_passenger_manifest_surface_test.sql`
- `supabase/tests/114_passenger_manifest_freeze_and_events_test.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/28_permissions_matrix.md` (CORRECT_PASSENGER_MANIFEST and the manifest-freeze rule); `_ORVION_CANONICAL/31_schema_draft.md` (`passengers`, `booking_item_passengers`); `_ORVION_CANONICAL/27_event_catalog.md` (manifest events)
- Current local `app.enforce_booking_item_passenger_lifecycle`, `app.guard_write_capability`, `app.record_manifest_change_event`, `app.guard_passenger_financials`, `app.correct_passenger_manifest`, `app.link_passenger_to_booking_item`; `supabase/tests/104_booking_item_passenger_manifest_surface_test.sql` and `supabase/tests/114_passenger_manifest_freeze_and_events_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`passengers`); `reports/master/MASTER_GAP_REGISTER.md` (PAX-1 through PAX-6)

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
| Manifest entries carry six `manifest_*` identity fields (first, family and full name; date of birth; passport number; passport issuing country) | client API reading `booking_item_passengers` (column-level SELECT); issued-ticket identity | WRITE | Measured: no function, view or report in `app`, `public` or `reporting` reads an issued traveller's identity; `customer_timeline` lists profiles and `upload_document` places passports on the profile. The client API is the only reader, so the new columns receive column-level SELECT and UPDATE (for corrections) and no INSERT. |
| Snapshot derivation and the post-freeze correction rule live in the PAX-5 enforcer | `app.enforce_booking_item_passenger_lifecycle`; `app.correct_passenger_manifest`; `app.link_passenger_to_booking_item` | VERIFY | The enforcer is the only definition of frozen (`issued, reissue, refunded, void, completed` or an archived booking) and now computes it once for both rules. Prototype: INSERT and every unfrozen write re-derive from the profile (a forged pre-freeze value was overwritten); a swap always takes the new traveller's identity (RPC and direct); a frozen row that is merely touched keeps its identity. |
| Pre-freeze profile edits propagate | `public.passengers` writers (direct UPDATE; `create_passenger` only INSERTs) | VERIFY | New AFTER UPDATE trigger, firing only when an identity field moves, touches the traveller's links (SECURITY DEFINER, so a link the editor cannot see is still re-derived); the enforcer decides per row. Prototype: one profile edit updated the draft link and left the issued and void links unchanged; a platform-path edit behaved the same. |
| Post-freeze identity correction costs CORRECT_PASSENGER_MANIFEST, a fresh reason and a server stamp | `app.guard_write_capability` PAX-5 branch (finance_manager containment) | VERIFY | The guard's existing correction append now also fires when the ticketed identity moves with a fresh reason, exactly PAX-5's containment argument: before this, a `finance_manager` (holds CORRECT, not CREATE_BOOKING_ITEM) could swap but was refused an identity correction. Prototype: employee refused (`permission denied: CORRECT_PASSENGER_MANIFEST`) with or without a reason; branch manager refused without a fresh reason and when blanking the name, allowed with one and stamped; finance manager allowed; profile untouched. |
| The guard's other 27 tables; manifest events; financial overrides | every `*_guard_write_capability` table; `app.record_manifest_change_event`; `app.guard_passenger_financials` | VERIFY | Only the `booking_item_passengers` UPDATE branch condition changes. The emitter fires only on traveller or item change and the financial guard only on override change, so a touch records nothing. Prototype on a clean reset: pgTAP 127 files / 2199 PASS; `verify_api_end_to_end` 33/0, `verify_journey_branches` 74/0, `verify_lifecycle_branches` 122/0; `verify_database.sql` ALL CHECKS PASSED. |
| Identity-correction event | `public.events`; canon 27 | UNAFFECTED | Prototype: a post-freeze identity correction records its reason, actor and time on the row and emits no event (the item's event count stayed 1), so a later correction overwrites the earlier stamp. Canon 27 has no fitting type (`booking_item_passenger_replaced` means a different traveller); adding one needs canon 27 and a catalog change and no consumer reads it, so it is registered separately as PAX-8 (Low, OPEN), not repaired here. |
| Canon, generated and measured state | canon 31; API contract; Primary evidence; manifest; disposition; gap register; map | WRITE | Canon 31 moves to 0.6 and names which table owns current versus ticketed identity, referring to the canon 28 freeze rule rather than restating it. The API-contract generator produced identical output under the prototype; it stays in scope because the parity check regenerates it. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 7 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, six HTTP suites, smoke and installed mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Canon 31 and the Slice-22 findings and 23/77 disposition describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Manifest and Primary ledger/function/structure agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 8 | Step 9 |
| API contract and map match generators | BEFORE_COMPLETION | Step 1 | Step 8 | Step 9 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `app.enforce_booking_item_passenger_lifecycle` already owns the manifest freeze and the post-issue correction rule (CORRECT_PASSENGER_MANIFEST, fresh reason, server stamp), and `app.guard_write_capability` already appends that capability for an attributed correction. Reuse both: the enforcer gains the snapshot derivation and the identity-correction arm, the guard's condition gains the identity case, and one small AFTER UPDATE trigger on `passengers` propagates pre-freeze edits. No new permission, reason column, event type or definition of frozen.

Added Property: a manifest entry's ticketed identity equals its traveller's profile until the freeze, never changes afterwards except by a swap or an authorized, reasoned, stamped correction, and profile edits after the freeze no longer reach it.

Causal Negative: An employee holding CREATE_BOOKING_ITEM but not CORRECT_PASSENGER_MANIFEST was refused the traveller swap on an issued manifest entry and then renamed and re-passported the linked passenger with UPDATE 1; the issued manifest reported the new identity with no reason, actor or event. The probe rolled back.

Positive Test Design: Links derive the profile identity at INSERT (draft and already-issued bookings); a pre-freeze profile edit and a forged pre-freeze snapshot both end equal to the profile; after the platform-path freeze an employee's profile renewal lands; a branch manager's reasoned correction lands and is stamped; a finance manager's reasoned correction lands; a reasoned swap and the RPC swap take the new traveller's identity; a platform-path profile edit lands.

Negative Test Design: After the freeze the employee is refused rewriting, clearing, rewriting-with-a-reason and swapping, each pinned to `permission denied: CORRECT_PASSENGER_MANIFEST`, and the frozen identity is unchanged; the branch manager is refused without a fresh reason, when blanking the name and when editing only the evidence, each pinned to its message; a platform-path identity correction is refused; the post-freeze profile renewal leaves the frozen identity unchanged while the same traveller's draft entry follows it.

Non-Empty Population Obligation: Prove the traveller has a non-null passport number, is linked to one draft and one issued entry, the employee holds CREATE_BOOKING_ITEM and not CORRECT_PASSENGER_MANIFEST, the branch manager holds both, the finance manager holds CORRECT_PASSENGER_MANIFEST and not CREATE_BOOKING_ITEM, and each refused statement targets a visible frozen entry.

Mutation Obligation: Disable `passengers_sync_manifest_identity`, positively inspect `tgenabled = 'D'`, and show a pre-freeze profile edit no longer reaches the draft entry; re-enable, prove `tgenabled = 'O'`, show the next edit reaches it again, and prove the enforcer and guard definitions are byte-identical before and after. A failed installation is HARNESS ERROR, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP A/B, six HTTP suites, smoke, installed/restored mutation, generated artifacts, fresh Primary evidence, parity and repository Gate on final bytes.

## Implementation Steps

1. **Check** that `supabase/migrations/20260926130000_frozen_traveller_identity_snapshot.sql` is absent. If absent, create one LF migration that, in order: adds nullable `manifest_first_name`, `manifest_family_name`, `manifest_full_name`, `manifest_date_of_birth`, `manifest_passport_number` and `manifest_passport_issuing_country_code` to `public.booking_item_passengers`; backfills them from each row's passenger while the previous enforcer is still installed; grants `authenticated` column-level SELECT and UPDATE (not INSERT) on exactly those six; replaces `app.enforce_booking_item_passenger_lifecycle()` with its current installed definition plus the frozen flag computed once, the identity-correction arm, and the INSERT and UPDATE derivations; replaces `app.guard_write_capability()` with its current installed definition plus only the identity case in the `booking_item_passengers` correction condition; creates SECURITY DEFINER `app.sync_manifest_identity()` with EXECUTE revoked from public and the AFTER UPDATE OF the six profile fields trigger `passengers_sync_manifest_identity` with a WHEN clause on their change. Change no RLS policy, table grant, permission, event type or other table's mapping. If the target exists with different bytes or an installed source differs from local, stop.
2. **Check** that `supabase/tests/128_frozen_traveller_identity_snapshot_test.sql` is absent. If absent, create one LF transaction-rolled-back pgTAP file with a closed-vocabulary `-- ATTACK-CLASSES:` line and an exact `plan(N)` proving the Positive and Negative Test Design, the Non-Empty Population Obligation and the Mutation Obligation, and pinning PAX-8 as still OPEN. If the target exists with different bytes, stop.
3. **Check** whether `_ORVION_CANONICAL/31_schema_draft.md` is at Version 0.5 without the six fields. If so, set Version 0.6; add the six fields to `booking_item_passengers` core fields with one rule naming it the owner of the ticketed identity from the canon 28 freeze point; add one `passengers` note naming it the reusable, editable current profile; and add one numbered review note for 0.6 citing SPEC-223, PAX-7 and the owner decision. Restate no correction semantics that canon 28 owns.
4. **Check** whether `passengers` remains `NOT-RECORDED` and PAX-7 is absent from the register. If so, register PAX-7 (Medium) as fixed by this change, with the measured consequence and Primary's zero-row exposure, and PAX-8 (Low, OPEN: a post-freeze identity correction is evidenced only by the row's latest stamp and emits no event); set only `passengers` to `AUDITED-OPEN` / `ADVERSARIAL` with findings PAX-7, PAX-8; and mechanically update Batch-6 coverage to 23/77. Leave PAX-1 through PAX-6, ENTRY-1, CAMP-4, PAY-3, PAY-4 and every other finding unchanged. If the current record conflicts, stop.
5. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run clean local reset, focused test, pgTAP Pass A, six declared HTTP suites, pgTAP Pass B without reset, `scripts/verify_database.sql`, plan sum, installed mutation proof, the two changed-definition comparisons against Primary's current raw definitions, API-contract and map generators, scope, `git diff --check`, repository consistency and parity readiness. Record actual counts, exits and exact SHA-256 hashes. Treat only undeployed Primary/manifest/parity drift as expected at this boundary.
6. **Check** that exact owner authorization for the migration and permanent-test SHA-256 values is recorded in the Execution Log. If absent, stop after Step 5 and present current HEAD, the exact 64-character hashes, fresh full Primary baseline, predicted structural delta and exact Primary write. CR approval does not authorize deployment.
7. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260926130000_frozen_traveller_identity_snapshot`. If absent and separately authorized, immediately re-read HEAD, hashes, project identity, full ordered Primary ledger, target absence, both installed function md5s, zero passenger and manifest rows. On exact match apply only the authorized migration. Normalize only its newly inserted ledger row if the connector assigns a temporary version. Read fresh full ledger, function and all ten structural surfaces, the changed definitions, security modes, EXECUTE ACLs, the new columns and grants, and trigger timing/enabled state. Never contact Secondary.
8. **Check** that fresh Primary evidence contains the unique new migration. If so, update `reports/evidence/primary-ledger-evidence.json` and the manifest only from measured Primary facts; regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` with canonical generators. Run ledger, parity-evidence, repository consistency and `git diff --check`. If Primary is unproven, stop.
9. **Check** for a `Post-deploy local certification` Execution Log entry. If absent, run canonical `-Finish` and require `LOCAL_CERTIFY: READY`; independently Review the committed implementation and every acceptance item. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete and clear the manifest pointer. Publish the exact committed candidate, require exact-SHA candidate CI, promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs, and remove permitted scratch files. Do not start Slice 23.

## Acceptance Criteria

- [ ] After the freeze, a caller without CORRECT_PASSENGER_MANIFEST cannot change a manifest entry's ticketed identity by editing the profile, by writing or clearing the snapshot, or by swapping; each direct refusal is pinned to its message and the frozen identity is unchanged.
- [ ] The profile stays editable before and after the freeze; pre-freeze edits reach the entry, post-freeze edits do not; a CORRECT_PASSENGER_MANIFEST holder (including a finance manager) can correct the ticketed identity only with a fresh reason, stamped by the server; swaps and the correction RPC take the new traveller's identity; PAX-5's existing refusals are unchanged.
- [ ] PAX-7 is fixed; PAX-8 is a separate OPEN finding; `passengers` is `AUDITED-OPEN` / `ADVERSARIAL` and coverage is 23/77; canon 31 names the profile/snapshot ownership at 0.6; every other finding is untouched.
- [ ] Migration, test, canon, generated artifacts, local and fresh Primary evidence agree, with no out-of-scope file changes.

## Execution Log

### 2026-09-26 — Owner approval

Owner approved the exact Draft SHA `33f4d4271bfb19a365cbe1140359829f40ab8b9a` and the frozen ten-path Write Scope. An isolated Draft-to-Approved Gate returned `APPROVAL_EVIDENCE: PASS`. Approval authorizes the PAX-7 snapshot repair (owner decision Option 1) as local implementation and proof, not Primary deployment; PAX-8 is registered OPEN and not repaired; PAX-1 through PAX-6, ENTRY-1, CAMP-4, PAY-3 and PAY-4 stay untouched.

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

EARN IT: the PAX-5 freeze forbids moving who is flying after issue, and the same outcome was reachable by editing the linked profile, with no authority, reason or trace. WORTH IT: the owner chose snapshot over lock because locking the profile would freeze every repeat traveller's passport and visa forever. Snapshot fields are the six that identify the ticketed person and document: name components and full name, date of birth, passport number and its issuing country (a passport number is unique only per issuing country). Excluded, each measured as not identity: passport issue and expiry dates and all visa fields (validity attributes the owner explicitly wants renewable), nationality (a profile attribute not needed to identify the document once number and issuing country are held), passenger type (a fare category), customer and relationship (CRM context); there is no gender column. No consumer reads any of them for an issued manifest. Snapshot moment: derived on every link write while unfrozen, so no transition hook is needed; rejected a hook on the booking's issue transition because its write into the manifest would charge the manifest's CREATE_BOOKING_ITEM guard to the issuer, and finance managers issue without holding it. Rejected also: lazy read-time coalescing (would need a second definition of frozen in every consumer) and a new correction permission or reason column (PAX-5's own ones already own the act). The identity-correction event gap is registered as PAX-8 (Low, OPEN), not repaired. PAX-1 through PAX-6, ENTRY-1, CAMP-4, PAY-3 and PAY-4 are untouched.
