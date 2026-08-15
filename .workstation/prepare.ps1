# ORVION Workstation Provisioner - "Prepare this workstation"
# Idempotent + fault-tolerant: installs only what is missing, CONTINUES past any failure,
# and prints a final Installed/Present/Failed summary. Re-running is also the retry path -
# only still-missing items are attempted. Real logic lives here; workstation.cmd (menu) is the launcher.
$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$Results = [System.Collections.Generic.List[object]]::new()
function Note($Item, $State) { $Results.Add([pscustomobject]@{ Item = $Item; State = $State }) }

function Ensure-Tool {
    param($Cmd, $WingetId, $Label)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) { Write-Host "[ OK ] $Label present"; Note $Label "present"; return }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Host "[FAIL] $Label - winget unavailable"; Note $Label "FAILED (no winget)"; return }
    Write-Host "[INSTALL] $Label ($WingetId)"
    winget install --id $WingetId -e --accept-source-agreements --accept-package-agreements
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) { Note $Label "installed" } else { Write-Host "[FAIL] $Label"; Note $Label "FAILED" }
}

Write-Host ""
Write-Host "== Base tools (manifest.md section 1) =="
Ensure-Tool git    "Git.Git"                     "Git"
Ensure-Tool node   "OpenJS.NodeJS.LTS"           "Node.js LTS"
Ensure-Tool docker "Docker.DockerDesktop"        "Docker Desktop"
Ensure-Tool python "Python.Python.3.12"          "Python 3.12"
Ensure-Tool code   "Microsoft.VisualStudioCode"  "VS Code"
# Supabase CLI is used via `npx supabase` (no global install) - see manifest.md.

# Refresh PATH in this session so tools just installed by winget are usable immediately
# (no shell restart needed).
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

Write-Host ""
Write-Host "== VS Code extensions (manifest.md section 2) =="
if (Get-Command code -ErrorAction SilentlyContinue) {
    $installed = @(code --list-extensions 2>$null)
    # MINIMUM ORVION-essential set only (a clean, intentional recovery environment - NOT a copy of
    # the owner's editor). Personal/owner AI tools (openai.chatgpt/Codex, github.copilot) are NOT
    # auto-installed - they live in .vscode/extensions.json recommendations for one-click add.
    # (github.copilot also can't CLI-install: its github.copilot-chat dep is now built-in.)
    foreach ($ext in @(
            "anthropic.claude-code",
            "supabase.vscode-supabase-extension", "mtxr.sqltools",
            "ms-vscode.powershell", "ms-azuretools.vscode-docker")) {
        if ($installed -contains $ext) { Write-Host "[ OK ] $ext present"; Note "ext:$ext" "present"; continue }
        Write-Host "[INSTALL] $ext"
        code --install-extension $ext 2>&1 | Out-Null
        if (@(code --list-extensions 2>$null) -contains $ext) { Write-Host "[ OK ] $ext installed"; Note "ext:$ext" "installed" }
        else { Write-Host "[FAIL] $ext"; Note "ext:$ext" "FAILED" }
    }
}
else { Write-Host "[SKIP] 'code' CLI not on PATH - open VS Code once, enable the 'code' command, re-run"; Note "vscode-extensions" "skipped (no code CLI)" }
Write-Host "[NOTE] Owner AI tools (GitHub Copilot, ChatGPT/Codex) are recommended, not auto-installed - add them from the VS Code Extensions UI (Copilot's CLI install conflicts with the built-in Copilot Chat)."

Write-Host ""
Write-Host "== Claude tooling + project dependencies (restore what git-clone can't) =="
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "[INSTALL] Claude Code CLI (npm global)"
    npm install -g "@anthropic-ai/claude-code" 2>&1 | Out-Null
    if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Host "[ OK ] claude CLI"; Note "claude CLI" "ok" } else { Write-Host "[FAIL] claude CLI"; Note "claude CLI" "FAILED" }

    Write-Host "[INSTALL] Project dependencies (npm install - restores node_modules from package-lock)"
    Push-Location $Root; npm install 2>&1 | Out-Null; $npmrc = $LASTEXITCODE; Pop-Location
    if ($npmrc -eq 0) { Write-Host "[ OK ] npm install"; Note "npm install" "ok" } else { Write-Host "[FAIL] npm install"; Note "npm install" "FAILED" }
}
else { Write-Host "[SKIP] npm unavailable - restart shell so Node is on PATH, then re-run"; Note "npm-steps" "skipped" }

Write-Host ""
Write-Host "== MCP servers (manifest.md section 4) =="
Write-Host "Configured in .mcp.json (context7, postgres-local, supabase-primary) - auto-loaded by Claude Code on start."
Write-Host "supabase-primary uses the official Supabase Remote MCP over OAuth (no token/env var needed) - run /mcp in Claude Code and authenticate on first use. See .workstation/manifest.md section 4."

Write-Host ""
Write-Host "== Verify =="
& (Join-Path $PSScriptRoot "doctor.ps1")

Write-Host ""
Write-Host "== Summary =="
$Results | ForEach-Object { Write-Host ("  {0,-24} {1}" -f $_.Item, $_.State) }
$failed = @($Results | Where-Object { $_.State -like "FAILED*" })
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "$($failed.Count) item(s) FAILED. Re-run Prepare (workstation.cmd -> 1) to retry only those (idempotent). If a base tool keeps failing, install it manually and re-run."
}
else {
    Write-Host ""
    Write-Host "All items present or installed. PATH was refreshed in-session - no shell restart needed."
}

Write-Host ""
Write-Host "== Manual re-provisions (by design - never stored in git) =="
Write-Host "  - Sign in to Claude Code:  claude   (then authenticate)"
Write-Host "  - Secrets (only if used):  set env vars for any cloud MCP token (see WORKSTATION.md)."
Write-Host "  - Local Supabase stack:    npx supabase start   (recreated from in-repo migrations - no data to restore)."
Write-Host "The repository, tools, extensions, dependencies, and config are now restored - ready to develop."
