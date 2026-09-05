# ORVION — Engineering Awareness Layer: the impact/consumer query, and the tooling that earns its place

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-05
Author: Claude Opus 5
Status: **COMPLETE — one new capability (`scripts/impact.ps1`), one new session hook, three permission guardrails. No migration, no schema change, no RPC, no canon change. PRIMARY PARITY = UNPROVEN and not claimed: nothing database-changing shipped, and Primary was not contacted this session.**

---

## 1. DISCOVERED

**The §5b gap was real and unfilled.** `AGENTS.md §5b` question 2 — *"which code CONSUMES, PARSES or DERIVES FROM the structure this package changed?"* — was owner-directed on 2026-08-29 out of CUST-1, and until this session nothing in the repository helped answer it. The answer was produced by ad-hoc grep, so its recall varied with the engineer's diligence. That is the exact shape of the defect that minted the rule: TENANT-1 was structurally correct and silently broke `app.merge_customer_identity` for eight days.

**PostgreSQL's own dependency metadata cannot close it.** `pg_depend` is the obvious tool and it is the wrong one. Function bodies are stored as text and are not parsed at creation, so `pg_depend` records **no** edge from a function to the tables it touches. For a repository whose application layer is 179 `app`-schema functions, `pg_depend` is blind to nearly every consumer that matters. Same for codes carried in trigger arguments — MEAS-1's recorded blind spot. Verified locally: `pg_depend` holds **2** rows for `moddatetime`, while **51** triggers pass a column name to it as an argument.

**Three enforcement gaps in the agent environment, none of them in ORVION.**
1. Two Supabase MCP connectors are reachable in a session — the project-pinned `supabase-primary` and an account-level one that is project-ambiguous. `§4` step 11 forbids letting a schema-changing call reach the wrong project; nothing enforced it.
2. `§6`'s protected-resource rule (`AGENTS.md`, `GOVERNANCE.md`, `README.md`, `CR_LIFECYCLE.md`, `_ORVION_CANONICAL/**`) was honour-system.
3. `§4` step 8 says plainly that nothing compares local `main` against `origin/main` and that it is the engineer's job. RECOVER-1 was the bill for that.

**The local database was 6 migrations behind at session start** (188 applied vs 194 files) — a live instance of the PAR-1b class, found by the new capability's own staleness check before anything was read from it.

---

## 2. VERIFIED (commands run, outputs observed)

| # | Check | Result |
|---|---|---|
| 1 | `npx supabase db reset` | exit 0; ledger **194 applied = 194 files** |
| 2 | Known-example replay — `impact.ps1 -Target customers` | returns `app.merge_customer_identity` among 23 function consumers, plus 11 triggers, 2 policies, the FK fan-in. **This is the CUST-1 relationship, produced mechanically.** |
| 3 | Must-flag counterexample — `-Target updated_at` | **51 triggers** found via `pg_get_triggerdef`, which carries the ARGUMENTS (MEAS-1). `pg_depend` sees 2 rows for the same fact. |
| 4 | Must-not-flag counterexample — word boundary | `select 'tenant_id x' ~* '\mtenant\M'` → **false**. `tenant` does not match `tenant_id` or `tenants`. Residual hits are genuine standalone occurrences inside exception messages (sampled and confirmed) — labelled a *lead*, not a fact, and the output now says so when a target resolves to no catalog object. |
| 5 | Staleness detection — injected one unapplied migration file | banner printed (`194 applied vs 195`); **every** evidence label downgraded to `LOCAL RUNTIME (STALE — NOT the repository)`; probe file removed, count back to 194 |
| 6 | Fail-closed mode — `-RequireFresh` under that stale state | **exit 2** |
| 7 | `-RequireFresh` on the fresh database | proceeds, zero STALE lines |
| 8 | Degraded mode — `-NoDatabase` | `database: NOT READ`, repository sections still answered, exit 0 |
| 9 | Injection boundary — `-Target "drop; select"` | refused, **exit 2**, nothing reached psql |
| 10 | Smoke — `scripts/verify_database.sql` | `ALL CHECKS PASSED (77 tables, …)` |
| 11 | `scripts/check_repository_consistency.ps1` | **REPOSITORY CONSISTENCY: CLEAN**, Checks 1–19, after every change including the AGENTS.md edit and the ai-map regeneration |
| 12 | Deny rules actually bite | the 11 account-level Supabase mutation tools disappeared from the tool surface on reload — verified by effect, not by reading the config |

Two defects in this session's own work were caught by running it rather than by reading it: `text || "char"` ambiguity on `polcmd`/`contype` (two sections silently returned an error instead of rows), and psql's multi-line error shape leaking continuation lines into result buckets. Both fixed and re-run.

---

## 3. FIXED / BUILT

- **`scripts/impact.ps1`** — the §5b question 2 capability. A **query, not a guard**: no CLEAN verdict, no gate, no CI wiring. Reads the live catalog (`pg_proc.prosrc`/`prosqlbody`, `pg_policy` via `pg_get_expr`, `pg_get_triggerdef` **including arguments**, `pg_get_viewdef`, `pg_get_constraintdef`, FKs, indexes, grants) and the repository (migrations, pgTAP suites, scripts, canon, Master registers, ADRs, open CRs). Every section carries its evidence class; the header states what it cannot know.
- **`scripts/generate-ai-map.ps1`** — one line, so `ai-map.json` advertises the capability at cold start. `ai-map.json` regenerated from it.
- **`AGENTS.md §5`** — one bullet registering the command. It restates none of §5a or §5b; it points.
- **`.claude/hooks/session-state.ps1` + a `SessionStart` hook** — prints `branch | ahead N / behind N vs upstream | working tree clean|DIRTY` and says `FETCH FIRST` when behind. Closes the §4-step-8 hole mechanically. Never fails a session (exits 0 on any error). Parsing proven in both directions (0/0 and a synthetic behind=3).
- **`.claude/settings.json` permissions** — `deny` on the 11 mutating tools of the account-level Supabase connector (wrong-project protection); `ask` on the five protected-resource paths; a small generalized allowlist for the read-only guards, the verify suites and read-only git/gh.

---

## 4. NOT FIXED (deliberate, with reasons)

- **Dynamic SQL assembled at runtime is invisible to `impact.ps1`.** Name matching cannot see it. This is stated in the script header and in its output rather than papered over: §5b still requires a **behavioural** test for a consumer whose meaning can change without its source changing.
- **`impact.ps1` is not wired into CI and should not be.** It has no verdict to fail on. Making a lead-generator into a gate is exactly the overclaiming class `§6` (MEAS-1/PAR-3) exists to prevent.
- **No repository index, no embeddings, no vector store was built** — see §6 below. The rejected design is recorded so it is not re-proposed.
- **The permission allowlist in `.claude/settings.json` still holds ~100 one-shot entries** from earlier sessions, now largely redundant. Pruning another engineer's allowlist was out of scope and is not mine to decide.

---

## 5. BLOCKED

Nothing is blocked. One item needs an owner decision only if it is wanted: **`.claude/settings.json` is gitignored as machine-local**, so the `SessionStart` hook is wired per machine even though `.claude/hooks/session-state.ps1` is committed. A re-clone gets the script and not the wiring — the same shape as the 2026-08-30 re-clone that discarded `.git/config` and was fixed by moving the fix into a tracked file (`bootstrap.ps1`). Making the hook survive a clone means either tracking a shared `.claude/settings.json` or teaching `bootstrap.ps1` to write the hook block. Both change how machine-local configuration is governed, so neither was done unilaterally.

---

## 6. GOVERNANCE

**Earn-It applied to tooling, and most candidates lost.** The ecosystem's answer to this problem in 2026 is AST/tree-sitter indexing plus embeddings behind an MCP server (Code Context Engine, Codebase-Memory, Cognee, Claude Context). All were rejected for ORVION on one decisive argument: **a freshly reset PostgreSQL catalog is a better index of ORVION than any AST index of its migrations could be.** It is already parsed, already resolved to the final state after 194 sequential migrations, already normalized, and free. An index built over the migration *files* indexes history — it would return dropped columns and superseded function bodies as live facts. Vector search also returns *similarity*, where this repository's evidence model demands exact, attributable, deterministic evidence. Also rejected: GitHub Spec Kit and the spec-driven-development family (ORVION already has a stronger spec lifecycle in `CR_LIFECYCLE.md` + `changes/` + canon; a second one is duplicated authority), the official Supabase agent skill (generic guidance that would sit beside `CODING_STANDARDS.md` and the hard-won BOOK-1/PAR-4 rules and be wrong for ORVION where they differ), external knowledge graphs and agent-memory servers (competing project truth — `GOVERNANCE.md §2/§6` makes the repository the memory), a GitHub MCP (`gh` is installed and authenticated), and browser automation (correct capability, wrong phase — there is no UI yet).

**The awareness layer deliberately holds no derived state.** No index, no cache, no generated map beyond the existing `ai-map.json`. Nothing to invalidate is stronger than anything to refresh: staleness is computed at call time from the ledger versus the migration files, and the one refresh instruction printed (`npx supabase db reset`) is deterministic and never executed automatically. Self-healing here means *detect, explain, stop* — per the standing rule that a measurement must not claim more than it measures.

**One Authority held.** The new script restates no protocol; it points at `§5a` and `§5b`. `AGENTS.md` gained one bullet. No new governance document was created.

---

## 7. ENVIRONMENT

Windows 11, pwsh 7, Docker Desktop up, `supabase_db_ORVION` healthy. MCP: `supabase-primary`, `postgres-local`, `context7`, `n8n` connected; `serena` present but disabled for this project on purpose (no LSP-backed language here). `gh` 2.96 authenticated as **PlatPlusHub** (a second account, `Shehabhub`, is also logged in — check the active account before any push). `jq` absent; `python` present.

---

## 8. CURRENT STATE

- Migrations **194**, local ledger **194 applied**, fresh from a reset this session.
- Smoke **ALL CHECKS PASSED (77 tables)**. Repository consistency **CLEAN, Checks 1–19**.
- pgTAP suites and the six HTTP suites **not run this session** — UNPROVEN, and not claimed. Nothing database-changing shipped, so `§5a`'s package protocol was not triggered.
- **PRIMARY: UNPROVEN.** Primary was not contacted. Check 19's recorded evidence still matches the repository at 194 migrations, fingerprint `6802ac41eaf6f4f17f0bf4cde7b3a720`.
- Manifest live state unchanged: Phase 8, Active Change Request `None.`
- Git: branch `main`, `0 0` against `origin/main` at session start.

---

## 9. NEXT STEP

Exactly one: **use `impact.ps1` as the first move of the next capability** — the governance backlog the manifest names, starting with **GOV-20** — and let its output drive the §5b cross-path sweep instead of ad-hoc grep. The capability is built and proven; what it has not yet earned is a track record inside a real package.
