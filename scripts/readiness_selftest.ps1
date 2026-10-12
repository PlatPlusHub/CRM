# Self-test for scripts/readiness_population.ps1, run whenever that script changes and in CI as a guard-of-the-guard suite (SPEC-269).
#
# Check 29 of the repository consistency guard runs the subject on every guard run, so its calibration is a permanent control too. It proves the derivation on a real
# historical population, on fixtures that exercise each rule in both directions, and by mutants: each
# load-bearing rule is removed in a temporary copy, and the case that depends on it must then FAIL.
# A mutant whose text replacement did not apply is itself a failure, never a silent pass.
param(
    [string]$Subject = (Join-Path $PSScriptRoot 'readiness_population.ps1'),
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
$Authority = Join-Path $Root 'scripts/check_repository_consistency.ps1'
$Work = Join-Path ([IO.Path]::GetTempPath()) ('orvion-readiness-selftest-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($Work)
$script:Pass = 0; $script:Fail = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) { $script:Pass++; "PASS $Name" } else { $script:Fail++; "FAIL $Name $Detail" }
}
function Invoke-Subject([string]$Path, [string[]]$Arguments) {
    $out = @(& pwsh -NoProfile -File $Path @Arguments 2>&1 | ForEach-Object { "$_" })
    [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($out -join "`n") }
}
function Write-Fixture([string]$Name, [string]$Text) { $p = Join-Path $Work $Name; [IO.File]::WriteAllText($p, $Text); $p }

# ---- fixtures ------------------------------------------------------------------------------------
$register = Write-Fixture 'register.md' (@(
    '# fixture register', '',
    '| ID | Title | Status |', '|---|---|---|',
    '| AA-1 | open row | OPEN |',
    '| AA-2 | settled row | ✅ RESOLVED 2026-01-01 |',
    '| AA-3/AA-4 | shared row | DESIGN-READY |',
    '| AA-5..7 | range row | OPEN |',
    '| AA-8 | terminal word outside the vocabulary | MERGED |',
    '| AA-11 | settled later by its block | OPEN |',
    '| AA-13 | a required capability nothing implements | OPEN |', '',
    '### AA-9 — settled block', '- **Status:** FIXED', '',
    '### AA-10 — block with no status', 'text', '',
    '### AA-11 — closed', '- **Status:** VERIFIED', '') -join "`n")
$surface = Write-Fixture 'surface.md' (@(
    '| `AUDITED` | vocabulary row |',
    '| `t_one` | AUDITED-OPEN | — | s | f | n |',
    '| `t_two` | **PARTIAL** | — | s | f | n |',
    '| `t_three` | AUDITED | — | s | f | n |',
    '| `t_four` | NOT-RECORDED | — | s | f | n |', '') -join "`n")
# t_four has a disposition: the programme-exit cases that must pass once every surface is recorded.
$surfaceRecorded = Write-Fixture 'surface-recorded.md' (([IO.File]::ReadAllText($surface)) -replace '\| `t_four` \| NOT-RECORDED \|', '| `t_four` | AUDITED |')
$manifest = Write-Fixture 'manifest.md' "Open owner decisions — **AA-1**, **ZZ-1**, **AA-9**. Narrative after the enumeration cites AA-2.`n"
# The registry fixture (SPEC-269). K-MID is the boundary the state cases move; AA-9 is settled in the
# register but still on the decision line, so it stays open; AA-2 is settled and still classified.
$rowsAll = @(
    '| AA-1 | VERIFIED DEFECT | engineering | `K-NEXT` | — | fix now |',
    '| AA-13 | REQUIRED CAPABILITY | engineering | `K-MID` | — | build it |',
    '| AA-3, AA-4 | VERIFIED DEFECT | engineering | `K-MID` | — | fix before mid |',
    '| AA-5 | ACCEPTED RESIDUAL | engineering | `K-LATER` | — | bounded |',
    '| AA-8 | TERMINAL IN SUBSTANCE | engineering | `K-LATER` | — | reword |',
    '| AA-10 | FUTURE-ONLY | engineering | `K-LATER` | — | later |',
    '| ZZ-1 | BUSINESS POLICY | owner | `K-LATER` | owner | decide |',
    '| AA-9 | EXTERNAL / LEGAL | counsel | `K-LATER` | counsel | wait |',
    '| AA-2 | VERIFIED DEFECT | engineering | `K-DONE` | — | fixed already |',
    '| `t_one`, `t_two` | SURFACE | engineering | `K-LATER` | — | follows its findings |')
function Plan-Text([string[]]$Rows, [string]$Mid = 'NOT REACHED') {
    (@('# plan', '', '## Pre-Production Readiness Closure gate', '', '### Action registry', '',
       '| Boundary | Crossed when | Roadmap link | State |', '|---|---|---|---|',
       '| `K-NEXT` | now | x | NEXT |', "| ``K-MID`` | mid | x | $Mid |", '| `K-LATER` | later | x | NOT REACHED |',
       '| `K-DONE` | done | x | REACHED 2026-01-01 fixture evidence |', '',
       '| Ids | Class | Decides | Boundary | Waits on | Treatment |', '|---|---|---|---|---|---|') + $Rows + @('', '## Next section', 'AA-6', '')) -join "`n"
}
function Plan-Fixture([string[]]$Rows, [string]$Mid = 'NOT REACHED') { Write-Fixture ('plan-' + [guid]::NewGuid().ToString('N') + '.md') (Plan-Text $Rows $Mid) }
$planFull = Plan-Fixture $rowsAll
$noVocab  = Write-Fixture 'authority-moved.ps1' (([IO.File]::ReadAllText($Authority)) -replace '\$statusResolvedLead\s*=', '$statusSettledLeadRenamed =')
# SPEC-270: only the '## Live deferred items' table is evaluated; the older table is a dated record.
function Backlog-Text([string[]]$Live) {
    (@('# backlog', '', '## Live deferred items', '', '| Item | Decides | Trigger | Boundary | Detail |', '|---|---|---|---|---|') + $Live +
     @('', '## A dated section', '', '| Item | Why | Trigger / when | CR? |', '|---|---|---|---|', '| old | x | at go-live | y |', '')) -join "`n"
}
$liveRows = @('| live later | owner | at go-live | `K-LATER` | x |', '| live now | engineering | now | `K-NEXT` | x |')
$backlog  = Write-Fixture 'backlog.md' (Backlog-Text $liveRows)
$script:SurfaceArg = $surface; $script:BacklogArg = $backlog
function Fixture-Args([string]$Plan, [string]$Tsv, [string]$Register = $register) {
    @('-Root', $Root, '-RegisterPath', $Register, '-SurfacePath', $script:SurfaceArg, '-ManifestPath', $manifest, '-PlanPath', $Plan, '-AuthorityPath', $Authority, '-BacklogPath', $script:BacklogArg, '-SurfaceBoundary', 'K-MID', '-Tsv', $Tsv)
}
# Runs a case with the surface or backlog fixture swapped, restoring the defaults afterwards.
# (Parameter names differ from the defaults' names: PowerShell variables are case-insensitive.)
function With-Inputs([string]$SurfaceFile, [string]$BacklogFile, [scriptblock]$Body) {
    $script:SurfaceArg = $SurfaceFile; $script:BacklogArg = $BacklogFile
    try { & $Body } finally { $script:SurfaceArg = $surface; $script:BacklogArg = $backlog }
}
$expectedOpen = 'AA-1 AA-10 AA-13 AA-3 AA-4 AA-5 AA-8'
function Run-Registry([string]$Path, [string]$Plan, [string]$Register = $register) {
    $tsv = Join-Path $Work ('pop-' + [guid]::NewGuid().ToString('N') + '.tsv')
    $r = Invoke-Subject $Path (Fixture-Args $Plan $tsv $Register)
    $states = @{}; $reg = [IO.Path]::ChangeExtension($tsv, '.registry.tsv')
    if (Test-Path $reg) { foreach ($e in (Import-Csv -Delimiter "`t" $reg)) { $states[$e.Id] = $e.State } }
    [pscustomobject]@{ Code = $r.Code; Text = $r.Text; Tsv = $tsv; States = $states }
}
function Show($x) { "exit=$($x.Code) states=[" + (($x.States.Keys | Sort-Object | ForEach-Object { "$_=$($x.States[$_])" }) -join ' ') + '] ' + (($x.Text -split "`n" | Where-Object { $_ -match '^  |REGISTRY' }) -join ' / ') }

# ---- cases (each returns $true when the subject behaves correctly) --------------------------------
function Case-Fixture([string]$Path) {
    $x = Run-Registry $Path $planFull
    if (-not (Test-Path $x.Tsv)) { return [pscustomobject]@{ Ok = $false; Detail = $x.Text } }
    $pop = Import-Csv -Delimiter "`t" $x.Tsv
    $open = (@($pop | Where-Object Source -eq 'register' | ForEach-Object Id | Sort-Object) -join ' ')
    $surf = (@($pop | Where-Object Source -eq 'surface' | ForEach-Object Id | Sort-Object) -join ' ')
    $dec  = (@($pop | Where-Object Source -eq 'decision' | ForEach-Object Id | Sort-Object) -join ' ')
    $want = @{ 'AA-1' = 'DUE NOW'; 'AA-13' = 'NOT DUE'; 'AA-3' = 'NOT DUE'; 'AA-4' = 'NOT DUE'; 'AA-5' = 'ACCEPTED RESIDUAL'; 'AA-8' = 'NOT DUE'; 'AA-10' = 'FUTURE-ONLY'
               'ZZ-1' = 'BLOCKED'; 'AA-9' = 'BLOCKED'; 'AA-2' = 'COMPLETED'; 't_one' = 'NOT DUE'; 't_two' = 'NOT DUE'; 't_four' = 'NOT DUE' }
    $statesOk = $x.States.Count -eq $want.Count -and @($want.Keys | Where-Object { $x.States[$_] -ne $want[$_] }).Count -eq 0
    $ok = $x.Code -eq 0 -and $open -eq $expectedOpen -and $surf -eq 't_one t_two' -and $dec -eq 'AA-1 AA-9 ZZ-1' -and $statesOk -and
          $x.Text -match 'register: 10 finding ids; settled 3; not settled 7 \(open vocabulary 5, other 1, block only 1\)' -and
          $x.Text -match 'backlog: 2 live items in .*; DUE NOW 1, NOT DUE 1'
    [pscustomobject]@{ Ok = $ok; Detail = "open=[$open] surfaces=[$surf] decisions=[$dec] " + (Show $x) }
}
function Case-Expect([string]$Path, [string]$Plan, [int]$Code, [string]$Pattern, [hashtable]$States = @{}, [string]$Register = $register) {
    $x = Run-Registry $Path $Plan $Register
    $ok = $x.Code -eq $Code -and $x.Text -match $Pattern -and @($States.Keys | Where-Object { $x.States[$_] -ne $States[$_] }).Count -eq 0
    [pscustomobject]@{ Ok = $ok; Detail = Show $x }
}
$registerOpened = Write-Fixture 'register-opened.md' (([IO.File]::ReadAllText($register)) + "`n| AA-12 | newly registered | OPEN |`n")
$registerClosed = Write-Fixture 'register-closed.md' (([IO.File]::ReadAllText($register)) -replace '\| AA-3/AA-4 \| shared row \| DESIGN-READY \|', '| AA-3/AA-4 | shared row | ✅ RESOLVED 2026-02-02 |' -replace '\| AA-13 \| a required capability nothing implements \| OPEN \|', '| AA-13 | a required capability nothing implements | ✅ IMPLEMENTED 2026-02-02 |')
function Case-Gap([string]$Path)       { Case-Expect $Path (Plan-Fixture ($rowsAll -replace '^\| AA-3, AA-4 ', '| AA-3 ')) 1 'UNCLASSIFIED: AA-4' @{ 'AA-4' = 'UNCLASSIFIED' } }
function Case-Unknown([string]$Path)   { Case-Expect $Path (Plan-Fixture ($rowsAll -replace '^\| AA-10 ', '| AA-100 ')) 1 'UNKNOWN ID: AA-100' }
function Case-Twice([string]$Path)     { Case-Expect $Path (Plan-Fixture ($rowsAll + '| AA-1 | FUTURE-ONLY | engineering | `K-LATER` | — | again |')) 1 'CLASSIFIED TWICE: AA-1' }
function Case-Overdue([string]$Path)   { Case-Expect $Path (Plan-Fixture $rowsAll 'REACHED 2026-02-01 fixture') 1 'OVERDUE: AA-3' @{ 'AA-3' = 'OVERDUE'; 'AA-4' = 'OVERDUE'; 'AA-13' = 'OVERDUE'; 'AA-5' = 'ACCEPTED RESIDUAL'; 't_four' = 'OVERDUE' } }
function Case-Closed([string]$Path)    { With-Inputs $surfaceRecorded $backlog { Case-Expect $Path (Plan-Fixture $rowsAll 'REACHED 2026-02-01 fixture') 0 'REGISTRY: complete' @{ 'AA-3' = 'COMPLETED'; 'AA-4' = 'COMPLETED'; 'AA-13' = 'COMPLETED' } $registerClosed } }
function Case-Due([string]$Path)       { Case-Expect $Path (Plan-Fixture $rowsAll 'NEXT') 0 'REGISTRY: complete' @{ 'AA-3' = 'DUE NOW'; 'AA-4' = 'DUE NOW'; 'AA-13' = 'DUE NOW'; 't_four' = 'DUE NOW' } }
# SPEC-270. EC-1: with every finding closed, the programme exit is still OVERDUE while a surface is unrecorded.
function Case-Ec1([string]$Path)       { Case-Expect $Path (Plan-Fixture $rowsAll 'REACHED 2026-02-01 fixture') 1 'OVERDUE: t_four' @{ 't_four' = 'OVERDUE'; 'AA-3' = 'COMPLETED' } $registerClosed }
function Case-BacklogUnknown([string]$Path) { With-Inputs $surface (Write-Fixture 'backlog-unknown.md' (Backlog-Text ($liveRows + '| no boundary | owner | someday | — | x |'))) { Case-Expect $Path $planFull 1 "BACKLOG BOUNDARY: '—' on live item 'no boundary'" } }
function Case-BacklogOverdue([string]$Path) { With-Inputs $surface (Write-Fixture 'backlog-overdue.md' (Backlog-Text ($liveRows + '| fired | owner | done | `K-DONE` | x |'))) { Case-Expect $Path $planFull 1 "OVERDUE: backlog item 'fired'" } }
function Case-BacklogMissing([string]$Path) { With-Inputs $surface (Write-Fixture 'backlog-missing.md' "# backlog`n`n| Item | Trigger |`n|---|---|`n| x | y |`n") { Case-Expect $Path $planFull 1 "BACKLOG: .* has no '## Live deferred items' table" } }
function Case-Opened([string]$Path)    { Case-Expect $Path $planFull 1 'UNCLASSIFIED: AA-12' @{ 'AA-12' = 'UNCLASSIFIED' } $registerOpened }
function Case-Admitted([string]$Path)  { Case-Expect $Path (Plan-Fixture ($rowsAll + '| AA-12 | VERIFIED DEFECT | engineering | `K-NEXT` | — | new |')) 0 'REGISTRY: complete' @{ 'AA-12' = 'DUE NOW' } $registerOpened }
function Case-Vocab([string]$Path)     { Case-Expect $Path (Plan-Fixture ($rowsAll -replace 'TERMINAL IN SUBSTANCE \| engineering \| `K-LATER`', 'MAYBE LATER | engineering | `K-NOWHERE`')) 1 "BAD CLASS: 'MAYBE LATER'[\s\S]*UNKNOWN BOUNDARY: 'K-NOWHERE'" }
function Case-Empty([string]$Path)     { Case-Expect $Path (Plan-Fixture ($rowsAll -replace '\| owner \| `K-LATER` \| owner \| decide \|', '| owner | `K-LATER` | owner |  |')) 1 'EMPTY DECIDES OR TREATMENT' }
# 1. A real, non-empty population: the gate's first derivation, replayed at 523888d where the gate
#    section did not exist yet (exit 3: coverage not evaluated).
$r = Invoke-Subject $Subject @('-Root', $Root, '-Ref', '523888d')
Check 'R1 replay at 523888d derives the recorded first population' ($r.Code -eq 3 -and
    $r.Text -match 'register: 446 finding ids; settled 322; not settled 124 \(open vocabulary 106, other 8, block only 10\)' -and
    $r.Text -match 'surfaces: AUDITED-OPEN 18, PARTIAL 3' -and $r.Text -match 'open decisions: MAIL-1 PH8-10 RET-1') "exit=$($r.Code) $($r.Text)"
$c = Case-Fixture $Subject;  Check 'R2 fixture: population, and every trigger state by its rule' $c.Ok $c.Detail
$r = Invoke-Subject $Subject @('-Root', $Root, '-RegisterPath', $register, '-SurfacePath', $surface, '-ManifestPath', $manifest, '-PlanPath', $planFull, '-AuthorityPath', $noVocab, '-BacklogPath', $backlog)
Check 'R5 a vocabulary the authority no longer defines fails loudly' ($r.Code -ne 0 -and $r.Text -match 'AUTHORITY_MOVED: \$statusResolvedLead') "exit=$($r.Code)"
foreach ($t in @(
    @('R3 an open member no row classifies fails as UNCLASSIFIED', 'Case-Gap'),
    @('R7 a row naming an unknown id fails', 'Case-Unknown'),
    @('R8 an id classified twice fails', 'Case-Twice'),
    @('R9 a REACHED boundary with its items still open fails as OVERDUE', 'Case-Overdue'),
    @('R10 closing the items in the register clears OVERDUE and reads COMPLETED', 'Case-Closed'),
    @('R11 moving a boundary to NEXT makes its items DUE NOW', 'Case-Due'),
    @('R12 a newly registered open finding is UNCLASSIFIED until a row admits it', 'Case-Opened'),
    @('R13 admitting it with a row clears the failure and derives its state', 'Case-Admitted'),
    @('R14 a class or boundary outside the vocabularies fails', 'Case-Vocab'),
    @('R15 an empty Treatment cell fails', 'Case-Empty'),
    @('R16 an unrecorded surface is OVERDUE once its programme exit is REACHED (EC-1)', 'Case-Ec1'),
    @('R17 a live backlog item without a registry boundary fails', 'Case-BacklogUnknown'),
    @('R18 a live backlog item whose boundary is REACHED fails as OVERDUE', 'Case-BacklogOverdue'),
    @('R19 a backlog without the Live deferred items table fails', 'Case-BacklogMissing'))) {
    $c = & $t[1] $Subject; Check $t[0] $c.Ok $c.Detail
}

# 6. Semantics, not a stored total: on the LIVE register, the derivation's universe equals the finding
#    subjects that Check 11's own subject rule reads (check_repository_consistency.ps1, the `$subjects`
#    loop): a row's leading cell split on '/', or a `###` heading -- taking each piece's leading id.
function Case-Universe([string]$Path) {
    $tsv = Join-Path $Work ('all-' + [guid]::NewGuid().ToString('N') + '.tsv')
    [void](Invoke-Subject $Path @('-Root', $Root, '-Tsv', $tsv, '-IncludeSettled'))
    if (-not (Test-Path $tsv)) { return [pscustomobject]@{ Ok = $false; Detail = 'no output' } }
    $mine = @(Import-Csv -Delimiter "`t" $tsv | Where-Object Source -eq 'register' | ForEach-Object Id | Sort-Object -Unique)
    $idRx = '^([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[0-9]+[a-z]?|R[0-9]+|A[0-9]+|B[0-9]+|N[0-9]+)(?![A-Za-z0-9-])'
    $theirs = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $Root 'reports/master/MASTER_GAP_REGISTER.md'))) {
        $m = [regex]::Match($line, '^\|\s*([A-Z][A-Za-z0-9\-/\.\s]*?)\s*\|')
        if (-not $m.Success) { $m = [regex]::Match($line, '^###\s+([A-Z][A-Za-z0-9\-/\.\s]*?)\s+[-—]') }
        if ($m.Success) { foreach ($piece in ($m.Groups[1].Value -split '/')) { $i = [regex]::Match($piece.Trim(), $idRx); if ($i.Success) { $theirs[$i.Value] = 1 } } }
    }
    $onlyMine = @($mine | Where-Object { -not $theirs.ContainsKey($_) }); $onlyTheirs = @($theirs.Keys | Where-Object { $mine -notcontains $_ })
    [pscustomobject]@{ Ok = ($mine.Count -gt 400 -and -not $onlyMine -and -not $onlyTheirs); Detail = "derived=$($mine.Count) check11=$($theirs.Count) onlyDerived=[$($onlyMine -join ' ')] onlyCheck11=[$($onlyTheirs -join ' ')]" }
}
$c = Case-Universe $Subject; Check 'R6 the derived universe is exactly the register subjects Check 11 reads (live register)' $c.Ok $c.Detail

# ---- mutants: each must be KILLED by the case named ------------------------------------------------
$source = [IO.File]::ReadAllText($Subject)
$mutants = @(
    @{ Name = 'M1 settled state ignored';        Find = '$settled = @($e.Keys';             Replace = '$settled = $false; $null = @($e.Keys'; Case = 'Case-Fixture' },
    @{ Name = 'M2 shared rows not split';         Find = "-split '/'))";                       Replace = "-split '#'))";                         Case = 'Case-Fixture' },
    @{ Name = 'M3 range cell dropped';            Find = "'(?![A-Za-z0-9-])')";                Replace = "'$')";                                 Case = 'Case-Fixture' },
    @{ Name = 'M4 decision prose read as state';  Find = 'if ($stop.Success) { $enumeration'; Replace = 'if ($false) { $enumeration';           Case = 'Case-Fixture' },
    @{ Name = 'M5 OVERDUE rule removed';          Find = 'elseif ("$bState" -like ''REACHED*'')'; Replace = 'elseif ($false)';                   Case = 'Case-Overdue' },
    @{ Name = 'M6 COMPLETED rule removed';        Find = 'elseif ($closed) {';                 Replace = 'elseif ($false) {';                    Case = 'Case-Closed' },
    @{ Name = 'M7 decision line keeps nothing open'; Find = '$closed = ($decisionIds -notcontains $id) -and'; Replace = '$closed = $true -and'; Case = 'Case-Fixture' },
    @{ Name = 'M8 duplicates accepted';           Find = 'if ($byId.ContainsKey($id)) { $problems.Add'; Replace = 'if ($false) { $problems.Add';  Case = 'Case-Twice' },
    @{ Name = 'M9 unknown ids accepted';          Find = 'if (-not $universe.Contains($id) -and';  Replace = 'if ($false -and';                Case = 'Case-Unknown' },
    @{ Name = 'M10 unclassified not failed';      Find = "Where-Object State -in 'UNCLASSIFIED', 'OVERDUE'"; Replace = "Where-Object State -in 'OVERDUE'"; Case = 'Case-Gap' },
    @{ Name = 'M11 NEXT ignored';                 Find = "elseif (`$bState -eq 'NEXT') { 'DUE NOW' }"; Replace = "elseif (`$false) { 'DUE NOW' }"; Case = 'Case-Due' },
    @{ Name = 'M12 empty cells accepted';         Find = 'if (-not "$($r.Decides)".Trim() -or'; Replace = 'if ($false -and';                Case = 'Case-Empty' },
    @{ Name = 'M13 unrecorded surfaces not members'; Find = "`$allSurfaces[`$_] -eq 'NOT-RECORDED' -and"; Replace = '$false -and';      Case = 'Case-Ec1' },
    @{ Name = 'M14 backlog boundary not required'; Find = 'if (-not $boundary.ContainsKey($key)) {'; Replace = 'if ($false) {';         Case = 'Case-BacklogUnknown' },
    @{ Name = 'M15 backlog OVERDUE not failed';   Find = "foreach (`$b in (`$backlogEntries | Where-Object State -eq 'OVERDUE'))"; Replace = 'foreach ($b in @())'; Case = 'Case-BacklogOverdue' }
)
foreach ($m in $mutants) {
    $mutated = $source.Replace($m.Find, $m.Replace)
    if ($mutated -eq $source) { Check "$($m.Name) (mutant applied)" $false "text not found: $($m.Find)"; continue }
    $path = Join-Path $Work ('mutant-' + [guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllText($path, $mutated)
    $c = & $m.Case $path
    # The mutant's own output is printed, so a kill caused by a broken copy rather than by the
    # removed rule is visible to the reader (`exit=1` with a parse error is not a kill).
    Check "$($m.Name) is KILLED by $($m.Case)" (-not $c.Ok -and $c.Detail -notmatch 'ParserError|ParseException') $c.Detail
    "    mutant observed: $($c.Detail)"
}

try { [IO.Directory]::Delete($Work, $true) } catch { "note: could not remove $Work ($($_.Exception.Message))" }
"== $script:Pass passed, $script:Fail failed =="
exit ([int]($script:Fail -gt 0))
