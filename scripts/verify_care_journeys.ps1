# ORVION -- the care journeys: complaints and conversations, end to end over HTTP.
#
# These two lifecycles had two HTTP assertions each in `verify_journey_branches.ps1` -- log a
# complaint, acknowledge it; start a thread, send a message. Neither walked a state machine, neither
# tested an authority split, and neither touched the tables directly. This script does all three,
# because pgTAP proves what the DATABASE does and this proves what a CLIENT can actually reach:
# API-1 was 600 green pgTAP assertions over an entirely unreachable API.
#
# It also carries the over-the-wire half of SEC-1b. The pgTAP file proves the guard fires; only an
# HTTP POST to /rest/v1/complaints proves that PostgREST offers that door to a browser at all, which
# is how a real client would have found it.
#
# Local development stack only (`iss: supabase-demo` keys on 127.0.0.1). Never point at a project.

$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0; $findings = @()
function Check($name, $condition, $detail = '') {
    if ($condition) { $script:pass++; Write-Host "  ok   $name" -ForegroundColor Green }
    else { $script:fail++; $script:findings += "$name :: $detail"; Write-Host "  FAIL $name  $detail" -ForegroundColor Red }
}

Write-Host "`n== ORVION care journeys: complaints and conversations, over HTTP ==" -ForegroundColor Cyan

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
function Post-Rest($jwt, $path, $body) {
    Invoke-WebRequest -Uri "$API/rest/v1/$path" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt"; Prefer = 'return=representation' } `
        -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 6 -Compress)
}
function Patch-Rest($jwt, $path, $body) {
    Invoke-WebRequest -Uri "$API/rest/v1/$path" -Method Patch -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" } `
        -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 6 -Compress)
}
function Del-Rest($jwt, $path) {
    Invoke-WebRequest -Uri "$API/rest/v1/$path" -Method Delete -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" }
}
function Get-Rest($jwt, $path) {
    Invoke-WebRequest -Uri "$API/rest/v1/$path" -Method Get -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" }
}
function Val($r) { if ($r.StatusCode -lt 300 -and $r.Content) { ($r.Content | ConvertFrom-Json) } else { $null } }
function Ok($r) { $r.StatusCode -ge 200 -and $r.StatusCode -lt 300 }
function Err($r) { try { ($r.Content | ConvertFrom-Json).message } catch { $r.Content } }

$T  = '0ca50000-0000-0000-0000-0000000000a0'
$T2 = '0ca50000-0000-0000-0000-0000000000b0'
$AU_MGR = '0ca50000-0000-0000-0000-0000000000a1'
$AU_EMP = '0ca50000-0000-0000-0000-0000000000a2'
$AU_TRN = '0ca50000-0000-0000-0000-0000000000a3'
$AU_RIV = '0ca50000-0000-0000-0000-0000000000b1'

if ((Psql "select count(*) from public.tenants where id='$T';").Trim() -ne '0') {
    Write-Host "  fixture tenant already present -- run 'npx supabase db reset' first" -ForegroundColor Yellow
    exit 1
}

Psql @"
insert into auth.users (id, email) values
  ('$AU_MGR','mgr@care.test'),('$AU_EMP','emp@care.test'),('$AU_TRN','trn@care.test'),('$AU_RIV','riv@care.test');
insert into public.tenants (id, name, slug, status) values
  ('$T','Care Travel','care-travel','active'),
  ('$T2','Rival Care','care-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['$T'::uuid,'$T2'::uuid]) t where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('0ca50000-0000-0000-0000-00000000aa01','$T','Cairo','care-cairo'),
  ('0ca50000-0000-0000-0000-00000000bb01','$T2','Giza','care-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('0ca50000-0000-0000-0000-00000000aa02','$T','0ca50000-0000-0000-0000-00000000aa01','sales','Sales'),
  ('0ca50000-0000-0000-0000-00000000bb02','$T2','0ca50000-0000-0000-0000-00000000bb01','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('0ca50000-0000-0000-0000-00000000aa03','$T','Care Manager','mgr@care.test',true,'$AU_MGR'),
  ('0ca50000-0000-0000-0000-00000000aa04','$T','Care Employee','emp@care.test',true,'$AU_EMP'),
  ('0ca50000-0000-0000-0000-00000000aa05','$T','Care Trainee','trn@care.test',true,'$AU_TRN'),
  ('0ca50000-0000-0000-0000-00000000bb03','$T2','Rival Owner','riv@care.test',true,'$AU_RIV');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('$T','0ca50000-0000-0000-0000-00000000aa03','0ca50000-0000-0000-0000-00000000aa01','0ca50000-0000-0000-0000-00000000aa02',true),
  ('$T','0ca50000-0000-0000-0000-00000000aa04','0ca50000-0000-0000-0000-00000000aa01','0ca50000-0000-0000-0000-00000000aa02',true),
  ('$T','0ca50000-0000-0000-0000-00000000aa05','0ca50000-0000-0000-0000-00000000aa01','0ca50000-0000-0000-0000-00000000aa02',true),
  ('$T2','0ca50000-0000-0000-0000-00000000bb03','0ca50000-0000-0000-0000-00000000bb01','0ca50000-0000-0000-0000-00000000bb02',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant' from (values
  ('$T'::uuid,'0ca50000-0000-0000-0000-00000000aa03'::uuid,'branch_manager'),
  ('$T'::uuid,'0ca50000-0000-0000-0000-00000000aa04'::uuid,'employee'),
  ('$T'::uuid,'0ca50000-0000-0000-0000-00000000aa05'::uuid,'trainee'),
  ('$T2'::uuid,'0ca50000-0000-0000-0000-00000000bb03'::uuid,'owner')) v(t,u,rc)
join public.roles r on r.code=v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('0ca50000-0000-0000-0000-00000000cc01','$T','person','Care Customer','+201000000801');
"@ | Out-Null

$MGR = New-UserJwt $AU_MGR $false
$EMP = New-UserJwt $AU_EMP $false
$TRN = New-UserJwt $AU_TRN $false
$RIV = New-UserJwt $AU_RIV $true

Check "fixture seeded" ((Psql "select count(*) from public.users where tenant_id='$T';").Trim() -eq '3')

# =================================================================================================
Write-Host "`n-- complaints: the whole state machine --" -ForegroundColor Cyan
# =================================================================================================
$r = Rpc $EMP 'create_complaint' @{ p_customer_id = '0ca50000-0000-0000-0000-00000000cc01'
                                    p_title = 'Baggage lost on the return leg'
                                    p_complaint_category_code = 'baggage'
                                    p_complaint_severity_code = 'high'
                                    p_description = 'Customer arrived, bag did not.' }
Check "employee logs a complaint over HTTP" (Ok $r) (Err $r)
$COMP = Val $r

$r = Rpc $EMP 'advance_complaint' @{ p_complaint_id = $COMP; p_to_status = 'resolved'; p_reason = 'skip the queue' }
Check "...and CANNOT jump new -> resolved -- the state machine is enforced over HTTP too" (-not (Ok $r)) "$($r.StatusCode)"

foreach ($step in @(
    @{ to = 'acknowledged';      why = 'logged and acknowledged to the customer' },
    @{ to = 'in_progress';       why = 'chasing the airline' },
    @{ to = 'awaiting_supplier'; why = 'airline has the claim' },
    @{ to = 'in_progress';       why = 'airline answered' },
    @{ to = 'awaiting_customer'; why = 'need the customer to confirm the contents' },
    @{ to = 'in_progress';       why = 'customer confirmed' })) {
    $r = Rpc $EMP 'advance_complaint' @{ p_complaint_id = $COMP; p_to_status = $step.to; p_reason = $step.why }
    Check "complaint -> $($step.to)" (Ok $r) (Err $r)
}

$r = Rpc $EMP 'advance_complaint' @{ p_complaint_id = $COMP; p_to_status = 'resolved'
                                     p_reason = 'Airline located the bag and delivered it; goodwill voucher issued.' }
Check "complaint -> resolved" (Ok $r) (Err $r)

$notes = (Psql "select coalesce(resolution_notes,'<null>') from public.complaints where id='$COMP';").Trim()
Check "COMP-1: the resolution is RECORDED on the complaint, not only in the event stream" `
    ($notes -eq 'Airline located the bag and delivered it; goodwill voucher issued.') "notes=$notes"

$r = Rpc $EMP 'advance_complaint' @{ p_complaint_id = $COMP; p_to_status = 'closed'; p_reason = 'customer satisfied' }
Check "complaint -> closed" (Ok $r) (Err $r)
$r = Rpc $EMP 'advance_complaint' @{ p_complaint_id = $COMP; p_to_status = 'in_progress'; p_reason = 'customer came back' }
Check "...and a CLOSED complaint can be reopened -- an agency does not get to close a conversation unilaterally" (Ok $r) (Err $r)

$ev = (Psql "select string_agg(distinct event_type_code, ',' order by event_type_code) from public.events where entity_type='complaint' and entity_id='$COMP';").Trim()
Check "every transition left its own event ($ev)" `
    ($ev -like '*complaint_acknowledged*' -and $ev -like '*complaint_resolved*' -and $ev -like '*complaint_reopened*') "events=$ev"

# =================================================================================================
Write-Host "`n-- complaints: who may open one --" -ForegroundColor Cyan
# =================================================================================================
$r = Rpc $TRN 'create_complaint' @{ p_customer_id = '0ca50000-0000-0000-0000-00000000cc01'
                                    p_title = 'Trainee complaint'; p_complaint_category_code = 'other' }
Check "a TRAINEE cannot open a complaint through the RPC" (-not (Ok $r)) "$($r.StatusCode)"

# SEC-1b over the wire. PostgREST exposes the table itself, so this is the door a browser would find.
$r = Post-Rest $TRN 'complaints' @{ tenant_id = $T; customer_id = '0ca50000-0000-0000-0000-00000000cc01'
                                    owner_user_id = '0ca50000-0000-0000-0000-00000000aa05'
                                    owner_branch_id = '0ca50000-0000-0000-0000-00000000aa01'
                                    owner_department_id = '0ca50000-0000-0000-0000-00000000aa02'
                                    complaint_category_code = 'other'; complaint_severity_code = 'normal'
                                    complaint_status_code = 'new'; title = 'Trainee via PostgREST' }
Check "SEC-1b: ...nor by POSTing straight to /rest/v1/complaints -- the door a client would actually find" `
    (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Post-Rest $EMP 'complaints' @{ tenant_id = $T; customer_id = '0ca50000-0000-0000-0000-00000000cc01'
                                    owner_user_id = '0ca50000-0000-0000-0000-00000000aa04'
                                    owner_branch_id = '0ca50000-0000-0000-0000-00000000aa01'
                                    owner_department_id = '0ca50000-0000-0000-0000-00000000aa02'
                                    complaint_category_code = 'other'; complaint_severity_code = 'normal'
                                    complaint_status_code = 'new'; title = 'Employee via PostgREST' }
Check "POSITIVE CONTROL: the EMPLOYEE can -- the guard charges capability, it does not close the endpoint" (Ok $r) "$($r.StatusCode) $(Err $r)"

# =================================================================================================
Write-Host "`n-- complaints: isolation --" -ForegroundColor Cyan
# =================================================================================================
$r = Get-Rest $RIV "complaints?id=eq.$COMP"
Check "the RIVAL AGENCY sees nothing of it" ((Ok $r) -and (Val $r).Count -eq 0) "$($r.StatusCode) $($r.Content)"
$r = Rpc $RIV 'advance_complaint' @{ p_complaint_id = $COMP; p_to_status = 'closed'; p_reason = 'not mine to close' }
Check "...and cannot advance it either -- reading nothing is not the same as writing nothing" (-not (Ok $r)) "$($r.StatusCode)"

# =================================================================================================
Write-Host "`n-- conversations: the thread --" -ForegroundColor Cyan
# =================================================================================================
$r = Rpc $EMP 'start_conversation' @{ p_channel_code = 'whatsapp'; p_customer_id = '0ca50000-0000-0000-0000-00000000cc01' }
Check "employee opens a WhatsApp thread" (Ok $r) (Err $r)
$CONV = Val $r

$r = Rpc $EMP 'advance_conversation' @{ p_conversation_id = $CONV; p_to_status = 'assigned'; p_reason = 'picked up' }
Check "open -> assigned" (Ok $r) (Err $r)

$r = Rpc $EMP 'send_conversation_message' @{ p_conversation_id = $CONV; p_message_direction_code = 'outbound'
                                             p_sender_type_code = 'user'; p_body = 'Good morning, how can we help?' }
Check "the employee sends an outbound message" (Ok $r) (Err $r)
$MSG = Val $r

$r = Rpc $EMP 'send_conversation_message' @{ p_conversation_id = $CONV; p_message_direction_code = 'inbound'
                                             p_sender_type_code = 'customer'; p_body = 'My visa appointment moved.' }
Check "...and records the customer's inbound reply" (Ok $r) (Err $r)

$r = Rpc $EMP 'advance_conversation' @{ p_conversation_id = $CONV; p_to_status = 'pending_customer'; p_reason = 'waiting on documents' }
Check "assigned -> pending_customer" (Ok $r) (Err $r)
$r = Rpc $EMP 'advance_conversation' @{ p_conversation_id = $CONV; p_to_status = 'assigned'; p_reason = 'documents arrived' }
Check "pending_customer -> assigned" (Ok $r) (Err $r)

# =================================================================================================
Write-Host "`n-- conversations: the authority split canon draws --" -ForegroundColor Cyan
# =================================================================================================
$r = Rpc $EMP 'advance_conversation' @{ p_conversation_id = $CONV; p_to_status = 'escalated'; p_reason = 'customer is angry' }
Check "an EMPLOYEE cannot escalate -- ESCALATE_CONVERSATION is a supervisory permission" (-not (Ok $r)) "$($r.StatusCode)"
$r = Rpc $MGR 'advance_conversation' @{ p_conversation_id = $CONV; p_to_status = 'escalated'; p_reason = 'taking it on' }
Check "...while the BRANCH MANAGER can -- the positive control for the refusal above" (Ok $r) (Err $r)
$r = Rpc $MGR 'advance_conversation' @{ p_conversation_id = $CONV; p_to_status = 'assigned'; p_reason = 'handing it back' }
Check "escalated -> assigned" (Ok $r) (Err $r)

$r = Rpc $EMP 'advance_conversation' @{ p_conversation_id = $CONV; p_to_status = 'closed'; p_reason = 'resolved' }
Check "...and an employee CAN close it -- closing is front-line, escalating is not" (Ok $r) (Err $r)
$r = Rpc $EMP 'send_conversation_message' @{ p_conversation_id = $CONV; p_message_direction_code = 'outbound'
                                             p_sender_type_code = 'user'; p_body = 'one more thing' }
Check "a CLOSED thread refuses new messages" (-not (Ok $r)) "$($r.StatusCode)"

# PARENT-1. The assertion above and the table POST further down BOTH existed before 202607059400,
# and the gap survived because they were never asked at the same moment: the RPC was refused while
# the thread was closed, and the table was posted to after it had been reopened. This asks the table
# door the identical question the RPC has just refused, at the identical moment.
$r = Post-Rest $EMP 'conversation_messages' @{ tenant_id = $T; conversation_id = $CONV
                                               sender_type_code = 'user'; message_direction_code = 'outbound'
                                               message_text = 'one more thing, straight to the table' }
Check "PARENT-1: ...and so does the TABLE door, with the RPC's own words -- before 202607059400 this POST returned 201 onto a finished engagement" `
    (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $EMP 'advance_conversation' @{ p_conversation_id = $CONV; p_to_status = 'open'; p_reason = 'customer wrote again' }
Check "...and reopening it is the supported way back -- closed -> open" (Ok $r) (Err $r)
$r = Post-Rest $EMP 'conversation_messages' @{ tenant_id = $T; conversation_id = $CONV
                                               sender_type_code = 'user'; message_direction_code = 'outbound'
                                               message_text = 'accepted once reopened' }
Check "NEGATIVE CONTROL: the identical POST succeeds once the thread is reopened -- the guard reads the parent's state, it does not close the door" `
    (Ok $r) "$($r.StatusCode) $(Err $r)"

# =================================================================================================
Write-Host "`n-- conversations: the message record --" -ForegroundColor Cyan
# =================================================================================================
$r = Post-Rest $EMP 'conversation_messages' @{ tenant_id = $T; conversation_id = $CONV
                                               sender_type_code = 'user'; message_direction_code = 'outbound'
                                               message_text = 'Posted straight to the table'
                                               sender_user_id = '0ca50000-0000-0000-0000-00000000aa03' }
Check "a message can be POSTed straight to the table" (Ok $r) "$($r.StatusCode) $(Err $r)"
$forged = (Psql "select sender_user_id from public.conversation_messages where message_text='Posted straight to the table';").Trim()
Check "ATTR-4: ...but it is attributed to the ACTUAL sender, not the manager it named" `
    ($forged -eq '0ca50000-0000-0000-0000-00000000aa04') "sender=$forged"

$r = Patch-Rest $EMP "conversation_messages?id=eq.$MSG" @{ message_text = 'that is not what I said' }
Check "CONV-2: the text of a sent message cannot be rewritten over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"
$r = Del-Rest $EMP "conversation_messages?id=eq.$MSG"
Check "...nor deleted" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"
$r = Patch-Rest $EMP "conversation_messages?id=eq.$MSG" @{ external_message_id = 'wamid.HTTP' }
Check "NEGATIVE CONTROL: external_message_id still updates -- the WhatsApp writer is not blocked" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Get-Rest $RIV "conversation_messages?conversation_id=eq.$CONV"
Check "the rival agency reads none of the thread" ((Ok $r) -and (Val $r).Count -eq 0) "$($r.StatusCode) $($r.Content)"
$r = Get-Rest $TRN "conversation_messages?conversation_id=eq.$CONV"
Check "...and neither does the TRAINEE, who is in the same branch but holds no VIEW_CONVERSATION" `
    ((Ok $r) -and (Val $r).Count -eq 0) "$($r.StatusCode) $($r.Content)"

Write-Host ""
if ($fail -eq 0) { Write-Host "== $pass passed, 0 failed ==" -ForegroundColor Green }
else { Write-Host "== $pass passed, $fail FAILED ==" -ForegroundColor Red; $findings | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red } }
Write-Host "(fixture rows remain by design -- the audit spine is append-only; 'npx supabase db reset' is the reset)" -ForegroundColor DarkGray
if ($fail -gt 0) { exit 1 }
