# Deterministic adversarial tests for scripts/check_agent_continuity.ps1.
$ErrorActionPreference='Stop'
$sourceRoot=Split-Path $PSScriptRoot -Parent
$control=Join-Path $sourceRoot 'scripts/check_agent_continuity.ps1'
$sandbox=Join-Path ([IO.Path]::GetTempPath())("orvion-agent-control-test-$([guid]::NewGuid().ToString('N'))")
$remote=Join-Path $sandbox 'remote.git';$root=Join-Path $sandbox 'work'
$script:pass=0;$script:fail=0
function Assert($Name,[bool]$Condition,[string]$Evidence){if($Condition){$script:pass++;Write-Host "PASS $Name"}else{$script:fail++;Write-Host "FAIL $Name :: $Evidence"}}
function ContractText([string]$Status='In Progress',[string]$Resume='1',[string]$Blocker='None',[string]$Attempt='0',[string]$Scope='allowed.txt',[string]$Reading='context.txt',[string]$Capabilities='None',[string]$Additional='None'){
@"
# Change Request — SPEC-999
## Status
[ ] Draft
[ ] Approved
[$(if($Status-eq'In Progress'){'x'}else{' '})] In Progress
[$(if($Status-eq'Draft'){'x'}else{' '})] Draft
[$(if($Status-eq'Approved'){'x'}else{' '})] Approved
[$(if($Status-eq'Complete'){'x'}else{' '})] Complete
[ ] Cancelled
## Objective
Fixture.
## Write Scope
$(if($Scope-eq'None'){'None'}else{"- ``$Scope``"})
## Required Reading
$(if($Reading-eq'None'){'None'}else{"- ``$Reading``"})
## Runtime Checkpoint
Resume Step: $Resume
Blocker: $Blocker
Recovery Attempt: $Attempt
## Required Capabilities
$(if($Capabilities-eq'None'){'None'}else{"- ``$Capabilities``"})
## Additional Verification
$(if($Additional-eq'None'){'None'}else{"- $Additional"})
## Implementation Steps
1. Exact fixture action.
2. Exact second action.
## Acceptance Criteria
- [ ] Fixture.
## Execution Log
None.
## Verification Notes
None.
## Review Gate
- [ ] Fixture.
"@
}
function Put([string]$Rel,[string]$Text){$p=Join-Path $root $Rel;$d=Split-Path $p -Parent;if(!(Test-Path $d)){[IO.Directory]::CreateDirectory($d)|Out-Null};[IO.File]::WriteAllText($p,$Text,(New-Object Text.UTF8Encoding($false)))}
function Reset-Fixture{git -C $root reset --hard origin/main --quiet;git -C $root clean -fdq;Put 'changes/SPEC-999-fixture.md' (ContractText)}
function Run([string]$Mode='Boot',[string[]]$Caps=@(),[switch]$Guard){$args=@("-$Mode",'-Root',$root);if(!$Guard){$args+='-SkipRepositoryGuard'};if($Caps.Count){$args+='-Capabilities';$args+=$Caps};$o=& pwsh -NoProfile -File $control @args 2>&1;$code=$LASTEXITCODE;[pscustomobject]@{Text=($o|Out-String);Code=$code;Lines=@($o).Count}}
function RunRange([string]$Base){$o=& pwsh -NoProfile -File $control -Gate -Root $root -BaseRef $Base -HeadRef HEAD -SkipRepositoryGuard 2>&1;$code=$LASTEXITCODE;[pscustomobject]@{Text=($o|Out-String);Code=$code}}
try{
    [IO.Directory]::CreateDirectory($sandbox)|Out-Null;git init --bare $remote --quiet;git clone $remote $root --quiet;git -C $root config user.email test@orvion.invalid;git -C $root config user.name ORVION-Test
    Put 'AGENTS.md' '# fixture';Put 'context.txt' 'readable';Put 'allowed.txt' 'baseline';Put '_ORVION_CANONICAL/manifest.md' "Active Change Request: changes/SPEC-999-fixture.md`nNext capability: Batch 6 Slice 12 on quotations.`n---`n";Put 'changes/SPEC-999-fixture.md' (ContractText);Put 'changes/SPEC-100-complete.md' (ContractText -Status Complete -Resume DONE)
    Put 'scripts/check_repository_consistency.ps1' "Write-Output 'REPOSITORY CONSISTENCY: CLEAN'; exit 0"
    git -C $root add .;git -C $root commit -m baseline --quiet;git -C $root branch -M main;git -C $root push -u origin main --quiet

    $r=Run;Assert '01 valid active CR -> EXECUTE' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE'-and$r.Text-match'Exact fixture action') $r.Text
    Reset-Fixture;Put '_ORVION_CANONICAL/manifest.md' "Active Change Request: None.`nNext capability: Batch 6 Slice 12 on quotations.`n---`n";$r=Run;Assert '02 no active CR -> PLAN/no write' ($r.Code-eq0-and$r.Text-match'MODE: PLAN'-and$r.Text-match'WRITE_AUTHORITY: none') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' '# malformed';$r=Run;Assert '03 malformed CR blocked' ($r.Code-ne0-and$r.Text-match'CONTRACT_SECTION_Status') $r.Text
    Reset-Fixture;$t=ContractText;$t=$t-replace '\[x\] In Progress','[ ] In Progress';$t=$t-replace '\[ \] Cancelled','[x] Rejected';Put 'changes/SPEC-999-fixture.md' $t;$r=Run;Assert '04 invalid official status blocked' ($r.Code-ne0-and$r.Text-match'INVALID_CR_STATUS') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' ((ContractText)+"`n## Required Reading`n- duplicate.md`n");$r=Run;Assert '05 duplicate required section blocked' ($r.Code-ne0-and$r.Text-match'CONTRACT_SECTION_Required Reading') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' (ContractText -Resume 0);$r=Run;Assert '06 nonexistent Resume Step blocked' ($r.Code-ne0-and$r.Text-match'INVALID_RUNTIME_CHECKPOINT') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' (ContractText -Resume 3);$r=Run;Assert '07 Resume Step past steps blocked' ($r.Code-ne0-and$r.Text-match'INVALID_RESUME_STEP') $r.Text
    Reset-Fixture;Put 'allowed.txt' 'changed';$r=Run 'Gate';Assert '08 allowed write passes' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Reset-Fixture;Put 'outside.txt' 'bad';$r=Run 'Gate';Assert '09 out-of-scope write blocked' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:outside.txt') $r.Text
    Reset-Fixture;$null=Get-Content (Join-Path $root 'context.txt');$r=Run;Assert '10 arbitrary read allowed' ($r.Code-eq0) $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' (ContractText -Reading outside.txt);Put 'outside.txt' 'bad';$r=Run 'Gate';Assert '11 Required Reading grants no write' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:outside.txt') $r.Text
    Reset-Fixture;Put 'AGENTS.md' '# changed protected';$r=Run 'Gate';Assert '12 protected unauthorized write blocked' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:AGENTS.md') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' (ContractText -Capabilities n8n);$r=Run;Assert '13 missing capability blocked' ($r.Code-ne0-and$r.Text-match'MISSING_REQUIRED_CAPABILITY:n8n') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' (ContractText -Scope scripts/check_agent_continuity.ps1);$r=Run;Assert '14 mandatory profile cannot downgrade' ($r.Code-eq0-and$r.Text-match'VERIFICATION: CONTROL, REPOSITORY') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' (ContractText -Additional 'EXTRA-CHECK');$r=Run;Assert '15 additional verification adds' ($r.Code-eq0-and$r.Text-match'REPOSITORY, EXTRA-CHECK') $r.Text
    Reset-Fixture;Put 'AGENTS.md' ('x'*16385);$r=Run;Assert '16 AGENTS ceiling enforced' ($r.Code-ne0-and$r.Text-match'AGENTS_SIZE_EXCEEDED:16385') $r.Text
    Reset-Fixture;Put '_ORVION_CANONICAL/manifest.md' "Active Change Request: changes/SPEC-404-missing.md`nNext capability: X`n---`n";$r=Run;Assert '17 stale active pointer blocked' ($r.Code-ne0-and$r.Text-match'STALE_ACTIVE_CR') $r.Text
    Reset-Fixture;Put 'scripts/check_repository_consistency.ps1' "Write-Output 'REPOSITORY CONSISTENCY: 1 issue'; exit 1";$r=Run -Guard;Assert '18 repository failure surfaces' ($r.Code-ne0-and$r.Text-match'REPOSITORY_CONSISTENCY_FAILED'-and$r.Text-match'\.log') $r.Text
    Reset-Fixture;$r=Run;Assert '19 success output compact' ($r.Code-eq0-and$r.Lines-lt20) "lines=$($r.Lines)"
    Reset-Fixture;Put 'outside.txt' 'bad';$r=Run 'Gate';Assert '20 failure identifies exact evidence' ($r.Text-match'CODE: OUT_OF_SCOPE_WRITE'-and$r.Text-match'SUBJECT: outside.txt') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' (ContractText -Attempt 4);$r=Run;Assert '21 recovery attempt max 3' ($r.Code-ne0-and$r.Text-match'INVALID_RUNTIME_CHECKPOINT') $r.Text
    Assert '22 equivalent recovery repetition prevented' ((Get-Content -Raw (Join-Path $sourceRoot 'AGENTS.md'))-match'Never repeat the same repair with the same evidence') 'kernel rule missing'
    $kernel=Get-Content -Raw (Join-Path $sourceRoot 'AGENTS.md');Assert '23 derivable decision not escalated' ($kernel-match'If one answer follows from approved architecture, decide and continue') 'decision exhaustion missing'
    Assert '24 genuine owner policy remains owner-only' ($kernel-match'Escalate only business preference, commercial policy, legal/compliance acceptance') 'owner boundary missing'
    Reset-Fixture;$r1=Run;$r2=Run;Assert '25 checkpoint survives cold start' ($r1.Text-match'STEP: 1/2'-and$r2.Text-match'STEP: 1/2'-and$r2.Text-match'Exact fixture action') $r2.Text
    Reset-Fixture;$before=(Get-FileHash (Join-Path $root 'changes/SPEC-100-complete.md')).Hash;$null=Run;$after=(Get-FileHash (Join-Path $root 'changes/SPEC-100-complete.md')).Hash;Assert '26 completed CR history unchanged' ($before-eq$after) "$before / $after"
    Reset-Fixture;Put 'scripts/check_agent_continuity.ps1' (Get-Content -Raw $control);Put '.githooks/pre-commit' (Get-Content -Raw (Join-Path $sourceRoot '.githooks/pre-commit'));git -C $root config core.hooksPath .githooks;Put 'outside.txt' 'injected';git -C $root add outside.txt;$beforeHead=git -C $root rev-parse HEAD;$hookOut=(git -C $root commit -m injected 2>&1|Out-String);$hookCode=$LASTEXITCODE;$afterHead=git -C $root rev-parse HEAD;Assert '27 pre-commit adapter rejects injected out-of-scope write' ($hookCode-ne0-and$beforeHead-eq$afterHead-and$hookOut-match'OUT_OF_SCOPE_WRITE') $hookOut
    Reset-Fixture;git -C $root config --unset core.hooksPath 2>$null;Put 'allowed.txt' 'range change';git -C $root add allowed.txt;git -C $root commit -m active-range --quiet;$r=RunRange 'HEAD~1';Assert '28 CI active CR range resolves' ($r.Code-eq0-and$r.Text-match'CR: SPEC-999') $r.Text
    Reset-Fixture;$complete=ContractText -Status Complete -Resume DONE;$complete=$complete-replace'`allowed\.txt`','`_ORVION_CANONICAL/manifest.md`';Put 'changes/SPEC-999-fixture.md' $complete;Put '_ORVION_CANONICAL/manifest.md' "Active Change Request: None.`nNext capability: Batch 6 Slice 12 on quotations.`n---`n";git -C $root add .;git -C $root commit -m completion-range --quiet;$r=RunRange 'HEAD~1';Assert '29 CI completion range resolves' ($r.Code-eq0-and$r.Text-match'MODE: VERIFY') $r.Text
    Reset-Fixture;Put 'changes/SPEC-999-fixture.md' (ContractText -Status Complete -Resume DONE);Put 'changes/SPEC-998-other.md' ((ContractText -Status Complete -Resume DONE)-replace'SPEC-999','SPEC-998');Put '_ORVION_CANONICAL/manifest.md' "Active Change Request: None.`nNext capability: X`n---`n";git -C $root add .;git -C $root commit -m ambiguous-range --quiet;$r=RunRange 'HEAD~1';Assert '30 CI ambiguous CR fails closed' ($r.Code-ne0-and$r.Text-match'AMBIGUOUS_GOVERNING_CR') $r.Text
    Reset-Fixture;Put '_ORVION_CANONICAL/manifest.md' "Active Change Request: None.`nNext capability: X`n---`n";Put 'allowed.txt' 'ungoverned';git -C $root add .;git -C $root commit -m no-governor --quiet;$r=RunRange 'HEAD~1';Assert '31 CI no governing CR fails closed' ($r.Code-ne0-and$r.Text-match'NO_GOVERNING_CR') $r.Text
}finally{if(Test-Path $sandbox){Remove-Item -LiteralPath $sandbox -Recurse -Force}}
Write-Host "AGENT CONTROL TESTS: $($script:pass) passed, $($script:fail) failed"
if($script:fail){exit 1};exit 0
