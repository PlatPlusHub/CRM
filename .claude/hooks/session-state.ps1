<#
.SYNOPSIS
  SessionStart hook — prints the one live fact no ORVION guard measures:
  how local HEAD stands against origin.

.DESCRIPTION
  AGENTS.md §4 Stage B step 8: "Nothing in this repository compares local `main`
  against `origin/main`; that is your job before you start." RECOVER-1 was four
  migrations that sat on origin/main for a day while every guard printed CLEAN,
  because two sessions had diverged from one base without fetching.

  This hook is not a guard and asserts nothing — it reports ahead/behind and
  working-tree state so a session cannot begin blind to divergence. It never
  fails a session: any error exits 0 silently.
  Agent tooling only (.claude/**); it touches no ORVION content.
#>

$ErrorActionPreference = 'SilentlyContinue'
try {
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    git fetch --quiet --no-tags 2>$null | Out-Null
    $counts = (git rev-list --left-right --count "HEAD...@{u}" 2>$null)
    $tree = if ((git status --porcelain)) { 'DIRTY' } else { 'clean' }
    if ($counts) {
        $a, $b = ($counts -split '\s+')
        $note = if ([int]$b -gt 0) { '  <-- FETCH FIRST: behind origin' } else { '' }
        Write-Output "ORVION git: branch $branch | ahead $a / behind $b vs upstream | working tree $tree$note"
    } else {
        Write-Output "ORVION git: branch $branch | no upstream tracked | working tree $tree"
    }
} catch { }
exit 0
