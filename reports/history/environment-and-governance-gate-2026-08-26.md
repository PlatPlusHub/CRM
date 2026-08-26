# ORVION — Environment & Governance Gate

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-26
Author: Claude Opus 5
Scope: Environment health, GitHub identity repair, MCP verification and repair, negative-testing the
database parity guard, and the future-LLM boot gate. **No CRM functionality was implemented** — the
owner directive gated WP-01/02/03 behind this work.

---

## DISCOVERED

**D1 — GitHub identity split (root cause of the 403).** Commit authorship and push credential are
two different accounts:

| Layer | Identity | Source |
|---|---|---|
| commit author | `PlatPlusHub <platplustours@gmail.com>` | `~/.gitconfig` |
| `gh` CLI | `Shehabhub` | keyring |
| **git push credential** | **`Shehabhub`** | Git Credential Manager |

The credential helper is **Git Credential Manager**, *not* `gh` — so the push never used the `gh`
token at all. `cmdkey /list` showed three github entries: `git:https://github.com` → **Shehabhub**
(the one GCM serves to `git push`), `gh:github.com:Shehabhub`, and a separate
`GitHub - https://api.github.com/PlatPlusHub` → **PlatPlusHub**. The PlatPlusHub entry lives in
GitHub Desktop's namespace, which git does not consult — so the correct account's credential was
present on the machine but unreachable by git.

`gh` token scopes (`gist, read:org, repo, workflow`) are sufficient; this is an **authorization**
problem (the account is not a writer on `PlatPlusHub/CRM`), not a scope problem.

**D2 — No GitHub MCP was configured at all.** `.mcp.json` held four servers (context7,
postgres-local, supabase-primary, n8n). Repository access through GitHub tooling was therefore
impossible to verify independently of the Git CLI.

**D3 — A second, account-level Supabase MCP exists** (`claude_ai_Supabase`) alongside the repo's
`supabase-primary`. It exposes `list_projects`, `create_project`, `pause_project` and
`apply_migration` and is **not** pinned to `vrvtsxexkiiiivlkdxzp`. It is currently blocked by a
permission hook, so it is a latent rather than active risk — but it is exactly the "two connectors,
one of them pointing somewhere else" hazard, and a future agent could reach the wrong project.

**D4 — Permission allowlist had accumulated one-off junk.** `.claude/settings.json` contained
entries such as a literal `sed` invocation naming a scratchpad file, `Bash(bc)`, and
`Bash(echo "exit=$?")` — patterns that can never match again.

## VERIFIED

Every item below is **PROVEN** by a real read this session; nothing is carried over from a prior
report.

| Target | Evidence | Verdict |
|---|---|---|
| Repository files | 119 migrations, latest `202607053000` | PROVEN |
| **Local** | `119 \| f5902d9dc743c316fc6421230d092e6f \| 202607053000` | PROVEN |
| **Primary** | same fingerprint; `get_project_url` → `https://vrvtsxexkiiiivlkdxzp.supabase.co` (read live, not transcribed) | PROVEN |
| Repository guard | `REPOSITORY CONSISTENCY: CLEAN` | PROVEN |
| Database parity guard | `DATABASE PARITY: CLEAN (local proven; primary proven)` | PROVEN |
| Test suite | 34 files, 307 assertions, **0 failures** | PROVEN |
| Smoke | `ALL CHECKS PASSED (72 tables …)` | PROVEN |
| `postgres-local` MCP | ledger query returned | PROVEN |
| `supabase-primary` MCP | project URL + SQL read | PROVEN |
| `n8n` MCP | live read: **0 workflows**, 2 credentials | PROVEN |
| `context7` MCP | `resolve-library-id` returned real results | PROVEN |
| Git read access | `git ls-remote` → `refs/heads/main` | PROVEN |
| **Git push access** | 403 → after remote fix, needs interactive sign-in | **BLOCKED** |
| `github` MCP | added this session, needs OAuth | **UNPROVEN** |
| `claude_ai_Supabase` MCP | blocked by permission hook | UNPROVEN (latent risk) |
| Google Cloud | account `platplustours@gmail.com`, project `orvion-data-manager`, `datamanager.googleapis.com` ENABLED | PROVEN (prior session; unchanged) |

### The parity guard was negative-tested, not merely run

A guard is not earned because it prints CLEAN. Four false states were induced deliberately and each
was detected; all were then restored and the real state re-proven:

| Induced state | Guard output |
|---|---|
| extra migration file (120 vs 119) | `LOCAL DRIFT: repository holds 120 migrations, local database has applied 119` |
| same count, renamed file | `LOCAL DRIFT: counts agree but contents differ -- same number of migrations, different set` |
| unreachable container | `UNREACHABLE: … Local parity is UNPROVEN, not CLEAN.` |
| wrong Primary fingerprint | `PRIMARY DRIFT: Primary reports deadbeef…, repository produces f5902d9d…` |

Restore confirmed: 119 files present, `git status` clean of leftovers, then
`DATABASE PARITY: CLEAN (local proven; primary proven)`.

## FIXED

1. **Remote qualified with the intended account** — `origin` is now
   `https://PlatPlusHub@github.com/PlatPlusHub/CRM.git`. This is the mechanism that stops git
   silently falling back to the Shehabhub credential; the account is now explicit in the URL. It is
   no regression, because pushes were already failing with 403.
2. **GitHub MCP added** (`.mcp.json` + `settings.local.json`) using the tokenless OAuth endpoint
   `https://api.githubcopilot.com/mcp/`, so no secret enters the repository.
3. **Permission allowlist rewritten** to durable, general entries only.
4. **Boot gate strengthened in `AGENTS.md §4`** (the existing single authority — no new document):
   * an explicit **DO NOT TRUST CHAT HISTORY AS CURRENT STATE** block, with the four-verdict rule
     (PROVEN / UNPROVEN / FAILED / BLOCKED) and the instruction never to narrow UNPROVEN to PROVEN;
   * step **8b** — run the database parity guard, separately from the repository guard;
   * step **8c** — prove every MCP by a real read, including the warning about the second Supabase
     connector;
   * Stage A step **7** — reading the latest session report is now mandatory, not "on demand";
   * step 8 now states the repository guard's scope limit explicitly.
5. **Session-report requirement governed** in `AGENTS.md §6`, with the required sections and the
   rule that an unlinked report does not exist.
6. **`reports/README.md`** gained a **Latest session report** pointer row, which the boot sequence
   now reads.

## NOT FIXED (deliberate)

* **`claude_ai_Supabase` MCP not removed.** It is account-level, not repository configuration, so it
  is not mine to delete — and it is currently inert behind a permission hook. Documented as a risk
  instead. If the owner wants it gone it must be removed in claude.ai settings.
* **The stale `git:https://github.com` → Shehabhub credential was left in place.** Deleting a
  credential the owner may rely on for other repositories is outside deterministic repair, and the
  username-qualified remote already prevents it being used here.
* **No CRM work.** WP-01/02/03, documents, notifications, 360s all untouched, per the directive.
* `supabase_edge_runtime_ORVION` has been exited for five weeks. ORVION uses no Edge Functions, so
  this is cosmetic; recorded rather than restarted.

## BLOCKED

**B1 — `git push` requires one interactive sign-in as PlatPlusHub.** This is the only blocker.

Evidence:
```
$ git push origin main
fatal: could not read Password for 'https://PlatPlusHub@github.com': terminal prompts disabled
```
GCM holds no credential for `PlatPlusHub@github.com` in git's namespace. A credential cannot be
created without an interactive browser/device sign-in, and `AGENTS.md §6` forbids a secret passing
through the agent — so this cannot be automated, only performed by the owner.

**Minimum owner action (one of):**
```
gh auth login          # choose GitHub.com → HTTPS → browser → sign in as PlatPlusHub
gh auth setup-git      # makes gh the git credential helper, giving ONE coherent identity
```
or simply run `git push` in an interactive terminal and complete the GCM prompt as PlatPlusHub.

Afterwards `gh auth status` should show **PlatPlusHub** active, and `git push origin main` will
publish the two waiting commits.

**Consequence while this stands:** local and Primary are at 119; **GitHub is at 118**. Anyone cold-
booting from `origin` would rebuild local at 118 and see false drift against Primary. The parity
guard detects exactly this, but the divergence should not be left open.

## GOVERNANCE

* `AGENTS.md §4` — boot gate hardened (see FIXED 4).
* `AGENTS.md §6` — session report is now a standing requirement.
* `reports/README.md` — Latest-session-report pointer.
* `scripts/check_database_parity.ps1` — negative-tested against four false states.
* `scripts/check_repository_consistency.ps1` — prints its own scope on success (added previous
  session, exercised here).

The source-of-truth hierarchy the boot gate now enforces:
`CANON/GOVERNANCE → REPOSITORY → MIGRATIONS → LOCAL DB → PRIMARY DB → INTEGRATION CONTRACTS → n8n/Google/UI`.
A layer may never claim parity with the layer below it without a guard that actually tested it.

## CURRENT STATE

* Migrations **119**, latest `202607053000`, fingerprint `f5902d9dc743c316fc6421230d092e6f` on
  repository, local **and** Primary.
* Objects: 72 tables, 104 `app` functions, 116 policies, 71 permissions. Primary holds zero business
  rows.
* Tests 34 files / **307 assertions / 0 failures**; smoke `ALL CHECKS PASSED`.
* Both guards CLEAN; parity guard negative-tested.
* Git: branch `main`, **ahead of `origin/main` by 2 commits**, working tree clean, remote
  `https://PlatPlusHub@github.com/PlatPlusHub/CRM.git`.

## NEXT STEP

**Complete B1** — sign in as PlatPlusHub (`gh auth login` + `gh auth setup-git`), push the waiting
commits, then re-verify `gh auth status`, `git push`, and the `github` MCP by a real read. That
closes the last three UNPROVEN rows and earns the environment gate in full.

Only then resume CRM work. On current evidence the next package should be **WP-03 (subscription
state)** ahead of WP-01: WP-01 adds four missing creation events, whereas WP-03 corrects behaviour
that is live and **inverted** relative to the owner's rule — `read_only` currently permits writes and
`suspended`/`expired`/`cancelled` deny reads, 42 of 71 permissions bypass the gate via a null
`required_feature_code`, a missing subscription fails open, and `MANAGE_SUBSCRIPTION` is held by no
role. Wrong behaviour outranks absent behaviour. That reordering is a recommendation, not a decision
taken.
