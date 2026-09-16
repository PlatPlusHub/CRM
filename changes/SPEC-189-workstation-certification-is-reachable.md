# Change Request — SPEC-189

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Give the `WORKSTATION` verification profile a reachable, fail-closed path to local certification by executing its bootstrap-idempotence evidence instead of declaring it unexecutable, and carry the already-implemented workstation single-authority work to completion through that repaired path.

## Business Reason

No Change Request deriving the `WORKSTATION` profile can be completed, by any actor. `Get-ProfileEvidence` gives that profile an unconditional `LOCAL_NOT_EXECUTED: bootstrap idempotence` note; any such note forces `LOCAL_CERTIFY: INCOMPLETE`; `Write-Certification` runs only on the `READY` branch, so no receipt is ever written; and `Validate-Certification` then refuses the `Complete` transition. The Gate runs identically for a human and for an agent, so this is not an agent limitation — it is a closed door.

This is the defect class `SPEC-164` named as DEFECT B and repaired for `DATABASE`: a profile that can only ever withhold certification leaves the executing party choosing between permanent incompleteness and completing without certification. `DATABASE` was repaired by EXECUTING its protocol rather than listing it. `WORKSTATION` was left deferring, and the deadlock went unobserved because no contract derived `WORKSTATION` between the receipt gate landing on 2026-09-11 and this work — the previous change to `.workstation/**` was `e0d897b`, which predates it.

The workstation single-authority capability behind `SPEC-186` and `SPEC-188` is fully implemented and independently verified in the tree today; both contracts were cancelled for scope reasons, not for defects in the work. This contract carries those preserved bytes to completion and is itself the first contract to certify through the repaired path, which makes its own `-Finish` the real proof that the path works.

## Risks

Moderate and bounded. Executing idempotence means `-Finish` now runs `.workstation/prepare.ps1` once for a workstation-scoped contract, so certification touches the machine rather than only reading it. That is deliberate and is the same trade `DATABASE` already makes with `npx supabase db reset`, which is considerably more destructive; `-Finish` is local-only and never runs in CI. The verifier never uninstalls anything, never clears credentials, and never manufactures damage. The real risk is a false red on a machine that has not been converged yet: that is accepted and made explicit, because the verifier reports it as "converge first with workstation.cmd" rather than silently passing. The opposite risk — weakening the profile so certification becomes reachable by asserting less — is refused outright: doctor health remains executed evidence and no CR-specific exemption exists.

## Supersedes / Depends On

Supersedes `changes/SPEC-188-workstation-desired-state-has-one-owner.md`, which is already `Cancelled`, and inherits the implementation it committed at `343186f`, which itself preserved the implementation `SPEC-186` committed at `7e62849`. Both files are terminal and are NOT in this contract's Write Scope; neither is reopened or edited. No byte of that preserved work is reimplemented here — the steps below detect it and record it as Already Applied.

## Write Scope

- `changes/SPEC-189-workstation-certification-is-reachable.md`
- `scripts/verify_workstation_idempotence.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `.github/workflows/repository-consistency.yml`
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.workstation/update.ps1`
- `.workstation/manifest.md`
- `.workstation/reports/INSTALLATION_STATUS.md`
- `WORKSTATION.md`
- `scripts/check_repository_consistency.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-186-workstation-desired-state-has-one-owner.md`
- `changes/SPEC-188-workstation-desired-state-has-one-owner.md`
- `.vscode/extensions.json`
- `.mcp.json`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `.workstation/menu.ps1`
- `.workstation/cleanup.ps1`
- `.workstation/decommission.ps1`
- `.workstation/claude-awareness.ps1`
- `bootstrap.ps1`
- `workstation.cmd`
- `.claude/awareness.json`
- `scripts/check_database_parity.ps1`
- `scripts/publish_candidate.ps1`
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

Also out of scope as SUBJECTS, not merely as files: any change to the certification receipt's shape, matching rules, or validation, beyond the profile whose evidence is being executed; any exemption of `WORKSTATION` from receipt validation; any per-identity special case; converting local evidence into `POST_PUSH` or `EXTERNAL` evidence; any change to `-Certify`, `-Gate` or Publisher; `DATABASE`, `CI`, `CONTROL` or `REPOSITORY` profile evidence; Check 12, calibration batching, continuity-suite performance work, Migration CI retirement, `ai-map` redesign; `.workstation/inventory.psd1`; a generic retry framework; Docker or WSL redesign; making `doctor.ps1` a mutator; a root `Doctor.cmd`; a generic workstation manager; and any new mutation framework or test harness.

## Required Reading

- `scripts/check_agent_continuity.ps1` (`Get-ProfileEvidence`, `Finish-Checks`, `Write-Certification`, `Validate-Certification`)
- `.workstation/prepare.ps1`
- `changes/SPEC-188-workstation-desired-state-has-one-owner.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Implementation Steps

1. **The comparison gets one owner.** Search for the file `scripts/verify_workstation_idempotence.ps1`. If it exists, record Already Applied. If it is absent, create it as a read-only-by-default verifier that runs `.workstation/prepare.ps1` exactly once and fails closed unless all of the following hold: the run exits 0; it emits no `[INSTALL]` line; it emits no `[CONFIG]` line; it reports no `[FAIL]` line or `FAILED` note; and every tracked repository file is byte-identical across the run. It must never uninstall, remove, or damage any component, and must state that an unconverged workstation should be converged with `workstation.cmd` first.

2. **The profile executes its evidence.** In `scripts/check_agent_continuity.ps1`, search for `verify_workstation_idempotence` inside `Get-ProfileEvidence`. If it is present, record Already Applied. If it is absent, add `pwsh -NoProfile -File scripts/verify_workstation_idempotence.ps1` to the `WORKSTATION` profile's `Local` list after the doctor command, and empty that profile's `Deferred` list so no `LOCAL_NOT_EXECUTED` note remains. The doctor command stays exactly as it is. No other profile is touched.

3. **The repaired semantics are asserted in both directions.** In `scripts/test_agent_continuity.ps1`, search for `MUST-ACCEPT: proven WORKSTATION evidence executes and reaches a receipt`. If it is present, record Already Applied. If it is absent, replace the assertion that pinned `WORKSTATION` Finish as permanently `INCOMPLETE` with one proving that both workstation commands execute, that `LOCAL_CERTIFY: READY` is reached, and that a receipt naming the `WORKSTATION` profile is written; and add two rejection assertions proving that a failing idempotence verifier blocks certification and leaves no usable receipt even when one existed beforehand, and that a failing doctor still blocks certification and writes no receipt. Use the next free assertion identifiers. No unrelated assertion is modified.

4. **Carry the preserved workstation work.** Verify that the single-authority implementation inherited from `SPEC-188` is present and unaltered: `.workstation/prepare.ps1` and `.workstation/doctor.ps1` read `.vscode/extensions.json` and `.mcp.json` rather than restating them; `.workstation/update.ps1` classifies by `$LASTEXITCODE`; `Profiles` derives `WORKSTATION` for `bootstrap.ps1`, `workstation.cmd`, `.vscode/extensions.json` and `.mcp.json`; Check 28 exists in `scripts/check_repository_consistency.ps1` and its two inputs are declared in Check 20's map and carried by both trigger blocks of `.github/workflows/repository-consistency.yml`; `.workstation/reports/INSTALLATION_STATUS.md` is a dated historical snapshot; `WORKSTATION.md` routes current status to the doctor; and `.workstation/manifest.md` names both authorities. Record each as Already Applied. Reimplement nothing that is already present.

5. **Synchronize.** Set `Active Change Request` in `_ORVION_CANONICAL/manifest.md` to this contract while it is in progress, and on completion set `Last Completed` to this capability, repoint `Next capability`, restore the pointer to `None`, and regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [x] `scripts/verify_workstation_idempotence.ps1` exists, runs `.workstation/prepare.ps1` once, and exits non-zero when the run installs, reconfigures, reports a failure, exits non-zero, or changes any tracked repository file.
- [x] The `WORKSTATION` profile in `scripts/check_agent_continuity.ps1` lists both the doctor and the idempotence verifier as `Local` evidence and carries no `LOCAL_NOT_EXECUTED` note.
- [x] `scripts/test_agent_continuity.ps1` contains an assertion proving a proven `WORKSTATION` Finish reaches `LOCAL_CERTIFY: READY` and writes a receipt recording the `WORKSTATION` profile.
- [x] `scripts/test_agent_continuity.ps1` contains an assertion proving a failing idempotence verifier blocks certification and leaves no usable receipt, including one written before the attempt.
- [x] `scripts/test_agent_continuity.ps1` contains an assertion proving a failing doctor blocks certification and writes no receipt.
- [x] `.workstation/prepare.ps1` and `.workstation/doctor.ps1` contain no literal VS Code extension identifier and no literal project MCP name, and both fail closed when their authority declares nothing.
- [x] `.workstation/update.ps1` classifies a step by `$LASTEXITCODE`, recording `FAILED (exit <code>)` for any non-zero value other than `-1978335189` and `-1978335135`.
- [x] `Profiles` returns `WORKSTATION` for `bootstrap.ps1`, `workstation.cmd`, `.vscode/extensions.json` and `.mcp.json`.
- [x] `scripts/check_repository_consistency.ps1` contains Check 28, and both `.vscode/extensions.json` and `.mcp.json` appear in Check 20's input map and in both trigger blocks of `.github/workflows/repository-consistency.yml`.
- [x] `.workstation/reports/INSTALLATION_STATUS.md` identifies itself as a dated historical snapshot, `WORKSTATION.md` routes current status to `.workstation/doctor.ps1`, and `.workstation/manifest.md` names both authorities.

## Execution Log

(no entries yet)

### 2026-09-16 — Claude Opus 5 (executing agent)

Outcome: Complete

Step results:
- Step 1: Applied — `scripts/verify_workstation_idempotence.ps1` created. It runs `.workstation/prepare.ps1` once and fails closed on any of: non-zero exit, an `[INSTALL]` line, a `[CONFIG]` line, a `[FAIL]`/`FAILED` report, or a change to any tracked repository file. It uninstalls nothing and names `workstation.cmd` as the remedy for an unconverged machine.
- Step 2: Applied — the `WORKSTATION` profile now lists the doctor and the verifier as `Local` evidence with an empty `Deferred` list; no `LOCAL_NOT_EXECUTED` note remains. No other profile touched.
- Step 3: Applied — assertion 92 replaced and assertions 173 and 174 added.
- Step 4: Already Applied — every inherited element verified present and unaltered: both scripts read their authorities and fail closed, `update.ps1` classifies by `$LASTEXITCODE`, `Profiles` covers the four paths, Check 28 exists with both inputs declared and both trigger blocks carrying them, the snapshot is historical, `WORKSTATION.md` routes to the doctor, and the manifest names both authorities. Nothing was reimplemented.
- Step 5: Applied — manifest pointer and `ai-map.json` synchronized.

The deadlock, measured before the repair. `Get-ProfileEvidence` gave `WORKSTATION` an unconditional `LOCAL_NOT_EXECUTED` note; `Finish-Checks` turns any such note into `LOCAL_CERTIFY: INCOMPLETE`; `Write-Certification` runs only on the `READY` branch; `Validate-Certification` refuses `Complete` without a receipt. Staging the exact `Complete` transition on `SPEC-188` with all 13 Acceptance Criteria and 7 Review Gate items checked, `Blocker: None`, `Resume Step: DONE`, a `Confirmed Complete` verdict, the pointer cleared and `ai-map.json` regenerated returned `COMPLETION_PREREQUISITE:no local certification receipt`. The three touched files were restored byte-identical afterwards. That is the closed door this contract opens.

Idempotence, defined from the live provisioner rather than abstractly. One `prepare.ps1` run on an already-converged workstation must exit 0, emit no `[INSTALL]` line, emit no `[CONFIG]` line, report no failure, and leave every tracked repository file byte-identical. Silence is deliberately NOT required: `prepare.ps1` legitimately re-runs detection, refreshes PATH and re-verifies through the doctor on every run, and demanding zero operating-system noise would measure the wrong property.

Causal proofs:

| door | case | result |
| --- | --- | --- |
| SUCCESS | both workstation commands pass (assertion 92) | `LOCAL_CERTIFY: READY`, receipt written, `profiles` contains `WORKSTATION` |
| FAILURE | idempotence verifier exits 1 with a READY receipt already on disk (assertion 173) | Finish fails, no `READY`, and `ReceiptJson` is null — the pre-existing receipt did not survive |
| FAILURE | doctor exits 1, idempotence passes (assertion 174) | Finish fails, no `READY`, no receipt — doctor health was not demoted |
| REAL PATH | the real verifier against the real workstation | exit 0, no installation, no reconfiguration, no failure, every tracked file byte-identical |

Assertions 173 and 174 use stubbed `.workstation/doctor.ps1` and verifier scripts inside the suite's synthetic sandbox, so no real software was uninstalled, no credential cleared, and no environmental damage manufactured to produce a failure. The stale-receipt protection they exercise is `Finish-Checks`'s existing "a previous receipt is destroyed FIRST" behaviour, which this contract preserves rather than adds.

Suite: `AGENT CONTROL TESTS: 174 passed, 0 failed`, including `PASS 92`, `PASS 173` and `PASS 174`.

Prior workstation and SSOT proofs from the cancelled contracts were NOT repeated: their implementation bytes are unchanged, proven by restoring the three repair files byte-identical by SHA256 and by every inherited element verifying as Already Applied. Only the receipt-door proofs are new, because only the certification path changed.

Commits: this entry's own commit.

## Verification Notes

(no entries yet)

### 2026-09-16 — Claude Opus 5 (reviewing agent)

Verdict: Confirmed Complete

Findings: all ten Acceptance Criteria were re-derived from the live files rather than read back from the Execution Log; 10 of 10 hold. `WORKSTATION` certification is now reachable — assertion 92 proves a proven run reaches `READY` and writes a receipt recording the profile. It cannot become `READY` without the proof: assertions 173 and 174 each fail Finish and leave no receipt, and 173 additionally proves a receipt written beforehand is destroyed rather than reused. Doctor remains read-only and remains separately executed evidence; nothing in this contract writes through it. The preserved workstation work is intact and unaltered, verified element by element and by byte-identical restoration of the three repair files.

No rejected proposal entered scope: no `.workstation/inventory.psd1`, no retry framework, no Docker or WSL change, no doctor mutation, no root `Doctor.cmd`, no receipt-shape change, no `WORKSTATION` exemption from receipt validation, and no per-identity special case. The `Deferred` lists of `DATABASE`, `CI`, `CONTROL` and `REPOSITORY` are untouched. Known in-unit debt: none.

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

Mechanisms considered and rejected, recorded so a later agent does not re-derive them. Removing the idempotence requirement so Finish turns green was refused: it discards declared evidence to buy a passing result, which is the failure the receipt exists to prevent. Listing `prepare.ps1` twice as two ordinary commands was refused: two exit-0 results prove both runs succeeded, not that the second changed nothing, and idempotence is a comparison. A `-VerifyIdempotence` switch inside `prepare.ps1` was refused: it puts the measurement inside its own subject, so a provisioner broken in the measured direction reports itself green. An operator attestation flag was refused for the reason `SPEC-164` already gives — "a boolean would not do" — since an unverified self-assertion is exactly what the receipt replaced. An agent-written idempotence artifact that Finish validates was refused as a second receipt-like authority for one fact.

The verifier runs `prepare.ps1` ONCE rather than twice. Idempotence is `f(f(x)) = f(x)`, and the doctor command that precedes it in the same profile is what establishes that the machine is already converged; measuring one further run against a converged machine is therefore the property itself, at half the cost. On a machine that is not converged the single run installs or configures something and the verifier fails loudly, which is the correct fail-closed answer rather than a false green.

Doctor remains read-only and is deliberately kept as separate executed evidence. `prepare.ps1` runs the doctor internally at its end, so a workstation Finish observes doctor health more than once; that duplication belongs to the provisioner's own self-verifying design and is not introduced here, and collapsing the two would make a contract that changes only `doctor.ps1` stop verifying it directly.


### 2026-09-17 — Claude Opus 5 (reviewing agent, pattern and resilience gate)

Verdict: Confirmed Complete

Findings: `-Finish` returned `LOCAL_CERTIFY: READY` on `adcbed9` with all nine mandatory commands PASS, including `scripts/verify_workstation_idempotence.ps1` against the real workstation, and wrote a receipt naming `SPEC-189` and the four derived profiles. The deadlock is closed on the real path, not only in fixtures.

The recurrence class was tested rather than assumed. `LOCAL_NOT_EXECUTED` was injected into the `CONTROL` profile — chosen because neither of the two profile-specific positive-path assertions (92 for `WORKSTATION`, 103 for `DATABASE`) derives it — and the existing suite KILLED it: assertion 79, whose scope `.github/workflows/agent-control.yml` derives `CONTROL`, `CI` and `REPOSITORY` and which pins `LOCAL_CERTIFY: READY`, failed. `scripts/check_agent_continuity.ps1` was restored byte-identical by SHA256 and the receipt remained valid.

A generic "no profile may emit `LOCAL_NOT_EXECUTED`" assertion therefore DOES NOT EARN IMPLEMENTATION, and none was added. The protection already exists by construction: every profile is covered by at least one assertion that pins a positive `LOCAL_CERTIFY: READY` path — `REPOSITORY` by 42, 98b and 110b, `CONTROL` and `CI` by 79, `WORKSTATION` by 92, `DATABASE` by 78 and 103 — so the same deadlock injected into any profile fails an existing test. No pattern registry, taxonomy, report or meta-test was created; the durable protection is executable and already present.

The verifier's own failure branches were proven causally in an isolated scratch repository, never against the real machine: a non-zero exit, an `[INSTALL]` action, a `[CONFIG]` action, a reported `[FAIL]`, and a silent tracked-byte mutation are each rejected, while a silent no-op run passes both before and after those mutants. Four of the five rejected cases exit 0, which is the property that matters — exit 0 alone never reads as idempotent. Nothing was uninstalled, no credential cleared and no environmental damage manufactured.

The bounded false-green sweep over the workstation surface found no further occurrence of the `update.ps1` shape. Both candidates were probed rather than assumed: `$?` does observe a native non-zero exit, so `doctor.ps1`'s `Test-Version` is sound, and the apparent native call in `claude-awareness.ps1` was a prose line matching the search. Check 20 and Check 28 already own their recurrence classes and were not duplicated. The `SPEC-186` and `SPEC-188` cancellations have different causes and are not treated as a reusable pattern.

Known in-unit debt: none. The `CI` profile's evidence remains `POST_PUSH` and is declared, never claimed locally.

Recommendation to human: Set Status to Complete