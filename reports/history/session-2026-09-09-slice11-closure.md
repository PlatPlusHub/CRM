# Slice 11 closure — the archive reason nobody had to own, and the two merges that erased each other

Date: 2026-09-09
Class: **HISTORICAL-IMMUTABLE**

## HANDOFF

- **INHERITED** — `18fd370` (documentation-only blocked checkpoint) plus an interrupted working tree: six modified files and one uncommitted migration `20260909114354`, left mid-edit when the previous session hit its usage limit.
- **PROVEN** — both residual product defects reproduced against a clean local reset BEFORE repair, then closed and re-tested; 111 files / 1796 pgTAP assertions (Pass A = Pass B); 445 HTTP; smoke; guard-of-guard 33/33; Primary parity across ledger, functions and all ten structural surfaces read live FROM Primary.
- **UNPROVEN** — nothing this session claims. AUDIT-2's residual scope (Enterprise feature enumeration) and PD-23's post-PLAN-1 remainder are recorded as leads, not verdicts.
- **CHANGED** — `20260909114354_customers_slice11_closure` deployed to Primary; CUST-11, CUST-12, GOV-21, GOV-22 recorded; two guards widened; assertion 57 added. Commit in this closure.
- **REMAINING** — **ARCH-2**, proven here and deliberately not fixed: the archive INSERT door is still open on the twelve archivable tables that are not `customers`. Batch 6 slice 12 target selection. PD-23 and AUDIT-2 need reclassification by whoever next opens their rows; MONEY-2's manifest placement disagrees with its own register row.
- **DO NOT TOUCH** — Secondary `brplkqmbzffpxqgkkdzo`; settled CUST-3 (warning-only credit ceiling, owner-approved); Slice 12; the `current_user = 'postgres'` invoice exemption, now pinned rather than narrowed.
- **NEXT** — select the slice 12 target with `scripts/batch6_select_target.ps1`. Slice 11 is closed.

## DISCOVERED

**The local database was not the repository, and it looked like it was.** The inherited stack was running and healthy at `210|20260909060754|b189b86098856c5e422f285bf1315ec3` — but `pg_get_functiondef` showed `app.enforce_archive_authority` and `app.merge_customer_identity` already carrying the *closure* bodies, which no applied migration contained. The previous session had applied that DDL out of band. A first attempt to reproduce the archive-reason defect against it therefore reported the defect FIXED, which would have been a false clearance built on PAR-1b exactly as `AGENTS.md §5a` step 1 describes. The closure migration was held aside, `db reset` re-established the true committed baseline, and both defects were then reproduced honestly.

**CUST-11 — `archive_reason` was outside archive authority.** On the clean 210 baseline, an `authenticated` employee proven to hold `CREATE_CUSTOMER` and **not** `ARCHIVE_RECORD` rewrote an archived customer's `archive_reason` from *"duplicate of ledger record"* to *"closed at customer request — no dispute"*. `UPDATE 1` — a row genuinely changed, so this is not a vacuous denial — while `archived_by` still named the owner who actually archived it. The archive record therefore carried a justification authored by someone it did not name, and nothing in the audit trail distinguished it from the original.

The root cause is one line in a shared function. `202607052800` stamps `archived_at`/`archived_by`; `20260909060754` froze them. **Both returned early whenever `is_archived` did not change** (`if new.is_archived is not distinct from old.is_archived then return new`). The two archive columns the SERVER stamps were governed; the one the CALLER authors was not. "Archive metadata is immutable once the archive state is set" was a true statement about two thirds of the metadata.

**CUST-12 — reciprocal merges both committed and left no survivor.** Overlapping `merge_customer_identity(A,B)` and `merge_customer_identity(B,A)` **both exited 0**, with `pg_blocking_pids` showing no blocking edge between them. Postcondition: **2 archived, 0 active survivors, 2 reciprocal merge rows, 2 `critical` merge events.** Each transaction read the other's `is_archived` from a snapshot taken before the other archived it, so CUST-8's archived-target refusal — correct code, correctly tested — was simply never reached. This is the more serious of the two: the survivor is the identity every dependent booking, invoice and payment was just re-pointed onto, so the corrupt outcome is a complete customer history hanging off two dead records.

## VERIFIED

Reproduction and repair both ran against a database reset from repository migrations, never against an ad-hoc one.

| Evidence | Pre-repair (210) | Post-repair (211) |
|---|---|---|
| Employee reason-only rewrite | `UPDATE 1`, narrative replaced | `42501 permission denied: ARCHIVE_RECORD` |
| Reciprocal merge blocking edge | **none observed** | `OVERLAP PROVEN: reverse_b blocked by reverse_a` |
| Reciprocal merge outcome | 2 archived / **0 survivors** / 2 merges / 2 events | 1 archived / **1 survivor** / 1 merge / 1 event |
| Loser's refusal | — | `target customer is already archived` (lifecycle, not FK) |

`scripts/verify_customer_concurrency.py` proves overlap for all three cases and **fails loudly if no `pg_blocking_pids` edge appears** — credit threshold (1200 exposure against a 1000 ceiling, exactly ONE `customer_credit_threshold_exceeded` event, CUST-3 warning-only preserved), same-direction replay, and the reciprocal race.

**Mechanism substitution was tested, not assumed.** Assertion 51 drops `customers_enforce_archive_authority` inside a savepoint, proves the exact rewrite then SUCCEEDS, rolls back, and proves it is refused again — so the trigger is the real enforcer and not RLS visibility, a constraint or trigger ordering (the PAR-4 pattern).

**Lock ordering was verified structurally, not inferred.** `explain` shows `LockRows` above an index scan on `customers_tenant_id_id_key`, so acquisition follows ascending `id` for both callers; opposite merges queue on the same first row rather than deadlocking.

**ARCH-2 — the same guard's other door, found by the mandatory cross-path sweep.** Changing a shared archive function triggers `AGENTS.md §5b`, and the sweep asked which paths now meet the new rule. Answer: on twelve of the thirteen tables, none — `202607052800` created every archive trigger as `before update`, so the shared function **never fires on INSERT** there. Only `customers` carries `before insert or update`. Reproduced: an employee holding no `ARCHIVE_RECORD` ran a plain `insert into public.customer_notes(… is_archived=true, archive_reason='forged narrative', archived_by=<self>)` and it **succeeded** — a row born archived, with a narrative nobody was authorized to write and an archiver the server never stamped. INVOICE-6 measured, repaired and guarded the UPDATE path across thirteen tables on 2026-09-08; the INSERT path was never the subject of that measurement, so a `coalesce` that no longer wins on UPDATE is simply not consulted on INSERT. **BOOK-1's "test both doors", applied to an archive guard rather than to an RPC.** Recorded OPEN and deliberately not repaired — see NOT FIXED.

## FIXED

`20260909114354_customers_slice11_closure`:

1. **`app.enforce_archive_authority`** — a change to `archive_reason` now costs `ARCHIVE_RECORD` (`ARCHIVE_DOCUMENT` on `documents`) even when the boolean does not move, and the INSERT path charges the same for planting a reason at creation. **Repaired in the shared mechanism, across all 13 archivable tables** — the invariant belongs to archive authority, not to `customers`. Measured first: all 13 tables carrying `is_archived` also carry `archive_reason`, so no table can hit a missing-field error at runtime. Sanctioned archive operations, restore, and correction by an archive holder all still work, and a correction preserves the original actor and time.
2. **`app.merge_customer_identity`** — both identities are locked `order by id for update` BEFORE the lifecycle reads.

Also this session: **assertion 57** pins the set of SECURITY DEFINER functions that can reach `guard_invoice_integrity`'s trusted-caller exemption, and **Checks 2 and 22** were widened for GOV-21/GOV-22 (below).

## NOT FIXED

- **ARCH-2** is OPEN by choice. The one-line repair — widening the twelve triggers to `before insert or update` — changes archive-creation semantics on `bookings`, `invoices`, `documents`, `suppliers`, `passengers`, `leads`, `quotations`, `tasks`, `complaints`, `service_requests`, `booking_items` and `customer_notes`, every one a surface outside slice 11. `§5b` requires each affected execution path be classified and proven **separately, never with one generic answer**, and doing that for twelve surfaces is twelve slices of work, not a closing edit. Half-building it here would ship an unproven behaviour change across the whole archive model on the strength of one table's reproduction. Its row exists so no future slice can reach one of those tables without meeting it.
- **CUST-6** remains OPEN and unchanged — repairing the malformed line that hid it deliberately did not touch its status or meaning. It needs a distinct required-permission mechanism, which is a design change.
- **MONEY-2 is misclassified and was left alone.** Its register row reads *"OPEN — **engineering**, deferred to each column's own Batch 6 slice"* and its decision cell begins `engineering/canon`, yet the manifest's boot line lists it among **Open owner decisions**. Correcting that is outside a Slice-11 closure and belongs with whoever next opens the row.
- **PD-23's owner pointer is stale.** Its decision cell reads *"owner (already recorded under PLAN-1): the three 'Limited' ceilings canon leaves undefined"* — the premise **PLAN-1 explicitly rejected on 2026-09-04** as a misreading of canon. What remains of PD-23 is its own measured finding (the quota class is structurally inert), which is engineering, not an owner question.
- **AUDIT-2's premises have partly dissolved.** Measured live: `feature_entitlements` holds **66 rows, 12 carrying numeric limits**, so both *"per-plan seed data"* and *"canon's numeric limits have no schema home"* are now false. Unlimited is encoded as the absence of a ceiling row (Enterprise carries none). What may genuinely remain is whether Enterprise's feature list is fully enumerable from canon — not re-derived here.

None of the three was solved, because §12 scopes this session to Slice 11 and none is a Slice-11 dependency.

## BLOCKED

Nothing. The 2026-09-09 Windows port-exclusion blocker was already resolved before this session; the local stack was running and reachable throughout.

## GOVERNANCE

**GOV-21 — a literal `` `r`n `` hid an OPEN row from every parser.** CUST-10 and CUST-6 shared one physical line, spliced by unexpanded PowerShell escape text where the newline belonged. Every leading-row parser in the guard anchors on `^\|`, so CUST-6 was not mis-parsed — **it was invisible**, and an OPEN engineering row did not exist for status-contradiction, phantom-ID or decision-line checking. The guard printed CLEAN throughout. Check 2's escaped-row detector was **widened in place** rather than duplicated (one home), flagging a row boundary followed by a finding ID with a literal newline escape between them, and deliberately narrow enough that prose *quoting* such an escape still passes.

**GOV-22 — the Coverage summary disagreed with its own rows.** The disposition table recorded twelve audited surfaces; the summary two sections above still read *"11 of 77 recorded · 5 AUDITED · 66 NOT-RECORDED · All 11 … ADVERSARIAL"*. Checks 22 and 24 both passed **because each validates the ROWS** — vocabulary, phantom surfaces, pointer resolution, earned `ADVERSARIAL` — **and neither had ever read the summary a human actually quotes.** This is PAR-3's shape inside a document: the measured surface was real, and the unmeasured one carried the claim. Check 22 now derives the recorded/total pair, every disposition count and the ADVERSARIAL sentence from the rows themselves.

**Both are attacked in both directions.** `scripts/test_status_contradiction_guard.ps1` (**33 passed, 0 failed**) mutates a clean copy of the register with each escape form and asserts detection, asserts prose may still quote the escape, mutates each of the three summary forms and asserts each stale value is caught, and asserts the restored files pass. A detector is not trusted here until it has been shown a case it must flag and one it must not.

**An audit lead was cleared rather than promoted.** `guard_invoice_integrity` exempts `current_user = 'postgres'`, which reads far broader than it is. Measured, exactly **two** SECURITY DEFINER functions owned by `postgres` and executable by `authenticated` can write invoices: `merge_customer_identity`, which re-points `customer_id` only under `MERGE_CUSTOMER_IDENTITY` after its own tenant and lifecycle checks, and `void_invoice`, which writes only `status_code` under `VOID_INVOICE`. Neither can be steered at an immutable column, so **the exemption is bounded by its callers, not by its condition** — safe today, and silently inheritable by a third caller tomorrow. Pinned by assertion 57 for the same reason test 71 pins the catalog-driven set: the next one must arrive WITH a behavioural test. Narrowing the condition was rejected as a fix that would break the sanctioned merge to address a defect that does not exist.

## ENVIRONMENT

Local Supabase running throughout (`supabase_db_ORVION` healthy). `supabase_vector_ORVION` restarts continuously — pre-existing, unrelated to the database, and it affected nothing here. Primary reached via `supabase-primary` MCP, project ref confirmed `vrvtsxexkiiiivlkdxzp` by `get_project_url` before any write. Secondary never contacted.

The MCP assigned version `20260909125259` on apply; it was normalised to the repository version `20260909114354`, the same practice the existing Primary ledger evidence records for `20260909060754`.

## CURRENT STATE

- **Migrations** — repository, local and Primary all **211**, latest `20260909114354`, ledger `d0ecf99da5c6276ee9858deb699f0511`.
- **Functions** — `6ec203382e14693d094e2a9efeee1c9a`, **280**, identical local and Primary.
- **Structure** — `_combined` `45afb9f0d73cfb976559f6f7bb7f435a`, **3,568** objects across all ten surfaces, identical local and Primary; every surface matched individually.
- **pgTAP** — **111 files / 1,796 assertions**, Pass A and Pass B both green (1,784 → 1,796: eleven inherited, one added here).
- **HTTP** — **445** across the six suites (29 / 122 / 74 / 120 / 40 / 60), 0 failed.
- **Smoke** — `ALL CHECKS PASSED` (77 tables).
- **Concurrency** — three cases, each with an observed `pg_blocking_pids` edge.
- **Guards** — repository consistency CLEAN; database parity CLEAN with all three values read live FROM Primary; guard-of-guard 33/33.
- **Batch 6** — **12 of 77**, unchanged. `customers` stays AUDITED / ADVERSARIAL; two further findings on an already-audited surface do not change its disposition.

## NEXT STEP

Select the Batch 6 slice 12 target with `scripts/batch6_select_target.ps1`. **Slice 12 was not started in this session, by instruction.**
