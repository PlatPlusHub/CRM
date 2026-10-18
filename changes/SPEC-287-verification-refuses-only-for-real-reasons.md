# Change Request — SPEC-287

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close the four known verification defects A, B, C and E in Platinum, so that `-Finish`, the hook and the range Gate refuse only for real reasons and a rehearsal reproduces the refusals a real run would meet, each proven positively, negatively and by mutation.

## Business Reason

The owner's 2026-10-18 directive requires every known defect closed with evidence in each affected repository before infrastructure readiness. All four were measured here and in `Shehabhub/ORVION`, whose evaluator code on these paths is identical:

- **A.** `Protect-PendingCertifications` refuses any foreign working receipt that no pending candidate retains. A READY receipt of a contract later Cancelled can never be bound, so it blocks every successor's `-Finish` (`PENDING_RECEIPT_UNBOUND: working evidence has no retained pending candidate`); this blocked a real Founder `-Finish` on 2026-10-18 and needed a one-time owner-authorized move.
- **B.** `scripts/test_future_date_guard.ps1` dates its probes from an edge read at its start while the guard reads its own ceiling minutes later; a run crossing 10:00 UTC fails four probes for no defect, as one Founder `-Finish` did on 2026-10-18. Finish starts are scheduled around it today.
- **C.** A disposable clone receives history, never ignored evidence, so a rehearsal without the authoritative checkout's receipt state skips the pending-evidence guard; a rehearsal passed while the real run was then refused by A.
- **E.** `Read-GitFile` keeps a leading U+FEFF that `ReadAllText` drops, so a keyed check or pin whose key is the first line of a BOM-prefixed file is missing at every commit: Approval and the hook refuse an unchanged file, and a real change fails as "missing" instead of "differs". Every outcome is a false refusal; no tracked file carries a BOM today.

## Risks

Low. A: retirement needs a schema-2 receipt that passes its checksum and whose own contract Git records as Cancelled at `HEAD`; pending completions are judged first and unchanged, and legacy, unreadable, tampered or uncancelled evidence still blocks. B: test-only; the guard and its ceiling are unchanged; a run that crosses the rollover is replaced once by a fresh whole run, so a day-boundary run costs about four more minutes and a run that stays on one day keeps its verdict. E: the commit side of `Read-RepoFile` drops exactly one leading U+FEFF, which `ReadAllText` drops on the working-tree side; `Read-GitFile` is unchanged because CTRL-4 must count a BOM a contract gains. C: method text only. Because B is fixed by this contract's own implementation, its `-Finish` needs no time window. CTRL-19 remains OPEN.

## Supersedes / Depends On

Depends on completed `SPEC-284` (pending-evidence protection), `SPEC-281` (criterion checks and pins), `SPEC-274` (sandbox and prototype method) and `SPEC-286` (current certified `main` `4a22aa513a34f1157a6467f7225b1aa60bf4926e`). Supersedes nothing.

## Write Scope

- `changes/SPEC-287-verification-refuses-only-for-real-reasons.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/test_certification_receipts.ps1`
- `scripts/test_future_date_guard.ps1`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_repository_consistency.ps1`
- `scripts/watch_ci.ps1`
- `scripts/github_public_read.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/batch6_select_target.ps1`
- `.workstation/doctor.ps1`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/agent-control.yml`
- `AGENTS.md`
- `GOVERNANCE.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_GAP_REGISTER.md`

The guard's future-date ceiling and every production date rule stay unchanged. The three pinned manifest lines stay unchanged. Batch 6 is ON HOLD in both repositories by owner decision of 2026-10-18 until the infrastructure programme completes and the owner explicitly authorizes resumption. Not here: the mechanical Three-Pass Draft Assurance enforcement the programme also names CR C, which is a new Approval-path mechanism for its own contract; GitHub Actions hardening (CR B); identity, credential, workflow or ruleset changes; publication or promotion by the agent. Observed and left unchanged: the hook reads a contract with `Get-Content -Raw`, which drops a leading BOM, so a leading U+FEFF a contract gains is refused only by the range Gate, which reads it through `Read-GitFile` (`PROHIBITED_CHARACTER:U+FEFF`); that direction fails closed.

## Required Reading

- `AGENTS.md` §§1–3
- `CR_LIFECYCLE.md` §§4–5,8–9
- `ENGINEERING_METHOD.md` §§1–3
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`: Read-GitFile, Read-RepoFile, Get-KeyedLine, Test-CriterionCheck, Validate-PinnedAuthority, Get-PinChanges, Validate-NoNewProhibitedCharacter, Protect-PendingCertifications, Receipt-AlreadyPromoted, Finish-Checks
- `scripts/test_certification_receipts.ps1`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_agent_continuity.ps1`: CONSTITUTIONAL ASSURANCE (SPEC-281) block

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- pwsh -NoProfile -File scripts/test_certification_receipts.ps1

## Pre-Approval Evidence

Change Class: Significant

Baseline: `4a22aa513a34f1157a6467f7225b1aa60bf4926e`, equal to remote `main`, clean original checkout, REMOTE_CERTIFY: READY on 2026-10-18. Allocation is derived by the existing allocator from this repository's history (cursor 286; 287 unreserved; 288 already reserved by `SPEC-286`'s text) and is refreshed immediately before the owner-approved Draft is committed.

Source anchors (baseline Git blobs, including read-only consumers):

| Path | Baseline blob |
| --- | --- |
| `scripts/check_agent_continuity.ps1` | `b7ffba9cc4907794ca45d410c74fa8c103a432d7` |
| `scripts/test_agent_continuity.ps1` | `30be3819df4caad865d1665a881760cee53ad396` |
| `scripts/test_certification_receipts.ps1` | `5a1e1079d3b93b5e63056faf7f8b04f6fe0057a2` |
| `scripts/test_future_date_guard.ps1` | `3c841e0e5a7bce65844c624630ad08be98651ec8` |
| `ENGINEERING_METHOD.md` | `6a5fdca1160d353647a01f0219db99d459a7f201` |
| `CR_LIFECYCLE.md` | `54cc3ddfb3c7ac911639629360add02b757760d1` |
| `scripts/check_repository_consistency.ps1` | `3e6d2810e03bfac15b96dba3bc46d119d97ad658` |
| `scripts/publish_candidate.ps1` | `d168504cc66c3a0759ac3ee9b5e01045a0f46589` |
| `scripts/promote_main.ps1` | `bf64aa893faf9d6be7477254bebf80dca04b4d79` |
| `.github/workflows/orvion-acceptance.yml` | `b242e4c7401258404c5d43bffb49c3f53f42467e` |
| `scripts/watch_ci.ps1` | `ca87c18d3ac7fa62f70f5df681c5df18cf482699` |
| `GOVERNANCE.md` | `5670c47888bbd6b4194f6c41c54476ee42cb7bdf` |
| `_ORVION_CANONICAL/manifest.md` | `762a535d7f8cf00a815d85dd2c602676f5d31d88` |
| `ai-map.json` | `67081cee78799fbd430e43ac485f9c29a288b6b2` |
| `repository-index.md` | `d075792a248fc781d7012cc0296fcd8bc15a47d5` |

The corrected regions of the evaluator and both shared test files are byte-identical with `Shehabhub/ORVION` at its certified `main`; the same correction is proposed there under its own contract.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A cancelled contract's working receipt is retired | Protect-PendingCertifications in `-Finish` | WRITE | Unchanged evaluator refuses the successor with the production message; corrected evaluator reaches LOCAL_CERTIFY: READY and the successor earns its own receipt |
| Pending completions keep their bound records | Pending-Completions loop, run before the receipt check | VERIFY | An unbound pending completion still blocks beside a cancelled receipt, before and after |
| Working-receipt integrity | Assert-ReceiptDigest, run before retirement | VERIFY | A tampered receipt naming a Cancelled contract is refused `RECEIPT_ALTERED`; the integrity mutant admits it |
| Uncancelled foreign and legacy receipts | Receipt-AlreadyPromoted and the retained-candidate refusal | VERIFY | A receipt whose contract is Complete but unbound, or absent at `HEAD`, still blocks; the status mutant admits the first |
| Candidate records and exact-SHA certification | `-BindCandidate`, `-Certify`, Select-Certification, `scripts/publish_candidate.ps1`, `scripts/promote_main.ps1` | UNAFFECTED | None reads the retirement path; candidate record hashes are unchanged across every receipt case |
| Commit-side text drops one leading BOM | Read-RepoFile callers: Get-CheckTarget (keyed and whole-file `same`, `has`, `lacks` at a commit), Assert-AssuranceAdmission, Validate-PinnedAuthority, Get-PinChanges | WRITE | Unchanged evaluator: Approval refuses `does not exist`, hook refuses an unchanged file, a changed line fails as missing; corrected: holds, holds, fails as `differs` |
| Other Git text readers | Read-GitFile in CTRL-4, Status-Path, allocation, receipts, publication segments | UNAFFECTED | Read-GitFile is unchanged; a contract gaining a BOM is still refused `PROHIBITED_CHARACTER:U+FEFF` in the range |
| Blob-judged checks | Get-RepoBlob, whole-file `same`, `blob` | UNAFFECTED | Blobs are compared as bytes on both sides |
| Date-guard suite verdict | CONTROL profile in `-Finish` | WRITE | Lag-injected old suite 12 passed, 6 failed; corrected suite voids the crossing run and its rerun gives 18 passed, 0 failed; rerun-disabled mutant 12 passed, 6 failed |
| Future-date ceiling | `scripts/check_repository_consistency.ps1` Check 12 | UNAFFECTED | Guard blob unchanged and pinned by a criterion |
| Rehearsal method and receipt authority | `ENGINEERING_METHOD.md` §2, `CR_LIFECYCLE.md` §8, relocation anchors and section pointers | WRITE | Repository consistency CLEAN with the corrected text; a cold-start agent applied the rule and one on the unchanged repository found none |
| Runtime bookkeeping and projections | manifest, ai-map, repository-index | WRITE | Active-pointer and Last Completed synchronization; pinned lines unchanged; the existing generator owns both projections |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Legal identity and admitted frozen contract | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Evaluator and control suites agree | BEFORE_COMPLETION | 2 | 5 | 7 |
| Generated state, scope and contract agree | BEFORE_COMPLETION | 2 | 7 | 8 |

Measured in a disposable Platinum clone at the baseline with real Git and every edit applied: `scripts/test_certification_receipts.ps1` 71 passed, 0 failed in 3.2 minutes, and against the unchanged evaluator only the cancelled-receipt case fails, with the production refusal; the BOM block with its precondition 5 passed, 0 failed, and against the unchanged evaluator all three cases and the mutant fail with `does not exist`; the date-guard matrix as stated above, the uninjected corrected suite 18 passed, 0 failed in 4.5 minutes beside other runs; repository consistency CLEAN; the generator changes no projection. The positive proofs also pass in a disposable Founder clone. A lifecycle rehearsal in a disposable clone carrying this checkout's ignored receipt and bound records reproduced allocation, approval, In Progress, implementation, the DONE checkpoint, the Finish entry stage past pending-certification protection, Review, the Complete hook reaching only the receipt prerequisite, and the whole publication range under the range Gate and the trusted judge. These are preparation measurements; the full derived commands and the Additional Verification run once, in the final timed Finish.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `SPEC-284` pending-evidence protection, `SPEC-281` criterion checks and pins, the existing date-guard suite and the `SPEC-274` rehearsal method; this contract corrects three judgments inside them and adds no mechanism.

Added Property: a valid working receipt of a contract Cancelled at `HEAD` no longer blocks, while every pending, tampered, legacy or uncancelled receipt still does; a keyed check reads a first line identically at a commit and in the working tree; the date-guard suite's verdict always comes from one civil day; a rehearsal reaching `-Finish` carries exactly the ignored certification state.

Causal Negative: against the unchanged evaluator the cancelled-receipt case fails with `PENDING_RECEIPT_UNBOUND: working evidence has no retained pending candidate`, the BOM cases fail with `does not exist`, and the lag-injected unchanged suite fails six probes.

Positive Test Design: the successor's Finish earns its own receipt beside a cancelled one; an unchanged first-line key holds in the hook and, with another line changed, in the range; the lag-injected corrected suite passes after one void run.

Negative Test Design: uncancelled, absent-contract and tampered receipts and an unbound pending completion still block; a changed first-line key fails as `differs`.

Non-Empty Population Obligation: the existing CHECK family population assertion stays non-zero for accept, reject and mutation.

Mutation Obligation: replacing the Cancelled condition with true admits an uncancelled receipt; skipping the receipt checksum admits a tampered cancelled one; removing the commit-side BOM drop restores the false refusal (281-CM6); disabling the rerun restores the six date-probe failures.

Post-Implementation Proof Obligation: the full control suites, every other derived CONTROL command, the REPOSITORY commands and `scripts/test_certification_receipts.ps1` pass in one fresh timed and watched Finish on the final implementation.

## Implementation Steps

1. Check that the owner's Gate 1 approval names this exact Draft's SHA-256, that remote `main` is still `4a22aa513a34f1157a6467f7225b1aa60bf4926e` and that every source anchor above still matches at `HEAD`; if any differs, stop and report without any write. This step writes nothing beyond the allocation and approval commits the owner's command directs.
2. Check whether `scripts/check_agent_continuity.ps1` contains `if($was-and(Status-FromText $was)-ceq'Cancelled'){return}`; if so record Already Applied. Otherwise make exactly these two replacements and nothing else. Replace

   ```powershell
   # A tracked file at a commit, or in the working tree when $Ref is empty.
   function Read-RepoFile([string]$Ref,[string]$Path){
       if($Ref){return Read-GitFile $Ref $Path}
   ```

   with

   ```powershell
   # A tracked file at a commit, or in the working tree when $Ref is empty. `ReadAllText` drops one
   # leading BOM and `git show` keeps it, so a first-line key was missing at every commit: the commit
   # side drops it the same way. `Read-GitFile` itself keeps it, because CTRL-4 must see a BOM a
   # contract gains.
   function Read-RepoFile([string]$Ref,[string]$Path){
       if($Ref){$t=Read-GitFile $Ref $Path;if($t-and$t[0]-eq[char]0xFEFF){$t=$t.Substring(1)};return $t}
   ```

   In Protect-PendingCertifications, immediately after the line `        Assert-ReceiptDigest $prior`, insert

   ```powershell
           # Its own contract Cancelled at HEAD can never complete, bind or publish: obsolete evidence,
           # not pending. Without this a cancelled contract's READY receipt blocked every successor.
           $was=if($prior.contract-is[string]-and$prior.contract-cmatch('^changes/'+[regex]::Escape("$($prior.cr)")+'-[A-Za-z0-9_.-]+\.md$')){Read-GitFile HEAD $prior.contract}
           if($was-and(Status-FromText $was)-ceq'Cancelled'){return}
   ```

   The resulting file's Git blob is 256879e512235b1e8744ea64862dd1e82ce65c6d.
3. Check whether `scripts/test_agent_continuity.ps1` contains `281-CM6 CHECK MUTATION: the commit side drops the BOM the working tree drops`; if so record Already Applied. Otherwise insert exactly the following lines immediately after the first line `    git -C $root config --unset core.autocrlf` that follows `281-CM5 CHECK MUTATION`, and change nothing else:

   ```powershell
       # A keyed check reads a line the same way at a commit and in the working tree. `git show` keeps the
       # leading BOM that ReadAllText drops, so a first-line key was missing at every commit: Approval
       # refused it in the range, the hook refused an unchanged file, and a real change failed as "missing".
       function ChBom([string]$Scope=$chPlain,[scriptblock]$Mid={},[switch]$Open){
           ChBase|Out-Null;[IO.File]::WriteAllText((Join-Path $root 'bom.txt'),"Channel: train 6`nOwner: release`n",[Text.UTF8Encoding]::new($true));Commit 'ch-bom'
           $b=(git -C $root rev-parse HEAD).Trim();ChLife @{Scope=$Scope;Acceptance="bom.txt keeps its channel. ``check: same bom.txt#Channel @$b``"} -NoReset -Mid $Mid -Open:$Open|Out-Null;$b
       }
       $bomOther={[IO.File]::WriteAllText((Join-Path $root 'bom.txt'),"Channel: train 6`nOwner: platform`n",[Text.UTF8Encoding]::new($true));Commit 'ch-bom-other'}
       $b=ChBom -Scope "bom.txt;$chPlain" -Mid $bomOther;$r=RunRange $b
       Assert '281-C14 CHECK: a first-line key of a BOM file holds in the range when another line changed' ($r.Code-eq0-and$r.Text-match'ORVION: READY') $r.Text
       Pop 'CHECK' 'accept'
       ChBom -Open|Out-Null;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run 'Gate'
       Assert '281-C15 CHECK: the unchanged first-line key holds in the hook' ($r.Text-notmatch'CRITERION_CHECK_FAILED'-and$r.Text-match$atReceipt) $r.Text
       Pop 'CHECK' 'accept'
       ChBom -Scope "bom.txt;$chPlain" -Open|Out-Null;[IO.File]::WriteAllText((Join-Path $root 'bom.txt'),"Channel: train 7`nOwner: release`n",[Text.UTF8Encoding]::new($true))
       Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run 'Gate'
       Assert '281-C16 CHECK: a changed first-line key fails because it differs, not because it is missing' ($r.Code-ne0-and$r.Text-match'CRITERION_CHECK_FAILED.*bom\.txt#Channel differs') $r.Text
       Pop 'CHECK' 'reject'
       MutationKill '281-CM6 CHECK MUTATION: the commit side drops the BOM the working tree drops' {ChBom -Open|Out-Null;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.')} $atReceipt `
           'if($t-and$t[0]-eq[char]0xFEFF){$t=$t.Substring(1)};' '' 'CHECK'
   ```

   The resulting file's Git blob is 52934332def1608d6bc12b6ac5847db34f4b37f7.
4. Check whether `scripts/test_certification_receipts.ps1` contains `unbound pending completion still blocks beside a cancelled receipt`; if so record Already Applied. Otherwise insert exactly the following lines immediately after the line that ends `'nonterminal later SHA cannot borrow earlier Finish evidence' 'RECEIPT_SHA_MISMATCH' (RunEval Certify)`, before the closing brace of that block, and change nothing else:

   ```powershell
           # A contract Git records as Cancelled at HEAD can never complete, bind or publish, so its READY
           # working receipt no longer blocks a successor. One whose contract is not cancelled, one whose
           # checksum fails, and an unbound pending completion beside it all still block.
           $fourthId='SPEC-'+(900+3);$fourthRel="changes/$fourthId-fixture.md";$c3=[IO.File]::ReadAllText($working)
           SetContract $thirdId $thirdRel Cancelled;$null=Commit 'C3 cancelled'
           SetContract $fourthId $fourthRel Draft;$null=Commit 'C4 draft'
           SetContract $fourthId $fourthRel Approved;SetManifest $fourthRel;$null=Commit 'C4 approved'
           SetContract $fourthId $fourthRel 'In Progress';Put 'allowed.txt' 'four';$null=Commit 'C4 implementation'
           # Not cancelled: C2's receipt claiming an unproven target (its contract is Complete at HEAD), and
           # a receipt whose contract HEAD does not hold at all, as one from an abandoned branch.
           $t=(Json $record2).receipt;$t.target='never-published';SaveJson $working (Resign $t);$open=[IO.File]::ReadAllText($working)
           $f=RunEval Finish
           Assert 'receipt of a contract not cancelled at HEAD still blocks its successor' ($f.Code-ne0-and$f.Text-match'PENDING_RECEIPT_UNBOUND'-and[IO.File]::ReadAllText($working)-ceq$open) $f.Text
           Mutant cancelled "(Status-FromText `$was)-ceq'Cancelled'" '$true' {[IO.File]::WriteAllText($working,$open)} {param($e)RunEval Finish @() $e} 'PENDING_RECEIPT_UNBOUND' 'LOCAL_CERTIFY: READY'
           $t=(Json $record2).receipt;$t.cr='SPEC-'+(900+5);$t.contract="changes/$($t.cr)-fixture.md";$t.target='never-published';SaveJson $working (Resign $t)
           Refused 'receipt whose contract HEAD does not hold still blocks' 'PENDING_RECEIPT_UNBOUND' (RunEval Finish)
           [IO.File]::WriteAllText($working,$c3);$t=Json $working;$t.expected=@('Tampered');SaveJson $working $t;$tampered=[IO.File]::ReadAllText($working)
           $f=RunEval Finish
           Assert 'tampered receipt of a cancelled contract is refused, never retired' ($f.Code-ne0-and$f.Text-match'RECEIPT_ALTERED'-and[IO.File]::ReadAllText($working)-ceq$tampered) $f.Text
           Mutant integrity '        Assert-ReceiptDigest $prior' '        $null=$prior.digest' {[IO.File]::WriteAllText($working,$tampered)} {param($e)RunEval Finish @() $e} 'RECEIPT_ALTERED' 'LOCAL_CERTIFY: READY'
           [IO.File]::WriteAllText($working,$c3);$f=RunEval Finish;$new=Json $working
           Assert 'cancelled contract receipt no longer blocks: successor Finish earns its own receipt, records intact' ($f.Code-eq0-and$f.Text-match'LOCAL_CERTIFY: READY'-and$new.cr-ceq$fourthId-and(Hash $script:record1)-ceq$hash1-and(Hash $record2)-ceq$hash2) $f.Text
           $candidate4=CompleteFixture $fourthId $fourthRel;$fifthId='SPEC-'+(900+4);$fifthRel="changes/$fifthId-fixture.md"
           SetContract $fifthId $fifthRel Draft;$null=Commit 'C5 draft'
           SetContract $fifthId $fifthRel Approved;SetManifest $fifthRel;$null=Commit 'C5 approved'
           SetContract $fifthId $fifthRel 'In Progress';Put 'allowed.txt' 'five';$null=Commit 'C5 implementation'
           [IO.File]::WriteAllText($working,$c3);$f=RunEval Finish
           Assert 'unbound pending completion still blocks beside a cancelled receipt' ($f.Code-ne0-and$f.Text-match"PENDING_RECEIPT_UNBOUND:$candidate4"-and[IO.File]::ReadAllText($working)-ceq$c3) $f.Text
   ```

   The resulting file's Git blob is c85cf120d4689633a550f45db0be005ef5de9037.
5. Check whether `scripts/test_future_date_guard.ps1` contains `ONE CIVIL DAY PER VERDICT`; if so record Already Applied. Otherwise make exactly these two replacements and nothing else. Replace

   ```powershell
   # by sharing a variable.
   $edge = [datetimeoffset]::UtcNow.AddHours(14).Date
   ```

   with

   ```powershell
   # by sharing a variable. It rolls over at 10:00 UTC; see the end of this file for a run that crosses it.
   function Get-Edge { [datetimeoffset]::UtcNow.AddHours(14).Date }
   $edge = Get-Edge
   ```

   Immediately before the line `if ($fail -gt 0) {` near the end of the file, insert

   ```powershell
   # ONE CIVIL DAY PER VERDICT. Every probe above is dated from the `$edge` read at the start, and the
   # guard reads its own ceiling minutes later. A run that crosses 10:00 UTC therefore judges `edge + 1`
   # probes against a ceiling that has already reached them, and four of them failed in a 2026-10-18
   # `-Finish`. Such a run measured nothing, so its verdict is void and the suite runs once more, whole,
   # in a fresh process: the next rollover is a day away. The guard and its ceiling are untouched, and
   # this is never a retry of a failure: a run that stays on one day keeps its verdict, pass or fail.
   if ((Get-Edge) -ne $edge -and -not $env:ORVION_FDATE_RERUN) {
       Write-Host "CEILING ROLLED OVER DURING THIS RUN ($(Iso $edge) -> $(Iso (Get-Edge))): verdict void, running once more" -ForegroundColor Yellow
       $env:ORVION_FDATE_RERUN = '1'
       & pwsh -NoProfile -File $PSCommandPath
       exit $LASTEXITCODE
   }
   ```

   The resulting file's Git blob is 2e2732e82d9c887202b52b830272ab69f21274bb.
6. Check whether `ENGINEERING_METHOD.md` contains `copy the authoritative checkout's ignored certification state into the clone first`; if so record Already Applied. Otherwise, in `ENGINEERING_METHOD.md` §2 replace `Three rehearsals cover the failures that cancelled recent contracts:` with `Four rehearsals cover the failures that cancelled or blocked recent contracts:`, change the final `.` of the bullet ending `froze criteria that were false as written).` to `;`, and insert immediately after that bullet

   ```markdown
     - when the rehearsal reaches `-Finish`, `-BindCandidate` or `-Certify`, copy the authoritative checkout's ignored certification state into the clone first: exactly `.orvion-local-certification.json` and `.orvion-certifications/`, read-only, and nothing else Git ignores, since local settings and `supabase/.temp/` can hold credentials. A clone receives history, never ignored evidence, so without them the rehearsal skips the guard that protects pending evidence: on 2026-10-18 a rehearsal passed, and the real `-Finish` was refused because a cancelled contract's READY receipt was still in place. The copies certify nothing and never return to the authoritative checkout.
   ```

   In `CR_LIFECYCLE.md` §8 replace `pending or unreadable legacy evidence blocks. Never reconstruct lost historical claims. Retain the original checkout and its ignored records; clones and promotion data worktrees do not inherit them.` with `pending or unreadable legacy evidence blocks. A valid working receipt whose own contract is Cancelled at ``HEAD`` is retired too: that contract can never complete, bind or publish. Never reconstruct lost historical claims. Retain the original checkout and its ignored records; clones and promotion data worktrees do not inherit them, and a rehearsal clone holds only the read-only copies ``ENGINEERING_METHOD.md`` §2 describes, which certify nothing.` The resulting Git blobs are 6f77b435ac20274f4e5ef7bb4ce47871f0b5e2df and a80d15cdf805932623a0a8ea93aaae9740fac870.
7. Check whether the Runtime Checkpoint reads `Resume Step: DONE`; if so record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, confirm `pwsh -NoProfile -File scripts/generate-ai-map.ps1 -Check` exits 0 and that `git diff --name-only` names only Write Scope paths, append the Execution Log entry, set the Runtime Checkpoint to `Resume Step: DONE`, `Blocker: None`, `Recovery Attempt: 0`, and commit the implementation and checkpoint together through the unchanged pre-commit hook.
8. Check that a fresh native receipt for this contract matches, a `Verdict: Confirmed Complete` Verification Notes entry exists and every Acceptance Criterion and Review Gate item holds; only then record Already Applied. Otherwise, from the repository root, start `pwsh -NoProfile -File scripts/run_timed.ps1 -Log <log> -Command "pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish"` and, at the same time, `pwsh -NoProfile -File scripts/watch_run.ps1 -Log <log> -Run spec-287-finish -Brief`. Require `LOCAL_CERTIFY: READY`; a failed command keeps its real exit code and evidence and starts bounded recovery without weakening any assertion. Perform independent live Review against the repository and append its Verification Notes verdict. Then complete through the native lifecycle with the unchanged pre-commit hook, setting `manifest.md`'s `Active Change Request` to `None.` and its `Last Completed` to exactly `Last Completed: **SPEC-287: known verification defects A, B, C and E closed — fresh local verification and Review complete; owner publication/promotion and exact-SHA remote certification follow `CR_LIFECYCLE.md` §9. Batch 6 remains ON HOLD by owner decision (2026-10-18) until the infrastructure programme completes and the owner authorizes resumption. CTRL-19 remains OPEN.**`, regenerating the projections with the existing generator. Locally prepare the exact candidate with `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BindCandidate -Root <original-checkout> -BaseRef <full-main-SHA> -HeadRef <full-candidate-SHA>`. Stop before publication or promotion.

## Acceptance Criteria

- [ ] The evaluator retires only a cancelled contract's valid working receipt and reads a commit's first line as the working tree does, with exactly the reviewed bytes. `check: blob scripts/check_agent_continuity.ps1 256879e512235b1e8744ea64862dd1e82ce65c6d` `check: has scripts/check_agent_continuity.ps1 "if($was-and(Status-FromText $was)-ceq'Cancelled'){return}"` `check: has scripts/check_agent_continuity.ps1 "if($t-and$t[0]-eq[char]0xFEFF){$t=$t.Substring(1)};return $t"`
- [ ] The control suites prove A and E positively, negatively and by mutation. `check: blob scripts/test_agent_continuity.ps1 52934332def1608d6bc12b6ac5847db34f4b37f7` `check: has scripts/test_agent_continuity.ps1 "281-CM6 CHECK MUTATION: the commit side drops the BOM the working tree drops"` `check: blob scripts/test_certification_receipts.ps1 c85cf120d4689633a550f45db0be005ef5de9037` `check: has scripts/test_certification_receipts.ps1 "unbound pending completion still blocks beside a cancelled receipt"`
- [ ] The date-guard suite takes its verdict from one civil day while the guard's ceiling is unchanged. `check: blob scripts/test_future_date_guard.ps1 2e2732e82d9c887202b52b830272ab69f21274bb` `check: has scripts/test_future_date_guard.ps1 "ONE CIVIL DAY PER VERDICT"` `check: blob scripts/check_repository_consistency.ps1 3e6d2810e03bfac15b96dba3bc46d119d97ad658`
- [ ] The method and receipt authority say how a rehearsal carries ignored certification state and when a working receipt retires. `check: blob ENGINEERING_METHOD.md 6f77b435ac20274f4e5ef7bb4ce47871f0b5e2df` `check: has ENGINEERING_METHOD.md "copy the authoritative checkout's ignored certification state into the clone first"` `check: blob CR_LIFECYCLE.md a80d15cdf805932623a0a8ea93aaae9740fac870`
- [ ] Release authorities, pins and the watcher are unchanged. `check: blob scripts/publish_candidate.ps1 d168504cc66c3a0759ac3ee9b5e01045a0f46589` `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79` `check: blob .github/workflows/orvion-acceptance.yml b242e4c7401258404c5d43bffb49c3f53f42467e` `check: blob scripts/watch_ci.ps1 ca87c18d3ac7fa62f70f5df681c5df18cf482699` `check: blob GOVERNANCE.md 5670c47888bbd6b4194f6c41c54476ee42cb7bdf`
- [ ] The manifest keeps the owner's Batch 6 hold. `check: has _ORVION_CANONICAL/manifest.md "Batch 6 remains ON HOLD by owner decision (2026-10-18)"`

## Execution Log

None.

### 2026-10-19 — Gate 1 approval recorded

The owner's execution directive of 2026-10-19 approved frozen Draft SHA256 9E8B761145074758C9838CAE5C51522B31D358728CBDF11E91C3B8A3568E7020 at baseline 4a22aa513a34f1157a6467f7225b1aa60bf4926e. Immediately before allocation the hash, the Draft blob cb2cab176b9b2360295c3790b0561ffc88b222dd, all 15 source anchors, refreshed origin/main and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as deedc2e. No implementation performed before this transition. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

## Verification Notes

None.

## Review Gate

- [ ] Exact approved steps and exhaustive scope independently confirmed.
- [ ] Every acceptance criterion confirmed against final local evidence.
- [ ] Mandatory profiles, Additional Verification and Git checks pass through fresh Finish.
- [ ] Release authorities, pending-evidence protection and historical evidence preserved; CTRL-19 remains OPEN.

## Notes

Three-pass Draft assurance. V1 fixed each defect where it was observed: A by retiring any foreign receipt the current contract did not write; E by dropping the BOM inside `Read-GitFile`; B by recomputing the edge in each section; C by a script that builds rehearsal clones. V2 challenged each against the code and a counterexample. A: retiring any foreign receipt would discard an uncancelled contract's evidence, so retirement needs Git's Cancelled status for the receipt's own contract after its checksum, and the status and integrity mutants prove both conditions are load-bearing. E: dropping the BOM in `Read-GitFile` admits a contract that gains a leading BOM in the range (measured: CTRL-4 ADMITTED instead of `PROHIBITED_CHARACTER:U+FEFF`), a false PASS, so only the commit side of `Read-RepoFile` drops exactly one leading U+FEFF, as `ReadAllText` does on the other side; trimming every leading U+FEFF would differ from `ReadAllText` on a doubled BOM. B: a per-section edge still races inside a section, and an injectable clock means a production change and, for `FakeTimeProvider`, a new package (https://learn.microsoft.com/dotnet/standard/datetime/timeprovider-overview); libfaketime needs `LD_PRELOAD`, which Windows lacks; so the smallest test-only mechanism voids a run whose ceiling moved and reruns it once. C: a new script is a new control surface with its own tests, while the failure it prevents is an omitted copy that the method can name, so the rule lives in the existing `ENGINEERING_METHOD.md` §2 list with a pointer from `CR_LIFECYCLE.md` §8, which a cold-start agent applied correctly. V3 refreshed the evidence on 2026-10-18 in disposable clones of both repositories: `ReadAllText` returned U+0061 for a BOM-prefixed file whose `git show` text began U+FEFF; each defect was reproduced on the unchanged code and closed on the corrected code; the receipt suite was measured for Additional Verification. V3 is selected.

Contract size was challenged. The four corrections are about 75 changed lines, each proven alone; one contract costs one Finish and one release instead of four. The programme's mechanical Draft Assurance enforcement changes the Approval path every later Draft passes and is not yet proven at this baseline, so it is left to its own contract after this one is certified.

Repository identity checked from effective Git configuration: this checkout commits as `PlatPlusHub <platplustours@gmail.com>` from its local configuration. Push authentication is not commit authorship and neither is changed here.
