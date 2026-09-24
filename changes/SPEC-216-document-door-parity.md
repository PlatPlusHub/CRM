# Change Request — SPEC-216

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the `public.documents` table door unable to give a document a state its own RPCs cannot give it — a document born held, archived, in a lifecycle state, or pointing at a version; a type changed after upload; a version pointer moved to anything but the document's own current version; and `archived` with `is_archived` false — by one SECURITY INVOKER guard and one CHECK constraint, while every RPC, grant, policy and other trigger on `documents` stays exactly as it is today.

## Business Reason

Batch 6 Slice 16 selected `documents` by measurement (`scripts/batch6_select_target.ps1` at `2c907cd`: Exposure **13**, first — Direct 2, five `app` writers, a status machine and a uniqueness marker; runner-up `refunds` at 11, first of the four surfaces at 11 on coverage 34). `authenticated` holds table-level INSERT and UPDATE on `documents`, and all five writing RPCs (`app.upload_document`, `app.upload_subscription_payment_proof`, `app.add_document_version`, `app.archive_document`, `app.set_document_legal_hold`) are SECURITY INVOKER through that same grant, so PostgREST serves the table beside them. Every creating RPC births a document `active`, unarchived, unheld and with no version, then points it at the version it has just made current; `app.add_document_version` moves the pointer only to the version it has just made current; `app.archive_document` moves both archive representations together; and no RPC changes a document's type. Reproduced against the clean local stack, each in one rolled-back transaction, by an actor who could not reach the state any other way:

- **DOC-4 (Medium)** — the legal hold was ungoverned at the INSERT door. An `employee` at `aal2` (UPLOAD_DOCUMENT; no MANAGE_TENANT_SETTINGS) was refused placing a hold by UPDATE (`permission denied: MANAGE_TENANT_SETTINGS`) and then INSERTed a document born held, its reason, `legal_hold_changed_at` 2019-01-01 and `legal_hold_changed_by` = the owner all of its own choosing, with **no** `document_legal_hold_placed` event (a `critical` event type). It equally INSERTed an unheld document carrying the evidence of a "release" the owner never made. `app.guard_document_legal_hold` and `app.record_document_legal_hold_event` are UPDATE triggers. Medium: a forged compliance record naming the owner, and a document exempt from retention deletion (`app.suppress_held_retention_candidate`, `app.claim_storage_actions`) until a MANAGE_TENANT_SETTINGS holder releases it; the retention consequence is latent today only because no retention period is configured (RET-1).
- **ARCH-2's `documents` instance** — the same employee INSERTed a document born archived, `archived_by` = the owner, `archived_at` 2019, a reason of its own. `documents_enforce_archive_authority` is BEFORE UPDATE only.
- **ENTRY-1's `documents` instance** — the same employee INSERTed documents born `archived` (with `is_archived` false) and `superseded`, a state nothing writes (DOC-LC-2).
- **DOC-5 (Low)** — the version pointer was checked by a tenant-only FK. The same employee pointed its own document at another document's version — a confidential one it cannot see — and at NULL, by UPDATE, and INSERTed a document born pointing at that version. Low, and the bound is measured: every UPLOAD_DOCUMENT holder also holds CREATE_DOCUMENT_VERSION, the move is recorded (`document_superseded`, actor = the employee), no confidentiality is crossed (a version's visibility is its parent's), and retention fails closed when the pointer and `is_current` disagree. What is lost is that a document's current file is its own.
- **DOC-6 (Medium)** — PP-4's unmeasured half. `app.guard_write_capability` charges MANAGE_TENANT_SETTINGS for a `payment_proof` by the NEW type only. A `finance_manager` at `aal2` (no MANAGE_TENANT_SETTINGS; it cannot even see the `subscription_payment_proofs` row) was refused editing the owner's pending subscription payment proof, then retyped it to `receipt` with a new title in one statement, then — the parent now outside the class — added a version through `app.add_document_version`: the proof's current file became `forged.pdf`, uploaded by the finance manager, while the proof stayed `pending` for `app.platform_review_payment_proof`. (Retyping to `other` was refused, but by the RLS WITH CHECK because the row left the actor's view — an incidental defence, neutralised by choosing another financial type.)
- **DOC-LC-3 (Medium, registered, resolved as engineering and scheduled)** — a `branch_manager` archived a document through `app.archive_document` and moved `is_archived` back alone, leaving `archived/false`: a document neither write path will version while the boolean reports it live. Its decided fix is `lifecycle_status_code = 'archived'` ⟹ `is_archived`, which `69_document_lifecycle_test.sql` assertions 18-19 pin as known state today.

## Risks

- **Legitimate paths must still pass the guard.** Every creating RPC's INSERT is already the entry state, and every RPC pointer move is to the version it has just made current. Measured with the prototype installed on a clean reset: the whole suite (122 files, 2050 assertions) passed, the six HTTP suites exited 0 (449 assertions), and pgTAP Pass B passed after them.
- **Session-less and definer writers are admitted by `current_user = 'postgres'`**, the SPEC-214 shape. `service_role` holds no INSERT or UPDATE on `documents`, so no other session-less writer exists; the fixtures in `38_…`, `49_…`, `52_…`, `60_…`, `97_…` and `116_…` that move pointers as `postgres` pass unchanged.
- **The CHECK validates existing rows.** Primary was read on 2026-09-24 (read-only): 0 `documents` rows. The constraint is re-checked on Primary immediately before deployment.
- **A frozen type is new behaviour**: correcting a mistyped upload means uploading a new document, as QUO-6 did for a quotation's customer. No RPC, test, HTTP suite or view changes a document's type.
- **Primary deployment is irreversible** and is gated by an explicit owner authorization inside Step 7, not by this contract's approval alone.
- Not repairing leaves a compliance hold forgeable in the owner's name, the subscription payment proof's file replaceable by a role the payment path forbids, and two registered class instances open on this table.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-216-document-door-parity.md`
- `supabase/migrations/20260924140000_document_door_parity.sql`
- `supabase/tests/122_document_door_parity_test.sql`
- `supabase/tests/69_document_lifecycle_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607041900_create_document_core_tables.sql`
- `supabase/migrations/202607054400_document_write_integrity.sql`
- `supabase/migrations/202607057200_the_document_lifecycle_canon_defined_never_wired.sql`
- `supabase/migrations/202607058500_paying_for_your_plan_is_not_a_plan_feature.sql`
- `supabase/migrations/20260909180403_a_legal_hold_always_overrides_retention.sql`
- `supabase/migrations/20260924120000_quotation_door_parity.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/38_class_a_events_test.sql`
- `supabase/tests/46_document_write_integrity_test.sql`
- `supabase/tests/47_payment_proof_lifecycle_test.sql`
- `supabase/tests/61_created_by_is_derived_test.sql`
- `supabase/tests/80_subscription_licensing_test.sql`
- `supabase/tests/100_notification_delivery_lifecycle_test.sql`
- `supabase/tests/116_document_legal_hold_retention_override_test.sql`
- `scripts/verify_database.sql`
- `scripts/verify_storage_end_to_end.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`
- `reports/README.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`

## Required Reading

- `reports/master/MASTER_SURFACE_DISPOSITION.md` — the `documents` and `quotations` rows and the Coverage section
- `reports/master/MASTER_GAP_REGISTER.md` — DOC-LC-1 to DOC-LC-3, PP-4, ARCH-2, ENTRY-1, RET-1, and the `SUP-5` row the new rows follow
- `supabase/migrations/20260924120000_quotation_door_parity.sql` — `app.guard_quotation_integrity`, the shape reused
- `supabase/migrations/20260909180403_a_legal_hold_always_overrides_retention.sql` — the hold guard, its event and its retention consumers
- `supabase/migrations/202607054400_document_write_integrity.sql` — DOC-3, the version-row half of the current-version rule
- `ENGINEERING_METHOD.md §4` — the DATABASE protocol, and that Primary for this repository is only `vrvtsxexkiiiivlkdxzp`
- `reports/evidence/primary-ledger-evidence.json` — the current recorded Primary reading and its `read_query`

## Runtime Checkpoint

Resume Step: 7
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
| a BEFORE INSERT OR UPDATE guard on `public.documents` holds INSERTs to the entry state | `app.upload_document`, `app.upload_subscription_payment_proof` | VERIFY | Both INSERT `active`, unarchived, unheld and pointer-less, then point at the version they made current; new file 2 and 14, and `47_…`, `80_…`, `35_…` passed unchanged |
| same | `app.add_document_version` | VERIFY | Moves the pointer to the version it has just made current, which the pointer rule admits; new file 11 and 13 |
| same | `app.archive_document` and `documents_enforce_archive_authority` | VERIFY | Archiving is an UPDATE and moves both representations together; new file 18, `69_…` 1-17 unchanged |
| same | `app.set_document_legal_hold`, `documents_guard_legal_hold`, `documents_record_legal_hold_event` | VERIFY | Placing a hold is an UPDATE the guard does not judge; new file 22-23, `116_…` passed unchanged |
| same | `documents_enforce_status_transition`, `documents_guard_write_capability`, `documents_enforce_document_subscription_gate`, `documents_derive_created_by`, `documents_enforce_catalog_codes`, `documents_set_updated_at`, `documents_emit_superseded` | UNAFFECTED | Not named. BEFORE triggers fire by name, so `…enforce_status_transition` still refuses the HTTP suite's lifecycle PATCHes first (`verify_storage_end_to_end` 60 passed) |
| same | session-less and definer writers — migrations, the retention executor, and the fixtures that move pointers as `postgres` (`38_…`, `49_…`, `52_…`, `60_…`, `97_…`, `116_…`) | VERIFY | `current_user = 'postgres'` passes first; `service_role` holds no INSERT or UPDATE here. Whole suite passed with the prototype |
| a document's type is frozen after INSERT | `app.guard_write_capability` (strict `payment_proof` class read from NEW) and `app.enforce_document_version_integrity` (reads the parent's type) | UNAFFECTED | With the type frozen, NEW equals OLD and both readings are sufficient; new file 15-17 |
| same | `scope_isolation` (reads `document_type_code` through `app.is_financial_document_type`) | UNAFFECTED | A document's visibility class can no longer be moved by retyping; no RPC ever did |
| the pointer names only the document's own current version | `app.reconcile_document_storage`, `app.claim_storage_actions`, `app.platform_resolve_storage_finding` | UNAFFECTED | Each checks `is_current` and `current_version_id` together and fails closed on disagreement; the rule removes the disagreement at the door |
| `lifecycle_status_code = 'archived'` implies `is_archived` (CHECK) | `app.enforce_archive_authority`'s restore path on an archived document; `69_document_lifecycle_test.sql` 18-19 | WRITE | 18-19 are rewritten from the pinned split to its refusal; a restore on a document still `active` stays allowed (new file 21) |
| same | existing rows on Primary | VERIFY | Read-only 2026-09-24: 0 `documents` rows; re-read before deployment |
| a new trigger and trigger function | `10_grant_model_test.sql`'s PUBLIC-EXECUTE class assertion and the whole pgTAP suite | VERIFY | `revoke execute … from public` is part of Step 1; whole suite passed |
| same | the six HTTP suites | VERIFY | Each exited 0 against the prototype-installed stack (33, 120, 40, 74, 122, 60) |
| same | `reports/master/MASTER_API_CONTRACT.md` (GENERATED, Check L3) | VERIFY | Regenerated from the prototype-installed stack: byte-identical. In Write Scope because the Gate derives it for any migration contract |
| same | `scripts/verify_database.sql` | UNAFFECTED | Against the prototype: `ALL CHECKS PASSED (77 tables, … 71/621 catalog …)` |
| migration set 222 → 223, function surface +1, structural surface | `reports/evidence/primary-ledger-evidence.json`; `_ORVION_CANONICAL/manifest.md` `Live state:` | WRITE | Rewritten from a post-deployment Primary read (GUARD-1), never from a repository list |
| pgTAP suite 121 → 122 files and its declared assertion total | `_ORVION_CANONICAL/manifest.md` `Live state:` (Check 15) | WRITE | Remeasured after the new file lands, never incremented on paper |
| findings DOC-4, DOC-5, DOC-6; DOC-LC-3 closed; ARCH-2's and ENTRY-1's `documents` instances closed | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Check 22 rejects a disposition row citing an unregistered id |
| `documents` disposition and coverage 16 → 17 of 77 | `reports/master/MASTER_SURFACE_DISPOSITION.md`; the manifest's `Batch 6 surface coverage` line | WRITE | Check 22 recomputes the Coverage totals from the rows; Check 24 requires the cited file's `-- ATTACK-CLASSES:` line and a negative assertion |
| dated content added to both Master documents | Check 21 freshness headers | WRITE | Each document's `Last updated:` moves in the same step that adds its dated content |
| any | `scripts/batch6_select_target.ps1` | UNAFFECTED | Stores nothing and reads the disposition file; the row change removes this surface from its NOT-RECORDED candidates |
| any | `reports/README.md`; the manifest's `Narrative:` field | UNAFFECTED | No session report is written; this contract is the immutable evidence artifact, as `SPEC-215` did |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 7 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| pgTAP Pass A and Pass B, the six HTTP suites and `verify_database.sql` green on a clean reset that includes the migration | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 6 |
| Check 22 / Check 24 — disposition rows, Coverage totals, cited finding ids and the cited test file agree | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 6 |
| Check 21 — each Master document's `Last updated:` is not older than its newest dated content | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 6 |
| Check 9 / Check 19 — manifest migration figures and the recorded Primary ledger agree with the repository | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 8 | Step 10 |
| Check 15 — manifest declared assertion total equals the `plan(N)` sum | AFTER_IRREVERSIBLE_ACTION | Step 2 | Step 8 | Step 10 |
| Check 7 — `ai-map.json` live_state equals the manifest by value | BEFORE_COMPLETION | Step 8 | Step 9 | Step 10 |
| Check 5 — `_ORVION_CANONICAL/manifest.md` inside its 7000-character budget | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: The shape is reused verbatim from `app.guard_quotation_integrity` (SPEC-214, `20260924120000`): one SECURITY INVOKER BEFORE INSERT OR UPDATE guard, `postgres` admitted first, an INSERT arm holding the entry state and UPDATE arms holding what no RPC changes. But no existing control on `documents` holds the entry state or the pointer: its ten triggers guard capability, catalog codes, subscription state, the status machine on UPDATE, archive authority on UPDATE and the hold on UPDATE. **Rejected without being built:** (A) widening `documents_enforce_archive_authority` and `documents_guard_legal_hold` to INSERT (ARCH-2's generic remedy) — it would AUTHORIZE a document born archived or held for a holder, which no RPC produces, and a born-held document would then also need an INSERT event producer; refusing the non-entry state is what the RPCs define. (B) giving `app.status_transitions` an entry state (ENTRY-1's promotion) — declined for SPEC-214's reason, it changes INSERT behaviour on nine surfaces no slice has read. (C) charging MANAGE_TENANT_SETTINGS on the OLD type inside `app.guard_write_capability` for DOC-6 — it edits a function 26 tables share, and still lets any other retype move a document's visibility class; freezing the type closes both, and no RPC retypes. (D) a composite FK `(tenant_id, id, current_version_id) → document_versions (tenant_id, document_id, id)` for DOC-5 — it needs a new unique index and still admits NULL and the document's own superseded version. (E) REVOKE of INSERT/UPDATE — all five RPCs are SECURITY INVOKER and depend on the grant (the `trusted_devices` lesson). DOC-LC-3's CHECK is its registered, decided resolution, and a constraint holds on every door including `postgres`.

Added Property: at the `documents` table door, in any session, a document is created only `active`, unarchived, unheld and without a version pointer; its type never changes; its pointer moves only to its own current version; and on every door a document whose status is `archived` has `is_archived` true.

Causal Negative: reproduced against unmodified `2c907cd` on the local stack, each in one rolled-back transaction: an `employee` refused a hold by UPDATE INSERTed a document born held (placer = owner, 2019, no event) and one carrying forged release evidence; INSERTed documents born archived (archiver = owner, 2019), `archived`/false and `superseded`; repointed its document at a confidential version it cannot see and at NULL, and INSERTed one born pointing at it. A `finance_manager` without MANAGE_TENANT_SETTINGS retyped the pending subscription payment proof to `receipt` and replaced its file through `app.add_document_version`. A `branch_manager` left an archived document `archived/false`.

Positive Test Design: the RPC uploads documents; the table door creates a document in the entry state and edits its title; `app.add_document_version` moves the pointer; the owner files a subscription payment proof; `app.archive_document` archives; an archiver flips `is_archived` both ways on a document still `active`; the owner places a legal hold through its RPC, stamped and recorded once.

Negative Test Design: every refusal is an exact `throws_ok` SQLSTATE: `23514` for each of the four entry-state arms (born held, born with hold evidence, born archived with `lifecycle` active so only the archive arm can refuse, born `superseded`, born pointing), the three pointer attacks (another document's current version the caller CAN see, so visibility is not the refuser; NULL; the document's own superseded version), the retype, and the DOC-LC-3 restore; `42501` for the proof's version after the refused retype. Non-mutation is asserted by exact value after each group: the pointer string `2/true`, the proof `payment_proof/1`, the archived document `archived/true`. Every signed-in actor is at `aal2`; the `employee` holds UPLOAD_DOCUMENT and CREATE_DOCUMENT_VERSION and neither ARCHIVE_DOCUMENT nor MANAGE_TENANT_SETTINGS, asserted first; the `finance_manager` holds no MANAGE_TENANT_SETTINGS; the `branch_manager` holds ARCHIVE_DOCUMENT, so its refusal is the state rule.

Non-Empty Population Obligation: every assertion names its document by title and compares an exact value or SQLSTATE, so none can pass by selecting nothing; the completeness assertion (no document is `archived`/false) runs after an archived document exists in the tenant (18-20).

Mutation Obligation: each load-bearing predicate independently killed, applied to Step 1's migration text on the clean-reset stack and restored by re-applying that text: (M1) INSERT hold clause removed: 4, 5 red; (M2) INSERT archive clause removed: 6 red; (M3) INSERT lifecycle clause removed: 7 red; (M4) INSERT pointer clause removed: 8 red; (M5) type not frozen: 15, 16, 17 red; (M6) UPDATE pointer arm removed: 9, 10, 12, 13 red; (M7) pointer `document_id = new.id` removed: 9 red; (M8) pointer `is_current` removed: 12, 13 red; (M9) the CHECK dropped: 19, 20, 25 red. The unmutated text turns none red.

Post-Implementation Proof Obligation: `npx supabase test db` reports 0 failures and the assertions executed equal the sum of the literal `plan(N)` declarations across `supabase/tests`; the new file passes 25 of 25 and `69_…` passes 19 of 19.

## Implementation Steps

1. **Check:** a file matching `supabase/migrations/20260924140000_*.sql` exists. If present, record Already Applied. Otherwise create `supabase/migrations/20260924140000_document_door_parity.sql` containing a leading comment block that names `SPEC-216 / DOC-4, DOC-5, DOC-6, DOC-LC-3` and states the rule, followed by exactly these four statements and nothing else: (a) `create or replace function app.guard_document_integrity() returns trigger language plpgsql set search_path to ''` (SECURITY INVOKER) whose body returns `new` at once when `current_user = 'postgres'`; on INSERT raises `23514` when `lifecycle_status_code` is distinct from `'active'`, when `is_archived` is true or any of `archived_at`, `archived_by`, `archive_reason` is non-null, when `legal_hold_active` is true or any of `legal_hold_reason`, `legal_hold_changed_at`, `legal_hold_changed_by` is non-null, and when `current_version_id` is non-null, and otherwise returns `new`; on UPDATE raises `23514` when `document_type_code` is distinct from `old.document_type_code`, and when `current_version_id` is distinct from `old.current_version_id` and no `public.document_versions` row has that id, `document_id = new.id` and `is_current`; and otherwise returns `new`; (b) `revoke execute on function app.guard_document_integrity() from public;` (c) `create trigger documents_guard_integrity before insert or update on public.documents for each row execute function app.guard_document_integrity();` (d) `alter table public.documents add constraint documents_archived_status_is_archived_check check (lifecycle_status_code <> 'archived' or is_archived);`. The migration must not change any grant, policy, index, other constraint, other trigger or function.

2. **Check:** `supabase/tests/122_document_door_parity_test.sql` exists. If present, record Already Applied. Otherwise create it in the `begin; select plan(25); … select finish(); rollback;` shape, carrying the line `-- ATTACK-CLASSES: DOOR STATE PRIVILEGE BUSINESS TENANT=N/A CONCURRENCY=N/A REPLAY=N/A` with the reason for each `N/A` and for the undeclared AUTH, INPUT and OBSERVABILITY stated in the header, fixtures written as `postgres` (a tenant, an `employee`, an `owner`, a `finance_manager` and a `branch_manager`, a supplier, and the owner's confidential contract with one current version), and asserting in this order: 1 the employee holds UPLOAD_DOCUMENT and CREATE_DOCUMENT_VERSION and neither ARCHIVE_DOCUMENT nor MANAGE_TENANT_SETTINGS; 2 it uploads two documents through `app.upload_document`; 3 it INSERTs an `active` document at the table door and renames it; 4 a document born held with a placer, time and reason is refused `23514`; 5 one born unheld with hold evidence is refused `23514`; 6 one born `active` with `is_archived` true and archive fields is refused `23514`; 7 one born `superseded` is refused `23514`; 8 one born pointing at the owner's version is refused `23514`; 9 pointing its first document at its second document's current version is refused `23514`; 10 pointing it at NULL is refused `23514`; 11 `app.add_document_version` on it succeeds; 12 pointing it back at its own version 1 is refused `23514`; 13 its pointer string is `2/true`; 14 the owner files a subscription payment proof through its RPC; 15 the `finance_manager` retyping the proof to `receipt` is refused `23514`; 16 its `app.add_document_version` on the proof is refused `42501`; 17 the proof is `payment_proof` with one version; 18 the `branch_manager` archives the first document through `app.archive_document`; 19 its moving `is_archived` back alone is refused `23514`; 20 that document is `archived/true`; 21 it sets `is_archived` true and back to false on the second, still-`active` document; 22 the owner places a legal hold on that document through `app.set_document_legal_hold`; 23 it is held, `legal_hold_changed_by` is the owner, and exactly one `document_legal_hold_placed` event names it; 24 `documents_guard_integrity` is BEFORE INSERT OR UPDATE FOR EACH ROW (tgtype 23) and `authenticated` cannot execute its function; 25 no document is `archived` with `is_archived` false. Signed-in actors are at `aal2`.

3. **Check:** `supabase/tests/69_document_lifecycle_test.sql` assertion 18 is a `throws_ok`. If it is, record Already Applied. Otherwise replace the comment block headed `18-19. DOC-LC-3, PINNED AS KNOWN STATE` with one headed `18-19. DOC-LC-3, FIXED by SPEC-216 (`20260924140000`)` stating the implication and why it removes neither authority; change assertion 18 from `lives_ok` to `throws_ok(…, '23514', null, …)` on the same statement; and change assertion 19's expected value from `archived/false` to `archived/true`. Change nothing else; `plan(19)` is unchanged.

4. **Check:** `reports/master/MASTER_GAP_REGISTER.md` contains a row whose first cell is `DOC-4`. If present, record Already Applied. Otherwise insert, immediately after the `SUP-5` row and in the table's existing thirteen-column format, three rows — `DOC-4` (Medium), `DOC-5` (Low) and `DOC-6` (Medium) — each with a bold title, a category, `R`, batch `6`, `A`, `✅`, a status cell beginning `**✅ FIXED 2026-09-24 (SPEC-216, `20260924140000`).**` followed by the measured reproduction from this contract's Business Reason, the severity bound, and the repair in one sentence, an EMPTY Owner Decision cell, source `SPEC-216`, added `09-24`, updated `09-24`. In the existing `DOC-LC-3` row set the status marker to `✅` and prefix its status cell with `**✅ FIXED 2026-09-24 (SPEC-216, `20260924140000`) — the decided constraint; `69_…` 18-19 now assert its refusal.**`, keeping the rest. In the existing `ARCH-2` row append `**2026-09-24 (SPEC-216): `documents` closed — refused at entry rather than authorized, because no RPC creates a document archived; eleven tables remain.**` and set its updated cell to `09-24`. In the existing `ENTRY-1` row append `**2026-09-24 (SPEC-216): `documents` closed, the fourth instance, by one arm of a door-parity guard; eight tables remain. Promotion still declined for SPEC-214's reason.**` and set its updated cell to `09-24`. Prepend a new `Last updated: 2026-09-24 (…)` entry describing the slice and demote the current one to `Previously:` in the file's existing voice. Change no other row.

5. **Check:** `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `documents` row reads `NOT-RECORDED`. If it does not, record Already Applied. Otherwise set that row to disposition `PARTIAL`, assurance `ADVERSARIAL`, session `SPEC-216-document-door-parity`, findings `DOC-4, DOC-5, DOC-6, DOC-LC-3`, and a Next cell stating: that `122_…` pins them and `69_…` 18-19 now assert DOC-LC-3's refusal; that ARCH-2's and ENTRY-1's `documents` instances were closed by the same guard; the swept non-defects (tenant relocation, refused by `scope_isolation`; `created_by`, derived and immutable; confidentiality and title, editable by an actor who already holds the file, so no escalation; both doors agreeing at `aal1`; no DELETE grant; the subscription gate on every door); and the two axes probed but deliberately not classified — (1) event parity for a document created at the door (no `document_uploaded`, while its creator is server-derived; `quotations` names the same axis) and (2) `created_at` writable at the door, whose only reader is `app.financial_documents`' listing and whose question stands on every table with such a column — which is why the row is `PARTIAL`. Update the Coverage summary to `17 of 77 recorded · 6 `AUDITED` · 8 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 60 `NOT-RECORDED`` and its sentence to `All 17 recorded surfaces stand at `ADVERSARIAL``. In the same step, prepend a new `Last updated: 2026-09-24 (…)` entry for slice 16 and demote the current one to `Previously:`. Change no other row.

6. **Check:** the Execution Log contains an entry headed `Pre-deploy readiness gate`. If present, record Already Applied. Otherwise perform the gate and record every item's measured result in the Execution Log; the first item that does not hold is a STOP, and nothing is deployed while it stands:
   - a clean `npx supabase db reset` completed;
   - pgTAP **Pass A** (`npx supabase test db`) ran with 0 failures, and the assertions executed equal the `plan(N)` sum;
   - the six Additional Verification suites ran in the listed order, each exiting 0;
   - pgTAP **Pass B** ran after those suites with 0 failures;
   - `scripts/verify_database.sql` completed with `ALL CHECKS PASSED`;
   - the nine mutants of the Mutation Obligation were each applied to the text of Step 1's migration on the clean-reset stack and restored by re-applying that text, and each turned red the assertions this contract names for it; the unmutated text turned none red;
   - `pwsh -NoProfile -File scripts/generate-api-contract.ps1` regenerates `reports/master/MASTER_API_CONTRACT.md` byte-identically;
   - `git status --porcelain` shows no path outside this contract's Write Scope;
   - `supabase/migrations/` contains exactly one migration absent from the recorded Primary ledger, and it is the file Step 1 created;
   - `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` is run and its result recorded. Exactly three failure classes are admissible, all the same bounded undeployed state: `MIGRATION STATE DRIFT`; `SUITE FIGURE DRIFT`; and RECOVER-1 / Check 19 only when its `only in repository` set is exactly `20260924140000_document_door_parity` and its `only on Primary` set is empty. Any other failure is a STOP.

7. **Check:** `reports/evidence/primary-ledger-evidence.json`'s `ledger` array contains an entry beginning `20260924140000`. If present, record Already Applied. Otherwise, **first confirm that the owner has explicitly authorized Primary deployment of SPEC-216 after Step 6 was recorded, and record that authorization in the Execution Log; without it, set `Blocker:` to the owner gate and STOP here.** Then, in this order and stopping at the first step that does not hold: (a) confirm the target is project ref `vrvtsxexkiiiivlkdxzp` by reading it live through the `supabase-primary` connector, and that it is not Secondary `brplkqmbzffpxqgkkdzo`; (b) read Primary's migration ledger with the exact query recorded in the evidence file's `read_query`; (c) prove `20260924140000` is absent, the ledger equals the recorded evidence (same `migration_count` and `ledger_fingerprint`), and no `documents` row is `archived` with `is_archived` false; (d) apply ONLY Step 1's migration through the connector's migration-apply call; (e) if the connector assigns its own version, normalise that one row in Primary's ledger to `20260924140000`, as already done for `20260924130000`; (f) re-read Primary's full ledger with the same query; (g) rewrite the evidence file from that post-deployment reading, including the function-surface and structural-surface hashes read FROM Primary; (h) prove repository, local and Primary hold the same migration identities; (i) run `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1` and record its result. If any post-deployment operation fails, STOP and report Primary's exact state as read; do not re-apply and do not author a corrective migration.

8. **Check:** `_ORVION_CANONICAL/manifest.md`'s `Batch 6 surface coverage` line reads `17 of 77`. If it does, record Already Applied. Otherwise, after Step 7, update by measurement only: set that line to `17 of 77` (seventeen at `ADVERSARIAL`); remeasure and rewrite every mutable figure in `Live state:` — migration count and latest identity, ledger fingerprint, function-surface hash and function count, structural-surface hash and object count, test-file count and declared assertion total, and the HTTP assertion total — from measurement, never by incrementing; set `Last Completed` to SPEC-216 REPLACING the SPEC-215 entry; and set `Next capability` to Batch 6 Slice 17 ranked by `scripts/batch6_select_target.ps1`, keeping the standing facts that follow it. Do not modify `Narrative:`. The `Live state:` sentence may claim Primary parity only if Step 7 read Primary and proved it.

9. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` equal the manifest's by value. If they agree, record Already Applied. Otherwise regenerate with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and normalise the file to LF before committing. Repeat after every commit in this lifecycle that changes the manifest, including Approve and Complete.

10. **Check:** the Execution Log contains an entry headed `Post-deploy verification`. If present, record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1`, `pwsh -NoProfile -File scripts/check_primary_ledger.ps1` and `pwsh -NoProfile -File scripts/check_repository_consistency.ps1`, and record each exit code; all three must exit 0.

## Acceptance Criteria

- [ ] `supabase/migrations/20260924140000_document_door_parity.sql` exists and contains exactly the guard function, the revoke, the trigger and the CHECK constraint Step 1 names, and no grant, policy, index, other-constraint, other-trigger or other-function change.
- [ ] `public.documents` carries exactly one trigger executing `app.guard_document_integrity`, `documents_guard_integrity`, firing `BEFORE INSERT OR UPDATE` for each row; the function is SECURITY INVOKER and grants no `EXECUTE` to `PUBLIC`; and `documents_archived_status_is_archived_check` is present.
- [ ] Every RLS policy, grant and other trigger on `public.documents`, and every function other than `app.guard_document_integrity`, is identical to its definition at the start of this Change Request.
- [ ] `supabase/tests/122_document_door_parity_test.sql` exists, declares `-- ATTACK-CLASSES:` from the closed vocabulary, plans 25 and contains `throws_ok`; its signed-in actors are at `aal2` and include an `employee` holding neither ARCHIVE_DOCUMENT nor MANAGE_TENANT_SETTINGS and a `finance_manager` holding no MANAGE_TENANT_SETTINGS.
- [ ] `supabase/tests/69_document_lifecycle_test.sql` differs from its state at the start of this Change Request only in the 18-19 comment block, assertion 18 becoming a `throws_ok` with SQLSTATE `23514`, and assertion 19 expecting `archived/true`.
- [ ] `npx supabase test db` reports 0 failures and the assertions executed equal the sum of the literal `plan(N)` declarations across `supabase/tests`.
- [ ] The Execution Log records all nine mutants of the Mutation Obligation, each turning red the assertions this contract names for it, and the unmutated migration turning none red.
- [ ] `reports/master/MASTER_API_CONTRACT.md` is byte-identical to its state at the start of this Change Request.
- [ ] `reports/master/MASTER_GAP_REGISTER.md` carries `DOC-4`, `DOC-5` and `DOC-6` rows, FIXED by SPEC-216 with empty Owner Decision cells; `DOC-LC-3` is FIXED by SPEC-216; the `ARCH-2` and `ENTRY-1` rows record the `documents` closure; and its `Last updated:` entry is dated 2026-09-24.
- [ ] `reports/master/MASTER_SURFACE_DISPOSITION.md` records `documents` as `PARTIAL` / `ADVERSARIAL` citing `SPEC-216-document-door-parity` and `DOC-4, DOC-5, DOC-6, DOC-LC-3`, its Next cell names the closed class instances, the swept non-defects and the two unclassified axes, and its Coverage summary reads 17 of 77 with three `PARTIAL`.
- [ ] `reports/evidence/primary-ledger-evidence.json` names `project_ref` `vrvtsxexkiiiivlkdxzp`, contains `20260924140000` in its `ledger` array, and its `migration_count` and `ledger_fingerprint` are consistent with that array.
- [ ] The repository migration filename set, the local migration set and the Primary ledger recorded in that evidence file contain the same migration identities.
- [ ] `_ORVION_CANONICAL/manifest.md` records Batch 6 coverage as 17 of 77, names SPEC-216 as `Last Completed` in place of SPEC-215, names Batch 6 Slice 17 as `Next capability`, and writes every mutable `Live state:` figure from a post-deployment measurement.
- [ ] `ai-map.json`'s live_state copies of `Last Completed`, `Active Change Request` and `Next capability` match the manifest by value, and the file is stored with LF line endings.
- [ ] The Execution Log records the owner's explicit Primary deployment authorization before the deployment, and the pre-deploy readiness gate's measured result for every item.
- [ ] No file outside this contract's Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-24 — Steps 1-5

Outcome: Complete

Step results:
- Step 1: Applied — `supabase/migrations/20260924140000_document_door_parity.sql` placed from the prototype; SHA-256 `4c50fa437a3ed9c8cbaec4fcb5477454d07041c70d133c6fffea58baf9b3676c`, equal to the hash recorded in Notes, LF. The guard function, its revoke, the trigger and the CHECK only.
- Step 2: Applied — `supabase/tests/122_document_door_parity_test.sql` placed from the prototype; SHA-256 `e599ffad5a6ffcd2558e1f20ab6bf74e6e78067092bbba0abd50989d34d183af`, equal to Notes, LF; `plan(25)`.
- Step 3: Applied — `supabase/tests/69_document_lifecycle_test.sql` replaced by the revised prototype; SHA-256 `8bddf6b17de15e440ab8bef9663fc48e36bca8e05fa9cf2540972980aa7f1a13`, equal to Notes, LF. Its diff from `2c907cd` is confined to lines 184-212: the 18-19 comment block, assertion 18 `lives_ok` → `throws_ok(…, '23514', …)`, and assertion 19's expected value `archived/false` → `archived/true`; `plan(19)` unchanged.
- Step 4: Applied — `DOC-4` (Medium), `DOC-5` (Low) and `DOC-6` (Medium) after `SUP-5`, FIXED by SPEC-216 with empty Owner Decision cells; `DOC-LC-3` marked `✅` and prefixed FIXED; the `ARCH-2` row records `documents` closed (eleven tables remain) and the `ENTRY-1` row records the fourth instance (eight remain), both updated `09-24`; `Last updated: 2026-09-24`, prior entry demoted to `Previously:`.
- Step 5: Applied — `documents` `PARTIAL` / `ADVERSARIAL` citing `SPEC-216-document-door-parity` and `DOC-4, DOC-5, DOC-6, DOC-LC-3`, the Next cell naming the closed class instances, the swept non-defects and the two unclassified axes; Coverage 17 of 77 with three `PARTIAL`, 60 `NOT-RECORDED`; `All 17 recorded surfaces`; `Last updated: 2026-09-24`.

Commits: none for Steps 1-5. They stand applied in the working tree and are committed with the post-deployment steps, as SPEC-215 did, because repository consistency cannot be green while the migration is undeployed.

### 2026-09-24 — Pre-deploy readiness gate (Step 6)

Outcome: Blocked

Step results:
- Step 6: Applied — every item held:
  - clean `npx supabase db reset`: exit 0 (127 s); the reset database's ledger holds 223 migrations, latest `20260924140000`, and carries `documents_guard_integrity` and `documents_archived_status_is_archived_check`.
  - pgTAP **Pass A**: `Files=122, Tests=2050`, `Result: PASS` (65 s); the literal `plan(N)` sum across `supabase/tests` is **2050** over 122 files.
  - Additional Verification, in order, each exit 0: `verify_api_end_to_end` 33 passed, `verify_role_journeys` 120, `verify_care_journeys` 40, `verify_journey_branches` 74, `verify_lifecycle_branches` 122, `verify_storage_end_to_end` 60 — 449 in total, 0 failed (63 s).
  - pgTAP **Pass B** after those suites, no reset: `Files=122, Tests=2050`, `Result: PASS` (53 s).
  - `scripts/verify_database.sql`: `ALL CHECKS PASSED (77 tables, … 71/621 catalog …)`.
  - Mutants of Step 1's text on the clean-reset stack, each restored by re-applying that text, every apply now checked for errors: M1 red 4,5; M2 red 6; M3 red 7; M4 red 8; M5 red 15,16,17; M6 red 9,10,12,13; M7 red 9; M8 red 12,13; M9 red 19,20,25; the restored text 25/25, none red. After the run `app.guard_document_integrity`'s definition has the same md5 as after the reset (`4d197e4028f55b5e8fc5b8647169ed71`), with one trigger and the constraint present.
  - **Correction to the Notes' account of M1**, measured here: the harness's M1 text was malformed (its first replacement closed the parenthesis the second also closed), so the scripted M1 NEVER applied. The pre-Approval run 1 "survived" because the unmutated guard stayed installed; run 2's "killed by 4, 5" measured a correctly-formed M1 applied by hand just before and still installed. The kill itself was real — that hand-applied M1 turned 4 and 5 red in isolation — but "a full re-run reproduced every result" was the wrong reason. With apply errors now surfaced, the first gate run reported `M1 … APPLY FAILED … mismatched parentheses`; the corrected pair kills 4, 5 as listed above.
  - `scripts/generate-api-contract.ps1`: `MASTER_API_CONTRACT.md` byte-identical — `git status` shows no change to it.
  - `git status`: only the five Write Scope paths of Steps 1-5.
  - Exactly one migration absent from the recorded Primary ledger (evidence: `vrvtsxexkiiiivlkdxzp`, 222, `c12c7a06c9d6d9199f56bccc03456bfd`): `20260924140000_document_door_parity`; nothing only on Primary.
  - `check_repository_consistency.ps1`: 6 issues, all three admissible classes and nothing else — `MIGRATION STATE DRIFT` (count 222→223, latest, fingerprint → `6b346033368ea9439a1119a5af5d3fc2`), `SUITE FIGURE DRIFT` (files 121→122, assertions 2025→2050), RECOVER-1 with `only in repository` exactly `20260924140000_document_door_parity` and no `only on Primary` set. Checks 20, 21, 22 and 24 clean.
- Live Primary, read-only before the owner gate: count **222**, fingerprint `c12c7a06c9d6d9199f56bccc03456bfd`, latest `20260924130000`, `20260924140000` absent, `app.guard_document_integrity` and `documents_guard_integrity` absent, 0 `documents` rows (so 0 `archived/false`) — equal to the recorded evidence.
- Step 7: Not started — the owner has not authorized Primary deployment.

Commits: this commit (contract synchronization only; Steps 1-5 remain in the working tree for the reason recorded in the previous entry).

Blocker: Step 7 requires the owner's explicit authorization to deploy `20260924140000_document_door_parity.sql` to Primary `vrvtsxexkiiiivlkdxzp`. Nothing has been sent to Primary and Secondary has not been contacted.

## Verification Notes

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

Evidence gathered before this contract was frozen, all local, synthetic and rolled back unless stated. The reproduction ran at `2c907cd` against the migration set ending `20260924130000`. The candidate was then installed on the local stack for the suite runs.

- **Prototypes, LF line endings** (provenance only; they live outside the repository, so no step depends on reproducing their bytes): migration SHA-256 `4c50fa437a3ed9c8cbaec4fcb5477454d07041c70d133c6fffea58baf9b3676c`; new test SHA-256 `e599ffad5a6ffcd2558e1f20ab6bf74e6e78067092bbba0abd50989d34d183af`; revised `69_…` SHA-256 `8bddf6b17de15e440ab8bef9663fc48e36bca8e05fa9cf2540972980aa7f1a13`. The new file passed 25/25 on the prototype stack.
- **Cheapest check first:** before any full run, the 24 existing pgTAP files that name a document table or RPC were run against the prototype: 23 passed unchanged, and `69_…` failed exactly 18-19 — the two assertions pinning DOC-LC-3's split, which is what the constraint exists to refuse.
- **Whole suite:** with the candidate installed on a clean reset (reset 83 s) the whole suite passed (122 files, 2050 assertions; the literal `plan(N)` sum is 2050 over 122 files); the six HTTP suites then exited 0 (33, 120, 40, 74, 122 and 60 passed, 449 in total, 59 s); pgTAP Pass B after them passed again (122 files, 2050). `verify_database.sql`: `ALL CHECKS PASSED`. `MASTER_API_CONTRACT.md` regenerated with no diff.
- **Mutants**, measured against the final text: M0 none red; M1 red 4, 5; M2 red 6; M3 red 7; M4 red 8; M5 red 15, 16, 17; M6 red 9, 10, 12, 13; M7 red 9; M8 red 12, 13; M9 red 19, 20, 25. Restored text 25/25. **A harness artefact is recorded rather than counted either way:** the first matrix run reported M1 as surviving while its apply output was discarded; applied alone with its output visible, the same text turned 4 and 5 red, and a full re-run of the matrix reproduced every result above. A hand-written M1 confirmed the attack succeeds without the clause.
- **Not counted as mutants:** removing the `current_user = 'postgres'` admission tightens rather than weakens; a draft clause `dv.tenant_id = new.tenant_id` was removed before freezing because `document_id = new.id` and the composite FKs already imply it — it could never decide anything.

**Swept and classified in this slice, not registered**, each with the measurement that classified it:
- **Incidental defence, named:** retyping the payment proof to `other` was refused by `scope_isolation`'s WITH CHECK, because the row left the finance manager's view — not by any rule about the class. Retyping to `receipt` stayed visible and succeeded; that is DOC-6.
- **AUTH:** at `aal1` an `employee` succeeded through `app.upload_document` and through a direct INSERT alike — the doors agree.
- **Tenant:** `scope_isolation` holds `tenant_id` on INSERT and UPDATE, and the pointer, archiver, placer and creator FKs are tenant-qualified.
- **`created_by`:** derived on INSERT and immutable on UPDATE (`documents_derive_created_by`, `61_…`), so a door-created document is still attributed.
- **Confidentiality and title:** writable by an actor who can see and write the document; such an actor already holds the file, so un-marking it is disclosure by someone with access, not an escalation. A `payment_proof` stays under MANAGE_TENANT_SETTINGS for every edit.
- **DELETE:** `authenticated` holds none; the subscription gate covers INSERT, UPDATE and DELETE.
- **Two axes probed and deliberately not classified**, named in the disposition row: event parity for a document created at the door (it records no `document_uploaded`; its creator is server-derived and it carries no file until a version is added, which is recorded), and `created_at`, writable at the door and read only by `app.financial_documents`' listing — a question that stands on every table with such a column.

**Candidate selection**, recorded so it is not re-litigated: this contract's guard plus constraint was prototyped and passed everything above; (A)-(E) in Existing Mechanism were rejected without being built.
