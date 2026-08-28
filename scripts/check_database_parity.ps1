# Database parity gate -- deliberately SEPARATE from check_repository_consistency.ps1.
#
# Why this exists (incident 2026-08-26): the repository held 118 migrations, the manifest claimed
# local was at 118, and `check_repository_consistency.ps1` printed REPOSITORY CONSISTENCY: CLEAN --
# while the local database was actually at 89, missing 29 migrations, 41 app functions and 40
# policies. Every repository-side check passed because Check 9 compares the manifest to the
# migration FILES and never opens a database. A guard that cannot fail on live drift must not be
# read as evidence about live state, so the two concerns are separate scripts with separate verdicts.
#
# Scope: this script checks LOCAL only, because it reaches the database through docker/psql. Primary
# is reached through the Supabase MCP connector, which is not available to a shell script; pass its
# fingerprint with -PrimaryFingerprint to have it compared here too.
#
# Exit 0 = parity proven. Exit 1 = drift, unreachable, or unproven.
param(
    [string]$Container = 'supabase_db_ORVION',
    [string]$PrimaryFingerprint = ''
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$issues = 0

# 1. The expected state, derived from the migration files -- the same recipe Check 9 uses, so the
#    two guards cannot disagree about what "correct" means.
$migDir = Join-Path $RepoRoot 'supabase/migrations'
$migNames = Get-ChildItem -Path $migDir -Filter '*.sql' -File |
            ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) } |
            Sort-Object -CaseSensitive
$expectedCount = $migNames.Count
$md5 = [System.Security.Cryptography.MD5]::Create()
$expectedPrint = ([BitConverter]::ToString(
                    $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes(($migNames -join ',')))
                 ) -replace '-', '').ToLower()

Write-Host "== Expected (from supabase/migrations) ==" -ForegroundColor Cyan
Write-Host "  $expectedCount migrations, fingerprint $expectedPrint"

# 2. Local.
Write-Host "== Check L1: local database ledger ==" -ForegroundColor Cyan
$sql = "select count(*)::text || '|' || md5(string_agg(version || '_' || name, ',' order by version)) from supabase_migrations.schema_migrations;"
$local = docker exec -i $Container psql -U postgres -d postgres -t -A -c $sql 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  UNREACHABLE: container '$Container' did not answer. Local parity is UNPROVEN, not CLEAN." -ForegroundColor Yellow
    Write-Host "  $local" -ForegroundColor DarkGray
    $issues++
} else {
    $parts = ($local | Select-Object -Last 1).Trim() -split '\|'
    $localCount = [int]$parts[0]
    $localPrint = $parts[1]
    Write-Host "  $localCount migrations, fingerprint $localPrint"
    if ($localCount -ne $expectedCount) {
        Write-Host "  LOCAL DRIFT: repository holds $expectedCount migrations, local database has applied $localCount" -ForegroundColor Red
        Write-Host "  Remedy: npx supabase db reset" -ForegroundColor DarkGray
        $issues++
    } elseif ($localPrint -ne $expectedPrint) {
        Write-Host "  LOCAL DRIFT: counts agree but contents differ -- same number of migrations, different set" -ForegroundColor Red
        $issues++
    }
}

# 3. Primary, only if its fingerprint was supplied by a caller that can reach it.
Write-Host "== Check P1: primary database ledger ==" -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($PrimaryFingerprint)) {
    Write-Host "  NOT CHECKED: no -PrimaryFingerprint supplied. Primary parity is UNPROVEN by this run." -ForegroundColor Yellow
} elseif ($PrimaryFingerprint -ne $expectedPrint) {
    Write-Host "  PRIMARY DRIFT: Primary reports $PrimaryFingerprint, repository produces $expectedPrint" -ForegroundColor Red
    $issues++
} else {
    Write-Host "  Primary matches the repository ($PrimaryFingerprint)" -ForegroundColor Green
    # The value is CALLER-SUPPLIED and this script cannot verify where it came from. Passing the
    # repository's own expected fingerprint makes this check agree with itself, which is not the
    # same as agreeing with Primary -- a real near-miss on 2026-08-29, caught only by querying
    # Primary independently. The caveat belongs in the OUTPUT, not only in the header.
    Write-Host "  (caller-supplied: this proves Primary parity only if that value was READ FROM Primary)" -ForegroundColor DarkGray
}

Write-Host ""
if ($issues -eq 0) {
    Write-Host "DATABASE PARITY: CLEAN (local proven$(if ($PrimaryFingerprint) { '; primary proven' } else { '; primary NOT checked' }))" -ForegroundColor Green
    exit 0
} else {
    Write-Host "DATABASE PARITY: $issues issue(s) found" -ForegroundColor Red
    exit 1
}
