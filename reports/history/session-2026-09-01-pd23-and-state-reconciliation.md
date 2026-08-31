# ORVION — PD-23: The Quota Class Is Inert, And Eighteen Decisions Were Stale

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Scope: State-consistency reconciliation of the SSOTs (**OWNER-1**); PD-23 measurement of the
quota/entitlement class; **MEAS-2** fixed and mutation-tested. **No migration written — and that is
a conclusion, not an omission.**
Status: Complete.

**Branch:** `main` · **Start HEAD:** `6d7f2df` · **Environment:** repository = local = Primary at 181.

---

## 1. STATE RECONCILIATION — the stale thing was the decision list itself

The manifest's `Open owner decisions` line is what a fresh session reads to learn what is blocked.
It had not moved after the owner's decision directive, so **eighteen settled questions still
presented as awaiting an answer** — exactly the stale-owner-decision class the directive asked to be
checked for, and the most misleading kind of staleness because it manufactures phantom blockers.

Removed from the open list because they are now DECIDED (each remains an *engineering task* where
implementation is owed; none is an open *question*): **SEC-1** — and with it **RLS-1**, merged into
it — **AUTH-1**, **SYSADMIN-1**, **FIN-5**, **DEL-1**, **EVT-2**, **SCHED-1**, **DOC-EXP-1**,
**PH8-5**, **PH8-3**, **SPP-3** + **PP-1**, **BLOCKED-4**, **BLOCKED-5**, **AUDIT-4**, **RET-2**,
**A3**.

Still genuinely open, unchanged: **RET-1** · **FIN-7** + **VOID-1** · **TRANS-1** · **DELIV-1** +
**PH8-2** · **PLAN-1** · **DOC-LC-2** · **DOC-LC-3** · **CANON-26-1** · **LIC-1**. Twenty-nine → twelve.

**A false positive of my own reconciliation detector, recorded rather than acted on.** It flagged
**PLAN-1** as stale because its status cell opens `RESOLVED 2026-08-24`. The row is not stale: its
body says *"Still open: numeric ceilings are readable but nothing counts against them"* plus three
"Limited" ceilings canon leaves undefined. Reading the headline and not the row would have closed a
live owner decision — so the row was read before the detector was believed.

---

## 2. PD-23 — PROVEN, structurally

Measured rather than grepped for a name:

- **No function anywhere in the database references `usage_counters`** — not an INSERT, not an
  UPDATE, not even a read. Its only trigger is `moddatetime`. It holds **0 rows**.
- **`app.plan_limit` exists and nothing calls it.** A second zero, in the reader direction.
- **The boolean half IS enforced:** `app.has_permission` composes `app.plan_allows`, so plan denial
  covers the RPC path, direct PostgREST reads and direct writes at once (SPEC-146).

**Detector attacked before the zero was accepted:** no view references the table; the single
`EXECUTE format` function in `app`/`public` is a reference-integrity helper, not a dynamic writer;
and the only objects named `usage%` are the table and its three indexes.

## 3. WHY NOTHING WAS BUILT — derived, not deferred by preference

Canon 28 §Plan Gating Enforcement already states the position in its own words:

> "**Ceilings are readable, not enforced.** `app.plan_limit` exposes them; `usage_counters` is empty
> and counting is a separate additive mechanism."

and canon 09 says the numeric limits **"must be reviewed before pricing is finalized"** — which has
not happened. Building enforcement now would harden provisional commercial numbers into blocking
behaviour, with no client, **zero business rows on Primary**, and one metric (`max_automations`)
counting n8n workflows in an instance that holds zero.

**Semantics differ per metric and must not be built as one thing** — derived from ORVION's own model,
not from generic SaaS assumptions:

| metric | shape | consequence |
|---|---|---|
| `max_users`, `max_branches`, `max_storage_gb` | **current state** — freeing a slot restores capacity | a direct count is authoritative; a stored counter is denormalised state that can drift |
| `max_monthly_leads`, `max_monthly_bookings` | **periodic consumption** | this is the shape `usage_counters.period_start/period_end` was built for |
| `max_automations` | **external** (n8n) | not countable in PostgreSQL at all |

**Security checked and sound:** `authenticated` holds SELECT only on `usage_counters` — no INSERT,
no UPDATE — and RLS is `tenant_isolation`. If the counter ever becomes authoritative its mutation
surface is already not user-forgeable.

**Concurrency deliberately not designed.** The classic read-N/read-N/both-pass race requires an
authoritative stored counter. For the current-state metrics the authoritative source is the resource
table itself, where a unique index or a count under the write's own lock is the natural control. A
lock was not introduced merely because concurrency exists.

**Trigger to build:** pricing finalisation, or the first tenant approaching a ceiling on real data.

## 4. CLASS RE-SCAN — a clean negative, earned

Generalised from "why has this table no producer?" to "which tables have none?". Of **23** tables
with no function-INSERT producer, all but three are migration-seeded reference data (`countries`,
`currencies`, `roles`, `permissions`, `catalog_*`, `subscription_plans`, `feature_entitlements`, …)
or intentional direct-DML tables whose writes `guard_write_capability` charges (`holidays`,
`branch_business_hours`, `financial_accounts`, `company_assets`, `exchange_rates`, …) — correct by
design, not defects.

The genuinely inert accumulators are `usage_counters` (this finding), `notification_deliveries`
(**DOC-EXP-1**) and the two canon-34 identity tables (**AUTH-1**). **All three are already recorded,
so no new class exists.** The detector is noisy by construction and that is stated rather than left
for the next reader to rediscover.

## 5. MEAS-2 — fixed, and attacked

Check 11 tested `$registerRaw -notmatch '\bID\b'` — a match **anywhere** in a thousand lines of
prose — while printing "defines no such finding". It now builds the set of register **subjects**
(first table cell, or `###` heading, split on `/` so `SPP-1/SPP-2` and `DC-1/R7` still count) and
tests membership.

```
ATTACK   SPEC-146 appears TWICE in the register's prose and is a subject nowhere
         -> ORPHAN ID: manifest raises 'SPEC-146' but MASTER_GAP_REGISTER.md defines no such finding
RESTORE  -> all 12 manifest decision IDs resolve in the register
```

The first attack attempt used `DEAD-1` and proved nothing, because DEAD-1 has a real row. Recorded,
because an attack that cannot fail is not an attack.

## 6. VERIFICATION

No SQL changed in this package, so the database is untouched: repository = local = Primary at **181**,
ledger `67a9e05e43c733594a76dd7e6ce6da31`, functions `d9b0dd9cb6dfaa3ac2f38a9cc7601408` (247),
structure `71f87b282df0598ccc100e367e6f7e4c` (3,373) — proven live earlier today and unchanged.
pgTAP **86 files / 1154 assertions** and HTTP **371** stand from the preceding package. Repository
guard **CLEAN** with the corrected Check 11.

## 7. NEXT STEP

**ATTR-2 — the remaining `_by` actor columns**, classified per column into caller identity · derived
actor · business fact recorded on behalf of someone else · system actor · historical snapshot ·
unknown. `payments.received_by` is the specific column where deriving the caller could destroy
legitimate business meaning, so semantics get reproduced before anything is changed. Then the
care/conversation slice, whose write-capability half SEC-1c has already closed.
