# ORVION — the layer that records the work could contradict itself, and a guard now says so

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-05
Author: Claude Opus 5
Status: **COMPLETE — no migration. One new CI-gated invariant (Check 21 / Docs-21 / `GOVERNANCE.md §6` rule 8), four stale document headers repaired, two missing ADR entries restored, one stale count deleted, and Batch 6 given measurable exit criteria while remaining explicitly INCOMPLETE.**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED, clean and verified before touching anything.** HEAD `024ddab` = `origin/main` (0/0), working tree clean, **199** migration files, local DB 199, Primary 199 with all three surface hashes matching. Nothing was ahead of anything.
- **PROVEN (this session):** the failure is real and was reproduced before the fix — the new check found **four** stale document headers on its first run, not the one that prompted the task. Guard **CLEAN, Checks 1–21** after repair. **Zero database change**: no migration, no function, no grant, no policy, no test-suite change, so the 199/1476/430 evidence from `session-2026-09-05-p3-delivery-lifecycle.md` stands unaltered and was not re-manufactured here.
- **UNPROVEN, and not claimed:** Check 21 cannot see a substantive edit that carries **no date** — rewriting a paragraph and dating nothing passes it. It does not judge whether the *annotation* beside the date is true. And **Batch 6 coverage is still not measurable**: EC-1 exists precisely because no per-table audit disposition record does.
- **CHANGED:** `scripts/check_repository_consistency.ps1` (Check 21); `GOVERNANCE.md` (§6 rule 9, v1.12 → v1.13); `MASTER_REPOSITORY_HEALTH.md` (Docs-21, header, §5 stale count deleted); `MASTER_EXECUTION_PLAN.md` (header, item 7's 75 → 77, Batch 6 exit criteria); `MASTER_ARCHITECTURE_DECISIONS.md` (header + ADR-0027/0028); `MASTER_DOMAIN_CATALOG.md`, `MASTER_RISK_REGISTER.md` (headers); `MASTER_GAP_REGISTER.md` (STALE-1 row + header); this report; `reports/README.md`; `manifest.md`; `ai-map.json`.
- **REMAINING:** **MAIL-1** is still the only open owner decision — untouched by this session. **DELIV-1** is still the recommended next engineering step. **EC-1** (the per-table disposition record) is the first move of any future Batch 6 slice.
- **DO NOT TOUCH:** do not "improve" Check 21 into a wall-clock check — "`Last updated` must equal today" was considered and rejected in writing, and would fail every finished document every day until the guard is ignored. Do not generate the field from git: it carries a written annotation git cannot supply, and git's date is the date of *any* touch. Do not add an exemption list — the scope is self-selecting by design, and Check 12 already records why exemption lists are where the next instance hides. Do not delete the historical "75 tables" figures in Batch 6's closed package entries: each was true on its own date.
- **NEXT:** §7.

---

## 1. WHAT WAS ACTUALLY WRONG

The task named one field: `MASTER_EXECUTION_PLAN.md` said `Last updated: 2026-09-02` while its own item 4 carried a P3 entry dated 2026-09-05.

Changing `09-02` to `09-05` would have been the fourth hand-repair of this class and the fourth time the mechanism survived the repair:

| When | Document | How it was found | What was done |
|---|---|---|---|
| 2026-07-14 | `MASTER_ARCHITECTURE_DECISIONS.md` | a human reading the file (`session-discovery-checkpoint`, finding **F2**) | recorded, refreshed by hand |
| 2026-07-15 | `MASTER_GAP_REGISTER.md` | the Repository Recovery audit | refreshed by hand |
| 2026-08-29 | `MASTER_GAP_REGISTER.md` again — rows dated 08-24…08-29 under `2026-08-21` | the pre-Phase-10 reconciliation | refreshed by hand, and *named in the register as the drift it describes* |
| 2026-08-29 | `MASTER_EXECUTION_PLAN.md`'s own header — `2026-07-15` while Batch 6 ran to 2026-08-29 | the same reconciliation | refreshed by hand |
| 2026-09-05 | `MASTER_EXECUTION_PLAN.md` again | this task | **guarded** |

Four repairs, four documents, no check. That is the definition of a missing fitness function, and this repository's own standard (`GOVERNANCE.md §18`, the discovery-to-guard loop) says the fix is the guard, not the fifth repair.

**The first run of the guard proved the task's own premise incomplete.** The directive said "do not assume the problem is isolated to `MASTER_EXECUTION_PLAN.md`". It was not: three more Masters were already in the same state, and one of them had been in it for **seven weeks**.

---

## 2. THE MECHANISM, AND THE TWO IT IS NOT

**Chosen: validation (Option B), inside the existing consistency guard.**

The invariant:

> A document's freshness metadata must never be **older than the newest date its own body carries**.

**Why not generation (Option A).** Every one of these headers is a date *plus a written account of what changed and why* — `MASTER_GAP_REGISTER.md`'s runs to a paragraph, and `MASTER_EXECUTION_PLAN.md` chains them as cumulative history. `git log -1 --format=%ad` can supply the date and nothing else, so a generator would either destroy the annotation or stamp a fresh date beside a paragraph that no longer matches it — a *new* contradiction in the same field. Worse, git's date is the date of **any** touch: a typo fix would advertise itself as a substantive update, and the field would stop meaning what its readers use it for. The annotation is human authorship. Only its **consistency** is mechanisable.

**Why not a hybrid (Option C).** The generated half has nowhere sound to stand, for the reason above. A hybrid here would be two mechanisms for one field — the duplicate-authority mistake `GOVERNANCE.md §6` rule 1 exists to prevent.

**Why not wall-clock.** The directive warned against it and the warning is correct: "`Last updated` must equal today" fails every legitimately finished document every day. `MASTER_HEAT_MAP.md` has not changed since 2026-07-11 and is not stale — its header describes its content exactly. A guard that is always red is a guard nobody reads, and this repository already has the `Check 5` precedent for what happens when a guard is treated as noise. The invariant chosen fires on **exactly one event**: dated content was added and the header stayed behind.

**Why it extends the existing guard rather than adding a mechanism.** Three reasons, each checked rather than assumed. It reads the same evidence class every other check in that file reads — repository files, no database. Its inputs (`**/*.md`) are **already** in the workflow's path filters, so it needed no new trigger and no new workflow. And it is the exact mirror of a check that already exists: **Check 12** forbids a header dated *ahead* of its evidence; Check 21 forbids one dated *behind* its content. The two now bracket the same field from both sides, which is an argument for one file, not two.

---

## 3. THE GUARD CAUGHT ITS OWN AUTHOR

Written into the record because `AGENTS.md §6` requires attacking a new detector before trusting it, and because this is the counterexample the rule asks for.

Two of the four repairs were first written as *"corrected 2026-09-05"* inside a header that declared an older date — an attempt to restore "the date the content earns" while narrating today's edit in the same line. Check 21 refused both, correctly: a line carrying `2026-09-05` **is** content dated 2026-09-05, so declaring an older date there is the contradiction, not an explanation of it. Both were rewritten in the append-and-demote form the check's own remedy text prescribes — a new dated line, the old one moved to `Previously:` — which is also what the documents' existing convention already did.

**Both directions were exercised, which is the standard:** the check flagged four real cases and, after repair, passed 19 documents including every one it had just failed. The must-not-flag direction is the 13 documents that were correct throughout and stayed green — among them `MASTER_HEAT_MAP.md` at 2026-07-11, the case a wall-clock guard would have failed.

---

## 4. WHAT ELSE THE SWEEP FOUND

The directive asked for a *targeted* search for related current-state metadata, not a forensic audit. Four things surfaced and all four are corrected:

* **`MASTER_ARCHITECTURE_DECISIONS.md` was missing two ratified ADRs entirely.** Chasing its stale header found the larger half: the file promises in its own §3 to track "(a) accepted ADRs", and stopped at ADR-0026 while **ADR-0027** (2026-09-02, capability grants per-user) and **ADR-0028** (2026-09-04, the supplier ceiling is an observation, not a gate) had been ratified in `architecture-decision-records.md`. Both entered with their ARB verdict; the authoritative text stays where it belongs.
* **The execution plan's sweep scope was understated.** Item 7 read "all **75** tables" from 2026-08-27 onward; the live count has been **77** since `document_retention_policies` and `document_storage_findings` were created. Corrected **against the catalog** (`pg_tables`, 77), not against another document. The three *historical* "75" figures in closed package entries are deliberately left alone — each records what was measured on its own date.
* **`MASTER_REPOSITORY_HEALTH.md §5` restated "the **18** checks registered in §2b"** against a registry that now runs to 21. **Deleted rather than refreshed**, which is the answer GOV-5 already established for a count restated beside the list it summarises — and which §2's own Automation-Coverage row already applies by pointing at §2b instead of counting.
* **`GOVERNANCE.md`'s `Version N · date` line** turned out to be the same class of claim, in the one document that now *declares* the rule. It is inside Check 21's scope for that reason: §15 already requires the version line and the top changelog entry to move together, and a rule whose own home is unguarded is decorative. Measured before widening the regex — it is the only file in the repository carrying that shape, and it had been kept in sync until this session's own edit made it stale.

**Deliberately NOT edited:** `reports/history/**`. Those are immutable point-in-time records, they carry `Date:` rather than a freshness claim, and several legitimately contain figures that were true when written and are not now. They are exempt **by construction, not by exemption** — there is no exemption list anywhere in this mechanism.

---

## 5. BATCH 6 — INCOMPLETE, AND NOW WITH A FINISH LINE

`MASTER_EXECUTION_PLAN.md` item 7 says the table/column completeness sweep was never finished. **That conclusion is unchanged and was not softened.** A large passing test suite is a different claim.

Added to the plan: the standing method (discover → classify → adversarially test → repair → retest → reconcile → document → guard) and **eleven exit criteria, EC-1…EC-11**, each stated with how it is measured *today* rather than as an aspiration. Two were refined rather than adopted as proposed:

* **EC-1 was proposed as "100% of the table inventory audited".** A *count* of audited tables is not measurable without a per-table disposition record, and none exists. The obvious proxy is worthless: **all 77 tables are named somewhere in `reports/**`**, which proves only that mention is not audit. EC-1's criterion is therefore the record itself; the count is what the record then yields.
* **EC-6 gained an explicit *negative*-test requirement.** The suite's 1,476 assertions are overwhelmingly positive controls, and a positive-only surface is exactly where LIC-2, SPP-2 and FIN-3 were found hiding.

**The one honest coverage number available today:** 75 of 77 tables are named in at least one pgTAP file; **`campaign_daily_metrics` and `exchange_rate_adjustments` are named in none.** Being named in a test is a floor and not coverage — but a table no test mentions at all is definitively unswept, and those two are the only assertions possible before EC-1's record exists.

**Assurance classification, kept separate as the directive requires.** ORVION is **TESTED** and **SUBSTANTIALLY ADVERSARIALLY TESTED** — specific assumptions were attacked and held (concurrent double-redemption of a single-use licence token under two live psql sessions, forged audit events, cross-tenant reads by a fully privileged owner of another agency, direct-DML capability bypass across 59 tables, trigger bypass, lease expiry and retry races, PAR-4 defect injection). It is **NOT exhaustively adversarially audited**: the surfaces challenged were the ones a defect led us to, which is a weaker claim than every surface having been challenged systematically. No document may say otherwise until EC-1 and EC-6 both hold, and that sentence is now written into the plan rather than left to discipline.

---

## 6. CI TRIGGER BLIND SPOT — RE-CHECKED, ALREADY CLOSED

The directive asked whether the `supabase/migrations/**` / `supabase/tests/**` / `ai-map.json` blind spot still exists. **It does not**, and it was verified rather than assumed: all three are present in `repository-consistency.yml` under both `push` and `pull_request`, closed on 2026-09-05 as **CI-1**, and **Check 20** now fails the build if any known input path goes missing. Check 21 needed no addition — it reads `**/*.md`, which has been in the filters since the workflow was written. Check 20's description of that entry was updated to name Check 21 among its readers, which is the one thing the fixed-list design requires of anyone adding an input.

Migration CI stays a separate workflow, deliberately: it runs a database stack and validates a different evidence class.

---

## 7. NEXT

**DELIV-1** — one `reporting` view over work that has exhausted its retries, covering both outboxes. Unchanged by this session, engineering-owned, needs no owner input.

Then **EC-1**: the per-table audit disposition record, which is the only thing standing between Batch 6 and a measurable coverage number. It is a documentation artifact, not a migration, and every subsequent exit criterion reads from it.

---

## 8. VERIFICATION

| Gate | Result |
|---|---|
| `check_repository_consistency.ps1` — before repair | **4 issues**, all Check 21, all genuine: `MASTER_EXECUTION_PLAN` (09-02 vs 09-05), `MASTER_ARCHITECTURE_DECISIONS` (08-10 vs 08-31), `MASTER_DOMAIN_CATALOG` (07-11 vs 08-29), `MASTER_RISK_REGISTER` (07-11 vs 07-13) |
| `check_repository_consistency.ps1` — after repair | **CLEAN, Checks 1–21** |
| Check 21 must-not-flag direction | 19 documents carrying freshness metadata pass, including `MASTER_HEAT_MAP.md` at 2026-07-11 — the case a wall-clock guard would wrongly fail |
| Live table count | `pg_tables` in `public` = **77** (item 7's "75" corrected against this, not against a document) |
| pgTAP table naming | 75 of 77 tables named in at least one test file; `campaign_daily_metrics` and `exchange_rate_adjustments` in none |
| Database | **UNCHANGED — no migration, no function, no grant, no policy, no test file.** The 199 / 1476 / 430 evidence from the P3 session stands and was not re-manufactured |
| Parity | unaffected: repository = local = Primary at **199**, ledger `829b15676b66b7d0cc744ebb9ecbddc1`, functions `0344913a0040acaf78806c041bd231ed`, structure `9f5d544b6b1bc4d2cfe833bd85336fc5` |

**Evidence class, stated so this report cannot be quoted for more than it proves (MEAS-1).** Every gate above reads **repository files**. No database was queried except the one read that item 7's correction required — the live `public` table count. This session proves a documentation invariant; it proves nothing new about the schema, and claims nothing new about it.

End of report.
