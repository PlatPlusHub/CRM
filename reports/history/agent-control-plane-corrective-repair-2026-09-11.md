# Agent Control Plane corrective repair

Class: 🟠 Historical-Immutable — corrective-repair record
Date: 2026-09-11
Status: Complete — independently reviewed and locally certified; exact final-SHA CI is verified after the immutable completion commit is pushed
Purpose: Preserve the evidence for SPEC-1001 without changing ORVION product or database behavior

---

## §0 HANDOFF

- **INHERITED:** `main` at starting HEAD `6fdc4af5e9930f81d6ff54fc1c4db15808559c62`, equal to fetched `origin/main`; the defective Agent Control Plane artifact conflicted with the pre-existing product SPEC-155 lineage.
- **PROVEN:** identity correction, restored authority, deterministic controls, 45/45 control tests, 34/34 cold-start tests, 33/33 status tests, 13/13 Primary-ledger tests, 5/5 future-date tests, Repository Consistency CLEAN, `git diff --check`, executable `-Finish` ending `LOCAL_CERTIFY: READY`, and exact-SHA remote runs listed below.
- **UNPROVEN:** no actual pull-request run was created; PR behavior is locally exercised through detached range-mode mutation tests. GitHub Actions is post-push verification because `main` is unprotected.
- **CHANGED:** only the SPEC-1001 Write Scope: operating-kernel authority, CR lifecycle/template contracts, control script/tests/workflow, the SPEC-155→SPEC-1000 control-plane rename, active-state manifest, generated `ai-map.json`, current report pointer, and this new report.
- **REMAINING:** branch protection is absent; local hooks remain bypassable by Git design; reasoning-hypothesis distinctness and Decision Exhaustion remain policy rather than mechanically decidable facts.
- **DO NOT TOUCH:** do not rewrite product SPEC-155 history, Git history, existing historical reports, product/database/Canon-domain surfaces, or start quotations work as part of this repair.
- **NEXT:** Decision-closure complete. Start Batch 6 Slice 12 on quotations in a NEW session.

---

## §1 Starting state and identity correction

The owner-directed repair began from `6fdc4af5e9930f81d6ff54fc1c4db15808559c62`. A repository-wide census over tracked filenames and tracked text observed maximum identifier 999 because a tracked control-test fixture used SPEC-999; the deterministic next identifiers were therefore SPEC-1000 for the existing Agent Control Plane and SPEC-1001 for this corrective repair.

The collision existed because the new control-plane CR had been assigned SPEC-155 even though SPEC-155 already belonged to commission/product history. Only `changes/SPEC-155-agent-control-plane.md` was renamed to `changes/SPEC-1000-agent-control-plane.md`; its self-identity and current manifest reference were corrected, and its original execution evidence was preserved. Pre-existing SPEC-155 product references remain unchanged. Historical commit messages were not rewritten.

## §2 Restored authority

`AGENTS.md` again owns the verbatim capability-unit and 2026-07-17 standing execution directive under §1. Current §3 again carries Earn-It, fundamental-domain structure, Routine/Significant/Owner-Decision classification, Technical Advisory Board conduct, evaluation of every proposal, the permanent Engineering Review Board, and workflow stages through the phase-transition checkpoint. Current §6 again carries the nine measurement-integrity rules, including positive fixtures, detector counterexamples, both-door testing, evidence classification, and the external-credential boundary.

The active 16-KiB failure and fixed byte ceiling were removed. Token efficiency remains subordinate to semantic authority.

## §3 Mechanical repair and evidence classes

The control script now derives CR identity from exactly one heading and validates the filename; rejects globally reused new SPEC identifiers against base Git filenames and text; rejects mutation, deletion, or rename of base Complete/Cancelled CRs; validates a local completion transition against the In-Progress HEAD version; has no production repository-guard bypass; fetches before local synchronization claims; separates detached range mode from local upstream state; validates PLAN through Repository Consistency and Git; parses multiline steps; observes GitHub capability through both `gh auth status` and `git ls-remote`; emits recovery exhaustion at attempt 3 with an active blocker; and makes `-Finish` execute mandatory and additive commands before `LOCAL_CERTIFY: READY`.

The GitHub workflow resolves actual push/PR ranges, uses the actual PR head and merge base, runs the mutation suite before Gate, and passes neither an upstream assumption nor an asserted capability.

Cases 1–43 of `scripts/test_agent_continuity.ps1` are behavioral attacks. Cases 44–45 are explicitly structural policy-anchor checks and do not claim to prove reasoning quality. Distinct recovery hypotheses and Decision Exhaustion remain human/agent execution policy, not mechanical invariants.

## §4 Local verification

The full `-Finish` path was rerun after the authorized cross-platform fixture repair. A later completion-draft Gate exposed the missing local completion-transition path; that exact defect was repaired and attacked in case 32, then `-Finish` was rerun again from the beginning and returned exit 0 with final line `LOCAL_CERTIFY: READY`. It executed the scope-derived profiles and every Additional Verification command. Observed results were control 45/45, cold-start 34/34, status contradiction 33/33, Primary ledger 13/13, future date 5/5, Repository Consistency CLEAN, and clean diff checks.

## §5 Commits, pushes, and remote results

The owner-directed sequence is preserved without amend, squash, force-push, or history rewrite:

- `66eaea6` — activated SPEC-1001.
- `dfcb44a` — corrected the control-plane identity to SPEC-1000.
- `5d78aacd5335278c5b03edb0b3f969bd86e6b9c4` — repaired authority, enforcement, tests, and workflow. Repository Consistency succeeded; Agent Control failed because the disposable Ubuntu hook working file lacked its executable bit.
- `e2b975ac98d5619a550a48db79437194370b4636` — repaired the cross-platform test fixture inside scope. Agent Control succeeded; Repository Consistency did not trigger for that path-filtered push.
- `7b2749aa3aee186100c91d697d9aa9d67e84afbf` — synchronized the failure/repair evidence. Agent Control run `34575651067` and Repository Consistency run `34575651015` both succeeded for this exact In-Progress SHA.
- `SPEC-1001: complete Agent Control Plane corrective repair` — the single completion commit containing this immutable report; both workflows are verified separately against its exact SHA after push.

## §6 Unchanged surfaces and enforcement limit

The baseline-to-completion changed-path audit contains no path under `supabase/`, `reports/master/`, `reports/evidence/`, or `.workstation/`; no Canon file other than `_ORVION_CANONICAL/manifest.md`; and no pre-existing history report. Product/database behavior, the execution roadmap, Governance, coding standards, workstation/bootstrap files, hooks, MCP/dependency files, and product SPEC-155 artifacts remain unchanged.

`main` reported `protected: false`. Hard direct-push prevention is not provided by branch protection. Agent Control and Repository Consistency provide post-push remote verification/detection. The existing local pre-commit hook is useful but bypassable by Git design.

## §7 Next product capability

Decision-closure complete. Start Batch 6 Slice 12 on quotations in a NEW session. This repair did not start Slice 12.
