# ORVION Engineering Future Backlog

Version: 0.1
Status: Living document (not canonical, not a Change Request)
Owner: maintained by the engineering/audit role during Change Requests and reviews

---

## Purpose

A permanent, evidence-driven record of valuable engineering ideas that are **not yet justified for immediate implementation**, so nothing important is silently forgotten or silently implemented. This is **not** a Change Request, not implementation work, and not a wish list — every entry must be backed by repository or authoritative external evidence, carry a classification, and state its trigger (when it should be reconsidered). Items graduate out of this backlog only through their own Change Request.

Classifications: **Required Soon**, **Recommended**, **Nice to Have**, **Future Candidate**. Review this document at the start of each new phase and whenever a listed trigger is reached.

---

## Required Soon (evidence-backed, near-term)

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| Reference Data Layer — core: **structure DONE, SEED still open** (scope corrected 2026-08-21) | The *structural* half is genuinely done and stays done: the tables exist and **all 19 reference-code columns are FK-backed** (`passengers.nationality_code`/`passport_issuing_country_code`, `customers.preferred_language_code`, `bookings.destination_country_code`, all `*currency_code`) — the "no integrity backing" concern is resolved. **What this row previously hid:** it was struck through as fully DONE while covering four tables of which only `currencies` was ever seeded. Live Primary and local both show `countries = 0`, `nationalities = 0`, `languages = 0` rows, so those four FK columns can hold nothing but `NULL` today. The deferral itself is legitimate and was governed all along — migration `202607045300`'s own header states the seeds "remain deferred until a hard requirement earns them (their referencing columns are nullable today)", and `SPEC-074`/`SPEC-076` both record them as still deferred — but closing this row erased the only forward-looking tracking they had. Re-tracked, not re-decided. | **Trigger:** the first consumer that must persist a real country / nationality / language — i.e. the first UI or API passenger-capture or booking-capture path. Not earned by Phase 8, which touches only `currencies`. | Yes — seed CR at the trigger. Tracked as **REF-1** in `MASTER_GAP_REGISTER.md`, which also carries the open `nationalities` vocabulary decision (reuse ISO 3166-1 alpha-2 with demonym names, or a separate demonym code set). |
| Reference Data Layer — travel-specific (cities, airports) | Still free-text/absent; distinct from the core layer above. Tracked as domain reference expansion. | See **Future Candidates — Domain Reference Layer Expansion** below (evidence-gated: a migration must introduce a column needing the integrity) | Yes, when promoted |
| ~~Table-level CHECK constraints from `31` "Rules"~~ — **DONE** (verified 2026-07-17 against migrations) | All five `31`-Rule invariants are DB-enforced in their creating migrations: journal debit/credit exclusivity + non-neg (`042500`), `booking_items`/`booking_item_passengers` non-negative (`042300`), `document_links` single-target (`042800`), `document_versions` single-current partial-unique (`041900`), passenger `passport_issue < expiry` (`042200`). This row was stale. | Closed | Implemented in the Phase-2 table migrations |
| ~~Process safeguard for Complete-sync~~ — **DONE 2026-09-02 (COLD-3, `check_repository_consistency.ps1` Check 18)** | The `Active Change Request` pointer-clear was omitted twice (SPEC-024, SPEC-027), and this row proposed a Claude Stop/PostToolUse hook. **Delivered as a guard instead of a hook**, deliberately: a hook runs only on the workstation that has it configured, while the consistency guard runs in `repository-consistency.yml` on every doc-touching push, needs no per-machine setup, and is what `GOVERNANCE.md §18` calls for. **Stronger than this row asked, too** — the row wanted `Active Change Request: None` verified *after Complete*; Check 18 instead validates the pointer against the named CR's **own `## Status` section**, so it also catches a pointer at a `Cancelled` CR, at a CR file that does not exist, and at a CR whose status section is missing, ambiguous or outside the template vocabulary. Proven first: the repository was CLEAN while pointing at `SPEC-125`, whose Status is `[x] Complete`. | Closed | Implemented as Check 18; registered as **COLD-3** in `MASTER_GAP_REGISTER.md` |
| `feature_entitlements` per-plan seed data | `subscription_plans` is seeded (SPEC-120), but the per-plan feature/limit rows are not, for four concrete unresolved reasons (full detail: `changes/SPEC-120-audit-remediation-event-vocabulary.md` Notes): (1) canon-17's six numeric per-plan limits — Users/Branches/Monthly Leads/Monthly Bookings/Storage/Automations — have no schema home (`feature_entitlements.feature_code` only carries the 15 boolean-style codes in `25_catalog_registry.md`, none of which are the numeric-metric names; those live in the separate, already-seeded `usage_metric_code` catalog consumed by per-tenant `usage_counters`, not by any static per-plan template); (2) "Unlimited"/"Custom" are not numeric and no NULL-means-unlimited (or sentinel) convention is documented anywhere; (3) "Enterprise includes all approved features" is not an enumerated list, and canon-17 itself flags `ai_dashboard` as conditional ("where approved"); (4) `offline_conversion` (a seeded `feature_code` candidate) has zero mention in any plan's Included/Excluded list. None of these are derivable from canon without inventing business policy. | Owner decides: (a) where the 6 numeric limits are stored; (b) how "Unlimited"/"Custom" is encoded; (c) whether Enterprise is a literal Professional superset or needs its own explicit list; (d) `offline_conversion`/`ai_dashboard` plan assignment | Yes — small canon + seed-migration CR once decided |

## Identity Lifecycle (from the 2026-07-04 Identity Lifecycle Review; SPEC-031 resolved the nullability contradiction)

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| `auth_user_id` → `auth.users(id)` referential action | Determines what happens if a Supabase admin deletes an auth user. SPEC-027's default `on delete restrict` would *block* that deletion; `on delete set null` lets the ORVION user survive unlinked/re-invitable. Must be a conscious choice, not defaulted. | **Migration 5 Design Review Gate** (recommend `set null`) | Decided within the Migration 5 CR (not a separate CR) |
| Invitation / activation lifecycle model | "Invited-but-not-activated" is currently only implicit (`is_active=false` + `auth_user_id` null). No invitation record, `invited_at`/`activated_at`, `invited_by`, user status/state machine, or activation/deactivation events (`26`/`27` have none for users). Re-invite reuse-vs-new is undefined. | After Migration 5 (users table exists); when the invitation UX is designed | Yes — its own feature CR |
| `users` deletion/archive clarification | `users` uses `is_active` (deactivate), has no archive fields, and is not in `30`'s no-physical-delete list — so hard-delete isn't explicitly forbidden. Clarify: deactivate-only, or add `users` to the no-physical-delete rule. | Documentation checkpoint before RLS/audit hardening | Small canonical CR if a rule is added |
| ~~Auth-support tables belong to the human, not the membership~~ — **RESOLVED** (SPEC-046 / ADR-0012) | Decided: `trusted_devices`/`otp_challenges`/`totp_enrollments` re-home to the Human Identity, keyed by `auth_user_id` → `auth.users(id)`, no `tenant_id`, cascade on human deletion. Governed by `34_authentication_and_identity_principles.md` (Principles 1/6/7). `31` §9 and `33` migration 16 amended. | Closed 2026-07-05 | Implemented by SPEC-047 (Migration 16) |
| Active-tenant RLS context (SPEC-033 / ADR-0011) | RLS must resolve `auth.uid()` + active-tenant → membership; degrades to the single membership when a human has one. The active-tenant claim/plumbing is only wired up when multi-membership UX ships. | **Migration 19** (RLS) design | Part of the RLS migration |

## Business-Key Uniqueness (from Migration 10, SPEC-040)

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| ~~`bookings.booking_reference` / `quotations.quotation_number` per-tenant unique~~ — **DONE** (migration `048800`, 2026-07-17) | `unique (tenant_id, booking_reference)` / `unique (tenant_id, quotation_number)` added; canon `31` synced. The deferred *format/sequence* decision (SPEC-073) remains separate and open — the uniqueness guard does not decide it. | Closed | Implemented (migration 048800) |

## Business-Key Uniqueness (from Migration 14, SPEC-044)

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| ~~`subscription_plans.plan_code`, `feature_entitlements(subscription_plan_id, feature_code)`, `usage_counters(tenant_id, usage_metric_code, period_start, period_end)` uniqueness~~ — **DONE** (migration `048800`, 2026-07-17) | Added `unique (plan_code)` (platform-global — `subscription_plans` has no `tenant_id`), `unique (subscription_plan_id, feature_code)`, `unique (tenant_id, usage_metric_code, period_start, period_end)`; canon `31` synced. | Closed | Implemented (migration 048800) |

## Finance Value Non-Negativity (from Migration 12, SPEC-042)

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| ~~Non-negative CHECKs on finance money columns~~ — **DONE** (migration `048800`, 2026-07-17) | Added `>= 0` CHECKs on `invoices.total_amount`, `payments.amount`, `refunds.amount`, `payment_allocations.allocated_amount`/`allocated_amount_invoice_currency`; canon `31` synced. Parity with the existing `booking_items`/`journal_entry_lines` guards. (`receipts` intentionally excluded — it has no amount column; it references a payment.) | Closed | Implemented (migration 048800) |

## Role Privileges (from Migration 19, SPEC-052)

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| ~~DML `GRANT`s to `authenticated` on tenant/global tables~~ — **ROW WAS FACTUALLY WRONG; CORRECTED 2026-08-21 (remediation pass)** | This row claimed `authenticated` "has only `TRUNCATE/REFERENCES/TRIGGER` … **not** `SELECT/INSERT/UPDATE/DELETE`, so end-user clients cannot access any table yet. Current state is safe (fully locked)". **Both halves were untrue.** (1) Migration `202607043400` — which predates this row's last review — *itself* grants `authenticated` `SELECT`/`INSERT`/`UPDATE` on tenant tables and `SELECT` on the ten global tables; the DML was never withheld. (2) On live Primary the grants were wider still: `anon` held `SELECT/INSERT/UPDATE/DELETE` on all 72 public tables and `authenticated` additionally held `DELETE`/`TRUNCATE`, inherited from Supabase's `pg_default_acl`. Nothing was "fully locked". The drift half is **closed** by SPEC-124 (migration `202607050200` + guard `10_grant_model_test.sql`, verified live). The genuine remaining question — whether `authenticated` should hold direct table DML *at all*, given that RLS scopes rows and not permissions — is **not** a backlog item; it is now **SEC-1** in `MASTER_GAP_REGISTER.md` as an owner decision. | Closed here; continues as SEC-1 | Superseded by SPEC-124 + SEC-1 |

## Naming Consistency (from the Database Naming Audit, post-Migration 20)

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| Status-column naming normalization | The audit found the schema otherwise fully consistent (constraints/indexes/table-plurals/`_at` timestamps/`_id`-vs-`_by`-vs-`_user_id` FK conventions). The one real inconsistency: `tenants.status` and `company_assets.status` use bare `status`; `invoices`/`marketing_campaigns`/`otp_challenges`/`subscription_payment_proofs`/`trusted_devices` use unprefixed `status_code` vs `<entity>_status_code` elsewhere. Cosmetic (functional today), no current consumer, but renaming post-code is a breaking change across API/frontend/queries. | **Backend/API phase start** — before any code references these columns; still cheap then, and pays off when consistency matters | Yes — small `31` amendment + `ALTER ... RENAME COLUMN` migration. Optionally include the two non-`is_`/`has_` booleans (`finance_approval_required`, `marketing_opt_in`) if a strict Boolean Standard is enforced. |

## Pre-Phase-8 Audit Orphans (from the 2026-07-13 readiness audit)

Capabilities surfaced in `reports/history/` phase reports and confirmed present-but-inert by the 2026-07-13 live-DB + reports audit — previously tracked in **no** living register. Promoted here so they are not re-discovered. Each is evidence-backed with a trigger; cross-refs avoid duplicating existing IDs.

| Item | Evidence | Trigger / when | CR? |
| --- | --- | --- | --- |
| ~~**Quotations are inert**~~ — **DONE** (migration `202607049500`, 2026-07-17) | Implemented: `create_quotation` / `add_quotation_item` / `advance_quotation` (full canon-26 state machine incl. revise loop; per-transition permissions CREATE/SEND/ACCEPT_QUOTATION already seeded — no mint) + `create_booking(p_quotation_id)` accepted-quotation→booking link (SPEC-073's deferred path). No auto lead-transition on send (lead status stays `advance_lead`'s authority; `quotation_sent` event published for future reactors). 10-assertion behavioral suite green through the real auth chain. Time-based auto-expiry (`sent→expired` when `valid_until` passes) is recordable via `advance_quotation` today; scheduled auto-expiry joins the n8n scheduled work at Phase 10. | Closed | Implemented (049500) |
| ~~**Event-requirements (`28`)**~~ — **RESOLVED** (2026-07-17, migration `202607049600`) | Verified per-RPC then fixed: the identity RPCs emitted nothing because they *predate* `app.record_event` (chronology gap, not design). Now emitted: `user_created`, `role_assigned` (severity `security`), `branch_created`, `department_created` — 044100 bodies preserved verbatim + emission only. Deliberately NOT emitted (no-guessing): `lead_created` (by-design, `044300`); branch initial-assignment (canon 27 defines only *transfer* events); `role_removed`/`permission_granted`/`permission_revoked` (no mutating RPC exists — land with their first consumer). | Closed | Implemented (049600) |
| **Booking-item roll-up never consumed** — item cost/selling + passenger overrides stored but never rolled to an item/booking total; `finance_approval_required` set but never read | `phase-05` §4 | With invoicing depth; relates to register **R3** (invoice_lines) | Within the finance/invoicing CR |
| **Finance-gated booking transitions partial** — only the execution-approval slice (SPEC-081) built; `confirmed`/`issued`/`void`/`refunded`/`reissue`/`completed` + capability set (Submit/Approve/Issue/Cancel/Refund/Reissue) still per-consumer | `phase-05`; ADR-0020 | As each booking consumer is built | Per-consumer CRs |
| ~~`chart_of_accounts.account_type` has no governing catalog~~ — **NOT A GAP (corrected 2026-07-17)**. `account_type` is **plain text by ratified decision ADR-0006** (`journal_entries.sql:9`), consistent with the canon-30 type-code convention (plain text; validity via seed + app logic; no FK mandated). Values are the standard accounting types seeded by `app.seed_default_chart_of_accounts` (asset/liability/equity/revenue/expense). Nothing to implement. | ADR-0006; `journal_entries.sql:9`; canon `30` §type-codes | Closed | None — ratified as-is |

## Recommended (evidence-backed, medium-term)

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| DB-enforced event immutability | `30` forbids updating events but nothing enforces it; a trigger/RLS blocking UPDATE/DELETE on `events`/`security_events` hardens audit integrity. | Events migration (13) or RLS (19) | Yes |
| `pg_trgm` fuzzy matching | Real duplicate-detection intent (`customer_identity_signals`, name/phone). `pg_trgm` + GIN indexes materially improve fuzzy matching. | When CRM identity/dedup is built | Yes (enable-extension step) |
| RLS sequencing confirmation | All RLS deferred to Migration 19; acceptable because `config.toml` does not auto-expose new tables. Confirm no client access to tenant tables before 19; if incremental client use is planned, enable RLS per-table instead. | Before any client integration | Decision; possibly CR |
| Disable Docker `tcp://localhost:2375` (no-TLS daemon exposure) | Enabled during a past environment repair. **Evidence (2026-07-13): no longer required** — all `docker`/`supabase`/MCP operations run over the default named pipe with no `DOCKER_HOST` set. It **fails Earn-It** (zero measurable benefit) and carries a real security cost (unauthenticated root-equivalent Docker/host control on localhost, reachable by any local process incl. `npm`/`npx` postinstall). Kept for now only to avoid changing a variable right before the comprehensive review. | **After the comprehensive ORVION review completes** — disable via Docker Desktop → Settings → General, then re-run the full environment health check. If everything works without 2375, removal permanently earns it; if something breaks, investigate the dependency before further change. | No — a config toggle + verification, not a repo CR |

## Engineering Methodology Artifacts (approved 2026-07-04)

| Item | Why it matters | Status / trigger | CR? |
| --- | --- | --- | --- |
| Architecture Decision Records (ADR) | Preserve reasoning behind major decisions for future contributors. | **Created** — `reports/architecture-decision-records.md` (seeded, ADR-0001..0010). Append a new ADR when a genuinely architectural decision is made. | No (living doc); new ADRs added inline |
| Database Naming Audit | Catch table/column/index/constraint/trigger/function/view/migration naming inconsistencies before the schema grows large. | **Recommended** — run at a milestone (e.g., after the Configuration + Core-Business tables, before the schema passes ~half of 71 tables). Findings surfaced as CRs, never silent edits. | Yes, if inconsistencies found |
| Migration Regression Checklist | Confirm each migration's tables/FKs/constraints/indexes/triggers/functions/extensions/RLS/views match both the canonical docs and the migration spec. | **Active** — already performed as the post-migration Database Audit (SPEC-024 onward). Keep applying; consider scripting it once the object count grows. | Optional (a script would be its own CR) |
| Migration Dependency Graph | Prevent accidental ordering-dependency violations. | **Partially exists** — `33_sql_migration_plan.md`'s "Depends on (#)" column is the current graph. An explicit standalone graph is a Nice-to-Have enhancement once the sequence is deep. | Nice to Have |

## Nice to Have (future optimization)

| Item | Why it matters | Trigger |
| --- | --- | --- |
| `pg_cron` scheduled jobs | OTP cleanup (Deletion Rule), subscription grace→read-only transitions, `usage_counters` rollups. | When those lifecycles are implemented |
| Declarative partitioning | High-volume tables (`events`, `conversation_messages`, `security_events`, `campaign_daily_metrics`, `attribution_clicks`) at scale. | When data volume warrants; not before real load |
| `citext`, partial indexes, generated columns | Case-insensitive emails; `document_versions WHERE is_current`; derived `full_name` as GENERATED. | Per-migration micro-optimizations |
| Impeccable (`pbakaus/impeccable`) — frontend design skill pack | Evaluated 2026-07-13 and **intentionally deferred** (not rejected). It is 100% frontend/UI tooling (typography, color, motion, visual-hierarchy critique, browser Live Mode, 44 frontend detector rules). ORVION is backend-only today (no UI surface), so an agent could not use it — it fails Earn-It *now*, not permanently. Recorded so future agents do not re-run this research. | **Trigger: the first real application UI / dashboard implementation.** Same trigger class as Playwright (`.workstation/manifest.md §4`). |

## Structural-Completeness Assessment (2026-07-17, under the Fundamental-Domain-Structure principle, `AGENTS.md §3`)

Owner directive: inevitable *domain structure* belongs in the repo now even without a consumer; only *features/infrastructure* are Earn-It-deferrable. Applying the 6-criteria test (+ the 5-year question) to every remaining structural candidate against the built schema (71 tables, 79 catalog families, all reference-code columns FK-backed). Finding: ORVION is already structurally near-complete; each remaining candidate fails at least one criterion — **not** blind-add foundational.

| Candidate | Verdict | Reason (which criterion fails) | Promotes when |
|---|---|---|---|
| Airports / airlines / cities (reference tables) | **Trigger-defer** | "Architecturally-correct *now*" fails — the validated shape (timezone/coords/ICAO/metadata) is driven by the **unbuilt flight-ticketing** feature; canon 25 §Reference Data defers on exactly this. Empty pre-creation avoids no FK-wiring migration and risks a wrong-shape one. | Flight-ticketing design (defines what airport/airline metadata must be validated) |
| First-class `invoice_lines` (+ tax lines) | **Owner decision** | Not inevitable for ORVION — current model *derives* invoice detail from linked `booking_items`; lines-as-table vs derived-detail are two valid models; tax/VAT lines are a compliance decision (ETA e-invoicing). | Owner selects the invoicing model |
| Document-number sequences (booking/invoice/quotation/receipt) | **Owner decision → then foundational** | Structure is modelable but the **format/scheme** is a business decision (SPEC-073 deferred it); uniqueness already guarded (migration 048800). | Owner sets the identifier-format policy |
| Structured address model | **Defer** | Not clearly canonical — ORVION uses `customer_contact_methods`; free-text/JSON addresses are a valid mature-SaaS choice; no evidence it's required. | Evidence a validated address is needed |
| Aircraft types, hotel chains, fare-class detail, GDS/PNR structures | **Feature-defer** | Feature-specific ticketing internals, not stable domain structure. | Their feature's design |

Rationale recorded so this is not re-litigated: the comprehensive up-front design is *why* little inevitable structure remains. Two owner decisions (invoicing model; identifier format) would each unlock foundational structure that would then be added immediately, not deferred.

---

## Strategic Direction & Future Domains (evidence-backed; guides later phases)

Forward-looking direction validated by research (2026-07). These do not change the current roadmap; they orient the later integration phases and are recorded so the direction survives without conversation history. See `PROJECT_CONTEXT.md` §11 for the vision framing (ORVION as source of truth; external platforms are consumers).

| Item | Why it matters | Trigger / when | CR? |
| --- | --- | --- | --- |
| ~~Attribution capture at lead intake (`gclid`/`gbraid`/`wbraid` + consent `ad_user_data`/`ad_personalization`)~~ — **capture side DONE (SPEC-119 / R5)** | Click IDs are unrecoverable retroactively, so the columns had to exist before Phase-8 intake. `attribution_clicks` now carries `gbraid`/`wbraid` + consent signals; `leads` carries a first-touch `attribution_click_id` anchor. | Closed 2026-07-13. **Still open (delivery side):** the outbound transport — Google's **Data Manager API** + consent mode (legacy Ads offline import blocked 2026-06-15) — is an owner decision to settle in Phase 8's first Design Challenge. | Capture: implemented (SPEC-119). Delivery: Phase-8 CR |
| Customer Communications as a first-class capability (company-owned conversations, unified inbox, assignment, transfers, internal notes, timeline, attachments) | Replaces operational dependence on employees' personal WhatsApp; the shared-inbox/collaboration layer is built on the Cloud API, not native to it. **Architectural shape deliberately UNDECIDED** — decide via a proper Design Challenge among standalone domain / CRM capability / Customer Workspace / Automation, on evidence. Design channel-agnostic (WhatsApp is one channel; email/SMS/in-app others), reusing the event backbone + Phase-7 document linkage. | **After Phase 7 (Documents)** — that provides the attachment substrate conversations reference | Yes — its own domain CR(s), preceded by Learn-Before-Designing research |
| Full Meta-ecosystem research | Before designing the communication/marketing layer: Meta Business Platform/Portfolio, WhatsApp Business Platform, Marketing API, Messenger, Instagram Messaging, Embedded Signup, System Users, App Review, Business Verification, conversation ownership, shared-inbox architecture, multi-agent messaging. Per `AGENTS.md` §3 Learn-Before-Designing. | Communication/marketing layer (Phase 10 or the Communications domain) | Research task, then design CR(s) |
| Revenue Intelligence delivery posture | Later integrations (Phase 8 Google Ads, Phase 10 Meta/analytics) are **outbound/push, ORVION-owns-the-truth**: ORVION emits verified events/values; platforms ingest. Do not build a home-grown attribution/measurement black box — deliver to each platform's ingestion API. | Phases 8 and 10 design | Within those phases' CRs |

## Group 3 architectural determinations (2026-07-17, Chief-Architect review under full delegation)

Reconstructed from implementation; each "Group 3" capability assessed for whether a full ADR is *earned now* (Earn-It / Learn-Before-Designing "study the strongest implementations at the trigger, not before") versus deferred with a trigger.

| Capability | Determination | Trigger for a full ADR |
|---|---|---|
| **FX / presentation currency** | **RESOLVED via ADR-0022** as the one isolated owner business-policy decision (per-currency default vs single presentation currency). The FX conversion primitive (`reporting.convert_amount` over the existing `exchange_rates`) is designed and additive; built only if the owner elects single-currency. | Owner selects single-currency presentation |
| **Read-model / reporting** | **RESOLVED — ADR-0022** (full architecture, implementation-ready). | Done |
| **Quotations workflow** | ~~Deferred~~ → **IMPLEMENTED** (2026-07-17, migration 049500, under delegated engineering authority — the workflow proved fully derivable from canon 26/28/31 + as-built precedent; no ADR needed, design decisions recorded in the migration header) | Done |
| **Subscription lifecycle** | Deferred by ADR-0016 ("separate future slice"). Full schema exists; lifecycle RPCs need subscription-*strategy* (owner business policy: plans, grace, billing). Phase-9 reports the *state*; it does not require the lifecycle to exist. | Subscription/billing go-live decision |
| **Communications domain** | Deferred — shape explicitly undecided; requires Meta-ecosystem Learn-Before-Designing (per PROJECT_CONTEXT). Premature to ADR now. | First customer-communications capability (post-attachment substrate, Phase 7 done) |
| **Notifications delivery** | Deferred. In-DB notifications are written (e.g., SLA); external delivery needs the outbound infra decision (Edge/n8n/pg_net) shared with Phase 8. Fold into the Phase-8 outbound-infra ADR rather than a standalone one (Anti-Entropy). | Phase 8 outbound-integration design |

Rationale: producing full ADRs for the four deferred domains now would be speculative architecture for future, business-policy-dependent capabilities off the critical path — a Learn-Before-Designing / Earn-It violation. Each is preserved with a concrete trigger so nothing is lost.

## Repository-Improvement Evaluation (2026-07-17, §5 of the Advisory-Board directive)

Every proposal evaluated against what already exists (the owner proposes; repository evidence decides). **Dominant finding: most proposals already exist under a different name** (the Master suite + SSOT matrix + guard already provide them) — adopting them again would duplicate authority (One-Authority / Anti-Entropy). A few earn a *later* trigger; almost none earn *now*.

| Proposal | Verdict | Evidence |
|---|---|---|
| Repository Health / Maturity / Phase-Readiness / Automation-Readiness **Scores** | **Reject** | Scalar "scores" are vanity metrics; `MASTER_REPOSITORY_HEALTH.md` (§17) + `MASTER_CERTIFICATION_STATUS.md` + roadmap/manifest already give richer, decision-driving state. A number adds no confidence. |
| Knowledge / Architecture / Governance / Canon / ADR **Coverage Matrices** | **Reject (duplicate)** | Already are: GOVERNANCE §2 SSOT matrix, `MASTER_COVERAGE_SCORE.md`, GOVERNANCE §5 registry, ai-map `canonical_docs`, ADR log + `MASTER_ARCHITECTURE_DECISIONS`. |
| Repository Traceability Matrix / Cross-reference Completeness | **Adopt Later → already scoped** | Covered by the consistency-guard broken-ref check + the §19 periodic orphan/lineage steward scan. No new artifact. |
| Architecture-Decision Dashboard / Repository-Health Dashboard | **Reject (exists)** | ADR log + `MASTER_ARCHITECTURE_DECISIONS`; `MASTER_REPOSITORY_HEALTH.md`. |
| Domain Dependency Matrix | **Reject (exists)** | `MASTER_ENTITY_RELATIONSHIP_MAP.md` + canon 29 relationship map. |
| Capability Dependency Graph | **Adopt Later** | `MASTER_DEPENDENCY_GRAPH.md` covers finding-deps; a capability-level graph earns it when capability count/coupling makes phase-order reasoning hard. Trigger: post-Phase-10 or on evidence. |
| Event Flow Map | **Adopt Later** | canon 27 + `MASTER_DATA_FLOW.md` define events; a concise event→consumer flow view earns it **at Phase 8** (offline-conversion consumes events). Trigger: Phase 8. |
| RPC Dependency Map | **Adopt Later** | 67 RPCs are migration-ordered + self-documenting today; a map earns it when coupling makes reasoning hard. Trigger: on evidence. |
| Dashboard contracts / per-department dashboard architecture / KPI Catalog / Widget Catalog / Dashboard Permission Matrix | **Adopt Later (UI trigger)** | Pure frontend concerns; ORVION has no UI. The Phase-9 `reporting` views already are the data contracts; RBAC + RLS already gate access. Trigger: first dashboard/frontend implementation (same trigger class as the deferred frontend design pack). |
| ~~**Permanent Integration Catalog**~~ — **DONE** (seeded 2026-07-17 at its trigger) | Implemented | `reports/master/MASTER_INTEGRATION_CATALOG.md` (Living Master; GOVERNANCE §2 SSOT row, v1.9): registry (Google/Meta/WhatsApp/GTM rows), the build-ready n8n workflow contract for Google delivery, and the owner-exclusive setup checklist — reduces Phase 8's owner dependency to credentials only. |

Net: **1 near-term adopt (Integration Catalog, trigger Phase 8), ~6 UI/scale-triggered defers, the rest rejected as duplicates of the existing Master suite.** This is Earn-It doing its job against governance bloat — the owner proposed, the evidence decided.

### Living-Repository philosophy evaluation (2026-07-17, owner directive §4; extends the GOVERNANCE §19 knowledge-graph determination)

Principles extracted (not tools) and judged against what ORVION already does:

| Philosophy | Principle extracted | Verdict |
|---|---|---|
| Docs-as-Code | docs versioned with code, reviewed, CI-validated | **Already embodied** — everything is markdown in git, guarded by the consistency CI |
| Living Documentation | generate docs from implementation evidence; hand-written docs decay | **Adopt (already begun)** — `repository-index.md` + `ai-map.json` are generated; standing rule: whenever a doc's content is mechanically derivable from implementation, prefer extending the generators/guard over hand-maintenance (GOVERNANCE §11 owns the automation list) |
| Backstage (software catalog) | one registry of components/APIs/owners | **Reject as tool; principle already present** — GOVERNANCE §5 registry + Master suite are the catalog; a platform would duplicate authority |
| C4 model | hierarchical architecture diagrams | **Adopt Later** — earns it at the first *service topology* (n8n workflows + Edge + portals); today one database = trivial C1–C3. Trigger: Phase 10 / first multi-service deployment |
| ADR automation | decisions captured at the moment of change, template-enforced | **Already embodied** — ADR log + §15 lifecycle + guard class-header check |
| Zettelkasten / knowledge graphs | atomic notes, stable IDs, backlinks, orphan detection | **Determined in GOVERNANCE §19** — principles largely embodied; tooling layer rejected; orphan scan adopted as periodic steward review |
| Event/Integration catalogs | one home per event/integration contract | **Event catalog already canonical (`27`)**; Integration Catalog Adopt-Later (trigger: Phase 8 lands — seed with ADR-0023) |
| "Repository shrinks over time" | retire > accumulate; every artifact re-earns its place | **Already law** — Retention Earn-It (GOVERNANCE §18) + Living-Documents-first (§4); the enforcement is the existing review cadences, not a new mechanism |

Net: the living-repository goal is **already ORVION's operating model**; the two genuine deltas are recorded above (generate-over-hand-write preference; C4 at service-topology trigger). No new tooling earned.

### 10-year Enterprise Architecture Review (2026-07-17, pre-Phase-8; owner directive)

Reviewed all 19 axes against the clarified digital-operating-system vision. **Verdict: the architecture satisfies the vision** (evidence: this session's verified findings — 71 tables/79 catalogs anticipate communications/marketing/departments; ADR-0022 reporting surface is the shared truth for all future dashboards; ADR-0023 outbox is channel-generic for Google/Meta/WhatsApp; RLS 71/71 + capability-driven permissions; append-only audit; self-describing repo for AI agents). Deltas found and classified:

| Finding | Verdict | Disposition |
|---|---|---|
| Events lacked a monotonic consumer cursor (uuid+created_at only) — automation consumers need a stable watermark | **Adopt Now — DONE** | Migration `049000`: `seq bigint identity` + indexes on `events`/`security_events` (empty-table window; a later rewrite on a populated event log would be expensive). Canon 31 synced. |
| Generic automation event-feed (claim/cursor RPC over `events` for n8n subscribers) | **Adopt Later** | The Phase-8 conversion outbox is the first consumer and defines the shape; generalize at the **second** n8n workflow needing events (Rule-of-Three/Earn-It). `seq` (above) makes it purely additive — no schema change will be needed. |
| Runtime AI-agent access model (AI agents as operational actors, not dev agents) | **Adopt Later** | Natural interface already exists (RPC surface + events + RLS); a dedicated agent-role/permission model earns an ADR at the first AI-agent capability. |
| Inbound webhook ingestion boundary (WhatsApp/Meta/GTM → n8n → ORVION) | **Already anticipated** | `create_lead(p_source_payload jsonb)` + `external_conversation_id` + `attribution_clicks` are the landing structures; the capture RPCs are Phase-8/10 feature work, not missing structure. |

Next-step determination: **Phase 8 remains the objectively highest-value step** — it is also the first end-to-end exercise of the integration pattern (outbox + n8n + consent) every later platform reuses, i.e. it validates the 10-year architecture with the least new surface.

### Foundational-completeness & governance-conflict scan (2026-07-17, documents-serve-ORVION directive)

| Item | Verdict | Evidence |
|---|---|---|
| HR / payroll / leave domain | **Owner decision (isolated, non-blocking)** | `PROJECT_CONTEXT.md §12` currently declares "ORVION is not an HR System" — a boundary only the owner may move (product identity = business policy). NOTE: the administrative *skeleton already exists* (users/branches/departments/tasks/`branch_business_hours`/`holidays`/`company_assets`), so employee-as-operational-actor needs nothing new; full HR (payroll/contracts/leave) would be a product-scope expansion. If the owner elects it, it becomes Fundamental-Domain-Structure and its canon doc + tables are modeled then. |
| Administration / org-management / branch-management structures | **Already present** | branches, departments, assignments, transfer events, business hours, holidays, company assets — verified in migrations. |
| Additional travel reference structures | **Unchanged verdicts** | see the Structural-Completeness Assessment above (feature-model-dependent; trigger recorded). |
| Governance conflicts found | **One (resolved) + one boundary note** | (a) Deprecated tombstones (`codex.md`, `SYSTEM_PROMPT.md`) conflicted with the shrink-over-time law → retired 2026-07-17 (first application of the §15 supremacy clause; ai-map 39→37; guard exclusion cleared; `PROJECT_CONTEXT §13` citation cleaned). (b) The §12 not-HR boundary vs the owner's completeness directive is *not* a governance defect — it is the isolated owner decision above. No duplicated/contradictory rules found otherwise (One-Authority scan clean). |
| New MCP servers / skills / tooling | **No change earned now** | Postgres MCP already connected; tooling adoption already owned by GOVERNANCE §11 + `.workstation/manifest.md` (Earn-It-gated). Re-evaluate per §11 when a concrete need appears (e.g., an n8n MCP at Phase-8 workflow build). |

### First-Principles Assumption Review (2026-07-17 — falsification attempted, not defended)

Load-bearing assumptions attacked; verdicts recorded so future sessions inherit the *tested* state. Two previously **invisible** assumptions promoted to visible-and-intentional:

| Assumption | Falsification attempt | Verdict |
|---|---|---|
| **"Postgres is the platform"** (queue=deliveries table, workflow state=tables, event store=events, cache=aggregates) — the deepest invisible assumption | At high volume: hot events table, outbox polling limits, single-region ceiling; cell-based sharding is expensive to retrofit | **SURVIVES — now visible & intentional.** ADR-0014/0018/0023 each carry explicit escalation triggers (queues/retry/high-volume → dedicated infra); `tenant_id`-everywhere makes future tenant-sharding feasible (tenant is the natural shard key). Not silently permanent anymore: it is a *decided* posture with recorded exits. |
| **State-first, events-as-audit** (tables are truth; events are milestones for audit/integration — ORVION is deliberately NOT event-sourced) | Should a "revenue intelligence" platform be event-sourced for temporal reconstruction? | **SURVIVES.** Event sourcing would trade relational clarity + RLS simplicity for replay complexity no current requirement needs; the append-only `events`+`seq` log already gives integrations and audit what ES would, without making it the write path. Deliberate, now stated. |
| Shared-schema multi-tenancy via RLS (ADR-0003) | Noisy neighbors, RLS overhead, compliance isolation demands | Survives for the real tenant scale (tens→hundreds of agencies); 2026 consensus for this class; sharding path preserved via tenant_id. |
| Per-tenant customer identity (no cross-tenant person graph) | A global traveler identity could serve dedup across agencies | Survives *because* tenants are competitors — cross-tenant identity would be a privacy/compliance liability, not a feature. |
| Phone-centric identity signals (Egyptian market) | Email-first is the Western default | Survives — evidence-based for the market (WhatsApp/phone-first sales reality, PROJECT_CONTEXT §13). |
| DB-centric testing (smoke + behavioral + pgTAP; no app-layer pyramid) | Insufficient once app servers exist | Survives *while logic lives in the database* (it all does); escalation = first out-of-DB service. |
| Serialized engineering (one Active CR, single manifest pointer) | Parallel agents would conflict | Survives as a deliberate §6 choice (one-task-at-a-time); revisit only if the owner runs concurrent agents. |
| Problem definition itself (close the verified-revenue loop; replace personal-tool operations) | — | Owner-domain; grounded in stated business pain, not engineering guess. Not an engineering assumption to falsify. |

**No assumption failed.** The review's value: the two invisible assumptions are now explicit with recorded exits — which is exactly what prevents them becoming tomorrow's constraints.

### Meta-architecture hypothesis verdicts (2026-07-17)

| Hypothesis | Verdict | Evidence |
|---|---|---|
| Remaining opportunities are meta-architectural (improve ORVION's ability to improve itself) | **Direction CONFIRMED; timing implication REJECTED** | Confirmed: this session's highest-leverage artifacts were meta (guard Checks 6–7, verify-first boot, generated ai-map, canon-generated event registry). Rejected as *next step*: the meta-layer is now strong while exactly one founding business loop (Phase 8) remains unclosed with zero production users — further meta-investment is below the marginal value of the feature loop, and a repo optimizing its self-improvement ahead of its purpose is the failure mode `AGENTS §1(4)` (execution focus) exists to prevent. Meta-improvements continue *through* implementation (discovery-to-guard), not instead of it. |
| Automate "is there a demonstrably better design?" (quality validation, not just correctness) | **Reject as automation; keep as judgment cadence** | No current mechanism can detect "a better design exists" without either ceremony or false confidence — it would violate the guard's precision-over-recall law (crying wolf teaches agents to ignore guards). This question is already owned, as judgment, by Learn-Before-Designing + the Design Challenge + Retention Earn-It cadences. Re-evaluate if future tooling makes design-diff genuinely mechanical (§11 owns adoption). |
| Reduce owner confirmations for researched/challenged/verified technical improvements | **Already law — no governance change needed** | The decision-classification framework (`AGENTS §1`, crystallized 2026-07-17) already makes technical/architectural decisions autonomous (decide, document, continue) and reserves the owner for product identity/business policy/irreversibles. Precedent: ADR-0022 and the Group-2 canon amendments were issued autonomously under it this same day. The remaining owner-gates (canon changes touching product identity, new business-policy ADRs, roadmap resequencing, irreversibles) all protect product identity — none is historical caution. Verified rule-by-rule; nothing to evolve. |

### Owner-hypothesis verdicts (2026-07-17, Learn→…→Institutionalize cycle review)

| Hypothesis | Verdict | Evidence |
|---|---|---|
| The proposed 6-step cycle (Learn/Exploit/Challenge/Implement/Verify/Institutionalize) should become governance | **Reject as NEW governance — it already IS governance under its existing names** | 1:1 mapping: Learn = `AGENTS §3` step 2 (Learn-Before-Designing, deliberately *scaled to the decision*, not mandatory-per-unit — mandatory full research per routine unit would be the ceremony §1/§8 forbid); Exploit = Phase-fit + Earn-It (step 1); Challenge = Design Challenge (step 4); Implement = step 5; Verify = Test-before-trust + Review Gate (steps 5–6, `§2`); Institutionalize = discovery-to-guard (`GOVERNANCE §18`) + governance-before-execution (`§19`). Adding a second vocabulary for the same stages would be duplicate authority (`§6.8`). The convergence itself is the proof the operating model is sound. |
| H1 — remaining opportunities are misplaced responsibilities, not missing tables | **Partially disproven (today)** | Placement scan clean: RPC/schema/catalog/canon ownership verified sound this session; the one real misplacement class found was *vocabulary* drift (canon 27 vs emitted codes) — found and fixed (mig 049100). Keep the lens; no current action. |
| H2 — next improvements come from relationships/contracts, not objects | **Confirmed by evidence** | This session's material wins were all contract-level: event cursor (049000), event-type registry (049100), outbox claim/ack boundary (ADR-0023), roadmap↔manifest guard. Already the operating bias. |
| H3 — prepare future capabilities structurally without their behavior | **Already law** | = Fundamental-Domain-Structure (`AGENTS §3`), with its exclusion clause (shape-dependent structures wait for their design — applied to HR below and to airports). |
| H4 — governance should become self-validating/generated/measurable | **Confirmed; partially built; extensions owned by §11** | the consistency guard = self-validating (its checks are enumerated in `MASTER_REPOSITORY_HEALTH.md §2b`; the count is not restated here — it read "7-check" while the guard carried 17, GOV-5); ai-map/repository-index = generated; `MASTER_REPOSITORY_HEALTH` = measurable. Remaining automation items stay in GOVERNANCE §11 (owner-gated CI/config), not a new mechanism. |
| HR foundational structures now (boundary revised by owner) | **Boundary synced; structures deferred with trigger** | `PROJECT_CONTEXT §12` amended (HR = planned future domain, owner 2026-07-17); HR row added to the canon-32 capability queue. No tables now: the org skeleton already exists, and the employee-vs-membership identity split — the core HR decision — must come from the HR Design Challenge, or we'd guess the most consequential shape (same logic that correctly deferred airports). |

## How items enter and leave this backlog

1. A review or migration surfaces an improvement not justified for immediate implementation.
2. It is added here with a classification, a why, and a trigger — evidence required.
3. When its trigger is reached and evidence justifies it, it becomes a Finding and then its own Change Request.
4. On completion, it is removed from this backlog (git history preserves the record).
