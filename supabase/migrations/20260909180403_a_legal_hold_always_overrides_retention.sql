-- RET-1 / RET-2 -- owner decision, ratified 2026-09-09.
--
-- Retention remains configured per document type, with no policy meaning retain. A legal hold is
-- stronger than every configured period: while a document is held, no version of it may enter the
-- retention-deletion queue and an already-recorded candidate may not be claimed. No retention
-- period is seeded or guessed here.
--
-- The hold is current state on the existing document aggregate rather than a new table. That is the
-- smallest complete representation supported by today's domain: ORVION has no legal-case entity to
-- reference, while the immutable event ledger preserves every place/release cycle. Adding a
-- speculative case-management aggregate would be feature design, not retention integrity.

alter table public.documents
    add column legal_hold_active boolean not null default false,
    add column legal_hold_reason text,
    add column legal_hold_changed_at timestamptz,
    add column legal_hold_changed_by uuid;

alter table public.documents
    add constraint documents_legal_hold_evidence_check
    check (not legal_hold_active
           or (legal_hold_reason is not null
               and btrim(legal_hold_reason) <> ''
               and legal_hold_changed_at is not null
               and legal_hold_changed_by is not null)),
    add constraint documents_legal_hold_changed_by_fkey
    foreign key (tenant_id, legal_hold_changed_by)
    references public.users (tenant_id, id) on delete restrict;

comment on column public.documents.legal_hold_active is
    'RET-1/RET-2: TRUE makes every version of this document ineligible for retention deletion, at scan and again at claim time. Legal hold always overrides a configured retention period.';
comment on column public.documents.legal_hold_reason is
    'RET-1/RET-2: mandatory fresh reason for the most recent legal-hold placement or release. Immutable events preserve every prior cycle.';
comment on column public.documents.legal_hold_changed_at is
    'RET-1/RET-2: server-stamped instant of the most recent legal-hold placement or release.';
comment on column public.documents.legal_hold_changed_by is
    'RET-1/RET-2: server-stamped actor for the most recent legal-hold placement or release.';

insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_system, is_active)
select v.type_code, v.code, v.label, v.ord, true, true
from (values
        ('event_type', 'document_legal_hold_placed',   'Document Legal Hold Placed',   930),
        ('event_type', 'document_legal_hold_released', 'Document Legal Hold Released', 931)
     ) as v(type_code, code, label, ord)
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = v.type_code and cv.code = v.code and cv.tenant_id is null
);

-- A retention/hold decision is tenant policy, so it reuses MANAGE_TENANT_SETTINGS: owner and CEO,
-- the same authority that configures document_retention_policies. The reason must be new on every
-- transition, and the actor/time are derived rather than accepted on both the RPC and table door.
create function app.guard_document_legal_hold()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if new.legal_hold_active is distinct from old.legal_hold_active then
        perform app.authorize('MANAGE_TENANT_SETTINGS');
        if new.legal_hold_reason is null
           or btrim(new.legal_hold_reason) = ''
           or new.legal_hold_reason is not distinct from old.legal_hold_reason then
            raise exception 'placing or releasing a document legal hold requires its own reason'
                using errcode = 'check_violation';
        end if;
        new.legal_hold_changed_at := now();
        new.legal_hold_changed_by := app.current_user_id();
    elsif new.legal_hold_reason is distinct from old.legal_hold_reason
       or new.legal_hold_changed_at is distinct from old.legal_hold_changed_at
       or new.legal_hold_changed_by is distinct from old.legal_hold_changed_by then
        raise exception 'legal-hold evidence is not editable without a hold transition'
            using errcode = 'check_violation';
    end if;
    return new;
end
$fn$;

revoke all on function app.guard_document_legal_hold() from public;

create trigger documents_guard_legal_hold
    before update on public.documents
    for each row execute function app.guard_document_legal_hold();

create function app.record_document_legal_hold_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if new.legal_hold_active is distinct from old.legal_hold_active then
        perform app.record_event(
            new.tenant_id,
            case when new.legal_hold_active
                 then 'document_legal_hold_placed'
                 else 'document_legal_hold_released' end,
            'document', new.id, null,
            case when old.legal_hold_active then 'held' else 'not_held' end,
            case when new.legal_hold_active then 'held' else 'not_held' end,
            new.legal_hold_reason,
            jsonb_build_object('legal_hold_changed_by', new.legal_hold_changed_by),
            'critical');
    end if;
    return null;
end
$fn$;

revoke all on function app.record_document_legal_hold_event() from public;

create trigger documents_record_legal_hold_event
    after update on public.documents
    for each row execute function app.record_document_legal_hold_event();

create function app.set_document_legal_hold(
    p_document_id uuid,
    p_active boolean,
    p_reason text
)
returns void
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if p_active is null then
        raise exception 'legal hold state is required';
    end if;
    if p_reason is null or btrim(p_reason) = '' then
        raise exception 'placing or releasing a document legal hold requires a reason';
    end if;

    update public.documents
       set legal_hold_active = p_active,
           legal_hold_reason = p_reason,
           updated_at = now()
     where id = p_document_id
       and tenant_id = v_tenant
       and legal_hold_active is distinct from p_active;

    if not found then
        if not exists (select 1 from public.documents d where d.id = p_document_id and d.tenant_id = v_tenant) then
            raise exception 'document is not in your tenant';
        end if;
        raise exception 'document legal hold is already %', case when p_active then 'active' else 'released' end;
    end if;
end
$fn$;

comment on function app.set_document_legal_hold(uuid, boolean, text) is
    'RET-1/RET-2: places or releases a document legal hold. The table trigger charges MANAGE_TENANT_SETTINGS, requires a fresh reason, stamps actor/time and emits exactly one immutable event.';

revoke all on function app.set_document_legal_hold(uuid, boolean, text) from public;
grant execute on function app.set_document_legal_hold(uuid, boolean, text) to authenticated;

create function public.set_document_legal_hold(p_document_id uuid, p_active boolean, p_reason text)
returns void language sql set search_path = ''
as $fn$ select app.set_document_legal_hold(p_document_id, p_active, p_reason) $fn$;
revoke all on function public.set_document_legal_hold(uuid, boolean, text) from public;
grant execute on function public.set_document_legal_hold(uuid, boolean, text) to authenticated;
comment on function public.set_document_legal_hold(uuid, boolean, text) is
    'HTTP surface for the SECURITY INVOKER app.set_document_legal_hold operation.';

-- The candidate-ledger boundary guards the scan and every future producer at once. A held document
-- is not inserted or refreshed as a retention-expired candidate. Findings recorded before a hold
-- remain evidence, but the claim path below makes them unclaimable until release.
create function app.suppress_held_retention_candidate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if new.finding_type_code = 'retention_expired'
       and exists (
           select 1
           from public.document_versions dv
           join public.documents d
             on d.tenant_id = dv.tenant_id and d.id = dv.document_id
           where dv.tenant_id = new.tenant_id
             and dv.id = new.document_version_id
             and d.legal_hold_active
       ) then
        return null;
    end if;
    return new;
end
$fn$;

revoke all on function app.suppress_held_retention_candidate() from public;

create trigger document_storage_findings_suppress_held_retention
    before insert or update on public.document_storage_findings
    for each row execute function app.suppress_held_retention_candidate();

-- Claim-time revalidation is independent of scan-time suppression. This is load-bearing for a hold
-- placed after a candidate was found and before an external executor claims it.
create or replace function app.claim_storage_actions(p_limit integer default 50)
returns table (finding_id uuid, tenant_id uuid, storage_path text, action_code text, attempt_count integer)
language sql
security definer
set search_path = ''
as $fn$
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
      and rp.retention_days >= 1
      and dv.uploaded_at + make_interval(days => rp.retention_days) <= now()
      and dv.is_current = false
      and d.current_version_id is distinct from dv.id
      and not d.legal_hold_active
      and app.subscription_allows_write(f.tenant_id)
    order by f.attempt_count, f.first_seen_at
    limit greatest(1, least(coalesce(p_limit, 50), 500));
$fn$;

comment on function app.claim_storage_actions(integer) is
    'Returns retention-backed Storage delete work to the external executor. Revalidates policy, age, non-current state, subscription eligibility and RET-1/RET-2 legal hold at claim time; a hold placed after scanning therefore blocks execution immediately.';
