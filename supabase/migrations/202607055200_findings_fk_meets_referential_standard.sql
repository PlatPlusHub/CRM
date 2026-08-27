-- WP-04-D correction -- `document_storage_findings_version_fkey` returns to ON DELETE RESTRICT.
--
-- WHAT HAPPENED, recorded rather than quietly amended. `202607054900` gave that constraint
-- `on delete set null (document_version_id)` to solve a real problem: the finding names the version
-- that §5 is about to destroy, so RESTRICT meant the finding forbade the deletion it existed to
-- authorize. The pgTAP suite passed. The SMOKE TEST then failed:
--
--     CHECK 7 FAILED: 1 public FK(s) deviate from the Referential Action Standard
--
-- The standard (canon 30, enforced by `scripts/verify_database.sql`) is that every public FK is
-- `on update no action` and `on delete restrict`, with exactly two NAMED exceptions, both of them
-- about `auth.users` -- a table ORVION does not own and whose deletions it cannot prevent.
--
-- TWO WAYS OUT, AND WHY THE GUARD WON. Adding a third named exception would have been one line and
-- would have been wrong: the standard's value is that it has no exceptions ORVION chose for its own
-- convenience, and the moment a package can buy itself one, the next package can too. The same
-- reasoning already applies once in this repository -- SPEC-158 met an exception-free RLS invariant
-- and wrote a deny-all policy rather than an exemption.
--
-- The other way out costs one statement and no exception: the function that destroys the version
-- releases the reference FIRST, explicitly, where a reader can see it happen. That is strictly
-- better than the FK action, because `set null` was silent -- it nulled the column as a side effect
-- of a DELETE three lines away -- while this states the intent at the point of intent.
--
-- The AUDIT PROPERTY is unchanged and is the reason neither CASCADE nor deleting the finding was
-- ever a candidate: the finding survives the destruction it authorized, keeping `tenant_id`,
-- `storage_path`, `details` and its resolution. It stops pointing at a row that no longer exists;
-- it does not stop existing.

alter table public.document_storage_findings
    drop constraint document_storage_findings_version_fkey;

alter table public.document_storage_findings
    add constraint document_storage_findings_version_fkey
        foreign key (tenant_id, document_version_id)
        references public.document_versions (tenant_id, id)
        on delete restrict on update no action;

-- ---------------------------------------------------------------------------------------------
-- The resolver releases every reference to the version before destroying it. Set-based rather than
-- limited to the finding being resolved: a single path can legitimately carry more than one finding
-- over its life -- a `missing_object` raised when a PUT failed, and later a `retention_expired`
-- once the re-uploaded version aged out -- and a RESTRICT that is only partly released is a
-- RESTRICT that still fires.
-- ---------------------------------------------------------------------------------------------
create or replace function app.platform_resolve_storage_finding(
    p_finding_id uuid,
    p_resolution_code text,
    p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $fn$
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

            -- Release the references BEFORE the delete. This replaces the FK's `on delete set
            -- null`, which failed the Referential Action Standard -- see this migration's header.
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
           resolution_note = p_note
     where id = p_finding_id;

    return p_resolution_code;
end;
$fn$;

revoke execute on function app.platform_resolve_storage_finding(uuid, text, text) from public;
grant  execute on function app.platform_resolve_storage_finding(uuid, text, text) to service_role;
