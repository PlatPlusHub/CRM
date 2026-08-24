# Permissions Matrix

Version: 0.2
Status: Draft
Canonical: Yes

---

# Purpose

This document defines ORVION's first permission model before database schema design.

Permissions must support all company departments while keeping tenant, branch, department, assignment, and subscription boundaries clear.

---

# Permission Principles

- Tenant isolation is mandatory.
- Role alone is not enough.
- Permission checks must consider scope.
- Subscription plan can disable features even if a user has role permission.
- Sensitive operations require explicit permission.
- Every permission change creates a security event.
- Every sensitive permission use creates an event.

---

# Scope Types

## tenant

Applies across the whole company tenant.

## branch

Applies only inside one branch.

## department

Applies only inside one department in one branch.

## assigned

Applies only to records assigned to the user.

## platform

Applies to ORVION platform administration, not tenant operations.

---

# Role Model

## owner

Tenant-level owner.

Can manage company-level settings and high-authority actions.

## ceo

Tenant-level executive user.

Can view and manage company operations across branches according to permissions.

## branch_manager

Branch-level manager.

Can view and manage their branch operations.

## department_manager

Department-level manager inside one branch.

Can manage employees and work inside their department and branch only.

## finance_manager

Finance authority.

Can approve finance actions, set exchange rates, and manage finance-sensitive operations.

## senior_employee

Operational senior user.

Can handle assigned work and may receive limited supervisory permissions.

## employee

Standard operational user.

Can handle assigned work.

## trainee

Restricted user.

Can view or perform limited actions only.

## system_administrator

Platform-level or tenant technical administrator depending on scope.

High-risk authentication required.

---

# Feature Access By Plan

| Feature | Starter | Professional | Enterprise |
| --- | --- | --- | --- |
| CRM | Yes | Yes | Yes |
| Customers | Yes | Yes | Yes |
| Booking | No | Yes | Yes |
| Documents | No | Yes | Yes |
| Suppliers | No | Yes | Yes |
| Finance Lite | No | Yes | Yes |
| Full Finance | No | No | Yes |
| Basic Reporting | Limited | Yes | Yes |
| Advanced Dashboards | No | No | Yes |
| API Read Only | No | Yes | Yes |
| API Full | No | No | Yes |
| Automation | No | Limited | Yes |
| Integrations | No | Limited | Yes |
| Offline Conversion | No | Limited | Yes |
| AI Dashboard | No | No | Yes |
| Multi Branch | No | Limited | Yes |

Plan denial overrides user role permission.

---

# CRM Permissions

| Permission | Owner | CEO | Branch Manager | Department Manager | Senior Employee | Employee | Trainee | Scope |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CREATE_LEAD | Yes | Yes | Yes | Yes | Yes | Yes | Limited | branch/department |
| ASSIGN_LEAD | Yes | Yes | Yes | Yes | Optional | No | No | branch/department |
| REASSIGN_LEAD | Yes | Yes | Yes | Yes | Optional | No | No | branch/department |
| CLOSE_LEAD | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned/department |
| VIEW_ASSIGNED_LEADS | Yes | Yes | Yes | Yes | Yes | Yes | Limited | assigned |
| VIEW_DEPARTMENT_QUEUE | Yes | Yes | Yes | Yes | Optional | No | No | department |
| CREATE_CUSTOMER | Yes | Yes | Yes | Yes | Yes | Yes | No | branch/department |
| MERGE_CUSTOMER_IDENTITY | Yes | Yes | Optional | No | No | No | No | tenant |

Notes:

- Sales employee sees assigned leads only by default.
- Department queue visibility requires explicit permission.
- Customer merge is sensitive and must create event.

---

# CRM Extension Permissions

| Permission | Owner | CEO | Branch Manager | Department Manager | Senior Employee | Employee | Trainee | Scope |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CREATE_TASK | Yes | Yes | Yes | Yes | Yes | Yes | Limited | branch/department |
| ASSIGN_TASK | Yes | Yes | Yes | Yes | Optional | No | No | branch/department |
| COMPLETE_TASK | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned |
| VIEW_ASSIGNED_TASKS | Yes | Yes | Yes | Yes | Yes | Yes | Limited | assigned |
| VIEW_DEPARTMENT_TASK_QUEUE | Yes | Yes | Yes | Yes | Optional | No | No | department |
| CREATE_COMPLAINT | Yes | Yes | Yes | Yes | Yes | Yes | No | branch/department |
| RESOLVE_COMPLAINT | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned/department |
| VIEW_COMPLAINT | Yes | Yes | Yes | Yes | Yes | Assigned only | Limited | assigned/department |
| CREATE_SERVICE_REQUEST | Yes | Yes | Yes | Yes | Yes | Yes | No | branch/department |
| RESOLVE_SERVICE_REQUEST | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned/department |
| VIEW_SERVICE_REQUEST | Yes | Yes | Yes | Yes | Yes | Assigned only | Limited | assigned/department |
| CREATE_QUOTATION | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned/department |
| SEND_QUOTATION | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned |
| ACCEPT_QUOTATION | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned |
| VIEW_CONVERSATION | Yes | Yes | Yes | Yes | Yes | Assigned only | Limited | assigned/department |
| SEND_MESSAGE | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned |
| ESCALATE_CONVERSATION | Yes | Yes | Yes | Yes | Optional | No | No | department |
| CLOSE_CONVERSATION | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned |

Notes:

- Task, Complaint, Service Request, Quotation, and Conversation permissions follow the same assigned/department visibility pattern already established for Leads in the CRM Permissions table above.
- Accepting a Quotation records the customer's decision and is performed by the assigned employee, consistent with the CLOSE_LEAD pattern.

---

# Booking Permissions

| Permission | Owner | CEO | Branch Manager | Department Manager | Finance Manager | Senior Employee | Employee | Trainee | Scope |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CREATE_BOOKING | Yes | Yes | Yes | Yes | No | Yes | Assigned only | No | branch/department |
| CREATE_BOOKING_ITEM | Yes | Yes | Yes | Yes | No | Yes | Assigned only | No | branch/department |
| APPROVE_BOOKING | Yes | Yes | Yes | Yes | No | No | No | No | branch/department |
| ISSUE_BOOKING | Yes | Yes | Yes | No | Yes | No | No | No | branch/department |
| CANCEL_BOOKING | Yes | Yes | Yes | No | Yes | No | No | No | branch/department |
| REFUND_BOOKING | Yes | Yes | Yes | No | Yes | No | No | No | branch/department |
| REISSUE_BOOKING | Yes | Yes | Yes | No | Yes | No | No | No | branch/department |
| UPDATE_BOOKING_ITEM_STATUS | Yes | Yes | Yes | Yes | No | Yes | Assigned only | No | assigned/department |
| ASSIGN_SUPPLIER | Yes | Yes | Yes | Yes | Optional | Yes | Optional | No | branch/department |
| ENTER_SELLING_PRICE | Yes | Yes | Yes | Yes | Optional | Yes | Assigned only | No | assigned |
| ENTER_COST | Yes | Yes | Yes | Yes | Optional | Yes | Assigned only | No | assigned |
| ALLOW_ISSUE_WITH_NEGATIVE_BALANCE | Yes | Yes | Yes | No | Yes | No | No | No | branch/tenant |

Notes:

- Issuing before full collection requires explicit permission and creates risk flag event.
- Department Manager does not receive negative balance issuance permission by default.
- Booking lifecycle authority is capability-driven (ADR-0020): APPROVE_BOOKING governs the booking-level management approval `pending_approval -> confirmed` ("Required approval granted", 26) and is a management act, distinct from the item-level finance execution approval (APPROVE_FINANCE). ISSUE_BOOKING governs `in_progress -> issued` (issuance) and is finance-consequential (owner/ceo/branch_manager/finance_manager); issuing before full collection additionally requires ALLOW_ISSUE_WITH_NEGATIVE_BALANCE and emits the `booking_item_risk_flag_created` risk event capturing the customer balance snapshot. CANCEL_BOOKING governs the post-approval cancellations (`confirmed/in_progress -> cancelled`) and the void (`issued -> void`) and is finance-consequential (owner/ceo/branch_manager/finance_manager); pre-approval cancels (`draft/pending_approval -> cancelled`) stay under CREATE_BOOKING (discarding not-yet-approved work). Every `cancelled` transition requires a cancellation reason (27). REFUND_BOOKING governs `issued -> refunded` and REISSUE_BOOKING governs `issued -> reissue` (both finance-consequential: owner/ceo/branch_manager/finance_manager); completing a re-issuance (`reissue -> issued`) reuses ISSUE_BOOKING, since every transition into `issued` is issuance and runs the negative-balance risk-flag check. This completes the capability-driven booking lifecycle authority set (Submit/Approve/Issue/Cancel/Refund/Reissue) per ADR-0020.

---

# Finance Permissions

| Permission | Owner | CEO | Finance Manager | Branch Manager | Department Manager | Senior Employee | Employee | Scope |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| APPROVE_FINANCE | Yes | Yes | Yes | Optional | No | No | No | tenant/branch |
| EDIT_LOCKED_COST | Yes | Yes | Yes | No | No | No | No | tenant |
| SET_EXCHANGE_RATE | Yes | Yes | Yes | No | No | No | No | tenant |
| CREATE_EXCHANGE_RATE_ADJUSTMENT | Yes | Yes | Yes | No | No | No | No | tenant |
| VIEW_FINANCIAL_DOCUMENTS | Yes | Yes | Yes | Optional | No | Assigned related only | Assigned related only | tenant/branch/assigned |
| CREATE_INVOICE | Yes | Yes | Yes | Optional | No | No | No | tenant |
| CREATE_RECEIPT | Yes | Yes | Yes | Optional | No | No | No | tenant |
| RECORD_PAYMENT | Yes | Yes | Yes | Optional | No | No | No | tenant |
| RECORD_REFUND | Yes | Yes | Yes | Optional | No | No | No | tenant |
| CREATE_JOURNAL_ENTRY | Yes | Yes | Yes | No | No | No | No | tenant |
| REVIEW_APPROVAL_REQUEST | Yes | Yes | Yes | No | No | No | No | tenant |

Notes:

- Assigned employee may view financial documents directly related to their lead/booking.
- Finance approval is required before controlled execution gate.
- Operations cannot edit locked cost.
- REVIEW_APPROVAL_REQUEST governs `approval_requests` rows whose `approval_type_code` is not `finance_execution_approval` (covered by APPROVE_FINANCE) and not `subscription_approval` (covered by REVIEW_SUBSCRIPTION_PAYMENT) — i.e. `refund_approval`, `discount_approval`, `booking_override`, `manual_price_change`, `sensitive_data_change`. This is a conservative default; per-type role refinement is an open business decision (see `reports/phase-02-prioritized-findings.md`).

---

# Document Permissions

| Permission | Owner | CEO | Branch Manager | Department Manager | Finance Manager | Senior Employee | Employee | Trainee | Scope |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UPLOAD_DOCUMENT | Yes | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned/department |
| VIEW_TRAVEL_DOCUMENTS | Yes | Yes | Yes | Yes | Optional | Yes | Assigned only | Limited | assigned/department |
| VIEW_FINANCIAL_DOCUMENTS | Yes | Yes | Optional | No | Yes | Assigned related only | Assigned related only | No | tenant/assigned |
| ARCHIVE_DOCUMENT | Yes | Yes | Yes | Yes | Yes | Optional | No | No | branch/department |
| CREATE_DOCUMENT_VERSION | Yes | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned/department |

Notes:

- Incorrect files are archived, not deleted.
- Financial documents require stricter visibility.

---

# Marketing Permissions

| Permission | Owner | CEO | Branch Manager | Finance Manager | Scope |
| --- | --- | --- | --- | --- | --- |
| MANAGE_MARKETING_CAMPAIGN | Yes | Yes | Optional | No | tenant |
| VIEW_MARKETING_DASHBOARD | Yes | Yes | Optional | Optional | tenant |

Notes:

- Marketing campaigns are tenant-scoped (no branch/department ownership fields exist on `marketing_campaigns`), consistent with `31_schema_draft.md`.

---

# Organization Permissions

| Permission | Owner | CEO | Branch Manager | Department Manager | Finance Manager | System Administrator | Scope |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MANAGE_TENANT_SETTINGS | Yes | Yes | No | No | No | Optional | tenant |
| MANAGE_BRANCHES | Yes | Yes | No | No | No | Optional | tenant |
| MANAGE_DEPARTMENTS | Yes | Yes | Branch only | No | No | Optional | tenant/branch |
| MANAGE_USERS | Yes | Yes | Branch only | Department only | No | Optional | tenant/branch/department |
| MANAGE_ROLES | Yes | Yes | No | No | No | Optional | tenant |
| MANAGE_PERMISSIONS | Yes | Yes | No | No | No | Optional | tenant |
| VIEW_ALL_BRANCHES | Yes | Yes | No | No | Finance related | Optional | tenant |
| VIEW_BRANCH_DATA | Yes | Yes | Own branch | Own department | Finance related | Optional | branch |

Notes:

- Department Manager manages only their department inside their branch.
- Branch Manager sees all departments inside their branch.
- CEO sees all branches.

---

# Subscription Permissions

| Permission | Platform Owner | Owner | CEO | System Administrator | Finance Manager |
| --- | --- | --- | --- | --- | --- |
| MANAGE_SUBSCRIPTION | Yes | Limited | Limited | Optional | No |
| REVIEW_SUBSCRIPTION_PAYMENT | Yes | No | No | No | No |
| VIEW_SUBSCRIPTION_STATUS | Yes | Yes | Yes | Optional | Optional |

Notes:

- Subscription proof review is platform owner action.
- Tenant users may upload proof but cannot approve their own subscription renewal.

---

# API Permissions

| Permission | Starter | Professional | Enterprise |
| --- | --- | --- | --- |
| ACCESS_API_READ_ONLY | No | Yes | Yes |
| ACCESS_API_FULL | No | No | Yes |

API access also requires user-level permission and tenant subscription status.

---

# Authentication Requirements By Role

| Role | Required Additional Verification |
| --- | --- |
| owner | TOTP |
| ceo | TOTP |
| finance_manager | TOTP |
| system_administrator | TOTP |
| branch_manager | Email OTP for new device |
| department_manager | Email OTP for new device |
| senior_employee | Email OTP for new device |
| employee | Email OTP for new device |
| trainee | Email OTP for new device |

---

# Read-Only Subscription Mode

When tenant is in read_only mode:

Allowed:

- Login
- View permitted existing data
- Export/download where permission allows
- Upload subscription renewal proof

Blocked:

- Create lead
- Edit lead
- Create customer
- Create booking
- Create booking item
- Upload business document
- Record payment
- Approve finance
- Create journal entry
- Change operational statuses

Platform owner subscription actions remain allowed.

---

# Event Requirements

The following permission actions always create events:

- Role assigned
- Role removed
- Permission granted
- Permission revoked
- Finance approval
- Locked cost edit
- Exchange rate set
- Exchange rate adjustment
- Negative balance issuance
- Customer identity merge
- Subscription approval
- Document archive
- Lead reassignment

---

# Read Scope Enforcement

Implemented by SPEC-137 (`202607051400_read_scope_model.sql`). Until then the five scope types above
were declarative only: every RLS policy resolved to `tenant_id`, and none of the `VIEW_*` permissions
was enforced anywhere.

A row in a scope-bearing table (`leads`, `bookings`, `booking_items`, `tasks`, `conversations`,
`complaints`, `service_requests`, `quotations`) is readable when **any** of:

| Scope | Condition |
| --- | --- |
| tenant | the caller holds `VIEW_ALL_BRANCHES` |
| assigned | the caller is one of the row's responsible users |
| branch | the row's branch is one the caller works in or governs, **and** the caller holds `VIEW_BRANCH_DATA` |
| department | the row's branch is visible **and** the row's department is one the caller belongs to **and** the caller holds that entity's department-read permission |

Derived children (`conversation_messages`, `quotation_items`, `booking_item_passengers`,
`lead_interactions`, `lead_assignments`) inherit their parent's scope through an `exists` check; they
carry no scope columns, so no second source of truth exists to disagree. Financial records
(`invoices`, `payments`, `receipts`, `refunds`, `payment_allocations`) resolve through
`VIEW_FINANCIAL_DOCUMENTS` **or** a visible related booking, which is the "assigned employee may view
financial documents directly related to their lead/booking" rule in the Finance notes above.

`customers` is deliberately **not** branch-scoped — see `05_customer_identity.md` §Customer
Cross-Branch Awareness. Branch-scoping the master row would prevent a second branch finding a
returning customer and would produce the duplicate canon 05 forbids. The customer's *activity* is
branch-scoped, which is that section's "detailed event content from another branch is not shown".

## Amendments ratified with this model (owner directive 2026-08-24)

1. **Department visibility is granted to `employee` and `senior_employee` by default.** The CRM table
   above marks Employee "No" for `VIEW_DEPARTMENT_QUEUE`. The owner requires that a colleague in the
   same department can continue serving a customer when the assigned employee is absent, and that
   assignment must never mean sole visibility. The mechanism remains permission-gated exactly as the
   note "Department queue visibility requires explicit permission" specifies — only the default grant
   changed. `trainee` is still excluded, which is what keeps the restricted-user boundary real.
2. **`VIEW_DEPARTMENT_RECORDS` is added.** Canon names a `VIEW_*` permission for leads, tasks,
   conversations, complaints and service requests, and none for bookings, booking items or
   quotations. Rather than stretch `VIEW_DEPARTMENT_QUEUE` (a leads concept) over a booking, this
   permission is the department-read gate for those three. Granted to the same roles.
3. **`VIEW_BRANCH_DATA` is granted to `branch_manager`.** The Organization table records "Own branch"
   for that role, but the seed gave the permission to `owner` and `ceo` only — which would have left
   a branch manager seeing just their own department. Department managers are still excluded, per
   "Department Manager manages only their department inside their branch".
4. **`user_role_assignments.scope_type` is constrained** to `tenant` / `branch` / `department` /
   `platform`, and a branch- or department-scoped assignment must carry its qualifying id. `assigned`
   is excluded: it describes a permission's reach over records, not a scope a role can be granted at.

Write authority over identity, organization and configuration tables is enforced by SPEC-138 — see
`changes/SPEC-138-rbac-write-authority.md`.

---

# Plan Gating Enforcement

Implemented by SPEC-146 (`202607052500_plan_gating.sql`). Until then "Plan denial overrides user role
permission" was documented and enforced nowhere: the matrix was seeded and nothing read it.

`permissions.required_feature_code` names the feature a permission depends on (NULL = not
plan-gated), and `app.has_permission` composes `app.plan_allows` after the role check. Because every
RLS policy and every `app.authorize()` already resolve through that one function, the gate covers the
RPC path, direct PostgREST reads and writes, future n8n calls and a future UI without any of them
cooperating.

The plan grants nothing — it only removes. A user still needs the role permission first.

- **Fail-open on absence.** No subscription row, or a feature the matrix does not mention, means no
  denial: a denial requires a plan that denies. Tenants cannot reach this state deliberately —
  `subscriptions` writes need `MANAGE_SUBSCRIPTION`, which no role holds.
- **Terminal states deny.** `suspended` / `cancelled` / `expired` deny every plan-gated permission.
  `read_only` does not: restricting writes for a read-only tenant is subscription-*state* gating,
  which `35 §8` keeps as a separate concern.
- **Ungated on purpose:** `MANAGE_BRANCHES` (Starter excludes `multi_branch` but is entitled to one
  branch — the `max_branches` ceiling is the right control); `crm` / `customers` / `basic_reporting`
  (enabled on every plan); `automation` / `integrations` / `offline_conversion` / `ai_dashboard` (no
  permission exists to attach to).
- **Capability query.** `app.tenant_capabilities()` returns feature, enabled state and ceiling, so a
  client asks rather than inferring capability from a failed write.
- **Ceilings are readable, not enforced.** `app.plan_limit` exposes them; `usage_counters` is empty
  and counting is a separate additive mechanism.

**Revocation is complete, not partial (SPEC-148).** Because the `assigned` scope is itself
permission-gated, an employee whose role assignment has expired — or whose role has been
deactivated — loses sight of their OWN records too, not merely of the department queue.
Deactivating the user (`users.is_active = false`) cuts `app.current_tenant_id()` at the root and so
removes access to all 72 tables at once. Expiry (`user_role_assignments.ends_at`), role
deactivation (`roles.is_active`) and user deactivation are three routes to the same result.

`MANAGE_ROLES` and `MANAGE_PERMISSIONS` have no enforcement point by design: `roles`, `permissions`
and `role_permissions` grant `authenticated` SELECT only, so no tenant user has a writable surface to
guard.

---

# Next Step

Create `29_relationship_map.md`.
