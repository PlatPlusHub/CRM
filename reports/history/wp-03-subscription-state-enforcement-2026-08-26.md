# ORVION — WP-03 / SPEC-152: Subscription State Enforcement

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-26
Author: Claude Opus 5
Scope: Implementing SPEC-152 (aligned earlier the same day) — making subscription state govern
business writes at the write layer. Includes the fixture and test corrections the change forced.

Predecessor: `environment-gate-earned-2026-08-26.md`.

---

## STATUS — **EARNED → CLOSED**

All twelve acceptance criteria in `changes/SPEC-152-subscription-state-enforcement.md` satisfied
individually, proven as a real `authenticated` user.

## DISCOVERED

**D1 — The exemption list was incomplete, and only the test found it.**
`subscription_payment_proofs.document_id` is NOT NULL with a tenant-qualified FK, so uploading a
payment proof necessarily creates a `documents` row first. `documents` was gated, so a suspended
tenant could not upload proof — **the one path out of a suspended subscription was silently broken.**
Reading the schema had not revealed it; running the test did. `documents`, `document_versions` and
`document_links` were added to the exemptions.

**D2 — My own test passed VACUOUSLY, exactly the failure mode this repository has been bitten by.**
The proof-upload assertion ran as the `employee` role and used
`insert ... select ... from public.subscriptions`. `employee` does not hold `VIEW_SUBSCRIPTION_STATUS`,
so the SELECT returned **zero rows**, the INSERT inserted nothing, and `lives_ok` reported success.
Fixed by running the exemption block as `postgres` (the subject is the trigger, not RLS) and adding a
follow-up assertion that the row **actually exists**. A "did not throw" assertion over an
`INSERT ... SELECT` is not evidence of a write.

**D3 — My migration introduced a real defect, caught by an existing guard.**
`10_grant_model_test.sql` failed with *"no app-schema function grants EXECUTE to PUBLIC"*.
PostgreSQL grants EXECUTE to PUBLIC by default, and I had added `grant ... to authenticated` without
the matching `revoke ... from public`. Both new functions now carry the revoke. The guard did its job.

**D4 — There is no `payment_proof` document type.** Canon 28 requires tenants to upload payment
proof, but the `document_type` catalog has no code for it (`contract, hotel_voucher, invoice,
medical_certificate, national_id, other, passport, photo, quotation, receipt, ticket, visa`). The test
uses `other`. Vocabulary gap — recorded for WP-02, not silently invented here.

**D5 — 25 test fixtures modelled a state production cannot reach**: a tenant doing business with no
subscription at all. Corrected rather than worked around (precedent: SPEC-151 corrected fixtures
creating a lead with an owner and no assignee).

**D6 — `30_plan_gating_test.sql` encoded the defect as if it were the rule.** Its assertion
*"a SUSPENDED subscription denies plan-gated permissions even on Enterprise"* asserted the inverted
behaviour — suspension denying **reads**. Rewritten to the owner's rule, with the reasoning recorded
in the file so it is not "corrected" back later.

## VERIFIED

| Check | Result |
|---|---|
| Suite | **35 files / 331 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED (72 tables, …)` |
| Repository guard | CLEAN |
| Database parity | `CLEAN (local proven; primary proven)` |
| Repo = Local = Primary | **120 migrations**, `b2f4482428307d1c87a3612abe5a517c` |
| Objects, local vs Primary | 42 gate triggers · 106 `app` functions · 116 policies · 72 tables — identical on both |
| Primary live behaviour | `app.subscription_allows_write('00000000-…')` → **false** (unknown tenant denied) |

Acceptance criteria, each proven in `supabase/tests/35_subscription_write_gate_test.sql` (24
assertions): trial/active/grace_period write **succeeds** (1–3); read_only/suspended/expired/cancelled
write **denied** (4–7); reads survive every restricted state (8–11); **direct DML** into `customers`
and `suppliers`, and direct UPDATE, all **denied** (12–14) — these tables' policies never call
`has_permission`, so a gate placed there would have missed them; exemptions open (15–19); missing
subscription denies writes but allows reads (20–21); coverage in both directions (22–23);
`provision_tenant` still succeeds (24).

## FIXED

* `app.plan_allows` returns to its single job — does the **plan** include this feature. Subscription
  state removed from it entirely.
* `app.subscription_allows_write(uuid)` — the authority. SECURITY DEFINER, because a restricted
  tenant's user may not hold `VIEW_SUBSCRIPTION_STATUS` yet the gate must still read the state.
  Returns **false** when no subscription row exists (fail closed for writes).
* `app.enforce_subscription_write_gate()` — BEFORE INSERT/UPDATE/DELETE, attached to **42** tables,
  generated over the tenant-scoped set so none can be forgotten. Derives the tenant from the **row**,
  not the session, so it behaves identically on RPC, direct PostgREST DML and session-less system paths.
* Both new functions: `revoke execute ... from public` (D3).
* 24 test files corrected (D5), `30_plan_gating_test.sql` re-pointed at the real rule (D6).

## NOT FIXED (deliberate)

* **`payment_proof` document type** (D4) — inventing a catalog value is fabricating canon. WP-02.
* **`usage_counters` still empty**; numeric plan ceilings uncounted (PLAN-1, pre-existing).
* **`plan_allows` still fails open** (`coalesce(..., true)`) when a tenant has no subscription. Now
  read-only in effect, because writes are refused by the gate regardless. Narrowing it is PLAN-1 work.
* **SEC-1** untouched, as the CR's boundary required.

## BLOCKED (business decisions — neither blocked this work)

* **BLOCKED-1 — trial provisioning.** Canon 26 makes `trial` the initial state and requires a
  `subscription_created` event, but names no plan tier or trial length; `subscription_plan_id` is NOT
  NULL, so a trial subscription cannot be created without choosing one. *Minimum decision:* default
  plan + trial duration. Deliberately routed around: the exemption set keeps `users`,
  `user_role_assignments`, `branches` and `departments` writable, so `provision_tenant` still works
  (criterion 9, asserted permanently in test 24).
* **BLOCKED-2 — `MANAGE_SUBSCRIPTION` = "Limited"** for Owner/CEO is undefined in canon 28; no role
  holds it, so no tenant user can change subscription state. *Minimum decision:* which transitions a
  tenant Owner/CEO may perform themselves.

## NEW DEBT INTRODUCED

**MEDIUM, NON-BLOCKING — the exemption set is broader than the reactivation path.** `documents` /
`document_versions` / `document_links` are exempt so proof upload works (D1), which also lets a
suspended tenant create unrelated documents. Acceptable today because document **storage** does not
exist yet (WP-04), so the surface is metadata only. **WP-04 must revisit** whether a narrower
proof-upload path is warranted; recorded here rather than left implicit.

## CURRENT STATE

* **120 migrations**, latest `202607053100`, fingerprint `b2f4482428307d1c87a3612abe5a517c` on
  repository, local and Primary.
* 72 tables · 106 `app` functions · 116 policies · 71 permissions · 42 subscription-gate triggers.
  Primary holds zero business rows.
* Suite 35 files / 331 assertions / 0 failures. Smoke passes. Both guards CLEAN.
* Git: `main`, working tree clean, pushed.

## ENVIRONMENT NOTE

`npx supabase` fails from the Bash (git-bash) tool on this machine with `Error: spawn UNKNOWN`, but
works from PowerShell. Not a Supabase fault; use PowerShell for `npx supabase` commands here.

## NEXT STEP

**Re-run discovery before choosing the next package, per the standing rule that each earned package
gets a targeted "what did this change introduce?" pass.** Specific questions this change raises:

1. The gate derives tenant from the row. What happens on a write whose `tenant_id` is being *changed*
   (a cross-tenant UPDATE)? The gate checks NEW; the tenant-qualified FKs should already prevent it,
   but it is untested.
2. `catalog_values` is gated, and it holds both global (`tenant_id is null`) and tenant rows — global
   rows pass the gate by the null-tenant branch. Confirm that is intended and not a hole.
3. Does any SECURITY DEFINER system path write a gated table for a restricted tenant and now fail
   where it previously succeeded? `process_lead_sla` is the candidate.

Then **WP-01 (creation events)** — four registered `*_created` types with executable producers that
never fire: `customer_created`, `lead_created`, `passenger_created`, `trusted_device_created`. WP-02
should absorb D4 (`payment_proof` document type) and the `subscription_created` producer, which this
work confirmed belongs to `provision_tenant`.
