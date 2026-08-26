# ORVION — Environment Gate: Final Verification (EARNED)

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-26
Author: Claude Opus 5
Scope: Read-only re-verification of every Environment Gate criterion after the owner repaired the
GitHub identity and pushed. One deterministic repair was made (removal of a broken MCP entry).
**No CRM code was written** — WP-01/WP-02/WP-03 remain gated.

Predecessor: `environment-and-governance-gate-2026-08-26.md` (same session-day; that report's single
BLOCKER is now closed).

---

## VERDICT — ENVIRONMENT GATE: **EARNED**

Every criterion below was proven by a real read in this pass. Nothing is carried forward from the
previous report.

| # | Criterion | Evidence | Verdict |
|---|---|---|---|
| 1 | GitHub active identity is PlatPlusHub | `gh auth status` → `✓ Logged in to github.com account PlatPlusHub (keyring)`, **Active account: true** | **PROVEN** |
| 2 | origin/main == local HEAD | both `3b4b9612af5fe425a3a361fe5af9333cad717ee5`; `git status -sb` → `## main...origin/main` (no ahead/behind) | **PROVEN** |
| 3 | GitHub repository readable by authorized tooling | `gh repo view` → `PlatPlusHub/CRM`, default branch `main`, **`viewerPermission: ADMIN`**; `gh api …/commits/main` → `3b4b961`; `gh api …/contents/AGENTS.md` → 32313 bytes | **PROVEN** |
| 4 | supabase-primary reaches the canonical project | `get_project_url` → `https://vrvtsxexkiiiivlkdxzp.supabase.co` (read live, not transcribed) | **PROVEN** |
| 5 | Local == Primary fingerprint | local `119 \| f5902d9dc743c316fc6421230d092e6f \| 202607053000`; Primary **identical** | **PROVEN** |
| 6 | n8n MCP reachable | `list_credentials` → 2 credentials, project `Platinum Plus Tours <platplustours@gmail.com>` | **PROVEN** |
| 7 | context7 MCP reachable | `resolve-library-id` returned real PostgreSQL library results | **PROVEN** |
| 8 | postgres-local MCP reachable | ledger + object query returned (72 tables, 104 `app` functions) | **PROVEN** |
| 9 | Repository consistency guard | `REPOSITORY CONSISTENCY: CLEAN` | **PROVEN** |
| 10 | Database parity guard | `DATABASE PARITY: CLEAN (local proven; primary proven)` | **PROVEN** |
| 11 | Smoke | `ALL CHECKS PASSED (72 tables, RLS + policies, …)` | **PROVEN** |
| 12 | Regression suite | 34 files, **0 failures** | **PROVEN** |
| 13 | Working tree clean, nothing unpushed | `git status --porcelain` empty at verification; HEAD == origin/main | **PROVEN** |

## DISCOVERED

**E1 — The GitHub MCP added last session cannot connect, and cannot be made to without a secret.**

```
github: https://api.githubcopilot.com/mcp/ (HTTP)
  ✘ Failed to connect — Incompatible auth server: does not support dynamic client registration
```

`claude mcp list` health check. The GitHub Copilot MCP endpoint requires a pre-registered OAuth
client or a Personal Access Token; Claude Code performs dynamic client registration, which that
server rejects. No `mcp__github__*` tool was ever exposed, so the entry had been non-functional from
the moment it was added — it was **UNPROVEN, and this pass turned it into FAILED**, which is exactly
what the four-verdict rule exists to surface rather than let a green-looking config imply.

The only ways to make it work are a PAT in `.mcp.json` or in an environment variable — both are
secrets, and `AGENTS.md §6` forbids a third-party credential passing through the agent or into a
repository file.

**E2 — GitHub access does not actually depend on that MCP.** The `gh` CLI is authenticated as
PlatPlusHub with `ADMIN` permission on the repository and performs authenticated API reads
(criterion 3). Repository access through authorized GitHub tooling is therefore proven; only the MCP
*transport* was broken.

**E3 — Two pre-existing MCP observations, unchanged and not defects of this work.**
* `claude.ai Supabase` (account-level) is Connected and is **not** pinned to
  `vrvtsxexkiiiivlkdxzp`. Still the latent "wrong project" hazard recorded previously. It is
  account-level, not repository configuration, so it is not mine to remove.
* `serena` is `⊘ Disabled for this project`. Not referenced by any governance file; harmless.

**E4 — `.claude/settings.json` was restored on disk to its pre-cleanup contents**, re-introducing the
one-off entries (a literal `sed` naming a scratchpad file, `Bash(bc)`, `Bash(echo "exit=$?")`). The
harness appends to this file as permissions are granted, so it is a generated-ish artifact rather
than hand-maintained governance. Consequence observed live: `mcp__n8n__search_workflows` was denied
mid-pass because the allowlist no longer carried it; n8n was proven with `list_credentials` instead.
Left as-is — fighting the harness over a file it rewrites is not a durable repair.

## FIXED

**Removed the broken `github` entry from `.mcp.json`.** Per the standing instruction not to preserve
broken configuration merely because it exists, and because a failing server re-reports on every
session start and trains readers to ignore health output. GitHub access remains proven through `gh`.

## NOT FIXED (deliberate)

* **No PAT-based GitHub MCP substituted.** That requires the owner to place a credential; choosing to
  introduce a long-lived token into the toolchain is theirs, not mine.
* `claude.ai Supabase` MCP — account-level, see E3.
* `.claude/settings.json` churn — see E4.
* The stale `git:https://github.com` → Shehabhub credential remains in Windows Credential Manager.
  Harmless now: `origin` is username-qualified and `gh` is authenticated as PlatPlusHub. `gh auth
  status` still lists Shehabhub as a second, non-active account.

## BLOCKED

**None.** The previous report's single blocker (interactive PlatPlusHub sign-in) is closed:
identity is PlatPlusHub, permission is ADMIN, and both commits are on `origin/main`.

## GOVERNANCE

No governance change this pass — the boot gate, session-report requirement and the two separate
guards were established in the predecessor report and were exercised, not modified, here. The
`github` MCP removal is configuration, not governance.

Worth recording for the next agent: **`claude mcp list` is the fastest way to satisfy `AGENTS.md §4`
step 8c**, because it reports a per-server health verdict — but a `✔ Connected` there still is not a
real read, and E1 is the reason the step demands one: a server can be listed and connected-looking
while exposing no usable tool.

## ENVIRONMENT

* **GitHub** — identity PlatPlusHub (active), `PlatPlusHub/CRM` public, `viewerPermission: ADMIN`,
  default branch `main`, remote `https://PlatPlusHub@github.com/PlatPlusHub/CRM.git`.
* **Local Supabase** — 119 migrations, 72 tables, 104 `app` functions, healthy.
* **Primary Supabase** — `vrvtsxexkiiiivlkdxzp`, 119 migrations, identical fingerprint, zero
  business rows.
* **MCP** — `postgres-local`, `supabase-primary`, `n8n`, `context7` all proven by real read;
  `github` removed (E1); `claude.ai Supabase` connected but unpinned (E3).
* **Google Cloud** — not re-verified this pass (not a gate criterion); last PROVEN state:
  `platplustours@gmail.com`, project `orvion-data-manager`, Data Manager API enabled.

## CURRENT STATE

* Migrations **119**, latest `202607053000`, fingerprint `f5902d9dc743c316fc6421230d092e6f` on
  repository, local **and** Primary.
* 72 tables · 104 `app` functions · 116 policies · 71 permissions. Primary holds zero business rows.
* Tests **34 files / 307 assertions / 0 failures**; smoke `ALL CHECKS PASSED`.
* Both guards CLEAN; parity guard previously negative-tested against four induced false states.
* Git: `main` == `origin/main` == `3b4b961` at verification time, working tree clean.

## NEXT STEP

**Align WP-03 (subscription-state enforcement) — alignment only, no implementation until its binary
acceptance criteria are written and its stop conditions are explicit.**

The recommendation to take WP-03 before WP-01 stands on evidence rather than preference: WP-01 adds
four *missing* creation events, whereas WP-03 corrects behaviour that is **live and inverted**
relative to the owner's stated rule — `app.plan_allows` currently lets `read_only` write while
`suspended`/`expired`/`cancelled` deny reads; 42 of 71 permissions bypass the gate entirely through a
null `required_feature_code`; a missing subscription row fails open; and `MANAGE_SUBSCRIPTION` is
held by no role, so subscription state cannot be changed by any user. Wrong behaviour outranks absent
behaviour. The ordering remains the owner's to confirm.
