<#
.SYNOPSIS
  Repository consistency guard — permanent guard (GOVERNANCE.md §18 discovery-to-guard loop)
  for the drift class repaired in the 2026-07-15 Repository Recovery: broken document
  references in Living docs, and contradictory finding-status inside a Master register.

.DESCRIPTION
  Deterministic, dependency-free. Precision over recall — it must not cry wolf, or agents
  will learn to ignore it. Twenty-five checks (1–2 Living docs; 3 boot routers; 4 all reports; 5 manifest;
  6 roadmap↔manifest; 7 ai-map freshness; 8 dual-project Supabase topology registry;
  9 manifest migration state vs the actual migration files; 10 latest-session pointer currency;
  11 manifest decision IDs resolve in the findings SSOT; 12 no future-dated evidence;
  13 no Master table row escaped out of its own table; 14 no manifest owner-decision id is already
  decided; 15 manifest suite/endpoint figures match the repository; 16–17 canon carries neither a
  settled decision presented as a current blocker nor a generated count copied out of its owner;
  18 the Active Change Request pointer names a real, still-open CR; 19 recorded Primary-ledger
  evidence, fail-closed):
    Check 1 broken references — document tokens in Living docs, AND (GOV-13, 2026-09-04) pgTAP
      `NN_*_test.sql` filenames cited in Living docs or in scripts/*.ps1, which nothing resolved
      until three references survived the deletion of the files they named ·
    Check 2 intra-register status contradiction — table rows, `###` headings, AND (GOV-11,
      2026-09-04) detail-block `**Status:**` fields, whose pattern had matched 0 of 96 blocks
      since it was written; both the same-file and the cross-Master pass now read them ·
    Check 3 boot-chain router integrity + AI-pointer thinness · Check 4 report class-header presence ·
    Check 5 manifest leanness (cold-boot cost) · Check 6 roadmap↔manifest phase agreement ·
    Check 7 ai-map freshness vs manifest — every live_state field the generator extracts (phase; and
      active_change_request / last_completed / next_capability compared BY VALUE) ·
    Check 8 Supabase project-topology registry integrity ·
    Check 9 manifest migration count/latest/fingerprint vs supabase/migrations ·
    Check 10 reports/README "Latest session report" pointer is CURRENT (GOV-1) ·
    Check 11 every open-decision ID the manifest raises resolves in MASTER_GAP_REGISTER.md (GOV-3) ·
    Check 12 no current-state evidence is dated in the future, and the clock is sane (AUD-01) --
      "the future" measured against the newest civil date anywhere on Earth (UTC+14), never the
      runner's own timezone, so the verdict is the same in CI as on the author's machine (AUD-01a) ·
    Check 13 no reports/master table row is escaped out of its own table, and out of Check 2 (REG-1) ·
    Check 14 no id on the manifest's open-decision line is already marked decided in the register (OWNER-1) ·
    Check 15 the manifest's suite and endpoint figures match the test files and the generated contract (META-1) ·
    Check 16 no canonical document names a settled finding as a CURRENT owner decision, judged against
      the manifest's own open-decision line (the cold-start contradiction of 2026-09-01) ·
    Check 17 no canonical document restates the RPC-endpoint count that MASTER_API_CONTRACT.md generates (REG-2) ·
    Check 18 the manifest's Active Change Request names a real, still-OPEN Change Request, judged
      against that CR's own `## Status` section (COLD-3). Check 7 asks whether the manifest and
      ai-map AGREE about this field; Check 18 asks whether what they agree on is TRUE. Independent
      invariants, independently testable -- neither substitutes for the other. ·
    Check 19 the repository CARRIES attributable evidence that Primary's migration ledger is this
      repository's migration ledger (RECOVER-1) -- a RECORDED reading, fail-closed, never a live one ·
    Check 20 this guard's OWN CI workflow is triggered by every input this guard reads (CI-1) -- a
      fixed list, because inferring the input set from this script would be a guess ·
    Check 21 no document's freshness metadata (`Last updated:` / `Last measured:`) is OLDER than the
      newest date its own body carries (STALE-1) -- semantic, never wall-clock: a document nobody has
      touched passes forever; only added-dated-content-without-a-header-update fails ·
    Check 22 the surface disposition record covers exactly the surfaces the migrations create (DISP-1) ·
    Check 23 every session report written under the HANDOFF rule carries its seven fields (HANDOFF-1) ·
    Check 24 `ADVERSARIAL` is earned by a declaring test file with negative assertions, not typed (ADV-1) ·
    Check 25 every registered decision reaches the manifest's boot line (GOV-16).

  COLD-START STATE IS ONE FACT WITH ONE PARSE (2026-09-09). Three synchronization defects were
  repaired together because they were one shape -- a check reading LESS than its name claims:
    * Check 10 validated the FIRST `Latest session report` row and never asked whether it was the
      ONLY live one, while a second un-prefixed cold-start directive named a three-slices-old report.
      It now requires exactly one live declaration, judged by this file's own `Previously:` marker.
    * Checks 11/14/16/25 each re-parsed the manifest's `Open owner decisions` line with a different
      regex, so the SENTENCE EXPLAINING the line donated a closed `GOV-16` to the open set. The line
      is now parsed ONCE: `$openDecisionIds` is the ENUMERATION (state, used by 14/16/25) and
      `$decisionLineIds` is every id on the line (a reference question, used by 11 alone).
    * Checks 2/14/25 each carried their own "settled" vocabulary over the SAME register and
      disagreed on 14 rows; Check 14 read table rows only, blind to all 65 section-only findings;
      Check 25 matched unanchored, so `deliberately NOT FIXED` read as settled. There is now ONE
      vocabulary (`$statusResolvedLead`, taken from the register's own Legend) and ONE resolver
      (`Get-RegisterFindingState`) reading table rows, `###` headings and detail blocks together.
  Checks 14 and 25 are exact inverses over the same two signals (settled · names a decider), so
  they can no longer answer one row differently and deadlock.

  Checks 1, 10 and 11 are three different questions about a reference and none substitutes for
  another: does it RESOLVE (1), is it the CURRENT one (10), and does the ID the boot sequence is
  told to look up actually EXIST in the register that claims to define it (11). Check 12 asks the
  fourth: is the evidence even dated plausibly (a record dated tomorrow claims evidence that could
  not yet have been gathered, and sorts ahead of records that are genuinely newer). Checks 12 and 21
  bracket the same field from opposite sides -- 12 forbids a header dated ahead of the evidence, 21
  forbids one dated behind the document's own content.

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

# GOV-13 (2026-09-04): the token set above is DOCUMENTS ONLY -- `NN_name.md`, `MASTER_*.md`,
# `ADR-NNNN.md`. A pgTAP file named as the proof of a finding was never resolved by anything, and
# the `d02b702` merge deleted two of them (the RECOVER-1 reconstructions, superseded by the
# committed originals) while THREE live references kept naming them: two in MASTER_GAP_REGISTER.md
# -- including the row that cited a deleted file as SUP-3's proof -- and one in
# verify_role_journeys.ps1. The register pointing at a test that does not exist is a finding whose
# evidence cannot be re-run, which is the same failure class as a stale document reference and was
# simply outside the measured token set. Widened rather than given its own check number: it is the
# same invariant (a reference that does not resolve), not a new one.
#
# SCOPE INCLUDES scripts/*.ps1, because the HTTP suites cite pgTAP files as their pgTAP counterpart
# and one of the three stale references lived there. `history/` and `changes/` stay excluded exactly
# as above -- an immutable dated report naming a file that existed on that date is HISTORY, and
# correcting it would be rewriting the record (`GOVERNANCE.md §4`).
$testRef = '(?<name>[0-9]{2}[a-z0-9_]*_test\.sql)'
$refScanned = @($livingDocs) + @(
    Get-ChildItem -Path (Join-Path $RepoRoot 'scripts') -Filter *.ps1 -File -ErrorAction SilentlyContinue
)
foreach ($src in $refScanned) {
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($src.FullName)) {
        $lineNo++
        foreach ($m in [regex]::Matches($line, $testRef)) {
            $name = $m.Groups['name'].Value.ToLower()
            if (-not $fileNames.ContainsKey($name)) {
                $rel = $src.FullName.Substring($RepoRoot.Length + 1)
                Write-Host "  BROKEN TEST REF: $rel : $lineNo -> $($m.Groups['name'].Value) (no such file in supabase/tests)" -ForegroundColor Yellow
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

# GOV-18 (2026-09-04): open-detection used to be `$line -match '\|\s*OPEN\s*\|'` -- a padded cell
# containing EXACTLY the word OPEN. Deliberate when written, to kill prose false-positives, but its
# cost was never measured. Measured now, over every reports/master table: the bare form covers
# **20 of 84** open rows. The other 64 say `DESIGN-READY`, `PENDING (OPTIONAL / NEEDS MORE
# EVIDENCE)`, `BLOCKED - ...`, `OPEN - ...`, `TRIGGER-DEFERRED`, `VALIDATED-REQUIRED`,
# `MOVED->PENDING` or `PARTIALLY RESOLVED`. Check 2's contradiction pass -- and, through $xOpen,
# AUD-04's cross-Master pass -- was therefore blind to 76% of the open population, which is exactly
# how GOV-17's five contradictions printed CLEAN.
#
# TWO CHANGES, and the first is what makes the second safe:
#
# 1. THE ROW'S STATUS CELL IS FOUND FROM ITS TABLE HEADER, not guessed. Every markdown table that
#    declares a `Status` column sets $statusIdx for the rows beneath it, so the check reads the cell
#    that actually holds the status -- index 9 in MASTER_GAP_REGISTER, but 2 in
#    MASTER_CERTIFICATION_STATUS and 5/6 in MASTER_INTEGRATION_CATALOG. Positional-but-declared,
#    the discipline that made the 2026-09-04 census correct after keyword matching failed twice.
#    Without this, widening the vocabulary would read OTHER cells: the register's `Cert` column
#    holds a bare ✅, and its `Owner Decision` column holds the bare word `pending`, so a widened
#    whole-line match would have called almost every row both open and resolved at once.
#    Measured before trusting: across all 15 Masters, ZERO rows have a non-status cell leading with
#    a resolved marker while their status cell does not -- so narrowing resolved-detection to the
#    status cell changes no existing verdict, and only removes that latent trap.
#
# 2. THE VOCABULARY IS DERIVED FROM THE FILES, not invented. Every distinct leading token of every
#    status cell in reports/master was enumerated; the open set below is the register's own legend
#    (`Status: OPEN . DESIGN-READY . RESOLVED . VERIFIED`) plus the deferral forms actually in use.
#    Terminal verdicts stay OUT, deliberately: `INTENTIONAL`, `PROVEN NOT A DEFECT`, `UNPROVEN`,
#    `ACCEPTED RISK`, `RECORDED, DELIBERATELY NOT FIXED`, `NOT REPRODUCIBLE`, `EVIDENCE ONLY`,
#    `MEASURED`, `DECIDED`, `CONFIRMED`, `BUILT`, `CORRECTED`, `GUARDED`, `WIDENED`, `RECONCILED`,
#    `REFACTORED`, `CONTROL APPLIED`, `RATIFIED`. Each of those is a finished verdict; reading one
#    as "open" would manufacture contradictions, which is the mirror of the defect being fixed.
#
# DETAIL BLOCKS ARE DELIBERATELY NOT SCANNED FOR "OPEN", and this asymmetry is the design, not an
# omission. A `###` block is an APPEND-ONLY NARRATIVE: the register records a finding's discovery
# state and its later resolution as separate blocks, so `BLOCKED` in an early block followed by
# `RESOLVED` in a later one is CORRECT history, not a contradiction -- TASK-3, ORPH-1, PERM-1,
# RBAC-2, LEAD-2, LEAD-3 and LEAD-4 all have exactly that shape. The TABLE ROW is the current-state
# record (one row per id), so "open" is read only from it, while "resolved" is read from either
# substrate (GOV-11) -- a resolution recorded anywhere means a row still saying open is STALE,
# which is precisely the GOV-17 case this exists to catch.
#
# PROVEN, NOT ASSERTED: scripts/test_status_contradiction_guard.ps1 -- 25 assertions over isolated
# sandbox copies of reports/master, in BOTH directions. Ten open forms must be flagged (and the
# suite also proves the pre-GOV-18 detector saw only one of them); eleven terminal verdicts must
# NOT be, including the `**✅ RESOLVED ... Superseded text:** **BLOCKED ...**` shape that seventeen
# real rows carry, plus a row planted with Cert=✅ and Owner=`pending` beside an open status to
# prove the row is judged on its declared Status cell alone. Two controls bracket the suite.
# It found and killed a real defect in its own harness before it certified anything here.
$statusOpenLead = '^[\s*`]*(?:📋[\s*`]*)?(OPEN|BLOCKED|DESIGN-READY|PENDING|IN PROGRESS|PARTIALLY RESOLVED|TRIGGER-DEFERRED|VALIDATED-REQUIRED|MOVED\s*(?:→|->)\s*PENDING)\b'

# ONE SETTLED VOCABULARY FOR THE WHOLE SCRIPT (2026-09-09). Until now Checks 2, 14 and 25 each
# carried their OWN idea of "settled" over the SAME register, and they disagreed on 14 rows:
#   Check 2   '^(\*\*)?\s*(✅|RESOLVED|IMPLEMENTED)'                             -- no CLOSED, no VERIFIED
#   Check 14  '^(\*\*)?\s*(✅|RESOLVED|FIXED|IMPLEMENTED|CLOSED|DECIDED|...)'    -- no VERIFIED, no INTENTIONAL
#   Check 25  'RESOLVED|DECIDED|FIXED|...|SUPERSEDED|RETIRED|✅'  UNANCHORED     -- a different set AND
#             matched anywhere in the first 80 characters rather than at the cell's opening.
# Checks 14 and 25 ask INVERSE questions of the same rows -- "is a listed decision already settled?"
# and "is a settled-less decision missing from the list?" -- so two vocabularies can deadlock: a row
# Check 14 calls settled (remove it from the manifest line) that Check 25 calls open (put it back)
# cannot be made CLEAN by any edit. Measured: 14 rows already sit in that disagreement, and the only
# reason it has not fired is that none of the 14 currently names a decider.
#
# Check 25's UNANCHORED match is a live false-negative, not a latent one, and it is the MEAS-2 class
# its own comment claims to have fixed: `ARCH-2`, `DEAD-4`, `SYNC-1`, `ORIG-1`, `JE-2`, `GOV-9`,
# `PLACE-2` and `CAP-1` all OPEN their status cell with `OPEN` / `RECORDED` / `UNPROVEN` and are read
# as SETTLED because the phrase "deliberately NOT **FIXED**" contains the word FIXED. Narrowing the
# window to 80 characters bounded that defect; it did not close it. Anchoring does.
#
# THE VOCABULARY IS THE REGISTER'S OWN, not an invention. `MASTER_GAP_REGISTER.md`'s Legend declares
# `Status: OPEN · DESIGN-READY · RESOLVED · VERIFIED · INTENTIONAL · RESOLVED BY DERIVATION`, and the
# five-state table beneath it assigns each state a meaning: `INTENTIONAL` is "intentional dormant
# state" and `RESOLVED`/`VERIFIED`/`RESOLVED BY DERIVATION` are "completed / closed" -- both terminal.
# ✅/FIXED/IMPLEMENTED/CLOSED/DECIDED/PROVEN-NOT-A-DEFECT/PROVEN-INTENTIONAL are the forms already in
# use that the three checks between them already accepted; they are unified here, not widened.
# DELIBERATELY STILL OUT: `SUPERSEDED`, `RETIRED`, `OBSOLETE`, `DELIVERED`, `MITIGATED`, `NARROWED`,
# `BOUNDED`, `MEASURED`, `RECORDED`, `UNPROVEN`, `ACCEPTED RISK`, `NOT REPRODUCIBLE`, `EVIDENCE ONLY`.
# None appears in the register's declared vocabulary, and deciding what they mean is a policy call
# about findings, not a parser repair. They resolve to NEITHER open nor settled, exactly as before.
#
# ANCHORED AT THE CELL'S OPENING, because that is where this register writes its verdict and because
# 17 rows legitimately RETAIN superseded wording after it ("**✅ RESOLVED ... Superseded text:**
# **BLOCKED ...**"). Both directions are pinned by scripts/test_status_contradiction_guard.ps1.
$statusResolvedLead = '^[\s*`]*(?:✅|RESOLVED BY DERIVATION\b|RESOLVED\b|VERIFIED\b|FIXED\b|IMPLEMENTED\b|CLOSED\b|DECIDED\b|INTENTIONAL\b|PROVEN\s+(?:NOT A DEFECT|INTENTIONAL)\b)'

# ONE RESOLVER FOR "WHAT DOES THE REGISTER SAY ABOUT THIS ID?", covering BOTH representations the
# register legitimately uses and BOTH signals its own five-state table names (2026-09-09).
#
# WHY IT READS DETAIL BLOCKS AT ALL. Check 14 read TABLE ROWS ONLY, and 65 of the register's findings
# have no table row -- they exist solely as `###` detail blocks. Measured: 42 of those 65 are SETTLED
# and Check 14 could see none of them. Not academic: `GOV-16` is
# `### GOV-16 — ✅ FIXED 2026-09-07 (Check 25), mutation-tested` with `- **Status:** **✅ RESOLVED**`,
# and it sat inside this guard's own open-decision set while Check 14 printed "every manifest
# owner-decision ID is still open in the register". Same class as GOV-11 and REG-1.
#
# THREE SUBSTRATES, in the order the register uses them:
#   (a) the `###` heading itself        -- `### API-3 — ✅ CLOSED 2026-08-30`
#   (b) the block's `**Status:**` field -- the form 89 blocks actually use (GOV-11)
#   (c) the table row's status cell, located from the table's OWN header (GOV-18), never guessed
#
# TWO SIGNALS, NOT ONE, and this is the correction that matters. A status test ALONE gets `RET-1`
# wrong, and it got it wrong on the first run of this repair: RET-1's blocks say
# `✅ RESOLVED — IMPLEMENTED (the MECHANISM; the VALUES remain counsel's)`, so a settled-status
# reading would have told a weak agent to DELETE a live compliance decision from the boot line --
# a worse failure than the miss being fixed, and in the destructive direction.
#
# The discriminator is the register's OWN, declared in its five-state table: a **critical unresolved
# decision** is where "the Owner Decision column is non-empty, and the id appears on manifest.md's
# open-decision line". So this returns Settled AND Decider, and the two consumers combine them as
# exact inverses:
#   Check 14  on the line + SETTLED + NO decider   -> stale, remove it
#   Check 25  has a decider + NOT settled + absent -> unsurfaced, add it
# GOV-16 is settled with `**Owner:** engineering` (not a decider) -> stale. RET-1 is settled with
# `**Owner:** owner + counsel for any period` -> still a decision. No special case for either.
#
# MONOTONIC IN BOTH FIELDS -- once settled, stays settled; once a decider is named, it stays named.
# The register is append-only narrative (a discovery block says BLOCKED and a later closure block
# says FIXED, which is correct history, not a contradiction), and both directions are the SAFE one:
# a resolution is never lost, and a decision never silently disappears.
#
# ITS CEILING, stated because a guard that oversells itself is the class this repository keeps
# finding: if a finding is settled and nobody ever clears its decider, it stays eligible for the boot
# line forever and no check here will say otherwise. That is a documentation act this script cannot
# perform, and reading a stale decider as "no decision" would be inventing the clearance.
function Get-RegisterFindingState {
    param([string]$Path, [string]$IdPattern, [string]$SettledLead, [string]$DeciderRx)
    $state = @{}
    if (-not (Test-Path $Path)) { return $state }
    function Set-Signal([hashtable]$s, [string]$id, [string]$field, [string]$where) {
        if (-not $id) { return }
        if (-not $s.ContainsKey($id)) { $s[$id] = @{ Settled = $null; Decider = $null } }
        if (-not $s[$id][$field]) { $s[$id][$field] = $where }
    }
    $statusIdx = -1
    $ownerIdx  = -1
    $blockId   = $null
    $lineNo    = 0
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $lineNo++
        $head = [regex]::Match($line, '^###\s+(?<id>' + $IdPattern + ')\s*(?<rest>.*)$')
        if ($line -match '^#{1,3}\s') { $blockId = $(if ($head.Success) { $head.Groups['id'].Value } else { $null }) }
        if ($head.Success) {
            # Strip the heading's separator (`— `, `-- `, `: `) so the verdict sits at the head.
            $rest = $head.Groups['rest'].Value -replace '^[\s\*`:—–-]+', ''
            if ($rest -match $SettledLead) {
                Set-Signal $state $head.Groups['id'].Value 'Settled' ("line $lineNo (heading): " + $rest.Substring(0, [Math]::Min(60, $rest.Length)))
            }
        }
        # `[regex]::Match`, not `-match`: an inner `-match` REBINDS $Matches, so reading $Matches['v']
        # after testing it against $SettledLead returns the SettledLead match's groups -- and that
        # pattern has no 'v'. Cost the first run of this repair a null-reference at line 318.
        $blkStatusM = [regex]::Match($line, '\*\*Status:?\*\*\s*(?<v>.*)$')
        if ($blockId -and $blkStatusM.Success) {
            $sv = $blkStatusM.Groups['v'].Value
            if ($sv -match $SettledLead) {
                Set-Signal $state $blockId 'Settled' ("line $lineNo (block status): " + $sv.Substring(0, [Math]::Min(60, $sv.Length)))
            }
        }
        # The VALUE after `**Owner:**`, never the label. `**Owner:**` itself trivially satisfies any
        # "names a decider" pattern, so reading the whole line would make every detail block in the
        # register a live decision.
        $blkOwnerM = [regex]::Match($line, '\*\*Owner:?\*\*\s*(?<v>[^·]*)')
        if ($blockId -and $blkOwnerM.Success) {
            $ov = $blkOwnerM.Groups['v'].Value
            if ($ov -match $DeciderRx) {
                Set-Signal $state $blockId 'Decider' ("line $lineNo (block owner): " + $ov.Trim())
            }
        }
        if ($line -match '^\s*\|') {
            $cells = @(($line -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
            $hS = -1; $hO = -1
            for ($ci = 0; $ci -lt $cells.Count; $ci++) {
                if ($cells[$ci] -eq 'Status')         { $hS = $ci }
                if ($cells[$ci] -eq 'Owner Decision') { $hO = $ci }
            }
            if ($hS -ge 0) { $statusIdx = $hS; $ownerIdx = $hO; continue }
            $lead = [regex]::Match($line, '^\|\s*(?<id>[A-Z][A-Za-z0-9\-/\.]*)\s*\|')
            if (-not $lead.Success) { continue }
            foreach ($piece in ($lead.Groups['id'].Value -split '/')) {
                $p = $piece.Trim()
                if (-not $p) { continue }
                if ($statusIdx -ge 0 -and $statusIdx -lt $cells.Count -and $cells[$statusIdx] -match $SettledLead) {
                    Set-Signal $state $p 'Settled' ("line $lineNo (row): " + $cells[$statusIdx].Substring(0, [Math]::Min(60, $cells[$statusIdx].Length)))
                }
                if ($ownerIdx -ge 0 -and $ownerIdx -lt $cells.Count -and $cells[$ownerIdx] -match $DeciderRx) {
                    Set-Signal $state $p 'Decider' ("line $lineNo (row owner): " + $cells[$ownerIdx])
                }
            }
        }
    }
    return $state
}

# A row/block records a DECISION when its Owner-Decision field names WHO must take it, rather than a
# scheduling word (`pending`, `done`, `cert-2026-07`, `-`). GOV-16's finding, kept verbatim; hoisted
# here from Check 25 because Check 14 now needs the identical predicate and two copies of it would
# be the very divergence this pass exists to remove. `owner (already recorded under PLAN-1)` is a
# decider too, so the separator may be a bracket as well as a colon.
$registerDeciderRx = '(?i)\b(owner|business|canon|counsel|legal|compliance)\b\s*[:+/(]|(?i)\bowner\b.*\bcounsel\b'

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
        $openAt = @{}      # id -> "line" where a table-row status cell reads as OPEN (GOV-18)
        $resolvedAt = @{}  # id -> "line" where the id is marked resolved
        $blockId = $null   # id of the `### <ID> — ...` detail block currently being read
        $statusIdx = -1    # GOV-18: index of the `Status` column of the table currently being read
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
            # GOV-11 (2026-09-04): the pattern above this line USED to be
            #   '^\s*-\s*\*\*Status:?\*\*.*\b(RESOLVED|FIXED|IMPLEMENTED|CLOSED)\b'
            # which requires the bullet to BEGIN with `- **Status:**`. The register has never once
            # written that form: it states a block's verdict INLINE on a combined field line,
            #   `- **Category:** ... · **Severity:** ... · **Status:** **CLOSED 2026-09-03** · **Owner:** ...`
            # so the detail-block half of this check matched **0 of 96** blocks from the day it was
            # written (2026-08-29) until this repair -- while its own comment above asserts it was
            # added precisely because the register "states a block's verdict on its own field far
            # more often than in the heading". A guard whose description outruns its measurement is
            # the MEAS-1 class, and this is that class inside the guard that reports it. Measured,
            # not assumed: 46 blocks state a resolved verdict this way, including RECOVER-1
            # (Critical, CLOSED), SUP-2, SUP-3, SUP-4a, RBAC-5 and RBAC-6 -- every one of whose
            # statuses was invisible to a cross-Master contradiction search.
            #
            # The repair anchors the verdict to the marker IMMEDIATELY AFTER `**Status:**` rather
            # than anywhere on the line, which is what keeps it precise: a block whose status is
            # BLOCKED/OPEN/INTENTIONAL must not be read as resolved merely because a later clause
            # on the same line contains the word "fixed". Attacked in both directions before it was
            # trusted -- 46 resolved lines match, and all 40 non-resolved ones (BLOCKED, OPEN,
            # INTENTIONAL, IN PROGRESS, OBSOLETE, MITIGATED, NARROWED, DEFER, SUPERSEDED,
            # DELIVERED) do not.
            #
            # THE VOCABULARY IS NOW $statusResolvedLead -- the ONE settled vocabulary defined above,
            # shared with Checks 14 and 25 (2026-09-09). It was a fourth private list here; the
            # header comment on $statusResolvedLead records which words were unified and which are
            # still deliberately excluded, and why that exclusion is a policy call rather than a
            # parser gap.
            # SECOND HALF OF GOV-11, found by ATTACKING the first half rather than by reading it.
            # Repairing the anchor above fixed the SAME-FILE contradiction pass only. A detail-block
            # status line is neither a table row nor a `###` heading, so it never reaches the
            # `foreach ($id in $ids)` loop below -- which is the ONLY place that populated
            # $xResolved. AUD-04's cross-Master pass was therefore still blind to all 46 blocks even
            # with the anchor fixed, and the mutation that should have flagged RECOVER-1 as OPEN in
            # a second Master while CLOSED here came back CLEAN. Wiring the cross-file table here is
            # what makes the published "conflicting finding status across Masters = 0" indicator
            # true for findings whose only verdict lives in a detail block.
            $blkStatus = [regex]::Match($line, '^\s*-\s.*\*\*Status:?\*\*\s*(?<v>.*)$')
            if ($blockId -and $blkStatus.Success -and $blkStatus.Groups['v'].Value -match $statusResolvedLead) {
                $resolvedAt[$blockId] = $lineNo
                if (-not $xResolved.ContainsKey($blockId)) { $xResolved[$blockId] = "$($md.Name):$lineNo" }
            }
            # GOV-18: learn this table's Status column from its header row, then judge each data row
            # on THAT cell. A header row carries no status of its own, so it is consumed here.
            $rowCells = @()
            if ($line -match '^\s*\|') {
                $rowCells = @(($line -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
                $hdrAt = -1
                for ($ci = 0; $ci -lt $rowCells.Count; $ci++) {
                    if ($rowCells[$ci] -eq 'Status') { $hdrAt = $ci; break }
                }
                if ($hdrAt -ge 0) { $statusIdx = $hdrAt; continue }
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
            if ($line -match '^###\s') {
                # UNIFIED 2026-09-09 with Get-RegisterFindingState: strip the heading's id and its
                # separator, then read the verdict AT THE HEAD. This branch used to match
                # ✅/RESOLVED/IMPLEMENTED ANYWHERE on the line, so a heading whose prose mentioned a
                # resolution ("the finding that was never RESOLVED") read as the block's own verdict
                # -- the unanchored-substring class that Check 25 still carried until this pass, one
                # branch away from where GOV-11 fixed exactly the same mistake. One rule, one
                # meaning, both places.
                $hRest = ($line -replace '^###\s+[A-Za-z0-9\-/\.]+\s*', '') -replace '^[\s\*`:—–-]+', ''
                $rowResolved = $hRest -match $statusResolvedLead
            } elseif ($statusIdx -ge 0 -and $statusIdx -lt $rowCells.Count) {
                # GOV-18: the declared status cell is the row's status. Both verdicts are read from
                # the SAME cell, so a row can never be open and resolved at once -- a contradiction
                # is now only ever a row disagreeing with a detail block, which is the real defect.
                $statusCell = $rowCells[$statusIdx]
                $rowOpen     = $statusCell -match $statusOpenLead
                $rowResolved = $statusCell -match $statusResolvedLead
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
    # GUARD-CRLF-1 (2026-09-07): this measured LINE ENDINGS, not document size. `-Raw` returns the
    # bytes as checked out, so under CRLF every line adds one character and the SAME COMMIT measures
    # differently on two machines: manifest.md read 6,943 on an LF working copy and 7,003 on a fresh
    # checkout of that identical commit (60 lines = +60), against a 7,000 budget — CLEAN here, 1 issue
    # there. It had already cost real content: commit `ecb8346` deleted BOOK-3's attack narrative from
    # the manifest to clear a 3-character overage that exists only under CRLF. The budget is NOT the
    # defect and is unchanged at 7,000 (AGENTS.md §6 — never raised to fit); the MEASUREMENT was wrong,
    # so the measurement is what is repaired (AGENTS.md §6 — "if a guard's description is stronger than
    # its measurement, fix the guard"). Same family as VER-1, MEAS-1, PAR-1a, GOV-11 and the Check 12
    # timezone defect fixed one commit earlier. Normalise CRLF→LF so the verdict is a property of the
    # DOCUMENT, not of the checkout. The two neighbouring measurements need no fix: `Get-Content`
    # without `-Raw` already strips line endings, so $mfLines and $mfLongest were never affected.
    $mfChars = ((Get-Content $mfPath -Raw) -replace "`r`n", "`n").Length
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
# must appear in ai-map's live_state, and its `Last Completed`, `Active Change Request` and
# `Next capability` fields must match ai-map's copies BY VALUE — every live_state field the
# generator extracts from the manifest is now compared. Skips cleanly if ai-map has been retired
# (owner-gated recommendation, 2026-07-17).
$aiMapPath = Join-Path $RepoRoot 'ai-map.json'
if ((Test-Path $aiMapPath) -and (Test-Path $mfPath)) {
    $mfRaw2 = Get-Content $mfPath -Raw
    $aiRaw  = Get-Content $aiMapPath -Raw
    if ($null -ne $manifestCur -and $aiRaw -notmatch "Phase\s+$manifestCur\b") {
        Write-Host "  AI-MAP STALE: ai-map.json live_state does not name manifest Current Phase $manifestCur — regenerate (scripts/generate-ai-map.ps1)" -ForegroundColor Yellow
        $issues++
    }
    # EXTENDED 2026-09-02 (GOV-10 ≡ COLD-2 -- ONE defect, found TWICE). `Active Change Request` is
    # the fourth live_state field the generator extracts, and it was the ONLY one nothing compared.
    #
    # RECONCILED 2026-09-03. Two sessions diverged from 4b67d3f without fetching and each wrote this
    # comparison independently -- GOV-10 at 17:59 and COLD-2 at 21:21 on 2026-09-02 -- arriving at the
    # same regex, the same variables and the same normalisation, differing only in the warning text.
    # The merge kept exactly ONE implementation -- THIS one (GOV-10's), on one measurable difference:
    # its warning echoes BOTH values, where COLD-2's names neither, and a guard that prints what it
    # saw is diagnosable without re-running it. A second copy would not have been redundant but
    # WRONG: both would fire on the same divergence and `$issues` would count one defect twice,
    # which is a guard lying about magnitude -- the MEAS-1 class this repository keeps re-finding.
    # Both register rows are retained and cross-referenced; the duplication is evidence about the
    # PROCESS (parallel sessions, no fetch), not about the field.
    #
    # Check 7's coverage had been
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
# =====================================================================================================
# SHARED MANIFEST STATE, PARSED ONCE (2026-09-09). Checks 10, 11, 14, 16 and 25 all read the manifest
# and four of them independently re-parsed its `Open owner decisions` line with three different
# regexes and two different scopes. That duplication was not cosmetic -- it is how GOV-16 became a
# live owner decision inside this guard.
#
# THE DEFECT. The manifest's line is an ENUMERATION followed by PROSE ABOUT the enumeration:
#     Open owner decisions - **MAIL-1**, ..., **BOOK-9**. IDs here are read as OPEN, so a decided one
#     is removed rather than annotated; ... **This line named only MAIL-1 until 2026-09-07**, when
#     GOV-16's guard (**Check 25**) was written and measured seven registered decisions ...
# Every consumer scraped ids from the WHOLE line, so the narrative sentence explaining how the line
# came to be donated `GOV-16` to the open set. GOV-16 is `### GOV-16 - ✅ FIXED 2026-09-07` in the
# register: a finding that was closed two days earlier, counted as a live blocker because its id
# appears in a sentence. Guard-derived open decisions: 11. Actual: 10.
#
# The damage runs in the direction that HIDES work, not merely the one that invents it. Check 25 asks
# "is any registered decision missing from this line?" and SKIPS every id the line already carries --
# so a narrative mention silently exempts a real decision from ever being surfaced. Check 16 asks
# "does canon present a settled finding as current?" and treats the same polluted set as authority.
#
# THE RULE, structural rather than linguistic: THE ENUMERATION IS THE STATE, and it ends at the first
# sentence terminator. Finding ids contain no periods, so the boundary is unambiguous, and prose that
# explains the list can never again become the list. Two sets are derived and they are deliberately
# different:
#   $openDecisionIds   -- the enumeration only. This is the OPEN-DECISION STATE (Checks 14, 16, 25).
#   $decisionLineIds   -- every id anywhere on the line. This is a REFERENCE question, not a state
#                         question: Check 11 asks whether an id the boot line NAMES resolves in the
#                         register, and a narrative citation that dangles is still a broken reference
#                         in the one line a cold start reads. Superset by construction, so the two
#                         can never contradict.
# =====================================================================================================
$manifestRaw  = Get-Content (Join-Path $RepoRoot '_ORVION_CANONICAL/manifest.md') -Raw
$readmeText   = Get-Content (Join-Path $RepoRoot 'reports/README.md') -Raw
$registerPathShared = Join-Path $RepoRoot 'reports/master/MASTER_GAP_REGISTER.md'
$registerRaw  = Get-Content $registerPathShared -Raw
$decisionIdRx = '\b([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[0-9]+[a-z]?|A[0-9]+)\b'
$decisionLine = ($manifestRaw -split "`n" | Where-Object { $_ -match 'Open owner decisions' } | Select-Object -First 1)
$decisionLineIds = @()
$openDecisionIds = @()
if ($decisionLine) {
    $decisionLineIds = @([regex]::Matches($decisionLine, $decisionIdRx) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    # The enumeration ends at the first sentence terminator -- a period followed by whitespace or the
    # end of the line. `$enumeration` is the whole line when the list is the whole line.
    $enumeration = $decisionLine
    $stop = [regex]::Match($decisionLine, '\.(\s|$)')
    if ($stop.Success) { $enumeration = $decisionLine.Substring(0, $stop.Index) }
    $openDecisionIds = @([regex]::Matches($enumeration, $decisionIdRx) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
}
# FAIL LOUD, never silently empty. An empty open set would make Checks 14 and 16 vacuously pass and
# Check 25 demand that every registered decision be added, which is the failure mode that looks like
# a clean repository. If the line exists it must enumerate at least one id before its first period.
if ($decisionLine -and $openDecisionIds.Count -eq 0) {
    Write-Host "  UNREADABLE OPEN-DECISION LINE: manifest.md has an 'Open owner decisions' line but no finding id before its first sentence terminator. The ENUMERATION is the state; prose after it is not. Add the id(s) to the list itself." -ForegroundColor Red
    $issues++
}

Write-Host "== Check 10: latest-session pointer is current ==" -ForegroundColor Cyan
$mNarr = [regex]::Match($manifestRaw, 'Narrative:\s*`([^`]+\.md)`')
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

    # -------------------------------------------------------------------------------------------
    # COLD-2b (2026-09-09): ONE LIVE POINTER, NOT MERELY A CORRECT FIRST ONE.
    #
    # Everything above uses [regex]::Match -- the FIRST match in the file. `reports/README.md` is a
    # stack of pointer rows, and the guard validated the top of the stack while a SECOND live-looking
    # cold-start directive sat eight lines below it saying something different:
    #     > **Current state & next step (read this first on a cold start):**
    #       `history/session-2026-09-08-batch6-slice8-lead-interactions.md` ...
    #       Next surface: **`leads`** (slice 9) ...
    # Slices 9, 10 and 11 were complete by then. A cold-starting agent that reached that line first --
    # and its own text tells the reader to read it first -- would have re-run finished work, which is
    # the most expensive cold-start failure there is because it looks like progress. Check 10 printed
    # CLEAN throughout: it proved the row it looked at, never that it was the only one.
    #
    # THE INVARIANT IS STRUCTURAL, and it is the file's OWN convention made executable. Every
    # superseded row in this file is prefixed `Previously:` or `Before that:`. So: a blockquote line
    # carrying a cold-start directive and NO historical prefix is a LIVE declaration; there must be
    # exactly one, and it must name the same report the manifest's `Narrative:` field names.
    #
    # The claim set is CLOSED and derived from the two shapes this file has actually used -- no NLP,
    # no inference (Check 16's discipline). Widening it is a deliberate act, not an accident.
    # Measured before trusting: over the real file these gates produce exactly ONE live row.
    $liveClaimRx    = '(?i)(Latest session report|read this first on a cold start|Current state & next step)'
    $historicalRx   = '(?i)^\s*>?\s*[*_]*\s*(Previously|Before that|Prior|Superseded)\b'
    $liveRows = @()
    $lineNo = 0
    foreach ($line in ($readmeText -split "`r?`n")) {
        $lineNo++
        if ($line -notmatch '^\s*>') { continue }          # blockquote rows are where pointers live
        if ($line -notmatch $liveClaimRx) { continue }
        if ($line -match $historicalRx)   { continue }      # structurally historical -- exempt
        $named = [regex]::Match($line, '`(?:history/)?([^`]+\.md)`')
        $liveRows += [pscustomobject]@{
            Line  = $lineNo
            Names = $(if ($named.Success) { $named.Groups[1].Value.Trim() } else { '<no report named>' })
        }
    }
    if ($liveRows.Count -eq 0) {
        Write-Host "  NO LIVE COLD-START POINTER: reports/README.md carries no un-prefixed 'Latest session report' row -- AGENTS.md 4 Stage A step 7 reads that row and would find nothing" -ForegroundColor Red
        $issues++
    } elseif ($liveRows.Count -gt 1) {
        Write-Host "  COMPETING LIVE COLD-START STATE: reports/README.md carries $($liveRows.Count) un-prefixed current-state declarations; exactly one may be live" -ForegroundColor Red
        foreach ($r in $liveRows) { Write-Host "    line $($r.Line) -> $($r.Names)" -ForegroundColor Red }
        Write-Host "  Remedy: a superseded pointer is prefixed 'Previously:' (this file's own convention) or deleted." -ForegroundColor DarkGray
        Write-Host "  Two live rows means a cold start can resolve two different current states, and the stale one wins if it is read first." -ForegroundColor DarkGray
        $issues++
    } elseif ($mNarr.Success -and $liveRows[0].Names -ne $mNarr.Groups[1].Value.Trim()) {
        Write-Host "  LIVE POINTER DISAGREES WITH THE MANIFEST: reports/README.md line $($liveRows[0].Line) names '$($liveRows[0].Names)' but the manifest's narrative is '$($mNarr.Groups[1].Value.Trim())'" -ForegroundColor Red
        $issues++
    } else {
        Write-Host "  exactly one live cold-start declaration (line $($liveRows[0].Line)), and it names the manifest's narrative" -ForegroundColor Green
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
if (-not $decisionLine) {
    Write-Host "  MANIFEST has no 'Open owner decisions' line -- cannot verify" -ForegroundColor Red
    $issues++
} else {
    # $decisionLineIds -- EVERY id on the line, narrative citations included. This is the ONE
    # consumer that legitimately wants the whole line, and the reason is that it asks a REFERENCE
    # question, not a state question: an id the boot line names must be findable in the register,
    # whether the line names it as an open decision or merely cites it. The open-decision STATE is
    # $openDecisionIds (the enumeration alone) and is used by Checks 14, 16 and 25 -- see the shared
    # parse above for why conflating the two put a closed GOV-16 into this guard's open set.
    $found = $decisionLineIds

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
# AUD-01a (2026-09-06). The ceiling is the newest civil date that EXISTS ANYWHERE ON EARTH, not the
# runner's local date. It used to be `(Get-Date).Date`, which made this check's verdict depend on
# WHERE it ran: ORVION is written from Africa/Cairo (UTC+2/+3) and CI runs in UTC, so for the ~3
# hours each night between Cairo's midnight and UTC's, a correctly-stamped document was "future
# dated" to GitHub Actions and to nobody else. That is exactly what happened to slice 3, pushed
# 2026-09-05T23:11Z: 22 FUTURE-DATED hits in CI, CLEAN on the machine that wrote them.
#
# UTC+14 (Pacific/Kiritimati) is the maximum civil offset in the IANA database, so this is the
# tightest bound that is true independently of the runner's clock. The invariant is UNCHANGED and
# still gates CI -- "a record dated tomorrow claims evidence that could not yet have been gathered"
# -- because a date that has not begun in UTC+14 has not begun for any author anywhere.
#
# ITS CEILING, stated because a guard that oversells itself is the class this repository keeps
# finding (MEAS-1): the accepted window is now up to 14 hours wider than the author's own civil day,
# so a date stamped a few hours into the author's tomorrow passes. That is the price of a verdict
# that does not change when the runner moves, and it is the right trade: the failure this replaces
# was a false one, fired nightly, at the moment work is most likely to be pushed.
$today = [datetimeoffset]::UtcNow.AddHours(14).Date
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
                Write-Host "  FUTURE-DATED: $rel : $lineNo -> $($m.Groups[1].Value) (that date has not begun anywhere on Earth; the newest civil date in existence is $($today.ToString('yyyy-MM-dd')))" -ForegroundColor Red
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
# The resolved-set is DERIVED from the register's own status fields, never from a list maintained
# here -- an exemption list would be one more thing to go stale, which is the defect this check
# exists to catch.
#
# WIDENED 2026-09-09 FROM TABLE ROWS TO THE WHOLE REGISTER. This check used to read `$cells[9]` of a
# leading-id table row and nothing else. **65 of the register's findings have no table row at all** --
# they exist only as `###` detail blocks -- and 42 of those 65 are SETTLED, so this check was
# structurally incapable of seeing any of them. The proof is not hypothetical and it was sitting in
# this guard's own output: `GOV-16` is `### GOV-16 - ✅ FIXED 2026-09-07 (Check 25), mutation-tested`
# with `- **Status:** **✅ RESOLVED**`, and Check 14 printed "every manifest owner-decision ID is
# still open in the register" while carrying it. Same class as GOV-11 (a detail-block reader that
# matched 0 of 96 blocks) and REG-1 (a row that no leading-pipe parser could see): a guard reporting
# a verdict over less than it claims to cover.
#
# Get-RegisterFindingState reads all three substrates with the ONE settled vocabulary this script now
# shares, so Check 14 ("is a listed decision already settled?") and Check 25 ("is a settled-less
# decision missing from the list?") can no longer answer the same row differently and deadlock.
$registerState = Get-RegisterFindingState -Path $registerPathShared -IdPattern $idPat.Trim('\b') `
                                          -SettledLead $statusResolvedLead -DeciderRx $registerDeciderRx
$staleDecisions = 0
# $openDecisionIds is the ENUMERATION ONLY -- see the shared parse above. The dead `Genuinely open:`
# cut that used to scope this line was removed with it: that marker has not been in the manifest for
# some time, so the cut silently fell through to the whole line and this check had been reading the
# narrative sentence too.
#
# SETTLED **AND** NO DECIDER. Status alone is not the test, and RET-1 is why: its blocks read
# `✅ RESOLVED — IMPLEMENTED (the MECHANISM; the VALUES remain counsel's)` beside
# `**Owner:** owner + counsel for any period`. The mechanism shipped; the compliance decision did
# not, the manifest says exactly that, and a status-only reading told this guard to strike a live
# decision off the boot line. The register's five-state table already names the Owner Decision
# column as the authority for "is this a decision"; this uses it rather than a second rule.
foreach ($id in $openDecisionIds) {
    if (-not $registerState.ContainsKey($id)) { continue }
    if (-not $registerState[$id].Settled)     { continue }
    if ($registerState[$id].Decider) { continue }   # settled mechanism, decision still outstanding
    Write-Host "  STALE OWNER DECISION: manifest lists '$id' as open, but the register marks it settled at $($registerState[$id].Settled) and names no decider for it" -ForegroundColor Yellow
    $staleDecisions++
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
            # A literal newline escape can hide a second row from every leading-row parser.
            # Match only a row boundary followed by a finding ID, not prose quoting escapes.
            if ($line -match '^\|' -and $line -cmatch '\|(?:`r)?`n\|\s*[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[0-9]+[a-z]?\s*\|') {
                Write-Host "  JOINED TABLE ROW: $($md.Name):$lineNo contains a literal newline escape before a finding row" -ForegroundColor Yellow
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
$canonClaims = 0
if (-not $decisionLine) {
    Write-Host "  MANIFEST has no 'Open owner decisions' line -- Check 16 cannot run" -ForegroundColor Red
    $issues++
} else {
    # 2026-09-09: this used to re-scrape the WHOLE line into its own hashtable, which is how a
    # narrative mention of GOV-16 became one of this gate's "open" ids. It now consumes
    # $openDecisionIds -- the enumeration alone -- so canon naming a settled finding as a current
    # owner decision is caught even when that finding's id happens to appear in the manifest's prose.
    $openDecisionSet = @{}
    foreach ($id in $openDecisionIds) { $openDecisionSet[$id] = $true }
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
                if (-not $openDecisionSet.ContainsKey($id)) {        # gate 5: not on the open list
                    Write-Host "  SETTLED FINDING PRESENTED AS A CURRENT OWNER DECISION: $($md.Name):$lineNo names $id, which the manifest's open-decision line does not carry" -ForegroundColor Yellow
                    $issues++; $canonClaims++
                }
            }
        }
    }
    if ($canonClaims -eq 0) {
        Write-Host "  no canonical document asserts a current owner decision the manifest does not list (checked against $($openDecisionSet.Count) open id(s))" -ForegroundColor Green
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

# =================================================================================================
Write-Host "== Check 18: the manifest's Active Change Request is a real, still-open CR ==" -ForegroundColor Cyan
# CLEAR-ON-COMPLETE (2026-09-02, COLD-3). Check 7 proves the manifest and `ai-map.json` AGREE about
# this field. It has never asked whether what they agree on is TRUE. Those are different invariants
# and this one had no owner: with the manifest pointing at `SPEC-125` -- whose own Status is
# `[x] Complete` -- and ai-map regenerated to match, the guard printed CLEAN at exit 0. So did a
# manifest pointing at `changes/SPEC-999-never-created.md`, a file that has never existed: Check 1
# deliberately excludes the `SPEC-NNN.md` placeholder shape from reference linting, so nothing in the
# repository had ever resolved this path. A cold-start agent takes `AGENTS.md §4` Stage A step 4 on
# this field -- it reads that CR and hands over to its Minimum Reading List -- so a stale pointer
# either hands it finished work as its assignment or sends it to a file that is not there.
#
# The failure is RECORDED, not hypothetical: the pointer-clear was omitted on Complete twice
# (SPEC-024, SPEC-027), and `reports/future-backlog.md` has carried the process-safeguard row since.
# That row proposed a Claude Stop/PostToolUse hook; a guard is the stronger answer because it runs in
# CI, needs no per-workstation tool configuration, and is what `GOVERNANCE.md §18` calls for.
#
# AUTHORITY: the CR's OWN `## Status` section, which `changes/TEMPLATE.md` defines and
# `CR_LIFECYCLE.md` §3/§4/§5/§8 governs -- §8 names `Status` as a workflow-state section of the
# Change Request itself, and §9's `Approve`/`Complete` commands flip that box and move this pointer
# in the same breath. Nothing else in the repository assigns a CR a status: `MASTER_EXECUTION_PLAN.md`
# names SPEC ids 29 times and gives none of them a state. Verified across all 151 CR files -- every
# one has exactly one `## Status` section with exactly one checked box. **Status is READ here, never
# copied**: no CR status enters `manifest.md` or `ai-map.json`, so no second source of truth is
# created and the manifest stays the sole current-state authority holding only the POINTER.
#
# No maintained list of SPEC ids exists or is possible here -- the subject is whatever path the
# manifest names. The five legal status words are read from `changes/TEMPLATE.md` rather than
# restated, so a vocabulary change is caught instead of silently accepted; the TERMINAL pair is
# `CR_LIFECYCLE.md` §4's ("`Complete` and `Cancelled` are terminal"), cited rather than derived by
# parsing prose. `Draft` is deliberately NOT flagged: it is non-terminal, and §9's `Execute` already
# refuses a Draft, so failing on it would be stricter than "currently open" without new evidence.
$acrLine = [regex]::Match($manifestRaw, '(?m)^Active Change Request:\s*(?<v>.+?)\s*$')
if (-not $acrLine.Success) {
    Write-Host "  MANIFEST has no 'Active Change Request:' line -- the boot sequence branches on it (AGENTS.md 4 step 4/5)" -ForegroundColor Red
    $issues++
} else {
    $acr = $acrLine.Groups['v'].Value.Trim().Trim('`')
    if ($acr -match '^None\.?$') {
        Write-Host "  no active Change Request (manifest says '$acr') -- nothing to validate" -ForegroundColor Green
    } else {
        $crPath = Join-Path $RepoRoot $acr
        if (-not (Test-Path $crPath)) {
            Write-Host "  ACTIVE CR MISSING: manifest names '$acr' but no such file exists -- a fresh session following AGENTS.md 4 step 4 has nothing to read" -ForegroundColor Yellow
            $issues++
        } else {
            # Legal vocabulary from the template that defines the field (One Authority), not restated here.
            $tplPath = Join-Path $RepoRoot 'changes/TEMPLATE.md'
            $legal = @()
            if (Test-Path $tplPath) {
                $tplSec = [regex]::Match([IO.File]::ReadAllText($tplPath), '(?ms)^##\s+Status\s*\r?\n(?<b>.*?)(?=^##\s|^---\s*$)')
                if ($tplSec.Success) {
                    # @() is load-bearing, not decoration: a single match makes the pipeline return a
                    # SCALAR STRING, whose .Count is 1 and whose [0] is its first CHARACTER. That exact
                    # slip made this check report a CR in state 'In Progress' as status 'I' -- an
                    # over-firing false positive that the closed-CR and missing-file cases could never
                    # have revealed, because both expect FAIL. Only the open-CR case caught it.
                    $legal = @([regex]::Matches($tplSec.Groups['b'].Value, '(?m)^\s*\[\s*[xX ]\s*\]\s*(?<s>\S[^\r\n]*)') |
                               ForEach-Object { $_.Groups['s'].Value.Trim() })
                }
            }
            $terminal = @('Complete', 'Cancelled')   # CR_LIFECYCLE.md 4
            $crSec = [regex]::Match([IO.File]::ReadAllText($crPath), '(?ms)^##\s+Status\s*\r?\n(?<b>.*?)(?=^##\s|^---\s*$)')
            if (-not $crSec.Success) {
                Write-Host "  ACTIVE CR UNREADABLE: '$acr' has no '## Status' section -- changes/TEMPLATE.md requires one, so its lifecycle state cannot be established" -ForegroundColor Yellow
                $issues++
            } else {
                $checked = @([regex]::Matches($crSec.Groups['b'].Value, '(?m)^\s*\[\s*[xX]\s*\]\s*(?<s>\S[^\r\n]*)') |
                             ForEach-Object { $_.Groups['s'].Value.Trim() })
                if ($checked.Count -ne 1) {
                    Write-Host "  ACTIVE CR AMBIGUOUS: '$acr' has $($checked.Count) checked status boxes -- exactly one is required (changes/TEMPLATE.md)" -ForegroundColor Yellow
                    $issues++
                } elseif ($legal.Count -gt 0 -and $legal -notcontains $checked[0]) {
                    Write-Host "  ACTIVE CR STATUS UNKNOWN: '$acr' is '$($checked[0])', which is not one of the states changes/TEMPLATE.md allows ($($legal -join ', '))" -ForegroundColor Yellow
                    $issues++
                } elseif ($terminal -contains $checked[0]) {
                    Write-Host "  ACTIVE CR IS CLOSED: manifest still points at '$acr', whose own Status is '$($checked[0])' -- a terminal state (CR_LIFECYCLE.md 4). The pointer was not cleared on Complete; a fresh session would be handed finished work as its assignment" -ForegroundColor Yellow
                    Write-Host "  Remedy: set 'Active Change Request: None.' in the manifest (CR_LIFECYCLE.md 9, the Complete command), then regenerate ai-map.json." -ForegroundColor DarkGray
                    $issues++
                } else {
                    Write-Host "  active CR '$acr' is '$($checked[0])' -- open, and its file exists" -ForegroundColor Green
                }
            }
        }
    }
}

# =====================================================================================================
# Check 19: RECOVER-1 -- the repository must CARRY attributable evidence that Primary's migration
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
Write-Host "== Check 19: Primary ledger evidence (RECOVER-1) ==" -ForegroundColor Cyan
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

# =====================================================================================================
# Check 20: CI-1 -- this guard's own workflow must be TRIGGERED by every input this guard READS.
#
# Verified failure class (2026-09-05). The workflow already states the rule, in a comment written
# when Check 19's script and evidence file were found missing from its path filters: "Every file the
# guard reads or executes belongs in these lists." It was stated and then not applied to the three
# remaining inputs. Measured in this script's own source: Check 1 resolves pgTAP references against
# `supabase/tests/`, Check 7 reads `ai-map.json`, Check 9 derives migration state from
# `supabase/migrations/`, Check 15 counts `supabase/tests/*.sql`. None of those three paths appeared
# in `on.push.paths`, so a commit touching ONLY migrations, ONLY tests or ONLY `ai-map.json` changed
# four checks' inputs and ran none of them.
#
# WHAT THIS CHECK IS AND IS NOT. It is a FIXED-LIST check: it asserts the paths known today are
# present, and it CANNOT discover a new input that a future check starts reading -- a guard that
# parsed this script for file reads would be inferring, and inferring wrongly would be worse than
# not checking. That ceiling is the reason the list carries the check numbers that justify each
# entry: adding an input means adding a line here, and the comment says so where the next author
# will read it. Pinning the known regression is worth more than an inference that could be wrong.
#
# Migration CI is deliberately NOT merged into this workflow. It watches two of these paths but runs
# a database stack and never runs this guard; the two validate different evidence classes.
# =====================================================================================================
Write-Host "== Check 20: CI triggers cover this guard's inputs (CI-1) ==" -ForegroundColor Cyan
$ciWorkflow = Join-Path $RepoRoot '.github/workflows/repository-consistency.yml'
if (-not (Test-Path $ciWorkflow)) {
    Write-Host "  MISSING: .github/workflows/repository-consistency.yml -- this guard has no CI trigger at all." -ForegroundColor Red
    $issues++
} else {
    $ciText = Get-Content $ciWorkflow -Raw
    # path -> the check(s) that read it, so a failure says WHY the path matters.
    $requiredTriggers = [ordered]@{
        '**/*.md'                                     = 'Checks 1-6, 10-18, 21, 22 and 23 (every Living/Master document, the disposition record, and every history report)'
        'scripts/check_repository_consistency.ps1'    = 'this script itself'
        'scripts/check_primary_ledger.ps1'            = 'Check 19 executes it'
        'reports/evidence/primary-ledger-evidence.json' = 'Check 19 reads it'
        'supabase/migrations/**'                      = 'Check 9 (migration count, latest, ledger fingerprint)'
        'supabase/tests/**'                           = 'Check 1 (pgTAP reference resolution) and Check 15 (suite figures)'
        'ai-map.json'                                 = 'Check 7 (ai-map freshness vs manifest)'
    }
    # THE GUARD-OF-THE-GUARD SUITES ARE DERIVED FROM THE WORKFLOW, NOT RESTATED HERE (2026-09-09).
    # This job also EXECUTES the mutation suites, and a suite edited without being run is a silent
    # change to what this gate means -- the CI-1 class one file over. The list is read out of the
    # workflow's own `foreach ($suite in ...)` line rather than copied, so adding a fifth suite
    # brings it under the trigger requirement automatically instead of quietly not.
    # The fixed list above stays fixed for the reason its own comment gives: inferring the guard's
    # INPUTS from this script would be a guess. Reading the workflow's EXECUTED suites is not an
    # inference -- it is the workflow's own statement of what it runs.
    $suiteLine = [regex]::Match($ciText, "foreach\s*\(\s*\`$suite\s+in\s+(?<l>[^)]+)\)")
    if ($suiteLine.Success) {
        foreach ($m in [regex]::Matches($suiteLine.Groups['l'].Value, "'(?<s>[A-Za-z0-9_\-]+)'")) {
            $requiredTriggers["scripts/$($m.Groups['s'].Value).ps1"] = "this workflow executes it as a guard-of-the-guard suite"
        }
    } else {
        Write-Host "  CI SUITE LIST UNREADABLE: repository-consistency.yml has no parseable 'foreach (\$suite in ...)' list -- cannot confirm the mutation suites are triggered by their own edits" -ForegroundColor Yellow
        $issues++
    }
    # CI-1b (2026-09-09): PER TRIGGER BLOCK, NOT PER FILE. This check used to ask whether each path
    # string appears ANYWHERE in the workflow, so an entry present on `push` and missing on
    # `pull_request` satisfied it. That is not a hypothetical: `.github/workflows/repository-
    # consistency.yml` and all three guard-of-the-guard suites were on `push` alone, so a PR touching
    # only a detector's calibration changed what this gate MEANS without running it -- and this check,
    # whose entire subject is "every input the guard reads must trigger the guard", printed CLEAN.
    # A guard that greps a file cannot see which of two lists a line is in. Same class as GUARD-CRLF-1
    # (measuring line endings instead of size) and VER-1 (measuring source text instead of execution):
    # the measurement was of the wrong object. Both blocks are now extracted and judged separately.
    # Line-based rather than one large regex: the blocks legitimately carry comment lines between the
    # event key and `paths:`, and between the items, and a single pattern that tolerates all of that
    # is harder to read than the thing it measures. Scan state: which event we are inside, and
    # whether we have reached its `paths:` list.
    $blocks = [ordered]@{ 'push' = $null; 'pull_request' = $null }
    $curEvent = $null
    $inPaths  = $false
    foreach ($line in ($ciText -split "`r?`n")) {
        if ($line -match '^\s*#') { continue }                       # comment: never a key or an item
        if ($line -match '^  (?<k>[A-Za-z_]+):\s*$') {               # a two-space key starts a new event
            $curEvent = $Matches['k']; $inPaths = $false
            if ($blocks.Contains($curEvent) -and $null -eq $blocks[$curEvent]) { $blocks[$curEvent] = @() }
            continue
        }
        if ($line -match '^\S') { $curEvent = $null; $inPaths = $false; continue }   # top-level key ends the section
        if ($null -eq $curEvent -or -not $blocks.Contains($curEvent)) { continue }
        if ($line -match '^\s{4}paths:\s*$') { $inPaths = $true; continue }
        if ($line -match '^\s{4}\S') { $inPaths = $false }           # a sibling key of `paths:`
        if ($inPaths -and $line -match '^\s{6}-\s*"(?<p>[^"]+)"\s*$') { $blocks[$curEvent] += $Matches['p'] }
    }
    foreach ($ev in $blocks.Keys) {
        if ($null -eq $blocks[$ev]) {
            Write-Host "  CI TRIGGER BLOCK UNREADABLE: repository-consistency.yml has no parseable 'on.$ev.paths' list -- this check cannot prove the guard is triggered at all" -ForegroundColor Yellow
            $issues++
            continue
        }
        foreach ($p in $requiredTriggers.Keys) {
            if ($blocks[$ev] -notcontains $p) {
                Write-Host "  CI TRIGGER GAP: '$p' is not in repository-consistency.yml on.$ev.paths -- $($requiredTriggers[$p]). A change touching only this path would alter the guard's input without running the guard." -ForegroundColor Yellow
                $issues++
            }
        }
    }
    # The two lists must also AGREE. A path that earns a run on push earns one on a pull request, and
    # the divergence above arrived precisely by adding to one list and forgetting the other. Compared
    # symmetrically so neither direction can drift silently.
    $asymmetry = 0
    if ($blocks['push'] -and $blocks['pull_request']) {
        foreach ($pair in @(@('push', 'pull_request'), @('pull_request', 'push'))) {
            foreach ($p in ($blocks[$pair[0]] | Where-Object { $blocks[$pair[1]] -notcontains $_ })) {
                Write-Host "  CI TRIGGER ASYMMETRY: '$p' triggers on $($pair[0]) but not on $($pair[1]) -- the same change is gated on one event and unguarded on the other" -ForegroundColor Yellow
                $issues++; $asymmetry++
            }
        }
    }
    # Say what was measured. A check that prints nothing on success is indistinguishable from one
    # that parsed nothing, which is the whole defect above.
    if ($blocks['push'] -and $blocks['pull_request'] -and $asymmetry -eq 0) {
        Write-Host "  push ($($blocks['push'].Count) paths) and pull_request ($($blocks['pull_request'].Count) paths) both cover all $($requiredTriggers.Count) guard inputs, and agree with each other" -ForegroundColor Green
    }
}

Write-Host ""
# =====================================================================================================
# Check 21: STALE-1 -- a current-state document's FRESHNESS METADATA must not contradict its own body.
#
# Verified failure class, and this is at least its FOURTH occurrence:
#   2026-07-14  `session-discovery-checkpoint` F2 -- MASTER_ARCHITECTURE_DECISIONS.md:5 "stale vs
#               content", recorded and hand-fixed.
#   2026-07-15  MASTER_GAP_REGISTER.md header "2026-07-11" over rows the Recovery had just moved.
#   2026-08-29  MASTER_GAP_REGISTER.md again -- rows dated 08-24..08-29 under "Last updated:
#               2026-08-21"; and MASTER_EXECUTION_PLAN.md's own header read "2026-07-15" while its
#               Batch 6 ran to 2026-08-29. Both fixed by hand, both recorded, neither guarded.
#   2026-09-05  MASTER_EXECUTION_PLAN.md header "2026-09-02" over a P3 entry dated 2026-09-05.
# Four hand-fixes of one class is the definition of a missing fitness function. This is that function.
#
# THE INVARIANT IS SEMANTIC, NOT AGE-BASED, and deliberately so:
#     a document's freshness date must not be OLDER than the newest date its own body carries.
# It says nothing about today. A document nobody has touched since July passes forever, because its
# header still describes its content truthfully -- which is what "fresh" has to mean for a document
# that is legitimately finished. "Last updated must equal today" would fail every stable document in
# the repository every single day, and a guard that is always red teaches people to ignore it.
# It fires on exactly one event: SOMEONE ADDED DATED CONTENT AND LEFT THE HEADER BEHIND. That is the
# whole failure class above, and Check 12 (no future dates) already bounds the other direction, so
# the pair brackets the header from both sides.
#
# WHY VALIDATION AND NOT GENERATION. Deriving the field from `git log -1 --format=%ad` was considered
# and rejected on what the field actually holds. Every one of these headers is a date PLUS a written
# account of what changed and why -- `MASTER_GAP_REGISTER.md`'s runs to a paragraph. Git can supply
# the date and nothing else, so a generator would either destroy the annotation or write a date beside
# a paragraph that no longer matches it -- a NEW contradiction in the same field. Worse, git's date is
# the date of ANY touch: a typo fix would advertise itself as a substantive update, and the field would
# stop meaning what its readers use it for. The annotation is human authorship; only its CONSISTENCY
# is mechanisable. So: humans keep writing the field, and the machine refuses to let it contradict.
#
# WHAT THIS CHECK DOES NOT DO (MEAS-1 -- a guard must not be described more strongly than it measures):
#   * It does not require any document to CARRY freshness metadata. Scope is self-selecting -- a file
#     with the field is guarded, a file without it makes no freshness claim to contradict. Requiring
#     the field would mean maintaining a list of which documents must have it, i.e. one more registry
#     to go stale, to guard the staleness of registries.
#   * It cannot see a substantive change that carries no date. Rewriting a paragraph and dating
#     nothing passes here. Undetectable without judging meaning; stated rather than papered over.
#   * It says nothing about whether the ANNOTATION beside the date is true. Check 2, 14, 16 and 18
#     each judge a different claim's truth; this one judges only internal date consistency.
# =====================================================================================================
Write-Host "== Check 21: freshness metadata vs the document's own content (STALE-1) ==" -ForegroundColor Cyan
# Every shape the repository actually uses to date a document's own head, and no invented ones:
#   `Last updated:`   -- 16 Master/evidence documents
#   `Last measured:`  -- MASTER_REPOSITORY_HEALTH.md, which measures rather than updates
#   `Version N · d`   -- GOVERNANCE.md alone, whose §15 requires the version line and the top
#                        changelog entry to move together. Included because it is the same claim in
#                        the same class, in the one document that DECLARES the rule (§6 rule 8);
#                        leaving the rule's own home unguarded is how a rule becomes decorative.
# Matched at line start within the head of the file, so the field is the document's own metadata and
# not a sentence in a change record quoting one -- `changes/SPEC-125` contains "Last updated"
# mid-prose and must not be read as a freshness claim.
$freshHeaderRx = '^\s*\**(?:Last (?:updated|measured)\**:|Version\**\s*[0-9]+(?:\.[0-9]+)*\s*[^0-9\s]{1,3})\s*\**(20[0-9]{2}-[01][0-9]-[0-3][0-9])'
$bodyDateRx    = '\b(20[0-9]{2}-[01][0-9]-[0-3][0-9])\b'
$staleHeaders  = 0
$freshChecked  = 0
foreach ($f in ($allFiles | Where-Object { $_.Extension -eq '.md' })) {
    $lines = [System.IO.File]::ReadAllLines($f.FullName)
    $hdrDate = $null
    for ($i = 0; $i -lt [Math]::Min(12, $lines.Count); $i++) {
        if ($lines[$i] -match $freshHeaderRx) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParseExact($Matches[1], 'yyyy-MM-dd', $null, 'None', [ref]$parsed)) { $hdrDate = $parsed }
            break
        }
    }
    if ($null -eq $hdrDate) { continue }
    $freshChecked++
    $newest = $hdrDate
    $newestLine = 0
    $ln = 0
    foreach ($line in $lines) {
        $ln++
        foreach ($m in [regex]::Matches($line, $bodyDateRx)) {
            $d = [datetime]::MinValue
            if ([datetime]::TryParseExact($m.Groups[1].Value, 'yyyy-MM-dd', $null, 'None', [ref]$d) -and $d -gt $newest) {
                $newest = $d
                $newestLine = $ln
            }
        }
    }
    if ($newestLine -gt 0) {
        $rel = $f.FullName.Substring($RepoRoot.Length + 1)
        Write-Host "  STALE FRESHNESS METADATA: $rel declares $($hdrDate.ToString('yyyy-MM-dd')) but line $newestLine carries $($newest.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
        $staleHeaders++
    }
}
if ($staleHeaders -gt 0) {
    Write-Host "  Remedy: record the newer state in the header the way these documents already do -- write a NEW dated line" -ForegroundColor DarkGray
    Write-Host "  saying what changed and demote the old one to 'Previously:'. Do not simply overwrite the date: the annotation" -ForegroundColor DarkGray
    Write-Host "  beside it is the cumulative history, and this repository keeps history rather than replacing it." -ForegroundColor DarkGray
    $issues += $staleHeaders
} else {
    Write-Host "  all $freshChecked document(s) carrying freshness metadata agree with their own newest dated content" -ForegroundColor Green
}

Write-Host ""
# =====================================================================================================
# Check 22: DISP-1 -- the surface disposition record must cover exactly the surfaces that exist, and
# every pointer in it must resolve.
#
# WHY IT EXISTS. Batch 6's exit criterion EC-1 is a per-surface audit disposition record, and the
# reason it is the FIRST criterion is that without one the coverage question has no honest answer.
# Two proxies were measured and both were worthless: all 77 tables are named somewhere in
# `reports/**` (so "mentioned" is saturated), and 75 of 77 are named in some pgTAP file (a floor -- a
# table named once in an unrelated fixture is not a swept surface). A hand-maintained record would
# rot the moment a migration adds a table, which is the STALE-1 class one file over. So the surface
# SET is derived, and only the dispositions are written.
#
# FOUR THINGS, because a coverage record can lie in four different ways:
#   (a) it names a surface that does not exist          -> the record has drifted from the schema
#   (b) it omits a surface that does exist              -> the coverage denominator is understated
#   (c) a Disposition/Assurance value is off-vocabulary -> the count means nothing
#   (d) a Session or Findings pointer does not resolve  -> the evidence is not there
#
# CEILING, stated in the file too (MEAS-1). The surface set is derived by parsing `create table` /
# `drop table` out of `supabase/migrations/**`. A table created by dynamic SQL, or renamed by
# `ALTER TABLE ... RENAME`, would fool it. That is bounded rather than open: `verify_database.sql`
# and `check_database_parity.ps1` both read the live catalog and would catch the divergence from the
# other side. This check cannot open a database -- none of them here can -- so a text derivation with
# a stated ceiling is the honest instrument, not a weaker one pretending to be strong.
#
# It does NOT judge whether a disposition is TRUE. Nothing mechanical can read "AUDITED" and know
# whether the audit happened; that is what the named immutable session report is for.
# =====================================================================================================
Write-Host "== Check 22: surface disposition record covers what exists (DISP-1) ==" -ForegroundColor Cyan
$dispPath = Join-Path $RepoRoot 'reports/master/MASTER_SURFACE_DISPOSITION.md'
if (-not (Test-Path $dispPath)) {
    Write-Host "  MISSING: reports/master/MASTER_SURFACE_DISPOSITION.md -- Batch 6 exit criterion EC-1 has no record." -ForegroundColor Red
    $issues++
} else {
    $migDir = Join-Path $RepoRoot 'supabase/migrations'
    $migText = ((Get-ChildItem $migDir -Filter *.sql -File | Sort-Object Name | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n")
    # `(?!\s*\.)` keeps `create table app.x` out: without it the optional `public.` prefix lets the
    # schema name itself be captured as a table.
    $mkRx = '(?im)^\s*create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-z_][a-z0-9_]*)(?!\s*\.)\s*\('
    $rmRx = '(?im)^\s*drop\s+table\s+(?:if\s+exists\s+)?(?:public\.)?([a-z_][a-z0-9_]*)(?!\s*\.)'
    $made = @([regex]::Matches($migText, $mkRx) | ForEach-Object { $_.Groups[1].Value })
    $gone = @([regex]::Matches($migText, $rmRx) | ForEach-Object { $_.Groups[1].Value })
    $expected = @($made | Where-Object { $gone -notcontains $_ } | Sort-Object -Unique)

    $registerPath = Join-Path $RepoRoot 'reports/master/MASTER_GAP_REGISTER.md'
    $registerText = if (Test-Path $registerPath) { [System.IO.File]::ReadAllText($registerPath) } else { '' }
    $okDisposition = @('NOT-RECORDED', 'AUDITED', 'AUDITED-OPEN', 'PARTIAL', 'EXEMPT')
    $okAssurance   = @('—', '-', 'TESTED', 'ADVERSARIAL')
    $listed = @()
    $dispositionCounts = @{}
    $adversarialCount = 0
    $dispIssues = 0
    foreach ($line in [System.IO.File]::ReadAllLines($dispPath)) {
        # `-cnotmatch`, not `-notmatch`: PowerShell's default comparison is CASE-INSENSITIVE, so the
        # lowercase pattern also matched the two uppercase VOCABULARY tables in this file's header
        # (`| AUDITED | ... |`) and reported five phantom surfaces on the first run. Table names are
        # lower_snake_case by convention (`CODING_STANDARDS.md`), so case is the discriminator.
        if ($line -cnotmatch '^\|\s*`([a-z_][a-z0-9_]*)`\s*\|') { continue }
        $surface = $Matches[1]
        $listed += $surface
        $cells = @($line.Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 6) {
            Write-Host "  MALFORMED ROW: $surface has $($cells.Count) cells, expected 6 (Surface, Disposition, Assurance, Session, Findings, Next)" -ForegroundColor Yellow
            $dispIssues++
            continue
        }
        $disp = ($cells[1] -replace '\*', '').Trim()
        $assr = ($cells[2] -replace '\*', '').Trim()
        $dispositionCounts[$disp] = 1 + [int]$dispositionCounts[$disp]
        if ($assr -eq 'ADVERSARIAL') { $adversarialCount++ }
        if ($okDisposition -notcontains $disp) {
            Write-Host "  OFF-VOCABULARY DISPOSITION: $surface -> '$disp' (allowed: $($okDisposition -join ', '))" -ForegroundColor Yellow
            $dispIssues++
        }
        if ($okAssurance -notcontains $assr) {
            Write-Host "  OFF-VOCABULARY ASSURANCE: $surface -> '$assr' (allowed: $($okAssurance -join ', ')). EXHAUSTIVE is deliberately not a per-surface value." -ForegroundColor Yellow
            $dispIssues++
        }
        $sess = ($cells[3] -replace '`', '').Trim()
        if ($sess -notin @('—', '-') -and -not $fileNames.ContainsKey(($sess + '.md').ToLower())) {
            Write-Host "  UNRESOLVED SESSION POINTER: $surface cites '$sess', which is not a file in this repository" -ForegroundColor Yellow
            $dispIssues++
        }
        $find = ($cells[4] -replace '\*', '').Trim()
        if ($find -notin @('—', '-')) {
            foreach ($id in ($find -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
                if ($registerText -notmatch [regex]::Escape($id)) {
                    Write-Host "  UNREGISTERED FINDING: $surface cites '$id', which has no row in MASTER_GAP_REGISTER.md" -ForegroundColor Yellow
                    $dispIssues++
                }
            }
        }
    }
    $listed = @($listed | Sort-Object -Unique)
    # The rows own the totals. Check the current Coverage section, never dated history.
    $dispText = [IO.File]::ReadAllText($dispPath)
    $coverage = [regex]::Match($dispText, '(?ms)^## Coverage\s*\n(.*?)(?=^## |\z)').Groups[1].Value
    $recorded = $listed.Count - [int]$dispositionCounts['NOT-RECORDED']
    $summary = [regex]::Match($coverage, '(\d+) of (\d+) recorded')
    if (-not $summary.Success -or [int]$summary.Groups[1].Value -ne $recorded -or [int]$summary.Groups[2].Value -ne $listed.Count) {
        Write-Host "  COVERAGE TOTAL DRIFT: recorded summary must be $recorded of $($listed.Count)" -ForegroundColor Yellow
        $dispIssues++
    }
    foreach ($value in $okDisposition) {
        $countMatch = [regex]::Match($coverage, '(\d+) `' + [regex]::Escape($value) + '`')
        if (-not $countMatch.Success -or [int]$countMatch.Groups[1].Value -ne [int]$dispositionCounts[$value]) {
            Write-Host "  COVERAGE TOTAL DRIFT: $value must be $([int]$dispositionCounts[$value])" -ForegroundColor Yellow
            $dispIssues++
        }
    }
    $assuranceMatch = [regex]::Match($coverage, 'All (\d+) recorded surfaces stand at `ADVERSARIAL`')
    if (-not $assuranceMatch.Success -or [int]$assuranceMatch.Groups[1].Value -ne $adversarialCount -or $adversarialCount -ne $recorded) {
        Write-Host "  COVERAGE TOTAL DRIFT: ADVERSARIAL summary disagrees with the disposition rows" -ForegroundColor Yellow
        $dispIssues++
    }
    foreach ($ghost in ($listed | Where-Object { $expected -notcontains $_ })) {
        Write-Host "  PHANTOM SURFACE: '$ghost' has a disposition row but no migration creates it" -ForegroundColor Yellow
        $dispIssues++
    }
    foreach ($missing in ($expected | Where-Object { $listed -notcontains $_ })) {
        Write-Host "  UNCOVERED SURFACE: '$missing' exists in supabase/migrations but has no disposition row -- add it as NOT-RECORDED" -ForegroundColor Yellow
        $dispIssues++
    }
    if ($dispIssues -gt 0) {
        $issues += $dispIssues
    } else {
        Write-Host "  all $($expected.Count) migration-derived surfaces have a disposition row; every vocabulary value, session and finding pointer resolves" -ForegroundColor Green
    }
}

Write-Host ""
# =====================================================================================================
# Check 23: HANDOFF-1 -- a session report written under the HANDOFF rule must actually carry one.
#
# `AGENTS.md §6` requires every session report to open with a HANDOFF block answering seven questions
# -- INHERITED, PROVEN, UNPROVEN, CHANGED, REMAINING, DO NOT TOUCH, NEXT -- because that block is the
# whole LLM-agnostic continuity mechanism: a fresh session with no conversational memory reads
# `reports/README.md`'s pointer, opens the named report, and inherits from those seven lines. The rule
# was written on 2026-09-05 and nothing measured it, which is the documentation-stronger-than-the-
# measurement class (MEAS-1) applied to the one document a cold start depends on most.
#
# FORWARD-ONLY, and that is not a loophole. `GOVERNANCE.md §6` rule 3 makes historical reports
# immutable; 123 of the 128 reports predate the rule and MUST NOT be retrofitted, because editing an
# immutable record to satisfy a later convention is a worse defect than the one being fixed. The
# check therefore reads each report's own `Date:` field and applies the rule only from the date the
# rule exists. A report with no parseable Date is skipped rather than guessed at -- Check 4 already
# owns whether a report declares itself at all.
# =====================================================================================================
Write-Host "== Check 23: session reports carry their HANDOFF block (HANDOFF-1) ==" -ForegroundColor Cyan
$handoffRuleDate = [datetime]'2026-09-05'
$handoffFields = @('INHERITED', 'PROVEN', 'UNPROVEN', 'CHANGED', 'REMAINING', 'DO NOT TOUCH', 'NEXT')
$historyDir = Join-Path $RepoRoot 'reports/history'
$handoffIssues = 0
$handoffChecked = 0
if (Test-Path $historyDir) {
    foreach ($rep in (Get-ChildItem $historyDir -Filter *.md -File)) {
        $text = [System.IO.File]::ReadAllText($rep.FullName)
        $head = ($text -split "`n" | Select-Object -First 12) -join "`n"
        if ($head -notmatch '(?im)^\s*Date:\s*(20[0-9]{2}-[01][0-9]-[0-3][0-9])') { continue }
        $repDate = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($Matches[1], 'yyyy-MM-dd', $null, 'None', [ref]$repDate)) { continue }
        if ($repDate -lt $handoffRuleDate) { continue }
        $handoffChecked++
        if ($text -notmatch '(?i)HANDOFF') {
            Write-Host "  NO HANDOFF BLOCK: reports/history/$($rep.Name) is dated $($repDate.ToString('yyyy-MM-dd')) -- on or after the rule -- and has none. A fresh session inherits nothing from it." -ForegroundColor Yellow
            $handoffIssues++
            continue
        }
        # `\b` rather than a fixed punctuation set: the field labels are written as `**PROVEN
        # (behavioural evidence, this session):**` as often as `**CHANGED:**`, and requiring a
        # colon-or-comma immediately after the word reported PROVEN missing from all five reports
        # that carry it. The `\*\*` prefix is what keeps `**UNPROVEN` from satisfying `PROVEN`.
        $absent = @($handoffFields | Where-Object { $text -notmatch ('(?i)\*\*' + [regex]::Escape($_) + '\b') })
        if ($absent.Count -gt 0) {
            Write-Host "  INCOMPLETE HANDOFF: reports/history/$($rep.Name) is missing $($absent -join ', ')" -ForegroundColor Yellow
            $handoffIssues++
        }
    }
}
if ($handoffIssues -gt 0) {
    Write-Host "  The seven fields are AGENTS.md §6's, and DO NOT TOUCH is the one this repository lacked:" -ForegroundColor DarkGray
    Write-Host "  a boundary stated by the session that found it, so the next agent does not reopen a settled question." -ForegroundColor DarkGray
    $issues += $handoffIssues
} else {
    Write-Host "  all $handoffChecked report(s) written under the HANDOFF rule carry a complete seven-field block" -ForegroundColor Green
}

Write-Host ""
# =====================================================================================================
# Check 24: ADV-1 -- `ADVERSARIAL` must be EARNED, not typed.
#
# The disposition record's assurance column is the strongest claim Batch 6 makes per surface, and
# before this check the word `ADVERSARIAL` cost exactly one keystroke. That is the shape of every
# defect this repository keeps finding in its own measuring layer (MEAS-1): a claim recorded in one
# place while the evidence for it lives, unchecked, somewhere else.
#
# THREE THINGS MUST HOLD for a surface recorded ADVERSARIAL, and each closes a different lie:
#   (a) some pgTAP file NAMES the surface           -- otherwise nothing was aimed at it at all
#   (b) that file declares `-- ATTACK-CLASSES: ...` -- otherwise which assumptions were attacked is
#       unrecorded, and the next session cannot tell a considered exclusion from an oversight
#   (c) that file contains a NEGATIVE assertion     -- `throws_ok`. A file of positive controls is
#       TESTED, never ADVERSARIAL, and LIC-2/SPP-2/FIN-3 were all found hiding behind exactly that.
#
# The class vocabulary is CLOSED so slices stay comparable, and `CLASS=N/A` is a first-class value:
# stating why a class does not apply to a surface is a position, and positions can be argued with,
# whereas silence cannot. A misspelled class fails rather than being silently ignored.
#
# WHAT IT CANNOT DO, stated because a registry that oversells a guard is the failure it exists to
# prevent. It cannot tell whether the declared classes were attacked WELL, or whether the negative
# assertions are the ones that matter, or whether `AUTH` in one file means what `AUTH` means in
# another. It measures that the evidence EXISTS and is declared -- the named immutable session report
# is what says whether it is any good.
# =====================================================================================================
Write-Host "== Check 24: ADVERSARIAL is earned, not typed (ADV-1) ==" -ForegroundColor Cyan
$attackClasses = @('AUTH','TENANT','DOOR','STATE','INPUT','BUSINESS','CONCURRENCY','REPLAY','PRIVILEGE','OBSERVABILITY')
$testDir = Join-Path $RepoRoot 'supabase/tests'
$advIssues = 0
$advChecked = 0
if ((Test-Path $dispPath) -and (Test-Path $testDir)) {
    $testFiles = @{}
    foreach ($tf in (Get-ChildItem $testDir -Filter *.sql -File)) {
        $body = [System.IO.File]::ReadAllText($tf.FullName)
        $declared = $null
        if ($body -match '(?m)^\s*--\s*ATTACK-CLASSES:\s*(.+)$') { $declared = $Matches[1].Trim() }
        $testFiles[$tf.Name] = @{ body = $body; declared = $declared; negative = ($body -match 'throws_ok') }
    }

    # Every declaration anywhere must use the closed vocabulary -- checked across ALL files, not only
    # the ones a surface happens to point at, so a typo cannot hide in an unreferenced file.
    foreach ($name in ($testFiles.Keys | Sort-Object)) {
        $d = $testFiles[$name].declared
        if ($null -eq $d) { continue }
        foreach ($tok in ($d -split '\s+' | Where-Object { $_ })) {
            $cls = ($tok -split '=')[0]
            if ($attackClasses -notcontains $cls) {
                Write-Host "  UNKNOWN ATTACK CLASS: supabase/tests/$name declares '$cls' (allowed: $($attackClasses -join ', '), each optionally '=N/A')" -ForegroundColor Yellow
                $advIssues++
            }
        }
    }

    foreach ($line in [System.IO.File]::ReadAllLines($dispPath)) {
        if ($line -cnotmatch '^\|\s*`([a-z_][a-z0-9_]*)`\s*\|') { continue }
        $surface = $Matches[1]
        $cells = @($line.Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 3) { continue }
        if (($cells[2] -replace '\*', '').Trim() -ne 'ADVERSARIAL') { continue }
        $advChecked++

        $naming = @($testFiles.Keys | Where-Object { $testFiles[$_].body -match ('\b' + [regex]::Escape($surface) + '\b') })
        if ($naming.Count -eq 0) {
            Write-Host "  ADVERSARIAL WITHOUT A TEST: '$surface' is recorded ADVERSARIAL and no pgTAP file names it" -ForegroundColor Yellow
            $advIssues++
            continue
        }
        $withDecl = @($naming | Where-Object { $testFiles[$_].declared })
        if ($withDecl.Count -eq 0) {
            Write-Host "  ADVERSARIAL WITHOUT DECLARED CLASSES: '$surface' -- no file naming it carries an '-- ATTACK-CLASSES:' line, so which assumptions were attacked is unrecorded" -ForegroundColor Yellow
            $advIssues++
            continue
        }
        if (-not ($withDecl | Where-Object { $testFiles[$_].negative })) {
            Write-Host "  ADVERSARIAL WITHOUT NEGATIVE EVIDENCE: '$surface' -- the declaring file(s) contain no throws_ok. Positive controls make a surface TESTED, never ADVERSARIAL" -ForegroundColor Yellow
            $advIssues++
        }
    }
}
if ($advIssues -gt 0) {
    Write-Host "  Remedy: either attack the surface and record the classes, or lower the assurance to TESTED." -ForegroundColor DarkGray
    Write-Host "  Lowering it is not a defeat -- an honest TESTED is worth more than an ADVERSARIAL nothing measured." -ForegroundColor DarkGray
    $issues += $advIssues
} else {
    Write-Host "  all $advChecked surface(s) recorded ADVERSARIAL carry a declaring test file with negative assertions" -ForegroundColor Green
}


# Check 25: GOV-16 -- the manifest's open-decision line must carry every decision the register is
#     still waiting on. Check 11 runs manifest -> register ("does this id exist?"); NOTHING ran the
#     other way, so a finding could be registered as an open OWNER/BUSINESS/COUNSEL/CANON question
#     and be invisible to a fresh session, which reads the manifest and not a 1,700-line register.
#     Measured on 2026-09-07: SEVEN such rows existed and the manifest named ONE.
#
#     WHY THIS TOOK THREE ATTEMPTS TO BE WRITABLE, recorded because the reason is the design:
#     GOV-16 first said "bind the open ROWS to the line", and the 2026-09-04 census proved that
#     naive: of the ~100 non-closed rows, 69 are scheduling backlog. A guard demanding the manifest
#     carry 100 ids would have destroyed the boot line to satisfy a checkbox. The register's own
#     conclusion was "compare DECISIONS, not open rows", and it stopped there because no mechanical
#     signal for "decision" had been found.
#
#     The signal was already there, in the register's own eleventh column. `Owner Decision` is
#     free text, but it is written in two distinct registers: it either NAMES A DECIDER
#     ("owner:", "business:", "canon:", "owner + counsel:") or it carries a scheduling word
#     ("pending", "done", "cert-2026-07", "-"). The first is a decision; the second is a queue
#     position. That distinction is the census's finding, made executable.
#
#     ITS CEILING, stated because a guard that oversells itself is the class this repository keeps
#     rediscovering: this reads a PROSE column, so a row that names its decider in words this regex
#     does not know is invisible to it. It is a floor on honesty, not a proof of completeness -- it
#     cannot find a decision nobody wrote down. What it does guarantee is that a decision written
#     down IN THE ESTABLISHED FORM cannot sit unsurfaced, which is the failure that actually
#     happened seven times.
Write-Host "== Check 25: registered decisions reach the manifest's boot line (GOV-16) ==" -ForegroundColor Cyan
if (-not $decisionLine) {
    Write-Host "  MANIFEST has no 'Open owner decisions' line -- cannot verify" -ForegroundColor Red
    $issues++
} else {
    # 2026-09-09: `$onLine` used to be scraped from the WHOLE manifest line, which meant a NARRATIVE
    # mention of an id silently exempted that decision from ever being surfaced -- the exact failure
    # this check exists to prevent, reachable by writing the id in a sentence. It now consumes
    # $openDecisionIds, the enumeration alone (see the shared parse above).
    $onLine = $openDecisionIds
    # A row is SETTLED if its status field says so, ANCHORED at the field's opening.
    #
    # THIS WAS THE LIVE DEFECT (2026-09-09). The pattern here was a private vocabulary matched
    # ANYWHERE in the first 80 characters. Narrowing the window to 80 bounded the MEAS-2 class this
    # check's own comment claims to have fixed; it did not close it, because the register's terminal
    # NON-resolutions are written with the resolved words inside them. Measured: `ARCH-2`, `DEAD-4`,
    # `SYNC-1`, `ORIG-1`, `JE-2`, `GOV-9`, `PLACE-2` and `CAP-1` all OPEN with `OPEN` / `RECORDED` /
    # `UNPROVEN` and were read as SETTLED because "deliberately NOT **FIXED**" contains FIXED. Any
    # one of them acquiring a decider would have been exempted from this gate on a substring.
    # Anchoring is the fix, and it is what Checks 2 and 14 have always done.
    #
    # BOTH SUBSTRATES, and the same $statusResolvedLead vocabulary Check 14 uses. Check 25 read table
    # rows only, so it agreed with Check 14 only by accident; the two ask INVERSE questions of the
    # same rows and a disagreement is unfixable by any edit (remove the id and one fires; add it back
    # and the other does). Measured before this repair: they disagreed on 14 rows.
    # The SAME two signals Check 14 consumes, from the SAME single pass, combined the other way round.
    # `$registerState` is already computed at Check 14 above; it is recomputed here only if this
    # script is ever re-ordered, which is cheap and keeps the two checks independent of sequence.
    if (-not $registerState) {
        $registerState = Get-RegisterFindingState -Path $registerPathShared -IdPattern $idPat.Trim('\b') `
                                                  -SettledLead $statusResolvedLead -DeciderRx $registerDeciderRx
    }
    $unsurfaced = @()
    foreach ($id in ($registerState.Keys | Sort-Object)) {
        if (-not $registerState[$id].Decider) { continue }   # not a decision -- a scheduling position
        if ($registerState[$id].Settled)      { continue }   # decided already
        if ($onLine -contains $id)            { continue }   # already on the boot line
        $unsurfaced += $id
    }
    $unsurfaced = @($unsurfaced | Sort-Object -Unique)
    if ($unsurfaced.Count -gt 0) {
        foreach ($u in $unsurfaced) {
            Write-Host "  UNSURFACED DECISION: register entry '$u' waits on $($registerState[$u].Decider) and the manifest's open-decision line does not name it" -ForegroundColor Red
        }
        Write-Host "  Remedy: add the id to the manifest's open-decision line -- INSIDE THE ENUMERATION, before its first" -ForegroundColor DarkGray
        Write-Host "  full stop. Ids written into the prose AFTER that point are narrative and are not read as state." -ForegroundColor DarkGray
        Write-Host "  Or -- if it is NOT a decision -- rewrite its Owner-Decision field to say what it actually is. Do not" -ForegroundColor DarkGray
        Write-Host "  silence it by resolving an entry that is not resolved: a decision nobody can see at boot is how" -ForegroundColor DarkGray
        Write-Host "  MAIL-1's six siblings hid." -ForegroundColor DarkGray
        $issues += $unsurfaced.Count
    } else {
        $liveDecisions = @($registerState.Keys | Where-Object { $registerState[$_].Decider -and -not $registerState[$_].Settled })
        Write-Host "  all $($liveDecisions.Count) register entr(ies) awaiting a decider are named on the manifest's boot line (of $($registerState.Count) findings read across table rows and detail blocks)" -ForegroundColor Green
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
    Write-Host "   Check 19 verifies the RECORDED Primary ledger reading, not a live one." -ForegroundColor DarkGray
    Write-Host "   For live local-vs-Primary surface parity run scripts/check_database_parity.ps1)" -ForegroundColor DarkGray
    exit 0
} else {
    Write-Host "REPOSITORY CONSISTENCY: $issues issue(s) found" -ForegroundColor Red
    exit 1
}
