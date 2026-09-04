-- pgTAP: TRANS-1 -- the transition rules are duplicated, so they must be compared. In BOTH
-- directions, and for EVERY entity.
--
-- ORVION states every status transition twice:
--
--   1. an inline VALUES list inside each `app.advance_*` function
--   2. `app.status_transitions` -- (table, status column, from, to, permission), read by
--      `app.enforce_status_transition`, the BEFORE UPDATE trigger on every status-bearing table
--
-- The trigger is the real boundary: it fires on the RPC path AND on direct DML. The function's copy
-- is therefore a duplicate of an authoritative rule, and duplicates drift.
--
-- THIS FILE EXISTS BECAUSE THAT DRIFT ALREADY HAPPENED, in the migration that fixed TASK-1. The
-- employee could not start their own task because `open -> in_progress` demanded ASSIGN_TASK, a
-- managers-only permission. The fix changed the function -- and the employee was still refused,
-- because the trigger reads the table. Two sources, one edited, and the bug survived the fix.
--
-- ================================================================================================
-- WHY THIS FILE WAS REWRITTEN (2026-08-28)
--
-- Its first version parsed only 4-tuples of the exact shape ('from','to','event','PERMISSION'). That
-- shape is `advance_booking`'s. It is NOT `advance_quotation`'s, which puts the permission third and
-- the event fourth; nor `advance_refund`'s, which carries three elements and a single constant
-- permission; nor `advance_lead`'s, whose fourth element is a boolean. So the parity check silently
-- covered ONE function out of ten, and its positive control -- "at least 8 rules parsed" -- was
-- satisfied by that one function alone.
--
-- A guard that checks a tenth of what it claims to check is worse than no guard, because the next
-- engineer trusts it. The parser now reads the VALUES BLOCK of every advance_* function (delimited,
-- so an `in ('cancelled','void')` list elsewhere in the body cannot be mistaken for a transition --
-- it was), and assertion 1 fails if any of the ten stops being parsed.
--
-- The reverse direction is new too. A transition the TABLE permits but no function offers is not
-- automatically a defect -- three lead transitions are deliberately performed by other RPCs -- but
-- it must be NAMED, because that is exactly where TRANS-2 was hiding: eight lead rows the table
-- permitted with no permission at all.
-- ================================================================================================
create extension if not exists pgtap with schema extensions;

begin;
select plan(6);

create temporary table _fn_table (proname text primary key, table_name text) on commit drop;
insert into _fn_table values
  ('advance_task','tasks'),
  ('advance_lead','leads'),
  ('advance_booking','bookings'),
  ('advance_booking_item','booking_items'),
  ('advance_quotation','quotations'),
  ('advance_refund','refunds'),
  ('advance_complaint','complaints'),
  ('advance_conversation','conversations'),
  ('advance_service_request','service_requests'),
  ('advance_marketing_campaign','marketing_campaigns');

-- The VALUES block of each function, then every tuple inside it. Delimiting the block first is what
-- keeps `p_to_status in ('cancelled','void','refunded','reissue')` -- a real line in advance_booking
-- -- from being read as a transition. The permission is whichever UPPERCASE code appears in the
-- tuple's tail, if any; functions that authorize a single constant permission outside the tuple
-- (advance_refund, advance_booking_item) leave it null and are compared on existence alone.
create temporary table _fn_rules as
with blocks as (
  select ft.table_name,
         substring(pg_get_functiondef(p.oid) from 'values(.*?)\) as ') as blk
  from _fn_table ft
  join pg_proc p on p.proname = ft.proname
  join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'app'
)
select b.table_name,
       m[1] as from_status,
       m[2] as to_status,
       (regexp_match(m[3], '''([A-Z_]{3,})'''))[1] as permission_key
from blocks b
cross join lateral regexp_matches(b.blk, '\(''([a-z_]+)'',\s*''([a-z_]+)'',([^()]*)\)', 'g') m;

-- The transitions the TABLE permits that no advance_* function offers, and who owns them instead.
create temporary table _rpc_owned (table_name text, from_status text, to_status text, owner_fn text)
  on commit drop;
insert into _rpc_owned values
  ('leads','new',       'assigned',  'app.assign_lead'),
  ('leads','assigned',  'contacted', 'app.record_lead_interaction'),
  ('leads','won',       'converted', 'app.convert_lead'),
  -- DOC-LC-1. `documents` has no `advance_document` -- canon 26's Document Lifecycle machine is
  -- driven by a named operation, not a generic advancer. `app.archive_document` refuses only when
  -- the document is ALREADY archived, so it performs both registered moves.
  ('documents','active',    'archived','app.archive_document'),
  ('documents','superseded','archived','app.archive_document'),
  -- FIN-7. `invoices` has no `advance_invoice` either: the machine is driven by two named finance
  -- operations whose own guards have always enforced it. `app.issue_invoice` performs the only move
  -- into `issued`; `app.record_payment` performs every move into `partially_paid`/`paid` and DERIVES
  -- which one from the amount rather than choosing it.
  ('invoices','draft',         'issued',        'app.issue_invoice'),
  ('invoices','issued',        'partially_paid','app.record_payment'),
  ('invoices','issued',        'paid',          'app.record_payment'),
  ('invoices','partially_paid','paid',          'app.record_payment'),
  ('invoices','overdue',       'partially_paid','app.record_payment'),
  ('invoices','overdue',       'paid',          'app.record_payment');

-- =============================================================================================
-- 1. COVERAGE. Every one of the ten functions must be parsed. This is the assertion the previous
--    version lacked, and its absence is why the parity check silently shrank to one function.
-- =============================================================================================
select is(
  (select count(distinct table_name)::int from _fn_rules),
  10,
  'POSITIVE CONTROL: all TEN advance_* functions were parsed -- a shape change that breaks the parser fails here, not silently');

select cmp_ok(
  (select count(*)::int from _fn_rules), '>=', 100,
  '...and they yield the full body of rules, not a handful');

-- =============================================================================================
-- 2-3. RPC -> TABLE. Same permission, and the move must actually be permitted.
-- =============================================================================================
select is(
  (select count(*)::int
     from _fn_rules f
     join app.status_transitions st
       on st.table_name = f.table_name
      and st.from_status = f.from_status
      and st.to_status = f.to_status
    where f.permission_key is not null
      and st.permission_key is distinct from f.permission_key),
  0,
  'no advance_* function requires a different permission than the trigger does for the same transition');

select is(
  (select count(*)::int
     from _fn_rules f
    where not exists (select 1 from app.status_transitions st
                       where st.table_name = f.table_name
                         and st.from_status = f.from_status
                         and st.to_status = f.to_status)),
  0,
  'every transition an advance_* function offers is one the trigger actually permits');

-- =============================================================================================
-- 4-5. TABLE -> RPC, the direction that was never checked. A move the trigger permits but no
--      advance_* offers must be named and owned, because an unnamed one is an unguarded path.
-- =============================================================================================
select is(
  (select count(*)::int
     from app.status_transitions st
    where not exists (select 1 from _fn_rules f
                       where f.table_name = st.table_name
                         and f.from_status = st.from_status
                         and f.to_status = st.to_status)
      and not exists (select 1 from _rpc_owned o
                       where o.table_name = st.table_name
                         and o.from_status = st.from_status
                         and o.to_status = st.to_status)),
  0,
  'every transition the TRIGGER permits is offered by an advance_* function or named to the RPC that owns it');

-- DOC-LC-1 fixed a defect in THIS assertion. It hardcoded `lead_status_code`, because every
-- exclusion was a `leads` row when it was written -- so the moment a non-leads exclusion appeared it
-- would have failed for the wrong reason, or (worse, had the column been a substring of another)
-- passed for the wrong one. The status column is now DERIVED per table from
-- `app.status_transitions.status_column`, which is the same source the trigger itself reads. Third
-- instance of the class in this file's history: SEC-1b's ceiling, this file's own one-function
-- regex, and now this.
select is(
  (select count(*)::int
     from _rpc_owned o
    where not exists (
      -- `prokind = 'f'` because pg_get_functiondef raises on aggregates, and the app schema has
      -- them; without it this assertion dies instead of failing, which reads the same in a summary
      -- and is not the same thing at all.
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'app' and p.prokind = 'f'
         and 'app.' || p.proname = o.owner_fn
         and pg_get_functiondef(p.oid) ~ ((select distinct st.status_column
                                             from app.status_transitions st
                                            where st.table_name = o.table_name) || '\s*='))),
  0,
  '...and each named owner really is a function that writes THAT TABLE''s status column -- the exclusion list is evidence, not an excuse');

select finish();
rollback;
