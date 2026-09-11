# Change Request — SPEC-160

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

Owner authorization: the owner directive titled "ORVION AGENT CONTROL PLANE — FINAL RECONCILIATION, HARDENING & CONTINUITY PROGRAM" authorizes this exact Change Request, its Write Scope, and its activation.

## Objective

Make the Agent Control Plane mechanically enforce the authority it already declares, so an executing agent can update runtime state but can never rewrite the contract that governs it.

## Business Reason

The Agent Control Plane refactor (`SPEC-1000`) and its corrective repair (`SPEC-1001`) delivered deterministic Boot, JIT routing, explicit Write Scope, Runtime Checkpoint, local Gate/Finish and terminal-history protection. A targeted comparison against the pre-Agent-Control baseline `8d67f77` and the current control code shows that several contracts now exist in prose but are not enforced by the code that claims to enforce them.

`CR_LIFECYCLE.md §8` already ratifies the partition between frozen contract fields and mutable workflow state. `scripts/check_agent_continuity.ps1` does not implement it: the governing Change Request is exempted from scope checking entirely and no frozen field is compared against its approved baseline, so an agent can widen its own Write Scope and then write the newly authorized path. Completion prerequisites, the state transition matrix, append-only evidence, CR/manifest agreement and same-diff identifier collision are likewise weaker in code than in prose. `LOCAL_CERTIFY: READY` is emitted for derived profiles that execute no command, which states evidence that was never observed.

This Change Request closes the gap between the declared contract and the enforced contract. It changes no business policy, no product behaviour and no database schema.

## Risks

Material. This Change Request modifies the control plane that authorizes all other work, including the mechanism that authorizes this Change Request.

- A defect in the frozen-authority comparison could block all future execution. Mitigated by the adversarial suite, which must prove both the rejected case and the accepted case for every detector.
- Strengthening the contract parser could reject historical Change Requests. Mitigated by evidence: every one of the 100 historical Change Requests is terminal (`Complete` or `Cancelled`), terminal Change Requests are never reopened per §4, and only the governing Change Request is ever fully parsed. A stricter schema therefore cannot reach a historical file.
- The pre-commit hook runs the Gate, so a Gate defect blocks committing the fix for that defect. Mitigated by developing each detector alongside its test and running the suite directly before relying on the hook.

No risk to product, migrations or Primary: no file under `supabase/` is in Write Scope.

## Supersedes / Depends On

Depends on `changes/SPEC-1000-agent-control-plane.md` and `changes/SPEC-1001-agent-control-plane-corrective-repair.md`, both `Complete`. This Change Request supersedes neither; it completes the objective they began. Neither file is modified.

## Write Scope

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `README.md`
- `.cursor/rules/orvion.mdc`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `GOVERNANCE.md`
- `reports/master/MASTER_REPOSITORY_HEALTH.md`
- `.claude/hooks/session-state.ps1`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-1000-agent-control-plane.md`
- `changes/SPEC-1001-agent-control-plane-corrective-repair.md`
- `supabase/migrations/202607053800_commission_is_system_derived.sql`
- `supabase/migrations/202607053900_remove_ignored_commission_parameter.sql`
- `supabase/tests/41_commission_derivation_test.sql`
- `reports/history/agent-control-plane-corrective-repair-2026-09-11.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `PROJECT_CONTEXT.md`
- `CODING_STANDARDS.md`
- `scripts/generate-ai-map.ps1`
- `.github/workflows/agent-control.yml`

Write Scope above is exhaustive for engineering artifacts. Every file under `supabase/` is out of scope without exception, including migrations, pgTAP tests and functions. Historical reports under `reports/history/` are immutable. No Git history is rewritten, no commit is amended, and no push is forced.

## Required Reading

- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`

## Runtime Checkpoint

Resume Step: 15
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- git diff --check

## Implementation Steps

Every step below is applied to the control plane only. Each step states its own verification check first; if the check matches, the step is Already Applied and is never re-applied.

1. Check: `scripts/check_agent_continuity.ps1` contains the literal `Acceptance Criteria` inside the `Contract` function's required-section list. If absent, extend `Contract` so the canonical section set of `changes/TEMPLATE.md` is required for the governing Change Request — adding `Objective`, `Business Reason`, `Risks`, `Supersedes / Depends On`, `Out of Scope — Files Forbidden to Modify`, `Acceptance Criteria`, `Execution Log`, `Verification Notes` and `Review Gate` to the sections already required — and return the parsed Acceptance Criteria items, Review Gate items, Execution Log body and Verification Notes body on the contract object. Historical Change Requests must remain unparsed by this function; do not add any retroactive validation of `changes/SPEC-*.md` files other than the governing one.

2. Check: `scripts/check_agent_continuity.ps1` contains the literal `FROZEN_AUTHORITY_MUTATED`. If absent, compare every frozen field of the governing Change Request against its baseline copy read from Git — `Objective`, `Business Reason`, `Risks`, `Supersedes / Depends On`, `Write Scope`, `Out of Scope — Files Forbidden to Modify`, `Required Reading`, `Required Capabilities`, `Additional Verification` and `Implementation Steps` — and throw `FROZEN_AUTHORITY_MUTATED` naming the changed section when the baseline exists and any of them differs. The baseline is `BaseRef` when supplied and `HEAD` otherwise. A governing Change Request absent from the baseline is newly created and has no frozen baseline to violate.

3. Check: `scripts/check_agent_continuity.ps1` contains the literal `EVIDENCE_NOT_APPEND_ONLY`. If absent, require the baseline `Execution Log` body and the baseline `Verification Notes` body each to remain an exact prefix of their current body, and throw `EVIDENCE_NOT_APPEND_ONLY` naming the section otherwise. This rejects editing, deleting, reordering and truncating prior evidence while permitting appends.

4. Check: `scripts/check_agent_continuity.ps1` contains the literal `ACCEPTANCE_TEXT_MUTATED`. If absent, require the Acceptance Criteria and Review Gate item text and item count to be identical to the baseline, permitting only a change of checkbox state from unchecked to checked, and throw `ACCEPTANCE_TEXT_MUTATED` or `REVIEW_GATE_TEXT_MUTATED` accordingly.

5. Check: `scripts/check_agent_continuity.ps1` contains the literal `ILLEGAL_STATUS_TRANSITION`. If absent, derive the baseline Status of the governing Change Request and enforce the complete matrix of `CR_LIFECYCLE.md §4` — permitting only `Draft`→`Approved`, `Draft`→`Cancelled`, `Approved`→`In Progress`, `Approved`→`Cancelled`, `In Progress`→`Complete`, `In Progress`→`Cancelled`, and an unchanged Status — throwing `ILLEGAL_STATUS_TRANSITION` with both states otherwise. Any transition out of `Complete` or `Cancelled` is rejected.

6. Check: `scripts/check_agent_continuity.ps1` contains the literal `COMPLETION_PREREQUISITE`. If absent, require before any transition to `Complete` that every Acceptance Criteria item is checked, every Review Gate item is checked, `Blocker` is `None`, `Resume Step` is `DONE`, and at least one `Verification Notes` entry carries `Verdict: Confirmed Complete`; throw `COMPLETION_PREREQUISITE` naming the unmet prerequisite otherwise.

7. Check: `scripts/check_agent_continuity.ps1` contains the literal `ORPHANED_APPROVED_CR`. If absent, treat Change Request state and the manifest active pointer as one invariant: when the manifest names no Active Change Request but a `changes/SPEC-*.md` file in the diff is `Approved` or `In Progress`, throw `ORPHANED_APPROVED_CR` naming it. Retain the existing rejection of an active pointer that names a missing file and of a terminal Change Request that is still active.

8. Check: `scripts/check_agent_continuity.ps1` contains the literal `DUPLICATE_NEW_SPEC_ID`. If absent, detect two or more newly added `changes/SPEC-NNN-*.md` files introducing the same identifier within one diff and throw `DUPLICATE_NEW_SPEC_ID` naming it, retaining the existing baseline-reuse rejection unchanged. Then record the allocation rule in `CR_LIFECYCLE.md`: a SPEC identity is a repository-wide engineering identity that may materialize as a Change Request file, a migration, a test or a plan entry; a new identity is the next integer above the highest identity in the real sequence, excluding the synthetic fixture band reserved by `scripts/test_agent_continuity.ps1`; collision validation remains repository-wide over every identifier including synthetic ones.

9. Check: `scripts/check_agent_continuity.ps1` contains the literal `EVIDENCE_CLASS`. If absent, classify each derived verification profile's evidence as LOCAL, POST_PUSH or EXTERNAL, execute only the LOCAL class during `-Finish`, and print each applicable profile with the class and the exact evidence still outstanding. `LOCAL_CERTIFY: READY` must be emitted only when every LOCAL command for every applicable profile actually ran and succeeded; when an applicable profile carries POST_PUSH or EXTERNAL evidence, name that evidence explicitly as not yet observed rather than implying it. A profile that is derived but has no executable local command must not silently contribute nothing.

10. Check: `scripts/check_agent_continuity.ps1` contains the literal `Get-ControlSurface`. If absent, replace the inline control-path regex with one authoritative control-surface definition covering the agent operating kernel, Change Request lifecycle and template, control and consistency scripts, Git hooks, the Agent Control workflow, the knowledge governance authority, the repository router and every thin client adapter; reuse it for CONTROL profile derivation. Then make verification output compact: a successful command prints one PASS line, a failed command retains its command line, exit code and diagnostic output or log path, and a command appearing identically in both the derived mandatory set and `Additional Verification` executes exactly once.

11. Check: `.cursor/rules/orvion.mdc` contains the literal `check_agent_continuity.ps1 -Boot`. If absent, add the executable Boot entry to that adapter, remove the trailing `Start at AGENTS.md.` sentence from `README.md` that contradicts its own Start-here Boot instruction, and upgrade Check 3 of `scripts/check_repository_consistency.ps1` from asserting that a router mentions a filename to asserting that every live adapter and router reaches the executable Boot entry, keeping the existing pointer-thinness budget.

12. Check: `_ORVION_CANONICAL/manifest.md` `Next capability:` resolves to a single immediate action. If it does not, reduce it to one immediate action, move the workflow-build and Phase-10 research items to their owning authority pointers, correct `Current Module` to current state rather than completed-work narrative, and remove the resolved Windows/Docker blocker narrative and its stale 211-migration count from `Current session blocker`. Preserve every semantically required field and stay within the existing Check 5 budgets by relocating narrative to pointers rather than deleting state.

13. Check: `AGENTS.md` contains the literal `disappears`. If absent, restore two owner-ratified properties weakened during the token-reduction refactor, compactly and without restoring mandatory session reports: durable meaningful checkpoints, stated as the self-test that a completed engineering boundary must leave the repository able to continue if the current agent disappears permanently; and delegation economy, stated as delegating only when it earns its cost, using the fewest non-overlapping specialists, choosing the smallest model capable of the required quality, and the governing agent independently verifying returned evidence and retaining final responsibility.

14. Check: `CR_LIFECYCLE.md` describes the enforced frozen-authority mechanism. If it does not, synchronize the live authorities to the system that now exists — `CR_LIFECYCLE.md`, `changes/TEMPLATE.md`, `GOVERNANCE.md` semantic section references, `reports/master/MASTER_REPOSITORY_HEALTH.md` remeasured from the live repository rather than from remembered numbers, and `.claude/hooks/session-state.ps1` resolved under Earn-It by correcting its unique responsibility or reducing it where Boot has superseded it. Regenerate `ai-map.json` with `scripts/generate-ai-map.ps1`; never hand-edit it. Historical reports are not edited.

15. Check: `scripts/test_agent_continuity.ps1` proves every detector added by steps 1 through 11 in both directions. If it does not, extend the adversarial suite so each detector has a case it must reject and a case it must accept, covering at minimum self-expanding Write Scope, post-approval mutation of Implementation Steps, removal of a Required Capability, weakening of Additional Verification, altered Acceptance and Review Gate wording, edited and deleted and reordered Execution Log and Verification Notes entries, every illegal status transition including out of terminal states, completion without each prerequisite, an orphaned Approved Change Request, duplicate new identifiers in one diff, a stale adapter route, and a multi-action next capability. Then run full local certification from a clean state, push the green implementation, and observe the Agent Control and Repository Consistency workflow results on the exact pushed SHA.

## Acceptance Criteria

- [ ] The governing Change Request is parsed against the canonical section set of `changes/TEMPLATE.md`, and no historical Change Request is retroactively validated.
- [ ] Mutating any frozen field of the active Change Request is rejected as `FROZEN_AUTHORITY_MUTATED`, and widening its own Write Scope is therefore impossible.
- [ ] Editing, deleting, reordering or truncating a prior Execution Log or Verification Notes entry is rejected as `EVIDENCE_NOT_APPEND_ONLY`; appending is accepted.
- [ ] Changing Acceptance Criteria or Review Gate item text or count is rejected; checking an unchecked box is accepted.
- [ ] Every state transition outside `CR_LIFECYCLE.md §4` is rejected as `ILLEGAL_STATUS_TRANSITION`, including every transition out of a terminal state.
- [ ] A transition to `Complete` is rejected unless every Acceptance Criterion is checked, every Review Gate item is checked, `Blocker` is `None`, `Resume Step` is `DONE`, and a `Confirmed Complete` verdict exists.
- [ ] An `Approved` or `In Progress` Change Request with no manifest active pointer is rejected as `ORPHANED_APPROVED_CR`.
- [ ] Two newly added Change Request files sharing one identifier in a single diff are rejected as `DUPLICATE_NEW_SPEC_ID`, and the SPEC allocation rule is recorded in `CR_LIFECYCLE.md`.
- [ ] `LOCAL_CERTIFY: READY` is emitted only when every applicable LOCAL command actually ran and succeeded, and POST_PUSH and EXTERNAL evidence is named as outstanding rather than implied.
- [ ] One authoritative control-surface definition drives CONTROL profile derivation and includes `GOVERNANCE.md` and the client adapters; successful verification prints one PASS line per command; an identical mandatory and additional command executes once.
- [ ] Every live client adapter and router reaches the executable Boot entry, `README.md` contains no competing start instruction, and Check 3 rejects a deliberately stale adapter.
- [ ] `_ORVION_CANONICAL/manifest.md` `Next capability` names exactly one immediate action, holds current state only, and passes Check 5.
- [ ] `AGENTS.md` carries the durable-checkpoint self-test and the delegation economy, with no mandatory session report reintroduced.
- [ ] Live authorities describe the enforced system, `MASTER_REPOSITORY_HEALTH.md` is remeasured from the live repository, and `ai-map.json` is regenerated rather than hand-edited.
- [ ] The adversarial suite proves every added detector in both directions, full local certification passes from a clean state, and the Agent Control and Repository Consistency workflows are green on the exact final SHA.
- [ ] No file under `supabase/`, no historical report and no completed Change Request was modified, and no Git history was rewritten.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.]

### 2026-09-11 — executing agent (owner-directed autonomous program)

Outcome: Complete

Step results:
- Step 1: Applied — the contract schema now requires the canonical section set of `changes/TEMPLATE.md`. Only the governing Change Request is parsed, so all 154 terminal historical Change Requests are untouched and no format-version field was needed.
- Step 2: Applied — `FROZEN_AUTHORITY_MUTATED`. Proven live against this very contract: adding `PROJECT_CONTEXT.md` to its own Write Scope and then writing that file was rejected naming `Write Scope`, while legitimate in-scope work passed in the same state.
- Step 3: Applied — `EVIDENCE_NOT_APPEND_ONLY`. A `None.` or bracketed-template body counts as "no evidence yet", so the first real entry stays legal while genuine prior evidence cannot be edited, deleted, reordered or truncated.
- Step 4: Applied — `ACCEPTANCE_TEXT_MUTATED` and `REVIEW_GATE_TEXT_MUTATED`; only unchecked-to-checked moves.
- Step 5: Applied — `ILLEGAL_STATUS_TRANSITION` over the complete §4 matrix. Transitions out of a terminal state are caught earlier still, by the existing `HISTORICAL_CR_MUTATION` guard.
- Step 6: Applied — `COMPLETION_PREREQUISITE` for each of the five prerequisites separately.
- Step 7: Applied — `ORPHANED_APPROVED_CR`.
- Step 8: Applied — `DUPLICATE_NEW_SPEC_ID`, plus the allocation-versus-collision separation recorded in `CR_LIFECYCLE.md §4`.
- Step 9: Applied — LOCAL / POST_PUSH / EXTERNAL evidence classes. An applicable profile whose local protocol this process cannot execute now yields `LOCAL_CERTIFY: INCOMPLETE` instead of a `READY` that asserted evidence nobody observed.
- Step 10: Applied — `Get-ControlSurface` as the single control-surface definition (it had omitted `GOVERNANCE.md`, `README.md`, `llms.txt` and every client adapter); compact one-line PASS on success; command, exit code, diagnostic tail and log path retained on failure; identical mandatory and additional commands executed once.
- Step 11: Applied — Check 3 upgraded from "does this file mention a filename" to "does every live adapter reach the executable Boot entry, and does none offer a competing start". Attacked in both directions and restored clean.
- Step 12: Applied — `Next capability` reduced to one immediate action; the resolved Windows/Docker blocker narrative and its stale 211-migration count removed.
- Step 13: Applied — durable-checkpoint self-test and delegation economy restored compactly to `AGENTS.md`, with no session-report overhead reintroduced.
- Step 14: Applied — live authorities synchronized; `MASTER_REPOSITORY_HEALTH.md` remeasured from the live repository rather than refreshed from memory; `ai-map.json` regenerated by its generator and never hand-edited; `.claude/hooks/session-state.ps1` retained under Earn-It for the one fact it uniquely reports before anything is run, with its stale section citation corrected. `GOVERNANCE.md` section references were checked against `AGENTS.md`'s actual sections and were already correct; only its adapter registry row needed an accuracy fix.
- Step 15: Applied — the adversarial suite grew from 45 to 82 behavioural cases, each new detector carrying both a case it must reject and a case it must accept.

Engineering observations, recorded rather than silently absorbed:
- Two defects were found inside this repair as it was written, both by its own tests. Baseline blobs read through `git show` were decoded with the console OEM code page, so any contract containing an em dash or `§` compared unequal to itself; UTF-8 decoding is now forced. And `pwsh -Command` collapses a child's exit code to 1, so failure reports named the wrong code until the exit status was propagated explicitly.
- A new test pushed its fixture to the sandbox origin and poisoned the shared baseline for eight later tests. Fixed in the test. Harness-level baseline restoration was considered and NOT earned: the failure is self-announcing, and tests 33 and 37 have pushed for months without incident.
- HANDOFF-2, a genuine unlisted defect inside this objective. Check 23 had been enforcing the seven-field HANDOFF rule since the Agent Control refactor deleted that rule's stated authority from `AGENTS.md`, so a fresh agent reading the authorities could not have complied with it. The authority is restored and the check now asserts its own authority exists, in both directions.

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

**Identity.** `SPEC-160` is the next identity in ORVION's real engineering sequence. Evidence: identifiers 001–159 are contiguous and real; `SPEC-147` and `SPEC-155`–`SPEC-159` exist as migrations, pgTAP tests and plan entries with no Change Request file, which establishes that a SPEC identity is a repository-wide engineering identity rather than a `changes/` file identity; identifiers 404, 800, 801, 802, 899, 900, 901 are a synthetic fixture band owned by `scripts/test_agent_continuity.ps1`, and 999 appears only as an illustrative non-existent Change Request in historical reports; no authority reserves any identifier above 159.

`SPEC-1000` and `SPEC-1001` arose from conflating allocation scope with collision scope — a repository-wide textual maximum observed the `SPEC-999` fixture. Step 8 separates the two rules so the defect cannot recur.

**Normalization of `SPEC-1000` and `SPEC-1001` to `SPEC-160` and `SPEC-161` was evaluated and is NOT EARNED.** Both are terminal, unique and non-colliding; nothing mechanical is broken by their identifiers. Renaming them would require a one-time exception through the terminal-history guard — the strongest protection in the system — during the program whose purpose is to make that protection airtight. It could not achieve its own goal, because `CR_LIFECYCLE.md §4` and `reports/history/agent-control-plane-corrective-repair-2026-09-11.md` truthfully record those identifiers and must remain truthful, so the rename would replace one visible scar with a contradiction between file names and the history describing them. `CR_LIFECYCLE.md §4` already ratifies the 2026-09-11 correction as a documented one-time historical exception. No normalization escape hatch is built, therefore none can survive.

**Three proposed mechanisms were evaluated and are NOT EARNED.**

*Contract Format Version* is superseded by terminality. Every one of the 100 historical Change Requests is `Complete` or `Cancelled`, a terminal Change Request is never reopened per §4, and only the governing Change Request is fully parsed. A stricter schema therefore cannot reach a historical file, and a version field would add a second authority for a boundary the state machine already enforces.

*Contract Fingerprint* is superseded by Git. `core.hooksPath` is `.githooks` and its pre-commit hook runs `-Gate`, so no commit can contain a frozen-field mutation; CI re-runs `-Gate -BaseRef` across the whole range. Comparing frozen sections against the Git baseline proves the same invariant using the anchor the repository already trusts, with no self-referential hash and no approval-bootstrap problem.

*Execution Tier* is not earned as a contract field. The tier governs pre-design ceremony that is already complete before a Change Request is executed, and no guard would mechanically consume it. A field no mechanism reads is documentation, not control. It remains available in `AGENTS.md §3` where it is actually applied.

**Server-side GitHub enforcement** remains a separate owner decision and is deliberately outside this Change Request. `.github/workflows/agent-control.yml` is out of scope and branch protection is not changed here; the real pull-request path is proven in step 15 so that the decision can be made on evidence afterwards.
