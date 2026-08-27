-- WP-04-C / SPP-1 + SPP-2 -- the payment-proof table gets the authority its parent has always had.
--
-- FOUND BY A FAILING ASSERTION IN MY OWN NEW TEST, not by inspection, and it is a defect my own
-- WP-04-B package should have caught: that package added the review path, the catalog trigger and
-- the narrowed gate to this table without ever comparing its RLS against its parent. That is
-- precisely the sibling-table audit the programme has now been bitten by three times -- FIN-1
-- (booking_items vs booking_item_passengers), DOC-1/DOC-3 (documents vs document_versions), and now
-- this.
--
-- THE ASYMMETRY, read live from `pg_policy`:
--
--   subscriptions                 read   : tenant AND has_permission('VIEW_SUBSCRIPTION_STATUS')
--   subscription_payment_proofs   read   : tenant ONLY                            <-- SPP-1
--
--   subscriptions                 insert : tenant AND has_permission('MANAGE_SUBSCRIPTION')
--   subscription_payment_proofs   insert : tenant ONLY                            <-- SPP-2
--
--   subscriptions                 update : tenant AND MANAGE_SUBSCRIPTION
--   subscription_payment_proofs   update : tenant AND REVIEW_SUBSCRIPTION_PAYMENT   (already correct)
--
-- WHAT THAT ACTUALLY ALLOWED
--
--   SPP-1: every tenant user -- down to a trainee -- could read every payment proof: when the
--   company paid, who uploaded it, the reviewer's notes and the decision. `subscriptions` itself is
--   properly restricted to Owner/CEO, so this leaked the commercial history of the agency through
--   the one sibling nobody gated.
--
--   SPP-2: any tenant user could FORGE a payment proof by direct DML -- no permission required at
--   all. They could not approve it (update was already gated), but a fabricated `pending` proof
--   pointing at any document they can see is audit pollution, and a plausible way to mislead the
--   Platform Owner into approving a renewal that was never paid.
--
-- THE FIX: make each policy say what its parent says.
--
--   READ  -> `VIEW_SUBSCRIPTION_STATUS`, identical to `subscriptions.scope_read`. Owner and CEO hold
--            it, and they are exactly who uploads and inspects a proof.
--
--   INSERT -> `MANAGE_TENANT_SETTINGS`, NOT `MANAGE_SUBSCRIPTION`. This is the one place the two
--            tables must legitimately differ: `MANAGE_SUBSCRIPTION` is deliberately held by NO role
--            because subscription state is Platform Owner authority (SPEC-157), so requiring it here
--            would make proof upload impossible for everyone and break the only route back from a
--            lapsed subscription. `MANAGE_TENANT_SETTINGS` is the permission
--            `app.upload_subscription_payment_proof` already authorizes, so RLS and the RPC now
--            agree instead of the RPC being the only thing charging for the write.
--
-- CROSS-PATH NOTE: `app.platform_review_payment_proof` is SECURITY DEFINER and runs as the owner, so
-- it is unaffected by either policy -- the Platform Owner keeps reviewing proofs it could never have
-- read as a tenant user. That is the intended asymmetry, not a hole.

drop policy scope_read on public.subscription_payment_proofs;

create policy scope_read on public.subscription_payment_proofs
    for select
    using (
        tenant_id = (select app.current_tenant_id())
        and (select app.has_permission('VIEW_SUBSCRIPTION_STATUS'))
    );

drop policy scope_insert on public.subscription_payment_proofs;

create policy scope_insert on public.subscription_payment_proofs
    for insert
    with check (
        tenant_id = (select app.current_tenant_id())
        and (select app.has_permission('MANAGE_TENANT_SETTINGS'))
    );
