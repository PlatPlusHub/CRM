# ORVION — Twenty Tables Let You Sign a Colleague's Name

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migration `202607056400`, test `61_created_by_is_derived_test.sql`, and a widened
PUBLIC-EXECUTE guard in `10`.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `a7250be` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Found by sweeping the class, not by tripping over an instance

With the directive's named packages exhausted, the remaining work was §14's system-wide sweep. One
of its classes is *caller-controlled security values*. The query was blunt: for every table
`authenticated` may INSERT, list the columns that name an actor, and say whether any trigger derives
them.

| column | derived? |
|---|---|
| `archived_by` (10 tables) | yes |
| `document_versions.uploaded_by` | yes |
| `approval_requests.requested_by` | yes — FIN-4 |
| **`created_by` (20 tables)** | **no** |

Every `app.*` RPC sets `created_by` from the session. Direct DML did not have to. So any tenant user
could create a customer, a booking, an invoice or a payment **attributed to a colleague**.

This is FIN-4's defect exactly — the same shape, the same principle — recurring across twenty tables
instead of one column. FIN-4 was found by reading one policy; this was found by asking the same
question of the whole schema.

### On `documents` it is not only history

`documents.scope_isolation` reads `created_by = current_user_id()` as one of its **visibility
grants**. On that table the column is load-bearing for authorization, not merely for the audit
trail — a forged value would be an authorization value.

---

## 2. The fix, and the half that is easy to leave out

`app.derive_created_by()` follows WP-00's ratified shape — **DERIVE, DO NOT VALIDATE** — so the
forgery is unrepresentable rather than refused. On INSERT the column becomes
`app.current_user_id()`, whatever the caller wrote.

It is also **immutable on UPDATE**, and that half matters: deriving only on INSERT would leave the
value editable a moment later, which closes nothing. That is safe only because **no `app.*` or
`public.*` function updates the column anywhere** — checked against every function body before the
trigger was written, not inferred from the name.

Session-less platform paths (provisioning, cron, the integration role) keep the attribution they
set: exempt from the check, never from the record.

### Deliberately left out, and recorded rather than swept in

`invoices.voided_by`, `journal_entries.voided_by`, `approval_requests.reviewed_by`, and
`subscription_payment_proofs.reviewed_by` / `uploaded_by`. Those are **action** attributions —
stamped when the action happens, not when the row is created — so an insert-time derivation would be
wrong for them. Sweeping them in because they matched a regex is how a fix becomes a defect.
Recorded as **ATTR-2**, engineering, no decision required.

---

## 3. A second guard that was narrower than its claim

The same sweep checked PUBLIC grants and found one: `public.moddatetime`. It is Supabase's own,
owned by `supabase_admin`, and not ORVION's ACL to manage — so not a defect.

What *was* a defect is that `10_grant_model_test.sql` would not have caught an ORVION function with
the same problem. Its PUBLIC-EXECUTE assertion covered the **`app` schema only** — leaving `public`
unchecked, which is where API-1 put all 74 endpoints and where `pg_default_acl` grants
`anon`/`authenticated` EXECUTE on new functions by default (SPEC-124's class).

It now covers both, excluding extension-owned functions by `pg_depend` membership rather than by
name, so a future extension is handled and a future ORVION function is not.

That is the third guard this session found checking less than it claimed, after the transition
parity test (one function out of ten) and the SEC-1 capability detector (one function name). The
pattern is worth naming: **a guard written against the first instance takes that instance's shape,
and the shape is the bug.**

---

## 4. Tests

Suite **60 files / 700 → 61 files / 708 assertions**, 0 failures, green fresh and with all five HTTP
suites' residue. HTTP **179/179**, unchanged.

`61_created_by_is_derived_test.sql` (8) — the employee **can** write the row, so the assertion is
about attribution rather than permission; they name a colleague and the row is attributed to the
actual author; the value proven immutable on UPDATE; `documents` proven separately because there it
is an authorization value; the session-less path proven to keep its own attribution; and the class
pinned — every insertable table with a `created_by` column must carry the trigger, with a positive
control that twenty actually do.

One draft assertion of mine was discarded before it ran: a `lives_ok` on `upload_document` against a
booking the fixture had not created, annotated "expected to be the failing half". A test written to
fail is not a test.

---

## 5. Environment, parity and guards

| Axis | Value |
|---|---|
| Migrations | **153** — repository, local, Primary |
| Fingerprint | **`63dba916b60bfc75d5c47b79c8bfe9f0`** on all three |
| Derivation coverage | 20 triggers; 0 insertable tables with `created_by` uncovered — identical local and Primary |
| pgTAP | **61 files / 708 assertions / 0 failures** |
| End-to-end HTTP | **179/179** |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN |

---

## 6. Classification

**PROVEN** — attribution is derived on all twenty tables and immutable afterwards; the system path
keeps its own; the class is pinned so a new table cannot reopen it; the PUBLIC-EXECUTE guard now
covers the schema that is actually exposed.

**UNPROVEN** — nothing outstanding.

**FAILED** — none.

**BLOCKED** — SCHED-1 · TRANS-1 · DOC-EXP-1 · AUTH-1 · FIN-5 · SYSADMIN-1 · TASK-3 · RET-1, RET-2,
ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1 · DEL-1 (partial) · PP-1 · LIC-1 · EVT-2 · RBAC-2 ·
PERM-1. **ATTR-2** is open but needs no decision — engineering only.

**INTENTIONAL** — action attributions excluded from this trigger; `public.moddatetime`'s ACL left
alone as Supabase's.

---

## 7. Next logical work

**ATTR-2** — the action attributions, which need engineering and no decision. Everything else on the
register needs the owner.
