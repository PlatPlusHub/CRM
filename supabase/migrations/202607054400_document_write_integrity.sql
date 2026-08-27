-- WP-04-A -- document write integrity: the storage path becomes system-derived, and a document
-- version stops being forgeable.
--
-- Two defects, both proven live before this migration was written, and both structural rather than
-- hypothetical.
--
-- ================================================================================================
-- DOC-1 -- THE STORAGE PATH WAS CALLER-SUPPLIED, ON THREE PATHS.
--
--   `app.upload_document(… p_storage_path text …)` and `app.add_document_version(… p_storage_path
--   text …)` both took the object key as a parameter, and `authenticated` additionally holds INSERT
--   and UPDATE directly on `public.document_versions`. So the value a document points at inside
--   object storage was chosen by the caller on three separate paths.
--
--   Nothing bad happens today only because there is no storage: `storage.buckets` = 0 on Primary.
--   The moment a bucket exists, a caller can write a path under another tenant's prefix, and the
--   ordinary defence -- a storage policy keyed on the first path segment -- is defeated by the very
--   value the attacker supplied. This is a cross-tenant path designed in *before* storage exists.
--
--   THE FIX IS DERIVATION, NOT VALIDATION. Validating that a supplied path "looks right" leaves the
--   value caller-chosen and fails open the moment a future writer forgets to check. This repository
--   has already settled this argument twice -- SPEC-155 derives `commission_rate` and WP-00 pins the
--   event actor -- and the same shape applies: the system computes the path from authoritative
--   server-side facts (tenant, document, version) and discards anything the caller sent.
--
--   NO CALLER STRING ENTERS THE OBJECT KEY AT ALL. The human file name stays in
--   `document_versions.file_name` where it belongs, for display and download naming; the key is
--   opaque and structural. That removes path traversal, unicode-normalisation and extension-spoofing
--   from the design instead of trying to sanitise them.
--
-- ================================================================================================
-- DOC-3 -- THE CURRENT VERSION OF A DOCUMENT COULD BE FORGED BY DIRECT DML.
--
--   `app.add_document_version` does everything correctly: it authorizes `CREATE_DOCUMENT_VERSION`,
--   computes the next version number, demotes the previous current version, and updates
--   `documents.current_version_id`. Nothing forced anyone through it.
--
--   `authenticated` holds INSERT and UPDATE on `document_versions`, whose RLS admits any row whose
--   PARENT DOCUMENT is visible. A user could therefore insert a row with `is_current = true` and an
--   arbitrary `storage_path`, or UPDATE an existing version's `storage_path` -- with no permission
--   check, no version sequencing, and no event. An invoice, a passport or a payment proof could be
--   made to point at a different object while every reader still saw the same document id.
--
--   That is the WP-00 audit-forgery class, one domain over: the authoritative record is correct only
--   as long as everybody uses the polite entry point.
-- ================================================================================================

-- ---------------------------------------------------------------------------------------------
-- 1. One home for the object key. Tenant first, so a storage policy can enforce isolation on
--    `(storage.foldername(name))[1]` whichever provider WP-04 selects -- the shape is deliberately
--    provider-independent, because the provider evaluation is not yet decided.
-- ---------------------------------------------------------------------------------------------
create or replace function app.document_storage_path(
    p_tenant_id uuid, p_document_id uuid, p_version_number integer)
returns text
language sql
immutable
set search_path = ''
as $fn$
    select p_tenant_id::text || '/' || p_document_id::text || '/' || p_version_number::text
$fn$;

revoke execute on function app.document_storage_path(uuid, uuid, integer) from public;
grant  execute on function app.document_storage_path(uuid, uuid, integer) to authenticated;

comment on function app.document_storage_path(uuid, uuid, integer) is
    'The single source of a document version''s object key. Tenant-prefixed so object-store policy '
    'can enforce isolation on the first path segment. Never accepts a caller-supplied path.';

-- ---------------------------------------------------------------------------------------------
-- 2. Version identity becomes non-negotiable on every write path.
--
--    Deliberately a trigger and not a check inside the RPC: direct DML was the unguarded path, and
--    the RPC was never the problem.
-- ---------------------------------------------------------------------------------------------
create or replace function app.enforce_document_version_integrity()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_actor uuid;
begin
    -- service_role / migration path (canon 35 principle 6), consistent with every other guard here.
    if (select auth.uid()) is null then
        if tg_op = 'INSERT' and new.storage_path is null then
            new.storage_path := app.document_storage_path(
                new.tenant_id, new.document_id, coalesce(new.version_number, 1));
        end if;
        return new;
    end if;

    -- Direct DML now costs the same permission the RPC always charged. Every role holding
    -- UPLOAD_DOCUMENT also holds CREATE_DOCUMENT_VERSION (verified against the live seed), so this
    -- adds no new barrier to any legitimate upload.
    perform app.authorize('CREATE_DOCUMENT_VERSION');

    v_actor := app.current_user_id();

    if tg_op = 'INSERT' then
        -- Derived, not accepted. Whatever the caller sent for these three columns is discarded --
        -- that discarding IS the security property, exactly as in SPEC-155.
        new.version_number := coalesce((
            select max(dv.version_number)
            from public.document_versions dv
            where dv.document_id = new.document_id and dv.tenant_id = new.tenant_id
        ), 0) + 1;

        new.storage_path := app.document_storage_path(
            new.tenant_id, new.document_id, new.version_number);

        new.uploaded_by := v_actor;
        return new;
    end if;

    -- UPDATE: the identity of a version is immutable. `is_current` is deliberately NOT frozen --
    -- `app.add_document_version` demotes the previous current version, and the partial unique index
    -- below is what keeps that honest.
    if new.document_id    is distinct from old.document_id
       or new.tenant_id      is distinct from old.tenant_id
       or new.version_number is distinct from old.version_number
       or new.storage_path   is distinct from old.storage_path
       or new.uploaded_by    is distinct from old.uploaded_by then
        raise exception
            'a document version''s identity is immutable: add a new version instead of rewriting one'
            using errcode = 'insufficient_privilege';
    end if;

    return new;
end;
$fn$;

revoke execute on function app.enforce_document_version_integrity() from public;

create trigger document_versions_enforce_integrity
    before insert or update on public.document_versions
    for each row execute function app.enforce_document_version_integrity();

-- NO INDEX IS ADDED HERE, and that is a finding rather than an omission. I intended to add a partial
-- unique index making "two current versions" unrepresentable; applying this migration failed with
-- `relation "document_versions_one_current_idx" already exists`. The original document-core
-- migration (`202607041900`) already created exactly that index. So the one-current-version
-- invariant was ALREADY enforced by the database, and the forgery risk in DOC-3 is narrower than the
-- discovery pass first read it: an attacker could rewrite or mis-point a version, but could never
-- produce two current versions. The trigger above is what closes the part that was genuinely open.
-- Recorded here because a wrong assumption caught by the database is worth more to the next reader
-- than a silent correction.

-- ---------------------------------------------------------------------------------------------
-- 3. Both RPCs lose the parameter. `drop` first, not `create or replace`: a shorter argument list
--    would otherwise leave the old signature callable as a second overload, still accepting a
--    caller-supplied path -- which is the entire defect (the SPEC-156 lesson).
-- ---------------------------------------------------------------------------------------------
drop function if exists app.upload_document(text, text, text, text, text, text, uuid, bigint, timestamptz, boolean);

create function app.upload_document(
    p_document_type_code text,
    p_title text,
    p_file_name text,
    p_file_type_code text,
    p_link_target_type text,
    p_link_target_id uuid,
    p_file_size bigint default null,
    p_expires_at timestamptz default null,
    p_is_confidential boolean default false
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_document_id uuid;
    v_version_id uuid;
    v_target_ok boolean;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    if not exists (select 1 from public.catalog_values
                   where catalog_type_code = 'document_type' and code = p_document_type_code) then
        raise exception 'unknown document_type: %', p_document_type_code;
    end if;
    if lower(coalesce(p_file_type_code, '')) not in ('pdf', 'jpg', 'jpeg', 'png', 'webp') then
        raise exception 'file type % is not allowed (MVP: pdf, jpg, jpeg, png, webp)', p_file_type_code;
    end if;
    if p_file_size is not null and p_file_size <= 0 then
        raise exception 'file_size must be greater than zero';
    end if;
    if not exists (select 1 from public.catalog_values
                   where catalog_type_code = 'document_link_target_type' and code = p_link_target_type) then
        raise exception 'unknown document_link_target_type: %', p_link_target_type;
    end if;

    -- Placement rules (16): passport at passenger level; ticket/visa/hotel_voucher at booking item level.
    if p_document_type_code = 'passport' and p_link_target_type <> 'passenger' then
        raise exception 'passport documents are stored at passenger level';
    end if;
    if p_document_type_code in ('ticket', 'visa', 'hotel_voucher') and p_link_target_type <> 'booking_item' then
        raise exception '% documents are stored at booking item level', p_document_type_code;
    end if;

    -- Target entity must exist in the caller's tenant.
    v_target_ok := case p_link_target_type
        when 'passenger'    then exists (select 1 from public.passengers    where id = p_link_target_id and tenant_id = v_tenant)
        when 'booking'      then exists (select 1 from public.bookings       where id = p_link_target_id and tenant_id = v_tenant)
        when 'booking_item' then exists (select 1 from public.booking_items  where id = p_link_target_id and tenant_id = v_tenant)
        when 'invoice'      then exists (select 1 from public.invoices       where id = p_link_target_id and tenant_id = v_tenant)
        when 'receipt'      then exists (select 1 from public.receipts       where id = p_link_target_id and tenant_id = v_tenant)
        when 'supplier'     then exists (select 1 from public.suppliers      where id = p_link_target_id and tenant_id = v_tenant)
        else false
    end;
    if not v_target_ok then
        raise exception '% target % is not in your tenant (or that target type is not yet supported)',
            p_link_target_type, p_link_target_id;
    end if;

    perform app.authorize('UPLOAD_DOCUMENT');

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    insert into public.documents (
        tenant_id, document_type_code, title, lifecycle_status_code,
        is_confidential, expires_at, created_by
    ) values (
        v_tenant, p_document_type_code, p_title, 'active',
        p_is_confidential, p_expires_at, v_actor
    ) returning id into v_document_id;

    -- `version_number`, `storage_path` and `uploaded_by` are omitted on purpose: the integrity
    -- trigger derives all three. Naming them here would re-create the illusion that this function
    -- decides them.
    insert into public.document_versions (
        tenant_id, document_id, file_name, file_type_code, file_size, is_current
    ) values (
        v_tenant, v_document_id, p_file_name, lower(p_file_type_code), p_file_size, true
    ) returning id into v_version_id;

    update public.documents set current_version_id = v_version_id, updated_at = now()
    where id = v_document_id;

    insert into public.document_links (
        tenant_id, document_id, passenger_id, booking_id, booking_item_id,
        invoice_id, receipt_id, supplier_id, created_by
    ) values (
        v_tenant, v_document_id,
        case when p_link_target_type = 'passenger'    then p_link_target_id end,
        case when p_link_target_type = 'booking'      then p_link_target_id end,
        case when p_link_target_type = 'booking_item' then p_link_target_id end,
        case when p_link_target_type = 'invoice'      then p_link_target_id end,
        case when p_link_target_type = 'receipt'      then p_link_target_id end,
        case when p_link_target_type = 'supplier'     then p_link_target_id end,
        v_actor
    );

    perform app.record_event(
        v_tenant, 'document_uploaded', 'document', v_document_id, v_actor,
        null, 'active', null,
        jsonb_build_object('document_type_code', p_document_type_code, 'file_type_code', lower(p_file_type_code),
                           'link_target_type', p_link_target_type, 'link_target_id', p_link_target_id),
        'info'
    );
    perform app.record_event(
        v_tenant, 'document_linked', 'document', v_document_id, v_actor,
        null, p_link_target_type, null,
        jsonb_build_object('link_target_type', p_link_target_type, 'link_target_id', p_link_target_id),
        'info'
    );

    return v_document_id;
end;
$fn$;

revoke execute on function app.upload_document(text, text, text, text, text, uuid, bigint, timestamptz, boolean) from public;
grant  execute on function app.upload_document(text, text, text, text, text, uuid, bigint, timestamptz, boolean) to authenticated;

comment on function app.upload_document(text, text, text, text, text, uuid, bigint, timestamptz, boolean) is
    'Creates a document, its first version and its link. The storage path is NOT a parameter: it is '
    'derived by app.document_storage_path and cannot be influenced by the caller on any path.';

drop function if exists app.add_document_version(uuid, text, text, text, bigint);

create function app.add_document_version(
    p_document_id uuid,
    p_file_name text,
    p_file_type_code text,
    p_file_size bigint default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_doc record;
    v_version_id uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if lower(coalesce(p_file_type_code, '')) not in ('pdf', 'jpg', 'jpeg', 'png', 'webp') then
        raise exception 'file type % is not allowed (MVP: pdf, jpg, jpeg, png, webp)', p_file_type_code;
    end if;

    select id, lifecycle_status_code, is_archived
      into v_doc
    from public.documents
    where id = p_document_id and tenant_id = v_tenant;
    if not found then
        raise exception 'document is not in your tenant';
    end if;
    if v_doc.is_archived or v_doc.lifecycle_status_code = 'archived' then
        raise exception 'cannot add a version to an archived document';
    end if;

    perform app.authorize('CREATE_DOCUMENT_VERSION');

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- Demote first: the partial unique index permits exactly one current version per document, so
    -- this ordering is now enforced by the database rather than merely observed by this function.
    update public.document_versions set is_current = false
    where document_id = p_document_id and tenant_id = v_tenant and is_current;

    insert into public.document_versions (
        tenant_id, document_id, file_name, file_type_code, file_size, is_current
    ) values (
        v_tenant, p_document_id, p_file_name, lower(p_file_type_code), p_file_size, true
    ) returning id into v_version_id;

    update public.documents set current_version_id = v_version_id, updated_at = now()
    where id = p_document_id;

    perform app.record_event(
        v_tenant, 'document_version_created', 'document', p_document_id, v_actor,
        null, 'active', null,
        jsonb_build_object('version_id', v_version_id, 'file_type_code', lower(p_file_type_code)),
        'info'
    );

    return v_version_id;
end;
$fn$;

revoke execute on function app.add_document_version(uuid, text, text, bigint) from public;
grant  execute on function app.add_document_version(uuid, text, text, bigint) to authenticated;

comment on function app.add_document_version(uuid, text, text, bigint) is
    'Supersedes a document with a new version. Version number, storage path and uploader are all '
    'system-derived; a version''s identity is immutable once written.';
