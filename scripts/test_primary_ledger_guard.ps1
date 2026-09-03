# ORVION -- the guard-of-the-guard for check_primary_ledger.ps1 (RECOVER-1).
#
# `AGENTS.md §6`: "Attack every new detector with a counterexample before trusting it, in both
# directions: construct a case it must flag and one it must not. A guard that can be satisfied
# without satisfying its invariant is the class the discovery-to-guard loop exists to eliminate."
#
# This exists because the guard it tests is the ONLY thing standing between the repository and a
# repeat of RECOVER-1, and a detector nobody has attacked is a hypothesis (META-1).
#
# Every scenario runs against COPIES in a temp directory. Neither the real evidence file, the real
# migrations, nor git history is modified. Nothing here touches Primary at all.
#
# Run: pwsh -File scripts/test_primary_ledger_guard.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$guard    = Join-Path $PSScriptRoot 'check_primary_ledger.ps1'
$realEv   = Join-Path $repoRoot 'reports/evidence/primary-ledger-evidence.json'
$realMig  = Join-Path $repoRoot 'supabase/migrations'

$pass = 0; $fail = 0
function Check($name, $condition, $detail = '') {
    if ($condition) { Write-Host "  ok   $name" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  FAIL $name  $detail" -ForegroundColor Red; $script:fail++ }
}

# Re-derive count and fingerprint so a scenario tests the SET comparison rather than tripping the
# self-consistency check first. A mutation that fails for the wrong reason proves nothing.
function Set-SelfConsistent($ev) {
    $sorted = @($ev.ledger | Sort-Object -CaseSensitive)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $ev.ledger_fingerprint = ([BitConverter]::ToString(
        $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes(($sorted -join ',')))) -replace '-','').ToLower()
    $ev.migration_count = $sorted.Count
    return $ev
}

function New-Sandbox {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("orvion-ledger-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $dir | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'migrations') | Out-Null
    Get-ChildItem $realMig -Filter '*.sql' -File | ForEach-Object {
        # Empty stand-ins: the guard reads FILENAMES only, and copying 189 real files each scenario
        # would make this suite slow for no added coverage.
        New-Item -ItemType File -Path (Join-Path $dir "migrations/$($_.Name)") | Out-Null
    }
    Copy-Item $realEv (Join-Path $dir 'evidence.json')
    return $dir
}

function Invoke-Guard($dir) {
    & pwsh -NoProfile -File $guard -EvidencePath (Join-Path $dir 'evidence.json') `
                                   -MigrationDir (Join-Path $dir 'migrations') *> $null
    return $LASTEXITCODE
}

Write-Host "`n== check_primary_ledger.ps1 -- mutation suite ==" -ForegroundColor Cyan

# --- 5 (run first, as the CONTROL). An untouched sandbox must PASS, or every failure below is
#        meaningless because the harness itself would be broken.
$d = New-Sandbox
Check "CONTROL: an untouched sandbox PASSES -- without this, every FAIL below could be the harness" ((Invoke-Guard $d) -eq 0)
Remove-Item $d -Recurse -Force

# --- 1. Primary has one extra migration. THE RECOVER-1 INCIDENT ITSELF.
$d = New-Sandbox
$ev = Get-Content (Join-Path $d 'evidence.json') -Raw | ConvertFrom-Json
$ev.ledger = @($ev.ledger) + '202607069999_a_migration_only_primary_ran'
$ev = Set-SelfConsistent $ev
$ev | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $d 'evidence.json') -Encoding utf8
Check "MUTATION 1: Primary has an extra migration the repository lacks -- RECOVER-1 exactly -- is DETECTED" ((Invoke-Guard $d) -ne 0)
Remove-Item $d -Recurse -Force

# --- 2. Repository has one extra migration Primary has not run (undeployed, or evidence not refreshed).
$d = New-Sandbox
New-Item -ItemType File -Path (Join-Path $d 'migrations/202607069998_undeployed_local_work.sql') | Out-Null
Check "MUTATION 2: the repository has a migration Primary has not run is DETECTED" ((Invoke-Guard $d) -ne 0)
Remove-Item $d -Recurse -Force

# --- 3. SAME COUNT, different identity. The case a count-only comparison cannot see, and the reason
#        this guard compares the whole ledger.
$d = New-Sandbox
$ev = Get-Content (Join-Path $d 'evidence.json') -Raw | ConvertFrom-Json
$list = @($ev.ledger); $list[10] = '202607069997_same_count_different_identity'
$ev.ledger = $list
$ev = Set-SelfConsistent $ev
$ev | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $d 'evidence.json') -Encoding utf8
$code = Invoke-Guard $d
Check "MUTATION 3: identical COUNT but a different migration identity is DETECTED -- count-only comparison would pass this" ($code -ne 0)
Check "         ...and the count genuinely did not change, so the detection came from the ledger and not from the count" ($ev.migration_count -eq 189)
Remove-Item $d -Recurse -Force

# --- 4. Evidence bound to a commit that is NOT an ancestor of HEAD. A real, well-formed commit
#        object is created with `commit-tree` -- dangling, on no branch, so history is untouched.
$d = New-Sandbox
$foreign = (git commit-tree (git rev-parse 'HEAD^{tree}') -p (git rev-parse HEAD) -m 'foreign commit for mutation test 4' 2>$null)
if ([string]::IsNullOrWhiteSpace($foreign)) {
    Check "MUTATION 4: could not create a foreign commit object -- scenario NOT PROVEN" $false 'git commit-tree failed'
} else {
    $ev = Get-Content (Join-Path $d 'evidence.json') -Raw | ConvertFrom-Json
    $ev.repository_head = $foreign.Trim()
    $ev | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $d 'evidence.json') -Encoding utf8
    Check "MUTATION 4: evidence bound to a commit that is NOT an ancestor of HEAD is DETECTED as stale/foreign" ((Invoke-Guard $d) -ne 0)
}
Remove-Item $d -Recurse -Force

# --- 4b. Evidence naming a commit that does not exist in this repository at all.
$d = New-Sandbox
$ev = Get-Content (Join-Path $d 'evidence.json') -Raw | ConvertFrom-Json
$ev.repository_head = '0123456789abcdef0123456789abcdef01234567'
$ev | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $d 'evidence.json') -Encoding utf8
Check "MUTATION 4b: evidence naming a commit that is not in this repository is DETECTED as unattributable" ((Invoke-Guard $d) -ne 0)
Remove-Item $d -Recurse -Force

# --- 6. Evidence absent entirely. THE STATE THE REPOSITORY WAS IN DURING RECOVER-1.
$d = New-Sandbox
Remove-Item (Join-Path $d 'evidence.json')
Check "MUTATION 6: MISSING evidence FAILS CLOSED -- unknown never becomes clean, which was the whole defect" ((Invoke-Guard $d) -ne 0)
Remove-Item $d -Recurse -Force

# --- 7. The pasted-value scenario. Editing the count and hash WITHOUT touching the ledger must be
#        useless: they are recomputed, so they carry no authority of their own.
$d = New-Sandbox
$ev = Get-Content (Join-Path $d 'evidence.json') -Raw | ConvertFrom-Json
$ev.migration_count = 999
$ev | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $d 'evidence.json') -Encoding utf8
Check "MUTATION 7a: a hand-edited migration_count is DETECTED as self-inconsistent -- pasting a number achieves nothing" ((Invoke-Guard $d) -ne 0)
Remove-Item $d -Recurse -Force

$d = New-Sandbox
$ev = Get-Content (Join-Path $d 'evidence.json') -Raw | ConvertFrom-Json
$ev.ledger_fingerprint = 'deadbeefdeadbeefdeadbeefdeadbeef'
$ev | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $d 'evidence.json') -Encoding utf8
Check "MUTATION 7b: a hand-edited ledger_fingerprint is DETECTED as self-inconsistent" ((Invoke-Guard $d) -ne 0)
Remove-Item $d -Recurse -Force

# --- 8. Malformed / truncated evidence must fail closed rather than throw or pass.
$d = New-Sandbox
Set-Content (Join-Path $d 'evidence.json') -Value '{ "project_ref": "vrvtsxexkiiiivlkdxzp"' -Encoding utf8
Check "MUTATION 8: unparseable evidence FAILS CLOSED rather than crashing or passing" ((Invoke-Guard $d) -ne 0)
Remove-Item $d -Recurse -Force

# --- 9. Evidence missing a required field.
$d = New-Sandbox
$ev = Get-Content (Join-Path $d 'evidence.json') -Raw | ConvertFrom-Json
$ev.PSObject.Properties.Remove('ledger_fingerprint')
$ev | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $d 'evidence.json') -Encoding utf8
Check "MUTATION 9: evidence with a missing required field FAILS CLOSED" ((Invoke-Guard $d) -ne 0)
Remove-Item $d -Recurse -Force

# --- 5 again, LAST. Proves the suite's mutations were all rolled back into their own sandboxes and
#     that the guard still passes the true state -- a second-direction control (GOV-4's lesson).
$d = New-Sandbox
Check "CONTROL (second direction): an untouched sandbox still PASSES after every mutation above" ((Invoke-Guard $d) -eq 0)
Remove-Item $d -Recurse -Force

Write-Host "`n== $pass passed, $fail failed ==" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
exit 0
