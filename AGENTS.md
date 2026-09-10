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

**Legacy §6 compatibility:** older live code/tests cite this section for the same enduring boundaries: credentials never pass through the agent, static analysis/comments are leads rather than proof, and security/denial tests require positive controls so empty or invisible fixtures cannot pass vacuously. Those rules remain owned by §1–§2 above.

## 7. Governance and tooling boundaries

Governance changes follow `GOVERNANCE.md §15` and owner authorization. Protected Canon, ADR, frozen baselines, schema, business rules, credentials, and external production systems require their owning authority. Tools and client hooks are adapters only; repository scripts/contracts + Git + CI own correctness. Skills may help but are never mandatory for correctness. Do not create parallel authorities, nested `AGENTS.md`, RAG/vector databases, knowledge graphs, context daemons/watchers, or generic semantic/dependency engines without separate owner-approved architecture.

Reports are durable only when they own evidence not better represented in CR/Git/tests/Canon/ADR: forensic/audit work, substantial research, architectural decisions, phase/capability boundaries, or a failure investigation that cannot be encoded more strongly. Historical reports are immutable. Ordinary checkpoints do not require a new report.

Delegation is not default. Use the fewest non-overlapping specialists only when work is genuinely parallel, requires distinct expertise/evidence, and improves total quality/time; independently verify returned evidence. A task may forbid delegation.

## 8. Definition of done and maintenance

Done means approved scope implemented; exact acceptance criteria and Review Gate proven against live state; derived profiles pass; cross-path impact handled when triggered; repository and generated artifacts synchronized; CR Runtime Checkpoint `DONE`; no unresolved blocker; working tree clean; committed and normally pushed; relevant CI verified. Never call UNPROVEN a pass.

Maintain this kernel below 16 KiB. Put mechanics in their owning authority and keep compatibility anchors instead of rewriting immutable history. Every structural change must pass Earn-It and One Authority. The repository consistency guard must remain CLEAN; if it reveals drift, fix only within approved scope or report the blocker.
