# Booking Statuses And Rules

Version: 0.1
Status: Draft
Canonical: Yes

---

# Official Booking Statuses

The official booking statuses are:

- draft
- pending_approval
- confirmed
- in_progress
- issued
- void
- refunded
- reissue
- completed
- cancelled

Status values must be controlled catalog values.

---

# Booking Item Status Principle

Every booking item has an independent lifecycle.

MVP uses one shared base lifecycle for all booking item types.

The base lifecycle is:

- draft
- pending
- confirmed
- in_progress
- completed

Each service type may have service-specific sub-status values without duplicating tables.

Examples:

Ticket sub-statuses:

- reserved
- ticketed
- reissued
- void

Visa sub-statuses:

- documents_pending
- embassy_submitted
- approved
- rejected

Hotel sub-statuses:

- reserved
- confirmed
- checked_in
- checked_out

---

# Booking Item Independence

The booking status summarizes the whole file.

Each booking item status describes the actual state of that service.

Example:

- Ticket item: issued
- Hotel item: pending_approval
- Visa item: in_progress
- Booking status: in_progress

---

# Issuance Before Full Collection

A service may be issued before full customer payment only if the user has explicit permission.

When this happens, the system must create a risk flag.

The risk flag must record:

- User
- Time
- Booking item
- Customer balance
- Reason
- Approval source if required

---

# Finance Approval Gate

Execution or issuance must be blocked until finance approval exists.

Finance approval may be based on:

- Uploaded bank receipt approved by finance
- Direct finance approval without receipt

The booking item cannot proceed past the controlled execution gate without finance approval.

A still-pending finance-approval requirement may be withdrawn deliberately by an authorized finance approver, with a fresh reason and server-stamped actor/time. The pending approval request is cancelled in the same transaction. A granted approval, executed service, or locked cost is historical truth and cannot be withdrawn through this operation.

The passenger manifest becomes immutable when a booking item reaches `issued`. Post-issue corrections use the dedicated manifest-correction capability and must record a fresh reason, actor, time, and link/replace/remove event.

---

# Cancellation And Refund

Cancellation and refund are part of the MVP.

They must be modeled as controlled workflows with events, financial impact, documents, and audit history.
