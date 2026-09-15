# Change Request — SPEC-184

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Candidate publication proves its committed range and uses fail-closed Git publication semantics.

## Business Reason

Publishing a candidate to `orvion-preflight` is a recurring manual sequence, and two of its steps are easy to get subtly wrong in ways the rest of the control plane cannot catch in time.

**One: nothing local proves the committed range before the push.** `-Finish` and a bare `-Gate` both judge the working tree at `HEAD`, and the pre-commit hook invokes `-Gate` with no `-BaseRef`, so none of the three ever sees the range a push will actually publish. Only CI passes a range — and by then the candidate is published. This is measured, not predicted: candidate `b70b734` was refused by both the standalone Gate and Acceptance with `OUT_OF_SCOPE_WRITE` on a contract file that no governing Write Scope authorised. The local evidence for that same tree was `LOCAL_CERTIFY: READY`. Recovery was not a patch: the governing contract was already `Complete`, its Write Scope frozen, and a terminal contract cannot be reopened — so the lineage had to be rebuilt from `main` and two contract identities were consumed. Running the existing Gate over `origin/main -> candidate HEAD` reproduced the CI verdict locally in seconds, and the rebuilt candidate was proven clean by that same command before it was published.

**Two: the lease that protects a rejected-candidate replacement is silently defeatable.** `git push --force-with-lease` with no value compares against the *remote-tracking* ref, which any earlier `git fetch` refreshes — and Publisher must fetch. The protection then reads as present and is vacuous. Only the literal `--force-with-lease=refs/heads/orvion-preflight:<expected-full-sha>`, with the expectation supplied by the caller rather than derived from the remote, actually refuses a ref that moved.

Neither fact is owned anywhere today. There is no publisher or recovery helper in the tree: the only occurrences of `force-with-lease` or `promote` in the control plane are two explanatory comments.

## Risks

Low, and the material risks are named rather than assumed away.

- The largest risk is scope. A publisher is exactly the kind of unit that grows into an orchestration layer, so V1 is bounded to one ref and one verb, and the exclusions below are part of the contract rather than an aspiration.
- A second executable on the publication path must be kept in step with Gate semantics. It is mitigated by the script never reproducing Gate logic: it invokes the existing command and refuses to continue unless that command reports READY.
- The script performs a network mutation, which is why it is a separate file and not a new switch on `scripts/check_agent_continuity.ps1`. That script judges and never mutates a remote; a Gate that can push is a Gate that can be made to push.
- A test that pushes could in principle touch a real remote. It cannot here: all three proofs run against the disposable bare repository the suite already builds inside its own sandbox.
- The honest counter-argument is recorded rather than hidden: only the range Gate is a genuinely non-trivial duty, and a written runbook would have prevented the one failure actually experienced. This contract exists because publication recurs and a runbook cannot refuse to continue.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-184-candidate-publication-proves-its-range.md`
- `scripts/publish_candidate.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `supabase/migrations`
- `supabase/tests`

Also out of scope as SUBJECTS, not merely as files. Publisher V1 does not own and must not contain: promotion to `main`; any call to or reimplementation of `-Certify`; polling or waiting for `ORVION Acceptance`; any GitHub Actions or GitHub API query; repair, rerun, suppression or interpretation of standalone `Agent Control`; a retry or recovery state machine; rollback; commit creation or rewriting; merge, rebase, cherry-pick or amend; plain `--force`; bare `--force-with-lease`; caching; concurrency policy; selective test execution; and GitHub Rulesets. The two `(SPEC-182)` provenance comments in `scripts/test_agent_continuity.ps1` are historical references to a consumed identity and are not touched by this contract.

## Required Reading

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Implementation Steps

1. Verification check: `scripts/publish_candidate.ps1` exists. If it matches, record Already Applied and skip. Otherwise create it as the only new file, performing exactly this path and stopping at the first failure without retry, recovery or repair: refuse unless `git status --porcelain` is empty; fetch `origin`; capture the fetched `origin/main` commit and the candidate `HEAD` commit ONCE as full forty-character SHAs and use those captured values for everything that follows; invoke `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BaseRef <captured origin/main> -HeadRef <captured HEAD>` and stop unless it exits zero; then push. The push is an ordinary `git push origin <captured HEAD>:refs/heads/orvion-preflight` with no force of any kind, EXCEPT when the caller has explicitly supplied an expected current preflight SHA, in which case the command must carry the literal argument `--force-with-lease=refs/heads/orvion-preflight:<expected-full-sha>` built from the caller's value. Finally report the captured base SHA, the candidate SHA and the push outcome, and stop. The script must not reproduce any Gate logic, must never read `refs/remotes/origin/orvion-preflight` to form the lease expectation, must never emit a bare `--force-with-lease` or a plain `--force`, and must contain nothing from the Out of Scope subject list.

2. Verification check: `scripts/test_agent_continuity.ps1` contains the string `164 PUBLISH`. If it matches, record Already Applied and skip. Otherwise add exactly three assertions, numbered 164, 165 and 166, to that file, reusing the disposable sandbox bare repository the suite already constructs rather than creating any fixture, helper module, stub or test framework, and touching no assertion numbered 1 through 163. Each assertion invokes `scripts/publish_candidate.ps1` against that sandbox and asserts on the sandbox remote's actual ref, so the proof is real Git behaviour and not an inspection of the command string:

   - 164: when the committed-range Gate does not succeed, no push occurs and the sandbox preflight ref is unchanged.
   - 165: when a replacement supplies the CORRECT expected preflight SHA, the push succeeds and the ref advances. This is the control for 166 — without it, 166 could pass merely because the script never pushes at all.
   - 166: when a replacement supplies a WRONG expected preflight SHA, and the remote-tracking ref has been refreshed by a fetch beforehand, the push is refused and the sandbox preflight ref is unchanged.

3. Verification check: none — this step is a proof obligation recorded in the Execution Log rather than detected in the tree. Before the candidate is accepted, kill assertions 164 and 166 with causal mutants applied to a disposable copy only, never to authoritative history: replacing the literal pinned lease with a bare `--force-with-lease` must fail 166, and removing the Gate exit-code check must fail 164. Each mutant must be run alongside the unmutated control in the same run so a kill is attributable to the mutation rather than to the harness, and the candidate must be restored exactly afterwards with the restoration proven. The bare-lease mutant is the one that matters: it is the form that looks protective and is not, and 166 is the only assertion that can tell the two apart.

## Acceptance Criteria

- [ ] `scripts/publish_candidate.ps1` exists, is the only file created by this Change Request, and refuses to proceed on a dirty working tree, on a failed fetch, on an unresolvable ref, and on a non-zero exit from the committed-range Gate.
- [ ] That script captures the fetched `origin/main` and candidate `HEAD` SHAs once and passes exactly those captured values to `check_agent_continuity.ps1 -Gate -BaseRef <base> -HeadRef <head>`, and contains no reimplementation of Gate logic.
- [ ] That script forms the replacement lease only from a caller-supplied expected SHA, emits it as the literal `--force-with-lease=refs/heads/orvion-preflight:<expected-full-sha>`, and never reads `refs/remotes/origin/orvion-preflight` to derive it.
- [ ] Neither a plain `--force` nor a bare `--force-with-lease` appears anywhere in that script, and the non-replacement path carries no force argument at all.
- [ ] That script contains no promotion to `main`, no `-Certify` call, no Acceptance polling, no GitHub Actions or API query, no retry, recovery, rollback or repair logic, and no commit-creating or history-rewriting Git command.
- [ ] `scripts/test_agent_continuity.ps1` declares assertions 164, 165 and 166, every assertion numbered 1 through 163 is unchanged in number, name and meaning, and no new test file, fixture file, stub, helper module or framework was added.
- [ ] Assertions 164, 165 and 166 each assert on the sandbox remote's actual ref after invoking the script, and all three run entirely inside the suite's existing disposable sandbox with no network access and no real remote.
- [ ] Assertion 166 fails when the pinned lease is replaced by a bare `--force-with-lease`, and assertion 164 fails when the Gate exit-code check is removed, each proven against an unmutated control in the same run and recorded in the Execution Log.
- [ ] No file outside Write Scope was created, modified or deleted, and the two `(SPEC-182)` provenance comments are unchanged.

## Execution Log

None.

## Verification Notes

None.

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

**Why the tests live in `scripts/test_agent_continuity.ps1` rather than a dedicated suite.** Decided by measuring both sides rather than by preference.

Recurring cost is negligible. Three assertions that push to a local bare repository add well under a second to a suite whose `Agent Control` run on `main` for the current head measured 213 seconds end to end, dominated by the 163 assertions already there. That is below run-to-run variance and does not approach the required admission job's 30-minute bound.

Wiring cost is not negligible, and it falls on files this contract must not touch. A separate `scripts/test_publish_candidate.ps1` would have to be registered in five places across four files to be executed and guarded at all: the `CONTROL` profile list in `scripts/check_agent_continuity.ps1`; BOTH the `push.paths` and `pull_request.paths` lists in `.github/workflows/repository-consistency.yml`, which Check 20 compares entry-for-entry and which is the exact asymmetry that guard exists to catch; that workflow's calibration loop; and the calibration loop inside `.github/workflows/orvion-acceptance.yml`, the required admission check. Four of those five sites are out of scope here, and two are the workflows a publisher must never casually edit. The existing suite needs none of it: it is already in the `CONTROL` profile, already executed by both workflows, and already covered by both path lists.

The remaining question — whether these three assertions need to run on every invocation when only Publisher changes — is real, and the answer is that answering it would cost more than the problem. Selective execution is a test-selection system, which is explicitly excluded, and the measured cost does not justify inventing one.

**Why this stays a thin paved road and not a new control plane.** The script owns no fact. It proves nothing itself: the committed range is judged by the existing Gate, the remote's position is judged atomically by Git's own lease, admission is judged by `ORVION Acceptance` and Ruleset 22950574, and post-push expected-versus-observed evidence remains owned solely by `-Certify`. What the script contributes is sequence and refusal — it runs existing commands in the one order that is safe and stops at the first failure. A runbook can describe that order but cannot decline to continue, and the failure this contract exists to prevent was precisely a step omitted rather than a step performed wrongly.

**What V1 deliberately leaves manual.** Promotion remains the single proven command `git push origin <accepted-candidate-sha>:refs/heads/main`, run after Acceptance has earned that exact SHA. Whether automating one command buys anything is a separate question for a separate contract, and nothing here assumes it does. Standalone `Agent Control` on preflight is not an admission signal and is not consulted: after an expected-value lease replaces a rejected candidate, `github.event.before` can name the displaced object and the run fails with `INVALID_GIT_REF`, which is expected and must be neither suppressed nor repaired.
