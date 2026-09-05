-- =====================================================================================================
-- BATCH 6 SLICE 1 -- the two surfaces no pgTAP file had ever named.
--
-- Chosen by MEASUREMENT, not by list: 75 of 77 tables are named in at least one test file;
-- `campaign_daily_metrics` and `exchange_rate_adjustments` were named in none. Being named in a test
-- is a floor rather than coverage, but a table no test mentions at all is definitively unswept, and
-- these two were the only surfaces that could be asserted un-audited before the disposition record
-- existed. Full evidence: reports/history/session-2026-09-05-batch6-evidence-foundation.md.
--
-- WHAT THE AUDIT FOUND, and what it deliberately did NOT change.
--
-- NOT a defect, proven rather than assumed: both tables are authorized entirely by RLS, and that is
-- correct here. Neither has ANY consumer -- zero functions and zero views reference either table
-- (measured against pg_proc.prosrc and information_schema.view_column_usage) -- so there is no RPC
-- door for direct DML to bypass. The table door IS the door, which is SEC-2's ratified reading, and
-- both tables already carry a permission in the write half of their policies:
--   campaign_daily_metrics  USING VIEW_MARKETING_DASHBOARD / WITH CHECK MANAGE_MARKETING_CAMPAIGN
--   exchange_rate_adjustments  per-command policies charging CREATE_EXCHANGE_RATE_ADJUSTMENT
-- All three permissions are held by real roles (ceo/owner; finance_manager for the third), so
-- neither surface is an unreachable capability. Nothing here widens or narrows authorization.
--
-- CDM-1 (Medium) -- A DAILY METRIC HAD NO NATURAL KEY.
-- Canon 31 defines this table as "daily marketing performance values" and states that "metrics may be
-- imported from integrations". An import is retried; the table had PRIMARY KEY (id) and nothing else,
-- so re-running an import inserted a SECOND row for the same campaign and the same day, and every
-- SUM over spend, clicks or revenue then double-counts silently. This is DC-2's idempotency class on
-- the one table whose own name says how many rows a day may have. The unique index is the whole fix:
-- it makes the natural key the natural key, and turns a retried import into a refusal an importer can
-- see (23505) instead of a duplicate nobody notices.
--
-- CDM-2 (Low) -- COUNTS AND MONEY COULD BE NEGATIVE.
-- No CHECK constrained any measure. Negative impressions, clicks, leads or bookings are not a policy
-- question, they are arithmetic; negative spend and revenue follow CUST-4's ratified precedent, which
-- added exactly this constraint to a money column for exactly this reason. NULL stays legal on every
-- one of them -- canon marks all six nullable, a CHECK is not evaluated against NULL, and inventing a
-- NOT NULL here would be inventing a rule canon does not state.
--
-- ERA-1 (Medium) -- A POST-LOCK RATE CORRECTION COULD BE SILENTLY REWRITTEN.
-- Canon 31 lists this table's fields as id, tenant_id, booking_item_id, original_exchange_rate_id,
-- new_exchange_rate_id, reason_code, reason_text, created_by, created_at -- and NO `updated_at`,
-- while canon lists one for every table it means to be updated (campaign_daily_metrics above has
-- one). Canon therefore already says this record is written once. Nothing enforced it: `authenticated`
-- held UPDATE, `scope_update` granted it to anyone with CREATE_EXCHANGE_RATE_ADJUSTMENT, and the row
-- says which rate WAS locked and which replaced it -- so a finance_manager could rewrite what the
-- original rate had been, after the fact, leaving no trace at all (no updated_at, no event).
--
-- THE MECHANISM WAS CHOSEN, NOT DEFAULTED. `app.forbid_acquisition_lineage_rewrite(cols...)` already
-- exists and freezes named columns on UPDATE -- it was considered first and rejected twice over: its
-- semantics are FIRST-TOUCH (NULL -> value is allowed once), which is wrong for columns that are NOT
-- NULL from birth, and canon withholds `updated_at` from the WHOLE row rather than from three
-- columns. `app.forbid_mutation()` is ORVION's ratified full-immutability trigger and says exactly
-- what canon says. It is applied here with the same THREE layers that make `events` and
-- `security_events` append-only, because any one of them alone is a half-fix: the trigger (closes
-- every path including service_role), the revoked grant (closes the PostgREST door before a row is
-- ever reached), and the removal of the two policies that promised an UPDATE and a DELETE the table
-- no longer performs. `scope_delete` was already unreachable -- `authenticated` has held no DELETE on
-- any table since B5 -- so dropping it removes a standing contradiction rather than a capability.
--
-- Safe to apply: both tables hold ZERO rows on local and Primary holds zero business rows, so no
-- existing data can violate the new index or the new CHECKs.
-- =====================================================================================================

-- -----------------------------------------------------------------------------------------------
-- CDM-1: one row per campaign per day.
-- -----------------------------------------------------------------------------------------------
create unique index if not exists campaign_daily_metrics_campaign_day_key
    on public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date);

comment on index public.campaign_daily_metrics_campaign_day_key is
    'CDM-1. The natural key of a daily metric. Canon 31 says metrics may be imported from '
    'integrations, and an import is retried; without this a retry inserted a duplicate campaign-day '
    'and every SUM double-counted. tenant_id leads because the FK to marketing_campaigns is '
    'tenant-composite and every read is tenant-scoped.';

-- -----------------------------------------------------------------------------------------------
-- CDM-2: a measure may be unknown (NULL), never negative.
-- -----------------------------------------------------------------------------------------------
alter table public.campaign_daily_metrics
    add constraint campaign_daily_metrics_spend_non_negative     check (spend_amount    >= 0),
    add constraint campaign_daily_metrics_revenue_non_negative   check (revenue_amount  >= 0),
    add constraint campaign_daily_metrics_impressions_non_negative check (impressions   >= 0),
    add constraint campaign_daily_metrics_clicks_non_negative    check (clicks          >= 0),
    add constraint campaign_daily_metrics_leads_non_negative     check (leads_count     >= 0),
    add constraint campaign_daily_metrics_bookings_non_negative  check (bookings_count  >= 0);

-- -----------------------------------------------------------------------------------------------
-- ERA-1: a post-lock rate correction is written once. All three layers, as `events` has them.
-- -----------------------------------------------------------------------------------------------
drop policy if exists scope_update on public.exchange_rate_adjustments;
drop policy if exists scope_delete on public.exchange_rate_adjustments;

revoke update on public.exchange_rate_adjustments from authenticated;

drop trigger if exists exchange_rate_adjustments_append_only on public.exchange_rate_adjustments;
create trigger exchange_rate_adjustments_append_only
    before update or delete on public.exchange_rate_adjustments
    for each row execute function app.forbid_mutation();

comment on trigger exchange_rate_adjustments_append_only on public.exchange_rate_adjustments is
    'ERA-1. Canon 31 gives this table no `updated_at` while giving one to every table it means to be '
    'updated, so the record is written once. Correcting a correction is a new row. Deliberately '
    'app.forbid_mutation (whole row) rather than app.forbid_acquisition_lineage_rewrite (named '
    'columns, first-touch semantics) -- the latter allows NULL -> value once, which is meaningless '
    'for columns that are NOT NULL from birth.';
