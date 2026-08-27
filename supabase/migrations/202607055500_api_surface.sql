-- API-1 -- ORVION's application API surface. The database stops being unreachable.
--
-- ================================================================================================
-- WHAT THIS IS, AND WHAT IT DELIBERATELY IS NOT
--
-- WP-04-E proved live against Primary that PostgREST serves only `public` and `graphql_public`, so
-- every `app.*` function and every `reporting` view returned 404/406. This migration gives ORVION
-- the API it never had.
--
-- IT IS NOT "wrap everything". The owner directive is explicit: classify the surface first, and
-- expose a function only if it is an intentional application capability. The classification was
-- done against the live catalogue, not by reading names:
--
--   137 `app` functions
--    -20 trigger functions            (`returns trigger` -- never callable by anyone)
--     -7 RLS helpers                  (referenced inside a policy expression: current_tenant_id,
--                                      current_user_id, has_permission, has_tenant_wide_read,
--                                      is_financial_document_type, visible_branch_ids,
--                                      visible_department_ids)
--     -4 view helpers                 (referenced inside a reporting view: item_financials,
--                                      booking_item_profit, customer_balance, supplier_balance)
--     -6 platform functions           (`platform_*`, service_role only -- not a tenant API)
--    -14 not granted to authenticated (system/batch paths: process_lead_sla, provision_tenant,
--                                      reconcile_document_storage, map_outcomes_to_conversions, ...)
--   ----
--     86 granted to `authenticated`, non-trigger, not a policy or view helper
--    -15 INTERNAL HELPERS, listed and excluded by hand (below)
--   ----
--     71 application capabilities -> exposed here, plus 8 reporting views.
--
-- THE 15 EXCLUSIONS, AND WHY EACH MATTERS. These are granted to `authenticated` because ORVION's
-- own SECURITY INVOKER functions call them on the caller's behalf -- not because a client should:
--
--   authorize, record_event, mfa_satisfied, requires_mfa
--       `record_event` is the audit spine's SOLE writer (WP-00). As an endpoint, any authenticated
--       user could mint arbitrary registered event types about arbitrary entities in their own
--       tenant -- audit forgery through the front door. `authorize` and the MFA predicates would be
--       a permission-probing oracle.
--   normalize_email, normalize_phone, plan_allows, plan_limit, sub_status_family,
--   subscription_allows_write, subscription_transition_allowed, commission_rate_default,
--   document_bucket, document_storage_path, is_my_booking_item
--       Pure derivations and predicates. A client has no reason to call them, and exposing them
--       would freeze implementation detail into a public contract.
--
-- THIS IS WHY "just expose the app schema" WAS THE WRONG ANSWER, and it is not a stylistic
-- preference: that single setting would have published `record_event` and `authorize` as endpoints.
--
-- ================================================================================================
-- THE RULES EVERY WRAPPER FOLLOWS, and the guard that keeps them
--
--   SECURITY INVOKER -- never DEFINER. A definer wrapper runs as its owner, so PostgreSQL checks
--     EXECUTE on the inner `app.*` function against the OWNER instead of the caller, turning every
--     wrapper into a privilege-escalation bridge into the private schema. The wrappers add
--     reachability and precisely zero authority: `auth.uid()`, the JWT claims, the acting role and
--     therefore every RLS policy, permission check, MFA step-up, plan gate and tenant boundary are
--     exactly what they were when the same function was called over SQL.
--   `set search_path = ''` on every one, with fully-qualified bodies.
--   Named-argument delegation (`p_x => p_x`) so a signature change in `app` fails loudly at
--     migration time rather than silently binding the wrong parameter positionally.
--   Explicit revoke then explicit grant. GRANT-1 (`202607055400`) established that Supabase's
--     default ACL grants `anon` EXECUTE on new public functions; that default is now revoked, and
--     each wrapper still revokes explicitly so its grant state is readable on its own.
--   All wrappers are VOLATILE, so PostgREST serves every endpoint over POST /rest/v1/rpc/<name>.
--     One uniform calling convention beats a GET/POST split a client has to memorise.
--
-- Guarded by `53_api_surface_test.sql`, which pins the exposed set BY NAME. Adding an endpoint now
-- requires deliberately editing that list -- which is the point: accidental exposure of an internal
-- helper becomes a failing test rather than a silent publication.
--
-- The 8 `reporting` views are exposed as `security_invoker` views in `public`, so they arrive as
-- filterable REST collections and every row is still filtered by the caller's own RLS.
-- ================================================================================================

create or replace function public.activate_membership()
returns TABLE(membership_id uuid, tenant_id uuid, tenant_name text, is_active boolean)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.activate_membership(); $fn$;
revoke execute on function public.activate_membership() from public, anon, authenticated;
grant  execute on function public.activate_membership() to authenticated;

create or replace function public.add_customer_contact_method(p_customer_id uuid, p_contact_method_type_code text, p_value text, p_is_primary boolean DEFAULT false)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.add_customer_contact_method(p_customer_id => p_customer_id, p_contact_method_type_code => p_contact_method_type_code, p_value => p_value, p_is_primary => p_is_primary); $fn$;
revoke execute on function public.add_customer_contact_method(p_customer_id uuid, p_contact_method_type_code text, p_value text, p_is_primary boolean) from public, anon, authenticated;
grant  execute on function public.add_customer_contact_method(p_customer_id uuid, p_contact_method_type_code text, p_value text, p_is_primary boolean) to authenticated;

create or replace function public.add_customer_note(p_customer_id uuid, p_note_text text, p_is_pinned boolean DEFAULT false, p_is_confidential boolean DEFAULT false)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.add_customer_note(p_customer_id => p_customer_id, p_note_text => p_note_text, p_is_pinned => p_is_pinned, p_is_confidential => p_is_confidential); $fn$;
revoke execute on function public.add_customer_note(p_customer_id uuid, p_note_text text, p_is_pinned boolean, p_is_confidential boolean) from public, anon, authenticated;
grant  execute on function public.add_customer_note(p_customer_id uuid, p_note_text text, p_is_pinned boolean, p_is_confidential boolean) to authenticated;

create or replace function public.add_document_version(p_document_id uuid, p_file_name text, p_file_type_code text, p_file_size bigint DEFAULT NULL::bigint)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.add_document_version(p_document_id => p_document_id, p_file_name => p_file_name, p_file_type_code => p_file_type_code, p_file_size => p_file_size); $fn$;
revoke execute on function public.add_document_version(p_document_id uuid, p_file_name text, p_file_type_code text, p_file_size bigint) from public, anon, authenticated;
grant  execute on function public.add_document_version(p_document_id uuid, p_file_name text, p_file_type_code text, p_file_size bigint) to authenticated;

create or replace function public.add_quotation_item(p_quotation_id uuid, p_service_type_code text, p_unit_price numeric, p_quantity numeric DEFAULT 1, p_description text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.add_quotation_item(p_quotation_id => p_quotation_id, p_service_type_code => p_service_type_code, p_unit_price => p_unit_price, p_quantity => p_quantity, p_description => p_description); $fn$;
revoke execute on function public.add_quotation_item(p_quotation_id uuid, p_service_type_code text, p_unit_price numeric, p_quantity numeric, p_description text) from public, anon, authenticated;
grant  execute on function public.add_quotation_item(p_quotation_id uuid, p_service_type_code text, p_unit_price numeric, p_quantity numeric, p_description text) to authenticated;

create or replace function public.advance_booking(p_booking_id uuid, p_to_status text, p_reason text DEFAULT NULL::text)
returns text
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_booking(p_booking_id => p_booking_id, p_to_status => p_to_status, p_reason => p_reason); $fn$;
revoke execute on function public.advance_booking(p_booking_id uuid, p_to_status text, p_reason text) from public, anon, authenticated;
grant  execute on function public.advance_booking(p_booking_id uuid, p_to_status text, p_reason text) to authenticated;

create or replace function public.advance_booking_item(p_booking_item_id uuid, p_to_status text, p_reason text DEFAULT NULL::text, p_sub_status_code text DEFAULT NULL::text, p_cancellation_reason_code text DEFAULT NULL::text)
returns text
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_booking_item(p_booking_item_id => p_booking_item_id, p_to_status => p_to_status, p_reason => p_reason, p_sub_status_code => p_sub_status_code, p_cancellation_reason_code => p_cancellation_reason_code); $fn$;
revoke execute on function public.advance_booking_item(p_booking_item_id uuid, p_to_status text, p_reason text, p_sub_status_code text, p_cancellation_reason_code text) from public, anon, authenticated;
grant  execute on function public.advance_booking_item(p_booking_item_id uuid, p_to_status text, p_reason text, p_sub_status_code text, p_cancellation_reason_code text) to authenticated;

create or replace function public.advance_complaint(p_complaint_id uuid, p_to_status text, p_reason text DEFAULT NULL::text)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_complaint(p_complaint_id => p_complaint_id, p_to_status => p_to_status, p_reason => p_reason); $fn$;
revoke execute on function public.advance_complaint(p_complaint_id uuid, p_to_status text, p_reason text) from public, anon, authenticated;
grant  execute on function public.advance_complaint(p_complaint_id uuid, p_to_status text, p_reason text) to authenticated;

create or replace function public.advance_conversation(p_conversation_id uuid, p_to_status text, p_reason text DEFAULT NULL::text)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_conversation(p_conversation_id => p_conversation_id, p_to_status => p_to_status, p_reason => p_reason); $fn$;
revoke execute on function public.advance_conversation(p_conversation_id uuid, p_to_status text, p_reason text) from public, anon, authenticated;
grant  execute on function public.advance_conversation(p_conversation_id uuid, p_to_status text, p_reason text) to authenticated;

create or replace function public.advance_lead(p_lead_id uuid, p_to_status text, p_reason text DEFAULT NULL::text, p_closure_reason_code text DEFAULT NULL::text)
returns text
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_lead(p_lead_id => p_lead_id, p_to_status => p_to_status, p_reason => p_reason, p_closure_reason_code => p_closure_reason_code); $fn$;
revoke execute on function public.advance_lead(p_lead_id uuid, p_to_status text, p_reason text, p_closure_reason_code text) from public, anon, authenticated;
grant  execute on function public.advance_lead(p_lead_id uuid, p_to_status text, p_reason text, p_closure_reason_code text) to authenticated;

create or replace function public.advance_marketing_campaign(p_campaign_id uuid, p_to_status text, p_reason text DEFAULT NULL::text)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_marketing_campaign(p_campaign_id => p_campaign_id, p_to_status => p_to_status, p_reason => p_reason); $fn$;
revoke execute on function public.advance_marketing_campaign(p_campaign_id uuid, p_to_status text, p_reason text) from public, anon, authenticated;
grant  execute on function public.advance_marketing_campaign(p_campaign_id uuid, p_to_status text, p_reason text) to authenticated;

create or replace function public.advance_quotation(p_quotation_id uuid, p_to_status text, p_reason text DEFAULT NULL::text)
returns text
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_quotation(p_quotation_id => p_quotation_id, p_to_status => p_to_status, p_reason => p_reason); $fn$;
revoke execute on function public.advance_quotation(p_quotation_id uuid, p_to_status text, p_reason text) from public, anon, authenticated;
grant  execute on function public.advance_quotation(p_quotation_id uuid, p_to_status text, p_reason text) to authenticated;

create or replace function public.advance_refund(p_refund_id uuid, p_to_status text, p_reason text DEFAULT NULL::text)
returns text
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_refund(p_refund_id => p_refund_id, p_to_status => p_to_status, p_reason => p_reason); $fn$;
revoke execute on function public.advance_refund(p_refund_id uuid, p_to_status text, p_reason text) from public, anon, authenticated;
grant  execute on function public.advance_refund(p_refund_id uuid, p_to_status text, p_reason text) to authenticated;

create or replace function public.advance_service_request(p_service_request_id uuid, p_to_status text, p_reason text DEFAULT NULL::text)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_service_request(p_service_request_id => p_service_request_id, p_to_status => p_to_status, p_reason => p_reason); $fn$;
revoke execute on function public.advance_service_request(p_service_request_id uuid, p_to_status text, p_reason text) from public, anon, authenticated;
grant  execute on function public.advance_service_request(p_service_request_id uuid, p_to_status text, p_reason text) to authenticated;

create or replace function public.advance_task(p_task_id uuid, p_to_status text, p_reason text DEFAULT NULL::text)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.advance_task(p_task_id => p_task_id, p_to_status => p_to_status, p_reason => p_reason); $fn$;
revoke execute on function public.advance_task(p_task_id uuid, p_to_status text, p_reason text) from public, anon, authenticated;
grant  execute on function public.advance_task(p_task_id uuid, p_to_status text, p_reason text) to authenticated;

create or replace function public.archive_document(p_document_id uuid, p_reason text)
returns text
language sql
security invoker
set search_path = ''
as $fn$ select app.archive_document(p_document_id => p_document_id, p_reason => p_reason); $fn$;
revoke execute on function public.archive_document(p_document_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.archive_document(p_document_id uuid, p_reason text) to authenticated;

create or replace function public.assign_lead(p_lead_id uuid, p_assignee_user_id uuid, p_reason text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.assign_lead(p_lead_id => p_lead_id, p_assignee_user_id => p_assignee_user_id, p_reason => p_reason); $fn$;
revoke execute on function public.assign_lead(p_lead_id uuid, p_assignee_user_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.assign_lead(p_lead_id uuid, p_assignee_user_id uuid, p_reason text) to authenticated;

create or replace function public.assign_lead_round_robin(p_lead_id uuid, p_reason text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.assign_lead_round_robin(p_lead_id => p_lead_id, p_reason => p_reason); $fn$;
revoke execute on function public.assign_lead_round_robin(p_lead_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.assign_lead_round_robin(p_lead_id uuid, p_reason text) to authenticated;

create or replace function public.assign_task(p_task_id uuid, p_owner_user_id uuid, p_owner_department_id uuid DEFAULT NULL::uuid, p_owner_branch_id uuid DEFAULT NULL::uuid, p_reason text DEFAULT NULL::text)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.assign_task(p_task_id => p_task_id, p_owner_user_id => p_owner_user_id, p_owner_department_id => p_owner_department_id, p_owner_branch_id => p_owner_branch_id, p_reason => p_reason); $fn$;
revoke execute on function public.assign_task(p_task_id uuid, p_owner_user_id uuid, p_owner_department_id uuid, p_owner_branch_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.assign_task(p_task_id uuid, p_owner_user_id uuid, p_owner_department_id uuid, p_owner_branch_id uuid, p_reason text) to authenticated;

create or replace function public.assign_user_branch(p_user_id uuid, p_branch_id uuid, p_department_id uuid DEFAULT NULL::uuid, p_is_primary boolean DEFAULT false, p_transfer_type_code text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.assign_user_branch(p_user_id => p_user_id, p_branch_id => p_branch_id, p_department_id => p_department_id, p_is_primary => p_is_primary, p_transfer_type_code => p_transfer_type_code); $fn$;
revoke execute on function public.assign_user_branch(p_user_id uuid, p_branch_id uuid, p_department_id uuid, p_is_primary boolean, p_transfer_type_code text) from public, anon, authenticated;
grant  execute on function public.assign_user_branch(p_user_id uuid, p_branch_id uuid, p_department_id uuid, p_is_primary boolean, p_transfer_type_code text) to authenticated;

create or replace function public.assign_user_role(p_user_id uuid, p_role_code text, p_scope_type text DEFAULT 'tenant'::text, p_branch_id uuid DEFAULT NULL::uuid, p_department_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.assign_user_role(p_user_id => p_user_id, p_role_code => p_role_code, p_scope_type => p_scope_type, p_branch_id => p_branch_id, p_department_id => p_department_id); $fn$;
revoke execute on function public.assign_user_role(p_user_id uuid, p_role_code text, p_scope_type text, p_branch_id uuid, p_department_id uuid) from public, anon, authenticated;
grant  execute on function public.assign_user_role(p_user_id uuid, p_role_code text, p_scope_type text, p_branch_id uuid, p_department_id uuid) to authenticated;

create or replace function public.convert_lead(p_lead_id uuid, p_customer_id uuid DEFAULT NULL::uuid, p_reason text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.convert_lead(p_lead_id => p_lead_id, p_customer_id => p_customer_id, p_reason => p_reason); $fn$;
revoke execute on function public.convert_lead(p_lead_id uuid, p_customer_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.convert_lead(p_lead_id uuid, p_customer_id uuid, p_reason text) to authenticated;

create or replace function public.create_booking(p_customer_id uuid DEFAULT NULL::uuid, p_lead_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_branch_id uuid DEFAULT NULL::uuid, p_department_id uuid DEFAULT NULL::uuid, p_travel_start_date date DEFAULT NULL::date, p_travel_end_date date DEFAULT NULL::date, p_destination_country_code text DEFAULT NULL::text, p_destination_city text DEFAULT NULL::text, p_booking_reference text DEFAULT NULL::text, p_quotation_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_booking(p_customer_id => p_customer_id, p_lead_id => p_lead_id, p_title => p_title, p_branch_id => p_branch_id, p_department_id => p_department_id, p_travel_start_date => p_travel_start_date, p_travel_end_date => p_travel_end_date, p_destination_country_code => p_destination_country_code, p_destination_city => p_destination_city, p_booking_reference => p_booking_reference, p_quotation_id => p_quotation_id); $fn$;
revoke execute on function public.create_booking(p_customer_id uuid, p_lead_id uuid, p_title text, p_branch_id uuid, p_department_id uuid, p_travel_start_date date, p_travel_end_date date, p_destination_country_code text, p_destination_city text, p_booking_reference text, p_quotation_id uuid) from public, anon, authenticated;
grant  execute on function public.create_booking(p_customer_id uuid, p_lead_id uuid, p_title text, p_branch_id uuid, p_department_id uuid, p_travel_start_date date, p_travel_end_date date, p_destination_country_code text, p_destination_city text, p_booking_reference text, p_quotation_id uuid) to authenticated;

create or replace function public.create_booking_item(p_booking_id uuid, p_service_type_code text, p_currency_code text, p_cost_amount numeric DEFAULT 0, p_selling_amount numeric DEFAULT 0, p_supplier_id uuid DEFAULT NULL::uuid, p_sub_status_code text DEFAULT NULL::text, p_finance_approval_required boolean DEFAULT false)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_booking_item(p_booking_id => p_booking_id, p_service_type_code => p_service_type_code, p_currency_code => p_currency_code, p_cost_amount => p_cost_amount, p_selling_amount => p_selling_amount, p_supplier_id => p_supplier_id, p_sub_status_code => p_sub_status_code, p_finance_approval_required => p_finance_approval_required); $fn$;
revoke execute on function public.create_booking_item(p_booking_id uuid, p_service_type_code text, p_currency_code text, p_cost_amount numeric, p_selling_amount numeric, p_supplier_id uuid, p_sub_status_code text, p_finance_approval_required boolean) from public, anon, authenticated;
grant  execute on function public.create_booking_item(p_booking_id uuid, p_service_type_code text, p_currency_code text, p_cost_amount numeric, p_selling_amount numeric, p_supplier_id uuid, p_sub_status_code text, p_finance_approval_required boolean) to authenticated;

create or replace function public.create_branch(p_name text, p_slug text, p_branch_type text DEFAULT NULL::text, p_primary_phone text DEFAULT NULL::text, p_address text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_branch(p_name => p_name, p_slug => p_slug, p_branch_type => p_branch_type, p_primary_phone => p_primary_phone, p_address => p_address); $fn$;
revoke execute on function public.create_branch(p_name text, p_slug text, p_branch_type text, p_primary_phone text, p_address text) from public, anon, authenticated;
grant  execute on function public.create_branch(p_name text, p_slug text, p_branch_type text, p_primary_phone text, p_address text) to authenticated;

create or replace function public.create_complaint(p_customer_id uuid, p_title text, p_complaint_category_code text, p_complaint_severity_code text DEFAULT 'normal'::text, p_description text DEFAULT NULL::text, p_booking_id uuid DEFAULT NULL::uuid, p_booking_item_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_complaint(p_customer_id => p_customer_id, p_title => p_title, p_complaint_category_code => p_complaint_category_code, p_complaint_severity_code => p_complaint_severity_code, p_description => p_description, p_booking_id => p_booking_id, p_booking_item_id => p_booking_item_id); $fn$;
revoke execute on function public.create_complaint(p_customer_id uuid, p_title text, p_complaint_category_code text, p_complaint_severity_code text, p_description text, p_booking_id uuid, p_booking_item_id uuid) from public, anon, authenticated;
grant  execute on function public.create_complaint(p_customer_id uuid, p_title text, p_complaint_category_code text, p_complaint_severity_code text, p_description text, p_booking_id uuid, p_booking_item_id uuid) to authenticated;

create or replace function public.create_customer(p_customer_type_code text, p_full_name text, p_first_name text DEFAULT NULL::text, p_family_name text DEFAULT NULL::text, p_company_name text DEFAULT NULL::text, p_primary_phone text DEFAULT NULL::text, p_primary_email text DEFAULT NULL::text, p_whatsapp text DEFAULT NULL::text, p_preferred_language_code text DEFAULT NULL::text, p_preferred_contact_method_code text DEFAULT NULL::text, p_marketing_opt_in boolean DEFAULT false, p_branch_id uuid DEFAULT NULL::uuid, p_allow_duplicate boolean DEFAULT false)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_customer(p_customer_type_code => p_customer_type_code, p_full_name => p_full_name, p_first_name => p_first_name, p_family_name => p_family_name, p_company_name => p_company_name, p_primary_phone => p_primary_phone, p_primary_email => p_primary_email, p_whatsapp => p_whatsapp, p_preferred_language_code => p_preferred_language_code, p_preferred_contact_method_code => p_preferred_contact_method_code, p_marketing_opt_in => p_marketing_opt_in, p_branch_id => p_branch_id, p_allow_duplicate => p_allow_duplicate); $fn$;
revoke execute on function public.create_customer(p_customer_type_code text, p_full_name text, p_first_name text, p_family_name text, p_company_name text, p_primary_phone text, p_primary_email text, p_whatsapp text, p_preferred_language_code text, p_preferred_contact_method_code text, p_marketing_opt_in boolean, p_branch_id uuid, p_allow_duplicate boolean) from public, anon, authenticated;
grant  execute on function public.create_customer(p_customer_type_code text, p_full_name text, p_first_name text, p_family_name text, p_company_name text, p_primary_phone text, p_primary_email text, p_whatsapp text, p_preferred_language_code text, p_preferred_contact_method_code text, p_marketing_opt_in boolean, p_branch_id uuid, p_allow_duplicate boolean) to authenticated;

create or replace function public.create_department(p_branch_id uuid, p_department_type_code text, p_name text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_department(p_branch_id => p_branch_id, p_department_type_code => p_department_type_code, p_name => p_name); $fn$;
revoke execute on function public.create_department(p_branch_id uuid, p_department_type_code text, p_name text) from public, anon, authenticated;
grant  execute on function public.create_department(p_branch_id uuid, p_department_type_code text, p_name text) to authenticated;

create or replace function public.create_invoice(p_customer_id uuid, p_currency_code text, p_total_amount numeric, p_booking_id uuid DEFAULT NULL::uuid, p_booking_item_id uuid DEFAULT NULL::uuid, p_invoice_date date DEFAULT CURRENT_DATE, p_due_date date DEFAULT NULL::date)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_invoice(p_customer_id => p_customer_id, p_currency_code => p_currency_code, p_total_amount => p_total_amount, p_booking_id => p_booking_id, p_booking_item_id => p_booking_item_id, p_invoice_date => p_invoice_date, p_due_date => p_due_date); $fn$;
revoke execute on function public.create_invoice(p_customer_id uuid, p_currency_code text, p_total_amount numeric, p_booking_id uuid, p_booking_item_id uuid, p_invoice_date date, p_due_date date) from public, anon, authenticated;
grant  execute on function public.create_invoice(p_customer_id uuid, p_currency_code text, p_total_amount numeric, p_booking_id uuid, p_booking_item_id uuid, p_invoice_date date, p_due_date date) to authenticated;

create or replace function public.create_journal_entry(p_source_type_code text, p_entry_date date, p_description text, p_lines jsonb, p_source_entity_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_journal_entry(p_source_type_code => p_source_type_code, p_entry_date => p_entry_date, p_description => p_description, p_lines => p_lines, p_source_entity_id => p_source_entity_id); $fn$;
revoke execute on function public.create_journal_entry(p_source_type_code text, p_entry_date date, p_description text, p_lines jsonb, p_source_entity_id uuid) from public, anon, authenticated;
grant  execute on function public.create_journal_entry(p_source_type_code text, p_entry_date date, p_description text, p_lines jsonb, p_source_entity_id uuid) to authenticated;

create or replace function public.create_lead(p_branch_id uuid, p_department_id uuid, p_lead_source_code text, p_title text, p_priority_code text DEFAULT NULL::text, p_requested_service_type_code text DEFAULT NULL::text, p_customer_id uuid DEFAULT NULL::uuid, p_customer_phone text DEFAULT NULL::text, p_customer_name text DEFAULT NULL::text, p_expected_value numeric DEFAULT NULL::numeric, p_source_payload jsonb DEFAULT NULL::jsonb)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_lead(p_branch_id => p_branch_id, p_department_id => p_department_id, p_lead_source_code => p_lead_source_code, p_title => p_title, p_priority_code => p_priority_code, p_requested_service_type_code => p_requested_service_type_code, p_customer_id => p_customer_id, p_customer_phone => p_customer_phone, p_customer_name => p_customer_name, p_expected_value => p_expected_value, p_source_payload => p_source_payload); $fn$;
revoke execute on function public.create_lead(p_branch_id uuid, p_department_id uuid, p_lead_source_code text, p_title text, p_priority_code text, p_requested_service_type_code text, p_customer_id uuid, p_customer_phone text, p_customer_name text, p_expected_value numeric, p_source_payload jsonb) from public, anon, authenticated;
grant  execute on function public.create_lead(p_branch_id uuid, p_department_id uuid, p_lead_source_code text, p_title text, p_priority_code text, p_requested_service_type_code text, p_customer_id uuid, p_customer_phone text, p_customer_name text, p_expected_value numeric, p_source_payload jsonb) to authenticated;

create or replace function public.create_marketing_campaign(p_campaign_name text, p_platform_code text, p_external_campaign_id text DEFAULT NULL::text, p_started_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_marketing_campaign(p_campaign_name => p_campaign_name, p_platform_code => p_platform_code, p_external_campaign_id => p_external_campaign_id, p_started_at => p_started_at); $fn$;
revoke execute on function public.create_marketing_campaign(p_campaign_name text, p_platform_code text, p_external_campaign_id text, p_started_at timestamp with time zone) from public, anon, authenticated;
grant  execute on function public.create_marketing_campaign(p_campaign_name text, p_platform_code text, p_external_campaign_id text, p_started_at timestamp with time zone) to authenticated;

create or replace function public.create_passenger(p_first_name text, p_family_name text, p_full_name text DEFAULT NULL::text, p_passenger_type_code text DEFAULT 'adult'::text, p_customer_id uuid DEFAULT NULL::uuid, p_relationship_to_customer_code text DEFAULT NULL::text, p_date_of_birth date DEFAULT NULL::date, p_nationality_code text DEFAULT NULL::text, p_passport_number text DEFAULT NULL::text, p_passport_issue_date date DEFAULT NULL::date, p_passport_expiry_date date DEFAULT NULL::date, p_passport_issuing_country_code text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_passenger(p_first_name => p_first_name, p_family_name => p_family_name, p_full_name => p_full_name, p_passenger_type_code => p_passenger_type_code, p_customer_id => p_customer_id, p_relationship_to_customer_code => p_relationship_to_customer_code, p_date_of_birth => p_date_of_birth, p_nationality_code => p_nationality_code, p_passport_number => p_passport_number, p_passport_issue_date => p_passport_issue_date, p_passport_expiry_date => p_passport_expiry_date, p_passport_issuing_country_code => p_passport_issuing_country_code); $fn$;
revoke execute on function public.create_passenger(p_first_name text, p_family_name text, p_full_name text, p_passenger_type_code text, p_customer_id uuid, p_relationship_to_customer_code text, p_date_of_birth date, p_nationality_code text, p_passport_number text, p_passport_issue_date date, p_passport_expiry_date date, p_passport_issuing_country_code text) from public, anon, authenticated;
grant  execute on function public.create_passenger(p_first_name text, p_family_name text, p_full_name text, p_passenger_type_code text, p_customer_id uuid, p_relationship_to_customer_code text, p_date_of_birth date, p_nationality_code text, p_passport_number text, p_passport_issue_date date, p_passport_expiry_date date, p_passport_issuing_country_code text) to authenticated;

create or replace function public.create_quotation(p_customer_id uuid, p_currency_code text, p_lead_id uuid DEFAULT NULL::uuid, p_valid_until timestamp with time zone DEFAULT NULL::timestamp with time zone, p_quotation_number text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_quotation(p_customer_id => p_customer_id, p_currency_code => p_currency_code, p_lead_id => p_lead_id, p_valid_until => p_valid_until, p_quotation_number => p_quotation_number); $fn$;
revoke execute on function public.create_quotation(p_customer_id uuid, p_currency_code text, p_lead_id uuid, p_valid_until timestamp with time zone, p_quotation_number text) from public, anon, authenticated;
grant  execute on function public.create_quotation(p_customer_id uuid, p_currency_code text, p_lead_id uuid, p_valid_until timestamp with time zone, p_quotation_number text) to authenticated;

create or replace function public.create_service_request(p_customer_id uuid, p_title text, p_service_request_type_code text, p_service_request_severity_code text DEFAULT 'normal'::text, p_description text DEFAULT NULL::text, p_booking_id uuid DEFAULT NULL::uuid, p_booking_item_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_service_request(p_customer_id => p_customer_id, p_title => p_title, p_service_request_type_code => p_service_request_type_code, p_service_request_severity_code => p_service_request_severity_code, p_description => p_description, p_booking_id => p_booking_id, p_booking_item_id => p_booking_item_id); $fn$;
revoke execute on function public.create_service_request(p_customer_id uuid, p_title text, p_service_request_type_code text, p_service_request_severity_code text, p_description text, p_booking_id uuid, p_booking_item_id uuid) from public, anon, authenticated;
grant  execute on function public.create_service_request(p_customer_id uuid, p_title text, p_service_request_type_code text, p_service_request_severity_code text, p_description text, p_booking_id uuid, p_booking_item_id uuid) to authenticated;

create or replace function public.create_supplier(p_name text, p_supplier_type_code text, p_phone text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_payment_term_code text DEFAULT NULL::text, p_credit_limit_amount numeric DEFAULT NULL::numeric)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_supplier(p_name => p_name, p_supplier_type_code => p_supplier_type_code, p_phone => p_phone, p_email => p_email, p_payment_term_code => p_payment_term_code, p_credit_limit_amount => p_credit_limit_amount); $fn$;
revoke execute on function public.create_supplier(p_name text, p_supplier_type_code text, p_phone text, p_email text, p_payment_term_code text, p_credit_limit_amount numeric) from public, anon, authenticated;
grant  execute on function public.create_supplier(p_name text, p_supplier_type_code text, p_phone text, p_email text, p_payment_term_code text, p_credit_limit_amount numeric) to authenticated;

create or replace function public.create_task(p_title text, p_task_type_code text, p_owner_user_id uuid DEFAULT NULL::uuid, p_owner_department_id uuid DEFAULT NULL::uuid, p_owner_branch_id uuid DEFAULT NULL::uuid, p_priority_code text DEFAULT 'normal'::text, p_description text DEFAULT NULL::text, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_related_entity_type text DEFAULT NULL::text, p_related_entity_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_task(p_title => p_title, p_task_type_code => p_task_type_code, p_owner_user_id => p_owner_user_id, p_owner_department_id => p_owner_department_id, p_owner_branch_id => p_owner_branch_id, p_priority_code => p_priority_code, p_description => p_description, p_due_at => p_due_at, p_related_entity_type => p_related_entity_type, p_related_entity_id => p_related_entity_id); $fn$;
revoke execute on function public.create_task(p_title text, p_task_type_code text, p_owner_user_id uuid, p_owner_department_id uuid, p_owner_branch_id uuid, p_priority_code text, p_description text, p_due_at timestamp with time zone, p_related_entity_type text, p_related_entity_id uuid) from public, anon, authenticated;
grant  execute on function public.create_task(p_title text, p_task_type_code text, p_owner_user_id uuid, p_owner_department_id uuid, p_owner_branch_id uuid, p_priority_code text, p_description text, p_due_at timestamp with time zone, p_related_entity_type text, p_related_entity_id uuid) to authenticated;

create or replace function public.create_tenant_user(p_full_name text, p_email text, p_phone text DEFAULT NULL::text, p_auth_user_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.create_tenant_user(p_full_name => p_full_name, p_email => p_email, p_phone => p_phone, p_auth_user_id => p_auth_user_id); $fn$;
revoke execute on function public.create_tenant_user(p_full_name text, p_email text, p_phone text, p_auth_user_id uuid) from public, anon, authenticated;
grant  execute on function public.create_tenant_user(p_full_name text, p_email text, p_phone text, p_auth_user_id uuid) to authenticated;

create or replace function public.current_placement()
returns TABLE(branch_id uuid, department_id uuid)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.current_placement(); $fn$;
revoke execute on function public.current_placement() from public, anon, authenticated;
grant  execute on function public.current_placement() to authenticated;

create or replace function public.customer_timeline(p_customer_id uuid)
returns TABLE(seq bigint, occurred_at timestamp with time zone, event_type_code text, entity_type text, entity_id uuid, actor_user_id uuid, previous_state text, new_state text, reason text, payload jsonb)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.customer_timeline(p_customer_id => p_customer_id); $fn$;
revoke execute on function public.customer_timeline(p_customer_id uuid) from public, anon, authenticated;
grant  execute on function public.customer_timeline(p_customer_id uuid) to authenticated;

create or replace function public.expiring_documents(p_within_days integer DEFAULT 30)
returns TABLE(document_id uuid, document_type_code text, title text, expires_at timestamp with time zone, days_until_expiry integer, is_confidential boolean)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.expiring_documents(p_within_days => p_within_days); $fn$;
revoke execute on function public.expiring_documents(p_within_days integer) from public, anon, authenticated;
grant  execute on function public.expiring_documents(p_within_days integer) to authenticated;

create or replace function public.financial_documents()
returns TABLE(document_id uuid, document_type_code text, title text, lifecycle_status_code text, is_confidential boolean, invoice_id uuid, receipt_id uuid)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.financial_documents(); $fn$;
revoke execute on function public.financial_documents() from public, anon, authenticated;
grant  execute on function public.financial_documents() to authenticated;

create or replace function public.find_customer_duplicates(p_phone text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_whatsapp text DEFAULT NULL::text, p_passport_number text DEFAULT NULL::text, p_document_number text DEFAULT NULL::text)
returns TABLE(customer_id uuid, full_name text, matched_signal_type text, matched_value text)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.find_customer_duplicates(p_phone => p_phone, p_email => p_email, p_whatsapp => p_whatsapp, p_passport_number => p_passport_number, p_document_number => p_document_number); $fn$;
revoke execute on function public.find_customer_duplicates(p_phone text, p_email text, p_whatsapp text, p_passport_number text, p_document_number text) from public, anon, authenticated;
grant  execute on function public.find_customer_duplicates(p_phone text, p_email text, p_whatsapp text, p_passport_number text, p_document_number text) to authenticated;

create or replace function public.issue_invoice(p_invoice_id uuid, p_reason text DEFAULT NULL::text)
returns text
language sql
security invoker
set search_path = ''
as $fn$ select app.issue_invoice(p_invoice_id => p_invoice_id, p_reason => p_reason); $fn$;
revoke execute on function public.issue_invoice(p_invoice_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.issue_invoice(p_invoice_id uuid, p_reason text) to authenticated;

create or replace function public.issue_receipt(p_payment_id uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.issue_receipt(p_payment_id => p_payment_id); $fn$;
revoke execute on function public.issue_receipt(p_payment_id uuid) from public, anon, authenticated;
grant  execute on function public.issue_receipt(p_payment_id uuid) to authenticated;

create or replace function public.lead_booking_readiness(p_lead_id uuid)
returns TABLE(lead_id uuid, is_ready boolean, reason_code text, reason text, customer_id uuid, lead_status_code text, requested_service_type_code text, branch_id uuid, department_id uuid, assigned_user_id uuid, expected_value numeric, title text)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.lead_booking_readiness(p_lead_id => p_lead_id); $fn$;
revoke execute on function public.lead_booking_readiness(p_lead_id uuid) from public, anon, authenticated;
grant  execute on function public.lead_booking_readiness(p_lead_id uuid) to authenticated;

create or replace function public.lead_origin(p_lead_id uuid)
returns TABLE(first_user_id uuid, first_assigned_at timestamp with time zone, current_user_id uuid, assignment_count integer)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.lead_origin(p_lead_id => p_lead_id); $fn$;
revoke execute on function public.lead_origin(p_lead_id uuid) from public, anon, authenticated;
grant  execute on function public.lead_origin(p_lead_id uuid) to authenticated;

create or replace function public.lead_timeline(p_lead_id uuid)
returns TABLE(seq bigint, occurred_at timestamp with time zone, event_type_code text, entity_type text, entity_id uuid, actor_user_id uuid, previous_state text, new_state text, reason text, payload jsonb)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.lead_timeline(p_lead_id => p_lead_id); $fn$;
revoke execute on function public.lead_timeline(p_lead_id uuid) from public, anon, authenticated;
grant  execute on function public.lead_timeline(p_lead_id uuid) to authenticated;

create or replace function public.link_internal_supplier(p_booking_item_id uuid, p_provider_branch_id uuid, p_provider_department_id uuid, p_reason text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.link_internal_supplier(p_booking_item_id => p_booking_item_id, p_provider_branch_id => p_provider_branch_id, p_provider_department_id => p_provider_department_id, p_reason => p_reason); $fn$;
revoke execute on function public.link_internal_supplier(p_booking_item_id uuid, p_provider_branch_id uuid, p_provider_department_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.link_internal_supplier(p_booking_item_id uuid, p_provider_branch_id uuid, p_provider_department_id uuid, p_reason text) to authenticated;

create or replace function public.link_passenger_to_booking_item(p_booking_item_id uuid, p_passenger_id uuid, p_selling_amount_override numeric DEFAULT NULL::numeric, p_cost_amount_override numeric DEFAULT NULL::numeric)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.link_passenger_to_booking_item(p_booking_item_id => p_booking_item_id, p_passenger_id => p_passenger_id, p_selling_amount_override => p_selling_amount_override, p_cost_amount_override => p_cost_amount_override); $fn$;
revoke execute on function public.link_passenger_to_booking_item(p_booking_item_id uuid, p_passenger_id uuid, p_selling_amount_override numeric, p_cost_amount_override numeric) from public, anon, authenticated;
grant  execute on function public.link_passenger_to_booking_item(p_booking_item_id uuid, p_passenger_id uuid, p_selling_amount_override numeric, p_cost_amount_override numeric) to authenticated;

create or replace function public.merge_customer_identity(p_source_customer_id uuid, p_target_customer_id uuid, p_reason text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.merge_customer_identity(p_source_customer_id => p_source_customer_id, p_target_customer_id => p_target_customer_id, p_reason => p_reason); $fn$;
revoke execute on function public.merge_customer_identity(p_source_customer_id uuid, p_target_customer_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.merge_customer_identity(p_source_customer_id uuid, p_target_customer_id uuid, p_reason text) to authenticated;

create or replace function public.my_memberships()
returns TABLE(membership_id uuid, tenant_id uuid, tenant_name text, is_active boolean)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.my_memberships(); $fn$;
revoke execute on function public.my_memberships() from public, anon, authenticated;
grant  execute on function public.my_memberships() to authenticated;

create or replace function public.my_trusted_devices()
returns TABLE(id uuid, device_identifier text, status_code text, first_seen_at timestamp with time zone, last_seen_at timestamp with time zone, verified_at timestamp with time zone, revoked_at timestamp with time zone)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.my_trusted_devices(); $fn$;
revoke execute on function public.my_trusted_devices() from public, anon, authenticated;
grant  execute on function public.my_trusted_devices() to authenticated;

create or replace function public.reassign_lead(p_lead_id uuid, p_assignee_user_id uuid, p_reason text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.reassign_lead(p_lead_id => p_lead_id, p_assignee_user_id => p_assignee_user_id, p_reason => p_reason); $fn$;
revoke execute on function public.reassign_lead(p_lead_id uuid, p_assignee_user_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.reassign_lead(p_lead_id uuid, p_assignee_user_id uuid, p_reason text) to authenticated;

create or replace function public.record_lead_interaction(p_lead_id uuid, p_interaction_type_code text, p_summary text DEFAULT NULL::text, p_metadata jsonb DEFAULT NULL::jsonb)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.record_lead_interaction(p_lead_id => p_lead_id, p_interaction_type_code => p_interaction_type_code, p_summary => p_summary, p_metadata => p_metadata); $fn$;
revoke execute on function public.record_lead_interaction(p_lead_id uuid, p_interaction_type_code text, p_summary text, p_metadata jsonb) from public, anon, authenticated;
grant  execute on function public.record_lead_interaction(p_lead_id uuid, p_interaction_type_code text, p_summary text, p_metadata jsonb) to authenticated;

create or replace function public.record_offline_conversion(p_conversion_event_type_code text, p_lead_id uuid DEFAULT NULL::uuid, p_booking_id uuid DEFAULT NULL::uuid, p_booking_item_id uuid DEFAULT NULL::uuid, p_payment_id uuid DEFAULT NULL::uuid, p_attribution_click_id uuid DEFAULT NULL::uuid, p_marketing_campaign_id uuid DEFAULT NULL::uuid, p_conversion_value numeric DEFAULT NULL::numeric, p_currency_code text DEFAULT NULL::text, p_conversion_at timestamp with time zone DEFAULT now())
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.record_offline_conversion(p_conversion_event_type_code => p_conversion_event_type_code, p_lead_id => p_lead_id, p_booking_id => p_booking_id, p_booking_item_id => p_booking_item_id, p_payment_id => p_payment_id, p_attribution_click_id => p_attribution_click_id, p_marketing_campaign_id => p_marketing_campaign_id, p_conversion_value => p_conversion_value, p_currency_code => p_currency_code, p_conversion_at => p_conversion_at); $fn$;
revoke execute on function public.record_offline_conversion(p_conversion_event_type_code text, p_lead_id uuid, p_booking_id uuid, p_booking_item_id uuid, p_payment_id uuid, p_attribution_click_id uuid, p_marketing_campaign_id uuid, p_conversion_value numeric, p_currency_code text, p_conversion_at timestamp with time zone) from public, anon, authenticated;
grant  execute on function public.record_offline_conversion(p_conversion_event_type_code text, p_lead_id uuid, p_booking_id uuid, p_booking_item_id uuid, p_payment_id uuid, p_attribution_click_id uuid, p_marketing_campaign_id uuid, p_conversion_value numeric, p_currency_code text, p_conversion_at timestamp with time zone) to authenticated;

create or replace function public.record_payment(p_invoice_id uuid, p_amount numeric, p_payment_method_code text, p_paid_at timestamp with time zone DEFAULT now(), p_reference_number text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.record_payment(p_invoice_id => p_invoice_id, p_amount => p_amount, p_payment_method_code => p_payment_method_code, p_paid_at => p_paid_at, p_reference_number => p_reference_number); $fn$;
revoke execute on function public.record_payment(p_invoice_id uuid, p_amount numeric, p_payment_method_code text, p_paid_at timestamp with time zone, p_reference_number text) from public, anon, authenticated;
grant  execute on function public.record_payment(p_invoice_id uuid, p_amount numeric, p_payment_method_code text, p_paid_at timestamp with time zone, p_reference_number text) to authenticated;

create or replace function public.record_refund(p_customer_id uuid, p_amount numeric, p_currency_code text, p_refund_reason_code text, p_booking_id uuid DEFAULT NULL::uuid, p_original_payment_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.record_refund(p_customer_id => p_customer_id, p_amount => p_amount, p_currency_code => p_currency_code, p_refund_reason_code => p_refund_reason_code, p_booking_id => p_booking_id, p_original_payment_id => p_original_payment_id); $fn$;
revoke execute on function public.record_refund(p_customer_id uuid, p_amount numeric, p_currency_code text, p_refund_reason_code text, p_booking_id uuid, p_original_payment_id uuid) from public, anon, authenticated;
grant  execute on function public.record_refund(p_customer_id uuid, p_amount numeric, p_currency_code text, p_refund_reason_code text, p_booking_id uuid, p_original_payment_id uuid) to authenticated;

create or replace function public.record_supplier_payment(p_supplier_id uuid, p_amount numeric, p_currency_code text, p_payment_method_code text, p_booking_id uuid DEFAULT NULL::uuid, p_paid_at timestamp with time zone DEFAULT now(), p_reference_number text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.record_supplier_payment(p_supplier_id => p_supplier_id, p_amount => p_amount, p_currency_code => p_currency_code, p_payment_method_code => p_payment_method_code, p_booking_id => p_booking_id, p_paid_at => p_paid_at, p_reference_number => p_reference_number); $fn$;
revoke execute on function public.record_supplier_payment(p_supplier_id uuid, p_amount numeric, p_currency_code text, p_payment_method_code text, p_booking_id uuid, p_paid_at timestamp with time zone, p_reference_number text) from public, anon, authenticated;
grant  execute on function public.record_supplier_payment(p_supplier_id uuid, p_amount numeric, p_currency_code text, p_payment_method_code text, p_booking_id uuid, p_paid_at timestamp with time zone, p_reference_number text) to authenticated;

create or replace function public.record_trusted_device(p_device_identifier text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.record_trusted_device(p_device_identifier => p_device_identifier); $fn$;
revoke execute on function public.record_trusted_device(p_device_identifier text) from public, anon, authenticated;
grant  execute on function public.record_trusted_device(p_device_identifier text) to authenticated;

create or replace function public.redeem_license_token(p_token text)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.redeem_license_token(p_token => p_token); $fn$;
revoke execute on function public.redeem_license_token(p_token text) from public, anon, authenticated;
grant  execute on function public.redeem_license_token(p_token text) to authenticated;

create or replace function public.request_finance_approval(p_booking_item_id uuid, p_reason text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.request_finance_approval(p_booking_item_id => p_booking_item_id, p_reason => p_reason); $fn$;
revoke execute on function public.request_finance_approval(p_booking_item_id uuid, p_reason text) from public, anon, authenticated;
grant  execute on function public.request_finance_approval(p_booking_item_id uuid, p_reason text) to authenticated;

create or replace function public.review_finance_approval(p_approval_request_id uuid, p_decision text, p_reason text DEFAULT NULL::text)
returns text
language sql
security invoker
set search_path = ''
as $fn$ select app.review_finance_approval(p_approval_request_id => p_approval_request_id, p_decision => p_decision, p_reason => p_reason); $fn$;
revoke execute on function public.review_finance_approval(p_approval_request_id uuid, p_decision text, p_reason text) from public, anon, authenticated;
grant  execute on function public.review_finance_approval(p_approval_request_id uuid, p_decision text, p_reason text) to authenticated;

create or replace function public.revoke_trusted_device(p_device_id uuid)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.revoke_trusted_device(p_device_id => p_device_id); $fn$;
revoke execute on function public.revoke_trusted_device(p_device_id uuid) from public, anon, authenticated;
grant  execute on function public.revoke_trusted_device(p_device_id uuid) to authenticated;

create or replace function public.revoke_user_role(p_assignment_id uuid)
returns void
language sql
security invoker
set search_path = ''
as $fn$ select app.revoke_user_role(p_assignment_id => p_assignment_id); $fn$;
revoke execute on function public.revoke_user_role(p_assignment_id uuid) from public, anon, authenticated;
grant  execute on function public.revoke_user_role(p_assignment_id uuid) to authenticated;

create or replace function public.seed_default_chart_of_accounts()
returns integer
language sql
security invoker
set search_path = ''
as $fn$ select app.seed_default_chart_of_accounts(); $fn$;
revoke execute on function public.seed_default_chart_of_accounts() from public, anon, authenticated;
grant  execute on function public.seed_default_chart_of_accounts() to authenticated;

create or replace function public.send_conversation_message(p_conversation_id uuid, p_message_direction_code text, p_sender_type_code text, p_body text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.send_conversation_message(p_conversation_id => p_conversation_id, p_message_direction_code => p_message_direction_code, p_sender_type_code => p_sender_type_code, p_body => p_body); $fn$;
revoke execute on function public.send_conversation_message(p_conversation_id uuid, p_message_direction_code text, p_sender_type_code text, p_body text) from public, anon, authenticated;
grant  execute on function public.send_conversation_message(p_conversation_id uuid, p_message_direction_code text, p_sender_type_code text, p_body text) to authenticated;

create or replace function public.start_conversation(p_channel_code text, p_customer_id uuid DEFAULT NULL::uuid, p_lead_id uuid DEFAULT NULL::uuid, p_booking_id uuid DEFAULT NULL::uuid, p_booking_item_id uuid DEFAULT NULL::uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.start_conversation(p_channel_code => p_channel_code, p_customer_id => p_customer_id, p_lead_id => p_lead_id, p_booking_id => p_booking_id, p_booking_item_id => p_booking_item_id); $fn$;
revoke execute on function public.start_conversation(p_channel_code text, p_customer_id uuid, p_lead_id uuid, p_booking_id uuid, p_booking_item_id uuid) from public, anon, authenticated;
grant  execute on function public.start_conversation(p_channel_code text, p_customer_id uuid, p_lead_id uuid, p_booking_id uuid, p_booking_item_id uuid) to authenticated;

create or replace function public.tenant_capabilities()
returns TABLE(feature_code text, is_enabled boolean, limit_value numeric)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.tenant_capabilities(); $fn$;
revoke execute on function public.tenant_capabilities() from public, anon, authenticated;
grant  execute on function public.tenant_capabilities() to authenticated;

create or replace function public.upload_document(p_document_type_code text, p_title text, p_file_name text, p_file_type_code text, p_link_target_type text, p_link_target_id uuid, p_file_size bigint DEFAULT NULL::bigint, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_is_confidential boolean DEFAULT false)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.upload_document(p_document_type_code => p_document_type_code, p_title => p_title, p_file_name => p_file_name, p_file_type_code => p_file_type_code, p_link_target_type => p_link_target_type, p_link_target_id => p_link_target_id, p_file_size => p_file_size, p_expires_at => p_expires_at, p_is_confidential => p_is_confidential); $fn$;
revoke execute on function public.upload_document(p_document_type_code text, p_title text, p_file_name text, p_file_type_code text, p_link_target_type text, p_link_target_id uuid, p_file_size bigint, p_expires_at timestamp with time zone, p_is_confidential boolean) from public, anon, authenticated;
grant  execute on function public.upload_document(p_document_type_code text, p_title text, p_file_name text, p_file_type_code text, p_link_target_type text, p_link_target_id uuid, p_file_size bigint, p_expires_at timestamp with time zone, p_is_confidential boolean) to authenticated;

create or replace function public.upload_subscription_payment_proof(p_file_name text, p_file_type_code text, p_file_size bigint DEFAULT NULL::bigint, p_note text DEFAULT NULL::text)
returns uuid
language sql
security invoker
set search_path = ''
as $fn$ select app.upload_subscription_payment_proof(p_file_name => p_file_name, p_file_type_code => p_file_type_code, p_file_size => p_file_size, p_note => p_note); $fn$;
revoke execute on function public.upload_subscription_payment_proof(p_file_name text, p_file_type_code text, p_file_size bigint, p_note text) from public, anon, authenticated;
grant  execute on function public.upload_subscription_payment_proof(p_file_name text, p_file_type_code text, p_file_size bigint, p_note text) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Reporting views. `security_invoker = true` is what keeps RLS applied as the CALLER -- without it
-- a view runs as its owner and every report becomes a tenant-isolation bypass.
-- ---------------------------------------------------------------------------------------------
create or replace view public.booking_item_profit with (security_invoker = true) as select * from reporting.booking_item_profit;
revoke all on public.booking_item_profit from public, anon, authenticated;
grant select on public.booking_item_profit to authenticated;

create or replace view public.booking_pipeline with (security_invoker = true) as select * from reporting.booking_pipeline;
revoke all on public.booking_pipeline from public, anon, authenticated;
grant select on public.booking_pipeline to authenticated;

create or replace view public.customer_outstanding with (security_invoker = true) as select * from reporting.customer_outstanding;
revoke all on public.customer_outstanding from public, anon, authenticated;
grant select on public.customer_outstanding to authenticated;

create or replace view public.lead_performance with (security_invoker = true) as select * from reporting.lead_performance;
revoke all on public.lead_performance from public, anon, authenticated;
grant select on public.lead_performance to authenticated;

create or replace view public.my_sales_performance with (security_invoker = true) as select * from reporting.my_sales_performance;
revoke all on public.my_sales_performance from public, anon, authenticated;
grant select on public.my_sales_performance to authenticated;

create or replace view public.sales_activity with (security_invoker = true) as select * from reporting.sales_activity;
revoke all on public.sales_activity from public, anon, authenticated;
grant select on public.sales_activity to authenticated;

create or replace view public.subscription_state with (security_invoker = true) as select * from reporting.subscription_state;
revoke all on public.subscription_state from public, anon, authenticated;
grant select on public.subscription_state to authenticated;

create or replace view public.supplier_outstanding with (security_invoker = true) as select * from reporting.supplier_outstanding;
revoke all on public.supplier_outstanding from public, anon, authenticated;
grant select on public.supplier_outstanding to authenticated;
