# Event Catalog

Version: 0.2
Status: Draft
Canonical: Yes

---

# Purpose

This document defines ORVION's meaningful immutable events.

Events are used to understand the full history of a lead, customer, booking, payment, document, subscription, and security action.

---

# Event Principles

- Every important business action creates an event.
- Events are immutable.
- Events are not physically deleted.
- Events are tenant-scoped where applicable.
- Events must identify actor, target entity, timestamp, and event type.
- Events should record meaningful business milestones, not every UI click.
- Events support timeline views, audit, notifications, reporting, and troubleshooting.
- Canonical event-entity linkage uses the polymorphic entity_type / entity_id pattern as specified in 31_schema_draft.md (see Review Required item #1).

---

# Event Severity

## info

Normal business event.

## warning

Needs attention but does not block the system.

## risk

Business or financial risk was accepted.

## security

Authentication, authorization, or permission event.

## critical

Sensitive or high-impact action.

---

# Event Payload Rule

Event payload may store structured context, but it must not become the primary database model.

Examples of acceptable payload:

- Previous status
- New status
- Reason
- Amount snapshot
- Assignment target
- Approval source
- External delivery response

Do not store full entity records only inside event payload.

---

# Lead Events

## lead_created

Created when a new lead enters the system.

Severity: info

Triggers:

- New lead from call, WhatsApp, website form, Google Ads, Meta Ads, or manual entry

## lead_assigned

Created when a lead is assigned to an employee.

Severity: info

Triggers:

- Round-robin assignment
- Manual assignment

## lead_reassigned

Created when a lead moves from one employee to another.

Severity: warning

Triggers:

- SLA failure
- Manager reassignment
- Employee unavailability

## lead_sla_warning

Created when a lead remains unhandled after the first SLA window.

Severity: warning

Triggers:

- 15 minutes without qualifying interaction

## lead_contacted

Created when valid customer contact is recorded.

Severity: info

Triggers:

- Phone call
- WhatsApp message
- Customer reply
- Chat opened

## lead_qualified

Created when customer intent is confirmed.

Severity: info

## lead_quotation_sent

Created when quotation is sent.

Severity: info

## lead_negotiation_started

Created when customer enters negotiation.

Severity: info

## lead_won

Created when customer agrees to proceed.

Severity: info

## lead_converted

Created when lead becomes a customer and/or booking.

Severity: info

## lead_lost

Created when lead closes without sale.

Severity: info

Requires:

- Closure reason

## lead_marked_spam

Created when lead is classified as spam.

Severity: warning

## lead_marked_duplicate

Created when lead is linked to an existing customer or lead.

Severity: warning

## lead_reopened

Created when a closed lead is reopened.

Severity: warning

Requires:

- Reopen reason
- Authorized actor

---

# Customer Events

## customer_created

Created when a customer record is approved.

Severity: info

## customer_contact_added

Created when contact method is added.

Severity: info

## customer_identity_match_found

Created when duplicate identity signals are detected.

Severity: warning

## customer_identity_merged

Created when identity records are merged or linked.

Severity: critical

Requires:

- Authorized actor
- Source record
- Target record
- Reason

## customer_cross_branch_activity_detected

Created when customer activity exists in another branch.

Severity: info

---

# Organization And User Events

## branch_created

Severity: info

## department_created

Severity: info

## user_created

Severity: info

## user_branch_transfer_started

Severity: info

## user_branch_transfer_completed

Severity: info

## role_assigned

Severity: security

## role_removed

Severity: security

## permission_granted

Severity: security

## permission_revoked

Severity: security

---

# Booking Events

## booking_created

Created when a booking is opened from lead, customer, or manual request.

Severity: info

## booking_submitted_for_approval

Created when booking is submitted for approval.

Severity: info

## booking_confirmed

Severity: info

## booking_in_progress

Severity: info

## booking_issued

Severity: info

## booking_voided

Severity: warning

## booking_reissue_started

Severity: warning

## booking_refunded

Severity: warning

## booking_completed

Severity: info

## booking_cancelled

Severity: warning

Requires:

- Cancellation reason

---

# Booking Item Events

## booking_item_created

Severity: info

## booking_item_pending

Severity: info

## booking_item_confirmed

Severity: info

## booking_item_in_progress

Severity: info

## booking_item_completed

Severity: info

## booking_item_sub_status_changed

Severity: info

Requires:

- Previous sub-status
- New sub-status

## booking_item_supplier_assigned

Severity: info

## booking_item_cost_entered

Severity: info

## booking_item_cost_locked

Severity: critical

## booking_item_locked_cost_edited

Severity: critical

Requires:

- Previous cost
- New cost
- Reason
- Authorized actor

## booking_item_risk_flag_created

Severity: risk

Triggers:

- Issuance before full collection

Requires:

- Permission used
- Customer balance snapshot
- Reason

## booking_item_cancelled

Severity: warning

Requires:

- Cancellation reason

## booking_item_no_show_recorded

Severity: warning

---

# Passenger Events

## passenger_created

Severity: info

## passenger_document_added

Severity: info

## passenger_passport_expiry_warning

Severity: warning

---

# Supplier Events

## supplier_created

Severity: info

## supplier_assigned_to_booking_item

Severity: info

## internal_supplier_linked

Severity: info

## supplier_credit_threshold_exceeded

Created when a supplier's outstanding payable, in the currency its credit ceiling is denominated in, rises above that ceiling. The ceiling WARNS; it never refuses (owner decision 2026-09-04, SUP-4b). Emitted once per breach, not once per write: it is suppressed while the most recent threshold event for the supplier is already this one.

Severity: warning

Triggers:

- a booking-item cost becoming or remaining locked against the supplier
- a supplier payment being recorded, changed or removed

## supplier_credit_threshold_cleared

Created when a supplier previously over its ceiling falls back to or below it. Exists so a later breach alerts again; without it the first breach would silence the supplier forever.

Severity: info

---

# Finance Events

## invoice_voided

Created when an ORVION invoice is voided internally, through `app.void_invoice` or the equivalent table write. Carries NO external or tax meaning: ORVION performs no cancellation with any tax authority, and the payload states `external_effect: none` explicitly. Refused, and therefore never emitted, once payment is allocated to the invoice or once the document has been accepted externally.

Severity: warning

Triggers:

- an invoice moving to `voided` from `draft`, `issued` or `overdue`

## customer_credit_threshold_exceeded

Created when a customer's outstanding receivable rises above the credit ceiling configured on that customer. Exposure held in other currencies is CONVERTED into the ceiling's currency at the tenant's latest manual rate at or before the evaluation instant; any currency with no usable rate is REPORTED in the payload as `unconvertible_currencies` rather than dropped. The ceiling WARNS; it never refuses (owner decision 2026-09-04, CUST-3). Emitted once per breach, not once per write: it is suppressed while the most recent threshold event for the customer is already this one.

Severity: warning

Triggers:

- an invoice for the customer being created, changed or removed
- a customer payment being recorded, changed or removed
- a completed customer refund being recorded, changed or removed

## customer_credit_threshold_cleared

Created when a customer previously over its ceiling falls back to or below it. Exists so a later breach alerts again; without it the first breach would silence the customer forever.

Severity: info

## finance_approval_requested

Severity: info

## finance_approval_approved

Severity: critical

Effects:

- Allows controlled execution gate
- May lock cost

## finance_approval_rejected

Severity: warning

## finance_approval_cancelled

Severity: warning

## finance_approval_resubmitted

Severity: info

## approval_requested

Severity: info

Triggers:

- Any `approval_requests` row created for an `approval_type_code` other than `finance_execution_approval`, which continues to use `finance_approval_requested`

## approval_approved

Severity: critical

## approval_rejected

Severity: warning

## approval_cancelled

Severity: warning

## approval_resubmitted

Severity: info

## payment_recorded

Severity: info

## payment_allocation_created

Severity: info

Requires:

- Invoice
- Payment
- Allocated amount

## receipt_issued

Severity: info

## invoice_created

Severity: info

## refund_requested

Severity: warning

## refund_approved

Severity: info

## refund_rejected

Severity: info

## refund_cancelled

Severity: info

## refund_processing

Severity: info

## refund_completed

Severity: info

## journal_entry_created

Severity: info

## exchange_rate_set

Severity: critical

## exchange_rate_adjustment_created

Severity: critical

Requires:

- Original rate
- New rate
- Affected booking item
- Reason

## financial_account_created

Severity: info

## company_asset_created

Severity: info

---

# Document Events

## document_uploaded

Severity: info

## document_linked

Severity: info

## document_version_created

Severity: info

## document_archived

Severity: warning

Requires:

- Archive reason

## document_superseded

Severity: info

## document_expiry_warning

Severity: warning

---

# Notification Events

## notification_created

Severity: info

## notification_sent

Severity: info

## notification_failed

Severity: warning

## notification_read

Severity: info

---

# Subscription Events

## subscription_created

Severity: info

## subscription_activated

Severity: info

## subscription_entered_grace_period

Severity: warning

## subscription_entered_read_only

Severity: warning

## subscription_suspended

Severity: critical

## subscription_cancelled

Severity: warning

## subscription_expired

Severity: warning

## subscription_reactivated

Severity: info

## subscription_payment_proof_uploaded

Severity: info

## subscription_payment_approved

Severity: critical

## subscription_payment_rejected

Severity: warning

---

# Authentication And Security Events

## login_attempt

Severity: security

## login_success

Severity: security

## login_failure

Severity: security

## otp_requested

Severity: security

## otp_verified

Severity: security

## otp_failed

Severity: security

## otp_expired

Severity: security

## totp_enrolled

Severity: security

## totp_challenge_success

Severity: security

## totp_challenge_failure

Severity: security

## trusted_device_created

Severity: security

## trusted_device_revoked

Severity: security

## trusted_device_expired

Severity: security

## trusted_device_reverified

Severity: security

## password_changed

Severity: security

## password_reset

Severity: security

## account_locked

Severity: security

---

# Offline Conversion Events

## attribution_click_captured

Severity: info

## offline_conversion_created

Severity: info

## offline_conversion_send_attempted

Severity: info

## offline_conversion_sent

Severity: info

## offline_conversion_failed

Severity: warning

## offline_conversion_retried

Severity: warning

---

# Task Events

## task_created

Severity: info

## task_assigned

Severity: info

## task_completed

Severity: info

## task_cancelled

Severity: warning

## task_overdue

Severity: warning

---

# Complaint Events

## complaint_created

Severity: warning

## complaint_acknowledged

Severity: info

## complaint_in_progress

Severity: info

## complaint_awaiting_customer

Severity: info

## complaint_awaiting_supplier

Severity: info

## complaint_resolved

Severity: info

## complaint_closed

Severity: info

## complaint_reopened

Severity: warning

Requires:

- Reopen reason
- Authorized actor

---

# Service Request Events

## service_request_created

Severity: info

## service_request_in_progress

Severity: info

## service_request_awaiting_customer

Severity: info

## service_request_awaiting_supplier

Severity: info

## service_request_resolved

Severity: info

## service_request_closed

Severity: info

## service_request_reopened

Severity: warning

Requires:

- Reopen reason
- Authorized actor

---

# Quotation Events

## quotation_created

Severity: info

## quotation_sent

Severity: info

## quotation_accepted

Severity: info

Effects:

- May produce a Booking referencing the Quotation via `bookings.quotation_id`

## quotation_rejected

Severity: info

## quotation_expired

Severity: warning

## quotation_cancelled

Severity: warning

## quotation_revised

Severity: info

---

# Conversation Events

## conversation_started

Severity: info

## conversation_assigned

Severity: info

## conversation_escalated

Severity: warning

## conversation_closed

Severity: info

## conversation_reopened

Severity: warning

Requires:

- Reopen reason
- Authorized actor

## conversation_message_received

Severity: info

## conversation_message_sent

Severity: info

---

# Marketing Campaign Events

## marketing_campaign_created

Severity: info

## marketing_campaign_activated

Severity: info

## marketing_campaign_paused

Severity: info

## marketing_campaign_ended

Severity: info

## marketing_campaign_archived

Severity: info

---

# Events Not Required

The following do not require events unless they cause a business state change:

- Opening a page
- Sorting a table
- Typing without saving
- Hovering UI elements
- Failed client-side validation before submission

---

# Next Step

Create `28_permissions_matrix.md`.

---

# As-built additions & alignments (2026-07-17, evidence-backed sync)

Implementation (Phases 5–7 RPCs) extended the vocabulary beyond v0.2; the emitted codes are the
as-built truth (empty DB, no rename cost). Renamed in place above (unused draft names → emitted
names): internal_supplier_link_created → internal_supplier_linked; receipt_created →
receipt_issued; refund_created → refund_requested. Added below (emitted by issue_invoice /
record_payment / record_supplier_payment):

## invoice_issued

Invoice moved to issued.

## invoice_partially_paid

Invoice partially settled by payment allocation.

## invoice_paid

Invoice fully settled.

## supplier_payment_recorded

Supplier payment recorded against payable.
