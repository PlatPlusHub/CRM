# Change Request — SPEC-125

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Close every documentation, tracking, and guard-design defect found by the 2026-08-21 remediation pass, so that no finding remains recorded only in prose, no closed row hides open work, no recorded claim is false, and the consistency guard can actually detect the invariant it was written to protect.

---

## Business Reason

The Ground Truth Audit and the remediation pass that followed found that ORVION's *implementation* is in materially better shape than its *records*. Three classes of defect all share one consequence — a future session reading the repository would have believed something untrue:

1. **A closed row hiding open work.** The Future Backlog struck through "Reference Data Layer — core (countries, nationalities, languages, currencies)" as DONE, but three of those four tables hold zero rows. The deferral is legitimate and governed at migration level; closing the row erased its only forward tracking.
2. **Recorded claims that were false.** The backlog asserted `authenticated` was "fully locked" with no DML — untrue in the repository's own migrations and further untrue on live Primary. `manifest.md` and the Integration Catalog recorded `record_offline_conversion` as executable by `orvion_integration` — a privilege-level fact with no functional meaning.
3. **A guard that could not see its own invariant.** Check 5 exists to stop `manifest.md` becoming a changelog. It passed at 60 lines while the file was 13,556 characters, because one field had grown to a 5,609-character paragraph. Cold-boot cost is paid in characters, not newlines.

`GOVERNANCE.md §19` requires every historical recommendation to reach a terminal state and forbids leaving one to accumulate. Two findings (`REF-1`, `CAT-1`) existed only in prose or in an immutable historical report and had never reached the findings SSOT.

---

## Risks

Very low — documentation, one canon status note, and one guard script. No schema change, no migration, no live database write. The single behavioural change is that `scripts/check_repository_consistency.ps1` now fails on two additional manifest conditions; that is the intended effect and the manifest was trimmed in the same change so the guard reports CLEAN.

---

## Supersedes / Depends On

Depends on `changes/SPEC-124-restore-least-privilege-grant-model.md` (this CR records SEC-1/SEC-2/DOC-1, which SPEC-124 produced). Supersedes nothing.

---

## Scope — Files Allowed to Modify

- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/future-backlog.md`
- `_ORVION_CANONICAL/25_catalog_registry.md`
- `_ORVION_CANONICAL/manifest.md`
- `scripts/check_repository_consistency.ps1`
- `.workstation/manifest.md`
- `ai-map.json` (regenerated, never hand-edited)
- `changes/SPEC-125-remediation-governance-reconciliation.md`

---

## Out of Scope — Files Forbidden to Modify

- `AGENTS.md`, `GOVERNANCE.md`, `README.md`, `CR_LIFECYCLE.md`
- `supabase/migrations/**` (SPEC-124 owns the only migration in this pass)
- `reports/history/**` (immutable)
- `repository-index.md` (auto-generated; its canon-only scope is correct and current)

---

## Minimum Reading List

- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/future-backlog.md`
- `_ORVION_CANONICAL/25_catalog_registry.md`
- `_ORVION_CANONICAL/manifest.md`
- `scripts/check_repository_consistency.ps1`
- `.workstation/manifest.md`

---

## Implementation Steps

1. Verification check: `MASTER_GAP_REGISTER.md` contains `SEC-1`. If absent, add eight rows — SEC-1, SEC-2, SEC-3, REF-1, CAT-1, PH8-7, PH8-8, DOC-1 — and update the register's `Last updated` line without editing any existing row.
2. Verification check: `future-backlog.md` contains "ROW WAS FACTUALLY WRONG". If absent, correct the DML-grants row with the true state and point the residual question at SEC-1.
3. Verification check: `future-backlog.md` contains "structure DONE, SEED still open". If absent, re-scope the reference-data row to track the seed half with an explicit trigger.
4. Verification check: `25_catalog_registry.md` `functional_role_code` section contains a `Status:` block. If absent, mark it superseded by `department_type`, retained not deleted.
5. Verification check: `check_repository_consistency.ps1` contains `$manifestCharBudget`. If absent, add character and per-line budgets to Check 5.
6. Verification check: `manifest.md` is under both budgets. If not, trim it to current state only and regenerate `ai-map.json`.
7. Verification check: `.workstation/manifest.md` says `Last curated: 2026-08-21`. If not, re-verify every tool version by executing it and record only observed values.
8. Verification check: `MASTER_INTEGRATION_CATALOG.md` `§2a` says "all eight". If not, add corrections 7 and 8 and the remediation-pass checkpoint to `§4`.

---

## Acceptance Criteria

- [x] Eight new rows exist in `MASTER_GAP_REGISTER.md`; no pre-existing row was modified.
- [x] The false "fully locked" claim is corrected and its residual question is carried by SEC-1.
- [x] The reference-data row tracks the seed half with an explicit, testable trigger.
- [x] `functional_role_code` is marked superseded in canon, retained not deleted.
- [x] Check 5 enforces line, character, and per-line budgets, and was demonstrated failing on the pre-trim manifest.
- [x] `manifest.md` is under every budget (63 lines / 6,491 chars, from 60 / 13,556).
- [x] `.workstation/manifest.md` records only versions observed on 2026-08-21, with unverifiable entries marked as such.
- [x] `§2a` documents eight mandatory corrections with sources and check dates.
- [x] `pwsh -File scripts/check_repository_consistency.ps1` prints `REPOSITORY CONSISTENCY: CLEAN`.

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (remediation pass)

Outcome: Complete

Step results:
- Step 1: Applied — eight rows added (SEC-1/2/3, REF-1, CAT-1, PH8-7/8, DOC-1); prior `Last updated` entry preserved beneath the new one.
- Step 2: Applied — row rewritten with both halves of the falsehood stated explicitly.
- Step 3: Applied — row re-scoped; trigger recorded as the first consumer needing a real country/nationality/language.
- Step 4: Applied — `Status:` block added, mirroring the `finance_approval_type` supersede precedent.
- Step 5: Applied — `$manifestCharBudget = 7000`, `$manifestLineCharBudget = 1200`.
- Step 6: Applied — guard first demonstrated FAILING on the untrimmed manifest (13,428 chars; line 28 at 5,609), then manifest trimmed to 63 lines / 6,491 chars and `ai-map.json` regenerated.
- Step 7: Applied — Git 2.55.0.windows.4, Node v24.19.0, Docker 29.6.2, Python 3.12.10, PowerShell 7.6.5 observed; VS Code and the exact Supabase CLI version marked unconfirmed rather than carried forward.
- Step 8: Applied — corrections 7 and 8 added with sources; `§4` checkpoint records the DOC-1 correction and SPEC-124's effect on the integration surface.

Evidence: guard output before the trim showed both new conditions firing; after the trim, `REPOSITORY CONSISTENCY: CLEAN`.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (remediation pass)

Verdict: Confirmed Complete

Findings: The guard was verified in both directions, which is the only way to know a guard works — it was observed **failing** on the exact pre-existing defect (`manifest.md is 13428 characters (budget 7000)` and `line 28 is 5609 characters (budget 1200)`) before the manifest was touched, and CLEAN afterwards. Every recorded workstation version was obtained by executing the tool in this session; the two values that could not be observed are marked unconfirmed rather than restated on trust, which is the behaviour the audit found missing. The register's existing rows were re-read after editing to confirm none was altered.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state.

---

## Notes

**Approval basis.** Authored and executed under the owner's directive of 2026-08-21 ("Full Remediation, Hardening & Governance Completion Pass"), which explicitly commissioned governance completion and required that no finding remain silently forgotten, orphaned, or falsely marked complete.

**What this CR deliberately did NOT do.** Per §23 of that directive, no problem was closed by relabelling it. `REF-1` was re-opened rather than re-closed, and its resolution is still pending — the migration-level deferral it restores was already governed, so re-tracking it is the fix; seeding 249 ISO countries by hand ahead of any consumer would fail Earn-It and risk transcription errors in data that only matters once a real consumer exists. `CAT-1` is recorded as an open low-severity integrity gap with a named next action, not converted into an "intentional design decision" — SPEC-024 F1 recorded only that no canonical document *required* the FK, which is not the same as deciding against it. `SEC-3` is the one item closed as accepted, and only because the closure rests on a live privilege check rather than on an assertion.
