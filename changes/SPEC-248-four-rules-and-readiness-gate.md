# Change Request — SPEC-248

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Integrate the owner's 2026-10-08 directive (GitHub issue 3) into the existing authorities:
- the four decision rules go into `AGENTS.md §2` and `ENGINEERING_METHOD.md §2`;
- the Pre-Production Readiness Closure gate and its first derived classification go into `MASTER_EXECUTION_PLAN.md`;
- SUB-4 is scheduled as the next correction.

## Business Reason

- **The directive.** On 2026-10-08 the owner ordered that ORVION be fit for its declared Day-1 business functions: no known material defect affecting an enabled Day-1 workflow may be deferred silently or marked launch-ready. It also requires:
  - every nonterminal item to carry an owner, a trigger, and a bounded fix or a fail-closed release condition;
  - the readiness population to be derived from the whole register and the surface dispositions, never hand-picked.

  The work must be integrated into the existing authorities, with no second roadmap and no second inventory.
- **The four rules.** LEARN BEFORE GUESSING → EARN IT → WORTH IT → SIMPLIFY IT WITHOUT WEAKENING.
  - Earn-It already exists as the governing meta-principle (`ENGINEERING_METHOD.md §2`, `AGENTS.md §2`).
  - Learn-Before-Designing already exists as workflow stage 2, scoped to decisions where research "materially helps".
  - The directive extends Learn-Before-Designing to small decisions, and names WORTH IT and SIMPLIFY IT WITHOUT WEAKENING. WORTH IT is already the register's practice (MONEY-3, CTRL-3) but is defined nowhere.

  So the change adds one kernel anchor and one definitions block, and widens stage 2 by one sentence. No procedure is duplicated.
- **No readiness gate exists today.**
  - `MASTER_CERTIFICATION_STATUS.md` rates product launch readiness 🟡 CONDITIONAL on prose conditions.
  - Batch 6's EC-1…EC-11 decide when the batch is complete, not whether a release is ready.
  - Nothing derives the open population.
- **Measured at `523888d`.** The register holds 439 distinct finding ids under its own finding pattern. 320 open with the settled vocabulary that `scripts/check_repository_consistency.ps1` declares once for Checks 2, 14 and 25, and 119 do not:
  - 101 open with the open vocabulary;
  - 8 carry a form outside both vocabularies;
  - 10 exist only as `###` blocks.

  `MASTER_SURFACE_DISPOSITION.md` records 18 `AUDITED-OPEN` and 3 `PARTIAL` surfaces. The manifest names MAIL-1, RET-1 and PH8-10. The prototype classifies every one of the 119 exactly once, checked by script, and RET-1 joins from the manifest line.
- **SUB-4.** It is a reproduced subscription-transition race (SPEC-247): the Platform Owner's transition judges canon 26 on a state read before the row lock, so a racing redemption yields an `active → suspended` move canon does not allow, recorded under a stale from-state. The owner prefers a focused correction ahead of Batch 6 Slice 35, while the runtime functions and the scenario are current. That is a recorded exception to the selector's ranking, never a silent one.

## Risks

- **Governance and register text could trip the consistency guards.** Mitigated: every edit was prototyped in an LF scratch worktree at `523888d`.
  - `check_repository_consistency.ps1` returned CLEAN. The cross-Master status agreement covered 101 open ids with no contradiction, and the open-decision line kept 3 ids.
  - The control suite passed 331/0, and the four CI guard suites passed 34/0, 18/0, 13/0 and 33/0.
  - The manifest measured 6871 of 7000 characters (about 6915 with this contract as the active pointer). Its longest line measured 1193 of 1200.
- **The classification could be read as a second status.** The gate section has no `Status` column, and no table row in it leads with a finding id. It also states that the register wins wherever the two differ.
- **The classification is a judgement.** It is recorded as a dated reading, and every evaluation re-derives it.
- **Identity.** The SUB-4 correction is never named by number here; it is referred to only by subject.
- **No migration, no test, and no Primary access.**

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-248-four-rules-and-readiness-gate.md`
- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_CERTIFICATION_STATUS.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-247-an-activation-code-carries-the-platforms-current-decision.md`
- `supabase/migrations/20261008170000_an_activation_code_carries_the_platforms_current_decision.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `reports/future-backlog.md`
- `_ORVION_CANONICAL/01_mvp_scope.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `CR_LIFECYCLE.md`
- `PROJECT_CONTEXT.md`
- `README.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/generate-ai-map.ps1`

## Required Reading

- GitHub issue 3 in `PlatPlusHub/CRM`, the owner's directive of 2026-10-08
- `AGENTS.md` §2–§3; `ENGINEERING_METHOD.md` §1–§2; `GOVERNANCE.md` §2 and §15; `CR_LIFECYCLE.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6's method and exit criteria
- `reports/master/MASTER_GAP_REGISTER.md`: the whole register, through the derivation, including its Legend, five-state table and the 2026-09-04 census and reconciliation
- `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_CERTIFICATION_STATUS.md`
- `_ORVION_CANONICAL/01_mvp_scope.md`; `_ORVION_CANONICAL/32_execution_roadmap.md`, Phase 8's execution sequence
- `scripts/check_repository_consistency.ps1`: `$idPat`, `$statusOpenLead`, `$statusResolvedLead` and `Get-RegisterFindingState`
- `changes/SPEC-247-an-activation-code-carries-the-platforms-current-decision.md`, SUB-4's reproduction

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

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
| `AGENTS.md §2` gains the four-rules anchor; `§3` routing names the rules | Boot routing; `test_agent_continuity.ps1` assertions 44–45; Check 27 | VERIFY | The Earn-It bullet and every existing anchor are unchanged; the new bullet routes to `ENGINEERING_METHOD.md §2`. On the prototype, `test_agent_continuity.ps1` passed 331/0, and the four CI guard suites passed 34/0, 18/0, 13/0 and 33/0. |
| `ENGINEERING_METHOD.md`: header sentence, the four-rules block in §2, one sentence in stage 2 | Check 27 anchors; assertion 44 (`Governing meta-principle — Earn-It`, `Fundamental Domain Structure vs Feature Implementation`, `Learn-Before-Designing`, `Phase-transition checkpoint`) | VERIFY | Every anchor string is preserved. The header no longer claims "nothing in this document is new", which the new block would make false. |
| `GOVERNANCE.md` v1.17: changelog line and §2 execution-plan row | Check 21 (version line); §15 lifecycle | WRITE | PATCH. The row names the gate the plan owns; no SSOT is reassigned. |
| `MASTER_EXECUTION_PLAN.md`: header and the gate section | Check 2 (cross-Master status), Check 13, Check 21 | WRITE | No `Status` column, and no row leads with a finding id; EC-1…EC-11 are byte-unchanged. |
| `MASTER_CERTIFICATION_STATUS.md`: header, launch-readiness basis, history entry | Check 2 (status cell); Check 21 | WRITE | The launch row stays 🟡 CONDITIONAL; only its basis points to the gate. |
| Canon 32 step (B) | Check 16; Phase-8 readers | WRITE | One clause records the SUB-4 exception and the gate's evaluation points. Order (A)–(H) is unchanged. |
| Register: header and the SUB-4 row | Checks 2, 11, 14, 21, 25 | WRITE | SUB-4's status lead stays `OPEN`. Its Owner field stays `engineering: …`, with no decider, so the open-decision line is unaffected. No other row changes. |
| Manifest Current Module, Next capability, Last Completed and the Active pointer; `ai-map.json` | Boot `NEXT_CAPABILITY`; Checks 5, 7, 25; `test_cold_start_state_guard.ps1` | WRITE | The open-decision line stays MAIL-1, RET-1 and PH8-10, so the cold-start pin of 3 holds. The manifest is 6871 at Complete. `ai-map.json` differs only in `generated_at`, `last_completed`, `next_capability` and, during execution, `active_change_request`. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Repository consistency is CLEAN | BEFORE_COMPLETION | NONE | NONE | Step 4 |
| `ai-map.json` matches its generator | BEFORE_COMPLETION | NONE | NONE | Step 4 |
| The CONTROL suites pass | BEFORE_COMPLETION | NONE | NONE | Step 4 |

## Implementation Steps

Every file is written LF. Each SHA-256 below is the prototype's at `523888d` with `Active Change Request: None.`; only the manifest differs during execution, by that one line.

1. **Check** whether `AGENTS.md` contains `**Four decision rules (owner-ratified 2026-10-08):**`. If absent, apply exactly as prototyped:
   - **`AGENTS.md`:** the four-rules bullet directly after the Earn-It bullet in §2. In §3 "Decision and architecture discipline", the owned list begins "the four decision rules, Earn-It, …". Expected SHA-256 `e6f68e3067eb6d1fe3afc734dfc14b2f9968ba07666096a45530d8deefe7db32`.
   - **`ENGINEERING_METHOD.md`:**
     - The header sentence "Nothing in this document is new. …" becomes "Every rule below is owner-ratified. The rules first ratified in `AGENTS.md` were relocated verbatim (2026-09-11, `SPEC-163`), …; a rule added here since carries its own ratification date."
     - The `Four decision rules (owner-ratified 2026-10-08)` block follows the Earn-It meta-principle paragraph in §2.
     - Stage 2 ends with the sentence applying it to small decisions as LEARN BEFORE GUESSING.

     Expected SHA-256 `a2b478cacf98ab7e89052e63c7d51f5e723830ce3c4bba6b5eab7dd8e4a5cb79`.
   - **`GOVERNANCE.md`:** `Version 1.17 · 2026-10-08`, the v1.17 changelog line first in the changelog, and the §2 row "Execution batches/sequencing, and the **Pre-Production Readiness Closure gate** …". Expected SHA-256 `306ee2c206ab2e5f36c8bc0f81b031f0024499d1d785ac1d3fa31abd6f8f2e86`.

   If a target carries different content, or a resulting hash differs, stop.
2. **Check** whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `## Pre-Production Readiness Closure gate (owner directive 2026-10-08)`. If absent, apply exactly as prototyped:
   - **The plan:**
     - a new `Last updated: 2026-10-08` entry, with the prior one demoted to `Previously:`;
     - the gate section directly before `## Tooling / environment enablement`. It holds:
       - the derivation rule, the five classes and the five READY criteria;
       - the first derivation, 439 / 320 / 119 at `523888d`;
       - the ten-item closure queue, SUB-4 first;
       - business policy, external and legal dependencies, accepted residuals, terminal-in-substance, future-only, and the surfaces;
       - the owner's order.

     Expected SHA-256 `3c863b1498c594e3f4a03355c0e7c4e3d607fdbbd63d1667981bb2c8bcfe6e4a`.
   - **`MASTER_CERTIFICATION_STATUS.md`:** a new `Last updated: 2026-10-08` entry with the prior demoted; the launch-readiness basis gains the gate sentence; a 2026-10-08 entry first in the history. Expected SHA-256 `b40545c380c9762b74b22b107126d74c726c91863867b21cd95f67617373ea63`.
   - **`_ORVION_CANONICAL/32_execution_roadmap.md`:** step (B) gains the SUB-4 exception and the gate's evaluation points. Expected SHA-256 `c708743d6565a34826a46d0ac7c6efb4801c15a7357423646e3081257159b6ab`.
   - **`MASTER_GAP_REGISTER.md`:**
     - a new `Last updated: 2026-10-08` entry with the prior demoted;
     - SUB-4's status cell gains its 2026-10-08 schedule sentence, its lead unchanged;
     - its Owner field becomes `engineering: the next correction, ahead of Batch 6 Slice 35 (owner directive 2026-10-08), …; it must close before the first production subscription`.

     No other row changes. Expected SHA-256 `43e7c9ccfe78a9a2b138e401b528a623e028d76f0dc62df939664a271230a371`.

   If a target carries different content, or a resulting hash differs, stop.
3. **Check** whether the manifest's `Next capability:` begins `**the SUB-4 correction**`. If not, set the three fields exactly as prototyped:
   - Current Module: Batch 6 by the 2026-10-07 order, with the SUB-4 correction preceding Slice 35;
   - Last Completed: this contract;
   - Next capability: the SUB-4 correction, then Batch 6 Slice 35 re-selected by the selector, then the readiness gate. The text after `then` is unchanged.

   Keep the open-decision line unchanged, the file within 7000 characters and every line within 1200. Regenerate `ai-map.json` with `scripts/generate-ai-map.ps1` and store it LF. With `Active Change Request: None.` the manifest's SHA-256 is `55bafc4b04038835ce1903d6769b3ad7190229e6affb9a252187e1580e969df0`.
4. **Check** for a `Steps 1-3 executed` Execution Log entry. If absent:
   - Run `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` (CLEAN), the five CONTROL suites (`test_agent_continuity.ps1`, `test_cold_start_state_guard.ps1`, `test_status_contradiction_guard.ps1`, `test_primary_ledger_guard.ps1`, `test_future_date_guard.ps1`, each exit 0) and `git diff --check`.
   - Re-run the derivation against the edited register, and confirm that the 119 ids are each placed exactly once in the gate section.
   - Record the results and hashes, and commit the implementation.
5. **Check** for a `Local certification` entry. If absent, run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` on the clean committed tree and require `LOCAL_CERTIFY: READY`. Then Review, and Complete with `Active Change Request: None.`

## Acceptance Criteria

- [ ] `AGENTS.md` §2 carries the four-rules anchor routed to `ENGINEERING_METHOD.md §2`, and §3 routes to them; SHA-256 `e6f68e30…`.
- [ ] `ENGINEERING_METHOD.md` §2 defines LEARN BEFORE GUESSING, EARN IT, WORTH IT and SIMPLIFY IT WITHOUT WEAKENING; stage 2 applies Learn-Before-Designing to small decisions; every Check 27 and assertion-44 anchor survives; SHA-256 `a2b478ca…`.
- [ ] `GOVERNANCE.md` reads Version 1.17 · 2026-10-08, with its changelog line and the §2 row; SHA-256 `306ee2c2…`.
- [ ] `MASTER_EXECUTION_PLAN.md` carries the gate: the derivation rule, five classes, five READY criteria, the first derivation (439 / 320 / 119) placing each of the 119 exactly once, the closure queue with SUB-4 first, and the owner's order; EC-1…EC-11 are unchanged; SHA-256 `3c863b14…`.
- [ ] `MASTER_CERTIFICATION_STATUS.md`'s launch-readiness row stays 🟡 CONDITIONAL and points to the gate, with a 2026-10-08 history entry; SHA-256 `b40545c3…`.
- [ ] Canon 32 step (B) records the SUB-4 exception and the gate's evaluation points; SHA-256 `c708743d…`.
- [ ] The register's SUB-4 row is scheduled, its lead still `OPEN` and its Owner field still decider-free; no other row changed; SHA-256 `43e7c9cc…`.
- [ ] At Complete, the manifest's SHA-256 is `55bafc4b…`; its open-decision line is MAIL-1, RET-1 and PH8-10; and `ai-map.json` is regenerated LF.
- [ ] No migration, test or Primary object changed, and no SPEC identity after this one is named in any changed file.
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

- **After `REMOTE_CERTIFY: READY`:**
  - GitHub issue 3 is closed with a comment linking the certified SHA and the sections that now carry its requirements.
  - The SUB-4 correction is drafted as its own contract, against the synchronized state.
  - Its Primary deployment needs a separate exact-byte Gate 2.
- **Not built here:** the SUB-4 repair, any Batch 6 slice, any register status change other than SUB-4's schedule, any guard, the n8n workflow and any Phase-8 work.
