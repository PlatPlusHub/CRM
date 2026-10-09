# Self-test for scripts/run_timed.ps1, scripts/watch_run.ps1 and scripts/watch_ci.ps1 -- ON DEMAND,
# run whenever one of them changes.
#
# Not a permanent control: no profile, hook or workflow runs it. It drives REAL processes (a runner,
# a silent stage, a killed runner) and checks what the watcher prints, then removes each load-bearing
# rule in a temporary copy and requires the case that depends on it to FAIL. A mutant whose text
# replacement did not apply is a failure, never a silent pass. Everything is written under the
# system temp directory; nothing in the repository is touched, and every process it starts is
# stopped before it exits. The CI cases judge the watcher's functions on fixtures and on the workflow
# files at real SHAs (local git only). -Live additionally watches six real, finished SHAs on GitHub --
# success on each branch, a code failure, an infrastructure failure, a failure on `main`, and checks
# that never ran -- which needs the network and the runs' retained logs, so it is opt-in.
param([string]$Tools = $PSScriptRoot, [switch]$Live)
$ErrorActionPreference = 'Stop'
$Work = Join-Path ([IO.Path]::GetTempPath()) ('orvion-watch-selftest-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $Work 'scripts'))
$script:Pass = 0; $script:Fail = 0; $script:Spawned = [Collections.Generic.List[int]]::new()
function Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) { $script:Pass++; "PASS $Name" } else { $script:Fail++; "FAIL $Name $Detail" }
}
function Q([string]$s) { '"' + $s + '"' }   # Start-Process joins arguments unquoted; this checkout's path has a space
function Start-Pwsh([string]$Arguments, [string]$Out) {
    $p = if ($Out) { Start-Process pwsh -ArgumentList "-NoProfile $Arguments" -RedirectStandardOutput $Out -PassThru -WindowStyle Hidden }
         else      { Start-Process pwsh -ArgumentList "-NoProfile $Arguments" -PassThru -WindowStyle Hidden }
    [void]$p.Handle   # cache the handle now, or ExitCode and CPU time are unreadable after exit
    $script:Spawned.Add($p.Id); $p
}
function Stop-Tree([int]$Id) { & taskkill.exe /T /F /PID $Id *> $null }
function Start-Runner([string]$Runner, [string]$Log, [string]$Command) {
    Start-Pwsh ('-File {0} -Log {1} -Command {2} -WorkingDirectory {3}' -f (Q $Runner), (Q $Log), (Q $Command), (Q $Work)) $null
}
function Start-Watcher([string]$Watcher, [string]$Log, [string]$Run, [double]$Quiet, [string]$Csv, [string]$Out, [double]$Poll = 1) {
    Start-Pwsh ('-File {0} -Log {1} -Run {2} -QuietMinutes {3} -PollSeconds {5} -Csv {4}' -f (Q $Watcher), (Q $Log), $Run, $Quiet, (Q $Csv), $Poll) $Out
}
function Wait-Exit($Process, [int]$Seconds) { if (-not $Process.WaitForExit($Seconds * 1000)) { Stop-Tree $Process.Id; return $false }; $true }
function New-Name([string]$Ext) { Join-Path $Work ([guid]::NewGuid().ToString('N') + $Ext) }

$RepoRoot = Split-Path $Tools -Parent   # where check_agent_continuity.ps1, the CI contract's authority, lives
$Runner = Join-Path $Tools 'run_timed.ps1'; $Watcher = Join-Path $Tools 'watch_run.ps1'; $Ci = Join-Path $Tools 'watch_ci.ps1'
$Stage = Join-Path $Work 'scripts\fake_stage.ps1'
# A silent stage whose NEWEST descendant is not a script (as a real suite's git or docker child is):
# the heartbeat must still name the script.
"Start-Sleep -Seconds 2; & ping.exe -n 39 127.0.0.1 | Out-Null; Write-Output '== 3 passed, 0 failed =='" | Set-Content -LiteralPath $Stage -Encoding utf8
$OtherWork = Join-Path $Work 'other_work.ps1'
'Start-Sleep -Seconds 90' | Set-Content -LiteralPath $OtherWork -Encoding utf8

# ---- unit cases on the watchers' functions (dot-sourced inside a function, so their parameters
#      cannot clobber this script's variables) ----------------------------------------------------
function Case-Vocabulary([string]$WatcherPath) {
    . $WatcherPath
    $results = @('PASS: pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1', 'FAILED: pwsh -NoProfile -File scripts/x.ps1 (exit 1)',
        'LOCAL_CERTIFY: READY', 'REMOTE_CERTIFY: FAILED', 'CODE: FINISH_NOT_READY:EXECUTE', '  STALE OWNER DECISION: AA-1 is settled',
        '== 41 passed, 1 failed ==', 'not ok 3 - fixture', 'ERROR:  relation "x" does not exist', 'FAIL 12 the guard refused',
        'END exit=1 total=0.4 min concurrent_end=0', 'M1 KILLED', 'ALL CHECKS PASSED',
        'WORKSTATION VERIFICATION: PASSED', 'WORKSTATION PREPARATION: COMPLETE', 'PUBLISH: DONE', 'REMOTE_CERTIFY: PENDING',
        'DATABASE PARITY: UNPROVEN -- local matches the repository, but PRIMARY WAS NOT CONTACTED.', 'HARD_BLOCKED: RECOVERY_EXHAUSTED', 'DATABASE PARITY: 3 issue(s) found')
    $noise = @('PASS 101 the guard holds', 'the guard is fail-closed by design', 'CODE: none', 'error: lowercase prose', 'Checking 27 anchors', 'Failed attempts are retried by nobody', 'MODE: PLAN')
    $missed = @($results | Where-Object { -not (Test-ResultLine $_) }); $leaked = @($noise | Where-Object { Test-ResultLine $_ })
    [pscustomobject]@{ Ok = (-not $missed -and -not $leaked); Detail = "missed=[$($missed -join ' | ')] leaked=[$($leaked -join ' | ')]" }
}
function Case-StartLine([string]$WatcherPath) {
    . $WatcherPath
    $s = Read-StartLine '[2026-10-09 10:35:40] START pid=4242 host=H pwsh=7.6.6 cpus=8 head=697b050 concurrent=0 | pwsh -NoProfile -File x.ps1'
    $old = Read-StartLine '[10:35:40] START pwsh -NoProfile -File x.ps1'
    [pscustomobject]@{ Ok = ($s.Pid -eq 4242 -and $s.At -eq [datetime]'2026-10-09 10:35:40' -and $s.Env -match 'concurrent=0' -and $null -eq $old); Detail = "pid=$($s.Pid) env=$($s.Env)" }
}
function Run([string]$Name, [string]$Branch, [string]$Status, [string]$Conclusion, [string]$Event = 'push') {
    [pscustomobject]@{ databaseId = [Math]::Abs(("$Name|$Branch|$Event").GetHashCode()); name = $Name; headBranch = $Branch; status = $Status; conclusion = $Conclusion; attempt = 1; event = $Event; createdAt = (Get-Date) }
}
# The candidate and main share one SHA: each branch is judged against its own runs only.
function Case-CiBranch([string]$CiPath) {
    . $CiPath -RepoRoot $RepoRoot
    $runs = @((Run 'ORVION Acceptance' 'orvion-preflight' 'completed' 'success'), (Run 'Agent Control' 'orvion-preflight' 'completed' 'success'), (Run 'Agent Control' 'main' 'in_progress' ''))
    $main = Get-CiState $runs 'main' @('Agent Control'); $cand = Get-CiState $runs 'orvion-preflight' @('Agent Control', 'ORVION Acceptance')
    [pscustomobject]@{ Ok = ($main.Open -eq 1 -and $main.Mine.Count -eq 1 -and $cand.Open -eq 0 -and -not $cand.Missing -and $cand.AllSucceeded); Detail = "main open=$($main.Open) mine=$($main.Mine.Count); candidate open=$($cand.Open) missing=[$($cand.Missing)]" }
}
# A missing expected check is missing even when another event's run carries its name; an unexpected one is never waited for.
function Case-CiMissing([string]$CiPath) {
    . $CiPath -RepoRoot $RepoRoot
    $none = Get-CiState @() 'main' @('Agent Control', 'Repository Consistency')
    $prOnly = Get-CiState @((Run 'Agent Control' 'main' 'completed' 'success' 'pull_request'), (Run 'Repository Consistency' 'main' 'completed' 'success')) 'main' @('Agent Control', 'Repository Consistency')
    $extra = Get-CiState @((Run 'Agent Control' 'main' 'completed' 'success'), (Run 'Migration CI' 'main' 'completed' 'failure')) 'main' @('Agent Control')
    [pscustomobject]@{ Ok = (@($none.Missing).Count -eq 2 -and ($prOnly.Missing -join ',') -eq 'Agent Control' -and -not $extra.Missing -and ($extra.Unexpected -join ',') -eq 'Migration CI' -and -not $extra.AllSucceeded)
                       Detail = "none=[$($none.Missing -join ',')] prOnly=[$($prOnly.Missing -join ',')] extraUnexpected=[$($extra.Unexpected -join ',')] extraAllSucceeded=$($extra.AllSucceeded)" }
}
# The contract derived from the workflow files at REAL SHAs (local git only): ORVION Acceptance is expected
# on the candidate and not on main; Migration CI only where a migration path changed.
function Case-CiContract([string]$CiPath) {
    . $CiPath -RepoRoot $RepoRoot
    $cand = (Get-CiContract '697b050' '523888d' 'orvion-preflight' $RepoRoot).Expected -join ','
    $main = (Get-CiContract '697b050' '523888d' 'main' $RepoRoot).Expected -join ','
    $mig  = (Get-CiContract '795d6bc' 'a7ff994' 'orvion-preflight' $RepoRoot).Expected -join ','
    [pscustomobject]@{ Ok = ($cand -eq 'Agent Control,ORVION Acceptance,Repository Consistency' -and $main -eq 'Agent Control,Repository Consistency' -and $mig -eq 'Agent Control,Migration CI,ORVION Acceptance,Repository Consistency')
                       Detail = "candidate=[$cand] main=[$main] migration=[$mig]" }
}
# Evidence lines, shaped like the real logs of runs 36600463643, 34700639112 and 35907919393.
function Case-CiEvidence([string]$CiPath) {
    . $CiPath -RepoRoot $RepoRoot
    $e = [char]27
    $log = @("2026-10-09T07:00:00.1Z $e[32mok 1 - fixture$e[0m", '2026-10-09T07:00:01.1Z fail-closed by design, see the guard',
        '2026-10-09T07:00:02.1Z PASS 145 a main failure is FAILED even when the same workflow succeeded on preflight',
        '2026-10-09T07:00:03.1Z toomanyrequests: retrying image pull', '2026-10-09T07:00:04.1Z FAIL 101 the guard refused the write', '2026-10-09T07:00:04.2Z   FAIL CONTROL: the open-decision set is the current ENUMERATION (2)',
        '2026-10-09T07:00:05.1Z error handling is explicit', '2026-10-09T07:00:06.1Z ORVION: BLOCKED', '2026-10-09T07:00:07.1Z CODE: AMBIGUOUS_GOVERNING_CR',
        "2026-10-09T07:00:08.1Z $e[31mBus error (core dumped)$e[0m", '2026-10-09T07:00:09.1Z ##[error]Process completed with exit code 135.')
    $sel = @(Select-ErrorLines $log -Last 20); $joined = $sel -join "`n"
    $summary = Format-Summary @((Run 'a' 'main' 'completed' 'success'), (Run 'b' 'main' 'completed' 'success'), (Run 'c' 'main' 'completed' 'skipped'))
    $ok = $sel.Count -eq 7 -and $joined -match 'FAIL CONTROL: the open-decision set' -and $joined -match 'toomanyrequests' -and $joined -match '(?m)Bus error \(core dumped\)$' -and $joined -match 'ORVION: BLOCKED' -and
          $joined -match 'CODE: AMBIGUOUS_GOVERNING_CR' -and $joined -notmatch 'fail-closed|error handling|PASS 145|\x1b' -and $summary -eq 'skipped=1, success=2'
    [pscustomobject]@{ Ok = $ok; Detail = "selected=[$($sel -join ' | ')] summary=[$summary]" }
}
# ---- end-to-end cases on real processes ------------------------------------------------------------
function Case-ExitCode([string]$RunnerPath) {
    $log = New-Name '.log'
    $r = Start-Runner $RunnerPath $log "pwsh -NoProfile -Command 'exit 3'"
    $done = Wait-Exit $r 60
    $end = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '\] END exit=' })
    [pscustomobject]@{ Ok = ($done -and $r.ExitCode -eq 3 -and $end.Count -eq 1 -and $end[0] -match 'END exit=3 '); Detail = "runner exit=$(if ($done) { $r.ExitCode }) end=[$end]" }
}
function Case-Steps([string]$RunnerPath, [string]$WatcherPath) {
    $log = New-Name '.log'; $csv = New-Name '.csv'; $out = New-Name '.out'
    # Other work already running: the START line must name it, so this run is labelled as contaminated.
    $other = Start-Pwsh ('-File {0}' -f (Q $OtherWork)) $null
    Start-Sleep -Seconds 3
    $wall = [Diagnostics.Stopwatch]::StartNew()
    $r = Start-Runner $RunnerPath $log "Write-Output 'PASS: pwsh -NoProfile -File scripts/fake_a.ps1'; Start-Sleep -Seconds 20; Write-Output 'FAILED: pwsh -NoProfile -File scripts/fake_b.ps1 (exit 1)'; exit 1"
    $w = Start-Watcher $WatcherPath $log 'steps' 5 $csv $out
    $done = Wait-Exit $w 120; [void](Wait-Exit $r 10); $wallMin = $wall.Elapsed.TotalMinutes; Stop-Tree $other.Id
    $label = (Get-Content -LiteralPath $log -TotalCount 1)
    $o = @(Get-Content -LiteralPath $out)
    $fail = $o | Where-Object { $_ -match '^\[\s*([\d.]+) min \| \+([\d.]+)\] FAILED: ' } | Select-Object -First 1
    $delta = if ($fail) { [double]$Matches[2] } else { -1 }
    $end = $o | Where-Object { $_ -match '^\[\s*([\d.]+) min \| \+[\d.]+\] END exit=1 ' } | Select-Object -First 1
    $total = if ($end) { [double]$Matches[1] } else { -1 }
    $rows = @(Import-Csv -LiteralPath $csv)
    $ok = $done -and @($o -match '\] PASS: ').Count -eq 1 -and $fail -and $end -and $delta -ge 0.25 -and [Math]::Abs($wallMin - $total) -le 0.15 -and
          $rows.Count -eq 3 -and $rows[0].env -match 'concurrent=[^ ]*other_work\.ps1' -and $label -notmatch 'shellIntegration' -and
          @($o -match '^compare: first recorded run').Count -eq 1
    [pscustomobject]@{ Ok = $ok; Log = $log; Csv = $csv; Detail = "done=$done delta=$delta total=$total wall=$('{0:N2}' -f $wallMin) rows=$($rows.Count) start=[$label] || $($o -join ' || ')" }
}
# Steady-state cost at the PRODUCTION cadence (10 s polls, 5-minute heartbeat): CPU sampled 20 s
# after start, once pwsh has loaded, and again a minute later.
function Case-Overhead([string]$RunnerPath, [string]$WatcherPath) {
    $log = New-Name '.log'
    $r = Start-Runner $RunnerPath $log 'Start-Sleep -Seconds 95'
    $w = Start-Watcher $WatcherPath $log 'overhead' 5 (New-Name '.csv') (New-Name '.out') 10
    Start-Sleep -Seconds 20; $w.Refresh(); $cpu0 = $w.TotalProcessorTime.TotalSeconds
    Start-Sleep -Seconds 60; $w.Refresh(); $cpu1 = $w.TotalProcessorTime.TotalSeconds
    $alive = -not $w.HasExited
    Stop-Tree $r.Id; Stop-Tree $w.Id
    [pscustomobject]@{ Ok = ($alive -and ($cpu1 - $cpu0) -lt 2); Detail = ('alive={0} startup {1:N2} s; steady {2:N2} s of CPU per minute' -f $alive, $cpu0, ($cpu1 - $cpu0)) }
}
function Case-Stage([string]$RunnerPath, [string]$WatcherPath) {
    $log = New-Name '.log'; $out = New-Name '.out'
    $r = Start-Runner $RunnerPath $log ("pwsh -NoProfile -File '{0}'" -f $Stage)
    $w = Start-Watcher $WatcherPath $log 'stage' 0.2 (New-Name '.csv') $out
    $done = Wait-Exit $w 120; [void](Wait-Exit $r 10)
    $o = @(Get-Content -LiteralPath $out)
    $hb = @($o -match '^heartbeat: no new output'); $named = @($hb -match 'running scripts[\\/]fake_stage\.ps1 since \d\d:\d\d:\d\d \(cpu \d+s\)')
    $cpuPerMin = $w.TotalProcessorTime.TotalSeconds / [Math]::Max(0.1, ($w.ExitTime - $w.StartTime).TotalMinutes)
    [pscustomobject]@{ Ok = ($done -and $named.Count -ge 1 -and @($o -match '3 passed, 0 failed').Count -eq 1); CpuPerMin = $cpuPerMin; Detail = "done=$done heartbeats=$($hb.Count) named=$($named.Count) || $($o -join ' || ')" }
}
function Case-Gone([string]$RunnerPath, [string]$WatcherPath) {
    $log = New-Name '.log'; $out = New-Name '.out'
    $r = Start-Runner $RunnerPath $log 'Start-Sleep -Seconds 300'
    $w = Start-Watcher $WatcherPath $log 'gone' 5 (New-Name '.csv') $out
    $t = [Diagnostics.Stopwatch]::StartNew(); while (-not (Test-Path -LiteralPath $log) -and $t.Elapsed.TotalSeconds -lt 30) { Start-Sleep -Milliseconds 500 }
    Start-Sleep -Seconds 4; Stop-Tree $r.Id
    $done = Wait-Exit $w 30
    $o = @(Get-Content -LiteralPath $out)
    [pscustomobject]@{ Ok = ($done -and $w.ExitCode -eq 1 -and @($o -match '^RUNNER GONE: process \d+ exited without an END line').Count -eq 1); Detail = "done=$done exit=$(if ($done) { $w.ExitCode }) || $($o -join ' || ')" }
}
function Case-NeverStarted([string]$WatcherPath) {
    $out = New-Name '.out'
    $w = Start-Watcher $WatcherPath (New-Name '.never.log') 'never' 0.1 (New-Name '.csv') $out
    Start-Sleep -Seconds 15; Stop-Tree $w.Id; [void]$w.WaitForExit(5000)
    $n = @(Get-Content -LiteralPath $out | Where-Object { $_ -match 'runner may not have started' }).Count
    [pscustomobject]@{ Ok = ($n -ge 1); Detail = "notices=$n" }
}
function Case-Rearm([string]$RunnerPath, [string]$WatcherPath, $First) {
    $out = New-Name '.out'
    $w = Start-Watcher $WatcherPath $First.Log 'steps' 5 $First.Csv $out; $done = Wait-Exit $w 60
    $rowsAfterRearm = @(Import-Csv -LiteralPath $First.Csv).Count
    Start-Sleep -Seconds 1   # a new run identity needs a different START second
    $log2 = New-Name '.log'; $out2 = New-Name '.out'
    $r = Start-Runner $RunnerPath $log2 "Write-Output 'PASS: pwsh -NoProfile -File scripts/fake_a.ps1'; exit 0"
    $w2 = Start-Watcher $WatcherPath $log2 'steps' 5 $First.Csv $out2; $done2 = Wait-Exit $w2 60; [void](Wait-Exit $r 10)
    $cmp = @(Get-Content -LiteralPath $out2 | Where-Object { $_ -match '^compare: this run [\d.]+ min \[.*concurrent=.*\] vs previous [\d.]+ min on \d{4}-\d\d-\d\d' })
    [pscustomobject]@{ Ok = ($done -and $done2 -and $rowsAfterRearm -eq 3 -and $cmp.Count -eq 1); Detail = "rows after re-arm=$rowsAfterRearm compare=$($cmp.Count) || $((Get-Content -LiteralPath $out2) -join ' || ')" }
}

try {
    $c = Case-ExitCode $Runner;      Check 'W0 the runner preserves the command''s own exit code (3), in its END line and its own exit' $c.Ok $c.Detail
    $c = Case-Vocabulary $Watcher;   Check 'W1 result vocabulary: every step, verdict, total and failure line; no prose or per-assertion noise' $c.Ok $c.Detail
    $c = Case-StartLine $Watcher;    Check 'W2 the START line carries date, runner pid and conditions; an old-format line is refused' $c.Ok $c.Detail
    $steps = Case-Steps $Runner $Watcher
    Check 'W3 a real run: PASS and FAILED step lines, END exit=1, timing within 0.15 min of the wall clock, labelled CSV rows' $steps.Ok $steps.Detail
    $c = Case-Stage $Runner $Watcher; Check 'W4 a silent stage produces a heartbeat naming the running repository script, then its result' $c.Ok $c.Detail
    $c = Case-Overhead $Runner $Watcher; Check 'W5 overhead at the production cadence: under 2 s of CPU per minute watched' $c.Ok $c.Detail
    "    measured: $($c.Detail)"
    $c = Case-Gone $Runner $Watcher;  Check 'W6 a runner killed mid-run is reported as RUNNER GONE and the watcher exits 1' $c.Ok $c.Detail
    $c = Case-NeverStarted $Watcher;  Check 'W7 a runner that never starts is reported, not waited on silently' $c.Ok $c.Detail
    $c = Case-Rearm $Runner $Watcher $steps; Check 'W8 a re-armed watcher adds no duplicate rows; a later run compares with the previous one and both conditions' $c.Ok $c.Detail
    $c = Case-CiBranch $Ci;          Check 'C1 the candidate and main runs on one SHA are judged separately, each against its own contract' $c.Ok $c.Detail
    $c = Case-CiMissing $Ci;         Check 'C2 an expected check that never ran is missing (another event never stands in for it); an unexpected run is reported, not required' $c.Ok $c.Detail
    $c = Case-CiContract $Ci;        Check 'C3 the contract at real SHAs: ORVION Acceptance on the candidate only; Migration CI only where a migration path changed' $c.Ok $c.Detail
    $c = Case-CiEvidence $Ci;        Check 'C4 evidence keeps refusals, failures and infrastructure messages without classifying them; no PASS lines or prose; skipped is not success' $c.Ok $c.Detail

    if ($Live) {
        $liveCases = @(
            @{ Name = 'L1 success on the candidate';                         Args = '697b050', 'orvion-preflight', '523888d'; Exit = 0; Must = 'DONE on 697b050 / orvion-preflight: every expected workflow ran and succeeded' },
            @{ Name = 'L2 success on main, ORVION Acceptance not expected';  Args = '697b050', 'main', '523888d';             Exit = 0; Must = 'not expected here: Migration CI, ORVION Acceptance' },
            @{ Name = 'L3 a code failure on the candidate';                  Args = '66bf1b2', 'orvion-preflight', '6c48fbb'; Exit = 1; Must = 'FAIL CONTROL: the open-decision set' },
            @{ Name = 'L4 an infrastructure failure, reported not classified'; Args = '795d6bc', 'orvion-preflight', 'a7ff994'; Exit = 1; Must = 'failed step: Start local Supabase stack' },
            @{ Name = 'L5 a failure on main whose cause is a refusal code';  Args = 'cde4f06', 'main', 'd0bba10';             Exit = 1; Must = 'CODE: AMBIGUOUS_GOVERNING_CR' },
            @{ Name = 'L6 expected checks that never ran are MISSING';       Args = 'ab1e3a3', 'main', '523888d';             Exit = 1; Must = 'MISSING on ab1e3a3 / main: Agent Control, Repository Consistency never ran' })
        foreach ($l in $liveCases) {
            $out = @(& pwsh -NoProfile -File $Ci -Sha $l.Args[0] -Branch $l.Args[1] -Base $l.Args[2] -SettleSeconds 5 -MissingMinutes 0.3 -PollSeconds 5 -QuietMinutes 1 2>&1 | ForEach-Object { "$_" })
            $code = $LASTEXITCODE
            Check $l.Name ($code -eq $l.Exit -and ($out -join "`n").Contains($l.Must)) "exit=$code || $(($out | Select-Object -Last 6) -join ' || ')"
        }
    }

    # ---- mutants: each must be KILLED by the case named ----------------------------------------------
    $mutants = @(
        @{ Name = 'M1 step lines dropped from the vocabulary'; File = $Watcher; Find = "'(^(PASS|FAILED|SKIPPED?): .*|"; Replace = "'("; Case = { param($p) Case-Vocabulary $p } },
        @{ Name = 'M2 case-insensitive matching';            File = $Watcher; Find = '$Body -cmatch';                    Replace = '$Body -match'; Case = { param($p) Case-Vocabulary $p } },
        @{ Name = 'M3 heartbeat disabled';                   File = $Watcher; Find = '} elseif ($quiet.Elapsed.TotalMinutes -ge $QuietMinutes) {'; Replace = '} elseif ($false) {'; Case = { param($p) Case-Stage $Runner $p } },
        @{ Name = 'M4 newest descendant named instead of the script'; File = $Watcher; Find = '$scripted = @($desc | Where-Object'; Replace = '$scripted = @(@() | Where-Object'; Case = { param($p) Case-Stage $Runner $p } },
        @{ Name = 'M5 runner-gone check removed';            File = $Watcher; Find = '} elseif (-not (Get-Process -Id $start.Pid -ErrorAction SilentlyContinue)) {'; Replace = '} elseif ($false) {'; Case = { param($p) Case-Gone $Runner $p } },
        @{ Name = 'M9 exit code collapsed by pwsh -Command';  File = $Runner;  Find = '"$Command`nexit `$LASTEXITCODE"'; Replace = '$Command'; Case = { param($p) Case-ExitCode $p } },
        @{ Name = 'M10 a derived verdict word dropped';       File = $Watcher; Find = 'READY|PASSED|';                   Replace = 'READY|'; Case = { param($p) Case-Vocabulary $p } },
        @{ Name = 'M8 concurrent work not detected';         File = $Runner;  Find = "'(?i)\s-File\s+";               Replace = "'(?i)\s-NoSuchFlag\s+"; Case = { param($p) Case-Steps $p $Watcher } },
        @{ Name = 'M6 branch ignored';                       File = $Ci;      Find = '$_.headBranch -eq $Branch';        Replace = '$true'; Case = { param($p) Case-CiBranch $p } },
        @{ Name = 'M7 case-insensitive error lines';         File = $Ci;      Find = '$message -cmatch $script:ErrorLineRx'; Replace = '$message -match $script:ErrorLineRx'; Case = { param($p) Case-CiEvidence $p } },
        @{ Name = 'M15 an indented failure line dropped';     File = $Ci;      Find = "'^\s*(FAIL\b|"; Replace = "'^(FAIL\b|"; Case = { param($p) Case-CiEvidence $p } },
        @{ Name = 'M11 PASS lines read as evidence';          File = $Ci;      Find = "`$message -cnotmatch '^PASS\b' -and "; Replace = ''; Case = { param($p) Case-CiEvidence $p } },
        @{ Name = 'M12 contract derived for the wrong branch'; File = $Ci;     Find = '$expected = @(Workflow-Expectations $changed $Branch)'; Replace = '$expected = @(Workflow-Expectations $changed ''orvion-preflight'')'; Case = { param($p) Case-CiContract $p } },
        @{ Name = 'M13 a missing check never reported';       File = $Ci;      Find = 'Missing    = @($Expected | Where-Object { $present -notcontains $_ })'; Replace = 'Missing    = @()'; Case = { param($p) Case-CiMissing $p } },
        @{ Name = 'M14 another event stands in for a push';   File = $Ci;      Find = " -and `$_.event -eq 'push'"; Replace = ''; Case = { param($p) Case-CiMissing $p } }
    )
    foreach ($m in $mutants) {
        $source = [IO.File]::ReadAllText($m.File); $mutated = $source.Replace($m.Find, $m.Replace)
        if ($mutated -eq $source) { Check "$($m.Name) (mutant applied)" $false "text not found: $($m.Find)"; continue }
        $dir = Join-Path $Work ('mutant-' + [guid]::NewGuid().ToString('N')); [void][IO.Directory]::CreateDirectory($dir)
        $path = Join-Path $dir (Split-Path $m.File -Leaf); [IO.File]::WriteAllText($path, $mutated)   # same name, so the runner's own exclusion still applies
        $c = & $m.Case $path
        Check "$($m.Name) is KILLED" (-not $c.Ok -and $c.Detail -notmatch 'ParserError|ParseException') $c.Detail
        "    mutant observed: $($c.Detail.Substring(0, [Math]::Min(300, $c.Detail.Length)))"
    }
} finally {
    foreach ($id in $script:Spawned) { if (Get-Process -Id $id -ErrorAction SilentlyContinue) { Stop-Tree $id } }
    try { [IO.Directory]::Delete($Work, $true) } catch { "note: could not remove $Work ($($_.Exception.Message))" }
}
"== $script:Pass passed, $script:Fail failed =="
exit ([int]($script:Fail -gt 0))
