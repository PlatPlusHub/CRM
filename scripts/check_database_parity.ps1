# Database parity gate -- deliberately SEPARATE from check_repository_consistency.ps1.
#
# Why this exists (incident 2026-08-26): the repository held 118 migrations, the manifest claimed
# local was at 118, and `check_repository_consistency.ps1` printed REPOSITORY CONSISTENCY: CLEAN --
# while the local database was actually at 89, missing 29 migrations, 41 app functions and 40
# policies. Every repository-side check passed because Check 9 compares the manifest to the
# migration FILES and never opens a database. A guard that cannot fail on live drift must not be
# read as evidence about live state, so the two concerns are separate scripts with separate verdicts.
#
# PAR-1 (2026-08-29): the ledger fingerprint alone is NOT parity. It proves the same migration NAMES
# were applied; it says nothing about what the applied SQL actually created. Six `app` functions on
# Primary were found carrying reformatted, comment-stripped source from earlier hand-transcribed
# deploys, while every fingerprint check reported CLEAN -- because parity had only ever compared the
# functions each package had just changed. -PrimaryLogicHash closes that: it covers the FULL function
# surface, so drift anywhere is visible rather than drift only where someone thought to look.
#
# PAR-1a (2026-08-29): USE THIS SCRIPT'S EXPRESSION, NOT AN AD-HOC ONE. The comment-stripping pattern
# below is built with `chr(10)` deliberately. Writing it as '--[^\n]*' does NOT mean "up to the next
# newline": inside a POSIX bracket expression the backslash is not an escape, so `[^\n]` reads as
# "not a backslash and not the letter n" and the pattern stops at the first `n` in the comment,
# leaving most of the comment text in the hash. Two databases compared with THAT pattern can agree
# while genuinely differing -- which is how `app.document_retention_days` stayed different between
# local and Primary through a session that reported the whole surface identical.
#
# Scope: this script checks LOCAL only, because it reaches the database through docker/psql. Primary
# is reached through the Supabase MCP connector, which is not available to a shell script; pass its
# fingerprint with -PrimaryFingerprint to have it compared here too.
#
# Exit 0 = parity proven. Exit 1 = drift, unreachable, or unproven.
param(
    [string]$Container = 'supabase_db_ORVION',
    [string]$PrimaryFingerprint = '',
    [string]$PrimaryLogicHash = ''
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

# 4. The function surface. This is what the ledger fingerprint cannot see.
Write-Host "== Check L2/P2: function surface ==" -ForegroundColor Cyan
$logicSql = "select md5(string_agg(h, ',' order by h)) || '|' || count(*)::text from (select md5(n.nspname || '.' || p.proname || '|' || regexp_replace(regexp_replace(pg_get_functiondef(p.oid), '--[^' || chr(10) || ']*', '', 'g'), '\s+', ' ', 'g')) as h from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname in ('app','public') and p.prokind = 'f') t;"
$localLogic = docker exec -i $Container psql -U postgres -d postgres -t -A -c $logicSql 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  UNREACHABLE: could not read the local function surface." -ForegroundColor Yellow
    $issues++
} else {
    $lparts = ($localLogic | Select-Object -Last 1).Trim() -split '\|'
    Write-Host "  local: $($lparts[1]) functions, logic hash $($lparts[0])"
    if ([string]::IsNullOrWhiteSpace($PrimaryLogicHash)) {
        Write-Host "  NOT CHECKED: no -PrimaryLogicHash supplied. Primary's FUNCTION SURFACE is UNPROVEN by this run." -ForegroundColor Yellow
        Write-Host "  Run the same query on Primary and pass its result -- see PAR-1 in the header." -ForegroundColor DarkGray
    } elseif ($PrimaryLogicHash -ne $lparts[0]) {
        Write-Host "  PRIMARY FUNCTION DRIFT: Primary reports $PrimaryLogicHash, local produces $($lparts[0])" -ForegroundColor Red
        Write-Host "  The ledgers may still agree -- that is exactly the PAR-1 blind spot." -ForegroundColor DarkGray
        $issues++
    } else {
        Write-Host "  Primary's function surface matches local ($PrimaryLogicHash)" -ForegroundColor Green
        Write-Host "  (caller-supplied, as above: it proves parity only if READ FROM Primary)" -ForegroundColor DarkGray
    }
}

Write-Host ""
if ($issues -eq 0) {
    Write-Host "DATABASE PARITY: CLEAN (local proven; primary ledger $(if ($PrimaryFingerprint) { 'proven' } else { 'NOT checked' }); primary functions $(if ($PrimaryLogicHash) { 'proven' } else { 'NOT checked' }))" -ForegroundColor Green
    exit 0
} else {
    Write-Host "DATABASE PARITY: $issues issue(s) found" -ForegroundColor Red
    exit 1
}
