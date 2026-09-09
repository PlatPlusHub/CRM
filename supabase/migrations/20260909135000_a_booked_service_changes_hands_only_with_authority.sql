-- BOOK-9 -- owner decision, ratified 2026-09-09.
--
-- Booking-item ownership reassignment has its own capability, independent of CREATE_BOOKING_ITEM.
--
-- ================================================================================================
-- WHAT WAS THERE
--
-- BOOK-5 (202607061500) removed the PROFIT in seizing a booking item: `guard_booking_item_financials`
-- reads the PRE-image, so an ownership grab in the same statement no longer buys the money scope.
-- What it did NOT do is price the grab itself, and `105_booking_item_service_door_test.sql`
-- assertion 15 asserts, deliberately, that it SUCCEEDS: a holder of CREATE_BOOKING_ITEM may rewrite
-- `owner_user_id`, `sales_owner_user_id` and `operational_owner_user_id` on an item assigned to a
-- colleague. Canon 28 gives leads both ASSIGN_LEAD and REASSIGN_LEAD and gives booking items
-- neither, so BOOK-9 was registered as a canon ABSENCE rather than filled in. The owner has now
-- filled it, and that assertion flips from `lives_ok` to `throws_ok` -- exactly as it said it would.
--
-- ================================================================================================
-- THE BUNDLE, DERIVED RATHER THAN CHOSEN
--
-- Seeded to the roles already trusted with REASSIGN_LEAD: owner, ceo, branch_manager,
-- department_manager. No role was added: the owner decision permits widening only where CURRENT
-- canon already demonstrates equivalent cross-owner booking authority, and it does not --
-- `finance_manager` holds REISSUE_BOOKING but moving sales responsibility is not a finance act, and
-- `employee`/`senior_employee` holding CREATE_BOOKING_ITEM is precisely the population this
-- capability exists to exclude.
--
-- CONTAINMENT, MEASURED: all four of those roles also hold CREATE_BOOKING_ITEM, so the object-class
-- door (`app.guard_write_capability`, which charges CREATE_BOOKING_ITEM for booking_items) refuses
-- none of them and this guard is purely ADDITIVE -- an ownership move costs the object-class
-- permission AND the reassignment authority. Unlike PAX-5's finance_manager case there is no role
-- holding one and not the other, so `guard_write_capability` needs no change here. A future per-user
-- grant of REASSIGN_BOOKING_ITEM to somebody who cannot write booking items at all would still need
-- CREATE_BOOKING_ITEM, which is correct rather than an oversight: they must be able to write the row
-- before they can move it.
--
-- ================================================================================================
-- WHAT "FROM ONE RESPONSIBLE PERSON TO ANOTHER" MEANS IN THE PREDICATE
--
-- The guard fires when an owner column moves AWAY FROM A NON-NULL VALUE -- not only when it moves
-- from one person to another. Filling an EMPTY slot is initial assignment and stays under
-- CREATE_BOOKING_ITEM. Clearing an occupied one is NOT exempted, because exempting it would leave a
-- two-step bypass: set the owner to NULL (free), then NULL to me (free). One statement or two, the
-- colleague still lost the item.
--
-- ================================================================================================
-- HISTORY, STATED ACCURATELY RATHER THAN ASSUMED
--
-- ORVION has no commission LEDGER table -- measured: nothing under `public` records an earned
-- commission as a row. `booking_items.commission_rate` is set unconditionally by
-- `app.derive_commission_rate` from the TENANT-WIDE default and does not depend on who owns the
-- item, so reassignment cannot rewrite it. Performance attribution is DERIVED from current ownership
-- by reporting views (`my_sales_performance`, `lead_performance`). There is therefore no historical
-- record for a reassignment to corrupt, and what preserves the history is the
-- `booking_item_reassigned` event: it names the previous owners, the new owners, the actor, the
-- reason and the instant, so who held the item when remains answerable after the move.

-- ------------------------------------------------------------------------------------------------
-- 1. The capability.
-- ------------------------------------------------------------------------------------------------
insert into public.permissions (key, name, description, required_feature_code, capability_group, action_kind, is_system, is_active)
values ('REASSIGN_BOOKING_ITEM',
        'Reassign a booked service',
        'Move responsibility for a booking item -- owner_user_id, sales_owner_user_id or '
        'operational_owner_user_id -- away from the person currently holding it. Independent of '
        'CREATE_BOOKING_ITEM, which builds and edits items and is explicitly NOT sufficient to take '
        'one from a colleague. The booking-item counterpart of canon 28''s REASSIGN_LEAD. Owner '
        'decision BOOK-9, 2026-09-09.',
        'booking', 'Booking', 'manage', true, true)
on conflict (key) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where p.key = 'REASSIGN_BOOKING_ITEM'
  and r.code in (select r2.code
                 from public.role_permissions rp2
                 join public.roles r2 on r2.id = rp2.role_id
                 join public.permissions p2 on p2.id = rp2.permission_id
                 where p2.key = 'REASSIGN_LEAD')
on conflict do nothing;

-- ------------------------------------------------------------------------------------------------
-- 2. The reassignment's evidence, and its event vocabulary.
-- ------------------------------------------------------------------------------------------------
alter table public.booking_items
    add column reassignment_reason text,
    add column reassigned_at timestamptz,
    add column reassigned_by uuid;

alter table public.booking_items
    add constraint booking_items_reassigned_by_fkey
    foreign key (tenant_id, reassigned_by)
    references public.users (tenant_id, id) on delete restrict;

comment on column public.booking_items.reassignment_reason is
    'BOOK-9: mandatory, caller-authored reason for moving responsibility away from the current holder. Must be FRESH on each reassignment.';
comment on column public.booking_items.reassigned_at is
    'BOOK-9: server-stamped instant of the last reassignment. Never accepted from the caller.';
comment on column public.booking_items.reassigned_by is
    'BOOK-9: server-stamped actor of the last reassignment. Never accepted from the caller.';

insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_system, is_active)
select v.type_code, v.code, v.label, v.ord, true, true
from (values
        ('event_type', 'booking_item_reassigned', 'Booking Item Reassigned', 921)
     ) as v(type_code, code, label, ord)
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = v.type_code and cv.code = v.code and cv.tenant_id is null
);

-- ------------------------------------------------------------------------------------------------
-- 3. The authority guard.
--
--    A dedicated BEFORE UPDATE trigger, the shape TASK-1's `app.guard_task_reassignment` already
--    established for the identical problem one table over -- chosen over widening
--    `app.guard_write_capability` for the reason that function's own TASK-1 comment gives: it fires
--    on every write to the table and charging the reassignment authority for every booking-item edit
--    would stop an employee pricing their own item, which CREATE_BOOKING_ITEM legitimately allows.
--
--    SECURITY INVOKER, and no elevation is wanted: every value it reads is in the row images it was
--    handed. The session-less path IS exempt, because this is AUTHORIZATION and canon 35 principle 6
--    exempts platform paths from authorization -- the same exemption `guard_task_reassignment` and
--    `guard_booking_item_financials` take. The INTEGRITY half (the fresh reason, the server stamp)
--    deliberately sits inside that same branch: a platform path has no actor to attribute and no
--    human reason to give, and demanding one would break the scheduled and integration writers that
--    touch these rows.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_booking_item_reassignment()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_moved boolean;
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    -- AWAY FROM an occupied slot, in any of the three ownership columns. Filling an empty slot is
    -- initial assignment and is not this act; clearing an occupied one IS, or the two-step bypass
    -- (owner -> null, then null -> me) would cost nothing.
    v_moved := (old.owner_user_id             is not null and new.owner_user_id             is distinct from old.owner_user_id)
            or (old.sales_owner_user_id       is not null and new.sales_owner_user_id       is distinct from old.sales_owner_user_id)
            or (old.operational_owner_user_id is not null and new.operational_owner_user_id is distinct from old.operational_owner_user_id);

    if v_moved then
        perform app.authorize('REASSIGN_BOOKING_ITEM');

        if new.reassignment_reason is null
           or btrim(new.reassignment_reason) = ''
           or new.reassignment_reason is not distinct from old.reassignment_reason then
            raise exception 'reassigning a booked service requires its own reason'
                using errcode = 'check_violation';
        end if;

        new.reassigned_at := now();
        new.reassigned_by := (select app.current_user_id());

    elsif new.reassignment_reason is distinct from old.reassignment_reason
       or new.reassigned_at is distinct from old.reassigned_at
       or new.reassigned_by is distinct from old.reassigned_by then
        raise exception 'reassignment evidence is not editable on its own'
            using errcode = 'check_violation';
    end if;

    return new;
end
$fn$;

comment on function app.guard_booking_item_reassignment() is
    'BOOK-9 (owner decision 2026-09-09): moving owner_user_id, sales_owner_user_id or operational_owner_user_id away from the person holding it costs REASSIGN_BOOKING_ITEM plus a fresh reason, and stamps the actor and instant. CREATE_BOOKING_ITEM is not sufficient -- 105 assertion 15 asserted that it WAS, and flips with this migration. Fires only when ownership actually moves, so ordinary booking-item work stays under CREATE_BOOKING_ITEM (TASK-1''s shape).';

revoke all on function app.guard_booking_item_reassignment() from public;

create trigger booking_items_guard_reassignment
    before update on public.booking_items
    for each row execute function app.guard_booking_item_reassignment();

-- ------------------------------------------------------------------------------------------------
-- 4. The event producer -- one, on the AFTER path, for PAX-6's reason.
-- ------------------------------------------------------------------------------------------------
create or replace function app.record_booking_item_reassignment_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if (old.owner_user_id             is not null and new.owner_user_id             is distinct from old.owner_user_id)
    or (old.sales_owner_user_id       is not null and new.sales_owner_user_id       is distinct from old.sales_owner_user_id)
    or (old.operational_owner_user_id is not null and new.operational_owner_user_id is distinct from old.operational_owner_user_id)
    then
        perform app.record_event(
            new.tenant_id, 'booking_item_reassigned', 'booking_item', new.id,
            null,
            old.owner_user_id::text, new.owner_user_id::text,
            new.reassignment_reason,
            jsonb_build_object(
                'previous_owner_user_id',             old.owner_user_id,
                'new_owner_user_id',                  new.owner_user_id,
                'previous_sales_owner_user_id',       old.sales_owner_user_id,
                'new_sales_owner_user_id',            new.sales_owner_user_id,
                'previous_operational_owner_user_id', old.operational_owner_user_id,
                'new_operational_owner_user_id',      new.operational_owner_user_id,
                'reassigned_by',                      new.reassigned_by),
            'warning');
    end if;
    return null;
end
$fn$;

comment on function app.record_booking_item_reassignment_event() is
    'BOOK-9: the sole producer of booking_item_reassigned. AFTER trigger rather than RPC code, because public.booking_items is a sanctioned direct-DML surface. Carries all three previous and new owners, the actor, the reason and (through events.created_at) the instant -- ORVION has no commission ledger, so this event is what keeps "who held this item when" answerable after the move.';

revoke all on function app.record_booking_item_reassignment_event() from public;

create trigger booking_items_record_reassignment
    after update on public.booking_items
    for each row execute function app.record_booking_item_reassignment_event();

-- ------------------------------------------------------------------------------------------------
-- 5. The sanctioned path. SECURITY INVOKER; the triggers above own every rule.
--    `coalesce(p_*, current)` so a caller may move one owner without restating the other two.
-- ------------------------------------------------------------------------------------------------
create or replace function app.reassign_booking_item(
    p_booking_item_id uuid,
    p_reason text,
    p_owner_user_id uuid default null,
    p_sales_owner_user_id uuid default null,
    p_operational_owner_user_id uuid default null
)
returns void
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_item   record;
    v_new_owner uuid;
    v_new_sales uuid;
    v_new_ops   uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if p_reason is null or btrim(p_reason) = '' then
        raise exception 'reassigning a booked service requires a reason';
    end if;
    if p_owner_user_id is null and p_sales_owner_user_id is null and p_operational_owner_user_id is null then
        raise exception 'name at least one new owner to reassign';
    end if;

    select bi.id, bi.owner_user_id, bi.sales_owner_user_id, bi.operational_owner_user_id
      into v_item
    from public.booking_items bi
    where bi.id = p_booking_item_id and bi.tenant_id = v_tenant
    for update;
    if not found then
        raise exception 'booking item is not in your tenant';
    end if;

    v_new_owner := coalesce(p_owner_user_id, v_item.owner_user_id);
    v_new_sales := coalesce(p_sales_owner_user_id, v_item.sales_owner_user_id);
    v_new_ops   := coalesce(p_operational_owner_user_id, v_item.operational_owner_user_id);

    -- Every named owner must be a real user in THIS tenant. The composite foreign keys prove that
    -- for a committable row; this raises the readable error before the write is attempted.
    if exists (
        select 1 from unnest(array[v_new_owner, v_new_sales, v_new_ops]) u(id)
        where u.id is not null
          and not exists (select 1 from public.users usr where usr.id = u.id and usr.tenant_id = v_tenant))
    then
        raise exception 'a named owner is not a user in your tenant';
    end if;

    update public.booking_items
    set owner_user_id             = v_new_owner,
        sales_owner_user_id       = v_new_sales,
        operational_owner_user_id = v_new_ops,
        reassignment_reason       = p_reason,
        updated_at                = now()
    where id = p_booking_item_id and tenant_id = v_tenant;
end
$fn$;

comment on function app.reassign_booking_item(uuid, text, uuid, uuid, uuid) is
    'BOOK-9 (owner decision 2026-09-09): the sanctioned booking-item reassignment. SECURITY INVOKER -- app.guard_booking_item_reassignment enforces the capability, the fresh reason and the actor stamp on the UPDATE it performs, and app.record_booking_item_reassignment_event emits the audit, so this RPC and the table door cannot diverge.';

revoke all on function app.reassign_booking_item(uuid, text, uuid, uuid, uuid) from public;
grant execute on function app.reassign_booking_item(uuid, text, uuid, uuid, uuid) to authenticated;

create or replace function public.reassign_booking_item(
    p_booking_item_id uuid,
    p_reason text,
    p_owner_user_id uuid default null,
    p_sales_owner_user_id uuid default null,
    p_operational_owner_user_id uuid default null)
returns void language sql set search_path = ''
as $fn$ select app.reassign_booking_item(p_booking_item_id, p_reason, p_owner_user_id,
                                         p_sales_owner_user_id, p_operational_owner_user_id) $fn$;
revoke all on function public.reassign_booking_item(uuid, text, uuid, uuid, uuid) from public;
grant execute on function public.reassign_booking_item(uuid, text, uuid, uuid, uuid) to authenticated;
comment on function public.reassign_booking_item(uuid, text, uuid, uuid, uuid) is
    'HTTP surface for the SECURITY INVOKER app.reassign_booking_item operation.';
