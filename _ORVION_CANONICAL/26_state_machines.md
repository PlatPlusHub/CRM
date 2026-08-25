# State Machines

Version: 0.2
Status: Draft
Canonical: Yes

---

# Purpose

This document defines allowed state transitions for ORVION core workflows.

No operational status should move freely without an allowed transition.

Every meaningful state transition must create an event.

---

# State Machine Rules

- Status values must come from `25_catalog_registry.md`.
- State transitions must be validated by application logic and, where practical, database constraints.
- Terminal records are not physically deleted.
- Reopening is allowed only through explicit workflow rules.
- Every state transition must record actor, timestamp, previous state, new state, and reason where applicable.

---

# Lead State Machine

## States

- new
- assigned
- contacted
- qualified
- quotation_sent
- negotiation
- won
- converted
- lost
- spam
- duplicate

## Normal Flow

```text
new
  -> assigned
  -> contacted
  -> qualified
  -> quotation_sent
  -> negotiation
  -> won
  -> converted
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| new | assigned | Lead assigned by routing or authorized user |
| new | spam | Invalid or spam intake |
| new | duplicate | Existing active lead/customer detected |
| assigned | contacted | Phone/WhatsApp/contact interaction recorded |
| assigned | assigned | Reassignment event only; lead remains assigned |
| assigned | lost | Allowed with closure reason |
| assigned | duplicate | Existing lead/customer confirmed |
| contacted | qualified | Customer need confirmed |
| contacted | lost | Allowed with closure reason |
| contacted | spam | Contact proves spam |
| qualified | quotation_sent | Quotation sent to customer |
| qualified | won | Customer agrees without formal quotation |
| qualified | lost | Allowed with closure reason |
| quotation_sent | negotiation | Customer negotiates price/details |
| quotation_sent | won | Customer accepts quotation |
| quotation_sent | lost | Allowed with closure reason |
| negotiation | won | Customer accepts |
| negotiation | lost | Allowed with closure reason |
| won | converted | Customer and/or booking created |
| duplicate | assigned | Only if duplicate classification was wrong and reopened by authorized user |
| lost | assigned | New attempt or reopening with reason |
| spam | assigned | Only if spam classification was wrong and reopened by authorized user |
```

Note:

`reassigned` is not a lead status. It is an assignment event.

## Terminal States

Terminal unless reopened by authorized action:

- converted
- lost
- spam
- duplicate

## Required Events

- lead_created
- lead_assigned
- lead_reassigned
- lead_contacted
- lead_qualified
- lead_quotation_sent
- lead_negotiation_started
- lead_won
- lead_converted
- lead_lost
- lead_marked_spam
- lead_marked_duplicate
- lead_reopened

---

# Lead SLA State Logic

Lead SLA is not a status field. It is derived from assignment and interaction events.

## SLA Rule

If assigned lead has no qualifying interaction within 15 minutes:

- Create lead_sla_warning event.
- Notify assigned employee.
- Notify manager.

If another 15 minutes pass without qualifying interaction:

- Reassign lead to another eligible employee.
- Create lead_reassigned event.

## Qualifying Interaction

Any of the following counts as response:

- phone_call
- whatsapp_message
- chat_opened
- customer_reply
- lead status changed by authorized user for a valid reason

---

# Booking State Machine

## States

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

## Principle

Booking status summarizes the whole booking.

Execution detail lives on booking items.

## Normal Flow

```text
draft
  -> pending_approval
  -> confirmed
  -> in_progress
  -> issued
  -> completed
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| draft | pending_approval | Booking submitted for finance/management approval |
| draft | cancelled | Booking cancelled before approval |
| pending_approval | confirmed | Required approval granted |
| pending_approval | cancelled | Approval rejected or customer cancelled |
| confirmed | in_progress | Operations started |
| confirmed | cancelled | Customer or company cancels before service execution |
| in_progress | issued | One or more issuable items issued |
| in_progress | completed | Non-ticket booking completed without issued state |
| in_progress | cancelled | Allowed with cancellation workflow |
| issued | completed | All required services completed |
| issued | void | Void workflow applies |
| issued | reissue | Reissue workflow applies |
| issued | refunded | Refund workflow applies |
| void | completed | Void finalized with finance impact resolved |
| reissue | issued | Reissued service issued |
| refunded | completed | Refund finalized |
```

## Terminal States

- completed
- cancelled

Terminal states may not be edited directly. Corrections require adjustment events or authorized reopening in a future policy.

## Required Events

- booking_created
- booking_submitted_for_approval
- booking_confirmed
- booking_in_progress
- booking_issued
- booking_voided
- booking_reissue_started
- booking_refunded
- booking_completed
- booking_cancelled

---

# Booking Item Base State Machine

## States

- draft
- pending
- confirmed
- in_progress
- completed
- cancelled
- no_show

## Normal Flow

```text
draft
  -> pending
  -> confirmed
  -> in_progress
  -> completed
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| draft | pending | Item submitted for approval or supplier action |
| draft | completed | Allowed only for simple already-completed manual item with authorized permission |
| draft | cancelled | Booking item cancelled before confirmation |
| pending | confirmed | Supplier/finance/operations confirms item |
| pending | draft | Returned for correction |
| pending | cancelled | Booking item cancelled while pending |
| confirmed | in_progress | Work starts or service execution begins |
| confirmed | completed | Allowed when service does not require in-progress step |
| confirmed | cancelled | Booking item cancelled after confirmation, per cancellation workflow |
| confirmed | no_show | Passenger/traveler did not show for a time-bound service |
| in_progress | completed | Service completed |
| in_progress | cancelled | Booking item cancelled during execution, per cancellation workflow |
| in_progress | no_show | Passenger/traveler did not show during execution |
```

## Terminal States

- cancelled
- no_show

Terminal states may not be edited directly. Corrections require adjustment events or authorized reopening in a future policy, consistent with the Booking State Machine's terminal-state rule.

## Sub-Status Rule

Service-specific sub-status may change inside the base lifecycle.

Examples:

- Ticket: reserved, ticketed, reissued, void
- Visa: documents_pending, embassy_submitted, approved, rejected
- Hotel: reserved, confirmed, checked_in, checked_out

Sub-status transitions must create events but do not require separate tables.

## Required Events

- booking_item_created
- booking_item_pending
- booking_item_confirmed
- booking_item_in_progress
- booking_item_completed
- booking_item_sub_status_changed
- booking_item_cancelled
- booking_item_no_show_recorded

---

# Finance Approval State Machine

## States

- pending
- approved
- rejected
- cancelled

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| pending | approved | Finance approves receipt or direct approval |
| pending | rejected | Finance rejects proof or request |
| pending | cancelled | Request cancelled before review |
| rejected | pending | Resubmission with new proof or correction |
```

## Effects

When approved:

- Booking item execution gate opens.
- Cost may be locked.
- Finance approval event is created.

When rejected:

- Booking item execution remains blocked.
- Responsible employee is notified.

## Required Events

- finance_approval_requested
- finance_approval_approved
- finance_approval_rejected
- finance_approval_cancelled
- finance_approval_resubmitted

---

# Document Lifecycle State Machine

## States

- active
- archived
- superseded

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| active | archived | Incorrect or no longer valid document archived with reason |
| active | superseded | New document version uploaded |
| superseded | archived | Old version archived from active use |
```

## Rules

- Documents are not physically deleted as a normal business action.
- Each new version creates document_version_created event.
- Archive requires reason.

## Required Events

- document_uploaded
- document_linked
- document_version_created
- document_archived
- document_superseded

---

# Subscription State Machine

## States

- trial
- active
- grace_period
- read_only
- suspended
- cancelled
- expired

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| trial | active | Subscription activated |
| trial | expired | Trial ends without activation |
| active | grace_period | Payment period ends without renewal |
| grace_period | active | Renewal approved within grace period |
| grace_period | read_only | Two-day grace period ends |
| read_only | active | Renewal approved |
| read_only | suspended | Platform owner suspends tenant |
| suspended | active | Platform owner restores subscription |
| active | cancelled | Subscription cancelled |
| cancelled | active | Manual reactivation by platform owner |
| expired | active | Manual reactivation by platform owner |
```

## Required Events

- subscription_created
- subscription_activated
- subscription_entered_grace_period
- subscription_entered_read_only
- subscription_suspended
- subscription_cancelled
- subscription_expired
- subscription_reactivated
- subscription_payment_proof_uploaded
- subscription_payment_approved
- subscription_payment_rejected

---

# Offline Conversion Delivery State Machine

## States

- pending
- sent
- failed
- retried

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| pending | sent | External platform accepts conversion |
| pending | failed | Send attempt fails |
| failed | retried | Retry scheduled or attempted |
| retried | sent | Retry succeeds |
| retried | failed | Retry fails |
```

## Rules

- CRM state does not depend on delivery success.
- Every delivery attempt is recorded.

## Required Events

- offline_conversion_created
- offline_conversion_send_attempted
- offline_conversion_sent
- offline_conversion_failed
- offline_conversion_retried

---

# Trusted Device State Machine

## States

- trusted
- revoked
- expired

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| trusted | revoked | User or admin revokes device |
| trusted | expired | Device trust expires by policy |
| revoked | trusted | Device verified again |
| expired | trusted | Device verified again |
```

## Required Events

- trusted_device_created
- trusted_device_revoked
- trusted_device_expired
- trusted_device_reverified

---

# OTP Challenge State Machine

## States

- pending
- verified
- failed
- expired

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| pending | verified | Correct OTP entered before expiry |
| pending | failed | Incorrect OTP or max attempts reached |
| pending | expired | OTP expires |
```

## Required Events

- otp_requested
- otp_verified
- otp_failed
- otp_expired

---

# Task State Machine

## States

- open
- in_progress
- completed
- cancelled
- overdue

## Normal Flow

```text
open
  -> in_progress
  -> completed
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| open | in_progress | Responsible employee starts work |
| open | completed | Allowed for tasks completed without a distinct in-progress step |
| open | cancelled | Task cancelled before completion |
| open | overdue | System-set when due_at passes without completion |
| in_progress | completed | Task completed |
| in_progress | cancelled | Task cancelled during execution |
| in_progress | overdue | System-set when due_at passes without completion |
| overdue | in_progress | Work resumed on an overdue task |
| overdue | completed | Task completed after its due date |
| overdue | cancelled | Overdue task cancelled |

## Terminal States

- completed
- cancelled

## Required Events

- task_created
- task_assigned
- task_completed
- task_cancelled
- task_overdue

---

# Complaint State Machine

## States

- new
- acknowledged
- in_progress
- awaiting_customer
- awaiting_supplier
- resolved
- closed

## Normal Flow

```text
new
  -> acknowledged
  -> in_progress
  -> resolved
  -> closed
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| new | acknowledged | Complaint acknowledged by responsible employee |
| acknowledged | in_progress | Investigation or resolution work started |
| in_progress | awaiting_customer | Waiting on customer response or documents |
| in_progress | awaiting_supplier | Waiting on supplier response |
| awaiting_customer | in_progress | Customer responded |
| awaiting_supplier | in_progress | Supplier responded |
| in_progress | resolved | Resolution provided to customer |
| resolved | closed | Complaint closed after resolution |
| closed | in_progress | Reopened with reason by authorized user |

## Terminal States

Terminal unless reopened by authorized action:

- closed

## Required Events

- complaint_created
- complaint_acknowledged
- complaint_in_progress
- complaint_awaiting_customer
- complaint_awaiting_supplier
- complaint_resolved
- complaint_closed
- complaint_reopened

---

# Service Request State Machine

## States

- requested
- in_progress
- awaiting_customer
- awaiting_supplier
- resolved
- closed

## Normal Flow

```text
requested
  -> in_progress
  -> resolved
  -> closed
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| requested | in_progress | Work started on the request |
| in_progress | awaiting_customer | Waiting on customer response or documents |
| in_progress | awaiting_supplier | Waiting on supplier response |
| awaiting_customer | in_progress | Customer responded |
| awaiting_supplier | in_progress | Supplier responded |
| in_progress | resolved | Request resolved |
| resolved | closed | Request closed after resolution |
| closed | in_progress | Reopened with reason by authorized user |

## Terminal States

Terminal unless reopened by authorized action:

- closed

## Required Events

- service_request_created
- service_request_in_progress
- service_request_awaiting_customer
- service_request_awaiting_supplier
- service_request_resolved
- service_request_closed
- service_request_reopened

---

# Quotation State Machine

## States

- draft
- sent
- accepted
- rejected
- expired
- cancelled

## Normal Flow

```text
draft
  -> sent
  -> accepted
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| draft | sent | Quotation sent to customer |
| draft | cancelled | Quotation cancelled before sending |
| sent | accepted | Customer accepts the quotation |
| sent | rejected | Customer rejects the quotation |
| sent | expired | valid_until passes without customer response |
| sent | cancelled | Quotation withdrawn before customer response |
| rejected | draft | Revised and prepared for resending |
| expired | draft | Revised and prepared for resending |

## Terminal States

- accepted
- cancelled

Terminal unless reopened by authorized action:

- rejected
- expired

## Effects

When accepted:

- Quotation may produce a Booking, which references the Quotation via `bookings.quotation_id`.
- `quotation_accepted` event is created.

## Required Events

- quotation_created
- quotation_sent
- quotation_accepted
- quotation_rejected
- quotation_expired
- quotation_cancelled
- quotation_revised

---

# Conversation State Machine

## States

- open
- assigned
- pending_customer
- pending_internal
- escalated
- closed

## Normal Flow

```text
open
  -> assigned
  -> closed
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| open | assigned | Conversation assigned to a user or department |
| assigned | pending_customer | Waiting on customer reply |
| assigned | pending_internal | Waiting on internal department or supplier |
| pending_customer | assigned | Customer replied |
| pending_internal | assigned | Internal response received |
| assigned | escalated | Escalated to a manager or another department |
| escalated | assigned | De-escalated back to normal handling |
| assigned | closed | Conversation closed |
| pending_customer | closed | Conversation closed without further customer response |
| escalated | closed | Conversation closed after escalation resolved |
| closed | open | Reopened with reason by authorized user |

## Terminal States

Terminal unless reopened by authorized action:

- closed

## Required Events

- conversation_started
- conversation_assigned
- conversation_escalated
- conversation_closed
- conversation_reopened

---

# Marketing Campaign State Machine

## States

- draft
- active
- paused
- ended
- archived

## Normal Flow

```text
draft
  -> active
  -> ended
  -> archived
```

## Allowed Transitions

| From | To | Rule |
| --- | --- | --- |
| draft | active | Campaign launched |
| active | paused | Campaign paused |
| paused | active | Campaign resumed |
| active | ended | Campaign ended |
| paused | ended | Campaign ended while paused |
| ended | archived | Campaign archived after ending |

## Terminal States

- archived

## Required Events

- marketing_campaign_created
- marketing_campaign_activated
- marketing_campaign_paused
- marketing_campaign_ended
- marketing_campaign_archived

---

# Next Step

Create `27_event_catalog.md`.

---

# Transition Enforcement

Implemented by SPEC-149 (`202607052700_lifecycle_transition_enforcement.sql`). Until then the state
machines were enforced only inside the `app.advance_*` RPCs, and nothing obliged a caller to use
one: a direct `update bookings set booking_status_code = 'issued'` moved a booking from `draft`
straight to `issued` with no authorization, no validation and no events.

`app.status_transitions` mirrors the transition maps held in the RPCs — 104 transitions across
`bookings`, `leads`, `booking_items`, `quotations`, `refunds`, `tasks`, `conversations`,
`complaints`, `service_requests` and `marketing_campaigns` — and a BEFORE UPDATE trigger on each
table checks two things independently:

| Failure | Code | Meaning |
| --- | --- | --- |
| unrecognised transition | `23514` | this `from -> to` pair is not in the state machine |
| missing capability | `42501` | the pair is legal, the caller may not make it |

**The RPCs remain the author of the rules.** The registry mirrors them and test 32 fails if any app
function can write a status the registry does not recognise — the same registry-plus-drift-guard
pattern as `07_event_vocabulary_registry_test` and `08_status_vocabulary_registry_test`.

**Transition logic is not confined to `advance_*`.** `app.assign_lead` / `assign_lead_round_robin`
(`new -> assigned`), `app.record_lead_interaction` (`assigned -> contacted`) and `app.convert_lead`
(`won -> converted`, canon 26: "only a won lead may convert") all move a lead's status. The drift
guard therefore scans every app function, not only the ones named like transition RPCs.

**Boundary.** The trigger restricts direct DML to legal, authorized transitions. It does not
reproduce the RPCs' side effects — events, closure reasons, risk flags, cost locking, timestamps —
so the `app.advance_*` RPC remains the only complete path. Platform callers (`service_role`,
migrations) are exempt per canon 35 principle 6.
