# ORVION — Owner Decision Review: 24 Proposals Verified, and a High-Severity Defect Found Underneath One

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Scope: Owner-directed decision review. Phase A — verify 24 proposed decisions against canon,
repository, runtime and external practice. Phase B — resolve A3 and PP-1 and sweep the register for
ambiguous/stale/duplicated entries. **No proposed decision was implemented. No migration written.**
Status: Phase A + B complete; STOPPED at the Phase C owner gate as directed.

**Branch:** `main` · **Start HEAD:** `5b19845` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.
**State correction made mid-session, and it is the first thing the next reader should see:** this
session began by trusting a summary that said 169 migrations. The repository was at **179** (HEAD
`5b19845`), two packages further on, and the date was **2026-09-01**, not 2026-08-30. Caught by the
manifest refusing to match an edit. Every figure below was re-measured afterwards; the SEC-1c
reproduction was re-run from scratch on a fresh reset at 179. `AGENTS.md §4` says a summary is a
lead, never a fact — this is that rule earning its place, against the agent that wrote it.

---

## 1. Objective and method

The directive supplied 24 PROPOSED decisions and forbade turning any of them into an ORVION rule
without owner approval. Each was tested against the evidence order the programme already uses —
canon → SSOT/register → schema → implementation → consumers → tests → runtime → Primary → external
practice — and classified A–F. Nothing below is a rule; everything below is evidence.

**Two proposals were falsified by evidence** (PD-23, PD-14's canon premise), **one proposal's premise
was found to be already unimplementable as stated** (PD-09), and **one investigation surfaced a
High-severity live defect that no proposal named** (SEC-1c).

---

## 2. Environment note, recorded because it is not a product finding

Mid-session `docker ps` began failing with `failed to connect to the docker API`. Cause: **Docker
Desktop was not running** (process count 0) — infrastructure, not a defect. Structure was read from
**Primary** instead, which is legitimate because this session had already proven local = Primary at
structural hash `3a65328f42bd8c13b3f3048fa8f0158f` across 3,348 objects. Behavioural probes waited
until the local stack returned; **none was ever run against Primary.** Recorded because in a
transcript an infrastructure failure and a product failure look identical (`AGENTS.md §6`).

Two further self-inflicted errors are recorded rather than tidied away: a probe died on **invalid hex
in a UUID** (`…t1`, `…s1`), the fourth occurrence of that personal slip; and a probe fixture guessed
`customers`/`passengers` column shapes and was corrected by **reading the catalog** rather than
guessing again.

---

## 3. PHASE B — A3 and PP-1

### A3 — RESOLVED, and it is an ID collision rather than an open question about its subject

`A3` names **two different things** in this repository:

1. `engineering-audit-2026-07.md §A3` — "Phase-8 attribution capture is incomplete" (gbraid/wbraid/
   consent). **Closed long ago** by R5/SPEC-119; `attribution_clicks` now carries `gbraid`, `wbraid`,
   `consent_ad_user_data`, `consent_ad_personalization`, verified live.
2. `MASTER_ARCHITECTURE_DECISIONS.md` item 11 — the **money-storage ADR-process** question, which is
   what `manifest.md` and the register's pointer row actually mean.

Reading (1) when the manifest means (2) is a live trap for a fresh session, and the two are in the
same document family. The **question A3 actually asks** is: DC-1's money standard (`numeric(19,4)`,
rounding by `currencies.decimal_places`) shipped in SPEC-118 with canon 30/31 updated but **no
ratified ADR**. Does it warrant one? Item 11 also records that A3 pre-reserves no ADR number.

**Genuinely open, and purely a governance/ADR-process choice** — nothing in the runtime depends on
the answer. Not resolvable without the owner because it asks what the owner wants the ADR log to
contain.

### PP-1 — the manifest raises an id the register never defined

Measured, not assumed. An independent subject-extraction over all **29** manifest decision ids
(first table cell, or `###` heading, sibling-aware for `SPP-1/SPP-2` and `DC-1/R7`) returns exactly
**one** id that is not a register subject: **PP-1**.

It satisfies Check 11 only because `DOC-2`'s row happens to end `New: **PP-1**, **PP-2**` — a
cross-reference inside a different finding. That is **MEAS-2** (below).

PP-1's originating definition is `wp-04b-payment-proof-lifecycle-2026-08-27.md §10`:
`subscription_payment_proofs.reviewed_by` references `public.users`, which holds only tenant users,
so a Platform Owner reviewer cannot be recorded. **`SPP-3` states the identical fact about the
identical column with the identical decision required.** The owner is therefore being shown one
decision twice. **Not merged silently** — retiring an id is a governance act, and both appear in
immutable history. Registered with the evidence; the merge is asked as a question.

### Register sweep — everything else resolves

The same measurement found no other orphan. Two stale/ambiguous items *were* found and are recorded
separately: **MEAS-2**, and the observation that `MASTER_DEPENDENCY_GRAPH.md`'s "135 findings" is a
dated 2026-08-29 measurement (correctly framed, left alone).

---

## 4. The finding no proposal named — SEC-1c (High), reproduced

Investigating PD-24 (supplier credit visibility) meant reading `suppliers`' actual protection. It has
one policy — `tenant_isolation FOR ALL`, qual `tenant_id = current_tenant_id()` — and one capability
trigger, `suppliers_guard_write_capability`, which is **`BEFORE INSERT`** and nothing else.

Asking the class question rather than stopping at the instance: **`guard_write_capability` is
INSERT-only on thirteen tables** — `approval_requests`, `bookings`, `complaints`, `conversations`,
`customer_notes`, `customers`, `documents`, `leads`, `passengers`, `quotations`, `service_requests`,
`suppliers`, `tasks`. For ten, RLS `WITH CHECK` still carries a **scope** predicate. For **three —
`customers`, `passengers`, `suppliers` — the UPDATE `WITH CHECK` is tenant isolation and nothing
else.**

**This is the exact mirror of SEC-1b.** SEC-1b found the ceiling counting UPDATE-only triggers and
opened twelve tables on the INSERT path. Nobody then asked the inverse question about the tables
SEC-1b did not touch.

Reproduced on a clean local reset, as a `trainee`, inside a rolled-back transaction:

```
CONTROL  has_permission CREATE_CUSTOMER=f  CREATE_PASSENGER=f  MANAGE_SUPPLIERS=f  VIEW_FINANCIAL_DOCUMENTS=f
CONTROL  rows visible before the write: customers=1  passengers=1  suppliers=1 (credit 1000)
NEGATIVE INSERT customers  -> REFUSED  "permission denied: one of CREATE_CUSTOMER is required"
PROBE    UPDATE customers.full_name              -> UPDATE 1  "Overwritten By Trainee"
PROBE    UPDATE passengers.full_name             -> UPDATE 1  "Overwritten Passenger"
PROBE    UPDATE suppliers.credit_limit_amount    -> UPDATE 1   1000 -> 999999
```

The refused INSERT **in the same session on the same table** is what makes this non-vacuous: it
proves the actor is genuinely unprivileged, so the difference is INSERT vs UPDATE and not the
fixture. `suppliers.credit_limit_amount` is the very field whose *visibility* is an open owner
decision — a trainee can rewrite the exposure ceiling they arguably should not even read.

**Not fixed, by directive.** The fix is small and independent of SEC-1's architecture question, but
it is not mechanical: `guard_write_capability` charges a `CREATE_*` permission, and UPDATE may
warrant an `EDIT_*`/`MANAGE_*` one — a permission-matrix question. The other ten tables are
**UNPROVEN** and each needs its own probe.

---

## 5. PHASE A — what the evidence did to the proposals

Full per-item evidence is in the decision sheet delivered to the owner. The results that changed a
proposal rather than confirming it:

- **PD-23 (PLAN-1) — the premise is false.** Canon `17_saas_plan_matrix.md §Plan Numeric Limits`
  already fixes the numbers, and `feature_entitlements` is **seeded with exactly them** (users
  5/15/∞, branches 1/3/∞, monthly leads 500/10,000/∞, monthly bookings 100/3,000/∞, automations
  5/100/∞, storage 2/5/∞ GB; Enterprise NULL = unlimited). `app.plan_allows`, `app.plan_limit` and
  `app.tenant_capabilities` read them. Nothing is invented and nothing is missing — but
  **`usage_counters` has zero producers**, so nothing counts usage and no limit is enforced. PLAN-1
  is not "decide the ceilings"; it is "decide what happens when one is crossed."
- **PD-14 (VOID-1/FIN-7) — my first reading was wrong and is corrected here.** Canon 26 contains a
  transition `issued → void`, but that is the **Booking** machine, not the invoice. Canon 26 defines
  six machines — Lead, Booking, Booking Item Base, Finance Approval, Document Lifecycle,
  Subscription — and the word "invoice" appears **zero** times. So an invoice state machine would be
  **new canon**. Meanwhile `invoice_status_code` already carries `voided`, and `invoices.status_code`
  is **not** in `app.status_transitions`, so no invoice transition is enforced at all today. Canon
  `07 §102` does already require corrections after approval to go through "a new event, adjustment,
  reversal, or authorized finance action" — so the *journal* half of PD-14 is already canon.
- **PD-04 (PH8-3) — there is no tenant country concept.** `tenants` has `default_currency_code`,
  `primary_phone`, `slug`, `status`, trial stamps — and **no country, locale or timezone column**.
  The only country columns anywhere are `bookings.destination_country_code` and
  `passengers.passport_issuing_country_code`, neither of which is a tenant default. The proposal's
  "use an existing field" option does not exist.
- **PD-09 (DOC-EXP-1) — cannot be implemented as stated.** `notifications` and
  `notification_deliveries` exist; **no function anywhere references them**. Canon 10 says "Passport
  expiry where configured" and canon 16 says "Expiry alerts are controlled by notification rules" —
  so canon defers the thresholds to a rules concept that does not exist. Fixed 60/30/7/1 would be
  inventing policy canon deliberately left configurable.
- **PD-03/PD-16 (PH8-2 / DELIV-1) — confirmed precisely.** `app.claim_conversion_deliveries` filters
  `ac.consent_ad_user_data = 'granted'` **inside the claim query**, so a consent-blocked conversion
  is never claimed, never stated and never counted. Its `attribution_clicks` join is an **INNER**
  join, so a conversion with a NULL `attribution_click_id` is *equally invisible* — a second
  silence class the proposal does not name. The catalog holds exactly `{pending, retried, sent,
  failed}`; there is no `processing` (a 30-minute lease reuses `pending`) and no `exhausted`.
- **PD-06 (SCHED-1) — `pg_net` is NOT installed.** `pg_cron` and `supabase_vault` are. Option A is
  not "use what is there"; it is "add outbound HTTP to the database."
- **PD-10 (AUTH-1) — confirmed.** `app.mfa_satisfied()` reads the Supabase JWT `aal` claim;
  `app.requires_mfa()` is role-based. **Neither reads `otp_challenges` or `totp_enrollments`**, and
  no other function does either.
- **PD-12 (SYSADMIN-1) — confirmed, with a wrinkle.** `system_administrator` holds **0** permissions
  (every other role holds 2–65), but it **is** named in `app.requires_mfa()`'s role list, so it is
  not wholly inert.
- **PD-07 (RET-1) — the repository already encodes "undecided."** `app.document_retention_days()`
  returns `null::integer`, and canon says nothing about document retention anywhere.
- **PD-20 (AUDIT-4) — confirmed.** The only consent columns in the database are
  `attribution_clicks.consent_ad_user_data` / `consent_ad_personalization`. There is **no
  customer-level consent anywhere**, and canon mentions consent only in canon 21 (offline
  conversion). Keeping it separate from ad-click consent is not a preference; they share no
  structure.
- **PD-01 (SEC-1) — measured live.** `authenticated` holds INSERT/UPDATE on **55** `public` tables
  and **DELETE on none**. All **76** `public` RPCs are `SECURITY INVOKER` (zero DEFINER); `app` holds
  62 DEFINER / 107 INVOKER. Option A means converting all 76 and hand-writing tenant checks in each.

---

## 6. Verification performed

| Axis | Result | Evidence class |
|---|---|---|
| Primary ledger, read live | **`179\|1f64a99ca835e0a54a222944c1aadcf5`** | PRIMARY |
| Local ledger after `npx supabase db reset` | **`179\|1f64a99ca835e0a54a222944c1aadcf5`** — identical | LOCAL RUNTIME |
| All structural reads (triggers, policies, grants, catalogs, entitlements, function bodies) | taken from **Primary at 179**, i.e. current | PRIMARY |
| SEC-1c reproduction | **re-run at 179** after the state correction: 3 tables, positive + negative controls, rolled back | LOCAL RUNTIME |
| Manifest-id subject measurement | 29 ids, exactly **1** non-subject (PP-1) **at the time of measurement**; the PP-1 row added by this session closes it, and a re-run returns none | REPOSITORY |
| Canon reads | 07, 09, 10, 16, 17, 21, 25, 26, 28, 30, 31 | INTENT |

**Not run:** pgTAP, the HTTP suites, the parity guard's Primary comparison. No migration, test or
suite changed in this package. **The hashes quoted in the predecessor report (169 / `4f79ecfd` /
`3a65328f` / 3,348 objects) are superseded and must not be carried forward** — they were true at
`09adf19` and two packages have landed since.

---

## 7. Classification

**FIXED** — none, by directive.
**PROVEN INTENTIONAL / not a defect** — PD-18 (TASK-3), PD-22 (BLOCKED-5: `trial_period_days()`=30
and `enforce_trial_stamp_immutable` already make the stamp write-once).
**NEWLY DISCOVERED, OPEN** — **SEC-1c** (High, reproduced), **MEAS-2** (Medium), **PP-1** registered.
**UNPROVEN** — the ten scope-guarded tables in SEC-1c's class; whether `retried` is ever written.
**OWNER DECISION REQUIRED** — as itemised in the decision sheet.

**No business policy was invented. No canon was changed. No proposed decision was implemented.**

---

## 8. Next executable step

**Await the owner's answers to the decision sheet.** Nothing in Phase D begins without them.

The one item that does **not** depend on any answer is **SEC-1c**: it is a proven security defect,
not a policy question, and the only reason it is not already fixed is this session's
investigation-only mandate. Recommended first action on resumption — ahead of the remaining Batch-6
work — with the permission-matrix question (`CREATE_*` vs `EDIT_*` on UPDATE) settled from canon 28
before the trigger is touched.

**Programme position, re-read rather than assumed:** **API-3 is CLOSED — 71 of 71 endpoints carry
HTTP execution evidence** (`MASTER_API_CONTRACT.md` owns the count). The predecessor report's "next:
API-3 lead-routing family" is **obsolete**; the remainder of Batch 6 is next, per
`MASTER_EXECUTION_PLAN.md`. Phase 8 remains current and Phase 10 remains NOT READY.
