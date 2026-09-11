# Change Request — SPEC-1001

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

Owner authorization: the 2026-09-11 owner directive titled “ORVION — OWNER-DIRECTED CORRECTIVE REPAIR” authorizes this exact Change Request.

## Objective

Correct the defective Agent Control Plane refactor by repairing its SPEC identity collision, restoring lost owner-ratified execution authority, eliminating false mechanical-certification claims and bypasses, and behaviorally proving the corrected control boundaries without changing ORVION product or database behavior.

## Business Reason

The Agent Control Plane must preserve established product history and owner-ratified execution authority while making only mechanically observable claims about repository control and local certification.

## Risks

An incorrect identity repair could overwrite product history, and an incorrect guard repair could admit unauthorized writes or certify checks it did not execute. The exact owner-directed scope, commit order, mutation tests, independent review, and remote evidence requirements constrain those risks.

## Supersedes / Depends On

Depends on the completed Agent Control Plane Change Request originally committed as `changes/SPEC-155-agent-control-plane.md`; this corrective CR renumbers only that conflicting control-plane artifact and does not supersede the pre-existing product `SPEC-155` lineage.

## Write Scope

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `changes/SPEC-155-agent-control-plane.md`
- `changes/SPEC-1000-agent-control-plane.md`
- `changes/SPEC-1001-agent-control-plane-corrective-repair.md`
- `_ORVION_CANONICAL/manifest.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `.github/workflows/agent-control.yml`
- `ai-map.json`
- `reports/README.md`
- `reports/history/agent-control-plane-corrective-repair-2026-09-11.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/**`
- `_ORVION_CANONICAL/00_project_charter.md` through `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`
- `reports/master/**`
- `reports/evidence/**`
- all existing `reports/history/**`
- `CODING_STANDARDS.md`
- `GOVERNANCE.md`
- `README.md`
- `CLAUDE.md`
- `GEMINI.md`
- `.github/copilot-instructions.md`
- `llms.txt`
- `.workstation/**`
- `.githooks/**`
- `.mcp.json`
- `package.json`
- `package-lock.json`

## Required Reading

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
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `CODING_STANDARDS.md`
- `reports/README.md`
- `ai-map.json`
- pre-refactor `AGENTS.md` at `8d67f776a59820205d643253a6a59922b6e207e5`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

- pwsh -NoProfile -File scripts/test_agent_continuity.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/check_repository_consistency.ps1
- git diff --check

## Implementation Steps

1. Verify the repository-wide SPEC census and generated identifiers, then establish this owner-authorized corrective CR and activate it in the manifest without implementing the repair.
2. Verify the conflicting Agent Control Plane file is still `changes/SPEC-155-agent-control-plane.md`, then rename it to `changes/SPEC-1000-agent-control-plane.md`, correct only its self-identifier, append the exact identity note, update the manifest reference, and regenerate `ai-map.json`.
3. Verify the pre-refactor owner-ratified wording at commit `8d67f776a59820205d643253a6a59922b6e207e5`, then restore only the directed §1, §3, and §6 authority and remove the numeric AGENTS size ceiling.
4. Verify the current control script defects, then repair CR identity parsing, global new-ID uniqueness, closed-CR immutability, repository-guard enforcement, fresh local Git checks, range-mode independence, Boot scope checks, multiline steps, deterministic capability probes, recovery exhaustion, and executable Finish behavior.
5. Verify the current template and lifecycle wording, then make Additional Verification executable-command-only and document terminal CR history, the one-time identity correction, local Finish certification, and separate remote CI evidence without changing the official states.
6. Verify the current test suite and workflow, then add the required behavioral attacks and structural policy-anchor tests and update Agent Control CI to test before gating the actual push or PR range.
7. Execute every required local verification, set the Runtime Checkpoint to DONE, obtain `LOCAL_CERTIFY: READY`, push the In-Progress implementation, and observe successful Agent Control and Repository Consistency runs at the exact SHA.
8. Independently re-read and audit the final implementation against the starting HEAD, append a Confirmed Complete verdict only when proven, complete and synchronize this CR, create the earned forensic report, regenerate `ai-map.json`, push, and verify final local and remote state.

## Acceptance Criteria

- [x] The Agent Control Plane CR is uniquely identified as SPEC-1000 and the pre-existing product SPEC-155 lineage remains unchanged.
- [x] The directed owner-ratified execution, architecture-decision, and measurement-integrity authority is restored at the referenced AGENTS sections.
- [x] No numeric AGENTS byte ceiling or repository-guard bypass remains.
- [x] CR identity, global new-ID uniqueness, terminal-history immutability, fresh local Git, range mode, Boot scope, multiline action, deterministic capabilities, recovery exhaustion, and executable Finish are behaviorally enforced as directed.
- [x] Additional Verification is executable-command-only for new CRs and remains additive.
- [x] Agent Control CI runs the control suite before Gate and uses the actual push/PR range without upstream or asserted capabilities.
- [x] All required behavioral and structural policy-anchor tests pass with their evidence classes stated honestly.
- [x] Local Finish actually executes required checks and ends with `LOCAL_CERTIFY: READY`.
- [x] Both required workflows succeed on the In-Progress SHA and final completion SHA.
- [x] Only exact Write Scope paths differ from starting HEAD; all forbidden product, database, Canon-domain, roadmap, Master, evidence, existing-history, workstation, MCP, and dependency surfaces remain unchanged.

## Execution Log

### 2026-09-11 — Codex

Outcome: Complete

Step results:
- Step 1: Applied — exact baseline passed; repository-wide census produced SPEC-1000 and SPEC-1001; corrective authority and active manifest state established.

Commits: pending first corrective commit.

### 2026-09-11 — Codex enforcement repair

Outcome: Complete

Step results:
- Step 2: Applied — Agent Control Plane identity corrected to SPEC-1000 while preserving product SPEC-155 history.
- Steps 3–6: Applied — directed AGENTS authority, parser/Gate/Finish controls, lifecycle/template contract, 45-case mutation suite, and CI range workflow repaired.

Commits: `66eaea6`, `dfcb44a`, and the pending enforcement-repair commit.

### 2026-09-11 — Codex remote CI correction

Outcome: Complete

Step results:
- Step 7: Initial push `5d78aacd5335278c5b03edb0b3f969bd86e6b9c4` produced Repository Consistency success and Agent Control failure because the disposable test hook lacked the Unix working-file executable bit.
- Step 7: Applied the authorized cross-platform fixture correction, reran `-Finish` to `LOCAL_CERTIFY: READY`, and pushed `e2b975ac98d5619a550a48db79437194370b4636`; Agent Control succeeded. Repository Consistency was not triggered by that one-file path-filtered push, so a synchronized CR evidence commit will obtain both exact-SHA results before review.

Commits: `e2b975a` and the pending evidence-synchronization commit.

### 2026-09-11 — Codex completion

Outcome: Complete

Step results:
- Step 7: Applied — evidence-synchronization commit `7b2749aa3aee186100c91d697d9aa9d67e84afbf` produced successful Agent Control and Repository Consistency runs for the exact In-Progress SHA.
- Step 8: Applied — independent live-state review confirmed every correction and the write-scope/forbidden-path boundaries; completion state, earned history report, report pointer, and generated routing were synchronized.

Commits: the completion commit containing this entry.

## Verification Notes

### 2026-09-11 10:46 +03:00 — Codex independent live-state review

Verdict: Confirmed Complete

Findings: Re-read every required final authority and inspected the complete diff from `6fdc4af5e9930f81d6ff54fc1c4db15808559c62`. The product SPEC-155 lineage remains present (23 scoped matches) while the former control-plane collision phrase has zero matches; SPEC-1000 owns the corrected control-plane CR and SPEC-1001 owns this repair. The restored §3 and §6 authority is present; active control surfaces contain no 16-KiB failure and the production script has no `SkipRepositoryGuard` parameter. A completion-draft Gate exposed that local mode did not recognize the legal HEAD `In Progress` to working-tree `Complete` transition; the in-scope repair now validates HEAD as the local base, and case 32 attacks both local and detached CI completion paths. The full corrected `-Finish` rerun returned `LOCAL_CERTIFY: READY`: 45/45 control, 34/34 cold-start, 33/33 status, 13/13 ledger, 5/5 date, and Repository Consistency CLEAN. Cases 1–43 are behavioral; cases 44–45 are explicitly structural policy-anchor tests. Agent Control and Repository Consistency both succeeded for exact In-Progress SHA `7b2749aa3aee186100c91d697d9aa9d67e84afbf`. Changed-path comparison found only authorized Write Scope paths and no forbidden product, database, Canon-domain, roadmap, Master, evidence, existing-history, workstation, MCP, or dependency change.

Recommendation to human: Set Status to Complete.

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

The repository-wide algorithm observes tracked test-fixture identifier `SPEC-999`; therefore the mechanically generated identifiers are SPEC-1000 and SPEC-1001.
