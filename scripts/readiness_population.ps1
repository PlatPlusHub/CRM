# ORVION Pre-Production Readiness Closure gate -- population derivation and the action registry.
#
# `reports/master/MASTER_EXECUTION_PLAN.md` owns the gate and the rule that derives its population;
# this script executes that rule, so an evaluation re-derives the population instead of remembering
# it. The population is the union of:
#   * every finding in `reports/master/MASTER_GAP_REGISTER.md` (a table row in a table with a
#     `Status` column, or a `###` block) whose status does not open with the settled vocabulary;
#   * every surface `reports/master/MASTER_SURFACE_DISPOSITION.md` records as AUDITED-OPEN or PARTIAL;
#   * every id on the manifest's open-decision line.
# It then reports which derived finding ids the gate section does not classify, and which ids the
# section names that the register has since settled (closure progress, or a stale reading).
#
# ONE AUTHORITY. The id pattern, both status vocabularies, the decision-line pattern and the register
# state resolver are READ FROM `scripts/check_repository_consistency.ps1` at run time (its AST), never
# copied: a copy would drift from the guard that owns them. If one of them stops existing there, this
# script fails loudly (AUTHORITY_MOVED) instead of deriving with a stale rule. The universe of ids and
# the surface and decision-line row rules mirror that script's own readers, cited where each is used.
#
# It decides nothing: READY is the gate's five criteria, judged by the evaluator. The section's
# ### Action registry (SPEC-269) classifies every member in one table and names each one's latest
# safe boundary in another; this script derives each id's trigger state from the two, by the rules
# that section states. Exit 1 means the registry is incomplete, contradictory or overdue: an open
# member no row classifies, an id two rows classify, a row naming an unknown id, a class or boundary
# outside the section's vocabularies, an empty Decides or Treatment cell, or an open id whose
# boundary is REACHED. Since SPEC-270 it also derives two members no row needs: every NOT-RECORDED
# surface (EC-1, boundary -SurfaceBoundary) and every row of the backlog's '## Live deferred items'
# table; a backlog row without a known boundary, or with a REACHED one, also exits 1. Check 29 of scripts/check_repository_consistency.ps1 runs this script, so
# every guard run (Boot, Gate, -Finish, CI) enforces it; scripts/readiness_selftest.ps1 proves it.
#
# Usage:
#   pwsh -NoProfile -File scripts/readiness_population.ps1                 # the working tree
#   pwsh -NoProfile -File scripts/readiness_population.ps1 -Ref 523888d   # as of a commit (replay)
#   pwsh -NoProfile -File scripts/readiness_population.ps1 -Registry      # one line per member, with its state
param(
    [string]$Ref,
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [string]$Tsv,
    [switch]$IncludeSettled,   # -Tsv also lists the settled register findings (the whole universe)
    [switch]$Registry,         # print every registry member with its derived trigger state
    # Input overrides, used by scripts/readiness_selftest.ps1 to run the rule on fixtures.
    [string]$RegisterPath = 'reports/master/MASTER_GAP_REGISTER.md',
    [string]$SurfacePath = 'reports/master/MASTER_SURFACE_DISPOSITION.md',
    [string]$ManifestPath = '_ORVION_CANONICAL/manifest.md',
    [string]$PlanPath = 'reports/master/MASTER_EXECUTION_PLAN.md',
    [string]$BacklogPath = 'reports/future-backlog.md',
    [string]$AuthorityPath = 'scripts/check_repository_consistency.ps1',
    [string]$SectionHeading = '## Pre-Production Readiness Closure gate',
    # EC-1 (SPEC-270): the boundary before which every NOT-RECORDED surface must carry a disposition.
    [string]$SurfaceBoundary = 'B6-EXIT'
)
$ErrorActionPreference = 'Stop'
function Read-Input([string]$Rel) {
    if ($Ref) {
        $text = (git -C $Root show "${Ref}:$Rel" 2>$null) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "INPUT_MISSING: $Rel at $Ref" }
        return $text
    }
    $path = if ([IO.Path]::IsPathRooted($Rel)) { $Rel } else { Join-Path $Root $Rel }
    if (-not (Test-Path -LiteralPath $path)) { throw "INPUT_MISSING: $path" }
    [IO.File]::ReadAllText($path)
}

# ---- the authority -------------------------------------------------------------------------------
$errs = $null
$ast = [Management.Automation.Language.Parser]::ParseInput((Read-Input $AuthorityPath), [ref]$null, [ref]$errs)
function Get-AuthorityString([string]$Name) {
    $a = $ast.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and
            $n.Left -is [Management.Automation.Language.VariableExpressionAst] -and $n.Left.VariablePath.UserPath -eq $Name }, $true) | Select-Object -First 1
    if (-not $a -or $a.Right.Expression -isnot [Management.Automation.Language.StringConstantExpressionAst]) {
        throw "AUTHORITY_MOVED: `$$Name is no longer a string constant in $AuthorityPath"
    }
    $a.Right.Expression.Value
}
$idPat       = (Get-AuthorityString 'idPat').Trim('\b')     # the trim the authority itself applies (Check 14)
$openLead    = Get-AuthorityString 'statusOpenLead'
$settledLead = Get-AuthorityString 'statusResolvedLead'
$deciderRx   = Get-AuthorityString 'registerDeciderRx'
$decisionRx  = Get-AuthorityString 'decisionIdRx'
$fn = $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-RegisterFindingState' }, $true) | Select-Object -First 1
if (-not $fn) { throw "AUTHORITY_MOVED: Get-RegisterFindingState is no longer defined in $AuthorityPath" }
. ([scriptblock]::Create($fn.Extent.Text))

# ---- the register ----------------------------------------------------------------------------------
$registerText = Read-Input $RegisterPath
$registerFile = Join-Path ([IO.Path]::GetTempPath()) ("orvion-register-{0}.md" -f [guid]::NewGuid().ToString('N'))
[IO.File]::WriteAllText($registerFile, $registerText)
try { $state = Get-RegisterFindingState -Path $registerFile -IdPattern $idPat -SettledLead $settledLead -DeciderRx $deciderRx }
finally { [IO.File]::Delete($registerFile) }

# The universe: every id that is the SUBJECT of a register entry, read as the resolver reads it -- a
# `###` heading, or the leading cell (split on '/') of a row in a table whose header has `Status`.
$universe = [ordered]@{}
$statusIdx = -1; $sevIdx = -1; $titleIdx = -1; $lineNo = 0
foreach ($line in ($registerText -split "`r?`n")) {
    $lineNo++
    $head = [regex]::Match($line, '^###\s+(?<id>' + $idPat + ')\s*(?<rest>.*)$')
    if ($head.Success) {
        $id = $head.Groups['id'].Value
        if (-not $universe.Contains($id)) { $universe[$id] = [pscustomobject]@{ Id = $id; Line = $lineNo; Status = $null; Keys = @($id); Sev = ''; Title = $head.Groups['rest'].Value.Trim(' -—') } }
        continue
    }
    if ($line -notmatch '^\s*\|') { continue }
    $cells = @(($line -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
    $hS = [array]::IndexOf($cells, 'Status')
    if ($hS -ge 0) { $statusIdx = $hS; $sevIdx = [array]::IndexOf($cells, 'Sev'); $titleIdx = [array]::IndexOf($cells, 'Title'); continue }
    if ($statusIdx -lt 0) { continue }
    $lead = [regex]::Match($line, '^\|\s*(?<id>[A-Z][A-Za-z0-9\-/\.]*)\s*\|')
    if (-not $lead.Success) { continue }
    foreach ($piece in ($lead.Groups['id'].Value -split '/')) {
        # The LEADING id of each piece: a range cell such as `INV-1..4` is the subject INV-1 (and the
        # resolver files its state under the raw piece, so both keys are consulted below). Dropping a
        # piece that is not a bare id would silently shrink the population -- the unsafe direction.
        $piece = $piece.Trim()
        $idm = [regex]::Match($piece, '^' + $idPat + '(?![A-Za-z0-9-])')
        if (-not $idm.Success) { continue }
        $id = $idm.Value
        $status = if ($statusIdx -lt $cells.Count) { $cells[$statusIdx] } else { '' }
        $sev = if ($sevIdx -ge 0 -and $sevIdx -lt $cells.Count) { $cells[$sevIdx] } else { '' }
        $title = if ($titleIdx -ge 0 -and $titleIdx -lt $cells.Count) { $cells[$titleIdx] } else { '' }
        if (-not $universe.Contains($id)) { $universe[$id] = [pscustomobject]@{ Id = $id; Line = $lineNo; Status = $status; Keys = @($id); Sev = $sev; Title = $title } }
        elseif ($null -eq $universe[$id].Status) { $universe[$id].Status = $status; $universe[$id].Sev = $sev; $universe[$id].Title = $title }
        if ($universe[$id].Keys -notcontains $piece) { $universe[$id].Keys += $piece }
    }
}
$findings = foreach ($e in $universe.Values) {
    $settled = @($e.Keys | Where-Object { $state.ContainsKey($_) -and $state[$_].Settled }).Count -gt 0
    $class = if ($settled) { 'SETTLED' } elseif ($null -eq $e.Status) { 'BLOCK-ONLY' } elseif ($e.Status -match $openLead) { 'OPEN' } else { 'OTHER' }
    [pscustomobject]@{ Source = 'register'; Id = $e.Id; Class = $class; Line = $e.Line; Status = "$($e.Status)".Substring(0, [Math]::Min(120, "$($e.Status)".Length)); Sev = $e.Sev; Title = ($e.Title -replace '\*', '') }
}
$open = @($findings | Where-Object Class -ne 'SETTLED')

# ---- surfaces: the row rule of Check 22 (lower_snake_case surface in backticks, disposition in cell 2) --
$allSurfaces = @{}
$surfaces = foreach ($line in ((Read-Input $SurfacePath) -split "`r?`n")) {
    if ($line -cnotmatch '^\|\s*`([a-z_][a-z0-9_]*)`\s*\|') { continue }
    $name = $Matches[1]
    $cells = @($line.Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
    if ($cells.Count -lt 2) { continue }
    $disp = ($cells[1] -replace '\*', '').Trim()
    $allSurfaces[$name] = $disp
    if ($disp -in 'AUDITED-OPEN', 'PARTIAL') { [pscustomobject]@{ Source = 'surface'; Id = $name; Class = $disp; Line = 0; Status = $disp } }
}
$surfaces = @($surfaces)

# ---- the manifest's open-decision line: the enumeration up to its first sentence terminator --------
$decisionLine = ((Read-Input $ManifestPath) -split "`r?`n" | Where-Object { $_ -match 'Open owner decisions' } | Select-Object -First 1)
if (-not $decisionLine) { throw "INPUT_MALFORMED: $ManifestPath has no 'Open owner decisions' line" }
$enumeration = $decisionLine; $stop = [regex]::Match($decisionLine, '\.(\s|$)'); if ($stop.Success) { $enumeration = $decisionLine.Substring(0, $stop.Index) }
$decisions = @([regex]::Matches($enumeration, $decisionRx) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique |
    ForEach-Object { [pscustomobject]@{ Source = 'decision'; Id = $_; Class = 'OPEN-DECISION'; Line = 0; Status = '' } })

# ---- the gate section ----------------------------------------------------------------------------
$plan = Read-Input $PlanPath
$a = $plan.IndexOf($SectionHeading)
$section = $null
if ($a -ge 0) {
    $next = [regex]::Match($plan.Substring($a + $SectionHeading.Length), '(?m)^## ')
    $section = if ($next.Success) { $plan.Substring($a, $SectionHeading.Length + $next.Index) } else { $plan.Substring($a) }
}
# ---- report ----------------------------------------------------------------------------------------
$at = if ($Ref) { "at $Ref" } else { 'in the working tree' }
$byClass = $open | Group-Object Class
"READINESS POPULATION $at"
'register: {0} finding ids; settled {1}; not settled {2} (open vocabulary {3}, other {4}, block only {5})' -f $findings.Count, ($findings.Count - $open.Count), $open.Count,
    [int]($byClass | Where-Object Name -eq 'OPEN').Count, [int]($byClass | Where-Object Name -eq 'OTHER').Count, [int]($byClass | Where-Object Name -eq 'BLOCK-ONLY').Count
'surfaces: AUDITED-OPEN {0}, PARTIAL {1}' -f @($surfaces | Where-Object Class -eq 'AUDITED-OPEN').Count, @($surfaces | Where-Object Class -eq 'PARTIAL').Count
'open decisions: ' + (($decisions | ForEach-Object Id) -join ' ')
if ($Tsv) { @($(if ($IncludeSettled) { $findings } else { $open })) + $surfaces + $decisions | ConvertTo-Csv -Delimiter "`t" -NoTypeInformation | Set-Content -LiteralPath $Tsv -Encoding utf8; "population written to $Tsv" }
if ($null -eq $section) { "gate section: '$SectionHeading' is not in $PlanPath $at - coverage not evaluated"; exit 3 }
# ---- the action registry: the section's two tables (SPEC-269) ---------------------------------------
function Get-Cells([string]$Line) { @(($Line.Trim().Trim('|')) -split '(?<!\\)\|' | ForEach-Object { $_.Trim() }) }
$classes = @('VERIFIED DEFECT', 'REQUIRED CAPABILITY', 'BUSINESS POLICY', 'EXTERNAL / LEGAL', 'ACCEPTED RESIDUAL', 'FUTURE-ONLY', 'TERMINAL IN SUBSTANCE', 'SURFACE')
$problems = [Collections.Generic.List[string]]::new()
$boundary = @{}; $rows = @(); $inTable = $false
foreach ($line in "$section" -split "`r?`n") {
    $bk = [regex]::Match($line, '^\|\s*`(?<k>[A-Z][A-Z0-9-]*)`\s*\|')
    if ($bk.Success) {
        $st = (Get-Cells $line)[-1]
        if ($st -notmatch '^(NEXT|NOT REACHED|PER ITEM|REACHED \d{4}-\d{2}-\d{2}\b.*)$') { $problems.Add("BAD BOUNDARY STATE: $($bk.Groups['k'].Value) reads '$st'") }
        $boundary[$bk.Groups['k'].Value] = $st
        continue
    }
    if ($line -match '^\|\s*Ids\s*\|\s*Class\s*\|') { $inTable = $true; continue }
    if (-not $inTable -or $line -notmatch '^\|' -or $line -match '^\|\s*-') { continue }
    $c = Get-Cells $line
    $rows += [pscustomobject]@{ Ids = @($c[0] -split ',' | ForEach-Object { $_.Trim().Trim('`') } | Where-Object { $_ })
        Class = $c[1]; Decides = $c[2]; Boundary = "$($c[3])".Trim('`'); WaitsOn = $c[4]; Treatment = $c[5]; Raw = $c[0] }
}
if (-not $rows.Count) { "registry: the gate section has no classification table (a '| Ids | Class |' header and rows)"; exit 1 }

$settledIds = @{}; foreach ($f in $findings) { if ($f.Class -eq 'SETTLED') { $settledIds[$f.Id] = $true } }
$decisionIds = @($decisions | ForEach-Object Id)
$openSurfaces = @($surfaces | ForEach-Object Id)
$byId = @{}
foreach ($r in $rows) {
    if ($r.Class -notin $classes) { $problems.Add("BAD CLASS: '$($r.Class)' on row '$($r.Raw)'") }
    if (-not $boundary.ContainsKey($r.Boundary)) { $problems.Add("UNKNOWN BOUNDARY: '$($r.Boundary)' on row '$($r.Raw)'") }
    if (-not "$($r.Decides)".Trim() -or -not "$($r.Treatment)".Trim()) { $problems.Add("EMPTY DECIDES OR TREATMENT: row '$($r.Raw)'") }
    foreach ($id in $r.Ids) {
        if ($byId.ContainsKey($id)) { $problems.Add("CLASSIFIED TWICE: $id"); continue }
        if (-not $universe.Contains($id) -and -not $allSurfaces.ContainsKey($id) -and $decisionIds -notcontains $id) { $problems.Add("UNKNOWN ID: $id (row '$($r.Raw)')") }
        $byId[$id] = $r
    }
}

# Trigger state, by the section's rules in their order. An unclassified open member is its own state.
$members = [ordered]@{}
foreach ($m in @($open) + $surfaces + $decisions) { if (-not $members.Contains($m.Id)) { $members[$m.Id] = $m } }
foreach ($id in $byId.Keys) { if (-not $members.Contains($id)) { $members[$id] = [pscustomobject]@{ Source = 'registry'; Id = $id; Class = 'SETTLED'; Status = '' } } }
$entries = foreach ($id in $members.Keys) {
    $r = $byId[$id]
    $closed = ($decisionIds -notcontains $id) -and ($(if ($allSurfaces.ContainsKey($id)) { $openSurfaces -notcontains $id } else { $settledIds.ContainsKey($id) }))
    $bState = if ($r) { $boundary[$r.Boundary] } else { $null }
    $state = if (-not $r) { 'UNCLASSIFIED' }
        elseif ($closed) { 'COMPLETED' }
        elseif ("$bState" -like 'REACHED*') { 'OVERDUE' }
        elseif ($r.Class -in 'BUSINESS POLICY', 'EXTERNAL / LEGAL') { 'BLOCKED' }
        elseif ($r.Class -in 'ACCEPTED RESIDUAL', 'FUTURE-ONLY') { $r.Class }
        elseif ($bState -eq 'NEXT') { 'DUE NOW' }
        else { 'NOT DUE' }
    $u = if ($universe.Contains($id)) { $universe[$id] } else { $null }
    [pscustomobject]@{ State = $state; Id = $id; Source = $members[$id].Source; RegistryClass = "$($r.Class)"; Boundary = "$($r.Boundary)"; BoundaryState = "$bState"
        Decides = "$($r.Decides)"; WaitsOn = "$($r.WaitsOn)"; Sev = "$($u.Sev)"; Title = ("$($u.Title)" -replace '\*', ''); Status = "$($members[$id].Status)"; Treatment = "$($r.Treatment)" }
}
$entries = @($entries)
# A state from a boundary alone, for members that carry no class of their own (SPEC-270).
function Get-BoundaryState([string]$Key) {
    $s = $boundary[$Key]
    if ("$s" -like 'REACHED*') { 'OVERDUE' } elseif ($s -eq 'NEXT') { 'DUE NOW' } else { 'NOT DUE' }
}
# EC-1 (SPEC-270): every surface still NOT-RECORDED is an implicit member whose boundary is the
# programme's exit. It needs no row; a row that classifies it explicitly wins. Without this, Batch 6's
# unaudited surfaces were in no list, and nothing failed if B6-EXIT were recorded REACHED before them.
$unrecorded = @($allSurfaces.Keys | Where-Object { $allSurfaces[$_] -eq 'NOT-RECORDED' -and -not $byId.ContainsKey($_) } | Sort-Object)
if ($unrecorded.Count -and -not $boundary.ContainsKey($SurfaceBoundary)) { $problems.Add("UNKNOWN BOUNDARY: '$SurfaceBoundary' (EC-1, for $($unrecorded.Count) NOT-RECORDED surfaces)") }
foreach ($id in $unrecorded) {
    $entries += [pscustomobject]@{ State = (Get-BoundaryState $SurfaceBoundary); Id = $id; Source = 'surface'; RegistryClass = 'SURFACE'; Boundary = $SurfaceBoundary; BoundaryState = "$($boundary[$SurfaceBoundary])"
        Decides = 'engineering'; WaitsOn = ''; Sev = ''; Title = ''; Status = 'NOT-RECORDED'; Treatment = 'EC-1: no recorded disposition yet; scripts/batch6_select_target.ps1 ranks the next slice' }
}
$order = 'OVERDUE', 'UNCLASSIFIED', 'DUE NOW', 'BLOCKED', 'NOT DUE', 'ACCEPTED RESIDUAL', 'FUTURE-ONLY', 'COMPLETED'
'registry: ' + (($order | ForEach-Object { $n = @($entries | Where-Object State -eq $_).Count; if ($n) { "$_ $n" } }) -join ', ')

# The backlog's live items (SPEC-270). Its older sections are a dated record whose prose triggers
# nothing evaluated, so five items stayed "open" after they were built and one security item after its
# trigger fired. Every live item is now one row of the '## Live deferred items' table, whose Boundary
# cell names a key of the boundaries table above; its state is derived like a registry row's.
$backlogText = Read-Input $BacklogPath
$liveAt = $backlogText.IndexOf('## Live deferred items')
$backlogEntries = @()
if ($liveAt -lt 0) { $problems.Add("BACKLOG: $BacklogPath has no '## Live deferred items' table") }
else {
    $liveText = $backlogText.Substring($liveAt + 3); $cut = [regex]::Match($liveText, '(?m)^## '); if ($cut.Success) { $liveText = $liveText.Substring(0, $cut.Index) }
    $bIdx = -1; $dIdx = -1
    foreach ($line in ($liveText -split "`r?`n")) {
        if ($line -notmatch '^\|' -or $line -match '^\|\s*-') { continue }
        $c = Get-Cells $line
        if ($bIdx -lt 0) { $bIdx = [array]::IndexOf($c, 'Boundary'); $dIdx = [array]::IndexOf($c, 'Decides'); continue }
        $key = if ($bIdx -lt $c.Count) { "$($c[$bIdx])".Trim().Trim('`') } else { '' }
        $item = ($c[0] -replace '\*', '')
        if (-not $boundary.ContainsKey($key)) { $problems.Add("BACKLOG BOUNDARY: '$key' on live item '$item' is not a registry boundary"); continue }
        $backlogEntries += [pscustomobject]@{ State = (Get-BoundaryState $key); Item = $item; Boundary = $key; Decides = $(if ($dIdx -ge 0 -and $dIdx -lt $c.Count) { $c[$dIdx] } else { '' }) }
    }
}
'backlog: {0} live items in {1}; {2}' -f $backlogEntries.Count, $BacklogPath, (($order | ForEach-Object { $n = @($backlogEntries | Where-Object State -eq $_).Count; if ($n) { "$_ $n" } }) -join ', ')
foreach ($b in ($backlogEntries | Where-Object State -eq 'OVERDUE')) { $problems.Add("OVERDUE: backlog item '$($b.Item)' -- boundary $($b.Boundary) is $($boundary[$b.Boundary])") }
'batch 6: {0} of {1} surfaces carry no recorded disposition; scripts/batch6_select_target.ps1 ranks the next slice' -f @($allSurfaces.Values | Where-Object { $_ -eq 'NOT-RECORDED' }).Count, $allSurfaces.Count

if ($Tsv) { $regTsv = [IO.Path]::ChangeExtension($Tsv, '.registry.tsv'); $entries | ConvertTo-Csv -Delimiter "`t" -NoTypeInformation | Set-Content -LiteralPath $regTsv -Encoding utf8; "registry written to $regTsv" }
if ($Registry) {
    foreach ($e in ($entries | Sort-Object { [array]::IndexOf($order, $_.State) }, Id)) {
        $what = if ($e.Title) { $e.Title } else { $e.Treatment }
        '{0,-17} {1,-24} {2,-21} {3,-27} {4,-14} {5}' -f $e.State, $e.Id, $e.RegistryClass, ("$($e.Boundary) ($($e.BoundaryState))" -replace '^ \(\)$', ''), $e.Decides.Substring(0, [Math]::Min(14, $e.Decides.Length)), $what.Substring(0, [Math]::Min(90, $what.Length))
    }
    foreach ($b in ($backlogEntries | Sort-Object { [array]::IndexOf($order, $_.State) }, Item)) {
        '{0,-17} {1,-24} {2,-21} {3,-27} {4,-14} {5}' -f $b.State, '(backlog)', 'LIVE DEFERRED ITEM', "$($b.Boundary) ($($boundary[$b.Boundary]))", $b.Decides.Substring(0, [Math]::Min(14, $b.Decides.Length)), $b.Item.Substring(0, [Math]::Min(90, $b.Item.Length))
    }
}
foreach ($e in ($entries | Where-Object State -in 'UNCLASSIFIED', 'OVERDUE')) { $problems.Add("$($e.State): $($e.Id)" + $(if ($e.State -eq 'OVERDUE') { " -- boundary $($e.Boundary) is $($e.BoundaryState)" } else { ' -- an open member no registry row classifies' })) }
$done = @($entries | Where-Object State -eq 'COMPLETED' | ForEach-Object Id)
if ($done.Count) { 'completed ids still classified ({0}) - prune at the next edit: {1}' -f $done.Count, ($done -join ' ') }
if ($problems.Count) { "REGISTRY: {0} problem(s)" -f $problems.Count; $problems | ForEach-Object { "  $_" }; exit 1 }
'REGISTRY: complete -- every open member is classified once, and nothing is overdue'
exit 0