-- SPEC-231 / Batch 6 Slice 29 -- DOC-7 and DOC-8: a document version's retention clock and its
-- object key are the server's.
--
-- DOC-3 (202607054400) made a version's identity derived and immutable: `version_number`,
-- `storage_path` and `uploaded_by` are computed by `app.enforce_document_version_integrity` and
-- frozen on UPDATE. Two facts the retention package built on that identity were left outside it.
--
-- DOC-7. `uploaded_at` is the retention clock: `app.reconcile_document_storage` and
-- `app.claim_storage_actions` make a SUPERSEDED version a destruction candidate once
-- `uploaded_at + retention_days` has passed, and the period is the tenant's legal setting, costing
-- MANAGE_TENANT_SETTINGS. No RPC ever writes `uploaded_at`, but the table door accepted it on INSERT
-- and UPDATE from any CREATE_DOCUMENT_VERSION holder. REPRODUCED on the local stack at `669d656`, in a
-- rolled-back transaction: under a 3650-day `contract` policy an `employee` (no
-- MANAGE_TENANT_SETTINGS, refused changing the policy) backdated the owner's superseded version to
-- 2000-01-01; the next reconcile found it, the executor claimed it and `object_deleted` removed it.
-- Forward-dating a version already due took it off the claim list -- a hold without the hold's
-- authority. Repaired here as DOC-3 repaired the other identity columns: derived on INSERT, frozen
-- on UPDATE.
--
-- DOC-8. `version_number` is `max + 1` read under READ COMMITTED, so two concurrent inserts derive
-- the same number and therefore the same object key. REPRODUCED by committing an employee's direct
-- INSERT while the owner's `app.add_document_version` was still open: both rows were version 2 at
-- one `storage_path`, the owner's current and the employee's superseded. The storage policy then
-- authorizes either row's upload to that one object, and retention of the superseded twin deletes
-- the object the current version points at -- which canon says is never eligible at any age.
-- Repaired by making the key unique: the loser of a race is refused (23505) instead of sharing an
-- object. Two concurrent `app.add_document_version` calls were already refused, by
-- `document_versions_one_current_idx`, so no legitimate path gains a failure.
--
-- Unchanged: the session-less platform path (canon 35 principle 6), the permission charged, and
-- `is_current`, which `app.add_document_version` demotes and whose disagreement with the document's
-- pointer retention already treats as fail-closed.

create or replace function app.enforce_document_version_integrity()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_actor uuid;
    v_doc_type text;
begin
    -- service_role / migration path (canon 35 principle 6), consistent with every other guard here.
    if (select auth.uid()) is null then
        if tg_op = 'INSERT' and new.storage_path is null then
            new.storage_path := app.document_storage_path(
                new.tenant_id, new.document_id, coalesce(new.version_number, 1));
        end if;
        return new;
    end if;

    -- LIC-3: a version of a payment-proof document costs MANAGE_TENANT_SETTINGS, the permission its
    -- RPC charges, because CREATE_DOCUMENT_VERSION is gated on the `documents` entitlement that a
    -- `starter` tenant does not have -- and paying for your plan cannot be a plan feature. If the
    -- parent is not visible the lookup yields NULL and we fall through to the STRICTER default,
    -- which is the safe direction (BOOK-1: an RLS-filtered read must never weaken a guard).
    select d.document_type_code into v_doc_type
    from public.documents d
    where d.id = new.document_id and d.tenant_id = new.tenant_id;

    -- Direct DML now costs the same permission the RPC always charged. Every role holding
    -- UPLOAD_DOCUMENT also holds CREATE_DOCUMENT_VERSION (verified against the live seed), so this
    -- adds no new barrier to any legitimate upload.
    if v_doc_type = 'payment_proof' then
        perform app.authorize('MANAGE_TENANT_SETTINGS');
    else
        perform app.authorize('CREATE_DOCUMENT_VERSION');
    end if;

    v_actor := app.current_user_id();

    if tg_op = 'INSERT' then
        -- Derived, not accepted. Whatever the caller sent for these four columns is discarded --
        -- that discarding IS the security property, exactly as in SPEC-155.
        new.version_number := coalesce((
            select max(dv.version_number)
            from public.document_versions dv
            where dv.document_id = new.document_id and dv.tenant_id = new.tenant_id
        ), 0) + 1;

        new.storage_path := app.document_storage_path(
            new.tenant_id, new.document_id, new.version_number);

        new.uploaded_by := v_actor;

        -- DOC-7: the retention clock. Every RPC takes the column default; so does this door now.
        new.uploaded_at := now();
        return new;
    end if;

    -- UPDATE: the identity of a version is immutable. `is_current` is deliberately NOT frozen --
    -- `app.add_document_version` demotes the previous current version, and the partial unique index
    -- below is what keeps that honest.
    if new.document_id    is distinct from old.document_id
       or new.tenant_id      is distinct from old.tenant_id
       or new.version_number is distinct from old.version_number
       or new.storage_path   is distinct from old.storage_path
       or new.uploaded_by    is distinct from old.uploaded_by
       or new.uploaded_at    is distinct from old.uploaded_at then
        raise exception
            'a document version''s identity is immutable: add a new version instead of rewriting one'
            using errcode = 'insufficient_privilege';
    end if;

    return new;
end
$fn$;

revoke execute on function app.enforce_document_version_integrity() from public;

-- DOC-8: one object key names one version.
create unique index document_versions_storage_path_idx
    on public.document_versions (storage_path);
