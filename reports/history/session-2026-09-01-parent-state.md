# ORVION — The Parent's State Is a Rule on Every Door

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Status: Complete. **183 migrations, repository = local = Primary; `DATABASE PARITY: CLEAN` (exit 0) on all three axes.**

---

## 1. Discovered

The care/conversation slice was re-entered **from live state**, not from the 2026-08-31 report that recorded four of its five tables as clean. Four of them still are — but this pass asked doors the earlier one had not, and recorded *why* each is clean rather than that it is:

- **The status machines are governed.** `complaints` (9 rows), `conversations` (11), `service_requests` (8) all appear in `app.status_transitions`, **every row carrying a `permission_key`**, and `app.enforce_status_transition` **fails closed** on an unregistered transition. TRANS-2's null-permission hole does not exist here.
- **`resolved_at` / `closed_at` / `resolution_notes` have no consumer.** No view, no function, no policy reads them — measured across `pg_proc`, `pg_views` and `pg_policies`, not assumed. So the fact that `guard_write_capability` accepts `CREATE_COMPLAINT` *or* `RESOLVE_COMPLAINT` for a write that sets them is behaviour-neutral, and it is doubly so because **the two permissions are held by identical role sets**. Recorded as checked, not as a defect: a trigger here would guard a field nothing reads against a caller who already holds the alternative.
- **`conversations.current_branch_id` / `current_department_id`** are written by `start_conversation` and read by **nothing** — DEAD-1's class, kept per `AGENTS.md §3` (a conversation transferred between departments is inevitable; the transfer capability is not built).
- **Descriptive-field editability on a closed complaint** is SEC-2's ratified INTENTIONAL half, not a new finding.

**`conversation_messages` failed, and it was not one defect.** `app.send_conversation_message` refuses a message on a **closed** conversation; nothing on the table stopped it. That is ADR-0024's class one table over from QUO-2 — so the question became whether there were others.

### The class, derived rather than listed

For every `app.*` function that reads a parent's registered `app.status_transitions.status_column` and then INSERTs into a **different** table, does any BEFORE INSERT trigger on that table read the same column? Catalog-derived, no hand-written table list, no exemption list.

Twelve pairs came back unguarded. **Reading the function bodies reduced them to four** — the other eight only *read* the parent state. `record_lead_interaction` reads `lead_status_code` solely to decide the `assigned → contacted` transition and refuses nothing on it; `upload_document` and `upload_subscription_payment_proof` **create** the document in the same transaction, so there is no prior parent state to refuse on; `process_lead_sla` writes `notifications`, where `authenticated` holds no INSERT at all. **Static analysis was the lead; the source was the verdict (MEAS-1).**

## 2. Proven — all four reproduced before any code was written

Each with the RPC as positive control, each as a caller who genuinely holds the capability, so every refusal is the state rule and not a permission:

| RPC refused | Table door returned |
|---|---|
| `only an accepted quotation can produce a booking (status: draft)` | **INSERT 0 1** — the booking cited an offer the customer never accepted |
| `cannot request finance approval on a cancelled/no_show/archived booking item` | **INSERT 0 1** — a `pending` finance request against a cancelled line |
| `cannot add a version to an archived document` | **INSERT 0 1** — version 2 on an archived document |
| `conversation is closed; reopen it before sending a message` | **INSERT 0 1** — a message on a finished engagement |

The conversation case is the worst of the four in one specific way: `conversations.updated_at` does not move for a direct INSERT, so the thread shows no sign that anything was appended after closure.

**One reproduction error worth keeping.** The first attempt at the booking case had `create_booking` refuse with *"customer is not in your tenant"* — a positional-argument mistake, not the rule. **A refusal for the wrong reason is not evidence**, so the whole script was rewritten to named arguments before anything was believed. The same discipline caught three fixture faults that would each have produced a false result: an invalid `sender_type_code` (`'employee'`; the catalog offers `customer/external_provider/system/user`), a cancellation with no `cancellation_reason_code`, and an invalid `approval_type_code`.

## 3. Root cause

Not four oversights — one. Every one of these rules was written **inside the function that needed it**, at a time when the function was assumed to be the door. `authenticated` holds INSERT on all four tables and PostgREST publishes them, so the RPC was never the only door and the rule was never enforced. ADR-0024 states this; what was missing was a way to *find* the instances, which is what the derivation above now provides.

## 4. Fixed — `202607059400`

**One function, four triggers, not four copies.** The rule is a single rule — *the parent's state decides* — with four subjects; four copies is precisely how TRANS-1's transition authority came to live in two places. The per-table detail is one `CASE`, the shape `app.guard_write_capability` already uses for the same reason.

Written around three hazards that have each already cost this repository a defect:
- **`to_jsonb(new) ->> '...'` for every field.** Naming `new.quotation_id` in a trigger that also serves `document_versions` raises `record "new" has no field` — SPEC-159-A, and again in PP-4.
- **SECURITY DEFINER**, so the parent lookup is not RLS-filtered: an invisible parent would read NULL and a NULL-tolerant guard is no guard (BOOK-1). The composite tenant-qualified FK makes a NULL unreachable, and it **fails closed anyway** — "unreachable" is a claim, the raise is a proof.
- **An unmapped table raises**, for the reason `guard_write_capability` refuses one.

**BEFORE INSERT only, deliberately.** Each rule governs the *creation* of the child. Freezing the child to the parent's *later* state would break working paths: `review_finance_approval` must still decide a request whose item was cancelled in the meantime, and an integration must still reconcile a message's `external_message_id` after its conversation closed. **No session-less exemption**, per ADR-0025 — integrity, not authorization; `guard_quotation_item_parent_editable` is the precedent and carries none either. **Messages copied verbatim** from each RPC, so the two doors cannot give one caller two accounts of the same rule.

**Cross-path sweep (`AGENTS.md §3 5b`).** All six writers of the four tables are `SECURITY INVOKER` interactive RPCs — there is **no** SECURITY DEFINER, batch, set-based, scheduled or integration writer, and `orvion_integration` holds no grant on any of the four. Question 2 (what consumes the changed structure): the package adds triggers and changes no column, key shape, grant, policy, permission, catalog or status vocabulary, so nothing derives behaviour from it; the SEC-1 ceilings in tests 10 and 57 count *capability* triggers and did not move.

## 5. Detector improvements

`88_parent_state_on_every_door_test.sql` assertion 25 re-derives the population on every run and pins the five verified non-defects. **It was attacked in both directions before it was trusted:**

- **Remove a guard** → the `guarded` set is computed live, so the pair returns to the list and the string stops matching. Assertion 22 proves the same behaviourally by defect injection.
- **Add an unguarded pair** → a probe function reading `conversations.conversation_status_code` and inserting into `public.complaints`, created inside a rolled-back transaction, took the count 5 → 6 and the detector named it. It is not pinning a constant.
- **Its two structural assumptions were measured, not assumed:** **0** `app` functions lack a pinned `search_path` (so `public.` qualification is mandatory, not a style convention), **0** build an INSERT with dynamic SQL, **0** write an unqualified `insert into`. Those three counts are what make a source-text predicate sound here rather than merely convenient — without them it would be the formatting-sensitive class MEAS-4 was.

**The HTTP gap is the more interesting half.** `verify_care_journeys.ps1` *already* asserted that the RPC refuses a message on a closed thread, and *already* POSTed a message straight to the table. The defect survived because the two were never asked **at the same moment**: the RPC was refused while the thread was closed, and the table was posted to after it had been reopened. Two correct assertions, arranged so that neither could catch it. The new assertions ask the table door the identical question at the identical moment, plus a negative control after reopening.

## 6. Verification

`npx supabase db reset` → **Pass A: 88 files / 1,211 assertions** → HTTP **376/376** across six suites (29 · 102 · 74 · 71 · 40 · 60) → **Pass B: 88 / 1,211** under every suite's residue → smoke `ALL CHECKS PASSED (75 tables)` → Primary's three values read **FROM Primary** → `DATABASE PARITY: CLEAN` exit 0 → artifacts regenerated → repository guard CLEAN.

Deployed to Primary through the `supabase-primary` MCP with the **exact version and name** (`202607059400` / `the_parents_state_is_a_rule_on_every_door`) written to `supabase_migrations.schema_migrations`, because the ledger fingerprint is `md5(version || '_' || name)` and `apply_migration`'s generated version would create permanent phantom drift. The target ref was confirmed by a live `get_project_url` (`vrvtsxexkiiiivlkdxzp`), not a transcribed string.

## 7. Not fixed, and why

- **The `(sender_type_code, message_direction_code)` pair is unconstrained on both doors** — `('customer','outbound')` is storable. Not a two-door gap and not fixed: which combinations are legal is a property of the messaging model **CONV-3** defers, and inventing it now is the business policy `AGENTS.md §6` forbids. Recorded inside CONV-3.
- **`conversation_messages.external_message_id` has no unique index** while `conversations.external_conversation_id` does — the two halves of a thread are not equally idempotent, so a redelivered *message* would duplicate. No producer exists today, so nothing can create the duplicate; the correct key depends on whether the provider's id is unique per tenant or per channel, which is a property of the provider being integrated. Recorded inside CONV-3 as a requirement its writer must ship **with** it, not afterwards.
- **QUO-4** was not reopened (owner directive §10) and remains the one open owner decision from this batch.

## 8. Governance

**A live instance of GOV-9, found by checking the direction the guard does not.** **QUO-4** has been an open owner decision in `MASTER_GAP_REGISTER.md` since 08-31, carrying `**owner: QUO-4**` in its own owner column — and the manifest's `Open owner decisions` line **never named it**, across three subsequent sessions and three CLEAN runs of every guard. Check 11 verifies manifest → register and not the reverse, which is exactly what GOV-9 predicted, on the very next owner decision after it was written. The manifest line is corrected; the guard is not, and the reason is unchanged. What the second occurrence adds is a *candidate convention* that did not exist when GOV-9 was written — `**owner: <ID>**` is used by exactly one row today, so promoting it to the convention makes the reverse check attackable in both directions. That is a governance-guard package, not a line in this one.

**`MASTER_EXECUTION_PLAN.md` carried "NEXT SLICE: ATTR-2" after `202607059300` closed ATTR-2** — written the same day the plan recorded SEC-1c and SUP-1 and left the pointer alone. A plan that names a finished slice as the next one is worse than one that names none. Corrected, and the header date with it.

No ADR added: PARENT-1 is an instance of ADR-0024 (every RPC rule must hold on the table door), ADR-0025 (enforcement layer from the measured surface; integrity may not exempt session-less paths) and ADR-0026 (scope as a predicate).

## 9. Environment

Local stack restarted from cold at session start — containers were seconds old and `supabase_auth` was still restarting, which `AGENTS.md §6` warns reads identically to a defect in a transcript. Brought to healthy with `npx supabase start` before anything was measured.

## 10. Current state

**Repository, local and Primary all at 183 migrations** (latest `202607059400`). Ledger `a4e519b1bb1cf003274c4a153ce610bb`, function surface `69f4d1ab766f60d958e0bbd41c36dc4f` (253), structural surface `9a0e2b6c2c42779bcbf417a3438b3404` (3,388 objects across ten surfaces). **No undeployed migrations. Approval debt = ZERO.**

## 11. Next step

**The remaining Batch-6 tables**, per `MASTER_EXECUTION_PLAN.md`, which owns the order. The care/conversation family is closed on every door it has, and the parent-state class is now pinned by a catalog-derived assertion that fails in both directions.
