-- Batch 6 slice 9 (`catalog_values`). Measured on the local stack before this file (probes CV1-CV5):
--   * an owner wrote tenant values from a password-only (aal1) session: MANAGE_TENANT_SETTINGS was charged through RLS,
--     never the step-up `app.authorize` charges every MFA-bound role;
--   * a tenant added its own values to platform-owned families (`payment_direction`, `booking_item_base_status`): the
--     policy reads only the tenant, never `catalog_types.ownership_type`, and `app.enforce_catalog_codes` then accepts
--     that value on the tenant's rows;
--   * a tenant value in use was renamed and moved to another family, leaving the supplier that used it holding a code
--     with no value behind it; and a tenant value claimed `is_system`.
-- Repair: every session write charges `app.authorize('MANAGE_TENANT_SETTINGS')`, adds only to a
-- `tenant_extendable_system` family, never as a system value, and an UPDATE keeps the value's family, code and
-- tenant (a replaced value is added anew and the old one deactivated, which `enforce_catalog_codes` already allows).

create or replace function app.guard_catalog_value_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    perform app.authorize('MANAGE_TENANT_SETTINGS');
    if new.is_system then
        raise exception 'a tenant catalog value cannot be a system value' using errcode = '42501';
    end if;
    if not exists (select 1 from public.catalog_types t
                    where t.code = new.catalog_type_code and t.ownership_type = 'tenant_extendable_system') then
        raise exception 'catalog family % does not take tenant values', new.catalog_type_code using errcode = '42501';
    end if;
    if tg_op = 'UPDATE'
       and (new.tenant_id, new.catalog_type_code, new.code) is distinct from (old.tenant_id, old.catalog_type_code, old.code) then
        raise exception 'a catalog value keeps its family and code: add a new value and deactivate this one'
            using errcode = '42501';
    end if;
    return new;
end;
$fn$;

revoke execute on function app.guard_catalog_value_write() from public;

create trigger catalog_values_guard_write
    before insert or update on public.catalog_values
    for each row execute function app.guard_catalog_value_write();
