-- ATTR-3 -- acquisition lineage is first-touch, and nothing in the database said so.
--
-- ================================================================================================
-- THE RULE, QUOTED RATHER THAN INFERRED
--
-- Owner business intent, ATTRIBUTION BUSINESS RULE:
--     "Lead ownership and acquisition attribution are different concepts.
--      Reassignment must never rewrite the original acquisition lineage.
--      Preserve: original source, GCLID, FBCLID, UTM lineage, attribution_click_id,
--      first-touch attribution, acquisition campaign/source.
--      Changing the employee responsible for a lead must not change where the customer
--      originally came from."
--
-- ORVION's own code ALREADY states the same rule, in `app.capture_attribution_click`:
--
--     -- First-touch anchor: attach to the lead only if it has none yet.
--     update public.leads set attribution_click_id = v_click
--     where id = p_lead_id and attribution_click_id is null;
--
-- So this migration invents nothing. It moves a rule the RPC honours onto the table, where every
-- writer meets it -- the FIN-4 / ATTR-1 shape, applied to the attribution class.
--
-- ================================================================================================
-- WHAT WAS ACTUALLY OPEN (the §8-J question, answered by measurement rather than by reading)
--
-- Neither reassignment path rewrites attribution. `app.reassign_lead` updates assigned_user_id,
-- owner_user_id, owner_branch_id, owner_department_id. `app.process_lead_sla` updates
-- assigned_user_id and owner_user_id. Both were read line by line and both are correct, and
-- `63_sla_escalation_test` / `64_acquisition_lineage_test` now assert it rather than trusting it.
--
-- What was NOT true is the stronger claim the owner rule actually makes. `authenticated` holds
-- UPDATE on public.leads and the `scope_isolation` policy permits updating any lead the caller can
-- see -- which, since canon 28 gives `employee` VIEW_DEPARTMENT_QUEUE, is their whole department's
-- pipeline. Nothing anywhere prevented:
--
--     update public.leads set attribution_click_id = <someone else's click> where id = ...;
--     update public.leads set lead_source_code = 'referral' where id = ...;
--
-- Re-pointing a lead at a different click moves a future Google Ads conversion, and the revenue
-- credited with it, from one campaign to another. That is the exact failure the owner rule names,
-- reachable by any employee, and the RPC's first-touch check could not see it because direct DML
-- never passes through the RPC.
--
-- ================================================================================================
-- SCOPE, AND WHY THERE IS NO SYSTEM-PATH EXEMPTION
--
-- Every guard ORVION has written for a derived column carries a session-less exemption, because a
-- definer function acting for the platform must still be able to write. This one does not need one,
-- and deliberately does not have one:
--
--   * `capture_attribution_click` only ever performs the NULL -> value transition, which this guard
--     permits. It is the only writer of `leads.attribution_click_id` after INSERT in the entire
--     database (verified against every function body and every trigger).
--   * NOTHING in the database updates `lead_source_code` or `source_payload` after INSERT at all.
--
-- An exemption would therefore buy nothing and would open the one door the rule exists to close.
--
-- THE SIBLING, found by asking what sits immediately beside the column just fixed.
--
-- `public.offline_conversions` is the REVENUE end of the same chain the owner rule names -- "Ad ->
-- Click identifier -> Visit -> Lead -> Employee -> Quotation -> Booking -> Revenue" -- and it
-- carries `attribution_click_id`, `lead_id` and `marketing_campaign_id` of its own. `authenticated`
-- holds INSERT, SELECT and UPDATE on it; `202607056000` added a capability guard
-- (MANAGE_MARKETING_CAMPAIGN) but nothing made the record itself append-only. So a ceo or owner
-- could re-point an ALREADY RECORDED conversion -- the evidence of what was or will be reported to
-- Google -- at a different click or a different campaign. Narrower blast radius than `leads`,
-- identical defect. Covered here rather than filed, because filing it would have left the class
-- half-closed for the second time in one migration.
--
-- NOT covered here, and each for a stated reason:
--   * `public.attribution_clicks` -- the lineage record itself (gclid, gbraid, wbraid, utm_*,
--     consent, campaign). `202607056100` already revoked INSERT and UPDATE on it from
--     `authenticated`, so no tenant user can rewrite a click. Adding an immutability trigger on top
--     of an absent grant would guard a door that has no handle.
--   * `leads.branch_id` / `department_id`, and `offline_conversions.booking_id` / `payment_id` /
--     `conversion_value` -- organisational placement and commercial outcome, not acquisition
--     lineage. Reassignment across branches is a real operation and canon does not forbid it.
--   * Deleting a click out from under a lead -- already impossible: the FK is ON DELETE RESTRICT.
--
-- ================================================================================================
-- ONE RULE, NOT THREE
--
-- The trigger takes the lineage columns as arguments and applies FIRST-TOUCH to every one of them:
-- a lineage column may be established ONCE, and never changed after that. This is not a
-- generalisation invented for elegance -- it is the rule `capture_attribution_click` already
-- applies to `attribution_click_id`, stated once instead of three times, so the next lineage column
-- is added to an argument list rather than to a chain of near-identical IF branches.
--
-- Comparison is through `to_jsonb`, not through NEW.<column>, for SPEC-159-A's reason: a generic
-- trigger that names fields directly binds every one of them for every table it is attached to.
-- ================================================================================================

create or replace function app.forbid_acquisition_lineage_rewrite()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_new jsonb := to_jsonb(new);
    v_old jsonb := to_jsonb(old);
    v_col text;
begin
    foreach v_col in array tg_argv loop
        -- First touch: NULL -> value is the acquisition being recorded, and is allowed exactly once.
        -- Anything else -- value -> other value, or value -> NULL -- rewrites history.
        if v_old ->> v_col is not null
           and v_new ->> v_col is distinct from v_old ->> v_col then
            raise exception
                '%.% is acquisition lineage and is first-touch: it may not be changed once set (row %, "%" -> "%")',
                tg_table_name, v_col, v_old ->> 'id', v_old ->> v_col, v_new ->> v_col
                using errcode = '42501';
        end if;
    end loop;
    return new;
end
$fn$;

comment on function app.forbid_acquisition_lineage_rewrite() is
    'Acquisition lineage is first-touch: each column named in TG_ARGV may be established once and '
    'never changed. Ownership moves freely; where the customer came from does not. No session-less '
    'exemption -- the only post-insert writer of leads.attribution_click_id is '
    'app.capture_attribution_click, which performs only the NULL -> value transition this permits, '
    'and nothing in the database updates the other lineage columns at all.';

-- POL-1 / GRANT-1's class: PostgreSQL's default for a new function is EXECUTE to PUBLIC, so an
-- omitted revoke is a grant rather than a no-op. `10_grant_model_test` §5 caught this one.
revoke execute on function app.forbid_acquisition_lineage_rewrite() from public;

drop trigger if exists leads_forbid_acquisition_lineage_rewrite on public.leads;
create trigger leads_forbid_acquisition_lineage_rewrite
    before update on public.leads
    for each row
    execute function app.forbid_acquisition_lineage_rewrite(
        'attribution_click_id', 'lead_source_code', 'source_payload');

drop trigger if exists offline_conversions_forbid_acquisition_lineage_rewrite on public.offline_conversions;
create trigger offline_conversions_forbid_acquisition_lineage_rewrite
    before update on public.offline_conversions
    for each row
    execute function app.forbid_acquisition_lineage_rewrite(
        'attribution_click_id', 'lead_id', 'marketing_campaign_id');
