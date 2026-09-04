# ORVION — Governed implementation session: GOV-18, then the three approved owner decisions

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: **IN PROGRESS — GOV-18 COMPLETE and mutation-proven (25/25); CUST-3 COMPLETE and deployed to Primary.** VOID-1 and RET-1 follow, in the owner's order. This report is written as the work happens, not after it — every figure below was read from a run, not predicted.

---

## 1. STARTING STATE

Fetched first. `HEAD` = `origin/main` = `4c2f82b349f1e32e88a6a7bec788258cb30c81ae`, ahead/behind `0 0`, **clean tree**, **191 migrations**, **94 test files**. Repository consistency at that commit: **CLEAN, Checks 1–19, exit 0**.

Governance read before touching anything: `AGENTS.md` §3 (decision tiers, Design Challenge, cross-path sweep 5b), §5a (the nine-step verification protocol and the evidence-class table), §6 (guardrails — no vacuous security tests, attack every detector in both directions, static analysis is a lead never a verdict, test both doors); `manifest.md`; `MASTER_GAP_REGISTER.md`; `MASTER_EXECUTION_PLAN.md`; and the owner-decision resolution review that this session's approvals answer.

---

## 2. GOV-18 — ✅ COMPLETE

### 2.1 The defect, re-measured against the current file rather than quoted

Check 2 is the repository's central contradiction guard. Its open-detector was:

```powershell
$rowOpen = $line -match '\|\s*OPEN\s*\|'
```

— a padded table cell containing **exactly** the word `OPEN`. Deliberate when written (to kill prose false-positives), but its cost had never been measured.

**Measured now, across every table in `reports/master`: the bare form covers 20 of 84 open rows.** The register's earlier note said "19 of 54"; that figure counted a narrower substrate and is corrected here. The other 64 rows say `DESIGN-READY`, `PENDING (OPTIONAL / NEEDS MORE EVIDENCE)`, `BLOCKED — …`, `OPEN — …`, `TRIGGER-DEFERRED`, `VALIDATED-REQUIRED`, `MOVED→PENDING` or `PARTIALLY RESOLVED`.

So Check 2's contradiction pass — and, through `$xOpen`, AUD-04's cross-Master pass — was blind to **76%** of the open population. That is exactly how GOV-17's five contradictions printed CLEAN.

### 2.2 The fix: two changes, and the first is what makes the second safe

**(1) The row's status cell is found from its table's own header.** Every markdown table that declares a `Status` column sets the column index for the rows beneath it. This matters because the Status column is not at a fixed position: index **9** in `MASTER_GAP_REGISTER`, **2** in `MASTER_CERTIFICATION_STATUS`, **5** and **6** in the two `MASTER_INTEGRATION_CATALOG` tables.

Without this, widening the vocabulary would have read **other** cells — the register's `Cert` column holds a bare `✅`, and its `Owner Decision` column holds the bare word `pending` — and called almost every row open **and** resolved at once.

**Measured before trusting**: across all 15 Masters, **zero** rows have a non-status cell leading with a resolved marker while their status cell does not. So narrowing resolved-detection to the status cell changed **no existing verdict**, and only removed that latent trap.

**(2) The open vocabulary was derived from the files, not invented.** Every distinct leading token of every status cell in `reports/master` was enumerated first. The resulting set is the register's own legend (`Status: OPEN · DESIGN-READY · RESOLVED · VERIFIED`) plus the deferral forms actually in use.

**Terminal verdicts stay out, deliberately**: `INTENTIONAL`, `PROVEN NOT A DEFECT`, `UNPROVEN`, `ACCEPTED RISK`, `RECORDED, DELIBERATELY NOT FIXED`, `NOT REPRODUCIBLE`, `EVIDENCE ONLY`, `MEASURED`, `DECIDED`, `CONFIRMED`, `BUILT`, `CORRECTED`, `GUARDED`, `WIDENED`, `RECONCILED`, `REFACTORED`, `CONTROL APPLIED`, `RATIFIED`. Each is a finished verdict; reading one as "open" would manufacture contradictions — the mirror of the defect being fixed.

### 2.3 The asymmetry that is deliberate, and why

**Detail blocks are not scanned for "open".** A `###` block is an **append-only narrative**: the register records a finding's discovery state and its later resolution as separate blocks, so `BLOCKED` in an early block followed by `RESOLVED` in a later one is **correct history, not a contradiction**. `TASK-3`, `ORPH-1`, `PERM-1`, `RBAC-2`, `LEAD-2`, `LEAD-3` and `LEAD-4` all have exactly that shape; treating a block as open would manufacture a contradiction out of every one.

The **table row** is the current-state record (one row per id), so `open` is read only from it. `resolved` is read from **either** substrate (GOV-11's repair) — a resolution recorded anywhere means a row still saying open is **stale**, which is precisely the GOV-17 case this exists to catch.

### 2.4 Mutation proof — both directions, permanent and repeatable

`scripts/test_status_contradiction_guard.ps1`, following the precedent of `scripts/test_primary_ledger_guard.ps1`. **25 assertions, 0 failures.** Every scenario runs against isolated sandbox copies of `reports/master` through the guard's own `-RepoRoot`; the real register is never modified and no database is touched.

| Direction | Assertions | Result |
|---|---|---|
| **CONTROL (first)** | untouched copy reports no contradiction | ok |
| **A — must flag** | 10 open forms: `BLOCKED`, `DESIGN-READY`, `PENDING (…)`, `OPEN — …`, `IN PROGRESS`, `PARTIALLY RESOLVED`, `TRIGGER-DEFERRED`, `VALIDATED-REQUIRED`, `MOVED→PENDING`, bare `OPEN` | all detected |
| **A-old** | the pre-GOV-18 detector sees **1 of those 10** | proven |
| **B — must NOT flag** | 10 terminal verdicts | none flagged |
| **B-critical** | `**✅ RESOLVED … Superseded text:** **BLOCKED …**` — the shape **17 real rows** carry | not flagged |
| **B-column** | a row with `Cert=✅` and `Owner=pending` beside an open status is judged on its **Status** cell alone | exactly 1 hit |
| **CONTROL (second)** | untouched copy still clean after every mutation | ok |

**The first control earned its place immediately: it caught a real defect in the harness itself.** `Get-Contradictions` originally filtered with a case-insensitive `-match 'STATUS CONTRADICTION'`, which also matched Check 2's own banner — *"== Check 2: intra-file status contradiction in reports/master =="* — so every run returned a phantom hit and both controls failed while the guard was behaving correctly. Fixed to `-cmatch` with the trailing colon. A harness that cries wolf is indistinguishable from a guard that does.

### 2.5 It immediately found two real defects, and they were fixed

Running the widened guard against the live register reported exactly two contradictions — **`ATTR-1`** and **`CAT-5`** — both members of GOV-19's four identity splits, **rediscovered independently** by the new detector.

Each was an **older row still reading `OPEN`** while a newer row or block recorded the resolution. Both resolutions were verified **live, not taken on trust**:

- **ATTR-1** (row L185, superseded by L180 / SPEC-128) — `public.offline_conversions` carries `customer_id`, `customer_email` and `customer_phone`. The stale row proposed *"snapshot identity onto the conversion row **vs.** add a direct `customer_id`"*; the shipped answer did **both**, and `13_conversion_identity_snapshot_test.sql` guards it.
- **CAT-5** (row L189, superseded by the `CAT-5/CAT-6` row L154 / SPEC-141) — `app.sub_status_family` exists and `booking_items` carries the sub-status catalog trigger, so the rule is enforced on the table door as well as the RPC, which is exactly what the stale row said was missing.

Both superseded rows now state their resolution with that evidence, retaining the original text per the register's never-delete convention.

**Open ids visible to Check 2: 20 → 82** (84 before the two were reconciled).

### 2.6 GOV-18 verification

| Check | Result |
|---|---|
| `scripts/test_status_contradiction_guard.ps1` | **25 passed, 0 failed**, exit 0 |
| `scripts/check_repository_consistency.ps1` | **CLEAN, Checks 1–19, exit 0** |
| Database | **not touched** — guard and documentation only |

---

## 3. CUST-3 — ✅ COMPLETE (`202607060300`, deployed to Primary)

### 3.1 Built to the approval, and to the one instruction that broke the template

The owner approved a **nullable, tenant-supplied, warning-only** customer receivable ceiling with **no default invented** and **no dunning**. All of that is the shipped supplier pattern (SUP-4b), reused: a ceiling pair on the row, a `MANAGE_CUSTOMER_CREDIT` permission (owner/ceo/finance_manager, plan-gated `finance_lite`), an evaluator that inserts rows and raises nothing, `customer_credit_threshold_exceeded`/`_cleared` events with idempotence carried by the event ledger, an in-system notification and a `pending` email-delivery row.

**One instruction did not fit the template, and it is the interesting half:** *"implement conversion/comparison correctly rather than silently dropping foreign-currency exposure."* SUP-4b filters exposure to the ceiling's own currency (`and bi.currency_code = p_currency_code`), so a supplier owed EGP 8,000 **and** USD 600 against an EGP ceiling is measured on the EGP alone. Repeating that here was forbidden.

So CUST-3 implements **SUP-4c's already-decided rule** — convert into the limit's currency at the spot rate — through a new **generic** primitive, `app.exchange_rate_as_of`, deliberately not customer-specific so SUP-4c can bring suppliers onto it without a second authority appearing. **This is the first reader `public.exchange_rates` has ever had**: the table was created with `SET_EXCHANGE_RATE`-gated policies, a `set_by`-deriving trigger, the subscription gate and DUP-1's unique pair-instant index, and then never wired to anything.

**The fail-safe is stated rather than silent.** A currency carrying real exposure with no usable rate is neither dropped nor guessed: it is reported as `unconvertible_currencies` in the event payload, in the notification text, and through the read contract, and the convertible part is still compared.

### 3.2 The suite found five real defects before it shipped

| # | Defect | Caught by |
|---|---|---|
| 1 | `text[] \|\| 'literal'` → 22P02: PostgreSQL parsed the untyped literal *as an array* | new pgTAP test |
| 2 | **A record field named in a SHARED condition** — `new.credit_limit_amount` beside `tg_table_name = 'customers'` in one expression resolves for *every* table the guard serves. **Eight test files broke at once.** The LIC-3 / PP-4 class, and the guard's own comment states the rule three lines above | Pass A |
| 3 | **A row-image comparison broken by a sibling trigger** — see below | new pgTAP test |
| 4 | `numeric(14,2)` — two decimals truncate a 3-dp currency, DC-1/R7's own rule | `03_money_currency_precision_test` |
| 5 | Missing `revoke … from public` — `anon` inherited both new readers (GRANT-1) | `10_grant_model_test` **and** `53_api_surface_test`, independently |

**Defect 3 is worth stating in full, because copying a working pattern is what caused it.** The supplier form asks *"the credit pair changed AND nothing else did"*. On `customers` that is never true: `customers_derive_first_registration_actor` fires **before** the guard (`derive_` sorts before `guard_`) and sets `new.first_registered_user_id` whenever the old value is null — true for every customer created by a system path with no session. **The guard was comparing a row image a sibling trigger had already mutated**, so the branch never fired and a finance manager was refused.

The fix removes the row image entirely: `v_perms` is an **OR-list**, so a write that *touches* the ceiling simply makes `MANAGE_CUSTOMER_CREDIT` sufficient, while `customers_guard_credit_authority` — which fires first — still *requires* it for the credit change itself. Two doors, each answering its own question, and nothing that can be broken by a trigger running earlier.

`suppliers` escapes the same bug only because it happens to carry no mutating BEFORE trigger — an accident, not a design, recorded as **CUST-5**.

### 3.3 And an HTTP probe found a sixth that the supplier side still has — SUP-4d

The pgTAP suite was green and the reader correctly said `over_limit = true`, but the HTTP probe asserted the **event ledger** and found nothing. Cause: SUP-4b hooks only the two **exposure** tables, reasoning that *"exposure is a function of exactly two tables, so those are the only two that can move it"*. True of exposure — but **the comparison also moves when the ceiling moves**. An invoice was raised while the customer had no ceiling, the ceiling was then set *below* that exposure, and nothing alerted.

**Lowering a ceiling is exactly when a credit control should speak.** Closed for customers by `customers_probe_credit_ceiling` (AFTER INSERT OR UPDATE, with a `when` clause so ordinary customer edits cost nothing). The supplier side still has the gap and is recorded as **SUP-4d** rather than fixed inside a customer migration.

### 3.4 CUST-3 verification (the full `§5a` protocol)

| Step | Result |
|---|---|
| `npx supabase db reset` | **192 migrations**, exit 0 |
| **Pass A** — `npx supabase test db` | **95 files / 1374 assertions — PASS** |
| **HTTP × 6** | **423 passed / 0 failed** (29 · 107 · 74 · 113 · 40 · 60) |
| **Pass B** (no reset) | 95 / 1374 — **Pass A = Pass B** |
| Smoke | `ALL CHECKS PASSED (76 tables, 71/605 catalog)` |
| Primary deployment | `202607060300` applied; ledger row normalised from the CLI's `20260904194539` stamp to the repository version, per the recorded GUARD-1 precedent |
| **Primary parity** | **CLEAN — ledger, functions AND structure proven**, all three read **from** Primary |
| Repository consistency | **CLEAN, Checks 1–19, exit 0** |

**Primary, read live:** ledger **192 / `ac42c9ade1a8efc256106de6c5d3cfeb`** — the exact fingerprint Check 9 independently computes from the repository's migration files; functions **`9f5868004b0bd94bd859fc29cf491291` / 270**; structure **`dc049c3a1a03bf3b2df1cda403bcb29d` / 3,474**. The ledger evidence file was rebuilt from the repository's own filenames and **proven to reproduce Primary's live fingerprint before being written**.

**The caller trap, hit again and recorded again:** `-PrimaryFingerprint` wants the **bare md5**, not `count|hash`. Passing `192|ac42c9…` produced a false `PRIMARY DRIFT`.

### 3.5 Canon and SSOT synchronised

`27_event_catalog.md` (the two new event types, with their triggers and the conversion/reporting rule), `28_permissions_matrix.md` (item 6 — `MANAGE_CUSTOMER_CREDIT`, its grants, its orthogonality to `CREATE_CUSTOMER` in both directions, and the deliberate asymmetry with suppliers), `31_schema_draft.md` (the ceiling pair on `customers`), `MASTER_GAP_REGISTER.md` (CUST-3 implemented; **CUST-4**, **CUST-5**, **SUP-4d** recorded), `53_api_surface_test.sql` (the endpoint classification, 77 → 78), `scripts/verify_database.sql` (catalog pin 603 → 605), and the generated `MASTER_API_CONTRACT.md` (74 endpoints, all 74 with HTTP evidence).

---

*(VOID-1 and RET-1 sections follow as each is implemented.)*
