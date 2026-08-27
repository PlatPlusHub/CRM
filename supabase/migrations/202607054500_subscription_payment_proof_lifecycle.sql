-- WP-04-B -- the subscription payment-proof lifecycle, end to end, and the narrowed document gate.
--
-- This is not "add a catalog value". Re-introspection found the capability broken in five places at
-- once, which is why it is one transactional package rather than five small ones:
--
--   1. `document_type` has no `payment_proof` value -- a mandatory business concept could only be
--      filed as `other`.
--   2. `subscription_payment` IS ALREADY a `document_link_target_type`, but `app.upload_document`
--      has no branch for it, so it falls through to `else false` and raises. The vocabulary was
--      seeded and the code path was never written.
--   3. `document_links.subscription_payment_proof_id` has no producer at all.
--   4. `subscription_payment_proofs.status_code` is unconstrained free text -- no catalog, no FK, no
--      trigger. Any string was a valid status.
--   5. There is no review path, so `REVIEW_SUBSCRIPTION_PAYMENT` (held by no role, correctly --
--      canon 28 makes review a PLATFORM OWNER action) had nothing to govern.
--
-- THE CIRCULAR DEPENDENCY, and why this needs a dedicated RPC rather than another parameter on
-- `app.upload_document`: `subscription_payment_proofs.document_id` is NOT NULL, so the proof needs a
-- document first; but `document_links.subscription_payment_proof_id` needs the proof id. The only
-- correct resolution is one transaction that creates document -> version -> proof -> link in that
-- order. Adding a parameter to `upload_document` could not express it, because that function returns
-- after creating the link and has no proof to link to.
--
-- ATOMICITY, stated honestly: everything below is one PostgreSQL transaction, so a failure at ANY
-- step leaves no half-created document, no orphan proof and no orphan link. That guarantee covers
-- the METADATA only. When an object store is added (WP-04-C), the binary upload will sit OUTSIDE
-- this transaction and no database transaction can roll it back -- an orphaned object is possible
-- and must be reconciled by the storage package. This migration does not pretend otherwise.
--
-- NO NEW VOCABULARY WAS INVENTED. Canon 26's approval machine is pending -> approved / rejected /
-- cancelled, with rejected -> pending for resubmission, and the catalog family `approval_status_code`
-- already holds exactly those four codes. It is reused verbatim.

-- ---------------------------------------------------------------------------------------------
-- 1. The missing document type, and its financial classification.
--
--    A bank-transfer receipt IS a financial document, so it joins `app.is_financial_document_type`.
--    That is not a new rule: it means the `documents` RLS branch
--    `is_confidential AND VIEW_FINANCIAL_DOCUMENTS AND is_financial_document_type` governs it, so a
--    frontline employee cannot read the company's bank transfer while Owner/CEO/Finance can. The
--    alternative -- leaving it unclassified -- would have made it an ordinary linked document that
--    any employee could open.
-- ---------------------------------------------------------------------------------------------
insert into public.catalog_values
    (tenant_id, catalog_type_code, code, label, description, sort_order, is_active, is_system)
values
    (null, 'document_type', 'payment_proof', 'Payment Proof',
     'Bank transfer proof supporting a subscription renewal (canon 09).', 13, true, true);

create or replace function app.is_financial_document_type(p_document_type_code text)
returns boolean
language sql
immutable
set search_path = ''
as $fn$
    select p_document_type_code in ('invoice', 'receipt', 'quotation', 'payment_proof')
$fn$;

-- ---------------------------------------------------------------------------------------------
-- 2. The proof status stops being free text.
--
--    `status_code` had no catalog, no FK and no trigger, so `'banana'` was a valid status. The
--    catalog trigger is the mechanism every other status column in ORVION already uses.
-- ---------------------------------------------------------------------------------------------
update public.subscription_payment_proofs
   set status_code = 'pending'
 where status_code not in ('pending', 'approved', 'rejected', 'cancelled');

create trigger subscription_payment_proofs_enforce_catalog_codes
    before insert or update on public.subscription_payment_proofs
    for each row execute function app.enforce_catalog_codes(
        'status_code', 'approval_status_code');

-- ---------------------------------------------------------------------------------------------
-- 3. The tenant side: one transaction, four rows.
--
--    ACTOR: `MANAGE_TENANT_SETTINGS`, which is Owner + CEO. Canon 09 calls this actor "the tenant
--    admin" and SPEC-158 already uses the same permission for redeeming a licence -- the same
--    person, the same commercial responsibility. `UPLOAD_DOCUMENT` was rejected as the gate because
--    it is held by every operational role down to trainee-adjacent staff, and the company's bank
--    transfer is not frontline work.
--
--    `app.authorize` (not `has_permission`) so MFA composes: canon 28 requires TOTP for owner and
--    ceo, and paying for the company's licence is exactly a step-up action.
-- ---------------------------------------------------------------------------------------------
create or replace function app.upload_subscription_payment_proof(
    p_file_name text,
    p_file_type_code text,
    p_file_size bigint default null,
    p_note text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_subscription_id uuid;
    v_document_id uuid;
    v_version_id uuid;
    v_proof_id uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if lower(coalesce(p_file_type_code, '')) not in ('pdf', 'jpg', 'jpeg', 'png') then
        raise exception 'a payment proof must be a pdf or an image (pdf, jpg, jpeg, png)';
    end if;
    if p_file_size is not null and p_file_size <= 0 then
        raise exception 'file_size must be greater than zero';
    end if;

    perform app.authorize('MANAGE_TENANT_SETTINGS');

    -- Same "latest row wins" rule `app.subscription_allows_write` uses, so the proof always attaches
    -- to the subscription the rest of the system is judging.
    select id into v_subscription_id
    from public.subscriptions
    where tenant_id = v_tenant
    order by created_at desc
    limit 1;
    if v_subscription_id is null then
        raise exception 'this tenant has no subscription to pay for';
    end if;

    v_actor := app.current_user_id();

    -- Confidential by default: this is the company's bank transfer, not an operational document.
    insert into public.documents (
        tenant_id, document_type_code, title, lifecycle_status_code,
        is_confidential, created_by
    ) values (
        v_tenant, 'payment_proof',
        'Subscription payment proof ' || to_char(now(), 'YYYY-MM-DD'), 'active',
        true, v_actor
    ) returning id into v_document_id;

    -- version_number, storage_path and uploaded_by are all derived by WP-04-A's integrity trigger.
    insert into public.document_versions (
        tenant_id, document_id, file_name, file_type_code, file_size, is_current
    ) values (
        v_tenant, v_document_id, p_file_name, lower(p_file_type_code), p_file_size, true
    ) returning id into v_version_id;

    update public.documents set current_version_id = v_version_id, updated_at = now()
    where id = v_document_id;

    insert into public.subscription_payment_proofs (
        tenant_id, subscription_id, document_id, uploaded_by, status_code, review_notes
    ) values (
        v_tenant, v_subscription_id, v_document_id, v_actor, 'pending', p_note
    ) returning id into v_proof_id;

    -- The link that had no producer. It is written LAST because it is the only row that needs the
    -- proof id -- which is what the circular dependency actually amounts to.
    insert into public.document_links (
        tenant_id, document_id, subscription_payment_proof_id, created_by
    ) values (
        v_tenant, v_document_id, v_proof_id, v_actor
    );

    perform app.record_event(
        v_tenant, 'subscription_payment_proof_uploaded', 'subscription', v_subscription_id, v_actor,
        null, 'pending', null,
        jsonb_build_object('proof_id', v_proof_id, 'document_id', v_document_id),
        'info'
    );

    return v_proof_id;
end;
$fn$;

revoke execute on function app.upload_subscription_payment_proof(text, text, bigint, text) from public;
grant  execute on function app.upload_subscription_payment_proof(text, text, bigint, text) to authenticated;

comment on function app.upload_subscription_payment_proof(text, text, bigint, text) is
    'Tenant admin uploads a subscription renewal proof. Creates document, version, proof and link in '
    'ONE transaction, resolving the circular dependency between them. Metadata only: an object store '
    'upload sits outside this transaction and cannot be rolled back by it.';

-- ---------------------------------------------------------------------------------------------
-- 4. The platform side. `service_role` only -- canon 28: "Subscription proof review is platform
--    owner action" and "Tenant users may upload proof but cannot approve their own subscription
--    renewal." `REVIEW_SUBSCRIPTION_PAYMENT` stays held by NO role, which is what makes the RLS
--    policy on `subscription_payment_proofs` deny every tenant user; that is deliberate and tested.
--
--    WHY `reviewed_by` IS LEFT NULL: the column references `public.users`, which contains only
--    TENANT users. A platform reviewer is not one, so writing any value there would be a lie. The
--    reviewer is recorded in the event and in `security_events` instead. Recorded as a finding
--    rather than papered over by inventing a synthetic user row.
--
--    APPROVAL AND ACTIVATION ARE SEPARATE but can be atomic. A bank transfer does not itself say
--    which plan or period it bought, so approving a proof cannot infer terms. When the Platform
--    Owner knows the terms they pass them and the subscription activates in the same transaction;
--    when they do not, the proof is simply approved. Canon 09 describes exactly this: "The platform
--    owner reviews the proof and activates renewal."
-- ---------------------------------------------------------------------------------------------
create or replace function app.platform_review_payment_proof(
    p_proof_id uuid,
    p_approve boolean,
    p_notes text default null,
    p_plan_code text default null,
    p_billing_period_code text default null,
    p_auto_renew boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_proof record;
    v_new_status text;
begin
    select id, tenant_id, subscription_id, status_code
      into v_proof
    from public.subscription_payment_proofs
    where id = p_proof_id;
    if not found then
        raise exception 'unknown payment proof %', p_proof_id;
    end if;

    -- Canon 26's approval machine: only a PENDING proof can be decided. This also makes review
    -- idempotent-safe -- a second approval of the same proof is refused rather than silently
    -- re-activating a subscription.
    if v_proof.status_code <> 'pending' then
        raise exception 'payment proof is already %, only a pending proof can be reviewed',
            v_proof.status_code using errcode = 'check_violation';
    end if;

    v_new_status := case when p_approve then 'approved' else 'rejected' end;

    update public.subscription_payment_proofs
       set status_code  = v_new_status,
           reviewed_at  = now(),
           review_notes = coalesce(p_notes, review_notes)
     where id = p_proof_id;

    perform app.record_event(
        v_proof.tenant_id,
        case when p_approve then 'subscription_payment_approved'
             else 'subscription_payment_rejected' end,
        'subscription', v_proof.subscription_id, null,
        'pending', v_new_status, p_notes,
        jsonb_build_object('proof_id', p_proof_id),
        'info'
    );

    insert into public.security_events (tenant_id, security_event_type_code, payload)
    values (v_proof.tenant_id, 'subscription_payment_reviewed',
            jsonb_build_object('proof_id', p_proof_id, 'decision', v_new_status));

    -- Activation only when the Platform Owner supplied the terms. Delegated rather than reimplemented
    -- so the canon-26 transition check, the end-date derivation and the lifetime rule keep exactly
    -- one home (SPEC-157).
    if p_approve and p_plan_code is not null and p_billing_period_code is not null then
        perform app.platform_activate_subscription(
            v_proof.tenant_id, p_plan_code, p_billing_period_code, p_auto_renew);
    end if;
end;
$fn$;

revoke execute on function app.platform_review_payment_proof(uuid, boolean, text, text, text, boolean) from public;
grant  execute on function app.platform_review_payment_proof(uuid, boolean, text, text, text, boolean) to service_role;

insert into public.catalog_values
    (tenant_id, catalog_type_code, code, label, description, sort_order, is_active, is_system)
values
    (null, 'security_event_type', 'subscription_payment_reviewed', 'Subscription Payment Reviewed',
     'Platform Owner approved or rejected a subscription payment proof.', 18, true, true);

-- ---------------------------------------------------------------------------------------------
-- 5. THE NARROWED SUBSCRIPTION GATE (owner directive §5/§7).
--
--    WP-03 exempted `documents`, `document_versions` and `document_links` from the write gate so a
--    lapsed tenant could still upload renewal proof. That was necessary then and is too broad now:
--    confirmed live, a `suspended` tenant could create ANY document -- passports, tickets, invoices --
--    not merely a renewal proof.
--
--    The narrowing is only expressible now, because it needs a discriminator: `payment_proof` is the
--    document type by which the gate can tell a renewal proof from ordinary work. Sequencing this
--    before §1 would have meant inventing a placeholder.
--
--    This is a SEPARATE trigger name from WP-03's generated `..._enforce_subscription_write_gate`,
--    deliberately: those three tables stay off the generated attachment (so its coverage test still
--    reads true in both directions) and gain a specialised gate instead.
--
--    Canon 28's Read-Only Subscription Mode is the authority for the shape: "Upload subscription
--    renewal proof" is ALLOWED, while "Upload business document" is BLOCKED. That is exactly this
--    rule, and it was already written down -- it had simply never been enforced.
-- ---------------------------------------------------------------------------------------------
create or replace function app.enforce_document_subscription_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_row      jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
    v_tenant   uuid  := (v_row ->> 'tenant_id')::uuid;
    v_doc_type text;
begin
    if v_tenant is null then
        return case when tg_op = 'DELETE' then old else new end;
    end if;

    if app.subscription_allows_write(v_tenant) then
        return case when tg_op = 'DELETE' then old else new end;
    end if;

    -- Restricted state. The single exception canon 28 grants is the renewal proof.
    if tg_table_name = 'documents' then
        v_doc_type := v_row ->> 'document_type_code';
    else
        select d.document_type_code into v_doc_type
        from public.documents d
        where d.id = (v_row ->> 'document_id')::uuid;
    end if;

    if v_doc_type = 'payment_proof' then
        return case when tg_op = 'DELETE' then old else new end;
    end if;

    raise exception
        'subscription state does not permit creating %.% -- a restricted tenant may still upload a '
        'subscription payment proof, and may still read and export everything it already has',
        tg_table_schema, tg_table_name
        using errcode = 'insufficient_privilege';
end;
$fn$;

revoke execute on function app.enforce_document_subscription_gate() from public;

create trigger documents_enforce_document_subscription_gate
    before insert or update or delete on public.documents
    for each row execute function app.enforce_document_subscription_gate();

create trigger document_versions_enforce_document_subscription_gate
    before insert or update or delete on public.document_versions
    for each row execute function app.enforce_document_subscription_gate();

create trigger document_links_enforce_document_subscription_gate
    before insert or update or delete on public.document_links
    for each row execute function app.enforce_document_subscription_gate();
