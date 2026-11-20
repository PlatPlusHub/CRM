# Change Request — SPEC-320

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Require the same MANAGE_BRANCHES permission and MFA on branch creation and edits through the table as the existing branch RPC. Close BRANCH-1 and only the branch member of STEPUP-1.

## Business Reason

The Batch 6 selector has scanned all 78 surfaces. The Action Registry requires the branch authority work at B6-EXIT. SPEC-226 and Test 130 distinguish BRANCH-1 from the remaining event gap BRANCH-2. The native child-table and campaign authority bindings already use a reusable capability guard. A single new binding and one existing function mapping address BRANCH-1 without a parallel permissions system.

## Risks

CREATE TRIGGER takes a lock on branches. Measure the current lock state before the write. Preserve app.guard_write_capability ownership and ACL, RLS tenant predicates, branch event production, authorized aal2 and session-less system writes. The rollback path is a separately authorized corrective migration to drop the specific binding and restore the previous function definition. Do not rewrite existing business rows.

## Supersedes / Depends On

Depends on SPEC-226, SPEC-222 and the CRM SPEC-319 certified baseline. Supersedes only the assertions in Test 130 that documented the open BRANCH-1 behavior.

## Write Scope

- `changes/SPEC-320-branch-write-authority-matches-the-rpc.md`
- `supabase/migrations/20261120122927_branch_write_authority_matches_the_rpc.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/130_branch_door_audit_test.sql`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/evidence/primary-ledger-evidence.json`
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

All other paths, Founder Secondary, integration activation, UI, branch events, GitHub configuration and other STEPUP-1 members are outside scope.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9; `ENGINEERING_METHOD.md` §§2, 4 and 5.
- `_ORVION_CANONICAL/28_permissions_matrix.md`; native branch RPC in migration `202607049600_identity_event_emission.sql`.
- `reports/master/MASTER_EXECUTION_PLAN.md` action registry; BRANCH-1, BRANCH-2 and STEPUP-1 in the gap register.
- `supabase/tests/58_write_grants_and_config_capability_test.sql` and `supabase/tests/130_branch_door_audit_test.sql`.

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

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Reuse the existing write capability guard through one mapping and one branches trigger. Its child table already uses MANAGE_BRANCHES through the same guard. Preserve permissions and RLS rather than adding a second authority.

Pass 2 Adversarial Review: The certified Test 130 records the current mismatch. The corrected test exercises aal1 denial and checks the unchanged stored row, aal2 allowed writes, tenant isolation, uniqueness and branch RPC behavior. Test 58 checks the shared guard membership. The original count and mapping membership assertions both flagged the deliberate addition and the revised tests passed together.

Pass 3 Evidence Refresh: 2026-11-20. On isolated CRM baseline 21d411b0e642c68b90cec795bbab0c86f27c8bee, the repaired schema has 274 migration rows, ledger fingerprint 67a6f9f8b5454c75d09b62a8f748c20d, one new trigger and unchanged API grants. The generated API contract changes only the branches guard columns. The corrected pgTAP run passed 182 files and 3381 assertions, database smoke passed, and the existing HTTP suite passed 35 assertions on the isolated API through its local container adapter. Primary was separately read at 273 migrations at fingerprint 68c065e6e3a2ea0fe8f5c55277220a0f with the proposed version absent. Recheck live at the deployment boundary.

Selected Version: SPEC-320; selected: one existing branch-class permission and MFA guard, a new branch binding and two aligned test files

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Branch creation and editing | branches, app.create_branch, platform fixtures and existing branch RLS | WRITE | Test 130 proves authorized and denied writes. Tenant RLS remains unchanged. The RPC still produces one branch_created event. |
| Shared capability guard | Existing twenty-eight bindings | VERIFY | The existing function body changes only by adding the branches mapping. Test 58 has the exact membership, and the database regression suite covers the previous bindings. |
| B6-EXIT evidence | BRANCH-1, STEPUP-1 and branches disposition | WRITE | Record BRANCH-1 fixed after hosted proof. STEPUP-1 remains open. The branch surface remains AUDITED-OPEN and follows BRANCH-2's existing enablement boundary after the B6-EXIT branch authority is proven. |
| Contract evidence | Generated API, Primary ledger and structural parity, manifest and discovery | WRITE | Reuse the native generation and evidence methods, with the single expected API contract row change. |
| Audit emission, Founder, integration and frontend | existing authorities and provider workflows | UNAFFECTED | BRANCH-2 stays open at its pre-existing trigger; no new product or integration action. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Platinum Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact approved payload, local functional proof, fresh target identity and recovery evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Recorded ledger reflects the actual Platinum Primary ledger | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| Repository and local figures match the pre-deploy payload | BEFORE_IRREVERSIBLE_ACTION | Step 1 | Step 5 | Step 6 |
| Generated evidence agrees with the deployed structure | BEFORE_COMPLETION | Step 6 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: app.guard_write_capability, app.authorize and the existing branch_business_hours binding charge the same object-class authority and step-up.

Added Property: Branch INSERT and UPDATE by a signed-in actor require the existing MANAGE_BRANCHES permission and required MFA.

Causal Negative: SPEC-226 and certified Test 130 assertions 6–8 establish the baseline branch-table and RPC mismatch.

Positive Test Design: Test 130 requires the authorized role at aal2 to create via the RPC and table and edit through the table. It retains the positive platform fixture and proves one RPC creation event.

Negative Test Design: Test 130 requires SQLSTATE 42501 from the unstepped writes and reads back the original row. It proves tenant scope and permission separately; Test 58 pins trigger membership.

Non-Empty Population Obligation: Test 130 establishes active tenants, branches and actual permission holders before testing the refusal and valid writes, then verifies cross-tenant invisibility.

Mutation Obligation: Test 130 preserves its rollback-only tenant and permission policy mutations; the installed branch binding must match the native catalog and the certified pre-repair evidence must differ in its MFA behavior.

Post-Implementation Proof Obligation: Fresh approved Primary apply and separate readback agree with local ledger and structural fingerprints. Re-run the native consistency and readiness evidence and retain BRANCH-2 and remaining STEPUP-1 obligations.

## Implementation Steps

1. Check whether `supabase/migrations/20261120122927_branch_write_authority_matches_the_rpc.sql` contains `-- BRANCH-1: require the same permission and MFA`; if so record Already Applied when its Git blob is ea92b491bf33a69377921ba84d76daf11abd8770, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the branch capability mapping and trigger migration), and change nothing else:

   ```text
   -- BRANCH-1: require the same permission and MFA for branch table writes and app.create_branch.
   -- Reuse the existing capability trigger, as branch_business_hours does. The current RLS
   -- tenant fence, grants and branch event behavior remain in force. BRANCH-2 is separate.

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

   create trigger branches_guard_write_capability
       before insert or update on public.branches
       for each row execute function app.guard_write_capability();
   ```

   The resulting file's Git blob is ea92b491bf33a69377921ba84d76daf11abd8770.

2. Check whether `supabase/tests/58_write_grants_and_config_capability_test.sql` contains `twenty-nine tables now carry`; if so record Already Applied when its Git blob is 0b044df1bc6fc9e9e8387b0ba8f583c17bf1ff5c, and otherwise stop and report. Otherwise make exactly these 2 edits (the exact guard binding membership), each matched once, and change nothing else:

   a) replace the lines
   ```text
     28,
     'twenty-eight tables now carry the write-capability guard (13 + SEC-1b''s twelve, 202607057000 + booking_item_passengers, PAX-1, 202607061400 + booking_items, BOOK-3, 202607061500 + marketing_campaigns, CAMP-3, SPEC-222)');
   ```
   with
   ```text
     29,
     'twenty-nine tables now carry the write-capability guard (13 + SEC-1b''s twelve, 202607057000 + booking_item_passengers, PAX-1, 202607061400 + booking_items, BOOK-3, 202607061500 + marketing_campaigns, CAMP-3, SPEC-222 + branches, BRANCH-1)');
   ```

   b) replace the line
   ```text
                               'marketing_campaigns')),
   ```
   with
   ```text
                               'marketing_campaigns','branches')),
   ```

   The resulting file's Git blob is 0b044df1bc6fc9e9e8387b0ba8f583c17bf1ff5c.

3. Check whether `supabase/tests/130_branch_door_audit_test.sql` contains `the branch table refuses creation without step-up`; if so record Already Applied when its Git blob is 1100910b9540ce32e32d691bb215f11fa74bdecd, and otherwise stop and report. Otherwise make exactly these 11 edits (the verified branch table and RPC MFA behavior), each matched once, and change nothing else:

   a) replace the lines
   ```text
   -- SPEC-226 / Batch 6 Slice 24. `branches` is audited, not repaired. What holds is pinned to the
   -- control that holds it: tenant placement, tenant relocation and the non-holder are refused by the
   -- `scope_insert` / `scope_update` policies, which is proven by removing each conjunct of the INSERT
   -- policy separately inside a savepoint and watching the matching attack land; DELETE has no grant;
   -- the slug is unique per tenant. What does NOT hold is pinned as OPEN so this file can never be read
   -- as having fixed it: BRANCH-1 (an aal1 owner writes the table the RPC refuses it) and BRANCH-2 (a
   -- direct INSERT records no `branch_created`). Those four assertions (6-8, 19) record a DEFECT that
   -- is still OPEN, NOT a desired invariant: they pass today only because the defect exists, and they
   -- are written to FAIL when their finding is repaired.
   ```
   with
   ```text
   -- SPEC-226 / Batch 6 Slice 24 records the branch audit. BRANCH-1 now requires the same
   -- step-up for table writes, the branch RPC and branch business hours. The capability guard
   -- enforces permission on INSERT independently of RLS. RLS still owns the tenant fence and
   -- UPDATE visibility. DELETE has no grant, and the slug remains unique per tenant.
   -- BRANCH-2 remains open. Assertion 19 records the direct creation event gap at its own gate.
   ```

   b) replace the lines
   ```text
   -- 4-8. AUTH / DOOR. The RPC and the child table charge step-up (desired, held). The table door does
   --      not: 6-8 pin the OPEN defect BRANCH-1, which is NOT desired behaviour.
   ```
   with
   ```text
   -- 4-8. AUTH / DOOR. The branch table, RPC and child table all require step-up.
   --      BRANCH-1 closes only the branch table's authority gap.
   ```

   c) replace the lines
   ```text
     'the child table door refuses the aal1 owner the same capability');
   select lives_ok(
   ```
   with
   ```text
     'the child table door refuses the aal1 owner the same capability');
   select throws_ok(
   ```

   d) replace the lines
   ```text
     'BRANCH-1 is OPEN: the aal1 owner creates a branch through the table (FAILS when BRANCH-1 is repaired)');
   select lives_ok(
   ```
   with
   ```text
     '42501','multi-factor authentication required for this role',
     'the branch table refuses creation without step-up');
   select throws_ok(
   ```

   e) replace the line
   ```text
     'BRANCH-1 is OPEN: the aal1 owner renames, re-slugs and deactivates a branch through the table (FAILS when repaired)');
   ```
   with
   ```text
     '42501','multi-factor authentication required for this role',
     'the branch table refuses edits without step-up');
   ```

   f) replace the lines
   ```text
     array['Hijacked','br130-hijacked','false'],
     '...and the aal1 rewrite persisted');
   update public.branches set name='Main', slug='br130-main', is_active=true where id='13000000-0000-0000-0000-00000000000a';
   ```
   with
   ```text
     array['Main','br130-main','true'],
     'the refused edit preserves the branch row');
   ```

   g) replace the line
   ```text
   -- 20-23. PRIVILEGE: a non-holder at aal2 has its INSERT refused by the policy, and its UPDATE matches
   ```
   with
   ```text
   -- 20-23. PRIVILEGE: the guard refuses INSERT by a non-holder at aal2, and UPDATE matches
   ```

   h) replace the lines
   ```text
       values ('13000000-0000-0000-0000-000000000001','Employee','br130-employee')$$,
     '42501','new row violates row-level security policy for table "branches"',
   ```
   with
   ```text
       values ('13000000-0000-0000-0000-000000000001','Employee','br130-employee')$$,
     '42501','permission denied: one of MANAGE_BRANCHES is required to write branches',
   ```

   i) replace the lines
   ```text
   -- 24-29. Mutation: each conjunct of `scope_insert` is load-bearing. Remove one at a time inside a
   --        savepoint, prove the installed expression changed, prove the attack that conjunct refuses
   --        now lands, then roll back and prove the original expression is back byte for byte.
   ```
   with
   ```text
   -- 24-29. Remove each INSERT policy conjunct in its own savepoint. The capability guard still
   --        refuses an actor without permission. The tenant restriction remains load-bearing.
   --        Roll the changes back and check restoration.
   ```

   j) replace the lines
   ```text
   select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
   select lives_ok(
   ```
   with
   ```text
   select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
   select throws_ok(
   ```

   k) replace the line
   ```text
     'MUTANT 1: the employee''s insert lands, so the permission conjunct is what refused it');
   ```
   with
   ```text
     '42501','permission denied: one of MANAGE_BRANCHES is required to write branches',
     'MUTANT 1: the capability guard still refuses a non-holder');
   ```

   The resulting file's Git blob is 1100910b9540ce32e32d691bb215f11fa74bdecd.

4. **Regenerate the exact API contract.** After the Original is carrying Steps 1–3 and the local CRM stack is rebuilt with the exact new migration, run the repository API generator from that state. The resulting Git blob must be 4c71ef7a47348212c2ce70c8ac30a05ebda80be6. Accept only the branches guard-row change. The script, authority described by other rows and Git baseline stay pinned. In a stack-free isolated rehearsal this step is deferred to Original DATABASE readiness.

5. **Verify the exact local payload and prepare Primary.** On the Original run the native DATABASE readiness against the local CRM stack. Verify 274 migration rows at `20261120122927`, ledger fingerprint `67a6f9f8b5454c75d09b62a8f748c20d`, 182 test files and 3381 assertions. Regenerate the API contract and require the approved blob. Verify the branch trigger is enabled and compare the ten parity sections with the isolated reference. Read the live Platinum Primary ledger for project `vrvtsxexkiiiivlkdxzp`. Require 273 rows, latest `20261119203357`, ledger fingerprint `68c065e6e3a2ea0fe8f5c55277220a0f`, the proposed migration absent and the certified Primary parity. Capture branch row count, lock state and exact payload hashes and confirm the recovery prerequisite. Set only the intermediate manifest Live state to:

   ```text
   Live state: SPEC-320 pre-deploy verification. **Repository and local stack at 274 migrations** (latest `20261120122927`), ledger `67a6f9f8b5454c75d09b62a8f748c20d`. **Platinum Primary `vrvtsxexkiiiivlkdxzp` verified separately at 273 migrations**, with the target absent. Structural parity awaits Gate 2. **80 client RPCs**. Suite **182 files / 3381 assertions**.
   ```

   Require native consistency to show only RECOVER-1 awaiting the exact Primary row before the irreversible step. An isolated rehearsal may use the native Approve and literal replay. Its absence of a new Primary ledger row does not grant deploy authority.

6. **Deploy the exact migration once under native Gate 2.** Confirm current delegated or exact owner authority, target, artifact, baseline, lock state and recovery before applying the already verified bytes through the CRM Primary route. Afterward independently verify exact row and digest, function and trigger, unchanged scoped row count and ten-domain parity. If the connector generates a temporary version, reconcile only that verified ledger row with its recorded statement digest and absence of the intended version. On ambiguous action preserve state and follow RECOVER-1. A rollback that changes hosted schema requires its own corrective migration authority.

7. **Record the verified change and reconcile the registry.** Write the ordered live Primary ledger and parity evidence, match all ten local signatures and update only the related manifest figures and generated discoveries. In the gap register attach the migration and Test 130 evidence to BRANCH-1 and mark it fixed only after readback. Keep STEPUP-1 open for the remaining member proofs. In the disposition keep branches AUDITED-OPEN for BRANCH-2 and update the proof to reference the verified repair, with the other surface statuses intact. In the action registry keep BRANCH-2's existing ENABLE-SURFACE-WORKFLOW trigger and change only the branches surface row's trigger from B6-EXIT to that existing trigger, because its B6-EXIT branch authority is proven. Require the native registry to preserve the other fourteen engineering obligations as due, the branch event obligation at its own trigger and all unrelated criteria. Verify native consistency and RECOVER-1 before setting the checkpoint DONE and making the implementation commit.

8. **Certify and release through the native lifecycle.** Run the timed, watched Finish and independent Review, then Complete, bind, Publish and Promote using current exact records. Use the Last Completed summary **Branch creation and edits enforce permission and MFA**. Verify hosted checks and Remote Certify on the released revision.

## Acceptance Criteria

- [ ] Exact migration reuses the existing capability guard for branch writes. `check: blob supabase/migrations/20261120122927_branch_write_authority_matches_the_rpc.sql ea92b491bf33a69377921ba84d76daf11abd8770`
- [ ] Test 58 retains exact shared guard membership. `check: blob supabase/tests/58_write_grants_and_config_capability_test.sql 0b044df1bc6fc9e9e8387b0ba8f583c17bf1ff5c`
- [ ] Test 130 proves permission and MFA behavior and preserves the existing branch event boundary. `check: blob supabase/tests/130_branch_door_audit_test.sql 1100910b9540ce32e32d691bb215f11fa74bdecd`
- [ ] The generated API reports only the expected branches guard change. `check: blob reports/master/MASTER_API_CONTRACT.md 4c71ef7a47348212c2ce70c8ac30a05ebda80be6`
- [ ] The native Batch 6 selector remains unchanged. `check: same scripts/batch6_select_target.ps1 @21d411b0e642c68b90cec795bbab0c86f27c8bee`
- [ ] The hosted target, ordered ledger and all ten structural parity sections are independently verified. Branch authority is evidenced and the event obligation and remaining class members keep their scopes and triggers.

## Execution Log

None.

### 2026-11-20 — Original implementation

- Steps 1–3 reproduced the three exact frozen Git blobs. Steps 4–5 regenerated the approved API blob 4c71ef7a47348212c2ce70c8ac30a05ebda80be6, changing only the branches row. Two pgTAP passes each ran 182 files and 3381 assertions. HTTP ran 35 assertions with exit 0. Database smoke and local parity passed. Native pre-deploy consistency reported only the exact pending migration under RECOVER-1.
- Step 6 used the separate DEC-25 Gate 2 record for one apply to Platinum Primary vrvtsxexkiiiivlkdxzp. SQL SHA-256 4ABC64F420ABC6EA35AC6F59571FB4F423DBDE93729A5DF4193E82061344CBB5 and MD5 4c710c23130d618cec77a5ffb3e368eb match the approved payload and stored statement. The verified temporary ledger version 20261120142616 was reconciled to 20261120122927 under the one-row guard. Final readback proved the 274 ordered entries, ledger 67a6f9f8b5454c75d09b62a8f748c20d, ten-domain structural parity, enabled branch trigger, expected function identity and ACL, and unchanged branch row count.
- Step 7 refreshed attributable Primary ledger evidence and its parity and registry records. Ledger, parity and consistency verifiers passed. BRANCH-1 is completed. Branches remain AUDITED-OPEN for BRANCH-2 at ENABLE-SURFACE-WORKFLOW. STEPUP-1 remains open and the same other 14 obligations are due at B6-EXIT.
- Step 8 proceeds to the timed and watched Original Finish on this implementation commit, followed by Review, Complete, bind and the native release gates.

## Verification Notes

None.


### 2026-11-20 — Gate 1 approval recorded

Owner approved Original Gate 1 for CRM SPEC-320 and this exact frozen Draft SHA-256 F415D9527F63B393D84A6863A02A1FE1BA59BA5518C0487AC3B634A0BB169A17 in the current directive. Verbatim owner source runtime/OWNER-GATE1-SPEC320.txt SHA-256 5E0E89ECBABBE6B951029A365B7981169ACB259D8EDF04FCAABAE664E0E914C0. Mode 2. Isolated native approval 2f73adebd91de5ece73d0120dbd69ff1391ea95c and verified handoff package 2B28F0C48B86C5C6B8CC216316D959CD18B7C8EFD7A508EBD2FA1B09485550AB. Gate 2 and release retain their exact separate evidence and authority records. Immediately before allocation the hash, the Draft blob a564ea530f8307f55e52c91cc738bdc9d0d2b1c0, all 2 source anchors, the baseline HEAD 21d411b0e642c68b90cec795bbab0c86f27c8bee against refreshed origin/main 21d411b0e642c68b90cec795bbab0c86f27c8bee and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 28c184c. No implementation performed before this transition.

## Review Gate

- [ ] Implementation matches the exact frozen payload.
- [ ] Local authority, native test and generated API proofs match the approved contract.
- [ ] Primary identity, deployed row, recovery and registry evidence hold independently.
- [ ] BRANCH-2 and remaining obligations retain their applicable triggers.

## Notes

Baseline: 21d411b0e642c68b90cec795bbab0c86f27c8bee.

Owner direction: Workbench `data/records/batch6/owner-words/owner-2026-11-20-decision-closure-directive.txt` SHA-256 `9AA38886AA686AAE55AE851FF68BACDB074FB282FD7EC953E803DB90E6D34A0D`. Mode 2 applies inside native authority. This Draft conveys no Original, deployment or release approval.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/58_write_grants_and_config_capability_test.sql` | `3cf87dbf6be695d2b3da79b06216ebf63a2af108` |
| `supabase/tests/130_branch_door_audit_test.sql` | `7ef0d7049ced476e17b5cfaddcb0c9456cc841d7` |
