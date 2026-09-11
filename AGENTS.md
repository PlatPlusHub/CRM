# AGENTS.md — ORVION Operating Kernel

This is the universal, client-neutral operating kernel for every ORVION engineering session. It is intentionally small. `scripts/check_agent_continuity.ps1` derives task/runtime state; the linked authorities own detail.

**Precedence.** A live owner instruction wins. Otherwise this file governs execution posture, `CR_LIFECYCLE.md` governs Change Requests, `GOVERNANCE.md` governs knowledge placement, Canon governs business/domain truth, and migrations + Git are as-built truth. `PROTOCOL.md` and `global-rules.md` are retired pointers.

## 1. Execution boundary and stop conditions

Repository READ/search access is unrestricted. CREATE/MODIFY/DELETE authority exists only in an Approved or In-Progress CR's exact `Write Scope`; Required Reading never grants write authority. In PLAN, read, search, research, diagnose, and draft a proposed CR, but do not mutate implementation. Official CR statuses remain exactly Draft, Approved, In Progress, Complete, Cancelled. PLAN, EXECUTE, VERIFY, BLOCKED and CERTIFY are runtime activities/verdicts, never statuses. Only an Approved or In-Progress CR may be the manifest's active pointer, and a Draft named as active is a rejected contradiction, not a mode.

Execution is the default inside approved scope. Do not pause for routine Git, tests, commits, synchronization, or objectively derivable implementation choices. Stop only for:

1. a genuine owner-only business/legal/commercial preference or new irreversible architecture direction after Decision Exhaustion;
2. an unresolved canonical contradiction;
3. a material unexpected blocker outside bounded recovery;
4. a destructive/irreversible action outside the approved workflow;
5. unauthorized write scope, Git divergence, technical impossibility, or exhausted recovery.

Never invent policy, expose/request secrets, force-push, use `--no-verify`, rewrite history, weaken a guard, widen scope to hide a failure, or touch unrelated user work. Before a destructive action resolve the exact target and prove it is authorized. Credentials remain external to Git; repository configuration may name environment-variable handles, never values.

**The capability is the unit of progress.** The roadmap is organized around approved business capabilities; a Change Request (SPEC) is one engineering step delivering one. When a capability is best delivered as several small SPECs, continue through them as one flow — do not treat each SPEC as a fresh decision point. Drive the capability to a coherent, verified completion.

**Standing execution directive (owner-ratified 2026-07-17): finish → audit → classify → execute.** No new unit begins until the current one is complete on every axis; each major unit opens with a Critical Architecture Audit; every decision is classified immediately as technical (decide and continue) or business-policy (present options and wait); the active unit keeps priority. Full ratified text: `ENGINEERING_METHOD.md §1 "Standing execution directive"` — read it when starting any unit of work.

## 2. Permanent principles

- **One Authority:** one fact has one owning location; other files point to it. See `GOVERNANCE.md §2`.
- **Earn-It:** every process, file, abstraction, tool, and permanent rule must measurably increase confidence; prefer the simpler equivalent.
- **Test Before Trust / No Guessing:** a claim is PROVEN only by an observed relevant check. Otherwise mark UNPROVEN, FAILED, or BLOCKED. Guard success proves only that guard's declared evidence class.
- **Anti-entropy:** leave touched surfaces simpler, synchronized, deterministic, and harder to misuse; never turn this into unrelated cleanup.
- **Implementation autonomy:** choose the strongest practical reversible option already implied by Canon, ADRs, implementation, tests, Git, and current official evidence.
- **Owner boundary:** never invent business policy, legal/compliance risk acceptance, commercial preference, or a genuinely new strategic architecture direction.
- **Repository memory:** chat is not state. Persist durable truth in its existing authority; reusable executable failure classes become guards/tests.

The active capability must finish on every relevant axis before another begins: implement, verify, Review-Gate, synchronize, commit, push, clean tree, no known in-unit debt. A checkpoint records progress; it is not a routine permission pause.

**Durable checkpoint test (owner-ratified continuity authority, restored 2026-09-11).** A meaningful engineering boundary is not checkpointed until the repository itself can carry it forward. Apply one question: *if this agent disappears permanently right now, can a completely fresh agent resume correctly from repository evidence alone?* If not, synchronize the Runtime Checkpoint to the exact next step, append the Execution Log entry, and commit the coherent boundary before stopping. Compact semantic state plus a durable Git checkpoint is the whole mechanism — this never requires a session report, and a knowingly inconsistent half-migration is never committed merely because a session is ending.

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

### Decision and architecture discipline

Owned by `ENGINEERING_METHOD.md §2 "Decision and architecture discipline"`: the Earn-It meta-principle, Fundamental Domain Structure vs Feature Implementation, the Routine / Significant / Owner-Decision tiers with the Technical Advisory Board and Engineering Review Board, independent evaluation of every proposal including the owner's, and the eight workflow stages from phase-fit through Learn-Before-Designing, Design Review, Design Challenge, Excellence Check and the phase-transition checkpoint.

Read it when classifying a capability or making an architectural or owner-facing decision. Routine execution inside an approved contract does not need it. Nothing was weakened in the move — Check 27 of `scripts/check_repository_consistency.ps1` fails if any of those rules stops existing there.

## 4. Context routing and live state

This section is the **single authoritative boot sequence**; its executable entry is `-Boot`. If that command cannot run, use this recovery route only:

| Need | Authority |
| --- | --- |
| Current phase/task/active CR/next capability | `_ORVION_CANONICAL/manifest.md` |
| CR format, write scope, exact step/checkpoint | active `changes/SPEC-*.md` + `changes/TEMPLATE.md` |
| CR states/transitions/synchronization | `CR_LIFECYCLE.md` |
| Decision tiers, design method, measurement integrity, DB + cross-path protocols | `ENGINEERING_METHOD.md` |
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

### 5a. Database verification protocol

Owned by `ENGINEERING_METHOD.md §4 "Database verification protocol"`, unchanged and never narrowed. Read it when the `DATABASE` profile applies; `-Finish` also prints its commands in execution order as `LOCAL_NOT_EXECUTED` evidence and withholds `LOCAL_CERTIFY: READY` until they are run.

### 5b. Cross-path impact protocol

Owned by `ENGINEERING_METHOD.md §5 "Cross-path impact protocol"`, with the full trigger list. Read it when changing triggers, RLS, grants, SECURITY DEFINER functions, lifecycle/archive/catalog enforcement, events, immutable fields, scope, FK/key shape, permissions, vocabulary, columns, constraints, authorization helpers, or attribution structures.

## 6. Blocked recovery and decisions

A BLOCKED result starts bounded recovery, not automatic owner escalation:

```text
BLOCKED → DIAGNOSE → REFRESH EVIDENCE → ROOT-CAUSE HYPOTHESIS → PRECHECK → REPAIR → VERIFY → CERTIFY
```

Maximum three attempts for the same blocker. Attempt 1 uses immediate error/diff/nearby tests; Attempt 2 uses consumers/history/ADRs/Canon/analogues/broader runtime; Attempt 3 uses a different hypothesis plus targeted current official/upstream evidence where relevant. Never repeat the same repair with the same evidence. Runtime Checkpoint persists only Resume Step, stable Blocker code, and Recovery Attempt 0–3. After three distinct failures: `HARD_BLOCKED: RECOVERY_EXHAUSTED`.

Before `OWNER_DECISION_REQUIRED`, exhaust in order: Canon; ADRs; implementation; analogous ORVION code; tests/runtime; Git history; current authoritative external sources; established industry practice. If one answer follows from approved architecture, decide and continue. Escalate only business preference, commercial policy, legal/compliance acceptance, irreversible strategy, owner value judgment, or genuinely new architecture. Complete independent work first and report one exact question, why not derivable, evidence exhausted, real options, recommendation, reversibility, blocked step, and completed independent work.

After recovery ask whether the failure class recurs. If executable, add one guard/test; if architectural, use the ADR system; if domain truth, Canon; if operational, its existing procedure; if integration-specific, the integration authority. Do not add every lesson here.

### Measurement integrity

Owned by `ENGINEERING_METHOD.md §3 "Measurement integrity"`: no vacuous security tests, a green guard proving only what it measures, attacking every new detector with a counterexample in both directions and proving enforcers by defect injection, static analysis as a lead rather than a verdict, testing both doors, distinguishing an infrastructure failure from a finding, never manufacturing an exemption or raising a budget to fit, the four declared states every finding must reach, and external credentials never passing through the agent.

Read it before writing or quoting any test, guard, or measurement. The kernel keeps the principle it rests on — Test Before Trust, §2 — and the detail lives with the method.

## 7. Governance and tooling boundaries

Governance changes follow `GOVERNANCE.md §15` and owner authorization. Protected Canon, ADR, frozen baselines, schema, business rules, credentials, and external production systems require their owning authority. Tools and client hooks are adapters only; repository scripts/contracts + Git + CI own correctness. Skills may help but are never mandatory for correctness. Do not create parallel authorities, nested `AGENTS.md`, RAG/vector databases, knowledge graphs, context daemons/watchers, or generic semantic/dependency engines without separate owner-approved architecture.

Reports are durable only when they own evidence not better represented in CR/Git/tests/Canon/ADR: forensic/audit work, substantial research, architectural decisions, phase/capability boundaries, or a failure investigation that cannot be encoded more strongly. Historical reports are immutable. Ordinary checkpoints do not require a new report.

**HANDOFF rule (owner-ratified 2026-09-05, authority restored 2026-09-11).** When a session report *is* written, it opens with a HANDOFF block carrying all seven fields — INHERITED · PROVEN · UNPROVEN · CHANGED · REMAINING · DO NOT TOUCH · NEXT — so a fresh session with no conversational memory inherits from the repository rather than from chat. Check 23 of `scripts/check_repository_consistency.ps1` enforces this forward-only; history is immutable and is never retrofitted. This rule was enforced by that check while this statement of it was absent, which is the defect class a guard must never be left in.

Delegation is not default and must earn its cost. Use the fewest non-overlapping specialists, only when work is genuinely parallel, requires distinct expertise/evidence, and improves total quality/time; choose the smallest model capable of the required quality; independently verify returned evidence rather than trusting the report that accompanies it; the governing agent retains final responsibility for everything it accepts. A task may forbid delegation.

## 8. Definition of done and maintenance

Done means approved scope implemented; exact acceptance criteria and Review Gate proven against live state; derived profiles pass; cross-path impact handled when triggered; repository and generated artifacts synchronized; CR Runtime Checkpoint `DONE`; no unresolved blocker; working tree clean; committed and normally pushed; relevant CI verified. Never call UNPROVEN a pass.

Token efficiency never authorizes semantic loss. Keep automatic bootstrap context as small as practical through routing and just-in-time reading, but never delete, weaken, or relocate an owner-ratified rule merely to satisfy a byte budget.

Put mechanics in their owning authority and keep compatibility anchors instead of rewriting immutable history. Every structural change must pass Earn-It and One Authority. The repository consistency guard must remain CLEAN; if it reveals drift, fix only within approved scope or report the blocker.
