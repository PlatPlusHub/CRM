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
# What it runs can see that it is timed and where: `check_agent_continuity.ps1 -Finish` refuses to
# start without this (SPEC-283, CR_LIFECYCLE.md §9).
$env:ORVION_TIMED_LOG = $Log
'[{0}] START pid={1} {2} | {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID, $envLabel, $Command | Out-File -LiteralPath $Log -Encoding utf8
# Stamped to a thousandth of a minute (0.06 s), culture-invariant, so every test line a suite prints
# carries its own measurable time (SPEC-283); a tenth of a minute hid every test shorter than 6 s.
function Stamp { $sw.Elapsed.TotalMinutes.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture).PadLeft(8) }
# RESOURCES. While the command runs, free memory, this run's own process tree and CPU are sampled to
# `<log>.resources.csv` every ORVION_RESOURCE_SECONDS (default 60), and one summary line precedes END,
# so the conditions behind a slow or killed run (a suite was killed at 1.7 GB free on 2026-10-12) and
# the headroom for running two suites together are measured, not guessed. It observes only. A host
# without these Windows counters, such as a hosted Linux runner, says `RESOURCES: unavailable`.
$resources = "$Log.resources.csv"; $sampler = $null
if ($IsWindows) {
    $every = 60; if (-not [int]::TryParse("$env:ORVION_RESOURCE_SECONDS", [ref]$every) -or $every -lt 1) { $every = 60 }
    $sampler = Start-ThreadJob -ArgumentList $PID, $resources, $every -ScriptBlock {
        param($Root, $Path, $Seconds)
        $inv = [Globalization.CultureInfo]::InvariantCulture
        'at,free_gb,tree_mb,cpu_pct' | Out-File -LiteralPath $Path -Encoding utf8
        while ($true) {
            $all = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, WorkingSetSize)
            $ids = [Collections.Generic.HashSet[int]]::new(); [void]$ids.Add($Root)
            do { $n = $ids.Count; foreach ($p in $all) { if ($ids.Contains([int]$p.ParentProcessId)) { [void]$ids.Add([int]$p.ProcessId) } } } while ($ids.Count -gt $n)
            $tree = ($all | Where-Object { $ids.Contains([int]$_.ProcessId) } | Measure-Object WorkingSetSize -Sum).Sum / 1MB
            $free = (Get-CimInstance Win32_OperatingSystem -Property FreePhysicalMemory).FreePhysicalMemory / 1MB
            $cpu = (Get-CimInstance Win32_Processor -Property LoadPercentage | Measure-Object LoadPercentage -Average).Average
            [string]::Format($inv, '{0:yyyy-MM-dd HH:mm:ss},{1:0.00},{2:0},{3:0}', (Get-Date), $free, $tree, $cpu) | Out-File -LiteralPath $Path -Append -Encoding utf8
            Start-Sleep -Seconds $Seconds
        }
    }
}
pwsh -NoProfile -Command "$Command`nexit `$LASTEXITCODE" 2>&1 | ForEach-Object { '[+{0} min] {1}' -f (Stamp), $_ } | Out-File -LiteralPath $Log -Append -Encoding utf8
# `pwsh -Command` collapses a child's exit code to 1 unless it is propagated explicitly, exactly as
# `check_agent_continuity.ps1` Invoke-Verification does; the appended `exit $LASTEXITCODE` is that propagation.
$code = $LASTEXITCODE
if ($sampler) { Stop-Job $sampler; Remove-Job $sampler -Force }
# A sample cut off by Stop-Job is dropped, never allowed to disturb END or the exit code.
$summary = try {
    $inv = [Globalization.CultureInfo]::InvariantCulture; $x = 0.0
    $rows = @(if ($sampler -and (Test-Path -LiteralPath $resources)) { Import-Csv -LiteralPath $resources | Where-Object { [double]::TryParse("$($_.cpu_pct)", [Globalization.NumberStyles]::Float, $inv, [ref]$x) } })
    if (-not $rows.Count) { 'RESOURCES: unavailable' } else {
        $col = { param($Name) $rows | ForEach-Object { [double]::Parse($_.$Name, $inv) } }
        [string]::Format($inv, 'RESOURCES: samples={0} min_free_gb={1:0.00} peak_tree_mb={2:0} max_cpu_pct={3:0} ({4})', $rows.Count,
            (& $col free_gb | Measure-Object -Minimum).Minimum, (& $col tree_mb | Measure-Object -Maximum).Maximum, (& $col cpu_pct | Measure-Object -Maximum).Maximum, $resources) }
} catch { "RESOURCES: unreadable ($($_.Exception.Message))" }
'[+{0} min] {1}' -f (Stamp), $summary | Out-File -LiteralPath $Log -Append -Encoding utf8
$after = Get-ConcurrentScripts
'[+{0} min] END exit={1} total={2} min concurrent_end={3}' -f (Stamp), $code, $sw.Elapsed.TotalMinutes.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture), $(if ($after.Count) { $after -join ',' } else { '0' }) | Out-File -LiteralPath $Log -Append -Encoding utf8
exit $code
