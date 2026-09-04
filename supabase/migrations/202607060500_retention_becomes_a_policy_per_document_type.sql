-- RET-1 -- retention becomes a POLICY, per document type, and still deletes nothing by default.
--
-- =================================================================================================
-- THE OWNER DECISION, QUOTED RATHER THAN INFERRED (2026-09-04)
--
--   "RET-1 = BUILD THE RETENTION MECHANISM NOW."
--   "Retention policy must be represented per document_type_code."
--   "NULL must remain the safe meaning of 'no deletion policy/value currently defined'."
--   "Do NOT invent legal retention periods. Do NOT populate guessed numbers."
--   "Do NOT make one global retention period the architectural authority."
--   "Preserve fail-closed behavior: absence of a defined retention period must never cause
--    destructive deletion."
--   "The mechanism must be ready for legally approved values to be inserted later without schema
--    redesign."
--   "Preserve the existing requirement that only superseded/non-current document versions can become
--    deletion candidates. Do not delete current document versions."
--   "Document clearly where legally approved values will live and who/what is expected to supply
--    them later."
--
-- NOT ONE NUMBER IS SEEDED. This migration creates the table and inserts ZERO rows into it. Every
-- tenant therefore has no policy for every document type, which means nothing is ever eligible for
-- destruction -- exactly the state that was in force before, reached by a different and better road.
--
-- =================================================================================================
-- WHY THE ZERO-ARG FUNCTION HAD TO GO, AND WHAT REPLACED IT
--
-- `app.document_retention_days()` took no arguments and returned NULL. It was ONE GLOBAL NUMBER for
-- every tenant and every document type, which is precisely the architectural authority the owner
-- forbade -- and it could not have been right in any case: a passport scan, a signed contract and a
-- payment proof do not share a retention obligation, and Egypt's PDPL ties the period to the
-- PURPOSE OF COLLECTION, which is per document type by construction.
--
-- It is replaced by `public.document_retention_policies` -- ONE authority, tenant-scoped, one row
-- per (tenant, document_type_code). There is deliberately NO platform-wide default row and no
-- nullable-tenant "global" row: two authorities disagreeing about a legal obligation is exactly the
-- duplicate-authority defect this repository keeps finding, and a platform default would also mean
-- ORVION inventing a legal period on every tenant's behalf.
--
-- `NULL` KEEPS ITS MEANING, and gains a second, stronger guarantee. `app.document_retention_days
-- (tenant, document_type_code)` returns NULL when no policy exists, exactly as before. But the scan
-- and the claim path no longer ask a function whether a number exists -- they INNER JOIN the policy
-- table, so "no policy" produces no row at all. Fail-closed stops being a WHERE clause someone could
-- edit and becomes the shape of the query.
--
-- `retention_days` is NOT NULL and `>= 1` at the constraint level, so the "0 means destroy on sight"
-- hazard cannot be stored at all. `app.reconcile_document_storage` keeps its defensive coercion
-- anyway -- two independent guards, neither relying on the other.
--
-- =================================================================================================
-- A PAR-2 HAZARD REMOVED AS A SIDE EFFECT, AND IT IS WORTH STATING
--
-- Because retention was a FUNCTION, every test that wanted to exercise it had to REDEFINE that
-- function -- `49_document_retention_test`, `52_public_api_and_executor_contract_test`,
-- `60_storage_backlog_observability_test` and `verify_storage_end_to_end.ps1` all did, and the HTTP
-- script had to read the original definition with `pg_get_functiondef` and put it back afterwards.
-- PAR-2 is the finding that "a suite that mutates the schema it tests corrupts parity silently".
-- With a policy TABLE, a test inserts a row and rolls back. No suite alters the schema any more.
--
-- =================================================================================================
-- WHERE THE LEGALLY APPROVED VALUES WILL LIVE, AND WHO SUPPLIES THEM
--
--   TABLE   : public.document_retention_policies
--   KEY     : (tenant_id, document_type_code)
--   VALUE   : retention_days integer, >= 1, measured from `document_versions.uploaded_at`
--   WHO     : the tenant's own owner/ceo, through MANAGE_TENANT_SETTINGS -- the same authority that
--             already governs tenant configuration. ORVION supplies no value and no default.
--   SOURCE  : counsel. Egypt's PDPL executive regulations (Decree 816/2025, in force) require a
--             controller to DEFINE AND DOCUMENT a retention period tied to the purpose of
--             collection and to erase once fulfilled, and Egyptian tax and commercial record-keeping
--             set competing minimums. Reconciling those is a legal question, not an engineering one,
--             and this migration deliberately answers none of it.
--   EFFECT  : inserting a row is the ONLY thing that makes any version eligible for destruction, and
--             even then only a SUPERSEDED one -- see the guarantees preserved below.
-- =================================================================================================

-- 1. THE POLICY TABLE. The single authority.
create table if not exists public.document_retention_policies (
    id                 uuid primary key default gen_random_uuid(),
    tenant_id          uuid not null,
    document_type_code text not null,
    retention_days     integer not null,
    reason             text,
    -- WITHDRAWAL IS DEACTIVATION, NOT DELETION. `10_grant_model_test` refused a DELETE grant here and
    -- was right to: `authenticated` holds DELETE on NO public base table in ORVION, anywhere. For a
    -- LEGAL setting that is the better model regardless -- what retention was configured, by whom and
    -- when, must remain answerable after the policy is withdrawn.
    is_active          boolean not null default true,
    created_by         uuid,
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now()
);

do $DO$
begin
    if not exists (select 1 from pg_constraint where conname = 'document_retention_policies_tenant_fkey') then
        alter table public.document_retention_policies
            add constraint document_retention_policies_tenant_fkey
            foreign key (tenant_id) references public.tenants(id) on delete restrict;
    end if;
    -- TENANT-1: every tenant-scoped FK is composite, so a row can never point across tenants.
    if not exists (select 1 from pg_constraint where conname = 'document_retention_policies_created_by_fkey') then
        alter table public.document_retention_policies
            add constraint document_retention_policies_created_by_fkey
            foreign key (tenant_id, created_by) references public.users(tenant_id, id) on delete restrict;
    end if;
    if not exists (select 1 from pg_constraint where conname = 'document_retention_policies_tenant_id_id_key') then
        alter table public.document_retention_policies
            add constraint document_retention_policies_tenant_id_id_key unique (tenant_id, id);
    end if;
    -- ONE authority per (tenant, type): a second row would be a second answer to a legal question.
    if not exists (select 1 from pg_constraint where conname = 'document_retention_policies_unique_type') then
        alter table public.document_retention_policies
            add constraint document_retention_policies_unique_type unique (tenant_id, document_type_code);
    end if;
    -- "0 means destroy on sight" cannot be STORED, not merely cannot be obeyed.
    if not exists (select 1 from pg_constraint where conname = 'document_retention_policies_days_check') then
        alter table public.document_retention_policies
            add constraint document_retention_policies_days_check check (retention_days >= 1);
    end if;
end
$DO$;

create index if not exists document_retention_policies_tenant_id_idx
    on public.document_retention_policies (tenant_id);

comment on table public.document_retention_policies is
'RET-1 (owner decision 2026-09-04): the retention period for SUPERSEDED document versions, one row '
'per (tenant, document_type_code). NO ROW MEANS NO POLICY, which means nothing is ever destroyed -- '
'and that is the shipped default, because this migration seeds zero rows. ORVION invents no legal '
'period; values are supplied by the tenant on counsel''s advice through MANAGE_TENANT_SETTINGS. '
'There is deliberately no platform-wide default row: two authorities disagreeing about a legal '
'obligation is a defect, and a default would mean ORVION choosing a period for every tenant.';

comment on column public.document_retention_policies.retention_days is
'Days from `document_versions.uploaded_at` after which a SUPERSEDED version becomes a destruction '
'CANDIDATE (a finding for the external executor -- nothing is deleted from inside the database). '
'NOT NULL and >= 1 at the constraint level, so a zero or negative period cannot be stored at all.';

-- 2. THE GUARDS, all reused rather than invented.
drop trigger if exists document_retention_policies_enforce_catalog_codes on public.document_retention_policies;
create trigger document_retention_policies_enforce_catalog_codes
    before insert or update on public.document_retention_policies
    for each row execute function app.enforce_catalog_codes('document_type_code', 'document_type');

drop trigger if exists document_retention_policies_derive_created_by on public.document_retention_policies;
create trigger document_retention_policies_derive_created_by
    before insert or update on public.document_retention_policies
    for each row execute function app.derive_created_by();

drop trigger if exists document_retention_policies_enforce_subscription_write_gate on public.document_retention_policies;
create trigger document_retention_policies_enforce_subscription_write_gate
    before insert or delete or update on public.document_retention_policies
    for each row execute function app.enforce_subscription_write_gate();

drop trigger if exists document_retention_policies_set_updated_at on public.document_retention_policies;
create trigger document_retention_policies_set_updated_at
    before update on public.document_retention_policies
    for each row execute function moddatetime(updated_at);

-- 3. ISOLATION AND AUTHORITY. Reading a retention policy is ordinary tenant configuration; SETTING
--    one is a legal act, so it costs MANAGE_TENANT_SETTINGS -- the authority that already governs
--    tenant configuration (held by owner and ceo). No new permission is minted: a retention period
--    is a tenant setting, and inventing a second permission for it would fragment that authority.
alter table public.document_retention_policies enable row level security;

drop policy if exists scope_read   on public.document_retention_policies;
drop policy if exists scope_insert on public.document_retention_policies;
drop policy if exists scope_update on public.document_retention_policies;

-- `to authenticated` on every policy, never the default `to public` -- POL-1 (`202607055000`) is
-- exactly this defect, and `50_policy_role_scope_test` caught it here before it shipped.
create policy scope_read on public.document_retention_policies
    for select to authenticated using (tenant_id = (select app.current_tenant_id()));

create policy scope_insert on public.document_retention_policies
    for insert to authenticated with check (tenant_id = (select app.current_tenant_id())
                           and (select app.has_permission('MANAGE_TENANT_SETTINGS')));

create policy scope_update on public.document_retention_policies
    for update to authenticated using (tenant_id = (select app.current_tenant_id())
                      and (select app.has_permission('MANAGE_TENANT_SETTINGS')))
        with check (tenant_id = (select app.current_tenant_id())
                    and (select app.has_permission('MANAGE_TENANT_SETTINGS')));

-- NO DELETE POLICY AND NO DELETE GRANT. `authenticated` holds DELETE on no public base table in
-- ORVION; a policy is withdrawn by setting `is_active = false`, which keeps the legal record of what
-- was configured. The capability check lives in these RLS POLICIES rather than in a trigger, exactly
-- as it does for `user_role_assignments` and `user_permission_grants` (RBAC-3).
grant select, insert, update on public.document_retention_policies to authenticated;

-- 4. THE RESOLVER. Replaces the zero-arg global. NULL still means "no policy defined", and that is
--    now a property of the DATA rather than a hard-coded return value nobody could change without a
--    migration.
drop function if exists app.document_retention_days();

create or replace function app.document_retention_days(p_tenant_id uuid, p_document_type_code text)
returns integer
language sql
stable
security definer
set search_path = ''
as $FN$
    select rp.retention_days
    from public.document_retention_policies rp
    where rp.tenant_id = p_tenant_id
      and rp.document_type_code = p_document_type_code
      and rp.is_active
$FN$;

revoke all on function app.document_retention_days(uuid, text) from public;
grant execute on function app.document_retention_days(uuid, text) to authenticated;

comment on function app.document_retention_days(uuid, text) is
'RET-1: the configured retention period for one tenant and one document type, or NULL when no '
'policy exists -- and NULL means RETAIN, never destroy. Replaced the zero-arg global of the same '
'name, which was one number for every tenant and every document type and could not have been '
'correct: Egypt''s PDPL ties retention to the PURPOSE of collection, which is per document type.';

-- =================================================================================================
-- 5. THE SCAN. Section C now INNER JOINs the policy, so "no policy" produces no row -- fail-closed
--    by the shape of the query rather than by a WHERE clause someone could edit away.
--    Everything else in this function is unchanged and is reproduced in full so nothing from
--    WP-04-E, RET-2 or the per-tenant exception handling is lost.
-- =================================================================================================
create or replace function app.reconcile_document_storage()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $FN$
declare
    t              record;
    v_bucket       text    := app.document_bucket();
    v_missing      integer := 0;
    v_orphan       integer := 0;
    v_expired      integer := 0;
    v_tenants      integer := 0;
    v_failed       integer := 0;
    v_policies     integer := 0;
    v_n            integer;
begin
    -- How many retention policies exist AT ALL. Reported in the run summary so an operator can see
    -- at a glance that retention is unconfigured rather than merely finding nothing -- "zero
    -- candidates" and "no policy anywhere" look identical without it.
    select count(*) into v_policies from public.document_retention_policies;

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
            -- C. Retention expiry -- RET-1, now a POLICY PER DOCUMENT TYPE.
            --
            --    THE INNER JOIN IS THE FAIL-CLOSED GUARANTEE. With no policy row for a tenant and
            --    document type there is no join partner, so no candidate is produced -- "retain by
            --    default" is the SHAPE of the query, not a condition that could be edited away.
            --    This migration seeds ZERO policy rows, so on the day it ships nothing anywhere is
            --    eligible, exactly as before.
            --
            --    ONLY SUPERSEDED VERSIONS, unchanged. The current version of a live document is
            --    never eligible, at any age -- `is_current` and the document's own
            --    `current_version_id` are BOTH checked, because they are two independent records of
            --    the same fact and a disagreement between them must fail closed rather than pick a
            --    winner.
            --
            --    The `>= 1` guard is kept even though the CHECK constraint already makes a smaller
            --    value unstorable: two independent guards, neither relying on the other.
            -- ------------------------------------------------------------------------------
            insert into public.document_storage_findings
                (tenant_id, finding_type_code, storage_path, document_version_id, details)
            select dv.tenant_id, 'retention_expired', dv.storage_path, dv.id,
                   jsonb_build_object('document_id', dv.document_id,
                                      'version_number', dv.version_number,
                                      'uploaded_at', dv.uploaded_at,
                                      'document_type_code', d.document_type_code,
                                      'retention_days', rp.retention_days)
            from public.document_versions dv
            join public.documents d
              on d.tenant_id = dv.tenant_id and d.id = dv.document_id
            join public.document_retention_policies rp
              on rp.tenant_id = d.tenant_id and rp.document_type_code = d.document_type_code
             and rp.is_active
            where dv.tenant_id = t.id
              and rp.retention_days >= 1
              and dv.is_current = false
              and d.current_version_id is distinct from dv.id
              and dv.uploaded_at + make_interval(days => rp.retention_days) <= now()
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
        'tenants_scanned',    v_tenants,
        'tenants_failed',     v_failed,
        'missing_objects',    v_missing,
        'orphan_objects',     v_orphan,
        'retention_expired',  v_expired,
        'retention_policies', v_policies,
        'ran_at',             now());
end;
$FN$;

-- =================================================================================================
-- 6. THE CLAIM PATH. Its own comment says the finding is "re-verified at claim time, not trusted
--    from the scan" -- but it only ever re-verified that retention was CONFIGURED, never that the
--    version was actually old enough. That is a guard whose description outran its measurement
--    (MEAS-1). With a per-type policy the real re-verification is available and is done here.
--    Everything else is unchanged, including RET-2's restricted-tenant rule.
-- =================================================================================================
-- `default 50` is LOAD-BEARING: `create or replace` cannot remove a parameter default, and the
-- original (`202607055300`) declared one. Omitting it fails with 42P13.
create or replace function app.claim_storage_actions(p_limit integer default 50)
returns table (finding_id uuid, tenant_id uuid, storage_path text, action_code text, attempt_count integer)
language sql
security definer
set search_path = ''
as $FN$
    select f.id, f.tenant_id, f.storage_path, 'delete_object'::text, f.attempt_count
    from public.document_storage_findings f
    join public.document_versions dv
      on dv.tenant_id = f.tenant_id and dv.id = f.document_version_id
    join public.documents d
      on d.tenant_id = dv.tenant_id and d.id = dv.document_id
    join public.document_retention_policies rp
      on rp.tenant_id = d.tenant_id and rp.document_type_code = d.document_type_code
     and rp.is_active
    where f.finding_type_code = 'retention_expired'
      and f.resolved_at is null
      -- Re-verified at claim time, not trusted from the scan. A finding can be days old -- and RET-1
      -- makes this a REAL re-verification: the policy must still exist (the join), must still be
      -- valid, and the version must still be past it. Withdrawing a policy therefore withdraws the
      -- work, which is the behaviour a legal setting must have.
      and rp.retention_days >= 1
      and dv.uploaded_at + make_interval(days => rp.retention_days) <= now()
      and dv.is_current = false
      and d.current_version_id is distinct from dv.id
      -- The RET-2 rule, applied where the work is handed out rather than only where it is
      -- reported: a restricted tenant's stored data is frozen, so its actions are never claimable.
      -- Without this the executor would collect work it is structurally forbidden to complete and
      -- burn an attempt on every run.
      and app.subscription_allows_write(f.tenant_id)
    order by f.attempt_count, f.first_seen_at
    limit greatest(1, least(coalesce(p_limit, 50), 500));
$FN$;
