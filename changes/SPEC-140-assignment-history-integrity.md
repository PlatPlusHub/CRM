# Change Request — SPEC-140

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Make "who had this lead, and who had it first" a fact the database guarantees: build the missing
reassignment path, stop assignment history being rewritten or bypassed, and record the employee who
first took a customer on.

---

## Business Reason

Canon 04 §Lead Assignment History has always been explicit — "Every assignment must remain visible in
the lead timeline", the timeline must show "The employee who received it … The next employee who
received it", and "**No assignment history may be deleted**". The owner restated it as a requirement
on 2026-08-24 (§7, §8) with a concrete scenario: A receives the lead, B takes over, C handles the
booking, and all three facts must survive.

None of it was enforced. Three separate gaps:

1. **No reassignment path existed at all.** `app.assign_lead` rejects any lead not in `new` status
   with the message "use reassignment" — pointing at an RPC that was never written. `REASSIGN_LEAD`
   was seeded and granted to four roles and enforced nowhere. The only way to hand a lead over was a
   direct `UPDATE` of `leads.assigned_user_id`, which writes no history: the first employee's
   involvement was simply overwritten. This is also one of the ~13 remaining write permissions in
   RPC-1.
2. **History could be rewritten.** `lead_assignments` had no triggers and `authenticated` holds
   `UPDATE` on it, so a row could be edited to name a different employee — worse than deletion,
   because it leaves a plausible timeline that is false.
3. **Nothing forced the lead and its history to agree.**

Separately, `app.create_customer` filled `first_registered_branch_id` from an optional parameter
defaulting to NULL, so even the branch fact canon 03 requires ("The system must record which branch
first registered a customer") was recorded only when a caller happened to pass it. There was no
column for the employee at all.

---

## Risks

Moderate. The guard trigger changes what a direct write to `leads` may do, which is the point, but it
also means any path that sets an assignee without recording it now fails — including fixtures and
future importers. That surfaced immediately: test 21's fixture broke, correctly, and was rewritten to
assign the way production does.

One consequence is worth stating plainly because it is permanent: **a lead can no longer be created
already-assigned in a single statement.** The history row has a foreign key to the lead, so the lead
must exist before its assignment can be recorded. This is not a workaround — it is the rule holding:
assignment is an act with a timestamp and an author, not an attribute a record is born with.
`app.create_lead` already takes no assignee, so no production path is affected.

---

## Supersedes / Depends On

Closes `REASSIGN_LEAD` from RPC-1's remaining set. Depends on `app.current_placement` (SPEC-137).
Implements canon 04 §Lead Assignment History and extends canon 03's first-registration rule to the
employee per the owner directive.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607051800_assignment_history_integrity.sql`
- `supabase/migrations/202607051900_customer_first_registration.sql`
- `supabase/tests/24_assignment_history_test.sql`
- `supabase/tests/21_read_scope_model_test.sql` (fixture only — it asserted on an assignment that can
  no longer exist unrecorded)
- `scripts/verify_database.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-140-assignment-history-integrity.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `app.process_lead_sla` — it already wrote history before updating the lead, so it satisfies the new
  guard unchanged; touching it would be change without cause

---

## Minimum Reading List

- `_ORVION_CANONICAL/04_lead_lifecycle.md` §SLA Escalation Rule and §Lead Assignment History
- `_ORVION_CANONICAL/03_company_structure.md` (first-registering branch)
- `_ORVION_CANONICAL/12_lead_statuses_and_rules.md` (terminal statuses)

---

## Implementation Steps

1. Freeze `lead_assignments`: forbid DELETE and forbid rewriting `lead_id` / `assigned_user_id` /
   `assigned_at` / `assigned_by` / `tenant_id`. `unassigned_at` and `is_current` stay updatable — that
   is how a row is closed.
2. Guard `leads`: an assignee may not change unless a current `lead_assignments` row names them.
3. Reorder `app.assign_lead` to write history before updating the lead.
4. Add `app.reassign_lead` — closes the outgoing assignment, opens the incoming one, refuses terminal
   leads and no-op handovers, emits `lead_reassigned`.
5. Add `customers.first_registered_user_id`, freeze it and `first_registered_branch_id`, and have
   `app.create_customer` fill both from the caller's placement.
6. Add `app.lead_origin` so first / current / count are answerable without a stored duplicate.
7. Verification check: test 24 drives the owner's A→B scenario and asserts every bypass fails.

---

## Acceptance Criteria

- [x] A lead can be reassigned through a governed RPC, and both employees remain in the timeline.
- [x] `app.lead_origin` reports the first employee after a handover, distinct from the current one.
- [x] Exactly one assignment is current after a handover; the previous is closed, not deleted.
- [x] History cannot be deleted or rewritten to name a different employee.
- [x] A direct `UPDATE` of `leads.assigned_user_id` without history fails.
- [x] Reassigning to the current holder is refused.
- [x] A customer records who first took them on, and it cannot be changed.
- [x] Clean `db reset` replays; full suite passes (`Files=24, Tests=189`); smoke passes.
- [ ] **UNVERIFIED — Primary.** The `supabase-primary` MCP disconnected and requires
      re-authorization, which cannot be done non-interactively. Not applied to Primary; parity not
      confirmed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Outcome: Complete

Both migrations applied. `db reset` replays 107 clean; suite `Files=24, Tests=189 ... PASS`; smoke
`ALL CHECKS PASSED`.

**The design choice worth recording is that the trigger guards rather than writes.** A writing
trigger — quietly inserting the history row whenever an assignee changes — was the obvious
alternative and is worse in two ways. It would have had to invent `assigned_by` and
`assignment_reason`, which only the caller knows, so either the record loses them or they get
smuggled through session settings. And it would have made the bypass path *succeed silently*, which
is exactly the failure mode canon 04 exists to prevent. A guard leaves the RPC as the author of the
record and makes the unrecorded path fail loudly.

Two defects were caught by existing guards rather than by review: `max(uuid)` does not exist in
Postgres (the migration failed to apply), and the three new trigger functions neither pinned
`search_path` nor revoked `PUBLIC EXECUTE` — test 05 and test 10 failed on both counts. That is those
tests working as designed on a change written by someone who knew the rule and still missed it.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Verdict: Confirmed Complete

Findings: the assertion that matters most is test 24's tenth — the direct `UPDATE` of
`leads.assigned_user_id` now raising `23514`. That exact statement was, until this CR, the *only* way
to reassign a lead, and it destroyed the first employee's record every time it ran. Everything else
in this change request is scaffolding around making that one statement impossible.

Test 21's fixture breaking was a genuine signal and not an inconvenience. It inserted a lead already
carrying an assignee with no timeline behind it — a state production can no longer reach. Fixing the
fixture rather than relaxing the trigger is what keeps the test honest: a fixture that could not exist
in production is not testing production.

`app.lead_origin` deliberately derives rather than stores. The earliest row in the timeline *is* the
first employee, and steps 1–2 are what make that derivation trustworthy; adding a stored
`originating_user_id` alongside it would have created a second source of truth that could disagree
with the history it summarises. The customer column is different and is stored, because a customer has
no assignment timeline to derive from.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state (local; Primary deployment outstanding).

---

## Notes

**Approval basis.** Owner directive 2026-08-24 §7 (lead lifecycle — "Do not overwrite historical
responsibility"), §8 (first employee — "permanently preserve … do not derive this later from the
current assigned employee"), and STEP 2 (remaining governed writes). Canon 04 already required the
same thing, so this is enforcement of settled rules rather than new policy.

**`leads.owner_user_id` and `leads.assigned_user_id` still hold the same value.** `app.assign_lead`
and `app.reassign_lead` both set them together, and canon 31 lists both without distinguishing them.
That is a genuine duplicate source of truth and it is **not** resolved here — resolving it means
deciding which one canon intends to keep, which belongs to the table-by-table audit (STEP 4) where the
same question can be asked of all eight tables carrying the ownership triple at once. Recorded rather
than guessed.
