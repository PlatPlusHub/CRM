-- ATTR-2 -- the two ACTION attributions that a session can actually fill.
--
-- ================================================================================================
-- WHY THESE TWO AND NOT THE FIVE THE SWEEP RETURNED
--
-- ATTR-1 derived `created_by` on twenty tables and deliberately left the ACTION attributions alone,
-- because they are stamped when an action happens rather than when a row is created. Reading each
-- one individually rather than treating them as a group split them three ways:
--
--   DERIVED HERE
--     `subscription_payment_proofs.uploaded_by` -- set by `app.upload_subscription_payment_proof`
--        from the session. It is an INSERT-time attribution after all; it was excluded from ATTR-1
--        only because the column is not called `created_by`, which is a naming accident, not a
--        difference in kind.
--     `approval_requests.reviewed_by` -- set by `app.review_finance_approval` from the session,
--        alongside the status. Derived on UPDATE, when it changes, so the RPC path is unaffected and
--        the direct path cannot name someone else as the reviewer.
--
--   NOT AN ATTRIBUTION DEFECT AT ALL: `invoices.voided_by` and `journal_entries.voided_by`.
--     NOTHING in the database writes them -- no function, no trigger -- and `app.status_transitions`
--     has no `invoices` or `journal_entries` rows either. Voiding is not implemented; the columns
--     (`voided_at`, `voided_by`, `void_reason`) promise a capability that does not exist. Deriving
--     an attribution for an action nobody can perform would dress a missing capability as a solved
--     one. Recorded as VOID-1.
--
--   STRUCTURALLY UNFILLABLE: `subscription_payment_proofs.reviewed_by`.
--     Review is `app.platform_review_payment_proof`, a PLATFORM action -- and the column's FK is
--     `(tenant_id, reviewed_by) -> public.users`, the TENANT membership table, which a platform
--     operator has no row in. So the reviewer cannot be recorded there even in principle, and the
--     function correctly does not try. Whether the platform identity belongs in this column, in a
--     separate one, or only in the event spine is a design question. Recorded as SPP-3.
-- ================================================================================================

create or replace function app.derive_proof_uploader()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if tg_op = 'INSERT' then
        new.uploaded_by := app.current_user_id();
    else
        new.uploaded_by := old.uploaded_by;
    end if;
    return new;
end
$fn$;

revoke execute on function app.derive_proof_uploader() from public;

create trigger subscription_payment_proofs_derive_uploader
    before insert or update on public.subscription_payment_proofs
    for each row execute function app.derive_proof_uploader();

create or replace function app.derive_approval_reviewer()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    -- Only when the reviewer CHANGES, so an unrelated update to an already-decided request does not
    -- silently re-attribute the decision to whoever touched the row last.
    if new.reviewed_by is distinct from old.reviewed_by then
        new.reviewed_by := app.current_user_id();
    end if;
    return new;
end
$fn$;

revoke execute on function app.derive_approval_reviewer() from public;

-- UPDATE only: `requested_by` is already derived on INSERT by `app.derive_approval_requester`, and a
-- request carries no reviewer until it is decided.
create trigger approval_requests_derive_reviewer
    before update on public.approval_requests
    for each row execute function app.derive_approval_reviewer();
