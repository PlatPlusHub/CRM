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
    [string]$Capabilities='None',[string]$Additional='None',[switch]$Multiline,
    [string]$Objective='Fixture.',[string]$OutOfScope='secret.txt',
    [string]$Acceptance='Fixture.',[string]$Review='Fixture.',
    [string]$Log='None.',[string]$Notes='None.',
    [switch]$Closeable
){
    $steps=if($Multiline){"1. first line`n   continuation line`n2. Exact second action."}else{"1. Exact fixture action.`n2. Exact second action."}
    $box=if($Closeable){'x'}else{' '}
    if($Closeable-and$Notes-eq'None.'){$Notes="### 2026-09-11 00:00 — fixture`nVerdict: Confirmed Complete`nFindings: fixture."}
@"
# Change Request — $Id
## Status
[$(if($Status-eq'Draft'){'x'}else{' '})] Draft
[$(if($Status-eq'Approved'){'x'}else{' '})] Approved
[$(if($Status-eq'In Progress'){'x'}else{' '})] In Progress
[$(if($Status-eq'Complete'){'x'}else{' '})] Complete
[$(if($Status-eq'Cancelled'){'x'}else{' '})] Cancelled
## Objective
$Objective
## Business Reason
Fixture business reason.
## Risks
Fixture risk statement.
## Supersedes / Depends On
None
## Write Scope
$(if($Scope-eq'None'){'None'}else{(@($Scope-split';')|%{"- ``$_``"})-join"`n"})
## Out of Scope
- ``$OutOfScope``
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
- [$box] $Acceptance
## Execution Log
$Log
## Verification Notes
$Notes
## Review Gate
- [$box] $Review
"@
}
function Put([string]$Rel,[string]$Text){$p=Join-Path $root $Rel;$d=Split-Path $p -Parent;if(!(Test-Path $d)){[IO.Directory]::CreateDirectory($d)|Out-Null};[IO.File]::WriteAllText($p,$Text,(New-Object Text.UTF8Encoding($false)))}
function ManifestText([string]$Active='changes/SPEC-900-fixture.md'){"Active Change Request: $Active`nNext capability: Batch 6 Slice 12 on quotations.`n---`n"}
# The local certification receipt is gitignored, and `git clean -fd` deliberately
# leaves ignored files alone, so it would otherwise survive every reset and let one
# case certify the next one's fixture. It is removed explicitly.
$receipt=Join-Path $root '.orvion-local-certification.json'
function Reset-Fixture{git -C $root checkout main --quiet 2>$null;git -C $root branch --set-upstream-to origin/main main --quiet 2>$null;git -C $root reset --hard origin/main --quiet;git -C $root clean -fdq;Remove-Item -LiteralPath $receipt -Force -ErrorAction SilentlyContinue}
# `npx` and `docker` stubs, deliberately OUTSIDE the work tree so `git clean` cannot
# remove them. Prepending them to PATH is what keeps this suite from running a real
# `supabase db reset` against a developer's stack; the DATABASE cases assert that the
# prepend actually took effect before they run anything.
$stubBin=Join-Path $sandbox 'bin'
$stubLog=Join-Path $sandbox 'stub.log'
function Stub([string]$Name){
    [IO.File]::WriteAllText((Join-Path $stubBin "$Name.cmd"),"@echo off`r`n>>`"%ORVION_STUB_LOG%`" echo $Name %*`r`nexit /b 0`r`n")
    [IO.File]::WriteAllText((Join-Path $stubBin $Name),"#!/bin/sh`necho `"$Name `$@`" >> `"`$ORVION_STUB_LOG`"`nexit 0`n")
    if($IsLinux-or$IsMacOS){& chmod +x (Join-Path $stubBin $Name)}
}
function StubLog{if(Test-Path -LiteralPath $stubLog){(Get-Content -Raw -LiteralPath $stubLog)}else{''}}
function StubGhLog{if(Test-Path -LiteralPath (Join-Path $sandbox 'gh.log')){(Get-Content -Raw -LiteralPath (Join-Path $sandbox 'gh.log'))}else{''}}
function Receipt($Object){[IO.File]::WriteAllText($receipt,(ConvertTo-Json $Object -Depth 5),(New-Object Text.UTF8Encoding($false)))}
function ReceiptJson{if(Test-Path -LiteralPath $receipt){Get-Content -Raw -LiteralPath $receipt|ConvertFrom-Json}else{$null}}
function Run([string]$Mode='Boot'){
    $o=& pwsh -NoProfile -File $control "-$Mode" -Root $root 2>&1;$code=$LASTEXITCODE
    [pscustomobject]@{Text=($o|Out-String);Code=$code;Lines=@($o).Count}
}
function RunRange([string]$Base,[string]$Head='HEAD'){
    $o=& pwsh -NoProfile -File $control -Gate -Root $root -BaseRef $Base -HeadRef $Head 2>&1;$code=$LASTEXITCODE
    [pscustomobject]@{Text=($o|Out-String);Code=$code}
}
function Commit([string]$Message){git -C $root add .;git -C $root commit -m $Message --quiet}
# Frozen authority is compared against the Git baseline, so a test that needs a
# DIFFERENT approved contract must commit it as the baseline. Swapping the file
# in the working tree is a post-approval mutation and is correctly rejected.
function Rebase([string]$Text,[string]$Rel='changes/SPEC-900-fixture.md'){$script:rebase++;Put $Rel $Text;Commit "rebase-$script:rebase"}
$script:rebase=0
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
    Put '.gitignore' ".orvion-local-certification.json`n"
    # DATABASE fixtures. The protocol is now EXECUTED rather than listed, so the
    # sandbox needs every file it reads and a project-local CLI for the
    # `supabase-local` probe. Real Supabase and Docker are replaced by stubs below.
    Put 'supabase/migrations/20260101_fixture.sql' 'select 1;'
    Put 'scripts/verify_database.sql' 'select 1;'
    Put 'scripts/verify_fixture.ps1' 'Add-Content -LiteralPath $env:ORVION_STUB_LOG -Value "verify_fixture ran";exit 0'
    Put 'scripts/check_database_parity.ps1' 'exit 0'
    Put 'scripts/check_primary_ledger.ps1' 'exit 0'
    Put 'node_modules/.bin/supabase.cmd' 'rem project-local CLI fixture'
    Put 'node_modules/.bin/supabase' 'exit 0'
    # Workflow fixtures for expected-set derivation: one that always runs on push, one
    # filtered to Markdown, one filtered to migrations, and one with no push trigger at
    # all. Real trigger shapes, so the reader is exercised the way the repository uses it.
    Put '.github/workflows/always.yml' "name: Always`non:`n  push:`n  pull_request:`n"
    Put '.github/workflows/docs.yml' "name: Docs`non:`n  push:`n    paths:`n      - `"**/*.md`"`n  pull_request:`n    paths:`n      - `"**/*.md`"`n"
    Put '.github/workflows/db.yml' "name: Db`non:`n  push:`n    paths:`n      - `"supabase/migrations/**`"`n      - `"supabase/config.toml`"`n"
    Put '.github/workflows/review-only.yml' "name: Review Only`non:`n  pull_request:`n    types: [opened]`n"
    Put 'scripts/check_agent_continuity.ps1' (Get-Content -Raw $control)
    Put 'scripts/check_repository_consistency.ps1' "Write-Output 'REPOSITORY CONSISTENCY: CLEAN'; if(Test-Path env:ORVION_GUARD_MARKER){Set-Content -LiteralPath `$env:ORVION_GUARD_MARKER -Value ran}; exit 0"
    foreach($s in @('test_agent_continuity.ps1','test_cold_start_state_guard.ps1','test_status_contradiction_guard.ps1','test_primary_ledger_guard.ps1','test_future_date_guard.ps1')){Put "scripts/$s" "exit 0"}
    git -C $root add .;git -C $root commit -m baseline --quiet;git -C $root branch -M main;git -C $root push -u origin main --quiet

    [IO.Directory]::CreateDirectory($stubBin)|Out-Null
    Stub npx;Stub docker
    $env:PATH="$stubBin$([IO.Path]::PathSeparator)$env:PATH";$env:ORVION_STUB_LOG=$stubLog
    # Load-bearing precondition, asserted rather than assumed: if the prepend did not
    # take, the DATABASE cases would invoke a REAL `supabase db reset`.
    Assert '00 PRECONDITION: the npx and docker stubs shadow any real executable' ((Get-Command npx -ErrorAction SilentlyContinue).Source-like"$stubBin*"-and(Get-Command docker -ErrorAction SilentlyContinue).Source-like"$stubBin*") "npx=$((Get-Command npx -ErrorAction SilentlyContinue).Source) docker=$((Get-Command docker -ErrorAction SilentlyContinue).Source)"

    $r=Run;Assert '01 valid active CR routes to EXECUTE' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE'-and$r.Text-match'Exact fixture action') $r.Text

    # PLAN means no executable contract exists. Clearing the pointer while the
    # fixture contract is still In Progress is the ORPHANED_APPROVED_CR state, so
    # the contract is returned to Draft here rather than left contradicting it.
    Reset-Fixture;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft);Commit plan-base;git -C $root push origin main --quiet;$marker=Join-Path $sandbox 'guard.marker';$env:ORVION_GUARD_MARKER=$marker;$r=Run;Remove-Item Env:ORVION_GUARD_MARKER;Put '_ORVION_CANONICAL/manifest.md' (ManifestText);Put 'changes/SPEC-900-fixture.md' (ContractText);Commit restore-active;git -C $root push origin main --quiet
    Assert '02 PLAN follows successful Repository Consistency and fresh Git checks' ($r.Code-eq0-and$r.Text-match'MODE: PLAN'-and(Test-Path $marker)-and$r.Text-match'GIT: clean \| ahead 0 / behind 0') $r.Text

    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' '# malformed';$r=Run;Assert '03 malformed CR blocks' ($r.Code-ne0-and$r.Text-match'INVALID_CR_HEADING') $r.Text
    Reset-Fixture;$t=ContractText;$t=$t-replace '\[x\] In Progress','[ ] In Progress';$t=$t-replace '\[ \] Cancelled','[x] Rejected';Put 'changes/SPEC-900-fixture.md' $t;$r=Run;Assert '04 invalid official status blocks' ($r.Code-ne0-and$r.Text-match'INVALID_CR_STATUS') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' ((ContractText)+"`n## Required Reading`n- duplicate.md`n");$r=Run;Assert '05 duplicate required contract section blocks' ($r.Code-ne0-and$r.Text-match'CONTRACT_SECTION_Required Reading') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume 0);$r=Run;Assert '06 invalid Runtime Checkpoint blocks' ($r.Code-ne0-and$r.Text-match'INVALID_RUNTIME_CHECKPOINT') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume 3);$r=Run;Assert '07 Resume Step beyond step count blocks' ($r.Code-ne0-and$r.Text-match'INVALID_RESUME_STEP') $r.Text
    Reset-Fixture;Put 'allowed.txt' changed;$r=Run Gate;Assert '08 allowed in-scope write passes' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Reset-Fixture;Put 'outside.txt' bad;$r=Run Gate;Assert '09 out-of-scope write blocks' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:outside.txt') $r.Text
    Reset-Fixture;$null=Get-Content(Join-Path $root context.txt);$r=Run;Assert '10 unrestricted read remains legal' ($r.Code-eq0) $r.Text
    Reset-Fixture;Rebase (ContractText -Reading outside.txt);Put outside.txt bad;$r=Run Gate;Assert '11 Required Reading does not grant write' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:outside.txt') $r.Text
    Reset-Fixture;Put AGENTS.md changed;$r=Run Gate;Assert '12 protected unauthorized write blocks' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:AGENTS.md') $r.Text
    # `n8n` is now a REGISTERED external capability, so it would no longer measure
    # the fail-closed rule. The fixture uses a name the registry genuinely does not
    # contain, which is what the assertion claims to test.
    Reset-Fixture;Rebase (ContractText -Capabilities unregistered-connector);$r=Run;Assert '13 unknown required capability fails closed' ($r.Code-ne0-and$r.Text-match'NO_DETERMINISTIC_CAPABILITY_PROBE:unregistered-connector') $r.Text
    Reset-Fixture;Rebase (ContractText -Scope scripts/check_agent_continuity.ps1);$r=Run;Assert '14 mandatory profile cannot be subtracted' ($r.Code-eq0-and$r.Text-match'VERIFICATION: CONTROL, REPOSITORY') $r.Text
    Reset-Fixture;Rebase (ContractText -Additional 'pwsh -NoProfile -Command "exit 0"');$r=Run;Assert '15 Additional Verification is additive' ($r.Code-eq0-and$r.Text-match'REPOSITORY, pwsh -NoProfile') $r.Text
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
    # The outgoing contract is committed as Draft first: leaving it In Progress
    # while the pointer moves to the new one is the orphan state, and editing it in
    # the working tree would put it outside the new contract's Write Scope.
    Reset-Fixture;Rebase (ContractText -Status Draft);Put 'changes/SPEC-901-fresh.md' (ContractText -Id SPEC-901 -Scope '_ORVION_CANONICAL/manifest.md');Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-fresh.md');$r=Run Gate;Assert '27 mechanically unused fresh ID is accepted' ($r.Code-eq0-and$r.Text-match'CR: SPEC-901') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' ((ContractText)-replace'SPEC-900','SPEC-901');$r=Run;Assert '28 CR heading and file mismatch is rejected' ($r.Code-ne0-and$r.Text-match'CR_ID_PATH_MISMATCH') $r.Text
    Reset-Fixture;Rebase (ContractText -Multiline);$r=Run;Assert '29 multiline Implementation Step is returned in full' ($r.Code-eq0-and$r.Text-match'first line'-and$r.Text-match'continuation line') $r.Text

    Reset-Fixture;Put '.githooks/pre-commit' "#!/bin/sh`nexec pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate`n";git -C $root add .githooks/pre-commit;git -C $root update-index --chmod=+x .githooks/pre-commit;if($IsLinux-or$IsMacOS){& chmod +x (Join-Path $root '.githooks/pre-commit')};git -C $root commit -m hook --quiet;git -C $root config core.hooksPath .githooks;Put outside.txt injected;git -C $root add outside.txt;$before=git -C $root rev-parse HEAD;$out=(git -C $root commit -m injected 2>&1|Out-String);$code=$LASTEXITCODE;$after=git -C $root rev-parse HEAD;Assert '30 pre-commit rejects a real out-of-scope write' ($code-ne0-and$before-eq$after-and$out-match'OUT_OF_SCOPE_WRITE') $out

    Reset-Fixture;git -C $root config --unset core.hooksPath 2>$null;Put allowed.txt range;Commit active-range;$r=RunRange 'HEAD~1';Assert '31 active CI range resolves' ($r.Code-eq0-and$r.Text-match'CR: SPEC-900') $r.Text
    # A LOCAL completion now additionally requires the certification receipt that
    # `-Finish` mints (SPEC-164), so this case earns one first. The range half is
    # deliberately NOT given a receipt: CI holds no local artifact and re-executes
    # the certification itself, and asserting both halves here is what proves the
    # receipt never became an unsatisfiable CI precondition.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md');$null=Run Finish;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md' -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$local=Run Gate;Commit completion-range;Remove-Item -LiteralPath $receipt -Force -ErrorAction SilentlyContinue;$r=RunRange 'HEAD~1';Assert '32 local and CI completion resolve only from nonterminal BASE' ($local.Code-eq0-and$local.Text-match'MODE: VERIFY'-and$r.Code-eq0-and$r.Text-match'MODE: VERIFY') "$($local.Text)`n$($r.Text)"
    # Deliberately NOT pushed. The range only needs local commits, and publishing a
    # second In-Progress contract to the sandbox origin left every later test
    # inheriting a genuine orphan through Reset-Fixture.
    Reset-Fixture;Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899);Commit add-second;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE);Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899 -Status Complete -Resume DONE);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit ambiguous;$r=RunRange 'HEAD~1';Assert '33 ambiguous governing CR range fails closed' ($r.Code-ne0-and$r.Text-match'AMBIGUOUS_GOVERNING_CR') $r.Text
    Reset-Fixture;Rebase (ContractText -Status Draft);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Put allowed.txt ungoverned;Commit no-governor;$r=RunRange 'HEAD~1';Assert '34 missing governing CR range fails closed' ($r.Code-ne0-and$r.Text-match'NO_GOVERNING_CR') $r.Text
    Reset-Fixture;Put allowed.txt detached;Commit detached;$base=git -C $root rev-parse HEAD~1;$head=git -C $root rev-parse HEAD;git -C $root checkout --detach $head --quiet;$r=RunRange $base $head;Assert '35 detached-HEAD range mode succeeds without upstream' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Reset-Fixture;git -C $root branch --unset-upstream; $r=Run;Assert '36 local mode with missing upstream blocks' ($r.Code-ne0-and$r.Text-match'GIT_UPSTREAM_MISSING') $r.Text

    Reset-Fixture;git clone -b main $remote $writer --quiet;git -C $writer config user.email writer@orvion.invalid;git -C $writer config user.name Writer;Set-Content -LiteralPath (Join-Path $writer context.txt) -Value advanced;git -C $writer add context.txt;git -C $writer commit -m advance --quiet;git -C $writer push origin main --quiet;$r=Run;Assert '37 local fetch notices newly advanced remote' ($r.Code-ne0-and$r.Text-match'GIT_NOT_SYNCHRONIZED:.*behind 1') $r.Text
    Remove-Item -LiteralPath $writer -Recurse -Force;git -C $root reset --hard origin/main --quiet

    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft);Put 'scripts/check_repository_consistency.ps1' "exit 1";$r=Run;Assert '38 PLAN repository-guard failure blocks' ($r.Code-ne0-and$r.Text-match'REPOSITORY_CONSISTENCY_FAILED') $r.Text
    Reset-Fixture;$o=& pwsh -NoProfile -File $control -Gate -Root $root -SkipRepositoryGuard 2>&1;$code=$LASTEXITCODE;Assert '39 SkipRepositoryGuard no longer exists' ($code-ne0-and($o|Out-String)-match'parameter.*SkipRepositoryGuard') ($o|Out-String)

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope scripts/test_agent_continuity.ps1);Put 'scripts/test_agent_continuity.ps1' 'exit 9';$r=Run Finish;Assert '40 failing mandatory CONTROL verification makes Finish fail' ($r.Code-ne0-and$r.Text-match'CERTIFY: FAILED'-and$r.Text-match'MANDATORY_VERIFICATION_FAILED') $r.Text
    Reset-Fixture;Rebase (ContractText -Resume DONE -Additional 'pwsh -NoProfile -Command "exit 7"');$r=Run Finish;Assert '41 failing Additional Verification makes Finish fail' ($r.Code-ne0-and$r.Text-match'ADDITIONAL_VERIFICATION_FAILED') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume DONE);$r=Run Finish;Assert '42 successful mandatory verification precedes LOCAL_CERTIFY READY' ($r.Code-eq0-and$r.Text-match'PASS: pwsh -NoProfile -File scripts/check_repository_consistency.ps1'-and$r.Text-match'LOCAL_CERTIFY: READY') $r.Text

    $collisionNeedle='SPEC-155 Agent'+' Control Plane';$collision=@(git -C $sourceRoot grep -n -F $collisionNeedle -- . 2>$null);$product=@(git -C $sourceRoot grep -n -F 'SPEC-155' -- 'supabase/migrations/*' 'reports/master/MASTER_EXECUTION_PLAN.md' 2>$null)
    Assert '43 control-plane identifier collision absent and product SPEC-155 remains' ($collision.Count-eq0-and$product.Count-gt0) "collision=$($collision.Count) product=$($product.Count)"
    $kernel=Get-Content -Raw (Join-Path $sourceRoot AGENTS.md)
    # These anchors moved to their owning authority with SPEC-163; the assertion did
    # not weaken, it follows the rule. The kernel must still ROUTE to that owner, and
    # the owner must still HOLD the rule - both halves are asserted, because either
    # one alone permits the authority to become implicitly remembered.
    $method=if(Test-Path (Join-Path $sourceRoot ENGINEERING_METHOD.md)){Get-Content -Raw (Join-Path $sourceRoot ENGINEERING_METHOD.md)}else{''}
    Assert '44 STRUCTURAL POLICY-ANCHOR: decision and architecture authority exists and is routed' ($method-match'Governing meta-principle — Earn-It'-and$method-match'Fundamental Domain Structure vs Feature Implementation'-and$method-match'Learn-Before-Designing'-and$method-match'Phase-transition checkpoint'-and$kernel-match'ENGINEERING_METHOD\.md §2') '§2 anchors missing from ENGINEERING_METHOD.md, or AGENTS.md no longer routes there'
    Assert '45 STRUCTURAL POLICY-ANCHOR: measurement integrity authority exists and is routed' ($method-match'No vacuous security tests'-and$method-match'A green guard proves only'-and$method-match'Attack every new detector with a counterexample'-and$method-match'External credentials never pass through the agent'-and$kernel-match'ENGINEERING_METHOD\.md §3') '§3 anchors missing from ENGINEERING_METHOD.md, or AGENTS.md no longer routes there'

    # ---- TRUST KERNEL: the agent may update state, never rewrite its own authority ----
    # The headline attack: redirect my own Write Scope at a new path, then write it.
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Scope 'outside.txt');Put 'outside.txt' 'expanded';$r=Run Gate
    Assert '46 active CR cannot expand its own Write Scope' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED:Write Scope') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' ((ContractText)-replace'Exact second action\.','Rewritten second action.');$r=Run Gate
    Assert '47 Implementation Steps cannot change after approval' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED:Implementation Steps') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Capabilities github);Commit caps-base;Put 'changes/SPEC-900-fixture.md' (ContractText -Capabilities None);$r=Run Gate
    Assert '48 a Required Capability cannot be removed' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED:Required Capabilities') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Additional 'pwsh -NoProfile -Command "exit 0"');Commit verif-base;Put 'changes/SPEC-900-fixture.md' (ContractText -Additional None);$r=Run Gate
    Assert '49 Additional Verification cannot be weakened' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED:Additional Verification') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Objective 'Something entirely different.');$r=Run Gate
    Assert '50 Objective cannot change after approval' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED:Objective') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -OutOfScope 'nolonger.txt');$r=Run Gate
    Assert '51 Out of Scope cannot be narrowed after approval' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED:Out of Scope') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume 2);$r=Run Gate
    Assert '52 MUST-ACCEPT: legal Runtime Checkpoint synchronization passes' ($r.Code-eq0-and$r.Text-match'STEP: 2/2') $r.Text

    # ---- Evidence is append-only: prior findings cannot be rewritten away ----
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Log 'ENTRY ONE');Commit log-base;Put 'changes/SPEC-900-fixture.md' (ContractText -Log 'ENTRY TWO');$r=Run Gate
    Assert '53 a prior Execution Log entry cannot be edited' ($r.Code-ne0-and$r.Text-match'EVIDENCE_NOT_APPEND_ONLY:Execution Log') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Log 'ENTRY ONE');Commit log-base2;Put 'changes/SPEC-900-fixture.md' (ContractText -Log 'None.');$r=Run Gate
    Assert '54 a prior Execution Log entry cannot be deleted' ($r.Code-ne0-and$r.Text-match'EVIDENCE_NOT_APPEND_ONLY:Execution Log') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Log 'ENTRY ONE');Commit log-base3;Put 'changes/SPEC-900-fixture.md' (ContractText -Log "ENTRY ONE`n`nENTRY TWO");$r=Run Gate
    Assert '55 MUST-ACCEPT: appending a new Execution Log entry passes' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Notes 'VERDICT ONE');Commit notes-base;Put 'changes/SPEC-900-fixture.md' (ContractText -Notes 'VERDICT REWRITTEN');$r=Run Gate
    Assert '56 a prior Verification Notes entry cannot be rewritten' ($r.Code-ne0-and$r.Text-match'EVIDENCE_NOT_APPEND_ONLY:Verification Notes') $r.Text

    # ---- Acceptance and Review wording is frozen; only the checkbox moves ----
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Acceptance 'A weaker criterion.');$r=Run Gate
    Assert '57 an Acceptance Criterion cannot be reworded' ($r.Code-ne0-and$r.Text-match'ACCEPTANCE_TEXT_MUTATED') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' ((ContractText)-replace'(?m)^- \[ \] Fixture\.\r?\n## Execution Log','## Execution Log');$r=Run Gate
    Assert '58 an Acceptance Criterion cannot be removed' ($r.Code-ne0-and$r.Text-match'ACCEPTANCE_TEXT_MUTATED:count') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Closeable);$r=Run Gate
    Assert '59 MUST-ACCEPT: checking an unchecked criterion passes' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Review 'A weaker gate item.');$r=Run Gate
    Assert '60 a Review Gate item cannot be reworded' ($r.Code-ne0-and$r.Text-match'REVIEW_GATE_TEXT_MUTATED') $r.Text

    # ---- The full CR_LIFECYCLE.md §4 transition matrix ----
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft);Commit draft-base;Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress');$r=Run Gate
    Assert '61 Draft to In Progress is rejected' ($r.Code-ne0-and$r.Text-match'ILLEGAL_STATUS_TRANSITION:Draft->In Progress') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft);Commit draft-base2;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Closeable);$r=Run Gate
    Assert '62 Draft to Complete is rejected' ($r.Code-ne0-and$r.Text-match'ILLEGAL_STATUS_TRANSITION:Draft->Complete') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved);Commit approved-base;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Closeable);$r=Run Gate
    Assert '63 Approved to Complete is rejected' ($r.Code-ne0-and$r.Text-match'ILLEGAL_STATUS_TRANSITION:Approved->Complete') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft);Commit draft-base3;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved);$r=Run Gate
    Assert '64 MUST-ACCEPT: Draft to Approved passes' ($r.Code-eq0-and$r.Text-match'STATUS: Approved') $r.Text
    Reset-Fixture;Put 'changes/SPEC-800-complete.md' (ContractText -Id SPEC-800 -Status 'In Progress');$r=Run Gate
    Assert '65 a terminal Change Request cannot be reopened' ($r.Code-ne0-and$r.Text-match'HISTORICAL_CR_MUTATION:changes/SPEC-800-complete.md') $r.Text

    # ---- Completion prerequisites are mechanical, not merely declared ----
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Closeable -Notes 'No verdict here.');$r=Run Gate
    Assert '66 Complete without a Confirmed Complete verdict is rejected' ($r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:no Confirmed Complete verdict') $r.Text
    Reset-Fixture;$t=(ContractText -Status Complete -Resume DONE -Closeable)-replace'(?m)^- \[x\] Fixture\.\r?\n## Execution Log',"- [ ] Fixture.`n## Execution Log";Put 'changes/SPEC-900-fixture.md' $t;$r=Run Gate
    Assert '67 Complete with an unchecked Acceptance Criterion is rejected' ($r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:1 unchecked Acceptance Criterion') $r.Text
    Reset-Fixture;$t=(ContractText -Status Complete -Resume DONE -Closeable)-replace'(?m)^- \[x\] Fixture\.\s*$','- [ ] Fixture.';$t=$t-replace'(?m)^- \[ \] Fixture\.\r?\n## Execution Log',"- [x] Fixture.`n## Execution Log";Put 'changes/SPEC-900-fixture.md' $t;$r=Run Gate
    Assert '68 Complete with an unchecked Review Gate item is rejected' ($r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:1 unchecked Review Gate item') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Blocker TEST_BLOCKER -Closeable);$r=Run Gate
    Assert '69 Complete while blocked is rejected' ($r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:Blocker TEST_BLOCKER') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume 1 -Closeable);$r=Run Gate
    Assert '70 Complete with an unfinished Resume Step is rejected' ($r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:Resume Step 1') $r.Text
    # "Fully satisfied" now includes the local certification receipt (SPEC-164): the
    # textual prerequisites above are all writable by hand, so on their own they
    # never proved that verification ran. The case still asserts acceptance, against
    # a strictly stronger precondition.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md');$null=Run Finish;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md' -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '71 MUST-ACCEPT: a fully satisfied completion passes' ($r.Code-eq0-and$r.Text-match'MODE: VERIFY') $r.Text

    # ---- Identity and pointer agreement ----
    Reset-Fixture;Put 'changes/SPEC-902-first.md' (ContractText -Id SPEC-902);Put 'changes/SPEC-902-second.md' (ContractText -Id SPEC-902);$r=Run Gate
    Assert '72 two new Change Requests cannot share one identifier in a single diff' ($r.Code-ne0-and$r.Text-match'DUPLICATE_NEW_SPEC_ID:SPEC-902') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '73 an Approved Change Request with no active pointer is rejected' ($r.Code-ne0-and$r.Text-match'ORPHANED_APPROVED_CR:changes/SPEC-900-fixture.md') $r.Text
    Reset-Fixture;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit plan-pointer;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft);$r=Run Gate
    Assert '74 MUST-ACCEPT: a Draft Change Request needs no active pointer' ($r.Code-eq0-and$r.Text-match'MODE: PLAN') $r.Text

    # ---- EVIDENCE_CLASS: local certification may assert only what it executed ----
    Reset-Fixture;Put 'scripts/check_repository_consistency.ps1' "Write-Output 'NOISE_LINE_SENTINEL';Write-Output 'REPOSITORY CONSISTENCY: CLEAN';exit 0";Rebase (ContractText -Resume DONE);$r=Run Finish
    Assert '75 successful verification is one PASS line, not streamed child output' ($r.Code-eq0-and$r.Text-match'PASS: pwsh -NoProfile -File scripts/check_repository_consistency\.ps1'-and$r.Text-notmatch'NOISE_LINE_SENTINEL') $r.Text
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope scripts/test_agent_continuity.ps1);Put 'scripts/test_agent_continuity.ps1' "Write-Output 'DIAG_TAIL_SENTINEL';exit 9";$r=Run Finish
    Assert '76 failed verification keeps command, exit code and diagnostic evidence' ($r.Code-ne0-and$r.Text-match'FAILED: .*test_agent_continuity\.ps1 \(exit 9\)'-and$r.Text-match'DIAG_TAIL_SENTINEL'-and$r.Text-match'full log:') $r.Text
    Reset-Fixture;Rebase (ContractText -Resume DONE -Additional 'git diff --check');$r=Run Finish
    Assert '77 a command that is both mandatory and additional executes once' ($r.Code-eq0-and(([regex]::Matches($r.Text,'PASS: git diff --check')).Count-eq1)) $r.Text
    # The old assertion here read "DATABASE local evidence that did not run withholds
    # LOCAL_CERTIFY READY". That expectation encoded a weaker contract: nothing ran, so
    # nothing could ever pass, and a weaker agent was left choosing between permanent
    # incompleteness and completing without certification (SPEC-164 DEFECT B). The
    # protocol is now EXECUTED, so the assertion is replaced by a stricter one - the
    # ENGINEERING_METHOD.md §4 order is actually performed, with pgTAP run on BOTH sides
    # of the HTTP suites - while Primary remains EXTERNAL and is still never claimed
    # locally. Rejection coverage for DATABASE moved to cases 99-103c below.
    Reset-Fixture;Remove-Item -LiteralPath $stubLog -Force -ErrorAction SilentlyContinue
    Rebase (ContractText -Resume DONE -Scope 'supabase/migrations/20260101_fixture.sql' -Capabilities 'supabase-local' -Additional 'pwsh -NoProfile -File scripts/verify_fixture.ps1');$r=Run Finish
    $order=StubLog
    $reset=$order.IndexOf('npx supabase db reset');$passA=$order.IndexOf('npx supabase test db')
    $http=$order.IndexOf('verify_fixture ran');$passB=$order.LastIndexOf('npx supabase test db');$smoke=$order.IndexOf('docker exec')
    Assert '78 MUST-ACCEPT: the DATABASE protocol executes in its documented order' ($r.Code-eq0-and$reset-ge0-and$passA-gt$reset-and$http-gt$passA-and$passB-gt$http-and$smoke-gt$passB-and$r.Text-match'EVIDENCE: DATABASE EXTERNAL:'-and$r.Text-match'LOCAL_CERTIFY: READY') "$($r.Text)`n--- stub log ---`n$order"
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope '.github/workflows/agent-control.yml');$r=Run Finish
    Assert '79 CI evidence is named as POST_PUSH and never implied locally' ($r.Code-eq0-and$r.Text-match'EVIDENCE: CI POST_PUSH: workflow conclusions on the exact pushed SHA'-and$r.Text-match'LOCAL_CERTIFY: READY') $r.Text
    Reset-Fixture;Rebase (ContractText -Scope GOVERNANCE.md);$r=Run
    Assert '80 GOVERNANCE.md is inside the control surface' ($r.Code-eq0-and$r.Text-match'VERIFICATION: CONTROL, REPOSITORY') $r.Text
    Reset-Fixture;Rebase (ContractText -Scope '.cursor/rules/orvion.mdc');$r=Run
    Assert '81 a thin client adapter is inside the control surface' ($r.Code-eq0-and$r.Text-match'VERIFICATION: CONTROL, REPOSITORY') $r.Text
    Reset-Fixture;Rebase (ContractText -Scope 'allowed.txt');$r=Run
    Assert '82 MUST-ACCEPT: an ordinary path derives REPOSITORY only' ($r.Code-eq0-and$r.Text-match'VERIFICATION: REPOSITORY'-and$r.Text-notmatch'CONTROL') $r.Text

    # ---- A CI range is a PATH of transitions, not one transition (SPEC-162) ----
    # Regression: the range 185d5e1..76c3ee1 carried Approved -> In Progress ->
    # Complete. Every step legal, endpoints not a legal pair, and comparing the
    # endpoints failed a legal history on the real repository.
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope '_ORVION_CANONICAL/manifest.md');Commit path-approved
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope '_ORVION_CANONICAL/manifest.md');Commit path-inprogress
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md' -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit path-complete
    $r=RunRange 'HEAD~2'
    Assert '83 MUST-ACCEPT: a range spanning Approved, In Progress and Complete is legal' ($r.Code-eq0-and$r.Text-match'MODE: VERIFY') $r.Text
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope '_ORVION_CANONICAL/manifest.md');Commit jump-approved
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md' -Closeable);Commit jump-complete
    $r=RunRange 'HEAD~1'
    Assert '84 a single commit jumping Approved straight to Complete is still rejected inside a range' ($r.Code-ne0-and$r.Text-match'ILLEGAL_STATUS_TRANSITION:Approved->Complete') $r.Text

    # ---- The manifest pointer and contract Status are ONE invariant (SPEC-163) ----
    # Only Approved and In Progress carry write authority, so only they may be
    # pointed at. A Draft named as active previously routed to a mode that printed
    # that contract's whole Write Scope on the WRITE: line - an authority a weaker
    # agent would read as permission, and that no approval ever granted.
    Reset-Fixture;Rebase (ContractText -Status Draft);$r=Run
    Assert '85 a manifest naming a Draft contract is a contradiction, not a mode' ($r.Code-ne0-and$r.Text-match'MANIFEST_CR_CONTRADICTION:Draft'-and$r.Text-notmatch'WRITE: allowed\.txt') $r.Text
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Closeable);$r=Run Gate
    Assert '86 a manifest naming a Complete contract is a contradiction' ($r.Code-ne0-and$r.Text-match'MANIFEST_CR_CONTRADICTION:Complete') $r.Text
    # Cancelled is the other terminal state and shares the rejection branch, so it is
    # asserted rather than assumed to follow from Complete.
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Status Cancelled);$r=Run Gate
    Assert '87 a manifest naming a Cancelled contract is a contradiction' ($r.Code-ne0-and$r.Text-match'MANIFEST_CR_CONTRADICTION:Cancelled') $r.Text
    # The orphan scan reads every contract on disk. Scanning only the diff could
    # never see an executable contract committed before the current change began.
    Reset-Fixture;Put 'changes/SPEC-902-orphan.md' (ContractText -Id SPEC-902 -Status Approved);Commit orphan-committed;$r=Run
    Assert '88 an executable contract absent from the diff is still detected as orphaned' ($r.Code-ne0-and$r.Text-match'ORPHANED_APPROVED_CR:changes/SPEC-902-orphan\.md') $r.Text
    Reset-Fixture;Put 'changes/SPEC-902-draft.md' (ContractText -Id SPEC-902 -Status Draft);Commit draft-coexists;$r=Run
    Assert '89 MUST-ACCEPT: a Draft alongside the active contract needs no pointer' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text

    # ---- Capability routing: probe what is local, declare what is not ----
    # A LOCAL_PROBE is PROBED, and the probe tells the truth about this machine. A
    # bare CI runner has `gh` installed but unauthenticated, so asserting that the
    # github probe always PASSES would assert an environment, not a behaviour - which
    # is exactly how this case failed in CI while passing on an authenticated
    # workstation. What must hold everywhere is that a registered capability is never
    # treated as unknown; the outcome is then checked against what is actually true here.
    gh auth status *>$null;$ghAuthed=($LASTEXITCODE-eq0)
    Reset-Fixture;Rebase (ContractText -Capabilities github);$r=Run
    $probed=($r.Text-notmatch'NO_DETERMINISTIC_CAPABILITY_PROBE')-and($r.Text-notmatch'CAPABILITY: github')
    $honest=if($ghAuthed){$r.Code-eq0-and$r.Text-match'MODE: EXECUTE'}else{$r.Code-ne0-and$r.Text-match'MISSING_REQUIRED_CAPABILITY:github'}
    Assert "90 MUST-ACCEPT: a LOCAL_PROBE capability is probed and reports honestly (gh authenticated: $ghAuthed)" ($probed-and$honest) $r.Text
    Reset-Fixture;Rebase (ContractText -Capabilities n8n);$r=Run
    Assert '91 an EXTERNAL_EVIDENCE capability is declared, never claimed proven' ($r.Code-eq0-and$r.Text-match'CAPABILITY: n8n EXTERNAL_EVIDENCE'-and$r.Text-notmatch'MISSING_REQUIRED_CAPABILITY') $r.Text

    # ---- WORKSTATION evidence is executed, not merely deferred ----
    Reset-Fixture;Put '.workstation/doctor.ps1' "Write-Output 'DOCTOR_RAN';exit 0";Rebase (ContractText -Resume DONE -Scope '.workstation/doctor.ps1');$r=Run Finish
    Assert '92 WORKSTATION local evidence runs the doctor instead of deferring it' ($r.Code-eq0-and$r.Text-match'PASS: pwsh -NoProfile -File \.workstation/doctor\.ps1'-and$r.Text-match'LOCAL_CERTIFY: INCOMPLETE'-and$r.Text-match'bootstrap idempotence') $r.Text

    # ---- Identity: a textual mention reserves, by decision (CR_LIFECYCLE.md §4) ----
    # Conservative on purpose. An unused identifier costs nothing; a reused identity
    # is unrecoverable. This fixes the rule so a later agent cannot "fix" it silently.
    Reset-Fixture;Put 'design-notes.txt' 'A future SPEC-903 could handle this.';Commit prose-mention;Put 'changes/SPEC-903-new.md' (ContractText -Id SPEC-903);$r=Run Gate
    Assert '93 an identifier mentioned only in prose is refused for a new contract' ($r.Code-ne0-and$r.Text-match'SPEC_ID_ALREADY_USED:SPEC-903') $r.Text

    # ---- POST_PUSH evidence is never asserted without observing it ----
    $o=& pwsh -NoProfile -File $control -Certify -Root $root 2>&1;$code=$LASTEXITCODE;$t=($o|Out-String)
    # `-notmatch 'ORVION:'` is load-bearing. The first implementation RETURNED its
    # exit code while also writing its result, so the code joined the output stream
    # and the run fell through into the whole Boot pipeline after reporting.
    Assert '94 remote certification never reports READY without reading a real run' ($code-ne0-and$t-match'REMOTE_CERTIFY: (FAILED|PENDING)'-and$t-notmatch'REMOTE_CERTIFY: READY'-and$t-notmatch'ORVION:') $t

    # ---- DEFECT A: Complete must PROVE that Finish succeeded (SPEC-164) ----
    # Every textual completion prerequisite could be satisfied by writing prose. An
    # agent that ticked the boxes, wrote `Verdict: Confirmed Complete` and set
    # `Resume Step: DONE` reached Complete without ever obtaining LOCAL_CERTIFY:
    # READY. The receipt is the anti-omission and anti-staleness control: it exists
    # only because Finish actually ran, and it is bound to the implementation state
    # it certified, so it cannot be carried forward past an edit.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md')
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md' -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '95 Complete with every box checked but no local certification receipt is rejected' ($r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:no local certification receipt') $r.Text

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md')
    Receipt @{cr='SPEC-899';profiles=@('REPOSITORY');fingerprint='0';result='READY'}
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md' -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '96 a certification receipt naming a different Change Request is rejected' ($r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:certification receipt names SPEC-899') $r.Text

    # The profiles are recorded so a receipt cannot be reused across a Write Scope
    # that derives DIFFERENT mandatory verification. Certifying REPOSITORY alone
    # proves nothing about a scope that also derives CONTROL or DATABASE.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md')
    Receipt @{cr='SPEC-900';profiles=@('CONTROL','REPOSITORY');fingerprint='0';result='READY'}
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope '_ORVION_CANONICAL/manifest.md' -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '97 a certification receipt whose verification profiles differ is rejected' ($r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:certification profiles') $r.Text

    # The staleness attack, and the reason a boolean `FINISH_PASSED: true` would not
    # do: certify, then edit an implementation file, then complete.
    $closeScope='allowed.txt;_ORVION_CANONICAL/manifest.md'
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope $closeScope);$f=Run Finish
    Put 'allowed.txt' 'edited after certification'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope $closeScope -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '98 a certification receipt from an older implementation state is rejected' ($f.Text-match'LOCAL_CERTIFY: READY'-and$r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:stale certification receipt') "$($f.Text)`n$($r.Text)"

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope $closeScope);$f=Run Finish;$j=ReceiptJson
    Assert '98b MUST-ACCEPT: a successful Finish writes a receipt bound to this state' ($f.Code-eq0-and$f.Text-match'LOCAL_CERTIFY: READY'-and$null-ne$j-and$j.cr-eq'SPEC-900'-and$j.result-eq'READY'-and$j.fingerprint-and(@($j.profiles)-contains'REPOSITORY')) "$($f.Text)`n$($j|ConvertTo-Json -Depth 5)"
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope $closeScope -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '98c MUST-ACCEPT: a fresh matching receipt permits the completion' ($r.Code-eq0-and$r.Text-match'MODE: VERIFY') $r.Text

    # ---- DEFECT B: DATABASE needs a success path, not only a failure path (SPEC-164) ----
    # `LOCAL_NOT_EXECUTED` was truthful and useless: no sequence of correct actions
    # could turn it green, so the profile could only ever withhold certification.
    $dbScope='supabase/migrations/20260101_fixture.sql'
    $dbAdditional='pwsh -NoProfile -File scripts/verify_fixture.ps1'

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope $dbScope -Additional $dbAdditional);$r=Run
    Assert '99 a DATABASE change that does not declare supabase-local is rejected' ($r.Code-ne0-and$r.Text-match'DATABASE_CAPABILITY_NOT_DECLARED') $r.Text

    # "Relevant HTTP suites" is the one step of the protocol no rule can derive, so the
    # contract must name them. Silence is refused rather than read as "none apply".
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope $dbScope -Capabilities 'supabase-local');$r=Run
    Assert '100 a DATABASE change naming no HTTP suite in Additional Verification is rejected' ($r.Code-ne0-and$r.Text-match'DATABASE_HTTP_SUITE_NOT_NAMED') $r.Text

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope "$dbScope;scripts/check_database_parity.ps1" -Capabilities 'supabase-local' -Additional $dbAdditional)
    Put 'scripts/check_database_parity.ps1' "Write-Output 'DB_DIAG_SENTINEL';exit 9";$r=Run Finish
    Assert '101 a failing mandatory DATABASE command keeps command, exit code and evidence' ($r.Code-ne0-and$r.Text-match'FAILED: .*check_database_parity\.ps1 \(exit 9\)'-and$r.Text-match'DB_DIAG_SENTINEL'-and$r.Text-notmatch'LOCAL_CERTIFY: READY') $r.Text

    # Stale DATABASE evidence: certify, then change a migration, then complete.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope "$dbScope;_ORVION_CANONICAL/manifest.md" -Capabilities 'supabase-local' -Additional $dbAdditional);$f=Run Finish
    Put $dbScope 'select 2;'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope "$dbScope;_ORVION_CANONICAL/manifest.md" -Capabilities 'supabase-local' -Additional $dbAdditional -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '102 stale DATABASE certification cannot complete a later migration state' ($f.Text-match'LOCAL_CERTIFY: READY'-and$r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:stale certification receipt') "$($f.Text)`n$($r.Text)"

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope $dbScope -Capabilities 'supabase-local' -Additional $dbAdditional);$r=Run Finish
    Assert '103 MUST-ACCEPT: a DATABASE change whose whole protocol succeeds reaches LOCAL_CERTIFY READY' ($r.Code-eq0-and$r.Text-match'PASS: npx supabase db reset'-and$r.Text-match'PASS: pwsh -NoProfile -File scripts/check_database_parity\.ps1'-and$r.Text-match'LOCAL_CERTIFY: READY'-and$null-ne(ReceiptJson)) $r.Text

    # ---- Primary evidence: reuse the existing validator, claim only what it proves ----
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'allowed.txt;scripts/check_primary_ledger.ps1' -Capabilities 'supabase-primary')
    Put 'scripts/check_primary_ledger.ps1' "Write-Output 'UNATTRIBUTABLE: evidence belongs to another history';exit 1";$r=Run Finish
    Assert '103b a declared supabase-primary with stale or unattributable evidence is not certified' ($r.Code-ne0-and$r.Text-match'FAILED: .*check_primary_ledger\.ps1'-and$r.Text-notmatch'LOCAL_CERTIFY: READY') $r.Text

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'allowed.txt' -Capabilities 'supabase-primary');$r=Run Finish
    Assert '103c MUST-ACCEPT: valid recorded Primary evidence certifies, and is never called a live read' ($r.Code-eq0-and$r.Text-match'PASS: pwsh -NoProfile -File scripts/check_primary_ledger\.ps1'-and$r.Text-match'CAPABILITY: supabase-primary EXTERNAL_EVIDENCE'-and$r.Text-match'recorded'-and$r.Text-match'LOCAL_CERTIFY: READY') $r.Text

    # ---- DEFECT C: -Certify must prove REQUIRED runs, not merely observed ones (SPEC-164) ----
    # The old logic asked only "did anything fail?". A required workflow that silently
    # stopped triggering produced no run at all, so there was nothing to fail, and the
    # remaining green workflow certified the push on its own.
    #
    # `gh` is stubbed as a PowerShell script keyed BY COMMIT SHA, so "successful on a
    # different SHA" is modelled exactly rather than asserted about the implementation.
    $ghDir=Join-Path $sandbox 'gh';[IO.Directory]::CreateDirectory($ghDir)|Out-Null
    $ghLog=Join-Path $sandbox 'gh.log'
    $env:ORVION_STUB_GH=$ghDir;$env:ORVION_STUB_GH_LOG=$ghLog
    [IO.File]::WriteAllText((Join-Path $stubBin 'gh.ps1'),@'
$i=[array]::IndexOf($args,'--commit');$sha=if($i-ge0){$args[$i+1]}else{''}
Add-Content -LiteralPath $env:ORVION_STUB_GH_LOG -Value "gh $($args -join ' ')"
$f=Join-Path $env:ORVION_STUB_GH "$sha.json"
if(Test-Path -LiteralPath $f){Get-Content -Raw -LiteralPath $f}else{'[]'}
exit 0
'@)
    function RunCertify{$o=& pwsh -NoProfile -File $control -Certify -Root $root 2>&1;[pscustomobject]@{Text=($o|Out-String);Code=$LASTEXITCODE}}
    function Run1([string]$Name,[string]$Status='completed',[string]$Conclusion='success'){@{workflowName=$Name;status=$Status;conclusion=$Conclusion}}
    # The previous case's payload is cleared, not overwritten: two cases share one HEAD
    # SHA, so a leftover file silently answered the query for a case that meant to model
    # "this SHA has no runs".
    function GhRuns([object[]]$Runs,[string]$Sha){Get-ChildItem -LiteralPath $ghDir -File|Remove-Item -Force;[IO.File]::WriteAllText((Join-Path $ghDir "$Sha.json"),(ConvertTo-Json @($Runs) -Depth 4 -AsArray))}
    function ExpectBoth{Receipt @{cr='SPEC-900';profiles=@('REPOSITORY');fingerprint='0';result='READY';expected=@('Agent Control','Repository Consistency')}}

    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    GhRuns @((Run1 'Agent Control')) $sha;$r=RunCertify
    Assert '104 one successful workflow does not certify a SHA whose other required run is missing' ($r.Code-ne0-and$r.Text-match'REMOTE_CERTIFY: FAILED'-and$r.Text-match'REQUIRED_WORKFLOW_MISSING'-and$r.Text-match'Repository Consistency'-and$r.Text-notmatch'REMOTE_CERTIFY: READY') $r.Text

    # Green on some other commit certifies nothing about this one.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    Remove-Item -LiteralPath $ghLog -Force -ErrorAction SilentlyContinue
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency')) '0000000000000000000000000000000000000000';$r=RunCertify
    Assert '105 a required workflow green only on another SHA never satisfies this one' ($r.Code-ne0-and$r.Text-notmatch'REMOTE_CERTIFY: READY'-and(StubGhLog)-match"--commit $sha") "$($r.Text)`n$(StubGhLog)"

    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency' 'in_progress' $null)) $sha;$r=RunCertify
    Assert '106 a required workflow still in progress is PENDING, never READY' ($r.Code-ne0-and$r.Text-match'REMOTE_CERTIFY: PENDING'-and$r.Text-notmatch'REMOTE_CERTIFY: READY') $r.Text

    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency' 'completed' 'timed_out')) $sha;$r=RunCertify
    Assert '107 a required workflow concluding anything but success is FAILED' ($r.Code-ne0-and$r.Text-match'REMOTE_CERTIFY: FAILED'-and$r.Text-match'Repository Consistency'-and$r.Text-notmatch'REMOTE_CERTIFY: READY') $r.Text

    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency')) $sha;$r=RunCertify
    Assert '108 MUST-ACCEPT: every expected workflow observed and successful on the exact SHA is READY' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY'-and$r.Text-match"SHA: $sha") $r.Text

    # Fail closed: with no receipt there is no expected set, so nothing can be proven.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim()
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency')) $sha;$r=RunCertify
    Assert '108b remote certification fails closed when no local certification receipt exists' ($r.Code-ne0-and$r.Text-notmatch'REMOTE_CERTIFY: READY'-and$r.Text-match'receipt') $r.Text

    # The expected set is DERIVED from the workflow files' own push triggers, never
    # hardcoded — a fixed list would fail a change that legitimately triggers less.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'allowed.txt');$null=Run Finish;$j=ReceiptJson
    Assert '109 an unfiltered push workflow is expected and a non-matching filtered one is not' ((@($j.expected)-contains'Always')-and(@($j.expected)-notcontains'Docs')-and(@($j.expected)-notcontains'Db')-and(@($j.expected)-notcontains'Review Only')) ($j|ConvertTo-Json -Depth 5)
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'supabase/migrations/20260101_fixture.sql' -Capabilities 'supabase-local' -Additional 'pwsh -NoProfile -File scripts/verify_fixture.ps1');$null=Run Finish;$j=ReceiptJson
    Assert '110 a path-filtered workflow becomes expected exactly when a written path matches it' ((@($j.expected)-contains'Db')-and(@($j.expected)-contains'Always')-and(@($j.expected)-notcontains'Docs')) ($j|ConvertTo-Json -Depth 5)
}finally{
    Remove-Item Env:ORVION_GUARD_MARKER -ErrorAction SilentlyContinue
    Remove-Item Env:ORVION_STUB_LOG -ErrorAction SilentlyContinue
    Remove-Item Env:ORVION_STUB_GH -ErrorAction SilentlyContinue
    Remove-Item Env:ORVION_STUB_GH_LOG -ErrorAction SilentlyContinue
    if(Test-Path $sandbox){Remove-Item -LiteralPath $sandbox -Recurse -Force}
}
Write-Host "AGENT CONTROL TESTS: $($script:pass) passed, $($script:fail) failed"
if($script:fail){exit 1};exit 0
