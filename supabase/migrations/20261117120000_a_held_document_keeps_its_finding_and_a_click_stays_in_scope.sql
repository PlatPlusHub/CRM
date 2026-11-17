-- RET-5, ATTR-5, ATTR-6 -- Batch 6 slice 55 (`document_storage_findings`, `attribution_clicks`).
--
-- THE RULE. A legal hold is stronger than every configured retention period (RET-1/RET-2,
-- `20260909180403`): while a document is held no version of it enters the retention-deletion
-- queue and an already-recorded candidate may not be claimed. `app.platform_resolve_storage_finding`
-- (SECURITY DEFINER, `service_role` only) closes a finding and, for `retention_expired` +
-- `object_deleted`, deletes the version's metadata. An attribution click is first-touch acquisition
-- lineage: `app.capture_attribution_click` (SECURITY DEFINER, `orvion_integration` only) records it
-- for one lead and anchors that lead's `attribution_click_id`; `authenticated` holds SELECT only.
-- Measured before this migration (local stack, `probe-02.log`):
--   RET-5   on a retention finding recorded before the hold was placed, the resolver deleted the
--           held document's version and wrote its destroy event (`object_deleted`: releasing the
--           version reference first slips past the suppression trigger), and returned `dismissed`
--           and `failed` as done while that trigger silently discarded both updates -- the claim
--           excludes held documents, the resolver did not;
--   ATTR-5  a trainee, an employee and a branch manager each read every click of the tenant, gclid,
--           session id and landing page included, for leads their own scope does not show them
--           (the policy was tenant-only);
--   ATTR-6  an employee and the owner set a lead's empty first touch to a click captured for
--           ANOTHER lead; the lineage trigger guards only a value already set.
--
-- THE REPAIR, in existing shapes.
--   RET-5   the resolver refuses every resolution of a `retention_expired` finding whose document
--           is held (23514, as the claim's own exclusion reads), so the finding stays open and
--           claimable after the release. The body is otherwise unchanged.
--   ATTR-5  the tenant-only policy becomes a SELECT `scope_isolation` in the DOC-1/DOC-9 shape: the
--           marketing dashboard holders (VIEW_MARKETING_DASHBOARD, as `marketing_campaigns`) read
--           the tenant's clicks; everyone else reads a click only through a lead the leads policy
--           shows them. The FOR ALL policy granted nothing more: there is no write grant.
--   ATTR-6  `app.guard_lead_lifecycle` (already BEFORE INSERT OR UPDATE on leads, SECURITY DEFINER,
--           the platform paths exempt by `auth.uid() is null`) refuses a member setting
--           `attribution_click_id` to anything but a click captured for this lead (42501, the
--           lineage trigger's code). LEAD-2 and LEAD-4 are unchanged.
--
-- NOT CHANGED: every grant, constraint, foreign key and trigger; `app.capture_attribution_click`,
-- `app.claim_storage_actions`, `app.reconcile_document_storage` and the suppression trigger.
-- Positions recorded, not repaired here: `branch_business_hours` (audited: no range, order,
-- closed-with-times or (branch, day) uniqueness check, `created_at` writable, a row may move between
-- branches of the tenant; nothing reads the hours); the capture accepts a future `clicked_at` and a
-- null consent from its trusted platform caller; a `service_role` direct UPDATE can reopen a
-- finding (platform trust); `offline_conversions` and `app.record_offline_conversion` are their
-- own surfaces.

create or replace function app.platform_resolve_storage_finding(p_finding_id uuid, p_resolution_code text, p_note text default null::text)
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
    v_f record;
begin
    select * into v_f
    from public.document_storage_findings
    where id = p_finding_id;
    if not found then
        raise exception 'unknown finding %', p_finding_id;
    end if;
    if v_f.resolved_at is not null then
        raise exception 'finding % is already resolved', p_finding_id;
    end if;
    if not exists (select 1 from public.catalog_values
                    where catalog_type_code = 'document_storage_finding_resolution'
                      and code = p_resolution_code and is_active) then
        raise exception 'unknown resolution code: %', p_resolution_code;
    end if;

    -- RET-5. A legal hold is stronger than retention (RET-1/RET-2): the claim already skips a held
    -- document's candidate, and the resolver refuses it too, for every resolution. Deleting would
    -- destroy held evidence; a dismissal or a failure would be discarded by the suppression trigger
    -- while this function reported it as done.
    if v_f.finding_type_code = 'retention_expired'
       and exists (select 1
                     from public.document_versions dv
                     join public.documents d
                       on d.tenant_id = dv.tenant_id and d.id = dv.document_id
                    where dv.tenant_id = v_f.tenant_id
                      and dv.id = v_f.document_version_id
                      and d.legal_hold_active) then
        raise exception 'the document of finding % is under legal hold; its retention finding stays open until the hold is released',
                        p_finding_id
            using errcode = 'check_violation';
    end if;

    -- FND-1. A failure is an ATTEMPT, not an outcome. It records what happened and returns without
    -- touching `resolved_at`, so the finding is still open, still claimable, and still counted.
    if p_resolution_code = 'failed' then
        update public.document_storage_findings
           set attempt_count   = attempt_count + 1,
               last_attempt_at = now(),
               last_error      = p_note
         where id = p_finding_id;
        return 'failed';
    end if;

    -- The metadata removal. Deliberately narrow: only a retention-expired finding, only on a
    -- confirmed deletion. An `orphan_object` finding has no version row to remove, and a
    -- `missing_object` finding must NOT remove one -- the object is what is missing, and the
    -- metadata is the only remaining evidence that it ever existed.
    if v_f.finding_type_code = 'retention_expired' and p_resolution_code = 'object_deleted' then
        if v_f.document_version_id is not null then
            -- THE SUBSCRIPTION GATE APPLIES TO THIS DELETE, AND IS CHECKED HERE RATHER THAN
            -- TRIPPED OVER. `document_versions_enforce_document_subscription_gate` fires BEFORE
            -- DELETE and has NO system-path exemption; WP-03 settled deliberately that the gate is
            -- the boundary and batch callers skip lapsed tenants
            -- (`36_subscription_gate_system_paths_test.sql`). Refusing explicitly turns an opaque
            -- 42501 from a trigger three layers down into a message the executor can act on.
            -- Consequence, stated: a tenant that never returns to good standing keeps its
            -- superseded versions forever. That is RET-2, a business decision, not a guess.
            if not app.subscription_allows_write(v_f.tenant_id) then
                raise exception
                    'tenant % is in a restricted subscription state; its stored data is frozen '
                    'for reading and export only, so this version will not be destroyed',
                    v_f.tenant_id
                    using errcode = 'insufficient_privilege';
            end if;

            -- Re-check eligibility at the moment of destruction rather than trusting the finding.
            -- A version can have been promoted back to current between the scan and this call, and
            -- destroying the live version of a document because a day-old finding said so is
            -- exactly the irreversible mistake this whole package exists to prevent.
            if exists (select 1
                         from public.document_versions dv
                         join public.documents d
                           on d.tenant_id = dv.tenant_id and d.id = dv.document_id
                        where dv.id = v_f.document_version_id
                          and (dv.is_current or d.current_version_id = dv.id)) then
                raise exception 'version % is current again and will not be destroyed',
                                v_f.document_version_id;
            end if;

            -- Release the references BEFORE the delete (`202607055200`: the FK is RESTRICT, and the
            -- Referential Action Standard has no exception for this table).
            update public.document_storage_findings
               set document_version_id = null
             where document_version_id = v_f.document_version_id;

            delete from public.document_versions where id = v_f.document_version_id;

            perform app.record_event(
                v_f.tenant_id, 'document_archived', 'document',
                (v_f.details ->> 'document_id')::uuid, null,
                'superseded', 'destroyed',
                'retention window elapsed; object destroyed by the storage executor',
                jsonb_build_object('storage_path', v_f.storage_path,
                                   'version_number', v_f.details -> 'version_number',
                                   'retention_days', v_f.details -> 'retention_days'),
                'warning');
        end if;
    end if;

    update public.document_storage_findings
       set resolved_at = now(),
           resolution_code = p_resolution_code,
           resolution_note = p_note,
           last_attempt_at = now()
     where id = p_finding_id;

    return p_resolution_code;
end;
$function$;

drop policy tenant_isolation on public.attribution_clicks;

create policy scope_isolation on public.attribution_clicks
    for select to authenticated
    using (
        tenant_id = (select app.current_tenant_id())
        and (
            (select app.has_permission('VIEW_MARKETING_DASHBOARD'))
            or (lead_id is not null
                and exists (select 1 from public.leads l
                             where l.id = attribution_clicks.lead_id
                               and l.tenant_id = attribution_clicks.tenant_id))
        )
    );

create or replace function app.guard_lead_lifecycle()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
    -- Platform/system paths (canon 35 principle 6): seeds, migrations, `service_role` and the
    -- session-less jobs build lead state directly and are outside per-table enforcement.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- ATTR-6. The first touch is the click captured FOR THIS LEAD. `app.capture_attribution_click`
    -- is the only writer of a click and anchors it; the lineage trigger keeps a value once set, and
    -- this keeps a member from setting an empty one to a click captured for another lead.
    if new.attribution_click_id is not null
       and (tg_op = 'INSERT' or old.attribution_click_id is distinct from new.attribution_click_id)
       and not exists (
           select 1 from public.attribution_clicks c
           where c.id = new.attribution_click_id
             and c.tenant_id = new.tenant_id
             and c.lead_id = new.id
       )
    then
        raise exception
            'a lead''s first touch is the click captured for that lead (app.capture_attribution_click); '
            'click % was not captured for lead %',
            new.attribution_click_id, new.id
            using errcode = '42501';
    end if;

    -- LEAD-2. A lead enters the pipeline at `new`. Not invented: `app.create_lead` is the only
    -- sanctioned writer and hardcodes it, and canon 26 makes `new` the initial state. Without this
    -- the transition graph is enforced only for leads that entered through the graph.
    if tg_op = 'INSERT' and new.lead_status_code is distinct from 'new' then
        raise exception
            'a lead enters the pipeline at ''new'' (canon 26); it was created as ''%'' -- use '
            'app.assign_lead / app.advance_lead / app.convert_lead to move it',
            new.lead_status_code
            using errcode = '23514';
    end if;

    -- LEAD-4. `assigned -> contacted` is CAUSED, not chosen. It is the one edge no RPC offers:
    -- `app.advance_lead` refuses it by name, and `app.record_lead_interaction` produces it only as a
    -- consequence of a qualifying interaction. Flipping it by hand takes the lead out of
    -- `app.process_lead_sla`'s working set (it scans `lead_status_code = 'assigned'`) with no
    -- evidence of contact anywhere.
    --
    -- The qualifying set is transcribed from `app.record_lead_interaction`, which took it from
    -- canon 26. This asks only that the evidence EXIST -- it does not decide LI-3's open question of
    -- whether a direct INSERT should itself advance the lifecycle.
    if tg_op = 'UPDATE'
       and old.lead_status_code = 'assigned' and new.lead_status_code = 'contacted'
       and not exists (
           select 1 from public.lead_interactions li
           where li.lead_id = new.id
             and li.tenant_id = new.tenant_id
             and li.interaction_type_code in
                 ('phone_call', 'whatsapp_message', 'chat_opened', 'customer_reply')
       )
    then
        raise exception
            'a lead becomes ''contacted'' by a qualifying interaction, not by assertion (canon 10/26); '
            'use app.record_lead_interaction'
            using errcode = '23514';
    end if;

    return new;
end;
$function$;
