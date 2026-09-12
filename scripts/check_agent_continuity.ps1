[CmdletBinding(DefaultParameterSetName='Boot')]
param(
    [Parameter(ParameterSetName='Boot',Mandatory=$true)][switch]$Boot,
    [Parameter(ParameterSetName='Gate',Mandatory=$true)][switch]$Gate,
    [Parameter(ParameterSetName='Finish',Mandatory=$true)][switch]$Finish,
    [Parameter(ParameterSetName='Certify',Mandatory=$true)][switch]$Certify,
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

# ---------------------------------------------------------------------------
# HISTORY-SENSITIVE invariants, judged over the commits a range actually
# contains (SPEC-167).
#
# `Diff-Records` computes a NET `BaseRef..HeadRef` diff, so every check built on
# its records judges the range's two ENDPOINTS. `Status-Path` was the single
# exception, and even it was walked for the resolved GOVERNING contract alone.
# A commit that violates an invariant plus a later commit that undoes it are
# therefore invisible: the violation was committed, is part of the history being
# admitted, and nothing looks at it.
#
# Four classes are defined as forbidden to have OCCURRED, not merely forbidden
# to survive to HEAD:
#
#   - a write outside the approved Write Scope;
#   - a widening of frozen authority (the widened scope would also authorise
#     that commit's own writes, so scope is read from the baseline, never from
#     the contract as it stood at the offending commit);
#   - a modification to a contract after it became terminal inside this range;
#   - an illegal Status transition in a contract that is not the governing one.
#
# This is deliberately NOT "every intermediate commit must independently be
# releasable". A work-in-progress commit is legal, and FINAL-STATE properties -
# the manifest pointer, completion prerequisites, certification - are correctly
# judged at HEAD alone and are not re-checked per commit. Only the invariants
# the repository defines as history-sensitive are audited here.
#
# ORVION history is linear (`main` carries non-fast-forward protection and the
# acceptance model forbids merge-generated SHAs), so each commit is compared
# against its first parent without special merge handling.
function Validate-CommittedRange([string]$Rel){
    $commits=@(git -C $Root rev-list --reverse "$BaseRef..$HeadRef")
    if(!$commits.Count){return}
    $governing=$Rel-replace'\\','/'

    # The effective frozen baseline is the governing contract AS APPROVED: its
    # text at the range base when it exists there, otherwise at its first
    # appearance inside the range. The fallback is what keeps a contract that is
    # born and completed in one push legal (SPEC-165) - demanding a base version
    # would refuse exactly that history.
    $FrozenBaseline=Read-GitFile $BaseRef $governing

    $terminal=@{};$touched=@{}

    foreach($commit in $commits){
        $short=$commit.Substring(0,7)
        $paths=@()
        foreach($line in @(git -C $Root diff --name-status -M "$commit^" $commit --)){
            $parts=$line-split"`t"
            if($parts[0].Substring(0,1)-eq'R'){$paths+=($parts[1]-replace'\\','/');$paths+=($parts[2]-replace'\\','/')}
            else{$paths+=($parts[1]-replace'\\','/')}
        }
        $paths=@($paths|Sort-Object -Unique)

        # A contract that was terminal at an EARLIER commit in this range is
        # historical from that point on. Validate-HistoryAndIds already rejects
        # touching one that was terminal BEFORE the range; this is the same rule
        # for one that closed inside it.
        foreach($p in $paths){
            if($terminal.ContainsKey($p)){throw "HISTORICAL_CR_MUTATION:${p}@$short"}
            if($p-match'^changes/SPEC-[0-9]+-.*\.md$'){$touched[$p]=$true}
        }

        if($null-eq$FrozenBaseline-and$paths-contains$governing){$FrozenBaseline=Read-GitFile $commit $governing}

        if($null-ne$FrozenBaseline){
            $text=Read-GitFile $commit $governing
            if($null-ne$text){
                try{Validate-FrozenAuthority $FrozenBaseline $text}catch{throw "$($_.Exception.Message)@$short"}
            }
            # Scope comes from the frozen baseline on purpose: a commit that
            # widened its own Write Scope must not thereby authorise its own writes.
            $scopeAt=@(Bullets (Section $FrozenBaseline 'Write Scope') 'WRITE_SCOPE'|%{$_-replace'\\','/'})
            foreach($p in $paths){
                if($p-ne$governing-and$scopeAt-notcontains$p){throw "OUT_OF_SCOPE_WRITE:${p}@$short"}
            }
        }

        # Recorded AFTER this commit's own checks, so the commit that CLOSES a
        # contract is itself legal and only later ones are refused.
        foreach($p in $paths){
            if($p-notmatch'^changes/SPEC-[0-9]+-.*\.md$'){continue}
            $t=Read-GitFile $commit $p
            if($null-ne$t){try{if((Status-FromText $t)-in@('Complete','Cancelled')){$terminal[$p]=$true}}catch{}}
        }
    }

    # Every contract the range touched is judged by the same transition matrix as
    # the governing one. Walking only the governing contract let a valid
    # corrective Change Request carry an invalid earlier one through.
    foreach($p in @($touched.Keys|Sort-Object)){Validate-StatusPath @(Status-Path $p $BaseRef $null)}
}

# ---------------------------------------------------------------------------
# LOCAL certification receipt (SPEC-164).
#
# `AGENTS.md` says only a successful Finish permits Review/Complete, but every
# completion prerequisite below is TEXT an agent writes about itself: tick the
# boxes, write `Verdict: Confirmed Complete`, set `Resume Step: DONE`, flip the
# Status. None of that requires `-Finish` to have run, so work could reach
# Complete having never obtained `LOCAL_CERTIFY: READY`.
#
# The smallest mechanism that closes it is a receipt Finish writes only on its
# success path, bound to the implementation state it certified. A boolean would
# not do: it survives an edit made after certification, which is precisely the
# stale-evidence case. The fingerprint therefore covers the Write Scope's file
# CONTENT, and skips exactly the two files the completion act itself rewrites -
# the governing contract and the manifest pointer - because including them would
# make every receipt stale the instant completion began.
#
# WHAT THIS PROVES, AND WHAT IT DOES NOT. It is an anti-omission and
# anti-staleness control, not a trust boundary: the same process writes and
# reads it, so it resists forgetting and drift, never a deliberate forgery. It
# is untracked and gitignored, because it is an observation about one working
# tree at one moment, not repository truth - and CI, which holds no receipt,
# re-executes the certification itself rather than trusting a recorded one.
# ---------------------------------------------------------------------------
$script:ReceiptName='.orvion-local-certification.json'
function Receipt-Path{Join-Path $Root $script:ReceiptName}

function Implementation-Fingerprint($Contract,[string]$Rel){
    $skip=@($Rel,'_ORVION_CANONICAL/manifest.md')
    $sha=[Security.Cryptography.SHA256]::Create()
    $acc=[Text.StringBuilder]::new()
    foreach($p in @($Contract.Scope|%{$_-replace'\\','/'}|Sort-Object)){
        if($skip-contains$p){continue}
        $full=Join-Path $Root $p
        # `absent` is recorded rather than skipped, so creating or deleting a
        # scoped file after certification is itself a fingerprint change.
        $h='absent'
        if(Test-Path -LiteralPath $full -PathType Leaf){
            $h=([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($full)))-replace'-','').ToLowerInvariant()
        }
        [void]$acc.Append("$p $h`n")
    }
    ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($acc.ToString())))-replace'-','').ToLowerInvariant()
}

# Which workflows MUST have run for this change, derived from the workflow files
# themselves so no second authority for CI expectations is created. A workflow that
# declares `push:` with no `paths:` filter always runs; one with a filter runs only
# when a written path matches it. A workflow with no `push:` trigger at all is never
# expected from a push, which is what keeps review-only workflows out of the set.
#
# The glob translation handles exactly the three forms this repository uses - an exact
# path, a `prefix/**` subtree and a `**/*.ext` suffix. That is deliberate: a general
# path-expression engine would be a new mechanism with its own failure modes, and an
# unrecognized form is better caught by a false expectation than by a silent miss.
function Glob-Regex([string]$Pattern){
    '^'+([regex]::Escape($Pattern)-replace'\\\*\\\*/','(?:.*/)?'-replace'\\\*\\\*','.*'-replace'\\\*','[^/]*')+'$'
}
# One trigger sub-key's values, in EITHER YAML style: an inline flow sequence
# (`branches: [a, b]`) or `- item` bullets beneath the key. Both styles are legal
# GitHub syntax and a reader that knows only one of them is silently wrong about
# the other. The key is matched exactly, so `paths:` never also swallows
# `paths-ignore:`.
function Trigger-List([string]$Body,[string]$Key){
    $m=[regex]::Match($Body,"(?m)^[ \t]*$([regex]::Escape($Key)):[ \t]*(?<inline>\[[^\]\r\n]*\])?[ \t]*\r?\n?")
    if(!$m.Success){return @()}
    if($m.Groups['inline'].Success){
        return @($m.Groups['inline'].Value.Trim('[',']')-split','|%{$_.Trim().Trim('"').Trim("'")}|?{$_})
    }
    $items=@()
    foreach($line in @($Body.Substring($m.Index+$m.Length)-split'\r?\n')){
        if($line-match'^\s*-\s*"?(?<v>[^"\r\n]+?)"?\s*$'){$items+=$Matches['v'].Trim()}
        elseif($line.Trim()){break}
    }
    $items
}

function Workflow-Expectations([string[]]$Paths){
    $dir=Join-Path $Root '.github/workflows'
    if(!(Test-Path -LiteralPath $dir)){return @()}
    # A workflow is expected only on a branch it can actually RUN on. Without this the
    # deriver read every list item under `push:` as a path glob, so a `branches:` filter
    # either vanished entirely - inline flow style produces no `- item` lines, leaving the
    # workflow looking unfiltered and therefore expected on every branch it can never run
    # on - or was compared against written file paths as though a branch name were one,
    # which yields the right answer only because branch names rarely look like paths.
    # `-Certify` fails closed on an expected workflow that produced no run, so the first
    # case turns every later push red on a workflow that was never going to trigger.
    $branch=(git -C $Root rev-parse --abbrev-ref HEAD 2>$null)
    $branch=if($LASTEXITCODE-eq0){("$branch").Trim()}else{''}
    $names=@()
    foreach($f in @(Get-ChildItem -LiteralPath $dir -File|Where-Object{$_.Extension-in @('.yml','.yaml')})){
        $text=[IO.File]::ReadAllText($f.FullName)
        $name=[regex]::Match($text,'(?m)^name:\s*(?<v>.+?)\s*$');if(!$name.Success){continue}
        # The `push:` block is everything indented deeper than it, so the sibling
        # `pull_request:` trigger at the same indent ends the capture. Reading the whole
        # file instead is how a guard once reported CLEAN on two lists that disagreed.
        $push=[regex]::Match($text,'(?ms)^  push:[ \t]*\r?\n(?<b>(?:[ \t]{4,}.*\r?\n|[ \t]*\r?\n)*)')
        if(!$push.Success){continue}
        $body=$push.Groups['b'].Value
        # Branch filters decide WHETHER this workflow runs here at all, so they are
        # settled before path filters, which only decide whether a run that could
        # happen actually does. Branch names may themselves be globs (`release/**`),
        # so the same matcher serves both.
        $branchList=@(Trigger-List $body 'branches')
        if($branchList.Count-and-not@($branchList|?{$branch-match(Glob-Regex $_)}).Count){continue}
        $branchIgnore=@(Trigger-List $body 'branches-ignore')
        if($branchIgnore.Count-and@($branchIgnore|?{$branch-match(Glob-Regex $_)}).Count){continue}
        $globs=@(Trigger-List $body 'paths')
        if(!$globs.Count){$names+=$name.Groups['v'].Value;continue}
        foreach($g in $globs){
            $rx=Glob-Regex $g
            if(@($Paths|Where-Object{$_-match$rx}).Count){$names+=$name.Groups['v'].Value;break}
        }
    }
    @($names|Sort-Object -Unique)
}

function Write-Certification($Contract,[string]$Rel,[string[]]$Profiles){
    $receipt=[ordered]@{
        cr=$Contract.Id
        profiles=@($Profiles|Sort-Object)
        fingerprint=(Implementation-Fingerprint $Contract $Rel)
        # Derived ONCE, here, and read back by -Certify. Re-deriving it after the push
        # would make the completed task's own surface a second authority.
        expected=@(Workflow-Expectations @($Contract.Scope|%{$_-replace'\\','/'}))
        result='READY'
        at=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    [IO.File]::WriteAllText((Receipt-Path),(ConvertTo-Json $receipt -Depth 4),(New-Object Text.UTF8Encoding($false)))
}

function Validate-Certification($Contract,[string]$Rel,[string[]]$Profiles){
    $path=Receipt-Path
    if(!(Test-Path -LiteralPath $path)){throw 'COMPLETION_PREREQUISITE:no local certification receipt - run -Finish and earn LOCAL_CERTIFY: READY first'}
    try{$receipt=Get-Content -Raw -LiteralPath $path|ConvertFrom-Json}catch{throw 'COMPLETION_PREREQUISITE:unreadable local certification receipt'}
    if($receipt.result-ne'READY'){throw "COMPLETION_PREREQUISITE:certification result $($receipt.result)"}
    if($receipt.cr-ne$Contract.Id){throw "COMPLETION_PREREQUISITE:certification receipt names $($receipt.cr), not $($Contract.Id)"}
    $certified=(@($receipt.profiles|Sort-Object)-join',');$derived=(@($Profiles|Sort-Object)-join',')
    if($certified-ne$derived){throw "COMPLETION_PREREQUISITE:certification profiles $certified do not match the derived $derived"}
    if($receipt.fingerprint-ne(Implementation-Fingerprint $Contract $Rel)){throw 'COMPLETION_PREREQUISITE:stale certification receipt - the implementation changed after it was certified'}
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
    # A contract may be BORN AND DIE inside one pushed range, which is the ordinary
    # shape of a small Change Request (SPEC-165). Requiring it to exist at the range
    # base refused that legal history - the `SPEC-164` push carried create, Approve,
    # implement, Review and Complete together and CI rejected it. The test was
    # redundant, not protective: the path below already rejects a single commit that
    # creates a contract as Complete (a one-element path) and a `Draft -> Complete`
    # pair (Draft immediately before Complete). Same defect class as SPEC-162, one
    # layer down - judge the transitions that occurred, never the range's endpoints.
    #
    # Complete is reachable only from In Progress, judged over the path actually
    # committed rather than over the two ends of the range.
    $seq=@(Status-Path $c[0] $base 'Complete')
    if($seq.Count-lt2-or$seq[$seq.Count-2]-ne'In Progress'){throw "INVALID_COMPLETION_TRANSITION:$($c[0])"}
    $c[0]
}

# Change Request state and the manifest active pointer are ONE invariant, and it
# holds in BOTH directions over every contract on disk - not merely over those in
# the current diff, which could never see an orphan that already existed before
# this change began.
#
#   Approved / In Progress  -> executable. At most one may exist, and the manifest
#                              must name exactly it. An unpointed executable
#                              contract is unreachable at cold start.
#   Draft / Complete / Cancelled -> the manifest must never name it. A Draft named
#                              as active made Boot print that contract's full
#                              Write Scope on its WRITE: line, which contradicts
#                              AGENTS.md 1 - only Approved or In Progress grants
#                              write authority. A weaker agent reading WRITE: as
#                              its permission would write files nobody approved.
#
# Status is READ from each contract's own Status section and never copied
# anywhere, so the manifest remains the sole holder of the pointer and no second
# source of truth for Change Request state is created.
function Contract-Statuses {
    $dir=Join-Path $Root 'changes'
    $map=@{}
    if(!(Test-Path -LiteralPath $dir)){return $map}
    foreach($f in @(Get-ChildItem -LiteralPath $dir -Filter 'SPEC-*.md' -File)){
        # A historical contract predating the current Status vocabulary cannot be
        # classified; it is terminal by definition and is skipped rather than
        # guessed at.
        try{$map['changes/'+$f.Name]=Status-FromText ([IO.File]::ReadAllText($f.FullName))}catch{}
    }
    $map
}
function Validate-ManifestCrState($m){
    $statuses=Contract-Statuses
    $active=if($m.Active){$m.Active-replace'\\','/'}else{$null}
    # A pointer naming no readable contract is diagnosed precisely by Contract()
    # as STALE_ACTIVE_CR. Returning here keeps that specific message instead of
    # pre-empting it with an orphan report about some unrelated file.
    if($active-and-not$statuses.ContainsKey($active)){return}
    if($active-and$statuses[$active]-notin@('Approved','In Progress')){
        throw "MANIFEST_CR_CONTRADICTION:$($statuses[$active]):$active"
    }
    foreach($p in @($statuses.Keys|Where-Object{$statuses[$_]-in@('Approved','In Progress')}|Sort-Object)){
        if($p-ne$active){throw "ORPHANED_APPROVED_CR:$p"}
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
        # This surface must not disagree with `.github/workflows/migration-ci.yml`.
        # It omitted `supabase/tests/` and `supabase/config.toml`, so a change to a
        # pgTAP test or to the stack's configuration was database-sensitive to remote
        # CI and ordinary to local certification - two authorities answering the same
        # question differently, which is how one of them ends up trusted wrongly.
        if($p-match'^(supabase/migrations/|supabase/tests/|supabase/config\.toml$|scripts/verify_database\.sql|reports/master/MASTER_DATABASE_)'){[void]$h.Add('DATABASE')}
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
#
# The one step of the DATABASE protocol no rule can derive. "Relevant HTTP suites"
# is a judgement about which surfaces this change touches, so the contract makes it
# in `Additional Verification` and this slot marks where the answer belongs in the
# order. Silence is refused rather than read as "none apply".
$script:HttpSuiteSlot='<HTTP SUITES NAMED IN ADDITIONAL VERIFICATION>'
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
        # The doctor is read-only and deterministic, so it is EXECUTED rather than
        # deferred. Bootstrap idempotence mutates the workstation and is therefore
        # never run automatically - but its exact command is named, so a weaker
        # agent does not have to re-derive it.
        'WORKSTATION'{[pscustomobject]@{Local=@(
            'pwsh -NoProfile -File .workstation/doctor.ps1');Deferred=@(
            'LOCAL_NOT_EXECUTED: bootstrap idempotence — run `.workstation/prepare.ps1` twice and compare; mutating, never automatic')}}
        # The `ENGINEERING_METHOD.md §4` protocol, EXECUTED in its documented order.
        #
        # These commands are destructive and slow, which is why they never run inside a
        # Gate - `Finish-Checks` is reached only under `-Finish`. Listing them without
        # running them was truthful and useless: the profile could only ever withhold
        # certification, so a weaker agent's options were permanent incompleteness or
        # completing without it. "Could not execute" still never becomes green; it now
        # becomes a named failure with an exit code instead of a standing excuse.
        #
        # pgTAP appears TWICE on purpose: Pass A proves the migrations' own invariants
        # on a clean database, and Pass B re-proves them after the HTTP suites have
        # written through the API. Only Pass B can catch a suite that corrupts state.
        'DATABASE'{[pscustomobject]@{Local=@(
            'npx supabase db reset',
            'npx supabase test db',
            $script:HttpSuiteSlot,
            'npx supabase test db',
            # Expressed as a PowerShell pipeline: `<` input redirection is reserved and
            # not valid PowerShell, so the shell form documented for bash cannot run here.
            'Get-Content -Raw scripts/verify_database.sql | docker exec -i supabase_db_ORVION psql -v ON_ERROR_STOP=1 -U postgres -d postgres -f -',
            'pwsh -NoProfile -File scripts/check_database_parity.ps1');Deferred=@(
            'EXTERNAL: Primary ledger, function-surface and structural-surface hashes read from Primary')}}
        default{[pscustomobject]@{Local=@();Deferred=@()}}
    }
}

# Capability registry. Two honest classes and one closed door:
#   LOCAL_PROBE       - this process can prove it here and now, so it does.
#   EXTERNAL_EVIDENCE - a connector reachable only from the agent's own runtime.
#                       It is DECLARED and reported as unproven. PowerShell must
#                       never manufacture a green for a connector it cannot see.
# A name absent from this table still fails closed, because an unknown capability
# is never assumed present. Only capabilities ORVION actually uses are listed:
# the three local ones are real commands, and the four external ones are exactly
# the MCP servers `.workstation/doctor.ps1` verifies in `.mcp.json`.
$script:Capabilities=@{
    'github'          =@{Class='LOCAL_PROBE';Probe={
        gh auth status *>$null;if($LASTEXITCODE-ne0){throw 'MISSING_REQUIRED_CAPABILITY:github:gh_auth_status'}
        git -C $Root ls-remote origin HEAD *>$null;if($LASTEXITCODE-ne0){throw 'MISSING_REQUIRED_CAPABILITY:github:git_ls_remote'}}}
    'docker'          =@{Class='LOCAL_PROBE';Probe={
        docker info *>$null;if($LASTEXITCODE-ne0){throw 'MISSING_REQUIRED_CAPABILITY:docker:docker_info'}}}
    'supabase-local'  =@{Class='LOCAL_PROBE';Probe={
        docker info *>$null;if($LASTEXITCODE-ne0){throw 'MISSING_REQUIRED_CAPABILITY:supabase-local:docker_info'}
        if(!(Test-Path -LiteralPath (Join-Path $Root 'node_modules/.bin/supabase.cmd'))-and
           !(Test-Path -LiteralPath (Join-Path $Root 'node_modules/.bin/supabase'))){
            throw 'MISSING_REQUIRED_CAPABILITY:supabase-local:project_cli_missing'}}}
    # An EXTERNAL_EVIDENCE capability may carry an `Evidence` command: the repository's
    # own validator for the RECORDED evidence that connector left behind. Declaring
    # `supabase-primary` therefore makes `check_primary_ledger.ps1` mandatory under
    # Finish, which is what separates DECLARED from PROVEN. What it proves is bounded
    # and stated: the recorded ledger is internally self-consistent, attributable to
    # this history, and equal to the repository's migration set. It is not a live read,
    # and the Note says so rather than letting the green imply one.
    'supabase-primary'=@{Class='EXTERNAL_EVIDENCE'
                         Note='recorded Primary evidence, validated by `scripts/check_primary_ledger.ps1` — attributable and current, never a live read'
                         Evidence='pwsh -NoProfile -File scripts/check_primary_ledger.ps1'}
    'postgres-local'  =@{Class='EXTERNAL_EVIDENCE';Note='declared by the contract, unprovable by this process'}
    'n8n'             =@{Class='EXTERNAL_EVIDENCE';Note='declared by the contract, unprovable by this process'}
    'context7'        =@{Class='EXTERNAL_EVIDENCE';Note='declared by the contract, unprovable by this process'}
}

# A contract whose derived profiles include DATABASE must say the two things the
# protocol cannot derive, and must say them before anything runs. Both fail at Boot
# with a precise code rather than halfway through a destructive reset.
function Validate-DatabaseContract($c,[string[]]$profiles){
    if($profiles-notcontains'DATABASE'){return}
    if($c.RequiredCapabilities-notcontains'supabase-local'){throw 'DATABASE_CAPABILITY_NOT_DECLARED:supabase-local'}
    if(-not @($c.AdditionalVerification|Where-Object{$_-match'scripts/verify_'}).Count){throw 'DATABASE_HTTP_SUITE_NOT_NAMED:no scripts/verify_* suite named in Additional Verification'}
}
function Test-Capabilities($c){
    $declared=@()
    foreach($name in $c.RequiredCapabilities){
        if(-not $script:Capabilities.ContainsKey($name)){throw "NO_DETERMINISTIC_CAPABILITY_PROBE:$name"}
        $entry=$script:Capabilities[$name]
        if($entry.Class-eq'LOCAL_PROBE'){& $entry.Probe}else{$declared+=$name}
    }
    # Returned unwrapped: the call site wraps in @(), where the `,$declared`
    # idiom would arrive as ONE element holding the whole array.
    $declared
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

function Finish-Checks($c,[string[]]$profiles,[string]$rel){
    # A previous receipt is destroyed FIRST. A Finish that fails must never leave a
    # READY receipt behind for the completion Gate to find.
    Remove-Item -LiteralPath (Receipt-Path) -Force -ErrorAction SilentlyContinue
    $mandatory=@();$deferred=@();$seen=@{}
    foreach($p in $profiles){
        $e=Get-ProfileEvidence $p
        foreach($command in $e.Local){
            $expanded=if($command-eq$script:HttpSuiteSlot){@($c.AdditionalVerification|Where-Object{$_-match'scripts/verify_'})}else{@($command)}
            foreach($one in $expanded){
                # Deduplicated ACROSS profiles only. A command one profile lists twice is
                # listed twice deliberately - pgTAP runs after the reset and again after
                # the HTTP suites - and a flat unique filter silently deleted Pass B,
                # which is the only pass that can catch a suite corrupting state.
                if($seen.ContainsKey($one)-and$seen[$one]-ne$p){continue}
                $seen[$one]=$p;$mandatory+=$one
            }
        }
        foreach($d in $e.Deferred){$deferred+=,([pscustomobject]@{Profile=$p;Note=$d})}
    }
    # A declared EXTERNAL_EVIDENCE capability that has a repository-local validator for
    # its RECORDED evidence runs that validator here. Declaring a connector must cost
    # something, or "declared" silently reads as "proven".
    foreach($name in $c.RequiredCapabilities){
        $entry=$script:Capabilities[$name]
        if($entry-and$entry.Evidence-and$mandatory-notcontains$entry.Evidence){$mandatory+=$entry.Evidence}
    }
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
        Write-Certification $c $rel $profiles
        Write-Output 'LOCAL_CERTIFY: READY'
    }
}

# POST_PUSH evidence has exactly ONE honest owner, and it is this.
#
# An Acceptance Criterion reading "the workflows are green on the exact final SHA"
# cannot be true when it is ticked: the commit that CREATES that SHA has not been
# made, let alone pushed. That circularity is why a Change Request once reached
# Complete while CI was red. The claim therefore belongs here - made after the
# push, by machine, against the SHA that actually exists - and never in a
# checkbox that Complete depends on.
# EXPECTED is compared against OBSERVED before any conclusion is judged (SPEC-164).
# Asking only "did anything fail?" cannot see a required workflow that stopped
# triggering: it produces no run, so there is nothing to fail, and the remaining green
# workflow certifies the push on its own. The expected set comes from the receipt, so
# this function derives nothing and adds no second authority.
function Certify-Remote {
    $sha=(git -C $Root rev-parse HEAD).Trim()
    Write-Output "SHA: $sha"
    $path=Receipt-Path
    if(!(Test-Path -LiteralPath $path)){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: no local certification receipt — the expected workflow set is unknown, so nothing can be proven. Run -Finish, then push, then certify.'
        exit 1
    }
    try{$receipt=Get-Content -Raw -LiteralPath $path|ConvertFrom-Json}catch{
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: the local certification receipt is unreadable'
        exit 1
    }
    $expected=@($receipt.expected|Where-Object{$_})
    if(!$expected.Count){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: the local certification receipt records no expected workflow set'
        exit 1
    }
    Write-Output "EXPECTED: $((@($expected)|Sort-Object)-join', ')"
    $raw=gh run list --commit $sha --json workflowName,conclusion,status 2>$null
    if($LASTEXITCODE-ne0-or!$raw){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: gh could not read workflow runs for this SHA'
        exit 1
    }
    $runs=@($raw|ConvertFrom-Json)
    if(!$runs.Count){
        Write-Output 'REMOTE_CERTIFY: PENDING'
        Write-Output 'EVIDENCE: no workflow run exists for this SHA yet — push it, or wait for the run to start'
        exit 1
    }
    foreach($r in $runs){Write-Output "RUN: $($r.workflowName) $($r.status)/$($r.conclusion)"}
    $observed=@($runs|ForEach-Object{$_.workflowName}|Sort-Object -Unique)
    $missing=@($expected|Where-Object{$observed-notcontains$_}|Sort-Object)
    $running=@($runs|Where-Object{$_.status-ne'completed'})
    # A required workflow that has not appeared YET is PENDING while anything is still
    # settling, and FAILED once every observed run has completed without it. Both are
    # NOT READY; the distinction only tells the reader whether waiting can still help.
    if($missing.Count-and$running.Count){
        Write-Output 'REMOTE_CERTIFY: PENDING'
        Write-Output "EVIDENCE: REQUIRED_WORKFLOW_MISSING so far: $($missing-join', ') — $($running.Count) run(s) on this SHA have not completed"
        exit 1
    }
    if($missing.Count){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: REQUIRED_WORKFLOW_MISSING: $($missing-join', ') produced no run on this SHA. Success on any other SHA proves nothing about this one."
        exit 1
    }
    if($running.Count){
        Write-Output 'REMOTE_CERTIFY: PENDING'
        Write-Output "EVIDENCE: $($running.Count) run(s) still in progress on this SHA"
        exit 1
    }
    $bad=@($runs|Where-Object{$_.conclusion-ne'success'})
    if($bad.Count){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: $((@($bad|ForEach-Object{$_.workflowName})|Sort-Object -Unique)-join', ')"
        exit 1
    }
    Write-Output 'REMOTE_CERTIFY: READY'
    # Exits directly rather than returning a code: this function WRITES its
    # result, so a returned value would join that output stream and the caller
    # would fall through into the Boot pipeline instead of stopping.
    exit 0
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
    if($Certify){Certify-Remote}
    if($BaseRef){Assert-Ref $BaseRef;Assert-Ref $HeadRef}

    $records=@(Diff-Records);$base=if($BaseRef){$BaseRef}else{'HEAD'}
    Validate-HistoryAndIds $records $base
    $m=Manifest
    $rel=Resolve-Contract $m $records;$repo=Repo-Guard;$git=Git-State
    if(!$git.Synced){throw "GIT_NOT_SYNCHRONIZED:$($git.Text)"}

    if(!$rel){
        Validate-ManifestCrState $m
        # PLAN permits authoring a Draft and nothing else. `Approved` is not listed
        # because Validate-ManifestCrState already rejects an approved contract the
        # manifest does not name, so allowing it here would describe a state the
        # control plane refuses one step earlier.
        $bad=@($records|?{
            if($_.Path-notmatch'^changes/SPEC-[0-9]+-.*\.md$'){return $true}
            try{$draft=Contract(Join-Path $Root $_.Path);return $draft.Status-ne'Draft'}catch{return $true}
        })
        if($bad.Count){throw "NO_GOVERNING_CR:$((@($bad|%{$_.Path})|sort -Unique)-join',')"}
        Write-Output 'ORVION: READY';Write-Output 'MODE: PLAN';Write-Output 'ACTIVE_CR: none'
        Write-Output "NEXT_CAPABILITY: $($m.Next)"
        Write-Output 'WRITE_AUTHORITY: none (Draft CR authoring only)'
        Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo"
        exit 0
    }

    $c=Contract(Join-Path $Root $rel);$completionTransition=(-not$m.Active);$profiles=Profiles $c.Scope

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

    # The endpoint view above proves what the range LANDED ON. This proves what it
    # PASSED THROUGH, which a net diff cannot see. It runs before the pointer
    # invariant because a forbidden committed state is the deeper defect, and the
    # pointer is a final-state property that would otherwise report the symptom.
    if($BaseRef){Validate-CommittedRange $rel}

    # Deliberately AFTER the contract's own legality. An agent that jumps a status
    # illegally usually also forgets to move the pointer, and the illegal
    # transition is the deeper defect; reporting the pointer first would name the
    # symptom. This still runs before any output, so a Draft named as active can
    # never reach the line that prints its Write Scope.
    Validate-ManifestCrState $m

    # The completion act's own LOCAL evidence (SPEC-164). Judged AFTER the contract's
    # legality and the pointer invariant, because a receipt is evidence about work
    # whose authority those two establish first - and still before any output, so an
    # uncertified completion never prints a mode. A range run is exempt: CI holds no
    # local artifact and re-executes the certification itself.
    Validate-DatabaseContract $c $profiles
    # `-Finish` is exempt because it IS the certification: it re-runs every local
    # command against the state in front of it and mints the receipt at the end.
    # Without this the completion act would be unreachable - it necessarily rewrites
    # the manifest and the generated `ai-map.json` mirror, which certifying earlier
    # cannot have covered. Certify the state you are about to commit, then commit it.
    if(!$BaseRef-and-not$Finish-and$null-ne$baselineText-and$baselineStatus-ne'Complete'-and$c.Status-eq'Complete'){
        Validate-Certification $c ($rel-replace'\\','/') $profiles
    }

    # `Draft` has no arm: Validate-ManifestCrState rejects a Draft the manifest
    # names, so the state the retired approval-pending mode described can no
    # longer be reached. PLAN is where a Draft is authored, and it correctly
    # reports no write authority.
    $mode=switch($c.Status){
        {$_-in@('Approved','In Progress')}{if($c.Blocker-ne'None'){if($c.Attempt-eq3){throw 'RECOVERY_EXHAUSTED'};'BLOCKED'}elseif($c.Resume-eq'DONE'){'VERIFY'}else{'EXECUTE'}}
        'Complete'{if($completionTransition){'VERIFY'}else{'BLOCKED'}}
        default{'BLOCKED'}
    }
    if($mode-eq'BLOCKED'){throw "RUNTIME_BLOCKED:$($c.Blocker)"}
    $declaredCapabilities=@();if(!$BaseRef){$declaredCapabilities=@(Test-Capabilities $c)}

    $scope=@($c.Scope|%{$_-replace'\\','/'})
    foreach($r in $records){
        foreach($p in @($r.Path,$r.Old)|?{$_}){
            if($p-ne($rel-replace'\\','/')-and$scope-notcontains$p){throw "OUT_OF_SCOPE_WRITE:$p"}
        }
    }

    if($Finish-and$mode-ne'VERIFY'){throw "FINISH_NOT_READY:$mode"}

    Write-Output 'ORVION: READY';Write-Output "MODE: $mode";Write-Output "CR: $($c.Id)";Write-Output "STATUS: $($c.Status)"
    Write-Output "STEP: $(if($c.Resume-eq'DONE'){'DONE'}else{"$($c.Resume)/$($c.Steps.Count)"})"
    if($mode-eq'EXECUTE'){Write-Output 'ACTION:';Write-Output $c.Steps[[int]$c.Resume-1]}
    Write-Output "WRITE: $($c.Scope-join', ')"
    Write-Output "START_CONTEXT: $($c.Reading-join', ')"
    Write-Output "VERIFICATION: $((@($profiles)+@($c.AdditionalVerification))-join', ')"
    # Named as declared, never as proven: this process cannot see these connectors,
    # and a capability line that looked like a probe result would be a false green.
    foreach($name in $declaredCapabilities){Write-Output "CAPABILITY: $name EXTERNAL_EVIDENCE — $($script:Capabilities[$name].Note)"}
    Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo";Write-Output "BLOCKER: $($c.Blocker.ToLowerInvariant())"
    if($Finish){Finish-Checks $c $profiles ($rel-replace'\\','/')}
    # A successful run states its OWN status (SPEC-166). Falling off the end leaves
    # whatever the last native command set, and `Read-GitFile` deliberately runs a
    # `git show` that FAILS whenever a path is absent at a ref - it leaves 128 behind
    # and treats that as "absent", which is correct. The range path then ends on
    # cmdlets, so nothing resets it, and GitHub's pwsh shell appends
    # `exit $LASTEXITCODE` to every step. The Gate therefore printed ORVION: READY,
    # MODE: VERIFY and BLOCKER: none, and the CI step failed with no error to read -
    # on the first push of a new Change Request, which is when the governing contract
    # is absent at the range base. Success is an assertion, not a leftover.
    exit 0
}catch{
    if($Finish){Write-Output 'CERTIFY: FAILED'}
    Block $_.Exception.Message
    exit 1
}
