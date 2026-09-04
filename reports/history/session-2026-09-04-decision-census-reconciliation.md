# ORVION — Decision census reconciliation: the counts now close, and five settled decisions came back off the manifest

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: **COMPLETE — all 151 non-closed findings across both register substrates carry exactly one final disposition, and the totals reconcile in both directions.** Pass 2's `237 / 100` was measured over one substrate of two and its buckets never summed. **Genuine owner input is 8, not 13 or 14.** Five ids pass 2 added to the manifest had been removed *because the owner decided them on 2026-09-01*. New: **GOV-20**. **GOV-19 widened** from 1 id to 4. GOV-18 is now safe to start.

---

## 1. CURRENT STATE (verified before anything was touched)

Fetched first. `HEAD` = `origin/main` = `ls-remote` = `33a86d697558b169f12ad8c6266d75a8ed5ddbcb`, ahead/behind `0 0`, **clean tree**, **191 migrations**. Repository consistency at that commit: **CLEAN, Checks 1–19, exit 0** — including Check 14, which is itself part of this report's finding.

---

## 2. THE 237-ID CENSUS, RECOMPUTED

### 2a. Pass 2's totals never closed, on its own numbers

Pass 2 reported `237 distinct ids: 131 closed, 35 DESIGN-READY, 71 open or other, i.e. 100 non-closed`.

`131 + 35 + 71 = 237` ✓ — but the non-closed population is `35 + 71 = 106`, or `71` if `DESIGN-READY` is excluded. **Neither is 100.** The figure `100` was never derived from the census that was supposed to produce it, which is why the buckets beneath it summed to **101** in the report and **100** in the register: they were fitted to a total that did not exist.

### 2b. The real defect: the register has two substrates, and the census read one

`Check 11` — the guard that decides whether a finding *exists at all* — is explicit, and its comment says why (MEAS-2, 2026-09-01):

> *"A finding is DEFINED where it is the SUBJECT of a register entry: the first cell of a table row, **or a `###` detail heading**."*

Pass 2 enumerated only the table. Re-run over both substrates, using Check 11's own definition and its own splitting rule for compound ids:

| Substrate | Distinct ids |
|---|---|
| table rows | **250** |
| `###` detail blocks | **112** |
| **union — the true population** | **314** |
| defined **only** by a detail block | **64** |

**`VOID-1`, `RET-1` and `RET-2` have no table row at all.** All three were on the manifest's decision line while being structurally invisible to the census that claimed to have dispositioned every discovered item. So were `DOC-EXP-1`, `AUTH-1`, `SYSADMIN-1`, `SPP-3`, `DEL-1`, `SCHED-1`, `EVT-2`, `FIN-5`, `DELIV-1`, `GOV-15/16/18/19` and 50 others.

Method, stated so it can be re-run: `Status` is table column 9 in both row widths — the 40 narrow rows are the same table with the `Owner Decision` cell omitted, a column *after* Status, so positional extraction is valid for both. Detail-block status is the `**Status:**` field of the block, last block wins.

### 2c. Corrected totals

**314 findings — 163 closed, 151 non-closed.**

---

## 3. DISPOSITION OF ALL 151 NON-CLOSED FINDINGS

| Disposition | Table rows | Detail-only | **Total** |
|---|---|---|---|
| **C — scheduling backlog** (design accepted, batch assigned) | 74 | 2 | **76** |
| **I — DECIDED by the owner 2026-09-01, implementation owed** | 8 | 9 | **17** |
| **E — superseded / terminal by an earlier verdict** | 15 | 2 | **17** |
| **D — engineering defect** | 11 | 5 | **16** |
| **J — closed in substance, unreadable in form** | 15 | 0 | **15** |
| **G — genuine owner business decision** | 6 | 1 | **7** |
| **B — resolved by existing implementation** | 2 | 0 | **2** |
| **H — owner compliance decision** | 0 | 1 | **1** |
| **F — evidence gap** | 0 | 0 | **0** |
| **TOTAL** | **131** | **20** | **151** |

`76+17+17+16+15+7+2+1+0 = 151` ✓  ·  `151 + 163 = 314` ✓  ·  **every non-closed finding carries exactly one disposition, and no bucket is "untriaged".**

**Bucket J is new and is the honest name for something pass 2 miscounted.** Fifteen findings carry a *terminal* verdict written in a form no guard reads — `PROVEN NOT A DEFECT`, `PROVEN INTENTIONAL`, `CONFIRMED and already FIXED`, `CONTROL APPLIED`, `BUILT`, `CORRECTED`, `WIDENED`, `RECONCILED`, `REFACTORED … DEPLOYED`, `DECIDED BY THE OWNER … AND IMPLEMENTED`. They are closed work counted as open. **This is GOV-18's population, now measured rather than estimated.**

---

## 4. THE MATERIAL FINDING: FIVE SETTLED DECISIONS WERE PUT BACK ON THE MANIFEST

`OWNER-1`'s row records that **on 2026-09-01 the owner ratified eighteen decisions**, naming each and its answer, and concludes:

> *"Each remains an ENGINEERING task where implementation is owed; **none is an open QUESTION**."*
> *"**Still genuinely open and unchanged:** RET-1, FIN-7, VOID-1, TRANS-1, DELIV-1, PH8-2, PLAN-1, DOC-LC-2, DOC-LC-3, CANON-26-1, LIC-1"*

**Proven from git history rather than inferred.** The manifest's decision line at `45ba216` and at every revision back through `a52b5c7` reads:

```
OWNER-1 QUO-4 SUP-4c CUST-3 RET-1 FIN-7 VOID-1 VERIFY-1 TRANS-1
DELIV-1 PH8-2 PLAN-1 DOC-LC-2 DOC-LC-3 CANON-26-1 LIC-1 CONV-3
```

`BLOCKED-4`, `BLOCKED-5`, `AUDIT-4`, `RET-2` and `A3` are **absent — they had been removed because they were decided.** Then `b958691` re-added `RET-2`, and `33a86d6` re-added the other four plus `BOOK-2`, under the claim that six ids *"had never been on the manifest line before — GOV-16's real cost, now measured."*

**That claim is true of exactly one id: `BOOK-2`.** The other five were absent by decision. Re-adding them re-created the precise defect `OWNER-1` was raised to record: **settled questions presented to a fresh session as live blockers** — five days after the guard against that class was written, and while quoting it.

### GOV-20 — NEW: a ratification recorded in one row is invisible on the rows it decides

- **Category:** governance / guard coverage (MEAS-1) · **Severity:** High · **Status:** 📋 **OPEN — engineering**
- **Why Check 14 passed.** Check 14 derives its decided-set from **each id's own status cell**, deliberately — its own comment says an exemption list *"would be one more thing to go stale, which is the defect this check exists to catch."* That reasoning is right. But `BLOCKED-4`, `BLOCKED-5`, `AUDIT-4` and `A3` still read `BLOCKED — BUSINESS DECISION` / `OPEN` on **their own** rows, last `Updated` **08-29** and **08-16** — *before* the ratification. `RET-2` has no row at all. The owner's answer lived only inside **`OWNER-1`'s** status cell, as prose about other findings. **A guard that reads status cells cannot see a verdict stored in another row's prose.**
- **The defect is in how the ratification was recorded, not in Check 14's logic.** Eighteen decisions were minuted in one place and never written back to the rows they settled, so since 2026-09-01 the register has asserted both that they are decided and that they are blocked.
- **Corrected at the source:** all 17 recoverable ids now carry the verdict on their own status cell or detail block, in a form Check 2 **and** Check 14 both read — rows `BLOCKED-4`, `BLOCKED-5`, `AUDIT-4`, `A3`, `PH8-3`, `PH8-5`, `PP-1`; blocks `DEL-1`, `RET-2`, `EVT-2`, `SCHED-1`, `FIN-5` ×2, `SYSADMIN-1`, `SPP-3`, `DOC-EXP-1`, `AUTH-1`. `SEC-1` already carried it and was the model. Superseded text retained throughout, per the register's never-delete convention.
- **Mutation-proven in both directions.** *After* the correction, re-adding `BLOCKED-4` to the decision line makes Check 14 fail — `STALE OWNER DECISION: manifest lists 'BLOCKED-4' as open, but the register marks it ✅ DECIDED BY THE OWNER 2026-09-01 (OWNER-1)` — and removing it makes Check 14 pass. The *before* direction needs no experiment: `33a86d6` was committed with Check 14 **clean** and `BLOCKED-4` on the line. That is the finding.
- **What remains for GOV-20 proper:** nothing binds a *ratification record* to the rows it ratifies. The recommended guard reads the ids named inside a reconciliation row's status and asserts each states its own verdict on its own row. Not built here — a new guard needs a mutation proof in both directions (`AGENTS.md §6`), and this task's scope is reconciliation.

---

## 5. OWNER-DECISION RECONCILIATION — the answer is 8

The task asked whether the number is 13, 14, or another number. **It is 8.** Every id below was checked against its current register row, its detail blocks, `OWNER-1`, and git history.

| ID | Substrate | Verdict | On manifest? |
|---|---|---|---|
| **SUP-4c** | row | **G** — genuine, raised 09-04, post-ratification | ✅ keep |
| **CUST-3** | row | **G** — genuine, raised 09-04, post-ratification | ✅ keep |
| **VOID-1** | detail only | **G** — `OPEN — GENUINE BUSINESS DECISION`; in `OWNER-1`'s still-open list | ✅ keep |
| **PLAN-1** | row | **G** — three "Limited" ceilings; in `OWNER-1`'s still-open list | ✅ keep |
| **DOC-LC-3** | row | **G** — canonical contradiction; in `OWNER-1`'s still-open list | ✅ keep |
| **CANON-26-1** | row | **G** — canon amendment; in `OWNER-1`'s still-open list | ✅ keep |
| **BOOK-2** | row | **G** — added 08-30, never surfaced. **The one genuine addition pass 2 made** | ✅ keep |
| **RET-1** | detail only | **H** — compliance; safe default (NULL = retain-forever) already in force | ✅ keep |
| **RET-2** | detail only | **I — DECIDED**: 30-day export window, then purge, legal hold blocking | ❌ **removed** |
| **BLOCKED-4** | row | **I — DECIDED**: commission follows explicit sales ownership | ❌ **removed** |
| **BLOCKED-5** | row | **I — DECIDED**: a consumed trial is never re-granted (SPEC-157 already implements it) | ❌ **removed** |
| **AUDIT-4** | row | **I — DECIDED**: purpose-based consent, separate from ad-click consent | ❌ **removed** |
| **A3** | row | **I — DECIDED**: write the small ADR for the money-storage standard | ❌ **removed** |
| **CAT-6** | row ×2 | **D — identity split**, see §6 | ❌ correctly absent |

**7 genuine business decisions (G) + 1 compliance decision (H) = 8 requiring owner input.**

The `13 / 14 / 11 / 10` confusion is fully explained: **`G = 10` counted table rows** (`SUP-4c`, `CUST-3`, `PLAN-1`, `DOC-LC-3`, `CANON-26-1`, `BOOK-2`, `A3`, `BLOCKED-4`, `BLOCKED-5`, `AUDIT-4`) while **the prose beside it named 13**, adding the three detail-block ids the census could not see. Two populations, one label. Neither number was a miscount; both were answers to different questions.

### Five hidden owner decisions were found, and all five were already answered

The two-substrate census surfaced `DOC-EXP-1`, `AUTH-1`, `SYSADMIN-1`, `SPP-3` and `FIN-5` — each reading `BLOCKED — BUSINESS DECISION` or `BLOCKED — ARCHITECTURAL DECISION`, **`Owner: owner`**, and **none on the manifest**. They looked exactly like hidden decision debt. `OWNER-1` names every one of them among the eighteen the owner ratified. **Checked before escalating, not after** — this is the failure mode pass 2 hit in the other direction.

---

## 6. CAT-6 — investigated, and left off the line

`CAT-6` was named in pass 2's `G` prose but is absent from the manifest, and the task asked why. **Both facts are correct and the contradiction is real.** The register carries **two rows whose subject includes `CAT-6`**: a combined `CAT-5/CAT-6` row marked `✅ RESOLVED 2026-08-24 (SPEC-141)` on **CAT-5's** evidence, and a standalone `CAT-6` row still `OPEN`. Check 14 refused the manifest edit and was right to.

**Leaving it off is correct**: with the register self-contradictory about the id, promoting it to the boot line would publish a question the register also says is answered. It goes on the line when GOV-19 splits the row — not before.

**GOV-19 is widened from 1 id to 4.** The measured MIXED set — one id, opposite verdicts in two rows — is **`ATTR-1`, `CAT-5`, `CAT-6`, `SEC-3`**. `CAT-6` was found only because a guard refused an edit; the other three were never surfaced by any pass. Same defect, same fix.

---

## 7. MANIFEST ↔ REGISTER, both directions

| Direction | Result |
|---|---|
| **A.** every manifest id resolves to exactly one current register definition | ✅ **Check 11: "all 8 manifest decision IDs resolve in the register"** |
| **B.** every genuine owner/compliance decision appears on the manifest | ✅ 7 G + 1 H, all present; the five hidden candidates were all already decided |
| **C.** scheduling backlog absent from the decision line | ✅ 76 items, none on the line |
| **D.** superseded/terminal absent | ✅ 17 E + 15 J, none on the line |
| **E.** engineering defects absent | ✅ 16 D, none on the line — `DELIV-1`, `GOV-15/16/18/19/20` are engineering |
| **F.** evidence gaps | ✅ **0** |
| **G.** no *decided* id on the line | ✅ **Check 14 passes, and now mutation-proven to catch a violation** |
| **H.** no canon doc names a settled finding as current | ✅ **Check 16: "checked against 8 open id(s)"** |

Nothing was solved by hiding a row. Every id removed from the line carries its removal reason on its own row, in the register, in a form two guards read.

---

## 8. THE 69-BACKLOG CLAIM — confirmed, and enlarged to 76

Validated rather than accepted. The register's own header states the policy — a `Required` finding's *design* must exist now and *"**implementation timing belongs only to the owner**"* — and its legend fixes the `Status` vocabulary as `OPEN · DESIGN-READY · RESOLVED · VERIFIED`. The 2026-07-11 Validation reclassifications note already dispositioned the DC family on exactly this axis.

Each of the 76 was checked for an unresolved *choice* as opposed to an unscheduled *build*. **None carries one.** Two were pulled out of the bucket on evidence: `DC-27` (`VALIDATED-REQUIRED`, ADR artifact owed) and `RPC-1` (a programme underway, 10 of 37 permissions closed) — neither is an unanswered question, and neither is plain backlog either. The two additions are the detail-only `CONV-3` (`DEFER — belongs to the integration phase`) and `DC-7` (folds into `R4`).

**Pass 2's central insight stands and is the most valuable thing it produced.** `Owner Decision` *is* a scheduling column; 76 of 151 non-closed findings are a product roadmap. That conclusion survives the recount intact.

---

## 9. CONTRADICTIONS FOUND

1. **Pass 2's totals do not close** — `35 + 71 ≠ 100`; buckets summed to 101 in the report, 100 in the register.
2. **Report and register disagree on `G`** — the report says `11`, the register says `10`, the prose in both names 13.
3. **`OWNER-1` vs 17 rows** — the register asserted since 2026-09-01 that the same findings are both decided and blocked. **GOV-20.**
4. **Five decided ids on the boot line** — `OWNER-1`'s own class of defect, re-created.
5. **Four ids with opposite verdicts in two rows** — `ATTR-1`, `CAT-5`, `CAT-6`, `SEC-3`. **GOV-19 widened.**
6. **15 findings closed in substance, open in form** — bucket J. **GOV-18's population, measured.**
7. **`FIN-5`'s narrowing block** labelled `BLOCKED — BUSINESS DECISION` while its body says *"what remains is EVT-2's class, **not a permission decision**"* and gives a trigger. Corrected with the ratification.

---

## 10. CORRECTIONS MADE

| File | Change |
|---|---|
| `reports/master/MASTER_GAP_REGISTER.md` | 7 table rows + 10 detail blocks now carry the 2026-09-01 ratification on their own status; the `Disposition of all 100` heading marked SUPERSEDED; new **RECONCILIATION** section with the closing totals, **GOV-20**, and **GOV-19 widened** |
| `_ORVION_CANONICAL/manifest.md` | decision line **13 → 8**; census figures corrected to 151/314; `Last Completed`; `Next capability` |
| `reports/README.md` | latest-session pointer |
| `_ORVION_CANONICAL/ai-map.json` | regenerated (Check 7) |

**No historical report was modified.** `session-2026-09-04-decision-census-pass-2.md` stands exactly as committed, including the numbers this report supersedes. **No migration, no test, no guard was changed** — GOV-18 is not started, and Check 2 is untouched.

---

## 11. IS DECISION DEBT FULLY DISPOSITIONED?

**YES.**

- Every one of the **151** non-closed findings, across **both** substrates, carries **exactly one** final disposition.
- The buckets sum to 151; 151 + 163 closed = 314, the full population under Check 11's own definition.
- **`F` (evidence gap) = 0.**
- Every genuine owner decision is identified **exactly once** and appears on the manifest **exactly once**.
- Manifest and register agree, verified mechanically by Checks 11, 14 and 16.
- No backlog item is presented as an owner decision; no decided item is presented as an open question.

**Owner input required: 8** — seven business decisions and one compliance decision.

---

## 12. VERIFICATION

| Check | Result |
|---|---|
| Repository consistency | **CLEAN, Checks 1–19, exit 0** |
| Check 11 | all **8** manifest decision IDs resolve in the register |
| Check 14 | every manifest owner-decision ID is still open — **and now mutation-proven to fail when one is not** |
| Check 16 | no canonical document asserts a current owner decision the manifest does not list (8 ids) |
| Check 5 | manifest **6,947** chars, budget 7,000 — **no budget raised** |
| Migrations | **191**, unchanged — no schema work in this task |

Documentation-only reconciliation: no migration, no test, no guard, no database change. Test suite and parity state are untouched at `191 / 94 files / 1347 assertions`, last proven at `33a86d6`.

---

## 13. NEXT STEP

**GOV-18 is now safe to start**, and the reconciliation has sized it precisely: **15 findings are closed in substance but unreadable in form**, and 35 of 54 open rows use a richer form than the bare `OPEN` cell. Widen Check 2's open-detection with a mutation proof in both directions. No owner input.

Then **GOV-20** (bind a ratification to the rows it ratifies) and **GOV-19** (split the four identity-split ids).

**Batch 6 remains not started**, as instructed.
