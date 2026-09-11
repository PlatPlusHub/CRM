# Change Request — SPEC-163

## Status

[ ] Draft
[x] Approved
[ ] In Progress
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

Resume Step: 1
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

[Appended by the executing agent after each run against this Change Request.]

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
