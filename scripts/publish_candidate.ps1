# ORVION candidate publisher (SPEC-184).
#
# Publishes a candidate to `orvion-preflight` and nothing else. This script OWNS NO FACT.
# The committed range is judged by `check_agent_continuity.ps1 -Gate`; the remote's position
# is judged atomically by Git's own lease; admission is judged by `ORVION Acceptance` and the
# Ruleset; post-push expected-vs-observed evidence stays owned by `-Certify`. What lives here
# is SEQUENCE and REFUSAL - the one order that is safe, and a stop at the first failure.
#
# It deliberately contains no promotion to `main`, no `-Certify` call, no Acceptance polling,
# no GitHub API query, no retry, recovery, rollback or repair, and no history-rewriting
# command. A normal push that Git rejects as non-fast-forward simply fails: it is NEVER
# retried with a lease, because "the ref moved" is the exact condition a lease must refuse.
[CmdletBinding()]
param(
    # The repository to publish from. Parameterised only so the control suite can exercise
    # this against its disposable sandbox; it defaults to the repository this script lives in.
    [string]$Root = (Split-Path $PSScriptRoot -Parent),

    # The CALLER's expectation of what `orvion-preflight` currently holds, supplied only when
    # deliberately replacing a rejected candidate. It is never derived from the remote-tracking
    # ref: this script fetches, and a fetch refreshes that ref, so a lease derived from it would
    # compare the remote against itself and refuse nothing. Absent, no force of any kind is used.
    [string]$ReplaceExpectedSha
)

$ErrorActionPreference = 'Stop'
$Branch = 'orvion-preflight'

function Fail([string]$Code, [string]$Detail) {
    Write-Output 'PUBLISH: BLOCKED'
    Write-Output "CODE: $Code"
    if ($Detail) { Write-Output "EVIDENCE: $Detail" }
    exit 1
}

if (-not (Test-Path -LiteralPath $Root)) { Fail 'ROOT_NOT_FOUND' $Root }

# 1. A dirty tree is refused BEFORE anything else. The Gate below runs Repo-Guard against the
#    working tree while answering a question about the COMMITTED range, so uncommitted content
#    would let a verdict be earned by bytes that are not the bytes being published.
$dirty = @(git -C $Root status --porcelain)
if ($LASTEXITCODE -ne 0) { Fail 'GIT_STATUS_FAILED' "git status exited $LASTEXITCODE" }
if ($dirty.Count) { Fail 'WORKING_TREE_DIRTY' (($dirty | Select-Object -First 10) -join '; ') }

# 2. Fetch before deciding anything about the remote.
git -C $Root fetch origin --quiet
if ($LASTEXITCODE -ne 0) { Fail 'FETCH_FAILED' "git fetch origin exited $LASTEXITCODE" }

# 3. Capture both SHAs ONCE and use exactly these values for the Gate and the push. Re-reading
#    either one later would let the thing proven and the thing pushed drift apart.
$base = (git -C $Root rev-parse refs/remotes/origin/main 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $base) { Fail 'BASE_UNRESOLVABLE' 'refs/remotes/origin/main could not be resolved' }
$base = "$base".Trim()
$head = (git -C $Root rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $head) { Fail 'HEAD_UNRESOLVABLE' 'HEAD could not be resolved' }
$head = "$head".Trim()
foreach ($pair in @(@('BASE', $base), @('HEAD', $head))) {
    if ($pair[1] -notmatch '^[0-9a-f]{40}$') { Fail 'SHA_NOT_FULL' "$($pair[0])=$($pair[1])" }
}

Write-Output "BASE: $base"
Write-Output "HEAD: $head"

# 4. The committed range is proven by the EXISTING Gate, invoked with the captured values. No
#    Gate logic is reproduced here, and no result is interpreted beyond its exit code. An empty
#    range needs no rule of its own: the Gate already fails it closed as NO_GOVERNING_CR.
$gate = Join-Path $Root 'scripts/check_agent_continuity.ps1'
if (-not (Test-Path -LiteralPath $gate)) { Fail 'GATE_SCRIPT_MISSING' $gate }
& pwsh -NoProfile -File $gate -Gate -Root $Root -BaseRef $base -HeadRef $head
if ($LASTEXITCODE -ne 0) { Fail 'RANGE_GATE_FAILED' "committed range $base..$head was refused; nothing was pushed" }

# 5. Push. Exactly one of two forms, chosen by whether the caller supplied an expectation.
$refspec = "${head}:refs/heads/$Branch"
if ($PSBoundParameters.ContainsKey('ReplaceExpectedSha') -and $ReplaceExpectedSha) {
    $expected = "$ReplaceExpectedSha".Trim()
    # A short or malformed expectation is refused rather than normalised. Resolving it would
    # mean asking the repository what the caller "meant", and the whole value of this argument
    # is that it is the caller's own statement about the remote.
    if ($expected -notmatch '^[0-9a-f]{40}$') { Fail 'EXPECTED_SHA_NOT_FULL' "ReplaceExpectedSha=$expected" }
    $lease = "--force-with-lease=refs/heads/${Branch}:${expected}"
    Write-Output "REPLACE: $Branch expected at $expected"
    git -C $Root push $lease origin $refspec
    if ($LASTEXITCODE -ne 0) { Fail 'LEASE_PUSH_REFUSED' "$Branch did not hold $expected, or the push was otherwise refused; the remote is unchanged" }
} else {
    git -C $Root push origin $refspec
    if ($LASTEXITCODE -ne 0) { Fail 'PUSH_REFUSED' "git refused the push (a non-fast-forward is not retried with a lease); the remote is unchanged" }
}

Write-Output "PUBLISHED: $head -> refs/heads/$Branch"
Write-Output 'PUBLISH: DONE'
exit 0
