-- SEC-1 (partial) -- nine more tables charge the permission their own RPC already charges.
--
-- ================================================================================================
-- THE RULE THIS MIGRATION FOLLOWS, AND WHY IT INVENTS NOTHING
--
-- FIN-3 fixed the money family by charging each table exactly the permission its own RPC charges,
-- read out of the function rather than chosen. That rule needs no business decision: the documented
-- path already says what the operation costs, and direct DML was simply not charging it.
--
-- This migration applies the same rule everywhere it has an unambiguous answer. The classification
-- was produced from the live catalogue, not from names:
--
--   for every table `authenticated` may INSERT, with no capability trigger and no policy WITH CHECK
--   naming a non-VIEW permission, find every `app.*` function that inserts into it and the
--   permission that function authorizes.
--
--   ONE RPC, ONE PERMISSION -> canon has answered; guard it here.
--   TWO RPCs, TWO PERMISSIONS -> guard the UNION, which is exactly what the code already requires.
--   NO RPC, OR AN RPC THAT AUTHORIZES NOTHING -> there is no evidence-based answer. Left to SEC-1.
--
--     approval_requests         CREATE_BOOKING_ITEM        app.request_finance_approval
--     conversation_messages     SEND_MESSAGE               app.send_conversation_message
--     customer_contact_methods  CREATE_CUSTOMER            app.add_customer_contact_method
--     customer_identity_signals CREATE_CUSTOMER            app.create_customer
--     customer_identity_merges  MERGE_CUSTOMER_IDENTITY    app.merge_customer_identity
--     internal_supplier_links   ASSIGN_SUPPLIER            app.link_internal_supplier
--     offline_conversions       MANAGE_MARKETING_CAMPAIGN  app.record_offline_conversion
--     document_links            UPLOAD_DOCUMENT
--                               or MANAGE_TENANT_SETTINGS  app.upload_document /
--                                                          app.upload_subscription_payment_proof
--     lead_assignments          ASSIGN_LEAD
--                               or REASSIGN_LEAD           app.assign_lead / app.reassign_lead
--
-- DELIBERATELY NOT GUARDED HERE, because no RPC names a permission for them and guessing one would
-- be inventing business policy: `attribution_clicks` and `lead_interactions` (their RPCs
-- -- `app.capture_attribution_click`, `app.record_lead_interaction` -- authorize nothing at all),
-- and the eleven tables with no RPC writer whatsoever: `branch_business_hours`, `company_assets`,
-- `financial_accounts`, `holidays`, `notification_deliveries`, `notifications`,
-- `offline_conversion_deliveries`, `otp_challenges`, `totp_enrollments`, `trusted_devices`,
-- `usage_counters`. The last three are the caller's own auth artifacts and are already owner-scoped
-- by policy; the rest are system-written or tenant configuration. All remain under SEC-1.
--
-- ================================================================================================
-- WHY UPDATE IS CHARGED EVERYWHERE EXCEPT `approval_requests`
--
-- Only three of the nine are updated by any `app.*` function at all, so charging UPDATE can affect
-- almost nothing but direct DML -- which is the point:
--
--     customer_contact_methods <- app.add_customer_contact_method  (charges CREATE_CUSTOMER: same)
--     lead_assignments         <- app.reassign_lead                (charges REASSIGN_LEAD: in the union)
--                              <- app.process_lead_sla             (session-less: exempt)
--     approval_requests        <- app.review_finance_approval      (charges APPROVE_FINANCE)
--
-- `approval_requests` is the exception and it matters. `review_finance_approval` is how finance
-- DECIDES a request, and `finance_manager` does not hold `CREATE_BOOKING_ITEM` -- so charging the
-- insert permission on UPDATE would have broken the approval workflow FIN-2 repaired one migration
-- ago. Its UPDATE is already correctly guarded: `approval_requests.scope_update` switches on
-- `approval_type_code` and requires APPROVE_FINANCE / REVIEW_SUBSCRIPTION_PAYMENT /
-- REVIEW_APPROVAL_REQUEST. Checked before writing, not after breaking it.
--
-- A UNION IS NOT A WEAKENING. Where two RPCs write a table under two different permissions, holding
-- either is precisely what the existing code already permits; requiring both would forbid writes
-- ORVION performs today, and picking one would silently retire a working path.
-- ================================================================================================

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

    v_perms := case tg_table_name
                   when 'approval_requests'         then array['CREATE_BOOKING_ITEM']
                   when 'conversation_messages'     then array['SEND_MESSAGE']
                   when 'customer_contact_methods'  then array['CREATE_CUSTOMER']
                   when 'customer_identity_signals' then array['CREATE_CUSTOMER']
                   when 'customer_identity_merges'  then array['MERGE_CUSTOMER_IDENTITY']
                   when 'internal_supplier_links'   then array['ASSIGN_SUPPLIER']
                   when 'offline_conversions'       then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                   when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
               end;

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

revoke execute on function app.guard_write_capability() from public;

create trigger approval_requests_guard_write_capability
    before insert on public.approval_requests
    for each row execute function app.guard_write_capability();

create trigger conversation_messages_guard_write_capability
    before insert or update on public.conversation_messages
    for each row execute function app.guard_write_capability();

create trigger customer_contact_methods_guard_write_capability
    before insert or update on public.customer_contact_methods
    for each row execute function app.guard_write_capability();

create trigger customer_identity_signals_guard_write_capability
    before insert or update on public.customer_identity_signals
    for each row execute function app.guard_write_capability();

create trigger customer_identity_merges_guard_write_capability
    before insert or update on public.customer_identity_merges
    for each row execute function app.guard_write_capability();

create trigger internal_supplier_links_guard_write_capability
    before insert or update on public.internal_supplier_links
    for each row execute function app.guard_write_capability();

create trigger offline_conversions_guard_write_capability
    before insert or update on public.offline_conversions
    for each row execute function app.guard_write_capability();

create trigger document_links_guard_write_capability
    before insert or update on public.document_links
    for each row execute function app.guard_write_capability();

create trigger lead_assignments_guard_write_capability
    before insert or update on public.lead_assignments
    for each row execute function app.guard_write_capability();
