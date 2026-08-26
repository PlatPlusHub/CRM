# ORVION — WP-00: Event / Audit Write-Path Integrity

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-26
Author: Claude Opus 5
Scope: Closing the forgeability of the audit spine (`public.events`, `public.security_events`),
plus the environment-health governance gap that let a 29-migration local drift go unnoticed.
Three further forgeries in the same class were proven and deliberately left to the SEC-1 decision.

---

## 1. The defect

Proven behaviourally as a real `authenticated` user holding the ordinary 13-permission `employee`
role, in a rolled-back transaction on the local stack. The read-scope anchor was verified first
(`bookings_visible = 0`), so the result is not a misconfigured fixture.

The employee inserted directly into `public.events` a row that was:

| Property | Forged value |
|---|---|
| `actor_user_id` | a **different employee** in the same tenant |
| `entity_id` | a booking the forger **could not read** |
| `event_type_code` | `totally_made_up_event_code` — **not in the registry** |
| `created_at` | **backdated 400 days** |

The only barrier was the `audit_insert` policy, whose `WITH CHECK` is
`tenant_id = app.current_tenant_id()` — tenant membership and nothing else. Nothing pinned actor,
entity, vocabulary or timestamp.

`public.security_events` carried the identical policy and the identical hole: a `login_failure`
could be fabricated against a colleague.

**Why this outranked every other open item.** Both tables carry `forbid_mutation`, so a forged row
can never be corrected or deleted — by anyone. The append-only guarantee, which exists to protect
history, instead made the forgery permanent. SPEC-143 closed the *read* side of the audit trail
(an event is readable exactly when its subject is); the *write* side was never closed. Customer 360,
Lead 360 and every chronological report are built on this spine.

One property already held and was left alone: `events.seq` is `GENERATED ALWAYS AS IDENTITY`, so
insertion order could not be forged, and the timelines order by `seq` rather than `created_at`.

## 2. Why the obvious fix was wrong

The prior session proposed converting `app.record_event` to SECURITY DEFINER and pinning tenant and
actor to the session. Verification of all 50 callers showed that would have **broken the n8n
integration contract and the SLA job**.

Five SECURITY DEFINER callers run with **no user session** and pass a tenant read from a row, with a
null actor: `app.process_lead_sla` (scheduled), `app.claim_conversion_deliveries` and
`app.record_conversion_delivery_result` (the two n8n conversion RPCs), and
`app.capture_attribution_click`. For these `app.current_tenant_id()` is null. Pinning tenant to the
session unconditionally would have made every one of them raise.

## 3. The mechanism

`app.record_event` is the **only** writer of `public.events` — 50 `app` functions call it and no
other function inserts into the table — so making it the sole *privileged* writer costs nothing.

* `app.record_event` → SECURITY DEFINER, keeping `set search_path = ''`. It joins
  `app.has_permission`, `app.plan_allows`, `app.item_financials` and `app.enforce_entity_reference`,
  which were already DEFINER; no new pattern was introduced.
* Tenant and actor become authoritative, **conditionally**:
  * user session present → `p_tenant_id` must equal the session tenant, else raise; actor is forced
    to `app.current_user_id()`, ignoring the argument.
  * no session (system / integration) → tenant taken as given but must not be null; actor must be
    null, since a system path may not name a human actor.
* `created_at` is not in the INSERT column list, so it is the server-side default and cannot be
  supplied by any caller.
* `revoke insert on public.events, public.security_events from authenticated`.

The event-type and severity registry checks were already inside `record_event`; they now become
**unbypassable**, because the direct-INSERT route that skipped them is gone.

### Deliberately not changed

* **`security_events` has zero legitimate writers** — no `app` function inserts into it. Revoking
  INSERT removed only the forgery path. The table stays write-dead until a governed producer is
  built; inventing one here would have fabricated capability.
* **The `audit_insert` policies were left in place.** With the grant revoked they are inert — a
  policy cannot admit a write the grant already denies — and removing them would churn the RLS
  coverage model for no security gain.
* **`authenticated` keeps EXECUTE on `app.record_event`**, because 45 of its 50 callers are SECURITY
  INVOKER and run as the user. A direct call is still possible but can now only produce a truthfully
  attributed, server-timestamped, registry-valid event in the caller's own tenant — self-incriminating
  rather than forgery. This is the bounded residual the mechanism accepts, and it is asserted in the
  test rather than left implicit.

## 4. Proof

`supabase/tests/34_event_write_path_test.sql` — 11 assertions, run as a real `authenticated`
employee, because the defect was invisible to a postgres-role test: postgres bypasses both the grant
and the policy that were the only things in the way.

Both denial and **positive baseline** are asserted, since a test that only proves a denial is the
failure mode this repository has already been bitten by:

1–2. direct INSERT into `events` / `security_events` → `42501 permission denied`.
3–4. `app.create_task` still succeeds end to end and lands exactly one `task_created` event.
5. actor is the caller, taken from the session.
6. `created_at` is server-side.
7–8. a direct `record_event` naming a colleague is accepted but **attributed to the actual caller**.
9. cross-tenant write refused.
10. unregistered `event_type_code` refused.
11. the no-session system path still writes — pinning down the branch that keeps n8n working.

Full suite **34 files / 307 assertions, 0 failures**. Smoke: `ALL CHECKS PASSED`. The original
forgery probe, re-run verbatim, now fails at `permission denied for table events`.

Parity: repo = local = Primary = `f5902d9dc743c316fc6421230d092e6f`, 119 migrations. Verified live on
Primary: `authenticated` holds SELECT only on both tables, `record_event.prosecdef = true`, 104 `app`
functions and 116 policies unchanged. The documented `apply_migration` version-stamp hazard occurred
(`20260826183847`) and was reconciled to `202607053000`.

## 5. Same class, NOT fixed — evidence for SEC-1

The sweep was deliberately broadened past the two audit tables. Three further forgeries of
authoritative history were proven by the same employee in the same run. Each is a **business** table
whose write model is precisely the open SEC-1 decision, so fixing them here would have silently
decided SEC-1:

| # | Forgery | The guard that makes it permanent |
|---|---|---|
| V3 | insert a backdated `lead_assignments` row fabricating assignment history | `forbid_assignment_history_rewrite` then freezes it |
| V4 | set `customers.first_registered_user_id` to self at INSERT, stealing first-handler attribution | `freeze_first_registration` then makes it uncorrectable |
| V5 | UPDATE `offline_conversions`, altering the "immutable" Google identity snapshot and value (15,000 → 999,999; customer e-mail → attacker's) | none — the table has no immutability trigger at all |

The pattern worth naming: in V3 and V4 an existing immutability guard **amplifies** the forgery
instead of preventing it. Each guard protects against *rewriting* history but not against
*fabricating* it in the first place. V5 additionally breaches the `MASTER_INTEGRATION_CATALOG §2`
contract, which requires the conversion identity snapshot to be immutable.

V4 is independently fixable without touching the write model (force the first-registration columns
from the session at INSERT) and is the cheapest of the three.

## 6. Governance — why a CLEAN guard hid a 29-migration drift

Earlier in this programme the repository held 118 migrations, the manifest claimed local was at 118,
and `check_repository_consistency.ps1` printed `REPOSITORY CONSISTENCY: CLEAN` — while the local
database was at **89**, missing 29 migrations, 41 `app` functions and 40 policies. Every check
passed because Check 9 compares the manifest to the migration **files** and never opens a database.

Two changes, kept separate so neither verdict can be over-read:

* **`scripts/check_database_parity.ps1` (new)** — derives the expected fingerprint from the migration
  files using the same recipe as Check 9, then compares it to the live local ledger, and to Primary
  when `-PrimaryFingerprint` is supplied. An unreachable database reports **UNPROVEN**, never CLEAN.
* **`check_repository_consistency.ps1`** now prints its own scope on success: *"repository files only
  — no database was queried."* Stating the limit is what stops a CLEAN result being quoted as
  evidence of live parity, which is exactly how the drift survived.

## 7. Status

**WP-00: EARNED → CLOSED.** Every acceptance criterion satisfied individually; no unexplained side
effects; guard CLEAN at commit; suite and smoke green; local/Primary parity proven by fingerprint
and by live re-verification of the security property on Primary.
