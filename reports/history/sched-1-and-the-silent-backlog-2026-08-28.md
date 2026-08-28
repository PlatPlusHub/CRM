# ORVION — SCHED-1: Choosing a Scheduler Is the Owner's; Making the Gap Visible Was Not

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migration `202607056300`, test `60_storage_backlog_observability_test.sql`, four new HTTP
assertions in `verify_storage_end_to_end.ps1`, and `53` (surface pin extended).
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `72bed6d` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. What actually needs scheduling, measured rather than assumed

Re-proven live on Primary:

| job | schedule |
|---|---|
| `app.reconcile_document_storage()` | `30 0 * * *` |
| `app.process_lead_sla()` | `* * * * *` |
| `app.process_subscription_lifecycle()` | `10 0 * * *` |
| **the storage executor** | **none** |

The executor is an Edge Function, ACTIVE, `verify_jwt = true`. Every part of it is proven end to end
by `verify_storage_end_to_end.ps1` — it claims work, destroys bytes through the Storage API, reports
the outcome, and honours FND-1's failed-attempt contract. Everything works except that **nothing ever
calls it**.

---

## 2. The three routes, and why none of them is mine to choose

| route | availability, re-proven live | cost |
|---|---|---|
| **A. pg_cron + pg_net + Vault** | `pg_cron` 1.6.4 **installed**; `pg_net` 0.20.4 available, **not installed**; `supabase_vault` **installed** | gives the **database** outbound HTTP, a capability ORVION does not have today |
| **B. n8n schedule → HTTP** | n8n live: 0 workflows, 2 credentials | makes a core retention path depend on n8n's uptime |
| **C. scheduled GitHub Action** | repo has Actions | couples data-plane operations to CI |

Route A deserves a note, because it changes an earlier judgement of mine. When `pg_net` was first
declined, the stated reason was that it "would require storing a service key in the DB". **Vault is
installed**, so the secret could live encrypted there rather than in a migration, a column or a log —
a materially better position than the one recorded. It is still not free: installing `pg_net` gives
Postgres itself the ability to make outbound HTTP calls, which is a real widening of the blast
radius, and that is an architectural call.

All three need the owner to place **one secret**, which never passes through the agent
(`AGENTS.md §6`). So SCHED-1 is **BLOCKED — EXTERNAL DEPENDENCY** on that secret and
**BLOCKED — ARCHITECTURAL DECISION** on the route. Installing `pg_net` unilaterally to make a metric
move would be precisely the "select a scheduler because it is convenient" the directive forbids, and
I did not.

---

## 3. What needed no decision at all: the gap was silent

If the executor never runs — or is scheduled and then quietly breaks — retention-expired findings
accumulate, bytes ORVION has undertaken to destroy stay on disk, and **nothing anywhere says so**.
`document_storage_findings` is platform-readable, but reading a table is not a signal: a backlog is
only visible if someone thinks to look and already knows what "too old" means.

`app.storage_action_backlog()` answers the one question that separates *working* from *never ran*:

```
pending_actions  ·  oldest_pending_age  ·  attempted_and_failed  ·  last_attempt_at  ·  unresolved_findings
```

**The age is the load-bearing field.** A count alone cannot distinguish a healthy system with work in
flight from a dead one — both report a positive number.

### The design decision that matters

It calls `app.claim_storage_actions(500)` rather than restating its eligibility rules. Those rules
are not trivial: retention re-verified at claim time, `is_current = false`, the version no longer
being the document's current one, **and** RET-2's rule that a restricted tenant's data is frozen so
its actions are never claimable.

A monitor that measured a *different* population than the worker consumes would be worse than no
monitor: it would report zero while work piled up. So there is one definition of "outstanding", used
by both — and assertion 3 of the new test asserts the two counts **equal**, not merely both
plausible.

Exposure follows `claim_storage_actions`: an `app.*` definer, a `public.*` invoker wrapper, both
`service_role` only. How far behind the platform is must not be readable by a tenant, and certainly
not probeable anonymously.

---

## 4. Tests

Suite **59 files / 689 → 60 files / 700**, 0 failures, green fresh and with all five HTTP suites'
residue. HTTP **175 → 179**.

`60_storage_backlog_observability_test.sql` (11) — zero under the default retain-forever policy (the
monitor does not manufacture work from a null policy, and the executor agrees at zero too); then
retention is switched on inside the transaction and **the monitor's count is asserted equal to what
the executor would claim**; the age proven to move; FND-1's failed attempt proven to keep the work
outstanding *and* become countable; the RET-2 suspension proven to remove work from both together;
and the endpoint proven unreachable by `anon` and by an authenticated tenant user, with a positive
control that `service_role` can.

The four HTTP assertions repeat the monitor-equals-worker check over the wire, where the two are
separate round trips rather than one query.

| What failed first | Cause | Resolution |
|---|---|---|
| `53_api_surface_test` assertions 1 and 3 | the new endpoint was not on the pinned surface list, and the count is pinned too | added under the platform group with its reason, count 73 → 74 — **the guard did exactly its job** |

---

## 5. Environment, parity and guards

| Axis | Value |
|---|---|
| Migrations | **152** — repository, local, Primary |
| Fingerprint | **`3a8b8211d475940375e358bd36d25173`** on all three |
| Endpoint exposure | `anon` 0, `authenticated` 0, `service_role` yes — identical local and Primary |
| pgTAP | **60 files / 700 assertions / 0 failures** |
| End-to-end HTTP | **179/179** — storage 40 · employee 29 · branches 26 · roles 27 · lifecycle 57 |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN |

---

## 6. Classification

**PROVEN** — the backlog measures exactly the population the executor consumes, including under the
RET-2 exclusion; the age moves; a failed attempt stays outstanding and becomes countable; the
endpoint is platform-only over real HTTP.

**UNPROVEN** — nothing outstanding.

**FAILED** — none.

**BLOCKED** — **SCHED-1** (the route, and its one secret) · TRANS-1 · DOC-EXP-1 · AUTH-1 · FIN-5 ·
SYSADMIN-1 · TASK-3 · RET-1, RET-2, ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1 ·
DEL-1 (partial) · PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — `pg_net` deliberately left uninstalled; the backlog endpoint restricted to
`service_role`; the monitor delegating to the claim function rather than duplicating its rules.

---

## 7. Next logical work

The executable engineering in this directive's list is exhausted. What remains is **owner
decisions**: SCHED-1's route and secret, RET-1's retention period, DOC-EXP-1's notification cadence,
AUTH-1's OTP/TOTP architecture, FIN-5's per-type approval permissions, SYSADMIN-1's empty role, and
TRANS-1's unification of transition authority.
