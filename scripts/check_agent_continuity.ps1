[CmdletBinding(DefaultParameterSetName='Boot')]
param(
    [Parameter(ParameterSetName='Boot',Mandatory=$true)][switch]$Boot,
    [Parameter(ParameterSetName='Gate',Mandatory=$true)][switch]$Gate,
    [Parameter(ParameterSetName='Finish',Mandatory=$true)][switch]$Finish,
    [string]$Root=(Split-Path $PSScriptRoot -Parent),
    [string]$BaseRef,
    [string]$HeadRef='HEAD'
)
$ErrorActionPreference='Stop'

function Section([string]$Text,[string]$Name,[switch]$Optional) {
    $m=[regex]::Matches($Text,"(?ms)^## $([regex]::Escape($Name))\s*\r?\n(?<b>.*?)(?=^## |\z)")
    if($m.Count-ne1){if($Optional-and$m.Count-eq0){return $null};throw "CONTRACT_SECTION_${Name}:count=$($m.Count)"}
    $m[0].Groups['b'].Value.Trim()
}
function Bullets([string]$Body,[string]$Name) {
    if(!$Body-or$Body.Trim()-eq'None'){return @()}
    $values=@()
    foreach($line in @($Body-split'\r?\n'|Where-Object{$_.Trim()})){
        $m=[regex]::Match($line,'^-\s+(?<v>.+?)\s*$')
        if(!$m.Success){throw "INVALID_${Name}:$line"}
        $value=$m.Groups['v'].Value.Trim()
        if($value.StartsWith('`')-and$value.EndsWith('`')){$value=$value.Substring(1,$value.Length-2)}
        $values+=$value
    }
    $values
}
function Status-FromText([string]$Text) {
    $checked=@([regex]::Matches((Section $Text 'Status'),'(?im)^\[x\]\s+(?<v>.+?)\s*$')|%{$_.Groups['v'].Value.Trim()})
    if($checked.Count-ne1-or @('Draft','Approved','In Progress','Complete','Cancelled')-notcontains$checked[0]){throw 'INVALID_CR_STATUS'}
    $checked[0]
}
function Contract([string]$Path) {
    if(!(Test-Path -LiteralPath $Path)){throw "STALE_ACTIVE_CR:$Path"}
    $t=Get-Content -Raw -LiteralPath $Path
    $headings=@([regex]::Matches($t,'(?m)^# Change Request — (?<id>SPEC-[0-9]+)\s*$'))
    if($headings.Count-ne1){throw "INVALID_CR_HEADING:count=$($headings.Count)"}
    $id=$headings[0].Groups['id'].Value.ToUpperInvariant();$base=[IO.Path]::GetFileName($Path)
    if($base-notmatch('^'+[regex]::Escape($id)+'-')){throw "CR_ID_PATH_MISMATCH:${base}:${id}"}
    $status=Status-FromText $t
    foreach($n in @('Write Scope','Required Reading','Runtime Checkpoint','Required Capabilities','Additional Verification','Implementation Steps')){[void](Section $t $n)}
    $cp=Section $t 'Runtime Checkpoint'
    $resume=[regex]::Match($cp,'(?m)^Resume Step:\s*(?<v>DONE|[1-9][0-9]*)\s*$')
    $block=[regex]::Match($cp,'(?m)^Blocker:\s*(?<v>None|[A-Z][A-Z0-9_]*)\s*$')
    $attempt=[regex]::Match($cp,'(?m)^Recovery Attempt:\s*(?<v>[0-3])\s*$')
    if(!$resume.Success-or!$block.Success-or!$attempt.Success){throw 'INVALID_RUNTIME_CHECKPOINT'}
    $sm=@([regex]::Matches((Section $t 'Implementation Steps'),'(?ms)^(?<n>[1-9][0-9]*)\.\s+(?<v>.*?)(?=^[1-9][0-9]*\.\s+|\z)'))
    if(!$sm.Count){throw 'NO_IMPLEMENTATION_STEPS'}
    for($i=0;$i-lt$sm.Count;$i++){if([int]$sm[$i].Groups['n'].Value-ne$i+1){throw 'NONSEQUENTIAL_IMPLEMENTATION_STEPS'}}
    if($resume.Groups['v'].Value-ne'DONE'-and[int]$resume.Groups['v'].Value-gt$sm.Count){throw 'INVALID_RESUME_STEP'}
    $scope=Bullets (Section $t 'Write Scope') 'WRITE_SCOPE';if(!$scope.Count){throw 'EMPTY_WRITE_SCOPE'}
    $additional=Bullets (Section $t 'Additional Verification') 'ADDITIONAL_VERIFICATION'
    foreach($command in $additional){if($command-match'^(?i:Prove|Verify)\b'){throw "INVALID_ADDITIONAL_VERIFICATION:$command"}}
    [pscustomobject]@{Path=$Path;Id=$id;Status=$status;Resume=$resume.Groups['v'].Value;Blocker=$block.Groups['v'].Value;Attempt=[int]$attempt.Groups['v'].Value;Steps=@($sm|%{$_.Groups['v'].Value.Trim()});Scope=$scope;Reading=Bullets (Section $t 'Required Reading') 'REQUIRED_READING';RequiredCapabilities=Bullets (Section $t 'Required Capabilities') 'REQUIRED_CAPABILITIES';AdditionalVerification=$additional}
}
function Manifest {
    $p=Join-Path $Root '_ORVION_CANONICAL/manifest.md';if(!(Test-Path $p)){throw 'MANIFEST_MISSING'};$t=Get-Content -Raw $p
    $a=[regex]::Match($t,'(?m)^Active Change Request:\s*(?<v>.+?)\s*$');if(!$a.Success){throw 'ACTIVE_CR_FIELD_MISSING'}
    $n=[regex]::Match($t,'(?ms)^Next capability:\s*(?<v>.*?)(?=\r?\n(?:---|#\s)|\z)');$v=$a.Groups['v'].Value.Trim().TrimEnd('.').Trim('`')
    [pscustomobject]@{Active=if($v-eq'None'){$null}else{$v};Next=if($n.Success){($n.Groups['v'].Value-replace'\s+',' ').Trim()}else{''}}
}
function Assert-Ref([string]$Ref){git -C $Root cat-file -e "$Ref^{commit}" 2>$null;if($LASTEXITCODE-ne0){throw "INVALID_GIT_REF:$Ref"}}
function Diff-Records {
    $lines=if($BaseRef){@(git -C $Root diff --name-status -M "$BaseRef..$HeadRef" --)}else{@(git -C $Root diff --name-status -M HEAD --)}
    $records=@()
    foreach($line in $lines){$parts=$line-split"`t";$code=$parts[0].Substring(0,1);if($code-eq'R'){$records+=[pscustomobject]@{Code='R';Old=($parts[1]-replace'\\','/');Path=($parts[2]-replace'\\','/')}}else{$records+=[pscustomobject]@{Code=$code;Old=$null;Path=($parts[1]-replace'\\','/')}}}
    if(!$BaseRef){foreach($p in @(git -C $Root ls-files --others --exclude-standard)){$records+=[pscustomobject]@{Code='A';Old=$null;Path=($p-replace'\\','/')}}}
    @($records|Sort-Object Path -Unique)
}
function Read-GitFile([string]$Ref,[string]$Path){$value=git -C $Root show "${Ref}:$Path" 2>$null;if($LASTEXITCODE-ne0){return $null};$value-join"`n"}
function Base-HasId([string]$Ref,[string]$Id){
    $rx='(^|[^0-9])'+[regex]::Escape($Id)+'([^0-9]|$)'
    foreach($path in @(git -C $Root ls-tree -r --name-only $Ref)){if($path-match$rx){return $true}}
    $hits=@(git -C $Root grep -I -E ([regex]::Escape($Id)+'([^0-9]|$)') $Ref -- . 2>$null);$LASTEXITCODE=0
    $hits.Count-gt0
}
function Historical-Guard-IsActive([string]$Ref){if(!$BaseRef){return $true};$old=Read-GitFile $Ref 'scripts/check_agent_continuity.ps1';$null-ne$old-and$old.Contains('HISTORICAL_CR_MUTATION')}
function Validate-HistoryAndIds([object[]]$Records,[string]$Ref){
    $historyActive=Historical-Guard-IsActive $Ref
    foreach($r in $Records){
        if($historyActive){foreach($p in @($r.Path,$r.Old)|?{$_}|select -Unique){if($p-match'^changes/SPEC-[0-9]+-.*\.md$'){$old=Read-GitFile $Ref $p;if($null-ne$old){$s=Status-FromText $old;if($s-in@('Complete','Cancelled')){throw "HISTORICAL_CR_MUTATION:$p"}}}}}
        if($r.Path-match'^changes/(?<id>SPEC-[0-9]+)-.*\.md$' -and $null-eq(Read-GitFile $Ref $r.Path)){$id=$Matches['id'];if(Base-HasId $Ref $id){throw "SPEC_ID_ALREADY_USED:$id"}}
    }
}
function Resolve-Contract($m,[object[]]$Records){
    if($m.Active){return $m.Active}
    $changed=@($Records|?{$_.Path-match'^changes/SPEC-[0-9]+-.*\.md$'}|%{$_.Path}|select -Unique);$c=@()
    foreach($p in $changed){if(Test-Path(Join-Path $Root $p)){try{$x=Contract(Join-Path $Root $p);if($x.Status-eq'Complete'){$c+=$p}}catch{}}}
    if(!$BaseRef-and!$c.Count){return $null};if(!$c.Count){throw 'NO_GOVERNING_CR'};if($c.Count-gt1){throw 'AMBIGUOUS_GOVERNING_CR'}
    $base=if($BaseRef){$BaseRef}else{'HEAD'};$old=Read-GitFile $base $c[0];if($null-eq$old-or(Status-FromText $old)-ne'In Progress'){throw "INVALID_COMPLETION_TRANSITION:$($c[0])"};$c[0]
}
function Profiles($scope){
    $h=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);[void]$h.Add('REPOSITORY')
    foreach($p in $scope){if($p-match'^(AGENTS\.md|CR_LIFECYCLE\.md|changes/TEMPLATE\.md|scripts/(check|test)_agent_continuity\.ps1|\.githooks/|\.github/workflows/agent-control\.yml)'){[void]$h.Add('CONTROL')};if($p-match'^\.github/workflows/'){[void]$h.Add('CI')};if($p-match'^\.workstation/'){[void]$h.Add('WORKSTATION')};if($p-match'^(supabase/migrations/|scripts/verify_database\.sql|reports/master/MASTER_DATABASE_)'){[void]$h.Add('DATABASE')}};@($h|sort)
}
function Test-Capabilities($c){
    foreach($name in $c.RequiredCapabilities){if($name-ne'github'){throw "NO_DETERMINISTIC_CAPABILITY_PROBE:$name"};gh auth status *>$null;if($LASTEXITCODE-ne0){throw 'MISSING_REQUIRED_CAPABILITY:github:gh_auth_status'};git -C $Root ls-remote origin HEAD *>$null;if($LASTEXITCODE-ne0){throw 'MISSING_REQUIRED_CAPABILITY:github:git_ls_remote'}}
}
function Repo-Guard {
    $g=Join-Path $Root 'scripts/check_repository_consistency.ps1';if(!(Test-Path $g)){throw 'REPOSITORY_GUARD_MISSING'};$log=Join-Path([IO.Path]::GetTempPath())("orvion-repository-guard-$([guid]::NewGuid().ToString('N')).log")
    & pwsh -NoProfile -File $g *>$log;if($LASTEXITCODE-ne0-or(Get-Content -Raw $log)-notmatch'REPOSITORY CONSISTENCY: CLEAN'){throw "REPOSITORY_CONSISTENCY_FAILED:$log"};Remove-Item -LiteralPath $log -Force;'clean'
}
function Git-State {
    if($BaseRef){Assert-Ref $BaseRef;Assert-Ref $HeadRef;return [pscustomobject]@{Text="range $BaseRef..$HeadRef";Synced=$true}}
    git -C $Root fetch --prune origin *>$null;if($LASTEXITCODE-ne0){throw 'GIT_FETCH_FAILED:origin'};git -C $Root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null|Out-Null;if($LASTEXITCODE-ne0){throw 'GIT_UPSTREAM_MISSING'}
    $x=(git -C $Root rev-list --left-right --count 'HEAD...@{u}')-split'\s+';$dirty=@(git -C $Root status --porcelain).Count-gt0
    [pscustomobject]@{Text="$(if($dirty){'dirty'}else{'clean'}) | ahead $($x[0]) / behind $($x[1])";Synced=([int]$x[1]-eq0)}
}
function Invoke-Verification([string]$Command,[switch]$Additional){Write-Output "RUN: $Command";& pwsh -NoProfile -Command $Command;if($LASTEXITCODE-ne0){if($Additional){throw "ADDITIONAL_VERIFICATION_FAILED:$Command"};throw "MANDATORY_VERIFICATION_FAILED:$Command"}}
function Finish-Checks($c,[string[]]$profiles){
    $commands=@();if($profiles-contains'REPOSITORY'){$commands+=@('pwsh -NoProfile -File scripts/check_repository_consistency.ps1','git diff --check')}
    if($profiles-contains'CONTROL'){$commands+=@('pwsh -NoProfile -File scripts/test_agent_continuity.ps1','pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1','pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1','pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1','pwsh -NoProfile -File scripts/test_future_date_guard.ps1')}
    foreach($command in $commands){Invoke-Verification $command};foreach($command in $c.AdditionalVerification){Invoke-Verification $command -Additional}
}
function Block($message){if($message-eq'RECOVERY_EXHAUSTED'){Write-Output 'HARD_BLOCKED: RECOVERY_EXHAUSTED';return};$p=$message-split':',2;Write-Output 'ORVION: BLOCKED';Write-Output "CODE: $($p[0])";if($p.Count-gt1){Write-Output "SUBJECT: $($p[1])"};Write-Output "EVIDENCE: $message";Write-Output 'NEXT: inspect the named authority/evidence, repair within Write Scope, then rerun.'}

try{
    Set-Location $Root;if(!(Test-Path(Join-Path $Root 'AGENTS.md'))){throw 'AGENTS_MISSING'};if($BaseRef){Assert-Ref $BaseRef;Assert-Ref $HeadRef}
    $records=@(Diff-Records);$base=if($BaseRef){$BaseRef}else{'HEAD'};Validate-HistoryAndIds $records $base
    $m=Manifest;$rel=Resolve-Contract $m $records;$repo=Repo-Guard;$git=Git-State;if(!$git.Synced){throw "GIT_NOT_SYNCHRONIZED:$($git.Text)"}
    if(!$rel){$bad=@($records|?{if($_.Path-notmatch'^changes/SPEC-[0-9]+-.*\.md$'){return $true};try{$draft=Contract(Join-Path $Root $_.Path);return $draft.Status-notin@('Draft','Approved')}catch{return $true}});if($bad.Count){throw "NO_GOVERNING_CR:$((@($bad|%{$_.Path})|sort -Unique)-join',')"};Write-Output 'ORVION: READY';Write-Output 'MODE: PLAN';Write-Output 'ACTIVE_CR: none';Write-Output "NEXT_CAPABILITY: $($m.Next)";Write-Output 'WRITE_AUTHORITY: none (Draft CR authoring only)';Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo";exit 0}
    $c=Contract(Join-Path $Root $rel);$completionTransition=(-not$m.Active)
    $mode=switch($c.Status){'Draft'{'READY_FOR_APPROVAL'} {$_-in@('Approved','In Progress')}{if($c.Blocker-ne'None'){if($c.Attempt-eq3){throw 'RECOVERY_EXHAUSTED'};'BLOCKED'}elseif($c.Resume-eq'DONE'){'VERIFY'}else{'EXECUTE'}} 'Complete'{if($completionTransition){'VERIFY'}else{'BLOCKED'}} default{'BLOCKED'}}
    if($mode-eq'BLOCKED'){throw "RUNTIME_BLOCKED:$($c.Blocker)"};if(!$BaseRef){Test-Capabilities $c}
    $scope=@($c.Scope|%{$_-replace'\\','/'});foreach($r in $records){foreach($p in @($r.Path,$r.Old)|?{$_}){if($p-ne($rel-replace'\\','/')-and$scope-notcontains$p){throw "OUT_OF_SCOPE_WRITE:$p"}}}
    $profiles=Profiles $c.Scope;if($Finish-and$mode-ne'VERIFY'){throw "FINISH_NOT_READY:$mode"}
    Write-Output 'ORVION: READY';Write-Output "MODE: $mode";Write-Output "CR: $($c.Id)";Write-Output "STATUS: $($c.Status)";Write-Output "STEP: $(if($c.Resume-eq'DONE'){'DONE'}else{"$($c.Resume)/$($c.Steps.Count)"})"
    if($mode-eq'EXECUTE'){Write-Output 'ACTION:';Write-Output $c.Steps[[int]$c.Resume-1]};Write-Output "WRITE: $($c.Scope-join', ')";Write-Output "START_CONTEXT: $($c.Reading-join', ')";Write-Output "VERIFICATION: $((@($profiles)+@($c.AdditionalVerification))-join', ')";Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo";Write-Output "BLOCKER: $($c.Blocker.ToLowerInvariant())";if($Finish){Finish-Checks $c $profiles;Write-Output 'LOCAL_CERTIFY: READY'}
}catch{if($Finish){Write-Output 'CERTIFY: FAILED'};Block $_.Exception.Message;exit 1}
