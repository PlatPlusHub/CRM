# ORVION — COLD-1: A Restated List Goes Stale, And It Had Happened Four Times

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Scope: Cold-start reliability pass. Booted the repository as a fresh session with no conversation
history and measured what it would misunderstand. **COLD-1** fixed and guarded by **Check 14**.
No migration; the database was not touched.
Status: Complete.

**Branch:** `main` · **Start HEAD:** `e6905cc` · **Environment:** repository = local = Primary at 181.

---

## The test that was actually run

Not "is the documentation tidy" but: *if a different LLM opened this repository tomorrow with zero
conversation history, what would it get wrong?* The boot chain was followed as written — `README.md`
→ `AGENTS.md §4` → `manifest.md` → the register and the plan — and each landing point was checked
against the thirteen cold-start failure modes, prioritising the ones that change a decision.

## FOUND — one class, four instances

**A moving list restated outside its SSOT goes stale.** Three of the four instances presented
already-settled work as a live blocker:

1. **Canon 32's Phase-8 gate list** — and it had already been corrected once, for naming a resolved
   AUDIT-3. Its replacement went stale in turn, naming **DOC-LC-1** (resolved), *"API-3's remaining
   endpoints"* (closed at 71/71), **SPEC-154-B** (shipped) and **SEC-1** (decided) as what keeps the
   gate shut. The paragraph even ended with *"Read Batch 6 for the live list rather than any summary
   of it"* — immediately after giving another summary.
2. **`manifest.md`'s `Next capability`** carried a second copy of the owner-blocker list. After
   **OWNER-1** reconciled the real list two lines above, **the same file asserted both that SEC-1 was
   decided and that it "needs the owner"** — plus stale suite figures (84 files / 1,127 / 366).
3. **`MASTER_EXECUTION_PLAN.md` item 8** still read *"SEC-1 write-path model — remains the open owner
   decision"*.

## WHY IT IS HIGH

Not wording. A fresh LLM reading any of the three would treat a settled architecture as an open
question — and could re-escalate it to the owner, or **propose the RPC-only write model the owner
explicitly rejected**. That is cold-start failure modes 2, 4 and 8 at once, from documents a fresh
session is *instructed* to trust.

## FIXED — by deletion, not refresh

Each restatement now points at the one list that is maintained: `MASTER_EXECUTION_PLAN.md` Batch 6
for engineering, and the manifest's single `Open owner decisions` line for decisions. Canon 32's
paragraph now says outright that it will not enumerate the gate, and records *why* — it has carried a
stale list twice, and a summary of a moving list is a stale list waiting to happen. Same conclusion
**GOV-5**, **REG-2** and **ROAD-1** reached; the third repetition is what made it worth guarding.

## GUARDED — Check 14

> Every id on the manifest's open-decision **enumeration** must still be OPEN in the register.

The decided-set is **derived from the register's own status cells** (the cell-anchored markers Check 2
already uses) — never a list maintained inside the guard, because an exemption list is one more thing
to go stale, which is the very defect this check exists to catch.

**Mutation-tested:** re-listing `SEC-1c` on the open line is reported —
`STALE OWNER DECISION: manifest lists 'SEC-1c' as open, but the register marks it ✅ FIXED …` —
and removing it returns CLEAN.

## THE CHECK IMMEDIATELY FOUND THREE MORE THINGS, ALL FIXED RATHER THAN EXEMPTED

- **PLAN-1's status cell led with "RESOLVED 2026-08-24"** while the row's own body says *"Still open:
  numeric ceilings are readable but nothing counts against them"* and its Owner column names the
  three undefined "Limited" ceilings. A cold reader takes the first word. Now
  **"PARTIALLY RESOLVED … the FEATURE half only"**. My manual reconciliation had already flagged this
  as a detector false positive; the guard proved the *row* was the defect.
- **SEC-1c's status cell led with a reproduction narrative** rather than its verdict, so the outcome
  was not the first thing read — and the guard could not see it was closed. Now leads **"✅ FIXED"**.
- **The check read a *citation* as a blocker.** The manifest legitimately cites the OWNER-1 evidence
  row while explaining the reconciliation; the first version counted every id on the line. Corrected
  to parse only the enumeration after `Genuinely open:`. An exemption for OWNER-1 would have been the
  weaker fix — the boundary is now structural.

## VERIFIED

No SQL changed: repository = local = Primary at **181**, ledger `67a9e05e43c733594a76dd7e6ce6da31`,
functions `d9b0dd9cb6dfaa3ac2f38a9cc7601408` (247), structure `71f87b282df0598ccc100e367e6f7e4c`
(3,373) — proven live earlier today, untouched since. pgTAP **86 files / 1154 assertions**. Repository
guard **CLEAN at 14 checks**. Check 7 caught `ai-map.json` as stale the moment the manifest changed,
which is the source→generate→verify relationship doing its job; regenerated.

## THE COLD-START QUESTIONS, ANSWERED FROM THE REPOSITORY ALONE

Current phase, active CR, next executable step, deployed-vs-local state, which decisions are settled
and which remain the owner's — each now resolves to exactly one document, and the guard fails if the
last of those drifts. The one answer that is still *narrative* rather than mechanical is which
reports are historical; `reports/README.md`'s class header and the `Class:` line on every report
carry it, and Check 4 enforces the header's presence.

## REMAINING

**Recorded, not acted on:** `reports/README.md`'s latest-session row is now roughly 20,000 characters
on one line, chaining every predecessor summary. It is genuinely the fastest way for a cold session to
learn recent history, and Check 10 keeps its head current — but it grows unboundedly and restates
content whose SSOT is each linked report. The trigger suggested at ~20,000 characters has now been
reached. Deliberately left for the owner: trimming it is a judgement about how much narrative belongs
inline, and this pass's mandate was consistency, not redesign.

## NEXT STEP

**ATTR-2 — the remaining `_by` actor columns**, classified per column into caller identity · derived
actor · business fact recorded on behalf of someone else · system actor · historical snapshot ·
unknown, with `payments.received_by` reproduced before anything is changed. Then the care/conversation
slice, whose write-capability half SEC-1c already closed.
