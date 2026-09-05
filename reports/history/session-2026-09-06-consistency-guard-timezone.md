# ORVION — the consistency guard was measuring a timezone

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-06
Author: Claude Opus 5
Status: **COMPLETE — one guard fix (`scripts/check_repository_consistency.ps1`, Check 12), one new guard-of-the-guard suite, one CI step. No migration, no schema change, no database touched. `AUD-01a`.**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED, verified before touching anything.** HEAD `755642f` = `origin/main` (0 / 0), clean tree, 202 migrations, 103 test files. The reported symptom was "Repository Consistency failed again on main at commit `755642f`". The guard was run **locally against that exact commit first, with the in-progress slice-4 work stashed**, and printed `REPOSITORY CONSISTENCY: CLEAN`. So the first established fact was that the failure was not reproducible where the work happens — which is the finding, not an obstacle to it.
- **PROVEN (behavioural evidence, this session):** CI run `33998010475` failed with **22 issues, every one of them `FUTURE-DATED ... -> 2026-09-06 (today is 2026-09-05)`**, on a commit pushed `2026-09-05T23:11Z`. Checks 1–11 and 13–24 passed on that run. After the fix: guard **CLEAN 1–24** locally, `scripts/test_future_date_guard.ps1` **5 passed / 0 failed**, `test_status_contradiction_guard.ps1` **25 / 0**, `test_primary_ledger_guard.ps1` **13 / 0**. The new suite was **defect-injected**: reverting the single line to `(Get-Date).Date` made it fail.
- **UNPROVEN, and not claimed:** the post-fix guard has been run in **Africa/Cairo only**. That it is now timezone-independent is proven by construction (the ceiling reads `UtcNow`) and by a structural assertion, **not** by a green UTC run — the CI run on this commit is that evidence and it is the reason this was pushed rather than declared. No claim is made that Check 12 has no other environmental dependency; only this one was measured.
- **CHANGED:** `scripts/check_repository_consistency.ps1` (Check 12's ceiling + its header + its failure message); `scripts/test_future_date_guard.ps1` (new); `.github/workflows/repository-consistency.yml` (runs the three guard suites; three new trigger paths); `MASTER_GAP_REGISTER.md` (`AUD-01a` + header). **The manifest is deliberately untouched** — it owns current state, and no migration count, test count, phase or decision moved.
- **REMAINING:** **MAIL-1**, **FA-2**, **MONEY-2** — all untouched. Batch 6 stands at **4 of 77**; slice 4 (`booking_item_passengers`) was **in progress when this interrupted it** and its work was stashed, not abandoned.
- **DO NOT TOUCH:** do not "tighten" Check 12 back toward the author's local day — that is the regression, and `test_future_date_guard.ps1` assertion 5 exists to catch it. Do not restamp the 22 documents CI complained about: they were correct, and dating them 2026-09-05 would make them wrong and would recur tomorrow. Do not merge the guard-of-the-guard step into the guard step; the gate and its calibration fail for different reasons and should be readable apart.
- **NEXT:** resume Batch 6 slice 4 on `booking_item_passengers` from the stash.

---

## 1. WHAT WAS ACTUALLY WRONG

`AUD-01` (2026-08-29) created Check 12 after an entire reconciliation was stamped one day ahead across 13 files. Its rule: fail on any date "later than today". Its implementation:

```powershell
$today = (Get-Date).Date
```

`Get-Date` returns the **runner's local civil date**. ORVION is written from Africa/Cairo, UTC+2/+3. GitHub Actions runs in UTC. So for the two-to-three hours each night between Cairo's midnight and UTC's, the guard gave two different verdicts on one commit — and did so at the hour when a long session is most likely to finish and push.

Slice 3 is what walked into it. It was pushed at `2026-09-05T23:11Z`; where it was written it was already `2026-09-06`, and it stamped its documents `2026-09-06`, which was true. The runner's clock said `2026-09-05` and reported 22 future-dated defects. **None of the 22 was a defect.** The substantive checks all passed on that same run.

**The failure was in the detector, not in the documents**, and the tell was available before any file was opened: the same commit, unchanged, was CLEAN on one machine and red on another. A guard whose verdict depends on where it runs is not measuring the repository.

## 2. WHY THE OBVIOUS FIX IS THE WRONG ONE

Restamping the 22 places back to `2026-09-05` would make CI green. It would also be a lie — the evidence really was gathered on the 6th — and it would recur the next night anyone worked late. **It fixes the report and leaves the instrument broken**, which is the shape this repository has a name for.

## 3. THE FIX, AND THE FIX WAS ATTACKED BEFORE IT WAS TRUSTED

```powershell
$today = [datetimeoffset]::UtcNow.AddHours(14).Date
```

UTC+14 (Pacific/Kiritimati) is the maximum civil offset in the IANA database, so this is the newest civil date that exists **anywhere on Earth** at the instant of the run. The invariant `AUD-01` wrote is unchanged and still gates CI: *a record dated tomorrow claims evidence that could not yet have been gathered.* A date that has not begun in UTC+14 has not begun for any author anywhere.

**Its ceiling, stated rather than implied (MEAS-1).** The accepted window is now up to 14 hours wider than the author's own civil day. A stamp a few hours into the author's tomorrow will pass. That is the price of a verdict that does not move with the runner, and it is the right trade against a false failure that fires nightly.

**What was rejected.** Comparing against `[datetime]::UtcNow.Date` — that only moves the arbitrary reference point from Cairo to UTC and makes the guard wrong for every author *east* of UTC instead of consistent for all of them. Adding an exemption list — `AUD-01`'s own row forbids it in terms: "every exemption is a place the next future date can hide". Relaxing the check to a warning — that is suppression.

## 4. TESTING THE TEST

`scripts/test_future_date_guard.ps1`, in the shape the two existing guard suites established: a sandbox, invoked through the guard's own `-RepoRoot`, asserting only on Check 12's lines. Five assertions — at the edge (must not flag), one day past it (must flag), a month past it (must flag), yesterday (must not flag), and a structural one that the ceiling is not derived from local time.

**The first draft of this suite was wrong, and the failure is worth recording.** With only a probe file in the sandbox, the guard aborts at Check 3 — `MISSING ROUTER: AGENTS.md does not exist`, under `$ErrorActionPreference = 'Stop'` — and never reaches Check 12 at all. Both must-flag assertions "passed" against a guard that had not run. Check 2's harness gets away with a partial copy only because Check 2 runs *before* that abort; Check 12 runs after it. The sandbox is now a full copy of the repository, and the runner throws outright if the output does not contain Check 12's own banner, so this cannot recur silently.

**Defect injection (PAR-4).** Reverting the one line to `(Get-Date).Date` made the suite fail. It was caught by the **structural** assertion alone — at the hour of the test, Cairo's local date and the UTC+14 date were the same, so the behavioural assertions could not discriminate. That is exactly the ceiling assertion 5 is declared to cover, and it earned its place on its first run.

## 5. THE SECOND HALF: NOTHING RAN THE GUARD TESTS

Three guard-of-the-guard suites existed. **CI ran none of them.** A regression inside a detector was therefore invisible until it produced a false verdict in front of someone — which is precisely how this defect surfaced. The workflow now runs all three after the guard itself, and lists them in its trigger paths.

This is the **second** time this workflow has been red for a reason that was not a consistency defect; `fetch-depth: 1` starved Check 19 of the history it attributes against, for 13 consecutive runs. Both share one shape, and it is the reusable lesson here: **a guard that reads its environment rather than the repository will disagree with itself across environments.**

## 6. VERIFICATION

| Evidence | Class | Result |
|---|---|---|
| Guard at `755642f`, slice-4 work stashed | LOCAL RUNTIME | `REPOSITORY CONSISTENCY: CLEAN` — the failure was never local |
| CI run `33998010475` | HISTORICAL | 22 issues, all `FUTURE-DATED`, all false |
| Guard after fix, Checks 1–24 | LOCAL RUNTIME | `REPOSITORY CONSISTENCY: CLEAN` |
| `test_future_date_guard.ps1` | LOCAL RUNTIME | 5 passed / 0 failed |
| ...with the fix reverted | LOCAL RUNTIME | 4 passed / **1 FAILED** — the suite can fail |
| `test_status_contradiction_guard.ps1` | LOCAL RUNTIME | 25 passed / 0 failed |
| `test_primary_ledger_guard.ps1` | LOCAL RUNTIME | 13 passed / 0 failed |
| Database, migrations, tests, Primary | — | **not touched, and not claimed** |

## 7. NEXT

Resume **Batch 6 slice 4** on `booking_item_passengers` from the stash. The slice's own findings are not in this report; they belong to its own.

End of report.
