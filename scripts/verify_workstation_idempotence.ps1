# ORVION workstation idempotence verifier.
#
# WHY THIS EXISTS. The WORKSTATION profile once declared bootstrap idempotence as
# `LOCAL_NOT_EXECUTED`, which meant `-Finish` could never emit `LOCAL_CERTIFY: READY`
# for a workstation contract, no receipt was ever written, and `Complete` was refused
# for every actor. That is the defect class SPEC-164 named when it repaired DATABASE:
# a profile that can only ever WITHHOLD certification leaves a weaker agent choosing
# between permanent incompleteness and completing without certification. DATABASE was
# fixed by EXECUTING its protocol; this script is the equivalent for WORKSTATION, and
# it is a separate file for the same reason `check_database_parity.ps1` is - the
# evidence is a COMPARISON, and a comparison cannot be expressed as a bare command.
#
# WHAT IDEMPOTENCE MEANS HERE, derived from `.workstation/prepare.ps1`'s actual
# behaviour rather than from an abstract definition. On a workstation that is already
# converged, one further `prepare.ps1` run must:
#   * exit 0;
#   * perform NO installation      - no `[INSTALL]` line;
#   * perform NO reconfiguration   - no `[CONFIG]` line;
#   * report NO failure            - no `[FAIL]` line and no `FAILED` summary note;
#   * leave every TRACKED repository file byte-identical.
#
# Deliberately NOT required: silence. `prepare.ps1` legitimately re-runs detection
# commands, refreshes PATH in-process, and re-verifies through the doctor every time.
# Executing a read-only probe is not mutation, and demanding zero operating-system
# noise would measure the wrong thing. Only meaningful mutation is measured.
#
# FAIL-CLOSED. Every failure path exits non-zero. A workstation that is NOT converged
# makes the single run install or configure something, which fails this check by
# design and says so: converge first with `workstation.cmd`, then certify. This script
# never converges the machine on the caller's behalf, never uninstalls anything, and
# never manufactures damage to test recovery.
[CmdletBinding()]
param([string]$Root = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = 'Continue'
Set-Location $Root

function Get-TrackedFingerprint {
    $sha = [Security.Cryptography.SHA256]::Create()
    $acc = [Text.StringBuilder]::new()
    foreach ($p in @(git -C $Root ls-files)) {
        $full = Join-Path $Root $p
        $h = 'absent'
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $h = ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($full))) -replace '-', '').ToLowerInvariant()
        }
        [void]$acc.Append("$p $h`n")
    }
    ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($acc.ToString()))) -replace '-', '').ToLowerInvariant()
}

$prepare = Join-Path $Root '.workstation/prepare.ps1'
if (-not (Test-Path -LiteralPath $prepare)) {
    Write-Output "WORKSTATION IDEMPOTENCE: FAILED - .workstation/prepare.ps1 is missing"
    exit 1
}

Write-Output "== ORVION workstation idempotence =="
Write-Output "Measuring one prepare run against an already-converged workstation."

$before = Get-TrackedFingerprint
$output = & pwsh -NoProfile -File $prepare 2>&1 | Out-String
$code = $LASTEXITCODE
$after = Get-TrackedFingerprint

$lines = @($output -split "`r?`n")
$installs = @($lines | Where-Object { $_ -match '^\[INSTALL\]' })
$configs = @($lines | Where-Object { $_ -match '^\[CONFIG\]' })
$failures = @($lines | Where-Object { $_ -match '^\[FAIL\]' -or $_ -match 'FAILED' })

$issues = 0
if ($code -ne 0) { Write-Output "  MUTATED/FAILED: prepare.ps1 exited $code"; $issues++ }
else { Write-Output "  exit code 0" }

if ($installs.Count -gt 0) {
    Write-Output "  NOT IDEMPOTENT: $($installs.Count) installation action(s) on an already-converged workstation"
    foreach ($l in $installs) { Write-Output "    $l" }
    $issues++
} else { Write-Output "  no installation action" }

if ($configs.Count -gt 0) {
    Write-Output "  NOT IDEMPOTENT: $($configs.Count) reconfiguration action(s) on an already-converged workstation"
    foreach ($l in $configs) { Write-Output "    $l" }
    $issues++
} else { Write-Output "  no reconfiguration action" }

if ($failures.Count -gt 0) {
    Write-Output "  FAILURE REPORTED by prepare.ps1:"
    foreach ($l in $failures) { Write-Output "    $l" }
    $issues++
} else { Write-Output "  no failure reported" }

if ($before -ne $after) {
    Write-Output "  MUTATED: a tracked repository file changed during the run"
    foreach ($l in @(git -C $Root status --porcelain)) { Write-Output "    $l" }
    $issues++
} else { Write-Output "  every tracked repository file byte-identical" }

if ($issues -gt 0) {
    Write-Output ""
    Write-Output "WORKSTATION IDEMPOTENCE: FAILED ($issues finding(s))"
    Write-Output "If the workstation is simply not converged yet, run workstation.cmd first, then certify."
    exit 1
}
Write-Output ""
Write-Output "WORKSTATION IDEMPOTENCE: PASSED"
exit 0
