# Change Request — SPEC-188

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make every workstation desired-state fact have exactly one owning file that `prepare.ps1` and `doctor.ps1` read rather than restate, and make the control plane derive the `WORKSTATION` profile — and the repository consistency guard's own CI triggers — for the workstation entry points and desired-state files they did not cover.

## Business Reason

This contract is the corrective successor to `SPEC-186`, whose objective it keeps unchanged. `SPEC-186` was cancelled at Step 7 as `WRITE_SCOPE_INSUFFICIENT`: its Check 28 reads `.vscode/extensions.json` and `.mcp.json`, so Check 20 (CI-1) requires both paths in `.github/workflows/repository-consistency.yml`, and that workflow was not in its Write Scope. Completing it would have closed the capability with a known remote coverage gap, which is in-unit debt rather than a finished capability. The only correction is the one file this contract adds.

The underlying defects are unchanged and were each observed live. The required VS Code extension identities existed in four places and DID drift: `2ded739` removed `openai.chatgpt` from the provisioner and updated the manifest while `.vscode/extensions.json` kept it, and the repair `8d67f77` hand-synchronized them by adding a THIRD copy to `doctor.ps1`. No guard covered any of it — zero of the consistency guard's 27 checks read a workstation file. Both scripts already parsed `.mcp.json` and then ignored it for hardcoded name and argument lists, so a fifth project MCP would be neither registered nor verified, silently. `.workstation/update.ps1` wrapped native `winget` and `npm` calls in `try`/`catch`, which does not observe a native non-zero exit, so every upgrade step reported `ok` whatever happened. `.workstation/reports/INSTALLATION_STATUS.md` was consumed by `WORKSTATION.md` as "Current install status" while asserting a `READY` state that live verification contradicted on four axes. And `Profiles` derived `WORKSTATION` only for `^\.workstation/`, so a change to `bootstrap.ps1` — the single entry point for a fresh machine — earned no workstation verification at all.

## Risks

Moderate and bounded, and unchanged from `SPEC-186` except for the added workflow. The provisioner and the doctor change how they obtain their required sets; a malformed or empty authority file must fail closed rather than silently verify nothing, which is addressed by explicit emptiness checks in both scripts. Widening `Profiles` and the guard's CI triggers makes more changes run workstation and consistency verification; that is the intended effect. The `winget` exit-code classification risks converting a normal no-op into a false red, which is why exactly two documented success-equivalent codes are treated as up-to-date and everything else is reported with its code. Adding trigger paths to `.github/workflows/repository-consistency.yml` can only cause the guard to run on more commits, never fewer. No credential, OAuth boundary, or user configuration is read, written, or overwritten.

## Supersedes / Depends On

This contract is `SPEC-188`, not `SPEC-187`. Naming the intended successor inside `SPEC-186`'s cancellation permanently retired `SPEC-187` under the collision rule (`CR_LIFECYCLE.md` §4): any tracked textual occurrence reserves an identifier, deliberately, and a later agent must not "fix" that by reusing the number. Step 11 removes the one remaining textual reference to the retired identity.

Supersedes `changes/SPEC-186-workstation-desired-state-has-one-owner.md`, which is already `Cancelled` and records this contract as its successor. That file is terminal and is NOT in this contract's Write Scope; it is never reopened or edited. The implementation `SPEC-186` committed at `7e62849` is preserved and is not reimplemented here — the steps below detect it and record it as Already Applied.

## Write Scope

- `changes/SPEC-188-workstation-desired-state-has-one-owner.md`
- `.github/workflows/repository-consistency.yml`
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.workstation/update.ps1`
- `.workstation/manifest.md`
- `.workstation/reports/INSTALLATION_STATUS.md`
- `WORKSTATION.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-186-workstation-desired-state-has-one-owner.md`
- `.vscode/extensions.json`
- `.mcp.json`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `.workstation/menu.ps1`
- `.workstation/cleanup.ps1`
- `.workstation/decommission.ps1`
- `.workstation/claude-awareness.ps1`
- `.workstation/reports/INCIDENT_CLAUDE_MEM_WINDOWS.md`
- `bootstrap.ps1`
- `workstation.cmd`
- `.claude/awareness.json`
- `package.json`
- `package-lock.json`
- `README.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `CLAUDE.md`
- `GEMINI.md`
- `llms.txt`
- `.github/copilot-instructions.md`
- `.cursor/rules/orvion.mdc`
- `changes/TEMPLATE.md`
- `supabase/migrations`
- `supabase/tests`

`.vscode/extensions.json` and `.mcp.json` are the authorities this contract makes the scripts consume. Their content is deliberately not edited, so that the proof that the scripts now read them cannot be confused with a proof that they were edited to match. `.github/workflows/repository-consistency.yml` is in scope for its `paths:` trigger lists ONLY — no job, step, condition, runner or permission in it is changed.

Also out of scope as SUBJECTS, not merely as files: any new workstation data file, inventory or manifest format, including `.workstation/inventory.psd1`; any host-tool, winget or npm-package inventory refactor; any retry, backoff or recovery state machine; any change to `-Finish`, `-Gate`, `-Certify` or Publisher; any change to Docker detection, Docker installation-path resolution, or Docker readiness behaviour; any change to WSL detection, installation or elevation behaviour; any change to `doctor.ps1` from an observer into a mutator; any new root `.cmd` entry point; any change to the boot chain, README routing or client adapter files; GitHub Rulesets; skipping or conditioning any existing guard execution; and any new test harness, mutation framework or generic configuration/dependency engine.

## Required Reading

- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.workstation/update.ps1`
- `.workstation/manifest.md`
- `.vscode/extensions.json`
- `.mcp.json`
- `.github/workflows/repository-consistency.yml`
- `changes/SPEC-186-workstation-desired-state-has-one-owner.md`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- `pwsh -NoProfile -File .workstation/doctor.ps1`

## Implementation Steps

1. **Provisioner reads the extension authority.** In `.workstation/prepare.ps1`, search for `$requiredExtensions = @((Get-Content -Raw (Join-Path $Root ".vscode\extensions.json")`. If it is present, record Already Applied. If it is absent, replace the literal `$requiredExtensions` assignment with a read of `recommendations` from `.vscode/extensions.json` relative to `$Root`, and add a fail-closed branch that emits `[FAIL] .vscode/extensions.json declares no required extensions`, records a `FAILED` note for `VS Code extensions`, and skips the install loop when the array is empty.

2. **Doctor reads the same extension authority.** In `.workstation/doctor.ps1`, search for `$requiredExtensions = @((Get-Content -Raw ".vscode\extensions.json"`. If it is present, record Already Applied. If it is absent, apply the same replacement, with a fail-closed branch calling `Fail` with `.vscode/extensions.json declares no required extensions` when the array is empty.

3. **Provisioner registers project MCPs from `.mcp.json`.** In `.workstation/prepare.ps1`, search for `$projectMcp = @($mcp.mcpServers.PSObject.Properties)`. If it is present, record Already Applied. If it is absent, replace the four literal `Ensure-CodexMcp` calls for the project servers with one loop over `$mcp.mcpServers` that passes the server's `url` when the definition carries one and otherwise its `command` followed by its `args`, preceded by a fail-closed branch when no server is declared. The `github` call remains literal and unchanged as the one workstation-specific server.

4. **Doctor verifies the servers `.mcp.json` declares.** In `.workstation/doctor.ps1`, search for `$projectMcpNames`. If it is present, record Already Applied. If it is absent, replace the hardcoded inventory assertion with a derivation that parses `.mcp.json`, fails when it declares no servers, otherwise passes with the declared count, and drives both the Claude and the Codex enumeration loops from that derived list; the Codex loop additionally checks `github`.

5. **Update reports native failures.** In `.workstation/update.ps1`, search for `$UpToDateExitCodes`. If it is present, record Already Applied. If it is absent, change `Step` to reset `$global:LASTEXITCODE` before invoking the scriptblock and then classify by it: `0` records `ok`; the two documented winget success-equivalents `-1978335189` and `-1978335135` record `up to date`; any other non-zero value records `FAILED (exit <code>)`; a thrown exception still records `FAILED`. The winget loop preserves the first non-success code so a later success cannot mask an earlier failure.

6. **`WORKSTATION` covers the entry points and the authorities.** In `scripts/check_agent_continuity.ps1`, search for `bootstrap\.ps1$|workstation\.cmd$`. If it is present, record Already Applied. If it is absent, widen the single `WORKSTATION` line in `Profiles` so its pattern also matches `bootstrap.ps1`, `workstation.cmd`, `.vscode/extensions.json` and `.mcp.json` anchored as whole paths. No other line of `Profiles` is changed.

7. **One guard covers the remaining prose copies.** In `scripts/check_repository_consistency.ps1`, search for `Check 28: workstation desired state has ONE owner (WS-1)`. If it is present, record Already Applied. If it is absent, add a Check 28 that compares the extension identifiers in `.workstation/manifest.md`'s "Required VS Code extensions" table against the `recommendations` array of `.vscode/extensions.json`, and the server names in its "MCP inventory and authentication" table, excluding `github`, against the `mcpServers` property names of `.mcp.json`, reporting every element present in one authority and absent from the other and failing the guard on any difference. Register it in the guard's header summary list.

8. **The coverage repair is asserted.** In `scripts/test_agent_continuity.ps1`, search for `168 bootstrap.ps1 derives WORKSTATION verification`. If it is present, record Already Applied. If it is absent, add assertions proving `Profiles` returns `WORKSTATION` for `bootstrap.ps1`, `workstation.cmd`, `.vscode/extensions.json` and `.mcp.json`, plus one negative assertion proving an unrelated document does not, using the next free assertion identifiers.

9. **The status mirror stops claiming to be current.** In `.workstation/reports/INSTALLATION_STATUS.md`, search for `HISTORICAL`. If it is present, record Already Applied. If it is absent, convert the header into a dated historical snapshot stating that it records the 2026-09-10 observation, is historical evidence rather than current status, and that current status comes only from running `.workstation/doctor.ps1`, leaving the observation table exactly as recorded. Then in `WORKSTATION.md`, route the current-status row to `.workstation/doctor.ps1` and name the snapshot as historical.

10. **The manifest names its authorities.** In `.workstation/manifest.md`, search for `is the authority`. If it is present, record Already Applied. If it is absent, record in section 2 that `.vscode/extensions.json` is the authority the scripts read and in section 3 that `.mcp.json` is the authority for project servers, each noting that the table restates it for rationale under Check 28. No extension identifier, server name, tool identity or winget package identifier in the file is added, removed or altered.

11. **Check 28's inputs trigger the guard that reads them.** This is the step `SPEC-186` could not reach. In `.github/workflows/repository-consistency.yml`, search for `.vscode/extensions.json`. If it is present in both the `on.push.paths` and the `on.pull_request.paths` lists, record Already Applied. If it is absent, add `.vscode/extensions.json` and `.mcp.json` to BOTH lists, with a comment recording that Check 28 reads them. Change nothing else in the file. Then in `scripts/check_repository_consistency.ps1`, replace the `DEBT, tracked by SPEC-187` comment block in Check 20's `$requiredTriggers` map with the two entries it describes, each naming Check 28 as the consumer, so the guard declares exactly the inputs it reads.

12. **Synchronize.** Set `Active Change Request` in `_ORVION_CANONICAL/manifest.md` to this contract while it is in progress, and on completion set `Last Completed` to this capability, repoint `Next capability`, restore the pointer to `None`, and regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] `.workstation/prepare.ps1` contains no literal VS Code extension identifier and obtains its required set from `.vscode/extensions.json`, failing closed when that set is empty.
- [ ] `.workstation/doctor.ps1` contains no literal VS Code extension identifier and obtains its required set from `.vscode/extensions.json`, failing closed when that set is empty.
- [ ] `.workstation/prepare.ps1` registers project MCP servers by iterating `$mcp.mcpServers` and contains no literal project MCP name or argument list; the `github` registration remains the only literal server, and the provisioner fails closed when `.mcp.json` declares none.
- [ ] `.workstation/doctor.ps1` derives the project MCP names it verifies from `.mcp.json` rather than from a hardcoded list, and its Claude and Codex enumeration loops both iterate that derived list.
- [ ] `.workstation/update.ps1` classifies a step by `$LASTEXITCODE`, recording `FAILED (exit <code>)` for any non-zero value other than `-1978335189` and `-1978335135`.
- [ ] `Profiles` in `scripts/check_agent_continuity.ps1` returns `WORKSTATION` for `bootstrap.ps1`, `workstation.cmd`, `.vscode/extensions.json` and `.mcp.json`.
- [ ] `scripts/check_repository_consistency.ps1` contains a Check 28 that fails when `.workstation/manifest.md` disagrees with `.vscode/extensions.json` or `.mcp.json`.
- [ ] `scripts/test_agent_continuity.ps1` contains the four positive `WORKSTATION` derivation assertions and the one negative assertion.
- [ ] `.workstation/reports/INSTALLATION_STATUS.md` identifies itself as a dated historical snapshot and not as current status, and its 2026-09-10 observation table is unaltered.
- [ ] `WORKSTATION.md` routes current workstation status to `.workstation/doctor.ps1`.
- [ ] `.workstation/manifest.md` names `.vscode/extensions.json` and `.mcp.json` as the authorities its tables restate, with no identifier in the file added, removed or altered.
- [ ] `.github/workflows/repository-consistency.yml` lists `.vscode/extensions.json` and `.mcp.json` in both its `on.push.paths` and its `on.pull_request.paths`, and no job, step, condition or permission in that file differs from its state before this contract.
- [ ] Check 20's `$requiredTriggers` map in `scripts/check_repository_consistency.ps1` declares `.vscode/extensions.json` and `.mcp.json` as Check 28's inputs, and the guard reports CLEAN on the unmodified repository.

## Execution Log

(no entries yet)

## Verification Notes

(no entries yet)

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

The rejected proposals are recorded here because the evidence that rejected them is worth more than the proposals, and because a successor contract must not quietly revive them. A host-tool inventory data file was rejected: the winget package identities in `prepare.ps1` and `update.ps1` are duplicated, but they have agreed at every commit since `05d2292`, so the duplication has never drifted. Docker detection was rejected: the hardcoded Docker Desktop path resolves on the live workstation and `docker` is on PATH, so there is no observed defect. A retry helper was rejected: no transient failure has been observed, and the real defect in the same script was the unchecked native exit code. Making `doctor.ps1` a mutator, adding a root `Doctor.cmd`, splitting `prepare.ps1`, and adding a new repair orchestrator were all rejected: the observe/converge separation is intact. The README, `AGENTS.md`, the boot command and all five client adapters were frozen after a cold-start exercise resolved mode, active CR, next capability, write authority and Git state from the repository alone, with every adapter a pointer carrying no independent rule.

The manifest records that the control-plane optimization chapter is closed and may be reopened only by newly earned evidence. This contract touches `scripts/check_agent_continuity.ps1` at one line under that clause and not as an optimization: Step 6 repairs a proven coverage gap, and Steps 5 and 9 repair two false greens. The winget classification in Step 5 uses the two codes documented in `microsoft/winget-cli` `doc/windows/package-manager/winget/returnCodes.md` as `APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE` and `APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED`.
