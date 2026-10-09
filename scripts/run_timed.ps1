# ORVION timed runner -- ON-DEMAND REPORTING ADAPTER (AGENTS.md section 7). It owns no truth.
#
# Runs one command and writes every output line to -Log prefixed with the minutes elapsed, so a
# long run (`check_agent_continuity.ps1 -Finish`, a guard suite) can be watched while it runs
# (`scripts/watch_run.ps1`) and its timing quoted with the conditions it was measured under
# (`ENGINEERING_METHOD.md §3`). The START line records the date, the runner's process id, the
# environment, and how many OTHER repository scripts were already running: a run measured beside
# other work is labelled as such and is not a baseline. The command's exit code is preserved.
#
# It never retries, reruns, filters, or judges anything, and it replaces no verification.
#
# Usage:
#   pwsh -NoProfile -File scripts/run_timed.ps1 -Log <file> -Command "pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish"
param(
    [Parameter(Mandatory)][string]$Log,
    [Parameter(Mandatory)][string]$Command,
    [string]$WorkingDirectory = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Continue'
$Log = [IO.Path]::GetFullPath($Log, (Get-Location).Path)
Set-Location -LiteralPath $WorkingDirectory

# Other PowerShell script files running now (`-File <x>.ps1`, from any directory: the run that made
# SPEC-248's -Finish timing unusable was a scratch validation script outside `scripts/`). An editor's
# terminal integration is dot-sourced through -Command, not run with -File, so it is not counted; nor
# are these tools, because a watcher observing this run is not load on it. The label is a lower bound:
# work started any other way is not seen.
function Get-ConcurrentScripts {
    @(Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID } | ForEach-Object {
            $m = [regex]::Match("$($_.CommandLine)", '(?i)\s-File\s+(?:"(?<f>[^"]+\.ps1)"|''(?<f>[^'']+\.ps1)''|(?<f>\S+\.ps1))')
            if ($m.Success) { Split-Path $m.Groups['f'].Value -Leaf } } |
        Where-Object { $_ -notmatch '^(run_timed|watch_\w+)\.ps1$' })
}
$head = (git rev-parse --short HEAD 2>$null); if (-not $head) { $head = 'none' }
$before = Get-ConcurrentScripts
$envLabel = 'host={0} pwsh={1} cpus={2} head={3} concurrent={4}' -f $env:COMPUTERNAME, $PSVersionTable.PSVersion, [Environment]::ProcessorCount, $head, $(if ($before.Count) { $before -join ',' } else { '0' })
$sw = [Diagnostics.Stopwatch]::StartNew()
'[{0}] START pid={1} {2} | {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID, $envLabel, $Command | Out-File -LiteralPath $Log -Encoding utf8
pwsh -NoProfile -Command "$Command`nexit `$LASTEXITCODE" 2>&1 | ForEach-Object { '[+{0,6:N1} min] {1}' -f $sw.Elapsed.TotalMinutes, $_ } | Out-File -LiteralPath $Log -Append -Encoding utf8
# `pwsh -Command` collapses a child's exit code to 1 unless it is propagated explicitly, exactly as
# `check_agent_continuity.ps1` Invoke-Verification does; the appended `exit $LASTEXITCODE` is that propagation.
$code = $LASTEXITCODE
$after = Get-ConcurrentScripts
'[+{0,6:N1} min] END exit={1} total={0:N1} min concurrent_end={2}' -f $sw.Elapsed.TotalMinutes, $code, $(if ($after.Count) { $after -join ',' } else { '0' }) | Out-File -LiteralPath $Log -Append -Encoding utf8
exit $code
