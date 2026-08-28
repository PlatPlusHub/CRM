-- SEC-1 residue -- the thirteen tables, classified from evidence and closed where evidence answers.
--
-- ================================================================================================
-- WHAT THE RESIDUE ACTUALLY WAS
--
-- `202607056000` guarded every table where an `app.*` RPC already named the permission its own write
-- costs. Thirteen tables had no such RPC. Counting them was not an answer, so each was investigated
-- individually: who writes it, who reads it, whether any legitimate path depends on the
-- `authenticated` grant at all, and whether canon already decides the question elsewhere.
--
-- Three distinct answers came back, and they need three different actions -- which is why treating
-- the thirteen as one number was itself the mistake.
--
--
-- 1. SYSTEM-OWNED: THE GRANT HAS NO WRITER (five tables) -> REVOKE THE GRANT
--
-- For `attribution_clicks`, `notifications`, `notification_deliveries`,
-- `offline_conversion_deliveries` and `usage_counters`, every writer in the database is SECURITY
-- DEFINER and none of them is executable by `authenticated`:
--
--     attribution_clicks             <- app.capture_attribution_click        (definer; orvion_integration)
--     notifications                  <- app.process_lead_sla                 (definer; service_role)
--     offline_conversion_deliveries  <- app.claim_conversion_deliveries      (definer; orvion_integration)
--                                    <- app.record_conversion_delivery_result(definer; orvion_integration)
--     notification_deliveries        <- nothing at all
--     usage_counters                 <- nothing at all
--
-- A SECURITY DEFINER function runs as its owner, so the `authenticated` table grant is not what
-- makes those paths work -- it is a SECOND door that only direct DML uses. Removing it therefore
-- cannot break a legitimate write; it can only remove forged marketing clicks, forged notifications,
-- forged delivery records and hand-edited usage meters. That is the directive's own preference:
-- REMOVE AN UNNECESSARY WRITE RATHER THAN INVENT A BUSINESS PERMISSION FOR IT.
--
-- Two independent pieces of evidence agree that ORVION already considered these system-owned:
-- `notification_deliveries`, `usage_counters` and `offline_conversion_deliveries` are on the
-- subscription-write-gate exemption list (`35_subscription_write_gate_test.sql` §19-20), and canon
-- 28 states plainly that "`usage_counters` is empty and counting is a separate additive mechanism".
--
-- `notifications` KEEPS a column-level UPDATE on `is_read, read_at`. Reading and dismissing your own
-- notification is a real user act with no RPC to perform it, and removing the whole UPDATE would
-- have deleted a capability instead of a hole. The owner-scoped policy already pins
-- `target_user_id = current_user_id()`, so this cannot reach a colleague's inbox; what it can no
-- longer do is rewrite the title, body or subject of a notification the system sent.
--
--
-- 2. TENANT CONFIGURATION: CANON CHARGES A PERMISSION FOR THE SAME OBJECT (four tables) -> GUARD IT
--
-- These have no writer at all, so direct DML is currently the ONLY path -- and it was open to every
-- tenant user, a trainee included. The permission is not invented here; it is read out of what
-- ORVION already charges for the same object:
--
--     branch_business_hours  MANAGE_BRANCHES        `branches`, its parent, charges exactly this
--                                                   (scope_insert / scope_update). Setting a
--                                                   branch's opening hours IS configuring the branch.
--     holidays               MANAGE_BRANCHES or     `branch_id` is nullable: a holiday is either a
--                            MANAGE_TENANT_SETTINGS branch calendar entry or a tenant-wide one.
--                                                   Both permissions resolve to exactly {ceo, owner},
--                                                   so the union honours both readings and widens
--                                                   nothing.
--     financial_accounts     CREATE_JOURNAL_ENTRY   canon 33 migration 6 groups it with
--                                                   `exchange_rates` and `chart_of_accounts`;
--                                                   `chart_of_accounts` -- the account structure a
--                                                   bank account belongs to -- charges this, and
--                                                   `journal_entries` charges it too.
--     company_assets         CREATE_JOURNAL_ENTRY   canon 33 migration 12 groups it with the finance
--                                                   transaction tables, and it carries
--                                                   purchase_amount / currency_code. Finance master
--                                                   data in ORVION costs a finance permission.
--
-- Every one of these narrows an ungoverned write down to roles canon 28 already designates, and none
-- of them grants anybody anything they did not have. `CREATE_JOURNAL_ENTRY` is held by ceo,
-- finance_manager and owner; `MANAGE_BRANCHES` and `MANAGE_TENANT_SETTINGS` by ceo and owner.
--
--
-- 3. NOT CLOSED HERE, AND WHY (four tables)
--
--     otp_challenges, totp_enrollments, trusted_devices -- INTENTIONAL, not residue. Canon 34 §
--     "Applying Principles 1, 6, and 7" states it directly: these belong to the Human Identity, are
--     keyed by `auth_user_id`, and "RLS for these tables is simply row-ownership by `auth.uid()`,
--     with no tenant scoping". Ownership IS the capability, canon says so, and inventing a CRUD
--     permission to make a metric reach zero would contradict it. `56_...`/`58_...` prove the
--     boundary holds rather than asserting it in a comment.
--
--     lead_interactions -- BLOCKED, BUSINESS DECISION. `app.record_lead_interaction` is SECURITY
--     INVOKER, granted to `authenticated`, and authorizes nothing. So unlike every table
--     `202607056000` fixed, there is no bypass here: the RPC and direct DML charge exactly the same
--     thing, which is nothing. Canon defines no permission for logging an interaction (the lead
--     permissions are CREATE / ASSIGN / REASSIGN / CLOSE / VIEW_ASSIGNED). The open question is
--     whether logging should cost anything at all -- and that is a business decision, not a defect
--     to patch by picking a permission that reads plausibly.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- 1. The grants now match the writers.
-- ------------------------------------------------------------------------------------------------
revoke insert, update on public.attribution_clicks            from authenticated;
revoke insert, update on public.notification_deliveries       from authenticated;
revoke insert, update on public.offline_conversion_deliveries from authenticated;
revoke insert, update on public.usage_counters                from authenticated;
revoke insert, update on public.notifications                 from authenticated;

-- ...except the one user act on an inbox that has no RPC to perform it.
grant update (is_read, read_at) on public.notifications to authenticated;

-- ------------------------------------------------------------------------------------------------
-- 2. Four configuration tables charge what ORVION already charges for the same object.
-- ------------------------------------------------------------------------------------------------
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
                   -- this migration: no RPC writes these at all, so the permission comes from what
                   -- ORVION charges for the parent object or for the same class of master data.
                   when 'branch_business_hours'     then array['MANAGE_BRANCHES']
                   when 'holidays'                  then array['MANAGE_BRANCHES','MANAGE_TENANT_SETTINGS']
                   when 'financial_accounts'        then array['CREATE_JOURNAL_ENTRY']
                   when 'company_assets'            then array['CREATE_JOURNAL_ENTRY']
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

-- INSERT OR UPDATE with no exception: unlike `approval_requests`, no `app.*` function updates any of
-- these four under a different permission, so there is no working path to preserve.
create trigger branch_business_hours_guard_write_capability
    before insert or update on public.branch_business_hours
    for each row execute function app.guard_write_capability();

create trigger holidays_guard_write_capability
    before insert or update on public.holidays
    for each row execute function app.guard_write_capability();

create trigger financial_accounts_guard_write_capability
    before insert or update on public.financial_accounts
    for each row execute function app.guard_write_capability();

create trigger company_assets_guard_write_capability
    before insert or update on public.company_assets
    for each row execute function app.guard_write_capability();
