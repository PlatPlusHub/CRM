# ORVION Foundation Review Findings — 2026-08-24

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Author: Claude Opus 5
Source: Foundation Completion, Security Scope & CRM Readiness Programme (owner directive 2026-08-24)
Scope of evidence: only work performed in that session. Local database only — see §7.

---

## 1. Findings & Observations

| # | Finding | Why it matters | Status |
| --- | --- | --- | --- |
| F1 | All 76 RLS policies resolved to `tenant_id` alone. 14 `VIEW_*` permissions were seeded, granted to roles, and enforced nowhere | A trainee could read every lead, booking, quotation, conversation, complaint and invoice in the tenant | **Already known** (AUDIT-3) |
| F2 | `authenticated` held INSERT/UPDATE on `user_role_assignments`, whose only policy was the tenant check. One INSERT of an owner-role row for your own user id made you an owner | Defeats every permission check in ORVION, including the read model built in the same session. Distinct in kind from SEC-1: a write that changes *who the caller is* | **NEWLY DISCOVERED** (found by challenging SPEC-137) |
| F3 | `booking_items.cost_amount` and `commission_rate` were readable by anyone who could read the row; `reporting.booking_item_profit` (a `security_invoker` view granted to `authenticated`) served cost and profit directly. Canon 31 records `commission_rate` as the sales-commission basis | One employee's earnings visible to another. Made sharper, not softer, by department continuity | **NEWLY DISCOVERED** in this form (owner named the requirement; the live view was the vector) |
| F4 | No lead reassignment RPC existed. `app.assign_lead` rejects non-`new` leads with "use reassignment", pointing at a path never written. `REASSIGN_LEAD` was seeded, granted to 4 roles, enforced nowhere | The only handover path was a direct `UPDATE` of `leads.assigned_user_id`, which writes no history — every handover erased the first employee. Canon 04 requires "Preserve the original assignee in lead history" | **NEWLY DISCOVERED** |
| F5 | `lead_assignments` had no triggers while `authenticated` holds UPDATE | A history row could be rewritten to name a different employee — worse than deletion, leaving a plausible timeline that is false. Canon 04: "No assignment history may be deleted" | **NEWLY DISCOVERED** |
| F6 | `app.create_customer` filled `first_registered_branch_id` from an optional parameter defaulting to NULL; no column existed for the employee | Canon 03 requires the first-registering branch be recorded; it was recorded only when a caller happened to pass it | **NEWLY DISCOVERED** |
| F7 | `feature_entitlements` had **zero rows and no reader** — no function in `app` or `reporting` references it | Canon 28 states "Plan denial overrides user role permission"; canon 09/17 define the matrix in full. Plans were seeded; what each plan grants was not | **NEWLY DISCOVERED** |
| F8 | Every duplicate rule existed only inside an RPC as check-then-insert, with no index behind it | Two holes: a direct PostgREST write skips the RPC, and two concurrent calls both pass the SELECT before either INSERTs. Canon 05 requires the customer primary phone be unique in-company | **NEWLY DISCOVERED** as a systematic pattern |
| F9 | `attribution_clicks` had no dedupe on gclid/gbraid/wbraid; `app.capture_attribution_click` inserts unconditionally | `app.map_outcomes_to_conversions` joins leads to their attribution click, so a replayed tag fire propagates outward as a **double-counted conversion reported to Google**. ADR-0023 makes delivery at-least-once by design | **NEWLY DISCOVERED** |
| F10 | `exchange_rates` allowed two rates for one currency pair at one instant | "The latest rate at or before X" had two answers; whichever the planner returned first silently decided what a booking cost | **NEWLY DISCOVERED** |
| F11 | `events` remained tenant-only after every operational table was branch-scoped | The audit trail described in full the records it refused to show — status changes, reasons, and every `payload`. A complete bypass of the read model | **NEWLY DISCOVERED** (created by SPEC-137) |
| F12 | `documents`, `document_links`, `document_versions` were named in SPEC-137's plan and never reached its migration | Passport scans readable by every employee in the company; `document_versions.storage_path` is the field that retrieves the file. `documents.is_confidential` was decorative — nothing read it | **NEWLY DISCOVERED** (found by auditing permission coverage, not by re-reading the migration) |
| F13 | `user_role_assignments.scope_type` was free text with no CHECK; `app.assign_user_role` passed its parameter through unvalidated | Became security-critical the moment scope_type decided read authority. A typo silently changes authority | **NEWLY DISCOVERED** |
| F14 | `user_branch_assignments` allowed multiple current `is_primary` rows | `app.create_task` resolves placement with `limit 1` on that lookup, making the branch a record is filed under non-deterministic | **NEWLY DISCOVERED** |
| F15 | Four RPCs (`create_quotation`, `start_conversation`, `create_complaint`, `create_service_request`) wrote a null ownership triple | All are SECURITY INVOKER, so under a branch-scoped WITH CHECK they would not merely produce invisible rows — they would stop working | **NEWLY DISCOVERED** |
| F16 | **No test in the suite had ever run as `authenticated`.** Every test ran as `postgres`, which owns the tables and bypasses RLS entirely | No test had ever proven that an RLS policy filters a row — including the tenant isolation the whole system rests on. Policies were verified by inspection only | **NEWLY DISCOVERED** |
| F17 | 67 of 82 `app` functions are SECURITY INVOKER | RLS is the real gate and governs the RPC path too; a second read mechanism would have been a second source of truth. This determined the AUDIT-3 architecture | **NEWLY DISCOVERED** (as a design-determining fact) |
| F18 | `leads` and `bookings` each carry two placements: `branch_id`/`department_id` (NOT NULL) and `owner_branch_id`/`owner_department_id` (nullable). `leads.owner_user_id` and `assigned_user_id` always hold the same value | Duplicate source of truth. Canon 31 lists both without distinguishing them | **NEWLY DISCOVERED** |
| F19 | `notifications.target_user_id` names one recipient, but every employee could read every other employee's notifications | Discloses who is being told what, and the records concerned | **NEWLY DISCOVERED** |
| F20 | `bookings.destination_city` is free text with no reference table; destination *country* is FK-constrained | Limits "which destinations sell best" as a report | **NEWLY DISCOVERED** |
| F21 | Configuration audit clean: 0 unpinned SECURITY DEFINER functions, 95/95 functions owned by `postgres`, 0 PUBLIC grants, `anon` has no privileges, 0 policies targeting the `public` role, 0 empty catalog families | Confirms SPEC-124's grant model holds locally | **Confirmation of known state** |
| F22 | `moddatetime` installed in `public` rather than `extensions` | Cosmetic surface concern; ~50 triggers depend on it | **NEWLY DISCOVERED**, minor |
| F23 | Manifest and `32_execution_roadmap.md` both named "build the n8n workflow" as the next capability after the owner gated it | A fresh agent booting through `AGENTS.md §4` would have started gated work | **NEWLY DISCOVERED** (pre-flight, same day) |

---

## 2. Recommendations

| # | Recommendation | Reason | Evidence / canon | Status |
| --- | --- | --- | --- | --- |
| R1 | Implement read scope as RLS predicates over resolution primitives, not RPC/view-only reads | 67 of 82 app functions are SECURITY INVOKER, so RLS already governs the RPC path; a second read mechanism would duplicate the rule | Canon 35 §4; F17 | **IMPLEMENTED** (SPEC-137) |
| R2 | Keep the customer master tenant-visible; branch-scope the activity | Branch-scoping the master would stop a second branch finding a returning customer and produce the duplicate canon 05 forbids | Canon 05 §Customer Cross-Branch Awareness | **IMPLEMENTED** (SPEC-137) |
| R3 | Gate department visibility by permission, and grant that permission to `employee`/`senior_employee` | Satisfies canon ("requires explicit permission") and the owner (continuity by default) literally, and keeps the trainee boundary real | Canon 28 CRM notes; owner §3 | **IMPLEMENTED** (SPEC-137) |
| R4 | Move RBAC write authority into the tables, using each table's own RPC `authorize()` key | The RPCs checked correctly; nothing enforced it when the RPC was skipped | F2; canon 28 §Organization Permissions | **IMPLEMENTED** (SPEC-138) |
| R5 | Withhold margin columns by column grant, re-serve through a gated accessor; keep `booking_item_profit` INVOKER | A definer function would bypass RLS and re-implement the row scope in a second place | Canon 28 Finance table ("Assigned related only") | **IMPLEMENTED** (SPEC-139) |
| R6 | Guard assignment history with a trigger rather than write it with one | A writing trigger would lose `assigned_by`/`assignment_reason` (caller-only knowledge) and make the bypass path succeed silently | Canon 04 §Lead Assignment History | **IMPLEMENTED** (SPEC-140) |
| R7 | Derive the originating employee for leads from the timeline; store it for customers | The earliest timeline row *is* the first employee; a customer has no assignment timeline to derive from | Owner §8; canon 03 | **IMPLEMENTED** (SPEC-140) |
| R8 | Lift the sub-status family mapping into one function shared by trigger and RPC | The rule already existed in `create_booking_item` citing canon 13; it was enforced on one path only | Canon 26 §Sub-Status Rule | **IMPLEMENTED** (SPEC-141) |
| R9 | Seed `feature_entitlements` from canon 28 + canon 17 | Canon defines the matrix in full and the table was empty | Canon 09/17/28 | **IMPLEMENTED** (SPEC-141) |
| R10 | Do **not** wire plan-gating enforcement in this programme | Canon 35 §8 explicitly defers where the gate sits to implementation time | Canon 35 §8 | **DEFERRED** (PLAN-1) |
| R11 | Put unique indexes behind every duplicate rule; scope each to what is actually a mistake | Check-then-insert cannot survive concurrency; over-restriction is a worse defect than the duplicate | Owner §18; canon 05 | **IMPLEMENTED** (SPEC-142) |
| R12 | Do **not** constrain `passengers.passport_number` | The same traveller can legitimately appear under a corporate and a personal account; `app.find_customer_duplicates` already detects it | Owner §18 ("do not create over-restrictive UNIQUE constraints") | **REJECTED** (deliberately not implemented) |
| R13 | Scope `events` by dispatching on `entity_type` to the subject table's own RLS | All 22 emitted entity types map to tables with RLS, so no judgement about sensitivity is needed and no stale copy of the rule is created | F11; canon 35 §7 | **IMPLEMENTED** (SPEC-143) |
| R14 | Restrict `security_events` to tenant-wide readers outright, not by subject | "Who may see this security event" is not "who may see the record it concerns" | Canon 35 §6/§7 | **IMPLEMENTED** (SPEC-143) |
| R15 | Do **not** add a branch column to `events` | Branch is derivable through the subject; denormalising creates a second source of truth | Owner §26 | **REJECTED** (deliberately not implemented) |
| R16 | Scope documents one-directionally: links by parent, documents by link, versions by document | Mutual reference between `documents` and `document_links` policies would recurse without end | F12; canon 28 §Document Permissions | **IMPLEMENTED** (SPEC-144) |
| R17 | Do **not** name `VIEW_TRAVEL_DOCUMENTS` in the document policy | Canon 28 scopes it as assigned/department, which is exactly what scoping through the linked record produces; naming it adds a gate canon does not describe | Canon 28 | **REJECTED** (recorded so a future coverage audit does not "fix" it by force) |
| R18 | Do **not** invent vocabularies for `branches.branch_type` or `company_assets.asset_type` | Canon gives neither column any vocabulary; inventing one puts fabricated values into a catalog the system treats as authoritative | Owner §16 ("do not force every field into a catalog"); canon 31 | **REJECTED** (deliberately not implemented) |
| R19 | Resolve `leads.owner_user_id` vs `assigned_user_id` in a pass that can ask the question of all eight ownership-triple tables at once | Canon 31 lists both without distinguishing them; deciding in isolation would be a guess | F18; canon 31 | **DEFERRED** |
| R20 | Define ceilings for the three "Limited" features canon leaves unquantified | Basic Reporting (Starter), Integrations and Offline Conversion (Professional) are marked "Limited" with no number anywhere; seeding an invented number would look authoritative | Canon 17/28 | **REQUIRES DECISION** (owner) |
| R21 | Repoint the manifest and roadmap next-capability at the Foundation programme | A fresh agent booting through `AGENTS.md §4` would have started the gated n8n build | F23; owner directive 2026-08-21 | **IMPLEMENTED** (pre-flight commit) |
| R22 | Complete the remaining 17 unenforced permissions | Booking-item costing, exchange rates, approval review, platform admin, API scope pair, reporting `VIEW_*` | Canon 28; RPC-1 | **DEFERRED** — next engineering block |

---

## 3. Changes Actually Implemented

All **IMPLEMENTED** and **VERIFIED locally**; all **UNVERIFIED on Primary** (§7).

### Migrations (10 new, `supabase/migrations/`)

| File | CR | Contents |
| --- | --- | --- |
| `202607051400_read_scope_model.sql` | SPEC-137 | 4 resolution primitives; `scope_isolation` policies on 21 tables; `scope_type` CHECK + qualifier CHECK; one-current-primary unique index; `VIEW_DEPARTMENT_RECORDS` permission; role_permission grants |
| `202607051500_branch_filed_write_paths.sql` | SPEC-137 | `app.current_placement()`; repaired `create_quotation`, `start_conversation`, `create_complaint`, `create_service_request` |
| `202607051600_rbac_write_authority.sql` | SPEC-138 | Split `FOR ALL` into SELECT + permission-gated INSERT/UPDATE/DELETE on 7 identity/org tables + `catalog_values` |
| `202607051700_employee_financial_privacy.sql` | SPEC-139 | `app.item_financials()`; column-grant replacement on `booking_items`; reworked `booking_item_profit`; `supplier_balance` → DEFINER + finance-gated |
| `202607051800_assignment_history_integrity.sql` | SPEC-140 | 3 trigger functions + 3 triggers; reordered `assign_lead`; new `app.reassign_lead`; `customers.first_registered_user_id` + FK; `app.lead_origin()` |
| `202607051900_customer_first_registration.sql` | SPEC-140 | `create_customer` fills first-registration branch + user from placement |
| `202607052000_conditional_vocabulary_and_plan_matrix.sql` | SPEC-141 | `app.sub_status_family()`; `app.enforce_sub_status_code()` + trigger; 2 CHECKs; 66 `feature_entitlements` rows |
| `202607052100_duplicate_prevention.sql` | SPEC-142 | `customers.duplicate_phone_approved`; 12 unique indexes; `create_customer` records the exception |
| `202607052200_event_visibility_and_timelines.sql` | SPEC-143 | `events` policy dispatching on `entity_type`; `security_events` restricted; `app.customer_timeline()`, `app.lead_timeline()` |
| `202607052300_document_read_scope.sql` | SPEC-144 | `scope_isolation` on `documents`, `document_links`, `document_versions` |

### RPCs

- **New**: `app.reassign_lead`, `app.current_user_id`, `app.has_tenant_wide_read`, `app.visible_branch_ids`, `app.visible_department_ids`, `app.current_placement`, `app.item_financials`, `app.sub_status_family`, `app.lead_origin`, `app.customer_timeline`, `app.lead_timeline`
- **Modified**: `app.assign_lead` (statement order), `app.create_quotation`, `app.start_conversation`, `app.create_complaint`, `app.create_service_request` (placement), `app.create_customer` (×3: placement, first-registration, duplicate flag), `app.booking_item_profit` (reads via accessor), `app.supplier_balance` (DEFINER + finance gate)

### Permissions

- Added `VIEW_DEPARTMENT_RECORDS` (70 permissions total)
- Granted `VIEW_DEPARTMENT_QUEUE`, `VIEW_DEPARTMENT_TASK_QUEUE`, `VIEW_DEPARTMENT_RECORDS`, `VIEW_COMPLAINT`, `VIEW_CONVERSATION`, `VIEW_SERVICE_REQUEST` to `employee` and `senior_employee`
- Granted `VIEW_BRANCH_DATA` to `branch_manager`

### RLS policies

- `scope_isolation` on 24 tables (8 scope-bearing, 5 derived children, 5 financial, notifications ×2, customer_notes, 3 document tables)
- `scope_read` / `scope_insert` / `scope_update` / `scope_delete` on 7 identity/org tables; 3 rewritten policies on `catalog_values`
- `audit_read` rewritten on `events` and `security_events`

### Constraints and triggers

- CHECKs: `user_role_assignments.scope_type`, scope qualifier, `catalog_types.ownership_type`, `feature_entitlements.feature_code`
- Triggers: `lead_assignments_immutable`, `leads_require_assignment_history`, `customers_freeze_first_registration`, `booking_items_enforce_sub_status`
- Unique indexes: 1 (one current primary placement) + 12 (duplicate prevention)
- FK: `customers_first_registered_user_id_fkey` (tenant-qualified)
- Column grant: table-level SELECT on `booking_items` replaced by an explicit column list

### Tests (8 new files, `supabase/tests/`)

`21_read_scope_model` (24), `22_write_authority` (12), `23_financial_privacy` (12), `24_assignment_history` (14), `25_conditional_vocabulary_and_plans` (13), `26_duplicate_prevention` (16), `27_event_visibility` (9), `28_document_scope` (8). Fixture correction to `21` after SPEC-140.

### Canonical / documentation

- `28_permissions_matrix.md` — new §Read Scope Enforcement + 4 ratified amendments
- `manifest.md` — corrected stale catalog count (67/569 → 68/583); next-capability repointed; progress recorded
- `32_execution_roadmap.md` — next-capability repointed off the gated n8n build
- `MASTER_GAP_REGISTER.md` — AUDIT-3 resolved; SEC-3, SEC-4, HIST-1, CAT-5/6, PLAN-1, DUP-1, AUDIT-6, DOC-1 added
- `changes/SPEC-137` … `SPEC-144` — 8 change requests with Execution Logs and Verification Notes
- `reports/history/foundation-completion-programme-2026-08-24.md`

### Configuration / governance

- `scripts/verify_database.sql` — checks 5b/5c/5d/5e/5f added (read-scope primitives, 21 scope policies, 7 permission-gated write policies, margin column grants, 3 history triggers); check 5e verified to fail when the grant is restored

---

## 4. Important Decisions Made From Evidence

| # | Decision | Alternative rejected | Evidence |
| --- | --- | --- | --- |
| D1 | Read scope enforced by **RLS predicates**, not RPC/view-only reads | RPC-only or view-only reads | 67/82 app functions are SECURITY INVOKER, so RLS already governs the RPC path (F17). This settles AUDIT-3's recorded owner-decision item |
| D2 | **Customer master stays tenant-visible**; activity is branch-scoped | Branch-scoping the customer row | Canon 05 requires no duplication + a cross-branch summary (last interaction date/branch/employee — the exact three columns present) |
| D3 | Department visibility is **permission-gated**, permission granted by default to employee/senior_employee; `trainee` excluded | Membership-only visibility | Test 21 assertion 12 failed under membership-only: a trainee inherited the whole department. Canon 28's "requires explicit permission" is what makes the boundary real |
| D4 | Isolation uses `branch_id`/`department_id` (NOT NULL) on leads/bookings, not the nullable owner triple | Using `owner_*` | A mandatory column cannot produce the invisible-row failure a nullable one can |
| D5 | Financial privacy by **column grant + gated accessor**, `booking_item_profit` stays INVOKER | Making it SECURITY DEFINER | A definer function bypasses RLS and would re-implement the row scope in a second place |
| D6 | `booking_item_profit` **masks** (NULL); `supplier_balance` **raises** | Uniform treatment | A booking item is operationally useful without its margin; a supplier balance is money end to end, so there is nothing to return |
| D7 | Branch/department managers **not** granted financial visibility by default | Granting it | Canon 28 marks `VIEW_FINANCIAL_DOCUMENTS` *Optional* for Branch Manager and **No** for Department Manager |
| D8 | Assignment-history trigger **guards**, does not write | A writing trigger | `assigned_by`/`assignment_reason` are caller-only knowledge; a guard makes the bypass fail loudly instead of succeeding silently |
| D9 | A lead **cannot be created already-assigned** in one statement | Relaxing the guard on INSERT | The history row FKs to the lead, so the lead must exist first. Assignment is an act with a timestamp and an author, not a birth attribute. `create_lead` takes no assignee, so no production path is affected |
| D10 | Originating employee **derived** for leads, **stored** for customers | Storing both | The earliest timeline row *is* the first employee; a customer has no timeline to derive from |
| D11 | Plan matrix **seeded**, enforcement **not wired** | Wiring an `app.plan_allows()` gate now | Canon 35 §8: subscription gating is "decided at implementation, not here" |
| D12 | "Unlimited"/"Custom" encoded as **null** ceiling | A sentinel number | A sentinel would later be mistaken for a real limit |
| D13 | Event visibility **dispatched to the subject's own RLS** | A blanket tenant-wide-only rule | All 22 emitted entity types map to RLS-bearing tables, so no sensitivity judgement is needed. A blanket rule would have passed most assertions and broken canon 05 cross-branch awareness |
| D14 | `security_events` restricted outright, **not** by subject | Subject dispatch | Different question: who investigates vs who owns the record |
| D15 | Document scoping is **one-directional** | Mutual link↔document scoping | Would recurse without end |
| D16 | Attribution/campaign/conversation idempotency enforced by **unique index** | Relying on caller discipline | ADR-0023 makes delivery at-least-once *by design*, so a retry is a normal event, not a failure mode. A duplicate click propagates to Google as a double-counted conversion |
| D17 | Canon 28 **amended**, not silently contradicted | Implementing the owner rule without recording it | Owner directive supersedes a Draft canon, but the divergence must be visible |

---

## 5. Remaining Gaps / Open Items

### Engineering work

| Item | Detail |
| --- | --- |
| G1 | **17 of 70 permissions still enforced nowhere**: `ENTER_COST`, `ENTER_SELLING_PRICE`, `EDIT_LOCKED_COST`, `SET_EXCHANGE_RATE`, `CREATE_EXCHANGE_RATE_ADJUSTMENT`, `REVIEW_APPROVAL_REQUEST`, `REVIEW_SUBSCRIPTION_PAYMENT`, `MANAGE_ROLES`, `MANAGE_PERMISSIONS`, `ACCESS_API_FULL`, `ACCESS_API_READ_ONLY`, `VIEW_ASSIGNED_LEADS`, `VIEW_ASSIGNED_TASKS`, `VIEW_TRAVEL_DOCUMENTS`, `VIEW_MARKETING_DASHBOARD`, `VIEW_ADVANCED_DASHBOARDS`, `VIEW_SUBSCRIPTION_STATUS` |
| G2 | **PLAN-1 enforcement** — nothing reads `feature_entitlements`; `usage_counters` is empty, so numeric ceilings have no counter |
| G3 | **`leads.owner_user_id` vs `assigned_user_id`** — always identical; canon does not distinguish them. Belongs to a pass covering all eight ownership-triple tables |
| G4 | The `assigned` clause in the scope model is unconditional — it does not check `VIEW_ASSIGNED_LEADS`/`VIEW_ASSIGNED_TASKS`. Low risk (every operational role holds them) but it is why those two show as unenforced |

### Verification work

| Item | Detail |
| --- | --- |
| G5 | **Primary deployment + verification (STEP 15)** — blocked, see G8 |
| G6 | Exhaustive column-by-column table-by-table pass (STEP 4) — performed across the security, duplicate-prevention, vocabulary and reporting dimensions, **not** column-by-column for all 72 tables |
| G7 | STEPS 9–11 not re-run: employee-walkthrough extension, n8n contract re-verification, Google Ads / Google Cloud re-verification. The Google conclusion was independently verified 2026-08-21 and nothing in this session touched that contract |

### Infrastructure / access blockers

| Item | Detail |
| --- | --- |
| G8 | **`supabase-primary` MCP server disconnected and requires re-authorization.** Cannot be done non-interactively. Primary is 10 migrations behind; parity **UNVERIFIED** |

### Genuine business decisions

| Item | Detail |
| --- | --- |
| G9 | **REQUIRES DECISION** — the ceilings for the three features canon marks "Limited" without a number: Basic Reporting (Starter), Integrations (Professional), Offline Conversion (Professional). Seeded enabled and uncapped rather than guessed |
| G10 | **REQUIRES DECISION** — whether `MANAGE_SUBSCRIPTION` stays platform-only. Canon 28 gives Owner/CEO "Limited"; no role currently holds it, making `subscriptions` service-role-writable only |
| G11 | **REQUIRES DECISION** — whether branch managers should see branch margins (`VIEW_FINANCIAL_DOCUMENTS` is *Optional* for that role in canon 28; not granted) |

---

## 6. Risks You Identified

Priority order.

| # | Risk | Consequence | Mitigation state |
| --- | --- | --- | --- |
| K1 | **Primary drift.** Primary carries none of the 10 migrations. The longer the gap, the higher the chance of divergence or a conflicting hotfix | Foundation cannot be frozen; parity claims would be false | Recorded as UNVERIFIED in all 8 CRs and the manifest. **Unmitigated — needs re-authorization** |
| K2 | **Unenforced write permissions (G1)** — costing and exchange-rate paths are still direct-DML only | Cost/price entry bypasses `authorize()`, lifecycle and events. Financial data integrity | Partially mitigated: SPEC-139 restricts *reading* margins; writing is still open |
| K3 | **Plan gating absent (G2)** | A Starter tenant can use Enterprise features; no ceiling is enforced. Revenue and capacity | Data seeded; enforcement deliberately deferred per canon 35 §8 |
| K4 | **`select *` on `booking_items` now fails for `authenticated`** | Any client using `select=*` breaks. Deliberate and unavoidable (Postgres checks column privileges on the reference) | Asserted as a test so it is discovered in CI, not production. **Employee-facing if a UI is written naively** |
| K5 | **A lead can no longer be created already-assigned in one statement** | Any future importer or bulk-load path must do it in two steps | Documented in SPEC-140; no current production path affected |
| K6 | **RLS UPDATE denial is silent** — a row excluded by USING yields zero rows and no error | Application code treating "no error" as "the write happened" would be wrong | Recorded in SPEC-138 and asserted in test 22 |
| K7 | **`destination_city` is free text (F20)** | Destination reporting cannot be aggregated reliably | Not addressed; canon defines no city vocabulary |
| K8 | **Performance of the scope model is unmeasured** | Policies use `exists` subqueries against parent tables. Indexes exist on the FK columns, and set primitives are InitPlan-hoisted, but this has never run against volume | Not measured — all tables are at 0 rows |
| K9 | **`moddatetime` in `public` (F22)** | Extension functions in the API-exposed schema | Cosmetic; not addressed |

---

## 7. Verification Status

| Metric | Value | State |
| --- | --- | --- |
| Local migrations | **112** (10 added this session) | **VERIFIED** — replays clean from empty |
| Test files | **28** (8 added) | **VERIFIED** |
| Assertions | **235** (108 added) | **VERIFIED** — `Result: PASS` |
| Assertions running as `authenticated` (real RLS) | **63** across 5 files | **VERIFIED** — first in the project's history |
| Smoke (`scripts/verify_database.sql`) | `ALL CHECKS PASSED` | **VERIFIED** — includes 5 new checks; 5e independently proven to fail when the grant is restored |
| Repository consistency guard | `CLEAN` | **VERIFIED** |
| repo = local | 112 = 112, fingerprint `5cdd944b34ee6e869a30dd24aed6dce4` | **VERIFIED** |
| Working tree / push state | clean, 0 unpushed | **VERIFIED** |
| Permissions enforced | **53 of 70** (was 33) | **VERIFIED** |
| **Primary parity** | Primary is **10 migrations behind** | **UNVERIFIED — blocked (G8)** |
| **Primary ledger fingerprint** | not obtainable this session | **UNVERIFIED** |
| Scope-model performance at volume | never measured | **UNVERIFIED** |
| n8n contract, Google Ads / Cloud environment | not re-run this session | **UNVERIFIED this session** (verified 2026-08-21; untouched since) |

---

## 8. Recommended Next Sequence

1. **Re-authorize `supabase-primary`** (interactive `/mcp` or `claude mcp`). Nothing else can be closed without it.
2. **Apply the 10 migrations to Primary**, then confirm three-way parity by ledger fingerprint and re-run the smoke script against Primary.
3. **Close G1's finance block** — `ENTER_COST`, `ENTER_SELLING_PRICE`, `EDIT_LOCKED_COST`, `SET_EXCHANGE_RATE`, `CREATE_EXCHANGE_RATE_ADJUSTMENT`, `REVIEW_APPROVAL_REQUEST`, following the SPEC-131/132/134 write-path pattern. Highest residual risk (K2).
4. **Decide and wire PLAN-1's gate** (canon 35 §8 says this decision is due at implementation). Needs G9 answered first.
5. **Close G1's remainder** — platform admin, API scope pair, the reporting `VIEW_*` set as `reporting` views are exposed.
6. **Resolve G3** in one pass across all eight ownership-triple tables.
7. **Complete STEP 4** column-by-column for the tables not yet covered.
8. **Re-run STEPS 9–14** end to end, then re-assess the freeze.

---

## 9. Final Assessment

**Solid now.** Tenant, branch, department and assignment read scope across 24 tables, proven behaviourally against real authenticated users. RBAC write authority — the escalation path is closed. Employee financial privacy. Lead assignment history, including the originating employee, guaranteed by trigger on every path. Controlled vocabulary complete, including the conditional sub-status case. Duplicate prevention with concurrency safety, including three integration-idempotency constraints. Audit-trail visibility and Customer 360 / Lead 360 timelines. Configuration and grant model clean on every dimension checked.

**Not solid yet.** Primary carries none of it. 17 permissions remain enforced nowhere, most consequentially the booking-item costing and exchange-rate write paths. Plan gating is data without a gate. The scope model has never been measured under load.

**Before Foundation Freeze.** Items 1–5 of §8, in order. Items 1–2 are blocking and cannot be started without access.

**Requires your decision.** G9 (the three undefined "Limited" ceilings), G10 (`MANAGE_SUBSCRIPTION` scope), G11 (branch-manager margin visibility). None blocks items 1–3.

---

End of report.
