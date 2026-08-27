-- WP-04-D -- document retention, deletion, recovery and orphan reconciliation.
--
-- ================================================================================================
-- THE DECISIVE FACT, DISCOVERED LIVE BEFORE ANY OF THIS WAS DESIGNED
--
-- The database CANNOT delete an object. Two independent proofs, both re-read from the live
-- Primary and the local stack on 2026-08-27:
--
--   1. Supabase installs `storage.protect_delete()` as a BEFORE DELETE trigger on BOTH
--      `storage.objects` and `storage.buckets`. It raises 42501 -- "Direct deletion from storage
--      tables is not allowed. Use the Storage API instead." -- unless the session GUC
--      `storage.allow_delete_query` is set to 'true'. Its own HINT states the platform's reason,
--      which is identical to ours: "This prevents accidental data loss from orphaned objects."
--
--   2. `pg_net` is NOT installed on either environment (`pg_extension` holds moddatetime, pg_cron,
--      pg_stat_statements, pgcrypto, supabase_vault, uuid-ossp, plpgsql -- and locally pgtap).
--      So the database cannot reach the Storage HTTP API either.
--
-- A SECURITY DEFINER function COULD carry `set storage.allow_delete_query = 'true'` and delete the
-- row anyway. That is not done, for two reasons and neither is squeamishness:
--
--   * It would defeat a security control the platform installed deliberately. The owner's standing
--     instruction is explicit -- do not work around security controls.
--   * It would not even work. Deleting the `storage.objects` row removes ORVION's only record of
--     the object's name; the bytes in S3 survive, now unnameable and unbillable-to-anyone. We would
--     have manufactured the exact orphan this package exists to detect.
--
-- THEREFORE the split this migration implements, which is architecture and not compromise:
--
--     THE DATABASE OWNS THE DECISION.   An external executor owns the BYTES.
--
--   The database decides WHAT must happen to which object, under whose authority, against which
--   retention rule, with a durable audit trail. It records that decision as a finding. An external
--   actor holding the service key (the future client, an Edge Function, or n8n) performs the byte
--   operation through the Storage API and reports the outcome back through one service_role RPC.
--
--   Physical byte deletion is therefore classified BLOCKED -- MISSING PLATFORM CAPABILITY from the
--   database's side. It is recorded in MASTER_GAP_REGISTER.md as DEL-1. Everything that does NOT
--   depend on it is built here and tested here, per the owner directive: "DO NOT stop the entire
--   technical work because the exact period is unknown."
--
-- ================================================================================================
-- WHY RECONCILIATION IS NEEDED AT ALL
--
-- `app.upload_document` / `app.add_document_version` write metadata in one transaction. The bytes
-- are PUT afterwards, over HTTP, by a different actor. Nothing joins those two events into one
-- atomic unit and nothing can -- WP-04-B already recorded that we will not claim transactional
-- guarantees across an external object store, because they do not exist. So both halves of the
-- discrepancy are physically reachable the moment a client exists:
--
--   metadata without object  -- the transaction committed and the PUT failed, or was abandoned.
--   object without metadata  -- the PUT succeeded and the transaction later rolled back.
--
-- Today Primary holds ZERO objects (verified live), so the window is not yet open in practice.
-- This lands before it is.
-- ================================================================================================

-- ---------------------------------------------------------------------------------------------
-- 1. Vocabulary.
-- ---------------------------------------------------------------------------------------------
insert into public.catalog_types (code, name, ownership_type, description, is_active)
values ('document_storage_finding_type', 'Document Storage Finding Type', 'system',
        'Class of discrepancy or due action found by document storage reconciliation.', true),
       ('document_storage_finding_resolution', 'Document Storage Finding Resolution', 'system',
        'How a document storage finding was closed by the external storage executor.', true);

insert into public.catalog_values
    (tenant_id, catalog_type_code, code, label, description, sort_order, is_active, is_system)
values
    (null, 'document_storage_finding_type', 'missing_object', 'Missing Object',
     'A document_versions row whose storage_path has no object in the bucket.', 1, true, true),
    (null, 'document_storage_finding_type', 'orphan_object', 'Orphan Object',
     'An object in the bucket with no document_versions row naming it.', 2, true, true),
    (null, 'document_storage_finding_type', 'retention_expired', 'Retention Expired',
     'A superseded version whose retention window has elapsed and may now be destroyed.', 3, true, true),
    (null, 'document_storage_finding_type', 'tenant_scan_failed', 'Tenant Scan Failed',
     'Reconciliation raised while scanning one tenant; other tenants were unaffected.', 4, true, true),

    (null, 'document_storage_finding_resolution', 'object_deleted', 'Object Deleted',
     'The executor destroyed the object through the Storage API.', 1, true, true),
    (null, 'document_storage_finding_resolution', 'object_restored', 'Object Restored',
     'The missing object was re-uploaded, so the metadata is whole again.', 2, true, true),
    (null, 'document_storage_finding_resolution', 'dismissed', 'Dismissed',
     'Reviewed by the Platform Owner and deliberately closed with no storage action.', 3, true, true),
    (null, 'document_storage_finding_resolution', 'failed', 'Failed',
     'The executor attempted the storage action and it failed. Stays discoverable.', 4, true, true);

-- ---------------------------------------------------------------------------------------------
-- 2. The retention rule.
--
--    NULL means UNDECIDED, and undecided means RETAIN FOREVER. This is the whole safety property
--    the owner asked for -- "retention policy cannot accidentally become 'delete immediately'" --
--    expressed as the DEFAULT rather than as a validation someone can forget to run. With no
--    decision recorded, §5 selects zero rows for destruction, forever, by construction.
--
--    The Egyptian record-keeping obligation for travel documents is not in canon and is not
--    inventable from evidence. It is BLOCKED -- BUSINESS DECISION (gap register: RET-1). When the
--    owner decides, exactly one line of exactly one migration changes, and nothing else does.
--
--    A floor of 1 day is asserted in `49_document_retention_test.sql` rather than clamped here: a
--    silent clamp would hide a mistaken value, whereas a failing test shows it to the person who
--    typed it.
-- ---------------------------------------------------------------------------------------------
create or replace function app.document_retention_days()
returns integer
language sql
immutable
set search_path = ''
as $fn$
    select null::integer;
$fn$;

-- REVOKED, and this line was missing on the first run. `10_grant_model_test.sql` assertion 5 failed
-- immediately: a bare `create function` leaves `proacl` null, which PostgreSQL reads as the default
-- ACL -- EXECUTE to PUBLIC. That is the SAME root cause as POL-1 in the migration beside this one:
-- the language's silent default is PUBLIC, and an omitted clause is therefore not a no-op but a
-- grant. Two independent instances in one package is what makes it a class rather than a slip.
revoke execute on function app.document_retention_days() from public;
grant  execute on function app.document_retention_days() to service_role;

comment on function app.document_retention_days() is
    'Days a superseded document version is retained before it may be destroyed. NULL = the business '
    'decision is open, which means retain forever and destroy nothing (WP-04-D, gap RET-1).';

-- ---------------------------------------------------------------------------------------------
-- 3. The findings store.
--
--    ONE table, not two, because all four finding types are the same thing: the database has
--    determined that a named storage path needs an action only an external actor can perform.
--    Splitting "discrepancy" from "due action" would have produced two tables with identical
--    columns, two RLS policies to keep in step, and a second sibling to forget -- which is the
--    precise defect class that has now bitten this programme three times.
-- ---------------------------------------------------------------------------------------------
create table public.document_storage_findings (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null references public.tenants (id) on delete restrict on update no action,

    finding_type_code text not null,

    -- Null only for `tenant_scan_failed`, which is about a tenant rather than about one path.
    storage_path text,

    -- TENANT-QUALIFIED FK (SPEC-130 / `14_tenant_qualified_fk_test.sql`). Nullable because an
    -- orphan object by definition has no version row -- that is what makes it an orphan.
    --
    -- SUPERSEDED BY `202607055200`: this constraint is now back to ON DELETE RESTRICT, and the
    -- resolver releases the reference explicitly instead. The reasoning below is preserved because
    -- it is still why the problem exists; what changed is where it is solved. The smoke test's
    -- Referential Action Standard (CHECK 7) rejected `set null` after the pgTAP suite had passed --
    -- see that migration's header. Read the two together.
    --
    -- `on delete set null (document_version_id)` -- the ONE place in ORVION that is not RESTRICT,
    -- and deliberately so. Written as RESTRICT first, which deadlocked the package against itself:
    -- §5 destroys a version precisely when a finding names it, so RESTRICT meant the finding
    -- forbade the deletion it existed to authorize. Caught by `49_document_retention_test.sql` on
    -- its first run. CASCADE was the wrong escape -- it would erase the audit record of the
    -- destruction at the moment of destruction. The column list form (PostgreSQL 15+) nulls ONLY
    -- the dangling id and leaves `tenant_id` and `storage_path` intact, so the finding survives as
    -- the permanent record that this exact path once existed and was destroyed under retention.
    document_version_id uuid,
    constraint document_storage_findings_version_fkey
        foreign key (tenant_id, document_version_id)
        references public.document_versions (tenant_id, id)
        on delete set null (document_version_id) on update no action,

    first_seen_at timestamptz not null default now(),
    last_seen_at  timestamptz not null default now(),

    resolved_at     timestamptz,
    resolution_code text,
    resolution_note text,

    details jsonb,

    -- A resolution without a time, or a time without a resolution, is a half-written record.
    constraint document_storage_findings_resolution_complete
        check ((resolved_at is null) = (resolution_code is null)),

    -- Only the tenant-scan failure may omit the path; every other type IS about a path.
    constraint document_storage_findings_path_present
        check ((finding_type_code = 'tenant_scan_failed') = (storage_path is null))
);

-- IDEMPOTENCY, expressed as a constraint rather than as care. Re-running reconciliation any number
-- of times touches `last_seen_at` and creates nothing, so the scheduled job is safe to run again
-- after a partial failure, and safe to run manually while it is already running.
create unique index document_storage_findings_identity_key
    on public.document_storage_findings (tenant_id, finding_type_code, coalesce(storage_path, ''));

-- `04_tenant_id_index_coverage_test.sql`: leading column must be tenant_id.
create index document_storage_findings_open_idx
    on public.document_storage_findings (tenant_id, resolved_at)
    where resolved_at is null;

comment on table public.document_storage_findings is
    'Storage discrepancies and due retention actions found by app.reconcile_document_storage. The '
    'database records the decision here; an external executor performs the byte operation through '
    'the Storage API and reports back via app.platform_resolve_storage_finding (WP-04-D).';

alter table public.document_storage_findings enable row level security;
revoke all on table public.document_storage_findings from anon, authenticated;

-- Deny-all, the SPEC-158 shape. A tenant user must never read these: `orphan_object` rows name
-- paths that no longer have a version row, so they are outside every scope rule the document
-- policies express, and `missing_object` rows are operational intelligence about the platform's
-- own reliability. The two functions below are SECURITY DEFINER and reach the table as its owner.
-- This is also a second lock -- a future accidental grant still returns nothing.
create policy platform_only on public.document_storage_findings
    for all to authenticated using (false) with check (false);

grant select, insert, update on table public.document_storage_findings to service_role;

-- DELIBERATELY EXEMPT from the subscription write gate, and added to the exemption list in
-- `35_subscription_write_gate_test.sql` §19/§20 rather than left to fail that guard silently. This
-- is a PLATFORM operational record that happens to carry a tenant_id, not tenant data: gating it
-- would mean a lapsed tenant's storage discrepancies stop being detectable, which is exactly
-- backwards -- a lapsed tenant is MORE likely to hold orphaned objects, and reconciliation is how
-- the platform manages its own storage bill. Same reasoning as `usage_counters` and
-- `notification_deliveries`, which are exempt for the same reason.

-- ---------------------------------------------------------------------------------------------
-- 4. Reconciliation.
--
--    THE WP-03 SHAPE: skip, never raise. A raising enforcement mechanism is right for a user's own
--    write and dangerous inside a cross-tenant batch, because one bad tenant would abort every
--    other tenant's scan and the job would never make progress again. Each tenant is scanned in its
--    own BEGIN/EXCEPTION block; a failure is RECORDED as a finding and the loop continues.
--
--    Note what that costs and why it is still right: the exception handler rolls back only the
--    failing tenant's sub-block, so the findings already inserted for earlier tenants survive.
--
--    SECURITY DEFINER and service_role-only. It reads across every tenant, which is precisely the
--    authority no tenant user may ever hold.
-- ---------------------------------------------------------------------------------------------
create or replace function app.reconcile_document_storage()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    t              record;
    v_retention    integer := app.document_retention_days();
    v_bucket       text    := app.document_bucket();
    v_missing      integer := 0;
    v_orphan       integer := 0;
    v_expired      integer := 0;
    v_tenants      integer := 0;
    v_failed       integer := 0;
    v_n            integer;
begin
    -- A zero or negative retention would mean "destroy on sight". Treated as undecided rather than
    -- obeyed: the safe reading of a nonsensical policy is to do nothing. `49_..._test.sql` fails if
    -- the function ever returns such a value, so the mistake surfaces instead of being absorbed.
    if v_retention is not null and v_retention < 1 then
        v_retention := null;
    end if;

    for t in select id from public.tenants order by id loop
        v_tenants := v_tenants + 1;
        begin
            -- ------------------------------------------------------------------------------
            -- A. Metadata without an object.
            -- ------------------------------------------------------------------------------
            insert into public.document_storage_findings
                (tenant_id, finding_type_code, storage_path, document_version_id, details)
            select dv.tenant_id, 'missing_object', dv.storage_path, dv.id,
                   jsonb_build_object('document_id', dv.document_id,
                                      'version_number', dv.version_number,
                                      'uploaded_at', dv.uploaded_at)
            from public.document_versions dv
            where dv.tenant_id = t.id
              and not exists (select 1 from storage.objects o
                               where o.bucket_id = v_bucket and o.name = dv.storage_path)
            on conflict (tenant_id, finding_type_code, coalesce(storage_path, ''))
            do update set last_seen_at = now(),
                          -- Re-detection REOPENS. A discrepancy that is observable again was not
                          -- actually resolved, whatever the executor reported last time.
                          resolved_at = null, resolution_code = null;
            get diagnostics v_n = row_count;
            v_missing := v_missing + v_n;

            -- ------------------------------------------------------------------------------
            -- B. Object without metadata.
            --
            --    CROSS-TENANT SAFETY IS STRUCTURAL HERE. The scan is anchored on the tenant's own
            --    path prefix -- `tenant_id/document_id/version` (`app.document_storage_path`) --
            --    so tenant A's iteration cannot even SEE an object under tenant B's prefix, let
            --    alone record or act on one. It is not a filter that could be forgotten; it is
            --    the only thing the query looks at.
            -- ------------------------------------------------------------------------------
            insert into public.document_storage_findings
                (tenant_id, finding_type_code, storage_path, details)
            select t.id, 'orphan_object', o.name,
                   jsonb_build_object('object_created_at', o.created_at,
                                      'size', o.metadata -> 'size')
            from storage.objects o
            where o.bucket_id = v_bucket
              and (storage.foldername(o.name))[1] = t.id::text
              and not exists (select 1 from public.document_versions dv
                               where dv.tenant_id = t.id and dv.storage_path = o.name)
            on conflict (tenant_id, finding_type_code, coalesce(storage_path, ''))
            do update set last_seen_at = now(),
                          resolved_at = null, resolution_code = null;
            get diagnostics v_n = row_count;
            v_orphan := v_orphan + v_n;

            -- ------------------------------------------------------------------------------
            -- C. Retention expiry.
            --
            --    ONLY SUPERSEDED VERSIONS. The current version of a live document is never
            --    eligible, at any age -- `is_current` and the document's own `current_version_id`
            --    are BOTH checked, because they are two independent records of the same fact and
            --    a disagreement between them must fail closed rather than pick a winner.
            --
            --    With `v_retention` NULL the WHERE clause is unsatisfiable, so nothing is ever
            --    selected. That is the "cannot accidentally become delete-immediately" guarantee,
            --    and it is the DEFAULT state today.
            -- ------------------------------------------------------------------------------
            insert into public.document_storage_findings
                (tenant_id, finding_type_code, storage_path, document_version_id, details)
            select dv.tenant_id, 'retention_expired', dv.storage_path, dv.id,
                   jsonb_build_object('document_id', dv.document_id,
                                      'version_number', dv.version_number,
                                      'uploaded_at', dv.uploaded_at,
                                      'retention_days', v_retention)
            from public.document_versions dv
            join public.documents d
              on d.tenant_id = dv.tenant_id and d.id = dv.document_id
            where dv.tenant_id = t.id
              and v_retention is not null
              and dv.is_current = false
              and d.current_version_id is distinct from dv.id
              and dv.uploaded_at + make_interval(days => v_retention) <= now()
            on conflict (tenant_id, finding_type_code, coalesce(storage_path, ''))
            do update set last_seen_at = now();
            get diagnostics v_n = row_count;
            v_expired := v_expired + v_n;

            -- This tenant scanned cleanly, so any standing scan-failure for it is now stale.
            update public.document_storage_findings
               set resolved_at = now(), resolution_code = 'dismissed',
                   resolution_note = 'a later scan of this tenant completed without error'
             where tenant_id = t.id
               and finding_type_code = 'tenant_scan_failed'
               and resolved_at is null;

        exception when others then
            -- SKIP, NEVER RAISE. One tenant's failure must not deny every other tenant its scan.
            v_failed := v_failed + 1;
            begin
                insert into public.document_storage_findings
                    (tenant_id, finding_type_code, storage_path, details)
                values (t.id, 'tenant_scan_failed', null,
                        jsonb_build_object('sqlstate', sqlstate, 'message', sqlerrm))
                on conflict (tenant_id, finding_type_code, coalesce(storage_path, ''))
                do update set last_seen_at = now(),
                              resolved_at = null, resolution_code = null,
                              details = excluded.details;
            exception when others then
                -- Recording the failure failed too. Nothing is left to do but keep going; the
                -- run summary still counts it, so the loss is visible rather than silent.
                null;
            end;
        end;
    end loop;

    return jsonb_build_object(
        'tenants_scanned',   v_tenants,
        'tenants_failed',    v_failed,
        'missing_objects',   v_missing,
        'orphan_objects',    v_orphan,
        'retention_expired', v_expired,
        'retention_days',    v_retention,
        'ran_at',            now());
end;
$fn$;

revoke execute on function app.reconcile_document_storage() from public;
grant  execute on function app.reconcile_document_storage() to service_role;

comment on function app.reconcile_document_storage() is
    'Per-tenant, skip-never-raise reconciliation of document metadata against the object store. '
    'Reads and writes findings only -- it never deletes, updates or archives a document, a version '
    'or an object, so it can never itself destroy what it is meant to protect (WP-04-D).';

-- ---------------------------------------------------------------------------------------------
-- 5. Resolution -- the external executor's only way back in.
--
--    This is where the byte operation's OUTCOME becomes ORVION state. The executor deletes through
--    the Storage API and then tells the database what happened; the database, and only here,
--    removes the metadata that named the destroyed object.
--
--    ORDER MATTERS AND IS ENFORCED BY THE ARGUMENT: metadata is removed only on the report that
--    the object is already gone. Removing it first would leave an object no row names -- an orphan
--    we would then have to detect. Removing it never would leave a `missing_object` finding
--    regenerating forever. So `object_deleted` on a `retention_expired` finding is the one path
--    that deletes a `document_versions` row anywhere in ORVION.
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
            -- ------------------------------------------------------------------------------
            -- THE SUBSCRIPTION GATE APPLIES TO THIS DELETE, AND IS CHECKED HERE RATHER THAN
            -- TRIPPED OVER. `document_versions_enforce_document_subscription_gate` fires BEFORE
            -- DELETE and -- unlike `app.enforce_archive_authority` and
            -- `app.enforce_document_version_integrity` -- has NO system-path exemption. WP-03
            -- settled that deliberately: the gate is the boundary, and batch callers skip lapsed
            -- tenants rather than the gate learning to make exceptions
            -- (`36_subscription_gate_system_paths_test.sql`). Widening it now, across all three
            -- document tables and every path, to buy this one function a shortcut would undo that.
            --
            -- So the caller does the skipping, as WP-03 requires. Refusing EXPLICITLY, before the
            -- delete, is what turns an opaque 42501 from a trigger three layers down into a
            -- message the storage executor can act on: leave the finding open and come back.
            --
            -- CONSEQUENCE, STATED AND NOT HIDDEN: a tenant that never returns to good standing
            -- keeps its superseded versions forever, and its storage with them. What ORVION owes
            -- a departed tenant's data is a business decision, not an engineering one -- recorded
            -- as RET-2 in MASTER_GAP_REGISTER.md rather than guessed at here.
            -- ------------------------------------------------------------------------------
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

comment on function app.platform_resolve_storage_finding(uuid, text, text) is
    'The external storage executor reports the outcome of a byte operation. The only path in ORVION '
    'that deletes a document_versions row, and only when the object is confirmed already destroyed '
    'and the version is still not current (WP-04-D). service_role only.';

-- ---------------------------------------------------------------------------------------------
-- 6. Schedule.
--
--    Daily, offset from the subscription job so two SECURITY DEFINER batches never contend. This
--    job protects nothing by running -- it only makes discrepancies visible -- so a missed run
--    costs visibility, never correctness, and the next run picks up everything the last one
--    would have found. That is what makes daily sufficient rather than merely cheap.
-- ---------------------------------------------------------------------------------------------
select cron.schedule('document-storage-reconciliation', '30 0 * * *',
                     'select app.reconcile_document_storage()');
