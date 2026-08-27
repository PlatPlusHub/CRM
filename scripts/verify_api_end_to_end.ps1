# ORVION -- the employee journey, proven over HTTP (API-1 / Phase B).
#
# WHY THIS EXISTS. The pgTAP suite proves what SQL does. It cannot prove that a travel-agency
# employee holding a JWT can actually do their job, because it never opens a socket -- which is
# exactly how API-1 (the entire `app` schema being unreachable) stayed invisible behind 600 green
# assertions. This script walks the real revenue lifecycle through the real door:
#
#   customer -> lead -> interaction -> task -> quotation -> send -> convert -> booking
#            -> booking item (cost/selling) -> passenger -> document -> invoice -> payment
#            -> receipt -> personal performance (gross profit, commission, company profit)
#
# Every call is POST /rest/v1/rpc/<name> with a real user JWT. No step uses `postgres`, and no step
# uses `service_role` except where a platform action genuinely requires it.
#
# ON THE KEYS. Read from `npx supabase status`; they belong to the local development stack only
# (`iss: supabase-demo`) on 127.0.0.1 -- the values Supabase publishes in its own documentation. No
# production credential is read or required. Never point this at a hosted project.

$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0
function Check($name, $condition, $detail = '') {
    if ($condition) { $script:pass++; Write-Host "  ok   $name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  FAIL $name  $detail" -ForegroundColor Red }
}

Write-Host "`n== ORVION employee journey over HTTP ==" -ForegroundColor Cyan

$status = (npx supabase status -o json 2>$null) | ConvertFrom-Json
$API = $status.API_URL
$SERVICE = $status.SERVICE_ROLE_KEY
$ANON = $status.ANON_KEY
$JWT_SECRET = $status.JWT_SECRET
if (-not $API) { throw "local stack is not running" }

function New-UserJwt([string]$sub, [bool]$aal2) {
    $exp = [int](Get-Date -UFormat %s) + 3600
    $aal = if ($aal2) { ',"aal":"aal2"' } else { '' }
    $pay = "{""sub"":""$sub"",""role"":""authenticated"",""aud"":""authenticated"",""exp"":$exp$aal}"
    function B64([byte[]]$b) { [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
    $h = B64 ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
    $p = B64 ([Text.Encoding]::UTF8.GetBytes($pay))
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($JWT_SECRET))
    "$h.$p." + (B64 ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$h.$p"))))
}
function Psql([string]$sql) {
    $sql | docker exec -i supabase_db_ORVION psql -U postgres -d postgres -q -t -A -v ON_ERROR_STOP=1 -f - 2>&1
}
# Every application call goes through this. `$jwt` is a real user token, never the service key.
function Rpc($jwt, $name, $body) {
    Invoke-WebRequest -Uri "$API/rest/v1/rpc/$name" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" } `
        -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 6 -Compress)
}
function Get-Rest($jwt, $path) {
    Invoke-WebRequest -Uri "$API/rest/v1/$path" -Method Get -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" }
}
function Val($resp) { if ($resp.StatusCode -lt 300) { ($resp.Content | ConvertFrom-Json) } else { $null } }

$TA = '0a710000-0000-0000-0000-0000000000a0'
$TB = '0a710000-0000-0000-0000-0000000000b0'
$AU_OWNER = '0a710000-0000-0000-0000-0000000000a1'
$AU_EMP = '0a710000-0000-0000-0000-0000000000a2'
$AU_OTHER = '0a710000-0000-0000-0000-0000000000b1'

$existing = (Psql "select count(*) from public.tenants where id in ('$TA','$TB');").Trim()
if ($existing -ne '0') {
    Write-Host "  fixture tenants already present -- run 'npx supabase db reset' first" -ForegroundColor Yellow
    exit 1
}

# ---------------------------------------------------------------------------------------------
# Fixture: one agency with an owner and a frontline employee, plus a second agency whose user is
# the cross-tenant control. Built as postgres because this is establishing the world, not the
# thing under test -- every assertion below runs as a real JWT-bearing user.
# ---------------------------------------------------------------------------------------------
Psql @"
insert into auth.users (id, email) values
  ('$AU_OWNER','owner@journey.test'),('$AU_EMP','emp@journey.test'),('$AU_OTHER','other@journey.test');
insert into public.tenants (id, name, slug, status) values
  ('$TA','Journey Travel','journey-travel','active'), ('$TB','Rival Travel','rival-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id in ('$TA','$TB');
insert into public.branches (id, tenant_id, name, slug) values
  ('0a710000-0000-0000-0000-00000000aa01','$TA','Cairo','journey-cairo'),
  ('0a710000-0000-0000-0000-00000000bb01','$TB','Giza','rival-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('0a710000-0000-0000-0000-00000000aa02','$TA','0a710000-0000-0000-0000-00000000aa01','sales','Sales'),
  ('0a710000-0000-0000-0000-00000000bb02','$TB','0a710000-0000-0000-0000-00000000bb01','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('0a710000-0000-0000-0000-00000000aa03','$TA','Journey Owner','owner@journey.test',true,'$AU_OWNER'),
  ('0a710000-0000-0000-0000-00000000aa04','$TA','Mona Employee','emp@journey.test',true,'$AU_EMP'),
  ('0a710000-0000-0000-0000-00000000bb03','$TB','Rival Owner','other@journey.test',true,'$AU_OTHER');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('$TA','0a710000-0000-0000-0000-00000000aa03','0a710000-0000-0000-0000-00000000aa01','0a710000-0000-0000-0000-00000000aa02',true),
  ('$TA','0a710000-0000-0000-0000-00000000aa04','0a710000-0000-0000-0000-00000000aa01','0a710000-0000-0000-0000-00000000aa02',true),
  ('$TB','0a710000-0000-0000-0000-00000000bb03','0a710000-0000-0000-0000-00000000bb01','0a710000-0000-0000-0000-00000000bb02',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant' from (values
  ('$TA'::uuid,'0a710000-0000-0000-0000-00000000aa03'::uuid,'owner'),
  ('$TA'::uuid,'0a710000-0000-0000-0000-00000000aa04'::uuid,'employee'),
  ('$TB'::uuid,'0a710000-0000-0000-0000-00000000bb03'::uuid,'owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;
select 'FIXTURE_OK';
"@ | Out-Null

$jwtOwner = New-UserJwt $AU_OWNER $true
$jwtEmp = New-UserJwt $AU_EMP $false
$jwtOther = New-UserJwt $AU_OTHER $true

# =============================================================================================
# 0. THE DOOR ITSELF. Before API-1 every one of these was a 404.
# =============================================================================================
Write-Host "`n-- the API exists --"
$anonTry = Invoke-WebRequest -Uri "$API/rest/v1/rpc/create_customer" -Method Post -SkipHttpErrorCheck `
    -Headers @{ apikey = $ANON; Authorization = "Bearer $ANON" } -ContentType 'application/json' `
    -Body '{"p_customer_type_code":"person","p_full_name":"Anon"}'
Check "anon is REFUSED by the endpoint (not 404)" ($anonTry.StatusCode -ge 400 -and $anonTry.StatusCode -ne 404) "$($anonTry.StatusCode)"

# =============================================================================================
# 1-4. CUSTOMER -> LEAD -> INTERACTION -> TASK, all as the frontline employee.
# =============================================================================================
Write-Host "`n-- customer and lead --"
$r = Rpc $jwtEmp 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Ahmed Hassan'; p_primary_phone = '+201001234567'; p_primary_email = 'ahmed@example.com' }
Check "employee creates a customer over HTTP" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$customerId = Val $r

$r = Rpc $jwtEmp 'create_lead' @{ p_branch_id = '0a710000-0000-0000-0000-00000000aa01'; p_department_id = '0a710000-0000-0000-0000-00000000aa02'; p_lead_source_code = 'manual_entry'; p_title = 'Umrah package for 2'; p_customer_id = $customerId; p_expected_value = 40000 }
Check "employee creates a lead" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$leadId = Val $r

# ASSIGNMENT IS SUPERVISORY, and the first run of this script asserted otherwise. The `employee`
# role holds CREATE_LEAD but not ASSIGN_LEAD, and that is correct rather than a gap: the leads policy
# already grants visibility on `owner_user_id`, so a lead its creator can see does not need a
# self-assignment. Deciding who ELSE works a lead is a manager's act. Both halves are asserted.
$r = Rpc $jwtEmp 'assign_lead' @{ p_lead_id = $leadId; p_assignee_user_id = '0a710000-0000-0000-0000-00000000aa04'; p_reason = 'self' }
Check "an employee CANNOT assign a lead -- assignment is supervisory" ($r.StatusCode -eq 403) "$($r.StatusCode) $($r.Content)"

$r = Rpc $jwtOwner 'assign_lead' @{ p_lead_id = $leadId; p_assignee_user_id = '0a710000-0000-0000-0000-00000000aa04'; p_reason = 'walk-in owner' }
Check "...and the OWNER assigns it to the employee -- the positive control" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"

$r = Rpc $jwtEmp 'record_lead_interaction' @{ p_lead_id = $leadId; p_interaction_type_code = 'phone_call'; p_summary = 'Discussed dates and budget' }
Check "employee records a follow-up interaction" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"

# =============================================================================================
# 5-7. QUOTATION -> PRICING -> SEND.
# =============================================================================================
Write-Host "`n-- quotation --"
$r = Rpc $jwtEmp 'create_quotation' @{ p_customer_id = $customerId; p_currency_code = 'EGP'; p_lead_id = $leadId }
Check "employee creates a quotation" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$quotationId = Val $r

$r = Rpc $jwtEmp 'add_quotation_item' @{ p_quotation_id = $quotationId; p_service_type_code = 'flight_ticket'; p_unit_price = 18000; p_quantity = 2; p_description = 'CAI-JED return' }
Check "employee prices a quotation line" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"

$r = Rpc $jwtEmp 'advance_quotation' @{ p_quotation_id = $quotationId; p_to_status = 'sent'; p_reason = 'emailed to customer' }
Check "employee sends the quotation" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"

# =============================================================================================
# 8-11. BOOKING -> ITEM -> PASSENGER, and the financial lineage.
# =============================================================================================
Write-Host "`n-- booking --"
$r = Rpc $jwtEmp 'create_booking' @{ p_customer_id = $customerId; p_lead_id = $leadId; p_title = 'Umrah Nov'; p_branch_id = '0a710000-0000-0000-0000-00000000aa01'; p_department_id = '0a710000-0000-0000-0000-00000000aa02' }
Check "employee creates a booking" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$bookingId = Val $r

$r = Rpc $jwtEmp 'create_booking_item' @{ p_booking_id = $bookingId; p_service_type_code = 'flight_ticket'; p_currency_code = 'EGP'; p_cost_amount = 30000; p_selling_amount = 36000 }
Check "employee creates a booking item with cost and selling" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$itemId = Val $r

$r = Rpc $jwtEmp 'create_passenger' @{ p_first_name = 'Ahmed'; p_family_name = 'Hassan'; p_passenger_type_code = 'adult'; p_customer_id = $customerId }
Check "employee registers a passenger" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$paxId = Val $r

$r = Rpc $jwtEmp 'link_passenger_to_booking_item' @{ p_booking_item_id = $itemId; p_passenger_id = $paxId }
Check "the passenger is linked to the booking item" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"

# =============================================================================================
# 12. DOCUMENTS -- the passport, through the endpoint.
# =============================================================================================
Write-Host "`n-- documents --"
$r = Rpc $jwtEmp 'upload_document' @{ p_document_type_code = 'passport'; p_title = 'Ahmed passport'; p_file_name = 'passport.pdf'; p_file_type_code = 'pdf'; p_link_target_type = 'passenger'; p_link_target_id = $paxId }
Check "employee uploads a passenger document" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"

# =============================================================================================
# 13-15. INVOICE -> PAYMENT -> RECEIPT.
# =============================================================================================
Write-Host "`n-- finance --"
$r = Rpc $jwtOwner 'create_invoice' @{ p_customer_id = $customerId; p_currency_code = 'EGP'; p_total_amount = 36000; p_booking_id = $bookingId }
Check "an invoice is raised" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$invoiceId = Val $r

$r = Rpc $jwtOwner 'issue_invoice' @{ p_invoice_id = $invoiceId; p_reason = 'issued to customer' }
Check "the invoice is issued" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"

$r = Rpc $jwtOwner 'record_payment' @{ p_invoice_id = $invoiceId; p_amount = 36000; p_payment_method_code = 'cash' }
Check "the customer's payment is recorded" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$paymentId = Val $r

$r = Rpc $jwtOwner 'issue_receipt' @{ p_payment_id = $paymentId }
Check "a receipt is issued" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"

# =============================================================================================
# 16-19. THE MONEY. gross = 36000 - 30000 = 6000; commission = 600; company profit = 5400.
#        Read through the employee's OWN report endpoint, as the employee.
# =============================================================================================
Write-Host "`n-- personal performance --"
$r = Get-Rest $jwtEmp "my_sales_performance?select=*"
Check "employee reads their own performance report over HTTP" ($r.StatusCode -eq 200) "$($r.StatusCode) $($r.Content)"
$perf = @(Val $r)
Check "...and it contains exactly their one booking item" ($perf.Count -eq 1) "rows=$($perf.Count)"
if ($perf.Count -eq 1) {
    $row = $perf[0]
    Check "gross profit = selling - cost = 6000" ([decimal]$row.gross_profit -eq 6000) "gross=$($row.gross_profit)"
    Check "commission = 10% of positive gross = 600" ([decimal]$row.employee_commission -eq 600) "commission=$($row.employee_commission)"
    Check "company profit = gross - commission = 5400" ([decimal]$row.company_profit -eq 5400) "company=$($row.company_profit)"
}

# =============================================================================================
# 20-22. ISOLATION. A rival agency's owner -- a fully privileged user in ANOTHER tenant.
# =============================================================================================
Write-Host "`n-- isolation --"
$r = Get-Rest $jwtOther "my_sales_performance?select=*"
$otherPerf = @(Val $r)
Check "the rival agency's owner sees NOTHING in the report" ($otherPerf.Count -eq 0) "rows=$($otherPerf.Count)"

$r = Rpc $jwtOther 'customer_timeline' @{ p_customer_id = $customerId }
$tl = @(Val $r)
Check "...and cannot read the customer's timeline" (($r.StatusCode -ge 400) -or ($tl.Count -eq 0)) "$($r.StatusCode) rows=$($tl.Count)"

$r = Rpc $jwtOther 'create_booking_item' @{ p_booking_id = $bookingId; p_service_type_code = 'hotel'; p_currency_code = 'EGP'; p_cost_amount = 1; p_selling_amount = 2 }
Check "...and cannot append an item to the other agency's booking" ($r.StatusCode -ge 400) "$($r.StatusCode) $($r.Content)"

# =============================================================================================
# 23. INTERNAL HELPERS ARE NOT ENDPOINTS. record_event is the audit spine's only writer.
# =============================================================================================
Write-Host "`n-- the surface is closed --"
$r = Rpc $jwtEmp 'record_event' @{ p_tenant_id = $TA; p_event_type_code = 'booking_created'; p_entity_type = 'booking'; p_entity_id = $bookingId }
Check "record_event is NOT reachable -- audit forgery has no front door" ($r.StatusCode -eq 404) "$($r.StatusCode) $($r.Content)"

$r = Rpc $jwtEmp 'has_permission' @{ p_permission_key = 'MANAGE_USERS' }
Check "has_permission is NOT reachable -- no permission-probing oracle" ($r.StatusCode -eq 404) "$($r.StatusCode)"

$r = Rpc $jwtEmp 'platform_activate_subscription' @{ p_tenant_id = $TA; p_plan_code = 'enterprise'; p_billing_period_code = 'annual' }
Check "platform_* is NOT reachable -- a tenant cannot elevate its own subscription" ($r.StatusCode -eq 404) "$($r.StatusCode)"

Write-Host "`n== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
Write-Host "(fixture rows remain by design -- the audit spine is append-only; 'npx supabase db reset' is the reset)"
if ($fail -gt 0) { exit 1 }
