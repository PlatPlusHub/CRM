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
    'Additional Verification','Pre-Approval Evidence','Implementation Steps'
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
# The two closed states. Both are terminal, both forbid being the manifest's active
# pointer, and both may therefore govern the run that closes a contract.
$script:TerminalStatuses=@('Complete','Cancelled')

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

# ---------------------------------------------------------------------------
# SPEC IDENTITY: ALLOCATION, RESERVATION, ORIGINATION, ACTIVATION (SPEC-196).
#
# Three different questions that were previously conflated, which is what
# produced the SPEC-1000 jump and then admitted an unused SPEC-1002:
#
#   ORIGINATION - which event creates a new sequence-advancing identity. From
#                 the activation marker onward that is a Change Request
#                 allocation event and nothing else; every other occurrence
#                 reserves a number without advancing the sequence.
#   ALLOCATION  - which number the next contract takes. Derived from the newest
#                 first-parent allocation event, never from a repository-wide
#                 numeric maximum, which observes fixtures and prose.
#   RESERVATION - whether a number may be taken at all. Monotonic over reachable
#                 history, so deleting an occurrence never releases an identity.
#
# Activation rides on a DECLARED marker in the identity authority rather than on
# a diagnostic literal. The previous pattern read an error string out of the
# evaluator's own source, so a behaviour-preserving rename silently disabled it -
# reproduced against `HISTORICAL_CR_MUTATION`, which still carries that defect
# and is recorded as a successor rather than repaired here.
# ---------------------------------------------------------------------------
$script:AllocationAuthority='CR_LIFECYCLE.md'
function Get-AllocationMarker([string]$Text){
    if($null-eq$Text){return 0}
    $m=[regex]::Match($Text,'(?m)^SPEC Allocation Enforcement:\s*(?<v>[0-9]+)\s*$')
    if($m.Success){[int]$m.Groups['v'].Value}else{0}
}
function Allocation-ActiveAt([string]$Ref){(Get-AllocationMarker (Read-GitFile $Ref $script:AllocationAuthority))-ge1}

# Allocation events in a name-status diff: an ADDED contract path, or a rename
# whose two sides carry DIFFERENT integer identities. A rename that merely
# retitles one identity is not an allocation.
function Allocation-Events([object[]]$Records,[string]$Ref){
    $ids=@()
    foreach($r in $Records){
        if($r.Code-eq'R'-and$r.Old-match'^changes/SPEC-(?<o>[0-9]+)-.*\.md$'){
            $old=[int]$Matches['o']
            if($r.Path-match'^changes/SPEC-(?<n>[0-9]+)-.*\.md$'){
                $new=[int]$Matches['n'];if($new-ne$old){$ids+=$new}
            }
            continue
        }
        if($r.Code-eq'D'){continue}
        # NEW relative to the ref, judged the same way collision validation judges
        # it. Editing an existing contract is not an allocation, and reading the
        # diff code alone would call every modification one.
        if($r.Path-match'^changes/SPEC-(?<n>[0-9]+)-.*\.md$'-and$null-eq(Read-GitFile $Ref $r.Path)){$ids+=[int]$Matches['n']}
    }
    @($ids|Sort-Object -Unique)
}

function Records-For([string]$Commit){
    $records=@()
    # `diff-tree --root` rather than `diff <sha>^ <sha>`: a ROOT commit has no
    # parent to name, and the repository's own first contracts were added by one.
    # Without this the cursor is unresolvable in exactly the history that defines it.
    foreach($line in @(git -C $Root diff-tree -r -M --root --no-commit-id --name-status $Commit 2>$null)){
        if(!$line){continue}
        $parts=$line-split"`t";$code=$parts[0].Substring(0,1)
        if($code-eq'R'){$records+=[pscustomobject]@{Code='R';Old=($parts[1]-replace'\\','/');Path=($parts[2]-replace'\\','/')}}
        else{$records+=[pscustomobject]@{Code=$code;Old=$null;Path=($parts[1]-replace'\\','/')}}
    }
    $records
}

# The cursor is the new-side identity of the NEWEST allocation event on a ref's
# first-parent history, and the walk STOPS there. Stopping is what makes older
# anomalies unreachable: SPEC-1000, SPEC-1001 and the transient SPEC-1002 are
# never examined, with no exception list and no hard-coded number.
function Get-SpecSequenceCursor([string]$Ref){
    foreach($commit in @(git -C $Root rev-list --first-parent $Ref)){
        $ids=Allocation-Events (Records-For $commit) "$commit^"
        if($ids.Count){return ($ids|Measure-Object -Maximum).Maximum}
    }
    throw 'SPEC_SEQUENCE_CURSOR_UNRESOLVED'
}

# Reservation is the union of the current tree and reachable history, answered
# ONE CANDIDATE AT A TIME. Anchored to the supplied ref, never `--all`: a
# temporary or unrelated branch must not be able to reserve a production
# identity, and `--all` reachability differs between clones.
#
# The content pickaxe is sufficient for the historical arm because an identity
# that ever appeared and is now gone must have a commit whose occurrence count
# DECREASED; one that is still present is found by the current-tree arm. The
# cheap path walk runs before the expensive pickaxe deliberately.
function Get-SpecIdReservation([string]$Ref,[string]$Id){
    if(Base-HasId $Ref $Id){return 'tree'}
    $rx='(^|[^0-9])'+[regex]::Escape($Id)+'([^0-9]|$)'
    $current=''
    foreach($line in @(git -C $Root log $Ref --root --format='@%h' --name-only --diff-filter=AR 2>$null)){
        if($line-match'^@(?<h>[0-9a-f]+)$'){$current=$Matches['h'];continue}
        if($line-and$line-match$rx){$LASTEXITCODE=0;return $current}
    }
    $LASTEXITCODE=0
    # QUOTED deliberately: written as `-S$rx` the shell splits the token and git
    # receives no usable pickaxe at all, so every historical content reservation
    # silently reads as free - a false GREEN, which is the worst failure a
    # reservation check can have.
    $hits=@(git -C $Root log $Ref --root --pickaxe-regex "-S$rx" --format=%h 2>$null);$LASTEXITCODE=0
    if($hits.Count){return $hits[-1]}
    $null
}
function Test-SpecIdEverReserved([string]$Ref,[string]$Id){$null-ne(Get-SpecIdReservation $Ref $Id)}

# Reservation drives ADVANCEMENT, not only rejection. The allocator skips a
# reserved candidate and hands out the next free one, which is what makes a
# number burned by a non-contract artifact harmless. The same fact refuses an
# agent that reaches for a reserved identity by hand.
function Validate-SpecAllocation([object[]]$Records,[string]$Ref,[switch]$SkipMarkerCheck){
    $events=Allocation-Events $Records $Ref
    if(!$events.Count){return}
    if(-not $SkipMarkerCheck){
        $local=Join-Path $Root $script:AllocationAuthority
        $text=if(Test-Path -LiteralPath $local){[IO.File]::ReadAllText($local)}else{$null}
        if((Get-AllocationMarker $text)-lt1){throw 'SPEC_ALLOCATION_MARKER_MISSING'}
    }
    $cursor=Get-SpecSequenceCursor $Ref
    $candidate=$cursor+1
    foreach($id in $events){
        $idText="SPEC-$id"
        $reserved=Get-SpecIdReservation $Ref $idText
        # A current-tree collision has already been refused by name upstream, so
        # reaching this with a reservation means history alone reserved it.
        if($null-ne$reserved){throw "SPEC_ID_HISTORICALLY_RESERVED:${idText}:$reserved"}
        while(Test-SpecIdEverReserved $Ref "SPEC-$candidate"){$candidate++}
        if($id-ne$candidate){throw "SPEC_ID_NOT_NEXT:${candidate}:$id"}
        $candidate++
    }
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

# ---------------------------------------------------------------------------
# PRE-APPROVAL EVIDENCE SUFFICIENCY (SPEC-196).
#
# Approval FREEZES authority, so the evidence that makes execution safe has to be
# sufficient before the freeze rather than discovered inside it. Three cancelled
# Slice-12 successors proved the asymmetry: the execution-time guards failed
# closed correctly every time, while the frozen contracts themselves were not
# evidence-closed.
#
# Three outcomes, no score and no compensation between predicates. INDETERMINATE
# is first-class because "we did not look" and "we looked and it is fine" are
# different facts, and only one of them is evidence.
#
# Applicability is DERIVED from repository evidence - Write Scope, the profiles
# it derives, and known control/governance surfaces - never from the contract's
# own Change Class. A label may add obligations; it may never remove one.
# ---------------------------------------------------------------------------
function SubSection([string]$Body,[string]$Name){
    if($null-eq$Body){return $null}
    $m=[regex]::Matches($Body,"(?ms)^### $([regex]::Escape($Name))\s*\r?\n(?<b>.*?)(?=^### |\z)")
    if($m.Count-ne1){return $null}
    $m[0].Groups['b'].Value.Trim()
}
function EvidenceField([string]$Body,[string]$Name){
    if($null-eq$Body){return ''}
    $m=[regex]::Match($Body,"(?m)^$([regex]::Escape($Name)):\s*(?<v>.*?)\s*$")
    if($m.Success){$m.Groups['v'].Value.Trim()}else{''}
}
# A row is evidence only if every cell carries something a human wrote. The
# template's own bracketed placeholders are explicitly NOT evidence - shipping
# the template unfilled is the commonest way a section looks complete.
function EvidenceRows([string]$Body){
    $rows=@()
    if($null-eq$Body){return $rows}
    foreach($line in @($Body-split'\r?\n')){
        $t=$line.Trim()
        if(-not $t.StartsWith('|')){continue}
        if($t-match'^\|[\s\-:|]+\|$'){continue}
        $cells=@(($t.Trim('|')-split'\|')|ForEach-Object{$_.Trim()})
        if($cells.Count-lt2){continue}
        if(($cells|Where-Object{$_-match'^\[.*\]$'}).Count){continue}
        if(($cells|Where-Object{$_-eq'Predicate'-or$_-eq'Invariant'-or$_-eq'Changed fact or surface'}).Count){continue}
        $rows+=,$cells
    }
    # Returned with the comma on purpose: a ONE-row table would otherwise unroll on
    # return and arrive at the caller as its own cells, so every single-row table
    # read as malformed - the opposite of the defect this evidence class exists for.
    ,$rows
}
$script:EvidenceBoundaries=@('BEFORE_IMPLEMENTATION','BEFORE_IRREVERSIBLE_ACTION','AFTER_IRREVERSIBLE_ACTION','BEFORE_COMPLETION')
function StepNumber([string]$Value,[int]$Max){
    if($null-eq$Value){return $null}
    $v=$Value.Trim()
    if($v-eq'NONE'-or$v-eq''){return 0}
    $m=[regex]::Match($v,'(?i)step\s*(?<n>[0-9]+)')
    if(-not $m.Success){$m=[regex]::Match($v,'^(?<n>[0-9]+)$')}
    if(-not $m.Success){return $null}
    $n=[int]$m.Groups['n'].Value
    if($n-lt1-or$n-gt$Max){return $null}
    $n
}
function Evaluate-PreApprovalEvidence($Contract,[string[]]$Profiles){
    # DERIVED applicability. A control or governance surface in Write Scope, or a
    # derived CONTROL profile, makes the evidence classes applicable whatever the
    # contract calls itself.
    $applicable=($Profiles-contains'CONTROL')
    if(-not $applicable){foreach($p in $Contract.Scope){if(Test-ControlPath $p){$applicable=$true;break}}}
    $body=Section $Contract.Text 'Pre-Approval Evidence' -Optional
    if(-not $applicable){return 'PASS'}
    if($null-eq$body-or(Normalize $body)-eq''){throw 'APPROVAL_EVIDENCE:INDETERMINATE:section missing for control-scope work'}

    # Self-exemption. Repository evidence says applicable; the contract may not
    # answer otherwise. A contradiction is INDETERMINATE, never a quiet pass.
    foreach($name in @('Consumer Closure','Execution-Boundary Satisfiability','Permanent-Control Admission')){
        $sub=SubSection $body $name
        if($null-eq$sub){throw "APPROVAL_EVIDENCE:INDETERMINATE:$name missing"}
        if((EvidenceField $sub 'Applicability')-ne'APPLICABLE'){
            throw "APPROVAL_EVIDENCE:INDETERMINATE:$name declared not applicable while repository evidence makes it applicable"
        }
    }
    foreach($row in (EvidenceRows (SubSection $body 'Derived Applicability'))){
        if($row[-1]-ne'APPLICABLE'){throw 'APPROVAL_EVIDENCE:INDETERMINATE:derived applicability contradicts repository evidence'}
    }

    # D - CONSUMER CLOSURE. Closes what DEPENDS on a changed fact, which is a
    # different question from Write Scope's what may be modified, so it is never
    # satisfied by restating the file list.
    $d=SubSection $body 'Consumer Closure'
    $rows=EvidenceRows $d
    if(!$rows.Count){throw 'APPROVAL_EVIDENCE:INDETERMINATE:no consumer closure rows'}
    foreach($row in $rows){
        if($row.Count-lt4){throw 'APPROVAL_EVIDENCE:INDETERMINATE:malformed consumer row'}
        if($row[2]-eq'UNKNOWN'){throw 'APPROVAL_EVIDENCE:INDETERMINATE:UNKNOWN consumer disposition'}
        if(@('WRITE','VERIFY','UNAFFECTED')-notcontains$row[2]){throw "APPROVAL_EVIDENCE:FAIL:invalid disposition $($row[2])"}
        foreach($cell in $row){if($cell-eq''){throw 'APPROVAL_EVIDENCE:INDETERMINATE:empty consumer cell'}}
    }
    $unresolved=EvidenceField $d 'Unresolved Material Consumers'
    if($unresolved-eq''){throw 'APPROVAL_EVIDENCE:INDETERMINATE:unresolved material consumers not stated'}
    if($unresolved-ne'None'){throw "APPROVAL_EVIDENCE:INDETERMINATE:unresolved material consumer: $unresolved"}

    # F - EXECUTION-BOUNDARY SATISFIABILITY. Bounded checkpoint comparison, never
    # simulation. SPEC-195 froze a sequence whose Step-12 gate demanded an
    # invariant green between the Step-10 that broke it and the Step-13 that
    # repaired it; that contract was approved and then cancelled for exactly this.
    $f=SubSection $body 'Execution-Boundary Satisfiability'
    $stepCount=@($Contract.Steps).Count
    $frows=EvidenceRows $f
    if(!$frows.Count){throw 'APPROVAL_EVIDENCE:INDETERMINATE:no execution-boundary rows'}
    foreach($row in $frows){
        if($row.Count-lt5){throw 'APPROVAL_EVIDENCE:INDETERMINATE:malformed boundary row'}
        foreach($b in @($row[1]-split',')){
            if($script:EvidenceBoundaries-notcontains$b.Trim()){throw "APPROVAL_EVIDENCE:INDETERMINATE:unknown boundary $($b.Trim())"}
        }
        $opens=StepNumber $row[2] $stepCount
        $closes=StepNumber $row[3] $stepCount
        $gate=StepNumber $row[4] $stepCount
        if($null-eq$opens-or$null-eq$closes-or$null-eq$gate){throw 'APPROVAL_EVIDENCE:INDETERMINATE:invalid step reference in boundary row'}
        if($opens-gt0-and$closes-eq0){throw 'APPROVAL_EVIDENCE:FAIL:red window never closes'}
        if($opens-gt0-and$gate-gt$opens-and$gate-le$closes){
            throw "APPROVAL_EVIDENCE:FAIL:mandatory gate at step $gate lies inside the red window $opens..$closes"
        }
    }

    # H/J - PERMANENT CONTROL ADMISSION. Pre-Approval freezes the OBLIGATIONS and
    # the already-reproduced causal negative. Actual positive/negative/population/
    # mutation proof belongs to the certified suite after the code exists, so this
    # never demands proof of code that has not been written.
    $hj=SubSection $body 'Permanent-Control Admission'
    foreach($field in @('Existing Mechanism Reusable','Existing Mechanism','Added Property','Causal Negative',
                        'Positive Test Design','Negative Test Design','Non-Empty Population Obligation',
                        'Mutation Obligation','Post-Implementation Proof Obligation')){
        if((EvidenceField $hj $field)-eq''){throw "APPROVAL_EVIDENCE:INDETERMINATE:permanent-control obligation missing: $field"}
    }
    'PASS'
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
    # Authority freezes at APPROVAL, not at a contract's first appearance. A Draft
    # exists precisely to be revised, so a contract drafted and hardened inside the
    # range must not have its pre-approval edits read as post-approval mutation.
    # Already-approved contracts bind at the range base exactly as before.
    $frozenBound=$false
    if($null-ne$FrozenBaseline){
        $baseStatus=try{Status-FromText $FrozenBaseline}catch{$null}
        if($baseStatus-and$baseStatus-ne'Draft'){$frozenBound=$true}
    }

    $terminal=@{};$touched=@{}
    # A cross-identity rename of the GOVERNING contract leaves its former path in
    # the diff. Without this the contract's own earlier name reads as a foreign
    # file and the range is refused OUT_OF_SCOPE_WRITE - which is exactly how this
    # repository's own SPEC-1002 -> SPEC-196 correction became unpublishable.
    # Renaming an identity is a first-class event here, so its lineage is followed.
    $aliases=@{}

    foreach($commit in $commits){
        $short=$commit.Substring(0,7)
        $records=Records-For $commit
        $paths=@()
        foreach($r in $records){
            if($r.Code-eq'R'){
                $paths+=$r.Old;$paths+=$r.Path
                if($r.Path-eq$governing){$aliases[$r.Old]=$true}
            }
            else{$paths+=$r.Path}
        }
        $paths=@($paths|Sort-Object -Unique)

        # Per-commit allocation, gated on the marker in THIS commit's first parent.
        # Pre-activation commits are not retroactively judged; after activation a
        # later correction cannot erase the earlier illegal allocation, which a net
        # BASE..HEAD diff can never see.
        if(Allocation-ActiveAt "$commit^"){
            try{Validate-SpecAllocation $records "$commit^" -SkipMarkerCheck}catch{throw "$($_.Exception.Message)@$short"}
        }

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
                $statusAt=try{Status-FromText $text}catch{$null}
                # The commit that leaves Draft is the one that freezes authority, so
                # it supplies the baseline every later commit is judged against.
                if(-not$frozenBound-and$statusAt-and$statusAt-ne'Draft'){$FrozenBaseline=$text;$frozenBound=$true}
                if($frozenBound){try{Validate-FrozenAuthority $FrozenBaseline $text}catch{throw "$($_.Exception.Message)@$short"}}
            }
            # Scope comes from the frozen baseline on purpose: a commit that
            # widened its own Write Scope must not thereby authorise its own writes.
            $scopeAt=@(Bullets (Section $FrozenBaseline 'Write Scope') 'WRITE_SCOPE'|%{$_-replace'\\','/'})
            foreach($p in $paths){
                if($p-ne$governing-and-not$aliases.ContainsKey($p)-and$scopeAt-notcontains$p){throw "OUT_OF_SCOPE_WRITE:${p}@$short"}
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

# COMPLETION-OWNED GENERATED STATE (SPEC-179). The skip list below names the two
# files the completion act rewrites, for the reason stated above - including them
# would stale every receipt the instant completion began. `ai-map.json` is the
# THIRD file in that class and was left out of it, and the completion arm already
# says so in its own words: "it necessarily rewrites the manifest and the generated
# `ai-map.json` mirror, which certifying earlier cannot have covered." The result
# was that a contract scoping the generated map could never complete - Finish
# fingerprinted it, Complete was REQUIRED to regenerate it so Check 7 would pass,
# and the Gate then called its own mandatory bookkeeping a changed implementation.
#
# The repair is NOT to drop the file. Measured, not assumed: rewriting `boot_order`
# and `authority.execution_conduct` to name files that do not exist leaves
# Repository Consistency CLEAN at exit 0, because Check 7 compares only the
# `live_state` fields the generator extracts and says so - "no other ai-map key is
# brought under comparison by this". The receipt is the ONLY authority that observes
# those keys, so removing the file would leave the cold-start map's boot pointers
# unguarded to make a bookkeeping problem go away.
#
# Exactly four values are excluded, each for a stated reason. `generated_at` is a
# timestamp that carries no authority and moves on every generator run. The three
# `live_state` fields are the ones `CR_LIFECYCLE.md` §9 REQUIRES the completion act
# to rewrite, and each is independently compared BY VALUE against the manifest that
# owns it by Check 7 - proven by making that check fail on a phantom
# `active_change_request`. Nothing stops being guarded; three fields move to the
# authority that already proves them. `live_state.source` and `live_state.phase`
# stay fingerprinted deliberately: completion does not own them, and Check 7 tests
# `phase` for presence rather than by value.
#
# A rename in the generator makes this list stop excluding a field, which stales the
# receipt and refuses completion LOUDLY - never fails open. Assertion 158 ties these
# four names to the names the generator emits so the drift is caught before that.
function AiMap-CertifiedProjection([string]$Path){
    $raw=[IO.File]::ReadAllText($Path)
    # Unparseable maps are fingerprinted by their raw text, never skipped: a map this
    # cannot read is exactly the one whose changes must not slip past unobserved.
    try{$o=$raw|ConvertFrom-Json}catch{return $raw}
    if($null-eq$o){return $raw}
    $o.PSObject.Properties.Remove('generated_at')
    if($null-ne$o.live_state){
        foreach($f in @('active_change_request','last_completed','next_capability')){
            $o.live_state.PSObject.Properties.Remove($f)
        }
    }
    # Compared only against itself, on one machine, minutes apart - so a canonical
    # re-serialization is sufficient and no stable-ordering guarantee is needed.
    $o|ConvertTo-Json -Depth 20
}

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
            $bytes=if($p-eq'ai-map.json'){[Text.Encoding]::UTF8.GetBytes((AiMap-CertifiedProjection $full))}else{[IO.File]::ReadAllBytes($full)}
            $h=([BitConverter]::ToString($sha.ComputeHash($bytes))-replace'-','').ToLowerInvariant()
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

# The branch this work is destined for, derived ONCE. Two mechanisms need it - the
# expectation deriver, to know which workflows can run there, and remote certification,
# to know which runs on a SHA belong to the promotion. Deriving it twice would let the
# two disagree about the same fact, and the certification defect this closes came from
# one of them not knowing the fact at all.
# THE BRANCH THIS PUBLISHES TO, NOT THE BRANCH YOU ARE STANDING ON (SPEC-180). This
# read `rev-parse --abbrev-ref HEAD`, which answers a different question: where the
# agent happens to be checked out. The two coincide only on a branch named after its
# own upstream, so the derivation was correct by coincidence rather than construction,
# and a contract executed on any other branch stamped a target no run has ever existed
# on - green everywhere it mattered, `REMOTE_CERTIFY: PENDING` forever, and unfixable
# afterwards because the contract is terminal by then and the receipt may not be edited.
#
# The upstream is not a new authority. `CR_LIFECYCLE.md` §9 already defines publication
# against it (`git rev-list @{u}..HEAD` empty), and `Git-State` already resolves `@{u}`
# and throws `GIT_UPSTREAM_MISSING` on the same run, BEFORE any receipt can be written -
# which is why no fallback belongs here. Guessing `main`, falling back to the current
# branch, or inferring the target from runs observed after the push are each this same
# defect wearing a different hat.
#
# `@{push}` was measured and rejected: under this repository's configuration it is
# `fatal: cannot resolve 'simple' push to a single destination` on exactly the branch
# shape that motivates this repair, so the more accurate-sounding name is the one that
# cannot answer. That a bare `git push` also refuses there is a question about TRANSPORT
# - the remedy is an explicit refspec - and never about which branch is the target.
#
# The configured merge ref is read rather than the short `origin/main` form, because a
# branch name may itself contain `/`: splitting `origin/release/foo` yields `foo`, and a
# target truncated to another branch's name is worse than no target at all.
function Target-Branch{
    $ref=(git -C $Root symbolic-ref --quiet HEAD 2>$null)
    if($LASTEXITCODE-ne0){return ''}
    $branch=("$ref").Trim()-replace'^refs/heads/',''
    if(!$branch){return ''}
    $merge=(git -C $Root config --get "branch.$branch.merge" 2>$null)
    if($LASTEXITCODE-ne0){return ''}
    ("$merge").Trim()-replace'^refs/heads/',''
}

function Workflow-Expectations([string[]]$Paths,[string]$Branch){
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
    # The branch arrives as a parameter (SPEC-173): the caller owns that fact and writes
    # the SAME value into the receipt, so what decided the expectations and what judges
    # the runs can never be two different branches.
    $branch=$Branch
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
    $target=Target-Branch
    $receipt=[ordered]@{
        cr=$Contract.Id
        profiles=@($Profiles|Sort-Object)
        fingerprint=(Implementation-Fingerprint $Contract $Rel)
        # The branch this candidate is destined for, recorded so -Certify never has to
        # guess it. A run on another ref is evidence about another question: one SHA is
        # pushed twice in this model - once to qualify it, once to promote it - and the
        # two pushes legitimately reach different conclusions.
        target=$target
        # Derived ONCE, here, and read back by -Certify. Re-deriving it after the push
        # would make the completed task's own surface a second authority.
        expected=@(Workflow-Expectations @($Contract.Scope|%{$_-replace'\\','/'}) $target)
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
    $changed=@($Records|?{$_.Path-match'^changes/SPEC-[0-9]+-.*\.md$'}|%{$_.Path}|select -Unique);$c=@();$finals=@{}
    foreach($p in $changed){
        # BOTH terminal statuses may govern the run that closes a contract (SPEC-170).
        # Admitting only `Complete` made `Cancelled` unreachable: closing a contract
        # forces the manifest pointer to be cleared, because a manifest naming a
        # terminal contract is MANIFEST_CR_CONTRADICTION - and with no pointer and no
        # governing contract, control fell to the PLAN arm, which rejects the
        # manifest.md and ai-map.json a closure must write. `CR_LIFECYCLE.md` §4 and
        # $script:LegalTransitions both permit Draft/Approved/In Progress -> Cancelled,
        # so the authority allowed a transition the mechanism refused, leaving a
        # contract approved on a false premise with no legal way forward at all.
        if(Test-Path(Join-Path $Root $p)){try{$x=Contract(Join-Path $Root $p);if($x.Status-in$script:TerminalStatuses){$c+=$p;$finals[$p]=$x.Status}}catch{}}
    }
    if(!$BaseRef-and!$c.Count){return $null}
    if(!$c.Count){throw 'NO_GOVERNING_CR'}
    # A CANCELLATION IS NOT A GOVERNING ACT (SPEC-171). Cancelling a contract requires
    # carrying it inside ANOTHER contract's Write Scope, so one Complete beside one
    # Cancelled is the ordinary shape of every cancellation rather than a conflict - and
    # rejecting it is what left `main` red on cde4f06. The abandoned contract authorised
    # nothing in the range; the completed one authorised every file, the cancelled
    # contract's own included. Genuine ambiguity is two contracts that both claim to have
    # DONE the work, or two that both abandoned it: neither names one authority. Write
    # Scope still comes from the resolved contract alone, so preferring `Complete` grants
    # no authority that was not already granted.
    if($c.Count-gt1){
        $done=@($c|?{$finals[$_]-eq'Complete'})
        if($done.Count-ne1){throw 'AMBIGUOUS_GOVERNING_CR'}
        $c=$done
    }
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
    # Judged against the contract's OWN final status, never a hardcoded one. `Complete`
    # keeps the stricter rule - reachable only from `In Progress` - while `Cancelled` is
    # reachable from every non-terminal state and is therefore judged by the same
    # transition matrix as everything else, which still rejects `Complete -> Cancelled`.
    # Widening which terminal status may GOVERN never widens what a status may DO.
    $final=$finals[$c[0]]
    $seq=@(Status-Path $c[0] $base $final)
    if($final-eq'Complete'){
        if($seq.Count-lt2-or$seq[$seq.Count-2]-ne'In Progress'){throw "INVALID_COMPLETION_TRANSITION:$($c[0])"}
    }else{
        Validate-StatusPath $seq
    }
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
        # `.workstation/` alone missed the two ROOT entry points that execute workstation
        # setup - `bootstrap.ps1` is the only thing that runs on a machine before the
        # repository exists - so a change to either earned no doctor run and no idempotence
        # requirement. `.vscode/extensions.json` and `.mcp.json` join them because
        # prepare.ps1 and doctor.ps1 now READ them: they became workstation desired state,
        # not merely editor and client convenience files.
        if($p-match'^(\.workstation/|bootstrap\.ps1$|workstation\.cmd$|\.vscode/extensions\.json$|\.mcp\.json$)'){[void]$h.Add('WORKSTATION')}
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
        # The doctor is read-only and deterministic, so it is EXECUTED.
        #
        # Bootstrap idempotence is now EXECUTED too, and this is the repair of a real
        # deadlock rather than a convenience. Declaring it `LOCAL_NOT_EXECUTED` meant
        # every WORKSTATION contract ended `LOCAL_CERTIFY: INCOMPLETE`, so
        # `Write-Certification` never ran, so no receipt existed, so `Validate-Certification`
        # refused the `Complete` transition - for a human as much as for an agent, because
        # the Gate does not care who commits. No workstation contract could be completed at
        # all. That is exactly the shape SPEC-164 named in DEFECT B and repaired for
        # DATABASE by EXECUTING the protocol instead of listing it; listing evidence that
        # can never run is truthful and useless, because the profile could only ever
        # withhold certification.
        #
        # The verifier runs `prepare.ps1` ONCE and measures whether it mutated anything,
        # which is the idempotence property given a converged machine - and convergence is
        # what the doctor above establishes. It is a separate script for the same reason
        # `check_database_parity.ps1` is one: the evidence is a COMPARISON. It never
        # uninstalls, never manufactures damage, and fails closed on a machine that has not
        # been converged yet.
        'WORKSTATION'{[pscustomobject]@{Local=@(
            'pwsh -NoProfile -File .workstation/doctor.ps1',
            'pwsh -NoProfile -File scripts/verify_workstation_idempotence.ps1');Deferred=@()}}
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
    # The branch is READ, never re-derived. A receipt written before this field existed
    # cannot be interpreted by guessing a default, because guessing the branch is the
    # whole defect: it is exactly how a preflight qualification run came to be judged as
    # though it were evidence about the promotion.
    $target=("$($receipt.target)").Trim()
    if(!$target){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: the local certification receipt records no target branch — it predates context-aware certification. Run -Finish again.'
        exit 1
    }
    Write-Output "TARGET: $target"
    Write-Output "EXPECTED: $((@($expected)|Sort-Object)-join', ')"
    # --limit is explicit: inheriting the CLI default would let a busy SHA silently
    # present a truncated view, and a missing row reads as REQUIRED_WORKFLOW_MISSING.
    # `attempt` is requested as evidence only. Measured against a real rerun in this
    # repository, `gh run list` returns ONE row per run carrying the CURRENT attempt's
    # conclusion, so an old success cannot hide a current failure and an old failure
    # cannot poison a current success. No attempt-selection logic is therefore written.
    # The field list is quoted so it stays ONE token however `gh` resolves: in argument
    # mode a bare `a,b,c` reaches a native executable as a single string but becomes an
    # ARRAY when the resolved command is a PowerShell script.
    $raw=gh run list --commit $sha --branch $target --event push --limit 100 --json 'attempt,conclusion,databaseId,event,headBranch,headSha,status,workflowName' 2>$null
    if($LASTEXITCODE-ne0-or!$raw){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: gh could not read workflow runs for this SHA'
        exit 1
    }
    # ASSIGN, then wrap. `ConvertFrom-Json` emits a JSON array as ONE pipeline item, so
    # `@($raw|ConvertFrom-Json)` yields a single element that IS the array - one iteration
    # holding every run at once. Assigning first unrolls it, and `@()` then normalises the
    # one-object and empty-array cases. The previous code carried the same shape harmlessly
    # because it only ever read members across the collection, which PowerShell flattens;
    # it becomes a real defect the moment individual rows are inspected.
    try{$parsed=$raw|ConvertFrom-Json}catch{
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: gh returned evidence this command cannot parse'
        exit 1
    }
    $all=@($parsed)
    # The filter is asked for AND the answer is checked. Trusting the query alone would
    # make this function believe whatever the CLI handed back; a row that contradicts the
    # question it answers is discarded, and a discarded row leaves its workflow MISSING,
    # which fails closed. Nothing is dropped silently - each is named.
    $runs=@();$ignored=@()
    foreach($r in $all){
        $why=@()
        if(("$($r.headSha)").Trim()-ne$sha){$why+="headSha=$($r.headSha)"}
        if(("$($r.headBranch)").Trim()-ne$target){$why+="headBranch=$($r.headBranch)"}
        if(("$($r.event)").Trim()-ne'push'){$why+="event=$($r.event)"}
        if($why.Count){$ignored+="$($r.workflowName) [$($why-join' ')]"}else{$runs+=$r}
    }
    foreach($i in $ignored){Write-Output "IGNORED: $i — not this SHA on $target by push"}
    if(!$runs.Count){
        Write-Output 'REMOTE_CERTIFY: PENDING'
        Write-Output "EVIDENCE: no workflow run exists for this SHA on $target yet — push it, or wait for the run to start"
        exit 1
    }
    foreach($r in $runs){Write-Output "RUN: $($r.workflowName) attempt $($r.attempt) $($r.status)/$($r.conclusion)"}
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
    # Green evidence about a SHA the target ref has already moved past certifies nothing
    # anyone can act on: the claim being made is "the branch stands at a proven revision",
    # and that is a statement about NOW, not about the moment the runs finished. Read the
    # remote, never a local cache, and refuse rather than assume when it cannot be read.
    git -C $Root fetch origin $target --quiet 2>$null|Out-Null
    if($LASTEXITCODE-ne0){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: TARGET_REF_UNREADABLE:$target — the remote target ref could not be read, so it cannot be proven to stand at this SHA"
        exit 1
    }
    $remote=(git -C $Root rev-parse "refs/remotes/origin/$target" 2>$null)
    $remote=if($LASTEXITCODE-eq0){("$remote").Trim()}else{''}
    if($remote-ne$sha){
        Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: TARGET_REF_MOVED:$target is at $remote, not the certified $sha"
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
    # Allocation is judged locally on every run, and in range mode only when the
    # base itself was already under enforcement - current rules are never applied
    # retroactively to history that predates the marker. Reservation, unlike
    # allocation, is never gated by it.
    if(-not $BaseRef){Validate-SpecAllocation $records $base}
    elseif(Allocation-ActiveAt $BaseRef){Validate-SpecAllocation $records $base -SkipMarkerCheck}
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
        # Judged on the Draft -> Approved transition ALONE. That is what freezes
        # authority, and it is also why terminal history is never retrofitted: a
        # contract that is already past this boundary is never re-examined.
        if($baselineStatus-eq'Draft'-and$c.Status-eq'Approved'){
            $script:ApprovalEvidence=Evaluate-PreApprovalEvidence $c $profiles
        }
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
        # Both closed states route the same way: the run that CLOSES a contract verifies
        # it, and a closed contract encountered outside that act is a blocked state, not
        # a mode. Without the `Cancelled` arm a cancelled governing contract fell to
        # `default` and reported RUNTIME_BLOCKED, so admitting it into Resolve-Contract
        # alone would have moved the refusal rather than removed it.
        {$_-in$script:TerminalStatuses}{if($completionTransition){'VERIFY'}else{'BLOCKED'}}
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
    if($script:ApprovalEvidence){Write-Output "APPROVAL_EVIDENCE: $($script:ApprovalEvidence)"}
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
