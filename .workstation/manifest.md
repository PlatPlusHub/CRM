# ORVION Workstation Manifest

**This file is the single source of truth for what the ORVION engineering workstation contains.**
`prepare.ps1` provisions exactly this list; `doctor.ps1` verifies it. Every entry earns its place by
measurable value to ORVION or to the primary engineering agent (Claude Code). Nothing is listed
"because it exists."

Last curated: 2026-07-11 · Platform: Windows 11 + PowerShell · Primary agent: Claude Code

---

## 1. Base tools (required — ORVION cannot be built without these)

| Tool | winget id | Why it earns its place | Verified |
|---|---|---|---|
| Git | `Git.Git` | version control; the repo is the SSOT | ✅ 2.54.0 |
| Node.js LTS | `OpenJS.NodeJS.LTS` | runs `npx supabase`, tooling | ✅ v24.18 |
| Docker Desktop | `Docker.DockerDesktop` | local Supabase/Postgres stack (`supabase start`) | ✅ 29.6.1 |
| Python 3 | `Python.Python.3.12` | base scripting dependency | ✅ 3.12.10 |
| VS Code | `Microsoft.VisualStudioCode` | editor host for all agents/extensions | ✅ 1.129 |
| Supabase CLI | via `npx supabase` (no global install) | migrations, `db reset`, `test db` | ✅ 2.109 |

> Supabase CLI is intentionally **not** installed globally — `npx supabase` pins per-project and avoids a stale global. Verified working this session.

## 2. VS Code extensions

**Auto-installed by `prepare.ps1`** — the minimum ORVION-essential set (a clean, intentional recovery
environment, NOT a copy of anyone's editor):

| Extension | id | Why it earns auto-install |
|---|---|---|
| Claude Code | `anthropic.claude-code` | primary engineering interface — non-negotiable |
| Supabase | `supabase.vscode-supabase-extension` | ORVION *is* Supabase |
| SQLTools | `mtxr.sqltools` | ORVION is SQL/Postgres-heavy |
| PowerShell | `ms-vscode.powershell` | workstation scripts + shell are `.ps1` |
| Docker | `ms-azuretools.vscode-docker` | local Supabase stack runs on Docker |

**Recommended, NOT auto-installed** (owner/personal tools — offered via `.vscode/extensions.json` for
one-click add, but a fresh recovery does not force them): `github.copilot`, `openai.chatgpt` (Codex).
Not required for ORVION development or recovery.

Recommended **removals** (installed but fail Earn-It for ORVION — a local Supabase/Postgres project; user-global, so removal is owner-confirmed, not auto):

| Extension | Why it fails |
|---|---|
| `ms-azuretools.vscode-azure-github-copilot` | Azure — ORVION has no Azure surface |
| `ms-azuretools.vscode-azure-mcp-server` | Azure MCP — irrelevant |
| `ms-azuretools.vscode-azureresourcegroups` | Azure resource mgmt — irrelevant |
| `github.codespaces` | cloud dev environments — ORVION is local |
| `continue.continue` | already removed — overlapped the primary agent |

Kept as owner conveniences (harmless, not part of the reproducible set): gitlens, errorlens, prettier, eslint, markdown/yaml tooling, python support, path-intellisense, etc. — the owner's editor, out of scope for the ORVION manifest.

## 3. Claude plugins

| Plugin | Earn-It verdict |
|---|---|
| GitKraken Hooks | **Keep** — provides durability (auto-commit). Improve commit-message convention (currently `"y"`). |
| Ponytail | **Keep (as-used)** — second-opinion review flow; occasional but real value |
| claude-mem | **Disabled** — `failed to load: cache-miss` + Windows worker never healthy; redundant with file-memory + self-describing repo. Confirmed `false` in global `.claude/settings.json` (2026-07-13) — its dead `UserPromptSubmit` hook was timing out at 60s. Re-enable only if upstream ships a Windows fix. |
| Impeccable (`pbakaus/impeccable`) | **Deferred** — frontend design skill pack (typography/color/motion, UI critique, browser Live Mode). ORVION is backend-only (SQL migrations + RPCs, no UI surface), so it has nothing to act on. Adopt when the first application UI is built — same trigger as Playwright (§4). |

## 4. MCP servers (`.mcp.json` at repo root)

| MCP | Earn-It verdict |
|---|---|
| Postgres MCP (`postgres-local` in `.mcp.json`) | **Adopted** — `@modelcontextprotocol/server-postgres` pointed at the local Supabase Postgres; the one MCP that measurably speeds the agent's ORVION work (direct schema/SQL/RLS vs `docker exec`). Uses the standard local dev string (`127.0.0.1:54322`, non-secret); a hosted/remote target would move the string to an env var — never commit a real secret. |
| Context7 | **Keep** — connected, near-zero maintenance, occasional doc lookups |
| `supabase-primary` (`.mcp.json`, added 2026-08-15, **switched local-stdio/PAT → official Remote MCP/OAuth 2026-08-15**) | **Adopted and VERIFIED WORKING (2026-08-15).** Official Supabase-hosted **Remote MCP server**, `"type": "http"`, `"url": "https://mcp.supabase.com/mcp?project_ref=vrvtsxexkiiiivlkdxzp"` (Streamable HTTP transport, project-ref-scoped to the authoritative Primary Supabase project; full topology `MASTER_INTEGRATION_CATALOG.md §0`). Config verified against official docs (`supabase.com/docs/guides/ai-tools/mcp`) 2026-08-15. **No `SUPABASE_ACCESS_TOKEN` / PAT of any kind — this entry has no `env` block.** Authenticates via OAuth 2.1 + dynamic client registration: the MCP client opens a browser, the owner signs in and authorizes (use the `platplustours@gmail.com` account — the Primary project's owning account per the topology table). **`list_migrations` confirmed successful (2026-08-15)** — a real authenticated Management API call, returning 88 migrations through `202607049900`, and `get_project_url` confirms the live ref matches `vrvtsxexkiiiivlkdxzp` exactly; Secondary (via `claude_ai_Supabase`, ref `brplkqmbzffpxqgkkdzo`) confirmed simultaneously reachable in the same session. **Known intermittency (2026-08-15):** the first two OAuth attempts that same session (initial auth, then a full disconnect + fresh re-auth) both produced `Unauthorized. Please provide a valid access token...` on every data-access tool while `get_project_url` kept succeeding — matching upstream report `supabase/supabase#38926`. A *third* `/mcp` disconnect+reauthenticate cycle then succeeded with no config change. **Treat as flaky, not fixed:** a new session must independently re-verify with a real data call (`list_migrations`, not just `get_project_url`) before trusting Primary is reachable; if `Unauthorized` recurs, try one more full disconnect+reauth cycle before escalating — do not fall back to a PAT without explicit owner authorization. **Replaces the prior local `npx @supabase/mcp-server-supabase` stdio server + PAT approach entirely** (PAT dependency removed, not parallel). |
| `n8n` (`.mcp.json`, **project scope, added 2026-08-20**) | **Adopted — registration fixed, authentication still pending.** n8n's official MCP server, `"type": "http"`, `"url": "https://plat.app.n8n.cloud/mcp-server/http"` (non-secret endpoint, exactly like `supabase-primary` — no credential is committed); grants workflow create/update/execute + execution-read, and is available on **all n8n editions, so no paid upgrade is required**. **Root cause it fixes (verified 2026-08-20):** the server had been registered in `~/.claude.json` under *local scope for `C:/Users/Platinum Plus/Documents/GitHub/ORVION`* — the pre-migration path, which no longer exists (the repository was intentionally migrated `Shehabhub/ORVION` → `PlatPlusHub/CRM`, local `.../GitHub/CRM`). From the current directory `claude mcp get n8n` reported "No MCP server named n8n", so **no** fresh session could ever load its tools — the 2026-08-17 "a fresh session is the only remaining prerequisite" diagnosis was wrong. That orphaned entry was removed and the server re-registered at **project scope so the configuration travels with the repository** into every future session and clone. **Approved and connected 2026-08-20:** approval is granted by listing the server in `enabledMcpjsonServers` in `.claude/settings.local.json` (per-machine, not versioned — a fresh clone re-approves there, `.mcp.json` carries the registration itself); `claude mcp get n8n` then reports **`✔ Connected`** with no OAuth prompt, i.e. the stored authorization survived the scope move. **Remaining prerequisite: a FRESH SESSION.** MCP tool registries are built at session start, so a server registered mid-session never exposes its tools — independently confirmed 2026-08-20 (a tool search for n8n tools returned nothing while `claude mcp get n8n` said Connected). **`✔ Connected` is a health check, not proof the tools work (`AGENTS.md §2`):** the next session must confirm with a real n8n data call before trusting it, and must still independently re-verify the two owner-reported-only n8n credentials (Google OAuth2, Postgres) per `MASTER_INTEGRATION_CATALOG.md §3/§4`. |
| GitHub push authentication (`origin` = `PlatPlusHub/CRM`) | **BLOCKED on owner action — diagnosed 2026-08-20, no workaround exists agent-side.** Git uses credential helper `manager` (Git Credential Manager, set in `C:/Program Files/Git/etc/gitconfig`); Windows Credential Manager holds `git:https://github.com` with **User `Shehabhub`** — the pre-migration account. Authentication *succeeds* and read works (`git ls-remote` returns refs), but `git push` fails **403 Permission to PlatPlusHub/CRM.git denied to Shehabhub** — an *authorization* failure, not a remote-URL or migration error. `gh` CLI is not installed; no `GH_TOKEN`/`GITHUB_TOKEN` is set; a non-destructive `git -c credential.https://github.com.username=PlatPlusHub push --dry-run` with `GCM_INTERACTIVE=never` failed with "Cannot prompt", proving **no PlatPlusHub git credential is cached** and interactive sign-in is genuinely required. (`git config user.name=Shehabhub` is commit *authorship* only and is not the cause; the `GitHub - https://api.github.com/PlatPlusHub` credential is a Desktop/API-style entry git's HTTPS helper does not read.) **Owner action — either:** (A) delete the `git:https://github.com` credential (`cmdkey /delete:LegacyGeneric:target=git:https://github.com`) then `git push` and sign in as **PlatPlusHub** in the browser — note this affects every repo on this machine pushing as Shehabhub; or (B) on github.com grant **Shehabhub** the **Write** role on `PlatPlusHub/CRM` and accept the invite. Until then commits stay local-only; nothing is lost and no history is rewritten. |
| Serena / GitHub / Playwright | **Deferred** — Serena (little payoff on a SQL/RPC repo), GitHub (gh CLI suffices), Playwright (no app UI to drive yet) |

## 5. Deliberately excluded (with reason)
- `opencode-ai` (global npm) — third-party AI CLI, not the primary agent, not an owner tool. Removed.
- Claude Mem worker — Windows blocker; see `reports/INCIDENT_CLAUDE_MEM_WINDOWS.md`.

---

**Reversibility:** every removal here is reinstallable (`winget`, `npm i -g`, `code --install-extension`, `claude plugin`). Nothing removed is irrecoverable.

---

## 6. Scripts (`.workstation/*.ps1`) — what each is and who runs it

The `.ps1` files hold all logic. Two thin entry points feed them: the **remote** `bootstrap.ps1`
(root; run via `irm …/bootstrap.ps1 | iex` on a bare machine — ensures git, clones the repo, hands off
to `prepare.ps1`) and the **local** `workstation.cmd` → `.workstation/menu.ps1` — a **Recovery & Maintenance** launcher
(NOT a dev dashboard). It is **recovery-first**: on launch, if base tools are missing it offers to run
recovery immediately; otherwise it shows maintenance — Prepare/Repair, Verify, Update, Cleanup,
Decommission — with a GitHub-sync header. The menu only dispatches / reads state; no logic lives in it.

**5.1 compatibility (hard constraint):** a fresh Windows machine runs **Windows PowerShell 5.1**, which reads a no-BOM `.ps1` as ANSI (not UTF-8) and lacks PS7-only syntax. All workstation scripts MUST be **pure ASCII** (no em dashes / box-drawing / smart-quotes) and avoid PS7-only syntax (ternary `?:`, `&&`, `||`, `??`). Verify with `powershell.exe` (5.1), not only `pwsh` 7.

`prepare.ps1` is intentionally a single linear script (~60 lines) -
not split into modules, because that would add orchestration overhead without earning it.

| Script | Purpose | When to run | Human? | AI agent? | Auto-called by | Idempotent / safe to repeat |
|---|---|---|---|---|---|---|
| `prepare.ps1` | **Recover/provision the environment:** install missing base tools (winget) + VS Code extensions + **Claude Code CLI** (npm global) + **project deps** (`npm install` → restores `node_modules` from `package-lock`); point at MCP config; refresh PATH in-session; then verify. Fault-tolerant — continues past failures and prints a summary + the manual re-provisions (Claude login, secrets, stack start). | Once on a fresh machine (menu → **1 Prepare**); re-run to **retry** failed items. | Yes (`workstation.cmd` → 1) | Yes (call `prepare.ps1` directly) | — | ✅ installs only what is missing |
| `doctor.ps1` | Verify the environment (read-only): tools on PATH, key repo files, Docker engine. | Anytime to check health; after `prepare`. | Yes (`workstation.cmd` → 2) | Yes | `prepare.ps1`, `update.ps1` (run it at the end) | ✅ read-only, changes nothing |
| `menu.ps1` | Interactive menu — the single human entry; invokes the scripts above. Refuses non-interactive input. | Whenever a human wants to run any workstation action. | Yes (via `workstation.cmd`) | No (call the `.ps1` scripts directly) | `workstation.cmd` | ✅ no logic of its own |
| `update.ps1` | Periodic maintenance: `winget upgrade` the workstation tools + `npm update -g` Claude Code, continue past failures, print a summary, then verify. (This is the "maintenance" command — update + verify in one; no separate `maintenance.ps1`.) | Occasionally (e.g. monthly). | Yes (run directly) | Optional | — (calls `doctor.ps1` at the end) | ✅ upgrades are no-ops if current |
| `cleanup.ps1` | Remove only transient/obsolete artifacts: retired-experiment env vars, gitignored generated logs, stray backups. Never touches committed files, migrations, or canon. | Rarely, if the tree accumulates transient logs. | Yes (run directly) | Optional | — | ✅ safe; skips what is absent |
| `decommission.ps1` | **Secure decommission** — remove ORVION from this machine (local repo + ORVION env vars; stops the local stack) for retire/sell/replace. Never touches general tools or unrelated data. Recoverable via the bootstrap (GitHub is permanent). | Only when retiring/selling this machine. | Yes (confirmation: type `DECOMMISSION`) | Optional | menu option 5 | ✅ but destructive — confirmation-gated |

`menu.ps1` (interactive, human-only — refuses non-interactive input) is reached via `workstation.cmd`;
it is the one entry point that exposes all four operations, so there are no per-action root launchers
(Earn-It: one launcher, not four). AI agents call the `.ps1` scripts directly.
