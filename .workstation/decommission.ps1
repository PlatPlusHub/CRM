# ORVION Secure Workstation Decommission
# Removes ONLY ORVION assets from THIS machine (for retire / sell / replace). Safe because GitHub is
# the permanent source of truth - the repo is fully recoverable anytime via the bootstrap. It NEVER
# removes general tools (Git/Node/Docker/VS Code) or any unrelated user data. Requires explicit confirmation.
$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "== ORVION Secure Decommission =="
Write-Host "Removes the local ORVION repository + ORVION-specific config/env from THIS machine."
Write-Host "GitHub keeps the permanent copy - recover anytime with the bootstrap."
Write-Host "Does NOT remove Git, Node, Docker, VS Code, or any unrelated data."
Write-Host ""
if ((Read-Host "Type DECOMMISSION to proceed (anything else cancels)") -cne "DECOMMISSION") {
    Write-Host "Cancelled - nothing removed."; return
}

# 1. ORVION-specific environment variables
foreach ($n in @("GEMINI_API_KEY", "OLLAMA_API_BASE", "SUPABASE_ACCESS_TOKEN")) {
    if ([Environment]::GetEnvironmentVariable($n, "User")) {
        [Environment]::SetEnvironmentVariable($n, $null, "User"); Write-Host "[DONE] env $n"
    }
}

# 2. Stop the local Supabase stack (frees ORVION containers) - best-effort.
if (Get-Command npx -ErrorAction SilentlyContinue) { Push-Location $Root; npx --yes supabase stop 2>$null | Out-Null; Pop-Location }

# 3. Remove the local repository LAST - detached, because we are running from inside it.
Write-Host "[DONE] scheduling removal of $Root"
Set-Location $HOME
Start-Process powershell -ArgumentList "-NoProfile", "-Command", "Start-Sleep 2; Remove-Item -LiteralPath '$Root' -Recurse -Force -ErrorAction SilentlyContinue" -WindowStyle Hidden

Write-Host ""
Write-Host "ORVION will be removed from this machine momentarily. Recover anytime with one command:"
Write-Host "  irm https://raw.githubusercontent.com/PlatPlusHub/CRM/main/bootstrap.ps1 | iex"
exit 0
