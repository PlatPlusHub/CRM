# Change Request — SPEC-163

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close the remaining Agent Control Plane state, capability and evidence invariants, repair confirmed semantic-pointer drift, and relocate owner-ratified methodology out of the automatically-read operating kernel into one routed authority without weakening any rule.

## Business Reason

Three measured weaknesses remain after `SPEC-160` and `SPEC-162`.

First, the manifest-to-Change-Request state invariant is incomplete in both directions. `CR_LIFECYCLE.md §8` declares that an `Approved` or `In Progress` Change Request with no active pointer is rejected, but the implementation only inspects Change Requests present in the current diff, so a pre-existing orphan is invisible. The reverse direction has no rule at all: a manifest pointing at a `Draft` Change Request makes Boot print that contract's full `Write Scope` on its `WRITE:` line, which directly contradicts `AGENTS.md §1`. A weaker agent reading `WRITE:` as its authority would write files no approval ever granted.

Second, capability routing understands only `github`, so a Change Request cannot declare the capabilities ORVION actually uses, and the `WORKSTATION` and `DATABASE` profiles report `LOCAL_NOT_EXECUTED` even though `.workstation/doctor.ps1` is a real read-only local probe that exists in this repository.

Third, `AGENTS.md` is 29,766 bytes and every session reads it. 16,604 of those bytes are owner-ratified methodology needed only for specific work classes. Relocating it behind deterministic pointers reduces the cost of routine execution, which is what allows cheaper models to run routine work safely.

## Risks

The material risk is semantic loss: relocating an owner-ratified rule could leave it implicitly remembered rather than owned. This is mitigated by moving prose verbatim, by pointing at the new owner from the kernel, and by a mechanical guard that fails if a relocated rule's anchor text is absent from its declared owner. No product or database behaviour is touched, so no domain risk exists. Removing the unreachable `READY_FOR_APPROVAL` runtime mode is a vocabulary reduction, not a control relaxation: the state it named becomes a rejected contradiction rather than an accepted mode.

## Supersedes / Depends On

Depends on `changes/SPEC-160-agent-control-plane-final-reconciliation.md` and `changes/SPEC-162-range-mode-status-path-validation.md`, both Complete. Supersedes nothing.

## Write Scope

- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `README.md`
- `global-rules.md`
- `changes/TEMPLATE.md`
- `.claude/hooks/session-state.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations`
- `PROJECT_CONTEXT.md`
- `CODING_STANDARDS.md`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `reports/architecture-decision-records.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`

## Runtime Checkpoint

Resume Step: 13
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Implementation Steps

1. Check `scripts/check_agent_continuity.ps1` for `MANIFEST_CR_CONTRADICTION`. If absent, replace `Validate-ManifestSync` with one central invariant that reads the `Status` of every `changes/SPEC-*.md` on disk rather than only those in the diff, and enforces both directions: at most one Change Request may be `Approved` or `In Progress`; if one exists the manifest must name it; if none exists the manifest must name `None`; and a manifest pointer must never name a `Draft`, `Complete` or `Cancelled` Change Request. Raise `ORPHANED_APPROVED_CR:<path>` for an unpointed executable contract and `MANIFEST_CR_CONTRADICTION:<status>:<path>` for an illegal pointer target. Call it on every run, not only in the no-active-contract branch.

2. Check `scripts/check_agent_continuity.ps1` for `'Draft'{'READY_FOR_APPROVAL'}`. If present, remove that switch arm, because step 1 makes a `Draft` active contract a rejected contradiction and the mode is therefore unreachable. Remove `READY_FOR_APPROVAL` from the runtime-mode vocabulary in `AGENTS.md §1` and `CR_LIFECYCLE.md §9`, leaving `PLAN`, `EXECUTE`, `VERIFY`, `BLOCKED` and `CERTIFY`.

3. Check `scripts/check_agent_continuity.ps1` for `$script:Capabilities`. If absent, replace the `github`-only branch in `Test-Capabilities` with a table mapping each capability ORVION actually uses to an evidence class: `github`, `docker` and `supabase-local` as `LOCAL_PROBE` with an executable probe each; `supabase-primary`, `postgres-local`, `n8n` and `context7` as `EXTERNAL_EVIDENCE`, which emits an `EVIDENCE:` line and is never reported as proven by this process. A name absent from the table must still fail closed with `NO_DETERMINISTIC_CAPABILITY_PROBE:<name>`.

4. Check `Get-ProfileEvidence` in `scripts/check_agent_continuity.ps1` for `.workstation/doctor.ps1`. If absent, route the `WORKSTATION` profile's local evidence to `pwsh -NoProfile -File .workstation/doctor.ps1`, retaining bootstrap idempotence as deferred evidence naming its exact command. Leave `DATABASE` deferred, but replace its prose note with the exact ordered commands of `AGENTS.md §5a` so a weaker agent needs no re-derivation. Never convert unexecuted evidence into a pass.

5. Check `scripts/check_agent_continuity.ps1` for `-Certify`. If absent, add a `Certify` parameter set that reads the current `HEAD` SHA, queries GitHub for the workflow conclusions recorded against that exact SHA, and prints `REMOTE_CERTIFY: READY` only when every run on that SHA concluded `success`. It must print `REMOTE_CERTIFY: PENDING` when no run exists yet and `REMOTE_CERTIFY: FAILED` with the failing workflow names otherwise. This is the non-circular owner of `POST_PUSH` evidence.

6. Check `CR_LIFECYCLE.md §8` for the phrase `never a completion checkbox`. If absent, record that `Acceptance Criteria` and `Review Gate` assert `LOCAL` evidence only, because a criterion naming the completion commit's own SHA cannot be true before that commit exists; `POST_PUSH` evidence is owned by `-Certify` against the pushed SHA and `EXTERNAL` evidence is declared, never self-asserted. State the same rule in `changes/TEMPLATE.md` under `Acceptance Criteria`, and correct that template's claim that every section including the optional `Notes` must be present.

7. Check `global-rules.md` for `AGENTS.md §6`. If present, repoint its retired-pointer rules to their real current owners: conduct principles to `AGENTS.md §2`, architecture discipline to `ENGINEERING_METHOD.md`, and review-before-completion to `AGENTS.md §8`. Check `.claude/hooks/session-state.ps1` for `§4 step 8` and replace it with a reference to `AGENTS.md §4` that names no step number. Check `scripts/check_repository_consistency.ps1` for the two Check 23 references to `AGENTS.md §6` and repoint them to `AGENTS.md §7`, which is where the HANDOFF rule's authority actually lives, and for the Check 18 reference to `AGENTS.md §4 Stage A step 4` and replace it with `AGENTS.md §4`.

8. Check `scripts/check_repository_consistency.ps1` for `Check 26`. If absent, add a check asserting that every `<DOC>.md §<N>` reference in the living documents and control scripts resolves to a section that exists in `<DOC>.md`, and that where a reference carries a parenthetical heading title that title matches the target heading. Report `BROKEN SECTION POINTER` and `SECTION POINTER MISMATCH` distinctly.

9. Check for `ENGINEERING_METHOD.md`. If absent, create it as the owning authority for engineering method, and move into it verbatim: the `AGENTS.md §1` standing execution directive, the whole `AGENTS.md §3` decision and architecture discipline block, the `§5a` database verification protocol, the `§5b` cross-path impact protocol, and the `§6` measurement integrity block. Preserve every owner-ratified date and wording. Add no new rule.

10. Check `AGENTS.md` for `ENGINEERING_METHOD.md`. If absent, remove exactly the five blocks relocated in step 9 and replace each with a one-line pointer naming its new owner and the condition that routes an agent there. Keep every kernel rule, every permanent principle, the boot sequence, the routing table, the profile list, and the definition of done in place. Do not reword surviving text.

11. Check `scripts/check_repository_consistency.ps1` for `Check 27`. If absent, add a check asserting that `ENGINEERING_METHOD.md` exists, that it contains the anchor phrase of every owner-ratified rule relocated in step 9, and that `AGENTS.md` still points to it. This is what prevents a relocated authority from becoming implicitly remembered.

12. Check `GOVERNANCE.md §5` and `README.md` for `ENGINEERING_METHOD.md`. If absent, register the new authority in the governance document registry and add one router row to `README.md`. Add its routing row to the `AGENTS.md §4` authority table.

13. Check `scripts/test_agent_continuity.ps1` for `MANIFEST_CR_CONTRADICTION`. If absent, add behavioral mutations covering every invariant introduced by steps 1 through 5: a manifest naming a `Draft` contract; a manifest naming a `Complete` contract; an unpointed `Approved` contract that is absent from the diff; the positive control of a correctly paired active contract; a `LOCAL_PROBE` capability succeeding; an `EXTERNAL_EVIDENCE` capability reported as declared rather than proven; a genuinely unknown capability still failing closed; and `WORKSTATION` evidence being executed rather than deferred. Change the existing unknown-capability fixture from `n8n` to a name absent from the registry so that its fail-closed assertion still measures what it claims.

14. Check `scripts/test_agent_continuity.ps1` for a case asserting that a hypothetical prose mention reserves a SPEC identity. If absent, add one positive and one negative mutation fixing the decided rule: an identifier appearing anywhere in tracked text is refused for a new Change Request, and an identifier appearing nowhere is accepted. Record in `CR_LIFECYCLE.md §4` that this conservative behaviour is intentional, because an unused identifier costs nothing while a reused identity is unrecoverable.

15. Run the full local certification, then open one temporary pull request from a branch containing only a no-op change to prove the `pull_request` trigger, merge-base derivation and detached-head execution path of both workflows. Record the observed conclusions and close the pull request without merging, then delete its branch.

16. Synchronize `_ORVION_CANONICAL/manifest.md` to the completed state and regenerate `ai-map.json` with `scripts/generate-ai-map.ps1`. Never hand-edit the generated file.

## Acceptance Criteria

- [ ] A manifest naming a `Draft` Change Request is rejected as `MANIFEST_CR_CONTRADICTION` rather than routed to a mode that prints its Write Scope.
- [ ] A manifest naming a `Complete` or `Cancelled` Change Request is rejected as `MANIFEST_CR_CONTRADICTION`.
- [ ] An `Approved` Change Request that is absent from the current diff and unnamed by the manifest is rejected as `ORPHANED_APPROVED_CR`.
- [ ] A correctly paired active Change Request still routes to `EXECUTE`, proving the invariant does not over-fire.
- [ ] `READY_FOR_APPROVAL` appears in no control script, `AGENTS.md` or `CR_LIFECYCLE.md`.
- [ ] A `LOCAL_PROBE` capability is probed, an `EXTERNAL_EVIDENCE` capability is declared and never claimed proven, and an unregistered capability still fails closed.
- [ ] `WORKSTATION` local evidence executes `.workstation/doctor.ps1` instead of reporting `LOCAL_NOT_EXECUTED`, and `DATABASE` deferred evidence names exact commands.
- [ ] `-Certify` reports `READY`, `PENDING` or `FAILED` against the exact current `HEAD` SHA.
- [ ] `CR_LIFECYCLE.md` and `changes/TEMPLATE.md` both state that Acceptance Criteria assert `LOCAL` evidence only.
- [ ] No `AGENTS.md §N` reference in any living document or control script points at a section that does not exist or whose heading contradicts the citing text.
- [ ] `ENGINEERING_METHOD.md` exists and contains every owner-ratified rule relocated from `AGENTS.md`, with its dates and wording intact.
- [ ] `AGENTS.md` points to `ENGINEERING_METHOD.md` for each relocated block and retains every kernel rule.
- [ ] `AGENTS.md` is smaller than 16,000 bytes, and no relocated rule is absent from its new owner.
- [ ] `scripts/check_repository_consistency.ps1` reports `REPOSITORY CONSISTENCY: CLEAN` with Checks 26 and 27 present and passing.
- [ ] The full adversarial suite passes with every new invariant covered by both a rejecting and an accepting case.
- [ ] `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` emits `LOCAL_CERTIFY: READY`.
- [ ] `git diff --check` is clean and no file outside Write Scope was modified.

## Execution Log

### 2026-09-11 — Claude Opus 5

Outcome: Complete

Step results:
- Step 1: Applied — `Validate-ManifestCrState` now reads every contract on disk and enforces the pointer invariant in both directions.
- Step 2: Applied — the `READY_FOR_APPROVAL` switch arm is removed; the state it named is now a rejected contradiction.
- Step 3: Applied — `$script:Capabilities` registers three `LOCAL_PROBE` and four `EXTERNAL_EVIDENCE` capabilities; unknown names still fail closed.
- Step 4: Applied — `WORKSTATION` executes `.workstation/doctor.ps1`; `DATABASE` lists its six commands in execution order.
- Step 5: Applied — `-Certify` reads workflow conclusions for the exact `HEAD` SHA.

Engineering Observations, both inside the approved objective and repaired within Write Scope:

1. Ordering. The pointer invariant initially ran before contract validation, so an illegal Status jump was reported as a pointer contradiction — the symptom rather than the defect. It now runs after the contract's own legality and still before any output, so a `Draft` named as active can never reach the line that prints its Write Scope.
2. `Certify-Remote` first returned its exit code while also writing its result, so the code joined the output stream and the run fell through into the whole Boot pipeline after reporting. It now exits directly, and case 93 asserts the absence of Boot output so the fall-through cannot return.

Five suite fixtures modelled states the stronger invariant correctly rejects, and were repaired rather than exempted: case 02 and 38 cleared the pointer while the contract was still In Progress; case 27 moved the pointer while leaving the old contract executable; case 33 published a second In-Progress contract to the sandbox origin, so every later case inherited a genuine orphan through `Reset-Fixture`; case 13's unknown-capability fixture named `n8n`, which the registry now knows, so it was changed to a name the registry genuinely lacks.

Suite: 84 → 93 assertions, all passing.

Commits: this entry's commit.

### 2026-09-11 — Claude Opus 5

Outcome: Complete

Step results:
- Step 6: Applied — `CR_LIFECYCLE.md §8` and `changes/TEMPLATE.md` now state that Acceptance Criteria and Review Gate assert LOCAL evidence only; the template's over-claim about the optional `Notes` section is corrected.
- Step 7: Applied — five confirmed pointer drifts repaired: `global-rules.md` pointed three conduct rules at `AGENTS.md §6`, which is now Blocked recovery; `.claude/hooks/session-state.ps1` cited a `§4 step 8` that no longer exists; and this repository's own consistency guard cited `AGENTS.md §6` for the HANDOFF rule that lives in §7 and a `§4 Stage A step 4` structure that is gone.
- Step 8: Applied — Check 26 resolves every cross-document section pointer and compares quoted headings.
- Step 9: Applied — `ENGINEERING_METHOD.md` created, carrying five relocated blocks verbatim.
- Step 10: Applied — `AGENTS.md` reduced to the kernel plus five routed pointers.
- Step 11: Applied — Check 27 asserts all eighteen relocated owner-ratified anchors and the kernel's route to them.
- Step 12: Applied — the new authority is registered in `GOVERNANCE.md §5`, `README.md` and the `AGENTS.md §4` routing table.

Engineering Observations:

3. Check 26's first version read any parenthetical after a section number as a claim about that section's heading, and immediately failed the manifest's accurate prose "`AGENTS.md §4` (the single, mandatory boot sequence)" — a description, not a title. A guard that fires on correct writing is worse than no guard, so the titled form is now opt-in and explicit: a quoted heading. Parentheses remain free prose, and the limitation is recorded in the check itself rather than implied by its name.

4. A defect-injection probe used `git checkout -- <file>` to undo each injection. That reverts to the last commit, not to the probe's starting point, so it destroyed the uncommitted relocation of `AGENTS.md` and the `global-rules.md` repair. No committed history was touched and nothing was lost permanently; both edits were redone and re-verified. The lesson is recorded because it is a real hazard for any agent attacking a guard: injection probes must run against committed state, or the "undo" is a deletion.

Verification: `scripts/check_repository_consistency.ps1` CLEAN with Checks 26 and 27 present.

Commits: this entry's commit.

### 2026-09-11 — Claude Opus 5

Outcome: Complete

Step results:
- Step 13: Applied — cases 85 to 91 and 93 cover the new invariants; case 13's fixture now names a capability the registry genuinely lacks.
- Step 14: Applied — case 92 fixes the identity rule, and `CR_LIFECYCLE.md §4` records that reserving on a prose mention is a decision, not a defect.

Engineering Observation 5: CI rejected `52295ba` and was right to. Three cases failed on the runner while passing on this workstation. Cases 44 and 45 still asserted the relocated anchors in `AGENTS.md`; they now assert the rule in `ENGINEERING_METHOD.md` AND the kernel's route to it, because either half alone permits the authority to become implicitly remembered. Case 89 asserted that the `github` probe PASSES, which asserts an environment rather than a behaviour — a bare runner has `gh` installed and unauthenticated. It now asserts what must hold everywhere, that a registered capability is never treated as unknown, and checks the outcome against what is actually true on the machine running it. Both branches are proven: 93 of 93 with `gh` authenticated, and 93 of 93 with `GH_CONFIG_DIR` pointed at an empty directory so `gh auth status` fails.

The direct cause was mine: after redoing the relocation I re-ran the repository guard but not the control suite. The remote check earned its place by catching it.

Commits: this entry's commit.
### 2026-09-11 — Claude Opus 5 (pull-request path probe)

Outcome: Complete

This entry exists only on `spec-163-pr-path` to exercise the `pull_request` trigger, merge-base derivation and detached-head range execution of both workflows. The branch is never merged.
## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log against the live repository state.]

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] No product, migration, or database-contract file was touched.
- [ ] The repository is in a clean, releasable state.

## Notes

The identity `SPEC-163` was allocated by the rule in `CR_LIFECYCLE.md §4`: the highest identity in the real engineering sequence is `SPEC-162`, the synthetic fixture band and illustrative identifiers are excluded from that maximum, and a repository-wide collision check found zero tracked occurrences of `SPEC-163`.

Remote certification of the commit that completes this Change Request is `POST_PUSH` evidence and is therefore deliberately not an Acceptance Criterion. It is obtained after the push by `-Certify` against the exact pushed SHA, which is the ordering this Change Request exists to make honest.
