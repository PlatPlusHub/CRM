# SaaS Plan Matrix

Version: 0.1
Status: Draft
Canonical: Yes

---

# Plan Names

Initial SaaS plans:

- Starter
- Professional
- Enterprise

---

# Starter

Starter is CRM-only.

Included:

- Leads
- Customers
- Basic lead assignment
- Basic customer follow-up

Excluded:

- File uploads
- Booking creation
- Finance
- Advanced dashboards
- API
- Automation
- Multi-branch advanced operations

Starter supports leads and customers only.

---

# Professional

Professional includes operational workflow.

Included:

- CRM
- Booking
- Documents
- Suppliers
- Finance Lite
- Basic reporting

Finance Lite must be defined carefully. It may include practical receivables, payables, invoices, receipts, and basic journals, but exclude advanced finance analytics and enterprise-level financial controls.

---

# Enterprise

Enterprise includes all approved features.

Included:

- CRM
- Booking
- Full finance
- Advanced dashboards
- Analysis and monitoring
- API access
- Automation
- Multi-branch operations
- Integrations
- AI dashboard where approved

---

# Advanced Analytics

Advanced analytics are Enterprise-only.

---

# Plan Numeric Limits

Initial plan limits:

| Feature | Starter | Professional | Enterprise |
| --- | --- | --- | --- |
| Users | 5 | 15 | Unlimited |
| Branches | 1 | 3 | Unlimited |
| Monthly Leads | 500 | 10,000 | Unlimited |
| Monthly Bookings | 100 | 3,000 | Unlimited |
| Storage | 2 GB | 5 GB | Custom |
| Automations | 5 | 100 | Unlimited |
| API | No | Read Only | Full |

These limits are product defaults and may later become configurable per subscription contract.

Database semantics (AUDIT-2 / PD-23 closure, 2026-09-09): the six numeric metrics are stored in `feature_entitlements.limit_value`; `NULL` is the sole representation of no ceiling, including Enterprise "Unlimited" and "Custom". Negative and large sentinel values are forbidden by convention and regression guard. Numeric ceilings are readable through `app.plan_limit` but are deliberately **not enforced** while pricing is provisional: `usage_counters` has no producer or reader. Boolean feature availability remains independently enforced through `app.plan_allows` and `app.has_permission`. Numeric enforcement is a later pricing-activation capability, triggered only when pricing is finalized or a real tenant approaches a ceiling; it must distinguish current-state limits from period consumption.
