# ORVION — Session Report, 2026-08-28: Six Packages, and Three Guards That Were Lying

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: The whole session. Migrations `202607056100` … `202607056500`, five new test files, one new
HTTP suite, and corrections to four existing guards.
Status: Complete. All six packages deployed to Primary and pushed; remote independently verified
after each.

**Branch:** `main` · **Session start HEAD:** `40de857` · **Session end HEAD:** see §10 ·
**Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Starting state, re-proven live rather than trusted

| Axis | Evidence at session start |
|---|---|
| GitHub | `gh api …/commits/main` = `40de8577518a…` = local HEAD; `ls-remote` agreed; tree clean |
| Repository | 149 migrations, 57 test files |
| Local + Primary | 149 migrations, fingerprint `c76d13a17ce0bf6dcb9888ba741e3b39` on repo, local and Primary |
| pgTAP | reported as 646/0 by the previous session — **it was not** (see §2) |

Everything matched the previous report **except the test suite**. That discrepancy set the shape of
the whole session.

---

## 2. The through-line: three guards that checked less than they claimed

This session found and fixed **three separate guards that reported health they had not measured**,
plus one detector whose narrowness had already produced a wrong finding in the register.

| guard | claimed | actually checked | consequence |
|---|---|---|---|
| `54_transition_permission_parity_test` | ten `advance_*` functions vs the transition table | **one** function (its regex matched only `advance_booking`'s tuple shape); its positive control was satisfied by that one | TRANS-2 hid behind it |
| `10_grant_model_test` capability detector | "tables with no capability trigger" | triggers calling `app.authorize` **only** | recorded `lead_interactions` as an open business question when it was a live bypass |
| `10_grant_model_test` PUBLIC-EXECUTE | no function granted to PUBLIC | the **`app`** schema only — not `public`, where all 74 endpoints live and where `pg_default_acl` grants EXECUTE by default | a future ORVION function in `public` would not have been caught |
| the pgTAP suite itself | 646 assertions passing | passing **only against a clean database** | 40+ fixtures silently depended on the rest of the DB |

The pattern is worth naming, because it recurred four times in one day: **a guard written against the
first instance takes that instance's shape, and the shape is the bug.** Every fix in this session
that widened a detector also recorded *why* in the file, so the next engineer inherits the reason and
not just the code.

---

## 3. Package 1 — SEC-1's residue: three problems, three different actions (`202607056100`)

Counting the thirteen implied they shared an answer. Investigating each individually produced three,
and they needed opposite actions.

- **Five system-owned** (`attribution_clicks`, `notifications`, `notification_deliveries`,
  `offline_conversion_deliveries`, `usage_counters`): every writer is SECURITY DEFINER and **none is
  executable by `authenticated`** (`orvion_integration` / `service_role`); two have no writer at all.
  The table grant was a second door only direct DML used → **revoked, not permissioned.**
  `notifications` keeps a **column-level** `update (is_read, read_at)`: dismissing your own
  notification is a real user act with no RPC, and removing the whole UPDATE would have deleted a
  capability instead of closing a hole.
- **Four tenant configuration** (`branch_business_hours`, `holidays`, `financial_accounts`,
  `company_assets`) with no writer at all → guarded with the permission ORVION already charges for
  the same object. `financial_accounts` is the instructive one: `MANAGE_TENANT_SETTINGS` was the
  obvious guess and is **wrong** — it resolves to {ceo, owner} and would have locked the finance
  manager out of the bank accounts payments post against. Reading `chart_of_accounts` instead gave
  `CREATE_JOURNAL_ENTRY` = {ceo, finance_manager, owner}.
- **Three that were never residue**: canon 34 states that `otp_challenges`, `totp_enrollments` and
  `trusted_devices` belong to the Human Identity and that row-ownership by `auth.uid()` **is** their
  model. INTENTIONAL, now proven behaviourally.

Also fixed: **TEST-1** — 40+ fixture subqueries across eleven files selecting their own rows by a
non-unique attribute with no tenant predicate. Found because `38_class_a_events_test` failed on a
real composite FK: its fixture cross-joined every tenant's invoices as `postgres` with RLS off, and
`verify_role_journeys.ps1` had left one behind. **The suite is now proven order-independent** — run
green both on a fresh `db reset` and immediately after every HTTP suite's residue.

New: **AUTH-1** — nothing reads or writes `otp_challenges` / `totp_enrollments`; `app.requires_mfa`
gates on Supabase Auth's own `aal` claim.

## 4. Package 2 — the lifecycle branches and the trainee, over HTTP (no migration)

Every journey the previous reports listed as UNPROVEN, executed with real JWTs: the trainee's full
first morning; quotation rejected / revised / expired and both revival paths; booking approved →
issued → **reissue** → issued with the authority split proven at each step; deposit-then-balance
allocated exactly; the supplier-failure chain end to end; document expiry as a real window; the
returning customer on one 360 timeline. **57 assertions; HTTP coverage 118 → 175.**

New: **DOC-EXP-1** — `expiring_documents` works and its window is a real filter, but the
`document_expiry` notification type has **no producer**. An expiring passport tells nobody.

## 5. Package 3 — TRANS-2 and SEC-1's last table (`202607056200`)

Began with a **correction**: `202607056100` recorded that `app.record_lead_interaction` "authorizes
nothing". It does — *"the assigned handler, OR ASSIGN_LEAD, plus MFA"* — inline with
`has_permission` rather than `authorize`, which a permission-shaped detector could not see.

Chasing the rule found the larger half. `app.status_transitions`' only authorization column is
`permission_key`, applied `if not null`, and **eight `leads` rows carry NULL** — so direct DML could
walk a **colleague's** lead from `contacted` to `won` and on to `converted` with no capability check,
while every RPC refused. Reachable: canon 28 gives `employee` `VIEW_DEPARTMENT_QUEUE`.

Fixed by `app.require_lead_handler`, called from the transition trigger where the permission is null
and from a new guard on `lead_interactions`. **And the class:** a null now means *apply this table's
named fallback rule*, and a table with neither **fails closed**.

TRANS-1 investigated as the directive required: no live disagreement (ten functions vs 104 rows,
compared exhaustively), and an `event` column is **not** proven to be the right canonical home — the
inline lists carry `is_closure`, sub-status handling and sometimes a constant permission. It stays
open, narrowed. Its guard was rewritten (see §2).

**Ceilings 54/18/4 → 54/17/3, and the three are canon-34 tables: SEC-1 has no unexplained residue.**

## 6. Package 4 — SCHED-1 (`202607056300`)

Three of the four recurring jobs are scheduled; the storage executor is the fourth and has none. All
three routes — pg_cron+pg_net+**Vault (installed**, which improves the position from when pg_net was
first declined), n8n, or a scheduled Action — need **one owner-placed secret**, and choosing is a
security trade-off. `pg_net` was **not** installed to make a metric move.

What needed no decision: the gap was **silent**. `app.storage_action_backlog()` reports pending
actions, **the age of the oldest**, already-failed attempts and unresolved findings, `service_role`
only. It **calls** `claim_storage_actions` rather than restating its rules, and the test asserts the
two counts *equal* — including under RET-2's suspension exclusion, where a hand-written monitor would
most easily have drifted.

## 7. Package 5 — ATTR-1 (`202607056400`)

Found by sweeping the class: for every table `authenticated` may INSERT, which columns name an actor,
and does a trigger derive them? `archived_by`, `document_versions.uploaded_by` and
`approval_requests.requested_by` do. **`created_by` did not, on twenty tables** — so any tenant user
could create a customer, booking, invoice or payment **attributed to a colleague**. On `documents`
that column is one of `scope_isolation`'s **visibility grants**, so there it is load-bearing for
authorization.

FIN-4's ratified DERIVE-DO-NOT-VALIDATE shape, held **immutable on UPDATE** — safe only because no
function anywhere updates the column, verified against every body first.

## 8. Package 6 — ATTR-2 (`202607056500`)

Reading the five candidate columns individually rather than as a group split them three ways, and
only two were attribution defects. Derived: `subscription_payment_proofs.uploaded_by` and
`approval_requests.reviewed_by` (on UPDATE **when it changes**, so an unrelated edit to a decided
request does not re-attribute the decision). Not attribution defects: `invoices.voided_by` /
`journal_entries.voided_by` — nothing writes them and no transition rows exist, so **voiding is
unimplemented** (**VOID-1**). Structurally unfillable: `subscription_payment_proofs.reviewed_by`,
whose FK points at the tenant membership table while the reviewer is the platform (**SPP-3**).

---

## 9. Errors of mine, and what each one cost

| error | how it surfaced | correction |
|---|---|---|
| "`record_lead_interaction` authorizes nothing" — written into a migration comment, the register, the plan, the manifest and a commit message | chasing the rule into `status_transitions` | corrected in every living document; the detector that caused it widened |
| unscoped fixture cross join in `38` | a real composite FK, after another suite left an invoice behind | 40+ sites scoped; the suite made order-independent |
| a tenant slug colliding with `32_lifecycle_transition_test` | only visible in the new order-independent regime | renamed; all five scripts checked against all 62 test files |
| invented catalog values (`call`, `complaint_followup`, `service_not_delivered`, `budget`), an omitted required argument, a passport filed against a booking | first run of the new HTTP suite, 42/7 | read the catalogs and the functions; the refusals are now asserted too |
| a draft assertion written to fail ("expected to be the failing half") | review before running | discarded — a test written to fail is not a test |
| `require_lead_handler` not executable by an invoker guard | test 59 | granted to `authenticated`, as `app.authorize` already is |
| `pg_get_functiondef` on aggregates | parity assertion 6 *died* rather than failed | `prokind = 'f'`, with the distinction noted in the file |

---

## 10. Final verified state

| Axis | Value |
|---|---|
| Migrations | **154** — repository, local, Primary |
| Fingerprint | **`73f01c3ae5e56754affbee87ba20f8ff`** on all three |
| pgTAP | **62 files / 717 assertions / 0 failures** — green on a fresh `db reset` **and** with all five HTTP suites' residue present |
| End-to-end HTTP | **179/179** — storage 40 · employee 29 · branches 26 · roles 27 · lifecycle 57 |
| Migration replay | all 154 apply in order from scratch, clean |
| Smoke | `ALL CHECKS PASSED` (74 tables, 71/601 catalog, FK standard, …) |
| Guards | repository CLEAN · parity CLEAN (local proven; primary proven) |
| SEC-1 ceilings | 59/27/13 → **54/17/3**, the three INTENTIONAL by canon 34 |
| Endpoints | 73 → **74** (`storage_action_backlog`, platform-only) |

Session totals: **5 migrations**, **5 new test files** (58–62), **1 new HTTP suite**, **4 guards
corrected**, **6 defects fixed** (SEC-1 residue, TEST-1, TRANS-2, ATTR-1, ATTR-2, and SEC-1's last
table), **5 findings recorded** (AUTH-1, DOC-EXP-1, VOID-1, SPP-3, and TRANS-1 narrowed).

---

## 11. What is left, and who owns it

**Nothing executable remains in this directive's scope.** Every item below needs the owner, not more
engineering:

| id | decision required |
|---|---|
| **SCHED-1** | which route invokes the storage executor, and the one secret it needs |
| **RET-1** | the document retention period (until then: retain forever, destroy nothing) |
| **DOC-EXP-1** | who is notified of an expiring document, how far ahead, how often |
| **VOID-1** | whether invoices/journal entries can be voided at all, and by what permission |
| **AUTH-1** | implement ORVION's OTP/TOTP tables, or retire them and let Supabase Auth own factor state |
| **SPP-3** | where the platform reviewer's identity is recorded |
| **FIN-5** | which permission opens each approval type |
| **SYSADMIN-1** | whether `system_administrator` is intentionally empty, obsolete, or missing its definition |
| **TRANS-1** | whether `app.status_transitions` becomes the single runtime source, and where per-entity extras then live |
| RET-2 · ORPH-1 · LEAD-2 · PLAN-1 · BLOCKED-4/5 · CANON-26-1 · DEL-1 · PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1 | as recorded in `MASTER_GAP_REGISTER.md` |

The n8n Phase-8 workflow remains GATED on `MASTER_INTEGRATION_CATALOG.md §2/§2a`.

---

## 12. For whoever picks this up next

Read `AGENTS.md §4` and run the boot sequence — then, before proposing work, run the suite **twice**:
once after `npx supabase db reset`, and once after all five scripts in `scripts/verify_*.ps1`. The
second run is the one that finds things. That regime was introduced this session and it caught three
defects the first run could not.

Per-package detail, in order:
`sec1-residue-and-fixture-scoping-2026-08-28.md` ·
`lifecycle-branches-and-the-trainee-2026-08-28.md` ·
`lead-handler-authority-and-trans-2026-08-28.md` ·
`sched-1-and-the-silent-backlog-2026-08-28.md` ·
`created-by-and-the-attribution-class-2026-08-28.md`.
