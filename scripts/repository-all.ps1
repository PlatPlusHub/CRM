Clear-Host

Write-Host ""
Write-Host "===============================" -ForegroundColor Cyan
Write-Host " ORVION Repository Automation"
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/6] Regenerate ai-map.json and repository-index.md..."
# One generator owns both repository-only projections (SPEC-270); Check 7 verifies they reproduce.
& "$PSScriptRoot\generate-ai-map.ps1"
if (-not $?) {
    Write-Host "generate-ai-map.ps1 FAILED -- ai-map.json is stale and must not be committed as fresh." -ForegroundColor Red
    exit 1
}

Write-Host "[2/6] Stage Changes..."
git add .

Write-Host "[3/6] Repository Status..."
git status --short

$msg = Read-Host "`nCommit message"

# EXIT CODES ARE THE CONTRACT (2026-09-09). Every failure path below used a BARE `exit`, and a bare
# `exit` in PowerShell returns **0** -- measured, not assumed, with an isolated probe: a script whose
# last command exited 7 and which then runs `if ($LASTEXITCODE -ne 0) { exit }` reports 0 to its
# caller. So this script announced SUCCESS when the commit failed, when the push failed, and when it
# was cancelled. `AGENTS.md 5a` step 8 puts this script ON the mandated verification path, and 5a's
# whole point is that a step's real output is reported -- a wrapper that returns 0 over a failed
# `git push` is the "ignoring a failing command buried inside a successful wrapper" class, aimed at
# the one command that decides whether the work left this machine at all.
#
# The cancelled branch is non-zero for the same reason and it is not a formality: `Read-Host` under a
# non-interactive session returns empty immediately, so an agent running this unattended lands here,
# having done nothing but `git add .`, and would otherwise be told the repository was synchronised
# and pushed.
if ([string]::IsNullOrWhiteSpace($msg)) {
    Write-Host ""
    Write-Host "Cancelled -- nothing was committed or pushed. Changes remain STAGED." -ForegroundColor Yellow
    exit 2
}

Write-Host ""
Write-Host "[4/6] Commit..."
git commit -m "$msg"

if ($LASTEXITCODE -ne 0) {
    Write-Host "COMMIT FAILED (git exit $LASTEXITCODE) -- nothing was pushed." -ForegroundColor Red
    exit 1
}

Write-Host "[5/6] Push..."
git push

if ($LASTEXITCODE -ne 0) {
    Write-Host "PUSH FAILED (git exit $LASTEXITCODE) -- the commit is LOCAL ONLY. The work has not left this machine." -ForegroundColor Red
    exit 1
}

Write-Host "[6/6] Done"

$commit = git rev-parse --short HEAD

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host " Repository Updated Successfully"
Write-Host "=====================================" -ForegroundColor Green
Write-Host "Branch : $(git branch --show-current)"
Write-Host "Commit : $commit"
Write-Host ""