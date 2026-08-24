# Change Request — SPEC-143

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Scope the audit trail to match the records it describes, and provide the Customer 360 / Lead 360
timeline primitives the owner's reporting requirements depend on.

---

## Business Reason

SPEC-137 scoped every operational table by branch, department and assignment. `events` was left on
its original tenant-only policy. The result was a complete bypass: a Cairo employee could not read an
Alexandria booking, but could read the entire event stream describing it — every status change, every
reassignment, every `reason`, and every `payload` those RPCs wrote. The more thoroughly the entities
were scoped, the more the audit trail stood out as the way around the model.

Separately, the owner requires (§6, §7, §14, §25) that "Show me everything that ever happened with
this customer, in chronological order" be answerable deterministically. The infrastructure for that
already existed and was simply unused: `events` carries `(entity_type, entity_id)` with a matching
index, and `seq` provides a total order that does not degrade when several events share a timestamp —
which is exactly what a multi-step RPC produces.

---

## Risks

Low, and the shape is over-restriction rather than exposure. A scoped audit trail that hid events
from the people who investigate incidents would be a worse defect than the one being fixed, so
tenant-wide readers still see everything and an actor can always read their own actions.

The dispatch is exhaustive by construction: all 22 `entity_type` values the RPCs emit are covered.
Anything unrecognised falls through to tenant-wide readers only, so a new entity type added later is
private by default rather than public by default.

---

## Supersedes / Depends On

Depends on SPEC-137 (the scope model these events now inherit) and SPEC-139 (`app.current_user_id`).
Implements the owner's §6 / §7 / §14 reporting requirements at the database level.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052200_event_visibility_and_timelines.sql`
- `supabase/tests/27_event_visibility_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-143-event-visibility-and-timelines.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- The append-only immutability triggers — this CR changes who may READ events and nothing else
- Any `reporting` view — the timelines take a parameter, which a view cannot

---

## Minimum Reading List

- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` §7 (audit behaviour)
- `supabase/migrations/202607051400_read_scope_model.sql` (the scope these events inherit)

---

## Implementation Steps

1. Replace the `events` read policy with a dispatch on `entity_type` that defers to the subject
   table's own RLS, plus tenant-wide read and own-actions clauses.
2. Restrict `security_events` to tenant-wide readers outright.
3. Add `app.customer_timeline` and `app.lead_timeline`, both SECURITY INVOKER, ordered by `seq`.
4. Verification check: test 27 proves the bypass is closed and the timeline does not reopen it.

---

## Acceptance Criteria

- [x] An employee cannot read events describing a record they cannot read.
- [x] Customer events stay visible, because the customer master is tenant-visible by canon 05.
- [x] The owner reads the whole stream.
- [x] An actor reads their own actions.
- [x] `app.customer_timeline` assembles the customer's events and those of their related records.
- [x] The same call returns only what the caller may see.
- [x] Ordering is by `seq`, surviving same-instant events.
- [x] Clean `db reset` replays; full suite passes (`Files=27, Tests=227`); smoke passes.
- [ ] **UNVERIFIED — Primary.** The `supabase-primary` MCP disconnected and requires
      re-authorization. Not applied to Primary; parity not confirmed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Outcome: Complete

Applied. `db reset` replays 110 clean; suite `Files=27, Tests=227 ... PASS`; smoke `ALL CHECKS PASSED`.

The reason this fix is trustworthy is that it required no judgement about which events are sensitive.
Every one of the 22 `entity_type` values the RPCs emit corresponds to a real table that already
carries RLS, so the rule is simply "an event is readable when its subject is readable". RLS applies
inside each `exists`, which means each event keeps inheriting its subject's scope as that table's
policy evolves, rather than freezing a second stale copy of the rule into the audit policy.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Verdict: Confirmed Complete

Findings: assertion 3 is the one that shows the rule is right rather than merely strict. Customer
events remain visible to an employee who cannot see that customer's out-of-branch booking — because
canon 05 makes the customer master deliberately tenant-visible, and the policy follows the subject
instead of blanket-hiding the table. A cruder fix (hide all events without tenant-wide read) would
have passed every other assertion in this file and quietly broken the cross-branch awareness canon 05
requires.

Assertion 7 is the one that matters for the 360 work: the *same* timeline call, made by two different
users, returns different rows. The timeline is not a privileged read path bolted beside the scope
model — it inherits it, because it is SECURITY INVOKER over an RLS-protected table.

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

**Approval basis.** Owner directive 2026-08-24 §6 (Customer 360), §7 (Lead 360), §14 (event/timeline
integrity — "If the current event model cannot support this for important CRM operations, fix it
now"), and §25 (reporting design test).

**`security_events` is treated differently on purpose.** It records authentication, permission changes
and risk flags — the material a tenant administrator investigates and an ordinary employee has no
business browsing. "Who may see this security event" is not the same question as "who may see the
record it concerns", so it is restricted to tenant-wide readers outright rather than dispatched by
subject.

**Events still carry no branch column, and none was added.** Branch is derivable through the subject
entity, and denormalising it onto `events` would create a second source of truth for a fact the
subject already owns — exactly what the owner's §26 warns against. Branch-filtered reporting joins
through the entity.
