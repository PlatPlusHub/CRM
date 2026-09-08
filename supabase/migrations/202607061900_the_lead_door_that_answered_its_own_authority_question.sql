-- Batch 6 slice 9 -- `leads`, the highest-exposure surface on the repaired selector, and the door
-- that let the attacking statement answer the question that authorized it.
--
-- ================================================================================================
-- THE INHERITED QUESTION, AND WHY ITS ANSWER WAS INCOMPLETE
--
-- Slice 8's sibling sweep left this recorded as a VERIFIED NON-DEFECT: `app.enforce_status_transition`
-- authorizes a `leads` transition with `app.require_lead_handler((to_jsonb(new) ->> 'assigned_user_id'))`,
-- and seizing plus transitioning in one statement was "refused 23514 by
-- `leads_owner_matches_assignee_chk`". That measurement was real but it was made with ONE column in
-- the SET list. Re-run with the pair the constraint actually couples --
--
--     update public.leads
--        set assigned_user_id = <me>, owner_user_id = <me>, lead_status_code = 'qualified'
--      where id = <a colleague's lead>;
--
-- -- the CHECK is satisfied, and the refusal comes from somewhere else entirely: **23514 from
-- `app.require_assignment_history`**, a trigger whose stated purpose is canon 04's timeline
-- completeness ("every assignment must remain visible in the lead timeline"). So the attack fails
-- today, and NEITHER of the two mechanisms that refuse it is the authorization model:
--
--   * `leads_owner_matches_assignee_chk` is a coherence constraint about two columns agreeing.
--   * `require_assignment_history` is an INTEGRITY control about history existing. It never asks who
--     the actor is or what they hold; it refuses the seize only because writing `lead_assignments`
--     is capability-gated somewhere else.
--
-- **INCIDENTAL DEFENSE is not INTENTIONAL CONTROL.** "The attack currently fails" and "the intended
-- authorization invariant is enforced" are different claims, and this surface is where they came
-- apart. Proven by mutation rather than argued: inside a transaction, with BOTH the constraint and
-- the history trigger removed, an `employee` who holds neither ASSIGN_LEAD nor REASSIGN_LEAD seized
-- a colleague's lead AND transitioned it in one statement, and every guard on the table returned
-- NEW. Restored, re-run, refused again.
--
-- ================================================================================================
-- LEAD-1 -- BOOK-5'S SHAPE, THIRD OCCURRENCE, AND THIS TIME THE BYPASS IS TOTAL
--
-- `app.guard_write_capability` carries a relationship shortcut for this one table:
--
--     if tg_op = 'UPDATE' and tg_table_name = 'leads' then
--         v_relationship_ok := app.current_user_id() in (NEW.assigned_user_id, NEW.owner_user_id);
--     end if;
--     if v_relationship_ok then return new; end if;   -- the whole capability check, skipped
--
-- `assigned_user_id` and `owner_user_id` are columns the attacking statement SUPPLIES. Naming
-- yourself in the SET list therefore answers the question "are you the handler?" -- and the answer
-- does not merely authorize the assignment change, it returns NEW before any permission,
-- `app.authorize` call or MFA check is reached, for EVERY column in the same statement.
--
-- This is the sixth adversarial-loop rule for the third time -- BOOK-5 on `booking_items`
-- (`set owner_user_id = <me>, cost_amount = 555`), LI-1 on `lead_interactions`
-- (`set lead_id = <my lead>`), and now `set assigned_user_id = <me>` here. The standing question is
-- *does the predicate read `new` to decide AUTHORITY, or only to validate CONTENT?* -- and the
-- distinction it draws is exactly the one this migration applies: **content validation** asks
-- whether the new value is legal; **authority validation** asks whether this actor was allowed to
-- cause the change. Only the second may not be sourced from the attacker's own image.
--
-- THE REPAIR IS TWO CLAUSES, AND NEITHER INVENTS A RULE:
--
--   1. The relationship shortcut is decided from the **OLD** image. You may edit a lead without a
--      permission because you ALREADY handle it -- not because you just wrote your name on it.
--
--   2. Moving the assignment costs **ASSIGN_LEAD or REASSIGN_LEAD**. Copied verbatim from
--      `app.assign_lead` (`perform app.authorize('ASSIGN_LEAD')`) and `app.reassign_lead`
--      (`perform app.authorize('REASSIGN_LEAD')`) -- the two RPCs that exist to do this. It
--      REPLACES rather than appends, the `suppliers`/CUST-5 shape rather than the `customers` one,
--      because the containment runs the safe way: every role holding either key (owner, ceo,
--      branch_manager, department_manager) also holds CREATE_LEAD, so no legitimate path loses a
--      door. `employee`, `senior_employee` and `trainee` hold neither, which is the whole point.
--
-- MEASURED AFTER THE REPAIR, with both incidental defences still removed: the seize is refused
-- **42501 -- "one of ASSIGN_LEAD or REASSIGN_LEAD is required to write leads"**, from the
-- authorization model itself. The guard now stands alone, which is what "intentional control" means.
--
-- `app.enforce_status_transition`'s `leads` fallback is corrected in the same breath, from
-- `to_jsonb(new)` to `to_jsonb(old)`. It is defence in depth rather than a second hole -- it fires
-- BEFORE `guard_write_capability` in trigger-name order, so a forged NEW image walked past it and
-- was caught one trigger later -- but reading OLD is also simply what the rule's three cited sources
-- do: `app.advance_lead`, `app.convert_lead` and `app.record_lead_interaction` all resolve
-- `v_assigned` by SELECTing the EXISTING row before deciding anything.
--
-- ================================================================================================
-- LEAD-2 / LEAD-3 / LEAD-4 -- THE STATE MACHINE GUARDS ITS EDGES AND NOT ITS PRECONDITIONS
--
-- `app.enforce_status_transition` is BEFORE **UPDATE**, and it validates one thing: that the edge
-- old -> new exists in `app.status_transitions`. Everything else canon 26 says about a lead's
-- lifecycle lives inside the RPCs, so the table door -- which `authenticated` reaches directly
-- through PostgREST -- enforces none of it. Three reproductions, all as a role that holds CREATE_LEAD:
--
--   LEAD-2  A lead can be BORN in any status. `app.create_lead` hardcodes `'new'`; the door accepted
--           `insert into public.leads (..., lead_status_code) values (..., 'won')`. The state machine
--           has no entry arm, so its graph is enforced only for leads that entered through it.
--
--   LEAD-3  `won -> converted` is a registered edge with a NULL `permission_key`, so the handler
--           fallback passes it. `app.convert_lead` refuses without a customer ("no customer to
--           convert to; link or create a customer first") and sets `customer_id`,
--           `closure_reason_code = 'converted_customer'` and `closed_at` in the same statement. At
--           the door the handler produced `lead_status_code = 'converted'` with `customer_id` NULL
--           and no closure reason: a converted lead that converted to nobody.
--
--   LEAD-4  `assigned -> contacted` is the one edge NO RPC offers. `app.advance_lead` excludes it by
--           name -- "owned by other RPCs" -- and refuses it (`transition not allowed: assigned ->
--           contacted`); its only sanctioned producer is `app.record_lead_interaction`, as a
--           CONSEQUENCE of a qualifying interaction. At the door the handler flipped their own lead
--           to `contacted` with zero interactions logged and `last_contact_at` still NULL. That is
--           not cosmetic: `app.process_lead_sla` scans `where l.lead_status_code = 'assigned'`, so
--           the flip removes the lead from SLA supervision entirely -- a one-statement, no-evidence
--           escape from the escalation canon 10 requires.
--
-- THE CORRECTION LEAD-4 ALSO FORCES ON A REGISTERED FINDING: LI-3's evidence says
-- "`app.process_lead_sla` escalates on `last_contact_at`". **It does not.** Measured: no function,
-- view or policy in this database reads `leads.last_contact_at` at all -- the SLA loop derives its
-- window from `lead_assignments.assigned_at` and its idempotency from the `events` ledger, and a
-- lead leaves the working set by changing STATUS. LI-3's conclusion survives (its direction is still
-- conservative, and it stays open); the mechanism it names is wrong and is corrected in the register.
-- Naming a column as the driver of an invariant that does not depend on it is PROXY-TO-INVARIANT
-- CONFUSION, the seventh rule, found this time in the register's own evidence.
--
-- THE REPAIR: one guard, three rules, each copied from the RPC that already states it. It does NOT
-- answer LI-3's open question. LI-3 asks whether a bare INSERT into `lead_interactions` should
-- ADVANCE the lifecycle; this asks only that the evidence exist before the lifecycle claims it did.
-- A handler who logs a real `phone_call` at the door and then marks the lead `contacted` is
-- permitted here exactly as before -- what is refused is the status with no contact behind it.
--
-- LEAD-3 is a CHECK CONSTRAINT rather than a line in the guard, deliberately. "A converted lead has
-- a customer" is a pure data invariant with no session in it, so it binds the platform paths too --
-- seeds, migrations, `service_role` and any future importer -- where every trigger guard here
-- exempts them by canon 35 principle 6. The cheapest correct enforcement layer is the one that
-- cannot be reached around.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- LEAD-1a. The relationship shortcut reads OLD; moving the assignment costs the assignment keys.
-- Body identical to `202607060600` apart from the `leads` block marked below.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_write_capability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
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
                   when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                   when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
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
$$;

-- ------------------------------------------------------------------------------------------------
-- LEAD-1b. The transition fallback asks who handles the lead NOW, which is what its three cited
-- sources do. Body identical to `202607059300` apart from the one marked line.
-- ------------------------------------------------------------------------------------------------
create or replace function app.enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_column text := tg_argv[0];
    v_old text;
    v_new text;
    v_permission text;
    v_found boolean;
begin
    -- Platform paths (service_role, migrations, seeds) are outside per-table enforcement -- canon 35
    -- principle 6. A tenant user cannot reach a row without a resolved identity, so this cannot be
    -- used to escape the guard.
    if (select auth.uid()) is null then
        return new;
    end if;

    v_old := to_jsonb(old) ->> v_column;
    v_new := to_jsonb(new) ->> v_column;

    if v_new is not distinct from v_old then
        return new;
    end if;

    select st.permission_key, true
      into v_permission, v_found
    from app.status_transitions st
    where st.table_name = tg_table_name
      and st.from_status = v_old
      and st.to_status = v_new;

    if not coalesce(v_found, false) then
        raise exception
            '% is not a permitted transition for %.% (canon 26 state machine); use the app.advance_* RPC',
            coalesce(v_old, '(null)') || ' -> ' || coalesce(v_new, '(null)'), tg_table_name, v_column
            using errcode = '23514';
    end if;

    if v_permission is not null then
        perform app.authorize(v_permission);
    elsif tg_table_name = 'leads' then
        -- TRANS-2. `permission_key` cannot express "the assigned handler", so these rows are null --
        -- and null used to mean no check at all. The rule is not invented here: it is copied from
        -- app.advance_lead, app.convert_lead and app.record_lead_interaction, which all state it.
        -- `to_jsonb` rather than `old.assigned_user_id` because plpgsql binds every OLD field named
        -- in a generic trigger regardless of which branch runs (the SPEC-159-A hazard).
        --
        -- LEAD-1b (202607061900): `old`, not `new`. All three cited RPCs resolve the assignee by
        -- SELECTing the EXISTING row; reading `new` let a caller who named themselves in the same
        -- statement authorize their own transition (BOOK-5's standing question).
        perform app.require_lead_handler((to_jsonb(old) ->> 'assigned_user_id')::uuid);
    else
        -- Fail closed. A transition with no permission and no named fallback is an unguarded write
        -- path, and returning NEW here is exactly how the eight leads rows stayed invisible.
        raise exception
            'transition %.% % -> % has no permission_key and no fallback authority rule',
            tg_table_name, v_column, v_old, v_new
            using errcode = '42501';
    end if;

    return new;
end;
$$;

-- ------------------------------------------------------------------------------------------------
-- LEAD-2 / LEAD-4. The preconditions the state machine's edges never carried.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_lead_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Platform/system paths (canon 35 principle 6): seeds, migrations, `service_role` and the
    -- session-less jobs build lead state directly and are outside per-table enforcement.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- LEAD-2. A lead enters the pipeline at `new`. Not invented: `app.create_lead` is the only
    -- sanctioned writer and hardcodes it, and canon 26 makes `new` the initial state. Without this
    -- the transition graph is enforced only for leads that entered through the graph.
    if tg_op = 'INSERT' and new.lead_status_code is distinct from 'new' then
        raise exception
            'a lead enters the pipeline at ''new'' (canon 26); it was created as ''%'' -- use '
            'app.assign_lead / app.advance_lead / app.convert_lead to move it',
            new.lead_status_code
            using errcode = '23514';
    end if;

    -- LEAD-4. `assigned -> contacted` is CAUSED, not chosen. It is the one edge no RPC offers:
    -- `app.advance_lead` refuses it by name, and `app.record_lead_interaction` produces it only as a
    -- consequence of a qualifying interaction. Flipping it by hand takes the lead out of
    -- `app.process_lead_sla`'s working set (it scans `lead_status_code = 'assigned'`) with no
    -- evidence of contact anywhere.
    --
    -- The qualifying set is transcribed from `app.record_lead_interaction`, which took it from
    -- canon 26. This asks only that the evidence EXIST -- it does not decide LI-3's open question of
    -- whether a direct INSERT should itself advance the lifecycle.
    if tg_op = 'UPDATE'
       and old.lead_status_code = 'assigned' and new.lead_status_code = 'contacted'
       and not exists (
           select 1 from public.lead_interactions li
           where li.lead_id = new.id
             and li.tenant_id = new.tenant_id
             and li.interaction_type_code in
                 ('phone_call', 'whatsapp_message', 'chat_opened', 'customer_reply')
       )
    then
        raise exception
            'a lead becomes ''contacted'' by a qualifying interaction, not by assertion (canon 10/26); '
            'use app.record_lead_interaction'
            using errcode = '23514';
    end if;

    return new;
end;
$$;

create trigger leads_guard_lifecycle
before insert or update on public.leads
for each row execute function app.guard_lead_lifecycle();

-- `create function` grants EXECUTE to PUBLIC by default, and a SECURITY DEFINER function reachable
-- by PUBLIC is the SECDEF-1 shape. `create or replace` preserves the existing ACL for the two
-- functions above, but they are re-revoked here so the migration states the posture it leaves rather
-- than relying on what a previous one did. `10_grant_model_test` assertion 5 measures this, and
-- caught the missing revoke on `guard_lead_lifecycle` before this migration was committed.
revoke execute on function app.guard_write_capability() from public;
revoke execute on function app.enforce_status_transition() from public;
revoke execute on function app.guard_lead_lifecycle() from public;

-- ------------------------------------------------------------------------------------------------
-- LEAD-3. A converted lead converted to somebody. `app.convert_lead` refuses without a customer and
-- sets it in the same statement; the door did not. A CHECK rather than a trigger line because this
-- is a data invariant with no session in it -- it binds the platform paths every guard above exempts.
-- ------------------------------------------------------------------------------------------------
alter table public.leads
    add constraint leads_converted_requires_customer_chk
    check (lead_status_code <> 'converted' or customer_id is not null);

comment on constraint leads_converted_requires_customer_chk on public.leads is
    'LEAD-3 (202607061900): app.convert_lead refuses to convert a lead with no customer and links '
    'one in the same statement; the table door let a handler write lead_status_code = ''converted'' '
    'with customer_id NULL. A CHECK because the invariant has no session in it.';

comment on function app.guard_lead_lifecycle() is
    'LEAD-2 / LEAD-4 (202607061900): the lead-lifecycle preconditions that lived only inside the '
    'RPCs. A lead is born ''new'' (app.create_lead hardcodes it), and assigned -> contacted requires '
    'a qualifying interaction to exist (app.record_lead_interaction is its only sanctioned producer, '
    'and the flip otherwise removes the lead from app.process_lead_sla''s working set).';
