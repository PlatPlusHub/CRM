# ORVION — COLD-2: The Handoff Field No Guard Compared

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-02
Author: Claude Opus 5
Status: Complete. Repository-only; **no migration, no database change, no deployment**.

---

## 1. Discovered

`scripts/check_repository_consistency.ps1` **Check 7** exists to keep `ai-map.json` — the machine-readable cold-start map — honest against `_ORVION_CANONICAL/manifest.md`. `scripts/generate-ai-map.ps1` extracts **four** live-state fields from the manifest. Check 7 compared **three** of them.

The uncompared one was `live_state.active_change_request`, and it is not an arbitrary fourth field. It is the field the boot sequence **branches on**:

- `AGENTS.md §4` Stage A **step 4** — *"If `Active Change Request` is not `None` — read that `changes/SPEC-*.md`; its own Minimum Reading List takes over from here."*
- `AGENTS.md §4` Stage A **step 5** — *"If it is `None` — read `32_execution_roadmap.md`…"*
- `AGENTS.md §6` — *"Handoff happens through `changes/*.md` and the manifest's `Active Change Request` field — **never through chat**."*
- `CR_LIFECYCLE.md §9` — `Approve` sets it, `Complete` clears it. It is the entire agent-to-agent handoff mechanism.

So the one live-state field with a *control-flow* consequence for a fresh session was the one field with no comparison behind it.

**It also has a recorded forgetting history.** Clearing this field on `Complete` was omitted twice — SPEC-024 and SPEC-027 — and `reports/future-backlog.md` still carries the resulting "Process safeguard for Complete-sync" row. The repository already knew this field gets forgotten and had never mechanised anything against it.

**And the same check had already failed this way once, unrecorded.** Commit `4b67d3f` (2026-09-01) repaired Check 7's `last_completed` comparison, which had been gated on `Last Completed:\s*SPEC-[0-9]+` and was therefore **inert for roughly forty commits** after the field stopped naming a SPEC id. That repair shipped with no register row, no report and no health-document update — so the repository held the fix but not the knowledge. This report registers both halves as one class, **COLD-2**.

## 2. Proven — before anything was changed

Two mutations, each touching exactly one side, guard run at the current implementation:

| # | Mutation | Manifest said | ai-map said | Guard |
|---|---|---|---|---|
| 1 | `ai-map.json` only | `None.` | `changes/SPEC-999-a-change-request-that-does-not-exist.md` | **CLEAN, exit 0** |
| 2 | manifest only | `changes/SPEC-999.md` | `None.` | **CLEAN, exit 0** |

Mutation 1 is a cold-start agent sent to read a Change Request that was never approved and does not exist on disk. Mutation 2 is a cold-start agent that **silently skips the work actually in flight** and goes to the roadmap instead. Both were invisible. This is `REPOSITORY`-class evidence: files only, no database touched.

## 3. Root cause

Check 7 was built field-by-field as each drift was *observed*, not derived from what the generator actually emits:

| Field | Comparison added | Trigger |
|---|---|---|
| `phase` | 2026-07-17 (INC-2) | observed drift |
| `next_capability` | 2026-08-17 | observed drift — a superseded Phase-8 objective |
| `last_completed` | 2026-09-01 (`4b67d3f`) | observed drift — repaired after being inert ~40 commits |
| `active_change_request` | **never** | **never observed drifting, therefore never guarded** |

Every comparison in that table was written *after* its field had already drifted in production. `active_change_request` had not yet drifted visibly, so nothing was written — the guard's coverage was a record of past incidents rather than a statement about the artifact's contract. That is the same family as **GOV-4** (Check 2's id pattern, blind to every id minted after it was written) and **MEAS-1** (a detector reading function bodies, blind to codes carried in trigger arguments): *a guard written against the first instance takes that instance's shape.*

## 4. Fixed

One comparison block added to Check 7, using the **identical extraction/normalisation contract** as `last_completed` — the value extracted exactly as `generate-ai-map.ps1`'s `Get-Field` extracts it (single line, trimmed), whitespace collapsed so reflowing cannot cry wolf while a real change of content fails loudly.

- **No new mechanism.** It is the existing by-value comparison, applied to a fourth field.
- **No maintained list of SPEC ids.** The comparison is by value and is equally active for a real SPEC path and for `None.`
- **No broadening.** No other `ai-map` key was brought under comparison — proven below (H4).

Check 7 now covers **every live-state field the generator extracts from the manifest**, which is a statement about the generator's contract rather than about which drifts have happened to be noticed.

### The limit, stated rather than left to be assumed

This comparison catches **divergence between the manifest and ai-map, from either side**. It does **not** detect a missed clear-on-Complete: a manifest still naming a finished SPEC, with `ai-map.json` regenerated to agree, is CLEAN here and always will be. That is a different invariant — *is the named CR still open?* — and it remains **unguarded**, tracked in `reports/future-backlog.md` and `GOVERNANCE.md §11`. The script comment says so at the point of implementation, because a guard whose description outruns its measurement is the exact class this programme keeps re-finding (**PAR-3**, **SEC-1b**, **VER-1**, **MEAS-2**).

## 5. Attacked before trusted — 14 runs

Each run reports the four Check-7 sub-comparisons **separately**, so field isolation is measured rather than assumed.

| # | Case | Expected | `phase` | `acr` | `last` | `next` | Verdict |
|---|---|---|---|---|---|---|---|
| A | Baseline, untouched | CLEAN | 0 | 0 | 0 | 0 | CLEAN ✅ |
| B | Manifest ACR mutated **alone** | FAIL | 0 | **1** | 0 | 0 | 1 issue ✅ |
| C | Restore | CLEAN | 0 | 0 | 0 | 0 | CLEAN ✅ |
| D | ai-map ACR mutated **alone** | FAIL | 0 | **1** | 0 | 0 | 1 issue ✅ |
| E | Restore | CLEAN | 0 | 0 | 0 | 0 | CLEAN ✅ |
| G | `None.` vs `None` — **one character** | FAIL | 0 | **1** | 0 | 0 | 1 issue ✅ |
| G2 | Restore — both `None.` | CLEAN | 0 | 0 | 0 | 0 | CLEAN ✅ |
| H1 | ai-map `phase` drifted alone | FAIL, phase only | **1** | 0 | 0 | 0 | 1 issue ✅ |
| H2 | ai-map `last_completed` drifted alone | FAIL, last only | 0 | 0 | **1** | 0 | 1 issue ✅ |
| H3 | ai-map `next_capability` drifted alone | FAIL, next only | 0 | 0 | 0 | **1** | 1 issue ✅ |
| H4 | ai-map `live_state.source` drifted | CLEAN (out of scope) | 0 | 0 | 0 | 0 | CLEAN ✅ |
| H5 | Restore | CLEAN | 0 | 0 | 0 | 0 | CLEAN ✅ |
| F1 | Real SPEC path, **both** sides agree | CLEAN | 0 | 0 | 0 | 0 | CLEAN ✅ |
| F2 | Same real SPEC path, ai-map reverted alone | FAIL | 0 | **1** | 0 | 0 | 1 issue ✅ |

*An infrastructure fault, distinguished from a product fault (`AGENTS.md §6`).* On the final re-run the throwaway harness named its manifest-mutation helper `RM`, which PowerShell resolves to the `Remove-Item` alias — so B, F1 and F2 silently never mutated anything and printed CLEAN. Read as guard results those three lines would have said the comparison was inert, i.e. the exact defect being repaired. They were caught by the harness printing the mutated line back, renamed, and re-run; the table above is the corrected run. Recorded because "a failed run is not automatically a finding" cuts both ways — a *passing* run from a harness that did nothing is the more dangerous half.

**The three that carry the most weight.** **G** proves the comparison is genuinely *active* at the `None.` value rather than skipping it — a single missing period fails, which is what distinguishes a live comparison from an inert one and is precisely the property `last_completed` lacked for forty commits. **F1/F2** prove it is equally active on a real non-`None` SPEC path, so the guard does not quietly stop working the moment a Change Request is actually approved — the shape-dependence that caused the original defect. **H1–H4** prove field isolation in both directions: each comparison fires only on its own field, the three pre-existing comparisons are unaffected by the addition, and an unrelated `live_state` key stays deliberately uncompared.

## 6. Manifest headroom

Measured before: **6,967 / 7,000 characters (33 left)** and a `Last Completed` line at **1,196 / 1,200 (4 left)**. Batch 6 could not have written its own completion line without tripping Check 5.

**No budget was raised** (`AGENTS.md §6`: *"no budget is ever raised to make a document fit"*). Three pieces of content were removed on the manifest's own stated rules, not to hit a number:

| Removed | Why it was safe |
|---|---|
| `Prior capability: PAY-1/JE-1/DEV-1, 202607059500, deployed.` | The manifest's own line 24 forbids exactly this: *"`Last Completed` names only the single most recent capability — replace it each time, never chain a 'Prior:' history."* The migration is still named on the `Live state:` line and the work is in the git log, `changes/` and its own report |
| The 2026-09-01 reconciliation narrative on the open-decisions line | Historical evidence, owned by the register's **OWNER-1** row. The **OWNER-1 citation, every open ID, the authority pointer and the "every ID on THIS line is read as an open decision" rule are all kept** — Checks 11, 14 and 16 all parse this line and all still pass |
| The `Last Completed` narrative of the 2026-09-01 package | `reports/history/session-2026-09-01-cold-start-guard.md` owns it, and the manifest still points at that class of history through `Narrative:` |

Also trimmed: the leanness paragraph restated the guard's three enforcement axes — the guard owns its own implementation, so it now cites Check 5 instead of describing it.

**Nothing authoritative was removed.** Current state, authority pointers, handoff information and execution context are all intact; what left the file was chained history and restatement.

**Result: 6,253 / 7,000 characters (747 left, up from 33) · 58 / 70 lines · longest line 884 / 1,200 (up from 4 characters of headroom to 316).**

## 7. Generator verification

`generate-ai-map.ps1` extracts `active_change_request` with `Get-Field $manifest "Active Change Request:"` → `(?m)^Active Change Request:\s*(.+?)\s*$`. The guard's new comparison uses the same anchor, the same label, the same single-line capture and the same trim. They read the same thing **by construction**, not by coincidence — the same relationship the `last_completed` comparison already has, and the same reason the `Next capability` terminator set is deliberately duplicated between the two files with a cross-reference in each.

**Sequencing (this is the part that matters).** The manifest trim made `ai-map.json` intentionally stale. The guard was run **first**, at that stale state, and **failed** — `last_completed` mismatch plus Check 10's stale README pointer. Only then was the artifact regenerated. Regenerating first would have made Check 7 pass again and hidden the very drift the package exists to catch; this is the sequencing `4b67d3f` established and it is followed here deliberately.

## 8. Repository re-scan

| Target | Result |
|---|---|
| Stale `ai-map.json` `live_state` fields | **None.** All four manifest-derived fields now compared by value; `source` is a constant pointer, `generated_at` is a timestamp — neither is manifest-derived |
| Duplicated current-state authority | **None introduced.** `manifest.md` remains the sole authority; `ai-map.json` remains derived and is regenerated, never hand-edited (`GOVERNANCE.md §2/§6` rule 4) |
| Stale references to Check 7 coverage | **Two found and fixed** — `MASTER_REPOSITORY_HEALTH.md` Docs-7 (named three fields), and the script's own header + block comment |
| Guard documentation claiming less than the implementation | **Found and fixed:** `MASTER_REPOSITORY_HEALTH.md §2b` calls itself *"Single discoverable list of every automatic check"* and stopped at Docs-12 while the script runs 17 checks — Checks 13–17 were missing. The same file's automation row still said *"the 11-check consistency guard"* |
| Guard documentation claiming **more** than the implementation | **One, in this package's own first draft** — the block comment implied the guard answered the SPEC-024/027 clear-on-Complete gap. It does not. Corrected before commit and the limit is now stated explicitly (§4) |
| Manifest budget violations | **None.** All three axes pass with the headroom above |
| Stale generated artifacts | `ai-map.json` regenerated. `repository-index.md` regenerated with `repository-all.ps1`'s exact inline logic and came back **byte-identical** — no canon `Version:`/`Status:` moved. `repository-all.ps1` itself was **not** invoked: it is interactive (`Read-Host`) and performs `git add`/`commit`/`push`, so only its two generation steps were run. `MASTER_API_CONTRACT.md` untouched — no database change, so its inputs did not move |

**Deliberately not entered:** the deferred Check-2 investigation, and Recommendations #2 and #3 from the prior reconnaissance. Out of scope for this package by instruction.

## 9. Not fixed (deliberate, with reasons)

1. **Clear-on-Complete is still unguarded.** Nothing verifies that a SPEC named in `Active Change Request` is still open. §4 states the limit; `future-backlog.md` and `GOVERNANCE.md §11` still carry the item. Closing it needs a different measurement (CR `Status` in `changes/SPEC-*.md`), not a wider Check 7.
2. **`live_state.source` and `generated_at` are uncompared.** Neither is manifest-derived; comparing them would broaden Check 7 past its contract for no invariant. Proven out of scope by H4 rather than left unstated.
3. **`GOVERNANCE.md §11`'s "enforce four invariants" is not rewritten.** It is a dated record of what was implemented on 2026-07-15/16, not a current-coverage claim; `MASTER_REPOSITORY_HEALTH.md §2b` is the declared registry of enforced invariants and is the file corrected. Editing `GOVERNANCE.md` would also engage the §15 governance-change lifecycle, which is owner-gated and unnecessary here.

## 10. Classification — engineering-only, verified from the repository

Checked against the repository rather than assumed:

- `GOVERNANCE.md §18` discovery-to-guard loop — *"every fix that closes a class of defect also lands the invariant that keeps it closed… **Do not wait for the owner to request these**; implementation exposes them."*
- `MASTER_REPOSITORY_HEALTH.md §2b` — *"Adding a new invariant is the standard permanent-guard response… extend the pgTAP suite or the consistency script."*
- `AGENTS.md §3` — **Routine** tier: an established pattern with no architectural impact.
- `AGENTS.md §1` — none of the five stop conditions holds: no owner-level architectural decision, no canonical contradiction, no long-term tradeoff, no blocker, nothing destructive or irreversible.
- **Protected-set check.** `AGENTS.md §6` defers to the `GOVERNANCE.md §5` registry, where `manifest.md` has its own row — Living, *"updated by: every CR"* — and is **not** in the "Living (protected) / owner-authorized" set. `check_repository_consistency.ps1`, `MASTER_REPOSITORY_HEALTH.md` and `MASTER_GAP_REGISTER.md` are Living and non-protected. No protected file was modified.
- **Precedent, same week:** Checks 16–17 (`302c7cb`) and the Check-7 `last_completed` repair (`4b67d3f`) were both landed autonomously.

**Verdict: engineering-only guard completion. No owner decision arises from this work, and none was consumed.**

## 11. Environment

No database was contacted. `check_repository_consistency.ps1` reads files only and prints that limit on success. No `supabase` MCP call, no `psql`, no reset, no deployment. pgTAP, the six HTTP suites, the smoke test and `check_database_parity.ps1` were **deliberately not run**: this package changes no schema, no function and no data, so they would have produced a longer report and zero additional evidence. Parity was last proven CLEAN on 2026-09-01 and is unaffected — that is `HISTORICAL` evidence about the database, and nothing here claims otherwise.

## 12. Current state

**184 migrations** (latest `202607059500`), repository = local = Primary as last proven. Repository guard **CLEAN at 17 checks, exit 0**. Manifest at 6,253 / 7,000 characters. Working tree committed. No owner decision opened or closed.

## 13. Next step

**Resume Batch 6 — the remaining Batch-6 tables**, per `MASTER_EXECUTION_PLAN.md`, which owns the order.
