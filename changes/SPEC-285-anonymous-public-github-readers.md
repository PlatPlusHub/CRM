# Change Request — SPEC-285

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Remove persisted GitHub authentication as a prerequisite for public evidence observation while preserving the existing evidence judgments.

## Business Reason

Public REST can read the accepted sandbox's runs and failed-job metadata while native gh readers require authentication. Reuse the existing capability registry, Certify-Remote, Inherited-Run and CI watcher; add one bounded transport/schema adapter. This reader-only step prepares a later credential separation contract without changing release authority.

## Risks

Anonymous rate limits are lower; inaccessible, malformed, incomplete or changing results must fail closed. Public job logs currently return HTTP 403 even though job metadata is readable: report the diagnostic gap and return unreadable, never use stored credentials. Exact search-cap populations are ambiguous and refused. This change neither establishes Windows isolation nor closes CTRL-19.

## Supersedes / Depends On

Depends on completed SPEC-284; preserves SPEC-167, SPEC-263, SPEC-281 and ADR-0031. Supersedes no historical contract. Replaces the unallocated external staging proposal only.

## Write Scope

- `changes/SPEC-285-anonymous-public-github-readers.md`
- `scripts/github_public_read.ps1`
- `scripts/test_github_public_read.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/test_certification_receipts.ps1`
- `scripts/watch_ci.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `.workstation/doctor.ps1`
- `scripts/watch_selftest.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/generate-ai-map.ps1`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/agent-control.yml`

No authentication cutover, PAT/account/App creation, security settings, database work, production tests, historical reopening, Batch 6, B1, ETA or Improvement Engine work. Owner launchers are already adequate and remain unchanged. Publication and promotion remain owner actions.

## Required Reading

- `AGENTS.md` §§1–3,6–8
- `ENGINEERING_METHOD.md` §§1–3
- `CR_LIFECYCLE.md` §§4–5,8–9
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`: github capability, Certify-Remote, Inherited-Run and Workflow-Expectations
- `scripts/test_agent_continuity.ps1`: capability and remote/inherited fixtures
- `scripts/watch_ci.ps1`
- `scripts/watch_selftest.ps1`
- `.workstation/doctor.ps1`: owner authentication boundaries

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- pwsh -NoProfile -File scripts/test_github_public_read.ps1
- pwsh -NoProfile -File scripts/watch_selftest.ps1
- pwsh -NoProfile -File scripts/test_certification_receipts.ps1

## Pre-Approval Evidence

Change Class: Significant

Predicates: Consumer Closure PASS; Execution-Boundary Satisfiability PASS; Permanent-Control Admission PASS; SPEC Identity Allocation PASS. Independent preparation only; this file remains Draft and grants no implementation authority.

Baseline: `ff6a8a0db2d95dd79838578470b482afbe33e1a0`, verified remote main/preflight and clean original checkout. Existing allocator `Get-SpecSequenceCursor` returned 284; `Test-SpecIdEverReserved` found SPEC-285 unreserved at that authoritative ref. No ledger or numeric-maximum allocator was introduced. Reservation must be refreshed immediately before committing the owner-approved Draft.

Source anchors (baseline Git blobs, including read-only consumers):

| Path | Baseline blob |
| --- | --- |
| `scripts/check_agent_continuity.ps1` | `10b5ad2342e5dcecb59852e33ce69343dd32dc7e` |
| `scripts/test_agent_continuity.ps1` | `9506234345aad402686d9ea76fe55e8f774d238c` |
| `scripts/watch_ci.ps1` | `cd7977dcd9c2f92030cdda7675fd5960ec89e55c` |
| `scripts/watch_selftest.ps1` | `144828ebdc82fa1812ca1971834b277bc9b94b31` |
| `.workstation/doctor.ps1` | `0ad69c87859646283c84e31df5732b2df1d42056` |
| `_ORVION_CANONICAL/manifest.md` | `3eda34889477b96a8d0a7023b215a2ba818e2599` |
| `ai-map.json` | `ef81fabbe3c9aa7284edf5729e6834076df787c8` |
| `repository-index.md` | `d075792a248fc781d7012cc0296fcd8bc15a47d5` |
| `scripts/generate-ai-map.ps1` | `01165b8570999b79de4d6e854cae2443256e6b64` |
| `scripts/test_certification_receipts.ps1` | `23d7ff3a4742cf0fa6d6d598083610a09d975786` |

Line histories were read for Certify-Remote, Inherited-Run and manifest bookkeeping. Inherited-Run's latest substantive authority is f724919 (SPEC-263), evaluator/fixture latest b868959 (SPEC-284), watcher b102694 (SPEC-249), watcher selftest bcbcca8 (SPEC-283), doctor e967360 (SPEC-277). No source/history patch is copied from an older contract.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Anonymous HTTP and normalization | shared adapter and dedicated tests | WRITE | Fixed public GitHub API; GET only; no gh/auth/cookies/default credentials/cache; bounded streaming, timeout and full bounded pagination; throw on unusable evidence. |
| github read capability | existing registry and fixture | WRITE | Public repository identity plus API and configuration-isolated anonymous Git probe; read access only. Local-bare fixture is explicitly not a public origin. |
| Current and ancestor run lists | Certify-Remote and Inherited-Run | WRITE | Replace transport calls only; retain receipt selection, expected set, SHA/ref/branch/event/current-attempt/literal-success, nearest ancestry and watched-path judgments. Adapter never returns READY or selects inherited evidence. |
| Existing evaluator and receipt fixtures | test_agent_continuity; test_certification_receipts | WRITE | Explicit transport stub bridges existing keyed CLI fixtures, preserving judgment assertions/mutations; actual HTTP has a separate suite. No test-only fallback in production. |
| Control classification and receipt fingerprint | Get-ControlSurface, Profiles and Implementation-Fingerprint | WRITE | Register adapter and its suite in the existing control surface; prove CONTROL classification and existing fingerprint sensitivity. Agent Control workflow has no paths filter and needs no change. |
| Active-session CI observation | watch_ci | WRITE | Same deriver/state/error-line functions; shared run/attempt/jobs/log reads; rate-limit evidence respected, at most five failed polls; inaccessible diagnostics explicit and non-successful. No rerun, repair or resident service. |
| CI watcher mutation fixtures | watch_selftest | VERIFY | Existing 57-check suite passed against adapted watcher; explicit RepoRoot resolves shared adapter when mutation copies live elsewhere. No fixture rewrite required. |
| Owner workstation authentication/readiness | doctor | UNAFFECTED | Auth status is an owner-tool warning and never the github runtime capability; gh/MCP dependencies remain legitimate for owner tools. No workstation migration is claimed or needed for public readers. |
| Owner release and certification receipts | installed launchers, publisher, promoter and retained records | VERIFY | Installed launcher SHA256 equals tested versions: Publish 100378AF9592254F7F22467AD8082E35E08C0B3E9777F9B177A8F7883232D99C; Promote 28DBC31F0A69242C3108FC8C4DF5E33110CF388D893B1B818F4906288DADC768. Reuse 26/0 plus 3/0 fixture evidence; no launcher redesign. Receipt and release mechanisms unchanged; the receipt regression suite receives only an explicit transport fixture bridge. |
| Runtime bookkeeping and projections | manifest, ai-map, repository-index | WRITE | Normal active/last-completed synchronization only; pinned Next capability unchanged; existing generator owns both projections. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Legal identity and admitted frozen contract | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Adapter, consumers and fixtures agree | BEFORE_COMPLETION | 2 | 3 | 4 |
| Generated state, scope and contract agree | BEFORE_COMPLETION | 2 | 3 | 4 |

Measured command satisfiability: the unchanged mandatory CONTROL commands all returned exit 0 in retained `spec-284-finish.log` (test_agent_continuity, test_cold_start_state_guard, test_status_contradiction_guard, test_primary_ledger_guard, test_future_date_guard); control log printed 522 passed, 0 failed. These are baseline measurements reused under the owner's instruction, not fresh verification of this prototype. The full costly CONTROL baseline was not rerun. Modified judgments were replayed in isolation: 48/0 remote/inheritance including all 15 inheritance mutations; 5/0 extra current-attempt/literal-result checks. The dedicated adapter command and existing watcher selftest were executed against the prototype. Repository consistency, generator freshness, diff checking and Draft-to-Approved local/range Gate were executed in the independent admission clone. Exact commands, outputs and source hashes are retained in the adjacent evidence directory. Future final mandatory checks remain required and are not labelled PASS before execution.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: existing registry, receipt-bound Certify-Remote, nearest-run Inherited-Run and on-demand CI watcher; existing Finish/Gate lifecycle.

Added Property: public observation has no persisted-auth prerequisite and refuses incomplete/unreadable transport evidence.

Causal Negative: the previously observed empty-gh-config native gh reader and github capability fail while anonymous HTTP succeeds. New actual HTTP proof distinguishes readable run/jobs metadata from inaccessible logs; no synthetic error is called a GitHub outage.

Positive Test Design: complete nonempty multi-page loopback populations; actual anonymous sandbox pagination/current-attempt/jobs read; original certification/inheritance functions with only transport adapted; real Git ancestry and target-ref checks; actual watcher subprocess positive polling and requested attempt; public API/native-Git capability probe.

Negative Test Design: real loopback HTTP 401/403/404/429/5xx, reset/retry headers, malformed status/JSON/content type, truncated/oversized/slow body and inaccessible port; stable count, missing/duplicate pages and search-cap ambiguity; all consumed required fields; wrong repository/run/attempt; actual watcher stops on long retry and reports inaccessible diagnostics. Actual GitHub 404 and log 403 are separate from fixture HTTP. Existing evaluator cases preserve wrong SHA/branch/event/workflow, missing/pending/non-success, moved ref, nearest-failure and changed-path refusals.

Non-Empty Population Obligation: actual sandbox run 38876025069; complete 205-row/three-page HTTP population; both accepted and rejected current-attempt and ancestor histories. No vacuous negative or fabricated production receipt.

Mutation Obligation: remove required-run schema, pagination completion and HTTP failure refusal independently; require forbidden evidence to escape, restore and prove refusal again. Preserve all 15 existing inheritance mutations and watcher mutations. Transport/schema validates shape, never establishes an independent certification verdict.

Post-Implementation Proof Obligation: final derived CONTROL and REPOSITORY commands plus all three Additional Verification commands all execute through timed/watched Finish; no reused baseline result substitutes for a final required check. Review, Complete and retained exact-SHA candidate preparation follow existing lifecycle; owner publication/promotion and remote certification remain separate.

## Implementation Steps

1. Check legal SPEC-285 allocation at the refreshed authoritative base and compare touched source blobs to the baseline anchors above. Check the owner's approval binds this exact Draft. If the source base has changed materially, stop and refresh the affected evidence before implementation. Do not reinterpret the independent clone's simulated Approved commit as owner approval.
2. Check for the proven adapter and consumer calls; otherwise implement the bounded anonymous transport/schema adapter and replace only github read capability and run/attempt/jobs/log transports in the evaluator and watcher. Preserve existing judgments verbatim outside the transport/failure-message blocks. Paginate to declared count with unique rows, consistent counts and a result bound below 1000; refuse cap ambiguity, contradictory next links and any incomplete page. Stream at most 16 MiB, bound headers/body by timeout, refuse API redirects; signed log redirects are HTTPS to approved GitHub log-storage hosts only. Register the adapter and its dedicated suite in Get-ControlSurface so later changes derive CONTROL; the existing receipt fingerprint must observe scoped adapter bytes. Use no credential fallback, persisted evidence cache or new verdict authority. Expose current-attempt fields unchanged; preserve expected workflow derivation and receipt authority. Watcher respects retry/reset evidence and returns unreadable for unavailable diagnostics.
3. Check for the explicit test transport bridge and focused cases; otherwise adapt the existing evaluator and receipt-suite transport fixtures without deleting assertions, add dedicated real-HTTP/negative/population/mutation tests and watcher subprocess cases, and retain the existing watch_selftest unchanged. Run the focused probes, synchronize the contract/manifest within normal lifecycle authority, and regenerate ai-map.json and repository-index.md with the existing generator. No doctor or owner-launcher change.
4. Check scope, generated freshness and clean coherent commits. Run timed Finish with the watcher concurrent, including every derived mandatory check and all three additions on final implementation; complete independent Review and synchronization only after success. Prepare the retained exact-SHA candidate locally. Stop for the owner's existing two-command release; the agent observes CI and certifies through existing authorities only. CTRL-19 remains OPEN.

## Acceptance Criteria

- [x] Anonymous transport fixtures preserve all consumed run/attempt/jobs fields and yield complete bounded observations without credential fallback.
- [x] Inaccessible, rate-limited, malformed, oversized, timed-out or incomplete evidence cannot produce a successful observation.
- [x] Existing certification, inheritance and watcher judgments retain expected workflow, SHA, branch, event, current-attempt, target-ref, nearest-run/path and literal-success behavior.
- [x] Public capability probe and evaluator fixture agree on read readiness without asserting write authority or isolation.
- [x] Owner launchers, publisher, promoter, receipt formats, Human Gates and historical contracts remain unchanged.

## Execution Log

None.

### 2026-10-16 — Gate 1 approval recorded

Owner explicitly approved frozen Draft SHA256 05FD9912A6E097CF4227E79568DE0A26CC46E75101C4AAAFF0B75FDF3917CE2F at baseline ff6a8a0db2d95dd79838578470b482afbe33e1a0. Immediately revalidated hash, all ten source anchors and refreshed origin/main; allocator cursor 284 and SPEC-285 unreserved before Draft allocation 6ff5745. No implementation performed before this transition. CTRL-19 remains OPEN.

### 2026-10-16 — Implementation checkpoint (Codex)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: refreshed authoritative baseline and all ten blob anchors matched; exact owner-approved Draft allocated as 6ff5745 and approval recorded as bf9bd68 after APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: installed reviewed anonymous bounded GET/schema adapter, existing github capability and evaluator/watcher read calls; registered adapter/test in existing CONTROL surface. Existing certification/inheritance bodies change only transport and read-error text. No authentication fallback, new verdict authority or receipt/release changes.
- Step 3 Applied: explicit transport-only bridges preserve existing judgment/receipt fixtures; dedicated real HTTP, pagination, failure and mutation cases plus current-attempt literal-result assertions installed. watch_selftest, doctor and owner launchers unchanged. Generated projections synchronized.
- Step 4 implementation checkpoint: Resume Step DONE; fresh timed/watched Finish, independent Review, Complete and candidate binding remain next. Pre-approval measurements are not final verification. CTRL-19 remains OPEN.

### 2026-10-16 — Local completion (Codex)

Outcome: Complete

Step 4 Applied: fresh timed/watched Finish returned LOCAL_CERTIFY: READY (all mandatory and additional commands exit 0); independent live-state Review recorded in d7d33b2. No new architecture or out-of-scope change. Manifest active pointer cleared, Last Completed synchronized, projections regenerated. Exact-SHA local candidate binding follows this completion commit through the existing Gate; retain the named pending-tail branch and original checkout/receipts. Owner publication/promotion and post-promotion remote certification remain separate. CTRL-19 remains OPEN.

## Verification Notes

None.

### 2026-10-16 — Independent live-state Review (Codex)

Verdict: Confirmed Complete

Findings:
- Rechecked the final source and live Git scope rather than relying on the Execution Log. All six implementation/test files equal the reviewed prototype bytes; only approved paths differ from baseline. The original Draft allocation stores exact approved blob e135e6bea47669bfbf404b94c3e4091384732611. Frozen authority remains unchanged.
- Fresh timed/watched Finish on implementation 22909fdeb2f72df05a4a02ee22a5b7d3c34e18dd returned LOCAL_CERTIFY: READY and exit 0. Every CONTROL command (agent continuity, cold-start, status contradiction, primary ledger, future date), REPOSITORY command (consistency, diff check), and all three Additional Verification commands passed in that single run. Evidence: C:/Users/My Lab/Documents/ORVION-Owner-Review/guarded-autonomy-2026-10-15/spec-285-finish.log. Finish printed 00:56:08; START recorded pwsh 7.6.7, 8 CPUs, concurrent=0. No SPEC-284 measurement substitutes for these results. Successful child output is suppressed by the existing runner, so no unprinted assertion count is claimed.
- Anonymous schema/transport positives, complete three-page population, malformed/inaccessible/rate/size/timeout refusals, watcher subprocess gaps and three mutation/restoration cases are covered by the fresh adapter suite using real loopback HTTP. This is not a claim of a real GitHub rate-limit event. Current-attempt literal results and all existing certification/inheritance mutations remain in the fresh full evaluator suite. The fresh receipt suite exercises actual evaluator/publisher processes with synthetic transport and stubbed profile children, not production release.
- Independently inspected evaluator diff: 105 functions identical; changed functions are Get-ControlSurface and the transport/error blocks of Inherited-Run and Certify-Remote. Existing receipt selection/fingerprint/format, workflow deriver, ancestry/path, exact-SHA/branch/event/current-attempt/literal-success judgments are preserved. Watcher contract/state/error-selection functions are identical. No new verdict authority, authenticated fallback or success from an unreadable log was introduced.
- Fresh live public capability Review returned PUBLIC_CAPABILITY: PASS via anonymous API and configuration-isolated native Git; evidence: adjacent spec-285-public-capability-review.log. This proves read readiness only, not write permission or Windows credential isolation. HTTP job-log 403 remains unreadable and is covered by fail-closed fixtures.
- Publisher, promoter, workflows, watch_selftest, doctor, governance and historical contracts are unchanged. Installed Owner-Publish and Owner-Promote hashes still equal the frozen tested hashes. The retained SPEC-284 exact-SHA receipt hash remains CF7E9C623C536A034987AEA6A88B6573A78B377B894951F0BC238BC081371E5D. CTRL-19 remains OPEN.
- Watcher duration comparisons are hypotheses only; their cause is UNPROVEN. No failure cause, retry, repair or new architecture is inferred from timing. No implementation discrepancy found; all five Acceptance Criteria and four Review Gate items confirmed.

Recommendation: Complete under the existing approved architecture, then bind the exact candidate locally; publication and promotion remain owner actions.

## Review Gate

- [x] Exact approved steps and exhaustive scope independently confirmed.
- [x] Every acceptance criterion confirmed against final local evidence.
- [x] Mandatory profiles, additional suites, generated state and Git checks pass through fresh Finish.
- [x] Existing evidence/release authorities preserved; CTRL-19 remains OPEN.

## Notes

Preparation evidence is not implementation certification. Sandbox protection/refusal/recovery tests and owner launcher fixtures are reused without reruns. GitHub run-list JSON represents the current attempt; no old-attempt selection or success preference is introduced. API search-cap and concurrent-population ambiguity fail closed rather than silently truncating inheritance. Real GitHub job-log 403 is preserved as an observation gap, not reclassified as a cause or repaired by authentication.

Official sources refreshed narrowly: https://docs.github.com/en/rest/actions/workflow-runs ; https://docs.github.com/en/rest/actions/workflow-jobs ; https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api . Documentation advertises public log access; the observed 403 controls runtime behavior. PowerShell preparation runtime: 7.6.7; the adapter uses ConvertFrom-Json -DateKind String to preserve ISO field strings.
