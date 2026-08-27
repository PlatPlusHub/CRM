# ORVION — WP-04-D: Retention, Storage Reconciliation, and the Post-WP-04 Discovery Sweep

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: Migrations `202607054900`–`202607055200`. Completes WP-04-D on a platform fact read live
before any design — the database cannot delete a storage object — then runs the whole-system
post-WP-04 sweep and closes RBAC-1, POL-1 and CUR-1.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `ef15d2b` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective

Complete **WP-04-D** — document retention, deletion, recovery and orphan reconciliation — then run the
whole-system post-WP-04 discovery sweep the owner directive requires, classify every finding, and fix
every engineering defect that could be fixed without an unresolved business or external dependency.

---

## 2. Starting state, re-proven live before any work

Nothing was taken from the previous session's report. Every number below was re-read from the live
systems at the start of this session:

| Axis | Evidence |
|---|---|
| Repository | HEAD `ef15d2b`, clean tree, **137** migration files, **48** test files |
| Local stack | 137 migrations, fingerprint `e126307a4df8738ab20744990a3a5739` |
| Primary | 137 migrations, **same fingerprint**, 73 tables, 131 `app` functions, 117 policies, 2 cron jobs, 1 bucket, **0 storage objects** |

Repo = local = Primary. WP-04-C confirmed as the genuine latest package, so WP-04-D was confirmed —
not assumed — to be the correct next one.

---

## 3. The discovery that shaped the entire package

**The database cannot delete an object.** Two independent facts, both read live from Primary *and*
the local stack before any design was written:

1. **`storage.protect_delete()`** is installed by Supabase as a `BEFORE DELETE` trigger on **both**
   `storage.objects` and `storage.buckets`. It raises `42501` — *"Direct deletion from storage tables
   is not allowed. Use the Storage API instead."* — unless the session GUC
   `storage.allow_delete_query` is `'true'`. Its own `HINT` gives the platform's reason, which is
   identical to ours: *"This prevents accidental data loss from orphaned objects."*
2. **`pg_net` is not installed** on either environment. `pg_extension` holds `moddatetime`, `pg_cron`,
   `pg_stat_statements`, `pgcrypto`, `supabase_vault`, `uuid-ossp`, `plpgsql` — and `pgtap` locally.
   So the database cannot reach the Storage HTTP API either.

A `SECURITY DEFINER` function **could** carry `set storage.allow_delete_query = 'true'` and delete the
row anyway. It does not, for two reasons:

- It would defeat a security control the platform installed deliberately. The owner's standing
  instruction is explicit: *do not work around security controls.*
- **It would not even work.** Deleting the `storage.objects` row removes ORVION's only record of the
  object's name; the bytes in S3 survive, unnameable. We would have manufactured the exact orphan
  this package exists to detect.

**Therefore the architecture, which is a split and not a compromise:**

> **The database owns the DECISION. An external executor owns the BYTES.**

The database decides what must happen to which object, under whose authority, against which retention
rule, with a durable audit trail, and records that decision as a finding. An external actor holding
the service key (the future client, an Edge Function, or n8n) performs the byte operation through the
Storage API and reports the outcome back through one `service_role` RPC.

Physical byte deletion is classified **BLOCKED — MISSING PLATFORM CAPABILITY** (from the database's
side) as **DEL-1**. Everything not depending on it was built and tested here.

---

## 4. What was built — WP-04-D (`202607054900`, `202607055200`)

**`app.document_retention_days()` → `NULL`.** NULL means *undecided*, and undecided means *retain
forever*. This is the whole "retention cannot accidentally become delete-immediately" property,
expressed as the **default** rather than as a validation someone must remember to run. With no
decision recorded, the retention scan's `WHERE` clause is unsatisfiable and selects nothing, forever,
by construction. The Egyptian record-keeping obligation for travel documents is not in canon and is
not inventable from evidence → **RET-1, BLOCKED — BUSINESS DECISION.** When the owner decides, one
line of one migration changes and nothing else does.

**`public.document_storage_findings`** — one table, not two, because all four finding types are the
same thing: the database has determined that a named storage path needs an action only an external
actor can perform. Splitting "discrepancy" from "due action" would have produced two tables with
identical columns, two RLS policies to keep in step, and *a second sibling to forget* — the precise
class that has now bitten this programme three times. Deny-all policy (SPEC-158 shape), no
`authenticated` grant, `service_role` only.

**`app.reconcile_document_storage()`** — `service_role` only, per-tenant, **skip-never-raise** (the
WP-03 shape). Detects:
- `missing_object` — a `document_versions` row whose `storage_path` has no object;
- `orphan_object` — an object with no version row naming it;
- `retention_expired` — a **superseded** version past its window (never a current one: both
  `is_current` **and** the document's own `current_version_id` are checked, because they are two
  independent records of the same fact and a disagreement must fail closed rather than pick a winner);
- `tenant_scan_failed` — recorded when one tenant's scan raises, so the failure stays discoverable.

Idempotency is a **constraint**, not care: a unique index on
`(tenant_id, finding_type_code, coalesce(storage_path,''))` means re-running creates nothing.
Re-detection **reopens** a resolved finding — a discrepancy that is observable again was not resolved,
whatever the executor reported.

Cross-tenant safety is **structural**: the orphan scan is anchored on the tenant's own path prefix, so
tenant A's iteration cannot *see* an object under tenant B's prefix. It is not a filter that could be
forgotten; it is the only thing the query looks at.

**`app.platform_resolve_storage_finding()`** — the executor's only way back in, and the one path in
ORVION that deletes a `document_versions` row. Order is enforced by the argument: metadata is removed
only on the report that the object is *already* gone. It re-checks eligibility at the moment of
destruction rather than trusting a day-old finding.

**Scheduled** daily at `00:30`, offset from the subscription job.

---

## 5. Cross-path review — two defects found in my own design before shipping

**The FK would have blocked the purge it enables.** `document_storage_findings.document_version_id`
was written `ON DELETE RESTRICT` like every other FK in ORVION. The finding names the version the
resolver is about to destroy, so RESTRICT meant *the finding forbade the deletion it existed to
authorize*. Caught by the new test on its first run.

**The document subscription gate applies to a platform DELETE.**
`document_versions_enforce_document_subscription_gate` fires `BEFORE DELETE` and — unlike
`app.enforce_archive_authority` and `app.enforce_document_version_integrity` — has **no system-path
exemption**. WP-03 settled that deliberately: the gate is the boundary, and batch callers skip lapsed
tenants rather than the gate learning to make exceptions
(`36_subscription_gate_system_paths_test.sql`). Widening it across all three document tables to buy
one function a shortcut would undo that. So the caller does the skipping, **explicitly and before the
delete**, turning an opaque `42501` from a trigger three layers down into a message the executor can
act on. Consequence, stated and not hidden: a tenant that never returns to good standing keeps its
superseded versions forever → **RET-2, BLOCKED — BUSINESS DECISION.**

---

## 6. The smoke test overruled the pgTAP suite, and the guard won

The RESTRICT deadlock was first solved with `on delete set null (document_version_id)`. **51 test
files passed.** The smoke test then failed:

```
CHECK 7 FAILED: 1 public FK(s) deviate from the Referential Action Standard
```

The standard (canon 30) is that every public FK is `on update no action` / `on delete restrict`, with
exactly **two named exceptions**, both about `auth.users` — a table ORVION does not own.

Adding a third named exception would have been one line and would have been wrong: the standard's
value is that it has no exceptions ORVION chose for its own convenience, and the moment one package
can buy itself one, the next can too. `202607055200` therefore returns the FK to RESTRICT and has the
resolver **release the reference explicitly**, one statement, at the point of intent — strictly better
than the FK action, which nulled the column as a silent side effect of a DELETE three lines away.
`202607054900` carries a superseded-pointer comment so a future reader is not misled; migration files
are not part of any fingerprint (both guards hash `version_name` pairs only), so the pointer changes
nothing about parity.

---

## 7. The post-WP-04 discovery sweep — classes swept

Run as class-wide queries against the live database, not by reading files:

| Class | Result |
|---|---|
| `SECURITY DEFINER` without pinned `search_path` | **0** |
| `app` functions with `EXECUTE` to `PUBLIC` | **0** (after fixing one I introduced — §8) |
| Views not `security_invoker` (`public` + `reporting`) | **0** |
| Tables without RLS | **0** |
| Tables with RLS and no policy | **1 → CUR-1** |
| Policies with `using(true)` | 10 — all `SELECT` on global reference tables (`countries`, `roles`, `permissions`, `subscription_plans` …), platform-managed and read-only for `authenticated` by `10_grant_model_test` §3. **INTENTIONAL** |
| Single-column FKs to tenant-scoped tables | **0** — the 12 my first query flagged were `auth.users`, which my predicate conflated with `public.users`. Test 14 is correct; my query was not |
| Policies scoped `to public` rather than `to authenticated` | **4 → POL-1** |
| Registered event types with **no producer anywhere** | **43 → 1 fixed (RBAC-1), 42 recorded as EVT-2** |
| `anon` holding any DML | **0** |
| `authenticated` holding `DELETE`/`TRUNCATE` | **0** |

---

## 8. What the sweep found, and what was done about each

### POL-1 — four policies applied `to public` (FIXED, `202607055000`)

113 policies name `authenticated`; four named `public` — and **all four are mine**, from the last two
packages, all from the same cause: `create policy … using (…)` with the `to` clause omitted, which
PostgreSQL defaults to `PUBLIC`. `subscription_payment_proofs` showed it plainest — `scope_update`
(WP-04-B) was `to authenticated` while the two policies I added beside it in WP-04-C were not. One
table, two conventions.

**Not exploitable today** — `anon` holds no privilege on any table (SPEC-124), and a policy cannot
grant what no GRANT permits. Fixed anyway, because it is one GRANT away from mattering and because
four occurrences from one omitted clause is a **class**. Fixed with `alter policy … to authenticated`,
which changes the role list and provably nothing else — retranscribing `document_links`' ten branches
by hand for the second time in two migrations is exactly how PP-2 happened. Guarded by
`50_policy_role_scope_test.sql`, including two assertions proving the expressions survived untouched.

### RBAC-1 — ORVION audited privilege grants made through one RPC and nothing else (FIXED, `202607055100`)

Found by the event-producer sweep. `role_removed` is a registered event type with no producer. That
is not an unbuilt feature — it is an **asymmetry**, and asymmetric audit is a defect.

Live introspection then showed something worse. `user_role_assignments` carries **no triggers
whatsoever** — `pg_trigger` returns zero non-internal rows for it. So `app.assign_user_role` was never
a boundary, only a convenience. The real privilege surface is the table, whose RLS checks
`app.has_permission('MANAGE_USERS')`. Three consequences:

1. **No revocation was ever recorded.** Every grant in ORVION's history is in the audit spine and not
   one removal is. Anyone reaching an administrator's session could strip a colleague's roles —
   including the Owner's — and leave the spine looking untouched. For an event class whose severity is
   literally `security`, that is the wrong half to record.
2. **Direct-DML grants were unaudited too.** This half I did not expect: because emission lived in the
   RPC, `insert into public.user_role_assignments …` granted a role and emitted nothing. Grant
   coverage was never complete either — it covered one path.
3. **The destructive path was the cheaper one.** Granting through the RPC costs MFA, because
   `app.authorize` composes it. Revoking, or granting by DML, cost only the permission. A control
   where the safe route is harder than the dangerous one inverts the incentive it exists to create.

**Fixed on the table, not in the RPC** — the WP-00 shape. One `AFTER INSERT OR UPDATE OR DELETE`
trigger closes every path, charges `app.authorize` (MFA parity) on session-ful writes, exempts
session-less platform paths from the *check* but never from the *record*, and becomes the **single
producer** of both events — so `app.assign_user_role` **lost** its own `record_event` call rather than
gaining a second one beside the trigger's. Only a change in **effective access** is audited
(`is_active` **and** `ends_at`, since either alone ends a grant), so correcting a typo in `scope_type`
does not pollute the security stream. `app.revoke_user_role()` was added — the verb that was missing,
which is *why* revocation was only ever reachable through raw DML. It ends the assignment rather than
deleting it, because `24_assignment_history_test.sql` establishes assignment history as evidence.

### CUR-1 — `integration_cursors` grants contradict its own RLS (FIXED, `202607055100`)

The only table with RLS enabled and zero policies, and invisible to `01_rls_coverage_test.sql` because
that guard is driven by NOT NULL `tenant_id` and this table has no tenant column. **Behaviour was
already correct and fail-closed** — RLS with no policy denies every non-owner role. What was wrong is
that the privilege layer and the policy layer stated **opposite intentions about the same table**:
`authenticated` held `SELECT`, `INSERT` and `UPDATE` on a table it can touch in no way. That is a
misleading contract, and misleading contracts are how the next engineer reasons their way into a real
defect — reading the GRANT and "fixing" the missing policy to match. Both layers now say the same
thing, with an explicit deny-all stating the intent.

### EVT-2 — 42 registered event types with no producer (RECORDED, guarded)

Most are genuinely unbuilt rather than broken: the auth family (`login_*`, `otp_*`, `totp_*`,
`password_*`) is produced by Supabase Auth, which ORVION does not intercept, and `notification_*`
belongs to a package that does not exist. Building 42 producers would be inventing features, which the
directive forbids as firmly as it forbids skipping defects. Recorded as **EVT-2** and pinned by a new
assertion in `07_event_vocabulary_registry_test.sql` with `<= 42`, so the debt is **measured and can
only shrink** — a new event type registered without a producer now fails the suite. The scan is
deliberately generous (a code counts as produced if it appears anywhere in any `app` function body or
trigger definition, comments included), so it can only under-report; everything it flags is genuinely
unreachable.

---

## 9. Tests: what was added, what failed first, and what was corrected

Suite went **48 files / 541 assertions → 51 files / 585 assertions**, 0 failures.

- **`49_document_retention_test.sql`** (25) — WP-04-D. The most important assertion is #2 and it
  asserts that *nothing happens*: with retention undecided, a 400-day-old superseded version is not
  marked for destruction. Also pins `storage.protect_delete` (#12), so we learn if Supabase ever
  changes the fact this package is built on.
- **`50_policy_role_scope_test.sql`** (5) — POL-1 class guard, with a positive control (a zero drawn
  from an empty universe proves nothing) and two assertions that the `alter policy` changed the role
  list and nothing else.
- **`51_role_change_audit_test.sql`** (13) — RBAC-1 and CUR-1.
- **`07_…`** gained the EVT-2 ceiling.

**Failures on first run, and how each was resolved:**

| What failed | Cause | Resolution |
|---|---|---|
| `10_grant_model_test` §5 | I created `app.document_retention_days()` with no `revoke` — a bare `create function` leaves `proacl` null, which PostgreSQL reads as **EXECUTE to PUBLIC**. Same root cause as POL-1: *the silent default is PUBLIC, so an omitted clause is not a no-op but a grant* | Added the revoke. Two instances in one package is what makes it a class rather than a slip |
| `49` §16 (FK deadlock) | RESTRICT blocked the purge | §5 above |
| Smoke CHECK 7 | `set null` broke the Referential Action Standard | §6 above — the guard won |
| `31_access_revocation`, `37_creation_event_completeness` | `reset role` returns to postgres but leaves `request.jwt.claims` set, so `auth.uid()` still resolved and the new trigger correctly read a system-path fixture as a user write by someone lacking `MANAGE_USERS`. That hybrid **cannot occur in production** | Fixed the **fixtures**, not the rule — they now clear the claim, so they genuinely are the system path they always meant to be |
| `27_event_visibility` §4 | Asserted `count(*) from public.events = 2`; RBAC-1 made the fixture's own role grants audited | Scoped the count to `entity_type in ('booking','customer')`. The intent was never "there are exactly two events" — it is "the owner sees the booking event the employee was refused". A total that shifts whenever an unrelated write becomes audited is a brittle way to state it |
| `51` §3, §8, §10 | **My test bugs, not implementation bugs.** §8 is the instructive one: it aimed at an assignment §6 had already expired, so there was no effective-access change left and the trigger correctly did nothing | Rewrote against a **live** grant. A denial test that attacks a dead row proves only that dead rows stay dead |

---

## 10. Environment, parity and guards — final verified state

| Axis | Value |
|---|---|
| Migrations | **141** — repository, local stack and Primary |
| Ledger fingerprint | **`db6975b3b3f025e47bc4e270752292c3`** on all three |
| Latest migration | `202607055200` |
| Tables / `app` functions / policies | 74 / 136 / 119 |
| Catalog | 71 types / 601 values |
| pg_cron jobs | **3** (lead SLA, subscription lifecycle, document-storage reconciliation) |
| Storage | 1 private bucket `documents`, 2 policies, **0 objects** |
| Test suite | **51 files / 585 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED (74 tables, … 71/601 catalog, FK standard, …)` |
| Repository guard | CLEAN after governance sync |
| Database parity guard | CLEAN (local proven; primary proven) |
| n8n | 0 workflows (re-proven live this session) |

---

## 11. Classification of every material conclusion

**PROVEN** — the database cannot delete a storage object (two independent live proofs); reconciliation
detects both discrepancy directions; cross-tenant reconciliation cannot touch another tenant's
objects; one poisoned tenant does not abort the batch and its failure stays discoverable; repeated
runs are idempotent; reconciliation destroys nothing; with retention undecided nothing is ever
selected for destruction; a current version is never eligible at any age; a restricted tenant's data
is not destroyed under retention; privilege changes are audited and MFA-checked on RPC, direct DML,
INSERT, UPDATE and DELETE; `integration_cursors` is unreachable by `authenticated`.

**UNPROVEN** — end-to-end byte upload and signed-URL download; the external storage executor
(nothing implements the Storage-API side of the split yet); reconciliation against a bucket that
actually holds objects (Primary holds zero).

**FAILED** — nothing outstanding. Six first-run failures, all resolved above; none by weakening a
guard or an implementation.

**BLOCKED** — DEL-1 (missing platform capability) · RET-1, RET-2 (business) · PP-1 (architectural) ·
LIC-1 (external) · BLOCKED-4, BLOCKED-5, CANON-26-1, PLAN-1, `suppliers.credit_limit_amount`
(business) · EVT-2 (mixed: architectural for auth events, unbuilt-package for the rest).

**INTENTIONAL** — 10 `using(true)` SELECT policies on global reference tables; no UPDATE/DELETE policy
on `storage.objects`; `document_storage_findings` exempt from the subscription write gate (a platform
operational record that happens to carry a tenant_id — gating it would make a lapsed tenant's storage
discrepancies undetectable, which is backwards); `subscription_payment_proofs.scope_insert` requiring
`MANAGE_TENANT_SETTINGS` and not `MANAGE_SUBSCRIPTION`.

---

## 12. Self-correction (§19)

Three of the four POL-1 policies and the missing revoke were **mine, from the previous two packages**.
Both defects share one root cause — *PostgreSQL's silent default is `PUBLIC`, so an omitted clause is
a grant rather than a no-op* — and neither was visible in review because the omission looks like
nothing. That is why both now have guards rather than only patches.

RBAC-1 was not mine, but the sweep that found it is the one the directive has asked for since WP-04-A
and which I ran narrowly before: I had audited *sibling tables* and not *sibling directions*. Grant
and revoke are siblings. Checking that every registered event type has a producer is what surfaced it,
and that check now runs on every suite execution.

---

## 13. Governance changes

`manifest.md` (live state, last completed, next capability, open decisions) · `reports/README.md`
(latest-session pointer) · `MASTER_EXECUTION_PLAN.md` (Batch 6 extended — WP-04-D closed; RBAC-1,
CUR-1, POL-1 recorded; EVT-2 registered) · `MASTER_GAP_REGISTER.md` (DEL-1, RET-1, RET-2, EVT-2 added;
POL-1, RBAC-1, CUR-1 recorded FIXED) · `ai-map.json` · `scripts/verify_database.sql` (73→74 tables,
69/593→71/601 catalog) · `35_subscription_write_gate_test.sql` (exemption list + justification).

The master plan was **extended, never replaced**; all historical batches preserved.

---

## 14. Next logical work package

**WP-04-E — the storage executor**, or the whole-system journey pass. WP-04-D deliberately stops at
the database boundary because that is where the database's authority stops. The split it establishes
is only half-built: nothing yet performs the byte operations or calls
`app.platform_resolve_storage_finding`. Until something does, `retention_expired` findings accumulate
unresolved — which is safe (nothing is destroyed) but not finished.

Acceptance criteria for that package: an executor that authenticates as `service_role`, polls open
findings, performs exactly the byte operation each finding names through the Storage API, reports the
outcome back through the one RPC, is idempotent under retry, cannot act on a finding whose tenant is
restricted, and never touches an object outside the finding's own tenant prefix. Whether it is an Edge
Function or an n8n workflow is an engineering decision to be taken on evidence in that package.

**Also queued:** the customer-journey end-to-end pass (§9 of the directive), notifications (no
producer — the largest EVT-2 cluster), Employee/Supplier/Branch 360, and the 74-table sweep.

**Standing risk, unchanged and now more relevant:** storage exists on Primary, so an orphan is
physically possible the moment a client uploads. Reconciliation now detects one. Nothing can yet
*remove* one.
