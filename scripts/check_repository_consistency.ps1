<#
.SYNOPSIS
  Repository consistency guard — permanent guard (GOVERNANCE.md §18 discovery-to-guard loop)
  for the drift class repaired in the 2026-07-15 Repository Recovery: broken document
  references in Living docs, and contradictory finding-status inside a Master register.

.DESCRIPTION
  Deterministic, dependency-free. Precision over recall — it must not cry wolf, or agents
  will learn to ignore it. Eight checks (1–2 Living docs; 3 boot routers; 4 all reports; 5 manifest;
  6 roadmap↔manifest; 7 ai-map freshness; 8 dual-project Supabase topology registry):
    Check 1 broken references · Check 2 intra-register status contradiction ·
    Check 3 boot-chain router integrity + AI-pointer thinness · Check 4 report class-header presence ·
    Check 5 manifest leanness (cold-boot cost) · Check 6 roadmap↔manifest phase agreement ·
    Check 7 ai-map freshness vs manifest · Check 8 Supabase project-topology registry integrity.
  Details inline. Original two checks documented below:

    1) BROKEN REFERENCES — in Living docs (repo-root *.md, _ORVION_CANONICAL/** except the
       two deprecated files, reports/master, reports/evidence, reports root), any strict
       document token (NN_name.md / MASTER_*.md / ADR-####.md) whose basename does not exist.
       Immutable/execution records (changes/**, reports/history/**) and placeholder tokens
       (NN_name.md, SPEC-NNN.md) are intentionally NOT linted.

    2) STATUS CONTRADICTION — within a single reports/master file, a finding ID that is
       shown OPEN in a table-row status cell (| ... | OPEN | ...) while the SAME file also
       marks it resolved (✅ / RESOLVED / IMPLEMENTED). This is the DC-16 row-vs-detail bug.

  Exit 0 = clean; 1 = issue(s) found (gates CI, GOVERNANCE.md §11). Never edits files.

.NOTES
  Run: pwsh -File scripts/check_repository_consistency.ps1
#>

param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path)

$ErrorActionPreference = 'Stop'
$issues = 0

# --- File index (basename -> exists) for reference resolution -------------------------------
$allFiles = Get-ChildItem -Path $RepoRoot -Recurse -File |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|backup|\.git)[\\/]' }
$fileNames = @{}
foreach ($f in $allFiles) { $fileNames[$f.Name.ToLower()] = $true }

# --- Living-doc set (what we lint) ----------------------------------------------------------
$deprecated = @()   # retired 2026-07-17; list kept for future tombstone exclusions
$livingDocs = $allFiles | Where-Object {
    $_.Extension -eq '.md' -and
    $_.FullName -notmatch '[\\/](changes|history)[\\/]' -and
    $deprecated -notcontains $_.Name.ToLower()
}

Write-Host "== Check 1: broken references in Living docs ==" -ForegroundColor Cyan

# Strict document tokens only. Placeholders (NN_, SPEC-NNN) excluded by requiring real digits/letters.
$strictRef = '(?<name>(?:[0-9]{2}_[a-z0-9_]+|MASTER_[A-Z0-9_]+|ADR-[0-9]{4})\.md)'

foreach ($md in $livingDocs) {
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($md.FullName)) {
        $lineNo++
        foreach ($m in [regex]::Matches($line, $strictRef)) {
            $name = $m.Groups['name'].Value.ToLower()
            if (-not $fileNames.ContainsKey($name)) {
                $rel = $md.FullName.Substring($RepoRoot.Length + 1)
                Write-Host "  BROKEN REF: $rel : $lineNo -> $($m.Groups['name'].Value)" -ForegroundColor Yellow
                $issues++
            }
        }
    }
}

Write-Host "== Check 2: intra-file status contradiction in reports/master ==" -ForegroundColor Cyan

$masterDir = Join-Path $RepoRoot 'reports/master'
$idPat = '\b(DC-[0-9]+|R[0-9]+|A[0-9]+|B[0-9]+|N[0-9]+|CDD-[0-9]+|BF-[0-9]+|RC-[0-9]+|OPS-[0-9]+|INV-[0-9]+)\b'

if (Test-Path $masterDir) {
    foreach ($md in Get-ChildItem $masterDir -Filter *.md -File) {
        $openAt = @{}      # id -> "line" where a table-row status cell is exactly OPEN
        $resolvedAt = @{}  # id -> "line" where the id is marked resolved
        $lineNo = 0
        foreach ($line in [System.IO.File]::ReadAllLines($md.FullName)) {
            $lineNo++
            # OPEN only when it is a padded table cell: | OPEN | (kills prose false-positives)
            $rowOpen = $line -match '\|\s*OPEN\s*\|'
            $rowResolved = $line -match '✅|\bRESOLVED\b|\bIMPLEMENTED\b'
            if (-not ($rowOpen -or $rowResolved)) { continue }
            # Only the row's leading ID (first table cell) is the row's subject — avoids
            # counting every id mentioned in a multi-id justification line.
            $leadId = [regex]::Match($line, '^\|\s*(?<id>' + $idPat.Trim('\b') + ')')
            $ids = @()
            if ($leadId.Success) { $ids = @($leadId.Groups['id'].Value) }
            elseif ($line -match '^###\s') {
                # detail-block heading: "### DC-16 — ..." — subject is its leading id
                $h = [regex]::Match($line, '^###\s+(?<id>' + $idPat.Trim('\b') + ')')
                if ($h.Success) { $ids = @($h.Groups['id'].Value) }
            }
            foreach ($id in $ids) {
                if ($rowOpen)     { $openAt[$id]     = $lineNo }
                if ($rowResolved) { $resolvedAt[$id] = $lineNo }
            }
        }
        foreach ($id in $openAt.Keys) {
            if ($resolvedAt.ContainsKey($id)) {
                Write-Host "  STATUS CONTRADICTION: $($md.Name): $id OPEN at line $($openAt[$id]) but resolved at line $($resolvedAt[$id])" -ForegroundColor Yellow
                $issues++
            }
        }
    }
}

Write-Host "== Check 4: every report declares its document class ==" -ForegroundColor Cyan
# A report without a class/type header has an ambiguous lifecycle (Living vs Historical vs
# Auto-generated — GOVERNANCE.md §4). The reports index and the ADR/backlog roots are exempt
# (they are not classed findings/records). Header must appear in the first 6 lines.
$reportExempt = @('readme.md','architecture-decision-records.md','future-backlog.md')
$reportsRoot = Join-Path $RepoRoot 'reports'
if (Test-Path $reportsRoot) {
    foreach ($md in Get-ChildItem $reportsRoot -Recurse -Filter *.md -File) {
        if ($reportExempt -contains $md.Name.ToLower()) { continue }
        $head = (Get-Content $md.FullName -TotalCount 6) -join "`n"
        if ($head -notmatch '(?im)^\s*(Class|Type|Status|Purpose)\s*:') {
            $rel = $md.FullName.Substring($RepoRoot.Length + 1)
            Write-Host "  UNTYPED REPORT: $rel has no Class/Type/Status/Purpose header (first 6 lines)" -ForegroundColor Yellow
            $issues++
        }
    }
}

Write-Host "== Check 3: boot-chain router integrity ==" -ForegroundColor Cyan
# The router files must always point to the single boot authority (AGENTS.md §4), or a fresh
# session's cold-boot chain is silently severed. Precise, low-false-positive.
$routers = @{
    'README.md'  = 'AGENTS.md'
    'llms.txt'   = 'AGENTS.md'
    'AGENTS.md'  = 'GOVERNANCE.md'   # §4 sequence must still route into governance + live state
}
foreach ($router in $routers.Keys) {
    $path = Join-Path $RepoRoot $router
    if (-not (Test-Path $path)) {
        Write-Host "  MISSING ROUTER: $router does not exist" -ForegroundColor Yellow
        $issues++
        continue
    }
    $text = Get-Content $path -Raw
    if ($text -notmatch [regex]::Escape($routers[$router])) {
        Write-Host "  BROKEN ROUTER: $router no longer references $($routers[$router]) — boot chain severed" -ForegroundColor Yellow
        $issues++
    }
}
if ((Get-Content (Join-Path $RepoRoot 'AGENTS.md') -Raw) -notmatch 'single authoritative boot sequence') {
    Write-Host "  BOOT AUTHORITY WEAKENED: AGENTS.md §4 no longer declares itself the single authoritative boot sequence" -ForegroundColor Yellow
    $issues++
}
# Anti-duplicate-authority: AI pointer files must stay THIN and keep routing to the boot chain.
# Precedent: llms.txt had grown into a restated SSOT matrix and drifted (2026-07-15). A pointer
# that accretes content is becoming a second authority — catch it by size + routing.
$thinPointers = @('CLAUDE.md','GEMINI.md','.github/copilot-instructions.md','.cursor/rules/orvion.mdc','llms.txt')
$pointerBudget = 25
foreach ($p in $thinPointers) {
    $pp = Join-Path $RepoRoot $p
    if (-not (Test-Path $pp)) { continue }   # not every tool's file exists in every checkout
    $n = @(Get-Content $pp).Count
    $t = Get-Content $pp -Raw
    if ($n -gt $pointerBudget) {
        Write-Host "  POINTER BLOAT: $p is $n lines (budget $pointerBudget) — a thin pointer is accreting duplicate authority" -ForegroundColor Yellow
        $issues++
    }
    if ($t -notmatch 'AGENTS\.md' -and $t -notmatch 'README\.md') {
        Write-Host "  POINTER ADRIFT: $p references neither AGENTS.md nor README.md — no longer routes into the boot chain" -ForegroundColor Yellow
        $issues++
    }
}

Write-Host "== Check 5: manifest leanness (cold-boot cost) ==" -ForegroundColor Cyan
# manifest.md is re-read on every cold boot and its own rule forbids becoming a changelog.
# A hard line budget mechanically enforces "keep it to current state only" — the drift that
# accreted three dated narrative blocks (2026-07-16 cold-boot finding).
$manifestBudget = 70
$mfPath = Join-Path $RepoRoot '_ORVION_CANONICAL/manifest.md'
if (Test-Path $mfPath) {
    $mfLines = @(Get-Content $mfPath).Count
    if ($mfLines -gt $manifestBudget) {
        Write-Host "  MANIFEST BLOAT: manifest.md is $mfLines lines (budget $manifestBudget) — trim changelog-style narrative; it holds current state only, pointing to reports for history" -ForegroundColor Yellow
        $issues++
    }
}

Write-Host "== Check 6: roadmap <-> manifest phase agreement ==" -ForegroundColor Cyan
# Verified failure class (2026-07-17): the roadmap and manifest can disagree on WHICH phase is
# current (INC-1: manifest = Phase 9, roadmap "Immediate Next Action" still said "Phase 8 is
# next"). Checks 1-5 could not see it. Invariant, deterministic + precise: the manifest's
# Current Phase number must equal the unique roadmap phase heading marked In Progress/CURRENT,
# and no roadmap prose may assert a DIFFERENT phase is "the current phase" / "is next".
$roadmapPath = Join-Path $RepoRoot '_ORVION_CANONICAL/32_execution_roadmap.md'
$manifestCur = $null
if (Test-Path $mfPath) {
    $m = [regex]::Match((Get-Content $mfPath -Raw), 'Current Phase:\s*\*\*\s*Phase\s+(?<n>\d+)')
    if ($m.Success) { $manifestCur = [int]$m.Groups['n'].Value }
}
if ($null -eq $manifestCur) {
    Write-Host "  UNREADABLE: manifest.md has no parseable 'Current Phase: **Phase N'" -ForegroundColor Yellow
    $issues++
} elseif (Test-Path $roadmapPath) {
    $headingPhase = $null
    $inProgress = @()   # phase numbers whose heading Status is In Progress/CURRENT
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($roadmapPath)) {
        $lineNo++
        $h = [regex]::Match($line, '^#\s+Phase\s+(?<n>\d+)\b')
        if ($h.Success) { $headingPhase = [int]$h.Groups['n'].Value; continue }
        if ($line -match '^Status:' -and $line -match 'In Progress|CURRENT phase') {
            if ($null -ne $headingPhase) { $inProgress += $headingPhase }
        }
        # inline assertion; the lookahead forbids crossing another "Phase N" token or a period,
        # so a lazy match can't span from an unrelated phase mention to a later "is current".
        foreach ($mm in [regex]::Matches($line, 'Phase\s+(?<n>\d+)\b(?:(?!Phase\s+\d+|[.\n]).)*?\bis (?:the current phase|next)\b')) {
            $x = [int]$mm.Groups['n'].Value
            if ($x -ne $manifestCur) {
                Write-Host "  PHASE DRIFT: roadmap line $lineNo asserts Phase $x is current/next, but manifest Current Phase is $manifestCur" -ForegroundColor Yellow
                $issues++
            }
        }
    }
    $uniq = $inProgress | Sort-Object -Unique
    if ($uniq.Count -eq 0) {
        Write-Host "  PHASE DRIFT: no roadmap phase heading is marked In Progress/CURRENT (manifest says Phase $manifestCur)" -ForegroundColor Yellow
        $issues++
    } elseif ($uniq.Count -gt 1) {
        Write-Host "  PHASE DRIFT: roadmap marks multiple phases In Progress ($($uniq -join ', ')); exactly one (Phase $manifestCur) must be" -ForegroundColor Yellow
        $issues++
    } elseif ($uniq[0] -ne $manifestCur) {
        Write-Host "  PHASE DRIFT: roadmap marks Phase $($uniq[0]) In Progress but manifest Current Phase is $manifestCur" -ForegroundColor Yellow
        $issues++
    }
}

Write-Host "== Check 7: ai-map freshness vs manifest ==" -ForegroundColor Cyan
# Verified failure class (2026-07-17, INC-2): ai-map.json's live_state COPIES the manifest but
# is regenerated only by repository-all.ps1, which is not in the doc-change DoD — so it drifted
# (generated_at a day behind HEAD). Dependency-free freshness: the manifest's Current Phase
# number and Last Completed SPEC id must both appear in ai-map's live_state. Skips cleanly if
# ai-map has been retired (owner-gated recommendation, 2026-07-17).
$aiMapPath = Join-Path $RepoRoot 'ai-map.json'
if ((Test-Path $aiMapPath) -and (Test-Path $mfPath)) {
    $mfRaw2 = Get-Content $mfPath -Raw
    $aiRaw  = Get-Content $aiMapPath -Raw
    $lastSpec = [regex]::Match($mfRaw2, 'Last Completed:\s*(?<s>SPEC-[0-9]+)')
    if ($null -ne $manifestCur -and $aiRaw -notmatch "Phase\s+$manifestCur\b") {
        Write-Host "  AI-MAP STALE: ai-map.json live_state does not name manifest Current Phase $manifestCur — regenerate (scripts/generate-ai-map.ps1)" -ForegroundColor Yellow
        $issues++
    }
    if ($lastSpec.Success -and $aiRaw -notmatch [regex]::Escape($lastSpec.Groups['s'].Value)) {
        Write-Host "  AI-MAP STALE: ai-map.json does not name manifest Last Completed $($lastSpec.Groups['s'].Value) — regenerate (scripts/generate-ai-map.ps1)" -ForegroundColor Yellow
        $issues++
    }
    # Verified failure class (2026-08-17): the two checks above key on the phase NUMBER and the
    # Last-Completed SPEC id — tokens that survive most edits — so ai-map's live_state.next_capability
    # drifted a full day out of date while this check reported CLEAN. A fresh agent reading the
    # machine-readable cold-start map would have executed a superseded Phase-8 objective (creating an
    # OAuth client that already existed). The next step is the single most action-guiding field in the
    # map, so compare its VALUE — extracted exactly as generate-ai-map.ps1 extracts it (the first line
    # of the manifest's "Next capability:" field). Whitespace is collapsed before comparison so
    # trivial reflowing does not cry wolf; any real change of intent fails loudly.
    $mfNext = [regex]::Match($mfRaw2, '(?m)^Next capability:\s*(?<v>.+?)\s*$')
    if ($mfNext.Success) {
        $aiNext = $null
        try { $aiNext = (ConvertFrom-Json $aiRaw).live_state.next_capability } catch { $aiNext = $null }
        $aiNextN = if ($null -eq $aiNext) { '' } else { ($aiNext -replace '\s+', ' ').Trim() }
        $mfNextN = ($mfNext.Groups['v'].Value -replace '\s+', ' ').Trim()
        if ($aiNextN -ne $mfNextN) {
            Write-Host "  AI-MAP STALE: ai-map.json live_state.next_capability does not match the manifest's current 'Next capability:' — a fresh agent would follow a superseded objective; regenerate (scripts/generate-ai-map.ps1)" -ForegroundColor Yellow
            $issues++
        }
    }
}

Write-Host "== Check 8: Supabase project-topology registry integrity ==" -ForegroundColor Cyan
# Verified failure class this guards against (2026-08-10): the dual-project topology record
# (MASTER_INTEGRATION_CATALOG.md §0) is the only thing standing between an agent and querying/
# writing to the wrong Supabase project, or treating the accidental/deleted projects as targets.
# This check cannot see live Supabase state (deliberately dependency-free/no credentials) — it
# only catches the registry itself going missing, losing a required ref, losing its disqualifying
# wording for the non-target refs, or contradicting the certification ledger's stated status.
$catalogPath = Join-Path $RepoRoot 'reports/master/MASTER_INTEGRATION_CATALOG.md'
$certPath = Join-Path $RepoRoot 'reports/master/MASTER_CERTIFICATION_STATUS.md'
$authorizedRefs = @('vrvtsxexkiiiivlkdxzp', 'brplkqmbzffpxqgkkdzo')
$nonTargetRefs = @{
    'hzyuczdlwalectfduehw' = 'DELETED'
    'wgsmrjcuhjdksfpdbhre' = 'not an ORVION target'
}
if (-not (Test-Path $catalogPath)) {
    Write-Host "  TOPOLOGY REGISTRY MISSING: reports/master/MASTER_INTEGRATION_CATALOG.md does not exist — no record of which Supabase projects are authorized" -ForegroundColor Yellow
    $issues++
} else {
    $catalogRaw = Get-Content $catalogPath -Raw
    foreach ($ref in $authorizedRefs) {
        if ($catalogRaw -notmatch [regex]::Escape($ref)) {
            Write-Host "  TOPOLOGY REGISTRY INCOMPLETE: authorized ref $ref is no longer recorded in MASTER_INTEGRATION_CATALOG.md §0" -ForegroundColor Yellow
            $issues++
        }
    }
    foreach ($ref in $nonTargetRefs.Keys) {
        if ($catalogRaw -notmatch [regex]::Escape($ref)) {
            Write-Host "  TOPOLOGY REGISTRY: non-target ref $ref is no longer recorded — its exclusion is no longer documented, a future session could mistake it for a valid target" -ForegroundColor Yellow
            $issues++
        } elseif ($catalogRaw -notmatch [regex]::Escape($nonTargetRefs[$ref])) {
            Write-Host "  TOPOLOGY REGISTRY WEAKENED: ref $ref is recorded but its disqualifying wording ('$($nonTargetRefs[$ref])') is missing" -ForegroundColor Yellow
            $issues++
        }
    }
    if ($catalogRaw -notmatch 'explicit, contemporaneous owner authorization') {
        Write-Host "  TOPOLOGY REGISTRY WEAKENED: the no-delete-without-explicit-owner-authorization rule for the two authorized projects is missing its exact wording" -ForegroundColor Yellow
        $issues++
    }
    # Cross-file contradiction (same pattern as Check 2): the certification ledger must not claim
    # CERTIFIED (synchronized) production-database status while the topology registry itself still
    # says a project is unverified/unreachable — that combination means one doc was updated and the
    # other wasn't, which is exactly the "only one project updated, INCOMPLETE" failure mode.
    if (Test-Path $certPath) {
        $certRaw = Get-Content $certPath -Raw
        $prodRow = [regex]::Match($certRaw, '\|\s*\*\*Production database deployment\*\*\s*\|(?<row>[^\n]*)\|')
        if ($prodRow.Success -and $prodRow.Groups['row'].Value -match 'CERTIFIED' -and $prodRow.Groups['row'].Value -notmatch 'CONDITIONAL') {
            # Deliberately narrow to \bunverified\b only — NOT a looser "not reachable" scan.
            # Legitimate prose about connector-scoping (e.g. "still not reachable through the
            # claude_ai_Supabase connector" while reachable via a different server) is expected
            # and must not cry wolf; "unverified" is the specific word this repo's convention
            # uses to mark a project's actual deployment status as unconfirmed.
            if ($catalogRaw -match '(?i)\bunverified\b') {
                Write-Host "  CROSS-FILE CONTRADICTION: MASTER_CERTIFICATION_STATUS.md claims production database deployment is CERTIFIED, but MASTER_INTEGRATION_CATALOG.md §0 still marks a project's status 'unverified' — one file was updated without the other" -ForegroundColor Yellow
                $issues++
            }
        }
    }
}

Write-Host ""
if ($issues -eq 0) {
    Write-Host "REPOSITORY CONSISTENCY: CLEAN" -ForegroundColor Green
    exit 0
} else {
    Write-Host "REPOSITORY CONSISTENCY: $issues issue(s) found" -ForegroundColor Red
    exit 1
}
