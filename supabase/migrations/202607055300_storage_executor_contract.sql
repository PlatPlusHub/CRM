-- WP-04-E -- the storage executor's database contract, and FND-1.
--
-- ================================================================================================
-- FND-1 -- A FAILED STORAGE ACTION WAS PERMANENTLY HIDDEN. Found by designing the consumer.
--
-- WP-04-D registered the resolution code `failed` with the description "The executor attempted the
-- storage action and it failed. **Stays discoverable.**" -- and then wrote a resolver that sets
-- `resolved_at = now()` for every valid resolution code, `failed` included. Both halves are still
-- readable in the live database, and they contradict each other:
--
--     catalog_values.description  ->  'Stays discoverable.'
--     platform_resolve_storage_finding -> update ... set resolved_at = now(), resolution_code = ...
--
-- Consequence, and it is the worse half: reconciliation REOPENS a resolved finding only for
-- `missing_object` and `orphan_object` (their `on conflict` clauses null `resolved_at`). The
-- `retention_expired` branch does not. So a retention action that failed once would be marked
-- resolved, never reopened, and never retried -- the object surviving forever with nothing open to
-- say so. That is exactly PH8-1's shape: a claimed-but-unacked item stranded silently, which this
-- programme has already paid for once.
--
-- I wrote that defect yesterday, in this same package family, while writing the sentence that
-- describes the correct behaviour. It was invisible because nothing consumed the contract yet.
-- Building the consumer is what exposed it -- which is the argument for building consumers.
--
-- FIX: `failed` stops being a resolution and becomes an ATTEMPT RECORD. The finding stays open, the
-- attempt is counted, the error is kept, and the next run picks it up again.
-- ================================================================================================

alter table public.document_storage_findings
    add column attempt_count integer not null default 0,
    add column last_attempt_at timestamptz,
    add column last_error text;

comment on column public.document_storage_findings.attempt_count is
    'How many times an executor has tried and failed this action. Never resets: a finding with a '
    'high count and no resolution is the signal an operator needs (WP-04-E, FND-1).';

-- The description now matches what the code does, rather than what I meant it to do.
update public.catalog_values
   set description = 'The executor attempted the storage action and it failed. Recorded as an '
                     'attempt; the finding STAYS OPEN and is retried.'
 where catalog_type_code = 'document_storage_finding_resolution' and code = 'failed';

-- ================================================================================================
-- THE EXECUTOR'S CLAIM CONTRACT.
--
-- WHY A FUNCTION AND NOT A TABLE READ. WP-04-D's architecture is that the DATABASE owns the
-- decision. If the executor selected from `document_storage_findings` and applied its own
-- eligibility rules, those rules would be a SECOND authorization system living outside the
-- database -- the precise thing canon 35 forbids and the reason WP-04-C rejected every non-Supabase
-- object store. The executor must be able to do exactly one thing: perform the operation it is
-- handed. Every question of *whether* is answered here.
--
-- WHY THERE IS NO LEASE, unlike `app.claim_conversion_deliveries`. PH8-1 needed one because that
-- outbox MARKS a delivery in flight before the work, so a crash strands the mark. This function
-- marks nothing. The sequence is: read -> delete the object -> report. A crash at any point leaves
-- the finding exactly as it was, and the next run retries it. Deleting an object that is already
-- gone is a no-op at the Storage API, so the retry is safe. Adding a lease here would introduce the
-- very stranding state PH8-1 had to invent a lease to escape.
--
-- WHY ONLY `retention_expired` IS EXECUTABLE. An `orphan_object` is bytes that no row references --
-- and the reason it has no row may be that a metadata transaction failed, which makes that object a
-- customer's document ORVION has forgotten rather than garbage. Destroying it on sight would make
-- recovery impossible and would be irreversible. Orphan disposition is a decision, not a chore:
-- recorded as ORPH-1. `missing_object` has no object to act on by definition, and
-- `tenant_scan_failed` is a diagnostic.
-- ================================================================================================
create or replace function app.claim_storage_actions(p_limit integer default 50)
returns table (
    finding_id      uuid,
    tenant_id       uuid,
    storage_path    text,
    action_code     text,
    attempt_count   integer
)
language sql
stable
security definer
set search_path = ''
as $fn$
    select f.id, f.tenant_id, f.storage_path, 'delete_object'::text, f.attempt_count
    from public.document_storage_findings f
    join public.document_versions dv
      on dv.tenant_id = f.tenant_id and dv.id = f.document_version_id
    join public.documents d
      on d.tenant_id = dv.tenant_id and d.id = dv.document_id
    where f.finding_type_code = 'retention_expired'
      and f.resolved_at is null
      -- Re-verified at claim time, not trusted from the scan. A finding can be days old.
      and app.document_retention_days() is not null
      and dv.is_current = false
      and d.current_version_id is distinct from dv.id
      -- The RET-2 rule, applied where the work is handed out rather than only where it is
      -- reported: a restricted tenant's stored data is frozen, so its actions are never claimable.
      -- Without this the executor would collect work it is structurally forbidden to complete and
      -- burn an attempt on every run.
      and app.subscription_allows_write(f.tenant_id)
    order by f.attempt_count, f.first_seen_at
    limit greatest(1, least(coalesce(p_limit, 50), 500));
$fn$;

revoke execute on function app.claim_storage_actions(integer) from public;
grant  execute on function app.claim_storage_actions(integer) to service_role;

comment on function app.claim_storage_actions(integer) is
    'The storage executor''s ONLY source of work. Every eligibility question is answered here so the '
    'executor never decides anything -- it performs exactly the operation it is handed (WP-04-E).';

-- ================================================================================================
-- The resolver learns the difference between "this is finished" and "this attempt failed".
-- ================================================================================================
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
$fn$;

revoke execute on function app.platform_resolve_storage_finding(uuid, text, text) from public;
grant  execute on function app.platform_resolve_storage_finding(uuid, text, text) to service_role;
