-- SPEC-215 / SUP-5 -- Batch 6 slice 15, `suppliers`.
--
-- THE RULE. Canon 27 catalogues `supplier_created`, and canon 30 says every meaningful business
-- action creates an event. `app.create_supplier` emitted it from inside itself, and nothing else
-- did. `authenticated` holds table-level INSERT here, and PostgREST serves it beside the RPC, so a
-- supplier created at the table door was SILENT. Measured before this migration: a
-- `senior_employee` holding ASSIGN_SUPPLIER created one supplier through the RPC (one
-- `supplier_created` event, actor = the senior) and one by direct INSERT with `created_at` set to
-- 2019-01-01 (zero events, zero security events). `suppliers` has no creator column, so for that
-- row the ledger was the ONLY record of who added a payee to the supplier master, and it held
-- nothing. What happens to the supplier afterwards stays attributed (`supplier_payment_recorded`
-- names its actor); only its creation was lost.
--
-- THE SHAPE is `app.emit_membership_change`'s (USR-1, `20260920120000`), deliberately: one AFTER
-- INSERT trigger is the single producer of the event, and the RPC loses its own `record_event`
-- call. Leaving that call would record every RPC creation twice. The actor and the time are not
-- this trigger's to decide: `app.record_event` takes the actor from the session (ignoring the
-- argument inside one, refusing one outside) and stamps `created_at` itself, so a statement can
-- neither name another creator nor backdate the event. The session-less path (migrations, seeds,
-- fixtures) is recorded too, with a null actor, which is what a system act looks like here.
--
-- NOT CHANGED: every grant, policy, constraint and guard, and every other line of
-- `app.create_supplier` -- its authority, its checks and its insert. The event's type, entity,
-- severity and payload keys are the ones the RPC wrote; the payload values are read from the row
-- the RPC wrote them into. UPDATE and DELETE are deliberately not recorded: canon 27 has no
-- supplier-update event, no RPC edits a supplier, and `authenticated` holds no DELETE here.
create or replace function app.emit_supplier_created()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
    perform app.record_event(
        new.tenant_id, 'supplier_created', 'supplier', new.id, app.current_user_id(),
        null, null, null,
        jsonb_build_object('supplier_type_code', new.supplier_type_code, 'name', new.name),
        'info');
    return null;
end;
$$;

revoke execute on function app.emit_supplier_created() from public;

create trigger suppliers_emit_created
    after insert on public.suppliers
    for each row execute function app.emit_supplier_created();

create or replace function app.create_supplier(
    p_name text,
    p_supplier_type_code text,
    p_phone text default null,
    p_email text default null,
    p_payment_term_code text default null,
    p_credit_limit_amount numeric default null,
    p_credit_limit_currency_code text default null
)
returns uuid
language plpgsql
set search_path to ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_id uuid;
    v_name text := nullif(btrim(p_name), '');
    v_phone text := app.normalize_phone(p_phone);
    v_email text := app.normalize_email(p_email);
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('ASSIGN_SUPPLIER');
    if v_name is null then raise exception 'name is required'; end if;
    if p_credit_limit_amount is not null and p_credit_limit_amount < 0 then
        raise exception 'credit_limit_amount must be non-negative'; end if;
    -- SUP-4a: refuse the ill-formed amount explicitly rather than letting the CHECK report it, so the
    -- caller is told which of the two it omitted.
    if (p_credit_limit_amount is null) <> (p_credit_limit_currency_code is null) then
        raise exception 'a credit limit needs both an amount and a currency (canon 30 money standard)'
            using errcode = 'check_violation';
    end if;

    -- Supplier names are the operational key an employee searches by, so the same supplier entered
    -- twice under one tenant is an accidental duplicate that would split payables across two
    -- records. Case-insensitive, because 'Egyptair' and 'EgyptAir' are the same airline.
    if exists (
        select 1 from public.suppliers
        where tenant_id = v_tenant and not is_archived and lower(name) = lower(v_name)
    ) then
        raise exception 'a supplier named "%" already exists in this tenant', v_name
            using errcode = 'unique_violation';
    end if;

    insert into public.suppliers (
        tenant_id, supplier_type_code, name, phone, email, payment_term_code,
        credit_limit_amount, credit_limit_currency_code
    ) values (
        v_tenant, p_supplier_type_code, v_name, v_phone, v_email, p_payment_term_code,
        p_credit_limit_amount, p_credit_limit_currency_code
    ) returning id into v_id;

    -- `supplier_created` is emitted by suppliers_emit_created, not from here (SUP-5).

    return v_id;
end;
$$;
