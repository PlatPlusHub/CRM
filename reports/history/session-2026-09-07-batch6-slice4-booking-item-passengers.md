# ORVION — Batch 6 slice 4: the manifest that asked nobody's permission, and the ceiling that had been vouching for it

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-07
Author: Claude Opus 5
Status: **COMPLETE — one migration (`202607061400`), deployed to Primary and parity-verified on all three surfaces. Repository = GitHub = local = Primary at 203 migrations. Batch 6 remains explicitly NOT COMPLETE at 5 of 77, and this slice OPENED a High finding it did not close (BOOK-3).**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED, verified before touching anything.** HEAD `b552987` = `origin/main` (0 ahead / 0 behind), 203 migrations **on disk but 202 tracked**, local ledger 203, 103 test files. **The tree was not clean**: `202607061400` was present, applied and **uncommitted**, with no test, no register row, no disposition row and no report. Slice 4 had been investigated and repaired, and completed on no other axis. §1 has the table.
- **PROVEN (behavioural evidence, this session):** 203 migrations apply clean from scratch; pgTAP **104 files / 1602 assertions, Pass A = Pass B** (was 103/1560); **all six HTTP suites re-run, 430 passed / 0 failed**; smoke `ALL CHECKS PASSED (77 tables)`; consistency **CLEAN 1–24**; parity **CLEAN on all three surfaces with Primary values READ FROM Primary** (GUARD-1) — ledger `36d87db9a2a106de2808d608c59ec6c2` (203), functions `8754ef0acd7e6dcb8a8574020c119239` (277), structure `06a3c59e6a0c4585c97a29a1f2cc739a` (3,562). Each inherited finding was **re-measured against the current implementation before being believed**, and each repair was **mutation-proven in both directions**, in-file *and* against the live schema. **BOOK-3 was reproduced, not inferred.**
- **UNPROVEN, and not claimed:** **nothing in this slice was exercised over HTTP against `booking_item_passengers` specifically** — the table's repairs are LOCAL RUNTIME + PRIMARY structural evidence; what the six HTTP suites prove is that the *legitimate journeys still pass* (`verify_journey_branches`, 74/0, is the one that writes this table). The MEAS-2 assertion is a **`set_eq` over catalog text**: it bounds which tables need a human to read their short-circuits, and **cannot itself tell a conditional guard from an unconditional one** — its own message says so. Of the ten tables it names, **only `booking_items` and `lead_interactions` have actually been read**; the other eight are bounded, not cleared. **72 surfaces have no recorded disposition.**
- **CHANGED:** `202607061400` (committed — it existed untracked); `104_booking_item_passenger_manifest_surface_test.sql` (new, 41 assertions, all ten attack classes); `10_grant_model_test.sql` (+assertion 9, MEAS-2); `58_write_grants_and_config_capability_test.sql` (25 → 26 and the allowlist); `MASTER_GAP_REGISTER.md` (PAX-1…PAX-6, BOOK-3, MEAS-2); `MASTER_SURFACE_DISPOSITION.md` (4 → 5 of 77, plus a `Next` note on `booking_items`); `MASTER_EXECUTION_PLAN.md` (header, EC-1, a **fifth** self-enforcing rule); `manifest.md`; `primary-ledger-evidence.json`; `ai-map.json`; `repository-index.md`; `reports/README.md`. **`MASTER_API_CONTRACT.md` regenerated and unchanged** — no grant, RPC or view moved; one trigger was added.
- **REMAINING:** **BOOK-3** (High, open, reproduced — next slice). **MEAS-2's other eight** unread tables. **PAX-4** (20 tables counted, not swept). **PAX-5** (owner). **PAX-6** (canon). **MAIL-1**, **FA-2**, **MONEY-2** untouched. **72 surfaces** at `NOT-RECORDED`.
- **DO NOT TOUCH:** do not add a rule freezing `passenger_id` after issuance — that is **PAX-5**, a business question canon does not answer, and inventing a freeze point is exactly what this programme forbids. Do not "fix" PAX-3 by comparing `bi.tenant_id = new.tenant_id`: **the attacker supplies `new.tenant_id`**, that draft was tried and rejected, and the reason is recorded in the migration and the register. Do not remove the unrestricted platform branch (`v_tenant is null`) from the lifecycle lookup — BOOK-1 grants that trigger no session-less exemption, and assertion 24 pins it. Do not add a DELETE arm to the new trigger: `authenticated` holds no DELETE grant, and assertion 30 pins the verb set. Do not mint a `booking_item_passenger_linked` event type to "close" PAX-6 — that is canon-27 vocabulary, and assertion 41 will fail until a producer and its test arrive together. Do not repair **BOOK-3** with a naive INSERT-or-UPDATE arm: `finance_manager` holds `ENTER_COST` without `CREATE_BOOKING_ITEM`, so it needs the CUST-3 `v_extra` treatment.
- **NEXT:** §9.

---

## 1. PREFLIGHT — AND THE DISCREPANCY IT FOUND

The boot sequence was executed against the repository rather than against the previous report: `git status`, `git rev-parse` on both refs, a read of `README.md`, `AGENTS.md`, `manifest.md`, `reports/README.md`, the disposition record and the plan's Batch 6 section.

**The starting state did not match the last report's, and the difference is the whole reason this session exists.**

| Fact | Last report (slice 3) | Measured at preflight |
|---|---|---|
| `HEAD` | `b552987` | `b552987` — equal to `origin/main`, 0 ahead / 0 behind |
| Working tree | clean | **one untracked file** |
| Migration files | 202 | **203 on disk, 202 tracked** |
| Local Supabase ledger | 202 | **203** |
| pgTAP files | 103 | 103 |

The untracked file was `supabase/migrations/202607061400_the_manifest_asked_nobody_permission.sql` — a complete, applied, **uncommitted** slice-4 repair carrying a forensic header for PAX-1, PAX-2 and PAX-3. Around it there was nothing: **no pgTAP file, no register row, no disposition row, no plan entry, no manifest update, no report.**

So slice 4 had been *investigated and repaired* and not *completed* on any other axis. This is precisely the state `AGENTS.md §6` calls out — a migration on disk and in one database is not a slice, and had this working copy been lost the investigation would have gone with it. The forensic work was **not** redone; it was **verified**, which is a different and cheaper thing, and §3 records what that verification changed.

---

## 2. SKILLS DISCOVERY — SEARCHED, EVALUATED, NONE INSTALLED

A bounded capability review was run before implementation, as directed.

**Searched.** The installed plugin marketplaces were enumerated (`~/.claude/plugins/known_marketplaces.json` → `claude-plugins-official` (291 plugins), `gitkraken`, `thedotmack`, `ponytail`) and the official catalogue was searched programmatically for: `postgres`, `supabase`, `rls`, `row-level`, `sql injection`, `owasp`, `pentest`, `penetration`, `adversarial`, `multi-tenant`, `rbac`, `abac`, `authorization`, `migration`, `database test`, `pgtap`, `concurrency`, `forensic`, `audit`.

**Evaluated, and rejected — each for a stated reason, not for taste.**

| Candidate | Verdict | Reason |
|---|---|---|
| `supabase` (supabase-community) | **Reject** | It is an *MCP integration*, and ORVION already has `supabase-primary` plus the CLI and `postgres-local`. Installing it adds a **second Supabase MCP**, and `AGENTS.md §4` step 8c warns in terms: *"never let a schema-changing call reach the wrong one."* It would add risk and no capability. |
| `42crunch-api-security-testing` | **Reject** | Audits **OpenAPI specs** for BOLA/BFLA. The class is right and the evidence layer is wrong: ORVION authors no OpenAPI document (PostgREST generates one), and PAX-1/2/3 live in triggers, RLS and grants — things no spec audit can see. Also a SaaS dependency. |
| `claude-security` | **Reject** | Local source vulnerability scanning. ORVION's defects are *semantic authorization gaps* provable only against a live database; `AGENTS.md §6` already fixes the ceiling on this class — **static analysis is a lead, never a verdict** (MEAS-1). It would produce leads this slice then had to re-prove behaviourally. |
| `neon`, `prisma`, `aiven`, `alloydb`, `cloud-sql-postgresql` | **Reject** | Wrong vendor or wrong access layer (ORM/managed-host tooling). No bearing on RLS, SECURITY DEFINER or trigger authorization. |

**Installed: none.** No available Skill offered material value over what this repository already encodes, and each candidate carried either an external dependency or a duplicated mechanism that `AGENTS.md §2` (anti-entropy, Earn-It) forbids adding.

**What was used instead, and it is the better instrument.** §3.4 asks for authoritative validation of material security practice. That was done directly against the **primary source** via the `supabase-primary` MCP's `search_docs`, which is stronger than a skill wrapper around the same documentation. Two passages bear on the repair and both confirm it:

> *"It is best practice to use `security invoker` (which is also the default). If you ever use `security definer`, you **must** set the `search_path`. If you use an empty search path (`search_path = ''`), you must explicitly state the schema for every relation in the function body (e.g. `from public.table`)."*

> *"By default, database functions can be executed by any role."*

`app.enforce_booking_item_passenger_lifecycle` and `app.guard_write_capability` both carry `security definer set search_path = ''` and schema-qualify every relation (`public.booking_items`, `public.bookings`), and the migration carries `revoke execute on function app.guard_write_capability() from public`. The shape was already right; the documentation confirms it rather than changing it. **No Skill affected implementation, testing, governance or documentation.**

---

## 3. THE FOUR INHERITED FINDINGS, RE-VERIFIED AGAINST THE CURRENT IMPLEMENTATION

The evidence base was treated as leads to test, not conclusions to accept. Each was re-measured on a freshly reset stack.

### 3.1 What the trigger firing order changes about the whole analysis

Measured first, because it reorders the other findings:

```
booking_item_passengers_enforce_lifecycle
booking_item_passengers_enforce_subscription_write_gate
booking_item_passengers_guard_financials
booking_item_passengers_guard_write_capability
```

PostgreSQL fires BEFORE ROW triggers in **name order**, so `enforce_lifecycle` — the SECURITY DEFINER function of PAX-3 — runs **before** the capability guard. Two consequences, both load-bearing:

1. PAX-3 is **not** closed as a side effect of PAX-1. A capability-less caller is stopped by the capability guard and never reaches the oracle; **only an actor who passes it can test the oracle at all.** The adversarial test therefore attacks PAX-3 with the `employee` who *holds* `CREATE_BOOKING_ITEM`. Attacking with the weaker role would have proved nothing and looked like proof.
2. The two repairs are genuinely independent and both are needed.

### 3.2 PAX-1 — CONFIRMED, and repaired

Reproduced as a real `finance_manager` with `aal2`:

```
has_permission('CREATE_BOOKING_ITEM')      false
has_permission('VIEW_FINANCIAL_DOCUMENTS') true      -- parent items VISIBLE: 2 rows
```

Post-repair, the direct table INSERT is refused:

```
ERROR:  permission denied: one of CREATE_BOOKING_ITEM is required to write booking_item_passengers
CONTEXT: PL/pgSQL function app.guard_write_capability()
```

and the legitimate paths both survive — an `employee` holding the capability writes the row directly (**it persists**), and `app.link_passenger_to_booking_item` still succeeds.

**The control that makes this non-vacuous** is that the finance manager can *see* the parent. A `trainee` is also refused — but by RLS, because the read-scope policy requires the parent item to be visible and a trainee sees zero. That is **visibility, not authority**, and it is why a low-privilege attacker had called this surface safe.

### 3.3 PAX-2 — CONFIRMED, and repaired without inventing a business rule

The swap is now priced at `CREATE_BOOKING_ITEM` on the UPDATE verb. It is **not forbidden**: an actor who holds the capability may still correct a manifest, and the test asserts that the correction takes effect. Whether a manifest may be corrected *after issuance* is **PAX-5**, open, owner — canon does not answer it and this slice did not invent an answer.

### 3.4 PAX-3 — CONFIRMED, and the oracle is closed by construction

Same actor, same statement, three parents, measured post-repair:

| Attack | Before `202607061400` | After |
|---|---|---|
| foreign **CANCELLED** item | `23514 cannot add a passenger to a cancelled booking item` | `42501 new row violates row-level security policy for table "booking_item_passengers"` |
| foreign **ACTIVE** item | `42501 new row violates row-level security policy…` | **identical string** |
| **nonexistent** id | `42501 new row violates row-level security policy…` | **identical string** |
| **same-tenant** cancelled item | `23514 cannot add a passenger to a cancelled booking item` | **unchanged — the trigger still speaks** |

The security property is **indistinguishability**, so the test pins the *same message string* three times rather than pinning three codes and hoping. The fourth row is the control that keeps the first three honest: without it, a trigger that had simply died would satisfy them.

### 3.5 The by-design behaviour — left unchanged, and re-checked

Re-pricing a passenger on an already-attached row whose item has since been cancelled remains **ALLOWED**. BOOK-1's own header rules on it — *"Editing an item already attached to a closed booking is a different question with different answers (a correction to a historical record may be legitimate)"* — and the passenger trigger mirrors the item trigger deliberately. **No new evidence disturbed that classification, so it stands unchanged.**

---

## 4. THE FINDING THE SLICE DID NOT EXPECT: A CEILING THAT HAD BEEN VOUCHING FOR THE DEFECT

This is the part worth the next reader's time.

After the repair, `10_grant_model_test`'s middle ceiling — *"at most 20 tables have NO capability trigger that fires on INSERT"* — was re-measured, expecting it to fall to 19.

**It did not move. It was still 20.**

A number that stays still through a real repair was never counting the thing you thought it was. `booking_item_passengers` had **never been in that count**: the detector credits a table when *some* trigger on it names `app.authorize` / `app.has_permission`, and this table carried `app.guard_passenger_financials`, which does — and which **returns NEW immediately when both override amounts are null.**

So the financial half of the row was governed, the operational half — the half the table exists for — was not, and **all three SEC-1 ceilings reported the table as protected the entire time.** A conditional guard is indistinguishable from an unconditional one at the level of text. Registered as **MEAS-2**, MEAS-1's family.

**Nothing textual can fix this**, and the guard does not pretend otherwise. What it does is bound the population a human has to read: `10_grant_model_test` assertion 9 is a `set_eq` naming the **exactly ten** tables whose only capability trigger is bespoke rather than `guard_write_capability` (which charges unconditionally by construction). An eleventh bespoke guard now fails the suite, forcing its author to state whether it charges on every path.

### 4.1 BOOK-3 — the same defect on the parent table, reproduced and deliberately NOT fixed here

Applying that rule immediately, the ten were examined. `booking_items` is credited **only** by `app.guard_booking_item_financials`, whose every authorization is conditional:

```
if coalesce(new.cost_amount, 0) <> 0        then perform app.authorize('ENTER_COST');
if coalesce(new.selling_amount, 0) <> 0     then perform app.authorize('ENTER_SELLING_PRICE');
if new.cost_locked_at is not null           then perform app.authorize('APPROVE_FINANCE');
if new.finance_approval_status_code is not null then …
```

Measured, as a `finance_manager` holding `CREATE_BOOKING_ITEM = false`:

```
BARE ITEM PERSISTED: 1   holds CREATE_BOOKING_ITEM: false
NOW PRICE IT:
ERROR:  permission denied: ENTER_SELLING_PRICE
```

The financial half is genuinely guarded. **Creating the booked service itself is not.** `app.create_booking_item` charges `CREATE_BOOKING_ITEM`, so the mapping needs inventing nothing — it is read out of the table's own RPC, exactly as SEC-1b's rule prescribes.

**It is deliberately not repaired in this slice, and the reason is stated rather than implied.** The trigger must fire on UPDATE as well as INSERT, and `booking_items` is the most heavily written table in the domain: `advance_booking_item`, cost entry, cost locking, supplier assignment and finance approval all update it, and `finance_manager` holds `ENTER_COST` **without** `CREATE_BOOKING_ITEM`. A naive UPDATE arm would refuse finance its own legitimate work — precisely the CUST-3 shape — so it needs the `v_extra` treatment and a full re-run of the six HTTP journey suites. `booking_items` is its own `NOT-RECORDED` Batch 6 surface, it is **named as the next slice**, and BOOK-3 is registered at **High** with its reproduction, pinned meanwhile by assertion 9 so it cannot be forgotten.

Ramming it into slice 4 would have been the one-large-change this repository forbids. Leaving it *unrecorded* would have been worse.

---

## 5. ADVERSARIAL COVERAGE — ALL TEN CLASSES, NONE N/A

`104_booking_item_passenger_manifest_surface_test.sql`, **41 assertions**, declaring:

```
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS CONCURRENCY REPLAY PRIVILEGE OBSERVABILITY
```

Every class is live on this surface and **none is declared N/A** — unusual in this programme, and a property of the table rather than of the effort: it carries an authorization question, a tenant question, two doors, a parent lifecycle, composite foreign keys, a unique constraint that is a genuine cross-row invariant, and a SECURITY DEFINER trigger.

| Class | Attacked as | Result |
|---|---|---|
| **AUTH** | capability-less write (finance_manager), trainee write, RPC vs table | refused at both verbs; positive controls prove the capability is genuinely held |
| **TENANT** | plant in rival tenant, row-hop, rival-passenger substitution, foreign-parent probe | refused; substitution refused by the composite FK `(tenant_id, passenger_id)` |
| **DOOR** | table vs RPC, DELETE, `anon`, definer-function inventory | DELETE refused at the GRANT; exactly one definer door executable by `authenticated` |
| **STATE** | cancelled item, archived item, item on a cancelled booking, UPDATE-path move, platform path | all refused, including session-less (BOOK-1 grants no exemption) |
| **INPUT** | negative per-passenger override at the table door | refused `23514` |
| **BUSINESS** | may a capable actor still correct a manifest? | **yes, and asserted** — no prohibition was invented (PAX-5 open) |
| **CONCURRENCY** | the cross-row invariant is pinned at exactly one — `(booking_item_id, passenger_id)` | two concurrent linkers serialise on the unique index; cannot be raced by construction |
| **REPLAY** | the same traveller linked twice | refused `23505` |
| **PRIVILEGE** | `guard_write_capability` executable by `public`? definer-door count? | revoked; count pinned at 1 |
| **OBSERVABILITY** | does a manifest change emit an event? | **no — and canon registers no vocabulary for one.** PAX-6, pinned as an absence |

**A vacuous assertion was written and then caught.** The trainee's swap was first asserted as `throws_ok … 42501`. It failed: *caught: no exception*. The trainee cannot see the row, so the UPDATE matches zero rows, **no trigger runs, and nothing raises**. Asserting a throw there would have recorded a capability check that never fired — the exact class `AGENTS.md §6` forbids. It is now a `lives_ok` plus a data assertion read **as `postgres`**, because reading it back through the trainee's own session would have returned NULL whether the swap landed or not — an assertion that passes for the wrong reason. Both halves of that mistake are documented in the file.

---

## 6. MUTATION AND GUARD-OF-GUARD RESULTS

**In-file defect injection (PAR-4 + TEST-3), permanent — assertions 37-40:**

| Mutation | Original attack | Restored |
|---|---|---|
| `drop trigger booking_item_passengers_guard_write_capability` | PAX-1 insert **succeeds again** | refused again (assertion 38) |
| restore the **pre-repair** lifecycle body (parent looked up by id alone) | foreign CANCELLED **discloses `23514` again** | opaque again (assertion 40) |

**External mutation of the LIVE schema, to prove the test file itself detects the class** (not merely that savepoints work):

| Mutation applied to the live database | Test 104 result |
|---|---|
| capability trigger dropped | **FAIL — 8/41**, failing tests 9, 10, 12 (PAX-1, PAX-2) |
| pre-repair lifecycle body installed | **FAIL — 2/41**, failing tests 17 and 40 (PAX-3) |
| both restored by `npx supabase db reset` | **PASS 41/41** |

**Guard-of-guard: the existing suite caught this change, which is what it is for.** `58_write_grants_and_config_capability_test` assertions 25-26 failed on the first full Pass A — *have 26, want 25* and *have 1, want 0* — because the trigger count moved and `booking_item_passengers` was not in the declared allowlist. Both were updated **with the reason**, not silenced: the count is now 26 and the table is listed with a comment recording why SEC-1b's sweep missed it.

---

## 7. WHAT WAS NOT DONE, AND WHY

- **BOOK-3** — reproduced, registered High, open. §4.1 states the reason in full. Next slice.
- **PAX-4** — 20 `authenticated`-INSERTable tables have no capability trigger at all. Counted, listed, not swept. Some are certainly correct (`otp_challenges` is pre-authentication; `user_permission_grants` carries its authority in an RLS policy; canon 34 governs the three identity tables). The rest need a per-table answer canon must supply. Inventing twenty mappings in one migration is what this programme forbids.
- **PAX-5** — owner/business. When does a manifest become immutable, and who may override? Canon 28 and 31 do not say. The absence of a freeze is the status quo, not a regression.
- **PAX-6** — canon. A manifest change emits no business event through either door, because canon 27 registers no event type for one. `passenger_created` and fourteen `booking_item_*` types exist; nothing for attaching, swapping or removing a traveller. **PAX-2's repair made the swap AUTHORIZED, not AUDITED**, and that distinction is stated so no later reader infers an audit trail this slice did not build.
- **`created_at` remains rewritable by `authenticated`** on this table — unchanged, and the reason is the number: this is a uniform schema-wide shape, not this table's defect. A one-table revoke would make the schema less consistent, not safer.

---

## 8. VERIFICATION AND FOUR-SURFACE PARITY

The `AGENTS.md §5a` protocol was executed in order, and every step's real output is recorded.

| # | Step | Result |
|---|---|---|
| 1 | `npx supabase db reset` | clean replay, **203 migrations** |
| 2 | Pass A — `npx supabase test db` | **104 files / 1602 assertions, PASS** |
| 3 | six HTTP suites | 29 + 107 + 74 + 120 + 40 + 60 = **430 passed / 0 failed** |
| 4 | Pass B — same, without reset | **104 / 1602, PASS** — Pass A = Pass B |
| 5 | smoke `verify_database.sql` | `ALL CHECKS PASSED (77 tables, …)` |
| 6 | Primary's three values, read **from Primary** | ledger `36d87db9…` (203) · functions `8754ef0a…` (277) · structure `06a3c59e…` (3,562) |
| 7 | `check_database_parity.ps1` | **DATABASE PARITY: CLEAN** (local proven; primary ledger, functions and structure proven) |
| 8 | regenerate `generate-api-contract.ps1`, `repository-all.ps1`, `generate-ai-map.ps1` | contract **unchanged**; index + ai-map refreshed |
| 9 | `check_repository_consistency.ps1` | **REPOSITORY CONSISTENCY: CLEAN** (Checks 1–24) |

**Two guards failed first, and both were fixed by changing the subject rather than the guard's budget.** `58_write_grants_and_config_capability_test` assertions 25-26 failed on Pass A because the trigger count moved and the new table was not declared — the allowlist now names it *with the reason*. Check 5 then reported **MANIFEST BLOAT** (8,106 characters against a 7,000 budget; one field at 1,332 against 1,200) because the `Last Completed` entry had become a narrative. `AGENTS.md §6` is explicit that the answer is always to trim, never to raise the budget, so both were cut and the narrative left here, where it belongs.

**Deployment to Primary.** The target was verified live before anything was written — `get_project_url` returned `vrvtsxexkiiiivlkdxzp`, the ref `MASTER_INTEGRATION_CATALOG.md §0` records as the sole deployment target of this repository. `202607061400` was applied via `apply_migration`, which stamped its own version `20260907043029`; that ledger row was **normalised to `202607061400`** so Primary's ledger matches the repository's filename, which is what every parity fingerprint is computed over.

**The evidence file was not transcribed by hand.** `reports/evidence/primary-ledger-evidence.json` carries all 203 entries. Rather than copy them from the MCP response and risk a silent typo, the repository's own filenames were hashed and **proved equal to the fingerprint read live from Primary** (`36d87db9a2a106de2808d608c59ec6c2`) before the array was written. GUARD-1's rule is not violated: the Primary value is the one read from Primary, and the repository list was *checked against it*, not substituted for it.

### Four-surface parity

| Surface | Required | Actual | Evidence | Verdict |
|---|---|---|---|---|
| Local Git | final implementation committed | 203 migrations, 104 test files, all governance files updated | `git log`, `git status` | **PASS** |
| Local working tree | clean | clean | `git status --short` empty | **PASS** |
| Local Supabase | final repository migration state | 203, replayed from scratch this session | reset + Pass A/B + smoke | **PASS** |
| Local HEAD | `== origin/main` | both `2573eaff3c9b368aa3c518e5f4ee4385a5325e38`, 0 ahead / 0 behind | `git rev-parse` both refs after `git fetch` | **PASS** |
| GitHub `origin/main` | final verified commit | `b552987..2573eaf main -> main`, fast-forward | push output + post-fetch `rev-parse` | **PASS** |
| GitHub CI | GREEN | **Repository Consistency success (1m4s)** · **Migration CI success (3m22s)** | runs `34084016035` and `34084016033` for `2573eaf` | **PASS** |
| Remote Supabase migrations | final state | 203, latest `202607061400` | live MCP read | **PASS** |
| Remote Supabase schema | matches repository | functions `8754ef0a…`/277, structure `06a3c59e…`/3,562 — identical to local | `parity_surface.sql`, **both sides ran the same file** | **PASS** |

### 8.1 The three rows this file could not assert about itself

A report cannot honestly record the result of pushing the commit that contains it, or of the CI run that commit triggers — writing `PASS` there before the run exists is precisely the *"declare completion immediately after a successful push"* that `AGENTS.md` forbids. Those three rows were therefore left open in the slice commit `2573eaf` and filled by **this** follow-up commit, which carries nothing else.

**The slice's own state is `2573eaf`** — the migration, the tests and the governance. This commit changes three table cells in this file and no engineering artifact, so the parity proved above still describes `2573eaf` exactly; its own CI run is the one that confirms the repository stayed CLEAN with these values written in.

---

## 9. NEXT STEP (exactly one)

**Batch 6 slice 5 — `booking_items`, closing BOOK-3 — and it is deliberately NOT the selector's choice.**

The selector was re-run after the disposition was updated. Its top rows are `nationalities`, `holidays`, `branch_business_hours` and `languages` (score −4), and **`booking_items` does not appear in its top twelve at all** — because the score is *exposure minus coverage*, and `booking_items` is one of the most heavily pgTAP-covered tables in the repository.

**That is MEAS-2 again, one layer up, and it is worth stating plainly: the selector subtracts coverage, and this slice just proved that coverage is not enforcement.** A table can be named in a dozen test files, credited by three ceilings, and still accept a write from an actor holding no capability. So the selector is used as it is documented — *"a high score says attacking here is most likely to be repaid, and a low score is never evidence that a surface is safe"* — and it is overridden here on evidence: **a reproduced High finding outranks a ranking.**

Take `booking_items`, and expect the UPDATE arm to be the whole difficulty: `finance_manager` holds `ENTER_COST` without `CREATE_BOOKING_ITEM`, so `guard_write_capability` needs the CUST-3 `v_extra` treatment, and the six HTTP journey suites must be re-run because every one of them writes that table. Run the selector again for slice 6.
