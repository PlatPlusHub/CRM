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
$Runner = Join-Path $Tools 'run_timed.ps1'; $Watcher = Join-Path $Tools 'watch_run.ps1'; $Ci = Join-Path $Tools 'watch_ci.ps1'; $Evaluator = Join-Path $Tools 'check_agent_continuity.ps1'
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
        'DATABASE PARITY: UNPROVEN -- local matches the repository, but PRIMARY WAS NOT CONTACTED.', 'HARD_BLOCKED: RECOVERY_EXHAUSTED', 'DATABASE PARITY: 3 issue(s) found',
        'TIME: Gate range 00:00:04', 'TIME: REPOSITORY pwsh -NoProfile -File scripts/check_repository_consistency.ps1 00:00:12', 'TIME: PROFILE CONTROL 00:31:02',
        'TIME: STAGES Gate range setup=0.05s range-walk=3.10s other=0.20s')
    $noise = @('PASS 101 the guard holds', 'the guard is fail-closed by design', 'CODE: none', 'error: lowercase prose', 'Checking 27 anchors', 'Failed attempts are retried by nobody', 'MODE: PLAN')
    $missed = @($results | Where-Object { -not (Test-ResultLine $_) }); $leaked = @($noise | Where-Object { Test-ResultLine $_ })
    [pscustomobject]@{ Ok = (-not $missed -and -not $leaked); Detail = "missed=[$($missed -join ' | ')] leaked=[$($leaked -join ' | ')]" }
}
# ---- history, ETA, findings and report (SPEC-283): unit cases on fixture rows -------------------------
function Rows([string]$Name, [string]$Date, [object[]]$Steps) {
    foreach ($s in $Steps) { [pscustomobject]@{ run = $Name; date = $Date; step = $s[0]; elapsed_min = "$($s[1])"; delta_min = "$($s[2])"; env = 'host=H' } }
}
function OkRun([string]$Date, [double]$End, [double]$XDelta = 1) { Rows 'r' $Date @(@('PASS: x', 1, $XDelta), @('PASS: y', 2, 1), @("END exit=0 total=$End min", $End, ($End - 2))) }
# Successful runs only, the median of what each still had to do, its range, and no estimate from one run.
function Case-CountEta([string]$WatcherPath) {
    . $WatcherPath
    $history = @(foreach ($date in 'a','b') {
        $steps = @([pscustomobject]@{Kind='test';Key='PASS 1 repeated';T=1.0},[pscustomobject]@{Kind='test';Key='PASS 1 repeated';T=6.0},[pscustomobject]@{Kind='test';Key='PASS 3 final';T=10.0})
        [pscustomobject]@{Date=$date;Ok=$true;Total=15.0;Steps=$steps;Index=@{'PASS 1 repeated'=$steps[0];'PASS 3 final'=$steps[2]}}
    })
    $second = Get-Eta $history 'PASS 1 repeated' 0 6 2
    $third = Get-Eta $history 'PASS 3 final' 0 10 3
    $one = Get-Eta @($history[0]) 'PASS 1 repeated' 0 6 2
    $missing = Get-Eta $history 'PASS 9 changed' 0 6 2
    $beyond = Get-Eta $history 'PASS 1 repeated' 0 6 4
    $failed = Get-Eta @($history[0],[pscustomobject]@{Date='f';Ok=$false;Total=15;Steps=$history[1].Steps;Index=$history[1].Index}) 'PASS 1 repeated' 0 6 2
    $variant = [pscustomobject]@{Date='v';Ok=$true;Total=17;Steps=@($history[1].Steps)+@([pscustomobject]@{Kind='test';Key='PASS 4 added';T=12});Index=$history[1].Index}
    $mixed = Get-Eta @($history[0],$variant) 'PASS 1 repeated' 0 6 2
    $ok = $second -match '^eta: ~9[.,]0 min left' -and $second -match 'observed test count 2 \(historical total 3 tests\)' -and $third -match '^eta: ~5[.,]0 min left' -and $one -match '^eta: none' -and $missing -match '^eta: none' -and $beyond -match '^eta: none' -and $failed -match '^eta: none' -and $mixed -match '^eta: none - incompatible'
    [pscustomobject]@{Ok=$ok;Detail="second=[$second] third=[$third] one=[$one] missing=[$missing] beyond=[$beyond] failed=[$failed] mixed=[$mixed]"}
}
function Case-CountEtaCaller([string]$WatcherPath) {
    $log=New-Name '.log';$csv=New-Name '.csv'
    $startAt=(Get-Date).AddMinutes(-6)
    $lines=@(('['+$startAt.ToString('yyyy-MM-dd HH:mm:ss')+"] START pid=$PID host=fixture | synthetic count fixture"),'[+   1.000 min] PASS 1 repeated','[+   6.000 min] PASS 1 repeated')
    [IO.File]::WriteAllLines($log,$lines)
    $rows=@(foreach($date in 'a','b'){Rows 'count-eta' $date @(@('PASS 1 repeated',1,1),@('PASS 1 repeated',6,5),@('PASS 3 final',10,4),@('END exit=0 total=15.0 min',15,5))})
    $rows|Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding utf8
    $output=@(& pwsh -NoProfile -File $WatcherPath -Log $log -Run 'count-eta' -Csv $csv -Eta 2>&1);$code=$LASTEXITCODE
    [pscustomobject]@{Ok=($code-eq0-and($output-join' ')-match'^eta: ~9[.,]0 min left.*observed test count 2');Detail="exit=$code $($output-join' | ')"}
}
function Case-Eta([string]$WatcherPath) {
    . $WatcherPath
    $hist = @(Read-History @((OkRun 'a' 5) + (OkRun 'b' 6) + (OkRun 'c' 7) + (Rows 'r' 'f' @(@('PASS: x', 1, 1), @('END exit=1', 1.5, 0.5)))) 'r')
    $three = Get-Eta $hist 'PASS: x' 0 1; $one = Get-Eta @($hist | Where-Object { $_.Date -in 'a', 'f' }) 'PASS: x' 0 1; $new = Get-Eta $hist 'PASS: a test no run has had' 0 1
    $log = New-Name '.log'; Set-Content -LiteralPath $log -Value @('[2026-10-15 10:00:00] START pid=1 host=H | x', '[+   1.0 min] PASS: x', '[+   2.0 min] END exit=0 total=2.0 min concurrent_end=0') -Encoding utf8
    $ended = @(& pwsh -NoProfile -File $WatcherPath -Log $log -Run 'r' -Eta -Csv (New-Name '.csv') 2>&1) -join ' '
    [pscustomobject]@{ Ok = ($three -eq 'eta: ~5.0 min left (median of 3 comparable successful runs, low sample; range 4.0 to 6.0)' -and $new -eq 'eta: ~5.0 min left (median of 3 comparable successful runs, by run totals, low sample; range 4.0 to 6.0)' -and $one -match '^eta: none - 1 comparable' -and $ended -match '^eta: the run has ended \(END exit=0'); Detail = "three=[$three] new=[$new] one=[$one] ended=[$ended]" }
}
# Each finding once, labelled by what the evidence supports.
function Case-Findings([string]$WatcherPath) {
    . $WatcherPath
    $hist = @(Read-History @((OkRun 'a' 5) + (OkRun 'b' 6) + (OkRun 'c' 7) + (Rows 'r' 'f' @(@('FAILED: z (exit 1)', 1, 1), @('END exit=1', 1.5, 0.5)))) 'r')
    $st = New-FindingState
    $f = @(foreach ($b in 'FAILED: z (exit 1)', 'FAILED: z (exit 1)', 'PASS: x', 'PASS: x', 'PASS: x') { Get-StepFindings $hist $st $b $(if ($b -eq 'PASS: x') { 5 } else { 1 }) }) + @(Get-EndFindings $hist $st 20) + @(Get-EndFindings $hist $st 20)
    $want = @('finding [confirmed] recurring failure: FAILED: z (exit 1) - also in 1 of 4 earlier runs', 'finding [hypothesis] repeated execution: z ran twice',
        'finding [hypothesis] slow step: PASS: x took 5.0 min', 'finding [hypothesis] repeated execution: x ran twice', 'finding [hypothesis] expected step absent: PASS: y', 'finding [hypothesis] slower run: 20.0 min')
    $missing = @($want | Where-Object { $w = $_; -not @($f | Where-Object { $_.StartsWith($w) }).Count })
    $calm = @(Get-StepFindings @() (New-FindingState) 'FAILED: z (exit 1)' 9)
    [pscustomobject]@{ Ok = ($f.Count -eq $want.Count -and -not $missing -and -not $calm.Count); Detail = "count=$($f.Count) missing=[$($missing -join ' | ')] calm=[$($calm -join ' | ')] all=[$($f -join ' | ')]" }
}
# A failure rate is per run of its own name: two failures in three runs outrank two in twenty.
function Case-Report([string]$WatcherPath) {
    $csv = New-Name '.csv'; 'run,date,step,elapsed_min,delta_min,env' | Out-File -LiteralPath $csv -Encoding utf8
    $rows = foreach ($i in 1..20) { Rows 'often' "o$i" @(@('PASS: build', 2, 2), @($(if ($i -le 2) { 'FAILED: flaky (exit 1)' } else { 'PASS: flaky' }), 3, 1), @("END exit=$([int]($i -le 2))", 3, 0)) }
    $rows += foreach ($i in 1..3) { Rows 'rare' "r$i" @(@($(if ($i -le 2) { 'FAILED: rare (exit 1)' } else { 'PASS: rare' }), 1, 1), @("END exit=$([int]($i -le 2))", 1, 0)) }
    $rows | Export-Csv -LiteralPath $csv -Append -NoTypeInformation -Encoding utf8
    $o = @(& pwsh -NoProfile -File $WatcherPath -Report -Csv $csv 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE
    $i = [array]::IndexOf($o, ($o | Where-Object { $_ -match 'FAILED: rare' } | Select-Object -First 1)); $j = [array]::IndexOf($o, ($o | Where-Object { $_ -match 'FAILED: flaky' } | Select-Object -First 1))
    [pscustomobject]@{ Ok = ($code -eq 0 -and $i -ge 0 -and $j -gt $i -and @($o -match 'time\s+67%\s+PASS: build').Count -eq 1 -and @($o -match '67%\s+FAILED: rare \(exit 1\) in 2 of 3 rare runs - investigate \[hypothesis\]').Count -eq 1); Detail = "exit=$code rare@$i flaky@$j || $($o -join ' || ')" }
}
function Case-Redact([string]$WatcherPath) {
    . $WatcherPath
    $r = Hide-Secret 'FAIL 3 secret scanning on; token=abc123 Authorization: Bearer xyz9 ghp_aaaaaaaaaaaaaaaaaaaaaaaa1 password: hunter2'
    [pscustomobject]@{ Ok = ($r -match 'secret scanning on' -and $r -notmatch 'abc123|xyz9|ghp_a|hunter2'); Detail = $r }
}
# One append past the bound leaves the history within it: the header, then the newest WHOLE rows, the new one last.
function Case-Limit([string]$WatcherPath) {
    . $WatcherPath
    $csv = New-Name '.csv'; [IO.File]::WriteAllLines($csv, @('run,date,step,elapsed_min,delta_min,env') + @(1..200 | ForEach-Object { """r"",""d$_"",""PASS: x"",1,1,""h""" }))
    $said = Add-TimingRows $csv @('"r","dnew","PASS: newest",1,1,"h"') 2000; $left = [IO.File]::ReadAllLines($csv); $bytes = (Get-Item -LiteralPath $csv).Length
    $broken = @($left | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^"r","d\w+","PASS: \w+",1,1,"h"$' }).Count
    [pscustomobject]@{ Ok = ($bytes -le 2000 -and $left[0] -like 'run,*' -and $left[-1] -match 'dnew' -and $left[-2] -match '"d200"' -and -not $broken -and $said -match 'kept the newest' -and -not (Test-Path -LiteralPath "$csv.tmp")); Detail = "bytes=$bytes lines=$($left.Count) broken=$broken said=[$said]" }
}
# A failed test is a TEST - timed, counted and ranked with the others - and a failure; a TAP `not ok` with a
# TODO or SKIP directive is a test but not a failure (TAP 14).
function Case-Classify([string]$WatcherPath) {
    . $WatcherPath
    $kinds = (@('FAIL 7 the slow failing test', 'not ok 4 - a failing tap test', 'not ok 5 - later # TODO not yet', 'PASS 8 fine', 'FAILED: x (exit 1)') | ForEach-Object { Get-StepKind $_ }) -join ','
    $failing = @(@('FAIL 7 the slow failing test', 'not ok 4 - a failing tap test', 'not ok 5 - later # TODO not yet', 'not ok 6 # skip no database', 'PASS 8 fine') | Where-Object { $_ -cmatch $script:FailedTestRx }).Count
    $csv = New-Name '.csv'; 'run,date,step,elapsed_min,delta_min,env' | Out-File -LiteralPath $csv -Encoding utf8
    $rows = foreach ($i in 1..3) { Rows 'suite' "s$i" @(@('PASS 8 fine', 1, 0.1), @($(if ($i -le 2) { 'FAIL 7 the slow failing test' } else { 'PASS 7 the slow test' }), 4, 3), @("END exit=$([int]($i -le 2))", 4, 0)) }
    $rows | Export-Csv -LiteralPath $csv -Append -NoTypeInformation -Encoding utf8
    $o = @(& pwsh -NoProfile -File $WatcherPath -Report -Csv $csv 2>&1 | ForEach-Object { "$_" })
    [pscustomobject]@{ Ok = ($kinds -eq 'test,test,test,test,result' -and $failing -eq 2 -and @($o -match '^\s+slowest test\s+3\.000 min\s+FAIL 7 the slow failing test$').Count -eq 1 -and @($o -match '67%\s+FAIL 7 the slow failing test in 2 of 3 suite runs').Count -eq 1)
                       Detail = "kinds=[$kinds] failing=$failing || $($o -join ' || ')" }
}
# Writers in separate processes - the evaluator's copy of the write path and the watcher's - appending at
# once: with no bound reached every row arrives whole, exactly once; past a small bound the history stays
# within it, every line whole, and what each writer still has is its own newest rows.
function Get-FunctionText([string]$Path, [string]$Name) {
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true) | ForEach-Object { $_.Extent.Text })
}
function Case-Concurrent([string]$WatcherPath, [string]$EvaluatorPath, [long]$Max, [int]$Count = 150) {
    $fns = New-Name '.ps1'; (@('Use-TimingHistory', 'Add-TimingRows') | ForEach-Object { Get-FunctionText $EvaluatorPath $_ }) -join "`n" | Set-Content -LiteralPath $fns -Encoding utf8
    $writer = New-Name '.ps1'; $go = New-Name '.go'; $csv = New-Name '.csv'
    @('param([string]$Fns, [string]$HistoryFile, [long]$Limit, [int]$Count, [string]$Tag, [string]$Go)',
      'function Write-All { . $Fns; while (-not (Test-Path -LiteralPath $Go)) { Start-Sleep -Milliseconds 20 }',
      '  foreach ($i in 1..$Count) { try { Add-TimingRows $HistoryFile @(''"{0}","d","PASS {0} row {1}",1,1,"h"'' -f $Tag, $i) $Limit | Out-Null } catch { "error: $($_.Exception.Message)" } } }',
      'Write-All') | Set-Content -LiteralPath $writer -Encoding utf8
    $procs = foreach ($w in @(@('eval1', $fns), @('eval2', $fns), @('eval3', $fns), @('watch1', $WatcherPath), @('watch2', $WatcherPath), @('watch3', $WatcherPath))) {
        $out = New-Name '.out'; [pscustomobject]@{ Tag = $w[0]; Out = $out; P = (Start-Pwsh ('-File {0} -Fns {1} -HistoryFile {2} -Limit {3} -Count {4} -Tag {5} -Go {6}' -f (Q $writer), (Q $w[1]), (Q $csv), $Max, $Count, $w[0], (Q $go)) $out) }
    }
    Start-Sleep -Seconds 4; Set-Content -LiteralPath $go -Value 'go'
    $done = @($procs | Where-Object { Wait-Exit $_.P 120 }).Count -eq $procs.Count
    $errors = @($procs | ForEach-Object { Get-Content -LiteralPath $_.Out -ErrorAction SilentlyContinue } | Where-Object { $_ -match '^error:' })
    $lines = @(if (Test-Path -LiteralPath $csv) { [IO.File]::ReadAllLines($csv) }); $bytes = if (Test-Path -LiteralPath $csv) { (Get-Item -LiteralPath $csv).Length } else { -1 }
    $broken = @($lines | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^"(eval|watch)\d","d","PASS (eval|watch)\d row \d+",1,1,"h"$' }).Count
    $suffix = $true; foreach ($p in $procs) {
        $mine = @($lines | Where-Object { $_ -match "^""$($p.Tag)""," } | ForEach-Object { [int]($_ -replace '^.* row (\d+)",.*$', '$1') })
        if ($mine.Count -and (($mine -join ',') -ne ((($Count - $mine.Count + 1)..$Count) -join ','))) { $suffix = $false }
    }
    [pscustomobject]@{ Done = $done; Errors = $errors.Count; Header = ($lines.Count -and $lines[0] -eq 'run,date,step,elapsed_min,delta_min,env'); Rows = $lines.Count - 1; Unique = @($lines | Select-Object -Skip 1 -Unique).Count; Broken = $broken; Bytes = $bytes; Suffix = $suffix; Last = $(if ($lines.Count) { $lines[-1] } else { '' })
                       Detail = "done=$done errors=$($errors.Count) [$(($errors | Select-Object -First 2) -join ' | ')] rows=$($lines.Count - 1) broken=$broken bytes=$bytes suffix=$suffix last=[$(if ($lines.Count) { $lines[-1] })]" }
}
function Case-ConcurrentAll([string]$WatcherPath, [string]$EvaluatorPath) {
    $a = Case-Concurrent $WatcherPath $EvaluatorPath 100MB; $b = Case-Concurrent $WatcherPath $EvaluatorPath 6000
    $okA = $a.Done -and -not $a.Errors -and $a.Header -and $a.Rows -eq 900 -and $a.Unique -eq 900 -and -not $a.Broken
    $okB = $b.Done -and -not $b.Errors -and $b.Header -and $b.Bytes -le 6000 -and $b.Rows -lt 900 -and -not $b.Broken -and $b.Suffix -and $b.Last -match ' row 150",'
    [pscustomobject]@{ Ok = ($okA -and $okB); Detail = "unbounded: $($a.Detail) || bounded 6000: $($b.Detail)" }
}
function Case-SharedWriter([string]$WatcherPath, [string]$EvaluatorPath) {
    $diff = @(foreach ($n in 'Use-TimingHistory', 'Add-TimingRows') { $w = @(Get-FunctionText $WatcherPath $n); $e = @(Get-FunctionText $EvaluatorPath $n); if ($w.Count -ne 1 -or $e.Count -ne 1 -or $w[0] -cne $e[0]) { $n } })
    [pscustomobject]@{ Ok = (-not $diff.Count); Detail = "differ=[$($diff -join ',')]" }
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
# The runner samples its own resources while the command runs and summarises them on one line before
# END, which stays last; the command's exit code is untouched.
function Case-Resources([string]$RunnerPath) {
    $log = New-Name '.log'; $saved = $env:ORVION_RESOURCE_SECONDS; $env:ORVION_RESOURCE_SECONDS = '1'
    try { $r = Start-Runner $RunnerPath $log "Write-Output 'PASS: x'; Start-Sleep -Seconds 6; exit 4" } finally { $env:ORVION_RESOURCE_SECONDS = $saved }
    $done = Wait-Exit $r 60; $lines = @(Get-Content -LiteralPath $log)
    $sum = @($lines | Where-Object { $_ -match '\] RESOURCES: samples=(\d+) min_free_gb=[\d.]+ peak_tree_mb=(\d+) max_cpu_pct=\d+ ' })
    $n = if ($sum.Count -eq 1) { [int]([regex]::Match($sum[0], 'samples=(\d+)').Groups[1].Value) } else { 0 }
    $rows = @(if (Test-Path -LiteralPath "$log.resources.csv") { Import-Csv -LiteralPath "$log.resources.csv" })
    $ok = $done -and $r.ExitCode -eq 4 -and $n -ge 2 -and $rows.Count -eq $n -and [double]$rows[0].tree_mb -gt 0 -and $lines[-1] -match '\] END exit=4 ' -and $lines[-2] -match '\] RESOURCES: '
    [pscustomobject]@{ Ok = $ok; Detail = "done=$done exit=$(if ($done) { $r.ExitCode }) samples=$n rows=$($rows.Count) || $($lines -join ' || ')" }
}
# Two runs at once each sample into their own file and keep their own exit code and summary.
function Case-ResourcesConcurrent([string]$RunnerPath) {
    $logs = @((New-Name '.log'), (New-Name '.log')); $saved = $env:ORVION_RESOURCE_SECONDS; $env:ORVION_RESOURCE_SECONDS = '1'
    try { $rs = @((Start-Runner $RunnerPath $logs[0] "Start-Sleep -Seconds 5; exit 5"), (Start-Runner $RunnerPath $logs[1] "Start-Sleep -Seconds 5; exit 6")) } finally { $env:ORVION_RESOURCE_SECONDS = $saved }
    $done = (Wait-Exit $rs[0] 60) -and (Wait-Exit $rs[1] 60); $detail = @(); $ok = $done; $paths = @()
    foreach ($i in 0, 1) {
        $lines = @(Get-Content -LiteralPath $logs[$i]); $sum = @($lines | Where-Object { $_ -match '\] RESOURCES: samples=(\d+) .*\((.+)\)$' })
        $path = if ($sum.Count -eq 1) { [regex]::Match($sum[0], '\((.+)\)$').Groups[1].Value } else { '' }; $paths += $path
        $n = if ($sum.Count -eq 1) { [int]([regex]::Match($sum[0], 'samples=(\d+)').Groups[1].Value) } else { 0 }
        $rows = @(if ($path -and (Test-Path -LiteralPath $path)) { Import-Csv -LiteralPath $path })
        $ok = $ok -and $done -and $rs[$i].ExitCode -eq (5 + $i) -and $n -ge 2 -and $rows.Count -eq $n -and $path -eq "$($logs[$i]).resources.csv" -and $lines[-1] -match "\] END exit=$(5 + $i) "
        $detail += "run$i exit=$(if ($done) { $rs[$i].ExitCode }) samples=$n rows=$($rows.Count) path=$path"
    }
    [pscustomobject]@{ Ok = ($ok -and $paths[0] -ne $paths[1]); Detail = ($detail -join ' || ') }
}
# Killing the runner stops its sampler with it: the sampler is a thread of the runner, never a process
# of its own, so nothing keeps appending once the runner is gone.
function Case-ResourcesInterrupted([string]$RunnerPath) {
    $log = New-Name '.log'; $csv = "$log.resources.csv"; $saved = $env:ORVION_RESOURCE_SECONDS; $env:ORVION_RESOURCE_SECONDS = '1'
    try { $r = Start-Runner $RunnerPath $log "Start-Sleep -Seconds 60" } finally { $env:ORVION_RESOURCE_SECONDS = $saved }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 30 -and @(if (Test-Path -LiteralPath $csv) { Get-Content -LiteralPath $csv }).Count -lt 3) { Start-Sleep -Milliseconds 250 }
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($r.Id)" | ForEach-Object { $_.ProcessId })
    Stop-Process -Id $r.Id -Force; [void]$r.WaitForExit(10000)
    $at = @(Get-Content -LiteralPath $csv).Count; Start-Sleep -Seconds 3; $later = @(Get-Content -LiteralPath $csv).Count
    foreach ($c in $children) { Stop-Tree $c }
    $end = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '\] (END|RESOURCES):' }).Count
    [pscustomobject]@{ Ok = ($at -ge 3 -and $later -eq $at -and $end -eq 0); Detail = "rows at kill=$at rows 3 s later=$later end-or-summary lines=$end" }
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
    $ok = $done -and $w.ExitCode -eq 1 -and @($o -match '^watching steps \(started \d{4}-\d\d-\d\d \d\d:\d\d:\d\d, attached \d{4}-\d\d-\d\d \d\d:\d\d:\d\d, ').Count -eq 1 -and @($o -match '\] PASS: ').Count -eq 1 -and $fail -and $end -and $delta -ge 0.25 -and [Math]::Abs($wallMin - $total) -le 0.15 -and
          $rows.Count -eq 3 -and $rows[0].env -match 'concurrent=[^ ]*other_work\.ps1' -and $label -notmatch 'shellIntegration' -and
          @($o -match '^compare: first recorded run').Count -eq 1
    [pscustomobject]@{ Ok = $ok; Log = $log; Csv = $csv; Detail = "done=$done exit=$(if ($done) { $w.ExitCode }) delta=$delta total=$total wall=$('{0:N2}' -f $wallMin) rows=$($rows.Count) start=[$label] || $($o -join ' || ')" }
}
# Steady-state cost at the PRODUCTION cadence (10 s polls, 5-minute heartbeat): CPU sampled 20 s
# after start, once pwsh has loaded, and again a minute later.
# Every test line and every evaluator stage is recorded with its own time, at the runner's 0.06-second
# resolution; tests are recorded, not printed; a `TIME:` line keeps the duration it states.
function Case-Tests([string]$RunnerPath, [string]$WatcherPath) {
    $log = New-Name '.log'; $csv = New-Name '.csv'; $out = New-Name '.out'
    # A failed test straight after a passing one: its time is the time since that line (about 0), not since
    # the last RESULT four seconds earlier, which is what it got while `FAIL` was judged a result first.
    $r = Start-Runner $RunnerPath $log "Write-Output 'PASS: pwsh -NoProfile -File scripts/fake_a.ps1'; Start-Sleep -Seconds 4; Write-Output 'PASS t1 the first test'; Write-Output 'FAIL t2 the second test :: evidence'; Write-Output 'ok 3 - a tap test'; Write-Output 'not ok 4 - a failing tap test'; Write-Output 'not ok 5 - pending # TODO later'; Write-Output 'TIME: STAGES Gate setup=0.60s repo-guard=12.00s other=0.30s'; Write-Output 'TIME: Gate 00:00:13'; exit 0"
    $w = Start-Watcher $WatcherPath $log 'tests' 5 $csv $out; $done = Wait-Exit $w 60; [void](Wait-Exit $r 10)
    $o = @(Get-Content -LiteralPath $out); $rows = @(Import-Csv -LiteralPath $csv); $row = { param($s) @($rows | Where-Object { $_.step -eq $s })[0] }
    $inv = [Globalization.CultureInfo]::InvariantCulture; $d = { param($s) $x = & $row $s; if ($x) { [double]::Parse($x.delta_min, $inv) } else { -1 } }
    $stamps = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^\[\+\s*\d+\.\d{3} min\] ' }).Count
    $fail2 = & $d 'FAIL t2 the second test :: evidence'; $fail4 = & $d 'not ok 4 - a failing tap test'
    $ok = $done -and $stamps -ge 9 -and (& $d 'PASS t1 the first test') -ge 0.06 -and $fail2 -ge 0 -and $fail2 -lt 0.03 -and (& $d 'ok 3 - a tap test') -ge 0 -and $fail4 -ge 0 -and $fail4 -lt 0.03 -and (& $d 'not ok 5 - pending # TODO later') -ge 0 -and
          [Math]::Abs((& $d 'STAGE Gate repo-guard') - 0.2) -lt 0.001 -and [Math]::Abs((& $d 'STAGE Gate setup') - 0.01) -lt 0.001 -and [Math]::Abs((& $d 'TIME: Gate 00:00:13') - 13 / 60) -lt 0.001 -and
          -not @($o -match 'PASS t1|ok 3 - a tap|not ok 5').Count -and @($o -match 'FAIL t2').Count -eq 1 -and @($o -match 'not ok 4 - a failing').Count -eq 1
    [pscustomobject]@{ Ok = $ok; Detail = "done=$done stamps=$stamps || $($o -join ' || ') || $(($rows | ForEach-Object { "$($_.step)=$($_.delta_min)" }) -join ' | ')" }
}
# -Brief prints what needs attention and a progress line; the history still receives everything.
function Case-LateBrief([string]$WatcherPath) {
    $log=New-Name '.log';$csv=New-Name '.csv';$out=New-Name '.out'
    $at=(Get-Date).AddMinutes(-51).ToString('yyyy-MM-dd HH:mm:ss')
    $lines=[Collections.Generic.List[string]]::new()
    $lines.Add("[$at] START pid=$PID host=fixture pwsh=fixture cpus=1 head=fixture concurrent=0 | fixture")
    foreach($i in 1..1000){$t=($i/20.0).ToString('0.000',[Globalization.CultureInfo]::InvariantCulture);$lines.Add("[+ $t min] PASS historical-$i fixture")}
    $lines.Add('[+ 50.100 min] REMOTE_CERTIFY: UNREADABLE')
    $lines.Add('[+ 50.200 min] END exit=2 total=50.2 min')
    [IO.File]::WriteAllLines($log,$lines)
    $w=Start-Pwsh ('-File {0} -Log {1} -Run late-brief -PollSeconds 1 -Csv {2} -Brief -ProgressMinutes 2' -f (Q $WatcherPath),(Q $log),(Q $csv)) $out
    $done=Wait-Exit $w 30
    $o=@(Get-Content -LiteralPath $out);$rows=@(Import-Csv -LiteralPath $csv)
    $progress=@($o|Where-Object{$_-match'^progress:'}).Count
    $testRows=@($rows|Where-Object{$_.step-like'PASS historical-*'}).Count
    $ok=$done-and$w.ExitCode-eq1-and$progress-eq1-and$testRows-eq1000-and@($o|Where-Object{$_-match'\] PASS historical-'}).Count-eq0-and@($o|Where-Object{$_-match'END exit=2'}).Count-ge1
    $unreadable=$done-and@($o|Where-Object{$_-match'REMOTE_CERTIFY: UNREADABLE'}).Count-eq1-and@($rows|Where-Object{$_.step-ceq'REMOTE_CERTIFY: UNREADABLE'}).Count-eq1
    [pscustomobject]@{Ok=$ok;Unreadable=$unreadable;Detail="done=$done exit=$($w.ExitCode) progress=$progress history_tests=$testRows unreadable=$unreadable"}
}
# Generic required evidence must be visible in Brief even when its producer ended successfully.
# Reporter exit still belongs to END, never to an inferred failure cause.
function Case-GenericBrief([string]$WatcherPath) {
    $passed=$true;$details=@()
    foreach($sample in @(@{Verdict='UNREADABLE';End=0},@{Verdict='UNREADABLE';End=2},@{Verdict='READY';End=0})){
        $log=New-Name '.log';$csv=New-Name '.csv';$out=New-Name '.out'
        $at=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        [IO.File]::WriteAllLines($log,[string[]]@("[$at] START pid=$PID host=fixture pwsh=fixture cpus=1 head=fixture concurrent=0 | generic evidence fixture",'[+ 0.001 min] PASS passing-noise fixture',"[+ 0.002 min] TOOL: $($sample.Verdict)","[+ 0.003 min] END exit=$($sample.End) total=0.003 min"))
        $w=Start-Pwsh ('-File {0} -Log {1} -Run generic-brief -PollSeconds 1 -Csv {2} -Brief' -f (Q $WatcherPath),(Q $log),(Q $csv)) $out
        $done=Wait-Exit $w 30;$o=@(Get-Content -LiteralPath $out);$rows=@(Import-Csv -LiteralPath $csv)
        $visible=@($o|Where-Object{$_-match'\] TOOL: UNREADABLE'}).Count
        $recorded=@($rows|Where-Object{$_.step-ceq("TOOL: "+$sample.Verdict)}).Count
        $expectedVisible=[int]($sample.Verdict-ceq'UNREADABLE');$expectedExit=[int]($sample.End-ne0)
        $ok=$done-and$w.ExitCode-eq$expectedExit-and$visible-eq$expectedVisible-and$recorded-eq1-and@($o|Where-Object{$_-match'\] TOOL: READY|\] PASS passing-noise'}).Count-eq0
        $passed=$passed-and$ok;$details+="$($sample.Verdict)/END$($sample.End):done=$done exit=$($w.ExitCode) visible=$visible recorded=$recorded"
    }
    [pscustomobject]@{Ok=$passed;Detail=($details-join'; ')}
}
function Case-Quiet([string]$RunnerPath, [string]$WatcherPath) {
    $log = New-Name '.log'; $csv = New-Name '.csv'; $out = New-Name '.out'
    $r = Start-Runner $RunnerPath $log "Write-Output 'PASS: pwsh -NoProfile -File scripts/fake_a.ps1'; Write-Output 'PASS t1 quiet'; Start-Sleep -Seconds 2; Write-Output 'FAILED: pwsh -NoProfile -File scripts/fake_b.ps1 (exit 1)'; exit 1"
    $w = Start-Pwsh ('-File {0} -Log {1} -Run quiet -QuietMinutes 5 -PollSeconds 1 -Csv {2} -Brief -ProgressMinutes 0.01' -f (Q $WatcherPath), (Q $log), (Q $csv)) $out
    $done = Wait-Exit $w 60; [void](Wait-Exit $r 10); $o = @(Get-Content -LiteralPath $out); $rows = @(Import-Csv -LiteralPath $csv)
    $ok = $done -and $w.ExitCode -eq 1 -and -not @($o -match '\] PASS: |PASS t1').Count -and @($o -match '\] FAILED: ').Count -eq 1 -and @($o -match '\] END exit=1').Count -eq 1 -and @($o -match '^progress: [\d.]+ min - \d+ tests and \d+ results so far').Count -ge 1 -and
          @($rows | Where-Object { $_.step -like 'PASS: *' -or $_.step -eq 'PASS t1 quiet' }).Count -eq 2
    [pscustomobject]@{ Ok = $ok; Detail = "done=$done exit=$(if ($done) { $w.ExitCode }) rows=$($rows.Count) || $($o -join ' || ')" }
}
# A credential a step prints never reaches the watcher's output or the history. The runner's log, which the
# history names as evidence, is the raw output and keeps it: the redaction claim stops at the watcher.
function Case-RedactRun([string]$RunnerPath, [string]$WatcherPath) {
    $log = New-Name '.log'; $csv = New-Name '.csv'; $out = New-Name '.out'
    $r = Start-Runner $RunnerPath $log "Write-Output 'FAILED: pwsh -NoProfile -File scripts/fake_c.ps1 token=SECRETVALUE42 (exit 1)'; exit 1"
    $w = Start-Watcher $WatcherPath $log 'redact' 5 $csv $out; $done = Wait-Exit $w 60; [void](Wait-Exit $r 10)
    $o = (Get-Content -Raw -LiteralPath $out); $c = (Get-Content -Raw -LiteralPath $csv); $raw = (Get-Content -Raw -LiteralPath $log)
    [pscustomobject]@{ Ok = ($done -and $o -match 'token=<redacted>' -and "$o$c" -notmatch 'SECRETVALUE42' -and $c -match 'log=' -and $raw -match 'token=SECRETVALUE42'); Detail = "done=$done raw-log-keeps-it=$($raw -match 'SECRETVALUE42') || $o || $c" }
}
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
    [pscustomobject]@{ Ok = ($done -and $w.ExitCode -eq 1 -and $done2 -and $w2.ExitCode -eq 0 -and $rowsAfterRearm -eq 3 -and $cmp.Count -eq 1); Detail = "re-arm exit=$(if ($done) { $w.ExitCode }) later exit=$(if ($done2) { $w2.ExitCode }) rows after re-arm=$rowsAfterRearm compare=$($cmp.Count) || $((Get-Content -LiteralPath $out2) -join ' || ')" }
}

try {
    $c = Case-ExitCode $Runner;      Check 'W0 the runner preserves the command''s own exit code (3), in its END line and its own exit' $c.Ok $c.Detail
    $c = Case-Resources $Runner;     Check 'W20 the runner samples free memory, its own process tree and CPU while the command runs, and summarises them on one line before END' $c.Ok $c.Detail
    $c = Case-ResourcesConcurrent $Runner; Check 'W21 two concurrent runs each sample into their own file and keep their own exit code, summary and END' $c.Ok $c.Detail
    $c = Case-ResourcesInterrupted $Runner; Check 'W22 a killed runner leaves no sampler behind: its resource file stops growing and no END or summary is claimed' $c.Ok $c.Detail
    $c = Case-Vocabulary $Watcher;   Check 'W1 result vocabulary: every step, verdict, total and failure line; no prose or per-assertion noise' $c.Ok $c.Detail
    $c = Case-StartLine $Watcher;    Check 'W2 the START line carries date, runner pid and conditions; an old-format line is refused' $c.Ok $c.Detail
    $steps = Case-Steps $Runner $Watcher
    Check 'W3 a real run: PASS and FAILED step lines, END exit=1, a watcher exit of 1 and its attach time, timing within 0.15 min of the wall clock, labelled CSV rows' $steps.Ok $steps.Detail
    $c = Case-Stage $Runner $Watcher; Check 'W4 a silent stage produces a heartbeat naming the running repository script, then its result' $c.Ok $c.Detail
    $c = Case-Overhead $Runner $Watcher; Check 'W5 overhead at the production cadence: under 2 s of CPU per minute watched' $c.Ok $c.Detail
    "    measured: $($c.Detail)"
    $c = Case-Gone $Runner $Watcher;  Check 'W6 a runner killed mid-run is reported as RUNNER GONE and the watcher exits 1' $c.Ok $c.Detail
    $c = Case-NeverStarted $Watcher;  Check 'W7 a runner that never starts is reported, not waited on silently' $c.Ok $c.Detail
    $c = Case-Rearm $Runner $Watcher $steps; Check 'W8 a watcher re-armed on a finished failed run exits 1 and adds no duplicate rows; a later successful run exits 0 and compares with the previous one and both conditions' $c.Ok $c.Detail
    $c = Case-Eta $Watcher;          Check 'W9 an ETA is the median of what comparable successful runs still had to do, with its range; a new step falls back to run totals; one run gives none; an ended run says so' $c.Ok $c.Detail
    $c = Case-CountEta $Watcher; Check 'W38 ETA uses observed test ordinal and compatible known historical totals; insufficient/incompatible evidence gives none' $c.Ok $c.Detail
    $c = Case-CountEtaCaller $Watcher; Check 'W39 actual -Eta caller passes its observed test count for repeated keys' $c.Ok $c.Detail
    $c = Case-Findings $Watcher;     Check 'W10 findings: a recurring failure is [confirmed]; a repeated command, a slow step, an absent step and a slow run are [hypothesis]; each once' $c.Ok $c.Detail
    $c = Case-Report $Watcher;       Check 'W11 the report ranks failures by rate per run of their own name and says where the time goes' $c.Ok $c.Detail
    $c = Case-Redact $Watcher;       Check 'W12 credentials are redacted by shape and by key; prose that names a secret is kept' $c.Ok $c.Detail
    $c = Case-RedactRun $Runner $Watcher; Check 'W13 a credential a step prints reaches neither the watcher''s output nor the history; each row names its log, which keeps the raw line unredacted' $c.Ok $c.Detail
    $c = Case-Limit $Watcher;        Check 'W14 one append past the bound leaves the history within it: header, then the newest whole rows' $c.Ok $c.Detail
    $c = Case-Tests $Runner $Watcher; Check 'W15 every test line, failed ones included, and every evaluator stage is recorded with its own time at 0.06 s resolution; only failed tests are printed; a TIME line keeps its stated duration' $c.Ok $c.Detail
    $c = Case-LateBrief $Watcher; Check 'W36 late Brief attach prints one progress line while retaining all historical tests' $c.Ok $c.Detail
    Check 'W37 UNREADABLE remains visible and recorded as its literal verdict' $c.Unreadable $c.Detail
    $c = Case-GenericBrief $Watcher; Check 'W40 generic UNREADABLE is visible once, READY stays quiet, history persists and END owns reporter exit' $c.Ok $c.Detail
    $c = Case-Quiet $Runner $Watcher; Check 'W16 -Brief prints failures, the end and progress, and still records every line' $c.Ok $c.Detail
    $c = Case-Classify $Watcher;     Check 'W17 FAIL and TAP not ok are tests, ranked by time and by failure rate; a TODO or SKIP not ok is not a failure' $c.Ok $c.Detail
    $c = Case-ConcurrentAll $Watcher $Evaluator; Check 'W18 six concurrent writers (three evaluator, three watcher): every row once and whole; past the bound, within it, whole, newest rows kept' $c.Ok $c.Detail
    $c = Case-SharedWriter $Watcher $Evaluator; Check 'W19 the evaluator and the watcher share one write path, text for text' $c.Ok $c.Detail
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
        @{ Name = 'M16 a failed run read as a clean watch';   File = $Watcher; Find = 'exit [int]($body -notmatch ''^END exit=0\b'')'; Replace = 'exit 0'; Case = { param($p) Case-Steps $Runner $p } },
        @{ Name = 'M9 exit code collapsed by pwsh -Command';  File = $Runner;  Find = '"$Command`nexit `$LASTEXITCODE"'; Replace = '$Command'; Case = { param($p) Case-ExitCode $p } },
        @{ Name = 'M10 a derived verdict word dropped';       File = $Watcher; Find = 'READY|PASSED|';                   Replace = 'READY|'; Case = { param($p) Case-Vocabulary $p } },
        @{ Name = 'M8 concurrent work not detected';         File = $Runner;  Find = "'(?i)\s-File\s+";               Replace = "'(?i)\s-NoSuchFlag\s+"; Case = { param($p) Case-Steps $p $Watcher } },
        @{ Name = 'M6 branch ignored';                       File = $Ci;      Find = '$_.headBranch -eq $Branch';        Replace = '$true'; Case = { param($p) Case-CiBranch $p } },
        @{ Name = 'M7 case-insensitive error lines';         File = $Ci;      Find = '$message -cmatch $script:ErrorLineRx'; Replace = '$message -match $script:ErrorLineRx'; Case = { param($p) Case-CiEvidence $p } },
        @{ Name = 'M15 an indented failure line dropped';     File = $Ci;      Find = "'^\s*(FAIL\b|"; Replace = "'^(FAIL\b|"; Case = { param($p) Case-CiEvidence $p } },
        @{ Name = 'M11 PASS lines read as evidence';          File = $Ci;      Find = "`$message -cnotmatch '^PASS\b' -and "; Replace = ''; Case = { param($p) Case-CiEvidence $p } },
        @{ Name = 'M12 contract derived for the wrong branch'; File = $Ci;     Find = '$expected = @(Workflow-Expectations $changed $Branch)'; Replace = '$expected = @(Workflow-Expectations $changed ''orvion-preflight'')'; Case = { param($p) Case-CiContract $p } },
        @{ Name = 'M13 a missing check never reported';       File = $Ci;      Find = 'Missing    = @($Expected | Where-Object { $present -notcontains $_ })'; Replace = 'Missing    = @()'; Case = { param($p) Case-CiMissing $p } },
        @{ Name = 'M14 another event stands in for a push';   File = $Ci;      Find = " -and `$_.event -eq 'push'"; Replace = ''; Case = { param($p) Case-CiMissing $p } },
        @{ Name = 'M17 an ETA from a single run';             File = $Watcher; Find = 'if ($left.Count -lt 2)'; Replace = 'if ($left.Count -lt 1)'; Case = { param($p) Case-Eta $p } },
        @{ Name = 'M18 a recurring failure not recognised';   File = $Watcher; Find = 'if ($prior.Count) {'; Replace = 'if ($false) {'; Case = { param($p) Case-Findings $p } },
        @{ Name = 'M19 findings repeated';                    File = $Watcher; Find = '@($found | Where-Object { $State.Said.Add($_) })'; Replace = '@($found)'; Case = { param($p) Case-Findings $p } },
        @{ Name = 'M20 failures ranked by count, not rate';   File = $Watcher; Find = 'Rate = $k.Count / [Math]::Max(1, $h.Count)'; Replace = 'Rate = $k.Count'; Case = { param($p) Case-Report $p } },
        @{ Name = 'M21 redaction disabled';                   File = $Watcher; Find = 'function Hide-Secret([string]$Text) {'; Replace = 'function Hide-Secret([string]$Text) { return $Text'; Case = { param($p) Case-Redact $p } },
        @{ Name = 'M22 a step''s line not redacted';           File = $Watcher; Find = '$body = Hide-Secret $m.Groups[''body''].Value'; Replace = '$body = $m.Groups[''body''].Value'; Case = { param($p) Case-RedactRun $Runner $p } },
        @{ Name = 'M23 the history never bounded';            File = $Watcher; Find = 'if ([IO.FileInfo]::new($Path).Length -le $MaxBytes) { return }'; Replace = 'return'; Case = { param($p) Case-Limit $p } },
        @{ Name = 'M24 test lines not recorded';              File = $Watcher; Find = 'if (Test-TestLine $body) {'; Replace = 'if ($false) {'; Case = { param($p) Case-Tests $Runner $p } },
        @{ Name = 'M29 a failed test judged a result first';   File = $Watcher; Find = 'if (Test-TestLine $body) {'; Replace = 'if ((Test-TestLine $body) -and -not (Test-ResultLine $body)) {'; Case = { param($p) Case-Tests $Runner $p } },
        @{ Name = 'M30 the history reads a failed test as a result'; File = $Watcher; Find = "elseif (Test-TestLine `$Step) { 'test' }"; Replace = "elseif ((Test-TestLine `$Step) -and -not (Test-ResultLine `$Step)) { 'test' }"; Case = { param($p) Case-Classify $p } },
        @{ Name = 'M31 a TODO not ok counted as a failure';    File = $Watcher; Find = '(?!.*#\s*(?i:todo|skip)\b)'; Replace = ''; Case = { param($p) Case-Classify $p } },
        @{ Name = 'M32 test times ranked from successful runs only'; File = $Watcher; Find = '$per = @{}; foreach ($r in $h) {'; Replace = '$per = @{}; foreach ($r in $ok) {'; Case = { param($p) Case-Classify $p } },
        @{ Name = 'M33 writers not serialised';               File = $Watcher; Find = "'Global\ORVION-timings-' + `$id.Substring(0, 32)"; Replace = "'Global\ORVION-timings-' + [guid]::NewGuid().ToString('N')"; Case = { param($p) Case-ConcurrentAll $p $Evaluator } },
        @{ Name = 'M25 -Brief prints everything';             File = $Watcher; Find = 'if (-not $Brief -or $body -cmatch $script:AttentionRx)'; Replace = 'if ($true)'; Case = { param($p) Case-Quiet $Runner $p } },
        @{ Name = 'M26 a TIME line''s stated duration ignored'; File = $Watcher; Find = '$(if ($null -ne $stated -and $step -like ''TIME: *'') { $stated } else { $delta })'; Replace = '$delta'; Case = { param($p) Case-Tests $Runner $p } },
        @{ Name = 'M27 stages not split';                     File = $Watcher; Find = '$stages = @(Split-Stages $body)'; Replace = '$stages = @()'; Case = { param($p) Case-Tests $Runner $p } },
        @{ Name = 'M28 the runner stamps a tenth of a minute'; File = $Runner;  Find = "ToString('0.000',"; Replace = "ToString('0.0',"; Case = { param($p) Case-Tests $p $Watcher } },
        @{ Name = 'M34 resources never sampled';              File = $Runner;  Find = 'if ($IsWindows) {'; Replace = 'if ($false) {'; Case = { param($p) Case-Resources $p } },
        @{ Name = 'M35 concurrent runs share one resource file'; File = $Runner; Find = '$resources = "$Log.resources.csv"'; Replace = '$resources = Join-Path ([IO.Path]::GetTempPath()) ''orvion-resources.csv'''; Case = { param($p) Case-ResourcesConcurrent $p } },
        @{ Name = 'M38 repeated test ordinal ignored'; File = $Watcher; Find = '$s = $testRows[$TestCount - 1]'; Replace = '$s = $testRows[0]'; Case = { param($p) Case-CountEta $p } },
        @{ Name = 'M39 incompatible historical test totals accepted'; File = $Watcher; Find = 'if ($totals.Count -ne 1)'; Replace = 'if ($false)'; Case = { param($p) Case-CountEta $p } },
        @{ Name = 'M40 actual ETA caller drops observed test count'; File = $Watcher; Find = ' (@($lines | Where-Object { Test-TestLine $_.Groups[''body''].Value }).Count)'; Replace = ' 0'; Case = { param($p) Case-CountEtaCaller $p } },
        @{ Name = 'M36 UNREADABLE verdict dropped'; File = $Watcher; Find = '|UNREADABLE|'; Replace = '|'; Case = { param($p) $v=Case-LateBrief $p;[pscustomobject]@{Ok=$v.Unreadable;Detail=$v.Detail} } },
        @{ Name = 'M41 generic UNREADABLE attention removed'; File = $Watcher; Find = '|INCOMPLETE|UNPROVEN|UNREADABLE|RECOVERY_EXHAUSTED|'; Replace = '|INCOMPLETE|UNPROVEN|RECOVERY_EXHAUSTED|'; Case = { param($p) Case-GenericBrief $p } },
        @{ Name = 'M37 historical Brief progress floods'; File = $Watcher; Find = '            if ($Brief -and ((-not $replaying -and $t - $lastProgress -ge $ProgressMinutes) -or ($replaying -and $body -match ''^END exit=''))) {'; Replace = '            if ($Brief -and $t - $lastProgress -ge $ProgressMinutes) {'; Case = { param($p) Case-LateBrief $p } }
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
