# ORVION — Handoff Readiness: Five Defects in the Layer That Records the Work

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Scope: Owner-directed continuity and repository-governance pass. Full reconciliation of every
authority against live evidence; continuity/handoff hardening; governance and workflow hardening;
guard audit. **No migration written, no test changed, no roadmap change, no API-3 package started.**
Status: Complete.

**Branch:** `main` · **Start HEAD:** `846feaf` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 0. What this session was, and what it deliberately was not

The objective was to leave the repository in a state where a **new LLM with no memory of any prior
session** can reconstruct the truth, reproduce the verification, and continue from the exact next
step. It was explicitly not a redesign, not a roadmap change, and not permission to start the next
API-3 package.

The finding that matters most is structural: **every defect this session found is in the layer that
RECORDS and MEASURES the work, not in the product.** That is now a recurring shape here — the
2026-08-29 contract-to-finance session found three, and the pre-Phase-10 reconciliation found six.
The product has been audited adversarially for a month; the recording layer has been audited far
less, and it is what a fresh session has to trust before it can verify anything.

---

## 1. Findings discovered

| ID | What | Severity | End state |
|---|---|---|---|
| **BOOT-1** | The verification protocol every package actually runs existed only in immutable history reports | **High** | **FIXED** (`AGENTS.md §5a`) |
| **REG-1** | The register's only **Critical** row was escaped out of its own table — and out of the guard that reads it | Medium | **FIXED** + guarded (**Check 13**, mutation-tested) |
| **REG-2** | The register restated an API-3 coverage count that drifted below the generated artifact | Low | **FIXED** by deletion |
| **ROAD-1** | Canon 32 presented a 2026-08-29 measurement as current live state | Low | **FIXED** by date-stamping + pointer |
| **MF-1** | `manifest.md` had **five characters** of headroom under its own cold-boot budget | Low | **FIXED** by trimming |

A sixth defect surfaced mid-session and is recorded in §4 because it was **mine, and a guard caught
it**: I stamped this session's work **one day ahead** by assuming the date from the shape of the
session. Check 12 — added for exactly that (**AUD-01**) — rejected it 16 times.

---

## 2. BOOT-1 — the protocol that was never written down

`AGENTS.md §5` documented `npx supabase db reset`, the smoke test, a behavioural test, the
repository guard and CI. That is a **strict subset** of what this programme has actually executed on
every package since 2026-08-27:

```
db reset → Pass A (pgTAP) → six HTTP suites → Pass B (no reset, under the suites' residue)
→ smoke → three Primary values read FROM Primary → parity guard → regenerate → repository guard
```

Measured, not assumed: `grep "Pass A"` across the repository resolved **only** to
`reports/history/**` (Historical-Immutable), the plan's package narratives, and the register. No
Living document told a session to run it.

**Why this is High and not cosmetic.** A fresh session following the boot sequence *correctly* would
run reset + smoke + the repository guard, see CLEAN twice, and report "verified" — having never
executed an HTTP suite, never run Pass B, and never contacted Primary. That is UNPROVEN narrowed to
PROVEN by following the instructions, which is the precise failure `AGENTS.md §4` forbids and which
has already happened once here (2026-08-26: the repository guard printed CLEAN while local sat 29
migrations behind). The rule existed; the procedure that satisfies it did not.

Fixed in `§5a` — the nine numbered steps, each carrying the finding ID that earned it (**PAR-1b**
for why step 1 is not optional, **TEST-2** and **PAR-2** for why Pass B exists, **BOOK-1**/**ADMIN-1**
for why HTTP is not a formality, **GUARD-1** for step 6, **AUD-05** for step 7).

**The seven evidence classes** are recorded in the same section as a table: REPOSITORY · LOCAL
RUNTIME · HTTP · PRIMARY · GENERATED · HISTORICAL · EXTERNAL · INTENT · INFERENCE, each with what it
proves and — the column that does the work — **what it can never prove**. Most false confidence in
this repository has come from a claim quietly borrowing a stronger class than its evidence.

No new document was created. `§5` already owns build-and-verify conduct; the protocol went where it
belonged.

---

## 3. REG-1 — a Critical finding invisible to the guard that measures it

The IDENT-1 row in `MASTER_GAP_REGISTER.md` opened with a **backslash-escaped** pipe. One line in the
entire repository. Two consequences:

1. **Rendering** — an escaped leading pipe is cell *content*, so every column shifts left by one and
   the account-takeover finding displayed its title in the ID column.
2. **Measurement** — Check 2 extracts a row's subject with `^\|\s*(<id>)`. A line starting with a
   backslash matches nothing. **IDENT-1 was structurally invisible to the cross-Master status
   comparison**, and Check 2's cheerful "no contradiction over 23 open id(s)" was computed over a set
   that silently excluded the highest-severity finding in the file.

No contradiction actually existed — IDENT-1 is marked FIXED consistently in the register, the plan,
the manifest and `reports/README.md`, and that was verified rather than assumed. So this was a
**latent** false-green, not a live one. It is recorded as a first-class finding anyway, because the
class is the same one as PAR-3 and SEC-1b: *a guard publishing a verdict over less than it claims to
cover.*

**Check 13** now fails on any line in `reports/master/*.md` beginning with an escaped pipe.
Deliberately narrow — escaped pipes *inside* a cell are legitimate (they are how a literal `|` is
written) and are untouched; the scope is derived from `reports/master/*.md` with no file enumerated
by name and no exemption list.

**Attacked before acceptance**, per the standing rule that a guard is not evidence until the guard
has been attacked:

```
mutate (re-escape the IDENT-1 row) → Check 13 FAILS, naming MASTER_GAP_REGISTER.md:220
restore                            → Check 13 PASSES
```

---

## 4. The measurement defect that was mine, caught by a guard I did not write

Every artifact this session touched was stamped **one day into the future**. The date was inferred
from the shape of the work — a continuation of a session that began the previous evening — rather
than read from the clock, which said `2026-08-30 10:42 +03:00`.

**Check 12 rejected it 16 times**, naming every file and line. This is the second occurrence of
**AUD-01**, and the first since the check was added; on the first occurrence the same mistake reached
43 places across 13 files and was caught only by a human audit. The guard did its job on an author
who knew the rule and broke it anyway, which is the strongest available evidence that the guard earns
its place. All 16 restamped; Check 12 green.

Recorded here rather than tidied away, because a session report that omits the author's own errors is
worth less than no report (`AGENTS.md §6`).

---

## 5. REG-2 and ROAD-1 — historical evidence wearing the present tense

Both are the **GOV-5** class, and both were fixed the way GOV-5 was: by **removing the restatement,
not refreshing it.**

- **REG-2** — the register's API-3 detail block read "30 of 71 … 41 of 71 are exercised" while four
  packages had moved the real figures to **55 covered / 16 uncovered**. The SSOT for a finding's
  status and evidence was two days behind `MASTER_API_CONTRACT.md`, the **generated** file it was
  summarising. The block now points at the generated contract and states no count of its own.
- **ROAD-1** — canon 32's Phase-10 NOT-READY determination listed "160 migrations … the full
  230-function surface" and "the **30** still lacking HTTP evidence" under the heading *What is NOT
  blocking*, read as present tense by any newcomer while the live figures were 169 / 236 / 16. The
  **verdict is unchanged and still correct**; only its supporting numbers had aged. Now stamped *as
  verified 2026-08-29* with current state pointed at `manifest.md`.

**What was deliberately NOT touched:** `MASTER_EXECUTION_PLAN.md`'s per-package narratives
(`33 → 30`, `25 → 20`, `20 → 16`). Those are not restatements — they are dated history of what each
package moved, which `GOVERNANCE.md §2` (AUD-03) explicitly permits and which is what makes the
programme continuable. The harmful half of duplication is a *status* the register disagrees with, and
Check 2 measures that.

---

## 6. Governance and workflow hardening

Two additions, both to `AGENTS.md`, both carrying findings by ID rather than restating them:

**`§4` step 13 — "Never assume."** Seven entries, each one already paid for: an HTTP-covered endpoint
is not safe (**BOOK-1**); a passing test does not prove the intended enforcer (**PAR-4**); a CLEAN
guard proves nothing outside its evidence class (**PAR-3**); repository evidence is not Primary
evidence (**GUARD-1**); a code comment can be false (**IDENT-1** — two shipped comments were, one of
them written in that same session); the previous report is not current state; and a discovered rule
does not automatically want a trigger — **IDENT-1 and ADMIN-1 are the same family and landed in
opposite enforcement layers**, each chosen by counting fixtures and alternate write paths.

**`§6` — "Measurement is not evidence until the measurement itself has been attacked."** The
distilled standing rules from PAR-1/1a/1b, PAR-2, PAR-3, PAR-4, SEC-1b, GUARD-1, VER-1 and MEAS-1:
read what a guard reads before quoting it; fix the guard when its description outruns its
measurement; attack every new detector in both directions; prove enforcers by defect injection;
treat static analysis as a lead (it cannot see trigger arguments, runtime values, or RLS visibility);
test both the RPC and the direct-DML door; distinguish infrastructure failure from product failure;
never manufacture an exemption or raise a budget to make a guard pass; and end every finding in
exactly one of four declared states, escalating to the owner only after canon → SSOT → schema →
implementation → consumers → tests → runtime → Primary → external documentation is exhausted.

Rules that already existed were **not** duplicated: Q1+Q2 (`§3 5b`), no-vacuous-security-tests
(`§6`), regenerate-never-hand-edit (`GOVERNANCE.md §6.4`), no-second-SSOT (`§6.8`), history-immutable
(`§4`), and the four verdicts PROVEN/UNPROVEN/FAILED/BLOCKED (`§4`). Adding them again would have
been the duplicated authority this repository spends most of its governance preventing.

---

## 7. Guard audit — what was added, and what was rejected

The question asked of each governance rule was: *can a future incorrect change produce a false
CLEAN?*

**Added: Check 13** (§3), the only proven failure mode with no guard.

**Rejected, on evidence rather than taste:**

- **A column-count check on register rows.** Measured first: **16** legitimate historic rows carry 12
  columns against a 13-column header, and blank-line group separators split the table throughout. A
  guard here would fire on a decade of valid history — precision over recall, which this script's own
  header demands.
- **A guard asserting the register's API-3 count matches the generated contract.** It would hard-code
  one finding ID and one phrasing. The correct fix was to **delete the restatement** so there is
  nothing left to drift, which is strictly stronger than measuring a duplicate.
- **A guard comparing the manifest's "next step" against the latest session report's.** Prose
  comparison; it would either match trivially or cry wolf. Check 10 already proves the *pointer* is
  current, and a human-readable disagreement between two sentences is what the boot sequence's
  Stage B cross-check exists to catch.
- **Any new "everything is healthy" aggregate script.** Explicitly rejected during the 2026-08-30
  verification-methodology review and still rejected: one verdict spanning several evidence classes
  is how a CLEAN starts meaning less than it says.

No existing guard was weakened. No exemption was created. `manifest.md` was trimmed rather than
having its budget raised — the sixth time that choice has been made and the sixth time trimming won.

---

## 8. Verification performed this session

| Axis | Result | Evidence class |
|---|---|---|
| Local reset | `npx supabase db reset` clean, exit 0 | LOCAL RUNTIME |
| Migrations | **169** — repository = local = Primary (`202607058000`) | all three read |
| Ledger fingerprint | `4f79ecfdad3b2f1f424f72e70e414d86` | read independently from BOTH |
| Function surface (236) | `a994108bd5cf44f9cc570180e72312a4` | read independently from BOTH |
| Structural surface (3,348 / ten surfaces) | `3a65328f42bd8c13b3f3048fa8f0158f` | read independently from BOTH |
| Primary project ref | `vrvtsxexkiiiivlkdxzp` via `get_project_url` | PRIMARY — never a transcribed string |
| pgTAP **Pass A** | **76 files / 968 assertions / 0 failures** | LOCAL RUNTIME, fresh reset |
| Smoke | `ALL CHECKS PASSED (75 tables …)` | LOCAL RUNTIME |
| Parity guard | **CLEAN exit 0**, all three Primary values supplied from live Primary reads | local ↔ Primary |
| API contract | regenerate-and-diff: matches the live surface — **55 of 71 with HTTP evidence** | GENERATED |
| Repository guard | **CLEAN**, now **13** checks | REPOSITORY |
| Check 13 | mutation-tested: FAILS on the injected bad row, PASSES on restore | REPOSITORY |

**NOT re-run this session, and stated rather than implied:** the six HTTP suites and pgTAP **Pass B**.
No migration, test file, or verification suite changed in this commit — the diff is documents, one
guard check, and the generated artifacts — so there was no product behaviour to re-prove over the
wire. **The last full HTTP + Pass B evidence is `846feaf` (298/298 across six suites; Pass A = Pass B
= 76 files / 968 assertions).** The next package that touches SQL must run the whole of `§5a`.

---

## 9. Classification

**FIXED and behaviourally verified** — BOOT-1, REG-1 (with Check 13 attacked both ways), REG-2,
ROAD-1, MF-1, and this session's own AUD-01 date slip.
**PROVEN INTENTIONAL / not a defect** — `MASTER_EXECUTION_PLAN.md`'s per-package narratives (AUD-03
permits them); `MASTER_DEPENDENCY_GRAPH.md`'s Batch-0–5 scope (already self-corrected by AUD-07).
**UNPROVEN** — none introduced.
**OWNER DECISION REQUIRED** — none arising from this session. The pre-existing open decisions are
unchanged in number and content; see `manifest.md` for the IDs and the register for each definition.

**No business policy invented. No canon rule changed** — canon 32's edit removed a stale restatement
and stamped a date; the Phase-10 verdict, the 7→9→8→10 order and every phase status are untouched.

---

## 10. One observation, recorded and deliberately not acted on

`reports/README.md`'s **Latest session report** row is a single line of roughly 15,000 characters
chaining every predecessor summary back through a month of sessions. It works — it is genuinely the
fastest way for a cold session to learn what happened recently, and Check 10 keeps its head current.
But it restates content whose SSOT is each linked report, it grows unboundedly, and `manifest.md`
needed a three-axis budget (Check 5) for precisely this shape.

Not acted on because trimming it is a judgement about how much continuity narrative the owner wants
carried inline, and this session's mandate was explicitly *not* to redesign. Recorded here so the
decision is deliberate rather than inherited. Suggested trigger: when the row passes ~20,000
characters, or at the next phase-transition checkpoint, keep the three most recent entries inline and
move the tail to a dated chain report.

---

## 11. Next executable step

**API-3, the lead-routing family** — `assign_lead_round_robin`, `reassign_lead`, `lead_origin`,
`lead_booking_readiness`. Unchanged by this session, and chosen on the same evidence as before: it is
the largest remaining coherent group of the 16 uncovered endpoints, it carries attribution
consequences (**ATTR-3** and **LEAD-3** both landed there), and `reassign_lead` writes the assignment
history that acquisition lineage depends on.

**Before starting it, re-establish state rather than trusting this report:** run the `AGENTS.md §4`
boot sequence in full, re-read all three Primary values **live from Primary** (never pass the
repository's own values back to the guard — GUARD-1), and `npx supabase db reset` before reading any
structure from local (PAR-1b). Then verify the package with the whole of **`§5a`**.

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut. **SEC-1 still awaits owner ratification**; nothing in the
lead-routing family is blocked on it.
