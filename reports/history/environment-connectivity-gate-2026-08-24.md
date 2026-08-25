# ORVION — Environment & Connectivity Gate

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-24
Author: Claude Opus 5
Scope: Owner environment/connectivity gate. **Read-only. No schema, data, migration, workflow or
configuration change was made.**

**Recheck status:** `supabase-primary` reconnected mid-gate. Primary is now **VERIFIED by live reads**.
This document supersedes the earlier revision in which Primary was unreachable.

Every line is **VERIFIED** (executed, result read) or **INFERRED** (reasoned from evidence read).

---

## 0. Project ref — settled by three independent proofs

**The ref in the directive does not exist. The repository's ref is correct.**

| Source | Ref | Evidence |
| --- | --- | --- |
| Directive | `vrvtsxexk**i****ll**i**v**i**kdxzp` | **does not resolve in DNS** |
| Repository | `vrvtsxexk**iiii**v**l**kdxzp` | **resolves** → `172.64.149.246` |
| **Live MCP** | `https://vrvtsxexkiiiivlkdxzp.supabase.co` | **`get_project_url` on the connected project** |

They differ at three positions, every one an `i` ↔ `l` swap — what transcribing a ref from a dashboard
produces, since those glyphs are identical in most fonts.

Two further corroborations, both **VERIFIED**:
- Your dashboard's "last migration = `complete_catalog_enforcement`" matches Primary's live
  `202607051300_complete_catalog_enforcement` exactly.
- Primary reports 72 tables and 68/583 catalog types/values — the repository's figures.

**The connected project IS ORVION Primary. Do not change the configured ref** — the directive's value
points at nothing.

---

## 1. Environment map — all six components verified

| Component | Connected | Verified how | Identity | State | Sync | Blocker |
| --- | --- | --- | --- | --- | --- | --- |
| **Repository** | yes | git | `PlatPlusHub/CRM`, `main` | HEAD `647d6b0`, clean, 0 unpushed | = GitHub | none |
| **GitHub** | yes | **real read** (`git ls-remote`) | `PlatPlusHub/CRM` | `refs/heads/main` matches local HEAD | in sync | none |
| **Local Supabase** | yes | **real reads** | PostgreSQL 17.6 | 118 migrations, 72 tables, 104 `app` fns, 116 policies, 71 permissions | = repository exactly | none |
| **Primary Supabase** | **yes** | **real reads** | `vrvtsxexkiiiivlkdxzp`, PG 17.6 | **102 migrations**, 72 tables, 82 `app` fns, 76 policies, 69 permissions | **16 behind, clean fast-forward** | none — reconnected |
| **n8n** | yes | **real read** | `plat.app.n8n.cloud` | **0 workflows** | n/a | none |
| **Google Cloud** | yes | **real reads** | `orvion-data-manager` | SDK 580.0.0, `datamanager.googleapis.com` ENABLED | n/a | none |

No MCP was claimed connected on the strength of its config file. Each was proven by a real data call.

---

## 2. Source of truth — PROVEN, not inferred

| Layer | Migrations | Latest | Ledger fingerprint |
| --- | --- | --- | --- |
| Repository (files) | **118** | `202607052900_lead_owner_assignee_coherence` | — |
| Local | **118** | `202607052900` | `5d3d4cbe27ec1ad5b75e9b4f91432eaa` |
| **Primary** | **102** | `202607051300_complete_catalog_enforcement` | `cd9c6dc1bfe0a8fbcd2b152377b9ad25` |

### The decisive check

Local's ledger fingerprint computed over **only its first 102 migrations** is
`cd9c6dc1bfe0a8fbcd2b152377b9ad25` — **byte-identical to Primary's full fingerprint**.

That proves, rather than suggests:

1. Primary contains **exactly** the repository's first 102 migrations, same versions, same names,
   same order.
2. **Primary has not diverged.** Nothing exists in Primary that is absent from the repository.
3. The gap is **exactly 16 migrations**, all present locally, and deployment is a **clean
   fast-forward** — not a merge, not a reconciliation.

### The 16 migrations Primary is missing

```
202607051400_read_scope_model                    202607052200_event_visibility_and_timelines
202607051500_branch_filed_write_paths            202607052300_document_read_scope
202607051600_rbac_write_authority                202607052400_financial_write_authority
202607051700_employee_financial_privacy          202607052500_plan_gating
202607051800_assignment_history_integrity        202607052600_resolution_path_indexes
202607051900_customer_first_registration         202607052700_lifecycle_transition_enforcement
202607052000_conditional_vocabulary_and_plan_matrix  202607052800_archive_authority
202607052100_duplicate_prevention                202607052900_lead_owner_assignee_coherence
```

**Ahead: repository and local, jointly, by 16.**

---

## 3. Primary state — live verification

| Dimension | Primary | Local | Assessment |
| --- | --- | --- | --- |
| PostgreSQL | 17.6 | 17.6 | ✅ identical |
| Tables | 72 | 72 | ✅ identical |
| `app` functions | 82 | 104 | expected: +22 from the 16 migrations |
| RLS policies | 76 | 116 | expected: +40 |
| Permissions | 69 | 71 | expected: +2 (`VIEW_DEPARTMENT_RECORDS`, `ARCHIVE_RECORD`) |
| Catalog types / values | 68 / 583 | 68 / 583 | ✅ identical |
| Feature entitlements | **0** | 66 | expected: seeded by `202607052000` |
| Composite tenant FKs | 190 | 191 | expected: +1 from `202607051800` |
| Tables without RLS | **0** | 0 | ✅ |
| `anon` grants | **0** | 0 | ✅ |
| `authenticated` DELETE grants | **0** | 0 | ✅ archive-oriented policy holds on Primary |
| SECURITY DEFINER without pinned `search_path` | **0** | 0 | ✅ |
| `orvion_integration` — can login | **true** | false | ✅ **the documented, deliberate divergence** |
| `orvion_integration` — `app` USAGE | true | true | ✅ |
| `orvion_integration` — table grants | **0** | 0 | ✅ least-privilege contract intact |

**Every delta is accounted for by a specific undeployed migration.** No unexplained object, no drift.

### Primary holds no production data — **VERIFIED**

`tenants`, `users`, `leads`, `bookings`, `events`: **all 0 rows.**

This materially de-risks deployment: there is no data to migrate, transform or lose. The 16
migrations would apply to an empty database.

### Supabase's own security advisors — independent corroboration

Exactly **two** findings, and **both were already identified independently before running the linter**:

| Finding | Level | Status |
| --- | --- | --- |
| `public.integration_cursors` has RLS with no policy | INFO | **Known and intentional** — locked to SECURITY DEFINER paths (migration `049300`); smoke check 4 excludes it by name with that reasoning |
| `moddatetime` extension installed in `public` | WARN | **Known** — recorded as cosmetic in the previous report |

**No new security findings.** The linter surfaced nothing my own checks had missed.

---

## 4. Integrity / corruption check — both databases clean

Local (read-only): 0 tables without RLS · 1 policy-less table (`integration_cursors`, the documented
exception) · 0 unpinned SECURITY DEFINER · 0 `anon` grants · 0 DELETE grants · 277 FKs / 191
tenant-qualified composite · **no duplicate indexes** · **0 orphaned or malformed ledger rows** · ledger
matches migration files exactly in both directions · no empty catalog families · 10 transition triggers
/ 104 registered transitions · 13 archive triggers · 26 `scope_isolation` policies.

**No evidence of data loss, failed migration, schema drift or corruption in either environment.**

---

## 5. Open findings from this gate

### 5.1 140 FK entity columns have no index — **VERIFIED, severity qualified**

Excluding `tenant_id`, **140 foreign-key columns have no index leading on them.** Most are low-value
(`created_by`, `archived_by`, `voided_by`, `currency_code`). **But a load-bearing subset is exactly what
every `scope_isolation` policy filters on**: `leads.owner_*`, `leads.assigned_user_id`,
`bookings.branch_id`, `bookings.department_id`, `booking_items.owner_*`, `tasks.owner_*`,
`conversations.owner_*`, `quotations.owner_*`, `complaints.owner_*`, `service_requests.owner_*`,
`events.actor_user_id`.

**INFERRED:** consistent with the Seq Scans measured last session (lead list 25 ms at 20k rows).

**NOT established:** whether indexing would change the plan. The predicate is an OR-chain over InitPlan
subqueries, which frequently forces a sequential scan regardless. **I would measure before adding 140
indexes** — unhelpful indexes cost write throughput permanently.

### 5.2 The manifest is stale — **VERIFIED**

| Manifest says | Reality |
| --- | --- |
| latest `202607052300` | `202607052900` |
| Primary "is 15 BEHIND" | **16** |

My omission across the last three commits. **Not corrected in this gate** (read-only).

### 5.3 The consistency guard cannot catch 5.2 — **VERIFIED governance gap**

`check_repository_consistency.ps1` reports **CLEAN** while the manifest carries a wrong migration count
and a wrong Primary gap. The guard checks broken references, register contradictions, boot-router
integrity, report classes, manifest leanness, roadmap↔manifest phase agreement, ai-map freshness and
Supabase topology — **nothing compares the manifest's stated migration count to the actual one**, which
is mechanically checkable and has bitten this project before.

---

## 6. Governance / workflow health

Boot chain intact (every `README.md` → `AGENTS.md §4` target exists) · consistency guard CLEAN ·
repository identity coherent (`PlatPlusHub/CRM` named 21× as the deployment repo; `Shehabhub/ORVION`
16× as the *separate* Secondary — expected, not drift) · no obsolete MCP references; the four
configured servers are the four the workflow names · no project skills directory required.

---

## 7. Is the environment safe to continue?

**Yes — for the first time in three sessions, all six components are connected and verified.**

- Repository, local and Primary are mutually consistent, with the gap proven to be a clean
  fast-forward rather than a divergence.
- Primary holds no production data, so deployment carries no data risk.
- Both databases pass every structural integrity check, and Supabase's own linter finds nothing new.

---

## 8. Recommended next step

**Deploy the 16 migrations to Primary, then verify behaviourally.** Specifically:

1. Apply the 16 in ledger order (clean fast-forward — proven, §2).
2. Re-read Primary's fingerprint and confirm it equals local's `5d3d4cbe27ec1ad5b75e9b4f91432eaa`.
3. Re-run the smoke script and the advisors against Primary.
4. Then, and only then, claim `repo = local = Primary`.

Why now: Primary is empty, the gap is a proven fast-forward, and every migration has passed 296
assertions locally. The risk of deploying is currently as low as it will ever be, and it removes the
one blocker that has gated the Foundation Freeze across three sessions.

Two small repairs to fold in: correct the manifest (5.2) and add a migration-count assertion to the
consistency guard (5.3).

---

**Gate complete. All connections verified. Stopped for review — no deployment performed.**
