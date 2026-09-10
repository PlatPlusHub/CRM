# ORVION Workstation Update / periodic maintenance
# Updates the workstation's own tools, continues past failures, prints a summary, then verifies.
# This IS the periodic-maintenance command (update + verify in one) - run it occasionally.
# Does NOT touch ORVION project state. VS Code extensions auto-update; not forced here.
$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$Results = [System.Collections.Generic.List[object]]::new()
function Step($Title, [scriptblock]$Cmd) {
    Write-Host ""
    Write-Host "[$Title]"
    try { & $Cmd; $Results.Add([pscustomobject]@{ Item = $Title; State = "ok" }) }
    catch { Write-Host "[WARN] $($_.Exception.Message)"; $Results.Add([pscustomobject]@{ Item = $Title; State = "FAILED" }) }
}

Step "winget upgrades (workstation tools)" {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        foreach ($id in @("Git.Git", "GitHub.cli", "OpenJS.NodeJS.LTS", "Docker.DockerDesktop", "Python.Python.3.12", "Microsoft.PowerShell", "Microsoft.VisualStudioCode")) {
            winget upgrade --id $id -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        }
    }
    else { throw "winget unavailable" }
}

Step "npm global (Claude Code)" {
    npm update -g @anthropic-ai/claude-code 2>&1 | Out-Null
}

Step "npm global (Codex CLI)" {
    npm update -g @openai/codex 2>&1 | Out-Null
}

Step "Supabase CLI (project-local via npx - nothing global to update)" {
    npx --yes supabase@latest --version 2>&1 | Out-Null
}

Write-Host ""
Write-Host "== Update summary =="
$Results | ForEach-Object { Write-Host ("  {0,-45} {1}" -f $_.Item, $_.State) }
Write-Host "(VS Code extensions auto-update inside VS Code - not forced here.)"

Write-Host ""
Write-Host "== Verify =="
& (Join-Path $PSScriptRoot "doctor.ps1")
