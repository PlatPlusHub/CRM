# ORVION -- the guard-of-the-guard for Check 12's future-date ceiling (AUD-01a), and for the
# culture-independence of the repository's `yyyy-MM-dd` date contract (AUD-01b).
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
# AUD-01b (SPEC-176). The SAME check returned a different verdict for a second reason, and this one
# was silent. Checks 12, 21 and 23 read the repository's `yyyy-MM-dd` dates with a $null format
# provider, which .NET resolves to CurrentCulture -- not InvariantCulture. Under a culture whose
# default calendar is not Gregorian (`ar-SA` -> UmAlQuraCalendar) the year 2026 is out of range,
# EVERY parse returns false, and each check skips the record it was about to judge: Check 12
# reported "no future-dated evidence" over a tree containing tomorrow's date, and Checks 21 and 23
# reported success over ZERO documents. A guard that asserts over an empty set is worse than one
# that fails, because it publishes a green verdict it never earned.
#
# That is proven here rather than trusted, and it is proven through the ONE scenario that already
# existed: the `edge + 1 day` case now runs under a hostile culture and carries three probes, so
# this suite still invokes the guard exactly four times. Culture is set PROCESS-LOCALLY in a child
# `pwsh`; this suite never touches Windows regional settings and never calls Set-Culture.
#
# Scenarios run against a temp sandbox, invoked through the guard's own `-RepoRoot`. The real
# repository is never modified. No database is touched. Other checks report noise against a minimal
# sandbox; this suite asserts ONLY on its own probes, which is what makes that acceptable.
#
# Run: pwsh -File scripts/test_future_date_guard.ps1

$ErrorActionPreference = 'Stop'
$guard = Join-Path $PSScriptRoot 'check_repository_consistency.ps1'

$pass = 0; $fail = 0
function Check($name, $condition, $detail = '') {
    if ($condition) { Write-Host "  ok   $name" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  FAIL $name  $detail" -ForegroundColor Red; $script:fail++ }
}

# This suite obtains its OWN invariant formatter and never imports one from the guard. If both sides
# read the same formatter, a culture defect in that formatter is invisible to the test that exists
# to find it -- the fixture would be mis-stamped in exactly the way that makes the guard's miss look
# correct. Independent by construction, for the same reason `$edge` below is computed here.
$inv = [System.Globalization.CultureInfo]::InvariantCulture
function Iso([datetime]$d) { $d.ToString('yyyy-MM-dd', $inv) }

# The boundary, computed here INDEPENDENTLY of the guard so the two must agree by arithmetic and not
# by sharing a variable.
$edge = [datetimeoffset]::UtcNow.AddHours(14).Date

# Check 23's cutoff is READ FROM THE GUARD rather than copied, so this probe cannot drift to the
# wrong side of a cutoff someone later moves. One day after it is unambiguously "on or after".
$cutoffMatch = [regex]::Match((Get-Content $guard -Raw), '\$handoffRuleDate\s*=\s*\[datetime\]''(\d{4}-\d{2}-\d{2})''')
if (-not $cutoffMatch.Success) { throw "cannot read Check 23's HANDOFF cutoff from the guard -- the probe would be unanchored" }
$handoffProbe = ([datetime]::ParseExact($cutoffMatch.Groups[1].Value, 'yyyy-MM-dd', $inv)).AddDays(1)

# Fixed historical dates for the Check 21 probe: a header older than a body date is stale by
# arithmetic that does not move with the calendar.
$freshHeader = [datetime]::ParseExact('2026-01-01', 'yyyy-MM-dd', $inv)
$freshBody   = [datetime]::ParseExact('2026-01-02', 'yyyy-MM-dd', $inv)

$hostileCulture = 'ar-SA'

# The sandbox is a FULL copy of the repository, not a bare directory, and the first draft of this
# suite got that wrong in a way worth recording: with only a probe file present, the guard aborts at
# Check 3 ("MISSING ROUTER: AGENTS.md does not exist") under $ErrorActionPreference = 'Stop' and
# never reaches Check 12 at all. Both must-flag scenarios then "passed" -- against a guard that had
# not run. That is the failure mode `AGENTS.md §6` names: a test satisfied without its invariant
# being satisfied. Check 2's harness gets away with a partial copy only because Check 2 runs BEFORE
# the abort; Check 12 runs after it, so nothing less than a whole repository will do.
$repoRoot = Split-Path -Parent $PSScriptRoot
function Invoke-Guard($dateStamp, [string]$Culture) {
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
        if (-not $Culture) {
            $out = & pwsh -NoProfile -File $guard -RepoRoot $dir 2>&1 | Out-String
        } else {
            # Probe B -- Check 21. A freshness header older than the document's own newest body date.
            Set-Content -Path (Join-Path $dir 'culture-freshness-probe.md') -Encoding UTF8 -Value @(
                "Last updated: $(Iso $freshHeader)",
                '',
                "Controlled body evidence: $(Iso $freshBody)")
            # Probe C -- Check 23. Dated on or after the rule, and deliberately carrying no block.
            # The seven field names are not written anywhere in this file, deliberately.
            $history = Join-Path $dir 'reports/history'
            New-Item -ItemType Directory -Path $history -Force | Out-Null
            Set-Content -Path (Join-Path $history 'culture-handoff-probe.md') -Encoding UTF8 -Value @(
                '# Culture probe report',
                "Date: $(Iso $handoffProbe)",
                '',
                'Deliberately carries no inherited-state block.')
            # A REAL process boundary, because that is what a differently-configured machine is. The
            # culture is constructed with user overrides DISABLED so the result depends on the
            # culture alone and not on whatever this workstation's regional panel happens to say.
            $wrapper = Join-Path $dir '_culture_wrapper.ps1'
            Set-Content -Path $wrapper -Encoding UTF8 -Value @'
param([string]$Guard, [string]$Root, [string]$Culture)
$c = [System.Globalization.CultureInfo]::new($Culture, $false)
[System.Globalization.CultureInfo]::CurrentCulture   = $c
[System.Globalization.CultureInfo]::CurrentUICulture = $c
Write-Output "CULTURE-PROBE: $([System.Globalization.CultureInfo]::CurrentCulture.Name) $([System.Globalization.CultureInfo]::CurrentCulture.Calendar.GetType().Name)"
& $Guard -RepoRoot $Root
'@
            $out = & pwsh -NoProfile -File $wrapper -Guard $guard -Root $dir -Culture $Culture 2>&1 | Out-String
        }
        # Assert ONLY on the probes. The copied repository carries its own dates and its own unrelated
        # noise in a sandbox with no git history; neither is this suite's question.
        if ($out -notmatch 'Check 12: no future-dated evidence') {
            throw "the guard never reached Check 12 -- the sandbox is not viable, not the check"
        }
        return $out
    } finally {
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# `FUTURE-DATED: probe.md ` and not a looser `probe\.md`, which the two culture probes would also
# satisfy -- they end in "-probe.md" and would make this suite report the wrong file's finding.
function Future-Hits($out) { ($out -split "`n" | Where-Object { $_ -match 'FUTURE-DATED: probe\.md ' }) -join "`n" }

Write-Host "== Check 12 ceiling: the newest civil date on Earth is $(Iso $edge) ==" -ForegroundColor Cyan

# 1. MUST NOT FLAG. A date that has begun somewhere is a date an author could legitimately have
#    stamped. This is the case the old local-time ceiling got wrong, and the only reason it passed on
#    the machine that wrote it was that the machine happened to be east of UTC.
$atEdge = Future-Hits (Invoke-Guard (Iso $edge))
Check "the newest civil date on Earth is NOT reported future-dated" ($atEdge -eq '') $atEdge

# 2. MUST FLAG. One day past the last timezone on Earth has begun nowhere, for anyone. If this stops
#    firing, the check has been widened into uselessness rather than corrected.
#
#    This is also the hostile-culture scenario (AUD-01b), carrying the Check 21 and Check 23 probes,
#    so proving culture-independence costs no additional guard execution.
$hostileOut = Invoke-Guard (Iso $edge.AddDays(1)) $hostileCulture
$pastEdge = Future-Hits $hostileOut
Check "one day beyond it IS reported future-dated" ($pastEdge -match 'FUTURE-DATED') $pastEdge

# 3. MUST FLAG. The defect the check actually exists for, unaffected by any of this.
$farFuture = Future-Hits (Invoke-Guard (Iso $edge.AddDays(30)))
Check "a date a month out IS reported future-dated" ($farFuture -match 'FUTURE-DATED') $farFuture

# 4. MUST NOT FLAG. Yesterday, everywhere, always.
$yesterday = Future-Hits (Invoke-Guard (Iso $edge.AddDays(-1)))
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
Write-Host "== Culture independence of the yyyy-MM-dd contract (AUD-01b), from the same run ==" -ForegroundColor Cyan

# 6. THE ORACLE'S OWN INTEGRITY, asserted first because every proof below is worthless without it.
#    If the child had silently fallen back to the invariant culture -- globalization-invariant mode,
#    an unavailable culture, a future runtime change -- assertions 7-9 would pass against a guard
#    that was never attacked at all. That is a false green of exactly the kind this file exists to
#    prevent, so the hostile process is made to PROVE its own calendar before it is believed.
Check "the probe process really ran under a non-Gregorian calendar" `
    ($hostileOut -match "CULTURE-PROBE: $hostileCulture UmAlQuraCalendar") `
    'the hostile-culture child did not report ar-SA/UmAlQuraCalendar -- the culture proofs below would be vacuous'

# 7. CHECK 12 under the hostile culture. The must-flag behaviour is already asserted at 2; what is
#    added here is that the DIAGNOSTIC speaks the repository's contract and not the machine's
#    calendar. A Hijri "1448-04-03" in this line would be a date no author could act on.
Check "Check 12 renders its Gregorian ceiling under a hostile culture" `
    ($pastEdge -match [regex]::Escape("the newest civil date in existence is $(Iso $edge)")) `
    $pastEdge

# 8. CHECK 21 under the hostile culture. Not merely "an issue was reported" -- the exact probe, with
#    both of its Gregorian dates, because the defect's signature was a green verdict over zero
#    documents and a count of zero is indistinguishable from a clean repository.
$staleHit = ($hostileOut -split "`n" | Where-Object { $_ -match 'STALE FRESHNESS METADATA: culture-freshness-probe\.md' }) -join "`n"
Check "Check 21 flags the stale probe and renders both Gregorian dates" `
    ($staleHit -match [regex]::Escape("declares $(Iso $freshHeader)") -and $staleHit -match [regex]::Escape("carries $(Iso $freshBody)")) `
    $staleHit

# 9. CHECK 23 under the hostile culture. Same shape: the report must be REACHED and named, because
#    the failure being pinned is the check quietly skipping every report it could not parse.
$handoffHit = ($hostileOut -split "`n" | Where-Object { $_ -match 'NO HANDOFF BLOCK: reports/history/culture-handoff-probe\.md' }) -join "`n"
Check "Check 23 flags the block-less probe and renders its Gregorian date" `
    ($handoffHit -match [regex]::Escape("is dated $(Iso $handoffProbe)")) `
    $handoffHit

Write-Host ""
if ($fail -gt 0) {
    Write-Host "FUTURE-DATE GUARD TEST: $pass passed, $fail FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "FUTURE-DATE GUARD TEST: $pass passed, 0 failed" -ForegroundColor Green
exit 0
