# Offline Conversion Engine

Version: 0.1
Status: Draft
Canonical: Yes

---

# Purpose

Offline Conversion Engine connects CRM outcomes to advertising platforms.

The goal is to optimize ads based on real business value, not only raw clicks or unqualified calls.

This is especially important in markets where Google Forwarding Numbers or native call reporting are limited or unavailable.

---

# Source Of Truth

ORVION CRM is the source of truth for lead quality, qualified calls, bookings, payments, and issued services.

Google Ads should receive meaningful business events from ORVION instead of relying only on direct call tracking.

---

# Attribution Flow

```text
Google Ads
  -> Landing Page
  -> GCLID / session id / click id captured
  -> ORVION CRM lead
  -> Sales records caller number and call result
  -> ORVION Attribution Engine matches lead to click data
  -> ORVION creates internal conversion event
  -> ORVION sends offline conversion to Google Ads
```

---

# Captured Click Data

The system should capture and store:

- GCLID
- GBRAID (iOS / app-campaign click id)
- WBRAID (web-to-app click id)
- Session ID
- Click ID where available
- Consent signals (ad_user_data, ad_personalization) — required for Data Manager API delivery
- Landing page URL
- UTM source
- UTM medium
- UTM campaign
- UTM content
- UTM term
- Timestamp
- Tenant
- Lead source

---

# Sales Call Data

Sales may record:

- Caller phone number
- Call date and time
- Call duration where available
- Call outcome
- Lead quality
- Next action

Call duration is optional unless available from an integrated telephony provider.

---

# Conversion Events

ORVION should send business-value events, not generic conversation events.

Approved candidate conversion events:

- qualified_phone_call
- qualified_lead
- booking_created
- payment_received
- ticket_issued

Google Ads may mark one or more of these as Primary Conversion depending on campaign strategy.

---

# Engine Responsibilities

Offline Conversion Engine is responsible for:

- Receiving CRM outcomes
- Matching phone number, lead, click data, and visit time
- Validating conversion window
- Creating internal conversion records
- Sending offline conversions to Google Ads
- Recording delivery state
- Retrying failed delivery where allowed

---

# Delivery States

Offline conversion delivery states:

- pending
- ingested
- sent
- failed
- retried

Every send attempt must be recorded.

A platform that accepts a request has not yet processed it. Acceptance is `ingested`; a delivery is `sent` only when the platform reports terminal success for that request.

---

# Critical Rule

Critical CRM state must not depend on Google Ads delivery success.

If sending an offline conversion fails, the CRM lead, booking, payment, and ticket workflows continue normally.

The conversion delivery failure is handled separately by retry and monitoring logic.

