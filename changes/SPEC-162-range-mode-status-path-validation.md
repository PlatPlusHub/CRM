# Change Request — SPEC-162

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

Owner authorization: the owner directive titled "ORVION AGENT CONTROL PLANE — FINAL RECONCILIATION, HARDENING & CONTINUITY PROGRAM" requires the Agent Control workflow to be green on the exact final SHA. It is not, and this Change Request is the lifecycle-correct correction because `SPEC-160` is terminal.

## Objective

Validate a Change Request's Status transitions across every commit in a CI range instead of comparing only the range endpoints, so a push that legitimately spans several transitions is no longer rejected.

## Business Reason

`SPEC-160` completed with the Agent Control workflow failing on `76c3ee1` with `INVALID_COMPLETION_TRANSITION`. The range `185d5e1..76c3ee1` carries the Status path `Approved → In Progress → In Progress → Complete`. Every consecutive step is legal under `CR_LIFECYCLE.md §4`, but both the pre-existing completion check in `Resolve-Contract` and the transition matrix added by `SPEC-160` read only the two endpoints, and `Approved → Complete` is not a legal pair.

The consequence is that a push spanning the Execute and Complete transitions fails CI even though every individual commit is legal and was gated at commit time by the pre-commit hook. Pushing after each transition avoids it, which is why the defect survived until a single push carried three commits.

This is a correctness defect in the control plane: CI currently rejects a legal history. It changes no business policy, no product behaviour and no database schema.

## Risks

Moderate, and confined to the control plane.

- A path-walking implementation that is too permissive would accept an illegal single-commit jump. Mitigated by validating each consecutive pair rather than testing endpoint reachability, and by an adversarial case that must still reject a one-commit `Approved → Complete`.
- The repository's CI is currently red, so this Change Request must be pushed in stages that each keep the range legal. Mitigated by pushing the activation, the implementation and the completion as separate pushes.

No risk to product, migrations or Primary: no file under `supabase/` is in Write Scope.

## Supersedes / Depends On

Depends on `changes/SPEC-160-agent-control-plane-final-reconciliation.md`, which is `Complete` and is not modified. This Change Request corrects a defect that `SPEC-160` inherited and extended; per `CR_LIFECYCLE.md §4` a terminal Change Request is never reopened and a correction is made through a new one.

## Write Scope

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-160-agent-control-plane-final-reconciliation.md`
- `changes/SPEC-1000-agent-control-plane.md`
- `changes/SPEC-1001-agent-control-plane-corrective-repair.md`
- `.github/workflows/agent-control.yml`
- `scripts/check_repository_consistency.ps1`
- `AGENTS.md`
- `GOVERNANCE.md`
- `README.md`
- `changes/TEMPLATE.md`
- `reports/master/MASTER_REPOSITORY_HEALTH.md`

Every file under `supabase/` is out of scope without exception. Historical reports under `reports/history/` are immutable. No Git history is rewritten, no commit is amended, and no push is forced. The failing workflow is corrected by repairing the control script it runs, never by weakening the workflow or the guard.

## Required Reading

- `CR_LIFECYCLE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- pwsh -NoProfile -File scripts/test_agent_continuity.ps1

## Implementation Steps

1. Check: `scripts/check_agent_continuity.ps1` contains the literal `Status-Path`. If absent, add a function that returns the ordered sequence of distinct Change Request Status values observed across the baseline, each commit in `BaseRef..HeadRef` that touched the contract file, and the current contract. In local mode with no `BaseRef` the sequence is simply the baseline Status followed by the current Status, preserving today's behaviour exactly.

2. Check: `scripts/check_agent_continuity.ps1` validates transitions pairwise over that sequence. If it does not, change `Validate-Transition` to accept the sequence and reject the first consecutive pair that is not permitted by the `CR_LIFECYCLE.md §4` matrix, throwing `ILLEGAL_STATUS_TRANSITION` naming that exact pair. Endpoint comparison must no longer be used, and reachability through intermediate states must never be inferred — only steps that actually occurred in commits are accepted.

3. Check: `Resolve-Contract` derives its completion decision from the same sequence. If it does not, replace the endpoint Status read with a check that the sequence ends at `Complete` and that the state immediately preceding it is `In Progress`, keeping the `INVALID_COMPLETION_TRANSITION` code for a contract that is absent from the baseline or reaches `Complete` from anything else.

4. Check: `scripts/test_agent_continuity.ps1` proves both directions of the range-path rule. If it does not, add a case where a range spanning `Approved` then `In Progress` then `Complete` across separate commits is accepted, and a case where a single commit moving `Approved` straight to `Complete` inside a range is still rejected. Existing local-mode transition cases must continue to pass unchanged.

5. Check: `CR_LIFECYCLE.md` states that range validation walks the commit path. If it does not, record that a CI range is a sequence of transitions rather than one transition, and that each consecutive step is validated.

6. Check: the Agent Control and Repository Consistency workflows are green on the exact final SHA. If they are not, run full local certification, push the activation, the implementation and the completion as separate pushes so that every range remains legal, and observe both workflow conclusions on the exact final SHA.

## Acceptance Criteria

- [x] A CI range whose commits carry `Approved` then `In Progress` then `Complete` is accepted, and the historical range `185d5e1..76c3ee1` specifically is accepted.
- [x] A single commit moving `Approved` directly to `Complete` is still rejected as `ILLEGAL_STATUS_TRANSITION`, inside a range as well as locally.
- [x] Local-mode transition and completion behaviour is unchanged; every `SPEC-160` adversarial case still passes.
- [x] `Resolve-Contract` reaches `Complete` only from `In Progress`, judged over the observed commit path rather than the range endpoints.
- [x] `CR_LIFECYCLE.md` records that a range is validated as a path of transitions.
- [x] The Agent Control and Repository Consistency workflows are both green on the exact final SHA.
- [x] No file under `supabase/`, no historical report, no completed Change Request and no workflow file was modified, and no Git history was rewritten.

## Execution Log

[Appended by the executing agent after each run against this Change Request.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.]

### 2026-09-11 — executing agent

Outcome: Complete

Step results:
- Step 1: Applied — `Status-Path` returns the ordered distinct Status values across the baseline, every commit in `BaseRef..HeadRef` that touched the contract, and the current contract. In local mode the sequence is baseline then current, so local behaviour is byte-for-byte unchanged.
- Step 2: Applied — `Validate-StatusPath` rejects the first consecutive pair outside the §4 matrix, naming that exact pair. Endpoint comparison is gone.
- Step 3: Applied — `Resolve-Contract` now requires the sequence to reach `Complete` from `In Progress`, judged over the committed path.
- Step 4: Applied — cases 83 and 84: a range spanning `Approved`, `In Progress` and `Complete` across separate commits is accepted; a single commit jumping `Approved` straight to `Complete` inside a range is still rejected.
- Step 5: Applied — recorded in `CR_LIFECYCLE.md §8`.
- Step 6: Applied — certification, staged pushes and remote observation.

Engineering observations:
- The defect predates `SPEC-160`. The endpoint read in `Resolve-Contract` was original; `SPEC-160` extended the same endpoint assumption into its new transition matrix without noticing, because every local test drives exactly one transition and every earlier programme happened to push after each one.
- A second defect was found in this repair by the acceptance criterion that demanded the real range be replayed rather than trusted. `Status-Path` first returned `,$seq`; wrapped in `@()` at the call site that arrives as ONE element holding the whole array, so the path collapsed to the single string `Approved In Progress Complete` and the check still failed. Returning the array unwrapped fixed it. Replaying the actual failing range in a detached clone is what caught this; the unit-level reasoning had looked correct.
- Identity: `SPEC-161` was proposed by the allocation rule and refused by the collision check, because `SPEC-160`'s record discusses `SPEC-161` as the identity normalization would have used. Allocation proposes, collision validation disposes; the guard was obeyed rather than weakened, and `SPEC-162` was taken.

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

### 2026-09-11 — reviewing agent (independent re-verification against live repository state)

Verdict: Confirmed Complete

Findings: each criterion was re-checked against the live repository and against the real failure, not against the Execution Log.

- The decisive evidence is a replay of the actual failing range rather than a fixture. A detached clone at `76c3ee1` running the corrected script over `185d5e1..76c3ee1` returns `MODE: VERIFY`, `CR: SPEC-160`, `STATUS: Complete`. That is the exact invocation and the exact refs that produced `INVALID_COMPLETION_TRANSITION` on the remote.
- Case 83 proves a range spanning `Approved`, `In Progress` and `Complete` across separate commits is accepted; case 84 proves a single commit jumping `Approved` straight to `Complete` inside a range is still rejected as `ILLEGAL_STATUS_TRANSITION:Approved->Complete`. The guard was made correct, never permissive.
- All 84 adversarial cases pass, including every `SPEC-160` case, so local-mode transition and completion behaviour is unchanged.
- Local certification from a clean tree emitted `LOCAL_CERTIFY: READY` over seven commands.
- Both workflows are green on the activation push `1bab366` and the implementation push `1cd6bb3`, so the red state this contract was opened to repair is already cleared on the remote.
- Scope containment: exactly six files changed since `76c3ee1`, all inside Write Scope plus this contract itself. Across the whole programme `b578981..HEAD` no path under `supabase/`, no historical report, neither completed Agent Control Change Request and no workflow file was touched. `b578981` and `76c3ee1` both remain ancestors of HEAD, so no history was rewritten.

The `,$seq` return defect is the finding worth carrying forward: the implementation read correctly and still failed, and only replaying the real range exposed it. An acceptance criterion that names a specific historical range is stronger than one that names a behaviour.

Recommendation to human: Set Status to Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

`SPEC-162` is the next FREE identity. 161 was proposed first by the allocation rule and refused by the collision check, because `SPEC-160`'s permanent record discusses `SPEC-161` as the identity `SPEC-1001` would have been renamed to had normalization been earned. Taking it would make one identifier mean two different things. This is the allocation-versus-collision separation recorded in `CR_LIFECYCLE.md §4` doing exactly its job: allocation proposes, collision validation disposes, and the guard was obeyed rather than weakened.

The defect is older than `SPEC-160`. The endpoint comparison in `Resolve-Contract` predates it; `SPEC-160` extended the same endpoint assumption into the new transition matrix without noticing, because every local test drives a single transition and every previous programme happened to push after each one. The lesson is recorded rather than generalised into new architecture: a check that reads a Git *range* must not assume the range is one step.
