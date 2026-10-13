# Judges the workstation scripts on fixtures and changes nothing on the machine.
# U: .workstation/update.ps1's plan - what winget and npm reported decides each row. update.ps1 runs
#    winget and npm at its top level, so it is never executed or dot-sourced here: the file is parsed
#    and only its tool tables and Get-UpdatePlan are evaluated.
# V: scripts/verify_workstation_idempotence.ps1, run against a throwaway root whose doctor and
#    prepare are stubs.
# L: the double-click launchers .workstation/doctor.cmd and update.cmd, copied beside stub scripts.
$ErrorActionPreference = 'Stop'
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path (Split-Path $PSScriptRoot -Parent) '.workstation/update.ps1'), [ref]$null, [ref]$null)
$defs = @($ast.EndBlock.Statements | Where-Object {
    ($_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Get-UpdatePlan') -or
    ($_ -is [Management.Automation.Language.AssignmentStatementAst] -and @('$WingetTools', '$NpmTools') -contains $_.Left.Extent.Text) })
if ($defs.Count -ne 3) { throw ('update.ps1 must define $WingetTools, $NpmTools and Get-UpdatePlan at its top level; found ' + $defs.Count + ' of 3') }
. ([scriptblock]::Create(($defs | ForEach-Object { $_.Extent.Text }) -join "`n"))
$script:pass = 0; $script:fail = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail) { if ($Ok) { $script:pass++; "PASS $Name" } else { $script:fail++; "FAIL $Name :: $Detail" } }
function Row($Plan, [string]$Tool) { @($Plan | Where-Object { $_.Tool -eq $Tool })[0] }

$table = @('Name                   Id                   Version  Available Source', '----',
    'Docker Desktop         Docker.DockerDesktop 4.95.0   4.96.0    winget', 'Git                    Git.Git              2.54.0   2.55.0    winget', '2 upgrades available.')
$outdated = '{"@anthropic-ai/claude-code":{"current":"2.1.296","latest":"2.1.300"},"@openai/codex":{"current":"1.0.0","latest":"1.1.0"}}' | ConvertFrom-Json
$plan = @(Get-UpdatePlan $WingetTools @('GitHub.cli', 'Docker.DockerDesktop', 'Microsoft.PowerShell') $table $NpmTools @('@anthropic-ai/claude-code') $outdated)

$r = Row $plan 'docker'; Check 'U1 a winget-managed tool with an upgrade row is planned at exactly the previewed version and source' ($r.Action -eq 'upgrade' -and $r.Version -eq '4.96.0' -and $r.Source -eq 'winget' -and $r.Detail -eq '4.95.0 -> 4.96.0') "$r"
$r = Row $plan 'git'; Check 'U2 a tool winget did not install is reported, never upgraded or failed, even when a row names its id' ($r.Action -eq 'report') "$r"
$r = Row $plan 'gh'; Check 'U3 a winget-managed tool with no upgrade row is up to date' ($r.Action -eq 'none') "$r"
$r = Row $plan 'claude'; Check 'U4 an npm-managed outdated package is planned at exactly the previewed version' ($r.Action -eq 'upgrade' -and $r.Version -eq '2.1.300' -and $r.Detail -eq '2.1.296 -> 2.1.300') "$r"
$r = Row $plan 'codex'; Check 'U5 a package npm did not install is reported even when npm calls it outdated' ($r.Action -eq 'report') "$r"
Check 'U6 only previewed upgrades exist: exactly two rows, and none for the pinned Supabase CLI' (@($plan | Where-Object Action -eq 'upgrade').Count -eq 2 -and -not @($plan | Where-Object { $_.Target -match 'supabase' }).Count) (($plan | ForEach-Object { "$($_.Tool)=$($_.Action)" }) -join ' ')
$p2 = @(Get-UpdatePlan $WingetTools @('Microsoft.PowerShell') @('Microsoft PowerShell Microsoft.PowerShell.Preview 7.7 7.8 winget') $NpmTools @() $null)
$r = Row $p2 'pwsh'; Check 'U7 an id is matched whole: a row for Microsoft.PowerShell.Preview does not plan Microsoft.PowerShell' ($r.Action -eq 'none') "$r"

# A prepare run on a machine that is not converged provisions it, so a failing doctor must stop the
# verifier before prepare.ps1 starts (OPS-6).
function Invoke-Verifier([int]$DoctorExit, [string]$PrepareLine) {
    $ErrorActionPreference = 'Continue'
    $r = Join-Path ([IO.Path]::GetTempPath()) ('orvion-ws-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $r '.workstation') -Force | Out-Null
    Set-Content (Join-Path $r '.workstation/doctor.ps1') "exit $DoctorExit"
    Set-Content (Join-Path $r '.workstation/prepare.ps1') "Set-Content (Join-Path `$PSScriptRoot 'prepared') x; Write-Host '$PrepareLine'; exit 0"
    git init -q $r
    $o = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'verify_workstation_idempotence.ps1') -Root $r 2>&1 | Out-String
    [pscustomobject]@{ Code = $LASTEXITCODE; Text = $o; Prepared = (Test-Path (Join-Path $r '.workstation/prepared')) }
    Remove-Item -LiteralPath $r -Recurse -Force
}
$v = Invoke-Verifier 1 '[ OK ] x'; Check 'V1 a failing doctor stops the verifier before prepare.ps1 runs' ($v.Code -eq 1 -and -not $v.Prepared -and $v.Text -match 'NOT MEASURED') $v.Text
$v = Invoke-Verifier 0 '[ OK ] x'; Check 'V2 a passing doctor and a prepare run that changes nothing pass' ($v.Code -eq 0 -and $v.Prepared -and $v.Text -match 'IDEMPOTENCE: PASSED') $v.Text
$v = Invoke-Verifier 0 '[CONFIG] x'; Check 'V3 a prepare run that still reconfigures after a passing doctor fails' ($v.Code -eq 1 -and $v.Text -match 'NOT IDEMPOTENT') $v.Text

# A launcher only dispatches: from any working directory it runs the script beside it, with no
# arguments (so update.cmd can never pass -Apply), and returns that script's exit code. pause returns
# at once when input is not a console.
function Invoke-Launcher([string]$Name, [int]$StubExit) {
    $ErrorActionPreference = 'Continue'
    $r = Join-Path ([IO.Path]::GetTempPath()) ('orvion-ws-' + [guid]::NewGuid().ToString('N'))
    $w = Join-Path $r '.workstation'; New-Item -ItemType Directory -Path $w, (Join-Path $r 'elsewhere') -Force | Out-Null
    Copy-Item (Join-Path (Split-Path $PSScriptRoot -Parent) ".workstation/$Name.cmd") $w
    Set-Content (Join-Path $w "$Name.ps1") "Write-Host ('STUB $Name args=[' + (`$args -join ' ') + ']'); exit $StubExit"
    Set-Content (Join-Path $w 'prepare.ps1') "Write-Host 'STUB prepare'; exit 0"
    Push-Location (Join-Path $r 'elsewhere')
    $o = cmd /c "`"$(Join-Path $w "$Name.cmd")`" < nul" 2>&1 | Out-String
    $c = $LASTEXITCODE; Pop-Location; Remove-Item -LiteralPath $r -Recurse -Force
    [pscustomobject]@{ Code = $c; Text = $o }
}
$l = Invoke-Launcher 'doctor' 3; Check 'L1 doctor.cmd runs only doctor.ps1 from another directory and returns its failure' ($l.Code -eq 3 -and $l.Text -match 'STUB doctor args=\[\]' -and $l.Text -notmatch 'STUB prepare') $l.Text
$l = Invoke-Launcher 'update' 0; Check 'L2 update.cmd runs update.ps1 with no arguments, never -Apply, and returns its exit code' ($l.Code -eq 0 -and $l.Text -match 'STUB update args=\[\]') $l.Text
$l = Invoke-Launcher 'update' 1; Check 'L3 update.cmd returns a failing update''s exit code' ($l.Code -eq 1) $l.Text

"== $script:pass passed, $script:fail failed =="
if ($script:fail) { exit 1 }
