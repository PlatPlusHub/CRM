# Change Request — SPEC-291

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make every Gate refuse a Git object store with missing objects, or a shallow one, before any judgment reads it, and make GitHub reads honest: CI watchers share the anonymous request budget and leave a reserve for `-Certify`, and `-Certify` reports evidence GitHub did not give as `UNREADABLE`, distinct from `PENDING` and `FAILED`.

## Business Reason

Three defects, each measured in this repository at its SPEC-290 candidate on 2026-10-20, in disposable copies:

- **A Git read that cannot finish read as "nothing there".** `git grep` exits 1 for an unreadable blob, exactly as for no match, and the reservation log and pickaxe return what they had read: with one blob missing, this repository's unguarded evaluator printed `ORVION: READY` in the pre-commit hook for an identity already in use (case OS1, Gate 1 packet `pt-store-baseline.log`). By inspection, not measurement, the same silent shape sits in the consumer search, the per-commit range walk and the evidence-character boundary; one guard before every read covers them all.
- **A shallow clone hides the history a judgment needs.** The store walk stops at a shallow boundary and passes, while the reservation lookup cannot see the history beyond it: on the unguarded evaluator the shallow fixture's reused identity was accepted at allocation (case OS3; the run then stopped only on `GIT_NOT_SYNCHRONIZED`, because the fixture boundary also cuts off the upstream).
- **A GitHub read that cannot finish read as a CI failure.** The CI watcher reads GitHub anonymously, and the 60 requests an hour per address are shared by every reader on the machine: two watchers polling every 30 s (240 an hour) spent the budget in about 15 minutes and stopped while every expected workflow was green, and a `-Certify` run made soon after printed `REMOTE_CERTIFY: FAILED` (`anonymous API could not read workflow runs for this SHA`) for two green runs. A conditional request answered 304 still costs one request; the rate-limit endpoint costs none (both measured).

Hosted CI clones complete history and judges again, so the reachable harm of the Git defects is local: a wrongly admitted commit and a red hosted run.

## Risks

Low. The guard is one shallow-clone check and one `git rev-list --objects --missing=print` over the refs the judgment walks (0.1 to 0.9 s over about 10,000 objects, warm and cold), before the first history read, in every judging mode: the pre-commit hook, Boot, the range Gate, `-BindCandidate`, `-Trusted` and Finish. `-Certify` exits before it, reads only remote conclusions, and keeps its own fail-closed local reads. An intact full clone is judged exactly as before (OS0). It refuses any clone whose objects are incomplete, a partial (`--filter`) clone included, naming the first missing object, and any shallow clone; that refusal is its purpose. It proves objects exist, not that each decompresses: a present but corrupt object, and history rewritten through `refs/replace`, stay outside it. Every workflow that runs the evaluator checks out complete history (`fetch-depth: 0`), and the trusted judge reads the trusted clone's own store. The `absent` listing check stays as a second layer, proven behind the guard (ABM5). The GitHub budget is one small ledger file in the user's temporary folder (every watcher on this machine runs as that user) holding the next free turn, locked while read and written (`ORVION_PUBLIC_BUDGET` moves it for tests); GitHub's own counter, read for free before each turn, already includes every other consumer on the address; watchers keep the last 10 requests for `-Certify` and pause until the reset instead of stopping, bounded by `-MaxWaitMinutes`; a lost or stale ledger only lets one watcher take an early turn. `UNREADABLE` exits 2, the code the watcher already uses for "GitHub could not be read"; every consumer that tests for success (exit 0, `REMOTE_CERTIFY: READY`) still sees not-ready. The control suite's fixture sets `maintenance.auto false` and `gc.auto 0`: Git 2.54's automatic maintenance packed a loose object two cases were about to lose (measured: with `gc.auto 0` alone, 250 commits left 147 of 750 objects loose; with maintenance off, all 750). This contract changes no next-work direction, routing line, pin or programme record: the manifest's Batch 6 direction and its hold are preserved. `scripts/check_agent_continuity.ps1`, both suites and `CR_LIFECYCLE.md` are control surfaces, so `-Finish` runs the CONTROL profile. CTRL-19 remains OPEN.

## Supersedes / Depends On

Depends on completed `SPEC-290`, released: remote `main` holds its candidate `94e7a39e6da7ac553842d2d2954cae38a574d45b`, this contract's baseline, and its exact-SHA remote certification read `REMOTE_CERTIFY: READY` on 2026-10-20. Supersedes nothing.

## Write Scope

- `changes/SPEC-291-a-read-that-cannot-finish-is-never-a-verdict.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/github_public_read.ps1`
- `scripts/watch_ci.ps1`
- `scripts/test_github_public_read.ps1`
- `CR_LIFECYCLE.md`
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
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/watch_selftest.ps1`
- `scripts/test_certification_receipts.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/readiness_population.ps1`
- `.workstation/doctor.ps1`
- `README.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `changes/TEMPLATE.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`

No GitHub setting, secret, ruleset, workflow or credential is changed by this contract. Batch 6 is ON HOLD by owner decision of 2026-10-18 until the owner explicitly authorizes resumption; this contract changes no next-work direction. Not here: the release interface, tracking further tools, workstation recovery, and publication or promotion by the agent.

## Required Reading

- `AGENTS.md` §§1–3
- `CR_LIFECYCLE.md` §§4–5,8–9
- `ENGINEERING_METHOD.md` §§1–3
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`: `Base-HasId`, `Get-SpecIdReservation`, `Certify-Remote`, `Inherited-Run`, the main `try` block
- `scripts/github_public_read.ps1`, `scripts/watch_ci.ps1`
- `scripts/test_agent_continuity.ps1`: `MutationKillRangeAt`, the CHECK family (AB10, ABM5), the certification cases; `scripts/test_github_public_read.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Significant

Baseline: `94e7a39e6da7ac553842d2d2954cae38a574d45b`, the `SPEC-290` candidate. Allocation is derived by the existing allocator from this repository's history (SPEC-291 is the next unreserved identity at the baseline) and is refreshed immediately before the approved Draft is committed.

Source anchors (baseline Git blobs, including read-only consumers):

| Path | Baseline blob |
| --- | --- |
| `scripts/check_agent_continuity.ps1` | `f56ec204b19a3628936d28bd02ddceabfbc68384` |
| `scripts/test_agent_continuity.ps1` | `4c9e384d8cf110bead46ff94c3a63525d5ed98ea` |
| `scripts/github_public_read.ps1` | `e7e48c45836371cb70077552731c35aab04618b5` |
| `scripts/watch_ci.ps1` | `ca87c18d3ac7fa62f70f5df681c5df18cf482699` |
| `scripts/test_github_public_read.ps1` | `d2321a05384659b26c9c299a010180690f0d6fb8` |
| `CR_LIFECYCLE.md` | `a80d15cdf805932623a0a8ea93aaae9740fac870` |
| `.github/workflows/orvion-acceptance.yml` | `b242e4c7401258404c5d43bffb49c3f53f42467e` |
| `.github/workflows/agent-control.yml` | `41243b7c9a499df4cf011385a046c53107084ba3` |
| `.github/workflows/migration-ci.yml` | `9bf8ca02d8ffac6591871b66bff53d5dbfc6e75c` |
| `.github/workflows/repository-consistency.yml` | `ed3ef8d8e954c8a2c5710fe44f46eb1f569c7492` |
| `.github/SECURITY.md` | `2b836bdf375a5fc6d0b6a8b01f4fbbed2e8bf132` |
| `scripts/check_repository_consistency.ps1` | `3e6d2810e03bfac15b96dba3bc46d119d97ad658` |
| `scripts/run_timed.ps1` | `d1fbfc81d41b04b0c8b3a50c4b17cdd19853ca60` |
| `scripts/watch_run.ps1` | `e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b` |
| `scripts/watch_selftest.ps1` | `b0a838b184a3b0b9d0928cb34e474b045624e4de` |
| `scripts/test_certification_receipts.ps1` | `c85cf120d4689633a550f45db0be005ef5de9037` |
| `scripts/publish_candidate.ps1` | `d168504cc66c3a0759ac3ee9b5e01045a0f46589` |
| `scripts/promote_main.ps1` | `bf64aa893faf9d6be7477254bebf80dca04b4d79` |
| `scripts/generate-ai-map.ps1` | `01165b8570999b79de4d6e854cae2443256e6b64` |
| `scripts/batch6_select_target.ps1` | `20e55b308088b4f5405029f02605915231246fbe` |
| `scripts/readiness_population.ps1` | `27b7f8158f506d537887fa967401ce2ef1ff45e9` |
| `.workstation/doctor.ps1` | `0ad69c87859646283c84e31df5732b2df1d42056` |
| `README.md` | `9f15270f25194e4ed0bb08613ca185a16b05ea2d` |
| `AGENTS.md` | `b2412d15cd6fcf710055114fe734ba69178f35cc` |
| `GOVERNANCE.md` | `5670c47888bbd6b4194f6c41c54476ee42cb7bdf` |
| `ENGINEERING_METHOD.md` | `874d1eefc1707dc56a9cbc41dfc3e695e2a0b726` |
| `changes/TEMPLATE.md` | `6494ecfc57e0212e8b1c35dbab46daa7f510f2f9` |
| `reports/architecture-decision-records.md` | `0bc32a7ec591cfbeeb7b26333ce66825d04c3e26` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `e957b949bc330cb637a634644664bf93bd2eb5ce` |
| `reports/master/MASTER_GAP_REGISTER.md` | `7f957064cf1c3622229e220a85ae123c63648f1c` |
| `_ORVION_CANONICAL/manifest.md` | `00272f857303b49095bcbc58e06f8bbca9515e03` |
| `ai-map.json` | `d2caec3c3c95417c994fc92679b98da9b9e7ad88` |
| `repository-index.md` | `d075792a248fc781d7012cc0296fcd8bc15a47d5` |

### Draft Assurance

Pass 1 Design: Version 1 fixed each silent Git read where it stands (exit-code checks on `Base-HasId`'s listing and grep, the reservation log and pickaxe, and the consumer search).

Pass 2 Adversarial Review: Version 2 rejected per-read fixes: `git grep` exits 1 for an unreadable blob, exactly as for no match (measured), so an exit-code check misses the proven case, and six to eight reads share one cause; one guard before the first history read closes the class and leaves the `absent` listing check as defense in depth; ABM5 pre-bypasses the guard to keep proving the listing layer, and each scenario loses its object after its last commit because committing over a lost blob fails in `write-tree`. Independent review of the frozen version 2 (PASS WITH NOTES, no blockers) found that a shallow clone passes the walk while the history beyond its boundary is unreadable, that "every mode" overstated (`-Certify` exits first), that in range mode the unguarded evaluator blocks OS2's fixture for an unrelated `NO_GOVERNING_CR` so only the hook path proves the false green, and claims without evidence in the packet. For the GitHub budget three smaller fixes were rejected on measurement: conditional requests (a 304 still costs one), a fixed 60 s floor (two watchers would still ask 120 an hour of 60), and authenticated reads (the reader is anonymous by design; CTRL-19 stays OPEN); one shared turn ledger read against GitHub's own free counter is the smallest mechanism that bounds every watcher together. A second review (PASS WITH NOTES) found a stale resume marker and wording to correct. Finally, by the owner's architecture direction, every routing line, pin and programme-record change was removed: this repository keeps its own next-work direction and names no other repository.

Pass 3 Evidence Refresh: Re-measured on 2026-10-20 in disposable copies of this repository with every edit applied: the control suite passes 595/595; the reader suite passes 86/86, and without the watcher's wait after an unreadable budget read its two cases for it fail (five failed reads in 1.0-1.5 s instead of 5.1 s); the certification-receipt suite passes 71/71 (through `run_timed`, as Finish runs it); the watcher self-test passes 62/62; the STORE family passes on the guarded evaluator and fails OS1, OS2, OS3, OSM1 and OSM2 on the unguarded one; the certification cases pass on the patched evaluator and 108c and INH-1u fail on the unpatched one (it printed FAILED); repository consistency is CLEAN. The suites ran on exactly the bytes this contract names (`git hash-object` of each tested file equals its step's blob, Gate 1 packet), and a lifecycle rehearsal rebuilt every blob from the steps.

Selected Version: Version 3: one object-store guard (incomplete store or shallow clone) and the GitHub read budget with an UNREADABLE verdict, in the existing evaluator, reader and watcher, grouped because both close one class (a read that cannot finish is never a verdict), share this baseline and the CONTROL Finish this contract runs once, so one Gate 1 and one release carry both.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| An incomplete or shallow object store is refused before any read | Every judging mode of `scripts/check_agent_continuity.ps1` | WRITE | OS0 accepts an intact store; OS1, OS2, OS3 refuse; OSM1, OSM2 kill the guard's removal |
| The same | `.github/workflows/agent-control.yml`, `.github/workflows/orvion-acceptance.yml` | UNAFFECTED | Both check out complete history (`fetch-depth: 0`); `migration-ci.yml` and `repository-consistency.yml` do not run the evaluator |
| The same | `scripts/promote_main.ps1`, `scripts/publish_candidate.ps1` | VERIFY | The trusted judge reads its clone's own store; the publisher runs the range Gate, which now also proves the store |
| AB10's damage is refused by the guard first | `scripts/test_agent_continuity.ps1` AB10, ABM5 | WRITE | AB10 expects the guard; ABM5 bypasses it to keep proving the listing layer; the fixture never packs |
| Watchers share one anonymous budget | `scripts/github_public_read.ps1`, `scripts/watch_ci.ps1` | WRITE | Every read takes a turn; a retry-after within the bound pauses; the reader suite proves exhaustion, reset, recovery, two concurrent watchers (and that without the ledger they collide), a transient failure, a bounded retry, and an unreadable budget read that waits a poll interval before retrying |
| `-Certify` names unreadable evidence | `scripts/check_agent_continuity.ps1` `-Certify`, `CR_LIFECYCLE.md` §9 | WRITE | UNREADABLE exit 2 for the runs read, an unparseable answer, a nearest-run read and the target-ref fetch; FAILED and PENDING keep their meaning (104-108, INH cases) |
| The same | `scripts/watch_selftest.ps1`, `scripts/test_certification_receipts.ps1` | UNAFFECTED | Both pass unchanged (62/62, 71/71) |
| The manifest's next-work direction and Batch 6 hold | `_ORVION_CANONICAL/manifest.md`, `GOVERNANCE.md` §6 | UNAFFECTED | Only `Active Change Request` and `Last Completed` change, by the lifecycle; pinned lines and pins are untouched |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Legal identity and admitted frozen contract | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Evaluator, suites, reader and watcher agree | BEFORE_COMPLETION | 2 | 8 | 9 |
| Generated state, scope and contract agree | BEFORE_COMPLETION | 2 | 8 | 9 |

Measured in disposable copies of this repository at the baseline with every edit applied: the full control suite passes and repository consistency is CLEAN. A lifecycle rehearsal in a disposable clone carrying this checkout's ignored certification state is recorded in the Gate 1 packet. These are preparation measurements; the derived commands run once, in the final timed Finish.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: the evaluator's main `try` block, which every judging mode already passes before its first history read; `Certify-Remote`'s existing verdict outputs; the anonymous reader all GitHub reads already use; and the control and reader suites' fixtures. No new script, hook or workflow.

Added Property: no judgment reads a Git object store that is missing an object reachable from the refs it walks, or that is shallow, and no GitHub read that did not finish is reported as a CI result.

Causal Negative: at the baseline a lost blob holding an identity's only occurrence, or a shallow boundary in front of it, makes that identity read as free, and the Gate judges on; and green runs GitHub could not be read for are certified FAILED.

Positive Test Design: an intact store is judged exactly as before, the identity refused as in use (OS0); a readable green SHA certifies READY again after an unreadable attempt (108d).

Negative Test Design: a lost blob in the hook (OS1) and in a range's reserving history (OS2), and a shallow clone whose reserving history lies beyond its boundary (OS3), are refused `OBJECT_STORE_INCOMPLETE`, never free; runs GitHub cannot read (108c) and a nearest-run query it cannot answer (INH-1u) are UNREADABLE, never FAILED; an exhausted budget stops a watcher without spending a request.

Non-Empty Population Obligation: the STORE family has accepting, refusing and mutation cases, asserted by the suite's population check; the budget cases include a causal negative (two watchers without the shared ledger collide).

Mutation Obligation: OSM1 removes the guard and OSM2 its shallow-clone refusal, and each must be killed; ABM5 removes the listing check behind a bypassed guard and must be killed.

Post-Implementation Proof Obligation: the full control suites and the REPOSITORY commands pass in one fresh timed and watched Finish on the final implementation; hosted workflow conclusions on the exact pushed SHA are proven by `-Certify`.

## Implementation Steps

1. Check that the owner's Gate 1 approval names this exact Draft's SHA-256, that `HEAD` is `94e7a39e6da7ac553842d2d2954cae38a574d45b` (the released SPEC-290, which remote `main` holds), and that every source anchor above matches at `HEAD`; if any differs, stop and report without any write. This step writes nothing beyond the allocation and approval commits the owner's command directs.
2. Check whether `scripts/check_agent_continuity.ps1` contains `function Assert-ObjectStoreComplete`; if so record Already Applied when its Git blob is d5d5b2845e7e5620afca82d9ee08aa9de23b483f, and otherwise stop and report. Otherwise make exactly these 9 edits (the object-store guard (incomplete store or shallow clone) and its single call before the first history read, and -Certify's UNREADABLE verdict for every read GitHub did not answer), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
       @($records|Sort-Object Path -Unique)
   }

   ```
   insert
   ```text
   # A read Git cannot finish is not "nothing there". `git grep` exits 1 for an unreadable blob, exactly as for
   # no match, and the listing, log and pickaxe reads that judge identity, reservation, consumers and absence
   # each returned what they had read so far: one missing object made an identity already in use read as free
   # (failure injection, 2026-10-19). Every such read meets the same object store, so the store is proven
   # complete once, for the refs the judgment walks, before any of them runs (about 0.2 s).
   function Assert-ObjectStoreComplete([string[]]$Refs){
       # A shallow clone passes the walk below, which stops at the clone's boundary, but the history beyond the boundary
       # is unreadable: in a `--depth 50` clone an identity reserved beyond the boundary read as free (measured 2026-10-20).
       $shallow=@(git -C $Root rev-parse --is-shallow-repository 2>$null);$code=$LASTEXITCODE;$global:LASTEXITCODE=0
       if($code-ne0-or"$shallow".Trim()-ne'false'){throw "OBJECT_STORE_INCOMPLETE:$(if($code){"git rev-parse exited $code"}else{'shallow clone'}) - history beyond a shallow boundary cannot be judged; fetch it whole (git fetch --unshallow) and rerun"}
       $out=@(git -C $Root rev-list --objects --missing=print @Refs -- 2>$null);$code=$LASTEXITCODE;$global:LASTEXITCODE=0
       if($code-ne0){throw "OBJECT_STORE_INCOMPLETE:git rev-list exited $code for $($Refs-join',')"}
       $missing=@($out|Where-Object{"$_".StartsWith('?')})
       if($missing.Count){throw "OBJECT_STORE_INCOMPLETE:$($missing.Count) object(s) missing, first $("$($missing[0])".Substring(1)) - a read Git cannot finish is never read as absence; repair the clone (git fetch, or a fresh clone) and rerun"}
   }
   ```

   b) replace the line
   ```text
       $no={param($why)[pscustomobject]@{Runs=@();From='';Why=$why}}
   ```
   with
   ```text
       $no={param($why,$unreadable=$null)[pscustomobject]@{Runs=@();From='';Why=$why;Unreadable=$unreadable}}
   ```

   c) replace the lines
   ```text
       try{$raw=ConvertTo-Json -InputObject @(Get-OrvionPublicRuns (Get-OrvionPublicRepo $Root) -Branch $Target -Event push -WorkflowPath $def) -Depth 10 -Compress;$LASTEXITCODE=0}catch{$raw=$null;$LASTEXITCODE=1}
       if($LASTEXITCODE-ne0-or!$raw){return (& $no "anonymous API could not read the runs of $Workflow on $Target")}
       try{$parsed=$raw|ConvertFrom-Json}catch{return (& $no "anonymous API returned runs of $Workflow this command cannot parse")}
   ```
   with
   ```text
       $readError=$null
       try{$raw=ConvertTo-Json -InputObject @(Get-OrvionPublicRuns (Get-OrvionPublicRepo $Root) -Branch $Target -Event push -WorkflowPath $def) -Depth 10 -Compress;$LASTEXITCODE=0}catch{$raw=$null;$readError=$_;$LASTEXITCODE=1}
       if($LASTEXITCODE-ne0-or!$raw){return (& $no "anonymous API could not read the runs of $Workflow on $Target" $(if($readError){$readError}else{'no answer'}))}
       try{$parsed=$raw|ConvertFrom-Json}catch{return (& $no "anonymous API returned runs of $Workflow this command cannot parse" $_)}
   ```

   d) immediately after the line
   ```text
   # this function derives nothing and adds no second authority.
   ```
   insert
   ```text
   # Evidence GitHub did not give is neither a pass nor a CI failure. On 2026-10-20 a -Certify run made while the anonymous
   # budget was spent printed FAILED for two green runs and hid the reason. UNREADABLE stays not READY and exits 2, the
   # code the CI watcher already uses for "GitHub could not be read"; it names the read, the reader's reason and, when
   # GitHub said, when a rerun can succeed. FAILED and PENDING keep meaning what the runs showed.
   function Exit-Unreadable([string]$What,$Problem){
       $why=if($Problem-is[Management.Automation.ErrorRecord]){$Problem.Exception.Message}elseif($Problem){"$Problem"}else{'no answer'}
       $retry=if($Problem-is[Management.Automation.ErrorRecord]){[long]$Problem.Exception.Data['RetryAfterSeconds']}else{0}
       $script:Outcome='REMOTE_CERTIFY: UNREADABLE';Write-Output 'REMOTE_CERTIFY: UNREADABLE'
       Write-Output "EVIDENCE: GitHub could not be read: $What ($why). Nothing about it was observed, so this is not a CI result.$(if($retry-gt0){" Rerun -Certify after $([DateTime]::UtcNow.AddSeconds($retry).ToString('HH:mm')) UTC."}else{' Rerun -Certify.'})"
       exit 2
   }
   ```

   e) replace the lines
   ```text
       try{$raw=ConvertTo-Json -InputObject @(Get-OrvionPublicRuns (Get-OrvionPublicRepo $Root) -Sha $sha -Branch $target -Event push) -Depth 10 -Compress;$LASTEXITCODE=0}catch{$raw=$null;$LASTEXITCODE=1}
       if($LASTEXITCODE-ne0-or!$raw){
           $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
           Write-Output 'EVIDENCE: anonymous API could not read workflow runs for this SHA'
           exit 1
       }
   ```
   with
   ```text
       $readError=$null
       try{$raw=ConvertTo-Json -InputObject @(Get-OrvionPublicRuns (Get-OrvionPublicRepo $Root) -Sha $sha -Branch $target -Event push) -Depth 10 -Compress;$LASTEXITCODE=0}catch{$raw=$null;$readError=$_;$LASTEXITCODE=1}
       if($LASTEXITCODE-ne0-or!$raw){Exit-Unreadable 'the workflow runs for this SHA' $readError}
   ```

   f) replace the lines
   ```text
       try{$parsed=$raw|ConvertFrom-Json}catch{
           $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
           Write-Output 'EVIDENCE: anonymous API returned evidence this command cannot parse'
           exit 1
       }
   ```
   with
   ```text
       try{$parsed=$raw|ConvertFrom-Json}catch{Exit-Unreadable 'the workflow runs for this SHA, which arrived in a form this command cannot parse' $_}
   ```

   g) immediately after the line
   ```text
           $proof=Inherited-Run $w $sha $target
   ```
   insert
   ```text
           if($proof.Unreadable){Exit-Unreadable "the runs of $w on $target, to judge its nearest run" $proof.Unreadable}
   ```

   h) replace the lines
   ```text
       if($LASTEXITCODE-ne0){
           $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
           Write-Output "EVIDENCE: TARGET_REF_UNREADABLE:$target — the remote target ref could not be read, so it cannot be proven to stand at this SHA"
           exit 1
       }
   ```
   with
   ```text
       if($LASTEXITCODE-ne0){Exit-Unreadable "TARGET_REF_UNREADABLE:$target, the remote target ref (git fetch), so this SHA cannot be proven to be where it stands" 'git fetch failed'}
   ```

   i) immediately after the lines
   ```text
           if($at-ne$want-or@(git -C $Root status --porcelain).Count){throw "TRUSTED_DATA_NOT_CANDIDATE:$Root is not a clean checkout of $want"}
       }

   ```
   insert
   ```text
       Assert-ObjectStoreComplete $(if($BaseRef){$BaseRef,$HeadRef}else{'HEAD'})
   ```

   The resulting file's Git blob is d5d5b2845e7e5620afca82d9ee08aa9de23b483f.
3. Check whether `scripts/test_agent_continuity.ps1` contains `OSM1 STORE MUTATION`; if so record Already Applied when its Git blob is 047370a65254ed92ad1c3ec89d4e6ecc2564002d, and otherwise stop and report. Otherwise make exactly these 12 edits (the range harness pre-bypass, AB10 and ABM5 behind the guard, cases OS0 to OS3, mutants OSM1 and OSM2 and the STORE family, a fixture that never packs objects, and certification cases 108c, 108d and INH-1u), each matched once, and change nothing else:

   a) replace the line
   ```text
       if($LASTEXITCODE-ne0){throw 'PUBLIC_READ:FIXTURE_UNREADABLE'}
   ```
   with
   ```text
       if($LASTEXITCODE-ne0){$e=[InvalidOperationException]::new('PUBLIC_READ:FIXTURE_UNREADABLE');if($env:ORVION_STUB_GH_RETRY){$e.Data['RetryAfterSeconds']=[long]$env:ORVION_STUB_GH_RETRY};throw $e}
   ```

   b) replace the lines
   ```text
   function MutationKillRangeAt([string]$Name,[scriptblock]$Build,[string]$Expect,[string]$Find,[string]$Replace,[string]$Family='RANGE-AUTH'){
       Reset-Fixture;$b=& $Build;$pristine=RunMutantRange $b
   ```
   with
   ```text
   function MutationKillRangeAt([string]$Name,[scriptblock]$Build,[string]$Expect,[string]$Find,[string]$Replace,[string]$Family='RANGE-AUTH',[string]$PreFind='',[string]$PreReplace=''){
       $src=Get-Content -Raw $control;$pre=$true
       if($PreFind){$pre=$src.Contains($PreFind);$src=$src.Replace($PreFind,$PreReplace)}
       Reset-Fixture;if($PreFind){Put 'scripts/check_agent_continuity.ps1' $src;CommitOnly 'scripts/check_agent_continuity.ps1' 'pre-mutant'};$b=& $Build;$pristine=RunMutantRange $b
   ```

   c) replace the lines
   ```text
       Reset-Fixture
       $src=Get-Content -Raw $control
       $applied=$src.Contains($Find)
   ```
   with
   ```text
       Reset-Fixture
       $applied=$pre-and$src.Contains($Find)
   ```

   d) replace the line
   ```text
       git -C $root config user.email test@orvion.invalid;git -C $root config user.name ORVION-Test
   ```
   with
   ```text
       git -C $root config user.email test@orvion.invalid;git -C $root config user.name ORVION-Test;git -C $root config gc.auto 0;git -C $root config maintenance.auto false
   ```

   e) immediately after the line
   ```text
   Add-Content -LiteralPath $env:ORVION_STUB_GH_LOG -Value "gh $($a -join ' ')"
   ```
   insert
   ```text
   if($env:ORVION_STUB_GH_UNREADABLE-and($env:ORVION_STUB_GH_UNREADABLE-eq'all'-or$a-contains'--workflow')){'unreadable';exit 1}
   ```

   f) immediately after the line
   ```text
       Assert '108 MUST-ACCEPT: every expected workflow observed and successful on the exact SHA is READY' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY'-and$r.Text-match"SHA: $sha") $r.Text
   ```
   insert
   ```text
       # GitHub that cannot be read is UNREADABLE (exit 2): not a CI failure, not success, with the reason and the rerun time.
       $env:ORVION_STUB_GH_UNREADABLE='all';$env:ORVION_STUB_GH_RETRY='600';$r=RunCertify
       Remove-Item Env:ORVION_STUB_GH_UNREADABLE,Env:ORVION_STUB_GH_RETRY -ErrorAction SilentlyContinue
       Assert '108c green runs GitHub cannot read are UNREADABLE with the reason and rerun time, never FAILED or READY' ($r.Code-eq2-and$r.Text-match'REMOTE_CERTIFY: UNREADABLE'-and$r.Text-match'FIXTURE_UNREADABLE'-and$r.Text-match'Rerun -Certify after \d\d:\d\d UTC'-and$r.Text-notmatch'REMOTE_CERTIFY: (FAILED|PENDING|READY)') $r.Text
       $r=RunCertify
       Assert '108d once GitHub can be read again the same SHA certifies READY' ($r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY') $r.Text
   ```

   g) replace the line
   ```text
       function InhRestore{Remove-Item Env:ORVION_STUB_GH_PERMISSIVE -ErrorAction SilentlyContinue;git -C $root checkout main --quiet 2>$null;git -C $root push origin +"$($script:iB):refs/heads/main" --quiet 2>$null;git -C $root fetch origin --quiet 2>$null}
   ```
   with
   ```text
       function InhRestore{Remove-Item Env:ORVION_STUB_GH_PERMISSIVE,Env:ORVION_STUB_GH_UNREADABLE -ErrorAction SilentlyContinue;git -C $root checkout main --quiet 2>$null;git -C $root push origin +"$($script:iB):refs/heads/main" --quiet 2>$null;git -C $root fetch origin --quiet 2>$null}
   ```

   h) immediately after the line
   ```text
       InhCase 'INH-1 MUST-ACCEPT: a bookkeeping head after a green implementation carries Db forward and is READY' 'accept' {InhImpl} {param($r)$r.Code-eq0-and$r.Text-match'REMOTE_CERTIFY: READY'-and$r.Text-match"INHERITED: Db from $($script:iS) run \d+ attempt 1 completed/success"}
   ```
   insert
   ```text
       InhCase 'INH-1u a nearest run GitHub cannot read is UNREADABLE, never NOT INHERITED or FAILED' 'reject' {InhImpl;$env:ORVION_STUB_GH_UNREADABLE='workflow'} {param($r)$r.Code-eq2-and$r.Text-match'REMOTE_CERTIFY: UNREADABLE'-and$r.Text-match'the runs of Db on main'-and$r.Text-notmatch'NOT INHERITED|REMOTE_CERTIFY: FAILED'}
   ```

   i) replace the line
   ```text
       Assert 'AB10 CHECK: an absent check Git cannot list is refused as indeterminate, never held' ($r.Code-ne0-and$r.Text-match'CRITERION_CHECK_INDETERMINATE:retired\.txt.*@[0-9a-f]{7}'-and$r.Text-notmatch'ORVION: READY') $r.Text
   ```
   with
   ```text
       Assert 'AB10 CHECK: an absent check Git cannot list is refused, never held' ($r.Code-ne0-and$r.Text-match'OBJECT_STORE_INCOMPLETE'-and$r.Text-notmatch'ORVION: READY') $r.Text
   ```

   j) replace the lines
   ```text
       MutationKillRangeAt 'ABM5 CHECK MUTATION: a failed listing is indeterminate, not absent' {ChLost -NoReset} 'CRITERION_CHECK_INDETERMINATE' `
           'if($LASTEXITCODE-ne0){throw "CRITERION_CHECK_INDETERMINATE' 'if($false){throw "CRITERION_CHECK_INDETERMINATE' 'CHECK'
   ```
   with
   ```text
       MutationKillRangeAt 'ABM5 CHECK MUTATION: behind the store guard, a failed listing is indeterminate, not absent' {ChLost -NoReset} 'CRITERION_CHECK_INDETERMINATE' `
           'if($LASTEXITCODE-ne0){throw "CRITERION_CHECK_INDETERMINATE' 'if($false){throw "CRITERION_CHECK_INDETERMINATE' 'CHECK' `
           'Assert-ObjectStoreComplete $(if' '$null=$(if'
   ```

   k) immediately after the lines
   ```text
       ChFound

   ```
   insert
   ```text
       # OBJECT STORE. A missing blob made an identity already in use read as free: `git grep` exits 1 for an
       # unreadable blob as for no match, and the reservation log and pickaxe returned what they had read. The
       # Gate now proves the store complete before any read. Moved objects are put back after each run.
       # An object is lost only after the last commit of a scenario: committing over a missing blob fails.
       $script:osLost=@()
       function OsLose([string]$Blob){$o=Join-Path $root ".git/objects/$($Blob.Substring(0,2))/$($Blob.Substring(2))";$k=Join-Path $sandbox "os-lost-$Blob"
           if(Test-Path -LiteralPath $k){Remove-Item -LiteralPath $o}else{Move-Item -LiteralPath $o -Destination $k;$script:osLost+=,@($k,$o)}}
       function OsFound{foreach($x in $script:osLost){Move-Item -LiteralPath $x[0] -Destination $x[1]};$script:osLost=@()}
       # Each note is unique, so its blob is new and loose: a repeated content's blob may already be packed.
       function OsNote{"historical note naming $(FxId 1) once $([guid]::NewGuid().ToString('N'))"}
       # The identity's only occurrence is a deleted note's content, so only the reservation log and pickaxe read it.
       function OsBuild([switch]$NoReset){
           if(-not$NoReset){OsFound;Reset-Fixture}
           Put 'changes/SPEC-900-fixture.md' (ContractText -Status Draft);Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None');Commit 'plan-baseline'
           Put 'lineage.txt' (OsNote);Commit 'reserve-text'
           $blob=(git -C $root rev-parse 'HEAD:lineage.txt').Trim();git -C $root rm -q 'lineage.txt';Commit 'delete-text'
           $b=(git -C $root rev-parse HEAD).Trim();Put "changes/$(FxId 1)-reuse.md" (ContractText -Id (FxId 1) -Status Draft);Commit 'reuse'
           OsLose $blob;$b
       }
       ReservedPresentSetup;$r=Run 'Gate'
       Assert 'OS0 STORE: a complete object store is judged as before (the identity is in use)' ($r.Code-ne0-and$r.Text-match'SPEC_ID_ALREADY_USED'-and$r.Text-notmatch'OBJECT_STORE_INCOMPLETE') $r.Text
       Pop 'STORE' 'accept'
       OsFound;PlanBaseline;Put 'lineage.txt' (OsNote);Commit 'reserve-present';Put "changes/$(FxId 1)-reuse.md" (ContractText -Id (FxId 1) -Status Draft)
       OsLose (git -C $root rev-parse 'HEAD:lineage.txt').Trim();$r=Run 'Gate';OsFound
       Assert 'OS1 STORE: an identity whose only occurrence Git cannot read is refused, never free' ($r.Code-ne0-and$r.Text-match'OBJECT_STORE_INCOMPLETE'-and$r.Text-notmatch'SPEC_ID_ALREADY_USED|ORVION: READY') $r.Text
       Pop 'STORE' 'reject'
       $b=OsBuild;$r=RunRange $b;OsFound
       Assert 'OS2 STORE: a range whose reserving history Git cannot read is refused' ($r.Code-ne0-and$r.Text-match'OBJECT_STORE_INCOMPLETE'-and$r.Text-notmatch'ORVION: READY') $r.Text
       Pop 'STORE' 'reject'
       MutationKillRangeAt 'OSM1 STORE MUTATION: an incomplete store is refused before any read' {OsBuild -NoReset} 'OBJECT_STORE_INCOMPLETE' `
           'Assert-ObjectStoreComplete $(if' '$null=$(if' 'STORE'
       OsFound
       # A shallow clone has every object the walk reaches, but not the history beyond its boundary, where the
       # identity's reservation lives. The boundary is the deleting commit, so only the reserving commit is cut off.
       # Judged in the hook, as OS1 is; there the unguarded evaluator accepts the reused identity at allocation.
       $shallowFile=Join-Path $root '.git/shallow'
       function OsShallowSetup{
           PlanBaseline;Put 'lineage.txt' (OsNote);Commit 'reserve-text';git -C $root rm -q 'lineage.txt';Commit 'delete-text'
           [IO.File]::WriteAllText($shallowFile,"$((git -C $root rev-parse HEAD).Trim())`n")
           Put "changes/$(FxId 1)-reuse.md" (ContractText -Id (FxId 1) -Status Draft)
       }
       OsShallowSetup;$r=Run 'Gate';Remove-Item -LiteralPath $shallowFile
       Assert 'OS3 STORE: a shallow clone, whose reserving history lies beyond its boundary, is refused, never free' ($r.Code-ne0-and$r.Text-match'OBJECT_STORE_INCOMPLETE:shallow clone'-and$r.Text-notmatch'ORVION: READY') $r.Text
       Pop 'STORE' 'reject'
       MutationKill 'OSM2 STORE MUTATION: a shallow clone is refused, not judged on cut-off history' {OsShallowSetup} 'OBJECT_STORE_INCOMPLETE:shallow clone' `
           '"$shallow".Trim()-ne''false''' '$false' 'STORE'
       Remove-Item -LiteralPath $shallowFile -ErrorAction SilentlyContinue

   ```

   l) replace the line
   ```text
       foreach($family in @('D','F','HJ','APPLIC','WC','CTRL1','CTRL4','RANGE-AUTH','ORIGIN','K-local','K-reservation','K-activation','K-range','CERT-INHERIT','SEG-CARRY','PARITY','CHECK','DA','PIN','ACI','TRUST','PROMOTE','TIME')){
   ```
   with
   ```text
       foreach($family in @('D','F','HJ','APPLIC','WC','CTRL1','CTRL4','RANGE-AUTH','ORIGIN','K-local','K-reservation','K-activation','K-range','CERT-INHERIT','SEG-CARRY','PARITY','CHECK','STORE','DA','PIN','ACI','TRUST','PROMOTE','TIME')){
   ```

   The resulting file's Git blob is 047370a65254ed92ad1c3ec89d4e6ecc2564002d.
4. Check whether `scripts/github_public_read.ps1` contains `function Wait-OrvionPublicSlot`; if so record Already Applied when its Git blob is 97f5c8894e5772e5a46e792aef927c5055e402b2, and otherwise stop and report. Otherwise make exactly this one edit (the shared anonymous budget: the free rate-limit read, the turn ledger in the user's temporary folder and the Certify reserve), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
       } finally {$proc.Dispose()}
   }
   ```
   insert
   ```text

   # ---- the shared anonymous budget ------------------------------------------------------------------------
   # GitHub allows 60 anonymous requests an hour per IP address, shared by every reader on this machine and by anything
   # else behind the same address. Two watchers polling every 30 s spent it in about 15 minutes and stopped while CI was
   # green, and a -Certify run right after then read nothing (2026-10-20). GitHub's own counter is the truth and
   # `/rate_limit` reads it without spending (measured: `used` unchanged across the call). Watchers take turns through one
   # small machine-local ledger holding the next free poll time, so N watchers split what is left instead of each spending
   # all of it, and they never spend the last $script:OrvionPublicReserve requests, which stay for -Certify.
   $script:OrvionPublicReserve = 10
   $script:OrvionPublicLedger = if ($env:ORVION_PUBLIC_BUDGET) { $env:ORVION_PUBLIC_BUDGET } else { Join-Path ([IO.Path]::GetTempPath()) 'orvion-github-public-budget.json' }
   function Get-OrvionPublicBudget {
       $j = Read-OrvionPublicJson ([uri]'https://api.github.com/rate_limit')
       $c = $j.resources.core
       if ($c -isnot [Collections.IDictionary] -or $c.remaining -isnot [long] -and $c.remaining -isnot [int] -or $c.reset -isnot [long] -and $c.reset -isnot [int]) { throw 'PUBLIC_READ:RATE_LIMIT_SHAPE' }
       [pscustomobject]@{ Remaining = [long]$c.remaining; Reset = [long]$c.reset }
   }
   # Blocks until this caller may spend one request. Emits one PAUSED line before any wait for the reset (pipe it to the log).
   # Throws PUBLIC_READ:BUDGET_EXHAUSTED when the reset is further away than -MaxWaitSeconds.
   function Wait-OrvionPublicSlot([int]$MinSeconds = 60, [int]$MaxWaitSeconds = 3600) {
       while ($true) {
           $lock = $null
           for ($i = 0; -not $lock; $i++) {
               try { $lock = [IO.File]::Open("$script:OrvionPublicLedger.lock", 'OpenOrCreate', 'ReadWrite', 'None') }
               catch { if ($i -ge 300) { throw 'PUBLIC_READ:BUDGET_LOCK' }; Start-Sleep -Milliseconds 100 }
           }
           try {
               $next = 0L
               if (Test-Path -LiteralPath $script:OrvionPublicLedger) { [void][long]::TryParse(([IO.File]::ReadAllText($script:OrvionPublicLedger)).Trim(), [ref]$next) }
               $b = Get-OrvionPublicBudget
               $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()   # milliseconds: whole seconds let two turns land 1.1 s apart
               $spendable = $b.Remaining - $script:OrvionPublicReserve
               if ($spendable -le 0) { $wait = [Math]::Max(1000, $b.Reset * 1000 - $now + 1000) }
               else {
                   $spacing = [long][Math]::Max($MinSeconds * 1000, [Math]::Ceiling([Math]::Max(1000, $b.Reset * 1000 - $now) / $spendable))
                   $slot = [Math]::Max($now, $next)
                   [IO.File]::WriteAllText($script:OrvionPublicLedger, "$($slot + $spacing)")
                   $wait = $slot - $now
               }
           } finally { $lock.Dispose() }
           if ($spendable -gt 0) { if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }; return }
           $waitSeconds = [long][Math]::Ceiling($wait / 1000)
           if ($waitSeconds -gt $MaxWaitSeconds) { $e = [InvalidOperationException]::new("PUBLIC_READ:BUDGET_EXHAUSTED:retry_after=$waitSeconds"); $e.Data['RetryAfterSeconds'] = $waitSeconds; throw $e }
           "PAUSED: the anonymous GitHub budget is down to its Certify reserve ($($b.Remaining) left); resuming after the reset at $([DateTimeOffset]::FromUnixTimeSeconds($b.Reset).UtcDateTime.ToString('HH:mm')) UTC"
           Start-Sleep -Milliseconds $wait
       }
   }
   ```

   The resulting file's Git blob is 97f5c8894e5772e5a46e792aef927c5055e402b2.
5. Check whether `scripts/watch_ci.ps1` contains `Wait-OrvionPublicSlot $PollSeconds`; if so record Already Applied when its Git blob is 738cb36667d4d9bef8182580c9115bc303a96329, and otherwise stop and report. Otherwise make exactly these 7 edits (every read takes its turn in the shared budget; a retry-after within -MaxWaitMinutes pauses instead of stopping; any other failed poll waits one poll interval), each matched once, and change nothing else:

   a) replace the line
   ```text
       [int]$PollSeconds = 30,
   ```
   with
   ```text
       [int]$PollSeconds = 60,      # the floor; the shared budget (github_public_read.ps1) spaces polls further when it must
       [double]$MaxWaitMinutes = 60,
   ```

   b) replace the line
   ```text
       try { $jobs = @(Get-OrvionPublicJobs $Repo $Id $Att) }
   ```
   with
   ```text
       try { Wait-OrvionPublicSlot 0 ($MaxWaitMinutes*60); $jobs = @(Get-OrvionPublicJobs $Repo $Id $Att) }
   ```

   c) replace the line
   ```text
           try { $log = @(Get-OrvionPublicLog $Repo $j.id) }
   ```
   with
   ```text
           try { Wait-OrvionPublicSlot 0 ($MaxWaitMinutes*60); $log = @(Get-OrvionPublicLog $Repo $j.id) }
   ```

   d) replace the line
   ```text
       try { $v = Get-OrvionPublicAttempt $Repo $RunId $Attempt }
   ```
   with
   ```text
       try { Wait-OrvionPublicSlot 0 ($MaxWaitMinutes*60); $v = Get-OrvionPublicAttempt $Repo $RunId $Attempt }
   ```

   e) replace the line
   ```text
           # The adapter throws on incomplete or unreadable evidence; never treat an outage as no runs.
   ```
   with
   ```text
           # Every poll takes its turn in the shared budget first. The adapter throws on incomplete or unreadable
           # evidence; never treat an outage as no runs.
           Wait-OrvionPublicSlot $PollSeconds ($MaxWaitMinutes*60) | ForEach-Object { "$(T) $_" }
   ```

   f) replace the lines
   ```text
           if ($retry -gt 60) { "$(T) STOPPED: public API retry-after=$retry seconds; resume later; evidence unreadable"; exit 2 }
           Start-Sleep -Seconds ([Math]::Max($PollSeconds,$retry)); continue
   ```
   with
   ```text
           if ($retry -gt $MaxWaitMinutes*60) { "$(T) STOPPED: public API retry-after=$retry seconds is beyond -MaxWaitMinutes $MaxWaitMinutes; evidence unreadable"; exit 2 }
           if ($retry -gt 0) { "$(T) PAUSED: public API retry-after=$retry seconds"; Start-Sleep -Seconds $retry }
           else { "$(T) retrying in $PollSeconds s"; Start-Sleep -Seconds $PollSeconds }   # an unreadable budget grants no turn to space the retry
           continue
   ```

   g) replace the lines
   ```text
       }
       Start-Sleep -Seconds $PollSeconds
   ```
   with
   ```text
       }
   ```

   The resulting file's Git blob is 738cb36667d4d9bef8182580c9115bc303a96329.
6. Check whether `scripts/test_github_public_read.ps1` contains `budget: two concurrent watchers take turns`; if so record Already Applied when its Git blob is df7d4616b6f46c050feede9022fde7897877dffc, and otherwise stop and report. Otherwise make exactly these 7 edits (the fixture rate-limit counter and the budget cases: exhaustion, reset, recovery, two concurrent watchers with their causal negative, a transient failure, a bounded retry and an unreadable budget read), each matched once, and change nothing else:

   a) immediately after the line
   ```text
    public TcpListener Listener; public Thread Worker; public int Port; volatile bool Done;
   ```
   insert
   ```text
    public long Remaining=60; public long Reset=0; public long Window=3600; public int RateReads=0; public int RateFail=0;
   ```

   b) replace the line
   ```text
    void Loop(){while(!Done){try{using(var c=Listener.AcceptTcpClient()){c.ReceiveTimeout=2000;var s=c.GetStream();var reader=new StreamReader(s,Encoding.ASCII,false,1024,true);string line=reader.ReadLine(),h;var req=line+"\n";while(!String.IsNullOrEmpty(h=reader.ReadLine())) req+=h+"\n";Requests.Enqueue(req);string reply;if(!Replies.TryDequeue(out reply))reply="HTTP/1.1 500 Missing fixture\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";if(reply.StartsWith("BODYDELAY")){reply=reply.Substring(9);int k=reply.IndexOf("\r\n\r\n")+4;byte[] hbytes=Encoding.UTF8.GetBytes(reply.Substring(0,k));s.Write(hbytes,0,hbytes.Length);Thread.Sleep(1800);reply=reply.Substring(k);}byte[] b=Encoding.UTF8.GetBytes(reply);s.Write(b,0,b.Length);}}catch{if(Done)return;}}}
   ```
   with
   ```text
    void Loop(){while(!Done){try{using(var c=Listener.AcceptTcpClient()){c.ReceiveTimeout=2000;var s=c.GetStream();var reader=new StreamReader(s,Encoding.ASCII,false,1024,true);string line=reader.ReadLine(),h;var req=line+"\n";while(!String.IsNullOrEmpty(h=reader.ReadLine())) req+=h+"\n";string reply;if(line!=null&&line.StartsWith("GET /rate_limit")){RateReads++;if(RateFail>0){RateFail--;byte[] fb=Encoding.UTF8.GetBytes("HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");s.Write(fb,0,fb.Length);continue;}long now=DateTimeOffset.UtcNow.ToUnixTimeSeconds();if(Reset==0||now>=Reset){if(Reset!=0)Remaining=60;Reset=now+Window;}string body="{\"resources\":{\"core\":{\"limit\":60,\"remaining\":"+Remaining+",\"reset\":"+Reset+",\"used\":"+(60-Remaining)+"}}}";reply="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "+Encoding.UTF8.GetByteCount(body)+"\r\nConnection: close\r\n\r\n"+body;byte[] rb=Encoding.UTF8.GetBytes(reply);s.Write(rb,0,rb.Length);continue;}Requests.Enqueue(req);if(!Replies.TryDequeue(out reply))reply="HTTP/1.1 500 Missing fixture\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";if(reply.StartsWith("BODYDELAY")){reply=reply.Substring(9);int k=reply.IndexOf("\r\n\r\n")+4;byte[] hbytes=Encoding.UTF8.GetBytes(reply.Substring(0,k));s.Write(hbytes,0,hbytes.Length);Thread.Sleep(1800);reply=reply.Substring(k);}byte[] b=Encoding.UTF8.GetBytes(reply);s.Write(b,0,b.Length);}}catch{if(Done)return;}}}
   ```

   c) immediately after the line
   ```text
   $probe=Join-Path $work 'adapter.ps1'; [IO.File]::WriteAllText($probe,$original)
   ```
   insert
   ```text
   $env:ORVION_PUBLIC_BUDGET=Join-Path $work 'budget.json'  # this suite's own ledger, never the machine's (set before the adapter loads)
   ```

   d) immediately after the lines
   ```text
   $env:ORVION_PUBLIC_BUDGET=Join-Path $work 'budget.json'  # this suite's own ledger, never the machine's (set before the adapter loads)
   . $probe
   ```
   insert
   ```text
   function Budget([long]$Remaining,[int]$ResetIn=3600){$server.Remaining=$Remaining;$server.Reset=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+$ResetIn;if(Test-Path -LiteralPath $env:ORVION_PUBLIC_BUDGET){[IO.File]::Delete($env:ORVION_PUBLIC_BUDGET)}}
   ```

   e) immediately after the line
   ```text
       Check 'real HTTP inaccessible port fails closed' (Refuses {Invoke-OrvionPublicHttp ([uri]"http://127.0.0.1:$port/") 1} 'TRANSPORT_UNREADABLE')
   ```
   insert
   ```text
       # Watcher cases below run under a two-second budget window, so polls are spaced about a second apart.
       $server.Window=2;Budget 60 2
   ```

   f) replace the lines
   ```text
       $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo owner/repo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 2>&1
       Check 'actual watcher honors long rate-limit retry by stopping after one unreadable poll' ($LASTEXITCODE-eq2-and($o|Out-String)-match'STOPPED: public API retry-after=120'-and$server.Requests.Count-eq$count+1) ($o|Out-String)
   ```
   with
   ```text
       $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo owner/repo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 -MaxWaitMinutes 1 2>&1
       Check 'actual watcher honors long rate-limit retry by stopping after one unreadable poll' ($LASTEXITCODE-eq2-and($o|Out-String)-match'STOPPED: public API retry-after=120 seconds is beyond -MaxWaitMinutes 1'-and$server.Requests.Count-eq$count+1) ($o|Out-String)
   ```

   g) immediately after the line
   ```text
       Check 'actual watcher polling diagnostic gap exits unreadable immediately' ($LASTEXITCODE-eq2-and($o|Out-String)-match'STOPPED: diagnostics unreadable') ($o|Out-String)
   ```
   insert
   ```text
       # The watcher cases use this repository's own watcher identity.
       $wRepo='owner/repo';$wRow={Row}
       # THE SHARED BUDGET. GitHub's anonymous 60 an hour is shared by every reader on the address; the rate-limit
       # endpoint costs nothing and is answered here by the fixture's counter, which refills at its reset.
       Budget 11 30; $sw=[Diagnostics.Stopwatch]::StartNew(); $null=Wait-OrvionPublicSlot 0 60; $next=[long][IO.File]::ReadAllText($env:ORVION_PUBLIC_BUDGET)
       Check 'budget: with one spendable request the slot is immediate and the next is spaced to the reset' ($sw.Elapsed.TotalSeconds-lt3-and$next-ge([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+27000))
       $server.Window=3600; Budget 10 3; $sw=[Diagnostics.Stopwatch]::StartNew(); $said=@(Wait-OrvionPublicSlot 0 60)
       Check 'budget: at the Certify reserve a watcher pauses until the reset, says so, and resumes' ($sw.Elapsed.TotalSeconds-ge2-and($said-join' ')-match'PAUSED: .*Certify reserve \(10 left\)'-and$server.Remaining-eq60)
       Budget 5 600; Check 'budget: a reset beyond the wait bound is refused, not waited for' (Refuses {Wait-OrvionPublicSlot 0 60} 'BUDGET_EXHAUSTED:retry_after=')
       $count=$server.Requests.Count
       $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo $wRepo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 -MaxWaitMinutes 1 2>&1
       Check 'budget: an exhausted budget stops the watcher without spending a request' ($LASTEXITCODE-eq2-and($o|Out-String)-match'STOPPED: public API retry-after=\d+ seconds is beyond'-and$server.Requests.Count-eq$count) ($o|Out-String)
       # Two watchers at once: each records when it was let through; the shared ledger keeps them a spacing apart.
       $probeSlots={param([string]$Ledger,[string]$Out)
           $job={param($Probe,$Ledger,$Out)$env:ORVION_PUBLIC_BUDGET=$Ledger;. $Probe;foreach($k in 1,2){$null=Wait-OrvionPublicSlot 2 60;[IO.File]::AppendAllText($Out,"$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())`n")}}
           $j=@(1,2|ForEach-Object{Start-Job -ScriptBlock $job -ArgumentList $probe,$(if($Ledger-like'*own*'){$Ledger.Replace('.json',"-$_.json")}else{$Ledger}),$Out});$null=$j|Wait-Job -Timeout 60;$j|Remove-Job -Force
           $ms=@([IO.File]::ReadAllLines($Out)|ForEach-Object{[long]$_}|Sort-Object);@(for($i=1;$i-lt$ms.Count;$i++){$ms[$i]-$ms[$i-1]})}
       $server.Window=3600; Budget 21 20; $gaps=@(& $probeSlots $env:ORVION_PUBLIC_BUDGET (Join-Path $work 'slots-shared.txt'))
       Check "budget: two concurrent watchers take turns, never closer than the shared 2 s floor (gaps $($gaps-join', ') ms)" ($gaps.Count-eq3-and@($gaps|Where-Object{$_-lt1900}).Count-eq0)
       Budget 21 20; $gaps=@(& $probeSlots (Join-Path $work 'own-a.json') (Join-Path $work 'slots-own.txt'))
       Check "budget: the same two watchers with no shared ledger would collide (causal negative, gaps $($gaps-join', ') ms)" (@($gaps|Where-Object{$_-lt1900}).Count-gt0)
       $server.Window=2; Budget 60 2
       $r=& $wRow;$r.head_sha=$head;$server.Replies.Enqueue('garbage');Reply (Payload @($r));Reply (Payload @($r))
       $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo $wRepo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 2>&1
       Check 'budget: a transient transport failure costs one turn, and the watch recovers' ($LASTEXITCODE-eq0-and($o|Out-String)-match'poll failed \(1 of 5\): PUBLIC_READ:TRANSPORT_UNREADABLE'-and($o|Out-String)-match'every expected workflow ran and succeeded') ($o|Out-String)
       Reply '{}' 429 "Retry-After: 2`r`n";Reply (Payload @($r));Reply (Payload @($r))
       $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo $wRepo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 2>&1
       Check 'budget: a short retry-after pauses within the bound and the watch recovers' ($LASTEXITCODE-eq0-and($o|Out-String)-match'PAUSED: public API retry-after=2 seconds'-and($o|Out-String)-match'every expected workflow ran and succeeded') ($o|Out-String)
       $server.RateFail=1;Reply (Payload @($r));Reply (Payload @($r))
       $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo $wRepo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 2>&1
       Check 'budget: an unreadable budget read waits one poll before retrying, and the watch recovers' ($LASTEXITCODE-eq0-and($o|Out-String)-match'poll failed \(1 of 5\): PUBLIC_READ:'-and($o|Out-String)-match'retrying in 0 s'-and($o|Out-String)-match'every expected workflow ran and succeeded') ($o|Out-String)
       $server.RateFail=5;$sw=[Diagnostics.Stopwatch]::StartNew()
       $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo $wRepo -RepoRoot $work -PollSeconds 1 -SettleSeconds 0 2>&1
       Check "budget: five unreadable budget reads stop only after a poll interval between each ($('{0:N1}'-f$sw.Elapsed.TotalSeconds) s)" ($LASTEXITCODE-eq2-and($o|Out-String)-match'five consecutive polls failed'-and$sw.Elapsed.TotalSeconds-ge4) ($o|Out-String)
       $server.RateFail=0
   ```

   The resulting file's Git blob is df7d4616b6f46c050feede9022fde7897877dffc.
7. Check whether `CR_LIFECYCLE.md` contains `means GitHub could not be read`; if so record Already Applied when its Git blob is bcebabb0665901fa1ebf1b7e28ddbbecddeb5f68, and otherwise stop and report. Otherwise make exactly this one edit (the -Certify verdicts gain UNREADABLE), each matched once, and change nothing else:

   a) replace the line
   ```text
   `-Certify` is that post-push observation, and it is the only thing entitled to make it: run from the repository root once `main` holds `HEAD`, it reads the workflow conclusions recorded against the exact current `HEAD` SHA and reports `REMOTE_CERTIFY: READY`, `PENDING` or `FAILED`. It asserts nothing it did not read. One expected workflow may stand on an earlier run, and only under proof (`SPEC-263`): a path-filtered workflow GitHub did not start on that SHA is judged by its nearest push run on the target branch at an ancestor of `HEAD`, provided git shows that no path it watches, and not its own definition, differs between the two SHAs. That run is judged exactly as one on `HEAD` would be; anything short of that proof is `REQUIRED_WORKFLOW_MISSING`.
   ```
   with
   ```text
   `-Certify` is that post-push observation, and it is the only thing entitled to make it: run from the repository root once `main` holds `HEAD`, it reads the workflow conclusions recorded against the exact current `HEAD` SHA and reports `REMOTE_CERTIFY: READY`, `PENDING`, `FAILED` or `UNREADABLE`. `UNREADABLE` (exit 2) means GitHub could not be read, so nothing about the runs was observed: it is never a CI result and never READY, and a rerun after the reset it names decides. It asserts nothing it did not read. One expected workflow may stand on an earlier run, and only under proof (`SPEC-263`): a path-filtered workflow GitHub did not start on that SHA is judged by its nearest push run on the target branch at an ancestor of `HEAD`, provided git shows that no path it watches, and not its own definition, differs between the two SHAs. That run is judged exactly as one on `HEAD` would be; anything short of that proof is `REQUIRED_WORKFLOW_MISSING`.
   ```

   The resulting file's Git blob is bcebabb0665901fa1ebf1b7e28ddbbecddeb5f68.
8. Check whether the Runtime Checkpoint reads `Resume Step: DONE`; if so record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, confirm `pwsh -NoProfile -File scripts/generate-ai-map.ps1 -Check` exits 0 and that `git status --porcelain` names only Write Scope paths, append the Execution Log entry, set the Runtime Checkpoint to `Resume Step: DONE`, `Blocker: None`, `Recovery Attempt: 0`, and commit the implementation and checkpoint together through the unchanged pre-commit hook.
9. Check that a fresh native receipt for this contract matches, a `Verdict: Confirmed Complete` Verification Notes entry exists and every Acceptance Criterion and Review Gate item holds; only then record Already Applied. Otherwise, from the repository root, start `pwsh -NoProfile -File scripts/run_timed.ps1 -Log <log> -Command "pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish"` and, at the same time, `pwsh -NoProfile -File scripts/watch_run.ps1 -Log <log> -Run finish-control -Brief`, with `<log>` outside the checkout. Require `LOCAL_CERTIFY: READY`; a failed command keeps its real exit code and evidence and starts bounded recovery without weakening any assertion. Perform independent live Review against the repository and append its Verification Notes verdict. Then complete through the native lifecycle with the unchanged pre-commit hook, setting `manifest.md`'s `Active Change Request` to `None.` and its `Last Completed` to exactly `Last Completed: **SPEC-291: a Git or GitHub read that cannot finish is never a verdict: every Gate refuses an incomplete or shallow object store, CI watchers share one bounded anonymous budget, and -Certify reports unreadable evidence as UNREADABLE — fresh local verification and Review complete; owner publication/promotion and exact-SHA remote certification follow `CR_LIFECYCLE.md` §9. Batch 6 remains ON HOLD by owner decision (2026-10-18) until the infrastructure programme completes and the owner authorizes resumption. CTRL-19 remains OPEN.**`, regenerating the projections with the existing generator. Locally prepare the exact candidate with `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BindCandidate -Root <original-checkout> -BaseRef <full-main-SHA> -HeadRef <full-candidate-SHA>`. Stop before publication or promotion.

## Acceptance Criteria

- [ ] The evaluator, both control suites, the reader, the watcher and the lifecycle hold exactly the reviewed bytes. `check: blob scripts/check_agent_continuity.ps1 d5d5b2845e7e5620afca82d9ee08aa9de23b483f` `check: blob scripts/test_agent_continuity.ps1 047370a65254ed92ad1c3ec89d4e6ecc2564002d` `check: blob scripts/github_public_read.ps1 97f5c8894e5772e5a46e792aef927c5055e402b2` `check: blob scripts/watch_ci.ps1 738cb36667d4d9bef8182580c9115bc303a96329` `check: blob scripts/test_github_public_read.ps1 df7d4616b6f46c050feede9022fde7897877dffc` `check: blob CR_LIFECYCLE.md bcebabb0665901fa1ebf1b7e28ddbbecddeb5f68`
- [ ] Every judging mode refuses an incomplete object store or a shallow clone before any read, and the suite kills the removal of each. `check: has scripts/check_agent_continuity.ps1 "OBJECT_STORE_INCOMPLETE:"` `check: has scripts/check_agent_continuity.ps1 "rev-parse --is-shallow-repository"` `check: has scripts/test_agent_continuity.ps1 "OSM1 STORE MUTATION"` `check: has scripts/test_agent_continuity.ps1 "OSM2 STORE MUTATION"`
- [ ] `-Certify` reports evidence GitHub did not give as UNREADABLE (exit 2), never FAILED or READY, and CI watchers share one bounded anonymous budget that leaves a reserve for `-Certify`. `check: has scripts/check_agent_continuity.ps1 "REMOTE_CERTIFY: UNREADABLE"` `check: has scripts/github_public_read.ps1 "function Wait-OrvionPublicSlot"` `check: has scripts/test_agent_continuity.ps1 "108c green runs GitHub cannot read are UNREADABLE"` `check: has scripts/test_github_public_read.ps1 "budget: two concurrent watchers take turns"`
- [ ] Every file this contract may not modify that exists at the baseline is unchanged: the workflows, the runner, the run watcher, the release authorities, the consistency guard, the generator, the Batch 6 selector, the governance and the method. `check: blob .github/workflows/orvion-acceptance.yml b242e4c7401258404c5d43bffb49c3f53f42467e` `check: blob .github/workflows/agent-control.yml 41243b7c9a499df4cf011385a046c53107084ba3` `check: blob .github/workflows/migration-ci.yml 9bf8ca02d8ffac6591871b66bff53d5dbfc6e75c` `check: blob .github/workflows/repository-consistency.yml ed3ef8d8e954c8a2c5710fe44f46eb1f569c7492` `check: blob .github/SECURITY.md 2b836bdf375a5fc6d0b6a8b01f4fbbed2e8bf132` `check: blob scripts/check_repository_consistency.ps1 3e6d2810e03bfac15b96dba3bc46d119d97ad658` `check: blob scripts/run_timed.ps1 d1fbfc81d41b04b0c8b3a50c4b17cdd19853ca60` `check: blob scripts/watch_run.ps1 e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b` `check: blob scripts/watch_selftest.ps1 b0a838b184a3b0b9d0928cb34e474b045624e4de` `check: blob scripts/test_certification_receipts.ps1 c85cf120d4689633a550f45db0be005ef5de9037` `check: blob scripts/publish_candidate.ps1 d168504cc66c3a0759ac3ee9b5e01045a0f46589` `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79` `check: blob scripts/generate-ai-map.ps1 01165b8570999b79de4d6e854cae2443256e6b64` `check: blob scripts/batch6_select_target.ps1 20e55b308088b4f5405029f02605915231246fbe` `check: blob scripts/readiness_population.ps1 27b7f8158f506d537887fa967401ce2ef1ff45e9` `check: blob .workstation/doctor.ps1 0ad69c87859646283c84e31df5732b2df1d42056` `check: blob README.md 9f15270f25194e4ed0bb08613ca185a16b05ea2d` `check: blob AGENTS.md b2412d15cd6fcf710055114fe734ba69178f35cc` `check: blob GOVERNANCE.md 5670c47888bbd6b4194f6c41c54476ee42cb7bdf` `check: blob ENGINEERING_METHOD.md 874d1eefc1707dc56a9cbc41dfc3e695e2a0b726` `check: blob changes/TEMPLATE.md 6494ecfc57e0212e8b1c35dbab46daa7f510f2f9` `check: blob reports/architecture-decision-records.md 0bc32a7ec591cfbeeb7b26333ce66825d04c3e26` `check: blob reports/master/MASTER_EXECUTION_PLAN.md e957b949bc330cb637a634644664bf93bd2eb5ce` `check: blob reports/master/MASTER_GAP_REGISTER.md 7f957064cf1c3622229e220a85ae123c63648f1c`
- [ ] The manifest keeps the owner's Batch 6 hold and this repository's own next-work direction (preservation). `check: has _ORVION_CANONICAL/manifest.md "Batch 6 remains ON HOLD by owner decision (2026-10-18)"`

## Execution Log

None.

### 2026-10-20 — Gate 1 approval recorded

The owner's Gate 1 approval explicitly approves this exact Draft, SHA-256 5C94E1324730FB4A99AC8D86FA1A2C36D7335338FA98E0B455E2D8B435DF6FBE and Git blob 3a007e12f8a4cf395845cb044e17a5681de677f8, and no superseded or future revision. Immediately before allocation the hash, the Draft blob 3a007e12f8a4cf395845cb044e17a5681de677f8, all 33 source anchors, the baseline HEAD 94e7a39e6da7ac553842d2d2954cae38a574d45b against refreshed origin/main 94e7a39e6da7ac553842d2d2954cae38a574d45b and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 6638b5c. No implementation performed before this transition. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

### 2026-10-20 — Implementation checkpoint (Claude)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: the owner's Gate 1 approval names this exact Draft's SHA-256; the baseline HEAD was 94e7a39e6da7ac553842d2d2954cae38a574d45b and every source anchor matched there; Draft allocated as 6638b5c and approved as 38bd40b with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `scripts/check_agent_continuity.ps1` edited exactly as the step states; blob d5d5b2845e7e5620afca82d9ee08aa9de23b483f (38 insertions, 20 deletions).
- Step 3 Applied: `scripts/test_agent_continuity.ps1` edited exactly as the step states; blob 047370a65254ed92ad1c3ec89d4e6ecc2564002d (69 insertions, 11 deletions).
- Step 4 Applied: `scripts/github_public_read.ps1` edited exactly as the step states; blob 97f5c8894e5772e5a46e792aef927c5055e402b2 (46 insertions, 0 deletions).
- Step 5 Applied: `scripts/watch_ci.ps1` edited exactly as the step states; blob 738cb36667d4d9bef8182580c9115bc303a96329 (12 insertions, 8 deletions).
- Step 6 Applied: `scripts/test_github_public_read.ps1` edited exactly as the step states; blob df7d4616b6f46c050feede9022fde7897877dffc (43 insertions, 3 deletions).
- Step 7 Applied: `CR_LIFECYCLE.md` edited exactly as the step states; blob bcebabb0665901fa1ebf1b7e28ddbbecddeb5f68 (1 insertions, 1 deletions).
- Step 8 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

## Verification Notes

None.

### 2026-10-21 — Independent live-state Review

Verdict: Confirmed Complete

Independent read-only reviewer: Codex, task review_contract_a. The governing agent separately repeated the existing live-Git review checks and observed every clause holding with a fresh matching native receipt.

- Live clean HEAD ae0830de48886cb4e765eacaff4a1aa06e815dd7 descends from baseline 94e7a39e6da7ac553842d2d2954cae38a574d45b. All nine changed paths and every individual commit stay within the ten-path Write Scope; all 24 forbidden paths are unchanged; git diff --check passes.
- Allocation 6638b5cd198ef1d2e2d5f1b05a6b437ff2188cbc stores the exact approved Draft blob 3a007e12f8a4cf395845cb044e17a5681de677f8. Frozen Draft SHA-256 remains 5C94E1324730FB4A99AC8D86FA1A2C36D7335338FA98E0B455E2D8B435DF6FBE. All six implementation blobs and all 39 executable acceptance clauses hold. All 12 frozen sections are unchanged; zero contract lines were removed outside permitted lifecycle fields.
- Code inspection confirms the incomplete/shallow object-store refusal before history judgment, UNREADABLE exit 2 for unreadable GitHub evidence, and the shared locked watcher budget with Certify reserve. Disclosed limitations remain documented in Notes for subsequent work.
- The single native timed and simultaneously watched Finish log pt-finish.log records every CONTROL and REPOSITORY command passing, LOCAL_CERTIFY: READY and END exit=0 total=48.8 min. The runner measured minimum free RAM 3.48 GB and peak process tree 874 MB alongside the concurrency recorded in that log; these are samples, not bounds.
- Existing native read-only helpers independently validate schema-2 receipt cr SPEC-291, result READY, matching finishHead ae0830de48886cb4e765eacaff4a1aa06e815dd7, profiles CONTROL and REPOSITORY, implementation fingerprint 226a5038d8578ec24b6ce6fc278d11fc941b02ec5130e0c7a6e05d187a774f7d and digest fe66ee80f40d6907dd374c42ba37ee8558acaab374fd94210ff225014ec2104c. The preserved native receipt copy is byte-identical.
- Admission workflows, release authorities, historical evidence and this repository's existing routing are preserved. No GitHub setting or credential was changed. Batch 6 remains ON HOLD; CTRL-19 remains OPEN. No local Review Gate blocker remains. Publication, promotion and exact-SHA remote certification are pending separate steps.

Recommendation to human: Set Status to Complete through the native lifecycle, synchronize the manifest and generated projections, and bind the resulting exact candidate before the separately authorized publication and promotion steps.

## Review Gate

- [ ] Exact approved steps and exhaustive scope independently confirmed.
- [ ] Every acceptance criterion confirmed against final local evidence.
- [ ] Mandatory profiles and Git checks pass through fresh Finish.
- [ ] Admission workflow, release authorities and historical evidence preserved; no GitHub setting changed; CTRL-19 remains OPEN.

## Notes

The guard proves the store holds every object the judgment can reach; it does not prove a read's meaning, which the existing checks still judge. Outside this contract and recorded for a later fail-closed reads contract: `Git-State` reads a failed `rev-list --count 'HEAD...@{u}'` as behind 0, and the guard walks the refs the judgment walks (in local mode `HEAD`), not the index or `@{u}`. The shallow-clone tolerance comments elsewhere in the evaluator and the suite now describe a path the guard refuses first; they are left as written. `repository-index.md` is in Write Scope because the generator may rewrite it; at this baseline it does not change. Also recorded for later contracts (independent review, 2026-10-20): `scripts/watch_run.ps1` (forbidden here) does not list `UNREADABLE` among its result words, although its attention pattern still surfaces the line; a permanently misconfigured `origin` under `-Certify` reads as `UNREADABLE`, which suggests a rerun that will not help; the rate-limit shape check mixes `-or` and `-and` at equal precedence; a shape it lets through either throws, pauses the watcher, or is a harmless number (a numeric string or a fraction); `Wait-OrvionPublicSlot` bounds each pause by `-MaxWaitSeconds` but not their total, so a budget another consumer keeps at the reserve, or a reply without `remaining`, pauses a watcher window after window (it never prints a verdict meanwhile).

Repository identity checked from effective Git configuration: this checkout commits as `PlatPlusHub <platplustours@gmail.com>` from its local configuration. Push authentication is not commit authorship and neither is changed here.
