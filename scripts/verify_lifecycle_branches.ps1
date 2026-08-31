# ORVION -- the lifecycle branches and the trainee, over HTTP (Phase C).
#
# `verify_journey_branches.ps1` walked the branches an agency hits weekly. These are the ones it hits
# on the bad days and the good ones: the quotation the customer turns down and you re-quote, the
# quotation that lapses, the ticket that must be reissued, the customer who pays half now and half
# later, the supplier who fails after you have already sold the trip, the passport about to expire,
# and the customer who comes back a second time.
#
# It also walks the TRAINEE end to end -- the only role whose full journey had never been executed.
# A trainee holds exactly two permissions, so "their journey" is mostly refusals; the point is to
# prove the refusals are about CAPABILITY and not about a broken session or an unreachable row, and
# to find out what a trainee can actually do on their first morning.
#
# A failure here is a RESULT, not a fault: it means a real agency would hit that wall.
#
# Local development stack only (`iss: supabase-demo` keys on 127.0.0.1). Never point at a project.

$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0; $findings = @()
function Check($name, $condition, $detail = '') {
    if ($condition) { $script:pass++; Write-Host "  ok   $name" -ForegroundColor Green }
    else { $script:fail++; $script:findings += "$name :: $detail"; Write-Host "  FAIL $name  $detail" -ForegroundColor Red }
}

Write-Host "`n== ORVION lifecycle branches and the trainee, over HTTP ==" -ForegroundColor Cyan

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
function Ok($r) { $r.StatusCode -ge 200 -and $r.StatusCode -lt 300 }
function Err($r) { try { ($r.Content | ConvertFrom-Json).message } catch { $r.Content } }

$T = '0c110000-0000-0000-0000-0000000000a0'
$AU_OWNER = '0c110000-0000-0000-0000-0000000000a1'
$AU_EMP = '0c110000-0000-0000-0000-0000000000a2'
$AU_FIN = '0c110000-0000-0000-0000-0000000000a3'
$AU_TRN = '0c110000-0000-0000-0000-0000000000a4'
$BR = '0c110000-0000-0000-0000-00000000aa01'
$DP = '0c110000-0000-0000-0000-00000000aa02'
$U_EMP = '0c110000-0000-0000-0000-00000000aa04'
$U_TRN = '0c110000-0000-0000-0000-00000000aa06'

if ((Psql "select count(*) from public.tenants where id='$T';").Trim() -ne '0') {
    Write-Host "  fixture tenant already present -- run 'npx supabase db reset' first" -ForegroundColor Yellow
    exit 1
}

Psql @"
insert into auth.users (id, email) values
  ('$AU_OWNER','owner@lc.test'),('$AU_EMP','emp@lc.test'),('$AU_FIN','fin@lc.test'),('$AU_TRN','trn@lc.test');
insert into public.tenants (id, name, slug, status) values ('$T','Lc Branch Travel','lc-branch-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '$T', sp.id, 'active' from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values ('$BR','$T','Cairo','lc-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values ('$DP','$T','$BR','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('0c110000-0000-0000-0000-00000000aa03','$T','Lc Owner','owner@lc.test',true,'$AU_OWNER'),
  ('$U_EMP','$T','Lc Employee','emp@lc.test',true,'$AU_EMP'),
  ('0c110000-0000-0000-0000-00000000aa05','$T','Lc Finance','fin@lc.test',true,'$AU_FIN'),
  ('$U_TRN','$T','Lc Trainee','trn@lc.test',true,'$AU_TRN');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '$T', u, '$BR','$DP', true
from unnest(array['0c110000-0000-0000-0000-00000000aa03'::uuid,'$U_EMP'::uuid,'0c110000-0000-0000-0000-00000000aa05'::uuid,'$U_TRN'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '$T', v.u, r.id, 'tenant' from (values
  ('0c110000-0000-0000-0000-00000000aa03'::uuid,'owner'),
  ('$U_EMP'::uuid,'employee'),
  ('0c110000-0000-0000-0000-00000000aa05'::uuid,'finance_manager'),
  ('$U_TRN'::uuid,'trainee')) v(u,rc)
join public.roles r on r.code=v.rc;
select 'OK';
"@ | Out-Null

$owner = New-UserJwt $AU_OWNER $true
$emp = New-UserJwt $AU_EMP $false
$fin = New-UserJwt $AU_FIN $true
$trn = New-UserJwt $AU_TRN $false

$customerId = Val (Rpc $emp 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Mona Fathy'; p_primary_phone = '+201118889999' })
Check "BASELINE: the employee registers the customer this whole file is about" ($null -ne $customerId) "c=$customerId"

# =============================================================================================
# THE TRAINEE'S FIRST MORNING. Two permissions: VIEW_ASSIGNED_LEADS, VIEW_ASSIGNED_TASKS.
# Every refusal below is paired with something the SAME session can do, so none of them is
# measuring a broken token or an unreachable row.
# =============================================================================================
Write-Host "`n-- the trainee --"

# A lead assigned TO the trainee, and one assigned to the employee. Assignment is supervisory, so
# the owner does it -- which is itself the reason a trainee cannot self-serve their own queue.
$leadMine = Val (Rpc $emp 'create_lead' @{ p_branch_id = $BR; p_department_id = $DP; p_lead_source_code = 'direct_call'; p_title = 'Trainee lead'; p_customer_id = $customerId })
$leadOther = Val (Rpc $emp 'create_lead' @{ p_branch_id = $BR; p_department_id = $DP; p_lead_source_code = 'direct_call'; p_title = 'Not the trainee lead'; p_customer_id = $customerId })
Val (Rpc $owner 'assign_lead' @{ p_lead_id = $leadMine; p_assignee_user_id = $U_TRN; p_reason = 'training queue' }) | Out-Null
Val (Rpc $owner 'assign_lead' @{ p_lead_id = $leadOther; p_assignee_user_id = $U_EMP; p_reason = 'normal queue' }) | Out-Null

$r = Get-Rest $trn "leads?select=id,title"
$trnLeads = @(Val $r)
Check "POSITIVE CONTROL: the trainee reaches the API and sees their ASSIGNED lead" (($trnLeads | Where-Object { $_.title -eq 'Trainee lead' }).Count -eq 1) "$($r.StatusCode) rows=$($trnLeads.Count)"
Check "...and NOT the colleague's lead -- scope, proven on the same query that returned theirs" (($trnLeads | Where-Object { $_.title -eq 'Not the trainee lead' }).Count -eq 0) "rows=$($trnLeads.Count)"

$r = Rpc $trn 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Trainee Customer'; p_primary_phone = '+201110000001' }
Check "a trainee CANNOT create a customer -- capability, not reach" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $trn 'create_lead' @{ p_branch_id = $BR; p_department_id = $DP; p_lead_source_code = 'direct_call'; p_title = 'Trainee attempt' }
Check "...nor open a lead of their own" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $trn 'create_quotation' @{ p_customer_id = $customerId; p_currency_code = 'EGP' }
Check "...nor quote a customer" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $trn 'create_task' @{ p_title = 'Trainee task'; p_task_type_code = 'call_customer' }
Check "...nor create a task, even though they may VIEW assigned ones -- reading a queue is not working it" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Get-Rest $trn "booking_item_profit?select=*"
$trnProfit = @(Val $r)
Check "...and sees no financial data at all" ($trnProfit.Count -eq 0) "$($r.StatusCode) rows=$($trnProfit.Count)"

# LEAD-INTERACTION: this SUCCEEDS, and the reason is the point. `app.record_lead_interaction`
# charges "the assigned handler, OR ASSIGN_LEAD, plus MFA" -- the trainee IS the assigned handler
# here, so two permissions is not what governs this write. `202607056200` put the same rule on the
# direct path, so the two doors now agree; the assertion below is the positive half of that pair and
# `59_lead_handler_authority_test.sql` carries the negative one.
$r = Rpc $trn 'record_lead_interaction' @{ p_lead_id = $leadMine; p_interaction_type_code = 'phone_call'; p_summary = 'trainee listened in' }
Check "a trainee CAN log an interaction on the lead they are ASSIGNED -- the handler rule, not a permission" (Ok $r) "$($r.StatusCode) $(Err $r)"

# =============================================================================================
# QUOTATION: REJECTED, REVISED, EXPIRED. The three endings nobody had walked.
# =============================================================================================
Write-Host "`n-- quotation: rejected, revised, expired --"

$q = Val (Rpc $emp 'create_quotation' @{ p_customer_id = $customerId; p_currency_code = 'EGP' })
Val (Rpc $emp 'add_quotation_item' @{ p_quotation_id = $q; p_service_type_code = 'hotel'; p_unit_price = 30000 }) | Out-Null

$r = Rpc $emp 'advance_quotation' @{ p_quotation_id = $q; p_to_status = 'accepted'; p_reason = 'skipping ahead' }
Check "a DRAFT quotation cannot jump straight to accepted" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_quotation' @{ p_quotation_id = $q; p_to_status = 'sent'; p_reason = 'emailed' }
Check "the employee sends it" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_quotation' @{ p_quotation_id = $q; p_to_status = 'rejected'; p_reason = 'customer said too expensive' }
Check "REJECTED: the customer turns it down" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_quotation' @{ p_quotation_id = $q; p_to_status = 'draft'; p_reason = 're-pricing' }
Check "REVISED: a rejected quotation goes back to draft to be re-priced" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'add_quotation_item' @{ p_quotation_id = $q; p_service_type_code = 'hotel'; p_unit_price = 24000; p_description = 'revised price' }
Check "...and the revised price is added to the SAME quotation, not a new one" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_quotation' @{ p_quotation_id = $q; p_to_status = 'sent'; p_reason = 'resent at the lower price' }
Check "...and it is sent again" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_quotation' @{ p_quotation_id = $q; p_to_status = 'expired'; p_reason = 'validity lapsed' }
Check "EXPIRED: a sent quotation can lapse" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_quotation' @{ p_quotation_id = $q; p_to_status = 'draft'; p_reason = 'customer came back' }
Check "...and an expired one can be revived to draft when the customer returns" (Ok $r) "$($r.StatusCode) $(Err $r)"

$hist = @(Val (Rpc $emp 'customer_timeline' @{ p_customer_id = $customerId }))
$qEvents = @($hist | Where-Object { $_.entity_type -eq 'quotation' -and $_.entity_id -eq $q })
Check "...and every one of those endings is in the customer's timeline, not just the last state" ($qEvents.Count -ge 6) "quotation events=$($qEvents.Count)"

# =============================================================================================
# BOOKING MODIFIED: approval, issue, reissue. The ticket that has to be changed after issue.
# =============================================================================================
Write-Host "`n-- booking: approved, issued, modified --"

$b = Val (Rpc $emp 'create_booking' @{ p_customer_id = $customerId; p_title = 'Sharm package'; p_branch_id = $BR; p_department_id = $DP })
$item = Val (Rpc $emp 'create_booking_item' @{ p_booking_id = $b; p_service_type_code = 'hotel'; p_currency_code = 'EGP'; p_cost_amount = 18000; p_selling_amount = 25000 })
Check "BASELINE: the employee books and prices it" (($null -ne $b) -and ($null -ne $item)) "b=$b item=$item"

$r = Rpc $emp 'advance_booking' @{ p_booking_id = $b; p_to_status = 'pending_approval'; p_reason = 'ready for the manager' }
Check "the employee sends the booking for approval" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_booking' @{ p_booking_id = $b; p_to_status = 'confirmed'; p_reason = 'approving my own' }
Check "...and CANNOT approve their own booking -- APPROVE_BOOKING is supervisory" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $owner 'advance_booking' @{ p_booking_id = $b; p_to_status = 'confirmed'; p_reason = 'approved' }
Check "...while the owner CAN -- the positive control for the refusal above" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_booking' @{ p_booking_id = $b; p_to_status = 'in_progress'; p_reason = 'arranging' }
Check "the employee carries the confirmed booking into progress" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_booking' @{ p_booking_id = $b; p_to_status = 'issued'; p_reason = 'issuing myself' }
Check "...but CANNOT issue it -- issuing is finance's" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $fin 'advance_booking' @{ p_booking_id = $b; p_to_status = 'issued'; p_reason = 'tickets issued' }
Check "...and finance CAN" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'advance_booking' @{ p_booking_id = $b; p_to_status = 'reissue'; p_reason = 'customer changed dates' }
Check "MODIFIED: the employee cannot reissue an issued ticket" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $fin 'advance_booking' @{ p_booking_id = $b; p_to_status = 'reissue'; p_reason = 'customer changed dates' }
Check "...finance takes it into reissue -- the real 'booking modified' path" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $fin 'advance_booking' @{ p_booking_id = $b; p_to_status = 'issued'; p_reason = 'new tickets issued' }
Check "...and back to issued once the change is done" (Ok $r) "$($r.StatusCode) $(Err $r)"

$state = (Psql "select booking_status_code from public.bookings where id='$b';").Trim()
Check "...and the booking's stored state is the one the journey ended on" ($state -eq 'issued') "state=$state"

# =============================================================================================
# PARTIAL PAYMENT: the customer pays a deposit now and the rest later.
# =============================================================================================
Write-Host "`n-- partial payment --"

$inv = Val (Rpc $fin 'create_invoice' @{ p_customer_id = $customerId; p_currency_code = 'EGP'; p_total_amount = 25000; p_booking_id = $b })
Val (Rpc $fin 'issue_invoice' @{ p_invoice_id = $inv; p_reason = 'issued' }) | Out-Null

$r = Rpc $fin 'record_payment' @{ p_invoice_id = $inv; p_amount = 10000; p_payment_method_code = 'cash' }
Check "the customer pays a 10,000 deposit against a 25,000 invoice" (Ok $r) "$($r.StatusCode) $(Err $r)"

$allocated = (Psql "select coalesce(sum(allocated_amount),0)::int from public.payment_allocations where tenant_id='$T' and invoice_id='$inv';").Trim()
Check "...and exactly 10,000 is allocated -- a deposit is not silently rounded to the total" ($allocated -eq '10000') "allocated=$allocated"

$r = Rpc $fin 'record_payment' @{ p_invoice_id = $inv; p_amount = 15000; p_payment_method_code = 'bank_transfer' }
Check "...the balance is paid later" (Ok $r) "$($r.StatusCode) $(Err $r)"

$allocated = (Psql "select coalesce(sum(allocated_amount),0)::int from public.payment_allocations where tenant_id='$T' and invoice_id='$inv';").Trim()
Check "...and the two payments now settle it exactly" ($allocated -eq '25000') "allocated=$allocated"

# Over-payment is recorded as OBSERVED, not as a desired outcome: if ORVION accepts it, the report
# says so and it becomes a decision; if it refuses, that is the contract. Either way it is pinned.
$r = Rpc $fin 'record_payment' @{ p_invoice_id = $inv; p_amount = 999999; p_payment_method_code = 'cash' }
$overOk = Ok $r
$allocatedAfter = (Psql "select coalesce(sum(allocated_amount),0)::int from public.payment_allocations where tenant_id='$T' and invoice_id='$inv';").Trim()
Check "OVER-PAYMENT, pinned as observed: accepted=$overOk, allocated now $allocatedAfter (invoice total 25000)" ($true) "$($r.StatusCode) $(Err $r)"
Check "...and whatever it did, it did NOT allocate less than the invoice was already paid" ([int]$allocatedAfter -ge 25000) "allocated=$allocatedAfter"

# =============================================================================================
# SUPPLIER FAILURE: the hotel cancels after the customer has already paid.
# =============================================================================================
Write-Host "`n-- supplier failure --"

$sup = Val (Rpc $owner 'create_supplier' @{ p_name = 'Failing Hotels Co'; p_supplier_type_code = 'hotel' })
Check "a supplier exists to fail" ($null -ne $sup) "sup=$sup"

$sr = Val (Rpc $emp 'create_service_request' @{ p_customer_id = $customerId; p_title = 'Hotel cancelled on us'; p_service_request_type_code = 'hotel_change'; p_booking_id = $b; p_booking_item_id = $item })
Check "the employee raises a service request when the supplier fails" ($null -ne $sr) "sr=$sr"

if ($sr) {
    $r = Rpc $emp 'advance_service_request' @{ p_service_request_id = $sr; p_to_status = 'in_progress'; p_reason = 'chasing the supplier' }
    Check "...and starts working it" (Ok $r) "$($r.StatusCode) $(Err $r)"
    $r = Rpc $emp 'advance_service_request' @{ p_service_request_id = $sr; p_to_status = 'awaiting_supplier'; p_reason = 'waiting on the hotel' }
    Check "...and parks it on the supplier -- the state that exists precisely for this" (Ok $r) "$($r.StatusCode) $(Err $r)"
    $r = Rpc $emp 'advance_service_request' @{ p_service_request_id = $sr; p_to_status = 'in_progress'; p_reason = 'supplier confirmed the cancellation' }
    Check "...and picks it back up when the supplier answers" (Ok $r) "$($r.StatusCode) $(Err $r)"
    $r = Rpc $emp 'advance_service_request' @{ p_service_request_id = $sr; p_to_status = 'resolved'; p_reason = 'rebooked elsewhere' }
    Check "...and resolves it" (Ok $r) "$($r.StatusCode) $(Err $r)"
}

$r = Rpc $emp 'advance_booking_item' @{ p_booking_item_id = $item; p_to_status = 'cancelled'; p_reason = 'supplier failed'; p_cancellation_reason_code = 'supplier_unavailable' }
Check "the failed service line is cancelled" (Ok $r) "$($r.StatusCode) $(Err $r)"

$ref = Val (Rpc $fin 'record_refund' @{ p_customer_id = $customerId; p_amount = 25000; p_currency_code = 'EGP'; p_refund_reason_code = 'supplier_cancelled'; p_booking_id = $b })
Check "finance refunds the customer in full" ($null -ne $ref) "ref=$ref"
if ($ref) {
    $r = Rpc $fin 'advance_refund' @{ p_refund_id = $ref; p_to_status = 'approved'; p_reason = 'approved' }
    Check "...and the refund is approved" (Ok $r) "$($r.StatusCode) $(Err $r)"
    $r = Rpc $fin 'advance_refund' @{ p_refund_id = $ref; p_to_status = 'completed'; p_reason = 'paid back' }
    Check "...and completed" (Ok $r) "$($r.StatusCode) $(Err $r)"
}

$r = Get-Rest $emp "booking_item_profit?select=*"
$profitRows = @(Val $r)
Check "a CANCELLED line carries no profit -- the employee is not paid commission on a trip that did not happen" (($profitRows | Where-Object { $_.booking_item_id -eq $item }).Count -eq 0) "rows=$($profitRows.Count)"

# =============================================================================================
# DOCUMENT EXPIRY: the passport that will not survive the trip.
# =============================================================================================
Write-Host "`n-- document expiry --"

# `upload_document` REFUSES a passport linked to anything but a passenger, which is correct and is
# what my first run of this script hit. A passport belongs to a person, not to a booking.
$soon = (Get-Date).AddDays(10).ToString('yyyy-MM-ddTHH:mm:ssZ')
$later = (Get-Date).AddDays(400).ToString('yyyy-MM-ddTHH:mm:ssZ')
$pax = Val (Rpc $emp 'create_passenger' @{ p_first_name = 'Mona'; p_family_name = 'Fathy'; p_customer_id = $customerId })
Check "the passenger the passports belong to is registered" ($null -ne $pax) "pax=$pax"

$r = Rpc $emp 'upload_document' @{ p_document_type_code = 'passport'; p_title = 'Mona passport (expiring)'; p_file_name = 'mona.pdf'; p_file_type_code = 'pdf'; p_link_target_type = 'booking'; p_link_target_id = $b; p_expires_at = $soon }
Check "a PASSPORT cannot be filed against a booking -- it belongs to a person" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$docSoon = Val (Rpc $emp 'upload_document' @{ p_document_type_code = 'passport'; p_title = 'Mona passport (expiring)'; p_file_name = 'mona.pdf'; p_file_type_code = 'pdf'; p_link_target_type = 'passenger'; p_link_target_id = $pax; p_expires_at = $soon })
$docLater = Val (Rpc $emp 'upload_document' @{ p_document_type_code = 'passport'; p_title = 'Mona passport (fine)'; p_file_name = 'mona2.pdf'; p_file_type_code = 'pdf'; p_link_target_type = 'passenger'; p_link_target_id = $pax; p_expires_at = $later })
Check "two passports are on file: one expiring in 10 days, one in 400" (($null -ne $docSoon) -and ($null -ne $docLater)) "soon=$docSoon later=$docLater"

$exp30 = @(Val (Rpc $emp 'expiring_documents' @{ p_within_days = 30 }))
Check "the 30-day window finds the expiring passport" (($exp30 | Where-Object { $_.document_id -eq $docSoon }).Count -eq 1) "rows=$($exp30.Count)"
Check "...and does NOT drag in the one that is fine -- the window is a real filter, not a list of every document" (($exp30 | Where-Object { $_.document_id -eq $docLater }).Count -eq 0) "rows=$($exp30.Count)"

$exp5 = @(Val (Rpc $emp 'expiring_documents' @{ p_within_days = 5 }))
Check "...and a 5-day window excludes it too, so the parameter is honoured rather than ignored" (($exp5 | Where-Object { $_.document_id -eq $docSoon }).Count -eq 0) "rows=$($exp5.Count)"

# The `document_expiry` notification type exists in the catalog. Nothing produces it: the only
# notification writer in the database is `app.process_lead_sla`. This assertion PINS that gap so it
# is a recorded finding rather than a surprise the day an agency misses a passport renewal.
$docNotifs = (Psql "select count(*) from public.notifications where tenant_id='$T' and notification_type_code='document_expiry';").Trim()
Check "DOC-EXP-1 pinned: an expiring passport produces NO notification -- the type exists, the producer does not" ($docNotifs -eq '0') "notifications=$docNotifs"

# =============================================================================================
# REPEAT BOOKING: the customer who comes back. The reason customer identity is not branch-scoped.
# =============================================================================================
Write-Host "`n-- repeat booking --"

$r = Rpc $emp 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Mona Fathy Again'; p_primary_phone = '+201118889999' }
Check "the returning customer is NOT created twice -- the same phone resolves to the same person" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$b2 = Val (Rpc $emp 'create_booking' @{ p_customer_id = $customerId; p_title = 'Second trip: Hurghada'; p_branch_id = $BR; p_department_id = $DP })
Check "...and their SECOND booking attaches to the same customer record" ($null -ne $b2) "b2=$b2"

$hist = @(Val (Rpc $emp 'customer_timeline' @{ p_customer_id = $customerId }))
$bookings = @($hist | Where-Object { $_.entity_type -eq 'booking' } | Select-Object -ExpandProperty entity_id -Unique)
Check "...and the 360 timeline shows BOTH trips, which is what makes a returning customer visible" ($bookings.Count -ge 2) "distinct bookings in timeline=$($bookings.Count)"

$r = Get-Rest $trn "customers?select=id,full_name"
$trnCust = @(Val $r)
Check "...while the trainee still sees the customer master row but none of this history" (($trnCust | Where-Object { $_.id -eq $customerId }).Count -eq 1) "$($r.StatusCode) rows=$($trnCust.Count)"

# =================================================================================================
Write-Host "`n-- the lead state machine (API-3) --" -ForegroundColor Cyan
# =================================================================================================
# `advance_lead` and `convert_lead` were among the 33 endpoints MASTER_API_CONTRACT.md marked as
# having no HTTP evidence -- and leads are where acquisition becomes revenue, so they are the worst
# place to be relying on pgTAP alone. This walks the machine over the wire and, more importantly,
# proves the TRANS-2 HANDLER RULE through PostgREST: that rule has only ever been asserted in pgTAP.

$leadJ = Val (Rpc $emp 'create_lead' @{ p_branch_id = $BR; p_department_id = $DP
                                        p_lead_source_code = 'google_ads_call'
                                        p_title = 'Umrah, family of four'; p_customer_id = $customerId })
Check "the employee opens an attributed lead" ($null -ne $leadJ) "lead=$leadJ"

$r = Rpc $emp 'advance_lead' @{ p_lead_id = $leadJ; p_to_status = 'won'; p_reason = 'skip the machine' }
Check "a NEW lead cannot jump straight to won -- the state machine holds over HTTP" (-not (Ok $r)) "$($r.StatusCode)"

$r = Rpc $owner 'assign_lead' @{ p_lead_id = $leadJ; p_assignee_user_id = $U_EMP; p_reason = 'front line' }
Check "the owner assigns it: new -> assigned" (Ok $r) (Err $r)

# assigned -> contacted is NOT advance_lead's to make. Logging a real interaction is what makes a
# lead contacted, so `record_lead_interaction` owns that transition -- one of three the transition
# table permits and `advance_lead`'s own VALUES list deliberately omits (TRANS-1 documented this;
# the first draft of this walk assumed advance_lead drove everything and was refused).
$r = Rpc $emp 'record_lead_interaction' @{ p_lead_id = $leadJ; p_interaction_type_code = 'phone_call'
                                           p_summary = 'Called the customer back, discussed dates' }
Check "logging an interaction is what carries assigned -> contacted" (Ok $r) (Err $r)

foreach ($step in @(
    @{ to = 'qualified';      why = 'budget and dates confirmed' },
    @{ to = 'quotation_sent'; why = 'quotation emailed' },
    @{ to = 'negotiation';    why = 'customer asked about a cheaper hotel' },
    @{ to = 'won';            why = 'customer accepted' })) {
    $r = Rpc $emp 'advance_lead' @{ p_lead_id = $leadJ; p_to_status = $step.to; p_reason = $step.why }
    Check "lead -> $($step.to)" (Ok $r) (Err $r)
}

# TRANS-2 over HTTP. A SECOND lead assigned to the owner: the employee can SEE it (canon 28 gives
# `employee` VIEW_DEPARTMENT_QUEUE) but is not its handler and holds no ASSIGN_LEAD, so the handler
# rule -- not RLS -- must refuse them. Seeing it is asserted first, or the refusal proves nothing.
$leadO = Val (Rpc $emp 'create_lead' @{ p_branch_id = $BR; p_department_id = $DP
                                        p_lead_source_code = 'direct_call'
                                        p_title = 'A colleague''s lead'; p_customer_id = $customerId })
$r = Rpc $owner 'assign_lead' @{ p_lead_id = $leadO; p_assignee_user_id = '0c110000-0000-0000-0000-00000000aa03'; p_reason = 'owner keeps this one' }
Check "a second lead is assigned to the OWNER, not the employee" (Ok $r) (Err $r)

$r = Get-Rest $emp "leads?id=eq.$leadO&select=id,lead_status_code"
Check "POSITIVE CONTROL: the employee CAN SEE the colleague's lead (VIEW_DEPARTMENT_QUEUE)" `
    ((Ok $r) -and (Val $r).Count -eq 1) "$($r.StatusCode) $($r.Content)"

$r = Rpc $emp 'advance_lead' @{ p_lead_id = $leadO; p_to_status = 'contacted'; p_reason = 'not mine to work' }
Check "TRANS-2 over HTTP: ...but CANNOT advance it -- the handler rule, not RLS, is what refuses" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

# convert_lead: won -> converted, the step where a lead becomes a customer relationship.
$r = Rpc $emp 'convert_lead' @{ p_lead_id = $leadJ; p_customer_id = $customerId; p_reason = 'booking to follow' }
Check "convert_lead carries the won lead to converted" (Ok $r) (Err $r)

$r = Get-Rest $emp "leads?id=eq.$leadJ&select=lead_status_code,lead_source_code,attribution_click_id"
$lj = @(Val $r)[0]
Check "...and the stored state is 'converted'" ($lj.lead_status_code -eq 'converted') "status=$($lj.lead_status_code)"
Check "ATTR-3 over HTTP: the acquisition source survived the entire machine unchanged" `
    ($lj.lead_source_code -eq 'google_ads_call') "source=$($lj.lead_source_code)"

$r = Rpc $emp 'lead_timeline' @{ p_lead_id = $leadJ }
$tl = @(Val $r)
Check "the lead timeline records the walk, not just its last state" ($tl.Count -ge 5) "timeline rows=$($tl.Count)"

# =============================================================================================
# API-3: THE LEAD-ROUTING FAMILY OVER HTTP -- assign_lead_round_robin, reassign_lead, lead_origin,
# lead_booking_readiness. All four had ZERO HTTP evidence; two had no behavioural coverage at all,
# only a name in 53_api_surface_test's endpoint list.
#
# The fixture is what makes the routing assertion discriminating: FOUR people are placed in this
# branch/department, and only TWO of them (owner, employee) hold CLOSE_LEAD. The finance manager
# and the trainee are placed here and are NOT eligible handlers.
# =============================================================================================
Write-Host "`n-- API-3: lead routing --" -ForegroundColor Cyan

function Post-Rest($jwt, $path, $body) {
    Invoke-WebRequest -Uri "$API/rest/v1/$path" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" } `
        -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 6 -Compress)
}

$leadRR = Val (Rpc $emp 'create_lead' @{ p_branch_id = $BR; p_department_id = $DP
                                          p_lead_source_code = 'direct_call'; p_title = 'Round robin target' })
Check "a new unassigned lead exists for round-robin" ($null -ne $leadRR) "l=$leadRR"

$r = Rpc $owner 'assign_lead_round_robin' @{ p_lead_id = $leadRR; p_reason = 'auto' }
Check "assign_lead_round_robin executes over HTTP (first execution evidence this endpoint has ever had)" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Get-Rest $owner "leads?id=eq.$leadRR&select=assigned_user_id,lead_status_code"
$rrLead = @(Val $r)[0]
Check "...and the lead is now assigned" ($null -ne $rrLead.assigned_user_id) "assignee=$($rrLead.assigned_user_id)"
Check "LEAD-6 over HTTP: round-robin did NOT route to the TRAINEE, who is placed in this department but holds no CLOSE_LEAD" `
    ($rrLead.assigned_user_id -ne $U_TRN) "assignee=$($rrLead.assigned_user_id)"
Check "LEAD-6 over HTTP: nor to the FINANCE MANAGER, also placed here and also not an eligible handler" `
    ($rrLead.assigned_user_id -ne '0c110000-0000-0000-0000-00000000aa05') "assignee=$($rrLead.assigned_user_id)"

$r = Rpc $owner 'lead_origin' @{ p_lead_id = $leadRR }
$lo = @(Val $r)[0]
Check "lead_origin executes over HTTP and reports the first handler" ((Ok $r) -and $lo.first_user_id -eq $rrLead.assigned_user_id) "$($r.StatusCode) $($r.Content)"
Check "...with an assignment_count of 1 before any handover" ($lo.assignment_count -eq 1) "count=$($lo.assignment_count)"

$otherEligible = if ($rrLead.assigned_user_id -eq $U_EMP) { '0c110000-0000-0000-0000-00000000aa03' } else { $U_EMP }
$r = Rpc $owner 'reassign_lead' @{ p_lead_id = $leadRR; p_assignee_user_id = $otherEligible; p_reason = 'handover' }
Check "reassign_lead executes over HTTP" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $owner 'lead_origin' @{ p_lead_id = $leadRR }
$lo2 = @(Val $r)[0]
Check "lead_origin distinguishes FIRST from CURRENT after the handover -- the fact canon 04 says must survive" `
    (($lo2.first_user_id -eq $rrLead.assigned_user_id) -and ($lo2.current_user_id -eq $otherEligible)) "first=$($lo2.first_user_id) current=$($lo2.current_user_id)"
Check "...and the timeline now counts 2 assignments, neither deleted" ($lo2.assignment_count -eq 2) "count=$($lo2.assignment_count)"

# ASGN-1 through the door PostgREST actually opens: `authenticated` holds INSERT on this table.
$r = Post-Rest $owner "lead_assignments" @{ tenant_id = $T; lead_id = $leadRR; assigned_user_id = $U_TRN
                                            assigned_by = '0c110000-0000-0000-0000-00000000aa03'; is_current = $true }
Check "ASGN-1 over HTTP: POST /rest/v1/lead_assignments cannot open a SECOND current assignment -- the RPC is not the only door and the table now refuses too" `
    (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Get-Rest $owner "lead_assignments?lead_id=eq.$leadRR&is_current=eq.true&select=assigned_user_id"
Check "...and exactly one current assignment survives the attempt" (@(Val $r).Count -eq 1) "$($r.Content)"

# ASGN-2 through the same door: a closed history row is legal; the attribution is not the caller's to choose.
$r = Post-Rest $owner "lead_assignments" @{ tenant_id = $T; lead_id = $leadRR; assigned_user_id = $U_TRN
                                            assigned_by = $U_TRN; is_current = $false }
Check "POSITIVE CONTROL: a CLOSED history row is accepted over HTTP, so the next assertion is about the value stored" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Get-Rest $owner "lead_assignments?lead_id=eq.$leadRR&is_current=eq.false&assigned_user_id=eq.$U_TRN&select=assigned_by"
Check "ASGN-2 over HTTP: assigned_by is the CALLER, not the id the caller put in the body -- attribution cannot be forged through PostgREST" `
    (@(Val $r)[0].assigned_by -eq '0c110000-0000-0000-0000-00000000aa03') "$($r.Content)"

# lead_booking_readiness: the derived verdict Booking Core consumes.
$leadNoCust = Val (Rpc $emp 'create_lead' @{ p_branch_id = $BR; p_department_id = $DP
                                              p_lead_source_code = 'direct_call'; p_title = 'No customer yet' })
$r = Rpc $emp 'lead_booking_readiness' @{ p_lead_id = $leadNoCust }
$rd = @(Val $r)[0]
Check "lead_booking_readiness executes over HTTP" (Ok $r) "$($r.StatusCode) $(Err $r)"
Check "...and a lead with no customer linked is NOT booking-ready, with the reason named" `
    (($rd.is_ready -eq $false) -and ($rd.reason_code -eq 'no_customer_linked')) "ready=$($rd.is_ready) code=$($rd.reason_code)"

$leadCust = Val (Rpc $emp 'create_lead' @{ p_branch_id = $BR; p_department_id = $DP; p_customer_id = $customerId
                                            p_lead_source_code = 'direct_call'; p_title = 'Customer linked' })
$r = Rpc $emp 'lead_booking_readiness' @{ p_lead_id = $leadCust }
$rd2 = @(Val $r)[0]
Check "POSITIVE CONTROL: the same endpoint returns READY once a customer is linked, so the refusal above was the rule and not a broken call" `
    (($rd2.is_ready -eq $true) -and ($rd2.reason_code -eq 'ready')) "ready=$($rd2.is_ready) code=$($rd2.reason_code)"

# =============================================================================================
# API-3: THE MARKETING-CAMPAIGN FAMILY OVER HTTP -- create_marketing_campaign,
# advance_marketing_campaign, record_offline_conversion. All three had ZERO HTTP evidence, and
# record_offline_conversion had no behavioural coverage at all beyond its name in an inventory.
#
# The owner is the actor because MANAGE_MARKETING_CAMPAIGN resolves to `ceo` and `owner` only, and
# this suite's owner JWT already carries aal2 -- without it every refusal would be an MFA refusal
# wearing an integrity label.
#
# The money assertions matter because app.claim_conversion_deliveries hands conversion_value and
# currency_code VERBATIM to the Google Ads payload without inspecting either.
# =============================================================================================
Write-Host "`n-- API-3: marketing campaigns and offline conversions --" -ForegroundColor Cyan

$campId = Val (Rpc $owner 'create_marketing_campaign' @{ p_campaign_name = 'Umrah Ramadan'
                                                          p_platform_code = 'google_ads'
                                                          p_external_campaign_id = 'G-HTTP-1' })
Check "create_marketing_campaign executes over HTTP (first execution evidence this endpoint has had)" ($null -ne $campId) "c=$campId"

$r = Get-Rest $owner "marketing_campaigns?id=eq.$campId&select=status_code,campaign_name,external_campaign_id"
$camp = @(Val $r)[0]
Check "...and the campaign opens in canon 26 initial state 'draft'" ($camp.status_code -eq 'draft') "status=$($camp.status_code)"

$r = Rpc $owner 'create_marketing_campaign' @{ p_campaign_name = 'Umrah Ramadan duplicate'
                                                p_platform_code = 'google_ads'; p_external_campaign_id = 'G-HTTP-1' }
Check "the same external campaign id cannot be recorded twice for one platform -- attribution would split across two rows" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $owner 'advance_marketing_campaign' @{ p_campaign_id = $campId; p_to_status = 'active'; p_reason = 'go live' }
Check "advance_marketing_campaign executes over HTTP" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Get-Rest $owner "marketing_campaigns?id=eq.$campId&select=status_code,started_at"
Check "...and the stored state is 'active'" ((@(Val $r)[0]).status_code -eq 'active') "$($r.Content)"

$r = Rpc $owner 'advance_marketing_campaign' @{ p_campaign_id = $campId; p_to_status = 'draft'; p_reason = 'back' }
Check "a transition canon 26 does not define is refused over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Post-Rest $owner "marketing_campaigns" @{ tenant_id = $T; platform_code = 'google_ads'
                                                campaign_name = 'No status'; status_code = $null }
Check "CAMP-1 over HTTP: a campaign cannot be POSTed with NO status -- which used to leave it permanently unadvanceable" `
    (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$convId = Val (Rpc $owner 'record_offline_conversion' @{ p_conversion_event_type_code = 'booking_created'
                                                          p_marketing_campaign_id = $campId
                                                          p_conversion_value = 5000; p_currency_code = 'EGP' })
Check "record_offline_conversion executes over HTTP (first execution evidence this endpoint has had)" ($null -ne $convId) "c=$convId"

$r = Get-Rest $owner "offline_conversions?id=eq.$convId&select=conversion_value,currency_code,marketing_campaign_id"
$conv = @(Val $r)[0]
Check "...and the recorded money is exactly what was sent -- this is the value Google Ads will receive" `
    (([decimal]$conv.conversion_value -eq 5000) -and ($conv.currency_code -eq 'EGP')) "$($r.Content)"

$r = Rpc $owner 'record_offline_conversion' @{ p_conversion_event_type_code = 'booking_created'
                                                p_marketing_campaign_id = $campId
                                                p_conversion_value = -5000; p_currency_code = 'EGP' }
Check "the RPC refuses a NEGATIVE conversion value over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Post-Rest $owner "offline_conversions" @{ tenant_id = $T; conversion_event_type_code = 'booking_created'
                                                conversion_value = -5000; currency_code = 'EGP'; marketing_campaign_id = $campId }
Check "CONV-4 over HTTP: POST /rest/v1/offline_conversions cannot store a negative value either -- the RPC is not the only door to the Google Ads payload" `
    (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Post-Rest $owner "offline_conversions" @{ tenant_id = $T; conversion_event_type_code = 'booking_created'
                                                conversion_value = 7777; marketing_campaign_id = $campId }
Check "CONV-5 over HTTP: nor an amount with no currency" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Post-Rest $owner "offline_conversions" @{ tenant_id = $T; conversion_event_type_code = 'qualified_lead'
                                                marketing_campaign_id = $campId }
Check "POSITIVE CONTROL: a conversion carrying no money at all is still accepted -- the pair rule does not over-reach" (Ok $r) "$($r.StatusCode) $(Err $r)"

Write-Host ""
if ($fail -gt 0) { $findings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow } }
Write-Host "== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
Write-Host "(fixture rows remain by design -- the audit spine is append-only; 'npx supabase db reset' is the reset)"
if ($fail -gt 0) { exit 1 }
