-- pgTAP: every tenant-scoped app function refuses a caller with no active tenant (EC-5, SPEC-338).
-- ATTACK-CLASSES: AUTH TENANT
-- The caller is a real, authenticated member whose user row is deactivated: app.current_tenant_id() is NULL for
-- them, so each function must stop at its own first refusal with its exact message, before any authority check,
-- read or write. Every call passes typed NULL arguments: the tenant refusal precedes every argument check.
create extension if not exists pgtap with schema extensions;

begin;
select plan(74);

insert into auth.users (id, email, email_confirmed_at) values
  ('c3380000-0000-0000-0000-0000000000a1','former@spec338.test', now());
insert into public.tenants (id, name, slug, status) values
  ('c3380000-0000-0000-0000-000000000001','Spec338 Travel','spec338','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select 'c3380000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('c3380000-0000-0000-0000-000000000011','c3380000-0000-0000-0000-000000000001','Former','former@spec338.test',false,'c3380000-0000-0000-0000-0000000000a1');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'c3380000-0000-0000-0000-000000000001','c3380000-0000-0000-0000-000000000011', r.id, 'tenant' from public.roles r where r.code='owner';

-- END FIXTURE

select set_config('request.jwt.claims','{"sub":"c3380000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select is(current_user::text,'authenticated','the probe really runs as authenticated');
select is(auth.uid(),'c3380000-0000-0000-0000-0000000000a1'::uuid,'the JWT is the deactivated member');
select is(app.current_tenant_id(),null::uuid,'a deactivated member has no active tenant');

select throws_ok($q$select app.add_customer_contact_method(null::uuid, null::text, null::text, null::boolean)$q$,'P0001','no active tenant for caller','app.add_customer_contact_method refuses a caller with no active tenant');
select throws_ok($q$select app.add_customer_note(null::uuid, null::text, null::boolean, null::boolean)$q$,'P0001','no active tenant for caller','app.add_customer_note refuses a caller with no active tenant');
select throws_ok($q$select app.add_document_version(null::uuid, null::text, null::text, null::bigint)$q$,'P0001','no active tenant for caller','app.add_document_version refuses a caller with no active tenant');
select throws_ok($q$select app.add_quotation_item(null::uuid, null::text, null::numeric, null::numeric, null::text)$q$,'P0001','no active tenant for caller','app.add_quotation_item refuses a caller with no active tenant');
select throws_ok($q$select app.advance_booking(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_booking refuses a caller with no active tenant');
select throws_ok($q$select app.advance_booking_item(null::uuid, null::text, null::text, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_booking_item refuses a caller with no active tenant');
select throws_ok($q$select app.advance_complaint(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_complaint refuses a caller with no active tenant');
select throws_ok($q$select app.advance_conversation(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_conversation refuses a caller with no active tenant');
select throws_ok($q$select app.advance_lead(null::uuid, null::text, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_lead refuses a caller with no active tenant');
select throws_ok($q$select app.advance_marketing_campaign(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_marketing_campaign refuses a caller with no active tenant');
select throws_ok($q$select app.advance_quotation(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_quotation refuses a caller with no active tenant');
select throws_ok($q$select app.advance_refund(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_refund refuses a caller with no active tenant');
select throws_ok($q$select app.advance_service_request(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_service_request refuses a caller with no active tenant');
select throws_ok($q$select app.advance_task(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.advance_task refuses a caller with no active tenant');
select throws_ok($q$select app.archive_document(null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.archive_document refuses a caller with no active tenant');
select throws_ok($q$select app.assign_lead(null::uuid, null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.assign_lead refuses a caller with no active tenant');
select throws_ok($q$select app.assign_lead_round_robin(null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.assign_lead_round_robin refuses a caller with no active tenant');
select throws_ok($q$select app.assign_task(null::uuid, null::uuid, null::uuid, null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.assign_task refuses a caller with no active tenant');
select throws_ok($q$select app.assign_user_branch(null::uuid, null::uuid, null::uuid, null::boolean, null::text)$q$,'P0001','no active tenant for caller','app.assign_user_branch refuses a caller with no active tenant');
select throws_ok($q$select app.assign_user_role(null::uuid, null::text, null::text, null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.assign_user_role refuses a caller with no active tenant');
select throws_ok($q$select * from app.booking_item_profit(null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.booking_item_profit refuses a caller with no active tenant');
select throws_ok($q$select app.convert_lead(null::uuid, null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.convert_lead refuses a caller with no active tenant');
select throws_ok($q$select app.correct_passenger_manifest(null::uuid, null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.correct_passenger_manifest refuses a caller with no active tenant');
select throws_ok($q$select app.create_booking(null::uuid, null::uuid, null::text, null::uuid, null::uuid, null::date, null::date, null::text, null::text, null::text, null::uuid)$q$,'P0001','no active tenant for caller','app.create_booking refuses a caller with no active tenant');
select throws_ok($q$select app.create_booking_item(null::uuid, null::text, null::text, null::numeric, null::numeric, null::uuid, null::text, null::boolean)$q$,'P0001','no active tenant for caller','app.create_booking_item refuses a caller with no active tenant');
select throws_ok($q$select app.create_branch(null::text, null::text, null::text, null::text, null::text)$q$,'P0001','no active tenant for caller','app.create_branch refuses a caller with no active tenant');
select throws_ok($q$select app.create_complaint(null::uuid, null::text, null::text, null::text, null::text, null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.create_complaint refuses a caller with no active tenant');
select throws_ok($q$select app.create_customer(null::text, null::text, null::text, null::text, null::text, null::text, null::text, null::text, null::text, null::text, null::boolean, null::uuid, null::boolean)$q$,'P0001','no active tenant for caller','app.create_customer refuses a caller with no active tenant');
select throws_ok($q$select app.create_department(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.create_department refuses a caller with no active tenant');
select throws_ok($q$select app.create_invoice(null::uuid, null::text, null::numeric, null::uuid, null::uuid, null::date, null::date)$q$,'P0001','no active tenant for caller','app.create_invoice refuses a caller with no active tenant');
select throws_ok($q$select app.create_journal_entry(null::text, null::date, null::text, null::jsonb, null::uuid)$q$,'P0001','no active tenant for caller','app.create_journal_entry refuses a caller with no active tenant');
select throws_ok($q$select app.create_lead(null::uuid, null::uuid, null::text, null::text, null::text, null::text, null::uuid, null::text, null::text, null::numeric, null::jsonb)$q$,'P0001','no active tenant for caller','app.create_lead refuses a caller with no active tenant');
select throws_ok($q$select app.create_marketing_campaign(null::text, null::text, null::text, null::timestamp with time zone)$q$,'P0001','no active tenant for caller','app.create_marketing_campaign refuses a caller with no active tenant');
select throws_ok($q$select app.create_passenger(null::text, null::text, null::text, null::text, null::uuid, null::text, null::date, null::text, null::text, null::date, null::date, null::text)$q$,'P0001','no active tenant for caller','app.create_passenger refuses a caller with no active tenant');
select throws_ok($q$select app.create_quotation(null::uuid, null::text, null::uuid, null::timestamp with time zone, null::text)$q$,'P0001','no active tenant for caller','app.create_quotation refuses a caller with no active tenant');
select throws_ok($q$select app.create_service_request(null::uuid, null::text, null::text, null::text, null::text, null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.create_service_request refuses a caller with no active tenant');
select throws_ok($q$select app.create_supplier(null::text, null::text, null::text, null::text, null::text, null::numeric, null::text)$q$,'P0001','no active tenant for caller','app.create_supplier refuses a caller with no active tenant');
select throws_ok($q$select app.create_task(null::text, null::text, null::uuid, null::uuid, null::uuid, null::text, null::text, null::timestamp with time zone, null::text, null::uuid)$q$,'P0001','no active tenant for caller','app.create_task refuses a caller with no active tenant');
select throws_ok($q$select app.create_tenant_user(null::text, null::text, null::text, null::uuid)$q$,'P0001','no active tenant for caller','app.create_tenant_user refuses a caller with no active tenant');
select throws_ok($q$select * from app.customer_balance(null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.customer_balance refuses a caller with no active tenant');
select throws_ok($q$select * from app.customer_credit(null::uuid)$q$,'P0001','no active tenant for caller','app.customer_credit refuses a caller with no active tenant');
select throws_ok($q$select * from app.expiring_documents(null::integer)$q$,'P0001','no active tenant for caller','app.expiring_documents refuses a caller with no active tenant');
select throws_ok($q$select * from app.financial_documents()$q$,'P0001','no active tenant for caller','app.financial_documents refuses a caller with no active tenant');
select throws_ok($q$select app.issue_invoice(null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.issue_invoice refuses a caller with no active tenant');
select throws_ok($q$select app.issue_receipt(null::uuid)$q$,'P0001','no active tenant for caller','app.issue_receipt refuses a caller with no active tenant');
select throws_ok($q$select * from app.lead_booking_readiness(null::uuid)$q$,'P0001','no active tenant for caller','app.lead_booking_readiness refuses a caller with no active tenant');
select throws_ok($q$select app.link_internal_supplier(null::uuid, null::uuid, null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.link_internal_supplier refuses a caller with no active tenant');
select throws_ok($q$select app.link_passenger_to_booking_item(null::uuid, null::uuid, null::numeric, null::numeric)$q$,'P0001','no active tenant for caller','app.link_passenger_to_booking_item refuses a caller with no active tenant');
select throws_ok($q$select app.merge_customer_identity(null::uuid, null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.merge_customer_identity refuses a caller with no active tenant');
select throws_ok($q$select app.reassign_booking_item(null::uuid, null::text, null::uuid, null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.reassign_booking_item refuses a caller with no active tenant');
select throws_ok($q$select app.reassign_lead(null::uuid, null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.reassign_lead refuses a caller with no active tenant');
select throws_ok($q$select app.record_customer_consent(null::uuid, null::text, null::text, null::text, null::text)$q$,'P0001','no active tenant for caller','app.record_customer_consent refuses a caller with no active tenant');
select throws_ok($q$select app.record_lead_interaction(null::uuid, null::text, null::text, null::jsonb)$q$,'P0001','no active tenant for caller','app.record_lead_interaction refuses a caller with no active tenant');
select throws_ok($q$select app.record_offline_conversion(null::text, null::uuid, null::uuid, null::uuid, null::uuid, null::uuid, null::uuid, null::numeric, null::text, null::timestamp with time zone)$q$,'P0001','no active tenant for caller','app.record_offline_conversion refuses a caller with no active tenant');
select throws_ok($q$select app.record_payment(null::uuid, null::numeric, null::text, null::timestamp with time zone, null::text)$q$,'P0001','no active tenant for caller','app.record_payment refuses a caller with no active tenant');
select throws_ok($q$select app.record_refund(null::uuid, null::numeric, null::text, null::text, null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.record_refund refuses a caller with no active tenant');
select throws_ok($q$select app.record_supplier_payment(null::uuid, null::numeric, null::text, null::text, null::uuid, null::timestamp with time zone, null::text)$q$,'P0001','no active tenant for caller','app.record_supplier_payment refuses a caller with no active tenant');
select throws_ok($q$select app.redeem_license_token(null::text)$q$,'P0001','no active tenant for caller','app.redeem_license_token refuses a caller with no active tenant');
select throws_ok($q$select app.request_finance_approval(null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.request_finance_approval refuses a caller with no active tenant');
select throws_ok($q$select app.review_finance_approval(null::uuid, null::text, null::text)$q$,'P0001','no active tenant for caller','app.review_finance_approval refuses a caller with no active tenant');
select throws_ok($q$select app.revoke_user_role(null::uuid)$q$,'P0001','no active tenant for caller','app.revoke_user_role refuses a caller with no active tenant');
select throws_ok($q$select app.seed_default_chart_of_accounts()$q$,'P0001','no active tenant for caller','app.seed_default_chart_of_accounts refuses a caller with no active tenant');
select throws_ok($q$select app.send_conversation_message(null::uuid, null::text, null::text, null::text)$q$,'P0001','no active tenant for caller','app.send_conversation_message refuses a caller with no active tenant');
select throws_ok($q$select app.set_document_legal_hold(null::uuid, null::boolean, null::text)$q$,'P0001','no active tenant for caller','app.set_document_legal_hold refuses a caller with no active tenant');
select throws_ok($q$select app.start_conversation(null::text, null::uuid, null::uuid, null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.start_conversation refuses a caller with no active tenant');
select throws_ok($q$select * from app.supplier_balance(null::uuid, null::uuid)$q$,'P0001','no active tenant for caller','app.supplier_balance refuses a caller with no active tenant');
select throws_ok($q$select * from app.supplier_credit(null::uuid)$q$,'P0001','no active tenant for caller','app.supplier_credit refuses a caller with no active tenant');
select throws_ok($q$select app.upload_document(null::text, null::text, null::text, null::text, null::text, null::uuid, null::bigint, null::timestamp with time zone, null::boolean)$q$,'P0001','no active tenant for caller','app.upload_document refuses a caller with no active tenant');
select throws_ok($q$select app.upload_subscription_payment_proof(null::text, null::text, null::bigint, null::text)$q$,'P0001','no active tenant for caller','app.upload_subscription_payment_proof refuses a caller with no active tenant');
select throws_ok($q$select app.void_invoice(null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.void_invoice refuses a caller with no active tenant');
select throws_ok($q$select app.withdraw_finance_approval(null::uuid, null::text)$q$,'P0001','no active tenant for caller','app.withdraw_finance_approval refuses a caller with no active tenant');

select * from finish();
rollback;
