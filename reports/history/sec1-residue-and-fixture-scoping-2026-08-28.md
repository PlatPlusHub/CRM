# ORVION — SEC-1's Residue Was Three Different Problems, and the Suite Was Lying by Luck

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migration `202607056100`, test `58_write_grants_and_config_capability_test.sql`, `57` (map
pin moved), `10` (ceilings), and a suite-wide fixture-scoping fix across eleven test files.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `40de857` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Starting state, re-proven live before anything was touched

| Axis | Evidence |
|---|---|
| GitHub | `gh api …/commits/main` = `40de8577518a…` = local HEAD; `ls-remote` agrees; tree clean |
| Repository | 149 migrations, 57 test files |
| Local + Primary | 149 migrations, fingerprint `c76d13a17ce0bf6dcb9888ba741e3b39` on both and on the repo |

Everything matched the previous report **except the test suite**, which did not.

---

## 2. The first discovery was drift, and it came from re-running rather than re-reading

The previous session recorded 57 files / 646 assertions / 0 failures. Re-running produced **646 / 2
failures**, both in `38_class_a_events_test`:

```
not ok 9  - a DIRECT allocation insert on the SYSTEM path succeeds
#   died: 23503: payment_allocations_invoice_id_fkey
#   Key (tenant_id, invoice_id)=(38…0001, b922b8b1-…) is not present in table "invoices"
not ok 10 - ...and ALSO emits its event      have: 1   want: 2
```

The fixture read:

```sql
insert into public.payment_allocations (...)
select '38000000-…-0001', p.id, i.id, 100, 'EGP'
  from public.payments p, public.invoices i limit 1
```

An **unscoped cross join**, executed under `reset role` — as `postgres`, with RLS off — so it saw
every tenant's rows and paired this fixture's payment with an invoice belonging to
`role-journey`, the tenant `scripts/verify_role_journeys.ps1` leaves behind by design (the audit
spine is append-only; its fixture cannot be torn down). The composite FK `(tenant_id, invoice_id)`
then did exactly its job.

**The code was correct both times. The fixture was measuring the wrong thing** — and the same file
already carried a comment saying precisely that about its *event counts*, corrected in an earlier
session. The lesson had been learned for assertions and not for fixtures.

### The class, searched rather than the instance

A scan of all 58 test files for subqueries that select a fixture row by a **non-unique attribute**
with no tenant predicate found **40+ sites across eleven files** (17, 19, 24, 34, 37, 38, 39, 46,
49, 52). They survive only while two accidents hold: the actor is `authenticated` so RLS bounds
them, and the fixture happens to be the only match. Under `reset role` neither holds; after any HTTP
suite runs, the second stops holding too.

All are now scoped to their own fixture's `tenant_id` (or `auth_user_id` for `trusted_devices`, or
the two fixture tenants for `49`). Reference lookups — `catalog_values`, `countries`, `roles`,
`subscription_plans` — were deliberately left alone: those tables are global and uniquely keyed, so
they carry no such dependency, and scoping them would have been noise.

**The fix is verified by regime, not by a green run.** Running pgTAP only against a clean database is
what let this class live. The suite is now re-run in both states.

---

## 3. SEC-1's thirteen: counting them was itself the mistake

The previous report classified the residue into three groups and left all thirteen open pending an
owner decision. Investigating each table individually — who writes it, who reads it, whether any
path depends on the grant, whether canon decides it elsewhere — showed the three groups needed
**opposite actions**, and that only one of them needed the owner at all.

### Group 1 — five system-owned tables: the grant had no writer

| table | writers | executable by |
|---|---|---|
| `attribution_clicks` | `app.capture_attribution_click` (definer) | `orvion_integration` |
| `notifications` | `app.process_lead_sla` (definer) | `service_role` |
| `offline_conversion_deliveries` | `claim_conversion_deliveries`, `record_conversion_delivery_result` (definer) | `orvion_integration` |
| `notification_deliveries` | **nothing at all** | — |
| `usage_counters` | **nothing at all** | — |

A SECURITY DEFINER function runs as its owner, so the `authenticated` table grant is **not** what
makes those paths work. It was a second door that only direct DML used. Revoking it therefore cannot
break a legitimate write — it removes forged marketing clicks, forged notifications, forged delivery
records and hand-edited usage meters.

That is the directive's own preference, and two independent facts confirm ORVION already treated
these as system-owned: three of the five sit on the subscription-write-gate **exemption list**
(`35_subscription_write_gate_test` §19–20), and canon 28 states outright that "`usage_counters` is
empty and counting is a separate additive mechanism."

**One deliberate exception.** `notifications` keeps a **column-level** `update (is_read, read_at)`.
Reading and dismissing your own notification is a real user act and there is no RPC that performs
it; revoking the whole UPDATE would have deleted a capability rather than closed a hole. The
owner-scoped policy already pins `target_user_id = current_user_id()`, so this cannot reach a
colleague's inbox. What it can no longer do is rewrite the title, body or subject of a notification
the system sent.

### Group 2 — four configuration tables: the permission was already in the codebase

These have **no writer at all**, so direct DML was the only path — and it was open to every tenant
user, a trainee included. The permission was read out of what ORVION already charges for the same
object, not chosen:

| table | permission | where it was read from |
|---|---|---|
| `branch_business_hours` | `MANAGE_BRANCHES` | `branches`, its parent, charges exactly this on INSERT and UPDATE |
| `holidays` | `MANAGE_BRANCHES` **or** `MANAGE_TENANT_SETTINGS` | `branch_id` is nullable — both readings resolve to {ceo, owner}, so the union widens nothing |
| `financial_accounts` | `CREATE_JOURNAL_ENTRY` | canon 33 migration 6 groups it with `chart_of_accounts`, which charges it |
| `company_assets` | `CREATE_JOURNAL_ENTRY` | canon 33 migration 12 groups it with the finance transaction tables |

`financial_accounts` is the one worth spelling out. `MANAGE_TENANT_SETTINGS` was the obvious guess
and it is **wrong**: it resolves to {ceo, owner}, which would have locked the finance manager out of
defining the bank accounts payments post against. Reading the sibling tables instead of guessing
produced `CREATE_JOURNAL_ENTRY` = {ceo, finance_manager, owner}, and the discomfort disappeared. The
evidence answered a question my intuition had answered wrongly.

### Group 3 — three tables that were never residue

Canon 34, § *Applying Principles 1, 6, and 7*:

> the authentication support tables (`trusted_devices`, `otp_challenges`, `totp_enrollments`) belong
> to the Human Identity … RLS for these tables is **simply row-ownership by `auth.uid()`**, with no
> tenant scoping.

Ownership **is** the capability, canon says so, and inventing a CRUD permission to make a metric
reach zero would contradict it. Classified INTENTIONAL, with the boundary now proven behaviourally
rather than trusted: a foreign-identity insert is refused, and a foreign-identity UPDATE changes
nothing — asserted **on the row**, because "no exception was raised" would have passed even if the
write had gone through.

### What is left: one table, and it is not a bypass

`lead_interactions`. `app.record_lead_interaction` is SECURITY INVOKER, granted to `authenticated`,
and authorizes nothing — so unlike every table `202607056000` fixed, the RPC and direct DML charge
**the same thing, which is nothing**. There is no bypass to close. Canon's lead permissions are
CREATE / ASSIGN / REASSIGN / CLOSE / VIEW_ASSIGNED and none covers logging an interaction. The open
question is whether logging should cost anything at all, and that is a business decision.

### A class sweep, so the answer is not just about the thirteen

The same query was run across the whole schema: every table `authenticated` may INSERT that has **no
SECURITY INVOKER writer**. It returned eighteen. Four more than the thirteen —
`campaign_daily_metrics`, `catalog_values`, `exchange_rates`, `exchange_rate_adjustments`,
`subscriptions`, `tenants` — and every one of them already requires a real write permission
(`MANAGE_MARKETING_CAMPAIGN`, `MANAGE_TENANT_SETTINGS`, `SET_EXCHANGE_RATE`,
`CREATE_EXCHANGE_RATE_ADJUSTMENT`, `MANAGE_SUBSCRIPTION`). The residue was exactly the thirteen and
no more.

---

## 4. A new finding the investigation produced: AUTH-1

Nothing in the database reads or writes `otp_challenges` or `totp_enrollments` — no function, no
trigger, no view, no report. Meanwhile `app.requires_mfa()` gates step-up on the JWT's `aal` claim,
which is **Supabase Auth's own** MFA state. `trusted_devices`, the third table in the same canon-34
group, is genuinely used by three RPCs and three event triggers; these two are not used by anything.

That is a duplicate source of truth waiting to happen: an implementer would reasonably assume ORVION
owns OTP and TOTP state when Supabase Auth does. Recorded as **AUTH-1, BLOCKED — ARCHITECTURAL
DECISION** rather than guessed, because "implement them" and "retire them" are both defensible and
the choice moves where authentication state lives.

---

## 5. Exposure

| ceiling | before | after |
|---|---|---|
| tables `authenticated` may INSERT | 59 | **54** |
| …with no capability **trigger** | 27 | **18** |
| …with **no capability enforcement of any kind** | 13 | **4** |

Of the four: three are INTENTIONAL by canon 34; one (`lead_interactions`) is open.

---

## 6. Tests

Suite **57 files / 646 assertions → 58 files / 672**, 0 failures.

`58_write_grants_and_config_capability_test.sql` (27) proves each group by the mechanism that
actually enforces it — the revoke at privilege level *and* the system path still open; the
column-level UPDATE from both sides; each config table denied to a trainee and permitted to an owner
**on the same table**; the auth-artifact boundary on the row rather than on the absence of an error.

`57` gave up its map-completeness pin to `58` rather than keeping a second copy, which would only
have given the two somewhere to disagree. `10`'s three ceilings now read 54 / 18 / 4.

| What failed first | Cause | Resolution |
|---|---|---|
| `38` assertions 9–10 | my own unscoped cross join (see §2) | scoped — and the class searched, 40+ sites in 11 files |
| `17` and `49`, on the re-run **after** the HTTP suites | the same class, two more instances | scoped; the suite is now run in both states, every time |
| `58` fixture | `trusted_devices.status_code` is NOT NULL and I omitted it | read the column list |

---

## 7. Environment, parity and guards — final state

| Axis | Value |
|---|---|
| Migrations | **150** — repository, local, Primary |
| Fingerprint | **`2f94900a67e5bb589b8a3c7303339c3f`** on all three |
| Logic hash (`guard_write_capability` + its 13 triggers, incl. type bits) | **`a98707fd7cb123f6ba07fa66aeace747`** identical local and Primary |
| Leftover `authenticated` INSERT/UPDATE on the five system tables | **0**, on both |
| pgTAP | **58 files / 672 assertions / 0 failures** — green on a fresh `db reset` **and** with all HTTP residue present |
| End-to-end HTTP | **118/118** — storage 36 · employee 29 · branches 26 · roles 27, all re-run on a fresh stack |
| Migrations replay | all 150 applied in order by `npx supabase db reset`, clean |
| Smoke | `ALL CHECKS PASSED` (74 tables, 71/601 catalog, FK standard, …) |
| Guards | repository CLEAN · parity CLEAN |

---

## 8. Classification

**PROVEN** — the five revokes break nothing (every writer is definer and the system path is
re-proven); the four config guards deny a trainee and permit an owner on the same table; the auth
artifacts hold their ownership boundary against a real foreign write; the guard map is complete and
refuses on an unmapped table; the pgTAP suite is order-independent.

**UNPROVEN** — the trainee's full journey over HTTP (only its denial path is proven); the remaining
lifecycle branches (quotation rejected/expired/revised, booking modified, partial payment, supplier
failure, document expiry, repeat booking).

**FAILED** — none outstanding.

**BLOCKED** — **SEC-1** (now `lead_interactions` alone) · **AUTH-1** (new) · FIN-5 · SYSADMIN-1 ·
TRANS-1 · TASK-3 · SCHED-1 · RET-1, RET-2, ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1 ·
DEL-1 (partial) · PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — `otp_challenges` / `totp_enrollments` / `trusted_devices` governed by ownership
(canon 34); `notifications` keeping a column-level UPDATE; the `holidays` union; reference-table
lookups left unscoped in fixtures.

---

## 9. Next logical work

**The trainee's full HTTP journey** and **the remaining lifecycle branches** — both are ordinary
engineering with no decision attached. Then **TRANS-1** (transition authority duplicated between the
`advance_*` functions and `app.status_transitions`) and **SCHED-1** (nothing invokes the storage
executor on a schedule).

`lead_interactions`, AUTH-1, FIN-5 and SYSADMIN-1 need the owner, not more discovery.
