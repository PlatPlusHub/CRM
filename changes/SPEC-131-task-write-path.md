# Change Request — SPEC-131

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Give `tasks` a governed write path — authorization, canonical lifecycle, and event emission — establishing the pattern for the RPC-1 programme and closing the first three of ORVION's unenforced permissions.

---

## Business Reason

35 of 72 tables had no RPC write path. For those entities a direct PostgREST write was the **only** path, so there was no `app.authorize()` check, no state-machine validation and no event emitted — not authorization that can be bypassed, but no authorization in existence.

Two pieces of evidence establish that this is an implementation gap rather than a design choice, and that closing it needs no business decision:

1. **37 of ORVION's 69 seeded permissions are enforced nowhere**, and the write-side ones map exactly onto the entities missing RPCs — `CREATE_TASK`, `ASSIGN_TASK`, `COMPLETE_TASK`, `SEND_MESSAGE`, `CLOSE_CONVERSATION`, `RESOLVE_COMPLAINT`, `SET_EXCHANGE_RATE`, and the rest. The domain already decided these operations require authorization.
2. **`26_state_machines.md` already defines the Task, Complaint, Service Request, Conversation and Marketing Campaign lifecycles in full.** Nothing here had to be invented or asked.

Tasks are first because they are the highest-traffic operational entity in a CRM, and because canon specifies their lifecycle completely: five states, ten transitions, five required events.

---

## Risks

Low. Additive functions on a zero-row table; no existing behaviour changes. The RPCs deliberately do **not** re-validate what the database now guarantees on every path — catalog codes (SPEC-127), the related-entity reference (SPEC-130), tenant-safe foreign keys (SPEC-129), normalization (SPEC-126) — so there is no second place for those rules to drift.

---

## Supersedes / Depends On

Depends on SPEC-126, SPEC-127, SPEC-129 and SPEC-130 (the database-layer guarantees these RPCs build on). First delivery against RPC-1; does not close it.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050800_task_write_path.sql`
- `supabase/tests/16_task_write_path_test.sql`
- `supabase/tests/08_status_vocabulary_registry_test.sql` (register `advance_task` in the transition-RPC map)
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-131-task-write-path.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `_ORVION_CANONICAL/26_state_machines.md` (the lifecycle is implemented as canon already specifies it — this CR must not redefine it)

---

## Minimum Reading List

- `_ORVION_CANONICAL/26_state_machines.md` §Task State Machine
- `supabase/migrations/202607044700_advance_lead.sql` (the established transition-RPC shape)
- `supabase/migrations/202607043500_seed_roles_and_permissions.sql`

---

## Implementation Steps

1. Verification check: `app.create_task` exists. If absent, create it — `CREATE_TASK`, owner/branch/department resolution and tenant checks, `task_created`.
2. Verification check: `app.assign_task` exists. If absent, create it — `ASSIGN_TASK`, refuses reassigning a terminal task, `task_assigned`.
3. Verification check: `app.advance_task` exists. If absent, create it using the canonical transition table in the established `values(...) as t(frm, to_s, ev, perm)` shape, excluding the System-set `overdue` destination.
4. Verification check: all three revoke PUBLIC EXECUTE and grant `authenticated`.
5. Verification check: `advance_task` is registered in test 08's transition-RPC map.
6. Verification check: `db reset` replays clean, smoke passes, full suite passes, Primary agrees by ledger fingerprint.

---

## Acceptance Criteria

- [x] Three governed Task RPCs exist.
- [x] None is executable by PUBLIC; all three are executable by `authenticated`.
- [x] `create_task` enforces `CREATE_TASK`; `assign_task` enforces `ASSIGN_TASK`; `advance_task` enforces `COMPLETE_TASK` on terminal transitions.
- [x] `in_progress -> completed` is allowed; `completed -> in_progress` is not reachable.
- [x] `overdue` is not an employee-reachable destination.
- [x] Unenforced permissions drop from 37 to 34 on Primary.
- [x] Suite 16 files / 84 tests PASS; smoke-test passes.
- [x] repo = local = Primary by ledger fingerprint (97 migrations).

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (foundation gate)

Outcome: Complete

Steps 1–6 applied and verified. `db reset` 97 clean; smoke `ALL CHECKS PASSED`; suite `Files=16, Tests=84 … PASS`. Primary: ledger `644a244693c721b289226425d3fcb6c0`, 70 `app` functions, PUBLIC EXECUTE 0, **unenforced permissions 37 → 34**.

Step 5 was not anticipated in advance — it was *demanded* by the suite. Creating `app.advance_task` immediately failed test 08's completeness assertion: *"Every transition-shaped app.* function … is covered by the transition-RPC map"*. That is precisely the behaviour SPEC-121 built it for: a new transition RPC cannot silently escape the status-vocabulary guard. The map entry records that it was added in response to the failure rather than written by hand ahead of time.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (foundation gate)

Verdict: Confirmed Complete

Findings: The permission and lifecycle assertions are made against the live function source rather than by impersonating a role, and that choice is deliberate: `app.authorize()` resolves through `auth.uid()`, which a pgTAP session does not have, so an impersonation test would prove nothing about the permission *names* — and the names are the contract, since three of them were previously enforced nowhere. The lifecycle assertions are stated in both directions: an allowed transition must be present **and** a disallowed one must be absent, so a permissive transition table cannot pass.

`overdue` is asserted absent rather than present. Canon marks it "System-set when due_at passes without completion", so exposing it as an employee transition would let staff mark their own work overdue — the opposite of what the state means. It belongs to a scheduled sweep, following the `app.process_lead_sla` precedent.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state.

---

## Notes

**Approval basis.** Owner directive 2026-08-21, which required the write-path architecture to be resolved as a foundation issue rather than framed around what the first UI needs.

**This CR does not close RPC-1, and should not be read as doing so.** It closes 3 of 34 remaining unenforced permissions and one of roughly ten entities. The remaining programme is fully enumerated in the RPC-1 register row, is technically determinable from canon 26, and requires no business decision — it requires the work. Claiming RPC-1 resolved here would be exactly the false completion the governance forbids.

**Why `overdue` is excluded, and why the scheduled sweep was not built here.** Canon assigns `overdue` to the system. Implementing that sweep means deciding a cadence and a trigger mechanism (`pg_cron` versus the n8n scheduler already in play for Phase 8), which is an infrastructure choice with its own trade-offs — and building it inside a CR about the employee write path would bundle two unrelated decisions. Recorded as part of the RPC-1 programme.
