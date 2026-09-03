# ORVION — Git Divergence Reconciliation: two legitimate histories, one authoritative `main`

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-03
Author: Claude Opus 5
Status: Complete — merged and verified locally. **NOT PUSHED** (owner instruction: stop after local verification).

**Scope:** reconcile a real divergence between local `main` and `origin/main` without losing either line of work. Read-only analysis first, then the merge the analysis recommended. **No Batch-6 work, no new product work, no rebase, no force-push — and none was attempted.**

---

## A. WHAT THE DIVERGENCE ACTUALLY WAS

| Axis | Value |
|---|---|
| local `main` | `87be107` |
| `origin/main` | `1193643` |
| merge-base | `4b67d3f` |
| local-only / origin-only | **7 / 6** |
| Migrations: base → origin → local | **184 → 188 → 189** |

**Cause, from timestamps rather than inference.** `4b67d3f` landed 09-01 17:20. Local's first divergent commit was 09-02 **17:59**; origin's was 09-02 **21:21**. Two sessions worked forward from the same base, neither fetched, and neither knew. Nothing was corrupted and nothing was abandoned — both lines are real work.

---

## B. THE FINDING THAT REFRAMED EVERYTHING — and it corrects this repository's own record

`a52b5c7` was committed under the title *"Primary ran four migrations the repository never had."* **That is false of the repository and true only of that clone.** `202607059600`–`202607059900` were committed and pushed hours earlier as `b72caff`, `46a0cfc` and `1193643`.

RECOVER-1 diagnosed a **fetch gap** as an **orphaning**. The observations were all accurate — `git log --all`, the reflog, the stash and `git fsck` genuinely contained no trace, and `1193643` genuinely was not a valid object *in that clone*. The inference drawn from them was not.

**The recovery was nonetheless exact, and git's own object hashing proves it:**

| Migration | origin blob | local blob | |
|---|---|---|---|
| `…059600` | `de526e7ccca7` | `de526e7ccca7` | **IDENTICAL** |
| `…059700` | `570ae330abfc` | `570ae330abfc` | **IDENTICAL** |
| `…059800` | `af88090fe6aa` | `af88090fe6aa` | **IDENTICAL** |
| `…059900` | `a54648ebea8d` | `a54648ebea8d` | **IDENTICAL** |
| `…060000` | *absent* | `e9ec5bc9190b` | **local only** |

Reconstructing four files from Primary's ledger by md5 reproduced the committed originals **byte for byte**. Git raised no conflict on any of them.

**What the incident still demonstrates is undiminished:** Primary ran ahead of a working copy for a day while every guard reported CLEAN. That class is real, and Check 19 still closes it. Only the story about where the commits went was wrong, and it is corrected in `MASTER_GAP_REGISTER.md`, in the manifest and here rather than left to stand.

---

## C. WHY MERGE, NOT REBASE — decided on evidence, not on history aesthetics

The `primary-ledger-evidence.json` binds to `repository_head = b2210f7`:

```
ancestor of local main  : True
ancestor of origin/main : False
```

A merge keeps `b2210f7` reachable through the second parent, so Check 19's ancestry test still passes. **A rebase would rewrite those commits, `b2210f7` would stop being an ancestor, and Check 19 would fail** — exactly as its mutation scenarios 4/4b specify — forcing a fresh live Primary read into what should be a pure history operation.

**The guard built to catch this class voted against rebasing.** That is the mechanism working, not a preference.

Cherry-picking was rejected too: it preserves neither parentage nor the fact that both lines were real, and the four shared migrations would replay as no-ops while every document conflicted anyway.

---

## D. THE THREE SEMANTIC DUPLICATES — none of which git flagged

12 files conflicted textually. The dangerous ones were the collisions git resolved **without complaint**, or resolved in ways that read plausibly.

### 1. `GOV-10 ≡ COLD-2` — one defect, found twice

Both sessions independently discovered that Check 7 compared three of the four `live_state` fields the generator extracts, and both wrote the fix: **the same regex, the same variable names, the same normalisation**, differing only in the warning text. A naive merge produced the block **twice**.

Two copies would not have been merely redundant — they would both fire on the same divergence and count one defect as two issues. **A guard lying about magnitude is the MEAS-1 class.**

Kept: **one** implementation — GOV-10's, on one measurable difference: its warning echoes *both* values, so a failure is diagnosable without re-running the guard. **Both register rows are retained and cross-referenced.** Deleting either would erase the evidence of how the duplication happened, which is a process finding in its own right.

### 2. Two `Check 18`s

COLD-3 added Check 18 (the Active Change Request names a real, still-open CR). RECOVER-1 added Check 18 (Primary ledger evidence). **The published one keeps its number**; RECOVER-1's renumbered to **Check 19**, with the header list, `Docs-19`, `GOVERNANCE.md`, `AGENTS.md §4` and the register all following.

A latent trap surfaced here: origin's COLD-3 block lost its two trailing closing braces to the conflict boundary, because git had matched them as shared context against HEAD's own trailing braces. The script would not parse. Caught by parsing it, then proven whole by probing all seven of COLD-3's distinct failure messages against origin's version.

### 3. Two `ADR-0027`s

One decision, two write-ups, two titles — and **git auto-merged them cleanly**, leaving the file with two `## ADR-0027` headings and no conflict marker to notice. Renumbering one to 0028 would have asserted a second decision that was never made. Merged into **one** record: the published title, the fuller body, and the trailer fields (`Evidence basis`, `Related`, `Revisit trigger`) only the other had.

---

## E. THE OTHER RESOLUTIONS

| File | Resolution |
|---|---|
| `verify_database.sql` | Both sides reached **76**. Kept the commented form. |
| `10_grant_model_test.sql` | Both reached **19**. Kept origin's inline justification *and* the fuller comment block. |
| `86_supplier_credit_visibility_test.sql` | INSERT statements were **byte-identical**; only a comment differed. |
| `35_subscription_write_gate_test.sql` | One exemption entry, one merged rationale keeping the operational argument (emergency revocation must not depend on billing state). |
| `85_write_capability_on_update_test.sql` | Chose origin's `phone` over local's `name` — both valid, the published one wins — and folded in local's trigger-firing-order explanation (`'c' < 'w'`), which says *why*. |
| `verify_role_journeys.ps1` | Two byte-equivalent PATCH helpers under two names. **One** kept; the RBAC-3 call sites retargeted onto it. Two spellings of one request is the PAR-1a class. |
| `ai-map.json` | **Regenerated**, never hand-resolved. Editing conflict markers into a generated artifact is how Check 7 gets lied to. |
| `manifest.md` | Local's live state (**189**, `4029ece…`) — the only one matching Primary. |
| `MASTER_EXECUTION_PLAN.md`, `28_permissions_matrix.md`, `31_schema_draft.md` | Origin's, untouched locally. |

**A canon gap the merge repaired.** Local canon did not know the permission its own migration mints:

```
28_permissions_matrix.md   origin  MANAGE_SUPPLIER_CREDIT x3
28_permissions_matrix.md   local   MANAGE_SUPPLIER_CREDIT x0
```

RECOVER-1 reconstructed tests and an ADR from Primary's SQL, but a database does not return canon. Origin had it all along.

### The duplicated test suites

Both sessions wrote tests for the same three migrations: origin's `90`/`91`/`92` (69 assertions) and RECOVER-1's reconstructed `90`/`91` (31). Origin's are the originals, more thorough, and named to match the migrations — they are kept.

**Before removing the reconstructions, they were read for anything origin's lacked, and one thing was found.** Both files had discovered that the credit column now carries *two* enforcers, and each solved the resulting mutation problem differently:

- **Origin** adds an ordinary column to the write, so `guard_write_capability` charges a permission the actor holds and the credit guard becomes the sole refuser.
- **The reconstruction** ran a two-step mutation: drop the dedicated trigger → *still refused*; drop both → *succeeds*.

The reconstruction's first step asserts something origin's file does not: that each guard **independently** defends the ceiling. That assertion was **ported into origin's `90_`** (plan 17 → 18) with its provenance recorded, and only then were the two files removed. Nothing of engineering value was discarded; the files remain in history.

---

## F. VERIFICATION ON THE MERGED TREE

Run in full on the merged tree, because passing on either parent proves nothing about the merge.

| Step | Result |
|---|---|
| `npx supabase db reset` | **189 migrations applied cleanly** |
| Migration count in tree | **189** |
| Ledger vs recorded Primary evidence | **`4029ecefa4bf40639b3bb61d63f986ef`, exact match** |
| `npx supabase test db` (Pass A) | **92 files / 1303 assertions, PASS** |
| Six HTTP suites | **414 passed, 0 failed** (29 / 40 / 74 / 107 / 104 / 60) |
| `npx supabase test db` (Pass B, no reset) | **92 / 1303, PASS — Pass A = Pass B** |
| Smoke `verify_database.sql` | `ALL CHECKS PASSED (76 tables, …)` |
| `check_repository_consistency.ps1` | **CLEAN**, Checks 1–19 |
| `check_database_parity.ps1` (3 live Primary values) | **CLEAN** — ledger, functions (`c83114a8…`, 257), structure (`7f327405…`, 3,442) |
| `test_primary_ledger_guard.ps1` | **13 / 13** |

**Primary was read live and read-only** via the `supabase-primary` MCP — ledger, function surface and structural surface. No write, migration or schema change reached it. Primary reports **189, newest `202607060000`**, and all three hashes are identical to the merged tree's.

### The four required proofs

| Claim | Proof |
|---|---|
| one `$mfAcr` implementation | mutated the manifest without regenerating ai-map → **exactly 1** `AI-MAP STALE … active_change_request` line. Two would have meant the duplicate survived. |
| one `Check 18` | one `Write-Host "== Check 18` — COLD-3 — and mutating the manifest to name a `[x] Complete` CR **fails it while Check 7 stays silent**, so the two are independently live. |
| one `Check 19` | one `Write-Host "== Check 19` — the ledger guard — and removing the evidence file makes the **parent** guard exit 1, then restores byte-identical. |
| one `ADR-0027` | one `## ADR-0027` heading and one mention in the file. |

### Two failures the merge itself produced, both fixed

1. **`check_repository_consistency.ps1` would not parse.** Origin's COLD-3 block lost its two trailing closing braces to the conflict boundary — git had matched them as shared context against HEAD's own trailing braces. Caught by parsing the file, then proven whole by probing all seven of COLD-3's distinct failure messages against origin's version.
2. **`verify_role_journeys.ps1` failed one assertion.** Origin's SUP-2 block asserted the ceiling was `25000` — the value the *fixture* inserts — which held while that block was the only writer of the column. The merge put the RBAC-3 block above it on the same supplier, so the ceiling legitimately read `41000` and the assertion failed while the behaviour it measures was correct. The literal was never the thing under test: what the pair proves is that a **refused write leaves the value unchanged**. It now reads the value immediately before the write and compares against that — strictly stronger, since it can no longer pass by coincidence.

**One mutation test was invalid on its first run and was redone.** The first attempt to make Check 18 fail used a `$`-anchored regex that CRLF defeated, so the manifest was never actually mutated and the guard "passed" a mutation that had not happened. Verified the mutation landed on disk before trusting the second run — a guard that passes an absent mutation measures nothing.

---

## G. WHAT IS STILL OPEN

- **Not pushed.** By instruction, this package stops at local verification.
- **SUP-4b** remains the owner's decision: whether the ceiling REFUSES or WARNS, at which operation, and with what override. Currency, exposure and supplier scope are all derived and shipped. **`CREDIT LIMIT ENFORCED = NO`.**
- The process defect underneath all of this — **two sessions diverging without fetching** — is now recorded in the register. No guard in this repository compares local `main` against `origin/main`, and nothing here changes that.

---

## H. NEXT STEP

Push, then **the remaining Batch-6 tables** per `MASTER_EXECUTION_PLAN.md`, which owns the order. Not started here, by instruction.
