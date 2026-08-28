# ORVION — A Rule My Detector Could Not See, and the Eight Transitions It Was Hiding

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migration `202607056200`, test `59_lead_handler_authority_test.sql`, a rewrite of
`54_transition_permission_parity_test.sql`, and a widened detector in `10`.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `abb48d3` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. The correction that produced this package

`202607056100` — two packages ago, today — recorded that `app.record_lead_interaction`
"authorizes nothing", and left `lead_interactions` as SEC-1's last open item: *no bypass, only an
undecided business question about what logging an interaction should cost.*

**That was wrong.** The function enforces:

```sql
if not (v_actor is not null and v_actor = v_assigned) and not app.has_permission('ASSIGN_LEAD') then
    raise exception 'permission denied: not the assigned handler and lacks ASSIGN_LEAD';
end if;
if not app.mfa_satisfied() then
    raise exception 'multi-factor authentication required for this role';
end if;
```

`app.advance_lead` (non-closure transitions) and `app.convert_lead` state the same rule verbatim.

The error was in my **detector**, not in ORVION. I searched for `app.authorize('PERM')`, and the lead
rule is **assignment-shaped, not permission-shaped** — so a permission-shaped search could not see
it. The same narrow detector sits inside `10_grant_model_test.sql`'s SEC-1 ceilings, which is how a
guard came to report a hole that was not there while missing one that was.

Once read correctly, `lead_interactions` is not an open question at all. It is the SEC-1 pattern
exactly: **the RPC charges a rule and direct DML charged nothing.**

---

## 2. TRANS-2 — eight lead transitions were enforced for sequence and not for authority

Chasing the same rule into `app.status_transitions` found the larger half.

That table is the direct-DML side of transition authority, read by `app.enforce_status_transition`,
and its only authorization column is `permission_key` — applied `if v_permission is not null`. Eight
`leads` rows carry NULL:

```
assigned->contacted      contacted->qualified       qualified->quotation_sent   qualified->won
quotation_sent->negotiation   quotation_sent->won   negotiation->won            won->converted
```

They are null because the rule they carry — *the assigned handler, or ASSIGN_LEAD* — has no column
that can express it. The effect: **direct DML could walk a colleague's lead from `contacted` all the
way to `won` and on to `converted`, with no capability check of any kind**, while every RPC that
performs those same moves refuses anyone who is not the handler.

Reachable, not theoretical: `leads.scope_isolation` lets a user update any lead they can see, and
canon 28 gives `employee` `VIEW_DEPARTMENT_QUEUE` by ratified amendment — so an ordinary employee can
see, and could move, their whole department's pipeline. Marking a colleague's lead `won` is credit
for a sale you did not make.

### The fix, and why it invents nothing

`app.require_lead_handler(uuid)` holds the rule once, copied from the three RPCs that state it.
`enforce_status_transition` calls it where `permission_key` is null on `leads`, and
`app.guard_lead_interaction_authority` calls it on `lead_interactions`.

Nothing became stricter than the RPC that walks it. Closure transitions keep `CLOSE_LEAD` and take
the permission branch; `assign_lead`'s `new -> assigned` already carried `ASSIGN_LEAD`;
`process_lead_sla` is SECURITY DEFINER and session-less, so it returns at the platform-path check.

### And the class, not the instance

A null `permission_key` used to mean *allow*. It now means *apply this table's named fallback rule*,
and a table with neither a permission nor a fallback **fails closed**. Only `leads` has nulls today,
so the new branch is unreachable — which is the point: the next unguarded transition is a loud 42501
instead of a silent hole. Assertion 13 of the new test pins that no other table has one.

---

## 3. TRANS-1 investigated, and the guard that was checking a tenth of what it claimed

The directive asked whether the duplication between the `advance_*` functions and
`app.status_transitions` creates correctness, drift, maintenance or deployment risk — and to prove
that an `event` column is the right canonical home *before* changing the schema.

**Correctness: no live disagreement.** All ten functions and all 104 table rows were compared
exhaustively. Every transition the RPCs offer exists in the table; every permission the RPCs state
matches the table's; the only table-side extras are three transitions performed by other RPCs
(`assign_lead`, `record_lead_interaction`, `convert_lead`), documented as such in `advance_lead`'s
own comment.

**An `event` column is NOT obviously the right home, and this is the evidence.** The inline lists
carry more than an event: `advance_lead` carries `is_closure`, `advance_booking_item` carries
sub-status handling, and the permission is per-transition in some functions and a single constant in
others (`advance_refund` → `RECORD_REFUND`). Unifying the runtime source would need the table to
carry per-entity extras — a wide sparse table or a jsonb payload — which is an architectural choice,
not an obvious win. **TRANS-1 therefore stays open, narrowed**, and was not "solved" by guessing.

**Drift and maintenance risk: real, and now guarded properly.** `54_transition_permission_parity_test`
existed for exactly this — and it was checking **one function out of ten**. Its regex matched only
`('from','to','event','PERMISSION')`, which is `advance_booking`'s shape. `advance_quotation` puts
the permission third; `advance_refund` has three elements; `advance_lead`'s fourth is a boolean. Its
positive control — "at least 8 rules parsed" — was satisfied by that one function alone.

A guard that checks a tenth of what it claims is worse than no guard, because the next engineer
trusts it. The rewrite parses the **VALUES block** of every function (delimited, so
`p_to_status in ('cancelled','void',…)` — a real line in `advance_booking` that my first parser did
read as a transition — cannot be mistaken for one), fails if any of the ten stops parsing, and adds
the direction that was never checked: **every transition the trigger permits must be offered by a
function or named to the RPC that owns it.** That reverse check is precisely where TRANS-2 was
hiding.

101 rules, 10 tables, 0 permission mismatches, 0 RPC-only transitions, 3 named RPC-owned exclusions.

---

## 4. Exposure — SEC-1's residue is now INTENTIONAL only

| ceiling | before this package | after |
|---|---|---|
| tables `authenticated` may INSERT | 54 | 54 |
| …with no capability **trigger** | 18 | **17** |
| …with **no capability enforcement of any kind** | 4 | **3** |

And the three are `otp_challenges`, `totp_enrollments`, `trusted_devices` — the canon-34 Human
Identity tables whose authorization model *is* row-ownership by `auth.uid()`, proven behaviourally in
`58_write_grants_and_config_capability_test.sql`.

**SEC-1 has no unexplained residue left.** The detector in `10` was widened to recognise
`app.has_permission` and `app.require_lead_handler` alongside `app.authorize`, with the reason
recorded in the file: measuring authorization by one function name is what caused the error at the
top of this report.

---

## 5. Tests

Suite **58 files / 672 → 59 files / 689 assertions**, 0 failures, re-run both fresh and with all five
HTTP suites' residue present.

`59_lead_handler_authority_test.sql` (14) — the colleague **sees** the lead (positive control on the
department queue), then is refused the transition by direct DML *and* by the RPC, while the handler
is permitted on the **same lead and the same transition**; ASSIGN_LEAD proven as the rule's other
half; the closure path proven untouched; `lead_interactions` refused to the colleague and permitted
to the handler and to ASSIGN_LEAD; the system path proven still open; and the fail-closed branch
pinned.

| What failed first | Cause | Resolution |
|---|---|---|
| fixture `leads` insert | set `assigned_user_id` directly — refused by SPEC-148's coherence trigger ("no assignee without a `lead_assignments` row") | assign through `app.assign_lead`, which is how it is really done |
| the same insert again | `leads_owner_matches_assignee_chk` requires owner = assignee | let `assign_lead` set both |
| `advance_lead(...,'budget')` | I invented a closure reason | read `lead_closure_reason`: `price_rejected` |
| `permission denied for function require_lead_handler` | the invoker guard could not execute it | granted to `authenticated`, exactly as `app.authorize` and `app.has_permission` are |
| parity assertion 6 | `pg_get_functiondef` raises on aggregates | `prokind = 'f'` — without it the assertion *dies* instead of failing, which reads the same in a summary and is not the same thing |

---

## 6. Environment, parity and guards

| Axis | Value |
|---|---|
| Migrations | **151** — repository, local, Primary |
| Fingerprint | **`5c5b340536257dbf221ce3dad1dba536`** on all three |
| Logic hash (`require_lead_handler` + `enforce_status_transition` + both guards) | **`b837ef78b33a669c96b9c3e4e5925f58`** identical local and Primary |
| pgTAP | **59 files / 689 assertions / 0 failures** — fresh and with HTTP residue |
| End-to-end HTTP | **175/175**, all five suites re-run after the change |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN |

---

## 7. Classification

**PROVEN** — the handler rule now applies on both paths, with denial and permit on the same row;
closure authority unchanged; the system path unchanged; the fail-closed branch pinned; the transition
parity guard covers all ten functions in both directions.

**UNPROVEN** — nothing outstanding from the previous reports.

**FAILED** — none.

**BLOCKED** — TRANS-1 (narrowed: unifying the runtime source needs a decision on where per-entity
extras live) · DOC-EXP-1 · AUTH-1 · FIN-5 · SYSADMIN-1 · TASK-3 · SCHED-1 · RET-1, RET-2, ORPH-1,
LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1 · DEL-1 (partial) · PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — SEC-1's three remaining tables (canon 34 ownership); the three RPC-owned lead
transitions absent from `advance_lead`.

**CORRECTED** — `app.record_lead_interaction` **does** authorize; `202607056100`'s statement that it
"authorizes nothing" was wrong, and the gap register and master plan now say so.

---

## 8. Next logical work

**SCHED-1** — nothing invokes the storage executor on a schedule, and the executor, the retention
architecture and the reconciliation job now all exist. Then the remaining recorded gaps, most of
which need the owner rather than more engineering.
