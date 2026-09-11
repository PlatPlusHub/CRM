# Change Request Lifecycle

## 1. Purpose

This document is the single authoritative reference for the Change Request in this repository — its states, allowed transitions, the responsibility for each transition, the command vocabulary that drives them, the canonical definitions of IMPLEMENT and Synchronization, and how mid-execution discoveries are handled. `AGENTS.md` holds the operating model and the boot sequence and points here for Change Request mechanics; where the two appear to differ on execution posture, `AGENTS.md` governs.

## 2. Lifecycle Overview

A Change Request begins as a proposal (`Draft`), authored against `changes/TEMPLATE.md`. A human approves it (`Approved`). An executing agent applies its Implementation Steps and synchronizes the Change Request's own state as the final part of the same task (`In Progress`). The work is then reviewed against the live repository, without trusting the Execution Log's self-report, and the findings are recorded — this activity does not change Status. The Change Request is closed once the Review Gate is satisfied (`Complete`). A Change Request may be abandoned at any point before closure (`Cancelled`). Throughout, the Change Request is a living repository artifact, not merely an instruction document — its own state is part of the work, not separate from it.

## 3. Official CR States

Exactly five, per `changes/TEMPLATE.md`:

- `Draft`
- `Approved`
- `In Progress`
- `Complete`
- `Cancelled`

No other status word is used. In particular, "Review" is not a Status value — it is an activity performed while Status remains `In Progress` (see §7).

## 4. Allowed State Transitions

| From | To |
| --- | --- |
| `Draft` | `Approved` |
| `Draft` | `Cancelled` |
| `Approved` | `In Progress` |
| `Approved` | `Cancelled` |
| `In Progress` | `Complete` |
| `In Progress` | `Cancelled` |

`Complete` and `Cancelled` are terminal. A closed Change Request is never reopened; a correction is made through a new Change Request (see `changes/SPEC-003-phase1-consistency-fix.md` for the established precedent).

Completed and cancelled Change Requests are terminal historical artifacts. The control Gate rejects their later modification, deletion, or rename; every correction requires a new Change Request. The 2026-09-11 Agent Control Plane identity correction is a one-time owner-authorized correction performed before this immutable-history guard was installed and is documented by `SPEC-1001`.

Because every Change Request that reaches a terminal state can never be reopened, and because only the *governing* Change Request is ever parsed against the contract schema, the schema may be strengthened without retroactively invalidating history. No contract-format version field is therefore carried: terminality is the format boundary.

### SPEC identity allocation

A SPEC identity is a repository-wide engineering identity, not a `changes/` filename. One identity names one unit of engineering work and may materialize as a Change Request file, a migration, a pgTAP test, a master-plan entry, or any combination — `SPEC-147` and `SPEC-155` through `SPEC-159` exist as real work with no Change Request file of their own, and sub-identities such as `SPEC-154-A` and `SPEC-159-A` attach to their parent.

Two distinct rules govern identity, and conflating them is exactly what produced the `SPEC-1000` jump:

- **Allocation** — a new identity is the next integer above the highest identity in the *real* engineering sequence. The synthetic band reserved for control-test fixtures by `scripts/test_agent_continuity.ps1` (currently `SPEC-404`, `SPEC-800`–`SPEC-802`, `SPEC-899`–`SPEC-901`) and illustrative non-existent identifiers used in historical reports (`SPEC-999`) are never real work and are excluded from that maximum.
- **Collision validation** — enforced mechanically by the Gate across the entire repository *including* the synthetic band: a newly added Change Request may never reuse an identifier that already appears in tracked filenames or tracked text (`SPEC_ID_ALREADY_USED`), and two newly added Change Requests may never introduce the same identifier in one diff (`DUPLICATE_NEW_SPEC_ID`).

Allocation decides which number to take; collision validation decides whether taking it is legal. A repository-wide textual maximum is the wrong allocator precisely because it observes fixtures — and the collision check is right to observe them.

**Collision validation treats any tracked textual occurrence as reserving the identifier, and this is intentional, not a defect to be repaired (decided 2026-09-11, `SPEC-163`).** It means a purely hypothetical mention in prose — `SPEC-160`'s Notes discussing `SPEC-161` as a rename target it never took — permanently retires that number. The alternative would require distinguishing an identity-bearing occurrence from a rhetorical one in arbitrary text, which no deterministic rule can do: `SPEC-147` and `SPEC-155`–`SPEC-159` are real work that exists only as migrations, tests and plan entries, and those look exactly like prose to a text search. The asymmetry decides it. An unused identifier costs nothing, because identifiers are free and the sequence is unbounded; a reused identity silently merges two units of engineering work and is unrecoverable. The Gate is therefore deliberately conservative, and a later agent must not "fix" this behaviour — cases 26, 27 and 93 of `scripts/test_agent_continuity.ps1` fix the rule in both directions.

## 5. Responsibility Of Each Transition

| Transition | Responsible party |
| --- | --- |
| `Draft` -> `Approved` | Human only |
| `Draft` -> `Cancelled` | Human only |
| `Approved` -> `In Progress` | The executing agent, as the first action of its own execution run |
| `Approved` -> `Cancelled` | Human only |
| `In Progress` -> `Complete` | The executing agent when the work is verified (a Review verdict of `Confirmed Complete`) AND introduces no new architectural decision — the deciding ADR or owner decision already exists; otherwise a human, after the Review Gate is satisfied |
| `In Progress` -> `Cancelled` | Human only |

**Autonomous completion** is part of execution (see `AGENTS.md` §2): when a capability is fully implemented, verified, passes its required tests, satisfies its acceptance criteria, and introduces no NEW architectural decision, the executing agent advances Status to `Complete`, syncs the manifest and docs, commits, and pushes without a separate approval gate. A capability that introduces a *new* decision still requires owner sign-off (usually an ADR) BEFORE it is built — only the *completion* of an already-decided, fully-proven capability is autonomous. `Cancelled` is always human-only.

## 6. Meaning Of IMPLEMENT

IMPLEMENT applies a Change Request's Implementation Steps exactly as written. IMPLEMENT is not considered complete until the Change Request has been synchronized with the execution state — its Status advanced to `In Progress` and its Execution Log appended — as the final part of the same task, not a separate action. Review and Complete remain independent phases and are not merged into IMPLEMENT.

The mutable `## Runtime Checkpoint` is the normal cold-start handoff: `Resume Step`, stable `Blocker`, and bounded `Recovery Attempt` only. It contains semantic progress, never HEAD, branch, timestamps, CI state, migration counts, or other facts derived live by Git/tooling. The append-only `## Execution Log` records meaningful durable outcomes rather than every routine session.

For new Change Requests, `## Additional Verification` is either `None` or exact executable repository-root PowerShell/shell commands, one bullet per command. It may add verification and can never subtract a scope-derived mandatory profile. Historical completed Change Requests are not retrofitted.

## 7. Meaning Of REVIEW

REVIEW is independent verification of a Change Request's execution against the live repository state, not against the Execution Log's self-report. REVIEW checks every Acceptance Criterion and every Review Gate item, and records its findings as a Verification Notes entry with a verdict (`Confirmed Complete`, `Discrepancy Found`, or `Needs Corrective Change Request`). REVIEW does not itself change Status — it is an activity performed while Status is `In Progress`. Completion follows REVIEW per §5.

## 8. Meaning Of Synchronization

A Change Request is a living repository artifact and the authoritative semantic state record of its work. Its declared Write Scope governs engineering artifacts; its own workflow-state sections are implicitly writable for synchronization and never a Write Scope violation.

Synchronization means updating only a Change Request's workflow-state sections — `Status` (only transitions permitted by §4), `Runtime Checkpoint`, `Acceptance Criteria`, `Review Gate`, `Execution Log`, and `Verification Notes`. Synchronization never authorizes modifying `Objective`, `Business Reason`, `Risks`, `Supersedes / Depends On`, `Write Scope`, `Out of Scope`, `Required Reading`, `Required Capabilities`, `Additional Verification`, or `Implementation Steps` after approval. Reading is repository-wide; only Write Scope grants create/modify/delete authority. Historical CRs retain their former `Scope` and `Minimum Reading List` headings. Execution Log and Verification Notes remain append-only.

**This partition is mechanically enforced, not merely declared (2026-09-11, `SPEC-160`).** The governing Change Request is exempt from ordinary Write Scope checking so that synchronization is possible at all; that exemption is safe only because every frozen field is compared against its Git baseline on every Gate. Specifically: a frozen field that differs from its baseline is rejected as `FROZEN_AUTHORITY_MUTATED`; `Execution Log` and `Verification Notes` must remain exact prefixes of their baseline (`EVIDENCE_NOT_APPEND_ONLY`), so a prior entry cannot be edited, deleted, reordered or truncated while appending stays legal; Acceptance Criteria and Review Gate wording and item count are fixed with only unchecked-to-checked permitted (`ACCEPTANCE_TEXT_MUTATED`, `REVIEW_GATE_TEXT_MUTATED`); Status changes are restricted to the §4 matrix (`ILLEGAL_STATUS_TRANSITION`); and a transition to `Complete` additionally requires every Acceptance Criterion and Review Gate item checked, `Blocker: None`, `Resume Step: DONE`, and a `Verdict: Confirmed Complete` entry (`COMPLETION_PREREQUISITE`). A Change Request that is `Approved` or `In Progress` while the manifest names no active pointer is rejected as `ORPHANED_APPROVED_CR`.

**A CI range is a sequence of transitions, never one transition (2026-09-11, `SPEC-162`).** A push may legitimately carry the Execute commit and the Complete commit together, giving the range endpoints `Approved` and `Complete` — which is not a legal pair even though every step between them is. Range validation therefore walks the Status actually recorded at each commit that touched the contract and checks each consecutive step; reachability through states that nobody committed is never inferred, so a single commit jumping `Approved` straight to `Complete` is still rejected. The same rule settles a contract **created inside that same range** (2026-09-12, `SPEC-165`): a small Change Request's whole lifecycle fits in one push, and requiring the contract to exist at the range base refused that legal history — it is how the `SPEC-164` push, whose committed path was `Approved -> In Progress -> Complete`, was rejected as `INVALID_COMPLETION_TRANSITION` and left `main` red. The base-existence test was redundant rather than protective: the committed path already rejects a single commit creating a contract as `Complete`, and a `Draft -> Complete` pair, because neither places `In Progress` immediately before `Complete`.

**Acceptance Criteria and Review Gate assert LOCAL evidence only, and a remote or external claim is never a completion checkbox (2026-09-11, `SPEC-163`).** A criterion reading "the workflows are green on the exact final SHA" cannot be true at the moment it is ticked: the commit that creates that SHA has not been made, let alone pushed, so requiring it checked before `Complete` is circular. That circularity is how a Change Request once reached `Complete` while CI was red. The three evidence classes therefore have three different owners. `LOCAL` evidence is executed by `-Finish`, which emits `LOCAL_CERTIFY: READY` only after every locally applicable command actually ran. `POST_PUSH` evidence is owned by `-Certify`, which reads the workflow conclusions recorded against the exact current `HEAD` SHA *after* the push and reports `READY`, `PENDING` or `FAILED`. `EXTERNAL` evidence — anything observable only from a live system this process cannot reach — is declared and never self-asserted. A contract may still describe remote expectations in its Notes; what it may not do is make `Complete` depend on a box whose evidence cannot exist yet.

**The manifest pointer and contract Status are ONE invariant, checked in both directions (2026-09-11, `SPEC-163`).** Only `Approved` and `In Progress` carry write authority, so only they may be pointed at. At most one contract may hold either status; if one does, the manifest must name exactly it (`ORPHANED_APPROVED_CR`), and if none does, the manifest must name `None`. A manifest naming a `Draft`, `Complete` or `Cancelled` contract is rejected as `MANIFEST_CR_CONTRADICTION`, because a `Draft` named as active made Boot print that contract's full `Write Scope` as though it were authority. The scan reads every contract on disk rather than only those in the current diff, so an orphan created before the current change is still found. The runtime mode that once named a Draft awaiting approval is consequently retired, because the state it described is now a contradiction; a Draft is authored in `PLAN`, which correctly reports no write authority. `SPEC-163` records the retired term.

**`Complete` must PROVE that Finish succeeded, not merely assert it (2026-09-11, `SPEC-164`).** Every prerequisite above is text the executing agent writes about itself: tick the boxes, write the verdict, set `Resume Step: DONE`, flip the Status. None of it required `-Finish` to have run, so work could reach `Complete` having never obtained `LOCAL_CERTIFY: READY`. A successful `-Finish` therefore writes a local certification receipt — `.orvion-local-certification.json`, untracked and gitignored — recording the Change Request identity, the derived verification profiles, a fingerprint of the Write Scope's file content, and the expected workflow set. A local `Complete` transition is refused unless a readable receipt matches all of identity, profiles and fingerprint (`COMPLETION_PREREQUISITE`). A boolean would not do: it survives an edit made after certification, which is exactly the stale-evidence case the fingerprint rejects. The receipt is an anti-omission and anti-staleness control and nothing more — the same process writes and reads it, so it resists forgetting and drift, never deliberate forgery. A CI range run holds no receipt and is exempt by design, because CI re-executes the certification rather than trusting a recorded one.

The baseline is Git itself — `HEAD` locally, the supplied range base in CI. The pre-commit hook runs the Gate, so a mutation of frozen authority cannot be committed at all, and the CI range check re-proves it across everything pushed. No fingerprint of the CONTRACT is stored, because a hash of frozen authority recomputed by the same agent it constrains proves nothing the Git baseline does not already prove. The certification receipt's fingerprint is a different object answering a different question: it covers the WORKING TREE that was verified, which is not a commit and about which Git can therefore say nothing at all.

## 9. Command Vocabulary

Handoff between agents happens through the active CR (including Runtime Checkpoint), manifest, Git, and executable evidence — never through chat. Run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Boot` to derive the current runtime mode and exact next action. Runtime modes (`PLAN`, `EXECUTE`, `VERIFY`, `BLOCKED`) and `CERTIFY` are not CR Status values.

`-Finish` is local executable certification: it runs the locally applicable derived profiles and every Additional Verification command, and only then may emit `LOCAL_CERTIFY: READY` and write the receipt §8 requires. When the `DATABASE` profile applies it executes the `ENGINEERING_METHOD.md §4` protocol rather than listing it, which is why such a contract must declare `supabase-local` and name its relevant `scripts/verify_*` suites. Remote CI success, when the CI profile applies, is separate observed evidence verified after push; local Finish never implies it.

`-Certify` is that post-push observation, and it is the only thing entitled to make it: run from the repository root after pushing, it reads the workflow conclusions recorded against the exact current `HEAD` SHA and reports `REMOTE_CERTIFY: READY`, `PENDING` or `FAILED`. It asserts nothing it did not read.

It also proves EXPECTED against OBSERVED before judging any conclusion (2026-09-11, `SPEC-164`). Asking only "did anything fail?" cannot see a required workflow that silently stopped triggering: it produces no run, so there is nothing to fail, and the remaining green workflow certifies the push on its own. The expected set is derived once, at Finish, from the `push:` triggers the workflow files themselves declare — an unfiltered `push:` always runs, a filtered one runs only when a written path matches, and a workflow with no `push:` trigger is never expected — and is recorded in the certification receipt, so `-Certify` re-derives nothing and no second authority for CI expectations exists. A required workflow that has produced no run on the exact SHA is `PENDING` while other runs are still settling and `FAILED` once they have all completed; success on any other SHA satisfies nothing. With no readable receipt, `-Certify` fails closed.

- **`Approve SPEC-NNN`** — requires Status `Draft`; flips Status to `Approved`, sets `manifest.md`'s `Active Change Request` to this Change Request's path, commits. If already `Approved` or further along, report that instead of re-applying.
- **`Execute SPEC-NNN`** — requires Status `Approved`; flips Status to `In Progress`, performs the Implementation Steps exactly as written, appends an `## Execution Log` entry, commits. If Status is still `Draft`, refuse — never treat `Execute` as an implicit `Approve`.
- **`Review SPEC-NNN`** — requires Status `In Progress` with at least one Execution Log entry; independently re-verifies every Acceptance Criterion and Review Gate item against the live repository state, appends a `## Verification Notes` entry, commits. If no Execution Log entry exists, report that there is nothing to review.
- **`Complete SPEC-NNN`** — requires a `## Verification Notes` entry with `Verdict: Confirmed Complete`; flips Status to `Complete` (by the executing agent when no new architectural decision is introduced, per §5, otherwise by a human); clears `manifest.md`'s `Active Change Request`; updates `manifest.md`'s `Current Module`, `Last Completed`, AND `Next capability` fields together — the just-completed work moves to `Last Completed` and `Next capability` is repointed to the next dependency-ready package, so the manifest can never leave `Next capability` naming a capability that is already complete (`Next capability` is a single field; do not restate "next" elsewhere in the manifest); if this is the last Change Request scoped to an active phase in `32_execution_roadmap.md`, notes in its Execution Log that `Freeze Phase N` may now apply (this never auto-invokes `Freeze Phase N`); commits; then publishes with `git push`, confirming no local commit remains ahead of the upstream (`git rev-list @{u}..HEAD` is empty). If the push cannot complete, the Complete transition remains valid locally — git history is the source of truth — and the commits publish on the next successful push. If no Verification Notes entry exists, perform `Review` first and stop; if it says `Discrepancy Found`, refuse and point to it.
- **`Start Phase N`** — requires the prior phase's status in `32_execution_roadmap.md` to be `Complete`; updates the roadmap's phase table and `manifest.md`'s Current Phase/Module/Task. If the prior phase is not `Complete`, flag it and wait.
- **`Freeze Phase N`** — requires every Change Request scoped to that phase to be `Complete` or `Cancelled`; updates that phase's status to `Complete` in the roadmap. If any scoped Change Request is still open, list them and refuse until addressed or explicitly overridden.

Every commit produced in response to a human command states, in its message, that it was human-directed and which command triggered it — e.g. `SPEC-NNN: Approve (human command)` — distinct from an agent's own step-execution or analytical commits.

## 10. State Machine

```text
Draft
  -> Approved     (human)
  -> Cancelled    (human)

Approved
  -> In Progress  (executing agent, first action of its own execution run)
  -> Cancelled    (human)

In Progress
  -> Complete     (executing agent when verified and no new decision; else human)
  -> Cancelled    (human)

  Review is an activity performed here, not a transition:
  Verification Notes are appended while Status remains In Progress.

Complete    (terminal)
Cancelled   (terminal)
```

## 11. Engineering Observations

A discovery made during IMPLEMENT or REVIEW that was not anticipated by the Change Request's Implementation Steps is recorded as an Engineering Observation. It stays inside the CR only if its repair is already explicitly authorized by Write Scope and objective, uses an existing mechanism, and requires no new judgment; otherwise it becomes a future CR. Never silently implement or discard it, and never widen approved Write Scope to absorb it.

An Observation concerning the engineering methodology itself — as distinct from repository content — never interrupts the Change Request that surfaced it. The current Change Request always completes its own lifecycle normally first; only afterward is a methodology refinement considered, and only through its own Change Request.

## 12. Relationship Between Governance Documents

- **`AGENTS.md`** — the operating model and boot sequence (how work is done, standing authorities, decision tiers, where to look next). Authoritative on execution posture. Points here for Change Request mechanics.
- **`CR_LIFECYCLE.md`** (this document) — the single authoritative reference for the Change Request state machine, command vocabulary, and the canonical definitions of IMPLEMENT and Synchronization.
- **`changes/TEMPLATE.md`** — the per-Change-Request document format; defines the fields every Change Request contains.
- **`GOVERNANCE.md`** — the knowledge/decision operating system (where every fact lives, decision/document lifecycles). Authoritative on knowledge placement; points here for CR mechanics.
- **`PROTOCOL.md`** / **`global-rules.md`** — RETIRED (2026-07-11) to tombstone pointers; own nothing exclusive. Conduct → `AGENTS.md`; knowledge → `GOVERNANCE.md`.
