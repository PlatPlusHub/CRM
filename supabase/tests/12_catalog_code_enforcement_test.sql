-- pgTAP invariants: the controlled vocabulary is authoritative AT THE POINT OF USE, not only in the
-- catalog table, and deactivation actually deactivates. Discovery-to-guard for VOCAB-1 / CAT-4,
-- reproduced live on 2026-08-21: tasks accepted task_type_code 'TOTALLY_MADE_UP', suppliers accepted
-- supplier_type_code 'MADE_UP_SUPPLIER', conversations accepted channel_code 'carrier_pigeon' --
-- because 35 of 72 tables have no RPC write path and nothing else validated those columns.
--
-- Every assertion here is behavioural: it attempts the write and requires the outcome. The
-- deactivation pair is the important one -- it proves the rule is "inactive values cannot be chosen
-- for new work, but history keeps what it already references", not the blunt "inactive is illegal"
-- that would make old rows uneditable.
create extension if not exists pgtap with schema extensions;

begin;
select plan(9);

insert into public.tenants (id, name, slug, status)
values ('bbbbbbbb-0000-0000-0000-000000000001','Vocab Tenant','vocab-tenant','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.users (id, tenant_id, full_name, email, is_active)
values ('bbbbbbbb-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001','U','vocab@example.com',true);
insert into public.branches (id, tenant_id, name, slug)
values ('bbbbbbbb-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000001','B','vocab-branch');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
values ('bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000003','sales','D');

-- 1-3. Invented codes are refused on tables that have no RPC write path.
select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title)
    values ('bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002',
            'bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000003',
            'TOTALLY_MADE_UP','open','T')$$,
  '23514', null,
  'an invented task_type_code is refused');

select throws_ok(
  $$insert into public.suppliers (tenant_id, name, supplier_type_code)
    values ('bbbbbbbb-0000-0000-0000-000000000001','S','MADE_UP_SUPPLIER')$$,
  '23514', null,
  'an invented supplier_type_code is refused');

select throws_ok(
  $$insert into public.conversations (tenant_id, channel_code, conversation_status_code)
    values ('bbbbbbbb-0000-0000-0000-000000000001','carrier_pigeon','open')$$,
  '23514', null,
  'an invented channel_code is refused');

-- 4. A genuine catalog value still works -- the guard must not block legitimate business writes.
select lives_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, priority_code, title)
    values ('bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002',
            'bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000003',
            'call_customer','open','high','Call the customer')$$,
  'a valid task_type_code / task_status_code / priority_code is accepted');

-- 5-7. Deactivation semantics (CAT-4). Deactivate a value, then prove the three behaviours that
-- together define the canonical rule.
update public.catalog_values set is_active = false
 where catalog_type_code = 'task_type_code' and code = 'send_quotation';

select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title)
    values ('bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002',
            'bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000003',
            'send_quotation','open','T')$$,
  '23514', null,
  'a DEACTIVATED catalog value cannot be chosen for a new record');

insert into public.tasks (id, tenant_id, owner_user_id, owner_department_id, owner_branch_id,
    task_type_code, task_status_code, title)
values ('bbbbbbbb-0000-0000-0000-00000000000a','bbbbbbbb-0000-0000-0000-000000000001',
        'bbbbbbbb-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000004',
        'bbbbbbbb-0000-0000-0000-000000000003','review_booking','open','Historical task');
update public.catalog_values set is_active = false
 where catalog_type_code = 'task_type_code' and code = 'review_booking';

select lives_ok(
  $$update public.tasks set title = 'Historical task, retitled'
     where id = 'bbbbbbbb-0000-0000-0000-00000000000a'$$,
  'a historical row referencing a since-deactivated value can still be edited');

select throws_ok(
  $$update public.tasks set task_type_code = 'send_quotation'
     where id = 'bbbbbbbb-0000-0000-0000-00000000000a'$$,
  '23514', null,
  'but that row cannot be MOVED onto a deactivated value');

-- 8. The trigger function itself must not be PUBLIC-executable (SPEC-124 invariant).
select is(
  (select count(*)::int
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as g(grantor, grantee, privilege_type, is_grantable)
    where n.nspname = 'app' and p.proname = 'enforce_catalog_codes'
      and g.privilege_type = 'EXECUTE' and g.grantee = 0),
  0,
  'app.enforce_catalog_codes is not executable by PUBLIC');

-- =============================================================================================
-- 9. COMPLETENESS -- added 2026-09-07 after TD-1, and the reason this file now measures the CLAIM
--    and not only the behaviour.
--
--    `202607051300` says it extended the trigger "to every catalog-backed column" and lists its
--    omissions under "DELIBERATE EXCLUSIONS, each with a reason rather than an oversight".
--    `trusted_devices.status_code` was in NEITHER set: the family `trusted_device_status` had been
--    seeded and active since `202607043100`, nothing enforced it, and `authenticated` could store
--    `SUPER_TRUSTED_FOREVER` verbatim. The claim was prose, so no guard could tell an exclusion
--    from an oversight -- which is exactly the class of defect that survives for two months.
--
--    This assertion makes the exclusion list EXECUTABLE. It names every active catalog family with
--    no `app.enforce_catalog_codes` site, matched at the FAMILY position of the (column, family)
--    argument pairs rather than by substring -- a substring match reads a column name, or an
--    unrelated trigger's arguments, as if it were enforcement. Seed a new family without wiring it,
--    or remove a trigger, and the set changes and this fails. Each current member is excused for a
--    reason that is measured, not assumed:
--
--    * ticket_/hotel_/visa_sub_status  -- CAT-5. The governing family DEPENDS ON `service_type_code`,
--                                         so a static mapping cannot express it; `app.sub_status_family`
--                                         enforces it by trigger on `booking_items` instead.
--    * related_entity_type             -- enforced by `app.enforce_entity_reference` (202607050700),
--                                         which checks the vocabulary AND that the row exists.
--    * event_type / security_event_type
--      / event_severity_code           -- `events` / `security_events` carry registry enforcement
--                                         (202607049100) and are append-only; neither is writable by
--                                         `authenticated` at all.
--    * otp_challenge_status            -- unreachable since OTP-1 (202607061600): `authenticated`
--                                         holds no INSERT or UPDATE grant on `otp_challenges`.
--    * document_storage_finding_type
--      / _resolution / usage_metric_code -- consuming tables are not writable by `authenticated`.
--    * confidentiality_level_code
--      / document_link_target_type
--      / verification_method           -- seeded families with NO consuming text column anywhere in
--                                         `public`: dead vocabulary, so there is nothing to enforce.
--                                         Minor debt, not a security gap.
-- =============================================================================================
select is(
  (with args as (
     select string_to_array(encode(t.tgargs, 'escape'), E'\\000') as a
       from pg_trigger t
      where not t.tgisinternal and t.tgfoid::regproc::text = 'app.enforce_catalog_codes'),
   fams as (
     select distinct a[i] as family
       from args, generate_series(1, array_length(a, 1)) g(i)
      where i % 2 = 0 and coalesce(a[i], '') <> '')
   select string_agg(distinct cv.catalog_type_code, ',' order by cv.catalog_type_code)
     from public.catalog_values cv
    where cv.is_active and cv.catalog_type_code not in (select family from fams)),
  'confidentiality_level_code,document_link_target_type,document_storage_finding_resolution,'
  || 'document_storage_finding_type,event_severity_code,event_type,hotel_sub_status,'
  || 'otp_challenge_status,related_entity_type,security_event_type,ticket_sub_status,'
  || 'usage_metric_code,verification_method,visa_sub_status',
  'COMPLETENESS: every active catalog family without an enforce_catalog_codes site is one of these fourteen, each excused for a measured reason in the comment above. trusted_device_status was silently absent from this list until 202607061700 -- seeding a family and never wiring it now fails HERE instead of waiting for someone to attack the column');

select * from finish();
rollback;
