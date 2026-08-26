# ORVION — WP-03 Post-Package Discovery: two cross-tenant abort defects

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-26
Author: Claude Opus 5
Scope: The mandatory "what did this package introduce?" pass after WP-03, plus the fixes it forced
(`202607053200`). **WP-01 was not started** — this pass found real defects that had to be closed first.

Predecessor: `wp-03-subscription-state-enforcement-2026-08-26.md`.

---

## HEADLINE

WP-03 shipped green — 35 files, 331 assertions, 0 failures, parity proven — and still introduced
**two cross-tenant denial-of-service defects**. Neither was visible in the gate, in any test, or in
any policy. Both were found by asking one question of the catalog: *which SECURITY DEFINER functions
write a table the gate now protects?*

This is the concrete argument for the post-package discovery rule. A passing suite proved the gate
worked; it did not prove the gate was *safe to have added*.

## DISCOVERED

### DEFECT 1 (HIGH, was live) — `app.process_lead_sla` aborted for every tenant

The function loops `for r in select l.id, l.tenant_id ... from public.leads where lead_status_code =
'assigned'` with **no tenant filter** (SECURITY DEFINER, so RLS does not scope it) and writes
`lead_assignments`, `leads` and `notifications` — all gated — inside the loop. The gate *raises*.
The exception was unhandled, so the first restricted tenant reached rolled back the **entire** SLA
run. Every other tenant silently lost its SLA warnings and auto-reassignments.

Demonstrated rather than asserted — pre-fix definition restored in a rolled-back transaction:

```
PRE-FIX (no gate awareness):
ERROR:  subscription state "suspended" does not permit writes on public.notifications
POST-FIX (shipped version):
     0        -- completes cleanly, restricted tenant skipped
```

### DEFECT 2 (HIGH, was live, worse) — `app.map_outcomes_to_conversions` stalled the n8n pipeline

Its `insert into public.offline_conversions ... select` is **one set-based statement over a batch of
events spanning tenants**. A BEFORE trigger fires per row, so a single restricted tenant's row
aborted the whole INSERT — and because the abort happens *before* `update
public.integration_cursors`, **the cursor never advanced**. The mapper would then re-read the same
poisoned batch on every subsequent run, forever. That is not a delay; it is a permanent stall of the
Phase-8 integration contract (`MASTER_INTEGRATION_CATALOG.md §2`).

### CHECK A (clean) — cross-tenant UPDATE

The gate reads `tenant_id` from the row, so an UPDATE that *changes* `tenant_id` would present the
target tenant to the gate — and if that tenant were healthy, the gate would approve it. RLS is what
refuses. **PROVEN**, with a positive baseline first: same-tenant UPDATE succeeded, then the
tenant-changing UPDATE was refused (`new row violates row-level security policy`).

### CHECK B (clean) — global `catalog_values` rows

The gate skips rows whose `tenant_id` is null, which is every global/system catalog row. That branch
is **not** abusable: all three write policies require `tenant_id = app.current_tenant_id()`, and
`NULL = uuid` is never true, so global rows are unwritable by any role.

**My first attempt at this check was vacuous and I caught it**: run as `employee`, the denials proved
nothing because `employee` cannot write `catalog_values` at all — the control (B4) failed. Re-run as
`owner` (who holds `MANAGE_TENANT_SETTINGS`): the control **passed** (tenant row created), while
INSERT of a global row was refused and UPDATE of a global row affected `UPDATE 0` rows.

## FIXED — `202607053200`

**Skip, do not raise.** Both system paths now consult `app.subscription_allows_write` themselves and
exclude non-writable tenants *before* the gate can fire:

* `process_lead_sla` — `if not app.subscription_allows_write(r.tenant_id) then continue; end if;` at
  the top of the loop.
* `map_outcomes_to_conversions` — `and app.subscription_allows_write(r.tenant_id)` in the INSERT's
  WHERE, so the statement cannot abort and the cursor still advances.

The gate itself is unchanged and remains the backstop. The business reading is also correct: a lapsed
tenant gets no SLA automation and generates no new ad conversions; everyone else is unaffected.

**Deliberate consequence, recorded not hidden:** conversions whose source events occur while a tenant
is restricted are skipped and the cursor advances past them, so they are not created retroactively on
reactivation. Preferred over stalling the shared pipeline. `grace_period` is writable, so an ordinary
billing lapse loses nothing.

## VERIFIED

| Check | Result |
|---|---|
| New guard `36_subscription_gate_system_paths_test.sql` | 10/10 — both defects, both A and B |
| Suite | **36 files / 341 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` |
| Repository guard | CLEAN |
| Database parity | `CLEAN (local proven; primary proven)` |
| repo = local = Primary | **121 migrations**, `4824852c1aec4d259815617ba3f049e7` |
| Primary live | `process_lead_sla` and `map_outcomes_to_conversions` both gate-aware; 106 `app` functions; `orvion_integration` still holds EXECUTE on the mapper |

Every denial in the new test is paired with a positive baseline — the healthy tenant *was* processed
and its conversion *was* created — so "it did not throw" cannot pass for success.

## NOT FIXED (deliberate)

* `capture_attribution_click` and `merge_customer_identity` also write gated tables, but both are
  **single-tenant** (the tenant is an argument, not a loop), so raising is correct: it signals to one
  caller about one tenant and cannot deny service to another. Left as-is.
* Everything deferred by WP-03 stands: the broad `documents` exemption (WP-04 must narrow it), the
  missing `payment_proof` document type (WP-02), `usage_counters` empty (PLAN-1).

## BLOCKED

Unchanged and still not blocking: **BLOCKED-1** (trial plan tier + duration at provisioning) and
**BLOCKED-2** (`MANAGE_SUBSCRIPTION` "Limited" for Owner/CEO). Both commercial.

## LESSON WORTH KEEPING

A gate that **raises** is safe for a user's own write and dangerous inside any batch or set-based
statement that spans tenants. Whenever a future package adds a raising trigger, the same question
must be asked immediately: *which SECURITY DEFINER or set-based path writes this table on behalf of
more than one tenant?* Introspection query used:

```sql
-- SECURITY DEFINER functions whose body writes a gated table
select p.proname, ... from pg_proc p ... where p.prosecdef
  and p.prosrc ~* '(insert into|update)\s+public\.<gated_table>\M'
```

## CURRENT STATE

* **121 migrations**, latest `202607053200`, fingerprint `4824852c1aec4d259815617ba3f049e7` on
  repository, local and Primary.
* 72 tables · 106 `app` functions · 116 policies · 71 permissions · 42 subscription-gate triggers.
  Primary holds zero business rows.
* Suite 36 files / 341 assertions / 0 failures. Smoke passes. Both guards CLEAN.
* Git: `main`, tree clean, pushed.

## NEXT STEP

**WP-01 — creation events.** Re-introspect first (do not trust this list): four registered
`*_created` types are believed to have an executable producer that never fires —
`customer_created` (`app.create_customer`), `lead_created` (`app.create_lead`), `passenger_created`
(`app.create_passenger`), `trusted_device_created` (`app.record_trusted_device`). Confirm each is
registered and active, that no path already emits it, that it fires exactly once with correct
entity/actor/tenant, and that the 360 timelines become complete. Then apply the same post-package
discovery pass — the new events flow into `map_outcomes_to_conversions`'s event batch, so check
whether any newly-emitted type joins the conversion mapper's trigger set.
