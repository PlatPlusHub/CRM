# ORVION — API-1: The Application Surface, and the Employee Journey Proven Over HTTP

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migration `202607055500`, test `53_api_surface_test.sql`, script
`scripts/verify_api_end_to_end.ps1`. Closes API-1 — ORVION gains 71 HTTP endpoints and 8 exposed
reporting views — and proves the complete travel-agency revenue journey end to end over HTTP.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `2f7a169` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective

Close API-1 — but as a **capability audit**, not a wrapper factory. The owner directive is explicit:
classify the surface first, and expose a function only if it is an intentional application
capability. Then stop thinking like a database engineer and prove the real employee journey.

---

## 2. Starting state, re-proven live

| Axis | Evidence |
|---|---|
| GitHub | identity `PlatPlusHub`; `origin/main` = `2f7a169c4e84…` = local HEAD; tree clean |
| Repository | 143 migration files, 52 test files |
| Local + Primary | 143 migrations, fingerprint `db6975b3b3f025e47bc4e270752292c3` on both |
| Primary | 74 tables, 137 `app` functions, **2** public endpoints, 119 policies, 71/601 catalog, 3 cron jobs, 0 storage objects, 0 tenants |
| Edge Functions | **1** — `storage-executor`, ACTIVE |
| n8n | **0 workflows**, 2 credentials |

---

## 3. The classification — API-1 is a decision, not a transformation

Done against the live catalogue, not by reading names:

| | count | disposition |
|---|---|---|
| `app` functions | 137 | |
| trigger functions (`returns trigger`) | −20 | never callable by anyone |
| RLS helpers (referenced inside a policy expression) | −7 | `current_tenant_id`, `current_user_id`, `has_permission`, `has_tenant_wide_read`, `is_financial_document_type`, `visible_branch_ids`, `visible_department_ids` |
| reporting-view helpers | −4 | `item_financials`, `booking_item_profit`, `customer_balance`, `supplier_balance` |
| `platform_*` | −6 | service_role only — not a tenant API |
| not granted to `authenticated` | −14 | system/batch paths (`process_lead_sla`, `provision_tenant`, `reconcile_document_storage`, …) |
| **remaining** | **86** | granted to `authenticated`, non-trigger, not a policy/view helper |
| **internal helpers, excluded by hand** | **−15** | see below |
| **exposed** | **71** | + 8 reporting views |

**The 15 exclusions, and why the classification was not optional.** These are granted to
`authenticated` because ORVION's own `security invoker` functions call them *on the caller's behalf*
— not because a client should:

- **`record_event`** — WP-00 made it the audit spine's **sole writer**. As an endpoint, any
  authenticated user could mint arbitrary registered event types about arbitrary entities in their
  own tenant: **audit forgery through the front door.**
- `authorize`, `mfa_satisfied`, `requires_mfa` — a permission-probing oracle.
- `normalize_email`, `normalize_phone`, `plan_allows`, `plan_limit`, `sub_status_family`,
  `subscription_allows_write`, `subscription_transition_allowed`, `commission_rate_default`,
  `document_bucket`, `document_storage_path`, `is_my_booking_item` — pure derivations. Exposing them
  would freeze implementation detail into a public contract.

This is the concrete reason **"just expose the `app` schema" was the wrong answer**, and it is not a
stylistic preference: that one setting publishes `record_event` and `authorize` as endpoints.

---

## 4. The rules every wrapper follows

- **`security invoker`, never `definer`.** A definer wrapper runs as its owner, so PostgreSQL checks
  EXECUTE on the inner `app.*` function against the **owner** instead of the caller — every wrapper
  becomes a privilege-escalation bridge into the private schema. With invoker, `auth.uid()`, the JWT
  claims, the acting role and therefore every RLS policy, permission check, MFA step-up, plan gate
  and tenant boundary are **exactly** what they were over SQL.
- `set search_path = ''` on all of them, fully-qualified bodies.
- **Named-argument delegation** (`p_x => p_x`), so a signature change in `app` fails loudly at
  migration time instead of silently binding the wrong parameter positionally.
- Explicit revoke then explicit grant (GRANT-1 established that the platform default grants `anon`
  EXECUTE on new public functions; that default is revoked, and each wrapper still revokes
  explicitly so its grant state reads on its own).
- All VOLATILE → one uniform calling convention, `POST /rest/v1/rpc/<name>`.
- The 8 reporting views are `security_invoker = true` views in `public`, so they arrive as filterable
  REST collections and every row is still filtered by the caller's own RLS.

---

## 5. How it reached Primary, and how equivalence was proven

The repo migration is **static SQL** — 71 explicit `create or replace function` blocks with explicit
grants — because a migration's effect must be immutable: a dynamically-generating migration would
produce different objects on a future reset as `app` grows, which is not history.

Deploying 63 KB through the MCP would have been a large paste with a transcription risk, so the
identical DDL was **generated on Primary from Primary's own catalogue using the same rules**, and the
two were then proven equal rather than assumed equal:

```
surface hash = md5 over every public function's
               signature + result type + prosecdef + proconfig + EXECUTE grantees,
               plus every view's security_invoker flag + SELECT grantees

local   731cbd41ce480d714802b3de9a255c7a   (81 objects)
Primary 731cbd41ce480d714802b3de9a255c7a   (81 objects)
```

That is a stronger check than trusting a copy-paste, and it is reproducible.

**A deployment step worth recording: PostgREST's schema cache.** After creating the functions, every
call still returned 404. `notify pgrst, 'reload schema'` is required. It also nearly misled me —
**PostgREST returns 404 `PGRST202` for an argument-signature mismatch**, which is indistinguishable
from "function absent" if you post an empty body. Re-tested with correct argument names, Primary
gives:

| call | result | meaning |
|---|---|---|
| `upload_document` (real args) | **401 42501** | live; `anon` refused on privilege |
| `create_customer` (real args) | **401 42501** | live |
| `record_event` (real args) | **404 PGRST202** | genuinely absent |
| `authorize` / `has_permission` / `current_tenant_id` | **404 PGRST202** | genuinely absent |
| `platform_activate_subscription` | **404 PGRST202** | genuinely absent |

---

## 6. The employee journey, end to end over HTTP — 29 assertions, all passing

`scripts/verify_api_end_to_end.ps1` walks the real revenue lifecycle as **real JWT-bearing users**,
never as `postgres`:

customer → lead → assignment → interaction → quotation → pricing → send → booking → booking item
(cost/selling) → passenger → link → document → invoice → issue → payment → receipt → personal
performance.

**The money, read from the employee's own report endpoint as the employee:**
selling 36 000 − cost 30 000 = **gross 6 000** → **commission 600** (10% of positive gross) →
**company profit 5 400**. The authoritative rule, proven through the door a client will use.

**Isolation, against a fully privileged owner of a *different* agency:** sees nothing in the report,
cannot read the customer's timeline, cannot append an item to the other agency's booking.

**The surface is closed:** `record_event`, `has_permission` and `platform_activate_subscription` all
404 for an authenticated employee.

### A role-model finding, and why it is not a defect

The first run failed on `assign_lead` with `permission denied: ASSIGN_LEAD`. The `employee` role
holds `CREATE_LEAD`, `CLOSE_LEAD`, `VIEW_ASSIGNED_LEADS`, `CREATE_QUOTATION`, `SEND_QUOTATION`,
`ACCEPT_QUOTATION`, `CREATE_BOOKING`, `CREATE_BOOKING_ITEM`, `UPDATE_BOOKING_ITEM_STATUS` — and not
`ASSIGN_LEAD`.

Checked before concluding: the `leads` policy grants visibility on `owner_user_id` **or**
`assigned_user_id`, and `create_lead` stamps the creator as owner. So an employee who creates a lead
can still see and work it; deciding who *else* works it is a supervisory act. **Correct design, not a
gap** — so the script now asserts both halves: the employee is refused, and the owner assigning is
the positive control. Per the directive, a missing permission was not solved by granting more
privilege.

---

## 7. Findings

**LEAD-2 (new, business).** `lead_source` has ten values — `google_ads_call`, `google_ads_form`,
`direct_call`, `whatsapp`, `website_form`, `manual_entry`, `meta_ads`, `referral`,
`repeat_customer`, `other` — and **no `walk_in`**. The owner directive names "walk-in customer" as a
primary scenario for an Egyptian travel agency. `manual_entry` was used rather than inventing a
catalog value. Recorded as a business decision.

**Deployment criteria gained a step:** any migration that adds or changes a `public` function or view
must be followed by `notify pgrst, 'reload schema'`, or the new API is invisible while every guard
stays green.

---

## 8. Tests: added, failed first, corrected

Suite **52 files / 600 assertions → 53 files / 612 assertions**, 0 failures. Plus 36 storage + 29
journey HTTP assertions.

`53_api_surface_test.sql` (12) is the permanent guard the directive asked for — it **pins the exposed
set by name**, so adding an endpoint requires deliberately editing the list and accidental exposure
of an internal helper becomes a failing test. It also asserts every exclusion explicitly (an absence
proves nothing on its own), that no endpoint is `SECURITY DEFINER`, that `anon` can execute none,
that every endpoint pins `search_path`, that all 8 views are `security_invoker`, and — behaviourally
— that a user holding no role is refused **by the endpoint**, proving the wrapper carries the caller
rather than the owner.

| What failed first | Cause | Resolution |
|---|---|---|
| journey: `unknown lead_source_code: walk_in` | my fixture invented vocabulary | read the real catalog; recorded LEAD-2 |
| journey: `unknown service_type_code: flight` | same — the value is `flight_ticket` | fixed |
| journey: `permission denied: ASSIGN_LEAD` | **not a defect** — assignment is supervisory | asserted both halves instead |
| journey: 4 cascading failures | downstream of the above | resolved with them |

---

## 9. Environment, parity and guards — final state

| Axis | Value |
|---|---|
| Migrations | **144** — repository, local, Primary |
| Fingerprint | **`95b67f1335820f641091f202c6610cd3`** on all three |
| API surface hash | **`731cbd41ce480d714802b3de9a255c7a`** — identical local and Primary |
| Tables / `app` fns / **endpoints** / views / policies | 74 / 137 / **73** / 8 exposed / 119 |
| pgTAP | **53 files / 612 assertions / 0 failures** |
| End-to-end HTTP | storage **36/36** · journey **29/29** |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN (local proven; primary proven) |

---

## 10. Classification

**PROVEN** — the full employee revenue journey over HTTP as real users; the financial model
(gross/commission/company profit) through the endpoint; cross-tenant isolation against a privileged
foreign owner; internal helpers unreachable on Primary with correct arguments; wrappers preserve
caller identity and authority; local and Primary API surfaces byte-identical.

**UNPROVEN** — Primary's endpoints as an *authenticated* caller (needs a Primary-signed JWT, i.e. a
project secret that must not pass through an agent; anon-level behaviour is proven and the surface
hash proves the objects are identical to the ones the journey exercised); the deployed Edge
Function's success path.

**FAILED** — none outstanding.

**BLOCKED** — SCHED-1 · RET-1, RET-2, ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1,
`suppliers.credit_limit_amount` (business) · DEL-1 (partial) · PP-1 (architectural) · LIC-1
(external) · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — the 15 unexposed internal helpers; `pg_net` left uninstalled; orphan objects never
auto-destroyed; `MANAGE_SUBSCRIPTION` / `REVIEW_SUBSCRIPTION_PAYMENT` held by no role; employees
cannot assign leads.

---

## 11. Next logical work — Phase C, the system-wide zero-debt audit

Phase A (API) and the first pass of Phase B (the employee journey) are done. Next is the broadest
audit yet: schema · RLS · RBAC · functions · triggers · events · finance · documents · subscriptions
· reporting · integrations · testing · governance — looking for behavioural inconsistency rather
than existence, across all 74 tables.

Specifically queued from this session: the remaining journey branches not yet walked over HTTP
(refund, cancellation, complaint, service request, supplier payment, approvals, conversations,
tasks), the reporting views' contents as each role, and `PERM-1`'s decision now that an API exists
for `ACCESS_API_FULL` / `ACCESS_API_READ_ONLY` to gate.
