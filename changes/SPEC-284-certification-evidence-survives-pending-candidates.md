# Change Request — SPEC-284

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Extend the existing local certification mechanism to preserve each completed candidate's original Finish evidence under its exact final SHA until human promotion and remote certification.

## Business Reason

The owner's 2026-10-16 Integrated Directive v3 keeps receipt continuity first and selects owner publication. At `082d106013c24d949b80415a1d1ceaf62cc61587`, `Finish-Checks` removes the single checkout receipt before running verification; a later successful or failed Finish can destroy evidence needed for an earlier candidate. An isolated reproduction observed that replacement.

Critical Architecture Audit: Finish precedes the completion commit and cannot know its future SHA. Keep Finish as the sole origin of verification claims. The existing evaluator's proposed Gate-only binding switch is independently callable: bind the unchanged claim after its committed-range Gate passes, without pushing or requiring GitHub authentication. The existing publisher reuses this same operation before transport. Store records inside the existing ignored local certification mechanism, not a separate ledger. Preserve all existing Git/CI judgment.

Select Option B: one retained record per candidate SHA, locally prepared before the next Finish. A focused experiment proved C1 preparation → unpublished C1 → C2 Finish/completion → restart → ordered owner transport/promotion and independent certification, using the original checkout. Reject publication-coupled preparation and sequential-only operation because they make owner absence block otherwise approved work unnecessarily. Reuse `-Gate -BindCandidate`; a new preparation script adds no property. Reject separate certification services, copying receipts between CRs, deriving expectations again, and inventing the future completion SHA. No additional mandatory GitHub check is needed for this correction. PAT transport and public-reader migration remain later units.

## Risks

Local records remain anti-omission/staleness evidence, not signatures or a boundary against an agent holding owner credentials. Checksums detect accidental alteration; they do not prevent deliberate recomputation. Ignored records belong to the original checkout: a clone or promoter data worktree does not inherit them. Retain that checkout and a Git branch naming the pending tail; machine loss is not solved here. The cutover must refuse unsupported legacy evidence rather than reconstruct SPEC-282. Preparation proves neither publication nor CI admission. Publication failures must preserve records. The current publisher still executes checkout code and may use stored credentials; this CR does not make it safe for an ephemeral owner PAT or eliminate CTRL-19. Rollback is a corrective CR/revert through the same lifecycle; retain pending records and pause affected certification if old code cannot read them.

## Supersedes / Depends On

Extends the mechanisms delivered by completed SPEC-164, SPEC-180, SPEC-184, SPEC-242, SPEC-263, SPEC-273 and SPEC-281. Their historical contracts remain unchanged. No new external prerequisite.

## Write Scope

- `changes/SPEC-284-certification-evidence-survives-pending-candidates.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/test_certification_receipts.ps1`
- `.gitignore`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/promote_main.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/watch_ci.ps1`
- `scripts/watch_run.ps1`
- `scripts/run_timed.ps1`
- `scripts/generate-ai-map.ps1`
- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/agent-control.yml`
- `.github/workflows/migration-ci.yml`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

All external settings, authentication, production/database operations, Batch 6, B1, ETA and Improvement Engine work are excluded.

## Required Reading

- `AGENTS.md` §§1–3
- `ENGINEERING_METHOD.md` §§1–3
- `CR_LIFECYCLE.md` §§8–9
- `GOVERNANCE.md` §§2,15
- `reports/architecture-decision-records.md` ADR-0031
- `scripts/check_agent_continuity.ps1` certification functions and Gate completion path
- `scripts/publish_candidate.ps1`
- `scripts/test_agent_continuity.ps1` receipt, publication, inherited-run and segmented-range cases

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- pwsh -NoProfile -File scripts/test_certification_receipts.ps1

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Finish origin and working receipt | `scripts/check_agent_continuity.ps1`: Write-Certification, Validate-Certification, Finish-Checks | WRITE | Existing fingerprint/profiles remain authoritative; overwrite guard preserves prior pending evidence. |
| Exact candidate association | evaluator Gate parameter/binding path; `scripts/publish_candidate.ps1` | WRITE | Independently callable local range Gate/binding; publisher reuses it before the existing exact-SHA push. No new transport. |
| Remote receipt selection | evaluator Certify-Remote | WRITE | Completed HEAD selects its retained record; preserve nonterminal exact-Finish-HEAD certification, with identity/content validation, before the existing evidence reader. |
| Local record lifetime | `.gitignore`; existing test reset/receipt helpers | WRITE | Retained records are ignored; every fixture clears its own records and cannot contaminate another case. |
| Behavioral regression evidence | existing control suite; `scripts/test_certification_receipts.ps1` | WRITE | Keep every existing assertion; adapt synthetic receipt fixtures and add focused real-command lifecycle tests. |
| Certification procedure | `CR_LIFECYCLE.md` §§8–9; `GOVERNANCE.md` version/changelog | WRITE | Describe local preparation, owner publication through the existing publisher, and ordered certification; unchanged CR states and owner promotion. |
| Current CR/completion bookkeeping | manifest; generated `ai-map.json` and `repository-index.md` | WRITE | Normal active pointer and Last Completed synchronization only; generated files come from the generator. |
| Profile derivation, hooks, acceptance and trusted promotion | `AGENTS.md`; `ENGINEERING_METHOD.md`; existing hooks/workflows; `scripts/promote_main.ps1` | VERIFY | No profile subtraction, CI receipt exemption change, candidate execution by the trusted judge, or automatic main update. |
| CI reporting | `scripts/watch_ci.ps1` | VERIFY | Workflow-Expectations interface and branch-specific expectations remain unchanged. |
| Domain/schema, historical contracts, CTRL-19 and roadmap | migrations; completed CRs; master registers; roadmap | UNAFFECTED | No database change, history repair, false CTRL-19 closure or Batch 6 execution. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Baseline matches recorded source and approved contract | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Writer, binder, reader and fixtures agree on receipt format | BEFORE_COMPLETION | 1 | 4 | 6 |
| Documentation and generated state agree with implementation | BEFORE_COMPLETION | 1 | 5 | 6 |
| All mandatory profiles, scope and acceptance checks hold | BEFORE_COMPLETION | NONE | NONE | 6 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: Finish, working receipt validation, publisher range Gate, Certify-Remote and Inherited-Run; preserve their distinct evidence classes.

Added Property: A later Finish cannot silently destroy a prior pending candidate's original evidence; remote certification selects evidence bound to its exact candidate.

Causal Negative: The isolated probe loaded the real writer and Finish-Checks from 082d106; Finish for the second fixture CR replaced the first CR's only receipt. Its original record was absent afterwards.

Positive Test Design: Existing verified nonterminal SHA certification; single completion/preparation/publication/certification; two sequential approved CR histories with distinct SHA records prepared before any publication; repeated preparation/publication; a fresh process selects each original record, ordered promotion/certification of C1 followed by restoration and promotion/certification of C2 in the original checkout.

Negative Test Design: Wrong CR/SHA/profiles, changed content/context, altered/missing/legacy record, unbound prior receipt, interrupted write, failed later Finish/transport, conflicting archive, replaced/rejected candidate, wrong ref/event and non-success CI must never become READY. A fresh clone without the ignored records refuses instead of recreating them; preparation must not invoke gh authentication, transport, hooks or claim publication. Existing trusted-evaluator and promotion-lease tests remain intact.

Non-Empty Population Obligation: At least two distinct completed fixture CRs and full candidate SHAs; successful local publication to a real independent bare remote; positive READY and changed-ref refusals through the actual evidence reader with explicitly synthetic gh responses.

Mutation Obligation: Independently remove SHA/CR/profile/fingerprint/checksum checks, overwrite protection and exact-record selection; require the targeted case to change behavior without a crash, then restore and re-prove refusal. Preserve existing SPEC-167, trusted-Gate and inherited-run mutation populations.

Post-Implementation Proof Obligation: The new focused suite and all derived CONTROL/REPOSITORY commands pass on final implementation; Finish runs once through the timed runner with its concurrent watcher, then Review and candidate publication use existing gates. Prototype success is not implementation certification.

## Implementation Steps

1. **Check** for `Receipt Schema: 2` in the evaluator and its tested writer/validator. If fully present, record Already Applied; partial/unexpected state stops. Otherwise extend Write-Certification's existing record with schema 2, contract path, a `finishHead` Git anchor and a deterministic SHA-256 digest of all recorded fields excluding the digest itself. Keep CR/profiles/fingerprint/target/expected/result/time; derive expected workflows only here, once. The fingerprint identifies verified working content; `finishHead` is an ancestry anchor, not a claim that dirty work was already committed. Validate new fields/digest alongside existing completion checks; require a repository-relative `changes/SPEC-<id>-<name>.md` path matching the CR. Never record a future completion SHA at Finish.

2. **Check** for a Gate-only `-BindCandidate` switch and exact-SHA record reader. Otherwise add them in the evaluator: refuse binding with Trusted, without BaseRef, or with a non-full/mismatched HeadRef. The standalone preparation command is `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BindCandidate -Root <original-checkout> -BaseRef <full-main-SHA> -HeadRef <full-candidate-SHA>`. It uses the existing committed-range Gate, which runs local consistency code; it needs no gh authentication, fetch or push. After that Gate succeeds, binding a completed governor requires clean exact HEAD, matching original Finish evidence, unchanged implementation/profiles, finishHead ancestry, and an In-Progress-to-Complete transition on that HEAD. Atomically create `.orvion-certifications/<full-candidate-SHA>.json` containing that SHA and the unchanged original receipt, with an outer digest. Validate/reuse an existing record even when a later working receipt exists; never overwrite a conflict. Intermediate nonterminal publication keeps its behavior and creates no completion record. The binding helper executes no candidate subprocess, mutates no remote and derives no expectations. Emit a distinct preparation result, never a publication claim. This operation is local qualification, not the independent `-Trusted` admission judgment.

3. **Check** that the publisher requests `-BindCandidate`, Finish guards prior receipts, and Certify selects exact evidence. Otherwise wire those paths: bind before push; retain records when push fails; before a different CR's Finish removes working evidence, require valid matching records for earlier pending completions in the upstream-to-HEAD history, even if the working receipt is missing. Derive those completions from Git, using the existing changed-contract/range machinery; require each record's exact SHA/identity/digests and ancestry. Compare its historical association, never an earlier CR's fingerprint to later approved working content. A same-CR failed retry still invalidates its working receipt. Legacy evidence may be retired only when Git proves its completion is already on its recorded upstream target; never create a schema-2 claim from it. Pending/unreadable legacy evidence blocks. For completed HEAD, Certify requires its exact-SHA record and validates both digests, original CR/path, profiles, fingerprint, result and nonempty target/expected set. Read historical identity/status/scope by minimal Git projection, not the current whole-contract schema. Preserve nonterminal Certify only for clean HEAD equal to the working receipt's finishHead and its matching active Approved/In-Progress CR, with the same validation. Missing completion records never use that fallback. Reuse the existing remote reader, target-ref check and SPEC-263 proof; never recompute expectations. Ignore the retained-record directory in `.gitignore`.

4. **Check** for receipt-continuity cases in both test files. Otherwise adapt existing synthetic remote receipt/reset fixtures for the new format without removing assertions, and create the focused suite using actual evaluator/publisher subprocesses and independent Git repositories. Stub expensive child verifications only in orchestration fixtures, and stub gh evidence explicitly; never call those full verification or GitHub-enforcement proof. Cover every positive/negative/population/mutation obligation above, restart and atomic-write recovery. Exercise the standalone preparation command with no GH tokens, explicit fixture Git configuration, a gh auth tripwire and transport tripwires; prove C2 Finish succeeds while both candidates remain unpublished. Prove preflight later advances C1→C2 while main stays fixed; in the original checkout, use fresh processes to certify promoted C1, restore the named C2 branch, then certify promoted C2. Check ignored-file hashes at every boundary, refusal in a separate clone, stale promotion leases and TARGET_REF_MOVED after main passes C1. Restore each mutant.

5. **Check** for `Receipt Schema: 2` in CR_LIFECYCLE.md. Otherwise document the working receipt plus exact-SHA retained records in §§8–9; unchanged Finish/Certify interfaces and CR statuses; retention and fail-closed cutover/recovery. Require successful local Gate/binding after each completion before the next Finish, independently of publication. Keep the original receipt-bearing checkout and a named pending-tail branch. For each candidate requiring individual certification: the owner selects its full SHA, checks out that SHA cleanly in the original checkout and runs the existing `scripts/publish_candidate.ps1`; observe its exact-SHA preflight acceptance before owner promotion through the existing trusted-main checkout. If preflight already advanced to a descendant, use the earlier candidate's retained exact-SHA CI evidence when still eligible; do not rewind preflight or borrow the descendant's runs. The agent certifies it from the original exact-SHA checkout before main advances, then restores the pending branch. Promoting only the tail does not retroactively certify earlier SHAs. Prepared and published are observations, never new CR statuses. This clarification does not make the current publisher credential-safe; do not introduce the future PAT until its separate migration is proven and authorized. This dated Draft is the §15 proposal; Gate 1 ratifies it. Update GOVERNANCE.md version 1.20 to 1.20.1 and prepend the corresponding clarification entry. Synchronize only the manifest's active pointer/normal completion fields and regenerate both projections. Do not change pinned Batch 6 lines or repair historical CRs.

6. **Check** that all steps are applied and scope/generated state match. Record deterministic results in the Execution Log, set Resume Step DONE and commit the coherent implementation before the single required timed/watched Finish. Do not pre-run its mandatory or Additional commands inside a step. After successful Finish, independently Review, complete/synchronize/commit and prepare the exact candidate with the standalone Gate/binding command. Provide its exact SHA and the existing publisher command for owner publication. Observe publication and exact-SHA CI; provide the owner promotion handoff. After explicit owner promotion observe main and run Certify from the original checkout at that exact SHA. No agent publication or promotion, authentication migration or new transport is authorized by this CR. Any unmet criterion remains a blocker, never a pass.

## Acceptance Criteria

- [x] Finish remains the sole source of local claims and records schema 2 plus all original certification fields. `check: has scripts/check_agent_continuity.ps1 "Receipt Schema: 2"`
- [x] Local Gate/binding prepares the exact completion SHA without authentication or transport; the existing publisher reuses it before preflight push. `check: has scripts/publish_candidate.ps1 "-BindCandidate"`
- [x] Retained exact-SHA records survive later successful/failed Finish, and unbound pending evidence cannot be silently removed.
- [x] Wrong/missing/altered/stale evidence and contradictory identity/profiles/context fail closed; no old record or CI success can be borrowed.
- [x] Two candidates can be prepared before owner publication; fresh-process, checkout-restoration and remote-reader tests prove ordered certification in the original checkout, with required mutations killed and restored.
- [x] Existing transition, scope, trusted-evaluator, nonterminal exact-SHA certification, CI applicability, target-ref and ancestor-proof behavior is preserved.
- [x] Certification procedure, ignored runtime output and governance clarification agree. `check: has CR_LIFECYCLE.md "Receipt Schema: 2"`
- [x] Generated projections match their source; promotion remains owner-only and CTRL-19 remains open.

## Execution Log

None.

### 2026-10-16 — execution opened
Owner Human Gate 1 explicitly approved the exact reviewed Draft (SHA-256 d7edf3795ec9a955eca89583102879ab010d61d533a2773f44151d1445568100). Boot READY/PLAN; baseline HEAD/main/preflight 082d106, only the Draft uncommitted. Prototype source hashes and final 60/20 logs recovered without rerunning. The guard required a Draft origination commit before the approval transition; no guard was bypassed. Approval admissibility PASS. Implementation begins at Step 1; publication and promotion remain owner actions.

### 2026-10-16 — Steps 1–5 implemented; Step 6 ready for Finish

Schema-2 Finish receipts preserve every original field, contract identity, existing Git anchor and canonical digest. The existing evaluator now supports local full-SHA range Gate/binding, atomically retains the original claim per completion SHA, reuses valid records and refuses conflicts. Publisher requests the same binding before its unchanged preflight transport. Finish checks pending historical associations before removing working evidence, including missing-working-receipt and Git-proven legacy retirement. Completed certification selects only its exact record; clean nonterminal exact-Finish-HEAD certification, the existing remote reader, trusted Gate, promotion leases and ancestor proof remain. Runtime records are ignored. CR_LIFECYCLE §§8–9 clarify original-checkout retention, local preparation and owner publication/promotion; GOVERNANCE 1.20.1 is the ratified PATCH. Manifest pinned Batch 6 lines and all excluded files remain unchanged.

Targeted implemented-code evidence, timed and watched while running where long: codec 3/0 (`implementation-codec-v2.log`); receipt mutation subset 33/0 (`implementation-mutations.log`, seven independent mutations: overwrite protection, SHA, CR, profiles, fingerprint, checksum and exact selection); existing reader assertions extracted unchanged with their fixtures 48/0 (`implemented-reader-regression-v2.log`, including all 15 inherited-run mutations); cutover/atomic/nonterminal subset 19/0 (`implemented-cutover-probe-v2.log`). Logs are in the existing owner-review evidence directory recorded in Notes. These subprocess probes use explicit child-command stubs and synthetic gh data against disposable bare Git, not full profiles or hosted enforcement. The final suite will execute all populations against the final implementation during Finish.

Development failures were preserved and corrected, never counted as passes: JSON timestamp coercion, singleton-array unwrapping and decorated pipeline scalars broke canonical round trips; codec tests now exercise those representations. The sequence's missing-ref helper ignored Git's nonzero exit (34/3 before correction); its ordered C1/C2 certification/restoration assertions themselves passed, and the corrected helper passes in the mutation subset. A superseded reader extraction loaded the earlier codec. The first cutover extraction used an 8.3 TEMP alias rejected by PowerShell's provider; the long-path fixture correction passes. No guard, assertion population or mandatory command was removed. Independent fixture configurations remain explicit. No production/authentication/settings write or external security test occurred.

Implementation is coherent and Resume Step DONE for the one required timed/watched Finish on this committed boundary. Acceptance/Review boxes remain unchecked until that final verification and independent Review. After local completion commit, prepare the exact SHA in this original checkout, retain a named pending-tail branch and the ignored evidence, and stop for owner publication with the existing publisher. Do not publish or promote as the agent. CTRL-19 and hosted security/PAT safety remain unproven/open under the owner's temporary risk acceptance.

### 2026-10-16 — final local verification

The required Finish ran once on committed implementation b868959a248225959ae7fe4c92788720f90fcf11 through run_timed.ps1 with watch_run.ps1 attached concurrently. `LOCAL_CERTIFY: READY`, exit 0, total 76.7 minutes; START conditions: Windows host DESKTOP-6J1RJ8V, PowerShell 7.6.7, 8 CPUs, concurrent=0. Full CONTROL 522 passed / 0 failed; cold-start 42/0; status-contradiction, primary-ledger and future-date guard commands PASS; repository consistency and git diff --check PASS. Full Additional receipt suite 64/0, with all seven mutations admitting the wrong behavior and restoring refusal. No required command was skipped or repeated. The suite's profile children are orchestration stubs and its gh evidence synthetic; bare Git transport and actual evaluator/publisher processes ran. Hosted acceptance, credential isolation and PAT safety are not proven by these results.

Evidence in the existing owner-review directory: spec-284-finish.log SHA-256 10a6394ceb001fd6281f3023e5e7ca436b0c7523418804aae6ea738caf550726; spec-284-control.log ff3b556f5bab68b57a68e61515668bcad8401096bebf30256e458a543f5807b2; spec-284-receipts.log 8c1dcc324109f55a9080d6fd44096f67f4035b16f11b0b94158a3241dddc1128. The watcher marked elapsed-time comparisons as hypotheses; they establish duration, not a cause or an implemented performance change.

### 2026-10-16 — local completion and owner-publication boundary

Independent Review is committed with Verdict: Confirmed Complete; all local acceptance and Review items are checked. Complete locally and synchronize the active pointer/Last Completed and generated projections. Next, capture the resulting exact SHA and prepare it through the implemented evaluator's full-SHA range Gate/binding in this original checkout, with temporary gh/Git-transport tripwires and GH tokens omitted from that one child process. These observers add no qualification logic or credential boundary. Preserve branch `orvion/spec-284-pending` and the original ignored working/retained records. The exact SHA, archive and preparation outcome are derived from Git plus the existing evaluator, never invented in this pre-commit entry. Stop for owner publication via scripts/publish_candidate.ps1; then observe exact-SHA preflight acceptance, await explicit owner promotion, and run the existing exact-SHA Certify reader before main advances. No agent publication/promotion, sandbox creation or authentication migration is authorized here. Remote certification remains unproven while those owner actions are pending.

## Verification Notes

None.

### 2026-10-16 — independent Review against live state
Verdict: Confirmed Complete

Reviewed the live implementation, full verification outputs and actual schema-2 working receipt, rather than relying on the execution narrative. All eight Acceptance Criteria and five Review Gate items are satisfied locally: original fields/digests and anchor are present; standalone Gate/binding and publisher reuse are tested; successful/failed Finish and transport preserve pending records; wrong SHA/CR/profiles/content/context and missing records fail closed; two unpublished candidates, restart, atomic recovery, ordered reader certification and checkout restoration pass; all existing CONTROL assertions remain (522/0), including SPEC-167, SPEC-281, promotion leases and ancestor proof; lifecycle/ignore/governance agree; generated state reproduces. Re-fetch observed ahead 4 / behind 0 and a clean tree. The committed diff contains only approved paths, and excluded scripts, workflows, historical contracts, master registers and pinned Batch 6 authority lines are unchanged.

The real working receipt names SPEC-284, CONTROL + REPOSITORY, finishHead b868959a248225959ae7fe4c92788720f90fcf11, target main, expected Agent Control + Repository Consistency, result READY, digest 8efcf5155e14ebbf1a10edc628e6f5030ff6ac48f458d1bdd02bd6d0212a1e10. It remains local evidence. Current-candidate binding necessarily follows its completion commit; prepare with the existing evaluator in this original checkout, preserve a named pending-tail branch and ignored records, then hand the exact SHA to the owner for the existing publisher. Publication, hosted acceptance, owner promotion and exact-SHA Remote Certification remain pending. No new architectural/business decision, authentication change or external write was introduced. CTRL-19 remains open.

## Review Gate

- [x] Every change matches the approved steps; no unrelated scope change.
- [x] All acceptance criteria hold and all required positive/negative/mutation populations are nonempty.
- [x] No existing test, guard, profile or immutable historical contract was weakened.
- [x] Original Finish evidence is retained; preparation never claims publication, acceptance or promotion, which remain separate owner actions and observations.
- [x] Repository/generated state is consistent and the candidate handoff separates LOCAL, POST_PUSH and EXTERNAL evidence.

## Notes

Baseline observed 2026-10-15: clean main, HEAD = origin/main = origin/orvion-preflight = 082d106; Boot READY/PLAN, no active CR. SPEC-283 is Complete with successful main/preflight CI; Last Completed still names SPEC-282, genuine stale metadata. Normal completion here replaces that field; no historical contract is rewritten and missing SPEC-282 evidence is never recreated.

Hypothesis decisions: ordinary-push protection PARTIALLY PROVEN (live active ruleset 22950574, acceptance source 15368, deletion/non-FF, no bypass; no hostile live-main test); candidate-first PROVEN compatible with ADR-0031; human-promotion mitigation PARTIALLY PROVEN (trusted independent evaluation helps; shared-admin enforcement remains absent), retained as owner policy; receipt collision PROVEN; extra-check benefit UNPROVEN and not earned for this unit (source already bound; no new independent issuer); reusable sandbox PARTIALLY PROVEN worthwhile locally, external behavior UNPROVEN pending owner creation; read-only MCP PARTIALLY PROVEN (official configuration exists, live write tools remain exposed; other owner CLI/Git paths persist); overnight stacking PARTIALLY PROVEN locally, enabled only for approved work after final certified tests establish the bounded sequence. No independent certification of an earlier candidate once main has moved past it.

Programme order under Integrated Directive v3: this receipt unit → minimal owner-authorized `PlatPlusHub/orvion-sandbox` → bounded manual PAT/publication/public-reader migration → explicitly authorized credential cutover. Each later implementation scope needs its own Gate 1; repository creation/settings need separate concrete owner authorization. Existing identity/authentication stays until a verified replacement and explicit cutover approval; no second account, Windows account or GitHub App. CTRL-19 remains open under the owner's temporary risk acceptance. Batch 6 stays paused. Full B1, ETA and Improvement Engine remain later work.

Pre-approval observations: push-disabled independent clones; final focused prototype: 60 assertions passed, including six mutation controls, missing-working-receipt recovery, nonterminal compatibility, exact-SHA selection, the real remote-reader function with synthetic gh responses, and C1→C2 Git plumbing against an independent bare remote. These prove mechanism/test feasibility, not final implementation, publisher integration or live GitHub enforcement. Prototype source SHA-256: `697daa1198c572de882474792d9dd6b4da5a1830bbb913775044c6bcbe41a266`. Evidence directory: `C:/Users/My Lab/Documents/ORVION-Owner-Review/guarded-autonomy-2026-10-15/`; logs `receipt-prototype-final.log` and `additional-command-prototype-routed.log` both exit 0. The Additional command was exercised on the disposable prototype harness; Step 4's final suite must instead exercise the implemented evaluator/publisher. Baseline mandatory-command results and final approval-admissibility evidence follow below.

Integrated Directive v3 review, 2026-10-16: all eight original evidence-manifest hashes match. `receipt-prototype.log` failed at GIT_UPSTREAM_MISSING before the sequence test; the final source explicitly sets the candidate branch upstream and `receipt-prototype-final.log` records 60 passes, exit 0. The failed log is a superseded fixture experiment, never a pass. No expensive baseline was rerun.

New focused evidence: `manual-sequence-prototype-final.log`, 20 passes, exit 0, 0.3 minutes; source `manual-sequence-prototype.ps1` SHA-256 `284e9fc8fcc85b6fbf059f2d97f73773c2fd573520eaa273d23be48445d8e4b0`. Fresh independent repositories, push URL disabled; proposed binding/selection functions imported from the unchanged final prototype, real Finish/writer/remote-reader functions, stubbed profile commands and synthetic gh rows. Children remove GH tokens and inherited global/system Git configuration; fixture configuration explicitly sets line-ending behavior. The probe proves local prepare-before-publication, C2 Finish with unpublished C1, failed transport/restart, original-checkout record lifetimes, missing records in a fresh clone, named-tail restoration, ordered simulated promotion/certification, stale expected-ref refusal and moved-main refusal. It does not exercise the final Gate switch/publisher integration, hosted Rulesets, PAT safety or credential isolation. Earlier probe attempts failed from function-loader parameter loss and fixture line-ending configuration; both were corrected before the final pass, with no repository implementation change.

Adversarial dispositions: future-SHA claim rejected; standalone evaluator binding adopted now; another preparation script rejected; trusted judge reused with existing 281-T/R positive, negative and mutation tests; credential-safe transport, fallback/persistence tests and public-reader capability changes adopted later at the sandbox/migration boundary. The current publisher calls checkout code and Git transport under existing authentication; no safe-PAT claim is made. The current Certify reader checks exact SHA/ref/push event, current attempt and literal success, with SPEC-263's bounded ancestor proof; it does not impose an age predicate. GitHub's current required-check documentation states a successful check in the repository during the past seven days. Hosted eligibility of older retained runs remains UNPROVEN; this CR introduces no arbitrary receipt expiry, freshness exemption or remote-reader policy change. Recheck eligibility before promotion; do not bypass a refusal. Read-only live inspection reconfirmed active ruleset 22950574, required source 15368, no bypass actors, non-FF/deletion protection, Actions default read/no PR approval, and current main/preflight workflow successes on 082d106. Public unauthenticated REST also returned those run identities successfully; full public-only Boot/Finish/Certify compatibility remains a later migration obligation.

Official behavior refreshed 2026-10-15, required-check and public workflow-run documentation rechecked 2026-10-16: [rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets), [required checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks), [workflow runs](https://docs.github.com/en/rest/actions/workflow-runs), [MCP read-only configuration](https://github.com/github/github-mcp-server/blob/main/docs/server-configuration.md). Required GitHub checks can accept skipped/neutral; the existing remote reader demands literal success. No external setting is changed by this CR.

Command feasibility observed on the unchanged 082d106 source in the independent clone: `scripts/test_agent_continuity.ps1` 522 passed / 0 failed, exit 0, 32.0 minutes, timed and concurrently watched (`baseline-control.log`). Repository consistency CLEAN, `test_cold_start_state_guard.ps1` 42/0, `test_status_contradiction_guard.ps1` 33/0, `test_primary_ledger_guard.ps1` 13/0, `test_future_date_guard.ps1` 18/0, and `git diff --check` all exited 0 (`baseline-guards.log`, 11.9 minutes; ran beside CONTROL). The final disposable approval-transition rehearsal returned `APPROVAL_EVIDENCE: PASS`, 3 of 8 criteria mechanically checkable, CONTROL + REPOSITORY + the Additional command, exit 0 (`approval-rehearsal-final.log`). This is admissibility evidence, not owner approval. Implementation certification remains unperformed.

Revised Draft admission, 2026-10-16: a fresh push-disabled independent clone, with only a simulated approval transition, returned `APPROVAL_EVIDENCE: PASS`, 3 of 8 mechanically checkable criteria, the same profiles/Additional command, repository clean, exit 0 (`approval-v3-rehearsal.log`, 0.5 minutes). The authoritative checkout's timed Gate returned READY/PLAN, no active CR, no implementation write authority, repository clean, exit 0 (`authoritative-draft-v3-gate.log`, 0.4 minutes). HEAD/main/preflight remain 082d106; only this untracked Draft changed. Local SPEC-283 legacy receipt remains untouched; no pending published candidate exists. No implementation, approval commit, push, authentication change or external mutation occurred. Next action: Human Gate 1 on this revised SPEC-284; after approval execute Step 1. The simulated approval never grants authority here.
