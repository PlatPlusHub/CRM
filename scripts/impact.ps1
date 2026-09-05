<#
.SYNOPSIS
  Impact / consumer discovery — answers "if this structure changes, what consumes, parses,
  derives from, assumes or validates it?" (AGENTS.md §5b question 2).

.DESCRIPTION
  This is a QUERY capability, not a guard. It has no CLEAN verdict and never gates a commit:
  it returns evidence, labelled by class, for a human or an agent to reason about.

  WHY IT EXISTS
  -------------
  AGENTS.md §5b was owner-directed on 2026-08-29 out of CUST-1: TENANT-1 correctly made every
  tenant-scoped FK composite and silently turned `app.merge_customer_identity`'s re-pointing loop
  into a no-op, because that loop read the FIRST column of each key. Nothing in the changed code
  was wrong. The defect lived entirely in a CONSUMER, and it ran for eight days.

  §5b tells an engineer to ask the question. Until now nothing helped answer it, so the answer was
  produced by ad-hoc grep whose recall varied with the engineer's diligence. That is the gap this
  script closes, and it closes only that gap.

  WHY POSTGRESQL'S OWN DEPENDENCY METADATA IS NOT ENOUGH
  -----------------------------------------------------
  `pg_depend` is the obvious answer and it is the wrong one here. PostgreSQL does not parse
  function bodies at creation time — they are stored as text — so `pg_depend` records NO edge from
  a function to the tables it reads or writes. For a repository whose entire application layer is
  `app`-schema functions, `pg_depend` is blind to almost every consumer that matters. The same is
  true of codes carried in TRIGGER ARGUMENTS, which is precisely the blind spot MEAS-1 recorded.
  So this script reads what the catalog actually stores: `pg_proc.prosrc` / `prosqlbody`,
  `pg_get_expr` over `pg_policy`, `pg_get_triggerdef` (which includes the arguments),
  `pg_get_viewdef`, and `pg_get_constraintdef` — plus the true structural edges (FKs, indexes,
  grants) where the catalog IS authoritative.

  WHAT IT CANNOT KNOW — stated plainly, because a measurement that overclaims is the failure class
  this repository has hit six times (AGENTS.md §6, MEAS-1/PAR-3/GUARD-1):
    * A text match is a NAME match. Identifier reuse produces false positives; dynamic SQL
      assembled at runtime from fragments produces false negatives. Word boundaries (`\m..\M`)
      cut the first; nothing here cures the second — that is why the output is a lead list, and
      why §5b still requires a BEHAVIOURAL test for a consumer whose meaning can change without
      its source changing.
    * It proves nothing about Primary. Database evidence here is LOCAL RUNTIME, always
      (AGENTS.md §5a evidence classes).
    * It reads the database it is pointed at. If local is not freshly reset, that database is not
      the repository (PAR-1b) — so the script counts the ledger against `supabase/migrations/**`
      and says so, loudly, before printing anything else.

.PARAMETER Target
  The structure to analyse: an identifier (`customers`, `merge_customer_identity`), a qualified
  object (`app.authorize`), or a column (`customers.tenant_id`). Restricted to
  [A-Za-z0-9_] with at most one dot — this is also what keeps it out of the SQL it builds.

.PARAMETER NoDatabase
  Skip database introspection entirely; return REPOSITORY evidence only. Use when Docker is down.

.PARAMETER RequireFresh
  Exit 2 if the local database is not exactly in step with `supabase/migrations/**`.
  Use in any workflow where a stale answer is worse than no answer.

.PARAMETER Full
  Lift the per-section display caps (default 25 rows per section).

.EXAMPLE
  pwsh -NoProfile -File scripts/impact.ps1 -Target customers
  pwsh -NoProfile -File scripts/impact.ps1 -Target app.authorize -RequireFresh
  pwsh -NoProfile -File scripts/impact.ps1 -Target document_type_code -NoDatabase
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Target,
    [switch] $NoDatabase,
    [switch] $RequireFresh,
    [switch] $Full
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$cap  = if ($Full) { [int]::MaxValue } else { 25 }
$container = 'supabase_db_ORVION'   # supabase/config.toml project_id; same container AGENTS.md §5 uses

# ---------------------------------------------------------------------------------------------
# Input validation. Also the injection boundary: nothing outside this class ever reaches psql.
# ---------------------------------------------------------------------------------------------
if ($Target -notmatch '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)?$') {
    Write-Host "IMPACT: refused — Target must be [A-Za-z0-9_] with at most one dot. Got: '$Target'" -ForegroundColor Red
    exit 2
}
$parts = $Target -split '\.'
$token = $parts[-1]            # the identifier actually searched for
$qual  = if ($parts.Count -eq 2) { $parts[0] } else { $null }

function Show-Section {
    param([string] $Title, [string[]] $Rows, [string] $Evidence, [string] $EmptyNote = 'none')
    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "    [evidence: $Evidence]" -ForegroundColor DarkGray
    if (-not $Rows -or $Rows.Count -eq 0) { Write-Host "    $EmptyNote" -ForegroundColor DarkGray; return }
    $Rows | Select-Object -First $cap | ForEach-Object { Write-Host "    $_" }
    if ($Rows.Count -gt $cap) { Write-Host "    (+$($Rows.Count - $cap) more — rerun with -Full)" -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host " ORVION IMPACT — what consumes / derives from this structure?" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "TARGET" -ForegroundColor Yellow
Write-Host "  $Target" -NoNewline
if ($qual) { Write-Host "   (searched as '$token', qualifier '$qual')" -ForegroundColor DarkGray } else { Write-Host "" }

# ---------------------------------------------------------------------------------------------
# STALENESS — the local database is only the repository immediately after a reset (PAR-1b).
# ---------------------------------------------------------------------------------------------
$dbUsable = -not $NoDatabase
$dbLabel  = 'LOCAL RUNTIME'
$fileCount = (Get-ChildItem -Path (Join-Path $repo 'supabase/migrations') -Filter '*.sql' -File).Count

if ($dbUsable) {
    $applied = (docker exec -i $container psql -U postgres -d postgres -At -c `
        "select count(*) from supabase_migrations.schema_migrations;" 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $applied) {
        Write-Host ""
        Write-Host "  DATABASE UNREACHABLE — container '$container' did not answer." -ForegroundColor Yellow
        Write-Host "  Continuing with REPOSITORY evidence only. Start it with: npx supabase start" -ForegroundColor Yellow
        $dbUsable = $false
        if ($RequireFresh) { Write-Host "  -RequireFresh was set; refusing to answer from a database that is absent." -ForegroundColor Red; exit 2 }
    }
    elseif ([int]$applied -ne $fileCount) {
        $delta = $fileCount - [int]$applied
        Write-Host ""
        Write-Host "  *** LOCAL DATABASE IS STALE: $applied applied vs $fileCount migration files ($delta unapplied). ***" -ForegroundColor Red
        Write-Host "  Anything read below describes THAT database, not this repository (PAR-1b)." -ForegroundColor Red
        Write-Host "  Refresh deterministically:  npx supabase db reset" -ForegroundColor Red
        $dbLabel = "LOCAL RUNTIME (STALE — $delta migrations unapplied; NOT the repository)"
        if ($RequireFresh) { Write-Host "  -RequireFresh was set; refusing to answer from a stale database." -ForegroundColor Red; exit 2 }
    }
}

# ---------------------------------------------------------------------------------------------
# DATABASE EVIDENCE
#   Structural rows come from catalog edges (authoritative). Body rows come from a word-boundary
#   text match over what the catalog stores as text (a strong lead, never a proof).
# ---------------------------------------------------------------------------------------------
$classification = @(); $fns = @(); $pols = @(); $trgs = @(); $views = @()
$fks = @(); $cons = @(); $idxs = @(); $grants = @()

if ($dbUsable) {
    $sql = @"
\set QUIET on
\pset tuples_only on
\pset format unaligned
\pset fieldsep '|'
\set tok '$token'

\echo @@CLASSIFY
select 'table     ' || n.nspname || '.' || c.relname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where c.relname = :'tok' and c.relkind in ('r','p')
union all
select 'view      ' || n.nspname || '.' || c.relname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where c.relname = :'tok' and c.relkind in ('v','m')
union all
select 'function  ' || n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where p.proname = :'tok' and n.nspname not in ('pg_catalog','information_schema')
union all
select 'column    ' || table_schema || '.' || table_name || '.' || column_name || '  ' || data_type
  from information_schema.columns
 where column_name = :'tok' and table_schema in ('app','public')
order by 1;

\echo @@FUNCTIONS
select n.nspname || '.' || p.proname
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname in ('app','public','extensions')
   and coalesce(case when p.prosqlbody is not null then pg_get_function_sqlbody(p.oid)::text else p.prosrc end, '')
       ~* ('\m' || :'tok' || '\M')
order by 1;

\echo @@POLICIES
select n.nspname || '.' || c.relname || '  ::  ' || pol.polname || '  [' || pol.polcmd::text || ']'
       || case when c.relname = :'tok' then '  (on target)' else '  (references target)' end
  from pg_policy pol
  join pg_class c on c.oid = pol.polrelid
  join pg_namespace n on n.oid = c.relnamespace
 where c.relname = :'tok'
    or coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') ~* ('\m' || :'tok' || '\M')
    or coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') ~* ('\m' || :'tok' || '\M')
order by 1;

\echo @@TRIGGERS
select n.nspname || '.' || c.relname || '  ::  ' || t.tgname || '  ->  ' || tn.nspname || '.' || tp.proname
       || case when t.tgnargs > 0 then '  args(' || t.tgnargs || ')' else '' end
       || case when c.relname = :'tok' then '  (on target)' else '  (target in definition/arguments)' end
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_proc tp on tp.oid = t.tgfoid
  join pg_namespace tn on tn.oid = tp.pronamespace
 where not t.tgisinternal
   and (c.relname = :'tok' or pg_get_triggerdef(t.oid) ~* ('\m' || :'tok' || '\M'))
order by 1;

\echo @@VIEWS
select n.nspname || '.' || c.relname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where c.relkind in ('v','m') and c.relname <> :'tok'
   and pg_get_viewdef(c.oid) ~* ('\m' || :'tok' || '\M')
order by 1;

\echo @@FK
select conrelid::regclass::text || '  ->  ' || confrelid::regclass::text || '  (' || conname || ')'
  from pg_constraint
 where contype = 'f'
   and (confrelid = to_regclass('public.' || :'tok') or conrelid = to_regclass('public.' || :'tok')
        or confrelid = to_regclass('app.' || :'tok')  or conrelid = to_regclass('app.' || :'tok'))
order by 1;

\echo @@CONSTRAINTS
select conrelid::regclass::text || '  ::  ' || conname || '  [' || contype::text || ']'
  from pg_constraint
 where contype in ('c','u','p','x')
   and pg_get_constraintdef(oid) ~* ('\m' || :'tok' || '\M')
order by 1;

\echo @@INDEXES
select schemaname || '.' || tablename || '  ::  ' || indexname
  from pg_indexes
 where schemaname in ('app','public')
   and (tablename = :'tok' or indexdef ~* ('\m' || :'tok' || '\M'))
order by 1;

\echo @@GRANTS
select grantee || '  ' || string_agg(distinct privilege_type, ',' order by privilege_type)
  from information_schema.role_table_grants
 where table_name = :'tok' and table_schema in ('app','public')
 group by grantee
order by 1;
"@

    $raw = $sql | docker exec -i $container psql -U postgres -d postgres -v ON_ERROR_STOP=0 2>&1
    $bucket = $null
    foreach ($line in ($raw -split "`r?`n")) {
        $l = $line.TrimEnd()
        if ($l -like '@@*') { $bucket = $l.Substring(2); continue }
        if (-not $l -or $l -match '^\(\d+ rows?\)$' -or $l -eq '(0 rows)') { continue }
        # psql spreads one error over several lines (ERROR / LINE n: / a caret row / HINT:). Swallow
        # the whole shape, or a continuation line lands in a bucket and reads like a result row.
        if ($l -match '^(ERROR|psql:|LINE \d+:|HINT:|DETAIL:|CONTEXT:)' -or $l -match '^\s*\^\s*$') {
            if ($l -match '^(ERROR|psql:)') { Write-Host "    [db] $l" -ForegroundColor DarkYellow }
            continue
        }
        switch ($bucket) {
            'CLASSIFY'    { $classification += $l }
            'FUNCTIONS'   { $fns    += $l }
            'POLICIES'    { $pols   += $l }
            'TRIGGERS'    { $trgs   += $l }
            'VIEWS'       { $views  += $l }
            'FK'          { $fks    += $l }
            'CONSTRAINTS' { $cons   += $l }
            'INDEXES'     { $idxs   += $l }
            'GRANTS'      { $grants += $l }
        }
    }
}

# ---------------------------------------------------------------------------------------------
# REPOSITORY EVIDENCE — word-boundary match, grouped by the role each area plays.
# ---------------------------------------------------------------------------------------------
$rx = '\b' + [regex]::Escape($token) + '\b'
function Find-In {
    param([string] $RelPath, [string] $Filter)
    $root = Join-Path $repo $RelPath
    if (-not (Test-Path $root)) { return @() }
    Get-ChildItem -Path $root -Filter $Filter -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            $hits = @(Select-String -Path $_.FullName -Pattern $rx -AllMatches -ErrorAction SilentlyContinue)
            if ($hits.Count -gt 0) {
                [pscustomobject]@{ Name = $_.Name; Rel = (Resolve-Path -Relative $_.FullName).TrimStart('.', '\', '/'); Hits = $hits.Count }
            }
        }
}

Push-Location $repo
try {
    $mig    = @(Find-In 'supabase/migrations' '*.sql'   | Sort-Object Name)
    $tests  = @(Find-In 'supabase/tests'      '*.sql'   | Sort-Object Name)
    $scr    = @(Find-In 'scripts'             '*'       | Where-Object { $_.Name -ne 'impact.ps1' } | Sort-Object Name)
    $canon  = @(Find-In '_ORVION_CANONICAL'   '*.md'    | Sort-Object Name)
    $master = @(Find-In 'reports/master'      '*.md'    | Sort-Object Name)
    $adr    = @(Find-In 'reports'             'architecture-decision-records.md')
    $chg    = @(Find-In 'changes'             '*.md'    | Sort-Object Name)
} finally { Pop-Location }

# ---------------------------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------------------------
Show-Section 'RESOLVES TO' $classification 'LOCAL RUNTIME — catalog identity' `
    $(if ($dbUsable) { 'no database object of this name (may be a code value, a permission, or repository-only)' } else { 'not checked (no database)' })
if ($dbUsable -and $classification.Count -eq 0) {
    Write-Host "    note: a target that names no catalog object also matches ordinary prose —" -ForegroundColor DarkGray
    Write-Host "          comments and exception messages included. Read the lists below as leads." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "DIRECT DATABASE CONSUMERS" -ForegroundColor Yellow
if (-not $dbUsable) { Write-Host "  skipped — no database evidence in this run" -ForegroundColor DarkGray }
else {
    Show-Section 'functions (body / SQL-body text match)' $fns   "$dbLabel — text match, a lead"
    Show-Section 'policies  (attached, or expression match)' $pols  "$dbLabel — catalog + expression text"
    Show-Section 'triggers  (attached, or named in definition INCLUDING arguments — MEAS-1)' $trgs "$dbLabel — catalog + triggerdef text"
    Show-Section 'views     (definition text match)' $views "$dbLabel — text match, a lead"
    Show-Section 'foreign keys (in and out)' $fks   "$dbLabel — catalog edge, authoritative"
    Show-Section 'constraints (definition mentions target)' $cons  "$dbLabel — catalog edge, authoritative"
    Show-Section 'indexes' $idxs  "$dbLabel — catalog edge, authoritative"
    Show-Section 'grants (on target relation)' $grants "$dbLabel — catalog edge, authoritative"
}

Write-Host ""
Write-Host "REPOSITORY CONSUMERS" -ForegroundColor Yellow
Show-Section "migrations ($($mig.Count) files)" @($mig | ForEach-Object { "$($_.Name)  x$($_.Hits)" }) 'REPOSITORY — text match'
Show-Section "scripts ($($scr.Count) files)"    @($scr | ForEach-Object { "$($_.Name)  x$($_.Hits)" }) 'REPOSITORY — text match'
Show-Section "open change requests ($($chg.Count))" @($chg | ForEach-Object { $_.Name }) 'REPOSITORY — text match'

Write-Host ""
Write-Host "CANONICAL REFERENCES" -ForegroundColor Yellow
Show-Section 'canon (_ORVION_CANONICAL)' @($canon | ForEach-Object { "$($_.Name)  x$($_.Hits)" }) 'REPOSITORY — INTENT class (what was meant, not what the system does)'
Show-Section 'master registers'          @($master | ForEach-Object { "$($_.Name)  x$($_.Hits)" }) 'REPOSITORY — INTENT class'
Show-Section 'ADRs'                      @($adr | ForEach-Object { "$($_.Name)  x$($_.Hits)" })    'REPOSITORY — INTENT class'

Write-Host ""
Write-Host "VALIDATION REQUIRED" -ForegroundColor Yellow
Write-Host "  [evidence: INFERENCE — derived from the matches above; it is a floor, never a ceiling]" -ForegroundColor DarkGray
if ($tests.Count -gt 0) {
    Write-Host "  pgTAP suites that already name this target ($($tests.Count)):"
    $tests | Select-Object -First $cap | ForEach-Object { Write-Host "    $($_.Name)  x$($_.Hits)" }
    if ($tests.Count -gt $cap) { Write-Host "    (+$($tests.Count - $cap) more — rerun with -Full)" -ForegroundColor DarkGray }
} else {
    Write-Host "  no pgTAP suite names this target." -ForegroundColor Yellow
    Write-Host "  If it is being changed, that absence is itself the finding (AGENTS.md §6 discovery-to-guard)." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Then the full package protocol — AGENTS.md §5a owns it and this script restates none of it:"
Write-Host "    reset -> Pass A -> the six HTTP suites -> Pass B -> smoke -> Primary's three values"
Write-Host "    -> check_database_parity.ps1 -> regenerate artifacts -> check_repository_consistency.ps1"
if ($pols.Count -gt 0 -or $trgs.Count -gt 0 -or $grants.Count -gt 0) {
    Write-Host ""
    Write-Host "  §5b CROSS-PATH SWEEP IS TRIGGERED for this target (policy / trigger / grant surface present)." -ForegroundColor Yellow
    Write-Host "  Classify every consumer above as single-tenant interactive | multi-tenant system | batch |" -ForegroundColor Yellow
    Write-Host "  scheduled | integration | administrative, and prove each class separately." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "EVIDENCE" -ForegroundColor Yellow
Write-Host "  database   : $(if ($dbUsable) { $dbLabel } else { 'NOT READ' })"
Write-Host "  repository : REPOSITORY — $fileCount migration files, word-boundary match on '$token'"
Write-Host "  limits     : name-based matching. Dynamic SQL assembled at runtime is invisible here."
Write-Host "               A consumer whose meaning changes without its source changing (CUST-1) still"
Write-Host "               needs a BEHAVIOURAL test — this list cannot substitute for one."
Write-Host ""
exit 0
