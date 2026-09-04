# ORVION — Owner policy package: SUP-4b decided and shipped; TRANS-1 / DELIV-1+PH8-2 / PLAN-1 / QUO-4 held at their decision boundaries

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: **PARTIALLY CLOSED — and deliberately so.** One of the five targets carried an owner decision and is closed. The other four are owner decisions the owner did not make in this package; each is held at its exact boundary rather than invented.

---

## 1. EXECUTIVE SUMMARY

The package named five targets. **Exactly one of them — SUP-4b — arrived with an explicit owner decision.** The other four (TRANS-1, DELIV-1/PH8-2, PLAN-1, QUO-4) are, in the register's own words, `BLOCKED — ARCHITECTURAL DECISION`, `OPEN (subsumed by PH8-2's decision)`, `owner: the three undefined "Limited" ceilings`, and `OWNER DECISION — reproduced, deliberately NOT fixed`. The governing rule for this package was explicit: *"If an unresolved business decision is encountered, isolate the exact decision and stop at that decision boundary rather than inventing an answer."* That is what happened, and §4–§7 state each boundary precisely.

**SUP-4b is decided, implemented, tested, deployed to Primary and documented.** The ceiling **warns and never refuses**. The answer to the owner's first question dissolved the other two: with nothing refused, no override permission is needed and no concurrency serialisation is required.

Two residues were **isolated rather than folded in**: **SUP-4c** (cross-currency "or equivalent") and **CUST-3** (a customer-side threshold). Both would have been new business rules.

---

## 2. INITIAL GIT STATE AND REMOTE SYNCHRONIZATION

| Fact | Value |
|---|---|
| Branch | `main` |
| HEAD at start | `8b3a08f` |
| origin URL | `https://github.com/PlatPlusHub/CRM.git` |
| `git fetch origin` | exit 0, no new objects |
| origin/main | `ce60179` |
| merge-base(HEAD, origin/main) | `ce60179` — **equal to origin/main** |
| Divergence | **none** — 1 ahead, 0 behind, fast-forward relationship |
| Working tree | clean |
| `8b3a08f` present | yes — the prior OBS-remediation package, committed and unpushed |

**No reconciliation was required and none was performed.** origin/main had not advanced; local held one legitimate unpushed commit which was preserved and is included in this push. No rebase, no reset, no force.

---

## 3. CANONICAL BASELINE (verified, not remembered)

| Axis | Value at package start |
|---|---|
| Migrations | 189, latest `202607060000` |
| Ledger | `4029ecefa4bf40639b3bb61d63f986ef` (repo = local = Primary) |
| Active Change Request | None |
| Batch-6 pointer | "the remaining Batch-6 tables" — Phase C table-by-table audit |
| Open owner decisions | QUO-4 · SUP-4b · RET-1 · FIN-7 · VOID-1 · VERIFY-1 · TRANS-1 · DELIV-1 · PH8-2 · PLAN-1 · DOC-LC-2 · DOC-LC-3 · CANON-26-1 · LIC-1 |
| Authorization model | `deny > user grant > role grant > plan gate`, plan gate terminal |

`SYSTEM_PROMPT.md` was named in the package instructions but **does not exist in this repository**; the governing documents are `AGENTS.md` (conduct + boot) and `GOVERNANCE.md` (knowledge authority), per `GOVERNANCE.md §2`.

---

## 4. TRANS-1 — NOT CLOSED, and the reason is recorded in the register itself

**Definition (read, not recalled):** status-transition permissions are stated twice — inline `VALUES` lists inside each `app.advance_*` function, and rows in `app.status_transitions` which the BEFORE-UPDATE trigger actually reads.

**Current state, from the register's own later investigation block:** the *drift* is FIXED and guarded — all ten `advance_*` functions and all 104 `status_transitions` rows were compared exhaustively with **no live disagreement**, and `54_transition_permission_parity_test.sql` was repaired to parse every function and to check both directions.

**Why it is not closed here:** the register records the remaining item as `Status: BLOCKED — ARCHITECTURAL DECISION (narrowed) · Owner: owner`, and states the question exactly: *"whether to make `app.status_transitions` the single runtime source and where the per-entity extras then live."* The extras are real and measured — `advance_lead` carries `is_closure`, `advance_booking_item` carries sub-status handling, and the permission is per-transition in some functions and a single constant in others. The manifest adds a prerequisite: *"classify the 13 ungoverned status columns against canon 26 first"* (CANON-26-1).

**Verdict: OPEN — owner architectural decision, unchanged.** No code was written. Closing it would have required choosing a canonical home for the per-entity extras, which is a design decision the owner reserved.

---

## 5. DELIV-1 / PH8-2 — NOT CLOSED; the delivery boundary restated honestly

**Reconstructed from repository evidence, not from memory:**

| Question | Answer, with evidence |
|---|---|
| What is implemented? | The ORVION-side pipeline: capture → map → claim → acknowledge. `app.claim_conversion_deliveries` exists with the SPEC-123 lease; failures are durably `failed` with `error_message`. |
| What is contract-ready? | The delivery contract in `MASTER_INTEGRATION_CATALOG.md §2` with its `§2a` corrections. |
| What is actually deployed? | The database half, on Primary. |
| What is missing? | **The n8n workflow itself. Measured: there is no `n8n/` directory and no n8n artifact anywhere in the repository.** No UI exists either. |
| What could be completed now? | Nothing that is not blocked below. |
| What is blocked? | **PH8-2 is an owner decision** — whether non-consented conversions warrant an operational surface, or are intentionally silent. **DELIV-1 is explicitly `OPEN (subsumed by PH8-2's decision)`** and its own row says building half of it now *"would pre-empt that decision"*. |

**Verdict: OPEN — owner decision, unchanged.** The consent gate is correct and stays; the gap is observability, and what a delivery-health surface should report is the owner's call. **No fake delivery claim is made anywhere: nothing in ORVION sends a conversion to Google today.**

---

## 6. PLAN-1 — NOT CLOSED; the derivable half was already shipped

**Current state:** `PARTIALLY RESOLVED` — the *feature* half shipped (66 entitlement rows from canon 28 + 17; the gate sits inside `app.has_permission`, proven on all three surfaces by `30_plan_gating_test.sql`).

**Two things remain, and they are different in kind:**
1. **Numeric ceilings have no counter.** `app.plan_limit` reads a ceiling; `usage_counters` is empty and nothing counts against it.
2. **Three ceilings canon leaves undefined** — Basic Reporting (Starter), Integrations and Offline Conversion (Professional) are marked "Limited" with no number anywhere. The register calls this *"an owner business decision, seeded uncapped rather than guessed."*

**Why (1) was not built either:** a counting mechanism needs a reset period (calendar month? billing cycle?) and an over-limit behaviour (refuse? warn? degrade?) — neither is derivable, and **three of the ceilings it would count against do not exist as numbers.** Building the counter first would be building a mechanism whose inputs are undefined.

**Verdict: OPEN — owner pricing decision, unchanged.** The authorization ordering was preserved exactly; the plan gate remains the terminal commercial boundary and was not converted into a permission grant.

---

## 7. QUO-4 — NOT CLOSED; a standing recommendation, not a decision

**Definition:** canon 28 scopes `CREATE_QUOTATION` "Assigned only" for `employee`; nothing enforces that on either door. Reproduced: one employee repriced a colleague's draft quotation line from 10,000 to 1.

**Why it is not derivable, in the register's words:** canon 28's scope column reads **"assigned/department"**, the 2026-08-24 owner directive granted department continuity deliberately, and SPEC-154-A's `is_my_booking_item` precedent would over-reach by blocking a department manager from editing their own team's quotation. *"Choosing between 'assigned' and 'department' decides who may work on whose quotation, which is a business rule."*

The register carries a **recommendation** — adopt the department reading, i.e. leave behaviour as it is — but a recommendation is not a decision, and the owner did not make one in this package. The boundary is pinned by assertion 15 of `84_quotation_line_integrity_test.sql`, so it cannot move silently.

**Verdict: OPEN — owner decision, unchanged.** No quotation redesign was introduced.

---

## 8. SUP-4b — THE OWNER DECISION, IMPLEMENTED

### 8.1 What the owner decided

Quoted rather than paraphrased: *"EXCEEDING the limit MUST NOT block operations"* · *"No new entry/addition/action should be prevented merely because the ceiling has been exceeded"* · *"When exposure exceeds the threshold: send an email notification to the Company Owner; send an email notification to the Finance Manager"* · *"The intended behavior is WARNING/ALERT, NOT REFUSAL/BLOCKING."*

### 8.2 The three open questions, all now answered

| Question | Answer |
|---|---|
| Which operation does the ceiling refuse? | **None.** It warns. |
| What may override it? | **Nothing needs to** — an override exists to bypass a refusal, and there is no refusal. No permission was minted. |
| Does it bind on all suppliers? | **All of them** (already DERIVED; a NULL ceiling is no ceiling, pinned by assertion). |

**The concurrency question was dissolved, not answered.** It mattered only because a *blocking* ceiling must serialise against the rows it sums. A warning cannot wrongly refuse anything, so **no lock, no deferred constraint trigger and no FIN-10-style aggregate re-read were introduced.** Choosing the non-blocking policy removed a class of engineering rather than deferring it.

### 8.3 What was implemented (`202607060100`)

- **Two canon-27 event types** — `supplier_credit_threshold_exceeded`, `supplier_credit_threshold_cleared`. Canon 27 is the SSOT and was updated first, because `app.record_event` refuses an unregistered code and says so.
- **`app.supplier_exposure_in_limit_currency`** — repeats `app.supplier_balance`'s *expression* for one currency **without its `VIEW_FINANCIAL_DOCUMENTS` gate**, because it runs in a trigger under whoever wrote the row. A salesperson locking a cost does not hold that permission, and calling the gated reader would have **blocked the write** — the exact outcome the owner forbade. **Deliberately not granted to `authenticated`** (proven by assertion): it is a system path, not a second read door.
- **`app.supplier_credit_alert_recipients`** — `owner` + `finance_manager` by role, modelled on `app.lead_responsible_managers`. **Role membership is the right expression because this is who gets TOLD, not who is ALLOWED.**
- **`app.evaluate_supplier_credit_threshold`** — compares exposure to the ceiling in the ceiling's own currency; emits the event and one notification per recipient; raises nothing.
- **AFTER-row probes on `booking_items` and `payments`** — the only two tables that can move exposure. Both OLD and NEW suppliers are evaluated so a supplier reassignment cannot leave the old supplier permanently "exceeded".
- **`supplier_credit` extended** with `exposure_amount` and `threshold_exceeded`, behind the unchanged `VIEW_FINANCIAL_DOCUMENTS` gate.

### 8.4 What was deliberately NOT implemented

- **No FX mechanism.** `public.exchange_rates` exists as a table and **no function in the database reads it** — measured, zero readers. `tenants.default_currency_code` is read by nothing. → **SUP-4c**.
- **No new configuration layer.** `suppliers.credit_limit_amount` + `credit_limit_currency_code` **is** the threshold, per supplier, already write-gated by `MANAGE_SUPPLIER_CREDIT`. **"100,000 EGP" is a VALUE the owner configures through that existing path, not a constant belonging in code.** No global-default column was invented. (Primary holds zero business rows, so there is no supplier to configure yet.)
- **No new notification type.** `notification_type = 'supplier_balance'` existed in the catalog with **no producer**; this migration is its first. Minting a second would have been duplicate authority.
- **No status/colour system.** Idempotency uses the **event ledger**: an alert is suppressed while the latest threshold event is already `exceeded`; the `cleared` event is what lets a later breach speak again.
- **No customer rule.** `public.customers` carries **zero** credit columns. → **CUST-3**.
- **No new permission, no permission widened.** `MANAGE_SUPPLIER_CREDIT` already grants exactly what the owner described. Verified live: granted to `ceo, finance_manager, owner`. The owner named Finance Manager and Company Owner; **`ceo` retains it on existing canonical authority** (canon 28's role set for `EDIT_LOCKED_COST`, ratified by the 2026-09-02 owner directive) — removing it would have been an unrequested authorization change.

### 8.5 Finance Manager authority — verified, not assumed

`finance_manager` holds `MANAGE_SUPPLIER_CREDIT`, `VIEW_FINANCIAL_DOCUMENTS` and `ASSIGN_SUPPLIER`. **No unrelated administrative or security permission was granted.** `MANAGE_PERMISSIONS` remains `ceo, owner` only. The owner's "full permissions in Accounting" was satisfied by what already existed; nothing was widened on the strength of a general phrase.

---

## 9. TESTS AND EXACT RESULTS — executed, by evidence class

| Step | Class | Result |
|---|---|---|
| `npx supabase db reset` | LOCAL RUNTIME | ✅ 190 migrations, exit 0 |
| **Pass A** `npx supabase test db` | LOCAL RUNTIME | ✅ **Files=93, Tests=1326, PASS** |
| `verify_api_end_to_end` | HTTP | ✅ 29 / 0 |
| `verify_lifecycle_branches` | HTTP | ✅ 107 / 0 |
| `verify_journey_branches` | HTTP | ✅ 74 / 0 |
| `verify_role_journeys` | HTTP | ✅ 104 / 0 |
| `verify_care_journeys` | HTTP | ✅ 40 / 0 |
| `verify_storage_end_to_end` | HTTP | ✅ 60 / 0 — **414 total, 0 failed** |
| **Pass B** (no reset, under all six suites' residue) | LOCAL RUNTIME | ✅ **93 / 1326, PASS — Pass A = Pass B** |
| Smoke `verify_database.sql` | LOCAL RUNTIME | ✅ `ALL CHECKS PASSED (76 tables, 71/603 catalog)` |
| `check_database_parity.ps1` | REPOSITORY + PRIMARY | ✅ **CLEAN, exit 0** |
| `check_repository_consistency.ps1` | REPOSITORY | ✅ **CLEAN, Checks 1–19** |

**`93_supplier_credit_threshold_test.sql` — 23 assertions, all pass.** The load-bearing ones: an over-ceiling write **lands and is counted** (the owner's core requirement, proven not asserted); exposure exactly *at* the ceiling does **not** alert (`>` not `>=`); the recipient set is measured with `set_eq` so the employee's absence is proven; a further over-ceiling write **plus three reads** add no second alert; a payment clears and a later cost re-alerts; a NULL-ceiling supplier carrying 999,999 EGP stays silent.

**Two guards caught real drift during this package and were fixed rather than bypassed:** the smoke test's pinned catalog count (601 → 603, because two event types were legitimately added) and the migration's `ON CONFLICT` arbiter (`catalog_values` uniqueness is carried by two **partial** indexes, so the original 2026-07 seed's idiom fails 42P10 today).

---

## 10. PRIMARY PARITY

**Deployed to Primary `vrvtsxexkiiiivlkdxzp`.** Target ref confirmed by a live `get_project_url`, not a transcribed string.

`apply_migration` stamped version `20260904085636`; **the ledger row was normalised to `202607060100`**, which is the recorded GUARD-1 handling used for `202607059100`, `059200`, `059400`, `059500`, `059800` and `059900` — the fingerprint is `md5(version || '_' || name)`, so a generated version would create permanent phantom drift.

Primary's three values, **read FROM Primary**:

| Surface | Value |
|---|---|
| Ledger | `1eaa2ec7d64f0403c8587c01aab6975f` — **190 migrations**, latest `202607060100_a_ceiling_that_warns_is_a_ceiling_that_speaks` |
| Function surface | `334a5bf9d6ccea0a1990e3b55444f654` — 261 functions |
| Structural surface | `9a33ada33f678bb8596b8c3eccbca586` — 3,448 objects across ten surfaces |

**`reports/evidence/primary-ledger-evidence.json` refreshed in this same commit** (`AGENTS.md §4` step 8). The 190-entry array was **proven** to hash to Primary's own live fingerprint before being written — verification against an independent authority, not derivation from the repository (GUARD-1).

`DATABASE PARITY: CLEAN` — local proven; primary ledger, functions and structure proven.

---

## 11. AUTHORIZATION AND FINANCE VERIFICATION

- **`deny > user grant > role grant > plan gate` is untouched.** No RLS policy, no `app.has_permission` change, no permission minted, granted or widened by this package.
- **Capability groups remain metadata.** Nothing in the decision path reads `capability_group`.
- **View/Manage independence intact**; server-side enforcement only; tenant isolation unchanged.
- **`threshold_exceeded` is not an authorization result** — it is a display flag behind the existing read gate, and ADR-0028 records that constraint on future callers.
- **`app.supplier_balance` was not modified.** The new helper repeats its expression for one currency on the system path; the authoritative gated reader is unchanged.

---

## 12. NOTIFICATION / EMAIL BOUNDARY — stated exactly

ORVION has **no email provider**: no SMTP, SendGrid, Resend, Postmark, Mailgun or SES reference exists anywhere in `supabase/migrations/**` or `scripts/**` (measured). Canon 10 listed "Email business alerts" as a **future** channel.

**What was built:** the in-system notification (canon 10's MVP channel) **plus** a `notification_deliveries` row on the `email` channel at status **`pending`** — the existing canonical delivery ledger, recording the obligation so a future dispatcher can act on it.

**No email was sent, and nothing in this repository claims one was.** Test assertion 18 asserts the status is `pending` precisely so a future reader cannot mistake the contract for delivery. Canon 10 now records the boundary and the owner's ratification of the channel.

## 13. UI WARNING BOUNDARY

There is no ORVION frontend and none was fabricated. The supported contract that already exists — `public.supplier_credit`, reachable over HTTP — now returns `exposure_amount` and `threshold_exceeded`: **one boolean a UI can render red.** Not a colour vocabulary, not a status catalog. Building a frontend to satisfy the warning was explicitly out of scope.

---

## 14. DOCUMENTATION UPDATED

`_ORVION_CANONICAL/27_event_catalog.md` (two event types, SSOT-first) · `_ORVION_CANONICAL/10_notifications_model.md` (email-alert ratification + delivery boundary) · `_ORVION_CANONICAL/manifest.md` (live state → 190/`1eaa2ec7…`/261/3,448/603, Last Completed, open-decision line) · `reports/master/MASTER_GAP_REGISTER.md` (SUP-4b closed; **SUP-4c** and **CUST-3** added) · `reports/architecture-decision-records.md` (**ADR-0028**) · `reports/master/MASTER_API_CONTRACT.md` (regenerated) · `reports/README.md` · `ai-map.json` (regenerated) · `scripts/verify_database.sql` (catalog pin 601 → 603).

**No historical report was rewritten.** Superseded current-state claims were replaced in the Living documents that own them.

---

## 15. FINAL STATE

| Axis | Value |
|---|---|
| Migrations | **190**, latest `202607060100` |
| Repo / local / Primary | ledger `1eaa2ec7d64f0403c8587c01aab6975f`, functions `334a5bf9…`/261, structure `9a33ada3…`/3,448 — **all three identical** |
| pgTAP | **93 files / 1326 assertions**, Pass A = Pass B |
| HTTP | **414 passed / 0 failed** across six suites |
| Guards | repository consistency **CLEAN 1–19**; database parity **CLEAN** |
| Closed this package | **SUP-4b** (owner-decided, implemented, deployed) |
| Still open | **TRANS-1 · DELIV-1 · PH8-2 · PLAN-1 · QUO-4** (unchanged owner decisions) · **SUP-4c** · **CUST-3** (new, isolated) |

---

## 16. NEXT BATCH-6 PATH

`MASTER_EXECUTION_PLAN.md`'s pointer is unchanged: **Phase C — the table-by-table audit**, and a next slice must attack a class none of the measured-clean ones covers.

The candidate identified by the 2026-09-04 discovery pass stands: **`app.*` functions granted to `authenticated` with no `public` wrapper** (the RBAC-6 class, of which one instance was ever fixed). Four business accessors remain candidates — `item_financials`, `customer_balance`, `supplier_balance`, `booking_item_profit`.

**`supplier_balance` has become the strongest candidate**, and this package is why: `supplier_credit` now publishes `exposure_amount` over HTTP, so a client can see *the number* for a supplier with a ceiling but still has no reachable door for the **per-currency breakdown** `app.supplier_balance` returns — and a supplier with **no** ceiling has no exposure door at all. The asymmetry that made it a candidate is now sharper, not resolved.

**The correct next step is an HTTP probe, not a migration** — call each of the four as a real role and record the status code. **Not started here, and not authorized by the plan.**

## 17. NEXT STEP (exactly one)

Probe `app.supplier_balance` over HTTP as a role holding `VIEW_FINANCIAL_DOCUMENTS`, and record whether the per-currency exposure breakdown is reachable. That single measurement decides whether the RBAC-6 class has a second real instance.
