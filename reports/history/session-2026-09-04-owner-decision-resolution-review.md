# ORVION — Owner-decision resolution review: eight re-derived, five closed, owner input 8 → 3

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: **COMPLETE — all eight decisions independently re-evaluated against the current implementation. Five closed, three genuinely require the owner.** Five failed `AGENTS.md §6`'s own test because **canon or the code already answered them and had not been read**. `RET-1` moves the other way: new external evidence makes it *more* urgent, with a dated deadline. Documentation-only — no migration, no test, no guard, no database change.

---

## 1. CURRENT STATE (verified before anything was touched)

Fetched first. `HEAD` = `origin/main` = `ls-remote` = `0caf9766ce4faafbaf4d304f12dd515e1efcc464`, ahead/behind `0 0`, **clean tree**, **191 migrations** (latest `202607060200`), **94 test files**. Repository consistency at that commit: **CLEAN, Checks 1–19, exit 0**. Local stack up; every measurement below was read from the live database, not from documents.

## 2. METHOD

`AGENTS.md §6` states the standing rule, and it is the whole method:

> *"an owner decision is legitimate only after canon, the SSOT/register, schema, implementation, consumers, tests, runtime, Primary and **authoritative external documentation** have been exhausted **in that order**."*

Each of the eight was re-derived from scratch in that order. **Five failed at the first or last step.** The register's descriptions were treated as evidence, never as truth — three of them turned out to be wrong about the facts they asserted.

---

## 3. SUP-4c — ✅ RESOLVED as ENGINEERING

**A. Exact question.** When a supplier's exposure spans currencies, at which instant is it converted for comparison against a ceiling stated in one currency?

**B. Origin.** Raised 2026-09-04 from the owner's SUP-4b wording "100,000 EGP *or equivalent*". Narrowed twice; the register's final framing called the instant "commercial, not derivable".

**C. Current implementation, measured.** `app.evaluate_supplier_credit_threshold` reads `suppliers.credit_limit_amount`/`credit_limit_currency_code`, calls `app.supplier_exposure_in_limit_currency(tenant, supplier, currency)`, and emits `supplier_credit_threshold_exceeded`/`_cleared` with `'enforcement' => 'warning_only'` plus a notification and a `pending` email delivery row. **The exposure function filters `and bi.currency_code = p_currency_code`** — exposure in any other currency is **silently dropped**, not converted. `public.exchange_rates` exists with `SET_EXCHANGE_RATE`-gated INSERT/UPDATE/DELETE policies (held by `owner`, `ceo`, `finance_manager`), an `exchange_rates_derive_setter` trigger so `set_by` cannot be caller-supplied, the subscription write gate, and `exchange_rates_unique_pair_instant_idx` on `(tenant, from, to, effective_at)` (DUP-1). **Zero functions read it and zero write it** — measured over every `app`/`public`/`reporting` function body.

**D. What engineering can determine.** *Facts:* the mechanism is complete, governed and unused; today's behaviour under-reports exposure. *Architecture:* which rate instant a **control** uses. *Not engineering's:* the ceiling values themselves — which are tenant data, already nullable, and were never asked of the owner.

**E. ORVION precedent.** SUP-4a gave the ceiling its currency so it could be compared per-currency; DUP-1 made the rate instant deterministic. Both were engineering.

**F. External research.** `12 CFR 32.9` requires current credit exposure to be determined by **mark-to-market value**; counterparty credit-limit systems convert each currency exposure into the **credit-limit base currency at the spot rate**. Historical-rate valuation is an **accounting** convention. *Applies* because ORVION's structure is identical — `credit_limit_currency_code` **is** the base currency. *Cost:* one function, one join. *Security:* none — read-only over an already tenant-scoped table.

**G. Alternatives.** (A) evaluation instant; (B) each item's cost-lock instant; (C) status quo — omit foreign-currency exposure.

**H. Recommendation — (A).** A credit ceiling is a present-risk control; the accounting instant is canon 14's locked rate and belongs to **DC-11**. (C) is indefensible: it silently under-reports. **Fail-safe, stated now:** exposure in a currency with no usable rate must be **reported as un-convertible**, never dropped. Reversible (warning-only), low complexity.

**I. Owner-input test — NO.** Canon 14 governs the *transaction* rate and is silent on control computations, which is a separation rather than a gap; external authority settles the instant; the "base currency" and "rate source" prerequisites already exist. **Resolved as engineering.**

---

## 4. CUST-3 — 📋 GENUINE BUSINESS DECISION (narrowed to one yes/no)

**A. Exact question.** Does ORVION offer a customer receivable ceiling at all?

**B. Origin.** The owner's SUP-4b directive said *"our financial dues at a customer or supplier"*; only the supplier half was built.

**C. Current implementation.** `public.customers` has **zero** credit/limit/term columns (measured against `information_schema`); `31_schema_draft.md`'s `customers` entry defines none. `app.customer_balance` already returns invoiced/paid/refunded/outstanding **per currency**, excluding voided and archived invoices. `notification_type = 'customer_balance'` is registered with no producer.

**D. What engineering can determine.** *Facts:* nothing to compare a balance against. *Architecture:* fully pre-solved — SUP-4b is a shipped template. *Not engineering's:* whether ORVION offers the capability. Building it is a **new commercial capability**, and `AGENTS.md §6` forbids inventing features as firmly as skipping defects.

**E. ORVION precedent.** SUP-4a/4b end to end, including the alert path and the `pending` email-delivery boundary.

**F. External research.** Receivable credit limits with warn/block thresholds are standard in mature CRM/ERP (Dynamics, NetSuite). *Applies* as a pattern; *does not* dictate that ORVION must ship it, and popularity is not proof.

**G. Alternatives.** (A) mirror SUP-4b (warn-only); (B) blocking ceiling; (C) do not build.

**H. Recommendation — (A).** The **"what number?" objection dissolves**: SUP-4b never asked the owner for a number — it shipped a *nullable* ceiling each tenant fills in, and a supplier with no ceiling has no ceiling. Warn-only is reversible; blocking is not. **The asymmetry is real:** a supplier ceiling caps what ORVION owes, a customer ceiling caps what ORVION is owed, and only the latter carries collection and dunning consequences — which is why (B) should not be chosen by default.

**I. Owner-input test — YES.** *Does ORVION offer a customer receivable ceiling?* Everything downstream is decided.

---

## 5. VOID-1 — 📋 GENUINE BUSINESS + REGULATORY DECISION

**A. Exact question.** Which of draft-only voiding, an ETA-shaped cancellation window on issued invoices, or a full credit-note model does ORVION implement?

**C. Current implementation — and this is materially better than recorded.** `invoices.voided_at` has **four readers**: `app.customer_balance` (excludes voided invoices from the receivable), `app.guard_parent_state_allows_write`, `app.issue_invoice` and `app.record_payment`. It has **zero writers**. **The consumer side of voiding is complete and correct; only the writer is missing.** `invoice_status_code` carries `voided` as an active system value, but `app.status_transitions` has no transition into it (FIN-7 registered six, deliberately excluding `voided`). **`public.permissions` contains no `VOID_INVOICE`, `CANCEL_INVOICE` or credit-note key**, and canon 26 defines **no invoice state machine at all**.

**D. What engineering can determine.** *Facts:* all of the above. *Not engineering's:* minting a permission and a state machine canon does not define. FIN-7 could register invoice transitions only because it **read them off existing RPCs** with existing permissions; there is no voiding RPC to read.

**F. External research — re-checked, and it is a three-mechanism regime, not the two the register recorded.** (1) **Buyer rejection** — a registered buyer may reject a B2B document within **3 days / 72 hours**; *not previously recorded at all*. (2) **Seller cancellation** — within **7 days**, with buyer approval, never after **60 days**, never once a credit note exists. (3) **Credit/debit notes** — identical format, signing and submission, and they must reference the **original document's UUID**. Submission is real-time on the day of issuance; validated invoices cannot be edited. *Applies* directly to (B)/(C); *does not* apply to a never-issued draft, which has no tax consequence.

**G/H. Alternatives and recommendation — (A) draft-only voiding.** It is the whole of what today's columns and four consumers can honour, invents no entity, and leaves (B)/(C) open until the agency's actual ETA obligations and integration timeline are known. **(B) and (C) must not be built speculatively** — they encode a live tax regime whose windows are jurisdiction- and document-type-specific.

**Separately, and true regardless:** `journal_entries` carries the same three void columns with **no readers anywhere** and no catalog state. Standard double-entry **reverses** a posted entry with a compensating entry and never voids it. **Engineering recommendation: those three columns are wrong for `journal_entries`.**

**I. Owner-input test — YES.** Canon defines no invoice machine and no void permission; both must be authored.

---

## 6. PLAN-1 — ✅ RESOLVED as DOCUMENTATION (the premise was a misreading)

**A. Exact question, as carried.** What are the three undefined "Limited" ceilings?

**C/D. What the evidence actually shows.** Canon 28 marks **five** features `Limited`, not three — Basic Reporting (Starter), and Automation, Integrations, Offline Conversion, Multi Branch (Professional). **The same document uses `Limited` throughout its ROLE columns to mean scope-restriction** — `| CREATE_LEAD | … | Limited | branch/department |`, `| VIEW_COMPLAINT | … | Limited | assigned/department |`. In canon 28's own vocabulary the word means *restricted in kind*, never *capped at a number*.

Every numeric ceiling lives in canon 17's separate **`Plan Numeric Limits`** table — seven rows — and it already supplies the numbers for **two of the five**: `Automations 100` and `Branches 3`, both correctly seeded as `max_automations` / `max_branches`. The pattern is explicit: a metered feature carries a boolean entitlement row **and** a `max_*` metric row.

The other three have **no row in canon 17 and no metric behind them**. `usage_metric_code` holds exactly six values — `users`, `branches`, `monthly_bookings`, `monthly_leads`, `storage_gb`, `automations`. **There is no metric for reports, integrations or offline conversions**, so a ceiling is not merely undefined — it is uncountable and unrepresentable.

`app.plan_limit` fixes the encoding in its own comment: *"NULL means no ceiling. Canon 17's 'Unlimited' and 'Custom' are both the absence of a limit, never a large number a caller might compare against and act on."* Enterprise uses that same encoding for all six metrics. **NULL is correct, not a placeholder.**

**E. Precedent.** **BLOCKED-2** — *"what `MANAGE_SUBSCRIPTION` 'Limited' means"* — was resolved 2026-08-27 by evidence, in the opposite direction to the obvious reading. A `Limited` cell is not automatically an owner question.

**H. Recommendation.** Keep NULL. If those three ever gain metered ceilings, the **metric must be built first**; the number is the last input, not the first.

**I. Owner-input test — NO.** No number is owed, because there is nothing to count.

---

## 7. DOC-LC-3 — ✅ RESOLVED as ENGINEERING (there is no canonical contradiction)

**A. Exact question, as carried.** Does un-archiving exist?

**C/D. The two authorities govern two different columns — the register conflated them.**

- **Canon 26** governs `documents.lifecycle_status_code`: states `active`/`superseded`/`archived`, three transitions, **no path back into `active`**. `app.status_transitions` implements exactly that.
- **`app.enforce_archive_authority`** governs the `is_archived` **boolean**, which exists on **thirteen tables** — `bookings`, `booking_items`, `customers`, `invoices`, `leads`, `passengers`, `quotations`, `suppliers`, `tasks`, `complaints`, `service_requests`, `customer_notes`, `documents` — every one carrying the same trigger, which selects `ARCHIVE_DOCUMENT` for documents and `ARCHIVE_RECORD` otherwise. Its sentence *"restoring is the same authority as archiving"* is about **who may flip the flag**. It says nothing about the document lifecycle, and never contradicted canon 26.

**So the question has two correct answers for two different things, both already settled and in force:** **no** for the document lifecycle, **yes** for the generic soft-archive flag.

**H. Recommendation — a one-directional implication:** **`lifecycle_status_code = 'archived'` ⟹ `is_archived = true`.** The pin in `69_document_lifecycle_test.sql` assumed *"synchronizing the fields in either direction removes one of them"*; this removes **neither**. Canon 26 keeps its no-un-archive rule; the boolean stays bidirectional on all 13 tables and on documents still `active`. Only the split state `archived/false` — the exact state assertions 18–19 pin today — becomes unreachable. Assertions 18–19 then move from "pinned defect" to "refused", with a mutation proof.

**I. Owner-input test — NO.**

---

## 8. CANON-26-1 — ✅ RESOLVED: PROVEN NOT A DEFECT

**A. Exact question.** Should canon 26 admit `active → suspended`?

**C. Measured.** `app.subscription_transition_allowed` encodes canon 26 exactly: `active → suspended` is absent, `read_only → suspended` and `active → cancelled` are present. **`app.subscription_allows_write` returns true only for `trial`, `active` and `grace_period`** within their windows; **`read_only`, `suspended`, `cancelled` and `expired` all return false**, and `app.enforce_subscription_write_gate` raises `insufficient_privilege` on every gated table.

**D. What this settles.** The stated concern — that suspension passes through `read_only`, which "may allow continued reads/export/**transacting**" — is **disproven for transacting**. Reads and export remain deliberately: that is canon 28's promise to a restricted tenant, stated in the gate's own error message. And **an active tenant can already be write-stopped in one step**: `active → cancelled` exists, `cancelled` blocks writes, `cancelled → active` restores.

**E. Canon's model is internally consistent.** `suspended` is the terminal of the *non-payment* ladder (`grace_period → read_only → suspended`, "Platform owner suspends tenant"); `cancelled` is the *administrative* terminal. **The "missing edge" is not missing — it is `active → cancelled`.**

**H. Recommendation — no amendment.** There is no safety gap and no capability gap. Should the owner later want a distinct one-step label for administrative suspension, that is an ordinary Change Request against canon 26, not decision debt blocking anything.

**I. Owner-input test — NO.**

---

## 9. BOOK-2 — ✅ RESOLVED: canon defined it all along

**A. Exact question.** What do the per-passenger overrides mean relative to the item total?

**C. The answer is in canon, in the section that defines the column.** `31_schema_draft.md`, `## booking_item_passengers`, Rules:

> *"`selling_amount_override` and `cost_amount_override`, when populated, represent this passenger's individual price/cost **within the shared booking_item**. When null, the passenger's share is treated as an **even split** of the parent `booking_item`'s `selling_amount`/`cost_amount`."*

**That answers the exact question asked.** The overrides are a **decomposition** of the item total with an even-split default — not independent per-passenger prices. **The register's claim that the meaning "cannot be derived from canon" was false**, and this is precisely the `AGENTS.md §6` ordering failure: canon was not exhausted before escalating.

**F. External research — corroboration only.** GDS/PNR fare quoting is per passenger, and a booking's total is the sum of its passenger fares. It agrees with canon; canon is the authority.

**H. Recommendation.** Enforce the derivable invariant (INV-1..4's class): for selling and cost independently, `Σ over passengers of (override, else item_amount / passenger_count) = item_amount`. **No consumer exists yet** — measured over `pg_proc` and `information_schema.views`, nothing reads either column — so this is scheduled, not urgent. The *meaning* is settled and must not be re-escalated.

**I. Owner-input test — NO.**

---

## 10. RET-1 — 📋 GENUINE COMPLIANCE DECISION, AND IT IS NOW DATED

**A. Exact question.** Should there be a finite retention period for superseded document versions, and what is it?

**C. The safe default is structurally in force, re-verified.** `app.document_retention_days()` returns `null`. `app.reconcile_document_storage`'s retention branch carries `and v_retention is not null`, so the `WHERE` is unsatisfiable and **no version is ever selected for destruction**. A zero or negative value is coerced to `null` rather than obeyed. Only **superseded** versions are ever eligible — `dv.is_current = false` **and** `d.current_version_id is distinct from dv.id`, two independent records checked together so a disagreement fails closed.

**F. External research — and this is the finding that changes the item's status.** Egypt's **Personal Data Protection Law 151/2020** now has **Executive Regulations**: Decree **816/2025**, issued **1 November 2025**, in force **2 November 2025**, published December 2025. The one-year transitional period ends with enforcement expected **1 November 2026** — roughly two months from today. The regulations require controllers to **define and document a retention period linked to the purpose of collection**, and to **erase personal data once that purpose is fulfilled** unless another legal obligation requires retention.

**"Retain forever, with no period defined anywhere" is therefore no longer merely conservative — it is the state the regulation names.** The previous disposition (*"leave NULL; re-open when counsel states a period or storage becomes a measurable cost"*) was recorded **without knowledge of these regulations** and understated the position: the driver is not storage cost, it is a dated legal obligation.

**An attractive engineering argument was tested and rejected**, recorded so it is not re-proposed: *"destroying superseded versions frees no personal data, because the current version holds the same data."* **That is false in the case that matters** — a superseded version typically holds a **replaced** passport or visa, personal data whose purpose *is* satisfied, which is exactly what storage limitation targets.

**D. What engineering can still do without legal input.** PDPL ties the period to the **purpose of collection**, so retention belongs **per `document_type_code`**, not as one global constant — a different shape from today's single function. Building that mechanism, with `null` still meaning retain, needs no legal decision.

**H. Recommendation.** **Keep `null` in force until counsel answers — never guess a legal period** — and **raise this now rather than at the deadline.** It is the only item on this list with a date attached.

**I. Owner-input test — YES.** The retention period per document type, reconciled against Egypt's competing **tax and commercial** record-keeping minimums. Counsel, not engineering.

---

## 11. EXTERNAL RESEARCH — WHAT WAS USED AND WHY

| Source | Used for | Applies because | Did **not** drive |
|---|---|---|---|
| `12 CFR 32.9`; counterparty credit-limit practice | SUP-4c | ORVION's structure is identical — a limit with its own currency, exposure converted into it | any ceiling *value*; those are tenant data |
| Egypt ETA e-invoicing rules (rejection 3 days; cancellation 7/60 days; credit/debit notes referencing the original UUID) | VOID-1 | ORVION targets Egyptian travel agencies and models `external_submission_status_code` | nothing was encoded — the rules stay in the recommendation, not in code |
| Egypt PDPL 151/2020 + Executive Regulations (Decree 816/2025) | RET-1 | ORVION stores passports and visas for Egyptian tenants | no retention period was chosen |
| GDS/PNR per-passenger fare quoting | BOOK-2 | corroborates canon; canon is the authority | canon 31 already decided it |

Global practice was used as **evidence for comparison, never as an automatic requirement**, and no external architecture was copied.

## 12–14. CLOSURES

**Closed by engineering (2):** **SUP-4c** — external authority fixes the rate instant, and canon separates transaction from control. **DOC-LC-3** — the two authorities govern two different columns; the fix removes neither.

**Closed by existing behaviour (1):** **CANON-26-1** — proven not a defect. Every non-paying state blocks writes; `active → cancelled` already stops a tenant in one step.

**Closed by documentation / canon already answering (2):** **BOOK-2** — `31_schema_draft.md` defines the overrides verbatim. **PLAN-1** — `Limited` is canon 28's scope word; canon 17 owns every number and there is no metric for the three.

## 15–16. WHAT GENUINELY REMAINS

**Business (2):** **CUST-3**, **VOID-1**. **Compliance (1):** **RET-1**.

## 17. RECOMMENDED IMPLEMENTATION ORDER

1. **GOV-18** — the guard, unchanged as next capability.
2. **SUP-4c** — convert exposure into the ceiling's currency at the spot rate; report un-convertible exposure rather than dropping it. First reader of `exchange_rates`.
3. **DOC-LC-3** — the implication `lifecycle_status_code='archived' ⟹ is_archived`, with a mutation proof; assertions 18–19 rewritten.
4. **BOOK-2** — the passenger-share invariant, when the first consumer arrives.
5. **GOV-20**, **GOV-19**, **GOV-16**, then **DELIV-1 + PH8-2**.
6. **RET-1's per-document-type mechanism** — buildable now with `null` still meaning retain; the values wait for counsel.

None of 1–5 needs owner input.

## 18. VERIFICATION

| Check | Result |
|---|---|
| Repository consistency | **CLEAN, Checks 1–19, exit 0** |
| Check 11 | all **3** manifest decision IDs resolve in the register |
| Check 14 | every manifest owner-decision ID is still open — the five closed ids now carry `✅ RESOLVED` on their own cells, so re-adding one would fail this check |
| Check 16 | no canonical document asserts a current owner decision the manifest does not list |
| Check 5 | manifest **6,957** chars, budget 7,000 — **no budget raised** (trimmed twice) |
| Migrations | **191**, unchanged |

## 19. PRIMARY PARITY

**No implementation occurred, so no fresh parity check is claimed.** Parity remains as last proven at `33a86d6`: ledger `a54dd1d0c303b24fbbfccbae13b787de` / 191, functions `334a5bf9d6ccea0a1990e3b55444f654` / 261, structure `8130e14bd2ef3d286da1a2f383ed4773` / 3,455, all read **from Primary** (GUARD-1). This session changed only documentation; **Primary was not touched and was not queried.**

## 20. FINAL DECISION-DEBT STATE

**ENGINEERING-RESOLVED: 2 · EXISTING-BEHAVIOR-RESOLVED: 1 · DOCUMENTATION-RESOLVED: 2 · GENUINE BUSINESS: 2 · GENUINE COMPLIANCE: 1.**

**Owner input required: 3** — down from 8, with no business rule invented and nothing hidden.

## 21. NEXT STEP

**GOV-18** — widen Check 2's open-detection beyond a bare `OPEN` cell, with a mutation proof in both directions. **Batch 6 remains not started**, as instructed.
