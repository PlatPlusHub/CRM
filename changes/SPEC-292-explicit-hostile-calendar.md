# Change Request — SPEC-292

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the future-date guard test establish and verify a genuinely hostile parsing calendar independently of the operating system's locale default.

## Business Reason

The test equates ar-SA with a default UmAlQuraCalendar. Ubuntu 26.04 with ICU 78 instead selects Gregorian, so the hostile parser is never established and the test correctly refuses its own proof. The required hosted check can therefore fail despite a clean repository and a successful Windows Finish. Select the intended hostile calendar explicitly while preserving all guard assertions, all admission requirements and fail-closed behaviour.

## Risks

Low: executable changes affect only the existing test's child-process fixture and its own integrity checks; the finding register records the measured repair. DateTimeFormat.Calendar is the parser's effective calendar; CultureInfo.Calendar still reports the locale default after an explicit override. Unsupported calendars or unavailable globalization must still fail. No regional setting, runtime installation, workflow, credential or protection changes. A successful local test is not hosted acceptance or remote certification.

## Supersedes / Depends On

Depends on locally Complete `SPEC-291` at `328b9c948f2a908a8e548826ac875d560ea75551`. That original candidate remains immutable historical evidence; its publication does not establish release or certification. Supersedes no terminal contract.

## Write Scope

- `changes/SPEC-292-explicit-hostile-calendar.md`
- `scripts/test_future_date_guard.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/watch_ci.ps1`
- `scripts/github_public_read.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/batch6_select_target.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `README.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

Every unlisted path remains outside scope. Batch 6 remains ON HOLD; CTRL-19 remains OPEN. No existing frozen contract, business policy, release authority or repository routing changes.

## Required Reading

- `AGENTS.md` sections 1–3
- `CR_LIFECYCLE.md` sections 4–5,8–9,11
- `ENGINEERING_METHOD.md` sections 1–3
- `changes/TEMPLATE.md`
- `scripts/test_future_date_guard.ps1`: hostile child, calendar oracle, culture probes
- `scripts/check_repository_consistency.ps1`: invariant date provider and Checks 12,21,23
- `.github/workflows/repository-consistency.yml`, `.github/workflows/orvion-acceptance.yml`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- `pwsh -NoProfile -File scripts/test_future_date_guard.ps1`

## Pre-Approval Evidence

Change Class: Routine

Baseline: `328b9c948f2a908a8e548826ac875d560ea75551`. The native sequence and reservation helpers derive `SPEC-292` as the next unreserved identity. The native profile deriver produces REPOSITORY for this exact scope; the additional command runs the changed test. Accepted expensive preparation and the predecessor's Finish are not repeated as preparation for this change.

Source anchors, refreshed before allocation:

| Path | Baseline blob |
| --- | --- |
| `scripts/test_future_date_guard.ps1` | `2e2732e82d9c887202b52b830272ab69f21274bb` |
| `reports/master/MASTER_GAP_REGISTER.md` | `7f957064cf1c3622229e220a85ae123c63648f1c` |
| `_ORVION_CANONICAL/manifest.md` | `e3aef6c7f3784318f8d886e829425cf21208d541` |
| `ai-map.json` | `4e012443e4159f89bfd2937950bd3b361cf1e499` |
| `repository-index.md` | `d075792a248fc781d7012cc0296fcd8bc15a47d5` |
| `scripts/check_repository_consistency.ps1` | `3e6d2810e03bfac15b96dba3bc46d119d97ad658` |
| `scripts/check_agent_continuity.ps1` | `d5d5b2845e7e5620afca82d9ee08aa9de23b483f` |
| `scripts/test_agent_continuity.ps1` | `047370a65254ed92ad1c3ec89d4e6ecc2564002d` |
| `scripts/run_timed.ps1` | `d1fbfc81d41b04b0c8b3a50c4b17cdd19853ca60` |
| `scripts/watch_run.ps1` | `e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b` |
| `scripts/watch_ci.ps1` | `738cb36667d4d9bef8182580c9115bc303a96329` |
| `scripts/github_public_read.ps1` | `97f5c8894e5772e5a46e792aef927c5055e402b2` |
| `scripts/publish_candidate.ps1` | `d168504cc66c3a0759ac3ee9b5e01045a0f46589` |
| `scripts/promote_main.ps1` | `bf64aa893faf9d6be7477254bebf80dca04b4d79` |
| `scripts/generate-ai-map.ps1` | `01165b8570999b79de4d6e854cae2443256e6b64` |
| `scripts/batch6_select_target.ps1` | `20e55b308088b4f5405029f02605915231246fbe` |
| `.github/workflows/agent-control.yml` | `41243b7c9a499df4cf011385a046c53107084ba3` |
| `.github/workflows/orvion-acceptance.yml` | `b242e4c7401258404c5d43bffb49c3f53f42467e` |
| `.github/workflows/repository-consistency.yml` | `ed3ef8d8e954c8a2c5710fe44f46eb1f569c7492` |
| `.github/workflows/migration-ci.yml` | `9bf8ca02d8ffac6591871b66bff53d5dbfc6e75c` |
| `README.md` | `9f15270f25194e4ed0bb08613ca185a16b05ea2d` |
| `AGENTS.md` | `b2412d15cd6fcf710055114fe734ba69178f35cc` |
| `GOVERNANCE.md` | `5670c47888bbd6b4194f6c41c54476ee42cb7bdf` |
| `ENGINEERING_METHOD.md` | `874d1eefc1707dc56a9cbc41dfc3e695e2a0b726` |
| `CR_LIFECYCLE.md` | `bcebabb0665901fa1ebf1b7e28ddbbecddeb5f68` |
| `changes/TEMPLATE.md` | `6494ecfc57e0212e8b1c35dbab46daa7f510f2f9` |
| `reports/architecture-decision-records.md` | `0bc32a7ec591cfbeeb7b26333ce66825d04c3e26` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `e957b949bc330cb637a634644664bf93bd2eb5ce` |

### Draft Assurance

Pass 1 Design: Explicitly select UmAlQura in the existing ar-SA child, retain its calendar integrity oracle, and preserve the guard's four scenarios and existing assertions.

Pass 2 Adversarial Review: Rejected checking CultureInfo.Calendar after selecting the effective calendar because the former remains Gregorian on ICU 78. Check DateTimeFormat.Calendar and also exercise the old null-provider parser; it must reject Gregorian year 2026. A spoofed marker with selection removed must fail the behavioural control; a culture-sensitive guard mutant must lose the actual future/stale/HANDOFF findings. Added the required resolved finding in its existing register instead of leaving knowledge only in chat. A first disposable lifecycle rehearsal caught punctuation inside the Last Completed anchor; corrected it before freeze. Pinning an older hosted image or skipping the assertion would hide the defect and is rejected.

Pass 3 Evidence Refresh: On 2026-10-21, re-read current source, line history, native allocation/profile derivation and hosted image evidence. Reproduced ar-SA default Gregorian/null-provider parse True on Ubuntu 26.04 with PowerShell 7.6.6, .NET 10.0.12 and task-local ICU 78.2; explicit effective UmAlQura gives False. Windows PowerShell 7.6.7/.NET 10.0.13 gives False with its default and explicit UmAlQura. The frozen final bytes passed the full changed suite on Linux and this repository's Windows prototype; causal mutants failed as designed, and native lifecycle rehearsal admitted approval, implementation, range and trusted judgment. Exact preparation logs are retained with the owner packet; no prototype is a certified implementation.

Selected Version: Version 1, one existing test file with explicit effective calendar selection and a behavioural anti-vacuity control; no new framework, guard bypass, runtime pin or workflow change.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Hostile child must use UmAlQura independent of locale default | `scripts/test_future_date_guard.ps1` | WRITE | Explicit effective calendar; real null-provider parse must fail; existing assertions preserved |
| Date guard must reject future/stale/HANDOFF probes | `scripts/check_repository_consistency.ps1` | VERIFY | Existing invariant provider remains unchanged; culture-sensitive mutant loses the findings |
| Hosted calibration and local verification | `.github/workflows/repository-consistency.yml`, `.github/workflows/orvion-acceptance.yml`, `scripts/check_agent_continuity.ps1` | VERIFY | Existing commands continue to execute this test; required hosted success is still mandatory |
| Contract lifecycle projections | `_ORVION_CANONICAL/manifest.md`, `ai-map.json`, `repository-index.md` | WRITE | Only native lifecycle fields/projections change; Batch 6 direction and hold preserved |
| Measured calendar fixture defect | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | One resolved AUD-01d row and freshness header; existing finding rows, including CTRL-19, preserved exactly; no new open action |
| Existing routing, governance pins and release | `AGENTS.md`, `README.md`, `GOVERNANCE.md`, `scripts/publish_candidate.ps1`, `scripts/promote_main.ps1` | UNAFFECTED | No edits; native trusted release and exact-SHA certification remain authoritative |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Approved exact contract and valid source baseline | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Hostile fixture and actual guard verdicts agree | BEFORE_COMPLETION | 2 | 4 | 5 |
| Generated projections and exhaustive scope agree | BEFORE_COMPLETION | 2 | 4 | 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: the current test's child process, independent date formatter, four guard invocations, calendar integrity assertion and Check helper; no new permanent script or gate.

Added Property: the hostile parser is explicitly established on both Gregorian-default and UmAlQura-default hosts, and a printed calendar label alone cannot supply the hostile-parser proof.

Causal Negative: on Ubuntu 26.04/ICU 78 the unchanged child creates ar-SA with Gregorian, and its null-provider parse of 2026-01-02 succeeds; the old calendar assertion fails. Explicitly selecting UmAlQura makes that same parse fail.

Positive Test Design: all existing future-date, Gregorian diagnostic, stale freshness, HANDOFF, ignored-cache and tracked-evidence assertions continue to pass with the intended hostile calendar actually selected.

Negative Test Design: a missing hostile calendar, even beside a spoofed success label, fails the real null-provider parser check; a guard switched back to culture-sensitive parsing loses the named probe findings.

Non-Empty Population Obligation: prove the child actually ran with the intended effective calendar and rejected the old parser input before trusting its three real guard findings; preserve all existing fixture population and mutation assertions.

Mutation Obligation: remove calendar selection and spoof the old marker, requiring the added behavioural oracle to fail; change the guard's invariant provider to null, requiring named future/stale/HANDOFF assertions to fail. Restore every mutation in the disposable fixture.

Post-Implementation Proof Obligation: the exact changed suite and mandatory REPOSITORY profile pass in fresh native timed/watched Finish; independent Review checks all frozen bytes and scope. Hosted acceptance, trusted promotion and exact-SHA Remote Certify must pass on the final candidate before release is claimed.

## Implementation Steps

1. Verify exact owner approval of this Draft, baseline `328b9c948f2a908a8e548826ac875d560ea75551`, all source anchors, clean original checkout and its retained predecessor bound record. Allocate the exact frozen Draft and use the native Approved transition before implementation. Preserve all prior receipts and named candidate branches. STOP if identity, scope, approval or baseline disagrees.

2. Check whether `scripts/test_future_date_guard.ps1` contains `EXPLICIT-HOSTILE-CALENDAR`; if so record Already Applied when its Git blob is dc23505d60eb4fe25870d70bfdf709759b61ec55, and otherwise stop and report. Otherwise make exactly these 6 edits (explicit effective calendar and a behavioural anti-vacuity control), each matched once, and change nothing else:

   a) replace the line
   ```text
   # default calendar is not Gregorian (`ar-SA` -> UmAlQuraCalendar) the year 2026 is out of range,
   ```
   with
   ```text
   # effective calendar is not Gregorian (ar-SA with explicit UmAlQuraCalendar), year 2026 is out of range,
   ```

   b) immediately after the line
   ```text
               # culture alone and not on whatever this workstation's regional panel happens to say.
   ```
   insert
   ```text
               # EXPLICIT-HOSTILE-CALENDAR: locale defaults vary across ICU releases. Select the
               # parser's calendar explicitly and measure DateTimeFormat.Calendar, not the default
               # CultureInfo.Calendar (which remains Gregorian on newer Linux images).
   ```

   c) immediately after the line
   ```text
   param([string]$Guard, [string]$Root, [string]$Culture)
   ```
   insert
   ```text
   $ErrorActionPreference = 'Stop'
   ```

   d) immediately after the line
   ```text
   $c = [System.Globalization.CultureInfo]::new($Culture, $false)
   ```
   insert
   ```text
   $c.DateTimeFormat.Calendar = [System.Globalization.UmAlQuraCalendar]::new()
   ```

   e) replace the line
   ```text
   Write-Output "CULTURE-PROBE: $([System.Globalization.CultureInfo]::CurrentCulture.Name) $([System.Globalization.CultureInfo]::CurrentCulture.Calendar.GetType().Name)"
   ```
   with
   ```text
   Write-Output "CULTURE-PROBE: $([System.Globalization.CultureInfo]::CurrentCulture.Name) $([System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.Calendar.GetType().Name)"
   $parsed = [datetime]::MinValue
   $accepted = [datetime]::TryParseExact('2026-01-02', 'yyyy-MM-dd', $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)
   Write-Output "CULTURE-NEGATIVE: null-provider accepted=$accepted"
   ```

   f) replace the line
   ```text
       'the hostile-culture child did not report ar-SA/UmAlQuraCalendar -- the culture proofs below would be vacuous'
   ```
   with
   ```text
       (($hostileOut -split "`n" | Where-Object { $_ -match '^CULTURE-' }) -join ' | ')
   Check "the hostile parser rejects a Gregorian year without an invariant provider" `
       ($hostileOut -match 'CULTURE-NEGATIVE: null-provider accepted=False') `
       (($hostileOut -split "`n" | Where-Object { $_ -match '^CULTURE-' }) -join ' | ')
   ```

   The resulting file's Git blob is dc23505d60eb4fe25870d70bfdf709759b61ec55.

3. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| AUD-01d |`; if so record Already Applied when its Git blob is 346f88e53111ecc5dde7fcbc73c6527f66fceca8, and otherwise stop and report. Otherwise make exactly these 2 edits (one resolved finding and its freshness header, preserving existing rows including CTRL-19), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-10-14 (**SPEC-281: a contract is judged against current authority, and CI re-proves what the hook judges.** **CTRL-17** (High) and **CTRL-18** (High) are new and fixed. CI had re-proved none of four transitions the hook refuses for a contract born inside its range, so `git commit --no-verify` published a reworded criterion, unticked criteria with no verdict, or a rewritten log. Approval had admitted SPEC-278's Consumer Closure, which wrote the Batch 6 target into a line SPEC-270 made point at its owner. **CTRL-19** (High) is new and open, waiting on the owner: the required check is computed by the candidate's own code, and the agent's credential administers the ruleset.)
   ```
   with
   ```text
   Last updated: 2026-10-21 (**SPEC-292: AUD-01d fixes the hostile-calendar test precondition.** The existing guard and every required gate remain unchanged.)

   Previously: 2026-10-14 (**SPEC-281: a contract is judged against current authority, and CI re-proves what the hook judges.** **CTRL-17** (High) and **CTRL-18** (High) are new and fixed. CI had re-proved none of four transitions the hook refuses for a contract born inside its range, so `git commit --no-verify` published a reworded criterion, unticked criteria with no verdict, or a rewritten log. Approval had admitted SPEC-278's Consumer Closure, which wrote the Batch 6 target into a line SPEC-270 made point at its owner. **CTRL-19** (High) is new and open, waiting on the owner: the required check is computed by the candidate's own code, and the agent's credential administers the ruleset.)
   ```

   b) immediately after the line
   ```text
   | AUD-01c | **Check 12 judged a generated, gitignored Supabase cache as authored evidence, and made DATABASE certification unreachable** | guard integrity / certification | High | R | 6 | — | ✅ | **✅ FIXED 2026-09-17 (`SPEC-192`; predecessor `SPEC-191` CANCELLED).** REPRODUCED end to end before any edit. `Profiles()` returns `@($h|sort)`, so **DATABASE sorts ahead of REPOSITORY**: `-Finish` runs `npx supabase db reset` first, the reset regenerates the gitignored `supabase/.temp/pgdelta` catalog cache, and that cache captures Supabase Realtime's own `realtime.messages_*` **daily partition bounds — legitimately dated days ahead, because a partition must exist before the day it covers**. Check 12's population was every file on disk minus `node_modules`/`backup`/`.git`, with `.gitignore` never consulted, so it read those bounds as evidence, exited 1, raised `MANDATORY_VERIFICATION_FAILED`, and left no certification receipt — `Complete` was unreachable for every remaining Batch-6 database slice. No ORVION migration creates those partitions. Deleting the cache first does not help: the reset that regenerates it is itself a mandatory step. **The repair is the measurement POPULATION, never the date invariant** — `$dateRx`, the UTC+14 ceiling, the invariant-culture parsing and the clock cross-check are untouched, and no exemption list was added, which this check refuses by design. The population is now Git's own repository-candidate set (`ls-files --cached --others --exclude-standard`), so untracked non-ignored evidence is still judged before it is committed and a tracked file stays judged even if an ignore rule later matches it; a non-zero git exit or an empty result falls back to the previous on-disk population, which over-measures rather than asserting over an empty set. Attacked in both directions by seven new assertions in `scripts/test_future_date_guard.ps1`, including a mutant that reverts the population and is caught reintroducing the false positive. Found while closing the Slice-12 pre-approval gate, not by a product surface. **PLATFORM SPLIT, measured:** the pre-repair population enumerates with `Get-ChildItem -Recurse -File` and no `-Force`, and a leading dot IS the hidden marker on Unix, so it sees that cache on Windows and not on Linux -- AUD-01c therefore manifests on the Windows workstation where LOCAL certification runs and never in Linux CI. `SPEC-191` keyed its mutation on that dot-prefixed fixture, which made the assertion unsatisfiable on Linux and got its candidate rejected remotely; `SPEC-192` retains this production repair unchanged and moves the discriminator to a NON-HIDDEN git-ignored generated-cache fixture that both populations resolve identically on both platforms, behind an oracle precondition that proves the fixture is visible before any mutant is believed. The platform-dependent `$allFiles` population is recorded as an observation and deliberately not repaired without a separately reproduced defect. | — | SPEC-191 | 09-17 | 09-17 |
   ```
   insert
   ```text
   | AUD-01d | **The hostile-calendar test trusted the locale default instead of establishing its parser precondition** | test integrity / CI | Medium | R | 6 | — | ✅ | **✅ FIXED 2026-10-21 (SPEC-292).** On Ubuntu 26.04 with ICU 78, ar-SA defaults to Gregorian: the old parser accepts Gregorian year 2026 and the fixture never attacks culture independence. The test now explicitly selects UmAlQura in DateTimeFormat.Calendar, measures that effective property, and proves a real null-provider parse rejects the year before trusting the existing guard findings. CultureInfo.Calendar remains the locale default and is not that measurement. Full changed suite passes with all original assertions; a removed selection with a spoofed label fails the behavioural oracle, and a culture-sensitive guard mutant loses the real findings. Existing native gates, hosted requirements and exact-SHA certification remain mandatory; prototype success is not release. | — | SPEC-292 | 10-21 | 10-21 |
   ```

   The resulting file's Git blob is 346f88e53111ecc5dde7fcbc73c6527f66fceca8.

4. Regenerate projections with `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, then `pwsh -NoProfile -File scripts/generate-ai-map.ps1 -Check`; verify the exhaustive scope and `git diff --check`. Preserve manifest pins and next-work direction. The native lifecycle sets only Active Change Request and, at Complete, `Last Completed: **SPEC-292: Explicit hostile calendar — fresh local verification and Review complete; owner publication/promotion and exact-SHA remote certification follow CR_LIFECYCLE.md section 9. Batch 6 remains ON HOLD by owner decision (2026-10-18) until the infrastructure programme completes and the owner authorizes resumption. CTRL-19 remains OPEN.**`; regenerate its projections after each transition.

5. Mark implementation Runtime Checkpoint DONE, run this contract's fresh native Finish once through Timed Runner with simultaneous Watcher, obtain independent live-state Review, and use native Complete only after all criteria and Review items hold. Bind the exact final candidate and retain its pending branch and record. Publication/promotion require the applicable owner delegation and successful native gates/hosted CI; this Draft grants no release authority or retrospective certification of an earlier candidate.

## Acceptance Criteria

- [ ] The changed test has exactly the reviewed bytes. `check: blob scripts/test_future_date_guard.ps1 dc23505d60eb4fe25870d70bfdf709759b61ec55`
- [ ] The finding is recorded in its existing authority with all prior finding rows, including CTRL-19, unchanged. `check: blob reports/master/MASTER_GAP_REGISTER.md 346f88e53111ecc5dde7fcbc73c6527f66fceca8`
- [ ] Explicit effective-calendar selection, the original calendar assertion and the real parser negative control coexist. `check: has scripts/test_future_date_guard.ps1 "EXPLICIT-HOSTILE-CALENDAR"` `check: has scripts/test_future_date_guard.ps1 "CurrentCulture.DateTimeFormat.Calendar.GetType().Name"` `check: has scripts/test_future_date_guard.ps1 "the hostile parser rejects a Gregorian year without an invariant provider"`
- [ ] All original test assertions remain, the complete suite passes, and the hostile fixture cannot pass merely by printing a label; verify preparation mutants and final native Finish evidence independently.
- [ ] All forbidden baseline files remain unchanged. `check: blob scripts/check_repository_consistency.ps1 3e6d2810e03bfac15b96dba3bc46d119d97ad658` `check: blob scripts/check_agent_continuity.ps1 d5d5b2845e7e5620afca82d9ee08aa9de23b483f` `check: blob scripts/test_agent_continuity.ps1 047370a65254ed92ad1c3ec89d4e6ecc2564002d` `check: blob scripts/run_timed.ps1 d1fbfc81d41b04b0c8b3a50c4b17cdd19853ca60` `check: blob scripts/watch_run.ps1 e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b` `check: blob scripts/watch_ci.ps1 738cb36667d4d9bef8182580c9115bc303a96329` `check: blob scripts/github_public_read.ps1 97f5c8894e5772e5a46e792aef927c5055e402b2` `check: blob scripts/publish_candidate.ps1 d168504cc66c3a0759ac3ee9b5e01045a0f46589` `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79` `check: blob scripts/generate-ai-map.ps1 01165b8570999b79de4d6e854cae2443256e6b64` `check: blob scripts/batch6_select_target.ps1 20e55b308088b4f5405029f02605915231246fbe` `check: blob .github/workflows/agent-control.yml 41243b7c9a499df4cf011385a046c53107084ba3` `check: blob .github/workflows/orvion-acceptance.yml b242e4c7401258404c5d43bffb49c3f53f42467e` `check: blob .github/workflows/repository-consistency.yml ed3ef8d8e954c8a2c5710fe44f46eb1f569c7492` `check: blob .github/workflows/migration-ci.yml 9bf8ca02d8ffac6591871b66bff53d5dbfc6e75c` `check: blob README.md 9f15270f25194e4ed0bb08613ca185a16b05ea2d` `check: blob AGENTS.md b2412d15cd6fcf710055114fe734ba69178f35cc` `check: blob GOVERNANCE.md 5670c47888bbd6b4194f6c41c54476ee42cb7bdf` `check: blob ENGINEERING_METHOD.md 874d1eefc1707dc56a9cbc41dfc3e695e2a0b726` `check: blob CR_LIFECYCLE.md bcebabb0665901fa1ebf1b7e28ddbbecddeb5f68` `check: blob changes/TEMPLATE.md 6494ecfc57e0212e8b1c35dbab46daa7f510f2f9` `check: blob reports/architecture-decision-records.md 0bc32a7ec591cfbeeb7b26333ce66825d04c3e26` `check: blob reports/master/MASTER_EXECUTION_PLAN.md e957b949bc330cb637a634644664bf93bd2eb5ce`
- [ ] The manifest retains this repository's Batch 6 hold and independent direction. `check: has _ORVION_CANONICAL/manifest.md "Batch 6 remains ON HOLD by owner decision (2026-10-18)"`

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Exact approved steps, source anchors and exhaustive scope independently confirmed.
- [ ] Every criterion holds against live evidence, including non-vacuous hostile parsing and unchanged guard semantics.
- [ ] Fresh native timed/watched Finish passes the actual derived profile and additional changed suite.
- [ ] Historical evidence, independent routing, native admission and release authorities preserved; no settings changed; Batch 6 ON HOLD and CTRL-19 OPEN.

## Notes

This corrects a test precondition, not a relaxation of the guard. Default locale metadata and the effective parsing calendar are distinct properties. Local prototype and rehearsal evidence never establish publication or certification. An earlier candidate's failed or pending hosted check stays attached to that exact SHA; descendant success cannot retrospectively certify it. Release sequencing and any changed completion boundary require explicit owner disposition before publishing a replacement tail. No Contract B work is included.
