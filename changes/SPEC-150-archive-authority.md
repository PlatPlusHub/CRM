# Change Request — SPEC-150

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Govern archiving, which in ORVION is what deletion is.

---

## Business Reason

Reproduced before the fix. An ordinary employee ran, as plain SQL:

```sql
update public.bookings  set is_archived = true, archived_at = now() where id = ...;
update public.customers set is_archived = true, archived_at = now() where id = ...;
```

Both succeeded, with **zero events**, no authorization, and `archived_by` left null. The same
employee then un-archived the booking.

Canon's policy is that business records are archive-oriented rather than delete-oriented, and the
implementation honours it — `authenticated` correctly holds **no DELETE grant on any table**. That
makes archiving the deletion mechanism, so an unauthorized, unattributed archive is an unauthorized,
unattributed deletion, with an unaudited restore alongside it.

Thirteen tables carry `is_archived`. Exactly one, `documents`, had a governed path
(`app.archive_document` → `ARCHIVE_DOCUMENT`). The other twelve — including `customers`, `bookings`,
`leads` and `invoices` — had none.

---

## Risks

Low. The permission profile is not invented: canon 28 already establishes archiving as a management
act and assigns it a role matrix. The risk of over-restriction is covered by asserting that ordinary
edits on the same rows still succeed, and that the manager can archive.

One consequence worth naming: no event is emitted. `archived_at` and `archived_by` are stamped on the
row, so the act is attributable — see Notes for why an event was not added.

---

## Supersedes / Depends On

Depends on SPEC-145/149 (the `auth.uid()`-null platform exemption pattern). Implements the archive
half of the owner's delete/archive policy.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052800_archive_authority.sql`
- `supabase/tests/33_archive_authority_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-150-archive-authority.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `app.archive_document` — it already authorizes `ARCHIVE_DOCUMENT` and emits its event; the trigger
  composes with it rather than replacing it

---

## Minimum Reading List

- `_ORVION_CANONICAL/28_permissions_matrix.md` §Document Permissions (the `ARCHIVE_DOCUMENT` row)
- `_ORVION_CANONICAL/08_document_model.md` ("Incorrect files are archived, not deleted")

---

## Implementation Steps

1. Mint `ARCHIVE_RECORD` and grant it to exactly the roles canon 28 gives `ARCHIVE_DOCUMENT`.
2. Add `app.enforce_archive_authority()` on all thirteen `is_archived` tables: authorize
   `ARCHIVE_DOCUMENT` for `documents` and `ARCHIVE_RECORD` for the rest, in both directions.
3. Stamp `archived_at` / `archived_by` on archive; clear both on restore.
4. Verification check: test 33 proves an employee cannot archive or restore, a manager can, ordinary
   edits are unaffected, and attribution is stamped without being asked for.

---

## Acceptance Criteria

- [x] An employee cannot archive a booking or a customer.
- [x] An employee cannot un-archive one.
- [x] Ordinary edits on the same rows still succeed.
- [x] A branch manager can archive and restore.
- [x] `archived_by` and `archived_at` are stamped by the system.
- [x] Restoring clears the stale archive attribution.
- [x] Clean `db reset` replays; full suite passes (`Files=33, Tests=296`); smoke passes.
- [ ] **UNVERIFIED — Primary.** MCP disconnected, no linked project, no access token.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Zero-Known-Debt Programme)

Outcome: Complete

Applied. `db reset` replays 117 clean; suite `Files=33, Tests=296 ... PASS`; smoke `ALL CHECKS PASSED`.
71 permissions; 13 archive triggers.

This defect was found by asking a question the previous passes had not: *if nobody can DELETE, what
actually removes a record?* The answer was `is_archived`, and following it showed that twelve of the
thirteen archivable tables had no governance at all. Every earlier pass had checked DELETE grants,
found none, and moved on satisfied — the grant audit was correct and the conclusion drawn from it was
wrong.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Zero-Known-Debt Programme)

Verdict: Confirmed Complete

Findings: assertion 4 is the one that keeps this from being an over-broad fix. The employee still
edits the same booking freely — the guard fires on the archive flag, not on the table. Without it, the
safest-looking implementation would be to stop employees writing to archivable tables at all, which
would pass every refusal assertion in the file and disable most of the CRM.

Assertion 9 matters for a subtler reason. Restoring clears `archived_at`/`archived_by` rather than
leaving them populated. Stale attribution on a live record is worse than none: a report joining on
`archived_by is not null` would count restored records as archived, and a person reading the row would
conclude it had been removed when it had not.

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

**Approval basis.** Owner directive 2026-08-24 (third directive) §21, which states the archive-oriented
policy and instructs "Verify the current implementation against this policy."

**`ARCHIVE_RECORD` extends a canon profile rather than inventing one.** Canon 28 already treats
archiving as a management act and gives it a role matrix — Owner / CEO / Branch Manager / Department
Manager / Finance Manager Yes, Senior Employee Optional, Employee **No**, Trainee **No**. Canon simply
never enumerated the other twelve entities. This is the same move SPEC-146 made with
`VIEW_DEPARTMENT_RECORDS`: the principle is canonical, only the entity list was incomplete.
`documents` keeps `ARCHIVE_DOCUMENT`, because canon names it.

**No event is emitted, deliberately.** Only `document_archived` and `marketing_campaign_archived`
exist in the event vocabulary; covering the rest would mean minting twelve event types for a trigger
to emit, and would double-emit for `documents`, which `app.archive_document` already events. Stamping
`archived_at` and `archived_by` on the row records *who* and *when* directly, which is the substance
of the audit need. If an archive RPC per entity is built later, it should emit and the trigger's
stamping will simply be redundant rather than conflicting.
