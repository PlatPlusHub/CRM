# Self-test for scripts/readiness_population.ps1 -- ON DEMAND, run whenever that script changes.
#
# Not a permanent control: no profile, hook or workflow runs it. It proves the derivation on a real
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
    '| AA-11 | settled later by its block | OPEN |', '',
    '### AA-9 — settled block', '- **Status:** FIXED', '',
    '### AA-10 — block with no status', 'text', '',
    '### AA-11 — closed', '- **Status:** VERIFIED', '') -join "`n")
$surface = Write-Fixture 'surface.md' (@(
    '| `AUDITED` | vocabulary row |',
    '| `t_one` | AUDITED-OPEN | — | s | f | n |',
    '| `t_two` | **PARTIAL** | — | s | f | n |',
    '| `t_three` | AUDITED | — | s | f | n |', '') -join "`n")
$manifest = Write-Fixture 'manifest.md' "Open owner decisions — **AA-1**, **ZZ-1**. Narrative after the enumeration cites AA-2.`n"
$named = 'AA-1 AA-3 AA-4 AA-5 AA-8 AA-10 ZZ-1 and the settled AA-2'
$planFull = Write-Fixture 'plan-full.md' "# plan`n`n## Pre-Production Readiness Closure gate`n`n$named`n`n## Next section`nAA-6`n"
$planGap  = Write-Fixture 'plan-gap.md'  "# plan`n`n## Pre-Production Readiness Closure gate`n`n$($named -replace 'AA-4 ', '')`n`n## Next section`nAA-4`n"
$planNear = Write-Fixture 'plan-near.md' "# plan`n`n## Pre-Production Readiness Closure gate`n`n$($named -replace 'AA-10 ', 'AA-100 ')`n"
$noVocab  = Write-Fixture 'authority-moved.ps1' (([IO.File]::ReadAllText($Authority)) -replace '\$statusResolvedLead\s*=', '$statusSettledLeadRenamed =')
function Fixture-Args([string]$Plan, [string]$Tsv) {
    @('-Root', $Root, '-RegisterPath', $register, '-SurfacePath', $surface, '-ManifestPath', $manifest, '-PlanPath', $Plan, '-AuthorityPath', $Authority, '-Tsv', $Tsv)
}
$expectedOpen = 'AA-1 AA-10 AA-3 AA-4 AA-5 AA-8'

# ---- cases (each returns $true when the subject behaves correctly) --------------------------------
function Case-Fixture([string]$Path) {
    $tsv = Join-Path $Work ('pop-' + [guid]::NewGuid().ToString('N') + '.tsv')
    $r = Invoke-Subject $Path (Fixture-Args $planFull $tsv)
    if (-not (Test-Path $tsv)) { return [pscustomobject]@{ Ok = $false; Detail = $r.Text } }
    $pop = Import-Csv -Delimiter "`t" $tsv
    $open = (@($pop | Where-Object Source -eq 'register' | ForEach-Object Id | Sort-Object) -join ' ')
    $surf = (@($pop | Where-Object Source -eq 'surface' | ForEach-Object Id | Sort-Object) -join ' ')
    $dec  = (@($pop | Where-Object Source -eq 'decision' | ForEach-Object Id | Sort-Object) -join ' ')
    $ok = $r.Code -eq 0 -and $open -eq $expectedOpen -and $surf -eq 't_one t_two' -and $dec -eq 'AA-1 ZZ-1' -and
          $r.Text -match 'register: 9 finding ids; settled 3; not settled 6 \(open vocabulary 4, other 1, block only 1\)' -and
          $r.Text -match 'settled ids the section names \(1\)[^\n]*AA-2'
    [pscustomobject]@{ Ok = $ok; Detail = "exit=$($r.Code) open=[$open] surfaces=[$surf] decisions=[$dec]" }
}
function Case-Gap([string]$Path) {
    $r = Invoke-Subject $Path (Fixture-Args $planGap (Join-Path $Work 'gap.tsv'))
    [pscustomobject]@{ Ok = ($r.Code -eq 1 -and $r.Text -match 'UNCLASSIFIED \(1\): AA-4'); Detail = "exit=$($r.Code)" }
}
function Case-Near([string]$Path) {
    $r = Invoke-Subject $Path (Fixture-Args $planNear (Join-Path $Work 'near.tsv'))
    [pscustomobject]@{ Ok = ($r.Code -eq 1 -and $r.Text -match 'UNCLASSIFIED \(1\): AA-10'); Detail = "exit=$($r.Code)" }
}

# 1. A real, non-empty population: the gate's first derivation, replayed at 523888d where the gate
#    section did not exist yet (exit 3: coverage not evaluated).
$r = Invoke-Subject $Subject @('-Root', $Root, '-Ref', '523888d')
Check 'R1 replay at 523888d derives the recorded first population' ($r.Code -eq 3 -and
    $r.Text -match 'register: 446 finding ids; settled 322; not settled 124 \(open vocabulary 106, other 8, block only 10\)' -and
    $r.Text -match 'surfaces: AUDITED-OPEN 18, PARTIAL 3' -and $r.Text -match 'open decisions: MAIL-1 PH8-10 RET-1') "exit=$($r.Code) $($r.Text)"
$c = Case-Fixture $Subject; Check 'R2 fixture: open, settled, shared, range, block-only, surfaces and decisions' $c.Ok $c.Detail
$c = Case-Gap $Subject;     Check 'R3 an unclassified derived id is reported and exits 1' $c.Ok $c.Detail
$c = Case-Near $Subject;    Check 'R4 a longer id (AA-100) does not classify AA-10' $c.Ok $c.Detail
$r = Invoke-Subject $Subject @('-Root', $Root, '-RegisterPath', $register, '-SurfacePath', $surface, '-ManifestPath', $manifest, '-PlanPath', $planFull, '-AuthorityPath', $noVocab)
Check 'R5 a vocabulary the authority no longer defines fails loudly' ($r.Code -ne 0 -and $r.Text -match 'AUTHORITY_MOVED: \$statusResolvedLead') "exit=$($r.Code)"

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
    @{ Name = 'M5 id boundary dropped';           Find = "'(?![0-9])')";                       Replace = "'')";                                  Case = 'Case-Near' }
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
