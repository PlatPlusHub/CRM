# Change Request — SPEC-153 (WP-02: Event Vocabulary Triage)

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

**ALIGNED — not implemented.** This document is the triage artefact. No migration or code change has
been made under it.

---

## Objective

Classify every registered-but-never-emitted event type, and close the ones that have a real producer.

## Scope discovered live (2026-08-27) — larger than expected

WP-01 closed four `*_created` types. The remaining vocabulary gap is **not** the "six producerless
`*_created` types" the previous report anticipated:

```
event_type catalog values, active : 169
emitted (functions + triggers)    : 106
NEVER emitted                     :  63
```

**Detection note that matters for anyone re-running this.** A first pass reported 67 never-emitted
and was wrong: WP-01 emits via **trigger arguments** (`tg_argv`), which never appear as string
literals in any function body. The corrected sweep unions `pg_proc.prosrc` with
`pg_get_triggerdef(...)`. Any future audit that greps only function bodies will under-count emitted
types by exactly the trigger-driven ones.

---

## Triage

### Class A — executable producer exists, event genuinely missing → implement

Each verified by reading the live function body and confirming it emits nothing (or omits this one).

| Event | Producer | Evidence |
|---|---|---|
| `user_branch_transfer_completed` | `app.assign_user_branch` | inserts `user_branch_assignments`, takes `p_transfer_type_code`, and **emits nothing at all** — branch/department placement is the basis of the entire branch-isolation model and currently leaves no audit trace |
| `payment_allocation_created` | `app.record_payment` | writes `payment_allocations`; emits `payment_recorded` / `invoice_paid` / `invoice_partially_paid` but never the allocation |
| `trusted_device_revoked` | `app.revoke_trusted_device` | updates `trusted_devices`; **emits nothing** |
| `trusted_device_reverified` | `app.record_trusted_device` | its UPDATE branch re-trusts a known device; emits nothing (its INSERT branch is covered by WP-01) |
| `document_superseded` | `app.add_document_version` | supersedes the prior version (`current_version_id`); emits only `document_version_created` |

### Class B — registered for a lifecycle that is deliberately not two-phase

| Event | Why not fired |
|---|---|
| `user_branch_transfer_started` | `assign_user_branch` is a **single synchronous call**. Canon 27 lists the event with a severity but defines no transfer lifecycle, and canon 26 has no user-branch-transfer state machine. Emitting `_started` and `_completed` from one call would fabricate a two-phase process that does not exist. Reserved for a future approval-gated transfer. |
| `supplier_assigned_to_booking_item` | `create_booking_item` takes `p_supplier_id`, so assignment at creation is already covered by `booking_item_created`. A *later* re-assignment would warrant this event, but no re-assignment RPC exists. |
| `approval_requested` / `_approved` / `_rejected` / `_cancelled` / `_resubmitted` | The finance-specific family **is** emitted (`finance_approval_requested/approved/rejected/cancelled` by `request_finance_approval` / `review_finance_approval`). The generic family covers the other `approval_type_code` values (`refund_approval`, `discount_approval`, `booking_override`, `manual_price_change`, `sensitive_data_change`), none of which has an RPC yet. |

### Class C — capability not built; do NOT invent a producer

| Group | Events | Reason |
|---|---|---|
| Subscription (11) | `subscription_created`, `_activated`, `_cancelled`, `_expired`, `_suspended`, `_reactivated`, `_entered_grace_period`, `_entered_read_only`, `_payment_proof_uploaded`, `_payment_approved`, `_payment_rejected` | No subscription state-transition RPC exists at all, and `MANAGE_SUBSCRIPTION` is held by no role. Gated behind **BLOCKED-1/BLOCKED-2**. `subscription_created`'s natural producer is `provision_tenant`, which does not create a subscription — that is BLOCKED-1. |
| Authentication (13) | `login_attempt`, `login_failure`, `login_success`, `account_locked`, `password_changed`, `password_reset`, `otp_requested`, `otp_verified`, `otp_failed`, `otp_expired`, `totp_enrolled`, `totp_challenge_success`, `totp_challenge_failure` | These are **Supabase Auth** events, not ORVION RPCs; ORVION has no login path to hook. They also duplicate the `security_event_type` catalog, and `public.security_events` has **zero producers** (WP-00 established this). Closing them is a separate capability — an auth-webhook or `auth` schema trigger — not an event-emission fix. |
| Notifications (4) | `notification_created`, `_sent`, `_read`, `_failed` | `notifications` / `notification_deliveries` have no producer function whatsoever. Known gap; belongs to the notifications package. |
| Master data (4) | `company_asset_created`, `financial_account_created`, `exchange_rate_adjustment_created`, `exchange_rate_set` | No RPC writes these tables. |
| Booking-item cost (4) | `booking_item_cost_entered`, `_cost_locked`, `_locked_cost_edited`, `_sub_status_changed` | Cost is set at creation; there is no separate cost-entry/locking workflow to fire them. |
| Detection / warnings (6) | `customer_cross_branch_activity_detected`, `customer_identity_match_found`, `passenger_passport_expiry_warning`, `passenger_document_added`, `document_expiry_warning`, `task_overdue` | Detection and warning **jobs** do not exist. `app.expiring_documents` and `app.find_customer_duplicates` are *readers*, not emitters; `process_lead_sla` covers leads only. |
| Access (3) | `permission_granted`, `permission_revoked`, `role_removed` | `assign_user_role` emits `role_assigned`; there is no revoke-role or per-permission grant RPC. |
| Offline conversion (2) | `offline_conversion_send_attempted`, `offline_conversion_retried` | Pre-existing **PH8-6**. The send attempt happens inside n8n, not ORVION; emitting them requires the workflow to call back. Left with PH8-6 rather than duplicated here. |
| Lead (1) | `lead_reopened` | No `reopened` transition exists in the lead state machine. |
| Finance (1) | `finance_approval_resubmitted` | No resubmission flow in `request_finance_approval`. |

---

## Change Boundary

Allowed: one migration adding the five Class A emissions and their tests; this CR; manifest; gap
register. Forbidden: inventing any producer for Class C; adding catalog values; touching SEC-1;
altering the n8n contract.

## Non-Goals

Notifications, subscription lifecycle, auth-event capture, detection/warning jobs, cost-entry
workflow — each is its own package.

## Binary Acceptance Criteria

1. Each of the five Class A events is emitted exactly once by its producer, proven as a real
   authenticated user with a positive baseline first.
2. `trusted_device_reverified` fires on the UPDATE branch only, and `trusted_device_created` (WP-01)
   still fires on the INSERT branch only — re-trusting a known device emits *reverified*, not *created*.
3. `user_branch_transfer_started` is **not** emitted (Class B), asserted explicitly so a later session
   does not "complete" the pair by fabricating it.
4. Correct tenant, actor, entity_type and entity_id on every new event.
5. Cross-path impact sweep (`AGENTS.md §3 5b`) completed and recorded — in particular, whether any
   new type enters `app.map_outcomes_to_conversions`'s filter (expected: no).
6. Full suite + smoke green; both guards CLEAN; repo = local = Primary by fingerprint after deploy.

## Stop Conditions

Halt and re-align if: a Class A producer turns out to have a second writer (duplicate emission risk);
an event requires an `entity_type` absent from the `events` read-policy dispatch and therefore
invisible to the role that needs it (**`payment_allocation` is exactly this case — see Open Question**);
a pre-existing test fails; or a guard is not CLEAN.

## Open Question (engineering, resolve during implementation — not a business decision)

`payment_allocation` is **not** in the `events` read-policy `entity_type` dispatch, so a
`payment_allocation_created` event would fall to `ELSE false` and be visible only to tenant-wide
readers and the acting user — plausibly hiding it from Finance, which is precisely the role that
needs it. Resolve by either adding a `payment_allocation` branch to the dispatch (a policy change,
which then requires its own cross-path sweep) or by confirming Finance holds tenant-wide read. Decide
on evidence before implementing criterion 1 for that event.

## Execution Log

* **2026-08-27 — ALIGNED.** Full 169-type vocabulary swept live; 63 never-emitted classified A/B/C
  with per-event evidence. Corrected a detection blind spot that under-counted emitted types by
  ignoring trigger arguments. No code written.
