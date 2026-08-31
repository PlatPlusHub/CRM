# ORVION — API-3 Lead Routing: Four Defects Behind Two Endpoints That Had Only a Name

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Scope: Bounded audit of API-3's lead-routing family — `assign_lead_round_robin`, `reassign_lead`,
`lead_origin`, `lead_booking_readiness` — plus the table they all write, `public.lead_assignments`.
One migration written, one pgTAP file added, one HTTP suite extended. **No roadmap change, no phase
change, no owner decision created, no commit, no push, no Primary write.**
Status: Complete. **Migration `202607058100` is NOT deployed to Primary — awaiting owner approval.**

**Branch:** `main` · **Start HEAD:** `09adf19` · **End HEAD:** `09adf19` (uncommitted working tree)
· **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 0. Session facts

| | |
|---|---|
| Starting commit | `09adf1951a733689949c9dec4be730eaeedcbc74` |
| Ending commit | `09adf1951a733689949c9dec4be730eaeedcbc74` — **no commit created** |
| Working tree | **DIRTY, deliberately**: 2 new files, 2 modified (listed in §10) |
| GitHub changed | **NO** |
| Push | **NO** |
| Local Supabase reset | **YES** — repeatedly, as the protocol requires |
| Primary contacted | **YES** — read-only (`execute_sql`, `get_project_url`) |
| Primary modified | **NO** |
| n8n contacted | **NO** this session |
| Package | API-3 lead-routing family (Batch 6, Foundation Completion Programme) |

---

## 1. What the audit surface actually was

Derived from the verified local database rather than from documentation: four RPCs (all
`SECURITY INVOKER`, all wrapped into `public` by `202607055500`), one table
(`public.lead_assignments`, 9 columns, 4 composite FKs, **no unique index of any kind**), its three
triggers, its single `scope_isolation` RLS policy, `leads`' ten triggers, the 17 `app.status_transitions`
rows for leads, two event codes (`lead_assigned`, `lead_reassigned`, both emitted **from RPC bodies,
never from a trigger**), and seven consumers — of which `reporting` holds **none**.

**The coverage that existed:** `assign_lead_round_robin` and `lead_booking_readiness` appeared in the
suite **only as names in `53_api_surface_test.sql`'s endpoint list** — the CUST-2 shape. All four had
**zero HTTP evidence**.

**`authenticated` holds SELECT, INSERT and UPDATE on `lead_assignments`**, so PostgREST serves the
table beside the RPCs. Its RLS requires *the parent lead to be visible*, not *the actor to be
permitted* — the BOOK-1 shape verbatim. Capability comes only from `app.guard_write_capability`,
which maps the table to `ASSIGN_LEAD` **or** `REASSIGN_LEAD`.

---

## 2. Findings

### LEAD-6 — round-robin routed by PROXIMITY where canon says ELIGIBILITY · High · FIXED

**Reproduction (PROVEN, LOCAL RUNTIME).** A branch/department holding one `branch_manager` and one
`trainee`, both placed. `app.eligible_lead_handlers` returned **one** candidate (the manager);
round-robin's own predicate returned **two**. With the manager already holding a lead, round-robin's
"never-assigned first" ordering selected the **trainee** — and the trainee, calling
`app.advance_lead(..., 'lost', ...)` on the lead they now owned, was refused
**`permission denied: CLOSE_LEAD`**. The lead was routed to someone who cannot close it.

**Root cause.** LEAD-3 (`202607056800`) already resolved what canon 04's "eligible" means, by reading
ORVION's own permission matrix rather than the word: a candidate must hold `CLOSE_LEAD`. It applied
that answer to `app.process_lead_sla` **and to nothing else**. `assign_lead_round_robin` still
selected on placement alone — *"everyone PLACED in the branch"*, the definition that migration
explicitly rejected. Canon 04 L27 uses the identical phrase for this path: *"The default routing
method is round-robin assignment among **eligible employees**."*

**Why existing controls missed it.** Its only test was a name in a list. LEAD-3's
"NOT CHANGED, deliberately" list names the round-robin **ordering** and names `app.reassign_lead`
(**LEAD-5**, the human path where a supervisor names the assignee). It does not name this pool, and
the reason it gives for sparing `reassign_lead` does not reach here: round-robin is the path where
**no human chooses**, which is the side of the line LEAD-3 governs.

**Enforcement layer, chosen by measurement.** The predicate is **not** inlined. `user_role_assignments`
carries a `scope_read` RLS policy, so a permission join evaluated inside this INVOKER function would
be row-filtered to what the caller may see and would silently exclude eligible colleagues — the
BOOK-1 lesson. The resolution must run as DEFINER, and `app.eligible_lead_handlers` already is one.
Calling it required granting EXECUTE to `authenticated`; granting it **as it stood** would have
opened a cross-tenant staff-enumeration oracle, because it is DEFINER and takes `p_tenant_id` as an
argument. The grant is therefore paired with a tenant guard inside the function. The ordering is
untouched, per LEAD-3.

**Side effect, recorded rather than filed separately:** round-robin tested `uba.ends_at is null`, so
it counted placements that have not **started** and skipped current ones carrying a future end date.
Adopting the shared pool corrects that window.

### ASGN-1 — "one lead has one current handler" lived in one function · High · FIXED

**Reproduction (PROVEN, LOCAL RUNTIME).** As a `branch_manager` over the real `authenticated` role,
holding ASSIGN_LEAD and REASSIGN_LEAD, with the lead visible, immediately after a legal
`app.assign_lead` that left exactly one current row: a direct INSERT produced **two current rows for
one lead**, left `leads.assigned_user_id` pointing at the first, and emitted **no event**.

**Root cause.** `leads.assigned_user_id` is singular and SPEC-151 constrains `owner_user_id` equal to
it, so the domain rule is exactly one current assignment. Nothing enforced it: no unique index, and
`app.require_assignment_history` — the trigger that closed the direct-UPDATE hole on `leads` — asks
whether **a** current row exists for the new assignee, never whether **only one** does.

**Enforcement layer.** A **partial unique index**, not a trigger: the invariant is a statement about a
set of rows that PostgreSQL enforces declaratively, and a declarative constraint cannot be reached
around by any door. Precedent: `document_versions_one_current_idx`. Every legal writer was checked
**first**: `app.assign_lead` inserts only when the lead is `new` and moves it to `assigned` (so it
cannot fire twice); `app.reassign_lead` and `app.process_lead_sla` both close the previous row before
inserting.

### ASGN-2 — `assigned_by` was a caller-supplied attribution column · High · FIXED

**Reproduction (PROVEN, LOCAL RUNTIME).** In the same transaction as ASGN-1, the manager's direct
INSERT recorded **`assigned_by = Employee A`**. The audit trail named a subordinate as the author of
the manager's own act.

**Root cause.** ATTR-1 (`202607056400`) made `created_by` derived on **twenty** tables for exactly
this reason. `lead_assignments` carries the same fact under a different name and was **not among the
twenty** — verified by reading that migration, which never mentions this table or column.
`app.forbid_assignment_history_rewrite` freezes `assigned_by` on UPDATE, so the column *looked*
governed; nothing constrained it on INSERT. The composite FK is satisfied by any user in the tenant —
**ADMIN-1's lesson: a foreign key proves an identity exists, never whose it is.**

**Enforcement layer.** ATTR-1's own idiom, unchanged: derive on INSERT from the session, and leave
session-less platform paths alone — `app.process_lead_sla` passes `assigned_by => null` deliberately,
because no human performed that assignment.

### ASGN-3 — the terminal-status rule was enforced in the RPC only · Medium · FIXED

**Reproduction (PROVEN, LOCAL RUNTIME).** With a lead legally advanced to `lost`, the RPC refused
(*"a lead in terminal status lost cannot be reassigned"*) and a direct INSERT by the **same actor in
the same transaction succeeded** — a closed lead acquired a new handler, unaudited. BOOK-1's shape one
domain over.

**Enforcement layer.** A BEFORE INSERT trigger carrying the RPC's list verbatim, `SECURITY DEFINER`
with a mandatory REVOKE for BOOK-1's reason: under INVOKER the guard's own read of the parent lead
would be RLS-filtered, leaving it blindest against precisely the caller it must stop. **No
session-less exemption** — this is integrity, not authorization.

---

## 3. Proven NOT defects — by measurement, not by inspection

- **"ASSIGN_LEAD suffices to perform REASSIGN_LEAD's job through the table door."** Structurally true
  (`guard_write_capability` accepts either) and **not a privilege escalation**: both permissions
  resolve to the *identical* role set — `branch_manager, ceo, department_manager, owner`. Measured
  against `role_permissions`. Recorded so the next audit does not re-raise it.
- **`app.lead_origin` truncating lineage under RLS.** The `lead_assignments` policy scopes on tenant
  plus parent-lead visibility and adds no per-user restriction, so anyone who can see the lead sees
  its whole timeline. Not a defect.
- **LEAD-5** (`reassign_lead` excluded from the eligibility rule) — **INTENTIONAL**, recorded in
  `202607056800`. Not reopened.
- **Round-robin tie-break** (open-lead count vs `u.id`) — **INTENTIONAL**, declined in the same
  migration as an optimisation rather than a defect. Not reopened.

---

## 4. Recorded and deliberately NOT fixed

- **ORIG-1 (Low, UNPROVEN as a wrong answer).** `app.lead_origin` orders by `assigned_at` with no
  tie-breaker, and its `current_user_id` uses `array_agg` with **no ORDER BY at all**. Under ASGN-1's
  duplicate rows it demonstrably returned a handler that was not the newest current one. With ASGN-1
  closed, exactly one current row exists and that half is resolved structurally. The remaining half —
  two history rows sharing an identical `assigned_at` — was constructed and the function returned the
  *correct* answer anyway, so **no wrong result was demonstrated**. Adding a tie-break is the same
  class of change LEAD-3 declined as "an optimisation, not a defect", and it is declined here for the
  same reason rather than a different one.
- **`public.lead_origin` and `public.lead_booking_readiness` wrappers are `volatile` while their `app`
  originals are `stable`.** A wrapper-generation artifact of `202607055500`. No behavioural
  consequence was demonstrated; changing the generator is out of this family's scope.
- **`app.lead_booking_readiness` does not require an assignee**, and its `reason_code` vocabulary
  (`ready` / `lead_archived` / `lead_closed_negative` / `no_customer_linked`) is **not in the
  catalog**. Canon was searched before judging: no canonical rule requires an assignee for booking
  readiness, and inventing one would be manufacturing business policy to produce a finding. The
  vocabulary is function-local to a derived read model, which is not the catalog's subject.
  **Classified INTENTIONAL, not deferred.**

---

## 5. Owner decisions

**None created.** Every question this family raised was answered from canon 04, the LEAD-3 precedent,
the live permission matrix, the schema, or experiment. The 29 pre-existing open owner decisions are
unchanged in number and content.

---

## 6. Measurement attacks, and the four that were mine

**Both new guards were attacked by defect injection (PAR-4 pattern), inside savepoints:**
- Drop `lead_assignments_one_current_idx` → the duplicate INSERT **succeeds** and produces exactly the
  two-current-handler state reproduced before the fix → rollback → **refused again**.
- Drop `lead_assignments_guard_target` → the terminal-lead INSERT **succeeds** → rollback → refused.

**Every negative assertion carries a positive control** proving the actor holds the capability, the
row is visible, and the legal path genuinely changes something.

**Four measurement failures this session were mine, and all four were caught before they became
findings** — recorded because the transcript would otherwise read as four product defects:
1. `assigned -> spam` is not a legal transition; my first H4 fixture used it and aborted. Fixture
   error, not a state-machine defect.
2. I invented `app.has_permission_for_user`, which does not exist.
3. I built a LEAD-6 fixture that left the manager unplaced, so `create_lead` failed RLS.
4. I called `app.eligible_lead_handlers` as `authenticated` **before** granting EXECUTE — the
   permission denial was correct behaviour, not a defect.

**Two guards caught real regressions in my own work, which is the strongest evidence in this report
that the protocol is not decorative:**
- **`10_grant_model_test.sql` failed** on the first draft of the migration: `app.derive_assignment_actor`
  inherited PostgreSQL's default `EXECUTE TO PUBLIC`. Exactly how it caught BOOK-1's first draft.
  Fixed with an explicit REVOKE.
- **Pass B failed** on the first draft of test 77: it used the bare slug `rival-travel`, which
  `verify_api_end_to_end.ps1` **commits**. Pass A was green and Pass B lost all 22 assertions to a
  `tenants_slug_key` collision — the **TEST-2 class**, found by the step that exists to find it.
  Every sibling test prefixes its slug per file (`ledger-rival`, `merge-rival`, `book-rival`); mine
  now does too.

**One blind spot found and NOT closed:** `app.eligible_lead_handlers` has no HTTP-reachable caller of
its own, so its new tenant guard is proven by pgTAP only. That is the correct evidence class for a
function `authenticated` may call but PostgREST does not expose (it lives in `app`, which is not an
exposed schema).

---

## 7. Changes made

| File | Change |
|---|---|
| `supabase/migrations/202607058100_one_lead_has_one_current_handler.sql` | **NEW.** LEAD-6 (round-robin uses `eligible_lead_handlers`; tenant guard + EXECUTE grant on that function), ASGN-1 (`lead_assignments_one_current_idx`), ASGN-2 (`app.derive_assignment_actor` + trigger + REVOKE), ASGN-3 (`app.guard_lead_assignment_target` + trigger + REVOKE) |
| `supabase/tests/77_lead_routing_integrity_test.sql` | **NEW.** 22 assertions, including two defect-injection mutations and a final section re-proving ASGN-1 through the real `authenticated` role |
| `scripts/verify_lifecycle_branches.ps1` | **EXTENDED.** 17 new assertions giving all four endpoints their first HTTP execution evidence, plus the ASGN-1 and ASGN-2 refusals over `POST /rest/v1/lead_assignments` |
| `reports/master/MASTER_API_CONTRACT.md` | **REGENERATED** (generated artifact; 55 → 59 with HTTP evidence) |

---

## 8. Verification performed this session

| Axis | Result | Class |
|---|---|---|
| `npx supabase db reset` | exit 0, **170** migrations | LOCAL RUNTIME |
| pgTAP **Pass A** | **77 files / 990 assertions / PASS** (was 76 / 968) | LOCAL RUNTIME, fresh reset |
| **Six HTTP suites** | **315 passed, 0 failed** (was 298) — 29 · **89** · 42 · 66 · 38 · 51 | HTTP |
| pgTAP **Pass B**, no reset, under the suites' residue | **77 files / 990 assertions / PASS** = Pass A | LOCAL RUNTIME |
| Smoke `verify_database.sql` | `ALL CHECKS PASSED (75 tables …)` | LOCAL RUNTIME |
| Local ledger | 170, `2d329a41a39b3296562caf70a38d23bd`, latest `202607058100` | LOCAL RUNTIME |
| Local function surface | `b42f555c13d7d05af9157b673d7f9faa` — **238** (was 236) | LOCAL RUNTIME |
| Local structural surface | `a279a54a25c830f8db680d6cf3b966e3` — **3,353** objects (was 3,348) | LOCAL RUNTIME |
| Primary ledger | **169**, `4f79ecfdad3b2f1f424f72e70e414d86`, latest `202607058000` | **PRIMARY**, read live |
| Primary function surface | `a994108bd5cf44f9cc570180e72312a4` — 236 | **PRIMARY**, read live |
| Primary structural surface | `3a65328f42bd8c13b3f3048fa8f0158f` — 3,348 | **PRIMARY**, read live |
| Parity guard | **exit 1 — PRIMARY DRIFT, and this is CORRECT** (see §9) | local ↔ Primary |
| API contract | regenerated: **71 endpoints, 59 with HTTP evidence** | GENERATED |
| Repository guard | see §11 | REPOSITORY |

---

## 9. Parity — the drift is intended and must not be "repaired"

Repository and local are at **170**; Primary is at **169**. All three parity axes therefore differ,
and the guard reports `PRIMARY DRIFT` at exit 1. **This is the expected state of an undeployed
migration, not a defect and not a reconciliation task.** Primary was read-only this session by
instruction. Deploying `202607058100` to Primary is an owner-approved action and is named as such in
the next step. Until it happens, repository↔local parity is **PROVEN** and repository↔Primary parity
is **intentionally open by exactly one migration**.

---

## 10. Git state at closure

```
 M reports/master/MASTER_API_CONTRACT.md      (regenerated)
 M scripts/verify_lifecycle_branches.ps1      (+17 HTTP assertions)
?? supabase/migrations/202607058100_one_lead_has_one_current_handler.sql
?? supabase/tests/77_lead_routing_integrity_test.sql
```
plus the governance updates listed in §11. **HEAD unchanged at `09adf19`. No commit. No push.**

---

## 11. SSOT synchronization performed

| File | Classification | Action |
|---|---|---|
| `_ORVION_CANONICAL/manifest.md` | **UPDATED** | Owns live state; migrations, hashes, suite counts, Last Completed and Next capability all genuinely changed. Trimmed to stay inside Check 5's budget, never widened. |
| `reports/README.md` | **UPDATED** | Latest-session pointer must name this report or the boot sequence cannot see it (Check 10). |
| `reports/master/MASTER_GAP_REGISTER.md` | **UPDATED** | Owns finding status/evidence. Four new rows: LEAD-6, ASGN-1, ASGN-2, ASGN-3, plus ORIG-1 recorded as not-fixed. |
| `reports/master/MASTER_EXECUTION_PLAN.md` | **UPDATED** | Batch 6 package narrative (AUD-03 explicitly permits narrating what a package fixed). |
| `reports/master/MASTER_API_CONTRACT.md` | **UPDATED (generated)** | Regenerated, never hand-edited. |
| `ai-map.json` | **UPDATED (generated)** | Regenerated after the manifest change (Check 7). |
| `_ORVION_CANONICAL/32_execution_roadmap.md` | **UNCHANGED** | No phase, order or gate changed. |
| `MASTER_CERTIFICATION_STATUS.md` | **UNCHANGED** | Certification state and gate unchanged. |
| `_ORVION_CANONICAL/04_lead_lifecycle.md` | **UNCHANGED** | Canon was the *authority* for LEAD-6, not its subject. No canon rule was changed or invented. |
| `reports/architecture-decision-records.md` | **UNCHANGED** | No new architectural decision; every choice followed an existing ADR or precedent. |

---

## 12. Continuous learning — could this class recur?

**LEAD-6's class is "a fix applied to one of several sibling writers".** It is the CUST-1 family
(a correct change that leaves a sibling behind) and `AGENTS.md §3 5b` question 2 already exists for
exactly it. **No new mechanism is proposed**, and that is a deliberate conclusion rather than an
omission: a guard asserting "every writer of table X uses helper Y" is not statically decidable —
`reassign_lead` legitimately does **not** use the helper (LEAD-5), so such a detector would have to
carry an exemption list, which `AGENTS.md §6` forbids manufacturing. The durable prevention is the
question already in §3 5b, and this session is evidence it works when asked.

**ASGN-2's class — an attribution column ATTR-1 did not reach — IS mechanizable**, and is recorded as
a candidate rather than built here: a check that every column whose name ends `_by` and references
`users` is either trigger-derived or provably RPC-only. It was not built this session because it
belongs to the attribution family rather than to lead routing, and because it must be
counterexample-tested in both directions before it is trusted. **Recorded as GOV-8 in the register.**

---

## 13. Next executable step

**Two actions, in this order.**

1. **Owner decision required (deployment, not design):** approve committing `202607058100` and
   deploying it to Primary `vrvtsxexkiiiivlkdxzp`. Until then repository and Primary differ by one
   migration and the parity guard will correctly report drift. Nothing else in the repository is
   blocked by this.
2. **Then continue API-3 — now 12 endpoints without HTTP evidence, down from 16.** The remaining set,
   read from the regenerated contract rather than restated from memory:
   `add_customer_contact_method` · `advance_marketing_campaign` · `assign_task` ·
   `create_marketing_campaign` · `current_placement` · `financial_documents` ·
   `find_customer_duplicates` · `link_internal_supplier` · `record_offline_conversion` ·
   `redeem_license_token` · `tenant_capabilities` · `upload_subscription_payment_proof`.
   The largest coherent group is the **marketing-campaign family** (`create_marketing_campaign`,
   `advance_marketing_campaign`, `record_offline_conversion`), which is also the group Phase 8's
   offline-conversion pipeline consumes — so auditing it serves the current phase directly.

**Phase position unchanged:** Phase 8 current; Phase 10 NOT READY; Foundation Completion gate SHUT;
**SEC-1 still awaits owner ratification.**
