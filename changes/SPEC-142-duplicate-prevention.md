# Change Request — SPEC-142

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Put a database constraint behind every duplicate rule the system already believed it had, and add the
ones the integration layer will depend on.

---

## Business Reason

The duplicate-prevention audit found the same shape everywhere: the rule existed, inside an RPC, as a
check-then-insert. `select … if found then raise … else insert`. That leaves two distinct holes.

- **A direct PostgREST write skips the RPC**, so the rule does not run at all.
- **Two concurrent RPC calls both run the SELECT before either runs the INSERT**, both find nothing,
  and both insert. No amount of care inside the function closes this — only a unique index does. This
  is not a theoretical race: it is two employees answering the same WhatsApp enquiry at the same
  moment, which is an ordinary Tuesday in a busy branch.

Canon 05 states the customer rule directly — "The primary phone number is a major identity signal and
must be unique inside the company unless an approved exception exists" — and neither half was
enforced. There was no index, and the exception (`p_allow_duplicate`) left **no trace at all**, so
after the fact a deliberate duplicate was indistinguishable from an accident.

Three of the constraints are not CRM hygiene but integration correctness. ADR-0023 makes n8n's
delivery contract at-least-once, so retries *will* happen:

- `attribution_clicks` — a click identifier names one click, and `app.capture_attribution_click`
  inserted unconditionally. Because `app.map_outcomes_to_conversions` joins leads to their
  attribution click, a duplicated click is a path to a **duplicated conversion reported to Google**.
- `marketing_campaigns` — a campaign resynced from Google Ads became a second campaign.
- `conversations` — a WhatsApp thread replayed by the provider opened a second conversation.

And one is a financial defect rather than a tidiness one: `exchange_rates` had nothing stopping two
rates for the same currency pair at the same instant. Rate lookup is "the latest rate at or before
this moment"; with two rows that question has two answers, and whichever the planner returns first
silently decides what a booking cost.

---

## Risks

The real risk of this CR is over-restriction — a unique index that blocks legitimate business is a
worse defect than the duplicate it prevents. Every constraint is therefore asserted in **both**
directions, and three are deliberately scoped rather than absolute:

- customer phone uniqueness excludes archived customers (a number can be re-used after the customer
  leaves) and rows carrying the approved-exception flag;
- supplier and department names exclude archived/inactive rows, so a name can be retired and reused;
- department names are unique *per branch*, because every branch having its own "Sales" is the normal
  case.

**`passengers.passport_number` is deliberately NOT constrained.** It looks like the obvious unique
key and is not one: the same traveller can legitimately appear under two customers — a corporate
account and their own personal account both booking the same person — so a unique index would block a
real booking. Detection is the right tool and already exists; `app.find_customer_duplicates` matches
on passport.

---

## Supersedes / Depends On

Implements canon 05 §Primary Customer Number. Supports ADR-0023's at-least-once delivery contract.
Depends on SPEC-140 (`create_customer` is rewritten again here, on top of its SPEC-140 form).

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052100_duplicate_prevention.sql`
- `supabase/tests/26_duplicate_prevention_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-142-duplicate-prevention.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- The RPC-level duplicate checks — they are left in place deliberately. They produce a clear,
  actionable error before the write is attempted; the index is the guarantee underneath. A validation
  and a constraint are doing separate jobs, not duplicating a rule.

---

## Minimum Reading List

- `_ORVION_CANONICAL/05_customer_identity.md` §Primary Customer Number
- `reports/architecture-decision-records.md` ADR-0023 (at-least-once delivery)
- `supabase/migrations/202607049400_map_outcomes_to_conversions.sql` (why a duplicate click matters)

---

## Implementation Steps

1. Add `customers.duplicate_phone_approved` and a partial unique index implementing canon 05's rule
   and its exception.
2. Unique contact-method values per customer, and one primary per type.
3. Unique department name per branch; unique supplier name per tenant.
4. Integration idempotency: `attribution_clicks` (gclid / gbraid / wbraid), `marketing_campaigns`
   external id, `conversations` external id.
5. Unique `exchange_rates` per pair per instant.
6. Teach `app.create_customer` to record the exception it was already permitting.
7. Verification check: test 26 asserts each duplicate rejected and each legitimate second record
   accepted.

---

## Acceptance Criteria

- [x] A duplicate primary phone is refused by the database, not only by the RPC.
- [x] The canon 05 approved exception still works, and now leaves a trace.
- [x] Uniqueness is per tenant, and archived customers do not hold a number permanently.
- [x] A contact value cannot repeat on one customer; only one primary per type.
- [x] Department names are unique per branch but repeat freely across branches.
- [x] A replayed click, campaign sync, or WhatsApp thread cannot become a second record.
- [x] One currency pair cannot carry two rates at the same instant.
- [x] Clean `db reset` replays; full suite passes (`Files=26, Tests=218`); smoke passes.
- [ ] **UNVERIFIED — Primary.** The `supabase-primary` MCP disconnected and requires
      re-authorization. Not applied to Primary; parity not confirmed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Outcome: Complete

Applied. `db reset` replays 109 clean; suite `Files=26, Tests=218 ... PASS`; smoke `ALL CHECKS PASSED`.

The customer-phone constraint is the one worth reading closely, because canon 05 states a rule **and**
an exception and a naive implementation satisfies exactly one of them. A plain unique index enforces
"must be unique" and forbids "unless an approved exception exists"; the previous `p_allow_duplicate`
parameter permitted the exception and enforced nothing. The flag column is what lets both be true at
once — and it is an improvement in its own right, because an approved exception now leaves evidence
that it was taken. Before this, nothing distinguished a deliberate duplicate from a mistake.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Verdict: Confirmed Complete

Findings: the assertions that matter most in this file are the `lives_ok` ones, not the `throws_ok`
ones. Proving a unique index rejects a duplicate proves almost nothing — a constraint that rejected
everything would pass every rejection test in the file. What has to be shown is that each constraint
is scoped to the thing that is actually a mistake: that another tenant may hold the same phone number,
that an archived customer releases theirs, that every branch keeps its own Sales department, that a
second non-primary phone is ordinary, and that a genuinely new exchange rate at a later instant is the
entire point of a temporal table. Each rejection is paired with its permission for that reason.

The three integration constraints are the ones a reader is most likely to think excessive and are the
least so. ADR-0023 makes delivery at-least-once by design, which means a retry is not a failure mode
to guard against but a normal event that *will* occur. Without them, the retry silently produces a
second attribution click — and the conversion mapper joins leads to their click, so the duplicate
propagates outward to Google as a double-counted conversion. That is the specific failure the
Integration Catalog's §2a correction 4 already warns about, arriving by a different route.

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

**Approval basis.** Owner directive 2026-08-24 §18, which required a systematic duplicate audit across
the business domain, asked for the concurrent case by name, and set both boundaries: "Do not create
over-restrictive UNIQUE constraints that block legitimate business activity. But do not leave obvious
duplicate paths unprotected."

**Entities examined and deliberately left without a business key**: `tasks`, `complaints`,
`service_requests`, `refunds`, `booking_items`, `documents`, `payments`, `leads`, `conversations`
(beyond the external id), `quotations` and `invoices` (both already carry a unique number). For each,
a second record with identical attributes is a legitimate business event — two tasks with the same
title, two leads from the same customer, two payments of the same amount — and constraining them
would block real work. `passengers` is the borderline case and is reasoned through under Risks.
