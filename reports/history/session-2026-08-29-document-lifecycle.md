# ORVION — The Document Lifecycle Machine Canon Defined and Nobody Wired, and the Passport a Trainee Could Freeze

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: DOC-LC-1 (migration `202607057200`), test `69_document_lifecycle_test.sql`, 6 new HTTP
assertions in `verify_storage_end_to_end.ps1`, a repaired assertion in
`54_transition_permission_parity_test.sql`. DOC-LC-2 and DOC-LC-3 recorded. API-3 30 → 29.
Status: Complete; deployed to Primary, verified, committed and pushed.

**Branch:** `main` · **Start HEAD:** `6f9b429` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Why this package, and what changed about it on contact

DOC-LC-1 was queued as "derivable, bounded — wire canon 26's Document Lifecycle machine into
`app.status_transitions`; permissions derivable from the existing writers." Two of those three claims
survived discovery. The third did not, and that is the interesting part.

---

## 2. The defect, reproduced before anything was written

`app.status_transitions` held **zero** rows for `documents`. The table does carry a guard —
`app.enforce_archive_authority`, which charges `ARCHIVE_DOCUMENT` — but its second statement is:

```sql
if new.is_archived is not distinct from old.is_archived then return new; end if;
```

**It watches the boolean.** `lifecycle_status_code` is a different column, governed by nothing except
`enforce_catalog_codes`, which asks whether a code *exists* in the catalog and never whether the
*move* is legal.

Reproduced as a `trainee`, with the positive control that makes it conclusive:

```
baseline                 : lifecycle=active   is_archived=false
trainee ARCHIVE_DOCUMENT : false
trainee SEES the doc     : rows=1                        <- not a vacuous denial
app.archive_document(...): ERROR permission denied: ARCHIVE_DOCUMENT
update documents set lifecycle_status_code='archived' : 1 row
after                    : lifecycle=archived  is_archived=false
```

The RPC refusing in the same transaction the direct write succeeded is exactly FIN-6's shape, one
domain over: **a guard that was present, working, and watching the wrong column.**

### It is not cosmetic

`lifecycle_status_code = 'archived'` is read as a refusal condition by **both** document write paths:

- `app.add_document_version` → *"document is already archived"* → no further version, ever
- `app.archive_document` → *"document is already archived"* → **the legitimate archive path is
  blocked too**

So a trainee holding no write permission at all could **permanently freeze any document they could
see**, and leave `is_archived = false` so nothing reading the boolean reported it as archived. In an
agency whose commonest way to lose a departure is an expired passport, that is a passport nobody can
re-version and nobody can properly retire.

---

## 3. What was registered — and what was deliberately not

Canon 26 names three states and three transitions. **Two were registered.** The omission is the
considered part of this package.

| Transition | Registered | Why |
|---|---|---|
| `active → archived` | **yes**, ARCHIVE_DOCUMENT | `app.archive_document` performs it and charges exactly that — read out of the function, not chosen |
| `superseded → archived` | **yes**, ARCHIVE_DOCUMENT | same function: it refuses only when *already* archived, so it archives from any other state |
| `active → superseded` | **no** | **nothing produces that state** |

**`documents.lifecycle_status_code = 'superseded'` has no producer.** Checked against every writer of
the column — `add_document_version`, `archive_document`, `expiring_documents`, `financial_documents`,
`upload_document`, `upload_subscription_payment_proof` — and not one sets it. `add_document_version`
moves `current_version_id` and flips `is_current` on the **version** rows; the **document** stays
`active`.

That is not an accident. SPEC-110 recorded the divergence as an Engineering Observation in Phase 7
("canon-26 'new version → superseded' diverges from the frozen `current_version_id` intra-document
versioning design; document-level supersede reserved for a future explicit op"), and canon 32's
Phase 7 entry still carries it.

**And the event *is* produced** — by `documents_emit_superseded`, an AFTER UPDATE trigger keyed on
`current_version_id` changing. So in the implemented design **"supersede" is an event about the
version pointer, never a document-level status.**

Registering `active → superseded` would therefore have permitted direct DML to move a document into
a state nothing writes and nothing reads — inventing a capability to satisfy a document. Recorded as
**DOC-LC-2** and left to the owner, because whether a *document* supersedes (as opposed to a version)
is a question about how an agency thinks of its records.

*(A detector note worth keeping: my first search for the event's producer scanned function bodies and
returned NONE. The producer is a **trigger argument**, not text in any function. Searching for
producers by function body is a detector shape that cannot see trigger-driven emission.)*

**Fail-closed came free.** `enforce_status_transition` raises 23514 for any unregistered move, so
`archived → active` is now refused too — canon lists no way back, and `enforce_archive_authority`
says of its own column that a control letting anyone un-archive would make the archive meaningless.

---

## 4. Proving the fix did not break the business

The assertion that matters most is not a denial. `ARCHIVE_DOCUMENT` is held by
`branch_manager, ceo, department_manager, finance_manager, owner` — **not** by `employee`,
`senior_employee` or `trainee`. Since `app.archive_document` already charged it, **no role gained or
lost anything**; the trigger charges what the RPC always charged.

A guard that stopped the trainee *and* the manager would have passed every denial in this package
while breaking document retirement entirely. So assertion 9 archives as a real manager and asserts it
works, before any refusal is tested.

---

## 5. DOC-LC-3 — found by continuing to look after the fix

With DOC-LC-1 shipped, an **authorized** holder can still produce the split state:

```
archived via RPC          : archived/true
update documents set is_archived = false   (ARCHIVE_DOCUMENT holder)
after                     : archived/false
```

`documents` carries **two representations of one concept**. Both now cost `ARCHIVE_DOCUMENT`, so no
unauthorized path splits them — this is an integrity defect, not an escalation.

**Not fixed here, and the reason is not convenience.** Fixing it requires deciding whether
un-archiving exists at all, and two authorities disagree: canon 26 lists no transition back into
`active`, while `enforce_archive_authority` states in terms that *"restoring is the same authority as
archiving"*. Synchronizing the fields in either direction deletes one of those positions. That is a
canonical contradiction — an owner call, not an engineering one — so it is recorded and **pinned by
assertions 18–19**, because a defect that is asserted cannot change unnoticed.

---

## 6. A guard repaired on the way through

`54_transition_permission_parity_test.sql`'s final assertion checked that each named RPC owner really
writes the status column — using a hardcoded `'lead_status_code\s*='`. Every exclusion was a `leads`
row when it was written. Adding the first non-`leads` exclusion would have failed it for the wrong
reason. The column is now **derived per table** from `app.status_transitions.status_column`, the same
source the trigger reads.

Third instance of that class in this one file's history: SEC-1b's trigger-timing ceiling, this file's
own one-function regex, and now this.

---

## 7. HTTP — because the reproduction was a table write

`archive_document` had **no HTTP evidence at all** (API-3), which is a poor thing to be true of the
endpoint that retires a customer's passport. Six assertions added to
`verify_storage_end_to_end.ps1`, including the real-world attack shape — PostgREST serves **tables**,
so `PATCH /rest/v1/documents` is the door a browser client actually has, and it was the door with no
state machine behind it:

- `active → superseded` via PATCH → refused, **even for the owner** (DOC-LC-2 over the wire)
- non-mutation after that refusal
- `rpc/archive_document` → 200 (its first HTTP evidence)
- both representations moved together
- `archived → active` via PATCH → refused
- non-mutation again

**API-3: 30 → 29 uncovered endpoints**; contract regenerated to 42 of 71 with HTTP evidence.

---

## 8. Verification

| Axis | Result |
|---|---|
| Migrations | **161** — repository, local, Primary (`202607057200`) |
| Ledger fingerprint | `03509b0f54d600f4ed57fc867e5331bc` — read independently from both |
| Function surface | `d98abbdd9aea724630f2d97f91a21b08` — unchanged, correctly (no function bodies altered) |
| Triggers | **230** both sides |
| pgTAP **Pass A** | **69 files / 835 assertions / 0 failures** |
| pgTAP **Pass B** | **69 files / 835 assertions / 0 failures** |
| End-to-end HTTP | **243/243** — storage **51** · api 29 · branches 26 · roles 27 · lifecycle 72 · care 38 |
| Post-HTTP surface hash | `d98abbdd…` — PAR-2 still holding |
| Smoke | `ALL CHECKS PASSED (75 tables …)` — CHECK 5g raised 10 → 11 triggers |
| Repository guard | **CLEAN**, 12 checks |
| Parity guard | **CLEAN**, exit 0, Primary values read live |

Ledger normalised after `apply_migration` stamped its own version (`20260829133651` →
`202607057200`), per GUARD-1.

---

## 9. Classification

**PROVEN DEFECT (fixed)** — DOC-LC-1 (High): `documents.lifecycle_status_code` ungoverned on the
direct path.

**BLOCKED — BUSINESS DECISION (new)** — DOC-LC-2: does a *document* supersede, or only a version?

**BLOCKED — CANONICAL CONTRADICTION (new)** — DOC-LC-3: does un-archiving exist? Canon 26 and
`enforce_archive_authority` disagree.

**GUARD REPAIRED** — `54_transition_permission_parity_test`'s hardcoded status column.

**PROGRESS** — API-3: 30 → 29.

---

## 10. Next executable step

**API-3**, continuing endpoint by endpoint — `create_journal_entry` and `merge_customer_identity`
next; 29 of 71 still without HTTP evidence. Then Batch 6's remaining engineering items
(`notification_deliveries` has no producer; the Employee/Supplier/Branch 360 primitives; the
table-by-table sweep across 75 tables).

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut.

**The single owner decision that unblocks the most: SEC-1**, the write-path architecture.
