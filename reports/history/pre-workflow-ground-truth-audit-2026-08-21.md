# Pre-Workflow Ground Truth Audit — 2026-08-21

Class: **HISTORICAL-IMMUTABLE** (dated review record; do not edit after this session — supersede with a newer dated report).
Type: **Non-canonical working record.** Owner-directed read-only integrity, synchronization and logical-consistency audit performed *before* the first n8n Workflow implementation. Not an ADR, not canon, not a Change Request.
Method: ground truth only — the mandatory boot sequence re-run from scratch, then live introspection of Supabase Primary (`vrvtsxexkiiiivlkdxzp`), the local CLI stack, GitHub, and the live n8n instance. Repository claims were re-verified against the running systems, never trusted.
Scope discipline: **strictly read-only.** No file created, modified or deleted; no migration written; no database object created or altered; nothing committed, pushed or merged; no workstation sync; nothing created or executed in n8n. All live SQL was `SELECT` or a read-only `DO` block containing only reads and assertions.

**State captured: repository HEAD `0cdcfd2`, Primary at 90 migrations.**

> **Read this with its sequel.** Every finding below was acted on the same day. Dispositions — what was fixed, what was deliberately left open, and what became an owner decision — are recorded in `remediation-and-hardening-pass-2026-08-21.md`. This report is the point-in-time evidence; that one is the current state. Do not read this file as a description of the system today.

---

## A. Executive status

**`CLEAN WITH DOCUMENTATION DRIFT`**

Every *executable* axis reconciled exactly. The repository, GitHub, the local stack and live Primary agreed on all 90 migrations by version **and** name; the live schema matched the frozen baseline object-for-object; all ten smoke-test invariants and both vocabulary guards passed when executed directly against Primary; and the deployed Phase-8 function was byte-identical to its certified fingerprint. No Supabase-only object, no repository-only object, and no divergent object was found.

The verdict was not `CLEAN` because three documentation-side defects were real and verified: a deferred reference-data seed whose tracking row had been closed while the work remained undone, a manifest violating its own leanness rule through a gap in the guard enforcing it, and a workstation manifest carrying stale values. None affected correctness, integrity or security, and none blocked the Phase-8 workflow build.

---

## B. Database integrity — what was checked

Live introspection of Primary across `public`, `app` and `reporting`. Counts are observed, not derived from migration arithmetic.

| Object | Count |
|---|---|
| Tables (public) | 72 |
| Columns | 869 |
| Foreign keys | 274 |
| Constraints (total) | 372 — 72 PK · 274 FK · 15 unique · 11 check |
| Indexes | 230 |
| Functions / RPCs | 64 (63 `app` + `public.moddatetime`) |
| Triggers | 38 — 36 `moddatetime` · 2 append-only |
| RLS policies | 76 |
| Catalog types / values | 67 / 569 |
| Reporting views | 7 |
| Migrations applied | 90 |
| Native enum types | 0 — by ratified design (ADR-0006) |

### Invariants executed live against Primary

Rather than trusting a local pass, the repository's own assertions were re-executed read-only against the production project.

| Invariant | Source | Result on Primary |
|---|---|---|
| 10 smoke-test checks (extensions, table count, RLS, policies, resolver, catalog seed, FK standard, `updated_at` triggers, append-only, grant/schema-usage completeness) | `scripts/verify_database.sql` | **All pass** |
| Every `event_type` literal an `app.*` function can emit is a registered catalog value | `tests/07_event_vocabulary_registry_test.sql` | **0 violations** |
| Every from/to status literal in a transition RPC is registered in its governing family; no transition RPC evades the map | `tests/08_status_vocabulary_registry_test.sql` | **0 violations** |
| Every schema-qualified object reference in all 63 `app` functions resolves | this audit | **0 dangling** |
| Every `app` function pins `search_path=''` | SPEC-115 invariant | **63 / 63** |

The dangling-reference check was exact rather than heuristic: because every function pins an empty `search_path`, all object references must be schema-qualified, so they can be extracted and resolved mechanically. The single candidate returned — `app.active_tenant_id` inside `app.current_tenant_id` — was manually confirmed to be a GUC name inside `current_setting()`, not an object reference.

---

## C. Local repository ↔ GitHub

**Fully synchronized.** Verified with `git ls-remote` (a pure read against the remote) rather than a fetch, so no ref was modified.

| Axis | State | Verdict |
|---|---|---|
| Branch / remote | `main` → `origin` (`PlatPlusHub/CRM`) | Correct |
| Local HEAD | `0cdcfd25b36f14de95093ca46e6d8b04bb20f44a` | Match |
| Remote `refs/heads/main` | `0cdcfd25b36f14de95093ca46e6d8b04bb20f44a` | Match |
| Remote ahead / local ahead | none / none | None |
| Uncommitted changes (`--untracked-files=all`) | none | Clean |
| Stashes | none | Clean |
| Ignored-but-present | `.claude/` · `supabase/.temp/` | Expected |

Both ignored paths are intentional and documented: `.claude/` is machine-local by `.gitignore` policy — which is why the MCP approval list (`enabledMcpjsonServers`) lives outside version control and a fresh clone must re-approve — and `supabase/.temp/` holds only a CLI version marker.

---

## D. Repository / GitHub ↔ live Supabase

**No drift, expected or unexpected.** Ledgers were compared element-by-element, not by count alone.

| Comparison | Repository | Live Primary | Local stack | Verdict |
|---|---|---|---|---|
| Migrations | 90 | 90 | 90 | Identical |
| Latest version | `202607050100` | `202607050100` | `202607050100` | Identical |
| Ledger versions + names | all 90 pairs match exactly | | | Identical |
| Public tables | 72 `CREATE TABLE` | 72 | 72 | Identical |
| Table names | set-difference empty in both directions | | | Identical |
| Catalog seed | 67 / 569 asserted | 67 / 569 | 67 / 569 | Identical |
| `app.claim_conversion_deliveries` md5 | `746695b6fc018c2d13c0d6903ba0ee1c` | same | — | Matches certification |

**Supabase-only objects:** none. **Repository-only objects:** none. **Divergent objects:** none.

The function fingerprint is independently significant — it reproduces exactly the md5 recorded in `MASTER_CERTIFICATION_STATUS.md`, proving the deployed SPEC-123 function is byte-identical to what was certified, not merely present by name.

**Topology respected throughout.** Per the permanent-separation ratification, only Primary was inspected. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and was deliberately *not* queried, compared or reconciled — its documented 89-migration state is valid and expected, and comparing it would itself have been a governance violation.

**Advisor state (live).** Security: 2 notices — `integration_cursors` RLS-enabled-with-no-policy (intentional; explicitly excluded in the smoke test as locked to `SECURITY DEFINER` paths) and `moddatetime` installed in `public` (see §E). Performance: 198 notices, **all INFO** — 140 unindexed foreign keys and 58 unused indexes, the expected signature of a correct, fully-seeded, zero-row pre-production database.

---

## E. Schema & relationship findings

### P1 — `catalog_values.catalog_type_code` has no referential backing to its own registry — POSSIBLE ISSUE

`catalog_types` is the only business-meaningful table in the schema with **no foreign key in either direction**. Nothing prevents inserting a `catalog_values` row naming a catalog family that does not exist.

ADR-0006's rationale does not cover this link. That decision rests on the fact that a single code column cannot reference `catalog_values`' composite key — but this is a plain single-column reference to `catalog_types.code`, which **is** uniquely constrained, so a foreign key is mechanically possible. The absence is recorded as deliberate in `SPEC-024` Finding F1 and as a Low-severity item in an immutable historical report, yet appears nowhere in `MASTER_GAP_REGISTER.md` — the findings SSOT — so it had never reached one of the three terminal states `GOVERNANCE.md §19` requires.

```
-- live: catalog_values constraints = PK, UNIQUE(catalog_type_code, code), FK tenant_id, FK created_by
-- live: orphan_catalog_values_today = 0 · distinct_type_codes_in_values = 67 · registered_types = 67
-- grep: "catalog_type_code" in MASTER_GAP_REGISTER.md -> 0 matches
```

**Current impact: zero.** All 569 values resolve to a registered type. A latent integrity gap and a governance-tracking gap, not a live defect.

### P2 — `moddatetime` extension installed in `public` — POSSIBLE ISSUE

Supabase's security advisor raises this as WARN. It appeared in no repository document — not in `CODING_STANDARDS.md`, not in canon, not in any report — so no decision record existed either accepting or rejecting the placement.

### Relationship checks that passed

| Check | Finding | Verdict |
|---|---|---|
| Referential Action Standard (ADR-0007) across all 274 FKs | Zero deviations beyond the four documented exceptions (`users.auth_user_id` SET NULL; three auth-support CASCADEs to `auth.users`) | Pass |
| Tenancy model — tables without `tenant_id` | 15, every one legitimately platform-scoped: the catalog registry, 4 reference tables, RBAC, platform subscription tables, `tenants` itself, `integration_cursors`, and the 3 auth-support tables re-homed to the human identity per ADR-0012 | Consistent |
| Orphan tables (no FK in or out) | Only `catalog_types` (→ P1) and `integration_cursors` (by design) | Explained |
| RLS coverage | 72/72 have RLS enabled; 71 carry policies; the one exception is the documented `integration_cursors` | Pass |
| `anon` reachability of `app` RPCs | Most `app` functions carry Postgres' default PUBLIC EXECUTE, but `anon` has **no USAGE on `app` or `reporting`**, so none is reachable anonymously | Safe |
| Ownership of the 4 outbox RPCs | All `SECURITY DEFINER`, granted to `orvion_integration` only | Correct |

---

## F. Catalog, dropdown & reference-data findings

All 67 catalog families and 569 values were cross-checked in both directions against live function source. **The high-severity direction is clean:** no application, RPC or SQL logic references a catalog value, status literal or event code that does not exist.

### I1 — Reference-data seeds are undone, but their tracking row is closed — INCONSISTENCY

Three reference tables are structurally complete and FK-referenced but **hold zero rows**. Four nullable columns therefore point at empty parents: any call supplying a real country, nationality or language code fails on foreign key, and the columns can only be left null.

| Reference table | Rows | Referencing column(s) | Nullable |
|---|---|---|---|
| `currencies` | 18 | 14 `*currency_code` columns | mixed |
| `countries` | 0 | `bookings.destination_country_code`, `passengers.passport_issuing_country_code` | yes |
| `nationalities` | 0 | `passengers.nationality_code` | yes |
| `languages` | 0 | `customers.preferred_language_code` | yes |

The deferral itself was deliberate and recorded in the change history. What was missing is its *continuation*: the Future Backlog row that would carry it is struck through as **DONE / Closed**, because it was scoped to the structural half (tables + FKs) and closed on that basis — while the seed half remained open in two separate SPECs and was never re-homed to an open row or given a trigger.

```
-- live: countries=0 · nationalities=0 · languages=0 · currencies=18
reports/future-backlog.md:21   ~~Reference Data Layer — core (...)~~ — DONE ... | Closed |
changes/SPEC-037-...:255       "Seed data (ISO 3166 countries, ISO 639 languages, ...) is a later seed migration"
changes/SPEC-074-...:55        "countries / nationalities / languages seeds (still deferred)"
changes/SPEC-076-...:42        "nationalities/countries reference-data seeds (still deferred, nullable)"
```

**Classification: Appears Forgotten.** Not a Phase-8 blocker — the offline-conversion path touches only `currencies`, which is seeded — but a real go-live gap for passenger and booking capture, with no owner, trigger or register ID.

### Canon 25 ↔ as-built catalog families

Eight families documented in `25_catalog_registry.md` have no live `catalog_type`. Seven are correct; one is a near-duplicate that was never marked.

| Canon family | Live realization | Classification |
|---|---|---|
| `role_code` | Dedicated `roles` table (9 rows) | Implemented elsewhere |
| `subscription_plan_code` | Dedicated `subscription_plans` table (3 rows) | Implemented elsewhere |
| `preferred_language_code` | `languages` reference table — **0 rows** | Partially implemented (I1) |
| `cabin_class_code` | None — canon says "Future ticket details" | Intentionally deferred |
| `fare_type_code` | None — canon says "Future ticket details" | Intentionally deferred |
| `expense_category_code` | None — canon says "Future expense recording" | Intentionally deferred |
| `finance_approval_type` | Superseded by `approval_type_code`; canon explicitly marks it deprecated | Obsolete, correctly marked |
| `functional_role_code` | **No realization and no deprecation note.** Its six values are an exact subset of the live `department_type` family | **P3 · Unmarked near-duplicate** |

The reverse direction is clean: the only two live families absent from canon 25 are `event_type` and `event_severity_code`, which canon 27 owns by design. No duplicate, misspelled or renamed catalog value was found in either direction.

### P4 — 101 of 169 registered event codes have no emitter

Expected in the main: vocabulary is deliberately seeded ahead of its consumers under the Fundamental-Domain-Structure rule, and several absences are explicitly by-design (`lead_created`, the permission-mutation events). The two that matter were already registered as **PH8-6**: `offline_conversion_send_attempted` and `offline_conversion_retried` are canon-required for Phase 8 and emitted by nothing. This audit independently confirmed that finding against live function source.

---

## G. Forgotten, deferred & abandoned work

The full keyword sweep (`TODO`, `FIXME`, `TBD`, `deferred`, `pending`, `workaround`, `obsolete`, `not implemented`, and the rest) returned **no unfinished-work marker anywhere in executable code**. Every match in `supabase/` and `scripts/` was a legitimate catalog value (`temporary` as a branch-transfer type), a `create temporary table` in a pgTAP test, or a deliberate design comment pointing at a tracked backlog row.

| Item | Evidence | Classification |
|---|---|---|
| Reference-data seeds (countries / nationalities / languages) | Live 0 rows; backlog row closed; two SPECs say "still deferred" | **Appears forgotten** |
| `catalog_values.catalog_type_code` FK | SPEC-024 F1 deliberate; historical report Low #5; absent from findings SSOT | Still open — untracked |
| `functional_role_code` canon family | No realization, no deprecation note, subset of `department_type` | Unknown — needs decision |
| `feature_entitlements` per-plan seed | 0 rows; backlog row open with four enumerated unresolved sub-questions | Intentionally deferred |
| PH8-2 · consent-denied operational surface | Register row OPEN, owner decision stated | Intentionally deferred |
| PH8-3 · E.164 phone normalization | Register row OPEN, owner decision stated | Intentionally deferred |
| PH8-4 · `qualified_phone_call` has no producer | **Confirmed live**: the mapper emits only 4 of the 5 conversion types | Still open — informational |
| PH8-5 · no `transactionId` sent to Google | Register row OPEN; mandatory build-time correction | Still open — resolves at build |
| PH8-6 · two canon-required events never emitted | **Confirmed live** by this audit | Still open |
| Booking-item roll-up never consumed; finance-gated transitions partial | Backlog rows with per-consumer triggers; matching design comments in migrations `045400` / `045700` | Intentionally deferred |
| Status-column naming normalization | Backlog row, trigger = "Backend/API phase start" | Intentionally deferred |
| DML `GRANT`s to `authenticated` | Backlog row; **claimed** still fully locked | Intentionally deferred *(this claim was later proven false — see §H and the remediation record)* |
| `SPEC-001`, `SPEC-006` referenced but no file exists | SPEC-001 explained in SPEC-002 as a never-committed fragment; SPEC-006 appears only inside one immutable historical report | Not a defect |

`MASTER_GAP_REGISTER.md` held 78 rows at audit time, 26 carrying an OPEN status. Every one carried an evidence trail and either a trigger or a named owner decision — with the two exceptions above (I1 and P1), which had no register row at all.

---

## H. Documentation drift

### I2 — The manifest breaks its own rule, and the guard that enforces it measures the wrong thing — INCONSISTENCY

`manifest.md` states plainly that it "holds ONLY current state", that history belongs in git and `reports/`, and that "if any field starts becoming a changelog, trim it." Its *Current Module* field was a single line of **5,609 characters** narrating three separate sessions of corrections dated 08-15, 08-17 and 08-20 — precisely the changelog the rule forbids.

The consistency guard's Check 5 exists to prevent exactly this, and it passed — because it budgeted **lines** (60 against a budget of 70) while the actual cold-boot cost it was written to bound is characters (13,556). Long single-line paragraphs passed through the proxy untouched.

```
manifest.md                       lines = 60 (budget 70, PASS) · chars = 13,556
longest line                      line 28 = 5,609 chars · line 34 = 1,684 chars
check_repository_consistency.ps1  $manifestBudget = 70  — compared against @(Get-Content).Count
```

A permanent guard that can be satisfied without satisfying its invariant is the failure class the discovery-to-guard loop exists to eliminate.

### Documentation that verified as accurate

| Claim | Source | Independent verification |
|---|---|---|
| Primary at 90 migrations, latest `202607050100` | manifest · certification · catalog §0 | Confirmed live |
| SPEC-123 lease deployed and behaviourally real (30-min lease, `LEASE_EXPIRED` sweep, `pending`/`sent` exclusion, consent gate) | catalog §2 · PH8-1 | Confirmed in live source |
| Certified function fingerprint | `MASTER_CERTIFICATION_STATUS.md` | md5 reproduced exactly |
| §2a correction 2 — only `payment_recorded` carries value/currency, so 3 of 4 mapper outputs are null | catalog §2a | Confirmed in mapper source |
| §2a correction 1 — `claim` permanently excludes `pending` *and* `sent` | catalog §2a | Confirmed in claim source |
| n8n: 0 workflows, 0 executions, exactly 2 credentials, 1 personal project | manifest · catalog §4 | Confirmed live, IDs match |
| Boot-chain routers, report class headers, roadmap↔manifest phase agreement, ai-map freshness, topology registry | consistency guard checks 1–8 | CLEAN |
| `repository-index.md` completeness | auto-generated | All 37 canon files present |

One suspected mismatch was investigated and cleared: `§2a` refers to `payment_recorded` while the conversion catalog contains `payment_received`. Reading the live mapper shows these are two different vocabularies — `payment_recorded` is the source *event* code, mapped to the `payment_received` conversion type. The documentation is correct as written.

**Broken references:** none. Every `SPEC-###` and every 12-digit migration version cited anywhere in the repository resolves to a real file, with the two explained exceptions in §G. All `GitHub/ORVION` path mentions are historical explanations of an already-fixed root cause, not live pointers. `PROTOCOL.md` and `global-rules.md` remain as intentional tombstones per the governance registry.

---

## I. Workstation delta — recorded, not applied

**Nothing was synchronized.** `.workstation/manifest.md` was read only.

| Category | Item | Recorded | Actual |
|---|---|---|---|
| **Stale** | Header currency | `Last curated: 2026-07-11` | §4 contains 2026-08-20 entries |
| Stale | Git | `2.54.0` | `2.55.0.windows.4` |
| Stale | Node.js | `v24.18` | `v24.19.0` |
| Stale | Docker Desktop | `29.6.1` | `29.6.2` |
| Stale | Supabase CLI | `2.109` | `v2.115.0` marker |
| Stale | §4 GitHub-auth evidence | `ls-remote → c5590c4` | `0cdcfd2` |
| **Correct** | MCP servers registered | 4 (context7, postgres-local, supabase-primary, n8n) | Exactly 4 in `.mcp.json` |
| Correct | MCP approval mechanism | `enabledMcpjsonServers` in `.claude/settings.local.json` | Present, lists all 4 |
| Correct | Python | `3.12.10` | `3.12.10` |
| Correct | n8n MCP works by effect, not health check | Verified 2026-08-20 | Re-proven with 3 live read calls |
| **Ambiguous** | VS Code `1.129` | Recorded | Not verifiable from this shell |
| Ambiguous | Supabase CLI installed version | `2.109` | `.temp/cli-latest` is a latest-available marker, not proof of the installed binary |
| **Missing** | PowerShell version | Not listed | `7.6.5` |

The local Supabase stack was **running and correct** (90 migrations, 72 tables, 569 catalog values — a three-way match with the repository and Primary), though the `supabase_vector_ORVION` container was in a restart loop. That container is unused by ORVION's workflow and did not affect any check.

---

## J. Logical-system findings

### Confirmed — evidence-backed

- **Reference columns with empty parents (I1).** The only confirmed inconsistency between a modelled relationship and its usable state.
- **PH8-4, verified independently.** `qualified_phone_call` is a registered conversion type with no producer — the live mapper emits only `qualified_lead`, `booking_created`, `payment_received` and `ticket_issued`. Its Google Conversion Action can never fire through the pipeline.
- **PH8-6, verified independently.** Two canon-required Phase-8 event codes are registered but emitted by nothing.

### Suspected, then cleared by verification

Each looked like a defect and was disproved by reading the live implementation rather than documentation about it.

- **Every state machine is reachable.** Across all five transition RPCs, exactly one catalog status has no transition — `lead_status = 'converted'` — and that is by design: it is written by the dedicated `app.convert_lead` RPC, confirmed in its live source.
- **`app.seed_default_chart_of_accounts()` has no caller, and that is correct.** Not invoked by `provision_tenant`. The migration header states the chart is a per-tenant customizable starting default, so the RPC is intentionally opt-in and idempotent. Worth one line in a future onboarding runbook — a tenant must call it before `create_journal_entry` can resolve accounts — but not a defect.
- **`chart_of_accounts`, `feature_entitlements` and all Phase-8 tables at 0 rows** is the correct pre-production state, consistent with `tenants = 0`.
- **The `payment_recorded` / `payment_received` pair** is two correct vocabularies, not a half-applied rename.
- **PUBLIC EXECUTE on `app` RPCs** is not an exposure, because `anon` holds no schema USAGE.

No conflict was found between Phase-8 logic and existing domain rules, and no entity was found whose ownership or financial reference semantics contradict the canonical model.

---

## K. Phase 8 readiness

**Yes — ready to proceed to the first n8n workflow implementation.** No prerequisite missing; nothing in this audit blocked the build.

The ORVION-side pipeline was verified live end-to-end: the four outbox RPCs exist, are `SECURITY DEFINER`, and are granted to `orvion_integration`; that role has login and `app` schema USAGE; the SPEC-123 lease is deployed with its behaviour confirmed in source; the consent gate is present in the claim path; the five conversion event types are seeded; and every table the workflow touches is at zero rows.

Two carried constraints remained, both recorded and neither blocking: the mandatory `§2a` corrections must all be applied at build time — particularly correction 1 (never ack a `validateOnly` run as success) and correction 4 (send `transactionId` = `conversion_id`) — and Google Auth Platform remains in Testing status, expiring n8n's refresh token every 7 days until OAuth verification.

The evidentiary boundary around the two n8n credentials still holds exactly as written, and this audit did not move it. Their *existence* is agent-verified; their targets, the `datamanager` scope, and whether either currently authenticates are not, because the available n8n MCP exposes no credential-detail or credential-test capability. Neither has been observed to authenticate. That uncertainty resolves at first execution, not before.

---

## L. Recommended next step

**Open one documentation-only synchronization Change Request that closes I1, I2 and I3 — no schema change, no migration, no Supabase write — after which the workflow build is unblocked.**

The reasoning is the repair-before-features rule: I1 is a synchronization and canonical-completeness defect — a real deferral that lost its tracking row — and `GOVERNANCE.md §19` makes that class the highest priority. But it is small, purely documentary, and touches nothing the workflow depends on. Doing it first costs one short CR and leaves the repository with no untracked deferral; deferring it risks the seed gap being lost a second time behind a larger Phase-8 CR.

> **Outcome.** This recommendation was executed the same day and grew in scope once remediation began — the privilege review it triggered uncovered a live security defect that this read-only audit could not see. See `remediation-and-hardening-pass-2026-08-21.md`.

---

End of report.
