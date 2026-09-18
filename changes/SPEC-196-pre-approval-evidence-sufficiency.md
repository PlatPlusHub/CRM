# Change Request — SPEC-196

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Prevent approval of applicable ORVION changes until consumer closure, execution-boundary satisfiability, and permanent-control admission evidence are deterministically sufficient.

## Business Reason

Phase-1 adversarial testing reproduced only three material approval gaps: a contract can omit consumer closure; a frozen Significant sequence can require an invariant to be both red and green at the same mandatory boundary (the exact `SPEC-195` failure); and a permanent control can be admitted despite redundant or vacuous evidence. The repair must extend the existing Change Request, Gate, and mutation-harness mechanisms without turning prose completeness into a generic dependency or temporal engine. The earlier A/B/C concerns did not earn independent fields, E/G remain unproven, and I is already mechanically protected.

## Risks

An over-broad applicability rule could burden Routine work, while a prose-only or self-asserted result would preserve the gaps. A parser that is not exercised on both local and committed-range transitions could disagree with CI. The bounded representation, derived applicability rules, valid controls, predicate-by-predicate mutation attacks, and performance comparison below constrain those risks. No product, database, client-hook, workflow, or external-system behavior is changed.

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

### Consumer Closure

Applicability: APPLICABLE

Evidence Commands:
- `pwsh -NoProfile -File scripts/impact.ps1 -Target FrozenSections -NoDatabase -Full`
- `pwsh -NoProfile -File scripts/impact.ps1 -Target ControlSurface -NoDatabase -Full`
- `rg -n "FrozenSections|Get-ControlSurface|ContractText|changes/TEMPLATE|Design Challenge|cross-path|impact.ps1" AGENTS.md ENGINEERING_METHOD.md CR_LIFECYCLE.md changes/TEMPLATE.md scripts .githooks .claude .github README.md CLAUDE.md GEMINI.md llms.txt`

| Changed fact or surface | Consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Approval-evidence semantics | `ENGINEERING_METHOD.md` | WRITE | Existing owner of decision discipline, measurement integrity, and cross-path method; add one bounded subsection, not a second authority. |
| Human approval and frozen contract partition | `CR_LIFECYCLE.md` | WRITE | Existing owner of the Draft-to-Approved transition and immutable authority; human remains the only approver. |
| Per-contract representation | `changes/TEMPLATE.md` | WRITE | Existing contract schema; add exactly one compact frozen section. |
| Contract parsing, local Gate, and range Gate | `scripts/check_agent_continuity.ps1` | WRITE | Existing evaluator; extend `Contract`, frozen-section comparison, and transition validation without changing `Resolve-Contract`. |
| Behavioral and mutation proof | `scripts/test_agent_continuity.ps1` | WRITE | Existing disposable harness; no second test framework or script. |
| Active pointer and completion state | `_ORVION_CANONICAL/manifest.md` | WRITE | Lifecycle synchronization only; preserve Batch 6 Slice 12 as the next product capability. |
| Generated cold-start mirror | `ai-map.json` | WRITE | Regenerate only from the manifest after lifecycle synchronization. |
| Repository operating kernel | `AGENTS.md` | UNAFFECTED | Already routes decision/measurement/cross-path semantics to `ENGINEERING_METHOD.md` and CR mechanics to `CR_LIFECYCLE.md`. |
| Consumer discovery query | `scripts/impact.ps1` | VERIFY | Remains a repository/local-runtime lead generator and never becomes approval authority. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | Existing guard and Check 27 must remain clean; no new semantic parser is added there. |
| Local and remote adapters | `.githooks/pre-commit`; `.claude/hooks/session-state.ps1`; `.github/workflows/agent-control.yml`; `.github/workflows/orvion-acceptance.yml`; `.github/workflows/repository-consistency.yml` | UNAFFECTED | They continue invoking the same repository Gate and suites; no client-specific rule or workflow is added. |
| Candidate publication | `scripts/publish_candidate.ps1` | UNAFFECTED | Continue invoking the existing committed-range Gate and normal preflight publication path. |
| This contract | `changes/SPEC-196-pre-approval-evidence-sufficiency.md` | WRITE | Implicit workflow synchronization only, as already defined by `CR_LIFECYCLE.md §8`. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Existing control behavior remains green | BEFORE_IMPLEMENTATION, BEFORE_COMPLETION | NONE | NONE | 7 |
| New D/F/HJ attack assertions fail for the reproduced reasons, then pass only after evaluator repair | BEFORE_COMPLETION | 2 | 3 | 7 |
| Every new evaluator predicate has a non-empty mutation discriminator | BEFORE_COMPLETION | 2 | 4 | 7 |
| Repository consistency and generated-state checks are clean | BEFORE_IMPLEMENTATION, BEFORE_COMPLETION | NONE | NONE | 7 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `scripts/check_agent_continuity.ps1` owns contract evaluation and both local/range Gate paths; `scripts/test_agent_continuity.ps1` owns disposable behavioral and mutation attacks.

Added Property: A Draft-to-Approved transition is refused unless applicable consumer, boundary, and permanent-control evidence evaluates to PASS; no new Status or human-approval substitute is introduced.

Causal Negative: Phase 1 proved that the current Gate admits a semantically empty approval contract, admitted the frozen `SPEC-195` sequence whose Steps 10–13 force Check 10 red at the pre-deployment boundary, and allowed an exit-zero vacuous verification control to reach local certification while the fixed control-surface list omitted a newly introduced `scripts/check_*.ps1` file.

Positive Control: Current valid Draft-to-Approved behavior (`scripts/test_agent_continuity.ps1` case 64), valid committed-range lifecycle paths, and a complete applicable evidence fixture must continue to pass; an unrelated Routine repository-only fixture must remain minimal and pass with explicit non-applicability reasons.

Non-Empty Population: Each of Consumer Closure, Execution-Boundary Satisfiability, and Permanent-Control Admission has at least one rejecting fixture and one accepting fixture, and the harness asserts each population count is greater than zero.

Mutation Proof: Step 4 must bypass each newly added applicability, completeness, UNKNOWN/unresolved-consumer, boundary-conflict, control-admission, and transition-invocation predicate one at a time in an isolated copy of the existing evaluator and prove the unchanged suite detects every mutation.

## Implementation Steps

1. **Check:** `ENGINEERING_METHOD.md` contains the heading `### Pre-Approval evidence sufficiency`, `CR_LIFECYCLE.md` contains the sentence `Only PASS permits the human Draft-to-Approved decision`, and `changes/TEMPLATE.md` contains exactly one `## Pre-Approval Evidence` section. If all three match, record Already Applied; if only a subset matches, STOP with the exact partial state. Otherwise: (a) add one subsection under `ENGINEERING_METHOD.md §2` defining the bounded evidence model, the three applicability classes, the meaning of PASS/FAIL/INDETERMINATE, and the rule that semantic review remains human; (b) update `CR_LIFECYCLE.md §5` and §8 so only an evaluator PASS permits, but never performs, the human Draft-to-Approved transition and so `Pre-Approval Evidence` joins the frozen authority list; and (c) add exactly one `## Pre-Approval Evidence` section to `changes/TEMPLATE.md` after `Additional Verification`, using the exact field names and table columns demonstrated by this contract and `Applicability: NOT_APPLICABLE — <non-empty reason>` as the only non-applicable form. Preserve the five official Status values, human-only Approval, all existing evidence classes, and historical-terminal-file compatibility. Do not modify `AGENTS.md`, add another authority, or add standalone A/B/C/E/G/I fields. Do not commit Steps 1 or 2: the Approved/In-Progress commit that still contains this exact frozen evidence must remain the Git baseline until Step 3 installs and passes its frozen comparison.

2. **Check:** `scripts/test_agent_continuity.ps1` contains all three sentinels `APPROVAL-EVIDENCE D`, `APPROVAL-EVIDENCE F SPEC-195`, and `APPROVAL-EVIDENCE HJ`, plus `APPROVAL-EVIDENCE VALID CONTROLS`. If all four match, record Already Applied; if only a subset matches, STOP. Otherwise extend only `ContractText` and the existing disposable harness with RED assertions that first record the current pre-repair behavior: D rejects a missing table, a missing Write-Scope consumer row, `UNKNOWN`, and a non-`None` unresolved-material-consumer value; F reproduces `SPEC-195` with red opening after Step 10, restoration by Step 13, irreversible action at Step 12, and a green requirement at `BEFORE_IRREVERSIBLE_ACTION`; H/J rejects a missing existing-mechanism comparison, empty added property, absent causal negative, absent positive control, zero population, and absent mutation mapping. Add accepting controls for complete applicable evidence, a red window closed before its mandatory boundary, and an unrelated Routine repository-only contract with reasoned non-applicability. Run those new assertions against the unchanged evaluator, record exactly which expected rejections are admitted, and do not commit the deliberately red intermediate state.

3. **Check:** `scripts/check_agent_continuity.ps1` contains `function Evaluate-PreApprovalEvidence` and emits `APPROVAL_EVIDENCE: PASS`. If both match, record Already Applied; if only one matches, STOP. Otherwise extend that file only: require and parse the new section for governing contracts; add it to `$script:FrozenSections`; derive Consumer Closure applicability when the declared Change Class is `Significant` or `Owner-Decision` or a non-REPOSITORY verification profile is derived; derive boundary applicability for `Significant` and `Owner-Decision`; derive permanent-control applicability when Write Scope touches the existing executable Gate, repository guard, hook, or workflow enforcement surfaces (a new helper alone does not qualify, while wiring it into an enforcement surface does); and evaluate to exactly PASS, FAIL, or INDETERMINATE. INDETERMINATE covers missing/malformed/placeholders, `UNKNOWN`, unresolved material consumers, invalid step references, or a derived-applicable block marked not applicable. FAIL covers an unclassified declared consumer, a Write Scope entry absent from the closure table, a mandatory boundary falling inside its invariant's declared red window, a red window without opening/closing/gate positions, or an applicable permanent-control block missing any named admission proof. PASS requires none of those conditions. Invoke the evaluator only when a local endpoint or a walked committed range actually crosses Draft to Approved; print its derived result, and block Approval on FAIL or INDETERMINATE before write authority is emitted. Before any commit, prove this contract's `Pre-Approval Evidence` is byte-identical to the Approved/In-Progress Git baseline and that the newly installed frozen comparison rejects a reversible mutation to it. Leave `Resolve-Contract`, all five Status values, human transition ownership, profiles, certification receipts, publication, and all database behavior unchanged. Run the Step-2 assertions and require every reject and valid control to behave as named.

4. **Check:** `scripts/test_agent_continuity.ps1` contains the sentinel `APPROVAL-EVIDENCE MUTATION POPULATION` and independently names every predicate introduced in Step 3. If both conditions hold, record Already Applied; if only one holds, STOP. Otherwise add mutation calibration inside the existing harness: copy the evaluator to the harness's temporary sandbox, bypass one predicate at a time (the three applicability derivations; required section/frozen membership; consumer-row, UNKNOWN, unresolved, and Write-Scope coverage; boundary position/conflict; all six permanent-control admission fields; local transition invocation; committed-range transition invocation), run the unchanged focused assertions against each copy, and require at least one expected assertion to fail for every mutation. Assert the mutation population and each reject/accept fixture population are non-zero. Do not add a script, module, schema, generic dependency graph, or generic temporal engine.

5. **Check:** the Execution Log already records one post-repair run in which the complete control suite passes, repository consistency is clean, and `git diff --check` exits zero. If present, record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/test_agent_continuity.ps1`, every CONTROL-profile suite derived by `scripts/check_agent_continuity.ps1`, `pwsh -NoProfile -File scripts/check_repository_consistency.ps1`, and `git diff --check`; require the D, exact `SPEC-195` F, H/J, valid-control, local-transition, and committed-range cases to pass. Verify the seven Write Scope paths are the only changed engineering paths, the three terminal contracts are byte-identical, and no Primary or Secondary capability was invoked.

6. **Check:** the Execution Log already records before/after median wall times for Boot, Gate, and `.githooks/pre-commit`, plus proof that no new web, model, database, Docker, Supabase, or heavy-network call was added. If present, record Already Applied. Otherwise create a temporary detached worktree at this contract's approved baseline commit and compare five post-warmup runs there with five post-warmup runs of the implemented state for each command, recording all six medians in the Execution Log; intercept external executables in the disposable harness and fail if the new evaluator invokes any of them. STOP if any after median exceeds twice its baseline plus two seconds. Remove the temporary worktree. Do not change the existing Git fetch behavior outside the new evaluator, and do not add a performance service, cache, daemon, or report.

7. **Check:** this contract's Runtime Checkpoint is `DONE`, every Acceptance Criterion and Review Gate item is checked, and Verification Notes contain `Verdict: Confirmed Complete`. If all match, record Already Applied; if only a subset matches, STOP. Otherwise run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish`; proceed only after its local certification succeeds, independently review every criterion against the live repository, append the execution and review evidence, set the checkpoint to `DONE`, synchronize the legal terminal state and `_ORVION_CANONICAL/manifest.md` while preserving Batch 6 Slice 12 as `Next capability`, regenerate `ai-map.json` with `scripts/generate-ai-map.ps1`, and commit without amending, squashing, rebasing, or rewriting history.

8. **Check:** `origin/main` equals the exact locally completed commit, the working tree is clean, and `git rev-list --left-right --count HEAD...origin/main` is `0 0`. If all match, record Already Applied and stop. Otherwise use only the existing publication path: publish the captured completed SHA with `scripts/publish_candidate.ps1`, verify the required acceptance result on that exact SHA, promote that exact accepted SHA to `main` with an ordinary non-force push, fetch, run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Certify`, and require clean `0 0` synchronization. Never force-push, rewrite history, contact either database, resume Slice 12, or alter a terminal contract.

## Acceptance Criteria

- [ ] `ENGINEERING_METHOD.md`, `CR_LIFECYCLE.md`, and `changes/TEMPLATE.md` contain one aligned bounded pre-Approval evidence model, and no new Status or approval actor exists.
- [ ] `Pre-Approval Evidence` is frozen after Approval and is required only for governing contracts under the new format; terminal history is not retrofitted.
- [ ] Consumer Closure deterministically rejects missing Write-Scope coverage, invalid dispositions, `UNKNOWN`, and unresolved material consumers while preserving `scripts/impact.ps1` as evidence rather than authority.
- [ ] Execution-Boundary Satisfiability rejects the exact `SPEC-195` Step-10/12/13 contradiction and accepts a red window that closes before its mandatory boundary.
- [ ] Permanent-Control Admission requires an existing-mechanism comparison, a distinct added property, a causal negative, a positive control, non-empty populations, and a predicate-level mutation mapping without classifying every helper as a control.
- [ ] Local and committed-range Draft-to-Approved transitions both block FAIL and INDETERMINATE and admit PASS, while the human remains the only actor that performs Approval.
- [ ] Every new predicate has a non-empty mutation discriminator in the existing harness, and every valid control remains accepted.
- [ ] No new script, workflow, hook, service, schema, report, generic dependency engine, generic temporal engine, client authority, or mandatory skill is introduced.
- [ ] Measured Boot, Gate, and pre-commit performance stays within the frozen Step-6 bound, and the new evaluator adds no web, model, database, Docker, Supabase, or heavy-network dependency.
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
- [ ] Consumer closure covers every Write Scope path and records no `UNKNOWN` or unresolved material consumer.
- [ ] The execution-boundary table contains no invariant required green inside its own declared red window.
- [ ] The before/after performance evidence and external-command interception meet Step 6 exactly.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] The repository is in a clean, releasable state.

## Notes

Current-practice refresh on 2026-09-18 found no contradiction to repository-local deterministic correctness with thin client adapters and human approval:

- OpenAI documents repository `AGENTS.md` instructions and treats sandboxing/permissions, version control, tests, and review as separate layers: <https://developers.openai.com/codex/guides/agents-md> and <https://developers.openai.com/codex/agent-approvals-security>.
- GitHub's current official documentation supports repository `AGENTS.md` instructions and deterministic repository hooks while retaining user review responsibility: <https://docs.github.com/en/copilot/how-tos/configure-custom-instructions-in-your-ide/add-repository-instructions-in-your-ide>, <https://docs.github.com/en/copilot/concepts/agents/hooks>, and <https://docs.github.com/en/copilot/get-started/about-github-copilot>.
- Anthropic's current Claude Code documentation distinguishes interpreted instructions/skills from deterministic hooks and permission controls; its separately documented Auto mode is research preview, so this design depends on none of it: <https://code.claude.com/docs/en/features-overview>, <https://code.claude.com/docs/en/security>, and <https://code.claude.com/docs/en/permissions>.
- NIST SP 800-218 Version 1.1 is Final and recommends integrating secure-development practices into the existing SDLC rather than creating a parallel lifecycle: <https://csrc.nist.gov/pubs/sp/800/218/final>.

Rejected options: prose-only checklist expansion (cannot refuse Approval); agent-authored `READY` text (self-assertion); a new policy engine or schema (unearned duplicate authority); dependency-graph or temporal-engine inference (broader than the reproduced gaps); new hooks/workflows/skills (the existing adapters already invoke the Gate); and separate A/B/C/E/G/I fields (not independently earned).
