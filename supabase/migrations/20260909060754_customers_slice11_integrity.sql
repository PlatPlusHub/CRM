-- Batch 6 Slice 11 — customer identity, authority and credit-threshold integrity.
--
-- Four defects were reproduced against the real local doors and then separated from incidental
-- refusals: the sanctioned SECURITY DEFINER merge path was blocked by the invoice identity guard;
-- an archived customer could be selected as a merge survivor; a credit-authorized mixed UPDATE
-- could rename a customer; and concurrent exposure writes could both miss the threshold crossing.

create or replace function app.guard_invoice_integrity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_new jsonb := to_jsonb(new);
    v_old jsonb;
    v_col text;
begin
    -- `merge_customer_identity` is the one sanctioned catalog-driven SECURITY DEFINER path that
    -- must re-point every customer referrer, including invoices. Direct authenticated DML remains
    -- subject to this guard; only the trusted database owner path reaches this branch.
    if current_user = 'postgres' then
        return new;
    end if;
    if (select auth.uid()) is null then
        return new;
    end if;
    if tg_op = 'INSERT' then
        if new.status_code is distinct from 'draft' then
            raise exception
                'an invoice is raised as a draft and issued by app.issue_invoice; it cannot be created already % (canon 26 state machine)',
                new.status_code using errcode = '23514';
        end if;
        return new;
    end if;
    v_old := to_jsonb(old);
    foreach v_col in array array['invoice_number', 'customer_id', 'booking_id', 'booking_item_id',
                                 'currency_code', 'invoice_date', 'corrects_invoice_id'] loop
        if (v_new ->> v_col) is distinct from (v_old ->> v_col) then
            raise exception
                'invoice %.% is fixed when the invoice is created and cannot be changed afterwards; correct the document with a new one (corrects_invoice_id)',
                old.invoice_number, v_col using errcode = '23514';
        end if;
    end loop;
    if new.total_amount is distinct from old.total_amount and old.status_code is distinct from 'draft' then
        raise exception
            'invoice % is % and its total can no longer change; issue a correcting document instead (canon 07: corrections after approval go through a new event, adjustment or reversal)',
            old.invoice_number, old.status_code using errcode = '23514';
    end if;
    return new;
end;
$$;

create or replace function app.guard_customer_credit_authority()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_credit_changed boolean := false;
    v_other_changed boolean := false;
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        perform app.authorize('CREATE_CUSTOMER');
        v_credit_changed := new.credit_limit_amount is not null
                         or new.credit_limit_currency_code is not null;
    else
        v_credit_changed := new.credit_limit_amount is distinct from old.credit_limit_amount
                         or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code;
        -- Server-derived fields are excluded. `derive_first_registration_actor` runs before this
        -- trigger and may legitimately fill the first actor on a credit-only update.
        v_other_changed := (to_jsonb(new) - array['credit_limit_amount','credit_limit_currency_code',
                                                   'updated_at','first_registered_user_id','created_by',
                                                   'archived_at','archived_by','archive_reason'])
                         is distinct from
                         (to_jsonb(old) - array['credit_limit_amount','credit_limit_currency_code',
                                                   'updated_at','first_registered_user_id','created_by',
                                                   'archived_at','archived_by','archive_reason']);
    end if;

    if v_credit_changed then
        perform app.authorize('MANAGE_CUSTOMER_CREDIT');
    end if;
    if v_other_changed then
        perform app.authorize('CREATE_CUSTOMER');
    end if;
    return new;
end;
$$;

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
        if new.is_archived then
            v_permission:=case when tg_table_name='documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end;
            perform app.authorize(v_permission);
            v_actor:=app.current_user_id();
            new.archived_at:=now(); new.archived_by:=v_actor;
        end if;
        return new;
    end if;
    if tg_op='UPDATE' and new.is_archived is not distinct from old.is_archived
       and (new.archived_at is distinct from old.archived_at
            or new.archived_by is distinct from old.archived_by) then
        raise exception 'archive metadata is immutable once the archive state is set' using errcode='42501';
    end if;
    if new.is_archived is not distinct from old.is_archived then return new; end if;
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

create or replace function app.evaluate_customer_credit_threshold(p_tenant_id uuid, p_customer_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
    v_limit numeric; v_currency text; v_name text; v_exposure numeric; v_unconv text[];
    v_last text; v_notif uuid; v_note text := ''; r record;
begin
    if p_tenant_id is null or p_customer_id is null then return; end if;
    -- Serialize threshold decisions per customer. The second writer waits, then re-reads the
    -- committed first write under READ COMMITTED instead of making a duplicate crossing decision.
    select c.credit_limit_amount,c.credit_limit_currency_code,c.full_name
      into v_limit,v_currency,v_name from public.customers c
      where c.id=p_customer_id and c.tenant_id=p_tenant_id for update;
    if v_limit is null or v_currency is null then return; end if;
    select e.exposure,e.unconvertible into v_exposure,v_unconv
      from app.customer_exposure_in_limit_currency(p_tenant_id,p_customer_id,v_currency) e;
    if v_unconv is not null and array_length(v_unconv,1)>0 then
      v_note:=format(' NOTE: exposure held in %s could not be converted (no exchange rate at or before now), so this figure is INCOMPLETE and understates the true exposure.',array_to_string(v_unconv,', '));
    end if;
    select e.event_type_code into v_last from public.events e
      where e.tenant_id=p_tenant_id and e.entity_type='customer' and e.entity_id=p_customer_id
        and e.event_type_code in ('customer_credit_threshold_exceeded','customer_credit_threshold_cleared')
      order by e.seq desc limit 1;
    if v_exposure > v_limit then
      if v_last='customer_credit_threshold_exceeded' then return; end if;
      perform app.record_event(p_tenant_id,'customer_credit_threshold_exceeded','customer',p_customer_id,null,null,null,
        'Customer outstanding receivable rose above its configured credit ceiling',jsonb_build_object('customer_id',p_customer_id,'customer_name',v_name,'currency_code',v_currency,'credit_limit',v_limit,'exposure',v_exposure,'over_by',v_exposure-v_limit,'unconvertible_currencies',to_jsonb(v_unconv),'enforcement','warning_only'),'warning');
      for r in select c.user_id from app.credit_alert_recipients(p_tenant_id) c loop
        insert into public.notifications(tenant_id,target_user_id,notification_type_code,title,body,related_entity_type,related_entity_id)
        values(p_tenant_id,r.user_id,'customer_balance','Customer credit threshold exceeded',format('Customer %s has an outstanding receivable of %s %s against a credit ceiling of %s %s (over by %s %s). This is a warning only - no operation has been blocked.%s',coalesce(v_name,'(unnamed)'),to_char(v_exposure,'FM999999999990.00'),v_currency,to_char(v_limit,'FM999999999990.00'),v_currency,to_char(v_exposure-v_limit,'FM999999999990.00'),v_currency,v_note),'customer',p_customer_id) returning id into v_notif;
        insert into public.notification_deliveries(tenant_id,notification_id,channel_code,delivery_status_code) values(p_tenant_id,v_notif,'email','pending');
      end loop;
    elsif v_last='customer_credit_threshold_exceeded' then
      perform app.record_event(p_tenant_id,'customer_credit_threshold_cleared','customer',p_customer_id,null,null,null,'Customer outstanding receivable returned to or below its configured credit ceiling',jsonb_build_object('customer_id',p_customer_id,'currency_code',v_currency,'credit_limit',v_limit,'exposure',v_exposure,'unconvertible_currencies',to_jsonb(v_unconv)),'info');
    end if;
end;
$$;
