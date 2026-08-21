# Change Request — SPEC-132

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Give the customer-service domain — conversations, messages, complaints and service requests — governed write paths, closing seven more of ORVION's unenforced permissions and adding the first end-to-end employee walkthrough test.

---

## Business Reason

`conversations`, `conversation_messages`, `complaints` and `service_requests` had no RPC at all, so a direct table write was the only way to use them: no authorization, no lifecycle rule, no event. Seven seeded permissions named these exact operations and were enforced nowhere — `SEND_MESSAGE`, `CLOSE_CONVERSATION`, `ESCALATE_CONVERSATION`, `CREATE_COMPLAINT`, `RESOLVE_COMPLAINT`, `CREATE_SERVICE_REQUEST`, `RESOLVE_SERVICE_REQUEST`.

Every state machine implemented here is transcribed from `26_state_machines.md`, not designed in this CR.

---

## Risks

Low. Additive functions on zero-row tables. The RPCs deliberately do not re-validate what SPEC-126/127/129/130 already guarantee on every write path.

---

## Supersedes / Depends On

Depends on SPEC-131 (the pattern) and SPEC-126/127/129/130 (the database-layer guarantees). Second delivery against RPC-1; does not close it.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050900_customer_service_write_paths.sql`
- `supabase/tests/17_employee_walkthrough_test.sql`
- `supabase/tests/07_event_vocabulary_registry_test.sql` (precision fix)
- `supabase/tests/08_status_vocabulary_registry_test.sql` (register three transition RPCs)
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-132-customer-service-write-paths.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `_ORVION_CANONICAL/26_state_machines.md` (lifecycles are implemented as canon defines them)
- `_ORVION_CANONICAL/27_event_catalog.md` (no event vocabulary was invented)

---

## Minimum Reading List

- `_ORVION_CANONICAL/26_state_machines.md` §Conversation / §Complaint / §Service Request
- `supabase/migrations/202607050800_task_write_path.sql`

---

## Implementation Steps

1. Verification check: `app.start_conversation` exists. If absent, create the three conversation RPCs.
2. Verification check: `app.create_complaint` exists. If absent, create the two complaint RPCs.
3. Verification check: `app.create_service_request` exists. If absent, create the two service-request RPCs.
4. Verification check: all seven revoke PUBLIC EXECUTE and grant `authenticated`.
5. Verification check: the three new transition RPCs are registered in test 08's map.
6. Verification check: `db reset` replays clean, smoke passes, suite passes, Primary agrees by fingerprint.

---

## Acceptance Criteria

- [x] Seven governed customer-service RPCs exist; none PUBLIC-executable; all `authenticated`-executable.
- [x] Each lifecycle matches `26_state_machines.md`, including the canonical reopen edges.
- [x] Conversation transitions to `pending_customer` / `pending_internal` emit no event, as canon specifies.
- [x] Unenforced permissions drop from 34 to 27 on Primary.
- [x] The employee walkthrough passes end-to-end through the real authorization chain.
- [x] Suite 17 files / 102 tests PASS; smoke passes; repo = local = Primary (98 migrations).

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (foundation gate)

Outcome: Complete

All steps applied and verified. `db reset` 98 clean; smoke `ALL CHECKS PASSED`; `Files=17, Tests=102 … PASS`. Primary: ledger `8511865a56d70c4c6899821f628b5164`, 77 `app` functions, PUBLIC EXECUTE 0, all `search_path` pinned, **unenforced permissions 34 → 27**.

Three things were caught by the suite rather than shipped:

1. **Test 08's completeness assertion** refused the three new transition RPCs until they were registered — the second time this guard has done its job in two CRs.
2. **Test 07 required a precision fix.** It scanned the unquoted SQL keyword `null` in `advance_conversation`'s event column as if it were an event code, and demanded a catalog value literally called "null". `null` there means *this transition emits no event*, which is canon's own design for the `pending_*` transitions. The guard now skips the keyword; a quoted `'null'` would still be scanned, so nothing is masked.
3. **A drafting error**: the migration briefly contained a placeholder function body referencing a non-existent table. plpgsql would not have failed at creation time, so it could have shipped as dead-but-valid code. Removed before any run.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (foundation gate)

Verdict: Confirmed Complete

Findings: The decisive verification is `supabase/tests/17_employee_walkthrough_test.sql`, which is qualitatively different from every other test in the suite. Rather than asserting that a constraint exists, it drives the real RPCs as a real authenticated user — a row in `auth.users`, a tenant user linked to it, a role assignment, and a JWT claim — so `auth.uid()` → `app.current_tenant_id()` → `app.authorize()` all resolve genuinely. That is what makes its negative assertions meaningful: the unauthorized case is a real trainee who genuinely lacks the permission, not a stub.

Building it surfaced two real behaviours worth recording. First, `app.requires_mfa()` gates `owner`/`ceo`/`finance_manager`/`system_administrator` on an `aal2` JWT claim, so a privileged session without MFA cannot act at all — correct, and the reason the walkthrough uses `branch_manager`, which is what a daily-CRM role actually looks like. Second, three assertions initially passed for the **wrong reason** — they accepted any exception and were catching the MFA error rather than the intended failure. They were tightened to `throws_like` with specific messages, so they can now only pass for the right reason.

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

**Approval basis.** Owner directive 2026-08-21 ("Supabase Completion & Foundation Freeze Gate"), which made RPC-1 non-optional and required an employee-first walkthrough.

**Canon was followed where it was inconvenient.** Three examples: the `closed → in_progress` / `closed → open` reopen edges are implemented because canon says these states are "Terminal unless reopened by authorized action"; the `pending_*` conversation transitions emit no event because canon's Required Events list deliberately omits them, and inventing `conversation_pending_*` codes would have put this CR ahead of canon 27's vocabulary, which it has no authority to extend; and `overdue` remains excluded from every employee path.

**RPC-1 is still open.** 27 permissions remain unenforced across roughly six entity groups. This CR closes 7 of 34; SPEC-131 closed 3. Naming it resolved would be false completion.
