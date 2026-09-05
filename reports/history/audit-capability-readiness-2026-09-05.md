# ORVION — Capability, Future-Readiness & Engineering Governance Audit

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-05
Author: Claude Opus 5
Status: **COMPLETE — READ-ONLY forensic audit. No file created, edited, committed or pushed during the audit itself; no database mutated (all reads). This document is the audit's export, authorized separately by the owner after the fact.**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED:** Phase 8, Active CR `None.`, **194 migrations** (repository = local = Primary), consistency **CLEAN 1–19**, parity **CLEAN exit 0** with all three Primary values read *from* Primary, working tree clean, `main` 0 ahead / 0 behind `origin/main` at `1df2f06`.
- **PROVEN (this session, by direct catalog/repository measurement):** the lead-SLA capability exists and is scheduled on both local and Primary; the authorization residue is 3 intentional self-scoped tables, not 40; **SUP-4d, CUST-4 and CUST-5 are all still open at HEAD**, with mechanisms reproduced; Repository Consistency does not trigger on `supabase/migrations/**`, `supabase/tests/**` or `ai-map.json`; `usage_counters` has no writer and `app.plan_limit` has no in-database consumer; only two functions in the entire database write a notification delivery obligation, and `process_lead_sla` is not one of them.
- **UNPROVEN:** pgTAP Pass A/B and the six HTTP suites were **not run** — this was a read-only audit and running them mutates. Local was **not reset** this session; its three hashes match the repository and Primary, which is strong but not reset-fresh evidence (PAR-1b). No claim in this report rests on HTTP evidence.
- **CHANGED:** nothing during the audit. This file is the only repository change, added afterwards on explicit owner instruction to export the report.
- **REMAINING:** the `reports/README.md` **Latest session report** pointer row is **NOT** updated — see §21 and the export note at the end of this document.
- **DO NOT TOUCH:** do not treat any A-nn identifier in §16 as a Gap Register ID — they are audit-local by design and were never written to the register. Do not reopen GOV-18, CUST-3, VOID-1 or the RET-1 mechanism; none was contradicted by this audit. Do not read §05's SEC-1 observation as authority to close SEC-1 — that is an owner-tier decision. Do not wire `impact.ps1` into CI (standing instruction from the 2026-09-05 awareness session).
- **NEXT:** owner decisions D1–D7 in §20, then package P1 or P2 in §19. Nothing in this audit blocks Phase 8.

---

## 1. Executive Summary

ORVION is a substantially built, unusually well-guarded multi-tenant backend whose weakest points are not in its core model but at three edges: **delivery** (nothing sends an email), **commerce** (nothing meters or bills), and **supplier-side symmetry** (the customer credit path is a generation ahead of the supplier one).

The core is stronger than the request assumed. All 77 public tables have row-level security enabled with at least one policy; `anon` holds zero table grants; the authorization model implements *deny > user grant > role grant > plan gate* identically in the enforcement function and in the explainability function; and of the 56 tables `authenticated` can write directly over PostgREST, exactly three have no capability enforcement of any kind — and all three are self-scoped personal auth tables (`otp_challenges`, `totp_enrollments`, `trusted_devices`) where `auth_user_id = auth.uid()` is the correct rule.

The lead SLA capability the owner described **already exists and is already running**: `app.process_lead_sla` is scheduled in `pg_cron` every minute on *both* local and Primary, warns at 15 minutes, reassigns at 30, picks the next handler by least-recently-assigned among users who actually hold `CLOSE_LEAD`, records the reassignment in an append-only assignment history, emits a `lead_reassigned` event and notifies the new assignee and the responsible managers. What it does not do is send an **email**, respect **business hours**, or let a tenant **configure the windows**.

All three registered findings under audit — **SUP-4d**, **CUST-4**, **CUST-5** — are **confirmed still open at HEAD**, by direct catalog measurement, with the exact mechanisms reproduced below. None of them blocks Phase 8.

The CI concern is real: a commit touching only `supabase/migrations/**`, `supabase/tests/**` or `ai-map.json` reaches `main` **without** the Repository Consistency workflow running, while five of that guard's checks read exactly those paths.

**Nothing discovered in this audit blocks the completion of Phase 8.** Phase 8's sole remaining deliverable is the n8n workflow; the n8n instance was queried live during this audit and holds **zero workflows**, which is the same blocker the roadmap already records.

---

## 2. Verified Repository Baseline

Every value below was read during the audit, not inherited. The three orientation commits supplied in the brief were confirmed to exist in this history.

| Fact | Value |
|---|---|
| Branch | `main` |
| HEAD | `1df2f067e0b22d47f7454299ee59f27fe664b426` |
| origin/main | identical — 0 ahead / 0 behind after `git fetch` |
| Working tree | clean (0 lines from `git status --porcelain`) |
| Migrations | 194 files · latest `202607060500_retention_becomes_a_policy_per_document_type.sql` |
| Ledger fingerprint | `6802ac41eaf6f4f17f0bf4cde7b3a720` — repository = local = Primary |
| Function surface | `8af5dd7786b940fe4208a1c00d28a7e9` · 273 functions, both sides |
| Structural surface | `bf9883b7cad716e085620058135b3b82` · 3,521 objects, both sides |
| Repository guard | CLEAN, checks 1–19 |
| Parity guard | CLEAN, exit 0 — Primary values read *from* Primary via `supabase-primary` MCP |
| Primary project | `vrvtsxexkiiiivlkdxzp` — matches `MASTER_INTEGRATION_CATALOG.md §0` |
| Schema | 77 public tables · 1 app table · 8 reporting views · 75 client RPCs |
| Test suite | 97 pgTAP files · 6 HTTP suites (not executed during the audit) |
| Workflows | `migration-ci` · `repository-consistency` · `claude` · `claude-code-review` |
| Supplied commits | `c01cbf5` ✓ · `38380ad` ✓ · `b2011e2` ✓ (all reachable) |
| Phase / Batch | Phase 8 IN PROGRESS · Batch 6 NOT STARTED · Active CR `None.` |

**Evidence-class caveat, stated rather than buried.** Findings marked `LOCAL RUNTIME` were read from the local database, which was *not* reset during this read-only session. Its ledger, function-surface and structural-surface hashes all match the values derived from `supabase/migrations/**` and read from Primary, which is strong evidence that local equals the repository — but a hand-applied DDL change that left no migration row would not be visible to that comparison (PAR-1b). No pgTAP pass and no HTTP suite was run: this audit did not need to mutate anything, and running the suites would have. Anything marked `PRIMARY` was read live from Primary during the audit.

---

## 3. Capability Scorecard

| Capability | Existence | Correctness | Security | Automation | Observability | Future-ready | Commercial | Verdict |
|---|---|---|---|---|---|---|---|---|
| Lead SLA / reassignment | Built | Sound | Enforced | Scheduled | Partial | Constrained | n/a | **YELLOW** |
| Feature authorization | Built | Sound | Two doors | n/a | Explainable | Extendable | Ready | **GREEN** |
| Customer credit | Built | Sound | Enforced | Trigger-driven | Event ledger | Good | Ready | **GREEN** |
| Supplier credit | Built | 3 defects | Fragile branch | Partial | Event ledger | Needs parity | Ready | **YELLOW** |
| Email notification | Obligation only | Honest | n/a | None | Ledger row | Good shape | Blocking | **RED** |
| SaaS commercialization | Partial | Sound where built | Strong | Lifecycle job | Weak | Good | Not sellable yet | **YELLOW** |
| CRM completeness | Broad | Coherent | Enforced | Partial | Strong | Good | Good | **GREEN** |
| Self-healing governance | Blocks present | Attacked | n/a | Manual | Strong | Excellent | n/a | **YELLOW** |
| CI coverage | Two workflows | Path gap | n/a | Automatic | Visible | Fixable | n/a | **YELLOW** |

**GREEN** the capability exists, is enforced and behaves coherently under measurement. **YELLOW** it exists and works, with specific bounded gaps named below. **RED** the capability is declared but the behaviour does not exist end to end.

---

## 4. Lead SLA / Reassignment Audit

The requested behaviour is built, scheduled and tested. The gaps are in configurability, calendar awareness, concurrency hardening and the delivery channel — not in the mechanism.

**Evidence** — `LOCAL RUNTIME` · `PRIMARY` · `REPOSITORY`

`app.process_lead_sla(p_warn_after interval default '00:15:00', p_reassign_after interval default '00:30:00')` — SECURITY DEFINER, `search_path=''`, read from `pg_get_functiondef`. Scheduled as `cron.job` id 1, `* * * * *`, `select app.process_lead_sla()`, active — confirmed **identically on Primary** (jobname `lead-sla-processor`). Tests: `63_sla_escalation_test` (11 assertions), `65_eligible_lead_handler_test`, `66_scheduled_job_isolation_test`, `77_lead_routing_integrity_test`.

### Answers to the fifteen questions asked

| # | Question | Answer, with the mechanism |
|---|---|---|
| 1 | What is implemented? | Warning at 15 min, reassignment at 30 min, candidate selection, assignment-history rewrite, `lead_reassigned` event, in-system notification to the new assignee, escalation notifications to responsible managers, durable deferral record when no handler exists. |
| 2 | What is only documented? | Business hours and holidays. `public.branch_business_hours` and `public.holidays` exist as tables and are named in canon 24 as "supports SLA calculation windows / exceptions" — but **no function, view or policy reads either table**. The only reference anywhere in the catalog is a write-permission mapping inside `app.guard_write_capability`. |
| 3 | Is the 15-minute behaviour executable? | Yes, today, unattended. It is the function's default and the cron command passes no arguments, so every tenant gets 15/30. |
| 4 | What starts the clock? | `lead_assignments.assigned_at` of the current assignment — *not* lead creation. Reassignment therefore restarts the clock, which is the correct behaviour and is stricter than the phrasing in the business request. |
| 5 | What stops or resets it? | A **qualifying interaction**. `app.record_lead_interaction` treats `phone_call`, `whatsapp_message`, `chat_opened`, `customer_reply` as qualifying, sets `last_contact_at` and moves `lead_status_code` `assigned → contacted`. The SLA loop only scans leads in status `assigned`, so the lead simply leaves the working set. |
| 6 | Response at minute 14? | No warning has fired yet, the status moves to `contacted`, and neither the warning nor the reassignment can ever fire for that assignment. Correct. |
| 7 | Two workers evaluating the same lead? | Not prevented by design, but **contained by a constraint**: `lead_assignments_one_current_idx` is a UNIQUE partial index on `(lead_id) WHERE is_current`. A concurrent second reassignment raises a unique violation, is caught by the per-lead exception handler, and is recorded to `scheduled_job_findings` as `item_failed`. So the data stays correct; the second run leaves a recorded failure. |
| 8 | Can duplicate reassignment occur? | No duplicate *current* assignment can exist (index above). A rapid double-reassignment across two passes is prevented by the clock restarting at the new `assigned_at`. |
| 9 | Is the next employee deterministic? | Yes: `order by max(assigned_at) asc nulls first, user_id asc limit 1` — least-recently-assigned, ties broken by id. |
| 10 | Is round-robin implemented? | Yes, as least-recently-assigned (a fair-queue round robin), plus a separate manual RPC `app.assign_lead_round_robin`. |
| 11 | Business hours? | **No.** A lead created at 23:50 is reassigned at 00:20. See question 2. |
| 12 | Manager escalation? | Yes, and it is the one part with a documented failure history: `app.lead_responsible_managers` resolves `branch_manager` / `department_manager` by *both* scoped role assignment and branch/department placement, because the placement source is the one `app.assign_user_role` actually populates. Asserted by `63_sla_escalation_test` assertions 1 and 5 (the manager can see the lead; the widening did not become "notify every manager"). |
| 13 | In-system, email, or both? | **In-system only.** `process_lead_sla` inserts into `public.notifications` and — unlike the credit-threshold path — writes **no** row to `public.notification_deliveries`. Nothing anywhere in ORVION sends mail. |
| 14 | Is email architecture ready without coupling the DB to a provider? | The *pattern* exists and is proven on another path; the SLA path does not use it. See §7. |
| 15 | Observable and auditable? | Strongly. Append-only `lead_assignments` history (`app.forbid_assignment_history_rewrite`), `events` rows with `from_user_id`/`to_user_id` payload and `seq` ordering, `lead_timeline` RPC, and durable `scheduled_job_findings` for both failures and deferrals, aggregated by `app.scheduled_job_health()`. |

### Where the requested rule and the built rule differ — and why the built one is better

The business request says "15 minutes **from lead creation**". The implementation measures from **assignment** and requires a *qualifying interaction* rather than mere "acceptance". Canon 04, canon 10, canon 26 and the project charter all describe 15 + 15 measured from assignment with no explicit acceptance step, and canon 26 states it plainly: *"Lead SLA is not a status field. It is derived from assignment and interaction events."* An unassigned lead has no one to hold responsible, so creation is the wrong clock. **No change is recommended on this point.** There is no separate "employee accepted" state, and none is needed unless the owner wants acceptance to be a distinct, measured act — that is a product decision, not a defect.

### Gaps found

- **No per-tenant, per-priority or per-service SLA policy.** `leads.priority_code` exists and is ignored by the SLA. The windows are function defaults invoked with no arguments. A per-tenant policy table would be the natural home; canon currently fixes 15/15 for everyone, so changing this is an owner decision (§20).
- **No calendar awareness** — two structurally complete tables with zero consumers (§16 A-02).
- **No overlap lock on a job that runs every 60 seconds.** pg_cron starts the next run whether or not the previous finished; the documented mitigation is a `pg_try_advisory_lock` at the top of the job. ORVION relies on the unique index to keep data correct instead, which works, but converts an overlap into a recorded error rather than a clean skip.
- **Manager membership in the reassignment pool** is recorded as LEAD-3 and was resolved in `202607056800`; it is not reopened here.

---

## 5. Feature-Level Authorization Audit

The target model in the brief — group → feature → view/manage, per user, with explicit deny and inheritance — is already the model in the database. The architecture can carry the admin UI described, with two named caveats.

**Evidence** — `LOCAL RUNTIME` · `REPOSITORY`

`public.permissions` carries `key`, `capability_group`, `action_kind`, `required_feature_code`, `is_active` — 74 rows, `action_kind` ∈ {manage: 59, view: 15}, groups: CRM 26, Booking 12, Finance 12, Organization 8, Documents 4, API 2, Marketing 2, Subscription 3, **NULL 5**. `public.user_permission_grants` carries `effect` ∈ {grant, deny} with `starts_at`/`ends_at`/`is_active`. Tests: `92_capability_grant_model_test`, `22_write_authority_test`, `57_write_capability_map_test`, `85_write_capability_on_update_test`, `30_plan_gating_test`, `31_access_revocation_test`.

### Precedence, verified against both implementations

The rule *deny > user grant > role grant > plan gate* is implemented twice and the two agree by test. `app.has_permission` evaluates `not exists(deny) and (exists(grant) or exists(role→role_permissions)) and app.plan_allows(required_feature_code)`. `app.effective_permissions` returns the same verdict per permission *plus its inputs* — `from_role`, `user_grant`, `user_deny`, `plan_allows`, `effective` — which is exactly the "why does this user have this?" explainability surface an administration UI needs, and it is already an exposed RPC in `MASTER_API_CONTRACT.md`.

### How comprehensively is it enforced? — measured, not assumed

| Measurement | Count | Meaning |
|---|---|---|
| public tables with RLS enabled and ≥1 policy | 77 / 77 | no table is outside the tenant boundary |
| tables `authenticated` may INSERT or UPDATE directly | 56 | the PostgREST "second door" (BOOK-1 class) |
| …of those, carrying a permission-checking trigger | 36 | `guard_write_capability` (25) + dedicated guards |
| …of the rest, carrying a permission-bearing RLS policy | 16 | e.g. `user_role_assignments`, `document_retention_policies` |
| **tables with no capability check on either door** | 4 | `lead_interactions` (actually guarded — see below) + 3 personal auth tables |
| table grants held by `anon` | 0 | login genuinely required |

`lead_interactions` appears in the residue only because its guard reaches the permission indirectly: `app.guard_lead_interaction_authority` calls `app.require_lead_handler(assigned_user_id)` rather than `app.authorize` by name. It is enforced. The genuine residue is therefore **three tables — `otp_challenges`, `totp_enrollments`, `trusted_devices`** — each carrying an `owner_only` policy of the form `auth_user_id = (select auth.uid())`, which is the correct rule for personal authentication material and is asserted as intentional by `10_grant_model_test` ("at most 3 have no capability enforcement of ANY kind — all three INTENTIONAL by canon 34").

**Governance accuracy issue, not a security issue.** `MASTER_GAP_REGISTER.md` line 663 still carries **SEC-1** as *High · BLOCKED — business/architectural decision* with the measurement *"59 tables accept a direct INSERT; 40 have no capability check anywhere on the direct write path"*. That measurement is from 2026-08-28 and has since been overtaken by SEC-1b, SEC-1c, FIN-3 and the write-capability migrations: the same measurement today yields **3 intentional**. The finding's own remediation clause anticipated this ("the numbers may fall"), and the ceilings in `10_grant_model_test` have indeed been lowered. What has *not* happened is a status re-classification, so a cold-start agent reading the register meets a High/BLOCKED row describing an exposure that no longer exists. Recorded as A-01; the underlying (a)-vs-(b) architectural choice is the owner's and is not reopened here.

### Can it carry the described admin UI?

**Yes.** `capability_group → key → action_kind` is precisely Feature Group → Feature → View/Manage; a per-user matrix is `effective_permissions(p_user_id)`, which is already permission-gated (a caller may itemise their own; itemising another user's costs `MANAGE_PERMISSIONS`). Groups behave as organisational umbrellas exactly as the brief requires — nothing grants by group; a group is a label on independently grantable rows. Revocation is immediate: `has_permission` is `STABLE`, evaluated per statement, with no cached materialisation anywhere (`31_access_revocation_test`).

#### Caveats that would surface in that UI

- **5 permissions have `capability_group = NULL`** and would fall out of a group-driven tree, or need an "Ungrouped" bucket. Low severity, one `UPDATE` when the supplier/admin package is next opened (A-06).
- **Direct grants are tenant-wide.** `user_permission_grants` has no `branch_id`/`department_id`/condition column, while `user_role_assignments` does have scope. So "manage bookings, but only in Alexandria" is expressible as a role assignment and not as a direct grant. Not a defect — a boundary the UI must respect, and the natural extension point if attribute-based rules are ever wanted (A-07).
- **Temporal semantics differ between the two grant sources.** `has_permission` checks `starts_at <= now()` for user grants but only `is_active`/`ends_at` for role assignments, so a role row inserted with a future `starts_at` would be effective immediately. Not reachable through `app.assign_user_role` (which never sets it), only through direct DML by a holder of `MANAGE_USERS`. Low (A-08).
- **Four functions still resolve behaviour by role code rather than capability:** `lead_responsible_managers`, `credit_alert_recipients`, `requires_mfa`, `provision_tenant`. Two are defensible (seeding; MFA policy is genuinely role-shaped), two encode "who is a manager / who hears about credit" as a hard-coded role list, which a tenant with custom roles cannot change (A-09).

---

## 6. Customer/Supplier Credit Audit

Two implementations of one idea, a generation apart. The customer side, built 2026-09-04 under CUST-3, is the reference pattern; the supplier side predates it and carries all three open findings.

| Aspect | Customer | Supplier |
|---|---|---|
| Ceiling storage | `customers.credit_limit_amount` + `_currency_code`, nullable, tenant-scoped | `suppliers.credit_limit_amount` + `_currency_code`, nullable, tenant-scoped |
| Both-or-neither CHECK | ✔ `customers_credit_limit_currency_check` | ✔ `suppliers_credit_limit_currency_check` |
| Non-negative CHECK | ✔ `customers_credit_limit_non_negative_check` | **✘ absent — CUST-4** |
| Exposure sources | invoices − payments + completed refunds | locked booking-item cost − supplier payments |
| Cross-currency | converts via `app.exchange_rate_as_of`, and *reports* what it could not convert as `unconvertible text[]` | **silently drops** every currency ≠ the ceiling's (`and bi.currency_code = p_currency_code`) — SUP-4c |
| Re-evaluated when exposure moves | ✔ triggers on invoices, payments, refunds | ✔ triggers on booking_items, payments |
| Re-evaluated when the ceiling moves | ✔ `customers_probe_credit_ceiling` AFTER INSERT OR UPDATE, with a WHEN clause | **✘ no such trigger — SUP-4d** |
| Authority to change the ceiling | ✔ `guard_customer_credit_authority` → `MANAGE_CUSTOMER_CREDIT` | ✔ `guard_supplier_credit_authority` → `MANAGE_SUPPLIER_CREDIT` |
| "Credit-only write" detection | robust OR-list on the two columns | **full row-image `to_jsonb` diff — CUST-5** |
| Duplicate-alert prevention | ✔ last threshold event in `events` is the idempotency ledger | ✔ same pattern |
| Clearing event | ✔ `customer_credit_threshold_cleared` | ✔ `supplier_credit_threshold_cleared` |
| Notification + delivery obligation | ✔ `notifications` + `notification_deliveries(email, pending)` | ✔ same |
| Warning-only semantics | ✔ stated in event payload (`enforcement: warning_only`) and in the notification body | ✔ same |
| Tests | `95_customer_credit_threshold_test` (27 assertions incl. defect injection) + 9 HTTP assertions | `93`, `90`, `91`, `86_supplier_credit_visibility_test` |

**Warning-only is correctly implemented as a design, not an omission**: neither evaluator raises, neither blocks a write, and both say so in the payload. Introducing blocking later is a bounded change — a new trigger on the exposure tables reading the same two functions — because the exposure calculation, the ceiling, the authority and the event vocabulary already exist. **No schema redesign would be required.**

**Currency and as-of behaviour.** `app.exchange_rate_as_of` is written generically (tenant, from, to) so the supplier side can adopt it without a second authority appearing — that was a deliberate CUST-3 decision recorded in the register. The customer path takes a spot rate at evaluation time, citing mark-to-market practice; there is no historical revaluation and none is needed for a warning control.

---

## 7. Email Notification Architecture

ORVION can already record a durable, provider-neutral delivery obligation. It cannot dispatch one, cannot retry one, and does not create one for the lead-SLA events the owner specifically asked about.

### What exists

- `public.notifications` — tenant, target user, type code (governed catalog), title, body, related entity, `is_read`/`read_at`. In-system delivery is complete.
- `public.notification_deliveries` — `channel_code`, `delivery_status_code`, `sent_at`, `failed_at`, `error_message`. This is a genuine outbox row: the business transaction writes the obligation, and no provider is named anywhere in the database.
- **Exactly two producers**, measured across every function body: `app.evaluate_customer_credit_threshold` and `app.evaluate_supplier_credit_threshold`, each writing `('email','pending')`.
- A **proven dispatcher pattern already in this repository**, on a different path: `app.claim_conversion_deliveries` / `app.record_conversion_delivery_result` with a lease, guarded by `09_conversion_delivery_lease_test` and a dedicated integration role. This is the template; it does not need inventing.

### What is missing

1. **No dispatcher and no claim/lease RPC for notifications.** Rows enter `pending` and stay there.
2. **No retry model.** Unlike `document_storage_findings` (which has `attempt_count`, `last_attempt_at`, `last_error`) and unlike `scheduled_job_findings`, the delivery table has no attempt counter, no next-attempt time and no dead-letter state — the three things the outbox pattern exists to provide.
3. **The lead-SLA path writes no obligation at all**, so even a future dispatcher would not send the reassignment email the owner described. This is the single highest-leverage line in the whole audit (A-03).
4. **No per-user notification preferences table**, while canon 10 already distinguishes mutable alerts from unmutable manager escalation.

**Verdict on the architecture question asked:** the shape *Business Event → Notification → Delivery Obligation → Dispatcher → Result → Retry/Dead-letter/Audit* is achievable **without redesigning any core business table**. It needs: three or four columns on `notification_deliveries`, one claim RPC plus one result RPC modelled on the conversion pair, catalog values for the new delivery statuses, and one line in each notification producer. Everything upstream of the dispatcher is already correct.

---

## 8. SaaS Commercialization Readiness

The isolation and entitlement halves of a SaaS product are built and tested. The commerce half — metering, billing, quotas, self-service onboarding — is structurally present and functionally empty.

| Dimension | State | Evidence and reasoning |
|---|---|---|
| Architecture | **GREEN** | Shared-schema, tenant-per-row with RLS (ADR-0003 lineage); branches and departments modelled as first-class scope with placement history (`user_branch_assignments`) separate from role scope. |
| Database | **GREEN** | 77 tables, tenant-qualified composite FKs throughout (TENANT-1), `tenant_id` index coverage asserted by `04_tenant_id_index_coverage_test`, money at `numeric(19,4)` asserted by `03`. |
| Security | **GREEN** | RLS on every table + policy; `anon` holds nothing; RLS initplan wrapping asserted (`06`); every function pins `search_path` (`05`); MFA gate (`app.mfa_satisfied`) on sensitive paths; append-only event and audit backbone (`02`). |
| Authorization | **GREEN** | §5. Two doors enforced; residue of 3 intentional self-scoped tables. |
| Subscriptions | **GREEN** | States trial / active / grace_period / read_only / suspended / cancelled / expired with a transition validator (`app.subscription_transition_allowed`), a nightly `pg_cron` lifecycle job with per-tenant isolation, auto-renew, and a write gate (`app.subscription_allows_write`) enforced by trigger on business tables. |
| Entitlements | **GREEN** | `feature_entitlements(subscription_plan_id, feature_code, is_enabled, limit_value)` wired into `has_permission` via `plan_allows` — a disabled feature disables its permissions, tested by `30_plan_gating_test`. |
| Usage metering | **NOT IMPLEMENTED** | `usage_counters` exists with a unique key per (tenant, metric, period) — and **no writer anywhere in the database**: zero functions and zero triggers reference it. `authenticated` holds SELECT only. |
| Quota enforcement | **NOT IMPLEMENTED** | `app.plan_limit(feature_code)` returns the ceiling and **has zero in-database consumers** — it is a client-facing read. No code compares a count against a limit. Entitlement is on/off only. |
| Billing | **YELLOW — manual only** | No invoicing of tenants, no gateway, no ledger of platform revenue. The path that exists is manual: `subscription_payment_proofs` (upload → platform review → `platform_activate_subscription`), plus offline licence tokens (`tenant_license_activations`, `redeem_license_token`). Adequate for hand-sold deployments, not for self-service. |
| Tenant onboarding | **YELLOW** | `app.provision_tenant` exists and seeds roles, permissions, chart of accounts and the first user — but it is a platform-operator RPC, not a self-service signup flow. Correct for the current sales model. |
| Operations | **YELLOW** | Three scheduled jobs, all with per-tenant fault isolation (skip-never-raise) and durable findings. Missing: any alert when findings accumulate. |
| Observability | **YELLOW** | Rich inside the database — 8 reporting views, sequenced `events`, `security_events`, `scheduled_job_health()`. Nothing outside it: no metrics export, no uptime signal, and **no guard proves the cron jobs still exist and are active on Primary** (A-05). |
| Commercial readiness | **RED** | ORVION can be *operated* for multiple tenants today. It cannot yet *sell itself*: nothing measures usage, nothing enforces a quota, nothing produces a tenant invoice. |

### Product isolation — can one agency see another's data?

On the evidence available in this read-only session: **no path was found**. Every table carries RLS with a tenant predicate; foreign keys are tenant-qualified composites, so a child row cannot point across tenants even with a forged id; SECURITY DEFINER helpers that take a tenant argument re-check it against the session (`eligible_lead_handlers` raises `42501` if asked about another tenant); and the suite includes dedicated isolation tests (`21_read_scope_model_test`, `27_event_visibility_test`, `40_financial_scope_test`, `66_scheduled_job_isolation_test`). This is `LOCAL RUNTIME` + `REPOSITORY` evidence; the six HTTP suites that prove the browser-facing door were not run during the audit, so the strongest available class for the claim is *not* HTTP today.

**The one standing residual risk is the `service_role` key**, which holds full DML on 85 tables and bypasses RLS by design — standard for Supabase, and the reason ORVION's own rule keeps that key out of client surfaces. It is a key-custody risk, not a schema defect.

### Scale

No performance claim is made — no load test exists and none was run. What can be said structurally: tenant-scoped indexes are asserted for coverage, the RLS predicates are initplan-wrapped (the pattern that keeps `auth.uid()` from being re-evaluated per row), and the per-minute SLA job is the only unbounded full-table scan in the scheduled set — it reads every lead in status `assigned` across all tenants each minute, using `leads_tenant_status_idx`. That job is the first thing that will need attention at high tenant counts, and it is also the one without an overlap lock.

---

## 9. CRM Completeness Audit

As a travel-industry CRM the entity model is more complete than most products at this stage, and the gaps are specific rather than structural.

### Present and coherent

- **Identity** — customers with type, contacts (`customer_contact_methods`), duplicate detection (`find_customer_duplicates`, `duplicate_phone_approved`), identity signals, and a merge with its own audit table (`customer_identity_merges`) and behavioural test (`71`).
- **Lead management** — source, status, priority, closure reason, snapshots of contact data at capture, attribution click, assignment history, interactions, SLA, conversion (`convert_lead`), `lead_booking_readiness`.
- **Sales** — quotations with items, derived totals (`recompute_quotation_total`), validity, sent/accepted/rejected stamps, conversion to booking, ownership triplet (user/branch/department) on every commercial object.
- **Service** — conversations, messages (rewrite-forbidden), tasks, complaints, service requests, each with a state machine in `app.status_transitions`.
- **Travel-specific** — passengers with passport and visa numbers, issue/expiry dates, issuing country, nationality, relationship to customer; booking items linked to passengers; suppliers with internal-supplier linkage; `expiring_documents`.
- **Revenue** — invoices with an internal state machine and a separate ETA fiscal boundary, payments, allocations with a ceiling constraint, refunds, receipts, a real double-entry journal (balanced by trigger), `booking_item_profit`, and both outstanding views.
- **Marketing** — campaigns, daily metrics, attribution clicks with lineage protection, offline conversions and their delivery outbox.
- **Auditability** — `events` with `seq`, severity and payload; creation-event completeness asserted by `37`; actor attribution derived by trigger and never accepted from the caller (`61`, `62`, `83`, `87`).

### Gaps, each classified

- **Quotation revisions** — no version chain or parent pointer on `quotations`; a revised quote is a new unrelated row. *Required before SaaS commercialization* (travel quotes are re-priced constantly and agencies compare versions).
- **Notification preferences** — no table, while canon already distinguishes mutable from unmutable alerts. *Required before production* if email goes live.
- **Customer-to-customer relationships** — family/household/corporate grouping exists only as `customer_type_code` + `passengers.relationship_to_customer_code`. *Future enhancement*; group travel is partly served by bookings.
- **Travel preferences** (seat, meal, hotel class, airline loyalty) — not modelled. *Future enhancement*, genuinely useful in this industry.
- **Per-tenant SLA / follow-up policy** — see §4. *Owner decision.*
- **Opportunities as a separate entity** — deliberately absent; leads + quotations cover it. *Overengineering to add.*

---

## 10. Self-Healing / Self-Learning Engineering Architecture

ORVION already has more of this than most repositories ever build. What it lacks is the closing arc: detection exists, notification and bounded repair do not.

### Building blocks that already exist

| Stage | Present? | Mechanism |
|---|---|---|
| Observe | ✔ | `events` (sequenced, append-only), `security_events`, reporting views, `pg_stat_statements` |
| Detect | ✔ | 19 repository checks; parity guard over 10 structural surfaces; 97 pgTAP files including fitness functions (RLS coverage, search_path, money precision, grant model, vocabulary registries) |
| Classify | ✔ | Evidence classes (REPOSITORY / LOCAL RUNTIME / HTTP / PRIMARY / GENERATED / HISTORICAL / EXTERNAL / INTENT / INFERENCE) — an unusually mature idea, enforced socially rather than mechanically |
| Explain | ✔ | Register entries carry mechanism, reproduction and counter-evidence; `impact.ps1` answers "what consumes this structure" from the live catalog |
| Propose | ✔ | MASTER_EXECUTION_PLAN sequencing; future-backlog with triggers |
| Approve | ✔ | Owner-decision tier in AGENTS §3; `approval_requests` table is the in-product analogue |
| Repair | partial | Runtime self-healing exists for one domain only: `reconcile_document_storage` + `document_storage_findings` with `attempt_count`/`resolution_code`, and `record_job_finding`/`resolve_job_finding` for scheduled work |
| Test / Security / Consistency / Parity | ✔ | The §5a protocol: reset → Pass A → 6 HTTP suites → Pass B → smoke → Primary's three values → parity guard → regenerate → consistency guard |
| Commit / Report | ✔ | Session report with a mandatory HANDOFF block (INHERITED · PROVEN · UNPROVEN · CHANGED · REMAINING · DO NOT TOUCH · NEXT) |
| **Alert** | **✘** | Nothing consumes `scheduled_job_health()`. A job can fail for every tenant, every minute, and only a human running a query would know |

### Proposed future architecture (design only — not implemented)

The safe shape follows the authority boundary this repository already uses, and the decisive property is that **the autonomous tier may only ever act where a deterministic invariant defines "correct"**:

1. **Tier 0 — deterministic safe repair (autonomous).** Regenerate what a generator owns (`ai-map.json`, `MASTER_API_CONTRACT.md`, `repository-index.md`), refresh the Primary ledger evidence, resolve a stale job finding. Preconditions: the artifact is declared auto-generated in `GOVERNANCE.md §5`, the regeneration is byte-deterministic, and the guard that consumes it passes afterwards. Anything else fails closed.
2. **Tier 1 — engineering decision (proposed, human-approved).** A missing constraint, a missing trigger, a missing test. Output is a diff plus its evidence, never an applied change.
3. **Tier 2 — business decision.** Vocabulary, policy, thresholds, who gets notified. Stop and present options.
4. **Tier 3 — legal/compliance.** Retention, consent, data residency. Stop; never default.
5. **Ambiguity is Tier 2 by default**, never Tier 0. The failure mode to design against is a repair that satisfies a guard without satisfying the invariant — the MEAS-1/PAR-3 class this repository has already met six times.

The one genuinely missing mechanical piece is a **detection→signal bridge**: a small function that turns unresolved `scheduled_job_findings` and unresolved `document_storage_findings` into a durable operational signal, reusing the notification path once §7 lands. Everything else above is orchestration of parts that already exist.

### Session continuity — already strong

A fresh agent can reconstruct current state from the repository alone: `README` → `AGENTS §4` → `manifest.md` → active CR → latest session report, with `ai-map.json` as the machine-readable mirror and Check 7 proving the two agree. Verified by doing exactly that at the start of this session, with no chat history. The remaining continuity weakness is not structural but editorial: the register's SEC-1 row (A-01) shows how a stale status in an otherwise-guarded file misleads precisely the reader the system is designed to serve.

---

## 11. CI Path-Filter Audit

The concern is correct, the mechanism is exactly as suspected, and the fix is the simple one — but for a reason worth stating, not because simple wins by default.

### Which checks consume the three paths

| Path | Consumed by | What breaks if unguarded |
|---|---|---|
| `supabase/migrations/**` | Check 9 (manifest migration count / latest / fingerprint), Check 19 (Primary ledger evidence agrees with the migration set) | A migration lands while the manifest and the recorded Primary reading still describe the previous set — the RECOVER-1 class, exactly |
| `supabase/tests/**` | Check 1 (broken test references in Living docs), Check 15 (manifest suite figures vs. actual files/assertions) | A doc cites a test file that no longer exists; the manifest's "97 files / 1423 assertions" silently goes stale |
| `ai-map.json` | Check 7 (ai-map freshness vs. manifest: phase, active CR, last completed, next capability) | The cold-start pointer disagrees with its own SSOT — the INC-2 class the check was written for |

### Findings

1. **Repository Consistency triggers on** `**/*.md`, `scripts/check_repository_consistency.ps1`, `scripts/check_primary_ledger.ps1`, `reports/evidence/primary-ledger-evidence.json`, and its own YAML. None of the three paths above.
2. **Migration CI triggers on** migrations, tests, `config.toml`, `verify_database.sql` — and runs `db reset` + `supabase test db` + the smoke test. **It does not run the consistency guard**, and it does not trigger on `ai-map.json` at all.
3. **So yes — a migration-only, test-only or ai-map-only commit reaches `main` with no consistency guard.** In practice most such commits also touch a `.md` file (the manifest) and trigger the workflow incidentally — which is precisely why this has not bitten yet, and precisely why it will bite on the one commit that does not.
4. **Is it intentional? No.** The workflow's own comment, added when Check 19 shipped, states the governing rule in the file itself: *"Every file the guard reads or executes belongs in these lists."* The three paths fail that rule as written. This is an oversight measured against the repository's own stated intent, not a deliberate scope choice.
5. **Redundant execution risk is negligible.** A commit touching both a migration and a doc already triggers both workflows once each; adding paths adds runs only for commits that currently escape. The consistency guard opens no database and completes in seconds.

### Recommendation

**Add the three paths to `repository-consistency.yml` (push and pull_request), and do not move any check into Migration CI.** The reasoning is ownership, not convenience: the two workflows measure different evidence classes — Migration CI proves `LOCAL RUNTIME` behaviour (migrations apply, pgTAP passes), the consistency guard proves `REPOSITORY` facts (documents agree with files). Merging them would produce one verdict over two classes, which is the exact failure the repository separated these guards to avoid. Specialised workflow ownership with *correct* path lists is the right architecture; only the lists are wrong.

One caveat to carry into implementation: `reports/evidence/primary-ledger-evidence.json` is already listed, so the Check 19 pairing is half-covered — adding `supabase/migrations/**` completes it. `REPOSITORY`

---

## 12. SUP-4d Verification

**STILL OPEN at HEAD `1df2f06`. Severity confirmed Medium.**

**Reproduction — catalog measurement** `LOCAL RUNTIME`

Every trigger whose definition mentions credit was enumerated. `customers` carries **two**: `customers_guard_credit_authority` (BEFORE, authority) and `customers_probe_credit_ceiling` — `AFTER INSERT OR UPDATE … WHEN (new.credit_limit_amount IS NOT NULL AND new.credit_limit_currency_code IS NOT NULL) EXECUTE app.probe_customer_credit_ceiling()`. `suppliers` carries **one**: `suppliers_guard_credit_authority`. There is no supplier equivalent of the ceiling probe.

The supplier evaluator is reached only from `app.probe_supplier_credit_threshold`, attached to `booking_items` and `payments` — the two *exposure* tables. Lowering `suppliers.credit_limit_amount` below a standing payable therefore emits nothing until an unrelated write to one of those two tables happens to occur.

**Mechanism:** the control watches the operand that moves most often and not the operand a manager actually changes deliberately. **Business impact:** the moment a finance manager *tightens* a supplier ceiling — the moment a credit control is most meant to speak — the system is silent, and the reporting view will show an over-limit supplier that the event ledger never announced. **Fix shape (not applied):** mirror `customers_probe_credit_ceiling` onto `suppliers`, one trigger and one probe function, with the same WHEN clause so ordinary supplier edits cost nothing. Engineering-resolvable; no owner decision; no compliance dependency.

---

## 13. CUST-4 Verification

**STILL OPEN at HEAD `1df2f06`. Severity confirmed Low.**

**Reproduction — constraint enumeration** `LOCAL RUNTIME`

All CHECK constraints on both tables were listed. `customers`: `customers_credit_limit_currency_check` *and* `customers_credit_limit_non_negative_check ((credit_limit_amount IS NULL) OR (credit_limit_amount >= 0))`. `suppliers`: `suppliers_credit_limit_currency_check` only. No non-negative constraint exists on `suppliers.credit_limit_amount`.

**Consequence:** a negative supplier ceiling is storable. It is not catastrophic — `evaluate_supplier_credit_threshold` would simply find every exposure above it and alert once — but it is meaningless data that the customer side already refuses, and integrity constraints are the cheapest control in the system. **Fix shape:** one `ALTER TABLE … ADD CONSTRAINT` in the supplier package. Engineering-resolvable; no owner decision.

---

## 14. CUST-5 Verification

**STILL OPEN at HEAD `1df2f06`. Severity confirmed Low, with a permissive-direction failure mode that deserves attention.**

**Reproduction — function source + trigger ordering** `LOCAL RUNTIME`

`app.guard_write_capability` still contains, for suppliers:

```
v_credit_only := (new.credit_limit_amount is distinct from old.credit_limit_amount
                  or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code)
                 and (to_jsonb(new) - 'credit_limit_amount' - 'credit_limit_currency_code' - 'updated_at')
                   = (to_jsonb(old) - 'credit_limit_amount' - 'credit_limit_currency_code' - 'updated_at');
if v_credit_only then
    v_perms := array['MANAGE_SUPPLIER_CREDIT'];
end if;
```

The BEFORE trigger set on `suppliers` was re-measured and matches the finding's original measurement exactly: `enforce_archive_authority`, `enforce_catalog_codes`, `enforce_subscription_write_gate`, `guard_credit_authority`, `guard_write_capability`, `set_updated_at` — none mutates `new` before the guard runs, and `set_updated_at` sorts after it. The comparison is therefore correct *today*, for a reason no test pins.

**Why it matters more than "Low" suggests:** the branch *replaces* `v_perms` rather than adding to it. The day anyone adds a `derive_*` trigger to `suppliers` — the exact thing that happened to `customers` with `derive_first_registration_actor` — the row image stops matching, the branch stops firing, and a credit-only write silently starts demanding `ASSIGN_SUPPLIER` instead of `MANAGE_SUPPLIER_CREDIT`. A finance manager who holds the credit permission but not the supplier-assignment one would be refused, and nothing in the suite would say why. **Fix shape:** adopt the customer OR-list form (a write that *touches* the ceiling makes `MANAGE_SUPPLIER_CREDIT` sufficient; `suppliers_guard_credit_authority` continues to *require* it), with the table test in its own outer `if`. Engineering-resolvable; no owner decision.

---

## 15. External Best-Practice Comparison

| External practice | Applicability | Assessment against ORVION |
|---|---|---|
| **pg_cron overlap protection** — pg_cron starts the next run whether or not the previous finished; the documented mitigation is `pg_try_advisory_lock` at the top of the job, exiting cleanly when another run holds it | Directly applicable | ORVION's per-minute SLA job has no such lock. It is *safe* (unique partial index prevents duplicate current assignments) but not *clean* (an overlap becomes a recorded `item_failed`). Recommended as part of any SLA package. Sources: crontap.com/guides/postgres-cron-jobs; supaexplorer.com/best-practices/supabase-postgres/lock-advisory/ |
| **Transactional outbox** — write the delivery obligation in the same transaction as the business change; a separate worker polls, publishes, marks sent, retries with backoff, and dead-letters after N failures | Directly applicable | ORVION has the first half exactly right (`notification_deliveries` written inside the business transaction, no provider named in the database) and none of the second half — no worker, no attempt counter, no backoff, no dead letter. Its own `claim_conversion_deliveries` lease is a closer, better-fitting precedent than any external framework. Source: docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html |
| **Capability/permission-based authorization over role checks** (OWASP ASVS access-control guidance; NIST SP 800-162 on ABAC) | Already adopted | ORVION checks capabilities, not role names, in the enforcement path. The four residual role-code functions (§5) are the only divergence, and two of them are defensible. No change of model recommended. |
| **Attribute/context-based rules as an extension, not a replacement** | Comparative only | The natural extension point is a scope or condition column on `user_permission_grants`, mirroring the scope already on role assignments. Adding a full policy engine would duplicate an authority that `has_permission` already owns — rejected as overengineering. |
| **Credit exposure marked to market at evaluation time** (the practice CUST-3 already cites) | Partially applied | Applied on the customer side; the supplier side still drops non-matching currencies entirely (SUP-4c). Bringing suppliers onto `exchange_rate_as_of` requires no new authority — the function was written generic for exactly this. |
| **Vendor SaaS reference architectures** (Salesforce/Dataverse permission models, AWS multi-tenant isolation patterns) | Not applicable | Deliberately not imported. ORVION's shared-schema + RLS model with tenant-qualified composite FKs is coherent, tested, and cheaper to operate at this scale than silo or pooled-with-sharding designs. No evidence was found that any vendor pattern would improve it. |

Sources consulted: `https://crontap.com/guides/postgres-cron-jobs` · `https://supaexplorer.com/best-practices/supabase-postgres/lock-advisory/` · `https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html` · `https://www.geeksforgeeks.org/system-design/outbox-pattern-for-reliable-messaging-system-design/`

---

## 16. Gaps Discovered

Audit-local identifiers (A-nn) are used deliberately so nothing here is confused with a register ID. Three registered findings (SUP-4d, CUST-4, CUST-5) are verified in §12–§14 and are not repeated as new gaps.

### A-01 — The register's SEC-1 row describes an exposure that measurement no longer supports · Medium

- **Type:** Governance / documentation accuracy (not a security defect)
- **Evidence:** `MASTER_GAP_REGISTER.md:663-671` states High · BLOCKED with "59 insertable, 40 with no capability check"; live measurement gives 56 writable and 3 with no check of any kind, all three intentional and asserted as such in `10_grant_model_test`
- **Current behavior:** A cold-start agent reads an open High finding whose stated measurement is a year-stale artifact of the programme's own progress
- **Expected behavior:** The row carries the current measurement, and either closes on evidence or states precisely which architectural question remains open
- **Why it matters:** This repository's continuity model depends on the register being the one place a finding's status lives; a stale status is the failure mode it was built to prevent
- **Engineering-resolvable?** Engineering can re-measure and restate; **closing** an owner-BLOCKED finding needs the owner
- **Owner decision?** Yes, for closure (see D5)
- **Compliance dependency?** No
- **Recommended timing:** Next governance touch — before any new authorization work

### A-02 — Business-hours and holiday tables have no consumer · Medium

- **Type:** Architecture gap (capability declared in canon, absent in code)
- **Evidence:** `public.branch_business_hours`, `public.holidays` exist with grants and policies; canon 24 says they "support SLA calculation windows/exceptions"; a full scan of function bodies, view definitions and policy expressions found the words only inside `guard_write_capability`'s write-permission map
- **Current behavior:** A lead assigned at 23:50 on a public holiday is escalated at 00:05 and reassigned at 00:20 to someone who is not working
- **Expected behavior:** SLA elapsed time counts working time, per branch calendar
- **Why it matters:** Out-of-hours reassignment churns ownership and generates notifications nobody acts on — it degrades the control it is meant to be
- **Engineering-resolvable?** Yes, once the policy question is answered
- **Owner decision?** Yes — D1
- **Compliance dependency?** No
- **Recommended timing:** With any SLA package; the tables are already correct, only the consumer is missing

### A-03 — Lead-SLA notifications create no delivery obligation, so no future dispatcher can send them · High

- **Type:** Engineering defect (inconsistency between two producers of the same concept)
- **Evidence:** Only `evaluate_customer_credit_threshold` and `evaluate_supplier_credit_threshold` reference `notification_deliveries`; `process_lead_sla` inserts into `notifications` alone
- **Current behavior:** The exact notification the owner asked to be emailed is the one notification that never enters the outbox
- **Expected behavior:** Every notification whose canonical channel includes email writes a `pending` obligation row, whatever the producer
- **Why it matters:** Without it, building the dispatcher would silently deliver credit alerts and not lead reassignments — a partial feature that looks complete
- **Engineering-resolvable?** Yes — three inserts, or better, one helper both paths call
- **Owner decision?** No
- **Compliance dependency?** No
- **Recommended timing:** Immediately before or with the email package

### A-04 — The delivery ledger has no retry, backoff or dead-letter state · Medium

- **Type:** Architecture gap
- **Evidence:** `notification_deliveries` columns: channel, status, sent_at, failed_at, error_message. No attempt count, no next-attempt time, no terminal dead-letter state — while `document_storage_findings` and `scheduled_job_findings` both have exactly those fields
- **Current behavior:** A failed send is a dead row; nothing retries and nothing escalates
- **Expected behavior:** Bounded retries with backoff, then a dead-letter state an operator can see
- **Why it matters:** An unreliable alert channel is worse than a documented absence of one, because people start trusting it
- **Engineering-resolvable?** Yes; the internal precedent (`claim_conversion_deliveries`) already exists
- **Owner decision?** Provider choice only (D3), not the ledger shape
- **Compliance dependency?** Indirect — provider terms
- **Recommended timing:** With the email package

### A-05 — No guard covers the scheduled-job schedule itself · Medium

- **Type:** CI / measurement gap (the MEAS-1 class)
- **Evidence:** `scripts/parity_surface.sql` hashes ten surfaces — functions, triggers, policies, RLS enablement, constraints, grants, columns, views, indexes, status transitions. `cron.job` is not among them. Both databases were compared by hand during this audit and agree (3 jobs, same schedules, active); nothing proves that tomorrow
- **Current behavior:** Disabling or dropping `lead-sla-processor` on Primary leaves every guard green — the PAR-3 pattern, one surface over
- **Expected behavior:** The cron schedule is part of the compared structural surface, or has a named guard of its own
- **Why it matters:** Three business controls (SLA, subscription lifecycle, storage reconciliation) exist *only* because a cron row exists
- **Engineering-resolvable?** Yes — one CTE in `parity_surface.sql`; note it changes the structural hash by design and needs the manifest figure refreshed in the same commit
- **Owner decision?** No
- **Compliance dependency?** No
- **Recommended timing:** Next parity/guard touch

### A-06 — Five permissions have no capability group · Low

- **Type:** Engineering improvement
- **Evidence:** `select capability_group, count(*) from permissions group by 1` → NULL: 5
- **Current behavior:** Those five would not appear in a group-driven administration tree
- **Expected behavior:** Every permission belongs to exactly one group
- **Why it matters:** Only when the admin UI is built — which is precisely when it will be discovered the hard way
- **Engineering-resolvable?** Yes, if canon's grouping covers all five; otherwise one owner question
- **Owner decision?** Possibly, for grouping intent
- **Compliance dependency?** No
- **Recommended timing:** Before any permission-administration UI

### A-07 — Direct user grants cannot be scoped to a branch or department · Low

- **Type:** Architecture boundary (not a defect)
- **Evidence:** `user_permission_grants` has no scope columns; `user_role_assignments` has `scope_type`, `branch_id`, `department_id` with a CHECK enforcing the qualifier
- **Current behavior:** A direct grant is tenant-wide; scoped authority must be expressed as a role assignment
- **Expected behavior:** Unchanged, unless the owner wants scoped exceptions
- **Why it matters:** It is the natural, low-cost extension point if attribute-based rules are ever wanted; adding a policy engine instead would be overengineering
- **Engineering-resolvable?** Yes, once wanted
- **Owner decision?** Yes — whether to want it
- **Compliance dependency?** No
- **Recommended timing:** Only on demand

### A-08 — Future-dated role assignments take effect immediately · Low

- **Type:** Engineering defect (inconsistent temporal semantics)
- **Evidence:** `has_permission` and `effective_permissions` filter role assignments on `is_active` and `ends_at` only; both filter user grants on `starts_at <= now()`. `user_role_assignments.starts_at` defaults to `now()` and `app.assign_user_role` never sets it, so the path is reachable only by direct DML from a `MANAGE_USERS` holder
- **Current behavior:** A role scheduled to begin next month is live now
- **Expected behavior:** Both grant sources honour `starts_at`
- **Why it matters:** Small now; it becomes a real control the day onboarding schedules access in advance
- **Engineering-resolvable?** Yes — one predicate in each of two functions, plus an assertion
- **Owner decision?** No
- **Compliance dependency?** No
- **Recommended timing:** With the next authorization package

### A-09 — Escalation and credit-alert audiences are hard-coded role lists · Low

- **Type:** Architecture gap
- **Evidence:** `lead_responsible_managers` filters `r.code in ('branch_manager','department_manager')`; `credit_alert_recipients` and `requires_mfa` carry similar literals
- **Current behavior:** A tenant with custom role names cannot change who is escalated to, or who hears about credit
- **Expected behavior:** Audience derived from a capability (e.g. a `RECEIVE_ESCALATION`-shaped permission), consistent with how eligibility is already resolved in `eligible_lead_handlers`
- **Why it matters:** It is the one place the capability model has a role-name back door, and it surfaces the moment a tenant customises roles
- **Engineering-resolvable?** Yes, after the policy question
- **Owner decision?** Yes — D4
- **Compliance dependency?** No
- **Recommended timing:** Before multi-tenant customisation is sold

### A-10 — Usage metering and quota enforcement exist as structure only · Medium

- **Type:** Architecture gap / commercial blocker
- **Evidence:** `usage_counters` has no writer in any function or trigger; `app.plan_limit` has no in-database consumer; `feature_entitlements.limit_value` is read only by `tenant_capabilities`, a client-facing view function
- **Current behavior:** Plan limits are advisory numbers the client can read; nothing counts and nothing enforces
- **Expected behavior:** For a sold product: counters written where the metered act happens, and an enforcement point that consults `plan_limit`
- **Why it matters:** Every commercial plan tier that mentions a number is currently unenforceable
- **Engineering-resolvable?** Yes, once the owner names the metered dimensions and the over-limit behaviour
- **Owner decision?** Yes — D6
- **Compliance dependency?** No
- **Recommended timing:** Before SaaS commercialization; not before production for a single operator

### A-11 — Nothing consumes scheduled-job health · Medium

- **Type:** Observability gap
- **Evidence:** `app.scheduled_job_health()` aggregates unresolved findings and is called by nothing; no notification, event or alert is produced when findings accumulate
- **Current behavior:** A job failing for every tenant every minute is visible only to someone who runs the query
- **Expected behavior:** A durable operational signal when open findings cross a threshold or age
- **Why it matters:** The self-healing architecture is complete up to the point where a human needs to be told
- **Engineering-resolvable?** Yes; depends on the notification package (§7) for the channel
- **Owner decision?** No
- **Compliance dependency?** No
- **Recommended timing:** With or after the email package

### A-12 — Repository Consistency does not run on the three paths its checks read · Medium

- **Type:** CI / repository governance gap
- **Evidence:** §11 — path lists in both workflow files, against the check→path map
- **Current behavior:** A migration-only, test-only or ai-map-only commit merges with no consistency verdict
- **Expected behavior:** Every file the guard reads appears in its trigger list — the workflow's own stated rule
- **Why it matters:** It disarms Checks 1, 7, 9, 15 and 19 for exactly the commits most likely to invalidate them
- **Engineering-resolvable?** Yes; three lines of YAML, no design decision
- **Owner decision?** No
- **Compliance dependency?** No
- **Recommended timing:** Next CI touch — cheapest item on this list

### A-13 — The per-minute SLA job has no overlap lock · Low

- **Type:** Engineering improvement (hardening)
- **Evidence:** `process_lead_sla` contains no `pg_try_advisory_lock`; pg_cron's documented behaviour is to start the next run regardless of the previous; the unique partial index converts a collision into a caught exception recorded as `item_failed`
- **Current behavior:** Data stays correct; an overlap manufactures a recorded failure that looks like a defect
- **Expected behavior:** A clean skip when a previous run is still in flight
- **Why it matters:** It grows with tenant count — the job scans every `assigned` lead across all tenants each minute
- **Engineering-resolvable?** Yes — one guard clause
- **Owner decision?** No
- **Compliance dependency?** No
- **Recommended timing:** With any SLA package, or before tenant count grows

---

## 17. What Is Already Strong

Architecture that should **NOT** be redesigned:

- **The tenancy model.** Shared schema + RLS + tenant-qualified composite foreign keys. It is coherent, tested, and the composite-FK decision (TENANT-1) closes the class of hole most such designs leave open. Leave it alone.
- **The capability model.** `deny > user grant > role grant > plan gate`, implemented once for enforcement and once for explanation, with a test asserting the two agree for every permission and actor. Extend it; do not replace it.
- **The two-door discipline.** Enforcing at the table as well as in the RPC, because PostgREST serves both. This is the single most valuable habit in the repository and it is why the SEC-1 exposure is now three intentional tables.
- **Derived attribution.** A row can never name its own actor; `created_by`, reviewers, uploaders, merge actors and payment receivers are all derived by trigger. Four separate tests defend it.
- **The event backbone.** Append-only, sequenced, severity-tagged, with a registered vocabulary and a test that the registry cannot grow silently.
- **Scheduled-job fault isolation.** Skip-never-raise with durable per-item findings, born from a real cross-tenant denial-of-service defect. Every future job should copy it.
- **The credit-alert idempotency design.** Using the event ledger itself as the alert-state ledger — no new status column, no new vocabulary, no drift. This is the pattern to reuse for any future threshold control.
- **The evidence-class discipline and the guard-attacking habit.** Six of this programme's findings were defects in the things that measure. That is a repository that audits its own instruments, and it is rare.

---

## 18. What Should NOT Be Added

- **A policy/rules engine for authorization.** `has_permission` already owns the question; a second evaluator would be a second authority. If context-sensitivity is ever needed, extend the grant row (A-07).
- **An opportunities entity.** Leads plus quotations already carry the pipeline; adding a third would split ownership of the same fact.
- **A generic workflow/BPM engine for SLA.** The requirement is two intervals and a candidate query. A workflow engine would be several orders of magnitude more machinery than the rule needs.
- **An email provider inside the database.** The provider belongs behind the dispatcher, outside PostgreSQL. Keep the database writing obligations, never sending mail.
- **A second spec/knowledge system** — no vector index, no external knowledge graph, no agent-memory server. Already assessed and rejected on 2026-09-05 with the decisive argument that a freshly reset catalog is a better index of ORVION than any index over its migration history.
- **Wiring `impact.ps1` into CI.** It has no verdict; a lead-generator used as a gate is the overclaiming class the repository forbids. Explicitly marked DO NOT TOUCH by the previous session.
- **Blocking credit enforcement, for now.** Warning-only is a stated design. Add blocking only if the owner asks, and as a separate trigger — not by making the evaluator raise.

---

## 19. Recommended Future Engineering Packages

Grouped by shared blast radius and shared test surface — not by finding severity. **None of these is authorized by this document.**

| # | Package | Contents | Prerequisite |
|---|---|---|---|
| P1 | **Supplier credit parity** | SUP-4d (ceiling probe), CUST-4 (non-negative CHECK), CUST-5 (OR-list form), and — if the owner agrees it belongs here — SUP-4c (cross-currency conversion via the already-generic `exchange_rate_as_of`) | None. All four are engineering-resolvable and share one table, one guard and one test file |
| P2 | **CI trigger correctness** | A-12 only. Three paths added to one workflow | None. Smallest, cheapest, highest ratio of protection to effort |
| P3 | **Notification delivery** | A-03 (SLA writes an obligation), A-04 (attempt/backoff/dead-letter columns + catalog values), claim + result RPCs modelled on `claim_conversion_deliveries`, and the dispatcher living in n8n rather than in the database | **Owner decision on the provider** (§20). The database half can be built before that decision; the dispatcher cannot |
| P4 | **SLA policy & hardening** | A-02 (business hours/holidays consumer), A-13 (advisory lock), per-tenant/priority policy if the owner wants it | **Owner decision on wall-clock vs working-hours, and on configurability** |
| P5 | **Operational signal** | A-05 (cron in the parity surface), A-11 (job-health signal) | A-11 depends on P3 for its channel; A-05 is independent |
| P6 | **Authorization administration readiness** | A-06 (group the five), A-08 (starts_at), A-09 (capability-based audiences), A-01 (re-measure and restate SEC-1) | A-09 and A-01 need owner input; the rest do not |
| P7 | **Commercialization** | A-10 (metering + quota), tenant billing, self-service onboarding, quotation revisions | **Substantial owner/business definition.** Largest package; not near-term |

The existing roadmap order in `manifest.md` (GOV-20, GOV-19, SUP-4d, CUST-5, GOV-16, SUP-4c, CUST-4, …) already interleaves several of these. P1 above is simply the observation that SUP-4d, CUST-4, CUST-5 and SUP-4c touch the same table, the same guard and the same test file, and that shipping them separately pays the verification cost four times.

---

## 20. Owner Decisions Required

Each of these was tested against canon, schema, migrations, consumers, tests, runtime and the register first. Nothing here is derivable.

| # | Decision | Why it cannot be derived | Type |
|---|---|---|---|
| D1 | **Is the lead SLA a wall-clock control or a working-hours control?** | Canon states 15 + 15 with no calendar qualifier; two calendar tables exist with no consumer and canon 24 says they support SLA windows. Both readings are supportable, and they produce different products | Business policy |
| D2 | **Should SLA windows be configurable per tenant, priority or service type?** | Canon fixes 15/15 for everyone; `leads.priority_code` exists and is unused by the SLA. Making it configurable changes a canonical rule, which engineering may not do unilaterally | Business policy → canon change |
| D3 | **Which email provider, and under what data-processing terms?** | No provider exists anywhere in the repository (measured, and stated in the migration that created the obligation ledger). Provider choice carries cost, deliverability and personal-data-processing consequences | Business + compliance |
| D4 | **Is the escalation and credit-alert audience a role list or a capability?** | Both are implemented in this repository — eligibility by capability, audience by role code. Which is correct is a policy question about how tenants customise roles | Business policy |
| D5 | **SEC-1: option (a) revoke table writes, or (b) keep enforcing per table?** | Recorded as owner-blocked since 2026-08-28 and not reopened here. What is new is that (b) has effectively been executed to a residue of three intentional tables, so the live question is narrower: *ratify (b) as done, or still pursue (a)* | Architecture (owner tier) |
| D6 | **What is metered, and what happens at the limit?** | Plans carry `limit_value`; nothing counts and nothing enforces. Which dimensions are metered (users, bookings, storage, messages) and whether over-limit warns, blocks or bills is pure commercial strategy | Business / commercial |
| D7 | **Retention periods per document type** — unchanged, already recorded | RET-1's mechanism is built and seeds zero policy rows deliberately; the periods must come from counsel reconciling Egypt's PDPL against tax and commercial minimums. **Not reopened, not guessed** | Legal / compliance |

**Deliberately not manufactured as decisions:** the SLA clock start (canon answers it — assignment, not creation), the warning-only credit semantics (canon and the owner's own CUST-3 approval answer it), whether managers may receive reassigned leads (LEAD-3, already resolved), and ETA cancellation windows (VOID-1 encodes no day-count and this audit invents none).

---

## 21. Phase / Batch Impact

**Phase 8 status: IN PROGRESS — unchanged.** Not moved by this audit. The ORVION-side pipeline is built, deployed and verified; the sole remaining deliverable is the n8n workflow, and the n8n instance was queried live during this session and returned **zero workflows**.

**Batch 6: NOT STARTED — unchanged.** Not started, not planned, not begun here. No finding in this report was written as a Batch 6 work item.

**Blocking analysis: nothing blocks Phase 8.** All thirteen audit gaps sit in lead SLA, notifications, credit, authorization administration, commercialization and CI. None touches the offline-conversion pipeline, its outbox pair, its consent gate or its integration role.

**One governance item the read-only instruction prevented, recorded rather than silently skipped.** `AGENTS.md §6` requires every meaningful session — explicitly including a read-only audit (GOV-14) — to write a session report to `reports/history/` and update the pointer row in `reports/README.md`, on the grounds that the repository, never the chat, is ORVION's long-term memory. The audit itself was instructed not to modify any file. This document is the subsequently authorized export of that audit; **the `reports/README.md` pointer row is still not updated** — see the export note below.

---

## 22. Final Verdict

| Capability | Verdict | Why |
|---|---|---|
| Lead SLA & reassignment | **YELLOW** | Built, scheduled, tested, auditable. Missing: email, calendar, configurability, overlap lock. |
| Feature-level authorization | **GREEN** | The described admin UI is buildable on today's schema. Four small items, no redesign. |
| Customer credit | **GREEN** | Converts currency, reports what it cannot, probes the ceiling, idempotent, warning-only by design. |
| Supplier credit | **YELLOW** | Three confirmed open findings plus SUP-4c. All four are one package on one table. |
| Email notification | **RED** | The obligation ledger is right; there is no dispatcher, no retry, and the SLA path writes no obligation at all. |
| SaaS commercialization | **YELLOW** | Isolation and entitlement green; metering, quotas and billing not implemented. Operable, not yet sellable. |
| CRM completeness | **GREEN** | Travel-specific and coherent. Named gaps: quotation revisions, notification preferences, preferences/relationships. |
| Self-healing governance | **YELLOW** | Best-in-class detection and evidence discipline; no alerting arc and no cron guard. |
| CI coverage | **YELLOW** | Two correct workflows, one wrong path list. Cheapest fix in the report. |

---

## Export note (2026-09-05)

This file is an **export of an already-completed read-only audit**, created on explicit owner instruction after the audit finished. Scope of the export task, as instructed:

- **The only repository change is this file.** No migration, SQL, test, canonical document, manifest, Gap Register, workflow or script was created or modified. No commit, no push.
- **No remediation was performed.** Every finding above remains open exactly as measured; no A-nn identifier was written into `MASTER_GAP_REGISTER.md`, and no register status was altered.
- **The `reports/README.md` "Latest session report" pointer row remains OUTSTANDING.** That row lives in `reports/README.md` — *not* in the Gap Register and *not* in a protected file (`AGENTS.md`, `README.md`, `GOVERNANCE.md`, `CR_LIFECYCLE.md`, `_ORVION_CANONICAL/**` are the protected set per `GOVERNANCE.md §5`), so updating it would not require touching a protected resource. It was left unchanged solely because this task authorized exactly one new file and no other modification. Until that pointer is added, `AGENTS.md §4` Stage A step 7 will continue to route a cold-start session to `session-2026-09-05-engineering-awareness-layer.md`, and this audit will not be found by the boot sequence.
- **Verification of the audit's own claims** is unchanged and unre-run: every figure in §2 was read during the audit session (repository guard CLEAN 1–19; parity guard CLEAN exit 0 with Primary's three values read from Primary). This export re-ran no guard against a changed repository, because nothing about the repository changed except the addition of this document.

End of Document.
