# ORVION Pre-Production Readiness Closure gate -- population derivation (ON DEMAND).
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
# It decides nothing: READY is the gate's five criteria, judged by the evaluator. Exit 1 means only
# that the derived population and the section disagree, which the evaluation must resolve.
#
# Usage:
#   pwsh -NoProfile -File scripts/readiness_population.ps1                 # the working tree
#   pwsh -NoProfile -File scripts/readiness_population.ps1 -Ref 523888d   # as of a commit (replay)
param(
    [string]$Ref,
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [string]$Tsv,
    [switch]$IncludeSettled,   # -Tsv also lists the settled register findings (the whole universe)
    # Input overrides, used by scripts/readiness_selftest.ps1 to run the rule on fixtures.
    [string]$RegisterPath = 'reports/master/MASTER_GAP_REGISTER.md',
    [string]$SurfacePath = 'reports/master/MASTER_SURFACE_DISPOSITION.md',
    [string]$ManifestPath = '_ORVION_CANONICAL/manifest.md',
    [string]$PlanPath = 'reports/master/MASTER_EXECUTION_PLAN.md',
    [string]$AuthorityPath = 'scripts/check_repository_consistency.ps1',
    [string]$SectionHeading = '## Pre-Production Readiness Closure gate'
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
$statusIdx = -1; $lineNo = 0
foreach ($line in ($registerText -split "`r?`n")) {
    $lineNo++
    $head = [regex]::Match($line, '^###\s+(?<id>' + $idPat + ')\s*(?<rest>.*)$')
    if ($head.Success) {
        $id = $head.Groups['id'].Value
        if (-not $universe.Contains($id)) { $universe[$id] = [pscustomobject]@{ Id = $id; Line = $lineNo; Status = $null; Keys = @($id) } }
        continue
    }
    if ($line -notmatch '^\s*\|') { continue }
    $cells = @(($line -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
    $hS = [array]::IndexOf($cells, 'Status')
    if ($hS -ge 0) { $statusIdx = $hS; continue }
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
        if (-not $universe.Contains($id)) { $universe[$id] = [pscustomobject]@{ Id = $id; Line = $lineNo; Status = $status; Keys = @($id) } }
        elseif ($null -eq $universe[$id].Status) { $universe[$id].Status = $status }
        if ($universe[$id].Keys -notcontains $piece) { $universe[$id].Keys += $piece }
    }
}
$findings = foreach ($e in $universe.Values) {
    $settled = @($e.Keys | Where-Object { $state.ContainsKey($_) -and $state[$_].Settled }).Count -gt 0
    $class = if ($settled) { 'SETTLED' } elseif ($null -eq $e.Status) { 'BLOCK-ONLY' } elseif ($e.Status -match $openLead) { 'OPEN' } else { 'OTHER' }
    [pscustomobject]@{ Source = 'register'; Id = $e.Id; Class = $class; Line = $e.Line; Status = "$($e.Status)".Substring(0, [Math]::Min(120, "$($e.Status)".Length)) }
}
$open = @($findings | Where-Object Class -ne 'SETTLED')

# ---- surfaces: the row rule of Check 22 (lower_snake_case surface in backticks, disposition in cell 2) --
$surfaces = foreach ($line in ((Read-Input $SurfacePath) -split "`r?`n")) {
    if ($line -cnotmatch '^\|\s*`([a-z_][a-z0-9_]*)`\s*\|') { continue }
    $name = $Matches[1]
    $cells = @($line.Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
    if ($cells.Count -lt 2) { continue }
    $disp = ($cells[1] -replace '\*', '').Trim()
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
function Test-Named([string]$Id) { [regex]::IsMatch($section, '(?<![A-Za-z0-9-])' + [regex]::Escape($Id) + '(?![0-9])') }

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
$unclassified = @(@($open) + $decisions | Where-Object { -not (Test-Named $_.Id) } | ForEach-Object Id | Sort-Object -Unique)
$settledNamed = @($findings | Where-Object { $_.Class -eq 'SETTLED' -and (Test-Named $_.Id) } | ForEach-Object Id)
'settled ids the section names ({0}) - cited as context, or closed since the reading: {1}' -f $settledNamed.Count, ($settledNamed -join ' ')
if ($unclassified.Count) { 'UNCLASSIFIED ({0}): {1}' -f $unclassified.Count, ($unclassified -join ' '); exit 1 }
'every derived finding and decision id is named in the gate section'
exit 0
