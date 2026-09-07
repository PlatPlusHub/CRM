# ORVION Local-First State Re-Audit

Class: History (immutable)
Date: 2026-09-07
Scope: three-way forensic comparison (local · GitHub · Supabase Primary), local-authority determination, engineering-debt audit, Check 25 second-substrate assessment, RECOVER-1 process review, next-slice re-derivation

---

## 0. HANDOFF

- **INHERITED** — a commissioning instruction built on the premise that **local is the authoritative
  engineering state** and that GitHub/Primary may be behind it. That premise is **false**, and disproving it
  is this report's first finding. Local is a *strict ancestor* of `origin/main`: zero local-only commits,
  zero local-only files, clean working tree.
- **PROVEN** — local `HEAD = 2aaab9d`; `origin/main = ecb8346`; `merge-base = 2aaab9d` (= HEAD), so
  ahead/behind is `0/1`. Migrations byte-identical local↔origin (204 files, empty diff). Primary read live
  this session: ledger `204|e9549f90784fb38b0924b6353a56d94f`, functions `8c012ce5ee5749923d94c0d54e6b867f`
  (277), structure `a48b275de685f89c073058de385d3ad8` (3,563 across ten surfaces) — all three match the
  repository and the manifest. `check_database_parity.ps1` → **DATABASE PARITY: CLEAN**, Primary values read
  FROM Primary (GUARD-1 satisfied).
- **UNPROVEN** — pgTAP, the six HTTP suites and the smoke test were **not re-run this session**; their last
  green is the slice-5 report's, which is HISTORICAL evidence, not live. `db reset` was not run, so per
  PAR-1b the local database is "this database", not proven to be "the repository" — though it agrees with
  the repository on all twelve compared surfaces, which is strong but not the same claim.
- **CHANGED** — nothing in the repository except this report. No migration, schema, guard, script, canon or
  Master document was modified. **No `git pull`, reset, checkout, restore, push or deploy was performed.**
- **DO NOT TOUCH** — do **not** commit anything onto local `HEAD` before fast-forwarding. Local is behind by
  one; committing here converts a trivial fast-forward into a merge and manufactures the divergence this
  audit exists to prevent. Also do not "fix" Check 5 by trimming the manifest again (see §9/§10) — the
  document is not the defect.
- **REMAINING** — four fixable engineering items (§9), three of them **new and found this session**; ten
  genuine business/canon/legal decisions (§8); Check 25's second substrate (§10).
- **NEXT** — fast-forward local to `ecb8346` (`git pull --ff-only`), then land the Check 5 measurement fix.
  Batch 6 slice 6 is **not** started here.

---

## 1. Executive Summary

**LOCAL IS NOT AUTHORITATIVE.** The commissioning premise is inverted, and the evidence is unambiguous:

| Question | Answer | Evidence |
|---|---|---|
| Does local hold work GitHub lacks? | **No** | `git log origin/main..HEAD` → empty |
| Does GitHub hold work local lacks? | **Yes, one commit** | `git log HEAD..origin/main` → `ecb8346` |
| Is local a strict ancestor? | **Yes** | `merge-base HEAD origin/main` = `2aaab9d` = `HEAD` |
| Is there uncommitted local work? | **No** | `git status --short` → empty |
| Do the databases diverge? | **No** | ledger + functions + ten structural surfaces identical |

The divergence is **repository-only, documentation-only, and one commit deep**. Nothing about the database,
migrations, schema, or any deployed artifact is in question: **local == Primary on every measured surface.**

The audit's substantive value is not the divergence — it is **why local looked correct**. Local's
`check_repository_consistency.ps1` prints **CLEAN**. A fresh checkout of *the very same commit* prints
**1 issue**. That is not a stale working copy; it is a **defect in the guard**, and it is the reason the
remote commit exists at all.

---

## 2. Local Repository Truth

```
branch            main
HEAD              2aaab9dc44e428db57204f42fb0c805551138e95
status --short    (empty — clean)
migrations        204 files, latest 202607061500_the_booked_service_itself_had_no_door.sql
ledger (expected) e9549f90784fb38b0924b6353a56d94f
```

**Local-only content: none.** No untracked tracked-worthy files; the only untracked paths are
`.gitignore`-matched (`.claude/settings*.json`, `.obsidian/**`, `supabase/.temp/cli-latest`).
No local-only migrations, tests, scripts, reports or documentation exist.

Guard results on the local working copy:

- `check_repository_consistency.ps1` → **REPOSITORY CONSISTENCY: CLEAN** (Checks 1–25), exit 0
- `check_database_parity.ps1` (three Primary values supplied from live reads) → **DATABASE PARITY: CLEAN**, exit 0

**The first verdict is not trustworthy as stated** — see §9, GUARD-CRLF-1.

## 3. GitHub Truth

`git fetch origin --prune` was run. Fetching updates remote-tracking refs only; it does not touch the
working tree, the index, or any local commit, so it is compatible with the no-overwrite rule and is
mandated by `AGENTS.md §4` step 8 ("**FETCH FIRST, ALWAYS**").

```
origin/main       ecb83464a929a2e59160c640bb4c1e3b0fe5228e
HEAD...origin/main  0 ahead / 1 behind
```

The single remote-only commit:

```
ecb8346  fix(sync): the manifest crossed its own budget by three characters
         _ORVION_CANONICAL/manifest.md | 2 +-
         ai-map.json                   | 6 +++---
```

**Classification: LEGITIMATE, non-destructive, documentation-only.** It trims one clause from the manifest's
`Last Completed` field and regenerates `ai-map.json` (regenerated, not hand-edited — `GOVERNANCE.md §6`
rule 4). It touches **no** migration, schema, guard, test or canon file. It is a normal continuation of the
same authorship (`PlatPlusHub`, same day, 2026-09-07 16:07 +0300) as local `HEAD`.

It is therefore **not** stale, accidental, superseded, or a cloud-only artifact. It is simply the next commit,
made from a working copy this machine has not yet fetched into.

## 4. Supabase Primary Truth

Target ref proven by live read, not transcription (`AGENTS.md §4` step 8c/11):
`get_project_url` → `https://vrvtsxexkiiiivlkdxzp.supabase.co` = Primary. Secondary
`brplkqmbzffpxqgkkdzo` was not contacted and is never a target from this repository.

All three parity values read **live, from Primary**, using the guard's own expressions and
`scripts/parity_surface.sql` (both sides run the same file — PAR-1a/PAR-3):

| Surface | Primary | Repository / local | Verdict |
|---|---|---|---|
| Migration ledger | `204 \| e9549f90784fb38b0924b6353a56d94f` | `204 \| e9549f90784fb38b0924b6353a56d94f` | **identical** |
| Function surface | `8c012ce5ee5749923d94c0d54e6b867f` (277) | same (277) | **identical** |
| Structural `_combined` | `a48b275de685f89c073058de385d3ad8` (3,563) | same (3,563) | **identical** |

Per-surface breakdown, Primary and local identical on every one:
functions 277 · triggers 273 · policies 124 · constraints 498 · grants 792 · columns 1,097 · views 16 ·
indexes 293 · status_transitions 115 · rls_enabled 78.

Primary's latest applied migration is `202607061500`, matching the repository's newest file exactly.
**Primary is SAME AS LOCAL — not ahead, not behind, not different in content or order.**

## 5. Three-Way Difference Matrix

| Surface | Local | GitHub | Primary | Difference | Authority |
|---|---|---|---|---|---|
| Repository commits | `2aaab9d` | `ecb8346` | n/a | GitHub +1 (ancestor relation) | **GitHub** |
| Migrations (files) | 204 | 204, identical | n/a | none | tie |
| Migration ledger | `e9549f90…` | same | `e9549f90…` | none | tie |
| Functions | 277 / `8c012ce5…` | same | 277 / `8c012ce5…` | none | tie |
| Schema columns | 1,097 / `b3ebf52e…` | same | identical | none | tie |
| Triggers | 273 / `debe2ad0…` | same | identical | none | tie |
| Policies | 124 / `8e641292…` | same | identical | none | tie |
| RLS enablement | 78 / `fbd0240f…` | same | identical | none | tie |
| Grants | 792 / `8fc4794a…` | same | identical | none | tie |
| Constraints | 498 / `6cf13e57…` | same | identical | none | tie |
| Views | 16 / `10bb212a…` | same | identical | none | tie |
| Indexes | 293 / `71855556…` | same | identical | none | tie |
| Status transitions | 115 / `db2165c7…` | same | identical | none | tie |
| Tests | 105 files | identical | n/a | none | tie |
| Consistency guards | identical source | identical source | n/a | **verdict differs by checkout** | see §9 |
| `manifest.md` | 6,943 chars (LF) | 6,836 chars | n/a | GitHub trimmed 107 chars | **GitHub** |
| `ai-map.json` | `generated_at 10:44:32Z` | `12:57:56Z` | n/a | regenerated | **GitHub** |
| Canonical docs (all others) | identical | identical | n/a | none | tie |

Only **two files** differ across all three environments, and both are documentation.

## 6. Local Authority Determination

**Verdict: LOCAL IS NOT AUTHORITATIVE. GitHub (`origin/main`) is authoritative for the repository;
local and Primary are jointly authoritative and identical for the database.**

Local cannot be authoritative because it contains **nothing that origin does not**. Authority requires
holding some correct state the other lacks; local holds none. This is the strongest possible form of the
answer — not "origin's changes look better", but "local is a subset, so there is nothing to protect".

The instruction's protective intent is nonetheless **fully honoured**: nothing was pulled, reset, restored,
checked out, pushed or deployed, and the classification was completed *before* any reconciliation was
proposed. The protection simply turned out to have nothing to protect.

**Why local *appeared* authoritative — and this is the real finding.** Local's guard says CLEAN. The remote
commit says Check 5 measured 7,003 against a 7,000 budget. Both are true, on the same bytes:

```
working copy (LF):        6,943 chars  → Check 5 PASSES
fresh clone, same commit: 7,003 chars  → Check 5 FAILS   (+60 = exactly the line count)
```

Reproduced by cloning `2aaab9d` into a scratch directory: the checkout materialised CRLF (`core.autocrlf=true`,
no `.gitattributes`), and the identical commit failed its own guard. Local's CLEAN was an artifact of its
line endings, not evidence of correctness — which is precisely the class `AGENTS.md §6` names:
*a green guard proves only the property it actually measures.*

## 7. Synchronization/Reconciliation Required

Required direction is **GITHUB → LOCAL**, which is the direction the commissioning instruction defaults to
forbidding. Under §4 and §16 of that instruction ("if it contains legitimate work that local lacks, **STOP
and report it before overwriting local**"), the comparison is complete, the commit is classified legitimate,
and the action is therefore **reported, not taken**.

**Nothing was synchronized in this session.** The recommended reconciliation is:

```
git pull --ff-only          # 2aaab9d → ecb8346; fast-forward, no merge commit, nothing discarded
```

It is safe and lossless: the working tree is clean, there are no local commits, and the only local file not
in git is this report (untracked files survive a fast-forward untouched).

**Database: no action.** Local == Primary on all twelve surfaces. §19's "if already identical, do not perform
unnecessary deployment" applies — synchronization is *proven*, not performed.

## 8. Current Open Findings

Re-derived from `MASTER_GAP_REGISTER.md` this session, not inherited from the previous report:

**Closed, confirmed:** BOOK-3, BOOK-4, BOOK-5, BOOK-6, BOOK-7 — all `✅ FIXED 2026-09-07 (202607061500)`.
CAT-6 — `RESOLVED 2026-09-07 (GOV-19 split)`. GOV-16, GOV-19 — fixed. RECOVER-1 — CLOSED (§11).

**Genuine business / canon / legal decisions (10), each verified *not* an engineering question in disguise:**
MAIL-1 (provider + Egyptian PDPC cross-border licence) · RET-1 (retention periods — counsel's) ·
AUDIT-2 · PD-23 · FA-2 · MONEY-2 · PAX-5 · PAX-6 · BOOK-8 · BOOK-9.
All ten are named on the manifest's boot line; Check 11 resolves all of them in the register; Check 14
confirms none is already decided; Check 25 confirms no *table-row* decision is unsurfaced.

**Open engineering (unscheduled, not blocked by any decision):** PAX-4 · CUST-6 · IDENT-2 · DELIV-1 ·
GOV-20 · DOC-LC-3 · PH8-2, plus the RBAC-6 class.

**No new finding appeared after Slice 5 in the register itself** — but three new findings appeared in this
audit (§9), all in the *measuring* layer rather than the measured one.

## 9. Engineering Debt Audit

### FIXABLE NOW

**GUARD-CRLF-1 — Check 5 measures line endings, not document size. (NEW, proven by experiment.)**
`check_repository_consistency.ps1:443` computes `(Get-Content $mfPath -Raw).Length`. Under CRLF that counts
one extra character per line, so `manifest.md` measures 6,943 on an LF checkout and **7,003** on a CRLF
checkout of the identical commit, against a 7,000 budget. Same bytes in git, opposite verdicts.

*Consequence already paid:* commit `ecb8346` deleted a real clause from the manifest — BOOK-3's attack
narrative ("a `trainee` created a bare booked service and could then rewrite, redenominate, reassign and
re-parent it") — to satisfy a 3-character overage **that only exists on CRLF checkouts**. The budget was
correctly not raised; but the subject that should have been fixed was the guard, not the document.
`AGENTS.md §6`: *"If a guard's description is stronger than its measurement, **fix the guard** — that is the
finding."* This is the same family as the immediately preceding commit `93373ec` ("Check 12 was measuring a
timezone, not a defect"), and as VER-1, MEAS-1, PAR-1a and GOV-11.

*Fix:* normalise before measuring — one line, no new source of truth, no second parser:
`$mfChars = ((Get-Content $mfPath -Raw) -replace "`r`n", "`n").Length`.
Blast radius is exactly this one line: `$mfLines`, `$mfLongest` and `$pointerBudget` all use `Get-Content`
without `-Raw`, which strips line endings and is already CRLF-safe.
*Attack it in both directions before trusting it* (`AGENTS.md §6`): a CRLF checkout must now pass, and a
genuinely over-budget manifest must still fail, on both line-ending forms.
*Secondary effect, same root cause:* `ai-map.json`'s `next_capability` value alternates between `\n\n` and
`\r\n\r\n` depending on which machine regenerates it — visible in `ecb8346`'s diff — producing cross-machine
churn in a generated file. A repository-level `.gitattributes` (none exists) is the durable answer.
**Blocked only by ordering:** it must land on top of `ecb8346`, not on local `HEAD` (see §14).

**DISP-DRIFT-1 — `MASTER_SURFACE_DISPOSITION.md` contradicts itself two lines apart. (NEW.)**
Line 45: "**6 of 77 recorded · 3 `AUDITED` · 3 `AUDITED-OPEN` · 71 `NOT-RECORDED`**" (correct; 3+3+71=77,
independently confirmed by column tally). Line 47: "**All 5 recorded surfaces stand at `ADVERSARIAL`**" —
stale, missed when slice 5 added `booking_items`. All six *are* `ADVERSARIAL`; only the count is wrong.
No guard catches it: Check 22 validates rows, Check 24 validates the `ADVERSARIAL` claim, neither reads this
prose sentence. *Fix:* one word.

**SELECT-1 — the next-slice justification is a windowing artifact. (NEW, and it propagates.)**
`manifest.md`, `ai-map.json` and the execution plan all state that "on EXPOSURE `otp_challenges` **leads** at
11". Re-run with `-Top 71` (the script defaults to `-Top 12`), `otp_challenges` ranks **12th of 71** on
exposure: `leads` 22, `invoices` 18, `customers` 17, `quotations` 15, `users` 15, `offline_conversions` 14,
`suppliers` 13, `trusted_devices` 12, `documents` 12 all exceed it. The claim was read off the default
12-row view and generalised to all 71. The *second* half of the justification survives verification:
`otp_challenges` **is** the only NOT-RECORDED surface carrying **both** PII and an unguarded write path
(the only other unguarded surfaces are `trusted_devices` and `totp_enrollments`, both PII 0).
*Fix:* correct the sentence in all three places; the recommendation itself survives on the criterion that
is true (§13).

### FIXABLE, BUT NOT A DRIVE-BY

**Check 25's second substrate** — see §10. Real blind spot; currently conceals nothing; needs a design
decision plus a counterexample battery, so it is its own package.

### NOT RESOLVABLE NOW, WITH REASONS

PAX-4, CUST-6, IDENT-2, DELIV-1, GOV-20, DOC-LC-3, PH8-2 — each is registered open engineering with its own
recorded rationale. None was re-opened or re-litigated here, and none blocks the reconciliation in §7.
They are *not* deferred on grounds of "later slice" or "low priority"; they are outside the scope of a state
re-audit and each already carries its trigger in the register.

## 10. Check 25 Second-Substrate Assessment

**Status re-derived, not inherited. The previous report's claim is CONFIRMED still true.**

*Exactly what it scans:* `foreach ($line in ($registerRaw -split "\n"))` with `if ($line -notmatch '^\|')
{ continue }` and `if ($cells.Count -lt 13) { continue }` — **table rows only**; id from cell 1, status from
cell 9, decider from cell 10.

*Exactly what it misses:* `###` detail blocks. The register has **176 `###` blocks / 127 block subjects**
against 271 table-row subjects, and **79 ids are defined by a detail block with no table row at all** —
including `RECOVER-1` and `GOV-16` themselves.

*Can the second substrate be parsed reliably?* **Yes, and the parsers already exist in the same file** —
this is the strongest argument for the fix. Check 2 already reads detail-block `**Status:**` fields with the
GOV-11 anchor (verdict taken from the marker *immediately after* `**Status:**`, precisely so a later "fixed"
clause cannot exonerate a BLOCKED block). Check 11 already defines finding existence across **both**
substrates: *"the first cell of a table row, **or a `###` detail heading**."* Check 25 is the only one of the
three that is single-substrate. It can reuse both canonical definitions and create no second source of truth.

*Does the semantic decision signal exist there?* **Yes.** Blocks carry an explicit `**Owner:**` field on the
same combined bullet: `- **Category:** … · **Severity:** … · **Status:** … · **Owner:** owner`.

*Does combining create duplicate ids?* **Yes — and this is the real obstacle, not the parsing.** A `###`
block is an *append-only narrative*: **SEC-1 has four blocks, SCHED-1 has two.** "The status of id X" is
therefore not well-defined in that substrate without a precedence rule (latest block? most terminal verdict?
the one the table row points at?). Check 2 sidesteps this because it hunts *contradictions*, which is
order-insensitive; Check 25 asks "is X **still** awaiting a decider", which is order-**sensitive**. That rule
does not exist canonically yet, and inventing it casually risks false positives — whose only cheap cure is
editing the register to silence the guard, the exact move `AGENTS.md §6` forbids.

*Measured blast radius — would fixing it surface anything today?* A probe applying Check 25's verbatim
`deciderRx`/`resolvedRx` to the block substrate returned **3 candidates: SCHED-1, SEC-1, SUP-4b.** All three
were then verified by hand against the register, and **all three are already decided**:
SCHED-1 `✅ RESOLVED 2026-09-01 (OWNER-1)`; SEC-1 `✅ RATIFIED BY THE OWNER 2026-09-01 (OWNER-1)`;
SUP-4b `✅ DECIDED BY THE OWNER 2026-09-04 AND IMPLEMENTED (202607060100)`. The probe misread them because it
picked up each block's `**Superseded:** BLOCKED …` prose as the verdict — **the probe reproduced the GOV-11
defect on its first attempt**, which is the most useful single data point in this assessment.

**Recommendation: FIX — as its own governance-guard package, next after GUARD-CRLF-1; not merged into any
slice.** It is objectively fixable and the blind spot is real. It is *not* urgent: measured, it currently
hides **zero** open decisions, so the manifest's ten-decision boot line is complete as far as this substrate
is concerned. The package must deliver (a) a block-precedence rule, (b) reuse of Check 2's anchor and
Check 11's subject definition rather than a third parser, (c) suppression of non-finding `###` headings —
the probe surfaced `The`, `What`, `Why`, `Where`, `Disposition`, `Verification` as spurious subjects — and
(d) a counterexample battery in both directions over all 127 block subjects.

## 11. RECOVER-1 Process Assessment

**RECOVER-1 remains CLOSED. It is not reopened, and this session found no new engineering defect in it.**

Check 19 passes: the recorded Primary ledger evidence agrees exactly with the repository (204,
`e9549f90784fb38b0924b6353a56d94f`, read 2026-09-07T08:05:00Z from `vrvtsxexkiiiivlkdxzp` at commit
`6ee6392`), and I independently re-read Primary live this session and got the same values.

On the observation that `202607061500` reached Primary before the commit: classification **(A) + (C)** —
an already-closed historical failure mode, plus a process note. No second synchronization mechanism is
justified, and none is proposed.

**The more interesting result is that RECOVER-1's guard demonstrably WORKED this session.** The divergence
that this entire audit turns on was caught at boot by `.claude/hooks/session-state.ps1`, which fetches and
prints ahead/behind and names its own provenance (*"because two sessions had diverged from one base without
fetching"*), emitting `behind 1 vs upstream … AGENTS.md §4 step 8 applies`. Without it, this session would
have begun by trusting a CLEAN guard on a stale base — RECOVER-1's exact precondition.

**Residual gap, recorded rather than fixed:** the hook *script* is version-controlled, but its *activation*
lives in `.claude/settings.json`, which is `.gitignore`d (line 37). No tracked file under `scripts/` or
`.github/` compares `main` against `origin/main` — `AGENTS.md §4` step 8's statement that "nothing in this
repository compares local `main` against `origin/main`" is still literally true of the guard suite and CI.
So a fresh clone, or the same repository on a second machine, boots with **no** divergence warning. That is
classification **(C)**, optionally **(D)**: a lightweight, honest fix is to track the hook's wiring (or add
the ahead/behind report to the boot output), and it is deliberately **separate from RECOVER-1**, which stays
closed.

## 12. Batch 6 Status

**6 of 77 surfaces recorded — verified by column tally, not by reading the sentence.**
3 `AUDITED` + 3 `AUDITED-OPEN` + 71 `NOT-RECORDED` = 77 exactly; no surface is double-counted or omitted.
Check 22 independently confirms all 77 migration-derived surfaces have a disposition row and that every
vocabulary value, session pointer and finding id resolves. Check 24 confirms all six `ADVERSARIAL` labels are
earned by a declaring test file with negative assertions. The selector independently reports **71 candidates
still at NOT-RECORDED**, agreeing with the register.

EC-1…EC-11 were not weakened, and EC-1 correctly stands at 6 of 77. The one defect is prose, not structure:
**DISP-DRIFT-1** (§9) — line 47 still says "All **5** recorded surfaces" beside line 45's correct 6.

## 13. Recommended Next Step

**Fast-forward local to `origin/main` (`git pull --ff-only`), then fix Check 5 (GUARD-CRLF-1).**
Not Slice 6, and not otp_challenges yet.

The fast-forward is first because every other repair must land on the authoritative tip; committing anything
onto `2aaab9d` manufactures a divergence. GUARD-CRLF-1 is next because until it is fixed, *no* CLEAN verdict
from `check_repository_consistency.ps1` can be quoted without naming the checkout's line endings — which
disqualifies the guard as evidence for every subsequent package. DISP-DRIFT-1 and SELECT-1 are one-line
corrections that ride along in the same commit.

**On Slice 6 (re-derived, per §14 of the instruction):** the previous recommendation of `otp_challenges`
**stands, but its stated reason does not.** The exposure-leadership claim is false (rank 12 of 71 —
SELECT-1). The surviving and sufficient criterion is that `otp_challenges` is the **only** NOT-RECORDED
surface carrying **both** PII and an unguarded write path, on a pre-authentication surface where an
unguarded write is most consequential. Two siblings deserve naming in the same breath and were not:
`trusted_devices` (exposure 12 — *higher* than otp_challenges — unguarded, PII 0) and `totp_enrollments`
(exposure 8, unguarded). They form one MFA/device-trust family and are the natural slice 6–8 sequence.

## 14. What Must NOT Be Done

- **Do not commit onto local `HEAD`.** It is one behind; a commit here turns a fast-forward into a merge.
- **Do not `git pull` without `--ff-only`**, and do not force-push, reset, or rebase. There is nothing local
  to preserve, but there is also no reason to rewrite anything.
- **Do not deploy anything to Primary.** It is already identical on all twelve surfaces. §19 forbids
  unnecessary deployment; §15 forbids deploying an uncommitted migration, and there is no migration here.
- **Do not trim `manifest.md` again to make Check 5 pass.** The document is not the defect (§9).
- **Do not raise the 7,000 budget.** `AGENTS.md §6` forbids it, and it would mask the real defect twice over.
- **Do not quote a CLEAN `check_repository_consistency.ps1` as evidence** until GUARD-CRLF-1 is fixed,
  without stating the checkout's line endings.
- **Do not start Batch 6 slice 6.**

## 15. Required Preconditions

Before the next implementation package:

1. Local fast-forwarded to `ecb8346`; `git rev-parse HEAD` == `git rev-parse origin/main`.
2. GUARD-CRLF-1 fixed and attacked in both directions on both line-ending forms.
3. DISP-DRIFT-1 and SELECT-1 corrected (manifest, `ai-map.json` regenerated, execution plan).
4. `check_repository_consistency.ps1` CLEAN **on a fresh checkout**, not only on this working copy.
5. Full `§5a` protocol re-run — this session proved neither pgTAP, HTTP, nor smoke.

## 16. Final Synchronization Evidence

| Claim | Verdict | Evidence class |
|---|---|---|
| Local Git == GitHub | **FAIL** — behind 1 (`2aaab9d` vs `ecb8346`) | REPOSITORY |
| Local DB == Primary DB | **PASS** — ledger, functions, ten structural surfaces | LOCAL RUNTIME + PRIMARY |
| Repository Consistency | **CLEAN on this working copy; 1 issue on a fresh checkout** | REPOSITORY (defective — §9) |
| Database Parity | **CLEAN** (exit 0), Primary values read FROM Primary | PRIMARY |
| pgTAP / HTTP / smoke | **UNPROVEN this session** (not re-run) | — |
| CI | **not consulted this session** | — |

## 17. Future-LLM Handoff

Read this before re-deriving anything:

1. **The premise that local leads is false and was disproved, not assumed.** If a future instruction repeats
   it, re-check `git merge-base HEAD origin/main` first: if it equals `HEAD`, local is a strict ancestor and
   there is nothing to protect. **Fetch first, always.**
2. **`check_repository_consistency.ps1`'s CLEAN is line-ending dependent until GUARD-CRLF-1 is fixed.**
   A working copy whose files were *written by a tool* keeps LF and passes; a *fresh checkout* under
   `core.autocrlf=true` with no `.gitattributes` gets CRLF and can fail Check 5 on the same commit. If local
   and CI ever disagree about Check 5, this is why.
3. **Check 25 is table-rows-only, and that is a real blind spot that currently hides nothing** (measured:
   3 candidates, all three already decided). Do not "discover" it again — read §10, which already contains
   the parser inventory, the duplicate-id obstacle (SEC-1 ×4 blocks, SCHED-1 ×2) and the package shape.
4. **`otp_challenges` does not lead on exposure** (rank 12 of 71). The selector's default is `-Top 12`; pass
   `-Top 71` before quoting any ranking claim from it.
5. **The database needs nothing.** Local and Primary agreed on all twelve compared surfaces on 2026-09-07.
6. **Nothing in this session was committed or pushed.** This report is untracked until someone commits it,
   and it must be committed *after* the fast-forward, not before.

End of Report.
