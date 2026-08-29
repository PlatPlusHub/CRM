# ORVION — BOOK-1: Three Endpoints That Already Had HTTP Evidence, and Still Hid a Defect

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Scope: API-3, the booking/passenger family — `create_booking_item`,
`link_passenger_to_booking_item`, `advance_booking_item` audited by capability rather than status
code. Migration `202607057700` (BOOK-1). Test `74_booking_item_lifecycle_test.sql` (16). Eight HTTP
assertions added to `verify_journey_branches.ps1`. Deployed to Primary, verified, pushed.
Status: Complete.

**Branch:** `main` · **Start HEAD:** `eaf2f14` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. The correction this package begins with

The previous report named the booking/passenger group as "the next family by dependency" for API-3's
25 uncovered endpoints. **That was wrong on the facts.** All three endpoints — plus `create_booking`
and `create_passenger` — already carried HTTP evidence, and none of them is among the 25.

The audit was run anyway, because the directive is explicit that a 200 is not evidence of a
capability. **It found a High-severity money defect behind endpoints that had been "covered" for
weeks**, which is the strongest available argument for that rule.

The genuinely uncovered 25, enumerated from the contract rather than remembered:

```
activate_membership add_customer_contact_method advance_marketing_campaign assign_lead_round_robin
assign_task assign_user_branch create_department create_marketing_campaign create_tenant_user
current_placement financial_documents find_customer_duplicates lead_booking_readiness lead_origin
link_internal_supplier my_memberships my_trusted_devices reassign_lead record_offline_conversion
record_trusted_device redeem_license_token revoke_trusted_device revoke_user_role
tenant_capabilities upload_subscription_payment_proof
```

---

## 2. BOOK-1 — a closed booking could earn new revenue

`app.create_booking_item` refuses to add an item to a booking that is archived, completed or
cancelled. `app.link_passenger_to_booking_item` refuses to attach a passenger to an item on such a
booking, or to an item that is itself cancelled, no_show or archived. **Each rule lived in exactly
one function.**

Reproduced as an ordinary `employee` holding `CREATE_BOOKING_ITEM`, `ENTER_COST` and
`ENTER_SELLING_PRICE` — *the same permissions the RPC charges* — against a booking driven to
`cancelled` through the legal RPC path:

```
RPC  create_booking_item          -> REFUSED 'cannot add items to a cancelled booking'
DIRECT INSERT into booking_items  -> SUCCEEDED
                                     selling 5000, cost 3000, on a CANCELLED booking
                                     gross_profit 2000, commission_rate 0.10 auto-derived
events 'booking_item_created'     -> 0        (the direct path emits nothing)
RPC  link_passenger…              -> REFUSED 'cannot add a passenger to an item on a cancelled booking'
DIRECT INSERT into …_passengers   -> SUCCEEDED, overrides 999 / 111
```

**Why it is money and not tidiness.** The ratified rules are `gross_profit = selling − cost` and
`employee_commission = max(gross,0) × 10%`, and `commission_rate` is *system-derived* precisely so a
caller cannot choose it — `booking_items_derive_commission_rate` set it to 0.10 without being asked.
Nothing derives the *booking's* state into that calculation. So a trip that never happened
contributed 2,000 of gross profit and 200 of commission, while the booking beside it still read
`cancelled`. And because `booking_item_created` is emitted by the RPC rather than by a trigger, the
whole thing was **unaudited**.

### Why the guards did not gate it

`booking_items` carries nine triggers and none of them is a capability guard. The permission lives in
the RLS `WITH CHECK`, which is SEC-3's model — but what that policy actually requires is
`EXISTS (select 1 from bookings b where b.id = booking_items.booking_id)`: **the parent must be
visible, not the actor permitted.** And `guard_booking_item_financials` charges `ENTER_COST` /
`ENTER_SELLING_PRICE` only when the amounts are non-zero, checking scope against
`new.sales_owner_user_id` — *a value the caller supplies*. An employee naming themselves is in scope
by construction.

---

## 3. The fix, and the three decisions inside it

A BEFORE INSERT OR UPDATE trigger on each table, carrying the RPC's own rules verbatim. **No business
policy was invented** — every refusal is copied from the function that already refused it.

**1. Plain BEFORE triggers, not deferred constraint triggers.** This is where BOOK-1 differs from
FIN-8/FIN-10: their invariants are true only *between* statements. This one holds at every instant.
Creating a booking, adding items and *then* cancelling it is ordinary and legal; only the reverse
order is the violation. A deferred trigger would have failed the legal order at commit.

**2. Deliberately asymmetric with FIN-10.** That one had to guard *both* sides of its inequality,
because an invoice total can shrink beneath its allocations. Here the mirror case — cancelling a
booking that already carries items — is **correct business behaviour**. So there is no trigger on
`bookings`, and assertion 8 pins that as a decision rather than an omission.

**3. `SECURITY DEFINER`, and therefore a mandatory `REVOKE`.** The check reads the *parent's* state,
and both parent tables carry RLS. Under INVOKER the trigger's own SELECT would be filtered by the
caller's row scope, so a caller who cannot *see* the parent would hit `not found`, fall through, and
be **allowed** — the guard would be weakest against exactly the caller it most needs to stop.

**No session-less exemption** (SEC-1 Refinement 2): `guard_booking_item_financials` exempts
`auth.uid() is null` because it is *authorization*; this is *integrity*, and an item attached to a
cancelled booking is equally incoherent whether a tenant user or a migration created it.

### What the SEC-1 clause-3 filter would have missed, and why that matters

BOOK-1 is **not** the aggregate-across-rows subclass. The rule compares a row to **another row in
another table**, which a CHECK cannot reference and a foreign key cannot qualify. SEC-1's operational
test — *"a rule comparing an aggregate across rows cannot be a CHECK"* — would **not** have found
this. That filter is a lead, not a sieve, and this is the evidence for saying so.

---

## 4. Consumer sweep (`AGENTS.md §3 5b`)

**Q1, what now meets the new rule:** `pg_proc` was searched rather than assumed —
`app.create_booking_item` and `app.link_passenger_to_booking_item` are the **only** functions that
insert these tables. No cron job, batch path or integration writes them, so the no-exemption trigger
has exactly one legitimate caller each, and both already perform the check.

**Q2, what consumes the changed shape:** nothing — this package adds triggers and changes no
structure. Ten pgTAP files insert `booking_items` directly; all were checked for a closed parent
before the migration was written, and the full suite then confirmed it.

---

## 5. Two failures on the way, both recorded because both are the lesson

**`10_grant_model_test.sql` assertion 5 failed on the first run.** `CREATE FUNCTION` grants EXECUTE
to PUBLIC by default, and a SECURITY DEFINER function left public is a privilege hole. An existing
guard caught a real regression introduced by a security fix — exactly what it is for. Two `revoke`
statements added.

**My HTTP "positive control" was not positive.** It linked a passenger to `$itemId`, the baseline
item — which the refund branch earlier in that same suite had already *cancelled*. The RPC refused
for the entirely correct reason, and the assertion pair caught it (`links=0`). The control now
creates a fresh open booking and item, and the cancelled item became a *separate* assertion for the
item-level rule, which is a different rule from the booking-level one.

---

## 6. Verification

| Axis | Result | Evidence class |
|---|---|---|
| Migrations | **166** — repository, local, Primary (`202607057700`) | all three read |
| Ledger fingerprint | `cf3adb11558035c84c578ba529678c13` | read independently from both |
| Function surface (235) | `ec0747d1a0b90d732b7f42d8cfb10e4f` | read independently from both |
| Structural surface (3,345) | `8d517aeaafc22a1652d7bcbe75a4c996` | read independently from both, ten surfaces |
| pgTAP **Pass A** | **74 files / 921 assertions / 0 failures** | local, fresh reset |
| pgTAP **Pass B** | **74 files / 921 assertions / 0 failures** | local, post-HTTP residue |
| End-to-end HTTP | **267/267** across six suites (was 259) | local over the wire |
| Smoke | `ALL CHECKS PASSED (75 tables …)` | local |
| Repository guard | **CLEAN**, 12 checks | files only |
| Parity guard | **CLEAN exit 0**, all three Primary values read live | local ↔ Primary |
| API contract | 71 endpoints, **46 with HTTP evidence — unchanged** | repository |

`apply_migration` stamped its own version; the ledger row was normalised to `202607057700`
(GUARD-1). Ledger fingerprint read *after* normalisation.

**API-3 remains at 25.** This package added eight HTTP assertions but no newly-covered endpoint,
because the three it audited were already covered. Saying so keeps the number honest.

---

## 7. Classification

**PROVEN DEFECT (fixed)** — **BOOK-1** (High, financial integrity + audit completeness).
**OPEN (recorded, not invented into a rule)** — **BOOK-2**: `booking_item_passengers.selling_amount_override`
and `cost_amount_override` are written by the RPC and **read by nothing** — no reporting view, no
profit function, no commission path (verified against `pg_proc` and `pg_views`). Whether the
per-passenger overrides must sum to the item's amounts is a genuine business question that cannot be
derived, and there is no consumer to make it urgent. Recorded rather than guessed.
**UNPROVEN** — nothing new.
**No business policy invented; no schema structure changed.**

---

## 8. Next executable step

**API-3, the canon-34 identity family** — `my_trusted_devices`, `record_trusted_device`,
`revoke_trusted_device`, `my_memberships`, `activate_membership`. Chosen on evidence: SEC-1's
inventory found exactly **three** writable tables with no governing trigger at all
(`otp_challenges`, `totp_enrollments`, `trusted_devices`), classified INTENTIONAL because they are
owned by `auth.uid()` rather than by a tenant permission. That classification has never been tested
over HTTP, and it is the only ungoverned writable surface in the system.

**Evidence the next session must verify first:** re-read all three Primary hashes live (never pass
the repository's own values back to the guard), and `db reset` before reading any structure from
local.

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut. **SEC-1 still awaits owner ratification**; nothing is blocked
on it.
