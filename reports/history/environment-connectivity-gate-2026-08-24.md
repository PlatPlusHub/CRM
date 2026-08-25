# ORVION — Environment & Connectivity Gate

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-24
Author: Claude Opus 5
Scope: Owner environment/connectivity gate. **Read-only. No schema, data, migration, workflow or
configuration change was made.**

Every line is **VERIFIED** (I executed it and read the result) or **INFERRED** (reasoned from evidence
I did read). Nothing here is taken from a previous report.

---

## 0. THE FINDING THAT MATTERS MOST — project ref

**The project ref in your message does not exist. The one in the repository does.**

| Source | Ref | DNS resolution |
| --- | --- | --- |
| Your message | `vrvtsxexk**i****ll**i**v**i**kdxzp` | **does not resolve** |
| Repository | `vrvtsxexk**iiii**v**l**kdxzp` | **resolves** → `172.64.149.246` |

The two differ at exactly three positions, and every difference is an `i` ↔ `l` swap — the classic
lowercase-L / lowercase-i confusion when transcribing from a dashboard. Both are 20 characters and
identical everywhere else.

**Independent corroboration that this is the same project:** your dashboard reports the last migration
as `complete_catalog_enforcement`. That is migration `202607051300` (SPEC-136), which is **#102** — and
102 is exactly the migration count the repository records for Primary. Identity confirmed by *state*,
not just by string.

**Conclusion (VERIFIED):** the dashboard project is ORVION Primary, and the canonical ref is the one
already in the repository. **No configuration change is needed, and the ref must not be "corrected" to
the value in your message** — that would point the project at nothing.

---

## 1. Environment map

| Component | Connected | Verified how | Identity | Current state | Sync | Blocker |
| --- | --- | --- | --- | --- | --- | --- |
| **Repository** | yes | git | `PlatPlusHub/CRM`, branch `main` | HEAD `8e91154`, clean, 0 unpushed | = GitHub | none |
| **GitHub** | yes | **real read** (`git ls-remote`) | `PlatPlusHub/CRM` | `refs/heads/main` = `8e91154b…` | matches local HEAD exactly | none |
| **Local Supabase** | yes | **real reads** (`postgres-local` MCP) | PostgreSQL 17.6 | 118 migrations, 72 tables, 104 `app` functions, 116 policies | = repository exactly | none |
| **Primary Supabase** | **NO** | 3 paths tested, all failed | `vrvtsxexkiiiivlkdxzp` (DNS-confirmed) | last known: 102 migrations | **16 BEHIND** | OAuth session expired |
| **n8n** | yes | **real read** (`search_workflows`) | `plat.app.n8n.cloud` | **0 workflows** | n/a | none |
| **Google Cloud** | yes | **real reads** (`gcloud`) | project `orvion-data-manager` | SDK 580.0.0, `datamanager.googleapis.com` **ENABLED**, account authenticated | n/a | none |
| **context7** | configured | not exercised | docs MCP | — | n/a | none (not required by this gate) |

**No MCP was claimed connected on the strength of its configuration file.** `n8n` and `postgres-local`
were each proven by a real data call. `supabase-primary`'s tools are **absent from the runtime
entirely** — not merely erroring.

---

## 2. Primary — exact blocker

Three independent access paths tested, all read-only:

| Path | Result |
| --- | --- |
| `supabase-primary` MCP tools | **absent from the runtime** — schemas cannot be loaded, so no call is possible |
| `supabase/.temp/project-ref` (CLI link) | **file does not exist** — project is not linked |
| `SUPABASE_ACCESS_TOKEN` / `SUPABASE_DB_PASSWORD` env | **neither is set** |

The MCP is configured as `type: http` against `mcp.supabase.com` with **no credential field** — it is
the Remote MCP over OAuth. The session has expired.

**Exact blocker (VERIFIED):** interactive OAuth re-authorization is required. It cannot be completed
non-interactively, and I will not fabricate a token, endpoint or connection state. Run `/mcp` (or
`claude mcp`) in an interactive session and re-authorize `supabase-primary`.

**I have not treated local as Primary, and make no parity claim.**

---

## 3. Source of truth — proven, not assumed

| Layer | Migrations | Latest | Fingerprint |
| --- | --- | --- | --- |
| Repository (files) | **118** | `202607052900_lead_owner_assignee_coherence` | — |
| Local Supabase (ledger) | **118** | `202607052900` | `5d3d4cbe27ec1ad5b75e9b4f91432eaa` |
| Primary | **102** (last known, unverifiable now) | `202607051300_complete_catalog_enforcement` | — |

- **Repository = Local: VERIFIED equal.** File list and ledger match exactly — no migration file
  missing from the ledger, no ledger row without a file.
- **Primary is 16 behind. INFERRED**, from your dashboard's "last migration =
  `complete_catalog_enforcement`" plus the repository's own record. It cannot be verified live.
- **The difference is expected, not accidental** — 16 migrations authored across this and the two
  preceding sessions, none ever deployed.
- **Nothing appears to exist in Primary that is absent from the repository.** INFERRED from the
  dashboard's latest-migration name matching a repository file; not provable without access.

**Ahead: repository and local, jointly.**

---

## 4. Integrity / corruption check (local, read-only)

| Check | Result |
| --- | --- |
| Tables without RLS | **0** |
| Tables without any policy | **1** — `integration_cursors`, the documented intentional exception |
| SECURITY DEFINER functions without pinned `search_path` | **0** |
| Grants to `anon` | **0** |
| `DELETE` grants to `authenticated` | **0** (archive-oriented policy holds) |
| Foreign keys / tenant-qualified composite FKs | **277 / 191** |
| Duplicate indexes | **none** |
| Orphaned or malformed ledger rows | **0** |
| Catalog families with zero values | **none** (68 types / 583 values) |
| Lifecycle transition triggers / registered transitions | **10 / 104** |
| Archive-authority triggers | **13** |
| `scope_isolation` policies | **26** |
| Feature entitlements / plan-gated permissions | **66 / 29** |

**No evidence of data loss, failed migration, schema drift or corruption.**

---

## 5. New findings from this gate

### 5.1 140 FK entity columns have no index — **VERIFIED, severity qualified**

Counting distinct `(table, column)` pairs, excluding `tenant_id`: **140 foreign-key columns have no
index leading on them.**

Most are low-value to index (`created_by`, `archived_by`, `voided_by`, `currency_code`). **But a
significant subset is load-bearing for the read-scope model** — every column each `scope_isolation`
policy filters on:

`leads.owner_user_id`, `leads.owner_branch_id`, `leads.owner_department_id`, `leads.assigned_user_id`,
`bookings.branch_id`, `bookings.department_id`, `bookings.owner_*`, `booking_items.owner_*`,
`tasks.owner_*`, `conversations.owner_*`, `quotations.owner_*`, `complaints.owner_*`,
`service_requests.owner_*`, and `events.actor_user_id`.

**INFERRED:** this is consistent with the Seq Scans measured on scoped list queries last session
(lead list 25 ms at 20k rows, booking list 18 ms at 10k).

**Not yet established:** whether indexing them would change the plan at all. The policy predicate is
an OR-chain over InitPlan subqueries, which frequently forces a sequential scan regardless of
available indexes. **I would test before adding 140 indexes**, because unhelpful indexes cost write
throughput on every insert and update.

### 5.2 The manifest is stale again — **VERIFIED**

| Manifest says | Live reality |
| --- | --- |
| latest `202607052300` | `202607052900` |
| Primary "is 15 BEHIND" | **16** behind (118 − 102) |

Both are my omissions from the last three commits.

### 5.3 The consistency guard cannot catch 5.2 — **VERIFIED, governance gap**

`check_repository_consistency.ps1` reports **CLEAN** while the manifest carries a wrong migration
count and a wrong Primary gap. The guard checks broken references, register contradictions, boot-router
integrity, report classes, manifest *leanness*, roadmap↔manifest phase agreement, ai-map freshness and
Supabase topology — but **nothing compares the manifest's stated migration count to the actual one.**

That is precisely the class of stale claim this project has been bitten by before, and it is
mechanically checkable.

---

## 6. Governance / workflow health (lightweight)

- Boot chain intact: every target named by `README.md` → `AGENTS.md §4` exists.
- Consistency guard: **CLEAN**.
- Repository identity coherent: documentation names `PlatPlusHub/CRM` 21 times as the deployment
  repository and `Shehabhub/ORVION` 16 times as the *separate* Secondary environment — expected, not
  drift.
- No project skills directory, and governance requires none.
- No obsolete MCP references found; the four configured servers are the four the workflow names.

---

## 7. Is the environment safe to continue engineering work?

**Locally: yes.** Repository, local database and GitHub are mutually consistent and verified by live
reads. Structural integrity is clean on every dimension checked.

**Against Primary: no.** It cannot be reached, and no synchronization or deployment decision should be
made until it can.

---

## 8. Recommended next step

1. **Re-authorize `supabase-primary` interactively** (`/mcp` or `claude mcp`). This is the only
   blocker, and it gates deployment, parity and the freeze regardless of what else gets built.
2. On reconnection, **before deploying anything**: read Primary's live migration ledger and compare
   fingerprints, to confirm the 16-migration gap and that Primary contains nothing the repository
   lacks. The dashboard's migration name is corroborating evidence, not proof.
3. **Do not change the project ref** to the value in your message — it resolves to nothing.

Two small repairs I would make once you approve resuming work: correct the manifest (5.2), and add a
migration-count assertion to the consistency guard so 5.2 cannot recur silently (5.3).

---

**Gate complete. Stopped for review. No changes made to schema, data, migrations, n8n, Google, or
production configuration.**
