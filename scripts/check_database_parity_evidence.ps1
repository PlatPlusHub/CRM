# ORVION -- PAR-6: the DATABASE profile's parity verification, satisfied from RECORDED Primary
# evidence instead of from three values a local process cannot obtain.
#
# ==================================================================================================
# THE DEADLOCK THIS RESOLVES (PAR-6, measured 2026-09-20)
# ==================================================================================================
# `Get-ProfileEvidence`'s DATABASE arm made `scripts/check_database_parity.ps1` mandatory and invoked
# it BARE, while listing the three Primary values it needs as `Deferred` EXTERNAL evidence. The
# profile therefore required a command to pass and, in the same breath, declared the evidence that
# command needs unreachable from PowerShell. Measured at a HEAD where every parity check passes: the
# bare call reported `$issues = 0` and still exited 2, because
# `$primaryProven = $PrimaryFingerprint -and $PrimaryLogicHash -and $PrimaryStructureHash` and a bare
# call supplies none of them. `Invoke-Verification` treats any non-zero exit as fatal, so no
# DATABASE-profile Change Request could ever write a certification receipt. Latent since SPEC-189.
#
# The fail-closed behaviour was NOT the defect and is NOT weakened here. `AUD-05` made "not measured"
# stop counting as "passed", and that stays exactly as it was: this script cannot make the parity
# engine return 0 for a database that disagrees with the evidence.
#
# ==================================================================================================
# WHY EVIDENCE AND NOT A LIVE READ (the same constraint RECOVER-1 already answered)
# ==================================================================================================
# A live read from `-Finish` was evaluated first and is not available: `.mcp.json` exposes
# `supabase-primary` as an HTTP MCP endpoint reachable by the AGENT, not by a script; there is no
# SUPABASE_ACCESS_TOKEN / SUPABASE_DB_PASSWORD / PGPASSWORD in the environment; and the CLI is not
# linked to a project. Giving this script a Primary credential would mean committing one or planting
# one, which `AGENTS.md` forbids ("Credentials remain external to Git"). `check_primary_ledger.ps1`
# already chose evidence over a faked live read for the ledger, for these same reasons, and this
# script extends that choice to the other two parity facts rather than inventing a second policy.
#
# THE OWNERSHIP SPLIT, STATED SO NO LAYER CLAIMS ANOTHER'S WORK:
#   LIVE READ        - the agent queries Primary through `supabase-primary`, at the DATABASE
#                      execution boundary, and writes what it observed into the evidence file.
#   RECORDED         - Git stores that observation, attributable to a commit.
#   LOCAL VALIDATION - this script proves the recorded observation is well-formed, belongs to this
#                      history, names Primary, and still AGREES with the database this repository
#                      currently generates.
# This script NEVER contacts Primary and never says it did.
#
# ==================================================================================================
# WHY THIS IS A TRANSPORT, NOT A SECOND PARITY IMPLEMENTATION
# ==================================================================================================
# It computes no hash and compares no surface. `check_primary_ledger.ps1` remains the ledger
# evidence authority and is INVOKED, not reimplemented; `check_database_parity.ps1` remains the one
# comparison engine and is INVOKED with the recorded values; `parity_surface.sql` remains the one
# structural definition. This file only carries three numbers from the evidence record to the engine
# and propagates the engine's exact exit code -- so the two can never disagree about what parity
# means, which is the PAR-1a mistake one layer up.
#
# ==================================================================================================
# FRESHNESS IS SEMANTIC, NOT A CLOCK
# ==================================================================================================
# There is no TTL, deliberately. Staleness is caught CAUSALLY, by the comparison itself:
#   * a migration added or edited in the repository changes the local ledger and the local function
#     and structural hashes, so evidence recorded before that change no longer matches and the
#     engine reports DRIFT;
#   * `check_primary_ledger.ps1` independently refuses evidence whose recorded ledger is not the
#     repository's migration set, and refuses evidence recorded on a non-ancestor commit.
# A wall-clock TTL would fail evidence that is still true and pass evidence that is not.
#
# THE RESIDUAL, STATED PLAINLY (MEAS-1, GUARD-1): no repository-local mechanism can prove the
# recorded values were READ FROM Primary rather than generated from the repository. That residual is
# unchanged by this script and is not closed here. What IS now impossible is the RECOVER-1 shape for
# the full parity surface: certifying a DATABASE change while the repository holds no attributable
# Primary reading for the state it generates.
#
# Exit code: this script's own failures exit 1; otherwise it exits with EXACTLY the parity engine's
# exit code (0 CLEAN / 1 DRIFT / 2 UNPROVEN), so nothing is laundered on the way out.
[CmdletBinding()]
param(
    [string]$EvidencePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'reports/evidence/primary-ledger-evidence.json'),
    # Primary for this repository, per `MASTER_INTEGRATION_CATALOG.md §0` and the manifest's
    # deployment-topology line. Secondary `brplkqmbzffpxqgkkdzo` belongs to another repository and
    # must never satisfy this repository's parity: evidence naming it is refused by identity, not by
    # hoping the hashes happen to differ. Same hardcoding precedent as Check 8's `$authorizedRefs`.
    [string]$ExpectedProjectRef = 'vrvtsxexkiiiivlkdxzp',
    [string]$Container = 'supabase_db_ORVION'
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path -Parent $here

function Bad([string]$msg) { Write-Host "  $msg" -ForegroundColor Red }

Write-Host "== PAR-6: Primary parity evidence -> parity engine ==" -ForegroundColor Cyan

# --- 1. The ledger portion is validated by its OWN authority, invoked rather than restated. -------
# This is what makes the evidence attributable, internally self-consistent and bound to this
# history. Re-implementing any of it here would create the second authority this design exists to
# avoid, and the two could then disagree about what "matches" means.
$ledgerGuard = Join-Path $here 'check_primary_ledger.ps1'
if (-not (Test-Path $ledgerGuard)) {
    Bad "MISSING: scripts/check_primary_ledger.ps1 -- the evidence cannot be validated."
    Write-Host "PRIMARY PARITY EVIDENCE: FAILED" -ForegroundColor Red
    exit 1
}
& pwsh -NoProfile -File $ledgerGuard -EvidencePath $EvidencePath -Quiet
if ($LASTEXITCODE -ne 0) {
    Bad "Primary ledger evidence is not usable (check_primary_ledger.ps1 exit $LASTEXITCODE)."
    Bad "Parity cannot be proven from evidence that is missing, unattributable or out of date."
    Write-Host "PRIMARY PARITY EVIDENCE: FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "  ledger evidence validated by scripts/check_primary_ledger.ps1" -ForegroundColor Green

# --- 2. The two surface facts the ledger guard does not own. ----------------------------------
if (-not (Test-Path $EvidencePath)) {
    Bad "MISSING: $EvidencePath"
    Write-Host "PRIMARY PARITY EVIDENCE: FAILED" -ForegroundColor Red
    exit 1
}
try { $ev = Get-Content $EvidencePath -Raw | ConvertFrom-Json }
catch {
    Bad "UNREADABLE: $EvidencePath is not valid JSON. $($_.Exception.Message)"
    Write-Host "PRIMARY PARITY EVIDENCE: FAILED" -ForegroundColor Red
    exit 1
}

$fail = 0

# The project identity is checked by NAME, not inferred from the numbers. Evidence read from the
# wrong project is refused even if every hash happened to agree.
if ([string]::IsNullOrWhiteSpace($ev.project_ref)) {
    Bad "INCOMPLETE: evidence has no 'project_ref'."; $fail++
} elseif ($ev.project_ref -ne $ExpectedProjectRef) {
    Bad "WRONG PROJECT: evidence was read from '$($ev.project_ref)', but this repository deploys only to '$ExpectedProjectRef'."
    Bad "Secondary and every other project are refused here by identity. See MASTER_INTEGRATION_CATALOG.md section 0."
    $fail++
}

# Both hashes must be PRESENT and well-formed. A missing hash is the AUD-05 shape -- an unmeasured
# value quietly counting as a measured one -- so it fails here rather than reaching the engine as an
# empty string, which the engine would report as "NOT CHECKED" while this script exited 0.
foreach ($pair in @(
    @{ Field = 'function_surface_hash';   Label = 'Primary function-surface hash' },
    @{ Field = 'structural_surface_hash'; Label = 'Primary structural-surface hash' }
)) {
    $value = $ev.($pair.Field)
    if ([string]::IsNullOrWhiteSpace($value)) {
        Bad "INCOMPLETE: evidence has no '$($pair.Field)'. The $($pair.Label) is UNPROVEN, and UNPROVEN IS NOT CLEAN."
        Bad "Remedy: re-read Primary through the supabase-primary connector and refresh the evidence file."
        $fail++
    } elseif ($value -notmatch '^[0-9a-f]{32}$') {
        Bad "MALFORMED: '$($pair.Field)' is '$value', which is not a 32-character lowercase md5."
        $fail++
    }
}

if ($fail -gt 0) {
    Write-Host "PRIMARY PARITY EVIDENCE: FAILED ($fail issue(s))" -ForegroundColor Red
    exit 1
}

Write-Host "  evidence names project $($ev.project_ref), read $($ev.read_at) at commit $($ev.repository_head)" -ForegroundColor DarkGray
Write-Host "  (evidence class: a RECORDED Primary reading, not a live one -- this script never contacts Primary)" -ForegroundColor DarkGray

# --- 3. Hand the recorded values to the ONE comparison engine and propagate its verdict. ---------
# Everything above is transport and admissibility. The parity judgement itself -- and therefore the
# exit code -- belongs entirely to check_database_parity.ps1, including its own L1/L5/L3 checks.
$parity = Join-Path $here 'check_database_parity.ps1'
if (-not (Test-Path $parity)) {
    Bad "MISSING: scripts/check_database_parity.ps1 -- the parity engine is gone."
    Write-Host "PRIMARY PARITY EVIDENCE: FAILED" -ForegroundColor Red
    exit 1
}

& pwsh -NoProfile -File $parity `
    -Container $Container `
    -PrimaryFingerprint $ev.ledger_fingerprint `
    -PrimaryLogicHash $ev.function_surface_hash `
    -PrimaryStructureHash $ev.structural_surface_hash
$parityExit = $LASTEXITCODE

Write-Host ""
if ($parityExit -eq 0) {
    Write-Host "PRIMARY PARITY EVIDENCE: CLEAN -- recorded Primary state agrees with the database this repository generates" -ForegroundColor Green
} else {
    Write-Host "PRIMARY PARITY EVIDENCE: parity engine exited $parityExit -- see its verdict above" -ForegroundColor Red
    Write-Host "  If the repository changed after the evidence was recorded, re-read Primary and refresh the evidence." -ForegroundColor DarkGray
}
exit $parityExit
