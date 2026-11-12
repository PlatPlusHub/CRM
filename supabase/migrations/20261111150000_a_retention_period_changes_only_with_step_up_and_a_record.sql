-- Batch 6 slice 49 (RET-3, RET-4) -- a document retention period changes only with step-up and a
-- record.
--
-- =================================================================================================
-- THE MEASURED DEFECTS (2026-11-11 at 53146b3 on the local stack, committed probe fixtures)
--
-- RET-3 The table is its own only writer: no RPC writes `document_retention_policies`, and its RLS
--      charges `app.has_permission('MANAGE_TENANT_SETTINGS')` only, held by `owner` and `ceo`, both
--      bound to step-up by `app.requires_mfa()`. An `owner` at `aal1` inserted a 1-day passport
--      policy and a `ceo` at `aal1` shortened the owner's ten-year visa policy to 1 day; after each,
--      `app.reconcile_document_storage` marked the superseded version `retention_expired` and
--      `app.claim_storage_actions` handed it out as `delete_object`. The legal hold, the lever that
--      overrides retention, refuses the same `aal1` owner through `app.authorize`. A member of
--      STEPUP-1, reproduced with a classified consequence: an irreversible file deletion on a
--      password alone.
-- RET-4 No policy change was recorded on any path, and `derive_created_by` keeps the creator on an
--      UPDATE, so after the ceo's shortening the row still named the owner: nothing recorded who set
--      the period that deletes a file.
--
-- =================================================================================================
-- THE REPAIR, IN THE SPEC-301 SHAPE: authority is a precondition and runs BEFORE; the record is a
-- fact and runs AFTER.
--
-- 1. `app.guard_document_retention_policy_write`, BEFORE INSERT OR UPDATE: `app.authorize(
--    'MANAGE_TENANT_SETTINGS')` on every session write, every column, the legal hold's own charge.
--    No session (migrations, seeds, provisioning, service_role, the tests' fixtures): no charge, as
--    in every sibling guard.
-- 2. `app.emit_document_retention_policy_change`, AFTER INSERT OR UPDATE, session writes only: the
--    NEW code `document_retention_policy_changed` (critical, the legal hold's severity, since either
--    decides whether a file may be destroyed) with the actor, the previous and the current
--    document type, period, active flag and reason; previous is null on a creation. An UPDATE that
--    moves none of them records nothing.
--
-- DELETE is not included: `authenticated` holds no DELETE on this table; withdrawal is deactivation.
-- NOT CHANGED: every grant and policy, the other four triggers, the scan and the claim, RET-1's
-- retain-by-default shape and test 97.
-- Hosted rows at the time of writing (read-only, ledger 258): 0 policies on Primary and on Founder
-- Secondary.
-- =================================================================================================

-- Vocabulary. `sort_order` 938 is MEASURED: `event_type` holds 190 rows, maximum 937. Canon 27 gains
-- the matching entry.
insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
select null::uuid, 'event_type', 'document_retention_policy_changed', 'Document Retention Policy Changed', 938, true, true
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = 'event_type' and cv.code = 'document_retention_policy_changed'
      and cv.tenant_id is null
);

create or replace function app.guard_document_retention_policy_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    perform app.authorize('MANAGE_TENANT_SETTINGS');
    return new;
end;
$fn$;

revoke execute on function app.guard_document_retention_policy_write() from public;

create trigger document_retention_policies_guard_write
    before insert or update on public.document_retention_policies
    for each row execute function app.guard_document_retention_policy_write();

-- `old` is read only inside the UPDATE branch (the SPEC-159-A 55000 failure mode).
create or replace function app.emit_document_retention_policy_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_prev jsonb;
    v_next jsonb;
    v_prev_state text;
begin
    if (select auth.uid()) is null then
        return null;
    end if;

    v_next := jsonb_build_object('document_type_code', new.document_type_code,
        'retention_days', new.retention_days, 'is_active', new.is_active, 'reason', new.reason);
    if tg_op = 'UPDATE' then
        v_prev := jsonb_build_object('document_type_code', old.document_type_code,
            'retention_days', old.retention_days, 'is_active', old.is_active, 'reason', old.reason);
        if v_prev = v_next then
            return null;
        end if;
        v_prev_state := case when old.is_active then 'active' else 'inactive' end;
    end if;

    perform app.record_event(
        new.tenant_id, 'document_retention_policy_changed', 'document_retention_policy', new.id, null,
        v_prev_state,
        case when new.is_active then 'active' else 'inactive' end, new.reason,
        jsonb_build_object('previous', v_prev, 'current', v_next),
        'critical');
    return null;
end;
$fn$;

revoke execute on function app.emit_document_retention_policy_change() from public;

create trigger document_retention_policies_emit_change
    after insert or update on public.document_retention_policies
    for each row execute function app.emit_document_retention_policy_change();
