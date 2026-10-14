[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$Candidate,
    [string]$Remote='origin'
)
# OWNER PROMOTION (SPEC-281, CTRL-19). `main` moves to exactly one candidate SHA, and only after the
# evaluator on `main` has judged that candidate with -Gate -Trusted.
#
# Why a script: a required check is computed by the candidate's own workflow and evaluator, and
# GitHub counts a skipped required check as passing, so a candidate can certify itself. -Trusted
# judges it with an evaluator the candidate never touched, but a judgment someone may forget to run,
# or run on another SHA, binds nothing. This file runs it, and pushes only the SHA it judged, onto
# the `main` it judged against.
#
# Run by the owner, from a clean checkout of `main`, in the owner's own account context: this
# checkout is the judge. The candidate is checked out beside it as data with every hook disabled, so
# none of its files runs. GitHub still applies its required check to the push, and a lease refuses
# the push if `main` moved after the judgment. Any failure stops before the push.
$ErrorActionPreference='Stop'
try{[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)}catch{}
$Root=Split-Path $PSScriptRoot -Parent
function Refuse([string]$Why){Write-Output 'PROMOTE: REFUSED';Write-Output "CODE: $Why";exit 1}

git -C $Root fetch --quiet $Remote;if($LASTEXITCODE-ne0){Refuse 'FETCH_FAILED'}
$main="$(git -C $Root rev-parse "$Remote/main")".Trim()
if("$(git -C $Root rev-parse HEAD)".Trim()-ne$main-or@(git -C $Root status --porcelain).Count){
    Refuse "NOT_FROM_MAIN:run this file from a clean checkout of $main - that checkout is the judge"
}
git -C $Root cat-file -e "$Candidate^{commit}" 2>$null;if($LASTEXITCODE-ne0){Refuse "UNKNOWN_CANDIDATE:$Candidate"}
git -C $Root merge-base --is-ancestor $main $Candidate;if($LASTEXITCODE-ne0){Refuse "NOT_A_FAST_FORWARD:$Candidate does not descend from $main"}

$data=Join-Path ([IO.Path]::GetTempPath()) ('orvion-candidate-'+[guid]::NewGuid().ToString('N'))
$noHooks=Join-Path ([IO.Path]::GetTempPath()) ('orvion-no-hooks-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($noHooks)|Out-Null
try{
    git -C $Root -c "core.hooksPath=$noHooks" worktree add --quiet --detach $data $Candidate
    if($LASTEXITCODE-ne0){Refuse 'CANDIDATE_CHECKOUT_FAILED'}
    $judgment=@(& pwsh -NoProfile -File (Join-Path $Root 'scripts/check_agent_continuity.ps1') -Gate -Trusted -Root $data -BaseRef $main -HeadRef $Candidate 2>&1)
    $code=$LASTEXITCODE
    $judgment|ForEach-Object{Write-Output "$_"}
    if($code-ne0-or-not@($judgment|Where-Object{"$_"-eq'ORVION: READY'}).Count){Refuse 'TRUSTED_GATE_REFUSED'}
    git -C $Root push --quiet $Remote "${Candidate}:refs/heads/main" "--force-with-lease=refs/heads/main:$main"
    if($LASTEXITCODE-ne0){Refuse 'PUSH_REFUSED'}
    $now="$(git -C $Root ls-remote $Remote refs/heads/main)".Split("`t")[0].Trim()
    if($now-ne$Candidate){Refuse "MAIN_NOT_PROMOTED:$now"}
    Write-Output 'PROMOTE: DONE'
    Write-Output "MAIN: $Candidate"
}finally{
    git -C $Root worktree remove --force $data 2>$null|Out-Null
    Remove-Item -LiteralPath $noHooks -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
