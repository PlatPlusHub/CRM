# Change Request — SPEC-277

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make the workstation scripts do what they say: a fresh Windows client completes the one-command recovery, `update.ps1` previews before it applies and reports what it cannot manage, the idempotence verifier never provisions the machine it measures, the maintenance menu's Exit exits, and verifying and updating get double-click entries like preparing has.

## Business Reason

The workstation is how a machine is rebuilt from GitHub (`WORKSTATION.md`). Four of its scripts claim behaviour they do not have; each was reproduced on 2026-10-13.

- **OPS-7 (Medium, new).** `bootstrap.ps1` is the documented one-command recovery. With no execution policy set in any scope, a Windows client's effective policy is Restricted (Microsoft Learn, about_Execution_Policies). `irm … | iex` runs the bootstrap text under it, but the bootstrap's `& .workstation\prepare.ps1` is refused with "running scripts is disabled on this system". So a fresh machine stops after the clone. Reproduced with `powershell.exe -ExecutionPolicy Restricted`. The owner workstation hides it: its CurrentUser policy is RemoteSigned. A fresh read-only agent predicted this from the files.
- **OPS-5 (Low, open since SPEC-275).** `.workstation/update.ps1`:
  - reads FAILED on every run for Git (scoop) and Python (Microsoft Store), which winget did not install;
  - reads ok for steps that change nothing (`npm update -g @openai/codex`, `npx supabase@latest --version`);
  - applies every upgrade, Docker Desktop's included, with no preview.
- **OPS-6 (Low, open since SPEC-275).** `scripts/verify_workstation_idempotence.ps1` says it "never converges the machine", but it runs `prepare.ps1`, which on an unconverged machine provisions it. During SPEC-275 it set `MCP_TIMEOUT`.
- **The blocker both carried.** `prepare.ps1` reads FAILED (configuration drift) because Codex's `context7` is the owner's OAuth server `https://mcp.context7.com/mcp/oauth`, not `.mcp.json`'s `npx -y @upstash/context7-mcp`. Context7 documents both transports as supported (context7.com/docs/resources/all-clients). The owner's working OAuth sign-in is not ours to replace.
- **Menu Exit.** In `.workstation/menu.ps1`, choosing `0` or `X` redraws the menu, because `break` inside a `switch` leaves only the switch. Reproduced under pwsh and Windows PowerShell 5.1.
- **Double-click entries (owner request, 2026-10-13).** Preparing has one (`workstation.cmd`). Verifying and updating need a typed command, or the menu started with `pwsh -File`. `.workstation/doctor.cmd` and `.workstation/update.cmd` add them as dispatch-only launchers. They live in `.workstation/` rather than at the root because there the WORKSTATION profile derives for them with no control-plane change; a root `workstation-*.cmd` would match none of its patterns (`scripts/check_agent_continuity.ps1` `Profiles`).

## Risks

- **Bootstrap hand-off.** It now runs `workstation.cmd`, which already starts `prepare.ps1` with a process-scoped `-ExecutionPolicy Bypass`, the same flag the one-click entry has always used. No persistent policy changes. On failure `workstation.cmd` pauses for the reader, as it already does from a double-click.
- **Update behaviour.** An interactive run now asks before applying, and a scripted run applies nothing unless `-Apply` is given. A user who relied on the old unattended upgrades must add `-Apply`. Apply installs exactly the previewed id, version and source (`winget --version --source`, `npm <pkg>@<version>`), never `latest`. A release published between preview and apply is therefore not applied unseen, and an id that is no longer offered fails visibly.
- **Launchers.** Each is six lines modelled on `workstation.cmd`. It runs the script beside it under Windows PowerShell 5.1 with a process-scoped `-ExecutionPolicy Bypass`, which a Group Policy still overrides; passes no arguments, so `update.cmd` can never pass `-Apply`; pauses; and returns the script's exit code.
- **The doctor gains one required check (`MCP_TIMEOUT` set).** A workstation without it now fails the doctor until `workstation.cmd` sets it. That is `prepare.ps1`'s documented desired state, and the owner workstation has it.
- **Context7 equivalence.** `prepare.ps1` accepts exactly one alternative definition for one server: Codex's `context7` at `https://mcp.context7.com/mcp/oauth`. Any other mismatch is still reported, never overwritten. A fresh machine still gets the `.mcp.json` definition.
- **Untouched.** No OAuth, credential, MCP configuration, Docker, WSL, database, Primary, CI workflow or product behaviour changes. No tool is installed or upgraded to certify this contract.

## Supersedes / Depends On

None

## Write Scope

- `bootstrap.ps1`
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.workstation/update.ps1`
- `.workstation/menu.ps1`
- `.workstation/manifest.md`
- `.workstation/doctor.cmd`
- `.workstation/update.cmd`
- `WORKSTATION.md`
- `scripts/verify_workstation_idempotence.ps1`
- `scripts/test_workstation.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-275-the-engineering-method-and-its-tools-do-what-they-say.md`
- `changes/SPEC-276-a-newcomer-reaches-the-right-authority.md`
- `README.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `workstation.cmd`
- `.workstation/cleanup.ps1`
- `.workstation/decommission.ps1`
- `.workstation/claude-awareness.ps1`
- `.mcp.json`
- `.vscode/extensions.json`
- `package.json`
- `package-lock.json`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`

## Required Reading

- `WORKSTATION.md`
- `.workstation/manifest.md`
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.workstation/update.ps1`
- `.workstation/menu.ps1`
- `bootstrap.ps1`
- `workstation.cmd`
- `scripts/verify_workstation_idempotence.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -NoProfile -File scripts/test_workstation.ps1`
- `powershell.exe -NoProfile -File scripts/test_workstation.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `bootstrap.ps1` hands off through `workstation.cmd` | A fresh Windows client running the `WORKSTATION.md` one-liner; `workstation.cmd` | WRITE | Under `-ExecutionPolicy Restricted` the old hand-off was refused, and the new one ran a stub `prepare.ps1` and returned its exit code (0 and 3). The clone, the username-qualified URL and the target are unchanged. `workstation.cmd` is unchanged. |
| `update.ps1` previews by default, applies only the previewed rows at their previewed version and source on confirmation or `-Apply`, reports tools other installers manage, never touches the pinned Supabase CLI, and announces that a Docker Desktop upgrade stops every container | The maintenance menu's option 3; owner and agents running it; `.workstation/manifest.md` §6 | WRITE | Read-only on the owner workstation, it reported Git, Python and Codex as provided by other installers, planned nothing, changed nothing and exited 0. U1–U7 judge the plan on fixtures, U1 and U4 including the exact version and source. The menu label and the manifest row say "preview, confirm, verify". |
| `.workstation/doctor.cmd` and `.workstation/update.cmd` dispatch to the script beside them | Humans double-clicking; `WORKSTATION.md`, which gains one bullet; manifest §6, which gains two rows | WRITE | L1–L3: from another directory, each ran only its own stub script, with no arguments, and returned its exit code (3, 0, 1). The real doctor and updater were never run by the test. `workstation.cmd` is unchanged. |
| The idempotence verifier runs the read-only doctor first, and refuses before `prepare.ps1` when it fails | `-Finish`'s WORKSTATION profile; assertions 92, 173 and 174 of `scripts/test_agent_continuity.ps1`, which stub the verifier | WRITE | The profile's command and its exit semantics are unchanged; only an unconverged machine now exits 1 before provisioning. The control assertions replace the verifier with a stub, so their verdicts do not depend on its body. V1–V3. |
| The doctor fails while the user variable `MCP_TIMEOUT` is unset | The doctor's callers: `prepare.ps1`'s final verification, `update.ps1`, the menu, the WORKSTATION profile; manifest §3 | WRITE | `prepare.ps1` sets the variable when absent, so prepare-then-doctor still converges and passes. The owner workstation has `MCP_TIMEOUT=90000`. A different user value still passes, as `prepare.ps1` keeps it. |
| `prepare.ps1` accepts Codex's `context7` at `https://mcp.context7.com/mcp/oauth` as the same server as `.mcp.json`'s | The owner's Codex configuration; the WORKSTATION profile; manifest §3 and Check 28 | WRITE | It is read, never written. Every other drift is still `FAILED (configuration drift)`. Check 28 compares server names, which are unchanged; prototype `REPOSITORY CONSISTENCY: CLEAN`. |
| The menu's Exit returns from the script | Humans using `.workstation/menu.ps1` | WRITE | Reproduced in an isolated copy of the loop: under pwsh and 5.1, `break` redrew the menu and `return` ended it with exit 0. The other options are unchanged; Decommission was never run. |
| Register and Action registry | `reports/master/MASTER_GAP_REGISTER.md`; `reports/master/MASTER_EXECUTION_PLAN.md`; consistency Check 29 | WRITE | OPS-5 and OPS-6 are recorded fixed and leave the registry's `OWN-TRIGGER` row; OPS-7 is recorded new and fixed. Prototype: `REPOSITORY CONSISTENCY: CLEAN`, Check 29 `ACCEPTED RESIDUAL 26`. |
| Manifest active pointer | Boot, Check 7, `scripts/generate-ai-map.ps1` | WRITE | `ai-map.json` and `repository-index.md` are in Write Scope. The new test script does not change them (prototype regeneration). |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Working tree is clean and the branch is not behind its upstream | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| The thirteen implementation files equal their pinned target hashes and no other tracked path changed | BEFORE_COMPLETION | 1 | 2 | 3 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The WORKSTATION profile's two commands (the doctor and the idempotence verifier) are reused unchanged. The verifier's existing comparison is kept, and only gains a precondition. No profile, gate or Boot change is made. The new fixture test was the prototype's `test_workstation_update.ps1`, renamed because it now also judges the verifier and the launchers. The launchers copy `workstation.cmd`'s existing pattern.

Added Property:
- Measuring idempotence never provisions.
- An update's plan is decided by which installer manages each tool, and apply installs exactly what was previewed.
- A double-click launcher returns its script's result.

Causal Negative: Reproduced 2026-10-13 in disposable clones:
- **V1 against the unchanged verifier fails.** It started `prepare.ps1` after a failing doctor, and the stub's marker file appeared.
- **U1–U7 have no plan to judge on the unchanged `update.ps1`.** Its measured behaviour on the owner workstation is the OPS-5 record.

Positive Test Design:
- V2: a passing doctor and a prepare run that changes nothing pass.
- U3 and U4: an up-to-date managed tool is left alone, and an outdated npm package is planned with its versions.
- L2: `update.cmd` runs `update.ps1` with no arguments and returns 0.
- On the owner workstation, the WORKSTATION profile passes (Notes).

Negative Test Design:
- V1: a failing doctor exits 1, `NOT MEASURED`, and `prepare.ps1` never ran.
- V3: a prepare run that still reconfigures after a passing doctor fails `NOT IDEMPOTENT`.
- U2 and U5: a tool another installer provides is reported, even when winget or npm names it.
- U7: an id is matched whole.
- L1 and L3: a failing script's exit code (3, 1) is returned, and `doctor.cmd` never runs `prepare.ps1`.

Non-Empty Population Obligation: Not applicable; each case is a single fixture.

Mutation Obligation: V1 was run against the unchanged verifier, the load-bearing predicate this contract adds. Removing `exit /b %ORVION_EXIT%` from `doctor.cmd` was killed by L1.

Post-Implementation Proof Obligation: The certified `-Finish` runs WORKSTATION (the doctor and the idempotence verifier on the owner workstation), REPOSITORY, and both Additional Verification runs. After `Complete`:
- `publish_candidate.ps1` must admit `origin/main..HEAD`;
- ORVION Acceptance must pass on the candidate;
- `-Certify` must report READY on `main`.

## Implementation Steps

1. For each file below, read its blob with `git hash-object --path=<path> <path>` (absent if the file does not exist). If it equals the `to` hash, record Already Applied. If it equals the `from` hash, replace the file with the reviewed content summarised in Notes, so that its blob becomes exactly the `to` hash. Any other value means stop and report; do not guess.
   - `bootstrap.ps1`: from `e38ed9b11aa1e6bff35296ae2c06824c86d92fec` to `0a33f6d3544d1e72cdb62747cc1fca4d54811475`
   - `.workstation/prepare.ps1`: from `79692dd35bcd50e39022f8d148e7d86b68bd45aa` to `667c14dc482e3d5c34d907e09bfca20c290fd5ed`
   - `.workstation/doctor.ps1`: from `0057d7ab7de5ac7b476953cdd41bc9e97c993426` to `0ad69c87859646283c84e31df5732b2df1d42056`
   - `.workstation/update.ps1`: from `7db330a7aba435a193e42edba739d6494eda3da2` to `688deb86b38183faeaddfc8405077492ba583b99`
   - `.workstation/menu.ps1`: from `7cdd24ad12a0e26af70521f1cff07b43edbc02f3` to `1a684fee9ec439da5ddaf6a1c608fcb72da08b25`
   - `.workstation/manifest.md`: from `2795568499bc51276563f492e9d0fa41111bd637` to `02918cb45c79a5bc26f2041ee1390b25f4f95d35`
   - `.workstation/doctor.cmd`: from absent to `a4b75b38082a282e0f11b983c8860387fb848dc7`
   - `.workstation/update.cmd`: from absent to `b7b747dab0eac4a329269ec0c3d60303e09b0024`
   - `WORKSTATION.md`: from `98c489bc300984bc52c6893ac66c3c42bab98d2c` to `8dc0b895d2d73289eb3338249e6629d572e832c9`
   - `scripts/verify_workstation_idempotence.ps1`: from `2aaf1439e1d8181a890a023756f99084bfe9c51d` to `24db02f804f55a10ad9835b809845dd4a3c52158`
   - `scripts/test_workstation.ps1`: from absent to `a30ed66e85996910f6a00e794ce58ec4f5b0bcd7`
   - `reports/master/MASTER_GAP_REGISTER.md`: from `3b2bf7bc4492d0ee9ce165843ea46e6d946b262b` to `7249a519e70c86871b483dc7eae4bb74068d2d64`
   - `reports/master/MASTER_EXECUTION_PLAN.md`: from `55eb1c6c3432789fdbcda739755e13a89237059c` to `1fcdefb98908576d5ce98b6f0dbe89edf502b940`
2. Check whether `git diff --name-only` against the approval commit lists only the thirteen files above plus this contract. If so, record Already Applied. Otherwise stop and report any other path. Nothing else is edited in this step; the lifecycle commits own the manifest, `ai-map.json` and `repository-index.md`.
3. Check whether the Runtime Checkpoint already reads `Resume Step: DONE`. If so, record Already Applied. Otherwise synchronize the Execution Log and the Runtime Checkpoint to `DONE`, and commit the implementation and checkpoint together. Then run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` normally. It changes no tool, OAuth, MCP, Docker or WSL state: on this converged workstation the doctor passes and the prepare run changes nothing. If a test fails, preserve its exit code and evidence, and follow bounded recovery without weakening any assertion.

## Acceptance Criteria

- [x] Each of the thirteen Step 1 files has exactly its `to` blob.
- [x] `bootstrap.ps1` hands off through `workstation.cmd` and no longer runs `.workstation\prepare.ps1` directly.
- [x] `.workstation/update.ps1` defines `Get-UpdatePlan`, applies only on confirmation or `-Apply` and only at each row's previewed version and source, and contains no `npx`, `supabase@latest` or `@latest` invocation.
- [x] `scripts/verify_workstation_idempotence.ps1` runs the doctor before `prepare.ps1` and prints `NOT MEASURED` when it fails.
- [x] `.workstation/doctor.ps1` fails when `MCP_TIMEOUT` is unset for the user.
- [x] `.workstation/prepare.ps1` accepts `https://mcp.context7.com/mcp/oauth` for `context7` only, and still reports any other drift as `FAILED (configuration drift)`.
- [x] `.workstation/menu.ps1`'s Exit choice uses `return`.
- [x] `.workstation/doctor.cmd` and `.workstation/update.cmd` each only run the script beside them with no arguments, pause, and return its exit code, and `WORKSTATION.md` names both.
- [x] The register reads OPS-5, OPS-6 and OPS-7 fixed, and the Action registry no longer lists OPS-5 or OPS-6.
- [x] The tracked implementation diff touches only this contract's Write Scope.

## Execution Log

### 2026-10-13 — Claude

Outcome: Implemented. The Runtime Checkpoint is DONE; `-Finish` follows.

Step results:
- **Step 1: Applied.** Each file read its `from` hash (`absent` for the three new files) and was replaced with the reviewed pre-approval prototype. The prototype's blob had been checked equal to the `to` hash before copying. `git hash-object --path` then read exactly the `to` hash for all thirteen files.
- **Step 2: Applied.** The tracked and untracked changes listed exactly those thirteen files plus this contract.
- **Step 3: Applied.** The Runtime Checkpoint is synchronized to `DONE` and committed with the implementation. `-Finish` runs next, normally. The local Supabase stack stays stopped: the WORKSTATION profile needs only the Docker engine, which is running.

**Approval prerequisites, re-verified before the first commit.**
- HEAD, `origin/main` and `origin/orvion-preflight` were all `386bf87`, on branch `main`, with a clean tree.
- The Draft's blob was `500220f756ccd0a5b8260ddf1c7d6220d5f7739f` and its SHA-256 `b9c2c091ee7696d141d4de566941176e3c9053c6c6a51a460f9baf1e7a3c2df9`.
- 13 of 13 pins held: each file was at its `from` hash in the repository, at its `to` hash in the prototype, and pinned that way in the Draft.

**Pre-approval rehearsal.** A disposable clone at `386bf87`, with push disabled, rehearsed the lifecycle of the same Draft blob:
- Draft, then Approve with `APPROVAL_EVIDENCE: PASS`, then Begin and Implement.
- `-Finish`: `LOCAL_CERTIFY: READY` in 1.5 min. Repository consistency, `git diff --check`, the doctor, the idempotence verifier and `scripts/test_workstation.ps1` under pwsh and Windows PowerShell 5.1 all passed.
- Complete.
- The range Gate over `origin/main..HEAD`: READY, with a net diff of exactly the thirteen files.
- `MCP_TIMEOUT` and the hash of `~/.codex/config.toml` were identical before and after.

## Verification Notes

### 2026-10-13 — Claude (independent review)

Verdict: Confirmed Complete

Findings: re-checked against the live repository at HEAD.
- **R1.** All thirteen Step 1 files have exactly their `to` blobs.
- **R2.** `bootstrap.ps1` hands off through `workstation.cmd` and no longer calls `prepare.ps1` directly.
- **R3.** `update.ps1` defines `Get-UpdatePlan`, applies only on confirmation or `-Apply`, passes `--version`/`--source` (winget) and `@<version>` (npm) from the previewed row, and contains no `npx` or `@latest`.
- **R4.** The verifier runs the doctor before `prepare.ps1` and prints `NOT MEASURED` when the doctor fails.
- **R5.** The doctor fails while `MCP_TIMEOUT` is unset.
- **R6.** `prepare.ps1` accepts the one OAuth URL for `context7` only, and still reports other drift as `FAILED (configuration drift)`.
- **R7.** The menu's Exit uses `return`.
- **R8.** Each launcher dispatches only to the script beside it, passes no arguments, pauses and returns `%ORVION_EXIT%`.
- **R9.** `WORKSTATION.md` names both launchers.
- **R10.** OPS-5, OPS-6 and OPS-7 read FIXED, and no Action-registry row lists OPS-5 or OPS-6.
- **R11.** `changes/SPEC-276-…` is unchanged since `386bf87`.
- **R12.** The net diff from `386bf87` is the thirteen files, this contract, and the lifecycle-owned manifest and `ai-map.json`.
- **Certification.** `-Finish` at `e967360`: `LOCAL_CERTIFY: READY` in 1.6 min. Repository consistency, `git diff --check`, the doctor, the idempotence verifier (doctor first, then a `prepare.ps1` run that installed and reconfigured nothing) and `scripts/test_workstation.ps1` under pwsh and Windows PowerShell 5.1 all passed. `MCP_TIMEOUT`, the hash of `~/.codex/config.toml`, the hash of `.claude/settings.json` and `core.hooksPath` were identical before and after.
- **Discrepancy, no effect.** The Risks section calls each launcher "six lines"; each has seven (`@echo off`, `setlocal`, a `REM` line, the dispatch, `set`, `pause`, `exit /b`). Their behaviour is exactly as specified. The frozen text is left as approved and corrected here.
- **Execution note.** The first Implement run copied six files, then the agent's own progress print failed on a new file's `absent` label. That bug was in the agent's helper, not in a contract file. The re-run recorded those six as Already Applied by their `to` hash and applied the remaining seven. The resulting blobs are exactly the pinned ones.

Recommendation to human: Set Status to Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

**Reviewed content (Step 1).**
- `bootstrap.ps1`: the hand-off line becomes `& (Join-Path $Target "workstation.cmd")`, with a comment giving the Restricted-policy reason.
- `.workstation/update.ps1`: the SPEC-275 prototype, with three changes:
  - the Docker Desktop warning is unconditional (the prototype first probed `docker ps`);
  - each upgrade row carries the previewed version and winget source, and apply passes exactly those;
  - the prototype's dot-source guard is removed, because no test loads the script any more.
- `.workstation/doctor.cmd`, `.workstation/update.cmd`: `workstation.cmd`'s pattern, with an unconditional `pause` so a double-clicked window stays readable.
- `WORKSTATION.md`: one bullet, before the menu bullet, naming both launchers.
- `scripts/verify_workstation_idempotence.ps1`: the doctor runs first, and its failure stops the verifier with `NOT MEASURED`; the FAIL-CLOSED header says so.
- `.workstation/doctor.ps1`: one `MCP_TIMEOUT` check beside the MCP checks.
- `.workstation/prepare.ps1`: `Ensure-CodexMcp` takes `$AlsoUrl`, and the `.mcp.json` loop passes it from a one-entry table for `context7`, with a comment citing Context7's client documentation.
- `.workstation/menu.ps1`: Exit uses `return`; the redirected-input message names `pwsh -File .workstation/menu.ps1` (`workstation.cmd` runs `prepare.ps1`, not the menu); the Update label reads "preview upgrades, confirm, verify".
- `.workstation/manifest.md`: the `context7` row names the accepted OAuth definition; §3 says the doctor fails while `MCP_TIMEOUT` is absent; §5 says the bootstrap hands off through `workstation.cmd`; §6's `update.ps1` row describes the preview, and §6 gains a row for each launcher.
- `scripts/test_workstation.ps1`: U1–U7, V1–V3 and L1–L3. `update.ps1` runs winget and npm at its top level, so the test never executes or dot-sources it. It parses the file and evaluates only `$WingetTools`, `$NpmTools` and `Get-UpdatePlan`, and refuses (exit 1, "found N of 3") when they are not all there. Against the unchanged `update.ps1` it refused with "found 0 of 3", and no winget or npm log appeared.

**Context7, the owner's alternatives.**
- (a) **Accept both transports as one server (adopted).** It keeps the working OAuth sign-in and changes nothing for a fresh install.
- (b) Switch Codex to `npx`. This would replace the owner's OAuth sign-in, which only the owner can authorise.
- (c) Switch `.mcp.json` to the remote server. This would change every client's Context7 for no measured gain.

**Pre-approval measurement (2026-10-13, owner workstation).** Docker Desktop was restarted with the owner's authorisation; its error had latched while Windows Update installed WSL 3.0.3. To free memory, the ORVION local stack was then stopped with the owner's authorisation, using the project-local CLI 2.120.0 (`supabase stop`, backup kept, all three volumes preserved). Both WORKSTATION commands were then run from a disposable clone with its push URL disabled, its fetch URL set to the canonical username-qualified origin, `npm ci` run, and the machine-local `.claude/settings.json` copied in:
- the doctor: `WORKSTATION VERIFICATION: PASSED`, 0 failures, 0 warnings;
- the verifier: `doctor passed: converged`, then no installation, no reconfiguration and no failure, `WORKSTATION IDEMPOTENCE: PASSED`, 29 s. `prepare.ps1` accepted Codex's OAuth `context7`.

`MCP_TIMEOUT` and the hash of `~/.codex/config.toml` were identical before and after. Both runs of `scripts/test_workstation.ps1` on the final files, rebased on SPEC-276's completion `386bf87`: 13 passed, 0 failed. Repository consistency is CLEAN, and the generated `ai-map.json` and `repository-index.md` do not change. Every file is unchanged by SPEC-276 except `WORKSTATION.md`, whose `from` is SPEC-276's `to`.

**Incident during preparation (disclosed).** The first causal negative ran the new test against the unchanged `update.ps1`. Because the test dot-sources the script, and that version has no dot-source guard, the whole update ran on the owner workstation:
- seven `winget upgrade` calls, every one "no applicable update" or "no installed package";
- `npm update -g` re-placed Claude Code 2.1.296, which is the latest, and was a no-op for Codex;
- `npx supabase@latest --version` touched only the npx cache.

No tool's version changed. The causal negative was then re-run with only the verifier reverted, and the test was changed so that it can no longer execute `update.ps1` at all (above).
