-- API-3 marketing-campaign family. Three defects, all reproduced first, all on the two tables the
-- family writes: `public.offline_conversions` and `public.marketing_campaigns`.
--
-- WHY THESE MATTER MORE THAN THEIR ROW COUNT SUGGESTS. `app.claim_conversion_deliveries` returns
-- `oc.conversion_value` and `oc.currency_code` **verbatim** into the payload n8n hands to the Google
-- Data Manager API. It filters on platform and delivery status and attempt count; it does not
-- inspect the money. So a value that should never have existed is not caught downstream — it is
-- DELIVERED. This is ORVION's only outbound money path.
--
-- ================================================================================================
-- CONV-4 (High) -- a negative conversion value was reachable, and would be sent to Google Ads.
--
-- `app.record_offline_conversion` refuses it: `conversion_value must be non-negative`. That rule
-- lived in the function and nowhere else. `authenticated` holds INSERT on `offline_conversions`,
-- `guard_write_capability` charges MANAGE_MARKETING_CAMPAIGN, and the RLS policy is tenant-only --
-- so a holder of that capability reaches the table directly.
--
-- REPRODUCED as an `owner` (aal2) over the real `authenticated` role, in the same transaction that
-- had just been refused by the RPC: a direct INSERT stored **-5000.0000 EGP**.
--
-- ================================================================================================
-- CONV-5 (High) -- a conversion value with NO currency was reachable, same door.
--
-- The RPC refuses it: `currency_code is required when conversion_value is set`. REPRODUCED the same
-- way: a direct INSERT stored **7777.0000 with currency_code NULL**. An amount with no currency is
-- not a smaller version of the right answer; it is an unusable one, and it reaches an external
-- advertising platform that will interpret it against whatever default it chooses.
--
-- ================================================================================================
-- CAMP-1 (Medium) -- a campaign could be created with NO status, and was then unreachable.
--
-- `marketing_campaigns.status_code` is nullable and `app.enforce_status_transition` is a
-- BEFORE **UPDATE** trigger, so the INSERT path never had to name a state. REPRODUCED: a direct
-- INSERT created a campaign with `status_code` NULL, and `app.advance_marketing_campaign` then
-- reported **"campaign not found in your tenant"** -- a false message about a row that plainly
-- exists. The campaign is permanently unadvanceable, because every transition needs a FROM state.
--
-- ================================================================================================
-- ENFORCEMENT LAYER -- chosen by measuring the write surface, not by copying a sibling.
--
-- All three are **row-level** invariants: each is decidable from the single row being written, with
-- no reference to any other row. That is precisely what a CHECK constraint is for, and a constraint
-- is stronger than a trigger here because it cannot be reached around by any door, any role, or any
-- session-less path -- which matters because LESSON 6 of this programme is that authorization may
-- exempt platform paths and **integrity must not**.
--
-- EVERY LEGAL WRITER WAS PROVEN COMPATIBLE BEFORE THE CONSTRAINT WAS WRITTEN, not after:
--   * `app.record_offline_conversion` already enforces both money rules itself.
--   * `app.map_outcomes_to_conversions` -- the session-less pg_cron writer -- derives its value from
--     `payments.amount` and its currency from `payments.currency_code`. `payments` carries
--     `payments_amount_nonneg_check (amount >= 0)` and `currency_code` is NOT NULL, so that writer
--     **structurally cannot** violate either constraint. Verified by reading both the function and
--     the payments constraints, because WP-03 shipped two cross-tenant aborts by not doing this.
--   * `app.create_marketing_campaign` is the ONLY function that inserts a campaign, and it always
--     writes 'draft' -- canon 26's initial state for this machine.
--   * Existing rows were counted first: 0 negative, 0 valueless-currency, 0 null-status.
--
-- DELIBERATELY NOT DONE: nothing here constrains WHICH state an INSERT may name. A direct INSERT
-- naming 'ended' is not addressed, because it was not reproduced as a defect and because the same
-- question applies to every status-bearing table in ORVION -- it is a programme-wide question, not
-- a marketing-campaign one, and inventing a rule for one table would create the inconsistency the
-- next audit would file. Recorded as CAMP-2, UNPROVEN.

alter table public.offline_conversions
    add constraint offline_conversions_value_nonneg_check
    check (conversion_value is null or conversion_value >= 0);

comment on constraint offline_conversions_value_nonneg_check on public.offline_conversions is
    'CONV-4: app.record_offline_conversion refuses a negative value and nothing else did. app.claim_conversion_deliveries hands conversion_value straight to the Google Ads payload without inspecting it, so a negative value reached by direct DML would be DELIVERED, not caught.';

alter table public.offline_conversions
    add constraint offline_conversions_value_currency_check
    check (conversion_value is null or currency_code is not null);

comment on constraint offline_conversions_value_currency_check on public.offline_conversions is
    'CONV-5: an amount with no currency is unusable, not merely imprecise, and it leaves ORVION for an external advertising platform. The RPC required the pair; the table did not.';

alter table public.marketing_campaigns
    alter column status_code set not null;

comment on column public.marketing_campaigns.status_code is
    'CAMP-1: NOT NULL since 202607058200. app.enforce_status_transition is BEFORE UPDATE, so the INSERT path never had to name a state; a NULL left the campaign permanently unadvanceable while app.advance_marketing_campaign reported "campaign not found in your tenant" about a row that exists. app.create_marketing_campaign writes canon 26 initial state "draft".';
