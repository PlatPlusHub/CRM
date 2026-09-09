# Finance Rules

Version: 0.1
Status: Draft
Canonical: Yes

---

# Chart Of Accounts

The system provides a default chart of accounts.

Each company may customize the chart of accounts according to permissions.

The default chart must support travel-company operations without unnecessary enterprise complexity.

---

# Finance Approval Before Issuance

Service issuance must be prevented if finance approval has not been granted.

Approval can be:

- Receipt-based approval
- Direct finance approval

The approval must be recorded as an immutable event.

---

# Sales Price And Cost Entry

Sales employees may enter:

- Selling price
- Cost

Reason:

The sales employee who sells the service often knows both the selling price and the operational cost.

Cost visibility and edit permissions must still be controlled by role and department policy.

After finance approval, cost is locked.

After locking, cost can be edited only by:

- Owner
- CEO
- Finance Manager

Operations cannot edit cost.

Every locked-cost edit must be recorded in the audit log.

---

# Exchange Rate Authority

Manual exchange rates may be set only by:

- Finance manager
- Company manager

Other employees cannot define exchange rates.

---

# Exchange Rate Locking

Exchange rate may be modified before or during issuance if permitted.

After issuance and execution, the exchange rate is locked.

Any later correction must be handled through an Exchange Rate Adjustment.

Every payment records the currency in which value arrived. When that currency differs from the invoice currency, the allocation must also carry a positive exchange rate, the allocated amount in invoice currency, and a server-derived evidence timestamp; a cross-currency payment is never silently treated as same-currency.

Quotation header and line monetary totals are never negative. The header total is derived from its lines and has one enforcement home; callers may not supply or independently maintain a second total.

---

# Exchange Rate Adjustment

Exchange Rate Adjustment is a formal financial operation.

It must record:

- Original rate
- New rate
- Affected booking item
- Affected journal entries
- User
- Time
- Reason
- Approval if required

The adjustment must be fully visible in the audit log.

---

# Finance Lite Scope

Professional plan Finance Lite includes:

- Customer receivables
- Supplier payables
- Payments
- Receipts
- Invoices
- Refunds
- Basic journal entries
- Profit per booking
- Outstanding balance

Professional plan Finance Lite excludes:

- Balance sheet
- Income statement
- Cash flow
- Fixed assets
- Tax engine
- Period closing
- Revaluation
- Consolidation
