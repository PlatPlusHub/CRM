-- Batch 6 slice 50 (DOC-9, DOC-10) -- a document is linked only by someone who can read it, and a
-- moved link is recorded.
--
-- =================================================================================================
-- THE MEASURED DEFECTS (2026-11-12 at 789e056 on the local stack, probe fixtures rolled back)
--
-- DOC-9  A link decides who reads a document: the `documents` policy admits a non-confidential
--        document through any `document_links` row the caller can see, and a link is visible when
--        its target record is. The link's own policy checks only the TARGET, so an `employee` of one
--        branch who holds `UPLOAD_DOCUMENT` inserted a link from another branch's passport scan onto
--        their own booking, or re-pointed their own link at it, and then read the document, its
--        version and its storage path -- the boundary DOC-1 (SPEC-144) closed. The same insert of
--        another branch's invoice made the employee "responsible" for it through
--        `app.is_document_responsible` and read it past SPEC-154-B. The only precondition is the
--        document's id. `app.upload_document`, the one door that links, links only the document it
--        has just created.
-- DOC-10 Re-pointing a link by UPDATE moved a document off the record it belonged to (a ticket off
--        its booking) and recorded nothing: `derive_created_by` keeps the creator, and no event is
--        written. A new link is attributed by its own row (`created_by` is derived and immutable).
--
-- =================================================================================================
-- THE REPAIR, IN THE SPEC-301 SHAPE: authority is a precondition and runs BEFORE; the record is a
-- fact and runs AFTER.
--
-- 1. `app.guard_document_link_readable`, BEFORE INSERT OR UPDATE, session writes only: the caller
--    must already read the link's document. SECURITY INVOKER on purpose: the check IS the caller's
--    own read of `documents` under its policy (creator, tenant-wide read, the financial and
--    confidential clauses, an existing visible link). It runs BEFORE the row exists, so a link
--    cannot vouch for itself. A policy clause cannot do this: `documents` reads `document_links`,
--    and the one-directional chain (SPEC-144) forbids the reverse. No session (migrations, seeds,
--    provisioning, service_role, the tests' fixtures): no check, as in every sibling guard.
-- 2. `app.emit_document_link_move`, AFTER UPDATE, session writes only: `document_linked` (the code
--    `app.upload_document` already records for its link) on the document, with the link id and the
--    previous and current document and target. An UPDATE that moves neither records nothing.
--
-- DELETE is not included: `authenticated` holds no DELETE on this table.
-- NOT CHANGED: every grant and policy, the other three triggers, both RPCs, the documents policy.
-- =================================================================================================

create or replace function app.guard_document_link_readable()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if not exists (select 1 from public.documents d where d.id = new.document_id) then
        raise exception 'a document can be linked only by someone who can already read it'
            using errcode = 'insufficient_privilege';
    end if;
    return new;
end;
$fn$;

revoke execute on function app.guard_document_link_readable() from public;

create trigger document_links_guard_document_readable
    before insert or update on public.document_links
    for each row execute function app.guard_document_link_readable();

create or replace function app.emit_document_link_move()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_prev jsonb := jsonb_strip_nulls(to_jsonb(old) - array['id', 'tenant_id', 'created_by', 'created_at']);
    v_next jsonb := jsonb_strip_nulls(to_jsonb(new) - array['id', 'tenant_id', 'created_by', 'created_at']);
begin
    if (select auth.uid()) is null or v_prev = v_next then
        return null;
    end if;

    perform app.record_event(
        new.tenant_id, 'document_linked', 'document', new.document_id, null,
        null, null, null,
        jsonb_build_object('link_id', new.id, 'previous', v_prev, 'current', v_next),
        'info');
    return null;
end;
$fn$;

revoke execute on function app.emit_document_link_move() from public;

create trigger document_links_emit_move
    after update on public.document_links
    for each row execute function app.emit_document_link_move();
