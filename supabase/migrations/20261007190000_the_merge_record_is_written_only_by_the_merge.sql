-- Batch 6 slice 31 -- `customer_identity_merges`: the merge record is written only by the merge.
--
-- ================================================================================================
-- WHY
--
-- The merge record is no longer only history. Since SPEC-240 (PH8-4) `app.customer_consent_status`
-- reads it to decide which identities form one logical customer, and `app.record_customer_consent`
-- refuses a decision on an identity it names as merged. Two doors could still change it without a
-- merge happening.
--
-- MRG-1. `authenticated` held INSERT and UPDATE, guarded only by MERGE_CUSTOMER_IDENTITY. An owner
--   inserted a row naming customer A merged into B. A stayed active, nothing was re-pointed, no
--   `customer_identity_merged` was recorded, and A's recorded DENIED read as B's GRANTED, so the
--   claim released A's qualified phone call to Google. A could no longer record a withdrawal. An
--   UPDATE moved a genuine merge's source, target, reason and time while its event kept the
--   original. The table's one writer is `app.merge_customer_identity`, SECURITY DEFINER, which needs
--   no table grant (`202607056100`'s rule: a write grant is kept exactly where a sanctioned writer
--   needs it). The two grants are revoked; SELECT stays.
--
-- MRG-2. The merge refused a second merge of an identity by its archive flag, a proxy the
--   `customers` door can reverse. An owner merged A into B, un-archived A and merged it into C, so
--   the record named A merged twice; or merged B back into A, a cycle whose two identities read no
--   consent and can record none, a withdrawal included. The merge now also refuses a source or a
--   target the record already names as merged away, read under the locks it already takes. Its body
--   is otherwise unchanged, and its existing refusals keep their order and messages.
-- ================================================================================================

revoke insert, update on public.customer_identity_merges from authenticated;

create or replace function app.merge_customer_identity(p_source_customer_id uuid, p_target_customer_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_src_archived boolean;
    v_target_archived boolean;
    v_merged_into uuid;
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
    -- The record, not the archive flag, says whether an identity was merged away: an un-archived
    -- source is still merged, and merging it, or into it, again would fork or close the lineage the
    -- consent reader follows (MRG-2).
    select m.target_customer_id into v_merged_into from public.customer_identity_merges m
     where m.tenant_id = v_tenant and m.source_customer_id = p_source_customer_id;
    if found then raise exception 'source customer was already merged into %', v_merged_into; end if;
    select m.target_customer_id into v_merged_into from public.customer_identity_merges m
     where m.tenant_id = v_tenant and m.source_customer_id = p_target_customer_id;
    if found then raise exception 'target customer was merged into %', v_merged_into; end if;
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
          -- ADR-0019's documented exclusions: the merge record itself, and consent evidence, which is
          -- never rewritten -- `app.customer_consent_status` follows the merge record instead (PH8-4).
          and n.nspname='public' and cl.relname not in ('customer_identity_merges', 'customer_consents')
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
$function$;
