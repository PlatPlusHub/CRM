# ORVION — COLD-3: The Pointer Was Never Checked Against the Lifecycle It Points Into

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-02
Author: Claude Opus 5
Status: Complete. Repository-only; **no migration, no database change, no deployment**.

---

## 1. The old gap — evidence

COLD-2 (earlier the same day, commit `2d7f891`) made Check 7 compare `manifest.md`'s `Active Change Request` with `ai-map.json`'s copy **by value**. That proves the two artifacts **agree**. It never asked whether what they agree on is **true**, and nothing else in the repository did either.

Proven at commit `2d7f891`, before a line was changed:

| # | Manifest points at | That CR's own Status | ai-map | Guard |
|---|---|---|---|---|
| 1 | `changes/SPEC-125-remediation-governance-reconciliation.md` | `[x] Complete` | agrees | **CLEAN, exit 0** |
| 2 | `changes/SPEC-999-never-created.md` | *file does not exist* | agrees | **CLEAN, exit 0** |

Case 1 hands a cold-start session finished work as its assignment. Case 2 sends it to a file that is not there — and had never been catchable, because Check 1 deliberately excludes the `SPEC-NNN.md` placeholder shape from reference linting, so **nothing in the repository had ever resolved this path**.

`AGENTS.md §4` Stage A step 4 *branches* on this field: if it is not `None`, the agent reads that CR and its Minimum Reading List takes over. So the pointer is not decorative — it redirects the entire boot sequence.

**The failure is recorded, not hypothetical.** The pointer-clear was omitted on `Complete` twice — **SPEC-024** and **SPEC-027** — and `reports/future-backlog.md` has carried a "Process safeguard for Complete-sync" row ever since, proposing a Claude Stop/PostToolUse hook. Nothing had been built.

An intermediate observation worth recording: with the manifest moved but ai-map **not** regenerated, Check 7 fired correctly and Check 18's absence was invisible. The synchronization guard was working perfectly and was simply answering a different question. That is why regenerating first would have hidden this defect (§9 below).

## 2. Authoritative CR status source — established from the repository, not assumed

**The Change Request's own `## Status` section, in its `changes/SPEC-*.md` file.**

| Evidence | What it establishes |
|---|---|
| `changes/TEMPLATE.md` §Status | **Defines the field**: five checkboxes, and *"Allowed values are exactly these five. Do not use any other status word."* |
| `CR_LIFECYCLE.md §3` | *"Exactly five, per `changes/TEMPLATE.md`"* — the lifecycle document defers the vocabulary to the template |
| `CR_LIFECYCLE.md §4` | **`Complete` and `Cancelled` are terminal.** This is the terminal set, cited rather than invented |
| `CR_LIFECYCLE.md §8` | Synchronization updates *"a Change Request's own workflow-state sections — `Status` …"* — the CR file is where status is written |
| `CR_LIFECYCLE.md §9` | `Approve` flips the box **and** sets this pointer; `Complete` flips the box **and** clears it. The two move together by design |
| `GOVERNANCE.md §3` | Lifecycle row: `Implementation │ changes/SPEC-*.md │ CR_LIFECYCLE` |
| `GOVERNANCE.md §13` | `CR_LIFECYCLE ──drives──▶ changes/SPEC-* ──update──▶ manifest` — one direction of authority |

**No competing authority exists.** `MASTER_EXECUTION_PLAN.md` names SPEC ids **29 times and assigns none of them a status**. No registry or index claims CR status. The manifest holds the *pointer*, never the *state*.

**The model is coherent — surveyed, not assumed.** All **151** CR files: 151 have a `## Status` section, 151 have exactly **one** checked box, 0 have zero, 0 have multiple, and every checked value is one of the five legal words. No stop condition applies: no conflicting authorities, no business decision, no database (CR status is a repository fact — `supabase/` was never opened).

## 3. Root cause

COLD-2 closed *artifact synchronization* and, in closing it, made the remaining hole harder to see: once the manifest and ai-map were guaranteed to agree, a reader could easily mistake agreement for validity. The two are orthogonal —

- **Synchronization** (Check 7): *do the derived artifact and its authority say the same thing?*
- **Lifecycle validity** (Check 18): *is the thing they say still true?*

— and a guard existed for the first only. This is the same family the programme keeps finding (**PAR-3**, **SEC-1b**, **VER-1**, **MEAS-2**): a guard that measures a real property, and a reader who takes it for a stronger one.

## 4. Implementation — exact files and minimal change

| File | Change |
|---|---|
| `scripts/check_repository_consistency.ps1` | **Check 18** added (one block, ~45 lines including its evidence comment), plus the header docblock |
| `reports/master/MASTER_GAP_REGISTER.md` | **COLD-3** row; header `Last updated` |
| `reports/master/MASTER_REPOSITORY_HEALTH.md` | **Docs-18** row; Docs-7 cross-reference; §5 action 1; 17→18; `Last measured` |
| `reports/future-backlog.md` | Process-safeguard row struck as **DONE** |
| `GOVERNANCE.md §11` | Two stale restated lists **removed** (not refreshed) — see §8 |
| `_ORVION_CANONICAL/manifest.md` | `Last Completed` + `Narrative:` |
| `reports/README.md` | Latest-session pointer |

**No parallel validation framework.** The repository's evidence is unambiguous — `GOVERNANCE.md §11` names `check_repository_consistency.ps1` as *the* governance-lint mechanism and says remaining extensions "are additive to the same script"; `MASTER_REPOSITORY_HEALTH.md §2b` is the single registry; `GOVERNANCE.md §18` says extend the existing guard, "never a one-off manual check". So: one more check in the existing script.

**No second source of truth.** Status is **read** from the CR file at check time and **never copied** into `manifest.md` or `ai-map.json`. The manifest continues to hold only the pointer; `ai-map.json` stays derived.

**No maintained SPEC-ID list**, and none is possible: the subject is whatever path the manifest names. The legal vocabulary is parsed from `changes/TEMPLATE.md` rather than restated, so a vocabulary change surfaces as `ACTIVE CR STATUS UNKNOWN` instead of being silently accepted.

## 5. Invariant behaviour

`Active Change Request` must name a real, still-open Change Request.

| Manifest value | Verdict |
|---|---|
| `None` / `None.` | CLEAN — no active CR, nothing to validate |
| Path to a CR whose one checked box is `Draft`, `Approved`, `In Progress` | CLEAN |
| Path to a CR whose one checked box is `Complete` or `Cancelled` | **FAIL** — terminal (`CR_LIFECYCLE.md §4`) |
| Path that does not exist | **FAIL** |
| CR with no `## Status` section | **FAIL** |
| CR with zero, or more than one, checked box | **FAIL** |
| CR whose status word is outside `TEMPLATE.md`'s five | **FAIL** |

`Draft` is deliberately **not** flagged: it is non-terminal, and `CR_LIFECYCLE.md §9`'s `Execute` already refuses a Draft. Failing on it would be stricter than "currently open" without evidence demanding it.

## 6. Mutation test matrix — 15 runs

**The harness was proven before its verdicts were trusted.** Every run echoes the actual on-disk state — manifest value, ai-map value, and the CR's checked status box — *before* the guard's result, so a CLEAN line can never be mistaken for "the mutation applied and passed" when the truth is "the mutation never landed". This was not theoretical caution: in the preceding package a helper named `RM` silently resolved to PowerShell's `Remove-Item` alias and three mutations never applied while printing CLEAN.

| # | Case | Verified on disk | Expected | Result |
|---|---|---|---|---|
| 1 | Baseline | `None.` | CLEAN | CLEAN ✅ |
| 2 | Completed CR, ai-map agrees | `[x] Complete` | FAIL | FAIL ✅ |
| 3 | Nonexistent CR, ai-map agrees | file missing | FAIL | FAIL ✅ |
| 4 | Restore | `None.` | CLEAN | CLEAN ✅ |
| 5 | Open CR — `Draft` | `[x] Draft` | CLEAN | CLEAN ✅ |
| 6 | Open CR — `Approved` | `[x] Approved` | CLEAN | CLEAN ✅ |
| 7 | Open CR — `In Progress` | `[x] In Progress` | CLEAN | CLEAN ✅ |
| 8 | **Same file** → `Complete` | `[x] Complete` | FAIL | FAIL ✅ |
| 9 | **Same file** → `Cancelled` | `[x] Cancelled` | FAIL | FAIL ✅ |
| 10 | Zero boxes checked | 0 checked | FAIL | FAIL ✅ |
| 11 | Two boxes checked | `Approved` + `Complete` | FAIL | FAIL ✅ |
| 12 | Word outside the vocabulary | `[x] Shipped` | FAIL | FAIL ✅ |
| 13 | No `## Status` section | section absent | FAIL | FAIL ✅ |
| 14 | Open CR, ai-map **not** regenerated | `[x] In Progress`, ai-map `None.` | FAIL **Check 7 only** | Check 7=1, Check 18=0 ✅ |
| 15 | Final restore | `None.` | CLEAN | CLEAN ✅ |

**Cases 5–9 are the load-bearing ones.** The *same file* flips CLEAN → FAIL → CLEAN purely on its own Status box, with the path, the manifest and ai-map all unchanged. That is the proof the check derives its verdict from the authoritative status source rather than from the path, a filename pattern, or a list.

**The open-CR case earned its place by catching a defect in the check itself.** On first run, a CR marked `In Progress` was reported as status `I`. Cause: a single regex match makes the PowerShell pipeline return a **scalar string**, whose `.Count` is 1 and whose `[0]` is its first *character*. The check was over-firing — a false positive — and **cases 2, 3 and 10–13 could never have revealed it, because every one of them expects FAIL.** Only a case that must come back CLEAN could. Fixed by forcing an array (`@(...)`), with the reason recorded at the site.

## 7. Existing Check-7 regression results

All four live-state comparisons remain independently effective, with Check 18 silent throughout:

| Mutation (ai-map only) | phase | acr | last | next | Check 18 |
|---|---|---|---|---|---|
| `phase` drifted alone | **1** | 0 | 0 | 0 | 0 |
| `active_change_request` drifted alone (`None.` vs `None`) | 0 | **1** | 0 | 0 | 0 |
| `last_completed` drifted alone | 0 | 0 | **1** | 0 | 0 |
| `next_capability` drifted alone | 0 | 0 | 0 | **1** | 0 |

**Independence proven in both directions** — the requirement that lifecycle validity and artifact synchronization never be conflated:

- **Sync fails alone:** a *valid, open* CR with a stale ai-map → Check 7 = 1, Check 18 = 0 (case 14).
- **Lifecycle fails alone:** a *closed* CR with a synchronized ai-map → Check 18 = 1, all four Check-7 comparisons = 0 (cases 2, 3, 8–13).

Neither can mask the other, and neither substitutes for the other.

## 8. Documentation / governance impact

Three documents asserted this gap was still open and are now corrected — each by **removing a stale restatement rather than refreshing it**, the remedy GOV-5 established:

1. **`reports/future-backlog.md`** — the process-safeguard row is struck as DONE, recording that the delivery is *stronger* than the row requested (it validates against the CR's Status, not merely against the literal string `None`) and *differently shaped* (a CI-gated guard, not a workstation-local hook).
2. **`MASTER_REPOSITORY_HEALTH.md`** — Docs-18 added; Docs-7's "remains open" pointer redirected to it; §5 action 1's two remaining items reduced to one (the link-checker); 17→18.
3. **`GOVERNANCE.md §11`** — the cell restated *"enforce four invariants"* against eighteen, and still listed the `Active CR` lint as a remaining extension after it shipped. **Both enumerations are deleted** and the cell now defers to `MASTER_REPOSITORY_HEALTH.md §2b`, the registry it already cited (`GOVERNANCE.md §6.8`, One Authority).

**On the `GOVERNANCE.md` edit specifically.** `§15` makes governance *rule* changes owner-gated. This edit changes **no rule, no SSOT-matrix row, no lifecycle and no taxonomy** — it corrects a factual tooling-status cell and removes a duplicated list, which is the same class of edit as the "IMPLEMENTED (2026-07-15/16)" note already in that cell. **No version bump was made, because no governance rule changed.** It is flagged here explicitly so the owner can reverse it if they read `§15` more strictly than I have.

## 9. Sequencing

Every mutation that made ai-map stale was run through the guard **before** regeneration, and the two failures were recorded separately (case 14). Where the *lifecycle* invariant was under test, ai-map was regenerated first **on purpose** — not to hide anything, but because an unsynchronized ai-map would have failed Check 7 and masked the very question being asked. Both orders are represented, and each is stated with the reason it was chosen.

## 10. Repository re-scan

| Target | Result |
|---|---|
| Stale current-state claims | **Three found and fixed** (§8). No others: the manifest's figures are guarded by Checks 9 and 15, and its narrative fields by Check 7 |
| Contradictory lifecycle/status claims | **None.** 151/151 CR files carry exactly one status; no document assigns a CR a status except the CR itself |
| Duplicated authority | **None introduced** — status is read, never copied. **One removed**: `GOVERNANCE.md §11`'s duplicate invariant list |
| Stale generated artifacts | `ai-map.json` regenerated and verified; `repository-index.md` byte-identical (no canon `Version:`/`Status:` moved); `MASTER_API_CONTRACT.md` untouched — no database change |
| Broken handoff references | **None** — and this is now mechanically enforced rather than reviewed |
| Missing referenced CR/SPEC files | **None.** The manifest names no CR; all 151 referenced CR files exist |
| Documentation claiming less/more coverage than exists | Fixed in all three documents above. `AGENTS.md §4` step 8 lists the guard's checks illustratively ("**and** … Check 8") rather than exhaustively, so it is not a completeness claim and is left alone |

**Deliberately not done:** no Batch-6 domain work, no repository reorganization, no redesign, no database access.

## 11. Guard result

`pwsh -File scripts/check_repository_consistency.ps1` → **REPOSITORY CONSISTENCY: CLEAN, exit 0**, now **18 checks**. Check 18 reports `no active Change Request (manifest says 'None.') -- nothing to validate`.

Evidence class **REPOSITORY** only. No database was contacted: no migration changed, no `.sql` changed, no MCP call, no `psql`, no reset. pgTAP, the six HTTP suites, the smoke test and `check_database_parity.ps1` were **not** run — this package changes no schema, function or data, so they would add no evidence. Migration count unchanged at **184**; parity last proven CLEAN 2026-09-01 (`HISTORICAL` evidence, not restated as current).

## 12. Remaining limitations

1. **`Draft` is accepted.** Non-terminal by `CR_LIFECYCLE.md §4`, and `Execute` already refuses one. Tightening to "`Approved` or `In Progress` only" — which `§9`'s `Approve` command implies — is available if evidence ever warrants; it was not taken without it.
2. **One pointer, one CR.** The field is single-valued by design (`CR_LIFECYCLE.md §9`); the check inherits that and says nothing about CRs not named by the manifest. A CR left `In Progress` while the manifest says `None.` is **not** detected. That is a different invariant (orphaned in-flight work) and is not claimed here.
3. **The check reads the Status *section*.** A CR that records its status somewhere else in prose would not be seen — but `TEMPLATE.md` mandates the section, all 151 files have it, and its absence is itself a FAIL.
4. **The full external link-check remains outstanding** (`GOVERNANCE.md §11`, `MASTER_REPOSITORY_HEALTH.md §5`). Untouched by this package.

## 13. Next step

**Resume Batch 6 — the remaining Batch-6 tables**, per `MASTER_EXECUTION_PLAN.md`, which owns the order.
