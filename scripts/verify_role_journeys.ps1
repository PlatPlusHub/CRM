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

Write-Host "`n== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($findings.Count -gt 0) { Write-Host "`nFindings:"; $findings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow } }
if ($fail -gt 0) { exit 1 }
