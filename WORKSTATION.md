# ORVION — Workstation Disaster Recovery & First-Time Bootstrap

This is the entry point for **recovering the ORVION workstation** onto a fresh Windows machine — after
an SSD failure, a Windows reinstall, or a new computer. Its job is *recovery*, not a daily dashboard.
It is separate from `README.md` (the entry point for *working on ORVION itself*).

**Primary purpose:** restore the ORVION **project** from GitHub onto a clean machine with the fewest
possible actions, and leave it immediately ready for development. Installing tools is only one step of
that recovery.

**One-authority note:** this file owns only *how to rebuild the workstation*. It points to the
scripts and manifest as the source of truth for the actual steps — it does not restate tool lists.
See `GOVERNANCE.md §2` (Workstation rebuild row).

**Design assumption (permanent):** the local machine is **disposable**; **GitHub is the permanent
source of truth**. Every workstation decision optimizes for rebuilding a completely new machine from
GitHub with the fewest user actions. When "convenient on this machine" conflicts with "reproducible
from GitHub," choose GitHub. (`doctor.ps1` enforces the spirit of this by warning when local commits
are not yet pushed.)

---

## Rebuild on a brand-new machine — ONE command

Open PowerShell on a fresh Windows 11 machine (no USB, no manual download) and run:

```powershell
irm https://raw.githubusercontent.com/PlatPlusHub/CRM/main/bootstrap.ps1 | iex
```

`bootstrap.ps1` (committed in this repo; the URL just delivers it) does the minimum needed *before* the
repo exists: ensure Git (install via `winget` if missing), clone this repository — **`PlatPlusHub/CRM`,
the CRM environment; never `Shehabhub/ORVION`, which is a separate environment** — from GitHub into `~/CRM`,
then hand off to the in-repo provisioner `.workstation/prepare.ps1`. **All real setup logic stays in
the repo** — the bootstrap only downloads the repository and transfers execution to it. Start Docker
Desktop once when prompted. When `prepare` reports a clean `doctor`, return to `README.md` and develop.

**Trust model:** `irm|iex` runs a script fetched over HTTPS from your own GitHub repo — the same trust
you place in the repo's scripts once cloned. This is the standard Windows bootstrap pattern (Chocolatey,
Scoop, rustup). The script is tiny and reviewable in the repo.

## Already have the repo? — Recovery & Maintenance launcher

Double-click **`workstation.cmd`** in the repo root. It is **recovery-first**: if base tools are
missing it offers to run recovery immediately; otherwise it shows the maintenance menu —
**Prepare/Repair · Verify · Update · Cleanup · Decommission** — with a GitHub-sync header. `prepare.ps1`
refreshes PATH in-session, so no shell restart is ever needed.

- **Terminal / no double-click:** run `./.workstation/prepare.ps1` (recover/repair) or `doctor.ps1` (verify).
- **AI agent controlling Windows:** call the `.workstation/*.ps1` scripts directly — **not** the menu.

`bootstrap.ps1` (remote entry) and `workstation.cmd → .workstation/menu.ps1` (local entry) are both thin
— they only clone/launch. The real implementation lives in `.workstation/*.ps1`. No duplicated logic,
no second authority.

**Retiring or selling this machine?** The menu's **Decommission** option (`.workstation/decommission.ps1`)
removes ORVION from the machine — the local repo + ORVION-specific env — after you type `DECOMMISSION`.
It never touches general tools or unrelated data, and it is fully recoverable via the bootstrap (GitHub
is permanent).

---

## What lives where

| Concern | Source of truth |
|---|---|
| Remote bootstrap (fresh machine, pre-clone) | `bootstrap.ps1` (root; served via GitHub raw URL) |
| Recovery & Maintenance launcher (human) | `workstation.cmd` (root) → `.workstation/menu.ps1` |
| What to install (tools, extensions, MCPs, plugins) + why | `.workstation/manifest.md` |
| Recover / provision the environment (real logic) | `.workstation/prepare.ps1` |
| Verify the environment (real logic) | `.workstation/doctor.ps1` |
| Decommission (remove ORVION from a retired machine) | `.workstation/decommission.ps1` |
| MCP server configuration | `.mcp.json` (repo root; secrets via env vars, never committed) |
| Claude engineering-awareness wiring (expected shape) | `.claude/awareness.json` (tracked) — applied by `.workstation/claude-awareness.ps1 -Apply`, verified by `-Verify`; `.claude/settings.json` itself stays machine-local |
| Known blockers | `.workstation/reports/INCIDENT_*.md` |
| Current install status | `.workstation/reports/INSTALLATION_STATUS.md` |

## Secrets (not in the repo)
Some MCP servers need secrets (e.g. the Supabase MCP connection string). Provide them as environment
variables before running `prepare.ps1`; they are never committed. `prepare.ps1` registers an MCP only
when its required env var is present.

## Known blocker
- **Claude Mem** worker does not stay healthy on Windows (port 37777). Parked; see
  `.workstation/reports/INCIDENT_CLAUDE_MEM_WINDOWS.md`. Not required for ORVION development.
