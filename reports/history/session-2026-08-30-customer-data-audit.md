# ORVION — API-3 Customer Data: Three Defects, and Every One Was Already Written Down

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Status: Complete. **Migration `202607058300` is NOT deployed to Primary — awaiting owner approval.**

---

## 1. Scope

**FACT — objective.** Audit API-3's customer-data family — `add_customer_contact_method`,
`find_customer_duplicates`, `current_placement` — and give all three their first HTTP execution
evidence.

**Bounded surface examined:** the three RPCs and their `public` wrappers; `public.customer_contact_methods`
(columns, constraints, indexes, triggers, RLS, grants); `public.user_branch_assignments` (indexes,
RLS, grants); the consumers of both; canon 03 (company structure), canon 05 (customer identity),
canon 24/31; the migrations that created the contact-method indexes (`202607052100`) and the
placement writer (`assign_user_branch`).

**Dependencies inspected only as far as needed, with reason:** `app.create_customer` (to determine
what an empty `current_placement` actually causes); the other four `current_placement` consumers (to
establish whether they error or store NULL); `app.merge_customer_identity` (to establish whether it
writes `value`, which decided a constraint's compatibility); `public.customers`' normalization CHECKs
(the comparison that turned CM-2 from suspicion into evidence).

**Explicitly OUT OF SCOPE:** the remaining six API-3 endpoints, the n8n workflow, the roadmap, the
three undeployed migrations' deployment, and every table not named above.

---

## 2. Git state

| | |
|---|---|
| Branch | `main`, tracking `origin/main` |
| Starting HEAD | `09adf1951a733689949c9dec4be730eaeedcbc74` |
| Ending HEAD | `09adf1951a733689949c9dec4be730eaeedcbc74` — **unchanged** |
| `origin/main` | `09adf19…` — 0 ahead / 0 behind |
| Working tree | **DIRTY, deliberately** — three uncommitted packages now |
| Commit / Push | **NO / NO** |

The two pre-existing uncommitted packages (`202607058100`, `202607058200` and their tests) were
verified present and intact at session start and were not disturbed.

---

## 3. Environment

- **Local database:** reset repeatedly. Final state **172 migrations**, latest `202607058300`.
- **Primary `vrvtsxexkiiiivlkdxzp`:** contacted, **read-only** — `get_project_url` plus three
  `execute_sql` reads. **No write.**
- **n8n:** **not contacted.** Its state is HISTORICAL here, not verified.
- **GitHub:** not written to.

---

## 4. Evidence actually measured this session

| Claim | Class | Measured |
|---|---|---|
| 172 migrations, ledger `053f48815dc08adccc048a92f45bec50` | LOCAL RUNTIME | after a clean reset |
| Pass A / Pass B 79 files / 1,028 assertions | LOCAL RUNTIME | executed |
| HTTP 339/339 | HTTP | six suites executed |
| Primary **169**, `4f79ecfdad3b2f1f424f72e70e414d86`, `a994108bd5cf44f9cc570180e72312a4`, `3a65328f42bd8c13b3f3048fa8f0158f` | **PRIMARY** | read live FROM Primary |
| API-3 65/71 | GENERATED | regenerated contract |
| n8n 0 workflows | **HISTORICAL** | **not measured this session** |

---

## 5–7. Hypotheses, reproductions, classifications

### PLACE-1 · High · **PROVEN DEFECT → FIXED**

**Hypothesis.** `app.current_placement()` matches `ends_at is null` only, so a placement scheduled to
end is treated as if it did not exist.
**Authority that makes it a defect.** Canon 03: *"The system must record which branch first registered
a customer"*, and it explicitly provides for *"Temporary transfer / Permanent transfer"*.
`app.create_customer`'s own comment: *"Leaving it null was how canon 03's requirement quietly went
unrecorded."*
**Positive control.** With the placement open-ended, `current_placement()` returned the branch and
`create_customer` stamped it.
**Reproduction.** An `owner` holding MANAGE_USERS (aal2) set `ends_at = now() + 30 days` through the
RLS-permitted `scope_update` door. `current_placement()` returned **0 rows**. The next customer that
employee registered was stored with **`first_registered_branch_id` NULL**.
**Blast radius, measured.** Five consumers — `create_customer`, `create_quotation`, `create_complaint`,
`create_service_request`, `start_conversation` — all read it with `SELECT … INTO`, so empty is a
silent NULL rather than an error.
**Corroboration.** `app.eligible_lead_handlers` (LEAD-3) answers the same question with
`starts_at <= now() and (ends_at is null or ends_at > now())` and returns 1 row for the same fixture.

### CM-2 · High · **PROVEN DEFECT → FIXED**

**Hypothesis.** The canonical form is enforced inside the RPC but not on the table.
**Authority.** SPEC-126 / NORM-1, cited by the RPC's own comment; and `customers` carries
`customers_primary_email_normalized_chk` / `customers_primary_phone_normalized_chk` for the same rule.
**The claim that turned out false (LESSON 4).** `202607052100` states: *"the index is what makes that
check hold under concurrency and on the direct path."* It does not —
`customer_contact_methods_unique_value_idx` indexes the **raw** `value`, so a denormalized string is
simply a different string.
**Reproduction.** RPC stored `mona@example.com`; a direct INSERT of `'  MONA@example.com  '`
**succeeded**, leaving **two rows for one logical address** on one customer and one channel. The
identical value applied to `customers.primary_email` was **REFUSED**.
**Consumer impact, measured.** `app.merge_customer_identity` chooses which contact methods to delete by
comparing `t.value = s.value` — a denormalized twin is invisible to it, which is CUST-1's family.

### CM-1 · Medium · **PROVEN DEFECT → FIXED**

**Hypothesis.** The RPC's primary-demotion is broader than the model's rule.
**Authority — and this is why it is a defect rather than a preference.** `202607052100` states the rule
where it creates the index: *"Two primary **PHONES** for one customer … is the same class of defect"*,
encoded as `(tenant_id, customer_id, contact_method_type_code) WHERE is_primary` — one primary **per
channel**. `customers` carries `primary_phone` **and** `primary_email`; canon 05 speaks only of *"one
primary phone number"*.
**Reproduction.** As an `employee` holding CREATE_CUSTOMER, adding a primary EMAIL silently set the
customer's primary PHONE to `is_primary = false`.
**Consumed, not decorative.** `merge_customer_identity` reads `is_primary` when deciding which contact
methods survive a merge.

### PLACE-2 · Low · **UNPROVEN — recorded, not fixed**

`current_placement` does not test `starts_at <= now()`, diverging from `eligible_lead_handlers`. **No
harm reproduced**, and `assign_user_branch` defaults `starts_at` to `now()`, so a future-dated
placement is reachable only by direct DML. Adding the test would **change** existing behaviour in a
case no evidence showed harmful — which is exactly why PLACE-1's fix was kept strictly additive.

### NOT A DEFECT — established, not assumed

- **`find_customer_duplicates` tenant isolation.** It is SECURITY INVOKER and STABLE, so RLS on
  `customers` and `customer_identity_signals` bounds it. Proven: a rival tenant's customer holding the
  **same phone number** is not returned.
- **`find_customer_duplicates` matching.** It normalizes inputs with the same helpers the writers use;
  a presentationally formatted phone matches the canonically stored value. It reads `customers` and
  `customer_identity_signals` and **not** `customer_contact_methods` — checked rather than assumed.
- **`current_placement`'s `limit 1`.** Deterministic under the old predicate:
  `user_branch_assignments_one_primary_idx` guarantees at most one row with `is_primary AND ends_at IS NULL`.
  The widened window needed an explicit order, which the fix adds.
- **`current_placement`'s SECURITY DEFINER.** Safe: the row is selected by `app.current_user_id()`, so
  it cannot return another user's placement. Retained.
- **Contact-method duplicate prevention and one-primary-per-type.** Both are backed by real unique
  indexes, not only by RPC logic.

---

## 8. Fixes

`supabase/migrations/202607058300_a_primary_is_per_channel_and_a_placement_is_not_over_yet.sql`.

**Enforcement layers, each chosen after measuring the write surface:**
- **CM-1 → the function.** Its own UPDATE was over-broad. Nothing else sets `is_primary = true`, and
  the index already constrains the direct path correctly, per channel. A constraint would be the wrong
  layer: the invariant it violated was already declaratively enforced.
- **CM-2 → a CHECK**, mirroring `customers`, because the invariant is decidable from the single row. It
  **reuses** `app.normalize_email` / `app.normalize_phone` — both verified IMMUTABLE, which is what
  makes them legal in a constraint — instead of writing a third copy of the rule. The `is not null`
  guard is deliberate: both helpers return NULL for blank input and `value = NULL` is NULL, which a
  CHECK treats as satisfied.
- **PLACE-1 → the function.** It is a read model; there is no write door to guard.

**Legal writers checked BEFORE the constraint was written:** `add_customer_contact_method` normalizes
already; `merge_customer_identity` only DELETEs exact duplicates and sets `is_primary = false`, and
**never writes `value`**. Existing rows: 0 violations.

Also: `supabase/tests/79_customer_data_integrity_test.sql` (19 assertions) and
`scripts/verify_journey_branches.ps1` (+11 assertions, 42 → 53).

---

## 9. Measurement attacks

**Both new protections attacked by defect injection** inside savepoints: drop
`customer_contact_methods_value_normalized_check` → the denormalized INSERT **succeeds** and produces
**two rows for one logical address** → roll back → refused again.

**Negative controls on the fixes themselves**, so neither over-reaches: an already-canonical value
still inserts by direct DML; and a placement that has **already ended** is still excluded — the
widened window did not become "any placement ever".

**Measurement errors this session, all mine, none turned into findings:**
1. I referenced `customers.branch_id`; the real column is `first_registered_branch_id`. Aborted a
   transaction; corrected after reading `information_schema`.
2. An earlier probe assumed a `claim_conversion_deliveries` signature — carried forward as a caution
   and avoided here by listing signatures before calling them.

**Guard limitation restated:** the contract's `http` column is a **repository** fact measuring source
text (VER-1). API-3 moving to 65 shows the suites *reference* these endpoints; the 339/339 execution
result below is what shows they *ran*.

---

## 10. Verification executed THIS session

| Step | Result |
|---|---|
| `npx supabase db reset` | exit 0, **172** migrations |
| pgTAP **Pass A** | **79 files / 1,028 assertions / PASS** |
| **Six HTTP suites** | **339 passed, 0 failed** — 29 · 102 · **53** · 66 · 38 · 51 |
| pgTAP **Pass B**, no reset, under residue | **79 / 1,028 / PASS** = Pass A |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Local function surface | `30517b7fc2b2a0c9bde7d9501e1189ac` (238) |
| Local structural surface | `357201713e65491bc01d2c03b70bf55b` — **3,356** objects |
| Parity guard | **exit 1 — PRIMARY DRIFT, correct and intended** |
| API contract | regenerated: **65 of 71** with HTTP evidence; Check L3 "matches the live surface" |
| Repository guard | CLEAN, 13/13 |

Nothing above is copied from a previous session.

---

## 11. Primary status

Read three times, written zero times. **169 migrations**, latest `202607058000`. Repository and local
are at 172. **Drift by three migrations is intentional** and pending owner approval; the parity
guard's exit 1 is the correct verdict and must not be resolved by any means other than an approved
deployment. Repository ↔ local parity is CLEAN.

---

## 12–13. SSOT changed, and deliberately unchanged

| File | Action | Why |
|---|---|---|
| `manifest.md` | **UPDATED** | Owns live state. Also **trimmed** — the enumerated list of remaining API-3 endpoints was removed as a restatement of a generated fact (REG-2 pattern); `MASTER_API_CONTRACT.md` owns that column. 6,948 chars. |
| `MASTER_GAP_REGISTER.md` | **UPDATED** | Owns finding status/evidence: PLACE-1, CM-2, CM-1, PLACE-2. |
| `MASTER_EXECUTION_PLAN.md` | **UPDATED** | Batch 6 package narrative (AUD-03). |
| `MASTER_API_CONTRACT.md`, `ai-map.json` | **REGENERATED** | Never hand-edited. |
| `reports/README.md` | **UPDATED** | Latest-session pointer. |
| `32_execution_roadmap.md` | **UNCHANGED** | No phase, order or gate changed. |
| `03_company_structure.md`, `05_customer_identity.md`, `24`, `31` | **UNCHANGED** | Canon was the **authority consulted**, not the subject. No canon rule invented or altered. |
| `MASTER_CERTIFICATION_STATUS.md` | **UNCHANGED** | Certification and gate unchanged. |
| ADR log | **UNCHANGED** | No new architectural decision. |

---

## 14. UNPROVEN

- **All three migrations on Primary** — never deployed, never exercised there.
- **PLACE-2**.
- **n8n** — not contacted this session.
- `storage-executor` Edge Function execution — carried forward, untouched.

## 15. Blockers

**One, and it is not engineering:** deployment approval for `202607058100`, `202607058200`,
`202607058300`. Nothing else is blocked; API-3 continues against local.

## 16. Position

Phase 8, IN PROGRESS · Batch 6 · Foundation Completion gate **SHUT** · certification **CONDITIONAL**
· Active CR **None** · 29 open owner decisions, **unchanged — this session created none**.

---

## 17. Next executable step

**FACT:** API-3 has **6 endpoints** without HTTP evidence, named by `MASTER_API_CONTRACT.md`:
`assign_task` · `financial_documents` · `link_internal_supplier` · `redeem_license_token` ·
`tenant_capabilities` · `upload_subscription_payment_proof`.

**RECOMMENDATION (sequence, not an owner decision):** take the **subscription/licensing group next —
`redeem_license_token`, `upload_subscription_payment_proof`, `tenant_capabilities`** — the largest
coherent remaining group. It carries known recorded history worth auditing rather than assuming:
**LIC-1** (a refused redemption is not audited — a stated limitation), **PP-1** (`reviewed_by`
references `public.users`, which holds no platform identity) and **SPP-3**, all already in the
register.

**OWNER DECISION, unchanged and not auto-approvable:** committing and deploying the three verified
migrations to Primary.
