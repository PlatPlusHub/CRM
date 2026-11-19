-- ARCH-2: extend the existing archive authority to creation on four CRM surfaces.

create or replace function app.enforce_archive_authority()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_permission text; v_actor uuid;
begin
    if (select auth.uid()) is null then return new; end if;
    if tg_op='INSERT' then
        if not new.is_archived
           and (new.archived_at is not null or new.archived_by is not null) then
            raise exception 'archive metadata is set by the server' using errcode='42501';
        end if;
        if new.is_archived or new.archive_reason is not null then
            v_permission:=case when tg_table_name='documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end;
            perform app.authorize(v_permission);
            v_actor:=app.current_user_id();
            if new.is_archived then new.archived_at:=now(); new.archived_by:=v_actor; end if;
        end if;
        return new;
    end if;
    if tg_op='UPDATE' and new.is_archived is not distinct from old.is_archived
       and (new.archived_at is distinct from old.archived_at
            or new.archived_by is distinct from old.archived_by) then
        raise exception 'archive metadata is immutable once the archive state is set' using errcode='42501';
    end if;
    -- Reason is caller-authored, unlike the server-stamped time/actor. Corrections remain
    -- possible, but cost the archive capability even when the boolean does not change.
    if new.is_archived is not distinct from old.is_archived then
        if new.archive_reason is distinct from old.archive_reason then
            perform app.authorize(case when tg_table_name='documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end);
        end if;
        return new;
    end if;
    v_permission:=case when tg_table_name='documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end;
    perform app.authorize(v_permission);
    v_actor:=app.current_user_id();
    if new.is_archived then new.archived_at:=now(); new.archived_by:=v_actor;
    else new.archived_at:=null; new.archived_by:=null; end if;
    return new;
end; $$;

create or replace trigger bookings_enforce_archive_authority
before insert or update on public.bookings
for each row execute function app.enforce_archive_authority();

create or replace trigger passengers_enforce_archive_authority
before insert or update on public.passengers
for each row execute function app.enforce_archive_authority();

create or replace trigger suppliers_enforce_archive_authority
before insert or update on public.suppliers
for each row execute function app.enforce_archive_authority();

create or replace trigger tasks_enforce_archive_authority
before insert or update on public.tasks
for each row execute function app.enforce_archive_authority();
