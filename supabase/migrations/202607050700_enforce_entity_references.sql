-- Migration: enforce_entity_references
-- Plan reference: SPEC-130. Resolves REL-1 — the polymorphic `related_entity_type` /
-- `related_entity_id` pair on tasks, notifications and approval_requests had no referential
-- integrity, no tenant safety, and no controlled vocabulary.
--
-- THE DEFECT (reproduced on the local database 2026-08-21, before any fix):
--     insert into tasks (..., related_entity_type, related_entity_id)
--     values (..., 'BoOkInG', '77777777-7777-7777-7777-777777777777');   -- ACCEPTED
--     select count(*) from tasks t where not exists (select 1 from bookings b where b.id = t.related_entity_id);
--       -> 1   (a task pointing at a booking that does not exist)
-- The discriminator was free text, so 'booking' / 'Booking' / 'BoOkInG' were three different
-- things, and the id was unconstrained, so it could name a row in another tenant or no row at all.
--
-- WHY THE SHAPE WAS KEPT. The obvious fix is the typed-FK pattern `document_links` already uses
-- (one nullable FK column per target plus a CHECK that exactly one is set), and that was the
-- starting assumption. It was rejected on evidence: `29_relationship_map.md` states the domain
-- intent explicitly — "Task may relate to **any** business entity via related_entity_type /
-- related_entity_id". Enumerating targets as columns contradicts that intent and makes every new
-- relatable entity a schema migration. Changing canon to suit an implementation preference is
-- exactly backwards, so the shape stays and the guarantees are added to it instead.
--
-- WHAT IS ENFORCED NOW, by trigger, on tasks / notifications / approval_requests:
--   1. PAIRING      — type and id are both present or both absent; a half-set reference is refused.
--   2. VOCABULARY   — the type must be an ACTIVE value of the new `related_entity_type` catalog
--                     family, so casing and spelling variants are impossible (SPEC-126/127 rules).
--   3. EXISTENCE    — a row with that id must actually exist in the named table.
--   4. TENANT       — and it must belong to the SAME tenant as the referring row, which closes on
--                     the polymorphic side the hole SPEC-129 closed for real foreign keys.
--
-- HOW THE TARGET TABLE IS RESOLVED, without a mapping table to drift out of sync: the catalog code
-- is singular (matching both `document_link_target_type` and the values ORVION's own RPCs already
-- write — `'lead'`, `'booking_item'`), and the table is `code || 's'`. That derivation is not
-- assumed: all fourteen values were verified against `to_regclass` and against the presence of a
-- `tenant_id` column before being seeded, and the trigger re-checks `to_regclass` at run time and
-- raises a clear error rather than silently skipping if a future value ever fails to resolve.
--
-- WHAT THIS DELIBERATELY DOES NOT DO. A trigger cannot provide ON DELETE behaviour. That costs
-- ORVION nothing: it is an archive-not-delete system — no `app.*` RPC issues DELETE anywhere
-- (verified across all 95 migrations), and SPEC-124 removed DELETE from `authenticated` entirely.
-- There is no path by which a referenced row can be physically removed, so the one guarantee a
-- real FK would add over this trigger has no scenario in which it applies.

-- ---------------------------------------------------------------------------------------------
-- 1. The controlled vocabulary for what a task / notification / approval can be about.
-- ---------------------------------------------------------------------------------------------
insert into public.catalog_types (code, name, ownership_type)
values ('related_entity_type', 'Related Entity Type', 'system');

insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_system)
select 'related_entity_type', v.code, initcap(replace(v.code, '_', ' ')), v.ord, true
from (values
    ('customer', 1), ('lead', 2), ('booking', 3), ('booking_item', 4),
    ('quotation', 5), ('invoice', 6), ('payment', 7), ('refund', 8),
    ('passenger', 9), ('supplier', 10), ('conversation', 11), ('complaint', 12),
    ('service_request', 13), ('document', 14)
) as v(code, ord);

-- ---------------------------------------------------------------------------------------------
-- 2. The enforcement.
-- ---------------------------------------------------------------------------------------------
create or replace function app.enforce_entity_reference()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_type_col text := tg_argv[0];
    v_id_col   text := tg_argv[1];
    v_new jsonb := to_jsonb(new);
    v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else null end;
    v_type text := v_new ->> v_type_col;
    v_id   text := v_new ->> v_id_col;
    v_tenant text := v_new ->> 'tenant_id';
    v_table text;
    v_exists boolean;
begin
    -- Skip when neither side changed on an UPDATE: a reference that was valid when written stays
    -- valid, and re-validating it would make unrelated edits fail if the vocabulary later changed.
    if tg_op = 'UPDATE'
       and v_old ->> v_type_col is not distinct from v_type
       and v_old ->> v_id_col   is not distinct from v_id then
        return new;
    end if;

    -- 1. Pairing.
    if v_type is null and v_id is null then
        return new;
    end if;
    if v_type is null or v_id is null then
        raise exception '%: % and % must be set together (got type=%, id=%)',
            tg_table_name, v_type_col, v_id_col, coalesce(v_type,'<null>'), coalesce(v_id,'<null>')
            using errcode = 'check_violation';
    end if;

    -- 2. Vocabulary.
    if not exists (
        select 1 from public.catalog_values cv
        where cv.catalog_type_code = 'related_entity_type'
          and cv.code = v_type
          and cv.is_active
          and cv.tenant_id is null
    ) then
        raise exception '%.%: "%" is not an active related_entity_type',
            tg_table_name, v_type_col, v_type
            using errcode = 'check_violation';
    end if;

    -- 3/4. Existence and tenant, in the table the code names.
    v_table := v_type || 's';
    if to_regclass('public.' || quote_ident(v_table)) is null then
        raise exception '%.%: related_entity_type "%" resolves to table public.% which does not exist',
            tg_table_name, v_type_col, v_type, v_table
            using errcode = 'check_violation';
    end if;

    execute format(
        'select exists (select 1 from public.%I where id = $1::uuid and tenant_id = $2::uuid)', v_table)
        into v_exists using v_id, v_tenant;

    if not v_exists then
        raise exception '%: % "%" does not identify a % in this tenant',
            tg_table_name, v_id_col, v_id, v_type
            using errcode = 'foreign_key_violation';
    end if;

    return new;
end;
$$;

revoke execute on function app.enforce_entity_reference() from public;

create trigger tasks_enforce_entity_reference
    before insert or update on public.tasks
    for each row execute function app.enforce_entity_reference('related_entity_type', 'related_entity_id');

create trigger notifications_enforce_entity_reference
    before insert or update on public.notifications
    for each row execute function app.enforce_entity_reference('related_entity_type', 'related_entity_id');

create trigger approval_requests_enforce_entity_reference
    before insert or update on public.approval_requests
    for each row execute function app.enforce_entity_reference('related_entity_type', 'related_entity_id');
