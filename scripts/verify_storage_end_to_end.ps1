# ORVION -- end-to-end storage proof (WP-04-E).
#
# WHY THIS EXISTS AS A SCRIPT AND NOT A pgTAP TEST. pgTAP runs inside a database session. It can
# prove what SQL does and it cannot prove what HTTP does, because it never opens a socket. Storage
# was reported PROVEN at the database boundary and UNPROVEN end to end for four packages running,
# and API-1 -- the discovery that every `app.*` RPC is unreachable over HTTP -- is exactly the class
# of defect a suite that only speaks SQL can never see.
#
# So this exercises the REAL doors: the Storage HTTP API and PostgREST, with real bytes, as the real
# roles, against the local stack.
#
# ON THE KEYS BELOW. They are read from `npx supabase status` and belong to the local development
# stack only (`iss: supabase-demo`) -- the same well-known values Supabase publishes in its own
# documentation, on 127.0.0.1. No production credential is read, written, or required, and this
# script must never be pointed at a hosted project.

$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0
function Check($name, $condition, $detail = '') {
    if ($condition) { $script:pass++; Write-Host "  ok   $name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  FAIL $name  $detail" -ForegroundColor Red }
}

Write-Host "`n== ORVION storage end-to-end proof ==" -ForegroundColor Cyan

# ---------------------------------------------------------------------------------------------
# 0. Local stack coordinates.
# ---------------------------------------------------------------------------------------------
$status = (npx supabase status -o json 2>$null) | ConvertFrom-Json
$API = $status.API_URL
$SERVICE = $status.SERVICE_ROLE_KEY
$JWT_SECRET = $status.JWT_SECRET
if (-not $API -or -not $SERVICE) { throw "local stack is not running -- run 'npx supabase start'" }
Write-Host "API: $API"

function New-UserJwt([string]$sub, [bool]$aal2) {
    $hdr = '{"alg":"HS256","typ":"JWT"}'
    $exp = [int](Get-Date -UFormat %s) + 3600
    $aal = if ($aal2) { ',"aal":"aal2"' } else { '' }
    $pay = "{""sub"":""$sub"",""role"":""authenticated"",""aud"":""authenticated"",""exp"":$exp$aal}"
    function B64([byte[]]$b) { [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
    $h = B64 ([Text.Encoding]::UTF8.GetBytes($hdr))
    $p = B64 ([Text.Encoding]::UTF8.GetBytes($pay))
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($JWT_SECRET))
    $sig = B64 ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$h.$p")))
    "$h.$p.$sig"
}

function Psql([string]$sql) {
    # ON_ERROR_STOP is not optional here. Without it a failed teardown statement only prints and the
    # script sails on with a half-built fixture -- which is exactly how the first run of this file
    # reported "fixture seeded" and then found no rows.
    $sql | docker exec -i supabase_db_ORVION psql -U postgres -d postgres -q -t -A -v ON_ERROR_STOP=1 -f - 2>&1
}

# Invoke-WebRequest returns .Content as a byte[] for non-text content types (application/pdf here),
# so comparing it to a string silently fails even when the bytes are correct. That is what the first
# run of this script did -- it reported a mismatch while printing the right bytes.
function AsText($content) {
    if ($content -is [byte[]]) { return [Text.Encoding]::UTF8.GetString($content) }
    return [string]$content
}

function Req($method, $url, $headers, $body, $contentType) {
    $p = @{ Uri = $url; Method = $method; Headers = $headers; SkipHttpErrorCheck = $true }
    if ($null -ne $body) { $p.Body = $body }
    if ($contentType) { $p.ContentType = $contentType }
    Invoke-WebRequest @p
}

# ---------------------------------------------------------------------------------------------
# 1. Fixture. Two tenants so every denial has a real target, not an absent one.
# ---------------------------------------------------------------------------------------------
$TA = '0e2e0000-0000-0000-0000-0000000000a0'   # tenant A
$TB = '0e2e0000-0000-0000-0000-0000000000b0'   # tenant B
$AUA = '0e2e0000-0000-0000-0000-0000000000a1'  # auth user A
$AUB = '0e2e0000-0000-0000-0000-0000000000b1'
$DOC = '0e2e0000-0000-0000-0000-0000000000d1'

# PREFLIGHT. This script cannot tear its own fixture down, and that is the audit spine working:
# `public.events` is append-only (app.forbid_mutation refuses DELETE), and `events.tenant_id`
# references `tenants` with ON DELETE RESTRICT -- so once a fixture write has emitted an event, that
# tenant can never be deleted. Discovered by trying: the first run of this file failed with
# "append-only table: DELETE is not permitted on events". Rather than weaken an immutability
# guarantee to make a test script tidy, the script requires a clean database and says so.
$existing = (Psql "select count(*) from public.tenants where id in ('$TA','$TB');").Trim()
if ($existing -ne '0') {
    Write-Host "  fixture tenants already present -- run 'npx supabase db reset' first" -ForegroundColor Yellow
    exit 1
}

$fixture = @"
insert into auth.users (id, email) values ('$AUA','e2e-a@orvion.test'),('$AUB','e2e-b@orvion.test');
insert into public.tenants (id, name, slug, status) values
  ('$TA','E2E Alpha','e2e-alpha','active'), ('$TB','E2E Beta','e2e-beta','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id in ('$TA','$TB');
insert into public.branches (id, tenant_id, name, slug) values
  ('0e2e0000-0000-0000-0000-00000000aa01','$TA','A Branch','e2e-a-br'),
  ('0e2e0000-0000-0000-0000-00000000bb01','$TB','B Branch','e2e-b-br');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('0e2e0000-0000-0000-0000-00000000aa02','$TA','0e2e0000-0000-0000-0000-00000000aa01','sales','A Sales'),
  ('0e2e0000-0000-0000-0000-00000000bb02','$TB','0e2e0000-0000-0000-0000-00000000bb01','sales','B Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('0e2e0000-0000-0000-0000-00000000aa03','$TA','A Owner','e2e-a@orvion.test',true,'$AUA'),
  ('0e2e0000-0000-0000-0000-00000000bb03','$TB','B Owner','e2e-b@orvion.test',true,'$AUB');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('$TA','0e2e0000-0000-0000-0000-00000000aa03','0e2e0000-0000-0000-0000-00000000aa01','0e2e0000-0000-0000-0000-00000000aa02',true),
  ('$TB','0e2e0000-0000-0000-0000-00000000bb03','0e2e0000-0000-0000-0000-00000000bb01','0e2e0000-0000-0000-0000-00000000bb02',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant' from (values
  ('$TA'::uuid,'0e2e0000-0000-0000-0000-00000000aa03'::uuid),
  ('$TB'::uuid,'0e2e0000-0000-0000-0000-00000000bb03'::uuid)) v(t,u)
join public.roles r on r.code='owner';

-- One document with TWO versions: v1 superseded (and aged), v2 current. The whole retention path
-- needs a superseded version to act on, and the authorization path needs a current one to read.
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code)
values ('$DOC','$TA','passport','E2E Passport','active');
insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, is_current, uploaded_at)
values ('$TA','$DOC',1,'v1.pdf','pdf',false, now() - interval '400 days'),
       ('$TA','$DOC',2,'v2.pdf','pdf',true,  now());
update public.documents set current_version_id =
  (select id from public.document_versions where document_id='$DOC' and version_number=2)
where id='$DOC';
select 'FIXTURE_OK';
"@
$r = Psql $fixture
Check "fixture seeded" ($r -match 'FIXTURE_OK') "$r"

$V1 = (Psql "select storage_path from public.document_versions where document_id='$DOC' and version_number=1;").Trim()
$V2 = (Psql "select storage_path from public.document_versions where document_id='$DOC' and version_number=2;").Trim()
Check "v1 path is tenant-prefixed" ($V1.StartsWith("$TA/")) $V1
Check "v2 path is tenant-prefixed" ($V2.StartsWith("$TA/")) $V2

$jwtA = New-UserJwt $AUA $true
$jwtB = New-UserJwt $AUB $true
$hdrA = @{ apikey = $SERVICE; Authorization = "Bearer $jwtA" }
$hdrB = @{ apikey = $SERVICE; Authorization = "Bearer $jwtB" }
$hdrS = @{ apikey = $SERVICE; Authorization = "Bearer $SERVICE" }

$bytesV1 = [Text.Encoding]::UTF8.GetBytes("%PDF-1.4 ORVION E2E v1")
$bytesV2 = [Text.Encoding]::UTF8.GetBytes("%PDF-1.4 ORVION E2E v2")

# ---------------------------------------------------------------------------------------------
# 2. UPLOAD -- real bytes, as a real authenticated user, over HTTP.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- upload --"
$up1 = Req POST "$API/storage/v1/object/documents/$V1" $hdrA $bytesV1 'application/pdf'
Check "authorized user uploads v1" ($up1.StatusCode -eq 200) "$($up1.StatusCode) $($up1.Content)"
$up2 = Req POST "$API/storage/v1/object/documents/$V2" $hdrA $bytesV2 'application/pdf'
Check "authorized user uploads v2" ($up2.StatusCode -eq 200) "$($up2.StatusCode) $($up2.Content)"

$objCount = (Psql "select count(*) from storage.objects where bucket_id='documents';").Trim()
Check "both objects exist in storage.objects" ($objCount -eq '2') "count=$objCount"

# The negative that matters: an object whose path has no document_versions row must be refused by
# the INSERT policy, which is what makes 'orphan objects cannot be created by a tenant' structural.
$upOrphan = Req POST "$API/storage/v1/object/documents/$TA/deadbeef-0000-0000-0000-000000000000/1" $hdrA $bytesV1 'application/pdf'
Check "upload with no metadata row is REFUSED" ($upOrphan.StatusCode -ge 400) "$($upOrphan.StatusCode)"

# Cross-tenant write: tenant B's user aiming at tenant A's prefix.
$upCross = Req POST "$API/storage/v1/object/documents/$V1.b" $hdrB $bytesV1 'application/pdf'
Check "cross-tenant upload is REFUSED" ($upCross.StatusCode -ge 400) "$($upCross.StatusCode)"

# ---------------------------------------------------------------------------------------------
# 3. DOWNLOAD -- authorization on the bytes is authorization on the row.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- download --"
$dl = Req GET "$API/storage/v1/object/documents/$V2" $hdrA $null $null
Check "owner downloads its own object" ($dl.StatusCode -eq 200) "$($dl.StatusCode)"
Check "downloaded bytes match what was uploaded" ((AsText $dl.Content) -eq '%PDF-1.4 ORVION E2E v2') "$(AsText $dl.Content)"

$dlCross = Req GET "$API/storage/v1/object/documents/$V2" $hdrB $null $null
Check "other tenant CANNOT download it" ($dlCross.StatusCode -ge 400) "$($dlCross.StatusCode)"

$dlAnon = Req GET "$API/storage/v1/object/documents/$V2" @{} $null $null
Check "unauthenticated CANNOT download it" ($dlAnon.StatusCode -ge 400) "$($dlAnon.StatusCode)"

# ---------------------------------------------------------------------------------------------
# 4. SIGNED URL -- the delivery mechanism a private bucket actually uses.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- signed url --"
$sign = Req POST "$API/storage/v1/object/sign/documents/$V2" $hdrA '{"expiresIn":60}' 'application/json'
Check "owner can mint a signed URL" ($sign.StatusCode -eq 200) "$($sign.StatusCode) $($sign.Content)"
if ($sign.StatusCode -eq 200) {
    $signed = ($sign.Content | ConvertFrom-Json).signedURL
    $fetch = Req GET "$API/storage/v1$signed" @{} $null $null
    Check "signed URL serves the bytes with NO auth header" ($fetch.StatusCode -eq 200 -and (AsText $fetch.Content) -eq '%PDF-1.4 ORVION E2E v2') "$($fetch.StatusCode) $(AsText $fetch.Content)"
}
$signCross = Req POST "$API/storage/v1/object/sign/documents/$V2" $hdrB '{"expiresIn":60}' 'application/json'
Check "other tenant CANNOT mint a signed URL for it" ($signCross.StatusCode -ge 400) "$($signCross.StatusCode)"

# ---------------------------------------------------------------------------------------------
# 5. RECONCILIATION against a bucket that actually holds objects -- previously untestable.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- reconciliation --"
$rec = Psql "select app.reconcile_document_storage()::text;"
$missing = (Psql "select count(*) from public.document_storage_findings where tenant_id='$TA' and finding_type_code='missing_object' and resolved_at is null;").Trim()
Check "no missing_object findings -- every version has its bytes" ($missing -eq '0') "count=$missing  run=$rec"
$orphans = (Psql "select count(*) from public.document_storage_findings where finding_type_code='orphan_object' and resolved_at is null;").Trim()
Check "no orphan_object findings -- every object has its row" ($orphans -eq '0') "count=$orphans"

# Now make a REAL orphan the only way one can happen: delete the metadata, leave the bytes.
Psql "delete from public.document_storage_findings where tenant_id='$TA'; delete from public.document_versions where document_id='$DOC' and version_number=1;" | Out-Null
Psql "select app.reconcile_document_storage()::text;" | Out-Null
$orphan2 = (Psql "select count(*) from public.document_storage_findings where tenant_id='$TA' and finding_type_code='orphan_object' and storage_path='$V1';").Trim()
Check "a REAL orphan object is detected" ($orphan2 -eq '1') "count=$orphan2"
$orphanCross = (Psql "select count(*) from public.document_storage_findings where tenant_id='$TB';").Trim()
Check "tenant B got no findings for tenant A's object" ($orphanCross -eq '0') "count=$orphanCross"

# ---------------------------------------------------------------------------------------------
# 6. RETENTION -> EXECUTOR CONTRACT -> BYTES DESTROYED.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- retention and the executor --"

# PAR-2 (2026-08-29): CAPTURE THE SHIPPED DEFINITION BEFORE OVERRIDING IT.
# This script overrides `app.document_retention_days` to exercise retention, and section 8 used to
# "restore" it by RETYPING an equivalent one-liner (`as 'select null::integer'`) instead of putting
# back the migration's `$fn$ ... $fn$` body. Behaviour was identical; the TEXT was not -- and the
# parity guard compares `pg_get_functiondef`. So every run of this suite left the local database
# permanently unequal to the repository, in exactly one function.
#
# That is the root cause PAR-1, PAR-1a and PAR-1b were all circling: three sessions chased this one
# function, and PAR-1b concluded local "had been hand-modified mid-session" -- close, but wrong in
# the way that mattered. It was not a hand edit. It was this script, doing it deterministically on
# every run, which is why the drift kept coming back. One of those sessions then read the polluted
# local body and pushed it to Primary.
#
# The fix reads the definition FROM THE DATABASE rather than restating it, so it cannot drift from
# the migration no matter how the migration later changes.
$RetentionFnDef = ((Psql "select pg_get_functiondef('app.document_retention_days()'::regprocedure);") -join "`n").Trim()
if ([string]::IsNullOrWhiteSpace($RetentionFnDef) -or $RetentionFnDef -notmatch 'document_retention_days') {
    throw "PAR-2: could not capture the shipped app.document_retention_days definition -- refusing to run, because this suite would otherwise leave the database drifted with no way back."
}
# Capture the FINGERPRINT in SQL, using the parity guard's own expression. The first version of this
# check recomputed that normalization in PowerShell and failed against a restore that was actually
# correct -- which is PAR-1a's lesson repeating one layer over: do not reimplement the comparison,
# reuse it. Both sides are now computed by the same engine with the same expression.
$RetentionFnMd5 = (Psql "select md5(regexp_replace(regexp_replace(pg_get_functiondef('app.document_retention_days()'::regprocedure), '--[^' || chr(10) || ']*', '', 'g'), '\s+', ' ', 'g'));").Trim()

# Rebuild v1 metadata so there is a genuine superseded version to age out.
Psql @"
delete from public.document_storage_findings where tenant_id='$TA';
insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, is_current, uploaded_at)
values ('$TA','$DOC',1,'v1.pdf','pdf',false, now() - interval '400 days');
create or replace function app.document_retention_days() returns integer language sql immutable set search_path='' as 'select 30::integer';
select app.reconcile_document_storage()::text;
"@ | Out-Null

$expired = (Psql "select count(*) from public.document_storage_findings where tenant_id='$TA' and finding_type_code='retention_expired' and resolved_at is null;").Trim()
Check "retention produces exactly one expired finding" ($expired -eq '1') "count=$expired"

# SCHED-1: the backlog BEFORE the executor runs. Nothing invokes the executor on a schedule yet --
# every route needs one owner-placed secret -- so the least ORVION can do is make the gap visible.
# The count is asserted against the claim below, because a monitor that measures a different
# population than the worker consumes reports zero while work piles up.
$backlog = Req POST "$API/rest/v1/rpc/storage_action_backlog" ($hdrS + @{'Content-Type' = 'application/json' }) '{}' 'application/json'
Check "public.storage_action_backlog is REACHABLE over HTTP by the platform" ($backlog.StatusCode -eq 200) "$($backlog.StatusCode) $($backlog.Content)"
$pending = if ($backlog.StatusCode -eq 200) { @($backlog.Content | ConvertFrom-Json)[0].pending_actions } else { -1 }

$backlogAnon = Req POST "$API/rest/v1/rpc/storage_action_backlog" @{apikey = $status.ANON_KEY; Authorization = "Bearer $($status.ANON_KEY)"; 'Content-Type' = 'application/json' } '{}' 'application/json'
Check "anon CANNOT read how far behind the platform is" ($backlogAnon.StatusCode -ge 400) "$($backlogAnon.StatusCode)"
$backlogUser = Req POST "$API/rest/v1/rpc/storage_action_backlog" ($hdrA + @{'Content-Type' = 'application/json' }) '{}' 'application/json'
Check "...nor can an authenticated tenant user -- operational state is not a tenant surface" ($backlogUser.StatusCode -ge 400) "$($backlogUser.StatusCode)"

# SCHED-2: the same boundary for the scheduled-job health surface. It lives in this script rather
# than a new one because this is where ORVION's PLATFORM-OPERATIONS HTTP surface is proven, and a
# second script would split one boundary across two files. pgTAP cannot prove reachability -- API-1
# was 600 green assertions over an entirely unreachable API -- so the endpoint is exercised here.
$health = Req POST "$API/rest/v1/rpc/scheduled_job_health" ($hdrS + @{'Content-Type' = 'application/json' }) '{}' 'application/json'
Check "public.scheduled_job_health is REACHABLE over HTTP by the platform" ($health.StatusCode -eq 200) "$($health.StatusCode) $($health.Content)"
$healthAnon = Req POST "$API/rest/v1/rpc/scheduled_job_health" @{apikey = $status.ANON_KEY; Authorization = "Bearer $($status.ANON_KEY)"; 'Content-Type' = 'application/json' } '{}' 'application/json'
Check "anon CANNOT read which tenants' scheduled work is stuck" ($healthAnon.StatusCode -ge 400) "$($healthAnon.StatusCode)"
$healthUser = Req POST "$API/rest/v1/rpc/scheduled_job_health" ($hdrA + @{'Content-Type' = 'application/json' }) '{}' 'application/json'
Check "...nor can an authenticated tenant user -- it names OTHER tenants" ($healthUser.StatusCode -ge 400) "$($healthUser.StatusCode)"

# The executor's contract, over HTTP, exactly as the Edge Function calls it.
$claim = Req POST "$API/rest/v1/rpc/claim_storage_actions" ($hdrS + @{'Content-Type' = 'application/json' }) '{"p_limit":50}' 'application/json'
Check "public.claim_storage_actions is REACHABLE over HTTP" ($claim.StatusCode -eq 200) "$($claim.StatusCode) $($claim.Content)"
$actions = @()
if ($claim.StatusCode -eq 200) { $actions = @($claim.Content | ConvertFrom-Json) }
Check "it hands out exactly the one eligible action" ($actions.Count -eq 1) "count=$($actions.Count)"
Check "...and the backlog counted exactly that same work -- one definition of outstanding, not two" ($pending -eq $actions.Count) "backlog=$pending claimed=$($actions.Count)"

$claimAnon = Req POST "$API/rest/v1/rpc/claim_storage_actions" @{apikey = $status.ANON_KEY; Authorization = "Bearer $($status.ANON_KEY)"; 'Content-Type' = 'application/json' } '{}' 'application/json'
Check "anon CANNOT claim storage actions" ($claimAnon.StatusCode -ge 400) "$($claimAnon.StatusCode)"
$claimUser = Req POST "$API/rest/v1/rpc/claim_storage_actions" ($hdrA + @{'Content-Type' = 'application/json' }) '{}' 'application/json'
Check "an authenticated tenant user CANNOT claim storage actions" ($claimUser.StatusCode -ge 400) "$($claimUser.StatusCode)"

if ($actions.Count -eq 1) {
    $a = $actions[0]
    Check "the action names tenant A's own prefix" ($a.storage_path.StartsWith("$TA/")) $a.storage_path

    # The byte operation, through the supported Storage API -- the step SQL cannot perform.
    $del = Req DELETE "$API/storage/v1/object/documents/$($a.storage_path)" $hdrS $null $null
    Check "executor destroys the object through the Storage API" ($del.StatusCode -eq 200) "$($del.StatusCode) $($del.Content)"

    $res = Req POST "$API/rest/v1/rpc/resolve_storage_finding" ($hdrS + @{'Content-Type' = 'application/json' }) (@{p_finding_id = $a.finding_id; p_resolution_code = 'object_deleted'; p_note = 'e2e' } | ConvertTo-Json) 'application/json'
    Check "executor reports the outcome over HTTP" ($res.StatusCode -eq 200) "$($res.StatusCode) $($res.Content)"

    $gone = (Psql "select count(*) from storage.objects where name='$($a.storage_path)';").Trim()
    Check "the bytes are actually gone" ($gone -eq '0') "count=$gone"
    $metaGone = (Psql "select count(*) from public.document_versions where document_id='$DOC' and version_number=1;").Trim()
    Check "the superseded metadata row is gone with them" ($metaGone -eq '0') "count=$metaGone"
    $survives = (Psql "select count(*) from public.document_storage_findings where id='$($a.finding_id)' and storage_path is not null and resolution_code='object_deleted';").Trim()
    Check "the finding SURVIVES as the audit record" ($survives -eq '1') "count=$survives"
    $evt = (Psql "select count(*) from public.events where tenant_id='$TA' and event_type_code='document_archived' and new_state='destroyed';").Trim()
    Check "a document_archived event records the destruction" ($evt -eq '1') "count=$evt"

    # v2 -- the CURRENT version -- must be untouched by all of this.
    $v2still = (Psql "select count(*) from storage.objects where name='$V2';").Trim()
    Check "the CURRENT version's bytes are untouched" ($v2still -eq '1') "count=$v2still"
}

# ---------------------------------------------------------------------------------------------
# 7. IDEMPOTENCY and the failure path.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- idempotency and failure --"
$claim2 = Req POST "$API/rest/v1/rpc/claim_storage_actions" ($hdrS + @{'Content-Type' = 'application/json' }) '{}' 'application/json'
$actions2 = @($claim2.Content | ConvertFrom-Json)
Check "a second run claims nothing -- the work is done" ($actions2.Count -eq 0) "count=$($actions2.Count)"

# FND-1: a reported failure must leave the finding OPEN, or failed work disappears forever.
# A fresh orphan is manufactured the only way a real one occurs -- bytes that no metadata row names.
# service_role inserts it directly, which is exactly what a PUT-then-rollback leaves behind. (The
# first run of this script reused the earlier orphan finding, which by this point the executor had
# already consumed, so $openId was null -- a fixture bug, not a defect.)
Req POST "$API/storage/v1/object/documents/$TA/0000dead-0000-0000-0000-00000000000f/1" $hdrS ([Text.Encoding]::UTF8.GetBytes('orphan')) 'application/pdf' | Out-Null
Psql "select app.reconcile_document_storage()::text;" | Out-Null
$openId = (Psql "select id from public.document_storage_findings where tenant_id='$TA' and finding_type_code='orphan_object' and resolved_at is null limit 1;").Trim()
Check "the manufactured orphan is detected" ([bool]$openId) "id=$openId"
if ($openId) {
    $failRes = Req POST "$API/rest/v1/rpc/resolve_storage_finding" ($hdrS + @{'Content-Type' = 'application/json' }) (@{p_finding_id = $openId; p_resolution_code = 'failed'; p_note = 'simulated storage outage' } | ConvertTo-Json) 'application/json'
    Check "a failure is accepted" ($failRes.StatusCode -eq 200) "$($failRes.StatusCode) $($failRes.Content)"
    $stillOpen = (Psql "select (resolved_at is null)::text || '/' || attempt_count::text from public.document_storage_findings where id='$openId';").Trim()
    Check "FND-1: the finding stays OPEN and the attempt is counted" ($stillOpen -eq 'true/1') "state=$stillOpen"
}

# ---------------------------------------------------------------------------------------------
# 7b. DOC-LC-1 -- canon 26's Document Lifecycle machine, over the wire.
#     Placed LAST because it archives the fixture document, which every section above still needs.
#     The PATCH is the real-world shape of the original reproduction: PostgREST serves TABLES, not
#     only RPCs, so `PATCH /rest/v1/documents` is the door a browser client actually has -- and it
#     was the door with no state machine behind it. `archive_document` also had NO HTTP evidence
#     before this block (API-3), which is a poor thing to be true of the endpoint that retires a
#     customer's passport.
# ---------------------------------------------------------------------------------------------
Write-Host "`n-- document lifecycle (DOC-LC-1) --"
$hdrJson = $hdrA + @{ 'Content-Type' = 'application/json' }

$toSup = Req PATCH "$API/rest/v1/documents?id=eq.$DOC" $hdrJson '{"lifecycle_status_code":"superseded"}' 'application/json'
Check "active -> superseded is refused over HTTP, even for the OWNER -- nothing produces that state (DOC-LC-2)" `
      ($toSup.StatusCode -ge 400) "$($toSup.StatusCode) 197121.Content)"

$lifeNow = (Psql "select lifecycle_status_code from public.documents where id='$DOC';").Trim()
Check "NON-MUTATION: the document is still active after the refused PATCH" ($lifeNow -eq 'active') "lifecycle=$lifeNow"

$arch = Req POST "$API/rest/v1/rpc/archive_document" $hdrJson "{""p_document_id"":""$DOC"",""p_reason"":""passport expired""}" 'application/json'
Check "POSITIVE CONTROL: an ARCHIVE_DOCUMENT holder archives over HTTP -- archive_document's first HTTP evidence (API-3)" `
      ($arch.StatusCode -eq 200) "$($arch.StatusCode) 197121.Content)"

$after = (Psql "select lifecycle_status_code || '/' || is_archived::text from public.documents where id='$DOC';").Trim()
Check "...and both representations moved together" ($after -eq 'archived/true') "state=$after"

$toActive = Req PATCH "$API/rest/v1/documents?id=eq.$DOC" $hdrJson '{"lifecycle_status_code":"active"}' 'application/json'
Check "archived -> active is refused over HTTP -- canon 26 lists no way back, and an un-archive anyone could do would make the archive meaningless" `
      ($toActive.StatusCode -ge 400) "$($toActive.StatusCode) 197121.Content)"

$finalLife = (Psql "select lifecycle_status_code from public.documents where id='$DOC';").Trim()
Check "NON-MUTATION: still archived after the refused un-archive" ($finalLife -eq 'archived') "lifecycle=$finalLife"

# PARENT-1 (202607059400). The document is genuinely archived at this point, over HTTP, so this is
# the real client asking both doors the same question.
$verRpc = Req POST "$API/rest/v1/rpc/add_document_version" $hdrJson `
          "{""p_document_id"":""$DOC"",""p_file_name"":""v9.pdf"",""p_file_type_code"":""pdf"",""p_file_size"":900}" 'application/json'
Check "POSITIVE CONTROL: add_document_version refuses a version on an ARCHIVED document over HTTP" `
      ($verRpc.StatusCode -ge 400) "$($verRpc.StatusCode)"

$verTbl = Req POST "$API/rest/v1/document_versions" $hdrJson `
          "{""tenant_id"":""$TA"",""document_id"":""$DOC"",""version_number"":0,""file_name"":""v9.pdf"",""file_type_code"":""pdf"",""file_size"":900,""storage_path"":""derived-anyway"",""is_current"":false}" 'application/json'
Check "PARENT-1: ...and so does the TABLE door -- before 202607059400 this POST returned 201 and versioned a closed record" `
      ($verTbl.StatusCode -ge 400) "$($verTbl.StatusCode)"

$verCount = (Psql "select count(*) from public.document_versions where document_id='$DOC';").Trim()
Check "NON-MUTATION: no version was added by either refusal" ($verCount -eq '1') "versions=$verCount"

# ---------------------------------------------------------------------------------------------
# 8. Restore the shipped retention policy and clean up.
# ---------------------------------------------------------------------------------------------
# PAR-2: restore the definition captured above, VERBATIM. Not a retyped equivalent -- see the note
# in section 6. `create or replace function` preserves the existing ACL, so the migration's
# `revoke execute ... from public` survives; that is asserted below rather than assumed.
Psql $RetentionFnDef | Out-Null

# =================================================================================================
# SPEC-154-B -- a financial document follows the work, not the department (`202607058700`).
#
# pgTAP proves this against the table. This proves it on the door a browser client actually has:
# `authenticated` holds SELECT on `public.documents`, so PostgREST serves it beside every RPC, and a
# rule that holds only in the database session is half a rule (BOOK-1).
#
# Two employees, same tenant, same branch, same department, same role, same permissions. One owns
# the booking; the other does not. Both documents are created by the OWNER, so `created_by` explains
# no read below.
# =================================================================================================
$AUE1 = '0e2e0000-0000-0000-0000-0000000000e1'
$AUE2 = '0e2e0000-0000-0000-0000-0000000000e2'
$E1   = '0e2e0000-0000-0000-0000-00000000aa11'
$E2   = '0e2e0000-0000-0000-0000-00000000aa12'
$DINV = '0e2e0000-0000-0000-0000-0000000000d7'
$DQUO = '0e2e0000-0000-0000-0000-0000000000d8'
$fx154 = @"
insert into auth.users (id, email) values ('$AUE1','e2e-resp@orvion.test'),('$AUE2','e2e-coll@orvion.test');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('$E1','$TA','A Responsible','e2e-resp@orvion.test',true,'$AUE1'),
  ('$E2','$TA','A Colleague','e2e-coll@orvion.test',true,'$AUE2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('$TA','$E1','0e2e0000-0000-0000-0000-00000000aa01','0e2e0000-0000-0000-0000-00000000aa02',true),
  ('$TA','$E2','0e2e0000-0000-0000-0000-00000000aa01','0e2e0000-0000-0000-0000-00000000aa02',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '$TA', v.u, r.id, 'tenant' from (values ('$E1'::uuid),('$E2'::uuid)) v(u)
join public.roles r on r.code='employee';
insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id)
values ('0e2e0000-0000-0000-0000-0000000000c7','$TA','person','E2E 154B Customer','0e2e0000-0000-0000-0000-00000000aa01');
insert into public.bookings (id, tenant_id, customer_id, title, booking_reference, branch_id, department_id,
                             owner_user_id, owner_branch_id, owner_department_id, booking_status_code)
values ('0e2e0000-0000-0000-0000-0000000000b7','$TA','0e2e0000-0000-0000-0000-0000000000c7','E2E 154B booking','E2E-154B-1',
        '0e2e0000-0000-0000-0000-00000000aa01','0e2e0000-0000-0000-0000-00000000aa02',
        '$E1','0e2e0000-0000-0000-0000-00000000aa01','0e2e0000-0000-0000-0000-00000000aa02','draft');
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential, created_by) values
  ('$DINV','$TA','invoice','E2E 154B invoice','active',false,'0e2e0000-0000-0000-0000-00000000aa03'),
  ('$DQUO','$TA','quotation','E2E 154B quotation','active',false,'0e2e0000-0000-0000-0000-00000000aa03');
insert into public.document_links (tenant_id, document_id, booking_id) values
  ('$TA','$DINV','0e2e0000-0000-0000-0000-0000000000b7'),
  ('$TA','$DQUO','0e2e0000-0000-0000-0000-0000000000b7');
select 'FX154_OK';
"@
$r154 = Psql $fx154
Check "SPEC-154-B fixture seeded" ($r154 -match 'FX154_OK') "$r154"

$hdrE1 = @{ apikey = $SERVICE; Authorization = "Bearer $(New-UserJwt $AUE1 $false)" }
$hdrE2 = @{ apikey = $SERVICE; Authorization = "Bearer $(New-UserJwt $AUE2 $false)" }

$bkgE2 = Req GET "$API/rest/v1/bookings?id=eq.0e2e0000-0000-0000-0000-0000000000b7&select=id" $hdrE2 $null $null
Check "SPEC-154-B positive control: the colleague reads the BOOKING over HTTP -- department continuity is intact, so the denial below means something" `
    ($bkgE2.StatusCode -eq 200 -and (AsText $bkgE2.Content) -match '0e2e0000-0000-0000-0000-0000000000b7') "$($bkgE2.StatusCode) $(AsText $bkgE2.Content)"

$invE1 = Req GET "$API/rest/v1/documents?id=eq.$DINV&select=id" $hdrE1 $null $null
Check "SPEC-154-B: the RESPONSIBLE employee reads the invoice document over HTTP" `
    ($invE1.StatusCode -eq 200 -and (AsText $invE1.Content) -match $DINV) "$($invE1.StatusCode) $(AsText $invE1.Content)"

$invE2 = Req GET "$API/rest/v1/documents?id=eq.$DINV&select=id" $hdrE2 $null $null
Check "SPEC-154-B: the DEPARTMENT COLLEAGUE gets an EMPTY set for the same document -- RLS filters, it does not raise" `
    ($invE2.StatusCode -eq 200 -and (AsText $invE2.Content).Trim() -eq '[]') "$($invE2.StatusCode) $(AsText $invE2.Content)"

$quoE2 = Req GET "$API/rest/v1/documents?id=eq.$DQUO&select=id" $hdrE2 $null $null
Check "SPEC-154-B negative control: that same colleague still reads the QUOTATION document -- the change is confined to financial types" `
    ($quoE2.StatusCode -eq 200 -and (AsText $quoE2.Content) -match $DQUO) "$($quoE2.StatusCode) $(AsText $quoE2.Content)"

$invOwner = Req GET "$API/rest/v1/documents?id=eq.$DINV&select=id" $hdrA $null $null
Check "SPEC-154-B: the tenant owner still reads it -- finance/management visibility is untouched" `
    ($invOwner.StatusCode -eq 200 -and (AsText $invOwner.Content) -match $DINV) "$($invOwner.StatusCode) $(AsText $invOwner.Content)"

# PAR-2 positive control: the point of this suite is that it must leave the database EQUAL to the
# repository. Proving the restore actually happened is what turns that from an intention into a
# guarantee -- and it is the assertion whose absence let three sessions chase the same drift.
$restored = (Psql "select md5(regexp_replace(regexp_replace(pg_get_functiondef('app.document_retention_days()'::regprocedure), '--[^' || chr(10) || ']*', '', 'g'), '\s+', ' ', 'g'));").Trim()
Check "PAR-2: the shipped retention policy is restored VERBATIM, so local still equals the repository" ($restored -eq $RetentionFnMd5) "restored=$restored captured=$RetentionFnMd5"
$pubExec = (Psql "select has_function_privilege('public','app.document_retention_days()','execute')::text;").Trim()
Check "PAR-2: and the revoke from PUBLIC survived the replace" ($pubExec -eq 'false') "public_execute=$pubExec"
$hdrCleanup = $hdrS
foreach ($p in @($V2, "$TA/0000dead-0000-0000-0000-00000000000f/1")) { Req DELETE "$API/storage/v1/object/documents/$p" $hdrCleanup $null $null | Out-Null }
# Remove what CAN be removed. `events`, `tenants` and `users` are deliberately left: the spine is
# append-only by design, so the tenant rows its events reference cannot be deleted either. On the
# local stack `npx supabase db reset` is the reset -- which is the correct answer, because the
# alternative is an audit trail that a script can erase.
Psql @"
update public.documents set current_version_id = null where tenant_id in ('$TA','$TB');
delete from public.document_storage_findings where tenant_id in ('$TA','$TB');
delete from public.document_links where tenant_id in ('$TA','$TB');
delete from public.document_versions where tenant_id in ('$TA','$TB');
delete from public.documents where tenant_id in ('$TA','$TB');
delete from public.bookings where tenant_id in ('$TA','$TB');
delete from public.customers where tenant_id in ('$TA','$TB');
"@ | Out-Null

Write-Host "`n== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
