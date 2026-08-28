# ORVION — Where the Customer Came From, and Who the Lead Goes To

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: Migrations `202607056700` and `202607056800`; tests `64_acquisition_lineage_test.sql`,
`65_eligible_lead_handler_test.sql`; the owner's BUSINESS DECISION CLOSURE audit; `GUARD-1`.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `a12ed33` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Starting state, re-proven before anything was touched

| Axis | Evidence |
|---|---|
| GitHub | `gh api` = local HEAD = `a12ed33`; tree clean |
| Repo / local / Primary | **155** migrations, fingerprint `61a213f3040452ed3ca2cf552f22a882` |
| pgTAP | **63 files / 728 assertions / 0 failures** |

The reported baseline held exactly.

---

## 2. The business-decision audit, done first because the directive puts it first

Every `BLOCKED — BUSINESS DECISION` in the register was re-read against canon, live evidence and
the accumulated owner intent. **Six resolved without asking the owner anything.** Two narrowed with
new evidence. The rest are blocked on facts that are genuinely external, and each now says exactly
which fact.

The pattern in the six is worth naming: **five of them were already answered somewhere I had not
looked.** Not by inference, not by mature-practice analogy — by a sentence in canon or a row in the
database that settled it outright.

### LEAD-2 — the answer was one heading above the value list

The register asked whether `walk_in` should join the `lead_source` catalog. canon 25:

> ## lead_source
> **Ownership: Tenant-Extendable System Catalog**
> **Default values:** …
> **Tenant additions: Allowed with admin permission.**

The ten values are *defaults*, not the closed set, and canon deliberately delegated this taxonomy to
the tenant. The implementation honours it precisely: `catalog_tenant_insert` requires
`tenant_id = current_tenant_id()` **and** `MANAGE_TENANT_SETTINGS`, and `enforce_catalog_codes`
accepts a value whose `tenant_id` is null **or** equal to the writing row's tenant.

So an agency with footfall adds its own `walk_in` today. And ORVION **should not** ship one: that
would decide a market's acquisition taxonomy on canon's behalf in the one catalog canon expressly
handed to the tenant. I had been one heading away from this answer for two sessions.

It is now proven rather than asserted — an employee refused, the owner permitted, a lead recorded
against the new value, and a second tenant unable to use it.

### RBAC-2 — the capability does not exist, so the permission gates nothing by design

`roles`, `role_permissions` and `permissions` grant `authenticated` **SELECT only**, each with a
single `cmd = SELECT` policy. A tenant cannot create a role, edit a role's permissions, or invent a
permission. `MANAGE_ROLES` and `MANAGE_PERMISSIONS` therefore do not gate a capability enforced in
the wrong place — they gate one ORVION deliberately does not offer.

The remediation the register proposed would have been actively wrong: assigning a role to a *user*
is user administration, which `MANAGE_USERS` correctly governs. Charging `MANAGE_ROLES` there would
have attached the role-administration permission to something that is not role administration — and
changed nothing, since both are held by exactly `{ceo, owner}`.

### PERM-1 — API-1 landed, so the deferred question is answerable, and the answer is no

All three permissions carry a `required_feature_code` (`api_full`, `api_read_only`,
`advanced_dashboards`), and `has_permission` already composes `plan_allows(...)`. They are plan-tier
entitlements with a working mechanism behind them.

The register said API-1 must decide whether the endpoint surface is gated by them. It must not be:
those 71 wrappers and 8 reporting views are **ORVION's own application data path** — the WeWeb
frontend calls exactly these endpoints — so gating them on `api_full` would disable the product for
every plan lacking the feature. `ACCESS_API_*` describe a third-party integration API ORVION does
not offer. Held by no role, correctly.

### TASK-3, ORPH-1

canon 26 **names** both start transitions (*"Responsible employee starts work"*, *"Work resumed on
an overdue task"*) and then lists five required events, none of them a start. Describing the
transition and declining the event is a choice on the record.

And a tenant **cannot create an orphan through the API** — proven over HTTP by *"upload with no
metadata row is REFUSED"*. So an orphan implies a platform-side failure: bytes whose metadata
transaction did not commit. That is a customer's document ORVION has lost the index to, not garbage.
Reviewed, never destroyed on sight — which is what the code already does.

### Narrowed rather than resolved

**FIN-5:** seven approval types exist; scanning every `app` function body for
`insert into public.approval_requests` returns **exactly one function**. Six types have no producer,
so deciding which permission opens a `discount_approval` means first deciding that ORVION offers
discount approval. That is a feature, not an authorization map.

**VOID-1:** `invoice_status_code` **does** contain `voided`. Canon registered the state. What is
still absent is any transition into it, any writer of the three columns, and any permission — and
whether an issued invoice should be credited rather than voided is an accounting model, which the
owner's intent does not cover.

---

## 3. Item J: the question, and the larger rule it sits inside

The directive's §8 item J asks whether reassignment rewrites acquisition attribution. Read line by
line: `app.reassign_lead` updates `assigned_user_id`, `owner_user_id`, `owner_branch_id`,
`owner_department_id`; `app.process_lead_sla` updates `assigned_user_id` and `owner_user_id`.
Neither touches lineage. That is now asserted on both paths, each with a positive control proving
the reassignment actually happened, rather than trusted.

**But the owner's rule is stronger than the question**, and the stronger half was false.

`authenticated` holds UPDATE on `public.leads`, and `scope_isolation` permits updating any lead the
caller can see — which, since canon 28 gives `employee` `VIEW_DEPARTMENT_QUEUE`, is their whole
department's pipeline. Nothing prevented:

```sql
update public.leads set attribution_click_id = <another campaign's click> where id = …;
update public.leads set lead_source_code = 'referral'                     where id = …;
```

Re-pointing a lead at a different click moves a future Google Ads conversion — and the revenue
credited with it — from one campaign to another. That is precisely the failure the owner rule names,
reachable by any employee.

**ORVION already knew the rule.** `app.capture_attribution_click`:

```sql
-- First-touch anchor: attach to the lead only if it has none yet.
update public.leads set attribution_click_id = v_click
where id = p_lead_id and attribution_click_id is null;
```

The rule lived in the RPC. Direct DML never passes through the RPC. **FIN-4 and ATTR-1's shape, on
the attribution class** — and the third time this programme has found a rule stated in a caller
rather than on the table.

### The sibling, found by asking §21's question

`offline_conversions` is the revenue end of the same chain the owner draws ("Ad → Click identifier →
… → Revenue") and carries `attribution_click_id`, `lead_id` and `marketing_campaign_id` of its own.
`authenticated` holds UPDATE; `202607056000` gave it a capability guard and nothing made the record
append-only. A ceo or owner could re-point an **already recorded** conversion. Covered in the same
migration, because filing it would have left the class half-closed for the second time in one
package.

### One rule rather than three

`app.forbid_acquisition_lineage_rewrite()` takes its lineage columns as `TG_ARGV` and applies a
single rule to each: **first touch — a lineage column may be established once, and never changed
after.** That is not a generalisation invented for elegance; it is the rule
`capture_attribution_click` already applies, stated once instead of three times. Comparison goes
through `to_jsonb` for SPEC-159-A's reason.

**No session-less exemption**, deliberately — every other derived-column guard in ORVION has one.
Here it would buy nothing: `capture_attribution_click` performs only the NULL → value transition the
guard permits and is the sole post-insert writer of `leads.attribution_click_id` in the database,
and nothing updates the other lineage columns at all. An exemption would open the one door the rule
exists to close.

---

## 4. LEAD-3: the question answered, and a defect underneath it

LEAD-3 was filed yesterday as an owner decision — *"the pool includes MANAGERS; canon 04 says
'another eligible employee' and defines neither term."*

**Asking the permission matrix instead of the word answers it.** `CLOSE_LEAD`, `CREATE_LEAD`,
`CREATE_QUOTATION` and `VIEW_DEPARTMENT_QUEUE` all resolve to the identical six roles —
branch_manager, ceo, department_manager, employee, owner, senior_employee. By ORVION's own
definition of what it takes to work a lead, a manager **is** an eligible handler. It also matches
how a small Egyptian agency runs, where the branch manager sells alongside the team. Managers stay.

Then the measurement, one handler plus a trainee plus a finance manager:

```
pass 1  -> warned
pass 2  -> reassigned
WHO NOW HOLDS THE LEAD:
    Trainee | trainee | can_close_lead = f | can_quote = f
```

The pool was never "eligible employees". It was **everyone placed in the branch and department**,
with no reference to what any of them may do. `trainee` holds two permissions in the entire system —
`VIEW_ASSIGNED_LEADS` and `VIEW_ASSIGNED_TASKS`. An SLA-overdue lead, the one case where ORVION
intervenes *because revenue is at risk*, was handed to the one role that cannot quote it, close it
or book it. `finance_manager` and `system_administrator` were equally eligible.

**SEC-1's shape, in the one place with no human in the loop:** a capability decision taken by
proximity instead of by authority.

`app.eligible_lead_handlers` now requires `CLOSE_LEAD` through an active role assignment, resolved
the way `has_permission` resolves it but for an arbitrary user, since this runs with no session. The
choice of permission narrows nothing the other three candidates would not narrow identically, which
makes it a reading of the matrix rather than a preference between readings.

When nobody qualifies, the lead **stays** and the pass returns `reassignment_blocked` — parking it
with someone who cannot act is worse than leaving it with someone who has not, and the employee and
both managers were already warned. **LEAD-4** records that nothing consumes that signal on a cron
run yet.

### The human path, settled rather than deferred

`app.reassign_lead` is deliberately untouched, and this is not a deferral. ORVION **deliberately**
supports a trainee holding an assigned lead: `require_lead_handler` admits the assigned handler
regardless of permission, and `verify_lifecycle_branches.ps1` already asserts *"a trainee CAN log an
interaction on the lead they are ASSIGNED — the handler rule, not a permission"*, alongside the
refusals that stop them opening one of their own. A supervisor naming a trainee is a deliberate act
with existing, tested meaning. The automatic path differs **because no human chose**.

---

## 5. A fixture that had to be built to fail loudly

`65_eligible_lead_handler_test`'s round robin breaks its tie on `u.id asc` with every `last_at`
null. So every excluded user in Cairo — the trainee, the finance manager, a deactivated user, and a
user whose role assignment has **expired** — is given a **lower id** than the colleague who must
win. Each exclusion is load-bearing: if any of them still qualified, the assertion names the wrong
person rather than passing quietly. That is the correction from `63_sla_escalation_test`, applied
before the fact instead of after.

---

## 6. Two guards caught me, and one did not

**`10_grant_model_test` §5 caught a real omission.** The first version of the lineage trigger had no
`revoke execute … from public`. POL-1 and GRANT-1's class — PostgreSQL's default is a grant, not a
no-op — caught by the guard written for exactly that. This is what a working guard looks like.

**`check_database_parity.ps1` did not — GUARD-1.** `apply_migration` records its **own** generated
`version` (`20260828085402`) rather than the repository's `202607056800`, so after deploying,
Primary's ledger fingerprint was `ca253f453ee5b692fd6ed9aa97ac7140` while the repository produced
`0c48b1fd30c03d2dcf3137cfb4b171f3`. I ran the parity guard with
`-PrimaryFingerprint 0c48b1fd…` — the repository's own expected value — and it reported:

> `Primary matches the repository (0c48b1fd30c03d2dcf3137cfb4b171f3)`

It was comparing the repository against itself. The mistake was caught by querying Primary's ledger
directly, not by the guard.

The limit is structural: the script reaches the local database through docker/psql and cannot reach
Primary at all, because external credentials do not pass through the agent (AGENTS.md §6). Its
header always said the value must come "from a caller that can reach it". The defect is that its
**verdict** did not repeat the caveat, and the verdict is what gets read — including by me, into
every session report. The success line now carries it, and the ledger rows were normalised so
Primary's own fingerprint independently equals the repository's.

**This is §4's own discipline turned on the verification layer.** A guard whose positive result can
be manufactured by its input proves nothing — and this is the guard I have been quoting as evidence.

---

## 7. Verification

| Axis | Value |
|---|---|
| Migrations | **157** — repository, local, Primary |
| Fingerprint | **`0c48b1fd30c03d2dcf3137cfb4b171f3`** — repository, local, **and Primary's own ledger read directly** |
| Logic hash (the four lead/lineage functions) | **`55a1f8a04b8af3c5018eddb846813a98`** identical local and Primary |
| pgTAP **Pass A** (fresh `db reset`) | **65 files / 761 assertions / 0 failures** |
| pgTAP **Pass B** (after all five HTTP suites' residue) | **65 files / 761 assertions / 0 failures** |
| End-to-end HTTP | **179/179** — storage 40 · employee 29 · branches 26 · roles 27 · lifecycle 57 |
| Smoke | `ALL CHECKS PASSED` (74 tables) |
| Guards | repository CLEAN · parity CLEAN |
| Negative proof | trigger dropped → assertions 5–8 fail, positive controls on both sides still pass |

---

## 8. Classification

**PROVEN DEFECT (fixed)** — ATTR-3: acquisition lineage was rewritable by any employee on `leads`
and by a ceo/owner on `offline_conversions`. LEAD-3's underlying defect: SLA reassignment chose by
proximity, not authority, and could hand an overdue lead to someone unable to work it.

**RESOLVED — no owner decision needed after all** — LEAD-2, LEAD-3, RBAC-2, PERM-1, TASK-3, ORPH-1.

**NARROWED** — FIN-5, VOID-1.

**MITIGATED** — GUARD-1 (the structural limit remains; the output no longer hides it).

**OPEN (engineering)** — LEAD-4: nothing consumes `reassignment_blocked` on a scheduled run.

**INTENTIONAL** — the human reassignment path; the round-robin tie-break; the absence of a
session-less exemption on the lineage guard; not shipping `walk_in` as a system default.

**STILL BLOCKED, on facts that are genuinely external** — RET-1 and RET-2 (a statutory retention
period), SCHED-1 (one owner-placed secret), SPP-3 (where platform-operator identity lives), AUTH-1
(canon 34 defines the tables; ADR-0017 gives factor state to Supabase Auth), SYSADMIN-1 (canon 28's
own text is ambiguous: *"Platform-level or tenant technical administrator depending on scope"*),
DOC-EXP-1 (recipient, lead time and repeat cadence), TRANS-1, DEL-1, EVT-2.

---

## 9. Next logical work

**DOC-EXP-1 is the largest remaining operational hole**, and it is genuinely owner-blocked: canon
registers both `passport_expiry` and `document_expiry` notification types and defines no recipient,
no lead time and no repeat rule, and a document has no assignee to inherit one from. Three sentences
from the owner close it.

Executable without any owner input: **LEAD-4**'s consumer, alongside the same silence in
`app.process_subscription_lifecycle` and `app.reconcile_document_storage` — three scheduled jobs
whose failure modes are only visible to a caller that reads their return value, and `pg_cron` reads
none of them. `app.storage_action_backlog()` is the precedent for what that surface looks like.
