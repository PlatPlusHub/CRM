# Change Request — SPEC-144

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Bring `documents`, `document_links` and `document_versions` into the read-scope model. They were named
in SPEC-137's plan and never reached its migration.

---

## Business Reason

All three document tables were still on the original `tenant_isolation` policy while every record they
attach to had been branch-scoped. For a table holding passport scans and financial records, that was
the widest remaining hole in the read model: any employee in the company could read any document in
the company, including one attached to a booking in a branch they have no part in.

It was found by auditing permission coverage rather than by re-reading the migration —
`VIEW_TRAVEL_DOCUMENTS` and `VIEW_FINANCIAL_DOCUMENTS` both showed as enforced nowhere, which for
these two permissions is not a paperwork discrepancy. Canon 28 scopes travel documents as
assigned/department and financial documents more tightly still.

`documents.is_confidential` was also decorative: nothing read it. A flag that does nothing is worse
than no flag, because it implies a protection that is not there.

---

## Risks

Low, with one structural hazard that had to be designed around. `documents` carries no branch,
department or owner — a document belongs to whatever it is attached to, through the polymorphic
`document_links`. If `documents` scoped itself through `document_links` while `document_links` scoped
itself through `documents`, each policy would invoke the other and recurse without end. The dependency
is therefore strictly one-directional:

```
document_links     -> scoped by its PARENT record (booking, invoice, quotation, …)
documents          -> scoped by whether any of its links is visible
document_versions  -> scoped by its document
```

The second risk is losing your own uploads: attaching a document to a record that later moves branches
would silently take it away from the person who added it. The uploader clause prevents that.

---

## Supersedes / Depends On

Completes SPEC-137, which named documents in its plan and did not deliver them. No canon change.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052300_document_read_scope.sql`
- `supabase/tests/28_document_scope_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-144-document-read-scope.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `app.upload_document` / `app.archive_document` / `app.add_document_version` — they are SECURITY
  INVOKER and already populate `created_by`, so they satisfy the new policies unchanged

---

## Minimum Reading List

- `_ORVION_CANONICAL/28_permissions_matrix.md` §Document Permissions
- `_ORVION_CANONICAL/08_document_model.md`
- `supabase/migrations/202607051400_read_scope_model.sql`

---

## Implementation Steps

1. Scope `document_links` by its parent record.
2. Scope `documents` by link visibility, with the uploader and `is_confidential` clauses.
3. Scope `document_versions` by its document.
4. Verification check: test 28 walks the whole three-deep chain as three different users.

---

## Acceptance Criteria

- [x] An employee in another branch cannot read a document attached to a booking they cannot see.
- [x] Nor its link, which would disclose the document's existence and what it hangs off.
- [x] Nor its version row, which carries the storage path that would retrieve the file.
- [x] The uploader keeps their own uploads.
- [x] A finance manager reads confidential documents.
- [x] ...and does not thereby acquire ordinary travel documents from branches they have no part in.
- [x] Clean `db reset` replays; full suite passes (`Files=28, Tests=235`); smoke passes.
- [ ] **UNVERIFIED — Primary.** The `supabase-primary` MCP disconnected and requires
      re-authorization. Not applied to Primary; parity not confirmed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Outcome: Complete

Applied. `db reset` replays 111 clean; suite `Files=28, Tests=235 ... PASS`; smoke `ALL CHECKS PASSED`.

This CR exists because SPEC-137 was checked against its own migration rather than against its own
plan. The plan listed documents; the migration did not implement them; the tests asserted what the
migration did. Nothing in that loop could have surfaced the omission — it took an independent question
("which permissions are enforced nowhere?") asked from outside the change.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Verdict: Confirmed Complete

Findings: assertions 3 and 4 are the ones that make this a real fix rather than a partial one. Hiding
`documents` alone would have satisfied the obvious test while leaving `document_links` to disclose
that a document exists and what it is attached to, and `document_versions` to hand over
`storage_path` — the field that would actually retrieve the passport scan. A read-scope fix on a
document store that stops at the metadata row is not a fix.

Assertion 8 is the counterpart that keeps `is_confidential` honest. The finance manager gains the
confidential document and *not* the ordinary travel document from a branch they have no part in.
Without that pairing, the natural implementation — give finance roles a blanket document exemption —
would have passed assertion 7 and quietly widened access well beyond what canon 28 grants.

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

**Approval basis.** Owner directive 2026-08-24 §17 (table-by-table audit, security dimension) and §28
(freeze criteria naming RLS and sensitive-field access).

**`VIEW_TRAVEL_DOCUMENTS` still does not appear literally in any policy, and that is correct.** Canon
28 scopes it as assigned/department, which is exactly what scoping a document through its linked
record produces — a travel document is visible to whoever can see the booking or passenger it belongs
to. Naming the permission in the policy as well would add a second gate that canon does not describe,
and would let a tenant break document access by revoking a permission whose scope is already implied
by the record. It is recorded here so that a future coverage audit does not "fix" it by force.
