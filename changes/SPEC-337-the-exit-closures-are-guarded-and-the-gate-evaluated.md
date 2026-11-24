# Change Request — SPEC-337

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Guard the two closures that the `B6-EXIT` gate evaluation found standing without a guard, and record the gate evaluation honestly at 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0. Check 30 freezes the seven gap-register ids that are rows twice, so a new duplicate id fails and an allowance no longer used fails as stale (GOV-12's class, which recurred after its closure). Check 31 parses every PowerShell script the guard sees and refuses an `exit` with no code (SYNC-2's class). `**/*.ps1` joins both trigger lists of the repository-consistency workflow and Check 20's required triggers. The register records GOV-27, and the plan records the EC-5 function-body probe, EC-6 to EC-10 met at the gate evaluation, and `B6-EXIT` still `NOT REACHED` because EC-5 stays partial.

## Business Reason

EC-7 asks that no finding be closed without a guard. The re-measure at 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0 found two: GOV-12 closed on 2026-09-04 with no guard, and MEAS-2's second row is dated 2026-09-07, so the class has already recurred; SYNC-2 closed on 2026-09-09 with no regression test. The constitution guards a proven repeat at source (DEC-33 rule 12) in one native control (rule 6), and both checks fit the existing guard at the smallest cost (rule 3). The gate evaluation must be recorded where the gate is kept, with each reading measured, so the next agent finds the true state (rule 11): five exit criteria are met as measured and EC-5 is not, so `B6-EXIT` is not reached and no criterion is marked met beyond its evidence.

## Risks

A new guard check that misfires blocks every later contract. Both checks are measured clean on the candidate tree, decide by id or by the parsed syntax tree alone, and are proven in both directions by the status-contradiction suite. A frozen allowance could hide a real duplicate among the seven; it records the present state, cannot grow and fails as stale when one is resolved. A script that fails to parse is reported, never skipped. Adding `**/*.ps1` runs the repository guard on more pushes; it costs CI minutes, not correctness. No product code, migration, database object, API or Primary state changes.

## Supersedes / Depends On

None. Extends GOV-12 (FIXED 2026-09-04) and SYNC-2 (FIXED 2026-09-09), which are closed and immutable, and the gate readings SPEC-336 carried.

## Write Scope

- `changes/SPEC-337-the-exit-closures-are-guarded-and-the-gate-evaluated.md`
- `.github/workflows/repository-consistency.yml`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_agent_continuity.ps1`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `.github/workflows/agent-control.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`

Migrations, tests under `supabase/`, product code, the repair of any EC-5 survivor, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9 and `ENGINEERING_METHOD.md` section 2.
- `scripts/check_repository_consistency.ps1` Checks 20 and 29.
- `scripts/test_status_contradiction_guard.ps1` the slice-11 sandbox block.
- `reports/master/MASTER_GAP_REGISTER.md` GOV-12 and SYNC-2.
- `reports/master/MASTER_EXECUTION_PLAN.md` the exit criteria EC-1 to EC-11 and the gate table.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Two checks appended to the existing guard after Check 29, one trigger added to the workflow's push and pull-request path lists and to Check 20's required triggers, five scenarios appended to the status-contradiction suite in its own tracked-tree sandbox, one register row, and the plan's evidence paragraph, exit readings and bundle paragraph. Each file is written by its own literal step and bound by its exact Git blob.

Pass 2 Adversarial Review: Check 30 reads only table rows with at least twelve cells and an id-shaped first cell, so the three-cell tables and prose never count. The suite's helper refuses any run that never reached Check 31, so a guard that dies early cannot pass a negative case by printing nothing. The bare-exit fixture is a new script in the sandbox, not an edit of a real one, and its positive twin `exit 1` must be accepted. Check 20 now requires `**/*.ps1` in both trigger lists, so dropping the trigger later fails the guard. The plan text marks EC-6, EC-7, EC-8 and EC-10 met only with their measured evidence and keeps EC-5 partial.

Pass 3 Evidence Refresh: 2026-11-24. On the candidate tree (5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0 plus steps 1 to 5), native repository consistency was CLEAN with Check 30 reading 447 register ids and Check 31 reading 50 scripts, and the five guard suites the hosted workflow runs passed locally under code page 65001 (status contradiction 38 of 38, future date 19 of 19, primary ledger 13 of 13, cold start 42 of 42, readiness self-test 33 of 33).

Selected Version: SPEC-337; selected: two checks in the existing repository guard (a frozen duplicate-id allowance that can only shrink, and a parsed bare-exit refusal), proven by the existing status-contradiction suite, plus the honest gate reading, the smallest change that guards both closures EC-7 found unguarded

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Checks 30 and 31 | Every later contract's native Finish and the hosted Repository Consistency run | WRITE | CLEAN on the candidate tree; each check proven in both directions by the suite. |
| `**/*.ps1` trigger | `.github/workflows/repository-consistency.yml` push and pull-request filters and Check 20 | WRITE | Check 20 requires it in both lists; no other workflow changes. |
| GOV-27 register row | Checks 22, 24 and 25 and the register readers | WRITE | FIXED with its closing contract; the duplicate allowance is unchanged by the new id. |
| Exit readings and gate table | `B6-EXIT` gate readers and Check 29 | WRITE | `B6-EXIT` stays NEXT; EC-5 stays partial. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |
| Native lifecycle metadata | Active Change Request, Last Completed and discovery projections | WRITE | Native lifecycle synchronization only. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Approved source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Repository consistency CLEAN with Checks 30 and 31 and all five hosted guard suites pass | BEFORE_COMPLETION | NONE | NONE | 6 |
| Matching native verification evidence | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `scripts/check_repository_consistency.ps1`, run by the hosted Repository Consistency workflow and by every native Finish, and its guard-of-the-guard suite `scripts/test_status_contradiction_guard.ps1`, which already copies the tracked tree into a temporary sandbox and attacks the guard there; this change adds two checks to that guard and five scenarios to that suite, and no new control.

Added Property: A gap-register id may be a row more than once only if it is one of the seven frozen at 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0, each exactly twice, and the allowance can only shrink; no PowerShell script the guard sees may exit without a code, and a script that does not parse is refused.

Causal Negative: GOV-12 closed on 2026-09-04 with no guard and MEAS-2's second row is dated 2026-09-07, so a duplicate id was added after the closure and nothing refused it; at 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0 the guard accepts a second row of any id. SYNC-2's bare `exit` reported SUCCESS over a failed push, and at 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0 the guard accepts a new bare `exit`.

Positive Test Design: The unmutated tracked tree passes Checks 30 and 31 with no defect line; a sandbox script ending in `exit 1` is accepted.

Negative Test Design: A second RBAC-5 row fails Check 30 as a new duplicate; removing one of MEAS-2's two rows fails Check 30 as a stale allowance; a sandbox script ending in a bare `exit` fails Check 31 at its exact line.

Non-Empty Population Obligation: The suite asserts the RBAC-5 row exists exactly once and MEAS-2 exactly twice before each mutation, and the helper requires the Check 31 header in every run; Check 30 reads 447 ids and Check 31 reads 50 scripts on the candidate tree.

Mutation Obligation: Removing Check 30 from the guard must turn both ID MUTATION scenarios red, and removing Check 31 must turn every scenario red through the helper's header requirement.

Post-Implementation Proof Obligation: The native Finish runs the repository guard and all five hosted guard suites through Additional Verification with zero failures, and the hosted Repository Consistency and ORVION Acceptance preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `.github/workflows/repository-consistency.yml` contains `# Check 31 (SYNC-2, SPEC-337) parses every PowerShell script for a bare exit.`; if so record Already Applied when its Git blob is 328b1206bae0983f445df0a0f297a2473015f158, and otherwise stop and report. Otherwise make exactly these 2 edits (every PowerShell script triggers the repository guard), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
     push:
       paths:
         - "**/*.md"
   ```
   insert
   ```text
         # Check 31 (SYNC-2, SPEC-337) parses every PowerShell script for a bare exit.
         - "**/*.ps1"
   ```

   b) immediately after the lines
   ```text
       # parses the two blocks separately and compares them.
       paths:
         - "**/*.md"
   ```
   insert
   ```text
         - "**/*.ps1"
   ```

   The resulting file's Git blob is 328b1206bae0983f445df0a0f297a2473015f158.

2. Check whether `scripts/check_repository_consistency.ps1` contains `== Check 31: no PowerShell script exits with a bare exit (SYNC-2) ==`; if so record Already Applied when its Git blob is c71c4f67fe55b89e0e111bd17caa59c1bd0c6fca, and otherwise stop and report. Otherwise make exactly these 2 edits (Checks 30 and 31 and the Check 20 trigger), each matched once, and change nothing else:

   a) immediately after the line
   ```text
           'scripts/generate-ai-map.ps1'                 = 'Check 7 (SPEC-270) executes it to reproduce ai-map.json and repository-index.md'
   ```
   insert
   ```text
           '**/*.ps1'                                    = 'Check 31 (SYNC-2) parses every PowerShell script'
   ```

   b) immediately after the lines
   ```text
           $issues += [Math]::Max(1, $registryProblems.Count)
       }
   }
   ```
   insert
   ```text

   Write-Host ""
   Write-Host "== Check 30: no new duplicate finding id in the gap register (GOV-12) ==" -ForegroundColor Cyan
   # GOV-12 (2026-09-04) closed one id recorded twice with "no guard added", reasoning that a title
   # heuristic would misfire. The class recurred: MEAS-2's second row is dated 2026-09-07. Measured at
   # 5f9c2f8 (SPEC-337): exactly seven ids are register rows twice. Deciding by id alone needs no
   # heuristic: the duplicated set must equal the frozen allowance below, each exactly twice. A new
   # duplicate fails; an allowed id no longer duplicated fails as stale, so the allowance only shrinks.
   $dupRegister = Join-Path $RepoRoot 'reports/master/MASTER_GAP_REGISTER.md'
   $dupAllowed = [ordered]@{ 'ATTR-1' = 2; 'CAT-5' = 2; 'DOC-1' = 2; 'FIN-1' = 2; 'MEAS-2' = 2; 'SEC-3' = 2; 'SUP-1' = 2 }
   if (-not (Test-Path $dupRegister)) {
       Write-Host "  MISSING: reports/master/MASTER_GAP_REGISTER.md" -ForegroundColor Red
       $issues++
   } else {
       $dupSeen = @{}
       $dupLines = [IO.File]::ReadAllLines($dupRegister)
       for ($i = 0; $i -lt $dupLines.Count; $i++) {
           if ($dupLines[$i] -notmatch '^\|') { continue }
           $cells = @($dupLines[$i] -split '(?<!\\)\|')
           if (($cells.Count - 2) -lt 12) { continue }
           $id = $cells[1].Trim() -replace '^\*\*|\*\*$', ''
           if ($id -cnotmatch '^[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d+[a-z]?$') { continue }
           if (-not $dupSeen.ContainsKey($id)) { $dupSeen[$id] = [System.Collections.Generic.List[int]]::new() }
           $dupSeen[$id].Add($i + 1)
       }
       $dupIssues = 0
       foreach ($id in @($dupSeen.Keys | Sort-Object)) {
           $n = $dupSeen[$id].Count
           if ($n -gt 1 -and $dupAllowed[$id] -ne $n) {
               Write-Host "  DUPLICATE REGISTER ID: $id is a register row $n times (lines $($dupSeen[$id] -join ', ')) -- give the new finding its own id" -ForegroundColor Red
               $dupIssues++
           }
       }
       foreach ($id in $dupAllowed.Keys) {
           $n = if ($dupSeen.ContainsKey($id)) { $dupSeen[$id].Count } else { 0 }
           if ($n -lt $dupAllowed[$id]) {
               Write-Host "  STALE DUPLICATE ALLOWANCE: $id is a register row $n time(s), allowed $($dupAllowed[$id]) -- remove it from Check 30's allowance" -ForegroundColor Red
               $dupIssues++
           }
       }
       if ($dupIssues -eq 0) { Write-Host "  $($dupSeen.Count) register ids, no duplicate beyond the frozen $($dupAllowed.Count)" -ForegroundColor Green }
       $issues += $dupIssues
   }

   Write-Host ""
   Write-Host "== Check 31: no PowerShell script exits with a bare exit (SYNC-2) ==" -ForegroundColor Cyan
   # SYNC-2 (2026-09-09): repository-all.ps1 reported SUCCESS over a failed push because every failure
   # path used a bare `exit`, which returns 0 when the last native command succeeded. The fix was not
   # guarded (its row says so). Measured at 5f9c2f8 (SPEC-337): 0 bare exits in 50 scripts. This check
   # parses every .ps1 the guard sees and refuses an exit statement without a value.
   $exitScripts = @($allFiles | Where-Object { $_.Extension -eq '.ps1' })
   $exitIssues = 0
   foreach ($f in $exitScripts) {
       $rel = $f.FullName.Substring($RepoRoot.Length + 1)
       $perr = $null
       $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$perr)
       if ($perr -and $perr.Count) {
           Write-Host "  UNPARSEABLE SCRIPT: $rel -- $($perr[0].Message)" -ForegroundColor Red
           $exitIssues++
           continue
       }
       foreach ($x in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] -and -not $n.Pipeline }, $true)) {
           Write-Host "  BARE EXIT: ${rel}:$($x.Extent.StartLineNumber) -- returns 0 after a successful native command; give it a code" -ForegroundColor Red
           $exitIssues++
       }
   }
   if ($exitIssues -eq 0) { Write-Host "  $($exitScripts.Count) scripts, no bare exit" -ForegroundColor Green }
   $issues += $exitIssues

   ```

   The resulting file's Git blob is c71c4f67fe55b89e0e111bd17caa59c1bd0c6fca.

3. Check whether `scripts/test_status_contradiction_guard.ps1` contains `# SPEC-337: Check 30 (GOV-12, duplicate register ids) and Check 31 (SYNC-2, bare exit), both directions.`; if so record Already Applied when its Git blob is 4ddf0f567f7d5b4b7fe249254e4f71b0de302912, and otherwise stop and report. Otherwise make exactly this one edit (the Check 30 and Check 31 scenarios), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
       if ($sandboxRoot -and $sandboxRoot -eq [IO.Path]::GetFullPath($d)) { Remove-Item -LiteralPath $sandboxRoot -Recurse -Force }
   }

   ```
   insert
   ```text
   # SPEC-337: Check 30 (GOV-12, duplicate register ids) and Check 31 (SYNC-2, bare exit), both directions.
   # The helper refuses a run that never reached Check 31, so "no hit" cannot mean "the guard died first".
   # Check 3 stops a reports-only copy, so the tracked tree is copied, as in the slice-11 block above.
   $d = New-Sandbox
   try {
       $sandboxRoot = [IO.Path]::GetFullPath($d)
       if (-not $sandboxRoot.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { throw 'Sandbox escaped temp root' }
       foreach ($relative in (git -C $repoRoot ls-files)) {
           $destination = Join-Path $sandboxRoot $relative
           New-Item -ItemType Directory -Force (Split-Path -Parent $destination) | Out-Null
           Copy-Item -LiteralPath (Join-Path $repoRoot $relative) -Destination $destination
       }
       function Get-IdExitDefects {
           $out = & pwsh -NoProfile -File $guard -RepoRoot $d 2>&1 | Out-String
           if ($out -notmatch '== Check 31:') { throw "Guard failed before Check 31 completed: $out" }
           @($out -split "`n" | Where-Object { $_ -cmatch 'DUPLICATE REGISTER ID:|STALE DUPLICATE ALLOWANCE:|BARE EXIT:|UNPARSEABLE SCRIPT:' })
       }
       $path = Join-Path $d 'reports/master/MASTER_GAP_REGISTER.md'
       $original = [IO.File]::ReadAllLines($path)
       $clean = Get-IdExitDefects
       Check 'ID/EXIT CONTROL: the frozen duplicates and the real scripts are accepted' ($clean.Count -eq 0) ($clean -join ' | ')
       $row = @($original | Where-Object { $_ -like '| RBAC-5 |*' })
       [IO.File]::WriteAllLines($path, [string[]]($original + $row))
       $hits = Get-IdExitDefects
       Check 'ID MUTATION: a second RBAC-5 row is a new duplicate' ($row.Count -eq 1 -and @($hits -cmatch 'DUPLICATE REGISTER ID: RBAC-5 ').Count -eq 1) ($hits -join ' | ')
       $meas = @(for ($i = 0; $i -lt $original.Count; $i++) { if ($original[$i] -like '| MEAS-2 |*') { $i } })
       [IO.File]::WriteAllLines($path, [string[]]@(for ($i = 0; $i -lt $original.Count; $i++) { if ($i -ne $meas[-1]) { $original[$i] } }))
       $hits = Get-IdExitDefects
       Check 'ID MUTATION: an allowed duplicate reduced to one row is a stale allowance' ($meas.Count -eq 2 -and @($hits -cmatch 'STALE DUPLICATE ALLOWANCE: MEAS-2 ').Count -eq 1) ($hits -join ' | ')
       [IO.File]::WriteAllLines($path, $original)
       $probe = Join-Path $d 'scripts/probe.ps1'
       New-Item -ItemType Directory -Force (Split-Path -Parent $probe) | Out-Null
       [IO.File]::WriteAllText($probe, "if (`$args.Count) { Write-Host 'x' }`nexit`n")
       $hits = Get-IdExitDefects
       Check 'EXIT MUTATION: a bare exit is refused' (@($hits -cmatch 'BARE EXIT: scripts[\\/]probe\.ps1:2 ').Count -eq 1) ($hits -join ' | ')
       [IO.File]::WriteAllText($probe, "if (`$args.Count) { Write-Host 'x' }`nexit 1`n")
       $hits = Get-IdExitDefects
       Check 'EXIT CONTROL: an exit with a code is accepted' ($hits.Count -eq 0) ($hits -join ' | ')
   } finally {
       if ($sandboxRoot -and $sandboxRoot -eq [IO.Path]::GetFullPath($d)) { Remove-Item -LiteralPath $sandboxRoot -Recurse -Force }
   }

   ```

   The resulting file's Git blob is 4ddf0f567f7d5b4b7fe249254e4f71b0de302912.

4. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| GOV-27 |`; if so record Already Applied when its Git blob is 76bf1acac532c7e5f783b183fabc36de2791b728, and otherwise stop and report. Otherwise make exactly these 2 edits (GOV-27 registered FIXED), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-23 (CRM SPEC-335 registers DOC-11, QUO-11, QUO-12 and BOOK-13 from the `documents`/`quotations` re-sweep and the caller-writable creation stamps, each pinned OPEN by Test 194, records STAMP-1 as an accepted residual, corrects BRANCH-2's sentence on `created_at`, and records CTRL-19 as an accepted residual by the owner's decision of 2026-11-23.)
   ```
   with
   ```text
   Last updated: 2026-11-24 (CRM SPEC-337 registers GOV-27, FIXED: Check 30 refuses a new duplicate register id beyond the frozen seven, and Check 31 refuses a bare `exit` in a tracked PowerShell script, so EC-7's two closures without a guard are guarded.)

   Previously: 2026-11-23 (CRM SPEC-335 registers DOC-11, QUO-11, QUO-12 and BOOK-13 from the `documents`/`quotations` re-sweep and the caller-writable creation stamps, each pinned OPEN by Test 194, records STAMP-1 as an accepted residual, corrects BRANCH-2's sentence on `created_at`, and records CTRL-19 as an accepted residual by the owner's decision of 2026-11-23.)
   ```

   b) immediately after the line
   ```text
   | GOV-26 | **Fresh agents did not apply the sandbox's isolation rule or the measure-before-freezing rule, although both were documented** | governance / agent conduct | Medium | R | — | — | ✅ | **✅ FIXED 2026-10-13 (SPEC-275).** **OBSERVED, not inferred:** seven isolated, read-only cold-start agents each received one neutrally worded ORVION task (a trivial label change, an existing guard, a toolchain upgrade, an external action version, an RLS review, a framework rewrite, an `APPROVAL_EVIDENCE: PASS` question). All seven applied the four decision rules. They kept a trivial change minimal, reused Check 7 instead of duplicating it, found the "newest" Supabase CLI already pinned, checked `actions/checkout` at its source, demanded the missing negative RLS paths, rejected an unearned framework, and said a PASS proves structure, not truth. Two documented rules did not reach them. Three of the four that planned an experiment chose a `git worktree`, which shares refs and config and which `ENGINEERING_METHOD.md` §2 excludes. One of those would have run `db reset` in it on the shared local stack. The trivial-change agent would have frozen a contract without measuring its mandatory commands (§3), and those commands fail on this workstation today (OPS-5). The rules lived in §2 and §3. The agents read `AGENTS.md` §1's pointer ("a disposable sandbox … outside the authoritative repository"), and only one read §2 through. **Repaired at the two points of decision, with nothing added to the method and no gate or check added.** `AGENTS.md` §1's sentence now carries §2's isolation principle, isolating whatever the experiment can change: commits in a fresh clone with push disabled, because a worktree shares refs and config, and database work on its own Supabase project id and ports, never the shared local stack. It also carries the measurement rule for every Draft, however small, running a command that can change shared state only in such a sandbox and asking before running one that cannot be isolated, so measuring never licenses provisioning the owner's machine (OPS-6). `changes/TEMPLATE.md`'s existing Pre-Approval Evidence pointer now names §2's closing paragraph. Fresh agents re-ran the failing scenarios on the repaired text; the results, including any residual, are recorded in SPEC-275 | — | SPEC-275 | 10-13 | 10-13 |
   ```
   insert
   ```text
   | GOV-27 | **Two closures stood without a guard, and one class had already recurred: duplicate register ids (GOV-12) and the bare `exit` (SYNC-2)** | governance / guard coverage | Low | R | 6 | — | ✅ | **✅ FIXED (SPEC-337).** MEASURED at `5f9c2f8` for EC-7: the register carries 446 distinct ids in table rows, and exactly seven are rows twice (ATTR-1, CAT-5, DOC-1, FIN-1, MEAS-2, SEC-3, SUP-1). GOV-12 closed on 2026-09-04 with no guard, and MEAS-2's second row is dated 2026-09-07, so the class recurred after its closure. SYNC-2 closed on 2026-09-09 with no regression test; its parsed measure finds no bare `exit` in the 50 tracked scripts today. Check 30 freezes the seven duplicates at exactly two rows each: a new duplicate fails, and an allowed id that is no longer duplicated fails as stale, so the allowance can only shrink. Check 31 parses every tracked `.ps1` and refuses an `exit` with no code; `**/*.ps1` joins both trigger lists and Check 20's required triggers. `scripts/test_status_contradiction_guard.ps1` proves a clean control, a new duplicate, a stale allowance, a bare `exit` refused and `exit 1` accepted | — | SPEC-337 | 11-24 | 11-24 |
   ```

   The resulting file's Git blob is 76bf1acac532c7e5f783b183fabc36de2791b728.

5. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `**Recorded exception, 2026-11-24, CRM exit bundle K.**`; if so record Already Applied when its Git blob is 7ff2cce501247a9cdc8db5b9de1a83884fbe1014, and otherwise stop and report. Otherwise make exactly these 4 edits (the gate evaluation readings), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-23 (CRM exit bundle J, SPEC-335. An EC-5 extension probe at `676df3e` removes each of the 301 foreign keys, 125 RLS policies, 78 RLS switches and 121 triggers without RAISE; Test 193 pins the 302 removals no test caught. The `documents`/`quotations` re-sweep and the caller-writable creation stamps register DOC-11, QUO-11, QUO-12 and BOOK-13, each pinned OPEN by Test 194, and STAMP-1 as an accepted residual. Test 192 pins the customer locks of CUST-10 and CUST-12, the two repairs the EC-7 cross-check found with no CI guard. FIN-9 and CTRL-11 are re-checked against Primary. The owner declined CTRL-19's repair on 2026-11-23, so CTRL-19 is an owner-accepted residual.)
   ```
   with
   ```text
   Last updated: 2026-11-24 (CRM exit bundle K, SPEC-337. The gate evaluation at `5f9c2f8` measures EC-6, EC-7, EC-8, EC-9 and EC-10 met, EC-10 with CTRL-19 as the owner-accepted residual. Check 30 freezes the seven register ids that are rows twice and registers GOV-27, and Check 31 refuses a bare `exit` in any PowerShell script, so GOV-12 and SYNC-2 are guarded. An EC-5 function-body probe lowers each of the 548 refusing RAISE statements in the 153 plpgsql functions to NOTICE, one at a time: 188 fail a test that names the function or its table and 360 do not, so EC-5 stays partial and `B6-EXIT` is not reached.)

   Previously: 2026-11-23 (CRM exit bundle J, SPEC-335. An EC-5 extension probe at `676df3e` removes each of the 301 foreign keys, 125 RLS policies, 78 RLS switches and 121 triggers without RAISE; Test 193 pins the 302 removals no test caught. The `documents`/`quotations` re-sweep and the caller-writable creation stamps register DOC-11, QUO-11, QUO-12 and BOOK-13, each pinned OPEN by Test 194, and STAMP-1 as an accepted residual. Test 192 pins the customer locks of CUST-10 and CUST-12, the two repairs the EC-7 cross-check found with no CI guard. FIN-9 and CTRL-11 are re-checked against Primary. The owner declined CTRL-19's repair on 2026-11-23, so CTRL-19 is an owner-accepted residual.)
   ```

   b) replace the line
   ```text
   **CRM exit evidence at `676df3e`, measured 2026-11-23 (SPEC-335, Tests 192, 193 and 194; SPEC-334, Tests 190 and 191; SPEC-333, Test 189; SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```
   with
   ```text
   **CRM exit evidence at `5f9c2f8`, measured 2026-11-24 (SPEC-337, Checks 30 and 31; SPEC-336, which carries the Cancelled SPEC-335's Tests 192, 193 and 194 unchanged; SPEC-334, Tests 190 and 191; SPEC-333, Test 189; SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven at `5f9c2f8` by `check_database_parity.ps1` with every value read from Primary: repository, local stack and Primary agree at 277 migrations (ledger `7d224a770526c87f171b9525b0817701`, logic `ca519b79e522cff13cd309456f618a14` over 358 functions, structure `0bb1e5b10e0bde5bd344f706366150ee` over 3204 rows), `DATABASE PARITY: CLEAN`.
   ```

   c) replace the lines
   ```text
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. RFD-3 and the PAY-5/FIN-11 unit are fixed by SPEC-326 (Test 184), PAY-4 by SPEC-327 (Test 185), and JE-2 is contained fail-closed by SPEC-327 (Tests 145/185). PAY-9 keeps `FIRST-BOOKING` and DC-11 keeps the finance model; each is classified at its own boundary. SPEC-334 runs a removal-mutation probe at `8a43a53`: it drops each of the 144 check and unique constraints and 33 unique indexes and disables each of the 216 RAISE-bearing row triggers, one at a time, and runs the pgTAP files that name the table. 28 drops are refused because a foreign key depends on the key. Of the 365 valid mutants, 278 fail a test; the 83 caught only by the trigger catalog of Test 187 run one of eight shared functions that a behavioural test runs on another table. Of the 87 survivors, Test 190 refuses 72 by constraint name and Test 191 refuses 13 by trigger message, and removing each fails its own assertion; 2 are equivalent (implied by another check and by the primary key). SPEC-335 extends the probe at `676df3e`: it drops each of the 301 foreign keys, 125 RLS policies and 121 triggers without RAISE, and disables RLS on each of the 78 tables that enable it, one at a time. 300 of the 625 removals fail a file that names the table, and 23 more fail a catalog-wide file (Tests 01, 83, 102 and 187). Test 193 pins the 302 survivors (244 foreign keys, 22 permissive policies and 36 `updated_at` triggers) by presence and definition, and removing each of them fails it. It pins presence, not behaviour, and function bodies are not mutated, so EC-5 stays partial.
   - **EC-6 (partial):** Check 24 admits the recorded adversarial labels. SPEC-333 sweeps the 101 member-writable doors at `2f8c19a` (52 INSERT, 49 UPDATE, no DELETE): exactly one, UPDATE on `customer_contact_methods`, had no test writing through it, and Test 189 is its targeted negative test across seven controls. SPEC-334 grades the negative side: each of the 101 doors has a refusal assertion writing through it (99 by `throws_*` statement text, 2 by inspection: Tests 47, 131 and 152 read back an RLS-silent UPDATE on `subscription_payment_proofs`, and Test 182 refuses a passengers INSERT built with `format`), and so does each of the 78 surfaces (74 by text, 4 by inspection: Tests 181, 175 and 66). The sweep grades existence; whether each negative test is the strongest case for its door stays with the gate evaluation. SPEC-335 moves `documents` and `quotations` to `AUDITED-OPEN`; retain the existing evaluation and delivery trigger for the one partial surface, `offline_conversions`. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision.
   - **EC-7 (ceilings closed; closures cross-checked at the gate evaluation):** Existing member repairs carry permanent tests. Test 187 turns the four numeric ceilings with slack into named memberships: Test 07 `<= 42` is the 39 event codes no function or trigger emits, and Test 10 `<= 56`, `<= 20` and `<= 3` are the 52 member-insertable tables, the 5 of them without a capability trigger and the 2 identity tables without any INSERT capability. Each is a set equality, so a new member fails and a removed one must leave the set. SPEC-335 cross-checks the 338 repair rows of the register at `676df3e`: 140 name their test, 152 are named by a test, 16 name another guard (a CI-run script, check or catalog assertion), and the 30 with none found were read by hand: contract-tooling repairs guarded by the Finish and CI suites, document corrections whose coherence is EC-8's, verified non-defects, and two recorded closures without a guard (SYNC-2, GOV-12). Two concurrency repairs, CUST-10 and CUST-12, were proven only by `scripts/verify_customer_concurrency.py`, which nothing runs. Test 192 pins both locks in the function bodies: removing them fails its 4 assertions while every other test that names either function still passes. The gate evaluation re-measures this.
   - **EC-8 (partial):** Native freshness checks and the reconciled records establish bounded coherence. SPEC-331 resolves two record conflicts: `booking_item_passengers` and `financial_accounts` are AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09 (Tests 104, 113 and 114). OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 now carry settled statuses, and each keeps its superseded text. SPEC-332 re-verifies N1, DC-5, RC-4, R8, B3 and RC-1 against their migrations at `5bed4ed`: Test 188 proves R8/B3 (`202607048800`) and N1 (`202607049100`), which had no test, and DC-5 (`202607054600`; Tests 48, 49, 97, 116, 175), RC-4 Tier A (`202607048900`; Tests 23, 45, 53) and RC-1 (Tests 42, 66, 148) are settled on their existing tests. The register rows carry the settled statuses with their superseded text. SPEC-335 settles the gate-evaluation rows at `676df3e`, re-measured at the evaluation: FIN-9's only ledger writer is `app.create_journal_entry`, locally and on Primary, and CTRL-11 finds every business table of Primary empty, so no non-zero count sits under a `NOT REACHED` boundary; both stay accepted residuals. The `documents`/`quotations` re-sweep registers DOC-11 and QUO-11 (`ENABLE-SURFACE-WORKFLOW`) and QUO-12 (`ENABLE-CRM`); the caller-writable creation stamps register BOOK-13 (`FIRST-BOOKING`: `reporting.sales_activity` and `reporting.my_sales_performance` report them) and STAMP-1, an accepted residual (the other 46 have no deciding reader). Test 194 pins each finding OPEN. BRANCH-2's sentence on `created_at` is corrected.
   - **EC-10 (partial):** Check 20 and SPEC-316 hosted CI establish the guarded inputs and release result. CTRL-19's independent enforcement is an owner-accepted residual (SPEC-335): the owner declined its GitHub configuration repair on 2026-11-23, and every release is promoted by `scripts/promote_main.ps1` from a trusted `main` checkout judged by `-Gate -Trusted`, while the agent's credential still administers the repository. Coverage of any important change class outside that list is still owed and is judged at the gate evaluation.
   ```
   with
   ```text
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. RFD-3 and the PAY-5/FIN-11 unit are fixed by SPEC-326 (Test 184), PAY-4 by SPEC-327 (Test 185), and JE-2 is contained fail-closed by SPEC-327 (Tests 145/185). PAY-9 keeps `FIRST-BOOKING` and DC-11 keeps the finance model; each is classified at its own boundary. SPEC-334 runs a removal-mutation probe at `8a43a53`: it drops each of the 144 check and unique constraints and 33 unique indexes and disables each of the 216 RAISE-bearing row triggers, one at a time, and runs the pgTAP files that name the table. 28 drops are refused because a foreign key depends on the key. Of the 365 valid mutants, 278 fail a test; the 83 caught only by the trigger catalog of Test 187 run one of eight shared functions that a behavioural test runs on another table. Of the 87 survivors, Test 190 refuses 72 by constraint name and Test 191 refuses 13 by trigger message, and removing each fails its own assertion; 2 are equivalent (implied by another check and by the primary key). SPEC-335 extends the probe at `676df3e`: it drops each of the 301 foreign keys, 125 RLS policies and 121 triggers without RAISE, and disables RLS on each of the 78 tables that enable it, one at a time. 300 of the 625 removals fail a file that names the table, and 23 more fail a catalog-wide file (Tests 01, 83, 102 and 187). Test 193 pins the 302 survivors (244 foreign keys, 22 permissive policies and 36 `updated_at` triggers) by presence and definition, and removing each of them fails it. It pins presence, not behaviour. SPEC-337 mutates function bodies at `5f9c2f8`: it lowers each of the 548 refusing RAISE statements (level EXCEPTION, explicit or default) in the 153 plpgsql functions of `public`, `app` and `reporting` to NOTICE, one at a time, and runs every pgTAP file that names the function or a table its trigger fires on. 188 of the 548 fail a test; 360 do not. A second pass runs every eighth survivor (45) against every other pgTAP file; none fails, so the survivors are not caught elsewhere. A refusal no test can see is not proven, so EC-5 stays partial until behavioural refusal tests cover the survivors.
   - **EC-6 (met at the gate evaluation):** Check 24 admits the recorded adversarial labels. SPEC-333 sweeps the 101 member-writable doors at `2f8c19a` (52 INSERT, 49 UPDATE, no DELETE): exactly one, UPDATE on `customer_contact_methods`, had no test writing through it, and Test 189 is its targeted negative test across seven controls. SPEC-334 grades the negative side: each of the 101 doors has a refusal assertion writing through it (99 by `throws_*` statement text, 2 by inspection: Tests 47, 131 and 152 read back an RLS-silent UPDATE on `subscription_payment_proofs`, and Test 182 refuses a passengers INSERT built with `format`), and so does each of the 78 surfaces (74 by text, 4 by inspection: Tests 181, 175 and 66). The sweep grades existence; whether each negative test is the strongest case for its door stays with the gate evaluation. SPEC-335 moves `documents` and `quotations` to `AUDITED-OPEN`; retain the existing evaluation and delivery trigger for the one partial surface, `offline_conversions`. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision. The gate evaluation (SPEC-337) decides it for `offline_conversions`: its delivery proof belongs to `ENABLE-CONVERSION-DELIVERY`, whose prerequisite, the Phase 8 workflow, is neither built nor authorized before `B6-EXIT`, so that proof does not hold `B6-EXIT`. Until then no transport exists that could send a row, and Tests 09, 119 and 143 cover the lease, the provenance and send-only-on-success. The exit text asks for at least one negative test on every sensitive surface; SPEC-334's grade finds one for all 78 surfaces and all 101 doors, so EC-6 is met. A stronger case per door is not an exit requirement.
   - **EC-7 (met at the gate evaluation):** Existing member repairs carry permanent tests. Test 187 turns the four numeric ceilings with slack into named memberships: Test 07 `<= 42` is the 39 event codes no function or trigger emits, and Test 10 `<= 56`, `<= 20` and `<= 3` are the 52 member-insertable tables, the 5 of them without a capability trigger and the 2 identity tables without any INSERT capability. Each is a set equality, so a new member fails and a removed one must leave the set. SPEC-335 cross-checks the 338 repair rows of the register at `676df3e`: 140 name their test, 152 are named by a test, 16 name another guard (a CI-run script, check or catalog assertion), and the 30 with none found were read by hand: contract-tooling repairs guarded by the Finish and CI suites, document corrections whose coherence is EC-8's, verified non-defects, and two recorded closures without a guard (SYNC-2, GOV-12). Two concurrency repairs, CUST-10 and CUST-12, were proven only by `scripts/verify_customer_concurrency.py`, which nothing runs. Test 192 pins both locks in the function bodies: removing them fails its 4 assertions while every other test that names either function still passes. The gate evaluation re-measures this. SPEC-337 guards the two closures without one: Check 30 (GOV-27, GOV-12's class) freezes the seven register ids that appear twice, so a new duplicate fails and an allowance no longer used fails as stale, and Check 31 (SYNC-2) refuses a bare `exit` in any guarded `.ps1`, with `**/*.ps1` added to both workflow trigger lists and to Check 20. The status-contradiction suite mutates each. No closed finding is left without a guard and no ceiling can grow, so EC-7 is met.
   - **EC-8 (met at the gate evaluation):** Native freshness checks and the reconciled records establish bounded coherence. SPEC-331 resolves two record conflicts: `booking_item_passengers` and `financial_accounts` are AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09 (Tests 104, 113 and 114). OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 now carry settled statuses, and each keeps its superseded text. SPEC-332 re-verifies N1, DC-5, RC-4, R8, B3 and RC-1 against their migrations at `5bed4ed`: Test 188 proves R8/B3 (`202607048800`) and N1 (`202607049100`), which had no test, and DC-5 (`202607054600`; Tests 48, 49, 97, 116, 175), RC-4 Tier A (`202607048900`; Tests 23, 45, 53) and RC-1 (Tests 42, 66, 148) are settled on their existing tests. The register rows carry the settled statuses with their superseded text. SPEC-335 settles the gate-evaluation rows at `676df3e`, re-measured at the evaluation: FIN-9's only ledger writer is `app.create_journal_entry`, locally and on Primary, and CTRL-11 finds every business table of Primary empty, so no non-zero count sits under a `NOT REACHED` boundary; both stay accepted residuals. The `documents`/`quotations` re-sweep registers DOC-11 and QUO-11 (`ENABLE-SURFACE-WORKFLOW`) and QUO-12 (`ENABLE-CRM`); the caller-writable creation stamps register BOOK-13 (`FIRST-BOOKING`: `reporting.sales_activity` and `reporting.my_sales_performance` report them) and STAMP-1, an accepted residual (the other 46 have no deciding reader). Test 194 pins each finding OPEN. BRANCH-2's sentence on `created_at` is corrected. SPEC-337 corrects the exit-evidence paragraph above, which still cited `676df3e` and 271 migrations after SPEC-336; every other citation of either is historical. Checks 1 to 31 are clean at the SPEC-337 tree, so EC-8 is met as measured.
   - **EC-10 (met at the gate evaluation, with an owner-accepted residual):** Check 20 and SPEC-316 hosted CI establish the guarded inputs and release result. CTRL-19's independent enforcement is an owner-accepted residual (SPEC-335): the owner declined its GitHub configuration repair on 2026-11-23, and every release is promoted by `scripts/promote_main.ps1` from a trusted `main` checkout judged by `-Gate -Trusted`, while the agent's credential still administers the repository. The gate evaluation sweeps all 1093 tracked paths of the SPEC-337 tree against every workflow trigger: 18 sit outside every path filter. The toolchain lock is run by the acceptance lane on every candidate and judged by `promote_main.ps1`; the Edge Function is an evidence-authority path; the two unfiltered workflows run on every push or candidate; the workstation entries derive the WORKSTATION profile; the manual verifiers and the editor and orientation files are not a guarded class. No important change class bypasses its guard, so EC-10 is met with CTRL-19 as the owner-accepted residual.
   ```

   d) immediately after the lines
   ```text
   **Recorded exception, 2026-11-23, CRM exit bundle J.** After CRM SPEC-334 at `676df3e46fffae83366fa4c177a74d327edd6381`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-335 adds Test 192, which pins the two customer locks the EC-7 cross-check found guarded by nothing that runs, Test 193, which pins the presence of the structural controls the extended EC-5 probe found unpinned, and Test 194, which pins DOC-11, QUO-11, QUO-12 and BOOK-13 OPEN. It registers those four findings and STAMP-1 from the `documents`/`quotations` re-sweep, settles the FIN-9 and CTRL-11 gate rows against Primary, and moves `documents`, `quotations` and `booking_items` to `AUDITED-OPEN`. It changes no migration or database object. `B6-EXIT` stays `NOT REACHED` until the gate evaluation re-measures; The owner declined CTRL-19's GitHub configuration repair on 2026-11-23, so SPEC-335 records CTRL-19 as an accepted residual with its containment and reopening trigger, and EC-10 no longer waits on the owner. The Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-24, CRM exit bundle K.** After CRM SPEC-336 at `5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0`, the Batch 6 delegation runs the gate evaluation in the owner's AFK mode. SPEC-337 adds Check 30, which freezes the seven gap-register ids that are rows twice so a new duplicate fails and an unused allowance fails as stale (GOV-27, GOV-12's class), and Check 31, which refuses a bare `exit` in any PowerShell script (SYNC-2), with `**/*.ps1` added to the repository-consistency triggers and to Check 20; the status-contradiction suite attacks both in each direction. It records EC-6, EC-7, EC-8, EC-9 and EC-10 met as measured, EC-10 with CTRL-19 as the owner-accepted residual, and the EC-5 function-body probe. It changes no migration or database object. `B6-EXIT` stays `NOT REACHED` because EC-5 is partial: 360 refusals no test sees remain, and behavioural refusal tests for them follow. The Original and release gates remain enforced.

   ```

   The resulting file's Git blob is 7ff2cce501247a9cdc8db5b9de1a83884fbe1014.

6. **Verify and synchronize.** Run the native repository guard and confirm Checks 30 and 31 report clean. Run the five hosted guard suites named in Additional Verification. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-337: The exit closures are guarded and the gate evaluated.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] Every PowerShell script triggers the repository guard. `check: blob .github/workflows/repository-consistency.yml 328b1206bae0983f445df0a0f297a2473015f158`
- [ ] Checks 30 and 31 and the Check 20 trigger are in the guard. `check: blob scripts/check_repository_consistency.ps1 c71c4f67fe55b89e0e111bd17caa59c1bd0c6fca`
- [ ] The suite attacks Checks 30 and 31 in both directions. `check: blob scripts/test_status_contradiction_guard.ps1 4ddf0f567f7d5b4b7fe249254e4f71b0de302912`
- [ ] The register records GOV-27. `check: blob reports/master/MASTER_GAP_REGISTER.md 76bf1acac532c7e5f783b183fabc36de2791b728`
- [ ] The plan records the gate evaluation with `B6-EXIT` not reached. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 7ff2cce501247a9cdc8db5b9de1a83884fbe1014`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0`
- [ ] The surface disposition is unchanged. `check: same reports/master/MASTER_SURFACE_DISPOSITION.md @5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0`
- [ ] The cold-start guard suite is preserved. `check: same scripts/test_cold_start_state_guard.ps1 @5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0`
- [ ] Repository consistency is CLEAN and all five hosted guard suites pass in the native Finish.

## Execution Log

None.


### 2026-11-24 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0 and every source anchor matched there; Draft allocated as 9bd007f and approved as bdaaf18 with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `.github/workflows/repository-consistency.yml` edited exactly as the step states; blob 328b1206bae0983f445df0a0f297a2473015f158 (3 insertions, 0 deletions).
- Step 3 Applied: `scripts/check_repository_consistency.ps1` edited exactly as the step states; blob c71c4f67fe55b89e0e111bd17caa59c1bd0c6fca (70 insertions, 0 deletions).
- Step 4 Applied: `scripts/test_status_contradiction_guard.ps1` edited exactly as the step states; blob 4ddf0f567f7d5b4b7fe249254e4f71b0de302912 (42 insertions, 0 deletions).
- Step 5 Applied: `reports/master/MASTER_GAP_REGISTER.md` edited exactly as the step states; blob 76bf1acac532c7e5f783b183fabc36de2791b728 (4 insertions, 1 deletions).
- Step 6 Applied: `reports/master/MASTER_EXECUTION_PLAN.md` edited exactly as the step states; blob 7ff2cce501247a9cdc8db5b9de1a83884fbe1014 (11 insertions, 7 deletions).
- Step 7 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-24 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-337 only under DEC-02 in the owner AFK Mode (owner-2026-11-23-modes-any-session.txt, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73), continuing Batch 6 under the owner OD-9 decision of 2026-11-22 (SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D) and the owner prompt to continue until the Batch 6 Finish (SHA-256 7D2A8B8F0F209C8538B0D87F133C440DBB620C2577DEAECF8F3D312584C94759); CTRL-19 accepted residual by the owner (owner-2026-11-23-ctrl19-declined.txt, SHA-256 6882D7C5A1E1C71B05EE8AD878DD72100821972811F1E1358CA022623D333124). Exact Draft revision r3 SHA-256 F0BEC5E82D93FF668F94173A2A50EAD4FB8A390EC1FCB8E918D648536932F4BB, Git blob 8b233da8f1ba0d67ca49bd223485f9dbace1c842, CRM baseline 5f9c2f8. Native isolated Approve 8ee0e5f and implement 5fdb89b passed (5 committed blobs verified), the product criterion checks on the sandbox tree passed 10 of 10, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 F28420F0A4C4934D21A0F77742E73DBA33002714A7B12379A47DC26D6A6A097A). Two repository guard checks, one workflow trigger, one guard suite block and records; no migration, no Primary write. Gate 1 only. Immediately before allocation the hash, the Draft blob 8b233da8f1ba0d67ca49bd223485f9dbace1c842, all 5 source anchors, the baseline HEAD 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0 against refreshed origin/main 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 9bd007f. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 5f9c2f8e13e9ad74bc52841d62ea71100a7e5ba0 (SPEC-336 Complete and released; origin/main is the same commit).

Authority: DELEGATED under the owner's AFK Mode, answered by the constitution; never typed by the owner. The owner's words of 2026-11-23, Workbench `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73, make AFK Mode a tool that decides by the project's rules and widens nothing; the owner's words of 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D, direct Batch 6 to finish first; and the owner's words of 2026-11-23, `data/records/batch6/owner-words/owner-2026-11-23-ctrl19-declined.txt`, SHA-256 6882D7C5A1E1C71B05EE8AD878DD72100821972811F1E1358CA022623D333124, accept CTRL-19 as a residual. This contract grants nothing beyond them. The gate evaluation evidence is Workbench `data/records/batch6/exit-bundle-k/` (`ec5-functions/`, `ec7-ids/`, `ec9-parity/`, `ec10-ci/`).

| Path | Baseline Git blob |
| --- | --- |
| `.github/workflows/repository-consistency.yml` | `ed3ef8d8e954c8a2c5710fe44f46eb1f569c7492` |
| `scripts/check_repository_consistency.ps1` | `3e6d2810e03bfac15b96dba3bc46d119d97ad658` |
| `scripts/test_status_contradiction_guard.ps1` | `49e1481d39447666ac39aa82a8ba2baa3194f739` |
| `reports/master/MASTER_GAP_REGISTER.md` | `424d084a30c76058ee2a081004d317f6e2b909c5` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `984a32d852fa86036f357c2761fa7aca6b9474fe` |
