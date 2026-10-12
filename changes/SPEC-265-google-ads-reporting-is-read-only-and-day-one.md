# Change Request — SPEC-265

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Integrate the owner's decision D4 of 2026-10-11 into the existing authorities: read-only Google Ads reporting and configuration visibility become a Day-1 function, and modifying Google Ads from ORVION is excluded. The edits are canon 01, 18 and 32, ADR-0030, `MASTER_INTEGRATION_CATALOG.md §5`, register row GADS-1 and two readiness-gate placements (GADS-1 and the already-open PAY-9).

## Business Reason

- **The decision.** On 2026-10-11 the owner decided D4:
  - ORVION does not modify Google Ads campaigns, budgets, keywords, bidding, targeting or account settings; every change stays in the official Google Ads interface;
  - read-only Google Ads reporting and configuration visibility are required for the first production release, wherever official Google APIs support them;
  - advertising cost and performance must meet ORVION's CRM, bookings, payments and management profitability, with attribution uncertainty shown and no duplicate expense;
  - no mutation workflow, no approval flow for advertising changes and no campaign editor is built;
  - the Data Manager offline-conversion integration stays a separate, existing requirement.

  The owner asked for this to reach the roadmap and the authoritative scope through the governance process. The decision is a product-scope decision, not authorization to create credentials, deploy code or modify Google Ads.
- **Where it lands.**
  - Canon 01 holds the Day-1 functions that the readiness gate reads, so the capability must be named there or the gate cannot hold launch for it.
  - A new integration enters the catalog only with its decision record, hence ADR-0030 and `§5`.
  - The register gains GADS-1 so that the derived readiness population carries it.
- **Measured on 2026-10-11, read-only:**
  - Primary holds 0 tenants and 0 rows in `campaign_daily_metrics`, and no migration or function inserts into that table;
  - the n8n instance holds 0 workflows and 2 credentials, neither for the Google Ads API;
  - no client application exists.
- **Official Google documentation, read on 2026-10-11 and 2026-10-12:**
  - developer tokens were retired on 2026-09-09; Google Ads API access levels now belong to the Google Cloud project;
  - production API access needs Explorer, which is applied for, and Google rejects Explorer and Basic applications from projects whose billing is not in good standing (free trial, suspended or disabled);
  - Google Ads scripts run GAQL inside the account at no cost, with no application. Limits: 30 minutes per run, 20,000 URL fetches a day on a consumer account, 50 MB per fetch;
  - `change_event` reports a change made by a script as client type `GOOGLE_ADS_SCRIPTS`.

  Together with the owner's rules (free and available first; no critical dependency on uncertain external approval), these facts fix ADR-0030's path:
  - a repository-held, read-only script delivers GAQL results to n8n;
  - the API's Read-only service account is recorded as the upgrade path, taken once the owner's Cloud project has billing and Explorer access;
  - the 2026-10-11 draft made the API path primary, and it was revised on 2026-10-12 before approval.
- **PAY-9.** SPEC-264 recorded it open. Today `scripts/readiness_population.ps1` exits 1, naming it as the one id the gate section does not classify. The gate section is edited here anyway to place GADS-1, so placing PAY-9 in the same edit is one row and removes a measured gap. It changes no class, no order and no criterion.

## Risks

- **Register, plan and catalog text could trip the consistency guards.** This was mitigated by prototyping every edit in an LF scratch worktree at `f6c30d0`:
  - `check_repository_consistency.ps1` returned CLEAN, and Check 25 still finds the open-decision line complete;
  - `readiness_population.ps1` reported that every derived id is named in the gate section;
  - the manifest measured 6879 of 7000 characters, with its longest line at 1143 of 1200.
- **GADS-1's gate class is a judgement.** The five classes have no name for a Day-1 function that is not built. It is placed as a VERIFIED DEFECT against canon 01, the class whose release consequence (closed before its boundary) matches the owner's intent. This is stated in the row so a reader can disagree with it.
- **The Google facts move.** ADR-0030 and `§5` record the date and the sources, and they require re-verification when the workflow is built.
- **A script's read-only property is weaker than a Google permission.** A script acts with its authorizing user's own access. ADR-0030 therefore checks it twice:
  - a repository check, owned by the implementing contract, refuses any call beyond `AdsApp.search` and `UrlFetchApp`;
  - each run reports `GOOGLE_ADS_SCRIPTS` changes from `change_event`, so a violation alarms.

  Google's scripts documentation does not list which resources a script can query, so each query is proven inside a script before it is relied on.
- **No migration, no test, no Primary write, no credential, no n8n change and no Google Ads change.**

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-265-google-ads-reporting-is-read-only-and-day-one.md`
- `_ORVION_CANONICAL/01_mvp_scope.md`
- `_ORVION_CANONICAL/18_integration_priority.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `PROJECT_CONTEXT.md`
- `_ORVION_CANONICAL/07_finance_model.md`
- `_ORVION_CANONICAL/14_finance_rules.md`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_CERTIFICATION_STATUS.md`
- `reports/future-backlog.md`
- `reports/evidence/primary-ledger-evidence.json`
- `supabase/migrations/202607043000_create_marketing_and_offline_conversion_tables.sql`
- `scripts/check_repository_consistency.ps1`
- `scripts/readiness_population.ps1`
- `scripts/generate-ai-map.ps1`
- `GOVERNANCE.md`
- `AGENTS.md`

## Required Reading

- This contract's Business Reason: the owner's decision D4 of 2026-10-11, quoted there.
- `_ORVION_CANONICAL/01_mvp_scope.md`; `_ORVION_CANONICAL/18_integration_priority.md`; `_ORVION_CANONICAL/32_execution_roadmap.md`, Phase 8's sequence and the Living Forward Plan.
- `reports/architecture-decision-records.md`: ADR-0023, the record shape from ADR-0024, and ADR-0029.
- `reports/master/MASTER_INTEGRATION_CATALOG.md` §1–§3; `reports/master/MASTER_EXECUTION_PLAN.md`, the Pre-Production Readiness Closure gate.
- `reports/master/MASTER_GAP_REGISTER.md`: the PAY-9 row and the table header.
- `scripts/check_repository_consistency.ps1`: `$registerDeciderRx` and `Get-RegisterFindingState`.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- `pwsh -NoProfile -File scripts/readiness_population.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Canon 01 gains one Day-1 integration line and one out-of-scope line | The readiness gate's Day-1 boundary; Check 16 (canonical documents asserting decisions) | WRITE | The prototype's guard is CLEAN. The lines name a decided scope, not an open decision. |
| Canon 18's Google Ads section gains reporting and the never-modify rule | Readers of the integration priority; ADR-0023 | VERIFY | ADR-0023's transport and outbox are unchanged; the text states that the two integrations share no state. |
| Canon 32 gains a Day-1 capability section | Phase 8 order (A)–(H); Check 16 | WRITE | It takes no place ahead of (C)–(H) unless the owner says so; the existing paragraph is byte-unchanged. |
| ADR-0030 is added after ADR-0029 | ADR readers; ADR-0023 | WRITE | Append-only, using ADR-0024's record shape; no earlier ADR changes. |
| Catalog §1 row and new §5 | Check 2 (cross-Master status), Check 13 (table rows), Check 26 (section pointers) | WRITE | No row leads with a finding id; the registry status reads NOT BUILT, outside both vocabularies; guard CLEAN. |
| Register: header and the GADS-1 row | Checks 2, 11, 14, 21, 25; `readiness_population.ps1` | WRITE | GADS-1 leads `OPEN`, and its Owner Decision cell is `—`, so it is not a decider and the open-decision line stays MAIL-1, PH8-10 and RET-1. The script counts 473 ids, 132 not settled. |
| Plan: header and closure-queue rows 11 (PAY-9) and 12 (GADS-1) | `readiness_population.ps1`; Check 21 | WRITE | Today the script exits 1 on PAY-9; on the prototype it exits 0. No class, order or criterion changes. |
| Manifest Last Completed; `ai-map.json` | Boot; Checks 5 and 7 | WRITE | 6879 of 7000 characters, longest line 1143. `ai-map.json` is regenerated by its generator; the guard is CLEAN after regeneration. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Repository consistency is CLEAN | BEFORE_COMPLETION | NONE | NONE | Step 6 |
| Every derived readiness id is classified | BEFORE_COMPLETION | NONE | NONE | Step 6 |

## Implementation Steps

Every file is written LF. Each SHA-256 below is of the LF form, as Git stores it, taken from the prototype at `f6c30d0` as revised on 2026-10-12. The prototype's patch is `spec265-prototype-v2.patch` in the authoring session's scratchpad. If a fresh agent lacks it, the edits are re-derived from the text of each step, and the hash decides whether they match.

1. **Check** whether `_ORVION_CANONICAL/01_mvp_scope.md` contains `Google Ads reporting and configuration visibility, read-only (owner decision D4, 2026-10-11)`. If absent, apply as prototyped:
   - **canon 01:** that bullet at the end of `## Integrations`, and the `Modifying Google Ads from ORVION` bullet at the end of `# Out Of Scope For MVP`. Expected SHA-256 `189a52485fc8fcd287feb5f489e4336f3a53e52fa8673de3a92b84e0c486e19c`.
   - **canon 18:** the reporting bullet in `# Google Ads And Call Tracking`, the widened purpose sentence and the never-modify paragraph. Expected SHA-256 `ac01a571d11b114c14d626febae1463cea1b89aaee55cc54764ca570a66c8e88`.
   - **canon 32:** `## Day-1 capability — Google Ads reporting, read-only (owner decision D4, 2026-10-11)` directly after the Phase 10 Living Forward Plan block. Expected SHA-256 `1338bd174b9e387e118cde9762e36fe32087f630ebef30086c81b0d4c4e17101`.

   If a target carries different content, or a resulting hash differs, stop.
2. **Check** whether `reports/architecture-decision-records.md` contains `## ADR-0030 —`. If absent, apply as prototyped:
   - **the ADR file:** ADR-0030 between ADR-0029 and `## Programme lesson numbering`. Expected SHA-256 `4c783f7d01251edae7aa98f4f2e43322a89aaa6b3558ac25990dfa880b408a00`.
   - **the catalog:** the `Google Ads reporting (read-only)` registry row directly after the Data Manager row, and `## 5. Google Ads reporting (read-only) — contract (ADR-0030)` at the end of the file. Expected SHA-256 `d72e6135d824182f1b88c371f6c9e5f677e8c86696c9576eeb016826319206a9`.

   If a target carries different content, or a resulting hash differs, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| GADS-1 |`. If absent, apply as prototyped:
   - **the register:** a new `Last updated: 2026-10-11` entry for D4, with the prior entry demoted to `Previously:`, and the GADS-1 row directly after PAY-9's. No other row changes. Expected SHA-256 `8f65e76af9c8b31c7afa5fb198e820e434293c33c4395063fce598eefded383c`.
   - **the plan:** a new `Last updated: 2026-10-11` entry, with the prior entry demoted to `Previously:`, and closure-queue rows 11 (PAY-9) and 12 (GADS-1) after row 10. Expected SHA-256 `029646d70ef5ac1f0df0e03d76e463f4b95beb9555ed0cbf8da00eca1f44a8b4`.

   If a target carries different content, or a resulting hash differs, stop.
4. **Check** whether the manifest's `Last Completed:` begins `**SPEC-265:`. If not, replace that field with the prototyped line, and change no other field. With `Active Change Request: None.` the manifest's SHA-256 is `4c77f44e91cb18d497ebefff25a57fd10c35e7f54a034c6c1bff2a672450a79e`. Then regenerate `ai-map.json` with `scripts/generate-ai-map.ps1` and store it LF.
5. **Check** for a `Steps 1-4 executed` Execution Log entry. If absent:
   - record each resulting hash and its comparison;
   - commit the implementation;
   - set `Resume Step: DONE` and commit.
6. **Check** for a `Local certification` entry. If absent, run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` on the clean committed tree and require `LOCAL_CERTIFY: READY`. Then Review, and Complete with `Active Change Request: None.`

## Acceptance Criteria

- [x] Canon 01 names read-only Google Ads reporting as a Day-1 integration and excludes modifying Google Ads; SHA-256 `189a5248…`.
- [x] Canon 18 records reporting and the never-modify rule, separate from ADR-0023; SHA-256 `ac01a571…`.
- [x] Canon 32 carries the Day-1 capability section without reordering Phase 8's (A)–(H); SHA-256 `1338bd17…`.
- [x] ADR-0030 exists after ADR-0029 with ADR-0024's record fields, and no earlier ADR changed; SHA-256 `4c783f7d…`.
- [x] The catalog carries the registry row and §5 (supported, partially supported and unavailable data; access; synchronization; how it meets ORVION's records); SHA-256 `d72e6135…`.
- [x] The register carries GADS-1, leading `OPEN` with Owner Decision `—`; no other row changed; SHA-256 `8f65e76a…`.
- [x] The plan's closure queue carries PAY-9 and GADS-1 as rows 11 and 12, and no class, order or criterion changed; SHA-256 `029646d7…`.
- [x] At Complete the manifest's SHA-256 is `4c77f44e…`, its open-decision line is MAIL-1, RET-1 and PH8-10, and `ai-map.json` is regenerated LF.
- [x] No migration, test, script, Primary object, n8n object, credential or Google Ads setting changed.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-12 — Gate 1 approval and execution started

- **Authority:** the owner's execution authorization of 2026-10-12 approves Gate 1 for SPEC-265, SPEC-266 and SPEC-267, in the order the allocation rule requires, with SPEC-265 first. For this contract it covers Draft `872babb5614703c3c52937d92afdceb684cfe3bd`, contract SHA-256 `796bf1d460cc4bb3960be52b463b9127c94e8d70ac48252e8de85b3e61d05380` (16435 bytes, LF). It authorizes no credential, Google Ads script, account change or n8n change. Approval was committed at `b73710b`, and its pre-commit Gate accepted it.
- **Verified before acting:**
  - HEAD was the Approve commit, 2 ahead of and 0 behind `origin/main` `f6c30d0`, with 0 merges, and the only worktree is the main one;
  - the committed Draft blob hashes to the approved value;
  - the prototype patch `spec265-prototype-v2.patch` (SHA-256 `1d17c97f26da6dbe215a1f25494c56d301b9f236c3eec3d69389f8d4099c2a6a`, durable copy in the owner's `ORVION-drafts-backup\2026-10-12`) applies cleanly to HEAD and touches only the eight Write Scope files Steps 1–4 name.
- **The other two approved Drafts** are held outside the working tree until their turn. The Gate counts an untracked contract file in `changes/` as an out-of-scope write of the governing contract, which refused this approval commit until they were moved.

### 2026-10-12 — Steps 1-4 executed

- Each target held its `f6c30d0` content, so every step applied. The prototype patch was applied to HEAD `9f92b38` and `ai-map.json` regenerated by its generator. Every resulting LF SHA-256 equals its pinned value:

  | File | SHA-256 | Pinned |
  | --- | --- | --- |
  | `_ORVION_CANONICAL/01_mvp_scope.md` | `189a52485fc8…` | equal |
  | `_ORVION_CANONICAL/18_integration_priority.md` | `ac01a571d11b…` | equal |
  | `_ORVION_CANONICAL/32_execution_roadmap.md` | `1338bd174b9e…` | equal |
  | `reports/architecture-decision-records.md` | `4c783f7d0125…` | equal |
  | `reports/master/MASTER_INTEGRATION_CATALOG.md` | `d72e6135d824…` | equal |
  | `reports/master/MASTER_GAP_REGISTER.md` | `8f65e76af9c8…` | equal |
  | `reports/master/MASTER_EXECUTION_PLAN.md` | `029646d70ef5…` | equal |
  | `_ORVION_CANONICAL/manifest.md`, with `Active Change Request: None.` | `4c77f44e91cb…` | equal |

- `scripts/readiness_population.ps1` exits 0: 473 finding ids, 341 settled, 132 not settled; open decisions MAIL-1, PH8-10, RET-1; every derived id is named in the gate section.
- `scripts/check_repository_consistency.ps1`: `REPOSITORY CONSISTENCY: CLEAN`.
- No migration, test, script, Primary object, n8n object, credential or Google Ads setting was touched.
### 2026-10-12 — Local certification

- `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` on the clean committed tree at `fca214d` (profile REPOSITORY plus the Additional Verification command): repository consistency PASS, `git diff --check` PASS, `scripts/readiness_population.ps1` PASS, `LOCAL_CERTIFY: READY` in 0.5 min with 0 concurrent scripts.

## Verification Notes

### 2026-10-12 — Review

Re-checked against the committed tree at `fca214d`, not against the Execution Log:
- **Hashes:** each of the seven document blobs at HEAD hashes to its pinned LF SHA-256 (`189a5248…`, `ac01a571…`, `1338bd17…`, `4c783f7d…`, `d72e6135…`, `8f65e76a…`, `029646d7…`), and the manifest with `Active Change Request: None.` hashes to `4c77f44e…`.
- **Range `f6c30d0..HEAD`:** exactly the ten Write Scope paths changed. The only removed lines are canon 18's former purpose sentence, which Step 1 widens, and the register's and plan's former `Last updated` entries, each kept as `Previously:`.
  - Canon 32 and the ADR file lose no line, so Phase 8's (A)–(H) and every earlier ADR are byte-unchanged.
  - ADR-0030 sits between ADR-0029 (line 299) and `## Programme lesson numbering` (line 383).
- **Register:** GADS-1 leads `OPEN` with Owner Decision `—`; no other row changed.
- **Plan:** rows 11 (PAY-9) and 12 (GADS-1) were added after row 10; no class, order or criterion changed.
- **Manifest:** the open-decision line is still MAIL-1, RET-1 and PH8-10, and `ai-map.json` is the generator's output.
- **Nothing else touched:** no migration, test, script or workflow changed. No Primary, n8n, credential or Google Ads call was made.
- **Checks:** `readiness_population.ps1` exits 0, repository consistency is CLEAN, and `LOCAL_CERTIFY: READY`.

Verdict: Confirmed Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **Not authorized by this contract:**
  - creating any Google credential, webhook secret or service account;
  - writing or installing a Google Ads script, or applying for API access;
  - running a Google Ads query;
  - building the n8n workflow, a migration or a screen.

  Those follow ADR-0030's order. Nothing needs provisioning, buying or applying for before the build (`MASTER_INTEGRATION_CATALOG.md §5.2`).
- **The other eight proposals** of the 2026-10-11 assessment (finance scope, revenue policy, reporting currency, login, legacy data, recovery targets, salary visibility, sequence exceptions) are not recorded here. They remain undecided.
