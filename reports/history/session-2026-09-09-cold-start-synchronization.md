# Cold-start synchronization repair and enforcement hardening

Class: 🟠 Historical-Immutable — session record
Date: 2026-09-09
Status: Complete — repository-only; no migration, no database write
Purpose: Repair three cold-start synchronization defects and harden the enforcement chain against a weaker agent

---

## §0 HANDOFF

- **INHERITED:** `main` at `010628b`, identical to `origin/main` (0 ahead, 0 behind — fetched and compared, which `AGENTS.md §4` Stage B step 8 makes the reader's job). Working tree clean. 211 migrations, guard CLEAN, Batch 6 at 12/77, Active Change Request `None`, next capability Batch 6 slice 12.
- **PROVEN (this session, by running the guard and by mutation):** three synchronization defects existed inside checks that were printing CLEAN, and all three are now repaired and pinned by 34 new mutation assertions in both directions (`test_cold_start_state_guard.ps1`, 34/34). All four guard-of-the-guard suites and the consistency guard are green.
- **UNPROVEN:** everything about a running database. **No database was opened this session** — no `db reset`, no pgTAP, no HTTP suite, no smoke test, no Primary read. Parity is UNPROVEN as of this session and is not claimed; the last proof is the 2026-09-09 slice-11 closure's, and Check 19 verifies only the RECORDED Primary reading.
- **CHANGED:** `reports/README.md` (stale competing cold-start block deleted), `scripts/check_repository_consistency.ps1` (Checks 10, 11, 14, 16, 20, 25 + one shared parse and one shared resolver), `scripts/repository-all.ps1` (exit codes), `.github/workflows/repository-consistency.yml` (pull_request triggers + the new suite), `scripts/test_cold_start_state_guard.ps1` (new), `reports/master/MASTER_GAP_REGISTER.md` (COLD-2b, GOV-23, GOV-24, CI-1b, SYNC-2), `_ORVION_CANONICAL/manifest.md` (`Narrative:` only). **Not yet committed at the time of writing; see §9.**
- **REMAINING:** nothing from this scope is half-built. Two items are reported and deliberately NOT built — see §4 NOT FIXED.
- **DO NOT TOUCH:** (1) **`RET-1` must stay on the manifest's open-decision line.** Its register blocks say `✅ RESOLVED — IMPLEMENTED` and it is still a live compliance decision; the mechanism shipped, the values are counsel's. A status-only reading of the register says otherwise and is wrong — that is precisely the false positive this session found and designed around. (2) **The status words `SUPERSEDED`, `OBSOLETE`, `DELIVERED`, `MITIGATED`, `NARROWED`, `BOUNDED`, `MEASURED`, `RECORDED`, `UNPROVEN`, `ACCEPTED RISK`, `NOT REPRODUCIBLE`, `EVIDENCE ONLY` are deliberately outside the settled vocabulary.** Adding one is a policy decision about what that word means for a finding, not a parser fix; do not widen the regex to make a row pass. (3) The historical `Previously:` rows in `reports/README.md` are history — demote or delete a live row, never rewrite a dated one.
- **NEXT:** Batch 6 slice 12, target selected by `scripts/batch6_select_target.ps1`. Unchanged by this session.

---

## §1 DISCOVERED

Three defects, and the shape they share is the one this repository keeps finding: **a check reading less than its name claims, while printing CLEAN.**

### COLD-2b — two live cold-start declarations, one of them three slices stale

`reports/README.md` line 13 carried an un-prefixed blockquote reading *"**Current state & next step (read this first on a cold start):**"*, naming the slice-8 report and closing *"Next surface: **`leads`** (slice 9)"*. Slices 9, 10 and 11 were complete. Check 10 located the pointer with `[regex]::Match` — the **first** match — validated it against the manifest's `Narrative:`, and printed `README and manifest both name session-2026-09-09-slice11-closure.md`. It had never asked whether that row was the only live one.

The block's own text instructs the reader to read it first. An agent reaching it would have re-run finished work — the most expensive cold-start failure there is, because it looks like progress.

### GOV-23 — the sentence explaining the decision line became the decision line

The manifest's `Open owner decisions` line is an enumeration followed by prose *about* the enumeration. Four checks each scraped ids from the whole line with three different regexes, so the sentence *"when GOV-16's guard (**Check 25**) was written"* donated **GOV-16** to the open set. GOV-16 is `### GOV-16 — ✅ FIXED 2026-09-07 (Check 25), mutation-tested`, closed two days earlier. Guard-derived open decisions: **11**. Actual: **10**.

The direction that matters is the quiet one. Check 25 skips every id already on the line, so writing a decision's id into prose **exempts it from ever being surfaced at boot** — the exact failure GOV-16 exists to prevent, reachable by writing a sentence.

### GOV-24 — three vocabularies over one register, and the check that judged decisions could see 65 findings less than it claimed

Measured: Checks 2, 14 and 25 disagreed about SETTLED on **14 rows**.

- Check 14 read **table rows only**. **65 of the register's findings have no table row at all** — they exist solely as `###` detail blocks — and **42 of those 65 are settled**. That is how GOV-16, whose block says `- **Status:** **✅ RESOLVED**`, sat inside the open-decision set while Check 14 printed *"every manifest owner-decision ID is still open in the register"*.
- Check 25 matched a fourth vocabulary **unanchored** inside 80 characters. `ARCH-2`, `DEAD-4`, `SYNC-1`, `ORIG-1`, `JE-2`, `GOV-9`, `PLACE-2` and `CAP-1` all **open** with `OPEN`/`RECORDED`/`UNPROVEN` and were read as settled because *"deliberately NOT **FIXED**"* contains FIXED. Narrowing the window to 80 characters had **bounded** the MEAS-2 class Check 25's own comment claims to have closed; it did not close it.

Checks 14 and 25 ask **inverse** questions of the same rows, so two vocabularies can **deadlock**: a row one calls settled (strike it from the boot line) and the other calls open (put it back) cannot be made CLEAN by any edit. The only reason it had not fired is that none of the 14 currently names a decider.

### Two more of the same class, found in the same sweep

- **CI-1b** — `.github/workflows/repository-consistency.yml` and all three guard-of-the-guard suites were in `on.push.paths` and absent from `on.pull_request.paths`. Check 20 asked whether each path appears **anywhere in the file** and found every one of them on the push side. A guard that greps a file cannot see which of two lists a line is in.
- **SYNC-2** — `scripts/repository-all.ps1` used a bare `exit` on every failure path. **A bare `exit` in PowerShell returns 0.**

---

## §2 VERIFIED (commands run, with their real output)

Repository evidence only. No database was opened.

| Command | Result |
|---|---|
| `git fetch origin` then `git rev-list --left-right --count HEAD...origin/main` | `0	0` — local `main` identical to `origin/main` at `010628b` |
| `pwsh -File scripts/check_repository_consistency.ps1` (baseline, before any edit) | `REPOSITORY CONSISTENCY: CLEAN`, exit 0 — **while carrying all three defects** |
| Same, after repair | `REPOSITORY CONSISTENCY: CLEAN`, exit 0 |
| `pwsh -File scripts/test_cold_start_state_guard.ps1` (new) | **34 passed, 0 failed**, exit 0 |
| `pwsh -File scripts/test_status_contradiction_guard.ps1` | **33 passed, 0 failed**, exit 0 |
| `pwsh -File scripts/test_primary_ledger_guard.ps1` | **13 passed, 0 failed**, exit 0 |
| `pwsh -File scripts/test_future_date_guard.ps1` | exit 0 |

**The numbers that establish the defects, read out of the guard's own output:**

- Before: `all 11 manifest decision IDs resolve` and `checked against 11 open id(s)` — against a manifest enumerating **10**.
- After: `checked against 10 open id(s)`, while the manifest line still literally contains `GOV-16` in its prose. The exclusion is real, not an absent input — asserted as a control in the new suite.
- After: Check 25 reports `all 9 register entr(ies) awaiting a decider are named on the manifest's boot line (of 273 findings read across table rows and detail blocks)`. Population: 273 findings carrying a signal, 264 settled, 29 naming a decider, **9** live decisions, all surfaced. Before, the same check read table rows only.
- Check 20 after: `push (12 paths) and pull_request (12 paths) both cover all 11 guard inputs, and agree with each other`.

**The `exit` semantics were measured, not assumed** (`AGENTS.md §6`, test-before-trust). An isolated probe: a script whose last command exits 7, then running `if ($LASTEXITCODE -ne 0) { exit }`, reports **exit code 0** to its caller.

---

## §3 FIXED

**One parse and one resolver replace four and three.**

1. **`reports/README.md`** — the stale block was **deleted, not refreshed** (the 2026-09-01 precedent). Nothing was lost: its substance survives in the `Previously:` row for the same report.
2. **Check 10 widened** to the invariant it always named: exactly **one** live cold-start declaration, and it must name the manifest's `Narrative:`. The rule is the file's **own convention** — every superseded row is prefixed `Previously:` or `Before that:` — so a blockquote carrying a cold-start directive without a historical prefix is live. Not a keyword list; a structural feature of the document.
3. **The manifest decision line is parsed once**, and yields two deliberately different sets: `$openDecisionIds` (the enumeration, ending at the first sentence terminator — finding ids contain no periods, so the boundary is unambiguous) is the **state** used by Checks 14/16/25; `$decisionLineIds` (every id on the line) answers Check 11's **reference** question alone, a superset by construction so the two can never contradict. It fails loud rather than silently empty. The dead `Genuinely open:` cut was removed — that marker had left the manifest, so the cut fell through to the whole line and Check 14 had been reading the narrative too.
4. **One settled vocabulary**, taken from this register's own Legend and its five-state table, **anchored** at the field's opening — because that is where this register writes its verdict, and because 17 rows legitimately retain superseded wording after it.
5. **One resolver, `Get-RegisterFindingState`**, reading table rows, `###` headings and detail-block `**Status:**` fields together, monotonic in both signals.
6. **Checks 14 and 25 are now exact inverses** over two signals — *settled* and *names a decider*: Check 14 fires on `on the line + settled + no decider`, Check 25 on `has a decider + not settled + absent from the line`. They cannot answer one row differently.
7. **CI-1b** — `pull_request` triggers completed; Check 20 parses the two blocks separately, compares them symmetrically, and **derives** the suite list from the workflow's own `foreach ($suite in ...)` line rather than restating it.
8. **SYNC-2** — `repository-all.ps1` exits non-zero on a failed generate, commit, push, and on cancellation, and says what failed and what state the tree is in.

**The second signal exists because of RET-1, and that is the finding inside the finding.** A status-only reading called RET-1 settled — its blocks say `✅ RESOLVED — IMPLEMENTED` — and the first run of this repair duly told the guard to strike a **live compliance decision** off the boot line. Worse than the miss being fixed, and in the destructive direction. The discriminator is the register's own, declared in its five-state table: *"the Owner Decision column is non-empty, and the id appears on manifest.md's open-decision line"*. GOV-16 (settled, `**Owner:** engineering`) and RET-1 (settled, `**Owner:** owner + counsel`) now separate with **no special case for either**.

---

## §4 NOT FIXED (and why)

- **Protected-file enforcement is prose plus a registry, and nothing behavioural.** There is no CODEOWNERS file, no git hook, and no guard check that refuses a write to `AGENTS.md`, `README.md` or `_ORVION_CANONICAL/**`. Building one requires expressing *per-task authorization* — `GOVERNANCE.md §5` marks those rows "owner-authorized", and `manifest.md` carries its **own** row (`Living`, "every CR") that legitimately permits the edits every session makes. A mechanism that cannot tell an authorized edit from an unauthorized one would either block normal work or pass everything. **That is a governance design decision, not a parser repair, and it is reported rather than invented.**
- **`AGENTS.md §6`'s inline protected list names five files; `GOVERNANCE.md §5` marks three "Living (protected)".** The drift is in the **safe** direction (the prose list is broader) and `AGENTS.md` explicitly says the line is not exhaustive and defers to §5. No demonstrated failure path; recorded, not guarded — adding a check here would be the speculative hardening `§18` forbids.
- **SYNC-2 has no automated regression test.** Exercising `repository-all.ps1`'s failure paths would run `git add`/`commit`/`push` against the working tree. The underlying `exit` semantics are proven by an isolated probe and the change is a four-line exit-code correction. Stated rather than hidden.

---

## §5 BLOCKED

Nothing. No external action is required by any item in this session's scope.

---

## §6 GOVERNANCE

- Five findings recorded in `MASTER_GAP_REGISTER.md`: **COLD-2b**, **GOV-23**, **GOV-24**, **CI-1b**, **SYNC-2**, each `✅ FIXED 2026-09-09` with `Owner Decision` empty, so none enters Check 25's decision population.
- **No new mechanism, register, framework or authority was introduced.** Four parses became one; three vocabularies became one; two substrate readers became one. `§23`'s cleanup requirement is satisfied by **removal**, not by layering: the dead `Genuinely open:` branch, three duplicate id regexes, two redundant whole-file reads of the manifest, and Check 2's private detail-block vocabulary are gone.
- The guard's header comment claimed "Nineteen checks" over a script with twenty-five; corrected, and the three unified behaviours are recorded where the next author will read them.
- **A protected file was edited: `_ORVION_CANONICAL/manifest.md`, `Narrative:` field only.** Sanctioned by `GOVERNANCE.md §5`, whose registry gives `manifest.md` its own row — `Living`, updated "every CR" — and mechanically forced by Check 10, which requires that field to equal this report's pointer. No other manifest field was touched: `Last Completed`, `Next capability`, `Active Change Request` and the open-decision line are unchanged, because no capability was completed and no decision was taken.

---

## §7 ENVIRONMENT

Windows 11, PowerShell 7. No Docker, no local stack, no Supabase connector used. `git fetch` reached `origin` successfully.

---

## §8 CURRENT STATE

| Axis | State | Evidence class |
|---|---|---|
| Migrations | 211, latest `20260909114354`, ledger `d0ecf99da5c6276ee9858deb699f0511` | REPOSITORY — unchanged this session |
| Repository consistency | **CLEAN**, Checks 1–25, exit 0 | REPOSITORY |
| Guard-of-the-guard | 4 suites, **80 assertions**, all green | REPOSITORY |
| Local database | **not started, not reset, not queried** | — |
| Primary parity | **UNPROVEN this session.** Check 19 confirms the RECORDED reading only | — |
| Batch 6 | 12 of 77 — **NOT complete**, unchanged | REPOSITORY |
| Open owner decisions | **10**, mechanically derived from the manifest's enumeration | REPOSITORY |
| Git | `main` == `origin/main` at `010628b` before this session's commit | REPOSITORY |

---

## §9 NEXT STEP

**Exactly one:** commit this session's changes and push. The repository records that `git push origin main` hangs non-interactively because `origin` carries no username — push with `git push https://PlatPlusHub@github.com/PlatPlusHub/CRM.git main`, as the 2026-09-04 report directs, and never read the hang as a reason to force or reset.

After that, Batch 6 slice 12 begins with `scripts/batch6_select_target.ps1`. **This session started no slice and authorized none.**
