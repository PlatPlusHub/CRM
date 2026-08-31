# ORVION — Batch 6 Table-by-Table Audit, First Slice: An Exchange Rate, and Who Granted the Role

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-31
Author: Claude Opus 5
Status: Complete. **`202607058100`–`202607058900` (nine) are NOT deployed to Primary — awaiting owner approval.**

---

## 1. Discovered

**The slice was chosen by measurement, not by preference.** The 54 tables `authenticated` can write were ranked by guard and test coverage. The first ranking was wrong and was caught before it was used: keying on `guard_write_capability` scored the finance tables as unguarded, which is false — FIN-3 gave them dedicated triggers under other names. Corrected, the sweep returned four results, three of them clean.

| Result | Verdict |
|---|---|
| Identity/organization — `users`, `user_role_assignments`, `user_branch_assignments`, `branches`, `departments` | **NOT A DEFECT.** SPEC-138 gives every one per-command policies requiring the canon-named `MANAGE_*` permission on INSERT, UPDATE and DELETE alike |
| Accounting core authorization — `exchange_rates`, `exchange_rate_adjustments`, `chart_of_accounts`, `journal_entries`, `journal_entry_lines` | **NOT A DEFECT.** Each requires its exact canon-28 permission; journal entries must balance |
| Every FK into `exchange_rates` | **NOT A DEFECT.** All tenant-qualified `(tenant_id, id)` — TENANT-1's class is closed here |
| `otp_challenges`, `totp_enrollments` | **NOT A DEFECT.** Owner-scoped by RLS (`auth_user_id = auth.uid()`), and **no reader at all** — no function, view or authorization path consults either. Inventing a consumer to justify a guard is this audit's stated non-goal |

**The outlier, and four defects.** Of every actor column in the schema, only one had no derivation — or so the first sweep said.

- **FX-1** — `exchange_rates.rate` is `numeric not null` with no CHECK. As a `finance_manager` who genuinely holds `SET_EXCHANGE_RATE`: `rate = -48.5` → **INSERT 0 1**; `rate = 0` → **INSERT 0 1**.
- **FX-2** — `exchange_rates.set_by` accepted from the caller: a rate attributed to an **employee who did not set it**, and, omitted, **no setter recorded at all**.
- **FX-3** — `user_role_assignments.assigned_by` accepted from the caller. Reproduced with a two-door comparison in one transaction, same actor: the RPC recorded the **owner who called it**; the direct INSERT recorded **the manager being promoted**; omitting the column recorded **NULL**.
- **FX-4** — `subscription_payment_proofs.reviewed_by` has no derivation. **Not reachable today** and recorded as such: no role holds `REVIEW_SUBSCRIPTION_PAYMENT`, and `platform_review_payment_proof` sets `reviewed_at` but never `reviewed_by`, running session-less where WP-00 requires a NULL actor.

**The method failure is the finding worth keeping.** The actor-column sweep used a hand-written list — `('created_by','set_by','uploaded_by','recorded_by','issued_by')` — and reported exactly one gap. Adding `assigned_by` produced FX-3. Widening again to `reviewed_by` produced FX-4. **A detector's blind spot is indistinguishable from a clean result.** An earlier version of the same query also mis-scored `subscription_payment_proofs.uploaded_by` as underived because its exclusion list did not know about `derive_proof_uploader`. The answer was to stop asking a list and ask the schema — which is now assertion 22 and closes **GOV-8**.

## 2. Proven

Pass A **83 files / 1,110 assertions** · HTTP **366/366** (29 · 102 · 74 · 38 · 66 · 57) · Pass B **83/1,110** under residue · smoke `ALL CHECKS PASSED (75 tables)` · parity **Check L1 CLEAN** · contract **71/71** · repository guard **CLEAN**.

Primary read live and written zero times: `169|4f79ecfd…`.

Every fix carries a positive control, a negative control and a mutation attack. The negative controls matter more than usual here: an ordinary employee is refused **42501** on both `exchange_rates` and `user_role_assignments`, which is what establishes that all four findings are **integrity** defects and not authorization ones — and that in turn is what denies them the session-less exemption an authorization rule would earn (ADR-0025).

## 3. Fixed

**`202607058800`** — CHECK `rate > 0` (strictly, unlike CONV-4: a free conversion *value* is real, a zero *rate* values every foreign amount at nothing), plus `app.derive_exchange_rate_setter`. **`202607058900`** — `app.derive_role_assignment_actor` and `app.derive_proof_reviewer`.

Layer chosen from the measured surface each time: FX-1 is a statement about the row and nothing else, and there is **no RPC** for exchange rates, so a CHECK on the only door is the narrowest thing that works. FX-2/3/4 are statements about the *session*, which a CHECK cannot express, so each is a trigger on the table — the door that was wrong. All three copy `app.derive_created_by`'s semantics verbatim, including the session-less exemption, rather than widening it: that function is attached to twenty tables and widening it to serve three is the **CUST-1** shape.

**Test 83 (22 assertions).** Assertion 22 is the durable part — it asks `information_schema` whether any actor column is accepted rather than derived, with no exemption list, because an exemption list is where the next gap hides.

## 4. Decisions

**MADE.** `exchange_rates.set_by` stays nullable — the session-less path must be able to record no actor (canon 35 principle 6), and NOT NULL would be a stronger claim than the evidence supports while breaking the first system writer that appears. FX-4 is guarded despite being unreachable, because canon 28 assigns `REVIEW_SUBSCRIPTION_PAYMENT` to owner/ceo/finance_manager and the seed has simply not granted it — the exposure arrives with that grant, silently.

**REJECTED.** Generalising `app.derive_created_by` to take a column argument (CUST-1). Adding a consumer to `otp_challenges`/`totp_enrollments` so their guards would mean something (the audit's non-goal). Carrying an exemption list in assertion 22 so FX-4 could stay unguarded.

**NO NEW ADR.** All four findings are instances of rules already ratified this week — **ADR-0024** (both doors) and **ADR-0025** (layer from the measured surface). Recording them again would duplicate durable reasoning, which is the failure mode the ADR threshold exists to prevent.

**SUPERSEDED.** GOV-8 moves from candidate to built.

## 5. Not fixed

Nothing found this session was left unfixed. `otp_challenges` / `totp_enrollments` are recorded as reader-less rather than guarded, deliberately. **GOV-9** (Check 11 is one-directional) remains open with its trigger, unchanged from the previous session.

## 6. Governance · Environment · Current state

`MASTER_GAP_REGISTER.md` (+FX-1..4; GOV-8 closed) · `MASTER_EXECUTION_PLAN.md` · `manifest.md` · `reports/README.md` pointer · regenerated contract + ai-map. No ADR was added, no canon touched, no roadmap change.

Local stack healthy; `supabase_vector` restarts on a loop and touches neither the database nor PostgREST.

**Repository and local: 178 migrations**, ledger `f3298da92ae6321665fa0e1ee6e71cfd`, function surface `f9f1824d8c8d000c78c048e0a8861fe5` (244), structural surface `8e74bf6b8a4c3c6cb2aac86c848f38b1` (3,368). **Primary: 169** — nine behind, by intent. HEAD `09adf19`; nothing committed, pushed or deployed.

## 7. Next executable step

Continue the table-by-table audit with the next bounded slice. The sweep's own ranking names it: the **care and conversation family** (`complaints`, `service_requests`, `conversations`, `conversation_messages`, `quotation_items`) — the journey branches the execution plan lists as not yet walked over HTTP, and the largest remaining block with thin behavioural coverage.
