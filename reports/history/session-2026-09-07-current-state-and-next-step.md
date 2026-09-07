# ORVION Current State & Next-Step Report

Class: History (immutable)
Date: 2026-09-07
Scope: full state refresh, open-finding inventory, decision-debt audit, four-surface synchronization

---

## 0. HANDOFF

- **INHERITED** — a commissioning instruction written on the premise that Slice 5 was unstarted and `BOOK-3`
  open. Both were false by the time it arrived; §1 records the correction, which is the report's first finding.
- **PROVEN** — 204 migrations on repository, local stack and Primary with identical ledger, function and all
  **ten** structural sub-surface hashes, Primary read from Primary (GUARD-1). Suite 105 files / 1646 assertions,
  Pass A = Pass B. Six HTTP suites 430/0. Smoke PASSED. Consistency CLEAN 1–25. Parity CLEAN.
- **UNPROVEN** — three items are stated as blind spots rather than claimed solved: REPLAY (no business-column
  uniqueness on `booking_items`; DC-2), CONCURRENCY (pgTAP is single-transaction; DC-3), and the fact that
  **pgTAP never runs against Primary** — the bridge is the hash comparison, which is PAR-3's residual.
- **CHANGED** — documentation only. No migration, schema, permission, RLS, trigger or function was modified
  after this report was commissioned; the implementation it describes was complete before it began.
- **DO NOT TOUCH** — the seven-permission UPDATE arm on `booking_items` (assertions 28–31 are the lockout a
  narrower arm would cause). The ten open decisions: none is an engineering question in disguise, and each was
  re-checked against canon this session.
- **REMAINING** — ten decisions (six business, two canon, two legal/provider) and four unscheduled engineering
  items: PAX-4's remaining tables, CUST-6, IDENT-2, and widening Check 25 to the register's second substrate.
- **NEXT** — Batch 6 slice 6, `otp_challenges` on exposure, **not** `branch_business_hours` on net score. §13
  carries the argument; disagree with it on evidence if you can.

---

## 1. Executive Summary

ORVION is at **204 migrations**, latest `202607061500`, with repository, local stack and Primary
`vrvtsxexkiiiivlkdxzp` carrying **identical ledger, function and structural hashes**. Every figure below was
re-read live this session; Primary's values were read **from Primary**.

**This report opens with a correction to its own commissioning premise, because §1 requires actual evidence over
prior reports.** The instruction that produced this report was written expecting Slice 5 to be *unstarted* and
`BOOK-3` to be *open*. Neither is true. **Slice 5 completed earlier in this same session.** `BOOK-3` is FIXED and
deployed, along with four further High/Medium defects that its adversarial sweep discovered — `BOOK-4`,
`BOOK-5`, `BOOK-6`, `BOOK-7` — plus two governance repairs, `GOV-16` and `GOV-19`. The §8 "BOOK-3 assessment"
below is therefore written as a *post-mortem of a closed finding* rather than a pre-implementation plan, and §11
recommends a different next step for that reason.

**The single most important technical finding to carry forward is BOOK-5**, because it invalidates a
comfortable assumption: a guard can charge the **correct permission, unconditionally, on every path** and still
be defeated, if it asks its authorization question of the row the attacking statement just wrote. No text
ceiling, coverage count or static sweep can see that.

**No fixable engineering defect is knowingly left open.** Two items remain open on this surface and neither is
engineering: `BOOK-8` (business) and `BOOK-9` (canon).

---

## 2. Verified Repository State

| Fact | Value |
|---|---|
| Branch | `main` |
| Remote | `PlatPlusHub/CRM` (zero `Shehabhub` dependency) |
| Migrations in `supabase/migrations/**` | **204** |
| Latest migration | `202607061500_the_booked_service_itself_had_no_door.sql` |
| pgTAP files / assertions | **105 / 1646** |
| HTTP suites / assertions | 6 / **430** |
| Consistency checks | **1–25** (Check 25 added this session) |

`HEAD` and working-tree cleanliness are recorded in §16 after the synchronization commit, because a report
cannot honestly assert the state of the commit that contains it.

## 3. Verified Database State

Both environments were read live on 2026-09-07.

| Surface | Local | Primary `vrvtsxexkiiiivlkdxzp` | Match |
|---|---|---|---|
| migrations | 204 (`202607061500`) | 204 (`202607061500`) | ✅ |
| ledger fingerprint | `e9549f90784fb38b0924b6353a56d94f` | `e9549f90784fb38b0924b6353a56d94f` | ✅ |
| function surface | `8c012ce5ee5749923d94c0d54e6b867f` (277) | `8c012ce5ee5749923d94c0d54e6b867f` (277) | ✅ |
| structural surface | `a48b275de685f89c073058de385d3ad8` (3,563) | `a48b275de685f89c073058de385d3ad8` (3,563) | ✅ |

All **ten** structural sub-surfaces matched individually, not merely in the combined hash: functions (277),
triggers (273), policies (124), constraints (498), grants (792), columns (1,097), views (16), indexes (293),
status_transitions (115), rls_enabled (78).

Both sides ran the **same file** (`scripts/parity_surface.sql`) — local via `psql`, Primary via the
`supabase-primary` MCP — which is PAR-1a's requirement, not a convenience.

`reports/evidence/primary-ledger-evidence.json` was rebuilt under **GUARD-1**: the array is the repository's own
filename list, written **only after** its md5 was proven equal to the fingerprint read from Primary
(`e9549f90784fb38b0924b6353a56d94f`, 204 entries, both sides). A repository value never stands in for a Primary
one.

Primary holds **zero business rows**.

## 4. GitHub / Primary Synchronization State

See §16 for the closing evidence. One process observation belongs here rather than being buried:

**`202607061500` was applied to Primary before it was committed and pushed.** It was committed and pushed in the
same session and the surfaces are proven identical, so nothing diverged — but *applying before committing* is
precisely the sequence that created the 2026-09-02 divergence recorded as **RECOVER-1**, where Primary carried
three migrations `origin/main` had never received. It is recorded here as a process note, not as a defect,
because the window was closed within the session.

## 5. Recent Completed Work

### Slice 4 — `booking_item_passengers` (`202607061400`), completed earlier

Closed `PAX-1` (a `finance_manager` with no `CREATE_BOOKING_ITEM` was refused by the RPC and allowed by the
table), `PAX-2` (a passenger could be swapped on an existing link with no capability and no record) and `PAX-3`
(a SECURITY DEFINER trigger running before the RLS `WITH CHECK` disclosed a foreign booking item's existence and
state). It also produced **MEAS-2** — all three SEC-1 ceilings *credited* the defective table, because
`guard_passenger_financials` short-circuits on null amounts — and, by root-causing that, **BOOK-3**.

### Slice 5 — `booking_items` (`202607061500`), completed this session

Full narrative: `session-2026-09-07-batch6-slice5-booking-items.md`. Summary of what actually happened:

- **Investigated** every writer of `booking_items` (4 RPCs), all 12 pre-existing triggers, the RLS policy, the
  column-level grants, and the role→permission matrix for all 8 relevant permissions.
- **Discovered that BOOK-3's own recorded obstacle was false.** The register said the repair was hard because
  "finance_manager holds `ENTER_COST` without `CREATE_BOOKING_ITEM`". Measured: it holds **neither**, and the
  two are held by exactly the same six roles. The real constraint is the mirror image — finance locks cost,
  approves, archives and assigns suppliers on items it does not own.
- **Reproduced five defects behaviourally** before writing any repair (details in §6).
- **Added** `202607061500` (3 functions, 1 trigger) and `105_booking_item_service_door_test.sql` (44
  assertions, ten attack classes, none N/A).
- **Executed** 204-migration clean replay, 105 files / 1646 assertions (Pass A = Pass B), six HTTP suites
  430/0, smoke `ALL CHECKS PASSED (77 tables …)`, consistency CLEAN 1–25, parity CLEAN.
- **Guard-of-guard caught the change twice and was updated with reasons, not silenced:**
  `10_grant_model_test` assertion 9 (bespoke-guard population ten → nine) and
  `58_write_grants_and_config_capability_test` assertions 25–26 (26 → 27 tables).
- **Added Check 25** to `scripts/check_repository_consistency.ps1`, closing `GOV-16`.
- **Documentation:** register (6 new rows, 3 updated, 2 detail blocks), disposition (5 → 6 of 77), execution
  plan (sixth self-enforcing rule), manifest, ai-map, reports index, ledger evidence.

---

## 6. Findings Discovered

All five were **reproduced behaviourally against the live local stack before any repair existed**. Static
reading produced the leads; none was accepted as a verdict (`MEAS-1`).

### BOOK-3 — High — FIXED

The booked service itself had no door. `app.create_booking_item` charges `CREATE_BOOKING_ITEM`; the table
charged nothing. A `finance_manager` and, separately, a `trainee` holding **none** of the eight booking-item
permissions each INSERTed a bare item that persisted. **The UPDATE half was wider than the register recorded:**
on a row the actor owned, `service_type_code` and `currency_code` were rewritten, `owner_user_id` was seized,
and the item was moved onto a different booking of the same tenant — none of which any RPC offers.

### BOOK-4 — Low — FIXED

`app.enforce_booking_item_lifecycle` is SECURITY DEFINER, looked its parent up by id alone, and BEFORE ROW
triggers run before the RLS `WITH CHECK`. A foreign **cancelled** booking answered `23514 cannot attach a
booking item to a cancelled booking`; a foreign **active** one and a **nonexistent** one both answered `23503`.
One of three was distinguishable — a cross-tenant existence-and-state oracle, `PAX-3` one table up. Repaired by
scoping the lookup to `app.current_tenant_id()`; the `new.tenant_id` draft was rejected because the attacker
supplies it.

### BOOK-5 — High — FIXED — *the one that generalises*

`app.guard_booking_item_financials` computed canon-28 assignment scope from `new` on both paths. On UPDATE that
is the row the attacking statement just wrote. Reproduced as a **discriminating pair one clause apart**, by an
`employee` who genuinely holds `ENTER_COST` and was not assigned the item:

```
update booking_items set cost_amount = 555 where id = e1;                      -> REFUSED (scope)
update booking_items set owner_user_id = <self>, ..., cost_amount = 555 ...;   -> SUCCEEDED
```

Ground truth read as `postgres`, not through the attacker's own RLS: `cost_amount` 100 → 555, ownership seized.
The repair is four lines — on UPDATE the scope is taken from `old`.

### BOOK-6 — Medium — FIXED

`finance_approval_required` — the flag `advance_booking_item` reads to **block** execution — had no writer of
any kind on the table door. **A first probe of this was a no-op and is recorded rather than discarded:** the
column is `NOT NULL DEFAULT false`, so clearing it on a fresh fixture changed nothing and raised nothing; it
*looked* like a successful attack and was neither. Re-run against a genuinely raised flag, the clearance took.

### BOOK-7 — Medium — FIXED

`currency_code` was unguarded, so EGP 100 became USD 100 without touching a guarded column. **The first draft of
the repair was a tautology and re-running the probe caught it** — written as `old.cost_amount is not null`,
always true because both money columns are `NOT NULL DEFAULT 0`.

### Two vacuous assertions I wrote and then removed

While explicitly hunting vacuous assertions, two of my own first drafts were `count(distinct …)` over literal
values — restating what the `throws_ok` calls above them already proved. Replaced with real coverage (the
`BOOK-9` residual, and the oracle's UPDATE entrance). Recorded because the failure mode is the point.

---

## 7. All Open Findings

Derived from `MASTER_GAP_REGISTER.md` this session, not from memory. Every row that is open **and** awaiting a
decider is now also on `manifest.md`'s boot line, enforced by Check 25.

| ID | Finding | Current State | Severity | Fixable Now? |
|---|---|---|---|---|
| BOOK-3 | booked service creatable/mutable with no capability | **✅ FIXED** `202607061500` | High | ALREADY FIXED |
| BOOK-4 | cross-tenant existence/state oracle | **✅ FIXED** `202607061500` | Low | ALREADY FIXED |
| BOOK-5 | scope check read the attacker's post-image | **✅ FIXED** `202607061500` | High | ALREADY FIXED |
| BOOK-6 | finance execution gate clearable | **✅ FIXED** `202607061500` | Medium | ALREADY FIXED |
| BOOK-7 | priced item redenominable without money permission | **✅ FIXED** `202607061500` | Medium | ALREADY FIXED |
| PAX-1/2/3 | manifest door, swap, oracle | **✅ FIXED** `202607061400` | High/High/Low | ALREADY FIXED |
| MEAS-2 | ceilings credit a conditional guard | **✅ BOUNDED**, population 10 → 9 | Medium | ALREADY FIXED (bounded; nothing textual can fix it) |
| GOV-16 | register decisions never reached the boot line | **✅ FIXED** — Check 25 | Medium | ALREADY FIXED |
| GOV-19 | CAT-6 under two rows with opposite verdicts | **✅ FIXED** — row split | Medium | ALREADY FIXED |
| CAT-6 | five catalog-less columns | **✅ RESOLVED by evidence**, verified live per column | Low | CLOSED BY EVIDENCE (residual is canon, 2 columns) |
| CDM-3 | assurance residue on an AUDITED row | **✅ FIXED** `202607061300` | Medium | ALREADY FIXED |
| **BOOK-8** | may a finance-approval requirement be withdrawn? | **OPEN** | Medium | **TRUE BUSINESS DECISION** |
| **BOOK-9** | booking items have no reassignment permission | **OPEN** | Low | **TRUE BUSINESS DECISION** (canon) |
| **PAX-4** | 20 `authenticated`-INSERTable tables with no capability trigger | **OPEN**, counted not swept | Medium | **NEEDS MORE EVIDENCE — per table** (see below) |
| **PAX-5** | when does a manifest become immutable? | **OPEN** | Medium | **TRUE BUSINESS DECISION** |
| **PAX-6** | no event vocabulary for a manifest change | **OPEN** | Medium | **TRUE BUSINESS DECISION** (canon) |
| **FA-2** | may an account receive a foreign-currency payment? | **OPEN** | Medium | **TRUE BUSINESS DECISION** |
| **MONEY-2** | may an account open overdrawn / a quotation go below cost? | **OPEN** | Medium | **TRUE BUSINESS DECISION** |
| **MAIL-1** | transactional email provider | **OPEN** | Medium | **EXTERNAL PROVIDER + LEGAL/COMPLIANCE** |
| **RET-1** | retention periods | **OPEN** (mechanism shipped, seeds zero rows) | Medium | **TRUE LEGAL/COMPLIANCE DEPENDENCY** |
| **AUDIT-2** | limit-metric storage, unlimited encoding, Enterprise scope | **OPEN** | Medium | **TRUE BUSINESS DECISION** |
| **PD-23** | the three "Limited" plan ceilings canon leaves undefined | **OPEN** | Medium | **TRUE BUSINESS DECISION** |
| FIN-9 / FIN-11 | post-fix residual state on the PostgREST table door | **OPEN** | Low | **NEEDS MORE EVIDENCE** |
| DEAD-3 / DEAD-4 | reader-with-no-writer / writer-with-no-reader | **OPEN**, measured both directions | Low | NEEDS MORE EVIDENCE |
| IDENT-2 | `user_created` emitted with `has_auth_link` semantics incomplete | **OPEN** | Low | FIXABLE NOW (small) |
| CAMP-2 / PLACE-2 | UNPROVEN, recorded rather than acted on | **OPEN** | Low | NEEDS MORE EVIDENCE |
| CAP-1 | not reproducible today | **OPEN** | Low | NEEDS MORE EVIDENCE |
| ORIG-1 / JE-2 | recorded, deliberately not fixed | **OPEN** | Low | NEEDS MORE EVIDENCE / would foreclose a Batch-4 decision |
| CUST-6 | `guard_write_capability` is not a second enforcer of `MANAGE_CUSTOMER_CREDIT` | **OPEN**, deliberate asymmetry | Low | FIXABLE NOW (small) |
| SYNC-1 | the 2026-09-02 divergence class | **OPEN** (the divergence itself resolved) | Medium | NEEDS MORE EVIDENCE |
| VER-2 / IDENT-3 / ADMIN-2 / ADMIN-3 / AUD-03 | intentional / proven-not-a-defect | pinned | — | CLOSED BY EVIDENCE |

### The two marked FIXABLE NOW, and why they were not done in this task

`§2` of the commissioning instruction forbids modifying implementation before this report exists, and both are
implementation changes:

- **CUST-6** — make `guard_write_capability` a second enforcer of `MANAGE_CUSTOMER_CREDIT` on `customers`, as
  the supplier branch already is. Recorded as a *deliberate asymmetry* with a stated reason (the append-vs-
  replace difference is load-bearing), so this is a design change, not a bug fix, and needs its own slice.
- **IDENT-2** — small, and belongs to the identity surface's own slice.

### PAX-4 — why "NEEDS MORE EVIDENCE" and not "FIXABLE NOW"

Twenty `authenticated`-INSERTable tables carry no capability trigger. **Some are certainly correct:**
`otp_challenges` is a pre-authentication surface where a capability check is a category error;
`user_permission_grants` and `user_role_assignments` carry their authority in an RLS policy (RBAC-3's ratified
shape); canon 34 makes row-ownership by `auth.uid()` the model for the three identity tables. The rest need a
per-table answer canon must supply. **Inventing twenty table-to-permission mappings in one migration is exactly
what this programme forbids**, and slices 4 and 5 both demonstrate why: each table's correct arm was only
derivable after reading its own RPC surface. The ceiling is pinned at `<= 20` by `10_grant_model_test`
assertion 7 — it may fall and must never rise.

---

## 8. Decision Debt Audit

Ten decisions are open. **Until this session, `manifest.md` named exactly one of them** — the rest were
registered, open, and invisible to a fresh session, which reads the manifest and not a 1,700-line register.
That gap was `GOV-16`, and **Check 25** now fails the build on it.

| ID | Exact question | Why engineering cannot decide it | Depends on it | Safe to continue? |
|---|---|---|---|---|
| MAIL-1 | Which transactional email provider, and which PDPC cross-border transfer licence names its destination? | A licensing question before a vendor one; both are the owner's, one is counsel's | the n8n dispatch workflow | Yes — ORVION sends no mail; every alert already writes a `pending` delivery row |
| RET-1 | What finite retention period per document type? | Statutory; counsel's, not the owner's unaided | nothing — mechanism seeds **zero** policy rows | Yes — nothing is destroyable while it waits |
| AUDIT-2 | Limit-metric storage, unlimited encoding, Enterprise scope | Commercial packaging | plan-ceiling enforcement | Yes |
| PD-23 | The three "Limited" plan ceilings canon leaves undefined | Commercial | `usage_counters` (currently referenced by no function at all) | Yes |
| FA-2 | May a financial account receive a payment in another currency, and at what rate? | Accounting policy | multi-currency deposits | Yes — current behaviour permits it, unchanged |
| MONEY-2 | May a bank account open overdrawn? May a quotation total fall below cost? | Commercial | two CHECK constraints not written | Yes |
| PAX-5 | After which state does `passenger_id` become immutable, and which permission may override? | Commercial and operational — airlines charge for name changes, some fares forbid them, and a typo correction before departure is legitimate | a freeze rule not written | Yes — the swap is now *priced*; only the freeze is undecided |
| PAX-6 | Does ORVION record manifest changes as business events, and under which type names? | Canon 27 registers no vocabulary; minting one is fabricating canon | manifest auditability | Yes — pinned as an absence by assertion 41 of `104_…` |
| BOOK-8 | May a raised finance-approval requirement be withdrawn, and under which permission? | Canon 26/28 do not say a requirement is irrevocable; the current refusal is the *conservative reading*, not the canonical one | an RPC nobody has asked for | Yes — errs toward more approval, never less |
| BOOK-9 | Does canon 28 owe booked services a reassignment permission, as it gives leads `REASSIGN_LEAD`? | Canon defines none and minting `REASSIGN_BOOKING_ITEM` fabricates canon | ownership-transfer authority | Yes — the floor still refuses outsiders; this is about which colleague |

**Closed by evidence this session:** `CAT-6`. Its engineering half had been settled by SPEC-141 on 2026-08-24
and the register never caught up for fourteen days; re-assessed live from `pg_constraint`, per column. Three of
five columns carry CHECKs; two are deliberately free text because canon defines no vocabulary. It was an owner
decision about five columns on paper and is a canon question about two in fact.

**No engineering question is disguised as an owner decision in the current register.** Check 25 makes the
inverse failure — an owner decision disguised as nothing — impossible to sustain silently.

---

## 9. BOOK-3 Assessment

**Status: CLOSED.** This section is a post-mortem, because the finding was repaired earlier in this session. It
is written in full because the commissioning instruction asked for the analysis, and the analysis is what makes
the repair reviewable.

- **Exact vulnerability.** `public.booking_items` — the booked service itself — accepted INSERT and UPDATE from
  any `authenticated` caller who satisfied RLS, with no capability charge whatsoever.
- **Affected path.** The direct PostgREST/table door. `authenticated` holds table-level INSERT and UPDATE (and
  column-level SELECT on 34 of the columns; `cost_amount` is withheld by SEC-1c). No DELETE grant exists.
- **Why the RPC authorization was insufficient.** `app.create_booking_item` charges `CREATE_BOOKING_ITEM`
  correctly. It is one of two doors. ORVION exposes PostgREST directly, so an RPC-only check is a check on the
  path the honest client happens to use.
- **Why the table door matters.** The RLS policy admits any row whose parent booking is visible to the caller —
  which for a `finance_manager` (holding `VIEW_FINANCIAL_DOCUMENTS`) is every booking in the tenant. Visibility
  was therefore doing the work authorization was supposed to do.
- **Why INSERT and UPDATE could not use identical authorization.** They do share a base arm
  (`CREATE_BOOKING_ITEM`), but UPDATE needed six more, because four roles legitimately mutate items they did not
  create: `APPROVE_FINANCE` and `EDIT_LOCKED_COST` (finance locking and approving), `ARCHIVE_RECORD` (archiving),
  `ASSIGN_SUPPLIER` (supplier assignment), plus `UPDATE_BOOKING_ITEM_STATUS` and the two pricing permissions.
  An INSERT-shaped arm on UPDATE would have locked finance out of its own work.
- **`finance_manager` / `ENTER_COST` / `CREATE_BOOKING_ITEM` implications — the recorded premise was false.**
  `finance_manager` holds **neither** `ENTER_COST` nor `CREATE_BOOKING_ITEM`. `ENTER_COST`,
  `ENTER_SELLING_PRICE`, `UPDATE_BOOKING_ITEM_STATUS` and `CREATE_BOOKING_ITEM` are held by **exactly the same
  six roles**. Assertion 4 of `105_…` is a `set_eq` pinning this, so the claim cannot decay again.
- **CUST-3 relationship.** CUST-3's `v_extra` *append* pattern was the right shape and was reused; CUST-3's
  stated *reason* (a permission finance holds without the base one) does not apply here. The pattern
  transferred; the rationale did not.
- **Repair as shipped.** One CASE arm (base), one `v_extra` arm (seven permissions), one
  `before insert or update` trigger. No second authorization engine, no per-column authority model, no invented
  permission — every entry read out of an enforcer that already exists (SEC-1b's rule).
- **Adversarial tests delivered.** 44 assertions, ten classes, none N/A. Assertions 28–31 are the lockout the
  naive repair would have caused, in test form.
- **Mutation tests delivered.** Dropping the trigger fails assertion 10; restoring the `new`-image scope fails
  assertion 14; removing the tenant predicate (external mutation) fails assertions 17 and 20. Each in-file
  mutation is rolled back and re-asserted (TEST-3).
- **Regressions checked.** All six HTTP journey suites re-run: **430 passed / 0 failed**. This was mandatory
  rather than prudent — `booking_items` is the most heavily written table in the domain, and a wrong UPDATE arm
  would have locked finance out rather than failed a unit test.
- **Business decision required?** For BOOK-3 itself, **no** — the mapping was read out of the RPC surface. Two
  adjacent questions surfaced and were *not* answered: `BOOK-8` and `BOOK-9`.

---

## 10. PAX-5 Documentation Reconciliation

**A contradiction existed, it was real, and it has been fixed structurally rather than cosmetically.**

- `MASTER_GAP_REGISTER.md` recorded PAX-5 as `OPEN — OWNER/BUSINESS DECISION` with an `Owner Decision` cell
  reading `business: at what point does a travel manifest become immutable, and who may override`.
- `manifest.md` read `Open owner decisions — **MAIL-1**, and nothing else.`
- `MASTER_SURFACE_DISPOSITION.md` listed PAX-5 among `booking_item_passengers`' open items.
- `MASTER_EXECUTION_PLAN.md` named PAX-5 as an owner item.

Three documents said PAX-5 was an open owner decision; the one document a fresh session actually reads at boot
said there were none but MAIL-1. **And PAX-5 had five siblings in the same position** — `AUDIT-2`, `PD-23`,
`FA-2`, `MONEY-2`, `PAX-6`.

**Reconciliation, without inventing policy:**

1. **Was it already answered?** Checked. Canon 31 defines `booking_item_passengers` as *"Links passengers to
   booking items"* with no immutability rule. Canon 26 defines the item state machine (`issued`, `reissue`,
   `void`, `refunded`) without mentioning the manifest. Canon 28 assigns the lifecycle authorities
   (`ISSUE_BOOKING`, `REISSUE_BOOKING`, …) and says nothing about `passenger_id`. **Canon does not answer it**,
   so the original classification stands — confirmed by evidence, not accepted by inheritance.
2. **`GOV-19` fixed first**, because it blocked the guard: `CAT-6` sat under two rows with opposite verdicts and
   its own row recorded that it must not reach the boot line while that was true.
3. **`GOV-16` fixed** — **Check 25** binds the register to the boot line in the direction that was missing.
4. **`manifest.md`'s decision line now carries all ten**, within the existing character budget (trimmed, never
   raised — `AGENTS.md §6`).

**The business decision itself was not altered.** PAX-5 remains open, with the same question.

---

## 11. Test / Security / Guard Assessment

| Layer | Result |
|---|---|
| Migration replay (204, from scratch) | clean |
| pgTAP Pass A | 105 files / **1646** assertions, PASS |
| pgTAP Pass B (no reset) | 105 files / **1646** assertions, PASS — identical |
| Adversarial (`105_…`) | 44 assertions, ten classes, none N/A |
| Mutation | 3 injections, each fails the intended assertion; all restored |
| Guard-of-guard | `10_grant_model_test` and `58_…` both caught this change and were updated with reasons |
| Repository Consistency | CLEAN, Checks **1–25** |
| Database Parity | CLEAN — local proven; Primary ledger, functions and structure proven |
| HTTP suites | 29 + 40 + 74 + 107 + 120 + 60 = **430 passed / 0 failed** |
| Smoke | `ALL CHECKS PASSED (77 tables …)` |

### "Does this PASS prove the invariant, or only the tested path?"

Applied honestly, this question is the reason slice 5 exists at all:

- **The SEC-1 ceilings did not prove the invariant.** They asked whether *some* trigger names `app.authorize`.
  `booking_items` passed while a trainee could create booked services. `MEAS-2` bounds this by naming the nine
  tables whose only capability trigger is bespoke, so the manual-review population is finite and explicit.
- **BOOK-5 proves a stronger blind spot exists.** Slice 5's own new trigger charges unconditionally — and
  `guard_booking_item_financials` *also* charged unconditionally, with the right permission, and was still
  defeated. **The standing question to ask of every authorization predicate is: does it read `new` to decide
  AUTHORITY, or only to validate CONTENT?** Reading `new` for content is correct; reading `new` for authority
  hands the decision to the caller. Recorded as the sixth self-enforcing rule.
- **The selector is not a safety measure.** It subtracts test coverage, and slices 4 and 5 both found High
  defects on well-covered tables. Every remaining candidate now scores **negative**, which means the ranking has
  stopped discriminating — not that the surfaces are safe. Its own output says so.

### Known blind spots, stated rather than dressed up

- **REPLAY** — `booking_items` carries no uniqueness on any business column, so a replayed create makes a second
  distinct service. That is `DC-2` (write-idempotency keys, DESIGN-READY), pinned by assertion 39, not claimed
  as solved.
- **CONCURRENCY** — pgTAP runs in one transaction, so true concurrency is not exercised. Assertion 40 pins the
  concurrency-relevant *property* (the scope decision comes from the row version the statement locked); the
  lost-update question itself is `DC-3`.
- **pgTAP never runs against Primary.** The bridge is the structural + function + ledger hash comparison. That
  is PAR-3's residual and it is why `parity_surface.sql` hashes ten surfaces rather than two.
- **Environment sensitivities already closed and worth not re-breaking:** Check 12 measured the *runner's*
  timezone until `AUD-01a` (same commit was CLEAN in Cairo and 22 failures in UTC CI); the guard-test suite
  needed a git identity CI does not have (`b552987`).

### Suspicious-test audit

- **Two vacuous assertions were written and removed during this session** (§6). No `count(distinct …)`-over-
  literals assertion remains in `105_…`.
- **Assertion 11–12 of `104_…`** are deliberately *not* `throws_ok`, and the header says why: the trainee is
  refused by RLS **visibility**, so a `throws_ok` there would record a capability check that never ran.
- **Assertions 11–12 of `105_…`** avoid that trap by giving the trainee a row it **owns**, so the refusal is
  authority and not visibility.
- **Assertion 26 of `105_…`** is an explicit anti-tautology control, and it caught a real draft.

---

## 12. Repository / Governance / Documentation Health

**Fixed this session:**

- `GOV-19` — one finding under two rows with opposite verdicts, stale for fourteen days.
- `GOV-16` — the register→manifest binding, now Check 25.
- `BOOK-3`'s register row carried a **false factual premise** that had been inherited rather than measured; it
  is corrected, and assertion 4 pins the fact so it cannot decay again.
- `MEAS-2`'s bound moved ten → nine **by construction**, not by editing a list.
- Manifest kept inside its character budget by **trimming**, never by raising it.

**Current state, verified:**

- No orphaned or duplicated mechanism introduced: `guard_write_capability` gained one table, and no parallel
  authorization path was created.
- No stale references: `ai-map.json` regenerated, `reports/README.md` pointer updated, ledger evidence rebuilt.
- Handoff information present: both new reports carry the mandated blocks; Check 23 enforces it.
- Historical reports remain immutable; only current-state documents were edited.

**Remaining consistency debt, honestly stated:**

- **Check 25's ceiling** — it reads a prose column, so it cannot find a decision nobody wrote down. It is a
  floor on honesty, not a proof of completeness.
- **`MASTER_GAP_REGISTER.md` has two substrates** (table rows and `###` detail blocks) and 64 ids are defined
  only by a block. Check 25 currently scans table rows only. Detail-block-only decisions (`MAIL-1` is a row;
  `RET-1` is not) would be invisible to it. **This is a real, technically fixable gap** and is the strongest
  candidate for a small follow-up.

---

## 13. Recommended Next Step

**Recommendation: Batch 6 slice 6 — `otp_challenges`, NOT the selector's top rank.**

1. **What.** An adversarial sweep of `otp_challenges`, the pre-authentication surface.
2. **Why highest-value.** The selector's top rank is `branch_business_hours` at score **-4**, and every
   remaining candidate now scores negative — the ranking has stopped discriminating. Judged on **exposure**
   rather than net score, `otp_challenges` is the highest at **11**, and it is the only remaining candidate
   carrying **both PII and an unguarded write path**. It is also the one table `PAX-4` explicitly flags as
   needing bespoke reasoning ("a capability check there would be a category error"), which means it will never
   be resolved by a routine sweep and will sit open indefinitely otherwise. Slices 4 and 5 both proved that
   coverage-adjusted ranking mis-sorts exactly this way.
3. **Findings addressed.** One of `PAX-4`'s twenty, on the table where the wrong answer is most costly; and it
   removes a name from the ceiling's manual-review list.
4. **Dependencies.** None. No owner input required.
5. **Risks.** Authentication paths are reachable pre-session, so `auth.uid()` is null and the platform-path
   early return in every guard applies. A capability trigger here would be **wrong**; the sweep must be prepared
   to conclude "correctly unguarded" and record that, which Check 24 permits only with declared classes and
   negative assertions.
6. **Do not touch yet.** The seven-permission UPDATE arm on `booking_items`. `PAX-4`'s other nineteen tables in
   bulk. Any of the ten open decisions.
7. **Preconditions.** Local stack at 204 and green; `HEAD == origin/main`; CI green on the head commit.
8. **Tests required.** A new `106_…` file declaring its attack classes, with N/A classes justified in prose;
   mutation tests in both directions; the six HTTP suites only if a write path changes.
9. **Synchronization after.** The full four-surface protocol, and **commit before deploying**, not after.
10. **Decisions needed first.** None.

**Two smaller items worth considering ahead of a full slice**, both fixable now and both cheap:

- **Widen Check 25 to the register's second substrate** (`###` detail blocks). Closes the gap named in §12 and
  is the natural completion of the work already done this session.
- **CUST-6** — a design change with a stated reason, so it deserves an explicit decision to proceed rather than
  a drive-by fix.

---

## 14. Preconditions for Next Step

- `HEAD == origin/main`, working tree clean (§16).
- Local stack at 204 migrations, replayed clean.
- Repository Consistency CLEAN 1–25; Database Parity CLEAN.
- CI green on the head commit.
- No open decision blocks any of it.

## 15. Remaining Dependencies

| Kind | Items |
|---|---|
| Business / owner | BOOK-8, PAX-5, FA-2, MONEY-2, AUDIT-2, PD-23 |
| Canon | BOOK-9, PAX-6, CAT-6's two columns |
| Legal / compliance | RET-1 (periods), MAIL-1 (PDPC cross-border transfer licence) |
| External provider | MAIL-1 (transactional email vendor) |
| Engineering, unscheduled | PAX-4's remaining tables, CUST-6, IDENT-2, Check 25's second substrate |

**None blocks Batch 6, and in every case the shipped behaviour is the conservative reading.**

## 16. Final Synchronization Evidence

Recorded in the commit that follows this report; the closing values are stated in the session's final response.
The rule this session held to: **a report may not assert the state of the commit that contains it**, so the
push, the CI result and the resulting `HEAD` are verified after the commit and before completion is claimed.

Proven before the commit:

- Local ↔ Primary: 204/204, ledger `e9549f90784fb38b0924b6353a56d94f`, functions
  `8c012ce5ee5749923d94c0d54e6b867f` (277), structure `a48b275de685f89c073058de385d3ad8` (3,563) — **all ten
  sub-surfaces matched individually**, Primary read from Primary.
- Repository Consistency: CLEAN, Checks 1–25.
- Suite: 105 files / 1646 assertions, Pass A = Pass B. HTTP: 430/0. Smoke: PASSED.
- Identity: `PlatPlusHub/CRM`, zero `Shehabhub` dependency.

---

## 17. Exact Current Truth for the Next LLM

**Where ORVION is.** Phase 8 in progress. 204 migrations. Repository, local stack and Primary are byte-identical
across ledger, functions and all ten structural surfaces. Batch 6 is **6 of 77 surfaces recorded — NOT
complete**.

**What is complete.** Slices 1–5. `booking_items` and `booking_item_passengers` are both `AUDITED-OPEN` with
every engineering finding closed and only non-engineering questions left. The assurance layer now includes
Check 25, which binds registered decisions to the manifest's boot line.

**What is not complete.** 71 surfaces at `NOT-RECORDED`. `PAX-4`'s twenty tables. The n8n dispatch workflow
(blocked on MAIL-1, which is a licensing question before it is a vendor one).

**What is broken.** Nothing known and fixable. Every reproduced defect in this session was repaired, deployed
and pinned by a failing-under-mutation test.

**What is merely undecided.** Ten decisions, all now visible on `manifest.md`'s boot line: BOOK-8, BOOK-9,
PAX-5, PAX-6, FA-2, MONEY-2, AUDIT-2, PD-23, MAIL-1, RET-1. None blocks engineering.

**What should happen next.** Slice 6. Recommended target `otp_challenges` on exposure, **not**
`branch_business_hours` on net score — see §13 for the argument, and disagree with it on evidence if you can.

**What must not be repeated.**

1. **Do not trust a register row's stated *reason* without measuring it.** `BOOK-3`'s deferral rested on a
   permission claim that was simply false, and it cost a slice.
2. **Do not conclude a probe succeeded because it raised no error.** `BOOK-6`'s first probe was a no-op against
   a `NOT NULL DEFAULT false` column and looked exactly like a successful attack.
3. **Do not write `is not null` against a `NOT NULL` column** and call it a condition. It is a tautology.
4. **Do not assert an oracle is closed using an actor the new guard refuses first.** You will prove nothing and
   it will look like proof. Attack with an actor who *holds* the capability.
5. **Do not deploy before committing.** RECOVER-1's exact sequence.
6. **Do not treat a green ceiling, a coverage count or a selector score as evidence of safety.** Three separate
   findings this session and last sat inside green measurements.

**What evidence already exists.** `session-2026-09-07-batch6-slice4-booking-item-passengers.md` and
`session-2026-09-07-batch6-slice5-booking-items.md` carry the per-slice narratives and HANDOFF blocks.
`MASTER_GAP_REGISTER.md` is the findings SSOT. `MASTER_SURFACE_DISPOSITION.md` answers "how much is audited".
`MASTER_EXECUTION_PLAN.md` holds EC-1…EC-11 and the six self-enforcing rules. `reports/evidence/primary-ledger-
evidence.json` holds Primary's ledger under GUARD-1. Do not re-derive any of it from scratch; verify it and
proceed.
