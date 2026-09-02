-- SUP-3 -- supplier credit management becomes its own permission (OWNER DECISION, 2026-09-02).
--
-- THE OWNER DECISION, recorded in `MASTER_GAP_REGISTER.md` (SUP-3), is two rules:
--   1. `finance_manager` MUST be able to modify `suppliers.credit_limit_amount` -- the finance
--      manager holds full authority for the Accounting/Finance function.
--   2. Supplier credit-limit management MUST have its OWN independent permission, not an incidental
--      consequence of ASSIGN_SUPPLIER.
-- The wider directive it belongs to: ORVION's authorization model is fine-grained by design, so that
-- every capability is independently grantable and revocable per user from the future admin
-- dashboard. This migration is that model applied to one capability, not a new framework.
--
-- WHAT SUP-2 (`202607059600`) LEFT, AND WHY THIS IS NOT A REVERSAL. SUP-2 proved the ceiling's WRITE
-- cost less than its READ, so the three roles holding ASSIGN_SUPPLIER without VIEW_FINANCIAL_DOCUMENTS
-- could set a figure they were refused. It closed that by charging the read permission on the write.
-- That was the correct FLOOR available at the time -- canon named no credit permission -- and it is
-- now replaced by the RIGHT permission, which the owner has since supplied. The hole SUP-2 closed
-- stays closed: those three roles still cannot set the ceiling, because they hold neither
-- VIEW_FINANCIAL_DOCUMENTS nor MANAGE_SUPPLIER_CREDIT.
--
-- NAMING AND MECHANISM ARE THE REPOSITORY'S OWN, NOT INVENTED. `permission_key` is a System Catalog
-- in canon 25 whose list is headed "Initial values", and `202607051400` already minted
-- VIEW_DEPARTMENT_RECORDS into it -- an `insert ... on conflict (key) do nothing` carrying a
-- description with `is_system = true`. That is the established way to add a permission here and it is
-- followed exactly. `MANAGE_<noun>` matches MANAGE_BRANCHES / MANAGE_DEPARTMENTS /
-- MANAGE_SUBSCRIPTION / MANAGE_MARKETING_CAMPAIGN. No second permission framework is introduced.
--
-- THE FEATURE CODE IS DERIVED, NOT PICKED. `required_feature_code` is a PLAN entitlement.
-- VIEW_FINANCIAL_DOCUMENTS -- the permission governing KNOWING this same figure -- is `finance_lite`,
-- so the write is entitled at the same tier. Putting it on `suppliers` (where ASSIGN_SUPPLIER sits)
-- would let a plan grant the write without entitling the read: SUP-2's shape reintroduced one level
-- up, at the plan rather than the role.
--
-- ROLES. `finance_manager` by the owner's rule. `owner` and `ceo` because they can set the ceiling
-- TODAY (they are the ASSIGN_SUPPLIER holders who also hold VIEW_FINANCIAL_DOCUMENTS) and the owner
-- directed that no existing legitimate authority be silently removed. branch_manager,
-- department_manager and senior_employee are NOT granted: SUP-2 removed that ability as a defect,
-- the owner was told so, and this decision adds finance_manager without restoring them. Granting
-- them would reopen SUP-2, and would be guessing commercial authority, which the directive forbids.
-- This is the same role set canon 28 already gives EDIT_LOCKED_COST, the nearest restricted
-- financial authority ORVION has.
--
-- ORTHOGONALITY, which is the part with teeth. `finance_manager` holds NO ASSIGN_SUPPLIER, and
-- `suppliers_guard_write_capability` charges ASSIGN_SUPPLIER for ANY write to the table -- so minting
-- the permission alone would have changed nothing and rule 1 would have silently failed. The table
-- guard must therefore learn that a write touching ONLY the ceiling is a different act:
--   * credit column only     -> MANAGE_SUPPLIER_CREDIT  (ASSIGN_SUPPLIER neither required nor sufficient)
--   * any other column       -> ASSIGN_SUPPLIER         (MANAGE_SUPPLIER_CREDIT grants nothing)
--   * both in one statement  -> BOTH, because both acts happen
--   * INSERT with a ceiling  -> BOTH: creating a supplier is ASSIGN_SUPPLIER, giving it credit terms is not
-- Neither permission implies the other in either direction, which is the owner's stated requirement.
--
-- VISIBILITY IS UNTOUCHED. The column grant and `app.supplier_credit` are not modified: an actor
-- holding MANAGE_SUPPLIER_CREDIT and not VIEW_FINANCIAL_DOCUMENTS may SET the ceiling and still
-- cannot READ it, nor any other financial field. Write authority does not become visibility.
--
-- ENFORCEMENT OF THE CEILING (exposure <= limit) IS NOT IN THIS MIGRATION and is deliberately not
-- attempted. ORVION has an authoritative supplier PAYABLE (`app.supplier_balance`) but no
-- authoritative definition of what counts against the LIMIT -- the limit is a currency-less scalar
-- while the payable is per-currency, and canon states no rule. Evidence and the smallest owner
-- decision required are recorded as **SUP-4** in `MASTER_GAP_REGISTER.md`. Inventing a definition
-- here would be exactly the invention this audit's non-goals forbid.

-- 1. The permission. `on conflict do nothing` per the VIEW_DEPARTMENT_RECORDS precedent, so a
--    re-applied migration and a `db reset` are both idempotent.
insert into public.permissions (key, name, description, required_feature_code, is_system, is_active)
values ('MANAGE_SUPPLIER_CREDIT',
        'Manage supplier credit',
        'Set or change a supplier''s credit limit (suppliers.credit_limit_amount). Independent of '
        'ASSIGN_SUPPLIER, which governs supplier records themselves, and of VIEW_FINANCIAL_DOCUMENTS, '
        'which governs reading the figure. Owner decision SUP-3, 2026-09-02.',
        'finance_lite', true, true)
on conflict (key) do nothing;

-- 2. The role grants.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where p.key = 'MANAGE_SUPPLIER_CREDIT'
  and r.code in ('owner', 'ceo', 'finance_manager')
on conflict do nothing;

-- 3. The table guard learns that a credit-only write is a different act. Replaced in full from the
--    live definition so nothing from SEC-1b / SEC-1c / LIC-3 / PP-4 is lost; the added region carries
--    its own SUP-3 comment.
create or replace function app.guard_write_capability()
returns trigger
language plpgsql
set search_path = ''
as $FN$
declare
    v_perms  text[];
    v_extra  text[];
    v_perm   text;
    v_held   text;
    -- Set ONLY inside the `documents` branch below. It exists because the UPDATE widening must not
    -- apply to payment proofs (PP-4), and the obvious way to write that -- naming
    -- `new.document_type_code` in the widening condition -- is the very trap the comment above
    -- describes: PL/pgSQL resolves a record field against the ACTUAL record type at execution, so
    -- that expression raises `record "new" has no field "document_type_code"` on `suppliers`,
    -- `customers` and every other table this trigger serves. It was written that way in this
    -- migration's first draft and the reproducer caught it immediately. A boolean carries the fact
    -- out of the branch where the field genuinely exists.
    v_strict boolean := false;
    -- `leads` carries an authority that is a RELATIONSHIP rather than a permission, and it is
    -- ORVION's own, copied verbatim rather than invented. `app.record_lead_interaction` reads:
    --     if not (v_actor = v_assigned) and not app.has_permission('ASSIGN_LEAD') then raise 42501
    -- i.e. THE ASSIGNED HANDLER, OR ASSIGN_LEAD. A trainee assigned a lead may log a call on it and
    -- holds none of CREATE_LEAD / ASSIGN_LEAD / CLOSE_LEAD / REASSIGN_LEAD -- so a permission-only
    -- UPDATE rule silently removed the handler rule. Caught by `verify_lifecycle_branches.ps1`
    -- ("a trainee CAN log an interaction on the lead they are ASSIGNED"), which is the assertion
    -- this migration's first draft broke: pgTAP was entirely green, and only the HTTP layer failed.
    -- That is the standing argument for running both doors, not a formality.
    -- Note this does NOT reopen SEC-1c: the reproduced trainee was assigned nothing, so the escape
    -- does not apply to them. It admits exactly the actor the RPC already admits, and no other.
    v_relationship_ok boolean := false;
    -- 202607059700 (SUP-3). Set ONLY inside the `suppliers` branch below, for the same reason
    -- `v_strict` and `v_relationship_ok` exist: naming `new.credit_limit_amount` anywhere this
    -- trigger also evaluates for `customers` or `leads` raises `record "new" has no field ...` on
    -- every one of them, whether or not the branch is taken.
    v_credit_only boolean := false;
begin
    -- Platform/system paths (canon 35 principle 6), as in every other guard here.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- 202607058500 (LIC-3 / PP-4): `documents` is resolved in its OWN statement, not inside the
    -- shared CASE below. A record field reference is resolved against the ACTUAL record type at
    -- execution, so naming `new.document_type_code` inside an expression this trigger also evaluates
    -- for `customers`, `leads` and twenty other tables fails on every one of them -- a CASE branch
    -- being untaken does not make the field reference disappear.
    if tg_table_name = 'documents' then
        if new.document_type_code = 'payment_proof' then
            -- Strict on both paths (PP-4): a billing artefact, not a use of the documents module.
            v_perms := array['MANAGE_TENANT_SETTINGS'];
            v_strict := true;
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

    -- 202607059100 (SEC-1c): on UPDATE, the object-class permission is joined by the permissions
    -- that canon already says may MUTATE this object -- its `app.status_transitions.permission_key`
    -- values, plus the permission any non-transition mutating RPC charges. Creating and changing are
    -- different authorities in canon 28 (CREATE_LEAD vs CLOSE_LEAD, UPLOAD_DOCUMENT vs
    -- ARCHIVE_DOCUMENT), and a rule that recognised only the first would strip authority the
    -- permission matrix grants. `payment_proof` is excluded from widening on purpose (PP-4).
    if tg_op = 'UPDATE' and not v_strict then
        v_extra := case tg_table_name
                       when 'approval_requests'  then array['APPROVE_FINANCE','REVIEW_APPROVAL_REQUEST','REVIEW_SUBSCRIPTION_PAYMENT']
                       when 'bookings'           then array['APPROVE_BOOKING','CANCEL_BOOKING','ISSUE_BOOKING','REFUND_BOOKING','REISSUE_BOOKING']
                       when 'complaints'         then array['RESOLVE_COMPLAINT']
                       when 'conversations'      then array['CLOSE_CONVERSATION','ESCALATE_CONVERSATION']
                       when 'customers'          then array['MERGE_CUSTOMER_IDENTITY']
                       when 'documents'          then array['ARCHIVE_DOCUMENT','CREATE_DOCUMENT_VERSION']
                       when 'leads'              then array['ASSIGN_LEAD','CLOSE_LEAD','REASSIGN_LEAD']
                       when 'quotations'         then array['ACCEPT_QUOTATION','SEND_QUOTATION']
                       when 'service_requests'   then array['RESOLVE_SERVICE_REQUEST']
                       when 'tasks'              then array['ASSIGN_TASK','COMPLETE_TASK']
                       else null
                   end;
        if v_extra is not null then
            v_perms := v_perms || v_extra;
        end if;
    end if;

    -- SUP-3 (owner decision, 2026-09-02): supplier CREDIT management is its own authority, so an
    -- UPDATE that changes the ceiling AND NOTHING ELSE is charged MANAGE_SUPPLIER_CREDIT instead of
    -- ASSIGN_SUPPLIER. The two permissions are orthogonal by owner directive: ASSIGN_SUPPLIER must
    -- not imply credit management, and credit management must not imply supplier administration --
    -- which is why this REPLACES the permission rather than being added to it. A row image
    -- comparison is used rather than a column list because it cannot fall out of date when a column
    -- is added to `suppliers`: a new column changes the image, so the write stops being credit-only
    -- and falls back to ASSIGN_SUPPLIER, which is the safe direction to be wrong in.
    -- `updated_at` is excluded because `suppliers_set_updated_at` (moddatetime) fires AFTER this
    -- trigger alphabetically, so a caller that sets it by hand must not thereby turn a credit-only
    -- write into a general one.
    if tg_op = 'UPDATE' and tg_table_name = 'suppliers' then
        v_credit_only := new.credit_limit_amount is distinct from old.credit_limit_amount
                         and (to_jsonb(new) - 'credit_limit_amount' - 'updated_at')
                           = (to_jsonb(old) - 'credit_limit_amount' - 'updated_at');
        if v_credit_only then
            v_perms := array['MANAGE_SUPPLIER_CREDIT'];
        end if;
    end if;

    -- The handler rule, evaluated ONLY inside its own table branch so `new.assigned_user_id` is
    -- never named while this trigger is serving `suppliers` or `customers`.
    if tg_op = 'UPDATE' and tg_table_name = 'leads' then
        v_relationship_ok := (select app.current_user_id()) is not null
                             and (select app.current_user_id()) in (new.assigned_user_id, new.owner_user_id);
    end if;

    if v_relationship_ok then
        return new;
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
$FN$;

revoke all on function app.guard_write_capability() from public;

-- 4. The column guard now charges the dedicated permission instead of the interim read permission.
--    Everything else is unchanged from `202607059600`: the session-less exemption, the not-in-play
--    short-circuits, and `is not distinct from` so CLEARING a ceiling still counts as setting it.
create or replace function app.guard_supplier_credit_authority()
returns trigger
language plpgsql
set search_path = ''
as $FN$
begin
    -- Platform/system paths (canon 35 principle 6), identical to every sibling guard.
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' and new.credit_limit_amount is null then
        return new;
    end if;

    if tg_op = 'UPDATE'
       and new.credit_limit_amount is not distinct from old.credit_limit_amount then
        return new;
    end if;

    -- SUP-3: the dedicated permission. `authorize` rather than `has_permission`, because it also
    -- composes the MFA step-up and every role granted this permission is in `app.requires_mfa`'s set.
    perform app.authorize('MANAGE_SUPPLIER_CREDIT');

    return new;
end;
$FN$;

revoke all on function app.guard_supplier_credit_authority() from public;

comment on function app.guard_supplier_credit_authority() is
'SUP-3: writing suppliers.credit_limit_amount costs MANAGE_SUPPLIER_CREDIT, its own independently '
'grantable permission (owner decision 2026-09-02). Orthogonal to ASSIGN_SUPPLIER (supplier records) '
'and to VIEW_FINANCIAL_DOCUMENTS (reading the figure); neither implies this one and this one implies '
'neither. Supersedes SUP-2''s interim floor without reopening the hole SUP-2 closed.';
