# Change Request — SPEC-293

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[x] Cancelled

## Objective

Deliver this repository's independent Contract B release interfaces and bounded, fail-closed Git/read/watcher observations.

## Business Reason

Prepared operations must remain independently governed and discoverable in this repository. Failed Git reads must never mean a free identity or a clean synchronized checkout. Optional adapters invoke existing native engines, preserve interactive confirmation and never confer implementation or release authority.

## Risks

Control changes can misclassify unreadable input; deadline changes can exceed their measured boundary; a wrapper can misreport native results. Owning causal tests and native verification remain mandatory. Credential configuration is not authenticated actor isolation. Mutable local records and confirmation do not authenticate an owner against equal OS privileges; CTRL-19 remains OPEN. No release or configuration change is included.

## Supersedes / Depends On

Depends on completed SPEC-292 at baseline 4f9f15d9c5e55771daed2fe36ac960fb1ba4eeba. Supersedes none. This is a new independent Draft, not inherited approval or delegation.

## Write Scope

- `_ORVION_CANONICAL/manifest.md`
- `AGENTS.md`
- `ai-map.json`
- `repository-index.md`
- `scripts/agent/apply-draft-steps.ps1`
- `scripts/agent/Invoke-DraftSteps.ps1`
- `scripts/agent/test-draft-steps.ps1`
- `scripts/agent/Test-ScriptHazards.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/github_public_read.ps1`
- `scripts/owner_promote.ps1`
- `scripts/owner_publish.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/test_github_public_read.ps1`
- `scripts/test_owner_interfaces.ps1`
- `scripts/watch_run.ps1`
- `scripts/watch_selftest.ps1`

## Out of Scope — Files Forbidden to Modify

- `README.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `.githooks/pre-commit`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/watch_ci.ps1`
- `reports/architecture-decision-records.md`

All other unlisted artifacts are outside Write Scope. No migrations, database operation, authentication, production change, original remote/configuration change, retirement, Batch 6 or Phase 8 work is authorized.

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/TEMPLATE.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- pwsh -NoProfile -File scripts/test_github_public_read.ps1
- pwsh -NoProfile -File scripts/watch_selftest.ps1
- pwsh -NoProfile -File scripts/test_owner_interfaces.ps1
- pwsh -NoProfile -File scripts/agent/test-draft-steps.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: preserve native authorities and scope-derived profiles; reuse this repository's existing release engines and owning suites; make only reproduced read/wait/watcher repairs and introduce minimum optional local helpers.

Pass 2 Adversarial Review: rejected a native profile expansion and all README changes; corrected discovery into AGENTS/Boot and literal/runtime step grammar; retained four additive suites. Full CONTROL exposed the legacy ABM5 lower-guard mutation being masked by the new earlier Git-read refusal. Isolate its exact criterion function on a real missing-tree fixture, with a known present population and restored healthy result; retain whole-Gate/store/read cases and both admission guards unchanged. Fix the observed Draft heading/PICF sequencing before freeze. Standalone fixtures remain distinct from lifecycle, credential and hosted proof. First publication uses the established trusted native route under separate release authorization because new tracked interfaces are absent from old trusted main.

Pass 3 Evidence Refresh: 2026-10-22. Live original baseline and clean state, fresh native Boot, exact payloads, source anchors and native CONTROL plus REPOSITORY derivation refreshed. The companion sealing check must bind actual command exits, literal replay and final review before Gate 1 is offered; an unfinished prerequisite blocks sealing and is never treated as a pass.

Selected Version: bounded Contract B version 1, with unchanged README and native profiles, repository-local optional tools and existing engine delegation; exact companion payload and replay evidence govern selection, not a programme-wide approval.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Required Git reads | Base-HasId, Git-State and owning tests | WRITE | Failed count/status/tree/grep or malformed output refuses; valid no-match is distinct from unreadable stderr |
| Shared slot pause | Existing public reader and owning local fixtures | WRITE | One invocation has a total deadline; no claim of a whole multi-poll watch deadline |
| Origin classification | Existing certification caller | VERIFY | Missing/malformed/multiple origins already produce UNREADABLE; owning tests added, no caller engine repair |
| Watcher observations | Existing watcher and self-test | WRITE | Brief late attach, explicit UNREADABLE and count-compatible ETA; no unknown total fabricated |
| Optional local interfaces/helpers | AGENTS, Boot, owner callers and owning tests | WRITE | Native gates remain authority; no companion repository/runtime dependency |
| Native verification and release | Profile mapping, hooks, CI, publish/promote engines | UNAFFECTED | No profile, hook, CI or native release-engine change; frozen Additional Verification adds required coverage |
| Runtime manifest and generated discovery | Native lifecycle and generate-ai-map | WRITE | Native active pointer, terminal Last Completed and generated artifacts synchronized only at their legal transitions |
| Protected authority | GOVERNANCE and ratified pins | VERIFY | No pin changed; source anchors and preserved-artifact criteria constrain execution |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact approved Draft, source baseline and anchors | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| All literal payloads and native generated freshness | BEFORE_COMPLETION | 1 | 15 | NONE |
| Fresh native Finish receipt, Review and legal transitions | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: native required-read helpers, shared public reader, watcher, owning tests and scope-derived mandatory profiles; optional callers dispatch native release engines.

Added Property: unreadable Git cannot become a favorable verdict, slot waits are bounded per invocation, observation remains honest, and independent optional entrypoints preserve native judgments.

Causal Negative: preserved B1 failed/malformed Git reads and actual missing blob were accepted as free/clean; B2 baseline had four failures; watcher baseline mishandled test-count history. Missing and contradictory native child outcomes are refused by final owner-interface fixtures.

Positive Test Design: real valid Git states, available slots, compatible ETA, cold independent helpers and exact successful native-child/ref fixture outcomes remain usable.

Negative Test Design: failed reads, missing blobs, expired wait budget, malformed origin, unknown ETA, noninteractive confirmation, wrong root/account/SHA/receipt, child failure, ambiguous verdict and wrong ref must refuse or remain explicitly unreadable/unavailable.

Non-Empty Population Obligation: execute the owning causal/positive/mutant cases and native mandatory commands; no fixture may pass with an empty case population or real release side effect.

Mutation Obligation: retain existing causal read/reader/watcher mutants and owner caller negative controls; each new load-bearing refusal must have a failing counterexample before it is trusted. Native admission/profile mutants remain under their existing owning suite.

Post-Implementation Proof Obligation: one authorized native timed/watched Finish executes all derived mandatory and additive commands on final implemented bytes; independent Review, Complete, bind, separate authorized publication, hosted checks and exact-SHA certification follow. Preparation never writes a native success receipt.

## Implementation Steps

1. Check whether `AGENTS.md` contains `Repository-local optional adapters (no additional write authority):`; if so record Already Applied when its Git blob is 708b72b2eada57e532cc5cc3be3115c1a5731b89, and otherwise stop and report. Otherwise make exactly this one edit (Contract B bounded repository-local repair or optional adapter), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   Boot validates and extracts manifest, active CR, official status, Runtime Checkpoint, Git/upstream, repository guard, capabilities, verification profile, and blocker. Follow its exact `ACTION`, `WRITE`, and `START_CONTEXT`. Boot routes context; it does not preload whole Governance, Canon, reports, or guard output. Read more whenever evidence requires it.

   ```
   insert
   ```text
   Repository-local optional adapters (no additional write authority):
   - Draft generation/application: `scripts/agent/Invoke-DraftSteps.ps1` (`Get-DraftFileStep`) and `scripts/agent/apply-draft-steps.ps1 -Draft <absolute-draft> -Root <absolute-root>`.
   - Scratch hazards: `scripts/agent/Test-ScriptHazards.ps1 <scratch.ps1>`; owning checks: `scripts/agent/test-draft-steps.ps1` and `scripts/test_owner_interfaces.ps1`.
   - Owner Publish: from this product's clean synchronized trusted main, `scripts/owner_publish.ps1 -Root <absolute-candidate-root> -Candidate <full-SHA>`; Owner Promote: `scripts/owner_promote.ps1 -Candidate <full-SHA>`.
   - Both owner interfaces require a real interactive confirmation; `-NonInteractive` refuses. Existing native engines retain Gate/CI/receipt judgment. Metadata goes outside the checkout; `-EvidenceDirectory <absolute-directory>` chooses the destination. Account routing is configuration evidence, not authenticated actor proof. Publication/promotion never means remote certification. Existing owner entrypoints bootstrap the first release; tracked interfaces become usable from trusted main only after release.

   ```

   The resulting file's Git blob is 708b72b2eada57e532cc5cc3be3115c1a5731b89.

2. Check whether `scripts/agent/apply-draft-steps.ps1` contains `# Replays literal Draft file steps; this is not an approval or scope-admission authority.`; if so record Already Applied when its Git blob is 523463176334e939c972d0393ad2d0696e40701a, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (Contract B bounded repository-local repair or optional adapter), and change nothing else:

   ```text
   # Replays literal Draft file steps; this is not an approval or scope-admission authority.
   # Preflight every target, operation and filtered blob before the first implementation write.
   param([Parameter(Mandatory)][string]$Draft,[Parameter(Mandatory)][string]$Root)
   $ErrorActionPreference='Stop'
   . (Join-Path $PSScriptRoot 'Invoke-DraftSteps.ps1')
   $t=[IO.File]::ReadAllText($Draft)-replace"`r`n","`n"
   $section=[regex]::Match($t,'(?s)## Implementation Steps\n\n(.*?)\n## Acceptance Criteria')
   if(!$section.Success){throw 'IMPLEMENTATION_SECTION_MISSING'}
   $items=@([regex]::Split($section.Groups[1].Value,'(?m)^(?=\d+\. )')|Where-Object{$_-match'^\d+\. Check whether '})
   if(!$items.Count){throw 'NO_FILE_STEPS'}
   $plans=@();$paths=@{}
   foreach($it in $items){
       $pathMatch=[regex]::Match($it,'^\d+\. Check whether `([^`]+)` contains `([^`]+)`')
       $blobMatch=[regex]::Match($it,"The resulting file's Git blob is ([0-9a-f]{40})\.")
       if(!$pathMatch.Success-or!$blobMatch.Success){throw 'FILE_STEP_INVALID'}
       $file=$pathMatch.Groups[1].Value;$want=$blobMatch.Groups[1].Value
       $p=Get-DraftTargetPath $Root $file
       if($paths.ContainsKey($p)){throw "DUPLICATE_TARGET:$file"};$paths[$p]=$true
       $exists=[IO.File]::Exists($p)
       if(Test-Path -LiteralPath $p -PathType Container){throw "TARGET_IS_DIRECTORY:$file"}
       $raw=if($exists){[IO.File]::ReadAllText($p)}else{$null}
       if($exists-and(Get-DraftContentBlob $Root $file $raw)-eq$want){
           $plans+= [pscustomobject]@{File=$file;Path=$p;Skip=$true}
           continue
       }
       $fences=@([regex]::Matches($it,'(?ms)^   ```text\n(.*?)^   ```(?=\n|$)')|ForEach-Object{
           $body=$_.Groups[1].Value
           (@($body.Substring(0,$body.Length-1)-split"`n")|ForEach-Object{if($_.StartsWith('   ')){$_.Substring(3)}else{$_}})-join"`n"
       })
       $creating=$it.Contains('Otherwise create this file with exactly the following UTF-8 content and one final newline ')
       if($creating){
           if($exists){throw "CREATE_DESTINATION_EXISTS:$file"}
           if($fences.Count-ne1){throw "CREATE_FENCE_COUNT:$file"}
           $text=$fences[0]+"`n";$nl="`n"
       }else{
           if(!$exists){throw "EDIT_TARGET_MISSING:$file"}
           $nl=if($raw.Contains("`r`n")){"`r`n"}else{"`n"};$text=$raw-replace"`r`n","`n"
           $ops=@([regex]::Matches($it,'(?m)^   [a-z]\) (immediately after the lines?|replace the lines?)')|ForEach-Object{$_.Groups[1].Value})
           if(!$ops.Count-or$fences.Count-ne2*$ops.Count){throw "EDIT_FENCE_COUNT:$file"}
           for($i=0;$i-lt$ops.Count;$i++){
               $a=$fences[2*$i];$b=$fences[2*$i+1]
               $count=([regex]::Matches($text,[regex]::Escape($a))).Count
               if($count-ne1){throw "ANCHOR_COUNT:${file}:${i}:$count"}
               $at=$text.IndexOf($a,[StringComparison]::Ordinal)
               $text=if($ops[$i].StartsWith('replace')){$text.Remove($at,$a.Length).Insert($at,$b)}else{$text.Insert($at+$a.Length,"`n"+$b)}
           }
           $text=$text-replace"`n",$nl
       }
       $got=Get-DraftContentBlob $Root $file $text
       if($got-ne$want){throw "DRAFT_BLOB_MISMATCH:${file}:expected=$want actual=$got"}
       $plans+=[pscustomobject]@{File=$file;Path=$p;Skip=$false;Create=$creating;Before=$raw;Text=$text;Blob=$got}
   }
   foreach($plan in $plans){
       if($plan.Skip){"ALREADY_APPLIED: $($plan.File)";continue}
       $checked=Get-DraftTargetPath $Root $plan.File
       if($checked-cne$plan.Path){throw 'TARGET_CHANGED'}
       $bytes=[Text.Encoding]::UTF8.GetBytes($plan.Text)
       if($plan.Create){
           [void][IO.Directory]::CreateDirectory((Split-Path $plan.Path -Parent))
           $stream=[IO.File]::Open($plan.Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
       }else{
           $stream=[IO.File]::Open($plan.Path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
       }
       try{
           if(!$plan.Create){
               $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true,1024,$true)
               try{$present=$reader.ReadToEnd()}finally{$reader.Dispose()}
               if($present-cne$plan.Before){throw "TARGET_CHANGED:$($plan.File)"}
               $stream.Position=0;$stream.SetLength(0)
           }
           $stream.Write($bytes,0,$bytes.Length);$stream.Flush()
       }finally{$stream.Dispose()}
       "APPLIED: $($plan.File) blob=$($plan.Blob)"
   }
   "files: $($items.Count), mismatches: 0"
   exit 0
   ```

   The resulting file's Git blob is 523463176334e939c972d0393ad2d0696e40701a.

3. Check whether `scripts/agent/Invoke-DraftSteps.ps1` contains `# Standalone literal Draft authoring/replay helpers for this repository.`; if so record Already Applied when its Git blob is 61621cca3e081e3a786e19c168e44d05bae3253f, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (Contract B bounded repository-local repair or optional adapter), and change nothing else:

   ```text
   # Standalone literal Draft authoring/replay helpers for this repository.
   function Get-IndentedBlock([string[]]$L){($L|ForEach-Object{if($_-eq''){''}else{"   $_"}})-join"`n"}
   function Get-Fence([string[]]$L){"   ``````text`n"+(Get-IndentedBlock $L)+"`n   ``````"}
   function Get-DraftTargetPath([string]$Sb,[string]$File){
       $base=[IO.Path]::GetFullPath($Sb).TrimEnd([IO.Path]::DirectorySeparatorChar)
       $segments=@($File-replace'\\','/'-split'/')
       if(!$File-or[IO.Path]::IsPathRooted($File)-or$File-match'[\x00-\x1f<>:"|?*`]'-or@($segments|Where-Object{$_-in@('','.','..','.git')}).Count){throw "DRAFT_PATH_INVALID:$File"}
       if(@($segments|Where-Object{$_-match'[ .]$|^(?:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3])(?:\.|$)'}).Count){throw "DRAFT_PATH_INVALID:$File"}
       $current=$base
       foreach($segment in @('')+$segments){
           if($segment){$current=Join-Path $current $segment}
           $item=Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
           if($item-and($item.Attributes-band[IO.FileAttributes]::ReparsePoint)){throw "DRAFT_REPARSE_PATH:$File"}
       }
       $current
   }
   function Get-DraftContentBlob([string]$Sb,[string]$File,[string]$Text){
       $temporary=[IO.Path]::GetTempFileName()
       try{
           [IO.File]::WriteAllText($temporary,$Text,[Text.UTF8Encoding]::new($false))
           $blob=@(git -C $Sb hash-object "--path=$File" -- $temporary)
           if($LASTEXITCODE-or$blob.Count-ne1-or$blob[0]-cnotmatch'^[0-9a-f]{40}$'){throw "DRAFT_HASH_FAILED:$File"}
           $blob[0]
       }finally{[IO.File]::Delete($temporary)}
   }
   function Get-FileEdits([string]$Sb,[string]$f){
       $original=@(git -C $Sb show "HEAD:$f");if($LASTEXITCODE){throw "BASELINE_READ_FAILED:$f"}
       $cur=[Collections.Generic.List[string]]::new([string[]]@($original-split"`r?`n"));$parts=@();$delta=0
       # Counted as apply-draft-steps.ps1 matches: a substring of the whole text, not whole lines (a block unique as lines
       # matched 5 times as a substring, contract-A rehearsal 2026-10-20).
       function Count-Block([string[]]$B){([regex]::Matches(($cur-join"`n"),[regex]::Escape($B-join"`n"))).Count}
       $diff=@(git -C $Sb -c core.autocrlf=true diff -U0 --no-color -- $f);if($LASTEXITCODE){throw "DIFF_FAILED $f"}
       $i=0
       while($i-lt$diff.Count){
           $m=[regex]::Match($diff[$i],'^@@ -(\d+)(?:,(\d+))? \+\d+(?:,\d+)? @@');$i++
           if(-not$m.Success){continue}
           $a=[int]$m.Groups[1].Value;$k=if($m.Groups[2].Success){[int]$m.Groups[2].Value}else{1}
           $old=@();$new=@()
           while($i-lt$diff.Count-and$diff[$i]-notmatch'^@@ '){if($diff[$i].StartsWith('-')){$old+=$diff[$i].Substring(1)}elseif($diff[$i].StartsWith('+')){$new+=$diff[$i].Substring(1)};$i++}
           if($k-eq0){
               $end=$a+$delta
               $n=1;do{$anc=@($cur.GetRange($end-$n,$n));$hits=Count-Block $anc;$n++}while($hits-ne1-and$n-lt8)
               if($hits-ne1){throw "ANCHOR_NOT_UNIQUE $f @$a"}
               $cur.InsertRange($end,[string[]]$new);$delta+=$new.Count
               $parts+="immediately after the line$(if($anc.Count-gt1){'s'})`n$(Get-Fence $anc)`n   insert`n$(Get-Fence $new)"
           }else{
               $at=$a-1+$delta
               if((@($cur.GetRange($at,$k))-join"`n")-cne($old-join"`n")){throw "SIMULATION_DRIFT $f @$a"}
               # A replaced block that also occurs elsewhere grows by its preceding unchanged lines until unique; a pure
               # deletion grows at least once, since "replace with nothing" would leave an empty line behind.
               $ctx=0;while(((Count-Block $old)-ne1-or$new.Count-eq0)-and$ctx-lt8-and$at-$ctx-gt0){$ctx++;$lead=$cur[$at-$ctx];$old=@($lead)+$old;$new=@($lead)+$new}
               if((Count-Block $old)-ne1-or$new.Count-eq0){throw "BLOCK_NOT_UNIQUE $f @$a"}
               $cur.RemoveRange($at-$ctx,$k+$ctx);$cur.InsertRange($at-$ctx,[string[]]$new);$delta+=$new.Count-$k-$ctx
               $parts+="replace the line$(if($old.Count-gt1){'s'})`n$(Get-Fence $old)`n   with`n$(Get-Fence $new)"
           }
       }
       $parts
   }
   function Get-DraftFileStep([string]$Sb,[string]$File,[string]$Marker,[string]$What,[string]$ExpectedBlob){
       # the resume marker must be in the edited file, or a resumed run could never say Already Applied (wave-1 review, 2026-10-20)
       $path=Get-DraftTargetPath $Sb $File
       if(!$Marker-or$Marker-match'[`\r\n]'){throw "MARKER_INVALID:$File"}
       $raw=[IO.File]::ReadAllText($path)
       if(-not$raw.Contains($Marker)){throw "MARKER_ABSENT $File :: $Marker"}
       # the steps cannot say "no newline at end of file"; such a file would never reproduce its blob
       if($raw.Length-and-not$raw.EndsWith("`n")){throw "NO_FINAL_NEWLINE $File"}
       $listed=@(git -C $Sb ls-tree -z HEAD -- ":(literal)$File")
       if($LASTEXITCODE){throw "BASELINE_TREE_FAILED:$File"}
       $nb=if($ExpectedBlob){$ExpectedBlob}else{Get-DraftContentBlob $Sb $File $raw}
       if($nb-cnotmatch'^[0-9a-f]{40}$'){throw "BLOB_INVALID:$File"}
       if(!$listed.Count){
           $content=$raw-replace"`r`n","`n"
           if($content-match'(?m)^\s*```'){throw "CREATE_FENCE_UNSUPPORTED:$File"}
           $body="Check whether ``$File`` contains ``$Marker``; if so record Already Applied when its Git blob is $nb, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline ($What), and change nothing else:`n`n"
           return [pscustomobject]@{Text=$body+(Get-Fence @($content.Substring(0,$content.Length-1)-split"`n"))+"`n`n   The resulting file's Git blob is $nb.";Blob=$nb}
       }
       if($listed.Count-ne1-or$listed[0]-notmatch'^100(?:644|755) blob '){throw "BASELINE_NOT_REGULAR:$File"}
       $e=@(Get-FileEdits $Sb $File);if(!$e.Count){throw "NO_EDITS $File"}
       $body="Check whether ``$File`` contains ``$Marker``; if so record Already Applied when its Git blob is $nb, and otherwise stop and report. Otherwise make exactly $(if($e.Count-gt1){"these $($e.Count) edits"}else{'this one edit'}) ($What), each matched once, and change nothing else:`n`n"
       $n=0;foreach($p in $e){$n++;$body+="   $([char](96+$n))) $p`n`n"}
       [pscustomobject]@{Text=$body+"   The resulting file's Git blob is $nb.";Blob=$nb}
   }
   ```

   The resulting file's Git blob is 61621cca3e081e3a786e19c168e44d05bae3253f.

4. Check whether `scripts/agent/test-draft-steps.ps1` contains `# Self-check: steps generated by Invoke-DraftSteps.ps1 must reproduce the edited file through apply-draft-steps.ps1.`; if so record Already Applied when its Git blob is 8aefb21e60d7aef7b8429ada3ec89289f1bb01c5, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (Contract B bounded repository-local repair or optional adapter), and change nothing else:

   ```text
   # Self-check: steps generated by Invoke-DraftSteps.ps1 must reproduce the edited file through apply-draft-steps.ps1.
   # Cases measured 2026-10-20 (contract-A rehearsal): a pure deletion left a blank line; a block unique as whole lines
   # matched 5 times as the applier's substring; a file ending without a newline cannot be expressed, so it is refused.
   $ErrorActionPreference='Stop'
   . (Join-Path $PSScriptRoot 'Invoke-DraftSteps.ps1')
   $root=Join-Path ([IO.Path]::GetTempPath()) "orvion-draft-steps-$PID";$fail=0
   function Test-Case([string]$Name,[string]$Base,[string]$Edited,[bool]$Refused=$false){
       $r=Join-Path $root $Name;New-Item -ItemType Directory -Force $r|Out-Null
       git -C $r init -q;git -C $r config core.autocrlf false
       [IO.File]::WriteAllText("$r\f.txt",$Base);git -C $r add f.txt;git -C $r -c user.name=t -c user.email=t@t commit -qm base
       [IO.File]::WriteAllText("$r\f.txt",$Edited)
       try{$s=Get-DraftFileStep $r 'f.txt' 'MARK' 'test'}catch{if($Refused){"PASS $Name refused: $($_.Exception.Message)";return};$script:fail++;"FAIL $Name generator threw: $($_.Exception.Message)";return}
       if($Refused){$script:fail++;"FAIL $Name was not refused";return}
       $d="$r\draft.md";[IO.File]::WriteAllText($d,"## Implementation Steps`n`n1. $($s.Text)`n`n## Acceptance Criteria`n")
       git -C $r checkout -q -- f.txt
       $out=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'apply-draft-steps.ps1') -Draft $d -Root $r 2>&1
       if($LASTEXITCODE){$script:fail++;"FAIL $Name steps did not reproduce: $(($out|Select-Object -Last 2)-join' ')"}else{"PASS $Name"}
   }
   function Assert-DraftCase([string]$Name,[bool]$Ok,[string]$Detail=''){
       if($Ok){"PASS $Name"}else{$script:fail++;"FAIL $Name $Detail"}
   }
   function New-CreationFixture([string]$Name,[string]$Content="MARK`nnew file`n`n"){
       $r=Join-Path $root $Name
       if(Test-Path -LiteralPath $r){throw "FIXTURE_EXISTS:$r"}
       [void][IO.Directory]::CreateDirectory((Join-Path $r 'tools'))
       git -C $r init -q;git -C $r config core.autocrlf true
       [IO.File]::WriteAllText((Join-Path $r 'seed.txt'),"seed`n")
       git -C $r add seed.txt;git -C $r -c user.name=t -c user.email=t@t commit -qm base
       if($LASTEXITCODE){throw 'FIXTURE_COMMIT_FAILED'}
       $relative='tools/new file Ω.txt';$path=Join-Path $r $relative
       [IO.File]::WriteAllText($path,$Content,[Text.UTF8Encoding]::new($false))
       $want=git -C $r hash-object -- $relative
       if($LASTEXITCODE){throw 'FIXTURE_HASH_FAILED'}
       $step=Get-DraftFileStep $r $relative 'MARK' 'creation fixture'
       if($step.Blob-ne$want){throw 'GENERATOR_CHANGED_ORACLE_BLOB'}
       Remove-Item -LiteralPath $path
       $draft=Join-Path $r 'draft.md'
       [IO.File]::WriteAllText($draft,"## Implementation Steps`n`n1. $($step.Text)`n`n## Acceptance Criteria`n")
       [pscustomobject]@{Root=$r;Relative=$relative;Path=$path;Draft=$draft;Step=$step;Content=$Content;Want=$want}
   }
   function Invoke-FixtureDraft($Fixture){
       $out=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'apply-draft-steps.ps1') -Draft $Fixture.Draft -Root $Fixture.Root 2>&1|Out-String
       [pscustomobject]@{Code=$LASTEXITCODE;Text=$out}
   }
   function Test-CreationCases{
       $x=New-CreationFixture 'create-unicode-space'
       $r=Invoke-FixtureDraft $x
       $actual=if(Test-Path -LiteralPath $x.Path){git -C $x.Root hash-object -- $x.Relative}else{'absent'}
       Assert-DraftCase 'create Unicode/space path preserves filtered blob and trailing blank line' ($r.Code-eq0-and$actual-eq$x.Want-and[IO.File]::ReadAllText($x.Path)-ceq$x.Content) $r.Text
       $before=(Get-FileHash -LiteralPath $x.Path).Hash;$r=Invoke-FixtureDraft $x
       Assert-DraftCase 'matching create step resumes Already Applied without rewriting' ($r.Code-eq0-and$r.Text-match'ALREADY_APPLIED'-and(Get-FileHash -LiteralPath $x.Path).Hash-eq$before) $r.Text

       $x=New-CreationFixture 'create-conflict'
       [IO.File]::WriteAllText($x.Path,"unique existing work`n");$before=(Get-FileHash -LiteralPath $x.Path).Hash
       $r=Invoke-FixtureDraft $x
       Assert-DraftCase 'create refuses an unexplained existing destination' ($r.Code-ne0-and$r.Text-match'CREATE_DESTINATION_EXISTS'-and(Get-FileHash -LiteralPath $x.Path).Hash-eq$before) $r.Text

       $x=New-CreationFixture 'preflight-later-mismatch'
       $second=$x.Step.Text.Replace($x.Relative,'tools/second.txt').Replace($x.Want,('0'*40))
       [IO.File]::WriteAllText($x.Draft,"## Implementation Steps`n`n1. $($x.Step.Text)`n`n2. $second`n`n## Acceptance Criteria`n")
       $r=Invoke-FixtureDraft $x
       Assert-DraftCase 'later blob mismatch refuses before any earlier implementation write' ($r.Code-ne0-and$r.Text-match'DRAFT_BLOB_MISMATCH'-and!(Test-Path -LiteralPath $x.Path)-and!(Test-Path -LiteralPath (Join-Path $x.Root 'tools/second.txt'))) $r.Text

       $x=New-CreationFixture 'duplicate-target'
       [IO.File]::WriteAllText($x.Draft,"## Implementation Steps`n`n1. $($x.Step.Text)`n`n2. $($x.Step.Text)`n`n## Acceptance Criteria`n")
       $r=Invoke-FixtureDraft $x
       Assert-DraftCase 'duplicate targets refuse before writing' ($r.Code-ne0-and$r.Text-match'DUPLICATE_TARGET'-and!(Test-Path -LiteralPath $x.Path)) $r.Text

       foreach($bad in @(@('traversal','../outside.txt'),@('git-config','.git/config'),@('absolute','C:/outside-orvion-fixture.txt'),@('trailing-space','.. /outside.txt'),@('trailing-period','tools/name.'),@('device-name','tools/NUL.txt'))){
           $x=New-CreationFixture $bad[0]
           $config=Join-Path $x.Root '.git/config';$before=(Get-FileHash -LiteralPath $config).Hash
           [IO.File]::WriteAllText($x.Draft,([IO.File]::ReadAllText($x.Draft).Replace($x.Relative,$bad[1])))
           $r=Invoke-FixtureDraft $x
           Assert-DraftCase "invalid $($bad[0]) target refuses without changing Git configuration" ($r.Code-ne0-and$r.Text-match'DRAFT_PATH_INVALID'-and!(Test-Path -LiteralPath $x.Path)-and(Get-FileHash -LiteralPath $config).Hash-eq$before) $r.Text
       }
       $x=New-CreationFixture 'empty-steps'
       [IO.File]::WriteAllText($x.Draft,"## Implementation Steps`n`n`n## Acceptance Criteria`n")
       $r=Invoke-FixtureDraft $x
       Assert-DraftCase 'no file steps cannot report a successful replay' ($r.Code-ne0-and$r.Text-match'NO_FILE_STEPS') $r.Text

       $x=New-CreationFixture 'missing-baseline'
       [IO.File]::WriteAllText($x.Path,$x.Content)
       [IO.File]::WriteAllText((Join-Path $x.Root '.git/HEAD'),"ref: refs/heads/absent`n")
       $problem='';try{$null=Get-DraftFileStep $x.Root $x.Relative 'MARK' 'unreadable baseline'}catch{$problem=$_.Exception.Message}
       Assert-DraftCase 'unreadable baseline is never interpreted as a new file' ($problem-match'BASELINE_TREE_FAILED') $problem

       $x=New-CreationFixture 'reparse-target'
       $outside=Join-Path $root 'junction-owned-target';[void][IO.Directory]::CreateDirectory($outside)
       $link=Join-Path $x.Root 'link';$null=New-Item -ItemType Junction -Path $link -Target $outside
       try{
           [IO.File]::WriteAllText($x.Draft,([IO.File]::ReadAllText($x.Draft).Replace($x.Relative,'link/created.txt')))
           $r=Invoke-FixtureDraft $x
           Assert-DraftCase 'reparse traversal refuses and leaves its target empty' ($r.Code-ne0-and$r.Text-match'DRAFT_REPARSE_PATH'-and!(Test-Path -LiteralPath (Join-Path $outside 'created.txt'))) $r.Text
       }finally{Remove-Item -LiteralPath $link -Force}
   }
   try{
       Test-Case 'deletion' "MARK`nkeep`ndel`nend`n" "MARK`nkeep`nend`n"
       Test-Case 'substring-ambiguous' "MARK`na`nfoo`nxfoo`nfoo2`nb`n" "MARK`na`nFOO`nxfoo`nfoo2`nb`n"
       Test-Case 'append-at-end' "MARK`na`nb`n" "MARK`na`nb`nc`n"
       Test-Case 'no-final-newline' "MARK`na`n" "MARK`na`nc" $true
       Test-CreationCases
   }finally{
       $resolved=[IO.Path]::GetFullPath($root);$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
       if(!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)-or(Split-Path $resolved -Leaf)-ne"orvion-draft-steps-$PID"){throw 'FIXTURE_CLEANUP_BOUNDARY'}
       if(!$fail){Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue}else{"retained failed fixtures: $resolved"}
   }
   "DRAFT STEPS: $(if($fail){"$fail FAILED"}else{'all passed'})";exit [int]($fail-gt0)
   ```

   The resulting file's Git blob is 8aefb21e60d7aef7b8429ada3ec89289f1bb01c5.

5. Check whether `scripts/agent/Test-ScriptHazards.ps1` contains `# Pre-run hazard check for agent scratch scripts (not repository code). Finds the PowerShell name`; if so record Already Applied when its Git blob is 24e364f49a1bc825afcb51fc906bd0eb83a7912d, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (Contract B bounded repository-local repair or optional adapter), and change nothing else:

   ```text
   # Pre-run hazard check for agent scratch scripts (not repository code). Finds the PowerShell name
   # collisions that broke six scratch runs (2026-10-12..19): a function named like an existing command or
   # alias (`Git` wrapping git recursed; `H` is Get-History), and a variable reused under another letter
   # case or as a loop variable over a parameter (`foreach($id ...)` overwrote `$Id`).
   # Usage: pwsh -NoProfile -File Test-ScriptHazards.ps1 <script.ps1> [...]; exit 1 when a hazard is found.
   param([Parameter(Mandatory,ValueFromRemainingArguments)][string[]]$Path)
   $found=0
   foreach($p in $Path){
       $tokens=$null;$errs=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Resolve-Path $p),[ref]$tokens,[ref]$errs)
       foreach($e in $errs){"$p`:$($e.Extent.StartLineNumber) PARSE $($e.Message)";$found++}
       foreach($fn in $ast.FindAll({$args[0]-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){
           $hit=Get-Command -Name $fn.Name -CommandType Alias,Cmdlet,Application,ExternalScript -ErrorAction SilentlyContinue|Select-Object -First 1
           if($hit){"$p`:$($fn.Extent.StartLineNumber) FUNCTION '$($fn.Name)' shadows or is shadowed by $($hit.CommandType) '$($hit.Name)'";$found++}
       }
       # Every variable spelling per scope block: one name written in two letter cases is one variable.
       $vars=$ast.FindAll({$args[0]-is[Management.Automation.Language.VariableExpressionAst]},$true)|Where-Object{$_.VariablePath.IsUnqualified-and$_.VariablePath.UserPath-notmatch'^(_|args|true|false|null|PSItem|this|input|matches|LASTEXITCODE|PID|env:.*)$'}
       foreach($g in ($vars|Group-Object{$_.VariablePath.UserPath.ToLowerInvariant()})){
           $spell=@($g.Group|ForEach-Object{$_.VariablePath.UserPath}|Sort-Object -Unique -CaseSensitive)
           if($spell.Count-gt1){"$p`:$($g.Group[0].Extent.StartLineNumber) VARIABLE spelled $($spell -join ' / ') - PowerShell treats these as ONE variable";$found++}
       }
       # A parameter or assignment named like an automatic variable: `[int[]]$Pid` is $PID, read-only (2026-10-19).
       # $null= is the idiomatic discard, not a hazard.
       $auto='^(pid|host|home|input|args|error|matches|this|true|false|psitem|pshome|pwd|profile|executioncontext|myinvocation|psscriptroot|pscommandpath|lastexitcode|sender|event|eventargs|foreach|switch)$'
       foreach($v in @($ast.FindAll({$args[0]-is[Management.Automation.Language.ParameterAst]},$true)|ForEach-Object{$_.Name})+@($ast.FindAll({$args[0]-is[Management.Automation.Language.AssignmentStatementAst]},$true)|ForEach-Object{$_.Left}|Where-Object{$_-is[Management.Automation.Language.VariableExpressionAst]})){
           $n=$v.VariablePath.UserPath;if($n-match$auto-and$n-ne'LASTEXITCODE'){"$p`:$($v.Extent.StartLineNumber) AUTOMATIC VARIABLE '`$$n' is reserved by PowerShell - rename it";$found++}
       }
   }
   if($found){"hazards: $found"}else{'hazards: 0'}
   exit [int]($found-gt0)
   ```

   The resulting file's Git blob is 24e364f49a1bc825afcb51fc906bd0eb83a7912d.

6. Check whether `scripts/check_agent_continuity.ps1` contains `function Read-RequiredGit([string[]]$Arguments,[int[]]$AllowedExitCodes=@(0)){`; if so record Already Applied when its Git blob is 3c0a09d3622529fd9c2d5e66f5f29a1548bdf92f, and otherwise stop and report. Otherwise make exactly these 5 edits (Contract B bounded repository-local repair or optional adapter), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   function Read-GitFile([string]$Ref,[string]$Path){$value=git -C $Root show "${Ref}:$Path" 2>$null;if($LASTEXITCODE-ne0){return $null};$value-join"`n"}

   ```
   insert
   ```text
   function Read-RequiredGit([string[]]$Arguments,[int[]]$AllowedExitCodes=@(0)){
       $stderr=[IO.Path]::GetTempFileName()
       try{
           $lines=@(git -C $Root @Arguments 2>$stderr)
           $nativeCode=$LASTEXITCODE
           $detail=[IO.File]::ReadAllText($stderr).Trim()
           $global:LASTEXITCODE=0
           if($nativeCode-notin$AllowedExitCodes-or($nativeCode-eq1-and$detail)){throw "GIT_READ_FAILED:$($Arguments[0]):exit=$nativeCode`: $detail"}
           [pscustomobject]@{Lines=[string[]]$lines;ExitCode=$nativeCode}
       }finally{[IO.File]::Delete($stderr)}
   }
   ```

   b) replace the lines
   ```text
       foreach($path in @(git -C $Root ls-tree -r --name-only $Ref)){if($path-match$rx){return $true}}
       $hits=@(git -C $Root grep -I -E ([regex]::Escape($Id)+'([^0-9]|$)') $Ref -- . 2>$null);$LASTEXITCODE=0
       $hits.Count-gt0
   ```
   with
   ```text
       $tree=Read-RequiredGit -Arguments @('ls-tree','-r','--name-only',$Ref)
       foreach($path in $tree.Lines){if($path-match$rx){return $true}}
       $hits=Read-RequiredGit -Arguments @('grep','-I','-E',([regex]::Escape($Id)+'([^0-9]|$)'),$Ref,'--','.') -AllowedExitCodes @(0,1)
       $hits.ExitCode-eq0-and$hits.Lines.Count-gt0
   ```

   c) replace the lines
   ```text
       $x=(git -C $Root rev-list --left-right --count 'HEAD...@{u}')-split'\s+';$dirty=@(git -C $Root status --porcelain).Count-gt0
       [pscustomobject]@{Text="$(if($dirty){'dirty'}else{'clean'}) | ahead $($x[0]) / behind $($x[1])";Synced=([int]$x[1]-eq0)}
   ```
   with
   ```text
       $counts=Read-RequiredGit -Arguments @('rev-list','--left-right','--count','HEAD...@{u}')
       if($counts.Lines.Count-ne1){throw 'GIT_COUNT_INVALID:field_count'}
       $match=[regex]::Match($counts.Lines[0],'^\s*(\d+)\s+(\d+)\s*$')
       $ahead=0L;$behind=0L
       if(!$match.Success-or![long]::TryParse($match.Groups[1].Value,[ref]$ahead)-or![long]::TryParse($match.Groups[2].Value,[ref]$behind)){throw 'GIT_COUNT_INVALID:integer_pair'}
       $status=Read-RequiredGit -Arguments @('status','--porcelain')
       $dirty=$status.Lines.Count-gt0
       [pscustomobject]@{Text="$(if($dirty){'dirty'}else{'clean'}) | ahead $ahead / behind $behind";Synced=($behind-eq0)}
   ```

   d) immediately after the line
   ```text
           Write-Output 'WRITE_AUTHORITY: none (Draft CR authoring only)'
   ```
   insert
   ```text
           Write-Output 'ADAPTER_CONTEXT: AGENTS.md (repository-local optional adapters) (optional; no write authority)'
   ```

   e) immediately after the line
   ```text
       Write-Output "START_CONTEXT: $($c.Reading-join', ')"
   ```
   insert
   ```text
       Write-Output 'ADAPTER_CONTEXT: AGENTS.md (repository-local optional adapters) (optional; no write authority)'
   ```

   The resulting file's Git blob is 3c0a09d3622529fd9c2d5e66f5f29a1548bdf92f.

7. Check whether `scripts/github_public_read.ps1` contains `function Invoke-OrvionPublicHttp([uri]$Uri, [double]$TimeoutSeconds = 20) {`; if so record Already Applied when its Git blob is 6493a2f5cbf8f65f4e479b0c172e30b1f3521cae, and otherwise stop and report. Otherwise make exactly these 11 edits (Contract B bounded repository-local repair or optional adapter), each matched once, and change nothing else:

   a) replace the line
   ```text
   function Invoke-OrvionPublicHttp([uri]$Uri, [int]$TimeoutSeconds = 20) {
   ```
   with
   ```text
   function Invoke-OrvionPublicHttp([uri]$Uri, [double]$TimeoutSeconds = 20) {
   ```

   b) replace the lines
   ```text
   function Read-OrvionPublicJson([uri]$Uri, [switch]$WithHeaders) {
       $r = Invoke-OrvionPublicHttp $Uri
   ```
   with
   ```text
   function Read-OrvionPublicJson([uri]$Uri, [switch]$WithHeaders, [double]$TimeoutSeconds = 20) {
       $r = Invoke-OrvionPublicHttp $Uri -TimeoutSeconds $TimeoutSeconds
   ```

   c) replace the lines
   ```text
   function Get-OrvionPublicBudget {
       $j = Read-OrvionPublicJson ([uri]'https://api.github.com/rate_limit')
   ```
   with
   ```text
   function Get-OrvionPublicBudget([double]$TimeoutSeconds = 20) {
       $j = Read-OrvionPublicJson ([uri]'https://api.github.com/rate_limit') -TimeoutSeconds $TimeoutSeconds
   ```

   d) immediately after the line
   ```text
   function Wait-OrvionPublicSlot([int]$MinSeconds = 60, [int]$MaxWaitSeconds = 3600) {
   ```
   insert
   ```text
       if($MaxWaitSeconds-lt0){throw 'PUBLIC_READ:BUDGET_ARGUMENT'}
       $clock=[Diagnostics.Stopwatch]::StartNew()
       $limitMs=[double]$MaxWaitSeconds*1000
       $exhaust={param([double]$RetryMilliseconds)
           $retry=[long][Math]::Ceiling([Math]::Max(0,$RetryMilliseconds)/1000)
           $e=[InvalidOperationException]::new("PUBLIC_READ:BUDGET_EXHAUSTED:retry_after=$retry")
           $e.Data['RetryAfterSeconds']=$retry
           throw $e
       }
   ```

   e) immediately after the line
   ```text
       while ($true) {
   ```
   insert
   ```text
           if($clock.Elapsed.TotalMilliseconds-ge$limitMs){&$exhaust 0}
   ```

   f) immediately after the line
   ```text
           for ($i = 0; -not $lock; $i++) {
   ```
   insert
   ```text
               $remaining=$limitMs-$clock.Elapsed.TotalMilliseconds
               if($remaining-le0){&$exhaust 0}
   ```

   g) replace the line
   ```text
               catch { if ($i -ge 300) { throw 'PUBLIC_READ:BUDGET_LOCK' }; Start-Sleep -Milliseconds 100 }
   ```
   with
   ```text
               catch {
                   if($clock.Elapsed.TotalMilliseconds-ge$limitMs){&$exhaust 0}
                   if ($i -ge 300) { throw 'PUBLIC_READ:BUDGET_LOCK' }
                   Start-Sleep -Milliseconds ([Math]::Min(100,[Math]::Max(1,[Math]::Floor($limitMs-$clock.Elapsed.TotalMilliseconds))))
               }
   ```

   h) replace the lines
   ```text
               $b = Get-OrvionPublicBudget
               $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()   # milliseconds: whole seconds let two turns land 1.1 s apart
   ```
   with
   ```text
               $remaining=$limitMs-$clock.Elapsed.TotalMilliseconds
               if($remaining-le0){&$exhaust 0}
               try{$b = Get-OrvionPublicBudget -TimeoutSeconds ([Math]::Min([double]20,([double]$remaining/1000)))}
               catch{if($clock.Elapsed.TotalMilliseconds-ge$limitMs){&$exhaust 0};throw}
               $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
   ```

   i) replace the lines
   ```text
                   $slot = [Math]::Max($now, $next)
                   [IO.File]::WriteAllText($script:OrvionPublicLedger, "$($slot + $spacing)")
   ```
   with
   ```text
                   $slot = [Math]::Max($now, $next)
   ```

   j) immediately after the lines
   ```text
                   $wait = $slot - $now
               }
   ```
   insert
   ```text
               $remaining=$limitMs-$clock.Elapsed.TotalMilliseconds
               if($remaining-le0-or$wait-ge$remaining){&$exhaust $wait}
               if($spendable-gt0){[IO.File]::WriteAllText($script:OrvionPublicLedger,"$($slot+$spacing)")}
   ```

   k) replace the lines
   ```text
           if ($spendable -gt 0) { if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }; return }
           $waitSeconds = [long][Math]::Ceiling($wait / 1000)
           if ($waitSeconds -gt $MaxWaitSeconds) { $e = [InvalidOperationException]::new("PUBLIC_READ:BUDGET_EXHAUSTED:retry_after=$waitSeconds"); $e.Data['RetryAfterSeconds'] = $waitSeconds; throw $e }
   ```
   with
   ```text
           if ($spendable -gt 0) {
               if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
               if($clock.Elapsed.TotalMilliseconds-ge$limitMs){&$exhaust 0}
               return
           }
   ```

   The resulting file's Git blob is 6493a2f5cbf8f65f4e479b0c172e30b1f3521cae.

8. Check whether `scripts/owner_promote.ps1` contains `# Tracked single-product owner interface. Run this file from trusted main; native engines remain authoritative.`; if so record Already Applied when its Git blob is 47aaa9eb76e5cec86dc4eab8f158050e520e71c0, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (Contract B bounded repository-local repair or optional adapter), and change nothing else:

   ```text
   # Tracked single-product owner interface. Run this file from trusted main; native engines remain authoritative.
   # Owner adapter only. Existing repository publisher/promoter remain the authority.
   # Existing workstation authentication; NOT credential isolation or PAT migration.
   [CmdletBinding()]
   param([string]$Candidate, [switch]$NonInteractive, [string]$EvidenceDirectory)
   $ErrorActionPreference = 'Stop'
   $operation = 'PROMOTE'
   $checkout = Split-Path $PSScriptRoot -Parent
   $interactive = !$NonInteractive -and [Environment]::UserInteractive -and $Host.Name -eq 'ConsoleHost'
   try { $interactive = $interactive -and ![Console]::IsInputRedirected -and ![Console]::IsOutputRedirected } catch { $interactive = $false }
   # Host switches precede -File/-Command; do not mistake script arguments for host switches.
   foreach ($a in [Environment]::GetCommandLineArgs() | Select-Object -Skip 1) {
       if ($a -match '^-(File|f|Command|c|EncodedCommand|e|ec)$') { break }
       if ($a.StartsWith('-') -and $a.Length -ge 5 -and 'noninteractive'.StartsWith($a.Substring(1).ToLowerInvariant())) { $interactive = $false }
   }
   $result = 'STARTED'; $classification = 'STARTING'; $exitCode = 1
   $saved = $false
   $selected = $null; $log = $null; $noHooks = $null
   $started = [DateTime]::UtcNow.ToString('o')
   function Save-Result {
       # Allowlisted metadata only. No transcripts, command output, exception text or environment dump.
       $record = [ordered]@{ operation=$operation; candidate=$selected; startedUtc=$started;
           recordedUtc=[DateTime]::UtcNow.ToString('o'); repository='PlatPlusHub/CRM'; checkout=$checkout;
           targetRef='refs/heads/main'; result=$result; classification=$classification; exitCode=$exitCode }
       [IO.File]::WriteAllText($log, ($record | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
   }
   function Invoke-ReleaseChild([string]$Script, [string[]]$Arguments) {
       $script:classification = 'AUTHORITATIVE_COMMAND'
       $script:result = 'FAILED'
       # Windows PowerShell 5.1 promotes redirected native stderr (even Git's
       # successful "Everything up-to-date") to error records. Judge the process
       # by its captured exit code and exact verdict, not by that host conversion.
       $priorPreference = $ErrorActionPreference
       [void](Get-Command pwsh -ErrorAction Stop)
       try {
           $ErrorActionPreference = 'Continue'
           $lines = @(& pwsh -NoProfile -File $Script @Arguments 2>&1)
           $code = $LASTEXITCODE
       } finally { $ErrorActionPreference = $priorPreference }
       if ($null -eq $code) { throw 'Authoritative command did not return a process exit code.' }
       # Child DONE is provisional until this wrapper also verifies the exact remote ref.
       $lines | Where-Object { "$_" -notmatch '^(PUBLISH|PROMOTE): DONE$' } | ForEach-Object { Write-Host "$_" }
       if ($code -ne 0) {
           $script:exitCode = $code
           if (@($lines | Where-Object { "$_" -match '^(PUBLISH|PROMOTE): REFUSED$' }).Count) { $script:result = 'REFUSED' }
           throw "Authoritative $operation command returned exit $code. Preserve checkouts and receipts."
       }
       # Exit zero alone cannot turn a contradictory/missing child verdict into success.
       $verdicts = @($lines | Where-Object { "$_" -match '^(PUBLISH|PROMOTE):' })
       if ($verdicts.Count -ne 1 -or "$($verdicts[0])" -cne "${operation}: DONE") {
           throw 'Authoritative command did not return one unambiguous DONE result.'
       }
       $script:exitCode = 1; $script:classification = 'REMOTE_REF_VERIFICATION'
   }
   function Get-OwnerTrustedSource {
       $sourceRoot = Split-Path $PSScriptRoot -Parent
       function Read-SourceGit([string[]]$Arguments) {
           $value = @(& git -C $sourceRoot @Arguments 2>$null)
           if ($LASTEXITCODE -ne 0) { throw 'STOP: Trusted source Git read failed.' }
           $value
       }
       foreach ($kind in @(@('remote','get-url','--all','origin'), @('remote','get-url','--push','--all','origin'))) {
           $urls = @(Read-SourceGit $kind)
           if ($urls.Count -ne 1 -or $urls[0] -cnotmatch '^https://(?:PlatPlusHub@)?github\.com/PlatPlusHub/CRM(?:\.git)?$') { throw 'STOP: Wrong trusted source repository.' }
       }
       if ((Read-SourceGit @('branch','--show-current') | Out-String).Trim() -cne 'main' -or @(Read-SourceGit @('status','--porcelain')).Count) { throw 'STOP: Launch this owner interface from a clean trusted main checkout.' }
       # A configuration check only: preserve the existing reset + own-account helper route; never execute or log a token.
       $sourceHelpers = @(Read-SourceGit @('config','--local','--get-all','credential.https://github.com.helper'))
       if ($sourceHelpers.Count -ne 2 -or $sourceHelpers[0] -cne '' -or
           $sourceHelpers[1] -notmatch 'gh auth token --user PlatPlusHub\b' -or
           [regex]::Matches($sourceHelpers[1], 'gh auth token --user ').Count -ne 1) { throw 'STOP: Trusted source credential routing is not pinned to the own account.' }
       & git -C $sourceRoot fetch --quiet origin
       if ($LASTEXITCODE -ne 0) { throw 'STOP: Trusted source fetch failed.' }
       if ((Read-SourceGit @('rev-parse','HEAD') | Out-String).Trim() -cne (Read-SourceGit @('rev-parse','refs/remotes/origin/main') | Out-String).Trim()) { throw 'STOP: Prepare trusted main before launching; no automatic fast-forward.' }
       $sourceRoot
   }
   function Invoke-Operation {
       $judge = Get-OwnerTrustedSource
       function GitRead([string[]]$Arguments) {
           $value = @(& git -C $judge @Arguments)
           if ($LASTEXITCODE -ne 0) { throw 'STOP: Trusted Git read failed.' }
           $value
       }
       $main = (GitRead @('rev-parse','HEAD') | Out-String).Trim()
       $preflight = (GitRead @('rev-parse','refs/remotes/origin/orvion-preflight') | Out-String).Trim()
       if ($preflight -cne $Candidate) { throw 'STOP: Current preflight does not match the selected SHA.' }
       & git -C $judge cat-file -e "$Candidate^{commit}" 2>$null
       if ($LASTEXITCODE -ne 0) { throw 'STOP: Candidate is unavailable.' }
       & git -C $judge merge-base --is-ancestor $main $Candidate
       if ($LASTEXITCODE -ne 0) { throw 'STOP: Candidate does not descend from main.' }
       Invoke-ReleaseChild (Join-Path $judge 'scripts\promote_main.ps1') @('-Candidate',$Candidate)
       $lines = @(GitRead @('ls-remote','--exit-code','origin','refs/heads/main'))
       if ($lines.Count -ne 1 -or ($lines[0] -split '\s+')[0] -cne $Candidate) { throw 'STOP: Remote main does not match the selected SHA.' }
   }
   try {
       $logs = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) } else { Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'ORVION-Owner-Review\owner-operations\PlatPlusHub_CRM' }
       [void][IO.Directory]::CreateDirectory($logs)
       $log = Join-Path $logs (('{0}-{1}-{2}.json' -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'),$operation,[guid]::NewGuid().ToString('N')))
       Save-Result
       $result = 'REFUSED'; $classification = 'PRECONDITION'
       if (!$Candidate -and $interactive) { $Candidate = Read-Host 'Full 40-character candidate SHA' }
       if (!$Candidate -or $Candidate.Trim() -cnotmatch '^[0-9a-fA-F]{40}$') { throw 'Candidate must be a full 40-character hexadecimal SHA.' }
       $Candidate = $Candidate.Trim().ToLowerInvariant(); $selected = $Candidate
       Write-Host "Operation: $operation"
       Write-Host "Candidate: $Candidate"
       Write-Host 'Repository: https://github.com/PlatPlusHub/CRM'
       Write-Host "Checkout: $checkout"
       Write-Host 'Action: synchronize the clean trusted main checkout and run its scripts/promote_main.ps1 for this exact SHA.'
       if (!$interactive) { $classification = 'INTERACTIVE_CONFIRMATION_REQUIRED'; throw 'An interactive console and explicit owner confirmation are required. No release operation was attempted.' }
       $classification = 'OWNER_CONFIRMATION'
       if ((Read-Host "Type $operation to confirm, or press Enter to cancel") -cne $operation) {
           $result = 'CANCELLED'; $classification = 'OWNER_CANCELLED'; $exitCode = 2
       } else {
           $classification = 'PRECONDITION'
           Invoke-Operation
           $result = 'DONE'; $classification = 'EXACT_REMOTE_REF_VERIFIED'; $exitCode = 0
       }
   } catch {
       Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
   } finally {
       if ($log) {
           try { Save-Result; $saved = $true } catch {
               $result = 'FAILED'; $classification = 'LOG_WRITE_FAILED'; if ($exitCode -eq 0) { $exitCode = 1 }
               Write-Host 'Operation evidence could not be saved. Do not retry a release blindly; inspect the remote ref.' -ForegroundColor Red
           }
       } else { $result = 'FAILED'; $classification = 'LOG_UNAVAILABLE' }
       Write-Host "${operation}: $result" -ForegroundColor $(if ($result -eq 'DONE') { 'Green' } else { 'Yellow' })
       Write-Host "Classification: $classification; exit code: $exitCode"
       if ($log) { Write-Host "Log: $log" }
       if ($result -eq 'DONE') { Write-Host 'Promotion is not remote certification. Certify main from the original receipt-bearing checkout.' }
       if ($interactive) {
           try { [void](Read-Host "$(if ($saved) { 'Result saved.' } else { 'Result could not be saved.' }) Press Enter when you have finished reading") }
           catch { Write-Host 'Console input unavailable; the saved log retains the result.' }
       }
   }
   exit $exitCode
   ```

   The resulting file's Git blob is 47aaa9eb76e5cec86dc4eab8f158050e520e71c0.

9. Check whether `scripts/owner_publish.ps1` contains `# Tracked single-product owner interface. Run this file from trusted main; native engines remain authoritative.`; if so record Already Applied when its Git blob is da783193f728d1a99cbda1431d03fdb57dc24f34, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (Contract B bounded repository-local repair or optional adapter), and change nothing else:

   ```text
   # Tracked single-product owner interface. Run this file from trusted main; native engines remain authoritative.
   # Owner adapter only. Existing repository publisher/promoter remain the authority.
   # Existing workstation authentication; NOT credential isolation or PAT migration.
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$Root, [string]$Candidate, [switch]$NonInteractive, [string]$EvidenceDirectory)
   $ErrorActionPreference = 'Stop'
   $operation = 'PUBLISH'
   $checkout = [IO.Path]::GetFullPath($Root)
   $interactive = !$NonInteractive -and [Environment]::UserInteractive -and $Host.Name -eq 'ConsoleHost'
   try { $interactive = $interactive -and ![Console]::IsInputRedirected -and ![Console]::IsOutputRedirected } catch { $interactive = $false }
   # Host switches precede -File/-Command; do not mistake script arguments for host switches.
   foreach ($a in [Environment]::GetCommandLineArgs() | Select-Object -Skip 1) {
       if ($a -match '^-(File|f|Command|c|EncodedCommand|e|ec)$') { break }
       if ($a.StartsWith('-') -and $a.Length -ge 5 -and 'noninteractive'.StartsWith($a.Substring(1).ToLowerInvariant())) { $interactive = $false }
   }
   $result = 'STARTED'; $classification = 'STARTING'; $exitCode = 1
   $saved = $false
   $selected = $null; $log = $null; $noHooks = $null
   $started = [DateTime]::UtcNow.ToString('o')
   function Save-Result {
       # Allowlisted metadata only. No transcripts, command output, exception text or environment dump.
       $record = [ordered]@{ operation=$operation; candidate=$selected; startedUtc=$started;
           recordedUtc=[DateTime]::UtcNow.ToString('o'); repository='PlatPlusHub/CRM'; checkout=$checkout;
           targetRef='refs/heads/orvion-preflight'; result=$result; classification=$classification; exitCode=$exitCode }
       [IO.File]::WriteAllText($log, ($record | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
   }
   function Invoke-ReleaseChild([string]$Script, [string[]]$Arguments) {
       $script:classification = 'AUTHORITATIVE_COMMAND'
       $script:result = 'FAILED'
       # Windows PowerShell 5.1 promotes redirected native stderr (even Git's
       # successful "Everything up-to-date") to error records. Judge the process
       # by its captured exit code and exact verdict, not by that host conversion.
       $priorPreference = $ErrorActionPreference
       [void](Get-Command pwsh -ErrorAction Stop)
       try {
           $ErrorActionPreference = 'Continue'
           $lines = @(& pwsh -NoProfile -File $Script @Arguments 2>&1)
           $code = $LASTEXITCODE
       } finally { $ErrorActionPreference = $priorPreference }
       if ($null -eq $code) { throw 'Authoritative command did not return a process exit code.' }
       # Child DONE is provisional until this wrapper also verifies the exact remote ref.
       $lines | Where-Object { "$_" -notmatch '^(PUBLISH|PROMOTE): DONE$' } | ForEach-Object { Write-Host "$_" }
       if ($code -ne 0) {
           $script:exitCode = $code
           if (@($lines | Where-Object { "$_" -match '^(PUBLISH|PROMOTE): REFUSED$' }).Count) { $script:result = 'REFUSED' }
           throw "Authoritative $operation command returned exit $code. Preserve checkouts and receipts."
       }
       # Exit zero alone cannot turn a contradictory/missing child verdict into success.
       $verdicts = @($lines | Where-Object { "$_" -match '^(PUBLISH|PROMOTE):' })
       if ($verdicts.Count -ne 1 -or "$($verdicts[0])" -cne "${operation}: DONE") {
           throw 'Authoritative command did not return one unambiguous DONE result.'
       }
       $script:exitCode = 1; $script:classification = 'REMOTE_REF_VERIFICATION'
   }
   function Get-OwnerTrustedSource {
       $sourceRoot = Split-Path $PSScriptRoot -Parent
       function Read-SourceGit([string[]]$Arguments) {
           $value = @(& git -C $sourceRoot @Arguments 2>$null)
           if ($LASTEXITCODE -ne 0) { throw 'STOP: Trusted source Git read failed.' }
           $value
       }
       foreach ($kind in @(@('remote','get-url','--all','origin'), @('remote','get-url','--push','--all','origin'))) {
           $urls = @(Read-SourceGit $kind)
           if ($urls.Count -ne 1 -or $urls[0] -cnotmatch '^https://(?:PlatPlusHub@)?github\.com/PlatPlusHub/CRM(?:\.git)?$') { throw 'STOP: Wrong trusted source repository.' }
       }
       if ((Read-SourceGit @('branch','--show-current') | Out-String).Trim() -cne 'main' -or @(Read-SourceGit @('status','--porcelain')).Count) { throw 'STOP: Launch this owner interface from a clean trusted main checkout.' }
       # A configuration check only: preserve the existing reset + own-account helper route; never execute or log a token.
       $sourceHelpers = @(Read-SourceGit @('config','--local','--get-all','credential.https://github.com.helper'))
       if ($sourceHelpers.Count -ne 2 -or $sourceHelpers[0] -cne '' -or
           $sourceHelpers[1] -notmatch 'gh auth token --user PlatPlusHub\b' -or
           [regex]::Matches($sourceHelpers[1], 'gh auth token --user ').Count -ne 1) { throw 'STOP: Trusted source credential routing is not pinned to the own account.' }
       & git -C $sourceRoot fetch --quiet origin
       if ($LASTEXITCODE -ne 0) { throw 'STOP: Trusted source fetch failed.' }
       if ((Read-SourceGit @('rev-parse','HEAD') | Out-String).Trim() -cne (Read-SourceGit @('rev-parse','refs/remotes/origin/main') | Out-String).Trim()) { throw 'STOP: Prepare trusted main before launching; no automatic fast-forward.' }
       $sourceRoot
   }
   function Invoke-Operation {
   $sourceRoot = Get-OwnerTrustedSource
   $repo = $checkout
   function GitRead([string[]]$Arguments) {
       $value = @(& git -C $repo @Arguments)
       if ($LASTEXITCODE -ne 0) { throw "STOP: Git read failed: $($Arguments -join ' ')" }
       return $value
   }
   if (!(Test-Path -LiteralPath (Join-Path $repo 'scripts\publish_candidate.ps1') -PathType Leaf)) { throw "STOP: Original CRM checkout missing: $repo" }
   $top = (GitRead @('rev-parse','--show-toplevel') | Out-String).Trim()
   if ([IO.Path]::GetFullPath($top) -ine [IO.Path]::GetFullPath($repo)) { throw 'STOP: Unexpected repository root.' }
   foreach ($kind in @(@('remote','get-url','--all','origin'), @('remote','get-url','--push','--all','origin'))) {
       $urls = @(GitRead $kind)
       if ($urls.Count -ne 1 -or $urls[0] -cnotmatch '^https://(?:PlatPlusHub@)?github\.com/PlatPlusHub/CRM(?:\.git)?$') { throw 'STOP: Unexpected CRM fetch/push destination.' }
   }
   $candidateHelpers = @(GitRead @('config','--local','--get-all','credential.https://github.com.helper'))
   if ($candidateHelpers.Count -ne 2 -or $candidateHelpers[0] -cne '' -or
       $candidateHelpers[1] -notmatch 'gh auth token --user PlatPlusHub\b' -or
       [regex]::Matches($candidateHelpers[1], 'gh auth token --user ').Count -ne 1) { throw 'STOP: Candidate credential routing is not pinned to the own account.' }
   $head = (GitRead @('rev-parse','HEAD') | Out-String).Trim()
   if ($head -cne $Candidate) { throw "STOP: Original HEAD is $head; expected $Candidate. Preserve the checkout and ask the agent to prepare it." }
   if (@(GitRead @('status','--porcelain')).Count) { throw 'STOP: Original checkout is dirty.' }
   if (!(GitRead @('branch','--show-current') | Out-String).Trim()) { throw 'STOP: Detached HEAD; ask the agent to restore the prepared candidate branch.' }
   if (!(Test-Path -LiteralPath (Join-Path $repo ".orvion-certifications\$Candidate.json") -PathType Leaf)) { throw 'STOP: Original exact-SHA certification record is missing.' }
   & git -C $repo fetch --quiet origin
   if ($LASTEXITCODE -ne 0) { throw 'STOP: Fetch failed.' }
   $main = (GitRead @('rev-parse','refs/remotes/origin/main') | Out-String).Trim()
   & git -C $repo merge-base --is-ancestor $main $Candidate
   if ($LASTEXITCODE -ne 0) { throw 'STOP: Candidate diverges from current main.' }
   if ((GitRead @('rev-parse','HEAD') | Out-String).Trim() -cne $Candidate -or @(GitRead @('status','--porcelain')).Count) { throw 'STOP: Checkout changed during preparation.' }
   Invoke-ReleaseChild (Join-Path $sourceRoot 'scripts\publish_candidate.ps1') @('-Root',$repo)
   $lines = @(GitRead @('ls-remote','--exit-code','origin','refs/heads/orvion-preflight'))
   if ($lines.Count -ne 1 -or ($lines[0] -split '\s+')[0] -cne $Candidate) { throw 'STOP: Remote preflight does not match the selected SHA.' }
   }
   try {
       $logs = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) } else { Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'ORVION-Owner-Review\owner-operations\PlatPlusHub_CRM' }
       [void][IO.Directory]::CreateDirectory($logs)
       $log = Join-Path $logs (('{0}-{1}-{2}.json' -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'),$operation,[guid]::NewGuid().ToString('N')))
       Save-Result
       $result = 'REFUSED'; $classification = 'PRECONDITION'
       if (!$Candidate -and $interactive) { $Candidate = Read-Host 'Full 40-character candidate SHA' }
       if (!$Candidate -or $Candidate.Trim() -cnotmatch '^[0-9a-fA-F]{40}$') { throw 'Candidate must be a full 40-character hexadecimal SHA.' }
       $Candidate = $Candidate.Trim().ToLowerInvariant(); $selected = $Candidate
       Write-Host "Operation: $operation"
       Write-Host "Candidate: $Candidate"
       Write-Host 'Repository: https://github.com/PlatPlusHub/CRM'
       Write-Host "Checkout: $checkout"
       Write-Host 'Action: validate the prepared receipt and publish this exact SHA through scripts/publish_candidate.ps1.'
       if (!$interactive) { $classification = 'INTERACTIVE_CONFIRMATION_REQUIRED'; throw 'An interactive console and explicit owner confirmation are required. No release operation was attempted.' }
       $classification = 'OWNER_CONFIRMATION'
       if ((Read-Host "Type $operation to confirm, or press Enter to cancel") -cne $operation) {
           $result = 'CANCELLED'; $classification = 'OWNER_CANCELLED'; $exitCode = 2
       } else {
           $classification = 'PRECONDITION'
           Invoke-Operation
           $result = 'DONE'; $classification = 'EXACT_REMOTE_REF_VERIFIED'; $exitCode = 0
       }
   } catch {
       Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
   } finally {
       if ($log) {
           try { Save-Result; $saved = $true } catch {
               $result = 'FAILED'; $classification = 'LOG_WRITE_FAILED'; if ($exitCode -eq 0) { $exitCode = 1 }
               Write-Host 'Operation evidence could not be saved. Do not retry a release blindly; inspect the remote ref.' -ForegroundColor Red
           }
       } else { $result = 'FAILED'; $classification = 'LOG_UNAVAILABLE' }
       Write-Host "${operation}: $result" -ForegroundColor $(if ($result -eq 'DONE') { 'Green' } else { 'Yellow' })
       Write-Host "Classification: $classification; exit code: $exitCode"
       if ($log) { Write-Host "Log: $log" }
       if ($result -eq 'DONE') { Write-Host 'Publication is not acceptance or certification. Wait for exact-SHA PROMOTION READY before Owner-Promote.' }
       if ($interactive) {
           try { [void](Read-Host "$(if ($saved) { 'Result saved.' } else { 'Result could not be saved.' }) Press Enter when you have finished reading") }
           catch { Write-Host 'Console input unavailable; the saved log retains the result.' }
       }
   }
   exit $exitCode
   ```

   The resulting file's Git blob is da783193f728d1a99cbda1431d03fdb57dc24f34.

10. Check whether `scripts/test_agent_continuity.ps1` contains `function Get-OrvionPublicRepo([string]$Root) { if($env:ORVION_STUB_ORIGIN_BAD){throw 'PUBLIC_READ:ORIGIN'}; 'fixture/repository' }`; if so record Already Applied when its Git blob is 0bf297c9db4f39b8b9297b0af02a3a812ce3e427, and otherwise stop and report. Otherwise make exactly these 4 edits (Contract B bounded repository-local repair or optional adapter), each matched once, and change nothing else:

   a) replace the line
   ```text
   function Get-OrvionPublicRepo([string]$Root) { 'fixture/repository' }
   ```
   with
   ```text
   function Get-OrvionPublicRepo([string]$Root) { if($env:ORVION_STUB_ORIGIN_BAD){throw 'PUBLIC_READ:ORIGIN'}; 'fixture/repository' }
   ```

   b) immediately after the line
   ```text
   function Assert($Name,[bool]$Condition,[string]$Evidence=''){if($Condition){$script:pass++;Write-Host "PASS $Name"}else{$script:fail++;Write-Host "FAIL $Name :: $Evidence"}}
   ```
   insert
   ```text
   function Test-AbsentCriterionListing([string]$ControlSource,[string]$FixtureRoot){
       # Exact lower-guard evidence: whole-Gate store/read refusals are tested separately, never disabled here.
       $caseTokens=$null;$caseErrors=$null
       $caseAst=[Management.Automation.Language.Parser]::ParseFile($ControlSource,[ref]$caseTokens,[ref]$caseErrors)
       $caseFunctions=@($caseAst.FindAll({param($node)$node-is[Management.Automation.Language.FunctionDefinitionAst]-and$node.Name-ceq'Test-CriterionCheck'},$true))
       if($caseErrors.Count-or$caseFunctions.Count-ne1){throw 'ABSENT_LISTING_FUNCTION_SOURCE'}
       $caseSource=$caseFunctions[0].Extent.Text
       $needle='if($LASTEXITCODE-ne0){throw "CRITERION_CHECK_INDETERMINATE'
       if([regex]::Matches($caseSource,[regex]::Escape($needle)).Count-ne1){throw 'ABSENT_LISTING_MUTATION_ANCHOR'}
       $root=$FixtureRoot
       $criterion=[pscustomobject]@{Kind='absent';Path='retired.txt';Key=''}
       $population=@(git -C $root ls-tree --name-only HEAD -- retired.txt 2>$null)
       if($LASTEXITCODE-ne0-or$population.Count-ne1-or$population[0]-cne'retired.txt'){throw 'ABSENT_LISTING_EMPTY_POPULATION'}
       . ([scriptblock]::Create($caseSource))
       $pristineError=''
       try{Test-CriterionCheck $criterion 'HEAD'|Out-Null}catch{$pristineError=$_.Exception.Message}
       . ([scriptblock]::Create($caseSource.Replace($needle,'if($false){throw "CRITERION_CHECK_INDETERMINATE')))
       $mutatedResult=$null;$mutatedError=''
       try{$mutatedResult=Test-CriterionCheck $criterion 'HEAD'}catch{$mutatedError=$_.Exception.Message}
       . ([scriptblock]::Create($caseSource))
       [pscustomobject]@{Passed=($pristineError.StartsWith('CRITERION_CHECK_INDETERMINATE:')-and!$mutatedError-and$null-eq$mutatedResult);
           Detail="population=$($population[0]) pristine=$pristineError mutantError=$mutatedError mutantResult=$mutatedResult";
           Boundary='Exact Test-CriterionCheck function and real missing-tree Git fixture; no whole-Gate or credential claim.'}
   }
   function Test-GitReadBoundaries([string]$ControlSource,[string]$FixtureRoot){
       # Exact function tests with real Git; injected failures never certify whole-Gate admission.
       if(Test-Path -LiteralPath $FixtureRoot){throw 'READ_FIXTURE_EXISTS'}
       [void][IO.Directory]::CreateDirectory($FixtureRoot)
       $Root=$FixtureRoot;$BaseRef=$null;$HeadRef=$null
       $gitExe=(Get-Command git -CommandType Application|Select-Object -First 1).Source
       $fault=@{Mode='';Hit=$false;Missing=(Join-Path $Root 'absent-read-target')}
       function Invoke-ReadFixtureGit([string[]]$Arguments){
           $value=& $gitExe @Arguments
           if($LASTEXITCODE-ne0){throw "READ_FIXTURE_SETUP:$LASTEXITCODE"}
           $value
       }
       Invoke-ReadFixtureGit @('-C',$Root,'init','-q','-b','main')|Out-Null
       Invoke-ReadFixtureGit @('-C',$Root,'config','core.autocrlf','false')|Out-Null
       Invoke-ReadFixtureGit @('-C',$Root,'config','gc.auto','0')|Out-Null
       Invoke-ReadFixtureGit @('-C',$Root,'config','maintenance.auto','false')|Out-Null
       [IO.File]::WriteAllText((Join-Path $Root 'readme.txt'),"SPEC-901 read fixture`n")
       Invoke-ReadFixtureGit @('-C',$Root,'add','readme.txt')|Out-Null
       Invoke-ReadFixtureGit @('-C',$Root,'-c','user.name=Fixture','-c','user.email=fixture@invalid','commit','-qm','fixture')|Out-Null
       Invoke-ReadFixtureGit @('-C',$Root,'remote','add','origin',$Root)|Out-Null
       Invoke-ReadFixtureGit @('-C',$Root,'update-ref','refs/remotes/origin/main','HEAD')|Out-Null
       Invoke-ReadFixtureGit @('-C',$Root,'branch','--set-upstream-to=origin/main','main')|Out-Null
       $tok=$null;$parseErrors=$null
       $ast=[Management.Automation.Language.Parser]::ParseFile($ControlSource,[ref]$tok,[ref]$parseErrors)
       if($parseErrors.Count){throw 'READ_SOURCE_PARSE'}
       foreach($name in @('Read-RequiredGit','Base-HasId','Git-State')){
           $nodes=@($ast.FindAll({param($n) $n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$true))
           if($nodes.Count-eq0-and$name-eq'Read-RequiredGit'){continue}
           if($nodes.Count-ne1){throw "READ_SOURCE_FUNCTION:$name"}
           . ([scriptblock]::Create($nodes[0].Extent.Text))
       }
       function git {
           [string[]]$a=@($args)
           $verb=@($a|Where-Object{$_-in@('ls-tree','grep','status','rev-list')})|Select-Object -First 1
           if($verb-eq'rev-list'-and$fault.Mode-eq'malformed'){$fault.Hit=$true;$global:LASTEXITCODE=0;'not-a-count';return}
           if($verb-eq'grep'-and$fault.Mode-eq'missing-blob'){$fault.Hit=$true}
           if($verb-eq'status'-and$fault.Mode-eq'warning'){
               $fault.Hit=$true;Write-Error 'fixture stderr warning' -ErrorAction Continue
           }
           if($verb-and$verb-ceq$fault.Mode){
               $fault.Hit=$true;$i=[Array]::IndexOf($a,'-C')
               if($i-lt0){throw 'READ_INJECTION_NOT_REACHED'}
               $a[$i+1]=$fault.Missing
           }
           & $gitExe @a
           $nativeCode=$LASTEXITCODE;$global:LASTEXITCODE=$nativeCode
       }
       $rows=[Collections.Generic.List[object]]::new()
       function Add-ReadCase([string]$Id,[scriptblock]$Action,[string]$Mode,[scriptblock]$Accept,[string]$ErrorPattern=''){
           $fault.Mode=$Mode;$fault.Hit=$false;$value=$null;$errorText=''
           try{$value=&$Action}catch{$errorText=$_.Exception.Message}
           $ok=if($ErrorPattern){$fault.Hit-and$errorText-match$ErrorPattern}else{!$errorText-and(&$Accept $value)}
           if($Mode-eq'warning'){$ok=$ok-and$fault.Hit}
           $rows.Add([pscustomobject]@{Id=$Id;Passed=[bool]$ok;FaultReached=$fault.Hit;Error=$errorText;Value=$value})
       }
       Add-ReadCase 'ID present' {Base-HasId HEAD SPEC-901} '' {param($v)$v-eq$true}
       Add-ReadCase 'genuine no match' {Base-HasId HEAD SPEC-902} '' {param($v)$v-eq$false}
       Add-ReadCase 'clean upstream' {Git-State} '' {param($v)$v.Text-ceq'clean | ahead 0 / behind 0'-and$v.Synced}
       $dirty=Join-Path $Root 'untracked.txt';[IO.File]::WriteAllText($dirty,'fixture')
       Add-ReadCase 'dirty state' {Git-State} '' {param($v)$v.Text-match'^dirty \|'}
       Remove-Item -LiteralPath $dirty
       Add-ReadCase 'stderr warning is not a path' {Git-State} 'warning' {param($v)$v.Text-ceq'clean | ahead 0 / behind 0'-and$v.Synced}
       Add-ReadCase 'failed tree read refuses' {Base-HasId HEAD SPEC-902} 'ls-tree' {} '^GIT_READ_FAILED:ls-tree:exit=128'
       Add-ReadCase 'failed grep refuses' {Base-HasId HEAD SPEC-902} 'grep' {} '^GIT_READ_FAILED:grep:exit=128'
       Add-ReadCase 'failed count refuses' {Git-State} 'rev-list' {} '^GIT_READ_FAILED:rev-list:exit=128'
       Add-ReadCase 'failed status refuses' {Git-State} 'status' {} '^GIT_READ_FAILED:status:exit=128'
       Add-ReadCase 'malformed count refuses' {Git-State} 'malformed' {} '^GIT_COUNT_INVALID:'
       # Construct an extra malformed-history fixture without deleting or altering an existing object.
       $missing='1111111111111111111111111111111111111111'
       $si=[Diagnostics.ProcessStartInfo]::new($gitExe)
       $si.UseShellExecute=$false;$si.RedirectStandardInput=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
       $si.StandardInputEncoding=[Text.UTF8Encoding]::new($false)
       foreach($arg in @('-C',$Root,'mktree','--missing')){[void]$si.ArgumentList.Add($arg)}
       $proc=[Diagnostics.Process]::new();$proc.StartInfo=$si
       try{
           [void]$proc.Start();$stdout=$proc.StandardOutput.ReadToEndAsync();$stderr=$proc.StandardError.ReadToEndAsync()
           $proc.StandardInput.WriteLine('100644 blob '+$missing+[char]9+'readme.txt');$proc.StandardInput.Close()
           $proc.WaitForExit();$tree=$stdout.GetAwaiter().GetResult().Trim();$detail=$stderr.GetAwaiter().GetResult()
           if($proc.ExitCode-ne0){throw "READ_MISSING_TREE_FIXTURE:$detail"}
       }finally{$proc.Dispose()}
       $missingCommit=Invoke-ReadFixtureGit @('-C',$Root,'-c','user.name=Fixture','-c','user.email=fixture@invalid','commit-tree',$tree,'-m','missing blob fixture')
       Add-ReadCase 'unreadable blob with grep exit1 refuses' {Base-HasId $missingCommit SPEC-902} 'missing-blob' {} '^GIT_READ_FAILED:grep:exit=1'
       $global:LASTEXITCODE=0
       $rows.ToArray()
   }
   foreach($readCase in @(Test-GitReadBoundaries -ControlSource $control -FixtureRoot (Join-Path $sandbox 'read-boundaries'))){
       Assert ("READ: "+$readCase.Id) $readCase.Passed $readCase.Error
   }
   ```

   c) immediately after the line
   ```text
       Assert '108d once GitHub can be read again the same SHA certifies READY' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY') $r.Text
   ```
   insert
   ```text
       $beforeOriginLog=StubGhLog
       $env:ORVION_STUB_ORIGIN_BAD='1'
       try{$r=RunCertify}finally{Remove-Item Env:ORVION_STUB_ORIGIN_BAD -ErrorAction SilentlyContinue}
       Assert '108e a permanently invalid origin is UNREADABLE without querying workflows' ($r.Code-eq2-and$r.Text-match'REMOTE_CERTIFY: UNREADABLE'-and$r.Text-match'PUBLIC_READ:ORIGIN'-and$r.Text-notmatch'REMOTE_CERTIFY: (FAILED|PENDING|READY)'-and(StubGhLog)-ceq$beforeOriginLog) $r.Text
       $r=RunCertify
       Assert '108f restoring the origin route leaves exact-SHA certification READY' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY') $r.Text
   ```

   d) replace the lines
   ```text
       MutationKillRangeAt 'ABM5 CHECK MUTATION: behind the store guard, a failed listing is indeterminate, not absent' {ChLost -NoReset} 'CRITERION_CHECK_INDETERMINATE' `
           'if($LASTEXITCODE-ne0){throw "CRITERION_CHECK_INDETERMINATE' 'if($false){throw "CRITERION_CHECK_INDETERMINATE' 'CHECK' `
           'Assert-ObjectStoreComplete $(if' '$null=$(if'
       ChFound
   ```
   with
   ```text
       # The early required-Git guard now rejects this damage before criterion admission. Keep both guards intact;
       # prove this lower guard at its exact function boundary, while AB10 and B1 retain whole-Gate/read coverage.
       ChLost|Out-Null
       try{$listingCase=Test-AbsentCriterionListing $control $root}finally{ChFound}
       Pop 'CHECK' 'mutation'
       Assert 'ABM5 CHECK MUTATION: exact absent-listing guard rejects unreadable, and its mutant admits a known present path' $listingCase.Passed $listingCase.Detail
   ```

   The resulting file's Git blob is 0bf297c9db4f39b8b9297b0af02a3a812ce3e427.

11. Check whether `scripts/test_github_public_read.ps1` contains `public int RateDelayMs=0; public int ForcedReserveReads=0; public long Remaining=60; public long Reset=0; public long Window=3600; public int RateReads=0; public int RateFail=0;`; if so record Already Applied when its Git blob is e7f65ceebfc7f15fb96d4b46150ca0d8d26e6792, and otherwise stop and report. Otherwise make exactly these 4 edits (Contract B bounded repository-local repair or optional adapter), each matched once, and change nothing else:

   a) replace the line
   ```text
    public long Remaining=60; public long Reset=0; public long Window=3600; public int RateReads=0; public int RateFail=0;
   ```
   with
   ```text
    public int RateDelayMs=0; public int ForcedReserveReads=0; public long Remaining=60; public long Reset=0; public long Window=3600; public int RateReads=0; public int RateFail=0;
   ```

   b) replace the lines
   ```text
    void Loop(){while(!Done){try{using(var c=Listener.AcceptTcpClient()){c.ReceiveTimeout=2000;var s=c.GetStream();var reader=new StreamReader(s,Encoding.ASCII,false,1024,true);string line=reader.ReadLine(),h;var req=line+"\n";while(!String.IsNullOrEmpty(h=reader.ReadLine())) req+=h+"\n";string reply;if(line!=null&&line.StartsWith("GET /rate_limit")){RateReads++;if(RateFail>0){RateFail--;byte[] fb=Encoding.UTF8.GetBytes("HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");s.Write(fb,0,fb.Length);continue;}long now=DateTimeOffset.UtcNow.ToUnixTimeSeconds();if(Reset==0||now>=Reset){if(Reset!=0)Remaining=60;Reset=now+Window;}string body="{\"resources\":{\"core\":{\"limit\":60,\"remaining\":"+Remaining+",\"reset\":"+Reset+",\"used\":"+(60-Remaining)+"}}}";reply="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "+Encoding.UTF8.GetByteCount(body)+"\r\nConnection: close\r\n\r\n"+body;byte[] rb=Encoding.UTF8.GetBytes(reply);s.Write(rb,0,rb.Length);continue;}Requests.Enqueue(req);if(!Replies.TryDequeue(out reply))reply="HTTP/1.1 500 Missing fixture\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";if(reply.StartsWith("BODYDELAY")){reply=reply.Substring(9);int k=reply.IndexOf("\r\n\r\n")+4;byte[] hbytes=Encoding.UTF8.GetBytes(reply.Substring(0,k));s.Write(hbytes,0,hbytes.Length);Thread.Sleep(1800);reply=reply.Substring(k);}byte[] b=Encoding.UTF8.GetBytes(reply);s.Write(b,0,b.Length);}}catch{if(Done)return;}}}
    public void Dispose(){Done=true;Listener.Stop();Worker.Join(3000);}
   ```
   with
   ```text
    void Loop(){while(!Done){try{using(var c=Listener.AcceptTcpClient()){c.ReceiveTimeout=2000;var s=c.GetStream();var reader=new StreamReader(s,Encoding.ASCII,false,1024,true);string line=reader.ReadLine(),h;var req=line+"\n";while(!String.IsNullOrEmpty(h=reader.ReadLine())) req+=h+"\n";string reply;if(line!=null&&line.StartsWith("GET /rate_limit")){RateReads++;if(RateDelayMs>0)Thread.Sleep(RateDelayMs);if(RateFail>0){RateFail--;byte[] fb=Encoding.UTF8.GetBytes("HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");s.Write(fb,0,fb.Length);continue;}long now=DateTimeOffset.UtcNow.ToUnixTimeSeconds();if(Reset==0||now>=Reset){if(Reset!=0)Remaining=60;Reset=now+Window;}if(ForcedReserveReads>0){ForcedReserveReads--;Remaining=10;Reset=now+1;}string body="{\"resources\":{\"core\":{\"limit\":60,\"remaining\":"+Remaining+",\"reset\":"+Reset+",\"used\":"+(60-Remaining)+"}}}";reply="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "+Encoding.UTF8.GetByteCount(body)+"\r\nConnection: close\r\n\r\n"+body;byte[] rb=Encoding.UTF8.GetBytes(reply);s.Write(rb,0,rb.Length);continue;}Requests.Enqueue(req);if(!Replies.TryDequeue(out reply))reply="HTTP/1.1 500 Missing fixture\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";if(reply.StartsWith("BODYDELAY")){reply=reply.Substring(9);int k=reply.IndexOf("\r\n\r\n")+4;byte[] hbytes=Encoding.UTF8.GetBytes(reply.Substring(0,k));s.Write(hbytes,0,hbytes.Length);Thread.Sleep(1800);reply=reply.Substring(k);}byte[] b=Encoding.UTF8.GetBytes(reply);s.Write(b,0,b.Length);}}catch{if(Done)return;}}}
    public System.Threading.Tasks.Task HoldBudgetLock(string path,int milliseconds){var held=File.Open(path,FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);return System.Threading.Tasks.Task.Run(()=>{try{Thread.Sleep(milliseconds);}finally{held.Dispose();}});} public void Dispose(){Done=true;Listener.Stop();Worker.Join(3000);}
   ```

   c) immediately after the line
   ```text
   function Row([int]$Id=1) { @{id=$Id;workflow_id=3;name='Expected';path='.github/workflows/expected.yml';head_sha=('a'*40);head_branch='main';event='push';run_attempt=2;status='completed';conclusion='success';created_at='2026-10-16T00:00:00Z';repository=@{full_name='owner/repo'}} }
   ```
   insert
   ```text
   function Test-PublicOrigin {
       $cases=@(
           @{Name='https-git';Urls=@('https://github.com/Owner/Repo.git');Want='Owner/Repo'},
           @{Name='https-bare';Urls=@('https://github.com/Owner/Repo');Want='Owner/Repo'},
           @{Name='account-pin';Urls=@('https://Owner@github.com/Owner/Repo.git');Want='Owner/Repo'},
           @{Name='absent';Urls=@();Want=$null},
           @{Name='ssh';Urls=@('git@github.com:Owner/Repo.git');Want=$null},
           @{Name='local';Urls=@('C:/local/repository');Want=$null},
           @{Name='wrong-host';Urls=@('https://example.invalid/Owner/Repo.git');Want=$null},
           @{Name='multiple';Urls=@('https://github.com/Owner/Repo.git','https://github.com/Other/Repo.git');Want=$null}
       )
       foreach($case in $cases){
           $fixture=Join-Path $work ("origin "+$case.Name)
           [void][IO.Directory]::CreateDirectory($fixture)
           git -C $fixture init -q
           if($LASTEXITCODE){throw 'ORIGIN_FIXTURE_INIT'}
           foreach($url in $case.Urls){
               git -C $fixture config --add remote.origin.url $url
               if($LASTEXITCODE){throw 'ORIGIN_FIXTURE_CONFIG'}
           }
           $answer=$null;$problem=''
           try{$answer=Get-OrvionPublicRepo $fixture}catch{$problem=$_.Exception.Message}
           $global:LASTEXITCODE=0
           $ok=if($case.Want){$answer-ceq$case.Want-and!$problem}else{$problem-ceq'PUBLIC_READ:ORIGIN'}
           Check ("origin "+$case.Name) $ok ("answer=$answer error=$problem")
       }
   }
   function Test-PublicTotalDeadline {
       # All requests use the existing loopback HTTP fixture; never a real API budget.
       $server.Window=3600;Budget 60 3600
       $future=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+4000
       [IO.File]::WriteAllText($env:ORVION_PUBLIC_BUDGET,"$future")
       $clock=[Diagnostics.Stopwatch]::StartNew()
       $refused=Refuses {Wait-OrvionPublicSlot 0 1} 'BUDGET_EXHAUSTED'
       $elapsed=$clock.Elapsed.TotalSeconds
       $unchanged=[IO.File]::ReadAllText($env:ORVION_PUBLIC_BUDGET)-ceq"$future"
       Check 'total deadline: distant spendable slot refuses before reservation' ($refused-and$elapsed-lt1.75-and$unchanged) "elapsed=$elapsed unchanged=$unchanged"

       Budget 10 3600;$server.ForcedReserveReads=3
       $clock=[Diagnostics.Stopwatch]::StartNew()
       $reason='';$refused=try{$null=Wait-OrvionPublicSlot 0 2;$false}catch{$reason=$_.Exception.Message;$reason-match'BUDGET_EXHAUSTED'}
       $elapsed=$clock.Elapsed.TotalSeconds
       $server.ForcedReserveReads=0
       Check 'total deadline: repeated reset loops share one budget' ($refused-and$elapsed-lt2.75) "elapsed=$elapsed reason=$reason"

       Budget 60 3600
       $hold=$server.HoldBudgetLock("$env:ORVION_PUBLIC_BUDGET.lock",2500)
       try{
           $clock=[Diagnostics.Stopwatch]::StartNew()
           $refused=Refuses {Wait-OrvionPublicSlot 0 1} 'BUDGET_EXHAUSTED'
           $elapsed=$clock.Elapsed.TotalSeconds
           Check 'total deadline: lock contention is inside the budget' ($refused-and$elapsed-lt1.75) "elapsed=$elapsed"
       }finally{$hold.GetAwaiter().GetResult()}

       Budget 60 3600;$server.RateDelayMs=1500
       try{
           $clock=[Diagnostics.Stopwatch]::StartNew()
           $refused=Refuses {Wait-OrvionPublicSlot 0 1} 'BUDGET_EXHAUSTED'
           $elapsed=$clock.Elapsed.TotalSeconds
           Check 'total deadline: rate-limit HTTP read uses remaining time' ($refused-and$elapsed-lt1.75) "elapsed=$elapsed"
       }finally{$server.RateDelayMs=0}
       Budget 60 3600
       $clock=[Diagnostics.Stopwatch]::StartNew()
       $null=Wait-OrvionPublicSlot 0 5
       Check 'total deadline: immediate slot still succeeds' ($clock.Elapsed.TotalSeconds-lt2)
   }
   ```

   d) immediately after the line
   ```text
       Check 'budget: an exhausted budget stops the watcher without spending a request' ($LASTEXITCODE-eq2-and($o|Out-String)-match'STOPPED: public API retry-after=\d+ seconds is beyond'-and$server.Requests.Count-eq$count) ($o|Out-String)
   ```
   insert
   ```text
       Test-PublicTotalDeadline
       Test-PublicOrigin
   ```

   The resulting file's Git blob is e7f65ceebfc7f15fb96d4b46150ca0d8d26e6792.

12. Check whether `scripts/test_owner_interfaces.ps1` contains `# Own repository owner-adapter tests: real child processes and owned local Git fixtures.`; if so record Already Applied when its Git blob is e8fb155bcadc567a2ab0dd3d7707691de5bc504a, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (Contract B bounded repository-local repair or optional adapter), and change nothing else:

   ```text
   # Own repository owner-adapter tests: real child processes and owned local Git fixtures.
   # Console confirmation and transport are explicit fixture seams, never owner identity or remote certification proof.
   param([string]$Root=(Split-Path $PSScriptRoot -Parent))
   $ErrorActionPreference='Stop'
   $work=Join-Path ([IO.Path]::GetTempPath()) ('orvion-owner-interfaces-'+[guid]::NewGuid().ToString('N'))
   [void][IO.Directory]::CreateDirectory($work)
   $output=Join-Path $work 'result.json'
   $MaxCases=0; $CaseNames=@()
   $gitExe = (Get-Command git -CommandType Application | Select-Object -First 1).Source
   $records = [Collections.Generic.List[object]]::new()
   function Write-FixtureText([string]$Path, [string]$Text) {
       [void][IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
       [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
   }
   function Invoke-FixtureSetupGit([string[]]$Arguments) {
       $lines = @(& $gitExe @Arguments 2>&1)
       if ($LASTEXITCODE -ne 0) { throw "FIXTURE_GIT: $($Arguments -join ' '): $($lines -join ' ')" }
       $lines | ForEach-Object { "$_" }
   }
   $nativeStub = @'
   param([string]$Root, [string]$Candidate)
   $ErrorActionPreference = 'Stop'
   $cfg = Get-Content -Raw -LiteralPath $env:ORVION_B4_FIXTURE_CONFIG | ConvertFrom-Json
   $operation = if ($PSCommandPath -match 'publish_candidate') { 'PUBLISH' } else { 'PROMOTE' }
   @{Operation=$operation;Root=$Root;Candidate=$Candidate;Script=$PSCommandPath} | ConvertTo-Json | Set-Content -LiteralPath $cfg.NativeCall
   if ($cfg.Mode -eq 'native-fail') { Write-Output "${operation}: REFUSED"; exit 7 }
   if ($cfg.Mode -eq 'zero-no-done') { Write-Output 'Fixture child completed without a verdict'; exit 0 }
   $target = if ($operation -eq 'PUBLISH') { 'refs/heads/orvion-preflight' } else { 'refs/heads/main' }
   $value = if ($cfg.Mode -eq 'wrong-ref') { $cfg.Base } else { $cfg.Candidate }
   & $cfg.GitExe -C $cfg.Bare update-ref $target $value
   if ($LASTEXITCODE -ne 0) { throw 'FIXTURE_REF_UPDATE' }
   Write-Output "${operation}: DONE"
   if ($cfg.Mode -eq 'duplicate-done') { Write-Output "${operation}: DONE" }
   if ($cfg.Mode -eq 'contradictory') { Write-Output "${operation}: REFUSED" }
   if ($cfg.Mode -eq 'blocked-and-done') { Write-Output "${operation}: BLOCKED" }
   if ($cfg.Mode -eq 'unreadable-and-done') { Write-Output "${operation}: UNREADABLE" }
   if ($cfg.Mode -eq 'cross-operation') { Write-Output $(if($operation-eq'PUBLISH'){'PROMOTE: DONE'}else{'PUBLISH: DONE'}) }
   if ($cfg.Mode -eq 'unknown-verdict') { Write-Output "${operation}: UNKNOWN" }
   exit 0
   '@
   $driver = @'
   param([Parameter(Mandatory)][string]$Config)
   $ErrorActionPreference = 'Stop'
   $global:OrvionB4Fixture = Get-Content -Raw -LiteralPath $Config | ConvertFrom-Json
   $env:ORVION_B4_FIXTURE_CONFIG = $Config
   function Invoke-FixtureGit {
       $GitArguments = @($args)
       if ($GitArguments.Count -lt 3 -or $GitArguments[0] -cne '-C' -or $GitArguments[1] -notin @($global:OrvionB4Fixture.Source,$global:OrvionB4Fixture.Root)) { throw 'FIXTURE_UNEXPECTED_GIT_ROOT' }
       $forward = @($GitArguments)
       $verb = $forward[2]
       if ($verb -eq 'push') { throw 'FIXTURE_PUSH_FORBIDDEN' }
       if ($verb -eq 'fetch') {
           if ($forward.Count -ne 5 -or $forward[3] -cne '--quiet' -or $forward[4] -cne 'origin') { throw 'FIXTURE_UNEXPECTED_FETCH' }
           $forward = @('-C',$forward[1],'fetch','--quiet',$global:OrvionB4Fixture.Bare,'refs/heads/*:refs/remotes/origin/*')
           Add-Content -LiteralPath $global:OrvionB4Fixture.Transport -Value 'FETCH_LOCAL_BARE'
       } elseif ($verb -eq 'ls-remote') {
           if ($forward.Count -ne 6 -or $forward[3] -cne '--exit-code' -or $forward[4] -cne 'origin' -or $forward[5] -notin @('refs/heads/main','refs/heads/orvion-preflight')) { throw 'FIXTURE_UNEXPECTED_LS_REMOTE' }
           $forward[4] = $global:OrvionB4Fixture.Bare
           Add-Content -LiteralPath $global:OrvionB4Fixture.Transport -Value ('LS_REMOTE_LOCAL_BARE '+$forward[5])
       }
       & $global:OrvionB4Fixture.GitExe @forward
       $global:LASTEXITCODE = $LASTEXITCODE
   }
   function Read-FixtureConfirmation([string]$Prompt) {
       if ($Prompt -match '^Type ') { if ($global:OrvionB4Fixture.Mode -eq 'cancel') { return '' }; return $global:OrvionB4Fixture.Operation }
       return ''
   }
   Set-Alias -Name git -Value Invoke-FixtureGit
   $invokeArguments = @{Candidate=$global:OrvionB4Fixture.Selected;EvidenceDirectory=$global:OrvionB4Fixture.Evidence}
   if ($global:OrvionB4Fixture.Operation -eq 'PUBLISH') { $invokeArguments.Root = $global:OrvionB4Fixture.Root }
   if ($global:OrvionB4Fixture.Mode -eq 'noninteractive') { $invokeArguments.NonInteractive = $true }
   & $global:OrvionB4Fixture.Interface @invokeArguments
   exit $LASTEXITCODE
   '@
   $driverPath = Join-Path $work 'fixture-driver.ps1'
   Write-FixtureText $driverPath $driver
   :Products foreach ($product in @(@{Key='self';Repository='PlatPlusHub/CRM'})) {
       $template = Join-Path $work ($product.Key+'-seed')
       [void](Invoke-FixtureSetupGit @('init','--quiet','-b','main',$template))
       [void](Invoke-FixtureSetupGit @('-C',$template,'config','user.name','Isolated caller fixture'))
       [void](Invoke-FixtureSetupGit @('-C',$template,'config','user.email','fixture@example.invalid'))
       [void](Invoke-FixtureSetupGit @('-C',$template,'config','core.autocrlf','false'))
       Write-FixtureText (Join-Path $template '.gitignore') ".orvion-certifications/`n"
       Write-FixtureText (Join-Path $template 'scripts\publish_candidate.ps1') $nativeStub
       Write-FixtureText (Join-Path $template 'scripts\promote_main.ps1') $nativeStub
       foreach ($operation in @('publish','promote')) {
           $subject = Join-Path $Root "scripts\owner_$operation.ps1"
           $originalText = [IO.File]::ReadAllText($subject) -replace "`r`n", "`n"
           Write-FixtureText (Join-Path $template "scripts\owner_$operation.original.ps1") $originalText
           $start = $originalText.IndexOf('$interactive = !$NonInteractive')
           $finish = $originalText.IndexOf("`n"+'$result = ', $start)
           if ($start -lt 0 -or $finish -lt $start) { throw 'FIXTURE_UI_ANCHOR' }
           # The sole policy seam: console detection and Read-Host. All operational functions stay exact.
           $testText = $originalText.Remove($start,$finish-$start).Insert($start,'$interactive = -not $NonInteractive')
           $testText = $testText.Replace('Read-Host ', 'Read-FixtureConfirmation ')
           Write-FixtureText (Join-Path $template "scripts\owner_$operation.ps1") $testText
       }
       [void](Invoke-FixtureSetupGit @('-C',$template,'add','--','.'))
       [void](Invoke-FixtureSetupGit @('-C',$template,'commit','--quiet','-m','Fixture source main and explicit endpoints'))
       $base = (Invoke-FixtureSetupGit @('-C',$template,'rev-parse','HEAD')).Trim()
       [void](Invoke-FixtureSetupGit @('-C',$template,'checkout','--quiet','-b','candidate'))
       Write-FixtureText (Join-Path $template 'candidate.txt') 'Independent synthetic candidate'
       [void](Invoke-FixtureSetupGit @('-C',$template,'add','--','candidate.txt'))
       [void](Invoke-FixtureSetupGit @('-C',$template,'commit','--quiet','-m','Fixture candidate'))
       $candidate = (Invoke-FixtureSetupGit @('-C',$template,'rev-parse','HEAD')).Trim()
       [void](Invoke-FixtureSetupGit @('-C',$template,'branch','orvion-preflight',$candidate))
       [void](Invoke-FixtureSetupGit @('-C',$template,'checkout','--quiet','main'))
       foreach ($operation in @('PUBLISH','PROMOTE')) {
           $modes = @('success','noninteractive','cancel','bad-sha','source-dirty','source-branch','source-origin','source-stale','source-account','source-helper-missing','source-helper-extra','source-helper-no-reset','native-fail','zero-no-done','duplicate-done','contradictory','blocked-and-done','unreadable-and-done','cross-operation','unknown-verdict','wrong-ref')
           if ($operation -eq 'PUBLISH') { $modes += @('candidate-dirty','candidate-origin','candidate-head','missing-receipt','candidate-account','candidate-helper-missing') }
           else { $modes += 'preflight-mismatch' }
           foreach ($mode in $modes) {
               if ($CaseNames.Count -and $mode -notin $CaseNames) { continue }
               $casePath = Join-Path $work ($product.Key+'-'+$operation.ToLowerInvariant()+'-'+$mode)
               $bare = Join-Path $casePath 'remote.git'
               $sourceRoot = Join-Path $casePath 'trusted main'
               $candidateRoot = Join-Path $casePath 'candidate root'
               [void][IO.Directory]::CreateDirectory($casePath)
               [void](Invoke-FixtureSetupGit @('clone','--quiet','--bare','--no-local',$template,$bare))
               if ($mode -eq 'preflight-mismatch') { [void](Invoke-FixtureSetupGit @('-C',$bare,'update-ref','refs/heads/orvion-preflight',$base)) }
               [void](Invoke-FixtureSetupGit @('clone','--quiet','--no-local','-b','main',$bare,$sourceRoot))
               [void](Invoke-FixtureSetupGit @('clone','--quiet','--no-local','-b','candidate',$bare,$candidateRoot))
               foreach ($fixtureRoot in @($sourceRoot,$candidateRoot)) {
                   [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'remote','set-url','origin',('https://github.com/'+$product.Repository)))
                   [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','protocol.https.allow','never'))
                   [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','protocol.ssh.allow','never'))
                   [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','gc.auto','0'))
                   [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','--local','--add','credential.https://github.com.helper',''))
                   [void](Invoke-FixtureSetupGit @('-C',$fixtureRoot,'config','--local','--add','credential.https://github.com.helper',('!gh auth token --user '+($product.Repository -split '/')[0])))
               }
               if ($mode -eq 'success' -and $operation -eq 'PUBLISH') {
                   $prohibited = @(& $gitExe -C $sourceRoot ls-remote origin refs/heads/main 2>&1)
                   $prohibitedExit = $LASTEXITCODE
                   Write-FixtureText (Join-Path $casePath 'protocol-refusal.log') ($prohibited -join "`n")
                   if ($prohibitedExit -eq 0 -or ($prohibited -join "`n") -notmatch "transport 'https' not allowed") { throw 'FIXTURE_NETWORK_BAN_NOT_PROVEN' }
               }
               Write-FixtureText (Join-Path $candidateRoot ".orvion-certifications\$candidate.json") '{}'
               $selected = $candidate
               switch ($mode) {
                   'bad-sha' { $selected = 'bad' }
                   'source-dirty' { Write-FixtureText (Join-Path $sourceRoot 'dirt.txt') 'untracked' }
                   'source-branch' { [void](Invoke-FixtureSetupGit @('-C',$sourceRoot,'checkout','--quiet','candidate')) }
                   'source-origin' { [void](Invoke-FixtureSetupGit @('-C',$sourceRoot,'remote','set-url','origin','https://github.com/fixture/wrong')) }
                   'source-stale' { [void](Invoke-FixtureSetupGit @('-C',$bare,'update-ref','refs/heads/main',$candidate)) }
                   'candidate-dirty' { Write-FixtureText (Join-Path $candidateRoot 'dirt.txt') 'untracked' }
                   'candidate-origin' { [void](Invoke-FixtureSetupGit @('-C',$candidateRoot,'remote','set-url','origin','https://github.com/fixture/wrong')) }
                   'candidate-head' { $selected = $base }
                   { $_ -in @('source-account','candidate-account','source-helper-no-reset','source-helper-missing','candidate-helper-missing') } {
                       $routingRoot = if ($mode -like 'source-*') { $sourceRoot } else { $candidateRoot }
                       [void](Invoke-FixtureSetupGit @('-C',$routingRoot,'config','--local','--unset-all','credential.https://github.com.helper'))
                       if ($mode -like '*account') {
                           [void](Invoke-FixtureSetupGit @('-C',$routingRoot,'config','--local','--add','credential.https://github.com.helper',''))
                           [void](Invoke-FixtureSetupGit @('-C',$routingRoot,'config','--local','--add','credential.https://github.com.helper','!gh auth token --user FixtureWrongAccount'))
                       } elseif ($mode -eq 'source-helper-no-reset') {
                           [void](Invoke-FixtureSetupGit @('-C',$routingRoot,'config','--local','--add','credential.https://github.com.helper',('!gh auth token --user '+($product.Repository -split '/')[0])))
                       }
                   }
                   'source-helper-extra' { [void](Invoke-FixtureSetupGit @('-C',$sourceRoot,'config','--local','--add','credential.https://github.com.helper','!fixture-helper-never-executed')) }
                   'missing-receipt' {
                       # Move one known fixture file, never recursive cleanup of a computed target.
                       Move-Item -LiteralPath (Join-Path $candidateRoot ".orvion-certifications\$candidate.json") -Destination (Join-Path $casePath 'held-fixture-receipt.json')
                   }
                   'preflight-mismatch' { } # Established before cloning; do not manufacture a non-fast-forward fetch error.
               }
               $fileName = 'owner_'+$operation.ToLowerInvariant()+$(if($mode-eq'noninteractive'){'.original'}else{''})+'.ps1'
               $config = [ordered]@{Mode=$mode;Operation=$operation;Source=$sourceRoot;Root=$candidateRoot;Bare=$bare;GitExe=$gitExe;Base=$base;Candidate=$candidate;Selected=$selected;Interface=(Join-Path $sourceRoot "scripts\$fileName");NativeCall=(Join-Path $casePath 'native-call.json');Transport=(Join-Path $casePath 'transport.log');Evidence=(Join-Path $casePath 'operation-evidence')}
               $configPath = Join-Path $casePath 'config.json'
               Write-FixtureText $configPath ($config | ConvertTo-Json)
               $lines = @(& pwsh -NoProfile -File $driverPath -Config $configPath 2>&1)
               $code = $LASTEXITCODE
               Write-FixtureText (Join-Path $casePath 'actual.log') (($lines | ForEach-Object{"$_"}) -join "`n")
               $evidenceFiles = @(Get-ChildItem -LiteralPath $config.Evidence -Filter '*.json' -ErrorAction SilentlyContinue)
               $record = if ($evidenceFiles.Count -eq 1) { Get-Content -Raw -LiteralPath $evidenceFiles[0].FullName | ConvertFrom-Json } else { $null }
               $native = if (Test-Path -LiteralPath $config.NativeCall) { Get-Content -Raw -LiteralPath $config.NativeCall | ConvertFrom-Json } else { $null }
               $expectsNative = $mode -in @('success','native-fail','zero-no-done','duplicate-done','contradictory','blocked-and-done','unreadable-and-done','cross-operation','unknown-verdict','wrong-ref')
               $ok = $null -ne $record -and ($null -ne $native) -eq $expectsNative
               $reason = ''
               if ($mode -eq 'success') {
                   $expectedScript = Join-Path $sourceRoot ('scripts\'+$(if($operation-eq'PUBLISH'){'publish_candidate'}else{'promote_main'})+'.ps1')
                   $ok = $ok -and $code -eq 0 -and $record.result -ceq 'DONE' -and $native.Script -ieq $expectedScript
                   if ($operation -eq 'PUBLISH') { $ok = $ok -and $native.Root -ieq $candidateRoot -and !$native.Candidate }
                   else { $ok = $ok -and $native.Candidate -ceq $candidate -and !$native.Root }
               } else {
                   $ok = $ok -and $code -ne 0 -and $record.result -cne 'DONE' -and !@($lines|Where-Object{"$_"-ceq"${operation}: DONE"}).Count
                   if ($mode -eq 'noninteractive') { $ok = $ok -and $record.classification -ceq 'INTERACTIVE_CONFIRMATION_REQUIRED' -and !(Test-Path -LiteralPath $config.Transport) }
                   if ($mode -eq 'cancel') { $ok = $ok -and $code -eq 2 -and $record.result -ceq 'CANCELLED' }
                   if ($mode -eq 'native-fail') { $ok = $ok -and $code -eq 7 }
                   $reasonPattern = switch ($mode) {
                       'bad-sha' { 'full 40-character hexadecimal SHA' }
                       'source-dirty' { 'clean trusted main checkout' }
                       'source-branch' { 'clean trusted main checkout' }
                       'source-origin' { 'Wrong trusted source repository' }
                       'source-stale' { 'no automatic fast-forward' }
                       { $_ -in @('source-account','source-helper-extra','source-helper-no-reset') } { 'Trusted source credential routing is not pinned' }
                       'source-helper-missing' { 'Trusted source Git read failed' }
                       'candidate-dirty' { 'Original checkout is dirty' }
                       'candidate-origin' { 'fetch/push destination' }
                       'candidate-head' { 'Original HEAD is' }
                       'candidate-account' { 'Candidate credential routing is not pinned' }
                       'candidate-helper-missing' { 'Git read failed: config' }
                       'missing-receipt' { 'exact-SHA certification record is missing' }
                       'preflight-mismatch' { 'Current preflight does not match' }
                       'wrong-ref' { 'Remote (preflight|main) does not match' }
                       { $_ -in @('zero-no-done','duplicate-done','contradictory','blocked-and-done','unreadable-and-done','cross-operation','unknown-verdict') } { 'one unambiguous DONE' }
                       default { '' }
                   }
                   if ($reasonPattern) { $ok = $ok -and (($lines -join "`n") -match $reasonPattern) }
               }
               if (!$ok) { $reason = ($lines | ForEach-Object{"$_"}) -join "`n" }
               $records.Add([pscustomobject]@{Product=$product.Key;Operation=$operation;Case=$mode;Passed=[bool]$ok;Exit=$code;Result=$record.result;Classification=$record.classification;NativeCalled=($null-ne$native);Fixture=$casePath;Failure=$reason})
               Write-Host ("{0} {1}/{2}/{3}: exit{4} {5}" -f $(if($ok){'PASS'}else{'FAIL'}),$product.Key,$operation,$mode,$code,$record.result)
               if ($MaxCases -gt 0 -and $records.Count -ge $MaxCases) { break Products }
           }
       }
   }
   $failed = @($records | Where-Object {!$_.Passed}).Count
   $result = [ordered]@{Passed=$records.Count-$failed;Failed=$failed;Cases=$records;ProofBoundary='Actual adapter child execution; unmodified noninteractive refusal; explicit console/transport seams for positive/operational routes. All remotes are owned fixture bare repositories; HTTPS/SSH prohibited. Stub endpoints prove binding/verdict/ref handling, not native certification, authenticated actor identity, real publication or promotion.'}
   Write-FixtureText $output (($result | ConvertTo-Json -Depth 8)+"`n")
   "B4_INTERFACES: $($records.Count-$failed) passed, $failed failed; fixture root: $work (retained on failure)"
   if ($failed -eq 0) {
       $resolvedWork=[IO.Path]::GetFullPath($work)
       $temporaryParent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
       if ((Split-Path $resolvedWork -Parent) -ine $temporaryParent -or (Split-Path $resolvedWork -Leaf) -notmatch '^orvion-owner-interfaces-[0-9a-f]{32}$') { throw 'UNSAFE_FIXTURE_CLEANUP' }
       Remove-Item -LiteralPath $resolvedWork -Recurse -Force -ErrorAction Stop
   } else { Write-Host "Failed fixture root: $work (retained on failure)" }
   exit [int]($failed -gt 0)
   ```

   The resulting file's Git blob is e8fb155bcadc567a2ab0dd3d7707691de5bc504a.

13. Check whether `scripts/watch_run.ps1` contains `$script:ResultRx = '(^(PASS|FAILED|SKIPPED?): .*|^\s*[A-Z][A-Z0-9_-]*(?: [A-Z0-9_-]+)*: (CLEAN|READY|PASSED|COMPLETE|DONE|PENDING|UNPROVEN|FAILED|BLOCKED|INCOMPLETE|RECOVERY_EXHAUSTED|UNREADABLE|NOT [A-Z]+|\d+ issue).*|^\s+[A-Z][A-Z0-9-]*(?: [A-Z0-9-]+)+: .*|^(CODE|EVIDENCE): (?!none\b).*|^\s*FAIL\b.*|\b\d+ passed, \d+ failed\b|\bnot ok\b|\bERROR:.*|ALL CHECKS PASSED|\bKILLED\b|\bSURVIVED\b|^END exit=\d+|^TIME: .*)'`; if so record Already Applied when its Git blob is ed8d956b9f2e8ebeacf1942b68424e452773641b, and otherwise stop and report. Otherwise make exactly these 9 edits (Contract B bounded repository-local repair or optional adapter), each matched once, and change nothing else:

   a) replace the line
   ```text
   $script:ResultRx = '(^(PASS|FAILED|SKIPPED?): .*|^\s*[A-Z][A-Z0-9_-]*(?: [A-Z0-9_-]+)*: (CLEAN|READY|PASSED|COMPLETE|DONE|PENDING|UNPROVEN|FAILED|BLOCKED|INCOMPLETE|RECOVERY_EXHAUSTED|NOT [A-Z]+|\d+ issue).*|^\s+[A-Z][A-Z0-9-]*(?: [A-Z0-9-]+)+: .*|^(CODE|EVIDENCE): (?!none\b).*|^\s*FAIL\b.*|\b\d+ passed, \d+ failed\b|\bnot ok\b|\bERROR:.*|ALL CHECKS PASSED|\bKILLED\b|\bSURVIVED\b|^END exit=\d+|^TIME: .*)'
   ```
   with
   ```text
   $script:ResultRx = '(^(PASS|FAILED|SKIPPED?): .*|^\s*[A-Z][A-Z0-9_-]*(?: [A-Z0-9_-]+)*: (CLEAN|READY|PASSED|COMPLETE|DONE|PENDING|UNPROVEN|FAILED|BLOCKED|INCOMPLETE|RECOVERY_EXHAUSTED|UNREADABLE|NOT [A-Z]+|\d+ issue).*|^\s+[A-Z][A-Z0-9-]*(?: [A-Z0-9-]+)+: .*|^(CODE|EVIDENCE): (?!none\b).*|^\s*FAIL\b.*|\b\d+ passed, \d+ failed\b|\bnot ok\b|\bERROR:.*|ALL CHECKS PASSED|\bKILLED\b|\bSURVIVED\b|^END exit=\d+|^TIME: .*)'
   ```

   b) replace the lines
   ```text
   function Get-Eta([object[]]$History, [string]$Key, [double]$Since, [double]$Now) {
       $left = @(foreach ($h in (Get-Recent $History 10)) {
           if ($Key) { $s = $h.Index[$Key]; if ($s) { $h.Total - $s.T - $Since } } else { $h.Total - $Now }
       })
       # A step the history has not seen yet (a new test) falls back to the runs' totals, under the same rule.
       if ($left.Count -lt 2 -and $Key) { return Get-Eta $History '' $Since $Now }
   ```
   with
   ```text
   function Get-Eta([object[]]$History, [string]$Key, [double]$Since, [double]$Now, [int]$TestCount = 0) {
       $byCount = $TestCount -gt 0 -and (Test-TestLine $Key)
       $countLabel = ''
       if ($byCount) {
           $samples = @(foreach ($h in (Get-Recent $History 10)) {
               $testRows = @($h.Steps | Where-Object Kind -eq 'test')
               if ($testRows.Count -ge $TestCount) {
                   $s = $testRows[$TestCount - 1]
                   if ($s.Key -ceq $Key) { [pscustomobject]@{ Count = $testRows.Count; Left = $h.Total - $s.T - $Since } }
               }
           })
           if ($samples.Count -lt 2) { return "eta: none - $($samples.Count) comparable successful run(s) at observed test count $TestCount" }
           $totals = @($samples | ForEach-Object { $_.Count } | Sort-Object -Unique)
           if ($totals.Count -ne 1) { return 'eta: none - incompatible historical test totals at this observed test count' }
           $left = @($samples | ForEach-Object { $_.Left })
           $countLabel = ", by observed test count $TestCount (historical total $($totals[0]) tests)"
       } else {
           $left = @(foreach ($h in (Get-Recent $History 10)) {
               if ($Key) { $s = $h.Index[$Key]; if ($s) { $h.Total - $s.T - $Since } } else { $h.Total - $Now }
           })
           # Non-test stages retain the existing measured step/total fallback; tests never guess a count match.
           if ($left.Count -lt 2 -and $Key) { return Get-Eta $History '' $Since $Now }
       }
   ```

   c) replace the line
   ```text
       'eta: ~{0:N1} min left (median of {1} comparable successful runs{5}{4}; range {2:N1} to {3:N1})' -f [Math]::Max(0, (Get-Median $s)), $s.Count, [Math]::Max(0, $s[0]), [Math]::Max(0, $s[-1]), $(if ($s.Count -lt 5) { ', low sample' }), $(if (-not $Key) { ', by run totals' })
   ```
   with
   ```text
       'eta: ~{0:N1} min left (median of {1} comparable successful runs{5}{4}; range {2:N1} to {3:N1})' -f [Math]::Max(0, (Get-Median $s)), $s.Count, [Math]::Max(0, $s[0]), [Math]::Max(0, $s[-1]), $(if ($s.Count -lt 5) { ', low sample' }), $(if ($byCount) { $countLabel } elseif (-not $Key) { ', by run totals' })
   ```

   d) replace the line
   ```text
       if ($lines.Count) { $t = [double]::Parse($lines[-1].Groups['t'].Value, [Globalization.CultureInfo]::InvariantCulture); Get-Eta $hist (Get-StepKey $lines[-1].Groups['body'].Value) ($now - $t) $now } else { Get-Eta $hist '' 0 $now }
   ```
   with
   ```text
       if ($lines.Count) { $t = [double]::Parse($lines[-1].Groups['t'].Value, [Globalization.CultureInfo]::InvariantCulture); Get-Eta $hist (Get-StepKey $lines[-1].Groups['body'].Value) ($now - $t) $now (@($lines | Where-Object { Test-TestLine $_.Groups['body'].Value }).Count) } else { Get-Eta $hist '' 0 $now }
   ```

   e) replace the line
   ```text
   $seen = 0; $last = 0.0; $prevLine = 0.0; $tests = 0; $results = 0; $failed = 0; $lastProgress = 0.0; $quiet = [Diagnostics.Stopwatch]::StartNew()
   ```
   with
   ```text
   $replaying = $true; $seen = 0; $last = 0.0; $prevLine = 0.0; $tests = 0; $results = 0; $failed = 0; $lastProgress = 0.0; $quiet = [Diagnostics.Stopwatch]::StartNew()
   ```

   f) replace the line
   ```text
               if ($Brief -and $t - $lastProgress -ge $ProgressMinutes) {
   ```
   with
   ```text
               if ($Brief -and ((-not $replaying -and $t - $lastProgress -ge $ProgressMinutes) -or ($replaying -and $body -match '^END exit='))) {
   ```

   g) replace the line
   ```text
                   'progress: {0:N1} min - {1} tests and {2} results so far, {3} failing; {4}' -f $t, $tests, $results, $failed, (Get-Eta $history $lastKey ($now - $t) $now)
   ```
   with
   ```text
                   'progress: {0:N1} min - {1} tests and {2} results so far, {3} failing; {4}' -f $t, $tests, $results, $failed, (Get-Eta $history $lastKey ($now - $t) $now $tests)
   ```

   h) immediately after the lines
   ```text
                   exit [int]($body -notmatch '^END exit=0\b')
               }
           }
   ```
   insert
   ```text
           if($replaying){
               if($Brief-and$prevLine-$lastProgress-ge$ProgressMinutes){
                   $lastProgress=$prevLine;$now=((Get-Date)-$start.At).TotalMinutes
                   'progress: {0:N1} min - {1} tests and {2} results so far, {3} failing; {4}' -f $prevLine,$tests,$results,$failed,(Get-Eta $history $lastKey ($now-$prevLine) $now $tests)
               }
               $lastProgress=$prevLine;$replaying=$false
           }
   ```

   i) replace the line
   ```text
           'heartbeat: no new output for {0:N1} min (last result at {1:N1} min) - {2}; {3}' -f $quiet.Elapsed.TotalMinutes, $last, (Get-RunningStage $start.Pid), (Get-Eta $history $lastKey ($now - $prevLine) $now)
   ```
   with
   ```text
           'heartbeat: no new output for {0:N1} min (last result at {1:N1} min) - {2}; {3}' -f $quiet.Elapsed.TotalMinutes, $last, (Get-RunningStage $start.Pid), (Get-Eta $history $lastKey ($now - $prevLine) $now $tests)
   ```

   The resulting file's Git blob is ed8d956b9f2e8ebeacf1942b68424e452773641b.

14. Check whether `scripts/watch_selftest.ps1` contains `function Case-CountEta([string]$WatcherPath) {`; if so record Already Applied when its Git blob is e0121cf17ab38a0cfa77fc706f35c01d0ac1416f, and otherwise stop and report. Otherwise make exactly these 5 edits (Contract B bounded repository-local repair or optional adapter), each matched once, and change nothing else:

   a) immediately after the line
   ```text
   # Successful runs only, the median of what each still had to do, its range, and no estimate from one run.
   ```
   insert
   ```text
   function Case-CountEta([string]$WatcherPath) {
       . $WatcherPath
       $history = @(foreach ($date in 'a','b') {
           $steps = @([pscustomobject]@{Kind='test';Key='PASS 1 repeated';T=1.0},[pscustomobject]@{Kind='test';Key='PASS 1 repeated';T=6.0},[pscustomobject]@{Kind='test';Key='PASS 3 final';T=10.0})
           [pscustomobject]@{Date=$date;Ok=$true;Total=15.0;Steps=$steps;Index=@{'PASS 1 repeated'=$steps[0];'PASS 3 final'=$steps[2]}}
       })
       $second = Get-Eta $history 'PASS 1 repeated' 0 6 2
       $third = Get-Eta $history 'PASS 3 final' 0 10 3
       $one = Get-Eta @($history[0]) 'PASS 1 repeated' 0 6 2
       $missing = Get-Eta $history 'PASS 9 changed' 0 6 2
       $beyond = Get-Eta $history 'PASS 1 repeated' 0 6 4
       $failed = Get-Eta @($history[0],[pscustomobject]@{Date='f';Ok=$false;Total=15;Steps=$history[1].Steps;Index=$history[1].Index}) 'PASS 1 repeated' 0 6 2
       $variant = [pscustomobject]@{Date='v';Ok=$true;Total=17;Steps=@($history[1].Steps)+@([pscustomobject]@{Kind='test';Key='PASS 4 added';T=12});Index=$history[1].Index}
       $mixed = Get-Eta @($history[0],$variant) 'PASS 1 repeated' 0 6 2
       $ok = $second -match '^eta: ~9[.,]0 min left' -and $second -match 'observed test count 2 \(historical total 3 tests\)' -and $third -match '^eta: ~5[.,]0 min left' -and $one -match '^eta: none' -and $missing -match '^eta: none' -and $beyond -match '^eta: none' -and $failed -match '^eta: none' -and $mixed -match '^eta: none - incompatible'
       [pscustomobject]@{Ok=$ok;Detail="second=[$second] third=[$third] one=[$one] missing=[$missing] beyond=[$beyond] failed=[$failed] mixed=[$mixed]"}
   }
   function Case-CountEtaCaller([string]$WatcherPath) {
       $log=New-Name '.log';$csv=New-Name '.csv'
       $startAt=(Get-Date).AddMinutes(-6)
       $lines=@(('['+$startAt.ToString('yyyy-MM-dd HH:mm:ss')+"] START pid=$PID host=fixture | synthetic count fixture"),'[+   1.000 min] PASS 1 repeated','[+   6.000 min] PASS 1 repeated')
       [IO.File]::WriteAllLines($log,$lines)
       $rows=@(foreach($date in 'a','b'){Rows 'count-eta' $date @(@('PASS 1 repeated',1,1),@('PASS 1 repeated',6,5),@('PASS 3 final',10,4),@('END exit=0 total=15.0 min',15,5))})
       $rows|Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding utf8
       $output=@(& pwsh -NoProfile -File $WatcherPath -Log $log -Run 'count-eta' -Csv $csv -Eta 2>&1);$code=$LASTEXITCODE
       [pscustomobject]@{Ok=($code-eq0-and($output-join' ')-match'^eta: ~9[.,]0 min left.*observed test count 2');Detail="exit=$code $($output-join' | ')"}
   }
   ```

   b) immediately after the line
   ```text
   # -Brief prints what needs attention and a progress line; the history still receives everything.
   ```
   insert
   ```text
   function Case-LateBrief([string]$WatcherPath) {
       $log=New-Name '.log';$csv=New-Name '.csv';$out=New-Name '.out'
       $at=(Get-Date).AddMinutes(-51).ToString('yyyy-MM-dd HH:mm:ss')
       $lines=[Collections.Generic.List[string]]::new()
       $lines.Add("[$at] START pid=$PID host=fixture pwsh=fixture cpus=1 head=fixture concurrent=0 | fixture")
       foreach($i in 1..1000){$t=($i/20.0).ToString('0.000',[Globalization.CultureInfo]::InvariantCulture);$lines.Add("[+ $t min] PASS historical-$i fixture")}
       $lines.Add('[+ 50.100 min] REMOTE_CERTIFY: UNREADABLE')
       $lines.Add('[+ 50.200 min] END exit=2 total=50.2 min')
       [IO.File]::WriteAllLines($log,$lines)
       $w=Start-Pwsh ('-File {0} -Log {1} -Run late-brief -PollSeconds 1 -Csv {2} -Brief -ProgressMinutes 2' -f (Q $WatcherPath),(Q $log),(Q $csv)) $out
       $done=Wait-Exit $w 30
       $o=@(Get-Content -LiteralPath $out);$rows=@(Import-Csv -LiteralPath $csv)
       $progress=@($o|Where-Object{$_-match'^progress:'}).Count
       $testRows=@($rows|Where-Object{$_.step-like'PASS historical-*'}).Count
       $ok=$done-and$w.ExitCode-eq1-and$progress-eq1-and$testRows-eq1000-and@($o|Where-Object{$_-match'\] PASS historical-'}).Count-eq0-and@($o|Where-Object{$_-match'END exit=2'}).Count-ge1
       $unreadable=$done-and@($o|Where-Object{$_-match'REMOTE_CERTIFY: UNREADABLE'}).Count-eq1-and@($rows|Where-Object{$_.step-ceq'REMOTE_CERTIFY: UNREADABLE'}).Count-eq1
       [pscustomobject]@{Ok=$ok;Unreadable=$unreadable;Detail="done=$done exit=$($w.ExitCode) progress=$progress history_tests=$testRows unreadable=$unreadable"}
   }
   ```

   c) immediately after the line
   ```text
       $c = Case-Eta $Watcher;          Check 'W9 an ETA is the median of what comparable successful runs still had to do, with its range; a new step falls back to run totals; one run gives none; an ended run says so' $c.Ok $c.Detail
   ```
   insert
   ```text
       $c = Case-CountEta $Watcher; Check 'W38 ETA uses observed test ordinal and compatible known historical totals; insufficient/incompatible evidence gives none' $c.Ok $c.Detail
       $c = Case-CountEtaCaller $Watcher; Check 'W39 actual -Eta caller passes its observed test count for repeated keys' $c.Ok $c.Detail
   ```

   d) immediately after the line
   ```text
       $c = Case-Tests $Runner $Watcher; Check 'W15 every test line, failed ones included, and every evaluator stage is recorded with its own time at 0.06 s resolution; only failed tests are printed; a TIME line keeps its stated duration' $c.Ok $c.Detail
   ```
   insert
   ```text
       $c = Case-LateBrief $Watcher; Check 'W36 late Brief attach prints one progress line while retaining all historical tests' $c.Ok $c.Detail
       Check 'W37 UNREADABLE remains visible and recorded as its literal verdict' $c.Unreadable $c.Detail
   ```

   e) replace the line
   ```text
           @{ Name = 'M35 concurrent runs share one resource file'; File = $Runner; Find = '$resources = "$Log.resources.csv"'; Replace = '$resources = Join-Path ([IO.Path]::GetTempPath()) ''orvion-resources.csv'''; Case = { param($p) Case-ResourcesConcurrent $p } }
   ```
   with
   ```text
           @{ Name = 'M35 concurrent runs share one resource file'; File = $Runner; Find = '$resources = "$Log.resources.csv"'; Replace = '$resources = Join-Path ([IO.Path]::GetTempPath()) ''orvion-resources.csv'''; Case = { param($p) Case-ResourcesConcurrent $p } },
           @{ Name = 'M38 repeated test ordinal ignored'; File = $Watcher; Find = '$s = $testRows[$TestCount - 1]'; Replace = '$s = $testRows[0]'; Case = { param($p) Case-CountEta $p } },
           @{ Name = 'M39 incompatible historical test totals accepted'; File = $Watcher; Find = 'if ($totals.Count -ne 1)'; Replace = 'if ($false)'; Case = { param($p) Case-CountEta $p } },
           @{ Name = 'M40 actual ETA caller drops observed test count'; File = $Watcher; Find = ' (@($lines | Where-Object { Test-TestLine $_.Groups[''body''].Value }).Count)'; Replace = ' 0'; Case = { param($p) Case-CountEtaCaller $p } },
           @{ Name = 'M36 UNREADABLE verdict dropped'; File = $Watcher; Find = '|UNREADABLE|'; Replace = '|'; Case = { param($p) $v=Case-LateBrief $p;[pscustomobject]@{Ok=$v.Unreadable;Detail=$v.Detail} } },
           @{ Name = 'M37 historical Brief progress floods'; File = $Watcher; Find = '            if ($Brief -and ((-not $replaying -and $t - $lastProgress -ge $ProgressMinutes) -or ($replaying -and $body -match ''^END exit=''))) {'; Replace = '            if ($Brief -and $t - $lastProgress -ge $ProgressMinutes) {'; Case = { param($p) Case-LateBrief $p } }
   ```

   The resulting file's Git blob is e0121cf17ab38a0cfa77fc706f35c01d0ac1416f.

15. Verify that the active contract contains the exact line Resume Step: DONE and generated artifacts pass their owning freshness check; if so record Already Applied only when all payload blobs match. Otherwise retain this contract's exact wording, synchronize only its allowed runtime sections, run scripts/generate-ai-map.ps1 to regenerate ai-map.json and repository-index.md, verify scope, and commit the In Progress implementation with Resume Step: DONE. Do not run a profile or Additional Verification command here; the later authorized native timed/watched Finish owns those commands.

## Acceptance Criteria

- [ ] Exact selected payload for `AGENTS.md`; check: blob AGENTS.md 708b72b2eada57e532cc5cc3be3115c1a5731b89
- [ ] Exact selected payload for `scripts/agent/apply-draft-steps.ps1`; check: blob scripts/agent/apply-draft-steps.ps1 523463176334e939c972d0393ad2d0696e40701a
- [ ] Exact selected payload for `scripts/agent/Invoke-DraftSteps.ps1`; check: blob scripts/agent/Invoke-DraftSteps.ps1 61621cca3e081e3a786e19c168e44d05bae3253f
- [ ] Exact selected payload for `scripts/agent/test-draft-steps.ps1`; check: blob scripts/agent/test-draft-steps.ps1 8aefb21e60d7aef7b8429ada3ec89289f1bb01c5
- [ ] Exact selected payload for `scripts/agent/Test-ScriptHazards.ps1`; check: blob scripts/agent/Test-ScriptHazards.ps1 24e364f49a1bc825afcb51fc906bd0eb83a7912d
- [ ] Exact selected payload for `scripts/check_agent_continuity.ps1`; check: blob scripts/check_agent_continuity.ps1 3c0a09d3622529fd9c2d5e66f5f29a1548bdf92f
- [ ] Exact selected payload for `scripts/github_public_read.ps1`; check: blob scripts/github_public_read.ps1 6493a2f5cbf8f65f4e479b0c172e30b1f3521cae
- [ ] Exact selected payload for `scripts/owner_promote.ps1`; check: blob scripts/owner_promote.ps1 47aaa9eb76e5cec86dc4eab8f158050e520e71c0
- [ ] Exact selected payload for `scripts/owner_publish.ps1`; check: blob scripts/owner_publish.ps1 da783193f728d1a99cbda1431d03fdb57dc24f34
- [ ] Exact selected payload for `scripts/test_agent_continuity.ps1`; check: blob scripts/test_agent_continuity.ps1 0bf297c9db4f39b8b9297b0af02a3a812ce3e427
- [ ] Exact selected payload for `scripts/test_github_public_read.ps1`; check: blob scripts/test_github_public_read.ps1 e7f65ceebfc7f15fb96d4b46150ca0d8d26e6792
- [ ] Exact selected payload for `scripts/test_owner_interfaces.ps1`; check: blob scripts/test_owner_interfaces.ps1 e8fb155bcadc567a2ab0dd3d7707691de5bc504a
- [ ] Exact selected payload for `scripts/watch_run.ps1`; check: blob scripts/watch_run.ps1 ed8d956b9f2e8ebeacf1942b68424e452773641b
- [ ] Exact selected payload for `scripts/watch_selftest.ps1`; check: blob scripts/watch_selftest.ps1 e0121cf17ab38a0cfa77fc706f35c01d0ac1416f
- [ ] README is preserved byte-for-byte in Git; check: same README.md @4f9f15d9c5e55771daed2fe36ac960fb1ba4eeba
- [ ] Native profile derivation, hooks, CI and release engines retain their baseline behavior; independent live Review verifies the bounded source diff and unchanged out-of-scope paths.
- [ ] Native generated-artifact freshness and scope checks pass; there is one legal active contract pointer during execution and none at Complete.
- [ ] Fresh authorized native timed/watched Finish succeeds, all required evidence is read, independent Review confirms completion and candidate binding passes. Remote acceptance is later evidence, never an assertion supplied by this local criterion.

## Review Gate

- [ ] Exact approved Draft bytes, baseline, source anchors, literal payloads and write closure match the companion sealed packet.
- [ ] Existing read/wait/watcher functionality and independent optional tool discovery remain; no native governance, README, credentials or unrelated work changed.
- [ ] Actual native evidence covers mandatory and Additional Verification, failure output, fresh receipt, scope, generated state and allowed lifecycle transitions.
- [ ] Reversibility and first-release bootstrap are reviewed; publication, promotion and remote certification retain their separate owner boundaries.

## Execution Log

None.

2026-10-22 - Codex applied all fourteen exact frozen Contract B literal file steps using the approved original applier. Each resulting Git-filtered payload blob matches pt/payload.json; Step 15 synchronized this In Progress checkpoint and native generated artifacts. README, native profiles/hooks/CI/release engines remain unchanged. Native timed/watched Finish is the next operation; no test/receipt/release success is inferred from application.


2026-10-22 - Cancel (human command): explicit Owner Contract B Recovery Authorization SHA-256 892E7C1513407B54CE0533E4FDE1FE3193721C11415E5D867D7B3651816CE375 authorizes this In Progress -> Cancelled transition. Circular pre-Complete candidate-binding criterion prevents truthful completion. Approved implementation and successful historical Finish evidence remain intact; this is contract cancellation, not source rollback. No acceptance checkbox is asserted, no receipt is relabelled, and no publication or successor approval is granted.

## Verification Notes

None.

2026-10-22 - Approval Evidence: owner explicitly approved exact Draft SHA-256 FDC13D63B00CEECA78BD251954F4A4C2F8DA3C4823F98B42EB035D83E39BA38E in the preserved Owner Master Execution Directive (SHA-256 564EF32626E0C5456AE7C3DDAD244691D2425AB6F6F6684F708FFA4149A8E873). Local source scope, native verification, Review/Complete and candidate binding only; publication/promotion are not authorized. Recorded by Codex; no cross-repository authority or inherited delegation.

## Notes

Baseline: 4f9f15d9c5e55771daed2fe36ac960fb1ba4eeba. Exact baseline source anchors:

| Path | Existing Git blob |
| --- | --- |
| `AGENTS.md` | `b2412d15cd6fcf710055114fe734ba69178f35cc` |
| `scripts/check_agent_continuity.ps1` | `d5d5b2845e7e5620afca82d9ee08aa9de23b483f` |
| `scripts/github_public_read.ps1` | `97f5c8894e5772e5a46e792aef927c5055e402b2` |
| `scripts/test_agent_continuity.ps1` | `047370a65254ed92ad1c3ec89d4e6ecc2564002d` |
| `scripts/test_github_public_read.ps1` | `df7d4616b6f46c050feede9022fde7897877dffc` |
| `scripts/watch_run.ps1` | `e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b` |
| `scripts/watch_selftest.ps1` | `b0a838b184a3b0b9d0928cb34e474b045624e4de` |

The native completion summary is `Last Completed: **SPEC-293: Contract B repository-local interfaces and reliable observations; locally verified and reviewed. Owner publication/promotion and exact-SHA remote certification follow CR_LIFECYCLE.md section 9. Batch 6 remains ON HOLD. CTRL-19 remains OPEN.**`.

This Draft grants no approval. Owner Gate 1 must name its exact SHA-256. Any later correction requires a new reviewed digest; do not edit a frozen authority or hide partial state. The selected literal applier supports creation; the unrelated generic stage executor is not selected because creation preflight and attribution remain unproven there.
