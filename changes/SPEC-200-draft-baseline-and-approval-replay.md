# Change Request — SPEC-200

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the committed-range evaluator judge a Change Request's authority from the point it was actually approved: stop treating a `Draft` at the range base as frozen authority, and replay the Pre-Approval evidence on the exact commit that performs `Draft -> Approved` even when that commit is not the range endpoint.

## Business Reason

Two defects in one block of `scripts/check_agent_continuity.ps1`, both reproduced against unmodified `90558c9`, and between them they made a legal capability unpublishable while leaving a real Approval bypass open.

**CTRL-2A — a `Draft` at the range base is treated as frozen authority.** When the governing contract exists at the base, the endpoint block runs `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly` and both `Validate-Checklist` calls against that snapshot. It computes `$baselineStatus` on the line above and never consults it. `CR_LIFECYCLE.md` §8 freezes those sections *after approval*, and `Validate-CommittedRange` already implements exactly that rule a few hundred lines earlier — "Authority freezes at APPROVAL, not at a contract's first appearance. A Draft exists precisely to be revised." So the same file disagrees with itself, and the endpoint site contradicts its own comment, which says the baseline is "the authority that was **approved**". Reproduced: `SPEC-197` was published as a `Draft` inside `SPEC-198`'s range, legally hardened before its own Approval, and its range was then refused `FROZEN_AUTHORITY_MUTATED: Pre-Approval Evidence` — permanently, for any range based at `90558c9`. Gating that block on the base status turns the identical range into `ORVION: READY`, exit 0.

**CTRL-2B — an Approval that happens mid-range is never evidence-checked.** `Evaluate-PreApprovalEvidence` is invoked from one site, keyed on the range's *endpoint* status: `$baselineStatus -eq 'Draft' -and $c.Status -eq 'Approved'`. A push that carries `Approve` and `In Progress` together — the ordinary shape — ends at `In Progress`, so the condition is false and the evidence is never read. Proved with a discriminating pair, three times: the same Approval commit with `UNKNOWN` consumer disposition, with a named unresolved consumer, and with a gate inside its own red window is refused `APPROVAL_EVIDENCE: INDETERMINATE`/`FAIL` when the range ends at `Approved`, and admitted `ORVION: READY`, exit 0 when the range continues one commit further. `SPEC-196` exists to make Approval admissible only on sufficient evidence; on the normal push shape, CI never checks it.

## Risks

- **Weakening a real protection while fixing a false one.** The repair must leave every post-Approval freeze intact. It is bounded by asserting the existing protections still fire from a non-`Draft` baseline, and by mutation-killing each new condition independently.
- **The replay could judge the wrong state.** Evidence must be read from the contract *as it stood at the approving commit*, not from the endpoint, or a later legal edit would change a historical verdict. The design parses that commit's own text and derives applicability from that commit's own Write Scope.
- **Parsing a historical contract with the current schema.** `Contract` enforces the canonical section set, and `CR_LIFECYCLE.md` §4 already states why that is safe — terminal contracts are never reopened and only the governing contract is parsed — but the replay reaches a commit rather than a file. Bounded: the replay parses only the governing contract, only at commits inside the range being judged, and a parse failure there is a refusal rather than a silent skip.
- **Not repairing leaves both halves live**: a legal capability cannot be published at all, and every ordinary push obtains Approval authority on evidence nothing read.
- This contract changes no product behaviour, no database object and no workflow.

## Supersedes / Depends On

None. `changes/SPEC-197-membership-authority-and-audit.md` is terminal `Cancelled` and is **not** superseded by this contract: its Slice-12 objective is untouched here and returns as its own legally allocated successor. That file is carried in Write Scope for range publishability only — the net diff of the publishable range contains its cancellation commit — and this contract must not modify it.

## Write Scope

- `changes/SPEC-200-draft-baseline-and-approval-replay.md`
- `changes/SPEC-197-membership-authority-and-audit.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `changes/TEMPLATE.md`
- `changes/SPEC-196-pre-approval-evidence-sufficiency.md`
- `changes/SPEC-198-preapproval-applicability-derivation.md`
- `scripts/check_repository_consistency.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/generate-ai-map.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`

## Required Reading

- `CR_LIFECYCLE.md` §4, §5 and §8 — the transition matrix, Approval admissibility, and what synchronization may and may not change
- `changes/SPEC-196-pre-approval-evidence-sufficiency.md` — its frozen Step E, which scopes evaluation to "actual Draft-to-Approved transitions"
- `changes/SPEC-198-preapproval-applicability-derivation.md` — the applicability derivation this contract reuses unchanged
- `scripts/check_agent_continuity.ps1` — the endpoint block, `Validate-CommittedRange`, `Contract`, `Evaluate-PreApprovalEvidence`
- `scripts/test_agent_continuity.ps1` — case 111 (a contract born and completed inside one range) and the `ApproveRun` / `EvidenceText` helpers

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Significant

### Derived Applicability

| Predicate | Repository-derived fact | Result |
| --- | --- | --- |
| Consumer Closure | Write Scope changes `scripts/check_agent_continuity.ps1`, the executable Gate used by the pre-commit hook, CI and publication; derived profile includes `CONTROL`. | APPLICABLE |
| Execution-Boundary Satisfiability | The change opens a required-red window in the control suite between its RED fixtures and the repair, with a mandatory `-Finish` CONTROL profile after it. | APPLICABLE |
| Permanent-Control Admission | The change alters when frozen-authority comparisons apply and adds a new mandatory evidence replay inside range validation. | APPLICABLE |
| SPEC Allocation | A new Change Request identity is an allocation event regardless of declared Change Class. | APPLICABLE |

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The endpoint frozen-comparison block becomes conditional on the base status | `scripts/test_agent_continuity.ps1` frozen-authority, append-only and checklist cases | WRITE | Those cases drive a non-`Draft` baseline and are unaffected by construction; Step 5 pins that they still fire, and a mutation proves the gate is load-bearing rather than always-true |
| The endpoint frozen-comparison block becomes conditional | `changes/SPEC-197-membership-authority-and-audit.md`'s already-committed range | VERIFY | The reproduction that motivated this contract; its range is re-run after the repair and must pass for the stated reason, not by accident |
| A new Pre-Approval replay inside `Validate-CommittedRange` | `.github/workflows/agent-control.yml` and `orvion-acceptance.yml`, which run the range Gate | VERIFY | Both invoke the same evaluator and gain the check automatically; neither workflow file is edited, and measured: neither encodes any evidence predicate of its own |
| A new Pre-Approval replay inside `Validate-CommittedRange` | every future push whose range contains a `Draft -> Approved` commit | VERIFY | Intended effect. A range whose Approval carries insufficient evidence is now refused where it was previously admitted; no existing published range is re-judged, because ranges are evaluated at push time and terminal history is never retrofitted |
| `Contract` split into a text-parsing core and a path wrapper | every existing caller of `Contract` | VERIFY | Pure refactor with no behaviour change at the path call sites; the whole control suite is the regression proof, and the split exists only so the replay can parse a commit's own text without a second parser |
| `changes/SPEC-197-...md` appears in the publishable range's net diff | the endpoint Write Scope check, and `scripts/publish_candidate.ps1` which gates on it | WRITE | Carried in Write Scope for publishability exactly as `SPEC-198` carried `SPEC-197`; an Acceptance Criterion pins that this contract changes not one byte of it after its cancellation commit |
| Manifest `Last Completed` / `Next capability` | `_ORVION_CANONICAL/manifest.md`, `ai-map.json` | WRITE | Both in Write Scope; Check 7 compares the three live_state fields by value, and Check 5's character budget is re-measured rather than assumed |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE — this is a repository-only control change that performs no irreversible external action, so `BEFORE_IRREVERSIBLE_ACTION` and `AFTER_IRREVERSIBLE_ACTION` do not arise.

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The control suite passes with zero failures | BEFORE_COMPLETION | Step 1 | Step 5 | Step 6 |
| Check 5 — `_ORVION_CANONICAL/manifest.md` inside its 7000-character budget | BEFORE_COMPLETION | NONE | NONE | NONE |
| Check 7 — `ai-map.json` live_state equals the manifest by value | BEFORE_COMPLETION | Step 7 | Step 7 | NONE |
| A fresh local certification receipt matches the Write Scope fingerprint | BEFORE_COMPLETION | NONE | NONE | NONE |

The RED fixtures of Step 1 are run and left **uncommitted**, so the red window never crosses a commit boundary and no Gate observes a deliberately failing suite.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `Evaluate-PreApprovalEvidence` already decides evidence sufficiency and is reused unchanged — this contract changes only *when* it is invoked. `Validate-CommittedRange` already walks every commit against its first parent and already reads the governing contract's text at each one, so the replay needs no new traversal. `Contract` already parses a contract; it is split into a text core and a path wrapper so the walk can parse a commit's own bytes rather than a working-tree file. No second evaluator, policy engine, registry, dependency graph or workflow is added.

Added Property: that the authority a range is judged against is the authority as it stood **when the contract was approved** — so a `Draft` at the base is not mistaken for frozen authority, and an Approval performed at an intermediate commit is judged by the same evidence rules as one performed at the endpoint.

Causal Negative: both halves reproduced against unmodified `90558c9`. CTRL-2A: `publish_candidate.ps1` on `90558c9..c954aaa` → `FROZEN_AUTHORITY_MUTATED: Pre-Approval Evidence`, nothing pushed; gating the block on the base status turns the identical range green. CTRL-2B: with the base `Draft` carrying the *same* invalid evidence so nothing mutates, a range ending at `Approved` is refused `APPROVAL_EVIDENCE: INDETERMINATE:UNKNOWN consumer disposition`, while the same Approval followed by one `In Progress` commit is admitted `ORVION: READY`, exit 0.

Positive Test Design: a contract legally revised while a `Draft` at the range base publishes; a range whose intermediate Approval carries valid evidence is admitted; every existing frozen-authority, append-only, acceptance-text and review-gate refusal still fires from a non-`Draft` baseline; case 111's born-and-completed-in-one-range history stays legal.

Negative Test Design: a range whose intermediate `Draft -> Approved` commit carries an `UNKNOWN` consumer disposition, a named unresolved material consumer, or a mandatory gate inside its own red window is refused with the evidence code, not with a frozen-authority code; a post-Approval mutation of any frozen section is still refused.

Non-Empty Population Obligation: the replay must be proven to have actually run rather than vacuously skipped — the accepting case must show the evidence verdict reached the output, and the refusing cases must name the specific evidence predicate. A range containing no `Draft -> Approved` commit must be proven to invoke the replay zero times, so the new code cannot pass by never selecting anything.

Mutation Obligation: each newly load-bearing condition independently killed in an isolated evaluator copy, each by a scenario no other guard can rescue — (i) removing the `$baselineStatus -ne 'Draft'` gate must make the legal Draft-revision range fail again; (ii) inverting that gate so the block runs only for a `Draft` baseline must make an ordinary post-Approval frozen mutation pass; (iii) removing the range replay must make the invalid intermediate Approval pass; (iv) making the replay read the endpoint contract instead of the approving commit's own text must change the verdict on a range whose contract was legally edited after Approval in a permitted section. Each mutation must record `applied=True`, a green pristine run and a red mutant run.

Post-Implementation Proof Obligation: before Complete, the derived CONTROL suite executed by `-Finish` must produce actual positive, negative, non-empty-population and mutation-kill proof for every predicate above, with the whole suite at zero failures.

### SPEC Identity Allocation

Applicability: APPLICABLE

Derived mechanically, not chosen. At allocation the first-parent sequence cursor stands at **198** (`SPEC-198`, Complete). The candidate `cursor + 1` = **199** is **reserved** and must be skipped: `SPEC-198`'s own evidence prose quotes the literal `SPEC-199` while recording the probe that refused it, and reservation is monotonic over reachable history, so that occurrence burns the identity permanently. The first unreserved candidate is therefore **200**, confirmed absent from the current tree, from every added or renamed path in reachable history, and from the content pickaxe over that history. This is the Reservation Rule driving candidate advancement exactly as `CR_LIFECYCLE.md` §4 specifies, not a numeric maximum, and no future identifier is written into tracked text by this contract.

## Implementation Steps

1. **Check:** `scripts/test_agent_continuity.ps1` contains the sentinel `RANGE-AUTHORITY BASELINE`. If present, record Already Applied. Otherwise extend only the existing disposable harness — no new script or helper file — with focused fixtures written against the **unmodified** evaluator: (a) a range whose governing contract is a `Draft` at the base and is legally revised before its own Approval inside the range, which must publish; (b) a range whose intermediate `Draft -> Approved` commit carries an `UNKNOWN` consumer disposition, and separately a named unresolved material consumer, and separately a mandatory gate inside its own red window, each of which must be refused with `CODE: APPROVAL_EVIDENCE`; (c) a control for each of (b) whose base `Draft` carries the identical evidence text, so a refusal can never come from a frozen-authority comparison; (d) a range whose intermediate Approval carries valid evidence, which must be admitted; (e) a range containing no `Draft -> Approved` commit, proving the replay selects nothing. Run the focused cases and keep their expected-red failures **uncommitted**.

2. **Check:** `scripts/check_agent_continuity.ps1` contains the string `if($baselineStatus-ne'Draft'){`. If present, record Already Applied. Otherwise wrap exactly the four endpoint calls — `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly` and both `Validate-Checklist` calls — in `if($baselineStatus-ne'Draft'){ … }`, changing nothing else in that block. `Validate-StatusPath` and the completion-prerequisite check must remain **outside** the gate and unconditional: a transition is always judged, and a `Draft` base must not exempt a completion. Record in a comment that authority freezes at Approval, naming `CR_LIFECYCLE.md` §8 and the matching rule already implemented in `Validate-CommittedRange`.

3. **Check:** `scripts/check_agent_continuity.ps1` contains `function Contract-FromText`. If present, record Already Applied. Otherwise split the existing `Contract` function without changing its behaviour: move its body into `Contract-FromText([string]$Text,[string]$BaseName)`, and leave `Contract([string]$Path)` as a thin wrapper that reads the file and delegates, preserving the existing `STALE_ACTIVE_CR`, `INVALID_CR_HEADING` and `CR_ID_PATH_MISMATCH` refusals and their exact codes. Add no new error code and no new validation.

4. **Check:** `scripts/check_agent_continuity.ps1` contains `APPROVAL_EVIDENCE` inside `Validate-CommittedRange`. If present, record Already Applied. Otherwise, inside the existing per-commit loop and only for the governing contract, when the contract's status at this commit's first parent is `Draft` and its status at this commit is `Approved`, parse this commit's own contract text with `Contract-FromText`, derive its profiles from that parsed contract's own Write Scope, invoke the existing `Evaluate-PreApprovalEvidence` unchanged, and on refusal raise the existing `APPROVAL_EVIDENCE:` message with the offending short SHA appended after an `@`, matching the file's established convention. Do not add a second evaluator, do not re-implement any predicate, and do not evaluate any contract that is not the governing one.

5. **Check:** every sentinel added in Step 1 has a passing assertion and the harness contains `RANGE-AUTHORITY MUTATION POPULATION`. If both hold, record Already Applied; if only one holds, STOP. Otherwise prove against the repaired evaluator: each Step-1 refusal refuses with its exact expected code; each Step-1 acceptance is admitted; the existing frozen-authority, append-only, acceptance-text and review-gate refusals still fire from a non-`Draft` baseline; case 111 remains legal; and the no-Approval range invokes the replay zero times. Record accept, reject and mutation population counters for the new family through the existing `Pop` helper. Then apply each mutation named in this contract's Mutation Obligation one at a time to an isolated evaluator copy inside the existing sandbox and require the unchanged focused assertions to kill every one.

6. **Check:** a fresh local certification receipt matches this Change Request identity, its derived profiles and its current Write Scope fingerprint. If it matches, record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and proceed only on `LOCAL_CERTIFY: READY`. Then, as evidence rather than as a change, re-run the committed-range Gate over the range this contract will publish and record in the Execution Log that it is admitted, together with the reason it was previously refused.

7. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` are equal by value to `_ORVION_CANONICAL/manifest.md`'s. If they already agree, record Already Applied. Otherwise update `_ORVION_CANONICAL/manifest.md` per `CR_LIFECYCLE.md` §9 so that SPEC-200 becomes `Last Completed`, `Next capability` names the Batch 6 Slice 12 successor that must now carry the cancelled `SPEC-197`'s objective, and the file stays inside Check 5's 7000-character budget measured rather than assumed; then regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and normalise it to LF before committing.

## Acceptance Criteria

- [ ] The four endpoint calls `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly` and both `Validate-Checklist` are executed only when the base status is not `Draft`.
- [ ] `Validate-StatusPath` and the completion-prerequisite check remain unconditional and outside that gate.
- [ ] `Contract-FromText` exists, `Contract` delegates to it, and the `STALE_ACTIVE_CR`, `INVALID_CR_HEADING` and `CR_ID_PATH_MISMATCH` codes are unchanged.
- [ ] `Validate-CommittedRange` replays `Evaluate-PreApprovalEvidence` on every commit that moves the governing contract from `Draft` to `Approved`, reading that commit's own contract text and deriving profiles from that contract's own Write Scope.
- [ ] A refusal from that replay carries the existing `APPROVAL_EVIDENCE:` message with the offending short SHA appended after an `@`.
- [ ] No second evaluator, policy engine, registry or workflow was added, and `Evaluate-PreApprovalEvidence` itself is unchanged.
- [ ] `scripts/test_agent_continuity.ps1` contains the sentinels `RANGE-AUTHORITY BASELINE` and `RANGE-AUTHORITY MUTATION POPULATION`.
- [ ] The harness proves a contract legally revised while a `Draft` at the range base publishes, and that the same range is refused by the pre-repair evaluator.
- [ ] The harness proves an intermediate `Draft -> Approved` carrying an `UNKNOWN` disposition, a named unresolved consumer, or a gate inside its own red window is refused with `CODE: APPROVAL_EVIDENCE`, each paired with a control whose base `Draft` carries identical evidence text.
- [ ] The harness proves an intermediate Approval carrying valid evidence is admitted, and that a range containing no `Draft -> Approved` commit invokes the replay zero times.
- [ ] Existing frozen-authority, append-only, acceptance-text and review-gate refusals still fire from a non-`Draft` baseline, and case 111 remains legal.
- [ ] Accept, reject and mutation population counters exist for the new range-authority family.
- [ ] Every mutation named in this contract's Mutation Obligation is independently killed by the unchanged focused assertions.
- [ ] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` reports zero failures.
- [ ] `changes/SPEC-197-membership-authority-and-audit.md` is byte-identical to its state at its `Cancel` commit and still `Cancelled`.
- [ ] `ENGINEERING_METHOD.md`, `CR_LIFECYCLE.md`, `changes/TEMPLATE.md`, `changes/SPEC-196-pre-approval-evidence-sufficiency.md` and `changes/SPEC-198-preapproval-applicability-derivation.md` are byte-identical to their state at the start of this Change Request.
- [ ] `_ORVION_CANONICAL/manifest.md` names SPEC-200 as `Last Completed`, names the Slice-12 successor obligation in `Next capability`, and is inside Check 5's character budget.
- [ ] `ai-map.json`'s live_state copies match `_ORVION_CANONICAL/manifest.md` by value and the file is stored with LF line endings.
- [ ] The Execution Log records the committed-range Gate over this contract's own publishable range being admitted, and the exact code it was previously refused with.
- [ ] No file outside this contract's Write Scope was created, modified or deleted.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.]

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

**Why these two travel together.** They are the same block of code answering the same question — *which authority is this range judged against?* — and they fail in opposite directions. CTRL-2A applies a freeze that has not happened yet; CTRL-2B fails to apply a check that should have happened. Repairing one without the other would leave the evaluator half-aligned with `CR_LIFECYCLE.md` §5 and §8, and the range that publishes this contract is itself a `Draft -> Approved -> In Progress -> Complete` push, so both paths are exercised by this contract's own publication.

**What is deliberately excluded.** A contract **born already `Approved`** inside a range is never evidence-checked at all, because the endpoint block is skipped entirely when the contract does not exist at the base — reproduced on both the local Gate and the range, with no evidence section and with invalid evidence, admitted every time. That is **not** repaired here. `SPEC-165` made born-Approved a legal history and assertion 111 pins it; `SPEC-196` scoped evaluation to "actual Draft-to-Approved transitions". Closing it therefore means either forbidding a ratified history shape or inventing an evidence rule for a path `SPEC-196` did not write — an owner decision, not an implementation detail. It is recorded as `CTRL-2C` and left open. This contract does not use that path, and fixing CTRL-2B does not widen it.

**`DRAFT-REMOTE-1` is not absorbed.** A `Draft`-only range still cannot be published, which is what forced `SPEC-197`'s legal Draft revisions to accumulate locally until CTRL-2A refused them. That interaction is why CTRL-2A was expensive rather than cosmetic, but the repair here removes the blocking half without inventing a remote-Draft mechanism, so `DRAFT-REMOTE-1` stays a separate successor.

**What this contract does not rescue.** `SPEC-197` is terminal `Cancelled`. Its Slice-12 engineering — USR-1, USR-2, the reproduced counterexamples, the attacked repair design and the four hardened pre-Approval sections — is untouched and reusable, but it must return as a legally allocated successor contract. Nothing here resumes it, and this contract changes not one byte of that file.
