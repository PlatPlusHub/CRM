# ORVION — Batch 6 slice 3: an asset register, and the money rule that had never once been true

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-06
Author: Claude Opus 5
Status: **COMPLETE — one migration (`202607061300`), deployed to Primary and parity-verified on all three surfaces. Repository = GitHub = local = Primary at 202 migrations. Batch 6 remains explicitly NOT COMPLETE at 4 of 77.**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED, verified before touching anything.** HEAD `17b0396` = `origin/main` (0 ahead / 0 behind), clean tree, 201 migrations, 102 test files, guard CLEAN 1–24, Batch 6 at 3 of 77. The selector was **re-run rather than trusted**: it returned `company_assets` (score −1), which is what the previous report predicted — but the prediction was not the evidence, the run was.
- **PROVEN (behavioural evidence, this session):** 202 migrations apply clean from scratch; pgTAP **103 files / 1560 assertions, Pass A = Pass B** (was 102/1520); **all six HTTP suites re-run, 430 passed / 0 failed**; smoke `ALL CHECKS PASSED (77 tables)`; consistency **CLEAN 1–24**; **Primary parity PROVEN on all three surfaces, values READ FROM Primary** — ledger `c6398307872fcfb9e2a9752cec6edc9d` (202), functions `25d0575a7a85c95f826958b7c57b7722` (277), structure `2fb356c9f9ebe30ff3e24f17bd53548c` (3,561). Every defect was **reproduced before repair**, three of them **through the real PostgREST door with a real employee JWT**, and the NaN repair is proven by **defect injection** plus **four mutations** of the new class assertions.
- **UNPROVEN, and not claimed:** the class ceiling in assertion 31 reads constraint **text**, so it proves a rule is declared, never that it fires — assertions 6 and 30 are what prove that, and the ceiling says so in its own message. **No claim is made that NaN was the only such value**: `Infinity` was measured and is rejected by `numeric(19,4)` on precision, but that is a property of the typed columns, not of the constraints. Only `company_assets` and `payments` were probed over HTTP; the other 17 tables' constraints are LOCAL RUNTIME + PRIMARY structural evidence. **73 surfaces have no recorded disposition.**
- **CHANGED:** `202607061300` (new); `103_company_asset_and_numeric_integrity_surface_test.sql` (new, 40 assertions); `MASTER_GAP_REGISTER.md` (MONEY-1, MONEY-2, CA-1, CA-2, CDM-3); `MASTER_SURFACE_DISPOSITION.md` (3 → 4 of 77); `MASTER_EXECUTION_PLAN.md` (header, EC-1 count, a **fourth** self-enforcing rule); `manifest.md`; ledger evidence; `ai-map.json`; `reports/README.md`. **`MASTER_API_CONTRACT.md` regenerated and unchanged** — no grant, RPC or view moved; only constraints were added.
- **REMAINING:** **MAIL-1** (owner, untouched). **FA-2** (owner/canon, untouched). **MONEY-2** (new, open): three money columns still carry no non-negative rule, deferred to their own slices. **73 surfaces** at `NOT-RECORDED`.
- **DO NOT TOUCH:** do not "complete" MONEY-1 by adding `>= 0` to `financial_accounts.opening_balance` — a bank account opening overdrawn is an ordinary banking fact and canon says nothing; that is MONEY-2 and it is deliberately open. Do not rewrite the existing non-negative CHECKs to fold the NaN clause in: they are separate constraints on purpose, because each existing one was earned by a finding and editing a control is how a control quietly loses a clause. Do not weaken `company_assets_purchase_currency_pairing` to a one-way implication. Do not add a catalog family to `company_assets.status` or `asset_type` — CAT-6 is open and inventing a vocabulary fabricates canon.
- **NEXT:** §8.

---

## 1. PREFLIGHT AND SELECTION

The boot sequence was executed against the repository, not against the previous report: `git rev-parse` on both refs, `ls` on the migration and test directories, and a full read of `AGENTS.md`, `README.md`, `manifest.md`, `reports/README.md`, the disposition record and the plan's Batch 6 section.

`pwsh -File scripts/batch6_select_target.ps1` was then run and its **current** output used:

| Surface | Score | Exposure | Coverage | Money | Direct | Tests | Negative |
|---|---|---|---|---|---|---|---|
| `company_assets` | **−1** | 7 | 8 | 1 | 2 | 2 | 1 |
| `booking_item_passengers` | −2 | 10 | 12 | 1 | 2 | 2 | 2 |
| `languages` | −4 | 0 | 4 | 0 | 0 | 2 | 0 |

**Does the ranking expose a weakness in the selector?** One, and it is worth stating: `company_assets` scored `money=1` from a single column and `direct=2` from the write grant, and that is the whole reason it rose — the selector cannot see that the money column had **no constraint at all**, because it counts *columns*, not *rules*. It ranked the right surface for a reason weaker than the one that turned out to matter. That is acceptable for a prioritiser and is not fixed here: adding constraint-awareness would make the selector a second opinion about what is safe, which `MASTER_EXECUTION_PLAN.md` explicitly forbids it from becoming.

---

## 2. THE SURFACE, AND WHAT IT ACTUALLY IS

`company_assets` — 10 columns, `numeric(19,4) purchase_amount` and `text currency_code` both nullable, `text asset_type` and `text status` with no catalog family (CAT-6, open by ratified decision). Measured from the live catalog, not read from canon:

- **No RPC writes it. No view reads it. No function names it except `app.guard_write_capability`.** The table door **is** the door — SEC-2's shape.
- `authenticated` holds **SELECT, INSERT, UPDATE and no DELETE**. So the missing DELETE arm on the capability trigger is not a gap: there is nothing to charge, and assertion 26 proves the refusal happens at the grant.
- Three triggers: `moddatetime`, `enforce_subscription_write_gate` (INSERT/UPDATE/**DELETE**), `guard_write_capability` (INSERT/UPDATE) charging `CREATE_JOURNAL_ENTRY` — held by `owner`, `ceo`, `finance_manager` only.
- One policy, `tenant_isolation`, `FOR ALL`, with both `USING` and `WITH CHECK`.
- `company_asset_created` is registered event vocabulary with **zero producers** — EVT-2's class, which the owner ratified under OWNER-1 as *"no producer invented to complete a catalog"*. Nothing to fix; assertion 36 pins it so a producer cannot arrive untested.

---

## 3. THE PROBE THAT LIED, AND WHY IT IS RECORDED FIRST

The first attack script wrapped each attempt in `rollback to savepoint` and reported that a tenant-A finance manager could **insert into the rival tenant, read the rival's asset, update it, row-hop into it, and DELETE** — five catastrophic isolation failures.

All five were false. `SET LOCAL ROLE` is undone by subtransaction abort, and the savepoint had been taken **before** the role was set, so every block after the first ran as `postgres`, for which RLS does not apply and DELETE is granted. The probe was measuring the superuser and printing it as the employee.

It is recorded first because it is the exact failure `§20` names — *can a fixture accidentally make a tenant-isolation test meaningless?* — and because the fix generalises: the corrected script re-establishes the role **and prints `current_user` and `app.current_tenant_id()` before every single attack**, so the transcript carries its own proof of who was acting. Every result in §4 comes from the corrected run.

---

## 4. CONTROLS FOUND STRONG — the majority of the slice

Recorded because proving an existing control works is a better outcome than adding another one, and each is now pinned by an assertion rather than left as a habit.

| Attack | Result |
|---|---|
| Cross-tenant INSERT (`tenant_id` = rival) | refused, `42501` — the `WITH CHECK` half |
| Cross-tenant SELECT of a row **proven to exist** | 0 rows; the tenant sees exactly its own 3 |
| Cross-tenant UPDATE (existence probe) | 0 rows, **no error** — no existence leak either way |
| Row-hop: move my own row into the rival tenant | refused, `42501` |
| DELETE as `authenticated` | refused at the **grant**, before any policy |
| `anon` SELECT | refused at the grant |
| Trainee INSERT **and** UPDATE | refused, `42501` (SEC-1c's both-sides rule holds here) |
| `finance_manager` **without** `aal2` | `has_permission` returns **true** and `app.authorize` refuses anyway — two independent gates |
| Explicit user **DENY** over a role grant | refused — `deny > user grant > role grant` proven on this door |
| Role assignment with `starts_at` in the future | refused — `202607060700` holds here |
| Subscription `cancelled` | refused by the write gate, with reads left open |
| JWT with **no `sub`** | reaches `guard_write_capability`'s `auth.uid() is null` system branch — **and RLS refuses it anyway**, because `current_tenant_id()` is NULL. The bypass is real and a second control closes it |
| Unregistered currency `XXX` | refused by the FK, `23503` |
| `10^16` into `numeric(19,4)` | refused, `22003` |

**Two live-session races** (pgTAP is single-session and cannot express these):

- **Concurrent inserts, one legal and one NaN, committing together** — only the legal row survived. A row-level CHECK cannot be raced.
- **A role revoked by a second session while a write transaction was open** — the writer's *next* statement was refused, and its earlier, legitimately-authorized insert rolled back with it. Final state: zero rows. `has_permission` is resolved live with no session cache, so revocation binds on the next statement **under READ COMMITTED**, which is what PostgREST uses. This is the property ADR-0027 asserted in prose; it is now behaviour.

---

## 5. WHAT GAVE

### MONEY-1 — found by attacking the repair, not the schema (High)

The draft fix for `purchase_amount` was `check (purchase_amount >= 0)`, copied from the fifteen money columns that already carry it. Before trusting it, the *constraint* was probed:

```
select 'NaN'::numeric >= 0;   -->  t
```

PostgreSQL defines `numeric` NaN as **greater than every non-NaN value**, so it can be sorted and indexed. Consequence: **every `>= 0` and `> 0` money CHECK in this repository had always admitted NaN** — payments, refunds, invoices, journal entry lines, payment allocations, booking items, both credit ceilings, and the six CDM-2 added the day before. Measured: **0 of 32** numeric columns on `public` base tables excluded it. `Infinity` is a separate PostgreSQL 14+ numeric value and is rejected by `numeric(19,4)` on precision — checked, not assumed.

**Reachable through the real door.** A `finance_manager` JWT POSTing to `/rest/v1/company_assets`:

| Body | Before | After |
|---|---|---|
| `"purchase_amount":"NaN"` | **201**, row returns `"NaN"` | **400** `23514` |
| `"purchase_amount":-500000` | **201** | **400** `23514` |
| `"purchase_amount":123456` (no currency) | **201** | **400** `23514` |

**Impact reproduced on the financial core**, not argued from the property: an `authenticated` insert of `payments.amount = 'NaN'` made `reporting.customer_outstanding.outstanding_balance` return **NaN**. `sum`, `avg` and `max` all propagate it, and the credit ceilings compare against exactly that sum — `NaN > threshold` is TRUE, so a ceiling fires on a figure nobody can read. Tenant-scoped by RLS, so it is self-inflicted rather than a cross-tenant attack; that bounds the blast radius, not the corruption.

**Repair.** 19 tables gain a **second, separate** constraint saying only *a stored number is a number*, written `is distinct from 'NaN'::numeric` — NULL stays legal (canon marks the measures nullable), NaN does not. **No existing CHECK was edited**: each was earned by a finding, and editing a control to insert a clause is how a control quietly loses one. Written out per table rather than generated by a catalog loop, so the list is reviewable and assertion 31 can count it.

**CHECK rather than trigger, and this is the door answer.** A trigger or a policy can be bypassed by the table owner. Assertion 30 proves the NaN refusal holds **as `postgres`**, with RLS and every capability trigger out of the picture.

### CA-1 — an asset bought for a negative amount (Medium)

`purchase_amount` carried no constraint while 15 of 19 money columns did. Canon 24 defines the entity as a company-owned asset; canon 31 gives it `purchase_amount` — what was paid. Negative is not a discount. CUST-4's ratified precedent, applied conditionally because canon marks the column nullable, with negative controls proving an asset with no price and an asset costing zero both remain legal.

### CA-2 / CDM-3 — an amount denominated in nothing (Medium)

`202607059900` (SUP-4a) established canon 30's money standard in its conditional form: the currency is present exactly when the amount is. **Five** public tables have a nullable `currency_code` beside a numeric amount; **three** carried the pairing (`customers`, `suppliers`, `offline_conversions`) and two did not.

One of the two was `campaign_daily_metrics` — **which this programme audited eight assertions deep in slice 1 and marked `AUDITED`**. Slice 1 checked *sign* (CDM-2, six non-negative CHECKs) and never checked *denomination*, because CUST-4 was the precedent in mind and SUP-4a was not. That is **CDM-3**, and it has an id rather than a quiet fix because a disposition is a claim about what was assessed. The row keeps `AUDITED` and gains the finding.

---

## 6. WHAT WAS DELIBERATELY NOT FIXED

- **MONEY-2 (new, open).** `financial_accounts.opening_balance`, `quotations.total_amount` and `quotation_items.total_amount` got the NaN rule and **nothing else**. The two rules differ in kind: *"this holds a number"* has no business content, *"this is never below zero"* is a claim about overdrafts and about whether a quotation may total negative. Canon states neither, and an account opening overdrawn is an ordinary banking fact — so the CUST-4 precedent must not be applied by pattern-match. Deferred to each column's own slice.
- **Empty-string `name` / `asset_type` / `status`.** All three are storable as `''`. Measured first: ORVION's only non-empty CHECKs are on **normalised identity** columns (email, phone, `customer_identity_signals.value`, `customer_contact_methods.value`). There is no general non-empty convention, so adding one to a single table would be inventing a convention rather than applying one.
- **`created_at` and the primary key are rewritable by UPDATE.** Measured across the schema: **7 of 65** base tables with `created_at` protect it, all of them append-only or first-touch by canon (`events`, `security_events`, `exchange_rate_adjustments`, `lead_assignments`, `conversation_messages`, `leads`, `offline_conversions`). An asset register is none of those. Recording it as a company_assets defect would misattribute a schema-wide property to one table.
- **Duplicate assets.** Two identical rows are legitimate — an agency may own two identical vehicles bought the same day. Canon names no natural key and a repeat produces no economic effect (canon 24 puts depreciation out of scope). Declared `REPLAY=N/A` with that reason, not with silence.
- **`company_asset_created` has no producer.** EVT-2, ratified by the owner under OWNER-1. Pinned by assertion, not invented.

---

## 7. VERIFICATION, AND ATTACKING THE TESTS

`§5a` executed in order, every step's real output recorded:

| Step | Result |
|---|---|
| `npx supabase db reset` | 202 migrations apply clean from scratch |
| Pass A `npx supabase test db` | **103 files / 1560 assertions — All tests successful** |
| Six HTTP suites | 29 + 107 + 74 + 120 + 40 + 60 = **430 passed, 0 failed** |
| Pass B (no reset, over the HTTP residue) | **103 / 1560 — identical to Pass A** |
| Smoke `verify_database.sql` | `ALL CHECKS PASSED (77 tables, …)` |
| Primary, read FROM Primary | ledger `c6398307872fcfb9e2a9752cec6edc9d` (202) · functions `25d0575a7a85c95f826958b7c57b7722` (277) · structure `2fb356c9f9ebe30ff3e24f17bd53548c` (3,561) |
| `check_database_parity.ps1` | **CLEAN** on all three |
| `generate-api-contract.ps1` | regenerated, **unchanged** (75 endpoints) |
| `check_repository_consistency.ps1` | **CLEAN, Checks 1–24** |

**The HTTP suites were re-run, and that was not ceremony.** `202607061300` constrains `payments`, `invoices`, `refunds`, `booking_items`, `quotations`, `quotation_items`, `journal_entry_lines`, `payment_allocations`, `customers` and `suppliers` — the exact tables the six journeys write. Carrying 430 as inherited (as slice 2 legitimately did) would have been unsafe here.

**Cross-path sweep (`§5b`).** Exactly one SECURITY DEFINER batch writes a constrained table: `app.map_outcomes_to_conversions`, whose set-based INSERT would abort for *every* tenant if one row violated a constraint — the WP-03 class. Traced: its `conv_value` is `payments.amount`, which is itself now NaN-constrained, so a NaN can no longer reach the batch. Upstream protection, not luck; and Primary holds zero business rows, so no legacy NaN exists to trip it.

**The tests were attacked (`§20`), four mutations, both directions:**

| Mutation | Detected? |
|---|---|
| Drop `payments_no_nan_check` — a **different table's** coverage | **FAIL** (assertion 31 is not self-satisfying) |
| Drop `campaign_daily_metrics_amount_currency_pairing` | **FAIL** (assertion 32) |
| `grant execute on app.guard_write_capability() to authenticated` | **FAIL** (assertion 29) |
| Add a unique constraint to `company_assets` | **FAIL** (assertion 33's concurrency basis) |
| Untouched tree | **PASS** |

Plus the **PAR-4 defect injection** inside the file itself: drop `company_assets_no_nan_check`, prove the original NaN insert succeeds again, roll back, and **re-assert the refusal after the rollback** — TEST-3, which this programme has already been caught by once.

---

## 8. NEXT STEP (exactly one)

**Batch 6 slice 4.** Run `pwsh -File scripts/batch6_select_target.ps1`, take the top row, and execute the loop in `MASTER_EXECUTION_PLAN.md`'s Batch 6 section unchanged — including its **fourth** rule, added by this slice: *attack the repair you are about to write, before you write it, against the engine's own documented semantics.* Slice 3's draft fix was correct-looking, precedented, and had never worked.

**Re-run the selector rather than trusting a candidate written here.** Slice 3 changed the inputs for every table it constrained, and `company_assets` has left the pool.

n8n stays uncoupled: the offline-conversion work and the notification dispatcher are unblocked by this session and unaffected by it; only the send node waits on MAIL-1.
