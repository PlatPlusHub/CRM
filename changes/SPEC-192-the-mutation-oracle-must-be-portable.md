# Change Request — SPEC-192

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make Check 12's mutation oracle portable by discriminating the repair with a non-hidden, git-ignored generated-cache fixture that both the pre-repair and post-repair populations resolve identically on Windows and Linux, and prove that portability locally rather than discovering it in remote CI.

## Business Reason

SPEC-191's production repair was correct and is retained. Its *test oracle* was not portable, and remote CI proved it: candidate `97b049bacbfaf71d670cf1c6181dd4ba4ac6da3f` was rejected with `Repository Consistency` and `ORVION Acceptance` each failing on one and the same assertion — `MUTATION: reverting the population REINTRODUCES the pgdelta false positive`, `15 passed, 1 FAILED` — while `Agent Control` succeeded and every other assertion passed.

The cause is measured, not inferred. `$allFiles` enumerates with `Get-ChildItem -Recurse -File` and no `-Force`. A dot-prefixed directory is an ordinary directory on Windows but *is* the hidden marker on Unix, so the pre-repair population sees `supabase/.temp/pgdelta` on Windows and cannot see it on Linux. A mutant that reverts to that population therefore cannot resurrect the defect on Linux, and an assertion demanding that it does is unsatisfiable there. Proven side by side in disposable sandboxes with one identical script: the dot-prefixed fixture is `VISIBLE` on Windows and `hidden` on Linux, while a non-hidden ignored fixture is `VISIBLE` on both and excluded from the Git population on both.

A corollary worth stating: **AUD-01c is Windows-specific.** On Linux, Check 12 never enumerated that cache at all. The defect and the blocked certification remain entirely real on the Windows workstation where `-Finish` and LOCAL certification run, which is why the production repair stays earned and is not reverted here.

## Risks

- **The main risk is weakening the production invariant to satisfy a test, and this contract forbids exactly that.** `-Force` is NOT added to `$allFiles`: that collection is shared with Check 1's filename index and widening it has earned nothing. No pathname exception, no `pgdelta`/`.temp`/Supabase rule, and no change to the UTC+14 ceiling, the date pattern or the invariant-culture parsing.
- **A mutation assertion over an invisible fixture is invalid evidence, and that is the precise failure being repaired.** The corrected suite therefore proves, as a precondition, that the pre-repair population can actually see the fixture before it claims the mutant failed to flag it. Without that precondition a future platform change would reproduce this same silent-oracle class.
- **Midnight-boundary flakiness.** The generated-cache fixture's date is the independently computed UTC+14 edge **plus thirty days**, computed at run time and never written literally anywhere, so no CI run can straddle the ceiling. The literal value is deliberately absent from this contract: Check 12 flagged an earlier draft of this very sentence for quoting it, which is the same self-inflicted case its own comment records.
- **Range coverage is the other way this could fail.** The candidate range already contains SPEC-191's four commits, and the range-integrity mechanism judges every commit in it against the governing contract's Write Scope. That Write Scope is therefore derived mechanically from `git diff --name-only origin/main..HEAD` plus this contract's own writes, not from the files this contract happens to edit. This is the SPEC-190 range mistake, avoided deliberately.
- Not repairing leaves the repository unable to publish the Check-12 fix at all, and therefore still unable to certify any Batch-6 database slice.

## Supersedes / Depends On

Supersedes `changes/SPEC-191-check-12-measures-repository-evidence-not-generated-cache.md`, which is **Cancelled** (owner-authorized, 2026-09-17) because remote CI falsified its frozen Implementation Step 2. SPEC-191's production repair — the Git repository-candidate population, the unchanged `$allFiles`, the unchanged UTC+14 ceiling and invariant-culture parsing, and the AUD-01c register entry — is **retained** and inherited by this contract wherever it was independently proven; only the cross-platform mutation oracle is corrected.

## Write Scope

- `changes/SPEC-192-the-mutation-oracle-must-be-portable.md`
- `changes/SPEC-191-check-12-measures-repository-evidence-not-generated-cache.md`
- `scripts/test_future_date_guard.ps1`
- `scripts/check_repository_consistency.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-190-a-membership-change-costs-the-same-through-every-door.md`
- `.gitignore`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/check_primary_ledger.ps1`
- `scripts/publish_candidate.ps1`
- `package.json`
- `package-lock.json`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`

## Required Reading

- `changes/SPEC-191-check-12-measures-repository-evidence-not-generated-cache.md` — the cancelled predecessor, its Execution Log and its Verification Notes
- `scripts/test_future_date_guard.ps1` — the `AUD-01c` section and `New-GitSandbox`
- `scripts/check_repository_consistency.ps1` — Check 12's population and its refusal of an exemption list
- `reports/master/MASTER_GAP_REGISTER.md` — AUD-01, AUD-01a, AUD-01c
- `AGENTS.md §6` — attack every detector in both directions
- `CR_LIFECYCLE.md §8` — evidence classes, frozen authority, the certification receipt

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github
- docker

## Additional Verification

- `pwsh -NoProfile -File scripts/test_future_date_guard.ps1`
- `docker run --rm -v "${PWD}:/repo:ro" mcr.microsoft.com/powershell@sha256:810c4f1e0c9d23022c3ec18c50a6205ee4b60766f1739d329b2948df1fd7d5b0 bash -lc "set -e; apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq git >/dev/null 2>&1; mkdir -p /work; tar -C /repo --exclude=./node_modules --exclude=./.git -cf - . | tar -C /work -xf -; cd /work; git config --global user.email ci@t.test; git config --global user.name ci; pwsh -NoProfile -File scripts/test_future_date_guard.ps1"`
- `pwsh -NoProfile -File scripts/check_repository_consistency.ps1`

## Implementation Steps

1. **Check:** `scripts/test_future_date_guard.ps1` contains the string `ORACLE PRECONDITION`. If present, record Already Applied. Otherwise amend ONLY the `AUD-01c` section (everything from the line `Write-Host "== AUD-01c:` up to but excluding the final `Write-Host ""` that precedes the pass/fail summary), leaving assertions 1–9, `Invoke-Guard`, `Future-Hits`, `$edge`, `$inv` and `Iso` untouched, so that:
   - `New-GitSandbox` additionally creates a **non-hidden** git-ignored generated-cache fixture: a directory whose name does not begin with `.` and which carries no hidden filesystem attribute, added to the sandbox `.gitignore` as its own rule, containing one `.sql` file whose body is a partition-bound line carrying the date `Iso $edge.AddDays(30)`;
   - the existing dot-prefixed `supabase/.temp/pgdelta/` fixture is RETAINED as a realistic control and its probe date also becomes `Iso $edge.AddDays(30)`;
   - a new assertion headed `ORACLE PRECONDITION` computes the pre-repair population in the harness exactly as the guard does — `Get-ChildItem -Path <sandbox> -Recurse -File` filtered by `$_.FullName -notmatch '[\\/](node_modules|backup|\.git)[\\/]'` and by the four judged extensions — and asserts that the non-hidden generated-cache fixture IS a member of it, so no mutation claim can be made over a fixture the population cannot see;
   - the repaired-guard assertions become: tracked authored future evidence FLAGGED; untracked non-ignored authored future evidence FLAGGED; the **non-hidden** ignored generated-cache fixture NOT FLAGGED; the dot-prefixed pgdelta fixture NOT FLAGGED; and the tracked-before-ignore boundary fixture FLAGGED;
   - the mutation keys on the **non-hidden** generated-cache fixture and asserts it IS flagged by the reverted-population mutant, while a genuine tracked authored future-dated file remains flagged; the dot-prefixed fixture is never the mutation discriminator.
   Each assertion must name its own probe file so one probe's finding cannot satisfy another's assertion, and the section must continue to prove the guard reached Check 12 before trusting any result.

2. **Check:** `scripts/check_repository_consistency.ps1` contains the string `SPEC-192`. If present, record Already Applied. Otherwise change the attribution in Check 12's `AUD-01c` comment header only, from `SPEC-191` to `SPEC-192`, and add one sentence recording that SPEC-191 was cancelled after remote CI falsified its mutation oracle while this production population repair was retained unchanged. Change no code line, no other comment, and no other check.

3. **Check:** `reports/master/MASTER_GAP_REGISTER.md`'s `AUD-01c` row contains the string `SPEC-192`. If present, record Already Applied. Otherwise amend that row's disposition cell so the repair is attributed to SPEC-192 with SPEC-191 named as the cancelled predecessor, and add one sentence recording the measured platform split: the pre-repair population sees a dot-prefixed path on Windows and not on Linux, so AUD-01c manifests on the Windows workstation where LOCAL certification runs and not in Linux CI, and the mutation oracle is therefore keyed on a non-hidden ignored fixture. Write no literal future date in that prose. Change no other row, and update the file's `Last updated:` header to carry the newer date with the previous entry demoted to `Previously:` if Check 21 requires it.

4. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` are equal by value to `_ORVION_CANONICAL/manifest.md`'s. If they already agree, record Already Applied. Otherwise regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and re-check. Run this regeneration after EVERY commit in this Change Request's lifecycle that changes the manifest, including the `Approve` and `Complete` transitions. The manifest's `Active Change Request` and `Last Completed` values are set by those lifecycle transitions per `CR_LIFECYCLE.md §9` and are not edited by this step; `Next capability` must still name Batch 6 Slice 12 when this Change Request closes.

## Acceptance Criteria

- [ ] `scripts/test_future_date_guard.ps1` creates a non-hidden, git-ignored generated-cache fixture whose directory name does not begin with `.`, ignored by its own rule in the sandbox `.gitignore`.
- [ ] That fixture's date is the independently computed UTC+14 edge plus thirty days, and the dot-prefixed pgdelta fixture carries the same date.
- [ ] The suite contains an `ORACLE PRECONDITION` assertion proving the pre-repair on-disk population enumerates the non-hidden generated-cache fixture, evaluated before any mutation claim.
- [ ] Against the repaired guard the suite asserts: tracked future evidence FLAGGED, untracked non-ignored future evidence FLAGGED, non-hidden ignored generated-cache NOT FLAGGED, pgdelta cache NOT FLAGGED, tracked-before-ignore boundary FLAGGED.
- [ ] The mutation asserts the **non-hidden** generated-cache fixture IS flagged by the reverted-population mutant and that genuine tracked evidence remains flagged; the dot-prefixed fixture is not the mutation discriminator.
- [ ] `scripts/test_future_date_guard.ps1` reports 0 failed on Windows, and 0 failed under Linux PowerShell via the container command in Additional Verification.
- [ ] Assertions 1–9 of `scripts/test_future_date_guard.ps1` and its `Invoke-Guard` helper are unchanged from their state at the start of this Change Request.
- [ ] `scripts/check_repository_consistency.ps1` has no `-Force` on `$allFiles`, no pathname/`pgdelta`/`.temp`/Supabase exception in any code line, and its `$dateRx`, UTC+14 ceiling, invariant-culture parsing and clock-sanity block are unchanged from their state at the start of this Change Request.
- [ ] Check 12's `AUD-01c` comment attributes the repair to SPEC-192 and records SPEC-191's cancellation.
- [ ] `reports/master/MASTER_GAP_REGISTER.md`'s `AUD-01c` row attributes the repair to SPEC-192, names SPEC-191 as the cancelled predecessor, and records the measured platform split.
- [ ] `changes/SPEC-191-check-12-measures-repository-evidence-not-generated-cache.md` is byte-identical to its state at the `SPEC-191: Cancel (human command)` commit, and its Status is still `Cancelled`.
- [ ] `changes/SPEC-190-a-membership-change-costs-the-same-through-every-door.md` is neither created, modified nor deleted by this Change Request.
- [ ] `_ORVION_CANONICAL/manifest.md`'s `Next capability` still names Batch 6 Slice 12, and `ai-map.json`'s live_state copies of `Last Completed`, `Active Change Request` and `Next capability` match the manifest by value.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.
Leave this section's bracketed instructions in place in an unused template; remove them
only in a CR that has at least one real entry.]

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

**Why `changes/SPEC-191-…md` appears in Write Scope.** It is there for RANGE COVERAGE ONLY. The candidate range still contains SPEC-191's four commits, and the range-integrity mechanism judges every commit in the range against the governing contract's Write Scope — that is exactly how the earlier SPEC-190 Draft commit was caught as `OUT_OF_SCOPE_WRITE` before publication. SPEC-191 is terminal and `CR_LIFECYCLE.md §4` forbids modifying it, so this contract must not touch it; an Acceptance Criterion asserts it stays byte-identical to its state at the cancellation commit. The full Write Scope was derived mechanically from `git diff --name-only origin/main..HEAD` — `_ORVION_CANONICAL/manifest.md`, `ai-map.json`, `changes/SPEC-191-…md`, `reports/master/MASTER_GAP_REGISTER.md`, `scripts/check_repository_consistency.ps1`, `scripts/test_future_date_guard.ps1` — plus this contract's own file, and confirmed per commit so a net diff could not hide a path.

**The supersession pointer is deliberately one-directional, and the repository has already paid for the alternative.** `changes/TEMPLATE.md` says a superseded file's Status must be set to Cancelled *"with a note pointing to the new file"*. Verified against the exact committed bytes at `904a987`: SPEC-191 **does not name SPEC-192 anywhere**. It cannot be given that note now — it is terminal, and `CR_LIFECYCLE.md §4` states the Gate rejects later modification of a closed contract. It is also the outcome the repository should prefer, which is not a convenient reading but a recorded lesson: `SPEC-188`'s own Supersedes section states that *"Naming the intended successor inside `SPEC-186`'s cancellation permanently retired `SPEC-187` under the collision rule"* — any tracked textual occurrence reserves an identifier, so writing a successor's number into a predecessor's cancellation burns that number whether or not it is ever used. SPEC-191 was cancelled on owner authority before this contract's identity was allocated from the live repository, so the note could only have been written by guessing a number in advance, which is exactly what retired SPEC-187.

What the template's clause actually protects is stated in the same sentence — *"never leave two files describing overlapping work both marked Draft or Approved"* — and that is satisfied: SPEC-191 is `Cancelled`, this contract is the only live one, and the Review Gate item asks only that the named file's *Status* has been updated accordingly, which it has. The relationship is therefore declared **forward only**, from this contract, which is where it can be stated truthfully without editing history. No lifecycle rule is invented and neither contract's committed bytes are altered.

**Why a Linux run is Additional Verification and not a hope.** The class that escaped was "local green, remote red", and the only Linux oracle at the time was CI itself — which `CR_LIFECYCLE.md §8` correctly forbids making a completion checkbox. Running the same suite under Linux PowerShell in a container is LOCAL evidence, executable by `-Finish`, and it was proven to reproduce the exact remote failure before this contract was written: `15 passed, 1 FAILED` on the identical assertion. After the repair it must report 0 failed. That converts the platform split from something CI discovers into something certification proves.

**The container is pinned by DIGEST, not by a tag.** `mcr.microsoft.com/powershell:latest` resolved to `sha256:810c4f1e…d5b0`, an image built 2024-04-10 carrying pwsh 7.4.2 — a tag that can move under a mandatory obligation is the `SPEC-173` hazard the acceptance workflow already pins an Action by full commit SHA to avoid (*"a tag can be moved"*). The digest-pinned command was re-run and reproduced the identical failure, so the pin is proven rather than assumed. Its residual dependencies are stated rather than hidden: it needs Docker, which this contract declares as a `LOCAL_PROBE` capability so `-Finish` refuses with a named `MISSING_REQUIRED_CAPABILITY` rather than silently skipping; and it needs one registry pull plus one `apt-get` for `git`, which on failure produces a loud `ADDITIONAL_VERIFICATION_FAILED` and never a false green. Every failure mode therefore fails closed and is attributable, which is the property a mandatory obligation needs.

**Why `-Force` is refused.** Adding `-Force` to `$allFiles` would make the dot-prefixed fixture visible on Linux and would "fix" the mutation assertion without changing anything the production repair is for. It would also silently widen Check 1's filename index and every other consumer of that collection, which has earned nothing. The fixture is changed instead of the production population, because the defect is in the oracle.

**The platform-population observation, recorded and deliberately NOT repaired.** `$allFiles` enumerates a different file set on Windows and Unix for dot-hidden paths, so in principle any check consuming it can reach a platform-dependent verdict — the AUD-01a class, moved from the clock into the population. No concrete false-green or false-red outside Check 12 has been reproduced, so this contract does not normalize filesystem enumeration repository-wide. It is recorded here so the next person meets it with evidence rather than rediscovering it.
