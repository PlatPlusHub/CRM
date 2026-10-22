# Change Request — SPEC-294

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Lawfully complete this repository's already-implemented Contract B capability through a carrying successor, with satisfiable pre-Complete acceptance and post-Complete candidate binding.

## Business Reason

The original contract was cancelled by explicit human decision because its frozen criterion required binding before Complete while the native binder requires Complete. Preserve correct source, independent native authority and earned evidence; correct only the temporal contract and its own lifecycle bookkeeping.

## Risks

A new identity invalidates the old receipt for successor certification. A missing carrying relationship makes the cancelled publication segment inadmissible. Code identity and historical test evidence are not authenticated owner identity. No source modification, engine exception, release, hosted certification or credential change is authorized. CTRL-19 remains OPEN; Batch 6 and Phase 8 remain ON HOLD.

## Supersedes / Depends On

Carries the cancelled original. Exact owning path: `changes/SPEC-293-contract-b-local-interfaces.md`.
The original implementation and native Finish are historical evidence, not this successor's certification. Baseline cancellation commit: d2deeb70c42bd5bfa89e512773aaa50828573dd4.

## Write Scope

- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

All existing source, tests, native engines, lifecycle and governance documents, the cancelled original contract, credentials, configuration, workflows, migrations and databases are forbidden to modify. The successor's own workflow sections are writable only under native synchronization rules. No source replay or artificial implementation delta is permitted. Publication, promotion, remote certification, Workbench, retirement and product work are outside this contract.

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/TEMPLATE.md`
- `changes/SPEC-293-contract-b-local-interfaces.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: SPEC-294-V1 fixes the temporal contract using only native lifecycle bookkeeping, explicitly carries the cancelled original and checks all fourteen already-correct payloads rather than replaying them. The native scope derives REPOSITORY; unchanged source and control engines do not become new writes.

Pass 2 Adversarial Review: SPEC-294-V2 challenges every acceptance/review item's earliest evidence state, false pre-Complete binding, wrong-subject receipts, omitted carry relationship, scope expansion, dirty state and source drift. Actual sandbox outcomes are preserved in the companion evidence; no result is inferred from a zero exit alone.

Pass 3 Evidence Refresh: 2026-10-22. SPEC-294-V3 refreshes the exact cancelled baseline, native allocator, frozen source, native stage ordering and proportionate primary-source comparison. NIST SSDF published final versus draft status, SLSA subject-bound verification, Lamport safety/liveness reasoning and official Git clone isolation are distinguished from unearned infrastructure. Actual isolated lifecycle proof and final review must pass before the Draft is frozen for Gate 1.

Selected Version: SPEC-294-V3, selected only with the companion final evidence: retains V1 simplicity, records V2 attacks and V3 authoritative comparison, no source or native policy changes and no invented differences. Exact frozen UTF-8 LF bytes and Git-stored identity govern approval.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Contract identity and cancelled segment carry | Native allocation, transition walk and publication segments | VERIFY | Native allocation selects this identity; the exact old relative path is declared above; the final full-range Gate proves carrying |
| Current active pointer and completion bookkeeping | Native Boot, manifest and generated discovery | WRITE | Only the manifest and its two generated projections are scoped; no active Draft or terminal active pointer |
| Existing fourteen payloads and native test engines | Source identities, native criterion checks and historical verification | VERIFY | Exact blobs remain unchanged; code is not replayed; mandatory profiles derive from actual authorized write surface |
| New certification identity and later candidate record | Native Finish, Review, Complete and binding | VERIFY | Fresh native successor receipt is mandatory; binding follows Complete and is never a pre-Complete checkbox |
| Credentials, release and hosted acceptance | Existing owning native authorities | UNAFFECTED | No release or authentication permission; local rehearsal never proves hosted certification |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact cancelled baseline, preserved payloads and frozen original | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Legal active pointer and generated discovery | BEFORE_COMPLETION | NONE | NONE | NONE |
| Fresh successor receipt and truthful pre-Complete Review | BEFORE_COMPLETION | NONE | NONE | NONE |

## Implementation Steps

1. Check whether all fourteen payload blobs listed in Acceptance Criteria and the cancelled original blob match current Git and working content. If every identity matches, record Already Applied: inherited source preserved. Otherwise STOP; do not edit, create, delete or replay any source. Check that this contract is Approved, was allocated as the exact owner-approved Draft and names the exact cancelled predecessor path before continuing.

2. Check whether this contract is already In Progress with an Execution Log entry recording inherited source verification. If so, record Already Applied. Otherwise change only its Status from Approved to In Progress, append the actual inherited-source verification outcome, and retain the manifest's sole active pointer to this contract. No acceptance checkbox is ticked by implementation.

3. Check whether Resume Step is DONE, Blocker is None and generated discovery reproduces from its source. If so, record Already Applied. Otherwise synchronize only this contract's Runtime Checkpoint to DONE / None / 0 and run `pwsh -NoProfile -File scripts/generate-ai-map.ps1`; retain the already-authorized active pointer. Stage only this contract and the three Write Scope paths, and commit the coherent In Progress boundary through the normal native hook. Do not run a profile or Additional Verification command here. Native timed/watched Finish runs once at the subsequent certification boundary.

## Acceptance Criteria

- [x] Existing source remains exact; `check: blob AGENTS.md 708b72b2eada57e532cc5cc3be3115c1a5731b89`
- [x] Existing source remains exact; `check: blob scripts/agent/apply-draft-steps.ps1 523463176334e939c972d0393ad2d0696e40701a`
- [x] Existing source remains exact; `check: blob scripts/agent/Invoke-DraftSteps.ps1 61621cca3e081e3a786e19c168e44d05bae3253f`
- [x] Existing source remains exact; `check: blob scripts/agent/test-draft-steps.ps1 8aefb21e60d7aef7b8429ada3ec89289f1bb01c5`
- [x] Existing source remains exact; `check: blob scripts/agent/Test-ScriptHazards.ps1 24e364f49a1bc825afcb51fc906bd0eb83a7912d`
- [x] Existing source remains exact; `check: blob scripts/check_agent_continuity.ps1 3c0a09d3622529fd9c2d5e66f5f29a1548bdf92f`
- [x] Existing source remains exact; `check: blob scripts/github_public_read.ps1 6493a2f5cbf8f65f4e479b0c172e30b1f3521cae`
- [x] Existing source remains exact; `check: blob scripts/owner_promote.ps1 47aaa9eb76e5cec86dc4eab8f158050e520e71c0`
- [x] Existing source remains exact; `check: blob scripts/owner_publish.ps1 da783193f728d1a99cbda1431d03fdb57dc24f34`
- [x] Existing source remains exact; `check: blob scripts/test_agent_continuity.ps1 0bf297c9db4f39b8b9297b0af02a3a812ce3e427`
- [x] Existing source remains exact; `check: blob scripts/test_github_public_read.ps1 e7f65ceebfc7f15fb96d4b46150ca0d8d26e6792`
- [x] Existing source remains exact; `check: blob scripts/test_owner_interfaces.ps1 e8fb155bcadc567a2ab0dd3d7707691de5bc504a`
- [x] Existing source remains exact; `check: blob scripts/watch_run.ps1 ed8d956b9f2e8ebeacf1942b68424e452773641b`
- [x] Existing source remains exact; `check: blob scripts/watch_selftest.ps1 e0121cf17ab38a0cfa77fc706f35c01d0ac1416f`
- [x] The cancelled original is immutable and retained; `check: blob changes/SPEC-293-contract-b-local-interfaces.md 478339a312931a6473f6179067deb23325bb56e1`
- [x] Native lifecycle, governance, hooks, CI and release engines retain their cancellation-baseline bytes; independent Review verifies unchanged out-of-scope paths and actual scope closure.
- [x] The observed In Progress implementation state had this contract as the sole active pointer with fresh generated discovery and a clean committed implementation boundary. Review verifies that recorded state; this item does not require the future Complete state to exist.
- [x] A real required timed/watched native Finish succeeded for this exact successor identity and implemented state, emitted LOCAL_CERTIFY READY and produced a fresh matching native receipt; all actual required command results and evidence have been read. The cancelled original's receipt is not substituted.
- [x] The recorded independent live Review checked every acceptance item and Review Gate item against evidence available in the reviewed In Progress state; no pre-Complete claim depends on binding, publication, hosted CI or remote certification.

## Review Gate

- [x] Exact approved Draft allocation, cancelled baseline, predecessor carry path and fourteen unchanged payloads are independently verified against actual Git and working content.
- [x] Every acceptance/review item's required evidence can exist no later than In Progress Review; the temporal audit and actual native sequence support this conclusion.
- [x] The fresh native receipt matches this successor identity, derived profiles and implementation fingerprint; required verification actually passed and no historical receipt has been relabelled.
- [x] Scope, protected authority, clean implementation state and generated artifacts are verified; no source change, unrelated work, credentials, release or policy weakening occurred.

## Execution Log

None.


UTC 2026-10-22T21:07:04Z - Exact approved steps1-3: all fourteen inherited source files and immutable cancelled predecessor verified against Git and working bytes. Source Already Applied: preserved; no source replay or artificial delta. Own Status and Runtime Checkpoint synchronized to In Progress / DONE / None / 0, sole active pointer retained and generated discovery refreshed. Required original timed/watched native Finish is next; no certification is inferred from implementation.

## Verification Notes

None.


Approval Evidence: explicit human Gate 1 approved this exact Draft SHA-256 DEC9804010F11A0F5D19A2F3DB9C36983C635054E0061C9A952CDE1C34034AF2. Preserved owner decision SHA-256 C78CD7F52D83D07F66053EF2191743A26C0216A10B9EB2BE064F2272B350EA18. This approval covers only the stated local carrying lifecycle, fresh native verification, Review/Complete and local candidate binding. No publication, promotion, remote change or unrelated implementation is authorized. Recorded by Codex; local hashes are not actor authentication.


UTC 2026-10-22T21:09:35Z - Independent live Review read exact approved allocation, all fourteen unchanged source identities, immutable cancelled predecessor, actual scope and sole In Progress pointer, real original timed/watched Finish READY/END0 with each required command PASS, and this contract own fresh native receipt 6bb58313f67a20e8288c437d0667312702531368eef7625e3cf6d94b02e73201 with verified digest/profiles/fingerprint/finishHead. All19 Acceptance Criteria and4 Review Gate items are supported by evidence available in the reviewed In Progress state. No binding, publication or remote result is claimed.


Verdict: Confirmed Complete

## Notes

Approval authorizes only the stated local carrying lifecycle. After genuine native Finish and truthful Review, Complete synchronizes Status and clears the manifest active pointer, updates Last Completed to this capability and regenerates discovery through the existing native procedure. Only after that completion commit may the owning `-Gate -BindCandidate` bind the unchanged fresh successor receipt to its exact full SHA. Prove the full original upstream-to-candidate range carries the cancelled original; do not publish a cancelled-only range. Keep a named pending-tail branch. Publication, hosted acceptance, owner promotion and exact-SHA remote certification remain later separately authorized operations. No acceptance checkbox requires any of these future observations.

Evidence classes: original Finish/receipts/commits remain historical; unchanged-input preparation remains preparation; old approval/receipt/review cannot certify this identity; fresh derived native Finish, Review, Complete Gate and actual post-Complete binding are required for this successor. The narrow Write Scope is not a verification exemption: this successor changes no native source or control mechanism, the existing source identities are machine-checkable acceptance, and original native CONTROL evidence remains preserved without being relabelled as this successor's execution.
