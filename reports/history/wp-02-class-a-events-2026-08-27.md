# ORVION — WP-02 / SPEC-153: Class A Events + the Finance Visibility Defect

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: Implementing SPEC-153's five Class A events (migration `202607053400`), resolving the
`payment_allocation` visibility question, and the post-package cross-path sweep.

Predecessor: `wp-01-creation-events-2026-08-27.md`.

---

## STATUS — **EARNED → CLOSED**

## DISCOVERED

**D1 — The inherited Class A list was STALE, and re-introspection caught it.** The instruction named
`customer_created`, `lead_created`, `passenger_created` among the candidates. A live sweep
(`pg_proc.prosrc` **∪** `pg_get_triggerdef`) proved all three are already emitted — WP-01 closed them.
Implementing them again would have produced duplicate events on every customer/lead/passenger
creation. The true remaining set was five.

**D2 — `payment_allocation_created` would have been invisible to Finance.** This was the open
question from alignment, and it was a **real defect, not a hypothetical**:

* `app.has_tenant_wide_read()` is literally `app.has_permission('VIEW_ALL_BRANCHES')`.
* `VIEW_ALL_BRANCHES` is held by **`ceo` and `owner` only** — verified against `role_permissions`.
  `finance_manager` does **not** hold it.
* `payment_allocation` was absent from the `events` read-policy `entity_type` dispatch, so the event
  would have hit `ELSE false`.

Net effect had it shipped as-is: an event about money movement that **Finance — the role that most
needs it — could never read**, while ceo/owner could. Emitting the event without fixing visibility
would have satisfied "the event exists" and failed the actual requirement.

**D3 — `app.assign_user_branch` emits nothing at all.** Not "emits the wrong event" — nothing.
Branch and department placement is the foundation of the entire branch-isolation model, and moving an
employee between branches left **no audit trace whatsoever**.

**D4 — Three fixture facts found by testing, each a genuine system rule:**
* `create_invoice` **requires MFA** for `finance_manager` (`app.requires_mfa` covers owner/ceo/
  finance_manager/system_administrator), so a realistic finance session needs `"aal":"aal2"`.
* An invoice must be **issued** before it can be paid — a draft invoice is not payable.
* `user_branch_assignments` has a partial unique index `(tenant_id, user_id) WHERE is_primary AND
  ends_at IS NULL`, so a transfer must **end** the prior primary placement first. The test now models
  a real transfer rather than an impossible double-primary state.

## FIXED — `202607053400`

Five events, all emitted by **trigger** (consistent with WP-01, and for the same reason: SEC-1 is
open, so a direct write must not create history-free state):

| Event | Trigger | Condition |
|---|---|---|
| `payment_allocation_created` | `payment_allocations` AFTER INSERT | — (reuses `app.emit_creation_event`) |
| `trusted_device_revoked` | `trusted_devices` AFTER UPDATE | `revoked_at` null → not null |
| `trusted_device_reverified` | `trusted_devices` AFTER UPDATE | became `trusted`, or returned from revoked |
| `document_superseded` | `documents` AFTER UPDATE | `current_version_id` changed **and old was not null** |
| `user_branch_transfer_completed` | `user_branch_assignments` AFTER INSERT | only when a prior assignment exists |

**Visibility fix (D2):** added a `payment_allocation` branch to the `events` `audit_read` dispatch,
delegating to `payment_allocations`' own RLS (`VIEW_FINANCIAL_DOCUMENTS` **or** the related invoice is
visible). This is SPEC-143's existing rule — *an event is readable exactly when its subject is* — not
a new boundary. It widens visibility only for `entity_type = 'payment_allocation'`, and only to
callers who can already read the allocation row, so it discloses nothing newly.

**Deliberately NOT renamed:** `app.emit_creation_event` was left untouched. Four live WP-01 triggers
depend on it, and renaming for elegance would buy nothing while risking a compatibility problem. The
non-creation cases got a new neutral helper, `app.emit_entity_event`.

**Deliberately NOT emitted:** `user_branch_transfer_started`. `assign_user_branch` is one synchronous
call and canon 26 defines no transfer state machine, so firing `_started` **and** `_completed` from a
single call would fabricate a two-phase lifecycle. Asserted explicitly in the test so a later session
does not "complete the pair".

## VERIFIED

| Check | Result |
|---|---|
| New guard `38_class_a_events_test.sql` | **21/21** |
| Suite | **38 files / 376 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` |
| Repository guard | CLEAN |
| Database parity | `CLEAN (local proven; primary proven)` |
| repo = local = Primary | **123 migrations**, `91d8e8b59380caa4e4f046288d6298f0` |
| Primary live | 109 `app` functions · 116 policies · 9 emit triggers (4 WP-01 + 5 WP-02) · dispatch branch present · `authenticated` on `events` = **SELECT only** (WP-00 intact) |

**The visibility proof carries both halves, each with a positive control** (per the no-vacuous-tests
rule):

* Finance: *control* — can read the `payment_allocations` **row** (`VIEW_FINANCIAL_DOCUMENTS`); then
  can read its **event**.
* Employee: *control* — can read events in general (`customer_created` visible), proving the fixture
  is not empty; then **cannot** read the allocation event.

Without the employee-side control, "0 rows" would have proven nothing.

Other proofs: direct DML into `payment_allocations` still emits (an in-RPC emission would have missed
it); an ordinary re-login touch does **not** emit `reverified` (only a genuine return from revoked
does); first placement does **not** emit a transfer; and `null → v1` is not a supersession while
`v1 → v2` is.

## CROSS-PATH SWEEP (`AGENTS.md §3 5b`)

Two things changed: five triggers, and the `events` read **policy** was rewritten.

| Class | Finding |
|---|---|
| Single-tenant interactive | all seven writers of the four affected tables (`record_payment`, `record_trusted_device`, `revoke_trusted_device`, `add_document_version`, `archive_document`, `upload_document`, `assign_user_branch`) are **SECURITY INVOKER** |
| Multi-tenant system | **none** |
| Batch / set-based | **none** |
| Scheduled | **none** — `process_lead_sla` touches none of these tables |
| Integration | `map_outcomes_to_conversions` verified against its live body: does **not** pick up any of the five new types; the n8n contract is unchanged |

**No WP-03-style cross-tenant abort risk**, because no multi-tenant or set-based path writes these
tables. Policy-rewrite fidelity proven two ways: the dispatch went from **23 → 24 branches** (exactly
one added, none lost), both `events` policies still exist, and `27_event_visibility_test.sql` — which
exercises this policy behaviourally — still passes.

## NOT FIXED (deliberate)

* **58 never-emitted events remain**, all Class B/C per SPEC-153. None has a producer, so none is an
  emission bug. Notable groups: subscription (11, blocked on BLOCKED-1/2), authentication (13 — these
  are Supabase Auth events with no ORVION hook, and `public.security_events` still has **zero
  producers**), notifications (4), detection/warning jobs (6).
* WP-03's broad `documents` subscription-gate exemption → WP-04 must narrow it.
* Missing `payment_proof` document type (canon 28 requires proof upload; the catalog has no code).
* `create_passenger` gated on `CREATE_BOOKING_ITEM`, which `employee` lacks → role audit.

## BLOCKED (unchanged, commercial)

**BLOCKED-1** trial plan tier + duration at provisioning. **BLOCKED-2** `MANAGE_SUBSCRIPTION`
"Limited" for Owner/CEO.

## RISK INTRODUCED THIS SESSION — and resolved

Rewriting a live RLS policy (`audit_read`) is the riskiest thing done here: a dropped branch would
silently *hide* history from a role, which no test asserting presence would catch. Mitigated by
counting branches before/after (23 → 24) and by the pre-existing behavioural visibility test still
passing. Recorded so a future session treats policy rewrites with the same suspicion.

## CURRENT STATE

* **123 migrations**, latest `202607053400`, fingerprint `91d8e8b59380caa4e4f046288d6298f0` on
  repository, local and Primary.
* 72 tables · 109 `app` functions · 116 policies · 71 permissions · 42 subscription-gate triggers ·
  9 event-emit triggers. Primary holds zero business rows.
* Suite 38 files / 376 assertions / 0 failures. Smoke passes. Both guards CLEAN.
* Git: `main`, tree clean, pushed.

## NEXT STEP

The event spine is now complete for every producer that exists — remaining gaps are missing
*capabilities*, not missing emissions. On evidence, the next package should be the one with the
largest day-one employee impact rather than the next number:

**Recommended: the employee role-scope audit.** Accumulated evidence across three sessions shows the
ordinary `employee` role holds 13 permissions and cannot create a quotation, create a booking, convert
a lead, or even register a passenger (`create_passenger` needs `CREATE_BOOKING_ITEM`). If that is
wrong, a real employee cannot do their job on day one — which outranks any remaining event or
reporting work. It requires classifying each gap as confirmed design / canon contradiction / business
decision / engineering defect, **without inventing permissions**.

Alternative if a purely technical package is preferred: **WP-04 documents/storage** (zero buckets,
zero storage policies, plus narrowing the WP-03 `documents` exemption and resolving `payment_proof`).
