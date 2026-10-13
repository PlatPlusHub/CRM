# ORVION Workstation - Recovery & Maintenance launcher (human entry point).
# Purpose: disaster recovery + first-time bootstrap of the ORVION workstation, then light
# maintenance. NOT a development dashboard. NO implementation here - options only DISPATCH to
# the existing .workstation/*.ps1 scripts (or read state for display).
# AI agents do NOT use this menu (it waits for input) - call the .ps1 scripts directly.
$Here = $PSScriptRoot
$Root = Split-Path $Here -Parent

if ([Console]::IsInputRedirected) {
    Write-Host "This launcher is interactive - run it in a real terminal: pwsh -File .workstation/menu.ps1"
    Write-Host "For automation/AI: call .workstation/prepare.ps1, doctor.ps1, update.ps1, cleanup.ps1, decommission.ps1 directly."
    exit 0
}

function Run($script) { & (Join-Path $Here $script); Write-Host ""; Read-Host "Press Enter to return" | Out-Null }

function Get-GitState {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return "no git" }
    Push-Location $Root
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    git rev-parse "@{u}" *> $null 2>&1
    if ($LASTEXITCODE -ne 0) { $s = "$branch - NOT PUSHED (work at risk)" }
    else {
        $a = git rev-list --count "@{u}..HEAD" 2>$null
        if ([int]$a -gt 0) { $s = "$branch - $a commit(s) NOT PUSHED (at risk)" } else { $s = "$branch - in sync with GitHub" }
    }
    Pop-Location; return $s
}
function Missing-Tools { @("git", "node", "docker", "python", "code") | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) } }

# --- Recovery-first: if the environment is incomplete, offer recovery immediately ---
$missing = Missing-Tools
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "ORVION workstation setup is INCOMPLETE - missing: $($missing -join ', ')"
    if ((Read-Host "Run recovery now? [Y/n]") -notmatch '^[nN]') { & (Join-Path $Here "prepare.ps1"); Write-Host ""; Read-Host "Press Enter to continue" | Out-Null }
}

while ($true) {
    Write-Host ""
    Write-Host "========================================="
    Write-Host "   ORVION Workstation - Recovery & Maintenance"
    Write-Host "========================================="
    Write-Host "  GitHub : $(Get-GitState)"
    Write-Host "-----------------------------------------"
    Write-Host "   1  Prepare / Repair   (install missing tools + verify)"
    Write-Host "   2  Verify             (doctor - health, versions, GitHub sync)"
    Write-Host "   3  Update             (preview upgrades, confirm, verify)"
    Write-Host "   4  Cleanup            (remove transient artifacts - safe)"
    Write-Host "   5  Decommission       (remove ORVION from this machine - for retire/sell)"
    Write-Host "   0  Exit"
    Write-Host ""
    switch (Read-Host "Choose") {
        "1" { Run "prepare.ps1" }
        "2" { Run "doctor.ps1" }
        "3" { Run "update.ps1" }
        "4" { Run "cleanup.ps1" }
        "5" { Run "decommission.ps1" }
        # `return`, not `break`: inside a switch, `break` leaves only the switch, so Exit redrew the menu.
        { $_ -in "X", "x", "0" } { return }
        default { Write-Host "Invalid choice." }
    }
}
