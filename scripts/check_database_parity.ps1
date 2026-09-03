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
# PAR-1b (2026-08-29): CHECK L2 COMPARES *LOCAL*, AND LOCAL EQUALS THE REPOSITORY ONLY IMMEDIATELY
# AFTER `npx supabase db reset`. Applying a migration to local by hand mid-session -- which is normal
# while iterating -- makes local diverge from the migration FILES, and anything read out of it after
# that is not "the repository's text". That mistake was made twice: once it pushed a non-repository
# form of `app.document_retention_days` onto Primary while reporting the opposite, and once it
# produced a false PRIMARY FUNCTION DRIFT alarm. If this check reports drift, RESET LOCAL AND RE-READ
# BOTH SIDES BEFORE CHANGING ANYTHING ON PRIMARY. The source of truth is supabase/migrations, not any
# running database.
#
# PAR-1a (2026-08-29): USE THIS SCRIPT'S EXPRESSION, NOT AN AD-HOC ONE. The comment-stripping pattern
# below is built with `chr(10)` deliberately. Writing it as '--[^\n]*' does NOT mean "up to the next
# newline": inside a POSIX bracket expression the backslash is not an escape, so `[^\n]` reads as
# "not a backslash and not the letter n" and the pattern stops at the first `n` in the comment,
# leaving most of the comment text in the hash. Two databases compared with THAT pattern can agree
# while genuinely differing -- which is how `app.document_retention_days` stayed different between
# local and Primary through a session that reported the whole surface identical.
#
# PAR-3 (2026-08-30): THE LEDGER AND THE FUNCTIONS WERE THE ONLY THINGS COMPARED. Reproduced on a
# clean local reset -- dropping `payment_allocations_within_invoice_total`, FIN-10's financial
# ceiling, shipped the day before -- and every gate still reported success: this script CLEAN exit 0,
# check_repository_consistency CLEAN, MASTER_API_CONTRACT "matches the live surface", and
# verify_database.sql ALL CHECKS PASSED. Only `72_invoice_allocation_ceiling_test.sql` noticed, and
# pgTAP runs against LOCAL only -- so the sole bridge to Primary was comparing 233 objects out of
# 3,265, blind to triggers, policies, grants, constraints, columns, views, indexes and the
# status-transition rows. Every one of the last four packages shipped a TRIGGER. Check L4/P4 closes
# it: the surface is defined ONCE in scripts/parity_surface.sql and BOTH SIDES RUN THAT FILE.
#
# Scope: this script checks LOCAL only, because it reaches the database through docker/psql. Primary
# is reached through the Supabase MCP connector, which is not available to a shell script; pass its
# fingerprint with -PrimaryFingerprint to have it compared here too.
#
# Exit 0 = parity proven. Exit 1 = drift, unreachable, or unproven.
param(
    [string]$Container = 'supabase_db_ORVION',
    [string]$PrimaryFingerprint = '',
    [string]$PrimaryLogicHash = '',
    [string]$PrimaryStructureHash = ''
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
#
# RECOVER-1 (2026-09-03) added a DURABLE record of Primary's ledger at
# `reports/evidence/primary-ledger-evidence.json`, enforced by Check 18 of
# check_repository_consistency.ps1. This guard now cross-checks the pasted value against that record.
# The point is narrow and worth stating exactly: it does NOT make a pasted value authoritative, and
# it does not turn recorded evidence into a live read. It catches the case where the two DISAGREE --
# a mistyped, stale, or copied-from-the-wrong-terminal fingerprint -- which is a contradiction the
# repository can detect on its own and previously could not.
$evidenceFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'reports/evidence/primary-ledger-evidence.json'
$recordedPrint = $null
if (Test-Path $evidenceFile) {
    try { $recordedPrint = (Get-Content $evidenceFile -Raw | ConvertFrom-Json).ledger_fingerprint } catch { $recordedPrint = $null }
}

Write-Host "== Check P1: primary database ledger ==" -ForegroundColor Cyan
if (-not [string]::IsNullOrWhiteSpace($PrimaryFingerprint) -and $recordedPrint -and $PrimaryFingerprint -ne $recordedPrint) {
    Write-Host "  EVIDENCE CONTRADICTION: the -PrimaryFingerprint passed to this run ($PrimaryFingerprint)" -ForegroundColor Red
    Write-Host "  disagrees with the recorded Primary ledger evidence ($recordedPrint)." -ForegroundColor Red
    Write-Host "  One of them is stale. Re-read Primary and refresh reports/evidence/primary-ledger-evidence.json." -ForegroundColor DarkGray
    $issues++
}
if ([string]::IsNullOrWhiteSpace($PrimaryFingerprint)) {
    Write-Host "  NOT CHECKED: no -PrimaryFingerprint supplied. Primary parity is UNPROVEN by this run." -ForegroundColor Yellow
    if ($recordedPrint) {
        Write-Host "  (a recorded Primary ledger reading DOES exist and is enforced by Check 18 of" -ForegroundColor DarkGray
        Write-Host "   check_repository_consistency.ps1 -- but recorded evidence is not a live read, so" -ForegroundColor DarkGray
        Write-Host "   this run still cannot report Primary parity.)" -ForegroundColor DarkGray
    }
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

# 4b. PAR-3: everything the function hash cannot see. The SQL lives in scripts/parity_surface.sql so
#     that local and Primary cannot be compared with two subtly different queries -- the PAR-1a
#     mistake one layer up. The per-surface breakdown prints either way, so a mismatch names WHICH
#     surface drifted instead of only reporting that something did.
Write-Host "== Check L4/P4: structural surface (triggers, policies, grants, constraints, columns, views, indexes, transitions) ==" -ForegroundColor Cyan
$surfaceFile = Join-Path $PSScriptRoot 'parity_surface.sql'
if (-not (Test-Path $surfaceFile)) {
    Write-Host "  MISSING: scripts/parity_surface.sql -- the structural surface cannot be computed." -ForegroundColor Red
    $issues++
} else {
    $surfaceOut = Get-Content $surfaceFile -Raw |
                  docker exec -i $Container psql -U postgres -d postgres -q -t -A -F '|' -v ON_ERROR_STOP=1 -f - 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  UNREACHABLE: could not read the local structural surface." -ForegroundColor Yellow
        Write-Host "  $surfaceOut" -ForegroundColor DarkGray
        $issues++
    } else {
        $rows = @($surfaceOut | Where-Object { $_ -match '\|' })
        $localCombined = $null; $localTotal = 0
        foreach ($row in $rows) {
            $c = $row.Trim() -split '\|'
            if ($c.Count -lt 3) { continue }
            if ($c[0] -eq '_combined') { $localCombined = $c[1]; $localTotal = $c[2] }
            else { Write-Host ("    {0,-20} {1}  ({2})" -f $c[0], $c[1], $c[2]) -ForegroundColor DarkGray }
        }
        if (-not $localCombined) {
            Write-Host "  MALFORMED: parity_surface.sql returned no _combined row." -ForegroundColor Red
            $issues++
        } else {
            Write-Host "  local: $localTotal objects, structure hash $localCombined"
            if ([string]::IsNullOrWhiteSpace($PrimaryStructureHash)) {
                Write-Host "  NOT CHECKED: no -PrimaryStructureHash supplied. Primary's STRUCTURE is UNPROVEN by this run." -ForegroundColor Yellow
                Write-Host "  Run scripts/parity_surface.sql on Primary (supabase-primary MCP) and pass its _combined value." -ForegroundColor DarkGray
            } elseif ($PrimaryStructureHash -ne $localCombined) {
                Write-Host "  PRIMARY STRUCTURE DRIFT: Primary reports $PrimaryStructureHash, local produces $localCombined" -ForegroundColor Red
                Write-Host "  The ledger and the function surface can both still agree -- that is the PAR-3 blind spot." -ForegroundColor DarkGray
                Write-Host "  Remedy: run scripts/parity_surface.sql on BOTH sides and compare the per-surface rows above" -ForegroundColor DarkGray
                Write-Host "  to find which surface moved, then reconcile from supabase/migrations (never from a database)." -ForegroundColor DarkGray
                $issues++
            } else {
                Write-Host "  Primary's structural surface matches local ($PrimaryStructureHash)" -ForegroundColor Green
                Write-Host "  (caller-supplied, as above: it proves parity only if READ FROM Primary)" -ForegroundColor DarkGray
            }
        }
    }
}

# 4c. META-1 (2026-09-01): the manifest PUBLISHES the three live-state values, and until now nothing
#     compared what it publishes against what the databases actually hold. Proven by mutation:
#     corrupting the structural-surface hash in `manifest.md` left the repository guard CLEAN (it
#     opens no database) and this guard CLEAN (it never read the manifest), so the one document a
#     cold-start session reads for "is Primary synchronized?" could assert any value at all. The
#     ledger fingerprint was already covered by repository Check 9; the function and structural
#     surfaces were not covered by anything.
#
#     This compares the manifest against the LOCAL values computed above -- local is the repository's
#     own state after a reset, so a mismatch means the manifest is stale or wrong. It deliberately
#     does NOT compare against the caller-supplied Primary values: those are only Primary evidence if
#     they were read from Primary (GUARD-1), and a guard must not launder a supplied value into a
#     published fact.
Write-Host "== Check L5: manifest's published live-state hashes match this database ==" -ForegroundColor Cyan
$mfPath = Join-Path $RepoRoot '_ORVION_CANONICAL/manifest.md'
if (-not (Test-Path $mfPath)) {
    Write-Host "  MISSING: _ORVION_CANONICAL/manifest.md" -ForegroundColor Red
    $issues++
} else {
    $mfText = Get-Content $mfPath -Raw
    $mfIssues = 0
    # Both values are produced by the checks above: $lparts[0] by Check L2/P2 and $localCombined by
    # Check L4/P4. PowerShell scopes them to the script, not to the `if` blocks that assign them, so
    # they are readable here -- but each is null when its own query failed, which the loop treats as
    # NOT CHECKED rather than as a match. A guard that silently compares against an empty string
    # would report agreement between two things it never read.
    $localFnHash = if ($lparts -and $lparts.Count -gt 0) { $lparts[0] } else { $null }
    $pairs = @(
        @{ label = 'function surface';   rx = 'full-function-surface hash `([0-9a-f]{32})`'; actual = $localFnHash },
        @{ label = 'structural surface'; rx = 'structural-surface hash `([0-9a-f]{32})`';    actual = $localCombined }
    )
    foreach ($pair in $pairs) {
        if ([string]::IsNullOrWhiteSpace($pair.actual)) {
            Write-Host "  NOT CHECKED: local $($pair.label) was not computed by this run" -ForegroundColor Yellow
            continue
        }
        $m = [regex]::Match($mfText, $pair.rx)
        if (-not $m.Success) {
            Write-Host "  MANIFEST publishes no $($pair.label) hash -- cannot verify what a cold start would read" -ForegroundColor Yellow
            $mfIssues++
        } elseif ($m.Groups[1].Value -ne $pair.actual) {
            Write-Host "  MANIFEST STALE: it publishes $($pair.label) $($m.Groups[1].Value), this database holds $($pair.actual)" -ForegroundColor Red
            $mfIssues++
        }
    }
    if ($mfIssues -gt 0) {
        Write-Host "  Remedy: update manifest.md's 'Live state' line. It is what a fresh session reads to answer" -ForegroundColor DarkGray
        Write-Host "  'is Primary synchronized?', so a wrong value there is worse than no value." -ForegroundColor DarkGray
        $issues += $mfIssues
    } else {
        Write-Host "  manifest's published function and structural hashes match this database" -ForegroundColor Green
    }
}

# 5. The API contract is GENERATED from this database. A generated document that nobody regenerates
#    is a stale claim, which is the failure mode this whole file exists to catch. Same shape as
#    Check 7's ai-map freshness test.
Write-Host "== Check L3: API contract freshness ==" -ForegroundColor Cyan
$contract = Join-Path $RepoRoot 'reports/master/MASTER_API_CONTRACT.md'
if (-not (Test-Path $contract)) {
    Write-Host "  MISSING: reports/master/MASTER_API_CONTRACT.md -- run scripts/generate-api-contract.ps1" -ForegroundColor Red
    $issues++
} else {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("orvion-api-contract-{0}.md" -f [guid]::NewGuid())
    try {
        & (Join-Path $PSScriptRoot 'generate-api-contract.ps1') -Container $Container -OutFile $tmp | Out-Null
        $a = [IO.File]::ReadAllText($contract).Replace("`r`n", "`n")
        $b = [IO.File]::ReadAllText($tmp).Replace("`r`n", "`n")
        if ($a -ne $b) {
            Write-Host "  CONTRACT STALE: the committed MASTER_API_CONTRACT.md no longer matches the live API surface." -ForegroundColor Red
            Write-Host "  Remedy: pwsh -File scripts/generate-api-contract.ps1" -ForegroundColor DarkGray
            $issues++
        } else {
            Write-Host "  MASTER_API_CONTRACT.md matches the live surface" -ForegroundColor Green
        }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
    }
}

Write-Host ""

# AUD-05 (2026-08-29): THIS SCRIPT USED TO PRINT "CLEAN" AND EXIT 0 WHEN PRIMARY WAS NEVER CONTACTED.
# The parenthetical did say "primary ledger NOT checked" -- but the verdict word was CLEAN and the
# exit status was 0, and an exit status is what a caller, a CI job or a future agent actually reads.
# That contradicted this file's OWN header contract ("Exit 0 = parity proven. Exit 1 = drift,
# unreachable, or unproven") and `AGENTS.md §4` Stage B step 8b, which already states that without
# -PrimaryFingerprint "Primary is reported UNPROVEN, which is not CLEAN". The governance was right
# and the script did not honour it; the script is what changed.
#
# Three outcomes now, deliberately distinct, because "not measured" is not a kind of "passed":
#   exit 0  CLEAN    -- everything this script claims was actually measured
#   exit 1  DRIFT    -- something was measured and disagreed
#   exit 2  UNPROVEN -- local is fine but Primary was never contacted; nothing to disagree with
# PAR-3: the structural hash joins the other two in what "proven" REQUIRES. Leaving it optional
# would have re-created exactly the defect AUD-05 fixed -- a value that is not measured quietly
# counting as one that passed.
$primaryProven = $PrimaryFingerprint -and $PrimaryLogicHash -and $PrimaryStructureHash

if ($issues -gt 0) {
    Write-Host "DATABASE PARITY: $issues issue(s) found" -ForegroundColor Red
    exit 1
} elseif (-not $primaryProven) {
    Write-Host "DATABASE PARITY: UNPROVEN -- local matches the repository, but PRIMARY WAS NOT CONTACTED." -ForegroundColor Yellow
    Write-Host "  primary ledger    : $(if ($PrimaryFingerprint) { 'proven' } else { 'NOT CHECKED' })" -ForegroundColor Yellow
    Write-Host "  primary functions : $(if ($PrimaryLogicHash) { 'proven' } else { 'NOT CHECKED' })" -ForegroundColor Yellow
    Write-Host "  primary structure : $(if ($PrimaryStructureHash) { 'proven' } else { 'NOT CHECKED' })" -ForegroundColor Yellow
    Write-Host "  This is NOT a pass. Read all three values live from Primary (supabase-primary MCP) and re-run" -ForegroundColor DarkGray
    Write-Host "  with -PrimaryFingerprint / -PrimaryLogicHash / -PrimaryStructureHash (the last from" -ForegroundColor DarkGray
    Write-Host "  scripts/parity_surface.sql). Never report this run as parity CLEAN." -ForegroundColor DarkGray
    exit 2
} else {
    Write-Host "DATABASE PARITY: CLEAN (local proven; primary ledger, functions and structure proven)" -ForegroundColor Green
    Write-Host "  (all three primary values are CALLER-SUPPLIED -- this is parity only if they were READ FROM Primary; GUARD-1)" -ForegroundColor DarkGray
    exit 0
}
