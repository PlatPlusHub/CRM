# ORVION — API-3 Subscription & Licensing: A Single-Use Code That Was Not, and a Recovery Path That Was Shut

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Status: Complete. **`202607058400` and `202607058500` are NOT deployed to Primary — awaiting owner approval.**

---

## 1. Objective and 2. Scope

**Objective (FACT).** Audit API-3's subscription/licensing family — `redeem_license_token`,
`upload_subscription_payment_proof`, `tenant_capabilities` — and give all three their first HTTP
execution evidence.

**Bounded surface examined:** the three RPCs and their `public` wrappers; `tenant_license_activations`,
`subscription_payment_proofs`, `subscriptions`, `feature_entitlements` and `documents` /
`document_versions` (columns, constraints, indexes, triggers, RLS, grants); every function that reads
or writes `subscriptions`; the permission matrix and `required_feature_code` for the permissions this
path charges; canon 09 (plans and access) and canon 28 (permissions matrix); the recorded history
LIC-1, PP-1, SPP-1/2/3.

**Dependencies inspected only as far as necessary, with reason:** `app.guard_write_capability` and
`app.enforce_document_version_integrity` (they are what refused the payment-proof upload — without
reading them the refusal could not be explained); `app.platform_activate_subscription` and
`app.provision_tenant` (to establish whether a second subscription row is reachable, which decided
CAP-1's classification); `public.payments` was **not** needed here.

**Explicitly OUT OF SCOPE:** the remaining three API-3 endpoints, n8n, the roadmap, deployment of any
migration, and **SPP-3**, which is an already-recorded BLOCKED architectural decision about where
platform identity lives — it was read, not reopened, and no answer was guessed.

---

## 3. Git state

| | |
|---|---|
| Branch | `main` → `origin/main`, 0 ahead / 0 behind |
| Starting HEAD | `09adf1951a733689949c9dec4be730eaeedcbc74` |
| Ending HEAD | `09adf1951a733689949c9dec4be730eaeedcbc74` — **unchanged** |
| Working tree | **DIRTY, deliberately** — five uncommitted packages |
| Commit / Push | **NO / NO** |

The three pre-existing uncommitted packages were verified present at session start and untouched.

## 4. Local database state (measured)

Start: **172 migrations**, latest `202607058300`, matching the 172 migration files. End: **174**,
latest `202607058500`.

## 5. Primary state (measured this session)

Read **four times, written zero times**: `get_project_url` → `vrvtsxexkiiiivlkdxzp`; ledger
**169**, latest `202607058000`, `4f79ecfdad3b2f1f424f72e70e414d86`; function surface
`a994108bd5cf44f9cc570180e72312a4` (236); structural surface `3a65328f42bd8c13b3f3048fa8f0158f`
(3,348). **PRIMARY evidence class.**

---

## 6–7. Findings

### LIC-2 — the single-use code was not single-use · High · **PROVEN DEFECT → FIXED**

**Hypothesis.** `redeem_license_token` reads the row, checks `consumed_at is null`, then updates
`where id = v_row.id`. Check-then-act with no guard on the act.
**Authoritative source that makes it a defect.** The repository asserts the opposite in two places:
the function's own comment (*"replay is closed by `consumed_at` regardless of auditing"*) and
`43_license_activation_test.sql` assertion 11 (*"the SAME code cannot be used twice — replay is closed
by consumption, not by hoping"*). Both are true sequentially and false concurrently — **LESSON 4**.
**Positive control.** A valid code redeems and the subscription activates (test 80 assertions 13–14).
**Reproduction — two live psql sessions on a committed fixture.** Session A: `begin; redeem(tok);
pg_sleep(6); commit;`. Session B, two seconds later while A was still open: `begin; redeem(tok);
commit;`. **Both returned success.** Measured: `security_events` `license_token_redeemed` = **2** for
one token; `tenant_license_activations` rows = 1, consumed = 1; subscription moved
trial/starter → active/professional, activated twice. The evidence is not merely incomplete but
**internally inconsistent** — the row says consumed once, the audit spine says twice.
**Enforcement layer, measured rather than copied.** `authenticated` holds **no grant at all** on
`tenant_license_activations` and its RLS policy is `platform_only`, so there is no second door — this
is the rare case where the function is the complete answer, unlike BOOK-1 / ASGN-1 / CM-2 where the
table was reachable. A trigger would guard a door nobody can open. Closed with a compare-and-swap
(`and consumed_at is null`, raising on `not found`) using the **same generic message**, because "you
lost the race" would be as much of an oracle as "already used".
**Fix proven by the identical experiment.** Session B now raises `activation code is not valid` at
the new branch while A succeeds; `security_events` = **1**.

### LIC-3 — the only way back from `read_only` was shut on `starter` · High · **PROVEN DEFECT → FIXED**

**Hypothesis.** The RPC charges `MANAGE_TENANT_SETTINGS` but its internal inserts charge
`UPLOAD_DOCUMENT` / `CREATE_DOCUMENT_VERSION`, and both carry `required_feature_code = 'documents'`.
**Authority.** Canon 09/28, via this register's DOC-2 row: a lapsed tenant uploads bank-transfer proof
so the Platform Owner can reactivate — *"the only way back from `read_only`"*. WP-04-B narrowed the
**subscription** gate for exactly this; the **plan** gate was never considered.
**Reproduction — a discriminating experiment.** Two tenants identical in every respect except the
plan, same `owner` role, same aal2 claim, same call:

| tenant plan | `documents` entitlement | `has_permission('UPLOAD_DOCUMENT')` | upload |
|---|---|---|---|
| professional | true | **TRUE** | **SUCCEEDS** |
| starter | false | **FALSE** | **REFUSED** |

`MANAGE_TENANT_SETTINGS` was TRUE on both. The plan is the only variable, so the plan is the cause.

### PP-4 — an employee could plant a confidential payment proof · Medium · **PROVEN DEFECT → FIXED**

**Reproduction, same run:** a plain `employee` on a professional plan, holding **no**
`MANAGE_TENANT_SETTINGS`, INSERTed a `documents` row with `document_type_code = 'payment_proof'`
marked confidential — `INSERT 0 1`. SPP-2 closed the forged proof on `subscription_payment_proofs`;
the `documents` half was never considered. Harm is SPP-2's: a fabricated proof in the tenant's
confidential set that a Platform Owner reviewing renewals could be misled by.

### CAP-1 — `tenant_capabilities` omits "latest row wins" · Low · **NOT REPRODUCIBLE — recorded**

Seven subscription readers (`plan_allows`, `plan_limit`, `subscription_allows_write`,
`enforce_subscription_write_gate`, `platform_activate_subscription`,
`upload_subscription_payment_proof`, `process_subscription_lifecycle`) order by `created_at desc
limit 1`. `tenant_capabilities` joins `subscriptions` with **no ordering at all**. **Measured before
recording:** `provision_tenant` is the ONLY inserter, `platform_activate_subscription` UPDATEs, and
**no role holds `MANAGE_SUBSCRIPTION`** — so a second row is unreachable and no harm could be
produced. Recorded because seven siblings defend against a state this one does not.

### NOT A DEFECT — established, not assumed

- **`tenant_capabilities` is not permission-gated.** Deliberate, and the reading is evidenced: canon 09
  lists what plan limits cover and says nothing about who may see them; canon 28 scopes
  `VIEW_SUBSCRIPTION_STATUS` to subscription **status**; the function exposes no price, billing date or
  payment data; and it has **no internal consumer**, so it cannot create an authorization
  inconsistency anywhere else. Proven both ways over HTTP and in pgTAP: an employee reads
  capabilities, and the `subscriptions` row stays empty for that same employee.
- **Cross-tenant capability leakage.** Disproven: it takes no argument and resolves
  `app.current_tenant_id()`. A discriminating control — a starter tenant told `documents = false` and
  a professional tenant told `true` — shows it resolves the caller's own tenant.
- **`tenant_capabilities` vs `plan_allows` status divergence.** `plan_allows` ignores subscription
  status (status is enforced by the write gate) while `tenant_capabilities` composes it. Different
  questions, no internal consumer — not a defect.
- **Cross-tenant licence redemption.** The token lookup is scoped by `tenant_id`, so another agency's
  token is invisible rather than merely refused. Asserted.
- **LIC-1** (a refused redemption is not audited) — **unchanged and still BLOCKED BY EXTERNAL
  DEPENDENCY.** `202607058400` neither improves nor worsens it; the new refusal path raises like every
  other. Read, not reopened.
- **SPP-3** — read and left alone: an explicitly recorded BLOCKED architectural decision about where
  platform identity lives. No answer was guessed.

---

## 8–9. Fixes and tests

| File | Change |
|---|---|
| `202607058400_a_single_use_code_is_single_use_under_concurrency_too.sql` | LIC-2 compare-and-swap |
| `202607058500_paying_for_your_plan_is_not_a_plan_feature.sql` | LIC-3 + PP-4: both guards charge `MANAGE_TENANT_SETTINGS` for `payment_proof` documents |
| `supabase/tests/80_subscription_licensing_test.sql` | **NEW**, 18 assertions |
| `scripts/verify_journey_branches.ps1` | +10 HTTP assertions (53 → 63) |
| `supabase/tests/35_subscription_write_gate_test.sql` | fixture correction (below) |

**What was deliberately NOT done:** the `starter` plan's `documents` entitlement was not changed.
What a plan includes is a commercial decision belonging to the owner; flipping an entitlement to fix
an authorization bug would have silently sold a feature.

---

## 10. Measurement attacks, and the mistakes that were mine

**LIC-2's guard is mutation-tested** (test 80, assertions 17–18): replace the function with a body
lacking the compare-and-swap and the guard fails; restore and it passes. **Its limitation is stated
rather than implied** — pgTAP runs one session in one transaction and structurally cannot stage the
race, so that assertion measures *source text* (VER-1's REPOSITORY class). **The behavioural proof is
the two-session experiment recorded in §6**, before and after.

**Negative controls proving no overreach:** an already-canonical ordinary document still inserts on a
plan that includes documents; a conversion carrying no money is still legal; an employee still reads
capabilities.

**Two guards caught real regressions in this session's own work:**
1. **The whole suite refused my first draft of `guard_write_capability`** — 21 files failed. I put
   `new.document_type_code` inside the CASE shared by every guarded table, and a record field
   reference is resolved against the **actual** record type at execution: an untaken branch does not
   make it disappear. Restructured into its own statement.
2. **Test 35 failed correctly.** Its payment-proof block used an `employee`, and PP-4's fix refuses
   exactly that. The block's own comment says its subject is the subscription gate, not the permission
   model, so the fixture now uses an owner — the same class as last session's TEST-64.

**Four further mistakes were mine and are recorded as measurement failures, not findings:**
3. Two assertions in my own test 80 asserted RLS behaviour while running as `postgres`, and expected
   RLS to *raise* when it *filters*.
4. I invented `app.tenant_capabilities_for_test`, which does not exist.
5. My first negative control ran on a `starter` tenant, where an ordinary document is refused for a
   reason that is not this migration — the plan model working as intended. Re-sited to professional.
6. **An ID collision I created and repaired:** I filed the employee-forgery finding as `PP-2`, which
   already exists (a `document_links` finding). Renamed to **PP-4** — and the blanket rename then
   corrupted `SPP-2` into `SPP-4` by substring match, which was detected and repaired in the same
   pass. Recorded because a silently renumbered finding would have broken Check 2's cross-Master
   comparison.

---

## 11. Verification executed THIS session

| Step | Result |
|---|---|
| `npx supabase db reset` | exit 0, **174** migrations |
| pgTAP **Pass A** | **80 files / 1,046 assertions / PASS** |
| **Six HTTP suites** | **349 passed, 0 failed** — 29 · 102 · **63** · 66 · 38 · 51 |
| pgTAP **Pass B**, no reset, under residue | **80 / 1,046 / PASS** = Pass A |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Local ledger | 174, `25b0bf8b28bba6c8b6e1232bd962373f` |
| Local function surface | `f689ec8b3ab0d45aab543018f7338823` (238) |
| Local structural surface | `e007dc8cac34d0c4a369fd3bd360a844` — 3,356 objects |
| Parity guard | **exit 1 — PRIMARY DRIFT, correct and intended** |
| API contract | regenerated: **68 of 71** with HTTP evidence |
| Repository guard | CLEAN, 13/13 |

*(The table above is the final protocol run, executed after every file edit in this session including
the PP-4 rename.)*

---

## 12. Primary / deployment

Read-only. Repository and local at 174, Primary at 169: **five migrations** (`202607058100`–
`202607058500`) are verified and undeployed pending owner approval. The parity guard's exit 1 is the
correct verdict for that state and must not be resolved by any means other than an approved
deployment. Repository ↔ local parity is CLEAN.

## 13. SSOT changed, and deliberately unchanged

**UPDATED:** `manifest.md` (live state, Last Completed, Next capability, suite counts) ·
`MASTER_GAP_REGISTER.md` (+4 rows: LIC-2, LIC-3, PP-4, CAP-1) · `MASTER_EXECUTION_PLAN.md` (Batch 6
narrative) · `reports/README.md` (pointer) · `MASTER_API_CONTRACT.md` and `ai-map.json` (regenerated).
**UNCHANGED:** `32_execution_roadmap.md` · canon 09/28 (**authority consulted, not subject** — no
canonical rule invented or altered) · `MASTER_CERTIFICATION_STATUS.md` · ADR log · the `starter` plan's
entitlements.

## 14. UNPROVEN

All five migrations on Primary (never deployed, never exercised there) · **CAP-1** ·
`storage-executor` Edge Function execution (carried forward) · **n8n — not contacted this session**,
so its state here is HISTORICAL, not verified.

## 15. Blockers

**One, and it is not engineering:** deployment approval for the five verified migrations.

## 16. Position

Phase 8 IN PROGRESS · Batch 6 · Foundation Completion gate **SHUT** · certification **CONDITIONAL** ·
Active CR **None** · **29 open owner decisions, unchanged — this session created none.**

## 17. Next executable step

**FACT:** API-3 has **3 endpoints** without HTTP evidence, named by `MASTER_API_CONTRACT.md`:
`assign_task` · `financial_documents` · `link_internal_supplier`.

**RECOMMENDATION (sequence, not an owner decision):** take all three together as the final API-3
package. They are unrelated to one another but small, and finishing them closes API-3 entirely, which
is one of the named Batch-6 gate items.

**OWNER DECISION, unchanged and not auto-approvable:** committing and deploying the five verified
migrations to Primary.

## 18–20. Session effects

**GitHub committed/pushed:** NO / NO. **Primary changed:** NO. **n8n contacted or changed:** NO.
