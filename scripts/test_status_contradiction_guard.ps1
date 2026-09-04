# ORVION -- the guard-of-the-guard for Check 2's status detection (GOV-18).
#
# `AGENTS.md §6`: "Attack every new detector with a counterexample before trusting it, in both
# directions: construct a case it must flag and one it must not. A guard that can be satisfied
# without satisfying its invariant is the class the discovery-to-guard loop exists to eliminate."
#
# WHY THIS EXISTS. Check 2 is the repository's central contradiction guard, and until GOV-18 its
# open-detector was `$line -match '\|\s*OPEN\s*\|'` -- a padded cell containing EXACTLY the word
# OPEN. Measured across every reports/master table, that form covered **20 of 84** open rows, so the
# contradiction pass (and, through $xOpen, AUD-04's cross-Master pass) was blind to 76% of the open
# population. That is exactly how GOV-17's five contradictions printed CLEAN. Widening a guard that
# every other status claim rests on is precisely the change that must not be trusted unattacked --
# too loose and it manufactures contradictions out of finished verdicts; too tight and it repeats
# GOV-18.
#
# Every scenario runs against COPIES of reports/master in a temp directory, invoked through the
# guard's own `-RepoRoot`. The real register is never modified. No database is touched.
# Other checks report noise against a minimal sandbox; this suite asserts ONLY on Check 2's lines,
# which is what makes that acceptable.
#
# Run: pwsh -File scripts/test_status_contradiction_guard.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$guard    = Join-Path $PSScriptRoot 'check_repository_consistency.ps1'
$realMaster = Join-Path $repoRoot 'reports/master'

$pass = 0; $fail = 0
function Check($name, $condition, $detail = '') {
    if ($condition) { Write-Host "  ok   $name" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  FAIL $name  $detail" -ForegroundColor Red; $script:fail++ }
}

function New-Sandbox {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("orvion-status-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path (Join-Path $dir 'reports/master') -Force | Out-Null
    Copy-Item (Join-Path $realMaster '*.md') (Join-Path $dir 'reports/master') -Force
    return $dir
}

# Returns ONLY Check 2's contradiction lines. Exit code is deliberately ignored: a minimal sandbox
# legitimately fails other checks, and asserting on those would make this suite test the wrong thing.
#
# `-cmatch` and the trailing colon are LOAD-BEARING. The first version of this helper used a
# case-insensitive `-match 'STATUS CONTRADICTION'`, which also matched Check 2's own banner --
# "== Check 2: intra-file status contradiction in reports/master ==" -- so every run returned one
# phantom hit and both CONTROLs failed while the guard was behaving correctly. The control caught
# it, which is what a control is for: a harness that cries wolf is indistinguishable from a guard
# that does, and a suite nobody trusts is worse than none.
function Get-Contradictions($dir) {
    $out = & pwsh -NoProfile -File $guard -RepoRoot $dir 2>&1 | Out-String
    return @($out -split "`n" | Where-Object { $_ -cmatch '(STATUS CONTRADICTION|CROSS-MASTER STATUS CONTRADICTION):' })
}

# Rewrites the Status cell of the table row whose FIRST cell is $id. Column is located from the
# table's own header, the same way Check 2 now does it -- a helper that guessed the index would be
# testing a different file shape than the guard reads.
function Set-StatusCell($dir, $file, $id, $newStatus) {
    $path  = Join-Path $dir "reports/master/$file"
    $lines = [System.IO.File]::ReadAllLines($path)
    $statusIdx = -1; $hit = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^\s*\|') { continue }
        $cells = @(($lines[$i] -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
        for ($c = 0; $c -lt $cells.Count; $c++) { if ($cells[$c] -eq 'Status') { $statusIdx = $c } }
        if ($statusIdx -lt 0 -or $cells.Count -le $statusIdx) { continue }
        if ($cells[1] -eq $id) {
            $raw = $lines[$i] -split '(?<!\\)\|'
            $raw[$statusIdx] = " $newStatus "
            $lines[$i] = ($raw -join '|')
            $hit = $true
            break
        }
    }
    [System.IO.File]::WriteAllLines($path, $lines)
    return $hit
}

Write-Host "`n== Check 2 status detection (GOV-18) -- mutation suite ==" -ForegroundColor Cyan

# --- CONTROL, FIRST. An untouched copy of the real register must report NO contradiction, or every
#     result below could be the harness rather than the guard.
$d = New-Sandbox
$base = Get-Contradictions $d
Check "CONTROL: an untouched copy of reports/master reports NO contradiction" ($base.Count -eq 0) "got: $($base -join ' | ')"
Remove-Item $d -Recurse -Force

# =================================================================================================
# DIRECTION A -- cases the guard MUST flag. Each sets a real row to an open form that the
# pre-GOV-18 detector could not see, for an id whose detail block states a resolved verdict.
# RBAC-5 is the vehicle: its row is resolved and its `### RBAC-5` block carries `**Status:** FIXED`,
# so only the row's own status is being changed by these mutations.
# =================================================================================================
$openForms = @(
    @{ Name = 'BLOCKED - ...';            Value = '**BLOCKED - MUTATION PROBE**' },
    @{ Name = 'DESIGN-READY';             Value = 'DESIGN-READY' },
    @{ Name = 'PENDING (...)';            Value = 'PENDING (OPTIONAL / NEEDS MORE EVIDENCE) - probe' },
    @{ Name = 'OPEN - ... (rich form)';   Value = '**OPEN - MUTATION PROBE**' },
    @{ Name = 'IN PROGRESS';              Value = 'IN PROGRESS (residue) - probe' },
    @{ Name = 'PARTIALLY RESOLVED';       Value = 'PARTIALLY RESOLVED 2026-01-01 - probe' },
    @{ Name = 'TRIGGER-DEFERRED';         Value = 'TRIGGER-DEFERRED - probe' },
    @{ Name = 'VALIDATED-REQUIRED';       Value = 'VALIDATED-REQUIRED - probe' },
    @{ Name = 'MOVED->PENDING';           Value = 'MOVED->PENDING' },
    @{ Name = 'bare OPEN (the ONLY form the old detector saw)'; Value = 'OPEN' }
)
foreach ($f in $openForms) {
    $d = New-Sandbox
    $set = Set-StatusCell $d 'MASTER_GAP_REGISTER.md' 'RBAC-5' $f.Value
    $hits = Get-Contradictions $d
    Check "MUTATION A [$($f.Name)] is DETECTED as a row that says open while the finding is resolved" ($set -and ($hits -match 'RBAC-5')) "set=$set hits=$($hits -join ' | ')"
    Remove-Item $d -Recurse -Force
}

# --- A-old. The pre-GOV-18 detector's own blindness, proven rather than asserted: of the ten open
#     forms above, `\|\s*OPEN\s*\|` matches exactly ONE. This is the finding, expressed as a test.
$oldPattern = '\|\s*OPEN\s*\|'
$seenByOld = @($openForms | Where-Object { "| RBAC-5 | x | $($_.Value) | y |" -match $oldPattern }).Count
Check "MUTATION A-old: the pre-GOV-18 detector sees only 1 of the $($openForms.Count) open forms -- the other $($openForms.Count - 1) were invisible" ($seenByOld -eq 1) "old detector saw $seenByOld"

# =================================================================================================
# DIRECTION B -- cases the guard MUST NOT flag. A terminal verdict is a FINISHED state; reading one
# as "open" would manufacture contradictions, which is the mirror of the defect GOV-18 fixes.
# =================================================================================================
$terminalForms = @(
    @{ Name = 'INTENTIONAL';                       Value = '**INTENTIONAL - kept, not dropped.** probe' },
    @{ Name = 'PROVEN NOT A DEFECT';               Value = '**PROVEN NOT A DEFECT, and now pinned.** probe' },
    @{ Name = 'ACCEPTED RISK';                     Value = '**ACCEPTED RISK - evidenced, not deferred.** probe' },
    @{ Name = 'UNPROVEN';                          Value = '**UNPROVEN - recorded, deliberately not acted on.** probe' },
    @{ Name = 'RECORDED, DELIBERATELY NOT FIXED';  Value = '**RECORDED, DELIBERATELY NOT FIXED.** probe' },
    @{ Name = 'NOT REPRODUCIBLE TODAY';            Value = '**NOT REPRODUCIBLE TODAY.** probe' },
    @{ Name = 'EVIDENCE ONLY';                     Value = '**EVIDENCE ONLY - creates no new decision.** probe' },
    @{ Name = 'MEASURED';                          Value = '**MEASURED 2026-09-01; implementation not started.** probe' },
    @{ Name = 'DECIDED BY THE OWNER';              Value = '**✅ DECIDED BY THE OWNER 2026-09-01 (OWNER-1)** - probe' },
    @{ Name = 'CONTROL APPLIED';                   Value = '**✅ CONTROL APPLIED 2026-09-04.** probe' }
)
foreach ($f in $terminalForms) {
    $d = New-Sandbox
    $set = Set-StatusCell $d 'MASTER_GAP_REGISTER.md' 'RBAC-5' $f.Value
    $hits = Get-Contradictions $d
    Check "MUTATION B [$($f.Name)] is NOT read as open -- a finished verdict must not manufacture a contradiction" ($set -and ($hits.Count -eq 0)) "set=$set hits=$($hits -join ' | ')"
    Remove-Item $d -Recurse -Force
}

# --- B-critical. THE SHAPE SEVENTEEN REAL ROWS USE. The register's never-delete convention keeps the
#     old wording after the new verdict, so a resolved cell legitimately CONTAINS the word BLOCKED:
#       `**✅ RESOLVED ... Superseded text:** **BLOCKED - BUSINESS DECISION**`
#     A whole-cell (rather than leading-anchored) open match would flag every one of them. This is
#     the single mutation that decides whether GOV-18's vocabulary is safe to ship.
$d = New-Sandbox
$set = Set-StatusCell $d 'MASTER_GAP_REGISTER.md' 'RBAC-5' '**✅ RESOLVED 2026-09-04 - probe. Superseded text:** **BLOCKED - BUSINESS DECISION.**'
$hits = Get-Contradictions $d
Check "MUTATION B-critical: a RESOLVED cell that retains superseded `BLOCKED` text is NOT read as open (17 real rows have this shape)" ($set -and ($hits.Count -eq 0)) "set=$set hits=$($hits -join ' | ')"
Remove-Item $d -Recurse -Force

# --- B-column. The register's `Cert` column holds a bare ✅ and its `Owner Decision` column holds the
#     bare word `pending`. Before GOV-18 anchored detection to the header-declared Status column, a
#     widened match would have read BOTH as the row's status and called almost every row open AND
#     resolved at once. Proven here by planting exactly that: an open status beside those cells must
#     be judged on the STATUS cell only.
$d = New-Sandbox
$path = Join-Path $d 'reports/master/MASTER_GAP_REGISTER.md'
$lines = [System.IO.File]::ReadAllLines($path)
for ($i = 0; $i -lt $lines.Count; $i++) {
    $cells = $lines[$i] -split '(?<!\\)\|'
    if ($cells.Count -gt 10 -and $cells[1].Trim() -eq 'RBAC-5') {
        $cells[8]  = ' ✅ '                      # Cert column: a bare tick
        $cells[9]  = ' **BLOCKED - probe** '     # Status column: genuinely open
        $cells[10] = ' pending '                 # Owner Decision column: the bare word
        $lines[$i] = ($cells -join '|'); break
    }
}
[System.IO.File]::WriteAllLines($path, $lines)
$hits = Get-Contradictions $d
Check "MUTATION B-column: with Cert=✅ and Owner=pending beside it, the row is judged on its STATUS cell alone" (($hits -match 'RBAC-5').Count -eq 1) "hits=$($hits -join ' | ')"
Remove-Item $d -Recurse -Force

# --- CONTROL, LAST. Second-direction control (GOV-4's lesson): every mutation lived in its own
#     sandbox, and the guard still reports the true state as clean.
$d = New-Sandbox
$after = Get-Contradictions $d
Check "CONTROL (second direction): an untouched copy still reports NO contradiction after every mutation above" ($after.Count -eq 0) "got: $($after -join ' | ')"
Remove-Item $d -Recurse -Force

Write-Host "`n== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
exit 0
