# Relationship Map

Version: 0.1
Status: Draft
Canonical: Yes

---

# Purpose

This document defines first-version entity relationships before database schema design.

It is used to create foreign keys and join tables later.

---

# Relationship Rules

- Tenant is the top-level isolation boundary.
- Branch is operational scope, not default financial scope.
- Department belongs to branch.
- Historical ownership must be preserved.
- Leads, bookings, documents, finance records, and events are never physically deleted as normal business actions.
- Many-to-many relationships require explicit link entities.

---

# SaaS And Organization Relationships

## Tenant To Branch

Relationship:

- Tenant has many Branches.
- Branch belongs to one Tenant.

Cardinality:

- tenant 1 -> many branches

## Branch To Department

Relationship:

- Branch has many Departments.
- Department belongs to one Branch.

Cardinality:

- branch 1 -> many departments

## Tenant To User

Relationship:

- Tenant has many Users.
- User belongs to one Tenant.

Cardinality:

- tenant 1 -> many users

## User To Branch Assignment

Relationship:

- User has many User Branch Assignments.
- Branch has many User Branch Assignments.

Cardinality:

- user 1 -> many user_branch_assignments
- branch 1 -> many user_branch_assignments

Purpose:

- Supports primary branch.
- Supports temporary and permanent transfers.
- Preserves historical context.

## User To Role Assignment

Relationship:

- User has many User Role Assignments.
- Role has many User Role Assignments.

Cardinality:

- user many <-> many roles through user_role_assignments

Scope:

- tenant
- branch
- department

---

# CRM Relationships

## Tenant To Lead

Relationship:

- Tenant has many Leads.
- Lead belongs to one Tenant.

Cardinality:

- tenant 1 -> many leads

## Branch To Lead

Relationship:

- Branch has many Leads.
- Lead belongs to an operational Branch.

Cardinality:

- branch 1 -> many leads

## Department To Lead

Relationship:

- Department has many Leads.
- Lead may be routed to one Department.

Cardinality:

- department 1 -> many leads

## Lead To Lead Assignment

Relationship:

- Lead has many Lead Assignments.
- Lead Assignment belongs to one Lead.
- Lead Assignment belongs to one assigned User.

Cardinality:

- lead 1 -> many lead_assignments
- user 1 -> many lead_assignments

Purpose:

- Preserves assignment and reassignment history.

## Lead To Customer

Relationship:

- Lead may link to one Customer.
- Customer may have many Leads.

Cardinality:

- customer 1 -> many leads
- lead many -> 0/1 customer

Rule:

- Lead is preserved after conversion.

## Customer To Contact Methods

Relationship:

- Customer has many Contact Methods.

Cardinality:

- customer 1 -> many customer_contact_methods

Rule:

- Primary phone is unique inside tenant unless approved exception exists.

## Lead To Interaction

Relationship:

- Lead has many Lead Interactions.
- Interaction may be created by User.

Cardinality:

- lead 1 -> many lead_interactions
- user 1 -> many lead_interactions

## Customer To Customer (Identity Merge)

Relationship:

- Customer (source) may be merged into exactly one Customer (target) via Customer Identity Merge.
- Customer (target) may have many source merges recorded against it.

Cardinality:

- customer (target) 1 -> many customer_identity_merges

Purpose:

- Supports customer-identity merges as a queryable, reconstructable action, not only an event-log entry.

---

# CRM Extension Relationships

## Customer/Lead To Task

Relationship:

- Task may relate to any business entity via `related_entity_type`/`related_entity_id`.
- Task is owned by exactly one User, Department, and Branch.

Enforcement (added 2026-08-21, SPEC-130 — the relationship above is unchanged; only its guarantees are new):

- This polymorphic link is enforced by `app.enforce_entity_reference`, applied to `tasks`, `notifications`, and `approval_requests`.
- `related_entity_type` must be an active value of the `related_entity_type` catalog family (`25_catalog_registry.md`), so spelling and casing variants are impossible.
- `related_entity_id` must identify a row that actually exists in the named entity **and belongs to the same tenant** as the referring record.
- The two columns must be set together or both left null; a half-set reference is refused.
- "Any business entity" is therefore realised as "any entity registered in the `related_entity_type` family", which is extended by adding a catalog value rather than by a schema change — preserving the open-ended intent of this relationship while making it referentially sound.
- The typed-FK pattern used by `document_links` was considered and deliberately not applied here: enumerating targets as columns would contradict the "any business entity" intent stated above and would make every newly relatable entity a schema migration.

## Customer To Complaint

Relationship:

- Customer has many Complaints.
- Complaint may optionally link to the Booking or Booking Item it concerns.

Cardinality:

- customer 1 -> many complaints
- booking 1 -> many complaints
- booking_item 1 -> many complaints

## Customer To Service Request

Relationship:

- Customer has many Service Requests.
- Service Request may optionally link to the Booking or Booking Item it concerns.

Cardinality:

- customer 1 -> many service_requests
- booking 1 -> many service_requests
- booking_item 1 -> many service_requests

## Lead/Customer To Quotation

Relationship:

- Quotation may originate from a Lead or belong directly to a Customer.
- Quotation has many Quotation Items.

Cardinality:

- lead 1 -> many quotations
- customer 1 -> many quotations
- quotation 1 -> many quotation_items

## Customer/Lead To Conversation

Relationship:

- Conversation may link to a Customer or a Lead.
- Conversation may optionally link to a Booking or Booking Item once one exists.
- Conversation has many Conversation Messages.

Cardinality:

- customer 1 -> many conversations
- lead 1 -> many conversations
- booking 1 -> many conversations
- booking_item 1 -> many conversations
- conversation 1 -> many conversation_messages

---

# Booking Relationships

## Lead To Booking

Relationship:

- Lead may create one or many Bookings.
- Booking may originate from one Lead.

Cardinality:

- lead 1 -> many bookings
- booking many -> 0/1 lead

## Quotation To Booking

Relationship:

- Quotation may produce zero or one Booking upon acceptance.
- Booking may optionally reference the Quotation it originated from.

Cardinality:

- quotation 1 -> 0..1 booking

## Customer To Booking

Relationship:

- Customer has many Bookings.
- Booking belongs to one Customer.

Cardinality:

- customer 1 -> many bookings

## Booking To Passenger

Relationship:

- Booking has many Passengers.
- Passenger belongs to one Tenant and may be reused in future bookings if identity rules allow.

Initial MVP approach:

- Passenger is linked to booking through booking_passengers or booking_item_passengers.

## Booking To Booking Item

Relationship:

- Booking has many Booking Items.
- Booking Item belongs to one Booking.

Cardinality:

- booking 1 -> many booking_items

## Booking Item To Passenger

Relationship:

- Booking Item can include many Passengers.
- Passenger can be included in many Booking Items.

Cardinality:

- booking_item many <-> many passengers through booking_item_passengers

## Booking Item To Supplier

Relationship:

- Booking Item belongs to one Supplier where applicable.
- Supplier has many Booking Items.

Cardinality:

- supplier 1 -> many booking_items

## Internal Supplier Link

Relationship:

- Internal Supplier Link connects service-providing department to requesting department or booking item.

Purpose:

- Supports internal department-to-department service.

---

# Finance Relationships

## Tenant To Chart Of Accounts

Relationship:

- Tenant has many Chart Of Accounts entries.

Cardinality:

- tenant 1 -> many chart_of_accounts

## Journal Entry To Lines

Relationship:

- Journal Entry has many Journal Entry Lines.
- Journal Entry Line belongs to one Chart Of Account.

Cardinality:

- journal_entry 1 -> many journal_entry_lines
- chart_of_account 1 -> many journal_entry_lines

## Customer To Invoice

Relationship:

- Customer has many Invoices.
- Invoice may link to Booking or Booking Item.

Cardinality:

- customer 1 -> many invoices
- booking 1 -> many invoices
- booking_item 1 -> many invoices

## Invoice To Payment

Relationship:

- Invoice may have many Payment Allocations.
- Payment may have many Payment Allocations.
- Payment Allocation belongs to exactly one Invoice and exactly one Payment.

Cardinality:

- invoice 1 -> many payment_allocations
- payment 1 -> many payment_allocations

Purpose:

- Supports partial and installment payments against a single invoice with a deterministic, queryable paid/outstanding balance, including cross-currency settlement via an optional exchange rate reference.

## Customer/Supplier To Payment

Relationship:

- Payment may relate to Customer or Supplier depending on direction.
- Payment may link to Booking or Booking Item.

Rule:

- Payment direction determines business meaning.

## Receipt To Payment

Relationship:

- Receipt belongs to one Payment.
- Payment may have one or more Receipts depending on split documentation.

## Refund Relationships

Relationship:

- Refund may relate to Customer or Supplier.
- Refund may link to Booking or Booking Item.

## Finance Approval To Booking Item

Relationship:

- Finance Approval belongs to one Booking Item.
- Booking Item may have multiple Finance Approval records over time.

Purpose:

- Supports approval, rejection, resubmission, and audit.

## Exchange Rate To Booking Item

Relationship:

- Booking Item may use one Exchange Rate snapshot.
- Exchange Rate Adjustment links to Booking Item and affected Journal Entries where applicable.

---

# Document Relationships

## Document To Document Version

Relationship:

- Document has many Document Versions.
- One version may be current.

Cardinality:

- document 1 -> many document_versions

## Document To Document Link

Relationship:

- Document has many Document Links.
- Document Link points to one supported business entity.

Supported targets:

- passenger
- booking
- booking_item
- invoice
- receipt
- supplier
- subscription_payment

Rule:

- The schema may implement polymorphic links or specific link tables. Decision is finalized in schema draft.

---

# Event Relationships

## Event To Actor

Relationship:

- Event may belong to one actor User.
- Some system events may have no human actor.

## Event To Target Entity

Relationship:

- Event targets one business entity type and entity id.

Supported approach:

- Use generic entity_type/entity_id for broad event log.
- Keep critical direct references where useful in module tables.

## Security Event

Relationship:

- Security Event belongs to User where applicable.
- Security Event belongs to Tenant where applicable.

---

# Notification Relationships

## Notification To User

Relationship:

- Notification belongs to target User.
- Notification belongs to Tenant.

## Notification To Delivery

Relationship:

- Notification has many Notification Deliveries.

---

# Subscription Relationships

## Tenant To Subscription

Relationship:

- Tenant has many Subscriptions over time.
- One subscription may be current.

## Subscription To Plan

Relationship:

- Subscription belongs to one Subscription Plan.

## Subscription To Payment Proof

Relationship:

- Subscription has many Subscription Payment Proofs.

## Plan To Feature Entitlement

Relationship:

- Subscription Plan has many Feature Entitlements.

## Tenant To Usage Counter

Relationship:

- Tenant has many Usage Counters per period.

---

# Authentication Relationships

## User To Trusted Device

Relationship:

- User has many Trusted Devices.

## User To OTP Challenge

Relationship:

- User has many OTP Challenges.

## User To TOTP Enrollment

Relationship:

- User may have one active TOTP Enrollment.

---

# Offline Conversion Relationships

## Marketing Campaign To Daily Metric

Relationship:

- Marketing Campaign has many Campaign Daily Metrics.

Cardinality:

- marketing_campaign 1 -> many campaign_daily_metrics

## Marketing Campaign To Attribution Click / Offline Conversion

Relationship:

- Marketing Campaign may have many Attribution Clicks and many Offline Conversions, where identifiable.

Cardinality:

- marketing_campaign 1 -> many attribution_clicks
- marketing_campaign 1 -> many offline_conversions

Notes:

- This is a referential (foreign key) link in addition to the existing `utm_campaign` free-text field; the two are not mutually exclusive.

## Attribution Click To Lead

Relationship:

- Attribution Click may link to one Lead.
- Lead may have one or many Attribution Click records depending on session history.

## Offline Conversion To Lead/Booking/Payment

Relationship:

- Offline Conversion links to the CRM outcome entity.

Possible targets:

- lead
- booking
- payment
- booking_item

## Offline Conversion To Delivery

Relationship:

- Offline Conversion has many Delivery attempts.

---

# Next Step

Create `30_database_conventions.md`.
