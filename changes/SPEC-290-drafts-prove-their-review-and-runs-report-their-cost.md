# Change Request — SPEC-290

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make Approval of evidence-applicable work in Platinum require a recorded three-pass Draft assurance, let an Acceptance Criterion check that a path is absent, and make every timed run report the memory and CPU it ran under.

## Business Reason

Three gaps, each measured in this repository at its SPEC-289 candidate on 2026-10-19:

- **Three-pass Draft assurance is a convention, not a check.** The owner made multi-pass Draft assurance a required outcome on 2026-10-15, and the owner's infrastructure programme (ADR-0033, recorded in the Founder repository) lists its enforcement. At the baseline the evaluator has no such predicate: `SPEC-289` and its predecessor recorded their passes in Notes, which nothing reads, and a Draft without them is approved the same way.
- **No criterion can say a file is gone.** The four check kinds (`same`, `has`, `lacks`, `blob`) all need the path to exist, so `SPEC-289`'s criterion that its two retired workflows no longer exist was judged by Review alone, and the Gate reported 4 of 5 criteria verified.
- **Run conditions are guessed.** A control suite was killed by the host at 1.7 GB free on 2026-10-12. On 2026-10-19 two `-Finish` runs ran side by side in 48 minutes each, and their headroom (at least 5.2 GB free; one suite's process tree peaks at about 0.6 GB) was known only from a sampler started by hand outside the repository. The owner asked the same day that this sampling become part of the system for every agent rather than a one-session trick.

## Risks

Low to moderate. The new Approval predicate refuses a future evidence-applicable Draft that carries no Draft Assurance record; that refusal is the purpose, and work the section is not derived for is unaffected. Historical contracts are never re-judged: the evaluator judges a Draft-to-Approved transition only inside a range being admitted. The `absent` kind is additive and no existing criterion changes meaning; it accepts only a canonical repository-relative path (`..`, `.`, absolute, drive, backslash and trailing-slash forms are malformed), and a path is present when Git holds it or anything under it in any letter case, or when it exists on disk, so a case-only rename never reads as a deletion. A criterion never authorizes a write: Write Scope alone does, and `absent` on an existing path outside Write Scope refuses Approval. The runner change only observes: the command's exit code, its stamped lines and the final `END` line are unchanged, and a host without the Windows counters says `RESOURCES: unavailable`. The sampler is a thread of the runner, never a process of its own, so a killed runner leaves nothing behind; each run writes its own `<log>.resources.csv`, which holds only the time, free memory, the run's own working-set total and CPU load, never a command line or process name. The Pass 3 date is judged as Check 12 judges evidence dates: a real calendar day, not after the newest civil date on Earth (UTC+14). A listing Git cannot complete is refused as `CRITERION_CHECK_INDETERMINATE`, never read as absence, so `absent` has three outcomes: absent, present or unknown; it is the only kind for which an unreadable tree could look like success, since every other kind already fails when its read returns nothing. Accepted limits, each stated rather than guarded: in the working tree a dangling symbolic link reads as absent, while every commit-level judgment counts it; and the resource figures are minute samples, not bounds. `scripts/check_agent_continuity.ps1`, `scripts/test_agent_continuity.ps1` and `changes/TEMPLATE.md` are control surfaces, so `-Finish` runs the CONTROL profile (about 45 minutes) plus the runner self-test. This contract's own criteria use no `absent` check, because `main`'s evaluator, which judges this candidate as trusted judge and at Approval, does not know the kind yet. CTRL-19 remains OPEN.

## Supersedes / Depends On

Depends on completed `SPEC-289` and its promotion: this contract's baseline is `main` `b091f0fa002d0d9f4ce9f38713c92cd0dbc6270c`, and `SPEC-289`'s exact-SHA remote certification precedes this contract's `-Finish`. Supersedes nothing.

## Write Scope

- `changes/SPEC-290-drafts-prove-their-review-and-runs-report-their-cost.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_selftest.ps1`
- `ENGINEERING_METHOD.md`
- `changes/TEMPLATE.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/agent-control.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/SECURITY.md`
- `scripts/check_repository_consistency.ps1`
- `scripts/watch_run.ps1`
- `scripts/watch_ci.ps1`
- `scripts/github_public_read.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/batch6_select_target.ps1`
- `.workstation/doctor.ps1`
- `README.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_GAP_REGISTER.md`

No GitHub setting, secret, ruleset, workflow or credential is changed by this contract. Batch 6 is ON HOLD in both repositories by owner decision of 2026-10-18 until the infrastructure programme completes and the owner explicitly authorizes resumption. Not here: the watcher's progress and ETA reporting, the Publish/Promote launchers, Dependabot, and publication or promotion by the agent.

## Required Reading

- `AGENTS.md` §§1–3
- `CR_LIFECYCLE.md` §§4–5,8–9
- `ENGINEERING_METHOD.md` §§1–3
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`: `Get-CriterionChecks`, `Test-CriterionCheck`, `Assert-AssuranceAdmission`, `Evaluate-PreApprovalEvidence`
- `scripts/test_agent_continuity.ps1`: `EvidenceText`, the CHECK family (281-C*) and the population assertion
- `scripts/run_timed.ps1`
- `scripts/watch_selftest.ps1`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- pwsh -NoProfile -File scripts/watch_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

Baseline: `b091f0fa002d0d9f4ce9f38713c92cd0dbc6270c`, the `SPEC-289` candidate, which becomes `main` by exact-SHA promotion. Allocation is derived by the existing allocator from this repository's history (cursor 289; 290 unreserved at the baseline) and is refreshed immediately before the approved Draft is committed.

Source anchors (baseline Git blobs, including read-only consumers):

| Path | Baseline blob |
| --- | --- |
| `scripts/check_agent_continuity.ps1` | `256879e512235b1e8744ea64862dd1e82ce65c6d` |
| `scripts/test_agent_continuity.ps1` | `52934332def1608d6bc12b6ac5847db34f4b37f7` |
| `scripts/run_timed.ps1` | `722ca31e5cd999d7fa968a2fd23ce943cebc37bc` |
| `scripts/watch_selftest.ps1` | `144828ebdc82fa1812ca1971834b277bc9b94b31` |
| `ENGINEERING_METHOD.md` | `6f77b435ac20274f4e5ef7bb4ce47871f0b5e2df` |
| `changes/TEMPLATE.md` | `af91d9bfa47d495bcc100554b821c5388ad8f5cb` |
| `.github/workflows/orvion-acceptance.yml` | `b242e4c7401258404c5d43bffb49c3f53f42467e` |
| `.github/workflows/agent-control.yml` | `41243b7c9a499df4cf011385a046c53107084ba3` |
| `scripts/watch_run.ps1` | `e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b` |
| `scripts/watch_ci.ps1` | `ca87c18d3ac7fa62f70f5df681c5df18cf482699` |
| `scripts/publish_candidate.ps1` | `d168504cc66c3a0759ac3ee9b5e01045a0f46589` |
| `scripts/promote_main.ps1` | `bf64aa893faf9d6be7477254bebf80dca04b4d79` |
| `scripts/check_repository_consistency.ps1` | `3e6d2810e03bfac15b96dba3bc46d119d97ad658` |
| `CR_LIFECYCLE.md` | `a80d15cdf805932623a0a8ea93aaae9740fac870` |
| `GOVERNANCE.md` | `5670c47888bbd6b4194f6c41c54476ee42cb7bdf` |
| `scripts/generate-ai-map.ps1` | `01165b8570999b79de4d6e854cae2443256e6b64` |
| `_ORVION_CANONICAL/manifest.md` | `c92f408b96c0df3da28d99d1db0b14668a21b11f` |
| `ai-map.json` | `b2a10ed5875a25b97a255e7384c172cac11581d5` |
| `repository-index.md` | `d075792a248fc781d7012cc0296fcd8bc15a47d5` |

### Draft Assurance

Pass 1 Design: Version 1 reused the 2026-10-15 design: every Draft version is a commit, the Gate re-judges each one at Approval and requires a review record naming every prior version's SHA; it also added an ETA fix to the watcher and kept resource sampling as its own contract.

Pass 2 Adversarial Review: Version 2 rejected version-commits, because Drafts are committed only at Approval and the range Gate refuses a Draft-only range (NO_GOVERNING_CR), so the 2026-10-15 design can no longer run; prior-version digests stored outside the repository are unverifiable and were rejected; minimum-length rules were rejected as arbitrary and gameable; the watcher ETA change was removed because its measured cause is the run name, not the code (every Finish that day used a per-contract `-Run` name with no history, while `finish-control` has nine), so Step 9 uses `finish-control`; the Gate is held to what it can prove and quality stays the human's Approval decision under CR_LIFECYCLE.md §5; the owner's 2026-10-19 review then required precise `absent` semantics (canonical paths only, no traversal, case and directory bypasses closed), rejection of duplicated, recased, impossible and future-dated assurance records, proof that historical contracts are never re-judged, and runner proof under failure, interruption and concurrency, each now a case with a mutation kill; Version 4 came from an independent review of Version 3 the same day, which found that the template step dropped the existing sentence "A check that can never hold refuses Approval, and every check must hold" and left a parenthesis open (corrected), that a second record or field whose heading differs only in letter case was ignored rather than refused (now refused, DA14, DA15, DAM10, DAM11), that resource figures read as bounds (now stated as minute samples), and confirmed the rest: hook-mode absence matches how every kind judges the working tree, and commits are judged by Git's tree; Version 5 came from the owner's review of Version 4 the same day, which refused the stated limit that a failed Git listing reads as absence: it was reproduced (a missing subtree object stopped `ls-tree` part-way with exit 1, and a path still in the commit held `absent`) and is now refused as indeterminate (AB10, ABM5), a staged deletion still on disk was added as a regression case (AB11), and the template rule was kept because the Gate refuses what it cannot judge without authors reasoning about Git failures.

Pass 3 Evidence Refresh: Re-measured on 2026-10-19 at the baseline: no Draft Assurance predicate exists; `SPEC-289` reported 4 of 5 criteria verified because no kind can state absence; on the final patched trees in disposable clones the control suite passes 585 of 585 (40.8 min) and the runner self-test 62 of 62, and the suite run sampled by the patched runner itself recorded min_free_gb 4.25, peak_tree_mb 544, max_cpu_pct 72; the hardening first judged hook-mode absence from Git's index, which case AB3 refused (a deleted, unstaged file read as present), and it now reads what is on disk, as every other working-tree check does; the independent review re-read every changed line on 2026-10-19 and re-ran the control suite on the Version 4 trees, and again on the Version 5 trees after the listing fix.

Selected Version: Version 5: Draft Assurance and `absent` in the existing evaluator plus resource sampling in the existing runner, grouped because one CONTROL Finish already runs and the runner self-test adds about eight minutes, while a separate contract would cost its own Gate 1, Finish and release.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Approval of evidence-applicable work needs a Draft Assurance record | The pre-commit hook and every range walk judging a Draft-to-Approved transition | WRITE | Cases DA1–DA15 and mutants DAM1–DAM11; work the section is not derived for returns NOT APPLICABLE unchanged (DA6) |
| Contracts approved before this rule | Range walks over later publications | UNAFFECTED | A transition is judged only inside the range being admitted: DA12 refuses an in-range Approval without the record, DA13 admits a range that starts after such an Approval |
| Authors of future Drafts | `changes/TEMPLATE.md`, `ENGINEERING_METHOD.md` | WRITE | The template gains the subsection; the method names the fifth class |
| A criterion may say `check: absent <path>` | `Get-CriterionChecks`, `Test-CriterionCheck`, `Assert-AssuranceAdmission`, the CRITERIA line | WRITE | Cases AB1–AB11 and mutants ABM1–ABM5; existing kinds unchanged |
| This candidate judged by `main`'s evaluator | `-Gate -Trusted`, `scripts/promote_main.ps1` | VERIFY | This contract's criteria use only kinds `main` knows, so the trusted judge parses them |
| The runner's log gains a `RESOURCES:` line before `END` | `scripts/watch_run.ps1`, `-Finish`'s `ORVION_TIMED_LOG` check | VERIFY | Runner self-test 62 of 62 with W20–W22; `END` stays the last line and the exit code is preserved (W0, W20, W21) |
| A `<log>.resources.csv` file beside each log | Log folders and `git status` | UNAFFECTED | It sits beside the log; a log inside the checkout already makes the tree dirty, so logs live outside it |
| Generated projections | `ai-map.json`, `repository-index.md` | VERIFY | The generator changes neither file for these edits; only the lifecycle's active-pointer and Last Completed lines move |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Legal identity and admitted frozen contract | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Evaluator and control suite agree | BEFORE_COMPLETION | 2 | 3 | 9 |
| Runner and its self-test agree | BEFORE_COMPLETION | 4 | 5 | 9 |
| Generated state, scope and contract agree | BEFORE_COMPLETION | 2 | 8 | 9 |

Measured in disposable clones of this repository at the baseline with every edit applied: the full control suite and the runner self-test pass; repository consistency is CLEAN; the generator changes no projection. A lifecycle rehearsal in a disposable clone carrying this checkout's ignored certification state is recorded in the Gate 1 packet. These are preparation measurements; the derived commands run once, in the final timed Finish.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `Evaluate-PreApprovalEvidence` (SPEC-196/198/210) and the criterion checks of `Assert-AssuranceAdmission` (SPEC-281); this contract adds one predicate to the first and one kind to the second, and one observation to the existing timed runner, with no new script, hook or workflow.

Added Property: an evidence-applicable Draft cannot be approved without a filled, three-pass, dated assurance record; a criterion can prove a path is absent; every timed run records the resources it ran under.

Causal Negative: at the baseline a Draft with no assurance record is approved with APPROVAL_EVIDENCE PASS, `check: absent` is refused as CRITERION_CHECK_MALFORMED, and the runner writes no resource evidence.

Positive Test Design: a complete record is admitted (DA5), non-applicable work needs none (DA6) and an Approval before the range is not re-judged (DA13); a removed path holds `absent` in the hook and the range (AB1, AB3); the runner keeps its exit code and END line with sampling on, alone and beside a second run (W0, W20, W21).

Negative Test Design: a missing, placeholder, repeated, recased, undated, impossibly dated, future-dated, field-duplicated or section-duplicated record, including a heading or field name repeated in another letter case, is refused INDETERMINATE (DA1–DA4, DA7–DA11, DA14, DA15), and so is an in-range Approval without one (DA12); a path that still exists, in any letter case or as a directory, fails `absent` (AB2, AB4, AB8, AB9), and so does a staged deletion still on disk in the hook (AB11); a tree Git cannot list is refused INDETERMINATE, never absent (AB10); a non-canonical path is malformed (AB7); `absent` on an existing path outside Write Scope or beside a check needing the path refuses Approval (AB5, AB6); a killed runner claims no END and its sampler stops (W22).

Non-Empty Population Obligation: the DA family and the CHECK family each have accepting, refusing and mutation cases, asserted by the suite's population check.

Mutation Obligation: DAM1–DAM11 remove each Draft Assurance predicate, ABM1–ABM5 each `absent` predicate, M34 the sampler and M35 the per-run resource file; each must be killed.

Post-Implementation Proof Obligation: the full control suites, the runner self-test and the REPOSITORY commands pass in one fresh timed and watched Finish on the final implementation; hosted workflow conclusions on the exact pushed SHA are proven by `-Certify`.

## Implementation Steps

1. Check that the owner's Gate 1 approval names this exact Draft's SHA-256, that remote `main` is `b091f0fa002d0d9f4ce9f38713c92cd0dbc6270c`, and that every source anchor above matches at `HEAD`; if any differs, stop and report without any write. This step writes nothing beyond the allocation and approval commits the owner's command directs.
2. Check whether `scripts/check_agent_continuity.ps1` contains `Assert-DraftAssurance`; if so record Already Applied when its Git blob is f56ec204b19a3628936d28bd02ddceabfbc68384, and otherwise stop and report. Otherwise make exactly these 5 edits (the `absent` check kind (parse, judgment, contradiction) and the Draft Assurance predicate), each matched once, and change nothing else:

   a) immediately after the line
   ```text
                   'blob'{[regex]::Match($a,'^(?<path>[^\s#@"]+)\s+(?<sha>[0-9a-f]{40})$')}
   ```
   insert
   ```text
                   'absent'{[regex]::Match($a,'^(?<path>(?!/)(?!.*//)(?!.*(?:^|/)\.\.?(?:/|$))[^\s#@"\\:]+(?<!/))$')}
   ```

   b) immediately after the line
   ```text
       $where=if($Check.Key){"$($Check.Path)#$($Check.Key)"}else{$Check.Path}
   ```
   insert
   ```text
       # SPEC-289 retired two workflows and no check could say so, so Review alone judged it. A path is
       # present when the judged tree holds it, or anything under it, in any letter case (a case-only
       # rename must not read as a deletion while the file still exists). At a commit that tree is Git's;
       # in the working tree it is what Git knows that is still on disk, plus the path itself on disk.
       if($Check.Kind-eq'absent'){
           $entries=@(if($Ref){git -C $Root ls-tree -r --name-only $Ref 2>$null}else{git -C $Root ls-files --cached --others --exclude-standard 2>$null})
           # A listing Git could not finish proves nothing: a missing object stops ls-tree part-way, and
           # the path read as absent while it was still there. Unknown is refused, never absent.
           if($LASTEXITCODE-ne0){throw "CRITERION_CHECK_INDETERMINATE:$where - Git could not list $(if($Ref){$Ref}else{'the working tree'})"}
           $global:LASTEXITCODE=0
           $hit=@($entries|Where-Object{[string]::Equals($_,$Check.Path,[StringComparison]::OrdinalIgnoreCase)-or$_.StartsWith("$($Check.Path)/",[StringComparison]::OrdinalIgnoreCase)}|Where-Object{$Ref-or(Test-Path -LiteralPath (Join-Path $Root $_))})
           if($hit.Count-or(-not$Ref-and(Test-Path -LiteralPath (Join-Path $Root $Check.Path)))){return "$where exists"}
           return $null
       }
   ```

   c) immediately after the line
   ```text
       foreach($a in $checks){foreach($b in $checks){
   ```
   insert
   ```text
           if($a.Kind-eq'absent'-and$b.Kind-ne'absent'-and$a.Path-eq$b.Path){throw "APPROVAL_EVIDENCE:FAIL:criteria $($a.Item) and $($b.Item) cannot both hold - $($a.Raw) and $($b.Raw)"}
   ```

   d) immediately after the lines
   ```text
         Why='mandatory Check L3 regenerates the API contract from the live surface and byte-compares it'}
   )
   ```
   insert
   ```text
   # THREE-PASS DRAFT ASSURANCE (owner requirement of 2026-10-15). A Draft that reaches a
   # surface this section is derived for is approved only with the record of three distinct passes:
   # the initial design, an adversarial challenge of it, and a dated refresh of the evidence it rests
   # on, plus the version selected. Until now that record lived in Notes by convention and nothing
   # refused its absence. The Gate proves the record exists, is filled and is not one pass restated
   # three times; whether the review was good is the human's Approval decision (CR_LIFECYCLE.md §5).
   $script:DraftAssuranceFields=@('Pass 1 Design','Pass 2 Adversarial Review','Pass 3 Evidence Refresh','Selected Version')
   function Assert-DraftAssurance([string]$Body){
       $n=([regex]::Matches("$Body",'(?mi)^### Draft Assurance\s*$')).Count
       if($n-eq0){throw 'APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance missing'}
       if($n-gt1){throw "APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance appears $n times"}
       $a=SubSection $Body 'Draft Assurance'
       $v=@{}
       foreach($f in $script:DraftAssuranceFields){
           $lines=([regex]::Matches($a,"(?mi)^$([regex]::Escape($f)):")).Count
           if($lines-gt1){throw "APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance field repeated: $f"}
           $v[$f]=EvidenceBody (EvidenceField $a $f)
           if($v[$f]-eq''){throw "APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance field missing: $f"}
       }
       $passes=@('Pass 1 Design','Pass 2 Adversarial Review','Pass 3 Evidence Refresh')|ForEach-Object{($v[$_]-replace'\s+',' ').ToLowerInvariant()}
       if([Collections.Generic.HashSet[string]]::new([string[]]$passes,[StringComparer]::Ordinal).Count-ne3){
           throw 'APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance passes are not three distinct records'
       }
       # Dated as Check 12 dates evidence: a real calendar day, not after the newest civil date on Earth (UTC+14).
       $dates=@([regex]::Matches($v['Pass 3 Evidence Refresh'],'\b\d{4}-\d{2}-\d{2}\b')|ForEach-Object{$_.Value})
       if(-not$dates.Count){throw 'APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance Pass 3 Evidence Refresh names no date'}
       $latest=[DateTime]::UtcNow.AddHours(14).Date
       foreach($d in $dates){$day=[DateTime]::MinValue
           if(-not[DateTime]::TryParseExact($d,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$day)){throw "APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance Pass 3 Evidence Refresh date $d is not a calendar date"}
           if($day-gt$latest){throw "APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance Pass 3 Evidence Refresh date $d is in the future"}
       }
   }
   ```

   e) immediately after the lines
   ```text
               throw 'APPROVAL_EVIDENCE:INDETERMINATE:derived applicability contradicts repository evidence'
           }
       }

   ```
   insert
   ```text
       Assert-DraftAssurance $body

   ```

   The resulting file's Git blob is f56ec204b19a3628936d28bd02ddceabfbc68384.
3. Check whether `scripts/test_agent_continuity.ps1` contains `DAM4 DRAFT ASSURANCE MUTATION`; if so record Already Applied when its Git blob is 4c9e384d8cf110bead46ff94c3a63525d5ed98ea, and otherwise stop and report. Otherwise make exactly these 6 edits (the fixture record, the `absent` cases and the Draft Assurance cases with their mutation kills), each matched once, and change nothing else:

   a) replace the line
   ```text
       [string]$Irreversible='NONE'     # SPEC-198: a declared irreversible action is itself
   ```
   with
   ```text
       [string]$Irreversible='NONE',    # SPEC-198: a declared irreversible action is itself
   ```

   b) immediately after the line
   ```text
                                        # an applicability input, so it must be settable.
   ```
   insert
   ```text
       [string]$Assurance='ok'          # ok | missing | placeholder | repeated | recased | undated | baddate | future | dupfield | dupsection | recasedsection | recasedfield
   ```

   c) immediately after the lines
   ```text
       [string]$Assurance='ok'          # ok | missing | placeholder | repeated | recased | undated | baddate | future | dupfield | dupsection | recasedsection | recasedfield
   ){
   ```
   insert
   ```text
       $p1='Fixture initial design.'
       $p2=switch($Assurance){'placeholder'{'[adversarial challenge]'}'repeated'{$p1}'recased'{'FIXTURE   initial design.'}default{'Fixture adversarial challenge.'}}
       $p3=switch($Assurance){'undated'{'Fixture evidence refreshed.'}'baddate'{'Fixture evidence refreshed on 2026-02-30.'}'future'{'Fixture evidence refreshed on 2999-01-01.'}default{'Fixture evidence refreshed on 2026-10-19.'}}
       $extra=if($Assurance-eq'dupfield'){"`nPass 1 Design: Fixture second design.`n"}else{''}
       $da=if($Assurance-eq'missing'){''}else{"### Draft Assurance`n`nPass 1 Design: $p1`n$extra`nPass 2 Adversarial Review: $p2`n`nPass 3 Evidence Refresh: $p3`n`nSelected Version: Fixture version 3.`n"}
       if($Assurance-eq'dupsection'){$da="$da`n$da"}
       if($Assurance-eq'recasedsection'){$da="$da`n### draft assurance`n`nSelected Version: Fixture version 2.`n"}
       if($Assurance-eq'recasedfield'){$da="${da}selected version: Fixture version 2.`n"}
   ```

   d) immediately after the lines
   ```text
   | SPEC Allocation | Fixture derived fact. | $derivedTable |

   ```
   insert
   ```text
   $da
   ```

   e) immediately after the line
   ```text
           'if($t-and$t[0]-eq[char]0xFEFF){$t=$t.Substring(1)};' '' 'CHECK'
   ```
   insert
   ```text
       # A criterion can say a path is gone. SPEC-289 retired two workflows and no check kind could
       # state it, so Review alone judged that criterion.
       function ChGone([string]$Path='retired.txt',[string]$Scope="retired.txt;$chPlain",[scriptblock]$Mid={},[switch]$Open,[switch]$NoReset){
           ChBase -NoReset:$NoReset|Out-Null;Put 'retired.txt' "Retired.`n";Commit 'ch-retired';$b=(git -C $root rev-parse HEAD).Trim()
           ChLife @{Scope=$Scope;Acceptance="$Path is retired. ``check: absent $Path``"} -NoReset -Mid $Mid -Open:$Open|Out-Null;$b
       }
       $retire={git -C $root rm -q retired.txt;Commit 'ch-retire'}
       $b=ChGone -Mid $retire;$r=RunRange $b
       Assert 'AB1 CHECK: a removed path holds an absent check in the range' ($r.Code-eq0-and$r.Text-match'ORVION: READY') $r.Text
       Pop 'CHECK' 'accept'
       $b=ChGone;$r=RunRange $b
       Assert 'AB2 CHECK: a path that still exists fails an absent check in the range' ($r.Code-ne0-and$r.Text-match'CRITERION_CHECK_FAILED.*retired\.txt exists') $r.Text
       Pop 'CHECK' 'reject'
       ChGone -Open|Out-Null;Remove-Item -LiteralPath (Join-Path $root 'retired.txt');Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run 'Gate'
       Assert 'AB3 CHECK: the removed path holds it in the hook' ($r.Text-notmatch'CRITERION_CHECK_FAILED'-and$r.Text-match$atReceipt) $r.Text
       Pop 'CHECK' 'accept'
       ChGone -Open|Out-Null;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run 'Gate'
       Assert 'AB4 CHECK: a path that still exists fails it in the hook' ($r.Code-ne0-and$r.Text-match'CODE: CRITERION_CHECK_FAILED') $r.Text
       Pop 'CHECK' 'reject'
       ChApprove @{Scope=$chPlain;Acceptance='notes.md is gone. `check: absent notes.md`'}|Out-Null;$r=Run 'Gate'
       Assert 'AB5 CHECK: an absent check on an existing path outside Write Scope refuses Approval' ($r.Code-ne0-and$r.Text-match'CODE: APPROVAL_EVIDENCE'-and$r.Text-match'can never hold') $r.Text
       Pop 'CHECK' 'reject'
       $goneClash='allowed.txt is gone. `check: absent allowed.txt`'+"`n- [ ] "+'allowed.txt is ready. `check: has allowed.txt "ready"`'
       ChApprove @{Scope=$chPlain;Acceptance=$goneClash}|Out-Null;$r=Run 'Gate'
       Assert 'AB6 CHECK: absent beside a check that needs the path refuses Approval' ($r.Code-ne0-and$r.Text-match'CODE: APPROVAL_EVIDENCE'-and$r.Text-match'cannot both hold') $r.Text
       Pop 'CHECK' 'reject'
       # Only a canonical repository-relative path is a check: never one outside the repository or spelled two ways.
       foreach($p in @('../secret.txt','/etc/passwd','C:/Windows/win.ini','docs\channel.md','docs/./channel.md','docs/')){
           ChApprove @{Scope=$chPlain;Acceptance="$p is gone. ``check: absent $p``"}|Out-Null;$r=Run 'Gate'
           Assert "AB7 CHECK: absent refuses the non-canonical path $p" ($r.Code-ne0-and$r.Text-match'CRITERION_CHECK_MALFORMED') $r.Text
           Pop 'CHECK' 'reject'
       }
       # A case-only difference is the same file to Windows and macOS: at a commit it must not read as absent.
       $b=ChGone -Path 'Retired.txt';$r=RunRange $b
       Assert 'AB8 CHECK: a path tracked in another letter case fails absent in the range' ($r.Code-ne0-and$r.Text-match'CRITERION_CHECK_FAILED.*Retired\.txt exists') $r.Text
       Pop 'CHECK' 'reject'
       ChApprove @{Scope=$chPlain;Acceptance='The docs are gone. `check: absent docs`'}|Out-Null;$r=Run 'Gate'
       Assert 'AB9 CHECK: a directory holding tracked files is present' ($r.Code-ne0-and$r.Text-match'can never hold'-and$r.Text-match'docs exists') $r.Text
       Pop 'CHECK' 'reject'
       MutationKill 'ABM1 CHECK MUTATION: absent refuses a path that still exists' {ChGone -Open|Out-Null;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.')} 'retired\.txt exists' `
           'if($hit.Count-or(' 'if($false-and(' 'CHECK'
       MutationKillRangeAt 'ABM3 CHECK MUTATION: absence is judged in any letter case' {ChGone -Path 'Retired.txt' -NoReset} 'Retired\.txt exists' `
           '[StringComparison]::OrdinalIgnoreCase)-or$_.StartsWith' '[StringComparison]::Ordinal)-or$_.StartsWith' 'CHECK'
       MutationKill 'ABM4 CHECK MUTATION: a non-canonical path is malformed' {ChApprove @{Scope=$chPlain;Acceptance='It is gone. `check: absent ../secret.txt`'}|Out-Null} 'CRITERION_CHECK_MALFORMED' `
           '(?!.*(?:^|/)\.\.?(?:/|$))' '' 'CHECK'
       MutationKill 'ABM2 CHECK MUTATION: absent clashes with a check that needs the path' {ChApprove @{Scope=$chPlain;Acceptance=$goneClash}|Out-Null} 'cannot both hold' `
           "if(`$a.Kind-eq'absent'-and" "if(`$false-and`$a.Kind-eq'absent'-and" 'CHECK'    # A listing Git cannot finish is not absence: a missing object stopped ls-tree part-way and the
       # range was READY with retired.txt still in the tree. The lost subtree sits in the range base, so
       # no diff in the walk reads it and only the listing meets the damage. Moved objects are put back.
       $script:chLost=@()
       function ChLost([switch]$NoReset){
           if(-not$NoReset){Reset-Fixture};Put "aaa-lost/$([guid]::NewGuid().ToString('N')).txt" "lost`n"
           $b=ChGone -NoReset;$t=(git -C $root rev-parse 'HEAD:aaa-lost').Trim()
           $o=Join-Path $root ".git/objects/$($t.Substring(0,2))/$($t.Substring(2))";$k=Join-Path $sandbox "lost-$t"
           Move-Item -LiteralPath $o -Destination $k;$script:chLost+=,@($k,$o);$b
       }
       function ChFound{foreach($x in $script:chLost){Move-Item -LiteralPath $x[0] -Destination $x[1]};$script:chLost=@()}
       $b=ChLost;$r=RunRange $b;ChFound
       Assert 'AB10 CHECK: an absent check Git cannot list is refused as indeterminate, never held' ($r.Code-ne0-and$r.Text-match'CRITERION_CHECK_INDETERMINATE:retired\.txt.*@[0-9a-f]{7}'-and$r.Text-notmatch'ORVION: READY') $r.Text
       Pop 'CHECK' 'reject'
       ChGone -Open|Out-Null;git -C $root rm -q --cached retired.txt;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run 'Gate'
       Assert 'AB11 CHECK: a staged deletion still on disk fails absent in the hook' ($r.Code-ne0-and$r.Text-match'CODE: CRITERION_CHECK_FAILED'-and$r.Text-match'retired\.txt exists') $r.Text
       Pop 'CHECK' 'reject'
       MutationKillRangeAt 'ABM5 CHECK MUTATION: a failed listing is indeterminate, not absent' {ChLost -NoReset} 'CRITERION_CHECK_INDETERMINATE' `
           'if($LASTEXITCODE-ne0){throw "CRITERION_CHECK_INDETERMINATE' 'if($false){throw "CRITERION_CHECK_INDETERMINATE' 'CHECK'
       ChFound

       # DRAFT ASSURANCE. Approval of evidence-applicable work needs three distinct, filled passes, a dated
       # evidence refresh and the selected version. The Gate proves the record exists, never that the
       # review was good: that is the human's Approval decision.
       $daScope="scripts/parity_surface.sql;$chPlain"
       foreach($c in @(
           @{No='DA1';A='missing';E='Draft Assurance missing'},
           @{No='DA2';A='placeholder';E='Draft Assurance field missing: Pass 2 Adversarial Review'},
           @{No='DA3';A='repeated';E='not three distinct records'},
           @{No='DA4';A='undated';E='names no date'},
           @{No='DA7';A='recased';E='not three distinct records'},
           @{No='DA8';A='baddate';E='2026-02-30 is not a calendar date'},
           @{No='DA9';A='future';E='2999-01-01 is in the future'},
           @{No='DA10';A='dupfield';E='field repeated: Pass 1 Design'},
           @{No='DA11';A='dupsection';E='Draft Assurance appears 2 times'},
           @{No='DA14';A='recasedsection';E='Draft Assurance appears 2 times'},
           @{No='DA15';A='recasedfield';E='field repeated: Selected Version'})){
           ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance $c.A)}|Out-Null;$r=Run 'Gate'
           Assert "$($c.No) DRAFT ASSURANCE: a $($c.A) record refuses Approval" ($r.Code-ne0-and$r.Text-match'APPROVAL_EVIDENCE'-and$r.Text-match$c.E) $r.Text
           Pop 'DA' 'reject'
       }
       ChApprove @{Scope=$daScope;Evidence=(EvidenceText)}|Out-Null;$r=Run 'Gate'
       Assert 'DA5 DRAFT ASSURANCE MUST-ACCEPT: a complete record is admitted' ($r.Code-eq0-and$r.Text-match'APPROVAL_EVIDENCE: PASS') $r.Text
       Pop 'DA' 'accept'
       ChApprove @{Scope=$chPlain}|Out-Null;$r=Run 'Gate'
       Assert 'DA6 DRAFT ASSURANCE: work the section is not derived for needs no record' ($r.Code-eq0-and$r.Text-match'APPROVAL_EVIDENCE: NOT APPLICABLE') $r.Text
       Pop 'DA' 'accept'
       MutationKill 'DAM1 DRAFT ASSURANCE MUTATION: Approval reads the record' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'missing')}|Out-Null} 'Draft Assurance missing' `
           'Assert-DraftAssurance $body' '' 'DA'
       MutationKill 'DAM2 DRAFT ASSURANCE MUTATION: every field is filled' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'placeholder')}|Out-Null} 'Draft Assurance field missing' `
           "if(`$v[`$f]-eq''){throw" 'if($false){throw' 'DA'
       MutationKill 'DAM3 DRAFT ASSURANCE MUTATION: the passes are distinct' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'repeated')}|Out-Null} 'not three distinct records' `
           '[StringComparer]::Ordinal).Count-ne3){' '[StringComparer]::Ordinal).Count-lt0){' 'DA'
       MutationKill 'DAM4 DRAFT ASSURANCE MUTATION: the evidence refresh is dated' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'undated')}|Out-Null} 'names no date' `
           'if(-not$dates.Count){throw' 'if($false){throw' 'DA'
       MutationKill 'DAM5 DRAFT ASSURANCE MUTATION: passes differing only in case and spacing are one pass' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'recased')}|Out-Null} 'not three distinct records' `
           "(`$v[`$_]-replace'\s+',' ').ToLowerInvariant()" '$v[$_]' 'DA'
       MutationKill 'DAM6 DRAFT ASSURANCE MUTATION: the date is a calendar day' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'baddate')}|Out-Null} 'is not a calendar date' `
           'if(-not[DateTime]::TryParseExact(' 'if($false-and-not[DateTime]::TryParseExact(' 'DA'
       MutationKill 'DAM7 DRAFT ASSURANCE MUTATION: the date is not in the future' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'future')}|Out-Null} 'is in the future' `
           'if($day-gt$latest){throw' 'if($false){throw' 'DA'
       MutationKill 'DAM8 DRAFT ASSURANCE MUTATION: a field has one line' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'dupfield')}|Out-Null} 'field repeated' `
           'if($lines-gt1){throw' 'if($false){throw' 'DA'
       MutationKill 'DAM9 DRAFT ASSURANCE MUTATION: the record appears once' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'dupsection')}|Out-Null} 'appears 2 times' `
           'if($n-gt1){throw' 'if($false){throw' 'DA'
       MutationKill 'DAM10 DRAFT ASSURANCE MUTATION: a heading in another letter case is the same record' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'recasedsection')}|Out-Null} 'appears 2 times' `
           "'(?mi)^### Draft Assurance" "'(?m)^### Draft Assurance" 'DA'
       MutationKill 'DAM11 DRAFT ASSURANCE MUTATION: a field name in another letter case is the same field' {ChApprove @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'recasedfield')}|Out-Null} 'field repeated' `
           '"(?mi)^$([regex]::Escape($f)):"' '"(?m)^$([regex]::Escape($f)):"' 'DA'
       # SACI: a Draft-to-Approved transition is judged only inside the range being admitted, so a contract
       # approved before this rule is never re-judged, while one approved inside the range is.
       ChLife @{Scope=$daScope;Evidence=(EvidenceText -Assurance 'missing')}|Out-Null
       $chBaseSha=(git -C $root log --format=%H --grep='^ch-base$' -1).Trim();$chApproveSha=(git -C $root log --format=%H --grep='^ch-approve$' -1).Trim()
       $r=RunRange $chBaseSha
       Assert 'DA12 DRAFT ASSURANCE: an Approval inside the admitted range is judged' ($r.Code-ne0-and$r.Text-match'Draft Assurance missing') $r.Text
       Pop 'DA' 'reject'
       $r=RunRange $chApproveSha
       Assert 'DA13 DRAFT ASSURANCE SACI: an Approval before the range is never re-judged' ($r.Code-eq0-and$r.Text-match'ORVION: READY') $r.Text
       Pop 'DA' 'accept'
   ```

   f) replace the line
   ```text
       foreach($family in @('D','F','HJ','APPLIC','WC','CTRL1','CTRL4','RANGE-AUTH','ORIGIN','K-local','K-reservation','K-activation','K-range','CERT-INHERIT','SEG-CARRY','PARITY','CHECK','PIN','ACI','TRUST','PROMOTE','TIME')){
   ```
   with
   ```text
       foreach($family in @('D','F','HJ','APPLIC','WC','CTRL1','CTRL4','RANGE-AUTH','ORIGIN','K-local','K-reservation','K-activation','K-range','CERT-INHERIT','SEG-CARRY','PARITY','CHECK','DA','PIN','ACI','TRUST','PROMOTE','TIME')){
   ```

   The resulting file's Git blob is 4c9e384d8cf110bead46ff94c3a63525d5ed98ea.
4. Check whether `scripts/run_timed.ps1` contains `RESOURCES: samples=`; if so record Already Applied when its Git blob is d1fbfc81d41b04b0c8b3a50c4b17cdd19853ca60, and otherwise stop and report. Otherwise make exactly these 2 edits (resource sampling and the `RESOURCES:` line), each matched once, and change nothing else:

   a) immediately after the line
   ```text
   function Stamp { $sw.Elapsed.TotalMinutes.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture).PadLeft(8) }
   ```
   insert
   ```text
   # RESOURCES. While the command runs, free memory, this run's own process tree and CPU are sampled to
   # `<log>.resources.csv` every ORVION_RESOURCE_SECONDS (default 60), and one summary line precedes END,
   # so the conditions behind a slow or killed run (a suite was killed at 1.7 GB free on 2026-10-12) and
   # the headroom for running two suites together are measured, not guessed. It observes only. A host
   # without these Windows counters, such as a hosted Linux runner, says `RESOURCES: unavailable`.
   $resources = "$Log.resources.csv"; $sampler = $null
   if ($IsWindows) {
       $every = 60; if (-not [int]::TryParse("$env:ORVION_RESOURCE_SECONDS", [ref]$every) -or $every -lt 1) { $every = 60 }
       $sampler = Start-ThreadJob -ArgumentList $PID, $resources, $every -ScriptBlock {
           param($Root, $Path, $Seconds)
           $inv = [Globalization.CultureInfo]::InvariantCulture
           'at,free_gb,tree_mb,cpu_pct' | Out-File -LiteralPath $Path -Encoding utf8
           while ($true) {
               $all = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, WorkingSetSize)
               $ids = [Collections.Generic.HashSet[int]]::new(); [void]$ids.Add($Root)
               do { $n = $ids.Count; foreach ($p in $all) { if ($ids.Contains([int]$p.ParentProcessId)) { [void]$ids.Add([int]$p.ProcessId) } } } while ($ids.Count -gt $n)
               $tree = ($all | Where-Object { $ids.Contains([int]$_.ProcessId) } | Measure-Object WorkingSetSize -Sum).Sum / 1MB
               $free = (Get-CimInstance Win32_OperatingSystem -Property FreePhysicalMemory).FreePhysicalMemory / 1MB
               $cpu = (Get-CimInstance Win32_Processor -Property LoadPercentage | Measure-Object LoadPercentage -Average).Average
               [string]::Format($inv, '{0:yyyy-MM-dd HH:mm:ss},{1:0.00},{2:0},{3:0}', (Get-Date), $free, $tree, $cpu) | Out-File -LiteralPath $Path -Append -Encoding utf8
               Start-Sleep -Seconds $Seconds
           }
       }
   }
   ```

   b) immediately after the line
   ```text
   $code = $LASTEXITCODE
   ```
   insert
   ```text
   if ($sampler) { Stop-Job $sampler; Remove-Job $sampler -Force }
   # A sample cut off by Stop-Job is dropped, never allowed to disturb END or the exit code.
   $summary = try {
       $inv = [Globalization.CultureInfo]::InvariantCulture; $x = 0.0
       $rows = @(if ($sampler -and (Test-Path -LiteralPath $resources)) { Import-Csv -LiteralPath $resources | Where-Object { [double]::TryParse("$($_.cpu_pct)", [Globalization.NumberStyles]::Float, $inv, [ref]$x) } })
       if (-not $rows.Count) { 'RESOURCES: unavailable' } else {
           $col = { param($Name) $rows | ForEach-Object { [double]::Parse($_.$Name, $inv) } }
           [string]::Format($inv, 'RESOURCES: samples={0} min_free_gb={1:0.00} peak_tree_mb={2:0} max_cpu_pct={3:0} ({4})', $rows.Count,
               (& $col free_gb | Measure-Object -Minimum).Minimum, (& $col tree_mb | Measure-Object -Maximum).Maximum, (& $col cpu_pct | Measure-Object -Maximum).Maximum, $resources) }
   } catch { "RESOURCES: unreadable ($($_.Exception.Message))" }
   '[+{0} min] {1}' -f (Stamp), $summary | Out-File -LiteralPath $Log -Append -Encoding utf8
   ```

   The resulting file's Git blob is d1fbfc81d41b04b0c8b3a50c4b17cdd19853ca60.
5. Check whether `scripts/watch_selftest.ps1` contains `Case-Resources`; if so record Already Applied when its Git blob is b0a838b184a3b0b9d0928cb34e474b045624e4de, and otherwise stop and report. Otherwise make exactly these 3 edits (cases W20 to W22 and mutants M34 and M35), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
       [pscustomobject]@{ Ok = ($done -and $r.ExitCode -eq 3 -and $end.Count -eq 1 -and $end[0] -match 'END exit=3 '); Detail = "runner exit=$(if ($done) { $r.ExitCode }) end=[$end]" }
   }
   ```
   insert
   ```text
   # The runner samples its own resources while the command runs and summarises them on one line before
   # END, which stays last; the command's exit code is untouched.
   function Case-Resources([string]$RunnerPath) {
       $log = New-Name '.log'; $saved = $env:ORVION_RESOURCE_SECONDS; $env:ORVION_RESOURCE_SECONDS = '1'
       try { $r = Start-Runner $RunnerPath $log "Write-Output 'PASS: x'; Start-Sleep -Seconds 6; exit 4" } finally { $env:ORVION_RESOURCE_SECONDS = $saved }
       $done = Wait-Exit $r 60; $lines = @(Get-Content -LiteralPath $log)
       $sum = @($lines | Where-Object { $_ -match '\] RESOURCES: samples=(\d+) min_free_gb=[\d.]+ peak_tree_mb=(\d+) max_cpu_pct=\d+ ' })
       $n = if ($sum.Count -eq 1) { [int]([regex]::Match($sum[0], 'samples=(\d+)').Groups[1].Value) } else { 0 }
       $rows = @(if (Test-Path -LiteralPath "$log.resources.csv") { Import-Csv -LiteralPath "$log.resources.csv" })
       $ok = $done -and $r.ExitCode -eq 4 -and $n -ge 2 -and $rows.Count -eq $n -and [double]$rows[0].tree_mb -gt 0 -and $lines[-1] -match '\] END exit=4 ' -and $lines[-2] -match '\] RESOURCES: '
       [pscustomobject]@{ Ok = $ok; Detail = "done=$done exit=$(if ($done) { $r.ExitCode }) samples=$n rows=$($rows.Count) || $($lines -join ' || ')" }
   }
   # Two runs at once each sample into their own file and keep their own exit code and summary.
   function Case-ResourcesConcurrent([string]$RunnerPath) {
       $logs = @((New-Name '.log'), (New-Name '.log')); $saved = $env:ORVION_RESOURCE_SECONDS; $env:ORVION_RESOURCE_SECONDS = '1'
       try { $rs = @((Start-Runner $RunnerPath $logs[0] "Start-Sleep -Seconds 5; exit 5"), (Start-Runner $RunnerPath $logs[1] "Start-Sleep -Seconds 5; exit 6")) } finally { $env:ORVION_RESOURCE_SECONDS = $saved }
       $done = (Wait-Exit $rs[0] 60) -and (Wait-Exit $rs[1] 60); $detail = @(); $ok = $done; $paths = @()
       foreach ($i in 0, 1) {
           $lines = @(Get-Content -LiteralPath $logs[$i]); $sum = @($lines | Where-Object { $_ -match '\] RESOURCES: samples=(\d+) .*\((.+)\)$' })
           $path = if ($sum.Count -eq 1) { [regex]::Match($sum[0], '\((.+)\)$').Groups[1].Value } else { '' }; $paths += $path
           $n = if ($sum.Count -eq 1) { [int]([regex]::Match($sum[0], 'samples=(\d+)').Groups[1].Value) } else { 0 }
           $rows = @(if ($path -and (Test-Path -LiteralPath $path)) { Import-Csv -LiteralPath $path })
           $ok = $ok -and $done -and $rs[$i].ExitCode -eq (5 + $i) -and $n -ge 2 -and $rows.Count -eq $n -and $path -eq "$($logs[$i]).resources.csv" -and $lines[-1] -match "\] END exit=$(5 + $i) "
           $detail += "run$i exit=$(if ($done) { $rs[$i].ExitCode }) samples=$n rows=$($rows.Count) path=$path"
       }
       [pscustomobject]@{ Ok = ($ok -and $paths[0] -ne $paths[1]); Detail = ($detail -join ' || ') }
   }
   # Killing the runner stops its sampler with it: the sampler is a thread of the runner, never a process
   # of its own, so nothing keeps appending once the runner is gone.
   function Case-ResourcesInterrupted([string]$RunnerPath) {
       $log = New-Name '.log'; $csv = "$log.resources.csv"; $saved = $env:ORVION_RESOURCE_SECONDS; $env:ORVION_RESOURCE_SECONDS = '1'
       try { $r = Start-Runner $RunnerPath $log "Start-Sleep -Seconds 60" } finally { $env:ORVION_RESOURCE_SECONDS = $saved }
       $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 30 -and @(if (Test-Path -LiteralPath $csv) { Get-Content -LiteralPath $csv }).Count -lt 3) { Start-Sleep -Milliseconds 250 }
       $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($r.Id)" | ForEach-Object { $_.ProcessId })
       Stop-Process -Id $r.Id -Force; [void]$r.WaitForExit(10000)
       $at = @(Get-Content -LiteralPath $csv).Count; Start-Sleep -Seconds 3; $later = @(Get-Content -LiteralPath $csv).Count
       foreach ($c in $children) { Stop-Tree $c }
       $end = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '\] (END|RESOURCES):' }).Count
       [pscustomobject]@{ Ok = ($at -ge 3 -and $later -eq $at -and $end -eq 0); Detail = "rows at kill=$at rows 3 s later=$later end-or-summary lines=$end" }
   }
   ```

   b) immediately after the line
   ```text
       $c = Case-ExitCode $Runner;      Check 'W0 the runner preserves the command''s own exit code (3), in its END line and its own exit' $c.Ok $c.Detail
   ```
   insert
   ```text
       $c = Case-Resources $Runner;     Check 'W20 the runner samples free memory, its own process tree and CPU while the command runs, and summarises them on one line before END' $c.Ok $c.Detail
       $c = Case-ResourcesConcurrent $Runner; Check 'W21 two concurrent runs each sample into their own file and keep their own exit code, summary and END' $c.Ok $c.Detail
       $c = Case-ResourcesInterrupted $Runner; Check 'W22 a killed runner leaves no sampler behind: its resource file stops growing and no END or summary is claimed' $c.Ok $c.Detail
   ```

   c) replace the line
   ```text
           @{ Name = 'M28 the runner stamps a tenth of a minute'; File = $Runner;  Find = "ToString('0.000',"; Replace = "ToString('0.0',"; Case = { param($p) Case-Tests $p $Watcher } }
   ```
   with
   ```text
           @{ Name = 'M28 the runner stamps a tenth of a minute'; File = $Runner;  Find = "ToString('0.000',"; Replace = "ToString('0.0',"; Case = { param($p) Case-Tests $p $Watcher } },
           @{ Name = 'M34 resources never sampled';              File = $Runner;  Find = 'if ($IsWindows) {'; Replace = 'if ($false) {'; Case = { param($p) Case-Resources $p } },
           @{ Name = 'M35 concurrent runs share one resource file'; File = $Runner; Find = '$resources = "$Log.resources.csv"'; Replace = '$resources = Join-Path ([IO.Path]::GetTempPath()) ''orvion-resources.csv'''; Case = { param($p) Case-ResourcesConcurrent $p } }
   ```

   The resulting file's Git blob is b0a838b184a3b0b9d0928cb34e474b045624e4de.
6. Check whether `ENGINEERING_METHOD.md` contains `**Draft Assurance**`; if so record Already Applied when its Git blob is 874d1eefc1707dc56a9cbc41dfc3e695e2a0b726, and otherwise stop and report. Otherwise make exactly these 3 edits (the fifth evidence class and the resource sentence), each matched once, and change nothing else:

   a) replace the line
   ```text
   Four evidence classes are required where deterministically applicable:
   ```
   with
   ```text
   Five evidence classes are required where deterministically applicable:
   ```

   b) immediately after the line
   ```text
   - **Permanent-Control Admission** — a new permanent control freezes its reuse assessment, the distinct property it adds, a reproduced causal negative, positive and negative test designs, a non-empty-population obligation, and a mutation obligation. Actual positive, negative, population, and mutation proof is supplied after implementation, by the certified suite, and is never asserted before the code exists.
   ```
   insert
   ```text
   - **Draft Assurance** — the Draft records three distinct passes, one line each: `Pass 1 Design`, the initial design; `Pass 2 Adversarial Review`, what a challenge of it rejected, changed or confirmed; `Pass 3 Evidence Refresh`, the evidence re-read or re-measured, with its date; and the `Selected Version`. It follows the contract-level trigger, as Consumer Closure does. The Gate refuses as `INDETERMINATE` a record that is missing or appears twice, a field that is unfilled or written twice (headings and field names in any letter case), passes that differ only in case or spacing, and a refresh with no date, an impossible date or a date later than the newest civil date on Earth; whether the review was good stays the human's Approval decision (owner requirement of 2026-10-15, enforced 2026-10-19).
   ```

   c) replace the line
   ```text
   - **A timing is evidence only with its conditions.** Record the command, its scope, the environment and what else was running; `scripts/run_timed.ps1` writes all of them into the run's START line. A run measured beside other work is labelled as such and is never a baseline: `SPEC-248`'s 50.3-minute `-Finish` ran beside a validation suite. An estimate or a remembered duration is never presented as a measurement.
   ```
   with
   ```text
   - **A timing is evidence only with its conditions.** Record the command, its scope, the environment and what else was running; `scripts/run_timed.ps1` writes all of them into the run's START line, samples free memory, its own process tree and CPU every minute into `<log>.resources.csv`, and states the lowest free memory and the largest tree it sampled on a `RESOURCES:` line before END. These are minute samples, not bounds: a shorter peak can fall between them, and WSL or Docker memory shows only as lower free memory. Read it before running two heavy suites together, and quote it with the timing. A run measured beside other work is labelled as such and is never a baseline: `SPEC-248`'s 50.3-minute `-Finish` ran beside a validation suite. An estimate or a remembered duration is never presented as a measurement.
   ```

   The resulting file's Git blob is 874d1eefc1707dc56a9cbc41dfc3e695e2a0b726.
7. Check whether `changes/TEMPLATE.md` contains `check: absent <path>`; if so record Already Applied when its Git blob is 6494ecfc57e0212e8b1c35dbab46daa7f510f2f9, and otherwise stop and report. Otherwise make exactly these 2 edits (the Draft Assurance subsection and the `absent` kind), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   Change Class: [Routine | Significant | Owner-Decision]

   ```
   insert
   ```text
   ### Draft Assurance

   [Required wherever Consumer Closure is, once, one line per field. The Gate refuses a missing,
   duplicated, bracketed or repeated record and a missing, impossible or future date; the human judges
   its quality at Approval (`ENGINEERING_METHOD.md`).]

   Pass 1 Design: [the initial design and what it covers]

   Pass 2 Adversarial Review: [what an adversarial challenge of Pass 1 rejected, changed or confirmed, and why]

   Pass 3 Evidence Refresh: [the evidence re-read or re-measured, with its date in YYYY-MM-DD form]

   Selected Version: [the version approved, and why it was preferred]

   ```

   b) replace the lines
   ```text
   `check: lacks <path>[#<line key>] "<text>"` or `check: blob <path> <sha1>`. A check that can never
   hold refuses Approval, and every check must hold at Complete, in the hook and in CI. An item without
   a check is judged by Review alone, and the Gate reports it as such.
   ```
   with
   ```text
   `check: lacks <path>[#<line key>] "<text>"`, `check: blob <path> <sha1>` or `check: absent <path>`
   (Git holds neither the repository-relative path nor anything under it, in any letter case, and in the
   working tree nothing is on disk there). A check that can never hold refuses Approval, and every check
   must hold at Complete, in the hook and in CI. An item without a check is judged by Review alone, and
   the Gate reports it as such.
   ```

   The resulting file's Git blob is 6494ecfc57e0212e8b1c35dbab46daa7f510f2f9.
8. Check whether the Runtime Checkpoint reads `Resume Step: DONE`; if so record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, confirm `pwsh -NoProfile -File scripts/generate-ai-map.ps1 -Check` exits 0 and that `git status --porcelain` names only Write Scope paths, append the Execution Log entry, set the Runtime Checkpoint to `Resume Step: DONE`, `Blocker: None`, `Recovery Attempt: 0`, and commit the implementation and checkpoint together through the unchanged pre-commit hook.
9. Check that a fresh native receipt for this contract matches, a `Verdict: Confirmed Complete` Verification Notes entry exists and every Acceptance Criterion and Review Gate item holds; only then record Already Applied. Otherwise, from the repository root, start `pwsh -NoProfile -File scripts/run_timed.ps1 -Log <log> -Command "pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish"` and, at the same time, `pwsh -NoProfile -File scripts/watch_run.ps1 -Log <log> -Run finish-control -Brief`, with `<log>` outside the checkout. Require `LOCAL_CERTIFY: READY`; a failed command keeps its real exit code and evidence and starts bounded recovery without weakening any assertion. Perform independent live Review against the repository and append its Verification Notes verdict. Then complete through the native lifecycle with the unchanged pre-commit hook, setting `manifest.md`'s `Active Change Request` to `None.` and its `Last Completed` to exactly `Last Completed: **SPEC-290: Approval requires a recorded three-pass Draft assurance, a criterion can prove a path is absent, and every timed run reports its resource cost — fresh local verification and Review complete; owner publication/promotion and exact-SHA remote certification follow `CR_LIFECYCLE.md` §9. Batch 6 remains ON HOLD by owner decision (2026-10-18) until the infrastructure programme completes and the owner authorizes resumption. CTRL-19 remains OPEN.**`, regenerating the projections with the existing generator. Locally prepare the exact candidate with `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BindCandidate -Root <original-checkout> -BaseRef <full-main-SHA> -HeadRef <full-candidate-SHA>`. Stop before publication or promotion.

## Acceptance Criteria

- [ ] The evaluator, its control suite, the timed runner, the runner self-test, the method and the template hold exactly the reviewed bytes. `check: blob scripts/check_agent_continuity.ps1 f56ec204b19a3628936d28bd02ddceabfbc68384` `check: blob scripts/test_agent_continuity.ps1 4c9e384d8cf110bead46ff94c3a63525d5ed98ea` `check: blob scripts/run_timed.ps1 d1fbfc81d41b04b0c8b3a50c4b17cdd19853ca60` `check: blob scripts/watch_selftest.ps1 b0a838b184a3b0b9d0928cb34e474b045624e4de` `check: blob ENGINEERING_METHOD.md 874d1eefc1707dc56a9cbc41dfc3e695e2a0b726` `check: blob changes/TEMPLATE.md 6494ecfc57e0212e8b1c35dbab46daa7f510f2f9`
- [ ] Approval of evidence-applicable work requires a Draft Assurance record, and a criterion may check that a path is absent. `check: has scripts/check_agent_continuity.ps1 "APPROVAL_EVIDENCE:INDETERMINATE:Draft Assurance missing"` `check: has scripts/check_agent_continuity.ps1 "'absent'{[regex]::Match("` `check: has changes/TEMPLATE.md "### Draft Assurance"`
- [ ] Every timed run reports its resource cost on one line before END. `check: has scripts/run_timed.ps1 "RESOURCES: samples={0}"` `check: has scripts/watch_selftest.ps1 "M34 resources never sampled"`
- [ ] The admission workflow, Agent Control, the watcher, the release authorities, the consistency guard, the lifecycle and governance are unchanged. `check: blob .github/workflows/orvion-acceptance.yml b242e4c7401258404c5d43bffb49c3f53f42467e` `check: blob .github/workflows/agent-control.yml 41243b7c9a499df4cf011385a046c53107084ba3` `check: blob scripts/watch_run.ps1 e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b` `check: blob scripts/watch_ci.ps1 ca87c18d3ac7fa62f70f5df681c5df18cf482699` `check: blob scripts/publish_candidate.ps1 d168504cc66c3a0759ac3ee9b5e01045a0f46589` `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79` `check: blob scripts/check_repository_consistency.ps1 3e6d2810e03bfac15b96dba3bc46d119d97ad658` `check: blob CR_LIFECYCLE.md a80d15cdf805932623a0a8ea93aaae9740fac870` `check: blob GOVERNANCE.md 5670c47888bbd6b4194f6c41c54476ee42cb7bdf`
- [ ] The manifest keeps the owner's Batch 6 hold. `check: has _ORVION_CANONICAL/manifest.md "Batch 6 remains ON HOLD by owner decision (2026-10-18)"`

## Execution Log

None.

### 2026-10-19 — Gate 1 approval recorded

The owner's Gate 1 directive of 2026-10-19 (Executive Infrastructure Handoff and Approved Execution) explicitly approves this exact Version 5 Draft, SHA-256 AB188E6302EEB2E9B4829F3FA33FD56F30E3E0442DE22589F23261908ABEE57C and Git blob 55f07e08c7fdd85e420c4d1916fd1392dbad50f7, and no superseded or future revision. Immediately before allocation the hash, the Draft blob 55f07e08c7fdd85e420c4d1916fd1392dbad50f7, all 19 source anchors, refreshed origin/main b091f0fa002d0d9f4ce9f38713c92cd0dbc6270c and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as b1caa7e. No implementation performed before this transition. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

## Verification Notes

None.

## Review Gate

- [ ] Exact approved steps and exhaustive scope independently confirmed.
- [ ] Every acceptance criterion confirmed against final local evidence.
- [ ] Mandatory profiles, the runner self-test and Git checks pass through fresh Finish.
- [ ] Admission workflow, release authorities and historical evidence preserved; no GitHub setting changed; CTRL-19 remains OPEN.

## Notes

Contract size was challenged under the owner's cohesive-contract direction. Draft Assurance and `absent` share one evaluator, one control suite and one Finish. Resource sampling touches disjoint files and was first planned alone; grouped, it adds only the runner self-test to a CONTROL Finish that runs anyway, while alone it would cost a Gate 1, a Finish, two hosted runs and a promotion. Its failure cannot couple to the evaluator change, and its code was proven before this Draft. The watcher's missing ETA on 2026-10-19 was traced to per-contract `-Run` names, which this contract avoids by using `finish-control`. Its silence while a suite runs (each suite's result is printed only when the suite ends) needs no change here: the running suite's live output is already written to `orvion-verify-*.log` in the temp folder.

The Gate proves that the assurance record exists and is well formed; it cannot prove the review was good, and does not claim to. That stays the human's Approval decision.

Repository identity checked from effective Git configuration: this checkout commits as `PlatPlusHub <platplustours@gmail.com>` from its local configuration. Push authentication is not commit authorship and neither is changed here. The Founder repository receives its own contract with its own approval, receipt and certification.
