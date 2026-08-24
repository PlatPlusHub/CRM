-- Migration: conditional_vocabulary_and_plan_matrix
-- Plan reference: SPEC-141. Resolves CAT-5 and CAT-6, and seeds the plan matrix canon defines but
-- the database never received.
--
-- CAT-5 -- the conditional sub-status family. SPEC-136 excluded `booking_items.sub_status_code` from
-- the catalog trigger because its governing family DEPENDS on another column: canon 26's Sub-Status
-- Rule gives ticket / visa / hotel their own vocabularies, and a static column->family mapping
-- cannot express that. It was recorded as CAT-5 rather than forced into a mechanism that could not
-- represent it correctly, which was right at the time.
--
-- What changes now is only where the rule lives. `app.create_booking_item` ALREADY implements the
-- exact mapping, citing canon 13. So the rule is neither missing nor ambiguous -- it is simply
-- enforced on one path and not the other, which is the same defect SPEC-127 and SPEC-136 closed for
-- every other catalog-backed column. The mapping is lifted into `app.sub_status_family` so the
-- trigger and the RPC read it from one place, and nothing is invented.
--
-- CAT-6 -- the catalog-less columns, each answered on its own merits rather than uniformly:
--   * `user_role_assignments.scope_type` -- already resolved by SPEC-137 with a CHECK, because it
--     became security-critical.
--   * `catalog_types.ownership_type` -- platform metadata with a two-value domain, not business
--     vocabulary. A CHECK is proportionate; a catalog family would imply tenants may extend it.
--   * `feature_entitlements.feature_code` -- a REAL controlled vocabulary that canon 28 and canon 17
--     both define, on a table that turned out to be entirely EMPTY (see below).
--   * `branches.branch_type` and `company_assets.asset_type` -- deliberately left alone. Canon 31
--     lists `branch_type` as "optional" and gives neither column any vocabulary anywhere in canon.
--     Inventing one would be fabricating canon, which is the failure mode the owner named directly:
--     "Do not force every field into a catalog."
--
-- THE FINDING INSIDE CAT-6. `feature_entitlements` had zero rows and no reader -- no function in
-- `app` or `reporting` references it. Canon 28 states plainly that "Plan denial overrides user role
-- permission", canon 09 and canon 17 define the matrix in full, and none of it existed in the
-- database. The three plans were seeded; what each plan actually grants was not. That data is
-- seeded here, directly from those two canon tables.
--
-- ENFORCEMENT IS DELIBERATELY NOT WIRED. Canon 35 principle 8 settles this: subscription-state
-- gating "is a distinct concern from tenant isolation and must not be conflated with it ... handle
-- read-only/suspended enforcement at the service layer for MVP, or later as a separate RLS predicate
-- routed through the same resolution layer -- decided at implementation, not here." Seeding the
-- reference data is Foundation; choosing where the gate sits is the deferred decision canon names.
-- Recorded as PLAN-1 so the gap is visible rather than implied by an empty table.

-- ---------------------------------------------------------------------------------------------
-- 1. CAT-5: one authority for the conditional family.
-- ---------------------------------------------------------------------------------------------
create or replace function app.sub_status_family(p_service_type_code text)
returns text
language sql
immutable
set search_path = ''
as $$
    -- Canon 26 §Sub-Status Rule / canon 13. Only these three service types define a sub-status
    -- vocabulary; the other six (umrah, hajj, tour_package, insurance, transport, custom_service)
    -- deliberately have none, and returning null is what makes "this service type does not support
    -- a sub_status" expressible rather than silently permissive.
    select case p_service_type_code
        when 'flight_ticket' then 'ticket_sub_status'
        when 'visa'          then 'visa_sub_status'
        when 'hotel'         then 'hotel_sub_status'
        else null
    end
$$;
revoke execute on function app.sub_status_family(text) from public;
grant execute on function app.sub_status_family(text) to authenticated;

create or replace function app.enforce_sub_status_code()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_family text;
begin
    if new.sub_status_code is null then
        return new;
    end if;

    v_family := app.sub_status_family(new.service_type_code);
    if v_family is null then
        raise exception 'service_type % does not support a sub_status (canon 26 Sub-Status Rule)',
            new.service_type_code
            using errcode = '23514';
    end if;

    if not exists (
        select 1 from public.catalog_values cv
        where cv.catalog_type_code = v_family
          and cv.code = new.sub_status_code
          and cv.is_active
          and (cv.tenant_id is null or cv.tenant_id = new.tenant_id)
    ) then
        raise exception 'unknown or inactive % value: %', v_family, new.sub_status_code
            using errcode = '23514';
    end if;
    return new;
end
$$;
revoke execute on function app.enforce_sub_status_code() from public;

create trigger booking_items_enforce_sub_status
    before insert or update on public.booking_items
    for each row execute function app.enforce_sub_status_code();

-- ---------------------------------------------------------------------------------------------
-- 2. CAT-6: catalog_types.ownership_type.
--
-- A platform discriminator, not tenant vocabulary: it says whether a catalog family is closed
-- (`system`) or may be extended by a tenant (`tenant_extendable_system`). Both values are in use and
-- canon 25 names no third. A CHECK states the domain without implying the domain is extensible.
-- ---------------------------------------------------------------------------------------------
alter table public.catalog_types
    add constraint catalog_types_ownership_type_check
    check (ownership_type in ('system', 'tenant_extendable_system'));

-- ---------------------------------------------------------------------------------------------
-- 3. CAT-6: feature_entitlements.feature_code, and the matrix itself.
-- ---------------------------------------------------------------------------------------------
alter table public.feature_entitlements
    add constraint feature_entitlements_feature_code_check
    check (feature_code in (
        -- Canon 28 §Feature Access By Plan / canon 09 -- capability switches.
        'crm', 'customers', 'booking', 'documents', 'suppliers',
        'finance_lite', 'full_finance', 'basic_reporting', 'advanced_dashboards',
        'api_read_only', 'api_full', 'automation', 'integrations',
        'offline_conversion', 'ai_dashboard', 'multi_branch',
        -- Canon 17 §Plan Limits -- numeric ceilings, carried in limit_value.
        'max_users', 'max_branches', 'max_monthly_leads', 'max_monthly_bookings',
        'max_storage_gb', 'max_automations'
    ));

-- Capability switches. `is_enabled = false` is "No"; `is_enabled = true` with a null `limit_value`
-- is "Yes" (uncapped). Canon's third state, "Limited", is enabled-with-a-ceiling and is carried by
-- the matching numeric row below where canon 17 gives a number -- Automation by `max_automations`,
-- Multi Branch by `max_branches`. For Basic Reporting (Starter), Integrations and Offline Conversion
-- (Professional), canon marks "Limited" but defines no ceiling anywhere; those are seeded enabled
-- and uncapped, and the missing ceiling is recorded in the CR as an owner business decision rather
-- than invented here.
insert into public.feature_entitlements (subscription_plan_id, feature_code, is_enabled, limit_value)
select p.id, f.code, f.enabled, null::numeric
from public.subscription_plans p
join (values
    ('starter',      'crm', true), ('professional','crm', true), ('enterprise','crm', true),
    ('starter',      'customers', true), ('professional','customers', true), ('enterprise','customers', true),
    ('starter',      'booking', false), ('professional','booking', true), ('enterprise','booking', true),
    ('starter',      'documents', false), ('professional','documents', true), ('enterprise','documents', true),
    ('starter',      'suppliers', false), ('professional','suppliers', true), ('enterprise','suppliers', true),
    ('starter',      'finance_lite', false), ('professional','finance_lite', true), ('enterprise','finance_lite', true),
    ('starter',      'full_finance', false), ('professional','full_finance', false), ('enterprise','full_finance', true),
    ('starter',      'basic_reporting', true), ('professional','basic_reporting', true), ('enterprise','basic_reporting', true),
    ('starter',      'advanced_dashboards', false), ('professional','advanced_dashboards', false), ('enterprise','advanced_dashboards', true),
    ('starter',      'api_read_only', false), ('professional','api_read_only', true), ('enterprise','api_read_only', true),
    ('starter',      'api_full', false), ('professional','api_full', false), ('enterprise','api_full', true),
    ('starter',      'automation', false), ('professional','automation', true), ('enterprise','automation', true),
    ('starter',      'integrations', false), ('professional','integrations', true), ('enterprise','integrations', true),
    ('starter',      'offline_conversion', false), ('professional','offline_conversion', true), ('enterprise','offline_conversion', true),
    ('starter',      'ai_dashboard', false), ('professional','ai_dashboard', false), ('enterprise','ai_dashboard', true),
    ('starter',      'multi_branch', false), ('professional','multi_branch', true), ('enterprise','multi_branch', true)
) as f(plan, code, enabled) on f.plan = p.plan_code
on conflict (subscription_plan_id, feature_code) do nothing;

-- Numeric ceilings, canon 17 §Plan Limits. "Unlimited" and "Custom" are both a null `limit_value` on
-- an enabled row -- there is no ceiling to record, and using a sentinel number would invent one.
insert into public.feature_entitlements (subscription_plan_id, feature_code, is_enabled, limit_value)
select p.id, f.code, true, f.cap
from public.subscription_plans p
join (values
    ('starter','max_users', 5::numeric), ('professional','max_users', 15), ('enterprise','max_users', null),
    ('starter','max_branches', 1), ('professional','max_branches', 3), ('enterprise','max_branches', null),
    ('starter','max_monthly_leads', 500), ('professional','max_monthly_leads', 10000), ('enterprise','max_monthly_leads', null),
    ('starter','max_monthly_bookings', 100), ('professional','max_monthly_bookings', 3000), ('enterprise','max_monthly_bookings', null),
    ('starter','max_storage_gb', 2), ('professional','max_storage_gb', 5), ('enterprise','max_storage_gb', null),
    ('starter','max_automations', 5), ('professional','max_automations', 100), ('enterprise','max_automations', null)
) as f(plan, code, cap) on f.plan = p.plan_code
on conflict (subscription_plan_id, feature_code) do nothing;
