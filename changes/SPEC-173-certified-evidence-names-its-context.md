# Change Request — SPEC-173

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make remote certification context-correct, and freeze the trust boundary the first shadow proof
actually executed, so the subsequent Phase-C Ruleset cutover rests on evidence that names its own
context.

The invariant certification must prove is not "this SHA has green runs". It is:

```text
exact artifact SHA
+ exact intended branch/ref
+ exact event
+ expected workflow identity
+ target ref still pointing at that SHA
```

`REMOTE_CERTIFY: READY` is forbidden unless all of those agree.

## Business Reason

`-Certify` asks GitHub only `gh run list --commit <sha>`. It requests `workflowName`, `conclusion`
and `status`, and nothing that says WHERE or WHY a run happened. The Simple Acceptance model pushes
one SHA twice — first to `orvion-preflight` to qualify it, then to `main` to promote it — so a single
SHA legitimately carries two runs of each legacy workflow, covering different ranges and reaching
different conclusions.

Measured on the current `main` SHA `18abbea`:

```text
Agent Control          main              push  success
Agent Control          orvion-preflight  push  FAILURE
ORVION Acceptance      orvion-preflight  push  success
Repository Consistency main              push  success
Repository Consistency orvion-preflight  push  success
```

`-Certify` reports `REMOTE_CERTIFY: FAILED — EVIDENCE: Agent Control` on the strength of the
preflight row alone, while every run belonging to the promotion is green. The preflight failure is
correct in its own context: legacy `Agent Control` derives its base from `github.event.before`, which
was `d0bba10` — the previous preflight tip — and that range carries three `Complete` contracts
(`SPEC-170`, `SPEC-171`, `SPEC-172`), so `AMBIGUOUS_GOVERNING_CR` is the Gate working, not failing.

This is not a one-time artefact of a stale branch. `github.event.before` is the previous tip of the
PUSHED ref, independent of `main`, so preflight and `main` diverge again the first time acceptance
rejects a candidate — that candidate stays on preflight and is never promoted. The shadow doing its
job is what re-creates the condition.

The consequence is a hard block rather than a nuisance: the failing run is permanent on that SHA, and
re-running it replays the same `event.before` and fails identically. No SHA promoted this way can
ever certify, so the programme's own rule — `REMOTE_CERTIFY: READY` before the next unit — and the
Phase-C prerequisite are both unsatisfiable until certification learns to name its context.

The native filters already answer this, proven live:

```text
gh run list --commit 18abbea --branch main --event push
  -> Repository Consistency success, Agent Control success
```

which is exactly the expected set. No custom GitHub API layer is needed.

Three further gaps are closed while this function is open, because they are the same question asked
about different fields. `-Certify` never verifies that the runs it read describe the SHA it asked
about; it never confirms the remote target ref still points at the certified SHA, so READY can be
reported for a SHA `main` has already moved past; and it passes no `--limit`, so it inherits the
CLI default and could silently judge a truncated view.

Separately, `orvion-acceptance` is about to become a required check. It currently names
`ubuntu-latest` and `actions/checkout@v6`, both of which move. The environment the first full shadow
proof actually executed was the runner family `ubuntu-24.04` and checkout resolved to
`d23441a48e516b6c34aea4fa41551a30e30af803`. Freezing those two values keeps the boundary equal to the
one that was proven. Nothing is upgraded.

## Risks

Low, and every residual risk fails closed.

Certification becomes stricter, so the realistic failure is refusing evidence that should have
counted. Three narrowing decisions carry that risk: a run on another branch, a run under another
event, and a run whose returned fields contradict the query. Each is asserted in both directions —
the accepting case (preflight failure beside main success certifies READY for target `main`) is
asserted alongside the rejecting ones, so the narrowing cannot quietly become a blanket refusal.

Receipts written before this change carry no target branch. They fail closed and require a fresh
`-Finish` rather than being interpreted with a guessed default, because guessing the branch is the
defect being removed.

Requiring the remote target ref to still equal the certified SHA adds a fetch, and therefore a
dependency on the network being reachable at certification time. An unreachable remote is reported as
not-READY rather than assumed unchanged.

Pinning `actions/checkout` to a commit SHA transfers upgrade responsibility to a human: the pin will
not move on its own. That is the intent. The release is named in a comment so the next maintainer can
see what the pin is, and a structural assertion makes silent loss of the pin visible.

The structural guards are the sharpest risk in this unit, because a crude assertion would be worse
than none — banning the token `if:` outright would forbid the cleanup step's legitimate
`if: always()`. They are therefore written against parsed job-level structure, and each is
mutation-tested against a counterexample rather than trusted because it passes today.

## Supersedes / Depends On

Corrects the remote-certification mechanism introduced by
`changes/SPEC-164-agent-control-evidence-lifecycle-closure.md` and the acceptance workflow introduced
by `changes/SPEC-168-shadow-acceptance-workflow.md`. Both are `Complete` and terminal and are
therefore not modified.

## Write Scope

- `changes/SPEC-173-certified-evidence-names-its-context.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `.github/workflows/orvion-acceptance.yml`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `scripts/check_repository_consistency.ps1`
- `package.json`
- `package-lock.json`
- `changes/SPEC-164-agent-control-evidence-lifecycle-closure.md`
- `changes/SPEC-168-shadow-acceptance-workflow.md`
- `changes/SPEC-172-acceptance-carries-the-evidence-it-replaces.md`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `supabase/migrations`

## Required Reading

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `.github/workflows/orvion-acceptance.yml`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Implementation Steps

1. Check for `Target-Branch` in `scripts/check_agent_continuity.ps1`. If absent, add one function
   that derives the certification target branch from Git, give `Workflow-Expectations` a branch
   parameter instead of deriving it internally, pass that one value from `Write-Certification`, and
   persist it in the local certification receipt. One derivation, one owner, read back by everything
   that needs it.
2. Check for `--branch` inside `Certify-Remote` in `scripts/check_agent_continuity.ps1`. If absent,
   make it read the target branch from the receipt and fail closed when the receipt carries none,
   naming a fresh `-Finish` as the remedy; query with the exact SHA, that target branch, the `push`
   event and an explicit bounded result limit; request `attempt`, `conclusion`, `databaseId`,
   `event`, `headBranch`, `headSha`, `status` and `workflowName`; and independently revalidate every
   returned row's `headSha`, `headBranch` and `event`, discarding any row that fails so the existing
   missing/running/failed judgement sees only rows proven to be in context. Report discarded rows
   rather than dropping them silently. Add no attempt-selection logic unless Step 0's probe is
   contradicted by the fixtures.
3. Check for `TARGET_REF_MOVED` in `scripts/check_agent_continuity.ps1`. If absent, make `-Certify`
   read the remote target ref and refuse READY unless it still equals the certified SHA, failing
   closed when the remote cannot be read at all.
4. Check for `ORVION_STUB_GH_PERMISSIVE` in `scripts/test_agent_continuity.ps1`. If absent, upgrade
   the `gh` stub so it honours `--branch` and `--event` by filtering the rows it returns, and ignores
   those filters when that variable is set so a deliberately permissive GitHub can be modelled;
   extend the run fixture helper with branch, event and SHA; and give the existing expected-set
   helper the target the new receipt requires.
5. Check for `Assert '144` in `scripts/test_agent_continuity.ps1`. If absent, add the context cases:
   a preflight failure beside a main success on one SHA certifies READY for target `main`; the same
   shape inverted is FAILED; success only on another branch is not READY; success only under another
   event is not READY; a receipt carrying no target fails closed; and a target ref that has moved away
   from the certified SHA is FAILED. Keep assertions 94 and 104 to 108b.
6. Check for `ubuntu-24.04` in `.github/workflows/orvion-acceptance.yml`. If absent, freeze the
   environment the first shadow proof actually executed — the runner family it ran on, and
   `actions/checkout` at the exact full commit SHA that run resolved — with a comment naming the
   release the pin corresponds to. Upgrade nothing.
7. Check for `Assert '150` in `scripts/test_agent_continuity.ps1`. If absent, add structural
   assertions over the active workflow set that fail if more than one active job could emit the
   required context `orvion-acceptance`, if the acceptance workflow gains a `paths:` or
   `paths-ignore:` trigger filter, if the acceptance job gains a job-level condition or
   `continue-on-error`, or if the runner family and checkout pin proven by the shadow are lost. Judge
   job-level keys separately from step-level keys so the cleanup step's `if: always()` remains legal.
8. Check that `_ORVION_CANONICAL/manifest.md` names
   `changes/SPEC-173-certified-evidence-names-its-context.md` as the Active Change Request. If it does
   not, set it, and regenerate `ai-map.json` with
   `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [x] The certification target branch is derived in exactly one place and read from the receipt by
      `-Certify`; no second branch parser is introduced.
- [x] `-Certify` queries GitHub with the exact SHA, the receipt's target branch, the `push` event and
      an explicit bounded limit, and independently revalidates `headSha`, `headBranch` and `event` on
      every row it judges.
- [x] One SHA carrying a preflight failure beside a main success certifies READY for target `main`.
- [x] The inverted shape — preflight success beside main failure — is FAILED.
- [x] Success only on another branch, and success only under another event, are each not READY.
- [x] A receipt written before this change fails closed and names `-Finish` as the remedy.
- [x] A target ref that no longer equals the certified SHA is FAILED, not READY.
- [x] Unavailable or malformed GitHub evidence is not READY.
- [x] Assertions 94 and 104 to 108b still exist and still pass.
- [x] Each newly claimed mechanism is killed by a mutant of that mechanism: removing branch
      filtering, removing `headBranch` revalidation behind a permissive filter, removing event
      enforcement, and removing the target-ref comparison.
- [x] `.github/workflows/orvion-acceptance.yml` names the runner family and the exact checkout commit
      SHA the first shadow proof executed, and structural assertions fail if either is lost.
- [x] Structural assertions prove exactly one active job can emit `orvion-acceptance`, that the
      acceptance workflow has no trigger path filter, and that the acceptance job carries no
      job-level condition and no `continue-on-error`, while the cleanup step's `if: always()` remains
      legal.
- [x] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` passes with zero failures.
- [x] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it
      is in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log

### 2026-09-12 — Claude Opus 5 (agent execution run)

Outcome: Complete

Step results:

- Step 1: Applied — `Target-Branch` added; `Workflow-Expectations` takes the branch as a parameter
  instead of deriving it; `Write-Certification` derives it once, passes it, and persists it as
  `target`.
- Step 2: Applied — `Certify-Remote` reads `target` from the receipt and fails closed without it;
  queries `--commit <sha> --branch <target> --event push --limit 100` requesting `attempt`,
  `conclusion`, `databaseId`, `event`, `headBranch`, `headSha`, `status`, `workflowName`; and
  revalidates `headSha`, `headBranch` and `event` on every row, discarding and naming those that
  contradict the query. No attempt-selection logic was written.
- Step 3: Applied — `TARGET_REF_MOVED` and `TARGET_REF_UNREADABLE`; READY requires the remote target
  ref to still equal the certified SHA.
- Step 4: Applied — the `gh` stub honours `--branch` and `--event`, and ignores them under
  `ORVION_STUB_GH_PERMISSIVE`; `Run1` carries branch, event and SHA; `GhRuns` backfills `headSha`;
  `ExpectBoth` carries the target.
- Step 5: Applied — assertions 144 to 149.
- Step 6: Applied — `ubuntu-24.04` and `actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803`
  (`v6.1.0`), both taken from the successful shadow run's own log. Nothing upgraded.
- Step 7: Applied — assertions 150 to 153, plus 154.

Suite: 143 → 154 passed / 0 failed.

PRECHECK. Every claim was measured on the unmodified tree before any edit:

| Claim | Measurement |
| --- | --- |
| certification is context-blind | `Certify-Remote` queried `--commit` only and requested `workflowName,conclusion,status` — no field naming branch, event or SHA |
| the defect is live, not theoretical | `-Certify` on `18abbea` returned `FAILED — EVIDENCE: Agent Control` while both `main` runs were green |
| the failing row is correct in context | `BASE_SHA=d0bba10`, and that range carries `Complete` `SPEC-170`, `SPEC-171`, `SPEC-172` — three governing contracts |
| the native filters suffice | `gh run list --commit 18abbea --branch main --event push` returned exactly the expected set |
| no target branch is recorded | receipt fields were `cr`, `profiles`, `fingerprint`, `expected`, `result`, `at` |
| the check identity is unique | six active jobs across six active workflows; exactly one emits `orvion-acceptance` |
| no classic-status collision | `commits/<sha>/status` reported `total_count=0` |

RERUN PROBE (Step 0 of the owner's decision, performed before drafting). Run `33859041123`
(`Repository Consistency`, attempt 2) is a real rerun in this repository. `gh run list` returns ONE
row for it carrying `attempt=2` and that attempt's conclusion; attempt 1 is reachable only through
`/attempts/1` and never appears as a separate row; across 200 rows no `databaseId` repeated; and
`head_sha`, `head_branch` and `event` were identical on both attempts. Both required invariants hold
natively, so `attempt` is requested as evidence and no attempt-selection logic exists.

MUTATION ANALYSIS. Four single-line mutants, each in its own detached worktree, each carrying a
byte-identical copy of the suite, and each verified to differ from the real implementation by exactly
one line before being run. Run sequentially in the foreground:

| Mutant | Mechanism removed | Killed | Collateral |
| --- | --- | --- | --- |
| M1 | `--branch`/`--event` dropped from the query | 154 only | none (153 passed) |
| M2 | `headBranch` revalidation → `if($false)` | 146 only | none (153 passed) |
| M3 | `event` revalidation → `if($false)` | 147 only | none (153 passed) |
| M4 | remote-vs-certified SHA comparison → `if($false)` | 149 only | none (153 passed) |

M2 and M3 were run against the PERMISSIVE stub, so the query could not rescue them and the
revalidation is proven independently causal. M3 left `--branch` in the query, so branch filtering
cannot be why 147 died — event protection is what is proven.

Engineering Observations:

1. **The query filters and the row revalidation are redundant for correctness, and that is stated
   rather than hidden.** With revalidation in place, deleting `--branch` still produces the right
   verdict from a wider result set, so no behavioural case can kill M1. What the filters actually buy
   is a bounded, relevant window: `--limit 100` only bounds honestly if the query is narrow, or a SHA
   that accumulates runs could push required evidence out of view and read as
   `REQUIRED_WORKFLOW_MISSING`. Assertion 154 therefore asserts the QUERY, and is the only thing that
   would notice the query silently widening. Revalidation is the load-bearing half; the filters are
   the bound.
2. **`ConvertFrom-Json` emits a JSON array as ONE pipeline item, and the old code carried that shape
   harmlessly.** `@($raw|ConvertFrom-Json)` yields a single element that IS the array, so
   `foreach($r in $all)` iterated once holding every run at once. The previous implementation never
   noticed because it only read members across the collection, which PowerShell flattens; it becomes
   a real defect the moment individual rows are inspected. Assign first, then wrap. The identical bug
   was introduced into the test stub at the same time and produced a triple-nested array — and the
   repaired implementation correctly fail-closed on that malformed evidence, which is how it was
   found.
3. **A bare `a,b,c` argument changes type with the resolved command.** It reaches a native executable
   as one string but becomes an ARRAY when the resolved command is a PowerShell script, which is why
   the stub logged `--json System.Object[]`. The field list is now quoted so it is one token either
   way. Real `gh` was never affected.

Commits: recorded by the Complete commit that carries this entry.

## Verification Notes

### 2026-09-12 — Claude Opus 5 (review)

Verdict: Confirmed Complete

Findings: re-checked against the live tree, the live GitHub state and the mutants, not against the
Execution Log.

- The target branch has exactly one derivation. `Target-Branch` is the only
  `rev-parse --abbrev-ref HEAD` for this purpose; `Workflow-Expectations` no longer derives it, and
  `-Certify` reads it from the receipt and never computes it. `Git-State`'s upstream check derives a
  different fact and is untouched.
- Every row judged is proven in context, and every row discarded is named on an `IGNORED:` line
  rather than dropped silently. A discarded row leaves its workflow MISSING, which fails closed.
- READY now requires the remote target ref to still equal the certified SHA. Both failure directions
  are covered: `TARGET_REF_MOVED` when it points elsewhere, `TARGET_REF_UNREADABLE` when the remote
  cannot be read at all.
- Receipts predating this change fail closed and name `-Finish` as the remedy (assertion 148). No
  default branch is guessed.
- The four mutation proofs are one-to-one with zero collateral: `153 passed, 1 failed` on each, the
  single failure being the assertion that names the removed mechanism.
- Assertions 94 and 104 to 108b all still exist and pass, adapted only where the new receipt contract
  required a `target` — their meaning is unchanged.
- Write Scope compliance verified mechanically: `git diff --name-only origin/main` lists exactly the
  six declared files. `scripts/check_repository_consistency.ps1`, `package.json`,
  `package-lock.json`, Migration CI, Agent Control and both Claude workflows are untouched.
- The acceptance change is only the approved freeze — `ubuntu-24.04` and the checkout commit SHA the
  proven run resolved. No dependency was upgraded.
- Repository Consistency: CLEAN. `git diff --check`: exit 0. Suite: 154 passed, 0 failed.

Not proven here, and deliberately not claimed: that `REMOTE_CERTIFY` returns READY on a promoted SHA.
That requires this candidate to complete the publication cycle, and it has not run yet. Nothing in
this contract asserts the repaired certifier has been exercised against real GitHub evidence.

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

**Rerun semantics were measured, not designed.** Before this contract was drafted, the repository's
own history was probed for a real rerun: run `33859041123`, `Repository Consistency`, attempt 2.
`gh run list` returns exactly ONE row for it, carrying `attempt=2` and that attempt's conclusion;
attempt 1 is reachable only through the attempts API and never appears as a separate row. Across 200
rows no `databaseId` appeared twice. `head_sha`, `head_branch` and `event` were identical on both
attempts. Both required invariants therefore hold natively — a current failed attempt cannot be
hidden by an old success, and an old failed attempt cannot poison a later successful current attempt
— so `attempt` is requested as evidence and NO attempt-selection logic is written.

**Legacy `Agent Control` is deliberately untouched.** Its `event.before` semantics are understood and
correct for the question it asks. It is not repaired here, and `branches-ignore` is not reintroduced.
New evidence may eventually make narrowing it earned for a reason unrelated to the cancelled
`SPEC-169` rationale — `orvion-acceptance` now runs the Agent Control mutation suite and the correct
`origin/main..candidate` Gate itself — but that is a separate decision recorded for the future
Publisher/recovery unit, not an action in this one.

**Deliberately not added.** No custom GitHub API framework, no second branch parser, no
attempt-selection logic, no rerun state machine, no publisher or recovery script, no repository-wide
Action pin enforcement, no `setup-node`, no Supabase or checkout upgrade, no change to Migration CI
which remains OBSERVE ONLY until the first real Batch-6 database slice can compare it against
acceptance by evidence.

**Registry flakiness is recorded, not acted on.** The successful shadow run contained ten
`toomanyrequests / Rate exceeded` lines with ten retries and still passed. No `--exclude` and no
Docker pull optimisation is introduced.

**Phase C is not performed by this contract.** The `main integrity` Ruleset keeps `non_fast_forward`
and `deletion` with zero bypass actors, and gains no required check here.
