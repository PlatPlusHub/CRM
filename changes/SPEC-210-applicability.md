# Change Request — SPEC-210

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Derive Pre-Approval evidence applicability **per predicate** instead of once per contract, extend the
contract-level trigger to the verification, generation and publication authorities that no profile
marks, and refuse **derived verification write closure** at Approval. `ENGINEERING_METHOD.md §2` and
`changes/TEMPLATE.md` are brought into agreement with the mechanism, and the control suite gains the
cases and mutation kills that prove it. One existing assertion whose title claims more than it
measures is retitled to claim only what it measures.

## Business Reason

Three of the last eight contracts were cancelled for defects in their own frozen text rather than for
falsified engineering, and two live defects in the evidence evaluator were reproduced against it before
this contract was written.

**Reproduced false positive.** `Evaluate-PreApprovalEvidence` derives applicability once — *did this
change reach a special surface* — and then asserts that single answer about three different questions.
A contract whose Write Scope is `AGENTS.md`, which has real consumers but adds no permanent control,
is refused `INDETERMINATE:Permanent-Control Admission declared not applicable while repository evidence
makes it applicable`. No repository evidence supports that sentence: none was ever consulted for that
predicate. The contract must then author nine obligations describing a control it is not adding, which
is not evidence and teaches that the section is a formality.

**Reproduced false negative, and the more serious one.** `scripts/parity_surface.sql` decides what the
structural parity detector *measures*. It is not a control path and derives no profile, so it is
invisible to the trigger. `SPEC-207` changed exactly that file, authored 68 lines of Pre-Approval
Evidence — 22% of its own text — and the Gate printed `APPROVAL_EVIDENCE: NOT APPLICABLE` without
reading one of them. The same hole covers `scripts/check_database_parity.ps1`,
`scripts/check_primary_ledger.ps1`, `scripts/check_database_parity_evidence.ps1`,
`scripts/publish_candidate.ps1`, `scripts/generate-*.ps1` and `ENGINEERING_METHOD.md` itself: every
verification, generation and publication authority in the repository, all reported NOT APPLICABLE.

**Reproduced write-closure class.** A mandatory verification that regenerates a tracked artifact and
byte-compares it makes that artifact part of the contract's write surface whether the contract planned
to touch it or not, because `Invoke-Verification` treats any non-zero exit as fatal and a frozen Write
Scope cannot be widened afterwards. `SPEC-203` carried `ai-map.json` but not
`reports/master/MASTER_API_CONTRACT.md`, **deployed to Primary**, and only then met mandatory Check L3;
the repair lay in a file its own frozen scope forbade, so an irreversible action had already happened
when it was cancelled. `SPEC-205` died to the same shape. The live evaluator **admits** that exact
Write Scope today; the change refuses it at Approval.

This reopens the control-plane chapter the manifest records as CLOSED, on newly earned evidence rather
than on a search for theoretical optimizations: two reproduced false results in the evaluator, and one
historical class reproduced against the live mechanism.

## Risks

**A widened trigger could force ceremony onto ordinary work.** Mitigated by measurement, not by
assertion: the new surfaces are read inside the evaluator only and never added to `Profiles`, so no
verification protocol changes, and a repository-only contract still derives `NOT APPLICABLE` (case 228).

**Relaxing `Permanent-Control Admission` could open a self-exemption door.** It cannot: a contract may
omit or decline the subsection only where the repository does not derive it, and declaring `APPLICABLE`
where the repository is silent binds fully. Both directions are proven (224, 225, 227).

**The evaluator is replayed over this contract's own Approve commit** by `Validate-CommittedRange` at
every later Gate, so the text frozen under the old rules must also satisfy the new ones. Verified
against both evaluators before this contract was frozen, and re-proved by Step 6.

**A write-closure rule could fire on a retired artifact.** It is skipped when the artifact does not
exist (case 231), so retiring a generator needs no edit here.

## Supersedes / Depends On

Depends on `SPEC-196`, `SPEC-198` and `SPEC-202`, whose evidence mechanism this refines. Supersedes
nothing. `SPEC-209` is not available: `SPEC-208`'s Execution Log records a refusal by quoting the
string `SPEC-209`, which reserves that identity permanently.

## Write Scope

- `changes/SPEC-210-applicability.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `changes/TEMPLATE.md`
- `ENGINEERING_METHOD.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `CR_LIFECYCLE.md` — §5 states that applicability is derived from repository evidence rather than from
  `Change Class`. That remains exactly true under per-predicate derivation, so it is verified, not
  written.
- `AGENTS.md` — no governance rule changes. Disposable pre-freeze rehearsal was examined against §9 and
  found already legal, because every byte written during rehearsal is written under a contract that
  holds its own Write Scope. An exception was not earned and is not taken.
- `GOVERNANCE.md`, `README.md`, `llms.txt`, `CLAUDE.md`, `GEMINI.md` — no consumer of theirs changes.
- `scripts/check_repository_consistency.ps1` — Checks 7 and L3 are the authorities this contract reads;
  it does not modify them, and re-implementing either would create a second authority.
- `scripts/check_database_parity.ps1`, `scripts/parity_surface.sql`, `scripts/check_primary_ledger.ps1`,
  `scripts/check_database_parity_evidence.ps1` — newly covered by the evidence trigger, unchanged by it.
- `supabase/**` — no migration, no test, no configuration. No database change is expected or made.
- `reports/master/MASTER_API_CONTRACT.md` — no `supabase/migrations/` path is in scope, so Check L3's
  closure does not bind and regenerating it would be an unrequested write.

## Required Reading

- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `changes/SPEC-203-membership-authority-and-audit.md`
- `changes/SPEC-207-grant-parity-ownership-boundary.md`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- `pwsh -NoProfile -File scripts/generate-ai-map.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Derived Applicability

| Predicate | Repository-derived fact | Result |
| --- | --- | --- |
| Consumer Closure | `scripts/check_agent_continuity.ps1`, `scripts/test_agent_continuity.ps1` and `changes/TEMPLATE.md` are control surfaces; profile CONTROL is derived. | APPLICABLE |
| Execution-Boundary Satisfiability | The contract changes a gate that judges its own later commits, so ordering is load-bearing. | APPLICABLE |
| Permanent-Control Admission | Write Scope reaches `scripts/check_*` and `scripts/test_*`; the change adds two permanently enforced evaluator predicates. | APPLICABLE |
| SPEC Allocation | `SPEC-210` is the next free identity; cursor 208, `SPEC-209` reserved in tree. | APPLICABLE |

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Applicability becomes per predicate | `changes/TEMPLATE.md` | WRITE | The template stops requiring a hand-copied restatement of a derivation and states when a subsection may be omitted. |
| Applicability becomes per predicate | `ENGINEERING_METHOD.md` §2 | WRITE | §2 already says "where deterministically applicable"; the amendment records that this is a statement about each class. |
| Applicability becomes per predicate | `CR_LIFECYCLE.md` §5 | UNAFFECTED | §5 says applicability is derived from repository evidence rather than `Change Class`, which stays exactly true per predicate. Verified by reading it; no edit. |
| The evidence trigger covers authority surfaces | `Profiles` / `Get-ProfileEvidence` | UNAFFECTED | The surfaces are read inside the evaluator only. No profile is added, so no verification protocol changes and `.github/workflows/migration-ci.yml` keeps agreeing with `Profiles`. |
| Derived write closure at Approval | `scripts/check_repository_consistency.ps1` Check 7, `scripts/check_database_parity.ps1` Check L3 | VERIFY | Both remain the sole authorities for freshness; the evaluator asserts only that their regenerated artifact is inside Write Scope. Neither is modified. |
| Two new evaluator predicates | `scripts/test_agent_continuity.ps1` | WRITE | Thirteen cases and two mutation kills added; the three mutation entries whose target lines this contract rewrites are retargeted. |
| `Derived Applicability` rows compared to derivation | contracts already Complete | UNAFFECTED | Terminal contracts are immutable and the evaluator fires only on a `Draft -> Approved` commit inside a validated range; every such commit is already behind `origin/main`. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The control suite passes | BEFORE_COMPLETION | Step 1 | Step 4 | Step 5 |
| This contract's own Approve commit is admissible under the new evaluator | BEFORE_COMPLETION | NONE | NONE | Step 6 |
| `ai-map.json` agrees with the manifest | BEFORE_COMPLETION | Step 6 | Step 6 | Step 6 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `Evaluate-PreApprovalEvidence` already derives applicability, and is the correct
place for this. It cannot express the property as written, because it derives one boolean and applies
it to three predicates; and it has no notion of an artifact a verification regenerates. Extending it is
strictly preferred to a second evaluator, so no new authority is created and no algorithm is duplicated.

Added Property: (1) each evidence predicate derives its own applicability, so an obligation the
repository cannot justify is not imposed and one it can justify is not skipped; (2) a tracked artifact
that a mandatory verification regenerates and byte-compares must be inside Write Scope before Approval
freezes it.

Causal Negative: Both reproduced against the live evaluator before this contract was written. The
`AGENTS.md` contract is refused for honestly declining `Permanent-Control Admission`; the
`scripts/parity_surface.sql` contract reports `NOT APPLICABLE` with a complete evidence section it
never reads; and `SPEC-203`'s exact Write Scope — migrations plus `ai-map.json`, without
`MASTER_API_CONTRACT.md` — is **admitted** today.

Positive Test Design: a governance-prose contract omitting `Permanent-Control Admission` is ADMITTED
(221); a detector-surface contract with complete evidence is ADMITTED (226); a repository-only contract
still reports `NOT APPLICABLE` (228); naming the regenerated artifact is admitted (230); a closure whose
artifact does not exist is not asserted (231).

Negative Test Design: omitting `Permanent-Control Admission` on a permanent-control surface is refused
(224); self-declaring it not applicable there is refused (225); a volunteered predicate binds fully
(227); `UNKNOWN` consumer disposition is still refused with the subsection omitted (222) and on a
detector surface (223); the regenerated artifact missing from Write Scope is refused (229, 232); a
contract that derives `NOT APPLICABLE` is still held to its write closure (233).

Non-Empty Population Obligation: families `D`, `F`, `HJ`, `APPLIC` and the new `WC` must each record at
least one accepting case, one rejecting case and one mutation kill; the suite fails on an unpopulated
family.

Mutation Obligation: each independently killed on a scenario only it can refuse — the
`Permanent-Control Admission` derivation (`Test-PermanentControlPath` over Write Scope), and the write
closure membership test. The three existing kills whose target lines this contract rewrites are
retargeted to the new lines and must keep killing.

Post-Implementation Proof Obligation: the full control suite passes with every new case and every
mutation kill, and `-Finish` certifies with `Validate-CommittedRange` replaying this contract's own
Approve commit through the new evaluator.

### SPEC Identity Allocation

Applicability: APPLICABLE

`SPEC-210` is derived, not chosen: the allocation cursor on `origin/main` is 208 and `SPEC-209` returns
reservation `tree`, because `SPEC-208`'s Execution Log records the refusal `SPEC_ID_NOT_NEXT:208:209`
and that mention reserves the identity permanently. 210 is the next free identity.

## Implementation Steps

1. Verification check: `scripts/check_agent_continuity.ps1` contains `function Test-PermanentControlPath`.
   If absent, add `Test-PermanentControlPath`, `Test-EvidenceAuthorityPath` and
   `$script:EvidenceWriteClosure` immediately above `Evaluate-PreApprovalEvidence`, and record in the
   header comment both reproduced directions and the reason these surfaces are read here rather than in
   `Profiles`. Change nothing else in the file.
2. Verification check: `Evaluate-PreApprovalEvidence` contains `$script:EvidenceWriteClosure`. If absent,
   evaluate write closure on Write Scope alone, before applicability, skipping any rule whose artifact
   does not exist; replace the inline control/Edge-Function loop with `Test-EvidenceAuthorityPath`.
3. Verification check: `Evaluate-PreApprovalEvidence` contains `$due=@{}`. If absent, derive the three
   predicates independently, require a subsection only where derived applicable, honour a declared
   `APPLICABLE` as a volunteered obligation, compare `Derived Applicability` rows against the derivation
   instead of demanding `APPLICABLE` throughout, and guard each body check with its own `$due` entry.
4. Verification check: `scripts/test_agent_continuity.ps1` contains `Assert '221 APPLICABILITY`. If
   absent, add the script-level fixtures `EvidenceNoHJ` and `ClosureSetup`, cases 221–233, the two new
   mutation entries, and retarget the three mutation entries whose target lines Steps 1–3 rewrote.
   In the same file, retitle assertion 103 so it claims ORCHESTRATION — `-Finish` runs the protocol in
   order and certifies when every command exits 0 — rather than that the real protocol can succeed,
   which it does not measure because the commands are fixtures. Change no assertion's condition.
   Add `WC` to the hardcoded family list of the NON-EMPTY POPULATIONS guard; without it the new
   family's counts are recorded and never asserted, which is the vacuous population that guard exists
   to refuse.
5. Verification check: the control suite reports `0 failed`. Run
   `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` and record the counts and exit code.
6. Verification check: `changes/TEMPLATE.md` contains `Omit this subsection otherwise`. If absent, remove
   the `### Derived Applicability` table and the `### SPEC Identity Allocation` subsection, state when
   `### Permanent-Control Admission` may be omitted, and amend `ENGINEERING_METHOD.md` §2 with
   per-predicate derivation and derived write closure and §3 with the stubbed-command and
   measure-before-freezing rules. Then record the closure in `reports/master/MASTER_GAP_REGISTER.md`,
   update `_ORVION_CANONICAL/manifest.md`, run `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, and
   prove `-Gate -BaseRef origin/main` replays this contract's own Approve commit through the new
   evaluator without refusing it.

## Acceptance Criteria

- [ ] `Evaluate-PreApprovalEvidence` derives `Consumer Closure`, `Execution-Boundary Satisfiability` and
      `Permanent-Control Admission` independently, and requires a subsection only where derived applicable.
- [ ] A contract whose Write Scope reaches an authority surface — `scripts/parity_surface.sql` is the
      recorded case — no longer reports `APPROVAL_EVIDENCE: NOT APPLICABLE`.
- [ ] A contract that declares a predicate `NOT APPLICABLE` where the repository derives it applicable is
      still `INDETERMINATE`, and a volunteered predicate is held to the full obligation.
- [ ] A tracked artifact a mandatory verification regenerates and byte-compares is refused at Approval
      when absent from Write Scope, is admitted when named, and is not asserted when the artifact does
      not exist.
- [ ] A repository-only reversible contract still reports `APPROVAL_EVIDENCE: NOT APPLICABLE` and needs
      no evidence section.
- [ ] `scripts/test_agent_continuity.ps1` reports `0 failed`, with every family populated and both new
      predicates independently mutation-killed.
- [ ] `changes/TEMPLATE.md` no longer contains `### Derived Applicability` or `### SPEC Identity
      Allocation`, and `ENGINEERING_METHOD.md` §2 and §3 record the rules this contract implements.
- [ ] Assertion 103's title claims orchestration rather than real-protocol reachability, and no
      assertion's condition is changed by this contract.
- [ ] No file outside Write Scope is modified; `supabase/` is untouched and no Supabase project is
      contacted.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Confirmed Complete — the frozen Objective is met with nothing missing, contradictory, unrequested
      or duplicated, no existing invariant is weakened, and no second authority was created.
