-- WP-04-C -- the document object store: a private bucket, and object authorization that is the SAME
-- mechanism as row authorization.
--
-- ================================================================================================
-- PROVIDER EVALUATION -- FACT, then RECOMMENDATION, kept separate (owner directive §12).
--
-- ORVION's requirements are not generic. They were established by earlier packages and are facts
-- about this repository, not preferences:
--
--   R1. The object key is `tenant/document/version`, derived server-side and tenant-first
--       (WP-04-A, `app.document_storage_path`). Whatever stores the bytes must let policy enforce
--       isolation on the first path segment.
--   R2. Canon 35 principle 4: every policy calls an `app.*` primitive so the mechanism evolves in
--       ONE place. A second, independent authorization system would fork the security model.
--   R3. Document visibility is already a solved, tested problem: `documents.scope_isolation` carries
--       confidential/financial branches, and `document_versions` inherits from its parent.
--   R4. AGENTS.md §6: an external credential is entered by the owner directly into its destination,
--       never through the agent. Any provider needing one carries a real BLOCKED — EXTERNAL
--       DEPENDENCY step before it can even be evaluated end to end.
--   R5. Tenants are many small Egyptian travel agencies. Documents are passports, tickets, vouchers,
--       invoices and payment proofs: numerous, small, and strictly isolated.
--
-- FACTS ABOUT THE CANDIDATES
--
--   Supabase Storage -- `storage.objects` is a PostgreSQL TABLE. Verified live on Primary:
--     relkind = 'r', relrowsecurity = true, policies = 0 (so it is fail-closed today). Bucket rows
--     carry `file_size_limit` and `allowed_mime_types`, so size and type are enforceable by the
--     store itself and not only by the RPC that records metadata. Private buckets serve bytes only
--     through signed URLs or an RLS-authorized request.
--
--   Google Cloud Storage -- prefix-per-tenant plus IAM is the standard shared-infrastructure
--     pattern, but current practice reports two hard limits for this shape: dynamically generated
--     IAM policies are not supported, and IAM policy size becomes a ceiling as tenants multiply.
--     The recommended escape is a "token vending machine" -- an additional always-on service that
--     mints scoped credentials. Project-per-tenant gives the strongest isolation and is
--     disproportionate for small agencies.
--
--   Google Drive / OneDrive / SharePoint -- these are collaboration products, not application
--     storage backends. Per-tenant OAuth, change detection and pagination become sustained
--     infrastructure work; SharePoint's quota is a shared tenant POOL rather than per-customer
--     allocation, which is the opposite of predictable isolation; Microsoft Graph caps a single PUT
--     at 250 MB. All three also require an external credential (R4).
--
-- RECOMMENDATION, and the reason it is not "Supabase because it is already here"
--
--   Supabase Storage is selected on ONE decisive property: it is the only candidate where object
--   authorization and row authorization are the SAME mechanism. Because `storage.objects` is a
--   Postgres table with RLS, the very `app.current_tenant_id()` primitive that governs `documents`
--   governs the bytes -- and, as written below, an object is visible exactly when its
--   `document_versions` row is visible. Every other candidate requires a second authorization
--   system that cannot see ORVION's RLS, which would mean maintaining the document-visibility rules
--   (confidential, financial, branch, ownership) twice and keeping them in agreement forever. That
--   is the duplicated authority canon 35 exists to prevent, and R2 forbids it.
--
--   Cost did not decide this and is not cited as a reason. If ORVION ever needs an external store
--   (regulatory residency, or files far beyond CRM documents), the object key is already
--   provider-independent, so the migration path is a copy plus a policy rewrite -- not a redesign.
--
--   REJECTED, with the reason recorded rather than left implicit: GCS on IAM-scalability plus the
--   extra service R2 forbids; Drive/OneDrive/SharePoint on being collaboration products whose quota
--   and identity models fight multi-tenant isolation.
-- ================================================================================================

-- ---------------------------------------------------------------------------------------------
-- 1. The bucket. PRIVATE -- `public = false` means no anonymous URL exists at all, so an object is
--    reachable only through an RLS-authorized request or a signed URL minted for one.
--
--    `file_size_limit` and `allowed_mime_types` are enforced by the STORE, which matters because
--    the metadata RPC and the byte upload are two different calls: a caller could record a
--    plausible `document_versions` row and then attempt to push something else entirely. The MIME
--    list mirrors the types `app.upload_document` already accepts (pdf, jpg, jpeg, png, webp) so the
--    two cannot drift apart silently.
--
--    10 MB is an engineering default derived from what these documents are -- passport scans,
--    tickets, vouchers, invoices -- not a business rule. It is one UPDATE to change.
-- ---------------------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'documents', 'documents', false, 10485760,
    array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------------------------
-- 2. Object authorization = document authorization.
--
--    The predicate deliberately does NOT restate who may see a document. It asks whether the
--    caller can see the `document_versions` row whose `storage_path` equals this object's name --
--    and that subquery is itself subject to `document_versions.scope_isolation`, which in turn
--    requires the parent `documents` row to be visible, which carries the confidential/financial/
--    branch/ownership branches SPEC-139 and SPEC-154 already proved. So the entire document
--    visibility model applies to the bytes without a single rule being duplicated.
--
--    The tenant-prefix test is defence in depth rather than the primary control. WP-04-A already
--    makes the path underivable by a caller, but an object whose first segment is not the caller's
--    tenant should be unreachable even if some future path let a stray row exist.
-- ---------------------------------------------------------------------------------------------
create policy documents_read_own_tenant
    on storage.objects for select
    to authenticated
    using (
        bucket_id = 'documents'
        and (storage.foldername(name))[1] = (select app.current_tenant_id())::text
        and exists (
            select 1 from public.document_versions dv
            where dv.storage_path = storage.objects.name
        )
    );

-- INSERT is how the binary arrives, AFTER the metadata transaction has run. The metadata row must
-- therefore already exist and be visible -- which means an object can only be created for a
-- document the caller was authorized to create in the first place. A caller cannot upload bytes to
-- a path no `document_versions` row claims.
create policy documents_write_own_tenant
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'documents'
        and (storage.foldername(name))[1] = (select app.current_tenant_id())::text
        and exists (
            select 1 from public.document_versions dv
            where dv.storage_path = storage.objects.name
        )
    );

-- NO UPDATE AND NO DELETE POLICY, and that is the design rather than an omission. RLS with no
-- policy denies, so both are refused for every tenant user. Documents are VERSIONED: superseding a
-- document creates a new version at a new key (WP-04-A made a version's identity immutable), so
-- overwriting an object in place would defeat the audit trail the whole document model exists to
-- keep. Retention and deletion are a platform/lifecycle concern executed by `service_role`, which
-- bypasses RLS -- and they are recorded as WP-04-D rather than improvised here.

-- ---------------------------------------------------------------------------------------------
-- 3. A named home for the bucket, so no caller hardcodes the string and no future writer has to
--    guess which bucket a document lives in.
-- ---------------------------------------------------------------------------------------------
create or replace function app.document_bucket()
returns text
language sql
immutable
set search_path = ''
as $fn$
    select 'documents'::text
$fn$;

revoke execute on function app.document_bucket() from public;
grant  execute on function app.document_bucket() to authenticated;

comment on function app.document_bucket() is
    'The single name of the private bucket holding ORVION documents. Objects are authorized by the '
    'same RLS that authorizes their document_versions row -- see the policies on storage.objects.';
