# ORVION — ATTR-2: The Hand That Records Is Not Always The Hand That Acted

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Scope: ATTR-2 — the complete actor-attribution class. Six columns reproduced and closed by
`202607059300` (deployed to Primary); three left deliberately unfixed with reasons; the class
detector replaced because it was blind in two independent ways.
Status: Complete.

**Branch:** `main` · **Start HEAD:** `eadd526` · **Environment:** repository = local = Primary,
181 → **182** migrations.

---

## 1. TRUTH RE-ESTABLISHED FIRST

Measured, not carried forward: HEAD `eadd526`, tree clean · **181** migration files, latest
`202607059200` · **86** test files · guard **CLEAN at 15 checks** · local ledger
`181|67a9e05e43c733594a76dd7e6ce6da31`, matching the manifest.

One correction happened here and it is worth recording. A first ad-hoc ledger query returned
`a544a57e…`, which looked like drift against the manifest's `67a9e05e…`. It was not drift: the guard's
fingerprint is `md5(version || '_' || name)` and the ad-hoc query hashed `version` alone. **Two
measurements of "the ledger" that are not the same measurement** — PAR-1a's exact shape, caught this
time by re-reading the guard's own SQL before reporting anything. Re-measured with the guard's
definition: identical.

## 2. DISCOVER — the inventory was derived, never listed

The register's ATTR-2 row named eight columns. The directive forbids trusting a hand list, and the
list turned out to be wrong in **both** directions.

The catalog sweep found **49** columns ending `_by` across 42 tables. But the `_by` suffix is itself a
name pattern, so the real predicate used was **structural**: every FOREIGN KEY to `public.users`, on a
table `authenticated` can write directly, with no BEFORE trigger deriving it. That returned **28**
columns, and reading each one individually split them apart:

| Verdict | Columns |
|---|---|
| **Caller identity — closed** | `payments.received_by` · `customer_identity_merges.merged_by` · `booking_items.cancelled_by` · `booking_items.no_show_recorded_by` · **`lead_interactions.user_id`** · **`customers.first_registered_user_id`** |
| **Assignment target — correctly caller-supplied, NOT an actor** | every `*owner_user_id` (7 tables) · `leads.assigned_user_id` · `lead_assignments.assigned_user_id` · `user_branch_assignments.user_id` · `user_role_assignments.user_id` |
| **Identity binding — governed elsewhere** | `users.auth_user_id` (IDENT-1/ADMIN-1) · `otp_challenges` · `totp_enrollments` · `trusted_devices` |
| **Unimplemented capability — deliberately not derived** | `invoices.voided_by` · `journal_entries.voided_by` (VOID-1) · `payments.verified_by` (**VERIFY-1**, new) |
| **Dead structure** | `customers.last_interaction_user_id` (**DEAD-3**, new) |
| **Unreachable by any tenant caller** | `tenant_license_activations.consumed_by` — granted to `postgres` and `service_role` only |

**The two in bold were never in the register's list**, because they carry an actor without a `_by`
suffix. That is ASGN-2's lesson for the fourth time: `lead_assignments` carried `created_by`'s meaning
under a different name, and no name-shaped sweep could see it.

## 3. TRACE — the finding is one sentence

Every one of the six closed columns has **exactly one producer**, that producer **already recorded the
caller**, and **none of them accepts an actor as a parameter**. `app.record_payment` and
`app.record_supplier_payment` set `received_by = created_by = v_actor`; `advance_booking_item`,
`merge_customer_identity`, `record_lead_interaction` and `create_customer` all do the same for theirs.

So the RPC door was never wrong. `authenticated` also holds the TABLE grant, and the second door
accepted an actor the first door never offered — a value **unreachable through any authorized path**.
That makes it forgery rather than a business fact, which is what settled the classification.

## 4. REPRODUCE — six scenarios, each with live positive and negative controls

| | Attack | Result before the fix |
|---|---|---|
| **A** | finance_manager (holds RECORD_PAYMENT) inserts a payment naming the employee as receiver | `received_by = Employee` while `created_by = Finance` — **one column derived, the other accepted verbatim, in the same statement** |
| **B** | employee (holds nothing) changes only `received_by` | refused `42501` on `amount`, then **`UPDATE 1`** on `received_by` — `guard_financial_capability` watches `amount` and nothing else |
| **C** | the assigned handler records a call attributed to the owner | `Owner` — `guard_lead_interaction_authority` asks *whether* the write is allowed, never *who* is recorded |
| **D** | employee creates a customer registered to the owner | `first_registered = Owner`, `created_by = Employee`; the column is frozen only on UPDATE, so it merely **looked** governed (ASGN-2's shape) |
| **E** | owner (holds MERGE_CUSTOMER_IDENTITY) records the merge as performed by the employee | `Employee` |
| **F** | employee **without** CANCEL_BOOKING stamps both action columns on an item still `confirmed` | `Owner`, `Owner`, status `confirmed` — an attribution for a cancellation that never happened |

Every negative control fired (amount refused, non-handler refused, employee refused MERGE), so none of
these is an authorization defect. **Authorization was never affected; the audit trail was.**

## 5. THE PAYMENTS SPECIAL CASE — answered by measurement, not by the suffix

The register had flagged `payments.received_by` as possibly a legitimate business fact — "which staff
member physically received the cash, recordable on another's behalf". It is not one **today**, and the
evidence is specific rather than rhetorical:

- **FACT** — both writers set `received_by = created_by = v_actor`; neither has an actor parameter, so
  the two columns are *always identical* through every authorized path.
- **FACT** — no view and no function READS the column. It has no consumer.
- **FACT** — canon 31 says only "received_by nullable". No cash-custody or on-behalf model exists.
- **FACT** — `RECORD_PAYMENT` is the only payment permission; **no `VERIFY_PAYMENT` exists at all**.

So "Employee A receives the cash, Employee B records it, Employee C verifies it" is **not expressible
in ORVION**. Deriving the caller therefore changes nothing any authorized path can do — it makes the
second door agree with the first. If the separation is ever wanted it is a *new capability* with a
parameter and a permission, and the trigger is amended then; that is stated in the migration so the
choice stays visible rather than silently foreclosed.

**`payments.verified_by` went the other way.** Nothing writes it, no permission to perform the act
exists, and canon 07 *does* define a two-person money workflow — "Finance verifies the bank account" —
which ORVION implements through **`approval_requests`**, whose `requested_by`/`reviewed_by` are already
derived. Deriving an attribution for an action nobody can perform would dress a missing capability as a
solved one, which is precisely why `202607056500` refused to do it for `voided_by`. Recorded as
**VERIFY-1** and added to the manifest's open-decision line beside VOID-1.

## 6. FIX — five dedicated derivers, and one of them ties attribution to the act

`202607059300`. `derive_payment_receiver` · `derive_interaction_actor` · `derive_merge_actor` ·
`derive_first_registration_actor` · `derive_booking_item_action_actor`. INSERT derives, UPDATE freezes;
session-less platform paths keep their own attribution (canon 35 principle 6).

**Rejected: one generic `derive_actor()` taking the column as a trigger argument.** It would be shorter
and would deliberately rebuild **MEAS-1** — a detector reading function bodies is blind to codes carried
in trigger arguments. Every existing deriver here is per-column for that reason. FX-2 also established
that widening `derive_created_by`, which twenty tables depend on, is the CUST-1 shape.

**`booking_items` is not merely re-attributed.** Re-attributing scenario F to the employee would have
recorded them as the canceller of an item that was never cancelled — one false statement traded for
another. The rule is read off the only producer: `advance_booking_item` sets `cancelled_by` precisely
when the item enters `cancelled`. Both statuses are terminal in `app.status_transitions`, so the value
is immutable once earned. The forgery is now **unrepresentable**, not corrected.

`customers.first_registered_user_id` also closed a gap the existing freeze left: it refuses a change
only when the OLD value is non-null, so a row created session-less with NULL could be filled in later
by any direct writer.

## 7. THE DETECTOR WAS WRONG TWICE — MEAS-4

`83_actor_attribution_test.sql` assertion 22 says in its own header that a hand-written list is where
the next gap hides. It was right, and its replacement was still a question about the **name**.

1. **Lexical blindness.** Proven by attack: adding `tasks.completed_by_user_id` leaves assertion 22
   reporting `tasks.created_by, tasks.archived_by` and nothing else, while the structural predicate
   names it immediately.
2. **Whitespace sensitivity.** `prosrc like '%new.<col> :=%'` returns **false** on the identical
   assignment written with aligned padding, where the regex returns **true**. This migration was first
   written with aligned assignments — **the detector would have reported its own fix as absent**, and
   the next author would have "fixed" it by un-aligning code. A guard constraining formatting instead
   of behaviour is the MEAS-1 class.

Both closed. **Assertion 23** is structural, has no exemption list, and was counterexample-tested in
both directions (a dropped deriver reappears; a new column appears; the baseline matches).

## 8. MY OWN TEST WAS WRONG TOO, AND IT MATTERED

`set_config(..., true)` is transaction-local and **survives `reset role`**. Two blocks written as
"session-less" therefore still carried the previous actor's claims. The `customers` one failed loudly.
The `payments` one would have **passed vacuously** — it asserted the owner's id, which is exactly what
a wrongly-firing trigger would also have produced. Fixed by clearing the claims explicitly, asserting a
*different* user than the lingering session held, and adding a precondition assertion. Recorded here
rather than quietly corrected, because it is the vacuous-control class `AGENTS.md §6` exists to catch.

A second self-inflicted error: three regression assertions called the RPC inside the `where` clause of
the assertion, making it a correlated subquery Postgres may evaluate per candidate row. Rewritten as
separate statements with deterministic lookups.

## 9. VERIFICATION

`npx supabase db reset` · Pass A **87 files / 1186 assertions** · six HTTP suites **371/371**
(29 + 102 + 74 + 71 + 38 + 57) · Pass B **87 / 1186**, identical · smoke
`ALL CHECKS PASSED (75 tables …)` · all three Primary values read **live FROM Primary** and identical to
local: ledger `182|18e452ceacd1fa1c405a1e7f0c1e4f57`, functions
`52e4cce73a66148df0c453fd9cca98ba` (252), structure `5d61e551b759bc661eb5633e2986ee9a` (3,383) ·
parity guard **CLEAN** · repository guard **CLEAN at 15 checks**.

**Cross-path impact sweep (§5b):** all five RPCs that legitimately write these columns still record the
same actor they recorded before the triggers existed — proven as assertions, not asserted in prose.

## 10. NOT FIXED, AND WHY

- **`invoices.voided_by` / `journal_entries.voided_by`** — VOID-1, an open OWNER decision.
- **`payments.verified_by`** — VERIFY-1, newly recorded, now on the manifest's open-decision line.
- **`customers.last_interaction_user_id`** — DEAD-3: no producer anywhere. A derivation trigger would
  manufacture an attribution for an interaction nobody records.
- **`tenant_license_activations.consumed_by`** — no `authenticated` grant; a trigger would guard a door
  that does not exist. Measured, not assumed.

## 11. NEXT STEP

**The care/conversation slice** — `complaints`, `service_requests`, `conversations`,
`conversation_messages`, `quotation_items` — per `MASTER_EXECUTION_PLAN.md` Batch 6, which owns the
order. Their write-capability half was already closed by SEC-1c.
