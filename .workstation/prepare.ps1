# ORVION Workstation Provisioner
# Windows PowerShell 5.1 compatible, ASCII-only, idempotent, and failure-aware.
$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
$Results = New-Object System.Collections.Generic.List[object]
function Note($Item, $State) { $Results.Add([pscustomobject]@{ Item = $Item; State = $State }) }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
function Ensure-Tool {
    param($Cmd, $WingetId, $Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) { Write-Host "[ OK ] $Label present"; Note $Label "present"; return }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Host "[FAIL] $Label - winget unavailable"; Note $Label "FAILED (install App Installer/winget)"; return }
    Write-Host "[INSTALL] $Label ($WingetId)"
    winget install --id $WingetId -e --source winget --accept-source-agreements --accept-package-agreements
    Refresh-Path
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) { Note $Label "installed" } else { Write-Host "[FAIL] $Label is still unavailable after installation"; Note $Label "FAILED" }
}
function Ensure-NpmGlobal {
    param($Cmd, $Package, $Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) { Write-Host "[ OK ] $Label present"; Note $Label "present"; return }
    Write-Host "[INSTALL] $Label ($Package)"
    npm install -g $Package
    Refresh-Path
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) { Note $Label "installed" } else { Write-Host "[FAIL] $Label"; Note $Label "FAILED" }
}
function Ensure-CodexMcp {
    param($Name, $Url, $CommandArgs, $BearerEnv)
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { Note "codex-mcp:$Name" "FAILED (no codex)"; return }
    $existing = (codex mcp get $Name 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0) {
        $normalized = $existing -replace '\s+', ' '
        $matches = $false
        if ($Url) { $matches = $normalized -like "*$Url*" }
        else {
            $expectedCommand = $CommandArgs[0]
            $expectedArgs = @($CommandArgs | Select-Object -Skip 1) -join " "
            $matches = ($normalized -like "*command: $expectedCommand*") -and ($normalized -like "*args: $expectedArgs*")
        }
        if ($matches) { Write-Host "[ OK ] Codex MCP $Name"; Note "codex-mcp:$Name" "present"; return }
        Write-Host "[FAIL] Codex MCP $Name exists but does not match the repository definition"
        Note "codex-mcp:$Name" "FAILED (configuration drift)"; return
    }
    Write-Host "[CONFIG] Codex MCP $Name"
    if ($Url) {
        if ($BearerEnv) { codex mcp add $Name --url $Url --bearer-token-env-var $BearerEnv } else { codex mcp add $Name --url $Url }
    } else { & codex mcp add $Name -- $CommandArgs }
    if ($LASTEXITCODE -eq 0) { Note "codex-mcp:$Name" "configured" } else { Write-Host "[FAIL] Codex MCP $Name"; Note "codex-mcp:$Name" "FAILED" }
}

Write-Host ""
Write-Host "== ORVION workstation preparation =="
Write-Host "Repository: $Root"
Write-Host ""
Write-Host "== Base tools =="
Ensure-Tool git "Git.Git" "Git"
Ensure-Tool gh "GitHub.cli" "GitHub CLI"
Ensure-Tool node "OpenJS.NodeJS.LTS" "Node.js LTS"
Ensure-Tool docker "Docker.DockerDesktop" "Docker Desktop"
Ensure-Tool python "Python.Python.3.12" "Python 3.12"
Ensure-Tool pwsh "Microsoft.PowerShell" "PowerShell 7"
Ensure-Tool code "Microsoft.VisualStudioCode" "VS Code"
Refresh-Path

Write-Host ""
Write-Host "== WSL 2 prerequisite =="
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    wsl --status *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "[ OK ] WSL 2 available"; Note "WSL 2" "present" } else { Write-Host "[FAIL] WSL is installed but not ready; run 'wsl --install --no-distribution' as Administrator, reboot, then rerun"; Note "WSL 2" "FAILED (admin/reboot required)" }
} else { Write-Host "[FAIL] WSL unavailable; run 'wsl --install --no-distribution' as Administrator, reboot, then rerun"; Note "WSL 2" "FAILED (admin/reboot required)" }

Write-Host ""
Write-Host "== Agent CLIs and locked project dependencies =="
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Ensure-NpmGlobal claude "@anthropic-ai/claude-code" "Claude Code CLI"
    Ensure-NpmGlobal codex "@openai/codex" "Codex CLI"
    npm ls --depth=0 *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "[ OK ] Project dependencies already match package.json"; Note "project dependencies" "present" }
    else {
        Write-Host "[INSTALL] Project dependencies from package-lock.json"
        npm ci
        if ($LASTEXITCODE -eq 0) { Write-Host "[ OK ] npm ci"; Note "project dependencies" "restored" } else { Write-Host "[FAIL] npm ci"; Note "project dependencies" "FAILED" }
    }
} else { Write-Host "[FAIL] npm unavailable after Node installation"; Note "npm steps" "FAILED" }

Write-Host ""
Write-Host "== VS Code extensions =="
$requiredExtensions = @("anthropic.claude-code","openai.chatgpt","supabase.vscode-supabase-extension","mtxr.sqltools","ms-vscode.powershell","ms-azuretools.vscode-docker")
if (Get-Command code -ErrorAction SilentlyContinue) {
    $installed = @(code --list-extensions 2>$null)
    foreach ($ext in $requiredExtensions) {
        if ($installed -contains $ext) { Write-Host "[ OK ] $ext"; Note "ext:$ext" "present"; continue }
        Write-Host "[INSTALL] $ext"; code --install-extension $ext
        if (@(code --list-extensions 2>$null) -contains $ext) { Note "ext:$ext" "installed" } else { Write-Host "[FAIL] $ext"; Note "ext:$ext" "FAILED" }
    }
} else { Write-Host "[FAIL] VS Code CLI unavailable"; Note "VS Code extensions" "FAILED" }

Write-Host ""
Write-Host "== Project MCP configuration =="
$mcp = Get-Content -Raw (Join-Path $Root ".mcp.json") | ConvertFrom-Json
Ensure-CodexMcp "context7" $null @("npx", "-y", "@upstash/context7-mcp") $null
Ensure-CodexMcp "postgres-local" $null @("npx", "-y", "@modelcontextprotocol/server-postgres", "postgresql://postgres:postgres@127.0.0.1:54322/postgres") $null
Ensure-CodexMcp "supabase-primary" $mcp.mcpServers.'supabase-primary'.url $null $null
Ensure-CodexMcp "n8n" $mcp.mcpServers.n8n.url $null $null
Ensure-CodexMcp "github" "https://api.githubcopilot.com/mcp/" $null "GITHUB_PAT_TOKEN"
Write-Host "[NOTE] Remote MCP OAuth and GITHUB_PAT_TOKEN remain external to git."

Write-Host ""
Write-Host "== Claude engineering-awareness wiring =="
& (Join-Path $PSScriptRoot "claude-awareness.ps1") -Apply
if ($LASTEXITCODE -eq 0) { Note "Claude awareness wiring" "ok" } else { Note "Claude awareness wiring" "FAILED" }

Write-Host ""
Write-Host "== Docker Desktop readiness =="
docker info *> $null
if ($LASTEXITCODE -eq 0) { Write-Host "[ OK ] Docker Engine running"; Note "Docker Engine" "ready" } else {
    $dockerDesktop = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktop) { Start-Process -FilePath $dockerDesktop -WindowStyle Hidden; Write-Host "[WAIT] Docker Desktop launched; waiting up to 120 seconds" }
    $ready = $false
    for ($i = 0; $i -lt 24; $i++) { Start-Sleep -Seconds 5; docker info *> $null; if ($LASTEXITCODE -eq 0) { $ready = $true; break } }
    if ($ready) { Write-Host "[ OK ] Docker Engine running"; Note "Docker Engine" "started" } else { Write-Host "[FAIL] Docker Engine not ready; complete Docker Desktop first launch, then rerun"; Note "Docker Engine" "FAILED (first launch/user action)" }
}

Write-Host ""
Write-Host "== Final verification =="
& (Join-Path $PSScriptRoot "doctor.ps1")
$doctorExit = $LASTEXITCODE
Write-Host ""
Write-Host "== Preparation summary =="
$Results | ForEach-Object { Write-Host ("  {0,-32} {1}" -f $_.Item, $_.State) }
$failed = @($Results | Where-Object { $_.State -like "FAILED*" })
if ($failed.Count -gt 0 -or $doctorExit -ne 0) {
    Write-Host ""; Write-Host "WORKSTATION PREPARATION: INCOMPLETE"
    Write-Host "Resolve required failures and rerun workstation.cmd. OAuth/account steps remain external by design."
    exit 1
}
Write-Host ""; Write-Host "WORKSTATION PREPARATION: COMPLETE"
Write-Host "If needed, authenticate with gh auth login, claude, codex login, and the remote MCP OAuth flows."
exit 0
