# ORVION — Foundation Completion, Security Scope & CRM Readiness Programme

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-24
Author: Claude Opus 5
Scope: Owner directive of 2026-08-24 — STEPS 1–16

---

# VERDICT

# FOUNDATION FREEZE — NOT EARNED

Three concrete Foundation defects remain. They are named in full in §5, and the first is not
something engineering can resolve:

1. **Primary carries none of this work and cannot be verified.** The `supabase-primary` MCP server
   disconnected mid-session and requires re-authorization, which is not possible non-interactively.
   Primary is 10 migrations behind and repo = local = Primary parity is **unverified**. Every result
   in this report is local-only.
2. **17 of 70 permissions remain enforced nowhere**, including the booking-item costing set
   (`ENTER_COST`, `ENTER_SELLING_PRICE`, `EDIT_LOCKED_COST`), the exchange-rate write path, and
   approval review.
3. **Plan gating is seeded but not enforced** (PLAN-1). Canon 28 states "Plan denial overrides user
   role permission"; nothing reads `feature_entitlements`.

---

# 1. What this programme found

Nine defects, seven of them security or integrity, all now closed. The pattern worth noting is that
**not one was found by reading a report**. Each came from asking the database a question it had not
been asked before.

| # | Defect | How it was found |
| --- | --- | --- |
| AUDIT-3 | Read model was tenant-only; 14 `VIEW_*` permissions enforced nowhere. A trainee could read every record in the tenant | The directive named it |
| SEC-3 | **Any employee could make themselves owner** with one INSERT into `user_role_assignments` | Challenging AUDIT-3's own implementation |
| SEC-4 | A colleague seeing a booking also saw its margin and the seller's commission | Owner directive §2.1, traced to `reporting.booking_item_profit` |
| HIST-1 | No reassignment path existed; every lead handover erased the first employee | Testing the owner's A→B scenario |
| CAT-5/6 | Conditional sub-status family enforced on one path only | Directive §16 |
| PLAN-1 | `feature_entitlements` had **zero rows and no reader** | Investigating CAT-6 |
| DUP-1 | Every duplicate rule was check-then-insert with no index behind it | Directive §18 |
| AUDIT-6 | The audit trail described in full the records it refused to show | Auditing what SPEC-137 had *not* covered |
| DOC-1 | Passport scans readable by every employee in the company | Auditing permission coverage |

The last two matter methodologically. **AUDIT-6 and DOC-1 were both created by SPEC-137** — the more
thoroughly the entities were scoped, the more the unscoped tables stood out as the way around the
model. DOC-1 in particular existed because SPEC-137 was checked against its own migration rather than
its own plan: the plan listed documents, the migration omitted them, and the tests asserted what the
migration did. Nothing inside that loop could have surfaced it. It took an independent question asked
from outside the change — "which permissions are enforced nowhere?"

---

# 2. The three owner visibility rules

All three are implemented and proven behaviourally.

**Branch isolation (§4).** Branch A staff cannot see or operate on Branch B's leads, bookings,
booking items, quotations, conversations, complaints, service requests, tasks, invoices, payments,
documents, or the events describing any of them. Branch identity is preserved on every row, so
branch-specific and consolidated reporting are both derivable — asserted directly (test 21,
assertion 11).

**Department continuity (§3).** A colleague in the same department can continue an absent employee's
work. Canon 28 says department visibility "requires explicit permission" and marks Employee "No"; the
owner requires it available by default. Both hold literally: the mechanism is permission-gated exactly
as canon specifies, and the permission is granted to `employee` and `senior_employee`. `trainee` is
excluded, which is what makes the restricted-user boundary real rather than incidental.

**Employee financial privacy (§2.1).** A colleague keeps the booking item and its selling amount, and
loses `cost_amount`, `commission_rate` and profit. The rule needed no new permission — canon 28
already scopes `VIEW_FINANCIAL_DOCUMENTS` as finance roles plus "Assigned related only" for
employees, which is precisely what the owner asked for.

---

# 3. Two design decisions a reviewer should check hardest

**The customer master is deliberately not branch-scoped.** Canon 05 §Customer Cross-Branch Awareness
requires that a customer dealing with two branches is *not* duplicated and that a limited cross-branch
summary — last interaction date, branch, and employee — stays visible. Those are exactly the three
columns `customers` already carries. Canon then draws the line: "Detailed event content from another
branch is not shown by default." So the master row is tenant-visible and every activity record about
them is branch-scoped. Branch-scoping the master would prevent a second branch finding a returning
customer and produce the duplicate canon 05 exists to forbid.

**`app.booking_item_profit` stayed SECURITY INVOKER.** The obvious fix for §2.1 was to make it
DEFINER and check the permission inside. That would have worked and been wrong: a definer function
bypasses RLS, so it would have had to re-implement the row-scope model in a second place. Only the
*numbers* moved behind a definer accessor. One authority decides which rows appear; a different one
decides whether the money appears.

---

# 4. Verification state (local)

| Check | Result |
| --- | --- |
| Clean `db reset` from empty | 112 migrations, replays clean |
| Full regression | `Files=28, Tests=235 … PASS` |
| Smoke (`verify_database.sql`) | `ALL CHECKS PASSED` |
| Repository consistency guard | `CLEAN` |
| repo = local | 112 = 112, fingerprint `5cdd944b34ee6e869a30dd24aed6dce4` |
| Working tree | clean, 0 unpushed |
| Permissions enforced | **53 of 70** (was 33) |

**The suite gained its first tests that actually exercise RLS.** Before this programme, every test
ran as `postgres` — which owns the tables and therefore bypasses row-level security entirely. Not one
test had ever proven that an RLS policy filters a row, including the tenant isolation the whole system
rests on. Tests 21, 22, 23, 27 and 28 run as `authenticated`; the policies are now the only thing
between the caller and the data in 63 assertions.

---

# 5. What remains before a freeze can be earned

**Blocking, and outside engineering's reach:**

- **Primary deployment and verification.** 10 migrations behind; the MCP server needs
  re-authorization in an interactive session (`claude mcp` or `/mcp`). Until then STEP 15 cannot run
  and no parity claim is honest.

**Blocking, and determinable from canon:**

- **17 permissions still enforced nowhere.** Booking-item costing (`ENTER_COST`,
  `ENTER_SELLING_PRICE`, `EDIT_LOCKED_COST`), exchange rates (`SET_EXCHANGE_RATE`,
  `CREATE_EXCHANGE_RATE_ADJUSTMENT`), `REVIEW_APPROVAL_REQUEST`, the platform-admin set, the API
  scope pair, and four reporting `VIEW_*` permissions that will gate `reporting` views.
- **PLAN-1 enforcement.** The matrix is seeded; nothing reads it. Canon 35 §8 explicitly defers *where*
  the gate sits to implementation time — that decision is now due, and `usage_counters` (empty) is its
  counterpart for the numeric ceilings.

**Not blocking, recorded rather than guessed:**

- `leads.owner_user_id` and `leads.assigned_user_id` always hold the same value. Canon 31 lists both
  without distinguishing them. Deciding which one canon intends belongs to a table-by-table pass that
  can ask the question of all eight ownership-triple tables at once.
- Canon marks Basic Reporting (Starter), Integrations and Offline Conversion (Professional) as
  "Limited" and defines no ceiling for any of them. **Owner business decision.**
- `bookings.destination_city` is free text with no reference table. Destination *country* is
  constrained; city is not, which limits "which destinations sell best" as a report. Canon defines no
  city vocabulary and inventing one is a reference-data project, not a Foundation fix.
- `moddatetime` is installed in `public` rather than `extensions`. Cosmetic; ~50 triggers depend on it.

**Steps not reached in this programme:** the exhaustive table-by-table pass (STEP 4) was performed
across the security, duplicate-prevention, vocabulary and reporting dimensions but not column-by-column
for all 72 tables; STEPS 9–11 (employee walkthrough extension, n8n and Google re-verification) were
not re-run, since the Google Ads / Data Manager conclusion was independently verified on 2026-08-21
and nothing in this programme touched that contract.

---

# 6. Configuration audit (STEP 7) — clean

| Dimension | Result |
| --- | --- |
| SECURITY DEFINER functions without pinned `search_path` | 0 |
| Function ownership | 95/95 owned by `postgres` |
| Grants to `PUBLIC` in `app` / `public` / `reporting` | 0 |
| `anon` role privileges | none |
| Policies targeting the `public` role | 0 |
| Catalog families with no values | 0 |
| Reference data | 82 countries, 82 nationalities, 20 languages, 18 currencies, 9 roles, 70 permissions, 3 plans, 66 entitlements |

---

# 7. Change requests delivered

| CR | Subject | Migrations | Tests |
| --- | --- | --- | --- |
| SPEC-137 | Read-scope model (AUDIT-3) | `202607051400`, `202607051500` | 21 |
| SPEC-138 | RBAC write authority (SEC-3) | `202607051600` | 22 |
| SPEC-139 | Employee financial privacy (SEC-4) | `202607051700` | 23 |
| SPEC-140 | Assignment history + `reassign_lead` (HIST-1) | `202607051800`, `202607051900` | 24 |
| SPEC-141 | CAT-5 / CAT-6 + plan matrix (PLAN-1 data) | `202607052000` | 25 |
| SPEC-142 | Duplicate prevention (DUP-1) | `202607052100` | 26 |
| SPEC-143 | Event visibility + 360 timelines (AUDIT-6) | `202607052200` | 27 |
| SPEC-144 | Document read scope (DOC-1) | `202607052300` | 28 |

Each carries its own Execution Log and Verification Notes in `changes/`.

---

End of report.
