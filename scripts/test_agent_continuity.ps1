# Deterministic behavioral attacks for scripts/check_agent_continuity.ps1.
$ErrorActionPreference='Stop'
$sourceRoot=Split-Path $PSScriptRoot -Parent
$control=Join-Path $sourceRoot 'scripts/check_agent_continuity.ps1'
$publisher=Join-Path $sourceRoot 'scripts/publish_candidate.ps1'
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
    [string]$Evidence='',
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
$(if($Evidence-eq''){''}else{"## Pre-Approval Evidence`n$Evidence"})
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
# Invoked the way `.github/workflows/agent-control.yml` invokes it, NOT the way the
# local hook does: dot-sourced under `pwsh -Command` with the `exit $LASTEXITCODE`
# appendix GitHub's pwsh shell appends to every step. This is load-bearing. `pwsh
# -File` DISCARDS a script's trailing $LASTEXITCODE, so a Gate that printed a clean
# report and left 128 behind from a deliberately-failing `git show` was exit 0 here
# and exit 128 in CI. The suite was not wrong about the Gate's behaviour; it was
# blind to the one output CI treats as the whole verdict. `Run` below keeps
# `pwsh -File` for the same reason in reverse — that is how the pre-commit hook runs.
function RunRange([string]$Base,[string]$Head='HEAD'){
    $cmd=". '$control' -Gate -Root '$root' -BaseRef '$Base' -HeadRef '$Head'; if ((Test-Path -LiteralPath variable:\LASTEXITCODE)) { exit `$LASTEXITCODE }"
    $o=& pwsh -NoProfile -Command $cmd 2>&1;$code=$LASTEXITCODE
    [pscustomobject]@{Text=($o|Out-String);Code=$code}
}
function Commit([string]$Message){git -C $root add .;git -C $root commit -m $Message --quiet}
# The publisher, run the way a human runs it, against the sandbox rather than a real remote
# (SPEC-184). Same shape as `Run`/`RunRange` above - no new harness.
function RunPublish([string[]]$ExtraArgs=@()){
    $o=& pwsh -NoProfile -File (Join-Path $root 'scripts/publish_candidate.ps1') -Root $root @ExtraArgs 2>&1;$code=$LASTEXITCODE
    [pscustomobject]@{Text=($o|Out-String);Code=$code}
}
# Read from the BARE repository, never from a tracking ref. The tracking ref is what a bare
# lease would consult, so trusting it here would make these cases agree with the very defect
# case 166 exists to catch.
function PreflightSha{
    $s=(git -C $remote rev-parse refs/heads/orvion-preflight 2>$null)
    if($LASTEXITCODE-ne0){''}else{("$s").Trim()}
}
# Points the sandbox `orvion-preflight` at an arbitrary commit. `+` because these cases
# deliberately construct a DIVERGENT preflight, which is the rejected-candidate shape.
function SetPreflight([string]$Rev){git -C $root push origin "+${Rev}:refs/heads/orvion-preflight" --quiet 2>$null;git -C $root fetch origin --quiet 2>$null}
# Frozen authority is compared against the Git baseline, so a test that needs a
# DIFFERENT approved contract must commit it as the baseline. Swapping the file
# in the working tree is a post-approval mutation and is correctly rejected.
function Rebase([string]$Text,[string]$Rel='changes/SPEC-900-fixture.md'){$script:rebase++;Put $Rel $Text;Commit "rebase-$script:rebase"}
$script:rebase=0
# SPEC-196. Fixture identities are DERIVED from the fixture contract's own identity
# rather than written as literals. A literal future number in tracked test source
# would permanently reserve a real production identity under the very monotonic
# reservation rule these cases exist to prove, so the suite must not spend one.
$fxBase=900
function FxId([int]$Offset){"SPEC-$($fxBase+$Offset)"}
# The compact pre-Approval evidence section. Every parameter breaks exactly ONE
# predicate so a refusal can never be credited to the wrong defect.
function EvidenceText(
    [string]$Class='Significant',
    [string]$Consumer='ok',          # ok | none | unknown | unresolved | placeholder | baddisposition
    [string]$Boundary='ok',          # ok | conflict | badstep | openended
    [string]$HJ='ok',                # ok | missing
    [string]$Applicability='ok',     # ok | selfexempt
    [string]$Irreversible='NONE'     # SPEC-198: a declared irreversible action is itself
                                     # an applicability input, so it must be settable.
){
    $rows=switch($Consumer){
        'none'         {''}
        'unknown'      {"| Fixture changed fact | Fixture consumer | UNKNOWN | Fixture evidence. |"}
        'placeholder'  {"| [changed fact, not a file list] | [consumer] | WRITE | [evidence] |"}
        'baddisposition'{"| Fixture changed fact | Fixture consumer | MAYBE | Fixture evidence. |"}
        default        {"| Fixture changed fact | ``allowed.txt`` | WRITE | Fixture preserved behaviour. |"}
    }
    $unresolved=if($Consumer-eq'unresolved'){'A named downstream consumer is still unresolved'}else{'None'}
    $boundaryRow=switch($Boundary){
        # The SPEC-195 shape: the mandatory gate sits INSIDE the invariant's own red
        # window. Every step reference is deliberately IN RANGE, so the refusal can
        # only come from the ordering predicate and never from step validation.
        'conflict'  {"| Fixture invariant | BEFORE_COMPLETION | Step 1 | Step 2 | Step 2 |"}
        'badstep'   {"| Fixture invariant | BEFORE_COMPLETION | Step 1 | Step 99 | Step 2 |"}
        'openended' {"| Fixture invariant | BEFORE_COMPLETION | Step 1 | NONE | Step 2 |"}
        default     {"| Fixture invariant | BEFORE_COMPLETION | NONE | NONE | Step 2 |"}
    }
    $hj=if($HJ-eq'missing'){"Existing Mechanism Reusable: YES`n`nExisting Mechanism: Fixture mechanism."}else{@"
Existing Mechanism Reusable: YES

Existing Mechanism: Fixture mechanism.

Added Property: Fixture distinct property.

Causal Negative: Fixture reproduced counterexample.

Positive Test Design: Fixture positive design.

Negative Test Design: Fixture negative design.

Non-Empty Population Obligation: Fixture population obligation.

Mutation Obligation: Fixture mutation obligation.

Post-Implementation Proof Obligation: Fixture post-implementation proof.
"@}
    # `selfexempt` answers NOT APPLICABLE in both places; the two narrow variants let a
    # mutation isolate ONE of the two checks, because a scenario both of them catch
    # cannot prove either is load-bearing.
    $derivedTable=if($Applicability-in@('selfexempt','tableonly')){'NOT APPLICABLE'}else{'APPLICABLE'}
    $derived=if($Applicability-in@('selfexempt','subonly')){'NOT APPLICABLE'}else{'APPLICABLE'}
@"
Change Class: $Class

### Derived Applicability

| Predicate | Repository-derived fact | Result |
| --- | --- | --- |
| Consumer Closure | Fixture derived fact. | $derivedTable |
| Execution-Boundary Satisfiability | Fixture derived fact. | $derivedTable |
| Permanent-Control Admission | Fixture derived fact. | $derivedTable |
| SPEC Allocation | Fixture derived fact. | $derivedTable |

### Consumer Closure

Applicability: $derived

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
$rows

Unresolved Material Consumers: $unresolved

### Execution-Boundary Satisfiability

Applicability: $derived

Irreversible Action Step: $Irreversible

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
$boundaryRow

### Permanent-Control Admission

Applicability: $derived

$hj

### SPEC Identity Allocation

Applicability: NOT APPLICABLE
"@
}
# Draft -> Approved is the only transition the evidence gate judges, so every
# evidence case must COMMIT the Draft first and then present the Approved tree.
# The manifest may not name a Draft, so it moves with the transition.
# The manifest pointer MOVES as part of approval, so it must be inside the fixture's
# own Write Scope or the run is refused as OUT_OF_SCOPE_WRITE before the evidence is
# ever read - a refusal that would credit these cases for the wrong defect.
# SPEC-198. `Capabilities`/`Additional` are passed through because a DATABASE-profile
# contract is refused by `Validate-DatabaseContract` unless it declares `supabase-local`
# and names a `scripts/verify_*` suite. Without them a DATABASE evidence fixture is
# rejected for the WRONG reason and proves nothing about applicability.
function ApproveRun([string]$Evidence,[string]$Scope='scripts/check_agent_continuity.ps1',[string]$Capabilities='None',[string]$Additional='None'){
    $full="$Scope;_ORVION_CANONICAL/manifest.md"
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $full -Evidence $Evidence -Capabilities $Capabilities -Additional $Additional)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None')
    Commit 'evidence-draft-baseline'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $full -Evidence $Evidence -Capabilities $Capabilities -Additional $Additional)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    Run 'Gate'
}
# Allocation is judged while a new Draft is being AUTHORED, which is PLAN: no contract
# holds write authority, so the new contract file is the only change. Leaving the
# fixture contract In Progress would refuse the new file as an out-of-scope write and
# prove nothing about identity at all.
function PlanBaseline{
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None')
    Commit 'plan-baseline'
}
# Population counters. A family with no accepting case, no rejecting case or no
# mutation kill has not been measured, however green it looks.
$script:pop=@{}
function Pop([string]$Family,[string]$Kind){
    foreach($f in @($Family-split';')){
        $k="$f/$Kind";if(-not $script:pop.ContainsKey($k)){$script:pop[$k]=0};$script:pop[$k]++
    }
}
# Setups are separated from the RUN so a mutation can be applied between them.
function ApproveSetup([string]$Evidence,[string]$Scope='scripts/check_agent_continuity.ps1',[string]$Capabilities='None',[string]$Additional='None'){
    $full="$Scope;_ORVION_CANONICAL/manifest.md"
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $full -Evidence $Evidence -Capabilities $Capabilities -Additional $Additional)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None')
    Commit 'evidence-draft-baseline'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $full -Evidence $Evidence -Capabilities $Capabilities -Additional $Additional)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
}
# SPEC-210. The template shape a contract adopts when the repository does NOT derive
# Permanent-Control Admission: the subsection is omitted WHOLE, not filled with nine
# invented obligations about a control it is not adding.
function EvidenceNoHJ([string]$Consumer='ok'){
    ((EvidenceText -Consumer $Consumer)-replace'(?ms)\r?\n### Permanent-Control Admission\r?\n.*?(?=\r?\n### SPEC Identity Allocation)','')
}
# SPEC-210. Derived write closure. The artifact must EXIST for the closure to bind, so the
# fixture creates it - a rule that fired on a retired artifact would be a new false red.
function ClosureSetup([string]$Scope='allowed.txt;_ORVION_CANONICAL/manifest.md',[string]$Artifact='ai-map.json'){
    Reset-Fixture
    if($Artifact){Put $Artifact '{}'}
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $Scope)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None')
    Commit 'closure-draft-baseline'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $Scope)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
}
function FrozenEvidenceSetup{
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope 'scripts/check_agent_continuity.ps1' -Evidence (EvidenceText))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    Commit 'approved-with-evidence'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope 'scripts/check_agent_continuity.ps1' -Evidence (EvidenceText -Consumer 'none'))
}
function AllocSetup([int]$Offset){PlanBaseline;Put "changes/$(FxId $Offset)-alloc.md" (ContractText -Id (FxId $Offset) -Status Draft)}
function ReservedPresentSetup{PlanBaseline;Put 'lineage.txt' "historical note naming $(FxId 1) once";Commit 'reserve-present';Put "changes/$(FxId 1)-reuse.md" (ContractText -Id (FxId 1) -Status Draft)}
function ReservedTextSetup{
    PlanBaseline;Put 'lineage.txt' "historical note naming $(FxId 1) once";Commit 'reserve-text'
    git -C $root rm -q 'lineage.txt';Commit 'delete-text'
    Put "changes/$(FxId 1)-reuse.md" (ContractText -Id (FxId 1) -Status Draft)
}
function ReservedPathSetup{
    PlanBaseline;Put "notes-$(FxId 2)-plan.txt" 'a path that carries the identity';Commit 'reserve-path'
    git -C $root rm -q "notes-$(FxId 2)-plan.txt";Commit 'delete-path'
    Put "changes/$(FxId 2)-reuse.md" (ContractText -Id (FxId 2) -Status Draft)
}
function SkipReservedSetup{
    PlanBaseline;Put 'lineage.txt' "historical note naming $(FxId 1) once";Commit 'burn-next'
    git -C $root rm -q 'lineage.txt';Commit 'delete-burned'
    Put "changes/$(FxId 2)-after-skip.md" (ContractText -Id (FxId 2) -Status Draft)
}
function NonCrOriginSetup{
    PlanBaseline;Put "supabase/migrations/20260102_$(FxId 40)_fixture.sql" 'select 1;';Commit 'non-cr-origin'
    Put "changes/$(FxId 1)-still-next.md" (ContractText -Id (FxId 1) -Status Draft)
}
function NoMarkerSetup{PlanBaseline;Put 'CR_LIFECYCLE.md' "# fixture lifecycle`n`nno marker here`n";Put "changes/$(FxId 1)-no-marker.md" (ContractText -Id (FxId 1) -Status Draft)}
# Mutations must be EXECUTED, not merely written: `Run` invokes the source
# evaluator against the sandbox, so a mutated sandbox copy would never run and
# every mutation would report a false kill. These invoke the sandbox's own copy.
function RunMutant([string]$Mode='Gate'){
    $o=& pwsh -NoProfile -File (Join-Path $root 'scripts/check_agent_continuity.ps1') "-$Mode" -Root $root 2>&1
    [pscustomobject]@{Text=($o|Out-String);Code=$LASTEXITCODE}
}
function RunMutantRange([string]$Base,[string]$Head='HEAD'){
    $c=Join-Path $root 'scripts/check_agent_continuity.ps1'
    $cmd=". '$c' -Gate -Root '$root' -BaseRef '$Base' -HeadRef '$Head'; if ((Test-Path -LiteralPath variable:\LASTEXITCODE)) { exit `$LASTEXITCODE }"
    $o=& pwsh -NoProfile -Command $cmd 2>&1
    [pscustomobject]@{Text=($o|Out-String);Code=$LASTEXITCODE}
}
# The mutant is COMMITTED so the scenario's own pending change stays the only
# working-tree difference; an uncommitted evaluator edit would be refused as an
# out-of-scope write and the mutation would appear killed for the wrong reason.
function CommitOnly([string]$Rel,[string]$Message){git -C $root add -- $Rel;git -C $root commit -m $Message --quiet}
# The laundering range, reused by the range mutations.
function LaunderSetup{PlanBaseline;LaunderHistory}
function LaunderHistory{
    $script:launderBase=(git -C $root rev-parse HEAD).Trim()
    $s='allowed.txt;_ORVION_CANONICAL/manifest.md'
    Put "changes/$(FxId 50)-illegal.md" (ContractText -Id (FxId 50) -Status Draft -Scope $s);Commit 'illegal-allocation'
    git -C $root mv "changes/$(FxId 50)-illegal.md" "changes/$(FxId 1)-corrected.md";Commit 'correct-it'
    Put "changes/$(FxId 1)-corrected.md" (ContractText -Id (FxId 1) -Status Approved -Scope $s)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText "changes/$(FxId 1)-corrected.md");Commit 'approve-the-correction'
}
# SPEC-200. Range builders, separated from Reset-Fixture so a mutant can be committed
# BEFORE the range base - the range under test then carries identical history in both
# halves and differs only in the evaluator judging it.
$script:raScopeM='scripts/check_agent_continuity.ps1;_ORVION_CANONICAL/manifest.md'
function RaBuildBaseline{
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $script:raScopeM -Evidence (EvidenceText))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None');Commit 'ra-base'
    $b=(git -C $root rev-parse HEAD).Trim()
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $script:raScopeM -Evidence (EvidenceText -Class 'Routine'));Commit 'ra-harden'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $script:raScopeM -Evidence (EvidenceText -Class 'Routine'))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText);Commit 'ra-approve'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope $script:raScopeM -Evidence (EvidenceText -Class 'Routine'));Commit 'ra-ip'
    $b
}
# ISOLATED for mutation (ii). A frozen-SECTION mutation is caught twice - once by the
# endpoint block and again by Validate-CommittedRange's per-commit walk - so inverting the
# endpoint gate would be killed by the walk and prove nothing about the gate. Acceptance
# Criteria text is compared by Validate-Checklist at the ENDPOINT ONLY, so it isolates the
# one predicate under test.
function RaBuildPostApproval{
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $script:raScopeM -Evidence (EvidenceText))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText);Commit 'ra-approved-base'
    $b=(git -C $root rev-parse HEAD).Trim()
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope $script:raScopeM -Evidence (EvidenceText) -Acceptance 'Silently reworded after Approval.');Commit 'ra-post-acceptance-mutation'
    $b
}
function RaBuildReplay{
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $script:raScopeM -Evidence (EvidenceText -Consumer 'unknown'))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None');Commit 'ra-base-bad'
    $b=(git -C $root rev-parse HEAD).Trim()
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $script:raScopeM -Evidence (EvidenceText -Consumer 'unknown'))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText);Commit 'ra-approve-bad'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope $script:raScopeM -Evidence (EvidenceText -Consumer 'unknown'));Commit 'ra-ip-bad'
    $b
}
function MutationKillRangeAt([string]$Name,[scriptblock]$Build,[string]$Expect,[string]$Find,[string]$Replace,[string]$Family='RANGE-AUTH'){
    Reset-Fixture;$b=& $Build;$pristine=RunMutantRange $b
    Reset-Fixture
    $src=Get-Content -Raw $control
    $applied=$src.Contains($Find)
    Put 'scripts/check_agent_continuity.ps1' ($src.Replace($Find,$Replace))
    CommitOnly 'scripts/check_agent_continuity.ps1' 'mutant'
    $b2=& $Build;$mutated=RunMutantRange $b2
    Pop $Family 'mutation'
    Assert $Name ($applied-and($pristine.Text-match$Expect)-and($mutated.Text-notmatch$Expect)) "applied=$applied pristine-has-expected=$($pristine.Text-match$Expect) mutated-has-expected=$($mutated.Text-match$Expect)`n$($mutated.Text)"
}
# One predicate bypassed per run, in a disposable copy of the evaluator. The
# pristine run must show the expected evidence and the mutated run must not, so a
# mutation that merely crashes the evaluator cannot be counted as a kill.
function MutationKill([string]$Name,[scriptblock]$Setup,[string]$Expect,[string]$Find,[string]$Replace,[string]$Family){
    & $Setup;$pristine=RunMutant 'Gate'
    & $Setup
    $src=Get-Content -Raw $control
    $applied=$src.Contains($Find)
    Put 'scripts/check_agent_continuity.ps1' ($src.Replace($Find,$Replace))
    CommitOnly 'scripts/check_agent_continuity.ps1' 'mutant'
    $mutated=RunMutant 'Gate'
    Pop $Family 'mutation'
    Assert $Name ($applied-and($pristine.Text-match$Expect)-and($mutated.Text-notmatch$Expect)) "applied=$applied pristine-has-expected=$($pristine.Text-match$Expect) mutated-has-expected=$($mutated.Text-match$Expect)`n$($mutated.Text)"
}
function MutationKillRange([string]$Name,[string]$Expect,[string]$Find,[string]$Replace,[string]$Family='K-range'){
    LaunderSetup;$pristine=RunMutantRange $script:launderBase
    # The mutant is committed BEFORE the range base, so the range under test carries
    # the same history in both halves and differs only in the evaluator judging it.
    PlanBaseline
    $src=Get-Content -Raw $control
    $applied=$src.Contains($Find)
    Put 'scripts/check_agent_continuity.ps1' ($src.Replace($Find,$Replace))
    CommitOnly 'scripts/check_agent_continuity.ps1' 'mutant'
    LaunderHistory
    $mutated=RunMutantRange $script:launderBase
    Pop $Family 'mutation'
    Assert $Name ($applied-and($pristine.Text-match$Expect)-and($mutated.Text-notmatch$Expect)) "applied=$applied pristine-has-expected=$($pristine.Text-match$Expect) mutated-has-expected=$($mutated.Text-match$Expect)`n$($mutated.Text)"
}
try{
    [IO.Directory]::CreateDirectory($sandbox)|Out-Null
    git init --bare $remote --quiet;git clone $remote $root --quiet
    git -C $root config user.email test@orvion.invalid;git -C $root config user.name ORVION-Test
    Put 'AGENTS.md' '# fixture'
    # SPEC-196. The allocation-enforcement marker lives in the identity authority and is
    # read from a commit's FIRST PARENT copy, so it must exist in the baseline commit for
    # activation to be testable in both directions. It is placed here, not written by a
    # later commit, for the same reason `publish_candidate.ps1` is: introducing it later
    # would be an OUT_OF_SCOPE_WRITE and the K cases would fail for the wrong reason.
    Put 'CR_LIFECYCLE.md' "# fixture lifecycle`n`nSPEC Allocation Enforcement: 1`n"
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
    Put 'scripts/check_database_parity_evidence.ps1' 'exit 0'
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
    # Branch-filtered triggers, in BOTH YAML styles. The flow style is load-bearing:
    # a `branches:` list written inline produces no `- item` lines at all, so a reader
    # that only looks for bullets sees NO filter and calls the workflow unconditionally
    # expected - on every branch it can never run on. The sandbox is checked out on
    # `main`, so `release` is the "some other branch" case.
    Put '.github/workflows/branch-other-flow.yml' "name: Branch Other Flow`non:`n  push:`n    branches: [release]`n"
    Put '.github/workflows/branch-other-block.yml' "name: Branch Other Block`non:`n  push:`n    branches:`n      - release`n"
    Put '.github/workflows/branch-main.yml' "name: Branch Main`non:`n  push:`n    branches: [main]`n"
    Put '.github/workflows/branch-main-paths.yml' "name: Branch Main Paths`non:`n  push:`n    branches: [main]`n    paths:`n      - `"supabase/migrations/**`"`n"
    Put 'scripts/check_agent_continuity.ps1' (Get-Content -Raw $control)
    # The publisher under test, placed in the BASELINE commit deliberately (SPEC-184). It is not
    # in the fixture contract's Write Scope, so introducing it later would itself be the
    # OUT_OF_SCOPE_WRITE that case 164 exists to provoke - the fixture would fail for the wrong
    # reason and 164 would pass without proving anything about the publisher.
    Put 'scripts/publish_candidate.ps1' (Get-Content -Raw $publisher)
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
    # SPEC-202: a fresh identity is now originated in PLAN, as a Draft, with the pointer
    # already at None - that is the only shape the origination rule admits, and PLAN mode
    # permits authoring exactly one thing: a new Draft contract file.
    PlanBaseline;Put 'changes/SPEC-901-fresh.md' (ContractText -Id SPEC-901 -Status Draft -Scope '_ORVION_CANONICAL/manifest.md');$r=Run Gate;Assert '27 mechanically unused fresh ID is accepted' ($r.Code-eq0-and$r.Text-match'MODE: PLAN') $r.Text
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

    # ---- WORKSTATION evidence is executed, and can therefore REACH certification ----
    # The old assertion here pinned `LOCAL_CERTIFY: INCOMPLETE` plus the words
    # "bootstrap idempotence" as correct. That encoded a deadlock as the contract:
    # idempotence was declared `LOCAL_NOT_EXECUTED`, which forced INCOMPLETE, which
    # meant `Write-Certification` never ran, which meant `Complete` was refused for
    # every actor - so NO workstation contract could ever be completed. It is the
    # DATABASE defect (SPEC-164 DEFECT B) one profile over, and the repair is the same
    # one: EXECUTE the evidence. These three cases replace it and prove the SEMANTIC
    # invariant - both doors of the receipt - rather than a new output string.
    Reset-Fixture
    Put '.workstation/doctor.ps1' "Write-Output 'DOCTOR_RAN';exit 0"
    Put 'scripts/verify_workstation_idempotence.ps1' "Write-Output 'IDEMPOTENCE_RAN';exit 0"
    Rebase (ContractText -Resume DONE -Scope '.workstation/doctor.ps1');$r=Run Finish;$j=ReceiptJson
    Assert '92 MUST-ACCEPT: proven WORKSTATION evidence executes and reaches a receipt' ($r.Code-eq0-and$r.Text-match'PASS: pwsh -NoProfile -File \.workstation/doctor\.ps1'-and$r.Text-match'PASS: pwsh -NoProfile -File scripts/verify_workstation_idempotence\.ps1'-and$r.Text-match'LOCAL_CERTIFY: READY'-and$r.Text-notmatch'LOCAL_NOT_EXECUTED'-and$null-ne$j-and$j.result-eq'READY'-and(@($j.profiles)-contains'WORKSTATION')) "$($r.Text)`n$($j|ConvertTo-Json -Depth 5)"

    # FAILURE DOOR, idempotence. A workstation that mutates on a second convergence
    # must not certify - and a receipt minted earlier must not survive the attempt,
    # which is why Finish destroys it BEFORE running anything.
    Reset-Fixture
    Put '.workstation/doctor.ps1' "Write-Output 'DOCTOR_RAN';exit 0"
    Put 'scripts/verify_workstation_idempotence.ps1' "Write-Output 'NOT IDEMPOTENT';exit 1"
    Receipt @{cr='SPEC-900';profiles=@('REPOSITORY','WORKSTATION');fingerprint='0';result='READY'}
    Rebase (ContractText -Resume DONE -Scope '.workstation/doctor.ps1');$r=Run Finish
    Assert '173 MUST-REJECT: failing idempotence blocks certification and destroys the older receipt' ($r.Code-ne0-and$r.Text-match'FAILED: pwsh -NoProfile -File scripts/verify_workstation_idempotence\.ps1 \(exit 1\)'-and$r.Text-notmatch'LOCAL_CERTIFY: READY'-and$null-eq(ReceiptJson)) "$($r.Text)`nreceipt: $(ReceiptJson|ConvertTo-Json -Depth 5)"

    # FAILURE DOOR, doctor. Executing idempotence must not have demoted doctor health
    # into something a passing idempotence run can paper over.
    Reset-Fixture
    Put '.workstation/doctor.ps1' "Write-Output 'DOCTOR_UNHEALTHY';exit 1"
    Put 'scripts/verify_workstation_idempotence.ps1' "Write-Output 'IDEMPOTENCE_RAN';exit 0"
    Rebase (ContractText -Resume DONE -Scope '.workstation/doctor.ps1');$r=Run Finish
    Assert '174 MUST-REJECT: a failing doctor still blocks certification and writes no receipt' ($r.Code-ne0-and$r.Text-match'FAILED: pwsh -NoProfile -File \.workstation/doctor\.ps1 \(exit 1\)'-and$r.Text-notmatch'LOCAL_CERTIFY: READY'-and$null-eq(ReceiptJson)) $r.Text

    # ---- WORKSTATION derives for the ROOT entry points and the desired-state authorities ----
    # `^\.workstation/` alone left `bootstrap.ps1` - the only thing that runs on a machine
    # before the repository exists - deriving nothing but REPOSITORY, so a change to it
    # earned no doctor run and no idempotence duty at all. The two JSON files join the
    # surface because prepare.ps1 and doctor.ps1 now READ them for their required sets.
    Reset-Fixture;Rebase (ContractText -Scope 'bootstrap.ps1');$r=Run
    Assert '168 bootstrap.ps1 derives WORKSTATION verification' ($r.Code-eq0-and$r.Text-match'VERIFICATION:.*WORKSTATION') $r.Text
    Reset-Fixture;Rebase (ContractText -Scope 'workstation.cmd');$r=Run
    Assert '169 workstation.cmd derives WORKSTATION verification' ($r.Code-eq0-and$r.Text-match'VERIFICATION:.*WORKSTATION') $r.Text
    Reset-Fixture;Rebase (ContractText -Scope '.vscode/extensions.json');$r=Run
    Assert '170 .vscode/extensions.json derives WORKSTATION verification' ($r.Code-eq0-and$r.Text-match'VERIFICATION:.*WORKSTATION') $r.Text
    Reset-Fixture;Rebase (ContractText -Scope '.mcp.json');$r=Run
    Assert '171 .mcp.json derives WORKSTATION verification' ($r.Code-eq0-and$r.Text-match'VERIFICATION:.*WORKSTATION') $r.Text
    # MUST-REJECT: the widening is bounded. A detector that fired on everything would
    # pass the four cases above while proving nothing about the classification at all.
    Reset-Fixture;Rebase (ContractText -Scope 'PROJECT_CONTEXT.md');$r=Run
    Assert '172 MUST-REJECT: an unrelated document derives no WORKSTATION duty' ($r.Code-eq0-and$r.Text-notmatch'VERIFICATION:.*WORKSTATION') $r.Text

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

    # ---- COMPLETION-OWNED GENERATED STATE (SPEC-179) ----
    # 98 proves an implementation edit after certification is refused. That rule was
    # applied to `ai-map.json` too, and `ai-map.json` is a GENERATED MIRROR of the
    # manifest which the completion act is REQUIRED to regenerate - so a contract
    # scoping it could never complete: Finish certified the map, Complete rewrote it
    # because Check 7 demands it agree with the manifest, and the Gate then called
    # its own mandatory bookkeeping a changed implementation. Reproduced on two
    # unrelated contracts before it was repaired.
    #
    # The pair below is the whole point, and neither half is sufficient alone. 156
    # proves the completion-owned fields no longer stale the receipt; 157 proves the
    # file did NOT simply leave the fingerprint, which is the repair that would have
    # been easy and wrong - Check 7 compares only the live_state fields it extracts,
    # so a `boot_order` rewritten to a file that does not exist leaves Repository
    # Consistency CLEAN and the receipt is the only authority that sees it at all.
    # The maps are written inline rather than through a helper so the two cases
    # cannot drift apart through a shared fixture builder.
    $mapScope='ai-map.json;_ORVION_CANONICAL/manifest.md'
    Reset-Fixture
    Put 'ai-map.json' '{"generated_at":"2026-01-01T00:00:00Z","project":"ORVION","boot_order":["README.md"],"authority":{"execution_conduct":"AGENTS.md"},"live_state":{"source":"_ORVION_CANONICAL/manifest.md","phase":"Phase 8","active_change_request":"changes/SPEC-900-fixture.md","last_completed":"SPEC-899 prior work.","next_capability":"Batch 6 Slice 12 on quotations."}}'
    Rebase (ContractText -Resume DONE -Scope $mapScope);$f=Run Finish
    # Exactly what a real completion regenerates: a new stamp, the pointer cleared,
    # the just-closed work recorded. Every other key byte-identical.
    Put 'ai-map.json' '{"generated_at":"2026-09-14T11:22:33Z","project":"ORVION","boot_order":["README.md"],"authority":{"execution_conduct":"AGENTS.md"},"live_state":{"source":"_ORVION_CANONICAL/manifest.md","phase":"Phase 8","active_change_request":"None.","last_completed":"SPEC-900 fixture work, Complete.","next_capability":"Batch 6 Slice 12 on quotations."}}'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope $mapScope -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '156 MUST-ACCEPT: completion-owned ai-map regeneration after Finish does not stale the receipt' ($f.Text-match'LOCAL_CERTIFY: READY'-and$r.Code-eq0-and$r.Text-match'MODE: VERIFY') "$($f.Text)`n$($r.Text)"

    Reset-Fixture
    Put 'ai-map.json' '{"generated_at":"2026-01-01T00:00:00Z","project":"ORVION","boot_order":["README.md"],"authority":{"execution_conduct":"AGENTS.md"},"live_state":{"source":"_ORVION_CANONICAL/manifest.md","phase":"Phase 8","active_change_request":"changes/SPEC-900-fixture.md","last_completed":"SPEC-899 prior work.","next_capability":"Batch 6 Slice 12 on quotations."}}'
    Rebase (ContractText -Resume DONE -Scope $mapScope);$f=Run Finish
    # ONLY `boot_order` moves. The live_state fields are left exactly as certified, so
    # a pass here could not be explained by the completion-owned exclusion.
    Put 'ai-map.json' '{"generated_at":"2026-01-01T00:00:00Z","project":"ORVION","boot_order":["HOSTILE-NOT-README.md"],"authority":{"execution_conduct":"AGENTS.md"},"live_state":{"source":"_ORVION_CANONICAL/manifest.md","phase":"Phase 8","active_change_request":"changes/SPEC-900-fixture.md","last_completed":"SPEC-899 prior work.","next_capability":"Batch 6 Slice 12 on quotations."}}'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope $mapScope -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '157 a non-completion-owned ai-map mutation after Finish is still refused as stale' ($f.Text-match'LOCAL_CERTIFY: READY'-and$r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:stale certification receipt') "$($f.Text)`n$($r.Text)"

    # STRUCTURAL, because the four excluded names are otherwise a magic list that
    # silently diverges the day the generator renames a field. A rename fails in the
    # SAFE direction - the receipt goes stale and completion is refused - but it
    # refuses it for an unreadable reason, which is what this case buys. It proves
    # only that the exclusion list names fields the generator actually emits; it is
    # deliberately not a test of every ai-map key.
    $fpSrc=[IO.File]::ReadAllText((Join-Path $sourceRoot 'scripts/check_agent_continuity.ps1'))
    $genSrc=[IO.File]::ReadAllText((Join-Path $sourceRoot 'scripts/generate-ai-map.ps1'))
    $proj=[regex]::Match($fpSrc,'(?ms)^function AiMap-CertifiedProjection.*?^\}')
    $excluded=@([regex]::Matches($proj.Value,"'(generated_at|active_change_request|last_completed|next_capability)'")|ForEach-Object{$_.Groups[1].Value}|Select-Object -Unique|Sort-Object)
    $emitted=@(@('generated_at','active_change_request','last_completed','next_capability')|Where-Object{$genSrc-match"(?m)^\s*$_\s*="})
    # ---- THE CERTIFICATION TARGET IS THE BRANCH THIS PUBLISHES TO, NOT THE BRANCH
    # ---- YOU ARE STANDING ON (SPEC-180) ----
    # 144-149 prove what -Certify DOES with a target: preflight evidence never certifies a
    # promotion, a wrong branch or wrong event never certifies, a missing target fails
    # closed, a target ref that has moved is refused. Every one of them injects a receipt
    # by hand through `ExpectBoth`, so not one of them proved where the target came FROM.
    # `Target-Branch` had zero coverage, and it read `rev-parse --abbrev-ref HEAD` - a fact
    # about the checkout, not about the destination. The three cases below are the writer's
    # missing half, and each asserts the target RECORDED BY A REAL `-Finish`, so the path
    # exercised is Finish -> Write-Certification -> Target-Branch -> receipt. A test that
    # parsed Git configuration itself and compared its own answer would prove only that two
    # copies of the same idea agree.
    #
    # No fail-closed case is added here: an unresolvable upstream is already stopped by
    # assertion 36 (`GIT_UPSTREAM_MISSING`), which runs BEFORE any receipt is written, and
    # an empty recorded target is already refused by 148.
    $tScope='allowed.txt;_ORVION_CANONICAL/manifest.md'

    # 159 - the shape that produced the defect. The branch is not named `main`; its upstream
    # is. The destination is a property of the upstream, so the receipt must say `main`.
    Reset-Fixture;git -C $root checkout -q -b publishes-elsewhere;git -C $root branch -q --set-upstream-to origin/main publishes-elsewhere
    Rebase (ContractText -Resume DONE -Scope $tScope);$f=Run Finish;$j=ReceiptJson
    Assert '159 the certification target is the upstream, not the branch name the agent stands on' `
        ($f.Text-match'LOCAL_CERTIFY: READY'-and$null-ne$j-and$j.target-eq'main') `
        "branch=publishes-elsewhere upstream=origin/main recorded target=$($j.target)`n$($f.Text)"
    git -C $root checkout -q main

    # 160 - the control that makes 159 mean something. Every historical execution here ran
    # on `main`, so if this moved, the repair would have traded one wrong answer for another.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope $tScope);$f=Run Finish;$j=ReceiptJson
    Assert '160 CONTROL: executing on main still records main, so the established path cannot regress' `
        ($f.Text-match'LOCAL_CERTIFY: READY'-and$null-ne$j-and$j.target-eq'main') `
        "recorded target=$($j.target)`n$($f.Text)"

    # 161 - a branch name may contain `/`. Deriving from the short `origin/release/foo` form
    # by splitting on the separator yields `foo`, and a target truncated into some OTHER
    # branch's name is worse than no target: it would query a real, wrong branch.
    Reset-Fixture
    git -C $root push -q origin "HEAD:refs/heads/release/foo";git -C $root fetch -q origin
    git -C $root checkout -q -b slash-work;git -C $root branch -q --set-upstream-to origin/release/foo slash-work
    Rebase (ContractText -Resume DONE -Scope $tScope);$f=Run Finish;$j=ReceiptJson
    Assert '161 an upstream branch name containing a slash is recorded whole, never truncated' `
        ($f.Text-match'LOCAL_CERTIFY: READY'-and$null-ne$j-and$j.target-eq'release/foo') `
        "upstream merge ref=$(git -C $root config --get branch.slash-work.merge) recorded target=$($j.target)`n$($f.Text)"
    git -C $root checkout -q main;git -C $root push -q origin --delete 'refs/heads/release/foo' 2>$null;git -C $root fetch -q --prune origin

    Assert '158 STRUCTURAL: the certified projection excludes exactly the completion-owned names the generator emits' `
        ($proj.Success-and($excluded-join',')-eq'active_change_request,generated_at,last_completed,next_capability'-and$emitted.Count-eq4) `
        "excluded=$($excluded-join',') emittedByGenerator=$($emitted.Count)/4 projectionFound=$($proj.Success)"

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

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope "$dbScope;scripts/check_database_parity_evidence.ps1" -Capabilities 'supabase-local' -Additional $dbAdditional)
    Put 'scripts/check_database_parity_evidence.ps1' "Write-Output 'DB_DIAG_SENTINEL';exit 9";$r=Run Finish
    Assert '101 a failing mandatory DATABASE command keeps command, exit code and evidence' ($r.Code-ne0-and$r.Text-match'FAILED: .*check_database_parity_evidence\.ps1 \(exit 9\)'-and$r.Text-match'DB_DIAG_SENTINEL'-and$r.Text-notmatch'LOCAL_CERTIFY: READY') $r.Text

    # Stale DATABASE evidence: certify, then change a migration, then complete.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope "$dbScope;_ORVION_CANONICAL/manifest.md" -Capabilities 'supabase-local' -Additional $dbAdditional);$f=Run Finish
    Put $dbScope 'select 2;'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope "$dbScope;_ORVION_CANONICAL/manifest.md" -Capabilities 'supabase-local' -Additional $dbAdditional -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run Gate
    Assert '102 stale DATABASE certification cannot complete a later migration state' ($f.Text-match'LOCAL_CERTIFY: READY'-and$r.Code-ne0-and$r.Text-match'COMPLETION_PREREQUISITE:stale certification receipt') "$($f.Text)`n$($r.Text)"

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope $dbScope -Capabilities 'supabase-local' -Additional $dbAdditional);$r=Run Finish
    # The protocol commands here are FIXTURES, so this measures ORCHESTRATION - that `-Finish` runs
    # the profile's commands in order and certifies when each exits 0 - and NOT that the real
    # protocol can succeed. Titled as reachability, it stayed green across nineteen contracts while
    # the real parity command was structurally incapable of returning 0 (`PAR-6`). Real reachability
    # of the parity step is proven by 103d-103k, which run the actual adapter.
    Assert '103 MUST-ACCEPT ORCHESTRATION: -Finish runs the DATABASE protocol in order and certifies when every (fixture) command exits 0' ($r.Code-eq0-and$r.Text-match'PASS: npx supabase db reset'-and$r.Text-match'PASS: pwsh -NoProfile -File scripts/check_database_parity_evidence\.ps1'-and$r.Text-match'LOCAL_CERTIFY: READY'-and$null-ne(ReceiptJson)) $r.Text

    # ---- Primary evidence: reuse the existing validator, claim only what it proves ----
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'allowed.txt;scripts/check_primary_ledger.ps1' -Capabilities 'supabase-primary')
    Put 'scripts/check_primary_ledger.ps1' "Write-Output 'UNATTRIBUTABLE: evidence belongs to another history';exit 1";$r=Run Finish
    Assert '103b a declared supabase-primary with stale or unattributable evidence is not certified' ($r.Code-ne0-and$r.Text-match'FAILED: .*check_primary_ledger\.ps1'-and$r.Text-notmatch'LOCAL_CERTIFY: READY') $r.Text

    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'allowed.txt' -Capabilities 'supabase-primary');$r=Run Finish
    Assert '103c MUST-ACCEPT: valid recorded Primary evidence certifies, and is never called a live read' ($r.Code-eq0-and$r.Text-match'PASS: pwsh -NoProfile -File scripts/check_primary_ledger\.ps1'-and$r.Text-match'CAPABILITY: supabase-primary EXTERNAL_EVIDENCE'-and$r.Text-match'recorded'-and$r.Text-match'LOCAL_CERTIFY: READY') $r.Text

    # ---- PAR-6: the DATABASE profile's parity command is satisfied from RECORDED evidence ----
    # The deadlock this closes was reproduced on the real repository: every local DATABASE
    # command passed, the bare `check_database_parity.ps1` still exited 2 (PRIMARY UNPROVEN,
    # $issues = 0, because a bare call supplies none of the three values it requires), and
    # `Invoke-Verification` treats that as fatal - so no DATABASE contract could ever write a
    # receipt. These cases attack the transport, NOT the comparison: the parity engine and the
    # ledger guard are stubbed so that every failure below is attributable to the adapter's own
    # evidence handling rather than borrowed from a neighbouring guard.
    $realAdapter = [IO.File]::ReadAllText((Join-Path $sourceRoot 'scripts/check_database_parity_evidence.ps1'))
    function EvidenceJson([hashtable]$Override=@{}){
        $o=[ordered]@{project_ref='vrvtsxexkiiiivlkdxzp';read_at='2026-09-20T08:05:00Z';repository_head='HEAD_PLACEHOLDER'
                      migration_count=1;ledger_fingerprint='0123456789abcdef0123456789abcdef';ledger=@('20260101_fixture')
                      function_surface_hash='f791acdba3e91462b1625ab8a723db4d';function_count=298
                      structural_surface_hash='0c77972ecf1b45096cda327943a45c00';structural_object_count=3029}
        foreach($k in $Override.Keys){if($null-eq$Override[$k]){$o.Remove($k)}else{$o[$k]=$Override[$k]}}
        $o|ConvertTo-Json -Depth 5
    }
    function RunAdapter{$o=& pwsh -NoProfile -File (Join-Path $root 'scripts/check_database_parity_evidence.ps1') 2>&1;[pscustomobject]@{Text=($o|Out-String);Code=$LASTEXITCODE}}
    function ArmAdapter([string]$ParityStub='exit 0',[string]$LedgerStub='exit 0'){
        Reset-Fixture
        Put 'scripts/check_database_parity_evidence.ps1' $realAdapter
        Put 'scripts/check_database_parity.ps1' $ParityStub
        Put 'scripts/check_primary_ledger.ps1' $LedgerStub
    }

    ArmAdapter;Put 'reports/evidence/primary-ledger-evidence.json' (EvidenceJson);$r=RunAdapter
    Assert '103d MUST-ACCEPT: well-formed Primary evidence reaches the parity engine and returns its 0' ($r.Code-eq0-and$r.Text-match'PRIMARY PARITY EVIDENCE: CLEAN'-and$r.Text-match'never contacts Primary') $r.Text

    ArmAdapter;$r=RunAdapter
    Assert '103e missing Primary evidence is refused, never treated as proven' ($r.Code-ne0-and$r.Text-notmatch'PRIMARY PARITY EVIDENCE: CLEAN') $r.Text

    ArmAdapter;Put 'reports/evidence/primary-ledger-evidence.json' (EvidenceJson @{project_ref='brplkqmbzffpxqgkkdzo'});$r=RunAdapter
    Assert '103f evidence naming Secondary is refused by IDENTITY, not by hoping the hashes differ' ($r.Code-eq1-and$r.Text-match'WRONG PROJECT'-and$r.Text-match'brplkqmbzffpxqgkkdzo') $r.Text

    ArmAdapter;Put 'reports/evidence/primary-ledger-evidence.json' (EvidenceJson @{function_surface_hash=$null});$r=RunAdapter
    Assert '103g a MISSING Primary surface hash is UNPROVEN, and unproven is not clean' ($r.Code-eq1-and$r.Text-match"no 'function_surface_hash'") $r.Text

    ArmAdapter;Put 'reports/evidence/primary-ledger-evidence.json' (EvidenceJson @{structural_surface_hash='NOTAHASH'});$r=RunAdapter
    Assert '103h a malformed Primary surface hash is refused before it reaches the engine' ($r.Code-eq1-and$r.Text-match'MALFORMED') $r.Text

    ArmAdapter -LedgerStub "Write-Output 'STALE/FOREIGN: not an ancestor';exit 1";Put 'reports/evidence/primary-ledger-evidence.json' (EvidenceJson);$r=RunAdapter
    Assert '103i the ledger authority is COMPOSED: its refusal refuses the whole parity claim' ($r.Code-eq1-and$r.Text-match'not usable') $r.Text

    ArmAdapter -ParityStub 'exit 1';Put 'reports/evidence/primary-ledger-evidence.json' (EvidenceJson);$r=RunAdapter
    Assert '103j a DRIFT verdict from the engine is propagated, never swallowed' ($r.Code-eq1-and$r.Text-match'parity engine exited 1') $r.Text

    ArmAdapter -ParityStub 'exit 2';Put 'reports/evidence/primary-ledger-evidence.json' (EvidenceJson);$r=RunAdapter
    Assert '103k UNPROVEN (2) is propagated EXACTLY, not laundered into 1 or 0' ($r.Code-eq2-and$r.Text-match'parity engine exited 2') $r.Text
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
    # The stub HONOURS --branch and --event, so removing either flag from the real command
    # changes what comes back and a test can notice. ORVION_STUB_GH_PERMISSIVE models the
    # opposite world - a GitHub that ignores the filters it was given - which is the only
    # way to prove the implementation's OWN revalidation is load-bearing rather than
    # riding on the query. Without both modes, "filter" and "revalidate" are untestable
    # apart, and a mutant that deletes one would be caught by the other's protection.
    [IO.File]::WriteAllText((Join-Path $stubBin 'gh.ps1'),@'
$a=$args
function Arg([string]$n){$i=[array]::IndexOf($a,$n);if($i-ge0){$a[$i+1]}else{''}}
$sha=Arg '--commit';$branch=Arg '--branch';$evt=Arg '--event'
Add-Content -LiteralPath $env:ORVION_STUB_GH_LOG -Value "gh $($a -join ' ')"
$f=Join-Path $env:ORVION_STUB_GH "$sha.json"
if(!(Test-Path -LiteralPath $f)){'[]';exit 0}
# Assign before wrapping: ConvertFrom-Json emits a JSON array as ONE pipeline item, so
# @(...) around the pipeline yields a single element that IS the array and the re-encode
# below would nest it another level deep.
$parsed=Get-Content -Raw -LiteralPath $f|ConvertFrom-Json
$rows=@($parsed)
if(!$env:ORVION_STUB_GH_PERMISSIVE){
    if($branch){$rows=@($rows|Where-Object{$_.headBranch-eq$branch})}
    if($evt){$rows=@($rows|Where-Object{$_.event-eq$evt})}
}
ConvertTo-Json @($rows) -Depth 6 -AsArray
exit 0
'@)
    function RunCertify{$o=& pwsh -NoProfile -File $control -Certify -Root $root 2>&1;[pscustomobject]@{Text=($o|Out-String);Code=$LASTEXITCODE}}
    # A run now carries the context GitHub actually reports. The defaults describe the
    # ordinary promotion - this SHA, on the target branch, by push - so every pre-existing
    # case keeps meaning exactly what it meant, and a case that wants a DIFFERENT context
    # has to say so explicitly rather than inherit it by accident.
    function Run1([string]$Name,[string]$Status='completed',[string]$Conclusion='success',[string]$Branch='main',[string]$Evt='push',[string]$HeadSha=''){
        @{workflowName=$Name;status=$Status;conclusion=$Conclusion;headBranch=$Branch;event=$Evt;headSha=$HeadSha;attempt=1;databaseId=1}
    }
    # The previous case's payload is cleared, not overwritten: two cases share one HEAD
    # SHA, so a leftover file silently answered the query for a case that meant to model
    # "this SHA has no runs".
    # `headSha` is backfilled from the SHA the payload is keyed to unless a case set it
    # deliberately, so the ordinary cases describe a self-consistent GitHub and only a
    # case that MEANS to model a contradictory row has to produce one.
    function GhRuns([object[]]$Runs,[string]$Sha){
        Get-ChildItem -LiteralPath $ghDir -File|Remove-Item -Force
        $rows=@($Runs|ForEach-Object{if(!$_.headSha){$_.headSha=$Sha};$_})
        [IO.File]::WriteAllText((Join-Path $ghDir "$Sha.json"),(ConvertTo-Json @($rows) -Depth 6 -AsArray))
    }
    function ExpectBoth([string]$Target='main'){Receipt @{cr='SPEC-900';profiles=@('REPOSITORY');fingerprint='0';result='READY';target=$Target;expected=@('Agent Control','Repository Consistency')}}

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

    # ---- Certified evidence must name its context, not merely its SHA (SPEC-173) ----
    # One SHA is pushed TWICE in this model - to `orvion-preflight` to qualify it, then to
    # `main` to promote it - so a single SHA legitimately carries two runs of each legacy
    # workflow over different ranges, reaching different conclusions. This exact shape was
    # measured on `18abbea`: every run belonging to the promotion was green while the
    # preflight run failed correctly on its own range, and SHA-only certification called
    # the promotion FAILED. The accepting case comes FIRST, because a narrowing that only
    # ever rejects would satisfy the rejecting cases alone.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency'),(Run1 'Agent Control' 'completed' 'failure' 'orvion-preflight')) $sha;$r=RunCertify
    Assert '144 MUST-ACCEPT: a preflight failure beside a main success certifies READY for target main' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY'-and$r.Text-match'TARGET: main') $r.Text

    # The same shape inverted. If the branch were being ignored rather than USED, this
    # would pass on the strength of the preflight row - so 144 and 145 together pin the
    # direction, not merely the existence, of the filtering.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    GhRuns @((Run1 'Agent Control' 'completed' 'failure'),(Run1 'Repository Consistency'),(Run1 'Agent Control' 'completed' 'success' 'orvion-preflight')) $sha;$r=RunCertify
    Assert '145 a main failure is FAILED even when the same workflow succeeded on preflight' ($r.Code-ne0-and$r.Text-match'REMOTE_CERTIFY: FAILED'-and$r.Text-match'Agent Control'-and$r.Text-notmatch'REMOTE_CERTIFY: READY') $r.Text

    # PERMISSIVE GITHUB. The stub is told to ignore the --branch/--event it was given, so
    # the query provides no protection at all and only the implementation's own
    # revalidation of the returned headBranch can catch this. Without this case, deleting
    # that revalidation would still pass 144 and 145.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    $env:ORVION_STUB_GH_PERMISSIVE='1'
    GhRuns @((Run1 'Agent Control' 'completed' 'success' 'orvion-preflight'),(Run1 'Repository Consistency' 'completed' 'success' 'orvion-preflight')) $sha;$r=RunCertify
    Assert '146 success only on another branch never certifies the target branch' ($r.Code-ne0-and$r.Text-notmatch'REMOTE_CERTIFY: READY'-and$r.Text-match'IGNORED:') $r.Text

    # Same permissive world, wrong EVENT. A workflow_dispatch or schedule run says nothing
    # about the push path this evidence is meant to describe.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    GhRuns @((Run1 'Agent Control' 'completed' 'success' 'main' 'workflow_dispatch'),(Run1 'Repository Consistency' 'completed' 'success' 'main' 'schedule')) $sha;$r=RunCertify
    Remove-Item Env:ORVION_STUB_GH_PERMISSIVE -ErrorAction SilentlyContinue
    Assert '147 success only under another event never certifies the push path' ($r.Code-ne0-and$r.Text-notmatch'REMOTE_CERTIFY: READY'-and$r.Text-match'IGNORED:') $r.Text

    # A receipt written before the target branch existed cannot be rescued by guessing a
    # default, because guessing the branch IS the defect.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim()
    Receipt @{cr='SPEC-900';profiles=@('REPOSITORY');fingerprint='0';result='READY';expected=@('Agent Control','Repository Consistency')}
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency')) $sha;$r=RunCertify
    Assert '148 a receipt recording no target branch fails closed and names -Finish' ($r.Code-ne0-and$r.Text-notmatch'REMOTE_CERTIFY: READY'-and$r.Text-match'target branch'-and$r.Text-match'-Finish') $r.Text

    # Green evidence about a SHA the branch has already moved past certifies nothing
    # anyone can act on. The remote is advanced by one commit while the receipt and the
    # runs still describe the previous SHA.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency')) $sha
    Put 'allowed.txt' 'moved on';Commit moved-target;git -C $root push origin main --quiet 2>$null
    git -C $root reset --hard $sha --quiet;$r=RunCertify
    Assert '149 a target ref that moved past the certified SHA is FAILED, never READY' ($r.Code-ne0-and$r.Text-match'TARGET_REF_MOVED'-and$r.Text-notmatch'REMOTE_CERTIFY: READY') $r.Text
    git -C $root push origin +"$sha`:refs/heads/main" --quiet 2>$null

    # The expected set is DERIVED from the workflow files' own push triggers, never
    # hardcoded — a fixed list would fail a change that legitimately triggers less.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'allowed.txt');$null=Run Finish;$j=ReceiptJson
    Assert '109 an unfiltered push workflow is expected and a non-matching filtered one is not' ((@($j.expected)-contains'Always')-and(@($j.expected)-notcontains'Docs')-and(@($j.expected)-notcontains'Db')-and(@($j.expected)-notcontains'Review Only')) ($j|ConvertTo-Json -Depth 5)
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'supabase/migrations/20260101_fixture.sql' -Capabilities 'supabase-local' -Additional 'pwsh -NoProfile -File scripts/verify_fixture.ps1');$null=Run Finish;$j=ReceiptJson
    Assert '110 a path-filtered workflow becomes expected exactly when a written path matches it' ((@($j.expected)-contains'Db')-and(@($j.expected)-contains'Always')-and(@($j.expected)-notcontains'Docs')) ($j|ConvertTo-Json -Depth 5)

    # `-Finish` IS the certification, so it may not demand a receipt of itself. Without
    # this the completion act would be unreachable: it necessarily rewrites the manifest
    # and its generated mirror, which any earlier certification cannot have covered.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope $closeScope)
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope $closeScope -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.')
    $f=Run Finish;$r=Run Gate
    Assert '110b MUST-ACCEPT: Finish certifies a completion state it is not asked to already hold' ($f.Code-eq0-and$f.Text-match'LOCAL_CERTIFY: READY'-and$r.Code-eq0-and$r.Text-match'MODE: VERIFY') "$($f.Text)`n$($r.Text)"

    # ---- A contract may be born and die inside one pushed range (SPEC-165) ----
    # The whole lifecycle of a small Change Request fits in one push, and CI rejected
    # exactly that as INVALID_COMPLETION_TRANSITION because the contract did not exist
    # at the range base. Every completion fixture above reaches Complete from a contract
    # the sandbox baseline already held, so the suite tested the TRANSITION and never the
    # contract's AGE. The rejecting cases are asserted beside the accepting one, because
    # the guard that was removed must be proven redundant, not merely absent.
    # The outgoing fixture contract is retired in a commit BEFORE the range begins.
    # Retiring it inside the range makes it an out-of-scope write against the new
    # contract's Write Scope, which would reject these cases for an unrelated reason.
    $rangeScope='_ORVION_CANONICAL/manifest.md'
    function Pre-Range{Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit pre-range}

    Reset-Fixture;Pre-Range
    # SPEC-202: after the activation boundary a contract must be born Draft. The property
    # SPEC-165 earned - a contract created AND completed inside one range is legal history,
    # and range validation may not demand it exist at the base - is unchanged. The
    # pre-activation born-Approved shape is covered by case 219.
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Draft -Scope $rangeScope);Commit born-draft
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope $rangeScope);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit born-approved
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status 'In Progress' -Scope $rangeScope);Commit born-inprogress
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Complete -Resume DONE -Scope $rangeScope -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit born-complete
    $r=RunRange 'HEAD~4'
    Assert '111 MUST-ACCEPT: a contract created and completed inside one range is a legal history' ($r.Code-eq0-and$r.Text-match'MODE: VERIFY'-and$r.Text-match'CR: SPEC-901') $r.Text

    Reset-Fixture;Pre-Range
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Complete -Resume DONE -Scope $rangeScope -Closeable);Commit born-complete-outright
    $r=RunRange 'HEAD~1'
    Assert '112 a contract created already marked Complete is still rejected' ($r.Code-ne0-and$r.Text-match'INVALID_COMPLETION_TRANSITION:changes/SPEC-901-born\.md') $r.Text

    Reset-Fixture;Pre-Range
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Draft -Scope $rangeScope);Commit born-draft
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Complete -Resume DONE -Scope $rangeScope -Closeable);Commit born-draft-to-complete
    $r=RunRange 'HEAD~2'
    Assert '113 a newly created contract taken from Draft straight to Complete is still rejected' ($r.Code-ne0-and$r.Text-match'INVALID_COMPLETION_TRANSITION:changes/SPEC-901-born\.md') $r.Text

    # ---- A successful Gate must SAY it succeeded (SPEC-166) ----
    # Production symptom: the Gate printed ORVION: READY, MODE: VERIFY and BLOCKER:
    # none, and the CI step failed with no error to read. `Read-GitFile` runs
    # `git show` and treats failure as "absent" - correct, deliberate, and it leaves
    # $LASTEXITCODE at 128. The range path then ends on cmdlets, nothing resets it,
    # and GitHub appends `exit $LASTEXITCODE`. It fires exactly when the governing
    # contract is absent at the range base, which is the FIRST push of every new
    # Change Request. The report is asserted alongside the code, because a guard that
    # exits 0 while reporting a failure would be the same defect facing the other way.
    Reset-Fixture;Pre-Range
    # SPEC-202: origination must begin at Draft after the activation boundary, so the
    # contract is committed as a Draft first. What this case asserts - a Gate that reports
    # success exits 0 for a contract NEW TO THE RANGE - is unchanged.
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Draft -Scope $rangeScope);Commit born-draft
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope $rangeScope);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit born-first-push
    $r=RunRange 'HEAD~2'
    Assert '114 a Gate that reports success exits 0, even when the contract is new to the range' ($r.Code-eq0-and$r.Text-match'ORVION: READY'-and$r.Text-match'CR: SPEC-901'-and$r.Text-notmatch'BLOCKED') $r.Text

    # ---- A range hides nothing behind a later revert (SPEC-167) ----
    # `SPEC-162` and `SPEC-165` established that a range is a SEQUENCE of committed
    # transitions, and applied it to Status alone. Everything else still judged the
    # two ENDPOINTS, because `Diff-Records` computes a net `BaseRef..HeadRef` diff.
    # A commit that violates an invariant and a later commit that undoes it therefore
    # cancel out, and the violation reaches `main` having been committed and never
    # seen. The invariants below are HISTORY-SENSITIVE: they forbid a state from ever
    # having been committed, not merely from surviving to HEAD. This is deliberately
    # NOT generalised into "every intermediate commit must independently be
    # releasable" - a work-in-progress commit is legal, and only these four classes
    # are defined as forbidden to have occurred.
    function Unput([string]$Rel){Remove-Item -LiteralPath (Join-Path $root $Rel) -Force -ErrorAction SilentlyContinue}

    # F. An out-of-scope write is forbidden to COMMIT, not merely forbidden at HEAD.
    Reset-Fixture
    Put 'allowed.txt' 'in-scope edit';Put 'outside.txt' 'transient violation';Commit transient-write
    Unput 'outside.txt';Commit transient-restore
    $r=RunRange 'HEAD~2'
    Assert '115 an out-of-scope write reverted later in the same range is still rejected' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:outside\.txt') $r.Text

    # G. Widening Write Scope and restoring it is net-identical, so the endpoint
    # comparison saw nothing - and the writes the widened scope authorised were
    # invisible for the very same reason. Frozen authority is checked per commit
    # BEFORE scope, so the cause is reported rather than its consequence.
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Scope 'allowed.txt;secret.txt');Put 'secret.txt' 'written under widened scope';Commit scope-widened
    Put 'changes/SPEC-900-fixture.md' (ContractText -Scope 'allowed.txt');Unput 'secret.txt';Commit scope-restored
    $r=RunRange 'HEAD~2'
    Assert '116 a Write Scope widened and restored inside one range is still rejected' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED:Write Scope') $r.Text

    # A non-governing contract must ALREADY EXIST at the range base for these cases to
    # measure what they claim. Naming a brand-new contract in the governing Write Scope
    # puts its identifier into the baseline text, and collision validation then rejects
    # the range as SPEC_ID_ALREADY_USED - a real and deliberate rule (CR_LIFECYCLE.md
    # §4) that would make every assertion below pass without the history check ever
    # running. `Second` therefore commits the contract and the scope that names it into
    # the BASE, so the range itself carries only the transitions under test.
    function Second([string]$Status){
        Rebase (ContractText -Id SPEC-902 -Status $Status) 'changes/SPEC-902-other.md'
        Rebase (ContractText -Scope 'allowed.txt;changes/SPEC-902-other.md')
    }

    # D. A valid corrective Change Request must never launder an invalid earlier one.
    # `Status-Path` was walked for the RESOLVED GOVERNING contract only, so a second
    # contract's illegal lifecycle was never judged at all.
    Reset-Fixture;Second Draft
    Put 'changes/SPEC-902-other.md' (ContractText -Id SPEC-902 -Status Approved);Commit other-approved
    Put 'changes/SPEC-902-other.md' (ContractText -Id SPEC-902 -Status Complete -Resume DONE -Closeable);Commit other-complete
    $r=RunRange 'HEAD~2'
    Assert '117 an illegal transition in a NON-governing contract is rejected' ($r.Code-ne0-and$r.Text-match'ILLEGAL_STATUS_TRANSITION:Approved->Complete') $r.Text

    # E. Terminality was read at the range BASE only, so a contract that became
    # terminal INSIDE the range was not yet historical and could still be edited.
    Reset-Fixture;Second 'In Progress'
    Put 'changes/SPEC-902-other.md' (ContractText -Id SPEC-902 -Status Complete -Resume DONE -Closeable);Commit other-closed
    Put 'changes/SPEC-902-other.md' (ContractText -Id SPEC-902 -Status Complete -Resume DONE -Closeable -Log 'MUTATED AFTER TERMINAL');Commit other-mutated
    $r=RunRange 'HEAD~2'
    Assert '118 a contract that became terminal inside the range cannot be modified later in it' ($r.Code-ne0-and$r.Text-match'HISTORICAL_CR_MUTATION:changes/SPEC-902-other\.md') $r.Text

    # H. Reopening a terminal contract, then CLOSING IT AGAIN before the range ends.
    # Leaving it reopened at HEAD is already rejected, but by ORPHANED_APPROVED_CR - a
    # FINAL-STATE mechanism, because a non-governing contract left executable is always
    # an orphan. Asserting that shape would measure the pointer invariant and claim
    # credit for terminality. Re-closing it removes the orphan, so what remains is only
    # the forbidden intermediate state, and the assertion names a code rather than
    # trusting a bare non-zero exit.
    Reset-Fixture;Second 'In Progress'
    Put 'changes/SPEC-902-other.md' (ContractText -Id SPEC-902 -Status Complete -Resume DONE -Closeable);Commit reopen-closed
    Put 'changes/SPEC-902-other.md' (ContractText -Id SPEC-902 -Status 'In Progress');Commit reopen-reopened
    Put 'changes/SPEC-902-other.md' (ContractText -Id SPEC-902 -Status Complete -Resume DONE -Closeable);Commit reopen-reclosed
    $r=RunRange 'HEAD~3'
    Assert '119 a terminal contract reopened and re-closed inside one range is rejected' ($r.Code-ne0-and$r.Text-match'HISTORICAL_CR_MUTATION|ILLEGAL_STATUS_TRANSITION:Complete->In Progress') $r.Text

    # MUST-ACCEPT. The over-strictness this repair could introduce is rejecting a
    # legal history. Cases 83 and 111 already pin the plain lifecycles; what is new
    # here is a contract BORN in the range - which has no text at the base and whose
    # frozen baseline must therefore fall back to its first appearance - while writing
    # several in-scope files across several commits. Getting the fallback wrong
    # re-breaks `SPEC-165`, so it is asserted rather than assumed.
    Reset-Fixture;Pre-Range
    $bornScope='_ORVION_CANONICAL/manifest.md;allowed.txt;context.txt'
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Draft -Scope $bornScope);Commit born-draft
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope $bornScope);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit born-a
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status 'In Progress' -Scope $bornScope);Put 'allowed.txt' 'step one';Commit born-b
    Put 'context.txt' 'step two';Commit born-c
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Complete -Resume DONE -Scope $bornScope -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit born-d
    $r=RunRange 'HEAD~5'
    Assert '120 MUST-ACCEPT: a contract born in range writing in-scope files across commits is legal' ($r.Code-eq0-and$r.Text-match'MODE: VERIFY') $r.Text

    # ---- A workflow is expected only on branches it can actually run on (SPEC-168) ----
    # `Workflow-Expectations` derives the EXPECTED set from the `push:` triggers the
    # workflow files declare, and treated every list item under `push:` as a PATH glob.
    # A `branches:` filter therefore either vanished (flow style produces no bullets, so
    # the workflow read as unfiltered and was expected on every push) or was compared
    # against written file paths as though a branch name were one - which happens to
    # yield the right answer only because branch names rarely look like paths.
    # `-Certify` fails closed on a required workflow that produced no run, so the flow
    # case would have failed every future push on a workflow that can never run there.
    Reset-Fixture;Rebase (ContractText -Resume DONE -Scope 'allowed.txt');$null=Run Finish;$j=ReceiptJson;$exp=@($j.expected)
    $ev=($j|ConvertTo-Json -Depth 5)
    Assert '121 a flow-style branches filter naming another branch is not expected' ($exp-notcontains'Branch Other Flow') $ev
    Assert '122 a block-style branches filter naming another branch is not expected' ($exp-notcontains'Branch Other Block') $ev
    Assert '123 MUST-ACCEPT: a branches filter naming the checked-out branch is expected' ($exp-contains'Branch Main') $ev
    Assert '124 a matching branches filter with a non-matching paths filter is not expected' ($exp-notcontains'Branch Main Paths') $ev
    Assert '125 MUST-ACCEPT: unfiltered and path-filtered derivation is unchanged' (($exp-contains'Always')-and($exp-notcontains'Docs')-and($exp-notcontains'Review Only')) $ev

    # ---- Cancelled is a terminal state the control plane can EXECUTE (SPEC-170) ----
    # `CR_LIFECYCLE.md` §4 and `$script:LegalTransitions` both permit Draft/Approved/
    # In Progress -> Cancelled, but `Resolve-Contract` accepted only `Complete` as a
    # terminal GOVERNING status. Cancelling forces the manifest pointer to be cleared
    # (a manifest naming a Cancelled contract is MANIFEST_CR_CONTRADICTION), which then
    # left no governing contract at all, so control fell to the PLAN arm - which rejects
    # the manifest.md and ai-map.json a cancellation must write. The authority permitted
    # a transition the mechanism refused, and the only escapes a weaker agent can see are
    # --no-verify and rewriting history, both forbidden by AGENTS.md §1.
    # Closing a contract WRITES the manifest pointer, so a contract that closes itself
    # must declare `_ORVION_CANONICAL/manifest.md` in its own Write Scope - exactly as
    # the completion fixtures above already do. That requirement is deliberate and is
    # not relaxed for cancellation: the manifest carries Current Phase, Live state and
    # much more than the pointer, so an implicit closure-time write permission would
    # let any contract silently rewrite all of it.
    Reset-Fixture;Rebase (ContractText -Status Approved -Scope $rangeScope)
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Cancelled -Scope $rangeScope);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.')
    $r=Run Gate
    Assert '126 MUST-ACCEPT: an Approved contract can be cancelled with the pointer cleared' ($r.Code-eq0-and$r.Text-notmatch'NO_GOVERNING_CR') $r.Text

    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $rangeScope);Commit cancel-approved
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Cancelled -Scope $rangeScope);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit cancel-done
    $r=RunRange 'HEAD~1'
    Assert '127 MUST-ACCEPT: the same cancellation is legal as a committed range' ($r.Code-eq0-and$r.Text-notmatch'NO_GOVERNING_CR') $r.Text

    # Terminal means terminal in BOTH directions: a closed contract is not cancellable.
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit closed-first
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Cancelled);Commit then-cancelled
    $r=RunRange 'HEAD~1'
    Assert '128 a Complete contract cannot later be Cancelled' ($r.Code-ne0-and$r.Text-match'HISTORICAL_CR_MUTATION|ILLEGAL_STATUS_TRANSITION') $r.Text

    # A CANCELLATION IS NOT A GOVERNING ACT (SPEC-171). This case originally asserted
    # ambiguity, and that expectation was wrong: cancelling a contract requires carrying
    # it inside ANOTHER contract's Write Scope, so "one Complete plus one Cancelled" is
    # the ordinary shape of every cancellation - the shape SPEC-170's own push produced,
    # which then failed on main as AMBIGUOUS_GOVERNING_CR. The abandoned contract held
    # no write authority over anything in the range; the completed one authorised every
    # file, including the cancelled contract's own. The test agreed with the code
    # because both came from one unexamined conclusion, which is exactly how a green
    # suite certifies a broken rule.
    # Write Scope is frozen against the range BASE, so the governing contract must
    # already carry this scope at the baseline commit - it names the second contract's
    # file because closing that contract is a write like any other.
    $twoScope='_ORVION_CANONICAL/manifest.md;changes/SPEC-899-other.md'
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Scope $twoScope)
    Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899);Commit add-second-terminal
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope $twoScope -Closeable)
    Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899 -Status Cancelled)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit two-terminal
    $r=RunRange 'HEAD~1'
    Assert '129 MUST-ACCEPT: one Complete and one Cancelled resolves to the Complete one' ($r.Code-eq0-and$r.Text-match'CR: SPEC-900'-and$r.Text-notmatch'AMBIGUOUS_GOVERNING_CR') $r.Text

    # Regression: Complete keeps the STRICTER rule and must not inherit the Cancelled path.
    Reset-Fixture;Pre-Range
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope $rangeScope);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit strict-approved
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Complete -Resume DONE -Scope $rangeScope -Closeable);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit strict-complete
    $r=RunRange 'HEAD~2'
    Assert '130 Complete still requires In Progress immediately before it' ($r.Code-ne0-and$r.Text-match'INVALID_COMPLETION_TRANSITION|ILLEGAL_STATUS_TRANSITION') $r.Text

    # The preference must not swallow GENUINE ambiguity. Two contracts that both claim
    # to have done the work is unresolvable, and so is two that both abandoned it -
    # neither case names a single authority whose Write Scope governed the range.
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Scope $twoScope)
    Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899);Commit add-two-complete
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope $twoScope -Closeable)
    Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899 -Status Complete -Resume DONE -Closeable)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit both-complete
    $r=RunRange 'HEAD~1'
    Assert '131 two Complete contracts are still ambiguous' ($r.Code-ne0-and$r.Text-match'AMBIGUOUS_GOVERNING_CR') $r.Text

    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Scope $twoScope)
    Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899);Commit add-two-cancelled
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Cancelled -Scope $twoScope)
    Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899 -Status Cancelled)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit both-cancelled
    $r=RunRange 'HEAD~1'
    Assert '132 two Cancelled contracts are ambiguous' ($r.Code-ne0-and$r.Text-match'AMBIGUOUS_GOVERNING_CR') $r.Text

    # THE LOAD-BEARING SAFETY PROPERTY, not the SPEC-169/SPEC-170 example. Preferring
    # the Complete contract is only safe because Write Scope still comes from the
    # RESOLVED contract alone. Here the cancelled contract names `secret.txt` and the
    # completed one does not: if the preference ever leaked the loser's authority, or
    # if a future reader "simplified" it into taking whichever contract is convenient,
    # that write would be admitted. An abandoned contract authorises nothing.
    Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Scope $twoScope)
    Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899 -Scope 'secret.txt');Commit add-scoped-cancel
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Complete -Resume DONE -Scope $twoScope -Closeable)
    Put 'changes/SPEC-899-other.md' (ContractText -Id SPEC-899 -Status Cancelled -Scope 'secret.txt')
    Put 'secret.txt' 'written under the cancelled contract scope'
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit leak-attempt
    $r=RunRange 'HEAD~1'
    Assert '133 a cancelled contract confers no write authority on the range' ($r.Code-ne0-and$r.Text-match'OUT_OF_SCOPE_WRITE:secret\.txt') $r.Text

    # ---- STRUCTURAL: the acceptance boundary carries the evidence it replaces (SPEC-172) ----
    # Read from the repository, not the sandbox: these are properties of the real
    # admission workflow. Both were measured FALSE on the workflow as shipped, which is
    # the only reason they are asserted - `orvion-acceptance` is the single external
    # check a Ruleset will require, and nothing noticed that its cleanup installed an
    # unpinned CLI or that it ran none of the guard calibration.
    #
    # Comment lines are stripped first, deliberately: every word forbidden below also
    # appears in the workflow's own commentary explaining why it must not appear in a
    # command, and an assertion that cannot tell a prohibition from its explanation
    # would fire on the document that records it.
    $acceptRaw=Get-Content -Raw (Join-Path $sourceRoot '.github/workflows/orvion-acceptance.yml')
    $accept=(@($acceptRaw-split'\r?\n')|?{$_-notmatch'^\s*#'})-join"`n"
    # `npm ci` is the one installation authority. `npx` resolves from the network when
    # `node_modules` has no match, and `setup-cli` would be a second version authority
    # that can silently disagree with the lockfile developers actually run.
    Assert '141 STRUCTURAL: the acceptance workflow resolves no package from the network' (($accept-notmatch'\bnpx\b')-and($accept-notmatch'setup-cli')) $accept
    # Guard-of-the-guard evidence, not a second run of the guard the Gate already
    # invokes. The per-suite exit check matters as much as the suites: `shell: pwsh`
    # gates a step on its LAST command, so four bare calls would let a failing first
    # suite pass silently.
    $suites=@('test_future_date_guard','test_status_contradiction_guard','test_primary_ledger_guard','test_cold_start_state_guard')
    Assert '142 STRUCTURAL: acceptance runs every guard-calibration suite with its own exit check' ((@($suites|?{$accept-match([regex]::Escape($_))}).Count-eq4)-and($accept-match'LASTEXITCODE')) $accept
    # The step that runs after everything else has already failed is the one that
    # reached for the network, so it is asserted on its own rather than inferred from
    # the file-wide rule above.
    $cleanup=[regex]::Match($accept,'(?ms)^      - name: Stop local Supabase stack\r?\n(?<b>.*?)(?=\r?\n      - name:|\z)')
    $cb=$cleanup.Groups['b'].Value
    Assert '143 STRUCTURAL: the always-run cleanup invokes only a CLI the lockfile installed' ($cleanup.Success-and$cb-match'if:\s*always\(\)'-and$cb-match'-x\s+node_modules/\.bin/supabase'-and$cb-notmatch'\bnpx\b') $cleanup.Value

    # ---- STRUCTURAL: the required admission boundary cannot be bypassed (SPEC-173) ----
    # These properties all hold today. They are asserted because they become load-bearing
    # the moment a Ruleset makes `orvion-acceptance` required: from then on, a skipped or
    # duplicated admission job is indistinguishable from a passed one to the Ruleset, and
    # the failure is silent. Each is parsed from job STRUCTURE rather than grepped for a
    # token, because the cleanup step's `if: always()` is legitimate and a crude ban on
    # the word `if:` would forbid it while proving nothing about job-level bypass.
    # NEWLINE INVARIANCE (SPEC-177). This is the file's ONE workflow-structure parsing
    # authority, and normalizing CRLF to LF is the first thing it does. That single line is
    # the whole newline policy. The structural matchers below are line-anchored and end
    # `[ \t]*$`, which cannot consume a `\r`: under a CRLF checkout every job header missed,
    # this list came back EMPTY, and 150/152/153/155 failed together while the workflow they
    # guard was entirely correct. Proven by A/B at one SHA with line endings as the only
    # variable -- the six workflow files normalized to identical SHA256, nothing else
    # differed, and the suite went 155/0 on LF versus 151/4 on CRLF.
    #
    # The fix is HERE and not a `\r?` added to each regex, because per-regex newline policy
    # is an omission surface rather than a rule: the `jobs:` matcher below already carried
    # `\r?\n` and its immediate neighbours did not, and that asymmetry IS the defect. One
    # boundary cannot be half-applied.
    function Get-WorkflowEmitters($Sources){
        $found=@()
        foreach($s in $Sources){
            $txt=$s.Text.Replace("`r`n","`n")
            $jobsBlock=[regex]::Match($txt,'(?ms)^jobs:[ \t]*\r?\n(?<b>.*)$')
            if(!$jobsBlock.Success){continue}
            $body=$jobsBlock.Groups['b'].Value
            foreach($jm in [regex]::Matches($body,'(?m)^  (?<id>[A-Za-z0-9_-]+):[ \t]*$')){
                $rest=$body.Substring($jm.Index+$jm.Length)
                $end=[regex]::Match($rest,'(?m)^  [A-Za-z0-9_-]+:[ \t]*$')
                $jobBody=if($end.Success){$rest.Substring(0,$end.Index)}else{$rest}
                $dn=[regex]::Match($jobBody,'(?m)^    name:[ \t]*(?<v>.+?)[ \t]*$')
                $ctx=if($dn.Success){$dn.Groups['v'].Value}else{$jm.Groups['id'].Value}
                $found+=[pscustomobject]@{File=$s.Name;Job=$jm.Groups['id'].Value;Context=$ctx;Body=$jobBody}
            }
        }
        $found
    }
    # One job's steps, split on the step bullet at the job's step indentation. Inside a chunk the
    # bullet's own first key sits at column 0 and every sibling key at eight spaces, so `^name:`
    # can only be the step's name and `^        if:` can only be a step-level condition - the same
    # "job-level keys only" discipline assertion 152 uses one level up. ONE splitter, called for
    # every job examined (SPEC-185): two copies would be two parsers that can disagree.
    function Get-JobSteps([string]$Body){
        $steps=@()
        foreach($chunk in @($Body-split'(?m)^      - '|Select-Object -Skip 1)){
            $nm=[regex]::Match($chunk,'(?m)^name:[ \t]*(?<v>.+?)[ \t]*$')
            $cond=[regex]::Match($chunk,'(?m)^        if:[ \t]*(?<v>.+?)[ \t]*$')
            $steps+=[pscustomobject]@{
                Name=$(if($nm.Success){$nm.Groups['v'].Value}else{''})
                If=$(if($cond.Success){$cond.Groups['v'].Value}else{$null})}
        }
        ,$steps
    }
    # BOTH representations are DERIVED, in memory, from one canonical form of the same file.
    # Reading the checkout twice would prove nothing: on a machine that checks out CRLF both
    # arms would be CRLF, and on GitHub's LF runners both would be LF, so the proof would
    # only ever exercise whatever `core.autocrlf` happened to produce. Deriving them means
    # the CRLF arm is genuinely CRLF even on an LF runner, which is where a regression in the
    # normalization above has to be caught. This canonicalization is fixture construction;
    # the one inside the parser is the parsing-time policy.
    $wfDir=Join-Path $sourceRoot '.github/workflows'
    $wfLf=@();$wfCrlf=@()
    foreach($wf in @(Get-ChildItem -LiteralPath $wfDir -File|Where-Object{$_.Extension-in @('.yml','.yaml')})){
        $canon=[IO.File]::ReadAllText($wf.FullName).Replace("`r`n","`n")
        $wfLf+=[pscustomobject]@{Name=$wf.Name;Text=$canon}
        $wfCrlf+=[pscustomobject]@{Name=$wf.Name;Text=$canon.Replace("`n","`r`n")}
    }
    $reps=@()
    foreach($rep in @([pscustomobject]@{Name='LF';Src=$wfLf},[pscustomobject]@{Name='CRLF';Src=$wfCrlf})){
        $em=@(Get-WorkflowEmitters $rep.Src)
        $ad=@($em|Where-Object{$_.Context-eq'orvion-acceptance'})
        $bd=if($ad.Count-eq1){$ad[0].Body}else{''}
        # The Agent Control gate job, from the SAME emitter pass (SPEC-182). Selected by file
        # and job id rather than by `Context`, because that job declares no `name:` and the
        # parser's documented fallback is the job id - matching on the fallback keeps this
        # working if a display name is ever added, and adding one would not silently unguard it.
        $ac=@($em|Where-Object{$_.File-eq'agent-control.yml'-and$_.Job-eq'gate'})
        $acBody=if($ac.Count-eq1){$ac[0].Body}else{''}
        $acSteps=Get-JobSteps $acBody
        # The same pass, for the consistency job (SPEC-185). ONE emitter is required of that file:
        # a second job there could carry the calibration unconditionally and this would not notice.
        $rc=@($em|Where-Object{$_.File-eq'repository-consistency.yml'})
        $rcBody=if($rc.Count-eq1){$rc[0].Body}else{''}
        $rcSteps=Get-JobSteps $rcBody
        $reps+=[pscustomobject]@{Rep=$rep.Name;Emitters=$em;Admission=$ad;Body=$bd;Tmo=[regex]::Matches($bd,'(?m)^    timeout-minutes:[ \t]*(?<m>\d+)[ \t]*$')
                                 Gate=$ac;GateBody=$acBody;GateSteps=$acSteps
                                 Rc=$rc;RcBody=$rcBody;RcSteps=$rcSteps}
    }
    # Binding the Ruleset to the GitHub Actions App stops another PROVIDER satisfying the
    # context; it does nothing about a second Actions job claiming the same name. Only
    # this assertion covers that.
    # Required of BOTH representations (SPEC-177): the same YAML must yield the same one
    # admission job whether the checkout materialized it as LF or CRLF.
    Assert '150 STRUCTURAL: exactly one active job in the repository can emit orvion-acceptance' (@($reps|Where-Object{$_.Admission.Count-ne1}).Count-eq0) (($reps|ForEach-Object{"[$($_.Rep)] "+(($_.Emitters|ForEach-Object{"$($_.File):$($_.Job) -> $($_.Context)"})-join'; ')})-join' || ')
    # A path-filtered required check produces NO run for a non-matching push, and a
    # required check that never runs is a permanently pending admission.
    $acceptOn=[regex]::Match($acceptRaw,'(?ms)^on:[ \t]*\r?\n(?<b>(?:[ \t]+.*\r?\n|[ \t]*\r?\n)*)')
    Assert '151 STRUCTURAL: the required acceptance workflow has no trigger path filter' ($acceptOn.Success-and$acceptOn.Groups['b'].Value-notmatch'(?m)^\s*paths(-ignore)?:') $acceptOn.Value
    # Job-level keys only: `^    key:` are the job's own, everything deeper belongs to a
    # step. A job-level `if:` can skip the whole admission, and GitHub reports a skipped
    # required job in a way that does not block - which is the entire attack.
    Assert '152 STRUCTURAL: the admission job carries no job-level condition and no continue-on-error' (@($reps|Where-Object{-not($_.Body-and$_.Body-notmatch'(?m)^    if:'-and$_.Body-notmatch'(?m)^    continue-on-error:'-and$_.Body-match'(?m)^    steps:')}).Count-eq0) (($reps|ForEach-Object{"[$($_.Rep)] $($_.Body)"})-join' || ')
    # The environment the first full shadow proof executed, not a moving description of
    # it. `ubuntu-latest` migrates OS generation and a tag can be repointed.
    Assert '153 STRUCTURAL: the admission boundary is frozen at the proven runner and checkout commit' ((@($reps|Where-Object{$_.Body-notmatch'(?m)^    runs-on:[ \t]*ubuntu-24\.04[ \t]*$'}).Count-eq0)-and$acceptRaw-match'uses:[ \t]*actions/checkout@[0-9a-f]{40}') (($reps|ForEach-Object{"[$($_.Rep)] $($_.Body)"})-join' || ')
    # A required check that never concludes blocks every promotion, and GitHub's default
    # job timeout is 360 minutes, which is not a bound. This pins the EXACT approved value
    # rather than a range, because a range refuses only one failure direction: a weaker
    # agent setting 5 minutes would keep this suite GREEN while making every healthy
    # candidate unadmittable, and that direction is invisible to a test even though a human
    # would notice it. 30 is the current repository contract, not an architectural constant
    # - retuning it is a future evidence-backed Change Request that moves the workflow value
    # and this expectation together, which is controlled evolution rather than fossilization.
    # Job-level like 152: `^    key:` is the job's own and anything deeper belongs to a step,
    # so a step-level timeout leaves the JOB unbounded. The keys are COUNTED rather than
    # matched once, so a second contradicting job-level key is refused too.
    Assert '155 STRUCTURAL: the required admission job declares exactly one job-level timeout, at the approved 30' (@($reps|Where-Object{$_.Tmo.Count-ne1-or[int]$_.Tmo[0].Groups['m'].Value-ne30}).Count-eq0) (($reps|ForEach-Object{"[$($_.Rep)] job-level timeout-minutes keys=$($_.Tmo.Count) value(s)=$(if($_.Tmo.Count){(@($_.Tmo|ForEach-Object{$_.Groups['m'].Value})-join',')}else{'<none at job level>'})"})-join' || ')

    # ---- STRUCTURAL: on preflight ONLY the duplicate deterministic step is skipped (SPEC-182) ----
    # `ORVION Acceptance` runs this same argument-free mutation suite on the same candidate SHA, so
    # its second execution there reads identical inputs and can only reach an identical verdict.
    # What is NOT duplicate is the Gate standing beside it: that resolves
    # `github.event.before -> github.sha`, a push-range question Acceptance never asks, and the two
    # contexts can legitimately disagree. So the condition belongs to exactly one step, and both
    # halves of that sentence need a detector - nothing else in this repository parses
    # `agent-control.yml` at all, and assertion 152 covers the ADMISSION job only.
    #
    # The literal is pinned rather than merely required to be present. `github.ref` is
    # `refs/pull/N/merge` on a pull request and `refs/tags/...` on a tag, so a typo here keeps a
    # condition that still reads as deliberate while silently removing Gate coverage from `main`.
    $mutName='Run Agent Control mutation suite';$gateName='Enforce governing Change Request'
    # SPEC-185 extends this to `main`: a commit cannot reach `main` without a successful
    # `orvion-acceptance` run on that exact SHA, and that workflow runs this same suite. Both
    # halves are `refs/heads/` literals, which is what keeps pull requests covered - their
    # `github.ref` is `refs/pull/N/merge` and matches neither.
    $preflightIf='${{ github.ref != ''refs/heads/orvion-preflight'' && github.ref != ''refs/heads/main'' }}'
    Assert '162 STRUCTURAL: the preflight skip sits on the mutation-suite step and names exactly that ref' (@($reps|Where-Object{
        $m=@($_.GateSteps|Where-Object{$_.Name-eq$mutName})
        -not($_.Gate.Count-eq1-and$m.Count-eq1-and$m[0].If-eq$preflightIf)}).Count-eq0) (($reps|ForEach-Object{$r=$_;$m=@($r.GateSteps|Where-Object{$_.Name-eq$mutName});"[$($r.Rep)] gate jobs=$($r.Gate.Count) mutation steps=$($m.Count) if=$(if($m.Count-eq1-and$null-ne$m[0].If){$m[0].If}else{'<none>'})"})-join' || ')
    # The containment half. A job-level condition would take the Gate down with the suite and GitHub
    # reports a skipped job in a way that does not read as a failure; `continue-on-error` would let
    # the Gate fail without failing the job. Job-level keys are `^    key:` and anything deeper
    # belongs to a step, exactly as 152 reads them. Counting CONDITIONED steps rather than checking
    # the Gate step alone is what makes this survive a future third step: the invariant is that one
    # step is suppressible, not merely that today's Gate happens not to be.
    Assert '163 STRUCTURAL: nothing else in the Agent Control job can be suppressed by that condition' (@($reps|Where-Object{
        $g=@($_.GateSteps|Where-Object{$_.Name-eq$gateName})
        $c=@($_.GateSteps|Where-Object{$null-ne$_.If})
        -not($_.Gate.Count-eq1-and$_.GateBody-notmatch'(?m)^    if:'-and$_.GateBody-notmatch'(?m)^    continue-on-error:'-and$g.Count-eq1-and$c.Count-eq1-and$c[0].Name-eq$mutName)}).Count-eq0) (($reps|ForEach-Object{$r=$_;$c=@($r.GateSteps|Where-Object{$null-ne$_.If});"[$($r.Rep)] job-level if=$([bool]($r.GateBody-match'(?m)^    if:')) continue-on-error=$([bool]($r.GateBody-match'(?m)^    continue-on-error:')) conditioned=$(if($c.Count){(@($c|ForEach-Object{$_.Name})-join',')}else{'<none>'}) steps=$(@($r.GateSteps|ForEach-Object{$_.Name})-join'|')"})-join' || ')

    # ---- STRUCTURAL: calibration is suppressed on main ONLY, and the guard never is (SPEC-185) ----
    # A commit cannot reach `main` without a successful `orvion-acceptance` run on that exact SHA -
    # ruleset 22950574, active on the default branch, empty bypass list, `do_not_enforce_on_create:
    # false` - and that workflow runs these same four suites, which assertion 142 fixes. So on a
    # `main` push this calibration is a repeat of admitted evidence and nothing else.
    #
    # The single `refs/heads/main` literal is what keeps pull requests covered: their `github.ref`
    # is `refs/pull/N/merge` and cannot match it. Pinning the literal rather than merely requiring
    # a condition is the point - a condition that looks deliberate and names the wrong ref would
    # silently stop calibrating the events that still need it.
    $calName='Attack the guards themselves';$guardName='Run repository consistency guard'
    $mainIf='${{ github.ref != ''refs/heads/main'' }}'
    Assert '167 STRUCTURAL: guard calibration is skipped on main only and the consistency guard never is' (@($reps|Where-Object{
        $cal=@($_.RcSteps|Where-Object{$_.Name-eq$calName})
        $grd=@($_.RcSteps|Where-Object{$_.Name-eq$guardName})
        $c=@($_.RcSteps|Where-Object{$null-ne$_.If})
        -not($_.Rc.Count-eq1-and$_.RcBody-notmatch'(?m)^    if:'-and$_.RcBody-notmatch'(?m)^    continue-on-error:'-and$cal.Count-eq1-and$cal[0].If-eq$mainIf-and$grd.Count-eq1-and$null-eq$grd[0].If-and$c.Count-eq1)}).Count-eq0) (($reps|ForEach-Object{$r=$_;$cal=@($r.RcSteps|Where-Object{$_.Name-eq$calName});$c=@($r.RcSteps|Where-Object{$null-ne$_.If});"[$($r.Rep)] jobs=$($r.Rc.Count) job-level if=$([bool]($r.RcBody-match'(?m)^    if:')) calibration if=$(if($cal.Count-eq1-and$null-ne$cal[0].If){$cal[0].If}else{'<none>'}) conditioned=$(if($c.Count){(@($c|ForEach-Object{$_.Name})-join',')}else{'<none>'}) steps=$(@($r.RcSteps|ForEach-Object{$_.Name})-join'|')"})-join' || ')

    # The QUERY is asserted separately from the revalidation, because the two are
    # redundant for correctness and therefore cannot catch each other's removal: with
    # revalidation in place, deleting `--branch` still yields the right verdict, just from
    # a wider result set. What the filters actually buy is a bounded, relevant result set —
    # and `--limit` only bounds honestly if the query is narrow, so a SHA that accumulates
    # runs cannot push required evidence out of the window and read as MISSING. Nothing
    # else in this suite would notice if the query silently widened.
    Reset-Fixture;$sha=(git -C $root rev-parse HEAD).Trim();ExpectBoth
    Remove-Item -LiteralPath $ghLog -Force -ErrorAction SilentlyContinue
    GhRuns @((Run1 'Agent Control'),(Run1 'Repository Consistency')) $sha;$null=RunCertify
    $q=StubGhLog
    Assert '154 remote certification asks GitHub for the exact SHA on the target branch by push, bounded' ($q-match"--commit $sha"-and$q-match'--branch main'-and$q-match'--event push'-and$q-match'--limit \d+') $q

    # ---- PUBLISH: candidate publication proves its range and fails closed (SPEC-184) ----
    # Behavioural, against the sandbox bare repository: each case asserts on the REMOTE'S REAL
    # REF after running the publisher, never on the command string it assembled. A string
    # assertion would pass for a lease that is correctly spelled and still vacuous, which is
    # precisely the defect 166 exists to catch.

    # 164. The failure that cost a lineage rebuild: a committed range no Write Scope authorises.
    # Local `-Finish` and a bare `-Gate` both judge the WORKING TREE, so the offending change is
    # COMMITTED here - a dirty tree would be refused one step earlier and prove nothing about
    # the Gate. The remote must be untouched, not merely the exit code non-zero.
    Reset-Fixture;SetPreflight 'main';$before=PreflightSha
    Put 'secret.txt' 'out of scope';Commit 'out-of-scope-candidate'
    $r=RunPublish
    Assert '164 PUBLISH: a refused committed range publishes nothing and leaves the remote untouched' ($r.Code-ne0-and$r.Text-match'RANGE_GATE_FAILED'-and$r.Text-notmatch'PUBLISHED:'-and(PreflightSha)-eq$before-and$before) "$($r.Text)`nbefore=$before after=$(PreflightSha)"

    # 165. The control for 166. Without it, 166 could pass merely because the publisher never
    # pushes at all - a script that always refuses would satisfy every negative case in this file.
    # Preflight is deliberately DIVERGENT from the candidate, which is the rejected-candidate
    # shape: a plain push cannot fast-forward onto it, so only the lease path can succeed.
    Reset-Fixture;Put 'allowed.txt' 'rejected candidate';Commit 'rejected';SetPreflight 'HEAD'
    $rejected=PreflightSha
    Reset-Fixture;Put 'allowed.txt' 'replacement candidate';Commit 'replacement'
    $candidate=(git -C $root rev-parse HEAD).Trim()
    $r=RunPublish @('-ReplaceExpectedSha',$rejected)
    Assert '165 PUBLISH: a replacement pinned to the correct expected SHA succeeds' ($r.Code-eq0-and$r.Text-match'PUBLISH: DONE'-and(PreflightSha)-eq$candidate-and$rejected-ne$candidate) "$($r.Text)`nrejected=$rejected candidate=$candidate after=$(PreflightSha)"

    # 166. THE differentiator against a bare `--force-with-lease`. The tracking ref is refreshed
    # before the run AND the publisher fetches again itself, so at push time
    # `refs/remotes/origin/orvion-preflight` is exactly what the remote holds - the state in which
    # a valueless lease compares the remote against itself, refuses nothing, and overwrites. Only
    # an expectation supplied by the CALLER can still be wrong, and being wrong must stop the push.
    Reset-Fixture;Put 'allowed.txt' 'rejected candidate 2';Commit 'rejected-2';SetPreflight 'HEAD'
    $rejected=PreflightSha
    Reset-Fixture;Put 'allowed.txt' 'replacement candidate 2';Commit 'replacement-2'
    git -C $root fetch origin --quiet 2>$null
    $wrong=(git -C $root rev-parse refs/remotes/origin/main).Trim()
    $r=RunPublish @('-ReplaceExpectedSha',$wrong)
    Assert '166 PUBLISH: a replacement pinned to the WRONG expected SHA is refused and the remote is unchanged' ($r.Code-ne0-and$r.Text-match'LEASE_PUSH_REFUSED'-and$r.Text-notmatch'PUBLISHED:'-and(PreflightSha)-eq$rejected-and$wrong-ne$rejected) "$($r.Text)`nwrong=$wrong rejected=$rejected after=$(PreflightSha)"
    # ---- APPROVAL EVIDENCE + SPEC ALLOCATION (SPEC-196) ----
    # Approval freezes authority, so sufficiency is proven BEFORE the freeze. Every case
    # below drives a real Draft -> Approved transition through the Gate rather than
    # asserting on parsed text, and every negative is paired with the positive that
    # proves the refusal is discriminating rather than universal.

    # 167. APPROVAL-EVIDENCE D. A control-scope contract may not freeze with no consumer
    # closure at all. This is the reproduced D defect: the contract looks complete.
    $r=ApproveRun (EvidenceText -Consumer 'none')
    Assert '167 APPROVAL-EVIDENCE D: control-scope approval with no consumer rows is refused' ($r.Code-ne0-and$r.Text-match'APPROVAL_EVIDENCE') $r.Text
    Pop 'D' 'reject'

    # 168. APPROVAL-EVIDENCE D. `UNKNOWN` is not an answer; it is the absence of one.
    $r=ApproveRun (EvidenceText -Consumer 'unknown')
    Assert '168 APPROVAL-EVIDENCE D: an UNKNOWN disposition is INDETERMINATE, never a pass' ($r.Code-ne0-and$r.Text-match'INDETERMINATE') $r.Text
    Pop 'D' 'reject'

    # 169. APPROVAL-EVIDENCE D. A named unresolved material consumer blocks the freeze.
    $r=ApproveRun (EvidenceText -Consumer 'unresolved')
    Assert '169 APPROVAL-EVIDENCE D: a named unresolved material consumer blocks approval' ($r.Code-ne0-and$r.Text-match'APPROVAL_EVIDENCE') $r.Text
    Pop 'D' 'reject'

    # 170. APPROVAL-EVIDENCE D. The template's own placeholder text is not evidence.
    $r=ApproveRun (EvidenceText -Consumer 'placeholder')
    Assert '170 APPROVAL-EVIDENCE D: unfilled template placeholders are not evidence' ($r.Code-ne0-and$r.Text-match'APPROVAL_EVIDENCE') $r.Text
    Pop 'D' 'reject'

    # 171. APPROVAL-EVIDENCE D. Disposition vocabulary is closed.
    $r=ApproveRun (EvidenceText -Consumer 'baddisposition')
    Assert '171 APPROVAL-EVIDENCE D: a disposition outside WRITE/VERIFY/UNAFFECTED is refused' ($r.Code-ne0-and$r.Text-match'APPROVAL_EVIDENCE') $r.Text
    Pop 'D' 'reject'

    # 172. APPROVAL-EVIDENCE F SPEC-195. THE canonical negative: an invariant required green
    # at a mandatory gate that sits inside its own declared red window. SPEC-195 froze exactly
    # this shape - Step 10 opened the window, Step 13 closed it, and the Step 12 gate demanded
    # green in between - and the contract was approved and then cancelled because of it.
    $r=ApproveRun (EvidenceText -Boundary 'conflict')
    Assert '172 APPROVAL-EVIDENCE F SPEC-195: a gate inside an invariant red window is refused' ($r.Code-ne0-and$r.Text-match'APPROVAL_EVIDENCE') $r.Text
    Pop 'F' 'reject'

    # 173. APPROVAL-EVIDENCE F. A step reference that does not exist cannot be ordered.
    $r=ApproveRun (EvidenceText -Boundary 'badstep')
    Assert '173 APPROVAL-EVIDENCE F: an out-of-range step reference is INDETERMINATE' ($r.Code-ne0-and$r.Text-match'INDETERMINATE') $r.Text
    Pop 'F' 'reject'

    # 174. APPROVAL-EVIDENCE F. A red window that never closes is unsatisfiable by construction.
    $r=ApproveRun (EvidenceText -Boundary 'openended')
    Assert '174 APPROVAL-EVIDENCE F: an open-ended red window is refused' ($r.Code-ne0-and$r.Text-match'APPROVAL_EVIDENCE') $r.Text
    Pop 'F' 'reject'

    # 175. APPROVAL-EVIDENCE HJ. A permanent control may not freeze without its obligations.
    $r=ApproveRun (EvidenceText -HJ 'missing')
    Assert '175 APPROVAL-EVIDENCE HJ: missing permanent-control obligations block approval' ($r.Code-ne0-and$r.Text-match'APPROVAL_EVIDENCE') $r.Text
    Pop 'HJ' 'reject'

    # 176. APPROVAL-EVIDENCE HJ. Routine is descriptive input, never an exemption. A CONTROL
    # Write Scope makes the obligations applicable whatever the contract calls itself.
    $r=ApproveRun (EvidenceText -Class 'Routine' -Applicability 'selfexempt')
    Assert '176 APPROVAL-EVIDENCE HJ: a Routine label cannot self-exempt control work' ($r.Code-ne0-and$r.Text-match'INDETERMINATE') $r.Text
    Pop 'HJ' 'reject'

    # 177. POSITIVE control for 167-176. Without it every case above would pass against a
    # guard that simply refused all approvals, which is the vacuous-control shape H/J exists
    # to reject.
    $r=ApproveRun (EvidenceText)
    Assert '177 APPROVAL-EVIDENCE: complete applicable evidence is ADMITTED' ($r.Code-eq0-and$r.Text-match'APPROVAL_EVIDENCE: PASS') $r.Text
    Pop 'D;F;HJ' 'accept'

    # 178. POSITIVE. A contract whose Write Scope touches no control or governance surface
    # derives NOT APPLICABLE and needs no evidence section at all - backward compatibility
    # for every ordinary contract, and the reason this is not governance bloat.
    Reset-Fixture
    $plain='allowed.txt;_ORVION_CANONICAL/manifest.md'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $plain)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None')
    Commit 'plain-draft'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $plain)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    $r=Run 'Gate'
    Assert '178 APPROVAL-EVIDENCE: a non-control contract approves with no evidence section' ($r.Code-eq0) $r.Text
    Pop 'D;F;HJ' 'accept'

    # 179. The evidence section is frozen at Approval like every other authority field.
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope 'scripts/check_agent_continuity.ps1' -Evidence (EvidenceText))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    Commit 'approved-with-evidence'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope 'scripts/check_agent_continuity.ps1' -Evidence (EvidenceText -Consumer 'none'))
    $r=Run 'Gate'
    Assert '179 APPROVAL-EVIDENCE: rewriting frozen evidence after approval is refused' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED') $r.Text
    Pop 'HJ' 'reject'

    # ---- PER-PREDICATE APPLICABILITY + DERIVED WRITE CLOSURE (SPEC-210) ----
    # Applicability used to be ONE answer asserted about THREE questions. These cases fix the
    # reachable combinations by MEASUREMENT rather than by fixture convenience, and prove both
    # reproduced directions. Note which combinations are impossible and why: every
    # permanent-control surface is also an authority surface, so `Test-PermanentControlPath`
    # is a strict SUBSET of the contract-level trigger. "Permanent Control only", "Consumer
    # only" and "Boundary only" therefore cannot exist under repository semantics, and
    # inventing fixtures for them would prove something about the fixture and nothing about
    # the derivation. That subset relation needs no assertion because it cannot be false:
    # `Test-EvidenceAuthorityPath` CALLS `Test-PermanentControlPath` in its own `-or` chain, so
    # a path that derives the expensive predicate derives the trigger by construction. The
    # three reachable states - {}, {D,F} and {D,F,HJ} - are covered by 228, 221 and 226.

    # 221. THE REPRODUCED FALSE POSITIVE. `AGENTS.md` is a control surface with real consumers
    # that introduces no permanent control. Before this, its honest omission was refused with
    # "repository evidence makes it applicable" - a claim about evidence never consulted.
    $r=ApproveRun (EvidenceNoHJ) 'AGENTS.md'
    Assert '221 APPLICABILITY: governance prose that adds no permanent control omits H/J and is ADMITTED' ($r.Code-eq0-and$r.Text-match'APPROVAL_EVIDENCE: PASS') $r.Text
    Pop 'D;F' 'accept'

    # 222. Consumer Closure still binds on that same contract, so 221 is not "evidence off".
    $r=ApproveRun (EvidenceNoHJ 'unknown') 'AGENTS.md'
    Assert '222 APPLICABILITY: omitting H/J does not exempt an UNKNOWN consumer disposition' ($r.Code-ne0-and$r.Text-match'INDETERMINATE') $r.Text
    Pop 'D' 'reject'

    # 223. THE REPRODUCED FALSE NEGATIVE. `scripts/parity_surface.sql` decides what the
    # structural parity detector MEASURES. It is not a control path and derives no profile,
    # so SPEC-207 changed it, wrote 68 lines of evidence, and the evaluator returned
    # NOT APPLICABLE without reading one of them.
    $r=ApproveRun (EvidenceText -Consumer 'unknown') 'scripts/parity_surface.sql'
    Assert '223 APPLICABILITY: a detector measurement surface is no longer exempt from evidence' ($r.Code-ne0-and$r.Text-match'INDETERMINATE') $r.Text
    Pop 'D' 'reject'

    # 224. The same surface derives PERMANENT CONTROL, so H/J may not be omitted there.
    $r=ApproveRun (EvidenceNoHJ) 'scripts/parity_surface.sql'
    Assert '224 APPLICABILITY: a permanent-control surface may not omit H/J' ($r.Code-ne0-and$r.Text-match'Permanent-Control Admission missing') $r.Text
    Pop 'HJ' 'reject'

    # 225. Nor may it self-exempt by declaring the subsection NOT APPLICABLE. Omission and
    # declaration are different acts and both have to be refused.
    $r=ApproveRun (EvidenceText -Applicability 'subonly') 'scripts/parity_surface.sql'
    Assert '225 APPLICABILITY: a permanent-control surface may not self-declare H/J not applicable' ($r.Code-ne0-and$r.Text-match'INDETERMINATE') $r.Text
    Pop 'HJ' 'reject'

    # 226. POSITIVE control for 223-225: the same surface with complete evidence is ADMITTED,
    # so the refusals above discriminate rather than reject the surface outright.
    $r=ApproveRun (EvidenceText) 'scripts/parity_surface.sql'
    Assert '226 APPLICABILITY MUST-ACCEPT: complete evidence on a detector surface is ADMITTED' ($r.Code-eq0-and$r.Text-match'APPROVAL_EVIDENCE: PASS') $r.Text
    Pop 'D;F;HJ' 'accept'

    # 227. A predicate the repository does NOT derive may still be VOLUNTEERED, and then binds
    # fully - a label adds an obligation and never removes one. Declaring H/J APPLICABLE on
    # `AGENTS.md` with incomplete obligations must fail exactly as it would on a control script.
    $r=ApproveRun (EvidenceText -HJ 'missing') 'AGENTS.md'
    Assert '227 APPLICABILITY: a volunteered predicate binds fully' ($r.Code-ne0-and$r.Text-match'permanent-control obligation missing') $r.Text
    Pop 'HJ' 'reject'

    # 228. LEAN PATH. A trivial reversible repository-only change is not dragged through
    # evidence that cannot affect it. This is the cost half of the bargain and it must keep
    # holding, or per-predicate derivation has merely moved ceremony around.
    Reset-Fixture
    $lean='allowed.txt;_ORVION_CANONICAL/manifest.md'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $lean)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None');Commit 'lean-draft'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $lean)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    $r=Run 'Gate'
    Assert '228 APPLICABILITY LEAN PATH: a repository-only change still needs no evidence section' ($r.Code-eq0-and$r.Text-match'APPROVAL_EVIDENCE: NOT APPLICABLE') $r.Text
    Pop 'D;F;HJ' 'accept'

    # ---- DERIVED WRITE CLOSURE: the SPEC-203 class, refused at APPROVAL ----
    # SPEC-203 carried `ai-map.json` and not `MASTER_API_CONTRACT.md`, deployed to Primary, and
    # only then met mandatory Check L3, which regenerates that file and byte-compares it. A
    # frozen Write Scope cannot be widened, so the repair lay in a file its own contract
    # forbade. The artifact must EXIST for the closure to bind, so the fixture creates it -
    # a rule that fires on a retired artifact would be a new false red.
    # 229. The reproduced shape: a mandatory verification regenerates a tracked artifact the
    # frozen Write Scope does not cover.
    ClosureSetup;$r=Run 'Gate'
    Assert '229 WRITE-CLOSURE: an artifact a mandatory verification regenerates must be in Write Scope' ($r.Code-ne0-and$r.Text-match'write closure'-and$r.Text-match'ai-map\.json') $r.Text
    Pop 'WC' 'reject'

    # 230. MUST-ACCEPT: naming it closes the contract. Without this the refusal above could be
    # satisfied by a guard that simply refused every manifest-writing contract.
    ClosureSetup 'allowed.txt;_ORVION_CANONICAL/manifest.md;ai-map.json';$r=Run 'Gate'
    Assert '230 WRITE-CLOSURE MUST-ACCEPT: naming the regenerated artifact is admitted' ($r.Code-eq0-and$r.Text-notmatch'write closure') $r.Text
    Pop 'WC' 'accept'

    # 231. A closure over an artifact this repository does not have is not a finding. Same
    # scope as 229, without the file: a retired generator must need no edit here.
    ClosureSetup 'allowed.txt;_ORVION_CANONICAL/manifest.md' '';$r=Run 'Gate'
    Assert '231 WRITE-CLOSURE: a closure whose artifact does not exist is not asserted' ($r.Code-eq0-and$r.Text-notmatch'write closure') $r.Text
    Pop 'WC' 'accept'

    # 232. THE SPEC-203 SHAPE ITSELF. A migration contract that does not carry the API contract
    # Check L3 regenerates. This is the case the live evaluator ADMITTED.
    ClosureSetup 'supabase/migrations/20260101_fixture.sql;_ORVION_CANONICAL/manifest.md;ai-map.json' 'reports/master/MASTER_API_CONTRACT.md';$r=Run 'Gate'
    Assert '232 WRITE-CLOSURE SPEC-203: a migration contract without the regenerated API contract is refused' ($r.Code-ne0-and$r.Text-match'write closure'-and$r.Text-match'MASTER_API_CONTRACT') $r.Text
    Pop 'WC' 'reject'

    # 233. Write closure is judged on Write Scope ALONE and BEFORE applicability, because it is
    # a property of the write surface: a REPOSITORY-only contract carries the identical Check 7
    # obligation. Reporting NOT APPLICABLE while the contract cannot finish would be the vacuous
    # green this whole evidence class exists to refuse.
    ClosureSetup;$r=Run 'Gate'
    Assert '233 WRITE-CLOSURE: a NOT-APPLICABLE contract is still held to its write closure' ($r.Code-ne0-and$r.Text-match'write closure'-and$r.Text-notmatch'APPROVAL_EVIDENCE: NOT APPLICABLE') $r.Text
    Pop 'WC' 'reject'

    # ---- SPEC ALLOCATION ----
    # The fixture's own cursor is its baseline commit, which added SPEC-900 alongside two
    # terminal contracts, so the next legal identity is derived - never asserted - below.

    # 180. SPEC-ALLOCATION LOCAL. The reproduced K defect: the Draft that became this very
    # contract was created as SPEC-1002 while the real sequence ended at SPEC-195, and the
    # Gate admitted it because it enforced collision only.
    PlanBaseline
    Put "changes/$(FxId 50)-jump.md" (ContractText -Id (FxId 50) -Status Draft)
    $r=Run 'Gate'
    Assert '180 SPEC-ALLOCATION LOCAL: an arbitrary unused high identity is refused' ($r.Code-ne0-and$r.Text-match'SPEC_ID_NOT_NEXT') $r.Text
    Pop 'K-local' 'reject'

    # 181. POSITIVE control for 180. The next legal identity must still be admitted, or the
    # rule would simply forbid all new contracts.
    PlanBaseline
    Put "changes/$(FxId 1)-legal.md" (ContractText -Id (FxId 1) -Status Draft)
    $r=Run 'Gate'
    Assert '181 SPEC-ALLOCATION LOCAL: the next legal identity is admitted' ($r.Code-eq0) $r.Text
    Pop 'K-local' 'accept'

    # 182. SPEC-ALLOCATION RESERVED-TEXT. K1, reproduced: an identity whose ONLY tracked
    # occurrence was committed and then deleted was re-admitted by the unmodified evaluator
    # while it remained reachable in history.
    PlanBaseline
    Put 'lineage.txt' "historical note naming $(FxId 1) once"
    Commit 'reserve-by-text'
    git -C $root rm -q 'lineage.txt';Commit 'delete-the-text'
    Put "changes/$(FxId 1)-reuse.md" (ContractText -Id (FxId 1) -Status Draft)
    $r=Run 'Gate'
    Assert '182 SPEC-ALLOCATION RESERVED-TEXT: a deleted tracked-text identity stays reserved' ($r.Code-ne0-and$r.Text-match'SPEC_ID_HISTORICALLY_RESERVED') $r.Text
    Pop 'K-reservation' 'reject'

    # 183. CONTROL for 182. While the occurrence still exists the EXISTING current-tree rule
    # must refuse it with its own unchanged vocabulary - proving 182 tested history, not this.
    PlanBaseline
    Put 'lineage.txt' "historical note naming $(FxId 1) once";Commit 'reserve-by-text-present'
    Put "changes/$(FxId 1)-reuse.md" (ContractText -Id (FxId 1) -Status Draft)
    $r=Run 'Gate'
    Assert '183 SPEC-ALLOCATION RESERVED-TEXT: a present occurrence still raises SPEC_ID_ALREADY_USED' ($r.Code-ne0-and$r.Text-match'SPEC_ID_ALREADY_USED') $r.Text
    Pop 'K-reservation' 'reject'

    # 184. SPEC-ALLOCATION RESERVED-PATH. The same defect through a tracked FILENAME, which
    # the content pickaxe alone cannot see.
    PlanBaseline
    Put "notes-$(FxId 2)-plan.txt" 'a path that carries the identity'
    Commit 'reserve-by-path'
    git -C $root rm -q "notes-$(FxId 2)-plan.txt";Commit 'delete-the-path'
    Put "changes/$(FxId 2)-reuse.md" (ContractText -Id (FxId 2) -Status Draft)
    $r=Run 'Gate'
    Assert '184 SPEC-ALLOCATION RESERVED-PATH: a deleted tracked-path identity stays reserved' ($r.Code-ne0-and$r.Text-match'SPEC_ID_HISTORICALLY_RESERVED') $r.Text
    Pop 'K-reservation' 'reject'

    # 185. SPEC-ALLOCATION SKIP-RESERVED. Reservation must drive ADVANCEMENT, not only
    # rejection. With cursor+1 burned in history the allocator must hand out cursor+2.
    PlanBaseline
    Put 'lineage.txt' "historical note naming $(FxId 1) once";Commit 'burn-next'
    git -C $root rm -q 'lineage.txt';Commit 'delete-burned'
    Put "changes/$(FxId 2)-after-skip.md" (ContractText -Id (FxId 2) -Status Draft)
    $r=Run 'Gate'
    Assert '185 SPEC-ALLOCATION SKIP-RESERVED: the allocator skips a reserved candidate' ($r.Code-eq0) $r.Text
    Pop 'K-reservation' 'accept'

    # 186. The enforcer half of 185: the very candidate the allocator skipped may not be
    # taken by hand. One reservation fact, two independently proven roles.
    PlanBaseline
    Put 'lineage.txt' "historical note naming $(FxId 1) once";Commit 'burn-next-2'
    git -C $root rm -q 'lineage.txt';Commit 'delete-burned-2'
    Put "changes/$(FxId 1)-manual.md" (ContractText -Id (FxId 1) -Status Draft)
    $r=Run 'Gate'
    Assert '186 SPEC-ALLOCATION SKIP-RESERVED: the skipped candidate is refused when chosen by hand' ($r.Code-ne0-and$r.Text-match'SPEC_ID_HISTORICALLY_RESERVED') $r.Text
    Pop 'K-reservation' 'reject'

    # 187. SPEC-ALLOCATION NON-CR-ORIGIN. Q1's cutover: a non-contract artifact carrying a
    # brand-new number reserves it but must NOT move the cursor, so the next contract still
    # allocates cursor+1 rather than following the stray number.
    PlanBaseline
    Put "supabase/migrations/20260102_$(FxId 40)_fixture.sql" 'select 1;'
    Commit 'non-cr-origination'
    Put "changes/$(FxId 1)-still-next.md" (ContractText -Id (FxId 1) -Status Draft)
    $r=Run 'Gate'
    Assert '187 SPEC-ALLOCATION NON-CR-ORIGIN: a non-contract identity does not advance the cursor' ($r.Code-eq0) $r.Text
    Pop 'K-local' 'accept'

    # 188. The reservation half of 187 - the stray number is burned, not merely ignored.
    PlanBaseline
    Put "supabase/migrations/20260102_$(FxId 40)_fixture.sql" 'select 1;'
    Commit 'non-cr-origination-2'
    Put "changes/$(FxId 40)-claim.md" (ContractText -Id (FxId 40) -Status Draft)
    $r=Run 'Gate'
    Assert '188 SPEC-ALLOCATION NON-CR-ORIGIN: the stray number is permanently reserved' ($r.Code-ne0-and$r.Text-match'SPEC_ID_ALREADY_USED|SPEC_ID_HISTORICALLY_RESERVED') $r.Text
    Pop 'K-reservation' 'reject'

    # 189. SPEC-ALLOCATION ACTIVATION. The marker is the activation signal. With no marker
    # in the working tree the evaluator fails CLOSED rather than silently allocating unchecked.
    PlanBaseline
    Put 'CR_LIFECYCLE.md' "# fixture lifecycle`n`nno marker here`n"
    Put "changes/$(FxId 1)-no-marker.md" (ContractText -Id (FxId 1) -Status Draft)
    $r=Run 'Gate'
    Assert '189 SPEC-ALLOCATION ACTIVATION: a missing allocation marker fails closed' ($r.Code-ne0-and$r.Text-match'SPEC_ALLOCATION_MARKER_MISSING') $r.Text
    Pop 'K-activation' 'reject'

    # 190. SPEC-ALLOCATION DIAGNOSTIC-RENAME. K2, reproduced: the old activation pattern read
    # a diagnostic literal out of the evaluator's own source, so a behaviour-preserving rename
    # silently disabled it. Renaming every diagnostic this evaluator emits must change nothing.
    PlanBaseline
    $renamed=(Get-Content -Raw $control).
        Replace('SPEC_ID_NOT_NEXT','ALLOC_NOT_NEXT_RENAMED').
        Replace('SPEC_ID_HISTORICALLY_RESERVED','ALLOC_RESERVED_RENAMED').
        Replace('SPEC_ALLOCATION_MARKER_MISSING','ALLOC_MARKER_RENAMED')
    Put 'scripts/check_agent_continuity.ps1' $renamed
    Commit 'rename-every-diagnostic'
    Put "changes/$(FxId 50)-jump-after-rename.md" (ContractText -Id (FxId 50) -Status Draft)
    $r=& pwsh -NoProfile -File (Join-Path $root 'scripts/check_agent_continuity.ps1') -Gate -Root $root 2>&1
    $rc=$LASTEXITCODE
    Assert '190 SPEC-ALLOCATION DIAGNOSTIC-RENAME: renaming diagnostics does not disable enforcement' ($rc-ne0-and(($r|Out-String)-match'ALLOC_NOT_NEXT_RENAMED')) ($r|Out-String)
    Pop 'K-activation' 'reject'

    # 191. SPEC-ALLOCATION RANGE-LAUNDER. A net diff cannot see a violation that a later
    # commit corrected. The range must still fail on the offending commit.
    # The range must carry a GOVERNING contract or range validation never reaches the
    # per-commit walk, so the corrected contract becomes governing exactly as it does
    # in a real publication: authored in PLAN, then approved inside the same push.
    PlanBaseline
    $base=(git -C $root rev-parse HEAD).Trim()
    $launderScope='allowed.txt;_ORVION_CANONICAL/manifest.md'
    Put "changes/$(FxId 50)-illegal.md" (ContractText -Id (FxId 50) -Status Draft -Scope $launderScope)
    Commit 'illegal-allocation'
    git -C $root mv "changes/$(FxId 50)-illegal.md" "changes/$(FxId 1)-corrected.md";Commit 'correct-it'
    Put "changes/$(FxId 1)-corrected.md" (ContractText -Id (FxId 1) -Status Approved -Scope $launderScope)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText "changes/$(FxId 1)-corrected.md")
    Commit 'approve-the-correction'
    $r=RunRange $base
    Assert '191 SPEC-ALLOCATION RANGE-LAUNDER: a corrected illegal allocation still fails the range' ($r.Code-ne0-and$r.Text-match'SPEC_ID_NOT_NEXT') $r.Text
    Pop 'K-range' 'reject'

    # 191b. The control for 191: the SAME shape with a LEGAL first allocation must be
    # accepted, or 191 would pass against a range check that refused every history.
    PlanBaseline
    $base=(git -C $root rev-parse HEAD).Trim()
    Put "changes/$(FxId 1)-legal-range.md" (ContractText -Id (FxId 1) -Status Draft -Scope $launderScope)
    Commit 'legal-allocation'
    Put "changes/$(FxId 1)-legal-range.md" (ContractText -Id (FxId 1) -Status Approved -Scope $launderScope)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText "changes/$(FxId 1)-legal-range.md")
    Commit 'approve-the-legal-one'
    $r=RunRange $base
    Assert '191b SPEC-ALLOCATION RANGE-LAUNDER: a legal allocation in the same shape is accepted' ($r.Code-eq0) $r.Text
    Pop 'K-range' 'accept'

    # 192. SPEC-ALLOCATION ACTIVATION. Pre-marker history is NOT retroactively judged, which
    # is what keeps this contract's own SPEC-1002 creation and correction publishable.
    PlanBaseline
    Put 'CR_LIFECYCLE.md' "# fixture lifecycle`n`nno marker yet`n";Commit 'pre-marker-state'
    $base=(git -C $root rev-parse HEAD).Trim()
    Put "changes/$(FxId 50)-premarker.md" (ContractText -Id (FxId 50) -Status Draft);Commit 'pre-marker-allocation'
    git -C $root mv "changes/$(FxId 50)-premarker.md" "changes/$(FxId 1)-premarker-fixed.md";Commit 'pre-marker-correction'
    $r=RunRange $base
    Assert '192 SPEC-ALLOCATION ACTIVATION: allocation before the marker is not retroactively judged' ($r.Text-notmatch'SPEC_ID_NOT_NEXT') $r.Text
    Pop 'K-activation' 'accept'

    # 193. The routine Gate must stay a LOCAL, deterministic check. The stub bin
    # already shadows npx and docker, so an invocation of either - and by extension
    # any Supabase, container or network work routed through them - leaves a trace.
    # Asserted on the ALLOCATING path too, because history-anchored reservation is
    # the only new cost and it must be Git and nothing else.
    Reset-Fixture
    if(Test-Path -LiteralPath $stubLog){Remove-Item -LiteralPath $stubLog -Force}
    $r=Run 'Gate'
    Assert '193 ORDINARY GATE: invokes no stubbed external executable' ($r.Code-eq0-and((StubLog)-eq'')) "code=$($r.Code) stub-log=[$(StubLog)]"
    Pop 'D;F;HJ;K-local' 'accept'

    PlanBaseline
    if(Test-Path -LiteralPath $stubLog){Remove-Item -LiteralPath $stubLog -Force}
    Put "changes/$(FxId 1)-perf-probe.md" (ContractText -Id (FxId 1) -Status Draft)
    $r=Run 'Gate'
    Assert '194 ALLOCATING GATE: identity allocation invokes no stubbed external executable' ($r.Code-eq0-and((StubLog)-eq'')) "code=$($r.Code) stub-log=[$(StubLog)]"
    Pop 'K-local;K-reservation;K-activation' 'accept'

    # ---- APPROVAL-EVIDENCE APPLICABILITY (SPEC-198) ----
    # SPEC-196 shipped ONE of the five applicability inputs its own frozen Step E named,
    # so a contract that reached a non-control surface had its evidence skipped and the
    # Gate still printed `APPROVAL_EVIDENCE: PASS`. Reproduced on the real Draft->Approved
    # path before repair. Every scope below is chosen so exactly ONE new input makes it
    # applicable - a fixture that two arms would catch cannot prove either is load-bearing.
    $dbScope='supabase/migrations/20260101000000_fixture.sql'
    $fnScope='supabase/functions/storage-executor/index.ts'
    # A DATABASE-profile contract must declare these or `Validate-DatabaseContract`
    # refuses it before the evidence is read - a wrong-reason failure that would look
    # identical to the defect these fixtures exist to catch.
    $dbCaps='supabase-local'
    $dbAdd='pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1'

    $r=ApproveRun (EvidenceText -Consumer 'unknown') $dbScope $dbCaps $dbAdd
    Assert '195 APPROVAL-EVIDENCE APPLICABILITY: DATABASE scope does not exempt an UNKNOWN disposition' ($r.Code-ne0-and$r.Text-match'SUBJECT: INDETERMINATE') $r.Text
    Pop 'APPLIC' 'reject'

    $r=ApproveRun (EvidenceText -Boundary 'conflict') $dbScope $dbCaps $dbAdd
    Assert '196 APPROVAL-EVIDENCE APPLICABILITY: DATABASE scope does not exempt a gate inside its red window' ($r.Code-ne0-and$r.Text-match'CODE: APPROVAL_EVIDENCE') $r.Text
    Pop 'APPLIC' 'reject'

    # An applicable contract that carries no section at all is INDETERMINATE, not absent.
    Reset-Fixture
    $dbFull="$dbScope;_ORVION_CANONICAL/manifest.md"
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $dbFull -Capabilities $dbCaps -Additional $dbAdd)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None')
    Commit 'db-draft-no-evidence'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $dbFull -Capabilities $dbCaps -Additional $dbAdd)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    $r=Run 'Gate'
    Assert '197 APPROVAL-EVIDENCE APPLICABILITY: an applicable DATABASE contract may not omit the section' ($r.Code-ne0-and$r.Text-match'section missing') $r.Text
    Pop 'APPLIC' 'reject'

    # REPOSITORY-only scope: the ONLY thing that can make this applicable is the contract's
    # own declared irreversible action, which is what isolates that arm for its mutation.
    $r=ApproveRun (EvidenceText -Consumer 'unknown' -Irreversible 'Step 2') 'allowed.txt'
    Assert '198 APPROVAL-EVIDENCE APPLICABILITY: a declared irreversible action makes evidence applicable' ($r.Code-ne0-and$r.Text-match'SUBJECT: INDETERMINATE') $r.Text
    Pop 'APPLIC' 'reject'

    # Edge Functions derive NO profile and are absent from Get-ControlSurface, so before
    # this repair nothing reached them at all - yet this one authorizes itself with the
    # service_role key and destroys customer documents.
    $r=ApproveRun (EvidenceText -Consumer 'unknown') $fnScope
    Assert '199 APPROVAL-EVIDENCE APPLICABILITY: an Edge Function contract is applicable' ($r.Code-ne0-and$r.Text-match'SUBJECT: INDETERMINATE') $r.Text
    Pop 'APPLIC' 'reject'

    # The fixtures must prove they are the shape they claim, read from the Gate's own
    # derived VERIFICATION line - otherwise they prove nothing about the input they name.
    $r=ApproveRun (EvidenceText) $dbScope $dbCaps $dbAdd
    Assert '200 APPROVAL-EVIDENCE APPLICABILITY: the DATABASE fixture derives DATABASE and not CONTROL' ($r.Code-eq0-and$r.Text-match'VERIFICATION: DATABASE, REPOSITORY'-and$r.Text-notmatch'CONTROL') $r.Text
    Pop 'APPLIC' 'accept'

    $r=ApproveRun (EvidenceText) $fnScope
    Assert '201 APPROVAL-EVIDENCE APPLICABILITY: the Edge Function fixture derives REPOSITORY alone' ($r.Code-eq0-and$r.Text-match'VERIFICATION: REPOSITORY'-and$r.Text-notmatch'DATABASE'-and$r.Text-notmatch'CONTROL') $r.Text
    Pop 'APPLIC' 'accept'

    # POSITIVE. Applicability must not become "refuse everything outside REPOSITORY".
    $r=ApproveRun (EvidenceText) $dbScope $dbCaps $dbAdd
    Assert '202 APPROVAL-EVIDENCE APPLICABILITY: complete evidence on a DATABASE contract is ADMITTED' ($r.Code-eq0-and$r.Text-match'APPROVAL_EVIDENCE: PASS') $r.Text
    Pop 'APPLIC' 'accept'

    # POSITIVE. A genuinely non-applicable contract stays light AND says so, because
    # "we did not look" and "we looked and it is fine" are different facts.
    Reset-Fixture
    $plain2='allowed.txt;_ORVION_CANONICAL/manifest.md'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $plain2)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None')
    Commit 'plain-draft-not-applicable'
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $plain2)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    $r=Run 'Gate'
    Assert '203 APPROVAL-EVIDENCE APPLICABILITY: a non-applicable contract reports NOT APPLICABLE' ($r.Code-eq0-and$r.Text-match'APPROVAL_EVIDENCE: NOT APPLICABLE') $r.Text
    Pop 'APPLIC' 'accept'

    # ---- RANGE-AUTHORITY BASELINE (SPEC-200) ----
    # Two defects in one block, failing in opposite directions. CTRL-2A applied a freeze
    # that had not happened yet: the endpoint compared the governing contract against its
    # snapshot at the range BASE without consulting $baselineStatus, so a Draft - the one
    # state CR_LIFECYCLE 8 says may be revised - was treated as frozen authority, and a
    # legally hardened Draft became permanently unpublishable. CTRL-2B failed to apply a
    # check that should have happened: the evidence call site was keyed on the range's
    # ENDPOINT status, so the ordinary push shape (Approve + In Progress together) never
    # evidence-checked its own Approval.
    #
    # Every scope below is CONTROL so the evidence classes are APPLICABLE (SPEC-198);
    # `allowed.txt` would derive REPOSITORY alone and prove nothing about evidence.
    $raScope='scripts/check_agent_continuity.ps1;_ORVION_CANONICAL/manifest.md'
    function RaBase([string]$Ev){
        Reset-Fixture
        Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $raScope -Evidence $Ev)
        Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None')
        Commit 'ra-base-draft'
        (git -C $root rev-parse HEAD).Trim()
    }
    function RaApprove([string]$Ev){
        Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $raScope -Evidence $Ev)
        Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
        Commit 'ra-approve'
    }
    function RaInProgress([string]$Ev){
        Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope $raScope -Evidence $Ev)
        Commit 'ra-inprogress'
    }

    # 204. CTRL-2A. A Draft at the base is revised before its own Approval - legal under
    # CR_LIFECYCLE 8 - and the range must publish.
    $b=RaBase (EvidenceText)
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft -Scope $raScope -Evidence (EvidenceText -Class 'Routine'))
    Commit 'ra-harden-draft'
    RaApprove (EvidenceText -Class 'Routine')
    RaInProgress (EvidenceText -Class 'Routine')
    $r=RunRange $b
    Assert '204 RANGE-AUTHORITY BASELINE: a Draft revised before its own Approval is publishable' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Pop 'RANGE-AUTH' 'accept'

    # 205-207. CTRL-2B. The base Draft carries the IDENTICAL evidence text, so nothing
    # mutates and a refusal can only come from the evidence replay - never from a
    # frozen-authority comparison. Each is asserted on its own predicate's code.
    foreach($bad in @(
        @{No='205'; E=(EvidenceText -Consumer 'unknown');    N='an UNKNOWN consumer disposition'},
        @{No='206'; E=(EvidenceText -Consumer 'unresolved'); N='a named unresolved material consumer'},
        @{No='207'; E=(EvidenceText -Boundary 'conflict');   N='a gate inside its own red window'})){
        $b=RaBase $bad.E
        RaApprove $bad.E
        RaInProgress $bad.E
        $r=RunRange $b
        Assert "$($bad.No) RANGE-AUTHORITY: an intermediate Approval carrying $($bad.N) is refused" `
            ($r.Code-ne0-and$r.Text-match'CODE: APPROVAL_EVIDENCE'-and$r.Text-notmatch'FROZEN_AUTHORITY_MUTATED') $r.Text
        Pop 'RANGE-AUTH' 'reject'
    }

    # 208. POSITIVE. The replay must not become "refuse every intermediate Approval".
    $b=RaBase (EvidenceText)
    RaApprove (EvidenceText)
    RaInProgress (EvidenceText)
    $r=RunRange $b
    Assert '208 RANGE-AUTHORITY: a valid intermediate Approval is ADMITTED' ($r.Code-eq0-and$r.Text-match'MODE: EXECUTE') $r.Text
    Pop 'RANGE-AUTH' 'accept'

    # 209. NON-EMPTY POPULATION for the replay itself: a range carrying no Draft->Approved
    # commit must select nothing, so the new code cannot pass by never running.
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $raScope -Evidence (EvidenceText))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    Commit 'ra-approved-base'
    $b=(git -C $root rev-parse HEAD).Trim()
    RaInProgress (EvidenceText)
    $r=RunRange $b
    Assert '209 RANGE-AUTHORITY: a range with no Draft-to-Approved commit invokes no replay' ($r.Code-eq0-and$r.Text-notmatch'APPROVAL_EVIDENCE') $r.Text
    Pop 'RANGE-AUTH' 'accept'

    # 210. The post-Approval freeze is NOT weakened by the baseline gate: from a non-Draft
    # baseline every existing protection must still fire.
    Reset-Fixture
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $raScope -Evidence (EvidenceText))
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
    Commit 'ra-approved-baseline'
    $b=(git -C $root rev-parse HEAD).Trim()
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope $raScope -Evidence (EvidenceText -Consumer 'none'))
    Commit 'ra-post-approval-mutation'
    $r=RunRange $b
    Assert '210 RANGE-AUTHORITY: a post-Approval frozen-section mutation is still refused' ($r.Code-ne0-and$r.Text-match'FROZEN_AUTHORITY_MUTATED') $r.Text
    Pop 'RANGE-AUTH' 'reject'

    # 211-212. The ENDPOINT-ONLY protections. Validate-CommittedRange's per-commit walk
    # compares frozen SECTIONS, so 210 above would still refuse even if the endpoint block
    # never ran. Acceptance Criteria and Review Gate text are compared by Validate-Checklist
    # at the endpoint alone, so these two are the only proof that the Draft gate did not
    # become a post-Approval exemption.
    foreach($ep in @(
        @{No='211'; What='Acceptance Criteria'; Arg=@{Acceptance='Silently reworded after Approval.'}; Code='ACCEPTANCE_TEXT_MUTATED'},
        @{No='212'; What='Review Gate';         Arg=@{Review='Silently reworded after Approval.'};     Code='REVIEW_GATE_TEXT_MUTATED'})){
        Reset-Fixture
        Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope $raScope -Evidence (EvidenceText))
        Put '_ORVION_CANONICAL/manifest.md' (ManifestText)
        Commit 'ra-ep-base'
        $b=(git -C $root rev-parse HEAD).Trim()
        $epArg=$ep.Arg
        Put 'changes/SPEC-900-fixture.md' (ContractText -Status 'In Progress' -Scope $raScope -Evidence (EvidenceText) @epArg)
        Commit 'ra-ep-mutation'
        $r=RunRange $b
        Assert "$($ep.No) RANGE-AUTHORITY: post-Approval $($ep.What) text is still refused at the endpoint" ($r.Code-ne0-and$r.Text-match$ep.Code) $r.Text
        Pop 'RANGE-AUTH' 'reject'
    }

    # ---- APPROVAL-EVIDENCE MUTATION POPULATION (SPEC-196) ----
    # A guard that cannot be broken was never load-bearing. Each mutation bypasses
    # exactly ONE predicate in a disposable copy of the evaluator and re-runs the
    # same scenario: the pristine run must produce the expected evidence and the
    # mutated run must not. Both halves are required - asserting only that the
    # mutated run differs would credit a crash as a kill.
    foreach($m in @(
        @{Fam='D';N='derived applicability / self-exemption (per-class declaration)';S={ApproveSetup (EvidenceText -Class 'Routine' -Applicability 'subonly')};E='CODE: APPROVAL_EVIDENCE'
          F="if(`$state-ne'APPLICABLE'){";R='if($false){'}
        # SPEC-210. The two NEW load-bearing predicates. Each is killed on a scenario only it
        # can refuse, so no neighbouring guard can supply the kill on its behalf.
        @{Fam='APPLIC';N='applicability: permanent-control surface derivation';S={ApproveSetup (EvidenceNoHJ) 'scripts/parity_surface.sql'};E='CODE: APPROVAL_EVIDENCE'
          F="'Permanent-Control Admission'=@(`$Contract.Scope|Where-Object{Test-PermanentControlPath `$_}).Count-gt0";R="'Permanent-Control Admission'=`$false"}
        @{Fam='WC';N='write closure: regenerated artifact absent from Write Scope';S={ClosureSetup};E='CODE: APPROVAL_EVIDENCE'
          F="if(`$Contract.Scope-notcontains`$rule.Needs){";R='if($false){'}
        # APPROVAL-EVIDENCE APPLICABILITY POPULATION (SPEC-198). Each scenario below is
        # applicable through exactly ONE arm, so no other arm can kill its mutation for it.
        @{Fam='APPLIC';N='applicability: derived non-REPOSITORY profile';S={ApproveSetup (EvidenceText -Consumer 'unknown') 'supabase/migrations/20260101000000_fixture.sql' 'supabase-local' 'pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1'};E='SUBJECT: INDETERMINATE'
          F="`$applicable=@(`$Profiles|Where-Object{`$_-ne'REPOSITORY'}).Count-gt0";R="`$applicable=(`$Profiles-contains'CONTROL')"}
        @{Fam='APPLIC';N='applicability: Edge Function execution surface';S={ApproveSetup (EvidenceText -Consumer 'unknown') 'supabase/functions/storage-executor/index.ts'};E='SUBJECT: INDETERMINATE'
          F="if(Test-EvidenceAuthorityPath `$p){`$applicable=`$true;break}";R=''}
        @{Fam='APPLIC';N='applicability: declared irreversible action';S={ApproveSetup (EvidenceText -Consumer 'unknown' -Irreversible 'Step 2') 'allowed.txt'};E='SUBJECT: INDETERMINATE'
          F="if(`$irr-and`$irr-notmatch'^\s*NONE\b'){`$applicable=`$true}";R='if($false){}'}
        # The vocabulary itself is load-bearing: reporting PASS for a section nobody read
        # is the defect's user-visible face, so it gets its own kill on its own scenario.
        @{Fam='APPLIC';N='applicability: a non-applicable contract reports NOT APPLICABLE, not PASS';S={ApproveSetup (EvidenceText) 'allowed.txt'};E='APPROVAL_EVIDENCE: NOT APPLICABLE'
          F="if(-not `$applicable){return 'NOT APPLICABLE'}";R="if(-not `$applicable){return 'PASS'}"}
        @{Fam='D';N='D rows present';S={ApproveSetup (EvidenceText -Consumer 'none')};E='CODE: APPROVAL_EVIDENCE'
          F="if(!`$rows.Count){throw 'APPROVAL_EVIDENCE:INDETERMINATE:no consumer closure rows'}";R=''}
        @{Fam='D';N='D UNKNOWN disposition';S={ApproveSetup (EvidenceText -Consumer 'unknown')};E='SUBJECT: INDETERMINATE'
          F="if(`$row[2]-eq'UNKNOWN'){";R='if($false){'}
        @{Fam='D';N='D disposition vocabulary';S={ApproveSetup (EvidenceText -Consumer 'baddisposition')};E='CODE: APPROVAL_EVIDENCE'
          F="if(@('WRITE','VERIFY','UNAFFECTED')-notcontains`$row[2]){";R='if($false){'}
        @{Fam='D';N='D placeholder rejection';S={ApproveSetup (EvidenceText -Consumer 'placeholder')};E='CODE: APPROVAL_EVIDENCE'
          F="if((`$cells|Where-Object{`$_-match'^\[.*\]`$'}).Count){continue}";R=''}
        @{Fam='D';N='D unresolved material consumer';S={ApproveSetup (EvidenceText -Consumer 'unresolved')};E='CODE: APPROVAL_EVIDENCE'
          F="if(`$unresolved-ne'None'){";R='if($false){'}
        @{Fam='F';N='F boundary conflict ordering';S={ApproveSetup (EvidenceText -Boundary 'conflict')};E='CODE: APPROVAL_EVIDENCE'
          F='if($opens-gt0-and$gate-gt$opens-and$gate-le$closes){';R='if($false){'}
        @{Fam='F';N='F open-ended red window';S={ApproveSetup (EvidenceText -Boundary 'openended')};E='CODE: APPROVAL_EVIDENCE'
          F="if(`$opens-gt0-and`$closes-eq0){";R='if($false){'}
        @{Fam='HJ';N='H/J obligation completeness';S={ApproveSetup (EvidenceText -HJ 'missing')};E='CODE: APPROVAL_EVIDENCE'
          F="if((EvidenceField `$hj `$field)-eq''){";R='if($false){'}
        @{Fam='HJ';N='frozen membership of the evidence section';S={FrozenEvidenceSetup};E='FROZEN_AUTHORITY_MUTATED'
          F="'Additional Verification','Pre-Approval Evidence','Implementation Steps'";R="'Additional Verification','Implementation Steps'"}
        @{Fam='K-local';N='K local allocation invocation';S={AllocSetup 50};E='SPEC_ID_NOT_NEXT'
          F='if($id-ne$candidate){throw "SPEC_ID_NOT_NEXT:${candidate}:$id"}';R=''}
        @{Fam='K-reservation';N='K current-tree collision';S={ReservedPresentSetup};E='SPEC_ID_ALREADY_USED'
          F='if(Base-HasId $Ref $id){throw "SPEC_ID_ALREADY_USED:$id"}';R=''}
        @{Fam='K-reservation';N='K historical content reservation';S={ReservedTextSetup};E='SPEC_ID_HISTORICALLY_RESERVED'
          F='$hits=@(git -C $Root log $Ref --root --pickaxe-regex "-S$rx" --format=%h 2>$null);$LASTEXITCODE=0';R='$hits=@()'}
        @{Fam='K-reservation';N='K historical path reservation';S={ReservedPathSetup};E='SPEC_ID_HISTORICALLY_RESERVED'
          F='if($line-and$line-match$rx){$result=$current;break}';R='if($false){}'}
        @{Fam='K-reservation';N='K reservation drives advancement';S={SkipReservedSetup};E='ORVION: READY'
          F='while(Test-SpecIdEverReserved $Ref "SPEC-$candidate"){$candidate++}';R=''}
        @{Fam='K-local';N='K origination restriction';S={NonCrOriginSetup};E='ORVION: READY'
          F="if(`$r.Path-match'^changes/SPEC-(?<n>[0-9]+)-.*\.md`$'-and`$null-eq(Read-GitFile `$Ref `$r.Path)){`$ids+=[int]`$Matches['n']}"
          R="if(`$r.Path-match'SPEC-(?<n>[0-9]+)'-and`$null-eq(Read-GitFile `$Ref `$r.Path)){`$ids+=[int]`$Matches['n']}"}
        @{Fam='K-activation';N='K working-tree activation marker';S={NoMarkerSetup};E='SPEC_ALLOCATION_MARKER_MISSING'
          F="if((Get-AllocationMarker `$text)-lt1){throw 'SPEC_ALLOCATION_MARKER_MISSING'}";R=''}
    )){
        MutationKill "APPROVAL-EVIDENCE MUTATION POPULATION: $($m.N)" $m.S $m.E $m.F $m.R $m.Fam
    }

    # Range-scoped mutations. Same contract, driven through RunRange because a
    # per-commit invariant cannot be observed from a working-tree gate at all.
    foreach($m in @(
        @{N='K per-commit range invocation';E='SPEC_ID_NOT_NEXT'
          F='try{Validate-SpecAllocation $records "$commit^" -SkipMarkerCheck -CheckOrigination -StateRef $commit}catch{throw "$($_.Exception.Message)@$short"}';R=''}
        @{N='K first-parent activation marker';E='SPEC_ID_NOT_NEXT'
          F='if(Allocation-ActiveAt "$commit^"){';R='if($false){'}
    )){
        MutationKillRange "APPROVAL-EVIDENCE MUTATION POPULATION: $($m.N)" $m.E $m.F $m.R
    }

    # The derived-applicability TABLE is a second, independent self-exemption door.
    # Both are proven separately; a scenario that trips both would prove neither.
    MutationKill 'APPROVAL-EVIDENCE MUTATION POPULATION: derived applicability / self-exemption (derived table)' `
        {ApproveSetup (EvidenceText -Class 'Routine' -Applicability 'tableonly')} 'CODE: APPROVAL_EVIDENCE' `
        "if(`$derived.Contains(`$row[0])-and`$derived[`$row[0]]-and`$row[-1]-ne'APPLICABLE'){" 'if($false){' 'D'

    # Cursor chronology is proven by an ACCEPTING scenario on purpose. Shifting the
    # cursor would merely move WHICH commit a rejecting scenario blames, which is not
    # evidence; breaking it must refuse the identity that is actually legal.
    MutationKill 'APPROVAL-EVIDENCE MUTATION POPULATION: K cursor chronology' {AllocSetup 1} 'ORVION: READY' `
        'if($ids.Count){return ($ids|Measure-Object -Maximum).Maximum}' 'if($ids.Count){return 0}' 'K-local'

    # ---- ORIGINATION STATE (SPEC-202) ----
    # A contract BORN `Approved` is never evidence-checked: Evaluate-PreApprovalEvidence
    # is reached only when the contract exists at the comparison baseline, and a born
    # contract has none. Owner-ratified correction, forward-only from the existing
    # `SPEC Allocation Enforcement` marker: after activation a newly originated contract
    # must first appear as `Draft`. Pre-activation histories keep their own law.
    $osScope='_ORVION_CANONICAL/manifest.md'
    function OsDeactivate{Put 'CR_LIFECYCLE.md' "# fixture lifecycle`n`nno marker`n";Commit 'os-deactivate'}

    # 213-215. POST-activation origination in a non-Draft state, at the LOCAL Gate.
    foreach($born in @(
        @{No='213'; S='Approved';    Extra=@{}},
        @{No='214'; S='In Progress'; Extra=@{}},
        @{No='215'; S='Complete';    Extra=@{Resume='DONE';Closeable=$true}})){
        Reset-Fixture
        $ex=$born.Extra
        Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status $born.S -Scope $osScope @ex)
        Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md')
        $r=Run 'Gate'
        Assert "$($born.No) ORIGINATION STATE: a post-activation contract born '$($born.S)' is refused locally" ($r.Code-ne0-and$r.Text-match'ORIGINATION_NOT_DRAFT') $r.Text
        Pop 'ORIGIN' 'reject'
    }

    # 216. The same history judged as a committed RANGE, with the offending short SHA.
    Reset-Fixture;Pre-Range
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope $osScope)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit 'os-born-approved'
    $r=RunRange 'HEAD~1'
    Assert '216 ORIGINATION STATE: a post-activation born-Approved range is refused with the offending SHA' ($r.Code-ne0-and$r.Text-match'ORIGINATION_NOT_DRAFT'-and$r.Text-match'@[0-9a-f]{7}') $r.Text
    Pop 'ORIGIN' 'reject'

    # 217. POSITIVE. Authoring a post-activation contract as Draft stays legal. PLAN mode
    # is required: a new contract file authored while another contract still governs is an
    # OUT_OF_SCOPE_WRITE, which would fail this case for a reason unrelated to origination.
    PlanBaseline
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Draft -Scope $osScope)
    $r=Run 'Gate'
    Assert '217 ORIGINATION STATE: a post-activation contract authored as Draft is admitted' ($r.Code-eq0-and$r.Text-match'MODE: PLAN') $r.Text
    Pop 'ORIGIN' 'accept'

    # 218. POSITIVE. The SPEC-165 property under the new law: a whole lifecycle in one
    # push is still legal, provided it BEGINS at Draft.
    Reset-Fixture;Pre-Range
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Draft -Scope $osScope);Commit 'os-draft'
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope $osScope)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit 'os-approve'
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status 'In Progress' -Scope $osScope);Commit 'os-ip'
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Complete -Resume DONE -Scope $osScope -Closeable)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit 'os-complete'
    $r=RunRange 'HEAD~4'
    Assert '218 ORIGINATION STATE: a Draft-first whole lifecycle inside one range is admitted' ($r.Code-eq0-and$r.Text-match'MODE: VERIFY') $r.Text
    Pop 'ORIGIN' 'accept'

    # 219. HISTORICAL CONTROL. The pre-activation SPEC-165 shape - a contract born
    # `Approved` where the originating commit's first parent declares no marker - stays
    # legal exactly as committed. This is what makes the rule forward-only.
    Reset-Fixture;OsDeactivate;Pre-Range
    Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope $osScope)
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit 'os-pre-activation-born'
    $r=RunRange 'HEAD~1'
    Assert '219 ORIGINATION STATE: a PRE-activation born-Approved range (SPEC-165 shape) is still admitted' ($r.Code-eq0) $r.Text
    Pop 'ORIGIN' 'accept'

    # 220. NON-EMPTY POPULATION for the rule itself: a range with no allocation event must
    # invoke the origination check zero times, so it cannot pass by never firing. The range
    # transitions a contract that ALREADY EXISTS at the base, which is not an allocation.
    Reset-Fixture;Pre-Range
    Put 'changes/SPEC-900-fixture.md' (ContractText -Status Approved -Scope '_ORVION_CANONICAL/manifest.md')
    Put '_ORVION_CANONICAL/manifest.md' (ManifestText);Commit 'os-no-allocation'
    $r=RunRange 'HEAD~1'
    Assert '220 ORIGINATION STATE: a range with no allocation event invokes no origination check' ($r.Code-eq0-and$r.Text-notmatch'ORIGINATION_NOT_DRAFT') $r.Text
    Pop 'ORIGIN' 'accept'

    # ---- RANGE-AUTHORITY MUTATION POPULATION (SPEC-200) ----
    # The two halves fail in opposite directions, so each is killed by the one scenario
    # no other guard can rescue. These run through the RANGE, because that is the only
    # place the repaired predicates live.
    MutationKillRangeAt 'RANGE-AUTHORITY MUTATION: the Draft baseline is not frozen authority' `
        {RaBuildBaseline} 'MODE: EXECUTE' "        if(`$baselineStatus-ne'Draft'){" '        if($true){'
    MutationKillRangeAt 'RANGE-AUTHORITY MUTATION: the baseline gate is not inverted' `
        {RaBuildPostApproval} 'ACCEPTANCE_TEXT_MUTATED' "        if(`$baselineStatus-ne'Draft'){" "        if(`$baselineStatus-eq'Draft'){"
    MutationKillRangeAt 'RANGE-AUTHORITY MUTATION: the intermediate Approval replay runs' `
        {RaBuildReplay} 'CODE: APPROVAL_EVIDENCE' "                if(`$parentStatus-eq'Draft'-and`$statusAt-eq'Approved'){" '                if($false){'

    # ---- ORIGINATION STATE MUTATION POPULATION (SPEC-202) ----
    # Three predicates, three scenarios no other guard can rescue: the marker gate that
    # makes the rule forward-only, the `Draft` requirement itself, and the deliberate
    # exclusion of the range endpoint.
    function OsBuildPost{
        Pre-Range
        Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope '_ORVION_CANONICAL/manifest.md')
        Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit 'osm-born'
        (git -C $root rev-parse 'HEAD~1').Trim()
    }
    function OsBuildPre{
        Put 'CR_LIFECYCLE.md' "# fixture lifecycle`n`nno marker`n";Commit 'osm-deactivate'
        Pre-Range
        Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope '_ORVION_CANONICAL/manifest.md')
        Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit 'osm-pre-born'
        (git -C $root rev-parse 'HEAD~1').Trim()
    }
    function OsBuildLifecycle{
        $sc='_ORVION_CANONICAL/manifest.md'
        Pre-Range
        Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Draft -Scope $sc);Commit 'osm-draft'
        $b=(git -C $root rev-parse 'HEAD~1').Trim()
        Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Approved -Scope $sc)
        Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'changes/SPEC-901-born.md');Commit 'osm-approve'
        Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status 'In Progress' -Scope $sc);Commit 'osm-ip'
        Put 'changes/SPEC-901-born.md' (ContractText -Id SPEC-901 -Status Complete -Resume DONE -Scope $sc -Closeable)
        Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');Commit 'osm-complete'
        $b
    }
    MutationKillRangeAt 'ORIGINATION STATE MUTATION: the activation marker keeps the rule forward-only' `
        {OsBuildPre} 'ORVION: READY' 'if(Allocation-ActiveAt "$commit^"){' 'if($true){' 'ORIGIN'
    MutationKillRangeAt 'ORIGINATION STATE MUTATION: origination must be Draft' `
        {OsBuildPost} 'ORIGINATION_NOT_DRAFT' "            if(`$st-ne'Draft'){throw ""ORIGINATION_NOT_DRAFT:`$(`$r.Path):`$st""}" '            if($false){}' 'ORIGIN'
    MutationKillRangeAt 'ORIGINATION STATE MUTATION: the range endpoint is excluded' `
        {OsBuildLifecycle} 'MODE: VERIFY' 'elseif(Allocation-ActiveAt $BaseRef){Validate-SpecAllocation $records $base -SkipMarkerCheck}' 'elseif(Allocation-ActiveAt $BaseRef){Validate-SpecAllocation $records $base -SkipMarkerCheck -CheckOrigination}' 'ORIGIN'

    # ---- NON-EMPTY POPULATIONS (SPEC-196) ----
    # A guard reasoning over an empty set reports success while measuring nothing.
    # Every family must have proven acceptance, refusal AND a mutation kill.
    foreach($family in @('D','F','HJ','APPLIC','WC','RANGE-AUTH','ORIGIN','K-local','K-reservation','K-activation','K-range')){
        $a=$script:pop["$family/accept"];$r=$script:pop["$family/reject"];$k=$script:pop["$family/mutation"]
        Assert "NON-EMPTY POPULATION ${family}: accept, reject and mutation populations are all non-zero" (($a-gt0)-and($r-gt0)-and($k-gt0)) "accept=$a reject=$r mutation=$k"
    }

}finally{
    Remove-Item Env:ORVION_GUARD_MARKER -ErrorAction SilentlyContinue
    Remove-Item Env:ORVION_STUB_LOG -ErrorAction SilentlyContinue
    Remove-Item Env:ORVION_STUB_GH -ErrorAction SilentlyContinue
    Remove-Item Env:ORVION_STUB_GH_LOG -ErrorAction SilentlyContinue
    if(Test-Path $sandbox){Remove-Item -LiteralPath $sandbox -Recurse -Force}
}
Write-Host "AGENT CONTROL TESTS: $($script:pass) passed, $($script:fail) failed"
if($script:fail){exit 1};exit 0




