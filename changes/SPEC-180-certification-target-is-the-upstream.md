# Change Request — SPEC-180

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Derive the certification target branch from the current branch's upstream — the authority `CR_LIFECYCLE.md` §9 already names for publication — instead of from the name of the branch the agent happens to be standing on.

## Business Reason

`Target-Branch` returns `git rev-parse --abbrev-ref HEAD`, and `-Finish` stamps that string into the certification receipt as `target`. `-Certify` then reads it and queries `gh run list --commit <sha> --branch <target> --event push`, refusing to re-derive it because, in the function's own words, "guessing the branch is the whole defect".

`SPEC-173` states the invariant certification must prove as `exact artifact SHA + exact intended branch/ref + exact event + expected workflow identity + target ref still pointing at that SHA`. The current branch is where the agent is standing, not the *intended* branch. The two coincide only when work is performed on a local branch named `main`, so the implementation has been correct by coincidence rather than by construction. `SPEC-173`'s own contract is not violated — its Implementation Step 1 asks only that the target be "derived from Git" in exactly one place, and it is — which is why the gap survived review.

Measured live rather than inferred. A contract executed on an isolated branch tracking `origin/main`, published by explicit refspec to `orvion-preflight` and then to `main`, produced every green run the receipt's own expected set required — `Agent Control` and `Repository Consistency`, both `success` on `main` at the exact promoted SHA. `-Certify` nevertheless reported `REMOTE_CERTIFY: PENDING`, because the receipt recorded the working branch name and no run has ever existed on it. The failure is silent until after publication, at which point the contract is terminal and the receipt cannot legally be rewritten: re-running `-Finish` from a clean `main` checkout enters `PLAN` mode, because the contract is `Complete` there and no governing contract exists to certify.

The authority to use is already present and already mandatory, so nothing new is introduced. `Git-State` resolves `@{u}` and throws `GIT_UPSTREAM_MISSING` when it cannot, on the same run and before any receipt is written; `CR_LIFECYCLE.md` §9 defines publication as `git push` with `git rev-list @{u}..HEAD` empty. Both shapes were measured:

```text
                       branch                   @{u}          @{push}                    bare push --dry-run
primary checkout       main                     origin/main   origin/main                main -> main
isolated worktree      spec179-cert-lifecycle   origin/main   FATAL: cannot resolve      refuses; advises `git push origin HEAD:main`
```

`@{push}` is rejected on evidence, not on taste: under this repository's actual configuration it cannot be resolved at all in the shape that motivates the repair, so it would make certification unobtainable for a second reason. `@{u}` answers identically and correctly in both shapes. On a local `main` the derived value is `main`, exactly what is derived today.

A second finding explains why this survived: the reader is heavily proven and the writer is not proven at all. Assertions 144 through 149 cover preflight-versus-promotion isolation, wrong branch, wrong event, a missing target and a target ref that has moved — every one of them by injecting a hand-written receipt through `ExpectBoth`. `Target-Branch` is named by zero tests. This Change Request adds the missing writer-side coverage and nothing else.

## Risks

Low, and the behaviour change is confined to one derivation.

- On any branch whose name equals its upstream branch — every historical execution in this repository — the derived value is unchanged, so the established path cannot regress. The control case below pins that.
- The value is read from the upstream's configured merge ref and the `refs/heads/` prefix removed, rather than by splitting `origin/main` at a slash, so a branch name containing `/` cannot be truncated.
- Fail-closed behaviour is inherited rather than rewritten. An unresolvable upstream already stops the run at `GIT_UPSTREAM_MISSING` before a receipt is written, and an empty target is already refused by `-Certify`. No new error vocabulary is introduced and no fallback is added — guessing `main`, guessing the current branch, or inferring the target from runs observed after publication are each the defect in another form.
- The reader's protections are untouched. Exact SHA, exact branch, `push` event, expected workflow identity, missing-workflow failure and target-ref-moved failure all keep their current semantics; only the value the writer records changes.
- This does not make isolated execution a supported path in the authorities, and it does not claim to. It makes the recorded target truthful wherever execution happens.

## Supersedes / Depends On

None. `SPEC-173` introduced the target field and remains correct; this Change Request corrects only the fact that populates it.

## Write Scope

- `changes/SPEC-180-certification-target-is-the-upstream.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `scripts/generate-ai-map.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_future_date_guard.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `.githooks/pre-commit`
- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `CODING_STANDARDS.md`
- `changes/TEMPLATE.md`
- `supabase/migrations`
- `reports/history`

## Required Reading

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `changes/SPEC-173-certified-evidence-names-its-context.md`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Implementation Steps

1. Verification check: `Target-Branch` in `scripts/check_agent_continuity.ps1` no longer contains `--abbrev-ref HEAD`. If it matches, record Already Applied and skip. Otherwise change `Target-Branch` only, so that it derives the branch name from the current branch's UPSTREAM rather than from `HEAD`: read the upstream's configured merge ref for the current branch and return that ref with a leading `refs/heads/` removed, returning an empty string when the upstream cannot be resolved. Do not split the `origin/main` short form on a separator. Add no fallback to `main`, to the current branch, or to any value inferred from remote runs. Introduce no new function, file, module, parameter or error code. Leave every caller unchanged: `Write-Certification` still passes the single derived value to `Workflow-Expectations` and still persists it in the receipt, and `Certify-Remote` still reads it from the receipt and still fails closed when it is empty.

2. Verification check: `scripts/check_agent_continuity.ps1` contains a comment beside `Target-Branch` naming the upstream as the publication authority. If it matches, record Already Applied and skip. Otherwise add a comment beside `Target-Branch` stating that the promotion target is the branch this one publishes to, not the branch the agent is standing on; that the upstream is the authority `CR_LIFECYCLE.md` §9 already uses for publication and `Git-State` already requires; that `@{push}` was rejected because it cannot be resolved under this repository's configuration when the working branch name differs from its upstream; and that an unresolvable upstream is already stopped by `GIT_UPSTREAM_MISSING` before a receipt is written.

3. Verification check: `scripts/test_agent_continuity.ps1` contains the string `publishes to, not the branch`. If it matches, record Already Applied and skip. Otherwise add exactly three behavioural cases using the existing fixture harness and adding no new harness function. The MUST-ACCEPT case places the fixture on a branch whose name is NOT `main` and whose upstream is `origin/main`, runs `-Finish`, and asserts the resulting receipt records the target `main`. The CONTROL case leaves the fixture on `main` with the same upstream, runs `-Finish`, and asserts the receipt still records `main`, so the established path is pinned against regression. The SLASH case gives the fixture an upstream whose branch name contains `/` — a remote branch `release/foo`, so the upstream merge ref is `refs/heads/release/foo` — runs `-Finish`, and asserts the receipt records `release/foo` whole rather than a truncated `foo`. Every case must assert on the target recorded in the receipt by a real `-Finish`, so that the production path `Write-Certification` -> `Target-Branch` -> receipt is what is exercised; a test that parses Git configuration itself and asserts its own result proves nothing about the writer and is forbidden. Delete no existing assertion, change no existing assertion's number, name or condition, and weaken no existing negative case; add no further fail-closed case, because an unresolvable upstream is already covered by the existing `GIT_UPSTREAM_MISSING` case and an empty target by assertion 148.

## Acceptance Criteria

- [ ] `Target-Branch` derives the certification target from the current branch's upstream and contains no `--abbrev-ref HEAD`.
- [ ] An upstream branch name containing `/` is recorded whole in the certification receipt: an upstream of `refs/heads/release/foo` produces the target `release/foo`, never `foo`.
- [ ] `Target-Branch` returns an empty string when the upstream cannot be resolved, and no fallback to `main`, to the current branch, or to observed remote runs was added.
- [ ] No new function, file, module, parameter or error code was introduced, and the target still has exactly one derivation consumed by `Workflow-Expectations` and persisted by `Write-Certification`.
- [ ] `Certify-Remote` still reads the target from the receipt, still fails closed on an empty one, and its SHA, branch, event, expected-workflow and target-ref-moved checks are unchanged.
- [ ] `scripts/test_agent_continuity.ps1` proves that a branch not named `main` whose upstream is `origin/main` produces a receipt recording `main`.
- [ ] `scripts/test_agent_continuity.ps1` proves that executing on `main` still produces a receipt recording `main`.
- [ ] Assertions 144 through 149 are unchanged and still pass, and no assertion was deleted, renumbered or weakened.
- [ ] No file outside Write Scope was created, modified or deleted, and no new test file exists.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

This Change Request can certify itself from an isolated branch, and that was checked rather than assumed: `-Finish` executes the working tree's copy of the control script, so the corrected derivation is already in effect when the receipt is minted. No bootstrap ordering is required and local `main` does not have to be freed first.

Scope deliberately NOT taken. The measured `git push --dry-run` behaviour shows that a bare `git push` REFUSES on a branch whose name differs from its upstream, and names the explicit refspec as the remedy. Publication from such a branch therefore requires an explicit refspec rather than the bare `git push` that `CR_LIFECYCLE.md` §9 describes. That is a question about whether isolated execution should become a documented supported path, with its own publication procedure — a governance decision, not a certification defect — and `CR_LIFECYCLE.md` is deliberately left out of Write Scope because its §9 text remains true exactly as written.

The writer/reader asymmetry this repair closes is recorded as an observation and not generalized here. Six assertions prove what `-Certify` does with a target and none proved where the target came from, which is the same shape as a guard whose input is never attacked. Whether that asymmetry exists elsewhere in the control plane is a separate question and is not investigated by this contract.
