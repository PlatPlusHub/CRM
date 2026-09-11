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

# Native command output (git) is decoded using the console code page, which on a
# default Windows shell is OEM (ibm437) and silently corrupts every non-ASCII
# character. The contract headings contain an em dash and the prose contains §,
# so a baseline read through git would never compare equal to the same bytes read
# from disk. Force UTF-8 so Git and the working tree agree byte for byte.
try{[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)}catch{}

# ---------------------------------------------------------------------------
# Contract partition (CR_LIFECYCLE.md §8).
#
# FROZEN AUTHORITY  - fixed once the Change Request is Approved. The executing
#                     agent may never alter these, because they are what
#                     authorize it. Compared against the Git baseline on every
#                     Gate; the pre-commit hook therefore makes it impossible
#                     to COMMIT a mutation, and the CI range check re-proves it
#                     across the whole pushed range.
# MUTABLE STATE     - Status (legal transitions only), Runtime Checkpoint,
#                     checkbox state, and the two append-only evidence logs.
#
# The governing Change Request is exempt from ordinary Write Scope checking so
# that synchronization is possible at all. That exemption is only safe because
# of the frozen comparison below: without it, an agent could widen its own
# Write Scope and then write the newly authorized path.
# ---------------------------------------------------------------------------
$script:FrozenSections=@(
    'Objective','Business Reason','Risks','Supersedes / Depends On',
    'Write Scope','Required Reading','Required Capabilities',
    'Additional Verification','Implementation Steps'
)
# Legal Status transitions, CR_LIFECYCLE.md §4. "Unchanged" is always legal;
# Complete and Cancelled are terminal and reach nothing else.
$script:LegalTransitions=@{
    'Draft'       = @('Draft','Approved','Cancelled')
    'Approved'    = @('Approved','In Progress','Cancelled')
    'In Progress' = @('In Progress','Complete','Cancelled')
    'Complete'    = @('Complete')
    'Cancelled'   = @('Cancelled')
}

function Normalize([string]$Text){
    if($null-eq$Text){return ''}
    ($Text-replace"`r`n","`n").Trim()
}

function Section([string]$Text,[string]$Name,[switch]$Optional){
    $m=[regex]::Matches($Text,"(?ms)^## $([regex]::Escape($Name))\s*\r?\n(?<b>.*?)(?=^## |\z)")
    if($m.Count-ne1){
        if($Optional-and$m.Count-eq0){return $null}
        throw "CONTRACT_SECTION_${Name}:count=$($m.Count)"
    }
    $m[0].Groups['b'].Value.Trim()
}

# Out of Scope carries a long em-dashed heading whose exact punctuation has
# varied across contract generations. Match it by prefix so the control plane
# never depends on one dash character.
function Section-OutOfScope([string]$Text){
    $m=[regex]::Matches($Text,'(?ms)^## Out of Scope\b.*?\r?\n(?<b>.*?)(?=^## |\z)')
    if($m.Count-ne1){throw "CONTRACT_SECTION_Out of Scope:count=$($m.Count)"}
    $m[0].Groups['b'].Value.Trim()
}

function Bullets([string]$Body,[string]$Name){
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

# A checklist item may wrap across several lines; collapse each to one
# normalized string so that re-wrapping is not mistaken for rewording.
function ChecklistItems([string]$Body){
    if(!$Body){return @()}
    $items=@()
    foreach($m in [regex]::Matches($Body,'(?ms)^-\s*\[(?<state>[ xX])\]\s*(?<text>.*?)(?=^-\s*\[[ xX]\]|\z)')){
        $items+=[pscustomobject]@{
            Checked=($m.Groups['state'].Value.Trim().ToLowerInvariant()-eq'x')
            Text=(($m.Groups['text'].Value-replace'\s+',' ').Trim())
        }
    }
    $items
}

function Status-FromText([string]$Text){
    $checked=@([regex]::Matches((Section $Text 'Status'),'(?im)^\[x\]\s+(?<v>.+?)\s*$')|%{$_.Groups['v'].Value.Trim()})
    if($checked.Count-ne1-or @('Draft','Approved','In Progress','Complete','Cancelled')-notcontains$checked[0]){throw 'INVALID_CR_STATUS'}
    $checked[0]
}

function Contract([string]$Path){
    if(!(Test-Path -LiteralPath $Path)){throw "STALE_ACTIVE_CR:$Path"}
    $t=Get-Content -Raw -LiteralPath $Path
    $headings=@([regex]::Matches($t,'(?m)^# Change Request — (?<id>SPEC-[0-9]+)\s*$'))
    if($headings.Count-ne1){throw "INVALID_CR_HEADING:count=$($headings.Count)"}
    $id=$headings[0].Groups['id'].Value.ToUpperInvariant();$base=[IO.Path]::GetFileName($Path)
    if($base-notmatch('^'+[regex]::Escape($id)+'-')){throw "CR_ID_PATH_MISMATCH:${base}:${id}"}
    $status=Status-FromText $t

    # The canonical section set of changes/TEMPLATE.md. Applied to the GOVERNING
    # Change Request only: this function is never called on a historical file,
    # every historical Change Request is terminal, and a terminal Change Request
    # is never reopened (CR_LIFECYCLE.md §4). A stricter schema therefore cannot
    # reach history, which is why no contract-format version field is needed.
    foreach($n in @(
        'Objective','Business Reason','Risks','Supersedes / Depends On',
        'Write Scope','Required Reading','Runtime Checkpoint','Required Capabilities',
        'Additional Verification','Implementation Steps','Acceptance Criteria',
        'Execution Log','Verification Notes','Review Gate'
    )){[void](Section $t $n)}
    [void](Section-OutOfScope $t)

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

    [pscustomobject]@{
        Path=$Path;Id=$id;Status=$status;Text=$t
        Resume=$resume.Groups['v'].Value;Blocker=$block.Groups['v'].Value;Attempt=[int]$attempt.Groups['v'].Value
        Steps=@($sm|%{$_.Groups['v'].Value.Trim()})
        Scope=$scope
        Reading=Bullets (Section $t 'Required Reading') 'REQUIRED_READING'
        RequiredCapabilities=Bullets (Section $t 'Required Capabilities') 'REQUIRED_CAPABILITIES'
        AdditionalVerification=$additional
        Acceptance=ChecklistItems (Section $t 'Acceptance Criteria')
        ReviewGate=ChecklistItems (Section $t 'Review Gate')
        ExecutionLog=Normalize (Section $t 'Execution Log')
        VerificationNotes=Normalize (Section $t 'Verification Notes')
    }
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
    foreach($line in $lines){
        $parts=$line-split"`t";$code=$parts[0].Substring(0,1)
        if($code-eq'R'){$records+=[pscustomobject]@{Code='R';Old=($parts[1]-replace'\\','/');Path=($parts[2]-replace'\\','/')}}
        else{$records+=[pscustomobject]@{Code=$code;Old=$null;Path=($parts[1]-replace'\\','/')}}
    }
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

function Historical-Guard-IsActive([string]$Ref){
    if(!$BaseRef){return $true}
    $old=Read-GitFile $Ref 'scripts/check_agent_continuity.ps1'
    $null-ne$old-and$old.Contains('HISTORICAL_CR_MUTATION')
}

function Validate-HistoryAndIds([object[]]$Records,[string]$Ref){
    $historyActive=Historical-Guard-IsActive $Ref
    $newIds=@{}
    foreach($r in $Records){
        if($historyActive){
            foreach($p in @($r.Path,$r.Old)|?{$_}|select -Unique){
                if($p-match'^changes/SPEC-[0-9]+-.*\.md$'){
                    $old=Read-GitFile $Ref $p
                    if($null-ne$old){$s=Status-FromText $old;if($s-in@('Complete','Cancelled')){throw "HISTORICAL_CR_MUTATION:$p"}}
                }
            }
        }
        if($r.Path-match'^changes/(?<id>SPEC-[0-9]+)-.*\.md$' -and $null-eq(Read-GitFile $Ref $r.Path)){
            $id=$Matches['id']
            # Collision validation is repository-wide over EVERY identifier that
            # already exists, synthetic test fixtures included. Allocation of a
            # NEW identifier is a separate rule and excludes the fixture band -
            # conflating the two is what produced SPEC-1000/1001.
            if(Base-HasId $Ref $id){throw "SPEC_ID_ALREADY_USED:$id"}
            # Two newly added files may also collide with each other inside a
            # single diff, where neither exists in the baseline to compare against.
            if($newIds.ContainsKey($id)){throw "DUPLICATE_NEW_SPEC_ID:${id}:$($newIds[$id]),$($r.Path)"}
            $newIds[$id]=$r.Path
        }
    }
}

function Validate-FrozenAuthority([string]$BaselineText,[string]$CurrentText){
    foreach($name in $script:FrozenSections){
        $was=Normalize (Section $BaselineText $name -Optional)
        $now=Normalize (Section $CurrentText $name -Optional)
        if($was-ne$now){throw "FROZEN_AUTHORITY_MUTATED:$name"}
    }
    $wasScope=Normalize (Section-OutOfScope $BaselineText)
    $nowScope=Normalize (Section-OutOfScope $CurrentText)
    if($wasScope-ne$nowScope){throw 'FROZEN_AUTHORITY_MUTATED:Out of Scope'}
}

# `None.`, an empty body, or a bracketed template instruction block all mean
# "no evidence recorded yet" rather than evidence. Writing the FIRST real entry
# must stay legal; only genuine prior evidence is protected.
function EvidenceBody([string]$Raw){
    $v=Normalize $Raw
    if($v-eq''-or$v-eq'None'-or$v-eq'None.'){return ''}
    if($v-match'^\[[\s\S]*\]$'){return ''}
    $v
}

# Prior evidence is never rewritten. Requiring the baseline body to remain an
# exact prefix rejects editing, deleting, reordering and truncating in one rule,
# while leaving appends legal.
function Validate-EvidenceAppendOnly([string]$BaselineText,$Current){
    foreach($pair in @(
        @{Name='Execution Log';Was=(EvidenceBody (Section $BaselineText 'Execution Log' -Optional));Now=(EvidenceBody $Current.ExecutionLog)},
        @{Name='Verification Notes';Was=(EvidenceBody (Section $BaselineText 'Verification Notes' -Optional));Now=(EvidenceBody $Current.VerificationNotes)}
    )){
        if($pair.Was-and-not$pair.Now.StartsWith($pair.Was)){throw "EVIDENCE_NOT_APPEND_ONLY:$($pair.Name)"}
    }
}

# Wording and item count are frozen; only an unchecked box may become checked.
# Otherwise an agent could soften the criteria it is about to certify against.
function Validate-Checklist([object[]]$Was,[object[]]$Now,[string]$Code){
    if($Was.Count-ne$Now.Count){throw "${Code}:count $($Was.Count)->$($Now.Count)"}
    for($i=0;$i-lt$Was.Count;$i++){
        if($Was[$i].Text-ne$Now[$i].Text){throw "${Code}:item $($i+1) reworded"}
        if($Was[$i].Checked-and-not$Now[$i].Checked){throw "${Code}:item $($i+1) uncheckedaftercheck"}
    }
}

# A CI range is a SEQUENCE of transitions, never one transition. Comparing only
# the range endpoints rejects a legal history: `Approved -> In Progress ->
# Complete` is three legal steps whose endpoints are not a legal pair, which is
# exactly how a push carrying both the Execute and the Complete commit failed.
# Walk the statuses that ACTUALLY occurred in commits and validate each step;
# reachability through states nobody committed is never inferred.
function Status-Path([string]$Path,[string]$Base,[string]$Current){
    $seq=@()
    $old=Read-GitFile $Base $Path
    if($null-ne$old){$seq+=(Status-FromText $old)}
    if($BaseRef){
        foreach($commit in @(git -C $Root rev-list --reverse "$BaseRef..$HeadRef" -- $Path)){
            $text=Read-GitFile $commit $Path
            if($null-eq$text){continue}
            $status=Status-FromText $text
            if(!$seq.Count-or$seq[-1]-ne$status){$seq+=$status}
        }
    }
    if($Current-and(!$seq.Count-or$seq[-1]-ne$Current)){$seq+=$Current}
    # Returned unwrapped on purpose: every call site wraps in @(), and the
    # `,$seq` idiom would arrive there as ONE element holding the whole array.
    $seq
}

function Validate-StatusPath([string[]]$Sequence){
    for($i=1;$i-lt$Sequence.Count;$i++){
        $from=$Sequence[$i-1];$to=$Sequence[$i]
        if(-not $script:LegalTransitions.ContainsKey($from)-or$script:LegalTransitions[$from]-notcontains$to){
            throw "ILLEGAL_STATUS_TRANSITION:${from}->${to}"
        }
    }
}

function Validate-CompletionPrerequisites($Contract){
    $unchecked=@($Contract.Acceptance|?{-not$_.Checked})
    if(-not$Contract.Acceptance.Count){throw 'COMPLETION_PREREQUISITE:no Acceptance Criteria'}
    if($unchecked.Count){throw "COMPLETION_PREREQUISITE:$($unchecked.Count) unchecked Acceptance Criterion"}
    $openGate=@($Contract.ReviewGate|?{-not$_.Checked})
    if(-not$Contract.ReviewGate.Count){throw 'COMPLETION_PREREQUISITE:no Review Gate'}
    if($openGate.Count){throw "COMPLETION_PREREQUISITE:$($openGate.Count) unchecked Review Gate item"}
    if($Contract.Blocker-ne'None'){throw "COMPLETION_PREREQUISITE:Blocker $($Contract.Blocker)"}
    if($Contract.Resume-ne'DONE'){throw "COMPLETION_PREREQUISITE:Resume Step $($Contract.Resume)"}
    if($Contract.VerificationNotes-notmatch'(?m)^Verdict:\s*Confirmed Complete\s*$'){throw 'COMPLETION_PREREQUISITE:no Confirmed Complete verdict'}
}

function Resolve-Contract($m,[object[]]$Records){
    if($m.Active){return $m.Active}
    $changed=@($Records|?{$_.Path-match'^changes/SPEC-[0-9]+-.*\.md$'}|%{$_.Path}|select -Unique);$c=@()
    foreach($p in $changed){
        if(Test-Path(Join-Path $Root $p)){try{$x=Contract(Join-Path $Root $p);if($x.Status-eq'Complete'){$c+=$p}}catch{}}
    }
    if(!$BaseRef-and!$c.Count){return $null}
    if(!$c.Count){throw 'NO_GOVERNING_CR'}
    if($c.Count-gt1){throw 'AMBIGUOUS_GOVERNING_CR'}
    $base=if($BaseRef){$BaseRef}else{'HEAD'}
    if($null-eq(Read-GitFile $base $c[0])){throw "INVALID_COMPLETION_TRANSITION:$($c[0])"}
    # Complete is reachable only from In Progress, judged over the path actually
    # committed rather than over the two ends of the range.
    $seq=@(Status-Path $c[0] $base 'Complete')
    if($seq.Count-lt2-or$seq[$seq.Count-2]-ne'In Progress'){throw "INVALID_COMPLETION_TRANSITION:$($c[0])"}
    $c[0]
}

# Change Request state and the manifest active pointer are ONE invariant. An
# executable Change Request with no pointer naming it is unreachable at cold
# start, which is the failure this rejects.
function Validate-ManifestSync([object[]]$Records,[string]$Ref){
    foreach($p in @($Records|?{$_.Path-match'^changes/SPEC-[0-9]+-.*\.md$'}|%{$_.Path}|select -Unique)){
        if(!(Test-Path(Join-Path $Root $p))){continue}
        try{$x=Contract(Join-Path $Root $p)}catch{continue}
        if($x.Status-in@('Approved','In Progress')){throw "ORPHANED_APPROVED_CR:$p"}
    }
}

# ONE authoritative definition of the control-sensitive surface: the files that
# decide how an agent behaves. The previous inline regex omitted GOVERNANCE.md,
# README.md, llms.txt, every thin client adapter and the consistency guard, so a
# change to knowledge governance or to a cold-start route earned no adversarial
# verification at all. A trailing slash means "this directory and below".
function Get-ControlSurface {
    @(
        'AGENTS.md','CR_LIFECYCLE.md','GOVERNANCE.md','changes/TEMPLATE.md',
        'README.md','llms.txt','CLAUDE.md','GEMINI.md',
        '.cursor/rules/orvion.mdc','.github/copilot-instructions.md',
        'scripts/check_agent_continuity.ps1','scripts/test_agent_continuity.ps1',
        'scripts/check_repository_consistency.ps1',
        '.githooks/','.claude/hooks/','.github/workflows/agent-control.yml'
    )
}
function Test-ControlPath([string]$Path){
    foreach($surface in Get-ControlSurface){
        if($surface.EndsWith('/')){if($Path.StartsWith($surface,[StringComparison]::OrdinalIgnoreCase)){return $true}}
        elseif($Path-eq$surface){return $true}
    }
    $false
}

function Profiles($scope){
    $h=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);[void]$h.Add('REPOSITORY')
    foreach($p in $scope){
        if(Test-ControlPath $p){[void]$h.Add('CONTROL')}
        if($p-match'^\.github/workflows/'){[void]$h.Add('CI')}
        if($p-match'^\.workstation/'){[void]$h.Add('WORKSTATION')}
        if($p-match'^(supabase/migrations/|scripts/verify_database\.sql|reports/master/MASTER_DATABASE_)'){[void]$h.Add('DATABASE')}
    }
    @($h|sort)
}

# EVIDENCE_CLASS. Three honest classes:
#   LOCAL      - executable here and now, by this process.
#   POST_PUSH  - exists only after a push, against an exact SHA.
#   EXTERNAL   - observable only from a live system this process cannot reach.
# `LOCAL_CERTIFY: READY` may assert the LOCAL class and nothing else. Previously
# CI, WORKSTATION and DATABASE were derived, printed, executed nothing, and the
# run still ended in READY - stating evidence that had never been observed.
function Get-ProfileEvidence([string]$Profile){
    switch($Profile){
        'REPOSITORY'{[pscustomobject]@{Local=@(
            'pwsh -NoProfile -File scripts/check_repository_consistency.ps1',
            'git diff --check');Deferred=@()}}
        'CONTROL'{[pscustomobject]@{Local=@(
            'pwsh -NoProfile -File scripts/test_agent_continuity.ps1',
            'pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1',
            'pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1',
            'pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1',
            'pwsh -NoProfile -File scripts/test_future_date_guard.ps1');Deferred=@()}}
        'CI'{[pscustomobject]@{Local=@();Deferred=@(
            'POST_PUSH: workflow conclusions on the exact pushed SHA')}}
        'WORKSTATION'{[pscustomobject]@{Local=@();Deferred=@(
            'LOCAL_NOT_EXECUTED: workstation doctor and bootstrap idempotence (AGENTS.md §5)')}}
        'DATABASE'{[pscustomobject]@{Local=@();Deferred=@(
            'LOCAL_NOT_EXECUTED: clean db reset, pgTAP Pass A and B, HTTP suites, smoke (AGENTS.md §5a)',
            'EXTERNAL: Primary ledger, function-surface and structural-surface hashes read from Primary')}}
        default{[pscustomobject]@{Local=@();Deferred=@()}}
    }
}

function Test-Capabilities($c){
    foreach($name in $c.RequiredCapabilities){
        if($name-ne'github'){throw "NO_DETERMINISTIC_CAPABILITY_PROBE:$name"}
        gh auth status *>$null;if($LASTEXITCODE-ne0){throw 'MISSING_REQUIRED_CAPABILITY:github:gh_auth_status'}
        git -C $Root ls-remote origin HEAD *>$null;if($LASTEXITCODE-ne0){throw 'MISSING_REQUIRED_CAPABILITY:github:git_ls_remote'}
    }
}

function Repo-Guard {
    $g=Join-Path $Root 'scripts/check_repository_consistency.ps1';if(!(Test-Path $g)){throw 'REPOSITORY_GUARD_MISSING'}
    $log=Join-Path([IO.Path]::GetTempPath())("orvion-repository-guard-$([guid]::NewGuid().ToString('N')).log")
    & pwsh -NoProfile -File $g *>$log
    if($LASTEXITCODE-ne0-or(Get-Content -Raw $log)-notmatch'REPOSITORY CONSISTENCY: CLEAN'){throw "REPOSITORY_CONSISTENCY_FAILED:$log"}
    Remove-Item -LiteralPath $log -Force;'clean'
}

function Git-State {
    if($BaseRef){Assert-Ref $BaseRef;Assert-Ref $HeadRef;return [pscustomobject]@{Text="range $BaseRef..$HeadRef";Synced=$true}}
    git -C $Root fetch --prune origin *>$null;if($LASTEXITCODE-ne0){throw 'GIT_FETCH_FAILED:origin'}
    git -C $Root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null|Out-Null;if($LASTEXITCODE-ne0){throw 'GIT_UPSTREAM_MISSING'}
    $x=(git -C $Root rev-list --left-right --count 'HEAD...@{u}')-split'\s+';$dirty=@(git -C $Root status --porcelain).Count-gt0
    [pscustomobject]@{Text="$(if($dirty){'dirty'}else{'clean'}) | ahead $($x[0]) / behind $($x[1])";Synced=([int]$x[1]-eq0)}
}

# Success is one line. Failure keeps everything a diagnosis needs: the command,
# the exit code, a diagnostic tail and the full log path. Streaming the entire
# successful child output buried the result it was meant to report.
function Invoke-Verification([string]$Command,[switch]$Additional){
    $log=Join-Path([IO.Path]::GetTempPath())("orvion-verify-$([guid]::NewGuid().ToString('N')).log")
    # `pwsh -Command` collapses a child's exit code to 1, which would report the
    # wrong failure code for every verification command. Propagate it explicitly.
    & pwsh -NoProfile -Command "$Command`nexit `$LASTEXITCODE" *>$log
    $code=$LASTEXITCODE
    if($code-eq0){Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue;Write-Output "PASS: $Command";return}
    Write-Output "FAILED: $Command (exit $code)"
    if(Test-Path -LiteralPath $log){
        Write-Output '--- last 20 lines ---'
        foreach($line in @(Get-Content -LiteralPath $log -Tail 20)){Write-Output $line}
        Write-Output "--- full log: $log"
    }
    if($Additional){throw "ADDITIONAL_VERIFICATION_FAILED:$Command"}
    throw "MANDATORY_VERIFICATION_FAILED:$Command"
}

function Finish-Checks($c,[string[]]$profiles){
    $mandatory=@();$deferred=@()
    foreach($p in $profiles){
        $e=Get-ProfileEvidence $p
        $mandatory+=$e.Local
        foreach($d in $e.Deferred){$deferred+=,([pscustomobject]@{Profile=$p;Note=$d})}
    }
    $mandatory=@($mandatory|Select-Object -Unique)
    # A command derived as mandatory and repeated verbatim in Additional
    # Verification is one piece of evidence, not two. Deduplicate the execution;
    # Additional Verification remains strictly additive.
    $extra=@($c.AdditionalVerification|Where-Object{$mandatory-notcontains$_})
    foreach($command in $mandatory){Invoke-Verification $command}
    foreach($command in $extra){Invoke-Verification $command -Additional}

    $notExecuted=@()
    foreach($d in $deferred){
        Write-Output "EVIDENCE: $($d.Profile) $($d.Note)"
        if($d.Note-like'LOCAL_NOT_EXECUTED:*'){$notExecuted+=$d.Profile}
    }
    if($notExecuted.Count){
        Write-Output "LOCAL_CERTIFY: INCOMPLETE — $((@($notExecuted|Select-Object -Unique))-join', ') local evidence was not executed by this process"
    }else{
        Write-Output 'LOCAL_CERTIFY: READY'
    }
}

function Block($message){
    if($message-eq'RECOVERY_EXHAUSTED'){Write-Output 'HARD_BLOCKED: RECOVERY_EXHAUSTED';return}
    $p=$message-split':',2
    Write-Output 'ORVION: BLOCKED'
    Write-Output "CODE: $($p[0])"
    if($p.Count-gt1){Write-Output "SUBJECT: $($p[1])"}
    Write-Output "EVIDENCE: $message"
    Write-Output 'NEXT: inspect the named authority/evidence, repair within Write Scope, then rerun.'
}

try{
    Set-Location $Root
    if(!(Test-Path(Join-Path $Root 'AGENTS.md'))){throw 'AGENTS_MISSING'}
    if($BaseRef){Assert-Ref $BaseRef;Assert-Ref $HeadRef}

    $records=@(Diff-Records);$base=if($BaseRef){$BaseRef}else{'HEAD'}
    Validate-HistoryAndIds $records $base
    $m=Manifest;$rel=Resolve-Contract $m $records;$repo=Repo-Guard;$git=Git-State
    if(!$git.Synced){throw "GIT_NOT_SYNCHRONIZED:$($git.Text)"}

    if(!$rel){
        Validate-ManifestSync $records $base
        $bad=@($records|?{
            if($_.Path-notmatch'^changes/SPEC-[0-9]+-.*\.md$'){return $true}
            try{$draft=Contract(Join-Path $Root $_.Path);return $draft.Status-notin@('Draft','Approved')}catch{return $true}
        })
        if($bad.Count){throw "NO_GOVERNING_CR:$((@($bad|%{$_.Path})|sort -Unique)-join',')"}
        Write-Output 'ORVION: READY';Write-Output 'MODE: PLAN';Write-Output 'ACTIVE_CR: none'
        Write-Output "NEXT_CAPABILITY: $($m.Next)"
        Write-Output 'WRITE_AUTHORITY: none (Draft CR authoring only)'
        Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo"
        exit 0
    }

    $c=Contract(Join-Path $Root $rel);$completionTransition=(-not$m.Active)

    # The authority that governs this run must be exactly the authority that was
    # approved. A Change Request absent from the baseline is newly created and
    # has no approved version to contradict.
    $baselineText=Read-GitFile $base ($rel-replace'\\','/')
    if($null-ne$baselineText){
        $baselineStatus=Status-FromText $baselineText
        Validate-FrozenAuthority $baselineText $c.Text
        Validate-EvidenceAppendOnly $baselineText $c
        Validate-Checklist (ChecklistItems (Section $baselineText 'Acceptance Criteria' -Optional)) $c.Acceptance 'ACCEPTANCE_TEXT_MUTATED'
        Validate-Checklist (ChecklistItems (Section $baselineText 'Review Gate' -Optional)) $c.ReviewGate 'REVIEW_GATE_TEXT_MUTATED'
        Validate-StatusPath @(Status-Path ($rel-replace'\\','/') $base $c.Status)
        if($baselineStatus-ne'Complete'-and$c.Status-eq'Complete'){Validate-CompletionPrerequisites $c}
    }

    $mode=switch($c.Status){
        'Draft'{'READY_FOR_APPROVAL'}
        {$_-in@('Approved','In Progress')}{if($c.Blocker-ne'None'){if($c.Attempt-eq3){throw 'RECOVERY_EXHAUSTED'};'BLOCKED'}elseif($c.Resume-eq'DONE'){'VERIFY'}else{'EXECUTE'}}
        'Complete'{if($completionTransition){'VERIFY'}else{'BLOCKED'}}
        default{'BLOCKED'}
    }
    if($mode-eq'BLOCKED'){throw "RUNTIME_BLOCKED:$($c.Blocker)"}
    if(!$BaseRef){Test-Capabilities $c}

    $scope=@($c.Scope|%{$_-replace'\\','/'})
    foreach($r in $records){
        foreach($p in @($r.Path,$r.Old)|?{$_}){
            if($p-ne($rel-replace'\\','/')-and$scope-notcontains$p){throw "OUT_OF_SCOPE_WRITE:$p"}
        }
    }

    $profiles=Profiles $c.Scope
    if($Finish-and$mode-ne'VERIFY'){throw "FINISH_NOT_READY:$mode"}

    Write-Output 'ORVION: READY';Write-Output "MODE: $mode";Write-Output "CR: $($c.Id)";Write-Output "STATUS: $($c.Status)"
    Write-Output "STEP: $(if($c.Resume-eq'DONE'){'DONE'}else{"$($c.Resume)/$($c.Steps.Count)"})"
    if($mode-eq'EXECUTE'){Write-Output 'ACTION:';Write-Output $c.Steps[[int]$c.Resume-1]}
    Write-Output "WRITE: $($c.Scope-join', ')"
    Write-Output "START_CONTEXT: $($c.Reading-join', ')"
    Write-Output "VERIFICATION: $((@($profiles)+@($c.AdditionalVerification))-join', ')"
    Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo";Write-Output "BLOCKER: $($c.Blocker.ToLowerInvariant())"
    if($Finish){Finish-Checks $c $profiles}
}catch{
    if($Finish){Write-Output 'CERTIFY: FAILED'}
    Block $_.Exception.Message
    exit 1
}
