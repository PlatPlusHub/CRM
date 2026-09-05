# ORVION -- the guard-of-the-guard for Check 12's future-date ceiling (AUD-01a).
#
# `AGENTS.md §6`: "Attack every new detector with a counterexample before trusting it, in both
# directions: construct a case it must flag and one it must not."
#
# WHY THIS EXISTS. Check 12's ceiling was `(Get-Date).Date` -- the RUNNER's local civil date. ORVION
# is written from Africa/Cairo (UTC+2/+3) and CI runs in UTC, so the check returned a different
# verdict depending on where it ran. Slice 3 was pushed 2026-09-05T23:11Z with documents correctly
# stamped 2026-09-06 (it was already the 6th where they were written): CLEAN on the author's
# machine, 22 FUTURE-DATED failures in GitHub Actions. The guard was not detecting a defect, it was
# detecting a timezone -- nightly, in the window when work is most likely to be pushed.
#
# The ceiling is now the newest civil date that exists anywhere on Earth (UTC+14, Pacific/Kiritimati
# -- the maximum civil offset in the IANA database). The invariant is unchanged; only the false
# positives are gone. This suite pins that boundary from both sides so a future edit cannot quietly
# return the check to local time.
#
# Scenarios run against a temp sandbox, invoked through the guard's own `-RepoRoot`. The real
# repository is never modified. No database is touched. Other checks report noise against a minimal
# sandbox; this suite asserts ONLY on Check 12's lines, which is what makes that acceptable.
#
# Run: pwsh -File scripts/test_future_date_guard.ps1

$ErrorActionPreference = 'Stop'
$guard = Join-Path $PSScriptRoot 'check_repository_consistency.ps1'

$pass = 0; $fail = 0
function Check($name, $condition, $detail = '') {
    if ($condition) { Write-Host "  ok   $name" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  FAIL $name  $detail" -ForegroundColor Red; $script:fail++ }
}

# The boundary, computed here INDEPENDENTLY of the guard so the two must agree by arithmetic and not
# by sharing a variable.
$edge = [datetimeoffset]::UtcNow.AddHours(14).Date

# The sandbox is a FULL copy of the repository, not a bare directory, and the first draft of this
# suite got that wrong in a way worth recording: with only a probe file present, the guard aborts at
# Check 3 ("MISSING ROUTER: AGENTS.md does not exist") under $ErrorActionPreference = 'Stop' and
# never reaches Check 12 at all. Both must-flag scenarios then "passed" -- against a guard that had
# not run. That is the failure mode `AGENTS.md §6` names: a test satisfied without its invariant
# being satisfied. Check 2's harness gets away with a partial copy only because Check 2 runs BEFORE
# the abort; Check 12 runs after it, so nothing less than a whole repository will do.
$repoRoot = Split-Path -Parent $PSScriptRoot
function Invoke-Check12($dateStamp) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("orvion-fdate-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    try {
        Get-ChildItem -Path $repoRoot -Recurse -File |
            Where-Object { $_.FullName -notmatch '[\\/](node_modules|backup|\.git)[\\/]' } |
            ForEach-Object {
                $rel = $_.FullName.Substring($repoRoot.Length + 1)
                $dest = Join-Path $dir $rel
                New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
                Copy-Item $_.FullName $dest -Force
            }
        Set-Content -Path (Join-Path $dir 'probe.md') -Value "Last updated: $dateStamp" -Encoding UTF8
        $out = & pwsh -NoProfile -File $guard -RepoRoot $dir 2>&1 | Out-String
        # Assert ONLY on the probe. The copied repository carries its own dates and its own unrelated
        # noise in a sandbox with no git history; neither is this suite's question.
        if ($out -notmatch 'Check 12: no future-dated evidence') {
            throw "the guard never reached Check 12 -- the sandbox is not viable, not the check"
        }
        return ($out -split "`n" | Where-Object { $_ -match 'FUTURE-DATED' -and $_ -match 'probe\.md' }) -join "`n"
    } finally {
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "== Check 12 ceiling: the newest civil date on Earth is $($edge.ToString('yyyy-MM-dd')) ==" -ForegroundColor Cyan

# 1. MUST NOT FLAG. A date that has begun somewhere is a date an author could legitimately have
#    stamped. This is the case the old local-time ceiling got wrong, and the only reason it passed on
#    the machine that wrote it was that the machine happened to be east of UTC.
$atEdge = Invoke-Check12 $edge.ToString('yyyy-MM-dd')
Check "the newest civil date on Earth is NOT reported future-dated" ($atEdge -eq '') $atEdge

# 2. MUST FLAG. One day past the last timezone on Earth has begun nowhere, for anyone. If this stops
#    firing, the check has been widened into uselessness rather than corrected.
$pastEdge = Invoke-Check12 $edge.AddDays(1).ToString('yyyy-MM-dd')
Check "one day beyond it IS reported future-dated" ($pastEdge -match 'FUTURE-DATED') $pastEdge

# 3. MUST FLAG. The defect the check actually exists for, unaffected by any of this.
$farFuture = Invoke-Check12 $edge.AddDays(30).ToString('yyyy-MM-dd')
Check "a date a month out IS reported future-dated" ($farFuture -match 'FUTURE-DATED') $farFuture

# 4. MUST NOT FLAG. Yesterday, everywhere, always.
$yesterday = Invoke-Check12 $edge.AddDays(-1).ToString('yyyy-MM-dd')
Check "yesterday is NOT reported future-dated" ($yesterday -eq '') $yesterday

# 5. STRUCTURAL, and its ceiling is stated rather than implied. Assertions 1-4 are behavioural and
#    are the real evidence -- but assertion 1 only DISCRIMINATES against a local-time regression
#    while the runner's local date is behind UTC+14, which in Africa/Cairo is about eleven hours a
#    day and in UTC is fourteen. So it would catch a revert usually, not always. This one catches it
#    always, at the cost of reading the source text rather than the behaviour: exactly the MONEY-1
#    class ceiling from slice 3, declared here for the same reason.
$src = Get-Content $guard -Raw
$check12 = [regex]::Match($src, '(?s)== Check 12: no future-dated evidence ==.*?\$dateRx\s*=').Value
Check "the ceiling is derived from UtcNow, not from the runner's local clock" `
    ($check12 -match '\[datetimeoffset\]::UtcNow\.AddHours\(14\)\.Date' -and $check12 -notmatch '\$today\s*=\s*\(Get-Date\)') `
    'Check 12 must not compute its ceiling from local time -- that is the AUD-01a regression'

Write-Host ""
if ($fail -gt 0) {
    Write-Host "FUTURE-DATE GUARD TEST: $pass passed, $fail FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "FUTURE-DATE GUARD TEST: $pass passed, 0 failed" -ForegroundColor Green
exit 0
