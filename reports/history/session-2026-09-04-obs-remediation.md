# ORVION — OBS-1/2/3 remediation and full post-reconciliation verification

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: Complete — five findings registered, three guard/registry defects fixed and mutation-proven, full `§5a` protocol executed green.

**Scope:** close the three observations raised by the 2026-09-04 post-merge forensic audit; establish that substantive sessions leave repository evidence; and re-verify the reconciled state end-to-end. **No Batch-6 implementation. No new business policy. No schema change — not one migration was added, and Primary was read-only throughout.**

---

## A. BASELINE, VERIFIED NOT ASSUMED

`AGENTS.md §4` forbids treating a prior session's claims as current state. Every baseline value below was re-derived this session.

| Fact | Claimed baseline | Verified | Method |
|---|---|---|---|
| Local HEAD | `ce60179` | ✅ `ce60179afbc590e49c4d21074f0a97ac8b842a05` | `git rev-parse HEAD` |
| `origin/main` | `ce60179` | ✅ identical | `git fetch` **then** `git ls-remote origin refs/heads/main` (independent of the cached ref) |
| Ahead / behind | 0 / 0 | ✅ `0	0` | `git rev-list --left-right --count` |
| Working tree | clean | ✅ clean at session start | `git status --porcelain` |
| Merge commit | `d02b702` | ✅ two parents `87be107` + `1193643` | `git cat-file -p` |
| Migration count | 189 | ✅ 189 repo / 189 local / 189 Primary | file count + both live ledgers |
| Ledger fingerprint | `4029ecef…` | ✅ identical on all three | live MCP read of Primary |
| Checks 1–19 | CLEAN | ✅ CLEAN, exit 0 | executed |
| RECOVER-1 | CLOSED | ✅ artifacts present, Check 19 green | executed |
| SYNC-1 | OPEN / controlled | ✅ row present, status OPEN | register |
| SUP-4a / SUP-4b | CLOSED / OPEN | ✅ unchanged | register |
| Batch 6 | not started | ✅ confirmed — see §H | `MASTER_EXECUTION_PLAN.md` |

**No baseline discrepancy was found.** The authorization model described in the baseline (deny > user grant > role grant > plan gate; groups as metadata; View/Manage independent) was re-derived from the **deployed catalog** and matches — see §F.

---

## B. OBS-1 → CANON-31-1 · canon did not document the grant model

**Investigated, not assumed.** The audit said canon 31 lacked `user_permission_grants`, `capability_group` and `action_kind`. Confirmed by measurement: 0 occurrences of each, while every sibling table was documented (`users`, `roles`, `permissions` ×9, `role_permissions` ×3, `user_role_assignments` ×3, `user_branch_assignments` ×2). `_ORVION_CANONICAL/34` and `35` (the cross-cutting auth/tenancy principles) carried none of the three either.

**Root cause, and it is not the merge.** Canon 31's blob is **identical** across origin-tip `1193643`, local-tip `87be107` and HEAD. Origin's own package updated canon 31 for SUP-4a's currency column (`202607059900`) and never for the grant table (`202607059800`). Inherited gap, not merge-caused.

**Fix.** Documented at *intent* level, because `GOVERNANCE.md §2` gives schema **truth** to `supabase/migrations/**` and schema **intent** to canon 24–33 — so canon states what the model IS and points at the migration rather than restating DDL. Added to `31_schema_draft.md`:

- `## user_permission_grants` — purpose, the missing user→permission edge it closes, all 12 core fields with the SUBJECT-vs-actor distinction on `user_id`, and a Rules block: the composite unique key, the `ends_at > starts_at` period check, tenant-qualified composite FKs per TENANT-1, `MANAGE_PERMISSIONS` enforced in per-command RLS (not a trigger), **no DELETE policy**, and the resolution order with the plan gate stated as terminal.
- `permissions` — added `required_feature_code`, `capability_group`, `action_kind`, each marked **metadata, never a security boundary**, with the NULL-group rule stated as deliberate.

**Verified against implementation.** Every documented field, constraint, index and policy was read from the live catalog first (`information_schema.columns`, `pg_constraint`, `pg_indexes`, `pg_policies`) and the text written from that reading — not from the migration's prose and not from the audit.

**No RBAC semantics were invented and the model was not redesigned.**

---

## C. OBS-2 → GOV-11 · the audit's premise was wrong; the real defect was worse

**The audit's claim:** three findings (RECOVER-1, RBAC-5, RBAC-6) have detail blocks but no summary-table row, and therefore "fall outside the table Check 2 scans".

**Both halves of that are false, and measuring it produced a materially larger finding.**

1. **59 of 98 detail blocks have no register-table row.** That is the register's *convention*, not an omission — every finding from `DEL-1` onward follows it. Adding 59 rows would have been exactly the cosmetic churn `AGENTS.md §2` forbids.
2. **Check 2 does read detail blocks.** It was extended on 2026-08-29 for precisely this, tracking `$blockId` and reading a block's own `**Status:**` field.

**The actual defect.** That reader required a bullet **beginning** `- **Status:**`. The register has never once written that form — it states the verdict **inline** on a combined field line:

```
- **Category:** parity / process · **Severity:** **Critical** · **Status:** **CLOSED 2026-09-03** · **Owner:** engineering
```

Measured with the guard's own regex: it matched **0 of 96** detail blocks. **46 blocks state a resolved verdict this way**, including **RECOVER-1 (Critical, CLOSED)**, SUP-2, SUP-3, SUP-4a, RBAC-5 and RBAC-6. Every one of those statuses was invisible to a contradiction search, while the check printed a verdict. This is the **MEAS-1 class** (a guard claiming more than it measures) occurring **inside the guard that reports that class** — the same family as GOV-4 and AUD-04.

**A second, deeper half — found by attacking the first fix, not by reading it.** With the anchor repaired, the mutation that *should* have flagged RECOVER-1 as OPEN in another Master still came back **CLEAN**. Reason: a detail-block status line is neither a table row nor a `###` heading, so it never reaches the loop that populates `$xResolved` — AUD-04's cross-Master pass had **never** read detail blocks at all. Fixed by wiring the cross-file table at the same point.

**Fix.** The verdict is anchored to the marker *immediately after* `**Status:**`, so a BLOCKED/OPEN block is not read as resolved because a later clause on the same line contains the word "fixed".

**Mutation-proven in three directions, restores byte-identical:**

| Probe | Expected | Result |
|---|---|---|
| RECOVER-1 row injected `OPEN` **inside the register** | must flag | ✅ `STATUS CONTRADICTION: MASTER_GAP_REGISTER.md: RECOVER-1 OPEN at line 1158 but resolved at line 1096` — exit 1 |
| RECOVER-1 row injected `OPEN` in **a second Master** | must flag | ✅ `CROSS-MASTER STATUS CONTRADICTION: RECOVER-1 is OPEN in MASTER_DEPENDENCY_GRAPH.md:51 but resolved in MASTER_GAP_REGISTER.md:1096` — exit 1 |
| RET-1 (block status **BLOCKED**) injected `OPEN` | must **not** flag | ✅ CLEAN |
| Both probe files after restore | byte-identical | ✅ SHA-256 match on both |

Negative control before the edit: 46 resolved status lines match, **all 40** non-resolved ones (BLOCKED, OPEN, INTENTIONAL, IN PROGRESS, OBSOLETE, MITIGATED, NARROWED, DEFER, SUPERSEDED, DELIVERED) do not.

**Limit stated at the point of implementation.** The resolved *vocabulary* is deliberately unchanged (`RESOLVED|FIXED|IMPLEMENTED|CLOSED`). `DELIVERED` and `SUPERSEDED` read as terminal to a human and still do not count. Widening the vocabulary is a separate decision about what those words mean; repairing an anchor is not the place to make it.

---

## D. OBS-3 → GOV-12 · not "documented and intentional" — a duplicate the audit missed

**Investigated from the file rather than from the ID NOTE.** The audit accepted the collision as disclosed and safe. It is not, and the reason is a duplicate the audit did not look for.

| Identifier | Where | Means |
|---|---|---|
| `RBAC-3` | **Register table row** (added by origin `1193643`) | "A capability could be granted to a ROLE and to nothing else" — the per-user grant work, `202607059800` |
| `RBAC-3` | **Two `###` detail blocks** (2026-08-28) | "an employee cannot assign leads" — INTENTIONAL, a completely different finding |
| `RBAC-5` | **`###` detail block** (added by local `a52b5c7`) | the per-user grant work — **the same finding as the row above** |

So the merged register carried **one finding under two ids**, while **one id meant two findings**. Git flagged nothing because the row and the block live in different regions of the file — the same class of silent semantic conflict the reconciliation already caught three times.

Verified from history: no `| RBAC-3 |` row exists at merge-base `4b67d3f` or at local-tip `87be107`; it appears only at origin-tip and at HEAD.

**Resolution — applying a decision the repository had already recorded, not making a new one.** The RBAC-5 block's own ID NOTE states: *"The register is the SSOT for finding ids (`GOVERNANCE.md §2`), so the rows are RBAC-5 and RBAC-6."* Under `AGENTS.md §1` applying an already-recorded decision is implementation, not escalation. The table row is now **`RBAC-5`**, carrying an **ID CORRECTED** note that names its original id, why it was minted, and why nothing else moved.

**No cosmetic renumbering, per instruction.** The migration and test prose still say `RBAC-3`/`RBAC-4` and remain byte-identical to what Primary executed; the ID NOTE is the map from those to the register.

**No guard added — deliberately.** The root cause is SYNC-1 (two sessions, one base, no fetch), which already carries its own control. No deterministic file-local check separates a legitimate id reuse from an illegitimate one without a title-similarity heuristic that could go green while wrong, and `AGENTS.md §6` forbids a guard whose description would outrun its measurement. Recorded as reasoning rather than left as an unexplained absence.

---

## E. GOV-13 (new — missed entirely by the audit) and GOV-14

### GOV-13 · three living references named pgTAP files the merge had deleted

Found while checking OBS-3's evidence pointers. The `d02b702` merge deleted the two RECOVER-1 reconstruction test files (correctly — superseded by the committed originals), and **three live references kept naming them**:

| Location | Cited | Status |
|---|---|---|
| `MASTER_GAP_REGISTER.md` SUP-3 block | a deleted file, **as SUP-3's proof on both doors** | repointed → `91_supplier_credit_permission_test.sql` (26 assertions) |
| `MASTER_GAP_REGISTER.md` RBAC-5 block | a deleted file, for "16 assertions" | repointed → `92_capability_grant_model_test.sql` (26 assertions) |
| `scripts/verify_role_journeys.ps1` | a deleted file, as its pgTAP counterpart | repointed → `91_supplier_credit_permission_test.sql` |

**A register row pointing at a test that does not exist is a finding whose evidence cannot be re-run.** Nothing measured it: Check 1's token set was documents only (`NN_name.md`, `MASTER_*.md`, `ADR-NNNN.md`).

**Guard added** — Check 1 widened to resolve `NN_*_test.sql` in Living docs **and** `scripts/*.ps1`. Same invariant (a reference that does not resolve), so it extends Check 1 rather than minting a Check 20. `history/` and `changes/` stay excluded: an immutable dated report naming a file that existed then is HISTORY (`GOVERNANCE.md §4`).

**Mutation-proven both directions:** a reference to `99_this_file_does_not_exist_test.sql` flags `BROKEN TEST REF` and exits 1; a reference to `92_capability_grant_model_test.sql` does not; probe file restored byte-identical.

*(The two correction notes name the dead artifact without its `.sql` extension, deliberately — it is a historical pointer, not a live reference, and must not satisfy or trip the new check.)*

### GOV-14 · the audit itself left no repository artifact

The 2026-09-04 forensic audit re-proved the ledger against Primary, reconstructed the authorization model from the live catalog and re-ran the consistency guard — and wrote **nothing** to the repository. A fresh session inherited none of it; this session re-ran that work to answer the same questions.

**The rule already existed.** `AGENTS.md §2/§6` and `GOVERNANCE.md §2/§6` already say the repository — never the chat — is ORVION's long-term memory, and that memory is a cache. **No parallel rule was created** (`GOVERNANCE.md §6` rule 8, One Authority). Its one home in `AGENTS.md §6` was extended to state that a **read-only session is still a session**, and that a no-mutation instruction makes the report *the only durable artifact the session can leave* rather than a step to skip. Same class as COLD-2's own root cause: a rule whose coverage was a record of past incidents rather than a statement of its contract.

---

## F. FULL POST-RECONCILIATION VERIFICATION — EXECUTED, BY EVIDENCE CLASS

`AGENTS.md §5a` protocol, run in order. **Every row below was executed this session**; nothing is inferred from a previous report.

| # | Step | Evidence class | Result |
|---|---|---|---|
| 1 | `npx supabase db reset` | LOCAL RUNTIME | ✅ all 189 migrations applied, exit 0 |
| 2 | **Pass A** `npx supabase test db` | LOCAL RUNTIME | ✅ **Files=92, Tests=1303, Result: PASS** |
| 3 | `verify_role_journeys.ps1` | HTTP | ✅ 104 passed, 0 failed |
| 3 | `verify_api_end_to_end.ps1` | HTTP | ✅ 29 passed, 0 failed |
| 3 | `verify_lifecycle_branches.ps1` | HTTP | ✅ 107 passed, 0 failed |
| 3 | `verify_journey_branches.ps1` | HTTP | ✅ 74 passed, 0 failed |
| 3 | `verify_care_journeys.ps1` | HTTP | ✅ 40 passed, 0 failed |
| 3 | `verify_storage_end_to_end.ps1` | HTTP | ✅ 60 passed, 0 failed — **414 total, 0 failed** |
| 4 | **Pass B** (no reset) | LOCAL RUNTIME | ✅ **Files=92, Tests=1303, PASS — Pass A = Pass B** |
| 5 | `verify_database.sql` smoke | LOCAL RUNTIME | ✅ `ALL CHECKS PASSED (76 tables, …)` |
| 6 | Primary's three values, read **from Primary** | **PRIMARY** | ledger `4029ecef…`/189 · functions `c83114a8…`/257 · structure `7f327405…`/3442 |
| 7 | `check_database_parity.ps1` (all three) | REPOSITORY + PRIMARY | ✅ **DATABASE PARITY: CLEAN** (local proven; primary ledger, functions and structure proven) |
| 9 | `check_repository_consistency.ps1` | REPOSITORY | ✅ **CLEAN, Checks 1–19, exit 0** |

**Git integrity.** All 13 divergent commits reachable; both merge parents ancestors of HEAD; no missing merged work (`git diff --diff-filter=D 1193643 HEAD` empty). **Migration integrity.** 189, strictly ascending, no duplicate timestamp prefix, latest `202607060000`, repository set identical to Primary's ledger.

**Authorization — read from the DEPLOYED catalog, not from files.** `app.has_permission` resolves `not exists(deny) AND (user grant OR role grant) AND app.plan_allows(...)` with the plan gate terminal, tenant pinned in both the actor CTE and the override join, and `starts_at`/`ends_at`/`is_active` time bounds. `app.effective_permissions` ends `(not udn) and (ugr or fr) and pa` — the same decision in the same order. `user_permission_grants` carries exactly three RLS policies (read tenant-scoped; insert and update charging `MANAGE_PERMISSIONS`) and **no DELETE policy**. `MANAGE_SUPPLIER_CREDIT` is live, `capability_group = Finance`, `action_kind = manage`, `required_feature_code = finance_lite` (same tier as the read permission), granted to exactly `ceo, finance_manager, owner`. **All of it now additionally proven behaviourally by the 1303 executed assertions**, which the prior audit could only inspect.

**Supplier credit** (executed, `90`/`91`/`86` + HTTP): read/write asymmetry, credit-only vs mixed vs ordinary writes, insert-with-ceiling, `finance_manager` positive path, grant/revoke round-trip, and the two independent enforcers each proven by defect injection.

**Reconciliation work re-verified:** COLD-2/GOV-10 (exactly one `$mfAcr`, Check 7 green), COLD-3/Check 18 (green, distinct from Check 7), RECOVER-1 (Check 19 green, evidence + guard + 13-assertion mutation suite present), SUP-3, SUP-4a.

**Efficiency / coherence sweep (§I).** No broken references (Check 1, now including test files). No dead authorization path — every enforcement site still routes through `app.has_permission`; no path bypasses it. No duplicated enforcement introduced. No migration-ordering hazard. Two guards were found producing false green and both were fixed (GOV-11, GOV-13) — that was the sweep's main yield.

---

## G. NOT DONE / LIMITATIONS — stated explicitly

- **Primary was never written.** No migration, no DDL, no row. All Primary access was read-only MCP `execute_sql`. Primary behaviour is therefore proven only for what a read can prove; **no test executed against Primary** — pgTAP and HTTP ran against local, which is at proven structural parity.
- **`supabase_vector_ORVION` was restarting** throughout (the log shipper). Infrastructure, not product — it touches no tested path, and is recorded rather than silently ignored (`AGENTS.md §6`).
- **Check 2's resolved vocabulary was not widened** (see §C limit).
- **No guard was added for GOV-12** (see §D reasoning).
- **`-PrimaryLogicHash` / `-PrimaryStructureHash` take the bare md5**, not the `md5|count` form the parity SQL emits. A first invocation passing the piped form reported two DRIFT lines whose hashes were visibly identical. That is a caller-format trap, not drift and not a defect; recorded here because the transcript of a real drift and this look alike at a glance.

---

## H. BATCH 6

Not started, and not started here. The first remaining unfinished slice was identified from `MASTER_EXECUTION_PLAN.md` and reconnoitred **discovery-only**; that work has its own report: `session-2026-09-04-batch6-discovery.md`.

---

## I. CURRENT STATE

| Axis | Value |
|---|---|
| Migrations | **189**, latest `202607060000`, ledger `4029ecefa4bf40639b3bb61d63f986ef` |
| Repository / local / Primary | ledger, function surface (`c83114a8…`/257) and structural surface (`7f327405…`/3442) **all three identical** |
| pgTAP | **92 files / 1303 assertions**, Pass A = Pass B |
| HTTP | **414 passed / 0 failed** across six suites |
| Smoke | ALL CHECKS PASSED (76 tables) |
| Guards | repository consistency **CLEAN** Checks 1–19; database parity **CLEAN** |
| Findings added | GOV-11, GOV-12, GOV-13, GOV-14, CANON-31-1 — all ✅ FIXED |
| Still open | **SYNC-1** (controlled), **SUP-4b** (owner/business decision — untouched) |

## J. NEXT STEP (exactly one)

Read `session-2026-09-04-batch6-discovery.md` and decide the one owner question it isolates. No implementation is authorized until that decision is made.
