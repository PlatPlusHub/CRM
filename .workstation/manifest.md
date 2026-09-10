# ORVION Workstation Manifest

Status: Living-Authoritative
Last curated: 2026-09-10
Platform: Current supported Windows 11, x64

This file is the single source of truth for what the ORVION engineering workstation needs and why.
`.workstation/prepare.ps1` provisions it and `.workstation/doctor.ps1` verifies it. Observed versions
are evidence, not pins; package identities and `package-lock.json` are the reproducible contracts.

## 1. Required environment and tools

| Component | Installation source | Why required | Live evidence 2026-09-10 | Bootstrap coverage |
|---|---|---|---|---|
| Windows 11 x64 | Laptop/Windows Update | Supported Docker and agent host | Build 26200, x64 | Prerequisite; doctor verifies |
| Windows Package Manager | Microsoft App Installer | Official package installer | winget 1.29.290 | Prerequisite; bootstrap fails clearly if absent |
| WSL 2 | `wsl --install --no-distribution` | Docker Linux-container backend | WSL 2.7.11, Docker distro running | Detected; admin/reboot boundary reported |
| Git | winget `Git.Git` | Repository is durable truth | 2.55.0.windows.4 | Installed and verified |
| GitHub CLI | winget `GitHub.cli` | GitHub identity and reachability | 2.100.0, authenticated | Installed; OAuth login external |
| Node.js LTS / npm / npx | winget `OpenJS.NodeJS.LTS` | Dependencies, Supabase, MCPs, agent CLIs | Node 24.19.0, npm/npx 11.17.0 | Installed and verified |
| Docker Desktop / Compose | winget `Docker.DockerDesktop` | Local Supabase/Postgres | Engine 29.7.2, Compose 5.5.1 | Installed, launched, readiness verified |
| Python 3.12 | winget `Python.Python.3.12` | Repository and agent scripts | 3.12.10, pip 25.0.1 | Installed and verified |
| PowerShell 7 | winget `Microsoft.PowerShell` | Repository scripts and guards | 7.6.6 | Installed and verified |
| VS Code | winget `Microsoft.VisualStudioCode` | Editor and agent host | 1.136.2 | Installed and verified |
| Claude Code CLI | npm `@anthropic-ai/claude-code` | Supported engineering client | 2.1.260 | Installed only when missing; auth external |
| Codex CLI | npm `@openai/codex` | Supported engineering client | 0.153.4 | Installed only when missing; auth external |
| Supabase CLI | project dev dependency `supabase` | Migration reset/test and local stack | package range `^2.109.0`; dependency missing before repair | Restored by `npm ci`; invoked project-locally |
| PostgreSQL client | Supabase database container | SQL tests and diagnostics | Host `psql` absent; container client operational | Docker/Supabase supplies it; no duplicate host install |

Gemini CLI and an n8n CLI are not required: neither is installed, no repository workflow invokes
them, and n8n is accessed through remote MCP. A host PostgreSQL install is unnecessary because the
repository deliberately executes `psql` in the local Supabase container.

## 2. Required VS Code extensions

`prepare.ps1` installs and `doctor.ps1` verifies:

| Extension | Purpose |
|---|---|
| `anthropic.claude-code` | Claude Code client |
| `openai.chatgpt` | Codex/ChatGPT IDE client |
| `supabase.vscode-supabase-extension` | Supabase tooling |
| `mtxr.sqltools` | PostgreSQL/SQL inspection |
| `ms-vscode.powershell` | PowerShell editing |
| `ms-azuretools.vscode-docker` | Docker container inspection |

GitHub Copilot and personal editor extensions are optional. Azure, Codespaces, and unrelated
extensions are neither installed nor removed by bootstrap.

## 3. MCP inventory and authentication

The four project MCP definitions live in `.mcp.json`, which Claude loads at project scope.
`prepare.ps1` idempotently mirrors them into Codex because Codex uses user configuration rather than
importing `.mcp.json`. A mismatching Codex definition is reported, never silently overwritten.

| Server | Clients | Connection/runtime | Authentication | Bootstrap status |
|---|---|---|---|---|
| `context7` | Claude, Codex | stdio `npx -y @upstash/context7-mcp` | None | Defined, registered, enumerated |
| `postgres-local` | Claude, Codex | stdio Node MCP to local port 54322 | Local-dev credentials only | Defined, registered, usable with stack |
| `supabase-primary` | Claude, Codex | official remote MCP scoped to Primary ref | Browser OAuth; no PAT in repo | Defined and registered; auth separate |
| `n8n` | Claude, Codex | `https://plat.app.n8n.cloud/mcp-server/http` | OAuth/account authorization | Defined and registered; auth separate |
| `github` | Codex; shell uses `gh` | GitHub Copilot MCP endpoint | `GITHUB_PAT_TOKEN` env name; value external | Registered; variable presence checked |

Claude.ai account connectors, Codex bundled MCPs (`node_repl`, computer use), and bundled/account
plugins are client-managed or account-managed. They are not repository dependencies and private
profiles are never copied. Supported client login/sync flows restore that state.

## 4. Agent integrations

- `.claude/awareness.json` is the tracked Claude hook/permission expectation;
  `claude-awareness.ps1 -Apply` merges it without replacing personal settings.
- `AGENTS.md` is the cross-client instruction authority; no duplicate agent rule file is generated.
- Codex bundled plugins and account connectors restore after `codex login`; scripts do not pin
  client-internal runtime paths or copy `%USERPROFILE%\.codex`.
- `claude plugin list` reported no installed plugins on 2026-09-10, so no Claude plugin is required.

## 5. One-click flow and safety

`workstation.cmd` invokes `.workstation/prepare.ps1` directly. The provisioner:

1. detects or installs base tools through official winget package IDs;
2. refreshes current-process PATH after installations;
3. verifies WSL 2 and reports the unavoidable elevation/reboot boundary;
4. installs missing agent CLIs and runs `npm ci` from the lockfile;
5. installs only required VS Code extensions;
6. validates `.mcp.json` and registers missing Codex MCPs without secrets;
7. applies Claude repository-awareness wiring;
8. starts Docker Desktop if needed and waits for readiness;
9. runs `doctor.ps1` and returns non-zero for any required failure.

Repeated runs detect valid installations and never uninstall, overwrite credentials, or replace
unrelated configuration. OAuth/browser authorization, first-time WSL elevation plus reboot, and
Docker Desktop's first-run agreement are the legitimate manual boundaries.

## 6. Scripts

| Script | Purpose |
|---|---|
| `prepare.ps1` | One-click provisioning and final verification |
| `doctor.ps1` | Read-only verification with authoritative exit code |
| `update.ps1` | Upgrade the required tools and agents, then verify |
| `menu.ps1` | Optional maintenance menu; not the setup entry point |
| `cleanup.ps1` | Remove only known transient workstation artifacts |
| `decommission.ps1` | Confirmation-gated ORVION-specific removal |
| `claude-awareness.ps1` | Additive apply/verify of Claude repository wiring |

The disabled Claude Mem experiment remains historical evidence in
`.workstation/reports/INCIDENT_CLAUDE_MEM_WINDOWS.md`; it is not required.
