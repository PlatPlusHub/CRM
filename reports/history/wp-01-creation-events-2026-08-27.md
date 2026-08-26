# ORVION — WP-01: Creation-Event Completeness

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: WP-01 (migration `202607053300`), plus the governance rules the owner ratified this session
and the mandatory cross-path impact sweep that followed the package.

Predecessor: `wp-03-post-package-discovery-2026-08-26.md`.

---

## STATUS — **EARNED → CLOSED**

## GOVERNANCE CHANGED FIRST (owner-ratified 2026-08-27)

Two rules were written into `AGENTS.md` **before** WP-01 began, both earned by WP-03's failures:

* **§3 step 5b — Cross-path impact sweep, mandatory before EARNED.** A package can pass every one of
  its own acceptance criteria and still break a different execution path. Triggered by any change to
  a trigger, policy, permission, grant, SECURITY DEFINER function, enforcement rule, event writer,
  immutable field or scope. Requires classifying every affected path (single-tenant interactive ·
  multi-tenant system · batch/set-based · scheduled · integration · administrative) and proving each
  class separately — multi-tenant/batch must prove one restricted tenant cannot abort another's
  processing; single-tenant must prove the error still reaches the caller. Explicitly forbids
  weakening a gate to accommodate a system path: the system path decides eligibility and **skips**,
  the gate stays the backstop.
* **§6 — No vacuous security tests.** A test that can pass with zero affected rows is not an earned
  security test. Requires proving the actor holds the capability, the target row is visible, and the
  positive operation actually changed something, before asserting any denial.

## DISCOVERED (WP-01 pre-flight, all live introspection)

The candidate list from the previous report was **re-derived, not trusted**, and came back confirmed:

* 26 `*_created` types registered, **all active**; **10 referenced by no `app` function at all.**
* Of those 10, exactly **four** have a producer that really inserts the entity:
  `customers`/`create_customer`, `leads`/`create_lead`, `passengers`/`create_passenger`,
  `trusted_devices`/`record_trusted_device`. The other six have **no producer** and were left alone —
  inventing one would fabricate capability (WP-02's triage).
* Each of the four tables has **exactly one** inserting function, so there was no second path to
  double-emit from, and **no existing trigger** on any of them emitted an event.

**D1 — `record_trusted_device` is UPSERT-shaped.** It UPDATEs a known device and only INSERTs when
none matched. An in-function `perform record_event` would have emitted `trusted_device_created` on
**every re-login from a known device**, forging repeated "creations" into an append-only spine.

**D2 — `create_passenger` is gated on `CREATE_BOOKING_ITEM`, which the ordinary `employee` role does
not hold.** Found because the test failed with `permission denied: CREATE_BOOKING_ITEM`. Registering
a traveller is a plausible day-one employee action, so this belongs to the open "employee is
intake-only" question — recorded, **not** silently fixed by granting a permission.

**D3 — Canon says `customer_created` fires "when a customer record is approved"** (canon 27), but no
customer-approval workflow exists; creation is the only reachable point. Emitted at creation, gap
recorded rather than a workflow invented.

## CONSUMER TRACE (mandatory before touching the spine)

* **`app.map_outcomes_to_conversions` — verified against the live function body:** its filter is
  `('lead_qualified','booking_created','payment_recorded','booking_issued')`. **None of the four new
  types appears**, so none becomes eligible for Google conversion mapping and the n8n contract is
  unchanged. This was the specific risk flagged in the previous report; it is now closed by evidence.
* `app.customer_timeline` / `app.lead_timeline` gain the creation event — the intended win.
* The `events` read policy dispatches `customer`, `lead`, `passenger` to the subject table's own RLS,
  so each new event is readable exactly when its subject is.
* `trusted_device` is **not** in that dispatch and falls to `ELSE false`. Left deliberately: the
  policy's actor exemption already shows the device's owner their own event and tenant-wide readers
  see it, so adding a branch would widen SPEC-143's policy for no visibility gain. Canon 27 marks the
  event `Severity: security`, and it is emitted at that severity.

## MECHANISM — trigger, not RPC line

`AFTER INSERT` triggers calling one new `app.emit_creation_event()` (SECURITY DEFINER,
`search_path = ''`, `revoke execute … from public`).

Chosen because **SEC-1 is still open**: `authenticated` retains direct INSERT on these tables, so an
event emitted inside the RPC would be skipped entirely by a direct write, leaving an entity whose
creation is permanently absent from the immutable spine — the exact defect the package exists to
close. Asserted directly in the test (12–13). It also resolves D1 for free, since an INSERT trigger
cannot fire on the UPDATE branch of an upsert.

The function skips silently when no tenant resolves (`trusted_devices` has no `tenant_id` and runs
during authentication): breaking a login to record an event would trade a missing timeline entry for
an unusable system. Actor is left to `record_event`, which derives it authoritatively (WP-00).

## VERIFIED

| Check | Result |
|---|---|
| New guard `37_creation_event_completeness_test.sql` | **14/14** |
| Suite | **37 files / 355 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` |
| Repository guard | CLEAN |
| Database parity | `CLEAN (local proven; primary proven)` |
| repo = local = Primary | **122 migrations**, `314fcc45e57aa524f85291e3f60c344c` |
| Primary live | 4 creation triggers · 107 `app` functions · 116 policies · 0 business rows |

Each assertion pairs a positive baseline with its claim: the actor is proven able to perform the
creation before any count is asserted, so no count can pass vacuously. Highlights — exactly one event
per creation (2, 7, 10); correct entity_type, entity_id and **actor** (3–5); the lead's birth state
recorded (8); **Customer 360 now begins at `customer_created`** (11); a direct INSERT still emits
(12–13); and re-recording the same trusted device emits **one** event, not two (14).

## CROSS-PATH IMPACT SWEEP (the new §3 5b gate)

Question asked of the catalog: *which execution paths now meet these triggers?*

| Class | Finding |
|---|---|
| Single-tenant interactive | the four producers + direct DML — **tested**, both positive and direct-write |
| Multi-tenant system | **none** — no such path INSERTs these tables |
| Batch / set-based | **none** |
| Scheduled | `process_lead_sla` touches `leads` by **UPDATE only**; an INSERT-only trigger never fires (suite passes, incl. test 36) |
| Integration | `capture_attribution_click` and `merge_customer_identity` touch `leads`/`customers` by **UPDATE only**; `map_outcomes_to_conversions` excludes the new types |
| Administrative | `provision_tenant` writes none of the four tables |

**Sweep result: clean.** No cross-tenant abort risk of the kind WP-03 introduced, because no
multi-tenant or set-based path inserts these rows.

## FIXED / CHANGED

* `202607053300` — `app.emit_creation_event()` + 4 AFTER INSERT triggers.
* `27_event_visibility_test.sql` — its fixture hand-wrote a `customer_created` event that the trigger
  now emits for real; the duplicate was removed (the fixture was simulating what the system now does).
* `AGENTS.md` §3 5b and §6 — the two new governance rules.

## NOT FIXED (deliberate)

* Six `*_created` types with **no producer** (`company_asset`, `exchange_rate_adjustment`,
  `financial_account`, `notification`, `payment_allocation`, `subscription`) → WP-02 triage.
  `subscription_created`'s producer is `provision_tenant`, which does not create a subscription —
  blocked on the trial-plan decision.
* D2 (`create_passenger` requires `CREATE_BOOKING_ITEM`) → role audit, not a silent grant.
* D3 (canon's "approved" wording) → recorded.
* WP-03's broad `documents` exemption → WP-04 must narrow it.

## BLOCKED (unchanged, commercial)

**BLOCKED-1** trial plan tier + duration at provisioning. **BLOCKED-2** `MANAGE_SUBSCRIPTION`
"Limited" for Owner/CEO.

## CURRENT STATE

* **122 migrations**, latest `202607053300`, fingerprint `314fcc45e57aa524f85291e3f60c344c` on
  repository, local and Primary.
* 72 tables · 107 `app` functions · 116 policies · 71 permissions · 42 subscription-gate triggers ·
  4 creation triggers. Primary holds zero business rows.
* Suite 37 files / 355 assertions / 0 failures. Smoke passes. Both guards CLEAN.
* Git: `main`, tree clean, pushed.

## NEXT STEP

**WP-02 — event vocabulary / reference-data completeness.** Triage the six producerless `*_created`
types into: (A) executable capability missing its event, (B) intentionally unfired, (C) capability
not built. Also absorb two items this session produced: the **missing `payment_proof` document type**
(canon 28 requires tenants to upload proof; the catalog has no code for it, so WP-03's test uses
`other`), and `subscription_created`'s producer. Do **not** invent catalog values — where canon does
not define one, record it as a canon gap.

Apply the same post-package sweep afterwards. The highest-value CRM question still open after WP-02
is the **employee role scope** (13 permissions, no `CREATE_QUOTATION`/`CREATE_BOOKING`/`CONVERT_LEAD`,
and now no `create_passenger`), because it decides whether a real employee can do their job on day one.
