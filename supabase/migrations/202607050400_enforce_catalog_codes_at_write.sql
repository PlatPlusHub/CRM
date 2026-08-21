-- Migration: enforce_catalog_codes_at_write
-- Plan reference: SPEC-127. Closes VOCAB-1 and resolves CAT-4 for every table it covers.
--
-- THE DEFECT (reproduced on the local database 2026-08-21, before any fix):
--   insert into tasks (... task_type_code, task_status_code, priority_code, related_entity_type ...)
--   values (..., 'TOTALLY_MADE_UP', 'not_a_status', 'SUPER_URGENT', 'BoOkInG');           -- ACCEPTED
--   insert into suppliers (... supplier_type_code, payment_term_code) values (..., 'MADE_UP_SUPPLIER', 'pay_whenever');  -- ACCEPTED
--   insert into conversations (... channel_code, conversation_status_code) values (..., 'carrier_pigeon', 'vibing');     -- ACCEPTED
--
-- SPEC-126 made the catalog itself canonical: a code cannot be created in casing/whitespace
-- variants, cannot belong to an unregistered family, and is correctly tenant-scoped. It did NOT
-- make the catalog AUTHORITATIVE AT THE POINT OF USE. A consuming column is plain `text` (ADR-0006),
-- validated only by the RPC that writes it -- and 35 of 72 tables have no RPC write path at all.
-- For those tables the controlled vocabulary was enforced by nothing whatsoever, so an employee (or
-- any direct PostgREST write) could invent a status, a type, a channel or a payment term at will.
-- That is the same "one logical value, many spellings" failure SPEC-126 fixed, displaced from the
-- catalog to its consumers.
--
-- WHY A TRIGGER, AND WHY THIS IS NOT A NEW ARCHITECTURE. ADR-0006 ratified that status/type codes
-- are plain text and explicitly names the alternative it leaves available: "Hard DB enforcement
-- (validation trigger, or constant type column + composite FK) is optional per column." This is
-- that sanctioned option, applied where evidence shows enforcement is absent -- not a redesign.
-- One generic function plus a declarative column->family mapping stated at each CREATE TRIGGER; no
-- new table, no registry to keep in sync, and the mapping is readable at the point it applies.
--
-- IT ALSO RESOLVES CAT-4 FOR THESE TABLES. Canon 25's rule is "deactivate, do not delete" -- which
-- only means anything if a deactivated value stops being selectable for NEW work while historical
-- rows keep theirs. None of the 27 catalog lookups filters `is_active`, so deactivation did
-- nothing. This trigger enforces is_active, and does so correctly on both paths:
--   * INSERT  -> every mapped column is validated.
--   * UPDATE  -> ONLY columns whose value actually changed are validated.
-- That distinction is the whole point: editing an unrelated field on an old row that references a
-- since-deactivated code must still succeed, or "history keeps its values" would be a lie.
--
-- SCOPE (deliberate, and the reason it is safe): applied to the tables that have NO RPC write path,
-- which is exactly the set where the defect was proven and where nothing else validates. Columns
-- written by an RPC are already validated on their only intended path; extending this trigger to
-- them is defense-in-depth against SEC-1 and is recorded as the CAT-4 completion step rather than
-- bundled here, because it would change behaviour on paths this migration has no evidence about.

create or replace function app.enforce_catalog_codes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    i int;
    v_column text;
    v_family text;
    v_value text;
    v_new jsonb := to_jsonb(new);
    v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else null end;
begin
    -- TG_ARGV holds (column, catalog_family) pairs.
    i := 0;
    while i < tg_nargs loop
        v_column := tg_argv[i];
        v_family := tg_argv[i + 1];
        i := i + 2;

        v_value := v_new ->> v_column;
        continue when v_value is null;

        -- On UPDATE, only re-validate a column the statement actually changed. This is what lets a
        -- historical row that references a since-deactivated code continue to be edited.
        continue when tg_op = 'UPDATE' and v_old ->> v_column is not distinct from v_value;

        if not exists (
            select 1 from public.catalog_values cv
            where cv.catalog_type_code = v_family
              and cv.code = v_value
              and cv.is_active
              -- A row may use a global value, or its own tenant's value. The cast is required:
              -- v_new ->> 'tenant_id' is text, and it is NULL for the platform-scoped tables that
              -- carry no tenant_id column at all, which correctly narrows those to global values.
              and (cv.tenant_id is null
                   or cv.tenant_id = nullif(v_new ->> 'tenant_id', '')::uuid)
        ) then
            raise exception
                '% .% : "%" is not an active value of catalog family "%"',
                tg_table_name, v_column, v_value, v_family
                using errcode = 'check_violation';
        end if;
    end loop;

    return new;
end;
$$;

revoke execute on function app.enforce_catalog_codes() from public;

-- ---------------------------------------------------------------------------------------------
-- Apply to the tables with no RPC write path. Each trigger states its own column->family mapping.
-- ---------------------------------------------------------------------------------------------

create trigger tasks_enforce_catalog_codes
    before insert or update on public.tasks
    for each row execute function app.enforce_catalog_codes(
        'task_type_code', 'task_type_code',
        'task_status_code', 'task_status_code',
        'priority_code', 'priority_code');

create trigger conversations_enforce_catalog_codes
    before insert or update on public.conversations
    for each row execute function app.enforce_catalog_codes(
        'channel_code', 'channel_code',
        'conversation_status_code', 'conversation_status_code');

create trigger conversation_messages_enforce_catalog_codes
    before insert or update on public.conversation_messages
    for each row execute function app.enforce_catalog_codes(
        'message_direction_code', 'message_direction_code',
        'sender_type_code', 'sender_type_code');

create trigger complaints_enforce_catalog_codes
    before insert or update on public.complaints
    for each row execute function app.enforce_catalog_codes(
        'complaint_category_code', 'complaint_category_code',
        'complaint_severity_code', 'complaint_severity_code',
        'complaint_status_code', 'complaint_status_code');

create trigger service_requests_enforce_catalog_codes
    before insert or update on public.service_requests
    for each row execute function app.enforce_catalog_codes(
        'service_request_type_code', 'service_request_type_code',
        'service_request_severity_code', 'service_request_severity_code',
        'service_request_status_code', 'service_request_status_code');

create trigger suppliers_enforce_catalog_codes
    before insert or update on public.suppliers
    for each row execute function app.enforce_catalog_codes(
        'supplier_type_code', 'supplier_type',
        'payment_term_code', 'supplier_payment_term_code');

create trigger marketing_campaigns_enforce_catalog_codes
    before insert or update on public.marketing_campaigns
    for each row execute function app.enforce_catalog_codes(
        'platform_code', 'platform_code',
        'status_code', 'campaign_status_code');

create trigger customer_contact_methods_enforce_catalog_codes
    before insert or update on public.customer_contact_methods
    for each row execute function app.enforce_catalog_codes(
        'contact_method_type_code', 'contact_method_type');

create trigger notification_deliveries_enforce_catalog_codes
    before insert or update on public.notification_deliveries
    for each row execute function app.enforce_catalog_codes(
        'channel_code', 'notification_channel',
        'delivery_status_code', 'notification_delivery_status');

create trigger financial_accounts_enforce_catalog_codes
    before insert or update on public.financial_accounts
    for each row execute function app.enforce_catalog_codes(
        'financial_account_type_code', 'financial_account_type');

create trigger exchange_rate_adjustments_enforce_catalog_codes
    before insert or update on public.exchange_rate_adjustments
    for each row execute function app.enforce_catalog_codes(
        'reason_code', 'exchange_rate_adjustment_reason');

create trigger subscriptions_enforce_catalog_codes
    before insert or update on public.subscriptions
    for each row execute function app.enforce_catalog_codes(
        'subscription_status_code', 'subscription_status');
