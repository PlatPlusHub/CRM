# Document Model

Version: 0.1
Status: Draft
Canonical: Yes

---

# Supported Documents

The system must support upload and retrieval of:

- PDF files
- Images
- Excel files <!-- C2 (2026-07-15 recovery): Excel is deferred for MVP per 16_document_types_and_rules.md (authoritative for MVP document-type scope); no business change. -->
- Other approved document types defined later

---

# Controlled Document Types

Every document must have a predefined document type.

Examples:

- Passport
- Ticket
- Visa
- Invoice
- Receipt
- Bank transfer proof
- Hotel voucher
- Supplier statement

Employees must not create document types freely during upload.

---

# Document Type Fields

Some document types may require structured fields.

Example:

Passport documents may require passport number, issue date, expiry date, nationality, and issuing country.

Visa documents may require visa number, country, issue date, expiry date, and status.

The required fields for each document type will be specified separately.

---

# Document Permissions

Financial documents are visible to finance and management by default.

The responsible employee for a lead or booking may view financial documents directly related to that lead or booking when operationally required.

Example:

An employee can upload and view a customer's bank transfer receipt for their assigned booking, but cannot browse unrelated finance documents.

---

# Archive Only

Documents must not be physically deleted as a normal business action.

Incorrect uploads are archived.

Archive action must record:

- User
- Time
- Reason
- Related entity

---

# Versioning

Document versioning is required.

When a newer document replaces an older one, the older version remains preserved and linked.

The system must show current version and previous versions according to permission.

---

# Retention And Legal Hold

Retention applies only to superseded document versions under an explicit active per-tenant, per-document-type policy. No policy means retain forever. A document-level legal hold always overrides the policy: held data is excluded both from candidate scanning and from action claiming, so one held tenant cannot abort or stall another tenant's scan. Placing and releasing a hold are authorized, reasoned, server-stamped, event-producing actions. The actual retention periods remain counsel-supplied configuration, not an engineering default.

