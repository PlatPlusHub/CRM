# ORVION GOVERNANCE — Knowledge & Decision Operating System

Status: **Authoritative governance operating system for the knowledge/decision/reports layer.** This document governs *how ORVION knows things and decides things* — where truth lives, how a decision travels from idea to canon, how documents evolve, and how drift is prevented. It is the single entry point for any engineer or AI agent asking "where does this belong / who is authoritative / how do I record this?"

**Precedence & scope boundary (no overlap):** `AGENTS.md` is authoritative for **execution conduct** (how work is done, when to continue/stop, standing authorities). This document is authoritative for **knowledge governance** (where information lives and how decisions/documents flow). Where the two touch, AGENTS.md governs conduct and GOVERNANCE.md governs knowledge placement. Neither restates the other. `CR_LIFECYCLE.md` remains authoritative for the Change Request state machine.

Version 1.11 · 2026-08-29 · Governs every future human, Claude, Codex, and AI/MCP session.

**Governance changelog** (governance governs itself — §15):
- v1.11 (2026-08-29) — **AUD-03**: the findings-SSOT row (§2) now states the plan↔register boundary explicitly instead of leaving it to be inferred from "never restate the finding". The register owns a finding's **status and evidence**; `MASTER_EXECUTION_PLAN.md` legitimately narrates what a package fixed and why it was sequenced where it was, because a package narrative cannot be written without describing findings and that history is what makes the programme continuable. The harmful half — a status the register disagrees with — is now **measured** by Check 2's new cross-Master pass (**AUD-04**) rather than left to prose discipline. PATCH/MINOR: clarifies an existing row's boundary and moves an assertion into a measurement; no SSOT reassignment.
- v1.10 (2026-08-29) — added the **API capability contract** SSOT row (§2) + registry entry (§5): `reports/master/MASTER_API_CONTRACT.md` is the single home for the client-facing surface (endpoints, tenant-reachable tables, reporting views, permissions, HTTP-evidence coverage). It is the first **auto-generated** Master, so both entries state that it must never be hand-edited and that `check_database_parity.ps1` Check L3 enforces that by regenerating and diffing. Registered during the pre-Phase-10 program reconciliation, which found it had been Living-Authoritative since 2026-08-29 with **no SSOT row at all** — the duplicate-authority risk §2 exists to prevent (**GOV-2**). §5's Master count corrected 14 → 15. MINOR: new SSOT row for a new concept; no reassignment.
- v1.9 (2026-07-17) — added the **Integration Catalog** SSOT row (§2) + registry entry (§5): `reports/master/MASTER_INTEGRATION_CATALOG.md` is the single home for external-integration contracts (registry, workflow specs, owner-setup checklists); ADRs keep owning the decisions, the catalog owns the contract surface. Seeded at its recorded Adopt-Later trigger (Phase 8 landed) under delegated engineering authority. MINOR: new SSOT row for a new concept; no reassignment.
- v1.8 (2026-07-17) — **Documents-serve-ORVION supremacy clause** added to §15 (owner-ratified): every document exists to serve ORVION, never the reverse; a document that blocks an objectively superior architecture becomes itself the subject of review — amend/supersede/split/retire it through its owning lifecycle rather than working around it; preserve history, never preserve architectural mistakes. First application: retired the `codex.md`/`SYSTEM_PROMPT.md` tombstones (git history preserves them). PATCH: sharpens §15's existing self-revision principle; no SSOT reassignment.
- v1.7 (2026-07-17) — added §19 **Repository Stewardship** (owner-ratified): the engineering role is steward of the whole repository as ORVION's permanent memory — implementation-age-is-not-evidence, repair-before-features, every-historical-recommendation-must-resolve, governance-before-execution. Includes the **knowledge-graph Earn-It determination**: adopt the principles (ORVION already embodies ~80% via the SSOT matrix + stable-ID references + decision/capability lineage), **reject** a wikilink/graph-tooling layer as bloat, adopt orphan/lineage completeness as a periodic stewardship scan (not a CI gate). MINOR: new section, no SSOT reassignment; sequences existing §6/§17/§18 rather than restating them.
- v1.6 (2026-07-15) — **Living-Documents-first** default added to §4 (update the authoritative Living doc in place; a dated Historical report is written only when it preserves genuine historical engineering evidence, not because information changed — Earn-It applied to documentation, against report sprawl). Owner-ratified in the 2026-07-15 Repository-Recovery directives. PATCH/MINOR: no SSOT reassignment; refines the §4 "write a new dated report" default and records it as policy. Companion conduct clauses (multi-role usability review; synchronization-in-definition-of-done) added to `AGENTS.md §3/§6` as pointers, not duplicated here.
- v1.5 (2026-07-13) — added the §18 **Retention Earn-It** clause (Earn-It is also a retention test, not only an adoption gate; existing artifacts are re-challenged at review cadences that already exist — no new review event). Owner-ratified. No SSOT reassignment. Confirmed idea "every memory needs a repo SSOT" already fully owned by §2/§6.5/AGENTS §6 — no addition made (would duplicate).
- v1.4 (2026-07-11) — extended §18 with the discovery-to-guard loop (implementation is the review; every fix lands a permanent guard) and an evolution-on-evidence pointer to §15/§11/AGENTS§3.2. Rejected 4 proposed duplicate rules (already owned). Owner-ratified.
- v1.3 (2026-07-11) — added §18 Repository maintenance mode & lifecycle (Maintenance Mode + Implement→Sync→Earn-It→Continue lifecycle + structural Earn-It gate; references AGENTS §3, restates nothing). Owner-ratified. No SSOT reassignment.
- v1.2 (2026-07-11) — added §6.8 one-authority consolidation rule (every governance rule lives here; conduct stays in AGENTS per §5). Owner-ratified. No SSOT reassignment.
- v1.1 (2026-07-11) — added §15 governance-change lifecycle, §16 SaaS portability layer, §17 repository-health pointer. No SSOT reassignment.
- v1.0 (2026-07-11) — initial governance operating system (hierarchy, SSOT matrix, decision/knowledge/document lifecycles, registry, drift rules, AI/human onboarding, migration).

---

## 1. Governance hierarchy (the layered model)

```
POLICY            Owner decisions · standing authorities            → AGENTS.md §2, owner directives
   ↓
GOVERNANCE        How knowledge & decisions work (this file)        → GOVERNANCE.md
   ↓
CONDUCT           How execution is performed                        → AGENTS.md · CR_LIFECYCLE.md · CODING_STANDARDS.md
   ↓
DECISIONS         Ratified architecture decisions                   → reports/architecture-decision-records.md (ADR log)
   ↓
CANON             Business rules, schema intent, principles         → _ORVION_CANONICAL/**
   ↓
STATE             Live phase / module / active CR                   → _ORVION_CANONICAL/manifest.md
   ↓
EXECUTION         The change being made                             → changes/SPEC-*.md  (built truth → supabase/migrations/**)
   ↓
FINDINGS          Accepted architectural gaps & plans               → reports/master/MASTER_*.md
   ↓
EVIDENCE          Proof, validation, citations                      → reports/evidence/{PROOF_LOG,VALIDATED,PENDING,REJECTED,INDUSTRY_REFERENCES}
   ↓
HISTORY           Dated review/session reports (immutable)          → reports/history/*-YYYY-MM* , phase-* , process reports
```
Read top-down to answer "what am I allowed to do?"; read a specific layer to answer "where does this fact live?".

---

## 2. Single Source of Truth (SSOT) matrix — the core rule

**Every fact has exactly one authoritative home. Every other mention must reference it by pointer, never restate it.** If you would type the same fact into a second file, stop — link instead.

| Information category | SSOT (authoritative — edit here) | May reference (must NOT restate) |
|---|---|---|
| Execution conduct / operating model | `AGENTS.md` | PROTOCOL.md, global-rules.md, CLAUDE/GEMINI/.cursor/.github (thin pointers) |
| Change Request state machine | `CR_LIFECYCLE.md` | AGENTS.md (points to it) |
| Boot sequence / reading order | `AGENTS.md §4` (single authority) | `README.md` (one-hop router), `llms.txt` (AI-convention pointer), `ai-map.json` (auto-gen pointer), this file — all reference, none restate the steps |
| Workstation rebuild (tools/extensions/MCPs/plugins) | `.workstation/manifest.md` (what + why) + `.workstation/prepare.ps1` (how) | `WORKSTATION.md` (thin entry, points here) — README does **not** reference the environment (repository/environment separation, 2026-07-17) |
| Coding / SQL / API / security standards | `CODING_STANDARDS.md` | ADRs, canon |
| Business & domain rules | `_ORVION_CANONICAL/00–23` | reports (rationale only) |
| Schema **intent** (planned) | `_ORVION_CANONICAL/24–33` | MASTER_DOMAIN_CATALOG (indexes it) |
| Schema **truth** (as-built) | `supabase/migrations/**` | canon 24–33 describe intent; migrations are ground truth |
| Cross-cutting principles (auth, tenancy) | `_ORVION_CANONICAL/34, 35` | ADRs reference |
| Live state (phase/module/active CR) | `_ORVION_CANONICAL/manifest.md` | never duplicated |
| Roadmap **phases** | `_ORVION_CANONICAL/32` | MASTER_EXECUTION_PLAN references phases, does not restate them |
| **Ratified** architectural decisions | `reports/architecture-decision-records.md` | MASTER_ARCHITECTURE_DECISIONS (tracking overlay only) |
| **Proposed/pending** decisions | `reports/master/MASTER_ARCHITECTURE_DECISIONS.md §B` + evidence/VALIDATED/PENDING | — |
| Accepted architectural findings/gaps — a finding's **STATUS and EVIDENCE** | `reports/master/MASTER_GAP_REGISTER.md` | ALL other Masters reference finding **IDs**; none may state a finding's status. **Boundary (AUD-03, 2026-08-29):** `MASTER_EXECUTION_PLAN.md` legitimately *narrates* what a package fixed and why it was sequenced where it was — a package narrative cannot be written without describing findings, and that history is what makes the programme continuable. What it must never do is assign a **status** the register disagrees with. That is the harmful half of the duplication, and it is now **measured**, not trusted: `check_repository_consistency.ps1` Check 2 compares finding status ACROSS every `reports/master/*.md` |
| Finding evidence trail (9 stages) | `reports/evidence/ARCHITECTURE_PROOF_LOG.md` | — |
| Finding lifecycle stage detail | `reports/evidence/{VALIDATED,PENDING,REJECTED}_ARCHITECTURE_DECISIONS.md` | register row shows the current status |
| External citations | `reports/evidence/INDUSTRY_REFERENCES.md` | every evidence-based finding cites a ref-id |
| Risk | `reports/master/MASTER_RISK_REGISTER.md` | references finding IDs |
| Certification state | `reports/master/MASTER_CERTIFICATION_STATUS.md` | — |
| Execution batches/sequencing | `reports/master/MASTER_EXECUTION_PLAN.md` | references register IDs + roadmap phases |
| Finding dependencies | `reports/master/MASTER_DEPENDENCY_GRAPH.md` | — |
| Design completion scores | `reports/master/MASTER_COVERAGE_SCORE.md` | references register IDs |
| Domain blueprint (catalog/ER/flow) | `reports/master/MASTER_{DOMAIN_CATALOG,ENTITY_RELATIONSHIP_MAP,DATA_FLOW}.md` | reference canon + physical-design |
| External integration contracts (registry + workflow specs) | `reports/master/MASTER_INTEGRATION_CATALOG.md` | ADRs own the *decisions*; the catalog owns the *contract surface* and points to them |
| **Client API capability contract** (endpoints, tenant-reachable tables, reporting views, permissions, HTTP-evidence coverage) | `reports/master/MASTER_API_CONTRACT.md` — **AUTO-GENERATED from the live database; do not hand-edit.** Regenerate via `scripts/generate-api-contract.ps1`; `check_database_parity.ps1` **Check L3** regenerates and diffs it, so a hand edit fails the guard | canon + `MASTER_GAP_REGISTER.md` own the *rules*; this file states the *surface* those rules produce and restates none of them |
| Deferred backlog + triggers | `reports/future-backlog.md` | — |
| Repository file index | `repository-index.md` (auto-generated) | **do not hand-edit** |
| AI cold-start map (machine-readable) | `ai-map.json` (auto-generated from the SSOTs it points to) | **do not hand-edit** — regenerate via `scripts/generate-ai-map.ps1`; restates nothing, only points |
| AI memory | `.claude/**/memory/**` | **cache only** — never the sole home of an operational fact (AGENTS §6) |
| Historical "why" (analysis) | dated reports in `reports/` | **immutable once written** |

**Drift is defined as any fact appearing authoritatively in two places.** §6 makes it impossible.

**Reports physical layout (reorganized 2026-07-11):** `reports/master/` (Living Masters), `reports/evidence/` (validation trail), `reports/history/` (immutable dated/phase/process reports); `README.md`, `architecture-decision-records.md`, `future-backlog.md` stay at `reports/` root. **Convention:** cite any report by its **unique filename** (folder is organizational) — so references survive future moves. Index: `reports/README.md`.

---

## 3. Architectural Decision Lifecycle (permanent standard)

Every architectural decision follows this pipeline **forever** — not just in review sessions. Each stage has one home:

```
IDEA → DISCOVERY → EVIDENCE → COUNTER-PROOF → PENDING → VALIDATED → OWNER APPROVAL → CANON/ADR → IMPLEMENTATION → VERIFICATION → DEPRECATED → ARCHIVED
```
| Stage | Where it is recorded | Gate to advance |
|---|---|---|
| Idea | a dated review report | described only |
| Discovery | dated review report | stated as hypothesis |
| Evidence (S2) | `ARCHITECTURE_PROOF_LOG.md` | repo/schema/migration/ADR/report evidence collected |
| External validation (S3) | `INDUSTRY_REFERENCES.md` | official/industry source cited |
| Counter-proof (S4) | PROOF_LOG; if killed → `REJECTED_ARCHITECTURE_DECISIONS.md` | actively attempted to disprove |
| Pending | `PENDING_ARCHITECTURE_FINDINGS.md` | failed a stage; trigger recorded |
| Validated | `VALIDATED_ARCHITECTURE_DECISIONS.md` + row in `MASTER_GAP_REGISTER.md` | passed all 9 stages; confidence ≥70% |
| Owner approval | `architecture-decision-records.md` (new ADR) | owner ratifies |
| Canon | `_ORVION_CANONICAL/**` updated | ADR integrated |
| Implementation | `changes/SPEC-*.md` | CR_LIFECYCLE |
| Verification | CR Review Gate + `verify`/pgTAP | acceptance criteria met |
| Deprecated | ADR marked `Superseded` (pointer to replacement) | never deleted |
| Archived | remains in `reports/` (immutable) | history preserved |

**Rule:** a finding may not enter `MASTER_GAP_REGISTER.md` until it reaches *Validated*. Anything earlier lives in PENDING. Nothing skips owner approval to reach canon.

---

## 4. Knowledge & Document lifecycle

Three document classes — each with a fixed rule:

| Class | Rule | Examples |
|---|---|---|
| **LIVING-AUTHORITATIVE** | evolve in place; never recreate; one SSOT per fact | all `MASTER_*.md`, the 5 evidence reports, `architecture-decision-records.md`, `future-backlog.md`, canon, manifest |
| **HISTORICAL-IMMUTABLE** | never edit after the session that wrote it; it is a dated record of what was thought then | `*-2026-07*` review reports, `phase-*` reports, process reports |
| **AUTO-GENERATED** | never hand-edit; regenerated by a script | `repository-index.md` |

When a review changes a conclusion, it **updates the LIVING doc**, and **writes a new dated HISTORICAL report only when that report preserves genuine historical engineering evidence** — reasoning, options weighed, or a point-in-time verification worth keeping. It never edits an old historical report. This is how "nothing is lost" and "nothing drifts" hold simultaneously.

**Living-Documents-first (default, owner-ratified 2026-07-15).** Almost every engineering document should be a Living document that evolves in place. Do **not** create a new report merely because information changed — update the authoritative Living document instead. A dated Historical report is justified only by genuine historical value (a decision/verification record future readers must be able to reconstruct); a verification pass that produces no new architectural conclusion appends its evidence to the existing authoritative record or is captured in the Living docs it corrects — it does **not** spawn a parallel report. This is Earn-It applied to documentation: prefer fewer, higher-quality, current documents; avoid report sprawl, duplicated authority, and historical clutter. (Precedent: the 2026-07-15 recovery reconciled the Master suite in place and declined to write a duplicate audit report.)

---

## 5. Governance document registry

| Document | Purpose | Class | Authoritative for | Updated by |
|---|---|---|---|---|
| `GOVERNANCE.md` (this) | knowledge/decision OS | Living | §2 SSOT, lifecycles | governance review |
| `AGENTS.md` | execution operating model | Living (protected) | conduct, boot, authorities | owner-authorized only |
| `README.md` | one-hop entry router | Living (protected) | routing to authorities (the boot sequence itself lives in `AGENTS.md §4`) | owner-authorized only |
| `PROTOCOL.md` | **RETIRED** → tombstone pointer (session 10) | Historical | nothing — content owned by AGENTS/GOVERNANCE | frozen |
| `global-rules.md` | **RETIRED** → tombstone pointer (session 10) | Historical | nothing — content owned by AGENTS §6 | frozen |
| `CR_LIFECYCLE.md` | CR state machine | Living | CR states/transitions/vocabulary | owner-authorized |
| `CODING_STANDARDS.md` | code/SQL/API/security standards | Living | standards | as standards evolve |
| `PROJECT_CONTEXT.md` | identity/vision/boundaries | Living | product identity | owner |
| `CLAUDE/GEMINI/.cursor/.github`, `llms.txt` | tool / AI-convention entry pointers | Living | nothing — thin pointers to `README.md` → `AGENTS.md §4`; restate nothing (cannot drift) | keep thin |
| `WORKSTATION.md` | engineering-environment rebuild entry | Living | how to rebuild the workstation (points to `.workstation/`) | when env reproducibility changes |
| `.workstation/manifest.md` | SSOT of tools/extensions/MCPs/plugins + Earn-It rationale | Living | what the workstation contains | when a tool earns/loses its place |
| `.workstation/*.ps1` | recover (`prepare`) · verify (`doctor`) · `update` · `cleanup` · `decommission` | Living | reproducible environment scripts (the real logic) | with the manifest |
| `bootstrap.ps1` (root) | remote pre-clone bootstrap (`irm … | iex`) | Living | nothing — ensures git, clones repo, hands off to `.workstation/prepare.ps1` | keep minimal (no setup logic) |
| `workstation.cmd` (root) → `.workstation/menu.ps1` | Recovery & Maintenance launcher (recovery-first) | Living | nothing — thin pass-through invoking `.workstation/*.ps1` | keep thin (no logic) |
| `_ORVION_CANONICAL/**` | business + schema canon | Living (protected) | domain/schema intent, principles | owner-authorized CRs |
| `manifest.md` | live state | Living | current phase/CR | every CR |
| `reports/architecture-decision-records.md` | ratified ADRs | Living | ratified decisions | on owner ratification |
| `reports/master/MASTER_*.md` (15 incl. MASTER_REPOSITORY_HEALTH, MASTER_INTEGRATION_CATALOG, MASTER_API_CONTRACT) | findings/plan/blueprint/health/integration contracts/API surface | Living — **except `MASTER_API_CONTRACT.md`, which is Auto-generated: never hand-edit, regenerate** | see §2 rows | every review |
| `reports/evidence/{VALIDATED,PENDING,REJECTED}_*.md`, `INDUSTRY_REFERENCES.md`, `ARCHITECTURE_PROOF_LOG.md` | decision evidence | Living | finding lifecycle + evidence | every validation |
| `reports/future-backlog.md` | deferred + triggers | Living | deferred work | reviews |
| `reports/history/*-2026-07*`, `phase-*`, process reports | historical analysis | **Immutable** | the record of that session | never |
| `repository-index.md` | file index | Auto-gen | file listing | `scripts/repository-all.ps1` |
| `ai-map.json` | machine-readable AI cold-start map (pointers + extracted live-state) | Auto-gen | nothing — points to SSOTs | `scripts/generate-ai-map.ps1` (called by `repository-all.ps1`) |

**Redundancy resolved (was drift risk):** `MASTER_ARCHITECTURE_DECISIONS.md` overlapped the ADR log → it is now explicitly a **tracking overlay** (proposed + amendment status only), not a second decision record. `MASTER_EXECUTION_PLAN.md` overlapped canon-32 → it owns finding-**batches** and references roadmap **phases**, never restating them. `PROTOCOL.md`/`global-rules.md` overlapped AGENTS.md → both already declare deference; retained as subordinate, authoritative for nothing exclusive.

---

## 6. Drift-prevention rules (make divergence impossible)

1. **One SSOT per fact (§2).** Never type a fact into a second file — reference it.
2. **IDs, not restatements.** Findings are referenced by register ID (DC-*, R-*, BF-*, …) everywhere except their SSOT row.
3. **Living updates + immutable history.** Change conclusions by updating the LIVING doc and writing a NEW dated report; never edit an old one.
4. **Auto-generated files are never hand-edited** (`repository-index.md`, `ai-map.json`).
5. **Memory is a cache.** An operational fact must exist in the repo; memory may point to it, never replace it.
6. **Every review runs the Master Knowledge Loop** (merge → dedup → resolve contradictions → update Masters → verify nothing forgotten → write dated report). No isolated reports.
7. **Governance validation (automatable, §11):** a check that (a) every report has a class header, (b) no finding ID appears with conflicting status across Masters, (c) cross-reference links resolve.
8. **One authority per concept — governance consolidates here.** Every *knowledge-governance* rule (where a fact lives, how a decision/document flows, how drift is prevented, reports taxonomy) lives in exactly one place: this file. If such a rule is found anywhere else — AGENTS, README, a report, a template, a script, a prompt, memory — move it here and replace the original with a pointer; never duplicate it. Boundary (§5): **execution-conduct** rules remain owned by `AGENTS.md` and are *not* moved here — GOVERNANCE points to them. The same one-authority/one-owner/one-lifecycle discipline applies to every repository concept: no file may become a second authority for something another file already owns.

---

## 7. Reports organization

The full classification and index live in **`reports/README.md`** (self-explanatory folder). Summary: 3 classes — Living-Authoritative (Masters + evidence + ADR log + backlog), Historical-Immutable (dated review/phase/process reports), and the entry index. Physical subfoldering (`reports/master/`, `/evidence/`, `/history/`) is **done** (session 9); references cite by unique filename (§2) so the move broke nothing.

---

## 8. Future AI-agent governance guide (read this, then act)

Any Claude/Codex/Gemini/Cursor/MCP session:
- **Where truth lives:** §2 SSOT matrix. Always edit the SSOT, never a copy.
- **How to record a discovery:** run the §3 lifecycle. New finding → PENDING first; only Validated findings enter `MASTER_GAP_REGISTER.md`; only owner-ratified decisions enter ADRs/canon.
- **Where you may write:** LIVING docs (Masters, evidence reports, backlog) + a NEW dated report per review. **Where you must NOT write:** any HISTORICAL-IMMUTABLE report; `repository-index.md`; protected resources (`AGENTS.md`, `README.md`, `_ORVION_CANONICAL/**`) without explicit owner authorization (AGENTS §6).
- **What is immutable:** dated reports, ratified ADRs (supersede, don't edit), the event/audit backbone.
- **What needs owner approval:** any new ADR, any canon change, any roadmap change, anything irreversible (AGENTS §1 stop-conditions).
- **How evidence works:** a finding is not "true" until it survives the 9-stage pipeline incl. counter-proof; cite `INDUSTRY_REFERENCES` for external claims.
- **Never rediscover governance:** it is here. Read README → AGENTS → GOVERNANCE → manifest → active CR.

---

## 9. Human onboarding path (<1 hour)

1. `README.md` (2 min) — what ORVION is + one-hop routing to the right authority.
2. `AGENTS.md` (15 min) — how work is done, when to stop.
3. `GOVERNANCE.md` (this, 15 min) — where truth lives, how decisions flow.
4. `manifest.md` (2 min) — where we are now.
5. `reports/README.md` + `MASTER_CERTIFICATION_STATUS.md` (15 min) — platform completeness at a glance.
Total ≈ 52 min → a new senior engineer can navigate everything and knows exactly where to write.

---

## 10. Repository organization — assessment & proposal

**Assessment:** the repo already largely reflects governance (canon isolated, changes/ for CRs, reports/ for analysis, auto-index). Two weaknesses: (a) `reports/` is flat with 40 mixed-class files; (b) three subordinate conduct docs a newcomer must read to learn they're subordinate — solved by §5 registry + this file.

**Both proposals below are now DONE:**
- `reports/` → `reports/master/` (Living Masters), `reports/evidence/` (validation set), `reports/history/` (immutable dated + phase + process), keeping `reports/README.md` + `architecture-decision-records.md` + `future-backlog.md` at top. **Completed session 9.** Safe because references cite by unique filename (§2), not path.
- **Completed session 10:** one-line `GOVERNANCE.md` pointer added to `AGENTS.md §4`, `README.md`, and `llms.txt`.

---

## 11. Tooling & governance automation (evidence-based; not self-installed — modifies config/CI)

| Tool | Governance problem it solves | Priority | Install |
|---|---|---|---|
| **Governance-lint hook** (custom, in `scripts/`) | enforces: every report has a class header; no finding ID has conflicting status across Masters; `manifest.md Active CR` cleared after Complete | **High** | **IMPLEMENTED (2026-07-15/16):** `scripts/check_repository_consistency.ps1` + the `Repository Consistency` CI workflow enforce four invariants — (1) no broken document references in Living docs, (2) no intra-register finding-status contradiction, (3) boot-chain router integrity, (4) every report declares its class. Also in the doc definition-of-done (AGENTS §5, run before commit). Remaining optional extensions (`Active CR` cleared-after-Complete lint; full external link-check) are additive to the same script. Enforced-invariant registry: `reports/master/MASTER_REPOSITORY_HEALTH.md §2b`. |
| Extend `scripts/repository-all.ps1` | already auto-generates `repository-index.md`; extend to emit a `reports/README.md` manifest + validate SSOT class headers | High | edit existing script (owner-approved) |
| **Markdown link checker** (e.g. `lychee`) in CI | guarantees `[[ ]]`/cross-references resolve → prevents dangling SSOT pointers | Medium | CI step |
| **pgTAP** (DC-16) | tests are governance for schema invariants (RLS coverage, money scale) | Critical | test migration + CI |
| **Supabase/Postgres MCP** | lets any agent verify schema truth directly (SSOT = migrations) instead of `docker exec psql` | High | `.mcp.json` + secret |
| **squawk/sqlfluff** | migration-safety + convention lint (enforces CODING_STANDARDS as code) | High | CI |

I did not self-install any: all modify the user's Claude config or CI. Exact steps available; apply via the `update-config` skill on approval. App-facing tools (Playwright/Sentry/Stripe) remain future-gated (no app surface).

---

## 12. Governance migration plan (to reach the target state)

| Step | Action | Owner-gated? | Risk |
|---|---|---|---|
| 1 | Adopt `GOVERNANCE.md` as the knowledge SSOT (this file) | no (additive) | none | **DONE** |
| 2 | Add `reports/README.md` index | no (additive) | none | **DONE** |
| 3 | One-line pointer to GOVERNANCE.md in `AGENTS.md §4` + `README.md` + `llms.txt` | **yes** (protected) | trivial | **DONE** (session 10) |
| 4 | Reconcile the two resolved redundancies (§5) — annotate MASTER_ARCHITECTURE_DECISIONS as overlay, MASTER_EXECUTION_PLAN as batches-not-phases | no | none | **DONE** |
| 5 | Physical `reports/` subfoldering | **yes** (migration) | none — filename-cited refs | **DONE** (session 9) |
| 6 | Governance-lint hook + repository-all.ps1 extension | **yes** (config/CI) | low | **pending owner** |
| 7 | Retire `PROTOCOL.md`/`global-rules.md` to tombstone pointers | **yes** | low | **DONE** (session 10, full-diff verified) |

Only step 6 (governance automation — config/CI) awaits owner approval. Steps 1–5, 7 are complete.

---

## 13. Governance dependency graph

```
GOVERNANCE.md ──defines──▶ SSOT matrix ──governs──▶ every LIVING doc
AGENTS.md ──authorizes──▶ conduct ──drives──▶ CR_LIFECYCLE ──drives──▶ changes/SPEC-* ──update──▶ manifest
Decision lifecycle (§3) ──feeds──▶ MASTER_GAP_REGISTER (validated) ──feeds──▶ ADR log (ratified) ──feeds──▶ canon ──feeds──▶ implementation
INDUSTRY_REFERENCES + PROOF_LOG ──evidence──▶ VALIDATED/PENDING/REJECTED ──status──▶ MASTER_GAP_REGISTER
repository-index.md ◀──generates── scripts/repository-all.ps1
```
No cycle; one direction of authority (Policy→…→History). A change enters at the correct layer and flows down; it never flows up without owner ratification.

---

## 15. Governance-change lifecycle (governance governs itself)

**Documents serve ORVION — never the reverse (owner-ratified 2026-07-17).** ORVION's highest priority is continuous architectural improvement, not preservation of prior decisions. When any document — this file, AGENTS, PROJECT_CONTEXT, an ADR, canon, a convention — prevents an objectively superior architecture, *that document* becomes the subject of review: amend, supersede, split, deprecate, or retire it **through its owning lifecycle** (this §15 for governance; ADR-supersede for decisions; owner sign-off where the registry requires it). Never work around outdated governance, and never silently violate it either — improve it first, then proceed. Preserve history (tombstone-free retirement is fine — git is the archive); never preserve architectural mistakes.

Governance is a subsystem and evolves through a controlled lifecycle — never silently. A change to **this file, the SSOT matrix, any lifecycle, or the reports taxonomy** follows:

```
PROPOSE → EVIDENCE → RATIFY(owner) → VERSION-BUMP → CHANGELOG → MIGRATE → CERTIFY
```
- **Propose** — a dated governance report states the change + why (evidence, not preference).
- **Ratify** — owner approves (governance changes are owner-gated, like ADRs and canon).
- **Version-bump + Changelog** — increment the version header + add a changelog line (top of this file). SemVer-lite: MAJOR = SSOT reassignment or hierarchy change; MINOR = new section/lifecycle; PATCH = clarification.
- **Migrate** — if the change moves facts between docs, do it atomically with a link-update pass (never leave dangling pointers).
- **Certify** — §14 re-certified in the governance report.
- **Retire** — a superseded governance rule is struck through with a pointer to its replacement, never deleted (mirrors the ADR supersede convention — validated as current practice, Nygard/MADR).

**Governance compatibility:** a doc written under an older governance version stays valid; the changelog states what changed so a reader reconciles. No silent breaking changes.

## 16. SaaS portability layer (reuse across future products)

Governance artifacts are tagged **GENERIC** (portable to any SaaS repo — copy as-is) or **ORVION** (product-specific — do not copy). Nothing GENERIC may depend on ORVION content.

| Artifact | Tag | Portable because / ORVION because |
|---|---|---|
| `GOVERNANCE.md` (this OS: hierarchy, SSOT method, lifecycles, drift rules) | **GENERIC** | pure knowledge-governance; swap the SSOT *rows*, keep the *method* |
| `AGENTS.md` operating model (execution-is-default, tiering, stop-conditions) | **GENERIC** | conduct framework; ORVION examples are illustrative |
| `CR_LIFECYCLE.md`, `CODING_STANDARDS.md` (structure) | **GENERIC** (content partly ORVION) | the CR state machine + standards *shape* port; SQL specifics are ORVION |
| Reports taxonomy (🟢/🔵/🟠 classes, MASTER_* responsibilities, decision/knowledge/doc lifecycles) | **GENERIC** | the *shape* of the knowledge base is product-agnostic |
| Repository-health dashboard *shape* (§17) | **GENERIC** | metrics port; values are per-repo |
| `_ORVION_CANONICAL/**`, domain MASTER_* (catalog/ER/flow), travel findings | **ORVION** | business/domain — never copy to another product |
| `PROJECT_CONTEXT.md`, `future-backlog.md` | **ORVION** | product identity + deferred work |

**Reuse procedure for a new SaaS repo:** copy the GENERIC set → empty the SSOT matrix's product rows → start its own canon + Masters + ADR log under the same lifecycles. The **Engineering Operating System is the GENERIC set**; ORVION is one instance of it.

## 17. Repository health (measurable governance)

Governance effectiveness is **measured, not asserted** — the current-practice "fitness function" approach. The dashboard + drift-detection indicators live in `reports/master/MASTER_REPOSITORY_HEALTH.md` (Living SSOT for repo health), regenerated each review and (target) by the governance-lint automation (§11). If a health indicator regresses (e.g., a duplicate finding ID, a broken reference, a stale doc), that is a governance defect to fix, not tolerate.

## 18. Repository maintenance mode & lifecycle

The repository structure is **stable** (evidence: three consecutive engineering sessions produced only sync-level fixes — stale paths, counts, one script pointer — no structural redesign; all remaining structural items are owner-gated). Repository Engineering therefore operates in **Maintenance Mode**, permanently:

- Structural work is **reactive, not proactive** — the repository is changed only when repository evidence proves the change improves it. Repository *redesign* is no longer normal work; it requires new evidence, not preference.
- Maintenance is part of the **implementation lifecycle**, not a separate project. This prevents future large cleanup passes by keeping drift near zero continuously:

  ```
  Implement (a batch/capability) → Synchronize → Earn-It maintenance gate → Continue implementing
  ```

**Synchronization pass (lightweight — after each implementation batch; not a review).** Verify only: no stale references · no duplicate authority · no broken navigation · no inconsistent paths (§2 subfolders) · no doc referencing completed work as pending (or vice-versa) · no stale counts. Fix what is inside Repository Engineering authority immediately; classify the rest.

**Earn-It structural gate.** *Every* structural repository change must first pass the Earn-It rule (`AGENTS.md §3` — not restated here). A structural change is implemented only if it demonstrably: improves navigation · improves synchronization · reduces duplication · reduces maintenance · improves AI onboarding · improves human onboarding · reduces token consumption · preserves one authority per concept (§2). If any criterion cannot be shown, the change is **not** made.

**Discovery-to-guard loop (implementation is the review).** Implementation is the primary discovery mechanism; no separate review cycle is required to find gaps. When implementing a capability, run this loop:

```
Implement → Discover a gap (missing protection/test/reference/constraint/data/rule) → Prove it with repository evidence → Earn-It → Fix (if inside authority) → add the PERMANENT guard that prevents recurrence → Continue
```

The **permanent guard** is what distinguishes this from ad-hoc fixing: every fix that closes a class of defect also lands the invariant that keeps it closed — a pgTAP fitness function, a self-gating script, a CHECK/constraint, or seed. Precedent: SPEC-113/114 (pgTAP invariants), SPEC-115 (search_path invariant), SPEC-116 (self-gating smoke-test). Do not wait for the owner to request these; implementation exposes them. A gap whose fix crosses a protected boundary (Canon/ADR/Frozen-Baseline/schema/business/product) is classified and escalated, not implemented.

**Evolution on evidence (governance & environment are never frozen).** Governance, tooling, and engineering knowledge evolve when new evidence appears (implementation experience, repository evolution, better practice, new industry standards, new AI capability, new tooling). This is not a new rule — it is the standing behaviour, owned where it already lives: governance changes follow the **§15** lifecycle; tooling adoption follows **§11**; researching current best practice before a major decision follows **`AGENTS.md §3` step 2 (Learn-Before-Designing)**. The only addition here: re-evaluation is **periodic and evidence-triggered**, never assumed-complete — but a change is adopted only if it survives Earn-It, never because it is newer.

**Retention Earn-It (does this still earn its place?).** Earn-It is not only an *adoption* gate; it is also a *retention* test. At the review cadences that **already exist** — the phase-transition checkpoint (`AGENTS.md §3` step 8) and the Design-Drift/Synchronization pass — also challenge what already exists (governance rules, docs, tools, generated artifacts, automation, repository structure) with the inverse question: *does this still earn its place, or has it become bloat, duplication, or stale?* Whatever no longer earns it is simplified, merged, or retired **through the mechanism that already owns it** — governance rules via the §15 lifecycle (Retire, never silent-delete), tools via §11, docs/structure via the Earn-It structural gate above, generated artifacts by deletion. This adds **no new review event** — it is one extra question inside reviews that already happen, and it catches the slow accumulation a purely pre-adoption gate cannot. (Precedent: the 2026-07-13 pass removed a stale `future-backlog.md` MCP entry and flagged `ai-map.json` as provisional with a kill-criterion.)

## 19. Repository Stewardship (permanent — owner-ratified 2026-07-17)

The engineering role is **Repository Steward**: responsible not only for the current phase but for the whole repository as ORVION's *permanent memory* — a future session with a different AI agent must reconstruct the entire system from repository evidence alone (§8; `AGENTS.md §4/§6`). This section **sequences** existing duties into a standing responsibility; it restates neither the drift rules (§6), the health dashboard (§17), nor the maintenance/Retention-Earn-It lifecycle (§18).

- **Implementation age is not evidence.** When any existing component becomes relevant to current work, re-audit it against current repository evidence — never trust it because it already exists. (`AGENTS.md §2` Test-before-trust, applied to the *existing* repo, not only new work. Precedent this session: Group-1 constraints assumed missing were already built; `account_type` "gap" was ADR-0006 by design — both caught only by re-auditing.)
- **Repair before features.** A discovered defect materially affecting correctness / integrity / synchronization / security / canonical completeness becomes the highest priority — never build new capability on a weak foundation. (Conduct half: `AGENTS.md §2` anti-entropy.)
- **Every historical recommendation must resolve.** No ADR / finding / backlog item / deferred decision / trigger may accumulate as stale: whenever it becomes relevant, re-apply Earn-It and drive it to one of three terminal states — *implemented*, *rejected-with-evidence*, or *intentionally-deferred-with-a-justified-trigger*. Nothing is silently forgotten. (Mechanism: the §18 Retention-Earn-It cadence.)
- **Governance before execution.** A reusable workflow / discipline / safeguard is preserved in canonical governance *before* it is applied — never left only in conversation (§5 permanent memory).

**Knowledge-graph philosophy — Earn-It determination (2026-07-17, Learn-Before-Designing).** Researched the *principles* behind Zettelkasten / knowledge graphs / linked thinking: atomic single-home notes; stable IDs that survive renames; bidirectional/traceable links; plain-markdown source of truth; emergent non-hierarchical structure; orphan/drift detection. **Finding: ORVION already embodies ~80% by design** — the SSOT matrix (§2 = atomic single-home facts), cite-by-unique-filename + finding-IDs (§2 = stable IDs surviving moves), the decision/knowledge/document lifecycles (§3–§4 = decision & capability lineage), plain-markdown throughout, and the consistency guard (broken-reference detection). **Verdict: adopt the *principles* (largely present already); REJECT a wikilink/backlink tooling layer or graph application** — rewriting every cross-reference into `[[links]]` for marginal gain over the existing SSOT+ID system is tooling-shaped bloat (fails Earn-It, mirrors the rejection of duplicate authority in §6). **Adopt the earns-it delta:** treat *orphan and lineage completeness* as a first-class stewardship signal — at the §18 review cadence, scan for orphan ADRs/tables/RPCs/events/reports and broken/duplicate references and drive each to resolution. This is a **judgment scan, not a CI gate**: the first scan (2026-07-17) flagged ADR-0003/0008 as cross-reference orphans, but verification showed both are *foundational decisions implemented pervasively* (shared-schema RLS on every table; `moddatetime` triggers) — not defects. A hard gate would cry wolf on exactly these, so orphan detection stays a periodic steward review, honouring the guard's precision-over-recall discipline.

## 14. Final governance certification

**CERTIFIED — governance is complete, non-conflicting, and drift-resistant.** Migration steps 1–5 and 7 are DONE; only governance automation (step 6, config/CI) remains owner-gated and does not block operation. Evidence:
- **One hierarchy** (§1); **one SSOT per fact** (§2) with the two real redundancies resolved (§5).
- **Permanent decision, knowledge, and document lifecycles** (§3–4) — no longer living only inside review reports.
- **Drift-prevention rules** (§6) make divergence a rule violation, not an accident; automatable (§11).
- **Self-explanatory reports** (§7 + `reports/README.md`); **AI-agent guide** (§8); **<1-hour human onboarding** (§9).
- **No conflict found** among conduct docs — precedence already self-declared; retained as subordinate.

**Residual (owner-gated):** governance automation (step 6 — governance-lint hook, link-checker, pgTAP) — the only remaining item; additive, blocks nothing. It would move the §17 drift indicators from best-effort (👁) to enforced (⚙).

*This governance system is designed to operate for years across many engineers and AI agents without knowledge loss, duplication, or drift. Challenge it in any future governance review exactly as rigorously as the architecture was challenged.*
