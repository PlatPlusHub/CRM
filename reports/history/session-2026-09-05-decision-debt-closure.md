# ORVION — Decision-debt closure: four findings closed as one control, two the audit did not have

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-05
Author: Claude Opus 5
Status: **COMPLETE — three migrations (`202607060600`, `202607060700`, `202607060800`), one CI defect, one new guard check. Deployed to Primary and parity-verified on all three surfaces. No canon rule changed; no owner decision manufactured.**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED:** Phase 8, Active CR `None.`, HEAD `1df2f06`, **194 migrations** on repository, local and Primary alike, zero commits since the 2026-09-05 capability audit — so that audit's measurements were current rather than stale, which was verified before anything was trusted from it.
- **PROVEN (behavioural evidence, this session):** all 197 migrations apply cleanly on a from-scratch `db reset`; pgTAP **99 files / 1453 assertions PASS**; smoke `ALL CHECKS PASSED (77 tables)`; six HTTP suites **430 assertions, 0 failed**; repository consistency **CLEAN 1–20**; **Primary parity PROVEN on all three surfaces with values READ FROM Primary** (ledger `aba2537d0bc95efd5869e4a5605f783e`, function surface `03732ae5bd8a52392652f221165b0095` / 274, structural surface `a5961d69f6d76589424bdf37943adbf9` / 3,524 across ten surfaces — every one identical to local).
- **UNPROVEN:** genuine concurrency for LEAD-5. pgTAP runs in one session and one transaction, so the advisory lock is proven to be TAKEN (via `pg_locks`, matched on the exact key) and is **not** proven to prevent a real overlapping pass. The test says so in its own comment rather than implying otherwise.
- **CHANGED:** three migrations; `.github/workflows/repository-consistency.yml`; `scripts/check_repository_consistency.ps1` (Check 20); five test files; `MASTER_API_CONTRACT.md` (regenerated, one line); `manifest.md`; `MASTER_GAP_REGISTER.md`; `MASTER_REPOSITORY_HEALTH.md`; `reports/evidence/primary-ledger-evidence.json`; `ai-map.json`; `reports/README.md`.
- **REMAINING:** **MAIL-1** is the only open owner decision, and it is a licensing question before it is a vendor one. **CUST-6** is newly opened and deliberately not fixed here. The next capability is **P3** — the notification delivery ledger's missing half — and it is NOT blocked by MAIL-1.
- **DO NOT TOUCH:** do not "simplify" the supplier credit branch in `app.guard_write_capability` into the customer branch's OR-list form. It was tried first this session and `90_supplier_credit_write_authority_test` assertion 12 refused it, correctly — see §3. Do not add a `starts_at <= now()` CHECK constraint to `user_role_assignments`: that would forbid the scheduling the column exists for. Do not add a `starts_at` parameter to `app.assign_user_role` — that is a feature, not AUTH-2's fix. Do not encode a retention period or an email provider.
- **NEXT:** P3, from §7 below.

---

## 1. WHAT WAS VERIFIED BEFORE ANYTHING WAS BELIEVED

The brief's first instruction was that the 2026-09-05 audit is *evidence, not current state*. Checked rather than assumed: `git rev-parse HEAD` = `1df2f06`, identical to the audit's baseline, with no commits after it and a working tree holding only the audit's own exported report. So the audit was not stale — but every finding acted on was still re-measured live, and two of its statements did not survive that.

Re-measured and **CONFIRMED**: 77/77 tables with RLS enabled and at least one policy, zero exceptions; precedence exactly `deny > user grant > role grant > plan gate`; the three intentional personal-auth tables; SLA wall-clock from `assigned_at` with 15/30 as function defaults; `process_lead_sla` writing `notifications` but never `notification_deliveries` (both credit evaluators do); all four supplier-credit defects still open in the catalog.

Re-measured and **NOT CONFIRMED**: the audit reported that enforcement and explainability agree. They do — but they agree on something *wrong*, which no comparison between them could ever surface. That is AUTH-2, §4.

---

## 2. THE SUPPLIER CREDIT PACKAGE — `202607060600`

Four registered findings, closed in one migration because they are the supplier half of one control and all four were deferred with the same sentence: *"recorded here rather than fixed inside a customer migration"*.

| Finding | What was wrong | What closed it |
|---|---|---|
| **CUST-4** | `customers` carries a non-negative ceiling CHECK; `suppliers` carries only both-or-neither | the same one line. A negative ceiling fires on the first unit of exposure and can never clear |
| **SUP-4d** | SUP-4b hooked the two EXPOSURE tables, reasoning exposure is a function of exactly those two. True of exposure — but the COMPARISON also moves when the CEILING moves | `suppliers_probe_credit_ceiling`, CUST-3's form exactly: AFTER, returning null, with a `when` clause so an edit to a supplier with no ceiling costs nothing |
| **CUST-5** | the "credit-only" branch compared full row images, correct only while no BEFORE trigger on `suppliers` mutated `new` | the row-image conjunct DELETED and nothing else |
| **SUP-4c** | non-matching currencies silently dropped; the reader returned a number that looked complete | per-currency aggregation, priced through the existing generic `app.exchange_rate_as_of`, with what could not be priced NAMED |

**No second FX authority was created.** CUST-3 wrote `app.exchange_rate_as_of` generic precisely so the supplier side could adopt it, and adopting it is all that happened. The rate instant was not invented here either: SUP-4c was reclassified to engineering on 2026-09-04 on external evidence (`12 CFR 32.9` mark-to-market for current credit exposure), and that ruling was applied rather than re-litigated.

**SUP-4d's test reproduces the silence before it proves the fix.** Exposure of 5,000 is created while the supplier has no ceiling — control assertion: zero events — and only then is the ceiling set to 1,000, with no write to any exposure table in between. Before this migration that sequence was completely silent.

---

## 3. THE FIX THAT WAS WRONG, AND THE TEST THAT SAID SO

CUST-5's register entry ends *"The customer branch is already on the robust OR-list form; bringing suppliers onto it is one edit."* That is what was built first, and it was wrong.

The OR-list form appends `MANAGE_SUPPLIER_CREDIT` to what is *sufficient*. Doing that stops `guard_write_capability` being an **enforcer** of the credit permission and turns it into an extra way to pass: an actor holding `ASSIGN_SUPPLIER` and not `MANAGE_SUPPLIER_CREDIT` would satisfy it on a credit write. `90_supplier_credit_write_authority_test` assertion 12 exists to forbid exactly that — it drops `suppliers_guard_credit_authority` and requires the write to be refused **anyway**, which is what "two independent enforcers" means. It failed.

The fix that shipped deletes the fragile conjunct and leaves the consequence untouched: a write that TOUCHES the credit pair still *replaces* `v_perms` with `MANAGE_SUPPLIER_CREDIT`. Production behaviour does not move, and that is checkable rather than hopeful — `suppliers_guard_credit_authority` fires first (alphabetically) and already demands the permission for every credit-touching write, so the only writes whose treatment changes are mixed ones, and the change is a **tightening**.

Two mutation pairs had isolated the two guards **by choosing columns**, which only the row image made possible. They now drop the other trigger **by name** and require the refusal to persist — a stronger statement than the one they replaced.

**The asymmetry this leaves with `customers` is real and is recorded as CUST-6** rather than silently equalised: `MANAGE_CUSTOMER_CREDIT ⊄ CREATE_CUSTOMER`, so replacing on that table would refuse an employee legitimately creating a customer that happens to carry a ceiling.

---

## 4. AUTH-2 — the finding the audit did not have, and could not have had by comparison

`public.user_role_assignments.starts_at` is `NOT NULL DEFAULT now()`. It exists to say when an assignment comes into force. **`app.has_permission` did not read it.**

The sharpest statement is inside one function. Two grant paths, one statement, two different temporal rules:

```
user_permission_grants:  and g.starts_at <= now() and (g.ends_at is null or g.ends_at > now())
user_role_assignments:   and ura.is_active        and (ura.ends_at is null or ura.ends_at > now())
```

Seven readers, measured by **reading each body** rather than grepping — the string `starts_at` appears in `has_permission` only inside the user-grant CTE, which is MEAS-1's false positive exactly:

| Honours `starts_at` | Ignores it |
|---|---|
| `visible_branch_ids`, `visible_department_ids`, `credit_alert_recipients`, `lead_responsible_managers` | **`has_permission`** (the authority), **`effective_permissions`** (the explainer), **`requires_mfa`** (the MFA gate) |

**Reachable, not theoretical.** `authenticated` holds INSERT/UPDATE on `user_role_assignments`, gated by `MANAGE_USERS` in RLS `WITH CHECK` — the permission-bearing-RLS mechanism SEC-1's ratified model names. `starts_at` is caller-supplied through that door and no trigger constrains it. Scheduling *"this user becomes finance_manager on the 1st"* granted finance_manager from the moment the row was written.

**Why no audit that compares surfaces could find it:** enforcement and explainability *agreed*. They were both wrong. The contradiction was only visible against a third surface — the scope resolvers, which had honoured the column all along, so the same row granted the PERMISSION now while withholding the SCOPE until it started.

**It is engineering, not policy.** The column is NOT NULL DEFAULT `now()`, so every row that exists satisfies the corrected predicate and nothing anyone holds today is revoked; the sibling path in the same function already applied it; four of seven readers already applied it. The fix makes the minority agree with the majority — it does not invent a seventh opinion.

`app.assign_user_role` is deliberately unchanged: it takes no `starts_at`, so future-dating is unreachable through the RPC door, and adding the parameter would be a new capability rather than a fix.

---

## 5. LEAD-5 and CI-1

**LEAD-5.** `cron.job` runs `app.process_lead_sla()` every minute and pg_cron does not wait for the previous pass. Measured **per branch** rather than asserted for both: reassignment was already safe, because `lead_assignments_one_current_idx` is UNIQUE on `(lead_id) WHERE is_current` — a second concurrent reassignment cannot commit. The **warning branch had no such constraint**: it reads whether a warning exists, then writes an event and one notification per manager. Closed with `pg_try_advisory_xact_lock`, the idiom `record_payment`, `issue_receipt` and `create_invoice` already use — TRY rather than blocking, because a scheduled job that cannot get the lock should give up rather than queue behind a slow pass. SLA semantics untouched.

**CI-1.** `repository-consistency.yml` already stated the rule — *"Every file the guard reads or executes belongs in these lists"* — and had not applied it to three paths that four of its own checks read: Check 1 resolves pgTAP references against `supabase/tests/`, Check 7 reads `ai-map.json`, Check 9 derives migration state from `supabase/migrations/`, Check 15 counts the test files. A commit touching only migrations changed four checks' inputs and ran none of them. **Migration CI was deliberately not merged in**: it watches two of these paths but runs a database stack and never runs this guard, and the two validate different evidence classes. **Check 20** now fails if a known input path is missing, and states its own ceiling in its header — it is a fixed list and cannot discover an input a future check adds, because inferring the input set from the script would be a guess that could go green while wrong.

---

## 6. DECISION DEBT: WHAT WAS RESOLVED, AND THE ONE THAT SURVIVED

| ID | Verdict | Basis |
|---|---|---|
| **D1** SLA clock | **RESOLVED — no decision needed.** Wall-clock from assignment, 15/30, is what canon 04/10/26 says and what the code does. No business-hours engine | repository + live catalog |
| **D2** SLA configurability | **RESOLVED — no decision needed.** Already parameterised at the function boundary (`p_warn_after`, `p_reassign_after`); cron passes neither, so canon's values are the defaults. The extension point exists; no configuration machinery was built | live catalog |
| **D3** Email provider | **OWNER + COUNSEL — irreducible, and reframed.** See below | primary regulatory sources |
| **D4** Notification audience | **RESOLVED — no decision needed *yet*.** `app.credit_alert_recipients` hard-codes `owner`/`finance_manager`, and `permissions` already carries `capability_group` and `action_kind`. But no capability in the catalog expresses "may receive credit alerts", and minting one would be inventing policy. Deferred into P6 with the mechanism identified, not the policy | live catalog |
| **D5** SEC-1 | **RESOLVED as restatement.** Owner's Option B stands; only the figures moved. Restated in place, history kept | live catalog |
| **D6** Metering/quotas | **RESOLVED — remains deferred.** No structural hardening is available that does not presuppose a quota dimension | — |
| **D7** Retention | **RESOLVED — remains a counsel dependency, and is not a decision engineering may take.** Mechanism built, seeds ZERO rows, nothing destroyable | RET-1 |

**D3 is the only one that survived, and the research changed what it is.** Egypt's PDPL 151/2020 became fully operational with its Executive Regulations (Minister of Communications and Information Technology Decision No. 81 of 2025, November 2025), which require a **separate PDPC licence before personal data is transferred outside Egypt** — the application must name the destination country, purpose, data types and security measures, and **no adequacy list has been published**. A notification carries the recipient's email address. Every credible provider — Resend, Postmark, Brevo, Amazon SES — hosts outside Egypt.

So this is **not** a vendor-preference question with a compliance footnote. **The licence decides the shortlist, not the reverse**, and engineering cannot hold a licence or sign a DPA. Recommendation recorded in MAIL-1 (Resend on the developer surface; Brevo if an EU destination is the easier PDPC application), explicitly conditional on the licence.

**And it blocks nothing that matters now.** PostgreSQL never sends mail; the provider lives in n8n; the database half of P3 is provider-neutral.

---

## 7. NEXT — P3, and why it is not blocked

`notification_deliveries` records obligations and nothing ever retries or abandons one: no `attempt_count`, no `next_attempt_at`, no `last_attempt_at`, no `last_error`, no dead-letter state, no claim/result pair. `app.claim_conversion_deliveries` and `app.record_conversion_delivery_result` are the shipped precedent to model on rather than reinvent.

Also for P3, and it is canon rather than preference: `process_lead_sla` writes `notifications` and **never** `notification_deliveries`, while both credit evaluators write both. Canon 10 requires the manager notification; the delivery obligation should be recorded on the same footing as every other alert's.

None of that needs a provider, and none of it should wait for MAIL-1.

---

## 8. VERIFICATION — exact commands, exact results

| Gate | Result |
|---|---|
| `npx supabase db reset` | all **197** migrations apply cleanly from scratch |
| `npx supabase test db` | **99 files / 1453 assertions — All tests successful** (was 97/1423) |
| `scripts/verify_database.sql` | `ALL CHECKS PASSED (77 tables, RLS + policies, resolver + read-scope model, 71/607 catalog, FK standard, updated_at triggers, append-only audit, grant/schema-usage completeness)` |
| six HTTP suites | 29 + 120 + 107 + 40 + 74 + 60 = **430 passed, 0 failed** |
| `check_repository_consistency.ps1` | **CLEAN**, Checks 1–20 |
| `check_database_parity.ps1` with all three Primary values | ledger, function surface and structural surface **all match**; `MASTER_API_CONTRACT.md` matches the live surface |
| `generate-api-contract.ps1` | one line changed — `supplier_credit` gains `unconvertible_currencies`; **75 endpoints, unchanged** |

**Primary values were READ FROM PRIMARY** through the `supabase-primary` MCP, using the *same* `scripts/parity_surface.sql` both sides run, and passed to the guard — never derived from the repository (GUARD-1).

**One deployment detail worth recording.** `apply_migration` stamps its own timestamp version (`20260905132852`), not the repository's synthetic `2026070606xx` scheme, so Primary's ledger initially disagreed with the repository by construction. Corrected with three `update … set version = …` statements against `supabase_migrations.schema_migrations`, after which Primary's fingerprint matched local's exactly. Anyone deploying this way must do the same, or Check 19 will fail for a reason that has nothing to do with drift.

**Stated because a guard must not be quoted for more than it measures (MEAS-1):** both the function-surface and structural-surface hashes strip `--` comments before hashing. They therefore prove the deployed **code** is byte-identical to local; they do not compare comment text.

---

## 9. WHAT WAS NOT DONE, AND WHY

- **P3 (notification retry/dead-letter)** — identified, scoped, not built. It is the next capability, not this one.
- **P6 capability-based audiences** — the mechanism is identified (`permissions.capability_group` / `action_kind` already exist); the policy is not, and minting a capability name to satisfy a hard-coded list would be inventing it.
- **P7 commercialization** — deferred, unchanged.
- **CUST-6** — opened, deliberately not fixed. Closing it needs a distinct required-permission mechanism, which is a design change rather than an edit, and `customers`' current behaviour is owner-approved and shipped.
- **No canon document was changed.** Nothing this session altered a business rule, so nothing needed to.

End of report.
