<#
.SYNOPSIS
  ORVION -- Batch 6 slice selection by MEASUREMENT. Ranks the surfaces that still carry
  `NOT-RECORDED` in MASTER_SURFACE_DISPOSITION.md by exposure-minus-coverage, and prints the
  ranking with every component visible so the choice can be argued with rather than trusted.

.DESCRIPTION
  WHY THIS EXISTS. Slice 1 was chosen honestly but narrowly -- "the only two tables no pgTAP file
  names" was the single measurement available before the disposition record existed. That rule
  cannot pick a third slice, and choosing by intuition ("this table looks interesting") is exactly
  what a repeatable programme must not do. This script is the selection rule.

  WHAT IT IS NOT, and this boundary is the important one. It is a SELECTOR, never an authority:

    * It STORES NOTHING. Every number is recomputed from the live catalog and the repository on
      every run, so there is no file to go stale and no second source of truth about a surface.
      MASTER_SURFACE_DISPOSITION.md owns what a surface's disposition IS; this only says which
      surface to look at NEXT.
    * It is NOT a CI gate and must never become one. It has no pass/fail verdict to give -- a high
      score is a suggestion, not a defect. (`impact.ps1` carries the same standing restriction for
      the same reason: a script without an authoritative verdict must not fail a build.)
    * Its ranking is NOT a claim that lower-ranked surfaces are safe. It is a claim about where the
      next hour of attacking is most likely to be repaid.

  THE MODEL, stated so it can be disagreed with. Score = EXPOSURE - COVERAGE.

  EXPOSURE -- what an attacker gains, and how little stands in the way:
    money      x3  a numeric(19,4) column: ORVION's money type (R7/DC-1). Financial impact.
    pii        x3  a column matching name/email/phone/passport/national id/date of birth.
    unguarded  x4  `authenticated` may write it AND no policy WITH CHECK names a permission AND no
                   capability trigger fires. This is SEC-1's residue shape and the heaviest weight
                   deliberately: it is the only component that means "there is no control here".
    direct     x2  per INSERT/UPDATE/DELETE grant held by `authenticated` -- each is a table door
                   that direct DML and PostgREST both reach, which is the class BOOK-1/ADMIN-1/
                   FIN-8/FIN-10/QUO-1 kept re-finding.
    secdef     x3  per SECURITY DEFINER function that writes it and is executable by
                   `authenticated`. Those run with RLS BYPASSED (no ORVION table sets FORCE ROW
                   LEVEL SECURITY, and every table is owned by the function owner), so each one is
                   a door where the tenant boundary is code rather than policy.
    rpc        x1  per app function that writes it -- more doors, more places one rule can be missed.
    state      x2  a status column with rows in app.status_transitions: lifecycle attack surface.
    concurrency x2 a unique constraint or a claim/lease/counter-shaped column: the LIC-2 class.

  COVERAGE -- what has already been aimed at it:
    tests      x2  per pgTAP file naming the surface. A floor, never proof (a table named once in
                   an unrelated fixture is not a swept surface) -- which is why the weight is low.
    negative   x4  per pgTAP file that names the surface AND contains `throws_ok`. Negative evidence
                   is worth double a positive file, because a positive-only surface is exactly where
                   LIC-2, SPP-2 and FIN-3 were found hiding.

  Weights are judgement, and they are visible rather than buried: change them here, re-run, and the
  ranking moves. Nothing downstream depends on the numbers.

.NOTES
  Run: pwsh -File scripts/batch6_select_target.ps1 [-Top 12] [-All]
  Needs the local Supabase stack up (it reads the live catalog); reads no remote database.
#>

param(
    [int]$Top = 12,
    [switch]$All,
    [string]$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
)

$ErrorActionPreference = 'Stop'

$container = (docker ps --format '{{.Names}}' | Where-Object { $_ -like 'supabase_db_*' } | Select-Object -First 1)
if (-not $container) {
    Write-Host "No supabase_db_* container is running -- start the local stack (npx supabase start)." -ForegroundColor Red
    exit 2
}

# One query, one row per public table, every exposure component separately so the ranking can be
# argued with. Kept as data rather than a verdict on purpose.
$sql = @'
select t.relname
    || '|' || (case when exists (select 1 from information_schema.columns c
                                  where c.table_schema='public' and c.table_name=t.relname
                                    and c.data_type='numeric' and c.numeric_precision=19 and c.numeric_scale=4)
                    then 1 else 0 end)
    || '|' || (case when exists (select 1 from information_schema.columns c
                                  where c.table_schema='public' and c.table_name=t.relname
                                    and (c.column_name ~ '(full_name|first_name|last_name|email|phone|passport|national_id|date_of_birth|birth_date)'))
                    then 1 else 0 end)
    || '|' || (select count(*) from information_schema.role_table_grants g
                where g.table_schema='public' and g.table_name=t.relname and g.grantee='authenticated'
                  and g.privilege_type in ('INSERT','UPDATE','DELETE'))
    || '|' || (case when (select count(*) from information_schema.role_table_grants g
                           where g.table_schema='public' and g.table_name=t.relname and g.grantee='authenticated'
                             and g.privilege_type in ('INSERT','UPDATE','DELETE')) > 0
                     and not exists (select 1 from pg_policies p
                                      where p.schemaname='public' and p.tablename=t.relname
                                        and coalesce(p.with_check,'') ~ '(has_permission|authorize)')
                     and not exists (select 1 from pg_trigger tg join pg_proc pr on pr.oid=tg.tgfoid
                                      where tg.tgrelid=t.oid and not tg.tgisinternal
                                        and pr.proname ~ '(guard_|capability|authoriz)')
                    then 1 else 0 end)
    || '|' || (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                where n.nspname='app' and p.prosrc ~ ('(insert into|update)\s+public\.' || t.relname || '\M'))
    || '|' || (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                where n.nspname='app' and p.prosecdef and has_function_privilege('authenticated', p.oid,'EXECUTE')
                  and p.prosrc ~ ('(insert into|update)\s+public\.' || t.relname || '\M'))
    || '|' || (case when exists (select 1 from app.status_transitions st where st.table_name = t.relname)
                    then 1 else 0 end)
    || '|' || (case when exists (select 1 from pg_constraint c where c.conrelid=t.oid and c.contype='u')
                  or exists (select 1 from pg_index i where i.indrelid=t.oid and i.indisunique and not i.indisprimary)
                  or exists (select 1 from information_schema.columns c
                              where c.table_schema='public' and c.table_name=t.relname
                                and (c.column_name ~ '(claimed_at|lease|attempt_number|consumed_at|_count$|balance)'))
                    then 1 else 0 end)
from pg_class t join pg_namespace n on n.oid=t.relnamespace
where n.nspname='public' and t.relkind='r'
order by t.relname;
'@

$rows = docker exec -i $container psql -U postgres -d postgres -t -A -c $sql 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "Could not read the local catalog." -ForegroundColor Red; exit 2 }

# Coverage comes from the repository, not the database: which pgTAP files name the surface, and
# which of those carry a NEGATIVE assertion. Read once, matched per surface.
$tests = @{}
foreach ($f in (Get-ChildItem (Join-Path $RepoRoot 'supabase/tests') -Filter *.sql -File)) {
    $txt = [System.IO.File]::ReadAllText($f.FullName)
    $tests[$f.Name] = @{ text = $txt; negative = ($txt -match 'throws_ok') }
}

# Disposition status comes from the Master that owns it -- never recomputed here.
$dispPath = Join-Path $RepoRoot 'reports/master/MASTER_SURFACE_DISPOSITION.md'
$recorded = @{}
foreach ($line in [System.IO.File]::ReadAllLines($dispPath)) {
    if ($line -cmatch '^\|\s*`([a-z_][a-z0-9_]*)`\s*\|\s*\**([A-Z-]+)\**\s*\|') {
        $recorded[$Matches[1]] = $Matches[2]
    }
}

$scored = foreach ($r in $rows) {
    $p = $r.Trim() -split '\|'
    if ($p.Count -lt 9) { continue }
    $surface = $p[0]
    $money = [int]$p[1]; $pii = [int]$p[2]; $direct = [int]$p[3]; $unguarded = [int]$p[4]
    $rpc = [int]$p[5]; $secdef = [int]$p[6]; $state = [int]$p[7]; $conc = [int]$p[8]

    $files = 0; $neg = 0
    foreach ($k in $tests.Keys) {
        if ($tests[$k].text -match ('\b' + [regex]::Escape($surface) + '\b')) {
            $files++
            if ($tests[$k].negative) { $neg++ }
        }
    }

    $exposure = (3*$money) + (3*$pii) + (4*$unguarded) + (2*$direct) + (3*$secdef) + $rpc + (2*$state) + (2*$conc)
    $coverage = (2*$files) + (4*$neg)

    [pscustomobject]@{
        Surface     = $surface
        Disposition = if ($recorded.ContainsKey($surface)) { $recorded[$surface] } else { 'ABSENT' }
        Score       = $exposure - $coverage
        Exposure    = $exposure
        Coverage    = $coverage
        Money       = $money
        PII         = $pii
        Unguarded   = $unguarded
        Direct      = $direct
        SecDef      = $secdef
        RPCs        = $rpc
        State       = $state
        Conc        = $conc
        Tests       = $files
        NegTests    = $neg
    }
}

$candidates = $scored | Where-Object { $All -or $_.Disposition -eq 'NOT-RECORDED' } | Sort-Object -Property Score -Descending

Write-Host ""
Write-Host "== Batch 6 slice selection by measurement ==" -ForegroundColor Cyan
Write-Host "   score = exposure - coverage; components shown so the ranking can be argued with." -ForegroundColor DarkGray
Write-Host "   $($candidates.Count) candidate surface(s)$(if(-not $All){' still at NOT-RECORDED'})." -ForegroundColor DarkGray
Write-Host ""
$candidates | Select-Object -First $Top | Format-Table Surface, Disposition, Score, Exposure, Coverage, Money, PII, Unguarded, Direct, SecDef, RPCs, State, Conc, Tests, NegTests -AutoSize

Write-Host "SELECTION IS A SUGGESTION, NEVER A VERDICT." -ForegroundColor DarkGray
Write-Host "  A high score says 'attacking here is most likely to be repaid', not 'this is broken'." -ForegroundColor DarkGray
Write-Host "  A low score is NOT evidence a surface is safe -- coverage counts files, and a file that" -ForegroundColor DarkGray
Write-Host "  merely NAMES a table in a fixture scores the same as one that attacks it. Nothing here" -ForegroundColor DarkGray
Write-Host "  is stored: re-run it and it is recomputed from the catalog and the test files." -ForegroundColor DarkGray
