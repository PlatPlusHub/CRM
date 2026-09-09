# ORVION -- the guard-of-the-guard for COLD-START STATE: Checks 10, 14, 16, 20 and 25.
#
# `AGENTS.md §6`: "Attack every new detector with a counterexample before trusting it, in both
# directions: construct a case it must flag and one it must not. A guard that can be satisfied
# without satisfying its invariant is the class the discovery-to-guard loop exists to eliminate."
#
# WHY THIS EXISTS. Three synchronization defects were found on 2026-09-09, and every one of them
# lived inside a check that was printing CLEAN. Each is reproduced here as a mutation, because a
# repair proven only by "the text looks right now" is not proven at all:
#
#   1. COMPETING COLD-START STATE (Check 10). `reports/README.md` carried TWO live-looking
#      current-state declarations. The guard validated the first with `[regex]::Match` and never
#      asked whether it was the only one; the second told a cold-starting agent to read the slice-8
#      report and take `leads` (slice 9) next, three completed slices later.
#
#   2. NARRATIVE OWNER-DECISION CONTAMINATION (Checks 14/16/25). Four checks each scraped finding
#      ids from the WHOLE `Open owner decisions` line, so the sentence EXPLAINING the line donated
#      `GOV-16` -- closed two days earlier -- to the open set. Guard-derived: 11. Actual: 10. The
#      dangerous direction is the quiet one: Check 25 SKIPS every id already on the line, so a
#      narrative mention silently exempts a real decision from ever being surfaced.
#
#   3. REGISTER STATUS READ FROM ONE SUBSTRATE (Checks 14/25). Check 14 read table rows only. 65 of
#      the register's findings have no table row -- 42 of them settled -- so it could not see any of
#      them, which is how a settled GOV-16 sat in its open set. Check 25 read a DIFFERENT vocabulary,
#      UNANCHORED, so `**OPEN - ... deliberately NOT FIXED**` read as settled on the substring FIXED.
#
# Two further gaps of the same class are pinned here because they were found in the same pass:
#   4. CI TRIGGER ASYMMETRY (Check 20) -- four paths were on `push` and not on `pull_request`, and
#      Check 20 searched the whole FILE for each path, so it could not see which list a line was in.
#   5. FAILURE PROPAGATION (Check 19) -- nothing permanently proved that a non-zero exit from
#      `check_primary_ledger.ps1` makes the parent guard fail. It was checked once, by hand, in 2026-09.
#
# Every scenario runs against a COPY of the git-tracked repository in a temp directory, invoked
# through the guard's own `-RepoRoot`. The real repository is never modified. No database is touched.
# A clean sandbox is CLEAN at exit 0, which is what makes whole-verdict assertions legitimate here.
#
# Run: pwsh -File scripts/test_cold_start_state_guard.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$guard    = Join-Path $PSScriptRoot 'check_repository_consistency.ps1'

$pass = 0; $fail = 0
function Check($name, $condition, $detail = '') {
    if ($condition) { Write-Host "  ok   $name" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  FAIL $name  $detail" -ForegroundColor Red; $script:fail++ }
}

# One sandbox for the whole suite; every mutation restores the file it touched before the next runs,
# and a CONTROL at each end proves the restores actually worked (GOV-4's second-direction lesson).
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("orvion-coldstart-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
$sandbox = [IO.Path]::GetFullPath($sandbox)
if (-not $sandbox.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Sandbox escaped the temp root'
}

$README   = 'reports/README.md'
$MANIFEST = '_ORVION_CANONICAL/manifest.md'
$REGISTER = 'reports/master/MASTER_GAP_REGISTER.md'
$WORKFLOW = '.github/workflows/repository-consistency.yml'
$LEDGER   = 'scripts/check_primary_ledger.ps1'

function S($rel) { Join-Path $sandbox $rel }
function Read-S($rel)        { [IO.File]::ReadAllText((S $rel)) }
function Write-S($rel, $text) { [IO.File]::WriteAllText((S $rel), $text) }

# Runs the REAL guard against the sandbox. `$PSScriptRoot` therefore stays real, so Check 19 reads
# the real (valid) ledger evidence and contributes no noise -- deliberate: this suite is about the
# other checks, and the propagation section below runs the SANDBOX copy precisely so that Check 19's
# delegation can be attacked in isolation.
function Invoke-Guard {
    $out = & pwsh -NoProfile -File $guard -RepoRoot $sandbox 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($out -notmatch '== Check 25:') { throw "Guard did not reach Check 25 -- it failed early:`n$out" }
    return [pscustomobject]@{ Text = $out; Exit = $code }
}
# Restores a file from the real repository, so a mutation can never leak into the next scenario.
function Restore-S($rel) { Copy-Item -LiteralPath (Join-Path $repoRoot $rel) -Destination (S $rel) -Force }

try {
    # `--cached --others --exclude-standard`: the WORKING TREE, not the index. A tracked-files-only
    # copy (`git ls-files` alone) omits a session's brand-new, not-yet-staged session report -- and
    # then Check 10 cannot resolve the pointer that names it, so the CONTROL fails for a reason that
    # has nothing to do with the guard. Caught by the control on the first run after this suite's own
    # session wrote its report, which is exactly what a control is for.
    foreach ($rel in (git -C $repoRoot ls-files --cached --others --exclude-standard)) {
        $src = Join-Path $repoRoot $rel
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }   # deleted-but-tracked
        $dst = Join-Path $sandbox $rel
        New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst
    }

    # =============================================================================================
    Write-Host "`n== CONTROL, FIRST ==" -ForegroundColor Cyan
    # =============================================================================================
    $base = Invoke-Guard
    Check 'CONTROL: an untouched copy of the repository is CLEAN at exit 0' `
        ($base.Exit -eq 0 -and $base.Text -match 'REPOSITORY CONSISTENCY: CLEAN') `
        "exit=$($base.Exit)"
    Check 'CONTROL: Check 10 reports exactly ONE live cold-start declaration' `
        ($base.Text -match 'exactly one live cold-start declaration')
    Check 'CONTROL: the open-decision set is the current ENUMERATION (2)' `
        ($base.Text -match 'checked against 2 open id\(s\)')
    # The regression, stated as a property of the real file rather than of a fixture: the manifest's
    # decision line still MENTIONS a settled id in its prose, and the guard no longer counts it.
    $decLine = ((Read-S $MANIFEST) -split "`n" | Where-Object { $_ -match 'Open owner decisions' } | Select-Object -First 1)
    Check 'CONTROL: settled GOV-16 is absent from the current owner-decision line' `
        ($decLine -notmatch 'GOV-16')
    Check 'CONTROL: RET-1 is settled in the register AND still listed open -- and Check 14 does NOT strike it, because it names a decider' `
        ($base.Text -match 'every manifest owner-decision ID is still open' -and $decLine -match 'RET-1')
    Check 'CONTROL: Check 25 reads BOTH substrates (its population is drawn from table rows and detail blocks)' `
        ($base.Text -match 'findings read across table rows and detail blocks')
    Check 'CONTROL: Check 20 measures both trigger blocks and finds them in agreement' `
        ($base.Text -match 'push \(\d+ paths\) and pull_request \(\d+ paths\) both cover')

    # =============================================================================================
    Write-Host "`n== A. COMPETING COLD-START STATE (Check 10) ==" -ForegroundColor Cyan
    # =============================================================================================
    $readmeOriginal = Read-S $README
    $NL = [string][char]10
    # SINGLE-QUOTED, deliberately: these fixtures carry markdown code spans, and inside a
    # double-quoted PowerShell string a backtick is the ESCAPE character -- `history/...` would be
    # written as history/... with the backticks silently eaten, and the guard reads those backticks.
    $staleDirective = '> **Current state & next step (read this first on a cold start):** `history/session-2026-09-08-batch6-slice9-leads.md` -- probe.'
    $stalePrevious  = '> Previously: **Latest session report:** `history/session-2026-09-08-batch6-slice9-leads.md` -- probe.'
    $liveRowRx      = '(?m)^(> \*\*Latest session report:\*\*[^\r\n]*)$'

    # A1 -- the defect verbatim: a SECOND un-prefixed cold-start directive naming an older report.
    $mutated = $readmeOriginal -replace $liveRowRx, ('$1' + $NL + '>' + $NL + $staleDirective)
    Check 'A-precondition: the probe row was actually inserted' ($mutated -ne $readmeOriginal)
    Write-S $README $mutated
    $r = Invoke-Guard
    Check 'A1 MUTATION: a second un-prefixed cold-start directive is DETECTED (this is the 2026-09-09 defect, byte for byte)' `
        ($r.Exit -ne 0 -and $r.Text -match 'COMPETING LIVE COLD-START STATE') $r.Exit
    # DERIVED, not hardcoded: the live report changes every session, and a suite that pins its name
    # would fail on the next one for no reason. The manifest's `Narrative:` field is the authority
    # Check 10 itself compares against, so ask it.
    $narrative = [regex]::Match((Read-S $MANIFEST), 'Narrative:\s*`([^`]+\.md)`').Groups[1].Value
    Check 'A1 MUTATION: the failure NAMES both competing reports, so it is diagnosable without re-running' `
        ($narrative -and $r.Text -match [regex]::Escape($narrative) -and $r.Text -match 'slice9-leads\.md') `
        "narrative=$narrative"

    # A2 -- SECOND DIRECTION, and it is the one that decides whether A1's rule is safe to ship. The
    # same row, prefixed `Previously:` -- the file's own historical marker -- must NOT be flagged.
    # Six real rows have exactly this shape; a rule that cannot tell them apart is useless.
    Write-S $README ($readmeOriginal -replace $liveRowRx, ('$1' + $NL + '>' + $NL + $stalePrevious))
    $r = Invoke-Guard
    Check 'A2 CONTROL: the identical row prefixed `Previously:` is NOT flagged -- history must stay legal' `
        ($r.Exit -eq 0 -and $r.Text -notmatch 'COMPETING LIVE COLD-START STATE') $r.Exit

    # A3 -- exactly one live declaration, but it names the WRONG report. This is the shape the defect
    # would have taken if the stale block had been the only live one.
    $demoted = $readmeOriginal -replace '(?m)^> \*\*Latest session report:\*\*', '> Previously: **Latest session report:**'
    # An INSTANCE regex, because only `Regex.Replace(input, replacement, count)` takes a count. The
    # static `[regex]::Replace(input, pattern, replacement, 1)` binds its fourth argument to
    # RegexOptions instead, so the 1 silently became `IgnoreCase` and every one of the six rows was
    # replaced -- producing the six-live-rows case rather than the one-wrong-row case under test.
    # The suite caught it because A3 asserts on a SPECIFIC message, not merely on a non-zero exit.
    $onceRx = [regex]'(?m)^(> Previously: \*\*Latest session report:\*\*[^\r\n]*)$'
    Write-S $README ($onceRx.Replace($demoted, ('$1' + $NL + '>' + $NL + $staleDirective), 1))
    $r = Invoke-Guard
    Check 'A3 MUTATION: a single live declaration that names a DIFFERENT report than the manifest is DETECTED' `
        ($r.Exit -ne 0 -and $r.Text -match 'LIVE POINTER DISAGREES WITH THE MANIFEST') $r.Exit

    # A4 -- no live declaration at all. A cold start following AGENTS.md 4 Stage A step 7 finds nothing.
    Write-S $README $demoted
    $r = Invoke-Guard
    Check 'A4 MUTATION: demoting every pointer to history leaves NO live declaration, and that is DETECTED' `
        ($r.Exit -ne 0 -and $r.Text -match 'NO LIVE COLD-START POINTER') $r.Exit

    Restore-S $README
    $r = Invoke-Guard
    Check 'A-restore: the README is back and the guard is CLEAN again' ($r.Exit -eq 0) $r.Exit

    # =============================================================================================
    Write-Host "`n== B. NARRATIVE OWNER-DECISION CONTAMINATION (Checks 14/16/25) ==" -ForegroundColor Cyan
    # =============================================================================================
    $manifestOriginal = Read-S $MANIFEST

    # B1 -- THE QUIET DIRECTION, and the reason this defect mattered. Remove `MAIL-1` from the
    # ENUMERATION while leaving the narrative sentence that mentions it. Under the old whole-line
    # parse Check 25 found MAIL-1 "on the line" and said nothing; a genuine, decider-bearing decision
    # would have been invisible at boot. It must now be reported as unsurfaced.
    $b1 = $manifestOriginal -replace '\*\*MAIL-1\*\*, ', ''
    Check 'B1-precondition: MAIL-1 removed from the enumeration and still present in the prose' `
        ($b1 -ne $manifestOriginal -and $b1 -match 'MAIL-1')
    Write-S $MANIFEST $b1
    $r = Invoke-Guard
    Check 'B1 MUTATION: an id mentioned ONLY in the line prose no longer counts as surfaced -- Check 25 reports it' `
        ($r.Exit -ne 0 -and $r.Text -match "UNSURFACED DECISION: register entry 'MAIL-1'") $r.Exit

    # B2 -- the opposite direction: an id written INTO the enumeration is state, and a settled one
    # must be struck. GOV-16 is the vehicle because it exists ONLY as `###` detail blocks, so this
    # simultaneously proves the enumeration is genuinely parsed AND that a section-only finding's
    # status is now visible to Check 14 (bug class 3).
    $b2 = $manifestOriginal -replace '\*\*MAIL-1\*\*, ', '**MAIL-1**, **GOV-16**, '
    Check 'B2-precondition: GOV-16 inserted into the enumeration' ($b2 -ne $manifestOriginal)
    Write-S $MANIFEST $b2
    $r = Invoke-Guard
    Check 'B2 MUTATION: a SETTLED id placed in the enumeration IS struck by Check 14' `
        ($r.Exit -ne 0 -and $r.Text -match "STALE OWNER DECISION: manifest lists 'GOV-16'") $r.Exit
    Check 'B2 MUTATION: and the evidence cited is a DETAIL BLOCK, not a table row -- GOV-16 has no table row at all' `
        ($r.Text -match "STALE OWNER DECISION: manifest lists 'GOV-16'[^\r\n]*(heading|block status)")

    Restore-S $MANIFEST
    $r = Invoke-Guard
    Check 'B-restore: the manifest is back and the guard is CLEAN again' ($r.Exit -eq 0) $r.Exit

    # =============================================================================================
    Write-Host "`n== C. REGISTER STATUS VOCABULARY AND ANCHORING (Checks 14/25) ==" -ForegroundColor Cyan
    # =============================================================================================
    $registerOriginal = Read-S $REGISTER
    # ARCH-2's row is the exact live false-negative: its status OPENS with `**OPEN - engineering,
    # PROVEN ... deliberately NOT fixed ...**`, and Check 25's unanchored pattern read the substring
    # FIXED as a settled verdict. Its Owner-Decision cell is currently `-` (no decider), so it sits
    # outside Check 25's population; giving it one puts it in.
    $archRow = (($registerOriginal -split "`r?`n") | Where-Object { $_ -match '^\|\s*ARCH-2\s*\|' } | Select-Object -First 1)
    Check 'C-precondition: ARCH-2 opens OPEN and contains the word FIXED inside its status' `
        ($archRow -and $archRow -match 'OPEN' -and $archRow -match 'NOT fixed')

    $cells = $archRow -split '\|'
    $withDecider = ($cells.Clone()); $withDecider[10] = ' owner: probe '
    Write-S $REGISTER $registerOriginal.Replace($archRow, ($withDecider -join '|'))
    $r = Invoke-Guard
    Check 'C1 MUTATION: a status OPENING with OPEN is not settled merely because "deliberately NOT FIXED" contains FIXED' `
        ($r.Exit -ne 0 -and $r.Text -match "UNSURFACED DECISION: register entry 'ARCH-2'") $r.Exit

    # C2 -- SECOND DIRECTION at the SAME site, so the difference measured is the vocabulary and
    # nothing else. `VERIFIED` is one of the words the register's own Legend declares terminal and
    # that Check 25 previously did not know; leading with it must settle the row.
    $settledForm = ($cells.Clone()); $settledForm[10] = ' owner: probe '; $settledForm[9] = ' **VERIFIED 2026-09-08 -- probe.** '
    Write-S $REGISTER $registerOriginal.Replace($archRow, ($settledForm -join '|'))
    $r = Invoke-Guard
    Check 'C2 CONTROL: the same row LEADING with VERIFIED is settled, and is not demanded on the boot line' `
        ($r.Exit -eq 0 -and $r.Text -notmatch "UNSURFACED DECISION: register entry 'ARCH-2'") $r.Exit

    Restore-S $REGISTER
    $r = Invoke-Guard
    Check 'C-restore: the register is back and the guard is CLEAN again' ($r.Exit -eq 0) $r.Exit

    # =============================================================================================
    Write-Host "`n== D. CI TRIGGER COVERAGE AND SYMMETRY (Check 20) ==" -ForegroundColor Cyan
    # =============================================================================================
    $workflowOriginal = Read-S $WORKFLOW
    # Split at `pull_request:` so a path can be removed from exactly ONE block -- which is precisely
    # the state Check 20 could not see while it searched the whole file.
    $splitAt = $workflowOriginal.IndexOf('  pull_request:')
    Check 'D-precondition: the workflow has a pull_request trigger block' ($splitAt -gt 0)
    $pushPart = $workflowOriginal.Substring(0, $splitAt)
    $prPart   = $workflowOriginal.Substring($splitAt)

    Write-S $WORKFLOW ($pushPart + ($prPart -replace '(?m)^\s+- "ai-map\.json"\r?\n', ''))
    $r = Invoke-Guard
    Check 'D1 MUTATION: a path removed from pull_request ONLY is DETECTED (the 2026-09-09 asymmetry)' `
        ($r.Exit -ne 0 -and $r.Text -match "CI TRIGGER GAP: 'ai-map\.json' is not in repository-consistency\.yml on\.pull_request\.paths") $r.Exit
    Check 'D1 MUTATION: and the asymmetry itself is named, not only the missing coverage' `
        ($r.Text -match "CI TRIGGER ASYMMETRY: 'ai-map\.json' triggers on push but not on pull_request")

    Write-S $WORKFLOW (($pushPart -replace '(?m)^\s+- "supabase/tests/\*\*"\r?\n', '') + $prPart)
    $r = Invoke-Guard
    Check 'D2 MUTATION: a path removed from push ONLY is DETECTED -- the check is not one-sided' `
        ($r.Exit -ne 0 -and $r.Text -match "CI TRIGGER GAP: 'supabase/tests/\*\*' is not in repository-consistency\.yml on\.push\.paths") $r.Exit

    Restore-S $WORKFLOW
    $r = Invoke-Guard
    Check 'D-restore: the workflow is back and the guard is CLEAN again' ($r.Exit -eq 0) $r.Exit

    # =============================================================================================
    Write-Host "`n== E. FAILURE PROPAGATION FROM THE DELEGATED GUARD (Check 19) ==" -ForegroundColor Cyan
    # =============================================================================================
    # Check 19 DELEGATES to `check_primary_ledger.ps1` and gates on `$LASTEXITCODE`. Nothing
    # permanently proved that a non-zero child exit reaches the parent's verdict -- it was confirmed
    # once by hand in 2026-09 and never pinned. A swallowed failure inside a wrapper is one of the
    # ways a weak agent is handed a green light over a red result.
    #
    # The SANDBOX copy of the guard is invoked here, deliberately: Check 19 resolves the child through
    # `$PSScriptRoot`, so only a sandbox-rooted run can substitute the child without touching the real
    # repository. The child is replaced by a stub whose ONLY behaviour is its exit code, which
    # isolates propagation from anything the real child does.
    $sandboxGuard = S 'scripts/check_repository_consistency.ps1'
    $ledgerReal   = Read-S $LEDGER

    Write-S $LEDGER "Write-Host 'STUB LEDGER GUARD: pass'`nexit 0`n"
    $out = & pwsh -NoProfile -File $sandboxGuard -RepoRoot $sandbox 2>&1 | Out-String
    $code = $LASTEXITCODE
    Check 'E-CONTROL: with the delegated guard exiting 0, the parent does not report a ledger failure' `
        ($code -eq 0 -and $out -notmatch 'Primary ledger evidence is ABSENT') "exit=$code"

    Write-S $LEDGER "Write-Host 'STUB LEDGER GUARD: deliberate failure'`nexit 3`n"
    $out = & pwsh -NoProfile -File $sandboxGuard -RepoRoot $sandbox 2>&1 | Out-String
    $code = $LASTEXITCODE
    Check 'E1 MUTATION: a NON-ZERO exit from the delegated guard makes the parent report it' `
        ($out -match 'Primary ledger evidence is ABSENT, STALE or DISAGREES')
    Check 'E1 MUTATION: ...and makes the PARENT exit non-zero -- the failure is not swallowed by the wrapper' `
        ($code -ne 0) "exit=$code"

    Remove-Item -LiteralPath (S $LEDGER) -Force
    $out = & pwsh -NoProfile -File $sandboxGuard -RepoRoot $sandbox 2>&1 | Out-String
    $code = $LASTEXITCODE
    Check 'E2 MUTATION: a DELETED delegated guard fails closed rather than being skipped as "nothing to check"' `
        ($code -ne 0 -and $out -match 'MISSING: scripts/check_primary_ledger\.ps1') "exit=$code"

    Write-S $LEDGER $ledgerReal

    # =============================================================================================
    Write-Host "`n== CONTROL, LAST (second direction) ==" -ForegroundColor Cyan
    # =============================================================================================
    $after = Invoke-Guard
    Check 'CONTROL (second direction): after every mutation above, an untouched copy is CLEAN again' `
        ($after.Exit -eq 0 -and $after.Text -match 'REPOSITORY CONSISTENCY: CLEAN') "exit=$($after.Exit)"
}
finally {
    if ($sandbox -and (Test-Path $sandbox)) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}

Write-Host "`n== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
exit 0
