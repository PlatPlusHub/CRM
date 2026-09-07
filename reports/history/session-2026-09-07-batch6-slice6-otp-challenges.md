# Batch 6 slice 6 — `otp_challenges`: the challenge its own subject could answer

Class: History (immutable)
Date: 2026-09-07
Migration: `202607061600_a_challenge_its_own_subject_could_answer.sql`
Test: `supabase/tests/106_otp_challenge_subject_authority_test.sql` — 16 assertions, ten attack classes, three declared `N/A` with reasons
Guard added: none. Two existing class guards were narrowed by the repair and re-expressed as membership rather than counts.

---

## 0. HANDOFF

- **INHERITED** — a *prediction*, not a finding: the manifest recorded `otp_challenges` as the next slice and
  said "expect to conclude correctly unguarded — it is pre-authentication". `202607061400` is where that claim
  originates. Both halves were tested rather than inherited, and the premise did not survive.
- **PROVEN** — six distinct writes by the subject of its own OTP challenge were reproduced at `aal1` against
  the live local stack BEFORE any repair: self-verification of an expired challenge, attempt-counter reset,
  expiry extension, delivery-address capture, `created_at` backdating, and forging a pre-verified row. The
  repair is verified by a 16-assertion pgTAP file, mutation-tested (re-granting the privilege fails assertions
  1-5 and 11), and re-verified through the full suite: 106 files / 1,662 assertions with Pass A = Pass B, six
  HTTP suites at 430/0, smoke green on 77 tables.
- **UNPROVEN** — nothing here is asserted without a behavioural or catalog measurement. One thing is
  deliberately recorded as a residual with an assertion that asserts the residual: `totp_enrollments` still
  permits MFA self-disable at `aal1`, and assertion 14 pins that open state rather than hiding it.
- **CHANGED** — one migration (a single `revoke`), one new pgTAP file, two existing tests updated because the
  repair narrowed their derived populations (`67_...` assertion 7, `83_...` class guard), the regenerated
  `MASTER_API_CONTRACT.md` and `ai-map.json`, and the governance set. **No function, trigger, policy, constraint
  or column was touched** — the function surface hash is byte-identical before and after.
- **DO NOT TOUCH** — `trusted_devices`' write grant. It looks like residue of the same shape and is not:
  `app.record_trusted_device` is SECURITY INVOKER and depends on it. Assertion 13 calls that RPC rather than
  reading its definition, so a family-wide revoke fails the suite instead of failing silently in production.
- **REMAINING** — `OTP-2` (security policy: MFA self-disable), `PAX-4` (engineering, now a five-table question
  rather than a twenty-table one). Neither blocks the next slice.
- **NEXT** — deploy `202607061600` to Primary (awaiting owner authorization), then Batch 6 slice 7,
  `trusted_devices`.

---

## 1. The premise was wrong, and that is the finding

This slice was commissioned with a predicted conclusion. That prediction had a provenance:
`202607061400`'s PAX-4 note asserted that "`otp_challenges` is a pre-authentication surface; a capability check
there would be a category error", and the manifest carried it forward as settled.

Measured, `anon` holds **no grant and matches no policy** on this table:

```
set local role anon; select count(*) from public.otp_challenges;
ERROR:  permission denied for table otp_challenges
```

An unauthenticated caller could never reach it. What canon 34 § 7 actually describes is a **second factor** —
presented *after* primary authentication, by a caller holding an `aal1` session and trying to reach `aal2`. The
surface is **intra-authentication**, and the distinction is the whole defect: a genuinely pre-authentication
table would be unreachable, whereas this one was reachable *and writable* by precisely the actor whose claim it
exists to adjudicate.

The category-error half of the old claim is correct — tenant RBAC is the wrong instrument here. The error was
inferring from "RBAC is the wrong guard" that **no guard was owed**.

## 2. OTP-1 — what was reproduced

All at `aal1`, as the challenged user, against their own row, before a line was written:

| attack | result |
|---|---|
| self-verify an EXPIRED unverified challenge (`status_code`, `verified_at`, `failed_attempts=0`, expiry `+100y`) | `UPDATE 1` |
| forge a fresh ALREADY-VERIFIED challenge for self | `INSERT 0 1` |
| rewrite `sent_to_email` to an attacker-controlled address | `UPDATE 1` |
| backdate `created_at` to 1999-01-01 | `UPDATE 1` |
| store `status_code='not-a-real-status'` with `failed_attempts=-999` | `INSERT 0 1` |

**What held, and is asserted as a negative control rather than assumed:** re-pointing `auth_user_id` at another
human is refused by the `WITH CHECK`; a foreign challenge is invisible to `SELECT`; an `UPDATE` aimed at one
changes nothing; there was never a `DELETE` grant. Canon 34's row-ownership model was intact throughout. What
was missing is that **ownership cannot be the authorization model for an artifact whose owner is the
adversary.**

`otp_challenges` carries only a primary key and a foreign key — no `CHECK` on `status_code`, none on
`failed_attempts`, none relating `expires_at` to `created_at`. The missing `status_code` check was measured
against its siblings before being treated as a defect: **5 of 5** public tables carrying a `status_code` column
have no such constraint (SPEC-030's plain-text convention). It is a schema-wide shape, not this table's defect,
and it is not repaired here.

**LATENT, and the word is load-bearing.** Zero functions in `app` or `public` reference this table — no issuer,
no verifier, no consumer. Nothing today reads a row to decide anything, so nothing was exploitable today. That
is what made this the cheap moment to close it, and it is also why the blast radius of the repair is provably
nil rather than merely expected to be.

## 3. The repair, and why it is a revoke

`revoke insert, update on public.otp_challenges from authenticated;`

ORVION already has exactly one mechanism for "the grants must match the writers" — `202607056100`. This is that
mechanism, unchanged, applied to one more table. No new guard, no second authorization engine, no capability
model invented for a caller who may not yet have a tenant context.

`SELECT` is deliberately retained: seeing that a code was issued to you is not authority over it, and
`owner_only` already scopes the read. The **policy is untouched**, so canon 34's stated RLS model still reads
exactly as canon specifies.

Verified consequence at the API surface: `MASTER_API_CONTRACT.md` regenerates `otp_challenges` from `SIU-` to
`S---`.

## 4. The generalisable finding is PAX-4, not the table

`202607061400` measured that **20** `authenticated`-INSERTable tables "have no trigger that calls
`app.authorize` or `app.has_permission` at all" and recorded that as twenty ungoverned writes.

The count is true. The inference is not. Re-measured against the live catalog, **15 of the 20 carry the
capability check inside the RLS policy instead of a trigger.** The clearest case is `user_permission_grants`,
which has three triggers — `derive_created_by`, `moddatetime`, `emit_permission_change` — of which **not one
authorizes**, while `scope_insert` and `scope_update` both require `app.has_permission('MANAGE_PERMISSIONS')`.
By the trigger metric it is ungoverned; in fact self-granting a permission is refused by the policy.

PAX-4 **counted enforcement sites of one kind and reported the result as governance.** That is the same shape
as GUARD-CRLF-1 (a document-size guard that measured line endings) and Check 12 (a global-date guard that
measured local civil time) — this time in a register row rather than in a guard.

The genuinely uncovered set is **five**, and each already had a disposition or a registered reason:

| table | status |
|---|---|
| `otp_challenges` | **closed here** (OTP-1) |
| `totp_enrollments` | **OTP-2**, open decision |
| `trusted_devices` | canon 34 — ownership is the model, and `58_...` tests that boundary |
| `lead_interactions` | already registered BLOCKED/business (`202607056100`) |
| `campaign_daily_metrics` | already `AUDITED` (slice 1) |

PAX-4 keeps its ID and stays open — the five-table question is real — so that the correction stays attached to
what it corrects rather than being closed and silently reopened under a new name.

## 5. Two class guards were narrowed, and both were re-expressed as membership

The repair changed derived populations in two existing tests. Both were updated to *name* what they measure
instead of counting it:

- **`67_...` assertion 7 (SEC-1b)** read `count(*) = 3`. A bare count is blind to **substitution** — one table
  leaving the uncovered set as another joins nets to zero, and the guard cannot tell that apart from nothing
  happening. It now asserts the membership: `totp_enrollments,trusted_devices`.
- **`83_...` class guard (ATTR-2)** derives every actor column on a table `authenticated` can write directly.
  `otp_challenges.auth_user_id` left that set because the join requires an INSERT or UPDATE grant. A departure
  in that direction is the guard working — the write surface narrowed.

While editing it, a small description/measurement mismatch in the same guard was corrected: its comment claimed
it matched columns foreign-keyed "to `public.users`", while the query filters on `rc.relname = 'users'` with no
namespace predicate and therefore matches `auth.users` too. The measurement is the safer of the two and is
kept; the description now says what it does.

## 6. What was deliberately not done

- **`totp_enrollments` was not swept in.** It carries OTP-1's shape and MFA self-disable at `aal1` was
  reproduced. It is not the same question: *enrolling* a factor is a legitimate user action where self-verifying
  a challenge never is, and the table holds no secret. Whether *disabling* requires a step-up is a security
  policy canon does not state, so it is registered as OTP-2 rather than decided here.
- **No `CHECK` constraints were added** to `status_code`, `failed_attempts` or `expires_at`. With the write
  grant revoked, the only remaining writer is the platform, and constraining a surface against its own trusted
  issuer is a different design question — one that belongs with the lifecycle when it is built.
- **No OTP lifecycle was implemented.** The table has no issuer or verifier. Building one would be inventing
  the authentication design, not auditing it.

## 7. Verification

| layer | result |
|---|---|
| migrations replayed (`db reset`) | 205 applied clean |
| pgTAP Pass A | 106 files / 1,662 assertions — PASS |
| pgTAP Pass B (rerun under Pass A residue) | identical — PASS |
| mutation test | re-granting the privilege fails assertions 1-5 and 11 |
| HTTP suites | 29 + 40 + 74 + 107 + 120 + 60 = **430 passed / 0 failed** |
| smoke (`verify_database.sql`) | ALL CHECKS PASSED (77 tables) |
| function surface | 277 / `8c012ce5ee5749923d94c0d54e6b867f` — **unchanged** |
| structural surface | 3,561 / `97c61119602a7353016bd4de6a1c7e80` — 3,563 minus exactly the two revoked privileges |
| repository consistency | Checks 1-25 CLEAN |

Assertion 6 (`DELETE` refused) passes with **and without** the repair, because `authenticated` never held
`DELETE`. It is recorded as a control that predates this migration rather than as evidence for it.

## 8. Primary

**Nothing was deployed.** Primary `vrvtsxexkiiiivlkdxzp` remains at 204 migrations; the repository and local
stack are at 205. The gap is `202607061600` and it is intended, not drift: deployment is an outward-facing,
hard-to-reverse action and was not authorized by this session's commission. Primary holds zero business rows,
so no data is at risk on either side of the gap, and the function surface is identical regardless.

The manifest's `Live state` line states this divergence explicitly rather than continuing to claim a parity that
no longer holds.

## 9. CI found a third instance of the same pattern, in this session's own test

`8b5f7d1` passed Repository Consistency and **failed Migration CI**: assertion 10 of the new test died
with `42501: permission denied for table otp_challenges`, having passed on the development machine
minutes earlier.

The repair was not the cause. Assertion 10 ran its anti-tautology `INSERT` as `service_role` — whose
privileges on a `public` table are granted by the **Supabase platform image**, not by anything in
`supabase/migrations`. CI pins CLI **2.109.1** (deliberately, with a stated reason in
`migration-ci.yml`); this machine runs **2.117.0**. The assertion was resting a repository invariant
on an input the repository does not govern.

That is the *third* occurrence of one shape in two sessions:

| where | claimed | actually measured |
|---|---|---|
| Check 5 (GUARD-CRLF-1) | document size | checkout line endings |
| PAX-4 | writes are ungoverned | absence of one *kind* of enforcement site |
| this file, assertion 10 | the table is still writable | a platform-managed grant that differs per CLI version |

Fixed at `208f8a2` by anchoring the control to the owner path, which still rules out both things
assertions 1-6 cannot distinguish — that the table was dropped, and that it is writable by nobody —
and depends on nothing outside this repository. **The CI pin was not bumped:** changing the
environment to suit a test is the wrong direction, and it would have converted a real finding into a
hidden one.

The generalisable rule, and the reason this section exists rather than a silent amendment: **a
repository invariant may only be anchored to state the repository itself produces.** Local agreement
is not evidence of environment-independence; here the only layer with a different environment was CI,
and it is the layer that noticed — exactly as `parity_surface.sql`'s own header records for PAR-3.

Commits: `8b5f7d1` (slice), `208f8a2` (this fix). Both CI workflows green on `208f8a2`; Migration CI
ran on both because `supabase/migrations` changed.

---

End of report.
