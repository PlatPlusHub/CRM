# ORVION MASTER ARCHITECTURE DECISIONS (ARB overlay)

Status: **Permanent cumulative decision ledger.** Never recreate; evolve. This is the ARB's decision-tracking overlay; the **authoritative ADR log remains `architecture-decision-records.md`**. This file tracks: (a) accepted ADRs and any ARB-proposed amendments, and (b) decisions the ARB proposes but the **owner has not yet ratified** (proposed ADRs must be recorded per the owner policy — design is not withheld). No canonical/ADR file is modified until the owner approves.

Last updated: 2026-08-10 (Decision-reconciliation pass — corrected item 11 (A3)'s stale ADR-0022 reference to sequential-at-ratification numbering; superseded item 15 (DC-15) with the verified per-class least-privilege model. No ADR ratified, no grant/role/RPC/RLS changed; both remain tracked proposals awaiting owner ratification. Prior 2026-07-15 annotation of item 11 preserved above, not deleted).

## A. Accepted ADRs (authoritative in `architecture-decision-records.md`) — ARB status
| ADR | Title | ARB verdict |
|---|---|---|
| 0001 | PostgreSQL on Supabase | Reaffirmed |
| 0002 | UUIDv4 `gen_random_uuid()` PKs | **Reaffirmed (session 4).** DC-13 UUIDv7 amendment **DEFERRED** — evidence: v4 fine <millions of rows, native uuidv7 is PG18 (Supabase=PG17). Trigger recorded. |
| 0003 | Shared-schema multi-tenancy + RLS | Reaffirmed (V1 verified dynamic-loop coverage) |
| 0004 | `users`↔`auth.users` via auth_user_id | Reaffirmed |
| 0005 | Catalog lookups over enums | Reaffirmed |
| 0006 | Status/type codes plain text | **Tighten (N1):** require event_type registry validation for contract-bearing codes |
| 0007 | FK default restrict/no-action | Reaffirmed |
| 0008 | updated_at via moddatetime trigger | Reaffirmed |
| 0009 | Direct-to-main, publish on Complete | Reaffirmed (governs additive-migration rule) |
| 0010 | Reference data natural keys | Reaffirmed |
| 0011 | users = tenant membership | Reaffirmed |
| 0012 | Auth artifacts re-home to human identity | Reaffirmed |
| 0013 | Tenant isolation principles / single RLS primitive | Reaffirmed (**strengthened** by C1 group-as-read-path) |
| 0014 | Supabase-native backend | Reaffirmed (DC-2/3/5/8/15 realizable without a service) |
| 0015 | Binary role_permissions (Earn-It) | Reaffirmed (+N2 permission×feature composition) |
| 0016 | Platform-mediated provisioning | Reaffirmed (+DC-10 opening balances, DC-14 offboarding extend lifecycle) |
| 0017 | Supabase-native authentication | Reaffirmed |
| 0018 | Scheduler-agnostic background processing | Reaffirmed (hosts DC-8 reconciliation, DC-7 ticketing sweeps) |
| 0019 | Customer-merge dynamic FK discovery | Reaffirmed (extend to party-merge under CDD-1) |
| 0020 | Finance-approval gate; capability-driven booking perms | Reaffirmed |
| 0021 | Derived customer_balance primitive | **Amend (INV-1..4):** contract-stable, source-evolving; conditional on DC-1 money fix |
| 0024 | Every RPC rule must also hold on the table door | **New (2026-08-31)** — ratifies the Foundation programme's enforcement rule; superseded if SEC-1 revokes direct table DML |
| 0025 | Enforcement layer chosen from the measured surface; session-less exemption for authorization only | **New (2026-08-31)** — resolves the "LESSON 6" citation that had no defined home |
| 0026 | Scoped access is a predicate, never a coarser grant | **New (2026-08-31)** — owner decision SPEC-154-B; mechanism derived from SPEC-139 `app.item_financials` |

## B. Proposed ADRs — awaiting owner ratification (design recorded, not withheld)
Consolidated set (from Baseline/Physical/Synthesis §9, confirmed by ARB):
1. **Party/Account model** (CDD-1) — unified parties + roles; customers/suppliers projections.
2. **Product/Packaging/Inventory + Supplier contracts** (CDD-2).
3. **Pricing & Tax** (CDD-3/4) — price-components + tax_codes + TOMS margin scheme.
4. **Accounting foundation** (CDD-5) — dimensions-as-projection, subledger auto-posting, periods, AP bills, treasury, revaluation, document_sequences; **incorporates INV-1..4 + DC-10 opening balances + DC-11 realized FX**.
5. **Tenant hierarchy / Franchise** (CDD-9) — consolidation read path, not an isolation change (C1).
6. **Integration Layer + selective Transactional Outbox** (CDD-7) — providers/connections/outbox/webhook-inbox; secrets in Vault (C2 selective).
7. **Event contract + event_type registry** (CDD-8/N1) — versioned/correlated events; RI/AI consumers.
8. **Customer Engagement** (CDD-10) — omnichannel conversations/templates + **single consent model (N5)**.
9. **Subscription two-plane + feature flags** — platform-billing vs operations-billing; `has_feature`; **permission×feature (N2)**.
10. **Localization** (CDD-11).

ARB-added proposed decisions (new this session):
11. **Money-storage standard** (DC-1) — `numeric(19,4)`; rounding driven by `currencies.decimal_places`. **⚠️ IMPLEMENTED via SPEC-118** (migration `202607048600`, canon `30`/`31` updated) **without a formal ADR recorded.** Open owner/ADR-process decision (A3): does the money-storage standard warrant a ratified ADR, or is the canon-30/31 convention update sufficient? **Number correction (2026-08-10): the ADR log (`architecture-decision-records.md`) now runs ADR-0001–0023 with no gaps; A3 does not pre-reserve a number — whichever proposed ADR (A3, or DC-27 below) is ratified first receives the next sequential number at that time, and the other receives the number after it.** Still flagged, not decided.
12. **Write-idempotency standard** (DC-2) — idempotency-key table + optional RPC param on all mutating RPCs.
13. **Concurrency-control standard** (DC-3) — `FOR UPDATE`/advisory locks for oversell-risk RPCs; optimistic guard for concurrent edits.
14. **Data-lifecycle & privacy** (DC-4/DC-6/DC-14) — pseudonymization erasure boundary; sensitive-read log; tenant export/purge.
15. **service_role least-privilege** (DC-15) — **superseded 2026-08-10 by a verified per-class model** (a blanket "every privileged function takes an explicit tenant assertion" rule was disproven by inventorying all 13 current `SECURITY DEFINER`/`service_role`-only/integration-role-only functions across `supabase/migrations/**`; 5 of the 13 are deliberately cross-tenant by job description and would violate a blanket rule). Every current privileged function falls into exactly one of four classes:
    - **Caller-tenant-scoped** (`current_tenant_id`, `my_memberships`, `has_permission`, `activate_membership`, `requires_mfa`, `mfa_satisfied`, `merge_customer_identity`) — resolves tenant only via `app.current_tenant_id()`/`auth.uid()`; `SECURITY DEFINER` is used to escape RLS self-reference or (for `merge_customer_identity`) to guarantee completeness of an already same-tenant-verified sweep, never to reach across tenants. Standard: must never accept a caller-supplied tenant parameter for scoping; grant target is never `public`/`anon`.
    - **Explicit-tenant integration path** (`capture_attribution_click`) — takes an explicit `p_tenant_id` argument and validates it exists before any write. Standard: the tenant argument is mandatory and validated; grant target is the specific integration role only.
    - **Controlled cross-tenant system job** (`process_lead_sla`; `claim_conversion_deliveries`, `record_conversion_delivery_result`, `map_outcomes_to_conversions`) — no tenant parameter, cross-tenant by design (a scheduled sweep or a batched outbox worker), restricted to `service_role` or a dedicated non-login integration role. Standard: grant target must never be `authenticated`/`public`/`anon`; the job's cross-tenant read is justified by its documented trigger (a `pg_cron` entry or an Integration Catalog row).
    - **Platform provisioning/administration** (`provision_tenant`) — creates tenant context itself; grant target must be exactly `service_role`.

    Mechanically testable per class: the grant-target restriction (candidate pgTAP guard, not yet built). Not mechanically testable generically: whether an explicit-tenant function's body actually validates its tenant argument, and whether a cross-tenant job is backed by a documented trigger — these remain code-review checklist items, not automated invariants, to avoid the false-precision risk already seen with brittle regex guards (SPEC-120).

    **Status: Adopt-Now as a design/ADR-content decision only.** No grants, roles, RPC bodies, or RLS policies changed. Not yet a ratified ADR — owner ratification still required to promote this from tracked-proposal to `architecture-decision-records.md`.
16. **Test-assurance standard** (DC-16) — pgTAP regression + invariant tests as a merge gate.

## C. Decision-making rule (standing)
Every genuinely architectural decision → a new ADR appended to `architecture-decision-records.md` (owner-ratified) AND its ARB status tracked here. Amendments supersede by pointer, never delete (ADR convention). Proposed ADRs remain in §B until ratified or rejected; a rejected ADR is recorded as Rejected with reasoning, never erased.
