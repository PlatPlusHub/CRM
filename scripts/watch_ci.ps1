# ORVION CI watcher -- ON-DEMAND REPORTING ADAPTER (AGENTS.md section 7). It owns no truth.
#
# Follows the GitHub Actions push runs on one exact SHA and BRANCH against that branch's own contract,
# and prints each run's conclusion with the minutes elapsed; for a run that did not succeed, the failed
# job and step, how many migrations it applied, and the last error-like lines of that job's log.
#
# THE CONTRACT IS DERIVED, NEVER LISTED. Which workflows a push must produce is decided by
# `Workflow-Expectations` in `scripts/check_agent_continuity.ps1` -- the deriver `-Finish` records and
# `-Certify` judges -- applied to the workflow files AS THEY ARE AT -Sha and to the paths changed between
# -Base and -Sha (the `upstream..HEAD` range `-Finish` uses, so -Base is the `main` commit the SHA is
# published on top of). A workflow whose `branches:` filter excludes the branch is not expected there
# (ORVION Acceptance runs on `orvion-preflight` only; on `main` the ruleset is satisfied by that run on
# the same SHA), and a path-filtered workflow is expected only when a changed path matches. The candidate
# and `main` share one SHA, so the branch is mandatory: a finished candidate run is never read as `main`'s.
#
# It finishes when every expected workflow has a completed run on the branch, nothing there is still
# open, and -SettleSeconds passed with no new run. An expected workflow that has not started when
# everything else has finished is waited for -MissingMinutes more, then reported MISSING -- a check that
# never ran is never read as one that passed. Exit 0 means every expected run ran and succeeded; 1, that
# one failed or is missing; 2, that GitHub could not be read. That is a summary of the evidence printed
# above it: `check_agent_continuity.ps1 -Certify` remains the verdict.
#
# EVIDENCE ONLY. It never classifies a failure as infrastructure or code and never reruns anything. A
# familiar message is not a cause: run 37823191020's single log holds a non-fatal `toomanyrequests`
# beside the fatal `Bus error`, so the reader establishes the cause from the evidence printed here.
#
# Usage:
#   pwsh -NoProfile -File scripts/watch_ci.ps1 -Sha <full sha> -Branch orvion-preflight -Base origin/main
#   pwsh -NoProfile -File scripts/watch_ci.ps1 -Sha <full sha> -Branch main -Base <the previous main sha>
#   pwsh -NoProfile -File scripts/watch_ci.ps1 -RunId <id> -Attempt <n>     # one attempt, post-mortem
param(
    [string]$Sha,
    [string]$Branch,
    [string]$Base,
    [long]$RunId,
    [int]$Attempt = 1,
    [int]$SettleSeconds = 90,
    [double]$MissingMinutes = 10,
    [int]$PollSeconds = 30,
    [double]$QuietMinutes = 5,
    [string]$Repo = 'PlatPlusHub/CRM',
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

# ---- the contract: the authority's own deriver, applied to the workflow files at the SHA --------------
# Read from the authority's AST and defined here, never copied: a copy would drift from what -Certify judges.
$authority = Join-Path $RepoRoot 'scripts/check_agent_continuity.ps1'
$authorityAst = [Management.Automation.Language.Parser]::ParseFile($authority, [ref]$null, [ref]$null)
foreach ($fnName in 'Glob-Regex', 'Trigger-List', 'Workflow-Expectations') {
    $fnAst = $authorityAst.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fnName }, $true) | Select-Object -First 1
    if (-not $fnAst) { throw "AUTHORITY_MOVED: $fnName is no longer defined in $authority" }
    . ([scriptblock]::Create($fnAst.Extent.Text))
}
function Get-CiContract([string]$Sha, [string]$Base, [string]$Branch, [string]$GitRoot) {
    $tree = Join-Path ([IO.Path]::GetTempPath()) ('orvion-ci-contract-' + [guid]::NewGuid().ToString('N'))
    $wf = Join-Path $tree '.github/workflows'; [void][IO.Directory]::CreateDirectory($wf)
    try {
        $all = @()
        foreach ($p in @(git -C $GitRoot ls-tree --name-only "${Sha}:.github/workflows" 2>$null)) {
            if ($p -notmatch '\.ya?ml$') { continue }
            $text = (git -C $GitRoot show "${Sha}:.github/workflows/$p") -join "`n"
            [IO.File]::WriteAllText((Join-Path $wf $p), $text + "`n")
            $n = [regex]::Match($text, '(?m)^name:\s*(?<v>.+?)\s*$'); if ($n.Success -and $text -match '(?m)^  push:') { $all += $n.Groups['v'].Value }
        }
        if (-not $all) { throw "CONTRACT_UNREADABLE: no push workflow at $Sha (is the SHA fetched?)" }
        $changed = @(git -C $GitRoot diff --name-only $Base $Sha --)
        if ($LASTEXITCODE -ne 0) { throw "CONTRACT_UNREADABLE: cannot diff $Base..$Sha" }
        $Root = $tree   # Workflow-Expectations reads `$Root/.github/workflows`, here the files at -Sha
        $expected = @(Workflow-Expectations $changed $Branch)
        [pscustomobject]@{ Expected = $expected; NotExpected = @($all | Where-Object { $expected -notcontains $_ } | Sort-Object); Changed = $changed.Count }
    } finally { [IO.Directory]::Delete($tree, $true) }
}

# The state of one branch's push runs against its contract. Pure, so the self-test can judge it on fixtures.
function Get-CiState([object[]]$Runs, [string]$Branch, [string[]]$Expected) {
    $mine = @($Runs | Where-Object { $_.headBranch -eq $Branch -and $_.event -eq 'push' })
    $present = @($mine | ForEach-Object name | Sort-Object -Unique)
    $open = @($mine | Where-Object { $_.status -ne 'completed' })
    [pscustomobject]@{
        Mine       = $mine
        Others     = @($Runs | Where-Object { -not ($_.headBranch -eq $Branch -and $_.event -eq 'push') })
        Open       = $open.Count
        Missing    = @($Expected | Where-Object { $present -notcontains $_ })
        Unexpected = @($present | Where-Object { $Expected -notcontains $_ })
        AllSucceeded = (@($mine | Where-Object { $_.status -ne 'completed' -or $_.conclusion -ne 'success' }).Count -eq 0)
    }
}

# The failure-like lines of a job log, judged on each line's MESSAGE (its runner timestamp removed), with
# ANSI and control characters stripped. Measured on real logs, not assumed (2026-10-09):
#   * the repository's own refusals -- `ORVION: BLOCKED`, `CODE: <code>`, `EVIDENCE: ...` -- are the
#     whole cause of a Gate failure (run 34700639112 on `main`: AMBIGUOUS_GOVERNING_CR) and must be kept;
#   * per-assertion `PASS 145 a main failure is FAILED ...` lines contain the word and are not failures,
#     so a message that opens with PASS is never evidence (it once filled the window in run 36600463643);
#   * infrastructure messages (`toomanyrequests`, `Bus error`) are KEPT and never interpreted.
#   * a suite indents its own failure line (`  FAIL CONTROL: ...`, run 36600463643), so leading space is allowed.
# CASE-SENSITIVE: `FAILED` and `ERROR:` are emitted words, and prose such as "fail-closed" is not one.
$script:ErrorLineRx = '^\s*(FAIL\b|FAILED: |CODE: (?!none\b)|EVIDENCE: (?!none\b)|[A-Z][A-Z0-9_]*(?: [A-Z0-9_]+)*: (BLOCKED|FAILED|INCOMPLETE|UNPROVEN|NOT [A-Z]+|\d+ issue)|##\[error\])|\b[1-9]\d* failed\b|\bFAILED\b|\bnot ok\b|ERROR:|Bus error|toomanyrequests|deadline exceeded|FATAL|panic:'
function Select-ErrorLines([string[]]$LogLines, [int]$Last = 8) {
    @($LogLines | ForEach-Object { ($_ -replace "\x1b\[[0-9;]*[A-Za-z]", '') -replace '[\x00-\x08\x0b-\x1f]', '' } |
        Where-Object { $message = $_ -replace '^\d{4}-\d\d-\d\dT[\d:.]+Z\s', ''; $message -cnotmatch '^PASS\b' -and $message -cmatch $script:ErrorLineRx } |
        Select-Object -Last $Last | ForEach-Object { $_.Substring(0, [Math]::Min(200, $_.Length)).TrimEnd() })
}
function Format-Summary([object[]]$Runs) {
    (@($Runs | Group-Object { if ($_.status -eq 'completed') { $_.conclusion } else { $_.status } } | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', ')
}

if ($MyInvocation.InvocationName -eq '.') { return }   # dot-sourced by scripts/watch_selftest.ps1 for the functions above
$ErrorActionPreference = 'Stop'
$sw = [Diagnostics.Stopwatch]::StartNew()
function T { '[{0,5:N1} min]' -f $sw.Elapsed.TotalMinutes }
function Show-Evidence([long]$Id, [int]$Att) {
    $jobs = @(gh api "repos/$Repo/actions/runs/$Id/attempts/$Att/jobs" --jq '.jobs[] | select(.conclusion=="failure") | "\(.id)\t\(.name)\t\([.steps[] | select(.conclusion=="failure") | .name] | join("; "))"')
    if (-not $jobs) { '    no failed job recorded (conclusion other than failure: read the run page)'; return }
    foreach ($j in $jobs) {
        $f = $j -split "`t"
        "    failed job: $($f[1]) | failed step: $($f[2])"
        $log = @(gh api --allow-escape-sequences "repos/$Repo/actions/jobs/$($f[0])/logs" 2>$null)
        "    log lines: $($log.Count) | migrations applied: $(@($log | Select-String 'Applying migration').Count)"
        Select-ErrorLines $log | ForEach-Object { '    > ' + $_ }
    }
}

if ($RunId) {
    $r = gh run view $RunId --repo $Repo --attempt $Attempt --json name,conclusion,status,attempt,headSha,headBranch | ConvertFrom-Json
    "$(T) run $RunId attempt $($r.attempt) [$($r.name)] on $($r.headBranch) $($r.status)/$($r.conclusion) sha=$($r.headSha.Substring(0,7))"
    if ($r.status -eq 'completed' -and $r.conclusion -ne 'success') { Show-Evidence $RunId $Attempt }
    exit 0
}
if (-not $Sha -or -not $Branch -or -not $Base) { throw 'usage: watch_ci.ps1 -Sha <full sha> -Branch <branch> -Base <main commit it is published on>   (or -RunId <id> [-Attempt <n>])' }
$Sha = (git -C $RepoRoot rev-parse $Sha).Trim()
$contract = Get-CiContract $Sha $Base $Branch $RepoRoot
"$(T) watching $($Sha.Substring(0,7)) on $Branch ($($contract.Changed) paths changed since $Base)"
"$(T) expected here: $(if ($contract.Expected) { $contract.Expected -join ', ' } else { 'nothing' }); not expected here: $(if ($contract.NotExpected) { $contract.NotExpected -join ', ' } else { 'none' })"

$reported = @{}; $otherSeen = @{}; $settleAt = $null; $missingSince = $null; $failures = 0; $quiet = [Diagnostics.Stopwatch]::StartNew()
while ($true) {
    try {
        # A failed `gh` prints nothing to stdout, and an empty pipeline parses as "no runs" -- so
        # its exit code is checked, or an outage would read as a quiet SHA.
        $json = gh run list --repo $Repo --commit $Sha --json databaseId,name,status,conclusion,attempt,event,headBranch,createdAt --limit 50
        if ($LASTEXITCODE -ne 0) { throw "gh run list exited $LASTEXITCODE" }
        $runs = @($json | ConvertFrom-Json)
        $failures = 0
    } catch {
        $failures++
        "$(T) poll failed ($failures of 5): $($_.Exception.Message)"
        if ($failures -ge 5) { "$(T) STOPPED: five consecutive polls failed - nothing about this SHA was observed since"; exit 2 }
        Start-Sleep -Seconds $PollSeconds; continue
    }
    $state = Get-CiState $runs $Branch $contract.Expected
    foreach ($r in $state.Mine) {
        $key = "$($r.databaseId)#$($r.attempt)"
        if ($r.status -eq 'completed' -and -not $reported.ContainsKey($key)) {
            $reported[$key] = $r.conclusion; $quiet.Restart(); $settleAt = $null
            $tag = if ($contract.Expected -contains $r.name) { '' } else { ' (not in the contract)' }
            "$(T) $($r.name)$tag run $($r.databaseId) attempt $($r.attempt): $($r.conclusion)"
            if ($r.conclusion -ne 'success') { Show-Evidence $r.databaseId $r.attempt }
        }
    }
    foreach ($r in $state.Others) {
        $key = "$($r.databaseId)#$($r.attempt)#$($r.status)"
        if (-not $otherSeen.ContainsKey($key)) { $otherSeen[$key] = 1; "$(T) (not this watch: $($r.event) on $($r.headBranch)) $($r.name): $($r.status)/$($r.conclusion)" }
    }
    $summary = "runs $($state.Mine.Count) [$(Format-Summary $state.Mine)]"
    if ($state.Open -gt 0) { $settleAt = $null; $missingSince = $null }
    elseif (-not $state.Missing) {
        $missingSince = $null
        if (-not $settleAt) { $settleAt = (Get-Date).AddSeconds($SettleSeconds) }
        elseif ((Get-Date) -ge $settleAt) {
            if ($state.AllSucceeded) { "$(T) DONE on $($Sha.Substring(0,7)) / ${Branch}: every expected workflow ran and succeeded; $summary. -Certify is the verdict."; exit 0 }
            "$(T) DONE WITH FAILURE on $($Sha.Substring(0,7)) / ${Branch}: $summary. -Certify is the verdict."; exit 1
        }
    } else {
        $settleAt = $null
        if (-not $missingSince) { $missingSince = Get-Date }
        elseif (((Get-Date) - $missingSince).TotalMinutes -ge $MissingMinutes) {
            "$(T) MISSING on $($Sha.Substring(0,7)) / ${Branch}: $($state.Missing -join ', ') never ran ($('{0:N1}' -f $MissingMinutes) min after everything else finished); $summary. A check that did not run has not passed."
            exit 1
        }
    }
    if ($quiet.Elapsed.TotalMinutes -ge $QuietMinutes) {
        $openNow = @($state.Mine | Where-Object { $_.status -ne 'completed' } | ForEach-Object { "$($_.name) $($_.status) $('{0:N1}' -f ((Get-Date).ToUniversalTime() - ([datetime]$_.createdAt).ToUniversalTime()).TotalMinutes) min" })
        $what = if ($openNow) { 'open: ' + ($openNow -join '; ') } elseif ($state.Missing) { 'expected, not started: ' + ($state.Missing -join ', ') } else { 'settling' }
        "$(T) heartbeat: nothing new for $('{0:N1}' -f $quiet.Elapsed.TotalMinutes) min - $what"
        $quiet.Restart()
    }
    Start-Sleep -Seconds $PollSeconds
}
