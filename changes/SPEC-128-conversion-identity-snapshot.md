# Change Request — SPEC-128

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Make the identity delivered for an offline conversion historical truth — snapshotted at conversion-creation time in every creation path — so that later customer edits and delivery retries can never change what a past business event reported to Google.

---

## Business Reason

`app.claim_conversion_deliveries` ended by joining to the live customer:

```sql
left join public.leads l      on l.id = oc.lead_id
left join public.customers cu on cu.id = l.customer_id
...  select cu.primary_phone, cu.primary_email
```

So the identity sent to Google was whatever the customer record said **at the moment of the claim**, not what was true when the conversion occurred. Three consequences, all real:

1. A customer correcting their email silently rewrites the identity of a historical business event.
2. A **retry sends different user data than the first attempt for the same `transactionId`** — the one thing an at-least-once pipeline must never do, and ORVION deliberately made delivery at-least-once in SPEC-123.
3. `offline_conversions` carried no `customer_id` at all, so a conversion could not name the customer it belonged to; identity was reachable only by traversing an optional lead.

This had to be fixed **before** the first workflow, not after: a snapshot cannot be backfilled. Once a conversion has been delivered against a since-edited customer, the identity actually sent is unrecoverable. Cost at zero rows: one migration. Cost after go-live: impossible for affected rows.

---

## Risks

Low. Additive columns on a table with zero rows; both creation paths populate them; the values inherit the canonical form SPEC-126 already enforces on `customers`, and CHECKs re-assert it here.

`claim_conversion_deliveries` keeps its **exact** `RETURNS TABLE` signature — `customer_phone` / `customer_email` remain in the same positions — so the n8n `§2` contract does not move. Only the source of those two values changes, from mutable to immutable. That was a design constraint, not a coincidence: the workflow must be built against the final data contract.

---

## Supersedes / Depends On

Depends on `changes/SPEC-126-*.md` (canonical customer identity) and `changes/SPEC-123-*.md` (the delivery lease that makes retries possible, and therefore makes retry-stability necessary). Resolves ATTR-1.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050500_conversion_identity_snapshot.sql`
- `supabase/tests/13_conversion_identity_snapshot_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-128-conversion-identity-snapshot.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations (the three RPCs are redefined forward)
- `supabase/migrations/202607050100_conversion_delivery_lease.sql`

---

## Minimum Reading List

- `supabase/migrations/202607049200_offline_conversion_core.sql`
- `supabase/migrations/202607049300_outcome_conversion_mapper.sql`
- `supabase/migrations/202607050100_conversion_delivery_lease.sql`
- `reports/master/MASTER_INTEGRATION_CATALOG.md` §2 / §2a

---

## Implementation Steps

1. Verification check: `offline_conversions.customer_id` exists. If absent, add `customer_id` / `customer_email` / `customer_phone`, the FK, the index, and the two normalization CHECKs.
2. Verification check: `app.map_outcomes_to_conversions` source contains `customer_email`. If absent, redefine it to left-join the lead's customer (tenant-qualified) and populate the snapshot.
3. Verification check: `app.record_offline_conversion` source contains `v_customer_email`. If absent, redefine it to resolve and snapshot identity from the supplied lead, re-checked against the caller's tenant.
4. Verification check: `app.claim_conversion_deliveries` source contains `oc.customer_phone`. If absent, redefine it to read the snapshot and drop the leads/customers joins, leaving the signature unchanged.
5. Verification check: `db reset` replays clean, smoke-test passes, full suite passes, Primary agrees by ledger fingerprint.

---

## Acceptance Criteria

- [x] Editing a customer after conversion creation does **not** change the identity delivered for that conversion.
- [x] The stored snapshot is unaffected by the customer edit.
- [x] The live customer and the snapshot genuinely diverge (so the assertion is not vacuous).
- [x] A retry delivers the **same** identity as the first attempt.
- [x] The retry really is attempt 2 (so the previous criterion is not trivially true).
- [x] A conversion with no customer identity is still delivered on its click ID alone.
- [x] A conversion cannot snapshot another tenant's customer.
- [x] Non-normalized email / formatted phone snapshots are refused.
- [x] `claim_conversion_deliveries` signature unchanged; full suite passes; repo = local = Primary.

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (foundation gate)

Outcome: Complete

Steps 1–4 applied; step 5 verified. `db reset` replays clean, smoke-test `ALL CHECKS PASSED`, suite green, Primary at ledger `faa7b09f6ab8331a693b4d76b26880d2` with the three snapshot columns present.

The tenant-isolation criterion initially **failed** — a conversion in tenant B could snapshot tenant A's customer, because the single-column FK checked existence, not tenant. That failure was not patched locally; it was recognised as an instance of a systemic defect and escalated into its own change (SPEC-129 / TENANT-1), after which this criterion passes for the right reason rather than by a special case.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (foundation gate)

Verdict: Confirmed Complete

Findings: Verified behaviourally, not structurally. The decisive test mutates the customer **after** the conversion exists and then calls the real `claim_conversion_deliveries`, requiring the pre-edit value — and is paired with an `isnt()` assertion proving the live customer and the snapshot actually diverged, so the test cannot pass vacuously. Retry stability is asserted the same way and paired with an attempt-number check. The null-identity case is asserted positively (still delivered, click ID present) rather than merely "does not error".

One prior claim of mine was corrected during this work: I had described ATTR-1 as also meaning "a booking for a walk-in customer yields a conversion with no identity". That is wrong — `map_outcomes_to_conversions` inner-joins `leads` and requires `attribution_click_id is not null`, and `claim` inner-joins `attribution_clicks`, so no such row is ever created or claimed by the automated path. The real defect was solely the mutable-identity half, which is what this CR fixes.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state.

---

## Notes

**Approval basis.** Owner directive 2026-08-21 ("Full System Health, Coherence & Long-Term Readiness Gate"), which instructed explicitly that ATTR-1 be implemented rather than registered, and that "non-blocking for n8n" is not a disposition.

**Denormalization is deliberate.** `customer_email` / `customer_phone` duplicate data that also lives on `customers`. That is the point: they are not a cache of the current value, they are the record of a past one. `customers` remains authoritative for *who the customer is now*; `offline_conversions` is authoritative for *what was reported to Google then*. The column comments state this so a future reader does not "fix" the duplication.
