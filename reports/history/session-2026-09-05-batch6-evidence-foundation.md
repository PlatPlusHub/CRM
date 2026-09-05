# ORVION — Batch 6 gets a record it cannot lie in, and the first slice fills it

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-05
Author: Claude Opus 5
Status: **COMPLETE — one migration (`202607061100`), deployed to Primary and parity-verified on all three surfaces. One new Master (`MASTER_SURFACE_DISPOSITION.md`), two new CI-gated checks (22, 23), three defects found and fixed, one new pgTAP file. Repository = GitHub = local = Primary at 200 migrations. Batch 6 remains explicitly NOT COMPLETE.**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED, verified before touching anything.** HEAD `a3ea3f0` = `origin/main` (0/0), working tree clean, 199 migrations on all three surfaces, consistency guard CLEAN 1–21. Nothing was ahead of anything and nothing was stale.
- **PROVEN (behavioural evidence, this session):** 200 migrations apply clean from scratch; pgTAP **101 files / 1497 assertions PASS** (was 100/1476); smoke `ALL CHECKS PASSED (77 tables … 71/611 catalog)`; consistency **CLEAN 1–23**; **Primary parity PROVEN on all three surfaces, values READ FROM Primary** — ledger `b0ce14818b8c21bc4bb017c9cd893efd` (200), functions `0344913a0040acaf78806c041bd231ed` (276, unchanged), structure `da933f4c479a1b1fe13479c5c365de68` (3,537 across ten surfaces). The three new defects were each **reproduced before being fixed** and each has a failing-then-passing assertion.
- **UNPROVEN, and not claimed:** the six HTTP suites were **not re-run** — safe by measurement rather than assumption (no HTTP script references either table this migration touches; grepped), so the 430 figure is carried forward as inherited, not re-earned. **Batch 6 coverage is 2 of 77**, and 75 surfaces have no recorded disposition. Check 22 cannot tell a true disposition from a false one; only the named session report can.
- **CHANGED:** `202607061100`; `101_marketing_metrics_and_fx_adjustment_surface_test.sql` (new, 21); `MASTER_SURFACE_DISPOSITION.md` (new Master); `check_repository_consistency.ps1` (Checks 22, 23); `GOVERNANCE.md` (§2 SSOT row, §5 registry, v1.13 → v1.14); `MASTER_REPOSITORY_HEALTH.md` (Docs-22/23, header); `MASTER_EXECUTION_PLAN.md`; `MASTER_GAP_REGISTER.md` (five rows: DISP-1, HANDOFF-1, CDM-1, CDM-2, ERA-1); `MASTER_API_CONTRACT.md` (regenerated — one line); `manifest.md`; ledger evidence; `ai-map.json`; `reports/README.md`.
- **REMAINING:** **MAIL-1** is still the only open owner decision and this session did not touch it. **75 surfaces** at `NOT-RECORDED` — that is Batch 6's remaining work and it is now a number rather than a feeling.
- **DO NOT TOUCH:** do not add `EXHAUSTIVE` to the assurance vocabulary — it is a claim about the programme, and making it a per-surface value would let ORVION's strongest claim be asserted one table at a time. Do not retrofit HANDOFF blocks into reports dated before 2026-09-05: they are immutable, and Check 23 is forward-only by design, not by omission. Do not "restore" `scope_update` on `exchange_rate_adjustments` — canon 31 withholds `updated_at` from that table deliberately, and correcting a correction is a new row. Do not hand-maintain the surface list in the disposition record; Check 22 derives it, and a hand-maintained list is the STALE-1 class one file over.
- **NEXT:** §8.

---

## 1. WHAT WAS ALREADY THERE, AND WHY ALMOST NOTHING NEW WAS BUILT

The brief asked for durable session evidence, an LLM-agnostic handoff, machine-readable discovery, failed-attempt knowledge, and a Batch 6 disposition model — and asked first whether ORVION already had them. It largely did. Measured:

| Requirement | Existing mechanism | Verdict |
|---|---|---|
| Session evidence with lineage | `AGENTS.md §6`: nine ordered sections, 128 immutable reports in `reports/history/` | **EXISTS** — extended by measuring it (Check 23) |
| LLM-agnostic handoff | `AGENTS.md §6`: seven-field HANDOFF block (INHERITED · PROVEN · UNPROVEN · CHANGED · REMAINING · DO NOT TOUCH · NEXT), reached from `reports/README.md`'s pointer, which **Check 10** already keeps current | **EXISTS, and was unmeasured** → Check 23 |
| Current-state vs history separation | `GOVERNANCE.md §6` rules 3 and 9; Check 21 | **EXISTS** |
| Machine-readable index | `ai-map.json`, generated, boot-order + live-state pointers | **EXISTS for canon** — a session index was **rejected**, §4 |
| Failed-attempt knowledge | `reports/evidence/REJECTED_ARCHITECTURE_DECISIONS.md` (design-time), `AGENTS.md §4.13` and `§6` (standing lessons with finding ids), the HANDOFF `DO NOT TOUCH` field (per-session) | **EXISTS in three scoped homes** — a fourth was **rejected**, §4 |
| Documentation guards | 21 CI-gated checks, registered in `MASTER_REPOSITORY_HEALTH.md §2b` | **EXISTS** — extended by two |
| **Per-surface audit disposition** | **nothing** | **GENUINELY MISSING** → the one new artifact |

So: **one new Master, two new checks, zero new systems.** No second index, no second findings register, no second governance file, no parallel handoff rule.

**Why this did not trip the brief's §21 stop condition.** A new Master is not a new architecture; it is the application of an existing one. `GOVERNANCE.md §2` requires an SSOT row for any new concept, and **GOV-2** exists precisely because `MASTER_API_CONTRACT.md` was Living-Authoritative for weeks without one. The row was written at creation, in the same commit, and states the boundary in both directions.

---

## 2. THE ONE NEW ARTIFACT, AND WHAT IT DELIBERATELY DOES NOT HOLD

`reports/master/MASTER_SURFACE_DISPOSITION.md` — one row per `public` table, **six columns**, of which only two are facts and four are pointers:

| Column | Why it is here, or what it points at |
|---|---|
| Surface | the key; the SET is derived, never maintained |
| **Disposition** | the fact this file exists to hold, from a closed five-value vocabulary |
| **Assurance** | the second fact, from a closed three-value vocabulary |
| Session | → the immutable report that holds the evidence |
| Findings | → ids only; `MASTER_GAP_REGISTER.md` owns their status |
| Next | the exact remaining action for this surface |

The brief offered fourteen candidate columns. Nine were **rejected because they are derivable or already owned**: "Tested" is derivable from the pgTAP files; "Findings"/"Repair"/"Retest"/"Guard" are the register's and the migration's; "Scope"/"Expected"/"Inspected" belong in the session report's narrative, and putting them in cells is how a coverage record becomes the historical diary the brief's §6 forbids. **Every restated fact is a fact that can go stale** — the class this repository guarded twenty-four hours earlier as STALE-1 — so the discipline is: hold the disposition, point at everything else.

**`NOT-RECORDED` is a statement about the record, not the surface**, and the value is named that way so it cannot be misread. `notification_deliveries` was audited, repaired and guarded three days ago; its row says `NOT-RECORDED` because it has not been assessed *against Batch 6's exit criteria*, which is the stricter question. Seeding 75 rows any other way would have meant assigning dispositions from prose across 77 tables — a forensic pass with high error risk and no evidence behind it.

**There is deliberately no `EXHAUSTIVE` assurance value.** Exhaustive adversarial audit is a claim about the programme and requires every row to hold at `ADVERSARIAL` simultaneously. As a per-surface label it would let ORVION's strongest claim be assembled one table at a time with nobody ever checking the whole.

**Opening count: 2 of 77 recorded.** That number is meant to be uncomfortable. It replaces two that read better and mean less — "all 77 tables appear in the reports" (true, and worthless: mention is saturated) and "75 of 77 appear in a pgTAP file" (true, and a floor).

---

## 3. THE TWO NEW GUARDS

**Check 22 (DISP-1) — the coverage record cannot drift from the schema.** It derives the expected surface set from `supabase/migrations/**` (`create table` less `drop table`) and fails on four different lies a coverage record can tell: a phantom row, a missing row, an off-vocabulary value, or a session/finding pointer that does not resolve. So a migration that adds a table turns the build red until that table has a row — which is the only mechanism that keeps a coverage denominator honest as the schema grows. **Ceiling stated in the check and in the file:** it parses DDL text, so dynamic SQL or `ALTER TABLE … RENAME` would fool it; bounded because `verify_database.sql` and `check_database_parity.ps1` both read the live catalog from the other side. Today the derivation returns exactly the 77 tables the catalog holds.

**Check 23 (HANDOFF-1) — the continuity mechanism is now measured.** `AGENTS.md §6` has required the seven-field HANDOFF block since 2026-09-05 and nothing checked it: the documentation-stronger-than-the-measurement class (**MEAS-1**) applied to the one document a cold start depends on most. **Forward-only, and that is not a loophole:** `GOVERNANCE.md §6` rule 3 makes history immutable, 123 of 128 reports predate the rule, and retrofitting an immutable record to satisfy a later convention would be a worse defect than the one being fixed. The check reads each report's own `Date:` and applies the rule only from the date the rule exists.

Both are in the **existing** guard, run by the **existing** workflow, and needed no new trigger path: Check 22's inputs (`supabase/migrations/**`) and Check 23's (`**/*.md`) were both already in the filters, and Check 20 was updated to name them as readers.

---

## 4. WHAT WAS REJECTED, AND WHY

**A machine-readable session index — rejected.** It would index 128 immutable files whose names already encode date and topic, restating their class, date, findings and next action in a second place. Every one of those is either in the report (immutable, so the index would be a stale copy) or in the register (which owns finding status). It would be a second knowledge system over an existing one, which is exactly what the brief's §1 forbids. What a fresh session actually needs is *one* pointer to the *latest* report — `reports/README.md` has it, `AGENTS.md §4` Stage A step 7 makes reading it mandatory, and **Check 10** already proves it is current. That is the whole discovery path, and it is one hop.

**A fourth home for failed-attempt knowledge — rejected.** Negative knowledge already lives in three homes with distinct, non-overlapping scopes: `REJECTED_ARCHITECTURE_DECISIONS.md` (design-time rejections, RJ-1…RJ-8), `AGENTS.md §4.13` and `§6` (standing lessons, each with the finding id that earned it), and each session's `DO NOT TOUCH` field (this session's boundary, stated by the session that found it). Adding a fourth would create the competing definition the brief forbids. What was missing was not a home but a *measurement* — hence Check 23, which makes `DO NOT TOUCH` mandatory in fact rather than only in rule.

**A guard on "the next action points at completed work" — rejected.** Check 10 (the report pointer) and Check 18 (the Active CR) already close the mechanical half. The remaining half is the manifest's prose `Next capability`, and judging whether a sentence describes finished work requires reading meaning. A guard that guessed would go green while wrong, which this repository has repeatedly established is worse than no guard.

**`app.forbid_acquisition_lineage_rewrite` for ERA-1 — rejected, twice over.** The parameterised column-freeze already existed and was the obvious reuse. Its semantics are FIRST-TOUCH (NULL → value allowed once), which is meaningless for columns that are `NOT NULL` from birth; and canon withholds `updated_at` from the **whole row**, not from three columns. `app.forbid_mutation()` — ORVION's ratified full-immutability trigger, already carried by `events` and `security_events` — says exactly what canon says.

---

## 5. THE FIRST SLICE, CHOSEN BY MEASUREMENT

Of 77 tables, 75 are named in at least one pgTAP file. **`campaign_daily_metrics` and `exchange_rate_adjustments` were named in none** — the only two surfaces that could be *asserted* un-audited before the record existed. That is why they were first: not because they are important, but because they were the only defensible choice.

**Proven, not assumed, before anything was changed:** neither table has **any** consumer — zero functions (`pg_proc.prosrc`) and zero views (`information_schema.view_column_usage`). So there is no RPC door for direct DML to bypass; the table door **is** the door, which is SEC-2's ratified reading, and RLS is legitimately the complete enforcement layer. Both already carry a permission in the write half of their policies, and all three governing permissions are held by real roles — so neither is an unreachable capability. **Nothing about authorization was widened or narrowed.** That non-finding is pinned by assertion 1, which fails the moment either table grows a function consumer and this reasoning has to be redone.

Three defects, each reproduced first:

**CDM-1 (Medium).** `campaign_daily_metrics` had `PRIMARY KEY (id)` and nothing else, while canon 31 defines it as "daily marketing performance values" and says "metrics may be imported from integrations". An import is retried; a retry inserted a second row for the same campaign-day and every `SUM` double-counted silently. **DC-2's idempotency class, on the one table whose own name says how many rows a day may have.** Fixed with a unique index on `(tenant_id, marketing_campaign_id, metric_date)`.

**CDM-2 (Low).** No CHECK constrained any measure — negative impressions, clicks, leads, bookings, spend or revenue were all storable. Not policy: negative impressions is arithmetic, and the money columns follow **CUST-4**'s precedent exactly. NULL stays legal on all six because canon marks all six nullable, pinned by a negative control.

**ERA-1 (Medium).** Canon 31 lists this table's fields and gives it **no `updated_at`**, while giving one to every table it means to be updated. Canon already said the record is written once; nothing enforced it. A `finance_manager` could rewrite which rate had *originally* been locked, after the fact, with no `updated_at` and no event to show it. Fixed with the **same three layers that make `events` append-only** — trigger, revoked grant, removed policies — because any one alone is a half-fix. The layer-1 assertion runs **as the table owner deliberately**: run as `authenticated` it would pass on the revoked grant alone and never reach the trigger.

---

## 6. FAILED ATTEMPTS — RECORDED BECAUSE THE BRIEF IS RIGHT THAT THEY ARE KNOWLEDGE

Four, all mine, all caught by the guards rather than by review:

1. **Check 22 reported five phantom surfaces on its first run.** PowerShell's `-match` is **case-insensitive by default**, so a lowercase `[a-z_]` row pattern also matched the two uppercase VOCABULARY tables in the file's own header (`| AUDITED | …`). Fixed with `-cnotmatch`. The lesson generalises: any PowerShell guard whose discriminator is *case* must say so explicitly, and ORVION's table names are lower_snake_case by convention, which is what makes case a valid discriminator here.
2. **Check 23 reported `PROVEN` missing from all five reports that carry it.** The field pattern demanded a colon or comma immediately after the label; reports write `**PROVEN (behavioural evidence, this session):**`. Fixed with a word boundary — and the `**` prefix is what still keeps `**UNPROVEN` from satisfying `PROVEN`.
3. **The new test's fixture dates broke Check 12 — twice, the second time in this very report.** The pgTAP fixture used campaign-days a day and two days *ahead* of the session date, and to Check 12 those are future-dated evidence; it has **no exemption list by design**. The fix was mine, not the guard's: the fixture moved into the past. Then this report's first draft **quoted the offending dates literally** while describing the incident, and the guard flagged it again — which is precisely the failure mode its own comment records from 2026-08-29 and the reason it says to *describe* a bad date rather than reproduce it. A test fixture is not exempt from a repository invariant merely because it is a fixture, and neither is a report about one.
4. **`git checkout --` during the previous session's mutation test discarded uncommitted work.** Reverting a *mutation* on a file that also held unstaged real edits threw both away. The mutation-test pattern is only safe on files with no pending changes; otherwise stage first or use a copy.

---

## 7. VERIFICATION

| Gate | Result |
|---|---|
| `npx supabase db reset` | **200** migrations apply cleanly from scratch |
| `npx supabase test db` | **101 files / 1497 assertions — All tests successful** (was 100/1476) |
| `scripts/verify_database.sql` | `ALL CHECKS PASSED (77 tables … 71/611 catalog …)` |
| `check_repository_consistency.ps1` | **CLEAN, Checks 1–23** |
| Check 22, first run | 8 issues, all genuine and all mine — five phantom rows (case-insensitivity), three unregistered findings (register rows not yet written) |
| Check 23, first run | 5 false negatives from my own field pattern; fixed, then **6 of 6** reports pass |
| **Mutation test, both checks, both directions** (`AGENTS.md §6`) | **4 of 4 mutations flagged, and an untouched tree passes.** Removing one surface row → `UNCOVERED SURFACE: 'users'`. Adding a row for a table no migration creates → `PHANTOM SURFACE: 'ghost_table'`. Claiming `EXHAUSTIVE` on a surface → `OFF-VOCABULARY ASSURANCE … EXHAUSTIVE is deliberately not a per-surface value`. Renaming `DO NOT TOUCH` in this report → `INCOMPLETE HANDOFF … is missing DO NOT TOUCH`. Every file restored afterwards |
| `check_database_parity.ps1` + three Primary values | ledger, function surface and structural surface **all match**; contract regenerated and matches live |
| `generate-api-contract.ps1` | **one line changed** — `exchange_rate_adjustments` `SIU-` → `SI--`, policies `scope_delete, scope_insert, scope_read, scope_update` → `scope_insert, scope_read`. Exactly ERA-1's client-visible consequence and nothing else |
| six HTTP suites | **NOT RE-RUN.** Safe by measurement: no HTTP script references either table (grepped). The 430 figure is inherited, not re-earned, and the manifest says so |

**Primary values were READ FROM PRIMARY** through the `supabase-primary` MCP using the same `scripts/parity_surface.sql` both sides run (GUARD-1). As in every prior session, `apply_migration` stamped its own timestamp version and the ledger row was corrected to the repository's synthetic scheme before comparing; the refreshed evidence file's recomputed fingerprint was then checked equal to the one Primary returned.

---

## 8. NEXT

**Batch 6 slice 2.** The model is now fixed and the next slice uses it unchanged — that was the brief's §11 requirement and it is the reason the columns were argued down to six before any surface was audited. Suggested selection rule, same as slice 1's: pick by measurement rather than by list. The strongest available signals are surfaces whose write path has a policy but no capability trigger, and surfaces whose only pgTAP mention is an incidental fixture reference.

Unchanged and still true: **DELIV-1** remains the cheapest engineering item; **MAIL-1** remains the only owner decision; the **n8n tracks are not blocked by any of this** — offline conversion can proceed now, notification dispatch can be built against the stable contract now, and only the send node waits on MAIL-1.

End of report.
