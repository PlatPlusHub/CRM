# ORVION — API-3 Marketing Campaigns: Three Defects on the Only Path Where Money Leaves ORVION

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Status: Complete. **Migration `202607058200` is NOT deployed to Primary — awaiting owner approval.**

---

## A. Session scope

**Objective.** Audit API-3's marketing-campaign family — `create_marketing_campaign`,
`advance_marketing_campaign`, `record_offline_conversion` — for defects, then give all three their
first HTTP execution evidence.

**Bounded surface examined:** the three RPCs and their `public` wrappers; `public.marketing_campaigns`
and `public.offline_conversions` (columns, constraints, indexes, triggers, RLS, grants); the campaign
rows in `app.status_transitions`; the `campaign_status_code` and `offline_conversion_event_type`
catalogs; the permission matrix for `MANAGE_MARKETING_CAMPAIGN` / `VIEW_MARKETING_DASHBOARD`; the five
consumers of `offline_conversions`; canon 26's Marketing Campaign State Machine; existing tests and
HTTP suites.

**Explicitly out of scope and not touched:** the n8n workflow (still gated), the Phase-8 delivery
transport, the roadmap, `reassign_lead`/LEAD-5, the remaining nine API-3 endpoints, and every table
outside the two named above. One dependency was examined because it was strictly necessary:
`public.payments`' `amount` and `currency_code` constraints, required to prove the session-less
writer compatible with a proposed constraint. That examination went no further.

---

## B. Git state

| | |
|---|---|
| Branch | `main`, tracking `origin/main` |
| Starting HEAD | `09adf1951a733689949c9dec4be730eaeedcbc74` |
| Ending HEAD | `09adf1951a733689949c9dec4be730eaeedcbc74` — **unchanged** |
| `origin/main` | `09adf19…` — 0 ahead / 0 behind |
| Working tree | **DIRTY, deliberately** — this package plus the previous session's, both uncommitted |
| Commit | **NO** |
| Push | **NO** |

The previous session's uncommitted package (`202607058100`, test 77, lifecycle HTTP additions,
governance updates) was verified present and intact at session start and was not disturbed.

---

## C. Environment

- **Local database:** reset repeatedly, as the protocol requires. Final state **171 migrations**,
  latest `202607058200`.
- **Primary `vrvtsxexkiiiivlkdxzp`:** contacted, **read-only** — `get_project_url`, plus three
  `execute_sql` reads (ledger, function surface, and the structural-surface value carried from the
  same session's earlier read). **No write of any kind.**
- **n8n:** **not contacted this session.** Its state is therefore HISTORICAL here, not verified.
- **GitHub:** not written to.

---

## D. Evidence classes

| Claim | Class | What was actually measured | What it cannot prove |
|---|---|---|---|
| 171 migrations, ledger `de72ed385715edacc21a7234a54a4589` | LOCAL RUNTIME | `supabase_migrations.schema_migrations` after a clean reset | anything about Primary |
| Pass A / Pass B 78 files / 1,009 assertions | LOCAL RUNTIME | executed this session | the HTTP door |
| HTTP 328/328 | HTTP | six suites executed this session | internal paths no client reaches |
| Primary at **169**, `4f79ecfdad3b2f1f424f72e70e414d86`, `a994108bd5cf44f9cc570180e72312a4` | **PRIMARY** | read live FROM Primary this session | nothing about the undeployed migrations |
| API-3 at 62/71 | GENERATED | regenerated contract; `http` column is a **repository fact** (VER-1) | that a suite passed — that is the HTTP row above |
| n8n holds 0 workflows | **HISTORICAL** | not measured this session | current state |

---

## E. Findings

### CONV-4 — a negative conversion value · High · **PROVEN DEFECT → FIXED**

**Hypothesis.** `record_offline_conversion` refuses `conversion_value < 0`; no constraint backs it.
**Evidence before reproduction.** No CHECK on the table; `authenticated` holds INSERT;
`guard_write_capability` charges `MANAGE_MARKETING_CAMPAIGN`; RLS is tenant-only.
**Positive control.** The actor genuinely held `MANAGE_MARKETING_CAMPAIGN` (`has_permission` = true,
with `aal2`); the legal RPC call recorded 5000 EGP successfully first.
**Reproduction.** As an `owner` over the real `authenticated` role: the RPC refused
(`conversion_value must be non-negative`) and a direct INSERT in the same transaction stored
**-5000.0000 EGP**.
**Root cause.** A row-level integrity rule implemented in one function.
**Consumer impact, measured not assumed.** `app.claim_conversion_deliveries` returns
`conversion_value` and `currency_code` verbatim into the Google Data Manager payload and filters only
on platform, delivery status and attempt count — so the row is **delivered**, not caught.
**Disposition.** FIXED with a CHECK constraint.

### CONV-5 — an amount with no currency · High · **PROVEN DEFECT → FIXED**

Same door, same actor. RPC refused (`currency_code is required when conversion_value is set`); direct
INSERT stored **7777.0000 with `currency_code` NULL**. An amount with no currency is unusable rather
than imprecise, and it leaves ORVION for a platform that will apply its own default. FIXED with a
CHECK constraint.

### CAMP-1 — a campaign with no status · Medium · **PROVEN DEFECT → FIXED**

`marketing_campaigns.status_code` was nullable and `app.enforce_status_transition` is BEFORE
**UPDATE**, so INSERT never had to name a state. Reproduced: a direct INSERT created a NULL-status
campaign, and `advance_marketing_campaign` then reported **"campaign not found in your tenant"** about
a row that plainly exists — permanently unadvanceable, because every transition needs a FROM state.
FIXED with NOT NULL; the false message becomes unreachable as a consequence, so no separate message
change was made.

### H-M4 — illegal campaign transition by direct DML · **NOT A DEFECT**

Hypothesised as a DOC-LC-1 repeat. **Disproven by reproduction:** `marketing_campaigns` already
carries `enforce_status_transition` and six `app.status_transitions` rows, and a direct
`update … set status_code = 'archived'` on an `active` campaign was **refused**. Nothing was changed.
The RPC additionally holds an inline transition list — a duplication, but the two definitions were
compared row by row and **agree exactly**, and the inline list also supplies event codes that
`status_transitions` does not carry. Recorded as consistent, not filed as a finding.

### CAMP-2 — initial state is unconstrained on INSERT · **UNPROVEN**

A direct INSERT may name any valid status, including a late one. **No harm was reproduced**, and the
question applies to every status-bearing table in ORVION. Inventing a rule for this one table would
create the inconsistency a later audit would file. Recorded, not acted on, not escalated.

### Cross-tenant reference on the conversion record · **NOT A DEFECT**

`record_offline_conversion` validates `p_lead_id` and `p_attribution_click_id` explicitly but not
`booking_id`, `booking_item_id`, `payment_id`, `marketing_campaign_id`. Checked rather than assumed:
all four carry **composite `(tenant_id, …)` foreign keys** (TENANT-1), so a cross-tenant reference is
structurally impossible. The explicit checks are redundant, not missing.

---

## F. Fixes

**`supabase/migrations/202607058200_a_conversion_value_is_money_that_leaves_the_building.sql`** —
`offline_conversions_value_nonneg_check`, `offline_conversions_value_currency_check`, and
`marketing_campaigns.status_code SET NOT NULL`.

**Enforcement layer, and why it is not a trigger.** All three invariants are **row-level**: each is
decidable from the single row being written, with no reference to another row. That is what a CHECK
is for, and a constraint is stronger than a trigger here because it cannot be reached around by any
door, any role, or any session-less path — LESSON 6 of this programme being that authorization may
exempt platform paths and **integrity must not**.

**Legal writers checked BEFORE the constraints were written, not after:**
- `app.record_offline_conversion` — already enforces both money rules itself.
- `app.map_outcomes_to_conversions` — the session-less `pg_cron` writer — derives value from
  `payments.amount` and currency from `payments.currency_code`. `payments` carries
  `payments_amount_nonneg_check (amount >= 0)` and a NOT NULL `currency_code`, so that writer is
  **structurally incapable** of violating either constraint.
- `app.create_marketing_campaign` — the **only** function that inserts a campaign; always writes
  canon 26's initial state `draft`.
- Existing rows counted first: **0** negative, **0** valueless-currency, **0** null-status.

**`supabase/tests/78_marketing_conversion_integrity_test.sql`** — 19 assertions.
**`scripts/verify_lifecycle_branches.ps1`** — +13 assertions (89 → 102).
**`supabase/tests/64_acquisition_lineage_test.sql`** — one fixture correction (TEST-64, below).

---

## G. Measurement attacks

**All three constraints were attacked by defect injection**, inside savepoints: drop the constraint →
assert the prohibited write **succeeds** → roll back → assert it is refused again. For CONV-4 the
mutation additionally asserts the corrupt row is really present (`count = 1`), so the mutation cannot
pass vacuously. For CAMP-1 the mutation reproduces the **original symptom** — the campaign inserts,
and `advance_marketing_campaign` then returns the false "not found" message.

**A negative control on the constraint itself:** a conversion carrying **no** value and **no**
currency is asserted to remain legal, proving the pair rule does not over-reach into event types that
carry no money.

**A guard caught a real regression in this session's own work.** `64_acquisition_lineage_test.sql`
failed on Pass A immediately after the constraints landed. Investigated before anything was changed:
its positive control inserted an `offline_conversions` row with **no currency** and then set
`conversion_value = 15000` — a state `record_offline_conversion` has always refused, so the fixture
was modelling a row no legal caller could produce. It had passed only because nothing enforced the
pair. **Recorded as TEST-64** and corrected by moving the currency with the value; the assertion's
intent is unchanged. Same class as the WP-04-B fixture correction. **This is a fixture defect the new
constraint exposed, not a product defect.**

**Three failures this session were mine and are recorded as such, not as findings:**
1. I guessed `app.claim_conversion_deliveries(integer)`; the real signature is
   `(p_platform_code text, p_batch integer)`. The bad probe aborted a transaction.
2. My first reproduction used a JWT without `"aal":"aal2"`; `owner` requires MFA step-up, so
   `create_marketing_campaign` refused. That refusal was **correct behaviour**, not a defect.
3. An earlier probe called a function name I had invented.

**Guard limitation restated rather than treated as proof:** the contract's `http` column is a
**repository** fact measuring source text (VER-1). API-3 moving to 62 is evidence that the suites
*reference* the endpoints; the 328/328 execution result in §H is what proves they *ran*.

---

## H. Verification executed THIS session

| Step | Result |
|---|---|
| `npx supabase db reset` | exit 0, **171** migrations |
| pgTAP **Pass A** | **78 files / 1,009 assertions / PASS** |
| **Six HTTP suites** | **328 passed, 0 failed** — 29 · **102** · 42 · 66 · 38 · 51 |
| pgTAP **Pass B**, no reset, under the suites' residue | **78 / 1,009 / PASS** = Pass A |
| Smoke `verify_database.sql` | `ALL CHECKS PASSED (75 tables …)` |
| Local ledger | 171, `de72ed385715edacc21a7234a54a4589` |
| Local function surface | `b42f555c13d7d05af9157b673d7f9faa` (238) — unchanged by this migration, which adds no function |
| Local structural surface | `1166bb39295938e8294e38d503d5b7eb` — **3,355** objects (constraints 440 → 442) |
| Parity guard | **exit 1 — PRIMARY DRIFT, correct and intended** (§I) |
| API contract | regenerated: 71 endpoints, **62** with HTTP evidence; Check L3 "matches the live surface" |
| Repository guard | CLEAN, 13/13 |

No result above is carried from a previous session.

---

## I. Primary / deployment

Primary was **read three times, written zero times**. Measured live: **169 migrations**, latest
`202607058000`, ledger `4f79ecfdad3b2f1f424f72e70e414d86`, function surface
`a994108bd5cf44f9cc570180e72312a4` (236).

**Drift exists and is intentional.** Repository and local are at 171; Primary at 169. Two migrations
— `202607058100` (lead routing) and `202607058200` (marketing) — are verified and undeployed pending
owner approval. The parity guard therefore reports three drift issues at exit 1, and **that verdict is
correct and must not be "repaired" by any means other than an approved deployment.** Repository ↔
local parity is CLEAN (Check L1).

---

## J. Governance / SSOT

| File | Action | Why |
|---|---|---|
| `_ORVION_CANONICAL/manifest.md` | **UPDATED** | Owns live state: migrations, hashes, suite counts, Last Completed, Next capability all changed. Trimmed to **6,820** chars (180 headroom) — MF-1's lesson is to trim, never widen. |
| `reports/master/MASTER_GAP_REGISTER.md` | **UPDATED** | Owns finding status/evidence: CONV-4, CONV-5, CAMP-1, CAMP-2, TEST-64. |
| `reports/master/MASTER_EXECUTION_PLAN.md` | **UPDATED** | Batch 6 package narrative (AUD-03 permits narrating what a package fixed). |
| `reports/master/MASTER_API_CONTRACT.md` | **REGENERATED** | Generated artifact; 55 → 62 in this working tree. |
| `ai-map.json` | **REGENERATED** | Check 7 compares it to the manifest, which changed. |
| `reports/README.md` | **UPDATED** | Latest-session pointer; an unlinked report is invisible to the boot sequence. |
| `_ORVION_CANONICAL/32_execution_roadmap.md` | **UNCHANGED** | No phase, order or gate changed. |
| `_ORVION_CANONICAL/26_state_machines.md` | **UNCHANGED** | Canon was the *authority* consulted for the campaign machine and initial state, not the subject. No canon rule invented or altered. |
| `MASTER_CERTIFICATION_STATUS.md` | **UNCHANGED** | Certification state and gate unchanged. |
| `reports/architecture-decision-records.md` | **UNCHANGED** | No new architectural decision; CHECK constraints follow existing precedent. |

---

## K. Continuity

- **Phase** — Phase 8, Offline Conversion, IN PROGRESS. Order 7→9→8→10. **Phase 10 NOT READY.**
- **Batch** — Batch 6, Foundation Completion Programme.
- **Gate** — Foundation Completion gate **SHUT**. Certification **CONDITIONAL**.
- **Active Change Request** — None.
- **Open owner decisions** — the 29 pre-existing IDs, unchanged in number and content. **This session
  created none.** Plus the standing deployment approval for the two undeployed migrations, which is a
  deployment decision rather than a design one.
- **UNPROVEN** — `202607058200` and `202607058100` on Primary (never deployed, never exercised there);
  **CAMP-2**; `storage-executor` Edge Function execution; n8n credential authentication/scope; n8n
  workflow count (HISTORICAL, not measured this session).
- **Blockers** — one, and it is not engineering: deployment approval.
- **Resolved, must not be reopened** — LEAD-5, the round-robin tie-break, LEAD-6/ASGN-1/2/3, H-M4
  (campaign transitions already governed at the table door), and the cross-tenant FK question above.

---

## L. Next executable step

**Continue API-3 — 9 endpoints remain without HTTP evidence**, read from the regenerated contract:
`add_customer_contact_method` · `assign_task` · `current_placement` · `financial_documents` ·
`find_customer_duplicates` · `link_internal_supplier` · `redeem_license_token` ·
`tenant_capabilities` · `upload_subscription_payment_proof`.

**The next bounded family is the customer-data group — `add_customer_contact_method`,
`find_customer_duplicates`, `current_placement`** — the largest coherent remaining group, and the one
touching `customers` / `customer_contact_methods`, where NORM-1 and CUST-1 both landed, so it carries
known-defect history worth auditing rather than assuming.

*This is a recommendation of sequence, not a finding.* The owner may instead prioritise the
deployment approval named in §I, which is the only item currently blocking Primary parity.
