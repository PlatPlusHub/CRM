# ORVION — Nine Migrations Deployed, and a Quotation the Customer Already Had

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-31
Author: Claude Opus 5
Status: Complete. **All 179 migrations are DEPLOYED to Primary; `DATABASE PARITY: CLEAN` (exit 0).**

---

## 1. Deployment

The owner approved deployment of the verified pending range. Reconciled against their criteria before anything was applied — all nine were implemented in this execution history, all carried passing tests, none embedded an unresolved owner decision, none was included merely to satisfy parity, and a scan for destructive statements found none (the three `update public.*` hits are all inside function bodies, verified by locating each against its enclosing `create function`).

`202607058100`–`202607058900` applied to `vrvtsxexkiiiivlkdxzp`, then `202607059000` from this session's own work. The CLI is not linked and linking needs credentials that must not pass through an agent (`AGENTS.md §6`), so each migration was applied through the MCP with its **exact version and name** written to `supabase_migrations.schema_migrations` — the ledger fingerprint is computed from `version || '_' || name`, so an auto-generated version would have produced permanent phantom drift.

**Parity re-proven from values read FROM Primary:** ledger `1f64a99c…` (179), functions `053f550f…` (245), structure `f7f2428a…` (3,372). Exit 0, all three axes.

**One measurement correction worth keeping.** The first post-deployment run reported `PRIMARY DRIFT` while both sides showed the identical md5. `Check L1` splits the local `count|md5`; `Check P1` compares the supplied string against the **bare md5**. Every previous session passed `count|md5` and got a DRIFT verdict that was *coincidentally correct* — Primary really was behind — so the format error stayed invisible until the two agreed. The guard was **not** touched: parity was genuinely clean and the fix was to pass the format the guard defines.

## 2. Discovered — the care/conversation slice

**Four of five tables came back clean, and were checked rather than counted.** `complaints` and `service_requests` carry seven triggers each. `conversation_messages` derives its sender and forbids rewriting a sent message. `conversations` lacks the archive and `created_by` guards its siblings have — and has neither `is_archived` nor an actor column, so those are guards it has nothing to apply to.

**`quotation_items` failed twice**, both with the RPC as positive control:

| Rule | `app.add_quotation_item` | Table door (before) |
|---|---|---|
| line on a **sent** quotation | refused — *"items can only be added to a draft quotation"* | **INSERT succeeded: a 7,777 line** |
| repricing a line on a sent quotation | **no RPC exists** | **10,000 → 1** |
| `unit_price = -5000` | refused — *"unit_price must be >= 0 and quantity > 0"* | **stored** |
| `quantity = 0` | refused | **stored** |

`quotation_items` had **no CHECK constraints at all**.

## 3. Fixed

**`202607059000`** — two CHECKs (QUO-3; bounds copied from the RPC, not chosen: `>= 0` for price because a waived fee is a real line, `> 0` for quantity because a zero-quantity line is not a line) and `app.guard_quotation_item_parent_editable` (QUO-2; a trigger because a CHECK cannot see the parent table, `SECURITY DEFINER` + REVOKE for BOOK-1's reason, no session-less exemption because it is integrity).

The **UPDATE half of QUO-2 is derived and labelled as such**: only INSERT has an RPC rule, because there is no `update_quotation_item` function at all. The rule is extended to UPDATE because `add_quotation_item`'s stated reason is about the parent's editability rather than about the verb — and because closing the door the RPC guards while leaving open the one it does not is the worse half of the same defect.

Test 84 (17 assertions, mutation-tested). A negative control proves the rule is not a permanent freeze: after a legal `rejected → draft` the same edit succeeds.

## 4. Discovered — the detector, again

Widening `83_actor_attribution_test.sql` assertion 22 from a hand-written name list to **every column ending `_by`** exposed **eight** more actor columns still accepted from the caller (**ATTR-2**): `booking_items.cancelled_by` / `no_show_recorded_by`, `customer_identity_merges.merged_by`, `invoices.voided_by`, `journal_entries.voided_by`, `payments.received_by` / `verified_by`, `tenant_license_activations.consumed_by`.

That is the same failure three times in one day: five names found FX-2 and looked finished; `assigned_by` produced FX-3; `reviewed_by` produced FX-4; asking the schema produced eight more. **A detector's blind spot is indistinguishable from a clean result.** Assertion 22 now pins the inventory and fails in *either* direction, so a new unattributed column fails it and each fix must delete its own line.

Not fixed here, deliberately: `payments.received_by` may be a legitimate business fact — which staff member physically received the cash, recordable on another's behalf — rather than a session actor. Deriving it would invent policy. Each needs its own reproduction.

## 5. Two traps this file walked into, recorded because they are the method

**TEST-3 again.** Test 84's mutation was placed second-to-last and its count was still un-done; the fix is that a mutation must never be among the last two assertions.

**A vacuous test, caught by its own failure.** The first closing assertion used `insert … select … where status <> 'draft'` — but the savepoint rollback had restored the parent to `draft`, so it matched zero rows, inserted nothing, and "passed". That is exactly the empty-fixture class `AGENTS.md §6` forbids. Rewritten to set the parent state explicitly and use a plain `INSERT … VALUES`.

## 6. Verification · Governance · Current state

Pass A **84 files / 1,127 assertions** · HTTP **366/366** · Pass B **84/1,127** under residue · smoke `ALL CHECKS PASSED (75 tables)` · **`DATABASE PARITY: CLEAN` exit 0** · repository guard CLEAN · contract 71/71.

`MASTER_GAP_REGISTER.md` (+QUO-2 ✅, QUO-3 ✅, QUO-4 📋 owner, ATTR-2 📋) · `MASTER_EXECUTION_PLAN.md` · `manifest.md` · `reports/README.md`. No ADR added: QUO-2/QUO-3 are instances of ADR-0024 and ADR-0025.

**Repository, local and Primary all at 179 migrations.** HEAD is published to `origin/main`.

## 7. Next executable step

**ATTR-2** — the eight remaining actor columns, one reproduction each, with `payments.received_by` and `payments.verified_by` judged on their semantics before any trigger is written. Assertion 22 already fails the moment the set changes, so the work is bounded and self-checking.
