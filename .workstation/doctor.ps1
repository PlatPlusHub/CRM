# ORVION Workstation Doctor - read-only verification + diagnostics.
# Checks tools, key repo files, Docker, tool versions, and GitHub sync (local is disposable -
# unpushed work is at risk). Changes nothing. Safe to run anytime.
$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

function Test-Cmd { param($Name)
    if (Get-Command $Name -ErrorAction SilentlyContinue) { Write-Host "[ OK ] $Name" } else { Write-Host "[FAIL] $Name" }
}

Write-Host ""
Write-Host "========================================="
Write-Host "ORVION WORKSTATION DOCTOR"
Write-Host "========================================="

Write-Host ""
Write-Host "[Applications]"
foreach ($c in @("git", "node", "npm", "docker", "python", "claude", "code")) { Test-Cmd $c }

Write-Host ""
Write-Host "[Repository]"
foreach ($f in @("README.md", "AGENTS.md", "PROJECT_CONTEXT.md", "GOVERNANCE.md", ".gitignore", ".mcp.json")) {
    if (Test-Path $f) { Write-Host "[ OK ] $f" } else { Write-Host "[FAIL] $f" }
}

Write-Host ""
Write-Host "[Docker]"
docker version *> $null
if ($LASTEXITCODE -eq 0) { Write-Host "[ OK ] Docker Engine" } else { Write-Host "[WARN] Docker Engine not running (start Docker Desktop)" }

Write-Host ""
Write-Host "[Versions]"
foreach ($v in @(
        @("git", "git --version"), @("node", "node -v"), @("npm", "npm -v"),
        @("docker", "docker --version"), @("python", "python --version"),
        @("claude", "claude --version"), @("code", "code --version"))) {
    if (Get-Command $v[0] -ErrorAction SilentlyContinue) {
        $out = (& ([scriptblock]::Create($v[1])) 2>$null | Select-Object -First 1)
        Write-Host ("  {0,-8} {1}" -f $v[0], $out)
    }
}

Write-Host ""
Write-Host "[GitHub identity]  (ORVION pushes as PlatPlusHub; never Shehabhub)"
if (Get-Command git -ErrorAction SilentlyContinue) {
    # Git Credential Manager keys credentials by URL. An unqualified https://github.com/... origin
    # resolves to `git:https://github.com` -- on the owner's machine the pre-migration Shehabhub
    # account -- which pushes as the wrong identity (historically 403, later a non-interactive hang).
    # This regressed silently once already: fixed in .git/config on 2026-08-26, destroyed by the
    # 2026-08-30 re-clone because git does not track .git/config. bootstrap.ps1 now clones with the
    # qualifier; this check catches any clone or set-url that reintroduces the unqualified form.
    $originUrl = git remote get-url origin 2>$null
    if (-not $originUrl) { Write-Host "[WARN] no 'origin' remote configured" }
    elseif ($originUrl -match '^https://PlatPlusHub@github\.com/PlatPlusHub/CRM(\.git)?$') {
        Write-Host "[ OK ] origin is username-qualified as PlatPlusHub"
    }
    elseif ($originUrl -match 'github\.com/PlatPlusHub/CRM') {
        Write-Host "[FAIL] origin is '$originUrl' - NOT username-qualified"
        Write-Host "       Git Credential Manager will fall back to the stored Shehabhub credential."
        Write-Host "       Remedy: git remote set-url origin https://PlatPlusHub@github.com/PlatPlusHub/CRM.git"
    }
    else { Write-Host "[WARN] origin is '$originUrl' - not the expected PlatPlusHub/CRM remote" }

    $author = git config user.name 2>$null
    if ($author -eq "PlatPlusHub") { Write-Host "[ OK ] commit author is PlatPlusHub" }
    else { Write-Host "[FAIL] commit author is '$author' - expected PlatPlusHub (git config --global user.name PlatPlusHub)" }
}

Write-Host ""
Write-Host "[GitHub sync]  (local is disposable - GitHub is the source of truth)"
if (Get-Command git -ErrorAction SilentlyContinue) {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    git rev-parse "@{u}" *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] branch '$branch' has no upstream - push it so GitHub has your work"
    }
    else {
        $ahead = (git rev-list --count "@{u}..HEAD" 2>$null)
        if ([int]$ahead -gt 0) { Write-Host "[WARN] $ahead local commit(s) not pushed - at risk until 'git push'" }
        else { Write-Host "[ OK ] in sync with origin/$branch" }
    }
}

Write-Host ""
Write-Host "Doctor completed."
