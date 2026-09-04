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

**Email business alerts — owner-directed 2026-09-04 (SUP-4b), and the boundary stated exactly.** The owner requires an email alert to the Company Owner and the Finance Manager when a supplier's exposure exceeds its credit ceiling. ORVION therefore now WRITES that obligation: the in-system notification is created and a matching `notification_deliveries` row is recorded on the `email` channel with status `pending`. **No email is sent.** ORVION has no email provider — no SMTP, and no third-party mail service is configured or referenced anywhere in the repository — so `pending` is the truthful terminal state today, and a dispatcher (n8n or a worker) reading that ledger is the remaining work. Nothing in the repository may report this alert as *delivered* until such a dispatcher exists and has been proven end to end.

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

