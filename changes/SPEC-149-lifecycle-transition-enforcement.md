# Change Request — SPEC-149

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Make business-critical lifecycle transitions impossible to bypass with ordinary employee DML.

---

## Business Reason

Reproduced before it was fixed. An authenticated employee who does **not** hold `ISSUE_BOOKING` ran:

```sql
update public.bookings set booking_status_code = 'issued' where id = ...;
```

The booking went from `draft` straight to `issued` — skipping `pending_approval`, `confirmed` and
`in_progress` — with **zero events emitted**, no authorization, no transition validation and no
negative-balance risk check. Every `advance_*` RPC was correct; nothing obliged anyone to call one.
That made the state machines decorative on the direct path, which was the largest remaining
Foundation defect and the second of the two blockers recorded at the previous gate.

---

## Risks

The stated objection to a transition trigger is that it duplicates the maps inside the RPCs — a
second source of truth that will eventually disagree. That objection is answered the way ORVION
already answers it twice: `07_event_vocabulary_registry_test` and `08_status_vocabulary_registry_test`
both scan `pg_proc` and fail when a function drifts from a registry. Test 32 does the same here. The
rules stay in the RPCs, the table mirrors them, and a mechanical guard makes silent divergence
impossible. Every row was extracted from `pg_proc`, not composed by hand.

Second risk: over-restriction. A guard that blocked legal transitions would be an outage. Every
refusal in test 32 is paired with the corresponding permitted case, and an ordinary edit that does
not touch the status is asserted to pass untouched.

**What this does NOT do, stated plainly.** The trigger does not re-implement the RPCs. It answers two
questions: is this `from -> to` a transition the business recognises, and does the caller hold the
capability that governs it. Side effects — events, closure reasons, risk flags, cost locking,
timestamps — remain the RPC's work, and a direct write still skips them. Direct DML is therefore
restricted to *legal, authorized* transitions rather than made equivalent to the RPC. The RPC remains
the only complete path, and that is the honest boundary of what a trigger can guarantee.

---

## Supersedes / Depends On

Closes the lifecycle half of SEC-1/RPC-1. Depends on SPEC-145 (the `auth.uid()`-null platform
exemption pattern) and on canon 26.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052700_lifecycle_transition_enforcement.sql`
- `supabase/tests/32_lifecycle_transition_test.sql`
- `scripts/verify_database.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-149-lifecycle-transition-enforcement.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- Every `app.advance_*` RPC — they remain the author of the rules. Rewriting them to read the registry
  would be a larger change with no security benefit, and would remove the independent second opinion
  the drift guard relies on.

---

## Minimum Reading List

- `_ORVION_CANONICAL/26_state_machines.md`
- `supabase/tests/08_status_vocabulary_registry_test.sql` (the registry + drift-guard pattern)
- `supabase/migrations/202607052400_financial_write_authority.sql` (the platform exemption)

---

## Implementation Steps

1. Create `app.status_transitions` in the non-API `app` schema and populate it from the maps extracted
   from `pg_proc`.
2. Add `app.enforce_status_transition()` and attach it to the ten governed tables.
3. Verification check: test 32 proves the bypass is closed, that validity and authority fail
   independently, and that no app function can write a status the registry does not recognise.

---

## Acceptance Criteria

- [x] `draft -> issued` by direct SQL is refused.
- [x] The booking is left untouched rather than half-moved.
- [x] A legal transition by an entitled user still succeeds.
- [x] A legal transition by an unentitled user is refused on **authority** (42501).
- [x] An illegal transition is refused on **validity** (23514) even for an entitled user.
- [x] An edit that does not move the status is unaffected.
- [x] No app function can write a status the registry does not recognise.
- [x] Clean `db reset` replays; full suite passes (`Files=32, Tests=287`); smoke passes.
- [ ] **UNVERIFIED — Primary.** MCP disconnected, no linked project, no access token.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Zero-Known-Debt Programme)

Outcome: Complete

Applied. `db reset` replays 116 clean; suite `Files=32, Tests=287 ... PASS`; smoke `ALL CHECKS PASSED`.
104 transitions across 10 tables.

**The registry was wrong on its first build, and the existing suite caught it immediately.** Built
from the `advance_*` RPCs alone, it failed test 24 on the first run: `app.assign_lead` performs
`new -> assigned` and is not an `advance_*` function at all. Transition-owning logic turned out to
live in three further RPCs — `assign_lead`/`assign_lead_round_robin`, `record_lead_interaction` and
`convert_lead` — and each addition was confirmed against canon 26's Lead State Machine "Normal Flow"
(`new -> assigned -> contacted -> qualified -> ... -> won -> converted`) rather than inferred from the
code alone.

That failure changed the drift guard's design. Scanning only functions named like transition RPCs
would have repeated the same mistake, so assertion 11 scans **every** app function for a status-literal
assignment.

A second defect surfaced in testing: the trigger was initially SECURITY INVOKER and could not read
`app.status_transitions`, which `authenticated` has no privilege on. It failed with `42501 permission
denied for table status_transitions` — and one assertion **passed anyway**, because it expected 42501
and got 42501 for entirely the wrong reason. Made SECURITY DEFINER; the caller's identity is still
resolved through `auth.uid()`, which a definer context does not change.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Zero-Known-Debt Programme)

Verdict: Confirmed Complete

Findings: assertions 6 and 8 are the pair that matters. The same table, the same user class, two
different error codes — `42501` when the transition is legal but the caller lacks the capability, and
`23514` when the transition is not legal at all, even for a caller who holds everything. A guard that
collapsed those into one check would look correct and would be wrong in one direction or the other:
either it would let an authorized user skip states, or it would refuse a legitimate transition for the
wrong reason and be debugged as a permissions problem.

Assertion 9 is the counterweight. Without it the safest-looking implementation — refuse any UPDATE
that touches a governed table — would pass every other assertion in the file and make the CRM
unusable.

The first draft of assertion 5 asserted that the *employee* could advance the booking, and failed.
That was the role model working exactly as canon 28 describes: `employee` holds no booking capability
at all. The assertion was rewritten around the branch manager rather than the guard being loosened.

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

**Approval basis.** Owner directive 2026-08-24 (third directive) §20, which names the exact bypass
and instructs: "Determine the correct enforcement mechanism from evidence. Do not invent an
architecture merely for elegance."

**Why not the alternatives.** Revoking `authenticated` DML and routing every write through an RPC was
rejected because 35 tables still have no RPC — it would make those entities unusable. Detecting "did
this come through an RPC" was rejected because every signal available to a trigger is forgeable by the
caller: `set_config` is public, and the RPCs are deliberately SECURITY INVOKER so that RLS applies to
them, which rules out distinguishing by `current_user`. Transition validation is what canon 26 already
defines, so it is the mechanism the evidence points to rather than the most elegant one available.
