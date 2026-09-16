# Change Request — SPEC-186

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make every workstation desired-state fact have exactly one owning file that `prepare.ps1` and `doctor.ps1` read rather than restate, and make the control plane derive the `WORKSTATION` profile for the workstation entry points and desired-state files it did not cover.

## Business Reason

The workstation's required VS Code extension identities exist in four places: `.vscode/extensions.json`, `.workstation/prepare.ps1`, `.workstation/doctor.ps1` and `.workstation/manifest.md`. This is not a theoretical drift risk — it has already happened. Commit `2ded739` removed `openai.chatgpt` from the provisioner's install list and updated the manifest, while `.vscode/extensions.json` kept both it and `github.copilot`. The repair, `8d67f77`, was a hand-synchronization commit that resolved the disagreement by adding a *third* copy of the list to `doctor.ps1`. No guard covers any of this: zero of the repository consistency guard's 27 checks read any workstation file.

The same shape exists for project MCP servers. Both scripts already parse `.mcp.json` and then ignore it in favour of hardcoded name and argument lists, so a fifth project MCP would be neither registered into Codex by `prepare.ps1` nor verified by `doctor.ps1` — silently, with both reporting success. The `github` server entered the workstation by exactly that route.

Two truthfulness defects sit alongside these. `.workstation/update.ps1` wraps native `winget` and `npm` calls in `try`/`catch`, which does not observe a native non-zero exit, so every upgrade step reports `ok` whatever happened. And `.workstation/reports/INSTALLATION_STATUS.md` is consumed by `WORKSTATION.md` as "Current install status" while asserting a `READY` state that live verification contradicts on four axes today.

Finally, `Profiles` derives `WORKSTATION` only for `^\.workstation/`, so a change to `bootstrap.ps1` — the single entry point for a fresh machine, whose own comments record a defect that recurred twice — earns no workstation verification at all.

## Risks

Moderate and bounded. The provisioner and the doctor change how they obtain their required sets; a malformed or empty authority file must fail closed rather than silently verify nothing, which is the principal risk and is addressed by explicit emptiness checks in both scripts. Widening `Profiles` makes more Change Requests run `doctor.ps1` during certification; that is the intended effect and costs a read-only run. The `winget` exit-code classification risks converting a normal no-op into a false red, which is why exactly two documented success-equivalent codes are treated as up-to-date and everything else is reported with its code. No credential, OAuth boundary, or user configuration is read, written, or overwritten by this contract.

## Supersedes / Depends On

None. This contract does not modify any mechanism introduced by `SPEC-183`, `SPEC-184` or `SPEC-185`.

## Write Scope

- `changes/SPEC-186-workstation-desired-state-has-one-owner.md`
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

- `.vscode/extensions.json`
- `.mcp.json`
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

`.vscode/extensions.json` and `.mcp.json` are the authorities this contract makes the scripts consume. Their content is deliberately not edited here, so that the proof that the scripts now read them cannot be confused with a proof that they were edited to match.

Also out of scope as SUBJECTS, not merely as files: any new workstation data file, inventory or manifest format, including `.workstation/inventory.psd1`; any host-tool, winget or npm-package inventory refactor; any retry, backoff or recovery state machine; any change to `-Finish`, `-Gate`, `-Certify` or Publisher; any change to Docker detection, Docker installation-path resolution, or Docker readiness behaviour; any change to WSL detection, installation or elevation behaviour; any change to `doctor.ps1` from an observer into a mutator; any new root `.cmd` entry point; any change to the boot chain, README routing or client adapter files; GitHub Rulesets; and any new test harness, mutation framework or generic configuration/dependency engine.

## Required Reading

- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.workstation/update.ps1`
- `.workstation/manifest.md`
- `.vscode/extensions.json`
- `.mcp.json`
- `scripts/check_agent_continuity.ps1` (the `Profiles` function)

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- `pwsh -NoProfile -File .workstation/doctor.ps1`

## Implementation Steps

1. **Provisioner reads the extension authority.** In `.workstation/prepare.ps1`, search for the exact string `$requiredExtensions = @("anthropic.claude-code"`. If it is absent, stop and report. If present, replace that single assignment line with an assignment that reads `recommendations` from `.vscode/extensions.json` relative to `$Root`, and immediately below it add a fail-closed check: when the resulting array has zero entries, emit `[FAIL] .vscode/extensions.json declares no required extensions`, record a `FAILED` note for `VS Code extensions`, and skip the install loop. The install loop body itself is not otherwise changed.

2. **Doctor reads the same extension authority.** In `.workstation/doctor.ps1`, search for the exact string `$requiredExtensions = @("anthropic.claude-code"`. If it is absent, stop and report. If present, replace that single assignment with the same read of `recommendations` from `.vscode/extensions.json`, and add a fail-closed check that calls `Fail` with `.vscode/extensions.json declares no required extensions` when the array is empty. The per-extension verification loop is not otherwise changed.

3. **Provisioner registers project MCPs from `.mcp.json`.** In `.workstation/prepare.ps1`, search for the exact string `Ensure-CodexMcp "context7" $null @("npx", "-y", "@upstash/context7-mcp") $null`. If it is absent, stop and report. If present, replace the four consecutive `Ensure-CodexMcp` calls for `context7`, `postgres-local`, `supabase-primary` and `n8n` with a single loop over the property names of `$mcp.mcpServers` that, for each server, calls `Ensure-CodexMcp` with the server's `url` when the definition carries one, and otherwise with its `command` followed by its `args`. The `github` call on the following line is workstation-specific rather than a project MCP and remains exactly as written. Immediately before the loop, add a fail-closed check that emits `[FAIL] .mcp.json declares no project MCP servers` and records a `FAILED` note when `$mcp.mcpServers` has no properties.

4. **Doctor verifies the MCP servers `.mcp.json` declares.** In `.workstation/doctor.ps1`, search for the exact string `foreach ($name in @("context7","postgres-local","supabase-primary","n8n")) { if ($mcp.mcpServers.PSObject.Properties.Name -contains $name)`. If it is absent, stop and report. If present, replace the hardcoded inventory assertion with a derivation: parse `.mcp.json`, set the project server list from `$mcp.mcpServers.PSObject.Properties.Name`, `Fail` with `.mcp.json declares no project MCP servers` when that list is empty, and otherwise `Pass` with the count of declared servers. Then change the Claude enumeration loop and the Codex enumeration loop to iterate that derived list instead of their hardcoded lists; the Codex loop additionally checks `github` exactly as it does now. The `Not logged in` warning and the `GITHUB_PAT_TOKEN` check are not changed.

5. **Update reports native failures.** In `.workstation/update.ps1`, search for the exact string `catch { Write-Host "[WARN] $($_.Exception.Message)"; $Results.Add([pscustomobject]@{ Item = $Title; State = "FAILED" }) }`. If it is absent, stop and report. If present, change `Step` so that after invoking the scriptblock it inspects `$LASTEXITCODE`: a value of `0` records `ok`; the two documented winget success-equivalents `-1978335189` (`0x8A15002B`, no applicable update) and `-1978335135` (`0x8A150061`, already installed) record `up to date`; any other non-zero value records `FAILED (exit <code>)`. A thrown exception continues to record `FAILED`. Before each scriptblock invocation, reset `$global:LASTEXITCODE` to `0` so a step that runs no native command cannot inherit a previous step's code.

6. **`WORKSTATION` covers the entry points and the authorities.** In `scripts/check_agent_continuity.ps1`, search for the exact string `if($p-match'^\.workstation/'){[void]$h.Add('WORKSTATION')}`. If it is absent, stop and report. If present, replace that single line with one whose pattern also matches `bootstrap.ps1`, `workstation.cmd`, `.vscode/extensions.json` and `.mcp.json` anchored as whole paths, and add a comment above it recording that the two root entry points execute workstation setup and the two JSON files became load-bearing workstation desired state when `prepare.ps1` and `doctor.ps1` began consuming them. No other line of `Profiles` is changed.

7. **One guard covers the remaining prose copies.** In `scripts/check_repository_consistency.ps1`, search for the exact string `Check 27: relocated owner-ratified rules`. If it is absent, stop and report. If present, add a new Check 28 that reads `.vscode/extensions.json` and `.mcp.json` and compares each against the corresponding table in `.workstation/manifest.md`: the set of extension identifiers in the manifest's "Required VS Code extensions" table must equal the `recommendations` array, and the set of server names in the manifest's "MCP inventory and authentication" table, excluding `github`, must equal the `mcpServers` property names. The check reports every element present in one authority and absent from the other, and fails the guard when any difference exists. Register the new check in the guard's header summary list and in its workflow-input map in the same form the existing checks use.

8. **The coverage repair is asserted.** In `scripts/test_agent_continuity.ps1`, add assertions proving that `Profiles` returns a set containing `WORKSTATION` for each of the four newly covered paths `bootstrap.ps1`, `workstation.cmd`, `.vscode/extensions.json` and `.mcp.json`, and one negative assertion proving that an unrelated path such as `PROJECT_CONTEXT.md` does not derive `WORKSTATION`. Use the next free assertion identifiers, derived by taking the file's maximum existing identifier and adding one for each new assertion.

9. **The status mirror stops claiming to be current.** In `.workstation/reports/INSTALLATION_STATUS.md`, search for the exact string `Last verified: 2026-09-10`. If it is absent, stop and report. If present, convert the file's header into a dated historical snapshot: state that it records the verification observed on 2026-09-10, that it is historical evidence rather than current status, and that current workstation status is obtained only by running `.workstation/doctor.ps1`. The table of observations from that date is left exactly as recorded. Then in `WORKSTATION.md`, search for the exact string `| Current install status | `.workstation/reports/INSTALLATION_STATUS.md` |` and replace that row so that current status points to `.workstation/doctor.ps1` and the historical snapshot is named as such.

10. **The manifest names its authorities.** In `.workstation/manifest.md`, search for the exact string `## 2. Required VS Code extensions`. If it is absent, stop and report. If present, record in section 2 that `.vscode/extensions.json` is the authority the scripts read and that the table restates it for rationale under Check 28, and record in section 3 that `.mcp.json` is the authority for project servers under the same check. No extension identifier, server name, tool identity or winget package identifier in this file is added, removed or altered by this step.

11. **Synchronize.** Set `Active Change Request` in `_ORVION_CANONICAL/manifest.md` to this contract while it is in progress, and on completion set `Last Completed` to this capability and restore the pointer, then regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] `.workstation/prepare.ps1` contains no literal VS Code extension identifier and obtains its required set from `.vscode/extensions.json`, failing closed when that set is empty.
- [ ] `.workstation/doctor.ps1` contains no literal VS Code extension identifier and obtains its required set from `.vscode/extensions.json`, failing closed when that set is empty.
- [ ] `.workstation/prepare.ps1` registers project MCP servers by iterating `$mcp.mcpServers` and contains no literal project MCP name or argument list; the `github` registration remains the only literal server, and the provisioner fails closed when `.mcp.json` declares none.
- [ ] `.workstation/doctor.ps1` derives the project MCP names it verifies from `.mcp.json` rather than from a hardcoded list, and its Claude and Codex enumeration loops both iterate that derived list.
- [ ] `.workstation/update.ps1` classifies a step by `$LASTEXITCODE`, recording `FAILED (exit <code>)` for any non-zero value other than `-1978335189` and `-1978335135`.
- [ ] `Profiles` in `scripts/check_agent_continuity.ps1` returns `WORKSTATION` for `bootstrap.ps1`, `workstation.cmd`, `.vscode/extensions.json` and `.mcp.json`.
- [ ] `scripts/check_repository_consistency.ps1` contains a Check 28 that fails when `.workstation/manifest.md` disagrees with `.vscode/extensions.json` or `.mcp.json`, and the guard reports CLEAN on the unmodified repository.
- [ ] `scripts/test_agent_continuity.ps1` contains the four positive `WORKSTATION` derivation assertions and the one negative assertion, and the suite passes.
- [ ] `.workstation/reports/INSTALLATION_STATUS.md` identifies itself as a dated historical snapshot and not as current status, and its 2026-09-10 observation table is unaltered.
- [ ] `WORKSTATION.md` routes current workstation status to `.workstation/doctor.ps1`.
- [ ] `.workstation/manifest.md` names `.vscode/extensions.json` and `.mcp.json` as the authorities its tables restate, with no identifier in the file added, removed or altered.

## Execution Log

### <YYYY-MM-DD HH:MM> — <agent identifier>

Outcome: Complete | Blocked | Failed

Step results:
- Step 1: Already Applied | Applied | Failed — <one-line reason>

Commits: <commit hash(es) for this run>

## Verification Notes

### <YYYY-MM-DD HH:MM> — <agent identifier>

Verdict: Confirmed Complete | Discrepancy Found | Needs Corrective Change Request

Findings: <what was independently re-checked, and what was found>

Recommendation to human: Set Status to Complete | Set Status to Cancelled | Approve corrective
Change Request `changes/SPEC-00N-*.md`

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

The rejected proposals are recorded here because the evidence that rejected them is worth more than the proposals. A host-tool inventory data file was rejected: the winget package identities in `prepare.ps1` and `update.ps1` are duplicated, but they have agreed at every commit since `05d2292`, so the duplication has never drifted and a new data file would be an abstraction bought on a theoretical risk. Docker detection was rejected: the hardcoded Docker Desktop path resolves on the live workstation and `docker` is on PATH, so there is no observed defect to attack. A retry helper was rejected: no transient failure has been observed, and the real defect in the same script was the unchecked native exit code, which Step 5 repairs directly. Making `doctor.ps1` a mutator, adding a root `Doctor.cmd`, and splitting `prepare.ps1` were all rejected: the observe/converge separation is intact and nothing in live evidence argues against it. The README, `AGENTS.md`, the boot command and all five client adapters were frozen after a cold-start exercise resolved mode, active CR, next capability, write authority and Git state from the repository alone, with every adapter a pointer carrying no independent rule.

The manifest records that the control-plane optimization chapter is closed and may be reopened only by newly earned evidence. This contract touches `scripts/check_agent_continuity.ps1` at one line under that clause and not as an optimization: Step 6 repairs a proven coverage gap, and Steps 5 and 9 repair two false greens. The winget classification in Step 5 uses the two codes documented in `microsoft/winget-cli` `doc/windows/package-manager/winget/returnCodes.md` as `APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE` and `APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED`.
