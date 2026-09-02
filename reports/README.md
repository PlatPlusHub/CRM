# ORVION reports/ — Index & Organization

Governed by `GOVERNANCE.md` (§7). This folder holds analysis, findings, evidence, and history — **never** authoritative business/schema canon (that is `_ORVION_CANONICAL/**`).

> **Latest session report:** `history/session-2026-09-02-clear-on-complete.md` — **COLD-3: the pointer was never checked against the lifecycle it points into.** COLD-2 made Check 7 prove that `manifest.md` and `ai-map.json` *agree* about `Active Change Request`. Nothing asked whether what they agree on is *true*: with the manifest naming `SPEC-125`, whose own Status is `[x] Complete`, and ai-map regenerated to match, the guard printed **CLEAN** — as it did naming a CR file that has never existed, because Check 1 excludes the `SPEC-NNN.md` placeholder shape and nothing had ever resolved this path. `AGENTS.md §4` step 4 *branches* on that field, and the pointer-clear had already been omitted twice (SPEC-024, SPEC-027). **Check 18** validates it against the CR's own `## Status` — the authority `changes/TEMPLATE.md` defines and `CR_LIFECYCLE.md` governs — **read, never copied**, so no CR status enters the manifest or ai-map and no second source of truth appears. All 151 CR files surveyed: one Status section each, one checked box each, so the model is coherent and no owner decision arises. 15 mutation runs, each echoing on-disk state before its verdict; the same CR file flips CLEAN↔FAIL purely on its own Status box. **The open-CR case caught a false positive in the check itself** — a single regex match returns a scalar string, so `[0]` read a character and `In Progress` became `I`; no FAIL-expecting case could have found it. Sync and lifecycle proven independently failable in both directions. Closes the `future-backlog.md` Complete-sync safeguard. Repository-only: no migration, no database change.
>
> *Previously:* `history/session-2026-09-02-cold-start-handoff-guard.md` — **COLD-2: the handoff field no guard compared.** `generate-ai-map.ps1` extracts four live-state fields from the manifest and Check 7 compared three — the missing one, `active_change_request`, being the field `AGENTS.md §4` *branches* on and the whole of the agent handoff (`§6`, `CR_LIFECYCLE.md §9`). Proven blind in **both** directions before the fix: ai-map naming a SPEC that does not exist, and the manifest naming a SPEC ai-map did not carry, each printed CLEAN — a cold-start agent would have chased a Change Request that was never approved, or silently skipped the one in flight. Root cause: Check 7's coverage was a record of *past incidents* (each field guarded only after it had drifted) rather than a statement about the generator's contract — the GOV-4 / MEAS-1 class. Now compared by value on the identical contract as `Last Completed`, whose own comparison had been inert for forty commits until `4b67d3f` and was **never recorded until now**; both halves are registered as COLD-2. Attacked with 14 runs reporting each sub-comparison separately, so field isolation is measured, not assumed. The clear-on-Complete gap (SPEC-024/027) is explicitly **not** closed by this and is stated as a limit. Manifest headroom restored 33 → 747 characters by deleting chained history, **without raising any budget**. Repository-only: no migration, no database change.
>
> *Previously:* `history/session-2026-09-01-cold-start-guard.md` — **the cold-start contradiction, and the guard that reads canon against the decision list.** `32_execution_roadmap.md` told a fresh session that SEC-1 was an open owner decision blocking Phase 10, four days after the owner ratified it, and restated "71 RPC endpoints" inside a sentence declaring it never restates that count. Verifying the first found a third: the register's own SEC-1 row still said AWAITING OWNER RATIFICATION while its OWNER-1 row recorded the ratification — Check 2 could see neither, because a status cell opening `**EVALUATED …**` is neither its OPEN form nor its resolved form, and no guard had ever read canon against the decision list. Fixed by deletion rather than refreshment; **Checks 16 and 17** added, attacked with 13 cases including a second-direction test that mutates the authority instead of the consumer. A living-document re-scan found 74 further restated figures and confirmed every one is dated evidence, not a current claim. Repository-only: no migration, no database change.
>
> *Previously:* `history/session-2026-09-01-finance-periphery.md` — **PAY-1 / JE-1 / DEV-1, and the blind spot in my own detector.** The Batch-6 slice of tables `authenticated` can write that no test had ever been *about* — a ranking attacked twice before use, because counting triggers scores `moddatetime` as protection and counting test mentions scores `tenants` at 76 since every test builds a tenant fixture. `app.record_payment` refuses a draft, voided or archived invoice and `payment_allocations` carried neither rule, so 1,000 EGP sat allocated against a voided invoice while FIN-10's ceiling stayed green — it caps the amount and never reads the state. A journal line could post to a retired chart account. Two concurrent `record_trusted_device` calls produced two rows for one device, reproduced through the RPC alone. **And PARENT-1's own detector could not see the worst of them**, because it derived its population from `app.status_transitions` and `invoices` has no rows there (FIN-7): widened, counterexample-tested, residual stated rather than hidden. Two hypotheses were killed by measurement before any code was written. JE-2 (a journal entry balancing across two currencies) recorded and deliberately not fixed — DC-11 owns that model. Migration `202607059500`, deployed.
>
> *Previously:* `history/session-2026-09-01-parent-state.md` — **PARENT-1: the parent's state is a rule on every door.** The care/conversation slice was re-entered from live state and `conversation_messages` exposed a class: four RPCs refuse a write because of the PARENT row's state — an unaccepted quotation, a cancelled booking item, an archived document, a closed conversation — and not one of those rules existed on the table door `authenticated` reaches through PostgREST. The population was derived from `app.status_transitions` + `pg_proc` + `pg_trigger` rather than listed; twelve candidate pairs were reduced to four by reading each function instead of trusting the match. All four reproduced live with the RPC as positive control, and closed by one guard function plus four BEFORE INSERT triggers with the RPCs' messages copied verbatim. The HTTP suite already asserted both halves of the conversation case and missed it because they were never asked at the same moment. Also: a live instance of GOV-9 — QUO-4 had been an open owner decision the manifest never listed. Migration `202607059400`, deployed.
>
> `AGENTS.md §4` Stage A step 7 requires every session to read this before proposing work. **Whoever writes the next session report updates this row in the same commit** — an unlinked report is invisible to the boot sequence, which is the one job this pointer has.

**Physical structure (reorganized 2026-07-11, session 9):**
```
reports/
  README.md                      (this index)
  architecture-decision-records.md   (ratified ADR log — top-level authority)
  future-backlog.md                  (deferred work + triggers)
  master/     🟢 Living-Authoritative — findings, plan, blueprint, API contract
  evidence/   🔵 Living — decision-validation trail
  history/    🟠 Historical-Immutable — dated review/phase/session/process reports
```
*(File counts were removed 2026-08-29 — GOV-5. They had read 14 / 5 / 34 while the real figures were 15 / 5 / 78, and a count that must be hand-maintained on every commit is a stale number waiting to happen. `ls` answers it exactly; the current population is tracked in `MASTER_REPOSITORY_HEALTH.md §2`, which is reviewed rather than incidental.)*
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
| `MASTER_API_CONTRACT.md` | the client-facing surface — RPC endpoints, tenant-reachable tables, reporting views, permissions, HTTP-evidence coverage. **AUTO-GENERATED (`scripts/generate-api-contract.ps1`); never hand-edit** — `check_database_parity.ps1` Check L3 regenerates and diffs it |

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
