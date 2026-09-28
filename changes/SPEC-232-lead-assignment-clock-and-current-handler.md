# Change Request — SPEC-232

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make a lead assignment's SLA clock (`assigned_at`) server-derived on a signed-in INSERT at the `public.lead_assignments` table door, require at COMMIT that a lead's current assignment names the lead's assignee, and record `lead_assignments` as audited.

## Business Reason

Batch 6 Slice 30 selected `lead_assignments` live at Exposure 9, coverage 66; `customer_identity_merges` was runner-up at 8/24.

- **The intended rule.** Canon 04 makes SLA escalation mandatory: at 15 minutes without response, notify the assigned employee and the employee's manager; at 30, reassign to another eligible employee. Canon 10 lists manager escalation among the notices a user cannot mute. `app.process_lead_sla` runs every minute and supervises each `assigned` lead through ONE row, the lead's current `lead_assignments` row, whose `assigned_at` is the clock (`v_elapsed := now() - assigned_at`). Canon 04 also requires the timeline to show "the time it was assigned". The same column orders round-robin and SLA reassignment (`max(assigned_at)`, least recent first) and decides `app.lead_origin`'s first handler. `authenticated` holds INSERT and UPDATE; `app.guard_write_capability` charges ASSIGN_LEAD or REASSIGN_LEAD (owner, ceo, branch_manager, department_manager), and `app.forbid_assignment_history_rewrite` freezes `assigned_at` among other columns on UPDATE and allows only `unassigned_at` and `is_current` to change. No RPC writes `assigned_at`; all three writers take the column default.
- **ASGN-4 (Medium, reproduced, latent).** Measured on the local stack at `76e0b6f`, in rolled-back transactions, as a `department_manager` at `aal2` in the lead's branch and department:
  - The manager closed the handler's current row (`is_current = false`) and wrote nothing after it. The lead still read `assigned` to the handler, the timeline said the handler had been unassigned, `app.lead_origin` returned no current handler, and the next SLA pass returned nothing for the lead: no warning, no notice, no reassignment, on every pass. No event was written.
  - The same close landed at `aal1`; both doors charge the same keys, and `app.authorize` asks for step-up only where `app.requires_mfa()` does.
  - `app.require_assignment_history` guards the other direction only: it fires when the LEAD's assignee moves, and here nothing on the lead moved.
- **ASGN-5 (Medium, reproduced, latent).** In the same transactions:
  - The manager closed the handler's current row and re-inserted the same handler as current with `assigned_at` a century ahead. The lead stayed coherent and the SLA never warned it.
  - As the handler of their own lead, the department manager did the same, and the branch manager, who `app.lead_responsible_managers` names for that lead, received nothing.
  - A backdated closed row naming a colleague made that colleague the lead's first handler in `app.lead_origin`. A forged future closed row for a colleague moved round-robin's pick from the colleague to the branch manager.
- **Controls that held.** The handler (an `employee`) is refused every write by `app.guard_write_capability` (`permission denied: one of ASSIGN_LEAD or REASSIGN_LEAD is required to write lead_assignments`); another tenant's owner is refused by `scope_isolation`; an UPDATE of `assigned_at` is refused by `app.forbid_assignment_history_rewrite`; DELETE is refused by the same trigger and has no grant. On the untouched fixture every assigned lead was warned, so the silent leads above were caused by the writes, not by the fixture.
- **Exposure.** Primary `vrvtsxexkiiiivlkdxzp` holds 233 migrations (latest `20260927140000`), 0 tenants, 0 leads, 0 lead assignments, 0 incoherent leads and 0 future-dated clocks, and the target function and trigger are absent (read-only, 2026-09-28). Both findings are latent until the first tenant works leads; the SLA job is already scheduled every minute.
- **Why these are not existing findings.** ASGN-1 made two current rows impossible and ASGN-2 derived `assigned_by`; neither touched the clock or a current row closed with no successor. ASGN-3 is the terminal-status guard. HIST-1 froze the history on UPDATE. LEAD-4 closed the handler's no-evidence escape on the `leads` status edge; this is the same outcome through a related row, by a different actor. LEAD-5 is overlapping SLA passes, and ORIG-1 is a tie-break. LI-3 and CAMP-4 are about events a table door does not emit, which this contract does not change.
- **The repair** is one line in ASGN-2's trigger (`new.assigned_at := now()` on a signed-in INSERT) and one deferred constraint trigger on `lead_assignments`, FIN-8's idiom, checking at COMMIT that the lead's current row names `leads.assigned_user_id`. The permission charged, the freeze, the RPCs and the session-less exemption from the clock are unchanged.

## Risks

- **A commit-time check could refuse a legitimate handover.** Mitigated: every writer of `leads.assigned_user_id` (`app.assign_lead`, `app.reassign_lead`, `app.process_lead_sla`) leaves the current row naming the assignee at commit, and the three lead RPCs that read it do not write it. The prototype passed the full suite, all six HTTP suites and Test 136's handover controls, including the SLA's own reassignment with no session-less exemption and `verify_lifecycle_branches.ps1`'s committed POSTs to the table.
- **Deriving the clock could break a fixture or import.** Mitigated: the only fixture that supplies `assigned_at` (`36_…`) writes session-less, which keeps its value; no signed-in producer accepts a timestamp.
- **Primary deployment replaces one function body and adds one function and one constraint trigger in production.** It requires separate exact-byte owner authorization (Gate 2) after the local proof; this contract's approval does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-232-lead-assignment-clock-and-current-handler.md`
- `supabase/migrations/20260928120000_the_sla_clock_and_the_current_handler_are_not_the_callers.sql`
- `supabase/tests/136_lead_assignment_clock_and_current_handler_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607051800_assignment_history_integrity.sql`
- `supabase/migrations/202607058100_one_lead_has_one_current_handler.sql`
- `supabase/migrations/202607060800_one_sla_pass_at_a_time.sql`
- `supabase/migrations/202607061000_the_sla_records_its_delivery_obligation_like_every_other_alert.sql`
- `supabase/migrations/202607061900_the_lead_door_that_answered_its_own_authority_question.sql`
- `supabase/tests/24_assignment_history_test.sql`
- `supabase/tests/63_sla_escalation_test.sql`
- `supabase/tests/77_lead_routing_integrity_test.sql`
- `supabase/tests/83_actor_attribution_test.sql`
- `supabase/tests/109_lead_authority_and_lifecycle_test.sql`
- `_ORVION_CANONICAL/04_lead_lifecycle.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `scripts/verify_database.sql`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/04_lead_lifecycle.md` (SLA Escalation Rule, Lead Assignment History)
- `supabase/migrations/202607058100_one_lead_has_one_current_handler.sql` (ASGN-1, ASGN-2, ASGN-3) and `202607057300_a_ledger_entry_that_does_not_balance_is_not_a_ledger_entry.sql` (FIN-8's deferred constraint trigger)
- Current local `public.lead_assignments` grants, `scope_isolation`, its five triggers and four indexes; `app.derive_assignment_actor`, `app.forbid_assignment_history_rewrite`, `app.guard_lead_assignment_target`, `app.guard_write_capability`, `app.require_assignment_history`, `app.assign_lead`, `app.assign_lead_round_robin`, `app.reassign_lead`, `app.process_lead_sla`, `app.lead_origin`, `app.lead_responsible_managers`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`leads`, `lead_assignments`, Coverage); `reports/master/MASTER_GAP_REGISTER.md` (HIST-1, ASGN-1, ASGN-2, ASGN-3, ORIG-1, LEAD-4, LEAD-5, LI-3)

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A signed-in INSERT's `assigned_at` is derived as `now()` | the PostgREST table door; `app.assign_lead`, `app.assign_lead_round_robin`, `app.reassign_lead`; `app.process_lead_sla` (session-less); `app.lead_origin`; round-robin and SLA reassignment ordering | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `76e0b6f`: migration SHA-256 `235eb4847c18a54aeaff4cbc7c23d76493b210962ee4c8a5cb77116e0f02fab3`, test SHA-256 `8fbd0532f64f170e3316914a3c0d8df118430cfd33fa281d21a2e7a7a334ddda`. A backdated closed row and a century-ahead current row are both born at `now()`, and `app.lead_origin` keeps the real first handler. The RPCs already took the default; the session-less platform write keeps the clock it sets. |
| At COMMIT, a lead's current assignment must name `leads.assigned_user_id` (`lead_assignments_current_names_the_assignee`, deferred) | `app.assign_lead`, `app.reassign_lead`, `app.process_lead_sla`; the table door; `app.require_assignment_history` on `leads` | VERIFY | Refused with `23514` `a lead's current assignment must name the lead's assignee: hand a lead over with app.reassign_lead`: a closed current row with nothing after it, and a current row naming someone other than the assignee. Commit cleanly: `app.reassign_lead`, the SLA's own reassignment of five leads, and a closed history row. `app.require_assignment_history` is unchanged. |
| Existing test fixtures | every pgTAP file that inserts `lead_assignments` (`21_…`, `24_…`, `31_…`, `36_…`, `65_…`, `66_…`, `77_…`, `87_…`) and the two that `set constraints all immediate` (`70_…`, `72_…`) | VERIFY | pgTAP files roll back, so a deferred check fires only where a file asks. `70_…` and `72_…` write no assignment, and the full suite passed unchanged in the prototype. |
| The HTTP table door | `verify_lifecycle_branches.ps1` (a refused second current row, an accepted closed history row, `lead_origin`, `reassign_lead`) and `verify_role_journeys.ps1` | VERIFY | Each request commits, so the deferred check runs on every one. Both passed in the prototype (122/0 and 120/0). |
| Rows that already exist | Primary and local `public.lead_assignments` | VERIFY | The trigger and the check judge only new writes and no row is rewritten. Primary held 0 leads, 0 assignments and 0 incoherent leads on 2026-09-28 (read-only); the local stack held 0 incoherent leads. |
| Suite, smoke and every HTTP door | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, in `-Finish`'s order: pgTAP Pass A 136 files / 2447 assertions PASS (2428 existing assertions unchanged, plus 19 new). HTTP suites: 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed. Pass B without reset: 136 / 2447 PASS. Smoke: `ALL CHECKS PASSED`, exit 0. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No RPC, view or table changes. `check_database_parity.ps1` on the prototype stack reports the contract matching the live surface (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 7, and any difference is recorded. |
| Measured state that moves | manifest (`Live state`, suite figure, Batch 6 coverage, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19, 22, 24 | WRITE | 233 → 234 migrations, latest `20260928120000`; 135 → 136 files / 2428 → 2447 assertions; coverage 30 → 31 of 77. Primary values are written only from fresh post-deploy readings. The manifest is 6611 of its 7000-character budget, and Step 7 keeps each moved line within its current length or trims `Last Completed`. |
| Findings and disposition | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 2, 11, 16, 21, 22, 25 | WRITE | Two new rows: ASGN-4 and ASGN-5, each with Owner Decision `—`, so Check 25 adds nothing to the open-decision line. HIST-1, ASGN-1, ASGN-2, ASGN-3, ORIG-1, LEAD-4, LEAD-5, LI-3 and every other row are unchanged. Only the `lead_assignments` disposition row changes, to `AUDITED` / `ADVERSARIAL` with findings ASGN-4 and ASGN-5. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, the declared HTTP suite, smoke and in-file mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| ASGN-4, ASGN-5 and the `lead_assignments` disposition accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| Manifest Batch 6 coverage equals the disposition record | BEFORE_COMPLETION | Step 3 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: ASGN-2's `app.derive_assignment_actor()` on trigger `lead_assignments_derive_actor` (BEFORE INSERT, SECURITY INVOKER, empty `search_path`, EXECUTE revoked from PUBLIC) already derives server-owned columns on a signed-in INSERT and leaves session-less paths alone; `assigned_at` joins it, exactly as SPEC-231 added a version's clock to the trigger that derived its author. `app.forbid_assignment_history_rewrite` already freezes the clock on UPDATE. The current-row rule reuses FIN-8's and FIN-10's deferred constraint trigger idiom (`202607057300`, `202607057500`): SECURITY DEFINER, empty `search_path`, EXECUTE revoked, `deferrable initially deferred`, no session-less exemption for a data-integrity rule. It is a new trigger because no existing one can see the end of a transaction: every legitimate handover closes, inserts and then moves the lead in three statements, and the attack is a statement with nothing after it. The alternatives were rejected:
- making `app.process_lead_sla` read the lead's assignee instead of `is_current`: rewrites a 200-line scheduled function, leaves `app.lead_origin` and the timeline wrong, and still lets the incoherent state stand;
- converting `app.require_assignment_history` into a deferred trigger on both tables: changes an immediate guard that `24_…`, `59_…` and `109_…` pin;
- freezing `is_current`: `app.reassign_lead` closes the previous row by UPDATE under the caller's privileges;
- revoking the table door and making the RPCs SECURITY DEFINER: reverses `202607056100`'s grants-match-the-writers model for one table.

Added Property: On any signed-in path, a new assignment's `assigned_at` is the server's clock and no UPDATE can change it; and on every path, at commit, a lead's current assignment names the lead's assignee. Closed history rows stay legal, the session-less platform path keeps its clock exemption, and `unassigned_at` and `is_current` stay mutable for the handover.

Causal Negative: On the local stack at `76e0b6f`, in rolled-back transactions, a `department_manager` closed the handler's current row with nothing after it, and the SLA returned nothing for the lead on every pass; the same manager re-inserted the handler a century ahead, and the SLA never warned it. Done to the manager's own lead, the branch manager received no notice. A backdated closed row made a colleague the first handler in `app.lead_origin`.

Positive Test Design: As the branch manager, `app.reassign_lead` then `set constraints all immediate` commits. As the department manager, a closed history row commits. Session-less, a closed row keeps the clock it sets, and the SLA's own reassignment of every due lead commits under the check.

Negative Test Design: As the department manager, closing the handler's current row with nothing after it, and replacing it with a current row naming someone else, are each refused at `set constraints all immediate` with `23514` `a lead's current assignment must name the lead's assignee: hand a lead over with app.reassign_lead`. A backdated closed row and a century-ahead current row are born at `now()`, and `app.lead_origin` keeps the real first handler. The SLA warns every assigned lead of the tenant, and the branch manager is told about the department manager's own lead. The handler is refused every write with `42501` `permission denied: one of ASSIGN_LEAD or REASSIGN_LEAD is required to write lead_assignments`; an UPDATE of `assigned_at` is refused with `42501` `lead assignment history is immutable; only unassigned_at and is_current may change`; the manager's UPDATE of another tenant's history changes nothing.

Non-Empty Population Obligation: The department manager holds ASSIGN_LEAD and REASSIGN_LEAD; the handler holds neither. Five leads are assigned through `app.assign_lead` by the branch manager, four to the handler and one to the department manager, so each has a real current row. All four staff are placed in the lead's branch and department, so the branch manager is a responsible manager for the department manager's lead.

Mutation Obligation: Record `app.derive_assignment_actor`'s and `app.enforce_lead_current_assignment`'s `pg_get_functiondef` md5, flush pending checks, then open a savepoint, install the pre-repair `app.derive_assignment_actor` and drop `lead_assignments_current_names_the_assignee`. Prove the md5 differs. As the department manager, close one lead's current row with nothing after it and re-insert another's a century ahead; prove the SLA then acts on neither. Roll back to the savepoint, then prove both md5s are identical, the constraint trigger is present and deferred, and no mutant close survived. A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B, smoke, the in-file mutation, generated artifacts, fresh Primary evidence, parity evidence, the Primary ledger check, repository consistency and `git diff --check`, all on the final bytes and through canonical `-Finish`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260928120000_the_sla_clock_and_the_current_handler_are_not_the_callers.sql` is absent. If absent, create it LF with SHA-256 `235eb4847c18a54aeaff4cbc7c23d76493b210962ee4c8a5cb77116e0f02fab3`. It holds:
   - one `create or replace function app.derive_assignment_actor()`, whose body is ASGN-2's (`202607058100`) plus `new.assigned_at := now();` (with a one-line ASGN-5 comment) after `assigned_by` is derived, with the security mode INVOKER and the `search_path` empty, and its `comment on function` updated to name ASGN-5;
   - one new SECURITY DEFINER function `app.enforce_lead_current_assignment()` with an empty `search_path`, which raises `23514` `a lead's current assignment must name the lead's assignee: hand a lead over with app.reassign_lead` when the lead's current row's `assigned_user_id` is distinct from `leads.assigned_user_id`, followed by `revoke all ... from public`;
   - `create constraint trigger lead_assignments_current_names_the_assignee after insert or update on public.lead_assignments deferrable initially deferred for each row`.

   It changes no other trigger, policy, grant, RPC or function. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/136_lead_assignment_clock_and_current_handler_test.sql` is absent. If absent, create it LF with SHA-256 `8fbd0532f64f170e3316914a3c0d8df118430cfd33fa281d21a2e7a7a334ddda`. It is one transaction-rolled-back pgTAP file with `select plan(19);`. Its first line is `-- ATTACK-CLASSES: PRIVILEGE DOOR TENANT BUSINESS STATE INPUT AUTH=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A`, and its header cites SPEC-232 and states each `N/A` reason. It implements:
   - the Non-Empty Population Obligation and the handler's refusal (1-2);
   - ASGN-4's Negative Test Design and the handover control (3-5);
   - ASGN-5's Negative and Positive Test Design (6-11);
   - the tenant refusal (12) and the business consequence (13-14);
   - the Mutation Obligation (15-17);
   - the SLA's own handover under the check (18-19).

   If the target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| ASGN-4 |`. If absent:
   - Add a dated Slice 30 freshness entry and demote the previous entry to `Previously:`.
   - Append two rows after `| DOC-8 |`: **ASGN-4** (Category `SLA supervision · data integrity`, Sev `Medium`) and **ASGN-5** (Category `SLA supervision · audit integrity`, Sev `Medium`), each Req/Opt `R`, Batch `6`, Mig `A`, Cert `📋`, Owner Decision `—`, Source `SPEC-232-lead-assignment-clock-and-current-handler`, dates `09-28`. Each Status reads `FIXED locally by SPEC-232 (`20260928120000`), pending Primary deployment` and states:
     - the reproduction and consequence above;
     - latent exposure (0 leads and 0 assignments on Primary);
     - why it is not HIST-1, ASGN-1, ASGN-2, ASGN-3, ORIG-1, LEAD-4, LEAD-5 or LI-3;
     - that the repair reuses ASGN-2's trigger (ASGN-5) or FIN-8's deferred constraint trigger idiom (ASGN-4);
     - that it is pinned by `136_...`.
   - Change no other row.

   Then check whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `lead_assignments` row reads `NOT-RECORDED`. If so:
   - Set it to `AUDITED` / `ADVERSARIAL` / `SPEC-232-lead-assignment-clock-and-current-handler` / `ASGN-4, ASGN-5`. Its Next cell names `136_lead_assignment_clock_and_current_handler_test.sql` and what it proves, and states the swept non-defects:
     - `assignment_reason` and `unassigned_at` stay writable by an assignment-key holder; nothing server-side reads either, and each handover's event carries its own reason;
     - a closed history row is legal at the table (`verify_lifecycle_branches.ps1` asserts it over HTTP), and after this repair it is born at the server's clock and attributed to its author;
     - closing and re-inserting the same handler restarts the SLA clock, visibly and attributed each time, so it is not a permanent escape; no repair is warranted;
     - nulling a lead's assignee on `leads` leaves the lead under SLA supervision through its current row, and walking a lead back to `new` is refused by the canon-26 state machine;
     - a direct-door write emits no assignment event, CAMP-4's shape;
     - both doors charge ASSIGN_LEAD or REASSIGN_LEAD at `aal1`, so step-up is not this surface's control;
     - the handler was refused every write, tenant isolation held, and DELETE is refused and has no grant.
   - Update Coverage to `31 of 77 recorded · 12 AUDITED · 16 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 46 NOT-RECORDED` and `All 31 recorded surfaces`.
   - Add a dated freshness entry and demote the previous one to `Previously:`.
   - Change no other row.

   If either target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused test;
   - pgTAP Pass A, the declared HTTP suite, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the in-file mutation evidence;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat only undeployed Primary, manifest and parity drift as expected at this boundary. Read a fresh Primary baseline, read-only:
   - the full ordered ledger;
   - the function and structural surfaces;
   - the tenant, lead, assignment and incoherent-lead counts;
   - the absence of the target migration, function and trigger;
   - `app.derive_assignment_actor`'s current definition md5.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration and Test-136 SHA-256 values is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD;
   - the exact 64-character hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260928120000_the_sla_clock_and_the_current_handler_are_not_the_callers`. If it is absent and deployment is separately authorized:
   - Immediately re-read: HEAD; both hashes; the project URL; the full ordered ledger; target migration, function and trigger absence; the lead, assignment and incoherent-lead counts; and `app.derive_assignment_actor`'s pre-repair md5.
   - On an exact match, apply only the authorized migration through the Primary connector. If the connector assigns a temporary version, normalize only its newly inserted ledger row.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, both functions' definition md5, security mode, `search_path` and EXECUTE ACL, and the constraint trigger's timing, deferrability and enabled state.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`:
     - Set the `Live state` migration count, latest version, ledger and surface hashes and counts from the same readings.
     - Set the suite figure to `Suite **136 files / 2447 assertions**`, after confirming `supabase/tests` holds 136 files whose literal `plan(N)` values sum to 2447. If either differs, stop.
     - Change the Batch 6 line's `**30 of 77 surfaces have a recorded audit disposition**, all thirty at` to `**31 of 77 surfaces have a recorded audit disposition**, all thirty-one at`, only after Step 3 set Coverage to `31 of 77 recorded`.
     - Set `Last Completed` to Slice 30 / ASGN-4 / ASGN-5 / SPEC-232, trimming it so the manifest stays within 7000 characters.
   - Mark ASGN-4 and ASGN-5 `FIXED` and `DEPLOYED` in the register and change their Cert to `✅`.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators, never by hand.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete, set `Next capability` to Batch 6 Slice 31 ranked by `scripts/batch6_select_target.ps1`, clear `Active Change Request` and regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI. Promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs and remove permitted scratch files.

   Do not start Slice 31.

## Acceptance Criteria

- [ ] At COMMIT, a lead's current assignment names the lead's assignee: closing the handler's current row with nothing after it, and a current row naming someone else, are each pinned to `23514` `a lead's current assignment must name the lead's assignee: hand a lead over with app.reassign_lead`, and `lead_assignments_current_names_the_assignee` is a deferrable, initially deferred constraint trigger.
- [ ] On every signed-in path, an assignment's `assigned_at` is the server's clock: a backdated closed row and a century-ahead current row are born at `now()`, `app.lead_origin` keeps the real first handler, and the clock stays frozen on UPDATE.
- [ ] The SLA warns every assigned lead of the tenant after both attacks, and the branch manager is notified for the department manager's own lead.
- [ ] With the pre-repair trigger installed and the check dropped in a savepoint, the SLA acts on neither the closed lead nor the century-ahead lead; both restored functions are byte-identical, the check is back and deferred, and no mutant close survives.
- [ ] `app.assign_lead`, `app.reassign_lead`, round-robin, the SLA's own reassignment, closed history rows, the session-less write of the clock, every RPC and every policy keep their behaviour; `verify_lifecycle_branches.ps1` passes.
- [ ] ASGN-4 (Medium) and ASGN-5 (Medium) are registered `FIXED` / `DEPLOYED`. `lead_assignments` is `AUDITED` / `ADVERSARIAL` with findings ASGN-4 and ASGN-5. Coverage reads 31 of 77 in both the disposition record and the manifest. Every other row is unchanged.
- [ ] The migration and Test 136 match their authorized SHA-256 values. Primary, the recorded evidence, the manifest (234 migrations; 136 files / 2447 assertions), the API contract and `ai-map.json` agree.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and no business-data write, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-28 — Owner approval

Owner approved the exact Draft SHA `e2f547cd8157c4ccf8f19e99bc2f3c114ba8c264` and the frozen nine-path Write Scope, with ASGN-4 and ASGN-5 as FIX NOW under the approved design. A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE, REPOSITORY, one permanent-control path in scope, so the predicates were read). Two mutated copies returned FAIL (a gate at Step 4 inside the red window 1..7) and INDETERMINATE (Mutation Obligation removed). Pre-approval revalidation:
- HEAD was the Draft SHA and the tree was clean;
- `origin/main` and `origin/orvion-preflight` were at `76e0b6f`;
- the prototype migration and Test 136 hash to the frozen values.

The approval is bound to migration SHA-256 `235eb4847c18a54aeaff4cbc7c23d76493b210962ee4c8a5cb77116e0f02fab3` and Test-136 SHA-256 `8fbd0532f64f170e3316914a3c0d8df118430cfd33fa281d21a2e7a7a334ddda` (`plan(19)`). ASGN-4 and ASGN-5 are the only new findings this contract owns; CAMP-4 and every other existing finding are not absorbed.

The owner asked for two review hypotheses to be proved or falsified before implementation. Both were tested on the local stack reset with the frozen migration applied (234 migrations), with a committed fixture and real `COMMIT`s, and both hold:
1. The deferred check judges the final transaction state and admits every legitimate writer and order, with no platform exemption. At real `COMMIT`: five `app.assign_lead` calls, `app.assign_lead_round_robin` and `app.reassign_lead` committed. The session-less `app.process_lead_sla` warned and then reassigned six leads, leaving 0 incoherent leads. A door handover that was incoherent between its statements (close, insert, then move the lead) committed, because its final state is coherent. One that was coherent mid-transaction but closed the current row last was refused `23514` at `COMMIT`, and a close with nothing after it was refused at `COMMIT` with the lead's current row intact. Moving a lead's assignee to someone with no current row is refused immediately by the unchanged `app.require_assignment_history`, so the two directions have one owner each.
2. The clock is stamped only on signed-in inserts. A signed-in manager's insert claiming 2000-01-01 was stored at `now()`. With no claims, and with `{"role":"service_role"}` claims (for which `auth.uid()` is null), the same insert kept 2000-01-01. `service_role` holds no INSERT on `lead_assignments` (its table door is refused `42501`), so the only session-less writers are postgres-level: `app.process_lead_sla` (DEFINER, EXECUTE to postgres and service_role only), migrations and fixtures. The only other inserting functions, `app.assign_lead` and `app.reassign_lead`, are INVOKER and never supply a clock.

Approval authorizes Approve, In Progress, Steps 1-4 and local proof. It does not authorize a Primary write, which needs separate exact-byte authorization at Gate 2.

### 2026-09-28 — Execution started

The approved nine-path contract entered In Progress at `310fb1c`. Resume Step 1. Local implementation and proof through the Step 4 pre-deploy readiness gate are authorized; Primary deployment remains separately gated at Step 5.

### 2026-09-28 — Steps 1-3 executed

- Step 1: Applied. `supabase/migrations/20260928120000_the_sla_clock_and_the_current_handler_are_not_the_callers.sql` was created LF, SHA-256 `235eb4847c18a54aeaff4cbc7c23d76493b210962ee4c8a5cb77116e0f02fab3`, exactly the value this step names.
- Step 2: Applied. `supabase/tests/136_lead_assignment_clock_and_current_handler_test.sql` was created LF, SHA-256 `8fbd0532f64f170e3316914a3c0d8df118430cfd33fa281d21a2e7a7a334ddda`, `plan(19)`, exactly the value this step names.
- Step 3: Applied.
  - Register: a Slice 30 freshness entry was added, and the Slice 29 entry was demoted to `Previously:`. ASGN-4 (Medium) and ASGN-5 (Medium) were appended after `| DOC-8 |`, each `FIXED locally by SPEC-232`, pending Primary deployment, Cert `📋`, Owner Decision `—`. No other row changed, including HIST-1, ASGN-1, ASGN-2, ASGN-3, ORIG-1, LEAD-4, LEAD-5, LI-3 and CAMP-4.
  - Disposition: `lead_assignments` was set to `AUDITED` / `ADVERSARIAL` / `SPEC-232-lead-assignment-clock-and-current-handler` / `ASGN-4, ASGN-5`. Coverage reads `31 of 77 recorded · 12 AUDITED · 16 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 46 NOT-RECORDED` and `All 31 recorded surfaces`. A freshness entry was added, and no other row changed.
  - Both code files are byte-identical to the prototype that was checked before freezing.

### 2026-09-28 — Pre-deploy readiness gate

On HEAD `ef91389`, with Steps 1-3 in the working tree:
- Both files hash to the frozen values: migration `235eb4847c18a54aeaff4cbc7c23d76493b210962ee4c8a5cb77116e0f02fab3`, Test 136 `8fbd0532f64f170e3316914a3c0d8df118430cfd33fa281d21a2e7a7a334ddda`.
- Clean reset: exit 0, 234 migrations through `20260928120000`.
- Focused Test 136: 19/19.
- pgTAP Pass A: `Files=136, Tests=2447, Result: PASS`.
- `verify_lifecycle_branches.ps1`: 122 passed, 0 failed.
- pgTAP Pass B without reset: `Files=136, Tests=2447, Result: PASS`.
- `scripts/verify_database.sql`: `ALL CHECKS PASSED`, exit 0.
- Plan sum: 2447 over 136 files.

Mutation (Test 136, assertions 15-17): pending checks were flushed, then the pre-repair `app.derive_assignment_actor` was installed and `lead_assignments_current_names_the_assignee` dropped in a savepoint, and the md5 was proven to differ. The department manager's close with nothing after it and century-ahead re-insert then landed, and the SLA acted on neither lead. After rollback to the savepoint, both functions were md5-identical to the repaired definitions, the check was back and deferred, and no mutant close survived. On the unrepaired stack at `76e0b6f`, the same bytes failed exactly the repair-owned assertions 3, 4, 7, 8, 10, 13 and 14 (the SLA warned only `{L2,L4,L5}` and the branch manager received 0 notices), failed the mechanism-bound 16, 17 and 19, and passed every control (1, 2, 5, 6, 9, 11, 12, 18).

Generators:
- `MASTER_API_CONTRACT.md` regenerated byte-identical (79 endpoints, 8 views, 73 tables), so it is unchanged.
- `ai-map.json` is regenerated in Step 7, once the manifest moves.

Checks on the working tree:
- `git diff --check` exited 0. The changed paths are the CR, the migration, Test 136, the register and the disposition record, all inside the frozen nine.
- Repository consistency found 6 issues, all expected at this boundary. Three come from the undeployed migration (manifest migration count, latest version and ledger fingerprint; the files produce `bf26c74e9266431f88ed5a61aa74954f`). Two are the suite figures (135/2428 vs 136/2447), which move in Step 7. The last is ledger evidence lacking `20260928120000`.

Under these reds the Gate blocks a commit, so these steps stay uncommitted until deployment, as SPEC-231 did.

Local candidate surfaces (`scripts/check_database_parity.ps1`):
- ledger 234 / `bf26c74e9266431f88ed5a61aa74954f`;
- functions `36411b98fec434082d8ed6f247348e7e` / 310;
- triggers `4d7c099d115fd9c69f30baad533e8069` / 299;
- constraints `3b47f1d13ec80c75b705e3a448ebec27` / 512;
- policies, grants, columns, views, indexes, status transitions and RLS flags identical to the recorded Primary values;
- combined `ac25eb2d5a277885fa662fa4c15d2441` / 3062.

`app.derive_assignment_actor` has `pg_get_functiondef` md5 `de0536caf1bade250661a6660b3984f9`, SECURITY INVOKER, `search_path` empty, ACL `{postgres=X/postgres}`. `app.enforce_lead_current_assignment` has md5 `3a175ce181bc1acdcdc2ddeb4ab68529`, SECURITY DEFINER, `search_path` empty, ACL `{postgres=X/postgres}`, not executable by anon or authenticated. `lead_assignments_current_names_the_assignee` is `tgtype` 21, deferrable, initially deferred, enabled `O`, with its `pg_constraint` row (contype `t`).

Fresh Primary `vrvtsxexkiiiivlkdxzp` baseline, read-only, 2026-09-28, through `scripts/parity_surface.sql`'s own queries:
- ledger 233 / `c641ed4f9faf6b8acb4c1342d311840d`, latest `20260927140000`; target migration, function, trigger and constraint absent;
- functions `25c5bce0b252c36d1cb1f04042f0d3a3` / 309; triggers `1ee1a1d1fa0b90265a65b044c7eb804c` / 298; constraints `1d5adec43fa5bacf35e949e5793bf397` / 511; combined `5a0247339f2a182952d3189e68d84edf` / 3059; all ten categories equal to the recorded evidence;
- 0 tenants, 0 leads, 0 lead assignments, 0 incoherent leads;
- `app.derive_assignment_actor` md5 `b82d76906fbecc0653fee702ca622585` (pre-repair), INVOKER, `search_path` empty, ACL `{postgres=X/postgres}`.

Predicted delta:
- ledger → 234 / `bf26c74e9266431f88ed5a61aa74954f`;
- functions → `36411b98fec434082d8ed6f247348e7e` / 310;
- `app.derive_assignment_actor` md5 → `de0536caf1bade250661a6660b3984f9`; new `app.enforce_lead_current_assignment` md5 `3a175ce181bc1acdcdc2ddeb4ab68529`;
- triggers → `4d7c099d115fd9c69f30baad533e8069` / 299; constraints → `3b47f1d13ec80c75b705e3a448ebec27` / 512;
- the seven other categories unchanged;
- combined → `ac25eb2d5a277885fa662fa4c15d2441` / 3062.

Primary deployment awaits separate exact-byte owner authorization (Step 5). Secondary was not contacted.

### 2026-09-28 — Authorized Primary deployment and reconciliation

**Authorization.** The owner authorized one Primary operation on `vrvtsxexkiiiivlkdxzp` (Step 5): `supabase/migrations/20260928120000_the_sla_clock_and_the_current_handler_are_not_the_callers.sql`, SHA-256 `235eb4847c18a54aeaff4cbc7c23d76493b210962ee4c8a5cb77116e0f02fab3`, bound to Test-136 SHA-256 `8fbd0532f64f170e3316914a3c0d8df118430cfd33fa281d21a2e7a7a334ddda`, with the conditions presented at Gate 2. It authorizes no business-data, policy, grant, trigger, constraint or other function write.

**Recheck immediately before writing.** Everything matched exactly:
- HEAD `ef91389`, with SPEC-232 In Progress; both hashes; only in-scope paths changed.
- The connector URL names `vrvtsxexkiiiivlkdxzp`.
- Primary: 233 / `c641ed4f9faf6b8acb4c1342d311840d`, latest `20260927140000`, target migration absent; functions 309, triggers 298, constraints 511; `app.enforce_lead_current_assignment` and `lead_assignments_current_names_the_assignee` absent. `app.derive_assignment_actor` md5 `b82d76906fbecc0653fee702ca622585`, SECURITY INVOKER, `search_path` empty, ACL `{postgres=X/postgres}`. 0 tenants, 0 leads, 0 lead assignments, 0 incoherent leads or rows.

**Deployment (Step 6).** Only that migration was applied, through the Primary connector. The connector created exactly one new row, with temporary version `20260928114223`. Its single stored statement (4433 bytes, md5 `e23fbe0338da061ba96bb54dfc273c15`) equals the migration file. A guarded update then renamed only that row to `20260928120000`: there was no existing `20260928120000`, exactly one row followed `20260927140000`, the statement md5 matched, and 1 row was updated. There was no business-data write, the exploit was not replayed on Primary, and Secondary was not contacted.

**Fresh postwrite readings**, every value equal to the local prediction:
- ledger 234 / `bf26c74e9266431f88ed5a61aa74954f`, with the target exactly once and no row after it;
- functions `36411b98fec434082d8ed6f247348e7e`/310, triggers `4d7c099d115fd9c69f30baad533e8069`/299 and constraints `3b47f1d13ec80c75b705e3a448ebec27`/512;
- policies, grants, columns, views, indexes, status transitions and RLS flags unchanged;
- combined `ac25eb2d5a277885fa662fa4c15d2441`/3062.

**Direct inspection.** `app.derive_assignment_actor()` has `pg_get_functiondef` md5 `de0536caf1bade250661a6660b3984f9`, equal to local, SECURITY INVOKER, `search_path` empty, ACL `{postgres=X/postgres}`, and carries the ASGN-2 / ASGN-5 comment; `lead_assignments_derive_actor` is `tgtype` 7, enabled `O`. `app.enforce_lead_current_assignment()` has md5 `3a175ce181bc1acdcdc2ddeb4ab68529`, equal to local, SECURITY DEFINER, `search_path` empty, ACL `{postgres=X/postgres}`, not executable by anon or authenticated. `lead_assignments_current_names_the_assignee` is `tgtype` 21, DEFERRABLE, INITIALLY DEFERRED, enabled `O`, executing that function, with its `pg_constraint` row (contype `t`). 0 tenants, 0 leads, 0 lead assignments.

**Reconciliation (Step 7).** Every value below comes from those readings:
- `reports/evidence/primary-ledger-evidence.json` holds the ordered ledger of 234 entries, verified to hash to the Primary-read fingerprint and to equal the repository's migration files, and the new function and structural hashes.
- Manifest:
  - `Live state` moved to 234 / `20260928120000` / `bf26c74e…` / `36411b98…` (310) / `ac25eb2d…` (3,062), re-read 2026-09-28.
  - The suite figure moved to 136 files / 2447 assertions, after measuring 136 files with a plan sum of 2447.
  - The Batch 6 line moved to `**31 of 77 surfaces have a recorded audit disposition**, all thirty-one at`, after Step 3 set Coverage to 31 of 77.
  - `Last Completed` moved to Slice 30 / ASGN-4 / ASGN-5 / SPEC-232.
  - The manifest is 6683 characters.
- ASGN-4 and ASGN-5 are marked `FIXED` / `DEPLOYED`, with Cert `✅`. No other register row changed.
- `MASTER_API_CONTRACT.md` regenerated byte-identical, so it is unchanged. `ai-map.json` was regenerated and stored LF.

## Verification Notes

None yet.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

- **EARN IT.** Both findings were reproduced end to end against rules the repository already states: canon 04 makes SLA escalation mandatory and the assignment time a timeline fact, canon 10 makes manager escalation unmutable, and `app.process_lead_sla` reads exactly the two inputs that were writable. The consequence is a lead taken out of escalation for good, with no event and no notice to the manager above, or a timeline whose first handler and order are forged. No existing control owns either direction: `app.require_assignment_history` guards the lead side, and `app.forbid_assignment_history_rewrite` only the UPDATE.
- **WORTH IT.** One line in the trigger that already derives an assignment's server-owned columns, and one deferred check in an idiom the ledger already uses. No data reconciliation is needed (Primary has 0 assignments). A reopen trigger was rejected because the event that exposes both, a tenant working its first lead, is ordinary operation that no CR or check observes, and the scheduled job is already running every minute. The residual cost is Gate 2 and one deployment.
- **Rejected alternatives:**
  - recording ASGN-4 and ASGN-5 OPEN with a reopen trigger: nothing would fire when the first tenant goes live;
  - fixing only the clock: closing the current row with nothing after it still silences the SLA for good;
  - requiring assignments to be born current: `verify_lifecycle_branches.ps1` asserts that a closed history row is legal, and after the clock is derived such a row is stamped now and attributed;
  - freezing `assignment_reason` and `unassigned_at`: no server-side reader.
- **Untouched:** HIST-1, ASGN-1, ASGN-2, ASGN-3, ORIG-1, LEAD-4, LEAD-5, LI-3, CAMP-4, ENTRY-1 and every other open finding. The registered worktree `owt/p2` is untouched.
