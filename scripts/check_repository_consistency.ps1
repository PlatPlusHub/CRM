<#
.SYNOPSIS
  Repository consistency guard — permanent guard (GOVERNANCE.md §18 discovery-to-guard loop)
  for the drift class repaired in the 2026-07-15 Repository Recovery: broken document
  references in Living docs, and contradictory finding-status inside a Master register.

.DESCRIPTION
  Deterministic, dependency-free. Precision over recall — it must not cry wolf, or agents
  will learn to ignore it. Seventeen checks (1–2 Living docs; 3 boot routers; 4 all reports; 5 manifest;
  6 roadmap↔manifest; 7 ai-map freshness; 8 dual-project Supabase topology registry;
  9 manifest migration state vs the actual migration files; 10 latest-session pointer currency;
  11 manifest decision IDs resolve in the findings SSOT; 12 no future-dated evidence;
  13 no Master table row escaped out of its own table; 14 no manifest owner-decision id is already
  decided; 15 manifest suite/endpoint figures match the repository; 16–17 canon carries neither a
  settled decision presented as a current blocker nor a generated count copied out of its owner):
    Check 1 broken references · Check 2 intra-register status contradiction ·
    Check 3 boot-chain router integrity + AI-pointer thinness · Check 4 report class-header presence ·
    Check 5 manifest leanness (cold-boot cost) · Check 6 roadmap↔manifest phase agreement ·
    Check 7 ai-map freshness vs manifest — all four live_state fields (phase; and
      active_change_request / last_completed / next_capability compared BY VALUE) ·
    Check 8 Supabase project-topology registry integrity ·
    Check 9 manifest migration count/latest/fingerprint vs supabase/migrations ·
    Check 10 reports/README "Latest session report" pointer is CURRENT (GOV-1) ·
    Check 11 every open-decision ID the manifest raises resolves in MASTER_GAP_REGISTER.md (GOV-3) ·
    Check 12 no current-state evidence is dated in the future, and the clock is sane (AUD-01) ·
    Check 13 no reports/master table row is escaped out of its own table, and out of Check 2 (REG-1) ·
    Check 14 no id on the manifest's open-decision line is already marked decided in the register (OWNER-1) ·
    Check 15 the manifest's suite and endpoint figures match the test files and the generated contract (META-1) ·
    Check 16 no canonical document names a settled finding as a CURRENT owner decision, judged against
      the manifest's own open-decision line (the cold-start contradiction of 2026-09-01) ·
    Check 17 no canonical document restates the RPC-endpoint count that MASTER_API_CONTRACT.md generates (REG-2).

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
# (generated_at a day behind HEAD). Dependency-free freshness: the manifest's Current Phase number
# must appear in ai-map's live_state, and its `Last Completed` and `Next capability` fields must
# match ai-map's copies BY VALUE. Skips cleanly if ai-map has been retired (owner-gated
# recommendation, 2026-07-17).
$aiMapPath = Join-Path $RepoRoot 'ai-map.json'
if ((Test-Path $aiMapPath) -and (Test-Path $mfPath)) {
    $mfRaw2 = Get-Content $mfPath -Raw
    $aiRaw  = Get-Content $aiMapPath -Raw
    if ($null -ne $manifestCur -and $aiRaw -notmatch "Phase\s+$manifestCur\b") {
        Write-Host "  AI-MAP STALE: ai-map.json live_state does not name manifest Current Phase $manifestCur — regenerate (scripts/generate-ai-map.ps1)" -ForegroundColor Yellow
        $issues++
    }
    # EXTENDED 2026-09-02 (GOV-10). `Active Change Request` is the fourth live_state field the
    # generator extracts, and it was the ONLY one nothing compared. Check 7's coverage had been
    # decided field by field -- phase (2026-07-17), next_capability (2026-08-17), last_completed
    # (2026-09-01) -- each added the day its own drift shipped, so the field nobody had yet been
    # burned by stayed unguarded while the check's name ("ai-map freshness") promised the block.
    #
    # This is the load-bearing field of the cold-start handoff, not an incidental one: `AGENTS.md
    # §4` step 4 branches the ENTIRE boot sequence on it (not `None` -> open that SPEC and let its
    # Minimum Reading List take over; `None` -> fall through to the roadmap), and `AGENTS.md §6`
    # plus `CR_LIFECYCLE.md §9` make it the only handoff channel between sessions. It is written by
    # `Approve SPEC-NNN` and cleared by `Complete SPEC-NNN`, and that clear has been FORGOTTEN
    # twice already (SPEC-024, SPEC-027 -- `reports/future-backlog.md` still carries the safeguard
    # entry), so the forgetting history is demonstrated rather than hypothetical. A stale
    # `changes/SPEC-NNN.md` in the map sends a cold-starting agent into a closed Change Request; a
    # stale `None.` hides an open one and the agent silently starts different work.
    #
    # Extracted and normalised by EXACTLY the contract the `Last Completed` comparison below
    # established -- generate-ai-map.ps1's Get-Field shape (single line, trimmed), whitespace
    # collapsed so reflowing cannot cry wolf while a real change of value fails loudly. No new
    # mechanism, no SPEC-id list, and no other ai-map key is brought under comparison by this.
    # RESIDUAL, stated rather than hidden: like both comparisons below, this one is silent if the
    # manifest loses the field entirely -- it measures DISAGREEMENT, never presence.
    $mfAcr = [regex]::Match($mfRaw2, '(?m)^Active Change Request:\s*(?<v>.+?)\s*$')
    if ($mfAcr.Success) {
        $aiAcr = $null
        try { $aiAcr = (ConvertFrom-Json $aiRaw).live_state.active_change_request } catch { $aiAcr = $null }
        $aiAcrN = if ($null -eq $aiAcr) { '' } else { ($aiAcr -replace '\s+', ' ').Trim() }
        $mfAcrN = ($mfAcr.Groups['v'].Value -replace '\s+', ' ').Trim()
        if ($aiAcrN -ne $mfAcrN) {
            Write-Host "  AI-MAP STALE: ai-map.json live_state.active_change_request is '$aiAcrN' but the manifest's 'Active Change Request:' is '$mfAcrN' — the cold-start handoff pointer disagrees with its own SSOT; regenerate (scripts/generate-ai-map.ps1)" -ForegroundColor Yellow
            $issues++
        }
    }
    # REPAIRED 2026-09-01. This comparison used to key on `Last Completed:\s*SPEC-[0-9]+`, so it ran
    # ONLY while that field began with a literal SPEC id and did nothing whatsoever otherwise. The
    # field stopped naming a SPEC id at 45a9463 (2026-08-27, WP-04-A), leaving the comparison INERT
    # for roughly forty commits — and the drift it exists to catch then shipped in 302c7cb, where
    # ai-map still described the finance-periphery package while the manifest had moved on to the
    # cold-start guard. A guard keyed on the SHAPE of the value it checks stops guarding the moment
    # that shape changes: the same class as GOV-4 (Check 2's id pattern, blind to every id minted
    # after it was written) and MEAS-4 (an actor predicate that was really a question about a name).
    # It was found by a post-fix reconciliation regenerating the artifact and diffing it, NOT by the
    # guard — which is the whole reason this now compares a value instead of matching a token.
    #
    # Compared BY VALUE, extracted exactly as scripts/generate-ai-map.ps1's Get-Field extracts it
    # (single line, trimmed) so the guard and the generator read the same thing by construction.
    # Whitespace is collapsed for the reason the next_capability comparison below collapses it:
    # reflowing must not cry wolf, a real change of content must fail loudly. Scope is deliberately
    # this ONE field — no other ai-map key is brought under comparison by this repair.
    $mfLast = [regex]::Match($mfRaw2, '(?m)^Last Completed:\s*(?<v>.+?)\s*$')
    if ($mfLast.Success) {
        $aiLast = $null
        try { $aiLast = (ConvertFrom-Json $aiRaw).live_state.last_completed } catch { $aiLast = $null }
        $aiLastN = if ($null -eq $aiLast) { '' } else { ($aiLast -replace '\s+', ' ').Trim() }
        $mfLastN = ($mfLast.Groups['v'].Value -replace '\s+', ' ').Trim()
        if ($aiLastN -ne $mfLastN) {
            Write-Host "  AI-MAP STALE: ai-map.json live_state.last_completed does not match the manifest's current 'Last Completed:' — a fresh agent would be told the wrong work finished last; regenerate (scripts/generate-ai-map.ps1)" -ForegroundColor Yellow
            $issues++
        }
    }
    # Verified failure class (2026-08-17): AS THIS CHECK STOOD IN 2026-08-08, the comparisons above it
    # keyed on the phase NUMBER and the Last-Completed SPEC id — tokens that survive most edits — so
    # ai-map's live_state.next_capability
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

    # MEAS-2 (2026-09-01): this used to test `$registerRaw -notmatch '\bID\b'` -- a match ANYWHERE in
    # a thousand lines of prose, including a cross-reference inside a DIFFERENT finding's row. PP-1
    # passed that test for weeks while having no row, no detail block, no status and no evidence:
    # it resolved solely because DOC-2's row ends "New: **PP-1**, **PP-2**". The check reported
    # "defines no such finding" while measuring "the string appears somewhere", which is the same
    # class as PAR-3, SEC-1b, VER-1 and REG-1 -- a guard whose description outruns its measurement.
    #
    # A finding is DEFINED where it is the SUBJECT of a register entry: the first cell of a table
    # row, or a `###` detail heading. Sibling ids sharing one cell ("SPP-1/SPP-2", "DC-1/R7") are
    # legitimate definitions, so the leading cell is split on '/'.
    $subjects = @{}
    foreach ($line in ($registerRaw -split "`n")) {
        $m = [regex]::Match($line, '^\|\s*([A-Z][A-Za-z0-9\-/\.\s]*?)\s*\|')
        if (-not $m.Success) { $m = [regex]::Match($line, '^###\s+([A-Z][A-Za-z0-9\-/\.\s]*?)\s+[-—]') }
        if ($m.Success) {
            foreach ($piece in ($m.Groups[1].Value -split '/')) {
                $p = $piece.Trim(); if ($p) { $subjects[$p] = $true }
            }
        }
    }
    $orphans = @($found | Where-Object { -not $subjects.ContainsKey($_) })
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
Write-Host "== Check 14: no manifest owner-decision ID is already decided in the register ==" -ForegroundColor Cyan
# OWNER-1 (2026-09-01). Check 11 proves the id RESOLVES; it never asks whether the thing it resolves
# to is still OPEN. On 2026-09-01 the manifest listed EIGHTEEN decisions the owner had already made,
# so a cold-start session would have read settled questions as live blockers -- the highest-value
# cold-start failure there is, because it manufactures work that does not exist and invites
# re-escalation of a decision the owner already gave. The same "restated moving list goes stale"
# shape had by then bitten canon 32 twice and the execution plan once.
#
# The resolved-set is DERIVED from the register's own status cells (same cell-anchored markers
# Check 2 uses), never from a list maintained here -- an exemption list would be one more thing to
# go stale, which is the defect this check exists to catch.
$decidedInRegister = @{}
$regLines = Get-Content (Join-Path $masterDir 'MASTER_GAP_REGISTER.md')
foreach ($line in $regLines) {
    $lead = [regex]::Match($line, '^\|\s*([A-Z][A-Za-z0-9\-/\.]*)\s*\|')
    if (-not $lead.Success) { continue }
    $cells = $line -split '(?<!\\)\|'
    if ($cells.Count -le 9) { continue }
    $status = $cells[9].Trim()
    # Cell-anchored, as in Check 2: the marker must LEAD the status, not merely appear in prose
    # about some other object. "RESOLVED 2026-.." and "✅ FIXED .." lead; "...revisit if" does not.
    if ($status -match '^(\*\*)?\s*(✅|RESOLVED\b|FIXED\b|IMPLEMENTED\b|CLOSED\b|DECIDED\b|PROVEN (NOT A DEFECT|INTENTIONAL)\b)') {
        foreach ($piece in ($lead.Groups[1].Value -split '/')) {
            $p = $piece.Trim(); if ($p) { $decidedInRegister[$p] = $status }
        }
    }
}
$staleDecisions = 0
if ($decLine) {
    # Only the ENUMERATION is the list of open decisions. The line legitimately also cites the
    # register row that explains a reconciliation, and a citation is not a blocker -- reading it as
    # one is how this check first reported its own evidence row as stale. The manifest marks the
    # boundary with "Genuinely open:"; everything before it is prose about the list, not the list.
    $enumeration = $decLine
    $cut = $decLine.IndexOf('Genuinely open:')
    if ($cut -ge 0) { $enumeration = $decLine.Substring($cut) }
    $manifestIds = [regex]::Matches($enumeration, '\b([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[0-9]+[a-z]?|A[0-9]+)\b') |
                   ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($id in $manifestIds) {
        if ($decidedInRegister.ContainsKey($id)) {
            $s = $decidedInRegister[$id]
            Write-Host "  STALE OWNER DECISION: manifest lists '$id' as open, but the register marks it $($s.Substring(0,[Math]::Min(60,$s.Length)))" -ForegroundColor Yellow
            $staleDecisions++
        }
    }
}
if ($staleDecisions -gt 0) {
    Write-Host "  Remedy: remove the id from the manifest's 'Open owner decisions' line. A decided item is an" -ForegroundColor DarkGray
    Write-Host "  ENGINEERING task, not an open question, and listing it as blocked invents work." -ForegroundColor DarkGray
    $issues += $staleDecisions
} else {
    Write-Host "  every manifest owner-decision ID is still open in the register" -ForegroundColor Green
}

Write-Host ""
Write-Host "== Check 15: manifest suite/endpoint figures match what the repository actually holds ==" -ForegroundColor Cyan
# META-1 (2026-09-01). A 14-mutation battery against this guard found nine caught and FIVE missed,
# and the five were one coherent blind spot: the manifest publishes current-state FIGURES that
# nothing verified. Check 9 already covers the migration count, latest filename and ledger
# fingerprint; the suite and endpoint counts had no owner at all, so "86 files / 1154 assertions"
# could drift to any value and stay CLEAN. That is the COLD-1 class in numeric form -- a restated
# current-state fact with no source-of-truth relationship -- and a cold-start session reads those
# figures as the size of the safety net it is inheriting.
#
# All three are DERIVED here, never listed: the file count and the assertion total come from the
# test files themselves (every file carries a literal `select plan(N)`; verified 86 files summing to
# 1154, matching the pgTAP run exactly), and the endpoint count comes from the GENERATED API
# contract, which `check_database_parity.ps1` Check L3 already regenerates and diffs against the
# live database. So the manifest is compared to the repository, and the contract to the database.
#
# Two of the five misses are deliberately NOT mechanised here, with reasons rather than silence:
#   * the HTTP assertion total requires RUNNING the six suites -- it is LOCAL RUNTIME evidence and
#     a file-only guard must not claim it (the evidence-class rule in AGENTS.md 5a);
#   * "75 tables" is the smoke test's assertion and is a DIFFERENT measurement from the contract's
#     count of tenant-reachable tables. Comparing them would create a false failure, which is worse
#     than an unguarded number.
$mfRaw = Get-Content $mfPath -Raw
$figureIssues = 0

$testFiles = @(Get-ChildItem (Join-Path $RepoRoot 'supabase/tests') -Filter *.sql -File)
$plannedTotal = 0
$noPlan = @()
foreach ($tf in $testFiles) {
    $pm = [regex]::Match([System.IO.File]::ReadAllText($tf.FullName), 'select\s+plan\(\s*(\d+)\s*\)')
    if ($pm.Success) { $plannedTotal += [int]$pm.Groups[1].Value } else { $noPlan += $tf.Name }
}
# If a test ever uses a computed plan this check must say so rather than quietly under-counting.
if ($noPlan.Count -gt 0) {
    Write-Host "  NOT COMPARABLE: $($noPlan.Count) test file(s) have no literal plan(N) -- the assertion total cannot be derived: $($noPlan -join ', ')" -ForegroundColor Yellow
    $figureIssues++
} else {
    $mSuite = [regex]::Match($mfRaw, 'Suite \*\*(\d+) files / ([\d,]+) assertions\*\*')
    if (-not $mSuite.Success) {
        Write-Host "  MANIFEST has no 'Suite **N files / M assertions**' figure -- cannot verify" -ForegroundColor Yellow
        $figureIssues++
    } else {
        $claimFiles = [int]$mSuite.Groups[1].Value
        $claimAsserts = [int]($mSuite.Groups[2].Value -replace ',', '')
        if ($claimFiles -ne $testFiles.Count) {
            Write-Host "  SUITE FIGURE DRIFT: manifest says $claimFiles test files, supabase/tests holds $($testFiles.Count)" -ForegroundColor Yellow
            $figureIssues++
        }
        if ($claimAsserts -ne $plannedTotal) {
            Write-Host "  SUITE FIGURE DRIFT: manifest says $claimAsserts assertions, the files plan $plannedTotal" -ForegroundColor Yellow
            $figureIssues++
        }
    }
}

$contractPath = Join-Path $masterDir 'MASTER_API_CONTRACT.md'
if (Test-Path $contractPath) {
    $cm = [regex]::Match((Get-Content $contractPath -Raw), '\*\*(\d+) RPC endpoints executable by')
    $mm = [regex]::Match($mfRaw, '\*\*(\d+) client RPCs\*\*')
    if ($cm.Success -and $mm.Success -and $cm.Groups[1].Value -ne $mm.Groups[1].Value) {
        Write-Host "  ENDPOINT FIGURE DRIFT: manifest says $($mm.Groups[1].Value) client RPCs, the GENERATED contract says $($cm.Groups[1].Value)" -ForegroundColor Yellow
        $figureIssues++
    }
}

if ($figureIssues -gt 0) {
    Write-Host "  Remedy: correct the manifest, or regenerate the contract. These figures describe the" -ForegroundColor DarkGray
    Write-Host "  safety net a fresh session inherits; a wrong one misrepresents how much is proven." -ForegroundColor DarkGray
    $issues += $figureIssues
} else {
    Write-Host "  manifest suite figures ($($testFiles.Count) files / $plannedTotal assertions) and endpoint count match the repository" -ForegroundColor Green
}

Write-Host ""
Write-Host "== Check 13: no Master table row is escaped out of its own table ==" -ForegroundColor Cyan
# REG-1 (2026-08-30). The IDENT-1 row in MASTER_GAP_REGISTER.md opened with a BACKSLASH-ESCAPED
# leading pipe. Two consequences, and the second is why this is a guard and not a typo:
#   1. Rendering -- an escaped leading pipe is cell CONTENT, so every column shifts left by one and
#      the register's only Critical finding displayed its title in the ID column.
#   2. Measurement -- Check 2 extracts a row's subject with '^\|\s*(<id>)'. A row starting with a
#      backslash matches nothing, so IDENT-1 was structurally INVISIBLE to the cross-Master status
#      comparison, and Check 2's "no contradiction over N open id(s)" was computed over a set that
#      silently excluded the highest-severity finding in the file. That is the same false-green
#      class as PAR-3 and SEC-1b: a guard reporting a verdict over less than it claims to cover.
# Deliberately narrow: ONLY a leading escaped pipe, which is never legitimate in a table row and
# has no other meaning at the start of a line. Escaped pipes INSIDE a cell are legal and common
# (they are how a literal '|' is written in a cell), so they are not touched. No exemption list --
# the check derives its scope from reports/master/*.md and nothing is enumerated by name.
$escapedRows = 0
if (Test-Path $masterDir) {
    foreach ($md in Get-ChildItem $masterDir -Filter *.md -File) {
        $lineNo = 0
        foreach ($line in [System.IO.File]::ReadAllLines($md.FullName)) {
            $lineNo++
            if ($line -match '^\\\|') {
                Write-Host "  ESCAPED TABLE ROW: $($md.Name):$lineNo begins with a backslash-escaped pipe -- the row is invisible to Check 2 and renders one column to the left" -ForegroundColor Yellow
                $escapedRows++
            }
        }
    }
}
if ($escapedRows -gt 0) { $issues += $escapedRows }
else { Write-Host "  every reports/master table row opens with an unescaped pipe" -ForegroundColor Green }

# =================================================================================================
Write-Host "== Check 16: canon does not name a settled finding as a CURRENT owner decision ==" -ForegroundColor Cyan
# COLD-START CONTRADICTION (2026-09-01). `32_execution_roadmap.md` told a fresh session that SEC-1's
# write-path architecture was an open owner decision BLOCKING PHASE 10 -- four days after the owner
# ratified it (OWNER-1), and forty-seven lines below a paragraph in the SAME FILE recording that very
# correction. A cold-start agent following the boot sequence would have re-litigated a settled
# decision or escalated a blocker that does not exist. Neither Check 2 (scoped to reports/master) nor
# Check 6 (phase agreement only) nor Check 11/14 (manifest -> register) could see it: no guard had
# ever read canon prose against the decision list.
#
# THE AUTHORITY IS THE MANIFEST'S `Open owner decisions` LINE -- the same designated list Checks 11
# and 14 already parse, and the line whose own text states that every ID on it is read as an open
# decision. Nothing here maintains a list of closed IDs; a decision leaves this guard's "open" set by
# leaving that line, which is the act OWNER-1 performs.
#
# FIVE GATES, and each is structural rather than linguistic. The hard problem is telling a CURRENT
# CLAIM from HISTORICAL or EXPLANATORY prose -- exactly the failure Check 2 hit when a title cell's
# aside about a different object read as the row's own status:
#   1. SCOPE  -- `_ORVION_CANONICAL/**` only. Canon is the INTENT evidence class (AGENTS.md §5a): it
#      records what was meant, never live status. `reports/master/**` is deliberately NOT covered --
#      Check 2 owns status there, and those documents legitimately carry dated evidence.
#   2. REGION -- the line must be a markdown LIST ITEM. This is the boundary that separates canon
#      32's Phase-10 "prerequisites" list (a current assertion) from its correction PARAGRAPH
#      (historical narrative). A structural feature of the document, not formatting inside a line --
#      MEAS-4's lesson that a whitespace-sensitive predicate is a predicate about formatting.
#   3. CLAIM  -- a small closed phrase set. No NLP, no inference.
#   4. NEGATIVE -- the line must not also carry a resolution word. A sentence saying "X WAS open and
#      is now decided" therefore exempts itself, which is how legitimate history stays legal.
#   5. AUTHORITY -- the ID must be absent from the manifest's open-decision line.
#
# MEASURED BEFORE IT WAS TRUSTED: across all 37 canonical documents these gates produce exactly ONE
# flag (the planted defect above) and zero false positives, and the ID parse deliberately reads the
# WHOLE manifest line -- parenthetical references included -- so its only possible error is to be
# MORE permissive, never to cry wolf.
$canonDir = Join-Path $RepoRoot '_ORVION_CANONICAL'
$decisionLine = ($manifestRaw -split "`n" | Where-Object { $_ -match 'Open owner decisions' } | Select-Object -First 1)
$canonClaims = 0
if (-not $decisionLine) {
    Write-Host "  MANIFEST has no 'Open owner decisions' line -- Check 16 cannot run" -ForegroundColor Red
    $issues++
} else {
    $openDecisionIds = @{}
    foreach ($m in [regex]::Matches($decisionLine, $idPat)) { $openDecisionIds[$m.Groups[1].Value] = $true }
    $claimPat    = '(open owner decision|awaiting owner|owner must decide|blocked on)'
    $resolvedPat = '(decided|resolved|closed|ratified|superseded|no longer|was an open)'
    foreach ($md in Get-ChildItem $canonDir -Filter *.md -File) {
        $lineNo = 0
        foreach ($line in [System.IO.File]::ReadAllLines($md.FullName)) {
            $lineNo++
            if ($line -notmatch '^\s*(\d+\.|[-*])\s') { continue }   # gate 2: list item only
            if ($line -notmatch $claimPat)            { continue }   # gate 3: asserts an open decision
            if ($line -match $resolvedPat)            { continue }   # gate 4: self-exempting history
            foreach ($m in [regex]::Matches($line, $idPat)) {
                $id = $m.Groups[1].Value
                if (-not $openDecisionIds.ContainsKey($id)) {        # gate 5: not on the open list
                    Write-Host "  SETTLED FINDING PRESENTED AS A CURRENT OWNER DECISION: $($md.Name):$lineNo names $id, which the manifest's open-decision line does not carry" -ForegroundColor Yellow
                    $issues++; $canonClaims++
                }
            }
        }
    }
    if ($canonClaims -eq 0) {
        Write-Host "  no canonical document asserts a current owner decision the manifest does not list (checked against $($openDecisionIds.Count) open id(s))" -ForegroundColor Green
    }
}

# =================================================================================================
Write-Host "== Check 17: canon does not restate the generated RPC-endpoint count ==" -ForegroundColor Cyan
# The same cold-start defect, second half. `32_execution_roadmap.md` restated "71 RPC endpoints"
# while `MASTER_API_CONTRACT.md` -- which is GENERATED from pg_catalog and diffed by the parity
# guard's Check L3 -- had moved to 72. The sentence contradicted itself inside its own second clause,
# which already said "The current count is read from the generated contract, never restated here".
# A mutable fact copied out of its generator is a stale fact with a delay fuse; GOV-5 reached this
# conclusion for migration counts, REG-2 for endpoint counts, and ROAD-1 for both.
#
# The fix that holds is DELETION, not refreshment, so this check forbids the restatement outright.
# Scope is canon only, for the reason above: canon is INTENT and never measurement. No exemption
# list exists and none is needed -- `MASTER_API_CONTRACT.md` is not in `_ORVION_CANONICAL/`, so the
# generator that legitimately owns the number is outside this check by construction rather than by
# a carve-out somebody has to maintain.
$countRestated = 0
foreach ($md in Get-ChildItem $canonDir -Filter *.md -File) {
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($md.FullName)) {
        $lineNo++
        $m = [regex]::Match($line, '\b\d+\s+RPC endpoints?\b')
        if ($m.Success) {
            Write-Host "  GENERATED COUNT RESTATED IN CANON: $($md.Name):$lineNo says '$($m.Value)' -- MASTER_API_CONTRACT.md owns this number; cite the contract instead" -ForegroundColor Yellow
            $issues++; $countRestated++
        }
    }
}
if ($countRestated -eq 0) {
    Write-Host "  no canonical document restates the endpoint count the generated contract owns" -ForegroundColor Green
}

# =====================================================================================================
# Check 18: RECOVER-1 -- the repository must CARRY attributable evidence that Primary's migration
#           ledger is this repository's migration ledger.
#
# WHY THIS CHECK IS HERE, in the file-only guard, and not only in check_database_parity.ps1.
# RECOVER-1 (2026-09-03): Primary ran four migrations the repository did not have, for a day, while
# every guard reported CLEAN. The parity guard was NOT the liar -- run without Primary values it
# already exits 2 and prints "This is NOT a pass". The hole was that **nothing in the repository
# recorded whether Primary had ever been read at this HEAD**, so the question was unanswerable from
# the repository, and an unanswerable question is indistinguishable from a satisfied one when nobody
# asks it. The parity guard also requires Docker and a live local stack, so it cannot run in the
# doc-only CI job or on a machine with the stack down -- and those are exactly the sessions that
# skipped it.
#
# So the evidence check belongs in the guard that IS run on every commit, in CI, and in Stage B of
# the boot sequence. It reads a repository FILE, so it stays inside this script's declared evidence
# class -- it does not open a database and does not claim to (MEAS-1: a guard must not describe
# itself more strongly than it measures).
#
# The check itself lives in scripts/check_primary_ledger.ps1 (single responsibility, independently
# runnable, independently mutation-tested by scripts/test_primary_ledger_guard.ps1). It is INVOKED
# here rather than reimplemented, so the two can never disagree about what "matches" means -- the
# PAR-1a mistake of two hand-copied variants of one query.
# =====================================================================================================
Write-Host "== Check 18: Primary ledger evidence (RECOVER-1) ==" -ForegroundColor Cyan
$ledgerGuard = Join-Path $PSScriptRoot 'check_primary_ledger.ps1'
if (-not (Test-Path $ledgerGuard)) {
    Write-Host "  MISSING: scripts/check_primary_ledger.ps1 -- RECOVER-1's guard is gone." -ForegroundColor Red
    $issues++
} else {
    & pwsh -NoProfile -File $ledgerGuard
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Primary ledger evidence is ABSENT, STALE or DISAGREES -- see above." -ForegroundColor Red
        Write-Host "  UNKNOWN IS NOT CLEAN. Refresh it by reading Primary's ledger via the" -ForegroundColor DarkGray
        Write-Host "  supabase-primary MCP; the exact query is recorded in the evidence file." -ForegroundColor DarkGray
        $issues++
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
    Write-Host "   Check 18 verifies the RECORDED Primary ledger reading, not a live one." -ForegroundColor DarkGray
    Write-Host "   For live local-vs-Primary surface parity run scripts/check_database_parity.ps1)" -ForegroundColor DarkGray
    exit 0
} else {
    Write-Host "REPOSITORY CONSISTENCY: $issues issue(s) found" -ForegroundColor Red
    exit 1
}
