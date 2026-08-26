# Change Request — SPEC-152 (WP-03: Subscription State Enforcement)

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

**EARNED → CLOSED (2026-08-26, migration `202607053100`).** All twelve acceptance criteria satisfied
individually and proven as a real `authenticated` user; suite 35 files / 331 assertions / 0 failures;
smoke `ALL CHECKS PASSED`; repo = local = Primary = `b2f4482428307d1c87a3612abe5a517c` at 120.
Evidence: `reports/history/wp-03-subscription-state-enforcement-2026-08-26.md`.

---

## Objective

Make subscription state actually govern write access at the database layer, with the semantics the
owner ratified:

| State | Reads | Writes |
|---|---|---|
| `trial` | allow | allow |
| `active` | allow | allow |
| `grace_period` | allow | allow |
| `read_only` | **allow** | **deny** |
| `suspended` | **allow** | **deny** |
| `expired` | **allow** | **deny** |
| `cancelled` | **allow** | **deny** |

Reads are retained deliberately: a tenant whose subscription lapsed must still be able to inspect and
export its own data.

---

## Business Reason

This is **not** missing behaviour. It is **live, incorrect** behaviour, which is why it outranks
WP-01 (four absent creation events) in the queue.

`app.plan_allows` currently gates on
`s.subscription_status_code in ('trial','active','grace_period','read_only')`. Measured against the
table above, it is **inverted at both ends**:

* `read_only` is in the allow-list, so a read-only tenant can **write**;
* `suspended` / `expired` / `cancelled` are excluded from a function that gates *permissions*
  generally, so those tenants are denied **reads** — the opposite of the export guarantee.

---

## Canon Source

* **`26_state_machines.md` — Subscription State Machine.** The seven states and their transitions.
  Note the transitions are worded as *platform-owner* actions ("Platform owner suspends tenant",
  "Manual reactivation by platform owner"), not tenant actions.
* **`28_permissions_matrix.md` — Subscription Permissions.** Carries a **Platform Owner** column for a
  role that does not exist in `public.roles`. `MANAGE_SUBSCRIPTION` = Owner/CEO "Limited";
  `REVIEW_SUBSCRIPTION_PAYMENT` = Platform Owner only; note: *"Tenant users may upload proof but
  cannot approve their own subscription renewal."*
* **`35_tenant_isolation_and_data_access_principles.md` §8 — decisive for the mechanism.** It names
  `subscriptions.subscription_status_code` as *the authority for access gating*, flags that
  `tenants.status` is a competing second source, and explicitly permits *"a separate RLS predicate
  routed through the same resolution layer — decided at implementation, not here."*

**Consequence: the mechanism needs no business decision.** Canon delegates it to implementation.

---

## Evidence gathered during alignment (all live reads, 2026-08-26)

**A. `has_permission` alone cannot carry this gate — measured, not assumed.**

```
policies_calling_has_permission       : 57
policies_NOT_calling_has_permission   : 32   <-- across 32 distinct tables
total_write_policies                  : 89
```

The 32 ungated tables include `customers`, `suppliers`, `passengers`, `quotation_items`,
`lead_assignments`, `lead_interactions`, `conversation_messages`, `customer_notes`,
`offline_conversions`, `financial_accounts`, `approval_requests`, `document_versions`,
`document_links`. A suspended tenant could therefore still perform most CRM work. This is the
concrete form of the owner's warning that `app.has_permission()` is not sufficient.

**B. `tenants.status` is a dead gate.** It is `not null` on every tenant but is referenced by exactly
one function (`app.provision_tenant`, which sets it) and enforced nowhere. Canon 35 §8's "two
sources" conflict therefore resolves without escalation: subscription state is the authority, and
`tenants.status` is descriptive only. Recorded so a later session does not "fix" it into a second gate.

**C. A provisioned tenant has NO subscription row at all.** `app.provision_tenant` does not insert
one (`provision_creates_subscription = false`), and `public.subscriptions` holds 0 rows. Combined
with `plan_allows`'s `coalesce(..., true)`, a brand-new tenant currently **fails open** to full
access. Canon 26 makes `trial` the initial state and lists `subscription_created` as a required
event, so the absent row is a genuine gap — see BLOCKED-1.

**D. Surface to gate: 57 tenant-scoped tables** of 72.

**E. Integration boundary is intact.** `orvion_integration` holds **0 table grants** and reaches the
database only through the four SECURITY DEFINER RPCs.

**F. Two of the five "orphan" permissions are canon-correct, not defects.** Correcting my own earlier
over-broad claim:

| Permission | Canon 28 | Live | Verdict |
|---|---|---|---|
| `REVIEW_SUBSCRIPTION_PAYMENT` | Platform Owner **only** | no role | **CORRECT** — Platform Owner is not a tenant role |
| `VIEW_SUBSCRIPTION_STATUS` | Owner + CEO | `ceo, owner` | **CORRECT** |
| `MANAGE_SUBSCRIPTION` | Owner/CEO "Limited" | no role | **GAP** — but "Limited" is undefined → BLOCKED-2 |
| `ACCESS_API_FULL` / `ACCESS_API_READ_ONLY` | plan-scoped table only; no role column | no role | **UNRESOLVED** → WP-08 |
| `VIEW_ADVANCED_DASHBOARDS` | not in any canon role table | no role | **UNRESOLVED** → WP-08 |

---

## Mechanism (selected, with the rejected alternatives)

**Selected: one `BEFORE INSERT OR UPDATE OR DELETE` trigger function attached per tenant-scoped
table**, following the established precedent of `app.enforce_catalog_codes`,
`app.enforce_status_transition`, `app.enforce_archive_authority` and `app.forbid_mutation` — one
function, many attachments.

Why it fits:

* It fires on **every** write path — RPC, direct PostgREST DML, and any future client — independent of
  which policy admitted the write. That is the only property that answers *"what happens if the
  intended RPC is not used?"*
* Triggers do not fire on `SELECT`, so **reads remain available for free**. The read/write asymmetry
  the owner requires falls out of the mechanism rather than being maintained by hand.
* It introduces no new architecture.

Rejected:

* **Inside `app.has_permission`** — leaves the 32 tables in evidence A completely ungated. This is the
  option the owner explicitly warned against, and A is the measurement proving it.
* **A predicate added to all 89 write policies** — same security outcome in principle, but 89 edit
  sites that must each be remembered by every future migration. Drift-prone; the trigger is one rule.
* **Returning `NULL` from `app.current_tenant_id()` for restricted states** — elegant, and canon 35's
  "resolution layer" hints at it, but it would kill reads too, breaking the export guarantee.
* **Revoking grants** — grants are static and role-wide; subscription state is per-tenant and dynamic.

### Exemptions (derived from canon + the owner's stated purpose, not invented)

A blanket write-deny would lock a lapsed tenant out permanently. These must stay writable:

| Table(s) | Why |
|---|---|
| `subscription_payment_proofs` | Canon 28: *"Tenant users may upload proof."* Without this the tenant can never trigger reactivation. |
| `subscriptions` | The reactivation path itself; already gated by `MANAGE_SUBSCRIPTION`. |
| `otp_challenges`, `totp_enrollments`, `trusted_devices` | Login writes rows. Denying them denies the read/export guarantee, which requires being able to log in. |
| `security_events` | Auth and security history must record even for a suspended tenant. |
| `events` | Written only by `app.record_event`; the audit spine must record the reactivation itself. |
| `notification_deliveries`, `usage_counters` | System/platform-written, not tenant work. |

Every exemption is a deliberate hole and must be asserted in the test, both that it is open and that
it is *narrow*.

---

## Change Boundary

Allowed: one new migration `2026MMDDHHMM_subscription_state_enforcement.sql`; `app.plan_allows`
(correcting the inverted state list); one new `app.*` trigger function plus its per-table attachments;
one new test file; `manifest.md`; `MASTER_GAP_REGISTER.md`; this CR.

Forbidden: any change to the SEC-1 write-path model; any grant revocation; any policy rewrite; any
change to the four integration RPCs' signatures; rewriting historical migrations.

---

## Non-Goals

* Numeric plan ceilings / `usage_counters` counting (PLAN-1, still open).
* The three canon "Limited" features with no defined ceiling.
* `system_administrator` semantics.
* Creating subscription rows during provisioning (BLOCKED-1).
* Billing, payment capture, or dunning.
* WP-01 creation events — except that `subscription_created` is confirmed to belong to
  `provision_tenant`, which WP-02 must record.

---

## Binary Acceptance Criteria

Each must pass individually, proven as a real `authenticated` user, not as `postgres`.

1. For each of `trial`, `active`, `grace_period`: an ordinary CRM write (e.g. `app.create_customer`)
   **succeeds**.
2. For each of `read_only`, `suspended`, `expired`, `cancelled`: the same write **fails**.
3. For each of `read_only`, `suspended`, `expired`, `cancelled`: a `SELECT` over `customers`,
   `bookings`, `invoices` and `events` **still returns rows** — the export guarantee.
4. **Direct DML bypass:** for each restricted state, a direct `INSERT`/`UPDATE` (no RPC) against a
   table from evidence A's ungated list — `customers`, `suppliers`, `lead_interactions` — **fails**.
5. Every exemption in the table above is **writable** in `suspended` state.
6. Exemptions are narrow: a non-exempt table adjacent to an exempt one still **denies**.
7. `app.plan_allows` no longer treats `read_only` as write-capable, and no longer denies reads for
   `suspended`/`expired`/`cancelled`.
8. **Missing subscription denies writes and allows reads** (fail closed for writes). Justification is
   derived, not invented: an absent subscription is at minimum as restricted as `read_only`, and the
   owner's rule for restricted states is read-yes/write-no.
9. `app.provision_tenant` still succeeds end to end despite criterion 8.
10. The four integration RPCs still execute for a tenant in an allowed state; behaviour for a
    restricted tenant is asserted explicitly, whichever way it is decided in implementation.
11. Full suite green (currently 34 files / 307 assertions) plus the new file; smoke `ALL CHECKS PASSED`.
12. Repository guard CLEAN and database parity CLEAN at commit; repo = local = Primary by fingerprint
    after deployment.

---

## Stop Conditions

Halt and re-align rather than improvise if: a pre-existing test fails; the guard is not CLEAN; the
trigger must touch a table outside the 57 tenant-scoped set; an exemption cannot be justified from
canon; enforcing the gate would make `provision_tenant` or the login path unreachable; the integration
RPCs' contract would change; or Primary parity becomes unexplained.

---

## BLOCKED — genuine business decisions (do not block the rest of this CR)

**BLOCKED-1 — what subscription does a newly provisioned tenant get?**
Canon says the initial state is `trial` and requires a `subscription_created` event, but names neither
the plan tier a trial receives nor the trial length. Both are commercial policy. *Minimum decision:*
(a) default plan for a trial tenant — `starter` / `professional` / `enterprise`; (b) trial duration.
WP-03 proceeds without it: criterion 8 makes "no subscription" safe (writes denied, reads allowed), so
the absent row cannot fail open while the decision is pending.

**BLOCKED-2 — what does `MANAGE_SUBSCRIPTION` = "Limited" mean for Owner/CEO?**
Canon 28 grants it "Limited" to Owner and CEO with no definition, while `REVIEW_SUBSCRIPTION_PAYMENT`
is Platform-Owner-only. Today no role holds `MANAGE_SUBSCRIPTION`, so no tenant user can change
subscription state at all. *Minimum decision:* which subscription transitions a tenant Owner/CEO may
perform themselves (plausibly: upload proof and request renewal, but never approve their own).
Same family as PLAN-1's undefined "Limited" ceilings.

---

## Execution Log

* **2026-08-26 — ALIGNED.** Canon read (26 / 28 / 35 §8); mechanism selected against four
  alternatives with the deciding measurement (32 of 89 write policies never call `has_permission`);
  exemption set derived from canon; two BLOCKED business decisions isolated so neither stops
  implementation; two previously-reported "orphan permission" defects corrected to canon-correct.
  No code written.
