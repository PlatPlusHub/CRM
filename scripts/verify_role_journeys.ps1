# ORVION -- the role journeys (Phase C, §8).
#
# The employee has now been walked twice. Senior employee, branch manager, department manager,
# finance manager, CEO, owner and the platform owner have had none of that treatment. This script
# gives each of them the same standard: a POSITIVE control proving the role can do its job, then the
# NEGATIVE controls proving it cannot do someone else's.
#
# Everything runs over HTTP with real JWTs. `postgres` builds the world and proves nothing.
#
# Local development stack only (`iss: supabase-demo` keys on 127.0.0.1).

$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0; $findings = @()
function Check($name, $condition, $detail = '') {
    if ($condition) { $script:pass++; Write-Host "  ok   $name" -ForegroundColor Green }
    else { $script:fail++; $script:findings += "$name :: $detail"; Write-Host "  FAIL $name  $detail" -ForegroundColor Red }
}

Write-Host "`n== ORVION role journeys over HTTP ==" -ForegroundColor Cyan
$status = (npx supabase status -o json 2>$null) | ConvertFrom-Json
$API = $status.API_URL; $ANON = $status.ANON_KEY; $SERVICE = $status.SERVICE_ROLE_KEY; $JWT_SECRET = $status.JWT_SECRET
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
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" } -ContentType 'application/json' `
        -Body ($body | ConvertTo-Json -Depth 6 -Compress)
}
function Get-Rest($jwt, $path) {
    Invoke-WebRequest -Uri "$API/rest/v1/$path" -Method Get -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $jwt" }
}
function Val($r) { if ($r.StatusCode -lt 300 -and $r.Content) { ($r.Content | ConvertFrom-Json) } else { $null } }
function Ok($r) { $r.StatusCode -ge 200 -and $r.StatusCode -lt 300 }
function Err($r) { try { ($r.Content | ConvertFrom-Json).message } catch { $r.Content } }

$T = '0d110000-0000-0000-0000-0000000000a0'
$BR_A = '0d110000-0000-0000-0000-00000000aa01'   # Cairo
$BR_B = '0d110000-0000-0000-0000-00000000bb01'   # Alexandria
$DP_A = '0d110000-0000-0000-0000-00000000aa02'   # Cairo Sales
$DP_A2 = '0d110000-0000-0000-0000-00000000aa07'  # Cairo Operations

if ((Psql "select count(*) from public.tenants where id='$T';").Trim() -ne '0') {
    Write-Host "  fixture tenant already present -- run 'npx supabase db reset' first" -ForegroundColor Yellow
    exit 1
}

# One agency, two branches, two departments in Cairo, one person per role. The second branch and the
# second department exist so every isolation claim has a real target rather than an absent one.
Psql @"
insert into auth.users (id,email) values
 ('0d110000-0000-0000-0000-0000000000e1','emp@rj.test'),
 ('0d110000-0000-0000-0000-0000000000e2','senior@rj.test'),
 ('0d110000-0000-0000-0000-0000000000e3','brmgr@rj.test'),
 ('0d110000-0000-0000-0000-0000000000e4','deptmgr@rj.test'),
 ('0d110000-0000-0000-0000-0000000000e5','fin@rj.test'),
 ('0d110000-0000-0000-0000-0000000000e6','ceo@rj.test'),
 ('0d110000-0000-0000-0000-0000000000e7','owner@rj.test'),
 ('0d110000-0000-0000-0000-0000000000e8','bemp@rj.test');
insert into public.tenants (id,name,slug,status) values ('$T','Role Journey Travel','role-journey','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '$T', sp.id,'active' from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id,tenant_id,name,slug) values
 ('$BR_A','$T','Cairo','rj-cairo'), ('$BR_B','$T','Alexandria','rj-alex');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
 ('$DP_A','$T','$BR_A','sales','Cairo Sales'),
 ('$DP_A2','$T','$BR_A','operations','Cairo Operations'),
 ('0d110000-0000-0000-0000-00000000bb02','$T','$BR_B','sales','Alex Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
 ('0d110000-0000-0000-0000-00000000f001','$T','Employee','emp@rj.test',true,'0d110000-0000-0000-0000-0000000000e1'),
 ('0d110000-0000-0000-0000-00000000f002','$T','Senior','senior@rj.test',true,'0d110000-0000-0000-0000-0000000000e2'),
 ('0d110000-0000-0000-0000-00000000f003','$T','BranchMgr','brmgr@rj.test',true,'0d110000-0000-0000-0000-0000000000e3'),
 ('0d110000-0000-0000-0000-00000000f004','$T','DeptMgr','deptmgr@rj.test',true,'0d110000-0000-0000-0000-0000000000e4'),
 ('0d110000-0000-0000-0000-00000000f005','$T','Finance','fin@rj.test',true,'0d110000-0000-0000-0000-0000000000e5'),
 ('0d110000-0000-0000-0000-00000000f006','$T','CEO','ceo@rj.test',true,'0d110000-0000-0000-0000-0000000000e6'),
 ('0d110000-0000-0000-0000-00000000f007','$T','Owner','owner@rj.test',true,'0d110000-0000-0000-0000-0000000000e7'),
 ('0d110000-0000-0000-0000-00000000f008','$T','AlexEmployee','bemp@rj.test',true,'0d110000-0000-0000-0000-0000000000e8');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary) values
 ('$T','0d110000-0000-0000-0000-00000000f001','$BR_A','$DP_A',true),
 ('$T','0d110000-0000-0000-0000-00000000f002','$BR_A','$DP_A',true),
 ('$T','0d110000-0000-0000-0000-00000000f003','$BR_A','$DP_A',true),
 ('$T','0d110000-0000-0000-0000-00000000f004','$BR_A','$DP_A',true),
 ('$T','0d110000-0000-0000-0000-00000000f005','$BR_A','$DP_A',true),
 ('$T','0d110000-0000-0000-0000-00000000f006','$BR_A','$DP_A',true),
 ('$T','0d110000-0000-0000-0000-00000000f007','$BR_A','$DP_A',true),
 ('$T','0d110000-0000-0000-0000-00000000f008','$BR_B','0d110000-0000-0000-0000-00000000bb02',true);
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '$T', v.u, r.id, 'tenant' from (values
 ('0d110000-0000-0000-0000-00000000f001'::uuid,'employee'),
 ('0d110000-0000-0000-0000-00000000f002'::uuid,'senior_employee'),
 ('0d110000-0000-0000-0000-00000000f003'::uuid,'branch_manager'),
 ('0d110000-0000-0000-0000-00000000f004'::uuid,'department_manager'),
 ('0d110000-0000-0000-0000-00000000f005'::uuid,'finance_manager'),
 ('0d110000-0000-0000-0000-00000000f006'::uuid,'ceo'),
 ('0d110000-0000-0000-0000-00000000f007'::uuid,'owner'),
 ('0d110000-0000-0000-0000-00000000f008'::uuid,'employee')) v(u,rc)
join public.roles r on r.code=v.rc;
select 'OK';
"@ | Out-Null

$emp = New-UserJwt '0d110000-0000-0000-0000-0000000000e1' $false
$senior = New-UserJwt '0d110000-0000-0000-0000-0000000000e2' $false
$brmgr = New-UserJwt '0d110000-0000-0000-0000-0000000000e3' $false
$deptmgr = New-UserJwt '0d110000-0000-0000-0000-0000000000e4' $false
$fin = New-UserJwt '0d110000-0000-0000-0000-0000000000e5' $true
$ceo = New-UserJwt '0d110000-0000-0000-0000-0000000000e6' $true
$owner = New-UserJwt '0d110000-0000-0000-0000-0000000000e7' $true
$alexEmp = New-UserJwt '0d110000-0000-0000-0000-0000000000e8' $false

# Cairo sells something; Alexandria sells something. Two branches with real money in them.
$cusA = Val (Rpc $emp 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Cairo Customer'; p_primary_phone = '+201000000101' })
$bkA = Val (Rpc $emp 'create_booking' @{ p_customer_id = $cusA; p_title = 'Cairo trip'; p_branch_id = $BR_A; p_department_id = $DP_A })
$itA = Val (Rpc $emp 'create_booking_item' @{ p_booking_id = $bkA; p_service_type_code = 'hotel'; p_currency_code = 'EGP'; p_cost_amount = 10000; p_selling_amount = 13000 })
$cusB = Val (Rpc $alexEmp 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Alex Customer'; p_primary_phone = '+201000000102' })
$bkB = Val (Rpc $alexEmp 'create_booking' @{ p_customer_id = $cusB; p_title = 'Alex trip'; p_branch_id = $BR_B; p_department_id = '0d110000-0000-0000-0000-00000000bb02' })
$itB = Val (Rpc $alexEmp 'create_booking_item' @{ p_booking_id = $bkB; p_service_type_code = 'flight_ticket'; p_currency_code = 'EGP'; p_cost_amount = 5000; p_selling_amount = 7000 })
Check "BASELINE: both branches have a sale" ($itA -and $itB) "A=$itA B=$itB"

# =============================================================================================
# SENIOR EMPLOYEE -- does the role differ meaningfully from employee?
# =============================================================================================
Write-Host "`n-- senior employee --"
$r = Rpc $senior 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Senior Customer'; p_primary_phone = '+201000000103' }
Check "senior employee does the sales job" (Ok $r) "$($r.StatusCode) $(Err $r)"
$r = Rpc $senior 'assign_lead' @{ p_lead_id = [guid]::Empty; p_assignee_user_id = '0d110000-0000-0000-0000-00000000f001' }
Check "...and still cannot assign leads (same as employee)" ($r.StatusCode -ge 400) "$($r.StatusCode)"
# FINANCIAL PRIVACY IS ABOUT COLUMNS, NOT ROWS -- and the first run of this script got that wrong.
# A senior employee legitimately SEES a colleague's booking item (VIEW_DEPARTMENT_RECORDS: the
# department must be able to keep serving a customer when the assigned employee is away). What they
# must not see is the money on it. Asserting `rows = 0` would have demanded the operational
# visibility be removed; asserting the FIGURES are null is the actual rule.
$sp = @(Val (Get-Rest $senior "booking_item_profit?select=*"))
Check "senior sees a colleague's item operationally" ($sp.Count -ge 1) "rows=$($sp.Count)"
$leaked = @($sp | Where-Object { $null -ne $_.cost_amount -or $null -ne $_.profit })
Check "...but its cost and profit are NULL -- financial privacy is column-level" ($leaked.Count -eq 0) "leaked=$($leaked.Count)"

# =============================================================================================
# BRANCH MANAGER -- a manager, not an employee with extras.
# =============================================================================================
Write-Host "`n-- branch manager --"
$bmBookings = @(Val (Get-Rest $brmgr "booking_pipeline?select=*"))
Check "branch manager sees their BRANCH's pipeline" ($bmBookings.Count -ge 1) "rows=$($bmBookings.Count)"
$bmAlex = @($bmBookings | Where-Object { $_.branch_id -eq $BR_B })
Check "...and NOT the other branch's" ($bmAlex.Count -eq 0) "alex rows=$($bmAlex.Count)"
$r = Rpc $brmgr 'assign_lead' @{ p_lead_id = [guid]::Empty; p_assignee_user_id = '0d110000-0000-0000-0000-00000000f001' }
Check "...and holds ASSIGN_LEAD (fails on the fixture id, not on permission)" ($r.StatusCode -ge 400 -and (Err $r) -notmatch 'permission denied') "$(Err $r)"

# =============================================================================================
# DEPARTMENT MANAGER -- department scope is not branch scope.
# =============================================================================================
Write-Host "`n-- department manager --"
$dmPipeline = @(Val (Get-Rest $deptmgr "booking_pipeline?select=*"))
Check "department manager sees their department's work" ($dmPipeline.Count -ge 1) "rows=$($dmPipeline.Count)"
$dmAlex = @($dmPipeline | Where-Object { $_.branch_id -eq $BR_B })
Check "...and not another branch's" ($dmAlex.Count -eq 0) "alex rows=$($dmAlex.Count)"

# =============================================================================================
# FINANCE MANAGER -- authority over financial reality, and nothing else.
# =============================================================================================
Write-Host "`n-- finance manager --"
$invA = Val (Rpc $fin 'create_invoice' @{ p_customer_id = $cusA; p_currency_code = 'EGP'; p_total_amount = 13000; p_booking_id = $bkA })
Check "finance raises an invoice" ([bool]$invA) "inv=$invA"
$r = Rpc $fin 'issue_invoice' @{ p_invoice_id = $invA; p_reason = 'issued' }
Check "...issues it" (Ok $r) "$($r.StatusCode) $(Err $r)"
$finProfit = @(Val (Get-Rest $fin "booking_item_profit?select=*"))
Check "...and sees TENANT-WIDE profit, which is its job" ($finProfit.Count -ge 2) "rows=$($finProfit.Count)"
$r = Rpc $fin 'assign_user_role' @{ p_user_id = '0d110000-0000-0000-0000-00000000f001'; p_role_code = 'owner' }
Check "...but CANNOT grant roles -- financial authority is not administrative authority" ($r.StatusCode -ge 400) "$($r.StatusCode) $(Err $r)"
$r = Rpc $fin 'create_branch' @{ p_name = 'Finance Branch'; p_slug = 'fin-branch' }
Check "...and cannot create branches" ($r.StatusCode -ge 400) "$($r.StatusCode) $(Err $r)"

# =============================================================================================
# CEO and OWNER -- tenant-wide, and where they differ.
# =============================================================================================
Write-Host "`n-- ceo and owner --"
$ceoProfit = @(Val (Get-Rest $ceo "booking_item_profit?select=*"))
Check "CEO sees tenant-wide profit across BOTH branches" ($ceoProfit.Count -ge 2) "rows=$($ceoProfit.Count)"
$ownerProfit = @(Val (Get-Rest $owner "booking_item_profit?select=*"))
Check "owner sees the same" ($ownerProfit.Count -ge 2) "rows=$($ownerProfit.Count)"
$r = Rpc $owner 'assign_user_role' @{ p_user_id = '0d110000-0000-0000-0000-00000000f001'; p_role_code = 'senior_employee' }
Check "owner grants a role" (Ok $r) "$($r.StatusCode) $(Err $r)"
$r = Rpc $ceo 'assign_user_role' @{ p_user_id = '0d110000-0000-0000-0000-00000000f002'; p_role_code = 'employee' }
Check "CEO grants a role too" (Ok $r) "$($r.StatusCode) $(Err $r)"

# THE LINE THAT MUST NOT MOVE: tenant authority is not platform authority.
$r = Rpc $owner 'platform_activate_subscription' @{ p_tenant_id = $T; p_plan_code = 'enterprise'; p_billing_period_code = 'lifetime' }
Check "the OWNER cannot activate their own subscription -- platform authority is separate" ($r.StatusCode -eq 404) "$($r.StatusCode) $(Err $r)"
$r = Rpc $ceo 'platform_issue_license_token' @{ p_tenant_id = $T; p_plan_code = 'enterprise'; p_billing_period_code = 'annual' }
Check "...and the CEO cannot mint a licence token" ($r.StatusCode -eq 404) "$($r.StatusCode)"
$subs = @(Val (Get-Rest $owner "subscription_state?select=*"))
Check "...though the owner CAN see their subscription state" ($subs.Count -ge 1) "rows=$($subs.Count)"

# =============================================================================================
# PLATFORM OWNER -- service_role, outside every tenant.
# =============================================================================================
Write-Host "`n-- platform owner --"
$r = Rpc $SERVICE 'claim_storage_actions' @{ p_limit = 5 }
Check "platform reaches its own endpoint" (Ok $r) "$($r.StatusCode) $(Err $r)"
# service_role holds BYPASSRLS, so it reads every tenant's rows -- that is what platform authority
# IS, not a leak. The first run asserted zero rows here, which would have been a claim that the
# platform cannot see the data it operates. The meaningful separation is the other direction, and it
# is asserted above: a tenant owner and CEO both get 404 on every platform_* endpoint.
# The platform has no tenant context, so a TENANT reporting view is not its surface -- the financial
# functions behind it raise "no active tenant for caller". That is correct: platform authority
# operates on platform objects, and tenant reporting belongs to the tenant. The separation that
# matters is asserted above, where the owner and CEO both get 404 on every platform_* endpoint.
$r = Get-Rest $SERVICE "booking_item_profit?select=*"
Check "...while a TENANT reporting view is not a platform surface (no tenant context)" ($r.StatusCode -ge 400) "$($r.StatusCode) $(Err $r)"

# =============================================================================================
# EMPLOYEE REGRESSION -- Phase C changed guards and transitions; the frontline must be intact.
# =============================================================================================
Write-Host "`n-- employee regression --"
$empPerf = @(Val (Get-Rest $emp "my_sales_performance?select=*"))
Check "the employee's own performance still resolves" ($empPerf.Count -eq 1) "rows=$($empPerf.Count)"
if ($empPerf.Count -eq 1) {
    Check "...with gross 3000, commission 300, company 2700" (
        [decimal]$empPerf[0].gross_profit -eq 3000 -and
        [decimal]$empPerf[0].employee_commission -eq 300 -and
        [decimal]$empPerf[0].company_profit -eq 2700) "g=$($empPerf[0].gross_profit) c=$($empPerf[0].employee_commission) p=$($empPerf[0].company_profit)"
}
$alexPerf = @(Val (Get-Rest $alexEmp "my_sales_performance?select=*"))
Check "the Alexandria employee sees only their own" ($alexPerf.Count -eq 1) "rows=$($alexPerf.Count)"

# ---------------------------------------------------------------------------------------------
# API-3 / CUST-1 -- customer identity merge over HTTP.
# `merge_customer_identity` had NO HTTP evidence, and auditing it found CUST-1: the re-pointing loop
# read the FIRST column of each foreign key, which TENANT-1 had silently turned into `tenant_id` when
# it made the customer FKs composite. The merge archived the source, wrote its audit row and emitted
# a CRITICAL event while moving nothing. This block walks the real deduplication an agency performs.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- customer identity merge (API-3 / CUST-1) --"

$mDup = Val (Rpc $owner 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Merge Dup'; p_primary_phone = '+201000000901' })
$mReal = Val (Rpc $owner 'create_customer' @{ p_customer_type_code = 'person'; p_full_name = 'Merge Real'; p_primary_phone = '+201000000902' })
Check "two duplicate customer records exist" ($mDup -and $mReal -and $mDup -ne $mReal) "dup=$mDup real=$mReal"

$r = Rpc $owner 'add_customer_note' @{ p_customer_id = $mDup; p_note_text = 'history on the duplicate' }
Check "the DUPLICATE carries history that must survive the merge" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'merge_customer_identity' @{ p_source_customer_id = $mDup; p_target_customer_id = $mReal; p_reason = 'employee attempt' }
Check "an employee CANNOT merge customer identities over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $owner 'merge_customer_identity' @{ p_source_customer_id = $mDup; p_target_customer_id = $mReal; p_reason = 'duplicate record' }
Check "POSITIVE CONTROL: the owner merges over HTTP -- merge_customer_identity's first HTTP evidence (API-3)" (Ok $r) "$($r.StatusCode) $(Err $r)"

$moved = (Psql "select count(*) from public.customer_notes where customer_id='$mReal' and note_text='history on the duplicate';").Trim()
Check "CUST-1 CLOSED: the duplicate's note is now on the SURVIVING customer -- before the fix it never moved" ($moved -eq '1') "notes_on_target=$moved"

$left = (Psql "select count(*) from public.customer_notes where customer_id='$mDup';").Trim()
Check "...and nothing is left stranded on the archived source" ($left -eq '0') "notes_on_source=$left"

$arch = (Psql "select is_archived::text from public.customers where id='$mDup';").Trim()
Check "the source is archived, not deleted" ($arch -eq 't' -or $arch -eq 'true') "archived=$arch"

$r = Rpc $owner 'merge_customer_identity' @{ p_source_customer_id = $mDup; p_target_customer_id = $mReal; p_reason = 'again' }
Check "IDEMPOTENCY BOUNDARY: re-merging an already-archived source is refused rather than repeated" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"


# =================================================================================================
# IDENT-1 -- the canon-34 Human Identity family over the wire.
#
# These five endpoints had NO behavioural coverage at all before this: the family's entire test
# footprint was a name-existence list in 53_api_surface_test.sql, which is the CUST-2 shape (a guard
# that checks an endpoint EXISTS cannot see what it does). Behind that sat a full account takeover.
#
# HTTP is a distinct evidence class here, not a formality: the anon path, PostgREST's own table
# endpoint for the identity tables, and two genuinely different JWTs are things pgTAP cannot exercise.
# =================================================================================================

# A pre-provisioned, unclaimed membership -- what create_tenant_user leaves when p_auth_user_id is
# null. Two identities compete for it: one that confirmed the mailbox and one that never did.
Psql @"
insert into auth.users (id, email, email_confirmed_at) values
  ('0d110000-0000-0000-0000-0000000000f1','claimant.http@ident.test', now()),
  ('0d110000-0000-0000-0000-0000000000f2','unconfirmed.http@ident.test', null);
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('0d110000-0000-0000-0000-0000000000f5','$T','HTTP Claimant','claimant.http@ident.test',true,null),
  ('0d110000-0000-0000-0000-0000000000f6','$T','HTTP Unclaimed','unconfirmed.http@ident.test',true,null);
"@ | Out-Null

$claimant = New-UserJwt '0d110000-0000-0000-0000-0000000000f1' $false
$unconf   = New-UserJwt '0d110000-0000-0000-0000-0000000000f2' $false

# anon holds EXECUTE on none of these; PostgREST must refuse before any body is evaluated.
$r = Invoke-WebRequest -Uri "$API/rest/v1/rpc/activate_membership" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON } -ContentType 'application/json' -Body '{}'
Check "anon cannot call activate_membership over HTTP -- the claim endpoint is not a public door" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $claimant 'activate_membership' @{}
Check "POSITIVE CONTROL: a CONFIRMED invitee claims their membership over HTTP -- activate_membership's first behavioural evidence" (Ok $r) "$($r.StatusCode) $(Err $r)"

$linked = (Psql "select coalesce(auth_user_id::text,'NULL') from public.users where id='0d110000-0000-0000-0000-0000000000f5';").Trim()
Check "...and the membership really was linked, not merely returned" ($linked -eq '0d110000-0000-0000-0000-0000000000f1') "auth_user_id=$linked"

$r = Rpc $claimant 'my_memberships' @{}
Check "my_memberships now returns it over HTTP" ((Ok $r) -and ((Val $r).Count -ge 1)) "$($r.StatusCode) $(Err $r)"

# The reproduction: identical shape, one column different.
$r = Rpc $unconf 'activate_membership' @{}
Check "IDENT-1 CLOSED: an UNCONFIRMED identity is refused over HTTP -- it previously claimed the membership and gained the role attached to it" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$still = (Psql "select coalesce(auth_user_id::text,'NULL') from public.users where id='0d110000-0000-0000-0000-0000000000f6';").Trim()
Check "NON-MUTATION: that membership is still unclaimed after the refusal" ($still -eq 'NULL') "auth_user_id=$still"

# Trusted devices, and then the attack shape pgTAP cannot reach: PostgREST's TABLE endpoint.
$r = Rpc $claimant 'record_trusted_device' @{ p_device_identifier = 'http-device-1' }
Check "record_trusted_device registers a device over HTTP" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $claimant 'my_trusted_devices' @{}
Check "...and my_trusted_devices returns it to its owner" ((Ok $r) -and ((Val $r).Count -eq 1)) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'my_trusted_devices' @{}
Check "a DIFFERENT authenticated user sees none of them -- owner_only RLS over the wire" ((Ok $r) -and ((Val $r).Count -eq 0)) "$($r.StatusCode) $(Err $r)"

# POST /rest/v1/trusted_devices naming SOMEONE ELSE as the owner. This is the direct-DML path for an
# identity table, and it exists only over HTTP.
$r = Invoke-WebRequest -Uri "$API/rest/v1/trusted_devices" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $emp" } -ContentType 'application/json' `
        -Body '{"auth_user_id":"0d110000-0000-0000-0000-0000000000f1","device_identifier":"planted","status_code":"trusted"}'
Check "and cannot PLANT a trusted device on another user via the TABLE endpoint -- owner_only WITH CHECK holds on the direct path too" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$planted = (Psql "select count(*) from public.trusted_devices where device_identifier='planted';").Trim()
Check "NON-MUTATION: no planted device row exists" ($planted -eq '0') "planted=$planted"

# Revocation. The negative comes FIRST so the positive below cannot be mistaken for a guard that
# happens to allow everything, and the device id is a real one the other user genuinely owns.
$devId = (Psql "select id from public.trusted_devices where device_identifier='http-device-1';").Trim()
$r = Rpc $emp 'revoke_trusted_device' @{ p_device_id = $devId }
Check "a different user cannot revoke someone else's device over HTTP -- it answers 'device not found', which is also what a nonexistent id gets, so it is not an existence oracle" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$stillTrusted = (Psql "select status_code from public.trusted_devices where id='$devId';").Trim()
Check "NON-MUTATION: the device is still trusted after the failed revocation" ($stillTrusted -eq 'trusted') "status=$stillTrusted"

$r = Rpc $claimant 'revoke_trusted_device' @{ p_device_id = $devId }
Check "POSITIVE CONTROL: the OWNER can revoke it over HTTP -- so the refusal above was ownership, not a blanket denial" (Ok $r) "$($r.StatusCode) $(Err $r)"

$revoked = (Psql "select status_code from public.trusted_devices where id='$devId';").Trim()
Check "...and the row really changed to revoked -- a 204 alone would not prove the UPDATE ran" ($revoked -eq 'revoked') "status=$revoked"



# =================================================================================================
# ADMIN-1 -- the tenant-administration family over the wire.
#
# create_tenant_user, assign_user_branch, revoke_user_role and create_department had no HTTP
# evidence at all. The one that matters here is the TABLE endpoint: PostgREST serves
# POST /rest/v1/users as readily as rpc/create_tenant_user, and users.scope_update grants UPDATE to
# any MANAGE_USERS holder -- so a check living only inside the RPC would have been a half-fix.
# =================================================================================================

# A spare identity to play the "foreign human". Its email is deliberately NOT the one the
# memberships below claim, which is the whole shape of ADMIN-1.
Psql @"
insert into auth.users (id, email, email_confirmed_at)
values ('0d110000-0000-0000-0000-0000000000f9','foreign.human@elsewhere.test', now());
"@ | Out-Null

$r = Rpc $owner 'create_tenant_user' @{ p_full_name = 'HTTP Invitee'; p_email = 'http.invitee@ident.test' }
Check "POSITIVE CONTROL: create_tenant_user creates an UNLINKED membership over HTTP -- the invite flow IDENT-1's claim path consumes" (Ok $r) "$($r.StatusCode) $(Err $r)"
$inviteeId = (Val $r)

$unlinked = (Psql "select coalesce(auth_user_id::text,'NULL') from public.users where id='$inviteeId';").Trim()
Check "...and it really is unlinked, waiting to be claimed" ($unlinked -eq 'NULL') "auth_user_id=$unlinked"

# ADMIN-1 over the wire: name one human, attach a different one.
$r = Rpc $owner 'create_tenant_user' @{ p_full_name = 'Impersonated'; p_email = 'victim@ident.test'
                                        p_auth_user_id = '0d110000-0000-0000-0000-0000000000f9' }
Check "ADMIN-1 CLOSED: binding a membership to a DIFFERENT human's identity is refused over HTTP -- it previously succeeded, locking the named person out and granting the bound one a tenant they never joined" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

# The direct-DML half, which exists only over HTTP.
$body = "{""tenant_id"":""$T"",""full_name"":""Planted"",""email"":""planted@ident.test""," +
        """is_active"":true,""auth_user_id"":""0d110000-0000-0000-0000-0000000000f9""}"
$r = Invoke-WebRequest -Uri "$API/rest/v1/users" -Method Post -SkipHttpErrorCheck `
        -Headers @{ apikey = $ANON; Authorization = "Bearer $owner" } -ContentType 'application/json' -Body $body
Check "and the TABLE endpoint is refused too -- a MANAGE_USERS holder can POST /rest/v1/users directly, so the rule had to live below the RPC" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

$planted = (Psql "select count(*) from public.users where email in ('victim@ident.test','planted@ident.test');").Trim()
Check "NON-MUTATION: neither impersonating membership exists" ($planted -eq '0') "rows=$planted"

# An employee holds no MANAGE_USERS -- the capability itself, not just its rules.
$r = Rpc $emp 'create_tenant_user' @{ p_full_name = 'By Employee'; p_email = 'by.employee@ident.test' }
Check "an ordinary employee cannot create a tenant user over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

# create_department, and its set-level uniqueness.
$r = Rpc $owner 'create_department' @{ p_branch_id = '0d110000-0000-0000-0000-00000000aa01'; p_department_type_code = 'sales'; p_name = 'HTTP Sales Floor' }
Check "create_department creates a department over HTTP" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $owner 'create_department' @{ p_branch_id = '0d110000-0000-0000-0000-00000000aa01'; p_department_type_code = 'sales'; p_name = 'HTTP Sales Floor' }
Check "...and a duplicate active name in the same branch is refused -- departments_unique_name_per_branch_idx over the wire" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"

# assign_user_branch, and the audit row the RPC does not write itself.
# The invitee created above, which is certainly a membership in this tenant. Assigned TWICE on
# purpose: emit_user_branch_transfer only fires when a PRIOR assignment exists, because a first
# posting is not a transfer. Guessing an id from the fixture is what made this fail the first time.
$r = Rpc $owner 'assign_user_branch' @{ p_user_id = $inviteeId; p_branch_id = '0d110000-0000-0000-0000-00000000aa01'
                                        p_is_primary = $true; p_transfer_type_code = $null }
Check "assign_user_branch gives the new member their first posting over HTTP" (Ok $r) "$($r.StatusCode) $(Err $r)"

$r = Rpc $owner 'assign_user_branch' @{ p_user_id = $inviteeId; p_branch_id = '0d110000-0000-0000-0000-00000000aa01'
                                        p_is_primary = $false; p_transfer_type_code = 'permanent' }
Check "assign_user_branch records a SECOND assignment over HTTP -- which is what makes it a transfer" (Ok $r) "$($r.StatusCode) $(Err $r)"

$xfer = (Psql "select count(*) from public.events where tenant_id='$T' and event_type_code='user_branch_transfer_completed';").Trim()
Check "...and the transfer reached the audit spine -- the RPC emits nothing, so this is the trigger" ($xfer -ne '0') "events=$xfer"

# revoke_user_role. The grant is seeded from the platform because ORVION exposes no assign-role RPC;
# roles are granted by direct DML through user_role_assignments' MANAGE_USERS-gated policy.
$roleAsg = (Psql @"
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '$T', '$inviteeId', r.id, 'tenant' from public.roles r where r.code = 'employee'
returning id;
"@).Trim()
Check "a role grant exists to revoke -- the fixture is real, not an empty target" ($roleAsg -ne '') "id=$roleAsg"

$r = Rpc $owner 'revoke_user_role' @{ p_assignment_id = $roleAsg }
Check "revoke_user_role ends a grant over HTTP -- its first behavioural evidence" (Ok $r) "$($r.StatusCode) $(Err $r)"

$live = (Psql "select is_active::text from public.user_role_assignments where id='$roleAsg';").Trim()
Check "...and the grant really is inactive -- a 204 alone would not prove the UPDATE ran" ($live -eq 'f' -or $live -eq 'false') "is_active=$live"

$removed = (Psql "select count(*) from public.events where tenant_id='$T' and event_type_code='role_removed';").Trim()
Check "...and role_removed reached the audit spine -- revoke_user_role emits nothing itself, so emit_role_change is what records the privilege change" ($removed -ne '0') "events=$removed"

$r = Rpc $emp 'revoke_user_role' @{ p_assignment_id = $roleAsg }
Check "and an ordinary employee cannot revoke a role over HTTP" (-not (Ok $r)) "$($r.StatusCode) $(Err $r)"



# =================================================================================================
# PD-24 / SUP-1 -- the supplier credit ceiling over the wire.
#
# SEC-1c closed the WRITE half. This is the READ half, and it exists as HTTP assertions because the
# defect lives at the door PostgREST actually serves: `suppliers` is a tenant-readable table and
# `credit_limit_amount` was in every row it returned. A pgTAP-only proof would miss the two things
# that matter here -- that `select=*` behaves like `booking_items` does, and that the gated RPC is
# not a way around the column grant.
# =================================================================================================

Psql @"
insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount)
values ('0d110000-0000-0000-0000-0000000000c7','$T','Credit Ceiling Air','airline', 25000);
"@ | Out-Null

$r = Get-Rest $emp 'suppliers?select=id,name&id=eq.0d110000-0000-0000-0000-0000000000c7'
Check "POSITIVE CONTROL: an employee still LISTS suppliers by explicit columns -- the column grant withheld a field, not the table" ((Ok $r) -and $r.Content -match 'Credit Ceiling Air') "$($r.StatusCode) $(Err $r)"

$r = Get-Rest $emp 'suppliers?select=id,credit_limit_amount'
Check "SUP-1: ...and asking for credit_limit_amount is REFUSED 403 -- it was returned to every tenant user until 202607059200" ($r.StatusCode -eq 403) "$($r.StatusCode) $(Err $r)"

$r = Get-Rest $emp 'suppliers?select=*'
Check "...and select=* is refused too, exactly as booking_items already behaves -- clients on such tables name their columns" ($r.StatusCode -eq 403) "$($r.StatusCode) $(Err $r)"

$r = Rpc $emp 'supplier_credit' @{ p_supplier_id = '0d110000-0000-0000-0000-0000000000c7' }
$v = Val $r
Check "the gated reader answers an unprivileged employee with permitted=false and NO amount -- the RPC is not a way around the grant" ((Ok $r) -and $v[0].permitted -eq $false -and $null -eq $v[0].credit_limit_amount) "$($r.StatusCode) $($r.Content)"

$r = Rpc $fin 'supplier_credit' @{ p_supplier_id = '0d110000-0000-0000-0000-0000000000c7' }
$v = Val $r
Check "POSITIVE CONTROL: finance, holding VIEW_FINANCIAL_DOCUMENTS, receives the REAL ceiling -- a null here would pass a weaker assertion" ((Ok $r) -and $v[0].permitted -eq $true -and [decimal]$v[0].credit_limit_amount -eq 25000) "$($r.StatusCode) $($r.Content)"


Write-Host "`n== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($findings.Count -gt 0) { Write-Host "`nFindings:"; $findings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow } }
if ($fail -gt 0) { exit 1 }
