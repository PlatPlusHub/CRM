# Change Request — SPEC-145

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Enforce the finance permissions at the table, so they hold when the RPC is bypassed — and repair the
finance-visibility defect SPEC-137 introduced.

---

## Business Reason

`authenticated` held INSERT and UPDATE on every finance table, and none carried anything but a tenant
check. An ordinary employee could, with plain SQL:

- set the company exchange rate — silently changing what every multi-currency booking cost;
- create an exchange-rate adjustment;
- write journal entries and edit the chart of accounts;
- UPDATE their own `approval_requests` row to `approved`, self-approving a refund, discount, booking
  override or manual price change;
- write `booking_items.cost_amount` and `commission_rate` — they cannot *read* them after SPEC-139,
  but column grants are independent: withholding SELECT never withheld UPDATE;
- clear `cost_locked_at`, defeating cost locking entirely;
- set `finance_approval_status_code` to `approved` without ever calling `app.review_finance_approval`.

Six permissions (`SET_EXCHANGE_RATE`, `CREATE_EXCHANGE_RATE_ADJUSTMENT`, `REVIEW_APPROVAL_REQUEST`,
`ENTER_COST`, `ENTER_SELLING_PRICE`, `EDIT_LOCKED_COST`) were enforced nowhere at all; two more
(`CREATE_JOURNAL_ENTRY`, `APPROVE_FINANCE`) only inside an RPC nothing obliged anyone to call.

**A second defect was found while testing this one.** A finance manager holding `APPROVE_FINANCE` and
`VIEW_FINANCIAL_DOCUMENTS` could see **zero bookings and zero booking items** — they own no records,
belong to no sales department, and hold no `VIEW_BRANCH_DATA`. `app.review_finance_approval` is
SECURITY INVOKER, so it could not find the item it was approving: the finance-approval workflow was
broken for the only role canon puts in charge of it. Test 21 did not catch this because it asserted
only that finance could read *invoices* — which was exactly the clause SPEC-137 had written, so it
could not have failed.

---

## Risks

Moderate; the risk is lockout, not exposure. Three mitigations:

1. Each permission is taken from canon 28, not chosen. `ENTER_COST`, `ENTER_SELLING_PRICE` and
   `CREATE_BOOKING_ITEM` are held by the same five roles, so guarding the costing columns cannot lock
   anyone out of creating an item they are entitled to create.
2. Every assertion in test 29 is adversarial — a real authenticated user attempting the write
   directly — and every denial is paired with the corresponding permitted case.
3. The guard exempts callers with no `auth.uid()`. `service_role` and migrations are placed outside
   per-table enforcement by canon 35 §6, and the exemption cannot be abused: without a resolved
   identity a tenant user fails `tenant_id = app.current_tenant_id()` on every policy and cannot
   reach a row at all.

---

## Supersedes / Depends On

Repairs a defect introduced by SPEC-137. Corrects an over-broad rule in SPEC-144 (see Notes). Closes
8 of the 17 permissions the previous programme left enforced nowhere.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052400_financial_write_authority.sql`
- `supabase/tests/29_financial_write_authority_test.sql`
- `supabase/tests/21_read_scope_model_test.sql` (regression assertion for the finance-visibility defect)
- `supabase/tests/28_document_scope_test.sql` (corrected semantics — see Notes)
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-145-financial-write-authority.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- Every finance RPC — each already authorizes correctly; the defect was that the table did not

---

## Minimum Reading List

- `_ORVION_CANONICAL/28_permissions_matrix.md` §Finance Permissions and §Document Permissions
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` §6
- `supabase/migrations/202607051400_read_scope_model.sql`

---

## Implementation Steps

1. Permission-gated write policies on `exchange_rates`, `exchange_rate_adjustments`,
   `journal_entries`, `journal_entry_lines`, `chart_of_accounts`.
2. `approval_requests`: INSERT open to the tenant, UPDATE gated by the type-dependent permission
   canon 28 specifies. `subscription_payment_proofs` UPDATE gated by `REVIEW_SUBSCRIPTION_PAYMENT`.
3. `app.guard_booking_item_financials` trigger — column-level authority for cost, selling price,
   commission, cost lock and finance approval status.
4. Extend the `bookings` / `booking_items` read scope with the finance clause.
5. Separate travel from financial documents so the finance clause cannot leak passports.
6. Verification check: test 29 (adversarial), plus regression assertions in tests 21 and 28.

---

## Acceptance Criteria

- [x] An employee cannot set an exchange rate, write a journal entry, or edit the chart of accounts.
- [x] An employee cannot approve their own approval request.
- [x] An employee cannot write a cost even on an item they can see.
- [x] A senior employee can enter cost and price while unlocked.
- [x] A senior employee cannot lock the cost, unlock it, or mark it finance-approved.
- [x] After finance locks it, the same senior employee can no longer edit the cost.
- [x] Finance can still correct a locked cost.
- [x] MFA composes with the guard on the direct path.
- [x] A finance manager can reach the bookings whose finances they govern.
- [x] Finance sees financial document types, not travel documents.
- [x] Clean `db reset` replays; full suite passes (`Files=29, Tests=253`); smoke passes.
- [ ] **UNVERIFIED — Primary.** MCP disconnected, no linked project, no access token. Not applied to
      Primary; parity not confirmed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Final Foundation Hardening)

Outcome: Complete

Applied. `db reset` replays 113 clean; suite `Files=29, Tests=253 ... PASS`; smoke `ALL CHECKS PASSED`.
Permissions enforced nowhere: **17 → 9**.

Three defects surfaced during the work itself, each by a test rather than by review:

1. **`cost_amount` and `selling_amount` are NOT NULL DEFAULT 0.** The first draft required
   `ENTER_COST` whenever the column "is not null" — which is never false — so creating a bare booking
   item demanded a finance permission. Existing test 25 failed instantly. Entering a cost means
   entering a *non-zero* one; zero is the absence of a figure.
2. **The guard fired for `postgres` and `service_role`.** Test 20 failed. Canon 35 §6 places platform
   access outside per-table enforcement, so callers with no `auth.uid()` are exempt.
3. **The finance manager's lock silently did nothing.** Test 11 passed via `lives_ok` while matching
   zero rows — the same silent-UPDATE behaviour SPEC-138 recorded. Chasing it found the real defect:
   finance could not see bookings or booking items at all.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Final Foundation Hardening)

Verdict: Confirmed Complete

Findings: the three-actor fixture is what makes test 29 evidence rather than decoration. A
two-actor test (employee vs finance) would have passed against a rule that simply blocked everyone
below finance from touching a cost — and that rule would be wrong, because canon 28 gives
`ENTER_COST` to five operational roles. The `senior_employee` in the middle proves the *lock* is what
moves the cost out of operations' reach, not the role: the same user who edits the cost in assertion 7
is refused in assertion 13, and the only thing that changed between them is that finance locked it.

Assertion 14 is the one that keeps the mechanism honest. Without it, a senior employee could clear
`cost_locked_at` under no permission and then edit the cost under `ENTER_COST`, making
`EDIT_LOCKED_COST` unreachable in practice — the guard would have looked correct and enforced nothing.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state (local; Primary deployment outstanding).

---

## Notes

**Approval basis.** Owner directive 2026-08-24 (second directive) §3 ("Do not consider a permission
complete merely because the RPC checks it. The database must remain safe if the RPC is bypassed") and
§12 (financial model audit).

**This corrects an over-broad rule in SPEC-144.** That CR granted finance *any* confidential document,
reading the flag as "sensitive, therefore finance". Canon 28 separates `VIEW_FINANCIAL_DOCUMENTS`
(Finance Manager: Yes) from `VIEW_TRAVEL_DOCUMENTS` (Finance Manager: *Optional*, not granted)
precisely so that seeing the money does not mean seeing the passport. Finance now gets financial
document *types* — `invoice`, `receipt`, `quotation` — confidential or not, and no travel documents.
`contract` and `other` are deliberately not classified as financial: they are ambiguous, and canon's
note that "Financial documents require stricter visibility" supports the fail-closed reading.

**`chart_of_accounts` borrows `CREATE_JOURNAL_ENTRY`.** Canon 28 names no permission for it. It is the
ledger's structure, and a journal entry cannot exist without the accounts it posts to, so the
authority that governs entries governs the accounts they use. `CREATE_JOURNAL_ENTRY` is held by
exactly the three roles canon puts in charge of the ledger. This borrows an existing authority rather
than inventing one; a dedicated permission would be a canon change, not an implementation decision.
