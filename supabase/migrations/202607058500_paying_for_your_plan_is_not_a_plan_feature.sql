-- API-3 subscription/licensing family, second package.
--
-- ================================================================================================
-- LIC-3 (High) -- the ONLY way back from `read_only` is unavailable on the plan most likely to need it.
--
-- canon 09/28, as recorded in this register's DOC-2 row: a lapsed tenant uploads bank-transfer proof
-- so the Platform Owner can reactivate it -- *"the only way back from `read_only`"*. WP-04-B built
-- that path and narrowed the SUBSCRIPTION write gate for it ("a lapsed tenant may upload a renewal
-- proof and nothing else"). The PLAN gate was never considered.
--
-- `app.upload_subscription_payment_proof` charges `MANAGE_TENANT_SETTINGS`, which carries no
-- `required_feature_code`. But it then INSERTs into `public.documents` and `public.document_versions`,
-- whose guards charge `UPLOAD_DOCUMENT` and `CREATE_DOCUMENT_VERSION` -- and BOTH of those carry
-- `required_feature_code = 'documents'`, which `feature_entitlements` sets **false** for the
-- `starter` plan. So the entry-level plan cannot file the proof that pays for the plan.
--
-- REPRODUCED with a discriminating experiment -- two tenants identical in every respect except the
-- plan, the same `owner` role, the same aal2 claim, the same call:
--   professional (documents = true):  has_permission('UPLOAD_DOCUMENT') = TRUE,  upload SUCCEEDS
--   starter      (documents = false): has_permission('UPLOAD_DOCUMENT') = FALSE, upload REFUSED
--                                     ("permission denied: one of UPLOAD_DOCUMENT is required")
--                                     while has_permission('MANAGE_TENANT_SETTINGS') = TRUE
-- The plan is the only variable, so the plan is the cause.
--
-- ================================================================================================
-- PP-4 (Medium) -- and the same two guards were the WRONG strength in the other direction.
--
-- REPRODUCED in the same run: a plain `employee` on a professional plan, holding **no**
-- `MANAGE_TENANT_SETTINGS`, INSERTed a `documents` row with `document_type_code = 'payment_proof'`
-- marked confidential -- `INSERT 0 1`. The RPC requires MANAGE_TENANT_SETTINGS; the table charged
-- only UPLOAD_DOCUMENT, which every ordinary role holds. That is SPP-2's shape one table over:
-- SPP-2 closed the forged proof on `subscription_payment_proofs` and the `documents` half was not
-- considered, so a fabricated "payment proof" document could still be planted in the tenant's
-- confidential set for a Platform Owner to find while reviewing renewals.
--
-- ================================================================================================
-- ONE FIX, DERIVED RATHER THAN INVENTED, AND IT MOVES BOTH FAULTS TOWARD THE SAME RULE.
--
-- For a document whose type is `payment_proof`, the guards charge `MANAGE_TENANT_SETTINGS` -- the
-- permission `app.upload_subscription_payment_proof` **already charges at its own entry**. Nothing
-- here decides new policy: it aligns the table door with the RPC that owns the action, which is the
-- direction every API-3 finding in this programme has moved. And it is correct on the plan axis for
-- a reason that is not a preference: **paying for your plan cannot itself be a plan feature.**
-- `MANAGE_TENANT_SETTINGS` carries no `required_feature_code`, so the recovery path stops depending
-- on the entitlement the tenant is trying to restore.
--
-- WHAT WAS DELIBERATELY NOT DONE: the `starter` plan's `documents` entitlement is NOT changed. What
-- a plan includes is a commercial decision belonging to the owner, and flipping an entitlement to
-- fix an authorization bug would have silently sold a feature. Nothing else about either guard moves
-- -- WP-04-A's derivation of `version_number` / `storage_path` / `uploaded_by` and its immutability
-- rules are reproduced verbatim, because this migration is about WHICH permission is charged, not
-- about what the guards derive or freeze.
--
-- The `payment_proof` branch is STRICT (`MANAGE_TENANT_SETTINGS` alone, not "either"), because the
-- "either" form would leave PP-4 open -- an employee holds UPLOAD_DOCUMENT. Completeness checked:
-- the only functions that create a payment-proof document are
-- `app.upload_subscription_payment_proof` (charges MANAGE_TENANT_SETTINGS) and the service_role
-- platform review path, which is session-less and returns early from both guards.

create or replace function app.guard_write_capability()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_perms text[];
    v_perm  text;
    v_held  text;
begin
    -- Platform/system paths (canon 35 principle 6), as in every other guard here.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- 202607058500 (LIC-3 / PP-4): `documents` is resolved in its OWN statement, not inside the
    -- shared CASE below. A record field reference is resolved against the ACTUAL record type at
    -- execution, so naming `new.document_type_code` inside an expression this trigger also evaluates
    -- for `customers`, `leads` and twenty other tables fails on every one of them -- a CASE branch
    -- being untaken does not make the field reference disappear. The first draft of this migration
    -- did exactly that and the suite refused it across 21 files.
    --
    -- A subscription payment proof is a BILLING artefact, not a use of the documents module: it
    -- charges the permission its own RPC charges, which is also the only one not gated on the
    -- `documents` entitlement the tenant is trying to restore.
    if tg_table_name = 'documents' then
        if new.document_type_code = 'payment_proof' then
            v_perms := array['MANAGE_TENANT_SETTINGS'];
        else
            v_perms := array['UPLOAD_DOCUMENT'];
        end if;
    else
    v_perms := case tg_table_name
                   -- 202607056000: the permission each table's own RPC already charges.
                   when 'approval_requests'         then array['CREATE_BOOKING_ITEM']
                   when 'conversation_messages'     then array['SEND_MESSAGE']
                   when 'customer_contact_methods'  then array['CREATE_CUSTOMER']
                   when 'customer_identity_signals' then array['CREATE_CUSTOMER']
                   when 'customer_identity_merges'  then array['MERGE_CUSTOMER_IDENTITY']
                   when 'internal_supplier_links'   then array['ASSIGN_SUPPLIER']
                   when 'offline_conversions'       then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                   when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
                   -- 202607056100: no RPC writes these at all, so the permission comes from what
                   -- ORVION charges for the parent object or for the same class of master data.
                   when 'branch_business_hours'     then array['MANAGE_BRANCHES']
                   when 'holidays'                  then array['MANAGE_BRANCHES','MANAGE_TENANT_SETTINGS']
                   when 'financial_accounts'        then array['CREATE_JOURNAL_ENTRY']
                   when 'company_assets'            then array['CREATE_JOURNAL_ENTRY']
                   -- 202607057000 (SEC-1b): the twelve the ceiling's detector was crediting for an
                   -- UPDATE-only trigger. Read out of each table's own creating RPC.
                   when 'bookings'                  then array['CREATE_BOOKING']
                   when 'complaints'                then array['CREATE_COMPLAINT']
                   when 'conversations'             then array['SEND_MESSAGE']
                   when 'customer_notes'            then array['CREATE_CUSTOMER']
                   when 'customers'                 then array['CREATE_CUSTOMER']
                   when 'leads'                     then array['CREATE_LEAD']
                   when 'passengers'                then array['CREATE_BOOKING_ITEM']
                   when 'quotations'                then array['CREATE_QUOTATION']
                   when 'service_requests'          then array['CREATE_SERVICE_REQUEST']
                   when 'suppliers'                 then array['ASSIGN_SUPPLIER']
                   when 'tasks'                     then array['CREATE_TASK']
               end;
    end if;

    if v_perms is null then
        -- Attached to a table with no mapping. Refusing is the only safe reading: returning NEW
        -- would manufacture the exact unguarded path this migration exists to close.
        raise exception 'guard_write_capability has no permission mapping for %', tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    -- `has_permission` first to find WHICH of the alternatives the caller holds, then `authorize`
    -- on that one -- because authorize is what also composes the MFA step-up, and a bare
    -- has_permission check would silently drop it for the roles canon 28 requires it from.
    foreach v_perm in array v_perms loop
        if app.has_permission(v_perm) then
            v_held := v_perm;
            exit;
        end if;
    end loop;

    if v_held is null then
        raise exception 'permission denied: one of % is required to write %',
                        array_to_string(v_perms, ' or '), tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    perform app.authorize(v_held);
    return new;
end
$fn$;

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
end
$fn$;
