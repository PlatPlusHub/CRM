# Change Request — SPEC-202

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Require every Change Request originated after the existing `SPEC Allocation Enforcement` activation boundary to first appear as a `Draft`, so its Approval passes through the committed `Draft -> Approved` transition the Pre-Approval evidence mechanism already judges, while every pre-activation history remains valid exactly as committed.

## Business Reason

A Change Request that first appears already `Approved` is never evidence-checked. `Evaluate-PreApprovalEvidence` is reached only when a contract exists at the comparison baseline; a contract that is *born* `Approved` has no baseline, so the entire endpoint block is skipped — and `SPEC-196`'s own frozen Step E scopes evaluation to "actual Draft-to-Approved transitions", which such a contract never performs.

Reproduced against `f0b5af0`, on the evaluator as repaired by `SPEC-201`, with a contract carrying **no `## Pre-Approval Evidence` section at all**:

- local Gate — `ORVION: READY`, `MODE: EXECUTE`, `STATUS: Approved`: full write authority obtained with no evidence and no human `Draft -> Approved` decision;
- committed range — `ORVION: READY`: the same history is admitted for publication.

`CR_LIFECYCLE.md` §5 states that Approval is admissible only on sufficient evidence. On this path no evidence is ever read, so the rule is unenforced. The owner has ratified the correction: **forward-only from the existing activation boundary, a newly originated Change Request must not be created directly in `Approved`**, and pre-activation histories remain valid and are never reinterpreted.

## Risks

- **Retroactively invalidating `SPEC-165`-era history is the main risk.** Bounded by reusing the existing `SPEC Allocation Enforcement` marker, which already provides a first-parent-derived forward-only cutover and already gates allocation enforcement in every mode. A pre-activation control fixture proves the historical shape still passes, and a mutation proves the marker gate is load-bearing rather than decorative.
- **Refusing a legal history by checking the wrong state.** A contract born `Draft` and completed inside one range has endpoint status `Complete`, so applying the rule to the range's net diff would falsely refuse it. Measured, and the reason the rule is applied to the *originating commit* and to local authoring, never to the range endpoint.
- **Assertion 111 changes shape, and that is stated rather than hidden.** It currently proves a whole lifecycle inside one push using a born-`Approved` fixture whose sandbox baseline already carries the marker, so under this rule that exact fixture becomes illegal. Its fixture becomes `Draft`-first, which preserves the property `SPEC-165` actually earned — a contract created inside a range is legal history, and range validation may not demand it exist at the base — and a separate new control proves the pre-activation born-`Approved` shape is still admitted. `SPEC-165` is not edited and is not wrong; it described the law of its time.
- Not repairing leaves a complete bypass of `SPEC-196` reachable by any agent that writes an `Approved` contract file in one commit.
- This contract changes no product behaviour, no database object and no workflow.

## Supersedes / Depends On

None. `changes/SPEC-165-*` is historical and untouched. `SPEC-196` supplies the activation marker this contract reuses and is not modified. `SPEC-201` supplied the `Draft -> Approved` replay this rule funnels Approvals into and is not modified.

## Write Scope

- `changes/SPEC-202-origination-must-begin-as-draft.md`
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
- `changes/SPEC-201-draft-baseline-and-approval-replay.md`
- `scripts/check_repository_consistency.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/generate-ai-map.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`

## Required Reading

- `CR_LIFECYCLE.md` §4 and §5 — the transition matrix and Approval admissibility
- `changes/SPEC-196-pre-approval-evidence-sufficiency.md` — the `SPEC Allocation Enforcement` marker and the forward-only cutover it already owns
- `scripts/check_agent_continuity.ps1` — `Validate-SpecAllocation`, `Allocation-Events`, `Allocation-ActiveAt`, `Status-Path`
- `scripts/test_agent_continuity.ps1` — assertion 111 and the `Pre-Range` / `RunRange` helpers

## Runtime Checkpoint

Resume Step: DONE
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
| Permanent-Control Admission | The change adds a mandatory origination-state rule to allocation validation and introduces one new refusal code. | APPLICABLE |
| SPEC Allocation | A new Change Request identity is an allocation event regardless of declared Change Class. | APPLICABLE |

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `Validate-SpecAllocation` gains an origination-state rule | its three existing call sites — local authoring, the range endpoint, and the per-commit walk | WRITE | Measured: the same function is already invoked in all three modes, so one rule needs no adapters. The rule is applied at local authoring and per-commit only; the endpoint call is deliberately excluded because a contract born `Draft` and completed in one range has endpoint status `Complete` |
| `Validate-SpecAllocation` gains an origination-state rule | `scripts/test_agent_continuity.ps1` assertion 111 | WRITE | Its born-`Approved` fixture sits on a marker-bearing baseline and becomes illegal under this rule; its fixture becomes `Draft`-first, preserving the `SPEC-165` property it exists to prove, with a new pre-activation control covering the historical shape |
| A new `ORIGINATION_NOT_DRAFT` refusal code | the Gate's error vocabulary and its consumers | WRITE | Measured before adding: `Status-Path` seeds its sequence only when the contract exists at the baseline, so a born contract yields no origination element and `ILLEGAL_STATUS_TRANSITION` has no transition to name; the allocation codes name identity, not state. No existing code names this invariant truthfully |
| The activation boundary used for the cutover | `CR_LIFECYCLE.md`'s `SPEC Allocation Enforcement` marker | VERIFY | Reused, not redefined. `CR_LIFECYCLE.md` is in Out of Scope and the marker's value is not changed; the rule simply consults the gate that already exists |
| Pre-activation ranges | every published historical range | VERIFY | The rule fires only where allocation enforcement is already active, which is first-parent derived and forward-only. A mutation proves removing that gate turns the pre-activation control red |
| Manifest `Last Completed` / `Next capability` | `_ORVION_CANONICAL/manifest.md`, `ai-map.json` | WRITE | Both in Write Scope; Check 7 compares the three live_state fields by value and Check 5's character budget is re-measured rather than assumed |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE — this is a repository-only control change that performs no irreversible external action.

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The control suite passes with zero failures | BEFORE_COMPLETION | Step 1 | Step 4 | Step 5 |
| Check 5 — `_ORVION_CANONICAL/manifest.md` inside its 7000-character budget | BEFORE_COMPLETION | NONE | NONE | NONE |
| Check 7 — `ai-map.json` live_state equals the manifest by value | BEFORE_COMPLETION | Step 6 | Step 6 | NONE |
| A fresh local certification receipt matches the Write Scope fingerprint | BEFORE_COMPLETION | NONE | NONE | NONE |

The RED fixtures of Step 1 are run and left **uncommitted**, so the red window never crosses a commit boundary.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `Validate-SpecAllocation` already identifies exactly the set of newly originated contracts through `Allocation-Events`, and is already called from local authoring, the range endpoint and the per-commit walk. The forward-only cutover already exists as the `SPEC Allocation Enforcement` marker read from a commit's first parent. No second activation authority, registry, allowlist, date, numeric threshold, status machine or Approval evaluator is added — the rule is one predicate placed where the allocation fact already lives.

Added Property: that a Change Request originated after the activation boundary cannot hold `Approved` authority without a committed `Draft -> Approved` transition, so `SPEC-196`'s evidence mechanism is always reached before authority freezes.

Causal Negative: reproduced against `f0b5af0` on the `SPEC-201`-repaired evaluator, with a contract carrying no `## Pre-Approval Evidence` section — local Gate `ORVION: READY / MODE: EXECUTE / STATUS: Approved`, and the committed range `ORVION: READY`. The pre-activation control, with the marker absent from the parent, is also `ORVION: READY` and must remain so.

Positive Test Design: post-activation `Draft` authoring is admitted; a post-activation `Draft -> Approved -> In Progress -> Complete` lifetime inside one range is admitted; a pre-activation born-`Approved` range remains admitted; assertion 111's property — a contract created inside a range is legal history — still holds under its `Draft`-first fixture.

Negative Test Design: a post-activation contract first appearing as `Approved` is refused `ORIGINATION_NOT_DRAFT` at local authoring; the same history is refused in the committed range with the offending short SHA appended; a post-activation contract first appearing as `In Progress`, and one first appearing as `Complete`, are also refused, because the rule names the required origination state rather than enumerating forbidden ones.

Non-Empty Population Obligation: the rule must be proven to select something and to select nothing where it must not — at least one post-activation refusal and one pre-activation acceptance, and a range containing no allocation event must be proven to invoke the origination check zero times, so the predicate cannot pass by never firing.

Mutation Obligation: exactly three, each killed by a scenario no other guard can rescue — (i) removing the activation-marker gate so the rule applies unconditionally must turn the **pre-activation** control red; (ii) removing the `Draft` requirement must admit the post-activation born-`Approved` case again; (iii) additionally applying the rule at the range endpoint must falsely refuse a contract born `Draft` and completed inside one range. Each must record `applied=True`, a green pristine run and a red mutant run.

Post-Implementation Proof Obligation: before Complete, the derived CONTROL suite executed by `-Finish` must produce actual positive, negative, non-empty-population and mutation-kill proof for every predicate above, with the whole suite at zero failures.

### SPEC Identity Allocation

Applicability: APPLICABLE

Derived mechanically. At allocation the first-parent sequence cursor stands at **201** (`SPEC-201`, Complete at `f0b5af0`); the candidate `cursor + 1` = **202**; `SPEC-202` is unreserved by all three reservation queries — absent from the current tree, from every added or renamed path in reachable history, and from the content pickaxe over that history. No future identifier is written into tracked text by this contract, and `SPEC-199` remains reserved and is not reclaimed.

## Implementation Steps

1. **Check:** `scripts/test_agent_continuity.ps1` contains the sentinel `ORIGINATION STATE`. If present, record Already Applied. Otherwise extend only the existing disposable harness with focused fixtures written against the **unmodified** evaluator: (a) a post-activation contract first appearing as `Approved`, refused at the local Gate with `ORIGINATION_NOT_DRAFT`; (b) the same history in a committed range, refused with that code and an `@<short>` suffix; (c) post-activation contracts first appearing as `In Progress` and as `Complete`, both refused; (d) a post-activation contract authored as `Draft`, admitted; (e) a post-activation `Draft -> Approved -> In Progress -> Complete` lifetime inside one range, admitted; (f) a **pre-activation** born-`Approved` range — the marker absent from the originating commit's first parent — admitted, and labelled in its assertion text as the historical `SPEC-165` shape; (g) a range containing no allocation event, proving the origination check fires zero times. Run the focused cases and keep their expected-red failures **uncommitted**.

2. **Check:** `scripts/check_agent_continuity.ps1` contains the string `ORIGINATION_NOT_DRAFT`. If present, record Already Applied. Otherwise add the origination-state rule to `Validate-SpecAllocation` only: give it an optional parameter naming the state to read the newly originated contract from — the working tree when empty, otherwise a commit — and for each allocation event whose contract is newly originated, read that contract's status at that state and refuse `ORIGINATION_NOT_DRAFT:<path>:<status>` when it is anything other than `Draft`. Reuse `Allocation-Events` to identify the originated set and `Status-FromText` to read the status; add no new traversal, no new activation authority and no second evaluator. Change no existing refusal code.

3. **Check:** `scripts/check_agent_continuity.ps1` passes the originating commit to the per-commit allocation call and the working tree to the local call. If already so, record Already Applied. Otherwise update exactly those two call sites, and **leave the range-endpoint call unchanged** so it does not apply the origination rule — a contract born `Draft` and completed inside one range carries endpoint status `Complete`, and applying the rule to the net diff would refuse that legal history. Record that reason in a comment at the endpoint call site.

4. **Check:** every sentinel added in Step 1 has a passing assertion and the harness contains `ORIGINATION STATE MUTATION POPULATION`. If both hold, record Already Applied; if only one holds, STOP. Otherwise prove each Step-1 case against the repaired evaluator; update assertion 111's fixture so the contract it creates inside one range is authored `Draft` first and then transitions `Approved -> In Progress -> Complete`, leaving its assertion text's claim — that a contract created and completed inside one range is a legal history — intact and extending its comment to record that the born-`Approved` shape it previously used is now pre-activation-only and is covered by the new control; record accept, reject and mutation population counters for the new family; then apply each mutation named in this contract's Mutation Obligation one at a time to an isolated evaluator copy inside the existing sandbox and require the unchanged focused assertions to kill every one.

5. **Check:** a fresh local certification receipt matches this Change Request identity, its derived profiles and its current Write Scope fingerprint. If it matches, record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and proceed only on `LOCAL_CERTIFY: READY`. Record in the Execution Log the ordinary `-Gate` wall-clock timing before and after the repair on one identical tree, and stop rather than accept a material routine slowdown without a stated cause.

6. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` are equal by value to `_ORVION_CANONICAL/manifest.md`'s. If they already agree, record Already Applied. Otherwise update `_ORVION_CANONICAL/manifest.md` per `CR_LIFECYCLE.md` §9 so that SPEC-202 becomes `Last Completed` and `Next capability` names the Batch 6 Slice 12 successor, keeping the file inside Check 5's 7000-character budget measured rather than assumed; then regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and normalise it to LF before committing.

## Acceptance Criteria

- [x] `Validate-SpecAllocation` refuses `ORIGINATION_NOT_DRAFT` when a newly originated contract's status at its origination state is anything other than `Draft`.
- [x] The rule fires only where allocation enforcement is already active, and no new activation authority, registry, allowlist, date or numeric threshold was introduced.
- [x] The rule is applied at local authoring and in the per-commit walk, and is **not** applied at the range-endpoint call, with that reason recorded in a comment there.
- [x] `ORIGINATION_NOT_DRAFT` is the only refusal code added, and no existing code's text or meaning changed.
- [x] `scripts/test_agent_continuity.ps1` contains the sentinels `ORIGINATION STATE` and `ORIGINATION STATE MUTATION POPULATION`.
- [x] The harness proves a post-activation born-`Approved` contract is refused at the local Gate and in the committed range, the latter with an `@<short>` suffix.
- [x] The harness proves post-activation origination as `In Progress` and as `Complete` are also refused.
- [x] The harness proves a post-activation `Draft` authoring is admitted and a post-activation `Draft -> Approved -> In Progress -> Complete` lifetime inside one range is admitted.
- [x] The harness proves a **pre-activation** born-`Approved` range remains admitted, and its assertion text names it as the historical `SPEC-165` shape.
- [x] The harness proves a range containing no allocation event invokes the origination check zero times.
- [x] Assertion 111 still asserts that a contract created and completed inside one range is a legal history, using a `Draft`-first fixture, and its comment records why the born-`Approved` shape moved to the pre-activation control.
- [x] Accept, reject and mutation population counters exist for the new origination family.
- [x] Exactly three mutations are declared and each is independently killed by the unchanged focused assertions.
- [x] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` reports zero failures.
- [x] `changes/SPEC-196-pre-approval-evidence-sufficiency.md`, `changes/SPEC-198-preapproval-applicability-derivation.md`, `changes/SPEC-201-draft-baseline-and-approval-replay.md`, `ENGINEERING_METHOD.md`, `CR_LIFECYCLE.md` and `changes/TEMPLATE.md` are byte-identical to their state at the start of this Change Request.
- [x] The Execution Log records the ordinary `-Gate` timing before and after the repair on one identical tree.
- [x] `_ORVION_CANONICAL/manifest.md` names SPEC-202 as `Last Completed` and is inside Check 5's character budget; `ai-map.json`'s live_state copies match it by value with LF line endings.
- [x] No file outside this contract's Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-20 - Claude Opus 5 (executing agent)

Outcome: Complete

Step results:
- Step 1: Applied - cases 213-220 added to the existing harness.
- Step 2: Applied - `Validate-SpecAllocation` refuses `ORIGINATION_NOT_DRAFT` for a newly originated contract whose status at its origination state is not `Draft`.
- Step 3: Applied - the rule is wired to local authoring (working tree) and the per-commit walk (state at that commit); the range-endpoint call is unchanged, with the reason recorded in a comment there.
- Step 4: Applied - all Step-1 cases proven, assertion 111 moved to a `Draft`-first fixture, population counters recorded, three mutations killed.
- Step 5: Applied - `LOCAL_CERTIFY: READY`; Gate timing recorded below.
- Step 6: Applied - manifest and `ai-map.json` updated by measurement and normalised to LF.

**RED, against the `SPEC-201`-repaired evaluator at `f0b5af0`.** A contract carrying no `## Pre-Approval Evidence` section at all, born `Approved`: local Gate `ORVION: READY / MODE: EXECUTE / STATUS: Approved`, committed range `ORVION: READY`. The pre-activation control - marker absent from the originating commit's first parent - was admitted and had to remain so.

**GREEN: 270 passed / 0 failed.** 213-215 refuse origination as `Approved`, `In Progress` and `Complete` locally; 216 refuses the same history in a range with the offending short SHA; 217 admits `Draft` authoring; 218 admits a `Draft`-first whole lifecycle inside one range; 219 admits the pre-activation `SPEC-165` shape; 220 proves a range with no allocation event invokes the check zero times.

**Mutations, each on a scenario no other guard can rescue.** Removing the activation gate turns the *pre-activation* control red; removing the `Draft` requirement admits the born-`Approved` case again; additionally applying the rule at the range endpoint falsely refuses a contract born `Draft` and completed inside one range. All three recorded `applied=True` with a green pristine and a red mutant.

**Blast radius was wider than this contract's Step 4 enumerated, and that is recorded rather than hidden.** Step 4 named only assertion 111. Measurement found the rule also reaches assertion 27 (which relied on `ContractText`'s default `In Progress`), 114 and 120 (born-`Approved` range fixtures), and one existing K mutation whose `Find` string targeted the exact line Step 3 edits. All four were corrected inside Write Scope, none changed what its assertion claims - 27 now originates in PLAN as a `Draft`, 114 and 120 commit a `Draft` first, and the K mutation tracks the edited line - and the contract's own criterion that the suite reports zero failures is what required them. Root cause: the blast radius was predicted rather than prototyped against the full suite before freezing, which is the measurement `SPEC-197` did correctly and this contract did not.

**Performance.** Three ordinary `-Gate` runs each on one identical tree: after 15520 / 12629 / 13903 ms against before 15888 / 14853 / 13902 ms. No material slowdown - the check adds a path match per record and one blob read per newly originated contract, and walks no history.

## Verification Notes

### 2026-09-20 - Claude Opus 5 (reviewing agent)

Verdict: Confirmed Complete

Findings: re-checked against the live repository. `ORIGINATION_NOT_DRAFT` is the only refusal code added. The local call passes `-CheckOrigination`; the per-commit call passes `-CheckOrigination -StateRef $commit`; the range-endpoint call is unchanged and carries the comment explaining that a contract born `Draft` and completed inside one range has endpoint status `Complete`, so judging it there would refuse legal `SPEC-165` history. A cross-identity rename is excluded from origination. No numeric threshold, date, allowlist or second activation authority appears. Both harness sentinels exist and exactly three origination mutations are declared. Against `origin/main`, none of `ENGINEERING_METHOD.md`, `CR_LIFECYCLE.md`, `changes/TEMPLATE.md`, `SPEC-196`, `SPEC-198`, `SPEC-201`, `check_repository_consistency.ps1` or `publish_candidate.ps1` differs. `-Finish` reported `LOCAL_CERTIFY: READY` with all five guard suites, repository consistency and `git diff --check` passing.

Recommendation to human: Set Status to Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

**Why this needs no adapters.** The obvious design is two thin adapters over one rule — one for local admission, one for historical range admission. Measurement refuted that: `Validate-SpecAllocation` is *already* called from all three places (local authoring, the range endpoint, and the per-commit walk), and it already computes the exact set of newly originated contracts. The rule therefore has one home and one implementation, and the only per-mode difference is which state the originated contract's status is read from — the working tree when authoring, the originating commit when judging history. That is a parameter, not a policy.

**Why the range endpoint is deliberately excluded.** A contract born `Draft` and completed inside a single push has endpoint status `Complete`. The endpoint call sees the net diff, in which that contract is simply "added", so applying the origination rule there would refuse a history the repository explicitly calls legal. The per-commit walk is the only place that can see the state a contract actually had when it appeared, so that is the only place the rule belongs.

**Why a new refusal code earns existence.** `Status-Path` seeds its sequence from the baseline only when the contract exists there, so a born contract produces no origination element and `Validate-StatusPath` has no transition to judge — `ILLEGAL_STATUS_TRANSITION` would name something that did not happen. The allocation codes (`SPEC_ID_NOT_NEXT`, `SPEC_ID_HISTORICALLY_RESERVED`, `SPEC_ALLOCATION_MARKER_MISSING`) all name identity facts, not lifecycle state. `ORIGINATION_NOT_DRAFT` names the violated invariant exactly and points at the remedy — commit the contract as a `Draft` first — so the distinction materially improves diagnosis.

**What happens to `SPEC-165`, stated plainly.** `SPEC-165` proved a real defect: range validation demanded that a contract exist at the range base, which refused a small Change Request whose whole lifecycle fit in one push. That property is preserved here — assertion 111 still proves it, with a `Draft`-first fixture — and a new control proves the pre-activation born-`Approved` shape is still admitted exactly as committed. `SPEC-165` is not edited, not superseded and not wrong; the activation marker is what separates the law of its time from the law after the cutover, which is the same forward-only device `SPEC-196` already installed for identity allocation.
