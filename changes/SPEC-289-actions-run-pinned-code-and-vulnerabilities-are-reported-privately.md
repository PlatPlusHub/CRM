# Change Request — SPEC-289

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make every GitHub Actions workflow in Platinum run only commit-pinned action code with read-only defaults, retire the two unused Claude agent workflows, and publish a private vulnerability-reporting policy.

## Business Reason

The programme's CR B (GitHub Actions hardening) and the owner's 2026-10-19 requirement for a repository security policy, measured in a disposable clone of this repository at its CR C candidate on 2026-10-19:

- **Mutable action references.** `zizmor` 1.30.1 (offline) reports 7 high `unpinned-uses` findings: `actions/checkout@v4` in `migration-ci.yml` and `repository-consistency.yml`, `actions/checkout@v6` in `agent-control.yml`, and `actions/checkout@v4` with `anthropics/claude-code-action@v1` in each Claude workflow. A tag can be moved to different code; a commit cannot. Only `orvion-acceptance.yml` is already pinned.
- **Implicit token permissions.** `migration-ci.yml` and `repository-consistency.yml` declare no `permissions:` (2 medium `excessive-permissions` findings). The repository default is `read` today, so this is drift protection, not a live grant.
- **Unused agent workflows.** `claude.yml` and `claude-code-review.yml` need the `CLAUDE_CODE_OAUTH_TOKEN` secret, which this repository does not hold (0 Actions secrets), so their last runs were all skipped. They are dead configuration that still runs third-party code on public events whenever someone adds the secret.
- **No security policy.** No `SECURITY.md` exists in the root, `.github/` or `docs/`, so a reporter has no stated private channel. GitHub private vulnerability reporting is the only channel this repository can offer without inventing an address; it was disabled on 2026-10-19 and must be enabled by the owner before this policy is true (Step 1).

After the change `zizmor` reports 0 high findings; the 4 remaining medium `artipacked` findings are recorded in Notes as not earned. `actionlint` 1.7.7 reports 0 findings before and after.

## Risks

Low. Each pin is the exact commit its tag resolves to today (`v4` = `11d5960a326750d5838078e36cf38b85af677262`, `v6` = `d23441a48e516b6c34aea4fa41551a30e30af803`, the commit `orvion-acceptance.yml` already runs), so no workflow changes behavior. `permissions: contents: read` equals the measured repository default. Retiring the Claude workflows removes no check any authority expects: neither triggers on `push`, and neither is a required check. The cost is that `agent-control.yml` is a control surface, so `-Finish` runs the CONTROL profile (about 42 minutes); the alternative of leaving one workflow unpinned was rejected (Notes). Hosted results on the changed workflows are proven only after publication, by `-Certify`. CTRL-19 remains OPEN.

## Supersedes / Depends On

Depends on completed `SPEC-287` and its promotion: this contract's baseline is `main` `7e06438d3574cba5151e207bf527ced710224dfa`, and `SPEC-287`'s exact-SHA remote certification precedes this contract's `-Finish`. Supersedes nothing.

## Write Scope

- `changes/SPEC-289-actions-run-pinned-code-and-vulnerabilities-are-reported-privately.md`
- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `.github/workflows/agent-control.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/SECURITY.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/orvion-acceptance.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/watch_ci.ps1`
- `scripts/github_public_read.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/batch6_select_target.ps1`
- `.workstation/doctor.ps1`
- `README.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_GAP_REGISTER.md`

The admission workflow and its frozen runner and checkout pin stay unchanged. No GitHub setting, secret, ruleset or credential is changed by this contract. Batch 6 is ON HOLD in both repositories by owner decision of 2026-10-18 until the infrastructure programme completes and the owner explicitly authorizes resumption. Not here: Dependabot configuration, CODEOWNERS, persistent `actionlint` or `zizmor` integration, `persist-credentials` changes, the mechanical Three-Pass Draft Assurance enforcement, run resource sampling, and publication or promotion by the agent.

## Required Reading

- `AGENTS.md` §§1–3
- `CR_LIFECYCLE.md` §§4–5,8–9
- `ENGINEERING_METHOD.md` §§1–3
- `changes/TEMPLATE.md`
- `.github/workflows/agent-control.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/repository-consistency.yml`
- `scripts/test_agent_continuity.ps1`: the STRUCTURAL workflow assertions (150–155 and the Agent Control step checks)
- `scripts/check_agent_continuity.ps1`: Profiles, Get-ControlSurface, the workflow expectation reader

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Significant

Baseline: `7e06438d3574cba5151e207bf527ced710224dfa`, the `SPEC-287` candidate, which becomes `main` by the owner's exact-SHA promotion. Allocation is derived by the existing allocator from this repository's history (cursor 287; 288 reserved by `SPEC-286`'s text; 289 unreserved) and is refreshed immediately before the owner-approved Draft is committed.

Source anchors (baseline Git blobs, including read-only consumers):

| Path | Baseline blob |
| --- | --- |
| `.github/workflows/agent-control.yml` | `48e90c2b23c4c56f49b1117e4598d63bc2fc267e` |
| `.github/workflows/migration-ci.yml` | `927cac7323b741b2ebcbe837b6ea4fb8da875211` |
| `.github/workflows/repository-consistency.yml` | `e8c48a3f2f8a321ac951b5ed3bb2587e8551209f` |
| `.github/workflows/claude.yml` | `6b15fac7af3da593de10cdc0e8203a0ae7d722bd` |
| `.github/workflows/claude-code-review.yml` | `b5e8cfd4dc37c61955c30f11cebe4e7bf7d126dd` |
| `.github/workflows/orvion-acceptance.yml` | `b242e4c7401258404c5d43bffb49c3f53f42467e` |
| `scripts/check_agent_continuity.ps1` | `256879e512235b1e8744ea64862dd1e82ce65c6d` |
| `scripts/test_agent_continuity.ps1` | `52934332def1608d6bc12b6ac5847db34f4b37f7` |
| `scripts/check_repository_consistency.ps1` | `3e6d2810e03bfac15b96dba3bc46d119d97ad658` |
| `scripts/publish_candidate.ps1` | `d168504cc66c3a0759ac3ee9b5e01045a0f46589` |
| `scripts/promote_main.ps1` | `bf64aa893faf9d6be7477254bebf80dca04b4d79` |
| `scripts/watch_ci.ps1` | `ca87c18d3ac7fa62f70f5df681c5df18cf482699` |
| `GOVERNANCE.md` | `5670c47888bbd6b4194f6c41c54476ee42cb7bdf` |
| `_ORVION_CANONICAL/manifest.md` | `d3d19a99013d8570fa481373290e5e67d82e460c` |
| `ai-map.json` | `3911e34c40e36d2d11c291f80a8fae857e57851b` |
| `repository-index.md` | `d075792a248fc781d7012cc0296fcd8bc15a47d5` |

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Action references become commit SHAs | GitHub Actions runners for Agent Control, Migration CI, Repository Consistency | WRITE | Each SHA is the commit its tag resolves to on 2026-10-19 (`git ls-remote`), so the executed code is unchanged |
| Workflow files change | Profiles in `-Finish` (CONTROL via `agent-control.yml`, CI deferred to `-Certify`) | VERIFY | The CONTROL suites run once in the timed Finish |
| Workflow text the control suite parses | STRUCTURAL assertions 150–155 and the Agent Control step checks in `scripts/test_agent_continuity.ps1` | VERIFY | Sandbox run of the suite on the patched tree before freezing; the admission job, its runner and its pin are untouched |
| `repository-consistency.yml` trigger paths and suite list | `scripts/check_repository_consistency.ps1` CI trigger checks | VERIFY | Repository consistency CLEAN on the patched tree; the `on:` block and suite list are unchanged |
| Expected hosted checks | Workflow expectation reader, receipt `expected`, `-Certify`, `scripts/watch_ci.ps1` | UNAFFECTED | The retired workflows trigger on issues, comments and pull requests only, never `push`, so no expected check disappears |
| Required check and admission | Ruleset `orvion-acceptance`, `.github/workflows/orvion-acceptance.yml` | UNAFFECTED | File unchanged and pinned by a criterion |
| A security policy exists | GitHub's Security tab and the private vulnerability reporting channel | WRITE | Step 1 refuses unless the owner has enabled the channel; the policy names only that channel |
| Generated projections | `ai-map.json`, `repository-index.md` | VERIFY | The generator changes neither file on the patched tree; only the lifecycle's active-pointer and Last Completed lines move |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Legal identity, admitted frozen contract and an enabled private reporting channel | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Workflows and control suites agree | BEFORE_COMPLETION | 2 | 5 | 7 |
| Generated state, scope and contract agree | BEFORE_COMPLETION | 2 | 7 | 8 |

Measured in a disposable Platinum clone at the baseline with every edit applied: `actionlint` 0 findings before and after; `zizmor` 15 findings before (7 high, 7 medium, 1 low) and 4 after (medium `artipacked` only); repository consistency CLEAN; the generator changes no projection; `scripts/test_agent_continuity.ps1` on the patched tree as recorded in Notes. A lifecycle rehearsal in a disposable clone carrying this checkout's ignored certification state is recorded in the Gate 1 packet. These are preparation measurements; the derived commands run once, in the final timed Finish.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: the existing workflows and the `SPEC-177`/`SPEC-182`/`SPEC-185` structural assertions over them; this contract narrows what three workflows may execute and adds no control, predicate or check.

Added Property: every action a remaining workflow runs is fixed by commit, every workflow states its token permissions, and no workflow runs a third-party agent action.

Causal Negative: at the baseline `zizmor` reports 7 high `unpinned-uses` findings across five workflows and 2 `excessive-permissions` findings.

Positive Test Design: the existing structural assertions and the full control suites keep passing on the patched workflows; repository consistency stays CLEAN.

Negative Test Design: after the change `zizmor` reports 0 high findings; no workflow other than the retired two is removed.

Non-Empty Population Obligation: the structural assertions still find exactly one admission emitter, the Agent Control gate job and one consistency job.

Mutation Obligation: none added; this contract adds no predicate, and the existing structural mutants are unchanged.

Post-Implementation Proof Obligation: the full control suites and the REPOSITORY commands pass in one fresh timed and watched Finish on the final implementation; hosted workflow conclusions on the exact pushed SHA are proven by `-Certify`.

## Implementation Steps

1. Check that the owner's Gate 1 approval names this exact Draft's SHA-256, that remote `main` is `7e06438d3574cba5151e207bf527ced710224dfa`, that every source anchor above matches at `HEAD`, and that `gh api repos/PlatPlusHub/CRM/private-vulnerability-reporting`, run with this repository's own account, returns `{"enabled":true}`; if any differs, stop and report without any write. This step writes nothing beyond the allocation and approval commits the owner's command directs.
2. Check whether both `.github/workflows/claude.yml` and `.github/workflows/claude-code-review.yml` are absent; if so record Already Applied, and if exactly one is absent stop and report. Otherwise delete both files and change nothing else.
3. Check whether `.github/workflows/migration-ci.yml` contains `actions/checkout@11d5960a326750d5838078e36cf38b85af677262`; if so record Already Applied. Otherwise replace `uses: actions/checkout@v4` with `uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4`, and immediately before the line `jobs:` insert the line `permissions:`, the line `  contents: read` and one empty line. Change nothing else. The resulting file's Git blob is 9bf8ca02d8ffac6591871b66bff53d5dbfc6e75c.
4. Check whether `.github/workflows/repository-consistency.yml` contains `actions/checkout@11d5960a326750d5838078e36cf38b85af677262`; if so record Already Applied. Otherwise make the same two edits as Step 3 in this file and change nothing else. The resulting file's Git blob is ed3ef8d8e954c8a2c5710fe44f46eb1f569c7492.
5. Check whether `.github/workflows/agent-control.yml` contains `actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803`; if so record Already Applied. Otherwise replace `- uses: actions/checkout@v6` with `- uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6` and change nothing else. The resulting file's Git blob is 41243b7c9a499df4cf011385a046c53107084ba3.
6. Check whether `.github/SECURITY.md` exists; if so record Already Applied when its Git blob is 2b836bdf375a5fc6d0b6a8b01f4fbbed2e8bf132, and otherwise stop and report. Otherwise create it with exactly this content, LF line endings and a final newline:

   ```markdown
   # Security policy

   This policy covers the `PlatPlusHub/CRM` repository (ORVION, Platinum). The `PlatPlusHub` account owns this repository and is responsible for its security.

   ## Supported versions

   There are no versioned releases. Only the current `main` branch is supported: fixes are made there, through the repository's Change Request process, and older commits receive none.

   ## Reporting a vulnerability

   Report it privately through GitHub: open this repository's **Security** tab and choose **Report a vulnerability**. That opens a private advisory visible only to the repository's maintainers.

   Please include:

   - what the vulnerability is and what an attacker could do with it;
   - the affected file, workflow, script or commit;
   - steps to reproduce it, or a proof of concept;
   - any mitigation you know of.

   Do not open a public issue, pull request or discussion about an unfixed vulnerability, and do not publish its details before a fix is on `main`. Never put real credentials, tokens or personal data in a report.

   ## Response

   This is a privately maintained project. There is no guaranteed response time and no bug bounty.
   ```

   The resulting file's Git blob is 2b836bdf375a5fc6d0b6a8b01f4fbbed2e8bf132.
7. Check whether the Runtime Checkpoint reads `Resume Step: DONE`; if so record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, confirm `pwsh -NoProfile -File scripts/generate-ai-map.ps1 -Check` exits 0 and that `git status --porcelain` names only Write Scope paths, append the Execution Log entry, set the Runtime Checkpoint to `Resume Step: DONE`, `Blocker: None`, `Recovery Attempt: 0`, and commit the implementation and checkpoint together through the unchanged pre-commit hook.
8. Check that a fresh native receipt for this contract matches, a `Verdict: Confirmed Complete` Verification Notes entry exists and every Acceptance Criterion and Review Gate item holds; only then record Already Applied. Otherwise, from the repository root, start `pwsh -NoProfile -File scripts/run_timed.ps1 -Log <log> -Command "pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish"` and, at the same time, `pwsh -NoProfile -File scripts/watch_run.ps1 -Log <log> -Run spec-289-finish -Brief`. Require `LOCAL_CERTIFY: READY`; a failed command keeps its real exit code and evidence and starts bounded recovery without weakening any assertion. Perform independent live Review against the repository, including that both retired workflows are absent, and append its Verification Notes verdict. Then complete through the native lifecycle with the unchanged pre-commit hook, setting `manifest.md`'s `Active Change Request` to `None.` and its `Last Completed` to exactly `Last Completed: **SPEC-289: GitHub Actions run only commit-pinned code with read-only defaults, the unused Claude workflows are retired and a private vulnerability-reporting policy exists — fresh local verification and Review complete; owner publication/promotion and exact-SHA remote certification follow `CR_LIFECYCLE.md` §9. Batch 6 remains ON HOLD by owner decision (2026-10-18) until the infrastructure programme completes and the owner authorizes resumption. CTRL-19 remains OPEN.**`, regenerating the projections with the existing generator. Locally prepare the exact candidate with `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BindCandidate -Root <original-checkout> -BaseRef <full-main-SHA> -HeadRef <full-candidate-SHA>`. Stop before publication or promotion.

## Acceptance Criteria

- [ ] The three remaining non-admission workflows run commit-pinned checkout code with explicit read-only permissions, with exactly the reviewed bytes. `check: blob .github/workflows/agent-control.yml 41243b7c9a499df4cf011385a046c53107084ba3` `check: blob .github/workflows/migration-ci.yml 9bf8ca02d8ffac6591871b66bff53d5dbfc6e75c` `check: blob .github/workflows/repository-consistency.yml ed3ef8d8e954c8a2c5710fe44f46eb1f569c7492` `check: lacks .github/workflows/migration-ci.yml "uses: actions/checkout@v"` `check: lacks .github/workflows/repository-consistency.yml "uses: actions/checkout@v"` `check: lacks .github/workflows/agent-control.yml "uses: actions/checkout@v"`
- [ ] `.github/workflows/claude.yml` and `.github/workflows/claude-code-review.yml` no longer exist.
- [ ] The security policy names GitHub private vulnerability reporting as its only channel, with exactly the reviewed bytes. `check: blob .github/SECURITY.md 2b836bdf375a5fc6d0b6a8b01f4fbbed2e8bf132` `check: has .github/SECURITY.md "choose **Report a vulnerability**"`
- [ ] The admission workflow, the evaluator, the control suite, release authorities and the watcher are unchanged. `check: blob .github/workflows/orvion-acceptance.yml b242e4c7401258404c5d43bffb49c3f53f42467e` `check: blob scripts/check_agent_continuity.ps1 256879e512235b1e8744ea64862dd1e82ce65c6d` `check: blob scripts/test_agent_continuity.ps1 52934332def1608d6bc12b6ac5847db34f4b37f7` `check: blob scripts/publish_candidate.ps1 d168504cc66c3a0759ac3ee9b5e01045a0f46589` `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79` `check: blob scripts/watch_ci.ps1 ca87c18d3ac7fa62f70f5df681c5df18cf482699` `check: blob GOVERNANCE.md 5670c47888bbd6b4194f6c41c54476ee42cb7bdf`
- [ ] The manifest keeps the owner's Batch 6 hold. `check: has _ORVION_CANONICAL/manifest.md "Batch 6 remains ON HOLD by owner decision (2026-10-18)"`

## Execution Log

None.

### 2026-10-19 — Gate 1 approval recorded

The owner's delegation directive of 2026-10-19 approved this prepared contract, conditional on its frozen SHA-256 equalling the digest in its Gate 1 packet (51FDB356102352B13600015E92699FCA70DD512AA741B14387BA968568A409FB), successful rehearsal, complete scope and unchanged assumptions. Immediately before allocation the hash, the Draft blob 30fe878d46c81ea65e937082d00eb497d0c72a87, all 16 source anchors, refreshed origin/main 7e06438d3574cba5151e207bf527ced710224dfa (the promoted predecessor), a clean checkout and an enabled private vulnerability-reporting channel were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 372dbaa. No implementation performed before this transition. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

## Verification Notes

None.

## Review Gate

- [ ] Exact approved steps and exhaustive scope independently confirmed.
- [ ] Every acceptance criterion confirmed against final local evidence, including the two absent workflows.
- [ ] Mandatory profiles and Git checks pass through fresh Finish.
- [ ] Admission workflow, release authorities and historical evidence preserved; no GitHub setting changed; CTRL-19 remains OPEN.

## Notes

Three-pass Draft assurance. V1 took every tool finding as scope: pin all actions, set `persist-credentials: false` everywhere, add Dependabot for action updates, pin the Claude workflows rather than remove them, and put `SECURITY.md` at the root. V2 challenged each. `persist-credentials` (`artipacked`, 4 medium findings after the change) matters only when a workflow uploads its workspace; none uploads any artifact, the token is read-only, and changing it would touch `orvion-acceptance.yml`, the frozen admission boundary, for no reachable leak: not earned. Dependabot would open pull requests that cannot merge without a Change Request; GitHub's native `sha_pinning_required` Actions setting enforces pins with no repository code, so it is recommended to the owner after this contract instead. Pinning the Claude workflows would keep third-party code that this repository cannot run (no secret) on public triggers; retiring them is smaller and removes 4 findings. A root `SECURITY.md` adds a root document; GitHub reads `.github/SECURITY.md` equally. Leaving `agent-control.yml` unpinned would avoid the CONTROL profile, but keeps one mutable reference in the workflow that judges every push and skips the local run of the structural assertions this change touches; one coherent invariant ("no tag reference remains") was preferred. V3 refreshed evidence on 2026-10-19: tag commits from `git ls-remote https://github.com/actions/checkout`; `actionlint` 1.7.7 and `zizmor` 1.30.1 (released 2026-09-09) run in the sandbox only, never installed in the repository; Actions secrets 0, default workflow permissions `read`, private vulnerability reporting disabled, all read with this repository's own account. V3 is selected. No criterion can check that a file is absent, so that one item is judged by Review.

Contract size was challenged. Pins, permissions, retirement and the policy share one objective, one Write Scope of workflow configuration and one Finish; split, the policy alone would cost a Gate 1 and a release of its own for one file. Run resource sampling, Dependabot and Draft Assurance are separate mechanisms and stay out.

Repository identity checked from effective Git configuration: this checkout commits as `PlatPlusHub <platplustours@gmail.com>` from its local configuration. Push authentication is not commit authorship and neither is changed here.
