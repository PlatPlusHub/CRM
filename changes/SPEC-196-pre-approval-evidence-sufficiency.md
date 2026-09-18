# Change Request — SPEC-196

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make ORVION pre-approval authority mechanically admissible only when required evidence is sufficient and the proposed SPEC identity is legally allocated.

## Business Reason

Phase-1 adversarial testing reproduced four material authority gaps: a contract can freeze without consumer closure; a frozen Significant sequence can require an invariant to be both red and green at one mandatory boundary (the exact `SPEC-195` failure); a permanent control can be admitted despite redundant or vacuous evidence; and collision validation admitted the arbitrary unused identity `SPEC-1002` after the normal sequence ended at `SPEC-195`. Phase-2 attacks narrowed that fourth gap further: reservation is not monotonic, because deleting an identity's only tracked occurrence releases it for reuse even though the identity authority declares such an occurrence permanent, and the first-parent diagnostic sentinel this contract first proposed for activation is defeated by an ordinary rename. The repair must extend the existing Change Request, Gate, committed-range, and mutation-harness mechanisms without creating a generic dependency graph, temporal engine, identity registry, or second policy authority. A/B/C did not earn standalone fields, E/G remain unproven, and I is already mechanically protected.

## Risks

An over-broad applicability rule could burden Routine work, while a self-declared Routine class could become an escape hatch. A numeric maximum or maintained fixture allowlist would repeat the `SPEC-1000/1001` allocation failure; an endpoint-only K check would let an illegal allocation be committed and later laundered by rename; and retroactive K enforcement would make this contract's own two pre-K Draft commits unpublishable. Two further risks were reproduced rather than assumed: current-tree-only reservation releases an identity as soon as its occurrence is deleted, and a first-parent diagnostic sentinel lets a behaviour-preserving rename silently disable historical enforcement. Anchoring reservation to reachable history, activating on a declared marker owned by the identity authority, failing closed when that marker is absent, derived applicability, separate collision validation, positive/negative activation fixtures, predicate mutations, and performance comparison constrain those risks. A residual risk remains that history-anchored reservation costs more as history grows; Step L therefore measures the identity-allocating Gate, not only the ordinary one. No product, database, client-hook, workflow, or external-system behavior is changed.

## Supersedes / Depends On

None. This Change Request uses the terminal evidence in `SPEC-193`, `SPEC-194`, and `SPEC-195` without reopening, superseding, or modifying any of them.

## Write Scope

- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `AGENTS.md`
- `GOVERNANCE.md`
- `scripts/impact.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/publish_candidate.ps1`
- `.githooks/pre-commit`
- `.claude/hooks/session-state.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `changes/SPEC-193-a-membership-change-costs-the-same-through-every-door.md`
- `changes/SPEC-194-a-membership-change-costs-the-same-through-every-door.md`
- `changes/SPEC-195-a-membership-change-costs-the-same-through-every-door.md`
- `supabase/config.toml`

## Required Reading

- `AGENTS.md`
- `ENGINEERING_METHOD.md §2, §3, §5`
- `CR_LIFECYCLE.md §4, §5, §8, §9`
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/impact.ps1`
- `scripts/check_repository_consistency.ps1` Check 27
- `changes/SPEC-1000-agent-control-plane.md`
- `changes/SPEC-1001-agent-control-plane-corrective-repair.md`
- `changes/SPEC-160-agent-control-plane-final-reconciliation.md`
- `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md`
- `changes/SPEC-184-candidate-publication-proves-its-range.md`
- `changes/SPEC-195-a-membership-change-costs-the-same-through-every-door.md` Steps 10–13 and Verification Notes

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Owner-Decision

### Derived Applicability

| Predicate | Repository-derived fact | Result |
| --- | --- | --- |
| Consumer Closure | Write Scope changes protected method/lifecycle/template authority and the central evaluator; derived profile includes `CONTROL`. | APPLICABLE |
| Execution-Boundary Satisfiability | The change installs a history-sensitive invariant with an activation boundary and changes the Draft-to-Approved control path. | APPLICABLE |
| Permanent-Control Admission | Write Scope changes `scripts/check_agent_continuity.ps1`, the executable Gate used by hooks/CI/publication. | APPLICABLE |
| SPEC Allocation | A new CR identity is an allocation event regardless of declared Change Class. | APPLICABLE |

`Change Class` is descriptive input, never exemption authority. A declared `Routine` value cannot suppress a block made applicable by Write Scope, a derived non-`REPOSITORY` profile, a known governance/control surface, a cross-path trigger, or a declared irreversible action. A contradiction or an exemption that cannot be derived deterministically evaluates `INDETERMINATE` and blocks Approval.

### Consumer Closure

Applicability: APPLICABLE

Evidence Commands:
- `pwsh -NoProfile -File scripts/impact.ps1 -Target FrozenSections -NoDatabase -Full`
- `pwsh -NoProfile -File scripts/impact.ps1 -Target ControlSurface -NoDatabase -Full`
- `rg -n "FrozenSections|Get-ControlSurface|ContractText|changes/TEMPLATE|Design Challenge|cross-path|impact.ps1" AGENTS.md ENGINEERING_METHOD.md CR_LIFECYCLE.md changes/TEMPLATE.md scripts .githooks .claude .github README.md CLAUDE.md GEMINI.md llms.txt`

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Bounded pre-Approval evidence semantics and outcome vocabulary | `ENGINEERING_METHOD.md`; `CR_LIFECYCLE.md`; `changes/TEMPLATE.md` | WRITE | Method owns evidence meaning, lifecycle owns Approval/frozen authority, and the template owns representation; PASS only permits the human decision. |
| Evidence parsing, derived applicability, and local/range transition refusal | `scripts/check_agent_continuity.ps1`; `scripts/test_agent_continuity.ps1` | WRITE | Extend the central evaluator and its existing disposable behavioral/mutation harness; do not create a second engine. |
| Normal-sequence allocation and independent collision reservation | `CR_LIFECYCLE.md`; `scripts/check_agent_continuity.ps1`; `scripts/test_agent_continuity.ps1` | WRITE | Replace prose-only allocation with first-parent CR-allocation chronology and make reservation history-anchored so a deleted occurrence no longer releases an identity; retain `Base-HasId`, `SPEC_ID_ALREADY_USED`, and `DUPLICATE_NEW_SPEC_ID` unchanged as separate current-tree collision controls. |
| Stable K activation marker declared by the identity authority and read from a commit's first parent | `CR_LIFECYCLE.md`; `scripts/check_agent_continuity.ps1`; `scripts/test_agent_continuity.ps1` | WRITE | The lifecycle authority already owns allocation and collision semantics, so it declares the marker and the evaluator only consumes it; the marker adds no second policy authority and answers exactly one question. |
| Post-activation intermediate-commit allocation integrity | `Validate-CommittedRange` in `scripts/check_agent_continuity.ps1` | WRITE | Extend the existing history scanner only; do not create a second scanner. |
| Committed-range Gate consumption | `scripts/publish_candidate.ps1`; agent-control and acceptance workflows | VERIFY | Confirm these unchanged adapters continue consuming the same central range Gate before publication/admission. |
| Lifecycle completion state and generated cold-start mirror | `_ORVION_CANONICAL/manifest.md`; `ai-map.json` | WRITE | Synchronize only this completed control-plane capability; preserve Batch 6 Slice 12 as `Next capability`, then regenerate the existing mirror. |
| Operating/governance routing | `AGENTS.md`; `GOVERNANCE.md`; `scripts/impact.ps1`; `scripts/check_repository_consistency.ps1` | VERIFY | Existing routing and checks remain authoritative and unchanged; impact is evidence, never Approval authority. |
| Thin local/remote adapters | `.githooks/pre-commit`; `.claude/hooks/session-state.ps1`; `.github/workflows/agent-control.yml`; `.github/workflows/orvion-acceptance.yml`; `.github/workflows/repository-consistency.yml` | UNAFFECTED | They already invoke the central Gate/suites and require no new client-specific rule or workflow. |

Unresolved Material Consumers: None

The table closes changed facts/surfaces, not files. Write Scope authorizes mutation; it is neither the source nor the required row count for Consumer Closure. For applicable work the evaluator requires at least one non-placeholder fact row, one or more relevant consumers per fact, a disposition from `WRITE | VERIFY | UNAFFECTED`, non-empty evidence, and `Unresolved Material Consumers: None`; `UNKNOWN`, malformed evidence, or any named unresolved material consumer is `INDETERMINATE`. Human Approval remains responsible for the semantic completeness of the declared facts and consumers.

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE — this repository-only control change performs no irreversible external action, so `BEFORE_IRREVERSIBLE_ACTION` and `AFTER_IRREVERSIBLE_ACTION` are not applicable.

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Existing control behavior remains green | BEFORE_IMPLEMENTATION, BEFORE_COMPLETION | NONE | NONE | Step 2 (B), Step 13 (M) |
| D/F/H-J/K RED fixtures fail for the reproduced reasons and no longer fail after evaluator repair | BEFORE_COMPLETION | Step 3 (C) | Step 5 (E) | Step 13 (M) |
| K exempts only commits whose first parent lacks the activation marker, so the two existing pre-marker Draft commits publish while every post-activation illegal allocation remains rejected even after correction | BEFORE_COMPLETION | Step 3 (C) | Step 5 (E) | Step 17 (Q) |
| Every new load-bearing predicate has a non-empty mutation discriminator | BEFORE_COMPLETION | Step 3 (C) | Step 8 (H) | Step 13 (M) |
| Repository consistency and generated-state checks are clean | BEFORE_IMPLEMENTATION, BEFORE_COMPLETION | NONE | NONE | Step 2 (B), Step 13 (M) |

The evaluator recognizes only `BEFORE_IMPLEMENTATION`, `BEFORE_IRREVERSIBLE_ACTION`, `AFTER_IRREVERSIBLE_ACTION`, and `BEFORE_COMPLETION`. It orders referenced implementation steps, rejects an invariant whose required boundary lies inside its declared red window, and returns `INDETERMINATE` for an invalid/missing step, open-ended red window, or applicable irreversible boundary without an irreversible step. It does not simulate arbitrary program state.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `scripts/check_agent_continuity.ps1` owns contract evaluation and both local/range Gate paths; `scripts/test_agent_continuity.ps1` owns disposable behavioral and mutation attacks.

Added Property: Future CR allocation is rejected immediately unless it is the next legal chronology-derived identity, an identity is reserved permanently by any occurrence in reachable tracked history rather than only while that occurrence survives at `HEAD`, post-activation committed violations cannot be laundered, and a future Draft-to-Approved transition is refused unless applicable D/F/H-J evidence evaluates to PASS; no new Status or approval actor is introduced.

Causal Negative: Phase 1 proved that the current Gate admits a contract with no consumer-closure evidence, admitted the frozen `SPEC-195` sequence whose Steps 10–13 force Check 10 red at the pre-deployment boundary, allowed an exit-zero vacuous verification control while the fixed control-surface population omitted a newly introduced `scripts/check_*.ps1`, and admitted unused `SPEC-1002` even though the normal sequence ended at `SPEC-195`. Phase 2 reproduced two further negatives in a disposable clone of `7b8c1c8`, each preceded by a control proving the mechanism fires when the identity is present. Reservation is not monotonic: an identity committed in tracked text and then deleted, and a second identity carried only by a tracked filename and then deleted, were both re-admitted as brand-new Change Request identities by the unmodified Gate — `ORVION: READY` in both cases — while both occurrences remained reachable in history, contradicting the `CR_LIFECYCLE.md` §4 statement that a tracked occurrence "permanently retires that number". The live instance is this contract itself: `SPEC-1002` survives at `HEAD` only as prose inside this Draft, so rewording one sentence would release a real historical Change Request identity for reuse. A first-parent diagnostic sentinel is also not a stable activation signal: renaming `HISTORICAL_CR_MUTATION` throughout the evaluator, a behaviour-preserving refactor, turned a refused terminal-Change-Request mutation into `ORVION: READY` over unchanged history, with no error and no failing assertion.

Positive Test Design: Preserve current valid Draft-to-Approved behavior and committed-range lifecycle paths; accept complete applicable evidence, a red window closed before its gate, a deterministically non-applicable Routine fixture, the next legal local identity, collision-driven candidate advancement, a legal post-K range allocation, and this contract's two pre-K Draft commits in the final governing range. Prove also that an identity that has never appeared anywhere in the ref's reachable history stays allocatable, so historical reservation does not over-reserve, and that a present marker activates K.

Negative Test Design: Reject missing/vacuous/`UNKNOWN` consumer evidence, the exact `SPEC-195` boundary contradiction, absent permanent-control obligations, Routine self-exemption, an unused jumped local identity, and an illegal post-K committed identity followed by a correcting rename. Reject reuse of an identity whose only occurrence was tracked text later deleted, reuse of an identity whose only occurrence was a tracked filename later deleted, and a missing activation marker; and prove that renaming every diagnostic code the evaluator emits leaves K activation and enforcement unchanged.

Non-Empty Population Obligation: Each D/F/H-J/K predicate family must have at least one rejecting and one accepting fixture, and the harness must assert every population count is greater than zero.

Mutation Obligation: Step 8 must bypass each applicability derivation, evidence completeness/`UNKNOWN` predicate, boundary-order predicate, permanent-control obligation, chronology cursor, current-tree collision advancement, historical reservation content query, historical reservation path query, local invocation, first-parent marker activation, working-tree marker presence, and per-commit range invocation one at a time in an isolated evaluator copy and prove the unchanged focused suite kills every mutation.

Post-Implementation Proof Obligation: Before Complete, the derived CONTROL suite executed by `-Finish` must produce actual positive, negative, non-empty-population, and mutation/bypass-kill proof. Pre-Approval freezes the designs and obligations only; it does not claim a mutation kill for code that does not yet exist.

### SPEC Identity Allocation

Applicability: APPLICABLE

Sequence Cursor Rule: For a supplied Git ref, walk its first-parent history newest-to-oldest. At each commit inspect the first-parent name-status diff with rename detection and consider only (a) an added `changes/SPEC-<integer>-*.md` path or (b) a rename whose old and new paths carry different integer SPEC identities. The new-side identity of the first such event is the normal-sequence cursor. Tokens in arbitrary prose, scripts, fixtures, migration names, or older exceptional CRs do not move that cursor. If no cursor resolves, fail closed as `SPEC_SEQUENCE_CURSOR_UNRESOLVED`.

Next Legal Identity Rule: Start at cursor plus one. A candidate is reserved when it has ever appeared in the reachable tracked history of the supplied ref — in a blob's content or in an added or renamed path — not merely when it survives in that ref's tree. Reservation is monotonic: deleting the occurrence never releases the identity. While the candidate is reserved, increment by one; the first unreserved candidate is the only admissible new identity. Exactly two candidate-specific Git queries anchored to the supplied ref answer this, one content pickaxe and one added/renamed path walk — never a ledger, registry, allowlist, or sweep over all identities, and never `--all`, whose reachability differs between clones. Existing current-tree collision validation runs first and unchanged, retaining `Base-HasId`, `SPEC_ID_ALREADY_USED`, and `DUPLICATE_NEW_SPEC_ID`; a newly added Change Request reusing a historically reserved identity is refused separately as `SPEC_ID_HISTORICALLY_RESERVED:<id>:<reserving short SHA>`, and allocation failure remains `SPEC_ID_NOT_NEXT:<expected>:<observed>`. `196` is evidence from the current history, never a constant.

Local Rule: In ordinary non-range Gate, validate each added CR or cross-identity CR rename against `HEAD` before `Resolve-Contract`; thus PLAN remains Draft-only but an arbitrary unused jump fails immediately. Multiple allocation events in one diff are ordered by integer identity and must consume the legal candidate sequence without duplicates.

Activation And History Rule: K is active for a committed-range allocation event only when that event commit's first-parent copy of `CR_LIFECYCLE.md` declares the stable marker `SPEC Allocation Enforcement: <integer>` with a value of at least `1`. The marker is a clause of the identity authority that already owns allocation and collision semantics, carried in the same file as the rules it activates; it is never a diagnostic code, log line, line number, test count, timestamp, or SPEC number, so renaming `SPEC_ID_NOT_NEXT` or any other error text cannot change activation. The evaluator additionally requires the marker in its own working tree and fails closed as `SPEC_ALLOCATION_MARKER_MISSING` when it is absent, so deleting the declaration or renaming its file breaks loudly on the very next Gate instead of silently disabling history enforcement. `Validate-CommittedRange` compares every active commit to its first parent, derives the cursor/collision candidate from that parent, and refuses the offending commit with its short SHA. The activation commit and every earlier commit are not retroactively judged for allocation; after activation, a later correction cannot erase the earlier failure. Reservation is not gated by the marker: a pre-activation identity appearance still reserves that identity against every future candidate. The current `3453750` `SPEC-1002` creation and `d839ccd` correction therefore remain publishable because both parents predate the marker, while `SPEC-1002` stays permanently reserved and never advances the cursor.

## Implementation Steps

1. **A — Approved to In Progress. Check:** Status is `In Progress` and the manifest names this file. If both match, record Already Applied; if only one matches, STOP. Otherwise require Status `Approved`, make `In Progress` the first execution transition, synchronize the manifest pointer, and make no implementation edit before that transition. Human-only Approval remains a prerequisite and is never inferred.

2. **B — Minimal authority and representation. Check:** `ENGINEERING_METHOD.md` contains `### Pre-Approval evidence sufficiency`, `CR_LIFECYCLE.md` contains `Only PASS permits the human Draft-to-Approved decision`, the first-parent allocation rule, the monotonic reservation rule, and exactly one line matching `^SPEC Allocation Enforcement: [0-9]+$`, and `changes/TEMPLATE.md` contains exactly one `## Pre-Approval Evidence`. If all match, record Already Applied; if only a subset matches, STOP. Otherwise add the bounded PASS/FAIL/INDETERMINATE model to `ENGINEERING_METHOD.md`; update lifecycle Approval, frozen-section, allocation, collision-separation, reservation, and activation semantics in `CR_LIFECYCLE.md`, declaring the activation marker at value `1` inside the section that already owns SPEC identity, and state there that reservation is history-anchored and monotonic while collision validation remains the separate current-tree rule; and add this contract's compact field/table shape to `changes/TEMPLATE.md`. Remove the stale synthetic-ID enumeration rather than replacing it with another maintained list. Preserve five Status values, human-only Approval, historical terminal compatibility, and every existing evidence class. Do not modify `AGENTS.md` or `GOVERNANCE.md`, and do not commit Steps B–D before Step E installs the evaluator and frozen comparison.

3. **C — RED fixtures before evaluator repair. Check:** the harness contains all sentinels `APPROVAL-EVIDENCE D`, `APPROVAL-EVIDENCE F SPEC-195`, `APPROVAL-EVIDENCE HJ`, `SPEC-ALLOCATION LOCAL`, `SPEC-ALLOCATION RANGE-LAUNDER`, `SPEC-ALLOCATION ACTIVATION`, `SPEC-ALLOCATION RESERVED-TEXT`, `SPEC-ALLOCATION RESERVED-PATH`, and `SPEC-ALLOCATION DIAGNOSTIC-RENAME`. If all exist, record Already Applied; if only a subset exists, STOP. Otherwise extend only `ContractText` and the existing disposable Git harness with focused fixtures against the unmodified evaluator: D missing/vacuous/`UNKNOWN`/unresolved fact-consumer evidence; F the exact `SPEC-195` Step-10/Gate-12/Step-13 contradiction; H/J absent or empty pre-Approval obligations; K an unused jumped local Draft; K a post-activation illegal commit followed by a legal correcting rename; a positive activation fixture reproducing pre-marker add-as-`SPEC-1002` then rename-to-`SPEC-196` before the marker is declared; K reuse of an identity whose sole tracked-text occurrence was committed and then deleted; K reuse of an identity whose sole occurrence was a tracked filename committed and then deleted; and a fixture that renames every diagnostic code the evaluator emits and requires K activation and enforcement to be unchanged. Each of the two reservation fixtures must pair with a control proving the same identity is refused while its occurrence is still present, and with an identity absent from the whole reachable history that must remain allocatable. Include a Routine-labelled CONTROL-scope fixture. Run the focused cases and keep their expected-red failures uncommitted.

4. **D — Record actual RED behavior. Check:** the Execution Log contains a `PRE-REPAIR RED` entry naming the observed result for every Step-C sentinel. If complete, record Already Applied; if partial, STOP. Otherwise append the exact admitted/refused result and error text for every fixture. The required causal baseline is that the current evaluator admits each D/F/H-J/K bypass; if a fixture is already refused by a relevant existing mechanism, classify it as Already Protected and remove only that unearned predicate from this contract before any evaluator edit.

5. **E — Minimum central evaluator repair. Check:** `scripts/check_agent_continuity.ps1` contains `function Evaluate-PreApprovalEvidence`, `function Get-SpecSequenceCursor`, `function Test-SpecIdEverReserved`, `SPEC_ID_NOT_NEXT`, `SPEC_ID_HISTORICALLY_RESERVED`, `SPEC_ALLOCATION_MARKER_MISSING`, and emits `APPROVAL_EVIDENCE: PASS`. If all exist, record Already Applied; if only a subset exists, STOP. Otherwise extend only this evaluator: parse/freeze the compact section; derive applicability from Write Scope, profiles, known control/governance surfaces, cross-path triggers, and irreversible-action declaration; make self-exemption contradictions `INDETERMINATE`; validate non-placeholder D fact/consumer rows without requiring one row per Write Scope file; compare only the four bounded F boundaries and ordered step references; require the H/J pre-Approval designs/obligations; and evaluate to PASS/FAIL/INDETERMINATE only on actual Draft-to-Approved transitions. Implement K before `Resolve-Contract`: derive the newest first-parent add/cross-ID-rename cursor, run existing `Base-HasId` unchanged first, then advance candidates through `Test-SpecIdEverReserved`, which answers one candidate at a time with exactly two Git queries anchored to the supplied ref — a content pickaxe and an added/renamed path walk — and never enumerates identities, consults `--all`, or persists state; preserve every existing collision error path, refuse historical reuse as `SPEC_ID_HISTORICALLY_RESERVED`, and reject local mismatch as `SPEC_ID_NOT_NEXT`. Read the activation marker from `CR_LIFECYCLE.md`, fail closed as `SPEC_ALLOCATION_MARKER_MISSING` when the working tree declares none, and do not let any diagnostic code participate in activation. Extend only `Validate-CommittedRange` for per-commit K: read the marker from each commit's first-parent `CR_LIFECYCLE.md`, skip commits whose parent declares none, validate every activated allocation against that parent, and append the offending short SHA. In BaseRef mode do not apply current K allocation enforcement retroactively to endpoint records when the base predates the marker; reservation is never gated by the marker. Before committing, prove this contract's `Pre-Approval Evidence` is byte-identical to its Approved baseline and that a reversible mutation is rejected. Leave `Resolve-Contract`, publication, hooks/workflows, certification receipts, database behavior, and Draft-only range semantics unchanged.

6. **F — Positive controls. Check:** every Step-C accepting sentinel has a passing assertion. If all pass, record Already Applied; if partial, STOP. Otherwise prove complete evidence, a closed-before-gate red window, derived Routine non-applicability, valid existing lifecycle paths, the next legal local identity, collision-driven candidate advancement, synthetic/prose tokens not moving the cursor, exceptional `SPEC-1000/1001` not displacing the later normal cursor, a legal post-activation range allocation, an identity absent from the entire reachable history remaining allocatable, and final-range carriage of both pre-marker Draft commits.

7. **G — Negative controls. Check:** every Step-C rejecting sentinel has the exact expected non-zero result/error assertion. If all pass, record Already Applied; if partial, STOP. Otherwise prove D malformed/empty/`UNKNOWN`/unresolved evidence, F's exact `SPEC-195` conflict, every missing H/J obligation, Routine self-exemption, local unused jump, independent reserved-ID collision, unresolved cursor, post-activation illegal allocation, post-activation illegal-then-correct history, reuse of an identity whose tracked text was deleted, reuse of an identity whose tracked path was deleted, and an absent activation marker all fail for their named reasons, and that renaming every emitted diagnostic code changes none of these outcomes.

8. **H — Predicate mutation/bypass proof. Check:** the harness contains `APPROVAL-EVIDENCE MUTATION POPULATION` and independently names every load-bearing D/F/H-J/K predicate from Step E. If both hold, record Already Applied; if only one holds, STOP. Otherwise copy the evaluator inside the existing temporary sandbox, bypass exactly one predicate per mutation, run the unchanged focused assertions, and require every mutation to be killed: derived applicability/self-exemption; section/frozen membership; D shape, disposition, evidence, `UNKNOWN`, unresolved; F boundary ordering/conflict; every H/J obligation; K cursor chronology, cross-ID rename, current-tree collision advancement, historical reservation content query, historical reservation path query, local invocation, first-parent marker activation, working-tree marker presence, and per-commit range invocation. Do not add a script, module, policy engine, registry, dependency graph, or temporal simulator.

9. **I — Non-empty populations. Check:** the harness asserts non-zero accept, reject, and mutation counts for D, F, H/J, K-local, K-reservation, K-activation, and K-range. If all counters exist and pass, record Already Applied; otherwise add only the missing counter assertions and run them. A zero population is a failure, never a skipped proof.

10. **J — Full control-plane regression. Check:** the Execution Log records a passing complete `scripts/test_agent_continuity.ps1` run at the implemented tree fingerprint. If present, record Already Applied; otherwise run the whole existing suite and require all pre-existing plus new cases to pass without changing their expected semantics.

11. **K — Repository profiles. Check:** the Execution Log records CLEAN Repository Consistency plus successful derived CONTROL and REPOSITORY profiles for the same fingerprint. If present, record Already Applied; otherwise run every profile derived by the Gate, `pwsh -NoProfile -File scripts/check_repository_consistency.ps1`, and `git diff --check`; verify only the seven Write Scope engineering paths plus this contract's permitted synchronization differ, and verify `SPEC-193/194/195` remain byte-identical and Cancelled. Do not contact either database.

12. **L — Performance and dependency regression. Check:** the Execution Log records five-post-warmup median comparisons for Boot, ordinary Gate, an identity-allocating Gate whose diff adds one new Change Request file, and `.githooks/pre-commit`, plus external-command interception. If present, record Already Applied. Otherwise use a temporary detached worktree at the Approved baseline and compare it with the implemented state; STOP if any after median exceeds twice baseline plus two seconds. The allocating Gate is measured separately because history-anchored reservation is the only new cost and is paid solely when a Change Request identity is allocated; if the ordinary Gate gains measurable cost, reservation is running where it must not. Intercept external executables in the disposable harness and fail if the new ordinary Gate path invokes web, model, database, Docker, Supabase, or heavy-network work. Remove the worktree; add no service, cache, daemon, or report.

13. **M — Finish. Check:** a fresh local certification receipt matches this CR identity, derived profiles, expected workflows, and current Write Scope fingerprint. If it matches, record Already Applied; otherwise run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and proceed only on `LOCAL_CERTIFY: READY`.

14. **N — Independent Review. Check:** Verification Notes contain a current `Verdict: Confirmed Complete` that independently addresses every Acceptance Criterion and Review Gate item against the live repository. If present, record Already Applied; otherwise perform that review from repository evidence rather than the Execution Log's assertions and append the result. A discrepancy stops completion.

15. **O — Complete under existing prerequisites. Check:** Status is `Complete`, Runtime Checkpoint is `DONE`, every checkbox is checked, Blocker is `None`, and manifest/ai-map are synchronized while Batch 6 Slice 12 remains `Next capability`. If all match, record Already Applied; if partial, STOP. Otherwise satisfy only the existing completion prerequisites, update the manifest fields together, regenerate `ai-map.json`, and commit the coherent terminal boundary without amend/rebase/squash/history rewrite.

16. **P — Existing candidate/preflight/promotion flow. Check:** the exact completed SHA is already the accepted `orvion-preflight` candidate or is already `origin/main`. If so, record Already Applied; otherwise invoke only `scripts/publish_candidate.ps1` with the captured completed SHA and the existing caller-pinned lease rule when replacement is applicable. Do not reproduce its sequence, push before its Gate, or promote a different SHA.

17. **Q — Publication-time committed-range proof. Check:** Step P's output records `ORVION: READY` for its captured `origin/main..<completed SHA>` before candidate push, and that exact range includes commits `3453750` and `d839ccd`. If present, record Already Applied; otherwise STOP before promotion. The completed `SPEC-196` must be the governing CR, both pre-K allocation events must be skipped by parent-state activation, and every post-K commit must be checked; `NO_GOVERNING_CR` is not acceptable at this stage. After exact-SHA acceptance, promote only that SHA to `main` by ordinary non-force push and fetch.

18. **R — Exact-SHA remote certification. Check:** local `HEAD`, `origin/main`, and the accepted SHA are identical, clean, and `0 0`, with required workflow conclusions recorded against that SHA. If all match, record Already Applied and stop. Otherwise run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Certify`, require `REMOTE_CERTIFY: READY`, fetch, and re-prove exact equality. Never force-push, rewrite history, contact either database, or resume Slice 12.

## Acceptance Criteria

- [ ] `ENGINEERING_METHOD.md`, `CR_LIFECYCLE.md`, and `changes/TEMPLATE.md` contain one aligned bounded pre-Approval evidence model, and no new Status or approval actor exists.
- [ ] `Pre-Approval Evidence` is frozen after Approval and is required only for governing contracts under the new format; terminal history is not retrofitted.
- [ ] Consumer Closure records changed facts/surfaces and relevant consumers rather than one row per Write Scope file, and rejects empty/placeholder evidence, invalid dispositions, `UNKNOWN`, and unresolved material consumers while preserving human semantic review.
- [ ] Execution-Boundary Satisfiability rejects the exact `SPEC-195` Step-10/12/13 contradiction and accepts a red window that closes before its mandatory boundary.
- [ ] Permanent-Control Admission freezes reuse, distinct-property, causal-negative, positive/negative design, non-empty-population, and mutation obligations before Approval, while actual positive/negative/population/mutation proof is required only after implementation through the certified CONTROL suite.
- [ ] Local Gate derives the legal SPEC identity from the newest first-parent CR allocation event, advances through tracked-text collisions independently, and rejects an arbitrary unused jump without a numeric maximum, fixture allowlist, or hard-coded `196`.
- [ ] Reservation is monotonic: an identity whose only tracked text or only tracked filename was later deleted can never be allocated again, while an identity absent from the whole reachable history stays allocatable and current-tree collision validation keeps its existing behaviour and error codes.
- [ ] K activation reads a declared marker owned by the identity authority, fails closed when that marker is missing from the working tree, and survives renaming every diagnostic code the evaluator emits.
- [ ] `Validate-CommittedRange` rejects an illegal post-activation allocation even when a later commit corrects it, while its first-parent marker rule permits the existing `3453750` and `d839ccd` pre-marker Draft commits in SPEC-196's final governing range.
- [ ] Derived applicability prevents a `Routine` label from exempting CONTROL/governance/significant work; an underivable exemption is `INDETERMINATE`.
- [ ] Local and committed-range Draft-to-Approved transitions both block FAIL and INDETERMINATE and admit PASS, while the human remains the only actor that performs Approval.
- [ ] Every new predicate has a non-empty mutation discriminator in the existing harness, and every valid control remains accepted.
- [ ] No new script, workflow, hook, service, schema, report, cursor registry, fixture allowlist, generic dependency engine, generic temporal engine, client authority, or mandatory skill is introduced.
- [ ] Measured Boot, Gate, and pre-commit performance stays within the frozen Step-L bound, and the new evaluator adds no web, model, database, Docker, Supabase, or heavy-network dependency.
- [ ] Only the seven engineering paths in Write Scope differ from the approved baseline; `SPEC-193`, `SPEC-194`, and `SPEC-195` remain byte-identical and terminal Cancelled.
- [ ] The manifest and generated ai-map synchronize only this control-plane capability and preserve Batch 6 Slice 12 as the next product capability.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.]

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Every new evaluator predicate is independently mutation-detected with a non-empty population.
- [ ] Consumer closure covers every declared changed fact/surface with relevant consumers and records no `UNKNOWN` or unresolved material consumer; it is not a per-file Write Scope duplicate.
- [ ] The execution-boundary table contains no invariant required green inside its own declared red window.
- [ ] K uses chronology rather than numeric maximum, keeps collision separate, and the activation/laundering fixtures pass in both directions.
- [ ] Reservation is proven monotonic against deleted text and deleted paths without a ledger, registry, or allowlist, and activation depends on no diagnostic string.
- [ ] Pre-Approval H/J fields contain obligations/designs rather than self-asserted post-implementation proof, and the certified suite supplies the actual proof before Complete.
- [ ] A self-declared Routine class does not suppress any repository-derived applicable block.
- [ ] The before/after performance evidence and external-command interception meet Step L exactly.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] The repository is in a clean, releasable state.

## Notes

Current-practice refresh on 2026-09-18 found no contradiction to repository-local deterministic correctness with thin client adapters and human approval:

- OpenAI documents repository `AGENTS.md` instructions and treats sandboxing/permissions, version control, tests, and review as separate layers: <https://developers.openai.com/codex/guides/agents-md> and <https://developers.openai.com/codex/agent-approvals-security>.
- GitHub's current official documentation supports repository `AGENTS.md` instructions and deterministic repository hooks while retaining user review responsibility: <https://docs.github.com/en/copilot/how-tos/configure-custom-instructions-in-your-ide/add-repository-instructions-in-your-ide>, <https://docs.github.com/en/copilot/concepts/agents/hooks>, and <https://docs.github.com/en/copilot/get-started/about-github-copilot>.
- Anthropic's current Claude Code documentation distinguishes interpreted instructions/skills from deterministic hooks and permission controls; its separately documented Auto mode is research preview, so this design depends on none of it: <https://code.claude.com/docs/en/features-overview>, <https://code.claude.com/docs/en/security>, and <https://code.claude.com/docs/en/permissions>.
- NIST SP 800-218 Version 1.1 is Final and recommends integrating secure-development practices into the existing SDLC rather than creating a parallel lifecycle: <https://csrc.nist.gov/pubs/sp/800/218/final>.

Bounded governance enforceability census: one materially distinct obligation was counted once at its owning location across `AGENTS.md`, `ENGINEERING_METHOD.md`, `CR_LIFECYCLE.md`, `GOVERNANCE.md`, and `changes/TEMPLATE.md`; pointer restatements, examples, and changelog history were deduplicated. Fifty material obligations were correctly classified HUMAN / SEMANTIC BY NATURE. No fifth reproduced deterministic gap passed the admission bar. The stale prose enumeration that omits harness fixtures `SPEC-902/903` is evidence within K and must be removed from allocation semantics, not replaced by another list.

The earlier Draft-only range result `NO_GOVERNING_CR` is PROVEN INTENTIONAL and not an acceptance criterion: ordinary local Gate permits Draft CR authoring only, whereas BaseRef mode requires an active or terminal governing CR. Final committed-range proof occurs in Step Q after SPEC-196 is governing. `Resolve-Contract` remains unchanged.

Phase-2 K attack evidence, 2026-09-18, in a disposable clone of `7b8c1c8` and read-only queries against `481048c`. Both K1 bypasses reproduced against the unmodified evaluator after a control proved the mechanism fires while the occurrence is present: a deleted tracked-text occurrence and a deleted tracked-filename occurrence each returned `ORVION: READY` for a new Change Request reusing that identity. The proposed history-anchored queries answer both correctly and do not over-reserve — the deleted text is found by content pickaxe, the deleted filename by the added/renamed path walk, and an identity never used is found by neither. Measured on `481048c` at 717 commits: content pickaxe 3.3 s, path walk 0.1 s, ordinary Gate 11.6 s. The added cost is therefore paid once per allocated identity and stays inside the Step-L bound, which is why reservation must never run on the ordinary Gate path. K2 reproduced as a design defect: renaming `HISTORICAL_CR_MUTATION` throughout the evaluator, a behaviour-preserving refactor of the identical first-parent sentinel pattern this contract originally proposed to copy, silently deactivated the guard and admitted a tampered terminal Change Request over unchanged history.

SUCCESSOR, not absorbed here: `Historical-Guard-IsActive` in the unmodified evaluator still activates on the diagnostic string `HISTORICAL_CR_MUTATION` and carries the defect reproduced above. It is reproduced and material, but repairing it is outside this contract's earned scope and its Write Scope authorizes no such step; widening the frozen contract to absorb it is forbidden. This contract therefore adds no second activation concept casually — it declares one stable marker for K and leaves the existing guard untouched and recorded, so the finding is neither silently abandoned nor executed without its own authority.

Rejected options: prose-only checklist expansion; agent-authored `READY`; numeric SPEC maximum; hard-coded `196`; manual cursor, exceptional-ID, or synthetic-fixture registry; a reservation ledger or identity database; sweeping all identities rather than querying one candidate; resolving reservation through `--all`, whose reachability is not clone-reproducible; a diagnostic string, log line, test count, or timestamp as an activation signal; a general enforcement-capability marker that would become a second policy authority; weakening collision validation; retroactive K allocation enforcement; endpoint-only history validation; a new policy engine or schema; dependency-graph or temporal-engine inference; new hooks/workflows/skills; and separate A/B/C/E/G/I fields.
