# Change Request — SPEC-276

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make every onboarding route a newcomer meets lead to its real authority: README reaches workstation setup, Boot's upstream refusal names the reading route, `AGENTS.md` §4 gives the execution plan's full path, and `WORKSTATION.md` states only what its scripts do.

## Business Reason

The owner's 2026-10-13 directive asks that a new human or agent find ORVION's purpose, live state, authorities and workstation setup without chat history. An independent cloud review at `13fb8fc` proposed four routing gaps; each was re-measured here at `0184947`.

- **README never reaches workstation setup (reproduced).** A fresh read-only agent was asked how to get a brand-new Windows laptop working on ORVION, starting from README. It reported that "README.md never mentions how to set up a new machine" and that the Boot command it gives needs PowerShell 7, which a new machine lacks. It reached `bootstrap.ps1` only by searching `scripts/check_agent_continuity.ps1` for "bootstrap" (Notes). The rule that README "does **not** reference the environment" (`GOVERNANCE.md` §2, 32ede76, 2026-07-17) moved setup *content* out of README so it stays a router. One routing row keeps that purpose; the rule's wording is narrowed to say exactly that.
- **Boot's upstream refusal gives the wrong next step (reproduced).** On a branch with no upstream, Boot prints `CODE: GIT_UPSTREAM_MISSING` and then `NEXT: … repair within Write Scope`. A cloud agent always starts on such a branch, and only wants to read. Refusing to guess an upstream is correct and is kept. The refusal now says that reading needs no upstream and names the `AGENTS.md` §4 route, where the decision is made.
- **`AGENTS.md` §4 names `MASTER_EXECUTION_PLAN.md` without its directory (verified).** §4 is the route used when Boot cannot run, so its table must be usable without a search; the file is `reports/master/MASTER_EXECUTION_PLAN.md`.
- **`WORKSTATION.md` states four things its scripts do not do (verified by reading them).**
  - "`doctor.ps1` … warning when local commits are not yet pushed": `doctor.ps1` has no such check; the maintenance menu's header shows it.
  - "or `doctor.ps1` (verify)" omits the `.workstation/` directory.
  - "The menu's **Decommission** option" never says how to open the menu; `workstation.cmd` runs `prepare.ps1`, not the menu.
  - "`prepare.ps1` registers an MCP only when its required env var is present", with "the Supabase MCP connection string" as the example: `supabase-primary` authenticates by OAuth, and `prepare.ps1` registers Codex's `github` server whether or not `GITHUB_PAT_TOKEN` is set.

## Risks

- **README is a boot surface.** A row that restated setup would create a second authority. The row only routes, and Checks 20 to 22 (one start instruction, no competing start route, pointer integrity) stay clean in the prototype.
- **A governance sentence changes.** Only the README clause of `GOVERNANCE.md` §2's workstation row changes, from "does not reference" to "routes to `WORKSTATION.md` in one row and restates nothing". The separation it protects is unchanged.
- **The Gate's refusal text changes.** `CODE: GIT_UPSTREAM_MISSING` is unchanged. The message gains a subject after its first colon, which `Block` already prints as `SUBJECT:`. No script compares the whole message; assertion 36 matched only the code, and now also requires the subject.
- **Untouched.** No workstation script, database, Primary, CI workflow, ruleset or product behaviour changes. Workstation script defects found in the same investigation are a separate contract, because they need the WORKSTATION profile, which cannot pass while Docker Desktop is down.

## Supersedes / Depends On

None

## Write Scope

- `README.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `WORKSTATION.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-275-the-engineering-method-and-its-tools-do-what-they-say.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `CLAUDE.md`
- `llms.txt`
- `PROTOCOL.md`
- `global-rules.md`
- `bootstrap.ps1`
- `workstation.cmd`
- `.workstation/manifest.md`
- `.workstation/menu.ps1`
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.workstation/update.ps1`
- `scripts/verify_workstation_idempotence.ps1`
- `scripts/check_repository_consistency.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `.mcp.json`

## Required Reading

- `README.md`
- `AGENTS.md` §§3–4
- `GOVERNANCE.md` §2
- `WORKSTATION.md`
- `.workstation/doctor.ps1`
- `.workstation/menu.ps1`
- `.workstation/prepare.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 1

## Required Capabilities

- github

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| README's authority table gains one row routing workstation setup, verification and recovery to `WORKSTATION.md` | Every newcomer, human or agent, and every client told "Start at README.md" | WRITE | One row is added; the "Start here" text, the single start instruction and every other row are unchanged. Fresh agents were observed before and after (Notes). |
| The same row | Consistency checks on boot surfaces: one start instruction, no competing `Start at` route, pointers into the boot chain | VERIFY | Prototype: `REPOSITORY CONSISTENCY: CLEAN`. The row contains no `Start at` instruction. |
| `GOVERNANCE.md` §2's workstation row says README routes to `WORKSTATION.md` in one row and restates nothing about the environment | The repository/environment separation of 2026-07-17 (32ede76); `WORKSTATION.md`'s one-authority note | WRITE | The separation's purpose, README as a router without setup content, is kept and stated. `WORKSTATION.md` keeps saying it is separate from README. |
| Boot's `GIT_UPSTREAM_MISSING` refusal carries a subject naming the reading route | Every agent on a branch without upstream; `Block`; assertion 36 of `scripts/test_agent_continuity.ps1` | WRITE | Prototype on a fresh branch: `CODE: GIT_UPSTREAM_MISSING` unchanged, `SUBJECT:` added, exit 1. The refusal still fires before anything else and still guesses nothing. `Certification-Paths`' refusal under `-Finish` is unchanged. |
| `AGENTS.md` §4's registry row gives `reports/master/MASTER_EXECUTION_PLAN.md` | Agents using the §4 recovery route; Check 26 section pointers | WRITE | Only the path is completed; the row's need, the registry name and the `readiness_population.ps1 -Registry` pointer are unchanged. |
| `WORKSTATION.md`'s four corrected statements, and how to open the maintenance menu | Humans preparing, verifying, maintaining or retiring a workstation | WRITE | Each statement now matches the scripts as read at `0184947`. The bootstrap command, the trust model and the one-click flow are unchanged. |
| Manifest active pointer | Boot, Check 7, `scripts/generate-ai-map.ps1` | WRITE | `ai-map.json` and `repository-index.md` are in Write Scope. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Working tree is clean and the branch is not behind its upstream | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| The six implementation files equal their pinned target hashes and no other tracked path changed | BEFORE_COMPLETION | 1 | 2 | 3 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: Boot's existing `GIT_UPSTREAM_MISSING` refusal and `Block`'s existing `SUBJECT:` line are reused, and so is assertion 36 of `scripts/test_agent_continuity.ps1`. No check, gate, mode or file is added.

Added Property: Boot's refusal on a branch without upstream names the route that needs none.

Causal Negative: Reproduced 2026-10-13 on a fresh branch of a disposable clone at `0184947`. The unchanged Boot printed `CODE: GIT_UPSTREAM_MISSING`, `EVIDENCE: GIT_UPSTREAM_MISSING` and `NEXT: … repair within Write Scope`, with no `SUBJECT:` line, so the strengthened assertion 36 fails on it.

Positive Test Design: Every other assertion of the control suite keeps its verdict, and Boot on a tracking branch is unchanged (`ORVION: READY`).

Negative Test Design: Assertion 36 removes the fixture's upstream and requires a non-zero exit, `CODE: GIT_UPSTREAM_MISSING` and a `SUBJECT:` naming `AGENTS.md section 4`.

Non-Empty Population Obligation: Not applicable; no population-based check is added or changed.

Mutation Obligation: None. The changed predicate is the text of a refusal, and assertion 36 checks that text directly.

Post-Implementation Proof Obligation: The certified `-Finish` runs CONTROL (the full control suite and the four guard suites) and REPOSITORY. After `Complete`:
- `publish_candidate.ps1` must admit `origin/main..HEAD`;
- ORVION Acceptance must pass on the candidate;
- `-Certify` must report READY on `main`.

## Implementation Steps

1. For each file below, read its blob with `git hash-object --path=<path> <path>`. If it equals the `to` hash, record Already Applied. If it equals the `from` hash, replace the file with the reviewed content summarised in Notes, so that its blob becomes exactly the `to` hash. Any other value means stop and report; do not guess.
   - `README.md`: from `58becec83a524569466ba91a186c1321c1bed20a` to `9f15270f25194e4ed0bb08613ca185a16b05ea2d`
   - `AGENTS.md`: from `328aac3fdfc407cfbd924b72c50cdf4e6e40fd16` to `1c4b85d4de197e3e7d2a574561c59cec34626f0b`
   - `GOVERNANCE.md`: from `398d40e2f84aa155167cfcabdc7afc73561c738d` to `f0e245b09c5b4e7beff2e80b61216e3eb3a5c1e4`
   - `WORKSTATION.md`: from `ab83a4f358d386832cfbad52e7eab3b564428b48` to `98c489bc300984bc52c6893ac66c3c42bab98d2c`
   - `scripts/check_agent_continuity.ps1`: from `64d5d53887d61da97b87d451e3ffe5ed93abb81c` to `20368053631981aed041afe92e3ce74b1eb9c285`
   - `scripts/test_agent_continuity.ps1`: from `013c3f9a3a89ebba92140c86b8ab825724804940` to `e9499704a646bd06d733fb0abb850f91d23af180`
2. Check whether `git diff --name-only` against the approval commit lists only the six files above plus this contract. If so, record Already Applied. Otherwise stop and report any other path. Nothing else is edited in this step; the lifecycle commits own the manifest, `ai-map.json` and `repository-index.md`.
3. Check whether the Runtime Checkpoint already reads `Resume Step: DONE`. If so, record Already Applied. Otherwise synchronize the Execution Log and the Runtime Checkpoint to `DONE`, and commit the implementation and checkpoint together. Then run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` normally; no container, Docker or workstation state is changed for it. If a test fails, preserve its exit code and evidence, and follow bounded recovery without weakening any assertion.

## Acceptance Criteria

- [x] Each of the six Step 1 files has exactly its `to` blob.
- [x] README's authority table has a row routing workstation setup, verification and recovery to `WORKSTATION.md`, and README still has exactly one start instruction.
- [x] `GOVERNANCE.md` §2's workstation row says README routes to `WORKSTATION.md` in one row and restates nothing about the environment.
- [x] Boot's refusal on a branch without upstream reads `CODE: GIT_UPSTREAM_MISSING` with a `SUBJECT:` naming `AGENTS.md section 4`, and assertion 36 requires both.
- [x] `AGENTS.md` §4 names `reports/master/MASTER_EXECUTION_PLAN.md`.
- [x] `WORKSTATION.md` no longer says the doctor warns about unpushed commits or that `prepare.ps1` needs an MCP secret, gives `./.workstation/doctor.ps1` its directory, and says how to open the maintenance menu.
- [x] `changes/SPEC-275-…` is byte-identical to `0184947`.
- [x] The tracked implementation diff touches only this contract's Write Scope.

## Execution Log

### 2026-10-13 — Claude

Outcome: Implemented. The Runtime Checkpoint is DONE; `-Finish` follows.

Step results:
- **Step 1: Applied.** Each file read its `from` hash and was replaced with the reviewed pre-approval prototype, whose blob had been checked equal to the `to` hash before copying. `git hash-object --path` then read exactly the `to` hash for:
  - `README.md`
  - `AGENTS.md`
  - `GOVERNANCE.md`
  - `WORKSTATION.md`
  - `scripts/check_agent_continuity.ps1`
  - `scripts/test_agent_continuity.ps1`
- **Step 2: Applied.** `git diff --name-only` listed exactly those six files plus this contract.
- **Step 3: Applied.** The Runtime Checkpoint is synchronized to `DONE` and committed with the implementation. `-Finish` runs next, normally. It changes no container, Docker or workstation state.

**Pre-approval rehearsal (the Notes' measurement).** The lifecycle of this exact Draft (blob `05a76dfa`) was rehearsed in a disposable clone at `0184947` with its push URL disabled:
- Draft, Approve (`APPROVAL_EVIDENCE: PASS`) and Begin;
- Implement;
- `-Finish`: `LOCAL_CERTIFY: READY` in 30.8 min, with the full control suite, the four guard suites, repository consistency and `git diff --check` all passing;
- Complete;
- the range Gate over `origin/main..HEAD`: READY. Its net diff was exactly the six files plus this contract.

**Candidate-text cold start (promised in Notes).** A fresh read-only agent got the same neutral new-laptop prompt as the baseline agent. It read the repository at `0184947`, with the candidate README text given in place of `README.md`.
- **Route.** It opened `WORKSTATION.md` first, because README routes setup there, then `bootstrap.ps1`. It used 4 tool calls in 26 s.
- **Answer.** It returned to README's Boot command for engineering work, and named no second start route. It also again predicted the execution-policy failure of the bootstrap hand-off, which is repaired by the workstation contract.
- **More evidence for this contract.** Reading the not-yet-corrected `WORKSTATION.md`, it followed the Secrets paragraph that this contract corrects ("set the Supabase MCP connection string" before setup).
- **Harness note.** Three earlier candidate runs read a copy in the session scratchpad. They stalled in the agent harness and were stopped without a result. Both baseline runs, which read the repository's own path, finished in under a minute. So the stall belongs to the harness, not to the README.

### 2026-10-13 19:40 — Claude

Outcome: Blocked; recovery attempt 1 of 3 re-runs `-Finish`.

**The failure.** `-Finish` on `5b7cf9e` ended `MANDATORY_VERIFICATION_FAILED` on `scripts/test_agent_continuity.ps1`: 445 passed and 1 failed. The failure was assertion 160, "CONTROL: executing on main still records main". Inside that fixture's own `-Finish`, `git diff --check` exited 1 with `git: 'C:\Users\My Lab\scoop\apps\git\current\cmd\git.exe' is not a git command`, so git received its own path as its first argument.

**Diagnosis (attempt 1, immediate evidence).**
- The fixture and the command are untouched by this contract. Assertion 159, the same Finish path, passed just before it. The rehearsal of these exact six files passed all 446 assertions.
- `git` resolves to two applications on this machine: scoop's `apps\git\current\cmd\git.exe` and its shim `scoop\shims\git.exe`. Neither changed during the run: git is 2.54.0 from 2026-09-11, and the shim is from 2026-06-25.
- The identical child command, `pwsh -NoProfile -Command "git diff --check; exit $LASTEXITCODE"`, failed 0 times in 40 runs.

Classified as a one-off environmental failure with no code defect. No assertion is changed. `-Finish` is re-run once. If it recurs, attempt 2 investigates how the shim resolves in the child process.

## Verification Notes

### 2026-10-13 — Claude (independent review)

Verdict: Confirmed Complete

Findings: re-checked against the live repository at the implementation commits, not against the Execution Log's claims.
- **C1.** All six Step 1 files have exactly their `to` blobs at HEAD.
- **C2.** README has the workstation row, no `Start at` instruction, and its single-start-instruction sentence unchanged.
- **C3.** `GOVERNANCE.md` §2 carries the new README clause, and the old "does **not** reference" wording is gone.
- **C4.** `Git-State` throws `GIT_UPSTREAM_MISSING` with the reading-route subject, the `Certification-Paths` refusal is unchanged, and assertion 36 requires both code and subject.
- **C5.** `AGENTS.md` §4 names `reports/master/MASTER_EXECUTION_PLAN.md`.
- **C6.** `WORKSTATION.md` no longer claims the doctor warns about unpushed commits, or that `prepare.ps1` needs an MCP secret. It names `./.workstation/doctor.ps1` and says how to open the menu.
- **C7.** `changes/SPEC-275-…` is unchanged since `0184947`.
- **C8.** The net diff from `0184947` is the six files, this contract, and the lifecycle-owned manifest and `ai-map.json`.
- **C9.** Live Boot in a disposable clone on a branch without upstream printed `ORVION: BLOCKED`, `CODE: GIT_UPSTREAM_MISSING` and the new `SUBJECT:`, and exited 1. It still fails closed.
- **Certification.** `-Finish` at `4ed04f4`: `LOCAL_CERTIFY: READY` in 32.3 min (CONTROL, REPOSITORY). The first run's one failure is recorded in the Execution Log as recovery attempt 1. The re-run passed every assertion, assertion 160 included, with no assertion changed. The failure class did not recur, so no guard is added.

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

**Reviewed content (Step 1).**
- `README.md`: after the "Runtime mode / exact next action" row, the row `| Set up, verify or recover the Windows workstation that runs Boot (PowerShell 7, Git and the rest) | `WORKSTATION.md` |`.
- `GOVERNANCE.md` §2, workstation rebuild row: "README does **not** reference the environment" becomes "README routes to `WORKSTATION.md` in one row and restates nothing about the environment"; the parenthesis "(repository/environment separation, 2026-07-17)" is kept.
- `AGENTS.md` §4: `` `MASTER_EXECUTION_PLAN.md` `` becomes `` `reports/master/MASTER_EXECUTION_PLAN.md` ``.
- `scripts/check_agent_continuity.ps1` `Git-State`: `throw 'GIT_UPSTREAM_MISSING'` becomes `throw 'GIT_UPSTREAM_MISSING:this branch tracks no upstream and Boot will not guess one; reading needs none (AGENTS.md section 4 route)'`. The `Certification-Paths` refusal is unchanged.
- `scripts/test_agent_continuity.ps1`: assertion 36 becomes "local mode with missing upstream blocks and names the reading route", requiring `CODE: GIT_UPSTREAM_MISSING` and `SUBJECT: .*AGENTS\.md section 4`.
- `WORKSTATION.md`:
  - the design-assumption parenthesis says the maintenance menu's header shows commits not yet pushed;
  - the terminal bullet names `./.workstation/doctor.ps1`;
  - a new bullet says `pwsh -File .workstation/menu.ps1` opens the menu (prepare, verify, update, cleanup, decommission);
  - the Secrets paragraph says no MCP secret is committed or needed by `prepare.ps1`: remote servers authenticate by OAuth in each client, and Codex's `github` server reads `GITHUB_PAT_TOKEN`, whose value stays outside the repository (`.workstation/manifest.md §3`).

**Cold-start evidence (2026-10-13, fresh read-only agents, neutral prompts).**
- *New laptop, starting from README.* Unchanged text: the agent found no setup route in README and reached `bootstrap.ps1` by searching the Boot script for "bootstrap". It also inferred that Windows' default execution policy would stop `bootstrap.ps1`'s hand-off; that was then reproduced, and is repaired in the workstation contract, not here. The same prompt on the candidate text is recorded in the Execution Log, with the agent's route and answer.
- *Branch without upstream, find the next capability, no writes.* Unchanged text: the agent read `AGENTS.md` §4 and the manifest and found the right answer; it also listed the `SPEC-163` upstream-setting workaround and rejected it only because the prompt forbade writes. Candidate text: the agent cited the new subject ("reading needs none (AGENTS.md section 4 route)") as its reason and found the same answer. Both reached the right answer, so the refusal's new subject makes explicit what the stronger agent derived, rather than repairing an observed failure.

**Cloud-review findings not adopted (measured at `0184947`).**
- *`.workstation/manifest.md` versions (`^2.109.0` and others).* The column is headed "Live evidence 2026-09-10" and the manifest says observed versions "are evidence, not pins". `package.json` and `package-lock.json` own the pin (`supabase 2.120.0`). Nothing is misleading, so the history is kept.
- *Repeated package inventories.* The winget identities in `prepare.ps1`, `update.ps1` and the manifest agree today, and the extension and MCP lists are already derived from their authorities (Check 28). No drift, so no inventory framework.
- *Doctor is owner-specific.* `WORKSTATION.md` is the owner workstation's recovery entry, and the doctor's identity checks protect that workstation's push identity (`bootstrap.ps1`'s comment records the 403 and hang they prevent). No contributor profile is added.
- *`Last Completed` names SPEC-270.* The manifest defines the field as "the single most recent capability"; SPEC-271 to SPEC-275 are tooling and governance contracts, so it is correct.
- *`PROTOCOL.md`, `global-rules.md`.* Both are documented retired pointers, kept for discoverability, and `scripts/check_repository_consistency.ps1` reads them. Kept.
- *Bootstrap trust model.* The script comes over HTTPS from `main` of `PlatPlusHub/CRM`, which accepts only a commit that passed ORVION Acceptance (Ruleset 22950574, no bypass). It is short, and can be read with `irm <url>` before it is piped to `iex`. That fits a trusted owner workstation; pinning a hash would break "one command, always current" for no measured gain. The statement in `WORKSTATION.md` is accurate and kept.

**Pre-approval measurement.** The whole lifecycle of this exact Draft was rehearsed in a disposable clone with its push URL disabled: Draft, Approve, Begin, Implement, `-Finish` (CONTROL and REPOSITORY), Complete, and the range Gate over `origin/main..HEAD`. Its results are given at the approval boundary and recorded in the Execution Log.
