# ORVION -- the journey branches nobody has walked (Phase C).
#
# `verify_api_end_to_end.ps1` proves the HAPPY PATH: enquiry to cash. A travel agency does not spend
# its day on the happy path. It spends it on the branches -- the cancelled booking, the refund, the
# complaint, the supplier who must be paid, the discount that needs a manager's approval, the
# WhatsApp thread, the follow-up that slipped.
#
# This script walks those branches over HTTP as real JWT-bearing users. Its purpose is to FIND
# BREAKAGE, so a failure here is a result, not a fault: it means an agency would hit that wall on
# day one.
#
# Local development stack only (`iss: supabase-demo` keys on 127.0.0.1). Never point at a project.

$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0; $findings = @()
function Check($name, $condition, $detail = '') {
    if ($condition) { $script:pass++; Write-Host "  ok   $name" -ForegroundColor Green }
    else { $script:fail++; $script:findings += "$name :: $detail"; Write-Host "  FAIL $name  $detail" -ForegroundColor Red }
}

Write-Host "`n== ORVION journey branches over HTTP ==" -ForegroundColor Cyan

$status = (npx supabase status -o json 2>$null) | ConvertFrom-Json
$API = $status.API_URL; $ANON = $status.ANON_KEY; $JWT_SECRET = $status.JWT_SECRET
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
function Psql([string]$sql) { $sql | docker exec -i supabase_db_ORVION psql -U postgres -d postgres -q -t -A -v ON_ERROR_STOP=1 -f - 2>&1 }
function Rpc($jwt, $name, $body) {
    Invoke-WebRequest -Uri "$API/rest/v1/rpc/$name" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" } `
        -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 6 -Compress)
}
function Get-Rest($jwt, $path) {
    Invoke-WebRequest -Uri "$API/rest/v1/$path" -Method Get -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" }
}
function Val($r) { if ($r.StatusCode -lt 300 -and $r.Content) { ($r.Content | ConvertFrom-Json) } else { $null } }
# PostgREST answers a void-returning RPC with 204 No Content. Treating only 200 as success made the
# first run of this script report a working call as a failure -- the script was wrong, not the code.
function Ok($r) { $r.StatusCode -ge 200 -and $r.StatusCode -lt 300 }
function Err($r) { try { ($r.Content | ConvertFrom-Json).message } catch { $r.Content } }

$T = '0b110000-0000-0000-0000-0000000000a0'
$AU_OWNER = '0b110000-0000-0000-0000-0000000000a1'
$AU_EMP = '0b110000-0000-0000-0000-0000000000a2'
$AU_FIN = '0b110000-0000-0000-0000-0000000000a3'

if ((Psql "select count(*) from public.tenants where id='$T';").Trim() -ne '0') {
    Write-Host "  fixture tenant already present -- run 'npx supabase db reset' first" -ForegroundColor Yellow
    exit 1
}

Psql @"
insert into auth.users (id, email) values
  ('$AU_OWNER','owner@br.test'),('$AU_EMP','emp@br.test'),('$AU_FIN','fin@br.test');
insert into public.tenants (id, name, slug, status) values ('$T','Branch Travel','branch-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '$T', sp.id, 'active' from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('0b110000-0000-0000-0000-00000000aa01','$T','Cairo','br-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('0b110000-0000-0000-0000-00000000aa02','$T','0b110000-0000-0000-0000-00000000aa01','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('0b110000-0000-0000-0000-00000000aa03','$T','Br Owner','owner@br.test',true,'$AU_OWNER'),
  ('0b110000-0000-0000-0000-00000000aa04','$T','Br Employee','emp@br.test',true,'$AU_EMP'),
  ('0b110000-0000-0000-0000-00000000aa05','$T','Br Finance','fin@br.test',true,'$AU_FIN');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '$T', u, '0b110000-0000-0000-0000-00000000aa01','0b110000-0000-0000-0000-00000000aa02', true
from unnest(array['0b110000-0000-0000-0000-00000000aa03'::uuid,'0b110000-0000-0000-0000-00000000aa04'::uuid,'0b110000-0000-0000-0000-00000000aa05'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '$T', v.u, r.id, 'tenant' from (values
  ('0b110000-0000-0000-0000-00000000aa03'::uuid,'owner'),
  ('0b110000-0000-0000-0000-00000000aa04'::uuid,'employee'),
  ('0b110000-0000-0000-0000-00000000aa05'::uuid,'finance_manager')) v(u,rc)
join public.roles r on r.code=v.rc;
select 'OK';
"@ | Out-Null

$owner = New-UserJwt $AU_OWNER $true
$emp = New-UserJwt $AU_EMP $false
$fin = New-UserJwt $AU_FIN $true

# Baseline: a customer with a confirmed booking and a paid invoice, built through the API.
$customerId = Val (Rpc $emp 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Sara Kamal'; p_primary_phone = '+201007654321' })
$bookingId = Val (Rpc $emp 'create_booking' @{ p_customer_id = $customerId; p_title = 'Dubai package'; p_branch_id = '0b110000-0000-0000-0000-00000000aa01'; p_department_id = '0b110000-0000-0000-0000-00000000aa02' })
$itemId = Val (Rpc $emp 'create_booking_item' @{ p_booking_id = $bookingId; p_service_type_code = 'hotel'; p_currency_code = 'EGP'; p_cost_amount = 20000; p_selling_amount = 25000 })
$invoiceId = Val (Rpc $owner 'create_invoice' @{ p_customer_id = $customerId; p_currency_code = 'EGP'; p_total_amount = 25000; p_booking_id = $bookingId })
Val (Rpc $owner 'issue_invoice' @{ p_invoice_id = $invoiceId; p_reason = 'issued' }) | Out-Null
$paymentId = Val (Rpc $owner 'record_payment' @{ p_invoice_id = $invoiceId; p_amount = 25000; p_payment_method_code = 'cash' })
Check "BASELINE: booking, item, invoice and payment all exist" ($customerId -and $bookingId -and $itemId -and $invoiceId -and $paymentId) "c=$customerId b=$bookingId i=$itemId inv=$invoiceId p=$paymentId"

# The employee's own financial visibility, measured BEFORE the branches below cancel the item.
# The first run asserted this after the cancellation and read zero rows -- it was measuring the
# cancellation, not the privacy rule.
$r = Get-Rest $emp "booking_item_profit?select=*"
$mine = @(Val $r)
Check "the employee sees their OWN item's profit" ($mine.Count -eq 1) "rows=$($mine.Count)"

# =============================================================================================
# TASKS -- the follow-up an agency actually runs on.
# =============================================================================================
Write-Host "`n-- tasks --"
$r = Rpc $emp 'create_task' @{ p_title = 'Call Sara about visa docs'; p_task_type_code = 'call_customer'; p_owner_user_id = '0b110000-0000-0000-0000-00000000aa04'; p_owner_department_id = '0b110000-0000-0000-0000-00000000aa02'; p_owner_branch_id = '0b110000-0000-0000-0000-00000000aa01' }
Check "employee creates a follow-up task" (Ok $r) "$($r.StatusCode) $(Err $r)"
$taskId = Val $r
if ($taskId) {
    $r = Rpc $emp 'advance_task' @{ p_task_id = $taskId; p_to_status = 'in_progress'; p_reason = 'started' }
    Check "...and moves it to in_progress" (Ok $r) "$($r.StatusCode) $(Err $r)"
    $r = Rpc $emp 'advance_task' @{ p_task_id = $taskId; p_to_status = 'completed'; p_reason = 'customer called' }
    Check "...and completes it" (Ok $r) "$($r.StatusCode) $(Err $r)"
}

# =============================================================================================
# CONVERSATIONS -- WhatsApp is how Egyptian agencies actually talk to customers.
# =============================================================================================
Write-Host "`n-- conversations --"
$r = Rpc $emp 'start_conversation' @{ p_channel_code = 'whatsapp'; p_customer_id = $customerId; p_booking_id = $bookingId }
Check "employee starts a WhatsApp conversation" (Ok $r) "$($r.StatusCode) $(Err $r)"
$convId = Val $r
if ($convId) {
    $r = Rpc $emp 'send_conversation_message' @{ p_conversation_id = $convId; p_message_direction_code = 'outbound'; p_sender_type_code = 'user'; p_body = 'Your voucher is attached.' }
    Check "...and sends a message" (Ok $r) "$($r.StatusCode) $(Err $r)"
}

# =============================================================================================
# DOCUMENT VERSIONING -- the customer sends a corrected passport scan.
# =============================================================================================
Write-Host "`n-- document versioning --"
# The first run linked a passport to a BOOKING and was refused: "passport documents are stored at
# passenger level". That is a correct domain rule doing its job, so the fixture was corrected rather
# than the rule -- a passport belongs to a person, not to an itinerary.
$paxId = Val (Rpc $emp 'create_passenger' @{ p_first_name = 'Sara'; p_family_name = 'Kamal'; p_passenger_type_code = 'adult'; p_customer_id = $customerId })
Check "employee registers the passenger the passport belongs to" ([bool]$paxId) "pax=$paxId"
$r = Rpc $emp 'upload_document' @{ p_document_type_code = 'passport'; p_title = 'Sara passport'; p_file_name = 'p1.pdf'; p_file_type_code = 'pdf'; p_link_target_type = 'passenger'; p_link_target_id = $paxId }
Check "employee uploads a document" (Ok $r) "$($r.StatusCode) $(Err $r)"
$docId = Val $r
if ($docId) {
    $r = Rpc $emp 'add_document_version' @{ p_document_id = $docId; p_file_name = 'p2.pdf'; p_file_type_code = 'pdf' }
    Check "...and adds a corrected version" (Ok $r) "$($r.StatusCode) $(Err $r)"
    $cur = (Psql "select version_number from public.document_versions dv join public.documents d on d.current_version_id=dv.id where d.id='$docId';").Trim()
    Check "...and version 2 becomes current" ($cur -eq '2') "current=$cur"
}

# =============================================================================================
# COMPLAINT and SERVICE REQUEST -- after-sales, which is where retention is won or lost.
# =============================================================================================
Write-Host "`n-- after-sales --"
$r = Rpc $emp 'create_complaint' @{ p_customer_id = $customerId; p_title = 'Hotel room not as described'; p_complaint_category_code = 'service_quality'; p_complaint_severity_code = 'high'; p_description = 'Customer unhappy'; p_booking_id = $bookingId }
Check "employee logs a complaint" (Ok $r) "$($r.StatusCode) $(Err $r)"
$complaintId = Val $r
if ($complaintId) {
    $r = Rpc $emp 'advance_complaint' @{ p_complaint_id = $complaintId; p_to_status = 'acknowledged'; p_reason = 'called customer' }
    Check "...and acknowledges it" (Ok $r) "$($r.StatusCode) $(Err $r)"
}

$r = Rpc $emp 'create_service_request' @{ p_customer_id = $customerId; p_title = 'Add extra night'; p_service_request_type_code = 'hotel_change'; p_service_request_severity_code = 'normal'; p_description = 'Customer wants +1 night'; p_booking_id = $bookingId }
Check "employee raises a service request" (Ok $r) "$($r.StatusCode) $(Err $r)"

# =============================================================================================
# SUPPLIER SIDE -- the agency owes the hotel.
# =============================================================================================
Write-Host "`n-- supplier --"
$r = Rpc $owner 'create_supplier' @{ p_name = 'Dubai Hotels LLC'; p_supplier_type_code = 'hotel' }
Check "a supplier is created" (Ok $r) "$($r.StatusCode) $(Err $r)"
$supplierId = Val $r
if ($supplierId) {
    $r = Rpc $fin 'record_supplier_payment' @{ p_supplier_id = $supplierId; p_amount = 20000; p_currency_code = 'EGP'; p_payment_method_code = 'bank_transfer'; p_booking_id = $bookingId }
    Check "finance records the supplier payment" (Ok $r) "$($r.StatusCode) $(Err $r)"
    $r = Rpc $emp 'record_supplier_payment' @{ p_supplier_id = $supplierId; p_amount = 1; p_currency_code = 'EGP'; p_payment_method_code = 'cash' }
    Check "...and an EMPLOYEE cannot -- supplier money is finance's" ($r.StatusCode -ge 400) "$($r.StatusCode) $(Err $r)"
}

# =============================================================================================
# FINANCE APPROVAL -- the discount that needs a manager.
# =============================================================================================
Write-Host "`n-- finance approval --"
$r = Rpc $emp 'request_finance_approval' @{ p_booking_item_id = $itemId; p_reason = 'customer wants 10% discount' }
Check "employee requests finance approval" (Ok $r) "$($r.StatusCode) $(Err $r)"
$approvalId = Val $r
if ($approvalId) {
    $r = Rpc $emp 'review_finance_approval' @{ p_approval_request_id = $approvalId; p_decision = 'approved'; p_reason = 'self-approve' }
    Check "...and CANNOT approve their own request" ($r.StatusCode -ge 400) "$($r.StatusCode) $(Err $r)"
    $r = Rpc $fin 'review_finance_approval' @{ p_approval_request_id = $approvalId; p_decision = 'approved'; p_reason = 'agreed' }
    Check "...while finance CAN -- the positive control" (Ok $r) "$($r.StatusCode) $(Err $r)"
}

# =============================================================================================
# REFUND and CANCELLATION -- the branch the happy path never touches.
# =============================================================================================
Write-Host "`n-- refund and cancellation --"
$r = Rpc $fin 'record_refund' @{ p_customer_id = $customerId; p_amount = 5000; p_currency_code = 'EGP'; p_refund_reason_code = 'customer_cancelled'; p_booking_id = $bookingId; p_original_payment_id = $paymentId }
Check "finance records a partial refund" (Ok $r) "$($r.StatusCode) $(Err $r)"
$refundId = Val $r
if ($refundId) {
    $r = Rpc $fin 'advance_refund' @{ p_refund_id = $refundId; p_to_status = 'approved'; p_reason = 'agreed with customer' }
    Check "...and advances it" (Ok $r) "$($r.StatusCode) $(Err $r)"
}

$r = Rpc $emp 'advance_booking_item' @{ p_booking_item_id = $itemId; p_to_status = 'cancelled'; p_reason = 'customer cancelled'; p_cancellation_reason_code = 'customer_cancelled' }
Check "the booking item is cancelled" (Ok $r) "$($r.StatusCode) $(Err $r)"

# THE QUESTION THAT MATTERS: does a cancelled item still pay commission?
$r = Get-Rest $emp "my_sales_performance?select=*"
$perf = @(Val $r)
Check "a CANCELLED item leaves the employee's performance report" ($perf.Count -eq 0) "rows=$($perf.Count)"

# =============================================================================================
# FINANCIAL PRIVACY -- the rule that must survive every branch above.
# =============================================================================================
Write-Host "`n-- financial privacy --"
# The first run asserted the employee sees ZERO rows in booking_item_profit. That was wrong: the view
# is security_invoker over booking_items, so it is RLS-scoped and the employee SHOULD see their own
# item's profit -- SPEC-139 grants exactly that. The question worth asking is the colleague one.
# A second employee, same branch, same department, with their own booking item. Neither may see the
# other's money. This is the rule that must survive every branch walked above.
$colleagueItem = (Psql @"
insert into auth.users (id, email) values ('0b110000-0000-0000-0000-0000000000a4','emp2@br.test') on conflict do nothing;
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('0b110000-0000-0000-0000-00000000aa06','$T','Br Employee Two','emp2@br.test',true,'0b110000-0000-0000-0000-0000000000a4') on conflict do nothing;
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
values ('$T','0b110000-0000-0000-0000-00000000aa06','0b110000-0000-0000-0000-00000000aa01','0b110000-0000-0000-0000-00000000aa02',true) on conflict do nothing;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '$T','0b110000-0000-0000-0000-00000000aa06', r.id,'tenant' from public.roles r where r.code='employee';
select 'OK';
"@)
$emp2 = New-UserJwt '0b110000-0000-0000-0000-0000000000a4' $false
$r = Get-Rest $emp2 "booking_item_profit?select=*"
$theirs = @(Val $r)
Check "a COLLEAGUE sees none of it -- financial privacy holds across the branch" ($theirs.Count -eq 0) "rows=$($theirs.Count)"

$r = Get-Rest $emp2 "my_sales_performance?select=*"
$theirPerf = @(Val $r)
Check "...and their personal report is empty, not the other employee's" ($theirPerf.Count -eq 0) "rows=$($theirPerf.Count)"

# ---------------------------------------------------------------------------------------------
# API-3 / FIN-8 -- the general ledger over HTTP.
# `create_journal_entry` had NO HTTP evidence at all, and auditing it found FIN-8: the double-entry
# invariant lived only inside the RPC, so a CREATE_JOURNAL_ENTRY holder could INSERT an unbalanced
# entry through the PostgREST TABLE endpoint. PostgREST serves tables, and each request is its own
# transaction -- so the deferred balance constraint now fires on that request's COMMIT, which is
# what makes the table endpoint safe rather than merely discouraged.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- the general ledger (API-3 / FIN-8) --"

# Seeded through the RPC as finance, deliberately: calling it via psql runs as `postgres`, where
# app.current_tenant_id() is null and the seed lands nowhere -- which is how the first run of this
# block failed with "unknown or inactive chart account code: 1000" while looking like a real defect.
$r = Rpc $fin 'seed_default_chart_of_accounts' @{}
Check "finance seeds the tenant's chart of accounts over HTTP" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'create_journal_entry' @{ p_source_type_code = 'manual_entry'; p_entry_date = '2026-08-29'; p_description = 'employee attempt'
                                        p_lines = @(@{account_code='1000';debit=100;currency='EGP'}, @{account_code='4000';credit=100;currency='EGP'}) }
Check "an employee CANNOT post to the general ledger over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $fin 'create_journal_entry' @{ p_source_type_code = 'manual_entry'; p_entry_date = '2026-08-29'; p_description = 'http balanced'
                                        p_lines = @(@{account_code='1000';debit=2500;currency='EGP'}, @{account_code='4000';credit=2500;currency='EGP'}) }
Check "POSITIVE CONTROL: finance posts a BALANCED entry over HTTP -- create_journal_entry's first HTTP evidence (API-3)" (Ok $r) "$($r.StatusCode) $(Err $r)"
$jeId = (Val $r)

$lineSum = (Psql "select coalesce(sum(debit_amount),0)::text || '/' || coalesce(sum(credit_amount),0)::text || '/' || count(*)::text from public.journal_entry_lines where journal_entry_id='$jeId';").Trim()
Check "...and it really landed: two lines, debits = credits" ($lineSum -eq '2500.0000/2500.0000/2') "sum=$lineSum"

$evt = (Psql "select count(*) from public.events where entity_id='$jeId' and event_type_code='journal_entry_created';").Trim()
Check "...and the audit spine recorded it" ($evt -eq '1') "events=$evt"

$r = Rpc $fin 'create_journal_entry' @{ p_source_type_code = 'manual_entry'; p_entry_date = '2026-08-29'; p_description = 'http unbalanced'
                                        p_lines = @(@{account_code='1000';debit=2500;currency='EGP'}, @{account_code='4000';credit=1;currency='EGP'}) }
Check "an UNBALANCED entry is refused over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

# FIN-8's real attack shape: the TABLE endpoint, not the RPC. One request = one transaction, so the
# entry row commits alone with zero lines and the deferred constraint fires.
$r = Invoke-WebRequest -Uri "$API/rest/v1/journal_entries" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $fin" } -ContentType 'application/json' `
        -Body "{""tenant_id"":""$T"",""source_type_code"":""manual_entry"",""entry_date"":""2026-08-29"",""description"":""forged""}"
Check "FIN-8 CLOSED: a bare journal_entries row via PATCH/POST on the TABLE endpoint is refused -- an entry with no lines is not an entry" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$orphans = (Psql "select count(*) from public.journal_entries je where je.tenant_id='$T' and (select count(*) from public.journal_entry_lines l where l.journal_entry_id=je.id) < 2;").Trim()
Check "NON-MUTATION: no entry in this tenant has fewer than two lines" ($orphans -eq '0') "bad_entries=$orphans"


# =================================================================================================
# BOOK-1 -- a closed booking cannot earn new revenue, proven over the wire.
#
# The three booking/passenger endpoints ALREADY had HTTP evidence, and still hid this: the RPC
# refused, the TABLE endpoint did not. That is the whole reason API-3 audits capability rather than
# status codes. PostgREST serves `POST /rest/v1/booking_items` as readily as `rpc/create_booking_item`,
# and one request is one transaction -- so this is the real attack shape, not a contrived one.
# =================================================================================================
$closingId = Val (Rpc $emp 'create_booking' @{ p_customer_id = $customerId; p_title = 'Cancelled trip'
                                               p_branch_id = '0b110000-0000-0000-0000-00000000aa01'
                                               p_department_id = '0b110000-0000-0000-0000-00000000aa02' })
$r = Rpc $emp 'advance_booking' @{ p_booking_id = $closingId; p_to_status = 'pending_approval'; p_reason = 'submit' }
$r = Rpc $emp 'advance_booking' @{ p_booking_id = $closingId; p_to_status = 'cancelled'; p_reason = 'customer withdrew' }
Check "a booking is cancelled over HTTP -- advance_booking's branch path" (Ok $r) "$($r.StatusCode) $(Err $r)"

$state = (Psql "select booking_status_code from public.bookings where id='$closingId';").Trim()
Check "POSITIVE CONTROL: it really is cancelled, so the refusals below are the lifecycle rule" ($state -eq 'cancelled') "status=$state"

$r = Rpc $emp 'create_booking_item' @{ p_booking_id = $closingId; p_service_type_code = 'hotel'
                                       p_currency_code = 'EGP'; p_cost_amount = 3000; p_selling_amount = 5000 }
Check "the RPC refuses an item on a cancelled booking over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

# The attack: the same insert through the TABLE endpoint, which charges no capability when it names
# itself as owner, and which used to succeed -- selling 5000 with commission_rate derived at 0.10.
$body = "{""tenant_id"":""$T"",""booking_id"":""$closingId"",""service_type_code"":""hotel""," +
        """base_status_code"":""draft"",""currency_code"":""EGP"",""cost_amount"":3000,""selling_amount"":5000," +
        """owner_user_id"":""0b110000-0000-0000-0000-00000000aa04""," +
        """sales_owner_user_id"":""0b110000-0000-0000-0000-00000000aa04""," +
        """operational_owner_user_id"":""0b110000-0000-0000-0000-00000000aa04""," +
        """owner_branch_id"":""0b110000-0000-0000-0000-00000000aa01""," +
        """owner_department_id"":""0b110000-0000-0000-0000-00000000aa02""}"
$r = Invoke-WebRequest -Uri "$API/rest/v1/booking_items" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $emp" } -ContentType 'application/json' -Body $body
Check "BOOK-1 CLOSED: the TABLE endpoint is refused too -- 5000 of selling on a cancelled booking was the original reproduction" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$leaked = (Psql "select count(*) from public.booking_items where booking_id='$closingId';").Trim()
Check "NON-MUTATION: the cancelled booking carries zero items after both refusals" ($leaked -eq '0') "items=$leaked"

# And the passenger half. NOT on $itemId: the refund branch above cancels that item, so linking to
# it is refused for the RIGHT reason and a "positive control" pointing at it proves nothing. Found by
# this assertion failing with `cannot add a passenger to a cancelled booking item` -- the control was
# not positive. A fresh OPEN booking and item is what makes the next line evidence.
$openBk = Val (Rpc $emp 'create_booking' @{ p_customer_id = $customerId; p_title = 'Open trip'
                                            p_branch_id = '0b110000-0000-0000-0000-00000000aa01'
                                            p_department_id = '0b110000-0000-0000-0000-00000000aa02' })
$openItem = Val (Rpc $emp 'create_booking_item' @{ p_booking_id = $openBk; p_service_type_code = 'hotel'
                                                   p_currency_code = 'EGP'; p_cost_amount = 1000; p_selling_amount = 1500 })
$r = Rpc $emp 'link_passenger_to_booking_item' @{ p_booking_item_id = $openItem; p_passenger_id = $paxId }
Check "POSITIVE CONTROL: a passenger still links to an item on an OPEN booking -- link_passenger_to_booking_item over HTTP" (Ok $r) "$($r.StatusCode) $(Err $r)"

$linked = (Psql "select count(*) from public.booking_item_passengers where booking_item_id='$openItem';").Trim()
Check "...and it actually wrote the link row -- a 2xx alone would not prove a row exists" ($linked -ne '0') "links=$linked"

# The item-level half of BOOK-1, which is a different rule from the booking-level half above.
$r = Rpc $emp 'link_passenger_to_booking_item' @{ p_booking_item_id = $itemId; p_passenger_id = $paxId }
Check "and a passenger is refused on the CANCELLED item from the refund branch -- the item-level rule, distinct from the booking-level one" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"


Write-Host "`n== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($findings.Count -gt 0) { Write-Host "`nFindings:"; $findings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow } }
if ($fail -gt 0) { exit 1 }
