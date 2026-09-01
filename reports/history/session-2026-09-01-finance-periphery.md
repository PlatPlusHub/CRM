# ORVION — The Finance Periphery, and the Blind Spot in My Own Detector

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Status: Complete. **184 migrations, repository = local = Primary; `DATABASE PARITY: CLEAN` (exit 0) on all three axes.**

---

## 1. How the slice was chosen

From the catalog, not from a list. Of the 54 tables `authenticated` can write, rank by grants × guard triggers × CHECK constraints × writing RPCs × test coverage, and take the bottom.

**That ranking was attacked twice before it was used, and it was wrong twice:**

- Counting BEFORE triggers scores `moddatetime` and `emit_creation_event` as protection. They guard nothing.
- Counting test-file mentions scores `branches` at 71, `users` at 67, `tenants` at 76 — because **every test builds a tenant fixture**. Appearance is not subjectship.

Corrected, the bottom of the list is sharp: `campaign_daily_metrics` and `exchange_rate_adjustments` have **0 pgTAP files, 0 HTTP suites, 0 writing RPCs, 0 CHECKs**; `journal_entry_lines`, `chart_of_accounts`, `financial_accounts` and `trusted_devices` are barely better.

## 2. Two hypotheses killed by measurement before any code was written

Recorded because the discipline is the deliverable, not the hit rate:

- **"`journal_entry_lines` accepts negative amounts."** It does not. `journal_entry_lines_debit_xor_credit_check` already enforces non-negative *and* debit-xor-credit — two of `create_journal_entry`'s three line rules were on the table door all along.
- **"`trusted_devices` is an MFA bypass."** It is not. `app.mfa_satisfied()` reads **only** the JWT `aal` claim and never consults the table. That measurement is what set DEV-1's severity to Low rather than High.

## 3. Proven

Each reproduced with the RPC as positive control, as a `finance_manager` who genuinely holds the capability.

**PAY-1 (High) — money against an invoice that was never issued.**

| | RPC | Table door |
|---|---|---|
| draft invoice | refused: `only an issued/partially_paid/overdue invoice can be paid (is draft)` | **INSERT 0 1** |
| voided invoice | refused: `… (is voided)` | **INSERT 0 1** |
| archived invoice | refused: `invoice is archived or voided` | **INSERT 0 1** |

1,000 EGP sat allocated against a **voided** invoice. **FIN-10's `enforce_invoice_allocation_ceiling` was green throughout and correctly so** — it caps the *amount* and never reads the invoice's *state*. A guard's presence is not evidence for a property it does not measure (PAR-3).

**JE-1 (Medium) — a line posted to a retired chart account.** The finance_manager deactivated accounts 1000 and 1100 — which the policy permits with CREATE_JOURNAL_ENTRY, and which is a normal thing for an agency to do — the RPC refused with `unknown or inactive chart account code: 1000`, and the identical two lines went in by direct DML.

**DEV-1 (Low) — two rows for one device, reproduced through the RPC alone.** Two concurrent psql sessions, the first holding its transaction open, both called `app.record_trusted_device('RACE-1')`; the table ended with **two rows**. `revoke_trusted_device` then revokes one by id, and `my_trusted_devices()` shows the same device as **revoked and trusted at once**. LIC-2's check-then-act shape, in a function nobody had raced.

*One reproduction was thrown away first.* The initial two-session script ran sequentially and hard-coded the INSERT rather than replicating the function's `if not found` condition — so it "proved" a duplicate that the real function would never have created. A reproduction that does not reproduce the code path is not evidence; it was rewritten to call the RPC itself.

## 4. Fixed — `202607059500`

**PAY-1 and JE-1** extend `app.guard_parent_state_allows_write`, PARENT-1's mechanism, with both refusals in the RPC's own words and its own order. BEFORE INSERT only. **Cross-path:** each of the three tables has exactly one writer, all `SECURITY INVOKER` and interactive; `record_payment` inserts the allocation *before* it advances the invoice status — verified by reading, so its own path cannot trip the new guard.

**DEV-1** takes a unique index on `(auth_user_id, device_identifier)` plus an `on conflict do update` upsert. The invariant is not invented: the function already treats the pair as a key, looking the row up by exactly those two columns and re-trusting it in place. Chosen over LIC-2's compare-and-swap because that guarded a *single-use* resource where the loser must fail; here the loser must re-trust the same row. The identical two-session experiment after the fix produced **one** row.

## 5. The finding about my own guard — MEAS-5

**PARENT-1's detector could not see PAY-1.** `202607059400` derived its population from `app.status_transitions`, and **`invoices` has no rows there** because canon defines no Invoice State Machine (FIN-7). So `invoices.status_code` is a state that governs behaviour and is not a governed *transition*, and a detector anchored on a catalog of transitions was structurally blind to the highest-severity instance of its own class. That is PAR-3's rule turned on my own work from the previous session: a guard whose description outruns its measurement **is** the finding.

Widened to `status_transitions.status_column` ∪ every column an `enforce_catalog_codes` trigger validates — read out of the **trigger arguments**, which is the repository's own structural definition of a state vocabulary. Two further filters are what made it usable rather than noise: the parent must be a real **foreign key** parent, and the child must be a table `authenticated` may **INSERT**. The naive widening returned **46** pairs, mostly actor and plan lookups; pinning those would have been an exemption list wearing an inventory's clothes. The structural version returns **9**, each classified into two reasons (same-transaction creation; reads-but-refuses-nothing).

Counterexample-tested both ways: dropping this migration's two triggers takes it **9 → 10**, and the reappearing pair is `record_payment -> payment_allocations (invoices)` — PAY-1 itself. Rolling the drop back returns it to 9.

**Its residual is stated in the test rather than hidden.** State carried as a boolean flag (`is_active`, `is_archived`, `is_current`) is still not enumerable this way. **JE-1 is exactly that residual**, and it was found by reading function bodies, not by the detector. It is paid down table by table as this audit reaches each one — which is what the Batch-6 sweep is for.

## 6. Not fixed, and why

- **JE-2 — a journal entry balances across two currencies.** Reproduced: a 100 **USD** debit and a 100 **EGP** credit, two lines, committed. `enforce_journal_entry_balanced` sums across currencies; `create_journal_entry` validates none, so **both doors agree** and it is not an ADR-0024 gap. Canon 31 lists `currency_code` on the line and states only the debit/credit exclusivity rule; **DC-10 and DC-11 are deferred to Batch 4**. The two standard answers — one currency per entry, or transaction currency plus a base-currency translation column — are an accounting-model choice, and a same-currency CHECK now would foreclose the second, which is the model DC-11 anticipates. Recorded with its trigger.
- **DEAD-4 — three writable tables with neither producer nor consumer.** `campaign_daily_metrics`, `exchange_rate_adjustments`, `financial_accounts`, measured in **both** directions across `pg_proc`, `pg_views` and `pg_policies`. All three are guarded, so this is dead structure and not an open door. Kept per `AGENTS.md §3`. One concrete requirement recorded for whoever builds the producer: `campaign_daily_metrics` has only a **non-unique** index on `(marketing_campaign_id, metric_date)`, so a metrics sync that runs twice would double the spend.

## 7. Clean results, with the reason recorded rather than the count

- `chart_of_accounts`, `journal_entry_lines`, `exchange_rate_adjustments`: capability enforced by **per-command RLS policies** naming CREATE_JOURNAL_ENTRY / CREATE_EXCHANGE_RATE_ADJUSTMENT — proven by reading `pg_policies`, not assumed from SEC-1's residue note.
- `financial_accounts`: capability on a **trigger** (`guard_write_capability` → CREATE_JOURNAL_ENTRY), not in its policy, which is tenant-only. Two different mechanisms for the same class, both real.
- **`authenticated` holds DELETE on none of the six**, so every DELETE-path question in this slice is unreachable rather than unguarded.
- `campaign_daily_metrics` splits read (VIEW_MARKETING_DASHBOARD) from write (MANAGE_MARKETING_CAMPAIGN) correctly — and both are held by exactly {ceo, owner}, so the split is behaviour-neutral today. Measured, because RLS-1's whole subject was a policy where read conferred write.
- `trusted_devices` is `auth_user_id = auth.uid()` with no tenant, which is canon 34's Human Identity model, already ratified in SEC-1's residue.

## 8. Verification

`npx supabase db reset` → **Pass A: 89 files / 1,232 assertions** → HTTP **381/381** across six suites (29 · 107 · 74 · 71 · 40 · 60) → **Pass B: 89 / 1,232** under residue → smoke `ALL CHECKS PASSED (75 tables)` → Primary's three values read **FROM Primary** → `DATABASE PARITY: CLEAN` exit 0 → artifacts regenerated → repository guard CLEAN.

Deployed through the `supabase-primary` MCP with the exact version and name (`202607059500` / `money_allocated_to_an_invoice_that_was_never_issued`). Primary was checked for duplicate `(auth_user_id, device_identifier)` pairs **before** the unique index was created — 0 rows, 0 duplicates — rather than discovering it during the DDL.

## 9. Current state

**Repository, local and Primary all at 184 migrations** (latest `202607059500`). Ledger `ed3828994cc61d703e60d02100eeae63`, function surface `bd040fbcfaf19f54da666b5b24d03ba0` (253), structural surface `92342d9cad6762a6541b3959b6f35152` (3,391 objects). **No undeployed migrations. Approval debt = ZERO.**

## 10. Next step

**The remaining Batch-6 tables**, per `MASTER_EXECUTION_PLAN.md`, which owns the order. The boolean-flag residual of MEAS-5 is paid down as each table is reached.
