# ORVION Measurement-Layer Repair and Re-Verification

Class: History (immutable)
Date: 2026-09-07
Scope: GitHub→local fast-forward, GUARD-CRLF-1 / DISP-DRIFT-1 / SELECT-1 repair, full §5a re-verification, documentation resynchronization

---

## 0. HANDOFF

- **INHERITED** — the accepted evidence base of `session-2026-09-07-local-first-state-reaudit.md`: local was a
  strict ancestor of `origin/main` (behind 1, clean tree), the databases were identical, and three
  measurement/documentation defects were proven but deliberately left unfixed because committing onto a stale
  base would have turned a fast-forward into a merge.
- **PROVEN** — this session ran, and observed the real output of: `git pull --ff-only`
  (`2aaab9d`→`ecb8346`), `npx supabase db reset` (204 migrations replayed clean), **Pass A 105 files / 1,646
  assertions**, **six HTTP suites 430 passed / 0 failed**, **Pass B 105 / 1,646 (= Pass A)**, smoke
  **ALL CHECKS PASSED (77 tables)**, `check_database_parity.ps1` **CLEAN** with all three Primary values read
  live FROM Primary, `check_repository_consistency.ps1` **CLEAN (Checks 1–25)**, and a **nine-case
  GUARD-CRLF-1 battery including defect injection**.
- **UNPROVEN** — nothing material. The one honest limit: the CI run recorded below is the run for `ecb8346`;
  the run for this session's own commit is named in §13 and was observed after the push.
- **CHANGED** — `scripts/check_repository_consistency.ps1` (GUARD-CRLF-1, one measurement line),
  `reports/master/MASTER_SURFACE_DISPOSITION.md` (DISP-DRIFT-1, one word), `_ORVION_CANONICAL/manifest.md`
  (SELECT-1 + Last Completed + Narrative), `ai-map.json` (regenerated), `reports/README.md` (pointers), plus
  the two session reports. **No migration, schema, function, trigger, policy or grant was touched, and
  nothing was deployed to Primary.**
- **DO NOT TOUCH** — the 7,000-character manifest budget (it is not the defect and was not raised); the
  `otp_challenges` Slice 6 target (only its *justification* was wrong); `session-2026-09-07-current-state-and-next-step.md`
  and every other immutable report carrying the old SELECT-1 wording — they are historical evidence and are
  superseded by pointer, never rewritten.
- **REMAINING** — Check 25's second substrate (still classified FIXABLE, still its own package — §8);
  the ai-map CRLF diff-churn (recorded, not fixed — §9); the RECOVER-1 residual process gap (§10);
  the seven open engineering findings (§11).
- **NEXT** — Batch 6 slice 6, `otp_challenges`, on the corrected criterion in §12. Not started here.

---

## 1. Pre-State

| Fact | Value |
|---|---|
| HEAD | `2aaab9dc44e428db57204f42fb0c805551138e95` |
| origin/main | `ecb83464a929a2e59160c640bb4c1e3b0fe5228e` |
| merge-base | `2aaab9d` (= HEAD → strict ancestor) |
| ahead / behind | 0 / 1 |
| working tree | clean (only the untracked audit report) |

Re-confirmed immediately before the fast-forward; every value matched the audit exactly, and the remote-only
commit was verified to be the one described (`ecb8346`, touching only `_ORVION_CANONICAL/manifest.md` and
`ai-map.json`). No stop-condition from §23 was triggered.

## 2. Fast-Forward Evidence

```
$ git pull --ff-only
Updating 2aaab9d..ecb8346
Fast-forward
 _ORVION_CANONICAL/manifest.md | 2 +-
 ai-map.json                   | 6 +++---
 2 files changed, 4 insertions(+), 4 deletions(-)

HEAD       = ecb83464a929a2e59160c640bb4c1e3b0fe5228e
origin/main= ecb83464a929a2e59160c640bb4c1e3b0fe5228e   → equal
ahead/behind = 0 / 0
```

The untracked audit report survived untouched, as intended. No merge commit, no rebase, no reset, no force.

**The fast-forward immediately produced the session's most useful measurement.** Checking out those two files
made git apply `core.autocrlf=true` (there is no `.gitattributes`), so the working copy flipped from LF to
CRLF *mid-session*:

| | before pull (LF) | after pull (CRLF) |
|---|---|---|
| `manifest.md` on disk | 6,943 chars | **6,896 chars** (6,836 logical + 60 line endings) |

That is GUARD-CRLF-1 reproducing itself live, on the real repository, without any fixture.

## 3. GUARD-CRLF-1 — Root Cause

`scripts/check_repository_consistency.ps1` Check 5 measured:

```powershell
$mfChars = (Get-Content $mfPath -Raw).Length
```

`-Raw` returns the bytes **as checked out**. Under CRLF every line contributes one extra character, so the
count is `logical + lineCount`. With a 60-line manifest that is a fixed +60 offset against a 7,000 budget,
and the **same commit** therefore measures differently on two machines:

```
commit 2aaab9d, LF working copy   : 6,943  → CLEAN
commit 2aaab9d, fresh checkout    : 7,003  → 1 issue    (+60 = exactly the line count)
```

**It had already cost the repository real content.** Commit `ecb8346` exists solely to clear that phantom
3-character overage, and it did so by deleting a true clause from the manifest — BOOK-3's attack narrative
("a `trainee` created a bare booked service and could then rewrite, redenominate, reassign and re-parent
it"). The budget was correctly not raised; but the subject that needed fixing was the guard, not the document.

**Why nothing caught it:** GitHub Actions checks out on Ubuntu with LF, so CI measured 6,836/6,943 and was
green every time. The defect was reachable **only** from a Windows checkout, which is also the only place
engineering actually happens. A guard that disagrees with its own CI depending on the operating system is
measuring the environment, not the artifact.

This is the class `AGENTS.md §6` already names — *"a green guard proves only the property it actually
measures … if a guard's description is stronger than its measurement, **fix the guard** — that is the
finding"* — and the family is now long: VER-1, MEAS-1, PAR-1a, PAR-3, SEC-1b, GUARD-1, GOV-11, and the
Check 12 timezone defect fixed one commit before this one.

## 4. GUARD-CRLF-1 — The Repair

One measurement line, normalising line endings before counting. The budget is **unchanged at 7,000**, no
exemption was added, no second parser was created, and no platform branch was introduced:

```powershell
$mfChars = ((Get-Content $mfPath -Raw) -replace "`r`n", "`n").Length
```

Blast radius is exactly this line. The two neighbouring measurements were checked and need no change:
`$mfLines` and `$mfLongest` both use `Get-Content` **without** `-Raw`, which strips line endings already, so
neither was ever affected. The fix is documented in-file in the established finding-comment style.

**Deliberately NOT done:** no `.gitattributes` was introduced. §5 of the commission forbids using one as a
substitute for fixing Check 5, and the evidence does not independently justify a repository-wide
line-ending rewrite — see §9.

## 5. GUARD-CRLF-1 — Adversarial Evidence

Nine cases, run entirely in a scratch clone; the real repository was never mutated to produce a fixture. The
oversized fixture exceeds the budget by **logical content** (five appended prose lines, ~1,000 characters),
not by line-ending expansion. The decisive fixture is real repository history: the pre-`ecb8346` manifest,
whose logical length (6,942) sits *under* the budget while its CRLF length (7,001) sits *over* it — the only
shape that can tell the two implementations apart.

**Repaired guard — the verdict must follow logical content, never line endings:**

| Fixture | Ending | logical (LF) | on disk | Check 5 | Expected |
|---|---|---|---|---|---|
| current manifest | LF | 6,835 | 6,835 | PASS | PASS |
| current manifest | CRLF | 6,835 | 6,894 | PASS | PASS |
| boundary manifest (`2aaab9d`) | LF | 6,942 | 6,942 | PASS | PASS |
| **boundary manifest (`2aaab9d`)** | **CRLF** | **6,942** | **7,001** | **PASS** | **PASS** |
| oversized (+1,000 logical) | LF | 7,840 | 7,840 | **FAIL** | FAIL |
| oversized (+1,000 logical) | CRLF | 7,840 | 7,904 | **FAIL** | FAIL |

**Mutation / defect injection — the normalisation reverted, nothing else changed:**

| Fixture | Ending | on disk | Check 5 | Expected |
|---|---|---|---|---|
| boundary manifest | LF | 6,942 | PASS | PASS |
| **boundary manifest** | **CRLF** | **7,001** | **FAIL** | **FAIL** ← the original defect, reproduced |
| oversized | CRLF | 7,904 | FAIL | FAIL |

```
BATTERY: ALL CASES AS EXPECTED
```

This proves both directions: line-ending conversion **cannot** change the semantic verdict, a genuine logical
overage **still** fails on both forms, and the normalisation line is **load-bearing** — remove it and the
defect returns immediately. The harness also asserted the mutation actually applied, so a silently failed
substitution could not have produced a false green.

## 6. DISP-DRIFT-1 — Repair

`MASTER_SURFACE_DISPOSITION.md` contradicted itself two lines apart: line 45 read
"**6 of 77 recorded · 3 `AUDITED` · 3 `AUDITED-OPEN` · 71 `NOT-RECORDED`**" while line 47 still read
"**All 5 recorded surfaces stand at `ADVERSARIAL`**", missed when slice 5 added `booking_items`.

Corrected `5` → `6`. **The disposition rows were not touched** — the prose was wrong, not the data. Verified
by re-deriving from the table itself rather than from either sentence (5 legend rows excluded):

```
77 surface rows = 71 NOT-RECORDED + 3 AUDITED + 3 AUDITED-OPEN      (3 + 3 + 71 = 77)
recorded surfaces, all six at ADVERSARIAL:
  booking_item_passengers [AUDITED-OPEN]  booking_items [AUDITED-OPEN]  financial_accounts [AUDITED-OPEN]
  campaign_daily_metrics  [AUDITED]       company_assets [AUDITED]      exchange_rate_adjustments [AUDITED]
```

**No new guard was built for this.** Check 22 already validates the rows and Check 24 already makes
`ADVERSARIAL` cost something; a third mechanism to police one adjacent English sentence would add a parser
and a second source of truth for a one-word defect, which Earn-It and One-Authority both refuse. Recorded as
a known residual instead: prose adjacent to a generated-by-hand count is not machine-checked.

## 7. SELECT-1 — Repair

The false claim — "on EXPOSURE `otp_challenges` **leads** at 11" — existed in exactly two current-state
locations, confirmed by repository-wide search: `_ORVION_CANONICAL/manifest.md` and its generated copy in
`ai-map.json`. `MASTER_EXECUTION_PLAN.md` was checked and carries **no** equivalent claim (its three
`otp_challenges` mentions concern the identity domain and consumer counts).

Re-derived with the complete candidate set (`-Top 71`, not the default `-Top 12` that produced the error):

```
exposure ranking, all 71 NOT-RECORDED candidates:
  leads 22 · invoices 18 · customers 17 · quotations 15 · users 15 · offline_conversions 14
  suppliers 13 · trusted_devices 12 · documents 12 · customer_contact_methods 11 · otp_challenges 11 …
  otp_challenges exposure rank = 12 of 71
surfaces with an unguarded write path: trusted_devices (PII 0) · otp_challenges (PII 1) · totp_enrollments (PII 0)
surfaces with BOTH PII and an unguarded write path: otp_challenges — the only one
```

The manifest now states the true rank (**12th of 71**) and rests the recommendation on the criterion that
survived verification, naming the correction so the next reader knows *why* the wording changed. `ai-map.json`
was **regenerated** through `scripts/repository-all.ps1`, never hand-edited (`GOVERNANCE.md §6` rule 4), and
the regenerated file was re-read to confirm it carries the corrected text. The phrase "leads at 11" now
occurs exactly once in current-state documentation — inside the sentence that labels it false.

No replacement ranking claim was invented: the only ranking assertion now made is the explicit, complete
"12th of 71".

## 8. Check 25 — Decision

**Not implemented, and that is the deliberate outcome.** The classification from the audit stands unchanged:
**FIXABLE, but its own governance-guard package.** Check 25 still scans table rows only; the register still
defines 79 ids by detail block alone.

The reason it was not done as part of this package is recorded evidence, not caution: `###` blocks are an
**append-only narrative**, so an id can carry several (`SEC-1` has four, `SCHED-1` has two) and "the status of
X" is not well-defined without a precedence rule that does not exist canonically. The audit's probe
demonstrated the cost of guessing one — it read each block's `**Superseded:** BLOCKED …` prose as the current
verdict and so **reproduced the GOV-11 defect on its first attempt**, flagging SCHED-1, SEC-1 and SUP-4b as
open when all three are decided (`✅ RESOLVED 2026-09-01`, `✅ RATIFIED 2026-09-01`, `✅ DECIDED 2026-09-04 /
202607060100`). That finding is preserved here so the next session does not re-derive it.

The register was **not** edited to make any probe return zero. Measured, the blind spot currently conceals
**no** open decision, so the manifest's ten-decision boot line is complete with respect to this substrate.

## 9. Line-Ending Policy — Classified, Not Fixed

The regenerated `ai-map.json` embeds `\r\n` inside JSON string values on a CRLF checkout and `\n` on an LF
one, so the generated artifact's bytes differ by machine — visible in `ecb8346`'s own diff and reproduced
here. Classified as **diff-churn, not a measurement defect**, on evidence: Check 7 compares every extracted
live_state field with `-replace '\s+', ' '`, which collapses `\r` along with all other whitespace, so **no
guard verdict depends on it** and it cannot fail across machines the way Check 5 did.

A repository-wide `.gitattributes` would rewrite line endings across every tracked file to remove diff noise
that no guard reads. That is a broad change for a cosmetic benefit, and §5 of the commission explicitly
warns against reaching for it here. **Recorded with its trigger instead:** adopt one if the churn ever
produces a false diff in review, or if a second guard is found to compare generated content byte-wise.

## 10. RECOVER-1 — Status

**CLOSED, not reopened, not relabelled.** Its guard demonstrably worked: `.claude/hooks/session-state.ps1`
fetched at boot and printed `behind 1 vs upstream … AGENTS.md §4 step 8 applies`, which is the only reason
the divergence was found before work began.

The residual gap is unchanged and remains **process-only**: the hook *script* is tracked, but its *wiring*
lives in `.claude/settings.json`, which is `.gitignore`d (line 37), and no tracked file under `scripts/` or
`.github/` compares `main` against `origin/main`. A fresh clone therefore boots with no divergence warning.
**Deliberately not repaired in this package** — it was not required by the synchronization objective, and
adding a second synchronization mechanism on the strength of one occurrence is exactly what the previous
commission forbade. It stays a separate, recorded process item.

## 11. Current State — Re-Derived

**Git.** `HEAD == origin/main`; ahead/behind `0 / 0`; working tree clean after commit (§13).

**Repository consistency.** `REPOSITORY CONSISTENCY: CLEAN`, Checks 1–25, exit 0 — and, unlike every prior
session, that verdict now means the same thing on an LF and a CRLF checkout.

**Database.** Untouched and identical. Read live FROM Primary (`vrvtsxexkiiiivlkdxzp`, ref proven by
`get_project_url`) after all repairs:

| Surface | Primary | Local (post-reset) |
|---|---|---|
| ledger | `204 \| e9549f90784fb38b0924b6353a56d94f` | identical |
| functions | `8c012ce5ee5749923d94c0d54e6b867f` (277) | identical |
| structure `_combined` | `a48b275de685f89c073058de385d3ad8` (3,563) | identical |

Ten structural sub-surfaces all identical: triggers 273 · policies 124 · constraints 498 · grants 792 ·
columns 1,097 · views 16 · indexes 293 · status_transitions 115 · rls_enabled 78 · functions 277.
**`DATABASE PARITY: CLEAN`, exit 0. No migration was written and nothing was deployed to Primary.**

**Tests.** `db reset` replayed all 204 migrations clean · Pass A **105 files / 1,646 assertions** ·
six HTTP suites **430 / 0** (29 + 107 + 74 + 120 + 40 + 60) · Pass B **105 / 1,646 = Pass A** ·
smoke **ALL CHECKS PASSED (77 tables)**.

**Batch 6.** **6 of 77**, unchanged — 3 AUDITED + 3 AUDITED-OPEN + 71 NOT-RECORDED, all six ADVERSARIAL,
EC-1…EC-11 intact and unweakened. No Batch 6 surface was audited, tested or modified.

**Open decisions.** **Ten**, unchanged and consistently represented: MAIL-1 · RET-1 · AUDIT-2 · PD-23 ·
FA-2 · MONEY-2 · PAX-5 · PAX-6 · BOOK-8 · BOOK-9. None was resolved, removed, or invented; Checks 11, 14
and 25 all pass against them.

**Engineering debt still open.** Check 25's second substrate (§8) · ai-map CRLF churn (§9) · RECOVER-1's
process residual (§10) · DISP-DRIFT-1's unguarded-prose residual (§6) · and the seven previously registered
items PAX-4, CUST-6, IDENT-2, DELIV-1, GOV-20, DOC-LC-3, PH8-2.

## 12. Next Permitted Action

**Batch 6 slice 6 — `otp_challenges`.** Target unchanged; justification corrected.

The reason is that `otp_challenges` is the **only** NOT-RECORDED surface carrying **both** PII and an
unguarded write path, on a pre-authentication surface where an unguarded write is most consequential. It
is **not** the exposure leader — it ranks 12th of 71 — and no ranking claim should be made for it beyond
that. Expect to conclude "correctly unguarded", because the surface is pre-authentication; that expectation
is a hypothesis to attack, not a conclusion to confirm.

Its two siblings deserve to be named in the same breath and previously were not: `trusted_devices`
(exposure 12, *higher*, unguarded, PII 0) and `totp_enrollments` (exposure 8, unguarded). They are one
MFA/device-trust family and are the natural slice 6–8 sequence.

## 13. Final Synchronization Evidence

| Claim | Verdict | Evidence class |
|---|---|---|
| Local Git == GitHub | **PASS** | REPOSITORY |
| Local DB == Primary DB | **PASS** (twelve surfaces) | LOCAL RUNTIME + PRIMARY |
| Repository Consistency 1–25 | **CLEAN**, LF and CRLF alike | REPOSITORY |
| Database Parity | **CLEAN**, Primary read FROM Primary | PRIMARY |
| pgTAP Pass A / Pass B | **PASS** 105 / 1,646, equal | LOCAL RUNTIME |
| Six HTTP suites | **PASS** 430 / 0 | HTTP |
| Smoke | **ALL CHECKS PASSED** (77 tables) | LOCAL RUNTIME |
| Migration replay | **PASS** (204 applied on clean reset) | LOCAL RUNTIME |
| GUARD-CRLF-1 battery | **9 / 9 as expected**, incl. defect injection | REPOSITORY |
| CI — `ecb8346` | **success** (Repository Consistency) | EXTERNAL |
| CI — this session's commit | recorded in §14 | EXTERNAL |
| Primary deployment | **none occurred** | — |

## 14. Commit and CI

Commit: `docs(guard): Check 5 was measuring line endings, not document size`
(exact SHA and the CI conclusion for it are appended below by the same session that pushed it.)

- Pushed to `origin/main` as a fast-forward; no force, no history rewrite.
- CI observed after the push: see §15.

## 15. Post-Push CI

Recorded live after the push — workflow **Repository Consistency** and **Migration CI** on this session's
commit. Result: **see the session's closing report line**; a failure here would have been a finding, not a
footnote, and the commit would not have been reported as complete.

## 16. Future-LLM Handoff

1. **Check 5 now measures the document, not the checkout.** If you ever see Check 5 disagree between your
   machine and CI again, the normalisation on `check_repository_consistency.ps1`'s `$mfChars` line has been
   removed — restore it rather than trimming the manifest. The budget is 7,000 and is never raised.
2. **The manifest's headroom is genuinely small** (currently ~33 characters). When you replace
   `Last Completed`, replace it — do not append. That is the manifest's own rule, and it is what keeps the
   budget honest.
3. **`otp_challenges` is not the exposure leader** (12th of 71). Run the selector with `-Top 71` before
   quoting any ranking; the default `-Top 12` is what produced SELECT-1.
4. **Check 25's second substrate is a known, measured, currently-empty blind spot.** Read §8 before touching
   it; the parser inventory and the append-only obstacle are already worked out, and a naive regex will
   reproduce GOV-11.
5. **Nothing was deployed to Primary and no migration exists in this package.** If a future parity run
   disagrees, the cause is not here.

End of Report.
