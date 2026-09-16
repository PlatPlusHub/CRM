# ORVION Workstation Update / periodic maintenance
# Updates the workstation's own tools, continues past failures, prints a summary, then verifies.
# This IS the periodic-maintenance command (update + verify in one) - run it occasionally.
# Does NOT touch ORVION project state. VS Code extensions auto-update; not forced here.
$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$Results = [System.Collections.Generic.List[object]]::new()
# A native executable's non-zero exit does NOT raise a PowerShell exception, so the
# try/catch alone reported "ok" for every winget and npm failure this script could have.
# The process exit result is therefore inspected explicitly. These two winget codes are
# success-equivalent per microsoft/winget-cli doc/windows/package-manager/winget/returnCodes.md:
#   0x8A15002B / -1978335189  APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE  (no applicable update)
#   0x8A150061 / -1978335135  APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED
# Treating them as failures would trade a false green for a false red; anything else is real.
$UpToDateExitCodes = @(-1978335189, -1978335135)
function Step($Title, [scriptblock]$Cmd) {
    Write-Host ""
    Write-Host "[$Title]"
    # Reset first: a step that runs no native command must not inherit a previous code.
    $global:LASTEXITCODE = 0
    try {
        & $Cmd
        $code = $LASTEXITCODE
        if ($code -eq 0) { $Results.Add([pscustomobject]@{ Item = $Title; State = "ok" }) }
        elseif ($UpToDateExitCodes -contains $code) { $Results.Add([pscustomobject]@{ Item = $Title; State = "up to date" }) }
        else { Write-Host "[FAIL] native command exited $code"; $Results.Add([pscustomobject]@{ Item = $Title; State = "FAILED (exit $code)" }) }
    }
    catch { Write-Host "[WARN] $($_.Exception.Message)"; $Results.Add([pscustomobject]@{ Item = $Title; State = "FAILED" }) }
}

Step "winget upgrades (workstation tools)" {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        # Preserve the FIRST real failure: without this only the last package's exit code
        # would survive to Step, so a failure followed by a success still read as success.
        $worst = 0
        foreach ($id in @("Git.Git", "GitHub.cli", "OpenJS.NodeJS.LTS", "Docker.DockerDesktop", "Python.Python.3.12", "Microsoft.PowerShell", "Microsoft.VisualStudioCode")) {
            winget upgrade --id $id -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            if ($worst -eq 0 -and $LASTEXITCODE -ne 0 -and $UpToDateExitCodes -notcontains $LASTEXITCODE) {
                Write-Host "[FAIL] winget upgrade $id exited $LASTEXITCODE"
                $worst = $LASTEXITCODE
            }
        }
        $global:LASTEXITCODE = $worst
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
