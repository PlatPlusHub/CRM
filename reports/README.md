# ORVION reports/ — Index & Organization

Governed by `GOVERNANCE.md` (§7). This folder holds analysis, findings, evidence, and history — **never** authoritative business/schema canon (that is `_ORVION_CANONICAL/**`).

> **Latest session report:** `history/session-2026-08-29-contract-to-finance.md` — the whole 2026-08-29 session in one place, **across a usage-limit interruption**: the owner's ten recommendations evaluated (9 ACCEPT, 1 ACCEPT-with-finding, none changing the execution order), the **API Capability Contract** delivered as a GENERATED document guarded by a regenerate-and-diff check, **SEC-2 resolved** — it was never one question — and **FIN-6**, the invoice an employee could declare PAID with no payment. Its through-line: **three of the session's findings were defects in the things that MEASURE, not the things measured**, and two of the three were mine. Also records what was in flight when the limit hit (a probe failing on an invalid UUID) and that the failure on resuming was **Docker being down, not SQL** — because those look identical in a transcript and only one is a finding. Carries three corrections: **PAR-1a** (the previous session's "all 228 functions byte-identical" used a POSIX bracket expression that does not mean what it looks like), **PAR-1b** (I twice read "the repository's text" out of a hand-modified local database and pushed it to Primary while reporting the opposite — RET-1 was never at risk on either environment), and a broken `\b` regex that would have supported the false conclusion "ORVION has no update RPCs at all". Per-package detail: `sec2-resolved-and-the-invoice-that-paid-itself-2026-08-29.md` and `the-api-capability-contract-2026-08-29.md`. Predecessor `history/the-care-journeys-and-the-ceiling-that-counted-wrong-2026-08-29.md` — complaints and conversations walked end to end over HTTP, and **SEC-1b**: the SEC-1 ceiling asked whether a table had a trigger MENTIONING `app.authorize` and never asked WHEN it fires, so thirteen tables were credited with INSERT-path protection they did not have; corrected residue **3 → 15**, reproduced by a `trainee` inserting a complaint AND a conversation by direct DML in the same transaction the RPC refused them. Also ATTR-4, CONV-2, COMP-1, and **TEST-2** — Pass B DIED where Pass A was green, on an `auth.users.email` collision, the one identifier the slug-collision rule never covered. Predecessor `history/scheduled-execution-and-the-guard-that-never-looked-2026-08-29.md` — all six background paths traced; **CONV-1** was real loss (a lapsed tenant's conversions were DESTROYED, not deferred, and restoring the tenant recovered nothing), **SCHED-2** gave two cron jobs the per-item isolation their sibling `reconcile_document_storage` already had, and **PAR-1** found that parity had never compared anything beyond the ledger and the functions each package touched. Predecessor `history/acquisition-lineage-and-the-eligible-handler-2026-08-29.md` — **ATTR-3**: acquisition lineage was rewritable by any employee (§8 item J answered and then exceeded), and **LEAD-3** resolved by the permission matrix, which exposed the real defect beneath it — SLA reassignment chose by PROXIMITY, handing an overdue lead to a **trainee** who can neither quote nor close. Also **GUARD-1**: the parity guard reported "primary proven" for a fingerprint supplied to it. Predecessor `history/sla-1-the-escalation-that-never-fired-2026-08-29.md` — canon 04 and canon 10 both require the employee's **manager** to be notified when a lead breaches its 15-minute SLA, and canon 10 lists it among the notifications a user **cannot mute**. It had never fired. Earlier predecessors are chained from that report.
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
