<#
.SYNOPSIS
  Repository consistency guard — permanent guard (GOVERNANCE.md §18 discovery-to-guard loop)
  for the drift class repaired in the 2026-07-15 Repository Recovery: broken document
  references in Living docs, and contradictory finding-status inside a Master register.

.DESCRIPTION
  Deterministic, dependency-free. Precision over recall — it must not cry wolf, or agents
  will learn to ignore it. Twelve checks (1–2 Living docs; 3 boot routers; 4 all reports; 5 manifest;
  6 roadmap↔manifest; 7 ai-map freshness; 8 dual-project Supabase topology registry;
  9 manifest migration state vs the actual migration files; 10 latest-session pointer currency;
  11 manifest decision IDs resolve in the findings SSOT; 12 no future-dated evidence):
    Check 1 broken references · Check 2 intra-register status contradiction ·
    Check 3 boot-chain router integrity + AI-pointer thinness · Check 4 report class-header presence ·
    Check 5 manifest leanness (cold-boot cost) · Check 6 roadmap↔manifest phase agreement ·
    Check 7 ai-map freshness vs manifest · Check 8 Supabase project-topology registry integrity ·
    Check 9 manifest migration count/latest/fingerprint vs supabase/migrations ·
    Check 10 reports/README "Latest session report" pointer is CURRENT (GOV-1) ·
    Check 11 every open-decision ID the manifest raises resolves in MASTER_GAP_REGISTER.md (GOV-3) ·
    Check 12 no current-state evidence is dated in the future, and the clock is sane (AUD-01).

  Checks 1, 10 and 11 are three different questions about a reference and none substitutes for
  another: does it RESOLVE (1), is it the CURRENT one (10), and does the ID the boot sequence is
  told to look up actually EXIST in the register that claims to define it (11). Check 12 asks the
  fourth: is the evidence even dated plausibly (a record dated tomorrow claims evidence that could
  not yet have been gathered, and sorts ahead of records that are genuinely newer).

  Check 2 compares status BOTH within a file and ACROSS every reports/master/*.md (AUD-04) -- the
  cross-file half exists because MASTER_REPOSITORY_HEALTH published "conflicting status across
  Masters = 0" while nothing had ever compared two Masters to each other.

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
# GOV-4 (2026-08-29): this pattern used to enumerate the 2026-07 prefixes literally --
# DC/R/A/B/N/CDD/BF/RC/OPS/INV -- so it matched NONE of the finding IDs minted since
# (SEC-, FIN-, ATTR-, CONV-, LEAD-, SCHED-, TRANS-, API-, PAR-, TEST-, GOV-, DOC-EXP-, ...).
# Check 2 was therefore structurally blind to every finding created in the last month while
# still printing a verdict, which is the "guard written against the first instance takes that
# instance's shape" class this repository keeps re-discovering. The generic alternative below
# matches any PREFIX-N / PREFIX-SUB-N / PREFIX-Nx id; the bare single-letter forms (R8, A3, B3,
# N1) keep their own alternatives because they carry no dash. Safe to widen because Check 2
# only ever treats an id as a row's SUBJECT when it leads a table row or a `###` heading.
$idPat = '\b([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[0-9]+[a-z]?|R[0-9]+|A[0-9]+|B[0-9]+|N[0-9]+)\b'

# AUD-04 (2026-08-29): `MASTER_REPOSITORY_HEALTH.md §3` published the indicator "Conflicting finding
# status across MASTERS = 0", but this check has only ever compared a file against ITSELF -- the
# hashtables below are rebuilt per file. The 0 was asserted, never measured, which is the exact
# "guard claims a property stronger than it measures" class the programme keeps finding. These two
# cross-file tables make the published indicator real: an id shown OPEN in one Master while another
# Master marks it resolved is now a reported contradiction.
$xOpen = @{}      # id -> "file:line" where some Master shows it OPEN
$xResolved = @{}  # id -> "file:line" where some Master marks it resolved

if (Test-Path $masterDir) {
    foreach ($md in Get-ChildItem $masterDir -Filter *.md -File) {
        $openAt = @{}      # id -> "line" where a table-row status cell is exactly OPEN
        $resolvedAt = @{}  # id -> "line" where the id is marked resolved
        $blockId = $null   # id of the `### <ID> — ...` detail block currently being read
        $lineNo = 0
        foreach ($line in [System.IO.File]::ReadAllLines($md.FullName)) {
            $lineNo++
            # Track which detail block we are inside. The register states a block's verdict on its
            # own `- **Status:** FIXED` field far more often than in the heading, and the check
            # previously read ONLY the heading -- so the row-vs-detail contradiction it was built
            # for (the DC-16 bug) was invisible in exactly the form the register actually writes.
            # Proven by a cross-line probe on 2026-08-29 that the heading-only version did not catch.
            $blockHead = [regex]::Match($line, '^###\s+(?<id>' + $idPat.Trim('\b') + ')')
            if ($line -match '^#{1,3}\s') { $blockId = $(if ($blockHead.Success) { $blockHead.Groups['id'].Value } else { $null }) }
            if ($blockId -and $line -match '^\s*-\s*\*\*Status:?\*\*.*\b(RESOLVED|FIXED|IMPLEMENTED|CLOSED)\b') {
                $resolvedAt[$blockId] = $lineNo
            }
            # OPEN only when it is a padded table cell: | OPEN | (kills prose false-positives)
            $rowOpen = $line -match '\|\s*OPEN\s*\|'
            # The resolved marker must LEAD a table cell, not merely appear somewhere on the line.
            # Found when GOV-4 widened $idPat above: AUDIT-2 is legitimately OPEN, and its title cell
            # says "(`subscription_plans` itself resolved by SPEC-120)" -- prose about a DIFFERENT
            # object. A whole-line match (PowerShell -match is case-insensitive) read that as the
            # row's own status and reported a contradiction with itself. Cell-anchoring keeps the
            # precision this script's header demands, since every real status cell leads with the
            # marker (`✅RESOLVED (SPEC-117)`, `**RESOLVED 2026-08-24 ...**`, `✅IMPLEMENTED ...`).
            # `###` detail-block headings keep the loose match: they are prose, not cells.
            if ($line -match '^###\s') {
                $rowResolved = $line -match '✅|\bRESOLVED\b|\bIMPLEMENTED\b'
            } else {
                $rowResolved = $false
                foreach ($cell in ($line -split '\|')) {
                    if ($cell.Trim() -match '^(\*\*)?\s*(✅|RESOLVED\b|IMPLEMENTED\b)') { $rowResolved = $true; break }
                }
            }
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
                if ($rowOpen)     { $openAt[$id]     = $lineNo; if (-not $xOpen.ContainsKey($id))     { $xOpen[$id]     = "$($md.Name):$lineNo" } }
                if ($rowResolved) { $resolvedAt[$id] = $lineNo; if (-not $xResolved.ContainsKey($id)) { $xResolved[$id] = "$($md.Name):$lineNo" } }
            }
        }
        foreach ($id in $openAt.Keys) {
            if ($resolvedAt.ContainsKey($id)) {
                Write-Host "  STATUS CONTRADICTION: $($md.Name): $id OPEN at line $($openAt[$id]) but resolved at line $($resolvedAt[$id])" -ForegroundColor Yellow
                $issues++
            }
        }
    }
    # AUD-04: the cross-file pass. Only ids whose two verdicts live in DIFFERENT Masters are reported
    # here -- same-file contradictions were already reported above and must not be counted twice.
    $xConflicts = 0
    foreach ($id in $xOpen.Keys) {
        if ($xResolved.ContainsKey($id)) {
            $a = $xOpen[$id]; $b = $xResolved[$id]
            if (($a -split ':')[0] -ne ($b -split ':')[0]) {
                Write-Host "  CROSS-MASTER STATUS CONTRADICTION: $id is OPEN in $a but resolved in $b" -ForegroundColor Yellow
                $issues++; $xConflicts++
            }
        }
    }
    if ($xConflicts -eq 0) {
        Write-Host "  cross-Master status agreement measured over $($xOpen.Count) open id(s) -- no contradiction" -ForegroundColor Green
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
#
# GUARD-DESIGN FIX (2026-08-21 remediation pass): the line budget alone was a proxy that its own
# invariant could walk straight past. At the time of the fix manifest.md passed this check at 60
# lines while being 13,556 characters, because a single "Current Module" line had grown to 5,609
# characters narrating three separate sessions of corrections — exactly the changelog the rule
# forbids. Cold-boot cost is paid in characters (tokens), not in newlines, so the budget is now
# enforced on BOTH axes, plus a per-line ceiling that catches the specific shape that defeated it:
# one enormous paragraph. A guard that can be satisfied without satisfying its invariant is the
# failure class the discovery-to-guard loop exists to eliminate (GOVERNANCE.md §18).
$manifestBudget = 70
$manifestCharBudget = 7000
$manifestLineCharBudget = 1200
$mfPath = Join-Path $RepoRoot '_ORVION_CANONICAL/manifest.md'
if (Test-Path $mfPath) {
    $mfContent = @(Get-Content $mfPath)
    $mfLines = $mfContent.Count
    $mfChars = (Get-Content $mfPath -Raw).Length
    if ($mfLines -gt $manifestBudget) {
        Write-Host "  MANIFEST BLOAT: manifest.md is $mfLines lines (budget $manifestBudget) — trim changelog-style narrative; it holds current state only, pointing to reports for history" -ForegroundColor Yellow
        $issues++
    }
    if ($mfChars -gt $manifestCharBudget) {
        Write-Host "  MANIFEST BLOAT: manifest.md is $mfChars characters (budget $manifestCharBudget) — cold-boot cost is paid in characters, not lines; move history to reports/ and git log" -ForegroundColor Yellow
        $issues++
    }
    $mfLongest = ($mfContent | Measure-Object -Property Length -Maximum).Maximum
    if ($mfLongest -gt $manifestLineCharBudget) {
        $mfLongestNo = ($mfContent | Select-String -Pattern '.{1201,}' | Select-Object -First 1).LineNumber
        Write-Host "  MANIFEST BLOAT: manifest.md line $mfLongestNo is $mfLongest characters (budget $manifestLineCharBudget) — a single field has become a changelog; state current state and link the history" -ForegroundColor Yellow
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
    # Extended 2026-08-17 to the WHOLE multi-step block, not just its headline: the steps that
    # qualify the objective (verify-tools-first, read the mandatory §2a corrections, read the
    # built workflow back) are the load-bearing part, and a map carrying only line 1 would drop
    # exactly the guardrails that the preceding Phase-8 failures produced. TERMINATOR SET IS
    # DUPLICATED, DELIBERATELY, from Get-Block in scripts/generate-ai-map.ps1 -- change both
    # together. Divergence surfaces immediately here as a loud mismatch, never as silent drift.
    $terminators = '---|#\s|Prior phases\b|Current Phase:|Current Module:|Active Change Request:|Last Completed:|Context & remaining'
    $mfNext = [regex]::Match($mfRaw2, "(?ms)^Next capability:\s*(?<v>.*?)(?=\r?\n(?:$terminators)|\z)")
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
    # CERTIFIED production-database status while the topology registry itself still says a project
    # is unverified/unreachable — that combination means one doc was updated and the other wasn't.
    # NOTE (2026-08-20): Primary and Secondary are permanently independent environments and are NOT
    # synchronized; certification is per-project and no cross-project claim is made. This check is
    # therefore about DOC-vs-DOC staleness only. It does NOT check parity between the two projects
    # and must never be extended to do so (MASTER_INTEGRATION_CATALOG.md §0 rule 15).
    if (Test-Path $certPath) {
        $certRaw = Get-Content $certPath -Raw
        $prodRow = [regex]::Match($certRaw, '\|\s*\*\*Production database deployment\*\*\s*\|(?<row>[^\n]*)\|')
        if ($prodRow.Success -and $prodRow.Groups['row'].Value -match 'CERTIFIED' -and $prodRow.Groups['row'].Value -notmatch 'CONDITIONAL') {
            # Deliberately narrow to \bunverified\b only — NOT a looser "not reachable" scan.
            # Legitimate prose about connector-scoping (e.g. "still not reachable through the
            # claude_ai_Supabase connector" while reachable via a different server) is expected
            # and must not cry wolf; "unverified" is the specific word this repo's convention
            # uses to mark a project's actual deployment status as unconfirmed.
            #
            # PRECISION FIX (2026-08-21 remediation pass): this scan is now scoped to §0, which is
            # what its own failure message has always claimed ("MASTER_INTEGRATION_CATALOG.md §0
            # still marks..."). It previously scanned the WHOLE file, so it fired on the word
            # "unverified" wherever it appeared — including §4's n8n *credential* evidentiary
            # boundary ("each credential's target ... remain unverified"), which says nothing about
            # any Supabase project's deployment status. That is a false positive of exactly the
            # cry-wolf kind the narrow-word choice above was made to avoid, and the correct fix is
            # to scope the scan rather than to reword honest documentation to dodge the check.
            $sec0 = [regex]::Match($catalogRaw, '(?ms)^##\s*0\.\s.*?(?=^##\s)')
            $sec0Text = if ($sec0.Success) { $sec0.Value } else { $catalogRaw }
            if ($sec0Text -match '(?i)\bunverified\b') {
                Write-Host "  CROSS-FILE CONTRADICTION: MASTER_CERTIFICATION_STATUS.md claims production database deployment is CERTIFIED, but MASTER_INTEGRATION_CATALOG.md §0 still marks a project's status 'unverified' — one file was updated without the other" -ForegroundColor Yellow
                $issues++
            }
        }
    }
}

Write-Host "== Check 9: manifest migration state vs actual repository ==" -ForegroundColor Cyan
# Verified failure class (2026-08-24/25): the manifest asserted "112 migrations (latest
# `202607052300`)" and a stale ledger fingerprint while the repository actually held 118 (latest
# `202607052900`), and it asserted Primary was "15 BEHIND" when the real gap was 16. Checks 1-8 all
# reported CLEAN throughout: check 5 measures the manifest's SIZE, not the truth of its claims, and
# nothing else compares a manifest number to a countable fact. A cold-booting agent reads this line
# as current state, so a wrong count sends it to the wrong baseline.
#
# This is mechanically checkable with no database and no network. The ledger fingerprint the
# manifest quotes is md5 of the comma-joined `version_name` list ordered by version -- which is
# exactly the migration filenames minus their extension. So all three claims (count, latest
# version, fingerprint) are derivable from `supabase/migrations/` alone, and any of them drifting
# from the files is a fact-level contradiction rather than a matter of judgement.
$migDir = Join-Path $RepoRoot 'supabase/migrations'
if (-not (Test-Path $migDir)) {
    Write-Host "  UNREADABLE: supabase/migrations not found" -ForegroundColor Yellow
    $issues++
} elseif (-not (Test-Path $mfPath)) {
    Write-Host "  UNREADABLE: manifest.md not found" -ForegroundColor Yellow
    $issues++
} else {
    $migNames = Get-ChildItem -Path $migDir -Filter '*.sql' -File |
                ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) } |
                Sort-Object -CaseSensitive
    $actualCount  = $migNames.Count
    $actualLatest = if ($actualCount -gt 0) { ($migNames[-1] -split '_', 2)[0] } else { '' }
    $md5          = [System.Security.Cryptography.MD5]::Create()
    $actualPrint  = ([BitConverter]::ToString(
                        $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes(($migNames -join ',')))
                     ) -replace '-', '').ToLower()

    # Scoped to the "Live state:" line, which is where the manifest makes these claims.
    $liveLine = [regex]::Match((Get-Content $mfPath -Raw), '(?m)^Live state:.*$')
    if (-not $liveLine.Success) {
        Write-Host "  UNREADABLE: manifest.md has no 'Live state:' line to verify" -ForegroundColor Yellow
        $issues++
    } else {
        $lv = $liveLine.Value

        $mCount = [regex]::Match($lv, '(?<n>\d{2,5})\s+migrations')
        if (-not $mCount.Success) {
            Write-Host "  UNREADABLE: manifest 'Live state:' states no migration count" -ForegroundColor Yellow
            $issues++
        } elseif ([int]$mCount.Groups['n'].Value -ne $actualCount) {
            Write-Host "  MIGRATION STATE DRIFT: manifest says $($mCount.Groups['n'].Value) migrations, repository holds $actualCount" -ForegroundColor Yellow
            $issues++
        }

        $mLatest = [regex]::Match($lv, 'latest\s+`(?<v>\d{9,14})')
        if (-not $mLatest.Success) {
            Write-Host "  UNREADABLE: manifest 'Live state:' names no latest migration version" -ForegroundColor Yellow
            $issues++
        } elseif ($mLatest.Groups['v'].Value -ne $actualLatest) {
            Write-Host "  MIGRATION STATE DRIFT: manifest says latest migration is $($mLatest.Groups['v'].Value), repository's latest is $actualLatest" -ForegroundColor Yellow
            $issues++
        }

        $mPrint = [regex]::Match($lv, '(?<h>\b[0-9a-f]{32}\b)')
        if ($mPrint.Success -and $mPrint.Groups['h'].Value -ne $actualPrint) {
            Write-Host "  MIGRATION STATE DRIFT: manifest asserts ledger fingerprint $($mPrint.Groups['h'].Value), but the migration files produce $actualPrint" -ForegroundColor Yellow
            $issues++
        }
    }
}

# 10. GOV-1: the README's Latest-session pointer must be CURRENT. The README states its own rule --
#     "an unlinked report is invisible to the boot sequence, which is the one job this pointer has" --
#     and nothing checked it, so on 2026-08-29 the pointer was found FIVE reports stale. Check 1
#     verifies that references RESOLVE, which is a different question from whether they are current.
#     The manifest's `Narrative:` field is updated every package by construction, so the two must
#     name the same file; disagreement means one of them was forgotten.
Write-Host "== Check 10: latest-session pointer is current ==" -ForegroundColor Cyan
$manifestText = Get-Content (Join-Path $RepoRoot '_ORVION_CANONICAL/manifest.md') -Raw
$readmeText   = Get-Content (Join-Path $RepoRoot 'reports/README.md') -Raw
$mNarr = [regex]::Match($manifestText, 'Narrative:\s*`([^`]+\.md)`')
$mPtr  = [regex]::Match($readmeText,   'Latest session report:\*\*\s*`(?:history/)?([^`]+\.md)`')
if (-not $mNarr.Success) {
    Write-Host "  MANIFEST has no 'Narrative: <file>.md' field -- cannot verify the pointer" -ForegroundColor Red
    $issues++
} elseif (-not $mPtr.Success) {
    Write-Host "  README has no 'Latest session report: <file>.md' pointer" -ForegroundColor Red
    $issues++
} else {
    $narr = $mNarr.Groups[1].Value.Trim()
    $ptr  = $mPtr.Groups[1].Value.Trim()
    if ($narr -ne $ptr) {
        Write-Host "  STALE POINTER: README names '$ptr' but the manifest's narrative is '$narr'" -ForegroundColor Red
        Write-Host "  Remedy: update the 'Latest session report' row in reports/README.md in this same commit." -ForegroundColor DarkGray
        $issues++
    } elseif (-not (Test-Path (Join-Path $RepoRoot "reports/history/$ptr"))) {
        Write-Host "  POINTER TARGET MISSING: reports/history/$ptr does not exist" -ForegroundColor Red
        $issues++
    } else {
        Write-Host "  README and manifest both name $ptr" -ForegroundColor Green
    }
}

# 11. GOV-3: the manifest lists its open owner decisions as IDs ONLY, and states that "every
#     definition, its evidence and its status live in MASTER_GAP_REGISTER.md". On 2026-08-29 that
#     promise was false for five of twenty-five ids -- A3, BLOCKED-4, BLOCKED-5, CANON-26-1 and
#     LIC-1 appeared in NO register row, so a fresh agent following the boot sequence to look one
#     up reached a dead end in the governance chain. GOVERNANCE.md section 2 makes the register the
#     SSOT for accepted findings and requires every other Master to reference an ID rather than
#     restate the finding; an id the manifest raises that the register does not define is that rule
#     broken in the one direction the boot sequence actually walks. Check 1 cannot see this: these
#     are finding IDs, not document filenames.
Write-Host "== Check 11: manifest open-decision IDs resolve in the gap register ==" -ForegroundColor Cyan
$manifestRaw = Get-Content (Join-Path $RepoRoot '_ORVION_CANONICAL/manifest.md') -Raw
$registerRaw = Get-Content (Join-Path $RepoRoot 'reports/master/MASTER_GAP_REGISTER.md') -Raw
$decLine = ($manifestRaw -split "`n" | Where-Object { $_ -match 'Open owner decisions' } | Select-Object -First 1)
if (-not $decLine) {
    Write-Host "  MANIFEST has no 'Open owner decisions' line -- cannot verify" -ForegroundColor Red
    $issues++
} else {
    # Same id shape as Check 2, plus the bare A<n> form. Deliberately applied to the WHOLE line,
    # resolved ids included: an id the manifest calls resolved must still be findable, because the
    # register is where its evidence lives.
    $found = [regex]::Matches($decLine, '\b([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[0-9]+[a-z]?|A[0-9]+)\b') |
             ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $orphans = @($found | Where-Object { $registerRaw -notmatch ('(?m)\b' + [regex]::Escape($_) + '\b') })
    if ($orphans.Count -gt 0) {
        foreach ($o in $orphans) {
            Write-Host "  ORPHAN ID: manifest raises '$o' but MASTER_GAP_REGISTER.md defines no such finding" -ForegroundColor Red
        }
        Write-Host "  Remedy: add the row to MASTER_GAP_REGISTER.md (a pointer row is fine when another" -ForegroundColor DarkGray
        Write-Host "  document legitimately owns it), or stop raising the id in the manifest." -ForegroundColor DarkGray
        $issues += $orphans.Count
    } else {
        Write-Host "  all $($found.Count) manifest decision IDs resolve in the register" -ForegroundColor Green
    }
}

# 12. AUD-01: CURRENT-STATE EVIDENCE MUST NOT BE DATED IN THE FUTURE.
#     On 2026-08-29 an entire reconciliation was stamped ONE DAY AHEAD across 13 files and 43 places
#     -- register rows, a GOVERNANCE version bump, a session report's filename and Date field --
#     while the commit carrying them was authored that same 2026-08-29. The date had been ASSUMED
#     ("this feels like a new session") rather than read from the clock, and nothing checked it. A
#     future-dated record is worse than a stale one: it claims evidence that could not yet have been
#     gathered, and it sorts ahead of records that are actually newer.
#     NOTE: this check has NO exemption list, deliberately. It flagged its own explanatory comment on
#     the first run, because that comment quoted the offending date literally. The fix was to stop
#     writing the future date in prose -- describe it ("one day ahead") instead. An exemption
#     mechanism would have been the weaker answer: every exemption is a place the next future date
#     can hide.
#     Two questions, because either alone can be fooled: (a) does any file carry a date later than
#     today, and (b) is the clock itself plausible, cross-checked against the newest commit.
Write-Host "== Check 12: no future-dated evidence ==" -ForegroundColor Cyan
$today = (Get-Date).Date
$dateRx = '\b(20[0-9]{2}-[01][0-9]-[0-3][0-9])\b'
$futureHits = 0
$scan = $allFiles | Where-Object { $_.Extension -in '.md', '.json', '.ps1', '.sql' }
foreach ($f in $scan) {
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
        $lineNo++
        foreach ($m in [regex]::Matches($line, $dateRx)) {
            $d = [datetime]::MinValue
            if ([datetime]::TryParseExact($m.Groups[1].Value, 'yyyy-MM-dd', $null, 'None', [ref]$d) -and $d -gt $today) {
                $rel = $f.FullName.Substring($RepoRoot.Length + 1)
                Write-Host "  FUTURE-DATED: $rel : $lineNo -> $($m.Groups[1].Value) (today is $($today.ToString('yyyy-MM-dd')))" -ForegroundColor Red
                $futureHits++
            }
        }
    }
}
if ($futureHits -gt 0) {
    Write-Host "  Remedy: read the clock (`Get-Date`) and restamp. Never infer today's date from how the session feels." -ForegroundColor DarkGray
    $issues += $futureHits
}
# Clock sanity: a commit cannot have been authored after 'now'. If one was, the clock is wrong and
# every date written this session is suspect -- including any this check just passed.
$newestCommit = (& git -C $RepoRoot log -1 --format=%aI 2>$null)
if ($newestCommit) {
    $cd = [datetimeoffset]::Parse($newestCommit)
    if ($cd -gt [datetimeoffset]::Now.AddMinutes(5)) {
        Write-Host "  CLOCK SKEW: newest commit is authored $($cd.ToString('u')) but 'now' is $([datetimeoffset]::Now.ToString('u'))" -ForegroundColor Red
        Write-Host "  Every date written this session is suspect. Fix the clock before recording evidence." -ForegroundColor DarkGray
        $issues++
    } elseif ($futureHits -eq 0) {
        Write-Host "  no future-dated evidence; clock agrees with the newest commit ($($cd.ToString('yyyy-MM-dd')))" -ForegroundColor Green
    }
}

Write-Host ""
if ($issues -eq 0) {
    Write-Host "REPOSITORY CONSISTENCY: CLEAN" -ForegroundColor Green
    # Scope disclaimer, added after the 2026-08-26 incident in which this script printed CLEAN while
    # the local database sat 29 migrations behind the repository. Every check above reads FILES; none
    # opens a database. Stating that here is what stops a CLEAN result from being quoted as evidence
    # of live parity -- which is exactly how the drift survived.
    Write-Host "  (scope: repository files only -- no database was queried." -ForegroundColor DarkGray
    Write-Host "   For live parity run scripts/check_database_parity.ps1)" -ForegroundColor DarkGray
    exit 0
} else {
    Write-Host "REPOSITORY CONSISTENCY: $issues issue(s) found" -ForegroundColor Red
    exit 1
}
