<#
.SYNOPSIS
  Reproduce (or verify) Claude Code's engineering-awareness wiring on this machine.

.DESCRIPTION
  `.claude/settings.json` is gitignored on purpose — it is machine-local and personal, and it
  carries each engineer's own permission allowlist. But three of its keys are NOT personal: the
  SessionStart awareness hook, the protected-resource `ask` rules, and the `deny` rules that stop a
  schema-changing call reaching the wrong Supabase project. A capability must not silently exist
  without its activation mechanism, so those three live in the TRACKED `.claude/awareness.json` and
  this script installs them.

  This is the same lesson `bootstrap.ps1` already carries: the 2026-08-30 re-clone destroyed a fix
  that lived only in an untracked file, so the fix had to move into a tracked one. A hook script in
  git whose wiring is not in git repeats that mistake exactly.

  -Apply   merges the tracked keys into .claude/settings.json, creating it if absent. Idempotent,
           additive, and non-destructive: existing `allow` entries and any other keys are preserved,
           arrays are unioned, and an already-wired machine is left byte-identical.
  -Verify  reports what is missing and changes nothing. Exit 0 = wired, 1 = incomplete.

  Called by prepare.ps1 (-Apply) and doctor.ps1 (-Verify). Safe to run directly.
#>

[CmdletBinding(DefaultParameterSetName = 'Verify')]
param(
    [Parameter(ParameterSetName = 'Apply')]  [switch] $Apply,
    [Parameter(ParameterSetName = 'Verify')] [switch] $Verify
)

$ErrorActionPreference = 'Continue'
$Root     = Split-Path $PSScriptRoot -Parent
$expected = Join-Path $Root '.claude/awareness.json'
$settings = Join-Path $Root '.claude/settings.json'
$hookFile = Join-Path $Root '.claude/hooks/session-state.ps1'

if (-not (Test-Path $expected)) {
    Write-Host "[FAIL] .claude/awareness.json missing — the repository cannot state what the wiring should be."
    exit 1
}
$want = Get-Content $expected -Raw | ConvertFrom-Json

# The hook script is tracked, so its absence means a broken checkout, not an unwired machine.
if (-not (Test-Path $hookFile)) {
    Write-Host "[FAIL] .claude/hooks/session-state.ps1 missing (tracked file) — checkout is incomplete."
    exit 1
}

$have = if (Test-Path $settings) {
    try { Get-Content $settings -Raw | ConvertFrom-Json } catch {
        Write-Host "[FAIL] .claude/settings.json is not valid JSON — fix or delete it, then re-run."
        exit 1
    }
} else { $null }

# --- what is missing -------------------------------------------------------------------------
$missing = @()
$haveHook = $false
if ($have -and $have.hooks -and $have.hooks.SessionStart) {
    $haveHook = ($have.hooks.SessionStart | ConvertTo-Json -Depth 8) -match 'session-state\.ps1'
}
if (-not $haveHook) { $missing += 'SessionStart awareness hook' }

foreach ($key in @('ask', 'deny')) {
    $wantList = @($want.permissions.$key)
    $haveList = @()
    if ($have -and $have.permissions -and $have.permissions.$key) { $haveList = @($have.permissions.$key) }
    $gap = @($wantList | Where-Object { $haveList -notcontains $_ })
    if ($gap.Count -gt 0) { $missing += "permissions.$key — $($gap.Count) of $($wantList.Count) rule(s) absent" }
}

# --- verify ------------------------------------------------------------------------------------
if (-not $Apply) {
    if ($missing.Count -eq 0) {
        Write-Host "[ OK ] Claude engineering-awareness wiring present (SessionStart hook, ask + deny rules)"
        exit 0
    }
    Write-Host "[FAIL] Claude engineering-awareness wiring INCOMPLETE on this machine:"
    $missing | ForEach-Object { Write-Host "       - $_" }
    Write-Host "       Remedy: pwsh -NoProfile -File .workstation/claude-awareness.ps1 -Apply"
    Write-Host "       Until then this session gets NO repository-state banner and NO protected-file prompts."
    exit 1
}

# --- apply -------------------------------------------------------------------------------------
if ($missing.Count -eq 0) { Write-Host "[ OK ] Claude awareness wiring already present — nothing to change"; exit 0 }

# Work on an ordered hashtable so keys we never touch survive verbatim.
$out = [ordered]@{}
if ($have) { foreach ($p in $have.PSObject.Properties) { $out[$p.Name] = $p.Value } }

if (-not $haveHook) {
    if (-not $out.Contains('hooks')) { $out['hooks'] = [pscustomobject]@{} }
    $hooks = [ordered]@{}
    foreach ($p in $out['hooks'].PSObject.Properties) { $hooks[$p.Name] = $p.Value }
    # Append rather than replace: another SessionStart hook on this machine is not ours to remove.
    # The outer @() is load-bearing — a `| Where-Object` pipeline returns a SCALAR for one match, and
    # ConvertTo-Json then writes "SessionStart": {...} instead of [...], which Claude Code ignores.
    # Caught by running -Apply on a simulated fresh clone; inspection would not have shown it.
    $hooks['SessionStart'] = @(@($hooks['SessionStart']) + @($want.hooks.SessionStart) | Where-Object { $_ })
    $out['hooks'] = [pscustomobject]$hooks
}

$perms = [ordered]@{}
if ($out.Contains('permissions') -and $out['permissions']) {
    foreach ($p in $out['permissions'].PSObject.Properties) { $perms[$p.Name] = $p.Value }
}
foreach ($key in @('ask', 'deny')) {
    $haveList = @(); if ($perms.Contains($key)) { $haveList = @($perms[$key]) }
    $perms[$key] = @($haveList + @($want.permissions.$key | Where-Object { $haveList -notcontains $_ }))
}
$out['permissions'] = [pscustomobject]$perms

New-Item -ItemType Directory -Force -Path (Split-Path $settings -Parent) | Out-Null
$json = [pscustomobject]$out | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($settings, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "[ OK ] Claude awareness wiring applied to .claude/settings.json:"
$missing | ForEach-Object { Write-Host "       + $_" }
Write-Host "       Restart Claude Code (or /hooks) for the SessionStart hook to take effect."
exit 0
