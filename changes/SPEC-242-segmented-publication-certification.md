# Change Request — SPEC-242

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Permit a linear unpublished range of sequential completed Change Requests to pass its own scoped Gate and carry complete main-promotion workflow expectations in the existing certification receipt.

## Business Reason

SPEC-240 is deployed and Complete, SPEC-241 is Complete, and fifteen governed local commits remain unpublished because the current range Gate reports `AMBIGUOUS_GOVERNING_CR`. The rejected SPEC-240 candidate must not be promoted. This repository-only correction allows the accumulated work to be admitted, published, certified and synchronized without changing business or database behavior.

## Risks

A segment could wrongly borrow another CR's Write Scope, a historical violation could be hidden by a later correction, or a final receipt could omit Migration CI from the full main push. A dirty Finish could freeze incomplete changed paths. The tests and mutation obligations below target these failure modes. This contract makes no database write.

## Supersedes / Depends On

Depends on `changes/SPEC-240-a-google-ads-call-qualifies-as-a-phone-call.md` and `changes/SPEC-241-the-open-decision-pin-counts-three.md`, both Complete and immutable. This is a corrective successor only to SPEC-241's prospective four-workflow candidate publication instruction: the replacement push from rejected `66bf1b2b647f86771413c10dc7cb46de5a742da6` expects ORVION Acceptance, Agent Control and Repository Consistency; Migration CI belongs to the full main promotion. Neither terminal CR is superseded or edited.

## Write Scope

- `changes/SPEC-242-segmented-publication-certification.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-240-a-google-ads-call-qualifies-as-a-phone-call.md`
- `changes/SPEC-241-the-open-decision-pin-counts-three.md`
- `CR_LIFECYCLE.md`
- `scripts/publish_candidate.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`
- `reports/evidence/primary-ledger-evidence.json`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `changes/SPEC-241-the-open-decision-pin-counts-three.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A range can contain sequential Complete governors | committed-range Gate and ORVION Acceptance | WRITE | Validate each ordered segment with its own frozen Approved authority and existing committed-history checks; refuse an unfinished tail. |
| Segment validation must retain historic protections | allocation, terminality, evidence replay, status and manifest checks | VERIFY | Existing validators remain in the range path; adversarial tests attack each property. |
| Multi-Complete Finish expectations cover the full main push | `Write-Certification` and `Certify-Remote` | WRITE | Actual upstream/main-to-HEAD paths use the existing `Workflow-Expectations`; the existing receipt freezes names and remote certification consumes them unchanged. |
| A dirty tree can add a later committed promotion path | Finish and completion fingerprint | WRITE | Refuse dirty multi-Complete Finish before minting a receipt; retain the current fingerprint and completion check. |
| Publication and current-state handoff | candidate publisher, manifest and ai-map | VERIFY | The existing pinned-lease publisher and exact-SHA promotion remain unchanged; regenerate ai-map from manifest. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE; repository edits and commits precede the separate governed publication sequence.

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| New adversarial tests and control implementation agree | BEFORE_COMPLETION | Step 1 | Step 2 | Step 3 |
| Full range and frozen main workflow receipt pass | BEFORE_COMPLETION | NONE | NONE | Step 4 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: Reuse contract parsing, frozen-authority and per-commit range validation, `Workflow-Expectations`, the local receipt and `Certify-Remote`; none currently partitions multiple completed governors or includes prior unpublished main-promotion paths in a final receipt.

Added Property: Each completed segment is judged by its own Approved CR, an unfinished tail is refused, and multi-Complete Finish freezes workflow names for the actual full clean main-promotion diff.

Causal Negative: The current `6c48fbb8e5df18f8b76315b2e3563b741360bfe9..f616ff98a756ed7a4370fc2532e10b8aba3e3dfb` Gate returns `AMBIGUOUS_GOVERNING_CR`; final-scope-only expectations omit Migration CI; a dirty in-scope workflow path can be certified and later committed with unchanged bytes.

Positive Test Design: Sequential A→B and A→B→C Complete ranges, the SPEC-240→241→242 topology, valid Complete plus Cancelled, final HEAD corrections, clean Finish, unchanged single-contract semantics and successful exact-target remote runs pass.

Negative Test Design: Refuse cross-segment or transient scope violations, frozen-scope widening, terminal mutation, illegal/overlapping lifecycle, unfinished tail, ambiguous same-commit completion, dirty Finish, and absent or failed required workflow evidence; retain wrong-SHA, wrong-branch and moved-target refusals.

Non-Empty Population Obligation: Prove non-empty accepted and rejected segmented ranges, clean and dirty Finish cases, absent/failed/running/successful required-run cases, plus mutation kills against real fixtures.

Mutation Obligation: Independently remove per-segment validation, permit later scope to cover earlier work, remove unfinished-tail refusal, remove clean-tree refusal, and revert multi-Complete expectations to final-CR scope; for each show the mutant installed, targeted test red, exact bytes restored and targeted test green. Do not count equivalent mutants.

Post-Implementation Proof Obligation: All existing Agent Control tests and new SPEC-242 cases pass with no regression; four guard suites, repository consistency and `git diff --check` pass; canonical `-Finish` returns `LOCAL_CERTIFY: READY` with Agent Control, Repository Consistency and Migration CI expected for main; the actual full three-contract Gate passes while the old Gate fails `AMBIGUOUS_GOVERNING_CR`.

## Implementation Steps

1. Check whether the SPEC-242 segmentation and certification assertions already exist in `scripts/test_agent_continuity.ps1`; if absent, add fixtures for every positive, negative and mutation obligation above without changing existing assertions. If only a subset exists, stop rather than silently substituting a different proof.
2. Check whether `scripts/check_agent_continuity.ps1` already validates separately completed range segments and derives multi-Complete receipt expectations from a clean full upstream diff; if absent, add the smallest hooks around the existing committed-range validator, governor resolver and certification writer. Keep final-state-only checks at final HEAD, single-contract behavior and `Certify-Remote` unchanged. If partially present, stop.
3. Check for a SPEC-242 Execution Log entry recording the test-first red and repaired green evidence; if absent, run targeted cases and the five required mutation attacks, restore the intended bytes after each, run the full Agent Control suite and four guard suites, repository consistency and `git diff --check`, then append the observed results.
4. Check for a canonical SPEC-242 `LOCAL_CERTIFY: READY` entry; if absent, commit the coherent implementation and review evidence to make the tree clean, run `-Finish`, inspect the frozen receipt and append its actual result. Independently review every Acceptance Criterion and Review Gate item, then record `Verdict: Confirmed Complete` only if proven.
5. Check whether SPEC-242 is already Complete with manifest and ai-map synchronized; if absent, complete it under the receipt, update only the manifest's current module, active pointer, last completed and next capability, regenerate `ai-map.json`, commit, and require a clean full `origin/main..HEAD` Gate before publication.

## Acceptance Criteria

- [x] Every sequential Complete segment is range-validated under its own frozen Approved CR; the actual SPEC-240→241→242 range reaches `ORVION: READY`.
- [x] Historical allocation, per-commit scope/status, terminal immutability, Approval Evidence replay, valid Complete plus Cancelled and final-HEAD repair behavior remain covered by passing positive and negative cases.
- [x] An unfinished tail and ambiguous same-commit completions are refused; no later CR authorizes earlier work.
- [x] Multi-Complete `-Finish` refuses dirt and freezes expected names from actual upstream/main-to-HEAD paths through the existing matcher and receipt; single-contract semantics remain unchanged.
- [x] Missing or failed expected Migration CI cannot certify a main promotion; running is PENDING, all exact target-branch successes are READY, and wrong SHA/branch/moved target remain refused.
- [x] No terminal CR, publisher, workflow, Supabase file, Primary evidence, application file or unrelated report changes.

## Execution Log

- 2026-09-30: Test-first run against the previous control returned 305 passes and 14 failures in the new segmented cases. Implemented ordered completion segments using the existing per-commit validator and one shared terminal-state table; each segment retains its own frozen Approved scope and Approval Evidence replay. An active successor exposed a real same-commit ambiguity escape, so the segment finder explicitly refuses it. No terminal CR or publication script changed.
- 2026-09-30: The focused block passed 27/0, including six installed, killed and byte-restored mutants. The full Agent Control suite passed 331/0. Future-date, status-contradiction, recorded Primary-ledger and cold-start guard suites passed 18/0, 33/0, 13/0 and 34/0. Repository Consistency was CLEAN and `git diff --check` passed. A clean disposable clone carrying the actual SPEC-240 and SPEC-241 commits plus a synthetic SPEC-242 Complete transition returned `ORVION: READY` for the full base-to-HEAD Gate. The live In Progress range still refused its unfinished tail as `SEGMENT_TRAILING_WORK`.
- 2026-09-30: With implementation committed at `fd638c5efc7998bfdc362c5495065170bff00898` and a clean tree, canonical `-Finish` passed Agent Control, all four control guard suites, Repository Consistency and `git diff --check`; it returned `LOCAL_CERTIFY: READY`. The existing receipt targets `main` and freezes exactly Agent Control, Migration CI and Repository Consistency, derived from the full upstream-to-HEAD changed paths.

## Verification Notes

Independent Review, 2026-09-30: The committed SPEC-242 range changed exactly the five scoped paths, while implementation after In Progress changed only this CR and the two control scripts. SPEC-240 and SPEC-241 remain Complete and unmodified. The new segment walk reuses the existing frozen-authority and per-commit checks; its shared terminal state, overlap refusal and unfinished-tail refusal are exercised by positive, negative and mutation cases. The full real SPEC-240→SPEC-241→synthetic SPEC-242 Complete range was READY in a clean disposable clone; the exact production Complete SHA will be checked again immediately after its commit. The canonical clean-tree receipt is READY with the three expected main workflows. Every Acceptance Criterion and Review Gate item was checked against the committed implementation, test results, receipt and scope diff. No unresolved business, legal, database or architecture decision was introduced.

Verdict: Confirmed Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] The Depends On contracts remain Complete and immutable; no terminal Status is changed.
- [x] The repository is in a clean, releasable state.

## Notes

Publication is POST_COMPLETION evidence, not an Acceptance Criterion on an SHA that does not yet exist. After the exact Complete commit `C` passes the full Gate: fetch and verify both remote refs; use `scripts/publish_candidate.ps1 -ReplaceExpectedSha 66bf1b2b647f86771413c10dc7cb46de5a742da6` to replace only the rejected preflight ref; require exact-`C` ORVION Acceptance, Agent Control and Repository Consistency success with no observed failure; fetch and confirm `origin/main` is unchanged; push exactly `C` to `main` by ordinary fast-forward; require the three workflow names frozen in the receipt to succeed on the `main` push; run canonical `-Certify` for `REMOTE_CERTIFY: READY`; fetch and verify local `main`, `origin/main` and `origin/orvion-preflight` equal `C`, ahead/behind are zero and the tree is clean. Stop on a moved ref, red/pending candidate or failed certification. Do not add work from the later Phase-8 backlog to this publication.
