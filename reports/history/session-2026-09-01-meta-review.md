# ORVION — META-1: The Guards Were Treated As Hypotheses, And Five Facts Had No Owner

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Scope: Meta-review of the exploration/audit/repair process itself. A 14-mutation battery against the
repository guard; a vacuity attack on the newest security test; two derived checks added
(**Check 15**, **Check L5**) and mutation-tested. No migration; the database was not modified.
Status: Complete.

**Branch:** `main` · **Start HEAD:** `ca37e80` · **Environment:** repository = local = Primary at 181.

---

## 1. TRUTH RE-ESTABLISHED FIRST

Measured, not carried forward: HEAD `ca37e80`, tree clean and pushed · **181** migration files,
latest `202607059200` · **86** test files · **15** guard checks (14 before this pass) · local ledger
`181|67a9e05e43c733594a76dd7e6ce6da31` · Primary ledger **identical**. No discrepancy, so the normal
workflow continued.

## 2. THE BATTERY — nine caught, five missed

Fourteen realistic mutations, each proven to change the semantic state, each followed by a guard run
and a restore. The harness itself needed one correction first: its reason-extraction matched a
section header, so every catch reported "Check 1". The **verdicts** were sound but the **attribution**
was not, and a mutation report that misnames the guard is worse than none.

**CAUGHT (9)** — migration count and ledger fingerprint (Check 9) · broken reference (1) · stale
latest-report pointer (10) · phase disagreement (6) · escaped register row (13) · a decided id put
back on the open list (14) · a falsified next step and a future date, both via ai-map freshness (7).

**MISSED (5)** — and they were one coherent blind spot: **the manifest publishes current-state
FIGURES that nothing owned.** Suite counts, HTTP total, client-RPC count, table count, and the
serious one:

> **The structural-surface hash could be corrupted to all zeros and BOTH guards stayed CLEAN.**

The repository guard opens no database; the parity guard never read the manifest. That is precisely
the document a cold-start session reads to answer *"is Primary synchronized?"* — so the one number
most likely to be trusted was the one nothing verified.

## 3. FIXED — two derived checks, no hand-maintained lists

**Check 15** (repository guard) compares the manifest's suite figures against the test files
themselves — every file carries a literal `select plan(N)`, and 86 files sum to 1156, matching the
pgTAP run exactly — and its client-RPC count against the **generated** API contract, which Check L3
already regenerates and diffs against the live database. So the manifest is compared to the
repository, and the contract to the database.

**Check L5** (parity guard) compares the manifest's published **function** and **structural** hashes
against the live database. Deliberately against LOCAL, never against the caller-supplied Primary
values: laundering a supplied value into a published fact is exactly **GUARD-1**.

**Two misses left unmechanised, with reasons rather than silence:**

- the **HTTP total** requires *running* the six suites — it is LOCAL RUNTIME evidence, and a
  file-only guard must not claim it (`AGENTS.md §5a`'s evidence classes);
- **"75 tables"** is the smoke test's assertion, a different measurement from the contract's count of
  tenant-reachable tables. Comparing them would manufacture a false failure, which is worse than an
  unguarded number.

**Both new checks mutation-tested both directions.** And **Check 15 caught real, unplanted drift on
its first run**: the suite had grown to 1156 while the manifest still said 1154 — drift introduced by
this very session, found by the guard rather than by me.

## 4. VACUITY ATTACK — the newest security test is load-bearing

Test 85 asserts a trainee cannot rewrite `suppliers.credit_limit_amount`. Inspection cannot tell
whether that refusal comes from the trigger or from something incidental, so the guard was attacked:

```
A  guard present  -> REFUSED  "permission denied: one of ASSIGN_SUPPLIER is required"
B  trigger DROPPED -> UPDATE 1          <- the write succeeds, so the assertion is load-bearing
C  rolled back     -> REFUSED again
```

A second fact fell out of step B: after the write succeeded, reading the value back still failed with
`permission denied for table suppliers` — the SUP-1 column grant is an **independent** control, so
the write and read halves cannot mask each other.

Now permanent as a **PAR-4 pair** (test 85, assertions 15-16), matching tests 70/72/73/76. Suite
1154 → 1156.

## 5. CLEAN NEGATIVES — attacked and earned

- **SSOT ownership.** No two documents were found independently claiming the same mutable fact after
  COLD-1; the numeric duplication META-1 found is the same class, now guarded rather than merely
  repaired.
- **Historical immutability.** Every stale figure still present in the repository lives in
  `reports/history/**`, is dated, and carries its `Class: History` header. Check 4 enforces the
  header's presence. No history file is referenced by boot logic as live truth.
- **Generated artifacts.** ai-map (Check 7) and the API contract (Check L3) both fail when their
  source moves; verified by mutation this pass.
- **Next-step coherence.** The manifest, the plan and the roadmap now agree, and two of the three
  point rather than restate — the third (`MASTER_EXECUTION_PLAN.md` Batch 6) is the SSOT.

## 6. BLIND SPOTS RECORDED, NOT FIXED

- **HTTP assertion totals** are unguarded by design (evidence class). A future guard could parse the
  suites' `Check` calls, but that would count call sites rather than executions and would be a
  weaker claim than the number it replaced.
- **Check 12 vs Check 7 ordering.** The future-date mutation was reported by ai-map staleness before
  Check 12 ran. Both fire; the first reported is not always the most informative. Cosmetic, recorded.
- **Check 2's `OPEN` detection** requires a padded cell exactly `OPEN`; a status cell beginning
  "OPEN — …" is not matched. That is deliberate precision, and it is why SEC-1c's contradictory cell
  was found by reading rather than by the guard — the fix was to make status cells lead with their
  verdict (done in COLD-1).

## 7. VERIFICATION

pgTAP **Pass A = Pass B, 86 files / 1156 assertions** · HTTP **371/371** across six suites · smoke
`ALL CHECKS PASSED (75 tables …)` · parity **CLEAN**, all three Primary values read live · repository
guard **CLEAN at 15 checks** · repository = local = Primary at **181**, ledger
`67a9e05e43c733594a76dd7e6ce6da31`, functions `d9b0dd9cb6dfaa3ac2f38a9cc7601408` (247), structure
`71f87b282df0598ccc100e367e6f7e4c` (3,373).

## 8. NEXT STEP

**ATTR-2**, unchanged — the remaining `_by` actor columns, classified per column into caller identity ·
derived actor · business fact recorded on behalf of someone else · system actor · historical snapshot ·
unknown, with `payments.received_by` reproduced before anything is changed. Then the care/conversation
slice.
