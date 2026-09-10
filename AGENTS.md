# AGENTS.md — ORVION Operating Kernel

This is the universal, client-neutral operating kernel for every ORVION engineering session. It is intentionally small. `scripts/check_agent_continuity.ps1` derives task/runtime state; the linked authorities own detail.

**Precedence.** A live owner instruction wins. Otherwise this file governs execution posture, `CR_LIFECYCLE.md` governs Change Requests, `GOVERNANCE.md` governs knowledge placement, Canon governs business/domain truth, and migrations + Git are as-built truth. `PROTOCOL.md` and `global-rules.md` are retired pointers.

## 1. Execution boundary and stop conditions

Repository READ/search access is unrestricted. CREATE/MODIFY/DELETE authority exists only in an Approved or In-Progress CR's exact `Write Scope`; Required Reading never grants write authority. In PLAN, read, search, research, diagnose, and draft a proposed CR, but do not mutate implementation. Official CR statuses remain exactly Draft, Approved, In Progress, Complete, Cancelled. PLAN, READY_FOR_APPROVAL, EXECUTE, VERIFY, BLOCKED and CERTIFY are runtime activities/verdicts, never statuses.

Execution is the default inside approved scope. Do not pause for routine Git, tests, commits, synchronization, or objectively derivable implementation choices. Stop only for:

1. a genuine owner-only business/legal/commercial preference or new irreversible architecture direction after Decision Exhaustion;
2. an unresolved canonical contradiction;
3. a material unexpected blocker outside bounded recovery;
4. a destructive/irreversible action outside the approved workflow;
5. unauthorized write scope, Git divergence, technical impossibility, or exhausted recovery.

Never invent policy, expose/request secrets, force-push, use `--no-verify`, rewrite history, weaken a guard, widen scope to hide a failure, or touch unrelated user work. Before a destructive action resolve the exact target and prove it is authorized. Credentials remain external to Git; repository configuration may name environment-variable handles, never values.

**The capability is the unit of progress.** The roadmap is organized around approved business capabilities; a Change Request (SPEC) is one engineering step delivering one. When a capability is best delivered as several small SPECs, continue through them as one flow — do not treat each SPEC as a fresh decision point. Drive the capability to a coherent, verified completion.

**Standing execution directive (owner-ratified 2026-07-17): finish → audit → classify → execute.** (1) **Finish before proceeding** — no new unit (phase / capability / slice / migration) begins until the current one is complete on every axis: implemented, verified, tested, Review-Gate-passed, governance-satisfied, docs + Canon + repo synchronized, working tree clean, committed, no known in-unit debt. (2) **Pre-unit Critical Architecture Audit** — before each major unit, review as architect + auditor to *actively discover* missing structure / lookups / reference data / identifiers / relationships / FKs / indexes / constraints / events / drift / duplication; assume incomplete until proven otherwise; validate every conclusion against implementation, never against prior conclusions. (3) **Classify every decision immediately** — technical/architectural (derivable from implementation, PostgreSQL/Supabase, enterprise SaaS practice, current research) ⇒ decide, document the reasoning, continue; **business-policy** (customer/product behaviour, pricing, finance/compliance/legal, commercial strategy) ⇒ present options + trade-offs + recommendation and wait, never silently defer; insufficient evidence ⇒ research first, exhaust technical investigation before asking. (4) **Execution focus** — the active unit has priority; classify/record future improvements without pausing *unless* they are critical architectural debt, security, integrity, data-loss, or a structural defect that grows materially more expensive if postponed. This crystallizes conduct already owned here (Earn-It §3, Fundamental Domain Structure §3, discovery-to-guard `GOVERNANCE.md §18`, Learn-Before-Designing §3, definition-of-done §6) — it restates none of them, it sequences them.

## 2. Permanent principles

- **One Authority:** one fact has one owning location; other files point to it. See `GOVERNANCE.md §2`.
- **Earn-It:** every process, file, abstraction, tool, and permanent rule must measurably increase confidence; prefer the simpler equivalent.
- **Test Before Trust / No Guessing:** a claim is PROVEN only by an observed relevant check. Otherwise mark UNPROVEN, FAILED, or BLOCKED. Guard success proves only that guard's declared evidence class.
- **Anti-entropy:** leave touched surfaces simpler, synchronized, deterministic, and harder to misuse; never turn this into unrelated cleanup.
- **Implementation autonomy:** choose the strongest practical reversible option already implied by Canon, ADRs, implementation, tests, Git, and current official evidence.
- **Owner boundary:** never invent business policy, legal/compliance risk acceptance, commercial preference, or a genuinely new strategic architecture direction.
- **Repository memory:** chat is not state. Persist durable truth in its existing authority; reusable executable failure classes become guards/tests.

The active capability must finish on every relevant axis before another begins: implement, verify, Review-Gate, synchronize, commit, push, clean tree, no known in-unit debt. A checkpoint records progress; it is not a routine permission pause.

## 3. Runtime workflow

Run from the repository root:

```powershell
pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Boot
```

Boot validates and extracts manifest, active CR, official status, Runtime Checkpoint, Git/upstream, repository guard, capabilities, verification profile, and blocker. Follow its exact `ACTION`, `WRITE`, and `START_CONTEXT`. Boot routes context; it does not preload whole Governance, Canon, reports, or guard output. Read more whenever evidence requires it.

Every implementation cycle is:

```text
PLAN → FRESHNESS → PRECHECK → EXECUTE → VERIFY → CERTIFY
```

- **FRESHNESS:** `INTERNAL_SUFFICIENT` when repository authority answers the decision. Use `EXTERNAL_REFRESH_REQUIRED` for materially fast-changing AI/model/tooling, SDK/API, GitHub, Supabase, n8n, Google/Meta, security, cloud, or external-contract assumptions; use current official/primary sources narrowly.
- **PRECHECK:** observe the present invariant or construct the defect/counterexample before editing.
- **EXECUTE:** make the smallest approved change.
- **VERIFY:** repeat the observation and exercise allowed/blocked behavior proportional to risk.
- **CERTIFY:** run `-Gate`, all derived mandatory profiles plus CR additions, repository consistency, generated-artifact freshness, checkpoint validation, and Git checks.

Before completion run:

```powershell
pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish
```

Only a successful Finish permits Review/Complete. CR transitions, immutable contract sections, synchronization, and command vocabulary live in `CR_LIFECYCLE.md`.

### Decision and architecture discipline — restored compatibility authority

**Governing meta-principle — Earn-It.** Optimize for engineering *confidence*, not process. Every step (and every artifact, document, and abstraction) must justify itself by measurably increasing confidence. If the same confidence is reachable with fewer steps or fewer files, prefer the simpler path. This guards against both governance bloat and documentation bloat.

**Fundamental Domain Structure vs Feature Implementation (owner-ratified 2026-07-17).** Earn-It's deferral pressure applies to *capabilities, infrastructure, integrations, workflows, automations, external systems, scheduled jobs, caches, optimizations, and feature behaviour* — not to the **canonical domain model**. A table, lookup family, enum, reference dataset, relationship, foreign key, constraint, index, event, canonical field, or business identifier that is an *inevitable* part of ORVION's domain belongs in the repository **now, even with no current consumer** — deferring it only forces an expensive structural migration after production begins, which ORVION exists to avoid. Include a structure now **only if it satisfies ALL of:** inevitable · architecturally correct · belongs to the canonical domain · reduces future structural migrations · improves long-term integrity · supported by modern enterprise best practice (as of the decision date). The decisive test: *"If ORVION were a mature enterprise travel SaaS in five years, would this structure almost certainly exist regardless of feature order?"* — if yes, add it in its correct canonical location; if it is speculative, feature-shaped, or has multiple equally-valid models whose correct choice depends on an unbuilt feature, do **not** invent it — record it with a trigger. Structural completeness is a first-class goal: future phases should primarily add *behaviour*, not redesign *structure*.

**Classify each capability at the start (this keeps reviews light):**
- **Routine** — established pattern, no architectural impact (a guarded RPC reusing a proven pattern). Minimal ceremony: phase-fit → design review → implement → Review Gate (with inline Excellence check). No Design Challenge.
- **Significant** — introduces or materially changes a business capability or architectural boundary (new/changed aggregate, phase/domain boundary, finance/security/identity-sensitive, hard to reverse, ADR-adjacent). Adds the Design Challenge and a fuller Excellence pass.
- **Owner-Decision** — changes long-term architecture or governance, or introduces a meaningful irreversible tradeoff. Act as the owner's **Technical Advisory Board (owner-ratified 2026-07-17)**: don't merely stop and request approval — explain *why* the decision exists, why it can't be objectively derived, whether it is reversible, and its assumptions; present *every realistic* option with a comparison across the axes that matter (architecture, operational model, scalability, implementation + operational complexity, maintainability, flexibility, vendor lock-in, migration cost, security, compliance, infrastructure, roadmap + ORVION fit); recommend one with evidence; and **teach the owner *how* to choose, not just what** — the goal is an informed decision, not a rubber stamp. Isolate the decision (design everything independent of it, per §1), await approval, record an ADR. Prepare the analysis as a Decision Record first (precedent: `reports/history/google-offline-conversion-transport-decision-2026-07-17.md`).
  - **Every proposal — including the owner's — is evaluated, never auto-accepted (owner-ratified 2026-07-17): the owner proposes, repository evidence decides.** Each concludes as exactly one of **Adopt Now / Adopt Later (explicit trigger) / Reject (with evidence)**, judged by Earn-It + repository evidence + One-Authority + Test-before-trust + Learn-Before-Designing + stewardship.
  - **Permanent Engineering Review Board.** Review every non-trivial implementation through multiple standing perspectives that challenge one another before concluding — Repository Steward, Chief/Enterprise/Solution/Domain/Software/Database/Data/Integration/Security architect, Governance Custodian, Technical Auditor, QA, Systems Analyst, Technical Product Owner, Risk/Compliance/DevOps reviewer, Documentation Steward, Long-Term Maintenance engineer. Governance remains the final authority. (This is the Excellence Check's multi-role lens, §3 step 6, widened to architectural roles — not a separate gate.)

**Workflow stages:**
1. **Phase-fit + Earn-It → classify tier.** ("Does this belong to the current phase, or am I solving a future problem?")
2. **Research when it materially helps (Learn-Before-Designing).** Use current external evidence as a lightweight Design Review tool whenever it would measurably improve a decision — validating a current best practice, evolving external-platform behaviour, an official spec, or an assumption before implementation. Scale it to the decision: a quick check for a routine choice touching a fast-moving external surface; for a *major* capability (UI, AI, communications, reporting, automation, analytics, search, integrations), a fuller study of the strongest current implementations — why they work, why users prefer them, where they fail, what to adopt vs deliberately avoid. Verify against up-to-date official sources (the ecosystem moves fast). When a fast-moving surface is in play — SDKs, APIs, AI tooling, cloud/infrastructure, external-platform behaviour — **prefer verifying current official information over relying on historical/stored knowledge**, because stored knowledge goes stale silently and a wrong assumption there is expensive. Goal: strengthen engineering judgment with evidence, not replace it — and not research every task.
3. **Design Review** — gather the minimum context, then confirm canonical fit: read *only* the relevant canonical docs and the *required* schema/migrations for this capability, and look for an existing precedent (an RPC or pattern already in the repo) to reuse rather than re-invent. Minimal, precedent-first reading is what keeps a capability both correct and cheap.
4. **Design Challenge** — *Significant only.* Objective: can we reasonably demonstrate the selected solution is the strongest practical solution among realistic alternatives? Adversarial sweep for what is MISSING or SIMPLER/BETTER (relationships, business concepts, catalog values, events, permissions, validations, integration points, hidden assumptions, simplification). Output = short findings list resolving to one of three engineering outcomes — reject, improve, or confirm the approach — then implement; a question to the owner is *not* an outcome, and is warranted only if the sweep surfaces a genuine architectural conflict (a stop condition). A full written report only at phase/gate boundaries.
5. **Implement + prove** — clean `db reset`, behavioral tests, smoke-test, Database Audit (for schema work).
5b. Cross-path impact sweep — mandatory when triggered; the full active rule is AGENTS.md §5b below.
6. **Review Gate + Excellence Check** — the CR Review Gate PLUS six questions: (a) anything overlooked? (b) simpler equivalent? (c) unnecessary complexity introduced? (d) reusable business concept emerged? (e) negligible-cost future-debt avoidance? (f) **multi-role usability** — reviewing not only as an architect but through the affected operational roles (sales, reservations, finance, accountant, call-center, support, marketing, operations, owner, plus the engineering roles): can each perform their workflow naturally? A capability no real role can use naturally is incomplete. In-phase improvement → implement; future → record at its trigger.
7. **Complete** — autonomous per §2 when verified and no new decision; sync manifest/ADR; commit; push.
8. **Phase-transition checkpoint** — execute a whole roadmap phase capability-by-capability without stopping, then pause at phase end with a concise checkpoint: what was completed, findings, deferred items + triggers, architectural health, next phase, recommendation, any observation deserving owner attention. Then begin the next phase.

Governance is self-revising: if a step stops earning its confidence, propose simplifying it; if a missing practice would raise quality without materially slowing execution, propose adding it. Reconsider methodology only on concrete repository evidence, never on preference alone.

## 4. Context routing and live state

This section is the **single authoritative boot sequence**; its executable entry is `-Boot`. If that command cannot run, use this recovery route only:

| Need | Authority |
| --- | --- |
| Current phase/task/active CR/next capability | `_ORVION_CANONICAL/manifest.md` |
| CR format, write scope, exact step/checkpoint | active `changes/SPEC-*.md` + `changes/TEMPLATE.md` |
| CR states/transitions/synchronization | `CR_LIFECYCLE.md` |
| Knowledge placement, reports, governance change | `GOVERNANCE.md` |
| Business/domain truth | `_ORVION_CANONICAL/00`–`23` task-specific only |
| Schema/database design truth | `_ORVION_CANONICAL/24`–`33`; as-built = `supabase/migrations/**` |
| Coding/SQL/security conventions | `CODING_STANDARDS.md` |
| Ratified decisions | `reports/architecture-decision-records.md` |
| Findings / deferred triggers | `reports/master/MASTER_GAP_REGISTER.md` / `reports/future-backlog.md` |
| Integration contracts/targets | `reports/master/MASTER_INTEGRATION_CATALOG.md` |
| File discovery | `repository-index.md` / generated `ai-map.json` |

Reality wins in this order: migrations + Git → Canon → living reports/prose. Fetch before work. If local and upstream diverge both ways, do not merge/rebase/reset automatically. Pre-existing out-of-scope dirt is a hard blocker; never stash, discard, or commit it.

The normal handoff is active CR + official Status + Runtime Checkpoint + exact Resume Step + Blocker + Git/live checks. It never depends on chat or a mandatory latest-session report. Read a session report only when Boot/Required Reading points to it or durable forensic/research/phase-boundary evidence is relevant.

## 5. Build and verify

Mandatory verification is derived from Write Scope and cannot be removed; `Additional Verification` can only add. Profiles are:

- **REPOSITORY:** every engineering CR; continuity Gate, repository consistency, relevant tests, `git diff --check`, scope and generated-artifact checks.
- **CONTROL:** agent/governance/CR-contract/control-script/hook changes; run `scripts/test_agent_continuity.ps1` and affected guard-of-the-guard suites.
- **CI:** workflow changes; validate syntax/range behavior and prove the remote run after push.
- **WORKSTATION:** bootstrap/doctor changes; prove setup idempotence and doctor detection.
- **DATABASE:** migration/schema/database-contract changes; the full §5a protocol below.

### 5a. Database verification compatibility anchor

For database work, do not narrow this protocol: fetch and verify target; clean `npx supabase db reset`; pgTAP Pass A; all relevant HTTP suites; pgTAP Pass B without reset; smoke via `docker exec -i supabase_db_ORVION psql -U postgres -d postgres -f - < scripts/verify_database.sql`; read Primary ledger, function hash, and `_combined` structure hash independently from Primary; run `scripts/check_database_parity.ps1`; run repository consistency; regenerate owned artifacts. Match counts and results, not remembered numbers. Primary for this repo is only ref `vrvtsxexkiiiivlkdxzp`; Secondary belongs to another repo and must never receive this repository's deployment. Confirm the target in `MASTER_INTEGRATION_CATALOG.md §0` before schema-changing/destructive calls.

### 5b. Cross-path impact compatibility anchor

When changing triggers, RLS, grants, SECURITY DEFINER functions, lifecycle/archive/catalog enforcement, events, immutable fields, scope, FK/key shape, permissions, vocabulary, columns, constraints, authorization helpers, or attribution structures, answer both: (1) which existing execution paths now meet the new rule, and (2) which code consumes/parses/derives from the changed structure. Use `scripts/impact.ps1 -Target <name>`. Classify interactive, multi-tenant system, batch/set-based, scheduled, integration, and administrative paths and prove each affected class. Restricted/ineligible tenants must be skipped by system paths without weakening the final gate; interactive callers must still receive intended errors.

## 6. Blocked recovery and decisions

A BLOCKED result starts bounded recovery, not automatic owner escalation:

```text
BLOCKED → DIAGNOSE → REFRESH EVIDENCE → ROOT-CAUSE HYPOTHESIS → PRECHECK → REPAIR → VERIFY → CERTIFY
```

Maximum three attempts for the same blocker. Attempt 1 uses immediate error/diff/nearby tests; Attempt 2 uses consumers/history/ADRs/Canon/analogues/broader runtime; Attempt 3 uses a different hypothesis plus targeted current official/upstream evidence where relevant. Never repeat the same repair with the same evidence. Runtime Checkpoint persists only Resume Step, stable Blocker code, and Recovery Attempt 0–3. After three distinct failures: `HARD_BLOCKED: RECOVERY_EXHAUSTED`.

Before `OWNER_DECISION_REQUIRED`, exhaust in order: Canon; ADRs; implementation; analogous ORVION code; tests/runtime; Git history; current authoritative external sources; established industry practice. If one answer follows from approved architecture, decide and continue. Escalate only business preference, commercial policy, legal/compliance acceptance, irreversible strategy, owner value judgment, or genuinely new architecture. Complete independent work first and report one exact question, why not derivable, evidence exhausted, real options, recommendation, reversibility, blocked step, and completed independent work.

After recovery ask whether the failure class recurs. If executable, add one guard/test; if architectural, use the ADR system; if domain truth, Canon; if operational, its existing procedure; if integration-specific, the integration authority. Do not add every lesson here.

### Measurement integrity — restored compatibility authority

- **No vacuous security tests (owner-ratified 2026-08-27).** *A test that can pass with zero affected rows is not an earned security test.* This has now bitten the repository twice: a denial assertion whose fixture was empty, and — during WP-03 — a proof-upload test that ran as `employee`, whose `insert … select … from public.subscriptions` read **zero rows** because `employee` lacks `VIEW_SUBSCRIPTION_STATUS`, so it inserted nothing and `lives_ok` reported success. Every authorization or security test must therefore, in order: establish the positive fixture; prove the actor genuinely **holds** the capability under test; prove the target row is **visible** where visibility is expected; perform the **positive** operation and assert it changed something; only then perform the negative operation; and assert the **exact** error code or a row count that could not have been produced by an empty query. When an assertion rests on `lives_ok`/`throws_ok` over an `INSERT … SELECT` or a filtered `UPDATE`, add a companion assertion that the row now exists (or the count changed) — "it did not throw" is not evidence that a write occurred.
- **A green guard proves only the property it actually measures.** Before quoting one, read what it reads. If a guard's description is stronger than its measurement, **fix the guard** — that is the finding, and it is recorded in the register as a first-class one, never as a footnote.
- **Attack every new detector with a counterexample before trusting it**, in both directions: construct a case it must flag and one it must not. A guard that can be satisfied without satisfying its invariant is the class the discovery-to-guard loop exists to eliminate. Prove enforcers by **defect injection** — inside a savepoint, drop the named enforcer, assert the violation *succeeds*, roll back, assert it is refused again (the **PAR-4** pattern in tests 70/72/73/76). "It did not throw" is not evidence that anything was enforced.
- **Static analysis is a lead, never a verdict.** It cannot see trigger arguments (**MEAS-1**), values assembled at runtime, RLS visibility, or whether a fixture row exists at all — a static pre-check reported "zero divergence" over ten impossible fixture rows (**TEST-65**). Prove fixtures valid by observing them, not by matching their shape.
- **Test both doors.** Where direct DML is reachable, an RPC-only check is a half-fix: `authenticated` holds table writes, so PostgREST exposes the table beside the RPC (**BOOK-1**, **ADMIN-1**, **FIN-8**, **FIN-10**, **QUO-1**). Prove positive and negative controls *independently* — verify the actor genuinely holds the capability and can see the row before asserting that anything was denied.
- **A failed run is not automatically a finding.** Distinguish infrastructure from product: Docker down, containers still restarting, or a probe running under the session a previous assertion left behind look identical to a real defect in a transcript, and each has already been mistaken for one. Establish which it is before recording anything.
- **No exemption is ever manufactured to make a guard pass**, and no budget is ever raised to make a document fit (Check 5 has been tripped repeatedly; the answer has always been to trim). Fix the subject, or record why the guard is right and the work is wrong.
- **Every discovered finding ends in exactly one declared state** — *FIXED and behaviourally verified* · *PROVEN INTENTIONAL* (or proven not a defect, by experiment rather than by inspection) · *UNPROVEN* · *OWNER DECISION REQUIRED* — and an owner decision is legitimate only after canon, the SSOT/register, schema, implementation, consumers, tests, runtime, Primary and authoritative external documentation have been exhausted **in that order**. Never silently abandon a finding, and never hide an open question to make a package look complete.
- **External credentials never pass through the agent.** A secret for a third-party system (a database role password, an OAuth client secret, an API key, a token) — Phase 8's `orvion_integration` password and n8n/Google OAuth client secret are the precedent — is entered by the owner directly into its destination (the database console, n8n's credential UI, the provider's own form), never into a prompt, tool call, file, or any other agent-visible surface. An agent must not generate, request, echo, or transit such a secret, even transiently in a tool call whose output only the agent sees. Concrete application of `CODING_STANDARDS.md §8`; verify by effect (a credential test passing, a query succeeding), never by inspecting the secret.

## 7. Governance and tooling boundaries

Governance changes follow `GOVERNANCE.md §15` and owner authorization. Protected Canon, ADR, frozen baselines, schema, business rules, credentials, and external production systems require their owning authority. Tools and client hooks are adapters only; repository scripts/contracts + Git + CI own correctness. Skills may help but are never mandatory for correctness. Do not create parallel authorities, nested `AGENTS.md`, RAG/vector databases, knowledge graphs, context daemons/watchers, or generic semantic/dependency engines without separate owner-approved architecture.

Reports are durable only when they own evidence not better represented in CR/Git/tests/Canon/ADR: forensic/audit work, substantial research, architectural decisions, phase/capability boundaries, or a failure investigation that cannot be encoded more strongly. Historical reports are immutable. Ordinary checkpoints do not require a new report.

Delegation is not default. Use the fewest non-overlapping specialists only when work is genuinely parallel, requires distinct expertise/evidence, and improves total quality/time; independently verify returned evidence. A task may forbid delegation.

## 8. Definition of done and maintenance

Done means approved scope implemented; exact acceptance criteria and Review Gate proven against live state; derived profiles pass; cross-path impact handled when triggered; repository and generated artifacts synchronized; CR Runtime Checkpoint `DONE`; no unresolved blocker; working tree clean; committed and normally pushed; relevant CI verified. Never call UNPROVEN a pass.

Token efficiency never authorizes semantic loss. Keep automatic bootstrap context as small as practical through routing and just-in-time reading, but never delete, weaken, or relocate an owner-ratified rule merely to satisfy a byte budget.

Put mechanics in their owning authority and keep compatibility anchors instead of rewriting immutable history. Every structural change must pass Earn-It and One Authority. The repository consistency guard must remain CLEAN; if it reveals drift, fix only within approved scope or report the blocker.
