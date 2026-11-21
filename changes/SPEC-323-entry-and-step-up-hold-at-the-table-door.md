# Change Request — SPEC-323

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close three reproduced entry and step-up gaps at the same table-door write boundary by reusing existing mechanisms. Archive authority applies on INSERT for leads, quotations, booking items and invoices (ARCH-2). Writes to campaign_daily_metrics and exchange_rate_adjustments require the permission their RLS already charges plus the role's MFA (STEPUP-1). A signed-in booking-item insert must open at `draft` with no lifecycle stamp (ENTRY-1).

## Business Reason

Each gap was reproduced at CRM `73b02a1` in rolled-back transactions. An employee without ARCHIVE_RECORD created archived leads, quotations and booking items and forged `archived_by`. An aal2 finance user created an archived invoice with a forged archiver and a time backdated one year. An aal1 owner wrote campaign metrics that the same session could not write on the parent campaign. An aal1 finance manager created an adjustment that then blocked an aal2 rate correction. An employee refused by the finance gate inserted that booking item already `in_progress`, and also inserted a `completed` item backdated 400 days, with no lifecycle event. The owner's 2026-11-20 directive groups items that share evidence, tests and a release boundary while keeping per-item acceptance.

## Risks

CREATE TRIGGER and CREATE OR REPLACE FUNCTION take locks on six tables. Measure the lock state before the write; Primary holds zero rows in every scoped table. Preserve the ownership and ACL of app.guard_write_capability and app.enforce_archive_authority, every grant, policy, permission, RLS predicate, event producer and RPC. Session-less platform paths remain exempt from the booking-item entry rule, as they are from the transition graph. The rollback path is a separately authorized corrective migration that drops the new bindings and the entry guard and restores the previous capability function. Do not rewrite existing business rows.

## Supersedes / Depends On

Depends on SPEC-319 (archive authority judges INSERT), SPEC-222 and SPEC-320 (capability guard arms), SPEC-239 (signed-in entry shape) and the CRM SPEC-322 certified baseline. Supersedes only the Test 58 guard-membership assertions and the Test 101 function-consumer assertion that recorded the previous state.

## Write Scope

- `changes/SPEC-323-entry-and-step-up-hold-at-the-table-door.md`
- `supabase/migrations/20261121100000_entry_and_step_up_hold_at_the_table_door.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql`
- `supabase/tests/183_entry_and_step_up_hold_at_the_table_door_test.sql`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/evidence/primary-ledger-evidence.json`
- `reports/future-backlog.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/config.toml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/readiness_population.ps1`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

All other paths, Founder Secondary, integration activation, UI, campaign entry (CAMP-2), campaign events (CAMP-4), journal entries (JE-2), other STEPUP-1 candidates and GitHub configuration are outside scope.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9; `ENGINEERING_METHOD.md` §§2, 4 and 5.
- `_ORVION_CANONICAL/28_permissions_matrix.md`; canon 26 on status entry.
- SPEC-319 migration `20261119203357_archive_authority_applies_at_entry.sql`, SPEC-320 migration `20261120122927_branch_write_authority_matches_the_rpc.sql` and `app.create_booking_item`.
- `reports/master/MASTER_EXECUTION_PLAN.md` action registry; ARCH-2, ENTRY-1, STEPUP-1, CAMP-2 and CAMP-4 in the gap register.
- `supabase/tests/58_write_grants_and_config_capability_test.sql`, `supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql` and `supabase/tests/182_archive_authority_applies_at_entry_test.sql`.

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Reuse three existing mechanisms rather than adding authority. Re-attach four archive triggers BEFORE INSERT OR UPDATE to the unchanged app.enforce_archive_authority. Add two arms to app.guard_write_capability, priced at the permission each table's RLS write check already charges (MANAGE_MARKETING_CAMPAIGN and CREATE_EXCHANGE_RATE_ADJUSTMENT), with BEFORE INSERT OR UPDATE bindings. Add one signed-in booking-item entry guard in SPEC-239's bookings shape, matching app.create_booking_item, the only inserter.

Pass 2 Adversarial Review: Five rolled-back reproductions at the baseline prove each gap and its consequence. Campaign entry was assessed and has no material consequence, because every campaign transition charges the permission its creator already holds; CAMP-2 and CAMP-4 therefore keep their own triggers. JE-2 has no approved containment and is not touched. Test 183 checks refusals with the stored rows unchanged, authorized aal2 writes, server-stamped archiver and time, the RPC door, session-less exemption and trigger timing. The first full run exposed two test-fixture defects, which were fixed at the test, and the original Test 58 count and membership and Test 101 consumer assertions flagged the deliberate change.

Pass 3 Evidence Refresh: 2026-11-20. On isolated CRM baseline 73b02a1ac820683846a7566c88d5704bf3171884, the repaired schema has 275 migration rows, latest `20261121100000`, ledger fingerprint `5213d0d035d53e635a839f0ce9bb7693`, with seven new or re-attached triggers, one new function and unchanged API grants. The full pgTAP run passed 183 files and 3409 assertions. Database smoke passed, and the existing HTTP suite passed 35 assertions on the isolated API through its local container adapter. The regenerated API contract changes only the two newly guarded table rows. Primary `vrvtsxexkiiiivlkdxzp` was read separately at 274 migrations, latest `20261120122927`, fingerprint `67a6f9f8b5454c75d09b62a8f748c20d`, with the target absent and zero rows in all six tables. Recheck live at the deployment boundary.

Selected Version: SPEC-323; selected: existing archive authority, capability guard and SPEC-239 entry shape reused at six tables, proven in one suite with two aligned test files

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Archive state on creation of leads, quotations, booking items and invoices | app.enforce_archive_authority, the creating RPCs and archive RLS | WRITE | Test 183 refuses unauthorized archived creation and forged active-row metadata with nothing stored. It accepts an authorized archived invoice with server-stamped archiver and time. The function body is unchanged. |
| Campaign metrics and exchange-rate adjustment writes | RLS write checks, app.authorize and app.guard_exchange_rate_write | WRITE | Test 183 refuses aal1 writes and accepts aal2 writes. Test 101 records the guard as the table's own door, and no RPC writes either table. |
| Shared capability guard | The twenty-nine existing bindings | VERIFY | The function changes only by adding two mappings. Test 58 checks exact membership, and the full suite covers the previous bindings. |
| Booking-item entry | app.create_booking_item, app.advance_booking_item, ADR-0020 finance gate, platform paths | WRITE | Test 183 proves the RPC still creates the draft item, a signed-in late-state or stamped insert is refused, and session-less paths stay exempt. Tests 74 and 105 pass unchanged. |
| B6-EXIT evidence | ARCH-2, ENTRY-1, STEPUP-1, CAMP-2 and the six disposition rows | WRITE | Record closure after hosted proof. CAMP-2 and the marketing_campaigns surface move to their own existing trigger. |
| Docker `tcp://localhost:2375` live deferred item at B6-EXIT | `reports/future-backlog.md`, readiness_population and Check 29 | WRITE | Measured 2026-11-20T22:43Z: Docker Desktop `ExposeDockerAPIOnTCP2375` is false, nothing listens on port 2375 at 127.0.0.1 or ::1, and this contract's full isolated stack, smoke, HTTP and rehearsal ran over the named pipe. Step 9 re-measures and closes the row only on agreeing evidence. |
| Contract evidence | Generated API, Primary ledger and parity, manifest and discovery | WRITE | Reuse native generation and evidence methods; the API contract changes only in two rows. |
| Audit events, Founder, integrations and frontend | Existing producers and workflows | UNAFFECTED | No event producer, product action or integration changes. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 8 (Platinum Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact approved payload, local functional proof, fresh target identity and recovery evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 7 |
| Recorded ledger reflects the actual Platinum Primary ledger | BEFORE_COMPLETION | Step 1 | Step 9 | Step 10 |
| Repository and local figures match the pre-deploy payload | BEFORE_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Generated evidence agrees with the deployed structure | BEFORE_COMPLETION | Step 8 | Step 9 | Step 10 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: app.enforce_archive_authority (SPEC-319), app.guard_write_capability with app.authorize (SPEC-222, SPEC-320) and the SPEC-239 signed-in entry-state shape.

Added Property: On the six tables, a signed-in INSERT is held to the same archive authority, step-up and booking-item entry state that UPDATE and the RPCs already enforce.

Causal Negative: Workbench reproductions `repro2`, `repro3`, `repro`, `repro4` and `repro5` at `73b02a1` succeed where this change refuses.

Positive Test Design: Test 183 requires authorized aal2 metric and adjustment writes, an authorized archived invoice with server-stamped metadata, an employee's active creation on three tables and the booking-item RPC draft, and the session-less exemption.

Negative Test Design: Test 183 requires SQLSTATE refusals for unauthorized archived creation, forged metadata, aal1 metric and adjustment writes, and late-state or stamped booking-item inserts, and reads back that nothing was stored. Test 58 pins guard membership and trigger timing.

Non-Empty Population Obligation: Test 183 establishes tenants, real permission holders at aal1 and aal2, parent bookings, campaigns and rates before testing refusals and valid writes.

Mutation Obligation: Disabling any new or re-attached trigger in a rolled-back transaction must turn a Test 183 refusal assertion red; the certified baseline reproductions must differ in exactly the refused behaviors.

Post-Implementation Proof Obligation: Fresh approved Primary apply and separate readback agree with local ledger and structural fingerprints. Re-run native consistency and readiness evidence and retain CAMP-2, CAMP-4, JE-2 and the remaining STEPUP-1 candidates at their recorded triggers.

## Implementation Steps

1. Check whether `supabase/migrations/20261121100000_entry_and_step_up_hold_at_the_table_door.sql` contains `-- B6-EXIT bundle A: three entry and step-up holes at the table door`; if so record Already Applied when its Git blob is fc317dda36df2d5540bad2ba6afcabbf9d2e8867, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the table-door archive, step-up and booking-item entry migration), and change nothing else:

   ```text
   -- B6-EXIT bundle A: three entry and step-up holes at the table door, each reproduced at 73b02a1 in
   -- rolled-back transactions on the local stack, each closed by reusing a mechanism already in force.
   --   * ARCH-2: an employee without ARCHIVE_RECORD inserted archived leads, quotations and booking
   --     items, and an active row naming a forged archived_by; an aal2 finance user inserted an
   --     archived invoice with archived_by forged and archived_at backdated a year. SPEC-319 already
   --     made app.enforce_archive_authority judge INSERT; these four attachments still fired on UPDATE
   --     only. They are re-attached BEFORE INSERT OR UPDATE on the unchanged function.
   --   * STEPUP-1: an aal1 owner inserted campaign_daily_metrics (spend 0, revenue 5,000,000) while the
   --     same session was refused the parent campaign update for missing MFA; an aal1 finance_manager
   --     inserted an exchange_rate_adjustment that then blocked an aal2 correction of the cited rate.
   --     Both tables gain the arm of app.guard_write_capability that CAMP-3 and BRANCH-1 use, priced at
   --     the permission each table's RLS write check already demands, so app.authorize adds only the
   --     role's MFA requirement. No RPC writes either table.
   --   * ENTRY-1 (booking_items): the employee refused by app.advance_booking_item for a finance-gated
   --     item inserted that item already in_progress with no approval, and a completed item with
   --     completed_at backdated 400 days; neither emitted a lifecycle event. app.create_booking_item,
   --     the only inserter, writes 'draft' and no lifecycle stamp. A signed-in caller is now held to
   --     the same entry, SPEC-239's bookings rule; session-less platform paths stay exempt, as
   --     app.enforce_status_transition already exempts them from the whole graph.
   -- NOT CHANGED: every grant, policy, permission, RLS check, event producer and RPC; the permission
   -- mapping of every other table; CAMP-2, JE-2 and the other STEPUP-1 candidates.

   create or replace trigger leads_enforce_archive_authority
   before insert or update on public.leads
   for each row execute function app.enforce_archive_authority();

   create or replace trigger quotations_enforce_archive_authority
   before insert or update on public.quotations
   for each row execute function app.enforce_archive_authority();

   create or replace trigger booking_items_enforce_archive_authority
   before insert or update on public.booking_items
   for each row execute function app.enforce_archive_authority();

   create or replace trigger invoices_enforce_archive_authority
   before insert or update on public.invoices
   for each row execute function app.enforce_archive_authority();

   CREATE OR REPLACE FUNCTION app.guard_write_capability()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO ''
   AS $function$
   declare
       v_perms  text[];
       v_extra  text[];
       v_perm   text;
       v_held   text;
       v_strict boolean := false;
       v_relationship_ok boolean := false;
   begin
       -- Platform/system paths (canon 35 principle 6), as in every other guard here.
       if (select auth.uid()) is null then
           return new;
       end if;

       -- 202607058500 (LIC-3 / PP-4): `documents` is resolved in its OWN statement, not inside the
       -- shared CASE below. A record field reference is resolved against the ACTUAL record type at
       -- execution, so naming `new.document_type_code` inside an expression this trigger also evaluates
       -- for `customers`, `leads` and twenty other tables fails on every one of them.
       if tg_table_name = 'documents' then
           if new.document_type_code = 'payment_proof' then
               v_perms := array['MANAGE_TENANT_SETTINGS'];
               v_strict := true;
           else
               v_perms := array['UPLOAD_DOCUMENT'];
           end if;
       else
       v_perms := case tg_table_name
                      when 'approval_requests'         then array['CREATE_BOOKING_ITEM']
                      when 'booking_item_passengers'   then array['CREATE_BOOKING_ITEM']
                      when 'booking_items'             then array['CREATE_BOOKING_ITEM']
                      when 'conversation_messages'     then array['SEND_MESSAGE']
                      when 'customer_contact_methods'  then array['CREATE_CUSTOMER']
                      when 'customer_identity_signals' then array['CREATE_CUSTOMER']
                      when 'customer_identity_merges'  then array['MERGE_CUSTOMER_IDENTITY']
                      when 'internal_supplier_links'   then array['ASSIGN_SUPPLIER']
                      when 'offline_conversions'       then array['MANAGE_MARKETING_CAMPAIGN']
                      when 'marketing_campaigns'       then array['MANAGE_MARKETING_CAMPAIGN']
                      when 'campaign_daily_metrics'    then array['MANAGE_MARKETING_CAMPAIGN']
                      when 'exchange_rate_adjustments' then array['CREATE_EXCHANGE_RATE_ADJUSTMENT']
                      when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                      when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
                      when 'branches'                  then array['MANAGE_BRANCHES']
                      when 'branch_business_hours'     then array['MANAGE_BRANCHES']
                      when 'holidays'                  then array['MANAGE_BRANCHES','MANAGE_TENANT_SETTINGS']
                      when 'financial_accounts'        then array['CREATE_JOURNAL_ENTRY']
                      when 'company_assets'            then array['CREATE_JOURNAL_ENTRY']
                      when 'bookings'                  then array['CREATE_BOOKING']
                      when 'complaints'                then array['CREATE_COMPLAINT']
                      when 'conversations'             then array['SEND_MESSAGE']
                      when 'customer_notes'            then array['CREATE_CUSTOMER']
                      when 'customers'                 then array['CREATE_CUSTOMER']
                      when 'leads'                     then array['CREATE_LEAD']
                      when 'passengers'                then array['CREATE_BOOKING_ITEM']
                      when 'quotations'                then array['CREATE_QUOTATION']
                      when 'service_requests'          then array['CREATE_SERVICE_REQUEST']
                      when 'suppliers'                 then array['ASSIGN_SUPPLIER']
                      when 'tasks'                     then array['CREATE_TASK']
                  end;
       end if;

       -- 202607059100 (SEC-1c): on UPDATE the object-class permission is joined by the permissions canon
       -- already says may MUTATE this object.
       if tg_op = 'UPDATE' and not v_strict then
           v_extra := case tg_table_name
                          when 'approval_requests'  then array['APPROVE_FINANCE','REVIEW_APPROVAL_REQUEST','REVIEW_SUBSCRIPTION_PAYMENT']
                          -- PAX-5 (2026-09-09): the post-issue manifest authority APPENDS, exactly as
                          -- CUST-3's block below explains for MANAGE_CUSTOMER_CREDIT and NOT as the
                          -- supplier branch REPLACES. Measured containment: CORRECT_PASSENGER_MANIFEST
                          -- goes to owner/ceo/branch_manager/finance_manager and CREATE_BOOKING_ITEM to
                          -- owner/ceo/branch_manager/department_manager/employee/senior_employee, so
                          -- `finance_manager` holds the first and NOT the second. Without this line the
                          -- object-class door would refuse a finance manager's correction before
                          -- app.enforce_booking_item_passenger_lifecycle -- the enforcer that actually
                          -- owns PAX-5 -- ever ran, and a per-user grant of the capability would be
                          -- silently void. Appending widens only WHO REACHES THE ENFORCER; the freeze
                          -- itself still demands CORRECT_PASSENGER_MANIFEST specifically.
                          when 'booking_items'      then array['UPDATE_BOOKING_ITEM_STATUS','ENTER_COST','ENTER_SELLING_PRICE','APPROVE_FINANCE','EDIT_LOCKED_COST','ARCHIVE_RECORD','ASSIGN_SUPPLIER']
                          when 'bookings'           then array['APPROVE_BOOKING','CANCEL_BOOKING','ISSUE_BOOKING','REFUND_BOOKING','REISSUE_BOOKING']
                          when 'complaints'         then array['RESOLVE_COMPLAINT']
                          when 'conversations'      then array['CLOSE_CONVERSATION','ESCALATE_CONVERSATION']
                          when 'customers'          then array['MERGE_CUSTOMER_IDENTITY']
                          when 'documents'          then array['ARCHIVE_DOCUMENT','CREATE_DOCUMENT_VERSION']
                          when 'leads'              then array['ASSIGN_LEAD','CLOSE_LEAD','REASSIGN_LEAD']
                          when 'quotations'         then array['ACCEPT_QUOTATION','SEND_QUOTATION']
                          when 'service_requests'   then array['RESOLVE_SERVICE_REQUEST']
                          when 'tasks'              then array['ASSIGN_TASK','COMPLETE_TASK']
                          else null
                      end;
           if v_extra is not null then
               v_perms := v_perms || v_extra;
           end if;
       end if;

       -- CUST-3 (2026-09-04): the customer ceiling. REQUIRED, not cosmetic -- `finance_manager` does NOT
       -- hold CREATE_CUSTOMER (measured: only owner, ceo, branch_manager, department_manager,
       -- senior_employee and employee do), so without this a finance manager could not set a ceiling at
       -- all. That is SUP-3's defect one table over.
       --
       -- THIS BRANCH APPENDS; THE SUPPLIER BRANCH BELOW REPLACES, AND THE DIFFERENCE IS DELIBERATE.
       -- MANAGE_CUSTOMER_CREDIT is NOT a subset of CREATE_CUSTOMER (`finance_manager` holds the first
       -- and not the second), so replacing here would refuse an employee legitimately creating a
       -- customer that happens to carry a ceiling. On `suppliers` the containment runs the other way and
       -- replacing costs nothing -- see CUST-5's block in `202607060600`. The CONSEQUENCE of appending
       -- is that this guard is not a second enforcer of MANAGE_CUSTOMER_CREDIT the way the supplier
       -- branch is; `customers_guard_credit_authority` is the sole enforcer on this table. Recorded as
       -- CUST-6 rather than changed inside a supplier migration.
       if tg_table_name = 'customers' then
           if (tg_op = 'UPDATE'
               and (new.credit_limit_amount is distinct from old.credit_limit_amount
                    or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code))
              or (tg_op = 'INSERT'
                  and (new.credit_limit_amount is not null or new.credit_limit_currency_code is not null))
           then
               -- `array[...]`, not a bare literal: `text[] || 'x'` makes PostgreSQL parse the untyped
               -- literal AS an array and fail with 22P02, which is what the suite caught first.
               v_perms := v_perms || array['MANAGE_CUSTOMER_CREDIT'];
           end if;
       end if;

       -- PAX-5 (2026-09-09). SCOPED TO THE ACT, NOT TO THE TABLE, and the first draft was wrong in a way
       -- the suite caught. Measured containment: CORRECT_PASSENGER_MANIFEST goes to
       -- owner/ceo/branch_manager/finance_manager, CREATE_BOOKING_ITEM to those three plus
       -- department_manager/employee/senior_employee -- so `finance_manager` holds the first and NOT the
       -- second, and without SOME widening a per-user grant of the correction capability would be
       -- silently void: the object-class door would refuse before
       -- app.enforce_booking_item_passenger_lifecycle -- the enforcer that owns PAX-5 -- ever ran.
       --
       -- THE FIRST DRAFT WIDENED THE WHOLE TABLE and broke PAX-2: test 104 assertions 10 and 12 failed,
       -- because a finance_manager could then swap the traveller on a DRAFT link they did not create,
       -- which is the exact reproduction 202607061400 closed. The rule is not "this table costs the
       -- correction capability"; it is "an ATTRIBUTED CORRECTION may be made by a correction holder".
       --
       -- So the alternative is offered ONLY when the statement is actually a correction: the traveller
       -- moves AND the statement authors a fresh reason for it -- the same two facts the lifecycle guard
       -- demands in the frozen period. A bare swap still costs CREATE_BOOKING_ITEM and nothing else, so
       -- PAX-2 is untouched. This APPENDS rather than REPLACES, for CUST-3's reason exactly: the two
       -- populations are not nested, and replacing would refuse an employee's ordinary attributed edit.
       if tg_op = 'UPDATE' and tg_table_name = 'booking_item_passengers' then
           -- PAX-7 (SPEC-223): correcting the TICKETED IDENTITY of the same traveller is the same
           -- attributed correction as moving the traveller, so it is offered on the same two facts.
           -- PAX-9 (SPEC-224): so is moving an entry ONTO or OFF a frozen manifest. Only a frozen
           -- endpoint qualifies: between unfrozen items a reason buys nothing here, and the object-class
           -- authority stays the only door.
           if (new.passenger_id is distinct from old.passenger_id
               or (new.manifest_first_name, new.manifest_family_name, new.manifest_full_name,
                   new.manifest_date_of_birth, new.manifest_passport_number,
                   new.manifest_passport_issuing_country_code)
                  is distinct from
                  (old.manifest_first_name, old.manifest_family_name, old.manifest_full_name,
                   old.manifest_date_of_birth, old.manifest_passport_number,
                   old.manifest_passport_issuing_country_code)
               or (new.booking_item_id is distinct from old.booking_item_id
                   and exists (select 1
                                 from public.booking_items bi
                                 join public.bookings b on b.id = bi.booking_id
                                where bi.id in (old.booking_item_id, new.booking_item_id)
                                  and bi.tenant_id = (select app.current_tenant_id())
                                  and app.manifest_is_frozen(b.booking_status_code, b.is_archived))))
              and new.passenger_correction_reason is distinct from old.passenger_correction_reason
              and coalesce(btrim(new.passenger_correction_reason), '') <> '' then
               v_perms := v_perms || array['CORRECT_PASSENGER_MANIFEST'];
           end if;
       end if;
       -- PAX-9 (SPEC-224): adding a traveller to a FROZEN manifest is an attributed correction too, and
       -- is offered on the same facts; before the freeze an insertion stays CREATE_BOOKING_ITEM work.
       if tg_op = 'INSERT' and tg_table_name = 'booking_item_passengers' then
           if coalesce(btrim(new.passenger_correction_reason), '') <> ''
              and exists (select 1
                            from public.booking_items bi
                            join public.bookings b on b.id = bi.booking_id
                           where bi.id = new.booking_item_id
                             and bi.tenant_id = (select app.current_tenant_id())
                             and app.manifest_is_frozen(b.booking_status_code, b.is_archived)) then
               v_perms := v_perms || array['CORRECT_PASSENGER_MANIFEST'];
           end if;
       end if;
       -- CUST-5 (202607060600): SUP-3's authority, widened by SUP-4a to the PAIR (amount, currency),
       -- expressed WITHOUT a row image. The ONLY change from the replaced form is that the
       -- "and nothing else changed" conjunct is GONE; the assignment it guards is untouched.
       if tg_op = 'UPDATE' and tg_table_name = 'suppliers' then
           if new.credit_limit_amount is distinct from old.credit_limit_amount
              or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code
           then
               v_perms := array['MANAGE_SUPPLIER_CREDIT'];
           end if;
       end if;

       -- LEAD-1 (202607061900). The handler rule, evaluated ONLY inside its own table branch so
       -- `new.assigned_user_id` is never named while this trigger is serving `suppliers` or `customers`.
       -- TWO CHANGES FROM THE FORM THIS REPLACES, both from BOOK-5's standing question:
       --   * MOVING THE ASSIGNMENT is authority, not content, and it costs what the two RPCs that do it
       --     charge. REPLACES the permission set (the `suppliers` shape): every role holding either key
       --     also holds CREATE_LEAD, so nothing legitimate loses a door.
       --   * THE SHORTCUT READS `old`. Reading `new` let the attacking statement supply the answer to
       --     "are you the handler?" and skip the entire check for every column in the statement.
       if tg_op = 'UPDATE' and tg_table_name = 'leads' then
           if new.assigned_user_id is distinct from old.assigned_user_id
              or new.owner_user_id is distinct from old.owner_user_id then
               v_perms := array['ASSIGN_LEAD','REASSIGN_LEAD'];
           else
               v_relationship_ok := (select app.current_user_id()) is not null
                                    and (select app.current_user_id())
                                        in (old.assigned_user_id, old.owner_user_id);
           end if;
       end if;

       if v_relationship_ok then
           return new;
       end if;

       if v_perms is null then
           raise exception 'guard_write_capability has no permission mapping for %', tg_table_name
               using errcode = 'insufficient_privilege';
       end if;

       foreach v_perm in array v_perms loop
           if app.has_permission(v_perm) then
               v_held := v_perm;
               exit;
           end if;
       end loop;

       if v_held is null then
           raise exception 'permission denied: one of % is required to write %',
                           array_to_string(v_perms, ' or '), tg_table_name
               using errcode = 'insufficient_privilege';
       end if;

       perform app.authorize(v_held);
       return new;
   end;
   $function$;

   create trigger campaign_daily_metrics_guard_write_capability
       before insert or update on public.campaign_daily_metrics
       for each row execute function app.guard_write_capability();

   create trigger exchange_rate_adjustments_guard_write_capability
       before insert or update on public.exchange_rate_adjustments
       for each row execute function app.guard_write_capability();

   create function app.guard_booking_item_entry_state()
   returns trigger
   language plpgsql
   set search_path = ''
   as $fn$
   begin
       if (select auth.uid()) is null then
           return new;
       end if;
       raise exception using
           errcode = '23514',
           message = 'a booking item is created at ''draft'' with no lifecycle stamp (canon 26); '
                     'use app.advance_booking_item to move it';
   end;
   $fn$;

   revoke all on function app.guard_booking_item_entry_state() from public;

   create trigger booking_items_guard_entry_state
   before insert on public.booking_items
   for each row
   when (new.base_status_code is distinct from 'draft'
         or new.completed_at is not null
         or new.cancelled_at is not null
         or new.cancelled_by is not null
         or new.no_show_at is not null
         or new.no_show_recorded_by is not null)
   execute function app.guard_booking_item_entry_state();
   ```

   The resulting file's Git blob is fc317dda36df2d5540bad2ba6afcabbf9d2e8867.

2. Check whether `supabase/tests/58_write_grants_and_config_capability_test.sql` contains `thirty-one tables now carry the write-capability guard`; if so record Already Applied when its Git blob is 68f4e874e55af952e5e2e8034dd334e347ea935c, and otherwise stop and report. Otherwise make exactly these 2 edits (the exact guard binding membership), each matched once, and change nothing else:

   a) replace the lines
   ```text
     29,
     'twenty-nine tables now carry the write-capability guard (13 + SEC-1b''s twelve, 202607057000 + booking_item_passengers, PAX-1, 202607061400 + booking_items, BOOK-3, 202607061500 + marketing_campaigns, CAMP-3, SPEC-222 + branches, BRANCH-1)');
   ```
   with
   ```text
     31,
     'thirty-one tables now carry the write-capability guard (13 + SEC-1b''s twelve, 202607057000 + booking_item_passengers, PAX-1, 202607061400 + booking_items, BOOK-3, 202607061500 + marketing_campaigns, CAMP-3, SPEC-222 + branches, BRANCH-1 + campaign_daily_metrics and exchange_rate_adjustments, STEPUP-1, 20261121100000)');
   ```

   b) replace the line
   ```text
                               'marketing_campaigns','branches')),
   ```
   with
   ```text
                               'marketing_campaigns','branches',
                               -- STEPUP-1 (20261121100000): RLS charged the permission but not the step-up.
                               'campaign_daily_metrics','exchange_rate_adjustments')),
   ```

   The resulting file's Git blob is 68f4e874e55af952e5e2e8034dd334e347ea935c.

3. Check whether `supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql` contains `Re-reasoned at B6-EXIT bundle A`; if so record Already Applied when its Git blob is 2b86d7be04a4a337d387ff60da68789caa9c9ca6, and otherwise stop and report. Otherwise make exactly this one edit (the marketing metrics and FX adjustment trigger expectation), each matched once, and change nothing else:

   a) replace the line
   ```text
         and p.oid <> 'app.guard_exchange_rate_write'::regproc),
   ```
   with
   ```text
         and p.oid <> 'app.guard_exchange_rate_write'::regproc
         -- Re-reasoned at B6-EXIT bundle A (`20261121100000`, STEPUP-1): `app.guard_write_capability` is the
         -- table door's own step-up guard, charging the permission the RLS write check already names plus
         -- the role's MFA. It writes nothing and opens no other door to either table.
         and p.oid <> 'app.guard_write_capability'::regproc),
   ```

   The resulting file's Git blob is 2b86d7be04a4a337d387ff60da68789caa9c9ca6.

4. Check whether `supabase/tests/183_entry_and_step_up_hold_at_the_table_door_test.sql` contains `select plan(30);`; if so record Already Applied when its Git blob is d11dea50c36e8dcc1e418251125358ad0377e87b, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the six-table regression test), and change nothing else:

   ```text
   -- B6-EXIT bundle A: ARCH-2 archive authority at entry on leads, quotations, booking_items and
   -- invoices; STEPUP-1 step-up on campaign_daily_metrics and exchange_rate_adjustments; ENTRY-1
   -- booking items enter at 'draft' with no lifecycle stamp. Each refused case below passed at 73b02a1.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(30);

   insert into auth.users (id, email) values
       ('18300000-0000-0000-0000-0000000000a1', 'owner@entry183.test'),
       ('18300000-0000-0000-0000-0000000000a2', 'finance@entry183.test'),
       ('18300000-0000-0000-0000-0000000000a3', 'emp@entry183.test');
   insert into public.tenants (id, name, slug, status)
   values ('18300000-0000-0000-0000-000000000001', 'Entry 183 Travel', 'entry-183', 'active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '18300000-0000-0000-0000-000000000001', id, 'active'
   from public.subscription_plans where plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug)
   values ('18300000-0000-0000-0000-00000000000a', '18300000-0000-0000-0000-000000000001', 'HQ', 'entry-183-hq');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
   values ('18300000-0000-0000-0000-00000000000b', '18300000-0000-0000-0000-000000000001',
           '18300000-0000-0000-0000-00000000000a', 'management', 'Exec');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
       ('18300000-0000-0000-0000-000000000011', '18300000-0000-0000-0000-000000000001', 'Owner', 'owner@entry183.test', true, '18300000-0000-0000-0000-0000000000a1'),
       ('18300000-0000-0000-0000-000000000012', '18300000-0000-0000-0000-000000000001', 'Finance', 'finance@entry183.test', true, '18300000-0000-0000-0000-0000000000a2'),
       ('18300000-0000-0000-0000-000000000013', '18300000-0000-0000-0000-000000000001', 'Emp', 'emp@entry183.test', true, '18300000-0000-0000-0000-0000000000a3');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
   select tenant_id, id, '18300000-0000-0000-0000-00000000000a', '18300000-0000-0000-0000-00000000000b', true
   from public.users where tenant_id = '18300000-0000-0000-0000-000000000001';
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '18300000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
   from (values ('18300000-0000-0000-0000-000000000011'::uuid, 'owner'),
                ('18300000-0000-0000-0000-000000000012'::uuid, 'finance_manager'),
                ('18300000-0000-0000-0000-000000000013'::uuid, 'employee')) v(u, rc)
   join public.roles r on r.code = v.rc;

   insert into public.marketing_campaigns (id, tenant_id, platform_code, campaign_name, status_code)
   values ('18300000-0000-0000-0000-0000000000cc', '18300000-0000-0000-0000-000000000001', 'google_ads', 'Umrah Q3', 'active');
   insert into public.campaign_daily_metrics (id, tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks, revenue_amount)
   values ('18300000-0000-0000-0000-0000000000dd', '18300000-0000-0000-0000-000000000001',
           '18300000-0000-0000-0000-0000000000cc', date '2026-08-01', 10, 'EGP', 100, 5, 0);
   insert into public.customers (id, tenant_id, customer_type_code, full_name)
   values ('18300000-0000-0000-0000-0000000000d1', '18300000-0000-0000-0000-000000000001', 'person', 'Customer');
   insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
       ('18300000-0000-0000-0000-0000000000b1', '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-00000000000a',
        '18300000-0000-0000-0000-00000000000b', '18300000-0000-0000-0000-0000000000d1', 'confirmed', 'Trip', 'BR-ENTRY183-1',
        '18300000-0000-0000-0000-000000000011'),
       ('18300000-0000-0000-0000-0000000000b2', '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-00000000000a',
        '18300000-0000-0000-0000-00000000000b', '18300000-0000-0000-0000-0000000000d1', 'draft', 'EmpTrip', 'BR-ENTRY183-2',
        '18300000-0000-0000-0000-000000000013');
   insert into public.suppliers (id, tenant_id, name, supplier_type_code)
   values ('18300000-0000-0000-0000-0000000000e1', '18300000-0000-0000-0000-000000000001', 'Air', 'airline');
   insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code)
   values ('18300000-0000-0000-0000-0000000000f1', '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000b1',
           '18300000-0000-0000-0000-0000000000e1', 'flight_ticket', 'USD', 400, 500, 'confirmed');
   insert into public.exchange_rates (id, tenant_id, from_currency_code, to_currency_code, rate, effective_at) values
       ('18300000-0000-0000-0000-0000000000ea', '18300000-0000-0000-0000-000000000001', 'USD', 'EGP', 48.0, now() - interval '2 days'),
       ('18300000-0000-0000-0000-0000000000eb', '18300000-0000-0000-0000-000000000001', 'USD', 'EGP', 49.5, now() - interval '1 day');

   -- One entry shape per ARCH-2 surface the employee can create: %1 id, %2 is_archived, %3 reason,
   -- %4 archived_at, %5 archived_by.
   create temporary table entry_cases (surface text primary key, statement text not null);
   insert into entry_cases values
       ('booking_items', $sql$insert into public.booking_items
           (id, tenant_id, booking_id, service_type_code, currency_code, base_status_code, owner_user_id,
            is_archived, archive_reason, archived_at, archived_by)
           values (%1$L, '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000b2', 'flight_ticket',
            'USD', 'draft', '18300000-0000-0000-0000-000000000013', %2$L, %3$L, %4$L, %5$L)$sql$),
       ('leads', $sql$insert into public.leads
           (id, tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title,
            is_archived, archive_reason, archived_at, archived_by)
           values (%1$L, '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-00000000000a',
            '18300000-0000-0000-0000-00000000000b', 'direct_call', 'new', 'Entry lead', %2$L, %3$L, %4$L, %5$L)$sql$),
       ('quotations', $sql$insert into public.quotations
           (id, tenant_id, customer_id, owner_user_id, quotation_status_code, quotation_number, currency_code,
            is_archived, archive_reason, archived_at, archived_by)
           values (%1$L, '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000d1',
            '18300000-0000-0000-0000-000000000013', 'draft', 'Q-' || %1$L, 'EGP', %2$L, %3$L, %4$L, %5$L)$sql$);
   grant select on entry_cases to authenticated;

   -- ENTRY-1 cases: each is an entry the RPC door never writes.
   create temporary table item_entry_cases (label text primary key, cols text not null, vals text not null);
   insert into item_entry_cases values
       ('born in_progress past a finance gate', 'base_status_code, finance_approval_required', $v$'in_progress', true$v$),
       ('born completed and backdated',         'base_status_code, completed_at',              $v$'completed', now() - interval '400 days'$v$),
       ('draft with a completion stamp',        'base_status_code, completed_at',              $v$'draft', now()$v$),
       ('draft with a cancellation stamp',      'base_status_code, cancelled_at',              $v$'draft', now()$v$),
       ('draft with a no-show stamp',           'base_status_code, no_show_at',                $v$'draft', now()$v$);
   grant select on item_entry_cases to authenticated;

   set local role authenticated;

   -- ARCH-2: the employee holds create but not archive authority.
   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a3","aal":"aal1"}', true);
   select ok(app.has_permission('CREATE_LEAD') and app.has_permission('CREATE_QUOTATION')
             and app.has_permission('CREATE_BOOKING_ITEM') and not app.has_permission('ARCHIVE_RECORD'),
             'employee creates leads, quotations and booking items without archive authority');
   select throws_ok(format(statement, '18300000-0000-0000-0000-000000000101', true, 'x', null, null),
                    '42501', 'permission denied: ARCHIVE_RECORD',
                    surface || ': creating archived requires archive authority') from entry_cases order by surface;
   select throws_ok(format(statement, '18300000-0000-0000-0000-000000000102', false, null, now(),
                           '18300000-0000-0000-0000-000000000011'),
                    '42501', 'archive metadata is set by the server',
                    surface || ': an active row cannot claim a forged archiver') from entry_cases order by surface;
   select lives_ok(format(statement, '18300000-0000-0000-0000-000000000103', false, null, null, null),
                   surface || ': ordinary creation still succeeds') from entry_cases order by surface;

   -- ARCH-2 invoices: a finance user who holds archive authority still cannot author the stamp.
   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select throws_ok($$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code, archived_by)
                      values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000d1', 'INV-183-A', current_date, 'EGP', 10, 'draft',
                              '18300000-0000-0000-0000-000000000011')$$,
                    '42501', 'archive metadata is set by the server', 'invoices: an active row cannot claim a forged archiver');
   select lives_ok($$insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code, is_archived, archived_by, archived_at)
                     values ('18300000-0000-0000-0000-000000000201', '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000d1', 'INV-183-B',
                             current_date, 'EGP', 10, 'draft', true, '18300000-0000-0000-0000-000000000011', now() - interval '1 year')$$,
                   'invoices: an authorized archived creation is accepted');

   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select lives_ok(format(statement, '18300000-0000-0000-0000-000000000104', true, 'approved', '2020-01-01',
                          '18300000-0000-0000-0000-000000000013'),
                   'leads: an archive holder may create archived with a reason')
   from entry_cases where surface = 'leads';
   reset role;

   select results_eq(
       $$select archived_by, archived_at = now() from public.invoices where id = '18300000-0000-0000-0000-000000000201'$$,
       $$values ('18300000-0000-0000-0000-000000000012'::uuid, true)$$,
       'invoices: the archiver and time come from the server, not the forged and backdated input');
   select results_eq(
       $$select is_archived, archive_reason, archived_by, archived_at = now() from public.leads where id = '18300000-0000-0000-0000-000000000104'$$,
       $$values (true, 'approved'::text, '18300000-0000-0000-0000-000000000011'::uuid, true)$$,
       'leads: the archiver and time come from the server');

   set local role authenticated;

   -- STEPUP-1: the write costs the permission the table's RLS already demands, plus the role's MFA.
   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
   select throws_ok($$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks, revenue_amount)
                      values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000cc', date '2026-08-02', 1, 'EGP', 1, 1, 999999)$$,
                    '42501', 'multi-factor authentication required for this role', 'campaign_daily_metrics: insert at aal1 needs step-up');
   select throws_ok($$update public.campaign_daily_metrics set spend_amount = 0, revenue_amount = 5000000
                      where id = '18300000-0000-0000-0000-0000000000dd'$$,
                    '42501', 'multi-factor authentication required for this role', 'campaign_daily_metrics: update at aal1 needs step-up');
   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select lives_ok($$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks, revenue_amount)
                     values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000cc', date '2026-08-03', 1, 'EGP', 1, 1, 2)$$,
                   'campaign_daily_metrics: insert at aal2 succeeds');
   select lives_ok($$update public.campaign_daily_metrics set clicks = 6 where id = '18300000-0000-0000-0000-0000000000dd'$$,
                   'campaign_daily_metrics: update at aal2 succeeds');
   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
   select throws_ok($$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks, revenue_amount)
                      values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000cc', date '2026-08-04', 1, 'EGP', 1, 1, 2)$$,
                    '42501', null, 'campaign_daily_metrics: a non-holder is refused');

   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
   select throws_ok($$insert into public.exchange_rate_adjustments (tenant_id, booking_item_id, original_exchange_rate_id, new_exchange_rate_id, reason_code, reason_text)
                      values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000f1', '18300000-0000-0000-0000-0000000000ea',
                              '18300000-0000-0000-0000-0000000000eb', 'incorrect_rate', 'aal1 pin')$$,
                    '42501', 'multi-factor authentication required for this role', 'exchange_rate_adjustments: insert at aal1 needs step-up');
   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select lives_ok($$insert into public.exchange_rate_adjustments (tenant_id, booking_item_id, original_exchange_rate_id, new_exchange_rate_id, reason_code, reason_text)
                     values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000f1', '18300000-0000-0000-0000-0000000000ea',
                             '18300000-0000-0000-0000-0000000000eb', 'incorrect_rate', 'stepped up')$$,
                   'exchange_rate_adjustments: insert at aal2 succeeds');

   -- ENTRY-1: a signed-in caller creates a booking item only at 'draft' with no lifecycle stamp.
   select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a3","aal":"aal1"}', true);
   select throws_ok(format($f$insert into public.booking_items (tenant_id, booking_id, service_type_code, currency_code, owner_user_id, %s)
                             values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000b2', 'flight_ticket', 'USD',
                                     '18300000-0000-0000-0000-000000000013', %s)$f$, cols, vals),
                    '23514', 'a booking item is created at ''draft'' with no lifecycle stamp (canon 26); use app.advance_booking_item to move it',
                    'booking_items: ' || label || ' is refused') from item_entry_cases order by label;
   select lives_ok($$select app.create_booking_item('18300000-0000-0000-0000-0000000000b2', 'flight_ticket', 'USD', 0, 0, null, null, false)$$,
                   'booking_items: the RPC door still creates the draft item');
   reset role;

   select set_config('request.jwt.claims', '', true);
   select lives_ok($$insert into public.booking_items (tenant_id, booking_id, service_type_code, currency_code, base_status_code)
                     values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000b1', 'flight_ticket', 'USD', 'in_progress')$$,
                   'booking_items: session-less platform paths stay exempt');

   select results_eq(
       $$select c.relname::text collate "default", t.tgname::text collate "default", (t.tgtype & 4) <> 0, (t.tgtype & 16) <> 0
         from pg_trigger t join pg_class c on c.oid = t.tgrelid
         where not t.tgisinternal
           and t.tgname in ('leads_enforce_archive_authority', 'quotations_enforce_archive_authority',
                            'booking_items_enforce_archive_authority', 'invoices_enforce_archive_authority',
                            'campaign_daily_metrics_guard_write_capability',
                            'exchange_rate_adjustments_guard_write_capability', 'booking_items_guard_entry_state')
         order by 1, 2$$,
       $$values ('booking_items', 'booking_items_enforce_archive_authority', true, true),
                ('booking_items', 'booking_items_guard_entry_state', true, false),
                ('campaign_daily_metrics', 'campaign_daily_metrics_guard_write_capability', true, true),
                ('exchange_rate_adjustments', 'exchange_rate_adjustments_guard_write_capability', true, true),
                ('invoices', 'invoices_enforce_archive_authority', true, true),
                ('leads', 'leads_enforce_archive_authority', true, true),
                ('quotations', 'quotations_enforce_archive_authority', true, true)$$,
       'each door is attached at INSERT, and the archive and step-up doors also at UPDATE');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is d11dea50c36e8dcc1e418251125358ad0377e87b.

5. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Recorded exception, 2026-11-20, CRM exit bundle A`; if so record Already Applied when its Git blob is 079320e6ea2875ccc83347b46803f146817da1a6, and otherwise stop and report. Otherwise make exactly this one edit (the current owner-authorized grouped selection), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   **Recorded exception, 2026-11-19, CRM archive at entry.** After CRM SPEC-318 Remote Certify at `243fd86c53715a4eb69f02e97353cfa2ad90ea8e`, the owner authorized one consolidated repair and continuous native execution because the selector has zero unrecorded surfaces. SPEC-319 selects the bookings, passengers, suppliers and tasks members of ARCH-2, which share the archive authority, and the active-row archive metadata check on the existing customers binding. Test 182 proves each selected effect on one isolated schema. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-20, CRM exit bundle A.** After CRM SPEC-322 Remote Certify at `73b02a1ac820683846a7566c88d5704bf3171884`, the owner's 2026-11-20 directive authorized grouping items that share evidence, tests and a release boundary while keeping per-item acceptance. SPEC-323 selects the leads, quotations, booking items and invoices members of ARCH-2, the booking-item member of ENTRY-1 and the campaign_daily_metrics and exchange_rate_adjustments members of STEPUP-1, which share the table-door write boundary. Test 183 proves each selected effect on one isolated schema. Campaign entry, CAMP-2 and JE-2 keep their own triggers. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```

   The resulting file's Git blob is 079320e6ea2875ccc83347b46803f146817da1a6.

6. **Regenerate the exact API contract.** After the Original carries Steps 1–5 and the local CRM stack is rebuilt with the exact new migration, run the repository API generator from that state. The resulting Git blob must be 24cbab925f5b30f88cb174fa9acae950e9fcc785. Accept only the campaign_daily_metrics and exchange_rate_adjustments guard-row changes. The script and all other rows stay pinned. In a stack-free isolated rehearsal this step is deferred to Original DATABASE readiness.

7. **Establish readiness and the exact Primary preflight.** Run the native DATABASE readiness, including full SQL tests, HTTP and smoke, API generation and Git blob comparison. Verify 275 migrations, latest `20261121100000`, fingerprint `5213d0d035d53e635a839f0ce9bb7693`, 183 files and 3409 assertions. Compare the catalog against the isolated evidence. Verify four re-attached archive bindings, two new capability bindings, the booking-item entry trigger, unchanged archive authority body and ACL, and the expected function and trigger differences with all other parity signatures stable. Read live Primary project `vrvtsxexkiiiivlkdxzp`: require 274 migrations, latest `20261120122927`, fingerprint `67a6f9f8b5454c75d09b62a8f748c20d`, absent target and certified Primary parity. Preserve scoped baseline row counts, fresh lock evidence and the native exact-DDL and recovery prerequisites. Verify the tracked file Git blob, SHA-256 and the MD5 received by the intended connected Primary route.

   While these measurements agree, update only the manifest Live state on the uncommitted tree to the following:

   ```text
   Live state: SPEC-323 pre-deploy verification. **Repository and local stack at 275 migrations** (latest `20261121100000`), ledger `5213d0d035d53e635a839f0ce9bb7693`. **Platinum Primary `vrvtsxexkiiiivlkdxzp` verified separately at 274 migrations**, with the target absent. Structural parity awaits Gate 2. **80 client RPCs**. Suite **183 files / 3409 assertions**.
   ```

   Require the unchanged consistency guard to report only the missing exact Primary row under RECOVER-1. In the isolated Sandbox, use native Approve and literal replay and check only this expected refusal. The real implementation commit and DONE belong after Primary readback, parity and record updates.

8. **Apply the exact migration once after Gate 2 with separately recorded current authority.** Use the authorized CRM Platinum Primary path for `vrvtsxexkiiiivlkdxzp`. Reconfirm project, baseline, raw file MD5, active Draft, lock window and recovery readiness immediately before the write. Afterward verify one expected ledger row, the seven trigger bindings, the two function definitions, catalog fingerprints and scoped row counts. If the connector allocates a temporary ledger version, reconcile only that exact row in a guarded transaction once the stored migration statement digest and intended version absence are proven. On error or ambiguity preserve the actual database state and follow the native RECOVER-1 decision; no blind retry. A reversal requires a separately authorized corrective migration restoring the prior function and trigger definitions.

9. **Record verified closure and resolve RECOVER-1.** From actual live Primary and local evidence, record ordered ledger and all ten parity surfaces, replace the interim Live state with the literal native fields `full-function-surface hash` and `structural-surface hash` carrying the matched hashes, retain suite count and regenerate discovery. In the gap register, with readback evidence, record ARCH-2 resolved for its last four members, ENTRY-1 resolved with the booking-item member closed and the campaign member assessed without material consequence, and STEPUP-1 resolved for its B6-EXIT members with the remaining candidates kept at their recorded status. CAMP-2, CAMP-4 and JE-2 keep their own statuses. In the action registry, move the CAMP-2 row and the marketing_campaigns surface row from B6-EXIT to the existing `OWN-TRIGGER`, citing CAMP-2's first-reproduced-harm trigger, and update the ARCH-2, ENTRY-1 and STEPUP-1 evidence. In the disposition, mark booking_items AUDITED because BOOK-8/9 are resolved, keep quotations PARTIAL with its archive axis updated, and add the proof to leads, invoices, campaign_daily_metrics and exchange_rate_adjustments with all other statuses intact. Close the Docker `tcp://localhost:2375` backlog item, which shares the B6-EXIT boundary, only on a fresh live measurement on this workstation: Docker Desktop `ExposeDockerAPIOnTCP2375` is false, no socket listens on port 2375, TCP connections to 127.0.0.1:2375 and [::1]:2375 do not connect, and this contract's local stack, smoke and HTTP evidence ran over the named pipe. Then remove that row from the Live deferred items table and begin the first cell of the older Recommended row with `~~Disable Docker tcp://localhost:2375~~ **DONE** (SPEC-323): the setting is off and nothing listens on port 2375`, with the measured time. If any measurement differs, keep the row and record the difference. The native registry must report only the expected B6-EXIT reduction, without changing exit criteria or unrelated triggers. Require repository consistency and parity evidence PASS before Runtime Checkpoint DONE and the implementation commit.

10. **Verify and release through the native lifecycle.** Run timed and watched Finish, independent Review, Complete and bind with exact evidence. Set `Last Completed: **SPEC-323: Entry and step-up hold at the table door.**`, clear the active pointer, regenerate discovery and bind the exact candidate. Publish, hosted preflight, Promote, main checks and Remote Certify use separate native exact-candidate records and the current delegated authority.

## Acceptance Criteria

- [ ] Exact migration reuses the archive authority, capability guard and entry shape at six tables. `check: blob supabase/migrations/20261121100000_entry_and_step_up_hold_at_the_table_door.sql fc317dda36df2d5540bad2ba6afcabbf9d2e8867`
- [ ] Test 58 retains exact shared guard membership. `check: blob supabase/tests/58_write_grants_and_config_capability_test.sql 68f4e874e55af952e5e2e8034dd334e347ea935c`
- [ ] Test 101 records the guard as the tables' own door. `check: blob supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql 2b86d7be04a4a337d387ff60da68789caa9c9ca6`
- [ ] Test 183 proves every selected effect, its authorized path and its exemption. `check: blob supabase/tests/183_entry_and_step_up_hold_at_the_table_door_test.sql d11dea50c36e8dcc1e418251125358ad0377e87b`
- [ ] The recorded grouped selection is exact. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 079320e6ea2875ccc83347b46803f146817da1a6`
- [ ] The generated API reports only the two expected guard-row changes. `check: blob reports/master/MASTER_API_CONTRACT.md 24cbab925f5b30f88cb174fa9acae950e9fcc785`
- [ ] Native selection stays intact. `check: same scripts/batch6_select_target.ps1 @73b02a1ac820683846a7566c88d5704bf3171884`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **183 files / 3409 assertions**"`
- [ ] The Docker 2375 item closes on live evidence. `check: has reports/future-backlog.md "**DONE** (SPEC-323): the setting is off and nothing listens on port 2375"`
- [ ] Verified Primary and local ledger and all ten surfaces agree. ARCH-2, ENTRY-1 and STEPUP-1 close per item with evidence; CAMP-2, CAMP-4, JE-2 and the remaining candidates keep their recorded triggers.

## Execution Log

None.

## Verification Notes

None.


### 2026-11-21 — Gate 1 approval recorded

Owner directly approved CRM SPEC-323 r2 Original Gate 1 for exact Draft SHA-256 715D4EC55BFE9EB06B05CFF1C777BB03D3A2268E1FFFC097F9D5CF3C7546C558 at baseline 73b02a1 on 2026-11-21, with run-through authority through Finish including the Step 8 CRM Primary deploy of these exact bytes, in owner words owner-2026-11-21-spec323-r2-run-through.txt (SHA-256 08DE33D40732E759739D6B747D6B22A3FB346772E2DAEBA593A0D9EDE06E59E9). The current instruction sets Batch 6 PLAN section 2 Mode 2. Native sandbox approval 665fdef9ae5bd848d2ce9173a9918db8dbae2148 passed. This record is Gate 1 only. Gate 2 is separate and depends on the exact artifact, current target, readiness and recovery. Immediately before allocation the hash, the Draft blob 774ac33253d029daebbb8a8409567959845bc577, all 3 source anchors, the baseline HEAD 73b02a1ac820683846a7566c88d5704bf3171884 against refreshed origin/main 73b02a1ac820683846a7566c88d5704bf3171884 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as c818f22. No implementation performed before this transition.

## Review Gate

- [ ] Exact approved payload and allowed scope.
- [ ] Isolated causal negatives and native SQL, smoke, HTTP and API evidence.
- [ ] Verified Primary identity, ledger, parity and per-item registry changes.
- [ ] Existing open items and governance gates retained.

## Notes

Baseline: 73b02a1ac820683846a7566c88d5704bf3171884.

Owner authority: Workbench `data/records/batch6/owner-words/owner-2026-11-20-batch-more-work-directive.txt`, SHA-256 `383D3198EBC1E7E0B46CE19945B0FBF35A062A5A74B3AF0792DEE13EB6734840`. Grouping keeps per-item acceptance, and native Gate 1 and Gate 2 remain. This Draft conveys no Original, deployment or release approval.

Isolated proof: Workbench `data/records/batch6/exit-bundle-a/` `RECHECK.md`, `repro*-73b02a1.log`, `prototype-pgtap.log`, `prototype-smoke.log`, `prototype-http.log`, `prototype-api.md`, `prototype-catalog.log`, `prototype-parity.log`, `primary-preflight-read.log` and `docker-2375-evidence.log`.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/58_write_grants_and_config_capability_test.sql` | `0b044df1bc6fc9e9e8387b0ba8f583c17bf1ff5c` |
| `supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql` | `9d5f3784082bac2db3f047701c49116c76bb1d74` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `5c33d781bb9b41f3a908036aca95036b663040eb` |
