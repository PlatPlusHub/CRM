# ORVION — IDENT-1: A Comment Claimed the Email Was Verified, and Nothing Ever Checked

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Scope: API-3, the canon-34 Human Identity family — `activate_membership`, `my_memberships`,
`record_trusted_device`, `my_trusted_devices`, `revoke_trusted_device` — audited by capability.
Migrations `202607057800` (IDENT-1) and `202607057900` (IDENT-4). Test
`75_human_identity_family_test.sql` (24), the family's first behavioural test. 15 HTTP assertions
added to `verify_role_journeys.ps1`. IDENT-2 and IDENT-3 recorded, not fixed. Deployed to Primary,
verified, pushed.
Status: Complete.

**Branch:** `main` · **Start HEAD:** `fd05484` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Boot verification (Stage B, run before any work)

| Fact | Value | Evidence class |
|---|---|---|
| Clock | `2026-08-29 22:54 UTC` = **`2026-08-30 01:54 +0300`** | local + UTC read |
| HEAD / remote | `fd05484` = `fd05484089f31d…`, tree clean | git |
| Repository | 166 migrations, 74 tests | files |
| Primary identity | `get_project_url` → `vrvtsxexkiiiivlkdxzp` | live MCP |
| Local | reset to repository before any structure was read (PAR-1b) | `npx supabase db reset` |
| SSOT pointers | manifest ↔ `reports/README.md` agree, and both named this family next | files |

---

## 2. IDENT-1 — an unverified email was the only proof of identity

`app.activate_membership()` is how a pre-provisioned membership is **claimed**:
`app.create_tenant_user` may insert a `public.users` row with `auth_user_id` NULL — it records
`has_auth_link: false` in its own event, so the unlinked case is a first-class, intended flow — and
the invitee later links their Supabase identity to it.

The entire authorization for that claim was a string comparison, justified in the function's own
comment:

> "The caller's `auth.users` row exists only after Supabase verified this email, so the match is an
> authorization proof."

**That sentence is false against this repository's own configuration.** `supabase/config.toml` sets
`enable_confirmations = false`, so a GoTrue signup creates the `auth.users` row immediately with
`email_confirmed_at` NULL. And `email_confirmed_at` appeared **nowhere** in any migration, test or
script — the assumption had never been checked anywhere.

### Reproduced

A tenant pre-provisions its CEO (`ceo@victim.test`, unlinked, active, `ceo` role). An attacker signs
up with the same email string; their `auth.users` row has `email_confirmed_at` NULL.

```
activate_membership()      -> returned the CEO membership, claimed
users.auth_user_id         -> now the ATTACKER'S uid
current_tenant_id()        -> the victim tenant
APPROVE_FINANCE            -> true
VIEW_FINANCIAL_DOCUMENTS   -> true
MANAGE_USERS               -> true
```

Full takeover of a pre-provisioned executive account, from a signup form.

### Why the fix is in the function and not a trigger

The reflex would be a trigger on `public.users` requiring any `auth_user_id` to reference a confirmed
identity. That is the wrong layer, for two **measured** reasons:

1. **The alternate paths are already closed** — verified, not assumed. Before claiming, the attacker
   has no membership, so `app.current_tenant_id()` is null and `users`' RLS hides every row: a direct
   `UPDATE public.users SET auth_user_id = <self>` affected **0 rows**, and a direct INSERT of a
   self-provisioned membership was refused **42501**. This RPC is the only reachable path.
2. **Q2, the consumer question: 49 test files create `auth.users` rows and not one sets
   `email_confirmed_at`.** A trigger would break all 49 — and would impose an email-confirmation
   requirement on the *admin* provisioning path (`create_tenant_user` with a supplied
   `p_auth_user_id`), which rests on a different trust basis: an authenticated administrator
   vouching for a colleague, not a stranger claiming a mailbox.

The rule is a **precondition of self-claiming**, not an invariant of the column. It goes where the
self-claiming happens.

`banned_until` and `deleted_at` are checked in the same breath, and not speculatively: **a JWT issued
before a ban stays valid until it expires**, so GoTrue refusing new sessions does not stop an
already-issued token from calling this.

`email_confirmed_at` deliberately, **not** the generated `confirmed_at` — the latter is
`least(email_confirmed_at, phone_confirmed_at)`, so a phone-confirmed identity would satisfy it while
never having proven ownership of the email this claim matches on.

---

## 3. IDENT-4 — the claim matched case-insensitively; uniqueness was case-sensitive

Found by continuing after the first fix looked correct.

`activate_membership` matches `lower(u.email) = lower(v_email)`, and its comment asserted the result
was "bounded to one row per tenant by `users_tenant_email_key`". That constraint is
`UNIQUE (tenant_id, email)` — **case-sensitive**. The two disagree, so the bound does not hold.

```
tenant holds ceo@case.test AND CEO@case.test   (legal: the constraint sees two people)
activate_membership()  ->  23505 duplicate key value violates
                           unique constraint "users_tenant_auth_key"
```

The UPDATE targets both rows and tries to put one `auth_user_id` on each. The user is then
**permanently unable to onboard**, cannot fix it themselves, and sees a raw PostgreSQL error naming
neither cause nor remedy. It fails closed, so this is availability and data quality rather than a
security hole — but it is unrecoverable without an administrator editing rows by hand.

**Fixed at the constraint layer, not in the function.** Making the claim "deterministic" would paper
over the actual fault: *two rows for one human existed at all*. An email address is one identity, and
a tenant holding `ceo@x` and `CEO@x` has a duplicate person whose ambiguity leaks into every later
question — who owns this lead, whose commission is this, which one do we email. The rule is a
uniqueness invariant on data, so it belongs in a UNIQUE INDEX. The fix also moves the failure from
claim time (unrecoverable) to provisioning time (actionable, before the duplicate exists).

**Cross-path sweep, both questions.** Q1: `create_tenant_user` can no longer create a case-variant
duplicate. Q2: `users_tenant_email_key` is referenced nowhere in the repository except its own DDL
and two prose comments — grepped, not assumed — and a live check returned **zero** existing
case-variant groups, so the index cannot fail to build. The old constraint is deliberately left in
place: the new index is strictly stronger and subsumes it, and dropping a named constraint is a
consumer risk for no functional gain.

**One of the two false comments was in my own new migration** — `202607057800` inherited the
"bounded to one row per tenant" claim verbatim before I tested it. Corrected in the same package.

---

## 4. What was NOT fixed, and why

**IDENT-2 — the membership claim emits no event.** `create_tenant_user` emits `user_created` with
`has_auth_link: false`; the claim that completes that link records nothing, so there is no trace of
*which* identity claimed *which* membership *when* — for a security-critical identity binding.

Deliberately not half-built, and the obstacle is specific: `app.record_event` validates
`p_tenant_id` against `app.current_tenant_id()`, and that function is `limit 1` with **no ORDER BY**
over the caller's memberships. A claim can span several tenants at once, so emitting from inside
`activate_membership` would audit one arbitrarily-chosen tenant and silently omit the rest.
**Partial, non-deterministic auditing is worse than a recorded gap.** This wants the same single
answer as FIN-9 and FIN-11 about where side effects belong.

**IDENT-3 — `otp_challenges` and `totp_enrollments` have zero consumers.** No function, no view, no
trigger references either table (measured against `pg_proc` and `pg_views`). MFA is enforced through
the JWT `aal2` claim issued by GoTrue, not through these tables. This is **Fundamental Domain
Structure** (`AGENTS.md §3`), not a defect — recorded so the next session does not rediscover it as
alarming and delete it.

**`trusted_devices.status_code` has no CHECK and no catalog binding**, so an owner can set their own
device's status to any string by direct DML. Measured before judging: `trusted_devices` is read by
**nothing that makes an authorization decision** — only its own three RPCs. So this is not privilege
escalation today, and inventing a rule for a column with no consumer would be manufacturing policy
to produce a finding. Recorded inside IDENT-3.

---

## 5. False positives and false negatives found

- **The family's entire prior coverage was a name-existence list** in `53_api_surface_test.sql`.
  That is the CUST-2 shape exactly: a guard that asserts an endpoint EXISTS cannot see what it does,
  and a full account takeover sat behind it. **A test that passes for the wrong reason.**
- **SEC-1's "INTENTIONAL, ungoverned" classification was half right and worth correcting.**
  `trusted_devices` does carry three event triggers; what it lacks is a *capability* trigger. The
  `owner_only` policy (`auth_user_id = auth.uid()` on both USING and WITH CHECK) is genuinely sound,
  and assertions 18 and the HTTP block now prove it behaviourally rather than by quoting `pg_policies`.
- **My own "positive control" was not positive**, twice over in two sessions. Here the fixture
  inserts ran under whichever tenant user the previous assertion had left in session, so provisioning
  a `finance_manager` role demanded MFA and the *fixture* — not the code under test — decided the
  result. Fixed by clearing the JWT claims for platform-path fixture work.
- **A transient failure that was NOT a defect:** the parity guard's contract regeneration threw
  `"array_agg" is an aggregate function` when run in the same command as `npx supabase db reset` —
  the containers were still restarting. It succeeded immediately on its own. Recorded because in a
  transcript this is indistinguishable from a real failure, and only one of the two is a finding.

---

## 6. Verification

| Axis | Result | Evidence class |
|---|---|---|
| Migrations | **168** — repository, local, Primary (`202607057900`) | all three read |
| Ledger fingerprint | `8c58b302f2272ecb3182303904a5f8a4` | read independently from both |
| Function surface (235) | `39afc19646b42050942926a6fb42b57a` | read independently from both |
| Structural surface (3,346) | `4cff15e2f1264c677c9e27ebaf1d827f` | read independently from both, ten surfaces |
| pgTAP **Pass A** | **75 files / 945 assertions / 0 failures** | local, fresh reset |
| pgTAP **Pass B** | **75 files / 945 assertions / 0 failures** | local, post-HTTP residue |
| End-to-end HTTP | **282/282** across six suites (was 267) | local over the wire |
| Smoke | `ALL CHECKS PASSED (75 tables …)` | local |
| Repository guard | **CLEAN**, 12 checks | files only |
| Parity guard | **CLEAN exit 0**, all three Primary values read live | local ↔ Primary |
| API contract | 71 endpoints, **51 with HTTP evidence** — API-3 **25 → 20** | repository |
| Primary business rows | 0 users, 0 tenants | live |

Both `apply_migration` calls stamped their own versions; both ledger rows were normalised
(GUARD-1), and the fingerprint was read *after* normalisation.

---

## 7. Classification

**PROVEN DEFECT (fixed)** — **IDENT-1** (Critical: account takeover), **IDENT-4** (Medium:
unrecoverable onboarding lockout).
**OPEN (recorded, not invented into rules)** — **IDENT-2** (claim emits no event; blocked on the
same side-effect question as FIN-9/FIN-11), **IDENT-3** (`otp_challenges`/`totp_enrollments` have no
consumer; `trusted_devices.status_code` unvalidated but unread).
**UNPROVEN** — nothing new.
**BLOCKED** — unchanged; no owner decision was consumed or created.

**No business policy invented; no canon changed.**

---

## 8. Next executable step

**API-3, the tenant-administration family** — `create_tenant_user`, `assign_user_branch`,
`revoke_user_role`, `create_department`. Chosen on evidence and on this package's own findings: it is
the group that *creates* the unlinked memberships IDENT-1 exploited and that grants the roles
IDENT-1 inherited, so it is the natural continuation of the identity thread rather than a fresh
subject. `create_tenant_user` is also the path IDENT-4's new index now constrains.

**Evidence the next session must verify first:** re-read all three Primary hashes live (never pass
the repository's own values back to the guard), and `npx supabase db reset` before reading any
structure from local.

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut. **SEC-1 still awaits owner ratification**; nothing is blocked
on it.
