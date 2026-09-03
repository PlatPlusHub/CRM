# ORVION -- RECOVER-1: does the repository hold ATTRIBUTABLE, CURRENT evidence that Primary's
# migration ledger is the repository's migration ledger?
#
# ==================================================================================================
# WHAT WENT WRONG, AND WHY THE EXISTING GUARDS WERE NOT ENOUGH (RECOVER-1, 2026-09-03)
# ==================================================================================================
# On 2026-09-02 four migrations were applied to Primary and never committed. Primary held 188,
# the repository held 184, and the repository could not rebuild the environment it deploys to.
#
# It is worth being precise about which guard failed, because the obvious answer is wrong:
#
#   * `check_database_parity.ps1` DOES fail closed. Run with no Primary values it exits 2 and prints
#     "UNPROVEN -- PRIMARY WAS NOT CONTACTED ... This is NOT a pass". It did not lie.
#   * `check_repository_consistency.ps1` reads files only, says so on success, and has never had an
#     opinion about Primary.
#
# So the hole was not a guard that said CLEAN when it should have said DIRTY. **The hole was that
# nothing in the repository RECORDED whether Primary had ever been read at this HEAD.** Parity was
# asserted in a terminal, in a session, and then lost. A later session -- or a reviewer, or CI --
# could not answer "was Primary verified for this commit?" from the repository at all, and an
# unanswerable question is indistinguishable from a satisfied one when nobody asks it.
#
# The fix is therefore not another count comparison. It is to make the answer DURABLE, ATTRIBUTABLE
# and FAIL-CLOSED, and to put the check in the guard that is actually run on every commit and in CI.
#
# ==================================================================================================
# WHY THIS IS EVIDENCE-BASED AND NOT A LIVE READ (design B, chosen on constraints, not taste)
# ==================================================================================================
# A live read would be stronger, and it was evaluated first. It is not available:
#   * `.mcp.json` exposes `supabase-primary` as an HTTP MCP endpoint with no reusable local secret --
#     it is reachable by the agent, not by a script.
#   * SUPABASE_ACCESS_TOKEN / SUPABASE_DB_PASSWORD / PGPASSWORD are all ABSENT from the environment.
#   * `supabase/.temp/` holds only `cli-latest`: the CLI is NOT linked to a project, so
#     `supabase migration list --linked` has nothing to authenticate with.
# Giving this script a Primary credential would mean committing one or planting one in the
# environment, which `AGENTS.md §6` forbids outright. **Faking a live read is worse than admitting an
# evidence-based one**, so this guard is honest about its class: it verifies RECORDED evidence.
#
# ==================================================================================================
# WHAT MAKES THIS STRONGER THAN "SOMEONE PASTED A NUMBER"
# ==================================================================================================
# A pasted count or a single pasted hash is exactly what this guard refuses to accept, on four counts:
#
#   1. THE WHOLE LEDGER, NOT A COUNT. The evidence carries every `version_name` Primary reported.
#      A count match with different identities fails; an extra on either side fails; a rename fails.
#   2. INTERNALLY SELF-CHECKED. `migration_count` and `ledger_fingerprint` are RECOMPUTED from the
#      `ledger` array. Editing the number without editing the 189-entry array is detected, so the
#      number carries no authority of its own -- the list does.
#   3. BOUND TO HISTORY. `repository_head` must be an ancestor of (or equal to) the current HEAD, so
#      evidence carried over from an abandoned branch or a rewritten history is refused.
#   4. FAIL-CLOSED. Missing file, unreadable file, missing field, or any disagreement is a FAILURE.
#      There is no "NOT CHECKED, continuing" path. UNKNOWN never becomes CLEAN.
#
# THE RESIDUAL, STATED PLAINLY BECAUSE A GUARD MUST NOT CLAIM MORE THAN IT MEASURES (MEAS-1):
# this guard cannot prove the recorded ledger was *read from Primary* rather than generated from the
# repository -- that is GUARD-1's class and no repository-local mechanism can close it. What it DOES
# guarantee is that the RECOVER-1 state -- no Primary reading for the current migration set, every
# guard green -- is now impossible: it is a hard failure, in CI, on every commit. Refreshing the
# evidence requires actually contacting Primary, and the procedure is recorded beside the file.

[CmdletBinding()]
param(
    [string]$EvidencePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'reports/evidence/primary-ledger-evidence.json'),
    [string]$MigrationDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'supabase/migrations'),
    # Set by the caller when this runs inside another guard, so the banner is not printed twice.
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$fail = 0
function Say($msg, $colour = 'Gray') { if (-not $Quiet) { Write-Host $msg -ForegroundColor $colour } }
function Bad($msg) { Write-Host "  $msg" -ForegroundColor Red; $script:fail++ }

Say "== RECOVER-1: Primary ledger evidence ==" 'Cyan'

# --- 1. The evidence must exist. Absence is the RECOVER-1 state itself. -----------------------
if (-not (Test-Path $EvidencePath)) {
    Bad "MISSING: $EvidencePath does not exist. Primary parity is UNKNOWN, and UNKNOWN IS NOT CLEAN."
    Bad "Remedy: read Primary's ledger via the supabase-primary MCP and write the evidence file."
    Write-Host "RECOVER-1 LEDGER EVIDENCE: FAILED ($fail issue(s))" -ForegroundColor Red
    exit 1
}

try { $ev = Get-Content $EvidencePath -Raw | ConvertFrom-Json }
catch {
    Bad "UNREADABLE: $EvidencePath is not valid JSON. $($_.Exception.Message)"
    Write-Host "RECOVER-1 LEDGER EVIDENCE: FAILED ($fail issue(s))" -ForegroundColor Red
    exit 1
}

foreach ($f in 'project_ref','read_at','repository_head','migration_count','ledger_fingerprint','ledger') {
    if ($null -eq $ev.$f) { Bad "INCOMPLETE: evidence has no '$f' field." }
}
if ($fail -gt 0) { Write-Host "RECOVER-1 LEDGER EVIDENCE: FAILED ($fail issue(s))" -ForegroundColor Red; exit 1 }

# --- 2. The evidence must be internally consistent. -------------------------------------------
# This is what makes a pasted number worthless: the count and the fingerprint are DERIVED from the
# ledger array here, so they cannot be edited into agreement without forging the whole list.
$ledger = @($ev.ledger | Sort-Object -CaseSensitive)
$md5    = [System.Security.Cryptography.MD5]::Create()
$calc   = ([BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes(($ledger -join ',')))) -replace '-','').ToLower()

if ([int]$ev.migration_count -ne $ledger.Count) {
    Bad "SELF-INCONSISTENT: evidence claims $($ev.migration_count) migrations but lists $($ledger.Count)."
}
if ($ev.ledger_fingerprint -ne $calc) {
    Bad "SELF-INCONSISTENT: recorded fingerprint $($ev.ledger_fingerprint) is not the hash of the recorded ledger ($calc)."
    Bad "A hand-edited count or hash is exactly what this check exists to reject."
}

# --- 3. The evidence must belong to THIS history. ---------------------------------------------
$headNow = (git rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($headNow)) {
    Bad "UNRESOLVABLE: could not read the current git HEAD; evidence cannot be attributed."
} else {
    $headNow = $headNow.Trim()
    git cat-file -e "$($ev.repository_head)^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Bad "UNATTRIBUTABLE: evidence names HEAD $($ev.repository_head), which is not a commit in this repository."
    } else {
        git merge-base --is-ancestor $ev.repository_head $headNow 2>$null
        if ($LASTEXITCODE -ne 0) {
            Bad "STALE/FOREIGN: evidence was recorded at $($ev.repository_head), which is NOT an ancestor of HEAD $headNow."
            Bad "It belongs to an abandoned branch or a rewritten history and certifies nothing about this commit."
        }
    }
}

# --- 4. The recorded Primary ledger must BE the repository's ledger. ---------------------------
# The comparison is a SET comparison over full `version_name` identities, so it catches an extra on
# either side, a missing entry, and a same-count/different-identity swap. It is also, deliberately,
# the staleness check that matters: adding a migration to the repository without re-reading Primary
# changes this set and fails here, which is the RECOVER-1 incident in reverse.
if (-not (Test-Path $MigrationDir)) {
    Bad "MISSING: $MigrationDir does not exist."
} else {
    $repo = @(Get-ChildItem -Path $MigrationDir -Filter '*.sql' -File |
              ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) } |
              Sort-Object -CaseSensitive)

    $onlyPrimary = @($ledger | Where-Object { $repo -notcontains $_ })
    $onlyRepo    = @($repo   | Where-Object { $ledger -notcontains $_ })

    if ($onlyPrimary.Count -gt 0) {
        Bad "PRIMARY HAS $($onlyPrimary.Count) MIGRATION(S) THE REPOSITORY DOES NOT -- this is RECOVER-1 exactly:"
        $onlyPrimary | ForEach-Object { Bad "    only on Primary: $_" }
        Bad "Recover them from supabase_migrations.schema_migrations.statements before doing anything else."
    }
    if ($onlyRepo.Count -gt 0) {
        Bad "THE REPOSITORY HAS $($onlyRepo.Count) MIGRATION(S) PRIMARY HAS NOT RUN (undeployed, or evidence not refreshed):"
        $onlyRepo | ForEach-Object { Bad "    only in repository: $_" }
    }
    if ($onlyPrimary.Count -eq 0 -and $onlyRepo.Count -eq 0) {
        Say "  Primary's recorded ledger and the repository agree exactly ($($repo.Count) migrations, $calc)" 'Green'
        Say "  evidence read $($ev.read_at) from project $($ev.project_ref), at commit $($ev.repository_head)" 'DarkGray'
        Say "  (evidence class: a RECORDED Primary reading, not a live one -- see this script's header)" 'DarkGray'
    }
}

if ($fail -gt 0) {
    Write-Host "RECOVER-1 LEDGER EVIDENCE: FAILED ($fail issue(s))" -ForegroundColor Red
    exit 1
}
Say "RECOVER-1 LEDGER EVIDENCE: CLEAN" 'Green'
exit 0
