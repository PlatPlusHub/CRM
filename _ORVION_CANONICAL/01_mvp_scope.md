# ORVION MVP Scope

Version: 0.1
Status: Draft
Canonical: Yes

---

# MVP Definition

The first production-ready version of ORVION must be practical, focused, and usable by a real travel company.

The goal is not to build the perfect enterprise system in the first release.

The goal is to build a controlled foundation that supports the most important business flow from lead intake to booking, documents, finance follow-up, and management visibility.

---

# In Scope For MVP

## SaaS Foundation

- Company tenant isolation
- Branch isolation
- Subscription plans
- Read-only mode after subscription suspension
- User management
- Role and permission management
- Department-level permission control

## CRM And Lead Intake

- Lead capture
- Lead source tracking
- Lead assignment
- 15-minute response SLA alert
- 30-minute reassignment rule
- Customer profile creation
- Duplicate customer prevention
- Lead status lifecycle

## Customer Data

- Primary phone number
- Additional phones
- WhatsApp identity
- Email
- Social media identities
- Family name
- First name
- Full name
- Passport data
- Miles card data
- Family or related travelers
- Expiry alerts for passport and important dates

## Travel Requests And Bookings

- Ticket request
- Hotel request
- Visa request
- Full travel program request
- Booking lifecycle
- Passenger/traveler data
- Supplier association
- Booking documents

## Documents

- Upload PDF, images, Excel files, and related document types <!-- C2 (2026-07-15 recovery): Excel upload is deferred for MVP per 16_document_types_and_rules.md, which governs MVP document-type scope; no business change. -->
- Link documents to customer, passenger, booking, invoice, supplier, or subscription payment
- Retrieve documents later
- Export or download documents where permitted

## Finance

- Customer receivables
- Supplier payables
- Basic profit tracking
- Payments
- Invoices
- Receipts
- Bank transfer proof attachments
- Company asset tracking
- Finance alerts for due balances

## Events And Audit

- Immutable event log
- User action tracking
- Entity timeline
- No physical deletion for business records
- Archive instead of delete

## Notifications

- Lead response alerts
- Manager escalation
- Lead reassignment notifications
- Passport expiry alerts
- Customer balance alerts
- Supplier balance alerts
- Subscription renewal alerts

## Integrations

- Supabase as backend/database layer
- n8n for automation
- WhatsApp API integration planning
- Google Ads and GTM attribution planning
- Meta Ads attribution planning
- Google Ads reporting and configuration visibility, read-only (owner decision D4, 2026-10-11): advertising cost, performance and campaign configuration read with Google's own query language (GAQL) wherever Google supports them, and compared inside ORVION with the leads, customers, bookings, payments and profitability ORVION itself verifies. Google-reported conversions stay distinct from ORVION-verified outcomes, attribution uncertainty is shown rather than hidden, and advertising cost is recognized once. Contract: ADR-0030 and `MASTER_INTEGRATION_CATALOG.md §5`.

---

# Out Of Scope For MVP

These may be planned later, but should not delay the first usable version:

- Full double-entry accounting ERP depth
- Complex airline GDS/NDC integration
- Full payment gateway integration
- Advanced AI automation beyond dashboard and assistance
- Marketplace or plugin ecosystem
- Deep HR/payroll system
- Data warehouse and OLAP analytics
- Complex inventory management
- Self-healing infrastructure
- Modifying Google Ads from ORVION — campaigns, budgets, keywords, bidding, targeting, assets and account settings change only in the official Google Ads interface, so ORVION builds no mutation workflow, no approval flow for advertising changes and no campaign editor (owner decision D4, 2026-10-11)

---

# MVP Success Criteria

The MVP succeeds when a travel company can:

- Receive and track leads from approved sources
- Prevent losing leads through SLA alerts and reassignment
- Create clean customer records without duplicates
- Manage ticket, hotel, visa, and package requests
- Attach and retrieve business documents
- Track money owed by customers and suppliers
- See practical profit and operational status
- Operate under branch, department, and user permissions
- Maintain a permanent event history
- Run as a SaaS tenant with subscription control

