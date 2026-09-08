# Batch 6 slice 7 — `trusted_devices`: the device record its own subject could rewrite

Class: History (immutable)
Date: 2026-09-08
Migration: `202607061700_a_device_record_its_own_subject_could_rewrite.sql`
Test: `supabase/tests/107_trusted_device_record_integrity_test.sql` — 15 assertions, ten attack classes, three declared `N/A` with reasons
Guard strengthened: `12_catalog_code_enforcement_test.sql` assertion 9 — the completeness claim of `202607051300` made executable. Two count-based assertions in `75_...` re-expressed as membership; one stale explanation in `75_...` corrected.

---

## 0. HANDOFF

- **INHERITED** — a *question*, not a finding: BOOK-3's, carried on the manifest as "does direct DML bypass
  what `app.record_trusted_device` charges?", with the accompanying prediction that the write grant is
  load-bearing and must not be revoked. Both halves were tested. The question answered **yes**; the prediction
  held, and it is why this slice's repair is the deliberate opposite of slice 6's.
- **PROVEN** — reproduced at `aal1` as `authenticated`, `current_user` asserted inside the same transaction:
  an invented `status_code` stored verbatim, and `verified_at` / `first_seen_at` / `created_at` all rewritten
  by the subject on its own row. Equally proven are the boundaries that HELD — a device cannot be planted on
  another human, another's row is invisible, a row cannot be stolen — because those are what keep this Medium
  rather than High. Verified by 15 assertions, mutation-tested (dropping both triggers fails 7 of 15), and
  re-verified through the full suite: 107 files / 1,678 assertions with Pass A = Pass B, six HTTP suites at
  430/0.
- **UNPROVEN** — nothing here is asserted without a behavioural or catalog measurement. The one inference
  drawn is explicitly labelled: assertion 15 matches function TEXT, so it includes two `emit_*` helpers that
  merely name the table in a comment. That over-inclusiveness is deliberate and stated in the assertion.
- **CHANGED** — one migration (one trigger reusing an existing function, one new trigger function), one new
  pgTAP file, one existing guard strengthened, one existing test corrected, the governance set, and a
  regenerated `ai-map.json`. `MASTER_API_CONTRACT.md` did **not** change: no grant moved.
- **DO NOT TOUCH** — `public.totp_enrollments`. It has no writer and no reader and mirrors nothing, but canon
  31 § 9 and canon 34 § 7 mandate its existence; dropping it would be a schema change with no proof of
  requirement. See § 5. Also do not revoke `trusted_devices`' write grant: `app.record_trusted_device` is
  SECURITY INVOKER and depends on it, which is why this slice's repair is doors rather than a revoke.
- **REMAINING** — nothing from this slice is unfinished, and nothing is left undocumented. Genuinely open,
  and each recorded where it belongs rather than here: `public.totp_enrollments` is canon-mandated parallel
  state with no writer (§ 5), so if enrolments are ever mirrored into it the write path and the step-up
  question arrive together. Three seeded catalog families — `confidentiality_level_code`,
  `document_link_target_type`, `verification_method` — have no consuming text column anywhere in `public`:
  dead vocabulary, minor debt, now named in `12_...` assertion 9 rather than invisible. The pre-existing debt
  list (`ai-map.json` timestamp churn, RECOVER-1's residual process gap, DISP prose residual, PAX-4's
  remaining members, CUST-6, IDENT-2, DELIV-1, GOV-20, DOC-LC-3, PH8-2, RBAC-6) is unchanged by this session.
- **NEXT** — **Batch 6 slice 8: `lead_interactions`.** Derived, not ranked: the selector has stopped
  discriminating (all 69 remaining candidates score negative, because coverage exceeds exposure everywhere,
  so its Top 12 surfaces low-coverage rows rather than high-exposure ones — read its caveat, not its order).
  `lead_interactions` is the last member of PAX-4's corrected five with real business exposure still
  `NOT-RECORDED`, and it carries both a catalog-enforced column and a derived-actor trigger, so TD-2's
  question — does the door enforce what the RPC charges — is live there.

---

## 1. What the surface actually is

Like `otp_challenges` one slice earlier, `trusted_devices` was carried as an `auth.uid()`-owned Human Identity
artifact outside tenant scope (canon 34, ADR-0017), written by three `SECURITY INVOKER` RPCs from
`202607044200`. `anon` holds **no grant at all** — proved, not assumed: both `select` and `insert` as `anon`
return `permission denied for table trusted_devices`. So this is not a pre-authentication surface either. It
is reachable at `aal1` by exactly the human the record is about.

The distinction that made this slice different from slice 6 is that here the write grant is **load-bearing**.
`app.record_trusted_device` is `SECURITY INVOKER`, so it writes with the caller's own privileges. Copying
OTP-1's revoke would have broken the sanctioned path. The repair had to be doors, not a revoke.

## 2. The first attack battery measured nothing, and that is worth recording

The first run of the attack script reported that every boundary was broken: cross-identity inserts accepted,
another human's rows updatable, `anon` able to read and write. All of it was false. The script used
`set local role authenticated` **outside a transaction block**, where it is a no-op, and `set_config(..., true)`
is likewise transaction-local — so the whole battery executed as the table owner.

Nothing was committed and no conclusion was drawn from it, because the output was read rather than the exit
code. But the failure mode is the point: a security test that silently runs as a role which bypasses the
boundary produces a **confident, detailed, entirely wrong** result, and it fails in the direction that looks
like a finding. The corrected battery wraps every attack in an explicit transaction and asserts `current_user`
as its first statement. `107_...` does the same.

This is the third distinct instance in two sessions of one shape: **a measurement anchored to something other
than what it claims to measure.** The first two were Check 5 (line endings, not document size) and PAX-4
(trigger sites, not governance).

## 3. TD-1 — a seeded vocabulary that nothing enforced

Reproduced:

```
insert into public.trusted_devices (auth_user_id, device_identifier, status_code)
values ('...a1','forged-device','SUPER_TRUSTED_FOREVER');           -- INSERT 0 1, stored verbatim
```

The family `trusted_device_status` has been **seeded and active since `202607043100`** (`expired`, `revoked`,
`trusted`, global scope). Nothing consulted it.

**The root cause is a governance shape, not a coding slip.** `202607051300` states it extended
`app.enforce_catalog_codes` "to every catalog-backed column that was previously validated only on its RPC
path", and lists what it left out under the heading **"DELIBERATE EXCLUSIONS, each with a reason rather than an
oversight"** — naming CAT-5's conditional sub-status family, the events registry, ADR-0006's free-text columns
and CAT-6's five catalog-less columns. `trusted_devices.status_code` appears in **neither** the enforced set
nor the excused set. The completeness claim lived in prose, so no guard could tell an exclusion from an
oversight, and the gap survived from 2026-08-21 to 2026-09-08.

The fix is the existing mechanism with nothing added: the same generic trigger, the same declarative
column→family mapping, the family that was already seeded. It is the row `202607051300` should have carried.

## 4. TD-2 — the door did not enforce what the RPC charges

`app.record_trusted_device` states its rule in code and in its own comment — *"The FIRST verification is the
one worth keeping; re-seeing a device is not re-verifying it"* — implemented as
`verified_at = coalesce(public.trusted_devices.verified_at, now())`. Reproduced against the subject's own row:

```
update public.trusted_devices set verified_at = <73 years hence> ...         -- UPDATE 1
update public.trusted_devices set first_seen_at='2001-01-01',
                                  created_at  ='2001-01-01' ...              -- UPDATE 1
```

SEC-1's shape on a security-domain record: a rule enforced on the RPC path only is not enforced, because
PostgREST exposes the table itself. The consequence is **anti-forensic rather than privilege-gaining** — a
subject could make a device look long-established and long-verified in the one record a security investigation
would read.

`app.forbid_trusted_device_record_rewrite` follows the ratified idiom for exactly this problem
(`app.forbid_message_rewrite`, `app.forbid_assignment_history_rewrite`): a small table-specific trigger naming
what may change — `last_seen_at`, `status_code`, `revoked_at`, and a NULL→value first setting of `verified_at`
— which is precisely what the two RPCs write. It is deliberately **not** a new generic mechanism:
`app.forbid_acquisition_lineage_rewrite` is already generic over `tg_argv`, but its error message says "is
acquisition lineage", which would be actively misleading in a device-trust investigation.

`10_grant_model_test` assertion 5 failed on the first draft — `create function` grants EXECUTE to PUBLIC by
default and `202607050200` forbids it. The guard working, and the omission was fixed rather than the guard.

## 5. Two open questions were closed by DERIVATION, not escalated

The commission's Decision Closure Protocol says to attempt derivation before asking, and that "Owner Decision"
labels a past judgement, not a prohibition on investigating. Both items here turned out to be **D5 — already
implicitly decided**.

**TD-3 — is device-trust revocation durable?** A revoked device can be re-trusted by direct DML. That looked
like an open lifecycle question until the sanctioned path was measured: `app.record_trusted_device`'s
`ON CONFLICT` clause **sets `revoked_at = null` itself**, proved behaviourally (revoke via RPC, re-record via
RPC, `revoked` → `false`). Direct DML gains nothing the RPC does not already offer. And it was decided in
writing: **SPEC-063**, a Complete, review-gated CR, specifies that the update shall *"clear `revoked_at`"*.
Re-recording re-establishes trust by design.

**OTP-2 — must disabling an MFA factor require re-authentication?** The premise was false.
`public.totp_enrollments` has **zero consumers** — no `app` or `public` function references it, no RLS policy
anywhere mentions it — and **no migration writes it**: `202607042900` creates it, `202607043300` gives it
owner-only RLS, and nothing else touches it. There is no RPC write path. Meanwhile `app.mfa_satisfied()`
consults `app.requires_mfa()` and `auth.jwt() ->> 'aal'` and nothing else, and Supabase's own factor store
`auth.mfa_factors` exists in this database. Supabase's authoritative documentation confirms AAL2 is reached by
verifying an enrolled factor held there. **A write to `public.totp_enrollments` cannot change any assurance
level or any authorization outcome.** The reproduced "MFA disabled and re-enrolled with no step-up" was a write
to a table that governs nothing.

Two stale claims in OTP-2's superseded text are corrected in the register: it proposed moving enrolment behind
"a SECURITY DEFINER RPC as `trusted_devices` did" — `trusted_devices`' three RPCs are SECURITY **INVOKER**, and
this slice kept its write grant for exactly that reason.

The residual is engineering, not policy: `public.totp_enrollments` is canon-mandated parallel state with no
writer. If ORVION ever mirrors enrolments into it, the write path must be designed then — and the step-up
question becomes real at that moment and not before.

## 6. The condition that bounds this slice, pinned executably

TD-2's residue and TD-3's non-durable revocation are both benign for **one reason only**: `trusted_devices` is
a RECORD, not a GATE. Nothing reads it to decide anything.

Rather than leave that as a sentence in a migration comment, assertion 15 names the table's entire mention set
by membership. Wiring device trust into an authorization path fails there first, and forces TD-3 to be
re-answered before the wiring lands — which is exactly when the answer becomes derivable. The assertion matches
function text and so includes two `emit_*` helpers that only name the table in a comment; that
over-inclusiveness is deliberate and stated, because a tripwire that errs toward review is the safe direction.

## 7. Prevention: the completeness claim made executable

`12_catalog_code_enforcement_test.sql` assertion 9 names every active catalog family with no
`app.enforce_catalog_codes` site — matched at the **family position** of the (column, family) argument pairs,
not by substring. Each of the fourteen survivors is excused for a measured reason: CAT-5's three conditional
sub-status families; `related_entity_type` (enforced by `app.enforce_entity_reference`); the three event
families (registry-enforced, append-only, not writable by `authenticated`); `otp_challenge_status` (unreachable
since OTP-1's revoke); three whose consuming tables are not writable by `authenticated`; and three seeded
families with **no consuming text column anywhere in `public`** — dead vocabulary, minor debt, nothing to
enforce.

Mutation-proved: dropping the new trigger makes assertion 9 fail and NAME `trusted_device_status` as the
intruder. Seeding a family and never wiring it now fails in CI instead of waiting for someone to attack the
column.

**A census attempt that failed is worth recording too.** Building this assertion, the first version matched
trigger arguments by substring and reported `trusted_devices.status_code` as *enforced* — because
`emit_creation_event(..., 'status_code')` passes the column name as an argument purely to read it for an event
payload. A second version, run against every `_code`/`_type` column, produced twenty-one apparent gaps that
were almost all foreign keys to `currencies` / `countries` / `languages`. Both drafts were the same defect this
session is about: a proxy standing in for the thing it claims to measure. The behavioural attack, not the
static census, is what established TD-1.

## 8. What was deliberately not done

- **No revoke.** `trusted_devices` keeps INSERT/SELECT/UPDATE; assertions 11–13 CALL all three RPCs rather than
  inspecting them, so a regression dressed as a fix would fail.
- **No status-transition machine.** There is no `trusted_device` entry in `app.status_transitions` and canon
  defines no device-trust lifecycle. Inventing one would be inventing policy.
- **No new generic immutability mechanism.** The repository idiom is table-specific triggers with accurate
  messages; a new generic one would have been symmetry, not need.
- **`public.totp_enrollments` not dropped**, despite having no reader and no writer. Canon mandates it.
- **No schema change of any kind.** No column, constraint, policy or grant was touched.

## 9. Verification

| Layer | Result |
|---|---|
| pgTAP, this file | 15/15 |
| Mutation (both triggers dropped) | 7 of 15 fail — exactly the assertions the repair owns |
| Mutation (catalog trigger dropped, test 12) | assertion 9 fails and names `trusted_device_status` |
| Full suite, Pass A | 107 files / 1,678 assertions PASS |
| Full suite, Pass B (no reset) | 107 files / 1,678 assertions PASS — identical |
| HTTP, six scripts | 29 + 40 + 74 + 107 + 120 + 60 = **430 passed, 0 failed** |
| `check_repository_consistency.ps1` | Checks 1–25 |
| `check_database_parity.ps1` | ledger, function surface and structural surface |

## 10. Primary

`202607061700` deployed to Primary `vrvtsxexkiiiivlkdxzp` (the only permitted target). The MCP stamped the
ledger row `20260908023950`; normalised to `202607061700` to match the repository, as in slice 6.

All three surfaces read **live from Primary**, and all three identical to local:

| Surface | Value |
|---|---|
| Ledger | `206\|66aaf752f8c9ff85174fa535f515a962` |
| Function surface | `4e2b0921904eea591fa7e3081535f4f3\|278` |
| Structural surface (`_combined`) | `90f5901910b7a9dd448ee8fd6355c4de` / 3,564 objects |

3,564 = 3,561 + one function + two triggers. Every one of the ten sub-surfaces matched individually, so the
combined agreement is not hiding a compensating pair.

End of Document.
