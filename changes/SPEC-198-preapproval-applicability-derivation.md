# Change Request — SPEC-198

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Bring the Pre-Approval evidence evaluator's applicability derivation up to the authority it already claims, so a Change Request made applicable by a derived non-`REPOSITORY` profile, a deployable execution surface, or a declared irreversible action has its evidence actually evaluated instead of silently admitted.

## Business Reason

`ENGINEERING_METHOD.md`'s `### Pre-Approval evidence sufficiency` rule states that applicability is derived from "Write Scope, derived verification profiles, known control and governance surfaces, cross-path triggers, and declared irreversible actions", and `SPEC-196`'s own frozen Step E instructs the evaluator to "derive applicability from Write Scope, profiles, known control/governance surfaces, cross-path triggers, and irreversible-action declaration". Its Derived Applicability prose says a block is made applicable by "a derived non-`REPOSITORY` profile, a known governance/control surface, a cross-path trigger, or a declared irreversible action".

The shipped implementation derives only one of those inputs. `Evaluate-PreApprovalEvidence` computes `$applicable = ($Profiles -contains 'CONTROL')`, falls back to `Test-ControlPath` over Write Scope, and otherwise executes `return 'PASS'` **before reading the section at all**.

Reproduced on the real automatic path, in a disposable sandbox, across a genuine committed `Draft -> Approved` transition with a `## Pre-Approval Evidence` section that is invalid three independent ways — an `UNKNOWN` consumer disposition, a named unresolved material consumer, and the `SPEC-195` shape where the mandatory gate sits inside the invariant's own red window:

- Write Scope `supabase/migrations/20260101000000_fixture.sql` (derived profiles `DATABASE, REPOSITORY`, no control path) — `ORVION: READY`, `STATUS: Approved`, **`APPROVAL_EVIDENCE: PASS`**, exit 0.
- The identical evidence with Write Scope `scripts/check_agent_continuity.ps1` (adds `CONTROL`) — `APPROVAL_EVIDENCE: INDETERMINATE:UNKNOWN consumer disposition`, exit 1.

The only difference between the two runs is Write Scope. This is reachable in ordinary engineering work rather than hypothetically: `changes/SPEC-197-membership-authority-and-audit.md` is a Draft awaiting Approval whose derived profiles are exactly `DATABASE, REPOSITORY`, which installs two permanent database controls and which declares an irreversible action (deploying a migration to Primary). Under the current derivation its evidence is never evaluated, and the Gate nonetheless prints `APPROVAL_EVIDENCE: PASS` — asserting the very fact `SPEC-196` exists to establish.

## Risks

- **Widening applicability could burden ordinary work.** Bounded by measurement rather than by intent: a contract whose Write Scope touches no control surface and derives only `REPOSITORY` stays non-applicable and still needs no evidence section, which is what assertion 178 pins. The population that newly becomes applicable is exactly the one the authority already names.
- **A newly applicable class could reveal incomplete evidence in a Draft authored before this repair.** That is the intended effect, not a regression: `SPEC-197` was authored with a complete section precisely so this would hold, and it is verified rather than assumed by this contract's Step 5.
- **Changing the emitted outcome word could break a consumer.** Measured: `git grep` finds no programmatic consumer of the `APPROVAL_EVIDENCE:` line outside the evaluator and its harness; the only other occurrence is `SPEC-196`'s own terminal step-verification text. Assertion 178 asserts the exit code, not the string.
- Not repairing leaves Approval authority obtainable, for every database and CI contract, on evidence nothing read — while the Gate states that it passed.

## Supersedes / Depends On

None. `SPEC-196` is `Complete` and terminal; this contract does not reopen, edit or supersede it, and changes no authority document. `ENGINEERING_METHOD.md` and `CR_LIFECYCLE.md` are deliberately out of scope: the authority is already correct and is not being rewritten to match the code.

## Write Scope

- `changes/SPEC-198-preapproval-applicability-derivation.md`
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
- `scripts/check_repository_consistency.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/generate-ai-map.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`

## Required Reading

- `ENGINEERING_METHOD.md` — the `### Pre-Approval evidence sufficiency` rule, and in particular its applicability sentence
- `CR_LIFECYCLE.md §5` — Approval admissibility
- `changes/SPEC-196-pre-approval-evidence-sufficiency.md` — its `### Derived Applicability` prose and its frozen Step E, which together state the intended derivation
- `scripts/check_agent_continuity.ps1` — `Evaluate-PreApprovalEvidence`, `Profiles`, `Test-ControlPath`, `Get-ControlSurface`
- `scripts/test_agent_continuity.ps1` — cases 176-178 and the `ApproveRun` / `ApproveSetup` / `EvidenceText` helpers
- `changes/SPEC-197-membership-authority-and-audit.md` — the live Draft this defect currently admits unevaluated

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
| Execution-Boundary Satisfiability | The change opens a required-red window in the control suite between its RED fixtures and the evaluator repair, and a mandatory `-Finish` CONTROL profile follows it. | APPLICABLE |
| Permanent-Control Admission | The change alters a permanent control's admission predicate, which decides whether Approval authority may be obtained. | APPLICABLE |
| SPEC Allocation | A new Change Request identity is an allocation event regardless of declared Change Class. | APPLICABLE |

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The publishable range `origin/main..HEAD` already contains the `SPEC-197` Draft commit `67e6092` | the endpoint scope check in `check_agent_continuity.ps1`, and `scripts/publish_candidate.ps1` which gates on it | WRITE | Reproduced before Approval in a disposable clone carrying the real topology: the simulated `Draft -> Approved -> In Progress -> implementation -> Complete` range was refused `OUT_OF_SCOPE_WRITE:changes/SPEC-197-membership-authority-and-audit.md`. Closed by carrying that path in Write Scope while an Acceptance Criterion pins it byte-identical |
| The applicability predicate inside `Evaluate-PreApprovalEvidence` | `scripts/test_agent_continuity.ps1` cases 176-178 and the mutation families | WRITE | 176 and 177 use a CONTROL scope and are unaffected by construction; 178 uses `allowed.txt` and must keep admitting a `REPOSITORY`-only contract with no evidence section, which Step 4 pins with a fixture rather than by argument |
| The applicability predicate | `changes/SPEC-197-membership-authority-and-audit.md`, derived `DATABASE, REPOSITORY` | VERIFY | Its evidence section was authored complete and is re-evaluated by Step 5 through the normal automatic path; no edit to that contract is authorized here |
| The applicability predicate | `ENGINEERING_METHOD.md` `### Pre-Approval evidence sufficiency` | UNAFFECTED | The authority already names these inputs. The code is being brought to the authority; the authority is not being rewritten, and is named in Out of Scope |
| The applicability predicate | `CR_LIFECYCLE.md §5` | UNAFFECTED | Owns admissibility, not applicability, and its `Routine`-cannot-exempt clause remains true and unchanged |
| The emitted `APPROVAL_EVIDENCE:` outcome word | any programmatic consumer | UNAFFECTED | Measured with `git grep`: no consumer outside the evaluator and its harness; the sole other occurrence is `SPEC-196`'s terminal step-verification text, and assertion 178 asserts the exit code rather than the string |
| Applicability for contracts deriving `CI` or `WORKSTATION` | `.github/workflows/**` and `.workstation/**` contracts | VERIFY | These become applicable by the same non-`REPOSITORY` profile rule. That is the authority's stated intent; Step 4 proves the rule by profile rather than by naming `DATABASE` specifically |
| Applicability for Edge Function contracts | `supabase/functions/storage-executor/index.ts` | VERIFY | Measured: this path matches no `Profiles` pattern and is absent from `Get-ControlSurface`, so a contract scoped to it derives `REPOSITORY` alone and was reproduced being admitted with invalid evidence. It is the repository's only Edge Function and it authorizes itself with the `service_role` key, bypassing RLS, to destroy customer documents — `ENGINEERING_METHOD.md §5` cross-path work by definition |
| `supabase/functions/**` as an applicability input | `Profiles`, `Get-ControlSurface`, `.github/workflows/migration-ci.yml` | UNAFFECTED | The path is read only inside the applicability predicate. Measured: `migration-ci.yml`'s `push:` filters do not include `supabase/functions/**`, so adding it to the `DATABASE` profile instead would create exactly the disagreement that profile's own comment forbids, and would additionally force the whole database protocol to execute for a TypeScript change |
| Manifest `Last Completed` / `Next capability` | `_ORVION_CANONICAL/manifest.md`, `ai-map.json` | WRITE | Both in Write Scope; Check 7 compares the three live_state fields by value |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE — this is a repository-only control change that performs no irreversible external action, so `BEFORE_IRREVERSIBLE_ACTION` and `AFTER_IRREVERSIBLE_ACTION` do not arise.

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The control suite passes with zero failures | BEFORE_COMPLETION | Step 1 | Step 3 | Step 5 |
| Check 7 — `ai-map.json` live_state equals the manifest by value | BEFORE_COMPLETION | Step 6 | Step 6 | NONE |
| A fresh local certification receipt matches the Write Scope fingerprint | BEFORE_COMPLETION | NONE | NONE | NONE |

The RED fixtures of Step 1 are run and left **uncommitted**, exactly as `SPEC-196`'s Step C required, so the red window never crosses a commit boundary and no Gate observes a deliberately failing suite.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `Evaluate-PreApprovalEvidence` already owns this decision, and every fact the repair needs is already computed and in scope at the call site — `$Profiles` is passed in by the Gate, `Test-ControlPath`/`Get-ControlSurface` already exist, and the declared irreversible action is already parsed out of the `Execution-Boundary Satisfiability` subsection by `SubSection`/`EvidenceField`. No second evaluator, policy engine, registry, dependency graph, semantic classifier, service, hook or workflow is added, and no authority text is duplicated into code: the code reads the inputs the authority already names.

Added Property: that a Change Request made applicable by a derived non-`REPOSITORY` profile or by its own declared irreversible action has its D/F/H-J evidence actually evaluated, and that a Change Request which is genuinely not applicable is reported as not applicable rather than as having passed.

Causal Negative: reproduced on the real automatic path before this contract was written. One committed `Draft -> Approved` transition, evidence invalid three independent ways, Write Scope `supabase/migrations/20260101000000_fixture.sql`: `ORVION: READY`, `APPROVAL_EVIDENCE: PASS`, exit 0. The same evidence under a CONTROL scope: `APPROVAL_EVIDENCE:INDETERMINATE:UNKNOWN consumer disposition`, exit 1.

Positive Test Design: a `REPOSITORY`-only contract with no evidence section is still admitted (assertion 178 preserved); a CONTROL contract with complete evidence is still admitted with `APPROVAL_EVIDENCE: PASS` (assertion 177 preserved); a `DATABASE`-scope contract carrying complete valid evidence is admitted.

Negative Test Design: a contract scoped only to `supabase/functions/**`, deriving `REPOSITORY` alone and declaring no irreversible action, is refused rather than admitted; a `DATABASE`-scope contract with an `UNKNOWN` consumer disposition is refused `APPROVAL_EVIDENCE:INDETERMINATE`; a `DATABASE`-scope contract whose mandatory gate lies inside its own red window is refused `APPROVAL_EVIDENCE:FAIL`; a `DATABASE`-scope contract with no evidence section at all is refused `INDETERMINATE:section missing`; a `REPOSITORY`-only contract that declares an irreversible action step is refused rather than exempted.

Non-Empty Population Obligation: the newly applicable population must be proven non-empty in both directions — at least one accepting case and one refusing case must exist for a contract that is applicable **only** by derived profile and carries no control path, so the new rule cannot pass by never selecting anything. The `DATABASE` fixtures must additionally assert that their derived profile set actually contains `DATABASE` and does not contain `CONTROL`, or they would prove nothing about the new input.

Mutation Obligation: each newly load-bearing applicability arm independently killed in an isolated evaluator copy, each by a case no other arm can rescue — (i) reverting the profile test to `-contains 'CONTROL'` must make the `DATABASE` refusal cases pass; (ii) removing the `supabase/functions/` arm must make the Edge Function refusal case pass, and that fixture must derive no profile and declare no irreversible action so no other arm can kill this mutation for it; (iii) removing the irreversible-action input must make the declared-irreversible refusal case pass, and that fixture must be `REPOSITORY`-only with no Edge Function path for the same reason; (iv) restoring the unconditional `return 'PASS'` on the non-applicable branch must make every new refusal case pass; (v) making the non-applicable branch report `PASS` again must make the not-applicable outcome assertion fail. Each mutation must record that it was actually applied and that the mutated evaluator was actually executed, and each must be paired with a green baseline control.

Post-Implementation Proof Obligation: before Complete, the derived CONTROL suite executed by `-Finish` must produce actual positive, negative, non-empty-population and mutation-kill proof for every predicate above, with the whole suite at zero failures.

### SPEC Identity Allocation

Applicability: APPLICABLE

Derived mechanically, not chosen. The first-parent sequence cursor stands at **197** (`changes/SPEC-197-membership-authority-and-audit.md`, committed at `67e6092`); the candidate is `cursor + 1` = **198**; `SPEC-198` is unreserved by all three reservation queries — absent from the current tree, from every added or renamed path in reachable history, and from the content pickaxe over that history — so the first free candidate is itself. The same mechanism refused a deliberate `SPEC-199` probe with `SPEC_ID_NOT_NEXT:198:199`, which is the evaluator naming 198 itself. No future identity literal is written into tracked text by this contract.

## Implementation Steps

1. **Check:** `scripts/test_agent_continuity.ps1` contains the sentinel `APPROVAL-EVIDENCE APPLICABILITY`. If present, record Already Applied. Otherwise extend only the existing disposable harness — no new script, no new helper file — with focused fixtures written against the **unmodified** evaluator, each using the existing `ApproveRun`/`ApproveSetup` helpers with a `-Scope` of `supabase/migrations/20260101000000_fixture.sql` so the derived profile set is `DATABASE, REPOSITORY` and contains no control path: an `UNKNOWN` consumer disposition; a mandatory gate inside its own declared red window; an absent evidence section; and a `REPOSITORY`-only scope whose contract declares an `Irreversible Action Step` other than `NONE`. Add one further fixture whose `-Scope` is `supabase/functions/storage-executor/index.ts` carrying the same `UNKNOWN` consumer disposition, which must also be refused. Add assertions that read the Gate's own `VERIFICATION:` line and prove the `DATABASE` fixtures derive `DATABASE` and do **not** derive `CONTROL`, and that the Edge Function fixture derives `REPOSITORY` and nothing else — otherwise neither fixture proves anything about the input it is named for. Run the focused cases and keep their expected-red failures **uncommitted**.

2. **Check:** `scripts/check_agent_continuity.ps1`'s `Evaluate-PreApprovalEvidence` contains the string `Where-Object{$_-ne'REPOSITORY'}`. If present, record Already Applied. Otherwise replace only the two applicability lines at the head of that function so that `$applicable` is true when any of the following holds, and change nothing else in the function: the derived `$Profiles` set contains any entry other than `REPOSITORY`; any Write Scope path satisfies `Test-ControlPath`; any Write Scope path matches `^supabase/functions/`; or the contract's `Execution-Boundary Satisfiability` subsection declares an `Irreversible Action Step` whose value is neither empty nor `NONE`. The `Test-ControlPath` fallback is retained rather than deleted as redundant, because it is the only input that does not depend on `Profiles` being computed by the caller. Read the irreversible-action value with the existing `SubSection`/`EvidenceField` helpers against the already-extracted `$body`, and only when `$body` is non-empty, so a contract with no evidence section is not made applicable by a section it does not have. Do not add `supabase/functions/` to `Profiles` or to `Get-ControlSurface`: those decide which verification protocol executes and which surface is control-plane, and this change must alter neither.

3. **Check:** `scripts/check_agent_continuity.ps1` contains the string `'NOT APPLICABLE'`. If present, record Already Applied. Otherwise change the non-applicable branch of `Evaluate-PreApprovalEvidence` to return the string `NOT APPLICABLE` instead of `PASS`, leaving every applicable path returning `PASS` unchanged. This is part of the same defect rather than a separate improvement: `ENGINEERING_METHOD.md` states that "we did not look" and "we looked and it is fine" are different facts, and the Gate currently prints `APPROVAL_EVIDENCE: PASS` for a section it never read. Change no other emitted code or word, and do not alter the `Block`/`Section` vocabulary.

4. **Check:** every sentinel added in Step 1 has a passing assertion and the harness contains `APPROVAL-EVIDENCE APPLICABILITY POPULATION`. If both hold, record Already Applied; if only one holds, STOP. Otherwise prove, against the repaired evaluator: each Step-1 refusal now refuses with its exact expected code; a `DATABASE`-scope contract carrying complete valid evidence is admitted; assertion 177's CONTROL accept still reports `APPROVAL_EVIDENCE: PASS`; assertion 178's `REPOSITORY`-only contract with no evidence section is still admitted and now reports `APPROVAL_EVIDENCE: NOT APPLICABLE`; and record accept/reject/mutation population counters for the new family through the existing `Pop` helper, so a family with no accepting case, no rejecting case or no mutation kill is visible as unmeasured. Then apply each mutation named in this contract's Mutation Obligation one at a time to an isolated evaluator copy inside the existing sandbox and require the unchanged focused assertions to kill every one.

5. **Check:** a fresh local certification receipt matches this Change Request identity, its derived profiles and its current Write Scope fingerprint. If it matches, record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and proceed only on `LOCAL_CERTIFY: READY`, which executes the derived CONTROL and REPOSITORY profiles including the full control suite at zero failures and `scripts/check_repository_consistency.ps1`. Then, as evidence rather than as a change, run the ordinary automatic Gate against `changes/SPEC-197-membership-authority-and-audit.md` in its existing `Draft` state and record in the Execution Log which applicability inputs it now derives; do not edit that contract, do not approve it, and do not force applicability by any means.

6. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` are equal by value to `_ORVION_CANONICAL/manifest.md`'s. If they already agree, record Already Applied. Otherwise update `_ORVION_CANONICAL/manifest.md` per `CR_LIFECYCLE.md §9` so that SPEC-198 becomes `Last Completed` and `Next capability` continues to name Batch 6 Slice 12, then regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and re-check. Run this regeneration after every commit in this Change Request's lifecycle that changes the manifest, including the `Approve` and `Complete` transitions. The generator writes CRLF while Git stores this file LF under `core.autocrlf=true`, so normalise the regenerated file to LF before committing or `git diff --check` reports trailing whitespace on every line.

## Acceptance Criteria

- [ ] `Evaluate-PreApprovalEvidence` derives applicability from the derived profile set, from `Test-ControlPath` over Write Scope, from a Write Scope path matching `^supabase/functions/`, and from a declared `Irreversible Action Step` other than `NONE`.
- [ ] `supabase/functions/` appears in `Evaluate-PreApprovalEvidence` only, and neither `Profiles` nor `Get-ControlSurface` was modified.
- [ ] The harness proves a contract scoped only to `supabase/functions/**` is refused, and asserts from the Gate's `VERIFICATION:` line that it derives `REPOSITORY` and nothing else.
- [ ] `changes/SPEC-197-membership-authority-and-audit.md` is byte-identical to its state at the start of this Change Request, despite being carried in Write Scope for range publishability.
- [ ] A contract whose derived profile set contains any entry other than `REPOSITORY` is applicable, and the previous `-contains 'CONTROL'` test no longer appears in that function.
- [ ] A contract with no `## Pre-Approval Evidence` section is not made applicable by the irreversible-action input.
- [ ] The non-applicable branch returns `NOT APPLICABLE`, and every applicable passing path still returns `PASS`.
- [ ] `scripts/test_agent_continuity.ps1` contains the sentinels `APPROVAL-EVIDENCE APPLICABILITY` and `APPROVAL-EVIDENCE APPLICABILITY POPULATION`.
- [ ] The harness proves a `DATABASE`-scope contract is refused for an `UNKNOWN` consumer disposition, for a gate inside its own red window, and for an absent evidence section.
- [ ] The harness proves a `REPOSITORY`-only contract declaring an irreversible action step is refused rather than exempted.
- [ ] The harness proves the `DATABASE` fixtures derive `DATABASE` and do not derive `CONTROL`, read from the Gate's own `VERIFICATION:` line.
- [ ] The harness proves a `DATABASE`-scope contract carrying complete valid evidence is admitted.
- [ ] Assertion 177 still reports `APPROVAL_EVIDENCE: PASS` for a CONTROL contract with complete evidence, and assertion 178 still admits a `REPOSITORY`-only contract with no evidence section.
- [ ] Accept, reject and mutation population counters exist for the new applicability family.
- [ ] Every mutation named in this contract's Mutation Obligation is independently killed by the unchanged focused assertions.
- [ ] `npx`-free `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` reports zero failures.
- [ ] `ENGINEERING_METHOD.md`, `CR_LIFECYCLE.md`, `changes/TEMPLATE.md` and `changes/SPEC-196-pre-approval-evidence-sufficiency.md` are byte-identical to their state at the start of this Change Request.
- [ ] The Execution Log records which applicability inputs the ordinary automatic Gate derives for `changes/SPEC-197-membership-authority-and-audit.md`, with that contract left `Draft` and unedited.
- [ ] `_ORVION_CANONICAL/manifest.md` names SPEC-198 as `Last Completed`, and `ai-map.json`'s three live_state fields match it by value with LF line endings.
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

**Why the repair is a predicate and not an engine.** The temptation is to build something that can decide applicability for any contract by understanding it. `SPEC-196` explicitly refused that, and so does this: the question the code must answer is only *"does this Change Request require bounded Pre-Approval evidence evaluation?"*, and every input needed to answer it is already computed at the call site. The derived profile set arrives as a parameter, `Test-ControlPath` already exists, and the declared irreversible action is already inside the section being parsed. Three cheap reads replace one narrow read.

**Why "any non-`REPOSITORY` profile" rather than a list naming `DATABASE`.** `SPEC-196`'s own prose says "a derived non-`REPOSITORY` profile", and that phrasing is load-bearing: `REPOSITORY` is the profile every contract gets unconditionally, so "something other than REPOSITORY was derived" is exactly the statement "this change reached a surface the profile system considers special". Naming `DATABASE` explicitly would leave `CI` and `WORKSTATION` contracts with the same defect and would need editing again the next time a profile is added. The rule is therefore written against the shape of the profile system, not against a list of its current members.

**Why a second contract's file sits in this one's Write Scope.** `changes/SPEC-197-membership-authority-and-audit.md` is carried for **range publishability only**, and this contract must not change a byte of it — an obligation pinned by an Acceptance Criterion rather than left to good intentions. The reason is mechanical and was reproduced before Approval in a disposable clone carrying the real commit topology: the publishable range is `origin/main..HEAD`, its net diff already contains the `SPEC-197` Draft commit `67e6092`, and the endpoint scope check refuses any path in that diff which is neither the governing contract nor in its Write Scope. The simulated `Draft -> Approved -> In Progress -> implementation -> Complete` range was refused `OUT_OF_SCOPE_WRITE:changes/SPEC-197-membership-authority-and-audit.md`. Listing that file in Out of Scope instead — which this contract originally did — is precisely what makes such a range unpublishable, and is the same lesson this repository already learned when a cancelled contract had to ride in its replacement's Write Scope.

**Cross-path coverage is closed by enumerating execution SURFACES, not by understanding change semantics.** `ENGINEERING_METHOD.md §5` defines cross-path work semantically — triggers, RLS, grants, SECURITY DEFINER functions, lifecycle and catalog enforcement, events, permissions, vocabulary, columns, constraints, authorization helpers. Detecting that semantically would be the classifier `SPEC-196` forbids. The tractable question instead is: *which places in this repository can a cross-path rule live?* Measured against the tracked tree, there are five, and after this repair each is reached by a mechanical input: database rules under `supabase/migrations/**` and `supabase/tests/**` (`DATABASE` profile); the control plane (`Get-ControlSurface`); CI under `.github/workflows/**` (`CI`); workstation surfaces (`WORKSTATION`); and Edge Functions under `supabase/functions/**` (the arm this contract adds). Before this repair the fifth was reached by nothing at all, which was reproduced rather than reasoned: a contract scoped to `supabase/functions/storage-executor/index.ts` derived `VERIFICATION: REPOSITORY` alone and was admitted with `APPROVAL_EVIDENCE: PASS` on evidence invalid three ways. Cross-path applicability is therefore complete **by construction over surfaces**, and the claim is falsifiable in one step: if a sixth executable surface is ever added, this enumeration is wrong and the finding is a new one with its own evidence.

**Why the Edge Function arm is not simply added to the `DATABASE` profile.** That was the first thing tried and it was rejected on measurement, not taste. `Profiles` decides which verification protocol `-Finish` executes, so adding `supabase/functions/` there would force a clean `db reset`, both pgTAP passes, every named HTTP suite and the smoke to run for a TypeScript change that touches no schema. Worse, that profile's own comment states it "must not disagree with `.github/workflows/migration-ci.yml`", and that workflow's `push:` filters are `supabase/migrations/**`, `supabase/tests/**`, `supabase/config.toml` and `scripts/verify_database.sql` — no Edge Functions. Adding the path to the profile alone would manufacture exactly the two-authorities disagreement the comment exists to prevent, and closing that would require a CI change this contract has no authority to make. Whether Edge Functions *should* join Migration CI and the DATABASE protocol is a real, separate question; it is recorded as a successor rather than smuggled in here. The applicability predicate, by contrast, changes what is *evaluated before Approval* and nothing about what is *executed*, which is why the arm lives there and only there.

**What this contract deliberately does not do.** It does not touch `ENGINEERING_METHOD.md` or `CR_LIFECYCLE.md`: the authority already says the right thing, and editing authority to match an implementation is the inversion this repository exists to prevent. It does not revisit any of `SPEC-196`'s D/F/H-J predicates, their vocabulary, or the K identity machinery — those were proven and are untouched. It does not repair `CTRL-1`, which is a different activation defect with its own register row. And it does not modify `changes/SPEC-197-membership-authority-and-audit.md`, which stays `Draft` and is re-evaluated through the normal automatic path only after this repair is published.

**Relationship to `SPEC-197`.** `SPEC-197` is the Draft that exposed this and is the first contract that will be judged by the repaired predicate. It is not blocked by a defect of its own: its evidence section was authored complete and, when the same evaluator function was called with applicability forced, it returned `PASS`, and a deliberately re-injected `SPEC-195` red-window contradiction in a scratch copy returned `APPROVAL_EVIDENCE:FAIL`. That forced result is recorded here as context and is explicitly **not** the basis for approving it. Its real Pre-Approval result must come from the ordinary automatic Gate after this contract is Complete and published.
