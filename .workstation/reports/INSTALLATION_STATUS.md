# ORVION Workstation Installation Snapshot — 2026-09-10 (HISTORICAL)

Class: historical evidence. Observed: 2026-09-10.

**This is not current workstation status and must never be read as such.** It records what one
verification run observed on 2026-09-10 and is preserved unchanged as evidence of that date.
Tool versions, readiness and authentication state all move; this file does not.

**Current workstation status has exactly one source: run `pwsh -NoProfile -File .workstation/doctor.ps1`.**
Live observation is the only thing entitled to report the state of a machine, and a tracked file
cannot be one — which is why no replacement current-state mirror exists. Required contents and
rationale live in `../manifest.md`.

| Area | Verified state |
|---|---|
| Windows / WSL | Windows 11 Pro build 26200 x64; WSL 2.7.11; Docker WSL distro running |
| Base toolchain | Git, GitHub CLI, Node/npm/npx, Docker/Compose, Python/pip, PowerShell 7, VS Code present and executable |
| Agent clients | Claude Code and Codex CLI installed and authenticated |
| Project dependencies | `npm ls --depth=0` clean; project-local Supabase CLI 2.109.0 operational |
| Docker | Docker Engine 29.7.2 reachable; Compose 5.5.1 |
| Extensions | All six required extensions present |
| Claude MCP | Four project servers enumerated as connected by `claude mcp list` |
| Codex MCP | Five required servers enumerated; Supabase OAuth currently reports login required |
| GitHub | CLI authenticated; canonical qualified origin reachable |
| One-click flow | `workstation.cmd` completed with zero required failures on its idempotent second run |

External authentication is intentionally not copied into the repository. The current Codex
`supabase-primary` OAuth session must be completed in the client before its data tools can be used.
This is authentication-required, not installation failure.

The old generated tool baselines were removed because they duplicated this living status, contained
stale versions and plugin claims, and had no consumer. Git history retains them.
