# ORVION — Final Foundation Hardening, CRM Completeness & Zero-Debt Gate

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-24
Author: Claude Opus 5
Scope: Owner directive of 2026-08-24 (second directive)
Evidence: this session's work only. Local database only — see §F.

---

# J. FOUNDATION FREEZE VERDICT

# FOUNDATION FREEZE — NOT EARNED

Two concrete blockers. The first cannot be closed by engineering.

1. **Primary carries none of this work and cannot be reached.** `supabase-primary` MCP is
   disconnected, `supabase/.temp/project-ref` does not exist, and `SUPABASE_ACCESS_TOKEN` is unset.
   All three access paths were checked, not assumed. Primary is **13 migrations behind**. §25 of the
   directive requires "Primary synchronized", "repo = local = Primary" and "behavioral tests pass
   against Primary" — none is verifiable. Every result below is local-only.
2. **Lifecycle transitions are still bypassable by direct DML.** SPEC-145 closed *financial*
   authority on every path, but `authenticated` retains UPDATE on the status columns of the CRM
   tables, so a direct `update bookings set booking_status_code = 'issued'` still skips the state
   machine, the negative-balance risk check and the event. This is SEC-1/RPC-1, and it cannot be
   closed safely without an owner decision — see §I.

---

# A. What I inspected

Repository boot chain as a fresh agent would follow it (README → AGENTS §4 → manifest → roadmap →
gap register); git and push state; MCP configuration and all three Primary access paths; the live
local database (grants, policies, triggers, functions, indexes, catalogs, reference data); every
finance table's write surface; the `orvion_integration` role's contract; the Google Cloud SDK
environment; and the scope model's behaviour under a synthetic dataset of 110,000 rows.

---

# B. What I discovered

Defects **not** in the previous reports:

| # | Finding | Why it matters |
| --- | --- | --- |
| B1 | **Every finance permission was bypassable with plain SQL.** `authenticated` held INSERT/UPDATE on `exchange_rates`, `exchange_rate_adjustments`, `journal_entries`, `journal_entry_lines`, `chart_of_accounts`, `approval_requests`, `subscription_payment_proofs` — all with nothing but a tenant check | An employee could set the company exchange rate (changing what every multi-currency booking cost), write journal entries, edit the ledger's structure, and **approve their own refund request** |
| B2 | **SPEC-139 withheld *reading* the margin columns but never *writing* them.** Column grants are independent: `cost_amount`, `commission_rate` and `cost_locked_at` remained UPDATE-able | An employee could write a false cost on an item whose cost they cannot see, and could simply clear `cost_locked_at` — which made `EDIT_LOCKED_COST` unreachable in practice |
| B3 | **Finance could not see the bookings it governs.** A finance manager holding `APPROVE_FINANCE` saw **zero** bookings and zero booking items | `app.review_finance_approval` is SECURITY INVOKER — it could not find the item it was approving. The finance-approval workflow was broken for the only role canon puts in charge of it. Introduced by SPEC-137 |
| B4 | **SPEC-144's confidentiality rule was too broad.** It granted finance *any* confidential document | Canon 28 separates `VIEW_FINANCIAL_DOCUMENTS` (Finance: Yes) from `VIEW_TRAVEL_DOCUMENTS` (Finance: *Optional*, not granted). Finance was reading confidential passports |
| B5 | **The plan matrix had no reader.** 66 seeded rows; nothing consulted them | Canon 28 states "Plan denial overrides user role permission". A Starter tenant could use Booking, Documents and Full Finance freely |
| B6 | **The `assigned` scope asked no permission at all** | `VIEW_ASSIGNED_LEADS` and `VIEW_ASSIGNED_TASKS` did nothing, and `trainee` held neither although canon marks both "Limited" |
| B7 | **`users(auth_user_id)` had no index.** `app.current_tenant_id()` resolves on it and every policy on every table calls it; the composite `(tenant_id, auth_user_id)` cannot serve the lookup because the tenant is what the function is discovering | Seq Scan confirmed. Free at 30 users, which is why no test caught it; on Primary `users` holds every employee of every tenant |
| B8 | **SPEC-137 added a unique index that already existed** — identical definition, identical partial predicate | A duplicate unique index is maintained and checked on every write. The CR was right about why the rule matters and wrong about whether it was present |
| B9 | **The manifest asserted parity that no longer held.** Line 32 still read "repository, local stack and Primary agree by ledger fingerprint" | A fresh agent would have believed Primary was current. Also: wrong migration count, a garbled CR list, and `reassign_lead` still listed as outstanding after SPEC-140 delivered it |
| B10 | **Role expiry is a *complete* revocation** (semantic, discovered by testing) | Because the assigned scope is now permission-gated, an employee whose assignment lapsed loses sight of their own records too — safer than partial revocation, and previously unstated |

---

# C. What I changed

| CR | Migration | Substance |
| --- | --- | --- |
| SPEC-145 | `202607052400` | Permission-gated write policies on 5 finance tables; type-dependent review gate on `approval_requests` (canon 28's own sentence, as a policy); `app.guard_booking_item_financials` trigger for the 5 financially-authoritative columns; finance clause added to `bookings`/`booking_items` read scope; `app.is_financial_document_type` separating travel from financial documents |
| SPEC-146 | `202607052500` | `permissions.required_feature_code` + CHECK; `app.plan_allows`, `app.plan_limit`, `app.tenant_capabilities`; **plan gate composed into `app.has_permission`**; `VIEW_ASSIGNED_*` granted to trainee and the assigned clause gated on them; `marketing_campaigns`, `campaign_daily_metrics`, `subscriptions` reads gated |
| SPEC-147 | `202607052600` | Partial index `users(auth_user_id) where is_active`; duplicate index dropped |
| SPEC-148 | — (tests only) | Access-revocation coverage |
| — | — | Manifest repaired (B9); canon 28 extended with §Plan Gating Enforcement and the revocation semantic |

**Where the plan gate sits, and why.** Inside `app.has_permission()` — the single function every RLS
policy and every `app.authorize()` already calls. One change covers the RPC path, direct PostgREST
reads, direct PostgREST writes, future n8n calls and a future UI, without any of them cooperating.
Canon 35 §8 left this open ("decided at implementation, not here"); the decision is now made and
recorded in canon 28.

---

# D. What I deliberately did NOT change

| Item | Why |
| --- | --- |
| `MANAGE_ROLES` / `MANAGE_PERMISSIONS` given no enforcement point | `roles`, `permissions`, `role_permissions` grant `authenticated` **SELECT only**. No tenant user has a writable surface to guard — stronger than a permission check. Minting an RPC would *create* the surface |
| `MANAGE_BRANCHES` not gated on `multi_branch` | Starter excludes the feature but is entitled to one branch (`max_branches = 1`). The numeric ceiling is the correct control; the switch would stop a Starter tenant creating any branch |
| Subscription-*state* gating (`read_only` write restriction) | Canon 35 §8 keeps it distinct from plan gating. Conflating them would decide something canon separates |
| Numeric ceilings not enforced | Readable via `app.plan_limit` / `app.tenant_capabilities`; `usage_counters` is empty and counting is a separate additive mechanism |
| `orvion_integration` `nologin` in migrations | Deliberate and documented: LOGIN was enabled manually on Primary so the password never entered the repo (Integration Catalog §3.3). Correct practice, not drift |
| The LATERAL timeline rewrite | **Reverted.** Written on a 611 ms reading; measured fairly (both shapes warmed, three runs, same session) the two forms are indistinguishable at ~128 ms. The 611 ms and a later 2,167 ms were cold-cache artefacts. A change with no benefit carrying a false rationale is the debt this pass removes |
| Status-column direct-DML guard | Blocked on an owner decision — see §I |

---

# E. Tests added

| File | Assertions | Subject |
| --- | --- | --- |
| `29_financial_write_authority_test.sql` | 15 | Adversarial: employee / senior_employee / finance_manager attacking the finance tables directly |
| `30_plan_gating_test.sql` | 13 | Plan gate attacked on three separate surfaces |
| `31_access_revocation_test.sql` | 10 | Employee leaves, assignment expires, role deactivated |
| `21` / `28` | +3 | Regressions for B3 and B4 |

---

# F. Behavioral verification results

All assertions below ran as **`authenticated`**, not `postgres`.

- An employee cannot set an exchange rate, write a journal entry, edit the chart of accounts, or
  approve their own refund request.
- An employee cannot write a cost on an item they can see.
- A senior employee **can** enter cost and price while unlocked, **cannot** lock, unlock, or mark
  finance-approved; after finance locks it, the same user can no longer edit the cost, and finance
  still can. MFA composes on the direct path.
- Plan denial overrides role permission on the RPC path, the direct read path and the direct write
  path; upgrading the plan restores it with no role or policy change; suspension denies plan-gated
  permissions only; a tenant with no subscription is unrestricted.
- A departed employee resolves to no tenant and no user, sees nothing on any table, holds nothing.
  Expiry and role deactivation reach the same result by different routes.

**Performance, measured (§19).** 5,000 customers / 20,000 leads / 10,000 bookings / 25,000 booking
items / 50,000 events, as an authenticated employee:

| Query | Result |
| --- | --- |
| Lead list (branch+department scoped) | 25 ms |
| Booking list | 18 ms |
| Booking items | 31 ms |
| Owner tenant-wide lead list | 9.6 ms |
| Single-entity event read | index-driven on `events_tenant_entity_idx` |
| `app.customer_timeline` | ~128 ms warm (1.8 ms with RLS bypassed) |

The resolution primitives are **genuinely InitPlan-hoisted** — visible in the plans as `(InitPlan n)`
and `(hashed SubPlan n)` — so they run once per query, not once per row. That was the design intent
and had never been confirmed. Essentially all of the timeline's cost is RLS resolution paid once per
relation across twelve subject branches; that is inherent to the model, not a defect in any policy.
**Stated, not fixed:** an unfiltered `select * from events` still pays the per-row subject dispatch.
The alternative would denormalise scope onto every event, which SPEC-143 deliberately avoided.

---

# G. CRM completeness status

| Area | Status |
| --- | --- |
| Read scope (tenant / branch / department / assigned) | 26 `scope_isolation` policies; proven behaviourally |
| Write authority — identity & organization | Enforced (SPEC-138) |
| Write authority — finance | Enforced on every path (SPEC-145) |
| Write authority — CRM lifecycle | **NOT enforced on the direct path** — §I |
| Plan gating | Enforced in `has_permission`; 29 permissions plan-mapped |
| Permissions | **65 of 70** enforced at a real check point; 2 have no writable surface; 3 gate surfaces that do not exist yet |
| Catalogs / reference data | 68 families, 583 values, no empty or single-value family; 82 countries, 82 nationalities, 20 languages, 18 currencies, 66 entitlements |
| Duplicate prevention | 12 unique indexes, concurrency-safe |
| Audit / events | Scoped to subject visibility; append-only; `seq` total order |
| Customer 360 / Lead 360 | `app.customer_timeline` / `app.lead_timeline`, measured |
| Employee / Branch 360 | Branch identity preserved on every row; financial privacy enforced; department continuity proven |
| Column-by-column audit of all 72 tables | **Not completed** — §I |

---

# H. Integration readiness

**n8n.** The contract is what ADR-0023 describes and was verified, not assumed: `orvion_integration`
has EXECUTE on exactly the four workflow RPCs, `USAGE` on `app` and `public`, and **zero table
grants** — it cannot read or write a table directly. Idempotency is enforced by the SPEC-142 unique
indexes on `attribution_clicks` (gclid/gbraid/wbraid), `marketing_campaigns` external id and
`conversations` external id, which is what makes at-least-once delivery safe.

**Google Ads / Google Cloud.** SDK 580.0.0; project `orvion-data-manager`;
`datamanager.googleapis.com` **ENABLED**; an authenticated account is present. Matches the
repository's documented assumptions — no stale assumption found. No production workflow created, no
conversion data sent.

---

# I. Remaining genuine business decisions

Only items that cannot be derived from evidence.

1. **The write-path model for CRM lifecycle tables (SEC-1/RPC-1).** `authenticated` retains UPDATE on
   status columns, so direct DML skips the state machine and its events. Three options, and the
   choice is commercial, not technical: (a) revoke `authenticated` DML and route every write through
   an RPC — 35 tables still have none; (b) materialise canon 26's transitions into a table and
   validate by trigger — removes duplication but touches every `advance_*` RPC; (c) accept the
   current posture and rely on the client. **Evidence cannot decide this.**
2. **The three "Limited" ceilings canon leaves unquantified** — Basic Reporting (Starter),
   Integrations and Offline Conversion (Professional). Seeded enabled and uncapped rather than
   guessed.
3. **Whether `MANAGE_SUBSCRIPTION` stays platform-only.** No role holds it, so `subscriptions` is
   service-role-writable only. Canon 28 gives Owner/CEO "Limited".
4. **Whether branch managers should see branch margins.** Canon 28 marks `VIEW_FINANCIAL_DOCUMENTS`
   *Optional* for that role; not granted.
5. **`leads.owner_user_id` vs `assigned_user_id`** — always identical; canon 31 lists both without
   distinguishing them. Belongs to a pass covering all eight ownership-triple tables at once.

---

## Verification state

| Metric | Value |
| --- | --- |
| Local migrations | **115**, replay clean from empty |
| Ledger fingerprint (repo = local) | `de6dc48ada6ffc9f56ece2e5074df24f` |
| Test files / assertions | **31 / 276**, `Result: PASS` |
| Assertions running as `authenticated` | 101 across 8 files |
| Smoke (`verify_database.sql`) | `ALL CHECKS PASSED` |
| Repository consistency guard | `CLEAN` |
| Working tree / push state | clean, 0 unpushed |
| **Primary parity** | **UNVERIFIED — 13 migrations behind, unreachable** |

---

End of report.
