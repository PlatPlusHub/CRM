# Catalog Registry

Version: 0.3
Status: Draft
Canonical: Yes

---

# Purpose

This document defines ORVION controlled values before database schema design.

Any dropdown-like value used by employees must come from a controlled catalog.

Employees must not create operational statuses, document types, service types, roles, or permission keys freely inside daily forms.

---

# Catalog Design Rules

- Catalogs prevent random employee input.
- System-critical catalogs are global and controlled by ORVION.
- Tenant-customizable catalogs may be extended by authorized tenant users where allowed.
- Status catalogs must be linked to state machines in `26_state_machines.md`.
- Catalog values must use stable machine codes.
- Display labels can be localized later.
- Deleted catalog values should be deactivated, not physically deleted, if already used.

---

# Catalog Classification Types

## System Catalog

Controlled by ORVION platform.

Tenant users cannot add or rename values.

Used for:

- Core statuses
- System permissions
- Security events
- Subscription plans
- Offline conversion delivery states

## Tenant Catalog

Controlled per tenant by authorized tenant users.

Used for:

- Some supplier classifications
- Some service naming extensions
- Tenant-specific business labels where safe

## Reference Data

Stable public or semi-public datasets that are not operational dropdowns owned by employees.

Used for:

- Countries
- Cities
- Currencies
- Languages
- Nationalities
- Airports where needed later

Status:

- Currencies: Implemented — see `31_schema_draft.md`, Reference Tables (`currencies`).
- Countries, Languages, Nationalities: **Implemented** as dedicated reference tables (`countries`, `languages`, `nationalities`) — `31_schema_draft.md`, migration `202607042000_create_geo_reference_tables.sql` (SPEC-037). Actively referenced by FK from `customers.preferred_language_code`, `passengers.nationality_code`, `passengers.passport_issuing_country_code`, and `bookings.destination_country_code`. Corrected 2026-08-16 (pre-Phase-8-completion audit) — this line previously said "not yet implemented" for all five, which had gone stale for these three.
- Cities, Airports: Not yet implemented as dedicated reference tables; current fields remain free-standing codes pending a documented business requirement for validated lookups at that granularity. (Still accurate — unchanged.)

Rule:

Do not store reference datasets inside generic `catalog_values` unless there is a strong business reason.

Reference data should use dedicated reference tables or seeded reference datasets.

## Tenant-Extendable System Catalog

Has ORVION default values but may allow tenant additions.

Used only when additions do not break core workflows.

---

# Lead Catalogs

## lead_status

Ownership: System Catalog

Values:

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

Usage:

- Lead lifecycle
- Lead pipeline
- SLA handling
- Reporting

## lead_closure_reason

Ownership: System Catalog

Values:

- booked
- postponed
- price_rejected
- no_response
- duplicate
- spam
- invalid_contact
- not_interested
- service_unavailable
- competitor
- customer_cancelled
- converted_customer
- other

Usage:

- Lead closure
- Lost lead reporting
- Duplicate handling
- Reopening rules

## lead_source

Ownership: Tenant-Extendable System Catalog

Default values:

- google_ads_call
- google_ads_form
- direct_call
- whatsapp
- website_form
- manual_entry
- meta_ads
- referral
- repeat_customer
- other

Usage:

- Lead attribution
- Offline conversion
- Sales reporting

Tenant additions:

Allowed with admin permission.

## lead_interaction_type

Ownership: System Catalog

Values:

- phone_call
- whatsapp_message
- chat_opened
- customer_reply
- note
- follow_up
- quotation_sent

Usage:

- Lead response detection
- SLA calculation
- Timeline

## priority_code

Ownership: System Catalog

Values:

- low
- normal
- high
- urgent

Usage:

- Leads
- Tasks
- Operational queues

---

# Customer Catalogs

## customer_type

Ownership: System Catalog

Values:

- person
- company

Usage:

- Customer identity
- Duplicate prevention
- UI display

## contact_method_type

Ownership: System Catalog

Values:

- primary_phone
- secondary_phone
- whatsapp
- email
- facebook
- instagram
- other_social
- other

Usage:

- Customer contact methods
- Duplicate detection

## customer_identity_signal_type

Ownership: System Catalog

Values:

- phone
- whatsapp
- email
- social_identity
- passport_number
- official_document_number

Usage:

- Duplicate matching
- Identity quality checks

## preferred_contact_method_code

Ownership: System Catalog

Values:

- phone
- whatsapp
- email
- social

Usage:

- Customer communication preference

## preferred_language_code

Ownership: Reference Data

Values:

Stored in reference data, not generic catalog values.

Initial practical values:

- ar
- en

Usage:

- Customer communication preference
- Future localization

---

# Organization Catalogs

## department_type

Ownership: System Catalog

Values:

- sales
- operations
- ticketing
- finance
- customer_service
- administration
- management

Usage:

- Department setup
- Routing
- Permissions

Tenant additions:

Not allowed in MVP.

## branch_transfer_type

Ownership: System Catalog

Values:

- temporary
- permanent

Usage:

- User branch assignment
- Transfer history

---

# Task Catalogs

## task_type_code

Ownership: System Catalog

Values:

- call_customer
- send_quotation
- issue_ticket
- verify_passport
- collect_payment
- approve_refund
- follow_up
- upload_document
- review_booking
- resolve_complaint
- other

Usage:

- My Work
- Department queues
- Operational task routing

## task_status_code

Ownership: System Catalog

Values:

- open
- in_progress
- completed
- cancelled
- overdue

Usage:

- Task lifecycle
- My Work
- Manager overview

---

# Role And Permission Catalogs

## role_code

Ownership: System Catalog

Values:

- owner
- ceo
- branch_manager
- department_manager
- finance_manager
- senior_employee
- employee
- trainee
- system_administrator

Usage:

- User role assignment
- Permission matrix
- High-risk authentication rules

## functional_role_code

Ownership: System Catalog

Values:

- sales
- operations
- ticketing
- finance
- customer_service
- administration

Usage:

- Functional responsibility
- UI routing
- Department-specific workflows

Status:

**Superseded by `department_type` — not implemented, and not to be implemented (recorded 2026-08-21, remediation pass).** Every one of the six values above is an exact subset of the live `department_type` catalog (`sales`, `operations`, `ticketing`, `finance`, `customer_service`, `administration`, plus `management`), which is seeded, FK-referenced by `departments.department_type_code`, and consumed by `app.create_department`. Introducing `functional_role_code` as a second catalog family would create two vocabularies for one concept and violate one-authority-per-concept (`GOVERNANCE.md §6.8`).

This entry is retained rather than deleted, per the supersede-don't-delete convention already applied to `finance_approval_type` above. "Functional responsibility" and "UI routing" are served by `department_type` together with the separate `role_code` → `roles` table; if a future UI genuinely needs a functional axis independent of both department and RBAC role, that is a new design question, not a revival of this family.

## permission_key

Ownership: System Catalog

Initial values:

- ALLOW_ISSUE_WITH_NEGATIVE_BALANCE
- MANAGE_TENANT_SETTINGS
- MANAGE_BRANCHES
- MANAGE_DEPARTMENTS
- MANAGE_USERS
- MANAGE_ROLES
- MANAGE_PERMISSIONS
- VIEW_ALL_BRANCHES
- VIEW_BRANCH_DATA
- VIEW_ASSIGNED_LEADS
- VIEW_DEPARTMENT_QUEUE
- CREATE_LEAD
- ASSIGN_LEAD
- REASSIGN_LEAD
- CLOSE_LEAD
- CREATE_CUSTOMER
- MERGE_CUSTOMER_IDENTITY
- CREATE_BOOKING
- CREATE_BOOKING_ITEM
- APPROVE_BOOKING
- ISSUE_BOOKING
- CANCEL_BOOKING
- REFUND_BOOKING
- REISSUE_BOOKING
- APPROVE_FINANCE
- EDIT_LOCKED_COST
- SET_EXCHANGE_RATE
- CREATE_EXCHANGE_RATE_ADJUSTMENT
- VIEW_FINANCIAL_DOCUMENTS
- UPLOAD_DOCUMENT
- ARCHIVE_DOCUMENT
- VIEW_ADVANCED_DASHBOARDS
- MANAGE_SUBSCRIPTION
- REVIEW_SUBSCRIPTION_PAYMENT
- ACCESS_API_READ_ONLY
- ACCESS_API_FULL
- UPDATE_BOOKING_ITEM_STATUS
- ASSIGN_SUPPLIER
- ENTER_SELLING_PRICE
- ENTER_COST
- CREATE_INVOICE
- CREATE_RECEIPT
- RECORD_PAYMENT
- RECORD_REFUND
- CREATE_JOURNAL_ENTRY
- VIEW_TRAVEL_DOCUMENTS
- CREATE_DOCUMENT_VERSION
- VIEW_SUBSCRIPTION_STATUS
- CREATE_TASK
- ASSIGN_TASK
- COMPLETE_TASK
- VIEW_ASSIGNED_TASKS
- VIEW_DEPARTMENT_TASK_QUEUE
- CREATE_COMPLAINT
- RESOLVE_COMPLAINT
- VIEW_COMPLAINT
- CREATE_SERVICE_REQUEST
- RESOLVE_SERVICE_REQUEST
- VIEW_SERVICE_REQUEST
- CREATE_QUOTATION
- SEND_QUOTATION
- ACCEPT_QUOTATION
- VIEW_CONVERSATION
- SEND_MESSAGE
- ESCALATE_CONVERSATION
- CLOSE_CONVERSATION
- MANAGE_MARKETING_CAMPAIGN
- VIEW_MARKETING_DASHBOARD
- REVIEW_APPROVAL_REQUEST

Usage:

- Permissions matrix
- API authorization
- UI feature access

---

# Booking Catalogs

## booking_status

Ownership: System Catalog

Values:

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

Usage:

- Booking state
- Booking reporting

## booking_item_base_status

Ownership: System Catalog

Values:

- draft
- pending
- confirmed
- in_progress
- completed
- cancelled
- no_show

Usage:

- Shared booking item lifecycle

## service_type

Ownership: Tenant-Extendable System Catalog

Default values:

- flight_ticket
- hotel
- visa
- umrah
- hajj
- tour_package
- insurance
- transport
- custom_service

Usage:

- Booking item classification
- Supplier matching
- Item sub-status selection

Tenant additions:

Allowed only in Professional and Enterprise plans with admin permission.

## ticket_sub_status

Ownership: System Catalog

Values:

- reserved
- ticketed
- reissued
- void

Usage:

- Flight ticket booking item detail

## visa_sub_status

Ownership: System Catalog

Values:

- documents_pending
- embassy_submitted
- approved
- rejected

Usage:

- Visa booking item detail

## hotel_sub_status

Ownership: System Catalog

Values:

- reserved
- confirmed
- checked_in
- checked_out

Usage:

- Hotel booking item detail

## passenger_type

Ownership: System Catalog

Values:

- adult
- child
- infant

Usage:

- Group travel
- Passenger pricing

## passenger_relationship_code

Ownership: System Catalog

Values:

- self
- spouse
- child
- parent
- relative
- friend
- employee
- other

Usage:

- Passenger relationship to primary customer
- Passenger history and booking context

## quotation_status_code

Ownership: System Catalog

Values:

- draft
- sent
- accepted
- rejected
- expired
- cancelled

Usage:

- Quotation workflow
- Lead to booking conversion

## cabin_class_code

Ownership: System Catalog

Values:

- economy
- premium_economy
- business
- first

Usage:

- Future ticket details
- Not required in first schema tables unless ticket detail expansion is approved

## fare_type_code

Ownership: System Catalog

Values:

- refundable
- non_refundable
- partially_refundable
- flexible
- promotional

Usage:

- Future ticket details
- Cancellation/refund decision support

## booking_cancellation_reason_code

Ownership: System Catalog

Values:

- customer_cancelled
- payment_not_received
- supplier_unavailable
- price_changed
- document_missing
- duplicate_booking
- operational_error
- other

Usage:

- Booking cancellation workflow

## service_request_type_code

Ownership: System Catalog

Values:

- complaint
- flight_change
- hotel_change
- seat_request
- meal_request
- extra_baggage
- invoice_request
- airport_transfer
- special_assistance
- visa_follow_up
- other

Usage:

- Customer service and complaint categorization
- Operational service request workflows

## service_request_status_code

Ownership: System Catalog

Values:

- requested
- in_progress
- awaiting_customer
- awaiting_supplier
- resolved
- closed

Usage:

- Service request workflow tracking

## service_request_severity_code

Ownership: System Catalog

Values:

- low
- normal
- high
- urgent
- critical

Usage:

- Service request prioritization

## complaint_status_code

Ownership: System Catalog

Values:

- new
- acknowledged
- in_progress
- awaiting_customer
- awaiting_supplier
- resolved
- closed

Usage:

- Complaint workflow tracking

## complaint_severity_code

Ownership: System Catalog

Values:

- low
- normal
- high
- urgent
- critical

Usage:

- Complaint prioritization

## complaint_category_code

Ownership: System Catalog

Values:

- service_quality
- pricing
- supplier_issue
- ticketing
- documentation
- baggage
- visa
- other

Usage:

- Complaint classification

---

# Conversation Catalogs

## channel_code

Ownership: System Catalog

Values:

- phone
- whatsapp
- email
- website_form
- internal
- other

Usage:

- Conversations
- Messages
- Lead interactions

## conversation_status_code

Ownership: System Catalog

Values:

- open
- assigned
- pending_customer
- pending_internal
- escalated
- closed

Usage:

- Unified Inbox
- Customer service queue

## sender_type_code

Ownership: System Catalog

Values:

- customer
- user
- system
- external_provider

Usage:

- Conversation messages

## message_direction_code

Ownership: System Catalog

Values:

- inbound
- outbound
- internal

Usage:

- Conversation messages

---

# Supplier Catalogs

## supplier_type

Ownership: Tenant-Extendable System Catalog

Default values:

- airline
- hotel
- embassy
- visa_provider
- travel_company
- freelancer
- internal_department
- general_supplier

Usage:

- Supplier classification
- Booking item supplier selection
- Finance reporting

Tenant additions:

Allowed with admin permission.

## supplier_payment_term_code

Ownership: System Catalog

Values:

- prepaid
- pay_on_confirmation
- net_7
- net_15
- net_30
- credit_limit

Usage:

- Supplier commercial payment terms
- Supplier credit and settlement policies

---

# Finance Catalogs

## finance_approval_type

Ownership: System Catalog

Values:

- receipt_based
- direct_approval

Usage:

- Finance approval gate

Status:

Deprecated as a separate physical workflow category if `approval_type_code` is used.

Kept for backward terminology only.

## approval_type_code

Ownership: System Catalog

Values:

- finance_execution_approval
- refund_approval
- discount_approval
- booking_override
- manual_price_change
- sensitive_data_change
- subscription_approval

Usage:

- Generic approval requests

## approval_status_code

Ownership: System Catalog

Values:

- pending
- approved
- rejected
- cancelled

Usage:

- Generic approval workflow

## invoice_status_code

Ownership: System Catalog

Values:

- draft
- issued
- partially_paid
- paid
- voided
- overdue

Usage:

- Invoices
- Finance dashboard

## refund_status_code

Ownership: System Catalog

Values:

- requested
- approved
- rejected
- processing
- completed
- cancelled

Usage:

- Refunds
- Refund requests queue

## tax_submission_status_code

Ownership: System Catalog

Values:

- pending
- submitted
- failed
- accepted
- rejected

Usage:

- External tax and receipt submission tracking
- Future e-invoice / e-receipt integration

## payment_direction

Ownership: System Catalog

Values:

- customer_payment
- supplier_payment
- customer_refund
- supplier_refund

Usage:

- Payment and refund classification

## payment_method

Ownership: Tenant-Extendable System Catalog

Default values:

- cash
- bank_transfer
- card
- wallet
- other

Usage:

- Payments
- Receipts
- Finance reporting

Tenant additions:

Allowed with finance manager permission.

## expense_category_code

Ownership: Tenant Catalog

Default values:

- advertising
- office
- salaries
- supplier_cost
- bank_fees
- transportation
- utilities
- other

Usage:

- Future expense recording
- Finance reports

Tenant additions:

Allowed with finance manager permission.

## refund_reason_code

Ownership: System Catalog

Values:

- customer_cancelled
- supplier_cancelled
- service_unavailable
- price_difference
- duplicate_payment
- operational_error
- other

Usage:

- Refund workflow

## financial_account_type

Ownership: System Catalog

Values:

- bank
- cash

Usage:

- Financial accounts
- Balance tracking

## journal_entry_source_type

Ownership: System Catalog

Values:

- invoice
- receipt
- payment
- refund
- exchange_rate_adjustment
- manual_entry
- booking_item

Usage:

- Journal entry classification

## exchange_rate_adjustment_reason

Ownership: System Catalog

Values:

- incorrect_rate
- post_issuance_correction
- finance_review
- management_approval
- other

Usage:

- Exchange Rate Adjustment

---

# Document Catalogs

## document_type

Ownership: System Catalog

Values:

- passport
- national_id
- visa
- ticket
- hotel_voucher
- invoice
- receipt
- quotation
- contract
- medical_certificate
- photo
- other

Usage:

- Document upload
- Required metadata
- Permissions
- Expiry alerts

## allowed_file_type

Ownership: System Catalog

Values:

- pdf
- jpg
- jpeg
- png
- webp

Usage:

- Upload validation

## document_lifecycle_status

Ownership: System Catalog

Values:

- active
- archived
- superseded

Usage:

- Document archive
- Versioning

## confidentiality_level_code

Ownership: System Catalog

Values:

- normal
- confidential

Usage:

- Document visibility
- Customer notes visibility

## document_link_target_type

Ownership: System Catalog

Values:

- passenger
- booking
- booking_item
- invoice
- receipt
- supplier
- subscription_payment

Usage:

- Document linking

---

# Notification Catalogs

## notification_type

Ownership: System Catalog

Values:

- lead_sla_warning
- lead_reassigned
- finance_approval_result
- passport_expiry
- document_expiry
- customer_balance
- supplier_balance
- subscription_expiry
- subscription_read_only
- security_alert

Usage:

- In-system notifications
- Future notification delivery channels

## notification_channel

Ownership: System Catalog

Values:

- in_system
- email
- whatsapp

Usage:

- Notification delivery

## notification_delivery_status

Ownership: System Catalog

Values:

- pending
- sent
- failed
- read

Usage:

- Notification delivery tracking

---

# Subscription Catalogs

## subscription_plan_code

Ownership: System Catalog

Values:

- starter
- professional
- enterprise

Usage:

- Plan assignment
- Feature entitlements
- Usage limits

## subscription_status

Ownership: System Catalog

Values:

- trial
- active
- grace_period
- read_only
- suspended
- cancelled
- expired

Usage:

- Tenant access control
- SaaS billing state

## feature_code

Ownership: System Catalog

Initial values:

- crm
- booking
- documents
- suppliers
- finance_lite
- full_finance
- basic_reporting
- advanced_dashboards
- api_read_only
- api_full
- automation
- integrations
- offline_conversion
- ai_dashboard
- multi_branch

Usage:

- Feature entitlements
- Plan limits
- UI/API access

## usage_metric_code

Ownership: System Catalog

Values:

- users
- branches
- monthly_leads
- monthly_bookings
- storage_gb
- automations

Usage:

- Subscription usage limits

---

# Authentication And Security Catalogs

## verification_method

Ownership: System Catalog

Values:

- email_otp
- totp

Usage:

- Trusted device verification
- High-risk login

## trusted_device_status

Ownership: System Catalog

Values:

- trusted
- revoked
- expired

Usage:

- Device trust

## otp_challenge_status

Ownership: System Catalog

Values:

- pending
- verified
- failed
- expired

Usage:

- Email OTP verification

## security_event_type

Ownership: System Catalog

Values:

- login_attempt
- login_success
- login_failure
- otp_request
- otp_verification_success
- otp_verification_failure
- totp_enrollment
- totp_challenge_success
- totp_challenge_failure
- new_device_verification
- password_change
- password_reset
- account_lock
- permission_change

Usage:

- Security event log

---

# Offline Conversion Catalogs

## offline_conversion_event_type

Ownership: System Catalog

Values:

- qualified_phone_call
- qualified_lead
- booking_created
- payment_received
- ticket_issued

Usage:

- Offline conversion creation
- Google Ads upload

## offline_conversion_delivery_status

Ownership: System Catalog

Values:

- pending
- sent
- failed
- retried

Usage:

- Offline conversion delivery tracking

## attribution_source

Ownership: System Catalog

Values:

- google_ads
- meta_ads
- website
- whatsapp
- direct
- manual
- other

Usage:

- Click/session attribution
- Lead attribution

## platform_code

Ownership: System Catalog

Values:

- google_ads
- meta_ads
- whatsapp_cloud_api
- website
- manual
- other

Usage:

- Marketing campaigns
- Offline conversion delivery
- Integration tracking

## campaign_status_code

Ownership: System Catalog

Values:

- draft
- active
- paused
- ended
- archived

Usage:

- Marketing campaigns

---

# Reference Data

The following datasets are Reference Data and should not be stored in generic `catalog_values` by default:

- countries
- cities
- currencies
- languages
- nationalities
- airports

Recommended storage:

- Dedicated reference tables
- Seeded data
- Stable ISO-like codes where available

Usage examples:

- `destination_country_code`
- `currency_code`
- `preferred_language_code`
- `nationality_code`
- `passport_issuing_country_code`

Rule:

Only move reference data into catalog_values if tenant-specific customization becomes a real business requirement.

---

# Deferred Catalogs

The following catalogs are deferred until their modules are approved:

- Tax codes
- Depreciation methods
- GDS provider codes
- Payroll statuses
- Full workflow engine action types
- Data warehouse dimensions
- Marketplace extension types

---

# Next Step

Create `26_state_machines.md`.
