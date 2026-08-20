# ORVION Remote Bootstrap - the ONLY thing that runs before the repository exists.
# Almost no logic: ensure Git, clone the ORVION repository (PlatPlusHub/CRM - this repository, the
# CRM environment) from GitHub, then hand off to the in-repo provisioner.
# ALL real setup logic lives in the repository (the permanent source of truth). This file is
# committed in the repo; the raw URL only delivers it for the single pre-clone step.
#
# On a brand-new machine, open PowerShell and run ONE command:
#   irm https://raw.githubusercontent.com/PlatPlusHub/CRM/main/bootstrap.ps1 | iex
#
# (Docker Desktop is still installed by prepare.ps1; start it once when prompted.)
$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/PlatPlusHub/CRM.git"
$Target  = Join-Path $HOME "CRM"

Write-Host "== ORVION bootstrap ==  target: $Target"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not found - installing via winget..."
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    # Refresh PATH so git is usable in this same session.
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

if (Test-Path (Join-Path $Target ".git")) {
    Write-Host "Repository already present - pulling latest."
    git -C $Target pull --ff-only
}
else {
    git clone $RepoUrl $Target
}

Set-Location $Target
Write-Host "Handing off to the in-repo provisioner (.workstation\prepare.ps1)..."
& (Join-Path $Target ".workstation\prepare.ps1")
