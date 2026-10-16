[CmdletBinding(DefaultParameterSetName='Boot')]
param(
    [Parameter(ParameterSetName='Boot',Mandatory=$true)][switch]$Boot,
    [Parameter(ParameterSetName='Gate',Mandatory=$true)][switch]$Gate,
    [Parameter(ParameterSetName='Gate')][switch]$Trusted,
    [Parameter(ParameterSetName='Gate')][switch]$BindCandidate,
    [Parameter(ParameterSetName='Finish',Mandatory=$true)][switch]$Finish,
    [Parameter(ParameterSetName='Certify',Mandatory=$true)][switch]$Certify,
    [string]$Root=(Split-Path $PSScriptRoot -Parent),
    [string]$BaseRef,
    [string]$HeadRef='HEAD'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'github_public_read.ps1')
# SPEC-283. Every run states how long it took, in every mode and on every exit path - the pre-commit
# hook, CI, the owner's promoter and an agent alike. The `finally` around the run prints
# `TIME: <mode> hh:mm:ss` after the verdict; `exit` runs it and keeps the exit code.
$script:RunClock=[Diagnostics.Stopwatch]::StartNew()
function Format-Elapsed([TimeSpan]$T){'{0:00}:{1:00}:{2:00}' -f [Math]::Floor($T.TotalHours),$T.Minutes,$T.Seconds}
# A run nobody timed - the pre-commit hook, a direct Boot or Gate, the publisher's and promoter's Gates,
# -Certify - is recorded here, in the history `scripts/watch_run.ps1` keeps and reports on. A run under
# `scripts/run_timed.ps1` is recorded by its watcher from the runner's log, and CI keeps its own run
# timings on GitHub, so every run has exactly one writer. Reporting only: a record that cannot be
# written is said so and never changes a verdict or an exit code. `$script:Outcome` is set where each
# verdict is printed, because a `finally` cannot read the code `exit` was given.
$script:RunStarted=Get-Date;$script:Outcome=$null
# Each stage is the time since the previous mark, and whatever follows the last mark is `other`, so the
# stages always sum to the run. One line carries them all - `TIME: STAGES <mode> <name>=1.23s ...` - so a
# run's output grows by one line, and the watcher or this file turns it into one history row per stage.
$script:Stages=[ordered]@{};$script:StageMark=[TimeSpan]::Zero
function Mark-Stage([string]$Name){$now=$script:RunClock.Elapsed;$script:Stages[$Name]=$now-$script:StageMark;$script:StageMark=$now}
function Format-Stages([string]$Label){
    $script:Stages['other']=$script:RunClock.Elapsed-$script:StageMark
    "TIME: STAGES $Label "+(@($script:Stages.GetEnumerator()|ForEach-Object{"$($_.Key)=$($_.Value.TotalSeconds.ToString('0.00',[Globalization.CultureInfo]::InvariantCulture))s"})-join' ')
}
function Write-TimingRecord([string]$Label){
    if($env:ORVION_TIMED_LOG-or$env:GITHUB_ACTIONS){return}
    try{
        $csv=if($env:ORVION_TIMINGS_CSV){$env:ORVION_TIMINGS_CSV}else{Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ORVION\timings.csv'}
        [void][IO.Directory]::CreateDirectory((Split-Path $csv -Parent))
        $head="$(git -C $Root rev-parse --short HEAD 2>$null)".Trim();$global:LASTEXITCODE=0
        $conditions="host=$env:COMPUTERNAME pwsh=$($PSVersionTable.PSVersion) cpus=$([Environment]::ProcessorCount) head=$head via=$(if($env:GIT_INDEX_FILE){'hook'}else{'direct'})"
        $outcome=if($script:Outcome){$script:Outcome}else{'OUTCOME UNRECORDED'}
        $inv=[Globalization.CultureInfo]::InvariantCulture;$min=$script:RunClock.Elapsed.TotalMinutes.ToString('0.0###',$inv)
        $run='orvion-'+($Label.ToLowerInvariant()-replace' ','-');$at=$script:RunStarted.ToString('yyyy-MM-dd HH:mm:ss.fff')
        $row={param($Step,$T,$D)'"{0}","{1}","{2}",{3},{4},"{5}"' -f $run,$at,($Step-replace'"',"'"),$T,$D,$conditions}
        $rows=@(& $row "TIME: $Label $(Format-Elapsed $script:RunClock.Elapsed)" $min $min)
        $at2=[TimeSpan]::Zero
        foreach($s in $script:Stages.GetEnumerator()){$at2+=$s.Value;$rows+=& $row "STAGE $Label $($s.Key)" $at2.TotalMinutes.ToString('0.0###',$inv) $s.Value.TotalMinutes.ToString('0.0###',$inv)}
        $rows+=& $row "END exit=$(if($outcome-match'READY$'){0}else{1}) $outcome" $min $min
        Add-TimingRows $csv $rows $(if($env:ORVION_TIMINGS_MAX_BYTES){[long]$env:ORVION_TIMINGS_MAX_BYTES}else{10MB})
    }catch{Write-Output "TIME_RECORD: not written - $($_.Exception.Message)"}
}
# The history's one write path, shared VERBATIM with scripts/watch_run.ps1 (scripts/watch_selftest.ps1
# holds the two copies equal). A named mutex per history file serialises every writer and the watcher's
# reads across processes, so an append never interleaves with another append or with a trim. The bound
# holds after every append: past $MaxBytes the history keeps its newest whole rows within half of it,
# written to a temporary file beside it and moved over it, so the history is never rewritten in place.
function Use-TimingHistory([string]$Path, [scriptblock]$Body) {
    $id = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Path).ToLowerInvariant())))
    $lock = [Threading.Mutex]::new($false, 'Global\ORVION-timings-' + $id.Substring(0, 32))
    try {
        # An abandoned mutex (its holder was killed) is acquired: the history is only ever replaced whole.
        try { if (-not $lock.WaitOne(15000)) { throw "the timing history $Path stayed locked for 15 s" } } catch [Threading.AbandonedMutexException] { }
        try { & $Body } finally { $lock.ReleaseMutex() }
    } finally { $lock.Dispose() }
}
function Add-TimingRows([string]$Path, [string[]]$Rows, [long]$MaxBytes) {
    Use-TimingHistory $Path {
        if (-not [IO.File]::Exists($Path)) { [IO.File]::WriteAllText($Path, 'run,date,step,elapsed_min,delta_min,env' + [Environment]::NewLine) }
        if ($Rows.Count) { [IO.File]::AppendAllText($Path, ($Rows -join [Environment]::NewLine) + [Environment]::NewLine) }
        if ([IO.FileInfo]::new($Path).Length -le $MaxBytes) { return }
        $b = [IO.File]::ReadAllBytes($Path); $h = [Array]::IndexOf($b, [byte]10) + 1
        $n = [Array]::IndexOf($b, [byte]10, [int][Math]::Max($h, $b.Length - [Math]::Floor($MaxBytes / 2))); $cut = if ($n -lt 0) { $b.Length } else { $n + 1 }
        $tmp = "$Path.tmp"; $f = [IO.File]::Create($tmp); try { $f.Write($b, 0, $h); $f.Write($b, $cut, $b.Length - $cut) } finally { $f.Dispose() }
        [IO.File]::Move($tmp, $Path, $true)
        'history: kept the newest {0:N0} of {1:N0} bytes of rows (limit {2:N0})' -f ($b.Length - $cut), ($b.Length - $h), $MaxBytes
    }
}

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

# SPEC-200. Split from `Contract` so the committed-range walk can parse a contract as it
# stood at a COMMIT rather than as it stands in the working tree. Same parser, same
# refusals, same codes - a second parser would be a second authority on contract shape.
function Contract([string]$Path){
    if(!(Test-Path -LiteralPath $Path)){throw "STALE_ACTIVE_CR:$Path"}
    Contract-FromText (Get-Content -Raw -LiteralPath $Path) ([IO.Path]::GetFileName($Path)) $Path
}
function Contract-FromText([string]$Text,[string]$BaseName,[string]$Path=''){
    $t=$Text
    $headings=@([regex]::Matches($t,'(?m)^# Change Request — (?<id>SPEC-[0-9]+)\s*$'))
    if($headings.Count-ne1){throw "INVALID_CR_HEADING:count=$($headings.Count)"}
    $id=$headings[0].Groups['id'].Value.ToUpperInvariant();$base=$BaseName
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
# reproduced against `HISTORICAL_CR_MUTATION`, which carried the same defect until
# `CTRL-1` was closed. Terminal-contract immutability now declares its own activation
# boundary in this same authority and resolves it by ancestry; see
# `Historical-Guard-IsActive` below, which reuses this pattern but deliberately not
# this marker's VALUE, because the two activated eight days apart.
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
# Memoized per (ref, candidate). One allocation asks about the identity it wants
# and then about the candidates it walks past, and the per-commit range walk asks
# the same questions again for the same parents. History does not change inside a
# run, so paying for the same answer twice is waste, not safety.
$script:ReservationCache=@{}
function Get-SpecIdReservation([string]$Ref,[string]$Id){
    $key="$Ref|$Id"
    if($script:ReservationCache.ContainsKey($key)){return $script:ReservationCache[$key]}
    $result=$null
    if(Base-HasId $Ref $Id){$result='tree'}
    else{
        $rx='(^|[^0-9])'+[regex]::Escape($Id)+'([^0-9]|$)'
        $current=''
        foreach($line in @(git -C $Root log $Ref --root --format='@%h' --name-only --diff-filter=AR 2>$null)){
            if($line-match'^@(?<h>[0-9a-f]+)$'){$current=$Matches['h'];continue}
            if($line-and$line-match$rx){$result=$current;break}
        }
        $LASTEXITCODE=0
        if($null-eq$result){
            # QUOTED deliberately: written as `-S$rx` the shell splits the token and git
            # receives no usable pickaxe at all, so every historical content reservation
            # silently reads as free - a false GREEN, which is the worst failure a
            # reservation check can have.
            $hits=@(git -C $Root log $Ref --root --pickaxe-regex "-S$rx" --format=%h 2>$null);$LASTEXITCODE=0
            if($hits.Count){$result=$hits[-1]}
        }
    }
    $script:ReservationCache[$key]=$result
    $result
}
function Test-SpecIdEverReserved([string]$Ref,[string]$Id){$null-ne(Get-SpecIdReservation $Ref $Id)}

# Reservation drives ADVANCEMENT, not only rejection. The allocator skips a
# reserved candidate and hands out the next free one, which is what makes a
# number burned by a non-contract artifact harmless. The same fact refuses an
# agent that reaches for a reserved identity by hand.
function Validate-SpecAllocation([object[]]$Records,[string]$Ref,[switch]$SkipMarkerCheck,[switch]$CheckOrigination,[string]$StateRef=''){
    $events=Allocation-Events $Records $Ref
    if(!$events.Count){return}
    if(-not $SkipMarkerCheck){
        $local=Join-Path $Root $script:AllocationAuthority
        $text=if(Test-Path -LiteralPath $local){[IO.File]::ReadAllText($local)}else{$null}
        if((Get-AllocationMarker $text)-lt1){throw 'SPEC_ALLOCATION_MARKER_MISSING'}
    }
    # SPEC-202. ORIGINATION STATE. A contract BORN `Approved` is never evidence-checked:
    # `Evaluate-PreApprovalEvidence` is reached only when the contract exists at the
    # comparison baseline, and a born contract has none, so `SPEC-196`'s rule that
    # Approval is admissible only on sufficient evidence went unenforced on that path.
    # Owner-ratified, forward-only: after the activation boundary a newly originated
    # contract must first appear as `Draft`. The cutover is the SAME marker gate this
    # function already stands behind, so pre-activation history keeps its own law and
    # no second activation authority exists.
    #
    # A cross-identity RENAME is deliberately not origination: the contract carries its
    # existing status, which was already judged under its former identity, and renaming
    # is how this repository corrects an identity (SPEC-1002 -> SPEC-196).
    if($CheckOrigination){
        foreach($r in $Records){
            if($r.Code-eq'D'-or$r.Code-eq'R'){continue}
            if($r.Path-notmatch'^changes/SPEC-[0-9]+-.*\.md$'){continue}
            if($null-ne(Read-GitFile $Ref $r.Path)){continue}
            $born=if($StateRef){Read-GitFile $StateRef $r.Path}
                  else{$f=Join-Path $Root $r.Path;if(Test-Path -LiteralPath $f){[IO.File]::ReadAllText($f)}else{$null}}
            if($null-eq$born){continue}
            $st=try{Status-FromText $born}catch{$null}
            if($st-ne'Draft'){throw "ORIGINATION_NOT_DRAFT:$($r.Path):$st"}
        }
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

# CTRL-1. HISTORICAL IMMUTABILITY ACTIVATION IS A DECLARED LIFECYCLE FACT, NOT A
# DIAGNOSTIC STRING.
#
# The previous form read the error literal `HISTORICAL_CR_MUTATION` out of the OLD copy of
# this script at the base ref, so a behaviour-preserving rename landing inside a range made
# the new evaluator search the base for a literal the base could not contain, and terminal
# immutability switched itself off in silence. Reproduced before this repair, with the rename
# and the tamper BOTH inside the governing Write Scope so that no incidental guard could
# supply the refusal: the control run exits 1 on `HISTORICAL_CR_MUTATION`, and the renamed run
# exits 0 and ADMITS modification of a contract that was already terminal at the base.
#
# The boundary is DECLARED, and it is the ORIGINAL one. Activation began at
# `5d78aacd5335278c5b03edb0b3f969bd86e6b9c4` (2026-09-11), whose first parent
# `dfcb44a8c233f3e0d88bb2900b21693f2b5091b5` carries no guard at all. The `SPEC Allocation
# Enforcement` marker is NOT reused as the cutover even though it is the same pattern: it
# first appears at `fcf065a` on 2026-09-19, eight days later, so adopting it would move the
# cutover forward and leave the history between the two boundaries unprotected. That is a
# weakening, and the point of this repair is that the truth table does not move.
#
# The marker is read from the CURRENT authority rather than at `$Ref`, because the boundary is
# a fixed historical fact that old refs cannot be expected to know about; reading it at `$Ref`
# would reintroduce exactly the defect being repaired. `CR_LIFECYCLE.md` is a control surface,
# so moving the declared value requires a contract that names it.
$script:HistoricalAuthority='CR_LIFECYCLE.md'
function Get-HistoricalActivationBoundary([string]$Text){
    if($null-eq$Text){return $null}
    $m=[regex]::Match($Text,'(?m)^Historical CR Immutability Enforcement:\s*(?<v>\S+)\s*$')
    if(-not $m.Success){return $null}
    $m.Groups['v'].Value
}
function Historical-Guard-IsActive([string]$Ref){
    if(!$BaseRef){return $true}
    $local=Join-Path $Root $script:HistoricalAuthority
    $text=if(Test-Path -LiteralPath $local){[IO.File]::ReadAllText($local)}else{$null}
    $boundary=Get-HistoricalActivationBoundary $text
    # Missing or malformed activation evidence FAILS LOUDLY. Returning false here would be the
    # silent deactivation this repair exists to remove.
    if($null-eq$boundary){throw 'HISTORICAL_ACTIVATION_MARKER_MISSING'}
    if($boundary-notmatch'^[0-9a-f]{40}$'){throw "HISTORICAL_ACTIVATION_MARKER_MALFORMED:$boundary"}
    # `$LASTEXITCODE` is captured into a DISTINCT local immediately, and only ever reset through
    # `$global:`. Writing `$LASTEXITCODE=0` inside a function creates a function-scoped shadow, so
    # the next read returns that stale 0 instead of the exit code git actually produced - which
    # made this guard read ACTIVE for every ref, including pre-activation ones. That direction is
    # safe but still wrong: it retroactively judges history the original boundary never covered.
    git -C $Root cat-file -e "$boundary^{commit}" 2>$null|Out-Null
    $knownCode=$LASTEXITCODE
    # A boundary this repository does not CONTAIN - a synthetic fixture, a shallow clone - must
    # never read as "immutability is off". Unprovable pre-activation means protect.
    if($knownCode-ne0){$global:LASTEXITCODE=0;return $true}
    git -C $Root merge-base --is-ancestor $boundary $Ref 2>$null|Out-Null
    $ancestorCode=$LASTEXITCODE
    $global:LASTEXITCODE=0
    $ancestorCode-eq0
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

# ---------------------------------------------------------------------------
# CONSTITUTIONAL ASSURANCE (SPEC-281). CAG admits a contract on what this evaluator CHECKS and
# says what is left to judgment; ACI, SACI and PICF are predicates inside it, never four gates.
# Each reads Git, the contract and the repository - never an account of them.
# ---------------------------------------------------------------------------

# A tracked file at a commit, or in the working tree when $Ref is empty.
function Read-RepoFile([string]$Ref,[string]$Path){
    if($Ref){return Read-GitFile $Ref $Path}
    $p=Join-Path $Root $Path
    if(Test-Path -LiteralPath $p){[IO.File]::ReadAllText($p)}else{$null}
}
# The one line `<Key>: ...` of a document; $null unless there is exactly one.
function Get-KeyedLine([string]$Text,[string]$Key){
    if($null-eq$Text){return $null}
    $m=[regex]::Matches(($Text-replace"`r`n","`n"),"(?m)^$([regex]::Escape($Key)):[^\n]*")
    if($m.Count-ne1){return $null}
    $m[0].Value
}
function Get-TextSha256([string]$Text){
    $h=[Security.Cryptography.SHA256]::Create()
    try{-join($h.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($Text))|ForEach-Object{$_.ToString('x2')})}finally{$h.Dispose()}
}

# SACI. A line that points to its owner holds exactly its ratified text. CTRL-12 recurred because
# "never a copy of it here" was prose: SPEC-270 deleted the copied Batch 6 targets and SPEC-278
# copied them back from a precedent written before that deletion. The pins live in GOVERNANCE.md
# §6, the authority for where a fact lives, one row per line:
# | `path` | `key` | `owner` | `SHA-256 of the line` |. Changing a pinned line stays lawful - it is
# an authority change, whose contract writes the new pin beside the new line and closes its
# consumers (ACI below).
function Get-PinRows([string]$Text){
    if($null-eq$Text){return}
    foreach($m in [regex]::Matches($Text,'(?m)^[ \t]*\|\s*`(?<path>[^`]+)`\s*\|\s*`(?<key>[^`]+)`\s*\|\s*`(?<owner>[^`]+)`\s*\|\s*`(?<sha>[0-9a-f]{64})`\s*\|\s*$')){
        [pscustomobject]@{Path=$m.Groups['path'].Value;Key=$m.Groups['key'].Value;Owner=$m.Groups['owner'].Value;Sha=$m.Groups['sha'].Value}
    }
}
function Get-PinnedAuthority([string]$Ref){Get-PinRows (Read-RepoFile $Ref 'GOVERNANCE.md')}
function Validate-PinnedAuthority([string]$Ref){
    foreach($pin in @(Get-PinnedAuthority $Ref)){
        $line=Get-KeyedLine (Read-RepoFile $Ref $pin.Path) $pin.Key
        if($null-eq$line){throw "PINNED_AUTHORITY_MISSING:$($pin.Path)#$($pin.Key) - GOVERNANCE.md §6 pins exactly one line there beginning '$($pin.Key):'"}
        if((Get-TextSha256 $line)-ne$pin.Sha){
            throw "PINNED_AUTHORITY_CHANGED:$($pin.Path)#$($pin.Key) - its value is owned by $($pin.Owner) and is never copied here; restore the ratified line, or change it only under a contract that also changes its GOVERNANCE.md §6 pin and closes its consumers"
        }
    }
}

# ACI. An authority change closes its consumers, found by `git grep` for the line's key at the
# base rather than listed from memory: SPEC-270 changed `Next capability`, and its Consumer
# Closure named two of the seven live files that name it by path - not `CR_LIFECYCLE.md`, whose
# `Complete` command still told agents to rewrite the line. Terminal contracts and dated reports
# are history (GOVERNANCE.md §4), never edited to follow current authority, so they are not
# candidates; the pin is what protects against them. A candidate is a file the contract must
# disposition (WRITE, VERIFY or UNAFFECTED), not a proven impact.
function Get-AuthorityConsumers([string]$Ref,$Pin){
    $hits=@(git -C $Root grep -l -F -e $Pin.Key $Ref -- . ':(exclude)changes/' ':(exclude)reports/history/' 2>$null);$global:LASTEXITCODE=0
    @($hits|ForEach-Object{$_.Substring($Ref.Length+1)}|Where-Object{$_-ne$Pin.Path})
}
function Assert-AuthorityConsumersCovered([object[]]$Rows,$Pin,[string]$Ref,[string]$Code){
    foreach($consumer in @(Get-AuthorityConsumers $Ref $Pin)){
        if(-not @($Rows|Where-Object{($_-join' | ').Contains($consumer)}).Count){
            throw "${Code}:changing pinned line '$($Pin.Key)' leaves $consumer, which names it, without a Consumer Closure row"
        }
    }
}
# What a commit actually did to the pins: one added, moved or removed, or a pinned line changed.
# Omitting a declaration cannot avoid it, because a changed line needs a changed pin.
function Get-PinChanges([string]$WasRef,[string]$NowRef){
    $was=@(Get-PinnedAuthority $WasRef);$now=@(Get-PinnedAuthority $NowRef)
    foreach($id in @(@($was)+@($now)|ForEach-Object{"$($_.Path)#$($_.Key)"}|Sort-Object -Unique)){
        $a=@($was|Where-Object{"$($_.Path)#$($_.Key)"-eq$id})[0]
        $b=@($now|Where-Object{"$($_.Path)#$($_.Key)"-eq$id})[0]
        $pin=if($b){$b}else{$a}
        $lineWas="$(Get-KeyedLine (Read-RepoFile $WasRef $pin.Path) $pin.Key)"
        $lineNow="$(Get-KeyedLine (Read-RepoFile $NowRef $pin.Path) $pin.Key)"
        if(-not$a-or-not$b-or$a.Sha-ne$b.Sha-or-not(Same-Text $lineWas $lineNow)){$pin}
    }
}

# PICF. A criterion may carry checks the Gate evaluates, so "met" is observed, not asserted:
#   `check: same <path>[#<key>] @<commit>`   unchanged since that commit
#   `check: has <path>[#<key>] "<text>"`     `check: lacks <path>[#<key>] "<text>"`
#   `check: blob <path> <sha1>`
# At Approval a check that can never hold is FAIL: it names a file outside Write Scope that
# already disagrees, a pinned line this contract may not change, or a commit outside the history
# it is approved on. A file the contract may write is judged at Complete, never as absent at
# the base. At Complete every check must hold in the completing tree. SPEC-278's Review listed
# as met a criterion whose figures the manifest no longer held, and SPEC-252 represented a false
# criterion as satisfied. A criterion without a check is still judged by Review, and CRITERIA
# says so rather than counting it as verified.
$script:CheckPattern='`check:\s*(?<kind>[a-z]+)\s+(?<args>[^`]*)`'
function Get-CriterionChecks($Contract){
    $i=0
    foreach($item in @($Contract.Acceptance)){
        $i++
        foreach($m in [regex]::Matches($item.Text,$script:CheckPattern)){
            $kind=$m.Groups['kind'].Value;$a=$m.Groups['args'].Value.Trim()
            $p=switch($kind){
                'same'{[regex]::Match($a,'^(?<path>[^\s#@"]+)(?:#(?<key>[^@"]+?))?\s+@(?<ref>[0-9a-f]{7,40})$')}
                {$_-in'has','lacks'}{[regex]::Match($a,'^(?<path>[^\s#@"]+)(?:#(?<key>[^@"]+?))?\s+"(?<text>[^"]+)"$')}
                'blob'{[regex]::Match($a,'^(?<path>[^\s#@"]+)\s+(?<sha>[0-9a-f]{40})$')}
                default{[regex]::Match('','x')}
            }
            if(-not$p.Success){throw "CRITERION_CHECK_MALFORMED:criterion $i - $($m.Value)"}
            [pscustomobject]@{Item=$i;Kind=$kind;Path=$p.Groups['path'].Value;Key=$p.Groups['key'].Value.Trim()
                Ref=$p.Groups['ref'].Value;Text=$p.Groups['text'].Value;Sha=$p.Groups['sha'].Value;Raw=$m.Value}
        }
    }
}
function Get-CheckTarget($Check,[string]$Ref){
    $text=Read-RepoFile $Ref $Check.Path
    if($Check.Key){return Get-KeyedLine $text $Check.Key}
    if($null-eq$text){return $null}
    $text-replace"`r`n","`n"
}
function Get-RepoBlob([string]$Ref,[string]$Path){
    $b=if($Ref){git -C $Root rev-parse "${Ref}:$Path" 2>$null}else{$f=Join-Path $Root $Path;if(Test-Path -LiteralPath $f){git -C $Root hash-object -- $f 2>$null}}
    $global:LASTEXITCODE=0
    "$b".Trim()
}
# $null when the check holds at $Ref ('' = working tree); otherwise why it does not.
function Test-CriterionCheck($Check,[string]$Ref){
    $where=if($Check.Key){"$($Check.Path)#$($Check.Key)"}else{$Check.Path}
    if($Check.Kind-eq'blob'){
        $b=Get-RepoBlob $Ref $Check.Path
        if($b-ne$Check.Sha){return "$where is blob $(if($b){$b}else{'(absent)'})"}
        return $null
    }
    $now=Get-CheckTarget $Check $Ref
    if($null-eq$now){return "$where does not exist"}
    if($Check.Kind-eq'has'-and-not$now.Contains($Check.Text)){return "$where does not contain `"$($Check.Text)`""}
    if($Check.Kind-eq'lacks'-and$now.Contains($Check.Text)){return "$where contains `"$($Check.Text)`""}
    if($Check.Kind-eq'same'){
        $was=Get-CheckTarget $Check $Check.Ref
        if($null-eq$was){return "$where does not exist at $($Check.Ref)"}
        if(-not(Same-Text $was $now)){return "$where differs from $($Check.Ref)"}
    }
    $null
}
function Get-CriteriaReport($Contract,[string]$Verb){
    $total=@($Contract.Acceptance).Count
    $checked=@(@(Get-CriterionChecks $Contract)|ForEach-Object{$_.Item}|Sort-Object -Unique).Count
    "$checked of $total $Verb by the Gate; $($total-$checked) judged by Review alone"
}

# CAG at Approval: the predicates every contract is held to, whether or not its evidence section
# is otherwise applicable.
function Assert-AssuranceAdmission($Contract,[string]$BaseRef){
    $pins=@(Get-PinnedAuthority $BaseRef)
    $mayRepin=$Contract.Scope-contains'GOVERNANCE.md'
    $checks=try{@(Get-CriterionChecks $Contract)}catch{throw "APPROVAL_EVIDENCE:FAIL:$($_.Exception.Message)"}
    foreach($c in $checks){
        if($c.Kind-eq'same'){
            git -C $Root merge-base --is-ancestor $c.Ref $BaseRef 2>$null|Out-Null;$anc=$LASTEXITCODE;$global:LASTEXITCODE=0
            if($anc-ne0){throw "APPROVAL_EVIDENCE:FAIL:criterion $($c.Item) checks against $($c.Ref), which is not in the history this contract is approved on"}
            if($null-eq(Get-CheckTarget $c $c.Ref)){throw "APPROVAL_EVIDENCE:FAIL:criterion $($c.Item) - $($c.Raw) names what does not exist at $($c.Ref)"}
            continue
        }
        $pinned=(-not$mayRepin)-and@($pins|Where-Object{$_.Path-eq$c.Path-and$_.Key-eq$c.Key}).Count-gt0
        if($pinned-or$Contract.Scope-notcontains$c.Path){
            $why=Test-CriterionCheck $c $BaseRef
            if($why){throw "APPROVAL_EVIDENCE:FAIL:criterion $($c.Item) can never hold - $($c.Raw): $why, and $(if($pinned){'that line is pinned by GOVERNANCE.md §6'}else{"$($c.Path) is outside Write Scope"})"}
        }
    }
    # Two checks on one target that no final state can satisfy together: `has` beside a `lacks`
    # it implies, two different blobs, or `same` beside a value the pinned commit does not hold.
    foreach($a in $checks){foreach($b in $checks){
        if($a.Path-ne$b.Path-or$a.Key-ne$b.Key-or[object]::ReferenceEquals($a,$b)){continue}
        $clash=switch("$($a.Kind)/$($b.Kind)"){
            'has/lacks'{$a.Text.Contains($b.Text)}
            'blob/blob'{$a.Sha-ne$b.Sha}
            'same/same'{-not(Same-Text "$(Get-CheckTarget $a $a.Ref)" "$(Get-CheckTarget $b $b.Ref)")}
            {$_-in'same/has','same/lacks','same/blob'}{$null-ne(Test-CriterionCheck $b $a.Ref)}
            default{$false}
        }
        if($clash){throw "APPROVAL_EVIDENCE:FAIL:criteria $($a.Item) and $($b.Item) cannot both hold - $($a.Raw) and $($b.Raw)"}
    }}
    # A step that names a pinned line says what it does to it: reading or verifying is
    # UNAFFECTED or VERIFY, and WRITE is lawful only beside a change to its pin. SPEC-278's
    # Consumer Closure, copied from SPEC-268, declared WRITE on `Current Module` and
    # `Next capability` while its Step 10 rewrote them after the Primary deployment.
    $rows=EvidenceRows (SubSection (Section $Contract.Text 'Pre-Approval Evidence' -Optional) 'Consumer Closure')
    foreach($pin in $pins){
        $declared=@($rows|Where-Object{"$($_[0]) | $($_[1])".Contains($pin.Key)-and@('WRITE','VERIFY','UNAFFECTED')-contains$_[2]})
        for($i=0;$i-lt@($Contract.Steps).Count;$i++){
            if($Contract.Steps[$i].Contains($pin.Key)-and-not$declared.Count){
                throw "APPROVAL_EVIDENCE:INDETERMINATE:step $($i+1) names pinned line '$($pin.Key)' ($($pin.Path)) and Consumer Closure gives it no disposition - WRITE, VERIFY or UNAFFECTED"
            }
        }
        if(@($declared|Where-Object{$_[2]-eq'WRITE'}).Count){
            if(-not$mayRepin){throw "APPROVAL_EVIDENCE:FAIL:Consumer Closure declares WRITE on pinned line '$($pin.Key)' ($($pin.Path)), whose value is owned by $($pin.Owner); only a contract that also changes its GOVERNANCE.md §6 pin may write it"}
            Assert-AuthorityConsumersCovered $rows $pin $BaseRef 'APPROVAL_EVIDENCE:INDETERMINATE'
        }
    }
    # Introducing or moving a pin is an authority change for that line as well.
    foreach($pin in @(Get-PinRows ($Contract.Steps-join"`n"))){Assert-AuthorityConsumersCovered $rows $pin $BaseRef 'APPROVAL_EVIDENCE:INDETERMINATE'}
}

# CAG. What a governing contract's own text may become, judged by ONE definition at the endpoint
# (the pre-commit hook: the working tree against HEAD) and at every commit of a range (CI: each
# commit against its parent). The walk replayed scope, frozen sections and Approval, not these:
# a contract born inside the published range - every contract, since a Draft is committed only
# at Approval - reached a READY range with a reworded criterion or Review Gate item, unticked
# criteria and no verdict, or a rewritten Execution Log, once its commits skipped the hook with
# `git commit --no-verify`. Each was measured refused by the hook and admitted by CI: SPEC-167
# judged them at HEAD alone, against a base where such a contract does not exist.
function Validate-RecordedText([string]$WasText,$Now){
    if((Status-FromText $WasText)-eq'Draft'){return}
    Validate-EvidenceAppendOnly $WasText $Now
    Validate-Checklist (ChecklistItems (Section $WasText 'Acceptance Criteria' -Optional)) $Now.Acceptance 'ACCEPTANCE_TEXT_MUTATED'
    Validate-Checklist (ChecklistItems (Section $WasText 'Review Gate' -Optional)) $Now.ReviewGate 'REVIEW_GATE_TEXT_MUTATED'
}
# Returns the Approval verdict when this transition is the Approval. $TreeRef is the tree the
# transition produces ('' = working tree); $BaseRef the one it is approved on.
function Validate-TransitionEvidence([string]$WasText,$Now,[string]$TreeRef,[string]$BaseRef){
    $was=Status-FromText $WasText
    if($was-ne'Complete'-and$Now.Status-eq'Complete'){
        Validate-CompletionPrerequisites $Now
        foreach($c in @(Get-CriterionChecks $Now)){
            $why=Test-CriterionCheck $c $TreeRef
            if($why){throw "CRITERION_CHECK_FAILED:criterion $($c.Item) - $($c.Raw): $why"}
        }
    }
    if($was-eq'Draft'-and$Now.Status-eq'Approved'){return Evaluate-PreApprovalEvidence $Now (Profiles $Now.Scope) $BaseRef}
}
# PER-PREDICATE APPLICABILITY (SPEC-210).
#
# SPEC-198 derived applicability ONCE - "did this change reach a special surface" -
# and then asserted that single answer about THREE different questions. Both
# directions were reproduced against this evaluator before it was changed:
#
#   FALSE POSITIVE. A governance-prose contract (Write Scope `AGENTS.md`) that adds
#   no permanent control was still forced to author nine Permanent-Control Admission
#   fields, and its honest `Applicability: NOT APPLICABLE` was refused with
#   "repository evidence makes it applicable" - a claim no repository evidence
#   supported, because none had ever been consulted for that predicate.
#
#   FALSE NEGATIVE. `scripts/parity_surface.sql` decides what the structural parity
#   detector MEASURES, and it is neither a control path nor a profile trigger.
#   SPEC-207 changed it, wrote 68 lines of Pre-Approval Evidence, and this evaluator
#   returned NOT APPLICABLE without reading one of them.
#
# Each predicate now derives its OWN applicability. A contract may still ADD an
# obligation by declaring APPLICABLE; it may never REMOVE one the repository
# derives. That is ENGINEERING_METHOD's rule unchanged - enforced per predicate
# instead of per contract.
function Test-PermanentControlPath([string]$Path){
    # Where a control that runs FOREVER actually lives. `_surface.sql` is here because
    # what a detector measures is part of the detector: PAR-5 was a standing false RED
    # that was MASKING a real drift, and the one file that decided it belonged to no
    # evidence class at all.
    $Path-match'^(scripts/(check|verify|test)_[^/]+|scripts/[^/]*_surface\.sql|supabase/tests/|\.githooks/|\.claude/hooks/|\.github/workflows/)'
}
function Test-EvidenceAuthorityPath([string]$Path){
    # Surfaces other things DEPEND ON. Read HERE and not in `Profiles` for exactly the
    # reason `^supabase/functions/` is: adding them to the profile system would force
    # the whole control suite onto a SQL or prose change and leave two authorities
    # disagreeing about what a DATABASE change is.
    (Test-ControlPath $Path)-or(Test-PermanentControlPath $Path)-or
    $Path-match'^(ENGINEERING_METHOD\.md|CODING_STANDARDS\.md|PROTOCOL\.md|scripts/(publish_candidate|promote_main)\.ps1|scripts/generate-[^/]+\.ps1|supabase/functions/)'
}
# DERIVED VERIFICATION WRITE CLOSURE. A mandatory verification that REGENERATES a
# tracked artifact and byte-compares it makes that artifact part of the contract's
# write surface whether the contract planned to touch it or not. SPEC-203 carried
# `ai-map.json` and not `MASTER_API_CONTRACT.md`, deployed to Primary, and only then
# met Check L3; a frozen Write Scope cannot be widened, so the contract was cancelled
# AFTER an irreversible action. SPEC-205 died to the same shape.
$script:EvidenceWriteClosure=@(
    # SPEC-270: Check 7 reproduces both projections, and both read every canonical header.
    @{When='^_ORVION_CANONICAL/[^/]+\.md$';Needs='ai-map.json'
      Why='mandatory Check 7 regenerates ai-map.json from the canonical documents and byte-compares it'},
    @{When='^_ORVION_CANONICAL/[^/]+\.md$';Needs='repository-index.md'
      Why='mandatory Check 7 regenerates repository-index.md from the canonical documents and byte-compares it'},
    @{When='^supabase/migrations/';Needs='reports/master/MASTER_API_CONTRACT.md'
      Why='mandatory Check L3 regenerates the API contract from the live surface and byte-compares it'}
)
function Evaluate-PreApprovalEvidence($Contract,[string[]]$Profiles,[string]$BaseRef='HEAD'){
    # DERIVED applicability, from the inputs ENGINEERING_METHOD actually names: Write
    # Scope, derived verification profiles, known control/governance surfaces,
    # cross-path triggers and a declared irreversible action. SPEC-196 implemented only
    # the control-surface one, so a DATABASE, CI, WORKSTATION or Edge Function contract
    # had its evidence SKIPPED while the Gate still printed `APPROVAL_EVIDENCE: PASS` -
    # reproduced on the real Draft->Approved path, invalid three ways, admitted (SPEC-198).
    #
    # `REPOSITORY` is the profile every contract derives unconditionally, so "any other
    # profile" is exactly the statement "this change reached a surface the profile system
    # marks as special". Written against the SHAPE of that system rather than a list of
    # its current members, so adding a profile later needs no edit here.
    # Write closure is judged on Write Scope ALONE and BEFORE applicability, because it
    # is a property of the contract's write surface rather than of its evidence section:
    # SPEC-203 was a DATABASE contract, but a REPOSITORY-only contract that touches the
    # manifest carries the identical Check 7 obligation. Skipped when the artifact does
    # not exist, so retiring one needs no edit here.
    foreach($rule in $script:EvidenceWriteClosure){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $rule.Needs))){continue}
        if(-not @($Contract.Scope|Where-Object{$_-match$rule.When}).Count){continue}
        if($Contract.Scope-notcontains$rule.Needs){
            throw "APPROVAL_EVIDENCE:FAIL:write closure - $($rule.Needs) is regenerated by a mandatory verification ($($rule.Why)) but is not in Write Scope"
        }
    }
    # SPEC-281, judged before applicability for the same reason: a pinned line, a criterion
    # check and an authority change bind whatever the rest of the section derives.
    Assert-AssuranceAdmission $Contract $BaseRef
    $applicable=@($Profiles|Where-Object{$_-ne'REPOSITORY'}).Count-gt0
    if(-not $applicable){
        foreach($p in $Contract.Scope){
            # Edge Functions derive NO profile and are not a control surface, yet this
            # repository's only one authorizes itself with the service_role key, bypasses
            # RLS and destroys customer documents. It is the single execution surface no
            # other mechanical input reaches; adding it to `Profiles` instead would
            # disagree with migration-ci.yml and force the database protocol on a
            # TypeScript change, so the path is read HERE and nowhere else.
            if(Test-EvidenceAuthorityPath $p){$applicable=$true;break}
        }
    }
    $body=Section $Contract.Text 'Pre-Approval Evidence' -Optional
    # A contract's own declared irreversible action is an applicability input. It can only
    # ADD an obligation, never remove one, so it is consulted last and only when a section
    # exists - a contract cannot be made applicable by a section it does not have. `NONE`
    # is matched as a prefix because the established idiom writes the reason after it.
    if(-not $applicable-and$null-ne$body-and(Normalize $body)-ne''){
        $irr=EvidenceField (SubSection $body 'Execution-Boundary Satisfiability') 'Irreversible Action Step'
        if($irr-and$irr-notmatch'^\s*NONE\b'){$applicable=$true}
    }
    # NOT the same word as PASS. `ENGINEERING_METHOD` states that "we did not look" and
    # "we looked and it is fine" are different facts; reporting PASS for a section that
    # was never read asserted the very thing this evaluator exists to establish.
    if(-not $applicable){return 'NOT APPLICABLE'}
    if($null-eq$body-or(Normalize $body)-eq''){throw 'APPROVAL_EVIDENCE:INDETERMINATE:section missing for control-scope work'}

    # Self-exemption. Repository evidence says applicable; the contract may not
    # answer otherwise. A contradiction is INDETERMINATE, never a quiet pass.
    # Consumer Closure and Execution-Boundary Satisfiability follow the contract-level
    # trigger: anything that reaches one of these surfaces HAS consumers, and a frozen
    # sequence is either satisfiable or it is not. Permanent-Control Admission is the one
    # predicate with a sharp repository-derived answer, and it is the expensive one -
    # nine mandatory fields describing a control the contract may not be adding at all.
    $derived=[ordered]@{
        'Consumer Closure'=$applicable
        'Execution-Boundary Satisfiability'=$applicable
        'Permanent-Control Admission'=@($Contract.Scope|Where-Object{Test-PermanentControlPath $_}).Count-gt0
    }
    $due=@{}
    foreach($name in $derived.Keys){
        $sub=SubSection $body $name
        $state=if($null-eq$sub){''}else{EvidenceField $sub 'Applicability'}
        if($derived[$name]){
            if($null-eq$sub){throw "APPROVAL_EVIDENCE:INDETERMINATE:$name missing"}
            if($state-ne'APPLICABLE'){
                throw "APPROVAL_EVIDENCE:INDETERMINATE:$name declared not applicable while repository evidence makes it applicable"
            }
        }
        # A predicate the repository does NOT derive may still be VOLUNTEERED, and is then
        # held to the full obligation - a label adds, never removes. Silence is exemption
        # only where the repository already agrees.
        $due[$name]=$derived[$name]-or($state-eq'APPLICABLE')
    }
    # The hand-written table is now a RESTATEMENT of a derivation, so it is compared
    # against that derivation rather than required to read APPLICABLE throughout. A row
    # for a predicate this function does not derive - `SPEC Allocation` - is not judged
    # here at all: `Validate-SpecAllocation` is its sole enforcement authority and runs
    # mechanically on every range regardless of what any contract writes about it.
    foreach($row in (EvidenceRows (SubSection $body 'Derived Applicability'))){
        if($derived.Contains($row[0])-and$derived[$row[0]]-and$row[-1]-ne'APPLICABLE'){
            throw 'APPROVAL_EVIDENCE:INDETERMINATE:derived applicability contradicts repository evidence'
        }
    }

    # D - CONSUMER CLOSURE. Closes what DEPENDS on a changed fact, which is a
    # different question from Write Scope's what may be modified, so it is never
    # satisfied by restating the file list.
    $d=SubSection $body 'Consumer Closure'
    $rows=EvidenceRows $d
    if($due['Consumer Closure']){
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
    }

    # F - EXECUTION-BOUNDARY SATISFIABILITY. Bounded checkpoint comparison, never
    # simulation. SPEC-195 froze a sequence whose Step-12 gate demanded an
    # invariant green between the Step-10 that broke it and the Step-13 that
    # repaired it; that contract was approved and then cancelled for exactly this.
    $f=SubSection $body 'Execution-Boundary Satisfiability'
    $stepCount=@($Contract.Steps).Count
    $frows=EvidenceRows $f
    if($due['Execution-Boundary Satisfiability']){
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
    }

    # H/J - PERMANENT CONTROL ADMISSION. Pre-Approval freezes the OBLIGATIONS and
    # the already-reproduced causal negative. Actual positive/negative/population/
    # mutation proof belongs to the certified suite after the code exists, so this
    # never demands proof of code that has not been written.
    if($due['Permanent-Control Admission']){
        $hj=SubSection $body 'Permanent-Control Admission'
        foreach($field in @('Existing Mechanism Reusable','Existing Mechanism','Added Property','Causal Negative',
                            'Positive Test Design','Negative Test Design','Non-Empty Population Obligation',
                            'Mutation Obligation','Post-Implementation Proof Obligation')){
            if((EvidenceField $hj $field)-eq''){throw "APPROVAL_EVIDENCE:INDETERMINATE:permanent-control obligation missing: $field"}
        }
    }
    'PASS'
}

# CTRL-4 (SPEC-255). Every immutability comparison below is ORDINAL. PowerShell's `-ne`
# and .NET's default `StartsWith` compare by CULTURE: `-ne` ignores case, and both treat NUL,
# backspace, zero-width space and soft hyphen as zero-weight and composed and decomposed
# letters as equal. Measured: each of those edits to frozen or prior text passed these checks
# while a visible edit was refused. Frozen means the same code points.
function Same-Text([string]$A,[string]$B){[string]::Equals($A,$B,[StringComparison]::Ordinal)}

function Validate-FrozenAuthority([string]$BaselineText,[string]$CurrentText){
    foreach($name in $script:FrozenSections){
        $was=Normalize (Section $BaselineText $name -Optional)
        $now=Normalize (Section $CurrentText $name -Optional)
        if(-not(Same-Text $was $now)){throw "FROZEN_AUTHORITY_MUTATED:$name"}
    }
    $wasScope=Normalize (Section-OutOfScope $BaselineText)
    $nowScope=Normalize (Section-OutOfScope $CurrentText)
    if(-not(Same-Text $wasScope $nowScope)){throw 'FROZEN_AUTHORITY_MUTATED:Out of Scope'}
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
        if($pair.Was-and-not$pair.Now.StartsWith($pair.Was,[StringComparison]::Ordinal)){throw "EVIDENCE_NOT_APPEND_ONLY:$($pair.Name)"}
    }
}

# CTRL-4 (SPEC-255). A governed contract gains no character a reader cannot see: C0 controls
# other than TAB, LF and a CRLF's CR; DEL and C1; and the invisible format characters (soft
# hyphen, zero-width and joiner characters, bidirectional controls, word joiner, BOM). One NUL
# made SPEC-250 invisible to every recursive search; a BEL from the same PowerShell escape sits
# in SPEC-239. A variation selector stays legal after a symbol, where it selects emoji
# presentation. COUNTED against the baseline, so text already in history is preserved and only
# an addition is refused; rewriting prior text is already refused by the ordinal checks above.
$script:ProhibitedCharacter='[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180B-\u180F\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\u3164\uFEFF\uFFA0\uFFF9-\uFFFB]|\r(?!\n)|(?<![\u2000-\u2BFF\uDC00-\uDFFF])[\uFE00-\uFE0F]'
function Validate-NoNewProhibitedCharacter([string]$BaselineText,[string]$CurrentText){
    $now=[regex]::Matches("$CurrentText",$script:ProhibitedCharacter)
    if($now.Count-gt([regex]::Matches("$BaselineText",$script:ProhibitedCharacter)).Count){
        throw ('PROHIBITED_CHARACTER:U+{0:X4}' -f [int][char]$now[$now.Count-1].Value[0])
    }
}
# The character rule is FORWARD-ONLY, declared in the same authority and read the same way as
# CTRL-1's boundary. A transition whose before-state descends from the declared commit is judged;
# one that predates it keeps the verdict it was published under (SPEC-239's range added its BEL
# legally). Unprovable means protect: a missing marker or an unknown boundary reads as active.
# The boundary cannot be MOVED (SPEC-255). Reproduced on SPEC-251's evaluator: a range whose
# contract owned this authority pointed the marker at an unrelated branch, or forward past its own
# BEL, and CI read READY. The declared value is a boundary only if it lies in the history of the
# commit that declares it, and only if it is the value FIRST committed there; anything else is
# unprovable and protects. Computed once per run.
$script:CharacterBoundary=$null
function Get-CharacterBoundary{
    if($null-ne$script:CharacterBoundary){return $script:CharacterBoundary}
    $script:CharacterBoundary=''
    $markerRx='(?m)^Evidence Character Enforcement:\s*(?<v>[0-9a-f]{40})\s*$'
    $local=Join-Path $Root $script:HistoricalAuthority
    $text=if(Test-Path -LiteralPath $local){[IO.File]::ReadAllText($local)}else{''}
    $m=[regex]::Match($text,$markerRx)
    if(-not $m.Success){return ''}
    $declared=$m.Groups['v'].Value
    git -C $Root merge-base --is-ancestor $declared HEAD 2>$null|Out-Null
    $inHistory=$LASTEXITCODE;$global:LASTEXITCODE=0
    if($inHistory-ne0){return ''}
    $first=@(git -C $Root log --reverse --format=%H -G '^Evidence Character Enforcement:' HEAD -- $script:HistoricalAuthority 2>$null)|Select-Object -First 1
    $global:LASTEXITCODE=0
    if(!$first){return ''}
    $was=[regex]::Match(((git -C $Root show "${first}:$($script:HistoricalAuthority)" 2>$null)-join"`n"),$markerRx).Groups['v'].Value
    $global:LASTEXITCODE=0
    if(-not(Same-Text $was $declared)){return ''}
    $script:CharacterBoundary=$declared
    $declared
}
function Character-Guard-IsActive([string]$Ref){
    if(!$BaseRef){return $true}
    $boundary=Get-CharacterBoundary
    if(!$boundary){return $true}
    git -C $Root merge-base --is-ancestor $boundary $Ref 2>$null|Out-Null
    # Captured into a distinct local, reset only through $global: (the CTRL-1 shadow trap above).
    $ancestorCode=$LASTEXITCODE;$global:LASTEXITCODE=0
    # 0 descends, 1 predates; anything else (a boundary this clone lacks) protects.
    $ancestorCode-ne1
}

# Wording and item count are frozen; only an unchecked box may become checked.
# Otherwise an agent could soften the criteria it is about to certify against.
function Validate-Checklist([object[]]$Was,[object[]]$Now,[string]$Code){
    if($Was.Count-ne$Now.Count){throw "${Code}:count $($Was.Count)->$($Now.Count)"}
    for($i=0;$i-lt$Was.Count;$i++){
        if(-not(Same-Text $Was[$i].Text $Now[$i].Text)){throw "${Code}:item $($i+1) reworded"}
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
function Validate-CommittedRange([string]$Rel,[hashtable]$SharedTerminal=$null){
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

    # Segments share terminal history: closing A makes its contract immutable
    # while every later governor is validated.
    $terminal=$SharedTerminal
    if($null-eq$terminal){$terminal=@{}}
    $touched=@{}
    # A cross-identity rename of the GOVERNING contract leaves its former path in
    # the diff. Without this the contract's own earlier name reads as a foreign
    # file and the range is refused OUT_OF_SCOPE_WRITE - which is exactly how this
    # repository's own SPEC-1002 -> SPEC-196 correction became unpublishable.
    # Renaming an identity is a first-class event here, so its lineage is followed.
    $aliases=@{}
    $script:PinnedPaths=@(@(Get-PinnedAuthority $BaseRef)+@(Get-PinnedAuthority $HeadRef)|ForEach-Object{$_.Path}|Sort-Object -Unique)

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
        # SPEC-256. A range whose ORIGINAL base is already under enforcement judges every commit,
        # so removing the marker inside the range cannot suspend the rule (case 191g).
        if($script:RangeAllocationActive-or(Allocation-ActiveAt "$commit^")){
            try{Validate-SpecAllocation $records "$commit^" -SkipMarkerCheck -CheckOrigination -StateRef $commit}catch{throw "$($_.Exception.Message)@$short"}
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
                # Write authority is judged at the commit that wrote. While the governor was still a Draft it
                # carried none (CR_LIFECYCLE.md, SPEC-163), so neither a carrying successor (SPEC-273) nor its
                # own later approval (CTRL-16, completed or still open) may legalise such a write.
                if($statusAt-eq'Draft'){foreach($w in $paths){if($w-ne$governing-and-not$aliases.ContainsKey($w)){throw "PRE_APPROVAL_WRITE:${w}@$short"}}}
                # The commit that leaves Draft is the one that freezes authority, so
                # it supplies the baseline every later commit is judged against.
                if(-not$frozenBound-and$statusAt-and$statusAt-ne'Draft'){$FrozenBaseline=$text;$frozenBound=$true}
                if($frozenBound){try{Validate-FrozenAuthority $FrozenBaseline $text}catch{throw "$($_.Exception.Message)@$short"}}
                # SPEC-200 (CTRL-2B). The evidence call site at the endpoint is keyed on the
                # RANGE'S final status, so a push carrying `Approve` and `In Progress`
                # together - the ordinary shape - ended at `In Progress` and never judged
                # its own Approval. The transition is a property of a COMMIT, so it is
                # replayed here, on the commit that actually performs it, reading that
                # commit's own contract text and deriving applicability from that
                # contract's own Write Scope. A later commit therefore cannot launder an
                # invalid Approval. SPEC-281: the same holds for every transition the hook
                # judges, so each commit that changes the contract is judged by the two
                # functions the endpoint uses, against its own parent.
                $parentText=Read-GitFile "$commit^" $governing
                # CTRL-4: judged per commit, so a character added and later removed inside one range is still refused.
                if(Character-Guard-IsActive "$commit^"){try{Validate-NoNewProhibitedCharacter $parentText $text}catch{throw "$($_.Exception.Message)@$short"}}
                if($null-ne$parentText-and-not(Same-Text $parentText $text)){
                    try{
                        $atCommit=Contract-FromText $text ([IO.Path]::GetFileName($governing)) $governing
                        Validate-RecordedText $parentText $atCommit
                        Validate-TransitionEvidence $parentText $atCommit $commit "$commit^"|Out-Null
                    }catch{throw "$($_.Exception.Message)@$short"}
                }
            }
            # Scope comes from the frozen baseline on purpose: a commit that
            # widened its own Write Scope must not thereby authorise its own writes.
            $scopeAt=@(Bullets (Section $FrozenBaseline 'Write Scope') 'WRITE_SCOPE'|%{$_-replace'\\','/'})
            foreach($p in $paths){
                if($p-ne$governing-and-not$aliases.ContainsKey($p)-and$scopeAt-notcontains$p){throw "OUT_OF_SCOPE_WRITE:${p}@$short"}
            }
            # SPEC-281 (ACI). A commit that adds, moves or removes a pin, or changes a pinned line,
            # made an authority change; the approved Consumer Closure must cover its consumers.
            if($frozenBound-and@($paths|Where-Object{$_-eq'GOVERNANCE.md'-or$script:PinnedPaths-contains$_}).Count){
                $ccRows=EvidenceRows (SubSection (Section $FrozenBaseline 'Pre-Approval Evidence' -Optional) 'Consumer Closure')
                foreach($pin in @(Get-PinChanges "$commit^" $commit)){
                    try{Assert-AuthorityConsumersCovered $ccRows $pin "$commit^" 'AUTHORITY_CONSUMER_UNCOVERED'}catch{throw "$($_.Exception.Message)@$short"}
                }
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

    # SPEC-273. The range is also judged by its NET diff against the same frozen scope. The walk
    # above has no baseline until the governor first appears, so a commit made before that was
    # judged by nothing once a publication had a second segment. A single-segment range already
    # had this from the endpoint check; for a publication segment this is the only judge.
    if($null-ne$FrozenBaseline){
        $netScope=@(Bullets (Section $FrozenBaseline 'Write Scope') 'WRITE_SCOPE'|%{$_-replace'\\','/'})
        foreach($r in @(Diff-Records)){foreach($q in @($r.Path,$r.Old)|?{$_}){if($q-ne$governing-and-not$aliases.ContainsKey($q)-and$netScope-notcontains$q){throw "OUT_OF_SCOPE_WRITE:$q"}}}
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
# A full-line comment between bullets is part of the list, not its end (SPEC-263).
# `repository-consistency.yml` documents its paths that way, and stopping at the
# first comment read two of its fourteen push globs.
function Trigger-List([string]$Body,[string]$Key){
    $m=[regex]::Match($Body,"(?m)^[ \t]*$([regex]::Escape($Key)):[ \t]*(?<inline>\[[^\]\r\n]*\])?[ \t]*\r?\n?")
    if(!$m.Success){return @()}
    if($m.Groups['inline'].Success){
        return @($m.Groups['inline'].Value.Trim('[',']')-split','|%{$_.Trim().Trim('"').Trim("'")}|?{$_})
    }
    $items=@()
    foreach($line in @($Body.Substring($m.Index+$m.Length)-split'\r?\n')){
        if($line-match'^\s*-\s*"?(?<v>[^"\r\n]+?)"?\s*$'){$items+=$Matches['v'].Trim()}
        elseif($line-match'^\s*#'){continue}
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

function Certification-Paths($Contract,[string]$Rel){
    $upstream=(git -C $Root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
    if($LASTEXITCODE-ne0){throw 'GIT_UPSTREAM_MISSING'}
    $upstream=("$upstream").Trim()
    $changed=@(git -C $Root diff --name-only "$upstream..HEAD" --)
    if($LASTEXITCODE-ne0){throw 'PUBLICATION_RANGE_DIFF_FAILED'}
    $prior=@($changed|?{$_-match'^changes/SPEC-[0-9]+-.*\.md$'-and$_-ne$Rel}|?{
        $atHead=Read-GitFile HEAD $_
        if($null-eq$atHead){return $false}
        try{(Status-FromText $atHead)-eq'Complete'}catch{$false}
    })
    # Single-contract Finish retains the established scope-based expectation.
    # Multiple completed contracts are one push, judged by that push's paths.
    if(!$prior.Count){return @($Contract.Scope|%{$_-replace'\\','/'})}
    $dirty=@(git -C $Root status --porcelain)
    if($LASTEXITCODE-ne0){throw 'PUBLICATION_RANGE_STATUS_FAILED'}
    if($dirty.Count){throw 'PUBLICATION_RANGE_UNCOMMITTED'}
    return @($changed)
}
function Write-Certification($Contract,[string]$Rel,[string[]]$Profiles){
    $target=Target-Branch
    $receipt=[ordered]@{
        # Receipt Schema: 2. Finish is the only origin of verification claims.
        schema=2
        contract=$Rel
        finishHead=("$(git -C $Root rev-parse HEAD)").Trim()
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
        expected=@(Workflow-Expectations @(Certification-Paths $Contract $Rel) $target)
        result='READY'
        at=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    $receipt.digest=Receipt-Digest $receipt
    [IO.File]::WriteAllText((Receipt-Path),(ConvertTo-Json $receipt -Depth 12),(New-Object Text.UTF8Encoding($false)))
}

function Receipt-Json($Value){
    # Canonical key order, recursively; arrays retain their order and empty arrays.
    if($null-eq$Value){return 'null'}
    # Pipeline-decorated strings can also satisfy -is [pscustomobject]. Serialize
    # scalar values before examining object properties (a string's Length is not data).
    if($Value-is[string]-or$Value-is[ValueType]){return (ConvertTo-Json -InputObject $Value -Compress)}
    if($Value-is[Collections.IDictionary]-or$Value-is[pscustomobject]){
        $keys=[string[]]$(if($Value-is[Collections.IDictionary]){@($Value.Keys)}else{@($Value.PSObject.Properties.Name)})
        [Array]::Sort($keys,[StringComparer]::Ordinal)
        $parts=@(foreach($key in $keys){
            if($Value-is[Collections.IDictionary]){$v=$Value[$key]}else{$v=$Value.$key}
            (ConvertTo-Json -InputObject $key -Compress)+':'+(Receipt-Json $v)
        })
        return '{'+($parts-join',')+'}'
    }
    if($Value-is[Collections.IEnumerable]-and$Value-isnot[string]){
        return '['+(@(foreach($v in $Value){Receipt-Json $v})-join',')+']'
    }
    ConvertTo-Json -InputObject $Value -Compress -Depth 30
}
function Receipt-Digest($Record){
    $fields=[ordered]@{}
    if($Record-is[Collections.IDictionary]){foreach($k in $Record.Keys){if($k-cne'digest'){$fields[$k]=$Record[$k]}}}
    else{foreach($p in $Record.PSObject.Properties){if($p.Name-cne'digest'){$fields[$p.Name]=$p.Value}}}
    Get-TextSha256 (Receipt-Json $fields)
}
function Assert-ReceiptDigest($Record){
    if($null-eq$Record-or$Record.digest-isnot[string]-or$Record.digest-cnotmatch'^[0-9a-f]{64}$'-or$Record.digest-cne(Receipt-Digest $Record)){throw 'RECEIPT_ALTERED'}
}
function Receipt-Value([System.Text.Json.JsonElement]$Element){
    # ConvertFrom-Json converts ISO timestamps into DateTime on supported PS versions,
    # changing their subsequent JSON spelling. Preserve JSON string values exactly.
    switch("$($Element.ValueKind)"){
        'Object'{
            $fields=[ordered]@{}
            foreach($p in $Element.EnumerateObject()){
                if($fields.Contains($p.Name)){throw 'RECEIPT_DUPLICATE_FIELD'}
                $fields[$p.Name]=Receipt-Value $p.Value
            }
            return [pscustomobject]$fields
        }
        'Array'{return ,@(foreach($v in $Element.EnumerateArray()){Receipt-Value $v})}
        'String'{return $Element.GetString()}
        'Number'{return $Element.GetInt64()}
        'True'{return $true}
        'False'{return $false}
        'Null'{return $null}
        default{throw 'RECEIPT_VALUE_INVALID'}
    }
}
function Read-ReceiptJson([string]$Path){
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)){throw "RECEIPT_MISSING:$Path"}
    $document=$null
    try{$document=[System.Text.Json.JsonDocument]::Parse([IO.File]::ReadAllText($Path));$r=Receipt-Value $document.RootElement}catch{throw "RECEIPT_UNREADABLE:$Path"}
    finally{if($document){$document.Dispose()}}
    if($r-isnot[pscustomobject]){throw "RECEIPT_UNREADABLE:$Path"}
    $r
}
function Assert-Certification($receipt,$Contract,[string]$Rel,[string[]]$Profiles,[switch]$Historical){
    if($receipt.result-cne'READY'){throw "COMPLETION_PREREQUISITE:certification result $($receipt.result)"}
    if($receipt.cr-cne$Contract.Id){throw "COMPLETION_PREREQUISITE:certification receipt names $($receipt.cr), not $($Contract.Id)"}
    $certified=(@($receipt.profiles|Sort-Object)-join',');$derived=(@($Profiles|Sort-Object)-join',')
    if($certified-cne$derived){throw "COMPLETION_PREREQUISITE:certification profiles $certified do not match the derived $derived"}
    if(!$Historical-and$receipt.fingerprint-ne(Implementation-Fingerprint $Contract $Rel)){throw 'COMPLETION_PREREQUISITE:stale certification receipt - the implementation changed after it was certified'}
    if($receipt.schema-isnot[ValueType]-or$receipt.schema-ne2){throw 'RECEIPT_SCHEMA_UNSUPPORTED:run -Finish; legacy evidence cannot be upgraded'}
    Assert-ReceiptDigest $receipt
    if($receipt.cr-isnot[string]-or$receipt.result-isnot[string]-or$receipt.contract-isnot[string]-or$receipt.profiles-isnot[array]){throw 'RECEIPT_IDENTITY_OR_PROFILES_INVALID'}
    if($receipt.contract-cne$Rel){throw 'RECEIPT_IDENTITY_MISMATCH'}
    if($receipt.contract-cnotmatch('^changes/'+[regex]::Escape($Contract.Id)+'-[A-Za-z0-9_.-]+\.md$')){throw 'RECEIPT_CONTRACT_INVALID'}
    if($receipt.finishHead-isnot[string]-or$receipt.finishHead-cnotmatch'^[0-9a-f]{40}$'){throw 'RECEIPT_BASE_INVALID'}
    Assert-Ref $receipt.finishHead
    if($receipt.fingerprint-isnot[string]-or$receipt.fingerprint-cnotmatch'^[0-9a-f]{64}$'){throw 'RECEIPT_FINGERPRINT_INVALID'}
    if($receipt.target-isnot[string]-or!$receipt.target.Trim()){throw 'RECEIPT_CONTEXT_MISSING:target branch missing; run -Finish'}
    git -C $Root check-ref-format "refs/heads/$($receipt.target)" *> $null
    if($LASTEXITCODE-ne0){throw 'RECEIPT_TARGET_INVALID'}
    if($receipt.expected-isnot[array]-or!@($receipt.expected).Count-or@($receipt.expected|Where-Object{$_-isnot[string]-or!$_.Trim()}).Count){throw 'RECEIPT_CONTEXT_MISSING:expected workflows missing; run -Finish'}
    $at=[datetime]::MinValue
    if($receipt.at-isnot[string]-or![datetime]::TryParseExact($receipt.at,'yyyy-MM-ddTHH:mm:ssZ',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal,[ref]$at)){throw 'RECEIPT_TIME_INVALID'}
}
function Validate-Certification($Contract,[string]$Rel,[string[]]$Profiles){
    $path=Receipt-Path
    if(!(Test-Path -LiteralPath $path)){throw 'COMPLETION_PREREQUISITE:no local certification receipt - run -Finish and earn LOCAL_CERTIFY: READY first'}
    $receipt=Read-ReceiptJson $path
    Assert-Certification $receipt $Contract $Rel $Profiles
}

function Candidate-ReceiptPath([string]$Sha){
    if($Sha-cnotmatch'^[0-9a-f]{40}$'){throw 'RECEIPT_SHA_INVALID'}
    Join-Path $Root ".orvion-certifications/$Sha.json"
}
function Candidate-Contract([string]$Sha,[string]$Rel){
    # Minimal historical projection: never apply today's whole-contract schema to history.
    if($Rel-cnotmatch'^changes/(?<id>SPEC-[0-9]+)-[A-Za-z0-9_.-]+\.md$'){throw 'RECEIPT_CONTRACT_INVALID'}
    $id=$Matches.id
    $text=Read-GitFile $Sha $Rel
    if(!$text-or$text-cnotmatch('(?m)^# Change Request — '+[regex]::Escape($id)+'\s*$')){throw 'RECEIPT_IDENTITY_MISMATCH'}
    if((Status-FromText $text)-ne'Complete'-or(Status-FromText (Read-GitFile "$Sha^" $Rel))-ne'In Progress'){throw 'RECEIPT_NOT_COMPLETION_SHA'}
    [pscustomobject]@{Id=$id;Status='Complete';Scope=@(Bullets (Section $text 'Write Scope') 'WRITE_SCOPE')}
}
function Read-CandidateReceipt([string]$Sha,[string]$Rel,[switch]$Historical){
    $record=Read-ReceiptJson (Candidate-ReceiptPath $Sha)
    Assert-ReceiptDigest $record
    if($record.schema-ne2-or$record.candidate-cne$Sha){throw 'RECEIPT_SHA_MISMATCH'}
    $c=Candidate-Contract $Sha $Rel
    Assert-Certification $record.receipt $c $Rel @(Profiles $c.Scope) -Historical:$Historical
    git -C $Root merge-base --is-ancestor $record.receipt.finishHead $Sha *> $null
    if($LASTEXITCODE-ne0){throw 'RECEIPT_BASE_NOT_ANCESTOR'}
    $record
}
function Bind-CandidateReceipt($c,[string]$Rel,[string[]]$Profiles,[string]$Sha){
    if(@(git -C $Root status --porcelain).Count){throw 'RECEIPT_DIRTY_TREE'}
    if($Sha-cne("$(git -C $Root rev-parse HEAD)").Trim()){throw 'RECEIPT_SHA_MISMATCH'}
    if($c.Status-ne'Complete'){
        Write-Output 'PREPARE: NONTERMINAL (no completion record created)'
        return
    }
    $path=Candidate-ReceiptPath $Sha
    if(Test-Path -LiteralPath $path){
        $null=Read-CandidateReceipt $Sha $Rel
    }else{
        $receipt=Read-ReceiptJson (Receipt-Path)
        Assert-Certification $receipt $c $Rel $Profiles
        $null=Candidate-Contract $Sha $Rel
        git -C $Root merge-base --is-ancestor $receipt.finishHead $Sha *> $null
        if($LASTEXITCODE-ne0){throw 'RECEIPT_BASE_NOT_ANCESTOR'}
        $record=[ordered]@{schema=2;candidate=$Sha;receipt=$receipt}
        $record.digest=Receipt-Digest $record
        [void][IO.Directory]::CreateDirectory((Split-Path $path -Parent))
        $temp="$path.$([guid]::NewGuid().ToString('N')).tmp"
        try{
            [IO.File]::WriteAllText($temp,(ConvertTo-Json $record -Depth 12),[Text.UTF8Encoding]::new($false))
            # No overwrite, including a record created concurrently. An interrupted temp file
            # is never a selectable record; retry still needs the original working receipt.
            [IO.File]::Move($temp,$path,$false)
        }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force}}
        $null=Read-CandidateReceipt $Sha $Rel
    }
    Write-Output "PREPARED: $Sha"
    Write-Output 'PREPARE: READY (local evidence bound; publication unproven)'
}

function Pending-Completions([string]$Upstream){
    foreach($sha in @(git -C $Root rev-list --reverse "$Upstream..HEAD")){
        foreach($r in @(Records-For $sha)){
            if($r.Path-notmatch'^changes/SPEC-[0-9]+-.*\.md$'){continue}
            $now=Read-GitFile $sha $r.Path
            if(!$now){continue}
            if((Status-FromText $now)-eq'Complete'-and(Status-FromText (Read-GitFile "$sha^" $r.Path))-ne'Complete'){
                [pscustomobject]@{Sha=$sha;Rel=$r.Path}
            }
        }
    }
}
function Receipt-AlreadyPromoted($Receipt){
    # Cutover retires legacy evidence only on positive Git evidence, never by age,
    # by the current CR, or by upgrading a legacy claim into schema 2.
    if(!$Receipt.cr-or$Receipt.target-isnot[string]-or!$Receipt.target.Trim()){return $false}
    git -C $Root check-ref-format "refs/heads/$($Receipt.target)" *> $null
    if($LASTEXITCODE-ne0){return $false}
    $target="refs/remotes/origin/$($Receipt.target)"
    $paths=@(git -C $Root ls-tree -r --name-only $target -- changes 2>$null|Where-Object{$_-cmatch('^changes/'+[regex]::Escape($Receipt.cr)+'-[A-Za-z0-9_.-]+\.md$')})
    if($LASTEXITCODE-ne0-or$paths.Count-ne1){return $false}
    $text=Read-GitFile $target $paths[0]
    if(!$text-or(Status-FromText $text)-ne'Complete'){return $false}
    if($Receipt.schema-eq2){
        try{Assert-ReceiptDigest $Receipt;Assert-Ref $Receipt.finishHead}catch{return $false}
        git -C $Root merge-base --is-ancestor $Receipt.finishHead $target *> $null
        if($LASTEXITCODE-ne0){return $false}
    }
    return $true
}
function Protect-PendingCertifications($c,[string]$Rel){
    $upstream=git -C $Root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    if($LASTEXITCODE-ne0){throw 'GIT_UPSTREAM_MISSING'}
    $saved=@()
    foreach($pending in @(Pending-Completions ("$upstream").Trim())){
        if($pending.Rel-ceq$Rel){continue}
        try{
            $record=Read-CandidateReceipt $pending.Sha $pending.Rel -Historical
            git -C $Root merge-base --is-ancestor $pending.Sha HEAD *> $null
            if($LASTEXITCODE-ne0){throw 'RECEIPT_CANDIDATE_NOT_ANCESTOR'}
            $saved+=,$record
        }catch{throw "PENDING_RECEIPT_UNBOUND:$($pending.Sha):$($_.Exception.Message)"}
    }
    if(Test-Path -LiteralPath (Receipt-Path)){
        $prior=Read-ReceiptJson (Receipt-Path)
        # Same-CR retry still removes its previous receipt before any verification.
        if($prior.cr-ceq$c.Id){return}
        if(Receipt-AlreadyPromoted $prior){return}
        if($prior.schema-ne2){throw 'PENDING_RECEIPT_UNBOUND:legacy evidence is not proven promoted'}
        Assert-ReceiptDigest $prior
        if(!@($saved|Where-Object{$_.receipt.digest-ceq$prior.digest}).Count){throw 'PENDING_RECEIPT_UNBOUND:working evidence has no retained pending candidate'}
    }
}
function Select-Certification([string]$Sha){
    if(@(git -C $Root status --porcelain).Count){throw 'RECEIPT_DIRTY_TREE'}
    $m=Manifest
    if(!$m.Active){
        # A completed HEAD has exactly one door: its exact-SHA record. Never borrow
        # the active working receipt, even when it happens to name this CR.
        $record=Read-ReceiptJson (Candidate-ReceiptPath $Sha)
        return (Read-CandidateReceipt $Sha $record.receipt.contract).receipt
    }
    $c=Contract (Join-Path $Root $m.Active)
    if($c.Status-notin@('Approved','In Progress')){throw 'RECEIPT_IDENTITY_MISMATCH'}
    $receipt=Read-ReceiptJson (Receipt-Path)
    Assert-Certification $receipt $c $m.Active @(Profiles $c.Scope)
    if($receipt.finishHead-cne$Sha){throw 'RECEIPT_SHA_MISMATCH'}
    $receipt
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

function Get-PublicationSegments {
    $segments=@();$start=$BaseRef
    foreach($commit in @(git -C $Root rev-list --reverse "$BaseRef..$HeadRef")){
        $closed=@();$cancelled=@()
        foreach($r in @(Records-For $commit)){
            $p=$r.Path
            if($p-notmatch '^changes/SPEC-[0-9]+-.*\.md$'){continue}
            $now=Read-GitFile $commit $p
            $old=Read-GitFile "$commit^" $p
            if($null-eq$now){continue}
            $nowStatus=try{Status-FromText $now}catch{''}
            $oldStatus=if($null-ne$old){try{Status-FromText $old}catch{''}}else{''}
            if($nowStatus-eq'Complete'-and$oldStatus-ne'Complete'){$closed+=$p}
            elseif($nowStatus-eq'Cancelled'-and$oldStatus-ne'Cancelled'){$cancelled+=$p}
        }
        # A simultaneous completion has no unique governor. The ordinary
        # resolver refuses it when no CR remains active, but an active tail
        # would take its fast path and hide both completions. Refuse here.
        if($closed.Count-gt1){throw 'AMBIGUOUS_GOVERNING_CR'}
        if($closed.Count-eq1){
            $segments+=,[pscustomobject]@{Start=$start;End=$commit;Rel=$closed[0];Cancelled=$false}
            $start=$commit
        }elseif($closed.Count-eq0-and$cancelled.Count-eq1){
            # SPEC-273. A cancellation committed on its own closes its own segment, governed by the
            # cancelled contract's frozen scope. Validate-PublicationSegments admits that segment only
            # when a later completed governor declares it in Supersedes / Depends On. A cancellation in
            # the same commit as a completion is still judged by the completion alone (SPEC-171).
            $segments+=,[pscustomobject]@{Start=$start;End=$commit;Rel=$cancelled[0];Cancelled=$true}
            $start=$commit
        }
    }
    if($segments.Count-gt1){
        $headSha=(git -C $Root rev-parse $HeadRef).Trim()
        if($segments[-1].End-ne$headSha){throw 'SEGMENT_TRAILING_WORK'}
    }
    $segments
}
function Validate-PublicationSegments {
    $saveBase=$BaseRef;$saveHead=$HeadRef
    $terminal=@{}
    try{
        for($i=0;$i-lt$script:PublicationSegments.Count;$i++){
            $seg=$script:PublicationSegments[$i]
            $script:BaseRef=$seg.Start;$script:HeadRef=$seg.End
            # A later CR may exist as Draft; it may not acquire active authority
            # before the preceding governor completes.
            foreach($later in @($script:PublicationSegments|Select-Object -Skip ($i+1))){
                # Re-closing this same CR is judged by the shared terminal guard,
                # which names the historical mutation rather than an overlap.
                if($later.Rel-eq$seg.Rel){continue}
                $seen=@(Status-Path $later.Rel $seg.Start $null)
                if(@($seen|?{$_-ne'Draft'}).Count){throw "OVERLAPPING_GOVERNORS:$($later.Rel)"}
            }
            if($seg.Cancelled){
                $carried=$false
                foreach($later in @($script:PublicationSegments|Select-Object -Skip ($i+1)|Where-Object{-not$_.Cancelled})){
                    if("$(Section (Read-GitFile $later.End $later.Rel) 'Supersedes / Depends On' -Optional)".Contains($seg.Rel)){$carried=$true;break}
                }
                if(-not$carried){throw "CANCELLED_SEGMENT_NOT_CARRIED:$($seg.Rel)"}
            }else{
                $seq=@(Status-Path $seg.Rel $seg.Start 'Complete')
                if($seq.Count-lt2-or$seq[-2]-ne'In Progress'){throw "INVALID_COMPLETION_TRANSITION:$($seg.Rel)"}
            }
            # This one existing walk owns the per-commit scope, frozen authority,
            # allocation, Approval replay and status checks. Shared terminal state
            # carries immutability across segment boundaries.
            Validate-CommittedRange $seg.Rel $terminal
        }
    }finally{$script:BaseRef=$saveBase;$script:HeadRef=$saveHead}
}

function Resolve-Contract($m,[object[]]$Records){
    if($m.Active){return $m.Active}
    if($script:PublicationSegments.Count-gt1){return $script:PublicationSegments[-1].Rel}
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
        'scripts/github_public_read.ps1','scripts/test_github_public_read.ps1',
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
            'pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1');Deferred=@(
            'EXTERNAL: the three Primary values are read LIVE through supabase-primary at the DATABASE execution boundary and RECORDED in reports/evidence/primary-ledger-evidence.json; this run validated that record and did NOT contact Primary')}}
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
        try{Test-OrvionPublicGithub $Root}catch{throw ('MISSING_REQUIRED_CAPABILITY:github:'+$_.Exception.Message)}
        }}
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
    git -C $Root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null|Out-Null;if($LASTEXITCODE-ne0){throw 'GIT_UPSTREAM_MISSING:this branch tracks no upstream and Boot will not guess one; reading needs none (AGENTS.md section 4 route)'}
    $x=(git -C $Root rev-list --left-right --count 'HEAD...@{u}')-split'\s+';$dirty=@(git -C $Root status --porcelain).Count-gt0
    [pscustomobject]@{Text="$(if($dirty){'dirty'}else{'clean'}) | ahead $($x[0]) / behind $($x[1])";Synced=([int]$x[1]-eq0)}
}

# Success is one line. Failure keeps everything a diagnosis needs: the command,
# the exit code, a diagnostic tail and the full log path. Streaming the entire
# successful child output buried the result it was meant to report.
function Invoke-Verification([string]$Command,[string]$Label,[switch]$Additional){
    $log=Join-Path([IO.Path]::GetTempPath())("orvion-verify-$([guid]::NewGuid().ToString('N')).log")
    # `pwsh -Command` collapses a child's exit code to 1, which would report the
    # wrong failure code for every verification command. Propagate it explicitly.
    $clock=[Diagnostics.Stopwatch]::StartNew()
    & pwsh -NoProfile -Command "$Command`nexit `$LASTEXITCODE" *>$log
    $code=$LASTEXITCODE;$clock.Stop()
    if(-not$script:ProfileTime.Contains($Label)){$script:ProfileTime[$Label]=[TimeSpan]::Zero};$script:ProfileTime[$Label]+=$clock.Elapsed
    $took="TIME: $Label $Command $(Format-Elapsed $clock.Elapsed)"
    if($code-eq0){Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue;Write-Output "PASS: $Command";Write-Output $took;return}
    Write-Output "FAILED: $Command (exit $code)";Write-Output $took
    if(Test-Path -LiteralPath $log){
        Write-Output '--- last 20 lines ---'
        foreach($line in @(Get-Content -LiteralPath $log -Tail 20)){Write-Output $line}
        Write-Output "--- full log: $log"
    }
    if($Additional){throw "ADDITIONAL_VERIFICATION_FAILED:$Command"}
    throw "MANDATORY_VERIFICATION_FAILED:$Command"
}

function Finish-Checks($c,[string[]]$profiles,[string]$rel){
    Protect-PendingCertifications $c $rel
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
    $script:ProfileTime=[ordered]@{}
    foreach($command in $mandatory){Invoke-Verification $command $(if($seen.ContainsKey($command)){$seen[$command]}else{'CAPABILITY'})}
    foreach($command in $extra){Invoke-Verification $command 'ADDITIONAL' -Additional}
    foreach($p in $script:ProfileTime.Keys){Write-Output "TIME: PROFILE $p $(Format-Elapsed $script:ProfileTime[$p])"}

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

# A path-filtered workflow that produced no run on this SHA (SPEC-263). GitHub runs it on
# a push only when that push changes a path it watches, so a bookkeeping commit pushed on
# its own never runs it - while the receipt, derived from the whole contract's Write Scope,
# still expects it. Measured on `f61ed84`: Migration CI ran and passed on `a87fa92`, the
# Complete commit changed three non-database files, and certification failed on a run GitHub
# was never going to start.
#
# The verdict is carried forward from ONE run only: the workflow's nearest push run on the
# target branch at an ancestor of this SHA. It counts only if git proves that no path the
# workflow watches, and not its own definition, differs between that SHA and this one - so
# the same workflow run here would read byte-identical inputs. That run is then judged like
# any other: still running is PENDING, any conclusion but success is FAILED. An older
# success never outranks a nearer failure. Everything else leaves the workflow MISSING and
# fails closed: a workflow with no `paths:` filter, a filter this reader cannot read
# exactly, not exactly one definition, no qualifying run, an unreadable query, or a watched
# path that changed. Renames are split into delete and add, so a file moved out of a watched
# directory still counts as a watched change.
function Inherited-Run([string]$Workflow,[string]$Sha,[string]$Target){
    $no={param($why)[pscustomobject]@{Runs=@();From='';Why=$why}}
    $dir=Join-Path $Root '.github/workflows'
    $defs=@(if(Test-Path -LiteralPath $dir){Get-ChildItem -LiteralPath $dir -File|Where-Object{$_.Extension-in @('.yml','.yaml')}|Where-Object{
        ([regex]::Match([IO.File]::ReadAllText($_.FullName),'(?m)^name:\s*(?<v>.+?)\s*$')).Groups['v'].Value-ceq$Workflow}})
    if($defs.Count-ne1){return (& $no "$($defs.Count) workflow definitions are named $Workflow")}
    $def=".github/workflows/$($defs[0].Name)"
    $text=[IO.File]::ReadAllText($defs[0].FullName)
    $push=[regex]::Match($text,'(?ms)^  push:[ \t]*\r?\n(?<b>(?:[ \t]{4,}.*\r?\n|[ \t]*\r?\n)*)')
    $body=if($push.Success){$push.Groups['b'].Value}else{''}
    $globs=@(Trigger-List $body 'paths')
    if(!$globs.Count){return (& $no "$Workflow watches every path, so it must run on this SHA")}
    # Read exactly or not at all: every bullet must have become one glob of the forms
    # `Glob-Regex` translates. A trailing comment or an unusual quote would otherwise drop
    # or garble a glob, and a watched set read short is the one error that certifies falsely.
    $block=[regex]::Match($body,'(?m)^[ \t]*paths:[ \t]*\r?\n')
    $bullets=0
    if($block.Success){foreach($line in @($body.Substring($block.Index+$block.Length)-split'\r?\n')){
        if($line-match'^\s*-'){$bullets++}elseif($line-match'^\s*#'-or!$line.Trim()){continue}else{break}}}
    if(($block.Success-and$bullets-ne$globs.Count)-or@($globs|Where-Object{$_-cnotmatch'^[A-Za-z0-9_./*-]+$'}).Count){
        return (& $no "the path filter of $Workflow cannot be read exactly")
    }
    try{$raw=ConvertTo-Json -InputObject @(Get-OrvionPublicRuns (Get-OrvionPublicRepo $Root) -Branch $Target -Event push -WorkflowPath $def) -Depth 10 -Compress;$LASTEXITCODE=0}catch{$raw=$null;$LASTEXITCODE=1}
    if($LASTEXITCODE-ne0-or!$raw){return (& $no "anonymous API could not read the runs of $Workflow on $Target")}
    try{$parsed=$raw|ConvertFrom-Json}catch{return (& $no "anonymous API returned runs of $Workflow this command cannot parse")}
    # Nearness is position in this SHA's own ancestry, never the order gh returns.
    $order=@{};$i=0
    foreach($c in @(git -C $Root rev-list --topo-order $Sha)){$order[("$c").Trim()]=$i++}
    if($LASTEXITCODE-ne0){return (& $no "the ancestry of $Sha cannot be read")}
    $best=@();$near=[int]::MaxValue
    foreach($run in @($parsed)){
        $s=("$($run.headSha)").Trim()
        if(("$($run.workflowName)").Trim()-cne$Workflow-or("$($run.headBranch)").Trim()-ne$Target-or("$($run.event)").Trim()-ne'push'){continue}
        if(!$order.ContainsKey($s)){continue}
        if($order[$s]-lt$near){$near=$order[$s];$best=@($run)}elseif($order[$s]-eq$near){$best+=$run}
    }
    if(!$best.Count){return (& $no "no run of $Workflow on $Target at an ancestor of this SHA")}
    $from=("$($best[0].headSha)").Trim()
    $changed=@((git -C $Root diff --no-renames --name-only -z $from $Sha --)-join''-split"`0"|Where-Object{$_})
    if($LASTEXITCODE-ne0){return (& $no "the paths changed since $from cannot be read")}
    $watched=@($changed|Where-Object{$p=$_;$p-eq$def-or@($globs|Where-Object{$p-match(Glob-Regex $_)}).Count})
    if($watched.Count){return (& $no "$($watched[0]) changed after its nearest run at $from")}
    [pscustomobject]@{Runs=$best;From=$from;Why=''}
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
    try{$receipt=Select-Certification $sha}catch{
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: certification receipt refused: $($_.Exception.Message)"
        exit 1
    }
    $expected=@($receipt.expected|Where-Object{$_})
    if(!$expected.Count){
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: the local certification receipt records no expected workflow set'
        exit 1
    }
    # The branch is READ, never re-derived. A receipt written before this field existed
    # cannot be interpreted by guessing a default, because guessing the branch is the
    # whole defect: it is exactly how a preflight qualification run came to be judged as
    # though it were evidence about the promotion.
    $target=("$($receipt.target)").Trim()
    if(!$target){
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
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
    try{$raw=ConvertTo-Json -InputObject @(Get-OrvionPublicRuns (Get-OrvionPublicRepo $Root) -Sha $sha -Branch $target -Event push) -Depth 10 -Compress;$LASTEXITCODE=0}catch{$raw=$null;$LASTEXITCODE=1}
    if($LASTEXITCODE-ne0-or!$raw){
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: anonymous API could not read workflow runs for this SHA'
        exit 1
    }
    # ASSIGN, then wrap. `ConvertFrom-Json` emits a JSON array as ONE pipeline item, so
    # `@($raw|ConvertFrom-Json)` yields a single element that IS the array - one iteration
    # holding every run at once. Assigning first unrolls it, and `@()` then normalises the
    # one-object and empty-array cases. The previous code carried the same shape harmlessly
    # because it only ever read members across the collection, which PowerShell flattens;
    # it becomes a real defect the moment individual rows are inspected.
    try{$parsed=$raw|ConvertFrom-Json}catch{
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output 'EVIDENCE: anonymous API returned evidence this command cannot parse'
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
        $script:Outcome='REMOTE_CERTIFY: PENDING';Write-Output 'REMOTE_CERTIFY: PENDING'
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
        $script:Outcome='REMOTE_CERTIFY: PENDING';Write-Output 'REMOTE_CERTIFY: PENDING'
        Write-Output "EVIDENCE: REQUIRED_WORKFLOW_MISSING so far: $($missing-join', ') — $($running.Count) run(s) on this SHA have not completed"
        exit 1
    }
    # Every run on this SHA has settled. A missing workflow may now carry its nearest run
    # forward under the proof `Inherited-Run` states (SPEC-263), and that run joins the
    # judgement below exactly as a run on this SHA would. Anything it refuses stays missing.
    $kept=@()
    foreach($w in $missing){
        $proof=Inherited-Run $w $sha $target
        if(!$proof.Runs.Count){Write-Output "NOT INHERITED: $w — $($proof.Why)";$kept+=$w;continue}
        foreach($r in $proof.Runs){Write-Output "INHERITED: $w from $($proof.From) run $($r.databaseId) attempt $($r.attempt) $($r.status)/$($r.conclusion) — no path it watches changed since"}
        $runs+=$proof.Runs
    }
    $missing=$kept
    $running=@($runs|Where-Object{$_.status-ne'completed'})
    if($missing.Count){
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: REQUIRED_WORKFLOW_MISSING: $($missing-join', ') produced no run on this SHA. Success on any other SHA proves nothing about this one."
        exit 1
    }
    if($running.Count){
        $script:Outcome='REMOTE_CERTIFY: PENDING';Write-Output 'REMOTE_CERTIFY: PENDING'
        Write-Output "EVIDENCE: $($running.Count) run(s) still in progress on this SHA"
        exit 1
    }
    $bad=@($runs|Where-Object{$_.conclusion-ne'success'})
    if($bad.Count){
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: $((@($bad|ForEach-Object{$_.workflowName})|Sort-Object -Unique)-join', ')"
        exit 1
    }
    # Green evidence about a SHA the target ref has already moved past certifies nothing
    # anyone can act on: the claim being made is "the branch stands at a proven revision",
    # and that is a statement about NOW, not about the moment the runs finished. Read the
    # remote, never a local cache, and refuse rather than assume when it cannot be read.
    git -C $Root fetch origin $target --quiet 2>$null|Out-Null
    if($LASTEXITCODE-ne0){
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: TARGET_REF_UNREADABLE:$target — the remote target ref could not be read, so it cannot be proven to stand at this SHA"
        exit 1
    }
    $remote=(git -C $Root rev-parse "refs/remotes/origin/$target" 2>$null)
    $remote=if($LASTEXITCODE-eq0){("$remote").Trim()}else{''}
    if($remote-ne$sha){
        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
        Write-Output "EVIDENCE: TARGET_REF_MOVED:$target is at $remote, not the certified $sha"
        exit 1
    }
    $script:Outcome='REMOTE_CERTIFY: READY';Write-Output 'REMOTE_CERTIFY: READY'
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

try{try{
    Set-Location $Root
    # SPEC-283. -Finish is the longest run an agent starts, and it is started only through
    # `scripts/run_timed.ps1`, which names its log here, so `scripts/watch_run.ps1` can follow it
    # and say how long is left (CR_LIFECYCLE.md §9). Anti-omission, not anti-forgery, like the receipt.
    if($Finish-and(-not$env:ORVION_TIMED_LOG-or-not(Test-Path -LiteralPath $env:ORVION_TIMED_LOG))){
        throw 'FINISH_NOT_TIMED:start -Finish through scripts/run_timed.ps1 and follow it with scripts/watch_run.ps1 (CR_LIFECYCLE.md §9)'
    }
    if(!(Test-Path(Join-Path $Root 'AGENTS.md'))){throw 'AGENTS_MISSING'}
    if($Certify){Certify-Remote}
    if($BindCandidate){
        if($Trusted-or!$BaseRef){throw 'BIND_LOCAL_RANGE_REQUIRED:-BindCandidate requires a local, non-Trusted range Gate'}
        if($BaseRef-cnotmatch'^[0-9a-f]{40}$'-or$HeadRef-cnotmatch'^[0-9a-f]{40}$'){throw 'BIND_FULL_SHA_REQUIRED'}
        if($HeadRef-cne("$(git -C $Root rev-parse HEAD)").Trim()){throw 'RECEIPT_SHA_MISMATCH'}
        if(@(git -C $Root status --porcelain).Count){throw 'RECEIPT_DIRTY_TREE'}
    }
    if($BaseRef){Assert-Ref $BaseRef;Assert-Ref $HeadRef}
    # SPEC-281. A candidate's own CI runs the candidate's own evaluator, so a candidate that edits
    # it, or its workflow, certifies itself; GitHub also counts a skipped required check as passing.
    # -Trusted judges a candidate WITHOUT executing it: this evaluator must come from outside -Root
    # (a checkout of `main`, which the candidate cannot change), -Root must be a clean checkout of
    # exactly the SHA being admitted, read as data, and Repo-Guard - the one step that runs a file
    # from -Root - is left out; the candidate's own required check still runs it.
    if($Trusted){
        if(!$BaseRef){throw 'TRUSTED_RANGE_REQUIRED:-Trusted judges a candidate range, so -BaseRef and -HeadRef are required'}
        $self=[IO.Path]::GetFullPath($PSCommandPath);$data=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if($self.StartsWith($data,[StringComparison]::OrdinalIgnoreCase)){throw "TRUSTED_EVALUATOR_IN_CANDIDATE:$self is inside the candidate it would judge"}
        $at="$(git -C $Root rev-parse HEAD)".Trim();$want="$(git -C $Root rev-parse "$HeadRef^{commit}")".Trim()
        if($at-ne$want-or@(git -C $Root status --porcelain).Count){throw "TRUSTED_DATA_NOT_CANDIDATE:$Root is not a clean checkout of $want"}
    }

    Mark-Stage 'setup'
    $records=@(Diff-Records);$base=if($BaseRef){$BaseRef}else{'HEAD'}
    Validate-HistoryAndIds $records $base
    Mark-Stage 'history'
    # Allocation is judged locally on every run, and in range mode only when the
    # base itself was already under enforcement - current rules are never applied
    # retroactively to history that predates the marker. Reservation, unlike
    # allocation, is never gated by it.
    # SPEC-202. The local call judges origination from the WORKING TREE, where a newly
    # authored contract sits at exactly the state it is being created in.
    # SPEC-256. In range mode allocation has ONE authority: the per-commit walk, which judges
    # each allocation against its own parent and alone sees the state a contract had when it
    # appeared. A net-diff call here judged the whole range against the BASE's reservations, so
    # an identity reserved inside the unpublished range and lawfully skipped read
    # SPEC_ID_NOT_NEXT (SPEC-254, after SPEC-252's Notes reserved 253). That call was also the
    # only guard for a range that removes the marker, so activation is decided here, once, from
    # the ORIGINAL base, before Validate-PublicationSegments substitutes segment bounds.
    if(-not $BaseRef){Validate-SpecAllocation $records $base -CheckOrigination}
    $script:RangeAllocationActive=[bool]$BaseRef-and(Allocation-ActiveAt $BaseRef)
    $script:PublicationSegments=@()
    if($BaseRef){$script:PublicationSegments=@(Get-PublicationSegments)}
    Mark-Stage 'allocation'
    $m=Manifest
    $rel=Resolve-Contract $m $records;Mark-Stage 'contract'
    $repo=if($Trusted){'not run (-Trusted executes no candidate file)'}else{Repo-Guard};Mark-Stage 'repo-guard'
    $git=Git-State;Mark-Stage 'git'
    if(!$git.Synced){throw "GIT_NOT_SYNCHRONIZED:$($git.Text)"}
    # SPEC-281. A state invariant like the consistency guard's, so it binds in every mode.
    Validate-PinnedAuthority $(if($BaseRef){$HeadRef}else{''})
    Mark-Stage 'pins'

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
        $script:Outcome='ORVION: READY'
        exit 0
    }

    $c=Contract(Join-Path $Root $rel);$completionTransition=(-not$m.Active);$profiles=Profiles $c.Scope

    # The authority that governs this run must be exactly the authority that was
    # approved. A Change Request absent from the baseline is newly created and
    # has no approved version to contradict.
    $baselineText=Read-GitFile $base ($rel-replace'\\','/')
    # CTRL-4: in every status, including a newly created contract, whose baseline is empty; forward-only in a range.
    if(Character-Guard-IsActive $base){Validate-NoNewProhibitedCharacter $baselineText $c.Text}
    if($null-ne$baselineText){
        $baselineStatus=Status-FromText $baselineText
        # Authority freezes at APPROVAL (CR_LIFECYCLE.md 8), so a baseline that is still a
        # DRAFT supplies no approved authority for any of these four to compare against -
        # a Draft exists precisely to be revised, which is the rule Validate-CommittedRange
        # already implements through $frozenBound. $baselineStatus was computed here and
        # never consulted, so a Draft published inside a predecessor's range and then
        # legally hardened before its own Approval became permanently unpublishable
        # (CTRL-2A, SPEC-200). Validate-StatusPath and the completion prerequisites stay
        # OUTSIDE this gate: a transition is always judged, and a Draft base must never
        # exempt a completion.
        if($baselineStatus-ne'Draft'){Validate-FrozenAuthority $baselineText $c.Text}
        # SPEC-281: the same two functions the range walk applies to every commit.
        Validate-RecordedText $baselineText $c
        Validate-StatusPath @(Status-Path ($rel-replace'\\','/') $base $c.Status)
        # Approval is judged on the Draft -> Approved transition ALONE. That is what freezes
        # authority, and it is also why terminal history is never retrofitted: a
        # contract that is already past this boundary is never re-examined.
        $script:ApprovalEvidence=Validate-TransitionEvidence $baselineText $c '' $base
        if($baselineStatus-eq'Draft'-and$c.Status-eq'Approved'){$script:Criteria=Get-CriteriaReport $c 'carry a check verified at Complete'}
        if($baselineStatus-ne'Complete'-and$c.Status-eq'Complete'){$script:Criteria=Get-CriteriaReport $c 'verified'}
    }
    Mark-Stage 'transition'

    # The endpoint view above proves what the range LANDED ON. This proves what it
    # PASSED THROUGH, which a net diff cannot see. It runs before the pointer
    # invariant because a forbidden committed state is the deeper defect, and the
    # pointer is a final-state property that would otherwise report the symptom.
    if($BaseRef){if($script:PublicationSegments.Count-gt1){Validate-PublicationSegments}else{Validate-CommittedRange $rel};Mark-Stage 'range-walk'}
    # SPEC-281 (ACI). The hook's view of the authority-change closure the walk applies per commit.
    if(!$BaseRef){
        $pinPaths=@(@(Get-PinnedAuthority 'HEAD')+@(Get-PinnedAuthority '')|ForEach-Object{$_.Path})
        if(@($records|Where-Object{$_.Path-eq'GOVERNANCE.md'-or$pinPaths-contains$_.Path}).Count){
            $ccRows=EvidenceRows (SubSection (Section $c.Text 'Pre-Approval Evidence' -Optional) 'Consumer Closure')
            foreach($pin in @(Get-PinChanges 'HEAD' '')){Assert-AuthorityConsumersCovered $ccRows $pin 'HEAD' 'AUTHORITY_CONSUMER_UNCOVERED'}
        }
    }

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
    if($script:PublicationSegments.Count-le1){
        foreach($r in $records){
            foreach($p in @($r.Path,$r.Old)|?{$_}){
                if($p-ne($rel-replace'\\','/')-and$scope-notcontains$p){throw "OUT_OF_SCOPE_WRITE:$p"}
            }
        }
    }

    if($Finish-and$mode-ne'VERIFY'){throw "FINISH_NOT_READY:$mode"}

    Write-Output 'ORVION: READY';Write-Output "MODE: $mode";Write-Output "CR: $($c.Id)";Write-Output "STATUS: $($c.Status)"
    if($script:ApprovalEvidence){Write-Output "APPROVAL_EVIDENCE: $($script:ApprovalEvidence)"}
    if($script:Criteria){Write-Output "CRITERIA: $($script:Criteria)"}
    Write-Output "STEP: $(if($c.Resume-eq'DONE'){'DONE'}else{"$($c.Resume)/$($c.Steps.Count)"})"
    if($mode-eq'EXECUTE'){Write-Output 'ACTION:';Write-Output $c.Steps[[int]$c.Resume-1]}
    Write-Output "WRITE: $($c.Scope-join', ')"
    Write-Output "START_CONTEXT: $($c.Reading-join', ')"
    Write-Output "VERIFICATION: $((@($profiles)+@($c.AdditionalVerification))-join', ')"
    # Named as declared, never as proven: this process cannot see these connectors,
    # and a capability line that looked like a probe result would be a false green.
    foreach($name in $declaredCapabilities){Write-Output "CAPABILITY: $name EXTERNAL_EVIDENCE — $($script:Capabilities[$name].Note)"}
    Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo";Write-Output "BLOCKER: $($c.Blocker.ToLowerInvariant())"
    if($Finish){Mark-Stage 'checks';Finish-Checks $c $profiles ($rel-replace'\\','/');Mark-Stage 'verification'}
    if($BindCandidate){Bind-CandidateReceipt $c ($rel-replace'\\','/') $profiles $HeadRef;Mark-Stage 'binding'}
    # A successful run states its OWN status (SPEC-166). Falling off the end leaves
    # whatever the last native command set, and `Read-GitFile` deliberately runs a
    # `git show` that FAILS whenever a path is absent at a ref - it leaves 128 behind
    # and treats that as "absent", which is correct. The range path then ends on
    # cmdlets, so nothing resets it, and GitHub's pwsh shell appends
    # `exit $LASTEXITCODE` to every step. The Gate therefore printed ORVION: READY,
    # MODE: VERIFY and BLOCKER: none, and the CI step failed with no error to read -
    # on the first push of a new Change Request, which is when the governing contract
    # is absent at the range base. Success is an assertion, not a leftover.
    $script:Outcome='ORVION: READY'
    exit 0
}catch{
    if($Finish){Write-Output 'CERTIFY: FAILED'}
    $script:Outcome="ORVION: BLOCKED $(($_.Exception.Message-split':',2)[0])"
    Block $_.Exception.Message
    exit 1
}}finally{
    $label=if($Boot){'Boot'}elseif($Gate){if($Trusted){'Gate trusted'}elseif($BaseRef){'Gate range'}else{'Gate'}}elseif($Finish){'Finish'}else{'Certify'}
    Write-Output (Format-Stages $label)
    Write-Output "TIME: $label $(Format-Elapsed $script:RunClock.Elapsed)"
    Write-TimingRecord $label
}

