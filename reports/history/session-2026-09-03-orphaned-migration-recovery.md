# ORVION — Four Orphaned Migrations, and the Authorization Refactor Nobody Could See

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-03
Author: Claude Opus 5
Status: Complete. **5 migrations added to the repository (4 recovered from Primary, 1 new), 1 deployed to Primary.**

**Scope:** an owner directive asking for an external-research pass on authorization, a preserve/refactor/rebuild verdict on the model "delivered in `1193643`", and SUP-4 driven as far as evidence permits. **The directive's premises did not match this repository, and finding out why became the session.**

**HEAD at start:** `da799e3` (184 migrations, 2 commits ahead of `origin/main`). **Primary at start: 188 migrations.**

---

## DISCOVERED

### RECOVER-1 (Critical) — Primary was four migrations ahead of the repository, and every guard said CLEAN

The directive referred to commit `1193643`, to a finding id `SUP-4`, to a `user_permission_grants` table, to a decision recorded as "B — Refactor grant model; preserve enforcement plane", and to "197 existing enforcement sites". **Every one of those was absent from this repository.** `git cat-file -t 1193643` → *not a valid object name*; `SUP-4` matched no file; `user_permission_grants` matched no file; 526 commits across all refs, the reflog, the stash and `git fsck` contained none of it.

The natural conclusion — that the directive was describing a different repository — was wrong, and testing it rather than assuming it is what found the defect. A live read of Primary returned:

```
migrations on Primary                 188
migrations in supabase/migrations/    184
permissions.capability_group          EXISTS on Primary, in no migration file
permissions.action_kind               EXISTS on Primary, in no migration file
public.user_permission_grants         EXISTS on Primary, in no migration file
```

Four migrations — `202607059600` (SUP-2), `202607059700` (SUP-3), `202607059800` (the per-user grant model), `202607059900` (SUP-4a) — had been applied to Primary on 2026-09-02 by `platplustours@gmail.com` and **never committed**. The owner's premises were accurate about the *work*; the work simply never reached the repository. Commit `1193643` presumably exists in a clone that was never pushed.

**Why nothing caught it — this is the finding, not the four files.**

| Guard | What it actually compares | Why it was silent |
|---|---|---|
| `check_repository_consistency.ps1` | repository files only | opens no database, and says so on success |
| Check 9 (manifest ↔ repository) | manifest's claimed count vs file count | both said 184 — consistently, and wrongly |
| `check_database_parity.ps1` | repository ↔ **local**; Primary only from three **pasted** values | a session that does not run it with those arguments learns nothing, and the run is indistinguishable from a clean one |

**No guard in ORVION reads Primary's migration count on its own initiative.** So "I did not check" and "I checked and it matched" produce the same output, and Primary ran ahead for a day carrying a security-relevant authorization refactor.

**Blast radius while it lasted:** the repository could not rebuild Primary. `npx supabase db reset` produced a database four migrations behind the one being served, so every local proof — pgTAP, smoke, all six HTTP suites — was evidence about a *different schema*, and the manifest's published hashes described the 184-migration world.

### RBAC-6 (Medium) — the explainer the dashboard was built for could not be reached from the dashboard

Found while reconstructing the lost tests. `202607059800` created `app.effective_permissions` explicitly "for the dashboard and for an audit" and granted EXECUTE to `authenticated` — and never created the `public` wrapper. **PostgREST serves only `public`.** Measured: both of its nearest siblings (`public.tenant_capabilities`, `public.supplier_credit`) have wrappers; this one did not. The single capability the refactor exists to enable was unreachable from any browser.

### A test-harness class: a swallowed fixture error

`verify_role_journeys.ps1` builds its supplier fixture with `Psql … | Out-Null`, which **discards the error**. When SUP-4a's new CHECK made that INSERT invalid, the supplier silently never existed and three assertions failed with `supplier is not in your tenant` — a message about the wrong thing. Here it was merely confusing, because those are positive assertions. **Under a negative assertion, "the employee cannot read the ceiling" would have passed for the sole reason that there was no ceiling to read.** A `FIXTURE CONTROL` assertion now proves the row exists before anything is asserted about it.

### A second enforcer, found by a mutation that failed

The first draft of `90_…`'s PAR-4 mutation dropped `suppliers_guard_credit_authority` and asserted the write then succeeds. **It did not.** `guard_write_capability`'s credit-only branch is an independent second enforcer of the same rule. A single-trigger mutation would have reported "this guard is load-bearing" while actually measuring the *other* guard — the masking `AGENTS.md §21` warns about. The test now drops them one at a time and then both, pinning the complete enforcement set.

### Pass B caught order-dependence in a test written this session

`91_…` assertion 1 asserted the grant table was globally empty. Pass B (the un-reset second run) failed it, because the HTTP suite deliberately leaves a real grant row behind. Scoped to the file's own tenant. TEST-2's class, caught by the mechanism that exists for it.

---

## VERIFIED

Every command run this session, with its real output. Local stack up (Docker was **down at session start** and was started).

| Step | Command | Result |
|---|---|---|
| Recovery integrity | md5 of each recovered file vs `md5(array_to_string(statements,E'\n'))` on Primary | **4/4 byte-identical** — `c45fbd1b…`, `fc8f8a53…`, `d338a3c2…`, `6bd9b19f…` |
| Replay | `npx supabase db reset` | all **189** applied cleanly |
| Pass A | `npx supabase test db` | **91 files / 1264 assertions, PASS** |
| HTTP | six suites | **400 passed, 0 failed** (29 / 107 / 74 / 90 / 40 / 60) |
| Pass B | `npx supabase test db`, no reset | **91 / 1264, PASS** — Pass A = Pass B |
| Smoke | `scripts/verify_database.sql` | `ALL CHECKS PASSED (76 tables, …)` |
| Primary reads | `supabase-primary` MCP, live | ledger `4029ecefa4bf40639b3bb61d63f986ef` (189) · functions `c83114a8697af5884411719a9dd1a874` (257) · structure `7f3274058d23126297f1b94b33438925` (3,442) |
| Parity | `check_database_parity.ps1` with all three | ledger ✓ · function surface ✓ · **structural surface matches exactly** |
| Contract | `generate-api-contract.ps1` | 73 RPC endpoints (73 with HTTP evidence), 8 views, 72 tables; Check L3 diff clean |
| Repository | `check_repository_consistency.ps1` | **CLEAN** |

**Behavioural proof of the recovered architecture** (not inferred from reading it):

- per-user grant: employee `CREATE_JOURNAL_ENTRY` false → grant → **true**;
- deny over role: employee `CREATE_LEAD` true → deny → **false**;
- deny over direct grant: grant and deny coexist, **deny wins**;
- **commercial boundary holds**: a starter tenant's own owner, holding an explicit grant written as `postgres`, still cannot use a `full_finance` capability;
- **revocation is immediate over HTTP** with the same unexpired token — the property that decides against JWT claims;
- explainer never disagrees with the decider, across every active permission, in one assertion.

**External sources verified live (2026-09-03), not recalled:** AWS IAM policy evaluation (explicit deny overrides explicit allow; default implicit deny) · Supabase Custom Claims & RBAC (role in claim, permissions queried at request time) · OWASP Authorization Cheat Sheet (deny-by-default, server-side on every request, prefer ABAC/ReBAC where RBAC is insufficient, never client-side). All three claims the recovered migration makes about external practice are **accurate**.

---

## FIXED

1. **Four migrations recovered** into `supabase/migrations/`, byte-verified, replayed.
2. **`202607060000`** — RBAC-6's `public.effective_permissions` wrapper. Applied to Primary; MCP-assigned version `20260903094532` reconciled to `202607060000` per the documented precedent.
3. **`scripts/verify_database.sql`** — expected table count 75 → 76. Raised because a table was legitimately added and is live on Primary, **never to make a failing guard pass**.
4. **Two new pgTAP files** — `90_supplier_credit_authority_test.sql` (15), `91_per_user_capability_grants_test.sql` (16).
5. **Three class guards updated with evidence, not with a bigger number**: `10_grant_model_test` ceilings 54→55 and 18→19, justified by *behaviourally* proving `user_permission_grants` refuses an unprivileged INSERT and accepts a privileged one; `35_subscription_write_gate_test` exemption (its siblings `users`/`user_role_assignments`/`user_branch_assignments` are all exempt, and **emergency revocation must not depend on billing state**); `83_actor_attribution_test` classification of `user_permission_grants.user_id` as a grant *subject*, not an actor.
6. **`53_api_surface_test`** — `effective_permissions` classified; positive control 76→77, and its prose corrected from a stale "75" that had drifted from its own assertion.
7. **19 new HTTP assertions** + the `FIXTURE CONTROL` guard against the swallowed-fixture class.
8. **Documentation rebuilt** — ADR-0027, seven register rows, manifest live-state, this report.

---

## NOT FIXED

- **SUP-4b — `CREDIT LIMIT ENFORCED = NO`.** Owner decision; see below. Everything derivable has shipped.
- **RECOVER-1's permanent guard is NOT built.** The correct invariant is that the guard *reads* Primary's ledger rather than being handed it — which requires the guard to hold Primary credentials, and it deliberately holds none (`AGENTS.md §6`: no secret passes through the agent or a script). **The smallest correct fix is a design decision, not a typing exercise**, so it is recorded rather than improvised. Two candidates: a read-only Primary connection for the guard, or a repository check that FAILS when no dated Primary reading exists for the current HEAD. **Until one lands, this class can recur**, and that is the single most important open item in this report.
- **The lost artifacts are rewritten, not restored.** The original tests, ADR and register rows for SUP-2/SUP-3/SUP-4a/RBAC-5 are gone permanently. What exists now was reconstructed from the migrations' own (unusually complete) reasoning. It is new work and should be read as such.
- **ID collision.** `202607059800`'s prose says "RBAC-3" and `202607060000`'s says "RBAC-4"; both ids were already taken. The register rows are **RBAC-5**/**RBAC-6** and the migrations were left byte-identical to what Primary ran. Recorded in RBAC-5's ID NOTE.

---

## SUP-4 — driven as far as the evidence permits

The directive said not to stop merely because earlier analysis called parts of it a business question. Three of the four parts turned out **not** to be business questions.

| Question | Verdict | Basis |
|---|---|---|
| Currency of the limit | **DERIVABLE → SHIPPED** | Eleven money-bearing tables; ten carry `currency_code`; `suppliers` was the only one that did not. Canon 30's own money standard. Fixed by SUP-4a. |
| Exposure definition | **AUTHORITATIVE, already implemented** | `app.supplier_balance` — locked cost minus supplier payments, per currency, excluding cancelled/no_show/archived. |
| Earliest real exposure | **DERIVABLE** | `cost_locked_at`, set by `app.review_finance_approval`. Cost is provisional until finance locks it. |
| Comparison rule | **DERIVABLE** | Per currency, never converted — ADR-0020/ADR-0021's shipped precedent. `tenants.default_currency_code` measured to have **no consumer**; deliberately not pressed into service as a base currency. |
| Supplier scope | **DERIVABLE: all suppliers** | No type/status/category exclusion exists; `supplier_type_code` is descriptive. NULL ceiling = no ceiling. |
| **Does it REFUSE or WARN? At which operation? With what override?** | **UNDEFINED — owner decision (SUP-4b)** | ADR-0020's precedent for a balance-constrained operation is *not* refusal: `advance_booking` requires an override permission and records a `risk` event. Whether supplier credit behaves the same way is a commercial-relationship choice. Canon names no operation, no override permission, no supplier-credit event type. |

**`CREDIT LIMIT ENFORCED = NO`, and the reason is precise:** nothing anywhere compares exposure to the ceiling. What was *blocking* enforcement was a schema defect, now fixed — the comparison was not hard, it was **malformed**, because a per-currency exposure cannot be compared to a currency-less scalar. Concurrency is part of SUP-4b's answer, not a separate item: if refusal is chosen, `exposure + new <= limit` must serialize against the rows it sums.

---

## GOVERNANCE

- `AGENTS.md §4`'s opening rule — *a claim in this conversation is a lead, never a fact* — is what produced this session's main finding. The directive was an owner instruction containing falsifiable premises; testing them rather than executing on them is what surfaced RECOVER-1.
- Recovering the migrations was **repair-before-features** (`GOVERNANCE.md §19`) and was not treated as an owner decision: the repository being unable to rebuild the environment it deploys to is a defect, and restoring files that already run on Primary is non-destructive and reversible.
- **No exemption was manufactured.** Every raised ceiling in this session is paired with a behavioural proof that the thing it now admits is genuinely enforced by something else.

---

## ENVIRONMENT

Docker Desktop was **not running** at session start; started mid-session. `supabase_vector_ORVION` restarts continuously — pre-existing, unrelated to the database, did not affect any run. Primary reachable throughout via `supabase-primary` MCP; `get_project_url` confirmed `vrvtsxexkiiiivlkdxzp` before every write.

---

## CURRENT STATE

- **189 migrations**, latest `202607060000`, ledger `4029ecefa4bf40639b3bb61d63f986ef` — repository = local = Primary.
- Functions `c83114a8697af5884411719a9dd1a874` (257); structure `7f3274058d23126297f1b94b33438925` (3,442 objects). **Parity PROVEN, Primary values read FROM Primary.**
- **76 tables** · 71/601 catalog · 8 reporting views · **73 client RPCs** · **72 permissions**.
- Suite **91 files / 1264 assertions**, Pass A = Pass B. HTTP **400 assertions**, 0 failed. Smoke passes.
- Both guards CLEAN. Working tree clean, everything committed at `a52b5c7`.
- **NOT PUSHED, and this is the second session in a row it has happened.** `git push origin main` fails with `could not read Username for 'https://github.com': terminal prompts disabled` — this session is non-interactive and holds no GitHub credential, and per `AGENTS.md §6` no credential may pass through the agent. **`origin/main` is 3 commits behind `main`** (`4b67d3f` → `a52b5c7`), and those three now include the entire orphaned-migration recovery.
- **The owner must run `git push origin main` from an interactive terminal.** Until then the recovery exists on this workstation only — which is a milder version of the very failure this session repaired: work that runs somewhere but is not in the shared repository. Primary is already at 189 and is NOT waiting on the push; it is the repository copy that is stranded.

---

## NEXT STEP (exactly one)

**Build RECOVER-1's permanent guard**, and decide its shape first: either give `check_database_parity.ps1` a read-only Primary connection so it reads the ledger itself, or add a repository check that FAILS when no dated Primary reading exists for the current HEAD. Until one exists, the class that cost this session four orphaned migrations can recur silently — and it is the only finding here whose absence of a guard is itself the defect. Batch-6's remaining tables come after it.
