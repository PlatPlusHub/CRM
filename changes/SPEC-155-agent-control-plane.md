# Change Request — SPEC-155

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
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

Resume Step: DONE
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

- [x] Boot derives PLAN, READY_FOR_APPROVAL, EXECUTE, VERIFY, and BLOCKED without changing official CR statuses.
- [x] Boot returns exact task/action/scope/context/capabilities/verification/Git/repository/blocker state compactly.
- [x] PLAN has no implementation authority and preserves the pre-existing Next capability.
- [x] Gate rejects malformed contracts, invalid checkpoints, missing capabilities, repository failures, and out-of-scope writes while reads remain unrestricted.
- [x] Mandatory REPOSITORY/CONTROL/CI/WORKSTATION/DATABASE profiles derive from paths and cannot be subtracted.
- [x] AGENTS.md is below 16 KiB and preserves kernel rules and compatibility routing.
- [x] Handoff uses CR/checkpoint/manifest/Git/tests, not chat or a mandatory report.
- [x] Recovery is bounded to three evidence-distinct attempts; owner escalation follows Decision Exhaustion.
- [x] Local hook and remote CI are thin adapters over one gate.
- [x] All 26 required adversarial cases and affected existing guards pass.
- [x] No migration, domain behavior, historical report, completed CR, Canon organization, RAG, vector DB, graph, daemon, watcher, or semantic engine changes.

## Execution Log

### 2026-09-11 — Codex

Outcome: Complete

Step results:
- Steps 1–4: Applied and proven by the 31-case control suite and repository consistency guard.
- Steps 5–6: Applied and proven by the real hook rejection, doctor hook detection, workflow validation, and range-resolution mutations.
- Step 7: Applied; generated routing, Boot, cold-start, Gate and Finish certified locally.

Commits: `38c4e9a`, `e0d897b`, and the completion commit containing this entry.

Blocker: None.

## Verification Notes

### 2026-09-11 — Codex independent live-state review

Verdict: Confirmed Complete

Findings: `test_agent_continuity.ps1` passed 31/31; `test_cold_start_state_guard.ps1` passed 34/34; status-contradiction and Primary-ledger suites passed 33/33 and 13/13; repository consistency was CLEAN; Boot recovered SPEC-155 at DONE and Finish returned CERTIFY READY; `git diff --check` passed; AGENTS.md measured 12,984 bytes; changed-path audit found no migration, historical-report, completed-CR, or Canon-roadmap mutation. Workstation doctor reported the new hook check OK and separately retained its pre-existing canonical-origin URL failure.

Recommendation to human: autonomous Complete is authorized by the owner directive and `CR_LIFECYCLE.md §5`.

## Review Gate

- [x] Every approved step is complete or truthfully recorded.
- [x] Every changed path is within Write Scope.
- [x] Every Acceptance Criterion is proven from live evidence.
- [x] Continuity and affected existing guard suites pass.
- [x] Repository consistency, generated artifacts, diff checks, hook, workflow, Boot, cold-start, and Finish pass.
- [x] AGENTS.md is below 16 KiB and live legacy references resolve.
- [x] No forbidden business/domain/database/history surface changed.
- [x] Repository is locally releasable; post-push CI must be verified before the final report.

## Notes

External refresh completed against official OpenAI, Git, and GitHub sources before implementation.
