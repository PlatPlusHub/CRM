# Change Request — SPEC-134

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Resolve RPC-2 by determining from canon which permission governs each of the four entities that have none of their own, and close their write paths with duplicate prevention and canonical contact-data normalization.

---

## Business Reason

RPC-2 recorded four employee-facing entities with no permission key among the seeded 69: `customer_contact_methods`, `customer_notes`, `suppliers`, `marketing_campaigns`. It was escalated rather than guessed, because writing an RPC against an invented permission would fabricate canon.

The evidence resolves all four without inventing anything:

| Entity | Permission | Why |
|---|---|---|
| `customer_contact_methods` | `CREATE_CUSTOMER` | Sub-record of the Customer aggregate |
| `customer_notes` | `CREATE_CUSTOMER` | Sub-record of the Customer aggregate |
| `suppliers` | `ASSIGN_SUPPLIER` | The only supplier capability canon defines, at the right scope and grantees |
| `marketing_campaigns` | `MANAGE_MARKETING_CAMPAIGN` | Already defined in canon 28's Marketing Permissions, tenant scope |

The customer sub-record answer is **not** "reuse `CREATE_CUSTOMER` because they belong to a customer" — that reasoning was explicitly ruled out by the directive. It rests on four independent pieces of evidence: `customer_id` is NOT NULL on both, so neither can exist independently; neither has a state machine in canon 26; canon 28's CRM table is granular enough to separate `SEND_QUOTATION` from `ACCEPT_QUOTATION` yet lists only `CREATE_CUSTOMER` and `MERGE_CUSTOMER_IDENTITY` for the customer domain; and **ORVION already governs sub-records by capability rather than by table** — `app.create_passenger` is authorized by `CREATE_BOOKING_ITEM`, and `app.create_customer` already writes `customer_identity_signals` under `CREATE_CUSTOMER`.

---

## Risks

Low. Additive functions on zero-row tables. The duplicate guards are new behaviour by design and are asserted in both directions — the accidental duplicate is refused, the legitimate distinct record still succeeds.

---

## Supersedes / Depends On

Depends on SPEC-126 (the normalizers), SPEC-131 and SPEC-132 (the RPC pattern). Resolves RPC-2. Third delivery against RPC-1.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607051100_master_data_write_paths.sql`
- `supabase/tests/19_master_data_write_path_test.sql`
- `supabase/tests/08_status_vocabulary_registry_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-134-master-data-write-paths.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `_ORVION_CANONICAL/28_permissions_matrix.md` — **deliberately not amended.** No permission key was invented; the whole point of RPC-2 was to determine the answer from the existing vocabulary.
- `_ORVION_CANONICAL/26_state_machines.md`

---

## Minimum Reading List

- `_ORVION_CANONICAL/28_permissions_matrix.md` §CRM / §Booking / §Marketing
- `_ORVION_CANONICAL/24_entity_registry.md` §Supplier
- `supabase/migrations/202607045500_create_passenger.sql` (the sub-record precedent)
- `_ORVION_CANONICAL/26_state_machines.md` §Marketing Campaign

---

## Implementation Steps

1. Verification check: `app.add_customer_contact_method` exists. If absent, create it under `CREATE_CUSTOMER`, normalizing by contact-method family and refusing an exact duplicate value per type.
2. Verification check: `app.add_customer_note` exists. If absent, create it under `CREATE_CUSTOMER` with no duplicate guard.
3. Verification check: `app.create_supplier` exists. If absent, create it under `ASSIGN_SUPPLIER`, normalizing phone/email and refusing a case-insensitive name duplicate.
4. Verification check: `app.create_marketing_campaign` and `app.advance_marketing_campaign` exist. If absent, create them under `MANAGE_MARKETING_CAMPAIGN`, with the canonical state machine and an external-campaign-id uniqueness guard.
5. Verification check: all six revoke PUBLIC EXECUTE and grant `authenticated`; `advance_marketing_campaign` is registered in test 08's map.
6. Verification check: `db reset` replays clean, smoke passes, suite passes, Primary agrees by fingerprint.

---

## Acceptance Criteria

- [x] Contact values are canonicalized exactly as `customers.primary_email` / `primary_phone` are.
- [x] The same address in different casing is refused; a genuinely different contact method is accepted.
- [x] The same note text can be recorded twice — repetition is a business fact.
- [x] Supplier contact data is canonicalized; a case-variant supplier name is refused.
- [x] The same platform campaign id cannot be recorded twice; the campaign *name* is not unique.
- [x] An owner **without** an `aal2` claim cannot act; the same owner **with** one can.
- [x] Suite 19 files / 121 tests PASS; smoke passes; repo = local = Primary (100 migrations).
- [x] Tables with no RPC insert path: 35 → 26.

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (foundation freeze gate)

Outcome: Complete

All steps applied. `db reset` 100 clean; smoke `ALL CHECKS PASSED`; `Files=19, Tests=121 … PASS`. Primary: ledger `1a52be27fe00fe422c5b0878793942f0`, 82 `app` functions, PUBLIC EXECUTE 0.

Test 08's completeness assertion again demanded registration of `advance_marketing_campaign` — the third time in three CRs that this guard has caught a new transition RPC before it could escape the status-vocabulary check.

Note: the unenforced-permission count does **not** move (27 before and after). That is the correct outcome and worth stating plainly — RPC-2 was never about permissions that lacked enforcement, it was about *entities* that lacked a permission. All three permissions used here were already enforced elsewhere. What changed is that four more entities now have governed write paths; the count that moved is tables-without-an-RPC, 35 → 26.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (foundation freeze gate)

Verdict: Confirmed Complete

Findings: Every assertion runs through the real authorization chain established by test 17. Two are worth singling out.

First, the duplicate assertions are deliberately paired with their opposites: the same email in different casing is refused **and** a genuinely different contact method still succeeds; the same supplier name in different casing is refused **and** the same note text can be written twice. A duplicate guard that refuses everything would pass a one-sided test while making the product unusable, and duplicate prevention is precisely where that mistake is easy to make.

Second, the MFA boundary is now proven in **both** directions for the first time: the same owner identity is refused without an `aal2` claim and succeeds with one. Previously MFA had only ever been observed failing, which does not distinguish "MFA is enforced" from "this role can never act".

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

**Approval basis.** Owner directive 2026-08-21, which required RPC-2 to be resolved through evidence rather than guesswork, explicitly forbade both reflexively reusing `CREATE_CUSTOMER` and reflexively minting `CREATE_SUPPLIER`, and granted authority to implement whatever the evidence determined.

**The supplier decision, stated honestly.** `ASSIGN_SUPPLIER` reads narrower than the capability it is being used for. That was weighed rather than waved through. Canon 24 makes Supplier a first-class entity, and mature CRM/ERP practice would give master data its own create permission — but canon 28 enumerates supplier permissions and defines exactly one, at branch/department scope, granted to precisely the roles who would add a supplier in practice (Senior Employee upward). ORVION names capabilities, not tables, and "work with suppliers" is that capability. The naming mismatch is an observation about the name, not evidence of a missing permission. If the owner later wants create and assign split, that is a canon-28 amendment; it is recorded as an option in the register rather than assumed here.

**Contact data normalization was in scope for a reason.** `customer_contact_methods.value` and `suppliers.phone`/`email` hold the same class of identity data SPEC-126 canonicalized on `customers`, and were left un-normalized only because they had no write path. Closing the write path without normalizing them would have created a second, inconsistent home for the same kind of value — reintroducing at the sub-record level exactly the defect SPEC-126 fixed at the customer level.

**Where duplicate prevention was deliberately NOT applied.** `customer_notes` has no duplicate guard: two employees recording "Called, no answer" on different days is a business fact. Campaign *names* are not unique: an agency may legitimately run "Umrah Ramadan" on Google and on Meta. Only the platform's own `external_campaign_id` is unique per tenant and platform, because recording one platform campaign twice would split its attribution and daily metrics across two rows.
