# ORVION reports/ — Index & Organization

Governed by `GOVERNANCE.md` (§7). This folder holds analysis, findings, evidence, and history — **never** authoritative business/schema canon (that is `_ORVION_CANONICAL/**`).

> **Latest session report:** `history/sched-1-and-the-silent-backlog-2026-08-28.md` — three of the four recurring jobs are scheduled; the **storage executor** is the fourth and has none. All three routes (pg_cron+pg_net+**Vault, which is installed** — improving the position from when pg_net was first declined; n8n; a scheduled Action) need **one owner-placed secret**, and choosing between them is a security trade-off — so `pg_net` was **not** installed to make a metric move. What needed no decision: the gap was **silent**. `app.storage_action_backlog()` reports pending actions, **the age of the oldest** (the only field that separates "in flight" from "nobody is running this"), failed attempts and unresolved findings, `service_role` only — and it **calls** `claim_storage_actions` rather than restating its rules, because a monitor measuring a different population than the worker reports zero while work piles up. The test asserts the two counts *equal*. Predecessor `history/lead-handler-authority-and-trans-2026-08-28.md` — opens with a **correction**: the previous package recorded that `app.record_lead_interaction` "authorizes nothing" and left `lead_interactions` open. It *does* authorize — *"the assigned handler, OR ASSIGN_LEAD, plus MFA"* — inline with `has_permission` rather than `authorize`, which a permission-shaped detector could not see. Chasing the rule found the larger half, **TRANS-2**: eight `leads` transitions carry a NULL `permission_key` and the trigger checked nothing when null, so direct DML could walk a **colleague's** lead from `contacted` to `won` to `converted` while every RPC refused. Fixed by one shared rule, and **a null now means "apply this table's named fallback" — a table with neither FAILS CLOSED.** TRANS-1 investigated per the directive (no live disagreement; an `event` column *not* proven the right home) — but **its guard was checking one function out of ten** and is rewritten to parse all ten and to check the reverse direction, which is exactly where TRANS-2 was hiding. Ceilings **54/17/3**, and the three are canon-34 Human Identity tables: **SEC-1 has no unexplained residue left.** Predecessor `history/lifecycle-branches-and-the-trainee-2026-08-28.md` — every journey the previous reports listed as UNPROVEN, executed over real HTTP: the trainee's full first morning (each refusal paired with a positive control on the same query), quotation rejected/revised/expired with both revival paths, booking approved → issued → **reissue** → issued with the authority split proven at each step, deposit-then-balance payment allocated exactly, the supplier-failure chain end to end, document expiry as a real window, and the returning customer on one 360 timeline. **57 new assertions; HTTP coverage 118 → 175.** Found **DOC-EXP-1**: `expiring_documents` works, but the `document_expiry` notification type has **no producer** — an expiring passport tells nobody. Also records a collision of mine that only the new order-independent regime could surface: pgTAP files roll back so tests never collide, but the HTTP scripts do not, so a script's tenant slug must be unique against every *test* slug too. Predecessor `history/sec1-residue-and-fixture-scoping-2026-08-28.md` — SEC-1's thirteen turned out to be **three different problems needing opposite actions**, so counting them was itself the mistake. Five system-owned tables had every writer as SECURITY DEFINER and none executable by `authenticated` — the grant was a second door only direct DML used, so it was **revoked, not permissioned**. Four configuration tables with no writer at all were guarded with the permission ORVION already charges for the same object (`branches` → MANAGE_BRANCHES; `chart_of_accounts` → CREATE_JOURNAL_ENTRY — which corrected my own wrong guess of MANAGE_TENANT_SETTINGS, that would have locked finance out of its own bank accounts). Three were never residue: canon 34 says ownership by `auth.uid()` IS their model. **Residue 13 → 1** (`lead_interactions`, where the RPC authorizes nothing either, so there is no bypass — only an undecided question). Also **TEST-1**: `38_class_a_events_test` failed on a real FK because its fixture cross-joined every tenant's invoices; the class search found 40+ unscoped fixture subqueries in 11 files, and the suite is now proven **order-independent** rather than merely green. Predecessor `history/phase-c-write-capability-2026-08-28.md` — FIN-3's rule generalised; nine tables guarded from their own RPCs. Predecessor `history/phase-c-financial-capability-2026-08-28.md` — the ledger was guarded and the cash was not (FIN-3/FIN-4). Predecessor `history/phase-c-role-journeys-2026-08-28.md` — RBAC-4, TASK-2, SEC-1 reproduced. Predecessor `history/phase-c-journey-branches-2026-08-28.md` — FIN-2, TASK-1, TRANS-1. Predecessor `history/api-1-application-surface-and-employee-journey-2026-08-28.md` — ORVION stops being unreachable.
>
> `AGENTS.md §4` Stage A step 7 requires every session to read this before proposing work. **Whoever writes the next session report updates this row in the same commit** — an unlinked report is invisible to the boot sequence, which is the one job this pointer has.

**Physical structure (reorganized 2026-07-11, session 9):**
```
reports/
  README.md                      (this index)
  architecture-decision-records.md   (ratified ADR log — top-level authority)
  future-backlog.md                  (deferred work + triggers)
  master/     🟢 Living-Authoritative — findings, plan, blueprint (14)
  evidence/   🔵 Living — decision-validation trail (5)
  history/    🟠 Historical-Immutable — dated review/phase/process reports (34)
```
**Reference convention:** reports are cited by **unique filename** (filenames are globally unique); the subfolder is an organizational detail. So `MASTER_GAP_REGISTER.md` resolves regardless of prose reference — moves never break citations.

> **Where do I write a new finding?** → `evidence/PENDING_ARCHITECTURE_FINDINGS.md` first, then (if validated) `master/MASTER_GAP_REGISTER.md`. See `GOVERNANCE.md §3`. Never edit a 🟠 `history/` file.

## reports/ root — stable authorities
| File | SSOT for |
|---|---|
| `architecture-decision-records.md` | **ratified ADRs** (ADR-0001…) |
| `future-backlog.md` | deferred work + triggers |
| `README.md` | this index |

## master/ 🟢 — Master documents
| File | SSOT for |
|---|---|
| `MASTER_GAP_REGISTER.md` | **all accepted findings** (others reference its IDs) |
| `MASTER_EXECUTION_PLAN.md` | finding batches (references roadmap phases in canon-32) |
| `MASTER_DEPENDENCY_GRAPH.md` | finding dependencies / ordering |
| `MASTER_RISK_REGISTER.md` | production/compliance risks |
| `MASTER_CERTIFICATION_STATUS.md` | certification state + gate |
| `MASTER_DESIGN_CHECKLIST.md` | design-integration checklist |
| `MASTER_ARCHITECTURE_DECISIONS.md` | proposed/amendment **overlay** (ratified log is at root) |
| `MASTER_DOMAIN_CATALOG.md` | domain index + completion % |
| `MASTER_ENTITY_RELATIONSHIP_MAP.md` | entity CRUD + references |
| `MASTER_DATA_FLOW.md` | end-to-end business flows |
| `MASTER_COVERAGE_SCORE.md` | design-completeness scorecard |
| `MASTER_HEAT_MAP.md` | architectural-importance ranking |
| `MASTER_REPOSITORY_HEALTH.md` | measurable repo/governance health |
| `MASTER_INTEGRATION_CATALOG.md` | external-integration contracts: registry, workflow specs, owner-setup checklists (seeded 2026-07-17, Phase-8 trigger) |

## evidence/ 🔵 — decision-validation trail
| File | Role |
|---|---|
| `VALIDATED_ARCHITECTURE_DECISIONS.md` | findings that passed the 9-stage pipeline |
| `PENDING_ARCHITECTURE_FINDINGS.md` | findings that failed a stage (+ triggers) |
| `REJECTED_ARCHITECTURE_DECISIONS.md` | rejected designs/sub-solutions (+ reasoning) |
| `INDUSTRY_REFERENCES.md` | external evidence library (cited by ref-id) |
| `ARCHITECTURE_PROOF_LOG.md` | every finding's path through the 9 stages |

## history/ 🟠 — immutable session/phase/process records (do not edit)
Design/review sessions: `engineering-audit-2026-07` · `business-stress-test-2026-07` · `design-evolution-plan-2026-07` · `complete-platform-design-baseline-2026-07` · `complete-platform-physical-design-2026-07` · `architecture-synthesis-2026-07` · `design-completion-certification-2026-07` · `design-review-2026-07-11` · `design-authority-2026-07-11` · `final-design-proof-2026-07-11` · `governance-eos-consolidation-2026-07-11` · `repository-eos-review-2026-07-11` · `repository-eos-validation-2026-07-11` · `execution-readiness-2026-07-11` · `repository-engineering-2026-07-11`
Phase & process: `phase-02-*` (2) · `phase-03-user-lifecycle-review` · `phase-04-crm-core-retrospective` · `phase-05-finance-gate-readiness` · `phase-2-*` (3) · `repository-communication-protocol` (+v0.2) · `repository-engineering-program` · `workflow-architecture-report` · `pre-phase8-readiness-audit-2026-07-13`
Discovery/verification checkpoints (read to continue from preserved engineering state, not to restart): `session-discovery-checkpoint-2026-07-14` — full state of the owner-directed review+research session (5-specialist verification pass, external compatibility research, approved P1–P7, UUIDv7/Self-Healing/Self-Learning/Airports-Airlines conclusions, consolidated synchronization register, pending owner decisions). · `repository-synchronization-integrity-audit-2026-07-15` — owner-directed final Repository Synchronization & Integrity Phase before Phase-8 implementation; re-verifies all prior findings against current file state (HIGH integrity, no forgotten architecture), confirms S-EVENT as the one live structural gap, and gives a priority-ordered Recovery Plan (awaiting owner approval). · `repository-reverification-log-2026-07-15` — deeper source-level re-verification pass (prior reports untrusted); independently confirms 76 migrations / 71 tables / 55 RPCs, resolves the RPC-count ambiguity (F11=55), re-confirms S-EVENT, and finds no new issue — the audit above remains the current register + Recovery Plan. · `repository-recovery-completion-2026-07-15` — **completion record** of the Repository Recovery phase: what was synchronized/annotated/cleaned, the permanent CI consistency guard installed, verification (guard CLEAN), remaining owner decisions, and the next-phase recommendation (Reporting/RC-4 before Phase 8). Governance advanced to v1.6. · **`pre-workflow-ground-truth-audit-2026-08-21`** — owner-directed **read-only** ground-truth audit before the first n8n Workflow: boot sequence re-run from scratch, then live introspection of Primary, the local stack, GitHub and n8n. Verdict `CLEAN WITH DOCUMENTATION DRIFT` — every executable axis reconciled (90 migrations agreeing by version *and* name across all three; smoke-test and both vocabulary guards executed live on Primary; SPEC-123's deployed function byte-identical to its certified md5), with three documentation-side defects found. Read it as **point-in-time evidence at HEAD `0cdcfd2`, not current state.** · **`remediation-and-hardening-pass-2026-08-21`** — the sequel that acted on every one of those findings and is the current-state record (HEAD `8b01de3`, 91 migrations). Its own discoveries matter more than the audit's: a **live-only privilege defect** (`anon` held full DML on all 72 public tables; `authenticated` held `DELETE`/`TRUNCATE`) inherited from Supabase's hosted default ACL and structurally invisible to `db reset` + the smoke-test — fixed by SPEC-124 and guarded — plus **SEC-1**, the open owner decision on whether `authenticated` should hold direct table writes at all, since RLS scopes rows and not permissions. Also carries the Google Data Manager API field contract re-verified against current official docs, and the WeWeb assessment (`CONDITIONALLY RECOMMENDED`).

## Reading order for a newcomer
`master/MASTER_CERTIFICATION_STATUS.md` (where we stand) → `master/MASTER_GAP_REGISTER.md` (what's open) → `master/MASTER_EXECUTION_PLAN.md` (what's next). History is context, read on demand.
