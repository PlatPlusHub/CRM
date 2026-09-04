# ORVION — Batch 6 reconnaissance: the first remaining unfinished slice

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: Discovery complete — **no implementation performed, and none is authorized by this report.**

**Scope:** identify, from `MASTER_EXECUTION_PLAN.md` alone, the first Batch-6 slice that is genuinely unfinished, and reconnoitre it. Selection was made from the plan, **not from memory and not from what seemed logical**. Measurements ran against a freshly reset local database at proven structural parity with Primary. **Primary was read-only. No migration was written. No business policy was invented.**

---

## A. WHAT THE PLAN AUTHORITATIVELY SAYS IS NEXT

`MASTER_EXECUTION_PLAN.md` carries exactly one live pointer:

> **NEXT SLICE: the remaining Batch-6 tables** — the table-by-table audit below still owns the order. The write-without-read class is now closed on all five of its columns, and the five classes above are measured rather than assumed; **a next slice needs a class none of them covers.**

The slice it points into is **PHASE C CONTINUED — the table-by-table audit**:

| Field | Plan's own words |
|---|---|
| Why it exists | every package so far found defects beside the one it was chartered for; the remaining surface has never been swept as a whole |
| Discovery source | the standing owner directive |
| Scope | all tables and relationships — schema, FKs, RLS, grants, functions, SECURITY DEFINER, triggers, catalogs, permissions, events + producers/consumers, reporting views, scheduled jobs, integrations, RPCs, direct-DML surfaces, test families, governance — inspected for **behavioural** consistency, not existence. Plus journey branches not yet walked over HTTP |
| Non-goals | inventing features to give registered vocabulary a producer; adding reports because mature CRMs have them |
| Acceptance | every finding classified PROVEN / UNPROVEN / FAILED / BLOCKED; if an engineering defect, fixed |
| Test criteria | each fix carries positive and negative controls plus direct-DML / RPC / system / cross-tenant paths |
| Deployment | migrations to Primary, parity re-proven, PostgREST cache reloaded when the surface changes |

**The plan does NOT authorize implementation of a specific fix.** It authorizes a *discovery method*: rank the surface, attack the ranking, and let the measurement choose the subject.

---

## B. THE CONSTRAINT — CLASSES ALREADY MEASURED CLEAN

A next slice must attack a class none of these covers. Five were recorded by SUP-2's discovery pass (`e33de54`):

| # | Class | Recorded result |
|---|---|---|
| 1 | Direct `DELETE` authority | `authenticated` holds **zero** DELETE on all tables |
| 2 | A granted command with no RLS policy | zero |
| 3 | `SECURITY DEFINER` hygiene | all 24 reachable by `authenticated` pin `search_path=""`; none executable by `anon` |
| 4 | Archive authority | every table with `is_archived` carries `enforce_archive_authority` |
| 5 | Reporting views as a read-door | all 8 `security_invoker`; none exposes a withheld column |

Plus **write-without-read**, closed on all five of its columns (SUP-2 / SUP-3 / SUP-4a).

### Two further classes measured clean this session (new, recorded so they are not re-swept)

| # | Class | Measured result | Verdict |
|---|---|---|---|
| 6 | **Tenant-composite FK completeness (TENANT-1)** | **195 of 195** intra-tenant foreign keys carry `tenant_id` in the key; **zero** exceptions | **Clean** — not a slice |
| 7 | **RLS forced vs merely enabled** | RLS enabled on **76 of 76** public tables; `FORCE` set on **zero** — uniform, i.e. the platform default, not drift. Already hashed by `parity_surface.sql`, so a change would be caught. ORVION's SECURITY DEFINER paths depend on owner-bypass semantics; forcing it would break them | **By design — do NOT change.** Recorded so the uniform zero is never mistaken for a finding |

---

## C. THE CLASS THAT IS *NOT* COVERED — AND THE CANDIDATE SLICE

### Detector: a capability granted to `authenticated` in `app`, with no `public` wrapper

PostgREST serves **only** `public`. This is the **RBAC-6 class**, and RBAC-6 fixed exactly one instance (`effective_permissions`, `202607060000`). The class itself was never swept.

**Measured on the fresh local database:**

| Metric | Value |
|---|---|
| `app.*` functions executable by `authenticated` | **102** |
| `public.*` functions executable by `authenticated` | 74 |
| **`app.*` with no `public` wrapper of the same name** | **29** |

**29 is a raw count, not 29 defects.** Triage against what each function is:

**(i) Must stay unreachable — internal authorization, scoping and helper surface (25).**
`authorize` · `has_permission` · `has_tenant_wide_read` · `mfa_satisfied` · `requires_mfa` · `plan_allows` · `plan_limit` · `current_tenant_id` · `current_user_id` · `visible_branch_ids` · `visible_department_ids` · `is_my_booking_item` · `is_document_responsible` · `subscription_allows_write` · `require_lead_handler` · `record_event` · `eligible_lead_handlers` · `is_financial_document_type` · `subscription_transition_allowed` · `sub_status_family` · `commission_rate_default` · `document_bucket` · `document_storage_path` · `normalize_email` · `normalize_phone`

Exposing any of these would **add** attack surface. `app.has_permission` is explicitly documented as a deliberate non-door — an arbitrary-key probe oracle — and `verify_api_end_to_end.ps1` asserts its absence. **No action. This is the correct state.**

**(ii) Business accessors with no public door — the actual candidate set (4).**

| Function | Security | Why it is a candidate |
|---|---|---|
| `app.item_financials(p_booking_item_id)` | DEFINER | **The strongest candidate.** `booking_items.cost_amount` and `commission_rate` are in the write-without-read set — `authenticated` cannot SELECT them. SUP-2's analysis established that the read-back path is `app.item_financials`, which grants the read on `VIEW_FINANCIAL_DOCUMENTS` **or ownership of the item**, so the salesperson who entered a cost can read it back. If that function has no `public` wrapper, **that read-back path does not exist over HTTP** — the exact shape of RBAC-6 |
| `app.customer_balance(p_customer_id, p_booking_id)` | INVOKER | ADR-0021 makes customer balance a derived, per-currency, read-only primitive. A primitive no client can call is a primitive with no consumer |
| `app.supplier_balance(p_supplier_id, p_booking_id)` | DEFINER | Its sibling `public.supplier_credit(p_supplier_id)` **does** have a wrapper; this one does not. The asymmetry is unexplained by anything found |
| `app.booking_item_profit(p_booking_id, p_booking_item_id)` | INVOKER | same family as `item_financials` |

Confirmed by measurement that **no differently-named public wrapper exists** for any of the four: the public surface matching balance/financial/profit/credit/capability/item is `financial_documents`, `supplier_credit`, `tenant_capabilities`, and four booking-item **mutators** — none of which is a read door for these values.

**This class is covered by none of classes 1–7.** It is the recommended slice subject.

---

## D. WHAT THIS REPORT DOES *NOT* CLAIM

Per `AGENTS.md §5a` evidence classes, stated so nothing is over-read:

- The four candidates are **UNPROVEN as defects.** Evidence class is **LOCAL RUNTIME + STATIC** (catalog introspection on a reset local database). **No HTTP probe was run against them**, and RBAC-6's own lesson is that only HTTP proves the browser-facing door.
- **The correct first act of the slice is therefore an HTTP measurement, not a migration:** call each of the four as a real role over PostgREST and record the status code. A 404 confirms unreachability; anything else kills the hypothesis.
- Three of the four may prove to be **PROVEN INTENTIONAL** — a value with no client consumer is not automatically a defect, and `AGENTS.md §3` non-goals forbid inventing a consumer to justify a wrapper. `item_financials` is the one with a concrete, already-documented consumer story.
- **No count here should be quoted as a defect count.** 29 is a surface measurement; 4 is a candidate set; 0 are proven defects.

---

## E. DEPENDENCIES, RISKS, BLOCKERS

| Axis | Finding |
|---|---|
| Schema / data dependencies | None. A wrapper adds no table, column or constraint |
| Authorization dependencies | **Critical and non-negotiable:** a wrapper must be `SECURITY INVOKER` with `search_path` pinned, per API-1's model, so the underlying DEFINER function's own gate remains the decision point. It must not widen who may read — RBAC-6's wrapper was proven in both directions including the empty-set-is-authorization control |
| Governance dependencies | `MASTER_API_CONTRACT.md` is **auto-generated** — regenerate, never hand-edit (Check L3 diffs it). Endpoint count in `53_api_surface_test.sql` must move with any new endpoint |
| Test dependencies | `53_api_surface_test.sql` pins the endpoint set at 77; `verify_api_end_to_end.ps1` asserts `has_permission` stays unreachable — that assertion must survive untouched |
| Risk | **Exposing a read that was previously unreachable is a privilege-surface change.** Each wrapper needs positive AND negative controls proving it confers nothing new |
| Blockers | **None technical.** |
| Business decisions required | **None for this slice** — reachability of an already-authorized read is derivable, not commercial. **SUP-4b is NOT part of it and remains an untouched owner decision** |
| Engineering decisions required | One per candidate: *is this value meant to have a client consumer at all?* Answerable from canon + ADRs + consumers, and must be answered **before** any wrapper is written |

---

## F. A PLAN STATEMENT THAT NO LONGER MATCHES REALITY

Recorded, not silently corrected — the plan's Phase C scope says the slice includes *"the journey branches not yet walked over HTTP: refund, cancellation, complaint, service request, supplier payment, finance approvals, conversations, tasks."*

**Measured: all eight now have HTTP coverage.**

| Branch | Suites covering it |
|---|---|
| refund · cancellation · service request | `verify_journey_branches`, `verify_lifecycle_branches` |
| complaint · conversations | `verify_care_journeys`, `verify_journey_branches` |
| finance approvals | `verify_journey_branches`, `verify_lifecycle_branches` |
| supplier payment | `verify_journey_branches` |
| tasks | `verify_api_end_to_end`, `verify_journey_branches`, `verify_lifecycle_branches` |

All six suites executed green this session (**414 assertions, 0 failed**). That half of the Phase C scope statement is **stale**. It is reported here rather than edited, because deciding whether "walked" means "any assertion touches it" or "the branch is walked end-to-end" is a scoping judgement the plan's owner should make — the sub-branch depth was **not** audited and this report does not claim it.

---

## G. RECOMMENDED IMPLEMENTATION BOUNDARY (for a future session — not authorized here)

1. **Measure first over HTTP.** Probe all four candidates as a real role. Record status codes. Kill any hypothesis the probe kills.
2. **Answer the consumer question per candidate** from canon, ADRs and existing clients — before writing anything.
3. **Wrap only what survives both**, following API-1's model exactly (`SECURITY INVOKER`, pinned `search_path`, `REVOKE` from `PUBLIC`, `GRANT` to `authenticated`).
4. **Prove in both directions**, including the empty-set-is-authorization control, on both doors.
5. **Regenerate** the API contract and `ai-map.json`; update the endpoint pin in `53_api_surface_test.sql`; re-run `§5a` end to end.
6. **Out of scope:** SUP-4b, any new permission, any new table, and any wrapper for the 25 internal helpers.

**Expected size:** one migration, one to four wrappers, ~10–15 assertions. Comparable to `202607060000` (RBAC-6), which is the precedent to copy.

---

## H. STATUS

**Batch 6 is NOT started.** This report is reconnaissance only. `MASTER_EXECUTION_PLAN.md` authorizes the table-by-table audit's *method*, and the method's next step is an HTTP measurement — **not** a migration.

**The one decision that gates implementation:** for each of the four accessors, is the value meant to have a client consumer? That is an engineering question answerable from the repository, and it must be answered before code is written. No owner/business decision is required for this slice; **SUP-4b remains open and untouched.**
