# Deterministic behavioral attacks for scripts/check_agent_continuity.ps1.
$ErrorActionPreference='Stop'
$sourceRoot=Split-Path $PSScriptRoot -Parent
$control=Join-Path $sourceRoot 'scripts/check_agent_continuity.ps1'
$sandbox=Join-Path ([IO.Path]::GetTempPath())("orvion-agent-control-test-$([guid]::NewGuid().ToString('N'))")
$remote=Join-Path $sandbox 'remote.git';$root=Join-Path $sandbox 'work';$writer=Join-Path $sandbox 'writer'
$script:pass=0;$script:fail=0
function Assert($Name,[bool]$Condition,[string]$Evidence=''){if($Condition){$script:pass++;Write-Host "PASS $Name"}else{$script:fail++;Write-Host "FAIL $Name :: $Evidence"}}
function ContractText(
    [string]$Id='SPEC-900',[string]$Status='In Progress',[string]$Resume='1',[string]$Blocker='None',
    [string]$Attempt='0',[string]$Scope='allowed.txt',[string]$Reading='context.txt',
    [string]$Capabilities='None',[string]$Additional='None',[switch]$Multiline
){
    $steps=if($Multiline){"1. first line`n   continuation line`n2. Exact second action."}else{"1. Exact fixture action.`n2. Exact second action."}
@"
# Change Request — $Id
## Status
[$(if($Status-eq'Draft'){'x'}else{' '})] Draft
[$(if($Status-eq'Approved'){'x'}else{' '})] Approved
[$(if($Status-eq'In Progress'){'x'}else{' '})] In Progress
[$(if($Status-eq'Complete'){'x'}else{' '})] Complete
[$(if($Status-eq'Cancelled'){'x'}else{' '})] Cancelled
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
$steps
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
function ManifestText([string]$Active='changes/SPEC-900-fixture.md'){"Active Change Request: $Active`nNext capability: Batch 6 Slice 12 on quotations.`n---`n"}
function Reset-Fixture{git -C $root checkout main --quiet 2>$null;git -C $root branch --set-upstream-to origin/main main --quiet 2>$null;git -C $root reset --hard origin/main --quiet;git -C $root clean -fdq}
function Run([string]$Mode='Boot'){
    $o=& pwsh -NoProfile -File $control "-$Mode" -Root $root 2>&1;$code=$LASTEXITCODE
    [pscustomobject]@{Text=($o|Out-String);Code=$code;Lines=@($o).Count}
}
function RunRange([string]$Base,[string]$Head='HEAD'){
    $o=& pwsh -NoProfile -File $control -Gate -Root $root -BaseRef $Base -HeadRef $Head 2>&1;$code=$LASTEXITCODE
    [pscustomobject]@{Text=($o|Out-String);Code=$code}
}
function Commit([string]$Message){git -C $root add .;git -C $root commit -m $Message --quiet}
try{
    [IO.Directory]::CreateDirectory($sandbox)|Out-Null
    git init --bare $remote --quiet;git clone $remote $root --quiet
    git -C $root config user.email test@orvion.invalid;git -C $root config user.name ORVION-Test
    Put 'AGENTS.md' '# fixture'
    Put 'context.txt' 'readable';Put 'allowed.txt' 'baseline';Put 'product-history.txt' 'SPEC-155 commission lineage'
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    Put 'changes/SPEC-900-fixture.md' (ContractText)
    Put 'changes/SPEC-800-complete.md' (ContractText -Id SPEC-800 -Status Complete -Resume DONE)
    Put 'changes/SPEC-801-cancelled.md' (ContractText -Id SPEC-801 -Status Cancelled -Resume DONE)
    Put 'scripts/check_agent_continuity.ps1' (Get-Content -Raw $control)
    Put 'scripts/check_repository_consistency.ps1' "Write-Output 'REPOSITORY CONSISTENCY: CLEAN'; if(Test-Path env:ORVION_GUARD_MARKER){Set-Content -LiteralPath `$env:ORVION_GUARD_MARKER -Value ran}; exit 0"
    foreach($s in @('test_agent_continuity.ps1','test_cold_start_state_guard.ps1','test_status_contradiction_guard.ps1','test_primary_ledger_guard.ps1','test_future_date_guard.ps1')){Put "scripts/$s" "exit 0"}
    git -C $root add .;git -C $root commit -m baseline --quiet;git -C $root branch -M main;git -C $root push -u origin main --quiet

    $r=Run;Assert '01 valid active CR routes to EXECUTE' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE'-and$r.Text-match'Exact fixture action') $r.Text

    Reset-Fixture;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit plan-base;git -C $root push origin main --quiet;$marker=Join-Path $sandbox 'guard.marker';$env:ORVION_GUARD_MARKER=$marker;$r=Run;Remove-Item Env:ORVION_GUARD_MARKER;Put '_ORVION_CANONICAL/manifest.md' (ManifestText);Commit restore-active;git -C $root push origin main --quiet
    Assert '02 PLAN follows successful Repository Consistency and fresh Git checks' ($r.Code-eq0-and$r.Text-match'MODE: PLAN'-and(Test-Path $marker)-and$r.Text-match'GIT: clean \| ahead 0 / behind 0') $r.Text

    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' '# malformed';$r=Run;Assert '03 malformed CR blocks' ($r.Code-ne0-and$r.Text-match'INVALID_CR_HEADING') $r.Text
    Reset-Fixture;$t=ContractText;$t=$t-replace '\[x\] In Progress','[ ] In Progress';$t=$t-replace '\[ \] Cancelled','[x] Rejected';Put 'changes/SPEC-900-fixture.md' $t;$r=Run;Assert '04 invalid official status blocks' ($r.Code-ne0-and$r.Text-match'INVALID_CR_STATUS') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' ((ContractText)+"`n## Required Reading`n- duplicate.md`n");$r=Run;Assert '05 duplicate required contract section blocks' ($r.Code-ne0-and$r.Text-match'CONTRACT_SECTION_Required Reading') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume 0);$r=Run;Assert '06 invalid Runtime Checkpoint blocks' ($r.Code-ne0-and$r.Text-match'INVALID_RUNTIME_CHECKPOINT') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume 3);$r=Run;Assert '07 Resume Step beyond step count blocks' ($r.Code-ne0-and$r.Text-match'INVALID_RESUME_STEP') $r.Text
    Reset-Fixture;Put 'allowed.txt' changed;$r=Run Gate;Assert '08 allowed in-scope write passes' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Reset-Fixture;Put 'outside.txt' bad;$r=Run Gate;Assert '09 out-of-scope write blocks' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:outside.txt') $r.Text
    Reset-Fixture;$null=Get-Content(Join-Path $root context.txt);$r=Run;Assert '10 unrestricted read remains legal' ($r.Code-eq0) $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Reading outside.txt);Put outside.txt bad;$r=Run Gate;Assert '11 Required Reading does not grant write' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:outside.txt') $r.Text
    Reset-Fixture;Put AGENTS.md changed;$r=Run Gate;Assert '12 protected unauthorized write blocks' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:AGENTS.md') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Capabilities n8n);$r=Run;Assert '13 unknown required capability fails closed' ($r.Code-ne0-and$r.Text-match'NO_DETERMINISTIC_CAPABILITY_PROBE:n8n') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Scope scripts/check_agent_continuity.ps1);$r=Run;Assert '14 mandatory profile cannot be subtracted' ($r.Code-eq0-and$r.Text-match'VERIFICATION: CONTROL, REPOSITORY') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Additional 'pwsh -NoProfile -Command "exit 0"');$r=Run;Assert '15 Additional Verification is additive' ($r.Code-eq0-and$r.Text-match'REPOSITORY, pwsh -NoProfile') $r.Text
    Reset-Fixture;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-404-missing.md');$r=Run;Assert '16 stale active-CR pointer blocks' ($r.Code-ne0-and$r.Text-match'STALE_ACTIVE_CR') $r.Text
    Reset-Fixture;Put 'scripts/check_repository_consistency.ps1' "Write-Output 'REPOSITORY CONSISTENCY: issue';exit 1";$r=Run;Assert '17 repository-guard failure blocks' ($r.Code-ne0-and$r.Text-match'REPOSITORY_CONSISTENCY_FAILED') $r.Text
    Reset-Fixture;$r=Run;Assert '18 successful output remains compact' ($r.Code-eq0-and$r.Lines-lt20) "lines=$($r.Lines)"
    Reset-Fixture;Put outside.txt bad;$r=Run Gate;Assert '19 exact failure evidence is named' ($r.Text-match'CODE: OUT_OF_SCOPE_WRITE'-and$r.Text-match'SUBJECT: outside.txt') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Attempt 4);$r=Run;Assert '20 Recovery Attempt greater than 3 blocks' ($r.Code-ne0-and$r.Text-match'INVALID_RUNTIME_CHECKPOINT') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Blocker TEST_BLOCKER -Attempt 3);$r=Run;Assert '21 attempt 3 with blocker is recovery exhausted' ($r.Code-ne0-and$r.Text-match'HARD_BLOCKED: RECOVERY_EXHAUSTED') $r.Text
    Reset-Fixture;$r1=Run;$r2=Run;Assert '22 cold-start checkpoint survives process restart' ($r1.Text-match'STEP: 1/2'-and$r2.Text-match'STEP: 1/2') $r2.Text

    Reset-Fixture;Add-Content -LiteralPath (Join-Path $root 'changes/SPEC-800-complete.md') -Value probe;$r=Run Gate;Assert '23 attempted modification of BASE Complete CR is rejected' ($r.Code-ne0-and$r.Text-match'HISTORICAL_CR_MUTATION:changes/SPEC-800-complete.md') $r.Text
    Reset-Fixture;Add-Content -LiteralPath (Join-Path $root 'changes/SPEC-801-cancelled.md') -Value probe;$r=Run Gate;Assert '24 attempted modification of BASE Cancelled CR is rejected' ($r.Code-ne0-and$r.Text-match'HISTORICAL_CR_MUTATION:changes/SPEC-801-cancelled.md') $r.Text
    Reset-Fixture;Move-Item (Join-Path $root 'changes/SPEC-800-complete.md') (Join-Path $root 'changes/SPEC-802-renamed.md');$r=Run Gate;Assert '25 deletion or rename of BASE closed CR is rejected' ($r.Code-ne0-and$r.Text-match'HISTORICAL_CR_MUTATION:changes/SPEC-800-complete.md') $r.Text
    Reset-Fixture;Put 'changes/SPEC-155-reuse.md' (ContractText -Id SPEC-155);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-155-reuse.md');$r=Run Gate;Assert '26 historical product SPEC-155 cannot be reused' ($r.Code-ne0-and$r.Text-match'SPEC_ID_ALREADY_USED:SPEC-155') $r.Text
    Reset-Fixture;Put 'changes/SPEC-901-fresh.md' (ContractText -Id SPEC-901 -Scope '_ORVION_CANONICAL/manifest.md');Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-fresh.md');$r=Run Gate;Assert '27 mechanically unused fresh ID is accepted' ($r.Code-eq0-and$r.Text-match'CR: SPEC-901') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' ((ContractText)-replace'SPEC-900','SPEC-901');$r=Run;Assert '28 CR heading and file mismatch is rejected' ($r.Code-ne0-and$r.Text-match'CR_ID_PATH_MISMATCH') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Multiline);$r=Run;Assert '29 multiline Implementation Step is returned in full' ($r.Code-eq0-and$r.Text-match'first line'-and$r.Text-match'continuation line') $r.Text

    Reset-Fixture;Put '.githooks/pre-commit' "#!/bin/sh`nexec pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate`n";git -C $root add .githooks/pre-commit;git -C $root update-index --chmod=+x .githooks/pre-commit;git -C $root commit -m hook --quiet;git -C $root config core.hooksPath .githooks;Put outside.txt injected;git -C $root add outside.txt;$before=git -C $root rev-parse HEAD;$out=(git -C $root commit -m injected 2>&1|Out-String);$code=$LASTEXITCODE;$after=git -C $root rev-parse HEAD;Assert '30 pre-commit rejects a real out-of-scope write' ($code-ne0-and$before-eq$after-and$out-match'OUT_OF_SCOPE_WRITE') $out

    Reset-Fixture;git -C $root config --unset core.hooksPath 2>$null;Put allowed.txt range;Commit active-range;$r=RunRange 'HEAD~1';Assert '31 active CI range resolves' ($r.Code-eq0-and$r.Text-match'CR: SPEC-900') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md');Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit completion-range;$r=RunRange 'HEAD~1';Assert '32 completion CI range resolves only from nonterminal BASE' ($r.Code-eq0-and$r.Text-match'MODE: VERIFY') $r.Text
    Reset-Fixture;Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899);Commit add-second;git -C $root push origin main --quiet;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE);Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899 -Status Complete -Resume DONE);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit ambiguous;$r=RunRange 'HEAD~1';Assert '33 ambiguous governing CR range fails closed' ($r.Code-ne0-and$r.Text-match'AMBIGUOUS_GOVERNING_CR') $r.Text
    Reset-Fixture;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Put allowed.txt ungoverned;Commit no-governor;$r=RunRange 'HEAD~1';Assert '34 missing governing CR range fails closed' ($r.Code-ne0-and$r.Text-match'NO_GOVERNING_CR') $r.Text
    Reset-Fixture;Put allowed.txt detached;Commit detached;$base=git -C $root rev-parse HEAD~1;$head=git -C $root rev-parse HEAD;git -C $root checkout --detach $head --quiet;$r=RunRange $base $head;Assert '35 detached-HEAD range mode succeeds without upstream' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Reset-Fixture;git -C $root branch --unset-upstream; $r=Run;Assert '36 local mode with missing upstream blocks' ($r.Code-ne0-and$r.Text-match'GIT_UPSTREAM_MISSING') $r.Text

    Reset-Fixture;git clone -b main $remote $writer --quiet;git -C $writer config user.email writer@orvion.invalid;git -C $writer config user.name Writer;Set-Content -LiteralPath (Join-Path $writer context.txt) -Value advanced;git -C $writer add context.txt;git -C $writer commit -m advance --quiet;git -C $writer push origin main --quiet;$r=Run;Assert '37 local fetch notices newly advanced remote' ($r.Code-ne0-and$r.Text-match'GIT_NOT_SYNCHRONIZED:.*behind 1') $r.Text
    Remove-Item -LiteralPath $writer -Recurse -Force;git -C $root reset --hard origin/main --quiet

    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Put 'scripts/check_repository_consistency.ps1' "exit 1";$r=Run;Assert '38 PLAN repository-guard failure blocks' ($r.Code-ne0-and$r.Text-match'REPOSITORY_CONSISTENCY_FAILED') $r.Text
    Reset-Fixture;$o=& pwsh -NoProfile -File $control -Gate -Root $root -SkipRepositoryGuard 2>&1;$code=$LASTEXITCODE;Assert '39 SkipRepositoryGuard no longer exists' ($code-ne0-and($o|Out-String)-match'parameter.*SkipRepositoryGuard') ($o|Out-String)

    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume DONE -Scope scripts/test_agent_continuity.ps1);Put 'scripts/test_agent_continuity.ps1' 'exit 9';$r=Run Finish;Assert '40 failing mandatory CONTROL verification makes Finish fail' ($r.Code-ne0-and$r.Text-match'CERTIFY: FAILED'-and$r.Text-match'MANDATORY_VERIFICATION_FAILED') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume DONE -Additional 'pwsh -NoProfile -Command "exit 7"');$r=Run Finish;Assert '41 failing Additional Verification makes Finish fail' ($r.Code-ne0-and$r.Text-match'ADDITIONAL_VERIFICATION_FAILED') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume DONE);$r=Run Finish;Assert '42 successful mandatory verification precedes LOCAL_CERTIFY READY' ($r.Code-eq0-and$r.Text-match'RUN: pwsh -NoProfile -File scripts/check_repository_consistency.ps1'-and$r.Text-match'LOCAL_CERTIFY: READY') $r.Text

    $collisionNeedle='SPEC-155 Agent'+' Control Plane';$collision=@(git -C $sourceRoot grep -n -F $collisionNeedle -- . 2>$null);$product=@(git -C $sourceRoot grep -n -F 'SPEC-155' -- 'supabase/migrations/*' 'reports/master/MASTER_EXECUTION_PLAN.md' 2>$null)
    Assert '43 control-plane identifier collision absent and product SPEC-155 remains' ($collision.Count-eq0-and$product.Count-gt0) "collision=$($collision.Count) product=$($product.Count)"
    $kernel=Get-Content -Raw (Join-Path $sourceRoot AGENTS.md)
    Assert '44 STRUCTURAL POLICY-ANCHOR: §3 restored authority exists' ($kernel-match'Governing meta-principle — Earn-It'-and$kernel-match'Fundamental Domain Structure vs Feature Implementation'-and$kernel-match'Learn-Before-Designing'-and$kernel-match'Phase-transition checkpoint') '§3 anchors missing'
    Assert '45 STRUCTURAL POLICY-ANCHOR: §6 measurement integrity authority exists' ($kernel-match'Measurement integrity — restored compatibility authority'-and$kernel-match'No vacuous security tests'-and$kernel-match'A green guard proves only'-and$kernel-match'External credentials never pass through the agent') '§6 anchors missing'
}finally{
    Remove-Item Env:ORVION_GUARD_MARKER -ErrorAction SilentlyContinue
    if(Test-Path $sandbox){Remove-Item -LiteralPath $sandbox -Recurse -Force}
}
Write-Host "AGENT CONTROL TESTS: $($script:pass) passed, $($script:fail) failed"
if($script:fail){exit 1};exit 0
