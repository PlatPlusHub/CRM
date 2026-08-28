# ORVION -- generate reports/master/MASTER_API_CONTRACT.md from the LIVE database.
#
# Why generated rather than written: a hand-maintained interface document is a claim about the
# system, and this programme has spent three sessions learning what an unverified claim costs. This
# one is DERIVED from pg_catalog and app.status_transitions, and `check_database_parity.ps1`
# regenerates it and fails on any difference -- the same shape as ai-map.json and Check 7.
#
# What it deliberately does NOT do: invent. Where a property cannot be derived (a request body's
# semantic meaning, a business error's remedy), the contract says so rather than guessing.
#
# Usage: pwsh -File scripts/generate-api-contract.ps1 [-OutFile <path>]

param(
    [string]$Container = 'supabase_db_ORVION',
    [string]$OutFile = ''
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutFile) { $OutFile = Join-Path $RepoRoot 'reports/master/MASTER_API_CONTRACT.md' }

function Psql([string]$sql) {
    $out = $sql | docker exec -i $Container psql -U postgres -d postgres -q -t -A -F "`t" -v ON_ERROR_STOP=1 -f - 2>&1
    if ($LASTEXITCODE -ne 0) { throw "psql failed: $out" }
    return $out
}

# -------------------------------------------------------------------------------------------------
# 1. RPC endpoints. The permission is read from the `app` implementation of the same name:
#    a literal app.authorize('X') where there is one; otherwise the transition table, which is what
#    app.enforce_status_transition actually reads at runtime; otherwise an explicit classification.
# -------------------------------------------------------------------------------------------------
$rpcSql = @'
with ep as (
    select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args,
           pg_get_function_result(p.oid) as result, p.prosecdef
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.prorettype <> 'trigger'::regtype
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
),
impl as (
    select e.*,
           (select pg_get_functiondef(ip.oid)
              from pg_proc ip join pg_namespace inn on inn.oid = ip.pronamespace
             where inn.nspname = 'app' and ip.proname = e.proname limit 1) as body
    from ep e
)
select i.proname,
       i.args,
       i.result,
       case when i.prosecdef then 'definer' else 'invoker' end,
       -- COMPOSED, not first-match-wins. `advance_lead` charges CLOSE_LEAD on closure AND the
       -- TRANS-2 handler rule on the rest; a CASE that stopped at the literal would report half of
       -- its authority model, which is the understatement this whole contract exists to prevent.
       coalesce(nullif(concat_ws(' + ',
         (select string_agg(distinct m[1], ' or ' order by m[1])
            from regexp_matches(coalesce(i.body,''), 'app\.authorize\(''([A-Z_]+)''\)', 'g') m),
         case when i.proname like 'advance\_%'
              then (select 'per transition: ' || string_agg(distinct st.permission_key, ', ' order by st.permission_key)
                      from app.status_transitions st
                     where st.table_name = replace(i.proname,'advance_','') || 's'
                       and st.permission_key is not null) end,
         case when coalesce(i.body,'') ~ 'app\.require_lead_handler'
              then 'assigned handler or ASSIGN_LEAD (TRANS-2)' end,
         case when coalesce(i.body,'') ~ 'app\.has_permission'
                   and coalesce(i.body,'') !~ 'app\.authorize\('
              then 'inline has_permission check' end
       ), ''), '-') as permission,
       coalesce((select string_agg(distinct w[1], ', ' order by w[1])
                   from regexp_matches(coalesce(i.body,''), 'insert into public\.([a-z_]+)', 'g') w), '-') as writes,
       coalesce((select string_agg(distinct u[1], ', ' order by u[1])
                   from regexp_matches(coalesce(i.body,''), 'update public\.([a-z_]+)', 'g') u), '-') as updates,
       (select count(*) from regexp_matches(coalesce(i.body,''), 'raise exception', 'g')) as error_states,
       case when i.body is null then 'no app implementation' else '' end as note
from impl i
order by i.proname;
'@

# -------------------------------------------------------------------------------------------------
# 2. Reporting views.
# -------------------------------------------------------------------------------------------------
$viewSql = @'
select c.relname,
       (select count(*) from information_schema.columns col
         where col.table_schema='reporting' and col.table_name=c.relname),
       case when c.reloptions::text like '%security_invoker=true%' then 'invoker' else 'DEFINER (!)' end,
       case when has_table_privilege('authenticated', c.oid, 'SELECT') then 'authenticated' else 'not granted' end
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='reporting' and c.relkind='v'
order by c.relname;
'@

# -------------------------------------------------------------------------------------------------
# 3. The table surface. PostgREST serves tables directly, so this is as much a client-facing door as
#    the RPCs -- the fact SEC-1b was found through. `(tgtype & 4)` = fires on INSERT, `& 16` = UPDATE:
#    a trigger that merely MENTIONS app.authorize proves nothing about the path being described.
# -------------------------------------------------------------------------------------------------
$tableSql = @'
select c.relname,
       case when has_table_privilege('authenticated', c.oid,'SELECT') then 'S' else '-' end ||
       case when has_table_privilege('authenticated', c.oid,'INSERT') then 'I' else '-' end ||
       case when has_table_privilege('authenticated', c.oid,'UPDATE') then 'U' else '-' end ||
       case when has_table_privilege('authenticated', c.oid,'DELETE') then 'D' else '-' end as grants,
       case when exists (select 1 from pg_trigger t join pg_proc p on p.oid=t.tgfoid
                          where t.tgrelid=c.oid and not t.tgisinternal and (t.tgtype & 4)<>0
                            and pg_get_functiondef(p.oid) ~ '(app\.authorize|app\.has_permission|app\.require_lead_handler)')
            then 'yes' else 'no' end as insert_capability_guard,
       case when exists (select 1 from pg_trigger t join pg_proc p on p.oid=t.tgfoid
                          where t.tgrelid=c.oid and not t.tgisinternal and (t.tgtype & 16)<>0
                            and pg_get_functiondef(p.oid) ~ '(app\.authorize|app\.has_permission|app\.require_lead_handler)')
            then 'conditional' else 'no' end as update_capability_guard,
       coalesce((select string_agg(pp.policyname, ', ' order by pp.policyname)
                   from pg_policies pp where pp.schemaname='public' and pp.tablename=c.relname), 'NONE') as policies
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r'
  and (has_table_privilege('authenticated', c.oid,'SELECT')
       or has_table_privilege('authenticated', c.oid,'INSERT')
       or has_table_privilege('authenticated', c.oid,'UPDATE'))
order by c.relname;
'@

$rpcRows   = @(Psql $rpcSql   | Where-Object { $_ -match "`t" })
$viewRows  = @(Psql $viewSql  | Where-Object { $_ -match "`t" })
$tableRows = @(Psql $tableSql | Where-Object { $_ -match "`t" })

# -------------------------------------------------------------------------------------------------
# 4. HTTP coverage, read from the suites themselves rather than asserted. An endpoint counts as
#    covered when some verify_*.ps1 actually calls `rpc/<name>`.
# -------------------------------------------------------------------------------------------------
$suiteText = (Get-ChildItem (Join-Path $RepoRoot 'scripts') -Filter 'verify_*.ps1' |
              ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"

$sb = [System.Text.StringBuilder]::new()
function W($s) { [void]$sb.AppendLine($s) }

W "# ORVION -- Master API Capability Contract"
W ""
W "Class: Reference (GENERATED -- do not hand-edit; see SS0)"
W "Generated: by ``scripts/generate-api-contract.ps1`` from the live local database"
W ""
W "---"
W ""
W "## 0. How this file is produced, and why it is generated"
W ""
W "Every row below is DERIVED from ``pg_catalog`` and ``app.status_transitions``. Nothing here is"
W "hand-maintained, because a hand-maintained interface document is a claim about the system, and"
W "this programme has repeatedly found that an unverified claim is worse than none -- SEC-1b was a"
W "ceiling whose predicate did not measure what its description said."
W ""
W "``scripts/check_database_parity.ps1`` regenerates this file and FAILS if the committed copy"
W "differs, the same way Check 7 keeps ``ai-map.json`` honest. Regenerate with:"
W ""
W '```'
W "pwsh -File scripts/generate-api-contract.ps1"
W '```'
W ""
W "Where a property cannot be derived from the database -- what a request field MEANS to the"
W "business, what a caller should DO about an error -- this contract says so rather than inventing."
W ""
W "## 1. Platform rules (true for every endpoint; not repeated per row)"
W ""
W "| Property | Rule |"
W "|---|---|"
W "| Transport | PostgREST at ``/rest/v1``. Only the ``public`` and ``graphql_public`` schemas are exposed; ``app`` is not (API-1). |"
W "| Authentication | Supabase JWT in ``Authorization: Bearer``, plus the ``apikey`` header. ``anon`` holds no privilege on any table or endpoint. |"
W "| Tenant | Never a parameter. Derived from the JWT by ``app.current_tenant_id()``. A caller cannot name another tenant. |"
W "| Step-up | ``app.authorize`` composes MFA. ``owner``, ``ceo``, ``finance_manager`` and ``system_administrator`` require ``aal2``; a missing claim raises 42501. |"
W "| RPC method | ``POST /rest/v1/rpc/<name>``, JSON body of named arguments. |"
W "| Void return | HTTP **204 No Content** is success, not failure. |"
W "| Error shape | PostgreSQL error surfaced as JSON ``{code, message, details, hint}``. ``42501`` = permission/authorization; ``23514`` = check/catalog violation; ``23503`` = foreign key; ``P0001`` = business rule raised by an RPC. |"
W "| Pagination | Table and view reads: ``?limit=&offset=`` or the ``Range`` header. RPCs return whole sets. |"
W "| Filtering / sorting | Table and view reads: PostgREST operators (``?col=eq.x``, ``?order=col.desc``). |"
W "| Row scope | RLS, always. A read returns an empty set rather than 403 when scope excludes the row -- so an empty result is NOT evidence of a missing endpoint. |"
W ""
W "## 2. RPC endpoints"
W ""
W "``permission`` is read from the ``app`` implementation of the same name: a literal"
W "``app.authorize('X')`` where one exists; for the ``advance_*`` family the permissions come from"
W "``app.status_transitions``, which is the source ``app.enforce_status_transition`` reads at runtime"
W "(a literal regex misses these because they authorize a VARIABLE -- the same detector-shape mistake"
W "SEC-1b was); ``-`` means no capability check, which for a read is correct and governed by RLS."
W ""
W "``http`` is whether a ``verify_*.ps1`` suite actually calls the endpoint over the wire."
W ""
W "| endpoint | args | returns | sec | permission | inserts | updates | raises | http |"
W "|---|---|---|---|---|---|---|---|---|"
$covered = 0
foreach ($r in $rpcRows) {
    $f = $r -split "`t"
    if ($f.Count -lt 8) { continue }
    $name = $f[0]
    # Two real call shapes, matched exactly rather than by loose name occurrence -- a coverage
    # column that over-counts would be the very thing this contract exists to stop.
    $esc = [regex]::Escape($name)
    $isCovered = ($suiteText -match ("rpc/$esc\b")) -or
                 ($suiteText -match ("Rpc\s+\S+\s+'$esc'")) -or
                 ($suiteText -match ("Rpc\s+\S+\s+`"$esc`""))
    $hit = if ($isCovered) { $covered++; 'yes' } else { '--' }
    $args = if ($f[1].Length -gt 90) { $f[1].Substring(0,87) + '...' } else { $f[1] }
    W ("| ``{0}`` | {1} | ``{2}`` | {3} | {4} | {5} | {6} | {7} | {8} |" -f `
        $name, $args, $f[2], $f[3], $f[4], $f[5], $f[6], $f[7], $hit)
}
W ""
W ("**{0} RPC endpoints executable by ``authenticated``; {1} exercised over HTTP by a suite.**" -f $rpcRows.Count, $covered)
W ""
W "## 3. Reporting views"
W ""
W "| view | columns | security | select |"
W "|---|---|---|---|"
foreach ($r in $viewRows) {
    $f = $r -split "`t"
    if ($f.Count -lt 4) { continue }
    W ("| ``reporting.{0}`` | {1} | {2} | {3} |" -f $f[0], $f[1], $f[2], $f[3])
}
W ""
W "## 4. The table surface -- the other half of the door"
W ""
W "PostgREST serves TABLES as well as RPCs, so ``POST /rest/v1/complaints`` is as reachable from a"
W "browser as ``POST /rest/v1/rpc/create_complaint``. A contract covering only the RPCs would describe"
W "a minority of what a client can touch; SEC-1b was found precisely here."
W ""
W "``insert guard`` requires a trigger that FIRES ON INSERT and charges capability."
W "``update guard`` says **conditional** where such a trigger exists but returns early unless a status"
W "or archive flag changes -- so a DESCRIPTIVE edit passes it. That is SEC-2, and it is stated as"
W "``conditional`` rather than ``yes`` deliberately."
W ""
W "| table | SIUD | insert guard | update guard | RLS policies |"
W "|---|---|---|---|---|"
foreach ($r in $tableRows) {
    $f = $r -split "`t"
    if ($f.Count -lt 5) { continue }
    W ("| ``{0}`` | ``{1}`` | {2} | {3} | {4} |" -f $f[0], $f[1], $f[2], $f[3], $f[4])
}
W ""
W "## 5. Known exposure a client author must design around"
W ""
W "- **SEC-2 (open, owner decision).** A role holding only VIEW permissions can UPDATE *descriptive*"
W "  columns of rows already in its read scope. Reproduced: a ``trainee`` holding"
W "  ``CREATE_LEAD=f, CLOSE_LEAD=f`` renamed the lead assigned to them. BOUNDED -- the same trainee"
W "  could not see or edit a colleague-owned complaint (0 rows, ``UPDATE 0``). Status transitions,"
W "  monetary columns, acquisition attribution and assignment history are all separately guarded, so"
W "  what remains reachable is non-governed descriptive text within scope."
W "- **No DELETE anywhere.** ``authenticated`` holds DELETE on zero tables. A client cannot destroy"
W "  a row through any door; archival is an explicit, permissioned act."
W "- **Excluded on purpose (API-1).** ``record_event`` (audit forgery), ``authorize`` /"
W "  ``has_permission`` / ``current_tenant_id`` (a permission-probing oracle) and every ``platform_*``"
W "  function are NOT exposed. A client cannot mint audit rows, probe the permission matrix, or"
W "  elevate its own subscription."
W ""
W "## 6. What this contract does NOT establish"
W ""
W "- Request-field SEMANTICS. Types and defaults are derived; what a field means to the business is"
W "  in canon, not in ``pg_catalog``."
W "- Remedies for business errors. The ``raises`` column counts the raise sites in each"
W "  implementation; it does not say what a client should do about each one."
W "- Endpoints with ``http = --`` are NOT proven reachable. pgTAP proves database behaviour; only an"
W "  HTTP suite proves the browser-facing door. API-1 was 600 green pgTAP assertions over an entirely"
W "  unreachable API, and that is the standing reason this column exists."

$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }
[IO.File]::WriteAllText($OutFile, $sb.ToString().Replace("`r`n", "`n"))
Write-Host ("MASTER_API_CONTRACT.md generated: {0} RPC endpoints ({1} with HTTP evidence), {2} reporting views, {3} tables." -f `
    $rpcRows.Count, $covered, $viewRows.Count, $tableRows.Count)
