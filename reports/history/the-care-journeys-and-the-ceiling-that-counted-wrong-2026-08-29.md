# ORVION — The Care Journeys, and the Ceiling That Counted the Wrong Triggers

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: Migration `202607057000`; test `67_care_capability_and_message_integrity_test.sql`; new HTTP
suite `scripts/verify_care_journeys.ps1`; SEC-1b, SEC-2, ATTR-4, CONV-2, COMP-1, TEST-2, PAR-1a.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `f4e7be3` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Starting state, re-proven

| Axis | Evidence |
|---|---|
| git | HEAD = `f4e7be3`, tree clean, 159 files: 158 migrations / 66 tests |
| Repo / local | **158** migrations, `cbd05efe6959946df51c83d288851627` |
| Primary shape | 75 tables |

---

## 2. Evidence examined before touching anything

Schema, RLS policies, triggers, `app.status_transitions` rows, RPCs, permission holders and public
wrappers for `complaints`, `conversations` and `conversation_messages`; canon 26's two state
machines; canon 31's column declarations; the `10_grant_model_test` ceilings; and every catalog the
three tables reference.

Two things stood out immediately and both turned out to matter: `conversation_messages`' policy is
markedly thinner than its parent's, and neither `complaints` nor `conversations` carries a
capability trigger — while the SEC-1 ceiling said the residue was three tables and named none of them.

---

## 3. SEC-1b — SEC-1 was not closed, and the guard is the reason

`10_grant_model_test` pins *"at most 17 tables have NO capability trigger **on the direct write
path**"*. Its detector:

```sql
not exists (select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
            where t.tgrelid = c.oid and not t.tgisinternal
              and pg_get_functiondef(p.oid) ~ '(app\.authorize|app\.has_permission|…)')
```

It asks whether *some* trigger's body mentions `app.authorize`. **It never asks when the trigger
fires.** `app.enforce_status_transition` and `app.enforce_archive_authority` both call `authorize`,
and both are `BEFORE UPDATE` **only** — so every status-bearing and every archivable table was
credited with protection on a path it did not have.

Measured live:

```
insertable by authenticated ........................ 54
no capability trigger, as the detector counts ...... 17
no capability trigger THAT FIRES ON INSERT ......... 30
credited but UPDATE-only ........................... bookings, complaints, conversations,
   customer_notes, customers, documents, leads, marketing_campaigns, passengers, quotations,
   service_requests, suppliers, tasks
```

Re-running the **residue** predicate with the same one-word correction turns **3 into 15**. Three are
the canon-34 auth artifacts and stay INTENTIONAL. The other twelve are ordinary business tables with
no capability check on their INSERT path at all.

### Reproduced

```
trainee holds CREATE_COMPLAINT? f   SEND_MESSAGE? f   CREATE_CUSTOMER? f   CREATE_TASK? f
app.create_complaint(...)               ->  REFUSED: permission denied: CREATE_COMPLAINT
insert into public.complaints (...)     ->  1 row
insert into public.conversations (...)  ->  1 row
```

Same actor, same transaction. The trainee satisfies the RLS policy through its
`current_user_id() = owner_user_id` disjunct — **naming yourself as owner is enough.** And it is not
a SQL-only curiosity: `POST /rest/v1/complaints` with the trainee's JWT did the same thing, which is
the door a browser would actually find.

### Why it survived

SEC-1's closure rested on that ceiling, and the ceiling measured something other than its own
description. This is the fourth instance of *"a guard written against the first instance takes that
instance's shape"* — and the second day running where the guard, not the code, was the defect.

### The fix, and one thing it deliberately does not do

`app.guard_write_capability`'s CASE gains all twelve, each charging the permission **read out of that
table's own creating RPC**. Nothing is chosen: `create_supplier` charges `ASSIGN_SUPPLIER`, so
`suppliers` charges `ASSIGN_SUPPLIER`.

Triggers are attached **BEFORE INSERT only**. Charging `CREATE_BOOKING` on every UPDATE to `bookings`
would break `advance_booking`, because `finance_manager` holds `ISSUE_BOOKING` and does **not** hold
`CREATE_BOOKING` — the same exception `202607056000` had to make for `approval_requests`, found the
same way: by checking before writing rather than after breaking.

The detector is corrected too, both predicates now requiring `(t.tgtype & 4) <> 0`. **The middle
ceiling therefore rose from 17 to 18 while the exposure fell** — both are the same correction, and
the test file says so, because a number moving the wrong way looks like a regression to the next
reader.

### What is left, and why it is genuinely blocked — SEC-2

The UPDATE axis is still unguarded: retitling a booking or renaming a customer passes only the RLS
`for ALL` policy, whose WITH CHECK is the read predicate. SEC-1b could read each INSERT permission
out of the RPC that inserts. There is **no `update_customer`, no `edit_booking`, no
`amend_complaint`** anywhere — no function to read a permission from. Charging the CREATE permission
was tried on paper and rejected for the same reason the INSERT guard is INSERT-only. Recorded as
**SEC-2**, owner decision.

---

## 4. ATTR-4, CONV-2, COMP-1 — three findings in the message and complaint records

**ATTR-4.** `app.send_conversation_message` derives `sender_user_id` from the session; direct DML did
not have to. Reproduced: an employee inserted a message naming a **colleague**, and the row read back
`Colleague | I never wrote this`. On this table that is worse than the usual attribution defect —
`conversation_messages` is the record of what the agency *said to a customer*, on the channel canon
10 designates for customer communication and the one the future WhatsApp/AI layer will write to.
Fixed with ATTR-1's shape; the rule is exactly what the RPC already does, so the guard makes the
RPC's behaviour unbypassable rather than inventing a second rule.

**CONV-2.** `update … set message_text = '…'` on a sent message returned `UPDATE 1` and replaced the
text; DELETE was open on the same policy. Fixed with the treatment ORVION already gives `events` and
lead assignment history. **`external_message_id` and `metadata` stay writable** — they are the
delivery integration's fields, and a WhatsApp writer learns the provider's message id only after the
send. A blanket row freeze would have looked stricter and broken the integration ORVION is being
built for.

**COMP-1.** `complaints.resolution_notes` is declared in canon 31 and written by **nothing** — a
complaint could reach `resolved` with no record of how. `advance_complaint` already accepts
`p_reason` and already puts it in the event. Now, on the transition into `resolved` **and only that
one**, the reason is persisted as the resolution note. `resolved` is the single transition where
"reason" and "resolution" denote the same fact; writing it on `new → acknowledged` would corrupt the
column rather than fill it. This is a fix and VOID-1 is not, because VOID-1 needs a permission canon
does not define, a set of legal source states, and a void-versus-credit-note decision — here the RPC,
the authority, the parameter and the column all already existed and simply were not joined.

---

## 5. The HTTP suite, and what it exists to prove that pgTAP cannot

`scripts/verify_care_journeys.ps1` (38 assertions) walks the complaint machine through all nine
transitions including reopen, the conversation machine including the escalate/close **authority
split** canon draws (an employee may close a thread but not escalate one; the branch manager is the
positive control), tenant isolation from a rival agency, and the trainee's scope.

It also carries the over-the-wire half of SEC-1b. The pgTAP file proves the guard fires; only an HTTP
`POST /rest/v1/complaints` proves PostgREST offers that door to a browser at all — which is how a
real client would have found it. API-1 is the standing reminder: 600 green pgTAP assertions once
coexisted with an entirely unreachable API.

---

## 6. Two guard findings the package produced about itself

**TEST-2.** Pass A was green at 67 files / 805 assertions. **Pass B died**: `67_…` reported
`Bad plan. You planned 24 tests but ran 0`, on
`duplicate key … "users_email_partial_key" … Key (email)=(emp@care.test) already exists`. The new
HTTP suite and the new pgTAP file, written in the same session, had both used `emp@care.test`.

The colliding key is **`auth.users.email`** —
`CREATE UNIQUE INDEX users_email_partial_key ON auth.users (email) WHERE (is_sso_user = false)`.
Supabase's own index, global across the entire database, with no tenant column to scope by. The
slug-collision discipline established after `lc-branch-travel` covered `tenants.slug` and
`branches.slug`; the identity table is the one identifier every fixture in both suites writes and no
rule mentioned. Swept the class rather than the instance: **117 distinct fixture emails across all 67
test files and all 10 scripts, 25 owned by a persistent HTTP suite, zero other collisions.** pgTAP
files roll back and may safely share an address; only a *persistent* suite's addresses are dangerous,
which is the distinction the rule needed.

**PAR-1a — and a correction to yesterday's report.** Yesterday I reported all 228 functions
byte-identical across local and Primary at `4821a18a9bf8193a4bc8c7dea6e345a8`. That comparison used
`regexp_replace(def, '--[^\n]*', '', 'g')`. **Inside a POSIX bracket expression the backslash is not
an escape**, so `[^\n]` reads as *"not a backslash and not the letter n"* — the pattern stops at the
first `n` in a comment and leaves most comment text in the hash. The byte-identity claim held only
under that weaker normalization.

The guard I had *just written* to close PAR-1 builds the pattern correctly with `chr(10)`, and on its
first real run it reported PRIMARY FUNCTION DRIFT. Bucket-narrowing found exactly one function:
**`app.document_retention_days`** — local `select null::integer`, Primary
`\n    select null::integer;\n`.

Behaviour was verified before anything was touched: both return NULL, and calling it on Primary
returns null, so **RET-1's retain-forever default is intact and no document is eligible for
destruction on either environment.** Cosmetic, then — but a real difference a session had reported as
absent. Primary restored to the repository's text, the guard's header now states why the `'--[^\n]*'`
form must never be used for this comparison, and the canonical value going forward is the guard's.

---

## 7. Verification

| Axis | Value |
|---|---|
| Migrations | **159** — repository, local, Primary |
| Ledger fingerprint | **`28cd2ca6d89881750b5cd2bfb84f9238`** — read independently from local and Primary |
| Function surface (230) | **`1c63f2545d2452cece517e324c5b25c7`** — identical, read independently from both, using the guard's expression |
| pgTAP **Pass A** (fresh `db reset`) | **67 files / 805 assertions / 0 failures** |
| pgTAP **Pass B** (after all six HTTP suites' residue) | **67 files / 805 assertions / 0 failures** |
| End-to-end HTTP | **220/220** — storage 43 · employee 29 · branches 26 · roles 27 · lifecycle 57 · care 38 |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Guards | repository CLEAN · parity CLEAN (ledger **and** functions) |
| Negative proof | every fix re-run against its original reproduction probe |

The deploy itself was byte-clean on the first comparison — PAR-1's verbatim-paste rule, applied for
the first time, worked.

---

## 8. Classification

**PROVEN DEFECT (fixed)** — SEC-1b (twelve tables with no INSERT-path capability check, and the
ceiling that hid them); ATTR-4; CONV-2; COMP-1; TEST-2; PAR-1a.

**BLOCKED — BUSINESS DECISION (new)** — SEC-2: whether editing an existing record costs the create
permission, a new EDIT_* permission per family, or is deliberately left to RLS scope. Not derivable:
no `update_*` RPC exists anywhere to read a permission out of.

**INTENTIONAL** — the INSERT-only attachment of the twelve guards; `external_message_id` and
`metadata` remaining writable on messages; COMP-1's write scoped to the single `resolved` transition;
the three canon-34 auth artifacts remaining the whole residue.

---

## 9. Next logical work

Executable without the owner: **§19's API capability contract** — endpoint, request, response,
permission, RLS scope, validation, error states, pagination, filtering, sorting — for each
employee-facing workflow, which the directive requires *before* any WeWeb work; and the
**service-request lifecycle**, the last after-sales branch with no dedicated HTTP walk of its own.

Owner-blocked and unchanged: DOC-EXP-1's recipient/lead-time/cadence (still the largest operational
hole), **SEC-2**, SCHED-1's route and secret, RET-1, RET-2, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3,
PH8-2, TRANS-1.
