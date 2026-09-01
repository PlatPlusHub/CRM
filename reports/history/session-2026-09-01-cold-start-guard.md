# ORVION — The Cold-Start Contradiction, and the Guard That Reads Canon Against the Decision List

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Status: Complete. Repository-only; **no migration, no database change, no deployment**.

---

## 1. Discovered

A cold-start audit found `_ORVION_CANONICAL/32_execution_roadmap.md` telling a fresh session two false things:

1. **Line 275** — Phase 10's prerequisites list named **SEC-1**'s write-path architecture as *"open owner decisions … chief among them"*. The owner **ratified SEC-1 on 2026-09-01 (OWNER-1)**. A cold-start agent following the boot sequence would have re-litigated a settled decision or escalated a blocker that does not exist.
2. **Line 282** — restated *"71 RPC endpoints"* while the generated `MASTER_API_CONTRACT.md` said **72**, inside a sentence whose own second clause reads *"The current count is read from the generated contract, never restated here (REG-2)"*. It contradicted itself in its own sentence.

**And a third, deeper one found while verifying the first — the register contradicted itself.** `MASTER_GAP_REGISTER.md`'s **SEC-1 row** still opened *"EVALUATED 2026-08-29 — AWAITING OWNER RATIFICATION"* with a live owner action in its owner column, while the **OWNER-1 row three rows below** already recorded SEC-1 as decided and removed from the manifest's open list. The findings SSOT disagreed with itself about its own highest-profile finding.

**Why no guard saw any of it.** Check 2 owns intra- and cross-Master status contradiction — but it reads a row as OPEN only on a cell that is exactly the padded literal `\| OPEN \|`, and as resolved only on a cell *leading* with `✅`/`RESOLVED`/`IMPLEMENTED`. A status cell opening `**EVALUATED … AWAITING OWNER RATIFICATION**` is invisible to **both** halves of the comparison, so SEC-1 was never in either set. And Check 2 is scoped to `reports/master/**`: **no guard had ever read canon prose against the decision list at all.**

## 2. Fixed

- **Canon 32 line 275** — stops naming any decision. It now points at the two maintained lists (`MASTER_EXECUTION_PLAN.md` Batch 6 for engineering, the manifest's `Open owner decisions` line for the owner's), which is the same conclusion the paragraph 47 lines above had already reached after this file restated a moving list twice before.
- **Canon 32 line 282** — the number is **deleted, not refreshed**. Refreshing it would only reset the fuse; the contract owns the count.
- **Register SEC-1 row** — corrected to `✅ RATIFIED BY THE OWNER 2026-09-01 (OWNER-1)`, owner column cleared. **No decision was made here**: the ratification is the owner's, already recorded in the OWNER-1 row, and this only stops the register from contradicting its own record of it. The evaluation text is kept verbatim beneath, because it is the evidence that earned the decision.

*A defect introduced and caught during the fix:* the new SEC-1 status text quoted `| OPEN |` in backticks, and those literal pipes split the row into 15 cells — **REG-1's exact class, reintroduced while repairing another contradiction**. Caught by the editor's table-column-count diagnostic, escaped to `\|`, and verified at **13 cells** matching the header by counting pipes a markdown parser would honour (`awk -F'|'` cannot see the escape and still reports 15 — the naive count is the wrong measurement here).

## 3. Guarded

**Check 16 — no canonical document may name a settled finding as a CURRENT owner decision.** Five gates, each structural rather than linguistic, because the hard problem is telling a current claim from historical narrative:

| Gate | Rule |
|---|---|
| Scope | `_ORVION_CANONICAL/**` only — canon is the **INTENT** evidence class (`AGENTS.md §5a`) and must never carry live status. `reports/master/**` stays with Check 2 |
| Region | the line must be a markdown **list item** — the boundary separating canon 32's prerequisites *list* from its correction *paragraph*; a structural feature, not formatting inside a line (**MEAS-4**) |
| Claim | a small closed phrase set: `open owner decision` · `awaiting owner` · `owner must decide` · `blocked on` |
| Negative | the line must not also carry `decided\|resolved\|closed\|ratified\|superseded\|no longer\|was an open` — so legitimate history exempts itself |
| Authority | the ID must be absent from the manifest's `Open owner decisions` line — the same designated list Checks 11 and 14 already parse |

**Nothing here maintains a list of closed IDs.** A decision leaves the guard's "open" set by leaving the manifest line, which is the act OWNER-1 performs. The ID parse deliberately reads the whole manifest line, parentheticals included, so its only possible error is to be *more permissive* — never to cry wolf.

**Check 17 — no canonical document may restate the RPC-endpoint count `MASTER_API_CONTRACT.md` generates.** Pattern-bound to the noun the contract owns. No exemption list is needed and none exists: the generating file is not in `_ORVION_CANONICAL/`, so it is outside the check by construction rather than by a carve-out somebody must maintain.

## 4. Attacked before trusted — 13 cases, all as predicted

| Attack | Expected | Result |
|---|---|---|
| Plant the exact SEC-1 defect in a canon list item | FAIL | FAIL (Check 16 ×1) |
| Restore | CLEAN | CLEAN |
| Plant `71 RPC endpoints` | FAIL | FAIL (Check 17 ×1) |
| Restore | CLEAN | CLEAN |
| **Second direction:** canon names QUO-4, which IS on the open list | CLEAN | CLEAN |
| **Second direction:** same canon line, QUO-4 removed from the *manifest* | FAIL | FAIL (Check 16 ×1) |
| Restore | CLEAN | CLEAN |
| FP (a) **paragraph** naming SEC-1 as an open owner decision | CLEAN | CLEAN |
| FP (b) list item naming SEC-1 **with** a resolution word | CLEAN | CLEAN |
| FP (c) list item **citing** SEC-1 with no claim phrase | CLEAN | CLEAN |
| FP (d) list item naming a genuinely open decision (RET-1) | CLEAN | CLEAN |
| FP (e) canon restating the **correct** count (72) | FAIL | FAIL |
| Final restore | CLEAN | CLEAN |

**The two that matter most.** *Second direction* changes only the **authority** and leaves the consumer document untouched — the same canon line flips from legal to flagged, proving the guard derives status from the decision list rather than pattern-matching an ID. *FP (e)* proves Check 17 forbids the restatement itself, not merely the wrong number: deletion is the fix, refreshment is not.

Measured before implementation: across all **37** canonical documents both rules produce exactly **one flag each** — the two known defects — and **zero** false positives.

## 5. Re-scan of the living document set

Living documents only (`_ORVION_CANONICAL/**`, `reports/master/**`, `reports/evidence/**`, root); `reports/history/**` excluded by design as immutable evidence.

Scanned for restated migration counts, suite figures, 32-hex hashes and endpoint counts: **34 + 4 + 29 + 7 hits, and every one is dated evidence rather than a current claim** — the certification ledger's append-only history, the integration catalog's handoff log, register rows citing the state that earned a finding, and `AGENTS.md §4`'s own "29 migrations behind" incident lesson. Rewriting any of them would destroy the evidence trail the repository deliberately preserves (GOV-5's stated reasoning).

**No new current contradiction was found.** This also validates Check 17's scope: extending it to `reports/master/**` would have produced seven false positives immediately.

## 6. Verification

`check_repository_consistency.ps1` → **CLEAN, exit 0**, now 17 checks. No database work: this package changes no schema, no function and no data, so pgTAP, HTTP, smoke and parity were deliberately **not** run — running them would have produced a larger report and no additional evidence. Migration count unchanged at **184**; repository/local/Primary parity unaffected and last proven CLEAN earlier today.

## 7. Current state

**184 migrations**, repository = local = Primary. Guard at 17 checks, CLEAN. No owner decision arises from this work.

## 8. Next step

**The remaining Batch-6 tables**, per `MASTER_EXECUTION_PLAN.md`.
