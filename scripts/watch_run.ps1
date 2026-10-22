# ORVION run watcher -- ON-DEMAND REPORTING ADAPTER (AGENTS.md section 7). It owns no truth.
#
# Follows a log written by `scripts/run_timed.ps1` and prints:
#   * the run's start and the watcher's own attach time, so a late watch is visible;
#   * every RESULT line, with the minutes since the run started and since the previous result;
#   * a heartbeat when the log has been silent for -QuietMinutes, naming the repository script the
#     runner is executing at that moment and its CPU time, so a long stage is distinguishable from
#     a stall, and an ETA from comparable past runs (or why there is none);
#   * RUNNER GONE when the runner's process has exited without writing its END line (killed or
#     crashed), and a notice when no runner has started at all;
#   * FINDINGS, each once per run and labelled by what the evidence supports: [confirmed] for a fact the
#     log and the history establish (a failure that also failed in earlier runs), [hypothesis] for a
#     comparison that needs a person to judge (a command run twice, a step or a run slower than its
#     history, steps every recent successful run had and this one lacks);
#   * at END, a comparison with the previous recorded run of the same -Run name, with both runs'
#     conditions, so a timing is never compared without knowing what else was running.
# With -Brief, for an agent's monitor, it prints only what needs attention - failures, findings,
# heartbeats, RUNNER GONE and the end - plus a progress line every -ProgressMinutes; everything else is
# still recorded.
#
# Every result, every TEST line a suite prints (`PASS <name>`, `FAIL <name>`, TAP `ok`/`not ok`), every
# evaluator stage (`TIME: STAGES`) and every finding is appended to a LOCAL timings file outside the
# repository, with the run's log as its evidence reference; a test's time is the time since the line
# before it, and a failed test is a test like any other, also printed and counted as a failure. That
# file is the one timing history: the evaluator appends the runs nobody timed (SPEC-283), and -Report
# reads it - where the time goes, the slowest tests and stages, which runs regressed, and which failures
# recur, each normalised by how often that run executes. It never exceeds -MaxBytes (10 MB, about
# 50,000 rows, measured to load in about a second): every append, the evaluator's or a watcher's, keeps
# the newest rows within half of it once it passes the limit (Add-TimingRows).
# What the watcher prints and writes to the history is redacted of values shaped like a known
# credential (Hide-Secret). The runner's log, which each row names as its evidence, is the run's RAW
# output and is not redacted; it stays where the agent wrote it.
# It exits 0 only when the run ended `END exit=0`; a run that ended non-zero, or a runner that died,
# exits 1, so a background notification never reports a failed run as a clean watch.
#
# It never retries, reruns, dismisses or approves anything, never classifies a failure's cause, and
# never changes a file but its own history. `-Finish` and `-Certify` remain the only verdicts, a
# finding is evidence for the reader to judge, and a [hypothesis] is never reported as a defect.
#
# Usage:
#   pwsh -NoProfile -File scripts/watch_run.ps1 -Log <file> -Run finish-control [-Brief]
#   pwsh -NoProfile -File scripts/watch_run.ps1 -Log <file> -Run finish-control -Eta    # one estimate, now
#   pwsh -NoProfile -File scripts/watch_run.ps1 -Report [-Run finish-control]          # the history
param(
    [string]$Log,
    [string]$Run,
    [double]$QuietMinutes = 5,
    [double]$PollSeconds = 10,
    [string]$Csv = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ORVION\timings.csv'),
    [switch]$Eta,
    [switch]$Report,
    [switch]$Brief,
    [double]$ProgressMinutes = 10,
    [long]$MaxBytes = 10MB
)

# RESULT VOCABULARY, derived from what the repository's scripts actually print:
#   * `check_agent_continuity.ps1` Invoke-Verification step lines: `PASS: <cmd>`, `FAILED: <cmd> (exit N)`;
#   * verdict lines `<LABEL>: <WORD>`, the words being every one a script prints outside its tests:
#     CLEAN, READY, PASSED, COMPLETE, DONE, PENDING, UNPROVEN, FAILED, BLOCKED, INCOMPLETE,
#     RECOVERY_EXHAUSTED, `NOT ...` and `N issue(s)` (scripts/*.ps1 and .workstation/*.ps1, 2026-10-09);
#   * `check_repository_consistency.ps1` issue lines, indented `  <MULTI WORD LABEL>: ...`;
#   * `CODE:` / `EVIDENCE:` refusals, suite totals `N passed, M failed`, TAP `not ok`, `ERROR:`,
#     mutation verdicts, and the runner's own `END exit=N`;
#   * the evaluator's `TIME:` lines for each run, stage, profile and verification command (SPEC-283).
# Structural families rather than a hand list of labels, so a new label of a known family is still
# reported. CASE-SENSITIVE on purpose: with PowerShell's default case-insensitive `-match`, `FAIL\b`
# matches the prose "fail-closed". Per-assertion `PASS 101 ...` lines are deliberately not results;
# every `FAIL` is. Both are TESTS, recorded with their own time; a failed one is also printed. A line is
# judged a test FIRST, so `FAIL <name>` and TAP `not ok` - which the result vocabulary also matches - are
# timed and reported as the tests they are. A TAP `not ok` with a TODO or SKIP directive is not a
# failure (TAP 14 specification, "Directives").
$script:ResultRx = '(^(PASS|FAILED|SKIPPED?): .*|^\s*[A-Z][A-Z0-9_-]*(?: [A-Z0-9_-]+)*: (CLEAN|READY|PASSED|COMPLETE|DONE|PENDING|UNPROVEN|FAILED|BLOCKED|INCOMPLETE|RECOVERY_EXHAUSTED|UNREADABLE|NOT [A-Z]+|\d+ issue).*|^\s+[A-Z][A-Z0-9-]*(?: [A-Z0-9-]+)+: .*|^(CODE|EVIDENCE): (?!none\b).*|^\s*FAIL\b.*|\b\d+ passed, \d+ failed\b|\bnot ok\b|\bERROR:.*|ALL CHECKS PASSED|\bKILLED\b|\bSURVIVED\b|^END exit=\d+|^TIME: .*)'
function Test-ResultLine([string]$Body) { $Body -cmatch $script:ResultRx }
$script:TestRx = '^\s*(PASS|FAIL)\s+[^:\s]\S*|^(not )?ok \d+\b'
function Test-TestLine([string]$Body) { $Body -cmatch $script:TestRx }
$script:FailedTestRx = '^\s*FAIL\s|^not ok\b(?!.*#\s*(?i:todo|skip)\b)'
# What -Brief still prints: anything that is or may be a failure, and the end. A pass prints nothing.
$script:AttentionRx = '(\bFAIL|\bFAILED\b|BLOCKED|^CODE: |\bnot ok\b|\bERROR:|\bSURVIVED\b|INCOMPLETE|UNPROVEN|RECOVERY_EXHAUSTED|\b[1-9]\d* failed\b|^END exit=|CERTIFY: )'

# The runner's START line: `[yyyy-MM-dd HH:mm:ss] START pid=N <environment> | <command>`.
function Read-StartLine([string]$Line) {
    $m = [regex]::Match($Line, '^\[(?<at>\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\] START pid=(?<pid>\d+) (?<env>[^|]*?) \| ')
    if (-not $m.Success) { return $null }
    [pscustomobject]@{ At = [datetime]$m.Groups['at'].Value; Pid = [int]$m.Groups['pid'].Value; Env = $m.Groups['env'].Value.Trim() }
}

# The newest live descendant of the runner, named by the repository script it runs when it runs one.
function Get-RunningStage([int]$RunnerPid) {
    $all = @(Get-CimInstance Win32_Process)
    $kids = @{}; foreach ($p in $all) { $kids[[int]$p.ParentProcessId] += @($p) }
    $desc = [Collections.Generic.List[object]]::new(); $queue = [Collections.Generic.Queue[int]]::new(); $queue.Enqueue($RunnerPid)
    while ($queue.Count) { foreach ($c in @($kids[$queue.Dequeue()])) { if ($c) { $desc.Add($c); $queue.Enqueue([int]$c.ProcessId) } } }
    $scripted = @($desc | Where-Object { $_.CommandLine -match 'scripts[\\/][\w.-]+\.ps1' } | Sort-Object CreationDate)
    $stage = if ($scripted.Count) { $scripted[-1] } elseif ($desc.Count) { @($desc | Sort-Object CreationDate)[-1] } else { $null }
    if (-not $stage) { return 'the runner has no child process' }
    $name = if ($stage.CommandLine -match '(scripts[\\/][\w.-]+\.ps1)') { $Matches[1] } else { $stage.Name }
    $cpu = (Get-Process -Id $stage.ProcessId -ErrorAction SilentlyContinue).CPU
    'running {0} since {1} (cpu {2:N0}s)' -f $name, $stage.CreationDate.ToString('HH:mm:ss'), $cpu
}

# ---- history: the timings file, read as runs (SPEC-283) ---------------------------------------------
# A value that looks like a credential never reaches the screen or the history.
function Hide-Secret([string]$Text) {
    # GitHub's documented token prefixes (ghp_, gho_, ghu_, ghs_, ghr_, github_pat_), common API keys and
    # JWTs by shape; then any `key=value` or `key: value` whose key names a credential, and a bearer value.
    $t = $Text -replace '\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_\w{20,}|sk-[A-Za-z0-9_-]{20,}|eyJ[\w-]{10,}\.[\w-]{10,}\.[\w-]+)', '<redacted>'
    $t = $t -replace '(?i)\bbearer\s+(?!<redacted>)\S+', 'Bearer <redacted>'
    $t -replace '(?i)\b(token|secret|password|passwd|api[_-]?key|authorization)(\s*[:=]\s*)(?!Bearer <redacted>)(?!<redacted>)\S+', '$1$2<redacted>'
}
# A step's identity across runs: its text without the elapsed time it carries or the evidence after ` :: `.
function Get-StepKey([string]$Step) { ((($Step -replace ' :: .*$', '') -replace ' \d\d:\d\d:\d\d\s*$', '') -replace '\s+', ' ').Trim() }
function ConvertTo-Minutes([string]$Value) { [double]::Parse($Value, [Globalization.NumberStyles]::Float -bor [Globalization.NumberStyles]::AllowThousands, [Globalization.CultureInfo]::InvariantCulture) }
function Format-Minutes([double]$Value) { $Value.ToString('0.0###', [Globalization.CultureInfo]::InvariantCulture) }
function Get-Median([double[]]$Values) { $s = @($Values | Sort-Object); if (-not $s.Count) { return $null }; if ($s.Count % 2) { $s[($s.Count - 1) / 2] } else { ($s[$s.Count / 2 - 1] + $s[$s.Count / 2]) / 2 } }
# A `TIME:` line states its own duration, which is truer than the gap between two log stamps.
function Get-StatedMinutes([string]$Step) { if ($Step -match ' (\d\d):(\d\d):(\d\d)\s*$') { [int]$Matches[1] * 60 + [int]$Matches[2] + [int]$Matches[3] / 60 } else { $null } }
# `TIME: STAGES <mode> a=1.23s b=0.40s` as one row per stage.
function Split-Stages([string]$Body) {
    $m = [regex]::Match($Body, '^TIME: STAGES (?<mode>.+?) (?=\S+=[\d.]+s\b)'); if (-not $m.Success) { return }
    foreach ($s in [regex]::Matches($Body, '(?<n>[^\s=]+)=(?<v>[\d.]+)s\b')) { [pscustomobject]@{ Step = "STAGE $($m.Groups['mode'].Value) $($s.Groups['n'].Value)"; Minutes = [double]::Parse($s.Groups['v'].Value, [Globalization.CultureInfo]::InvariantCulture) / 60 } }
}
function Get-StepKind([string]$Step) {
    if ($Step -like 'END exit=*') { 'end' } elseif ($Step -like 'finding *') { 'finding' } elseif ($Step -like 'STAGE *') { 'stage' }
    elseif ($Step -like 'TIME: *') { 'time' } elseif (Test-TestLine $Step) { 'test' } else { 'result' }
}
# Every run of one -Run name but $Exclude: its steps, an index of each step's first occurrence, whether it
# ended, and whether it ended `END exit=0`.
function Read-History([object[]]$Rows, [string]$Name, [string]$Exclude = '') {
    foreach ($g in @($Rows | Where-Object { $_.run -eq $Name -and $_.date -ne $Exclude } | Group-Object date)) {
        $steps = @($g.Group | ForEach-Object { [pscustomobject]@{ Key = (Get-StepKey $_.step); T = (ConvertTo-Minutes $_.elapsed_min); Delta = (ConvertTo-Minutes $_.delta_min); Step = $_.step; Kind = (Get-StepKind $_.step) } })
        $index = @{}; foreach ($s in $steps) { if (-not $index.ContainsKey($s.Key)) { $index[$s.Key] = $s } }
        $end = @($steps | Where-Object { $_.Kind -eq 'end' }) | Select-Object -Last 1
        [pscustomobject]@{ Date = $g.Name; Ended = [bool]$end; Ok = [bool]($end -and $end.Step -match '^END exit=0\b'); Total = $(if ($end) { $end.T } else { $null }); Steps = $steps; Index = $index }
    }
}
# Minutes left, from what the last 10 comparable SUCCESSFUL runs still had to do after this step: failed
# and unfinished runs distort a duration, and a median with its range, not a mean, describes a long-tailed
# one (CI practice: Jenkins, TeamCity, Metabase). Two runs at least, or no estimate - one sample is a
# guess - and fewer than five are labelled a low sample.
function Get-Recent([object[]]$History, [int]$N) { @($History | Where-Object { $_.Ok } | Sort-Object Date | Select-Object -Last $N) }
function Get-Eta([object[]]$History, [string]$Key, [double]$Since, [double]$Now, [int]$TestCount = 0) {
    $byCount = $TestCount -gt 0 -and (Test-TestLine $Key)
    $countLabel = ''
    if ($byCount) {
        $samples = @(foreach ($h in (Get-Recent $History 10)) {
            $testRows = @($h.Steps | Where-Object Kind -eq 'test')
            if ($testRows.Count -ge $TestCount) {
                $s = $testRows[$TestCount - 1]
                if ($s.Key -ceq $Key) { [pscustomobject]@{ Count = $testRows.Count; Left = $h.Total - $s.T - $Since } }
            }
        })
        if ($samples.Count -lt 2) { return "eta: none - $($samples.Count) comparable successful run(s) at observed test count $TestCount" }
        $totals = @($samples | ForEach-Object { $_.Count } | Sort-Object -Unique)
        if ($totals.Count -ne 1) { return 'eta: none - incompatible historical test totals at this observed test count' }
        $left = @($samples | ForEach-Object { $_.Left })
        $countLabel = ", by observed test count $TestCount (historical total $($totals[0]) tests)"
    } else {
        $left = @(foreach ($h in (Get-Recent $History 10)) {
            if ($Key) { $s = $h.Index[$Key]; if ($s) { $h.Total - $s.T - $Since } } else { $h.Total - $Now }
        })
        # Non-test stages retain the existing measured step/total fallback; tests never guess a count match.
        if ($left.Count -lt 2 -and $Key) { return Get-Eta $History '' $Since $Now }
    }
    if ($left.Count -lt 2) { return "eta: none - $($left.Count) comparable successful run(s) in the history$(if ($Key) { ' reached this step' })" }
    $s = @($left | Sort-Object)
    'eta: ~{0:N1} min left (median of {1} comparable successful runs{5}{4}; range {2:N1} to {3:N1})' -f [Math]::Max(0, (Get-Median $s)), $s.Count, [Math]::Max(0, $s[0]), [Math]::Max(0, $s[-1]), $(if ($s.Count -lt 5) { ', low sample' }), $(if ($byCount) { $countLabel } elseif (-not $Key) { ', by run totals' })
}
# Findings on one recorded line. $State dedupes them per run and counts this run's commands and steps.
function New-FindingState { [pscustomobject]@{ Said = [Collections.Generic.HashSet[string]]::new(); Keys = [Collections.Generic.HashSet[string]]::new(); Commands = @{} } }
function Get-StepFindings([object[]]$History, $State, [string]$Body, [double]$Delta) {
    $key = Get-StepKey $Body; [void]$State.Keys.Add($key); $found = @()
    if ($Body -cmatch '^(FAILED: |CODE: )|\bERROR:' -or $Body -cmatch $script:FailedTestRx) {
        $prior = @($History | Where-Object { $_.Index.ContainsKey($key) })
        if ($prior.Count) { $found += "finding [confirmed] recurring failure: $key - also in $($prior.Count) of $(@($History).Count) earlier runs" }
    }
    if ($Body -cmatch '^(PASS|FAILED): (?<cmd>.+?)(?: \(exit \d+\))?$') {
        $cmd = $Matches['cmd']; $State.Commands[$cmd] = 1 + [int]$State.Commands[$cmd]
        if ($State.Commands[$cmd] -eq 2) { $found += "finding [hypothesis] repeated execution: $cmd ran twice in this run - wasteful unless its profile lists it twice on purpose" }
    }
    $d = @(foreach ($h in (Get-Recent $History 10)) { $s = $h.Index[$key]; if ($s) { $s.Delta } })
    if ($d.Count -ge 3) { $med = Get-Median $d; if ($Delta -gt [Math]::Max(1.5 * $med, $med + 1)) { $found += ('finding [hypothesis] slow step: {0} took {1:N1} min against a median of {2:N1} over {3} successful runs' -f $key, $Delta, $med, $d.Count) } }
    @($found | Where-Object { $State.Said.Add($_) })
}
# At END: steps each of the last successful runs had and this one lacks (one finding, however many), and
# a run slower than they were.
function Get-EndFindings([object[]]$History, $State, [double]$Total) {
    $ok = Get-Recent $History 5; $found = @()
    if ($ok.Count -ge 3) {
        $absent = @($ok[0].Index.Keys | Where-Object { $_ -notlike 'END exit=*' -and $_ -notlike 'finding *' -and -not $State.Keys.Contains($_) } | Where-Object { $k = $_; -not @($ok | Where-Object { -not $_.Index.ContainsKey($k) }).Count } | Sort-Object)
        if ($absent.Count -eq 1) { $found += "finding [hypothesis] expected step absent: $($absent[0]) - present in each of the last $($ok.Count) successful runs" }
        elseif ($absent.Count) { $found += "finding [hypothesis] expected steps absent: $($absent.Count) steps each of the last $($ok.Count) successful runs had (first: $($absent[0]))" }
        $med = Get-Median @($ok | ForEach-Object { $_.Total })
        if ($Total -gt [Math]::Max(1.25 * $med, $med + 2)) { $found += ('finding [hypothesis] slower run: {0:N1} min against a median of {1:N1} over the last {2} successful runs' -f $Total, $med, $ok.Count) }
    }
    @($found | Where-Object { $State.Said.Add($_) })
}
# The history, summarised: where the time goes, the slowest tests and stages, which runs regressed, which
# failures recur. A failure rate is per run of its own -Run name, so a run that executes often is not
# ranked worse for being run. The top lists are views; every row stays in the history.
function Format-Report([object[]]$Rows, [string]$Only) {
    $rates = @()
    foreach ($n in @($Rows | ForEach-Object { $_.run } | Sort-Object -Unique | Where-Object { -not $Only -or $_ -eq $Only })) {
        $h = @(Read-History $Rows $n); $ok = @($h | Where-Object { $_.Ok } | Sort-Object Date); $ended = @($h | Where-Object { $_.Ended })
        $line = '{0}: {1} runs, {2} ended, {3} succeeded' -f $n, $h.Count, $ended.Count, $ok.Count
        if ($ok.Count) {
            $t = @($ok | ForEach-Object { $_.Total } | Sort-Object); $med = Get-Median $t
            $line += '; median {0:N2} min, p90 {1:N2}' -f $med, $t[[Math]::Max(0, [Math]::Ceiling(0.9 * $t.Count) - 1)]
            if ($ok.Count -ge 3 -and $ok[-1].Total -gt [Math]::Max(1.25 * $med, $med + 2)) { $line += ('; REGRESSION [hypothesis]: latest {0:N2} min' -f $ok[-1].Total) }
        }
        $line
        $share = @{}; $sum = 0.0
        foreach ($r in $ok) { foreach ($s in $r.Steps) { if ($s.Kind -ne 'result') { continue }; $share[$s.Key] += $s.Delta; $sum += $s.Delta } }
        if ($sum -gt 0) { foreach ($e in @($share.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3)) { '  time {0,3:N0}%  {1}' -f (100 * $e.Value / $sum), $e.Key } }
        # A stage's or a test's time is its own whether its run succeeded or not, so a failed test is ranked too.
        foreach ($kind in 'stage', 'test') {
            $per = @{}; foreach ($r in $h) { foreach ($s in @($r.Steps | Where-Object { $_.Kind -eq $kind })) { $per[$s.Key] += @($s.Delta) } }
            foreach ($e in @($per.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Key = $_.Key; Med = (Get-Median $_.Value) } } | Sort-Object Med -Descending | Select-Object -First 5)) { '  slowest {0} {1,7:N3} min  {2}' -f $kind, $e.Med, $e.Key }
        }
        foreach ($k in @($h | ForEach-Object { @($_.Steps | Where-Object { $_.Step -cmatch '^(FAILED: |CODE: |END exit=[1-9])' -or $_.Step -cmatch $script:FailedTestRx } | ForEach-Object { $_.Key } | Select-Object -Unique) } | Group-Object)) {
            $rates += [pscustomobject]@{ Run = $n; Key = $k.Name; Runs = $k.Count; Of = $h.Count; Rate = $k.Count / [Math]::Max(1, $h.Count) }
        }
        $f = @($h | ForEach-Object { $_.Steps } | Where-Object { $_.Kind -eq 'finding' } | ForEach-Object { $_.Key -replace '^(finding \[\w+\] [^:]+):.*$', '$1' } | Group-Object)
        if ($f.Count) { '  findings: ' + (@($f | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join '; ') }
    }
    $ranked = @($rates | Where-Object { $_.Of -ge 3 } | Sort-Object @{ Expression = 'Rate'; Descending = $true }, @{ Expression = 'Of'; Descending = $true } | Select-Object -First 8)
    if ($ranked.Count) { 'failures by rate (runs affected / runs of that name; names with at least 3 runs):' }
    foreach ($x in $ranked) { '  {0,3:N0}%  {1} in {2} of {3} {4} runs{5}' -f (100 * $x.Rate), $x.Key, $x.Runs, $x.Of, $x.Run, $(if ($x.Runs -ge 2) { ' - investigate [hypothesis]: a Skill, Guard or Hook is a candidate only once the Improvement Loop shows need, gap and value' }) }
}
# The history's one write path, shared VERBATIM with scripts/check_agent_continuity.ps1 (scripts/watch_selftest.ps1
# holds the two copies equal). A named mutex per history file serialises every writer and the watcher's
# reads across processes, so an append never interleaves with another append or with a trim. The bound
# holds after every append: past $MaxBytes the history keeps its newest whole rows within half of it,
# written to a temporary file beside it and moved over it, so the history is never rewritten in place.
function Use-TimingHistory([string]$Path, [scriptblock]$Body) {
    $id = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Path).ToLowerInvariant())))
    $lock = [Threading.Mutex]::new($false, 'Global\ORVION-timings-' + $id.Substring(0, 32))
    try {
        # An abandoned mutex (its holder was killed) is acquired: the history is only ever replaced whole.
        try { if (-not $lock.WaitOne(15000)) { throw "the timing history $Path stayed locked for 15 s" } } catch [Threading.AbandonedMutexException] { }
        try { & $Body } finally { $lock.ReleaseMutex() }
    } finally { $lock.Dispose() }
}
function Add-TimingRows([string]$Path, [string[]]$Rows, [long]$MaxBytes) {
    Use-TimingHistory $Path {
        if (-not [IO.File]::Exists($Path)) { [IO.File]::WriteAllText($Path, 'run,date,step,elapsed_min,delta_min,env' + [Environment]::NewLine) }
        if ($Rows.Count) { [IO.File]::AppendAllText($Path, ($Rows -join [Environment]::NewLine) + [Environment]::NewLine) }
        if ([IO.FileInfo]::new($Path).Length -le $MaxBytes) { return }
        $b = [IO.File]::ReadAllBytes($Path); $h = [Array]::IndexOf($b, [byte]10) + 1
        $n = [Array]::IndexOf($b, [byte]10, [int][Math]::Max($h, $b.Length - [Math]::Floor($MaxBytes / 2))); $cut = if ($n -lt 0) { $b.Length } else { $n + 1 }
        $tmp = "$Path.tmp"; $f = [IO.File]::Create($tmp); try { $f.Write($b, 0, $h); $f.Write($b, $cut, $b.Length - $cut) } finally { $f.Dispose() }
        [IO.File]::Move($tmp, $Path, $true)
        'history: kept the newest {0:N0} of {1:N0} bytes of rows (limit {2:N0})' -f ($b.Length - $cut), ($b.Length - $h), $MaxBytes
    }
}
function Read-TimingRows([string]$Path) {
    try { @((Use-TimingHistory $Path { [IO.File]::ReadAllLines($Path) }) | ConvertFrom-Csv) } catch { Write-Warning "history: not read - $($_.Exception.Message)"; @() }
}
function Write-Row([string]$Path, [string]$Name, [string]$Identity, [string]$Step, [double]$T, [double]$Delta, [string]$Conditions) {
    try { Add-TimingRows $Path @('"{0}","{1}","{2}",{3},{4},"{5}"' -f $Name, $Identity, ($Step -replace '"', "'"), (Format-Minutes $T), (Format-Minutes $Delta), $Conditions) $MaxBytes }
    catch { "history: row not written - $($_.Exception.Message)" }
}

if ($MyInvocation.InvocationName -eq '.') { return }   # dot-sourced by scripts/watch_selftest.ps1 for the functions above
$ErrorActionPreference = 'Continue'
[void][IO.Directory]::CreateDirectory((Split-Path $Csv -Parent))
try { Add-TimingRows $Csv @() $MaxBytes } catch { "history: not prepared - $($_.Exception.Message)" }   # creates it; bounds one an older writer left over its limit
if ($Report) { Format-Report @(Read-TimingRows $Csv) $Run; exit 0 }
if (-not $Log -or -not $Run) { throw 'usage: watch_run.ps1 -Log <run_timed log> -Run <stable name> [-Brief] [-Eta] | -Report [-Run <name>]' }
$Log = [IO.Path]::GetFullPath($Log, (Get-Location).Path)
$StampRx = '^\[\+\s*(?<t>[\d.]+) min\] (?<body>.*)$'

if ($Eta) {
    $first = if (Test-Path -LiteralPath $Log) { Read-StartLine (Get-Content -LiteralPath $Log -TotalCount 1 -Encoding utf8) }
    if (-not $first) { 'eta: none - no START line in the log yet'; exit 0 }
    $lines = @(Get-Content -LiteralPath $Log -Encoding utf8 | ForEach-Object { [regex]::Match($_, $StampRx) } | Where-Object { $_.Success -and ((Test-ResultLine $_.Groups['body'].Value) -or (Test-TestLine $_.Groups['body'].Value)) })
    $now = ((Get-Date) - $first.At).TotalMinutes
    $hist = @(Read-History @(Read-TimingRows $Csv) $Run $first.At.ToString('yyyy-MM-dd HH:mm:ss'))
    if ($lines.Count -and $lines[-1].Groups['body'].Value -match '^END exit=') { "eta: the run has ended ($($lines[-1].Groups['body'].Value))"; exit 0 }
    if ($lines.Count) { $t = [double]::Parse($lines[-1].Groups['t'].Value, [Globalization.CultureInfo]::InvariantCulture); Get-Eta $hist (Get-StepKey $lines[-1].Groups['body'].Value) ($now - $t) $now (@($lines | Where-Object { Test-TestLine $_.Groups['body'].Value }).Count) } else { Get-Eta $hist '' 0 $now }
    exit 0
}

$wait = [Diagnostics.Stopwatch]::StartNew(); $lastNote = 0.0; $start = $null
while (-not $start) {
    if (Test-Path -LiteralPath $Log) { $start = Read-StartLine (Get-Content -LiteralPath $Log -TotalCount 1 -Encoding utf8) }
    if ($start) { break }
    if ($wait.Elapsed.TotalMinutes - $lastNote -ge $QuietMinutes) { $lastNote = $wait.Elapsed.TotalMinutes; 'heartbeat: no log or no START line after {0:N1} min - the runner may not have started' -f $wait.Elapsed.TotalMinutes }
    Start-Sleep -Seconds ([Math]::Min(2, $PollSeconds))
}
$identity = $start.At.ToString('yyyy-MM-dd HH:mm:ss')   # identifies THIS run; a re-armed watcher computes the same value
'watching {0} (started {1}, attached {2}, runner pid {3}; {4})' -f $Run, $identity, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $start.Pid, $start.Env
$rows = @(Read-TimingRows $Csv); $have = @{}; $rows | ForEach-Object { $have[($_.run, $_.date, $_.step, $_.elapsed_min) -join '|'] = 1 }
$history = @(Read-History $rows $Run $identity); $state = New-FindingState; $conditions = "$($start.Env) log=$Log"; $lastKey = ''
function Save-Step([string]$Step, [double]$T, [double]$Delta) {
    $key = ($Run, $identity, $Step, (Format-Minutes $T)) -join '|'
    if (-not $have.ContainsKey($key)) { $have[$key] = 1; Write-Row $Csv $Run $identity $Step $T $Delta $conditions }
}
$replaying = $true; $seen = 0; $last = 0.0; $prevLine = 0.0; $tests = 0; $results = 0; $failed = 0; $lastProgress = 0.0; $quiet = [Diagnostics.Stopwatch]::StartNew()
while ($true) {
    $lines = @(Get-Content -LiteralPath $Log -Encoding utf8)
    if ($lines.Count -gt $seen) {
        foreach ($line in $lines[$seen..($lines.Count - 1)]) {
            $m = [regex]::Match($line, $StampRx)
            if (-not $m.Success) { continue }
            $t = [double]::Parse($m.Groups['t'].Value, [Globalization.CultureInfo]::InvariantCulture); $body = Hide-Secret $m.Groups['body'].Value
            $sinceLine = $t - $prevLine; $prevLine = $t
            if ($Brief -and ((-not $replaying -and $t - $lastProgress -ge $ProgressMinutes) -or ($replaying -and $body -match '^END exit='))) {
                $lastProgress = $t; $now = ((Get-Date) - $start.At).TotalMinutes
                'progress: {0:N1} min - {1} tests and {2} results so far, {3} failing; {4}' -f $t, $tests, $results, $failed, (Get-Eta $history $lastKey ($now - $t) $now $tests)
            }
            $step = ($body.Substring(0, [Math]::Min(160, $body.Length))) -replace '"', "'"
            if (Test-TestLine $body) {
                $tests++; $lastKey = Get-StepKey $step; Save-Step $step $t $sinceLine
                if ($body -cmatch $script:FailedTestRx) { $failed++; '[{0,5:N1} min | +{1:N1}] {2}' -f $t, $sinceLine, $step }
                foreach ($f in (Get-StepFindings $history $state $step $sinceLine)) { $f; Save-Step $f $t 0 }
                continue
            }
            if (-not (Test-ResultLine $body)) { continue }
            $results++; if ($body -cmatch $script:AttentionRx -and $body -notmatch '^END exit=0\b|\b0 failed\b|: READY\b') { $failed++ }
            $delta = $t - $last; $last = $t; $lastKey = Get-StepKey $step
            if (-not $Brief -or $body -cmatch $script:AttentionRx) { '[{0,5:N1} min | +{1:N1}] {2}' -f $t, $delta, $step }
            $stages = @(Split-Stages $body)
            if ($stages.Count) { $at = $t; foreach ($s in $stages) { Save-Step $s.Step $at $s.Minutes } }
            else { $stated = Get-StatedMinutes $step; Save-Step $step $t $(if ($null -ne $stated -and $step -like 'TIME: *') { $stated } else { $delta }) }
            $found = if ($body -match '^END exit=') { Get-EndFindings $history $state $t } else { Get-StepFindings $history $state $step $delta }
            foreach ($f in $found) { $f; Save-Step $f $t 0 }
            if ($body -match '^END exit=') {
                $prev = Read-TimingRows $Csv | Where-Object { $_.run -eq $Run -and $_.step -like 'END exit=*' -and $_.date -ne $identity } | Select-Object -Last 1
                if ($prev) { 'compare: this run {0:N1} min [{1}] vs previous {2} min on {3} [{4}]' -f $t, $start.Env, $prev.elapsed_min, $prev.date, $prev.env }
                else { "compare: first recorded run of '$Run' ($('{0:N1}' -f $t) min) [$($start.Env)]" }
                exit [int]($body -notmatch '^END exit=0\b')
            }
        }
        if($replaying){
            if($Brief-and$prevLine-$lastProgress-ge$ProgressMinutes){
                $lastProgress=$prevLine;$now=((Get-Date)-$start.At).TotalMinutes
                'progress: {0:N1} min - {1} tests and {2} results so far, {3} failing; {4}' -f $prevLine,$tests,$results,$failed,(Get-Eta $history $lastKey ($now-$prevLine) $now $tests)
            }
            $lastProgress=$prevLine;$replaying=$false
        }
        $seen = $lines.Count; $quiet.Restart()
    } elseif (-not (Get-Process -Id $start.Pid -ErrorAction SilentlyContinue)) {
        # Re-read once: the END line may have landed between the read above and this check.
        if (@(Get-Content -LiteralPath $Log -Encoding utf8).Count -gt $seen) { continue }
        'RUNNER GONE: process {0} exited without an END line after {1:N1} min (last result at {2:N1} min) - the run did not finish' -f $start.Pid, ((Get-Date) - $start.At).TotalMinutes, $last
        exit 1
    } elseif ($quiet.Elapsed.TotalMinutes -ge $QuietMinutes) {
        $now = ((Get-Date) - $start.At).TotalMinutes
        'heartbeat: no new output for {0:N1} min (last result at {1:N1} min) - {2}; {3}' -f $quiet.Elapsed.TotalMinutes, $last, (Get-RunningStage $start.Pid), (Get-Eta $history $lastKey ($now - $prevLine) $now $tests)
        $quiet.Restart()
    }
    Start-Sleep -Seconds $PollSeconds
}
