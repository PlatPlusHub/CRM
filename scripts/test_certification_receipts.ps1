# SPEC-284: actual evaluator/publisher subprocesses, isolated Git repositories.
# Profile children and gh responses are explicit fixtures: this tests orchestration,
# receipt continuity and the real remote reader, never hosted GitHub enforcement.
param([ValidateSet('All','Codec','Sequence','Mutations')][string]$Case='All')
$ErrorActionPreference='Stop'
$sourceRoot=Split-Path $PSScriptRoot -Parent
$control=Join-Path $PSScriptRoot 'check_agent_continuity.ps1'
$publisher=Join-Path $PSScriptRoot 'publish_candidate.ps1'
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('orvion-receipts-'+[guid]::NewGuid().ToString('N'))
$root=Join-Path $sandbox 'original';$remote=Join-Path $sandbox 'remote.git'
$bin=Join-Path $sandbox 'bin';$rows=Join-Path $sandbox 'rows';$hooks=Join-Path $sandbox 'hooks'

# Reader-only dependency bridge. Receipt implementation and every prior assertion stay unchanged.
[void][IO.Directory]::CreateDirectory($sandbox)
$readerFixture=Join-Path $sandbox 'reader-fixture.ps1'
$fixture=@'
function Get-OrvionPublicRepo([string]$Root) { 'fixture/repository' }
function Get-OrvionPublicRuns([string]$Repo,[string]$Sha='',[string]$Branch='',[string]$Event='',[string]$WorkflowPath='') {
    $raw=gh run list --commit $Sha --branch $Branch --event $Event
    if($LASTEXITCODE-ne0){throw 'PUBLIC_READ:FIXTURE_UNREADABLE'}
    $raw|ConvertFrom-Json
}
'@
[IO.File]::WriteAllText($readerFixture,$fixture)
$copy=Join-Path $sandbox 'evaluator.ps1'
$text=[IO.File]::ReadAllText($control).Replace('. (Join-Path $PSScriptRoot ''github_public_read.ps1'')',(". '"+$readerFixture.Replace("'","''")+"'"))
[IO.File]::WriteAllText($copy,$text);$control=$copy

$script:pass=0;$script:fail=0
function Assert([string]$Name,[bool]$Ok,[string]$Evidence=''){
    if($Ok){$script:pass++;Write-Host "PASS $Name"}else{$script:fail++;Write-Host "FAIL $Name :: $Evidence"}
}
function Put([string]$Rel,[string]$Text){$p=Join-Path $root $Rel;[void][IO.Directory]::CreateDirectory((Split-Path $p -Parent));[IO.File]::WriteAllText($p,$Text,[Text.UTF8Encoding]::new($false))}
function Commit([string]$Message){git -C $root add .;git -C $root commit --quiet -m $Message;if($LASTEXITCODE){throw "fixture commit failed:$Message"};("$(git -C $root rev-parse HEAD)").Trim()}
function Json([string]$Path){Read-ReceiptJson $Path}
function SaveJson([string]$Path,$Object){[IO.File]::WriteAllText($Path,(ConvertTo-Json $Object -Depth 20),[Text.UTF8Encoding]::new($false))}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function RunEval([string]$Mode,[string[]]$Extra=@(),[string]$Evaluator=$control,[string]$At=$root){
    $o=& pwsh -NoProfile -File $Evaluator "-$Mode" -Root $At @Extra 2>&1
    [pscustomobject]@{Code=$LASTEXITCODE;Text=($o|Out-String)}
}
function Bind([string]$Sha,[string]$Evaluator=$control){RunEval Gate @('-BindCandidate','-BaseRef',$script:base,'-HeadRef',$Sha) $Evaluator}
function Ref([string]$Name){$value=git -C $remote rev-parse "refs/heads/$Name" 2>$null;if($LASTEXITCODE-ne0){return ''};("$value").Trim()}
function SetManifest([string]$Rel='None.'){Put '_ORVION_CANONICAL/manifest.md' "Active Change Request: $Rel`nNext capability: fixture.`n---`n"}
$scope='allowed.txt;fixture-verify.ps1;_ORVION_CANONICAL/manifest.md'
$additional='pwsh -NoProfile -File fixture-verify.ps1'
$firstId='SPEC-900';$secondId='SPEC-'+(900+1)
$firstRel="changes/$firstId-fixture.md";$secondRel="changes/$secondId-fixture.md"
function SetContract([string]$Id,[string]$Rel,[string]$Status,[switch]$Closed){
    Put $Rel (ContractText -Id $Id -Status $Status -Resume DONE -Scope $scope -Additional $additional -Evidence (EvidenceText) -Closeable:$Closed)
}
function CompleteFixture([string]$Id,[string]$Rel){SetContract $Id $Rel Complete -Closed;SetManifest;$sha=Commit "complete $Id";$sha}
function Green([string]$Sha,[string]$Branch='main',[string]$Event='push',[string]$Conclusion='success'){
    SaveJson (Join-Path $rows "$Sha.json") @([ordered]@{headSha=$Sha;headBranch=$Branch;event=$Event;workflowName='Always';status='completed';conclusion=$Conclusion;attempt=1;databaseId=123})
}
function OwnerPush([string]$Sha,[string]$Branch){
    git -C $root -c core.hooksPath=$sandbox push --quiet $remote "${Sha}:refs/heads/$Branch"
    if($LASTEXITCODE){throw "bare owner transport failed:$Branch"}
}
# Load fixture text only, plus the implementation's canonical digest for controlled
# semantic mutations. All qualification/certification runs below are fresh processes.
function ImportFunctions([string]$Path,[string[]]$Names){
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw "parse failed:$Path"}
    foreach($fn in $ast.EndBlock.Statements|Where-Object{$_-is[Management.Automation.Language.FunctionDefinitionAst]-and$_.Name-in$Names}){
        . ([scriptblock]::Create($fn.Extent.Text.Replace("function $($fn.Name)","function global:$($fn.Name)")))
    }
}
ImportFunctions (Join-Path $PSScriptRoot 'test_agent_continuity.ps1') @('ContractText','EvidenceText')
ImportFunctions $control @('Receipt-Json','Receipt-Digest','Get-TextSha256','Receipt-Value','Read-ReceiptJson')
function Resign($Record){$Record.digest=Receipt-Digest $Record;$Record}
function Alter([scriptblock]$Change){
    $r=Json $script:record1;& $Change $r;$r.receipt=Resign $r.receipt;$r=Resign $r;SaveJson $script:record1 $r
}
function RestoreRecord{[IO.File]::WriteAllText($script:record1,$script:original1,[Text.UTF8Encoding]::new($false))}
function Refused([string]$Name,[string]$Code,$Result){Assert $Name ($Result.Code-ne0-and$Result.Text-match$Code-and$Result.Text-notmatch'REMOTE_CERTIFY: READY') $Result.Text}
function Mutant([string]$Name,[string]$Find,[string]$Replace,[scriptblock]$SetUp,[scriptblock]$Run,[string]$Code,[string]$WrongVerdict){
    $source=[IO.File]::ReadAllText($control)
    if($source.Contains("`r`n")){$Find=$Find-replace'(?<!\r)\n',"`r`n";$Replace=$Replace-replace'(?<!\r)\n',"`r`n"}
    if([regex]::Matches($source,[regex]::Escape($Find)).Count-ne1){throw "mutation anchor not unique:$Name"}
    $path=Join-Path $sandbox 'mutant.ps1';[IO.File]::WriteAllText($path,$source.Replace($Find,$Replace),[Text.UTF8Encoding]::new($false))
    & $SetUp;$pristine=& $Run $control
    & $SetUp;$mutated=& $Run $path
    & $SetUp;$restored=& $Run $control
    Assert "MUTATION ${Name}: refused, wrong verdict admitted, restored refusal" ($pristine.Code-ne0-and$pristine.Text-match$Code-and$mutated.Code-eq0-and$mutated.Text-match$WrongVerdict-and$restored.Code-ne0-and$restored.Text-match$Code) "pristine=$($pristine.Text) mutant=$($mutated.Text) restored=$($restored.Text)"
    RestoreRecord
}
try{
    foreach($d in @($sandbox,$bin,$rows,$hooks)){[void][IO.Directory]::CreateDirectory($d)}
    $codec=Join-Path $sandbox 'codec.json'
    $sample=[ordered]@{schema=2;at='2026-10-16T00:00:00Z';expected=@('Always'|Sort-Object);empty=@();nested=[ordered]@{b=2;a='text'}}
    $sample.digest=Receipt-Digest $sample;SaveJson $codec $sample;$decoded=Json $codec
    Assert 'codec preserves ISO strings, singleton arrays, empty arrays and original digest' ($decoded.at-is[string]-and$decoded.expected-is[array]-and$decoded.empty-is[array]-and$decoded.empty.Count-eq0-and$decoded.digest-ceq(Receipt-Digest $decoded)) (Receipt-Json $decoded)
    $reordered=[ordered]@{nested=[ordered]@{a='text';b=2};empty=@();expected=@('Always');at='2026-10-16T00:00:00Z';schema=2}
    Assert 'digest is independent of object key order and excludes its own field' ((Receipt-Digest $reordered)-ceq$sample.digest)
    $reordered.expected=@('Always','Other')
    Assert 'digest observes array content' ((Receipt-Digest $reordered)-cne$sample.digest)
    if($Case-eq'Codec'){Write-Host "CERTIFICATION RECEIPT CODEC: $($script:pass) passed, $($script:fail) failed";if($script:fail){exit 1};exit 0}
    $empty=Join-Path $sandbox 'empty-gitconfig';[IO.File]::WriteAllText($empty,'')
    $env:GIT_CONFIG_GLOBAL=$empty;$env:GIT_CONFIG_NOSYSTEM='1';$env:GIT_TERMINAL_PROMPT='0'
    foreach($name in @('GH_TOKEN','GITHUB_TOKEN','GH_ENTERPRISE_TOKEN','GITHUB_ENTERPRISE_TOKEN','GIT_ASKPASS','SSH_ASKPASS')){Remove-Item "Env:$name" -ErrorAction SilentlyContinue}
    $env:PATH="$bin$([IO.Path]::PathSeparator)$env:PATH";$env:ORVION_RECEIPT_ROWS=$rows
    $env:ORVION_RECEIPT_TRIPWIRE=Join-Path $sandbox 'tripwire.log'
    [IO.File]::WriteAllText((Join-Path $bin 'gh.ps1'),@'
if($args[0]-ne'run'-or$args[1]-ne'list'){Add-Content $env:ORVION_RECEIPT_TRIPWIRE 'gh authentication or unexpected command';exit 99}
$i=[array]::IndexOf($args,'--commit');if($i-lt0){'[]';exit 0}
$path=Join-Path $env:ORVION_RECEIPT_ROWS ($args[$i+1]+'.json')
if(Test-Path -LiteralPath $path){Get-Content -Raw -LiteralPath $path}else{'[]'}
exit 0
'@)
    git init --quiet --bare $remote;git init --quiet -b main $root
    git -C $root config user.name ORVION-Receipt-Test;git -C $root config user.email receipt-test@orvion.invalid
    git -C $root config core.autocrlf false;git -C $root config core.hooksPath $hooks;git -C $root config credential.helper ''
    Put '.gitignore' ".orvion-local-certification.json`n.orvion-certifications/`n"
    Put 'AGENTS.md' '# fixture'
    Put 'CR_LIFECYCLE.md' "# fixture`nSPEC Allocation Enforcement: 1`nHistorical CR Immutability Enforcement: 5d78aacd5335278c5b03edb0b3f969bd86e6b9c4`nEvidence Character Enforcement: ae1d130d82a1173099d858e667aab8dc88650d84`n"
    Put '.github/workflows/always.yml' "name: Always`non:`n  push:`n"
    Put 'scripts/check_agent_continuity.ps1' ([IO.File]::ReadAllText($control))
    Put 'scripts/publish_candidate.ps1' ([IO.File]::ReadAllText($publisher))
    Put 'scripts/check_repository_consistency.ps1' "Write-Output 'REPOSITORY CONSISTENCY: CLEAN';exit 0"
    # Only REPOSITORY applies here. Its consistency child is the above stub; its real
    # git diff check and this Additional command execute. No DB/tool/network child.
    Put 'fixture-verify.ps1' 'if($env:ORVION_RECEIPT_FAIL){exit 7};exit 0'
    Put 'allowed.txt' 'baseline';SetContract $firstId $firstRel Draft;SetManifest
    $script:base=Commit 'fixture baseline'
    git -C $root remote add origin $remote;OwnerPush $script:base main
    git -C $root fetch origin --quiet;git -C $root branch --set-upstream-to origin/main main --quiet
    git -C $root remote set-url --push origin none
    SetContract $firstId $firstRel Approved;SetManifest $firstRel;$null=Commit 'C1 approved'
    SetContract $firstId $firstRel 'In Progress';Put 'allowed.txt' 'one';$finish1=Commit 'C1 implementation'
    $f=RunEval Finish
    Assert 'C1 actual Finish mints schema 2 from executed fixture commands' ($f.Code-eq0-and$f.Text-match'LOCAL_CERTIFY: READY') $f.Text
    $working=Join-Path $root '.orvion-local-certification.json';$r=Json $working
    Assert 'Finish anchor is existing HEAD and all original fields survive' ($r.schema-eq2-and$r.finishHead-ceq$finish1-and$r.contract-ceq$firstRel-and$r.digest-ceq(Receipt-Digest $r)-and$r.expected-contains'Always'-and$r.result-ceq'READY') (ConvertTo-Json $r -Depth 12)
    $candidate1=CompleteFixture $firstId $firstRel
    $script:record1=Join-Path $root ".orvion-certifications/$candidate1.json"
    [IO.File]::WriteAllText((Join-Path $hooks 'pre-push'),"#!/bin/sh`necho unexpected-hook >> `"`$ORVION_RECEIPT_TRIPWIRE`"`nexit 99`n")
    if($IsLinux-or$IsMacOS){chmod +x (Join-Path $hooks 'pre-push')}
    Assert 'fixture gh tripwire shadows the real executable' ((Get-Command gh).Source-ceq(Join-Path $bin 'gh.ps1'))
    # Invalid switch contexts fail before Gate, and standalone preparation has no
    # usable fetch/push destination, no tokens and a gh authentication tripwire.
    Refused 'binding requires an explicit range' 'BIND_LOCAL_RANGE_REQUIRED' (RunEval Gate @('-BindCandidate'))
    Refused 'binding refuses Trusted' 'BIND_LOCAL_RANGE_REQUIRED' (RunEval Gate @('-Trusted','-BindCandidate','-BaseRef',$script:base,'-HeadRef',$candidate1))
    Refused 'binding requires a full captured SHA' 'BIND_FULL_SHA_REQUIRED' (RunEval Gate @('-BindCandidate','-BaseRef',$script:base,'-HeadRef','HEAD'))
    Refused 'binding refuses a SHA other than exact checkout' 'RECEIPT_SHA_MISMATCH' (Bind $script:base)
    git -C $root remote set-url origin none
    $b=Bind $candidate1
    Assert 'standalone actual range Gate prepares C1 without gh or transport' ($b.Code-eq0-and$b.Text-match"PREPARED: $candidate1"-and$b.Text-notmatch'PUBLISHED:'-and!(Test-Path $env:ORVION_RECEIPT_TRIPWIRE)-and(Ref main)-ceq$script:base) $b.Text
    git -C $root remote set-url origin $remote
    Remove-Item -LiteralPath (Join-Path $hooks 'pre-push')
    $script:original1=[IO.File]::ReadAllText($script:record1);$hash1=Hash $script:record1
    $b=Bind $candidate1
    Assert 'repeat preparation is byte-identical' ($b.Code-eq0-and(Hash $script:record1)-ceq$hash1) $b.Text
    Put 'allowed.txt' 'dirty';Refused 'dirty preparation refused' 'RECEIPT_DIRTY_TREE' (Bind $candidate1);git -C $root restore allowed.txt
    SetContract $secondId $secondRel Draft;$null=Commit 'C2 draft'
    SetContract $secondId $secondRel Approved;SetManifest $secondRel;$null=Commit 'C2 approved'
    SetContract $secondId $secondRel 'In Progress';Put 'allowed.txt' 'two';$null=Commit 'C2 implementation'
    Remove-Item -LiteralPath $script:record1
    $prior=[IO.File]::ReadAllText($working);$f=RunEval Finish
    Assert 'unbound pending C1 blocks C2 Finish before destroying working evidence' ($f.Code-ne0-and$f.Text-match'PENDING_RECEIPT_UNBOUND'-and[IO.File]::ReadAllText($working)-ceq$prior) $f.Text
    Remove-Item -LiteralPath $working
    Refused 'missing working receipt cannot hide unbound C1' 'PENDING_RECEIPT_UNBOUND' (RunEval Finish)
    [IO.File]::WriteAllText($working,$prior);RestoreRecord
    if($Case-ne'Sequence'){
        Mutant overwrite '    Protect-PendingCertifications $c $rel' '    # pending protection removed by test mutant' {
            Remove-Item -LiteralPath $script:record1 -ErrorAction SilentlyContinue
            [IO.File]::WriteAllText($working,$prior)
        } {param($e)RunEval Finish @() $e} 'PENDING_RECEIPT_UNBOUND' 'LOCAL_CERTIFY: READY'
        [IO.File]::WriteAllText($working,$prior)
    }
    $f=RunEval Finish
    Assert 'C2 Finish succeeds while C1 remains unpublished and preserves C1 record' ($f.Code-eq0-and$f.Text-match'LOCAL_CERTIFY: READY'-and(Hash $script:record1)-ceq$hash1-and(Ref main)-ceq$script:base-and!(Ref orvion-preflight)) $f.Text
    $env:ORVION_RECEIPT_FAIL='1';$f=RunEval Finish;Remove-Item Env:ORVION_RECEIPT_FAIL
    Assert 'failed same-CR Finish removes its receipt and retains C1' ($f.Code-ne0-and$f.Text-match'ADDITIONAL_VERIFICATION_FAILED'-and!(Test-Path $working)-and(Hash $script:record1)-ceq$hash1) $f.Text
    $f=RunEval Finish;Assert 'C2 retry earns a new working receipt' ($f.Code-eq0-and$f.Text-match'LOCAL_CERTIFY: READY') $f.Text
    $candidate2=CompleteFixture $secondId $secondRel
    $b=Bind $candidate2;Assert 'C2 prepares locally before either candidate is published' ($b.Code-eq0-and$b.Text-match"PREPARED: $candidate2"-and!(Ref orvion-preflight)-and(Ref main)-ceq$script:base) $b.Text
    $record2=Join-Path $root ".orvion-certifications/$candidate2.json";$hash2=Hash $record2
    git -C $root branch pending-tail $candidate2
    git -C $root branch --set-upstream-to origin/main pending-tail --quiet
    # Existing publisher, actual subprocess, failed Git push. Its Gate must reuse C2.
    $o=& pwsh -NoProfile -File (Join-Path $root 'scripts/publish_candidate.ps1') -Root $root 2>&1
    $pubCode=$LASTEXITCODE;$pubText=$o|Out-String
    Assert 'failed owner transport keeps both records and does not publish' ($pubCode-ne0-and$pubText-match'PUSH_REFUSED'-and(Hash $script:record1)-ceq$hash1-and(Hash $record2)-ceq$hash2-and!(Ref orvion-preflight)) $pubText
    $b=Bind $candidate2;Assert 'restart after failed push reuses C2 original record' ($b.Code-eq0-and(Hash $record2)-ceq$hash2) $b.Text
    # A new clone receives Git history, never ignored evidence.
    $clone=Join-Path $sandbox 'clone'
    git clone --quiet --no-hardlinks --config core.autocrlf=false $root $clone
    $missing=RunEval Certify @() $control $clone
    Refused 'another checkout without records refuses certification' 'RECEIPT_MISSING' $missing
    git -C $root checkout --quiet --detach $candidate1
    Assert 'C1 checkout is clean and preserves both ignored records' (!@(git -C $root status --porcelain).Count-and(Hash $script:record1)-ceq$hash1-and(Hash $record2)-ceq$hash2)
    # Atomic failure: a conflicting destination is retained, then a leftover temp
    # file cannot impersonate a record and does not prevent a legitimate retry.
    [IO.File]::WriteAllText($script:record1,'{"conflict":true}')
    $b=Bind $candidate1;Assert 'conflicting archive is refused and never overwritten' ($b.Code-ne0-and[IO.File]::ReadAllText($script:record1)-ceq'{"conflict":true}') $b.Text
    RestoreRecord
    # Use the existing publisher for both successful local preflight pushes.
    git -C $root remote set-url --push origin $remote
    $o=& pwsh -NoProfile -File (Join-Path $root 'scripts/publish_candidate.ps1') -Root $root 2>&1;$code=$LASTEXITCODE
    Assert 'existing publisher binds/reuses and pushes exact C1 only to preflight' ($code-eq0-and(Ref orvion-preflight)-ceq$candidate1) ($o|Out-String)
    git -C $root checkout --quiet pending-tail
    $o=& pwsh -NoProfile -File (Join-Path $root 'scripts/publish_candidate.ps1') -Root $root 2>&1;$code=$LASTEXITCODE
    Assert 'preflight advances to C2 while main does not move in publisher' ($code-eq0-and(Ref orvion-preflight)-ceq$candidate2-and(Ref main)-cne$candidate2) ($o|Out-String)
    git -C $root checkout --quiet --detach $candidate1
    OwnerPush $candidate1 main;Green $candidate1
    if($Case-eq'All'){
        foreach($bad in @(
            @{Name='CR identity';Code='certification receipt names';Change={param($r)$r.receipt.cr=$secondId}},
            @{Name='contract path';Code='RECEIPT_IDENTITY_MISMATCH|RECEIPT_NOT_COMPLETION_SHA';Change={param($r)$r.receipt.contract=$secondRel}},
            @{Name='profiles';Code='certification profiles';Change={param($r)$r.receipt.profiles=@('CONTROL','REPOSITORY')}},
            @{Name='fingerprint';Code='stale certification receipt';Change={param($r)$r.receipt.fingerprint='0'*64}},
            @{Name='result';Code='certification result';Change={param($r)$r.receipt.result='FAILED'}},
            @{Name='legacy schema';Code='RECEIPT_SCHEMA_UNSUPPORTED';Change={param($r)$r.receipt.schema=1}},
            @{Name='missing expectations';Code='RECEIPT_CONTEXT_MISSING';Change={param($r)$r.receipt.expected=@()}},
            @{Name='missing target';Code='RECEIPT_CONTEXT_MISSING';Change={param($r)$r.receipt.target=''}},
            @{Name='wrong ancestry';Code='RECEIPT_BASE_NOT_ANCESTOR';Change={param($r)$r.receipt.finishHead=$candidate2}},
            @{Name='invalid anchor';Code='RECEIPT_BASE_INVALID';Change={param($r)$r.receipt.finishHead='HEAD'}}
        )){
            RestoreRecord;Alter $bad.Change;Refused "semantic $($bad.Name) refused despite recomputed checksums" $bad.Code (RunEval Certify)
        }
        RestoreRecord;$r=Json $script:record1;$r.receipt.expected=@('Changed');$r=Resign $r;SaveJson $script:record1 $r
        Refused 'inner checksum observes altered original claims' 'RECEIPT_ALTERED' (RunEval Certify)
        RestoreRecord
        $laterWorking=[IO.File]::ReadAllText($working)
        SaveJson $working ((Json $script:record1).receipt);Remove-Item -LiteralPath $script:record1
        # Inject failure at the actual atomic installation, not into a fake binder.
        $fault=Join-Path $sandbox 'atomic-fault.ps1'
        $src=[IO.File]::ReadAllText($control);$needle='[IO.File]::Move($temp,$path,$false)'
        if([regex]::Matches($src,[regex]::Escape($needle)).Count-ne1){throw 'atomic fault anchor missing'}
        [IO.File]::WriteAllText($fault,$src.Replace($needle,"throw 'ATOMIC_TEST_INTERRUPT'"),[Text.UTF8Encoding]::new($false))
        $b=Bind $candidate1 $fault
        Assert 'interrupted atomic installation leaves no selectable record or temp file' ($b.Code-ne0-and$b.Text-match'ATOMIC_TEST_INTERRUPT'-and!(Test-Path $script:record1)-and!@(Get-ChildItem (Split-Path $script:record1 -Parent) -Filter '*.tmp').Count) $b.Text
        [IO.File]::WriteAllText("$($script:record1).interrupted.tmp",'unselectable interrupted data')
        $b=Bind $candidate1
        Assert 'restart ignores interrupted temp data and binds only original evidence' ($b.Code-eq0-and(Hash $script:record1)-ceq$hash1) $b.Text
        Remove-Item -LiteralPath "$($script:record1).interrupted.tmp"
        [IO.File]::WriteAllText($working,$laterWorking)
    }
    if($Case-ne'Sequence'){
        $run={param($e)RunEval Certify @() $e}
        Mutant SHA 'if($record.schema-ne2-or$record.candidate-cne$Sha)' 'if($record.schema-ne2)' {RestoreRecord;Alter {param($r)$r.candidate=$candidate2}} $run 'RECEIPT_SHA_MISMATCH' 'REMOTE_CERTIFY: READY'
        Mutant CR 'if($receipt.cr-cne$Contract.Id)' 'if($false)' {RestoreRecord;Alter {param($r)$r.receipt.cr=$secondId}} $run 'certification receipt names' 'REMOTE_CERTIFY: READY'
        Mutant profiles 'if($certified-cne$derived)' 'if($false)' {RestoreRecord;Alter {param($r)$r.receipt.profiles=@('CONTROL','REPOSITORY')}} $run 'certification profiles' 'REMOTE_CERTIFY: READY'
        Mutant fingerprint 'if(!$Historical-and$receipt.fingerprint-ne(Implementation-Fingerprint $Contract $Rel))' 'if($false)' {RestoreRecord;Alter {param($r)$r.receipt.fingerprint='0'*64}} $run 'stale certification receipt' 'REMOTE_CERTIFY: READY'
        Mutant checksum '    Assert-ReceiptDigest $record' '    $null=$record.digest' {RestoreRecord;$r=Json $script:record1;$r.digest='0'*64;SaveJson $script:record1 $r} $run 'RECEIPT_ALTERED' 'REMOTE_CERTIFY: READY'
        # The missing exact record must refuse even when its own original working
        # receipt is still available. A mutant opens precisely that forbidden door.
        $laterWorking=[IO.File]::ReadAllText($working)
        Mutant selection @'
$record=Read-ReceiptJson (Candidate-ReceiptPath $Sha)
        return (Read-CandidateReceipt $Sha $record.receipt.contract).receipt
'@ @'
if(!(Test-Path -LiteralPath (Candidate-ReceiptPath $Sha))){return (Read-ReceiptJson (Receipt-Path))}
        $record=Read-ReceiptJson (Candidate-ReceiptPath $Sha)
        return (Read-CandidateReceipt $Sha $record.receipt.contract).receipt
'@ {RestoreRecord;SaveJson $working ((Json $script:record1).receipt);Remove-Item -LiteralPath $script:record1} $run 'RECEIPT_MISSING' 'REMOTE_CERTIFY: READY'
        [IO.File]::WriteAllText($working,$laterWorking)
        if($Case-eq'Mutations'){
            $script:completed=$true
            Write-Host "CERTIFICATION RECEIPT MUTATIONS: $($script:pass) passed, $($script:fail) failed"
            if($script:fail){exit 1};exit 0
        }
    }
    $r=RunEval Certify
    Assert 'fresh process independently certifies promoted C1 using its original record' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY'-and$r.Text-match"SHA: $candidate1") $r.Text
    foreach($bad in @(@('orvion-preflight','push','success'),@('main','schedule','success'),@('main','push','skipped'),@('main','push','neutral'),@('main','push','failure'))){
        Green $candidate1 $bad[0] $bad[1] $bad[2];$r=RunEval Certify
        Assert "reader refuses $($bad-join'/')" ($r.Code-ne0-and$r.Text-notmatch'REMOTE_CERTIFY: READY') $r.Text
    }
    Green $candidate1
    git -C $root checkout --quiet pending-tail
    Assert 'named tail restores exact C2, clean tree and original hashes' ((git -C $root rev-parse HEAD)-ceq$candidate2-and!@(git -C $root status --porcelain).Count-and(Hash $script:record1)-ceq$hash1-and(Hash $record2)-ceq$hash2)
    $r=RunEval Certify;Assert 'C1 success cannot certify C2' ($r.Code-ne0-and$r.Text-notmatch'REMOTE_CERTIFY: READY') $r.Text
    # A stale literal lease cannot promote C2 after main has advanced to C1.
    git -C $root -c core.hooksPath=$sandbox push --quiet "--force-with-lease=refs/heads/main:$($script:base)" $remote "${candidate2}:refs/heads/main" 2>$null
    Assert 'stale promotion expectation refuses moved main' ($LASTEXITCODE-ne0-and(Ref main)-ceq$candidate1)
    OwnerPush $candidate2 main;Green $candidate2;$r=RunEval Certify
    Assert 'fresh process independently certifies promoted C2' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY') $r.Text
    git -C $root checkout --quiet --detach $candidate1;$r=RunEval Certify
    Refused 'green historical C1 fails after main moves to C2' 'TARGET_REF_MOVED' $r
    git -C $root checkout --quiet pending-tail
    Assert 'ordered certification and restoration leave both records byte-identical' ((Hash $script:record1)-ceq$hash1-and(Hash $record2)-ceq$hash2-and!@(git -C $root status --porcelain).Count)
    if($Case-eq'All'){
        $thirdId='SPEC-'+(900+2);$thirdRel="changes/$thirdId-fixture.md"
        SetContract $thirdId $thirdRel Draft;$null=Commit 'C3 draft'
        SetContract $thirdId $thirdRel Approved;SetManifest $thirdRel;$null=Commit 'C3 approved'
        SetContract $thirdId $thirdRel 'In Progress';$thirdHead=Commit 'C3 implementation'
        [IO.File]::WriteAllText($working,'unreadable legacy data');$f=RunEval Finish
        Assert 'unreadable prior evidence blocks without deletion' ($f.Code-ne0-and$f.Text-match'RECEIPT_UNREADABLE'-and[IO.File]::ReadAllText($working)-ceq'unreadable legacy data') $f.Text
        SaveJson $working @{cr=$secondId;target='never-published';result='READY'}
        Refused 'legacy evidence without recorded-target completion proof blocks' 'PENDING_RECEIPT_UNBOUND' (RunEval Finish)
        SaveJson $working @{cr=$secondId;target='main';result='READY'}
        $f=RunEval Finish;$new=Json $working
        Assert 'Git-proven promoted legacy evidence retires without upgrading its claim' ($f.Code-eq0-and$new.schema-eq2-and$new.cr-ceq$thirdId-and$new.finishHead-ceq$thirdHead-and(Hash $script:record1)-ceq$hash1-and(Hash $record2)-ceq$hash2) $f.Text
        OwnerPush $thirdHead main;Green $thirdHead;$r=RunEval Certify
        Assert 'nonterminal active CR certifies only its clean exact Finish HEAD' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY') $r.Text
        Put 'allowed.txt' 'dirty';Refused 'nonterminal dirty content refused' 'RECEIPT_DIRTY_TREE' (RunEval Certify);git -C $root restore allowed.txt
        $text=[IO.File]::ReadAllText((Join-Path $root $thirdRel));Put $thirdRel ($text.Replace('## Execution Log',"## Execution Log`n`nA later bookkeeping boundary."));$later=Commit 'C3 later bookkeeping'
        OwnerPush $later main;Green $later;Refused 'nonterminal later SHA cannot borrow earlier Finish evidence' 'RECEIPT_SHA_MISMATCH' (RunEval Certify)
    }
    $script:completed=$true
}finally{
    # Keep failed fixtures inspectable; successful fixtures have an explicitly bounded target.
    if(($script:completed-or$Case-eq'Codec')-and$script:fail-eq0-and(Test-Path -LiteralPath $sandbox)){
        $resolved=[IO.Path]::GetFullPath($sandbox);$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if(!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)-or(Split-Path $resolved -Leaf)-notlike'orvion-receipts-*'){throw 'cleanup escaped fixture root'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }else{Write-Host "FIXTURE: $sandbox"}
}
Write-Host "CERTIFICATION RECEIPT TESTS: $($script:pass) passed, $($script:fail) failed (profile children stubbed; gh synthetic; bare Git only)"
if($script:fail){exit 1};exit 0
