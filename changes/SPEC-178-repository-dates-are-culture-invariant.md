# Change Request — SPEC-178

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make Repository Consistency's `yyyy-MM-dd` date contract independent of the machine's `CurrentCulture`, and prove Checks 12, 21 and 23 still flag their defects under a hostile non-Gregorian culture.

## Business Reason

Checks 12, 21 and 23 parse the repository's machine-readable dates with `[datetime]::TryParseExact(..., 'yyyy-MM-dd', $null, ...)`. A `$null` provider resolves to `DateTimeFormatInfo.CurrentInfo`, i.e. `CurrentCulture` — not `InvariantCulture`. Under a culture whose default calendar is not Gregorian (`ar-SA` resolves to `UmAlQuraCalendar`), the year 2026 falls outside the supported range, every parse returns `False`, and each check silently skips the record it was about to judge.

The failure is green, which is the worst available shape. Measured against the real guard at `cd92cb2` in a disposable clone, with culture as the only variable between two runs:

- Check 12 reported `no future-dated evidence` while a date one day beyond the UTC+14 ceiling sat in the tree;
- Check 21 reported `all 0 document(s)` where the same repository yields 20;
- Check 23 reported `all 0 report(s)` where the same repository yields 26.

All three assert success over an empty set. The invariant each guard enforces is correct; only the source of the calendar is wrong. This Change Request changes the calendar source and nothing else.

## Risks

Low, and bounded by construction.

- The change replaces a culture-sensitive format provider with an explicit invariant one at four parse sites and five diagnostic render sites. It alters no regex, no ceiling arithmetic, no freshness or HANDOFF semantics, no file enumeration, no issue counting and no check numbering.
- On an `en-US` machine and on CI (`ubuntu-latest`) behaviour is identical before and after, because `CurrentCulture` there is already Gregorian. That is also why this is a latent portability defect rather than a live CI failure.
- The material risk is a test that cannot see the defect. It is retired by running the widened suite against the unfixed guard first and requiring it to go red, and by a four-mutant causal battery that restores each parse site to `$null` one at a time and requires the matching proof, and only that proof, to fail.
- The hostile scenario reuses an existing calibration scenario rather than adding one, so the suite's guard-execution count does not increase.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-178-repository-dates-are-culture-invariant.md`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_future_date_guard.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `CODING_STANDARDS.md`
- `changes/TEMPLATE.md`
- `supabase/migrations`
- `reports/history`

## Required Reading

- `scripts/check_repository_consistency.ps1`
- `scripts/test_future_date_guard.ps1`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Implementation Steps

1. Verification check: `scripts/check_repository_consistency.ps1` contains the string `$isoDateFormat`. If it matches, record Already Applied and skip. Otherwise, immediately after the `$allFiles` / `$fileNames` preamble near the top of the file, add exactly one format value and exactly one culture value — `$isoDateFormat` set to the literal `yyyy-MM-dd`, and `$isoDateCulture` set to `[System.Globalization.CultureInfo]::InvariantCulture` — with a comment stating that the repository's machine-readable date contract is ASCII Gregorian and must not be read through the machine's calendar. Introduce no function, module, class or helper file. Change nothing else in the preamble.

2. Verification check: within Check 12, the `TryParseExact` call passes `$isoDateFormat, $isoDateCulture`. If it matches, record Already Applied and skip. Otherwise, in Check 12 only, replace the arguments `'yyyy-MM-dd', $null` with `$isoDateFormat, $isoDateCulture` in its single `TryParseExact` call, and render the dates in both of Check 12's diagnostics with `.ToString($isoDateFormat, $isoDateCulture)` — the `FUTURE-DATED` line's "newest civil date in existence", and the clock-sanity line's newest-commit date. Leave untouched: `$today = [datetimeoffset]::UtcNow.AddHours(14).Date`, `$dateRx`, the `20xx` horizon, the `-gt $today` comparison, the clock-skew comparison, the remedy text, and `$issues` accounting.

3. Verification check: within Check 21, the freshness-header `TryParseExact` call passes `$isoDateFormat, $isoDateCulture`. If it matches, record Already Applied and skip. Otherwise, in Check 21 only, replace the arguments `'yyyy-MM-dd', $null` with `$isoDateFormat, $isoDateCulture` in both `TryParseExact` calls — the header parse and the body-date parse — and render both dates in the `STALE FRESHNESS METADATA` diagnostic with `.ToString($isoDateFormat, $isoDateCulture)`. Leave untouched: `$freshHeaderRx`, `$bodyDateRx`, the 12-line head window, the self-selecting scope rule, the remedy text, and `$staleHeaders` accounting.

4. Verification check: within Check 23, the report-date `TryParseExact` call passes `$isoDateFormat, $isoDateCulture`. If it matches, record Already Applied and skip. Otherwise, in Check 23 only, replace the arguments `'yyyy-MM-dd', $null` with `$isoDateFormat, $isoDateCulture` in its single `TryParseExact` call, and render the report date in the `NO HANDOFF BLOCK` diagnostic with `.ToString($isoDateFormat, $isoDateCulture)`. Leave untouched: `$handoffRuleDate`, `$handoffFields`, the `Date:` regex, the cutoff comparison, the HANDOFF authority assertion, and `$handoffIssues` accounting.

5. Verification check: `scripts/test_future_date_guard.ps1` contains the string `ar-SA`. If it matches, record Already Applied and skip. Otherwise widen that file in place, preserving all five existing proof meanings and keeping the number of guard executions at four. Format every fixture date with an `InvariantCulture` instance the test obtains itself, never one imported from the guard. Convert the existing one-day-beyond-edge scenario, and only that scenario, into the hostile-culture scenario: run the real guard in a fresh `pwsh -NoProfile` child process whose `CurrentCulture` and `CurrentUICulture` are set process-locally to an `ar-SA` instance constructed with user overrides disabled, via a temporary wrapper written inside the disposable sandbox and deleted with it; never call `Set-Culture` and never change Windows regional settings or any persistent environment. Place three controlled probes in that one sandbox: the existing future-date `probe.md` for Check 12; a root-level `culture-freshness-probe.md` whose header date is older than a later body date, for Check 21; and `reports/history/culture-handoff-probe.md` carrying a `Date:` on or after the live Check 23 cutoff and deliberately containing no HANDOFF block, for Check 23. Assert that each of the three checks was reached and emitted its own expected diagnostic, and that every date rendered in those diagnostics is Gregorian.

## Acceptance Criteria

- [x] `scripts/check_repository_consistency.ps1` declares exactly one ISO date format value and exactly one invariant-culture value, and no new function, module, class or helper file was added for this.
- [x] No `TryParseExact` call in Check 12, Check 21 or Check 23 passes `$null` as its format provider.
- [x] Every diagnostic in Checks 12, 21 and 23 that renders a repository-contract date passes the invariant format and provider explicitly.
- [x] Check 12's ceiling is still `[datetimeoffset]::UtcNow.AddHours(14).Date`, and `$dateRx`, `$freshHeaderRx`, `$bodyDateRx`, `$handoffRuleDate` and `$handoffFields` are unchanged from their pre-change values.
- [x] `scripts/test_future_date_guard.ps1` still expresses its five original proof meanings and still invokes the guard exactly four times.
- [x] `scripts/test_future_date_guard.ps1` runs the one-day-beyond-edge scenario under a process-local `ar-SA` culture and asserts the Check 12, Check 21 and Check 23 diagnostics from that single run.
- [x] `scripts/test_future_date_guard.ps1` formats its fixture dates with an invariant culture it obtains itself, not one imported from the guard.
- [x] No file outside Write Scope was created, modified or deleted, and no new test file exists.

## Execution Log

### 2026-09-14 — Claude Opus 5 (agent)

Outcome: Complete

Step results:

- Step 1: Applied — one `$isoDateFormat` / `$isoDateCulture` pair added after the file-index preamble. No function, module, class or helper file introduced (`+function` count against the base is 0).
- Step 2: Applied — Check 12's parse takes the invariant provider; its `FUTURE-DATED` ceiling and clock-sanity commit date both render invariantly. `$today`, `$dateRx` and every comparison unchanged.
- Step 3: Applied — both Check 21 parses take the invariant provider; both dates in `STALE FRESHNESS METADATA` render invariantly. `$freshHeaderRx` and `$bodyDateRx` unchanged.
- Step 4: Applied — Check 23's parse takes the invariant provider; the `NO HANDOFF BLOCK` date renders invariantly. `$handoffRuleDate` and `$handoffFields` unchanged.
- Step 5: Applied — the suite's `edge + 1 day` scenario runs under a process-local `ar-SA` culture (user overrides disabled) in a child `pwsh`, carrying the Check 21 and Check 23 probes. Four guard executions, nine assertions.

EARN IT. The implementation is applied by BLOB IDENTITY from the proven lineage preserved at `backup/spec176-pre-reconcile`, not rewritten: `scripts/check_repository_consistency.ps1` is blob `99ea548` and `scripts/test_future_date_guard.ps1` is blob `e567af1`, the exact objects that carried the original RED/GREEN and mutation evidence. Because the implementation bytes are unchanged, that evidence is reused rather than regenerated — the hostile-culture reproduction, the invariant-culture repair, the RED run against the unfixed guard (5 passed / 4 FAILED on assertions 2, 7, 8, 9 with the oracle-integrity assertion passing in the same run), and the four-mutant causal battery in which restoring each parse site to `$null` failed the matching proof and only that proof. A different base SHA does not stale a causal proof over identical bytes.

The one genuinely new question was whether the proven repair still behaves correctly on the SPEC-177-based canonical state, and it was answered with the smallest existing proof: `scripts/test_future_date_guard.ps1` returned 9 passed, 0 failed, exit 0, including the oracle-integrity assertion confirming the child process really held `ar-SA`/`UmAlQuraCalendar`. The rest of the derived `CONTROL, REPOSITORY` profile is executed once inside the mandatory `-Finish` rather than run separately beforehand.

Defect presence on the canonical base was proven before replay rather than assumed: `scripts/check_repository_consistency.ps1` was blob `57a746c` at both `cd92cb2` and `375a62e`, carrying all four `$null`-provider parse sites, and `SPEC-177` touched `scripts/test_agent_continuity.ps1` only.

Lineage. The approved authority above was first approved on 2026-09-13 under the `SPEC-176` identity, whose three commits were never published and are retained at `backup/spec176-pre-reconcile` (`d5d424c`). That run halted at `MANDATORY_VERIFICATION_FAILED` because `scripts/test_agent_continuity.ps1` scored 151/4 on this CRLF workstation against assertions 150, 152, 153 and 155. `SPEC-177` repaired exactly that defect, so the blocker is not inherited here. The identity could not be reused: `SPEC-177` is `Complete` and terminal and names `SPEC-176` inside its own frozen sections, so the Gate refuses any newly added `changes/SPEC-176-*.md` as `SPEC_ID_ALREADY_USED`. Re-identification was forced, and the frozen authority plus Acceptance Criteria normalize to SHA256 `798fcc06...` against the originally approved text, differing only in the title and the Write Scope self-reference.

Commits: recorded by the implementation commit carrying this entry.

## Verification Notes

None.

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

No new test file is created and `scripts/test_future_date_guard.ps1` is not renamed. No session or performance report is written by this Change Request.

Scope discovery, recorded so a later session does not have to re-derive it. Two further date conversions sit inside these three checks and were deliberately left alone, because both were measured to be culture-robust rather than assumed to be:

- `[datetime]'2026-09-05'`, Check 23's cutoff — PowerShell's cast converts through the invariant culture, and returned the correct Gregorian instant under `ar-SA`.
- `[datetimeoffset]::Parse($newestCommit)`, Check 12's clock sanity — Git's `%aI` output is a full ISO-8601 string with offset, which .NET resolves through its ISO path; it too returned the correct Gregorian instant under `ar-SA`.

Neither is part of the `yyyy-MM-dd` contract this Change Request governs, and neither reproduced a defect, so widening to them would have been unevidenced scope. The clock-sanity line's rendering is corrected under Step 2 because it prints a `yyyy-MM-dd` date.

This Change Request deliberately does not perform a repository-wide culture cleanup. Only the three checks with a reproduced silent fail-open are touched.

Lineage, and why this identity. This contract re-carries, unchanged, the engineering authority approved on 2026-09-13 under the `SPEC-176` identity, whose three commits were executed locally and never published. That identity is now permanently retired and cannot be revived: the terminal contract `changes/SPEC-177-workflow-proof-is-newline-invariant.md` names `SPEC-176` inside its own frozen `Supersedes / Depends On` and `Out of Scope` sections, and the Gate's repository-wide collision rule refuses any newly added `changes/SPEC-176-*.md` with `SPEC_ID_ALREADY_USED`. `CR_LIFECYCLE.md` §4 states that a tracked textual occurrence reserving an identifier is intentional and must not be repaired by a later agent, and `SPEC-177` is `Complete`, so its text may never be edited to release the number. Re-identification is therefore the only legal carrier, not a preference. Every frozen section above is byte-identical to the approved `SPEC-176` text apart from the single Write Scope self-reference.

The defect was re-verified against the new canonical base rather than assumed to persist. `scripts/check_repository_consistency.ps1` is blob `57a746c` both at `cd92cb2` — the SHA the Business Reason measured against — and at `375a62e`, and `scripts/test_future_date_guard.ps1` is likewise unchanged, so the four `$null`-provider parse sites and every measurement recorded above transfer to this base by object identity. `SPEC-177` changed `scripts/test_agent_continuity.ps1` only and shares no implementation file with this contract.

The 2026-09-13 run under the retired identity halted at `MANDATORY_VERIFICATION_FAILED`, because `scripts/test_agent_continuity.ps1` reported 151 passed / 4 failed on this CRLF workstation against assertions 150, 152, 153 and 155. That blocker is not inherited here: it was a defect in the control evidence layer, `SPEC-177` repaired exactly it, and the repair is present in the base this contract is authored against.
