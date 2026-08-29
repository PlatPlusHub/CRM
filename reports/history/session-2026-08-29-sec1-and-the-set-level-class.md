# ORVION — SEC-1 Evaluated, and the Class It Made Findable: Three Invariants Living in One Function Each

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: SEC-1 architectural evaluation against live evidence (recommendation: **ACCEPT WITH
REFINEMENT**, awaiting owner ratification). Migrations `202607057500` (FIN-10) and `202607057600`
(QUO-1). Tests `72_invoice_allocation_ceiling_test.sql` (16), `73_quotation_total_derivation_test.sql`
(11), assertion 20 added to test 71. FIN-11 and GOV-7 recorded. `AGENTS.md §3 5b` extended.
Status: Complete; deployed to Primary, verified, committed and pushed.

**Branch:** `main` · **Start HEAD:** `bac02e3` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. What was actually tested

The owner asked that a proposed SEC-1 model be proven or falsified against the live system rather
than accepted by opinion. Six clauses. Each was tested against grants, RLS policies, RPCs, triggers,
constraints, permissions and the API contract, read live.

**The headline result is that the hypothesis is not a change of direction — it is a description of
what ORVION has already converged on**, and the honest work was finding where it is *not yet* true
and why that gap is not detectable by inspection.

### The measured writable surface

`authenticated` holds INSERT/UPDATE on **54 tables**:

| | count | evidence |
|---|---|---|
| capability trigger (`guard_write_capability` / financial / transition / archive) | **35** | `pg_trigger` ∩ guard functions |
| permission named in RLS `WITH CHECK` (SEC-3's model) | **15** | `pg_policies.with_check ~ has_permission` |
| integrity trigger instead (`document_versions`, DOC-3) | **1** | `document_versions_enforce_integrity` |
| **ungoverned, and INTENTIONAL** | **3** | `otp_challenges`, `totp_enrollments`, `trusted_devices` — canon 34 Human Identity, owned by `auth.uid()` |

So clause 6 ("RLS never a substitute for business authorization") is **already true**, and clause 3
("direct DML only where structural") is **already close to true**.

### Clause by clause

| Clause | Verdict | Evidence |
|---|---|---|
| RLS is the row-scope/tenant authority | **PROVEN** | 21 `scope_isolation` policies; every cross-tenant test in the suite |
| RPCs are the business-mutation authority | **TRUE IN INTENT, not self-enforcing** | FIN-8, FIN-10, QUO-1, DOC-LC-1, SEC-1b — all RPC-authoritative *in intent* while the table stayed writable |
| Direct DML only where structural | **SOUND AS A RULE, not yet a description** | the three defects above; needs a decision procedure (below) |
| DB-level invariants, path-independent | **PROVEN and now applied 3×** | FIN-8, FIN-10, QUO-1 |
| No cosmetic RPCs | **PROVEN, already practised** | RPC-1 found 35 tables with no RPC; the programme **revoked grants** or added permission triggers instead of minting RPCs |
| RLS never a substitute for authorization | **PROVEN by counterexample** | **SEC-3**: `tenant_id = current_tenant_id()` alone let any employee grant themselves `owner` |

---

## 2. The decision: ACCEPT WITH REFINEMENT

**Two refinements, both earned by evidence this session.**

### Refinement 1 — clause 3 needs a decision procedure, not just a principle

"Direct DML only where the mutation has no business invariant" is correct and **not decidable by
inspection**. FIN-8, FIN-10 and QUO-1 each looked entirely fine. Every one was found by asking a
different question:

> **What does the RPC refuse that the table does not?**

And the mechanizable form of that question, which is what actually found all three:

> **A rule that compares an AGGREGATE ACROSS ROWS cannot be a CHECK constraint. It will therefore
> live in exactly one function unless someone deliberately extracts it.**

Measured: only **two** `app` functions aggregate-and-raise-and-write (`record_payment`,
`add_quotation_item`) — both now closed. `create_journal_entry` accumulates in a loop variable rather
than calling `sum()`, so it is that filter's **known blind spot**; it was closed by FIN-8 the day
before. Stating the blind spot is part of the refinement: the filter is a lead, not a proof.

### Refinement 2 — the exemption asymmetry, decided three times and now explicit

Authorization guards (`enforce_status_transition`, `enforce_archive_authority`) exempt
`auth.uid() is null` under canon 35 principle 6: platform paths sit outside per-table
*authorization*. **Integrity constraints must not.** A ledger corrupted by a migration is exactly as
corrupt as one corrupted by a tenant user. This distinction was reached independently three times
(FIN-8, FIN-10, QUO-1) and is now pinned by an assertion in each test rather than left to be
re-derived a fourth time.

### What is NOT recommended

**Option A — revoke `authenticated` INSERT/UPDATE wholesale.** It requires converting **56**
SECURITY INVOKER functions to DEFINER, which replaces RLS as the row authority with 56 hand-written
tenant checks: the second authorization system canon 35 forbids. The evidence is in the SEC-1
inventory (2026-08-28) and has not changed.

**This decision is recorded as a recommendation and awaits owner ratification.** Engineering does not
need it to continue — the refined model is what the last four packages already implement.

---

## 3. What the refinement found immediately

### FIN-10 — an invoice could be paid more than it is worth

`app.record_payment` refuses to over-allocate, and takes `pg_advisory_xact_lock` on the invoice
first — so the author knew this was a statement about a set of rows and that concurrency could break
it. Nothing enforced it anywhere else.

Reproduced as a `finance_manager` holding `RECORD_PAYMENT`, the same permission the RPC charges:

```
invoice total 1000, issued
RPC pays 400        -> allocated 400,  partially_paid
RPC tries 900 more  -> ERROR 'payment 900 exceeds invoice outstanding 600.0000'
DIRECT DML 900      -> SUCCEEDED.  ALLOCATED = 1300 against a 1000 invoice
                       status still 'partially_paid'
```

`reporting.customer_outstanding` derives `paid_amount` and `outstanding_balance` from this data, so
the customer's balance is wrong in the direction that matters commercially.

**Both sides of the inequality are guarded**, because allocations can exceed the total by *growing*
**or** by the total *shrinking beneath them* — `invoices.total_amount` is writable by a
`CREATE_INVOICE` holder. A trigger on the allocations alone would have been a half-fix, which is the
mistake DOC-LC-1 and FIN-8 both had to avoid.

### QUO-1 — a quotation's price and its line items could disagree by any amount

The third instance, and the first that is a **derived value** rather than a refusal.
`app.add_quotation_item` recomputes `quotations.total_amount` from the items on every insert — so the
total *is defined* as that sum — and maintains it on that one path, while `quotation_items` is
directly writable by all six `CREATE_QUOTATION` roles, including ordinary `employee`.

```
RPC adds a 1000 item        -> total = 1000   items = 1000
DIRECT DML adds a 5000 item -> total = 1000   items = 6000
DIRECT DML edits the first  -> total = 1000   items = 5001
```

A quotation is a **price offered to a customer**: an underquote the agency may have to honour, or an
overquote that loses the sale. `advance_quotation` reads `total_amount` when the quotation is sent
and accepted, so the wrong number is the one that travels into the booking.

**Recomputed rather than refused** — the one place this differs from FIN-8/FIN-10. Those guard
invariants, where rejecting the write is the only correct answer. This is a derived value with **no
independent source**: `quotations` has no discount, override or adjustment column (asserted, not
assumed). Refusing a legitimate line to protect a number the database can simply compute would be the
larger change, not the safer one.

---

## 4. GOV-7 — the consumer-impact rule, made durable

The owner asked that CUST-1's lesson become an explicit audit rule without creating a duplicate
governance system.

`AGENTS.md §3 5b` — the existing cross-path impact sweep — now asks a **second question**:

> **Which code consumes, parses or derives from the structure this package changed?**

Question 1 asks what the new *rule* now catches. Question 2 asks what the new *shape* now breaks.
CUST-1 proved they are not the same: TENANT-1's composite FKs were correct and necessary, and turned
a re-pointing loop into a no-op for eight days.

**Guarded, not merely written down — and deliberately narrowly.** "Audit everything that reads what
you changed" is true and unguardable. What *is* guardable: the consumers that can change meaning
**without their own source changing** are those whose behaviour is derived from the catalog. Measured
live, ORVION has **exactly one** (`merge_customer_identity`), so test 71 assertion 20 pins that set
by name. A second catalog-driven function cannot arrive without failing an assertion that tells its
author to bring a *behavioural* test — which is exactly what was missing.

No new governance document was created.

---

## 5. What was disproven

- **"The system is already RPC-only in practice"** — false. 54 tables accept direct writes; the
  model works because they are *permission-gated*, not because they are unreachable.
- **"A CHECK constraint would have caught FIN-8/FIN-10"** — false and structurally so. Both tables
  already carry per-row CHECKs. A CHECK cannot express a statement about a set of rows.
- **"`add_quotation_item`'s `sum()` is a refusal"** — false; it is a *derived-value recompute*, which
  is why QUO-1 needed a different remedy from FIN-10 despite the same detection method.
- **My own first run of test 72 "passing"** — I grepped only for `not ok`, which hid an `ERROR` line;
  the file had died on a NOT NULL column. Corrected, and the full-suite run is what caught it.

---

## 6. Verification

| Axis | Result |
|---|---|
| Migrations | **165** — repository, local, Primary (`202607057600`) |
| Ledger fingerprint | `6f6595de1f1d3d784457e6c60d882fd7` — read independently from both |
| Function surface (233) | `b511e0edeeec052514fead7ddea5e0ba` — identical both sides |
| Triggers | **235** |
| pgTAP **Pass A** | **73 files / 898 assertions / 0 failures** |
| pgTAP **Pass B** | **73 files / 898 assertions / 0 failures** |
| End-to-end HTTP | **259/259** across six suites |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Repository guard | **CLEAN**, 12 checks |
| Parity guard | **CLEAN**, exit 0, Primary values read live |
| API contract | 46 of 71 with HTTP evidence — API-3 remains **25** |

Ledger normalised after `apply_migration` stamped its own version (GUARD-1), twice.

---

## 7. Classification

**PROVEN DEFECT (fixed)** — **FIN-10** (High), **QUO-1** (High).

**GOVERNANCE (fixed)** — **GOV-7**: consumer-impact rule governed in `AGENTS.md §3 5b` and guarded by
a pinned catalog-consumer set.

**OWNER DECISION (evaluated, awaiting ratification)** — **SEC-1**: ACCEPT WITH REFINEMENT.

**OPEN (recorded)** — **FIN-11**: the direct allocation path leaves invoice status and event
emission behind. Deliberately not fixed with a bolted-on trigger: FIN-9 asks the identical question
about journal events, and the two want **one** answer about where side effects belong.

**No business policy invented.** QUO-1's recompute enforces an existing definition (no discount
column exists); FIN-10's ceiling is copied from `record_payment`'s own inequality.

---

## 8. Next executable step

**API-3 continues — 25 endpoints without HTTP evidence**, audited by capability rather than status
code. The next family by dependency is the **booking/passenger** group (`create_booking_item`,
`link_passenger_to_booking_item`, `advance_booking_item`), which carries the commission derivation
and per-passenger financial authority — the densest remaining concentration of money rules.

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut.

**Owner input now genuinely useful:** ratify or reject the refined SEC-1 model. Nothing is blocked on
it — but it is the difference between four packages implementing an agreed architecture and four
packages implementing an inferred one.
