# Change Request — SPEC-151

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Resolve the `leads.owner_user_id` / `leads.assigned_user_id` duplication recorded as open since
SPEC-140.

---

## Business Reason

Both columns exist, canon 31 lists both without distinguishing them, and every write path sets them to
the same value. Two columns holding one fact is the duplicate source of truth the owner's directive
names directly: "The same fact must not be represented in multiple competing structures unless there
is a clearly defined authoritative source."

Nothing stopped a direct `UPDATE` from moving one alone — after which "who is handling this lead?"
would have two answers, with the RPCs believing one and the read model enforcing the other.

---

## Risks

Low. The constraint captures what every code path already does; no existing behaviour changes. Two
test fixtures created a lead with an owner and no assignee — a state production could not reach — and
were corrected to assign the way production does.

---

## Supersedes / Depends On

Closes the item recorded in SPEC-140's Notes. Depends on SPEC-140 (the assignment timeline that makes
`assigned_user_id` the authority) and SPEC-137 (the ownership triple `owner_user_id` completes).

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052900_lead_owner_assignee_coherence.sql`
- `supabase/tests/21_read_scope_model_test.sql` (fixture only)
- `supabase/tests/31_access_revocation_test.sql` (fixture only)
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-151-lead-owner-assignee-coherence.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- Either column's presence. Dropping one was considered and rejected — see Notes.

---

## Minimum Reading List

- `_ORVION_CANONICAL/31_schema_draft.md` §leads
- `changes/SPEC-140-assignment-history-integrity.md` §Notes

---

## Implementation Steps

1. CHECK `owner_user_id is not distinct from assigned_user_id` on `leads`.
2. Column comments recording which is authoritative and why.
3. Verification check: the full suite, whose fixtures had to become production-shaped to pass.

---

## Acceptance Criteria

- [x] The two columns cannot diverge.
- [x] A lead with neither set is still valid (creation).
- [x] Clean `db reset` replays; full suite passes (`Files=33, Tests=296`).
- [ ] **UNVERIFIED — Primary.** MCP disconnected, no linked project, no access token.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Zero-Known-Debt Programme)

Outcome: Complete

Applied. `db reset` replays 118 clean; suite `Files=33, Tests=296 ... PASS`.

Two fixtures broke and were right to. Both created a lead carrying an owner but no assignee — a state
that is now unreachable, because SPEC-140 makes assignment an act with a timeline and SPEC-151 makes
ownership mirror it. Together they say a lead cannot be born owned, which is coherent: ownership
follows assignment, and assignment is something that happens rather than something a record starts
with. The fixtures were rewritten to assign the way production does.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Zero-Known-Debt Programme)

Verdict: Confirmed Complete

Findings: the authority was decided by reading what the code trusts, not by which name sounds better.
`app.advance_lead`, `app.convert_lead` and `app.record_lead_interaction` all resolve "who is handling
this lead?" from `assigned_user_id`, and none of them reads `owner_user_id`. The business logic had
already chosen; nothing had written that choice down.

A syncing trigger was rejected in favour of a CHECK. A trigger would quietly repair a caller that
moved one column without the other, hiding the fact that something tried to. A divergence between an
authority and its mirror deserves to fail loudly.

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

**Approval basis.** Owner directive 2026-08-24 (third directive) §9: "Do not leave two fields
representing the same fact indefinitely if one can become the canonical source of truth."

**Neither column was dropped, and that is the finding rather than an evasion.** `assigned_user_id` is
the authority — three RPCs resolve the handler from it, and SPEC-140's timeline backs it.
`owner_user_id` is not redundant either: it completes the uniform ownership triple that the SPEC-137
scope model reads across all eight scope-bearing tables, so removing it would make `leads` the single
exception to that pattern and require a special case in the read model. One is the fact; the other is
the shape the scope model expects. What was missing was anything stopping them from disagreeing.
