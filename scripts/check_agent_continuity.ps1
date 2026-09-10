[CmdletBinding(DefaultParameterSetName='Boot')]
param(
    [Parameter(ParameterSetName='Boot',Mandatory=$true)][switch]$Boot,
    [Parameter(ParameterSetName='Gate',Mandatory=$true)][switch]$Gate,
    [Parameter(ParameterSetName='Finish',Mandatory=$true)][switch]$Finish,
    [string]$Root=(Split-Path $PSScriptRoot -Parent), [string]$BaseRef,
    [string]$HeadRef='HEAD', [string[]]$Capabilities=@(), [switch]$SkipRepositoryGuard
)
$ErrorActionPreference='Stop'

function Section([string]$Text,[string]$Name,[switch]$Optional) {
    $m=[regex]::Matches($Text,"(?ms)^## $([regex]::Escape($Name))\s*\r?\n(?<b>.*?)(?=^## |\z)")
    if($m.Count -ne 1){if($Optional-and$m.Count-eq 0){return $null};throw "CONTRACT_SECTION_${Name}:count=$($m.Count)"}
    $m[0].Groups['b'].Value.Trim()
}
function Bullets([string]$Body) {
    if(!$Body-or$Body.Trim()-eq'None'){return @()}
    @([regex]::Matches($Body,'(?m)^-\s+`?(?<v>[^`\r\n]+)`?\s*$')|%{$_.Groups['v'].Value.Trim()})
}
function Contract([string]$Path) {
    if(!(Test-Path -LiteralPath $Path)){throw "STALE_ACTIVE_CR:$Path"}
    $t=Get-Content -Raw -LiteralPath $Path
    $checked=@([regex]::Matches((Section $t 'Status'),'(?im)^\[x\]\s+(?<v>.+?)\s*$')|%{$_.Groups['v'].Value.Trim()})
    if($checked.Count-ne 1-or @('Draft','Approved','In Progress','Complete','Cancelled')-notcontains$checked[0]){throw 'INVALID_CR_STATUS'}
    foreach($n in @('Write Scope','Required Reading','Runtime Checkpoint','Required Capabilities','Additional Verification','Implementation Steps')){[void](Section $t $n)}
    $cp=Section $t 'Runtime Checkpoint'
    $resume=[regex]::Match($cp,'(?m)^Resume Step:\s*(?<v>DONE|[1-9][0-9]*)\s*$')
    $block=[regex]::Match($cp,'(?m)^Blocker:\s*(?<v>None|[A-Z][A-Z0-9_]*)\s*$')
    $attempt=[regex]::Match($cp,'(?m)^Recovery Attempt:\s*(?<v>[0-3])\s*$')
    if(!$resume.Success-or!$block.Success-or!$attempt.Success){throw 'INVALID_RUNTIME_CHECKPOINT'}
    $sm=[regex]::Matches((Section $t 'Implementation Steps'),'(?m)^(?<n>[1-9][0-9]*)\.\s+(?<v>.+)$')
    if(!$sm.Count){throw 'NO_IMPLEMENTATION_STEPS'}
    for($i=0;$i-lt$sm.Count;$i++){if([int]$sm[$i].Groups['n'].Value-ne$i+1){throw 'NONSEQUENTIAL_IMPLEMENTATION_STEPS'}}
    if($resume.Groups['v'].Value-ne'DONE'-and[int]$resume.Groups['v'].Value-gt$sm.Count){throw 'INVALID_RESUME_STEP'}
    $scope=Bullets (Section $t 'Write Scope');if(!$scope.Count){throw 'EMPTY_WRITE_SCOPE'}
    [pscustomobject]@{Path=$Path;Id=([IO.Path]::GetFileNameWithoutExtension($Path)-replace '-agent-control-plane$','').ToUpper();Status=$checked[0];Resume=$resume.Groups['v'].Value;Blocker=$block.Groups['v'].Value;Attempt=[int]$attempt.Groups['v'].Value;Steps=@($sm|%{$_.Groups['v'].Value.Trim()});Scope=$scope;Reading=Bullets (Section $t 'Required Reading');RequiredCapabilities=Bullets (Section $t 'Required Capabilities');AdditionalVerification=Bullets (Section $t 'Additional Verification')}
}
function Manifest {
    $p=Join-Path $Root '_ORVION_CANONICAL/manifest.md';if(!(Test-Path $p)){throw 'MANIFEST_MISSING'};$t=Get-Content -Raw $p
    $a=[regex]::Match($t,'(?m)^Active Change Request:\s*(?<v>.+?)\s*$');if(!$a.Success){throw 'ACTIVE_CR_FIELD_MISSING'}
    $n=[regex]::Match($t,'(?ms)^Next capability:\s*(?<v>.*?)(?=\r?\n(?:---|#\s)|\z)')
    $v=$a.Groups['v'].Value.Trim().TrimEnd('.').Trim('`')
    [pscustomobject]@{Active=if($v-eq'None'){$null}else{$v};Next=if($n.Success){($n.Groups['v'].Value-replace'\s+',' ').Trim()}else{''}}
}
function Changed {
    if($BaseRef){return @(git -C $Root diff --name-only --diff-filter=ACDMRT "$BaseRef..$HeadRef" --)}
    @(@(git -C $Root diff --name-only --diff-filter=ACDMRT --)+@(git -C $Root diff --cached --name-only --diff-filter=ACDMRT --)+@(git -C $Root ls-files --others --exclude-standard)|%{$_-replace'\\','/'}|sort -Unique)
}
function Resolve-Contract($m) {
    if($m.Active){return $m.Active}
    $changed=if($BaseRef){@(git -C $Root diff --name-only "$BaseRef..$HeadRef" -- 'changes/SPEC-*.md')}else{@(git -C $Root diff --cached --name-only -- 'changes/SPEC-*.md')}
    $c=@();foreach($p in $changed){try{$x=Contract(Join-Path $Root $p);if($x.Status-eq'Complete'){$c+=$p}}catch{}}
    if(!$BaseRef-and!$c.Count){return $null}
    if(!$c.Count){throw 'NO_GOVERNING_CR'};if($c.Count-gt 1){throw 'AMBIGUOUS_GOVERNING_CR'};$c[0]
}
function Profiles($scope) {
    $h=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);[void]$h.Add('REPOSITORY')
    foreach($p in $scope){if($p-match'^(AGENTS\.md|CR_LIFECYCLE\.md|changes/TEMPLATE\.md|scripts/(check|test)_agent_continuity\.ps1|\.githooks/|\.github/workflows/agent-control\.yml)'){[void]$h.Add('CONTROL')};if($p-match'^\.github/workflows/'){[void]$h.Add('CI')};if($p-match'^\.workstation/'){[void]$h.Add('WORKSTATION')};if($p-match'^(supabase/migrations/|scripts/verify_database\.sql|reports/master/MASTER_DATABASE_)'){[void]$h.Add('DATABASE')}}
    @($h|sort)
}
function Capabilities($c) {
    $a=@($Capabilities);if($env:ORVION_CAPABILITIES){$a+=@($env:ORVION_CAPABILITIES-split',')};if(Get-Command gh -EA SilentlyContinue){$a+='github'}
    foreach($n in $c.RequiredCapabilities){if($a-notcontains$n){throw "MISSING_REQUIRED_CAPABILITY:$n"}}
}
function Repo-Guard {
    if($SkipRepositoryGuard){return 'skipped'};$g=Join-Path $Root 'scripts/check_repository_consistency.ps1';if(!(Test-Path $g)){throw 'REPOSITORY_GUARD_MISSING'}
    $log=Join-Path ([IO.Path]::GetTempPath())("orvion-repository-guard-$([guid]::NewGuid().ToString('N')).log")
    & pwsh -NoProfile -File $g *>$log;if($LASTEXITCODE-ne0-or(Get-Content -Raw $log)-notmatch'REPOSITORY CONSISTENCY: CLEAN'){throw "REPOSITORY_CONSISTENCY_FAILED:$log"};'clean'
}
function Git-State {
    $d=@(git -C $Root status --porcelain).Count-gt0;git -C $Root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null|Out-Null
    if($LASTEXITCODE-ne0){return[pscustomobject]@{Text="$(if($d){'dirty'}else{'clean'}) | no upstream";Synced=$false}}
    $x=(git -C $Root rev-list --left-right --count 'HEAD...@{u}')-split'\s+';[pscustomobject]@{Text="$(if($d){'dirty'}else{'clean'}) | ahead $($x[0]) / behind $($x[1])";Synced=([int]$x[1]-eq0)}
}
function Block($message){$p=$message-split':',2;Write-Output 'ORVION: BLOCKED';Write-Output "CODE: $($p[0])";if($p.Count-gt1){Write-Output "SUBJECT: $($p[1])"};Write-Output "EVIDENCE: $message";Write-Output 'NEXT: inspect the named authority/evidence, repair within Write Scope, then rerun.'}

try{
    Set-Location $Root;$agents=Join-Path $Root 'AGENTS.md';if(!(Test-Path $agents)){throw 'AGENTS_MISSING'};if((Get-Item $agents).Length-gt16384){throw "AGENTS_SIZE_EXCEEDED:$((Get-Item $agents).Length)"};$m=Manifest;$rel=Resolve-Contract $m
    if(!$rel){if($Gate){$bad=@(Changed|?{$_-notmatch'^changes/SPEC-[0-9]+[^/]*\.md$'});if($bad.Count){throw "NO_GOVERNING_CR:$($bad-join',')"}};Write-Output 'ORVION: READY';Write-Output 'MODE: PLAN';Write-Output 'ACTIVE_CR: none';Write-Output "NEXT_CAPABILITY: $($m.Next)";Write-Output 'WRITE_AUTHORITY: none (Draft CR authoring only)';exit 0}
    $c=Contract(Join-Path $Root $rel);$rangeCompletion=(-not$m.Active-and($BaseRef-or$Gate));$mode=switch($c.Status){'Draft'{'READY_FOR_APPROVAL'} {$_-in@('Approved','In Progress')}{if($c.Blocker-ne'None'){'BLOCKED'}elseif($c.Resume-eq'DONE'){'VERIFY'}else{'EXECUTE'}} 'Complete'{if($rangeCompletion){'VERIFY'}else{'BLOCKED'}} default{'BLOCKED'}}
    if($mode-eq'BLOCKED'){throw "RUNTIME_BLOCKED:$($c.Blocker)"}
    if($mode-eq'EXECUTE'){Capabilities $c};$repo=Repo-Guard;$git=Git-State;if(!$git.Synced){throw "GIT_NOT_SYNCHRONIZED:$($git.Text)"}
    if($Gate-or$Finish){$scope=@($c.Scope|%{$_-replace'\\','/'});foreach($p in Changed){if($p-ne($rel-replace'\\','/')-and$scope-notcontains$p){throw "OUT_OF_SCOPE_WRITE:$p"}}}
    $profiles=Profiles $c.Scope;if($Finish-and$mode-ne'VERIFY'){throw "FINISH_NOT_READY:$mode"}
    Write-Output 'ORVION: READY';Write-Output "MODE: $mode";Write-Output "CR: $($c.Id)";Write-Output "STATUS: $($c.Status)";Write-Output "STEP: $(if($c.Resume-eq'DONE'){'DONE'}else{"$($c.Resume)/$($c.Steps.Count)"})"
    if($mode-eq'EXECUTE'){Write-Output 'ACTION:';Write-Output $c.Steps[[int]$c.Resume-1]};Write-Output "WRITE: $($c.Scope-join', ')";Write-Output "START_CONTEXT: $($c.Reading-join', ')";Write-Output "VERIFICATION: $((@($profiles)+@($c.AdditionalVerification))-join', ')";Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo";Write-Output "BLOCKER: $($c.Blocker.ToLowerInvariant())";if($Finish){Write-Output 'CERTIFY: READY'}
}catch{Block $_.Exception.Message;exit 1}
