# Change Request — SPEC-173

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
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

Resume Step: 1
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

- [ ] The certification target branch is derived in exactly one place and read from the receipt by
      `-Certify`; no second branch parser is introduced.
- [ ] `-Certify` queries GitHub with the exact SHA, the receipt's target branch, the `push` event and
      an explicit bounded limit, and independently revalidates `headSha`, `headBranch` and `event` on
      every row it judges.
- [ ] One SHA carrying a preflight failure beside a main success certifies READY for target `main`.
- [ ] The inverted shape — preflight success beside main failure — is FAILED.
- [ ] Success only on another branch, and success only under another event, are each not READY.
- [ ] A receipt written before this change fails closed and names `-Finish` as the remedy.
- [ ] A target ref that no longer equals the certified SHA is FAILED, not READY.
- [ ] Unavailable or malformed GitHub evidence is not READY.
- [ ] Assertions 94 and 104 to 108b still exist and still pass.
- [ ] Each newly claimed mechanism is killed by a mutant of that mechanism: removing branch
      filtering, removing `headBranch` revalidation behind a permissive filter, removing event
      enforcement, and removing the target-ref comparison.
- [ ] `.github/workflows/orvion-acceptance.yml` names the runner family and the exact checkout commit
      SHA the first shadow proof executed, and structural assertions fail if either is lost.
- [ ] Structural assertions prove exactly one active job can emit `orvion-acceptance`, that the
      acceptance workflow has no trigger path filter, and that the acceptance job carries no
      job-level condition and no `continue-on-error`, while the cleanup step's `if: always()` remains
      legal.
- [ ] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` passes with zero failures.
- [ ] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it
      is in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log

None.

## Verification Notes

None.

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
