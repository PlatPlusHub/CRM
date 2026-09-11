# Change Request — SPEC-164

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close the three evidence-lifecycle gaps in the Agent Control Plane so that `Complete` is mechanically bound to a fresh successful local certification, the DATABASE profile has an executable success path as well as a failure path, and `-Certify` proves every workflow expected for the completed change actually ran on the exact certified SHA.

## Business Reason

The control plane already enforces write authority mechanically, but its evidence chain is weaker than its authority chain in three measured places. A `Complete` transition currently needs only checked boxes, a `Verdict: Confirmed Complete` line and `Resume Step: DONE` — none of which requires `-Finish` to have succeeded, so a weaker agent can complete work it never certified. The DATABASE profile can only ever report `LOCAL_NOT_EXECUTED`, which leaves that same agent choosing between permanent incompleteness and the completion loophole. And `-Certify` reasons only about runs it happened to observe, so a required workflow that silently fails to trigger is indistinguishable from one that passed. Closing all three makes the evidence chain as deterministic as the write-authority chain.

## Risks

Low and bounded. The receipt is a local, untracked, anti-omission artifact — it adds no persistent repository state, no service, and no second authority; its worst failure mode is refusing a completion that should have been allowed, which is fail-closed and recoverable by running `-Finish`. Making DATABASE commands execute means `-Finish` on database work now runs a destructive local reset; that command was already mandatory in `ENGINEERING_METHOD.md §4` and runs only under `-Finish`, never under `-Boot` or `-Gate`. Deriving expected workflows from the workflow files themselves risks a false failure if a trigger list is rewritten in a form the reader does not parse; the reader is therefore restricted to the exact glob forms the repository actually uses and a workflow with no `push:` trigger is never expected.

## Supersedes / Depends On

None

## Write Scope

- `changes/SPEC-164-agent-control-evidence-lifecycle-closure.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `.gitignore`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_primary_ledger.ps1`
- `reports/evidence/primary-ledger-evidence.json`
- `scripts/check_database_parity.ps1`
- `supabase/migrations`
- `GOVERNANCE.md`
- `PROJECT_CONTEXT.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`

## Runtime Checkpoint

Resume Step: 5
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Implementation Steps

1. Check for `Assert '95` in `scripts/test_agent_continuity.ps1`. If absent, add the DEFECT A mutation group: a `Complete` transition with every box checked, a `Verdict: Confirmed Complete` and `Resume Step: DONE` but no local certification receipt must be REJECTED; the same transition with a receipt naming a different Change Request, a receipt whose recorded verification profiles differ from the derived profiles, and a receipt whose implementation fingerprint no longer matches the working tree must each be REJECTED; and a `-Finish` run that reaches `LOCAL_CERTIFY: READY` must produce a receipt that then permits the otherwise-valid transition. Run the suite and record that the new cases fail against the unmodified control script.
2. Check for `function Implementation-Fingerprint` in `scripts/check_agent_continuity.ps1`. If absent, add the certification receipt: a constant receipt path `.orvion-local-certification.json` under `$Root`; `Implementation-Fingerprint`, which hashes each Write Scope path in sorted order together with the SHA-256 of its bytes (or the literal `absent`), skipping exactly the governing Change Request and `_ORVION_CANONICAL/manifest.md` because those two are what the completion act itself rewrites; and a writer invoked only on the `LOCAL_CERTIFY: READY` branch of `Finish-Checks`, recording the Change Request identity, the derived verification profiles, the fingerprint, the expected workflow names and `result: READY`.
3. Check for `no local certification receipt` in `scripts/check_agent_continuity.ps1`. If absent, extend `Validate-CompletionPrerequisites` to require, when the run is local (no `-BaseRef`), a readable receipt whose Change Request identity, verification profiles and implementation fingerprint all match the state being completed and whose result is `READY`; every mismatch is a distinct `COMPLETION_PREREQUISITE:` subject. A range run in CI holds no receipt and is exempt, because CI re-executes the certification itself.
4. Check for `.orvion-local-certification.json` in `.gitignore`. If absent, add it with a comment stating that the receipt is a local anti-omission artifact and never repository truth.
5. Check for `Assert '99` in `scripts/test_agent_continuity.ps1`. If absent, add the DEFECT B mutation group against stubbed executables placed on `PATH` inside the sandbox: a DATABASE profile whose mandatory local commands did not execute must not reach `LOCAL_CERTIFY: READY`; a DATABASE profile where one mandatory command exits non-zero must fail with that command, its exit code and diagnostic evidence; a DATABASE Change Request that does not declare the `supabase-local` capability must be rejected; a DATABASE Change Request that names no `scripts/verify_` HTTP suite in Additional Verification must be rejected; and a DATABASE Change Request whose entire protocol succeeds must reach `LOCAL_CERTIFY: READY`. Run the suite and record that the new cases fail against the unmodified control script.
6. Check for `npx supabase db reset` in `scripts/check_agent_continuity.ps1`. If absent, make the DATABASE profile executable: replace its `LOCAL_NOT_EXECUTED` list with the `ENGINEERING_METHOD.md §4` protocol as mandatory local commands in the existing order — clean reset, pgTAP Pass A, the contract's `scripts/verify_` HTTP suites, pgTAP Pass B without reset, the `scripts/verify_database.sql` smoke, then `scripts/check_database_parity.ps1` — with the smoke expressed as a PowerShell pipeline because `<` input redirection is not valid PowerShell. Keep the Primary reading as `EXTERNAL:` deferred evidence.
7. Check for `$seen` in `Finish-Checks` in `scripts/check_agent_continuity.ps1`. If absent, replace the flat `Select-Object -Unique` deduplication with a per-profile one, so a command contributed by two different profiles still runs once while pgTAP Pass A and Pass B — the same command, deliberately run twice within one profile — both execute.
8. Check for `DATABASE_CAPABILITY_NOT_DECLARED` in `scripts/check_agent_continuity.ps1`. If absent, require that a contract whose derived profiles include DATABASE declares the `supabase-local` capability and names at least one `scripts/verify_` command in Additional Verification, each with its own error code, so an undeclared stack or an unstated HTTP suite fails at Boot with a precise message instead of mid-protocol.
9. Check for `check_primary_ledger.ps1` inside the `$script:Capabilities` table in `scripts/check_agent_continuity.ps1`. If absent, attach the existing Primary evidence validator to the `supabase-primary` capability entry, so declaring it adds `scripts/check_primary_ledger.ps1` as a mandatory `-Finish` command and the Boot line states that recorded Primary evidence is validated rather than that the connector was reached. Do not modify the validator or its evidence file.
10. Check for `supabase/tests/` in the `Profiles` function of `scripts/check_agent_continuity.ps1`. If absent, add `supabase/tests/` and `supabase/config.toml` to the DATABASE-sensitive surface so local certification and Migration CI cannot disagree about whether a change is database-sensitive.
11. Check for `Assert '104` in `scripts/test_agent_continuity.ps1`. If absent, add the DEFECT C mutation group against a stubbed `gh` on `PATH`: one required workflow succeeding while another required workflow produced no run on the SHA must not be READY; a required workflow that succeeded only on a different SHA must not satisfy the requirement; a required workflow that is queued or in progress must be PENDING; a required workflow concluding failure, cancellation or timeout must be FAILED; and every expected workflow present and successful on the exact SHA must be READY. Run the suite and record that the new cases fail against the unmodified control script.
12. Check for `function Workflow-Expectations` in `scripts/check_agent_continuity.ps1`. If absent, derive the expected workflow set from the workflow files themselves: read each `.github/workflows/*.yml`, take its `name:`, and expect it when it declares a `push:` trigger with no `paths:` filter, or when any Write Scope path matches one of that filter's globs. Restrict glob translation to the three forms the repository uses — an exact path, a `prefix/**` subtree, and a `**/*.ext` suffix. Record the resulting set in the certification receipt so `-Certify` derives nothing independently.
13. Check for `REQUIRED_WORKFLOW_MISSING` in `scripts/check_agent_continuity.ps1`. If absent, repair `Certify-Remote` to compare the receipt's expected workflow set against the runs observed on the exact `HEAD` SHA before judging conclusions: no runs at all is PENDING; a missing required workflow while other runs are still in progress is PENDING; a missing required workflow once every observed run has completed is FAILED; an observed run still in progress is PENDING; any observed run not concluding `success` is FAILED; otherwise READY. A missing or unreadable receipt fails closed.
14. Check for `local certification receipt` in `CR_LIFECYCLE.md`. If absent, record in §8 that a `Complete` transition additionally requires a fresh local certification receipt bound to the implementation state, amend the existing sentence about storing no contract fingerprint so it continues to state the truth about frozen authority while distinguishing the implementation-state fingerprint, and note in §9 that `-Certify` now proves expected workflows before conclusions.
15. Check for `executes that protocol` in `ENGINEERING_METHOD.md`. If absent, replace the §4 paragraph stating that `-Finish` lists the database commands as `LOCAL_NOT_EXECUTED` and withholds `LOCAL_CERTIFY: READY` with the current behaviour: `-Finish` executes the protocol in order and certification is earned or refused on the result.
16. Check for `local certification receipt` in `changes/TEMPLATE.md` and `AGENTS.md`. If absent, add to the TEMPLATE Acceptance Criteria guidance that local certification is proven by the receipt rather than asserted in a checkbox, and correct any AGENTS.md sentence that describes completion prerequisites in a way the enforcement no longer matches.
17. Check that `_ORVION_CANONICAL/manifest.md` names `changes/SPEC-164-agent-control-evidence-lifecycle-closure.md` as the Active Change Request. If it does not, set it, and regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` so the mirrored live state agrees.

## Acceptance Criteria

- [ ] `scripts/check_agent_continuity.ps1 -Finish` writes `.orvion-local-certification.json` only on the `LOCAL_CERTIFY: READY` branch, and the file records the Change Request identity, the derived verification profiles, an implementation fingerprint and the expected workflow names.
- [ ] A local `In Progress -> Complete` transition with every completion prerequisite textually satisfied and no receipt present is rejected with `COMPLETION_PREREQUISITE:no local certification receipt`.
- [ ] A receipt naming a different Change Request, a receipt whose recorded profiles differ from the derived profiles, and a receipt whose fingerprint no longer matches the working tree are each rejected with their own distinct `COMPLETION_PREREQUISITE:` subject.
- [ ] A local `In Progress -> Complete` transition with a fresh matching receipt is accepted.
- [ ] A CI range run reaches the same completion without a receipt, so the receipt never becomes an unsatisfiable CI precondition.
- [ ] `.gitignore` excludes `.orvion-local-certification.json`, and `git status --porcelain` is empty with the receipt present.
- [ ] The DATABASE profile's mandatory local commands are the `ENGINEERING_METHOD.md §4` protocol in its documented order, with the smoke step expressed as a valid PowerShell pipeline.
- [ ] A DATABASE Change Request whose every mandatory local command succeeds reaches `LOCAL_CERTIFY: READY`.
- [ ] A DATABASE Change Request where one mandatory local command exits non-zero fails with that command, its exit code and a diagnostic tail, and never reaches `LOCAL_CERTIFY: READY`.
- [ ] pgTAP Pass A and Pass B both execute despite being the same command string, and a command contributed by two different profiles still executes once.
- [ ] A contract deriving the DATABASE profile without declaring `supabase-local` is rejected, and one naming no `scripts/verify_` HTTP suite in Additional Verification is rejected, each with its own error code.
- [ ] Declaring the `supabase-primary` capability makes `scripts/check_primary_ledger.ps1` a mandatory `-Finish` command, and its Boot line claims recorded evidence rather than a live read.
- [ ] The DATABASE-sensitive path surface includes `supabase/migrations/`, `supabase/tests/`, `supabase/config.toml` and `scripts/verify_database.sql`, matching Migration CI's trigger surface.
- [ ] `-Certify` reports FAILED when a required workflow produced no run on the exact `HEAD` SHA while every observed run has completed, including the case where that workflow succeeded only on a different SHA.
- [ ] `-Certify` reports PENDING when a required workflow is queued or in progress, and FAILED when an observed run concluded failure, cancellation or timeout.
- [ ] `-Certify` reports READY only when every expected workflow is observed on the exact `HEAD` SHA and every observed run concluded `success`, and fails closed when no receipt is readable.
- [ ] The expected workflow set is derived from the `push:` triggers declared in `.github/workflows/*.yml` and recorded in the receipt, so `-Certify` re-derives nothing and no second authority for workflow expectations exists.
- [ ] `scripts/test_agent_continuity.ps1` reports 0 failed, retains every one of the 94 pre-existing assertions in rejecting and accepting form, and adds the DEFECT A, B and C groups.
- [ ] `CR_LIFECYCLE.md §8` records the receipt requirement and no longer implies that no fingerprint of any kind is stored; §9 records the expected-versus-observed rule.
- [ ] `ENGINEERING_METHOD.md §4` states that `-Finish` executes the database protocol rather than listing it as `LOCAL_NOT_EXECUTED`.
- [ ] `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` reports `REPOSITORY CONSISTENCY: CLEAN`.
- [ ] No file outside this Change Request's Write Scope is created, modified or deleted, and `git diff --check` is clean.

## Execution Log

### 2026-09-11 — implementation agent

Outcome: In Progress

Step results:
- Step 1: Applied — DEFECT A mutation group added as cases 95, 96, 97, 98, 98b, 98c. Proven failing against the unmodified control script: 94 passed, 6 failed. The fixture builder gained multi-path Write Scope support (`;`-separated) because the staleness attack needs both a real implementation file and the manifest in one scope.
- Step 2: Applied — `Implementation-Fingerprint`, `Write-Certification` and the `.orvion-local-certification.json` receipt path added. The fingerprint covers Write Scope file content and skips exactly the governing contract and the manifest, the two files the completion act itself rewrites.
- Step 3: Applied — `Validate-Certification` called after `Validate-ManifestCrState`, local runs only, with a distinct `COMPLETION_PREREQUISITE:` subject per failure mode. A stale receipt from a failed Finish is impossible: `Finish-Checks` deletes any prior receipt before running anything.
- Step 4: Applied — `.gitignore` excludes the receipt.

Cases 32 and 71 were updated, not weakened: both assert a LOCAL completion that must now also be certified, so each earns a receipt via `-Finish` first. Case 32 additionally deletes the receipt before its range half, which is what proves the receipt never became an unsatisfiable CI precondition.

Evidence: `scripts/test_agent_continuity.ps1` 100 passed, 0 failed.

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

Earn-It record for the mechanisms this Change Request adds, and for the ones it deliberately does not.

Added, each closing exactly one measured failure: a single gitignored receipt file with an implementation-state fingerprint, because nothing in the repository recorded whether `-Finish` had succeeded for the state being completed and the Git baseline cannot prove anything about an uncommitted working tree; the existing `ENGINEERING_METHOD.md §4` commands promoted from a printed list to executed mandatory verification, because a profile with no success path forces a weaker agent to choose between permanent incompleteness and the completion loophole; the existing `scripts/check_primary_ledger.ps1` attached to the `supabase-primary` capability entry, because that validator already distinguishes proven from stale evidence and a second one would be a second authority; and an expected-workflow set read from the workflow files' own `push:` triggers and recorded in the receipt, because `-Certify` judged only runs it happened to see.

Deliberately not added: any signing, sealing or cryptographic trust — the receipt is an anti-omission and anti-staleness control and is written by the same process it constrains, so it proves that certification ran against this exact implementation state and nothing more; a certification service, daemon, watcher or evidence database; a generic path-expression engine, the glob reader handling only the three forms the repository actually uses; a second definition of verification profiles, database-sensitive paths or expected workflows; and any new workflow file, since no repair here requires one.
