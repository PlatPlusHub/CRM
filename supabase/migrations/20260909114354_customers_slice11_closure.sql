-- Slice 11 closure: serialized identity merges and archive-reason authority.
-- Existing permissions and ADR-0019; no new commercial policy.

create or replace function app.merge_customer_identity(
    p_source_customer_id uuid,
    p_target_customer_id uuid,
    p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_src_archived boolean;
    v_target_archived boolean;
    r record;
    v_sql text;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('MERGE_CUSTOMER_IDENTITY');
    -- Lock both identities before reading lifecycle state. A consistent order prevents opposite
    -- merges from validating stale row versions and archiving both survivors (ADR-0019).
    perform 1 from public.customers
     where tenant_id = v_tenant and id in (p_source_customer_id, p_target_customer_id)
     order by id for update;
    if p_source_customer_id = p_target_customer_id then
        raise exception 'source and target customer must differ';
    end if;
    select is_archived into v_src_archived from public.customers
     where id = p_source_customer_id and tenant_id = v_tenant;
    if not found then raise exception 'source customer is not in your tenant'; end if;
    if v_src_archived then raise exception 'source customer is already archived (merged?)'; end if;
    select is_archived into v_target_archived from public.customers
     where id = p_target_customer_id and tenant_id = v_tenant;
    if not found then raise exception 'target customer is not in your tenant'; end if;
    if v_target_archived then raise exception 'target customer is already archived'; end if;
    select id into v_actor from public.users
     where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- Resolve the two uniqueness collisions that are normal when duplicate identities are merged:
    -- the survivor keeps an existing value and its primary designation; a source-only value is
    -- retained but demoted when the target already has a primary of that type.
    delete from public.customer_contact_methods s
     where s.tenant_id=v_tenant and s.customer_id=p_source_customer_id
       and exists (select 1 from public.customer_contact_methods t
                    where t.tenant_id=v_tenant and t.customer_id=p_target_customer_id
                      and t.contact_method_type_code=s.contact_method_type_code and t.value=s.value);
    update public.customer_contact_methods s set is_primary=false
     where s.tenant_id=v_tenant and s.customer_id=p_source_customer_id and s.is_primary
       and exists (select 1 from public.customer_contact_methods t
                    where t.tenant_id=v_tenant and t.customer_id=p_target_customer_id
                      and t.contact_method_type_code=s.contact_method_type_code and t.is_primary);

    for r in
        select cl.relname as tbl,
               max(a.attname) filter (where fa.attname = 'id') as customer_col,
               max(a.attname) filter (where fa.attname = 'tenant_id') as tenant_col
        from pg_constraint c
        join pg_class cl on cl.oid = c.conrelid
        join pg_namespace n on n.oid = cl.relnamespace
        join unnest(c.conkey) with ordinality lk(attnum,ord) on true
        join unnest(c.confkey) with ordinality fk(attnum,ord) on fk.ord=lk.ord
        join pg_attribute a on a.attrelid=c.conrelid and a.attnum=lk.attnum
        join pg_attribute fa on fa.attrelid=c.confrelid and fa.attnum=fk.attnum
        where c.contype='f' and c.confrelid='public.customers'::regclass
          and n.nspname='public' and cl.relname not in ('customer_identity_merges')
        group by c.oid,cl.relname
    loop
        if r.customer_col is null then
            raise exception 'merge aborted: the foreign key on public.% has no column referencing customers.id', r.tbl;
        end if;
        v_sql := format('update public.%I set %I=$1 where %I=$2',r.tbl,r.customer_col,r.customer_col);
        if r.tenant_col is not null then
            v_sql := v_sql || format(' and %I=$3',r.tenant_col);
            execute v_sql using p_target_customer_id,p_source_customer_id,v_tenant;
        else
            execute v_sql using p_target_customer_id,p_source_customer_id;
        end if;
    end loop;
    insert into public.customer_identity_merges(tenant_id,source_customer_id,target_customer_id,merged_by,reason)
    values(v_tenant,p_source_customer_id,p_target_customer_id,v_actor,p_reason);
    update public.customers set is_archived=true,archived_at=now(),archived_by=v_actor,
      archive_reason=coalesce(p_reason,'merged into '||p_target_customer_id::text),updated_at=now()
      where id=p_source_customer_id;
    perform app.record_event(v_tenant,'customer_identity_merged','customer',p_target_customer_id,v_actor,null,null,p_reason,
      jsonb_build_object('source_customer_id',p_source_customer_id,'target_customer_id',p_target_customer_id),'critical');
    return p_target_customer_id;
end;
$$;

create or replace function app.enforce_archive_authority()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_permission text; v_actor uuid;
begin
    if (select auth.uid()) is null then return new; end if;
    if tg_op='INSERT' then
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

drop trigger if exists customers_enforce_archive_authority on public.customers;
create trigger customers_enforce_archive_authority
before insert or update on public.customers
for each row execute function app.enforce_archive_authority();

