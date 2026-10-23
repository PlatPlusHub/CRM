# Change Request — SPEC-295

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Show generic UNREADABLE result lines in the existing native watcher's Brief output while preserving quiet success, recorded evidence and producer-owned exit semantics.

## Business Reason

A required evidence-read failure was recorded but hidden from the agent's concise observation stream. One missing attention alternative caused the gap; use the existing reporter and owning self-test instead of another monitoring engine.

## Risks

Broader matching could create noisy notifications or silently change the reporter's authority. Preserve result classification, literal diagnostics, END-derived exit, timing history, five-minute quiet heartbeat, redaction, ETA and all native gates. Local stdout evidence proves neither delivery to a human/client nor the cause of unreadability. This contract governs only local source/lifecycle and native candidate binding; publication/promotion remain post-Complete operations. Batch6/Phase8 remain ON HOLD; CTRL-19 remains OPEN.

## Supersedes / Depends On

None.

## Write Scope

- `scripts/watch_run.ps1`
- `scripts/watch_selftest.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/watch_ci.ps1`
- `scripts/run_timed.ps1`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `changes/TEMPLATE.md`
- `scripts/watch_run.ps1`
- `scripts/watch_selftest.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- pwsh -NoProfile -File scripts/watch_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: SPEC-295-BRIEF-V1 identifies one attention-vocabulary gap and retains the native reporter/exit/history contract. The retained initial design preceded prototype edits; this complete native contract snapshot was instantiated after focused experiments, not backdated.

Pass 2 Adversarial Review: SPEC-295-BRIEF-V2 exercises actual generic UNREADABLE with END0 and END2, READY/passing-noise suppression and one retained history row. A scoped attention-removal mutant still records the result but hides the alert; the actual owning caller rejects it. No receipt or client delivery is inferred.

Pass 3 Evidence Refresh: 2026-10-23. SPEC-295-BRIEF-V3 re-reads the native header/method, exact profiles and self-test obligation, fresh actual prototype evidence, Google SRE simple symptom/low-noise guidance and PowerShell scope guidance. Existing scratch-checker warnings were compared with baseline; none was introduced, and that checker explicitly targets scratch rather than repository code. Native parsing/callers and full owning verification remain mandatory. Exact selected sandbox native Finish/Review/Complete/binding must pass before original delegated approval.

Selected Version: SPEC-295-BRIEF-V3; selected because actual symptoms, causal mutation and current owning authority support this smallest compatible repair; original authority waits for exact native sandbox closure

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Generic unreadable attention | Existing Brief output and agent monitor | WRITE | One extra attention alternative; result classifier/history/END authority unchanged |
| Visibility regression | Existing owning watcher self-test | WRITE | Actual allowed/blocked/noisy callers and a specific removal mutant; complete previous suite retained |
| Verification selection | Native profile engine and Finish | VERIFY | Actual source scope derives native obligations; owning watcher self-test runs once as Additional Verification, never an implementation step |
| Active task and generated discovery | Native Boot and manifest projections | WRITE | Existing legal pointer/completion synchronization and native generator only |
| Native authorization, domain, databases and release | Existing owning authorities | UNAFFECTED | No guard/profile/credential/service change, no product work or remote acceptance claimed |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Selected bytes and baseline anchors | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Own native profiles and fresh verification | BEFORE_COMPLETION | NONE | NONE | NONE |
| Native source/receipt/Review independence | BEFORE_COMPLETION | NONE | NONE | NONE |

## Implementation Steps

1. Check whether `scripts/watch_run.ps1` contains `|INCOMPLETE|UNPROVEN|UNREADABLE|RECOVERY_EXHAUSTED|`; if so record Already Applied when its Git blob is 6d337dc27eb56e6fb0aa74136ad7623f41699724, and otherwise stop and report. Otherwise make exactly this one edit (truthful generic unreadable visibility through the existing native watcher), each matched once, and change nothing else:

   a) replace the line
   ```text
   $script:AttentionRx = '(\bFAIL|\bFAILED\b|BLOCKED|^CODE: |\bnot ok\b|\bERROR:|\bSURVIVED\b|INCOMPLETE|UNPROVEN|RECOVERY_EXHAUSTED|\b[1-9]\d* failed\b|^END exit=|CERTIFY: )'
   ```
   with
   ```text
   $script:AttentionRx = '(\bFAIL|\bFAILED\b|BLOCKED|^CODE: |\bnot ok\b|\bERROR:|\bSURVIVED\b|INCOMPLETE|UNPROVEN|UNREADABLE|RECOVERY_EXHAUSTED|\b[1-9]\d* failed\b|^END exit=|CERTIFY: )'
   ```

   The resulting file's Git blob is 6d337dc27eb56e6fb0aa74136ad7623f41699724.

2. Check whether `scripts/watch_selftest.ps1` contains `W40 generic UNREADABLE is visible once`; if so record Already Applied when its Git blob is 6dc84f48b8b9c17ae329e0958ded6ba38cb80b3c, and otherwise stop and report. Otherwise make exactly these 3 edits (truthful generic unreadable visibility through the existing native watcher), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
       [pscustomobject]@{Ok=$ok;Unreadable=$unreadable;Detail="done=$done exit=$($w.ExitCode) progress=$progress history_tests=$testRows unreadable=$unreadable"}
   }
   ```
   insert
   ```text
   # Generic required evidence must be visible in Brief even when its producer ended successfully.
   # Reporter exit still belongs to END, never to an inferred failure cause.
   function Case-GenericBrief([string]$WatcherPath) {
       $passed=$true;$details=@()
       foreach($sample in @(@{Verdict='UNREADABLE';End=0},@{Verdict='UNREADABLE';End=2},@{Verdict='READY';End=0})){
           $log=New-Name '.log';$csv=New-Name '.csv';$out=New-Name '.out'
           $at=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
           [IO.File]::WriteAllLines($log,[string[]]@("[$at] START pid=$PID host=fixture pwsh=fixture cpus=1 head=fixture concurrent=0 | generic evidence fixture",'[+ 0.001 min] PASS passing-noise fixture',"[+ 0.002 min] TOOL: $($sample.Verdict)","[+ 0.003 min] END exit=$($sample.End) total=0.003 min"))
           $w=Start-Pwsh ('-File {0} -Log {1} -Run generic-brief -PollSeconds 1 -Csv {2} -Brief' -f (Q $WatcherPath),(Q $log),(Q $csv)) $out
           $done=Wait-Exit $w 30;$o=@(Get-Content -LiteralPath $out);$rows=@(Import-Csv -LiteralPath $csv)
           $visible=@($o|Where-Object{$_-match'\] TOOL: UNREADABLE'}).Count
           $recorded=@($rows|Where-Object{$_.step-ceq("TOOL: "+$sample.Verdict)}).Count
           $expectedVisible=[int]($sample.Verdict-ceq'UNREADABLE');$expectedExit=[int]($sample.End-ne0)
           $ok=$done-and$w.ExitCode-eq$expectedExit-and$visible-eq$expectedVisible-and$recorded-eq1-and@($o|Where-Object{$_-match'\] TOOL: READY|\] PASS passing-noise'}).Count-eq0
           $passed=$passed-and$ok;$details+="$($sample.Verdict)/END$($sample.End):done=$done exit=$($w.ExitCode) visible=$visible recorded=$recorded"
       }
       [pscustomobject]@{Ok=$passed;Detail=($details-join'; ')}
   }
   ```

   b) immediately after the line
   ```text
       Check 'W37 UNREADABLE remains visible and recorded as its literal verdict' $c.Unreadable $c.Detail
   ```
   insert
   ```text
       $c = Case-GenericBrief $Watcher; Check 'W40 generic UNREADABLE is visible once, READY stays quiet, history persists and END owns reporter exit' $c.Ok $c.Detail
   ```

   c) immediately after the line
   ```text
           @{ Name = 'M36 UNREADABLE verdict dropped'; File = $Watcher; Find = '|UNREADABLE|'; Replace = '|'; Case = { param($p) $v=Case-LateBrief $p;[pscustomobject]@{Ok=$v.Unreadable;Detail=$v.Detail} } },
   ```
   insert
   ```text
           @{ Name = 'M41 generic UNREADABLE attention removed'; File = $Watcher; Find = '|INCOMPLETE|UNPROVEN|UNREADABLE|RECOVERY_EXHAUSTED|'; Replace = '|INCOMPLETE|UNPROVEN|RECOVERY_EXHAUSTED|'; Case = { param($p) Case-GenericBrief $p } },
   ```

   The resulting file's Git blob is 6dc84f48b8b9c17ae329e0958ded6ba38cb80b3c.

## Acceptance Criteria

- [ ] Exact scoped source output; `check: blob scripts/watch_run.ps1 6d337dc27eb56e6fb0aa74136ad7623f41699724`
- [ ] Exact scoped source output; `check: blob scripts/watch_selftest.ps1 6dc84f48b8b9c17ae329e0958ded6ba38cb80b3c`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @c8324e436fca8fb26d6657b539971b9bd6f78b4c`
- [ ] Actual generic UNREADABLE is visible once and recorded once, READY/passing noise stays quiet, END0/END2 retain reporter exits0/1, and the focused attention-removal mutant is detected by its actual caller.
- [ ] Existing own timing/history/redaction/ETA/concurrency/CI reporter cases remain in the unchanged owning schedule; no profile or child suite is exempted or duplicated.
- [ ] Independent Review inspects declared scope, exact allocation and original-versus-disposable evidence; no local fixture is called owner notification delivery or remote certification.

## Execution Log

None.


### 2026-10-23 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was c8324e436fca8fb26d6657b539971b9bd6f78b4c and every source anchor matched there; Draft allocated as 88b1761 and approved as dbc74fd with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `scripts/watch_run.ps1` edited exactly as the step states; blob 6d337dc27eb56e6fb0aa74136ad7623f41699724 (1 insertions, 1 deletions).
- Step 3 Applied: `scripts/watch_selftest.ps1` edited exactly as the step states; blob 6dc84f48b8b9c17ae329e0958ded6ba38cb80b3c (20 insertions, 0 deletions).
- Step 4 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

## Verification Notes

None.


### 2026-10-23 — Gate 1 approval recorded

DELEGATED exact Gate1 under actual owner continuation and expanded primary-workflow authorization; Draft SHA-256 F5A93D792D8F1B1DE1FFA13A4587B7ED8CE512B829E820F560B5AB581D6F8D4D, decision SHA-256 D1946DFF4A5305F6536500471BDCA102445A1CB05E307B30822DD2618A0933DD. No fabricated human future-digest approval. Own fresh original native verification/Review/Complete/binding required; sandbox receipt certifies no original. Immediately before allocation the hash, the Draft blob 37452257b613f495c70c06805597ce3e3f0ce53f, all 2 source anchors, the baseline HEAD c8324e436fca8fb26d6657b539971b9bd6f78b4c against refreshed origin/main c8324e436fca8fb26d6657b539971b9bd6f78b4c and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 88b1761. No implementation performed before this transition. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.


Verdict: Confirmed Complete

Independent current Git/actual evidence: selected Draft F5A93D792D8F1B1DE1FFA13A4587B7ED8CE512B829E820F560B5AB581D6F8D4D, allocated blob 37452257b613f495c70c06805597ce3e3f0ce53f, both exact source outputs, unchanged native evaluator and declared scope verified. This original root owns fresh receipt 334ef9c48d6e2284a0b234a9a7764a5e5b0fc8e8d0921b707792aa988e9be549, finishHead 6bc136521b1217390758e6eff1a600f919f3faea, derived REPOSITORY obligations and its one required watcher self-test in native timed/watched Finish, all observed PASS/END0. Actual caller/attention-removal evidence preserves generic unreadable visibility, quiet READY/history and producer-owned exit. All6 Acceptance Criteria and3 Review Gate items are supported; native Complete/range/binder still owns full receipt/criterion validation. No future binding, hosted result, client delivery, failure cause or original certification from a disposable receipt is asserted. Batch6 remains ON HOLD.

## Review Gate

- [ ] Exact literal outputs and every acceptance criterion are independently confirmed against current source and actual evidence.
- [ ] Fresh native Finish/receipt belongs to this contract/root; the required self-test ran once within that Finish, and all derived obligations passed.
- [ ] Normal native hooks and legal workflow/source scope remain intact; no unproven cause, client delivery, exemption or product/remote result is asserted.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-295: generic unreadable Brief visibility; native verification and Review complete. Publication/promotion remain separately governed. Batch6/Phase8 remain ON HOLD; CTRL-19 remains OPEN.**` and regenerate discovery. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline c8324e436fca8fb26d6657b539971b9bd6f78b4c and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `scripts/watch_run.ps1` | `ed8d956b9f2e8ebeacf1942b68424e452773641b` |
| `scripts/watch_selftest.ps1` | `e0121cf17ab38a0cfa77fc706f35c01d0ac1416f` |

Selection sources (reviewable footer): native AGENTS.md, ENGINEERING_METHOD.md section3, CR_LIFECYCLE.md section9 and the unchanged watch_run.ps1 header at c8324e436fca8fb26d6657b539971b9bd6f78b4c; https://sre.google/sre-book/monitoring-distributed-systems/ for simple actionable symptoms/low noise, and https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes for variable scope. Actual retained prototype before/after stdout/history and owning caller/attention-only removal mutant support the exact repair. V3 retains one existing reporter, preserves producer-owned exit, avoids duplicate monitors/tests and adds the narrow missing regression case. No generic hierarchy, daemon, heuristic cause classifier, profile change or invented code difference is justified. Three identified snapshots/digests and selection reasons are retained externally; correctness remains native and independent.

Snapshot identities and decision: V1 9A390BDF771862D8E908C606843A6062C5EC4DCE7CA80B125A30D648C86224A1; V2 C0BAFA87F27CCC8429FA2B44E0C80566587E456364AB851E53A8E3E629EF604B. V3 adds this reviewable evidence linkage and explicit final selection; its own raw SHA256 is external to avoid self-reference. No earlier snapshot is silently overwritten.
