# ORVION — RECOVER-1 Closure: the Primary Ledger Evidence Guard

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-03
Author: Claude Opus 5
Status: Complete. **RECOVER-1 CLOSED.** Repository-only — no migration, no schema change, no Primary write.

**Scope:** a dedicated closure package. Close RECOVER-1, build a guard that detects repository↔Primary drift without depending on a value someone remembered to paste, restore GitHub synchronization, synchronize canon. **No Batch-6 work, no table audit, no SUP-4 continuation, no RBAC redesign — and none was started.**

---

## A. INITIAL STATE (verified independently, not read from the previous report)

| Axis | Value |
|---|---|
| HEAD / branch | `b2210f7d1b768274a2fc75d6fc81df04d7bbab9d` / `main` |
| Working tree | clean |
| `origin/main` | `4b63f7…` → **4 commits behind** (`da799e3`, `77075f2` and both recovery commits unpushed) |
| Repository migrations | 189 (newest `202607060000_the_explainer_needs_a_door`) |
| Local ledger | 189, fingerprint `4029ecefa4bf40639b3bb61d63f986ef` |
| Primary ledger | 189, fingerprint `4029ecefa4bf40639b3bb61d63f986ef`, newest `202607060000` |

**Repository = Local = Primary — PROVEN.** All three fingerprints identical, Primary's read live via the `supabase-primary` MCP.
**Repository ≠ `origin/main` — 4 commits ahead.** The previous report said "3"; it was written before its own follow-up commit existed. Corrected here rather than left to stand.

---

## B. ROOT CAUSE — and the previous report's version of it was wrong

The first RECOVER-1 write-up implied the parity guard failed open. **It does not, and I reproduced that before building anything.** `check_database_parity.ps1` with no Primary values:

```
DATABASE PARITY: UNPROVEN -- local matches the repository, but PRIMARY WAS NOT CONTACTED.
  primary ledger : NOT CHECKED    ... This is NOT a pass.        exit code 2
```

So the guard was honest. The actual hole is narrower and worse:

**Nothing in the repository recorded whether Primary had ever been read at this HEAD.** Parity was asserted in a terminal, in a session, and then lost. A later session, a reviewer, or CI could not answer *"was Primary verified for this commit?"* from the repository at all — and an unanswerable question is indistinguishable from a satisfied one when nobody asks it.

Two aggravating facts made skipping easy: `check_database_parity.ps1` needs Docker and a live local stack, so it cannot run in the doc-only CI job or with the stack down — precisely the sessions that skipped it; and `check_repository_consistency.ps1`, the guard that *is* run on every commit and in CI, had never had an opinion about Primary.

---

## C. GUARD DESIGN

**Chosen: design B — durable, HEAD-attributed, fail-closed recorded evidence.** Design A (the guard opens its own read-only Primary connection) was evaluated **first** and is not available here:

- `.mcp.json` exposes `supabase-primary` as an HTTP MCP endpoint with **no reusable local secret** — reachable by the agent, not by a script;
- `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`, `PGPASSWORD` — all **ABSENT**;
- `supabase/.temp/` holds only `cli-latest`: the CLI is **not linked**, so `supabase migration list --linked` has nothing to authenticate with.

Giving the script a credential means committing one or planting one, which `AGENTS.md §6` forbids outright. **Faking a live read would be worse than admitting an evidence-based one**, so the guard names its class in its own output.

**Authoritative source:** `reports/evidence/primary-ledger-evidence.json` — Primary's **entire** `version_name` set, its fingerprint, project ref, read timestamp, the exact read query, and the commit it was read at.

**Provenance, and why this is not GUARD-1 in disguise:** `migration_count` and `ledger_fingerprint` were produced **by Primary**, over Primary's rows. The ledger array was then *proven* to hash to that fingerprint. That is verification against an independent authority, not derivation of a Primary value from the repository.

**Four properties that make a pasted number worthless:**

1. **Whole ledger, not a count** — a same-count/different-identity swap fails where a count comparison passes.
2. **Self-recomputing** — `migration_count` and `ledger_fingerprint` are recalculated from the ledger array, so editing a number without forging all 189 entries is detected.
3. **Bound to history** — `repository_head` must be an ancestor of HEAD; evidence from an abandoned branch or rewritten history is refused.
4. **Fail-closed** — absent, unparseable, incomplete, stale or disagreeing evidence is an **issue**, never a skip. UNKNOWN never becomes CLEAN.

**Integration:** `scripts/check_primary_ledger.ps1` (single responsibility, no database, independently runnable) **invoked** as **Check 18** of `check_repository_consistency.ps1` — the guard run on every commit, in CI, and at Stage B. Invoked rather than reimplemented, so the two can never disagree about what "matches" means (the PAR-1a mistake of two hand-copied variants).

`check_database_parity.ps1` additionally **cross-checks** any supplied `-PrimaryFingerprint` against the recorded evidence and fails on contradiction — catching a mistyped or stale paste, without pretending recorded evidence is a live read.

**Security:** read-only throughout. No credential is read, stored, committed or transmitted. Primary was contacted only by `select` over `supabase_migrations.schema_migrations`.

**Residual, stated because a guard must not be quoted for more than it measures (MEAS-1):** Check 18 cannot prove the recorded ledger was read *from* Primary rather than generated from the repository — **GUARD-1**'s class, which no repository-local mechanism closes. What it closes is the state RECOVER-1 actually occupied: no Primary reading for the current migration set, every guard green. That is now a hard CI failure.

---

## D. MUTATION / FAILURE PROOF

`scripts/test_primary_ledger_guard.ps1` — every scenario in an isolated temp sandbox; neither the real evidence, the real migrations, nor git history is touched.

| # | Mutation | Expected | Actual |
|---|---|---|---|
| — | CONTROL: untouched sandbox (run **first**, so a broken harness cannot masquerade as detection) | PASS | **PASS** |
| 1 | **Primary has an extra migration — RECOVER-1 itself** | FAIL | **FAIL** |
| 2 | Repository has a migration Primary has not run | FAIL | **FAIL** |
| 3 | **Same count, different identity** (count-only comparison would pass) | FAIL | **FAIL** |
| 3b | …and the count genuinely stayed 189, so detection came from the ledger | true | **true** |
| 4 | Evidence bound to a commit that is not an ancestor of HEAD | FAIL | **FAIL** |
| 4b | Evidence naming a commit absent from the repository | FAIL | **FAIL** |
| 6 | **Evidence missing entirely** | FAIL CLOSED | **FAIL** |
| 7a | Hand-edited `migration_count` | FAIL | **FAIL** |
| 7b | Hand-edited `ledger_fingerprint` | FAIL | **FAIL** |
| 8 | Malformed/truncated JSON | FAIL CLOSED | **FAIL** |
| 9 | Missing required field | FAIL CLOSED | **FAIL** |
| — | CONTROL (second direction): untouched sandbox still passes after all mutations | PASS | **PASS** |

**13 passed, 0 failed.**

**The integration was proven separately, because a passing sub-guard proves nothing about its caller.** The real evidence file was moved aside and `check_repository_consistency.ps1` run: it reported `RECOVER-1 LEDGER EVIDENCE: FAILED` and exited **1** rather than CLEAN. The file was then restored and confirmed **byte-identical** by hash.

**The contradiction check was proven in both directions:** with the correct fingerprint the parity guard exits 0 CLEAN; with the manifest's *old 184-migration* fingerprint (`ed3828994…` — a realistic stale paste) it prints `EVIDENCE CONTRADICTION` and exits 1.

---

## E. VERIFICATION

| Step | Result |
|---|---|
| Migration state | 189, repository = local = Primary, fingerprint `4029ece…` |
| `npx supabase test db` (Pass A) | **91 files / 1264 assertions, PASS** |
| Six HTTP suites | **400 passed, 0 failed** (29 / 107 / 74 / 90 / 40 / 60) |
| `npx supabase test db` (Pass B, no reset) | **91 / 1264, PASS** — Pass A = Pass B |
| Smoke `verify_database.sql` | `ALL CHECKS PASSED (76 tables, …)` |
| `check_database_parity.ps1` (3 live Primary values) | **CLEAN** — ledger, functions (`c83114a8…`, 257), structure (`7f327405…`, 3,442) |
| `check_repository_consistency.ps1` | **CLEAN**, Checks 1–18 |
| `check_primary_ledger.ps1` | **CLEAN** |
| `test_primary_ledger_guard.ps1` | **13 / 13** |

No new failure is hidden by another check: the new guard was proven standalone, proven through its caller, and proven to fail when its evidence is removed.

---

## F. GITHUB SYNCHRONIZATION

Recorded in the closure commit; see the CURRENT STATE line below for the final proven equality or the exact remaining command.

---

## G. CANONICAL SYNCHRONIZATION

- `GOVERNANCE.md` → **v1.12**: new §2 SSOT row for the evidence file (with its evidence class stated), §5 registry entry, changelog line — following §15's own PROPOSE→RATIFY→VERSION→CHANGELOG lifecycle rather than bypassing it.
- `AGENTS.md §4` Stage B step 8 → names Check 18, and adds the behavioural half: **refresh the evidence in the same commit that changes the migration set.**
- `MASTER_REPOSITORY_HEALTH.md §2b` → **Docs-18** row + an explicit evidence-class paragraph.
- `MASTER_GAP_REGISTER.md` → RECOVER-1 **CLOSED**; the obsolete "GUARD OUTSTANDING" status and the **incorrect root cause** ("the parity guard reported CLEAN") both removed and replaced with the reproduced truth.
- `manifest.md` → Last Completed.
- `reports/README.md` → latest-session pointer.

**Obsolete contradictions removed:** the claim that pasted Primary values constitute authoritative parity is gone from the register row; the parity guard's own output now distinguishes *recorded* evidence from a *live* read in words, not just in a header comment.

---

## H. RECOVER-1 STATUS

**CLOSED.**

---

## I. NEXT STEP

**The remaining Batch-6 tables**, per `MASTER_EXECUTION_PLAN.md`, which owns the order. Not started here, by instruction.
