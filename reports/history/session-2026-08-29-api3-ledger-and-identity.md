# ORVION — API-3: A Ledger That Need Not Balance, and a Merge That Merged Nothing

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: API-3's two named endpoints — `create_journal_entry` and `merge_customer_identity`. Migrations
`202607057300` (FIN-8) and `202607057400` (CUST-1). Tests `70_journal_entry_balance_test.sql` (17)
and `71_customer_identity_merge_test.sql` (19), plus 16 HTTP assertions. FIN-9, CUST-2 recorded.
Status: Complete; deployed to Primary, verified, committed and pushed.

**Branch:** `main` · **Start HEAD:** `c170ec2` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. The instruction, and why it mattered

*"Do not treat HTTP 200/204 as sufficient evidence… The purpose is to discover hidden defects behind
each uncovered capability, not to manufacture HTTP assertions."*

Two endpoints were named. **Both hid a defect**, and neither would have been found by calling the
endpoint and checking the status code — both RPCs work perfectly. The defects were in what the
capability's *surface* permits beside the RPC, and in one case in what the RPC silently failed to do.

---

## 2. `create_journal_entry` → FIN-8: the ledger's defining invariant had one enforcement point

The RPC is correct. It requires at least two lines, exactly one of debit/credit per line, equal
totals, non-zero. It enforces all of that **and nothing else does**.

`authenticated` holds INSERT and UPDATE on `journal_entries` and `journal_entry_lines`. The RLS
policies charge `CREATE_JOURNAL_ENTRY` — the same permission the RPC charges. Reproduced as a
`finance_manager` (aal2):

```
RPC, balanced 1000/1000   -> 76565004-…                  (positive control: a real entry)
RPC, unbalanced 1000/1    -> ERROR 'not balanced: debits 1000 <> credits 1'
DIRECT DML, ONE line, 1,000,000 debit, no credit at all
                          -> SUCCEEDED.  debits=1000000  credits=0  lines=1
events emitted            -> 0
```

**This was never a privilege escalation.** It is a holder of the right permission reaching the right
table through a door with no invariant behind it — the FIN-6 shape, in the general ledger.

**Why the existing constraint could not have caught it.**
`journal_entry_lines_debit_xor_credit_check` proves each *line* is a debit or a credit. Whether an
*entry* balances is a statement about a **set** of rows, and a CHECK constraint structurally cannot
express one. That is the whole gap.

**The fix — deferred constraint triggers.** The invariant is only ever true *between* statements: the
entry row lands first and is momentarily an entry with zero lines; each line arrives one at a time
and every intermediate state is unbalanced. An immediate trigger would refuse the RPC on its own
first line. `deferrable initially deferred` moves the check to COMMIT, which is the only moment the
invariant is meaningful. The three rules are **copied out of the RPC**, not chosen here.

**No session-less exemption, deliberately** — and this differs from the guards beside it.
`enforce_status_transition` and `enforce_archive_authority` exempt `auth.uid() is null` under canon
35 principle 6, because platform paths sit outside per-table *authorization*. This is not
authorization. It is data integrity, in the same class as the `debit_xor_credit` CHECK one column
over, which the platform does not escape either. A ledger corrupted by a migration is exactly as
corrupt as one corrupted by a tenant user.

**Consequence, stated plainly rather than discovered later:** creating a journal entry through the
PostgREST *table* endpoints is now impossible — one HTTP request is one transaction and cannot hold
an entry plus two balanced lines. That is not a capability removed. There was never a way to build a
*valid* entry that way, only an invalid one.

**FIN-9 recorded, not papered over:** a transaction-capable client (psql, `service_role`) can still
create a valid balanced entry with no `journal_entry_created` event. An event trigger would
double-emit for every RPC-created entry, so the honest answer is not a second producer.

**Assertion 14 is the one that keeps the other thirteen honest.** Because a pgTAP file never commits,
each negative forces the check with `set constraints all immediate` inside a DO block — so a
*balanced* correction is asserted to pass the same forcing mechanism. Without it, every refusal could
have been the harness rather than the constraint.

---

## 3. `merge_customer_identity` → CUST-1: it archived, audited, alarmed, and moved nothing

The more serious of the two.

```
BEFORE  notes  src=1  tgt=0
MERGE returned: 3b26956e-…          <- success
AFTER   notes  src=1  tgt=0         <- NOTHING MOVED
source archived: true                <- the history is now behind an archived customer
audit rows: 1     critical events: 1 <- both assert a merge that did not happen
```

Customer deduplication is a core CRM primitive. After a "successful" merge the surviving customer had
none of the duplicate's bookings, invoices, payments, leads, quotations, passengers, notes,
conversations or complaints — and the duplicate holding all of it was archived out of sight.

### It is a regression introduced by an earlier fix

The re-pointing loop discovered referrers from `pg_constraint` and took the local column as the
**first** column of the foreign key. That was correct when written: the FKs were single-column
`customer_id`.

**TENANT-1 (SPEC-128, 2026-08-21) made every tenant-scoped FK composite** —
`(tenant_id, customer_id) REFERENCES customers(tenant_id, id)` — to close a cross-tenant reference
hole. From that moment the first column was `tenant_id` on all sixteen referrers, and the generated
statement became:

```sql
update public.customer_notes set tenant_id = <target CUSTOMER id> where tenant_id = <source CUSTOMER id>
```

A tenant id never equals a customer id, so it matched zero rows and failed silently. **A fix broke a
different capability, and the failure mode was silence.**

### CUST-2 — why no guard caught it

The only tests naming this function were `07_event_vocabulary_registry_test` (its event code is
registered) and `53_api_surface_test` (the endpoint exists).

AUDIT-1/SPEC-120 had already broken this function once — an unregistered event code aborted every
call — and the guard added in response verified the **vocabulary**, not the **behaviour**. *A guard on
the name of the event a function emits cannot notice that the function did nothing else.* When a fix
is prompted by a symptom, the guard tends to be written against the symptom rather than the
capability.

### The fix, and the collision it immediately exposed

Position N of `conkey` corresponds to position N of `confkey`, so the local column referencing
`customers.id` is the one whose partner is `id` — regardless of key width or declaration order. The
same pairing yields the local `tenant_id`, now used as an extra predicate because the function is
SECURITY DEFINER and therefore RLS-blind. It **fails closed** if a referrer cannot be resolved:
silently skipping one is exactly the defect being fixed.

Making the loop correct is not sufficient. `customer_contact_methods` carries two unique indexes
keyed on `customer_id`:

- `(tenant_id, customer_id, contact_method_type_code, value)`
- `(tenant_id, customer_id, contact_method_type_code) WHERE is_primary`

Two customers being merged are duplicates **of each other** — they very often share an email or
phone, and they nearly always each have a *primary* of the same type. Re-pointing alone raises a
unique violation on the most ordinary merge there is. Replacing a silent no-op with a loud failure is
not a fix.

Both resolutions are forced by the schema plus the function's own contract that **the target is the
surviving identity** — neither invents policy:

1. A source contact method whose (type, value) already exists on the target is **deleted**. Nothing is
   lost; the value is already on the survivor, and keeping it is impossible.
2. A source **primary** colliding with the target's primary of that type is **demoted, not
   discarded** — the value survives as a non-primary method.

Proven:

```
BEFORE  src=2 (1 primary email)   tgt=2 (1 primary email)   [sharing one whatsapp value]
AFTER   tgt: email:source-only@… | email:target-primary@…*PRIMARY* | whatsapp:+20111222333
        src: 0
```

Four contacts became three, the duplicate removed, the source's email kept, the target's primary
intact.

---

## 4. What else the audit covered, per the directive

| Axis | `create_journal_entry` | `merge_customer_identity` |
|---|---|---|
| Canonical intent | canon 07/14 double-entry | ADR-0019 catalog-driven re-pointing |
| Permission source | `CREATE_JOURNAL_ENTRY` — ceo, finance_manager, owner | `MERGE_CUSTOMER_IDENTITY` — ceo, owner |
| Direct DML exposure | INSERT+UPDATE on both tables → **FIN-8** | n/a (DEFINER RPC) — but RLS-blind, so a tenant predicate was added |
| RLS / WITH CHECK / grants | policies charge the same permission as the RPC — correct | tenant membership verified explicitly, both sides |
| Positive HTTP | balanced entry posted over HTTP | owner merges over HTTP |
| Negative authorization | employee refused over HTTP | employee refused over HTTP |
| Tenant isolation | rival finance manager sees no ledger rows | rival owner cannot merge another agency's customers |
| Mutation / side effects | lines land, event emitted once | referrers moved, source archived, audit row, critical event |
| Idempotency | none (DC-2, known) — entries are not idempotent by design | re-merging an archived source is **refused**, asserted |
| Sibling write paths | `chart_of_accounts`, `journal_entry_lines` swept | all 16 customer referrers, `customer_contact_methods` collisions |
| Regression | 71 files / 871 assertions, both passes | same |

---

## 5. Verification

| Axis | Result |
|---|---|
| Migrations | **163** — repository, local, Primary (`202607057400`) |
| Ledger fingerprint | `6746dc8c39cb9ca9fb012eca6092c645` — read independently from both |
| Function surface (231) | `da7d4866655f8ba95b2640aeaf8b9e9a` — identical both sides |
| Triggers | **232** |
| pgTAP **Pass A** | **71 files / 871 assertions / 0 failures** |
| pgTAP **Pass B** | **71 files / 871 assertions / 0 failures** |
| End-to-end HTTP | **259/259** — storage 51 · api 29 · branches **34** · roles **35** · lifecycle 72 · care 38 |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Repository guard | **CLEAN**, 12 checks |
| Parity guard | **CLEAN**, exit 0, Primary values read live |
| API contract | 46 of 71 endpoints with HTTP evidence — **API-3: 30 → 25** |

Ledger rows normalised after `apply_migration` stamped its own versions (GUARD-1), twice.

---

## 6. Classification

**PROVEN DEFECT (fixed)** — **FIN-8** (High): the double-entry invariant had one enforcement point.
**CUST-1** (High): customer identity merge re-pointed nothing, silently, since 2026-08-21.

**GUARD DEFECT (fixed)** — **CUST-2**: the guards that existed measured the event vocabulary and the
endpoint's existence, neither of which can see a no-op.

**OPEN (recorded)** — **FIN-9**: a transactional direct-DML client can create a valid journal entry
with no event; an event trigger would double-emit.

**No business policy invented.** The merge's two collision resolutions are forced by the unique
indexes plus the function's own contract that the target survives. The balance rules are copied from
the RPC.

---

## 7. What this pair says about the programme

CUST-1 is the first defect this programme has found where **a previous fix caused it**. TENANT-1 was
correct and necessary; it closed a real cross-tenant hole. It also silently changed the shape of
something a different function was reading positionally, and no guard connected the two.

That is the sibling-audit rule (`AGENTS.md §3 5b`) pointed at a target it has not been aimed at
before: not "which paths now meet this new rule?" but **"which code reads the structure I just
changed?"** A composite-key migration should ask what parses keys.

---

## 8. Next executable step

**API-3 continues — 25 endpoints without HTTP evidence.** The same method: audit the capability, not
the status code. Then Batch 6's remaining engineering items (`notification_deliveries` has no
producer; Employee/Supplier/Branch 360 primitives; the table-by-table sweep across 75 tables).

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut.

**The single owner decision that unblocks the most: SEC-1**, the write-path architecture.
