# ORVION — WP-04-E: The Storage Executor, and the Discovery That ORVION Had No API

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: Migrations `202607055300`–`202607055400`, Edge Function `storage-executor`, and
`scripts/verify_storage_end_to_end.ps1`. Completes the byte half of WP-04-D's split, proves storage
end to end with real HTTP for the first time, and records **API-1** — every `app.*` RPC and every
`reporting` view is unreachable over HTTP.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `7b1e93a` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective

Build the storage executor WP-04-D specified but did not implement, then prove the storage path end
to end rather than at the database boundary, then run the broadest system-wide discovery pass so far.

---

## 2. Starting state, re-proven live

Nothing was taken from the previous report.

| Axis | Evidence |
|---|---|
| GitHub | identity `PlatPlusHub`; `origin/main` = `7b1e93a6e21d…` = local HEAD |
| Repository | 141 migration files, 51 test files |
| Local + Primary | 141 migrations, fingerprint `db6975b3b3f025e47bc4e270752292c3` on both |
| Primary | 74 tables, 136 `app` functions, 119 policies, 71/601 catalog, 3 cron jobs, 1 bucket, **0 objects**, 0 tenants, 0 users |
| Edge Functions | **0** |
| n8n | **0 workflows**, 2 credentials (`postgres`, Google OAuth) |

**Working tree:** two files showed as modified — content-identical, line-ending normalisation only
(`git diff --numstat` returned nothing). Untracked `.obsidian/` (editor state) has been gitignored.

**A correction to my own WP-04-D report.** It stated `pg_net` is not installed, which is true, in a
context that implied it was unavailable. It is **available** (`pg_available_extensions`,
default_version 0.20.4) and I did not check. The conclusion survives on better grounds — see §4 —
but the evidence as written was incomplete, and that is worth more to the next reader than a silent
fix.

---

## 3. API-1 — the largest gap found in the programme

**Every one of ORVION's 136 `app.*` functions is unreachable over HTTP. So are all 8 `reporting`
views.** Proven against Primary, not inferred:

```
POST /rest/v1/rpc/document_bucket                       -> 404 PGRST202
     "Searched for the function public.document_bucket ... no matches were found in the schema cache"
POST /rest/v1/rpc/document_bucket  (Content-Profile: app) -> 406 PGRST106
     "Invalid schema: app. Only the following schemas are exposed: public, graphql_public"
POST /rest/v1/tenants                                   -> 401 42501
     "permission denied for table tenants"
```

The third call is the control: the API works and the table is in PostgREST's cache, so the 404s mean
"schema not exposed", not "API down". And `public` contained exactly **one** function —
`moddatetime`, from an extension. ORVION had **zero** endpoints.

**Why no test caught it.** Every RPC test calls `app.something(...)` as a database session. That is a
real proof of the function's logic and it is not a proof that any client can reach it. The suite has
been green for the entire programme while the whole API surface was unreachable, because **SQL and
HTTP are different doors and only one was ever tried.**

**Why the fix is wrappers, not "expose the `app` schema".** Exposing `app` publishes all 136
functions at once, including every internal helper that *must* be executable by `authenticated`
because RLS policies call it — `app.has_permission`, `app.current_tenant_id`,
`app.visible_branch_ids`, `app.item_financials`. Not vulnerabilities, but it hands any authenticated
caller a permission-probing oracle and makes every internal refactor a breaking API change. A named,
minimal `public` surface is both the smaller attack surface and the stable contract.

**The safety property, and it is one word.** A wrapper written `security definer` would run as its
owner, so PostgreSQL would check EXECUTE on the inner `app.*` function against the **owner** instead
of the caller — turning every wrapper into a privilege-escalation bridge into the private schema.
`security invoker` means the wrapper adds reachability and precisely zero authority. Assertion 1 of
`52_public_api_and_executor_contract_test.sql` makes the mistake unshippable for the two wrappers
that exist and the ~130 that API-1 will add.

This migration adds **only** the two endpoints the executor cannot run without. The rest is a
specified package, not 130 wrappers written speculatively.

---

## 4. GRANT-1 — SPEC-124's class, recurring for functions

`revoke execute … from public` does not make a `public` function private here. Live evidence:

```
pg_default_acl: grantor=postgres schema=public objtype=f
  {postgres=X/postgres, anon=X/postgres, authenticated=X/postgres, service_role=X/postgres}
```

Supabase ships `alter default privileges … grant execute on functions to anon, authenticated`. Those
are **explicit per-role grants**, so revoking from the PUBLIC pseudo-role removes something that was
never there. My first version of the migration did exactly that, and test 52 failed with both
endpoints executable by `anon`.

This is **SPEC-124's defect class recurring for FUNCTIONS after SPEC-124 fixed it for TABLES**. It was
invisible until ORVION created its first `public` function — which was this migration.

Not exploitable in the moment (the wrappers are `security invoker`, so `anon` still fails the inner
EXECUTE check), but that is relying on the second lock while the first stands open, and one
`security definer` slip in any future wrapper turns it into a breach. **Fixed at the class:** the
default itself now grants nothing, so every API-1 wrapper is private on creation.

---

## 5. WP-04-E — the executor

**Chosen on one property, as WP-04-C was: the number of new secrets.**

The Supabase Edge runtime **injects `SUPABASE_SERVICE_ROLE_KEY` itself**. The credential is never
created by a human, never pasted, never stored in the repo or the database, and never passes through
an agent — it cannot leak from a place it was never put. The n8n route needs the owner to create a
service_role credential by hand (AGENTS.md §6); n8n's two existing credentials are a `postgres`
connection and a Google OAuth client, and the postgres one reaches a database that provably cannot
delete objects. Rejected for the same reason: a direct Postgres connection from the function, which
needs the database password. **One route needs zero new secrets; the other needs one that lives
somewhere forever.** Cost and "n8n already exists" did not decide it.

**It decides nothing.** Every eligibility question — retention configured, version still superseded,
`current_version_id` disagreement, tenant not restricted — is answered by `app.claim_storage_actions`
before the executor sees a row. An executor applying its own rules would be a second authorization
system outside the database, which is what canon 35 forbids and what WP-04-C rejected every
non-Supabase provider over.

**No lease, deliberately.** `app.claim_conversion_deliveries` needs one (PH8-1) because it *marks*
deliveries in flight, so a crash strands the mark. This marks nothing: read → delete → report. A
crash anywhere leaves the finding untouched and the next run retries; deleting an absent object is a
no-op. Adding a lease would introduce the stranding state PH8-1 invented the lease to escape.

**It takes no input that could name an object.** No path, tenant, bucket or finding id is read from
the request — the only object names it ever sees come back from the claim RPC. "Never construct a
path from untrusted input" is structural here, not a rule to remember. A tenant-prefix check runs
anyway, as defence against a database-side bug or a tampered row.

**Authentication, verified live on Primary:**

| Call | Result |
|---|---|
| no Authorization header | `401 UNAUTHORIZED_NO_AUTH_HEADER` (platform gateway) |
| valid **anon** JWT | `403 {"error":"forbidden"}` (the function's own check) |

The anon key is a valid project JWT, so the platform's default `verify_jwt` would have let any
visitor reach a function that destroys customer documents. The explicit service-key comparison
(length-independent) is what closes it.

---

## 6. FND-1 — a failed storage action was permanently hidden

Found by building the consumer. WP-04-D registered `failed` as *"The executor attempted the storage
action and it failed. **Stays discoverable.**"* and then wrote a resolver that sets
`resolved_at = now()` for every valid code, `failed` included. Both halves were live and contradicted
each other.

The worse half: reconciliation reopens resolved findings only for `missing_object` and
`orphan_object`; the `retention_expired` branch does not. So a retention action that failed once was
marked resolved, never reopened, never retried — the object surviving forever with nothing open to
say so. **That is PH8-1's shape, which this programme has already paid for once.**

I wrote that defect the previous day, in this package family, in the same breath as the sentence
describing the correct behaviour. It was invisible because nothing consumed the contract yet.
**Building the consumer is what exposed it** — which is the argument for building consumers.

Fixed: `failed` is now an **attempt record**, not a resolution. It increments `attempt_count`, stores
`last_error`, and leaves the finding open and claimable.

---

## 7. Storage proven end to end — 36 assertions, real bytes, real HTTP

`scripts/verify_storage_end_to_end.ps1` exercises the doors pgTAP cannot: the Storage HTTP API and
PostgREST, with real bytes, as real roles, against the local stack (Supabase's published
`iss: supabase-demo` development keys on 127.0.0.1 — no production credential is read or required).

**All 36 pass.** Upload as an authorized user; both objects land in `storage.objects`; an upload whose
path has no `document_versions` row is refused (which is what makes "a tenant cannot create an orphan"
structural); cross-tenant upload refused; owner downloads and the bytes match; another tenant cannot
download; unauthenticated cannot download; signed URL mints and serves with no auth header; another
tenant cannot mint one; reconciliation sees a bucket that actually holds objects and reports no false
positives; a **real** orphan is detected; tenant B gets no finding for tenant A's object; retention
produces exactly one expired finding; `public.claim_storage_actions` is reachable over HTTP while
`anon` and an authenticated tenant user are both refused; the executor destroys the object through the
Storage API and reports back over HTTP; the bytes are gone; the superseded metadata row is gone with
them; the finding **survives** as the audit record; a `document_archived` event records the
destruction; the **current** version's bytes are untouched; a second run claims nothing; and a
reported failure leaves the finding open with the attempt counted.

**The harness cannot tear its own fixture down, and that is the audit spine working.** `public.events`
is append-only (`app.forbid_mutation` refuses DELETE) and `events.tenant_id` references `tenants` with
ON DELETE RESTRICT — so once a fixture write emits an event, that tenant can never be deleted.
Discovered by trying. Rather than weaken an immutability guarantee to make a script tidy, the script
requires a clean database and says so.

---

## 8. System-wide discovery sweep

| Class | Result |
|---|---|
| `SECURITY DEFINER` without pinned `search_path` | 0 |
| `public` functions that are `SECURITY DEFINER` | 0 (guarded) |
| `reporting` views not `security_invoker` | 0 — all 8 correct, all granted to `authenticated`, all under RLS |
| `public` views | 0 |
| Orphan catalog values / empty catalog types | 0 / 0 |
| Permissions held by **no role** | **5** |
| Permissions referenced by **no function or policy** | **5** |
| `anon` DML / `authenticated` DELETE·TRUNCATE | 0 / 0 |

**Permissions held by no role:** `MANAGE_SUBSCRIPTION` and `REVIEW_SUBSCRIPTION_PAYMENT` are
deliberate platform authority (SPP-2) — **INTENTIONAL**. `ACCESS_API_FULL`, `ACCESS_API_READ_ONLY`
and `VIEW_ADVANCED_DASHBOARDS` are held by nobody **and** checked by nothing.

**Permissions enforced nowhere:** `MANAGE_PERMISSIONS` and `MANAGE_ROLES` **are** held by roles but
are referenced by no function and no policy — RBAC-1 established that `MANAGE_USERS` is what actually
guards role assignment. A role holding them gains nothing, which is a **misleading contract**: canon
28 implies a capability that does not exist. Whether role administration should charge `MANAGE_ROLES`
instead of `MANAGE_USERS` is a canon-vs-implementation conflict, recorded as **RBAC-2** rather than
guessed at. `ACCESS_API_*` are not dead but **premature** — they become meaningful when API-1 lands
and there is an API to gate, which is now a specified dependency.

---

## 9. Tests: added, failed first, corrected

Suite: **51 files / 585 assertions → 52 files / 600 assertions**, 0 failures. Plus 36 HTTP assertions.

| What failed | Cause | Resolution |
|---|---|---|
| `52` §2 | My `proconfig @> array['search_path=']` predicate — entries are `search_path=""` | Fixed the predicate (I had made the same mistake in a probe earlier the same session) |
| `52` §4–5 | GRANT-1 — both endpoints executable by `anon` | Fixed the **default privileges**, not the two functions (§4) |
| E2E: byte comparison ×2 | `Invoke-WebRequest` returns `.Content` as `byte[]` for `application/pdf`, so comparing to a string fails while printing the right bytes | Added `AsText` |
| E2E: teardown | Deleted `document_versions` before releasing `documents.current_version_id` — RESTRICT FK; and without `ON_ERROR_STOP` it failed silently and reported "fixture seeded" | Reordered, and made psql fail loudly |
| E2E: orphan fixture | Reused an orphan the executor had already consumed | Manufacture a fresh one the way a real one occurs |
| `38` §21 | Counted `document_superseded` **globally**, so it broke the moment anything outside the suite created a second version | Scoped to the fixture — and **all 12** global event counts in that file were scoped, since one instance is a class |

---

## 10. Environment, parity and guards — final verified state

| Axis | Value |
|---|---|
| Migrations | **143** — repository, local, Primary |
| Fingerprint | **`028708a3c36ee155e5eb932973abd5e2`** on all three |
| Tables / `app` functions / **public endpoints** / policies | 74 / 137 / **2** / 119 |
| Catalog | 71 types / 601 values |
| pg_cron jobs | 3 · **Edge Functions: 1** (`storage-executor`, ACTIVE) |
| Storage | 1 private bucket, 2 policies, 0 objects |
| `anon` default EXECUTE on new public functions | **0** |
| pgTAP | **52 files / 600 assertions / 0 failures** |
| End-to-end HTTP | **36 / 36** |
| Smoke | `ALL CHECKS PASSED (74 tables, … 71/601 catalog, FK standard, …)` |
| Guards | repository CLEAN · parity CLEAN (local proven; primary proven) |

---

## 11. Classification

**PROVEN** — storage end to end over HTTP (upload, download, cross-tenant denial, unauthenticated
denial, signed URLs, versioning, supersession); object authorization is document authorization; a
tenant cannot create an orphan; reconciliation against a populated bucket; the executor's claim
contract including RET-2 at claim time and withdrawal of a re-promoted version; byte destruction
through the supported API; audit survival; idempotency; FND-1; the Edge Function's authentication on
Primary; wrappers reachable and role-restricted.

**UNPROVEN** — the deployed Edge Function's *success* path on Primary (it needs the production
service key, which must not pass through an agent; its logic is proven locally through the identical
HTTP contract, and its authentication is proven on Primary); scheduled invocation (see BLOCKED).

**FAILED** — none outstanding. Seven first-run failures, all resolved above; none by weakening a
guard, an implementation, or a platform control.

**BLOCKED** — **SCHED-1** (nothing can invoke the executor on a schedule: `pg_cron` cannot make HTTP
calls without `pg_net`, which is deliberately not installed — an owner-configured schedule or a
client-side trigger is required) · **API-1** (the remaining ~130 endpoints — a specified package) ·
RET-1, RET-2, ORPH-1 (business) · DEL-1 (now partially closed — the executor exists; scheduling does
not) · PP-1 (architectural) · LIC-1 (external) · EVT-2 · RBAC-2 (canon conflict) · PLAN-1,
BLOCKED-4/5, CANON-26-1, `suppliers.credit_limit_amount`.

**INTENTIONAL** — `pg_net` left uninstalled (installing it would require storing a service key inside
the database and would make any compromised DEFINER function an HTTP client with platform authority);
orphan objects are never auto-destroyed (ORPH-1); `MANAGE_SUBSCRIPTION` / `REVIEW_SUBSCRIPTION_PAYMENT`
held by no role.

---

## 12. Self-correction

FND-1 was mine, written the previous day. The `search_path` predicate error was mine, made twice in
one session. Three of four POL-1 policies and the GRANT-1 omission were mine. The pattern across all
of them is the same: **defects in things nothing consumes yet are invisible.** API-1 is the largest
instance — an entire API surface that no test ever tried to open, in a repository with 600 passing
assertions. The lesson encoded this session is that a proof must use the same door the user will.

---

## 13. Next logical work

**API-1 — the client-facing endpoint surface.** Now the single largest thing between ORVION and a
usable system: the database is complete and unreachable. Scope: enumerate the client-facing `app.*`
RPCs and the `reporting` views, wrap each in `public` as `security invoker`, grant deliberately per
role, and prove each over HTTP the way `verify_storage_end_to_end.ps1` does — not only in SQL.
Non-goals: exposing the `app` schema; wrapping internal helpers; inventing endpoints for capabilities
that do not exist. Dependencies: none blocking. Decides whether `ACCESS_API_FULL` /
`ACCESS_API_READ_ONLY` gate that surface.

**Then:** SCHED-1; the customer-journey end-to-end pass over HTTP; notifications; the 74-table sweep.
