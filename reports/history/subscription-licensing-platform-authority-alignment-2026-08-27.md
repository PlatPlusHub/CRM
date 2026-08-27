# ORVION — Alignment: Subscriptions, Trial, Licensing, Platform Authority & Employee Performance

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: The owner-proposed business requirements of 2026-08-27, evaluated against live evidence
before any implementation, per the owner's §14 ("REQUIRED OUTPUT BEFORE IMPLEMENTATION").

Predecessor: `spec-155-commission-system-derived-2026-08-27.md`.

---

## HOW THIS WAS PRODUCED

Every claim below was read live this session from the local stack (`postgres-local`) and Primary
(`supabase-primary`), or from the repository files, and is labelled **PROVEN** where a command was
run. Nothing was accepted from chat history, from a prior report, or from the owner's message.

Boot verified first: repository = local = Primary at **127 migrations**, fingerprint
`8ed3ef86e9df137d0cd5d2fc5eb55a52`; `REPOSITORY CONSISTENCY: CLEAN`; `DATABASE PARITY: CLEAN
(local proven; primary proven)`; Primary ref `vrvtsxexkiiiivlkdxzp`; tree clean.

---

## A. WHAT THE CURRENT SYSTEM ALREADY SUPPORTS

The owner's proposal is, to an unusual degree, **already canon**. It is largely not a new direction —
it is the direction the repository never finished implementing.

| Owner requirement | Already present | Evidence |
|---|---|---|
| trial → active → grace_period → read_only → suspended/expired/cancelled | **Exactly these 7 states**, seeded and FK-constrained | `catalog_values.subscription_status` = trial, active, grace_period, read_only, suspended, cancelled, expired |
| "inspect the existing state machine first; do not create a second lifecycle" | Canon 26 defines the full transition table, including *"Platform owner suspends tenant"*, *"Platform owner restores subscription"*, *"Manual reactivation by platform owner"* | `26_state_machines.md` §Subscription State Machine |
| writes restricted per subscription state | **Enforced at the DB layer** on 42 tables by a trigger gate (WP-03), with system paths skipping rather than aborting | `app.enforce_subscription_write_gate`, `app.subscription_allows_write` |
| reads retained when writes are denied | Property of the mechanism — triggers do not fire on SELECT | WP-03 migration note |
| grace period | Canon fixes it at **two days** | `09_saas_plans_and_access.md` §Subscription Expiry |
| read-only semantics (login, view, export, upload renewal proof; no business writes) | Canon enumerates the exact allow/block list | `28_permissions_matrix.md` §Read-Only Subscription Mode |
| Platform Owner ≠ Tenant Owner/CEO | Canon 28's subscription matrix has a **Platform Owner column distinct from Owner and CEO** | `28_permissions_matrix.md` line 290 |
| tenant cannot approve its own renewal | Canon: *"Tenant users may upload proof but cannot approve their own subscription renewal."* | `28` §Subscription Permissions notes |
| renewal by uploaded proof | `subscription_payment_proofs` table exists with `uploaded_by` / `reviewed_by` / `status_code` / `review_notes` | live schema |
| activation-code idea | Recorded in canon as an **idea under consideration**, explicitly *"requires security review before implementation"*, open as decision **C4** | `09` §Activation Code Idea |
| auditability of transitions | 11 `subscription_*` event types already registered in the event vocabulary | `catalog_values.event_type` |
| platform-only commercial authority | `app.provision_tenant` is granted to **`service_role` only** — the platform surface already exists as an established pattern | `proacl` = `postgres=X \| service_role=X`; migration note: *"by service_role (platform owner / backend), never by tenants themselves"* |
| employee performance report | A `reporting` schema of **7 `security_invoker` views** granted `SELECT` to `authenticated`, scoped by the underlying tables' RLS | `reporting.booking_item_profit`, `sales_activity`, `lead_performance`, `booking_pipeline`, `customer_outstanding`, `supplier_outstanding`, `subscription_state` |
| **one financial truth** | **PROVEN.** Only `app.item_financials` computes gross profit. `app.booking_item_profit` delegates to it; `reporting.booking_item_profit` delegates to that. A repository-wide sweep for any second `selling_amount - cost_amount` found **no other computation** | `pg_get_functiondef` + `grep` over all 127 migrations |
| sales vs operational responsibility | `booking_items` carries a full **sales placement triple** — `sales_owner_user_id` / `sales_owner_department_id` / `sales_owner_branch_id` — alongside `owner_*` and `operational_owner_user_id` | live schema |
| high-risk auth for platform actions | `app.requires_mfa()` already names `system_administrator` in the aal2 set | live function body |

**Conclusion for A:** the owner is not asking for a new architecture. Most of this is canon that was
never wired.

---

## B. WHAT THE CURRENT SYSTEM CONTRADICTS

Twelve contradictions, each proven live this session. The first three are production defects.

### B1 — A newly provisioned tenant cannot write anything. **PROVEN. Severity: critical.**

`app.provision_tenant` creates the tenant, the owner user and the owner role assignment — and
**no `subscriptions` row at all**. `app.subscription_allows_write` returns **false** when no
subscription exists:

```
select app.subscription_allows_write(gen_random_uuid());  -->  false
```

Since WP-03 attached the write gate to 42 tables, a freshly provisioned tenant can create branches,
departments and users (all exempted) but **cannot create a customer, a lead, a booking, a quotation,
a payment or a document.** Day one of a real agency fails. This is the technical half of BLOCKED-1
and it is not a policy question — provisioning simply never finished.

### B2 — The subscription date columns are decorative. **PROVEN. Severity: high.**

`subscriptions.ends_at`, `grace_ends_at` and `read_only_started_at` are written by the create-table
migration and read by **exactly one** consumer — the `reporting.subscription_state` view. No function
consumes them; `app.subscription_allows_write` reads only `subscription_status_code`. There is
**no scheduled job** that advances subscription state (`cron.job` holds exactly one entry,
`lead-sla-processor`).

Therefore: **a trial whose `ends_at` passed a year ago retains full write access forever.** The
owner's "automatic expiry transition" does not exist, and neither does anything that would make a
30-day limit mean anything.

### B3 — Two opposite answers to "this tenant has no subscription". **PROVEN.**

`app.subscription_allows_write` **fails closed** (`coalesce(..., false)`); `app.plan_allows`
**fails open** (`coalesce(..., true)`). Canon 28 documents the fail-open as deliberate. The
contradiction is real but the correct resolution is **not** to flip a canon-documented behaviour —
it is to make the absence state unreachable (B1's fix), which is what canon already assumes when it
says *"Tenants cannot reach this state deliberately."*

### B4 — No tenant-level trial record; nothing prevents repeated trials.

There is no `trial_started_at` / `trial_ends_at` anywhere. `subscription_allows_write` selects
`order by s.created_at desc limit 1`, which means **multiple subscription rows per tenant are
expected by design** — so any trial fact stored on the subscription row is lost the moment a second
row is written. Nothing records that a tenant ever consumed a trial.

### B5 — No commercial duration concept at all.

`subscription_plans` holds only `plan_code / name / description / is_active`. There is no billing
period, no renewal flag, no price, and no way to express monthly / quarterly / semi-annual / annual /
lifetime. Canon 17's plan matrix is feature-and-limit only. This part of the owner's proposal is
genuinely new structure.

### B6 — The subscription lifecycle is unreachable from inside a tenant. **PROVEN.**

`MANAGE_SUBSCRIPTION` and `REVIEW_SUBSCRIPTION_PAYMENT` are held by **no role** — while the RLS
policies on `subscriptions` require `MANAGE_SUBSCRIPTION` for INSERT/UPDATE/DELETE and
`subscription_payment_proofs.scope_update` requires `REVIEW_SUBSCRIPTION_PAYMENT`.

This is **exactly the owner's intended model, already in force by accident of omission** — but it is
undocumented, untested, and indistinguishable from orphaned debt. It must become a deliberate,
guarded property rather than a coincidence.

### B7 — `system_administrator` demands MFA and grants nothing. **PROVEN.**

The role holds **0 permissions**, yet `app.requires_mfa()` lists it among the aal2 roles. Canon 28
describes it as *"Platform-level **or** tenant technical administrator depending on scope"* — an
ambiguity canon never resolves. This is the undefined platform authority the owner names in §5.

### B8 — 11 subscription events registered, 0 producers. **PROVEN.**

`subscription_created`, `subscription_activated`, `subscription_entered_grace_period`,
`subscription_entered_read_only`, `subscription_suspended`, `subscription_expired`,
`subscription_cancelled`, `subscription_reactivated`, `subscription_payment_proof_uploaded`,
`subscription_payment_approved`, `subscription_payment_rejected` — all in the registry, none emitted
anywhere in 127 migrations. Canon 26 names the first five as **required**.

### B9 — `tenants.status` is a second, unconstrained lifecycle.

Free text, **no CHECK constraint, no FK**, set to `'trial'` by `provision_tenant`, and **read by
nothing**. Canon 35 §8 already names `subscriptions.subscription_status_code` as the single authority
and expressly flags `tenants.status` as a competing source; WP-03 deliberately declined to use it.
The owner's "do not create a second lifecycle" instruction is therefore already violated — by a
column that exists but means nothing.

### B10 — `p_commission_rate` is a silently ignored RPC parameter.

Carried forward from SPEC-155 as classified debt.

### B11 — Five orphaned permissions. **PROVEN.**

`ACCESS_API_FULL`, `ACCESS_API_READ_ONLY`, `MANAGE_SUBSCRIPTION`, `REVIEW_SUBSCRIPTION_PAYMENT`,
`VIEW_ADVANCED_DASHBOARDS` are held by no role. Two of them (B6) are load-bearing *deny-all* gates
and must be documented as such; the other three need classification.

### B12 — Sales / operational / general ownership are structurally separate but operationally identical. **PROVEN.**

`app.create_booking_item` sets `owner_user_id`, `sales_owner_user_id` **and**
`operational_owner_user_id` all to the same `v_actor`, plus both placement triples. No RPC anywhere
reassigns booking-item ownership. So the three fields the owner asks about in §9 are, today, always
the same person — the distinction is real in the schema and unrealized in behaviour.

---

## C. WHAT THE OWNER REQUIREMENTS IMPLY TECHNICALLY

1. **The trial must be a tenant-level, write-once fact.** Because multiple subscription rows per
   tenant are expected (B4), non-restartability cannot live on `subscriptions`. It belongs on
   `tenants` as `trial_started_at` / `trial_ends_at`, made immutable by a trigger once set.
2. **Provisioning must create the subscription.** Trial start, trial end (+30 days), plan, and
   `subscription_status_code = 'trial'` in the same transaction as the tenant — otherwise B1.
3. **"Full feature access during trial" means the Enterprise entitlement set,** because
   `feature_entitlements` is keyed by `subscription_plan_id` and `enterprise` is the only plan whose
   rows are all enabled. Trial = Enterprise plan + `trial` state is the only way to express it
   without inventing a fourth plan.
4. **Dates must become load-bearing** in two independent places: a scheduled job that advances
   state (the primary mechanism, per canon 26), and the write gate itself (defence in depth, so a
   late job does not grant free write time).
5. **Commercial durations need a catalog family and a column,** not a hardcoded list.
6. **Lifetime must be `ends_at IS NULL`,** not a far-future date — and a constraint must make the two
   inseparable, so no future writer can express "lifetime" with a date.
7. **Platform authority cannot be a tenant permission.** This is a *structural* proof, not a
   preference: `app.has_permission` resolves the caller through `public.users` joined on
   `u.tenant_id = app.current_tenant_id()`. Any holder of any role is, by construction, inside
   exactly one tenant. A Platform Owner is therefore inexpressible as a role — it must live outside
   the tenant permission model, on the `service_role` surface `provision_tenant` already
   established.
8. **Therefore `MANAGE_SUBSCRIPTION` must stay held by no role** — and that must be asserted by a
   permanent test, so a future "tidy up the orphaned permissions" pass cannot silently grant it.
9. **The employee report must go through `app.item_financials`.** **PROVEN:**
   `has_column_privilege('authenticated', 'public.booking_items', 'cost_amount', 'SELECT')` =
   **false**, and the same for `commission_rate`. A plain view selecting those columns fails for
   every employee. The existing `reporting.booking_item_profit` already solves this with
   `cross join lateral app.item_financials(bi.id)` — the report reuses that shape exactly.
10. **Commission attributes to `sales_owner_user_id`.** Derived, not guessed: canon 31 states
    `commission_rate` reserves the basis for *sales* commission, and the schema carries a dedicated
    sales ownership triple. Today it equals `owner_user_id` on every row (B12), so the choice is
    behaviour-neutral now and correct later.

---

## D. WHICH PARTS ARE BUSINESS RULES (owner's to set — accepted as given)

* Trial length = **30 days**, full feature access, tenant-level, not silently restartable.
* Commercial durations = monthly / quarterly / semi-annual / annual / lifetime.
* Renewable periods may auto-renew; **lifetime does not expire by time**.
* Commercial subscription state is the **Platform Owner's** authority; the tenant Owner/CEO may not
  elevate their own subscription.
* Commission = 10% of gross profit, company takes the remaining 90%, loss ⇒ commission 0
  (already implemented and proven in SPEC-155 — **not** reopened here).
* An employee may see their own results and may not see any other employee's private financial
  results or company-wide totals.

## E. WHICH PARTS ARE ENGINEERING DECISIONS (mine, derived from evidence)

* Trial stamp on `tenants`, immutable by trigger (from B4's "multiple rows expected").
* Trial = Enterprise plan + `trial` state (from C3).
* State advanced by a `pg_cron` job following canon 26's transition table, written in the
  **skip-don't-raise** shape WP-03's cross-path defects taught.
* Write gate becomes date-aware per state (`ends_at` for trial/active, `grace_ends_at` for grace).
* Lifetime = `billing_period_code = 'lifetime'` **and** `ends_at is null`, bound by a CHECK.
* Platform authority = SECURITY DEFINER functions granted to `service_role` only.
* One home for canon 26's transition table: `app.subscription_transition_allowed(from, to)`.
* `tenants.status` constrained to an account-level vocabulary distinct from the commercial lifecycle.
* Employee report as a `security_invoker` view in the existing `reporting` schema.

## F. WHICH PARTS ARE STILL GENUINELY UNKNOWN

Recorded, not guessed, not silently deferred.

* **BLOCKED-4 — commission on reassignment.** Once booking-item ownership becomes transferable
  (it is not today, B12), does the commission follow the new sales owner or stay with the original
  seller? Pure compensation policy; no evidence can settle it. Does **not** block anything now,
  because no transfer path exists.
* **BLOCKED-5 — trial re-grant policy.** The owner requires "prevention of uncontrolled repeated
  trials". Whether the Platform Owner may *deliberately* re-grant a trial (and under what record) is
  policy. Implemented conservatively: the stamp is immutable, and only a platform function could
  ever lift it — no such function is being written.
* **BLOCKED-6 — the three undefined "Limited" plan ceilings** (PLAN-1, pre-existing, unchanged).
* **Notification before expiry** — the owner requires it. `notifications` has **no producer at all**;
  building one inside this package would be a second architecture. Classified **BLOCKED BY
  DEPENDENCY (notifications package)**, with the lifecycle job emitting the canon events that a
  producer will later consume. No new event code is invented for it here.

---

## G. PROPOSED IMPLEMENTATION

Four packages, smallest first, each independently verifiable.

**SPEC-156 — remove the ignored `p_commission_rate` parameter.** Contained; an integration-contract
change that should not ride inside a larger package.

**SPEC-157 — subscription lifecycle, trial, and platform authority.** One coherent capability: *the
subscription lifecycle actually works, and only the Platform Owner drives it.*
* `tenants.trial_started_at` / `trial_ends_at` + immutability trigger; `tenants.status` constrained.
* `subscription_period` catalog family (5 values) + `subscriptions.billing_period_code`,
  `auto_renew`; lifetime CHECK.
* `app.provision_tenant` creates the 30-day Enterprise trial subscription and stamps the tenant,
  refusing a second trial.
* `app.subscription_transition_allowed(from, to)` — canon 26's table, one home.
* `app.process_subscription_lifecycle()` + daily `pg_cron` job: trial→expired, active→grace_period,
  grace_period→read_only, and auto-renewal of renewable periods. Per-tenant, **skip never raise**.
* `app.subscription_allows_write` becomes date-aware per state.
* Platform surface, `service_role` only: `app.platform_activate_subscription(...)`,
  `app.platform_transition_subscription(...)`.
* All five canon-required events emitted, plus activation/expiry/cancellation/reactivation.

**SPEC-158 — tenant license activation credential.** Design settled below; built after 157.

**SPEC-159 — employee performance & earnings report.** `reporting.my_sales_performance` (or a scoped
function if the view cannot express the filters), built on `app.item_financials`.

### G-LICENSE — the credential mechanism (owner §4), decided on evidence

**Recommendation: a single-use, hashed, expiring activation token. Not TOTP.**

Three independent reasons, in order of force:

1. **TOTP requires ORVION to store a shared secret; ORVION has decided it never will.**
   `totp_enrollments` carries `auth_user_id`, `is_active`, `enrolled_at`, `revoked_at` — and
   **no secret column**. Canon 34 §84 places these tables on the Human Identity with the factor
   itself owned by Supabase Auth (ADR-0017). A per-tenant TOTP seed would be the first
   authentication secret ORVION ever stored, and would reverse a ratified decision to obtain a
   *licensing* feature.
2. **TOTP is the wrong shape.** A TOTP seed is a *permanent* credential that yields a valid code
   every 30 seconds forever. An activation credential must be *single-use and revocable*. Building
   one-time semantics on a repeating primitive means adding a consumption record anyway — at which
   point the consumption record is doing all the work and the seed is pure liability.
3. **The owner's own constraints select the simpler primitive.** Issuance, regeneration, revocation,
   rotation, replay control, auditability and compromise recovery are all properties of a stored
   one-time token; none of them are properties TOTP provides.

**Shape:** `tenant_license_activations` — `tenant_id`, `token_hash` (`sha256`, **plaintext never
stored**), `issued_at`, `issued_by`, `expires_at`, `consumed_at`, `consumed_by`, `revoked_at`,
`revoked_reason`. The Platform Owner issues through a `service_role` function that returns the
plaintext **once**; the tenant Owner redeems through an `authenticated` function that hashes the
input and compares. Replay is closed by `consumed_at`; rotation is revoke-then-issue; compromise
recovery is revoke. The token grants **no database privilege** — it is an argument to a controlled
function whose only effect is a subscription state transition, so it can never become a Supabase
password. Every issue / redeem / fail / revoke writes a `security_events` row.

External research supports the separation but did not decide it — mature practice is a
*dual-domain* split between SaaS administrators and tenant users with break-glass, time-bounded,
fully audited platform access rather than standing cross-tenant rights
([WorkOS](https://workos.com/blog/developers-guide-saas-multi-tenant-architecture),
[Cerbos](https://www.cerbos.dev/features-benefits-and-use-cases/multi-tenant-saas)), and
server-side entitlement enforcement rather than client-trusted flags
([SuperTokens](https://supertokens.com/blog/secure-multi-tenant-auth)). TOTP's own documentation is
explicit that it is built on a **shared secret stored on both server and device**
([LoginRadius](https://www.loginradius.com/blog/engineering/what-is-totp-authentication),
[ManageEngine](https://www.manageengine.com/products/self-service-password/blog/mfa/what-is-time-based-one-time-password-totp-authenticator.html)),
which is precisely the property that disqualifies it here. Trial-abuse practice confirms that
one-trial-per-account enforced at the account record is the standard control
([Stripe](https://stripe.com/resources/more/how-to-prevent-free-trial-abuse-in-saas-and-ai-products),
[AWS Marketplace](https://docs.aws.amazon.com/marketplace/latest/userguide/saas-free-trials.html)).

### G-PLATFORM-ROLE — does ORVION need a Platform Owner role?

**No new tenant role. Yes to an explicit platform surface.** Per C7, a tenant role structurally
cannot express platform authority. `system_administrator` is therefore **not** promoted to Platform
Owner; its ambiguity is resolved in the opposite direction — it is the *tenant technical
administrator* half of canon 28's "or", and platform authority lives on `service_role`.

---

## H. RISKS

| Risk | Mitigation |
|---|---|
| Making the write gate date-aware could deny writes for tenants whose state was not yet advanced | Every existing test creates subscriptions with `ends_at` NULL (verified), so no test regresses; `ends_at is null` is always writable, which is also what lifetime needs |
| A lifecycle job that raises would abort every tenant's transition — the exact WP-03 defect | Per-tenant loop, `continue` on ineligibility, never `raise`; guarded by a test that proves one bad tenant does not stall another |
| Trigger firing order on `booking_items` is already load-bearing (SPEC-155) | This package touches no `booking_items` trigger |
| Constraining `tenants.status` could break a caller | **PROVEN**: all 41 test files use `'active'`; the only other writer is `provision_tenant`'s `'trial'` default, changed in the same migration |
| An activation token leaking through logs or an error message | Plaintext returned exactly once by the issuing function and never stored, logged, or included in any event payload |
| Auto-renewal rolling a period without payment | `auto_renew` defaults **false**; it is a deliberate Platform Owner setting, not a default behaviour |

## I. TESTS REQUIRED

Every denial preceded by a positive control (AGENTS.md §6, no vacuous security tests).

* Provisioning: a new tenant **can** immediately create a customer/lead/booking — the positive
  control that B1 is actually fixed, not merely papered over.
* Trial: `trial_ends_at` = start + 30 days; a second trial attempt is refused; the stamp cannot be
  moved by UPDATE.
* Expiry: a subscription past `ends_at` is denied writes **even before** the job runs; reads still
  succeed (the read/write asymmetry proven, not assumed).
* Lifecycle job: trial→expired, active→grace_period, grace_period→read_only each fire and emit the
  canon event; **one ineligible tenant does not prevent another tenant's transition**.
* Lifetime: `ends_at is null` writes forever; the CHECK refuses `lifetime` with a date.
* Platform authority: an `owner` who provably **holds** `MANAGE_TENANT_SETTINGS` and provably **can
  see** their own subscription row is nonetheless refused an UPDATE to `subscription_status_code` —
  the positive controls make the denial about authority, not visibility.
* A permanent assertion that **no role holds `MANAGE_SUBSCRIPTION`**, so it cannot be granted by a
  future tidy-up.
* Employee report: the employee sees their own totals; a colleague's figures are absent (not merely
  masked); company-wide totals are unreachable; finance's own wider view still works.

## J. DEPENDENCY ORDER

**SPEC-156** (independent) → **SPEC-157** (lifecycle + platform authority) → **SPEC-158** (license
credential; needs 157's platform surface and transition validator) → **SPEC-159** (employee report;
independent of 157/158 but sequenced after, since it is additive and lower-risk).

## K. REQUIRED UPDATES

* `reports/master/MASTER_EXECUTION_PLAN.md` — extend **Batch 6** (never replace) with SPEC-156→159.
* `reports/master/MASTER_GAP_REGISTER.md` — B1/B2 as new findings; C4 (activation code) moves from
  *undecided* to *decided, mechanism recorded*; PLAN-1 unchanged.
* `_ORVION_CANONICAL/manifest.md` — live state, Last Completed, Next capability, open decisions
  (BLOCKED-1/2 resolved; BLOCKED-4/5 opened).
* `_ORVION_CANONICAL/09_saas_plans_and_access.md` — the C4 activation-code section records a decided
  mechanism (owner-authorized canon touch; canon is protected under AGENTS.md §6).
* Guards — no new guard needed; the permanent assertions live in the pgTAP suite.
* Session report — this file, extended with VERIFIED / FIXED / NOT FIXED / BLOCKED as work lands.

---

## STATUS AT THIS POINT

**ALIGNED. Implementation authorized by the alignment itself** — no owner decision is outstanding for
SPEC-156 or SPEC-157. BLOCKED-4/5/6 do not block them.

---

# IMPLEMENTED THIS SESSION — SPEC-156 and SPEC-157, both **EARNED → CLOSED**

## SPEC-156 — `202607053900` — remove the ignored `p_commission_rate` parameter

SPEC-155 made `commission_rate` system-derived, which left `app.create_booking_item` accepting a
parameter it silently discarded. A caller could pass `0.90`, receive no error, and see no effect —
an input that teaches the caller a false rule is worse than one that is rejected.

`drop function` first, deliberately: `create or replace` with a shorter argument list would have left
the nine-parameter version in place as a **second callable overload** that still accepted a
commission rate. Assertion 16 of `41_commission_derivation_test.sql` asserts exactly one signature
survives, which is the assertion that makes assertion 17 ("no `p_commission_rate`") meaningful.

Caller safety was verified before writing, not assumed: the only two callers in the repository pass
three positional arguments and never reach the removed parameter. PostgREST invokes RPCs by *named*
argument, so a caller that never named it is unaffected and one that did will now fail loudly.

## SPEC-157 — `202607054000` — subscription lifecycle, trial, and platform authority

Closes **BLOCKED-1**, **BLOCKED-2** and canon **C5**. Details of the three defects are in §B above.

**What "the Platform Owner controls this" turned out to mean, technically.** The obvious reading of
the owner's requirement was "grant `MANAGE_SUBSCRIPTION` to a platform role". That is impossible, and
the impossibility is structural rather than stylistic: `app.has_permission` resolves the caller
through `public.users` joined on `u.tenant_id = app.current_tenant_id()`, so **every holder of every
role is inside exactly one tenant by construction**. Granting `MANAGE_SUBSCRIPTION` to `owner` or
`ceo` would not have created platform authority — it would have let each tenant elevate its own
subscription, the exact opposite of the requirement. Platform authority therefore lives where
`app.provision_tenant` already put it: SECURITY DEFINER functions granted to `service_role` alone.

`MANAGE_SUBSCRIPTION` accordingly **stays held by no role**, which makes the existing RLS policies on
`subscriptions` deny every tenant user. That was already true before this package — but by accident
of omission, indistinguishable from orphaned debt. Assertion 20 makes it a permanent, deliberate
property that a future "tidy up the orphaned permissions" pass cannot quietly undo.

`system_administrator` was **not** promoted. Canon 28 calls it "Platform-level **or** tenant
technical administrator depending on scope"; the ambiguity resolves to the tenant half, because the
platform half cannot live in a tenant role at all.

## SPEC-158 — `202607054100` — the tenant license activation credential

Closes canon **C4**, open since 2026-07-15, where canon 09 recorded the activation-code idea and
stated it *"requires security review before implementation"*. This is that review's outcome; the
reasoning is §G-LICENSE above, and the mechanism is as designed there.

**A defect of my own that this package's own test caught, and how it was resolved.** The first
version wrote a `license_token_rejected` row to `security_events` and then raised. Assertion 7 failed
with `have: NULL` — because `raise` aborts the transaction and rolls the audit INSERT back with it.
PostgreSQL has no autonomous transaction, so an audit row written in the same transaction as its own
refusal **cannot** survive. The escapes are an out-of-transaction hop (dblink self-connection, pg_net,
an edge function) or abandoning `raise` for a status return; the first needs a stored connection
secret, and the second invites a client to read failure as success.

None of the three was worth taking, so the honest option was chosen: **the INSERT was removed, the
limitation is stated in the function body, and an assertion now pins the real behaviour** — a refused
attempt leaves no audit row — so nobody builds a brute-force alert on data that does not exist.
Recorded as **LIC-1**, classified **BLOCKED BY EXTERNAL DEPENDENCY**. Residual risk is bounded: a
token is 128 bits of CSPRNG output so guessing is infeasible, replay is closed by `consumed_at`
regardless of auditing, and every *successful* redemption is audited because that path commits. The
worst outcome would have been shipping the INSERT anyway — code that looks like auditing and never
runs.

**A fourth vocabulary word was deliberately not registered.** `license_token_rejected` is absent from
the catalog precisely because nothing can emit it. Canon left eleven subscription event types
registered with zero producers for years (§B8); registering a word nothing can ever write is how that
happens.

**Two more defects caught by existing guards, both fixed rather than exempted:**

* `14_tenant_qualified_fk_test.sql` — `consumed_by uuid references public.users (id)` was a
  single-column FK to a tenant-scoped table, i.e. a path by which one tenant's row could point at
  another tenant's user. Replaced with the composite `(tenant_id, consumed_by) → users (tenant_id,
  id)`, which makes the cross-tenant row unrepresentable. This is the exact class SPEC-130 removed
  everywhere else, reintroduced by me and caught within one run.
* `01_rls_coverage_test.sql` — the table had RLS enabled and no policy. That guard is catalog-driven
  with **no exception list**, and the right answer was not to give it one: an explicit
  `platform_only … using (false) with check (false)` policy states the intent where a reader will
  look, and acts as a second lock if a future migration ever grants `authenticated` a privilege here
  by accident. The exception I had briefly added to the smoke test was then **removed again**.

## VERIFIED

| Check | Result |
|---|---|
| New guard `43_license_activation_test.sql` | **19/19** |
| New guard `42_subscription_lifecycle_test.sql` | **28/28** |
| `41_commission_derivation_test.sql` (extended for SPEC-156) | **17/17** |
| `35_subscription_write_gate_test.sql` (rewritten assertion + 3 new controls) | **27/27** |
| Suite | **43 files / 474 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` (**73** tables, **69/591** catalog) |
| Repository guard | CLEAN |
| Database parity | `CLEAN (local proven; primary proven)` |
| repo = local = Primary | **130 migrations**, `538237ee27a3aa6a41da26f6ac146b3f` |
| Primary live re-read | 73 tables · **124** `app` functions (+12) · 117 policies · 2 `pg_cron` jobs · 5 `subscription_period` values · `service_role` **can** execute the platform functions and `authenticated` **cannot** · `authenticated` **can** execute `redeem_license_token` · **0** privileges on `tenant_license_activations` for `anon`/`authenticated` · exactly **1** `create_booking_item` overload · **0** roles hold `MANAGE_SUBSCRIPTION` · 0 tenants, 0 subscriptions |

The decisive assertions are the ones that would have passed against the old, broken system and now
do not:

* a trial past `ends_at` is denied writes **before any job runs** — while a tenant still inside its
  grace window is allowed, proving the deadline is evaluated **per state** rather than by one
  `ends_at` predicate (a single predicate would have denied the grace period its entire purpose)
* reads on that same lapsed tenant still succeed — writes are gated, data is not confiscated
* a lifetime subscription **cannot** be given an end date or a renewal cycle: two CHECK constraints,
  because a comment saying "do not use a far-future date" would not stop the next writer
* the trial stamp cannot be moved by UPDATE — a trial that can be silently restarted is not a trial
* four due tenants transition in the same run that skips two ineligible ones — the WP-03 shape
* a tenant owner who **provably** holds tenant authority and **provably can see** its own
  subscription row still changes nothing when it tries to grant itself ten years

## CROSS-PATH IMPACT SWEEP (AGENTS.md §3 step 5b) — and what it caught

`app.subscription_allows_write` was **tightened**, so every path that consults it was re-examined:

* **42 gate triggers** — intended target. Existing fixtures all use `ends_at is null`, verified, so
  no test regressed by accident rather than by design.
* **`process_lead_sla` and `map_outcomes_to_conversions`** (multi-tenant system paths) — both already
  carry the `continue`-on-ineligibility shape WP-03 forced. They now additionally skip
  date-lapsed tenants, which is the correct behaviour and required no change.
* **The new lifecycle job** — writes `subscriptions` and `events`, both on the gate's exemption list,
  so the job cannot deadlock against the rule it enforces.
* **The recreated catalog trigger on `subscriptions`** — proven live to still reject an invalid
  `subscription_status_code` **and** to now reject an invalid `billing_period_code`. Recreating a
  trigger to add an argument pair is exactly where an existing check gets silently dropped.

**The sweep caught a real defect in my own work.** The first run of `35_subscription_write_gate_test`
failed at `record_event: tenant … is not the caller's tenant`. Cause: WP-00 pins a session-ful
caller's events to that caller's own tenant, and the test invoked `provision_tenant` while holding a
JWT for a *different* tenant. That is WP-00 working correctly — provisioning a new tenant is only
legitimate from the session-less platform path — so the fix was to call the function the way
production calls it (`service_role`, no `auth.uid()`), not to weaken the rule. Recorded here because
it is a real constraint on any future caller of `provision_tenant`.

## NOT FIXED (deliberate, each tracked)

* **Notification before subscription expiry** — the owner requires it; `notifications` has **no
  producer at all**, so building one inside this package would create a second architecture.
  Classified **BLOCKED BY DEPENDENCY (notifications package)**. The lifecycle job already emits the
  canon-26 events a producer will consume, and **no new event code was invented** to fill the gap.
* **`ACCESS_API_FULL` / `ACCESS_API_READ_ONLY` / `VIEW_ADVANCED_DASHBOARDS`** — three permissions
  still held by no role. Unlike `MANAGE_SUBSCRIPTION` (now a deliberate deny-all, tested), these
  three are genuinely unclassified. Recorded, not silently left: they belong to the API-access and
  dashboard capabilities, neither of which exists yet.
* **SPEC-154-B**, WP-03's broad `documents` exemption, the missing `payment_proof` document type →
  all still WP-04.
* **Canon 09 / canon 26 annotations** — canon is protected (AGENTS.md §6) and C4's mechanism is
  decided but not yet built. The canon touch belongs in SPEC-158, where it can record an
  implemented mechanism rather than an intention.

## BLOCKED

* **BLOCKED-4** — does commission follow a booking-item reassignment? No reassignment path exists
  today (`create_booking_item` sets all three ownership fields to the creator), so nothing is
  blocked by it now. Compensation policy.
* **BLOCKED-5** — may the Platform Owner ever deliberately re-grant a trial? Implemented
  conservatively as *never*; lifting it would require a new platform function, which was not written.
* **CANON-26-1** — canon 26 admits `suspended` only from `read_only`, so an active tenant cannot be
  suspended in one step (`active → cancelled` is available). Encoded exactly as canon states rather
  than widened for convenience. A canon question, not an implementation one.
* **PLAN-1** — the three undefined "Limited" plan ceilings, unchanged.
* **LIC-1 (BLOCKED BY EXTERNAL DEPENDENCY)** — a *refused* license redemption is not audited, because
  `raise` rolls back its own audit row and PostgreSQL has no autonomous transaction. Stated in code,
  pinned by an assertion, and fixable only by an out-of-transaction audit hop.

## GOVERNANCE

`manifest.md` (live state, Last Completed, Next capability, open decisions), `reports/README.md`
latest-report pointer, `MASTER_EXECUTION_PLAN.md` Batch 6 (**extended, never replaced**; BLOCKED-1/2/3
struck through with their resolutions, BLOCKED-4/5 and CANON-26-1 added), `MASTER_GAP_REGISTER.md`
(**SUB-1** and **SUB-2** added as resolved High findings), `ai-map.json` regenerated.

The manifest exceeded its 7000-character leanness budget during this update. It was brought back
under budget by **deleting accumulated history** — the "Prior phases" chain the manifest's own rules
forbid, plus duplicated counts — rather than by trimming the new state, which is what the budget is
for.

## ENVIRONMENT

`apply_migration` stamped its own version on both migrations (the documented hazard, first recorded
in WP-00) and both were reconciled to their file versions, `202607053900` and `202607054000`, before
parity was re-proven. `npx supabase` continues to work only from PowerShell, not from the Bash tool
(`spawn UNKNOWN`).

## CURRENT STATE

* **130 migrations**, latest `202607054100`, fingerprint `538237ee27a3aa6a41da26f6ac146b3f` on
  repository, local and Primary.
* **73** tables · **124** `app` functions · **117** policies · 71 permissions · 69/591 catalog ·
  2 pg_cron jobs. Primary holds zero business rows.
* Suite 43 files / 474 assertions / 0 failures. Smoke passes. Both guards CLEAN.
* Git: `main`, tree clean, pushed.

## NEXT STEP

**SPEC-159 — the employee performance & earnings report** (owner directive §7–§10). Two constraints
are already proven and shape it before a line is written: `authenticated` **cannot** SELECT
`cost_amount` or `commission_rate`, so the report must route through `app.item_financials` exactly as
`reporting.booking_item_profit` already does; and commission attributes to `sales_owner_user_id`,
derived from canon 31's "sales commission" wording rather than guessed — noting that today
`create_booking_item` sets all three ownership fields to the creator, so the distinction is real in
the schema and unrealised in behaviour (§B12), with the reassignment question held as BLOCKED-4.
