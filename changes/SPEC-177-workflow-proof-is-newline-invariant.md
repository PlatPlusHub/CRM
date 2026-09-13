# Change Request — SPEC-177

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make Agent Control's workflow structural proof invariant to LF versus CRLF working-tree representation, while preserving all 155 existing assertions and their current security meaning.

## Business Reason

Workflow structural verification in `scripts/test_agent_continuity.ps1` depends on the checkout's newline representation. The same semantically identical GitHub Actions YAML passes when materialized as LF and loses the admission job under CRLF. A control-plane proof must depend on YAML structure, not on Windows/Linux newline representation.

This was established by a controlled A/B experiment, not inferred. Two independent full-history clones of the canonical repository at the same SHA `cd92cb23`, both with `core.autocrlf false`, differing only in the working-tree line endings of the six files under `.github/workflows/`. Every transformed file normalized `CRLF -> LF` matched the control's SHA256 byte-for-byte, and `git status` showed no other changed path, so line-ending representation was the sole independent variable.

```text
A (LF,   0 CRLF / 435 LF)   155 passed, 0 failed, exit 0
B (CRLF, 435 CRLF / 0 LF)   151 passed, 4 failed, exit 1
                            150, 152, 153, 155
```

The defect is in the test and control evidence layer. It is NOT a workflow defect, a GitHub Actions defect, a timeout defect, an Acceptance defect, a Windows defect, or a reason to force the repository to LF globally. The admission boundary itself is correct in both runs; only the proof of it is unreliable.

Why this matters beyond a red local run: the four assertions are the only mechanical proof that exactly one job can emit the required `orvion-acceptance` context, that it carries no job-level `if:` or `continue-on-error:` bypass, that it is frozen at the proven runner and a pinned `actions/checkout` commit, and that it declares exactly one job-level `timeout-minutes` at the approved 30. A detector that silently stops seeing the job it guards is the fail-open class this repository keeps finding. It currently fails loudly on Windows, which is the benign direction — but the same fragility would report success over an empty job set if the surrounding assertions were ever written to tolerate a missing admission job.

## Risks

Low, and the material risks are named rather than assumed away.

- The repair changes how workflow text is READ, not what is asserted about it. Every structural regex keeps its current semantics; the input simply reaches them in one canonical newline representation.
- The real risk is a regression proof that is green for the wrong reason. On a machine that checks out CRLF, a CRLF proof can pass merely because the machine already produced CRLF, proving nothing about the normalization. This is why the regression fixture must DERIVE both representations from the same semantic content rather than trusting the checkout, and why a causal mutant is required.
- A second risk is scope creep into a repository-wide line-ending policy. `.gitattributes`, `core.autocrlf` and workflow rewrites are deliberately out of scope: they would make the detector correct only because Git happens to materialize one style, which is the opposite of portability.
- Assertion semantics are security-bearing. Strengthening 150, 152, 153 and 155 to hold under both representations only narrows what passes; it cannot widen it.

## Supersedes / Depends On

None. This Change Request is independent of the unpublished culture-date work held locally under the SPEC-176 identity, and shares no file with it except by coincidence of repository.

## Write Scope

- `changes/SPEC-177-workflow-proof-is-newline-invariant.md`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `.gitattributes`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `CODING_STANDARDS.md`
- `changes/TEMPLATE.md`
- `supabase/migrations`
- `reports/history`

Also out of scope as SUBJECTS, not merely as files: the culture-date repair carried locally under SPEC-176, Performance Stage 0 profiling, H1 future-date batching, Check 12 performance optimization, repository corpus hermeticity, affected-verification selection, cloud deduplication, Workstation, Python, Oracle, Java, global or system Git configuration, `.gitattributes`, GitHub Rulesets, and any modification of the Acceptance workflow.

## Required Reading

- `scripts/test_agent_continuity.ps1`
- `.github/workflows/orvion-acceptance.yml`
- `CR_LIFECYCLE.md`
- `AGENTS.md`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Implementation Steps

1. Verification check: `scripts/test_agent_continuity.ps1` contains the string `Get-WorkflowEmitters`. If it matches, record Already Applied and skip. Otherwise extract the existing inline workflow scan — currently the `foreach` over `$wfDir` that builds `$emitters`, together with the job-header, job-end, and job-name matching inside it — into ONE local function in the same file, taking a collection of workflow name/text pairs and returning the same emitter objects it builds today (`File`, `Job`, `Context`, `Body`). Move the logic without altering any regex, the job-end boundary rule, the `name:` fallback to the job id, or the emitter shape. Introduce no new file, module, class, dependency, YAML parser, package, framework, workflow, or permanent utility script. This step must change no assertion.

2. Verification check: that function contains a `.Replace` call converting CRLF to LF, applied before any structural matching. If it matches, record Already Applied and skip. Otherwise normalize once, at that single input boundary, as the first thing the function does to each workflow's text. Do not add `\r?` to individual downstream regexes: one authority for newline policy, so a future regex cannot omit it. Leave `(?ms)^jobs:[ \t]*\r?\n(?<b>.*)$` exactly as written — it is already tolerant and rewriting it would spread the policy again.

3. Verification check: the structural block derives a CRLF representation of the workflow set. If it matches, record Already Applied and skip. Otherwise, from the SAME workflow texts already read from `.github/workflows/`, derive two in-memory representations: one with every line ending as LF and one with every line ending as CRLF, both produced from that single source so they are semantically identical by construction and neither depends on what `core.autocrlf` did to the checkout. Call the Step 1 function once per representation. Do not write fixture workflow files to disk, do not copy the workflow directory, and do not implement a second parser — both representations must traverse the same structural parsing path, which is the whole point of Step 1.

4. Verification check: assertions 150, 152, 153 and 155 evaluate their conditions against both representations. If it matches, record Already Applied and skip. Otherwise strengthen those four assertions so each requires its existing condition to hold for the LF representation AND the CRLF representation, keeping each assertion's number, name, meaning and failure detail. The total assertion count stays at 155: this repairs the portability of existing proofs and invents no new security property, so no assertion 156 is created and no manifest suite figure changes. For each representation the required facts remain exactly: exactly one `orvion-acceptance` emitter; no job-level `if:`; no job-level `continue-on-error:`; a `steps:` key; `runs-on: ubuntu-24.04`; a pinned 40-hex `actions/checkout` commit; exactly one job-level `timeout-minutes`; and that value equal to 30. Assertion 151 and assertion 154 are not touched.

5. Verification check: none — this step is a proof obligation and is recorded in the Execution Log rather than detected in the tree. Before the candidate is accepted, prove RED then GREEN using the same semantic workflow contents with no unrelated file differing. RED, against the baseline implementation: an LF checkout yields 155 passed / 0 failed and a CRLF checkout yields 151 passed / 4 failed on assertions 150, 152, 153 and 155, or an equivalent targeted proof on the same code path reproducing that signature. GREEN, after the candidate: both representations yield 155 passed / 0 failed. Then run at least one causal mutant in a disposable clone or copy only, never against authoritative history: remove or bypass the Step 2 normalization, run the permanent proof FROM AN LF CHECKOUT, and require the CRLF arm of the structural assertions to fail. That last condition is the one that matters — without it the proof could be passing only because the developer's own machine checked the files out as CRLF, and it would not detect the regression on GitHub's LF runners. Restore the candidate exactly and prove the restoration before concluding.

## Acceptance Criteria

- [ ] `scripts/test_agent_continuity.ps1` contains exactly one workflow-scanning implementation, reached by both representations, and no new file, module, dependency or YAML parser was added.
- [ ] Newline normalization occurs at exactly one place — the defect-bearing workflow-enumeration input boundary — and no downstream structural regex gained a `\r?` in this Change Request.
- [ ] The `$acceptRaw` read and every assertion that consumes it (141, 142, 143, 151, and the `actions/checkout` pin in 153) are unchanged.
- [ ] The job-header, job-end, job-name, `runs-on` and `timeout-minutes` matchers are otherwise unchanged from their pre-change text.
- [ ] The suite declares 155 assertions; no assertion was added, removed or renumbered, and no manifest suite figure changed.
- [ ] Assertions 150, 152, 153 and 155 each require their condition to hold under both an LF and a CRLF representation derived from the same workflow content.
- [ ] The CRLF representation is derived in memory from the workflow text actually read, not from the checkout's line endings and not from fixture files written to disk.
- [ ] No file under `.github/workflows/`, and no `.gitattributes`, was created or modified, and no Git configuration was changed at any scope.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

Mechanism, confirmed by reading the baseline rather than assumed. The defect lives in the workflow-enumeration path, where each file under `.github/workflows/` is read and scanned for job headers. The `jobs:` block matcher is written `(?ms)^jobs:[ \t]*\r?\n(?<b>.*)$` and tolerates both representations, so the block is still found under CRLF. The job-header matcher immediately after it is written `(?m)^  (?<id>[A-Za-z0-9_-]+):[ \t]*$` with no `\r?`, and `[ \t]*` cannot consume the `\r` that sits before the line break, so ZERO job headers match. The emitter list is therefore empty, the admission job is empty, and assertions 150, 152 and 153 fail together. Assertion 155 searches that same empty job body with `(?m)^    timeout-minutes:[ \t]*(?<m>\d+)[ \t]*$`, which is why it reports `keys=0 value(s)=<none at job level>` even though `timeout-minutes: 30` is present at job level in the file. The asymmetry between one CRLF-tolerant regex and its CRLF-intolerant neighbours is the entire defect, and it is exactly the omission surface that per-regex `\r?` patching would leave open again.

Scope deliberately NOT taken. The suite reads workflow text at a second place, the `$acceptRaw` read of `orvion-acceptance.yml`. An earlier revision of this Draft proposed normalizing it too, "so the boundary rule is uniform". That is removed. The A/B experiment reproduced the failure only in the enumeration path, `$acceptRaw` was not part of the reproduced failure, and its relevant consumers (assertions 141, 142, 143, 151, and the `actions/checkout` pin in 153) already tolerate CRLF where it matters — assertion 151's `on:` matcher is written with `\r?\n`, and 153's pin matcher is not line-anchored. Changing an unaffected boundary on a symmetry argument is exactly what EARN IT forbids: it would be an unevidenced edit to a security-bearing control file, and uniformity is not evidence. If a future regex over `$acceptRaw` is ever written line-anchored, that is the Change Request that must carry the normalization, with its own reproduction.

The Execution Log and Verification Notes sections are written `None.` rather than carrying the template's placeholder stanza. The Gate's append-only rule treats a committed placeholder as real prior evidence and then requires it to remain an exact prefix forever; `None.` is recognized as "no evidence recorded yet", so the first real entry can be written cleanly.
