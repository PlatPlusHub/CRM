# ORVION run watcher -- ON-DEMAND REPORTING ADAPTER (AGENTS.md section 7). It owns no truth.
#
# Follows a log written by `scripts/run_timed.ps1` and prints:
#   * every RESULT line, with the minutes since the run started and since the previous result;
#   * a heartbeat when the log has been silent for -QuietMinutes, naming the repository script the
#     runner is executing at that moment and its CPU time, so a long stage is distinguishable from
#     a stall;
#   * RUNNER GONE when the runner's process has exited without writing its END line (killed or
#     crashed), and a notice when no runner has started at all;
#   * at END, a comparison with the previous recorded run of the same -Run name, with both runs'
#     conditions, so a timing is never compared without knowing what else was running.
# Each reported result is appended to a LOCAL timings file outside the repository.
#
# It never retries, reruns, dismisses, classifies or approves anything. `-Finish` and `-Certify`
# remain the only verdicts, and a reported line is evidence for the reader to judge.
#
# Usage:
#   pwsh -NoProfile -File scripts/watch_run.ps1 -Log <file> -Run finish-control
param(
    [string]$Log,
    [string]$Run,
    [double]$QuietMinutes = 5,
    [double]$PollSeconds = 10,
    [string]$Csv = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ORVION\timings.csv')
)

# RESULT VOCABULARY, derived from what the repository's scripts actually print:
#   * `check_agent_continuity.ps1` Invoke-Verification step lines: `PASS: <cmd>`, `FAILED: <cmd> (exit N)`;
#   * verdict lines `<LABEL>: <WORD>`, the words being every one a script prints outside its tests:
#     CLEAN, READY, PASSED, COMPLETE, DONE, PENDING, UNPROVEN, FAILED, BLOCKED, INCOMPLETE,
#     RECOVERY_EXHAUSTED, `NOT ...` and `N issue(s)` (scripts/*.ps1 and .workstation/*.ps1, 2026-10-09);
#   * `check_repository_consistency.ps1` issue lines, indented `  <MULTI WORD LABEL>: ...`;
#   * `CODE:` / `EVIDENCE:` refusals, suite totals `N passed, M failed`, TAP `not ok`, `ERROR:`,
#     mutation verdicts, and the runner's own `END exit=N`.
# Structural families rather than a hand list of labels, so a new label of a known family is still
# reported. CASE-SENSITIVE on purpose: with PowerShell's default case-insensitive `-match`, `FAIL\b`
# matches the prose "fail-closed". Per-assertion `PASS 101 ...` lines are deliberately not results;
# every `FAIL` is.
$script:ResultRx = '(^(PASS|FAILED|SKIPPED?): .*|^\s*[A-Z][A-Z0-9_-]*(?: [A-Z0-9_-]+)*: (CLEAN|READY|PASSED|COMPLETE|DONE|PENDING|UNPROVEN|FAILED|BLOCKED|INCOMPLETE|RECOVERY_EXHAUSTED|NOT [A-Z]+|\d+ issue).*|^\s+[A-Z][A-Z0-9-]*(?: [A-Z0-9-]+)+: .*|^(CODE|EVIDENCE): (?!none\b).*|^\s*FAIL\b.*|\b\d+ passed, \d+ failed\b|\bnot ok\b|\bERROR:.*|ALL CHECKS PASSED|\bKILLED\b|\bSURVIVED\b|^END exit=\d+)'
function Test-ResultLine([string]$Body) { $Body -cmatch $script:ResultRx }

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

if ($MyInvocation.InvocationName -eq '.') { return }   # dot-sourced by scripts/watch_selftest.ps1 for the functions above
if (-not $Log -or -not $Run) { throw 'usage: watch_run.ps1 -Log <run_timed log> -Run <stable name>' }
$ErrorActionPreference = 'Continue'
$Log = [IO.Path]::GetFullPath($Log, (Get-Location).Path)
[void][IO.Directory]::CreateDirectory((Split-Path $Csv -Parent))
if (-not (Test-Path -LiteralPath $Csv)) { 'run,date,step,elapsed_min,delta_min,env' | Out-File -LiteralPath $Csv -Encoding utf8 }

$wait = [Diagnostics.Stopwatch]::StartNew(); $lastNote = 0.0; $start = $null
while (-not $start) {
    if (Test-Path -LiteralPath $Log) { $start = Read-StartLine (Get-Content -LiteralPath $Log -TotalCount 1 -Encoding utf8) }
    if ($start) { break }
    if ($wait.Elapsed.TotalMinutes - $lastNote -ge $QuietMinutes) { $lastNote = $wait.Elapsed.TotalMinutes; 'heartbeat: no log or no START line after {0:N1} min - the runner may not have started' -f $wait.Elapsed.TotalMinutes }
    Start-Sleep -Seconds ([Math]::Min(2, $PollSeconds))
}
$identity = $start.At.ToString('yyyy-MM-dd HH:mm:ss')   # identifies THIS run; a re-armed watcher computes the same value
'watching {0} (started {1}, runner pid {2}; {3})' -f $Run, $identity, $start.Pid, $start.Env
$have = @{}; Import-Csv -LiteralPath $Csv | ForEach-Object { $have[($_.run, $_.date, $_.step, $_.elapsed_min) -join '|'] = 1 }
$seen = 0; $last = 0.0; $quiet = [Diagnostics.Stopwatch]::StartNew()
while ($true) {
    $lines = @(Get-Content -LiteralPath $Log -Encoding utf8)
    if ($lines.Count -gt $seen) {
        foreach ($line in $lines[$seen..($lines.Count - 1)]) {
            $m = [regex]::Match($line, '^\[\+\s*(?<t>[\d.]+) min\] (?<body>.*)$')
            if (-not $m.Success) { continue }
            $t = [double]$m.Groups['t'].Value; $body = $m.Groups['body'].Value
            if (-not (Test-ResultLine $body)) { continue }
            $step = ($body.Substring(0, [Math]::Min(160, $body.Length))) -replace '"', "'"
            $delta = $t - $last; $last = $t
            '[{0,5:N1} min | +{1:N1}] {2}' -f $t, $delta, $step
            $key = ($Run, $identity, $step, ('{0:N1}' -f $t)) -join '|'
            if (-not $have.ContainsKey($key)) {
                $have[$key] = 1
                '"{0}","{1}","{2}",{3:N1},{4:N1},"{5}"' -f $Run, $identity, $step, $t, $delta, $start.Env | Out-File -LiteralPath $Csv -Append -Encoding utf8
            }
            if ($body -match '^END exit=') {
                $prev = Import-Csv -LiteralPath $Csv | Where-Object { $_.run -eq $Run -and $_.step -like 'END exit=*' -and $_.date -ne $identity } | Select-Object -Last 1
                if ($prev) { 'compare: this run {0:N1} min [{1}] vs previous {2} min on {3} [{4}]' -f $t, $start.Env, $prev.elapsed_min, $prev.date, $prev.env }
                else { "compare: first recorded run of '$Run' ($('{0:N1}' -f $t) min) [$($start.Env)]" }
                exit 0
            }
        }
        $seen = $lines.Count; $quiet.Restart()
    } elseif (-not (Get-Process -Id $start.Pid -ErrorAction SilentlyContinue)) {
        # Re-read once: the END line may have landed between the read above and this check.
        if (@(Get-Content -LiteralPath $Log -Encoding utf8).Count -gt $seen) { continue }
        'RUNNER GONE: process {0} exited without an END line after {1:N1} min (last result at {2:N1} min) - the run did not finish' -f $start.Pid, ((Get-Date) - $start.At).TotalMinutes, $last
        exit 1
    } elseif ($quiet.Elapsed.TotalMinutes -ge $QuietMinutes) {
        'heartbeat: no new output for {0:N1} min (last result at {1:N1} min) - {2}' -f $quiet.Elapsed.TotalMinutes, $last, (Get-RunningStage $start.Pid)
        $quiet.Restart()
    }
    Start-Sleep -Seconds $PollSeconds
}
