# Entity Registry

Version: 0.1
Status: Draft
Canonical: Yes

---

# Purpose

This document defines the first official ORVION entities before database schema design.

It defines what each entity represents and why it exists.

It does not define final database columns.

---

# Entity Design Rules

- Every entity must support a real travel agency workflow.
- Every tenant-owned business entity must be tenant-scoped.
- Operational entities must preserve historical ownership.
- Important business records are archived, not physically deleted.
- Events record meaningful business milestones.
- Catalog values are defined separately in `25_catalog_registry.md`.
- Table design is defined later in `31_schema_draft.md`.

---

# Core SaaS And Organization Entities

## Tenant

Represents one subscribed travel company.

Responsibilities:

- Owns company data.
- Defines SaaS isolation boundary.
- Owns branches, departments, users, customers, bookings, finance, documents, and subscriptions.

Notes:

- Tenant data must be isolated from other tenants.
- A tenant may have more than one owner.

## Branch

Represents an operational branch inside a tenant.

Responsibilities:

- Groups daily work.
- Owns branch employees operationally.
- Scopes leads, queues, departments, and permissions.

Notes:

- Branches are operationally separated.
- Finance remains company-level unless a future rule changes this.

## Department

Represents an operational department inside a branch.

Examples:

- Sales
- Operations
- Ticketing
- Finance
- Customer Service
- Administration

Responsibilities:

- Scopes employee work.
- Scopes department manager authority.
- Supports routing and permissions.

## Branch Business Hours

Represents weekly operating hours for a branch.

Responsibilities:

- Supports SLA calculation windows.
- Supports operational planning and scheduling displays.

## Holiday

Represents a lightweight holiday calendar entry.

Responsibilities:

- Supports SLA calculation exceptions.
- Supports operational planning around non-working days.

Notes:

- May be tenant-wide or branch-specific.

## User

Represents an employee or authorized platform user.

Responsibilities:

- Performs actions.
- Receives assignments.
- Owns or manages records according to permissions.
- Generates events.

Notes:

- User belongs to a tenant.
- User normally has one primary branch.
- Temporary or permanent transfers must be recorded.

## User Branch Assignment

Represents current or historical branch assignment for a user.

Responsibilities:

- Preserves transfer history.
- Supports temporary and permanent transfers.
- Allows historical actions to remain linked to the correct branch context.

## Role

Represents a named authority level or functional role.

Examples:

- Owner
- CEO
- Branch Manager
- Department Manager
- Finance Manager
- Senior Employee
- Employee
- Trainee
- System Administrator

Responsibilities:

- Groups permissions.
- Supports role-based access decisions.

## Permission

Represents an explicit allowed action.

Responsibilities:

- Controls sensitive operations.
- Avoids hardcoding authority into role names.

Example:

- ALLOW_ISSUE_WITH_NEGATIVE_BALANCE

## User Role Assignment

Represents assigning a role to a user within a scope.

Scope may include:

- Tenant
- Branch
- Department

Responsibilities:

- Supports scoped permissions.
- Allows different authority in different branches or departments.

## Role Permission

Represents the assignment of a Permission to a Role.

Responsibilities:

- Defines which Permissions each Role grants.

---

# Reference Entities

## Currency

Represents a canonical, validated currency used across the platform.

Responsibilities:

- Provides the single source of truth for every `currency_code` reference in the system.
- Carries decimal precision so multi-currency amounts round correctly.

---

# CRM Entities

## Lead

Represents an incoming sales or service opportunity.

Responsibilities:

- Captures initial customer intent.
- Tracks source and assignment.
- Supports SLA escalation.
- Links to customer when approved.
- Links to booking when a booking is created.

Notes:

- Leads are not deleted.
- Duplicate leads are linked to existing customers.
- Multiple active leads for the same customer are restricted unless different departments handle different business needs.

## Lead Assignment

Represents assigning a lead to a user.

Responsibilities:

- Supports round-robin assignment.
- Preserves assignment history.
- Records reassignment after SLA failure.

## Lead Interaction

Represents meaningful lead contact activity.

Examples:

- Phone contact recorded
- WhatsApp contact recorded
- Chat opened
- Customer replied

Responsibilities:

- Helps determine whether a lead was handled.
- Supports SLA rules.

## Customer

Represents an approved customer identity inside a tenant.

Responsibilities:

- Stores customer identity.
- Prevents duplicate customer records.
- Links leads, bookings, passengers, payments, and events.

Notes:

- Customer uniqueness is tenant-level.
- A person customer and company customer are separate records.
- Name alone is not enough for duplicate detection.

## Customer Contact Method

Represents customer contact channels.

Examples:

- Primary phone
- Additional phone
- WhatsApp
- Email
- Social media identity

Responsibilities:

- Supports duplicate detection.
- Supports communication history.

## Customer Identity Merge

Represents merging one customer identity into another.

Responsibilities:

- Records source and target customer, the merging user, and the reason, as queryable relational data.
- Supplements (does not replace) the `customer_identity_merged` audit event.

## Customer Identity Signal

Represents a data point used for duplicate-customer detection.

Responsibilities:

- Supports duplicate detection across phone, email, passport, or other identity signals.
- Records which source entity contributed the signal.

## Customer Note

Represents a searchable, editable business note about a customer.

Responsibilities:

- Stores customer-relevant business memory, distinct from immutable events.
- May be pinned or marked confidential.

## Customer Branch Activity Summary

Represents limited cross-branch awareness for a customer.

Responsibilities:

- Shows last interaction branch.
- Shows last interaction employee.
- Shows last interaction date.

Notes:

- Does not expose detailed event content from another branch by default.

## Task

Represents operational work assigned to an employee.

Examples:

- Call customer
- Send quotation
- Issue ticket
- Verify passport
- Collect payment
- Approve refund

Responsibilities:

- Tracks responsible employee, due date, and completion.
- Distinct from notifications, which communicate information rather than represent work.

## Complaint

Represents a first-class customer complaint and its resolution workflow.

Responsibilities:

- Links to the customer and, where applicable, the booking or booking item concerned.
- Integrates with tasks, conversations, and events for full timeline history.

## Service Request

Represents operational work requested by a customer after the initial booking.

Responsibilities:

- Links to the customer and, where applicable, the booking or booking item concerned.
- Links naturally to tasks, events, and conversations rather than requiring a separate table per request type.

## Quotation

Represents a price/service offer sent to a customer before booking.

Responsibilities:

- Links to a lead or customer.
- May be accepted to create a booking.

## Quotation Item

Represents a service line inside a quotation.

Responsibilities:

- Records service type, quantity, unit price, and currency for one quoted line item.

## Conversation

Represents an ongoing or historical customer conversation.

Responsibilities:

- Supports WhatsApp, phone, and future channels.
- Links to customer, lead, and — once linked post-booking — booking or booking item.
- Distinct from events: conversations store communication context, events record milestones.

## Conversation Message

Represents an individual conversation message or call log entry.

Responsibilities:

- Stores message direction, sender, and content or metadata.
- Business-critical outcomes are recorded separately in lead interactions and events, not only in message content.

---

# Travel And Booking Entities

## Passenger

Represents a traveler inside a booking context.

Responsibilities:

- Stores traveler identity and travel documents.
- Links passport and official documents.
- Allows a customer to book for multiple travelers.

Notes:

- Passport files are stored at passenger level, not customer level.

## Booking

Represents a travel order or reservation container.

Responsibilities:

- Groups one or more booking items.
- Links lead, customer, passengers, payments, documents, and events.
- Tracks overall booking state.

Examples:

- Ticket only
- Hotel only
- Visa only
- Full travel program
- Custom mixed services

## Booking Item

Represents one service inside a booking.

Responsibilities:

- Tracks service type.
- Tracks supplier.
- Tracks independent lifecycle.
- Tracks cost, selling price, currency, profit, and finance approval.
- Links item-level documents.

Examples:

- Flight ticket
- Hotel reservation
- Visa
- Umrah package item
- Custom service

## Booking Item Passenger

Represents the relationship between passengers and booking items.

Responsibilities:

- Supports group bookings.
- Allows one booking item to include many passengers.
- Allows one passenger to appear in multiple booking items.

## Supplier

Represents an external or internal service provider.

Examples:

- Airline
- Hotel
- Embassy or visa provider
- Another travel company
- Freelancer
- Internal department

Responsibilities:

- Links to booking items.
- Supports payables and receivables.
- Supports supplier statement tracking.

## Internal Supplier Link

Represents internal department-to-department service provision.

Responsibilities:

- Tracks when one department provides a service to another.
- Supports operational and financial visibility.

---

# Finance Entities

## Chart Of Account

Represents an account in the tenant's chart of accounts.

Responsibilities:

- Supports journal entries.
- Provides default finance structure.
- Allows tenant customization.

## Journal Entry

Represents a financial accounting entry.

Responsibilities:

- Records financial movement.
- Supports full journal-based accounting.
- Links to payments, refunds, invoices, receipts, adjustments, and booking items where applicable.

## Journal Entry Line

Represents debit or credit side of a journal entry.

Responsibilities:

- Supports double-entry accounting.
- Links to chart of account.

## Invoice

Represents a request for payment.

Responsibilities:

- Links customer, booking, or booking item.
- Supports receivables.

## Receipt

Represents proof that money was received.

Responsibilities:

- Links customer payment.
- May link to uploaded receipt document.

## Payment

Represents money received from a customer or paid to a supplier.

Responsibilities:

- Tracks amount, currency, account, and related business entity.
- Supports installments.

## Payment Allocation

Represents a payment settling a specific invoice, in whole or in part.

Responsibilities:

- Links a Payment to the Invoice(s) it settles.
- Supports partial and installment payments against a single invoice.
- Records the exchange rate used when the payment's currency differs from the invoice's currency.

## Refund

Represents money returned or expected to be returned.

Responsibilities:

- Supports customer refunds.
- Supports supplier refund receivables.

## Finance Approval

Represents finance approval for a booking item or payment proof.

Responsibilities:

- Gates service execution or issuance.
- Records approval source.
- Locks cost where required.

Notes:

- Implemented via the generic `approval_requests` table (`approval_type_code = finance_execution_approval`), not a separate physical table — see `31_schema_draft.md`, Review Required item 5.
- `approval_requests` also carries the other approval types (refund, discount, booking override, manual price change, sensitive data change, subscription) under the same generic mechanism.

## Exchange Rate

Represents manually defined exchange rate.

Responsibilities:

- Supports multi-currency booking items.
- Controlled by Finance Manager or company manager.

## Exchange Rate Adjustment

Represents formal correction after rate lock.

Responsibilities:

- Records old rate, new rate, affected item, reason, user, and financial impact.

## Financial Account

Represents bank or cash account.

Responsibilities:

- Supports multiple banks.
- Supports multiple currencies.
- Supports balance tracking.

## Company Asset

Represents company-owned asset.

Responsibilities:

- Supports practical asset management.

Notes:

- Advanced depreciation is not part of Professional Finance Lite.

---

# Document Entities

## Document

Represents an uploaded file.

Responsibilities:

- Stores file metadata.
- Links to a business entity.
- Supports permissions, archive, and versioning.

## Document Version

Represents a specific version of a document.

Responsibilities:

- Preserves old uploads.
- Marks current version.

## Document Link

Represents linking a document to a supported entity.

Supported targets include:

- Passenger
- Booking
- Booking item
- Invoice
- Receipt
- Supplier
- Subscription payment

Responsibilities:

- Avoids duplicating documents.
- Allows one document to be linked where business rules allow it.

---

# Event And Notification Entities

## Event

Represents an immutable business event.

Responsibilities:

- Records meaningful business milestones.
- Links actor, tenant, entity, and event type.
- Supports audit and timeline views.

## Security Event

Represents authentication, authorization, and credential events.

Responsibilities:

- Records login, OTP, TOTP, password, device, and permission changes.

## Notification

Represents an in-system notification.

Responsibilities:

- Alerts users about operational, finance, subscription, and SLA events.

## Notification Delivery

Represents delivery attempt through a channel.

Examples:

- In-system
- Email
- Future WhatsApp

Responsibilities:

- Tracks delivery state.
- Supports future channel expansion.

---

# SaaS And Subscription Entities

## Subscription Plan

Represents Starter, Professional, or Enterprise plan.

Responsibilities:

- Defines feature access.
- Defines limits.
- Defines module availability.

## Subscription

Represents a tenant's active or historical subscription.

Responsibilities:

- Tracks plan, period, grace period, suspension, and read-only mode.

## Subscription Payment Proof

Represents uploaded bank transfer proof for subscription renewal.

Responsibilities:

- Supports owner review.
- Links proof document to subscription renewal.

## Feature Entitlement

Represents plan-level feature access.

Responsibilities:

- Controls enabled modules and capabilities.

## Usage Counter

Represents monthly or period-based usage.

Examples:

- Leads
- Bookings
- Storage
- Automations

Responsibilities:

- Enforces plan limits.

---

# Authentication And Security Entities

## Trusted Device

Represents a verified user device.

Responsibilities:

- Supports first-new-device verification.
- Supports revocation.

## OTP Challenge

Represents an email OTP challenge.

Responsibilities:

- Supports normal user verification for new devices.

## TOTP Enrollment

Represents authenticator app enrollment for high-risk roles.

Responsibilities:

- Supports Owner, CEO, Finance Manager, and System Administrator authentication.

---

# Marketing And Offline Conversion Entities

## Marketing Campaign

Represents an advertising campaign tracked by ORVION.

Responsibilities:

- Represents the campaign a click, conversion, or metric belongs to.
- Supports the Marketing Dashboard without implementing full ad platform management.

## Campaign Daily Metric

Represents daily marketing performance values for a campaign.

Responsibilities:

- Stores spend, impressions, clicks, leads, bookings, and revenue per day.
- May be imported from integrations or calculated internally.

## Attribution Click

Represents captured ad click/session data.

Responsibilities:

- Stores GCLID, session ID, click ID, UTM fields, landing page, and timestamp.
- Links to the Marketing Campaign it belongs to, where identifiable.

## Offline Conversion

Represents an internal conversion created from CRM outcome.

Examples:

- qualified_phone_call
- qualified_lead
- booking_created
- payment_received
- ticket_issued

Responsibilities:

- Links CRM outcome to ad click data.
- Prepares delivery to Google Ads.
- Links to the Marketing Campaign it belongs to, where identifiable.

## Offline Conversion Delivery

Represents sending conversion data to an external platform.

Responsibilities:

- Tracks pending, ingested, sent, failed, and retried states.
- Records send attempts.

---

# Deferred Entities

The following entities are intentionally deferred from first schema unless needed by an approved module:

- Full tax engine
- Advanced financial statement model
- Data warehouse
- OLAP cube
- GDS booking engine
- Marketplace/plugin system
- HR/payroll
- Full workflow engine runtime

---

# Next Step

Create `25_catalog_registry.md`.
