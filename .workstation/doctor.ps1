# ORVION Workstation Doctor - read-only, Windows PowerShell 5.1 compatible, ASCII-only.
$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
$Failures = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
function Pass($Text) { Write-Host "[ OK ] $Text" }
function Fail($Text) { Write-Host "[FAIL] $Text"; $Failures.Add($Text) }
function Warn($Text) { Write-Host "[WARN] $Text"; $Warnings.Add($Text) }
function Test-RequiredCommand($Name) { $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1; if ($cmd) { Pass "$Name -> $($cmd.Path)" } else { Fail "$Name is not on PATH" } }
function Test-Version($Label, [scriptblock]$Command) { try { $allOutput = & $Command 2>&1; $succeeded = $?; $out = $allOutput | Select-Object -First 1; if ($succeeded -and $out) { Pass "$Label $out" } else { Fail "$Label version command failed" } } catch { Fail "$Label version command failed: $($_.Exception.Message)" } }

Write-Host ""; Write-Host "========================================="; Write-Host "ORVION WORKSTATION DOCTOR"; Write-Host "========================================="
Write-Host ""; Write-Host "[Operating environment]"
$os = Get-CimInstance Win32_OperatingSystem
Pass "$($os.Caption) build $($os.BuildNumber), $($os.OSArchitecture)"
Pass "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
foreach ($name in @("git","gh","node","npm","npx","docker","python","pwsh","code","claude","codex")) { Test-RequiredCommand $name }
if (Get-Command wsl -ErrorAction SilentlyContinue) { wsl --status *> $null; if ($LASTEXITCODE -eq 0) { Pass "WSL 2 available" } else { Fail "WSL installed but not ready" } } else { Fail "WSL is unavailable" }

Write-Host ""; Write-Host "[Versions and capability]"
Test-Version "git" { git --version }; Test-Version "gh" { gh --version }; Test-Version "node" { node --version }; Test-Version "npm" { npm --version }
Test-Version "python" { python --version }; Test-Version "docker" { docker --version }; Test-Version "docker compose" { docker compose version }
Test-Version "pwsh" { pwsh --version }; Test-Version "code" { code --version }; Test-Version "claude" { claude --version }; Test-Version "codex" { codex --version }
if (Test-Path "node_modules\.bin\supabase.cmd") { Test-Version "supabase" { & "node_modules\.bin\supabase.cmd" --version } } else { Fail "project-local Supabase CLI is missing (run npm ci)" }

Write-Host ""; Write-Host "[Repository dependencies and configuration]"
foreach ($f in @("README.md","AGENTS.md","GOVERNANCE.md","package.json","package-lock.json","supabase\config.toml",".mcp.json",".vscode\extensions.json",".claude\awareness.json")) { if (Test-Path $f) { Pass $f } else { Fail "$f missing" } }
$hooksPath = git config --get core.hooksPath 2>$null
if ($hooksPath -eq '.githooks' -and (Test-Path '.githooks\pre-commit')) { Pass 'Git hooks path -> .githooks' } else { Fail "Git hooks path is '$hooksPath'; run workstation.cmd" }
npm ls --depth=0 *> $null
if ($LASTEXITCODE -eq 0) { Pass "npm dependency tree" } else { Fail "npm dependency tree incomplete or invalid" }

Write-Host ""; Write-Host "[Docker]"
docker info *> $null
if ($LASTEXITCODE -eq 0) { Pass "Docker Engine ready" } elseif (Get-Command docker -ErrorAction SilentlyContinue) { Fail "Docker installed but engine not ready" }

Write-Host ""; Write-Host "[VS Code extensions]"
$requiredExtensions = @("anthropic.claude-code","openai.chatgpt","supabase.vscode-supabase-extension","mtxr.sqltools","ms-vscode.powershell","ms-azuretools.vscode-docker")
if (Get-Command code -ErrorAction SilentlyContinue) { $installed = @(code --list-extensions 2>$null); foreach ($ext in $requiredExtensions) { if ($installed -contains $ext) { Pass $ext } else { Fail "VS Code extension $ext missing" } } }

Write-Host ""; Write-Host "[MCP definitions]"
try { $mcp = Get-Content -Raw ".mcp.json" | ConvertFrom-Json; foreach ($name in @("context7","postgres-local","supabase-primary","n8n")) { if ($mcp.mcpServers.PSObject.Properties.Name -contains $name) { Pass ".mcp.json contains $name" } else { Fail ".mcp.json missing $name" } } } catch { Fail ".mcp.json is invalid JSON" }
if (Get-Command claude -ErrorAction SilentlyContinue) { $claudeMcp = (claude mcp list 2>&1 | Out-String); foreach ($name in @("context7","postgres-local","supabase-primary","n8n")) { if ($claudeMcp -match "(?m)^$([regex]::Escape($name)):") { Pass "Claude MCP $name enumerated" } else { Fail "Claude MCP $name not enumerated" } } }
if (Get-Command codex -ErrorAction SilentlyContinue) {
    $codexMcp = (codex mcp list 2>&1 | Out-String)
    foreach ($name in @("context7","postgres-local","supabase-primary","n8n","github")) { if ($codexMcp -match "(?m)^$([regex]::Escape($name))\s") { Pass "Codex MCP $name enumerated" } else { Fail "Codex MCP $name not enumerated" } }
    if ($codexMcp -match "supabase-primary.*Not logged in") { Warn "Codex supabase-primary configured; OAuth authentication required" }
}
if (-not $env:GITHUB_PAT_TOKEN) { Warn "Codex GitHub MCP configured; GITHUB_PAT_TOKEN is not present in this process" } else { Pass "Codex GitHub MCP credential variable is present (value not inspected)" }

Write-Host ""; Write-Host "[Authentication boundaries]"
gh auth status *> $null; if ($LASTEXITCODE -eq 0) { Pass "GitHub CLI authenticated" } else { Warn "GitHub CLI installed; run gh auth login" }
claude auth status *> $null; if ($LASTEXITCODE -eq 0) { Pass "Claude Code authenticated" } else { Warn "Claude Code installed; launch claude to authenticate" }
codex login status *> $null; if ($LASTEXITCODE -eq 0) { Pass "Codex authenticated" } else { Warn "Codex installed; run codex login" }

Write-Host ""; Write-Host "[Claude engineering awareness]"
& (Join-Path $PSScriptRoot "claude-awareness.ps1") -Verify
if ($LASTEXITCODE -ne 0) { Fail "Claude awareness wiring incomplete" }

Write-Host ""; Write-Host "[GitHub repository]"
$originUrl = git remote get-url origin 2>$null
if ($originUrl -match '^https://PlatPlusHub@github\.com/PlatPlusHub/CRM(\.git)?$') { Pass "origin is username-qualified for PlatPlusHub" } else { Fail "origin is not the canonical username-qualified URL" }
$author = git config user.name 2>$null
if ($author -eq "PlatPlusHub") { Pass "commit author is PlatPlusHub" } else { Warn "commit author is '$author'; expected PlatPlusHub on the owner workstation" }
git ls-remote origin HEAD *> $null
if ($LASTEXITCODE -eq 0) { Pass "GitHub remote reachable" } else { Fail "GitHub remote is not reachable" }

Write-Host ""; Write-Host "Doctor summary: $($Failures.Count) required failure(s), $($Warnings.Count) warning(s)."
if ($Warnings.Count -gt 0) { Write-Host "Warnings are authentication, readiness, or owner-workstation boundaries; they are not missing software." }
if ($Failures.Count -gt 0) { Write-Host "WORKSTATION VERIFICATION: FAILED"; exit 1 }
Write-Host "WORKSTATION VERIFICATION: PASSED"; exit 0
