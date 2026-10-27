# Change Request — SPEC-296

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the owner Publish and Promote interfaces save their operation evidence by default in the `ORVION-Owner-Tools` folder beside this product's checkout, instead of `Documents\ORVION-Owner-Review`, while an explicit `-EvidenceDirectory` keeps choosing any destination.

## Business Reason

Both interfaces fall back to `Documents\ORVION-Owner-Review\owner-operations\PlatPlusHub_CRM`. The owner has consolidated the workspace into three folders beside the repositories (`ORVION-Workbench`, the private `ORVION-Owner-Tools` with its off-device continuity copy, and a disposable temporary folder) and will delete the retired `Documents\ORVION-*` folders, so a release run without `-EvidenceDirectory` would write its only operation record into a folder scheduled for deletion and outside the continuity copy. One default per interface moves to `<folder holding the checkout>\ORVION-Owner-Tools\records\owner-operations\PlatPlusHub_CRM`; nothing else changes.

## Risks

A wrong default would lose or misplace release evidence. The default is derived from the interface's own location (`$PSScriptRoot`), never from Publish's candidate `-Root`, so the trusted main beside the other repositories writes into Owner-Tools. The anchor is location-relative, not a containment guard: a clone in a dedicated disposable parent writes beside itself, while a checkout at a drive root, or a clone sharing a parent with other work, must pass an explicit `-EvidenceDirectory`. The evidence format, file naming, allowlisted metadata, refusal semantics, interactive confirmation and every native release judgment are unchanged; the directory is still created on demand. No dependency on Owner-Tools content is introduced: only a destination path. Gate 1 of this contract is DELEGATED under the owner's exceptional delegation of 2026-10-26 and the owner's Step 2 approval of 2026-10-27, never a human-typed digest. Founder is not referenced or changed. Publication and promotion stay separately governed. Batch6/Phase8 remain ON HOLD until the owner's recorded lift; CTRL-19 remains OPEN.

## Supersedes / Depends On

None.

## Write Scope

- `scripts/owner_publish.ps1`
- `scripts/owner_promote.ps1`
- `scripts/test_owner_interfaces.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `changes/TEMPLATE.md`
- `scripts/owner_publish.ps1`
- `scripts/owner_promote.ps1`
- `scripts/test_owner_interfaces.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- pwsh -NoProfile -File scripts/test_owner_interfaces.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: SPEC-296-V1 changes only the fallback expression in each interface's evidence-directory line and adds one actual-child case per interface to the owning `test_owner_interfaces.ps1`; anchoring the default to the interface's own checkout keeps it correct after a restore into the same three-folder layout and keeps disposable clones out of the owner's records.

Pass 2 Adversarial Review: SPEC-296-V2 ran the owning suite on the prototype (51 passed, 0 failed, including both new cases) and scoped mutants: each interface's anchor one folder level too shallow, and Publish's default derived from its candidate `-Root`; each was detected by exactly its own new case (saved=0) while the other passed. The explicit `-EvidenceDirectory` path is exercised by every existing fixture case. An independent Codex review (advisory) found the missing Permanent-Control Admission, a Publish fixture that could not tell the trusted source from the candidate (the candidate now lives under a different parent) and an overbroad isolation claim; all three were adopted.

Pass 3 Evidence Refresh: 2026-10-27. SPEC-296-V3 re-read AGENTS.md (owner interfaces: metadata goes outside the checkout; `-EvidenceDirectory` chooses the destination), the profile mapping (`test_owner_interfaces.ps1` is not in a native profile, so it is named once in Additional Verification as in SPEC-293), a tracked-text search showing no other consumer of the old default outside terminal Change Requests, and the owner's three-folder decision; exact sandbox native lifecycle must pass before the original delegated approval.

Selected Version: SPEC-296-V3; selected: the smallest change that keeps owner release evidence out of the folders the owner will delete, with one owning regression case per interface

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Default evidence directory of `scripts/owner_publish.ps1` | Owner running Publish without `-EvidenceDirectory` | WRITE | Fallback derives from `$PSScriptRoot`; explicit `-EvidenceDirectory` branch, record schema, file name and refusal semantics unchanged |
| Default evidence directory of `scripts/owner_promote.ps1` | Owner running Promote without `-EvidenceDirectory` | WRITE | Same single fallback change; promote semantics unchanged |
| Default-path regression | Owning `scripts/test_owner_interfaces.ps1` | WRITE | One actual-child case per interface; all previous cases unchanged and still pass an explicit `-EvidenceDirectory` |
| Owner interface documentation | `AGENTS.md` repository-local adapters paragraph | VERIFY | It states that metadata goes outside the checkout and `-EvidenceDirectory` chooses the destination; both stay true, so the text is unchanged |
| Historical mentions of the old default | Terminal Change Requests under `changes/` | UNAFFECTED | Immutable history; describes past behavior |
| Verification selection | Native profile engine and Finish | VERIFY | Source scope derives native obligations; the owning interface suite runs once as Additional Verification, never an implementation step |
| Active task and generated discovery | Native Boot and manifest projections | WRITE | Existing legal pointer/completion synchronization and native generator only |
| Native release engines, CI, credentials and Founder | `scripts/publish_candidate.ps1`, `scripts/promote_main.ps1`, workflows, Founder repository | UNAFFECTED | No engine, workflow, credential, routing or Founder change |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Selected bytes and baseline anchors | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Own native profiles and fresh verification | BEFORE_COMPLETION | NONE | NONE | NONE |
| Native source/receipt/Review independence | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `scripts/test_owner_interfaces.ps1` actual-child fixtures and its explicit `-EvidenceDirectory` cases.

Added Property: an omitted `-EvidenceDirectory` resolves to `ORVION-Owner-Tools\records\owner-operations\PlatPlusHub_CRM` beside the interface's own checkout, independently of Publish's candidate `-Root`.

Causal Negative: the baseline defaults write into `Documents\ORVION-Owner-Review`, which the owner will delete; a Publish default derived from its candidate `-Root` would pass a fixture where candidate and interface share one checkout, so the candidate lives under a different parent.

Positive Test Design: both unmodified interfaces, run as real children with `-NonInteractive` and no `-EvidenceDirectory`, save exactly one `INTERACTIVE_CONFIRMATION_REQUIRED` record at the source-derived destination; every existing explicit-directory case still passes.

Negative Test Design: a wrong-depth anchor in either interface and a candidate-derived Publish anchor each fail the corresponding default-path case.

Non-Empty Population Obligation: both default-path cases execute and each observes exactly one JSON record; no fixture writes outside its temporary root or performs a real release.

Mutation Obligation: independently kill each interface's wrong-depth anchor and Publish's candidate-derived anchor before trusting the cases.

Post-Implementation Proof Obligation: one authorized native timed/watched Finish runs the derived mandatory commands and the owning interface suite as Additional Verification on final implemented bytes; independent Review, Complete, bind, separately authorized publication, hosted checks and exact-SHA certification follow.

## Implementation Steps

1. Check whether `scripts/owner_publish.ps1` contains `'ORVION-Owner-Tools\records\owner-operations\PlatPlusHub_CRM'`; if so record Already Applied when its Git blob is 6c5152d32e4f272a5ddfed4524cacda1f16cdd5a, and otherwise stop and report. Otherwise make exactly this one edit (owner evidence default beside the checkout), each matched once, and change nothing else:

   a) replace the line
   ```text
       $logs = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) } else { Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'ORVION-Owner-Review\owner-operations\PlatPlusHub_CRM' }
   ```
   with
   ```text
       $logs = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) } else { Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'ORVION-Owner-Tools\records\owner-operations\PlatPlusHub_CRM' }
   ```

   The resulting file's Git blob is 6c5152d32e4f272a5ddfed4524cacda1f16cdd5a.

2. Check whether `scripts/owner_promote.ps1` contains `'ORVION-Owner-Tools\records\owner-operations\PlatPlusHub_CRM'`; if so record Already Applied when its Git blob is 66ce3167ed07cd1272cae5d320cb068579501111, and otherwise stop and report. Otherwise make exactly this one edit (owner evidence default beside the checkout), each matched once, and change nothing else:

   a) replace the line
   ```text
       $logs = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) } else { Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'ORVION-Owner-Review\owner-operations\PlatPlusHub_CRM' }
   ```
   with
   ```text
       $logs = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) } else { Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'ORVION-Owner-Tools\records\owner-operations\PlatPlusHub_CRM' }
   ```

   The resulting file's Git blob is 66ce3167ed07cd1272cae5d320cb068579501111.

3. Check whether `scripts/test_owner_interfaces.ps1` contains `default-evidence-directory`; if so record Already Applied when its Git blob is 95bb63838453351434dba3bbb75846ee98c8e41e, and otherwise stop and report. Otherwise make exactly this one edit (owner evidence default beside the checkout), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
       }
   }
   ```
   insert
   ```text
   # Without -EvidenceDirectory, evidence goes to the ORVION-Owner-Tools folder beside the interface's own checkout.
   foreach ($fileName in @('owner_publish.ps1','owner_promote.ps1')) {
       $parent = Join-Path $work ('default-'+$fileName)
       $copy = Join-Path $parent "checkout\scripts\$fileName"
       Write-FixtureText $copy ([IO.File]::ReadAllText((Join-Path $Root "scripts\$fileName")))
       $childArguments = @('-NoProfile','-File',$copy,'-Candidate',('a'*40),'-NonInteractive')
       if ($fileName -eq 'owner_publish.ps1') { $childArguments += @('-Root',(Join-Path $parent 'candidate-area\checkout')) }
       $lines = @(& pwsh @childArguments 2>&1); $code = $LASTEXITCODE
       $saved = @(Get-ChildItem -LiteralPath (Join-Path $parent 'ORVION-Owner-Tools\records\owner-operations\PlatPlusHub_CRM') -Filter '*.json' -File -ErrorAction SilentlyContinue)
       $record = if ($saved.Count -eq 1) { Get-Content -Raw -LiteralPath $saved[0].FullName | ConvertFrom-Json } else { $null }
       $ok = $code -eq 1 -and $null -ne $record -and $record.classification -ceq 'INTERACTIVE_CONFIRMATION_REQUIRED'
       $records.Add([pscustomobject]@{Product='self';Operation=$fileName;Case='default-evidence-directory';Passed=[bool]$ok;Exit=$code;Result=$record.result;Classification=$record.classification;NativeCalled=$false;Reason=$(if($ok){''}else{($lines|ForEach-Object{"$_"})-join"`n"})})
       Write-Host ("{0} self/{1}/default-evidence-directory: exit{2} saved={3}" -f $(if($ok){'PASS'}else{'FAIL'}),$fileName,$code,$saved.Count)
   }
   ```

   The resulting file's Git blob is 95bb63838453351434dba3bbb75846ee98c8e41e.

## Acceptance Criteria

- [ ] Exact scoped source output; `check: blob scripts/owner_publish.ps1 6c5152d32e4f272a5ddfed4524cacda1f16cdd5a`
- [ ] Exact scoped source output; `check: blob scripts/owner_promote.ps1 66ce3167ed07cd1272cae5d320cb068579501111`
- [ ] Exact scoped source output; `check: blob scripts/test_owner_interfaces.ps1 95bb63838453351434dba3bbb75846ee98c8e41e`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @20ea5e0d8f63742308efd4dc5e13ef178f0f82db`
- [ ] Without `-EvidenceDirectory` each interface saves its refusal record under `ORVION-Owner-Tools\records\owner-operations\PlatPlusHub_CRM` beside its checkout; every explicit `-EvidenceDirectory` case still passes in the owning suite.
- [ ] Independent Review inspects declared scope, exact allocation and original-versus-disposable evidence; no local fixture is called publication, promotion or remote certification.

## Execution Log

None.


### 2026-10-27 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was 20ea5e0d8f63742308efd4dc5e13ef178f0f82db and every source anchor matched there; Draft allocated as b8a4067 and approved as 9a932c2 with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `scripts/owner_publish.ps1` edited exactly as the step states; blob 6c5152d32e4f272a5ddfed4524cacda1f16cdd5a (1 insertions, 1 deletions).
- Step 3 Applied: `scripts/owner_promote.ps1` edited exactly as the step states; blob 66ce3167ed07cd1272cae5d320cb068579501111 (1 insertions, 1 deletions).
- Step 4 Applied: `scripts/test_owner_interfaces.ps1` edited exactly as the step states; blob 95bb63838453351434dba3bbb75846ee98c8e41e (14 insertions, 0 deletions).
- Step 5 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

## Verification Notes

None.


### 2026-10-27 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's exceptional delegation of 2026-10-26 and Step 2 approval of 2026-10-27; Draft SHA-256 E3E43986BB7AFB6BE6CC9DEDF969B0DD2CFEF4DEC01017D1A1CD8B1ED9D05EDE, decision SHA-256 5447D381BC34FD17904A5647A0FCF3DB2C57C0E371AC99A6BC177A69BCC71189. No fabricated human future-digest approval. Own fresh original native verification/Review/Complete/binding required; sandbox receipt certifies no original. Immediately before allocation the hash, the Draft blob 7c604d726a845ab068d36909080e799e9e0341f5, all 3 source anchors, the baseline HEAD 20ea5e0d8f63742308efd4dc5e13ef178f0f82db against refreshed origin/main 20ea5e0d8f63742308efd4dc5e13ef178f0f82db and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as b8a4067. No implementation performed before this transition. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.


Verdict: Confirmed Complete

Independent current Git evidence: selected Draft E3E43986BB7AFB6BE6CC9DEDF969B0DD2CFEF4DEC01017D1A1CD8B1ED9D05EDE, allocated blob 7c604d726a845ab068d36909080e799e9e0341f5, the three literal outputs (publish and promote default evidence directory beside the checkout in ORVION-Owner-Tools; one owning default-path case per interface), regenerated discovery, unchanged native evaluator and declared scope verified. This original root owns fresh receipt f1390e429f597f37a814a637c820d9022e5065228dbba37bd9d0115779b59b64, finishHead 464c9380d4727a4424b8d4c895d2d41b3bed4f48, profiles REPOSITORY, in a native timed/watched Finish observed READY/END0, which ran the owning interface suite as Additional Verification. Explicit -EvidenceDirectory cases unchanged. Native Complete/range/binder still own full receipt/criterion validation. No publication or hosted result asserted. Batch6/Phase8 remain ON HOLD until the owner's recorded lift; CTRL-19 remains OPEN.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-296: owner Publish/Promote default evidence directory moved to ORVION-Owner-Tools beside the checkout; native verification and Review complete. Publication/promotion remain separately governed. Batch6/Phase8 remain ON HOLD until the owner's recorded lift; CTRL-19 remains OPEN.**` and regenerate discovery. Candidate binding follows Complete and is never a pre-Complete criterion. Publication and promotion follow the native release path separately.

Exact baseline 20ea5e0d8f63742308efd4dc5e13ef178f0f82db and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `scripts/owner_publish.ps1` | `da783193f728d1a99cbda1431d03fdb57dc24f34` |
| `scripts/owner_promote.ps1` | `47aaa9eb76e5cec86dc4eab8f158050e520e71c0` |
| `scripts/test_owner_interfaces.ps1` | `e8fb155bcadc567a2ab0dd3d7707691de5bc504a` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md, the owner interfaces and their owning suite at 20ea5e0d8f63742308efd4dc5e13ef178f0f82db; the owner's exceptional delegation of 2026-10-26, three-folder decision and Step 2 approval of 2026-10-27 (recorded outside this repository). Three identified snapshots and selection reasons are retained externally; correctness remains native and independent.

Snapshot identities: V1 173932774F03E29EC2534540B22AC4DB992304FEAB92DBEEF4D8DF8EF284F877; V2 B855949E5F1031F5EAC9969CFFE580B0781B471B70CE907EC8EB2414477EE716. V3 adds this linkage and the final selection; its own SHA-256 is external.
