# Change Request — SPEC-283

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Time every run of the control plane and keep its history, so that every mode, gate, stage, profile, verification command and test has a recorded, historically accessible time, `-Finish` can no longer run unobserved, and the existing watcher estimates the time left, reports labelled findings and summarises where time and failures concentrate.

## Business Reason

- **The owner's objective (2026-10-15):** full-cycle timing, live quality observation and evidence-based improvement feedback, without a second governance engine and without implementing the Improvement Loop.
- **Causal negative, measured.** `SPEC-282`'s `-Finish` was started directly. It printed no time, `scripts/watch_run.ps1` could not attach because it follows only `scripts/run_timed.ps1` logs, and the owner's question "how many minutes left" had no evidence-based answer. At `246284d` no mode of `scripts/check_agent_continuity.ps1` prints a time, the pre-commit hook and both workflows start it directly, and the timing history (`%LOCALAPPDATA%\ORVION\timings.csv`, 122 rows, 12 runs) holds only runs a watcher followed.
- **What already existed, and what each requirement needed** (repository evidence at `246284d`):

  | Requirement | Before | This contract |
  | --- | --- | --- |
  | Time every mode and gate, the hook, the publisher's and promoter's Gates, `-Certify` | MISSING | `TIME: <mode> hh:mm:ss` on every exit path; untimed runs appended to the history with their outcome |
  | Time each stage inside a run | MISSING | `TIME: STAGES <mode> setup= history= allocation= contract= repo-guard= git= pins= transition= range-walk= checks= verification= other=`, one line, summing to the run (measured: Repo-Guard is 14.7 of a 15-second Boot) |
  | Time every profile and verification command | MISSING | `TIME: <profile> <command>` and `TIME: PROFILE <name>` from `-Finish` |
  | Time every test | PARTIAL: `run_timed.ps1` stamped lines to 0.1 min, only when an agent used it, and nothing kept a test's time | Stamps to 0.001 min (0.06 s); the watcher records every `PASS`/`FAIL` test line and TAP line, failed ones included, with its own time, and prints only the failed ones; `-Finish` refuses to start outside the runner, and suites are started through it by rule |
  | CI timing | ALREADY SUPPORTED: GitHub keeps run, job and step timings; `watch_ci.ps1` reports minutes per run | Unchanged; the evaluator writes no history in CI |
  | Durable machine-readable history | PARTIAL: watched runs only, no outcome for an untimed run, no evidence reference, unbounded | One file outside the repository, one writer per run and one write path for every writer; outcome, head SHA, how it was started, log reference; the watcher's rows redacted of known credential shapes; at most 10 MB, enforced on every append |
  | Comparison and ETA | PARTIAL: total against the previous run only | ETA from the last 10 comparable successful runs (median and range, none below two, low sample below five); slow-step and slow-run findings; report of where the time goes |
  | Live quality findings | PARTIAL: results, heartbeat, runner gone | `[confirmed]` recurring failure; `[hypothesis]` repeated command, slow step or test, absent steps (one finding however many), slow run; each once per run |
  | Notifications to the working agent | Every result line, including passes (the V3 self-test sent 26) | `-Brief` for an agent's monitor: failures, findings, heartbeats, a progress line every 10 minutes with an ETA, and the end |
  | Normalised quality history | MISSING | `-Report`: failures ranked by their rate per run of the same name, recurring ones marked for investigation; the slowest stages and tests as views over the full history |
  | Owner-facing notification | Outside the repository | The agent uses its own client's notification; a local log is never called one |

- **Not in this contract:** a repository notification channel, ingesting CI timings into the local history (GitHub already keeps them), cross-machine history, and any automatic Skill, Guard, Hook or Change Request. Each is a separate decision if evidence later earns it.

## Risks

- **A verdict changed by timing.** The `TIME:` line is printed in a `finally` after the verdict, and `exit` keeps its code (PowerShell runs `finally` on `exit`; measured for exit 0, 1, 3 and an `exit` inside a function). Every parser of the evaluator's output reads its exit code or an exact `ORVION: READY` line. The history writer is wrapped so a failure to write prints `TIME_RECORD: not written` and changes nothing (283-T11).
- **A `-Finish` that cannot start.** It now needs `ORVION_TIMED_LOG`, which `scripts/run_timed.ps1` sets to its own log. `AGENTS.md`, `CR_LIFECYCLE.md` §9 and `ENGINEERING_METHOD.md` §3 give the command. The control suite's fixtures stand in for the runner.
- **Cost.** The writer adds about 48 ms to each untimed evaluator run (measured, 20 runs); one append through the shared write path takes about 2 ms (300 appends, measured). The watcher's steady cost stays under 2 s of CPU per minute (W5). The history never exceeds 10 MB: every append, by the evaluator or a watcher, checks the file's length and, past the limit, keeps the newest whole rows within 5 MB. At the measured 206 bytes a row that is about 50,000 rows, loaded and grouped in 1.2 s (10.3 MB measured), about 60 `-Finish` runs with every test. The control suite took 29.0 min (28.8 for D4 and 29.8 for D3 on the same machine); the watcher self-test took 7.1 min (6.5 for D4, 5.8 at `246284d`), the added minute being the six-writer concurrency case and the seven new mutants. With `-Brief`, the 29-minute suite produced two progress notifications and its end.
- **Concurrent writers.** The hook, a direct run and a watcher can append at the same moment. A named mutex per history file serialises every append, trim and watcher read across processes (W18: six concurrent writers, every row once and whole), and a trim writes the kept rows to a file beside the history and moves it over the history, so the history is never rewritten in place. A writer that cannot get the mutex within 15 s reports `TIME_RECORD: not written` or `history: row not written` and changes no verdict (283-T11).
- **Sensitive data.** What the watcher prints and writes to the history is redacted of values shaped like a known credential: GitHub's documented token prefixes, `sk-` keys, JWTs, a bearer value, and a `key=value` whose key names a credential (W12, W13). Redaction by pattern is not a guarantee. The runner's log, which each history row names as its evidence, is the run's raw output and is **not** redacted (W13 proves it keeps the line), as at `246284d`; it stays where the agent wrote it, outside the repository. The existing protection is unchanged: a credential never passes through the agent (`AGENTS.md`).
- No migration, schema, Primary or Secondary action, no workflow change, and no new script or authority.

## Supersedes / Depends On

None. Built on `SPEC-282` (`246284d`).

## Write Scope

- `changes/SPEC-283-every-run-is-timed-and-watched.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/watch_selftest.ps1`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `AGENTS.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/watch_ci.ps1`
- `scripts/check_repository_consistency.ps1`
- `.githooks/pre-commit`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `GOVERNANCE.md`
- `changes/SPEC-282-publication-and-the-template-say-what-the-gate-does.md`

## Required Reading

- `scripts/run_timed.ps1`, `scripts/watch_run.ps1` and `scripts/watch_selftest.ps1` (headers)
- `CR_LIFECYCLE.md` §9 (`-Finish`)
- `ENGINEERING_METHOD.md` §3 ("A long run is watched")
- `AGENTS.md` (the completion command and the adapters' boundary)

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- pwsh -NoProfile -File scripts/watch_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Every evaluator run ends with `TIME: <mode> hh:mm:ss` | `scripts/promote_main.ps1` (exact `ORVION: READY` line and exit code); `scripts/publish_candidate.ps1` (exit code); `.github/workflows/agent-control.yml` and `orvion-acceptance.yml` (exit code); `scripts/test_agent_continuity.ps1` case 18 (fewer than 20 lines) | VERIFY | No parser reads the last line. 283-T1 to T3 prove the exit code is kept in the hook shape and in CI's dot-sourced shape. |
| `-Finish` starts only under `scripts/run_timed.ps1` | `AGENTS.md` completion command; `CR_LIFECYCLE.md` §9; `scripts/test_agent_continuity.ps1` fixtures | WRITE | Step 1. 283-T5 and T6 refuse an untimed start before any verification and leave no receipt; the fixtures set `ORVION_TIMED_LOG`. |
| `scripts/run_timed.ps1` names its log to the command it runs | `scripts/watch_selftest.ps1` W0 to W8; the evaluator's guard | VERIFY | 283-T7; W15 proves the 0.06-second stamps; the watcher self-test passes in full. |
| Untimed runs are appended to the timing history with their outcome, through the one bounded, serialised write path | `scripts/watch_run.ps1` (writer, reader, ETA, findings, report); the history file, whose columns do not change | WRITE | 283-T8 to T11 and T13; one writer per run, so no row is recorded twice; W18 and W19 prove the shared write path under six concurrent writers. |
| The watcher's vocabulary, test classification, ETA, findings, report, redaction and bound | `scripts/watch_selftest.ps1`; agents following runs; `AGENTS.md`'s adapters boundary | WRITE | W9 to W19 and mutants M17 to M33, each killed. `AGENTS.md` now says the watchers never classify a failure's cause. |
| The rule in `ENGINEERING_METHOD.md` §3 | Its readers; repository consistency Check 27 | VERIFY | Prototype consistency CLEAN. |
| The manifest's Active Change Request names this contract, then `None.` | The Gate; `ai-map.json`, `repository-index.md` (Check 7) | WRITE | Set by the Approve and Complete commits and regenerated. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The eight target files hold their `246284d` blobs | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Repository consistency CLEAN and only Write Scope paths changed | BEFORE_COMPLETION | NONE | NONE | 2 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `scripts/run_timed.ps1`, `scripts/watch_run.ps1` and their history time only the runs an agent chooses to time, and the evaluator times nothing. They are extended; no script, file or authority is added.

Added Property: every evaluator run, profile and verification command is timed; every untimed run is recorded with its outcome; `-Finish` cannot start unobserved; the watcher estimates the time left and reports labelled, deduplicated findings and a normalised history.

Causal Negative: `SPEC-282`'s `-Finish` on 2026-10-15 was started directly, printed no time, and could not be followed by the watcher. Measured in a disposable clone of `246284d` with its unmodified evaluator (blob `d9d485b9a3bfa099af092648228e8bb005320471`): a READY Boot printed 7 lines and a refused Gate exited 1, and neither printed any time.

Positive Test Design: 283-T1, T2, T3, T4, T7, T8, T9, T11, T12 and T13; W9 to W19.

Negative Test Design: 283-T5 and T6 refuse an untimed `-Finish` with `FINISH_NOT_TIMED` and no receipt; 283-T10 writes no history for a timed or CI run; W9 gives no ETA from one run; W12 and W13 keep credentials out of output and history; W17 counts no TAP TODO or SKIP as a failure.

Non-Empty Population Obligation: the TIME family has accept, reject and mutation populations (`NON-EMPTY POPULATION TIME`).

Mutation Obligation: 283-TM1 (guard), TM2 (the run's time), TM3 (a command's time), TM4 (the history record), TM5 (the recorded outcome), TM6 (stages), TM7 (the evaluator's bound); M17 to M33 in `watch_selftest.ps1`, among them M23 (the bound), M29 to M32 (test classification) and M33 (writers not serialised).

Post-Implementation Proof Obligation: `-Finish`, started through `scripts/run_timed.ps1` and watched while it runs by `scripts/watch_run.ps1`, runs the CONTROL suites including the TIME family, and its Additional Verification runs `scripts/watch_selftest.ps1`.

### Draft review

The owner's method reviews a Draft in three passes before Gate 1: V1 initial validation, V2 adversarial challenge, V3 current external research. The development iterations D1 to D4 are the design history that produced the first Draft; they are **not** review passes.

| Iteration | Identity | Design | Evidence | Outcome |
| --- | --- | --- | --- | --- |
| D1 | `V1-design.md` SHA-256 `435bd02f3fa9c14b4576089040cf5266d38c122cb3d743241735d00ef7cc6c1c` | A written rule: start every run through the runner | `.githooks/pre-commit` and both workflows start the evaluator directly | Rejected: a rule cannot time the hook or CI |
| D2 | `d-proto.ps1` SHA-256 `80a01bb6a8945df05d7e6f7e44e29d54ec53935c73ea4bf614d34e92fbd6fff3`; suite log `19a02efd825d435c827553fe2bdfeaf3fb92dd2cd9a6f4df9d7cecd09c4dcb6d` | Evaluator `TIME:` lines, per-command and per-profile times, the `-Finish` guard | Control suite 509 passed, 3 failed: placement (`ORPHANED_APPROVED_CR`), fixed by placing the block after case 42 | Superseded when the owner confirmed the full objective |
| D3 | `V3.patch` SHA-256 `2fbbd9b000923613dc7fe80924050616004fb4cd7a95a839a88a6272617f04c3` | D2, plus the history writer, ETA, findings, report, redaction, bound and rule text | Control suite 518 passed, 0 failed; watcher self-test 42 of 42 | Superseded: the owner required every test and stage kept, and fewer notifications |
| D4 | `V4-noblank.patch` SHA-256 `66ef2bd1df15e8274899d1f459508b58198802502941d3a5426c5d4d0a249015` | D3, plus stages, every test line at 0.06 s, `-Brief`, an indexed history, slowest-stage and slowest-test views | Control suite 520 passed, 0 failed; watcher self-test 49 of 49 | Embedded in the first Draft, reviewed below |

| Pass | Reviewed content | By | Method | Outcome |
| --- | --- | --- | --- | --- |
| V1 Initial validation | First Draft, blob `5a8677cea9114efbdb798960ef2a4f1baa21a309`, SHA-256 `582b95c1d84b79356e7b8d1109d7be0856b3ce5be59b4bbd235e951d0aee76e5` (D4 embedded) | The drafting agent | Rehearsal in a disposable clone of `246284d`: hook READY at Draft, Approve, Begin and Implement; `APPROVAL_EVIDENCE: PASS`; `CRITERIA: 9 of 9`; three unlawful variants refused; Step 1 took 8 of 8 files from base to target blob; 13 of 13 criterion checks held; the whole publication range and the trusted judge READY | Valid as a Draft; presented at Gate 1 and not approved |
| V2 Adversarial challenge | The same blob | The owner's independent review (A1 to A4), then the drafting agent's own challenge of the corrections (A5 to A8) | Each finding gets a disposition and a test that fails without its correction | REVISE: eight findings, all corrected in this text; the owner's review of the revised Draft added A9, corrected the same way |
| V3 Current external research | The mechanisms of the corrections | The drafting agent | Official specifications and API references, read 2026-10-15 (R1 to R3) | Three content changes; no source contradicted a retained claim |

V2 findings:

- **A1 (owner).** The review record set a two-version minimum and presented development versions as review passes. Corrected by this section.
- **A2 (owner).** The evaluator's direct writer did not enforce the bound; the watcher trimmed only at its start and rewrote the file in place, so an append between its read and its write was lost. Corrected: one write path, `Add-TimingRows`, held text for text in both scripts (W19). A named mutex per history file serialises writers and the watcher's reads; every append checks the bound; a trim writes the newest whole rows beside the history and moves them over it. The bound is now 10 MB rather than 50,000 rows, because a file's length is the one measure an append can check without reading the file. Proof: 283-T13 and TM7; W14, W18 (900 rows from six concurrent writers arrive once and whole; past a 6,000-byte bound the history stays within it, with each writer's newest rows) and W19; M23; M33 (writers not serialised: appends fail and rows are lost).
- **A3 (owner).** `FAIL <name>` and TAP `not ok` matched the result vocabulary first, so a failed test was timed since the previous result, not counted as a test, and absent from the test views. Corrected: a line is judged a test first; a failed test is printed, timed since the line before it, counted and ranked. Proof: W15, W17; M29, M30, M32.
- **A4 (owner).** "Credentials are redacted before anything is printed or stored" was not true of the runner's raw log, which the history names. Corrected: the claim stops at the watcher's output and the history, and W13 proves the raw log keeps the line. The existing protections are unchanged.
- **A5 (agent).** The watcher wrote the header by overwriting when it found no file, so an evaluator's rows appended in between could be lost. Corrected: the header is written inside the lock.
- **A6 (agent).** A history write that timed out would have stopped the watcher with an uncaught error. Corrected: it reports `history: row not written` and the watch continues, as the evaluator reports `TIME_RECORD: not written`.
- **A7 (agent).** The slowest-test view read successful runs only, so a failed test's time never ranked. Corrected: the views read every run (M32).
- **A8 (agent).** Simplification challenged: one writer only, the evaluator calling the watcher, would remove the duplicated write path but make the authority depend on an adapter and add a process start to every hook run. Rejected; W19 holds the two copies equal.
- **A9 (owner, review of the revised Draft blob `458f45911dabd1c855114f0409e3c6dc140d8e8a`).** The completion command was printed as two lines in sequence, but `scripts/run_timed.ps1` blocks until its command ends, so a watcher started after it replays a finished log with no heartbeat or estimate. Corrected in `AGENTS.md`, `CR_LIFECYCLE.md` §9, `ENGINEERING_METHOD.md` §3 and Step 2: the watcher runs at the same time, from a second shell or the agent's background monitor, and it already waits for the log. Documentation only; no script changes. Proof, in a disposable clone with the patched scripts: started concurrently, the watcher attached 3 s after the run started and printed a heartbeat naming the running stage before `END`; run in sequence in one shell, it attached 1 s after the runner returned, with no heartbeat.

V3 research:

- **R1.** TAP version 14 specification, "Test Points" and "Directives" (https://testanything.org/tap-version-14-specification.html): `not ok` is a failed test point, and one with a TODO or SKIP directive must not be treated as a failure. Applied: such a line is a test, not a failure (W17, M31).
- **R2.** Microsoft Learn, `System.Threading.Mutex` (https://learn.microsoft.com/dotnet/api/system.threading.mutex): a named system mutex synchronises processes; `Global\` is visible in every session; an abandoned mutex passes to the next waiter with `AbandonedMutexException`; a timed-out `WaitOne` returns false and must not be released; a named mutex is not restricted to its creator. Applied: a `Global\` name derived from the history's full path; an abandoned mutex is taken (the history is only replaced whole); a timeout is reported before entering. Recorded limit: another local account holding the mutex can delay history writes, never a verdict.
- **R3.** Microsoft Learn, `File.Move(String, String, Boolean)` (https://learn.microsoft.com/dotnet/api/system.io.file.move): `overwrite` replaces the destination, and the documentation states no atomicity. Applied: the contract says the history is replaced by one move from a file beside it, not that the replacement is atomic. A writer killed before the move leaves the old history and a stray `.tmp` that the next trim overwrites.
- Reused from earlier research the same day, still current: `about_Try_Catch_Finally`, GitHub's token formats, CI duration practice and alerting practice (Notes).

Selection: the text V2 and V3 produced, which is this Draft; the V1 text is not selected. The embedded patch is `V6-noblank.patch` (V5 plus the A9 documentation correction), SHA-256 `d7fd6256ddaa22416eaa49dff72632bd6d96a2d67d9a8c1aaf90dd6c7eb312cf`. Validation of this text in a disposable clone of `246284d` with the patch applied, each run started through `scripts/run_timed.ps1` and followed by `scripts/watch_run.ps1 -Brief`: control suite 522 passed, 0 failed (29.0 min, log SHA-256 `d8ae5f7ee40a409b9f8134d455060efc7389109defa4c447a98c560d79f1d859`), including 283-T13, TM7 and the TIME population; watcher self-test 57 passed, 0 failed (7.1 min, log SHA-256 `9a2f3764c0a33fb158ea941a9da59cd2b0af0ddfdcce1ee3158f8b8e4eed6497`), every mutant killed; repository consistency CLEAN. An earlier self-test run was stopped at 5.8 min by the workstation running out of memory and is not counted. The A9 correction changes documentation only: the five scripts keep the blobs those runs passed on, and repository consistency on the corrected text is CLEAN (0.2 min).

## Implementation Steps

1. **Check** each file below against its blobs. If every file has its target blob, record Already Applied. Otherwise, if every file has its base blob (`246284d`), write the patch below to a file outside the repository, taking each line of the code block without its first three characters (an empty line stays empty), apply it with `git apply`, and confirm that every file now has its target blob; change nothing else. Otherwise stop and report.

   | File | Base blob | Target blob |
   | --- | --- | --- |
   | `CR_LIFECYCLE.md` | `b2f7cbe8669f8af48948bcaaa03a89700949a7c2` | `7ee05f5a3c18636b21647aa9afc702b1893f350d` |
   | `ENGINEERING_METHOD.md` | `e844e85adb4d21b83b01bf8a0c7328e8a379bebf` | `6a5fdca1160d353647a01f0219db99d459a7f201` |
   | `AGENTS.md` | `1b50005ad890a3446bfbfd0d1f22d7d5355a047b` | `b2412d15cd6fcf710055114fe734ba69178f35cc` |
   | `scripts/check_agent_continuity.ps1` | `d9d485b9a3bfa099af092648228e8bb005320471` | `4d67468f479076f28e95f223070788016281a59c` |
   | `scripts/test_agent_continuity.ps1` | `7f0843fd3ff31433e8c643b01298ab8d589dfe83` | `3e554c25f5d3ee9f015615f1be143817ca4ce0ca` |
   | `scripts/run_timed.ps1` | `50a1eee11211780fd795b555d6b2403e2fc1ebee` | `722ca31e5cd999d7fa968a2fd23ce943cebc37bc` |
   | `scripts/watch_run.ps1` | `06e1001973c731e25687c816c6662bde17ef0a2f` | `e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b` |
   | `scripts/watch_selftest.ps1` | `6b2b7f719acefa1611b834d0300ff3a04dd19cb0` | `144828ebdc82fa1812ca1971834b277bc9b94b31` |

   ```text
   diff --git a/AGENTS.md b/AGENTS.md
   index 1b50005..b2412d1 100644
   --- a/AGENTS.md
   +++ b/AGENTS.md
   @@ -59,10 +59,13 @@ PLAN → FRESHNESS → PRECHECK → EXECUTE → VERIFY → CERTIFY
    - **VERIFY:** repeat the observation and exercise allowed/blocked behavior proportional to risk.
    - **CERTIFY:** run `-Gate`, all derived mandatory profiles plus CR additions, repository consistency, generated-artifact freshness, checkpoint validation, and Git checks.

   -Before completion run:
   +Before completion run it through the timed runner and watch it while it runs (`CR_LIFECYCLE.md` §9); started directly, `-Finish` refuses. The runner blocks until the run ends, so the watcher runs at the same time, from a second shell or the agent's background monitor, never after the runner returns; it waits for the log if the run has not started:

    ```powershell
   -pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish
   +# first shell: blocks until the run ends
   +pwsh -NoProfile -File scripts/run_timed.ps1 -Log <log> -Command "pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish"
   +# at the same time, a second shell or a background monitor
   +pwsh -NoProfile -File scripts/watch_run.ps1 -Log <log> -Run finish-control -Brief
    ```

    Only a successful Finish permits Review/Complete, and that is now enforced rather than asked for: Finish writes a local certification receipt bound to the implementation state it certified, and the Gate refuses a Complete transition without a fresh matching one. CR transitions, immutable contract sections, synchronization, and command vocabulary live in `CR_LIFECYCLE.md`.
   @@ -137,7 +140,7 @@ Read it before writing or quoting any test, guard, or measurement. The kernel ke

    ## 7. Governance and tooling boundaries

   -Governance changes follow `GOVERNANCE.md §15` and owner authorization. Protected Canon, ADR, frozen baselines, schema, business rules, credentials, and external production systems require their owning authority. Tools and client hooks are adapters only; repository scripts/contracts + Git + CI own correctness. Skills may help but are never mandatory for correctness. Do not create parallel authorities, nested `AGENTS.md`, RAG/vector databases, knowledge graphs, context daemons/watchers, or generic semantic/dependency engines without separate owner-approved architecture. The on-demand run and CI watchers (`scripts/run_timed.ps1`, `scripts/watch_run.ps1`, `scripts/watch_ci.ps1`; owner-approved 2026-10-09) are reporting adapters inside this rule: started for one run and never resident, they write only a local timings file, never retry, rerun, dismiss, classify or approve anything, and never replace `-Finish` or `-Certify`.
   +Governance changes follow `GOVERNANCE.md §15` and owner authorization. Protected Canon, ADR, frozen baselines, schema, business rules, credentials, and external production systems require their owning authority. Tools and client hooks are adapters only; repository scripts/contracts + Git + CI own correctness. Skills may help but are never mandatory for correctness. Do not create parallel authorities, nested `AGENTS.md`, RAG/vector databases, knowledge graphs, context daemons/watchers, or generic semantic/dependency engines without separate owner-approved architecture. The on-demand run and CI watchers (`scripts/run_timed.ps1`, `scripts/watch_run.ps1`, `scripts/watch_ci.ps1`; owner-approved 2026-10-09) are reporting adapters inside this rule: started for one run and never resident, they write only the local timing history, which the evaluator also appends to (`SPEC-283`), never retry, rerun, dismiss or approve anything, never classify a failure's cause - a finding is labelled only by what its evidence supports - and never replace `-Finish` or `-Certify`.

    Reports are durable only when they own evidence not better represented in CR/Git/tests/Canon/ADR: forensic/audit work, substantial research, architectural decisions, phase/capability boundaries, or a failure investigation that cannot be encoded more strongly. Historical reports are immutable. Ordinary checkpoints do not require a new report.

   diff --git a/CR_LIFECYCLE.md b/CR_LIFECYCLE.md
   index b2f7cbe..7ee05f5 100644
   --- a/CR_LIFECYCLE.md
   +++ b/CR_LIFECYCLE.md
   @@ -122,7 +122,7 @@ Handoff between agents happens through the active CR (including Runtime Checkpoi

    `-Finish` is local executable certification: it runs the locally applicable derived profiles and every Additional Verification command, and only then may emit `LOCAL_CERTIFY: READY` and write the receipt §8 requires. When the `DATABASE` profile applies it executes the `ENGINEERING_METHOD.md §4` protocol rather than listing it, which is why such a contract must declare `supabase-local` and name its relevant `scripts/verify_*` suites. Remote CI success, when the CI profile applies, is separate observed evidence verified after push; local Finish never implies it.

   -**`-Finish` is the one run of the local verification, and it runs last (2026-10-09, `SPEC-249`).** It executes only in `VERIFY` mode, which a contract reaches when its Runtime Checkpoint reads `Resume Step: DONE` with `Blocker: None`; otherwise it refuses with `FINISH_NOT_READY:<mode>`, so that checkpoint is committed first. Because `-Finish` already runs every derived profile command and every Additional Verification command, an Implementation Step never runs one of them: `SPEC-248`'s step 4 ran the five CONTROL suites, and `-Finish` then ran all five again on the same bytes. A step that needs a result before `-Finish` runs a narrower command of its own. A long run may be followed with `scripts/watch_run.ps1` (`ENGINEERING_METHOD.md §3`); what the watcher reports never replaces the run.
   +**`-Finish` is the one run of the local verification, and it runs last (2026-10-09, `SPEC-249`).** It executes only in `VERIFY` mode, which a contract reaches when its Runtime Checkpoint reads `Resume Step: DONE` with `Blocker: None`; otherwise it refuses with `FINISH_NOT_READY:<mode>`, so that checkpoint is committed first. Because `-Finish` already runs every derived profile command and every Additional Verification command, an Implementation Step never runs one of them: `SPEC-248`'s step 4 ran the five CONTROL suites, and `-Finish` then ran all five again on the same bytes. A step that needs a result before `-Finish` runs a narrower command of its own. `-Finish` is started only through `scripts/run_timed.ps1` and watched while it runs by `scripts/watch_run.ps1`, started at the same time because the runner blocks until the run ends (`ENGINEERING_METHOD.md §3`); started any other way it refuses with `FINISH_NOT_TIMED` (`SPEC-283`), and what the watcher reports never replaces the run. Every run of `check_agent_continuity.ps1`, in every mode and on every exit path, ends after its verdict with `TIME: STAGES`, the time of each of its stages, and `TIME: <mode> hh:mm:ss`, and `-Finish` also prints each verification command's time and each profile's total.

    `-Certify` is that post-push observation, and it is the only thing entitled to make it: run from the repository root once `main` holds `HEAD`, it reads the workflow conclusions recorded against the exact current `HEAD` SHA and reports `REMOTE_CERTIFY: READY`, `PENDING` or `FAILED`. It asserts nothing it did not read. One expected workflow may stand on an earlier run, and only under proof (`SPEC-263`): a path-filtered workflow GitHub did not start on that SHA is judged by its nearest push run on the target branch at an ancestor of `HEAD`, provided git shows that no path it watches, and not its own definition, differs between the two SHAs. That run is judged exactly as one on `HEAD` would be; anything short of that proof is `REQUIRED_WORKFLOW_MISSING`.

   diff --git a/ENGINEERING_METHOD.md b/ENGINEERING_METHOD.md
   index e844e85..6a5fdca 100644
   --- a/ENGINEERING_METHOD.md
   +++ b/ENGINEERING_METHOD.md
   @@ -119,7 +119,7 @@ What stays judgment: whether a disposition is true, whether a criterion without
    - **External credentials never pass through the agent.** A secret for a third-party system (a database role password, an OAuth client secret, an API key, a token) — Phase 8's `orvion_integration` password and n8n/Google OAuth client secret are the precedent — is entered by the owner directly into its destination (the database console, n8n's credential UI, the provider's own form), never into a prompt, tool call, file, or any other agent-visible surface. An agent must not generate, request, echo, or transit such a secret, even transiently in a tool call whose output only the agent sees. Concrete application of `CODING_STANDARDS.md §8`; verify by effect (a credential test passing, a query succeeding), never by inspecting the secret.
    - **Quote only what a log printed (owner directive 2026-10-09).** A count, a verdict or a duration is copied from the output that produced it, never recalled, predicted or rounded into a claim. A progress report once carried a "289 passed" line that no run had printed, and it had to be retracted. While a run is still going, say that it is still going.
    - **A timing is evidence only with its conditions.** Record the command, its scope, the environment and what else was running; `scripts/run_timed.ps1` writes all of them into the run's START line. A run measured beside other work is labelled as such and is never a baseline: `SPEC-248`'s 50.3-minute `-Finish` ran beside a validation suite. An estimate or a remembered duration is never presented as a measurement.
   -- **A long run is watched, and the watcher decides nothing.** `scripts/watch_run.ps1` follows a `run_timed.ps1` log and reports every result line, a heartbeat naming the stage that is running whenever output stops, and a runner that died without finishing. `scripts/watch_ci.ps1` judges the runs on one exact SHA and branch against that branch's own contract, derived by the deriver `-Certify` uses, and reports the failed job, step and error lines; a check that never ran is reported MISSING, never as passed. A familiar message is never a cause: one Migration CI log held a harmless `toomanyrequests` beside the fatal `Bus error`. So the cause is established from the evidence before anything is rerun, and a mandatory verification is never skipped because a watcher once saw it pass. `scripts/watch_selftest.ps1` proves both watchers whenever either changes, and with `-Live` replays six real runs.
   +- **Every run is timed, a long run is watched, and the watcher decides nothing (`SPEC-283`).** An agent starts every repository verification it runs itself - `-Finish`, and any `scripts/test_*`, `check_*` or `verify_*` suite - through `scripts/run_timed.ps1`, and follows a run longer than a few minutes with `scripts/watch_run.ps1` while it runs: the runner blocks until its command ends, so the watcher is started at the same time, from a second shell or the agent's background monitor, and waits for the log if the run has not started; started after the runner returns, it only replays a finished log, with no heartbeat or estimate while the run was going; `-Finish` refuses any other start. `check_agent_continuity.ps1` times every run itself, so the pre-commit hook, CI and the owner's promoter are timed as well, and appends each run nobody timed to the one timing history the watcher keeps, outside the repository (CI's own timings stay on GitHub). `scripts/watch_run.ps1` follows a `run_timed.ps1` log, records every test line a suite prints and every evaluator stage with its own time, and reports every result line; a heartbeat naming the stage that is running whenever output stops, with the time left estimated from comparable successful runs, or no estimate below two; and a runner that died without finishing. Its findings are evidence labelled by what supports them: `[confirmed]` for a failure that also failed in earlier runs, `[hypothesis]` for a repeated command, a slow step or run, or a step recent successful runs had and this one lacks. An agent's monitor follows a run with `-Brief`, which prints only failures, findings, heartbeats, a progress line and the end, so a passing run costs a few notifications. `-Report` summarises the history: where the time goes, the slowest tests and stages, regressions, and failures ranked by their rate per run of the same name. An agent acts on a finding only through the lifecycle, tells the owner of one that needs the owner through its own client's notification, and never presents a local log as a notification; a Skill, Guard or Hook a finding suggests is a candidate for the Improvement Loop, never a change. `scripts/watch_ci.ps1` judges the runs on one exact SHA and branch against that branch's own contract, derived by the deriver `-Certify` uses, and reports the failed job, step and error lines; a check that never ran is reported MISSING, never as passed. A familiar message is never a cause: one Migration CI log held a harmless `toomanyrequests` beside the fatal `Bus error`. So the cause is established from the evidence before anything is rerun, and a mandatory verification is never skipped because a watcher once saw it pass. `scripts/watch_selftest.ps1` proves both watchers whenever either changes, and with `-Live` replays six real runs.
    - **Nothing open is lost (owner-ratified 2026-10-12).** Chat memory, an agent's memory and a session report are conveniences, never the place an open obligation lives. Before a task is complete, and before a session stops, every new item goes to the one home `GOVERNANCE.md` §2 assigns it:
      - a defect goes to the register with its evidence;
      - an accepted engineering decision goes to its ADR or Canon;
   diff --git a/scripts/check_agent_continuity.ps1 b/scripts/check_agent_continuity.ps1
   index d9d485b..4d67468 100644
   --- a/scripts/check_agent_continuity.ps1
   +++ b/scripts/check_agent_continuity.ps1
   @@ -10,6 +10,71 @@ param(
        [string]$HeadRef='HEAD'
    )
    $ErrorActionPreference='Stop'
   +# SPEC-283. Every run states how long it took, in every mode and on every exit path - the pre-commit
   +# hook, CI, the owner's promoter and an agent alike. The `finally` around the run prints
   +# `TIME: <mode> hh:mm:ss` after the verdict; `exit` runs it and keeps the exit code.
   +$script:RunClock=[Diagnostics.Stopwatch]::StartNew()
   +function Format-Elapsed([TimeSpan]$T){'{0:00}:{1:00}:{2:00}' -f [Math]::Floor($T.TotalHours),$T.Minutes,$T.Seconds}
   +# A run nobody timed - the pre-commit hook, a direct Boot or Gate, the publisher's and promoter's Gates,
   +# -Certify - is recorded here, in the history `scripts/watch_run.ps1` keeps and reports on. A run under
   +# `scripts/run_timed.ps1` is recorded by its watcher from the runner's log, and CI keeps its own run
   +# timings on GitHub, so every run has exactly one writer. Reporting only: a record that cannot be
   +# written is said so and never changes a verdict or an exit code. `$script:Outcome` is set where each
   +# verdict is printed, because a `finally` cannot read the code `exit` was given.
   +$script:RunStarted=Get-Date;$script:Outcome=$null
   +# Each stage is the time since the previous mark, and whatever follows the last mark is `other`, so the
   +# stages always sum to the run. One line carries them all - `TIME: STAGES <mode> <name>=1.23s ...` - so a
   +# run's output grows by one line, and the watcher or this file turns it into one history row per stage.
   +$script:Stages=[ordered]@{};$script:StageMark=[TimeSpan]::Zero
   +function Mark-Stage([string]$Name){$now=$script:RunClock.Elapsed;$script:Stages[$Name]=$now-$script:StageMark;$script:StageMark=$now}
   +function Format-Stages([string]$Label){
   +    $script:Stages['other']=$script:RunClock.Elapsed-$script:StageMark
   +    "TIME: STAGES $Label "+(@($script:Stages.GetEnumerator()|ForEach-Object{"$($_.Key)=$($_.Value.TotalSeconds.ToString('0.00',[Globalization.CultureInfo]::InvariantCulture))s"})-join' ')
   +}
   +function Write-TimingRecord([string]$Label){
   +    if($env:ORVION_TIMED_LOG-or$env:GITHUB_ACTIONS){return}
   +    try{
   +        $csv=if($env:ORVION_TIMINGS_CSV){$env:ORVION_TIMINGS_CSV}else{Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ORVION\timings.csv'}
   +        [void][IO.Directory]::CreateDirectory((Split-Path $csv -Parent))
   +        $head="$(git -C $Root rev-parse --short HEAD 2>$null)".Trim();$global:LASTEXITCODE=0
   +        $conditions="host=$env:COMPUTERNAME pwsh=$($PSVersionTable.PSVersion) cpus=$([Environment]::ProcessorCount) head=$head via=$(if($env:GIT_INDEX_FILE){'hook'}else{'direct'})"
   +        $outcome=if($script:Outcome){$script:Outcome}else{'OUTCOME UNRECORDED'}
   +        $inv=[Globalization.CultureInfo]::InvariantCulture;$min=$script:RunClock.Elapsed.TotalMinutes.ToString('0.0###',$inv)
   +        $run='orvion-'+($Label.ToLowerInvariant()-replace' ','-');$at=$script:RunStarted.ToString('yyyy-MM-dd HH:mm:ss.fff')
   +        $row={param($Step,$T,$D)'"{0}","{1}","{2}",{3},{4},"{5}"' -f $run,$at,($Step-replace'"',"'"),$T,$D,$conditions}
   +        $rows=@(& $row "TIME: $Label $(Format-Elapsed $script:RunClock.Elapsed)" $min $min)
   +        $at2=[TimeSpan]::Zero
   +        foreach($s in $script:Stages.GetEnumerator()){$at2+=$s.Value;$rows+=& $row "STAGE $Label $($s.Key)" $at2.TotalMinutes.ToString('0.0###',$inv) $s.Value.TotalMinutes.ToString('0.0###',$inv)}
   +        $rows+=& $row "END exit=$(if($outcome-match'READY$'){0}else{1}) $outcome" $min $min
   +        Add-TimingRows $csv $rows $(if($env:ORVION_TIMINGS_MAX_BYTES){[long]$env:ORVION_TIMINGS_MAX_BYTES}else{10MB})
   +    }catch{Write-Output "TIME_RECORD: not written - $($_.Exception.Message)"}
   +}
   +# The history's one write path, shared VERBATIM with scripts/watch_run.ps1 (scripts/watch_selftest.ps1
   +# holds the two copies equal). A named mutex per history file serialises every writer and the watcher's
   +# reads across processes, so an append never interleaves with another append or with a trim. The bound
   +# holds after every append: past $MaxBytes the history keeps its newest whole rows within half of it,
   +# written to a temporary file beside it and moved over it, so the history is never rewritten in place.
   +function Use-TimingHistory([string]$Path, [scriptblock]$Body) {
   +    $id = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Path).ToLowerInvariant())))
   +    $lock = [Threading.Mutex]::new($false, 'Global\ORVION-timings-' + $id.Substring(0, 32))
   +    try {
   +        # An abandoned mutex (its holder was killed) is acquired: the history is only ever replaced whole.
   +        try { if (-not $lock.WaitOne(15000)) { throw "the timing history $Path stayed locked for 15 s" } } catch [Threading.AbandonedMutexException] { }
   +        try { & $Body } finally { $lock.ReleaseMutex() }
   +    } finally { $lock.Dispose() }
   +}
   +function Add-TimingRows([string]$Path, [string[]]$Rows, [long]$MaxBytes) {
   +    Use-TimingHistory $Path {
   +        if (-not [IO.File]::Exists($Path)) { [IO.File]::WriteAllText($Path, 'run,date,step,elapsed_min,delta_min,env' + [Environment]::NewLine) }
   +        if ($Rows.Count) { [IO.File]::AppendAllText($Path, ($Rows -join [Environment]::NewLine) + [Environment]::NewLine) }
   +        if ([IO.FileInfo]::new($Path).Length -le $MaxBytes) { return }
   +        $b = [IO.File]::ReadAllBytes($Path); $h = [Array]::IndexOf($b, [byte]10) + 1
   +        $n = [Array]::IndexOf($b, [byte]10, [int][Math]::Max($h, $b.Length - [Math]::Floor($MaxBytes / 2))); $cut = if ($n -lt 0) { $b.Length } else { $n + 1 }
   +        $tmp = "$Path.tmp"; $f = [IO.File]::Create($tmp); try { $f.Write($b, 0, $h); $f.Write($b, $cut, $b.Length - $cut) } finally { $f.Dispose() }
   +        [IO.File]::Move($tmp, $Path, $true)
   +        'history: kept the newest {0:N0} of {1:N0} bytes of rows (limit {2:N0})' -f ($b.Length - $cut), ($b.Length - $h), $MaxBytes
   +    }
   +}

    # Native command output (git) is decoded using the console code page, which on a
    # default Windows shell is OEM (ibm437) and silently corrupts every non-ASCII
   @@ -1890,14 +1955,17 @@ function Git-State {
    # Success is one line. Failure keeps everything a diagnosis needs: the command,
    # the exit code, a diagnostic tail and the full log path. Streaming the entire
    # successful child output buried the result it was meant to report.
   -function Invoke-Verification([string]$Command,[switch]$Additional){
   +function Invoke-Verification([string]$Command,[string]$Label,[switch]$Additional){
        $log=Join-Path([IO.Path]::GetTempPath())("orvion-verify-$([guid]::NewGuid().ToString('N')).log")
        # `pwsh -Command` collapses a child's exit code to 1, which would report the
        # wrong failure code for every verification command. Propagate it explicitly.
   +    $clock=[Diagnostics.Stopwatch]::StartNew()
        & pwsh -NoProfile -Command "$Command`nexit `$LASTEXITCODE" *>$log
   -    $code=$LASTEXITCODE
   -    if($code-eq0){Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue;Write-Output "PASS: $Command";return}
   -    Write-Output "FAILED: $Command (exit $code)"
   +    $code=$LASTEXITCODE;$clock.Stop()
   +    if(-not$script:ProfileTime.Contains($Label)){$script:ProfileTime[$Label]=[TimeSpan]::Zero};$script:ProfileTime[$Label]+=$clock.Elapsed
   +    $took="TIME: $Label $Command $(Format-Elapsed $clock.Elapsed)"
   +    if($code-eq0){Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue;Write-Output "PASS: $Command";Write-Output $took;return}
   +    Write-Output "FAILED: $Command (exit $code)";Write-Output $took
        if(Test-Path -LiteralPath $log){
            Write-Output '--- last 20 lines ---'
            foreach($line in @(Get-Content -LiteralPath $log -Tail 20)){Write-Output $line}
   @@ -1938,8 +2006,10 @@ function Finish-Checks($c,[string[]]$profiles,[string]$rel){
        # Verification is one piece of evidence, not two. Deduplicate the execution;
        # Additional Verification remains strictly additive.
        $extra=@($c.AdditionalVerification|Where-Object{$mandatory-notcontains$_})
   -    foreach($command in $mandatory){Invoke-Verification $command}
   -    foreach($command in $extra){Invoke-Verification $command -Additional}
   +    $script:ProfileTime=[ordered]@{}
   +    foreach($command in $mandatory){Invoke-Verification $command $(if($seen.ContainsKey($command)){$seen[$command]}else{'CAPABILITY'})}
   +    foreach($command in $extra){Invoke-Verification $command 'ADDITIONAL' -Additional}
   +    foreach($p in $script:ProfileTime.Keys){Write-Output "TIME: PROFILE $p $(Format-Elapsed $script:ProfileTime[$p])"}

        $notExecuted=@()
        foreach($d in $deferred){
   @@ -2034,18 +2104,18 @@ function Certify-Remote {
        Write-Output "SHA: $sha"
        $path=Receipt-Path
        if(!(Test-Path -LiteralPath $path)){
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output 'EVIDENCE: no local certification receipt — the expected workflow set is unknown, so nothing can be proven. Run -Finish, then push, then certify.'
            exit 1
        }
        try{$receipt=Get-Content -Raw -LiteralPath $path|ConvertFrom-Json}catch{
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output 'EVIDENCE: the local certification receipt is unreadable'
            exit 1
        }
        $expected=@($receipt.expected|Where-Object{$_})
        if(!$expected.Count){
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output 'EVIDENCE: the local certification receipt records no expected workflow set'
            exit 1
        }
   @@ -2055,7 +2125,7 @@ function Certify-Remote {
        # though it were evidence about the promotion.
        $target=("$($receipt.target)").Trim()
        if(!$target){
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output 'EVIDENCE: the local certification receipt records no target branch — it predates context-aware certification. Run -Finish again.'
            exit 1
        }
   @@ -2072,7 +2142,7 @@ function Certify-Remote {
        # ARRAY when the resolved command is a PowerShell script.
        $raw=gh run list --commit $sha --branch $target --event push --limit 100 --json 'attempt,conclusion,databaseId,event,headBranch,headSha,status,workflowName' 2>$null
        if($LASTEXITCODE-ne0-or!$raw){
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output 'EVIDENCE: gh could not read workflow runs for this SHA'
            exit 1
        }
   @@ -2083,7 +2153,7 @@ function Certify-Remote {
        # because it only ever read members across the collection, which PowerShell flattens;
        # it becomes a real defect the moment individual rows are inspected.
        try{$parsed=$raw|ConvertFrom-Json}catch{
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output 'EVIDENCE: gh returned evidence this command cannot parse'
            exit 1
        }
   @@ -2102,7 +2172,7 @@ function Certify-Remote {
        }
        foreach($i in $ignored){Write-Output "IGNORED: $i — not this SHA on $target by push"}
        if(!$runs.Count){
   -        Write-Output 'REMOTE_CERTIFY: PENDING'
   +        $script:Outcome='REMOTE_CERTIFY: PENDING';Write-Output 'REMOTE_CERTIFY: PENDING'
            Write-Output "EVIDENCE: no workflow run exists for this SHA on $target yet — push it, or wait for the run to start"
            exit 1
        }
   @@ -2114,7 +2184,7 @@ function Certify-Remote {
        # settling, and FAILED once every observed run has completed without it. Both are
        # NOT READY; the distinction only tells the reader whether waiting can still help.
        if($missing.Count-and$running.Count){
   -        Write-Output 'REMOTE_CERTIFY: PENDING'
   +        $script:Outcome='REMOTE_CERTIFY: PENDING';Write-Output 'REMOTE_CERTIFY: PENDING'
            Write-Output "EVIDENCE: REQUIRED_WORKFLOW_MISSING so far: $($missing-join', ') — $($running.Count) run(s) on this SHA have not completed"
            exit 1
        }
   @@ -2131,18 +2201,18 @@ function Certify-Remote {
        $missing=$kept
        $running=@($runs|Where-Object{$_.status-ne'completed'})
        if($missing.Count){
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output "EVIDENCE: REQUIRED_WORKFLOW_MISSING: $($missing-join', ') produced no run on this SHA. Success on any other SHA proves nothing about this one."
            exit 1
        }
        if($running.Count){
   -        Write-Output 'REMOTE_CERTIFY: PENDING'
   +        $script:Outcome='REMOTE_CERTIFY: PENDING';Write-Output 'REMOTE_CERTIFY: PENDING'
            Write-Output "EVIDENCE: $($running.Count) run(s) still in progress on this SHA"
            exit 1
        }
        $bad=@($runs|Where-Object{$_.conclusion-ne'success'})
        if($bad.Count){
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output "EVIDENCE: $((@($bad|ForEach-Object{$_.workflowName})|Sort-Object -Unique)-join', ')"
            exit 1
        }
   @@ -2152,18 +2222,18 @@ function Certify-Remote {
        # remote, never a local cache, and refuse rather than assume when it cannot be read.
        git -C $Root fetch origin $target --quiet 2>$null|Out-Null
        if($LASTEXITCODE-ne0){
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output "EVIDENCE: TARGET_REF_UNREADABLE:$target — the remote target ref could not be read, so it cannot be proven to stand at this SHA"
            exit 1
        }
        $remote=(git -C $Root rev-parse "refs/remotes/origin/$target" 2>$null)
        $remote=if($LASTEXITCODE-eq0){("$remote").Trim()}else{''}
        if($remote-ne$sha){
   -        Write-Output 'REMOTE_CERTIFY: FAILED'
   +        $script:Outcome='REMOTE_CERTIFY: FAILED';Write-Output 'REMOTE_CERTIFY: FAILED'
            Write-Output "EVIDENCE: TARGET_REF_MOVED:$target is at $remote, not the certified $sha"
            exit 1
        }
   -    Write-Output 'REMOTE_CERTIFY: READY'
   +    $script:Outcome='REMOTE_CERTIFY: READY';Write-Output 'REMOTE_CERTIFY: READY'
        # Exits directly rather than returning a code: this function WRITES its
        # result, so a returned value would join that output stream and the caller
        # would fall through into the Boot pipeline instead of stopping.
   @@ -2180,8 +2250,14 @@ function Block($message){
        Write-Output 'NEXT: inspect the named authority/evidence, repair within Write Scope, then rerun.'
    }

   -try{
   +try{try{
        Set-Location $Root
   +    # SPEC-283. -Finish is the longest run an agent starts, and it is started only through
   +    # `scripts/run_timed.ps1`, which names its log here, so `scripts/watch_run.ps1` can follow it
   +    # and say how long is left (CR_LIFECYCLE.md §9). Anti-omission, not anti-forgery, like the receipt.
   +    if($Finish-and(-not$env:ORVION_TIMED_LOG-or-not(Test-Path -LiteralPath $env:ORVION_TIMED_LOG))){
   +        throw 'FINISH_NOT_TIMED:start -Finish through scripts/run_timed.ps1 and follow it with scripts/watch_run.ps1 (CR_LIFECYCLE.md §9)'
   +    }
        if(!(Test-Path(Join-Path $Root 'AGENTS.md'))){throw 'AGENTS_MISSING'}
        if($Certify){Certify-Remote}
        if($BaseRef){Assert-Ref $BaseRef;Assert-Ref $HeadRef}
   @@ -2199,8 +2275,10 @@ try{
            if($at-ne$want-or@(git -C $Root status --porcelain).Count){throw "TRUSTED_DATA_NOT_CANDIDATE:$Root is not a clean checkout of $want"}
        }

   +    Mark-Stage 'setup'
        $records=@(Diff-Records);$base=if($BaseRef){$BaseRef}else{'HEAD'}
        Validate-HistoryAndIds $records $base
   +    Mark-Stage 'history'
        # Allocation is judged locally on every run, and in range mode only when the
        # base itself was already under enforcement - current rules are never applied
        # retroactively to history that predates the marker. Reservation, unlike
   @@ -2218,11 +2296,15 @@ try{
        $script:RangeAllocationActive=[bool]$BaseRef-and(Allocation-ActiveAt $BaseRef)
        $script:PublicationSegments=@()
        if($BaseRef){$script:PublicationSegments=@(Get-PublicationSegments)}
   +    Mark-Stage 'allocation'
        $m=Manifest
   -    $rel=Resolve-Contract $m $records;$repo=if($Trusted){'not run (-Trusted executes no candidate file)'}else{Repo-Guard};$git=Git-State
   +    $rel=Resolve-Contract $m $records;Mark-Stage 'contract'
   +    $repo=if($Trusted){'not run (-Trusted executes no candidate file)'}else{Repo-Guard};Mark-Stage 'repo-guard'
   +    $git=Git-State;Mark-Stage 'git'
        if(!$git.Synced){throw "GIT_NOT_SYNCHRONIZED:$($git.Text)"}
        # SPEC-281. A state invariant like the consistency guard's, so it binds in every mode.
        Validate-PinnedAuthority $(if($BaseRef){$HeadRef}else{''})
   +    Mark-Stage 'pins'

        if(!$rel){
            Validate-ManifestCrState $m
   @@ -2239,6 +2321,7 @@ try{
            Write-Output "NEXT_CAPABILITY: $($m.Next)"
            Write-Output 'WRITE_AUTHORITY: none (Draft CR authoring only)'
            Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo"
   +        $script:Outcome='ORVION: READY'
            exit 0
        }

   @@ -2272,12 +2355,13 @@ try{
            if($baselineStatus-eq'Draft'-and$c.Status-eq'Approved'){$script:Criteria=Get-CriteriaReport $c 'carry a check verified at Complete'}
            if($baselineStatus-ne'Complete'-and$c.Status-eq'Complete'){$script:Criteria=Get-CriteriaReport $c 'verified'}
        }
   +    Mark-Stage 'transition'

        # The endpoint view above proves what the range LANDED ON. This proves what it
        # PASSED THROUGH, which a net diff cannot see. It runs before the pointer
        # invariant because a forbidden committed state is the deeper defect, and the
        # pointer is a final-state property that would otherwise report the symptom.
   -    if($BaseRef){if($script:PublicationSegments.Count-gt1){Validate-PublicationSegments}else{Validate-CommittedRange $rel}}
   +    if($BaseRef){if($script:PublicationSegments.Count-gt1){Validate-PublicationSegments}else{Validate-CommittedRange $rel};Mark-Stage 'range-walk'}
        # SPEC-281 (ACI). The hook's view of the authority-change closure the walk applies per commit.
        if(!$BaseRef){
            $pinPaths=@(@(Get-PinnedAuthority 'HEAD')+@(Get-PinnedAuthority '')|ForEach-Object{$_.Path})
   @@ -2349,7 +2433,7 @@ try{
        # and a capability line that looked like a probe result would be a false green.
        foreach($name in $declaredCapabilities){Write-Output "CAPABILITY: $name EXTERNAL_EVIDENCE — $($script:Capabilities[$name].Note)"}
        Write-Output "GIT: $($git.Text)";Write-Output "REPOSITORY: $repo";Write-Output "BLOCKER: $($c.Blocker.ToLowerInvariant())"
   -    if($Finish){Finish-Checks $c $profiles ($rel-replace'\\','/')}
   +    if($Finish){Mark-Stage 'checks';Finish-Checks $c $profiles ($rel-replace'\\','/');Mark-Stage 'verification'}
        # A successful run states its OWN status (SPEC-166). Falling off the end leaves
        # whatever the last native command set, and `Read-GitFile` deliberately runs a
        # `git show` that FAILS whenever a path is absent at a ref - it leaves 128 behind
   @@ -2359,10 +2443,17 @@ try{
        # MODE: VERIFY and BLOCKER: none, and the CI step failed with no error to read -
        # on the first push of a new Change Request, which is when the governing contract
        # is absent at the range base. Success is an assertion, not a leftover.
   +    $script:Outcome='ORVION: READY'
        exit 0
    }catch{
        if($Finish){Write-Output 'CERTIFY: FAILED'}
   +    $script:Outcome="ORVION: BLOCKED $(($_.Exception.Message-split':',2)[0])"
        Block $_.Exception.Message
        exit 1
   +}}finally{
   +    $label=if($Boot){'Boot'}elseif($Gate){if($Trusted){'Gate trusted'}elseif($BaseRef){'Gate range'}else{'Gate'}}elseif($Finish){'Finish'}else{'Certify'}
   +    Write-Output (Format-Stages $label)
   +    Write-Output "TIME: $label $(Format-Elapsed $script:RunClock.Elapsed)"
   +    Write-TimingRecord $label
    }

   diff --git a/scripts/run_timed.ps1 b/scripts/run_timed.ps1
   index 50a1eee..722ca31 100644
   --- a/scripts/run_timed.ps1
   +++ b/scripts/run_timed.ps1
   @@ -36,11 +36,17 @@ $head = (git rev-parse --short HEAD 2>$null); if (-not $head) { $head = 'none' }
    $before = Get-ConcurrentScripts
    $envLabel = 'host={0} pwsh={1} cpus={2} head={3} concurrent={4}' -f $env:COMPUTERNAME, $PSVersionTable.PSVersion, [Environment]::ProcessorCount, $head, $(if ($before.Count) { $before -join ',' } else { '0' })
    $sw = [Diagnostics.Stopwatch]::StartNew()
   +# What it runs can see that it is timed and where: `check_agent_continuity.ps1 -Finish` refuses to
   +# start without this (SPEC-283, CR_LIFECYCLE.md §9).
   +$env:ORVION_TIMED_LOG = $Log
    '[{0}] START pid={1} {2} | {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID, $envLabel, $Command | Out-File -LiteralPath $Log -Encoding utf8
   -pwsh -NoProfile -Command "$Command`nexit `$LASTEXITCODE" 2>&1 | ForEach-Object { '[+{0,6:N1} min] {1}' -f $sw.Elapsed.TotalMinutes, $_ } | Out-File -LiteralPath $Log -Append -Encoding utf8
   +# Stamped to a thousandth of a minute (0.06 s), culture-invariant, so every test line a suite prints
   +# carries its own measurable time (SPEC-283); a tenth of a minute hid every test shorter than 6 s.
   +function Stamp { $sw.Elapsed.TotalMinutes.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture).PadLeft(8) }
   +pwsh -NoProfile -Command "$Command`nexit `$LASTEXITCODE" 2>&1 | ForEach-Object { '[+{0} min] {1}' -f (Stamp), $_ } | Out-File -LiteralPath $Log -Append -Encoding utf8
    # `pwsh -Command` collapses a child's exit code to 1 unless it is propagated explicitly, exactly as
    # `check_agent_continuity.ps1` Invoke-Verification does; the appended `exit $LASTEXITCODE` is that propagation.
    $code = $LASTEXITCODE
    $after = Get-ConcurrentScripts
   -'[+{0,6:N1} min] END exit={1} total={0:N1} min concurrent_end={2}' -f $sw.Elapsed.TotalMinutes, $code, $(if ($after.Count) { $after -join ',' } else { '0' }) | Out-File -LiteralPath $Log -Append -Encoding utf8
   +'[+{0} min] END exit={1} total={2} min concurrent_end={3}' -f (Stamp), $code, $sw.Elapsed.TotalMinutes.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture), $(if ($after.Count) { $after -join ',' } else { '0' }) | Out-File -LiteralPath $Log -Append -Encoding utf8
    exit $code
   diff --git a/scripts/test_agent_continuity.ps1 b/scripts/test_agent_continuity.ps1
   index 7f0843f..3e554c2 100644
   --- a/scripts/test_agent_continuity.ps1
   +++ b/scripts/test_agent_continuity.ps1
   @@ -469,6 +469,8 @@ function MutationKillRange([string]$Name,[string]$Expect,[string]$Find,[string]$
    }
    try{
        [IO.Directory]::CreateDirectory($sandbox)|Out-Null
   +    # SPEC-283. -Finish starts only under scripts/run_timed.ps1, which names its log; the fixtures stand in for it.
   +    $timedLog=Join-Path $sandbox 'timed.log';[IO.File]::WriteAllText($timedLog,'');$env:ORVION_TIMED_LOG=$timedLog
        git init --bare $remote --quiet;git clone $remote $root --quiet
        git -C $root config user.email test@orvion.invalid;git -C $root config user.name ORVION-Test
        Put 'AGENTS.md' '# fixture'
   @@ -602,6 +604,100 @@ try{
        Reset-Fixture;Rebase (ContractText -Resume DONE -Scope scripts/test_agent_continuity.ps1);Put 'scripts/test_agent_continuity.ps1' 'exit 9';$r=Run Finish;Assert '40 failing mandatory CONTROL verification makes Finish fail' ($r.Code-ne0-and$r.Text-match'CERTIFY: FAILED'-and$r.Text-match'MANDATORY_VERIFICATION_FAILED') $r.Text
        Reset-Fixture;Rebase (ContractText -Resume DONE -Additional 'pwsh -NoProfile -Command "exit 7"');$r=Run Finish;Assert '41 failing Additional Verification makes Finish fail' ($r.Code-ne0-and$r.Text-match'ADDITIONAL_VERIFICATION_FAILED') $r.Text
        Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume DONE);$r=Run Finish;Assert '42 successful mandatory verification precedes LOCAL_CERTIFY READY' ($r.Code-eq0-and$r.Text-match'PASS: pwsh -NoProfile -File scripts/check_repository_consistency.ps1'-and$r.Text-match'LOCAL_CERTIFY: READY') $r.Text
   +    # ---- TIME (SPEC-283) ----
   +    # Every run reports how long it took, after its verdict, on every exit path and in both invocation
   +    # shapes; -Finish reports each verification command and each profile, and starts only under
   +    # scripts/run_timed.ps1. Before SPEC-283 no run printed a time, and a -Finish started directly could
   +    # not be followed by scripts/watch_run.ps1 (measured on SPEC-282's own -Finish).
   +    function TimeLine([string]$Label){'(?m)^TIME: '+[regex]::Escape($Label)+' \d\d:\d\d:\d\d\s*$'}
   +    function RunWith([string]$Evaluator,[string]$Mode){$o=& pwsh -NoProfile -File $Evaluator "-$Mode" -Root $root 2>&1;[pscustomobject]@{Text=($o|Out-String);Code=$LASTEXITCODE}}
   +    function Untimed([scriptblock]$Body,[string]$Value=''){$saved=$env:ORVION_TIMED_LOG;if($Value){$env:ORVION_TIMED_LOG=$Value}else{Remove-Item Env:ORVION_TIMED_LOG};try{& $Body}finally{$env:ORVION_TIMED_LOG=$saved}}
   +    $finishFixture={Reset-Fixture;Put 'changes/SPEC-900-fixture.md' (ContractText -Resume DONE)}
   +
   +    Reset-Fixture;$r=Run
   +    Assert '283-T1 TIME: a READY Boot ends with its time and keeps exit 0' ($r.Code-eq0-and$r.Text-match(TimeLine 'Boot')) $r.Text
   +    Pop 'TIME' 'accept'
   +    Reset-Fixture;Put 'secret.txt' 'a write no contract authorised';$r=Run Gate
   +    Assert '283-T2 TIME: a refused Gate reports its time and keeps its non-zero exit' ($r.Code-ne0-and$r.Text-match'ORVION: BLOCKED'-and$r.Text-match(TimeLine 'Gate')) $r.Text
   +    Pop 'TIME' 'accept'
   +    Reset-Fixture;$r=RunRange 'origin/main'
   +    Assert '283-T3 TIME: dot-sourced as CI runs it, the range reports its time and its exit still matches its verdict' ($r.Text-match(TimeLine 'Gate range')-and(($r.Code-eq0)-eq($r.Text-match'ORVION: READY'))) "code=$($r.Code) $($r.Text)"
   +    Pop 'TIME' 'accept'
   +    & $finishFixture;$r=Run Finish
   +    Assert '283-T4 TIME: Finish reports each verification command and each profile' ($r.Code-eq0-and$r.Text-match'LOCAL_CERTIFY: READY'-and$r.Text-match'(?m)^TIME: REPOSITORY pwsh -NoProfile -File scripts/check_repository_consistency\.ps1 \d\d:\d\d:\d\d'-and$r.Text-match(TimeLine 'PROFILE REPOSITORY')-and$r.Text-match(TimeLine 'Finish')) $r.Text
   +    Pop 'TIME' 'accept'
   +    $r=Untimed {& $finishFixture|Out-Null;Run Finish}
   +    Assert '283-T5 TIME: Finish started outside scripts/run_timed.ps1 is refused before it verifies anything' ($r.Code-ne0-and$r.Text-match'CODE: FINISH_NOT_TIMED'-and$r.Text-notmatch'PASS: '-and$null-eq(ReceiptJson)) $r.Text
   +    Pop 'TIME' 'reject'
   +    $r=Untimed {& $finishFixture|Out-Null;Run Finish} (Join-Path $sandbox 'no-such-timed.log')
   +    Assert '283-T6 TIME: a runner log that does not exist is refused the same way' ($r.Code-ne0-and$r.Text-match'CODE: FINISH_NOT_TIMED'-and$null-eq(ReceiptJson)) $r.Text
   +    Pop 'TIME' 'reject'
   +    $tl=Join-Path $sandbox 'runner.log';& pwsh -NoProfile -File (Join-Path $sourceRoot 'scripts/run_timed.ps1') -Log $tl -Command 'Write-Output "seen=$env:ORVION_TIMED_LOG"' 2>&1|Out-Null
   +    $seen=if(Test-Path -LiteralPath $tl){Get-Content -Raw -LiteralPath $tl}else{''}
   +    Assert '283-T7 TIME: scripts/run_timed.ps1 names its own log to the command it runs' ($seen.Contains("seen=$([IO.Path]::GetFullPath($tl))")) $seen
   +    Pop 'TIME' 'accept'
   +    # Mutations, each killed by the one case only it breaks.
   +    $src=Get-Content -Raw $control;$mutant=Join-Path $sandbox 'time-mutant.ps1'
   +    function TimeMutant([string]$Old,[string]$New){$m=$src.Replace($Old,$New);[IO.File]::WriteAllText($mutant,$m,(New-Object Text.UTF8Encoding($false)));$m-ne$src}
   +    $ok=TimeMutant "if(`$Finish-and(-not`$env:ORVION_TIMED_LOG" "if(`$false-and(-not`$env:ORVION_TIMED_LOG"
   +    $r=Untimed {& $finishFixture|Out-Null;RunWith $mutant 'Finish'};Pop 'TIME' 'mutation'
   +    Assert '283-TM1 TIME MUTATION: the guard is what refuses an untimed Finish' ($ok-and$r.Text-notmatch'FINISH_NOT_TIMED'-and$r.Text-match'LOCAL_CERTIFY: READY') $r.Text
   +    $ok=TimeMutant 'Write-Output "TIME: $label $(Format-Elapsed $script:RunClock.Elapsed)"' '$null'
   +    Reset-Fixture;$r=RunWith $mutant 'Boot';Pop 'TIME' 'mutation'
   +    Assert '283-TM2 TIME MUTATION: the finally is what prints a run''s time' ($ok-and$r.Code-eq0-and$r.Text-notmatch'(?m)^TIME: Boot') $r.Text
   +    $ok=TimeMutant 'Write-Output "PASS: $Command";Write-Output $took;return' 'Write-Output "PASS: $Command";return'
   +    & $finishFixture;$r=RunWith $mutant 'Finish';Pop 'TIME' 'mutation'
   +    Assert '283-TM3 TIME MUTATION: Invoke-Verification is what times each command' ($ok-and$r.Text-match'LOCAL_CERTIFY: READY'-and$r.Text-notmatch'(?m)^TIME: REPOSITORY pwsh') $r.Text
   +    # HISTORY. A run nobody timed - the hook, a direct Boot or Gate - is appended to the timing history
   +    # with its true outcome; a timed run (its watcher records it) and a CI run (GitHub keeps its timings)
   +    # are not; a history that cannot be written changes no verdict and no exit code.
   +    $hist=Join-Path $sandbox 'timings.csv'
   +    function Recorded([scriptblock]$Body,[hashtable]$With=@{},[string[]]$Seed=@()){
   +        $saved=@{};foreach($k in @('ORVION_TIMED_LOG','GITHUB_ACTIONS','ORVION_TIMINGS_CSV','ORVION_TIMINGS_MAX_BYTES')){$saved[$k]=[Environment]::GetEnvironmentVariable($k)}
   +        [Environment]::SetEnvironmentVariable('ORVION_TIMED_LOG',$null);[Environment]::SetEnvironmentVariable('GITHUB_ACTIONS',$null);$env:ORVION_TIMINGS_CSV=$hist
   +        foreach($k in $With.Keys){[Environment]::SetEnvironmentVariable($k,$With[$k])}
   +        Remove-Item -LiteralPath $hist -Force -ErrorAction SilentlyContinue
   +        if($Seed.Count){[IO.File]::WriteAllLines($hist,$Seed)}
   +        try{$r=& $Body;[pscustomobject]@{R=$r;Rows=@(if(Test-Path -LiteralPath $hist -PathType Leaf){Import-Csv -LiteralPath $hist})}}
   +        finally{foreach($k in $saved.Keys){[Environment]::SetEnvironmentVariable($k,$saved[$k])}}
   +    }
   +    $x=Recorded {Reset-Fixture|Out-Null;Run}
   +    $stageRows=@($x.Rows|Where-Object{$_.step-like'STAGE Boot *'});$inv=[Globalization.CultureInfo]::InvariantCulture
   +    $stageSum=($stageRows|ForEach-Object{[double]::Parse($_.delta_min,$inv)}|Measure-Object -Sum).Sum;$total=if($x.Rows.Count){[double]::Parse($x.Rows[0].elapsed_min,$inv)}else{-1}
   +    Assert '283-T8 HISTORY: an untimed Boot is recorded with its time, each stage, its outcome and its conditions' ($x.R.Code-eq0-and$x.Rows[0].run-eq'orvion-boot'-and$x.Rows[0].step-match'^TIME: Boot \d\d:\d\d:\d\d$'-and$x.Rows[-1].step-eq'END exit=0 ORVION: READY'-and$x.Rows[-1].env-match'head=[0-9a-f]{7,} via=direct'-and@($stageRows|Where-Object{$_.step-in'STAGE Boot repo-guard','STAGE Boot other'}).Count-eq2-and[Math]::Abs($stageSum-$total)-lt0.01) "sum=$stageSum total=$total`n$($x.R.Text)`n$($x.Rows|ConvertTo-Json)"
   +    Pop 'TIME' 'accept'
   +    $x=Recorded {Reset-Fixture|Out-Null;Put 'secret.txt' 'a write no contract authorised';Run Gate}
   +    Assert '283-T9 HISTORY: a refused Gate is recorded as refused, with its code' ($x.R.Code-ne0-and$x.Rows[0].run-eq'orvion-gate'-and$x.Rows[-1].step-match'^END exit=1 ORVION: BLOCKED [A-Z_]+$') "$($x.R.Text)`n$($x.Rows|ConvertTo-Json)"
   +    Pop 'TIME' 'accept'
   +    Reset-Fixture;$r=Run
   +    Assert '283-T12 STAGES: one line names every stage of an EXECUTE-mode Boot with its own time' ($r.Code-eq0-and$r.Text-match'(?m)^TIME: STAGES Boot setup=[\d.]+s history=[\d.]+s allocation=[\d.]+s contract=[\d.]+s repo-guard=[\d.]+s git=[\d.]+s pins=[\d.]+s transition=[\d.]+s other=[\d.]+s\s*$') $r.Text
   +    Pop 'TIME' 'accept'
   +    $t=Recorded {Reset-Fixture|Out-Null;Run} @{ORVION_TIMED_LOG=$timedLog};$c=Recorded {Reset-Fixture|Out-Null;Run} @{GITHUB_ACTIONS='true'}
   +    Assert '283-T10 HISTORY: a timed run and a CI run leave the history to their own writers' ($t.R.Code-eq0-and$c.R.Code-eq0-and$t.Rows.Count-eq0-and$c.Rows.Count-eq0) "timed=$($t.Rows.Count) ci=$($c.Rows.Count)"
   +    Pop 'TIME' 'reject'
   +    $x=Recorded {Reset-Fixture|Out-Null;Run} @{ORVION_TIMINGS_CSV=$sandbox}
   +    Assert '283-T11 HISTORY: a history that cannot be written is reported and changes no verdict or exit code' ($x.R.Code-eq0-and$x.R.Text-match'ORVION: READY'-and$x.R.Text-match'TIME_RECORD: not written') $x.R.Text
   +    Pop 'TIME' 'accept'
   +    # The bound holds on the evaluator's own append, not only when a watcher starts: a history already past
   +    # ORVION_TIMINGS_MAX_BYTES keeps its header and its newest whole rows, this run's among them.
   +    $seed=@('run,date,step,elapsed_min,delta_min,env')+@(1..300|ForEach-Object{"""old"",""2026-01-01 00:00:00"",""PASS seeded row $_"",1,1,""host=H"""})
   +    $x=Recorded {Reset-Fixture|Out-Null;Run} @{ORVION_TIMINGS_MAX_BYTES='8000'} $seed;$bytes=if(Test-Path -LiteralPath $hist){(Get-Item -LiteralPath $hist).Length}else{-1}
   +    $lines=if($bytes-gt0){[IO.File]::ReadAllLines($hist)}else{@()}
   +    Assert '283-T13 HISTORY: the evaluator''s own append keeps the history within its bound, header first, newest rows whole' ($x.R.Code-eq0-and$bytes-gt0-and$bytes-le8000-and$lines[0]-eq$seed[0]-and$x.Rows[-1].step-eq'END exit=0 ORVION: READY'-and@($x.Rows|Where-Object{$_.step-eq'PASS seeded row 1'}).Count-eq0-and@($x.Rows|Where-Object{$_.step-eq'PASS seeded row 300'}).Count-eq1-and@($lines|Where-Object{$_-notmatch'^"[^"]*","[^"]*","[^"]*",[\d.]+,[\d.]+,"[^"]*"$'}).Count-eq1-and$x.R.Text-match'history: kept the newest') "bytes=$bytes lines=$($lines.Count)`n$($x.R.Text)"
   +    Pop 'TIME' 'accept'
   +    $ok=TimeMutant 'if ([IO.FileInfo]::new($Path).Length -le $MaxBytes) { return }' 'return'
   +    $x=Recorded {Reset-Fixture|Out-Null;RunWith $mutant 'Boot'} @{ORVION_TIMINGS_MAX_BYTES='8000'} $seed;$bytes=if(Test-Path -LiteralPath $hist){(Get-Item -LiteralPath $hist).Length}else{-1};Pop 'TIME' 'mutation'
   +    Assert '283-TM7 HISTORY MUTATION: Add-TimingRows is what bounds the evaluator''s append' ($ok-and$x.R.Code-eq0-and$bytes-gt8000) "bytes=$bytes"
   +    $ok=TimeMutant 'Write-TimingRecord $label' '$null'
   +    $x=Recorded {Reset-Fixture|Out-Null;RunWith $mutant 'Boot'};Pop 'TIME' 'mutation'
   +    Assert '283-TM4 HISTORY MUTATION: the finally is what records a run' ($ok-and$x.R.Code-eq0-and$x.Rows.Count-eq0) "rows=$($x.Rows.Count)"
   +    $ok=TimeMutant '$script:Outcome="ORVION: BLOCKED $(($_.Exception.Message-split'':'',2)[0])"' '$null'
   +    $x=Recorded {Reset-Fixture|Out-Null;Put 'secret.txt' 'a write no contract authorised';RunWith $mutant 'Gate'};Pop 'TIME' 'mutation'
   +    Assert '283-TM5 HISTORY MUTATION: the outcome is set where the refusal is printed' ($ok-and$x.R.Code-ne0-and@($x.Rows|Where-Object{$_.step-match'BLOCKED'}).Count-eq0) "$($x.Rows|ConvertTo-Json)"
   +    $ok=TimeMutant 'function Mark-Stage([string]$Name){$now=$script:RunClock.Elapsed;$script:Stages[$Name]=$now-$script:StageMark;$script:StageMark=$now}' 'function Mark-Stage([string]$Name){}'
   +    Reset-Fixture;$r=RunWith $mutant 'Boot';Pop 'TIME' 'mutation'
   +    Assert '283-TM6 STAGES MUTATION: Mark-Stage is what times each stage' ($ok-and$r.Code-eq0-and$r.Text-notmatch'repo-guard=') $r.Text
   +    Remove-Item -LiteralPath $mutant,$tl,$hist -Force -ErrorAction SilentlyContinue

        $collisionNeedle='SPEC-155 Agent'+' Control Plane';$collision=@(git -C $sourceRoot grep -n -F $collisionNeedle -- . 2>$null);$product=@(git -C $sourceRoot grep -n -F 'SPEC-155' -- 'supabase/migrations/*' 'reports/master/MASTER_EXECUTION_PLAN.md' 2>$null)
        Assert '43 control-plane identifier collision absent and product SPEC-155 remains' ($collision.Count-eq0-and$product.Count-gt0) "collision=$($collision.Count) product=$($product.Count)"
   @@ -3639,13 +3735,14 @@ exit 0
        # ---- NON-EMPTY POPULATIONS (SPEC-196) ----
        # A guard reasoning over an empty set reports success while measuring nothing.
        # Every family must have proven acceptance, refusal AND a mutation kill.
   -    foreach($family in @('D','F','HJ','APPLIC','WC','CTRL1','CTRL4','RANGE-AUTH','ORIGIN','K-local','K-reservation','K-activation','K-range','CERT-INHERIT','SEG-CARRY','PARITY','CHECK','PIN','ACI','TRUST','PROMOTE')){
   +    foreach($family in @('D','F','HJ','APPLIC','WC','CTRL1','CTRL4','RANGE-AUTH','ORIGIN','K-local','K-reservation','K-activation','K-range','CERT-INHERIT','SEG-CARRY','PARITY','CHECK','PIN','ACI','TRUST','PROMOTE','TIME')){
            $a=$script:pop["$family/accept"];$r=$script:pop["$family/reject"];$k=$script:pop["$family/mutation"]
            Assert "NON-EMPTY POPULATION ${family}: accept, reject and mutation populations are all non-zero" (($a-gt0)-and($r-gt0)-and($k-gt0)) "accept=$a reject=$r mutation=$k"
        }

    }finally{
        Remove-Item Env:ORVION_GUARD_MARKER -ErrorAction SilentlyContinue
   +    Remove-Item Env:ORVION_TIMED_LOG -ErrorAction SilentlyContinue
        Remove-Item Env:ORVION_STUB_LOG -ErrorAction SilentlyContinue
        Remove-Item Env:ORVION_STUB_GH -ErrorAction SilentlyContinue
        Remove-Item Env:ORVION_STUB_GH_LOG -ErrorAction SilentlyContinue
   diff --git a/scripts/watch_run.ps1 b/scripts/watch_run.ps1
   index 06e1001..e327c2f 100644
   --- a/scripts/watch_run.ps1
   +++ b/scripts/watch_run.ps1
   @@ -5,26 +5,53 @@
    #   * every RESULT line, with the minutes since the run started and since the previous result;
    #   * a heartbeat when the log has been silent for -QuietMinutes, naming the repository script the
    #     runner is executing at that moment and its CPU time, so a long stage is distinguishable from
   -#     a stall;
   +#     a stall, and an ETA from comparable past runs (or why there is none);
    #   * RUNNER GONE when the runner's process has exited without writing its END line (killed or
    #     crashed), and a notice when no runner has started at all;
   +#   * FINDINGS, each once per run and labelled by what the evidence supports: [confirmed] for a fact the
   +#     log and the history establish (a failure that also failed in earlier runs), [hypothesis] for a
   +#     comparison that needs a person to judge (a command run twice, a step or a run slower than its
   +#     history, steps every recent successful run had and this one lacks);
    #   * at END, a comparison with the previous recorded run of the same -Run name, with both runs'
    #     conditions, so a timing is never compared without knowing what else was running.
   -# Each reported result is appended to a LOCAL timings file outside the repository.
   +# With -Brief, for an agent's monitor, it prints only what needs attention - failures, findings,
   +# heartbeats, RUNNER GONE and the end - plus a progress line every -ProgressMinutes; everything else is
   +# still recorded.
   +#
   +# Every result, every TEST line a suite prints (`PASS <name>`, `FAIL <name>`, TAP `ok`/`not ok`), every
   +# evaluator stage (`TIME: STAGES`) and every finding is appended to a LOCAL timings file outside the
   +# repository, with the run's log as its evidence reference; a test's time is the time since the line
   +# before it, and a failed test is a test like any other, also printed and counted as a failure. That
   +# file is the one timing history: the evaluator appends the runs nobody timed (SPEC-283), and -Report
   +# reads it - where the time goes, the slowest tests and stages, which runs regressed, and which failures
   +# recur, each normalised by how often that run executes. It never exceeds -MaxBytes (10 MB, about
   +# 50,000 rows, measured to load in about a second): every append, the evaluator's or a watcher's, keeps
   +# the newest rows within half of it once it passes the limit (Add-TimingRows).
   +# What the watcher prints and writes to the history is redacted of values shaped like a known
   +# credential (Hide-Secret). The runner's log, which each row names as its evidence, is the run's RAW
   +# output and is not redacted; it stays where the agent wrote it.
    # It exits 0 only when the run ended `END exit=0`; a run that ended non-zero, or a runner that died,
    # exits 1, so a background notification never reports a failed run as a clean watch.
    #
   -# It never retries, reruns, dismisses, classifies or approves anything. `-Finish` and `-Certify`
   -# remain the only verdicts, and a reported line is evidence for the reader to judge.
   +# It never retries, reruns, dismisses or approves anything, never classifies a failure's cause, and
   +# never changes a file but its own history. `-Finish` and `-Certify` remain the only verdicts, a
   +# finding is evidence for the reader to judge, and a [hypothesis] is never reported as a defect.
    #
    # Usage:
   -#   pwsh -NoProfile -File scripts/watch_run.ps1 -Log <file> -Run finish-control
   +#   pwsh -NoProfile -File scripts/watch_run.ps1 -Log <file> -Run finish-control [-Brief]
   +#   pwsh -NoProfile -File scripts/watch_run.ps1 -Log <file> -Run finish-control -Eta    # one estimate, now
   +#   pwsh -NoProfile -File scripts/watch_run.ps1 -Report [-Run finish-control]          # the history
    param(
        [string]$Log,
        [string]$Run,
        [double]$QuietMinutes = 5,
        [double]$PollSeconds = 10,
   -    [string]$Csv = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ORVION\timings.csv')
   +    [string]$Csv = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ORVION\timings.csv'),
   +    [switch]$Eta,
   +    [switch]$Report,
   +    [switch]$Brief,
   +    [double]$ProgressMinutes = 10,
   +    [long]$MaxBytes = 10MB
    )

    # RESULT VOCABULARY, derived from what the repository's scripts actually print:
   @@ -34,13 +61,22 @@ param(
    #     RECOVERY_EXHAUSTED, `NOT ...` and `N issue(s)` (scripts/*.ps1 and .workstation/*.ps1, 2026-10-09);
    #   * `check_repository_consistency.ps1` issue lines, indented `  <MULTI WORD LABEL>: ...`;
    #   * `CODE:` / `EVIDENCE:` refusals, suite totals `N passed, M failed`, TAP `not ok`, `ERROR:`,
   -#     mutation verdicts, and the runner's own `END exit=N`.
   +#     mutation verdicts, and the runner's own `END exit=N`;
   +#   * the evaluator's `TIME:` lines for each run, stage, profile and verification command (SPEC-283).
    # Structural families rather than a hand list of labels, so a new label of a known family is still
    # reported. CASE-SENSITIVE on purpose: with PowerShell's default case-insensitive `-match`, `FAIL\b`
    # matches the prose "fail-closed". Per-assertion `PASS 101 ...` lines are deliberately not results;
   -# every `FAIL` is.
   -$script:ResultRx = '(^(PASS|FAILED|SKIPPED?): .*|^\s*[A-Z][A-Z0-9_-]*(?: [A-Z0-9_-]+)*: (CLEAN|READY|PASSED|COMPLETE|DONE|PENDING|UNPROVEN|FAILED|BLOCKED|INCOMPLETE|RECOVERY_EXHAUSTED|NOT [A-Z]+|\d+ issue).*|^\s+[A-Z][A-Z0-9-]*(?: [A-Z0-9-]+)+: .*|^(CODE|EVIDENCE): (?!none\b).*|^\s*FAIL\b.*|\b\d+ passed, \d+ failed\b|\bnot ok\b|\bERROR:.*|ALL CHECKS PASSED|\bKILLED\b|\bSURVIVED\b|^END exit=\d+)'
   +# every `FAIL` is. Both are TESTS, recorded with their own time; a failed one is also printed. A line is
   +# judged a test FIRST, so `FAIL <name>` and TAP `not ok` - which the result vocabulary also matches - are
   +# timed and reported as the tests they are. A TAP `not ok` with a TODO or SKIP directive is not a
   +# failure (TAP 14 specification, "Directives").
   +$script:ResultRx = '(^(PASS|FAILED|SKIPPED?): .*|^\s*[A-Z][A-Z0-9_-]*(?: [A-Z0-9_-]+)*: (CLEAN|READY|PASSED|COMPLETE|DONE|PENDING|UNPROVEN|FAILED|BLOCKED|INCOMPLETE|RECOVERY_EXHAUSTED|NOT [A-Z]+|\d+ issue).*|^\s+[A-Z][A-Z0-9-]*(?: [A-Z0-9-]+)+: .*|^(CODE|EVIDENCE): (?!none\b).*|^\s*FAIL\b.*|\b\d+ passed, \d+ failed\b|\bnot ok\b|\bERROR:.*|ALL CHECKS PASSED|\bKILLED\b|\bSURVIVED\b|^END exit=\d+|^TIME: .*)'
    function Test-ResultLine([string]$Body) { $Body -cmatch $script:ResultRx }
   +$script:TestRx = '^\s*(PASS|FAIL)\s+[^:\s]\S*|^(not )?ok \d+\b'
   +function Test-TestLine([string]$Body) { $Body -cmatch $script:TestRx }
   +$script:FailedTestRx = '^\s*FAIL\s|^not ok\b(?!.*#\s*(?i:todo|skip)\b)'
   +# What -Brief still prints: anything that is or may be a failure, and the end. A pass prints nothing.
   +$script:AttentionRx = '(\bFAIL|\bFAILED\b|BLOCKED|^CODE: |\bnot ok\b|\bERROR:|\bSURVIVED\b|INCOMPLETE|UNPROVEN|RECOVERY_EXHAUSTED|\b[1-9]\d* failed\b|^END exit=|CERTIFY: )'

    # The runner's START line: `[yyyy-MM-dd HH:mm:ss] START pid=N <environment> | <command>`.
    function Read-StartLine([string]$Line) {
   @@ -63,12 +99,170 @@ function Get-RunningStage([int]$RunnerPid) {
        'running {0} since {1} (cpu {2:N0}s)' -f $name, $stage.CreationDate.ToString('HH:mm:ss'), $cpu
    }

   +# ---- history: the timings file, read as runs (SPEC-283) ---------------------------------------------
   +# A value that looks like a credential never reaches the screen or the history.
   +function Hide-Secret([string]$Text) {
   +    # GitHub's documented token prefixes (ghp_, gho_, ghu_, ghs_, ghr_, github_pat_), common API keys and
   +    # JWTs by shape; then any `key=value` or `key: value` whose key names a credential, and a bearer value.
   +    $t = $Text -replace '\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_\w{20,}|sk-[A-Za-z0-9_-]{20,}|eyJ[\w-]{10,}\.[\w-]{10,}\.[\w-]+)', '<redacted>'
   +    $t = $t -replace '(?i)\bbearer\s+(?!<redacted>)\S+', 'Bearer <redacted>'
   +    $t -replace '(?i)\b(token|secret|password|passwd|api[_-]?key|authorization)(\s*[:=]\s*)(?!Bearer <redacted>)(?!<redacted>)\S+', '$1$2<redacted>'
   +}
   +# A step's identity across runs: its text without the elapsed time it carries or the evidence after ` :: `.
   +function Get-StepKey([string]$Step) { ((($Step -replace ' :: .*$', '') -replace ' \d\d:\d\d:\d\d\s*$', '') -replace '\s+', ' ').Trim() }
   +function ConvertTo-Minutes([string]$Value) { [double]::Parse($Value, [Globalization.NumberStyles]::Float -bor [Globalization.NumberStyles]::AllowThousands, [Globalization.CultureInfo]::InvariantCulture) }
   +function Format-Minutes([double]$Value) { $Value.ToString('0.0###', [Globalization.CultureInfo]::InvariantCulture) }
   +function Get-Median([double[]]$Values) { $s = @($Values | Sort-Object); if (-not $s.Count) { return $null }; if ($s.Count % 2) { $s[($s.Count - 1) / 2] } else { ($s[$s.Count / 2 - 1] + $s[$s.Count / 2]) / 2 } }
   +# A `TIME:` line states its own duration, which is truer than the gap between two log stamps.
   +function Get-StatedMinutes([string]$Step) { if ($Step -match ' (\d\d):(\d\d):(\d\d)\s*$') { [int]$Matches[1] * 60 + [int]$Matches[2] + [int]$Matches[3] / 60 } else { $null } }
   +# `TIME: STAGES <mode> a=1.23s b=0.40s` as one row per stage.
   +function Split-Stages([string]$Body) {
   +    $m = [regex]::Match($Body, '^TIME: STAGES (?<mode>.+?) (?=\S+=[\d.]+s\b)'); if (-not $m.Success) { return }
   +    foreach ($s in [regex]::Matches($Body, '(?<n>[^\s=]+)=(?<v>[\d.]+)s\b')) { [pscustomobject]@{ Step = "STAGE $($m.Groups['mode'].Value) $($s.Groups['n'].Value)"; Minutes = [double]::Parse($s.Groups['v'].Value, [Globalization.CultureInfo]::InvariantCulture) / 60 } }
   +}
   +function Get-StepKind([string]$Step) {
   +    if ($Step -like 'END exit=*') { 'end' } elseif ($Step -like 'finding *') { 'finding' } elseif ($Step -like 'STAGE *') { 'stage' }
   +    elseif ($Step -like 'TIME: *') { 'time' } elseif (Test-TestLine $Step) { 'test' } else { 'result' }
   +}
   +# Every run of one -Run name but $Exclude: its steps, an index of each step's first occurrence, whether it
   +# ended, and whether it ended `END exit=0`.
   +function Read-History([object[]]$Rows, [string]$Name, [string]$Exclude = '') {
   +    foreach ($g in @($Rows | Where-Object { $_.run -eq $Name -and $_.date -ne $Exclude } | Group-Object date)) {
   +        $steps = @($g.Group | ForEach-Object { [pscustomobject]@{ Key = (Get-StepKey $_.step); T = (ConvertTo-Minutes $_.elapsed_min); Delta = (ConvertTo-Minutes $_.delta_min); Step = $_.step; Kind = (Get-StepKind $_.step) } })
   +        $index = @{}; foreach ($s in $steps) { if (-not $index.ContainsKey($s.Key)) { $index[$s.Key] = $s } }
   +        $end = @($steps | Where-Object { $_.Kind -eq 'end' }) | Select-Object -Last 1
   +        [pscustomobject]@{ Date = $g.Name; Ended = [bool]$end; Ok = [bool]($end -and $end.Step -match '^END exit=0\b'); Total = $(if ($end) { $end.T } else { $null }); Steps = $steps; Index = $index }
   +    }
   +}
   +# Minutes left, from what the last 10 comparable SUCCESSFUL runs still had to do after this step: failed
   +# and unfinished runs distort a duration, and a median with its range, not a mean, describes a long-tailed
   +# one (CI practice: Jenkins, TeamCity, Metabase). Two runs at least, or no estimate - one sample is a
   +# guess - and fewer than five are labelled a low sample.
   +function Get-Recent([object[]]$History, [int]$N) { @($History | Where-Object { $_.Ok } | Sort-Object Date | Select-Object -Last $N) }
   +function Get-Eta([object[]]$History, [string]$Key, [double]$Since, [double]$Now) {
   +    $left = @(foreach ($h in (Get-Recent $History 10)) {
   +        if ($Key) { $s = $h.Index[$Key]; if ($s) { $h.Total - $s.T - $Since } } else { $h.Total - $Now }
   +    })
   +    # A step the history has not seen yet (a new test) falls back to the runs' totals, under the same rule.
   +    if ($left.Count -lt 2 -and $Key) { return Get-Eta $History '' $Since $Now }
   +    if ($left.Count -lt 2) { return "eta: none - $($left.Count) comparable successful run(s) in the history$(if ($Key) { ' reached this step' })" }
   +    $s = @($left | Sort-Object)
   +    'eta: ~{0:N1} min left (median of {1} comparable successful runs{5}{4}; range {2:N1} to {3:N1})' -f [Math]::Max(0, (Get-Median $s)), $s.Count, [Math]::Max(0, $s[0]), [Math]::Max(0, $s[-1]), $(if ($s.Count -lt 5) { ', low sample' }), $(if (-not $Key) { ', by run totals' })
   +}
   +# Findings on one recorded line. $State dedupes them per run and counts this run's commands and steps.
   +function New-FindingState { [pscustomobject]@{ Said = [Collections.Generic.HashSet[string]]::new(); Keys = [Collections.Generic.HashSet[string]]::new(); Commands = @{} } }
   +function Get-StepFindings([object[]]$History, $State, [string]$Body, [double]$Delta) {
   +    $key = Get-StepKey $Body; [void]$State.Keys.Add($key); $found = @()
   +    if ($Body -cmatch '^(FAILED: |CODE: )|\bERROR:' -or $Body -cmatch $script:FailedTestRx) {
   +        $prior = @($History | Where-Object { $_.Index.ContainsKey($key) })
   +        if ($prior.Count) { $found += "finding [confirmed] recurring failure: $key - also in $($prior.Count) of $(@($History).Count) earlier runs" }
   +    }
   +    if ($Body -cmatch '^(PASS|FAILED): (?<cmd>.+?)(?: \(exit \d+\))?$') {
   +        $cmd = $Matches['cmd']; $State.Commands[$cmd] = 1 + [int]$State.Commands[$cmd]
   +        if ($State.Commands[$cmd] -eq 2) { $found += "finding [hypothesis] repeated execution: $cmd ran twice in this run - wasteful unless its profile lists it twice on purpose" }
   +    }
   +    $d = @(foreach ($h in (Get-Recent $History 10)) { $s = $h.Index[$key]; if ($s) { $s.Delta } })
   +    if ($d.Count -ge 3) { $med = Get-Median $d; if ($Delta -gt [Math]::Max(1.5 * $med, $med + 1)) { $found += ('finding [hypothesis] slow step: {0} took {1:N1} min against a median of {2:N1} over {3} successful runs' -f $key, $Delta, $med, $d.Count) } }
   +    @($found | Where-Object { $State.Said.Add($_) })
   +}
   +# At END: steps each of the last successful runs had and this one lacks (one finding, however many), and
   +# a run slower than they were.
   +function Get-EndFindings([object[]]$History, $State, [double]$Total) {
   +    $ok = Get-Recent $History 5; $found = @()
   +    if ($ok.Count -ge 3) {
   +        $absent = @($ok[0].Index.Keys | Where-Object { $_ -notlike 'END exit=*' -and $_ -notlike 'finding *' -and -not $State.Keys.Contains($_) } | Where-Object { $k = $_; -not @($ok | Where-Object { -not $_.Index.ContainsKey($k) }).Count } | Sort-Object)
   +        if ($absent.Count -eq 1) { $found += "finding [hypothesis] expected step absent: $($absent[0]) - present in each of the last $($ok.Count) successful runs" }
   +        elseif ($absent.Count) { $found += "finding [hypothesis] expected steps absent: $($absent.Count) steps each of the last $($ok.Count) successful runs had (first: $($absent[0]))" }
   +        $med = Get-Median @($ok | ForEach-Object { $_.Total })
   +        if ($Total -gt [Math]::Max(1.25 * $med, $med + 2)) { $found += ('finding [hypothesis] slower run: {0:N1} min against a median of {1:N1} over the last {2} successful runs' -f $Total, $med, $ok.Count) }
   +    }
   +    @($found | Where-Object { $State.Said.Add($_) })
   +}
   +# The history, summarised: where the time goes, the slowest tests and stages, which runs regressed, which
   +# failures recur. A failure rate is per run of its own -Run name, so a run that executes often is not
   +# ranked worse for being run. The top lists are views; every row stays in the history.
   +function Format-Report([object[]]$Rows, [string]$Only) {
   +    $rates = @()
   +    foreach ($n in @($Rows | ForEach-Object { $_.run } | Sort-Object -Unique | Where-Object { -not $Only -or $_ -eq $Only })) {
   +        $h = @(Read-History $Rows $n); $ok = @($h | Where-Object { $_.Ok } | Sort-Object Date); $ended = @($h | Where-Object { $_.Ended })
   +        $line = '{0}: {1} runs, {2} ended, {3} succeeded' -f $n, $h.Count, $ended.Count, $ok.Count
   +        if ($ok.Count) {
   +            $t = @($ok | ForEach-Object { $_.Total } | Sort-Object); $med = Get-Median $t
   +            $line += '; median {0:N2} min, p90 {1:N2}' -f $med, $t[[Math]::Max(0, [Math]::Ceiling(0.9 * $t.Count) - 1)]
   +            if ($ok.Count -ge 3 -and $ok[-1].Total -gt [Math]::Max(1.25 * $med, $med + 2)) { $line += ('; REGRESSION [hypothesis]: latest {0:N2} min' -f $ok[-1].Total) }
   +        }
   +        $line
   +        $share = @{}; $sum = 0.0
   +        foreach ($r in $ok) { foreach ($s in $r.Steps) { if ($s.Kind -ne 'result') { continue }; $share[$s.Key] += $s.Delta; $sum += $s.Delta } }
   +        if ($sum -gt 0) { foreach ($e in @($share.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3)) { '  time {0,3:N0}%  {1}' -f (100 * $e.Value / $sum), $e.Key } }
   +        # A stage's or a test's time is its own whether its run succeeded or not, so a failed test is ranked too.
   +        foreach ($kind in 'stage', 'test') {
   +            $per = @{}; foreach ($r in $h) { foreach ($s in @($r.Steps | Where-Object { $_.Kind -eq $kind })) { $per[$s.Key] += @($s.Delta) } }
   +            foreach ($e in @($per.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Key = $_.Key; Med = (Get-Median $_.Value) } } | Sort-Object Med -Descending | Select-Object -First 5)) { '  slowest {0} {1,7:N3} min  {2}' -f $kind, $e.Med, $e.Key }
   +        }
   +        foreach ($k in @($h | ForEach-Object { @($_.Steps | Where-Object { $_.Step -cmatch '^(FAILED: |CODE: |END exit=[1-9])' -or $_.Step -cmatch $script:FailedTestRx } | ForEach-Object { $_.Key } | Select-Object -Unique) } | Group-Object)) {
   +            $rates += [pscustomobject]@{ Run = $n; Key = $k.Name; Runs = $k.Count; Of = $h.Count; Rate = $k.Count / [Math]::Max(1, $h.Count) }
   +        }
   +        $f = @($h | ForEach-Object { $_.Steps } | Where-Object { $_.Kind -eq 'finding' } | ForEach-Object { $_.Key -replace '^(finding \[\w+\] [^:]+):.*$', '$1' } | Group-Object)
   +        if ($f.Count) { '  findings: ' + (@($f | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join '; ') }
   +    }
   +    $ranked = @($rates | Where-Object { $_.Of -ge 3 } | Sort-Object @{ Expression = 'Rate'; Descending = $true }, @{ Expression = 'Of'; Descending = $true } | Select-Object -First 8)
   +    if ($ranked.Count) { 'failures by rate (runs affected / runs of that name; names with at least 3 runs):' }
   +    foreach ($x in $ranked) { '  {0,3:N0}%  {1} in {2} of {3} {4} runs{5}' -f (100 * $x.Rate), $x.Key, $x.Runs, $x.Of, $x.Run, $(if ($x.Runs -ge 2) { ' - investigate [hypothesis]: a Skill, Guard or Hook is a candidate only once the Improvement Loop shows need, gap and value' }) }
   +}
   +# The history's one write path, shared VERBATIM with scripts/check_agent_continuity.ps1 (scripts/watch_selftest.ps1
   +# holds the two copies equal). A named mutex per history file serialises every writer and the watcher's
   +# reads across processes, so an append never interleaves with another append or with a trim. The bound
   +# holds after every append: past $MaxBytes the history keeps its newest whole rows within half of it,
   +# written to a temporary file beside it and moved over it, so the history is never rewritten in place.
   +function Use-TimingHistory([string]$Path, [scriptblock]$Body) {
   +    $id = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Path).ToLowerInvariant())))
   +    $lock = [Threading.Mutex]::new($false, 'Global\ORVION-timings-' + $id.Substring(0, 32))
   +    try {
   +        # An abandoned mutex (its holder was killed) is acquired: the history is only ever replaced whole.
   +        try { if (-not $lock.WaitOne(15000)) { throw "the timing history $Path stayed locked for 15 s" } } catch [Threading.AbandonedMutexException] { }
   +        try { & $Body } finally { $lock.ReleaseMutex() }
   +    } finally { $lock.Dispose() }
   +}
   +function Add-TimingRows([string]$Path, [string[]]$Rows, [long]$MaxBytes) {
   +    Use-TimingHistory $Path {
   +        if (-not [IO.File]::Exists($Path)) { [IO.File]::WriteAllText($Path, 'run,date,step,elapsed_min,delta_min,env' + [Environment]::NewLine) }
   +        if ($Rows.Count) { [IO.File]::AppendAllText($Path, ($Rows -join [Environment]::NewLine) + [Environment]::NewLine) }
   +        if ([IO.FileInfo]::new($Path).Length -le $MaxBytes) { return }
   +        $b = [IO.File]::ReadAllBytes($Path); $h = [Array]::IndexOf($b, [byte]10) + 1
   +        $n = [Array]::IndexOf($b, [byte]10, [int][Math]::Max($h, $b.Length - [Math]::Floor($MaxBytes / 2))); $cut = if ($n -lt 0) { $b.Length } else { $n + 1 }
   +        $tmp = "$Path.tmp"; $f = [IO.File]::Create($tmp); try { $f.Write($b, 0, $h); $f.Write($b, $cut, $b.Length - $cut) } finally { $f.Dispose() }
   +        [IO.File]::Move($tmp, $Path, $true)
   +        'history: kept the newest {0:N0} of {1:N0} bytes of rows (limit {2:N0})' -f ($b.Length - $cut), ($b.Length - $h), $MaxBytes
   +    }
   +}
   +function Read-TimingRows([string]$Path) {
   +    try { @((Use-TimingHistory $Path { [IO.File]::ReadAllLines($Path) }) | ConvertFrom-Csv) } catch { Write-Warning "history: not read - $($_.Exception.Message)"; @() }
   +}
   +function Write-Row([string]$Path, [string]$Name, [string]$Identity, [string]$Step, [double]$T, [double]$Delta, [string]$Conditions) {
   +    try { Add-TimingRows $Path @('"{0}","{1}","{2}",{3},{4},"{5}"' -f $Name, $Identity, ($Step -replace '"', "'"), (Format-Minutes $T), (Format-Minutes $Delta), $Conditions) $MaxBytes }
   +    catch { "history: row not written - $($_.Exception.Message)" }
   +}
   +
    if ($MyInvocation.InvocationName -eq '.') { return }   # dot-sourced by scripts/watch_selftest.ps1 for the functions above
   -if (-not $Log -or -not $Run) { throw 'usage: watch_run.ps1 -Log <run_timed log> -Run <stable name>' }
    $ErrorActionPreference = 'Continue'
   -$Log = [IO.Path]::GetFullPath($Log, (Get-Location).Path)
    [void][IO.Directory]::CreateDirectory((Split-Path $Csv -Parent))
   -if (-not (Test-Path -LiteralPath $Csv)) { 'run,date,step,elapsed_min,delta_min,env' | Out-File -LiteralPath $Csv -Encoding utf8 }
   +try { Add-TimingRows $Csv @() $MaxBytes } catch { "history: not prepared - $($_.Exception.Message)" }   # creates it; bounds one an older writer left over its limit
   +if ($Report) { Format-Report @(Read-TimingRows $Csv) $Run; exit 0 }
   +if (-not $Log -or -not $Run) { throw 'usage: watch_run.ps1 -Log <run_timed log> -Run <stable name> [-Brief] [-Eta] | -Report [-Run <name>]' }
   +$Log = [IO.Path]::GetFullPath($Log, (Get-Location).Path)
   +$StampRx = '^\[\+\s*(?<t>[\d.]+) min\] (?<body>.*)$'
   +
   +if ($Eta) {
   +    $first = if (Test-Path -LiteralPath $Log) { Read-StartLine (Get-Content -LiteralPath $Log -TotalCount 1 -Encoding utf8) }
   +    if (-not $first) { 'eta: none - no START line in the log yet'; exit 0 }
   +    $lines = @(Get-Content -LiteralPath $Log -Encoding utf8 | ForEach-Object { [regex]::Match($_, $StampRx) } | Where-Object { $_.Success -and ((Test-ResultLine $_.Groups['body'].Value) -or (Test-TestLine $_.Groups['body'].Value)) })
   +    $now = ((Get-Date) - $first.At).TotalMinutes
   +    $hist = @(Read-History @(Read-TimingRows $Csv) $Run $first.At.ToString('yyyy-MM-dd HH:mm:ss'))
   +    if ($lines.Count -and $lines[-1].Groups['body'].Value -match '^END exit=') { "eta: the run has ended ($($lines[-1].Groups['body'].Value))"; exit 0 }
   +    if ($lines.Count) { $t = [double]::Parse($lines[-1].Groups['t'].Value, [Globalization.CultureInfo]::InvariantCulture); Get-Eta $hist (Get-StepKey $lines[-1].Groups['body'].Value) ($now - $t) $now } else { Get-Eta $hist '' 0 $now }
   +    exit 0
   +}

    $wait = [Diagnostics.Stopwatch]::StartNew(); $lastNote = 0.0; $start = $null
    while (-not $start) {
   @@ -79,26 +273,43 @@ while (-not $start) {
    }
    $identity = $start.At.ToString('yyyy-MM-dd HH:mm:ss')   # identifies THIS run; a re-armed watcher computes the same value
    'watching {0} (started {1}, attached {2}, runner pid {3}; {4})' -f $Run, $identity, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $start.Pid, $start.Env
   -$have = @{}; Import-Csv -LiteralPath $Csv | ForEach-Object { $have[($_.run, $_.date, $_.step, $_.elapsed_min) -join '|'] = 1 }
   -$seen = 0; $last = 0.0; $quiet = [Diagnostics.Stopwatch]::StartNew()
   +$rows = @(Read-TimingRows $Csv); $have = @{}; $rows | ForEach-Object { $have[($_.run, $_.date, $_.step, $_.elapsed_min) -join '|'] = 1 }
   +$history = @(Read-History $rows $Run $identity); $state = New-FindingState; $conditions = "$($start.Env) log=$Log"; $lastKey = ''
   +function Save-Step([string]$Step, [double]$T, [double]$Delta) {
   +    $key = ($Run, $identity, $Step, (Format-Minutes $T)) -join '|'
   +    if (-not $have.ContainsKey($key)) { $have[$key] = 1; Write-Row $Csv $Run $identity $Step $T $Delta $conditions }
   +}
   +$seen = 0; $last = 0.0; $prevLine = 0.0; $tests = 0; $results = 0; $failed = 0; $lastProgress = 0.0; $quiet = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $lines = @(Get-Content -LiteralPath $Log -Encoding utf8)
        if ($lines.Count -gt $seen) {
            foreach ($line in $lines[$seen..($lines.Count - 1)]) {
   -            $m = [regex]::Match($line, '^\[\+\s*(?<t>[\d.]+) min\] (?<body>.*)$')
   +            $m = [regex]::Match($line, $StampRx)
                if (-not $m.Success) { continue }
   -            $t = [double]$m.Groups['t'].Value; $body = $m.Groups['body'].Value
   -            if (-not (Test-ResultLine $body)) { continue }
   +            $t = [double]::Parse($m.Groups['t'].Value, [Globalization.CultureInfo]::InvariantCulture); $body = Hide-Secret $m.Groups['body'].Value
   +            $sinceLine = $t - $prevLine; $prevLine = $t
   +            if ($Brief -and $t - $lastProgress -ge $ProgressMinutes) {
   +                $lastProgress = $t; $now = ((Get-Date) - $start.At).TotalMinutes
   +                'progress: {0:N1} min - {1} tests and {2} results so far, {3} failing; {4}' -f $t, $tests, $results, $failed, (Get-Eta $history $lastKey ($now - $t) $now)
   +            }
                $step = ($body.Substring(0, [Math]::Min(160, $body.Length))) -replace '"', "'"
   -            $delta = $t - $last; $last = $t
   -            '[{0,5:N1} min | +{1:N1}] {2}' -f $t, $delta, $step
   -            $key = ($Run, $identity, $step, ('{0:N1}' -f $t)) -join '|'
   -            if (-not $have.ContainsKey($key)) {
   -                $have[$key] = 1
   -                '"{0}","{1}","{2}",{3:N1},{4:N1},"{5}"' -f $Run, $identity, $step, $t, $delta, $start.Env | Out-File -LiteralPath $Csv -Append -Encoding utf8
   +            if (Test-TestLine $body) {
   +                $tests++; $lastKey = Get-StepKey $step; Save-Step $step $t $sinceLine
   +                if ($body -cmatch $script:FailedTestRx) { $failed++; '[{0,5:N1} min | +{1:N1}] {2}' -f $t, $sinceLine, $step }
   +                foreach ($f in (Get-StepFindings $history $state $step $sinceLine)) { $f; Save-Step $f $t 0 }
   +                continue
                }
   +            if (-not (Test-ResultLine $body)) { continue }
   +            $results++; if ($body -cmatch $script:AttentionRx -and $body -notmatch '^END exit=0\b|\b0 failed\b|: READY\b') { $failed++ }
   +            $delta = $t - $last; $last = $t; $lastKey = Get-StepKey $step
   +            if (-not $Brief -or $body -cmatch $script:AttentionRx) { '[{0,5:N1} min | +{1:N1}] {2}' -f $t, $delta, $step }
   +            $stages = @(Split-Stages $body)
   +            if ($stages.Count) { $at = $t; foreach ($s in $stages) { Save-Step $s.Step $at $s.Minutes } }
   +            else { $stated = Get-StatedMinutes $step; Save-Step $step $t $(if ($null -ne $stated -and $step -like 'TIME: *') { $stated } else { $delta }) }
   +            $found = if ($body -match '^END exit=') { Get-EndFindings $history $state $t } else { Get-StepFindings $history $state $step $delta }
   +            foreach ($f in $found) { $f; Save-Step $f $t 0 }
                if ($body -match '^END exit=') {
   -                $prev = Import-Csv -LiteralPath $Csv | Where-Object { $_.run -eq $Run -and $_.step -like 'END exit=*' -and $_.date -ne $identity } | Select-Object -Last 1
   +                $prev = Read-TimingRows $Csv | Where-Object { $_.run -eq $Run -and $_.step -like 'END exit=*' -and $_.date -ne $identity } | Select-Object -Last 1
                    if ($prev) { 'compare: this run {0:N1} min [{1}] vs previous {2} min on {3} [{4}]' -f $t, $start.Env, $prev.elapsed_min, $prev.date, $prev.env }
                    else { "compare: first recorded run of '$Run' ($('{0:N1}' -f $t) min) [$($start.Env)]" }
                    exit [int]($body -notmatch '^END exit=0\b')
   @@ -111,7 +322,8 @@ while ($true) {
            'RUNNER GONE: process {0} exited without an END line after {1:N1} min (last result at {2:N1} min) - the run did not finish' -f $start.Pid, ((Get-Date) - $start.At).TotalMinutes, $last
            exit 1
        } elseif ($quiet.Elapsed.TotalMinutes -ge $QuietMinutes) {
   -        'heartbeat: no new output for {0:N1} min (last result at {1:N1} min) - {2}' -f $quiet.Elapsed.TotalMinutes, $last, (Get-RunningStage $start.Pid)
   +        $now = ((Get-Date) - $start.At).TotalMinutes
   +        'heartbeat: no new output for {0:N1} min (last result at {1:N1} min) - {2}; {3}' -f $quiet.Elapsed.TotalMinutes, $last, (Get-RunningStage $start.Pid), (Get-Eta $history $lastKey ($now - $prevLine) $now)
            $quiet.Restart()
        }
        Start-Sleep -Seconds $PollSeconds
   diff --git a/scripts/watch_selftest.ps1 b/scripts/watch_selftest.ps1
   index 6b2b7f7..144828e 100644
   --- a/scripts/watch_selftest.ps1
   +++ b/scripts/watch_selftest.ps1
   @@ -36,7 +36,7 @@ function Wait-Exit($Process, [int]$Seconds) { if (-not $Process.WaitForExit($Sec
    function New-Name([string]$Ext) { Join-Path $Work ([guid]::NewGuid().ToString('N') + $Ext) }

    $RepoRoot = Split-Path $Tools -Parent   # where check_agent_continuity.ps1, the CI contract's authority, lives
   -$Runner = Join-Path $Tools 'run_timed.ps1'; $Watcher = Join-Path $Tools 'watch_run.ps1'; $Ci = Join-Path $Tools 'watch_ci.ps1'
   +$Runner = Join-Path $Tools 'run_timed.ps1'; $Watcher = Join-Path $Tools 'watch_run.ps1'; $Ci = Join-Path $Tools 'watch_ci.ps1'; $Evaluator = Join-Path $Tools 'check_agent_continuity.ps1'
    $Stage = Join-Path $Work 'scripts\fake_stage.ps1'
    # A silent stage whose NEWEST descendant is not a script (as a real suite's git or docker child is):
    # the heartbeat must still name the script.
   @@ -53,11 +53,114 @@ function Case-Vocabulary([string]$WatcherPath) {
            '== 41 passed, 1 failed ==', 'not ok 3 - fixture', 'ERROR:  relation "x" does not exist', 'FAIL 12 the guard refused',
            'END exit=1 total=0.4 min concurrent_end=0', 'M1 KILLED', 'ALL CHECKS PASSED',
            'WORKSTATION VERIFICATION: PASSED', 'WORKSTATION PREPARATION: COMPLETE', 'PUBLISH: DONE', 'REMOTE_CERTIFY: PENDING',
   -        'DATABASE PARITY: UNPROVEN -- local matches the repository, but PRIMARY WAS NOT CONTACTED.', 'HARD_BLOCKED: RECOVERY_EXHAUSTED', 'DATABASE PARITY: 3 issue(s) found')
   +        'DATABASE PARITY: UNPROVEN -- local matches the repository, but PRIMARY WAS NOT CONTACTED.', 'HARD_BLOCKED: RECOVERY_EXHAUSTED', 'DATABASE PARITY: 3 issue(s) found',
   +        'TIME: Gate range 00:00:04', 'TIME: REPOSITORY pwsh -NoProfile -File scripts/check_repository_consistency.ps1 00:00:12', 'TIME: PROFILE CONTROL 00:31:02',
   +        'TIME: STAGES Gate range setup=0.05s range-walk=3.10s other=0.20s')
        $noise = @('PASS 101 the guard holds', 'the guard is fail-closed by design', 'CODE: none', 'error: lowercase prose', 'Checking 27 anchors', 'Failed attempts are retried by nobody', 'MODE: PLAN')
        $missed = @($results | Where-Object { -not (Test-ResultLine $_) }); $leaked = @($noise | Where-Object { Test-ResultLine $_ })
        [pscustomobject]@{ Ok = (-not $missed -and -not $leaked); Detail = "missed=[$($missed -join ' | ')] leaked=[$($leaked -join ' | ')]" }
    }
   +# ---- history, ETA, findings and report (SPEC-283): unit cases on fixture rows -------------------------
   +function Rows([string]$Name, [string]$Date, [object[]]$Steps) {
   +    foreach ($s in $Steps) { [pscustomobject]@{ run = $Name; date = $Date; step = $s[0]; elapsed_min = "$($s[1])"; delta_min = "$($s[2])"; env = 'host=H' } }
   +}
   +function OkRun([string]$Date, [double]$End, [double]$XDelta = 1) { Rows 'r' $Date @(@('PASS: x', 1, $XDelta), @('PASS: y', 2, 1), @("END exit=0 total=$End min", $End, ($End - 2))) }
   +# Successful runs only, the median of what each still had to do, its range, and no estimate from one run.
   +function Case-Eta([string]$WatcherPath) {
   +    . $WatcherPath
   +    $hist = @(Read-History @((OkRun 'a' 5) + (OkRun 'b' 6) + (OkRun 'c' 7) + (Rows 'r' 'f' @(@('PASS: x', 1, 1), @('END exit=1', 1.5, 0.5)))) 'r')
   +    $three = Get-Eta $hist 'PASS: x' 0 1; $one = Get-Eta @($hist | Where-Object { $_.Date -in 'a', 'f' }) 'PASS: x' 0 1; $new = Get-Eta $hist 'PASS: a test no run has had' 0 1
   +    $log = New-Name '.log'; Set-Content -LiteralPath $log -Value @('[2026-10-15 10:00:00] START pid=1 host=H | x', '[+   1.0 min] PASS: x', '[+   2.0 min] END exit=0 total=2.0 min concurrent_end=0') -Encoding utf8
   +    $ended = @(& pwsh -NoProfile -File $WatcherPath -Log $log -Run 'r' -Eta -Csv (New-Name '.csv') 2>&1) -join ' '
   +    [pscustomobject]@{ Ok = ($three -eq 'eta: ~5.0 min left (median of 3 comparable successful runs, low sample; range 4.0 to 6.0)' -and $new -eq 'eta: ~5.0 min left (median of 3 comparable successful runs, by run totals, low sample; range 4.0 to 6.0)' -and $one -match '^eta: none - 1 comparable' -and $ended -match '^eta: the run has ended \(END exit=0'); Detail = "three=[$three] new=[$new] one=[$one] ended=[$ended]" }
   +}
   +# Each finding once, labelled by what the evidence supports.
   +function Case-Findings([string]$WatcherPath) {
   +    . $WatcherPath
   +    $hist = @(Read-History @((OkRun 'a' 5) + (OkRun 'b' 6) + (OkRun 'c' 7) + (Rows 'r' 'f' @(@('FAILED: z (exit 1)', 1, 1), @('END exit=1', 1.5, 0.5)))) 'r')
   +    $st = New-FindingState
   +    $f = @(foreach ($b in 'FAILED: z (exit 1)', 'FAILED: z (exit 1)', 'PASS: x', 'PASS: x', 'PASS: x') { Get-StepFindings $hist $st $b $(if ($b -eq 'PASS: x') { 5 } else { 1 }) }) + @(Get-EndFindings $hist $st 20) + @(Get-EndFindings $hist $st 20)
   +    $want = @('finding [confirmed] recurring failure: FAILED: z (exit 1) - also in 1 of 4 earlier runs', 'finding [hypothesis] repeated execution: z ran twice',
   +        'finding [hypothesis] slow step: PASS: x took 5.0 min', 'finding [hypothesis] repeated execution: x ran twice', 'finding [hypothesis] expected step absent: PASS: y', 'finding [hypothesis] slower run: 20.0 min')
   +    $missing = @($want | Where-Object { $w = $_; -not @($f | Where-Object { $_.StartsWith($w) }).Count })
   +    $calm = @(Get-StepFindings @() (New-FindingState) 'FAILED: z (exit 1)' 9)
   +    [pscustomobject]@{ Ok = ($f.Count -eq $want.Count -and -not $missing -and -not $calm.Count); Detail = "count=$($f.Count) missing=[$($missing -join ' | ')] calm=[$($calm -join ' | ')] all=[$($f -join ' | ')]" }
   +}
   +# A failure rate is per run of its own name: two failures in three runs outrank two in twenty.
   +function Case-Report([string]$WatcherPath) {
   +    $csv = New-Name '.csv'; 'run,date,step,elapsed_min,delta_min,env' | Out-File -LiteralPath $csv -Encoding utf8
   +    $rows = foreach ($i in 1..20) { Rows 'often' "o$i" @(@('PASS: build', 2, 2), @($(if ($i -le 2) { 'FAILED: flaky (exit 1)' } else { 'PASS: flaky' }), 3, 1), @("END exit=$([int]($i -le 2))", 3, 0)) }
   +    $rows += foreach ($i in 1..3) { Rows 'rare' "r$i" @(@($(if ($i -le 2) { 'FAILED: rare (exit 1)' } else { 'PASS: rare' }), 1, 1), @("END exit=$([int]($i -le 2))", 1, 0)) }
   +    $rows | Export-Csv -LiteralPath $csv -Append -NoTypeInformation -Encoding utf8
   +    $o = @(& pwsh -NoProfile -File $WatcherPath -Report -Csv $csv 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE
   +    $i = [array]::IndexOf($o, ($o | Where-Object { $_ -match 'FAILED: rare' } | Select-Object -First 1)); $j = [array]::IndexOf($o, ($o | Where-Object { $_ -match 'FAILED: flaky' } | Select-Object -First 1))
   +    [pscustomobject]@{ Ok = ($code -eq 0 -and $i -ge 0 -and $j -gt $i -and @($o -match 'time\s+67%\s+PASS: build').Count -eq 1 -and @($o -match '67%\s+FAILED: rare \(exit 1\) in 2 of 3 rare runs - investigate \[hypothesis\]').Count -eq 1); Detail = "exit=$code rare@$i flaky@$j || $($o -join ' || ')" }
   +}
   +function Case-Redact([string]$WatcherPath) {
   +    . $WatcherPath
   +    $r = Hide-Secret 'FAIL 3 secret scanning on; token=abc123 Authorization: Bearer xyz9 ghp_aaaaaaaaaaaaaaaaaaaaaaaa1 password: hunter2'
   +    [pscustomobject]@{ Ok = ($r -match 'secret scanning on' -and $r -notmatch 'abc123|xyz9|ghp_a|hunter2'); Detail = $r }
   +}
   +# One append past the bound leaves the history within it: the header, then the newest WHOLE rows, the new one last.
   +function Case-Limit([string]$WatcherPath) {
   +    . $WatcherPath
   +    $csv = New-Name '.csv'; [IO.File]::WriteAllLines($csv, @('run,date,step,elapsed_min,delta_min,env') + @(1..200 | ForEach-Object { """r"",""d$_"",""PASS: x"",1,1,""h""" }))
   +    $said = Add-TimingRows $csv @('"r","dnew","PASS: newest",1,1,"h"') 2000; $left = [IO.File]::ReadAllLines($csv); $bytes = (Get-Item -LiteralPath $csv).Length
   +    $broken = @($left | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^"r","d\w+","PASS: \w+",1,1,"h"$' }).Count
   +    [pscustomobject]@{ Ok = ($bytes -le 2000 -and $left[0] -like 'run,*' -and $left[-1] -match 'dnew' -and $left[-2] -match '"d200"' -and -not $broken -and $said -match 'kept the newest' -and -not (Test-Path -LiteralPath "$csv.tmp")); Detail = "bytes=$bytes lines=$($left.Count) broken=$broken said=[$said]" }
   +}
   +# A failed test is a TEST - timed, counted and ranked with the others - and a failure; a TAP `not ok` with a
   +# TODO or SKIP directive is a test but not a failure (TAP 14).
   +function Case-Classify([string]$WatcherPath) {
   +    . $WatcherPath
   +    $kinds = (@('FAIL 7 the slow failing test', 'not ok 4 - a failing tap test', 'not ok 5 - later # TODO not yet', 'PASS 8 fine', 'FAILED: x (exit 1)') | ForEach-Object { Get-StepKind $_ }) -join ','
   +    $failing = @(@('FAIL 7 the slow failing test', 'not ok 4 - a failing tap test', 'not ok 5 - later # TODO not yet', 'not ok 6 # skip no database', 'PASS 8 fine') | Where-Object { $_ -cmatch $script:FailedTestRx }).Count
   +    $csv = New-Name '.csv'; 'run,date,step,elapsed_min,delta_min,env' | Out-File -LiteralPath $csv -Encoding utf8
   +    $rows = foreach ($i in 1..3) { Rows 'suite' "s$i" @(@('PASS 8 fine', 1, 0.1), @($(if ($i -le 2) { 'FAIL 7 the slow failing test' } else { 'PASS 7 the slow test' }), 4, 3), @("END exit=$([int]($i -le 2))", 4, 0)) }
   +    $rows | Export-Csv -LiteralPath $csv -Append -NoTypeInformation -Encoding utf8
   +    $o = @(& pwsh -NoProfile -File $WatcherPath -Report -Csv $csv 2>&1 | ForEach-Object { "$_" })
   +    [pscustomobject]@{ Ok = ($kinds -eq 'test,test,test,test,result' -and $failing -eq 2 -and @($o -match '^\s+slowest test\s+3\.000 min\s+FAIL 7 the slow failing test$').Count -eq 1 -and @($o -match '67%\s+FAIL 7 the slow failing test in 2 of 3 suite runs').Count -eq 1)
   +                       Detail = "kinds=[$kinds] failing=$failing || $($o -join ' || ')" }
   +}
   +# Writers in separate processes - the evaluator's copy of the write path and the watcher's - appending at
   +# once: with no bound reached every row arrives whole, exactly once; past a small bound the history stays
   +# within it, every line whole, and what each writer still has is its own newest rows.
   +function Get-FunctionText([string]$Path, [string]$Name) {
   +    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
   +    @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true) | ForEach-Object { $_.Extent.Text })
   +}
   +function Case-Concurrent([string]$WatcherPath, [string]$EvaluatorPath, [long]$Max, [int]$Count = 150) {
   +    $fns = New-Name '.ps1'; (@('Use-TimingHistory', 'Add-TimingRows') | ForEach-Object { Get-FunctionText $EvaluatorPath $_ }) -join "`n" | Set-Content -LiteralPath $fns -Encoding utf8
   +    $writer = New-Name '.ps1'; $go = New-Name '.go'; $csv = New-Name '.csv'
   +    @('param([string]$Fns, [string]$HistoryFile, [long]$Limit, [int]$Count, [string]$Tag, [string]$Go)',
   +      'function Write-All { . $Fns; while (-not (Test-Path -LiteralPath $Go)) { Start-Sleep -Milliseconds 20 }',
   +      '  foreach ($i in 1..$Count) { try { Add-TimingRows $HistoryFile @(''"{0}","d","PASS {0} row {1}",1,1,"h"'' -f $Tag, $i) $Limit | Out-Null } catch { "error: $($_.Exception.Message)" } } }',
   +      'Write-All') | Set-Content -LiteralPath $writer -Encoding utf8
   +    $procs = foreach ($w in @(@('eval1', $fns), @('eval2', $fns), @('eval3', $fns), @('watch1', $WatcherPath), @('watch2', $WatcherPath), @('watch3', $WatcherPath))) {
   +        $out = New-Name '.out'; [pscustomobject]@{ Tag = $w[0]; Out = $out; P = (Start-Pwsh ('-File {0} -Fns {1} -HistoryFile {2} -Limit {3} -Count {4} -Tag {5} -Go {6}' -f (Q $writer), (Q $w[1]), (Q $csv), $Max, $Count, $w[0], (Q $go)) $out) }
   +    }
   +    Start-Sleep -Seconds 4; Set-Content -LiteralPath $go -Value 'go'
   +    $done = @($procs | Where-Object { Wait-Exit $_.P 120 }).Count -eq $procs.Count
   +    $errors = @($procs | ForEach-Object { Get-Content -LiteralPath $_.Out -ErrorAction SilentlyContinue } | Where-Object { $_ -match '^error:' })
   +    $lines = @(if (Test-Path -LiteralPath $csv) { [IO.File]::ReadAllLines($csv) }); $bytes = if (Test-Path -LiteralPath $csv) { (Get-Item -LiteralPath $csv).Length } else { -1 }
   +    $broken = @($lines | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^"(eval|watch)\d","d","PASS (eval|watch)\d row \d+",1,1,"h"$' }).Count
   +    $suffix = $true; foreach ($p in $procs) {
   +        $mine = @($lines | Where-Object { $_ -match "^""$($p.Tag)""," } | ForEach-Object { [int]($_ -replace '^.* row (\d+)",.*$', '$1') })
   +        if ($mine.Count -and (($mine -join ',') -ne ((($Count - $mine.Count + 1)..$Count) -join ','))) { $suffix = $false }
   +    }
   +    [pscustomobject]@{ Done = $done; Errors = $errors.Count; Header = ($lines.Count -and $lines[0] -eq 'run,date,step,elapsed_min,delta_min,env'); Rows = $lines.Count - 1; Unique = @($lines | Select-Object -Skip 1 -Unique).Count; Broken = $broken; Bytes = $bytes; Suffix = $suffix; Last = $(if ($lines.Count) { $lines[-1] } else { '' })
   +                       Detail = "done=$done errors=$($errors.Count) [$(($errors | Select-Object -First 2) -join ' | ')] rows=$($lines.Count - 1) broken=$broken bytes=$bytes suffix=$suffix last=[$(if ($lines.Count) { $lines[-1] })]" }
   +}
   +function Case-ConcurrentAll([string]$WatcherPath, [string]$EvaluatorPath) {
   +    $a = Case-Concurrent $WatcherPath $EvaluatorPath 100MB; $b = Case-Concurrent $WatcherPath $EvaluatorPath 6000
   +    $okA = $a.Done -and -not $a.Errors -and $a.Header -and $a.Rows -eq 900 -and $a.Unique -eq 900 -and -not $a.Broken
   +    $okB = $b.Done -and -not $b.Errors -and $b.Header -and $b.Bytes -le 6000 -and $b.Rows -lt 900 -and -not $b.Broken -and $b.Suffix -and $b.Last -match ' row 150",'
   +    [pscustomobject]@{ Ok = ($okA -and $okB); Detail = "unbounded: $($a.Detail) || bounded 6000: $($b.Detail)" }
   +}
   +function Case-SharedWriter([string]$WatcherPath, [string]$EvaluatorPath) {
   +    $diff = @(foreach ($n in 'Use-TimingHistory', 'Add-TimingRows') { $w = @(Get-FunctionText $WatcherPath $n); $e = @(Get-FunctionText $EvaluatorPath $n); if ($w.Count -ne 1 -or $e.Count -ne 1 -or $w[0] -cne $e[0]) { $n } })
   +    [pscustomobject]@{ Ok = (-not $diff.Count); Detail = "differ=[$($diff -join ',')]" }
   +}
    function Case-StartLine([string]$WatcherPath) {
        . $WatcherPath
        $s = Read-StartLine '[2026-10-09 10:35:40] START pid=4242 host=H pwsh=7.6.6 cpus=8 head=697b050 concurrent=0 | pwsh -NoProfile -File x.ps1'
   @@ -139,6 +242,42 @@ function Case-Steps([string]$RunnerPath, [string]$WatcherPath) {
    }
    # Steady-state cost at the PRODUCTION cadence (10 s polls, 5-minute heartbeat): CPU sampled 20 s
    # after start, once pwsh has loaded, and again a minute later.
   +# Every test line and every evaluator stage is recorded with its own time, at the runner's 0.06-second
   +# resolution; tests are recorded, not printed; a `TIME:` line keeps the duration it states.
   +function Case-Tests([string]$RunnerPath, [string]$WatcherPath) {
   +    $log = New-Name '.log'; $csv = New-Name '.csv'; $out = New-Name '.out'
   +    # A failed test straight after a passing one: its time is the time since that line (about 0), not since
   +    # the last RESULT four seconds earlier, which is what it got while `FAIL` was judged a result first.
   +    $r = Start-Runner $RunnerPath $log "Write-Output 'PASS: pwsh -NoProfile -File scripts/fake_a.ps1'; Start-Sleep -Seconds 4; Write-Output 'PASS t1 the first test'; Write-Output 'FAIL t2 the second test :: evidence'; Write-Output 'ok 3 - a tap test'; Write-Output 'not ok 4 - a failing tap test'; Write-Output 'not ok 5 - pending # TODO later'; Write-Output 'TIME: STAGES Gate setup=0.60s repo-guard=12.00s other=0.30s'; Write-Output 'TIME: Gate 00:00:13'; exit 0"
   +    $w = Start-Watcher $WatcherPath $log 'tests' 5 $csv $out; $done = Wait-Exit $w 60; [void](Wait-Exit $r 10)
   +    $o = @(Get-Content -LiteralPath $out); $rows = @(Import-Csv -LiteralPath $csv); $row = { param($s) @($rows | Where-Object { $_.step -eq $s })[0] }
   +    $inv = [Globalization.CultureInfo]::InvariantCulture; $d = { param($s) $x = & $row $s; if ($x) { [double]::Parse($x.delta_min, $inv) } else { -1 } }
   +    $stamps = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^\[\+\s*\d+\.\d{3} min\] ' }).Count
   +    $fail2 = & $d 'FAIL t2 the second test :: evidence'; $fail4 = & $d 'not ok 4 - a failing tap test'
   +    $ok = $done -and $stamps -ge 9 -and (& $d 'PASS t1 the first test') -ge 0.06 -and $fail2 -ge 0 -and $fail2 -lt 0.03 -and (& $d 'ok 3 - a tap test') -ge 0 -and $fail4 -ge 0 -and $fail4 -lt 0.03 -and (& $d 'not ok 5 - pending # TODO later') -ge 0 -and
   +          [Math]::Abs((& $d 'STAGE Gate repo-guard') - 0.2) -lt 0.001 -and [Math]::Abs((& $d 'STAGE Gate setup') - 0.01) -lt 0.001 -and [Math]::Abs((& $d 'TIME: Gate 00:00:13') - 13 / 60) -lt 0.001 -and
   +          -not @($o -match 'PASS t1|ok 3 - a tap|not ok 5').Count -and @($o -match 'FAIL t2').Count -eq 1 -and @($o -match 'not ok 4 - a failing').Count -eq 1
   +    [pscustomobject]@{ Ok = $ok; Detail = "done=$done stamps=$stamps || $($o -join ' || ') || $(($rows | ForEach-Object { "$($_.step)=$($_.delta_min)" }) -join ' | ')" }
   +}
   +# -Brief prints what needs attention and a progress line; the history still receives everything.
   +function Case-Quiet([string]$RunnerPath, [string]$WatcherPath) {
   +    $log = New-Name '.log'; $csv = New-Name '.csv'; $out = New-Name '.out'
   +    $r = Start-Runner $RunnerPath $log "Write-Output 'PASS: pwsh -NoProfile -File scripts/fake_a.ps1'; Write-Output 'PASS t1 quiet'; Start-Sleep -Seconds 2; Write-Output 'FAILED: pwsh -NoProfile -File scripts/fake_b.ps1 (exit 1)'; exit 1"
   +    $w = Start-Pwsh ('-File {0} -Log {1} -Run quiet -QuietMinutes 5 -PollSeconds 1 -Csv {2} -Brief -ProgressMinutes 0.01' -f (Q $WatcherPath), (Q $log), (Q $csv)) $out
   +    $done = Wait-Exit $w 60; [void](Wait-Exit $r 10); $o = @(Get-Content -LiteralPath $out); $rows = @(Import-Csv -LiteralPath $csv)
   +    $ok = $done -and $w.ExitCode -eq 1 -and -not @($o -match '\] PASS: |PASS t1').Count -and @($o -match '\] FAILED: ').Count -eq 1 -and @($o -match '\] END exit=1').Count -eq 1 -and @($o -match '^progress: [\d.]+ min - \d+ tests and \d+ results so far').Count -ge 1 -and
   +          @($rows | Where-Object { $_.step -like 'PASS: *' -or $_.step -eq 'PASS t1 quiet' }).Count -eq 2
   +    [pscustomobject]@{ Ok = $ok; Detail = "done=$done exit=$(if ($done) { $w.ExitCode }) rows=$($rows.Count) || $($o -join ' || ')" }
   +}
   +# A credential a step prints never reaches the watcher's output or the history. The runner's log, which the
   +# history names as evidence, is the raw output and keeps it: the redaction claim stops at the watcher.
   +function Case-RedactRun([string]$RunnerPath, [string]$WatcherPath) {
   +    $log = New-Name '.log'; $csv = New-Name '.csv'; $out = New-Name '.out'
   +    $r = Start-Runner $RunnerPath $log "Write-Output 'FAILED: pwsh -NoProfile -File scripts/fake_c.ps1 token=SECRETVALUE42 (exit 1)'; exit 1"
   +    $w = Start-Watcher $WatcherPath $log 'redact' 5 $csv $out; $done = Wait-Exit $w 60; [void](Wait-Exit $r 10)
   +    $o = (Get-Content -Raw -LiteralPath $out); $c = (Get-Content -Raw -LiteralPath $csv); $raw = (Get-Content -Raw -LiteralPath $log)
   +    [pscustomobject]@{ Ok = ($done -and $o -match 'token=<redacted>' -and "$o$c" -notmatch 'SECRETVALUE42' -and $c -match 'log=' -and $raw -match 'token=SECRETVALUE42'); Detail = "done=$done raw-log-keeps-it=$($raw -match 'SECRETVALUE42') || $o || $c" }
   +}
    function Case-Overhead([string]$RunnerPath, [string]$WatcherPath) {
        $log = New-Name '.log'
        $r = Start-Runner $RunnerPath $log 'Start-Sleep -Seconds 95'
   @@ -200,6 +339,17 @@ try {
        $c = Case-Gone $Runner $Watcher;  Check 'W6 a runner killed mid-run is reported as RUNNER GONE and the watcher exits 1' $c.Ok $c.Detail
        $c = Case-NeverStarted $Watcher;  Check 'W7 a runner that never starts is reported, not waited on silently' $c.Ok $c.Detail
        $c = Case-Rearm $Runner $Watcher $steps; Check 'W8 a watcher re-armed on a finished failed run exits 1 and adds no duplicate rows; a later successful run exits 0 and compares with the previous one and both conditions' $c.Ok $c.Detail
   +    $c = Case-Eta $Watcher;          Check 'W9 an ETA is the median of what comparable successful runs still had to do, with its range; a new step falls back to run totals; one run gives none; an ended run says so' $c.Ok $c.Detail
   +    $c = Case-Findings $Watcher;     Check 'W10 findings: a recurring failure is [confirmed]; a repeated command, a slow step, an absent step and a slow run are [hypothesis]; each once' $c.Ok $c.Detail
   +    $c = Case-Report $Watcher;       Check 'W11 the report ranks failures by rate per run of their own name and says where the time goes' $c.Ok $c.Detail
   +    $c = Case-Redact $Watcher;       Check 'W12 credentials are redacted by shape and by key; prose that names a secret is kept' $c.Ok $c.Detail
   +    $c = Case-RedactRun $Runner $Watcher; Check 'W13 a credential a step prints reaches neither the watcher''s output nor the history; each row names its log, which keeps the raw line unredacted' $c.Ok $c.Detail
   +    $c = Case-Limit $Watcher;        Check 'W14 one append past the bound leaves the history within it: header, then the newest whole rows' $c.Ok $c.Detail
   +    $c = Case-Tests $Runner $Watcher; Check 'W15 every test line, failed ones included, and every evaluator stage is recorded with its own time at 0.06 s resolution; only failed tests are printed; a TIME line keeps its stated duration' $c.Ok $c.Detail
   +    $c = Case-Quiet $Runner $Watcher; Check 'W16 -Brief prints failures, the end and progress, and still records every line' $c.Ok $c.Detail
   +    $c = Case-Classify $Watcher;     Check 'W17 FAIL and TAP not ok are tests, ranked by time and by failure rate; a TODO or SKIP not ok is not a failure' $c.Ok $c.Detail
   +    $c = Case-ConcurrentAll $Watcher $Evaluator; Check 'W18 six concurrent writers (three evaluator, three watcher): every row once and whole; past the bound, within it, whole, newest rows kept' $c.Ok $c.Detail
   +    $c = Case-SharedWriter $Watcher $Evaluator; Check 'W19 the evaluator and the watcher share one write path, text for text' $c.Ok $c.Detail
        $c = Case-CiBranch $Ci;          Check 'C1 the candidate and main runs on one SHA are judged separately, each against its own contract' $c.Ok $c.Detail
        $c = Case-CiMissing $Ci;         Check 'C2 an expected check that never ran is missing (another event never stands in for it); an unexpected run is reported, not required' $c.Ok $c.Detail
        $c = Case-CiContract $Ci;        Check 'C3 the contract at real SHAs: ORVION Acceptance on the candidate only; Migration CI only where a migration path changed' $c.Ok $c.Detail
   @@ -237,7 +387,24 @@ try {
            @{ Name = 'M11 PASS lines read as evidence';          File = $Ci;      Find = "`$message -cnotmatch '^PASS\b' -and "; Replace = ''; Case = { param($p) Case-CiEvidence $p } },
            @{ Name = 'M12 contract derived for the wrong branch'; File = $Ci;     Find = '$expected = @(Workflow-Expectations $changed $Branch)'; Replace = '$expected = @(Workflow-Expectations $changed ''orvion-preflight'')'; Case = { param($p) Case-CiContract $p } },
            @{ Name = 'M13 a missing check never reported';       File = $Ci;      Find = 'Missing    = @($Expected | Where-Object { $present -notcontains $_ })'; Replace = 'Missing    = @()'; Case = { param($p) Case-CiMissing $p } },
   -        @{ Name = 'M14 another event stands in for a push';   File = $Ci;      Find = " -and `$_.event -eq 'push'"; Replace = ''; Case = { param($p) Case-CiMissing $p } }
   +        @{ Name = 'M14 another event stands in for a push';   File = $Ci;      Find = " -and `$_.event -eq 'push'"; Replace = ''; Case = { param($p) Case-CiMissing $p } },
   +        @{ Name = 'M17 an ETA from a single run';             File = $Watcher; Find = 'if ($left.Count -lt 2)'; Replace = 'if ($left.Count -lt 1)'; Case = { param($p) Case-Eta $p } },
   +        @{ Name = 'M18 a recurring failure not recognised';   File = $Watcher; Find = 'if ($prior.Count) {'; Replace = 'if ($false) {'; Case = { param($p) Case-Findings $p } },
   +        @{ Name = 'M19 findings repeated';                    File = $Watcher; Find = '@($found | Where-Object { $State.Said.Add($_) })'; Replace = '@($found)'; Case = { param($p) Case-Findings $p } },
   +        @{ Name = 'M20 failures ranked by count, not rate';   File = $Watcher; Find = 'Rate = $k.Count / [Math]::Max(1, $h.Count)'; Replace = 'Rate = $k.Count'; Case = { param($p) Case-Report $p } },
   +        @{ Name = 'M21 redaction disabled';                   File = $Watcher; Find = 'function Hide-Secret([string]$Text) {'; Replace = 'function Hide-Secret([string]$Text) { return $Text'; Case = { param($p) Case-Redact $p } },
   +        @{ Name = 'M22 a step''s line not redacted';           File = $Watcher; Find = '$body = Hide-Secret $m.Groups[''body''].Value'; Replace = '$body = $m.Groups[''body''].Value'; Case = { param($p) Case-RedactRun $Runner $p } },
   +        @{ Name = 'M23 the history never bounded';            File = $Watcher; Find = 'if ([IO.FileInfo]::new($Path).Length -le $MaxBytes) { return }'; Replace = 'return'; Case = { param($p) Case-Limit $p } },
   +        @{ Name = 'M24 test lines not recorded';              File = $Watcher; Find = 'if (Test-TestLine $body) {'; Replace = 'if ($false) {'; Case = { param($p) Case-Tests $Runner $p } },
   +        @{ Name = 'M29 a failed test judged a result first';   File = $Watcher; Find = 'if (Test-TestLine $body) {'; Replace = 'if ((Test-TestLine $body) -and -not (Test-ResultLine $body)) {'; Case = { param($p) Case-Tests $Runner $p } },
   +        @{ Name = 'M30 the history reads a failed test as a result'; File = $Watcher; Find = "elseif (Test-TestLine `$Step) { 'test' }"; Replace = "elseif ((Test-TestLine `$Step) -and -not (Test-ResultLine `$Step)) { 'test' }"; Case = { param($p) Case-Classify $p } },
   +        @{ Name = 'M31 a TODO not ok counted as a failure';    File = $Watcher; Find = '(?!.*#\s*(?i:todo|skip)\b)'; Replace = ''; Case = { param($p) Case-Classify $p } },
   +        @{ Name = 'M32 test times ranked from successful runs only'; File = $Watcher; Find = '$per = @{}; foreach ($r in $h) {'; Replace = '$per = @{}; foreach ($r in $ok) {'; Case = { param($p) Case-Classify $p } },
   +        @{ Name = 'M33 writers not serialised';               File = $Watcher; Find = "'Global\ORVION-timings-' + `$id.Substring(0, 32)"; Replace = "'Global\ORVION-timings-' + [guid]::NewGuid().ToString('N')"; Case = { param($p) Case-ConcurrentAll $p $Evaluator } },
   +        @{ Name = 'M25 -Brief prints everything';             File = $Watcher; Find = 'if (-not $Brief -or $body -cmatch $script:AttentionRx)'; Replace = 'if ($true)'; Case = { param($p) Case-Quiet $Runner $p } },
   +        @{ Name = 'M26 a TIME line''s stated duration ignored'; File = $Watcher; Find = '$(if ($null -ne $stated -and $step -like ''TIME: *'') { $stated } else { $delta })'; Replace = '$delta'; Case = { param($p) Case-Tests $Runner $p } },
   +        @{ Name = 'M27 stages not split';                     File = $Watcher; Find = '$stages = @(Split-Stages $body)'; Replace = '$stages = @()'; Case = { param($p) Case-Tests $Runner $p } },
   +        @{ Name = 'M28 the runner stamps a tenth of a minute'; File = $Runner;  Find = "ToString('0.000',"; Replace = "ToString('0.0',"; Case = { param($p) Case-Tests $p $Watcher } }
        )
        foreach ($m in $mutants) {
            $source = [IO.File]::ReadAllText($m.File); $mutated = $source.Replace($m.Find, $m.Replace)
   ```

2. **Check** whether the Runtime Checkpoint reads `Resume Step: DONE`. If so, record Already Applied. Otherwise:
   - confirm that `git diff --name-only` against the Approve commit lists only paths in this contract's Write Scope, and stop and report any other path;
   - synchronize the Execution Log, set the Runtime Checkpoint to `DONE`, and commit;
   - then run `pwsh -NoProfile -File scripts/run_timed.ps1 -Log <log> -Command "pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish"` and, at the same time, from a second shell or the agent's background monitor (the runner blocks until the run ends), `pwsh -NoProfile -File scripts/watch_run.ps1 -Log <log> -Run finish-control -Brief`.

## Acceptance Criteria

- [x] `CR_LIFECYCLE.md` is its `246284d` text with only the Step 1 patch applied. `check: blob CR_LIFECYCLE.md 7ee05f5a3c18636b21647aa9afc702b1893f350d`
- [x] `ENGINEERING_METHOD.md` is its `246284d` text with only the Step 1 patch applied. `check: blob ENGINEERING_METHOD.md 6a5fdca1160d353647a01f0219db99d459a7f201`
- [x] `AGENTS.md` is its `246284d` text with only the Step 1 patch applied. `check: blob AGENTS.md b2412d15cd6fcf710055114fe734ba69178f35cc`
- [x] `scripts/check_agent_continuity.ps1` is its `246284d` text with only the Step 1 patch applied. `check: blob scripts/check_agent_continuity.ps1 4d67468f479076f28e95f223070788016281a59c`
- [x] `scripts/test_agent_continuity.ps1` is its `246284d` text with only the Step 1 patch applied. `check: blob scripts/test_agent_continuity.ps1 3e554c25f5d3ee9f015615f1be143817ca4ce0ca`
- [x] `scripts/run_timed.ps1` is its `246284d` text with only the Step 1 patch applied. `check: blob scripts/run_timed.ps1 722ca31e5cd999d7fa968a2fd23ce943cebc37bc`
- [x] `scripts/watch_run.ps1` is its `246284d` text with only the Step 1 patch applied. `check: blob scripts/watch_run.ps1 e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b`
- [x] `scripts/watch_selftest.ps1` is its `246284d` text with only the Step 1 patch applied. `check: blob scripts/watch_selftest.ps1 144828ebdc82fa1812ca1971834b277bc9b94b31`
- [x] The publication, promotion and CI surfaces are unchanged. `check: blob scripts/publish_candidate.ps1 f55e7a165744fd0207b5da5733ae5e047f85f2a1` `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79` `check: blob .githooks/pre-commit 40e6df021b0a9959462c51aab30981b7a82af860` `check: blob .github/workflows/agent-control.yml 48e90c2b23c4c56f49b1117e4598d63bc2fc267e` `check: blob .github/workflows/orvion-acceptance.yml b242e4c7401258404c5d43bffb49c3f53f42467e`

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.
Leave this section's bracketed instructions in place in an unused template; remove them
only in a CR that has at least one real entry.]

### 2026-10-15 — Claude

Outcome: Implemented. The Runtime Checkpoint is DONE; `-Finish` follows, started through `scripts/run_timed.ps1` with `scripts/watch_run.ps1` attached concurrently.

Step results:
- **Step 1: Applied.** All eight files had their base blob at `246284d`. The patch was taken from this contract's committed code block (each line without its first three characters), applied with `git apply`, and every file now has its target blob: `CR_LIFECYCLE.md` `7ee05f5a3c18636b21647aa9afc702b1893f350d`, `ENGINEERING_METHOD.md` `6a5fdca1160d353647a01f0219db99d459a7f201`, `AGENTS.md` `b2412d15cd6fcf710055114fe734ba69178f35cc`, `scripts/check_agent_continuity.ps1` `4d67468f479076f28e95f223070788016281a59c`, `scripts/test_agent_continuity.ps1` `3e554c25f5d3ee9f015615f1be143817ca4ce0ca`, `scripts/run_timed.ps1` `722ca31e5cd999d7fa968a2fd23ce943cebc37bc`, `scripts/watch_run.ps1` `e327c2ff9b8c7acf8851f7153c1e1acb066d4e9b`, `scripts/watch_selftest.ps1` `144828ebdc82fa1812ca1971834b277bc9b94b31`.
- **Step 2: Applied.** `git diff --name-only af2d218` (the Approve commit) listed only Write Scope paths: AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md, changes/SPEC-283-every-run-is-timed-and-watched.md, scripts/check_agent_continuity.ps1, scripts/run_timed.ps1, scripts/test_agent_continuity.ps1, scripts/watch_run.ps1, scripts/watch_selftest.ps1. The Runtime Checkpoint is DONE.

**Approval prerequisites, re-verified before the first commit.** The approved Draft's bytes were recomputed from the owner-review copy: blob `dd54eb29a8aaf86880d3392322f13577dbccd143`, SHA-256 `eb69e0f5ce5dc61b5ca1a047e41a177c5f6e8c783b8e84939d59cfe99e2cd6ba`, 139609 bytes, 0 CR, equal to the approved identity, and the committed copy has the same blob. After a fetch HEAD and `origin/orvion-preflight` were `246284d` (`origin/main` `349825e`; `SPEC-282` awaits the owner's promotion), the tree was clean, no index lock existed, and `SPEC-283` appeared in no tracked text. The Approve Gate reported `APPROVAL_EVIDENCE: PASS`. No Primary or Secondary contact was made.

Commits: Draft `7d35953`, Approve `af2d218`, Begin `f1d8cdf`, and this Implement commit.
## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

### 2026-10-15 — Claude (independent review)

Verdict: Confirmed Complete

Findings: re-checked against the live repository at `bcbcca8`, not against the Execution Log.
- **R1.** `git diff --name-only 246284d bcbcca8` lists only Write Scope paths: the eight Step 1 files, this contract, `_ORVION_CANONICAL/manifest.md` and `ai-map.json`. `repository-index.md` did not change.
- **R2.** Since the Draft commit `7d35953`, this contract changed only in Status, the Runtime Checkpoint and the Execution Log, and the pre-commit Gate reported READY at Draft, Approve, Begin and Implement; the Approve Gate reported `APPROVAL_EVIDENCE: PASS`.
- **R3.** All 13 criterion checks hold in the working tree and at `HEAD`: the eight files have their target blobs and the publication, promotion, hook and CI surfaces keep theirs. Nothing changed in `scripts/publish_candidate.ps1`, `scripts/promote_main.ps1`, `.githooks/`, `.github/`, `supabase/`, `GOVERNANCE.md` or `CODING_STANDARDS.md`.
- **R4.** `-Finish` at `bcbcca8`, started through `scripts/run_timed.ps1` with `scripts/watch_run.ps1 -Brief` attached 2 s after it started, nothing else running: CONTROL (the five control suites, 38.1 min), REPOSITORY (consistency and `git diff --check`) and the Additional Verification `scripts/watch_selftest.ps1` (7.0 min) PASS; `LOCAL_CERTIFY: READY` in 45.5 min. The run printed its stages, each command's and profile's time and `TIME: Finish 00:45:31`, and the watcher recorded it.
- **R5.** No Primary or Secondary contact, no push to `main`, and no GitHub setting, ruleset or credential change.

Defect found by this run, carried forward, not fixed here: the watcher's `-Brief` progress line understates elapsed time in its estimate. It looks up the step of the last result but subtracts only the time since the line just read, so after a long silence the estimate is a whole run. Evidence, this `-Finish`: the last result before the first progress line was `ORVION: READY` at 0.3 min; the three comparable runs had 30.9, 33.5 and 36.6 min left after it; the heartbeats, which subtract the time since then, fell 28, 23, 18, 13, 8; the progress line at 29.2 min said about 33 min left (range 31 to 37). The run ended at 45.5 min. The heartbeat's shortfall is not this defect: this run added the 7.0-minute watcher self-test that two of the three earlier runs lacked, and the estimate was labelled a low sample. No verdict, criterion or recorded time depends on an estimate, and `scripts/watch_run.ps1` is fixed by criterion 7, so the correction belongs to a later contract: keep the time of the last result's line and subtract the time since it in both the progress line and the heartbeat, with a self-test case in which a progress line after a silence agrees with the heartbeat.

Review Gate: every step matched its text and was Applied. Nothing was written outside Write Scope, and no section was restructured. Every Acceptance Criterion is true. No step needed a guess. `Supersedes / Depends On` names no file to update. The tree is clean.

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

- **Owner direction (2026-10-15).** The owner approved making this contract, required `-Finish` never to be started directly by any agent, extended it to every gate, test, mode and profile, then confirmed the full objective: full-cycle timing, live quality observation and evidence-based improvement feedback, preserving D2 and its evidence. On the first Draft the owner required the three review passes recorded in Draft review and the corrections A1 to A4.
- **Research, 2026-10-15.** Microsoft's `about_Try_Catch_Finally` (a `finally` runs on `exit` and on CTRL+C, whose output is then not displayed); GitHub's token formats (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_`); CI duration practice (successful runs only, median and spread, small samples unreliable: Jenkins, TeamCity, Metabase); alerting practice (actionable signals, deduplicated).
- **Known limits.** A run interrupted with CTRL+C is recorded but may not print its `TIME:` line. A test's time is the time since the line before it, so setup printed between tests is charged to the next test. The history is local to one machine. A `[hypothesis]` finding needs a person's judgement. CI's timings stay on GitHub. The runner's log is raw output and is not redacted; redaction by pattern covers known credential shapes only. Another local account holding the history's mutex can delay its writes, never a verdict. The history's replacement is one move, not a documented atomic replace.
- **Not this contract's work:** CR B, CR C, CTRL-19, DRAFT-REMOTE-1, the Improvement Loop, and Batch 6.
