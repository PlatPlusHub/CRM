-- Migration: archive_authority
-- Plan reference: SPEC-150. Governs archiving, which in ORVION is what deletion is.
--
-- THE DEFECT, REPRODUCED. An ordinary employee ran, as plain SQL:
--
--     update public.bookings  set is_archived = true, archived_at = now() where id = ...;
--     update public.customers set is_archived = true, archived_at = now() where id = ...;
--
-- Both succeeded, with **zero events**, no authorization, and `archived_by` left null. The same
-- employee then un-archived the booking. Canon's policy is that business records are archive-oriented
-- rather than delete-oriented -- `authenticated` correctly holds no DELETE grant on any table -- which
-- makes archiving the deletion mechanism. An unauthorized, unattributed archive is therefore an
-- unauthorized, unattributed deletion, and an unaudited restore alongside it.
--
-- Thirteen tables carry `is_archived`. Exactly one of them, `documents`, had a governed path
-- (`app.archive_document` -> `ARCHIVE_DOCUMENT`). The other twelve had none at all.
--
-- WHERE THE AUTHORITY COMES FROM. Canon 28 already establishes archiving as a management act and
-- gives it a role profile: `ARCHIVE_DOCUMENT` is Owner / CEO / Branch Manager / Department Manager /
-- Finance Manager **Yes**, Senior Employee *Optional*, Employee **No**, Trainee **No**. Canon simply
-- never enumerated the other twelve entities. `ARCHIVE_RECORD` extends that existing, canon-defined
-- profile to them rather than inventing a new rule -- the same move SPEC-146 made with
-- `VIEW_DEPARTMENT_RECORDS`, and for the same reason: the principle is canonical, only the entity
-- list was incomplete. It is granted to exactly the roles canon 28 gives `ARCHIVE_DOCUMENT`.
--
-- `documents` keeps `ARCHIVE_DOCUMENT`, because canon names it.
--
-- ATTRIBUTION IS STAMPED, NOT ASKED FOR. `archived_at` and `archived_by` are system-generated facts,
-- and the directive is explicit that employees should not be made to maintain those by hand. The
-- trigger sets both, and clears both on restore, so an archived row always says who archived it and
-- when -- which is what makes the act attributable even though no event is emitted (see Notes).

insert into public.permissions (key, name, description, is_system, is_active)
values ('ARCHIVE_RECORD',
        'Archive a business record',
        'Archive or restore a business record. ORVION is archive-oriented rather than delete-oriented '
        '(no role holds DELETE), so this is the capability that governs removing a record from active '
        'use. Extends canon 28''s ARCHIVE_DOCUMENT profile to the twelve archivable entities canon '
        'does not enumerate; documents keep ARCHIVE_DOCUMENT.',
        true, true)
on conflict (key) do nothing;

-- The same five roles canon 28 gives ARCHIVE_DOCUMENT. Employee and trainee are excluded, which is
-- the whole point: an employee could previously erase a customer.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.key = 'ARCHIVE_RECORD'
where r.code in ('owner', 'ceo', 'branch_manager', 'department_manager', 'finance_manager')
on conflict do nothing;

create or replace function app.enforce_archive_authority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_permission text;
    v_actor uuid;
begin
    -- Platform paths are outside per-table enforcement (canon 35 principle 6), as in SPEC-145/149.
    if (select auth.uid()) is null then
        return new;
    end if;
    if new.is_archived is not distinct from old.is_archived then
        return new;
    end if;

    v_permission := case when tg_table_name = 'documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end;
    perform app.authorize(v_permission);

    -- Restoring is the same authority as archiving: a control that let anyone un-archive would make
    -- the archive itself meaningless.
    v_actor := app.current_user_id();
    if new.is_archived then
        new.archived_at := coalesce(new.archived_at, now());
        new.archived_by := coalesce(new.archived_by, v_actor);
    else
        new.archived_at := null;
        new.archived_by := null;
    end if;

    return new;
end
$$;
revoke execute on function app.enforce_archive_authority() from public;

do $$
declare r record;
begin
    for r in
        select c.relname
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
        join pg_attribute a on a.attrelid = c.oid and a.attname = 'is_archived' and not a.attisdropped
        where c.relkind = 'r'
        order by c.relname
    loop
        execute format(
            'create trigger %I before update on public.%I for each row execute function app.enforce_archive_authority()',
            r.relname || '_enforce_archive_authority', r.relname);
    end loop;
end
$$;
