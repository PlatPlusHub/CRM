# ORVION — SPEC-154-B Decided and Implemented, and Three Rules That Only Existed in Migration Comments

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-31
Author: Claude Opus 5
Status: Complete. **`202607058100`–`202607058700` (seven) are NOT deployed to Primary — awaiting owner approval.**

---

## 1. What was discovered

**A financial document was readable by anyone whose department could see the record it hung off (PROVEN).** Reproduced before anything was written, with a discriminating control: two `employee`s in the same tenant, branch, department and role, with identical permissions, differing only in whether they owned the booking. Both read the manager-uploaded invoice document, identically:

| Caller | invoice (open) | invoice (confidential) | quotation | passport |
|---|---|---|---|---|
| Responsible employee | t | f | t | t |
| **Department colleague** | **t** | f | t | t |
| Finance manager | t | t | t | f |

The read came through the **department** axis, not the assigned one — `VIEW_DEPARTMENT_RECORDS` makes the booking visible, the booking makes the link visible, and the link was the entire test the policy applied. `created_by` explained nothing: every document was uploaded by the manager.

**A pgTAP mutation assertion placed last was never counted (PROVEN, TEST-3).** `finish()` reported *"planned 18 but ran 17"* for **test 80, shipped in a previous session**, while `pg_prove` counted the emitted `ok` lines and reported PASS. pgTAP's counter lives in a temp table, so `rollback to savepoint` undoes it. Both test 80 and the first draft of test 82 were also missing PAR-4's closing move — they proved the guard could be removed and never proved it came back.

**Three rules were being relied on that no file recorded (PROVEN).** `LESSON 4` and `LESSON 6` are cited by ordinal in three shipped migrations and five reports, and the numbering was defined nowhere.

**An open owner decision existed that no guard could see (PROVEN, GOV-9).** SPEC-154-B had no register row, was absent from the manifest's open-decision line, and every guard stayed CLEAN — because Check 11 verifies manifest → register and not the reverse.

**Two measurement errors of my own, recorded rather than tidied away.** (1) Test 82's first run "passed" four assertions it had no right to, because pgTAP runs as `postgres` and RLS does not apply to the table owner; the ad-hoc measurement had switched role and the test had not. (2) I asserted `employee` does not hold `VIEW_TRAVEL_DOCUMENTS` from reading the seed; the live grant set says they do — a later package widened it. Neither changed the result, because the empirical matrix had already established the behaviour; both are why static reading is a lead and not a verdict.

## 2. What was proven

| Gate | Result |
|---|---|
| Pass A (clean `db reset`) | **82 files / 1,088 assertions PASS** |
| HTTP, six suites | **366 / 366** — 29 · 102 · 74 · 38 · 66 · **57** |
| Pass B (no reset, under HTTP residue) | **82 / 1,088 PASS** |
| Smoke | `ALL CHECKS PASSED (75 tables)` |
| Parity Check L1 (repository ↔ local) | **CLEAN** — 176 migrations, `25a535eadb1414dc0fdc09456901d561` |
| Parity P1/P2/P4 (Primary) | **exit 1, and correct** — seven migrations undeployed by intent |
| Contract (Check L3) | regenerated, matches the live surface: **71 RPC endpoints, 71 with HTTP evidence** |

Primary was read live, four times, and written **zero** times: ledger `169|4f79ecfd…`, function surface `a994108b…` (236), structural surface `3a65328f…` (3,348).

## 3. What was fixed

**`202607058700` — SPEC-154-B (owner-decided, Option C).** One RLS disjunct changed; the other three are byte-identical to `202607052400`. The rule lives in the `documents` policy because that is the one layer **both** doors traverse — the table via PostgREST, and `app.financial_documents()`, which is `SECURITY INVOKER`. A trigger cannot express a read rule; a CHECK cannot see another table.

- `app.is_document_responsible(uuid)` — `SECURITY DEFINER` + REVOKE, for SUP-1's reason: responsibility is a property of the row, not of the caller's visibility, and the policy still requires a visible link before consulting it. Resolves through `document_links` to bookings, booking items and quotations, and through invoices and receipts to the booking they are **for**.
- **`quotation` left `app.is_financial_document_type`.** Canon 07 omits it, canon 28 governs it under CRM at assigned/department scope and lists it among the *operational* tables in its own read-scope model, and `app.financial_documents()` has never returned one. Leaving it in would have stripped the quotation document from a colleague covering an absent seller — defeating amendment 2 of the same 2026-08-24 directive.
- **`VIEW_FINANCIAL_DOCUMENTS` was not granted to anyone**, per ADR-0026.

Post-change matrix, measured: the responsible employee keeps the invoice; the colleague loses **only** it and keeps the booking, the quotation and the passport; the finance manager is unchanged on invoices; the uploader keeps their own upload.

**TEST-3 — tests 80 and 82.** Both now re-assert after the rollback, which restores the count and completes PAR-4.

**Tests and coverage.** `82_financial_document_responsibility_test.sql` (21 assertions, mutation-tested, three positive and three negative controls); test 81 assertion 20 converted from pin to rule (1 → 0); **+6 HTTP assertions** on `GET /rest/v1/documents` in `verify_storage_end_to_end.ps1`, proving the rule on the door a browser client actually has.

## 4. Decisions

**MADE / DERIVED.** Option C, owner-adopted, with three sub-answers derived rather than escalated: `quotation` is not a financial document (canon 07 + 28); financial classification does **not** imply confidentiality (canon 25 makes it per-document, canon 08/28 make strictness per-type — orthogonal); and the 2026-08-24 directive's two halves coexist, because SPEC-139 already applied the same split one table over (colleague keeps the booking item, loses the margin).

**REJECTED.** Granting `VIEW_FINANCIAL_DOCUMENTS` to employees — measurably unsafe: the confidential branch carries no link-visibility conjunct, so it would expose every confidential financial document in the tenant. Minting `VIEW_OWN_FINANCIAL_DOCUMENTS` — doubles the vocabulary for every scoped rule; canon names no such permission. Forcing `is_confidential` on financial types — satisfies canon 28 by destroying canon 08. Re-creating `app.financial_documents()` to fix its stale header — the false sentence is in a migration header, not in `prosrc`, so it would change the function surface and correct nothing a reader can see. Creating a new decision-memory document — GOVERNANCE §19 already ran that Earn-It determination and rejected a parallel knowledge layer; the gap was unused structure, not missing structure.

**RATIFIED AS ADRs (owner-authorised this session).** **ADR-0024** every RPC rule must also hold on the table door · **ADR-0025** the enforcement layer is chosen from the measured surface, and authorization may exempt session-less paths where integrity may not · **ADR-0026** scoped access is a predicate, never a coarser grant. The ADR record shape gained four fields from 0024 onward — *Alternatives rejected*, *Constraints on future work*, *Evidence basis*, *Revisit trigger* — because the previous six could not answer what a session with no chat history asks. Alternatives-rejected had been present in **1 of 23** records.

**SUPERSEDED.** The `LESSON 4` / `LESSON 6` ordinals are retired in favour of stable homes (`AGENTS.md §6` and ADR-0025), resolved in the ADR log.

## 5. What was not fixed, and why

- **GOV-9** (Check 11 is one-directional). Recorded, deliberately not fixed: the reverse check needs a parseable definition of "open owner decision" in a 362 KB register whose status column is emoji, and a detector that cannot be attacked with a counterexample in both directions is the class PAR-3 and MEAS-1 exist to prevent. Trigger recorded.
- **Canon 08 lists "Bank transfer proof" and "Supplier statement"** as controlled document types; canon 16's MVP list and the catalog have neither (`payment_proof` covers the first). Canon is protected — this is an annotation the owner must authorise, of the kind canon 08 line 15 already carries for Excel.
- **`app.upload_document('payment_proof', …, false)`** can still create a non-confidential payment proof. Narrowed, not closed, by the uncommitted `202607058500`, which charges `MANAGE_TENANT_SETTINGS` for any `payment_proof` row — so only an owner, who has tenant-wide read anyway, can reach it. Left as recorded rather than fixed on top of an undeployed migration.

## 6. Governance and SSOT changes

`architecture-decision-records.md` (+3 ADRs, record shape, lesson-numbering resolution) · `MASTER_ARCHITECTURE_DECISIONS.md` (§A rows for 0024–0026) · `MASTER_GAP_REGISTER.md` (+3 rows: SPEC-154-B ✅, TEST-3 ✅, GOV-4 📋; FIN-DOC-1 closed) · `MASTER_EXECUTION_PLAN.md` · `manifest.md` · `reports/README.md` pointer · regenerated `MASTER_API_CONTRACT.md` and `ai-map.json`. **Unchanged, deliberately:** canon (protected), the roadmap (no phase moved), `AGENTS.md` (protected), certification.

## 7. Environment · 8. Current state

Local stack healthy throughout; `supabase_vector` restarts on a loop and is unrelated to the database, PostgREST or the tests. Docker was already up.

**Repository and local: 176 migrations** (latest `202607058700`), ledger `25a535eadb1414dc0fdc09456901d561`, function surface `8ced8036ab7dac0088fa6e0be5da4cde` (241), structural surface `c2e2c15e9fb844250970b2008c258be3` (3,361 objects). **Primary: 169** — seven migrations behind, by intent. HEAD `09adf19`, unchanged; nothing committed, pushed or deployed.

## 9. Next executable step

**One:** put the seven verified migrations `202607058100`–`202607058700` to the owner for commit and deployment. Until then the parity guard's exit 1 is the correct verdict and must not be "repaired".

Independent of that approval, the next executable work is the rest of Batch 6 — the table-by-table audit, `notification_deliveries` having no producer, the 360 primitives — none of which depends on it.
