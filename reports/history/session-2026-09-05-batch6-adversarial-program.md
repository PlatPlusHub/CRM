# ORVION — Batch 6 becomes an adversarial programme, and the first thing it attacked was itself

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-05
Author: Claude Opus 5
Status: **COMPLETE — one migration (`202607061200`), deployed to Primary and parity-verified on all three surfaces. Closed-vocabulary attack taxonomy, a measurement-based slice selector, Check 24, and slice 2 executed under the new loop. Repository = GitHub = local = Primary at 201 migrations. Batch 6 remains explicitly NOT COMPLETE at 3 of 77.**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED, verified before touching anything.** HEAD `22f302e` = `origin/main` (0/0), clean tree, 200 migrations on all three surfaces, guard CLEAN 1–23, Batch 6 at 2 of 77.
- **PROVEN (behavioural evidence, this session):** 201 migrations apply clean from scratch; pgTAP **102 files / 1520 assertions PASS** (was 101/1497); consistency **CLEAN 1–24**; **Primary parity PROVEN on all three surfaces, values READ FROM Primary** — ledger `9f574e3bb3080400047533e6c33b97b3` (201), functions `25d0575a7a85c95f826958b7c57b7722` (277), structure `d339ae18c6cf10d030b3c0158bb009fe` (3,539). Both defects were **reproduced before repair**, and the capability trigger's necessity is proven by injection, not by assumption.
- **UNPROVEN, and not claimed:** the six HTTP suites were **not re-run** — no HTTP script references `financial_accounts` or either revoked helper (grepped), so 430 is carried as inherited. **No concurrency claim is made for `financial_accounts`**: CONCURRENCY is declared `N/A` with a stated reason, not tested and passed. Check 24 cannot judge whether declared classes were attacked *well*. **74 surfaces have no recorded disposition.**
- **CHANGED:** `202607061200`; `102_financial_account_identity_and_definer_surface_test.sql` (new, 23); `101_...` (ATTACK-CLASSES header, retrospective, no assertions added); `scripts/batch6_select_target.ps1` (new); `check_repository_consistency.ps1` (Check 24); `MASTER_EXECUTION_PLAN.md` (the adversarial loop + taxonomy + selection rule); `MASTER_SURFACE_DISPOSITION.md`; `MASTER_GAP_REGISTER.md` (FA-1, FA-2, SECDEF-1, ADV-1); `MASTER_REPOSITORY_HEALTH.md` (Docs-24); `manifest.md`; ledger evidence; `ai-map.json`; `reports/README.md`. **`MASTER_API_CONTRACT.md` was regenerated and did NOT change** — the revokes are on `app`-schema functions PostgREST never exposed, and no table grant moved.
- **REMAINING:** **MAIL-1** (owner, untouched). **FA-2** (owner/canon: may an account receive a foreign-currency payment). **74 surfaces** at `NOT-RECORDED`.
- **DO NOT TOUCH:** do not make `batch6_select_target.ps1` a CI gate or let it store its ranking — it has no verdict to give, and a stored ranking is the second source of truth §18 forbids. Do not add columns to `MASTER_SURFACE_DISPOSITION.md`; the attack classes live in the test file beside the assertions that earn them, deliberately. Do not "fix" FA-2 by making payment currency match account currency — that is a business rule canon does not state. Do not re-grant `authenticated` EXECUTE on `app.document_retention_days` or `app.subscription_allows_write` without first adding `eligible_lead_handlers`' refusal clause; test 102 asserts that as a class and will fail closed.
- **NEXT:** §9.

---

## 1. RESEARCH, AND WHAT IT ACTUALLY CHANGED

Two authoritative sources were read and both produced a testable property rather than a slogan.

**PostgreSQL 17, "Writing SECURITY DEFINER Functions Safely"** — the risk is `search_path`, the
temporary schema is searched first and is writable by anyone, and the mitigation is `SET search_path`
with `pg_temp` **last**. Measured against ORVION: **zero** SECURITY DEFINER functions lack a pinned
`search_path`, and ORVION pins it **empty**, which is stronger than the documented advice because an
empty path does not search `pg_temp` at all. That is a control found strong, and it is now pinned by
assertion rather than left as a habit.

**PostgreSQL 17, Row Security Policies** — table owners bypass RLS unless `FORCE ROW LEVEL SECURITY`
is set. Measured: **all 77 tables enable RLS and none forces it**, and every table is owned by the
role that owns the functions. Therefore **all 83 SECURITY DEFINER functions run with RLS entirely
bypassed.** That is correct and load-bearing — the system paths exist to cross tenants — and it is
exactly why a *caller-supplied* `p_tenant_id` inside one is a cross-tenant door by construction.
**That single sentence is what produced SECDEF-1**, and no amount of grepping for defects would have.

The same page's referential-integrity caveat (unique and FK checks bypass RLS, creating a covert
channel) was chased and **found not to apply**: every tenant-scoped unique constraint in ORVION is
tenant-prefixed except `booking_item_passengers (booking_item_id, passenger_id)`, whose both columns
carry tenant-composite FKs — so a foreign id cannot be referenced in the first place. Recorded as a
non-finding rather than left as an open worry.

**OWASP WSTG** supplied the *taxonomy shape* — authorization testing as horizontal escalation,
vertical escalation, bypassing the authorization schema, and insecure direct object references — and
was **deliberately not imported**. WSTG's categories are written for HTTP applications; ORVION's
trust boundary is a database with RLS, capability triggers and RPC/table dual doors. The ten classes
adopted keep WSTG's *intent* (attack the control, separate horizontal from vertical, treat object
references as attacker-controlled) in ORVION's own vocabulary, so a finding maps to a register id
rather than to a external clause number nobody here can act on.

---

## 2. WHAT WAS BUILT, AND WHAT WAS DELIBERATELY NOT

**Extended, not replaced:** the standing method in `MASTER_EXECUTION_PLAN.md` — which already said
DISCOVER → CLASSIFY → ADVERSARIALLY TEST → REPAIR → RETEST → RECONCILE → DOCUMENT → GUARD — gained
the explicit loop, the **closed ten-class taxonomy**, the three self-enforcing rules (PAR-4
injection, TEST-3's closing move, "a control found strong is pinned"), and the selection rule. No new
governance document, no new authority, no new SSOT.

**Where the taxonomy lives, and why not in the Master.** The brief's §17 asked for per-surface class
visibility; §20 forbade adding columns without demonstrating the boundary is insufficient. It is not
insufficient: the classes are declared on an `-- ATTACK-CLASSES:` line **in the test file, beside the
assertions that earn them**, and the disposition row's `Session` pointer reaches them in one hop. A
seventh column would have restated, in a hand-maintained Master, something that is only true because
of what a test file contains — the restated-fact class this repository guarded as STALE-1 two days
ago.

**`scripts/batch6_select_target.ps1`** ranks by exposure minus coverage and **stores nothing**. Its
constraints are written into its own header: not a CI gate, no verdict, and a low score is never
evidence of safety. Every number is recomputed from the live catalog and the test files per run, so
there is no artifact to go stale and no second truth about a surface.

**Rejected:** a stored risk register (a second SSOT); a seventh disposition column; importing WSTG's
categories verbatim; adding `EXHAUSTIVE` to the assurance vocabulary; and a guard for every item in
the brief's §21 list — three were built (ADV-1 here, DISP-1 and HANDOFF-1 last session) and the rest
would have measured ceremony rather than truth.

---

## 3. SLICE 2, CHOSEN BY THE SELECTOR

The selector ranked `financial_accounts` first among 75: a `numeric(19,4)` money column, two direct
write grants to `authenticated`, **zero RPCs**, and two pgTAP files naming it of which one had any
negative assertion. Slice 1's rule — "the tables no test names" — could not have chosen a third
slice. This one can choose a seventy-fifth.

**Controls found STRONG, and pinned rather than merely enjoyed:**

* **DOOR.** No function anywhere writes the table. The table door is not a bypass of an intended RPC
  door — it *is* the door (SEC-2's ratified reading), so RLS plus the capability trigger are the
  complete layer. Pinned, so the day an RPC appears this file fails instead of quietly under-testing.
* **AUTH.** `app.guard_write_capability` charges `CREATE_JOURNAL_ENTRY` on **INSERT and UPDATE** —
  SEC-1c was an entire package about tables guarded on one verb only, so each verb is denied
  separately with a control proving the employee genuinely lacks the permission.
* **TENANT.** Both directions hold, including the **row-hop** — an owner moving their own account
  into another tenant by UPDATE, which RLS `WITH CHECK` refuses because it judges the row *after*
  the update. A third assertion proves the rival's account is invisible, so the two refusals are
  refusals and not accidents of an empty table.

**FA-1 (Medium), reproduced then fixed.** Canon 31 calls these "bank and cash accounts": currency and
kind are the account's *identity*. `payments` carries a tenant-composite FK into the table, so money
is routed *into* an account — and a holder of `CREATE_JOURNAL_ENTRY` could switch that account from
EGP to USD, or bank to cash, afterwards. Every payment already recorded silently changes meaning,
with no event and an `updated_at` that says only that *something* moved.

The freeze is **conditional and that is the whole design**: an unused account is a typo someone may
fix, a used one is history someone must not rewrite. `SECURITY DEFINER` is **required rather than
tidy** — the trigger must see payments the caller cannot, or the guard would be weakest for the
callers with the narrowest visibility.

**FA-2, recorded and NOT fixed.** Nothing requires a payment's currency to match its account's. That
is a business rule canon does not state, and inventing one because an attack exposed the ambiguity is
what the standing method forbids. FA-1 does not answer it in either direction.

---

## 4. SECDEF-1 — THE CROSS-CUTTING FINDING

Four SECURITY DEFINER functions reachable by `authenticated` take a caller-supplied tenant. **Two
already refused a foreign tenant** — `app.record_event` and `app.eligible_lead_handlers`, whose own
comment says exposure without the check "would let any signed-in user enumerate any tenant's staff".
Two did not: `app.document_retention_days` (any tenant's retention configuration) and
`app.subscription_allows_write` (whether any agency's subscription is in good standing — commercial
intelligence about a competitor). Neither had a `public` wrapper, so neither was reachable over HTTP.
That is a mitigation, not the fix.

**Revoked rather than guarded, and only after measuring.** The obvious repair was to copy the tenant
check into both. Measured first: no policy, CHECK, view or index references either;
`document_retention_days` has **zero callers anywhere**; and every caller of
`subscription_allows_write` is itself SECURITY DEFINER and executes as the owner without consulting
`authenticated`'s grant. The grant was never needed. Removing a door is smaller and more complete
than adding a lock to it, and it is `202607056100`'s ratified answer for this class.

The guard is a **class**, not two instances: test 102 asserts that no SECURITY DEFINER function
reachable by `authenticated` takes a tenant argument without comparing it to the session's own — so a
new one fails closed.

---

## 5. FAILED ATTEMPTS — SIX, ALL RECORDED

1. **`app.forbid_used_account_redenomination` shipped without revoking PUBLIC EXECUTE.** Caught on
   the first run by `10_grant_model_test.sql`, which exists for GRANT-1 (`pg_default_acl` grants
   EXECUTE to PUBLIC on every new function). An existing guard doing exactly its job on a brand-new
   function. Every future `app.*` function needs the revoke in the same migration.
2. **The new test charged its own fixture `CREATE_CUSTOMER`.** `reset role` was not enough:
   `app.guard_write_capability` resolves the actor from `request.jwt.claims`, **never from the
   database role**, so the owner path was still being charged. Clearing the claims is what returns a
   session to the system path.
3. **PowerShell here-strings ate the backticks in a SQL comment.** Writing `` `app.x` `` inside a
   double-quoted `@"…"@` turned `` `a `` into BEL and `` `r `` into CR, corrupting the file into a
   syntax error at a line number that pointed nowhere near the cause. Then `ReadAllLines` split on
   the embedded CR and my line-indexed repair overwrote the wrong lines, producing two orphan lines
   and a second syntax error. **Never build SQL or Markdown containing backticks in a PowerShell
   double-quoted string** — use single quotes, a here-doc, or the file-editing tools.
4. **The catalog guard's error code was assumed.** `app.enforce_catalog_codes` raises
   `check_violation` (23514), not the plpgsql default P0001, deliberately so a catalog refusal is
   indistinguishable from a CHECK constraint to any caller. Assumed P0001; the test said otherwise.
5. **The injection assertion was placed last and was never counted.** The file printed
   `planned 22 but ran 21` **while reporting PASS** — TEST-3's exact shape, in a session that had
   already written TEST-3's lesson into slice 1. The closing re-assertion after the rollback is what
   makes an injection countable.
6. **The first attempt at SECDEF-1 was going to add tenant checks to both functions.** It was
   abandoned before implementation once the caller analysis showed the grant itself was unnecessary
   — the more invasive fix would have shipped a check on a path nothing traverses, and left the
   unnecessary grant in place.

Items 1, 2, 4 and 5 were each caught by a guard or a test that already existed. That is the loop
working: **four of six failures cost minutes because something was already measuring them.**

---

## 6. THE GUARDS WERE ATTACKED TOO

Check 24 was mutation-tested in both directions before being trusted:

| Mutation | Expected | Result |
|---|---|---|
| `ADVERSARIAL` on a surface no test names | flag | flagged |
| `ADVERSARIAL` on a surface whose test has no `ATTACK-CLASSES` line | flag | flagged |
| `ADVERSARIAL` on a surface whose declaring file has no `throws_ok` | flag | flagged |
| A misspelled class in any test file | flag | flagged |
| Untouched repository | pass | passed |

Its ceiling is stated in the check and in `§2b`: it measures that declared evidence *exists*, never
that the attack was any good.

---

## 7. VERIFICATION

| Gate | Result |
|---|---|
| `npx supabase db reset` | **201** migrations apply cleanly from scratch |
| `npx supabase test db` | **102 files / 1520 assertions — All tests successful** (was 101/1497) |
| `check_repository_consistency.ps1` | **CLEAN, Checks 1–24** |
| `check_database_parity.ps1` + three Primary values | ledger, function surface and structural surface **all match**; contract regenerated and matches live |
| `generate-api-contract.ps1` | 75 endpoints, unchanged — the migration adds no endpoint and revokes only `app`-schema EXECUTE, which PostgREST never saw |
| six HTTP suites | **NOT RE-RUN.** Safe by measurement: no HTTP script references `financial_accounts` or either revoked helper |
| `batch6_select_target.ps1` | ranks 75 candidates; `financial_accounts` first at score 1 |

**Primary values were READ FROM PRIMARY** via the `supabase-primary` MCP using the same
`scripts/parity_surface.sql` both sides run (GUARD-1); the refreshed ledger evidence's recomputed
fingerprint was checked equal to the one Primary returned.

---

## 8. WHAT BATCH 6 MAY AND MAY NOT CLAIM

Unchanged and restated because the classification is the point: ORVION is **TESTED** and
**SUBSTANTIALLY ADVERSARIALLY TESTED**. It is **NOT exhaustively adversarially audited**, and
`EXHAUSTIVE` is deliberately absent from the per-surface vocabulary so the strongest claim in the
repository can never be assembled one table at a time. Three surfaces of 77 carry a recorded
disposition. That number moves only with evidence.

---

## 9. NEXT

**Batch 6 slice 3.** Run `pwsh -File scripts/batch6_select_target.ps1`, take the top row, and execute
the loop in `MASTER_EXECUTION_PLAN.md`'s Batch 6 section unchanged. At the time of writing the
selector's next candidates are `company_assets` and `booking_item_passengers` — but **re-run it
rather than trusting this sentence**: the ranking is recomputed from live state and slice 2 has
already changed the inputs.

Unchanged: **DELIV-1** remains the cheapest non-Batch-6 engineering item; **MAIL-1** the only owner
decision blocking anything; and the **n8n tracks stay uncoupled from Batch 6** — offline conversion
can proceed now, notification dispatch can be built against its stable contract now, and only the
send node waits on MAIL-1.

End of report.
