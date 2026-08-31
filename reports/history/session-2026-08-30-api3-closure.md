# ORVION — API-3 Closed: The Last Three Endpoints, and a Task That Changed Hands Without Authority

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Status: Complete. **`202607058600` is NOT deployed to Primary — awaiting owner approval.**

---

## 1. Objective · 2. Scope

**Objective (FACT).** Audit API-3's final three endpoints — `assign_task`, `financial_documents`,
`link_internal_supplier` — and give all three HTTP execution evidence, closing API-3.

**Bounded surface examined:** the three RPCs and their wrappers; `public.tasks`,
`public.internal_supplier_links`, `public.documents` and `public.document_links` (columns,
constraints, indexes, triggers, RLS, grants); `user_branch_assignments` RLS; the permission matrix
for ASSIGN_TASK / CREATE_TASK / ASSIGN_SUPPLIER / VIEW_FINANCIAL_DOCUMENTS / VIEW_TRAVEL_DOCUMENTS;
every consumer of the two write tables; canon 28's document-visibility rules; SPEC-154-B's record.

**Dependencies inspected only as far as necessary:** `app.is_financial_document_type` and
`app.upload_document`'s `p_is_confidential` default (they decide whether financial documents are
confidential by default, which the visibility question turns on); `app.advance_booking_item` (to
cancel an item through the legal path for the lifecycle reproduction).

**Explicitly OUT OF SCOPE:** deployment, n8n, the roadmap, and **SPEC-154-B's business decision**,
which was sharpened with evidence but deliberately not decided.

---

## 3. Git state at start · 4. at end

| | |
|---|---|
| Branch | `main` → `origin/main`, 0 ahead / 0 behind |
| HEAD, start and end | `09adf1951a733689949c9dec4be730eaeedcbc74` — **unchanged** |
| Working tree | **DIRTY, deliberately** — six uncommitted packages |
| Commit / Push | **NO / NO** |

The five pre-existing uncommitted packages were verified present at session start and untouched.

## 5. Local database state (measured)

**Docker Desktop was not running at session start** — an ENVIRONMENT condition, recorded as such
rather than as a product result. It was launched and the stack came up healthy. Start: **174
migrations**, latest `202607058500`. End: **175**, latest `202607058600`.

## 6. Primary state (measured this session)

Read **four times, written zero times**. `get_project_url` → `vrvtsxexkiiiivlkdxzp`; ledger **169**,
latest `202607058000`, `4f79ecfdad3b2f1f424f72e70e414d86`; function surface
`a994108bd5cf44f9cc570180e72312a4` (236); structural surface `3a65328f42bd8c13b3f3048fa8f0158f`
(3,348). **PRIMARY evidence class.**

---

## 7. Findings

### TASK-1 · High · **PROVEN DEFECT → FIXED**

**Hypothesis.** `app.assign_task` charges ASSIGN_TASK; the table's capability guard charges
CREATE_TASK; `public.tasks` is served by PostgREST with UPDATE to `authenticated`.
**Why it is a real gap and not the ASGN-1 repeat.** ASSIGN_TASK resolves to
`branch_manager, ceo, department_manager, owner`; CREATE_TASK adds **`employee` and
`senior_employee`**. When the same question was asked of `lead_assignments`, both permissions
resolved to the *identical* role set and the finding was closed as NOT A DEFECT. Here they differ,
and the difference is the defect.
**Positive control.** The employee holds CREATE_TASK (asserted), does not hold ASSIGN_TASK
(asserted), and successfully creates a task they own.
**Reproduction, one transaction.** `app.assign_task` → **`permission denied: ASSIGN_TASK`**.
`update public.tasks set owner_user_id = <manager>` → **`UPDATE 1`**. `task_assigned` events for that
task: **0**. Unauthorized *and* unaudited, because the event is emitted by the RPC.
**Enforcement layer.** A BEFORE UPDATE trigger charging ASSIGN_TASK **only when `owner_user_id`
actually changes** — chosen over widening `guard_write_capability`'s mapping because that guard fires
on every write and cannot see which column moved; charging ASSIGN_TASK for every task edit would stop
an employee completing their own task, which CREATE_TASK legitimately allows. Session-less exempt
(authorization, canon 35 principle 6). Legal writers enumerated first: `create_task` (INSERT only, so
this UPDATE trigger never fires for it) and `assign_task`, which already authorizes ASSIGN_TASK.

### TASK-2 · Medium · **PROVEN DEFECT → FIXED**

`assign_task` resolves the placement of an *arbitrary* user, so neither `app.current_placement()`
(the caller) nor `app.eligible_lead_handlers` (a pool) fits — and it inlined `uba.ends_at is null`,
a **third** and narrowest definition of "current placement".
**Reproduced with a wrong value, not merely a divergence:** a CAIRO task assigned to staff whose
primary placement is GIZA with a transfer scheduled 30 days out kept **Cairo**, the previous owner's
branch. Measured beside it: that user's placement resolves to Giza under the full window and to
nothing under `assign_task`'s.
Fixed with PLACE-1's strictly-additive shape. **Also corrected and flagged as not separately
reproduced:** the coalesce sat *inside* the lookup, so an owner with no placement made the SELECT
return nothing and discarded the caller's explicit `p_owner_branch_id` with it.

### SUP-1 · Low · **PROVEN DEFECT → FIXED**

Three of `link_internal_supplier`'s rules were absent from its table door, each reproduced as an
ASSIGN_SUPPLIER holder whose RPC call had just been refused: a provider department not in the
provider branch (RPC refused / `INSERT 0 1`); a forged requester (derived by the RPC, accepted
verbatim by the table); and a link on a legally-cancelled booking item (RPC refused / `INSERT 0 1`).
**Severity is Low and the reason is measured:** `internal_supplier_links` has **no consumer** —
nothing reads it but its own RPC and `guard_write_capability`. Corrupt rows misstate history and
change no behaviour today. Fixed anyway because the history *is* the point of an append-only
fulfilment log, and a future consumer would inherit the corruption silently.
Enforcement: one BEFORE INSERT OR UPDATE trigger carrying the RPC's rules verbatim (BOOK-1's
pattern), SECURITY DEFINER + REVOKE because under INVOKER the parent reads would be RLS-filtered. **No
session-less exemption — integrity, not authorization.** A CHECK cannot express any of the three:
each is a statement about *another* table.

---

## 8. NOT A DEFECT — established, not assumed

- **`link_internal_supplier`'s RPC path.** It validates the provider pair against `departments`,
  derives the requester from the item rather than accepting it, refuses archived/cancelled items and
  completed/cancelled bookings, and appends history rather than mutating. Nothing to fix in the RPC.
- **Cross-tenant supplier links and task owners.** Blocked structurally: every relevant FK on both
  tables is composite `(tenant_id, …)` (TENANT-1). Checked, not assumed.
- **Duplicate supplier links.** By design — the table is an append-only fulfilment log, "latest row =
  current provider". Not a defect.
- **`internal_supplier_links` UPDATE path.** The new trigger covers UPDATE as well as INSERT.
- **`financial_documents`' confidentiality boundary.** A confidential financial document **is**
  invisible to an employee through the table (measured: 0 rows). The protection is real.
- **`user_branch_assignments` RLS hiding other users' placements.** Disproven before relying on the
  TASK-1/TASK-2 results: `scope_read` is tenant-wide, so an ordinary caller sees the same rows the
  test saw as `postgres`. This was checked precisely because running as `postgres` bypasses RLS and
  would otherwise have made both results unsafe to trust.

### FIN-DOC-1 — evidence for SPEC-154-B, not a new decision

Measured with a discriminating control: `finance_manager` (VIEW_FINANCIAL_DOCUMENTS) reads the
financial documents through the endpoint; `employee` is refused **42501** by it — yet that same
employee reads a **non-confidential** invoice document through the table, while a **confidential** one
is correctly hidden.

**What this adds to the existing decision:** SPEC-154-B was recorded as "the binary permission cannot
express canon's *assigned related only*". The measurement shows the decision is also about whether the
RLS branch should exclude financial **types** regardless of the confidential flag. Canon 28 states
**both** *"assigned employee may view financial documents directly related to their lead/booking"*
**and** *"financial documents require stricter visibility"* — and forcing `is_confidential` on
financial types would satisfy the second by destroying the first. **Deliberately not decided.** Pinned
by assertion 20 of the new test so the boundary cannot move silently.

Also recorded (LESSON 4): `202607048200`'s header claims *"RLS on documents is tenant-wide"*. That is
**measurably false** since the SPEC-139/DOC packages tightened it. The endpoint is stricter than its
own comment says, so the staleness is harmless — but it is a comment asserting a property that no
longer holds.

---

## 9. Fixes · 10. Tests · 11. HTTP evidence

| File | Change |
|---|---|
| `202607058600_a_task_changes_hands_only_with_authority.sql` | **NEW.** TASK-1 trigger, TASK-2 window fix, SUP-1 integrity trigger |
| `supabase/tests/81_task_supplier_financial_test.sql` | **NEW.** 20 assertions, two mutation attacks, three negative controls, one open-decision pin |
| `scripts/verify_journey_branches.ps1` | **+11 HTTP assertions** (63 → 74) |

**HTTP evidence is execution, not reference.** Each of the three endpoints was CALLED and its result
asserted: `assign_task` executed for an ASSIGN_TASK holder and the task really changed hands;
`link_internal_supplier` executed and its derived requester was verified; `financial_documents`
executed for a finance_manager and was refused for an employee. `PATCH /rest/v1/tasks` and
`POST /rest/v1/internal_supplier_links` were exercised as the second doors.

## 12. Verification executed THIS session

| Step | Result |
|---|---|
| `npx supabase db reset` | exit 0, **175** migrations |
| pgTAP **Pass A** | **81 files / 1,066 assertions / PASS** |
| **Six HTTP suites** | **360 passed, 0 failed** — 29 · 102 · **74** · 66 · 38 · 51 |
| pgTAP **Pass B**, no reset, under residue | **81 / 1,066 / PASS** = Pass A |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Local ledger | 175, `f9b48f14410f56852a3a552db26242ca` |
| Local function surface | `7f509e9a8b091d0e11330254d0ae3208` (240) |
| Local structural surface | `ad135a817fc0e1b93246dd869cac9ccd` — 3,360 objects |
| Parity guard | **exit 1 — PRIMARY DRIFT, correct and intended** |
| API contract | regenerated: **71 of 71** with HTTP evidence |
| Repository guard | CLEAN, 13/13 |

## 13. Measurement errors and fixture failures — all mine

1. **Docker Desktop was down at session start.** ENVIRONMENT, not a product finding; launched it.
2. I passed `assign_task`'s reason as its 3rd positional argument; the 3rd and 4th are
   department/branch UUIDs. Read the signature instead of guessing.
3. `create_booking`'s second parameter is `p_lead_id`, not the title.
4. `advance_booking_item` requires `p_cancellation_reason_code`; my first cancellation attempt failed
   without it.
5. `'customer'` is not a `document_link_target_type`; the valid set is booking, booking_item, invoice,
   passenger, receipt, subscription_payment, supplier.
6. Two assertions in the new test failed because `authenticated` cannot read the test's own temp
   tables — granted select on the scratch tables only.
None of these became product findings.

## 14. UNPROVEN

All six migrations on Primary (never deployed, never exercised there) · **SPEC-154-B**'s correct
visibility rule · `storage-executor` Edge Function execution (carried forward) · **n8n — not
contacted this session**, so its state here is HISTORICAL.

## 15. Owner decisions

**Newly created: NONE.** **Resolved autonomously:** every question in this family was answered from
canon 28, the permission matrix, the schema, consumer measurement or experiment. **Unchanged:** the
29 recorded decisions, with **SPEC-154-B now carrying sharper evidence** (FIN-DOC-1) but no new
decision beside it.

## 16. Governance files updated

`manifest.md` (live state, Last Completed, API-3 closure, suite counts) · `MASTER_GAP_REGISTER.md`
(+4 rows) · `MASTER_EXECUTION_PLAN.md` (Batch 6 narrative) · `reports/README.md` (pointer) ·
`MASTER_API_CONTRACT.md` and `ai-map.json` (regenerated).
**Deliberately unchanged:** `32_execution_roadmap.md` (no phase or gate changed — API-3 is a Batch-6
item, and the plan owns batch state) · canon 28 (**authority consulted, not subject**) ·
`MASTER_CERTIFICATION_STATUS.md` · ADR log.

## 17. Next executable step

**API-3 is closed.** The next Batch-6 items, from `MASTER_EXECUTION_PLAN.md`: the table-by-table
audit, `notification_deliveries` having no producer, the Employee/Supplier/Branch 360 primitives, and
**SPEC-154-B** — which this session's FIN-DOC-1 evidence has made decidable enough to put to the
owner.

*Recommendation, not a finding:* put SPEC-154-B to the owner next, because it is now the only
API-3-adjacent item with measured evidence on both sides and it gates nothing else until decided.

## 18–22. Session effects

**Commit:** NO. **Push:** NO. **Primary deployment:** NO — Primary unchanged at 169. **n8n:** not
contacted, not changed.
