# ORVION Workstation Update - preview first, then apply exactly what was previewed.
# Windows PowerShell 5.1 compatible, ASCII-only.
#
# Default: read-only. It asks winget and npm which ORVION tools they manage and which have an
# upgrade, prints that plan, and changes nothing. Interactive runs (the menu) are asked to confirm;
# `-Apply` applies without asking. Only the previewed rows are applied, then the doctor verifies.
#
# A tool another installer provides (Git from scoop, Python from the Store, the Codex desktop
# installer) is REPORTED, never "upgraded": winget and npm do nothing for it. This script used to
# ask them anyway, so Git read FAILED on every run (winget exit -1978335212, no installed package)
# and Codex read ok while `npm update -g` changed nothing. The project-local Supabase CLI is pinned
# by package-lock.json and changes only through a Change Request.
param([switch]$Apply)

$WingetTools = @(
    @{ Cmd = 'git'; Id = 'Git.Git' }, @{ Cmd = 'gh'; Id = 'GitHub.cli' }, @{ Cmd = 'node'; Id = 'OpenJS.NodeJS.LTS' },
    @{ Cmd = 'docker'; Id = 'Docker.DockerDesktop' }, @{ Cmd = 'python'; Id = 'Python.Python.3.12' },
    @{ Cmd = 'pwsh'; Id = 'Microsoft.PowerShell' }, @{ Cmd = 'code'; Id = 'Microsoft.VisualStudioCode' })
$NpmTools = @(@{ Cmd = 'claude'; Package = '@anthropic-ai/claude-code' }, @{ Cmd = 'codex'; Package = '@openai/codex' })

# The plan, decided only from what winget and npm reported. Pure, so scripts/test_workstation.ps1 judges it.
#   $WingetManaged  ids `winget list --id <id> -e` found;  $UpgradeTable  the lines `winget upgrade` printed;
#   $NpmManaged     global packages `npm ls -g` lists;     $NpmOutdated   `npm outdated -g --json`, parsed.
function Get-UpdatePlan($WingetTools, [string[]]$WingetManaged, [string[]]$UpgradeTable, $NpmTools, [string[]]$NpmManaged, $NpmOutdated) {
    foreach ($t in $WingetTools) {
        $row = @($UpgradeTable | Where-Object { $_ -match ('\s' + [regex]::Escape($t.Id) + '\s') }) | Select-Object -First 1
        if ($WingetManaged -notcontains $t.Id) { [pscustomobject]@{ Tool = $t.Cmd; Channel = 'winget'; Target = $t.Id; Action = 'report'; Detail = 'not installed by winget: update it through the installer that provided it' } }
        # The table reads Name, Id, Version, Available, Source; the three tokens after the id are applied as previewed.
        elseif ($row) { $v = @($row.Trim() -split '\s+'); $i = [array]::IndexOf($v, $t.Id); [pscustomobject]@{ Tool = $t.Cmd; Channel = 'winget'; Target = $t.Id; Action = 'upgrade'; Version = $v[$i + 2]; Source = $v[$i + 3]; Detail = "$($v[$i + 1]) -> $($v[$i + 2])" } }
        else { [pscustomobject]@{ Tool = $t.Cmd; Channel = 'winget'; Target = $t.Id; Action = 'none'; Detail = 'up to date' } }
    }
    foreach ($t in $NpmTools) {
        $o = if ($NpmOutdated) { $NpmOutdated.PSObject.Properties[$t.Package] } else { $null }
        if ($NpmManaged -notcontains $t.Package) { [pscustomobject]@{ Tool = $t.Cmd; Channel = 'npm'; Target = $t.Package; Action = 'report'; Detail = 'not installed by npm: update it through the installer that provided it' } }
        elseif ($o) { [pscustomobject]@{ Tool = $t.Cmd; Channel = 'npm'; Target = $t.Package; Action = 'upgrade'; Version = $o.Value.latest; Detail = "$($o.Value.current) -> $($o.Value.latest)" } }
        else { [pscustomobject]@{ Tool = $t.Cmd; Channel = 'npm'; Target = $t.Package; Action = 'none'; Detail = 'up to date' } }
    }
}

$ErrorActionPreference = 'Continue'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
# Success-equivalent per microsoft/winget-cli doc/windows/package-manager/winget/returnCodes.md:
#   0x8A15002B UPDATE_NOT_APPLICABLE, 0x8A150061 PACKAGE_ALREADY_INSTALLED.
$UpToDateExitCodes = @(-1978335189, -1978335135)

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Host '[FAIL] winget unavailable (install App Installer)'; exit 1 }
$managed = @(foreach ($t in $WingetTools) { winget list --id $t.Id -e --accept-source-agreements *> $null; if ($LASTEXITCODE -eq 0) { $t.Id } })
$table = @(winget upgrade --accept-source-agreements 2>&1 | ForEach-Object { "$_" })
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] winget upgrade could not list upgrades (exit $LASTEXITCODE)"; exit 1 }
$npmManaged = @(); $npmOutdated = $null
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $ls = npm ls -g --depth=0 --json 2>$null | Out-String | ConvertFrom-Json
    if ($ls.dependencies) { $npmManaged = @($ls.dependencies.PSObject.Properties.Name) }
    $raw = npm outdated -g --json 2>$null | Out-String   # exits 1 when anything is outdated; the JSON is the answer
    if ($raw.Trim()) { $npmOutdated = $raw | ConvertFrom-Json }
}
$plan = @(Get-UpdatePlan $WingetTools $managed $table $NpmTools $npmManaged $npmOutdated)

Write-Host ''; Write-Host '== Update preview =='
foreach ($p in $plan) { Write-Host ('  {0,-8} {1,-7} {2,-8} {3}' -f $p.Tool, $p.Channel, $p.Action, $p.Detail) }
Write-Host '  supabase project  pinned   package-lock.json; changed only through a Change Request'
$todo = @($plan | Where-Object { $_.Action -eq 'upgrade' })
if (-not $todo.Count) { Write-Host ''; Write-Host 'Nothing to upgrade.'; exit 0 }
if (@($todo | Where-Object { $_.Target -eq 'Docker.DockerDesktop' }).Count) {
    Write-Host '[WARN] Upgrading Docker Desktop restarts the engine and stops every running container, the local Supabase stack included.'
}
if (-not $Apply) {
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) { $Apply = (Read-Host "Apply these $($todo.Count) upgrade(s)? [y/N]") -match '^[yY]' }
    if (-not $Apply) { Write-Host ''; Write-Host 'PREVIEW ONLY: nothing was changed. Run .workstation/update.ps1 -Apply to apply exactly the upgrades above.'; exit 0 }
}

$failed = 0
foreach ($p in $todo) {
    Write-Host ''; Write-Host "[UPGRADE] $($p.Tool) ($($p.Target))"
    # --allow-scripts: npm 11.16+ warns, and npm 12 refuses, a global package's install script unless it is
    # allowed; Claude Code's postinstall is what installs its executable.
    # Exactly the previewed version, so a release published after the preview is never applied unseen.
    if ($p.Channel -eq 'winget') { winget upgrade --id $p.Target -e --version $p.Version --source $p.Source --accept-source-agreements --accept-package-agreements }
    else { npm install -g "$($p.Target)@$($p.Version)" "--allow-scripts=$($p.Target)" }
    if ($LASTEXITCODE -ne 0 -and $UpToDateExitCodes -notcontains $LASTEXITCODE) { Write-Host "[FAIL] $($p.Tool) upgrade exited $LASTEXITCODE"; $failed++ }
}

Write-Host ''; Write-Host '== Verify =='
& (Join-Path $PSScriptRoot 'doctor.ps1')
if ($failed -or $LASTEXITCODE -ne 0) { Write-Host "WORKSTATION UPDATE: INCOMPLETE ($failed upgrade(s) failed)"; exit 1 }
Write-Host 'WORKSTATION UPDATE: COMPLETE'; exit 0
