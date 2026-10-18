# Change Request — SPEC-286

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the Gate judge a whole-file `check: same` by Git blob, and an unchanged tracked file by its index blob, by transferring the correction and its control tests already certified in `Shehabhub/ORVION`.

## Business Reason

A keyless `check: same <path> @<commit>` compares `git show` text, which loses the final newline, with working-tree text, so it never holds in the hook or `-Finish` while it holds in the range Gate; `SPEC-282` recorded this and avoided the form. Under `core.autocrlf=true`, `hash-object` alone also re-normalizes a CRLF blob that `git add` kept. `Shehabhub/ORVION` corrected both in commit `975f1aa31b05736b33971fe1e5afb628e9b6fb58`, certified on its `main` `794a6dbb2e462f6c41c6d2155570e316f5490d5a` (REMOTE_CERTIFY: READY). This is the first controlled synchronization of the owner's 2026-10-18 programme: it transfers that shared evaluator correction and its seven control cases byte-for-byte, adapting one comment, and transfers no Founder history, identity, configuration or Founder-only behaviour.

## Risks

Low. Three evaluator lines change: Get-RepoBlob's working-tree branch, Test-CriterionCheck's keyless `same`, and the `same/same` approval clash; keyed checks, `has`, `lacks` and range-mode `blob` keep their logic. No Platinum contract has ever used a keyless `same`, so no recorded verdict can change. A `git diff` error falls back to the previous `hash-object` result. One pre-existing edge remains unchanged before and after: a keyed check whose first line carries a UTF-8 BOM; no tracked Platinum file carries a BOM. The known UTC+14 midnight race in `scripts/test_future_date_guard.ps1` belongs to CR C; Finish is started so that the test cannot straddle 10:00 UTC, and the test is not changed here. The working receipt is `SPEC-285`'s, whose completion is already on `main`, so the known cancelled-receipt defect cannot block this Finish. CTRL-19 remains OPEN.

## Supersedes / Depends On

Depends on completed `SPEC-281` (criterion checks), `SPEC-282` (which recorded the defect) and `SPEC-285` (current certified `main` `fd118fae6c76271100d67fdb44923bb0b406c986`). Supersedes nothing.

## Write Scope

- `changes/SPEC-286-whole-file-checks-are-judged-by-git-blob.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/watch_ci.ps1`
- `scripts/github_public_read.ps1`
- `scripts/test_github_public_read.ps1`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_certification_receipts.ps1`
- `scripts/watch_selftest.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/batch6_select_target.ps1`
- `.workstation/doctor.ps1`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/agent-control.yml`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_GAP_REGISTER.md`

The three pinned manifest lines stay unchanged. Batch 6 is ON HOLD in both repositories by owner decision of 2026-10-18 until the infrastructure programme completes and the owner explicitly authorizes resumption; moving the pinned lines to say so is an authority change left to Platinum CR C. No Founder-only watcher binding, admission base, database target, identity, credential, workflow or ruleset change; no cancelled-receipt, date-test or sandbox-fidelity correction (CR C); no publication or promotion by the agent.

## Required Reading

- `AGENTS.md` §§1–3
- `CR_LIFECYCLE.md` §§4–5,8–9
- `ENGINEERING_METHOD.md` §§1–3
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`: Get-CheckTarget, Get-RepoBlob, Test-CriterionCheck, Assert-AssuranceAdmission
- `scripts/test_agent_continuity.ps1`: CONSTITUTIONAL ASSURANCE (SPEC-281) block

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

Baseline: `fd118fae6c76271100d67fdb44923bb0b406c986`, equal to remote `main`, clean original checkout, REMOTE_CERTIFY: READY re-observed 2026-10-18. Allocation is derived by the existing allocator from this repository's history (cursor 285; 286 unreserved) and is refreshed immediately before the owner-approved Draft is committed.

Source anchors (baseline Git blobs, including read-only consumers):

| Path | Baseline blob |
| --- | --- |
| `scripts/check_agent_continuity.ps1` | `86e15ae7d85401a3d09388603515997dec121d40` |
| `scripts/test_agent_continuity.ps1` | `f8020fb082d35617fac011779cb8a0fd4d2d01f3` |
| `scripts/watch_ci.ps1` | `ca87c18d3ac7fa62f70f5df681c5df18cf482699` |
| `scripts/publish_candidate.ps1` | `d168504cc66c3a0759ac3ee9b5e01045a0f46589` |
| `scripts/promote_main.ps1` | `bf64aa893faf9d6be7477254bebf80dca04b4d79` |
| `.github/workflows/orvion-acceptance.yml` | `b242e4c7401258404c5d43bffb49c3f53f42467e` |
| `scripts/test_future_date_guard.ps1` | `3c841e0e5a7bce65844c624630ad08be98651ec8` |
| `_ORVION_CANONICAL/manifest.md` | `b6151fdc7b304ac9bcf8067ed83e6e8656c30725` |
| `ai-map.json` | `d0eeb2248e125cb45b97b16444eee7d902317165` |
| `repository-index.md` | `d075792a248fc781d7012cc0296fcd8bc15a47d5` |
| `scripts/generate-ai-map.ps1` | `01165b8570999b79de4d6e854cae2443256e6b64` |

The source evaluator region (Get-RepoBlob, Test-CriterionCheck, Assert-AssuranceAdmission) is byte-identical between this baseline and the Founder evaluator before its correction; the Founder patch applies with one test-hunk offset of two lines.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Whole-file `check: same` is judged by Git blob | Validate-TransitionEvidence through Test-CriterionCheck (hook Complete) | WRITE | Unchanged evaluator refuses an unchanged file (281-C9 FAIL); corrected evaluator holds it (281-C9 PASS) |
| Whole-file `check: same` is judged by Git blob | Range Gate through Test-CriterionCheck with a tree ref | VERIFY | Blob against blob; an unchanged file still holds (281-C10 PASS before and after); a removed final newline now fails (281-C11) |
| Whole-file `check: same` is judged by Git blob | Assert-AssuranceAdmission `same/same` clash | WRITE | Same blob identity as the evaluator, so Approval and Complete agree; keyed pairs keep ordinal text comparison |
| Working-tree blob of an unchanged tracked file | Get-RepoBlob and every `blob` check in the hook | WRITE | Index blob when `git diff --quiet` reports the file unchanged, `hash-object` otherwise; an unchanged CRLF blob under `core.autocrlf=true` now holds (281-C13) |
| Existing whole-file `same` population | `changes/` contracts | UNAFFECTED | `git grep` at the baseline finds no contract using the keyless form; `SPEC-282` mentions it only as the recorded defect |
| Gate behaviour under test | `scripts/test_agent_continuity.ps1` | WRITE | Seven cases 281-C9 to 281-C13, 281-CM4, 281-CM5; the unchanged evaluator fails six, 281-C10 is the positive control |
| Evaluator copies in other suites | `scripts/test_certification_receipts.ps1`, `scripts/watch_selftest.ps1`, `scripts/watch_ci.ps1` | UNAFFECTED | None declares a `check:` clause (only the evaluator and its control suite do), and the watcher reads only the workflow deriver |
| CI watcher repository binding | `scripts/watch_ci.ps1` | UNAFFECTED | Its default `PlatPlusHub/CRM` is correct here and its self-tests pass `-Repo`; the Founder version refuses every repository but `Shehabhub/ORVION`, so it is deliberately not transferred |
| Trusted candidate judgment and release | `scripts/promote_main.ps1`, `.github/workflows/orvion-acceptance.yml`, `scripts/publish_candidate.ps1` | VERIFY | Unchanged; the trusted evaluator on `main` judges this candidate, and this contract's own criteria use `has`, `lacks` and `blob`, which the old and new evaluators judge alike |
| Runtime bookkeeping and projections | manifest, ai-map, repository-index | WRITE | Normal active-pointer and Last Completed synchronization; pinned lines unchanged; the existing generator owns both projections |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Legal identity and admitted frozen contract | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Evaluator and control suite agree | BEFORE_COMPLETION | 2 | 3 | 4 |
| Generated state, scope and contract agree | BEFORE_COMPLETION | 2 | 4 | 5 |

Measured in the Platinum sandbox clone at the baseline with real Git: the reduced CHECK block of the control suite gave 21 passed, 6 failed against the unchanged evaluator (281-C9, C11, C12, C13 fail; the CM4 and CM5 anchors are absent) and 27 passed, 0 failed against the corrected evaluator; a 134-case real-Git harness over line endings, final newline, Unicode and BOM, attributes, staged and missing files gave 50 unexpected results before and 5 after, the same pre-existing BOM edge, with no new unexpected result. A lifecycle rehearsal in a disposable clone carrying this checkout's ignored receipt and bound records reproduced allocation, approval, In Progress, implementation, the DONE checkpoint, the Finish entry stage past pending-certification protection, Review, the Complete hook reaching only the receipt prerequisite, and the whole publication range under the range Gate and the trusted judge. These are preparation measurements, not final verification; the full derived CONTROL and REPOSITORY commands run once, in the final timed Finish.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: the `SPEC-281` criterion checks (`same`, `has`, `lacks`, `blob`) in the hook, the range Gate and Approval admission; this contract corrects one comparison inside them and adds no mechanism.

Added Property: a whole-file `check: same` holds exactly when the file's Git blob equals the blob at the named commit, in the hook and in the range alike; an unchanged tracked file is judged by its index blob.

Causal Negative: against the unchanged evaluator 281-C9, 281-C11, 281-C12 and 281-C13 fail and the 281-CM4 and 281-CM5 anchors do not exist; the 134-case harness gives 50 unexpected results.

Positive Test Design: an unchanged file holds a whole-file same in the hook (281-C9) and the range (281-C10); an unchanged CRLF blob holds under `core.autocrlf=true` (281-C13).

Negative Test Design: a removed final newline fails a whole-file same in the range (281-C11) and the hook (281-C12).

Non-Empty Population Obligation: the existing CHECK family population assertion stays non-zero for accept, reject and mutation.

Mutation Obligation: 281-CM4 restores text comparison for a whole-file same and 281-CM5 removes the index-blob branch; each pristine run reaches the receipt prerequisite and each mutant does not.

Post-Implementation Proof Obligation: the full control suite, every other derived CONTROL command and the REPOSITORY commands pass in one fresh timed and watched Finish on the final implementation.

## Implementation Steps

1. Check that the owner's Gate 1 approval names this exact Draft's SHA-256, that remote `main` is still `fd118fae6c76271100d67fdb44923bb0b406c986` and that every source anchor above still matches at `HEAD`; if any differs, stop and report without any write. This step writes nothing beyond the allocation and approval commits the owner's command directs.
2. Check whether `scripts/check_agent_continuity.ps1` contains `if($Check.Kind-eq'same'-and-not$Check.Key){`; if so record Already Applied. Otherwise make exactly these three replacements and nothing else. In Get-RepoBlob replace

   ```powershell
       $b=if($Ref){git -C $Root rev-parse "${Ref}:$Path" 2>$null}else{$f=Join-Path $Root $Path;if(Test-Path -LiteralPath $f){git -C $Root hash-object -- $f 2>$null}}
   ```

   with

   ```powershell
       $b=if($Ref){git -C $Root rev-parse "${Ref}:$Path" 2>$null}else{$f=Join-Path $Root $Path;if(Test-Path -LiteralPath $f){
           # A tracked file Git sees as unchanged is its index blob: hash-object alone re-normalizes a CRLF blob that `git add` keeps.
           git -C $Root diff --quiet -- $Path 2>$null;if($LASTEXITCODE-eq0-and(git -C $Root ls-files -- $Path)){git -C $Root rev-parse ":$Path" 2>$null}else{git -C $Root hash-object -- $f 2>$null}}}
   ```

   In Test-CriterionCheck replace the line `    if($Check.Kind-eq'same'){` with

   ```powershell
       if($Check.Kind-eq'same'-and-not$Check.Key){
           # A whole file is its Git blob, as `blob` judges it: `git show` text loses the final newline
           # and the working tree's line endings, so a text comparison could never hold in the hook.
           $was=Get-RepoBlob $Check.Ref $Check.Path
           if(-not$was){return "$where does not exist at $($Check.Ref)"}
           if($was-ne(Get-RepoBlob $Ref $Check.Path)){return "$where differs from $($Check.Ref)"}
       }
       if($Check.Kind-eq'same'-and$Check.Key){
   ```

   In Assert-AssuranceAdmission replace

   ```powershell
               'same/same'{-not(Same-Text "$(Get-CheckTarget $a $a.Ref)" "$(Get-CheckTarget $b $b.Ref)")}
   ```

   with

   ```powershell
               'same/same'{if($a.Key){-not(Same-Text "$(Get-CheckTarget $a $a.Ref)" "$(Get-CheckTarget $b $b.Ref)")}else{(Get-RepoBlob $a.Ref $a.Path)-ne(Get-RepoBlob $b.Ref $b.Path)}}
   ```

   The resulting file's Git blob is b7ffba9cc4907794ca45d410c74fa8c103a432d7.
3. Check whether `scripts/test_agent_continuity.ps1` contains `281-CM5 CHECK MUTATION: an unchanged file is its index blob`; if so record Already Applied. Otherwise insert exactly the following lines immediately after the line `        'if($why){throw "CRITERION_CHECK_FAILED' 'if($false){throw "CRITERION_CHECK_FAILED' 'CHECK'`, and change nothing else:

   ```powershell
       # A whole-file `same` is the file's Git blob. Compared as text, `git show` lost the final newline,
       # so the hook refused every unchanged file (SPEC-282 recorded it) and neither mode saw a
       # changed final newline. Reaching the receipt prerequisite proves the criterion stage passed.
       # ChLife re-commits the unchanged base, so its returned text carries git's "nothing to commit".
       function ChWhole([string]$Rel='notes.md',[string]$Scope=$chPlain,[scriptblock]$Mid={},[switch]$Open){
           $b=ChBase;ChLife @{Scope=$Scope;Acceptance="$Rel is unchanged. ``check: same $Rel @$b``"} -NoReset -Mid $Mid -Open:$Open|Out-Null;$b
       }
       $atReceipt='CODE: COMPLETION_PREREQUISITE[\s\S]*no local certification receipt'
       ChWhole -Open|Out-Null;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run 'Gate'
       Assert '281-C9 CHECK: an unchanged file holds a whole-file same in the hook' ($r.Text-notmatch'CRITERION_CHECK_FAILED'-and$r.Text-match$atReceipt) $r.Text
       Pop 'CHECK' 'accept'
       $b=ChWhole;$r=RunRange $b
       Assert '281-C10 CHECK: the same completion is READY in the range' ($r.Code-eq0-and$r.Text-match'ORVION: READY') $r.Text
       Pop 'CHECK' 'accept'
       $newline={Put 'notes.md' 'Agents read the Release channel line before a release.';Commit 'ch-newline'}
       $b=ChWhole -Scope "notes.md;$chPlain" -Mid $newline;$r=RunRange $b
       Assert '281-C11 CHECK: a removed final newline fails a whole-file same in the range' ($r.Code-ne0-and$r.Text-match'CRITERION_CHECK_FAILED.*notes\.md differs') $r.Text
       Pop 'CHECK' 'reject'
       ChWhole -Scope "notes.md;$chPlain" -Open|Out-Null;Put 'notes.md' 'Agents read the Release channel line before a release.';Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.');$r=Run 'Gate'
       Assert '281-C12 CHECK: the same change fails it in the hook' ($r.Code-ne0-and$r.Text-match'CODE: CRITERION_CHECK_FAILED') $r.Text
       Pop 'CHECK' 'reject'
       # An unchanged file is its index blob: under core.autocrlf=true hash-object alone re-normalizes a
       # CRLF blob that `git add` keeps, and would refuse it.
       $crlf={ChBase|Out-Null;git -C $root config core.autocrlf true;Put 'crlf.txt' "a`r`nb`r`n";git -C $root -c core.autocrlf=false add crlf.txt;git -C $root commit -m 'ch-crlf' --quiet
           $b=(git -C $root rev-parse HEAD).Trim();ChLife @{Scope=$chPlain;Acceptance="crlf.txt is unchanged. ``check: same crlf.txt @$b``"} -NoReset -Open|Out-Null;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.')}
       & $crlf;$r=Run 'Gate';git -C $root config --unset core.autocrlf
       Assert '281-C13 CHECK: an unchanged CRLF blob holds under core.autocrlf=true' ($r.Text-notmatch'CRITERION_CHECK_FAILED'-and$r.Text-match$atReceipt) $r.Text
       Pop 'CHECK' 'accept'
       MutationKill '281-CM4 CHECK MUTATION: a whole-file same is judged by blob, not text' {ChWhole -Open|Out-Null;Put '_ORVION_CANONICAL/manifest.md' (ManifestText 'None.')} $atReceipt `
           "if(`$Check.Kind-eq'same'-and`$Check.Key){" "if(`$Check.Kind-eq'same'){" 'CHECK'
       MutationKill '281-CM5 CHECK MUTATION: an unchanged file is its index blob' $crlf $atReceipt `
           "if(`$LASTEXITCODE-eq0-and(git -C `$Root ls-files -- `$Path)){" 'if($false){' 'CHECK'
       git -C $root config --unset core.autocrlf
   ```

   The resulting file's Git blob is 30be3819df4caad865d1665a881760cee53ad396.
4. Check whether the Runtime Checkpoint reads `Resume Step: DONE`; if so record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, confirm `pwsh -NoProfile -File scripts/generate-ai-map.ps1 -Check` exits 0 and that `git diff --name-only` names only Write Scope paths, append the Execution Log entry, set the Runtime Checkpoint to `Resume Step: DONE`, `Blocker: None`, `Recovery Attempt: 0`, and commit the implementation and checkpoint together through the unchanged pre-commit hook.
5. Check that a fresh native receipt for this contract matches, a `Verdict: Confirmed Complete` Verification Notes entry exists and every Acceptance Criterion and Review Gate item holds; only then record Already Applied. Otherwise, from the repository root, start `pwsh -NoProfile -File scripts/run_timed.ps1 -Log <log> -Command "pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish"` and, at the same time, `pwsh -NoProfile -File scripts/watch_run.ps1 -Log <log> -Run spec-286-finish -Brief`, at a time when the run cannot execute `scripts/test_future_date_guard.ps1` across 10:00 UTC. Require `LOCAL_CERTIFY: READY`; a failed command keeps its real exit code and evidence and starts bounded recovery without weakening any assertion. Perform independent live Review against the repository and append its Verification Notes verdict. Then complete through the native lifecycle with the unchanged pre-commit hook, setting `manifest.md`'s `Active Change Request` to `None.` and its `Last Completed` to exactly `Last Completed: **SPEC-286: whole-file checks are judged by Git blob, transferred from the certified Founder correction — fresh local verification and Review complete; owner publication/promotion and exact-SHA remote certification follow `CR_LIFECYCLE.md` §9. Batch 6 remains ON HOLD by owner decision (2026-10-18) until the infrastructure programme completes and the owner authorizes resumption. CTRL-19 remains OPEN.**`, regenerating the projections with the existing generator. Locally prepare the exact candidate with `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BindCandidate -Root <original-checkout> -BaseRef <full-main-SHA> -HeadRef <full-candidate-SHA>`. Stop before publication or promotion.

## Acceptance Criteria

- [ ] The Gate judges a whole-file same by Git blob in both modes and an unchanged tracked file by its index blob, with exactly the transferred bytes. `check: blob scripts/check_agent_continuity.ps1 b7ffba9cc4907794ca45d410c74fa8c103a432d7` `check: has scripts/check_agent_continuity.ps1 "if($Check.Kind-eq'same'-and-not$Check.Key){"` `check: has scripts/check_agent_continuity.ps1 "git -C $Root diff --quiet -- $Path 2>$null"`
- [ ] The control suite proves the correction positively, negatively and by mutation. `check: blob scripts/test_agent_continuity.ps1 30be3819df4caad865d1665a881760cee53ad396` `check: has scripts/test_agent_continuity.ps1 "281-CM4 CHECK MUTATION: a whole-file same is judged by blob, not text"` `check: has scripts/test_agent_continuity.ps1 "281-CM5 CHECK MUTATION: an unchanged file is its index blob"`
- [ ] No Founder-only content is transferred. `check: lacks scripts/test_agent_continuity.ps1 "SPEC-288"` `check: blob scripts/watch_ci.ps1 ca87c18d3ac7fa62f70f5df681c5df18cf482699` `check: lacks scripts/watch_ci.ps1 "FOUNDER_REPOSITORY_MISMATCH"`
- [ ] Release authorities and the date-guard test are unchanged. `check: blob scripts/publish_candidate.ps1 d168504cc66c3a0759ac3ee9b5e01045a0f46589` `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79` `check: blob .github/workflows/orvion-acceptance.yml b242e4c7401258404c5d43bffb49c3f53f42467e` `check: blob scripts/test_future_date_guard.ps1 3c841e0e5a7bce65844c624630ad08be98651ec8`
- [ ] The manifest records the owner's Batch 6 hold. `check: has _ORVION_CANONICAL/manifest.md "Batch 6 remains ON HOLD by owner decision (2026-10-18)"`

## Execution Log

None.

### 2026-10-18 — Gate 1 approval recorded

Owner conditionally approved frozen Draft SHA256 0449080FCD55C61F069FE9B510CFA823F4369C21EAE6B6C0C2C28BD7F8BC28A7 at baseline fd118fae6c76271100d67fdb44923bb0b406c986, subject to two evidence checks; both passed from retained evidence without changing the Draft. The final rehearsal's Complete hook ran all five criterion checks (Validate-TransitionEvidence) before the receipt check and refused only at the missing receipt; its range and trusted judgments were READY on the final bytes. The five remaining harness cases are one pre-existing keyed-BOM false refusal, identical before and after the correction, unused by this contract's criteria, and absent from Platinum (0 of 976 blobs carry a BOM); it is preserved for CR C. Immediately revalidated the hash, all eleven source anchors, refreshed origin/main and the allocator; Draft allocated as df19501. No implementation performed before this transition. CTRL-19 remains OPEN.

### 2026-10-18 — Implementation checkpoint (Claude)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: the owner's Gate 1 approval names this exact Draft's SHA-256; remote main was fd118fae6c76271100d67fdb44923bb0b406c986 and all eleven source anchors matched at HEAD; Draft allocated as df19501 and approved as fa7f49e with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: the three evaluator replacements, copied from the reviewed sandbox bytes; `scripts/check_agent_continuity.ps1` blob b7ffba9cc4907794ca45d410c74fa8c103a432d7 (12 insertions, 3 deletions).
- Step 3 Applied: the seven control tests inserted after the named line; `scripts/test_agent_continuity.ps1` blob 30be3819df4caad865d1665a881760cee53ad396 (33 insertions).
- Step 4 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, `git diff --name-only` names only Write Scope paths. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain. Preparation measurements are not final verification. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

## Verification Notes

None.

## Review Gate

- [ ] Exact approved steps and exhaustive scope independently confirmed.
- [ ] Every acceptance criterion confirmed against final local evidence.
- [ ] Mandatory profiles and Git checks pass through fresh Finish.
- [ ] Release authorities, Founder isolation and historical evidence preserved; CTRL-19 remains OPEN.

## Notes

Three-pass Draft assurance. V1 transferred the Founder hunks verbatim with the Founder watcher change. V2 challenged it: the watcher change refuses every repository but `Shehabhub/ORVION` and Platinum's default is already correct, so it is excluded; a ported test comment named a Founder contract identity, which any tracked mention would reserve here, so it now cites `SPEC-282`; a keyless `same` in this contract's own criteria would be judged by the old evaluator in the trusted range and the new one in the hook, so the criteria use `has`, `lacks` and `blob`; moving the pinned Batch 6 lines is an authority change, so the hold is recorded in Last Completed and here; no suite outside the derived profiles declares a `check:` clause, so no Additional Verification is earned. V3 refreshed the Git authority on 2026-10-18: `git hash-object` applies attribute-driven input filters including end-of-line conversion unless `--no-filters` (https://git-scm.com/docs/git-hash-object), and `git diff --quiet -- <path>` compares the working tree with the index and implies `--exit-code`, 0 meaning no difference (https://git-scm.com/docs/git-diff); a non-zero or error exit therefore keeps the previous `hash-object` behaviour. V3 is selected.

Repository identity checked from effective Git configuration including inherited scope: this checkout commits as `PlatPlusHub <platplustours@gmail.com>` from its local configuration; the Founder checkouts commit as `Shehabhub <shehab.nim@gmail.com>` from theirs. Push authentication is not commit authorship and neither is changed here.
