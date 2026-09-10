# Change Request — SPEC-155

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

Owner authorization: the 2026-09-11 owner directive titled “ORVION — OWNER-AUTHORIZED DETERMINISTIC AGENT CONTROL PLANE REFACTOR” authorizes this exact Change Request.

## Objective

Build a deterministic, low-context Agent Control Plane that preserves ORVION's existing truth and governance while making task state, handoff, write authority, verification, recovery, and completion mechanically enforceable for future agents.

## Business Reason

Future agents must recover the exact approved task, next action, write boundary, required context, verification obligations, and blocker state from repository evidence without chat history or broad mandatory preload.

## Risks

An incorrect parser or adapter could block valid work or admit unauthorized writes. The implementation is fail-closed, mutation-tested, bounded to control-plane files, and preserves database/domain behavior.

## Supersedes / Depends On

None.

## Write Scope

- `AGENTS.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `changes/SPEC-155-agent-control-plane.md`
- `_ORVION_CANONICAL/manifest.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/generate-ai-map.ps1`
- `ai-map.json`
- `.githooks/pre-commit`
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.github/workflows/agent-control.yml`
- `.claude/hooks/session-state.ps1`
- `README.md`
- `CLAUDE.md`
- `GEMINI.md`
- `.github/copilot-instructions.md`
- `llms.txt`
- `reports/README.md`

Repository reading is unrestricted. Required Reading never grants write authority.

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/**`
- `_ORVION_CANONICAL/32_execution_roadmap.md`
- `reports/history/**`
- `reports/master/**`
- `reports/evidence/**`
- `.mcp.json`

## Required Reading

- `AGENTS.md`
- `GOVERNANCE.md §2, §6, §8, §15, §18, §19`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `_ORVION_CANONICAL/manifest.md`
- `scripts/check_repository_consistency.ps1` active-CR and routing checks
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`

Additional repository reading/search is always allowed for evidence, dependency tracing, impact verification, and current-state verification.

## Runtime Checkpoint

Resume Step: 5
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

- Prove cold-start recovery returns this CR, Resume Step, and exact action without chat context.
- Prove the pre-commit adapter rejects an injected out-of-scope write in a reversible sandbox.

## Implementation Steps

1. PRECHECK and establish the deterministic CR/checkpoint parser, Boot/Gate/Finish interfaces, runtime modes, write-scope enforcement, capability checks, verification profiles, and compact fail-closed output in `scripts/check_agent_continuity.ps1`.
2. Add deterministic adversarial mutation coverage in `scripts/test_agent_continuity.ps1` for all 26 owner-required cases using temporary fixtures and no LLM.
3. Reduce `AGENTS.md` to a universal operating kernel and compact routing map below 16 KiB while preserving active rules through their existing authority or compatibility pointers.
4. Synchronize `GOVERNANCE.md`, `CR_LIFECYCLE.md`, `changes/TEMPLATE.md`, and only factually affected routers with runtime, read/write, handoff, freshness, recovery, decision-exhaustion, and report policy.
5. Add the thin pre-commit adapter, configure `core.hooksPath=.githooks` in workstation preparation, and verify it in workstation doctor.
6. Add unfiltered push/pull-request CI enforcement using the same gate and conservative governing-CR range resolution.
7. Regenerate affected artifacts, execute all focused and affected guards, certify Boot/cold-start/Finish, synchronize CR/manifest, commit in at most three checkpoints, push normally once, and verify SHA and CI.

## Acceptance Criteria

- [ ] Boot derives PLAN, READY_FOR_APPROVAL, EXECUTE, VERIFY, and BLOCKED without changing official CR statuses.
- [ ] Boot returns exact task/action/scope/context/capabilities/verification/Git/repository/blocker state compactly.
- [ ] PLAN has no implementation authority and preserves the pre-existing Next capability.
- [ ] Gate rejects malformed contracts, invalid checkpoints, missing capabilities, repository failures, and out-of-scope writes while reads remain unrestricted.
- [ ] Mandatory REPOSITORY/CONTROL/CI/WORKSTATION/DATABASE profiles derive from paths and cannot be subtracted.
- [ ] AGENTS.md is below 16 KiB and preserves kernel rules and compatibility routing.
- [ ] Handoff uses CR/checkpoint/manifest/Git/tests, not chat or a mandatory report.
- [ ] Recovery is bounded to three evidence-distinct attempts; owner escalation follows Decision Exhaustion.
- [ ] Local hook and remote CI are thin adapters over one gate.
- [ ] All 26 required adversarial cases and affected existing guards pass.
- [ ] No migration, domain behavior, historical report, completed CR, Canon organization, RAG, vector DB, graph, daemon, watcher, or semantic engine changes.

## Execution Log

No execution entries yet.

## Verification Notes

No verification entries yet.

## Review Gate

- [ ] Every approved step is complete or truthfully recorded.
- [ ] Every changed path is within Write Scope.
- [ ] Every Acceptance Criterion is proven from live evidence.
- [ ] Continuity and affected existing guard suites pass.
- [ ] Repository consistency, generated artifacts, diff checks, hook, workflow, Boot, cold-start, and Finish pass.
- [ ] AGENTS.md is below 16 KiB and live legacy references resolve.
- [ ] No forbidden business/domain/database/history surface changed.
- [ ] Repository is clean, pushed normally, and relevant CI is successful.

## Notes

External refresh completed against official OpenAI, Git, and GitHub sources before implementation.
