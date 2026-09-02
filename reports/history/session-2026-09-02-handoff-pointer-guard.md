# ORVION — The Cold-Start Handoff Pointer, and Check 7's Last Unguarded Field

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-02
Author: Claude Opus 5
Status: Complete. Repository-only; **no migration, no database change, no deployment**.

---

## 1. Discovered

`scripts/generate-ai-map.ps1` extracts **four** live-state fields from `_ORVION_CANONICAL/manifest.md` into `ai-map.json`:

```
phase · active_change_request · last_completed · next_capability
```

`check_repository_consistency.ps1` **Check 7** is named *"ai-map freshness vs manifest"* and compared **three** of them:

| field | brought under comparison | how |
|---|---|---|
| `phase` | 2026-07-17 (INC-2) | phase number must appear somewhere in `live_state` |
| `next_capability` | 2026-08-17 | whole multi-line block, BY VALUE |
| `last_completed` | 2026-09-01 | BY VALUE — after ~40 commits inert (it had been keyed on a `SPEC-` prefix the field stopped carrying) |
| **`active_change_request`** | **never** | **nothing compared it** |

**The uncompared field is the load-bearing one.** `AGENTS.md §4` step 4 branches the *entire* boot sequence on it — not `None` ⇒ open that `changes/SPEC-*.md` and let its own Minimum Reading List take over; `None` ⇒ fall through to `32_execution_roadmap.md`. `AGENTS.md §6` and `CR_LIFECYCLE.md §9` make it the **only** sanctioned handoff channel between sessions ("never through chat").

Failure modes, both silent:

* a stale **non-`None`** value in the map sends a cold-starting agent into a **closed** Change Request;
* a stale **`None.`** hides an **open** one, and the agent silently starts different work.

**The forgetting history is demonstrated, not hypothetical.** The `Complete SPEC-NNN` pointer-clear (`CR_LIFECYCLE.md §9`) was omitted twice — SPEC-024 and SPEC-027 — and `reports/future-backlog.md` still carries the safeguard entry that omission earned.

### Root cause

Check 7's coverage was decided **field by field**, and each field entered it on the day its own drift shipped. The check's coverage is therefore a record of which drifts have already been *paid for*, not of what its name claims to measure. A field nobody had yet been burned by was simply unguarded.

This is the repository's most-repeated class, now in its sixth instance: **GOV-4** (Check 2's id pattern, blind to every id minted after it was written), **MEAS-1**, **MEAS-2**, **VER-1**, **PAR-3**, **SEC-1b** — a guard whose description outruns its measurement.

### Second finding, from the post-fix re-scan

`MASTER_GAP_REGISTER.md` — which `GOVERNANCE.md §2` makes the SSOT for a finding's **status** — still carried **`Status: OPEN`** for **API-3**, contradicted by three documents that were right:

* the GENERATED `MASTER_API_CONTRACT.md`: *"**72** RPC endpoints executable by `authenticated`; **72** exercised over HTTP by a suite"* — zero uncovered;
* `MASTER_EXECUTION_PLAN.md`: *"API-3 CLOSED — TASK-1 / TASK-2 / SUP-1, 2026-08-30"*, *"API-3 6 → 3 → 0"*;
* `manifest.md`'s `Next capability` — the field copied verbatim into `ai-map.json` and read at **every cold start** — *"API-3 is CLOSED"*.

**Why no guard saw it:** API-3 is defined by a `###` detail block and has **no table row**. Check 2 records OPEN only from a padded table cell (`\| OPEN \|`), so a detail block's `- **Status:** OPEN` field is invisible to it; the id was in neither the open set nor the resolved set, and the cross-Master pass had nothing to compare.

### Third finding — the guard's own documentation, wrong in both directions

`MASTER_REPOSITORY_HEALTH.md §2b` calls itself *"the single discoverable list of every automatic check"*.

* **Claiming MORE than the implementation:** its **Docs-7** row listed `Last Completed` as covered throughout the ~40 commits that comparison was inert, and never mentioned `active_change_request` at all.
* **Claiming LESS than the implementation:** the table stopped at **Docs-12** while the guard has carried **Checks 13–17** since 2026-08-30.
* Two stale counts in the same file: *"the 11-check consistency guard"* (17) and *"68 files"* for a pgTAP suite now at **89**.

## 2. Proven (evidence, in the order it was gathered)

**The guard was repaired FIRST and proven to fail on an intentionally stale artifact BEFORE anything was regenerated.** Regenerating first would have made Check 7 pass again and hidden the defect rather than fixed it — the same discipline the 2026-09-01 `last_completed` repair recorded.

```
ai-map.active_change_request := "changes/SPEC-154-employee-role-canon-alignment.md"   (manifest: "None.")
  AI-MAP STALE: ai-map.json live_state.active_change_request is
  'changes/SPEC-154-employee-role-canon-alignment.md' but the manifest's
  'Active Change Request:' is 'None.' — the cold-start handoff pointer disagrees
  with its own SSOT; regenerate (scripts/generate-ai-map.ps1)
REPOSITORY CONSISTENCY: 1 issue(s) found        exit 1
```

Exactly one issue: the mutation produced no collateral failure in any other check.

### Generator verification — the two read the same thing by construction, and it was measured

| probe | generator (`Get-Field`) | guard (Check 7) | identical |
|---|---|---|---|
| live manifest, generator's read (`-Encoding utf8`) | `None.` | `None.` | **yes** |
| live manifest, guard's read (host default) | `None.` | `None.` | **yes** |
| non-`None` real SPEC path | `changes/SPEC-154-…md` | `changes/SPEC-154-…md` | **yes** |
| decorated value + trailing whitespace | `` `changes/SPEC-999-x.md` `` | `` `changes/SPEC-999-x.md` `` | **yes** |

Same file, same anchor, same capture, same trim. The guard additionally collapses internal whitespace — deliberately, and identically to the `last_completed` comparison it copies — so reflowing cannot cry wolf while a real change of value fails loudly. `artifact == generator` and `generator == guard` both true against the committed `ai-map.json`.

### Mutation battery

Every mutation was applied to the real files, the guard run, and the file restored byte-for-byte from a backup taken before the battery.

| # | mutation | expected | observed |
|---|---|---|---|
| **A** | none — baseline | CLEAN | see §6 |
| **B** | manifest `Active Change Request` only | FAIL | see §6 |
| **C** | restore | CLEAN | see §6 |
| **D** | ai-map `active_change_request` only | FAIL | see §6 |
| **E** | restore | CLEAN | see §6 |
| **F** | BOTH set to a real SPEC path, then map mutated alone | agree ⇒ CLEAN, then FAIL | see §6 |
| **G** | BOTH `None.`, then map mutated alone | agree ⇒ CLEAN, then FAIL | see §6 |
| **H** | `phase` / `last_completed` / `next_capability` each mutated alone | each fires its **own** message; ACR silent | see §6 |

**F and G are the tests that matter, and they are why the battery has eight cases rather than five.** A comparison can be *present* and still be inert at the value the field actually holds — which is exactly how the `last_completed` comparison died. The field sits at `None.` for most of its life, so `None.` had to be proven live, not assumed live.

## 3. Fixed

1. **`scripts/check_repository_consistency.ps1` Check 7** — `active_change_request` compared BY VALUE, extracted and normalised by exactly the contract `Last Completed` already established. **No new mechanism; no maintained SPEC-id list; no other `ai-map` key brought under comparison.** The script's own header now enumerates all four fields rather than naming the check generically.
2. **`_ORVION_CANONICAL/manifest.md` headroom** — restored by **trimming narrative, never by raising a budget** (`AGENTS.md §6`: *"no budget is ever raised to make a document fit"*; precedent **MF-1**).
3. **`MASTER_GAP_REGISTER.md`** — API-3's status corrected **in its own detail block**, the single home of that fact; no second row was created for it. The "why it is not closed" paragraph is retained, re-labelled as the historical reason it stayed open through 2026-08-29.
4. **`MASTER_REPOSITORY_HEALTH.md §2b`** — Docs-7 rewritten from the implementation; **Docs-13…17 added**; the two stale counts replaced by pointers to their owners rather than refreshed (**GOV-5**'s standing conclusion).
5. **`ai-map.json`** — regenerated, never hand-repaired (`GOVERNANCE.md §6` rule 4).
6. **Two more stale guard-coverage claims found by the re-scan and fixed the same way (point, don't count):** `reports/future-backlog.md` described a *"7-check guard"* (17), and a comment inside Check 7 itself still said *"the two checks above key on the phase NUMBER and the Last-Completed SPEC id"* — untrue on both halves after this package and after the 2026-09-01 repair, so it is now explicitly dated to the state it describes.

### Manifest headroom — what was cut and why it was safe

| axis | before | after | headroom |
|---|---|---|---|
| characters | 6,967 / 7,000 | **6,348** | 33 → **652** |
| longest line | 1,196 / 1,200 | **864** | 4 → **336** |
| lines | 58 / 70 | 58 | 12 |

Three cuts, each removing something the manifest's **own rules** already forbid — not current state, authority, handoff, or execution context:

* **`Last Completed`** carried `"Prior capability: PAY-1/JE-1/DEV-1, `202607059500`, deployed"` — a chained history the field's own rule forbids (*"names only the single most recent capability … never chain a 'Prior:' history"*), whose migration id is already stated on the `Live state:` line and guarded there by Check 9. The rest was rationale that belongs in this report; the new line states the capability, its consequence, and the narrative pointer.
* **`Open owner decisions`** — the 2026-09-01 reconciliation narrative compressed to its rule plus the **OWNER-1** pointer (the evidence lives in that register row), and QUO-4's "how it went stale" history dropped. **Every open ID, and every parenthetical stating *why* an item is owner-gated or what must happen first, was preserved** — that is handoff, not history.
* **`Current Module`** — "the **eight** mandatory `§2a` corrections" → "the mandatory `§2a` corrections (that file owns how many)". The count was correct today; a mutable number restated outside its owner is the **REG-2 / GOV-5** class, and deletion is the fix that holds.

Nothing was removed to make a guard pass: Check 5 was **already CLEAN** at 6,967 and 1,196. The work was to restore a margin Batch 6 can spend.

## 4. Not fixed (found, deliberately left)

* **Check 7 measures disagreement, not presence.** All four comparisons — the three that existed and the one added — are silent if the manifest loses a field entirely. Adding a presence assertion for `active_change_request` alone would leave the same asymmetry one level down, which *is* the defect **GOV-10** records. It needs one deliberate decision covering all four fields, in a package that can attack it properly. **Recorded in GOV-10 as a stated residual.**
* **Check 2 cannot read a `###` detail block's `Status:` field**, which is why API-3's stale OPEN survived three days beside three documents that disagreed with it. Extending it needs a counterexample battery over ~109 detail blocks whose status lines are prose plus emoji — a governance-guard package of its own. It joins **GOV-9** as recorded, triggered, unbuilt. **Explicitly out of scope by owner instruction for this package.**
* **`AGENTS.md §5a`'s evidence-class table says the REPOSITORY class covers "guard Checks 1–13"; the guard has 17.** A hand-maintained count restated beside the thing it counts — the same **GOV-5** class fixed twice in `MASTER_REPOSITORY_HEALTH.md` this session. **Not fixed because `AGENTS.md` is a protected resource** (`AGENTS.md §6`; `GOVERNANCE.md §5` registry: *"owner-authorized only"*). The correct fix is deletion, not refreshment: *"guard Checks 1–13"* → *"the repository guard's checks (enumerated in `MASTER_REPOSITORY_HEALTH.md §2b`)"*. **Owner authorization required.**
* **`manifest.md`'s `Next capability` states finding statuses** ("API-3 is CLOSED", "SEC-1 is DECIDED, not open") that `GOVERNANCE.md §2` assigns to the register. Left untouched deliberately: both sentences were added by the 2026-09-01 cold-start package **to stop a fresh agent re-litigating settled work**, and removing them would risk reintroducing the contradiction that package fixed. Recorded here as a known duplication whose resolution is a governance question, not an edit.
* **`manifest.md`'s `Live state:` figures "71/601 catalog", "8 reporting views", "75 tables"** have no mechanical owner. **META-1** already reasoned about the last of these and declined to guard it (the smoke test's table assertion is a different measurement from the contract's tenant-reachable count, so comparing them would manufacture a false failure). The other two are unexamined. **No new finding raised — this is META-1's declared residue, not a new one.**

## 5. Blocked

Nothing. No external action is required by anything in this package.

## 6. Verification — commands and real output

Every mutation was applied to the **real** files, the guard run as CI runs it, and both files restored from a pre-battery backup. The harness asserts each mutation actually changed the *parsed* value before running the guard — a mutation that silently fails to apply would otherwise "prove" the guard clean.

```
pwsh -File scripts/check_repository_consistency.ps1

[PASS] A   baseline, no mutation .................................. CLEAN                exit 0
[PASS] B   manifest Active Change Request mutated ALONE ........... 1 issue(s) found     exit 1
           > ai-map … is 'None.' but the manifest's is
             'changes/SPEC-154-employee-role-canon-alignment.md'
[PASS] C   restored ............................................... CLEAN                exit 0
[PASS] D   ai-map active_change_request mutated ALONE ............. 1 issue(s) found     exit 1
           > ai-map … is 'changes/SPEC-154-…md' but the manifest's is 'None.'
[PASS] E   restored ............................................... CLEAN                exit 0
[PASS] F1  BOTH at a real SPEC path — active and agreeing ......... CLEAN                exit 0
[PASS] F2  map moved to a DIFFERENT real SPEC ..................... 1 issue(s) found     exit 1
           > ai-map … 'changes/SPEC-153-event-vocabulary-triage.md'
             vs manifest 'changes/SPEC-154-employee-role-canon-alignment.md'
[PASS] G1  BOTH at None. — active and agreeing .................... CLEAN                exit 0
[PASS] G2  'None' vs 'None.' — ONE character ...................... 1 issue(s) found     exit 1
           > ai-map … is 'None' but the manifest's is 'None.'
---------------- H: the other three comparisons are unaffected ----------------
[PASS] H1  manifest Current Phase mutated alone ................... 3 issue(s) found     exit 1
           > ai-map live_state does not name manifest Current Phase 3
             (also trips Check 6 roadmap↔manifest, correctly; active_change_request SILENT)
[PASS] H2  ai-map last_completed mutated alone .................... 1 issue(s) found     exit 1
           > live_state.last_completed does not match … (active_change_request SILENT)
[PASS] H3  ai-map next_capability mutated alone ................... 1 issue(s) found     exit 1
           > live_state.next_capability does not match … (active_change_request SILENT)
[PASS] H4  final restore — baseline again ......................... CLEAN                exit 0

restored byte-identical: manifest=True  ai-map=True
================ RESULT: 13 passed, 0 failed ================
```

**What each direction proves, stated rather than left to the reader:**

* **B and D** are the two directions of the same disagreement — mutating the *authority* and mutating the *consumer* — and a guard that catches only one of them is half a guard. **B is the one that matters most in practice**, because a real `Approve SPEC-NNN` moves the manifest and leaves the map behind.
* **F2 and G2** prove the comparison is live at both values the field ever holds. **G2 is deliberately a one-character difference** (`None` vs `None.`): a token-shaped or prefix-keyed check would pass it, and that is precisely how the `last_completed` comparison was inert for forty commits.
* **H** proves the addition is additive: each pre-existing comparison still fires its own message, and `active_change_request` stays silent in all three — no cross-talk, no double-reporting.
* **H1 reporting three issues is correct, not noise:** mutating `Current Phase` to a phase the roadmap does not mark In Progress legitimately trips Check 6 as well. It is recorded rather than filtered, because a battery that hides a guard's other true positives is measuring the wrong thing.

## 7. Governance

* **Classification: engineering-only guard completion, verified from the repository rather than assumed.** `GOVERNANCE.md §18`'s discovery-to-guard loop makes the permanent guard the standard response to a discovered gap and says explicitly *"do not wait for the owner to request these"*; `MASTER_REPOSITORY_HEALTH.md §2b` states the mechanism (*"extend the pgTAP suite or the consistency script, never a one-off manual check"*). `AGENTS.md §3` tiers this **Routine** — an established pattern reusing an existing mechanism, with no architectural impact. **None of `AGENTS.md §1`'s five stop-conditions is met:** no new architectural decision, no canonical contradiction created, no long-term tradeoff, no blocker, nothing destructive or irreversible. No ADR, no canon rule, no roadmap change. **Precedent is direct and recent:** Checks 14, 15, 16 and 17 were all added under the same authority within the preceding three days.
* **Files touched are all writable at this authority:** `scripts/**`, `reports/master/**` and `reports/history/**` (Living / new), `ai-map.json` (auto-generated — regenerated, not edited), and `manifest.md`, whose `GOVERNANCE.md §5` registry row is **Living, "updated by: every CR"** — the one `_ORVION_CANONICAL` file that is not in the protected set. `AGENTS.md`, `README.md`, `GOVERNANCE.md`, `CR_LIFECYCLE.md` and canon `00`–`35` were **read and not modified**.
* **Database:** untouched. No migration was authored, no MCP write was issued, no `db reset` was run. Every claim in this report is **REPOSITORY**-class evidence (`AGENTS.md §5a`), and none of it is quoted as evidence of live parity.

## 8. Environment

Windows 11, PowerShell 7.6.5. Repository-only session: Docker/Supabase local stack not started, `supabase-primary` not contacted — correctly, since nothing here touches the database. `scripts/generate-api-contract.ps1` was **not** run: it generates from the live database, and no schema changed.

## 9. Current state

* **Working tree:** clean at commit time; one commit ahead of the previous HEAD `4b67d3f`.
* **Repository consistency:** `REPOSITORY CONSISTENCY: CLEAN` — 17 checks, scope repository files only.
* **manifest ↔ ai-map:** all four `live_state` fields agree, and three of the four are now proven to *fail* when they do not.
* **Database / Primary:** unchanged and **UNPROVEN this session by design** — 184 migrations, ledger `ed3828994cc61d703e60d02100eeae63`, last read live 2026-09-01. A repository-only package cannot and does not refresh that evidence.
* **Suite:** 89 files / 1232 assertions, unchanged (no test was added — the guard under repair is a PowerShell script, not a database invariant, and Check 7 is its own regression surface).

## 10. Next step — exactly one

**Resume Batch 6: the remaining Batch-6 tables, per `MASTER_EXECUTION_PLAN.md`, which owns the order.** This package deliberately did not begin it.
