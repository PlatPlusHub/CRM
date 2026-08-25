-- Migration: lifecycle_transition_enforcement
-- Plan reference: SPEC-149. Makes business-critical lifecycle transitions impossible to bypass with
-- ordinary employee DML.
--
-- THE BYPASS, REPRODUCED BEFORE IT WAS FIXED. An authenticated employee who does NOT hold
-- `ISSUE_BOOKING` ran:
--
--     update public.bookings set booking_status_code = 'issued' where id = ...;
--
-- The booking went from `draft` straight to `issued` -- skipping pending_approval, confirmed and
-- in_progress -- with **zero events emitted**, no authorization, no transition validation and no
-- negative-balance risk check. Every `advance_*` RPC was correct and nothing obliged anyone to call
-- one. That made the state machines decorative on the direct path, which is the largest remaining
-- Foundation defect.
--
-- WHY A REGISTRY AND NOT A SECOND COPY OF THE RULES. The obvious objection to enforcing transitions
-- in a trigger is that it duplicates the maps already inside the RPCs -- a second source of truth
-- that will eventually disagree. That objection is answered the way ORVION already answers it twice
-- over: `07_event_vocabulary_registry_test` and `08_status_vocabulary_registry_test` both scan
-- `pg_proc` for the `values(...) as t(frm, to_s, ...)` blocks the transition RPCs are written with,
-- and fail when a function drifts from the registry. Test 32 does exactly the same for this table.
-- So the rules live in the RPCs, this table mirrors them, and a mechanical guard makes silent
-- divergence impossible. Every row below was extracted from `pg_proc`, not composed by hand.
--
-- WHAT THE TRIGGER DOES NOT DO. It does not re-implement the RPCs. It answers two questions only:
-- is this (from -> to) a transition the business recognises, and does the caller hold the capability
-- that governs it. Side effects -- events, closure reasons, risk flags, cost locking, timestamps --
-- remain the RPC's work, and a direct write still skips them. Direct DML is therefore restricted to
-- *legal, authorized* transitions rather than made equivalent to the RPC; the RPC remains the only
-- complete path, and that is the honest boundary of what a trigger can guarantee.
--
-- PLATFORM PATHS ARE EXEMPT, on the same basis as SPEC-145: canon 35 principle 6 places
-- `service_role` and migrations outside per-table enforcement. A tenant user cannot use the
-- exemption -- without a resolved identity they fail `tenant_id = app.current_tenant_id()` on every
-- policy and cannot reach a row at all.

create table if not exists app.status_transitions (
    table_name     text not null,
    status_column  text not null,
    from_status    text not null,
    to_status      text not null,
    permission_key text,
    primary key (table_name, from_status, to_status)
);

comment on table app.status_transitions is
    'Mirror of the transition maps inside the app.advance_* RPCs, extracted from pg_proc. The RPCs remain the author; test 32 fails if this table and they disagree. NULL permission_key means the transition needs no capability beyond the row access RLS already grants.';

-- Lives in `app`, not `public`: it is a platform rule rather than tenant data, and keeping it out of
-- `public` keeps it off the PostgREST surface entirely.
revoke all on app.status_transitions from public;

insert into app.status_transitions (table_name, status_column, from_status, to_status, permission_key) values
-- bookings (app.advance_booking) -- per-transition capability, ADR-0020
('bookings','booking_status_code','draft','pending_approval','CREATE_BOOKING'),
('bookings','booking_status_code','draft','cancelled','CREATE_BOOKING'),
('bookings','booking_status_code','pending_approval','cancelled','CREATE_BOOKING'),
('bookings','booking_status_code','pending_approval','confirmed','APPROVE_BOOKING'),
('bookings','booking_status_code','confirmed','in_progress','CREATE_BOOKING'),
('bookings','booking_status_code','confirmed','cancelled','CANCEL_BOOKING'),
('bookings','booking_status_code','in_progress','completed','CREATE_BOOKING'),
('bookings','booking_status_code','in_progress','issued','ISSUE_BOOKING'),
('bookings','booking_status_code','in_progress','cancelled','CANCEL_BOOKING'),
('bookings','booking_status_code','issued','completed','CREATE_BOOKING'),
('bookings','booking_status_code','issued','void','CANCEL_BOOKING'),
('bookings','booking_status_code','issued','refunded','REFUND_BOOKING'),
('bookings','booking_status_code','issued','reissue','REISSUE_BOOKING'),
('bookings','booking_status_code','reissue','issued','ISSUE_BOOKING'),
('bookings','booking_status_code','void','completed','CREATE_BOOKING'),
('bookings','booking_status_code','refunded','completed','CREATE_BOOKING'),
-- leads -- CLOSE_LEAD only on closure transitions; the rest need row access alone.
--
-- THE FIRST THREE ARE NOT IN app.advance_lead, AND THAT IS THE POINT. Building this table from the
-- `advance_*` RPCs alone produced a map that immediately failed test 24: `app.assign_lead` performs
-- `new -> assigned` and is not an `advance_*` function at all. Transition-owning logic turned out to
-- live in three further RPCs, each confirmed against canon 26's Lead State Machine "Normal Flow"
-- (`new -> assigned -> contacted -> qualified -> ... -> won -> converted`) rather than inferred from
-- the code alone:
--   * app.assign_lead / app.assign_lead_round_robin  -> new -> assigned          (ASSIGN_LEAD)
--   * app.record_lead_interaction                    -> assigned -> contacted    (see below)
--   * app.convert_lead                               -> won -> converted         (canon 26: "only a
--     won lead may convert", enforced in the RPC)
--
-- `assigned -> contacted` carries NO permission key deliberately. `record_lead_interaction` admits
-- either the assigned handler OR a holder of ASSIGN_LEAD; requiring ASSIGN_LEAD in the trigger would
-- lock out the very employee the lead was assigned to.
('leads','lead_status_code','new','assigned','ASSIGN_LEAD'),
('leads','lead_status_code','assigned','contacted',null),
('leads','lead_status_code','won','converted',null),
('leads','lead_status_code','new','spam','CLOSE_LEAD'),
('leads','lead_status_code','new','duplicate','CLOSE_LEAD'),
('leads','lead_status_code','assigned','lost','CLOSE_LEAD'),
('leads','lead_status_code','assigned','duplicate','CLOSE_LEAD'),
('leads','lead_status_code','contacted','qualified',null),
('leads','lead_status_code','contacted','lost','CLOSE_LEAD'),
('leads','lead_status_code','contacted','spam','CLOSE_LEAD'),
('leads','lead_status_code','qualified','quotation_sent',null),
('leads','lead_status_code','qualified','won',null),
('leads','lead_status_code','qualified','lost','CLOSE_LEAD'),
('leads','lead_status_code','quotation_sent','negotiation',null),
('leads','lead_status_code','quotation_sent','won',null),
('leads','lead_status_code','quotation_sent','lost','CLOSE_LEAD'),
('leads','lead_status_code','negotiation','won',null),
('leads','lead_status_code','negotiation','lost','CLOSE_LEAD'),
-- booking_items (app.advance_booking_item) -- one top-level capability
('booking_items','base_status_code','draft','pending','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','draft','completed','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','draft','cancelled','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','pending','confirmed','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','pending','cancelled','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','confirmed','in_progress','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','confirmed','completed','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','confirmed','cancelled','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','confirmed','no_show','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','in_progress','completed','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','in_progress','cancelled','UPDATE_BOOKING_ITEM_STATUS'),
('booking_items','base_status_code','in_progress','no_show','UPDATE_BOOKING_ITEM_STATUS'),
-- quotations (app.advance_quotation)
('quotations','quotation_status_code','draft','sent','SEND_QUOTATION'),
('quotations','quotation_status_code','draft','cancelled','CREATE_QUOTATION'),
('quotations','quotation_status_code','sent','accepted','ACCEPT_QUOTATION'),
('quotations','quotation_status_code','sent','rejected','ACCEPT_QUOTATION'),
('quotations','quotation_status_code','sent','expired','SEND_QUOTATION'),
('quotations','quotation_status_code','sent','cancelled','SEND_QUOTATION'),
('quotations','quotation_status_code','rejected','draft','CREATE_QUOTATION'),
('quotations','quotation_status_code','expired','draft','CREATE_QUOTATION'),
-- refunds (app.advance_refund) -- one top-level capability
('refunds','refund_status_code','requested','approved','RECORD_REFUND'),
('refunds','refund_status_code','requested','rejected','RECORD_REFUND'),
('refunds','refund_status_code','requested','cancelled','RECORD_REFUND'),
('refunds','refund_status_code','approved','processing','RECORD_REFUND'),
('refunds','refund_status_code','approved','completed','RECORD_REFUND'),
('refunds','refund_status_code','approved','cancelled','RECORD_REFUND'),
('refunds','refund_status_code','processing','completed','RECORD_REFUND'),
('refunds','refund_status_code','processing','cancelled','RECORD_REFUND'),
-- tasks (app.advance_task)
('tasks','task_status_code','open','in_progress','ASSIGN_TASK'),
('tasks','task_status_code','open','completed','COMPLETE_TASK'),
('tasks','task_status_code','open','cancelled','COMPLETE_TASK'),
('tasks','task_status_code','in_progress','completed','COMPLETE_TASK'),
('tasks','task_status_code','in_progress','cancelled','COMPLETE_TASK'),
('tasks','task_status_code','overdue','in_progress','ASSIGN_TASK'),
('tasks','task_status_code','overdue','completed','COMPLETE_TASK'),
('tasks','task_status_code','overdue','cancelled','COMPLETE_TASK'),
-- conversations (app.advance_conversation)
('conversations','conversation_status_code','open','assigned','SEND_MESSAGE'),
('conversations','conversation_status_code','assigned','pending_customer','SEND_MESSAGE'),
('conversations','conversation_status_code','assigned','pending_internal','SEND_MESSAGE'),
('conversations','conversation_status_code','pending_customer','assigned','SEND_MESSAGE'),
('conversations','conversation_status_code','pending_internal','assigned','SEND_MESSAGE'),
('conversations','conversation_status_code','assigned','escalated','ESCALATE_CONVERSATION'),
('conversations','conversation_status_code','escalated','assigned','ESCALATE_CONVERSATION'),
('conversations','conversation_status_code','assigned','closed','CLOSE_CONVERSATION'),
('conversations','conversation_status_code','pending_customer','closed','CLOSE_CONVERSATION'),
('conversations','conversation_status_code','escalated','closed','CLOSE_CONVERSATION'),
('conversations','conversation_status_code','closed','open','CLOSE_CONVERSATION'),
-- complaints (app.advance_complaint)
('complaints','complaint_status_code','new','acknowledged','RESOLVE_COMPLAINT'),
('complaints','complaint_status_code','acknowledged','in_progress','RESOLVE_COMPLAINT'),
('complaints','complaint_status_code','in_progress','awaiting_customer','RESOLVE_COMPLAINT'),
('complaints','complaint_status_code','in_progress','awaiting_supplier','RESOLVE_COMPLAINT'),
('complaints','complaint_status_code','awaiting_customer','in_progress','RESOLVE_COMPLAINT'),
('complaints','complaint_status_code','awaiting_supplier','in_progress','RESOLVE_COMPLAINT'),
('complaints','complaint_status_code','in_progress','resolved','RESOLVE_COMPLAINT'),
('complaints','complaint_status_code','resolved','closed','RESOLVE_COMPLAINT'),
('complaints','complaint_status_code','closed','in_progress','RESOLVE_COMPLAINT'),
-- service_requests (app.advance_service_request)
('service_requests','service_request_status_code','requested','in_progress','RESOLVE_SERVICE_REQUEST'),
('service_requests','service_request_status_code','in_progress','awaiting_customer','RESOLVE_SERVICE_REQUEST'),
('service_requests','service_request_status_code','in_progress','awaiting_supplier','RESOLVE_SERVICE_REQUEST'),
('service_requests','service_request_status_code','awaiting_customer','in_progress','RESOLVE_SERVICE_REQUEST'),
('service_requests','service_request_status_code','awaiting_supplier','in_progress','RESOLVE_SERVICE_REQUEST'),
('service_requests','service_request_status_code','in_progress','resolved','RESOLVE_SERVICE_REQUEST'),
('service_requests','service_request_status_code','resolved','closed','RESOLVE_SERVICE_REQUEST'),
('service_requests','service_request_status_code','closed','in_progress','RESOLVE_SERVICE_REQUEST'),
-- marketing_campaigns (app.advance_marketing_campaign)
('marketing_campaigns','status_code','draft','active','MANAGE_MARKETING_CAMPAIGN'),
('marketing_campaigns','status_code','active','paused','MANAGE_MARKETING_CAMPAIGN'),
('marketing_campaigns','status_code','paused','active','MANAGE_MARKETING_CAMPAIGN'),
('marketing_campaigns','status_code','active','ended','MANAGE_MARKETING_CAMPAIGN'),
('marketing_campaigns','status_code','paused','ended','MANAGE_MARKETING_CAMPAIGN'),
('marketing_campaigns','status_code','ended','archived','MANAGE_MARKETING_CAMPAIGN')
on conflict do nothing;

-- ---------------------------------------------------------------------------------------------
-- The guard.
-- ---------------------------------------------------------------------------------------------
-- SECURITY DEFINER so the guard can read `app.status_transitions`, which `authenticated` has no
-- privilege on and must not: the registry is platform rule data, not tenant data. The definer
-- context does not weaken the check -- `app.authorize` resolves the CALLER through `auth.uid()`,
-- which a definer context does not change.
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
    end if;

    return new;
end
$$;
revoke execute on function app.enforce_status_transition() from public;

do $$
declare r record;
begin
    for r in select distinct table_name, status_column from app.status_transitions
    loop
        execute format(
            'create trigger %I before update on public.%I for each row execute function app.enforce_status_transition(%L)',
            r.table_name || '_enforce_status_transition', r.table_name, r.status_column);
    end loop;
end
$$;
