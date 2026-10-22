# Own repository owner-adapter tests: real child processes and owned local Git fixtures.
# Console confirmation and transport are explicit fixture seams, never owner identity or remote certification proof.
param([string]$Root=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$work=Join-Path ([IO.Path]::GetTempPath()) ('orvion-owner-interfaces-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
$output=Join-Path $work 'result.json'
$MaxCases=0; $CaseNames=@()
$gitExe = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$records = [Collections.Generic.List[object]]::new()
function Write-FixtureText([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}
function Invoke-FixtureSetupGit([string[]]$Arguments) {
    $lines = @(& $gitExe @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "FIXTURE_GIT: $($Arguments -join ' '): $($lines -join ' ')" }
    $lines | ForEach-Object { "$_" }
}
$nativeStub = @'
param([string]$Root, [string]$Candidate)
$ErrorActionPreference = 'Stop'
$cfg = Get-Content -Raw -LiteralPath $env:ORVION_B4_FIXTURE_CONFIG | ConvertFrom-Json
$operation = if ($PSCommandPath -match 'publish_candidate') { 'PUBLISH' } else { 'PROMOTE' }
@{Operation=$operation;Root=$Root;Candidate=$Candidate;Script=$PSCommandPath} | ConvertTo-Json | Set-Content -LiteralPath $cfg.NativeCall
if ($cfg.Mode -eq 'native-fail') { Write-Output "${operation}: REFUSED"; exit 7 }
if ($cfg.Mode -eq 'zero-no-done') { Write-Output 'Fixture child completed without a verdict'; exit 0 }
$target = if ($operation -eq 'PUBLISH') { 'refs/heads/orvion-preflight' } else { 'refs/heads/main' }
$value = if ($cfg.Mode -eq 'wrong-ref') { $cfg.Base } else { $cfg.Candidate }
& $cfg.GitExe -C $cfg.Bare update-ref $target $value
if ($LASTEXITCODE -ne 0) { throw 'FIXTURE_REF_UPDATE' }
Write-Output "${operation}: DONE"
if ($cfg.Mode -eq 'duplicate-done') { Write-Output "${operation}: DONE" }
if ($cfg.Mode -eq 'contradictory') { Write-Output "${operation}: REFUSED" }
if ($cfg.Mode -eq 'blocked-and-done') { Write-Output "${operation}: BLOCKED" }
if ($cfg.Mode -eq 'unreadable-and-done') { Write-Output "${operation}: UNREADABLE" }
if ($cfg.Mode -eq 'cross-operation') { Write-Output $(if($operation-eq'PUBLISH'){'PROMOTE: DONE'}else{'PUBLISH: DONE'}) }
if ($cfg.Mode -eq 'unknown-verdict') { Write-Output "${operation}: UNKNOWN" }
exit 0
'@
$driver = @'
param([Parameter(Mandatory)][string]$Config)
$ErrorActionPreference = 'Stop'
$global:OrvionB4Fixture = Get-Content -Raw -LiteralPath $Config | ConvertFrom-Json
$env:ORVION_B4_FIXTURE_CONFIG = $Config
function Invoke-FixtureGit {
    $GitArguments = @($args)
    if ($GitArguments.Count -lt 3 -or $GitArguments[0] -cne '-C' -or $GitArguments[1] -notin @($global:OrvionB4Fixture.Source,$global:OrvionB4Fixture.Root)) { throw 'FIXTURE_UNEXPECTED_GIT_ROOT' }
    $forward = @($GitArguments)
    $verb = $forward[2]
    if ($verb -eq 'push') { throw 'FIXTURE_PUSH_FORBIDDEN' }
    if ($verb -eq 'fetch') {
        if ($forward.Count -ne 5 -or $forward[3] -cne '--quiet' -or $forward[4] -cne 'origin') { throw 'FIXTURE_UNEXPECTED_FETCH' }
        $forward = @('-C',$forward[1],'fetch','--quiet',$global:OrvionB4Fixture.Bare,'refs/heads/*:refs/remotes/origin/*')
        Add-Content -LiteralPath $global:OrvionB4Fixture.Transport -Value 'FETCH_LOCAL_BARE'
    } elseif ($verb -eq 'ls-remote') {
        if ($forward.Count -ne 6 -or $forward[3] -cne '--exit-code' -or $forward[4] -cne 'origin' -or $forward[5] -notin @('refs/heads/main','refs/heads/orvion-preflight')) { throw 'FIXTURE_UNEXPECTED_LS_REMOTE' }
        $forward[4] = $global:OrvionB4Fixture.Bare
        Add-Content -LiteralPath $global:OrvionB4Fixture.Transport -Value ('LS_REMOTE_LOCAL_BARE '+$forward[5])
    }
    & $global:OrvionB4Fixture.GitExe @forward
    $global:LASTEXITCODE = $LASTEXITCODE
}
function Read-FixtureConfirmation([string]$Prompt) {
    if ($Prompt -match '^Type ') { if ($global:OrvionB4Fixture.Mode -eq 'cancel') { return '' }; return $global:OrvionB4Fixture.Operation }
    return ''
}
Set-Alias -Name git -Value Invoke-FixtureGit
$invokeArguments = @{Candidate=$global:OrvionB4Fixture.Selected;EvidenceDirectory=$global:OrvionB4Fixture.Evidence}
if ($global:OrvionB4Fixture.Operation -eq 'PUBLISH') { $invokeArguments.Root = $global:OrvionB4Fixture.Root }
if ($global:OrvionB4Fixture.Mode -eq 'noninteractive') { $invokeArguments.NonInteractive = $true }
& $global:OrvionB4Fixture.Interface @invokeArguments
exit $LASTEXITCODE
'@
$driverPath = Join-Path $work 'fixture-driver.ps1'
Write-FixtureText $driverPath $driver
:Products foreach ($product in @(@{Key='self';Repository='PlatPlusHub/CRM'})) {
    $template = Join-Path $work ($product.Key+'-seed')
    [void](Invoke-FixtureSetupGit @('init','--quiet','-b','main',$template))
    [void](Invoke-FixtureSetupGit @('-C',$template,'config','user.name','Isolated caller fixture'))
    [void](Invoke-FixtureSetupGit @('-C',$template,'config','user.email','fixture@example.invalid'))
    [void](Invoke-FixtureSetupGit @('-C',$template,'config','core.autocrlf','false'))
    Write-FixtureText (Join-Path $template '.gitignore') ".orvion-certifications/`n"
    Write-FixtureText (Join-Path $template 'scripts\publish_candidate.ps1') $nativeStub
    Write-FixtureText (Join-Path $template 'scripts\promote_main.ps1') $nativeStub
    foreach ($operation in @('publish','promote')) {
        $subject = Join-Path $Root "scripts\owner_$operation.ps1"
        $originalText = [IO.File]::ReadAllText($subject) -replace "`r`n", "`n"
        Write-FixtureText (Join-Path $template "scripts\owner_$operation.original.ps1") $originalText
        $start = $originalText.IndexOf('$interactive = !$NonInteractive')
        $finish = $originalText.IndexOf("`n"+'$result = ', $start)
        if ($start -lt 0 -or $finish -lt $start) { throw 'FIXTURE_UI_ANCHOR' }
        # The sole policy seam: console detection and Read-Host. All operational functions stay exact.
        $testText = $originalText.Remove($start,$finish-$start).Insert($start,'$interactive = -not $NonInteractive')
        $testText = $testText.Replace('Read-Host ', 'Read-FixtureConfirmation ')
        Write-FixtureText (Join-Path $template "scripts\owner_$operation.ps1") $testText
    }
    [void](Invoke-FixtureSetupGit @('-C',$template,'add','--','.'))
    [void](Invoke-FixtureSetupGit @('-C',$template,'commit','--quiet','-m','Fixture source main and explicit endpoints'))
    $base = (Invoke-FixtureSetupGit @('-C',$template,'rev-parse','HEAD')).Trim()
    [void](Invoke-FixtureSetupGit @('-C',$template,'checkout','--quiet','-b','candidate'))
    Write-FixtureText (Join-Path $template 'candidate.txt') 'Independent synthetic candidate'
    [void](Invoke-FixtureSetupGit @('-C',$template,'add','--','candidate.txt'))
    [void](Invoke-FixtureSetupGit @('-C',$template,'commit','--quiet','-m','Fixture candidate'))
    $candidate = (Invoke-FixtureSetupGit @('-C',$template,'rev-parse','HEAD')).Trim()
    [void](Invoke-FixtureSetupGit @('-C',$template,'branch','orvion-preflight',$candidate))
    [void](Invoke-FixtureSetupGit @('-C',$template,'checkout','--quiet','main'))
    foreach ($operation in @('PUBLISH','PROMOTE')) {
        $modes = @('success','noninteractive','cancel','bad-sha','source-dirty','source-branch','source-origin','source-stale','source-account','source-helper-missing','source-helper-extra','source-helper-no-reset','native-fail','zero-no-done','duplicate-done','contradictory','blocked-and-done','unreadable-and-done','cross-operation','unknown-verdict','wrong-ref')
        if ($operation -eq 'PUBLISH') { $modes += @('candidate-dirty','candidate-origin','candidate-head','missing-receipt','candidate-account','candidate-helper-missing') }
        else { $modes += 'preflight-mismatch' }
        foreach ($mode in $modes) {
            if ($CaseNames.Count -and $mode -notin $CaseNames) { continue }
            $casePath = Join-Path $work ($product.Key+'-'+$operation.ToLowerInvariant()+'-'+$mode)
            $bare = Join-Path $casePath 'remote.git'
            $sourceRoot = Join-Path $casePath 'trusted main'
            $candidateRoot = Join-Path $casePath 'candidate root'
            [void][IO.Directory]::CreateDirectory($casePath)
            [void](Invoke-FixtureSetupGit @('clone','--quiet','--bare','--no-local',$template,$bare))
            if ($mode -eq 'preflight-mismatch') { [void](Invoke-FixtureSetupGit @('-C',$bare,'update-ref','refs/heads/orvion-preflight',$base)) }
            [void](Invoke-FixtureSetupGit @('clone','--quiet','--no-local','-b','main',$bare,$sourceRoot))
            [void](Invoke-FixtureSetupGit @('clone','--quiet','--no-local','-b','candidate',$bare,$candidateRoot))
            foreach ($fixtureRoot in @($sourceRoot,$candidateRoot)) {
                [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'remote','set-url','origin',('https://github.com/'+$product.Repository)))
                [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','protocol.https.allow','never'))
                [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','protocol.ssh.allow','never'))
                [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','gc.auto','0'))
                [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','--local','--add','credential.https://github.com.helper',''))
                [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','--local','--add','credential.https://github.com.helper',('!gh auth token --user '+($product.Repository -split '/')[0])))
            }
            if ($mode -eq 'success' -and $operation -eq 'PUBLISH') {
                $prohibited = @(& $gitExe -C $sourceRoot ls-remote origin refs/heads/main 2>&1)
                $prohibitedExit = $LASTEXITCODE
                Write-FixtureText (Join-Path $casePath 'protocol-refusal.log') ($prohibited -join "`n")
                if ($prohibitedExit -eq 0 -or ($prohibited -join "`n") -notmatch "transport 'https' not allowed") { throw 'FIXTURE_NETWORK_BAN_NOT_PROVEN' }
            }
            Write-FixtureText (Join-Path $candidateRoot ".orvion-certifications\$candidate.json") '{}'
            $selected = $candidate
            switch ($mode) {
                'bad-sha' { $selected = 'bad' }
                'source-dirty' { Write-FixtureText (Join-Path $sourceRoot 'dirt.txt') 'untracked' }
                'source-branch' { [void](Invoke-FixtureSetupGit @('-C',$sourceRoot,'checkout','--quiet','candidate')) }
                'source-origin' { [void](Invoke-FixtureSetupGit @('-C',$sourceRoot,'remote','set-url','origin','https://github.com/fixture/wrong')) }
                'source-stale' { [void](Invoke-FixtureSetupGit @('-C',$bare,'update-ref','refs/heads/main',$candidate)) }
                'candidate-dirty' { Write-FixtureText (Join-Path $candidateRoot 'dirt.txt') 'untracked' }
                'candidate-origin' { [void](Invoke-FixtureSetupGit @('-C',$candidateRoot,'remote','set-url','origin','https://github.com/fixture/wrong')) }
                'candidate-head' { $selected = $base }
                { $_ -in @('source-account','candidate-account','source-helper-no-reset','source-helper-missing','candidate-helper-missing') } {
                    $routingRoot = if ($mode -like 'source-*') { $sourceRoot } else { $candidateRoot }
                    [void](Invoke-FixtureSetupGit @('-C',$routingRoot,'config','--local','--unset-all','credential.https://github.com.helper'))
                    if ($mode -like '*account') {
                        [void](Invoke-FixtureSetupGit @('-C',$routingRoot,'config','--local','--add','credential.https://github.com.helper',''))
                        [void](Invoke-FixtureSetupGit @('-C',$routingRoot,'config','--local','--add','credential.https://github.com.helper','!gh auth token --user FixtureWrongAccount'))
                    } elseif ($mode -eq 'source-helper-no-reset') {
                        [void](Invoke-FixtureSetupGit @('-C',$routingRoot,'config','--local','--add','credential.https://github.com.helper',('!gh auth token --user '+($product.Repository -split '/')[0])))
                    }
                }
                'source-helper-extra' { [void](Invoke-FixtureSetupGit @('-C',$sourceRoot,'config','--local','--add','credential.https://github.com.helper','!fixture-helper-never-executed')) }
                'missing-receipt' {
                    # Move one known fixture file, never recursive cleanup of a computed target.
                    Move-Item -LiteralPath (Join-Path $candidateRoot ".orvion-certifications\$candidate.json") -Destination (Join-Path $casePath 'held-fixture-receipt.json')
                }
                'preflight-mismatch' { } # Established before cloning; do not manufacture a non-fast-forward fetch error.
            }
            $fileName = 'owner_'+$operation.ToLowerInvariant()+$(if($mode-eq'noninteractive'){'.original'}else{''})+'.ps1'
            $config = [ordered]@{Mode=$mode;Operation=$operation;Source=$sourceRoot;Root=$candidateRoot;Bare=$bare;GitExe=$gitExe;Base=$base;Candidate=$candidate;Selected=$selected;Interface=(Join-Path $sourceRoot "scripts\$fileName");NativeCall=(Join-Path $casePath 'native-call.json');Transport=(Join-Path $casePath 'transport.log');Evidence=(Join-Path $casePath 'operation-evidence')}
            $configPath = Join-Path $casePath 'config.json'
            Write-FixtureText $configPath ($config | ConvertTo-Json)
            $lines = @(& pwsh -NoProfile -File $driverPath -Config $configPath 2>&1)
            $code = $LASTEXITCODE
            Write-FixtureText (Join-Path $casePath 'actual.log') (($lines | ForEach-Object{"$_"}) -join "`n")
            $evidenceFiles = @(Get-ChildItem -LiteralPath $config.Evidence -Filter '*.json' -ErrorAction SilentlyContinue)
            $record = if ($evidenceFiles.Count -eq 1) { Get-Content -Raw -LiteralPath $evidenceFiles[0].FullName | ConvertFrom-Json } else { $null }
            $native = if (Test-Path -LiteralPath $config.NativeCall) { Get-Content -Raw -LiteralPath $config.NativeCall | ConvertFrom-Json } else { $null }
            $expectsNative = $mode -in @('success','native-fail','zero-no-done','duplicate-done','contradictory','blocked-and-done','unreadable-and-done','cross-operation','unknown-verdict','wrong-ref')
            $ok = $null -ne $record -and ($null -ne $native) -eq $expectsNative
            $reason = ''
            if ($mode -eq 'success') {
                $expectedScript = Join-Path $sourceRoot ('scripts\'+$(if($operation-eq'PUBLISH'){'publish_candidate'}else{'promote_main'})+'.ps1')
                $ok = $ok -and $code -eq 0 -and $record.result -ceq 'DONE' -and $native.Script -ieq $expectedScript
                if ($operation -eq 'PUBLISH') { $ok = $ok -and $native.Root -ieq $candidateRoot -and !$native.Candidate }
                else { $ok = $ok -and $native.Candidate -ceq $candidate -and !$native.Root }
            } else {
                $ok = $ok -and $code -ne 0 -and $record.result -cne 'DONE' -and !@($lines|Where-Object{"$_"-ceq"${operation}: DONE"}).Count
                if ($mode -eq 'noninteractive') { $ok = $ok -and $record.classification -ceq 'INTERACTIVE_CONFIRMATION_REQUIRED' -and !(Test-Path -LiteralPath $config.Transport) }
                if ($mode -eq 'cancel') { $ok = $ok -and $code -eq 2 -and $record.result -ceq 'CANCELLED' }
                if ($mode -eq 'native-fail') { $ok = $ok -and $code -eq 7 }
                $reasonPattern = switch ($mode) {
                    'bad-sha' { 'full 40-character hexadecimal SHA' }
                    'source-dirty' { 'clean trusted main checkout' }
                    'source-branch' { 'clean trusted main checkout' }
                    'source-origin' { 'Wrong trusted source repository' }
                    'source-stale' { 'no automatic fast-forward' }
                    { $_ -in @('source-account','source-helper-extra','source-helper-no-reset') } { 'Trusted source credential routing is not pinned' }
                    'source-helper-missing' { 'Trusted source Git read failed' }
                    'candidate-dirty' { 'Original checkout is dirty' }
                    'candidate-origin' { 'fetch/push destination' }
                    'candidate-head' { 'Original HEAD is' }
                    'candidate-account' { 'Candidate credential routing is not pinned' }
                    'candidate-helper-missing' { 'Git read failed: config' }
                    'missing-receipt' { 'exact-SHA certification record is missing' }
                    'preflight-mismatch' { 'Current preflight does not match' }
                    'wrong-ref' { 'Remote (preflight|main) does not match' }
                    { $_ -in @('zero-no-done','duplicate-done','contradictory','blocked-and-done','unreadable-and-done','cross-operation','unknown-verdict') } { 'one unambiguous DONE' }
                    default { '' }
                }
                if ($reasonPattern) { $ok = $ok -and (($lines -join "`n") -match $reasonPattern) }
            }
            if (!$ok) { $reason = ($lines | ForEach-Object{"$_"}) -join "`n" }
            $records.Add([pscustomobject]@{Product=$product.Key;Operation=$operation;Case=$mode;Passed=[bool]$ok;Exit=$code;Result=$record.result;Classification=$record.classification;NativeCalled=($null-ne$native);Fixture=$casePath;Failure=$reason})
            Write-Host ("{0} {1}/{2}/{3}: exit{4} {5}" -f $(if($ok){'PASS'}else{'FAIL'}),$product.Key,$operation,$mode,$code,$record.result)
            if ($MaxCases -gt 0 -and $records.Count -ge $MaxCases) { break Products }
        }
    }
}
$failed = @($records | Where-Object {!$_.Passed}).Count
$result = [ordered]@{Passed=$records.Count-$failed;Failed=$failed;Cases=$records;ProofBoundary='Actual adapter child execution; unmodified noninteractive refusal; explicit console/transport seams for positive/operational routes. All remotes are owned fixture bare repositories; HTTPS/SSH prohibited. Stub endpoints prove binding/verdict/ref handling, not native certification, authenticated actor identity, real publication or promotion.'}
Write-FixtureText $output (($result | ConvertTo-Json -Depth 8)+"`n")
"B4_INTERFACES: $($records.Count-$failed) passed, $failed failed; fixture root: $work (retained on failure)"
if ($failed -eq 0) {
    $resolvedWork=[IO.Path]::GetFullPath($work)
    $temporaryParent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
    if ((Split-Path $resolvedWork -Parent) -ine $temporaryParent -or (Split-Path $resolvedWork -Leaf) -notmatch '^orvion-owner-interfaces-[0-9a-f]{32}$') { throw 'UNSAFE_FIXTURE_CLEANUP' }
    Remove-Item -LiteralPath $resolvedWork -Recurse -Force -ErrorAction Stop
} else { Write-Host "Failed fixture root: $work (retained on failure)" }
exit [int]($failed -gt 0)
