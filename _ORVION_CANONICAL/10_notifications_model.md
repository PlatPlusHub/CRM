# Notifications Model

Version: 0.1
Status: Draft
Canonical: Yes

> **Supersession banner (2026-07-15 Repository Recovery, C3 — no business change):** any authentication/OTP prose here is **superseded by ADR-0017** and `34_authentication_and_identity_principles.md` (auth artifacts belong to Supabase Auth). The notification-domain content itself remains current design intent.

---

# Notification Channels

MVP notification channels:

- In-system notifications for operational alerts
- Email OTP notifications for login

Future channels may include:

- WhatsApp
- Email business alerts
- External automation through n8n

**Email business alerts — owner-directed 2026-09-04 (SUP-4b), provider decision 2026-09-09 (MAIL-1).** The owner requires an email alert to the Company Owner and the Finance Manager when a supplier's exposure exceeds its credit ceiling. ORVION therefore WRITES that obligation: the in-system notification is created and a matching `notification_deliveries` row is recorded on the `email` channel with status `pending`. **Resend is the technically selected default transactional-email provider; that selection is not production authorization. No email is sent today.** PostgreSQL remains provider-neutral and never calls Resend. A future n8n dispatcher claims the delivery ledger, sends with a stable idempotency key derived from the delivery id, and records the result. Provider credentials belong only in n8n's credential store. Production activation requires owner authorization plus the applicable Egyptian PDPC controller/processor and cross-border-transfer approvals, including the licensed destination. Until then `pending` is the truthful state, and nothing may report an alert as delivered.

---

# Mandatory Notifications

Users cannot mute mandatory operational notifications.

Mandatory notifications include:

- Lead not responded alert
- Manager escalation
- Lead reassignment
- Finance approval result for relevant booking
- Passport expiry where configured
- Subscription expiry and read-only warnings

---

# Lead Notifications

Lead delay notifications are immediate.

After 15 minutes without response:

- Notify assigned employee.
- Notify manager.

After another 15 minutes without response:

- Notify reassigned employee.
- Notify manager.
- Record reassignment event.

---

# Finance Notifications

Financial notifications are normally visible to management and finance only.

Exceptions:

The employee responsible for a lead or booking may receive financial notifications directly related to that lead or booking.

Examples:

- Customer has not transferred payment yet.
- Customer refund is still pending.
- Finance approved bank transfer proof.
- Finance rejected bank transfer proof.

---

# Authentication Notifications

Email OTP is required after password validation according to the proposed authentication model.

Every login attempt and OTP verification must be recorded as security events.

