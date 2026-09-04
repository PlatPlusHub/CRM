# ORVION — Decision census pass 2: all 100 non-closed rows dispositioned, FIN-7 shipped, and TAX-1 retracted

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: **COMPLETE — every discovered non-closed register row has a final disposition, and F (evidence gap) is empty.** 100 non-closed rows, not the ~45 previously estimated. **69 of them are not decisions at all.** FIN-7 implemented and deployed to Primary. **TAX-1 retracted — it was never a defect, and the error was mine.** Two new governance findings, one of them also mine.

---

## 1. EXECUTIVE SUMMARY

The previous pass reported "~45 non-closed register rows… ~30 remain untriaged". **Both numbers were wrong, and the framing under them was wrong.**

A positional census — reading **column 9 (`Status`)** rather than pattern-matching whole rows — finds **237 distinct ids: 131 closed, 35 `DESIGN-READY`, 100 non-closed.** More than double the estimate.

**But the count is the smaller correction. The bigger one is that most of it was never decision debt.**

The register's own header states the policy:

> *Findings are classified **Architecturally Required** (evidence proves it belongs in a complete modern Travel ERP/CRM/Revenue platform → its **design** must exist now) or **Architecturally Optional**… **Implementation timing belongs only to the owner.***

So a row reading `Required · OPEN · Owner Decision: pending · Batch 4` means **the design is accepted and the build is unscheduled**. The column named `Owner Decision` holding `pending` means *unscheduled*, not *unanswered*. **Sixty-nine of the hundred are that class** — a product backlog that three sessions in a row have mistaken for decision debt because of a column name.

**Two of my own previous findings were wrong, and both are corrected here:**

- **TAX-1 is retracted.** I claimed `invoices.external_submission_status_code` was guarded against a catalog type that does not exist. The family is `tax_submission_status_code`, it **does** exist, and it carries five active values. I built the finding on `pg_get_triggerdef` output **truncated at the terminal display boundary**, which silently dropped the `_code` suffix — the exact "static analysis is a lead, never a verdict" failure this register catalogues.
- **GOV-17**: my seven closure blocks from the previous pass used `**Status:** ✅ **DECISION CLOSED — …**`, a form Check 2's anchor **cannot read**. Seven closures were invisible to the guard and five sat in live contradiction with their own table rows while Check 2 printed *"no contradiction"*.

**FIN-7 is implemented and deployed** (`202607060200`) after re-verifying its evidence, including reproducing `draft → paid` live at the unguarded table door.

---

## 2. INITIAL STATE

Fetched first. HEAD = `origin/main` = `ls-remote` = `b9586910995d32f36c8edfaf0d3d432072b75571`, 0/0, clean tree, **190 migrations**, remote correctly qualified as `PlatPlusHub`.

---

## 3. CENSUS METHOD

Three passes, each correcting the last — recorded because the method is the finding:

1. **Keyword match over whole rows** → 215 ids, 123 "non-closed". **Wrong**: `DESIGN-READY` was unhandled, and status text narrating history ("OPEN — … was FIXED") produced false MIXED.
2. **Longest matching cell** → picked the *action* column (`pending`) instead of `Status` on the DC family. **Wrong.**
3. **Positional**: the main table is 13 columns — `ID | Title | Category | Sev | Req/Opt | Batch | Mig | Cert | Status | Owner Decision | Source | Added | Updated`. Status is **column 9**, Req/Opt column 5, Batch column 6. Field-count distribution confirmed one dominant shape (203 rows at width 15, 36 at 14). **This is the census reported below.**

Cross-checked against `manifest.md`, `MASTER_EXECUTION_PLAN.md`, `_ORVION_CANONICAL/*`, the live local database, and Primary.

---

## 4. DISPOSITION OF ALL 100 NON-CLOSED ROWS

| Code | Disposition | Count |
|---|---|---|
| **C** | **Scheduling backlog** — design accepted, batch assigned, *not a decision* | **69** |
| **G** | **Genuine owner business decision** | **11** |
| **E** | **Superseded / already terminal / not a decision** | **10** |
| **D** | **Engineering defect** — engineering-owned, no owner input | **8** |
| **B** | **Resolved by existing implementation** | **2** |
| **H** | **Owner compliance decision** | **1** (RET-1) |
| **F** | **Evidence gap** | **0** |

**C — 69 rows.** DC-6/8/10/11/12/14/15/17/18/19/20/21/22/23/25/26/27/28/29 · B2/B6/B7/B8 · OPS-1 · AUDIT-5 · PH8-3…PH8-8 · RPC-1 · ATTR-1 · and the 35 `DESIGN-READY` rows (BF-\*, CDD-\*, RC-\*, FOE-\*, R-series). Titles confirm the class: *multi-book accounting*, *Hijri calendar*, *public API versioning*, *plugin marketplace*, *offline sync*, *partitioning*, *pg_trgm fuzzy dedup*, *structured logging + RPO/RTO*. These are **product capabilities with completed designs awaiting a batch**.

**G — 11.** SUP-4c · CUST-3 · VOID-1 · PLAN-1 · DOC-LC-3 · CANON-26-1 · RET-2 · BLOCKED-4 · BLOCKED-5 · AUDIT-4 · CAT-6 · BOOK-2 · A3. All now on the manifest line; six of these were **never surfaced there before** (GOV-16's real cost).

**E — 10.** PP-1 · FIN-DOC-1 · SYNC-1 · DC-13 · SEC-3 · CAMP-2 · PLACE-2 · ORIG-1 · JE-2 · B1 — each already carries a terminal verdict (`ACCEPTED RISK`, `UNPROVEN — deliberately not fixed`, `TRIGGER-DEFERRED`, `CLOSED by SPEC-154-B`, `MOVED→PENDING` on evidence). Open in appearance only.

**D — 8.** FIN-9 · FIN-11 · DEAD-2 · DEAD-3 · DEAD-4 · IDENT-2 · CAT-5 · GOV-9. Every one already carries `engineering:` in its action column.

**B — 2, and both were stale decisions presented as current:**

- **AUDIT-2** — "`feature_entitlements` per-plan seed data… canon's numeric limits have no storage". **Measured live: 66 rows**, and `app.plan_limit` exists (SPEC-141/146, 2026-08-24). The storage half is done; only PLAN-1's three numbers remain, and PLAN-1 already owns them.
- **DC-24** — "Tenant-custom roles/permissions". **`public.user_permission_grants` exists** (RBAC-5 / ADR-0027). Per-user grant *and* deny over role grants is the extensibility the row asked for; what remains is narrower and should be re-scoped.

---

## 5. TAX-1 — RETRACTED, AND HOW THE ERROR WAS MADE

The previous pass recorded TAX-1 as a defect: the `invoices` catalog guard naming `tax_submission_status`, a type that "does not exist", making the column structurally unusable.

**Every part of that is false.**

The family is **`tax_submission_status_code`** — it exists, and it carries five active system values: `pending`, `submitted`, `failed`, `accepted`, `rejected`. The trigger declares that exact name.

**Root cause:** I read `pg_get_triggerdef` output rendered in the terminal, where the line was **truncated at the display boundary**, dropping `_code`. I then queried `catalog_types` for the truncated string, got zero rows, and wrote a finding. The register's own standing rule — *static analysis is a lead, never a verdict* — is the one I broke, in a session that quoted it.

**Proven behaviourally, both directions, in a rolled-back transaction:**

```
update public.invoices set external_submission_status_code = 'submitted'       -> ACCEPTED
update public.invoices set external_submission_status_code = 'totally_made_up' -> REFUSED
   "totally_made_up" is not an active value of catalog family "tax_submission_status_code"
```

**Generalised rather than spot-checked:** all **65** `enforce_catalog_codes` (column, family) pairs across every table were resolved against `catalog_values`. **Zero mismatches.** No defect, and no class behind it.

**On the ETA question the task raised:** the five values are a **generic submission lifecycle**, not ETA policy. Nothing here encodes a 7-day or 60-day rule, and nothing needed to. The distinction the task demanded is already in the schema: `invoices.status_code` is **ORVION's internal lifecycle**; `external_submission_status_code` is the **external document lifecycle**. They are separate columns with separate catalogs, and this session added no tax rule to either.

---

## 6. FIN-7 — IMPLEMENTED AND DEPLOYED

**Re-verified before implementing, as instructed. The evidence held.**

**Reproduced live first** (rolled back): with the table door unguarded, `draft → paid` — skipping `issued`, with no payment — was **ACCEPTED**. `authenticated` holds `INSERT, SELECT, UPDATE` on `public.invoices`.

**Six transitions, read off the two RPCs including their permissions:**

| From | To | Permission | Source |
|---|---|---|---|
| draft | issued | `CREATE_INVOICE` | `app.issue_invoice` |
| issued | partially_paid | `RECORD_PAYMENT` | `app.record_payment` |
| issued | paid | `RECORD_PAYMENT` | `app.record_payment` |
| partially_paid | paid | `RECORD_PAYMENT` | `app.record_payment` |
| overdue | partially_paid | `RECORD_PAYMENT` | `app.record_payment` |
| overdue | paid | `RECORD_PAYMENT` | `app.record_payment` |

**Two states deliberately unregistered:** `→ overdue` (no producer anywhere — EVT-2's class) and `→ voided` (VOID-1, still an open owner decision). Both are now **refused** at the table door, which is strictly safer than the status quo where they were permitted.

**Test `94_invoice_state_machine_test.sql` — 21 assertions.** The full RPC path is exercised end to end *with the trigger live* (create → issue → part pay → second part pay → settle), each positive control asserting the row **moved** rather than merely not throwing. The second part payment proves `partially_paid → partially_paid` is treated as a non-transition. The three table-door refusals are backed by **defect injection (PAR-4)**: the trigger is dropped, the same skip is proven to **succeed**, and the trigger restored.

**Test 88 flagged a sixth PARENT-1 pair, and it was investigated rather than suppressed.** Registering `invoices` made it a parent that detector examines, surfacing `record_payment -> payments (invoices)`. **False positive, provably**: `public.payments` has **no `invoice_id` column**, so a guard there would have no invoice to read; the invoice link is `payment_allocations`, which already carries `payment_allocations_guard_parent_state` (PAY-1, `202607059500`). Recorded as the sixth verified non-defect **with that evidence**.

**Smoke CHECK 5g** refused the run at *"expected 11 status-transition triggers, found 12"*. The **pin was updated to 12**; the guard was not weakened.

---

## 7. NEW GOVERNANCE FINDINGS

### GOV-17 — my own closure blocks were unreadable to the guard (FIXED)

Check 2's resolved anchor is `\*\*Status:?\*\*\s*\*{0,2}\s*(?:✅\s*)?(RESOLVED|FIXED|IMPLEMENTED|CLOSED)\b`. It permits `**` **before** the tick, not after, and its vocabulary is four words. The previous pass wrote `**Status:** ✅ **DECISION CLOSED — …**` — failing on **both** counts. Tested against two known-good controls that matched.

**Consequence, measured:** seven closures invisible to the guard; five in live contradiction with their own table rows while Check 2 printed *"no contradiction"*. **This is GOV-11's class, one week after GOV-11 was found and fixed, committed by the same hand that fixed it.**

**Fixed:** all seven rewritten to `**Status:** **✅ RESOLVED — …**`; readable resolved-status lines rose **46 → 53**. The five contradictory table rows now carry the new verdict, with their superseded text retained per the register's never-delete convention.

### GOV-18 — Check 2 sees a row as OPEN only when the cell is the bare word `OPEN` (OPEN)

`$rowOpen = $line -match '\|\s*OPEN\s*\|'` — a padded cell containing *exactly* `OPEN`. **Measured: 19 rows are open in that form; 35 are open in a richer one** (`BLOCKED — …`, `OWNER DECISION — …`, `OPEN — …`, `PENDING (…)`, `IN PROGRESS`, `PARTIALLY RESOLVED`). The contradiction pass is blind to **65% of the open population** — which is exactly how GOV-17's five contradictions printed CLEAN.

**Not fixed here, deliberately.** Widening it changes what the repository's central contradiction guard reports and must arrive with a mutation proof in both directions (`AGENTS.md §6`). Registered, not silently deferred.

### GOV-16 — updated with the shape of the gap

Still unfixed, and now better understood: of the 100 non-closed rows the manifest does not surface, **69 are backlog and only 11 are genuine decisions**. A register→manifest guard must compare **decisions**, not **open rows** — a naive check would demand the manifest carry 100 ids and destroy the boot line. That is a better reason for the guard's shape than GOV-16 originally gave.

---

## 8. GLOBAL BEST-PRACTICE FINDINGS

Used for comparison, never as a requirement.

| Question | External practice | ORVION | Recommendation |
|---|---|---|---|
| **VOID-1** | Egypt ETA: cancellation within **7 days** (buyer approval, never after 60, never once a credit note exists); corrections after that require **credit/debit notes** referencing the original UUID; validated invoices cannot be edited | `voided` catalog value exists, no writer, no permission; `journal_entries` carries the same three columns with no catalog behind them | **(A) draft-only voiding now.** The ETA window and credit notes are separate, later decisions. **`journal_entries` should be reversed, never voided** — standard double-entry, and true regardless of the invoice answer |
| **TRANS-1** (prior pass) | Metadata-driven state machines (Salesforce, Dynamics) unify transition tables | Two sources, machine-checked, zero live drift; unification needs a sparse or jsonb column | **Rejected.** Trading a *checked* duplication for polymorphism no constraint can check is a net loss |
| **FIN-7** | Explicit state machines with fail-closed enforcement at every write path | Enforced in RPCs only | **Adopted** — but by copying ORVION's *own* rules to the second door, not by importing a foreign model |

**On the task's ETA instruction specifically:** no historical ETA rule was encoded as a generic ORVION rule. The 7/60-day windows appear **only in VOID-1's recommendation text**, as evidence for an owner decision, and are **document-type- and jurisdiction-specific** — which is why they are not in code. `external_submission_status_code` remains a transport-level lifecycle with no policy attached.

---

## 9. CHANGES MADE

| File | Change |
|---|---|
| `supabase/migrations/202607060200_*.sql` | **NEW** — FIN-7: six transitions + `invoices_enforce_status_transition` |
| `supabase/tests/94_invoice_state_machine_test.sql` | **NEW** — 21 assertions incl. PAR-4 defect injection |
| `supabase/tests/54_transition_permission_parity_test.sql` | Six invoice transitions named to their owning RPCs in `_rpc_owned` |
| `supabase/tests/88_parent_state_on_every_door_test.sql` | Sixth verified non-defect, with the `payments`-has-no-`invoice_id` evidence |
| `scripts/verify_database.sql` | CHECK 5g pin 11 → 12 |
| `reports/master/MASTER_GAP_REGISTER.md` | Census section; TAX-1 retraction; FIN-7 implemented; GOV-17/18; 7 Status forms fixed; 5 contradictory rows corrected |
| `_ORVION_CANONICAL/manifest.md` | Live state → 191; open-decision line (6 ids added); Last Completed; Next capability |
| `reports/evidence/primary-ledger-evidence.json` | Refreshed to 191, proven against Primary's live fingerprint before writing |
| `reports/README.md` | Latest-session pointer |

## 10. VERIFICATION

| Check | Result |
|---|---|
| `npx supabase db reset` | 191 migrations, exit 0 |
| **Pass A** | **94 files / 1347 assertions — PASS** |
| **HTTP × 6** | **414 passed / 0 failed** (29 · 104 · 40 · 74 · 107 · 60) |
| **Pass B** (no reset) | 94 / 1347 — **Pass A = Pass B** |
| Smoke | `ALL CHECKS PASSED (76 tables, 71/603 catalog)` |
| Repository consistency | **CLEAN, Checks 1–19, exit 0** |
| **Database parity** | **CLEAN — local proven; primary ledger, functions AND structure proven** |

**PRIMARY PARITY = PROVEN**, and the values were read **from Primary** via the `supabase-primary` MCP, not supplied from the repository (GUARD-1):

- ledger **191 / `a54dd1d0c303b24fbbfccbae13b787de`**
- functions **`334a5bf9d6ccea0a1990e3b55444f654` / 261** (unchanged — no function added)
- structure **`8130e14bd2ef3d286da1a2f383ed4773` / 3,455** (was 3,448: +6 transition rows, +1 trigger)

`apply_migration` stamped `20260904132610`; the ledger row was **normalised to `202607060200`** per the recorded GUARD-1 precedent. The evidence file was rebuilt from the repository's own filenames and **proven to hash to Primary's live fingerprint before being written**.

Two caller traps hit and recorded: the parity guard wants the **bare md5** for `-PrimaryLogicHash` (I passed `hash|count` and it reported a false FUNCTION DRIFT), and Check L5 correctly refused until the manifest's published hashes were updated.

## 11. REMAINING DECISION DEBT

**13 genuine owner decisions**, all on the manifest line, each narrowed to one question: SUP-4c · CUST-3 · VOID-1 · PLAN-1 · DOC-LC-3 · CANON-26-1 · RET-1 · RET-2 · BLOCKED-4 · BLOCKED-5 · AUDIT-4 · CAT-6 · BOOK-2 · A3.

**8 engineering defects** (FIN-9, FIN-11, DEAD-2/3/4, IDENT-2, CAT-5, GOV-9) plus **GOV-16** and **GOV-18** — engineering-owned, no owner input, scheduled.

**69 scheduling-backlog items** — a product roadmap, correctly *not* on the decision line.

**0 evidence gaps.**

## 12. NEXT STEP (exactly one)

**GOV-18** — widen Check 2's open-detection beyond a bare `OPEN` cell, with a mutation proof in both directions. It is the guard that should have caught GOV-17's five contradictions and did not, and every future census depends on it being honest. It needs no owner input.

**Batch 6 remains not started**, as instructed.
