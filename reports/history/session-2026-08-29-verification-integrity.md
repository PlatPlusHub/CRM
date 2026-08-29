# ORVION — Verification Integrity: The Test Suite Was Breaking Parity, and I Had Dated My Own Work Tomorrow

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: Codex audit AUD-01…AUD-07 reproduced and classified. **PAR-2** found and fixed — the root
cause of PAR-1/1a/1b. AUD-01, AUD-04, AUD-05, AUD-07 fixed. Guards gained Check 12 and a cross-Master
pass. No migration.
Status: Complete; verified, committed and pushed.

**Branch:** `main` · **Start HEAD:** `3a5605c` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective

The owner supplied an independent Codex audit (AUD-01…AUD-07) with one instruction: *"Do NOT assume
Codex is correct. Do NOT assume Claude's previous reports are correct. Reproduce each finding."*

Reproduced all seven. **Five verified defects, one duplicate, one false positive** — and the
reproduction of AUD-05 uncovered an eighth thing nobody had audited for, which turned out to be the
largest finding of the session.

---

## 2. Starting state, and an environment fault handled honestly

Docker Desktop was **down** at session start — AUD-06's exact condition, arriving unprompted. Primary
was reachable and reported 160 migrations / `9e5fb52c…` / 75 tables / 122 policies /
`d98abbdd…`|230 functions. **Local was not read from memory.** Docker was restarted, then every
local figure re-read. Nothing about local was claimed in the interval.

Repository: HEAD `3a5605c`, clean, `= origin/main`.

---

## 3. AUD-01 — I had dated my own work tomorrow

**VERIFIED DEFECT, and it was mine.**

```
UTC clock          : 2026-08-29 13:00
Cairo              : 2026-08-29 16:00
Commit 3a5605c     : authored 2026-08-29 12:00:29 +0300
Content of 3a5605c : stamped ONE DAY AHEAD, in 43 places across 13 files
```

*(That line describes the wrong date rather than quoting it — Check 12 has no exemption list and
flagged this very report on its first run when it did quote it. The check is doing its job on the
document that introduces it, which is the strongest evidence it works.)*

Gap-register rows, a `GOVERNANCE.md` version bump, a session report's **filename and `Date:` field**,
the manifest, the roadmap, four Masters, two scripts. The commit's own author date contradicted
everything it carried.

**Root cause:** I inferred the date from the shape of the session — the previous report was dated
2026-08-29, this felt like a new session, so I wrote the next day. The environment had told me the
correct date and I overrode it with an assumption. Nothing checked.

**Why it is worse than staleness:** a future-dated record claims evidence that *could not yet have
been gathered*, and it sorts ahead of records that are genuinely newer. A later agent reconciling by
date would have preferred it over correct, newer work.

**Fixed:** all 43 stamps corrected; the report renamed to `session-2026-08-29-program-reconciliation.md`;
`ai-map.json` regenerated. Verified zero future dates remain repository-wide.

**Guarded — Check 12.** Any ISO date later than today, anywhere in `*.md`/`*.json`/`*.ps1`/`*.sql`,
fails the build. Plus a clock-sanity cross-check: a commit authored after "now" means the clock is
wrong and every date written in the session is suspect.

**It flagged itself on the first run** — my explanatory comment quoted the offending date literally.
I did *not* add an exemption list; I rewrote the comment to *describe* the date ("one day ahead")
instead of quoting it. **Every exemption is a place the next future date can hide**, and this check
is worth more absolutely strict than conveniently quiet.

---

## 4. AUD-05 → PAR-2 — the finding behind the finding

### AUD-05 as reported: parity says CLEAN without contacting Primary

**VERIFIED DEFECT.** Run with no Primary values:

```
DATABASE PARITY: CLEAN (local proven; primary ledger NOT checked; primary functions NOT checked)
exit 0
```

The parenthetical was honest; **the verdict word and the exit status were not**, and an exit status
is what a caller, a CI job or a future agent actually reads. It contradicted the script's own header
(*"Exit 0 = parity proven. Exit 1 = drift, unreachable, or unproven"*) **and** `AGENTS.md §4` Stage B
step 8b, which already said Primary unproven "is not CLEAN". The governance was right; the script
did not honour it, so the script changed.

Three outcomes now, because *"not measured" is not a kind of "passed"*:

| exit | verdict | meaning |
|---|---|---|
| 0 | CLEAN | everything claimed was measured |
| 1 | DRIFT | measured, and disagreed |
| 2 | UNPROVEN | Primary was never contacted |

Proven in all three states.

### And then the number was wrong

That same run printed `local: 230 functions, logic hash 506eb973…`. Primary had reported
`d98abbdd…` minutes earlier. **Same ledger, same 230 functions, different bodies.**

Narrowed by schema (`public` identical, `app` differing), then by first letter (only `d`), then to
exactly one function: **`app.document_retention_days`** — the same function PAR-1, PAR-1a and PAR-1b
had each chased.

### PAR-2 — the root cause, and it is the test suite

`scripts/verify_storage_end_to_end.ps1` overrides the function to exercise retention, then "restores"
it:

```sql
-- what the script wrote back
create or replace function app.document_retention_days() ... as 'select null::integer';

-- what the migration actually ships
create or replace function app.document_retention_days() ... as $fn$
    select null::integer;
$fn$;
```

Behaviourally identical. **Textually different** — and the parity guard compares
`pg_get_functiondef`. So **every run of that suite left the local database permanently unequal to the
repository**, in exactly one function.

pgTAP overrides the same function in three files and leaves no trace, because pgTAP rolls back. The
HTTP suites do not roll back. That asymmetry is why only this one persisted.

**This is the root cause the three earlier findings were circling.** PAR-1b concluded local "had been
hand-modified mid-session" — close, and wrong in the way that mattered. It was not a hand edit. It
was this script, deterministically, on every run, which is exactly why the drift kept coming back
after each diagnosis. And one of those sessions read the polluted local body and **pushed it to
Primary** while reporting the opposite.

**Fix:** capture `pg_get_functiondef` *before* the override and replay it verbatim. The restore is
read from the database, so it cannot drift from the migration however the migration later changes.
It refuses to run if the capture fails, rather than leaving the database drifted with no way back.

**Proof:**

```
after db reset ............................. d98abbdd9aea724630f2d97f91a21b08
after ALL SIX HTTP suites + pgTAP Pass B ... d98abbdd9aea724630f2d97f91a21b08
Primary, read live ......................... d98abbdd9aea724630f2d97f91a21b08
```

Before the fix the middle line was `506eb973…`. **Parity now survives a full HTTP run for the first
time in the programme's history.**

**One error of mine inside the fix, worth keeping.** My first restore-assertion recomputed
PostgreSQL's normalization in PowerShell and **failed against a restore that was actually correct**.
That is PAR-1a's lesson one layer over: *do not reimplement the comparison, reuse it.* Both sides are
now computed by the same engine with the same expression.

**Sibling sweep** (directive §11): all six HTTP suites checked for persistent DDL. Only this one had
any. `verify_role_journeys.ps1` matched the grep on the word "grant" inside an assertion label — a
false positive, checked rather than assumed.

Two assertions added (43 → 45): the definition is restored verbatim, **and** the migration's
`revoke execute … from public` survived the replace (`create or replace` preserves the ACL — verified,
not assumed).

---

## 5. AUD-04 — a published zero that nothing measured

**VERIFIED DEFECT.** `MASTER_REPOSITORY_HEALTH.md §3` published *"Conflicting finding status across
**Masters** = 0"*. Check 2's hashtables are rebuilt **per file** — it had never compared two Masters
to each other. The 0 was asserted, never measured.

Fixed by making the claim true rather than by softening it: Check 2 gained a cross-file pass. Now
reports `cross-Master status agreement measured over 24 open id(s) -- no contradiction`.

Proven: marking `SEC-1` resolved in `MASTER_RISK_REGISTER.md` produced
`CROSS-MASTER STATUS CONTRADICTION: SEC-1 is OPEN in MASTER_GAP_REGISTER.md:132 but resolved in
MASTER_RISK_REGISTER.md:32`; removing it cleared. Same-file contradictions are not double-counted.

---

## 6. AUD-07 — split: one defect, one false positive

**Dependency graph — VERIFIED DEFECT.** `MASTER_DEPENDENCY_GRAPH.md` claimed to resolve ordering
*"for every finding"*. Measured: **46 ids named, 135 in the register — 100 findings had no entry**,
including every one minted since 2026-07-11 (SEC-1, the whole FIN/ATTR/CAT/RPC/TENANT set, all of the
Foundation Completion Programme).

Fixed by correcting the **scope**, not by inventing 100 dependency rows. The ordering authority for
modern findings is `MASTER_EXECUTION_PLAN.md` Batch 6, which sequences them "by evidence (highest
day-one/business impact first)" with dependencies stated inline — that is how the programme has
actually executed since 2026-08-24, and a second ordering document would be the competing authority
`GOVERNANCE.md §2` forbids. The graph now declares itself the map of the Batch 0–5 **structural**
chains, where a wrong order means an expensive migration rather than a rescheduled package.

**`repository-index.md` — FALSE POSITIVE.** Regenerated it; byte-identical. Not stale.

---

## 7. AUD-02, AUD-03, AUD-06

**AUD-02 — CONFIRMED, already fixed.** Duplicate of **GOV-5**, repaired in the immediately preceding
session. Kept as its own row because Codex reached it independently, which is corroboration worth
preserving. Its residual tail — §3's *"Stale documents = 0"*, asserted on a 2026-07-15 reconciliation
and never re-measured — was corrected here and marked 👁, because **no guard measures document
staleness** and pretending otherwise would repeat AUD-04's mistake.

**AUD-03 — INTENTIONAL, with the harmful half now guarded.** The plan does narrate finding detail the
register owns. But the two answer different questions: the register owns a finding's **status and
evidence**; the plan owns the **package narrative and sequencing**, which cannot be written without
describing findings — and that history is what makes the programme continuable. Gutting it would
destroy the continuity the whole governance model exists to protect.

The concrete harm of duplication is **status disagreement**, and that is precisely what AUD-04's
cross-Master pass now measures. So the boundary is enforced where it bites instead of by prose
discipline, and `GOVERNANCE.md §2` states it explicitly (v1.10 → v1.11) rather than leaving it to be
inferred from "never restate the finding".

**AUD-06 — CONFIRMED, structurally addressed.** It recurred on arrival (Docker down). Handled by
reporting nothing about local until it was readable. The durable fix is AUD-05: a run that could not
reach an environment now exits **2 UNPROVEN**, so "the auditor could not see it" can no longer be
recorded as "it matched".

---

## 8. Verification

| Axis | Result |
|---|---|
| Clock | UTC 2026-08-29; agrees with newest commit's author date |
| Migrations | **160** — repository, local, Primary |
| Ledger fingerprint | `9e5fb52c92ce30a8b6d0559be3da7110` — read independently from both |
| Function surface (230) | `d98abbdd92…` → `d98abbdd9aea724630f2d97f91a21b08` identical both sides |
| pgTAP **Pass A** (fresh reset) | **68 files / 816 assertions / 0 failures** |
| pgTAP **Pass B** (post-residue) | **68 files / 816 assertions / 0 failures** |
| End-to-end HTTP | **237/237** — storage **45** · api 29 · branches 26 · roles 27 · lifecycle 72 · care 38 |
| **Post-HTTP surface hash** | **`d98abbdd…` — equal to Primary. The PAR-2 proof.** |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Repository guard | **CLEAN**, now **12 checks** |
| Parity guard | **CLEAN**, exit 0, Primary values read live |
| Parity with no Primary values | **UNPROVEN, exit 2** (was CLEAN, exit 0) |

---

## 9. Classification

**VERIFIED DEFECT (fixed)** — **PAR-2** (High), **AUD-05** (High), **AUD-01**, **AUD-04**, **AUD-07**
(dependency graph half).

**CONFIRMED, previously fixed** — AUD-02 (duplicate of GOV-5).

**INTENTIONAL, boundary now enforced** — AUD-03.

**CONFIRMED condition, structurally addressed** — AUD-06.

**FALSE POSITIVE** — AUD-07's `repository-index.md` half.

**No business policy invented.** No blocked item became derivable this session; none was re-labelled.

---

## 10. What this session says about the programme

Three sessions independently diagnosed drift in **one function** and each produced a plausible,
partially-correct story. None found the cause, because all three looked at the *database* and the
cause was in the *test suite*. PAR-1b even corrected PAR-1a and was itself wrong.

The pattern is now explicit enough to state as a rule: **when the same symptom returns after being
"fixed", the diagnosis was of a symptom.** A recurring drift has a producer, and the producer is
whatever runs between the measurements.

And AUD-01 is the plainest instance yet of this programme's recurring lesson: I asserted a fact I
could have read in one command, and no guard existed because nobody had imagined getting the *date*
wrong.

---

## 11. Next executable step

**DOC-LC-1** — wire canon 26's Document Lifecycle machine into `app.status_transitions`
(`ARCHIVE_DOCUMENT` for `→ archived`, `CREATE_DOCUMENT_VERSION` for `→ superseded`, both read from
the existing writers). Derivable, bounded, the last canon-defined machine with no runtime wiring.
Then **API-3** (30 endpoints), then Batch 6's remaining engineering items.

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut.

**The single owner decision that unblocks the most: SEC-1**, the write-path architecture.
