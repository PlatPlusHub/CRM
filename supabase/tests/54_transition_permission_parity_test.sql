-- pgTAP: TRANS-1 -- the transition rules are duplicated, so they must be compared.
--
-- ORVION states every status transition's required permission TWICE:
--
--   1. an inline VALUES list inside each `app.advance_*` function -- (from, to, EVENT, permission)
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
-- Neither copy can simply be deleted today: the table has no event column, so the function's list
-- is the only home for the event code. Giving `app.status_transitions` an event column and making it
-- the single source is recorded as TRANS-1. Until then the duplication is guarded rather than
-- tolerated: this assertion fails the moment the two disagree, so the next engineer to edit one is
-- told to edit the other.
create extension if not exists pgtap with schema extensions;

begin;
select plan(3);

-- The `advance_*` functions whose inline lists carry a permission, mapped to the table they govern.
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
  ('advance_service_request','service_requests');

-- Every 4-tuple `('from','to','event','PERMISSION')` an advance_* function declares.
-- The event slot is either a quoted code or `null::text` -- TASK-2 made two transitions
-- eventless, because canon 26 defines no start event and `app.assign_task` already owns
-- `task_assigned`. The pattern accepts both so those transitions stay permission-compared; a regex
-- that only matched quoted events would have silently stopped checking them, which is precisely the
-- kind of coverage loss that let TRANS-1 happen in the first place.
create temporary table _fn_rules as
select ft.table_name,
       m[1] as from_status,
       m[2] as to_status,
       m[3] as permission_key
from _fn_table ft
join pg_proc p on p.proname = ft.proname
join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'app'
cross join lateral regexp_matches(
    pg_get_functiondef(p.oid),
    '\(''([a-z_]+)'',\s*''([a-z_]+)'',\s*(?:''[a-z_]+''|null::text),\s*''([A-Z_]+)''\)', 'g') m;

select ok(
  (select count(*) from _fn_rules) >= 8,
  'POSITIVE CONTROL: the inline transition lists were actually parsed, so the checks below are not vacuous');

-- =============================================================================================
-- 2. THE PARITY CHECK. A transition an advance_* function knows about must require exactly the
--    permission `app.status_transitions` requires, because the trigger enforces the latter.
-- =============================================================================================
select is(
  (select count(*)::int
     from _fn_rules f
     join app.status_transitions st
       on st.table_name = f.table_name
      and st.from_status = f.from_status
      and st.to_status = f.to_status
    where st.permission_key is distinct from f.permission_key),
  0,
  'no advance_* function requires a different permission than the trigger does for the same transition');

-- =============================================================================================
-- 3. And a transition the function offers must EXIST in the table -- otherwise the RPC advertises
--    a move the trigger will refuse, which is a promise the system cannot keep.
-- =============================================================================================
select is(
  (select count(*)::int
     from _fn_rules f
    where not exists (select 1 from app.status_transitions st
                       where st.table_name = f.table_name
                         and st.from_status = f.from_status
                         and st.to_status = f.to_status)),
  0,
  'every transition an advance_* function offers is one the trigger actually permits');

select finish();
rollback;
