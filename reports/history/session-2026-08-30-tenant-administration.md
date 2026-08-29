# ORVION — ADMIN-1: One Unvalidated Argument Bound a Membership to the Wrong Human

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Scope: API-3, the tenant-administration family — `create_tenant_user`, `assign_user_branch`,
`revoke_user_role`, `create_department` — audited by capability. Migration `202607058000` (ADMIN-1).
Test `76_tenant_administration_test.sql` (23). 16 HTTP assertions added to
`verify_role_journeys.ps1`. Fixture defect repaired in `65_eligible_lead_handler_test.sql`;
assertion 11 of test 75 sharpened. ADMIN-2 and ADMIN-3 recorded. Deployed to Primary, verified.
Status: Complete.

**Branch:** `main` · **Start HEAD:** `aee8a9f` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Findings discovered

| ID | What | Severity | End state |
|---|---|---|---|
| **ADMIN-1** | `create_tenant_user` binds a membership to any caller-supplied `auth_user_id`, unvalidated | **High** | **FIXED**, behaviourally verified |
| **ADMIN-2** | The last-owner protection is real but *accidental*, and its error message is wrong | Low | **PROVEN NOT A DEFECT** (protection pinned by test); message recorded |
| **ADMIN-3** | 42 catalog event codes have no producer, incl. `user_branch_transfer_started` | Low | **PROVEN INTENTIONAL** (Fundamental Domain Structure) |
| **TEST-65** | 10 fixture rows in `65_eligible_lead_handler_test.sql` modelled impossible humans | — | **FIXED** |
| **MEAS-1** | My own "codes with no producer" detector was wrong by 7 | — | **FIXED** before it was reported |

---

## 2. ADMIN-1 — the defect, reproduced

`app.create_tenant_user` accepts `p_auth_user_id` and inserts it **without validating it against
anything**. The only structural check is `users_auth_user_id_fkey`, which proves the identity
*exists* and nothing about *whose* it is.

**Canon 34 settles what the rule should be** — derived, not invented:

> "A human being has exactly one identity across the entire platform… it owns everything that proves
> *who the person is*: credentials, **verified email/phone**…"
> "A membership… owns everything that describes *what the person may do* inside that tenant."

So the verified email belongs to the identity; a linked membership carrying a different email is
claiming to be a different human.

Reproduced on a clean local reset. Agency A's owner (MANAGE_USERS, aal2) calls
`create_tenant_user('Alice Smith', 'alice@a.test', null, <BOB's uid>)`, Bob being a member of
unrelated Agency B:

```
membership row   -> 'Alice Smith' / alice@a.test
bound identity   -> bob@b.test                       EMAIL DIVERGED
real Alice, confirmed, calls activate_membership()
                 -> 0 memberships.  PERMANENTLY LOCKED OUT of her own membership
Bob calls my_memberships()
                 -> "Agency A" AND "Agency B"
```

**Three harms from one pasted UUID:** every action Bob takes in Agency A is attributed to Alice; the
rightful person can never claim her membership (the claim path only takes rows with `auth_user_id`
null); and Bob gains a tenant he never joined. No malice required, and nothing reports it afterwards.

### Enforcement layer, chosen by measurement — and it differs from IDENT-1's

| | IDENT-1 (previous package) | ADMIN-1 (this one) |
|---|---|---|
| Fixture blast radius | **49** test files create `auth.users` with no `email_confirmed_at` | **120** linked rows, **zero** divergent emails |
| Alternate write paths | closed — direct UPDATE hit 0 rows, INSERT refused 42501 | **open** — `users.scope_update` lets any MANAGE_USERS holder rebind |
| Conclusion | **function** | **trigger** |

Copying the previous package's answer would have been wrong in both directions. `users.scope_update`
means a check inside the RPC alone closes one door and leaves the other; and because the invariant
already holds everywhere, a trigger costs nothing to adopt.

`SECURITY DEFINER` is mandatory here: `authenticated` holds no SELECT on `auth.users`, so under
INVOKER the lookup would find nothing, fall through `if not found`, and **allow every divergence** —
weakest against exactly the caller it exists to stop. Hence the `REVOKE ... FROM PUBLIC`.

**No session-less exemption** (SEC-1 Refinement 2): integrity, not authorization.

---

## 3. What was proven NOT to be a defect

**ADMIN-2 — tenant lockout is unreachable, but by accident.** The sole owner cannot revoke their own
last owner grant. The mechanism was established by a discriminating experiment rather than assumed:
with **two** owner grants the first revoke *succeeds* and the last is *refused*. `emit_role_change`
is an `AFTER I/U/D` trigger that re-checks `app.authorize('MANAGE_USERS')` — by which point the
granting row is already inactive, so the caller no longer holds it.

The protection is real and correct in effect. It is also **fragile and undocumented**: moving that
trigger to BEFORE, or dropping its `authorize` call, would make a tenant permanently unadministrable
with nothing noticing. Test 76 assertions 15–17 pin it. The error message —
`permission denied: MANAGE_USERS` shown to someone who demonstrably holds it — is recorded as the
residual, unfixed, because the alternative is duplicating the rule in a second place.

**ADMIN-3 — 42 event codes have no producer.** Including `user_branch_transfer_started`, which
canon 27 defines. They are `login_*`, `otp_*`, `totp_*`, `notification_*`, `password_*` — vocabulary
for flows not yet built, exactly like IDENT-3's identity tables. Canon defines the event vocabulary
ahead of the flows that emit it, which is `AGENTS.md §3` Fundamental Domain Structure, not dead code.
A guard here would cry wolf 42 times.

**Also verified working, and left alone:** `one_primary_idx` (a genuine set-level invariant, already
correctly expressed as a *partial unique index* rather than a trigger), the department-name uniqueness
index, `emit_user_branch_transfer`, and `emit_role_change`'s `role_removed`.

---

## 4. Measurement defects found

**MEAS-1 — my own detector was wrong, and I caught it before reporting it.** My first pass at "event
codes with no producer" searched only `pg_proc.prosrc` and returned **49**. But generic emitters
(`emit_creation_event`) carry the code in the **trigger arguments**, not the function body — so
`trusted_device_created` appeared "unproduced" while I had *proved it firing* an hour earlier. The
corrected detector unions `pg_trigger.tgargs` and returns 42. Seven fabricated findings avoided.

**TEST-65 — a fixture modelling an impossible state.** `65_eligible_lead_handler_test.sql` generated
identity emails as `auth-NN@lead3.test` while its memberships claimed `uNN@lead3.test` — ten rows,
each a membership bound to a different human than it names. My static pre-check said "zero
divergence" and **missed it**, because the insert shape differed from the pattern I matched. The full
suite run is what caught it. Fixed by aligning the fixture to the identity, which canon 34 makes the
owner of the email.

**A false red I introduced.** Test 75 assertion 11 expected `42501` (RLS) and began getting `23514`,
because ADMIN-1's BEFORE trigger now answers before RLS's WITH CHECK. The assertion's *claim* was
that RLS blocks self-provisioning; its fixture used a mismatched email, so it was proving the wrong
thing. Fixed by making the row otherwise valid, which **isolates RLS** and makes the assertion prove
what it says.

---

## 5. Consumer / sibling sweep (Q1 and Q2)

**Q1 — which paths meet the new rule?** `create_tenant_user` (p_auth_user_id), any direct
INSERT/UPDATE of `users.auth_user_id` or `users.email` by a MANAGE_USERS holder, and
`app.activate_membership` — which satisfies it by construction, because it matches on the very email
it is about to bind. Verified against `pg_proc`: those are the only writers.

**Q2 — which paths consume the shape?** `activate_membership` reads `users.email` to find claimable
rows. After this trigger a linked row's email is *guaranteed* to equal its identity's, so that match
becomes strictly more reliable. No consumer derived behaviour from the previous unconstrained shape,
because there was no shape to rely on. Live check on Primary: **0 diverged rows**, so the trigger
cannot fail on existing data.

---

## 6. Verification performed

| Axis | Result | Evidence class |
|---|---|---|
| Migrations | **169** — repository, local, Primary (`202607058000`) | all three read |
| Ledger fingerprint | `4f79ecfdad3b2f1f424f72e70e414d86` | read independently from both |
| Function surface (236) | `a994108bd5cf44f9cc570180e72312a4` | read independently from both |
| Structural surface (3,348) | `3a65328f42bd8c13b3f3048fa8f0158f` | read independently from both, ten surfaces |
| pgTAP **Pass A** | **76 files / 968 assertions / 0 failures** | local, fresh reset |
| pgTAP **Pass B** | **76 files / 968 assertions / 0 failures** | local, post-HTTP residue |
| End-to-end HTTP | **298/298** across six suites (was 282) | local over the wire |
| Smoke | `ALL CHECKS PASSED (75 tables …)` | local |
| Repository guard | **CLEAN**, 12 checks | files only |
| Parity guard | **CLEAN exit 0**, all three Primary values read live | local ↔ Primary |
| API contract | **55 of 71 with HTTP evidence — API-3 20 → 16** | repository |

The parity guard caught the contract as **STALE** after the HTTP additions and was satisfied only by
**regenerating** it, never by hand-editing. `apply_migration` stamped its own version; the ledger row
was normalised (GUARD-1) and the fingerprint read afterwards.

---

## 7. Classification

**FIXED and behaviourally verified** — ADMIN-1, TEST-65, MEAS-1, test-75 assertion 11.
**PROVEN NOT A DEFECT** — ADMIN-2 (lockout unreachable; now pinned), ADMIN-3 (Fundamental Domain
Structure), `one_primary_idx`, department-name uniqueness, transfer and role-change events.
**UNPROVEN** — none introduced.
**OWNER DECISION REQUIRED** — **none from this family.** Every question was derivable: canon 34
settled the identity binding, the schema settled the set-level invariants, and a discriminating
experiment settled the lockout question. Nothing was escalated that evidence could answer.

**No business policy invented; no canon changed.**

---

## 8. Next executable step

**API-3, the lead-routing family** — `assign_lead_round_robin`, `reassign_lead`, `lead_origin`,
`lead_booking_readiness`. Chosen on evidence: it is the largest remaining coherent group of the 16,
it carries attribution consequences (ATTR-3 and LEAD-3 both landed there), and `reassign_lead` writes
the assignment history that acquisition lineage depends on.

**Evidence the next session must verify first:** re-read all three Primary hashes live (never pass
the repository's own values back to the guard), and `npx supabase db reset` before reading any
structure from local.

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut. **SEC-1 still awaits owner ratification**; nothing is blocked
on it.
