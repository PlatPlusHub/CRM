<#
.SYNOPSIS
  SessionStart hook — prints the one live fact no ORVION guard measures:
  how local HEAD stands against origin.

.DESCRIPTION
  AGENTS.md §4 requires fetching before work and forbids automatic merge/rebase/
  reset when local and upstream diverge both ways. RECOVER-1 was four migrations
  that sat on origin/main for a day while every guard printed CLEAN, because two
  sessions had diverged from one base without fetching. Boot reports the same
  fact, but only once it is run; this hook reports it before anything is run.

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
        # Stated as a fact, not as an instruction: hook output framed as an out-of-band command can
        # trip prompt-injection defences, and the rule it refers to already lives in AGENTS.md.
        $note = if ([int]$b -gt 0) { '  (local is behind origin; AGENTS.md §4 applies)' } else { '' }
        Write-Output "ORVION git: branch $branch | ahead $a / behind $b vs upstream | working tree $tree$note"
    } else {
        Write-Output "ORVION git: branch $branch | no upstream tracked | working tree $tree"
    }
} catch { }
exit 0
