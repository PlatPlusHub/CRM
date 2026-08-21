# Change Request — SPEC-124

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Restore, on both environments and permanently, the end-user privilege model that migration `202607043400` decided but the hosted Supabase project silently overrode — `anon` holds no table DML, `authenticated` holds no DELETE/TRUNCATE, the ten global/reference tables stay read-only, and no `app` function is executable by PUBLIC — and add the pgTAP guard that prevents the drift recurring.

---

## Business Reason

ORVION's tenant isolation is enforced by RLS sitting on top of table privileges. Migration `202607043400` set those privileges deliberately and documented two explicit decisions in its own header: **"anon: nothing (login required)"** and **"DELETE is intentionally withheld (archive-not-delete)"**.

Live Primary contradicted both. `anon` held `SELECT/INSERT/UPDATE/DELETE` on all 72 public tables, and `authenticated` held `DELETE` and `TRUNCATE` on all 72 plus full DML on the ten platform-managed reference tables. The `authenticated` DELETE was not theoretical: the `tenant_isolation` policies are `FOR ALL`, so their `USING` clause permits DELETE of in-tenant rows — an authenticated user of any tenant could have deleted that tenant's bookings, invoices, payments, or passengers directly through PostgREST, in a system whose canonical convention is archive-not-delete.

This is the first defect class found in this repository that **`supabase db reset` plus the smoke-test structurally cannot detect**, because it exists only where the hosted default ACLs apply. Locally the grants already matched intent. Every prior verification was therefore correct and still missed it.

---

## Risks

Low, and materially lower than leaving it. The revokes remove privileges that no code path uses: no `app.*` function issues `DELETE` or `TRUNCATE` anywhere (verified against `pg_proc` on Primary), no RLS policy targets `anon`, ORVION has no anonymous flow, and Primary holds zero tenants and zero users. `service_role` and `orvion_integration` are deliberately untouched. The change is fully reversible by re-granting.

The one behavioural change is intentional and documented in Notes: `orvion_integration` loses EXECUTE on `app.record_offline_conversion`, which it held only through the implicit PUBLIC grant and could never have used successfully.

---

## Supersedes / Depends On

Depends on `changes/SPEC-052-migration-19-rls-policies.md` (RLS baseline) and migration `202607043400_grant_authenticated_access_and_memberships.sql` (the grant model this restores). Supersedes nothing. Corrects a factual claim recorded in `reports/future-backlog.md` (see SPEC-125).

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050200_restore_least_privilege_grant_model.sql`
- `supabase/tests/10_grant_model_test.sql`
- `changes/SPEC-124-restore-least-privilege-grant-model.md`

---

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607043400_grant_authenticated_access_and_memberships.sql` (historical; never rewritten)
- `scripts/verify_database.sql`
- `_ORVION_CANONICAL/manifest.md` (synchronized by SPEC-125)
- `reports/master/MASTER_GAP_REGISTER.md` (SEC-1/SEC-2 registered by SPEC-125)

---

## Minimum Reading List

- `supabase/migrations/202607043400_grant_authenticated_access_and_memberships.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `reports/master/MASTER_INTEGRATION_CATALOG.md` §0

---

## Implementation Steps

1. Verification check: `supabase/migrations/202607050200_restore_least_privilege_grant_model.sql` exists. If absent, create it revoking all table privileges in `public` from `anon` and `authenticated`, re-granting exactly the `202607043400` model, revoking the hosted default ACL for future tables via `alter default privileges for role postgres`, and revoking `execute on all functions in schema app from public`.
2. Verification check: `supabase/tests/10_grant_model_test.sql` exists. If absent, create the five-assertion catalog-driven pgTAP guard.
3. Verification check: `npx supabase db reset` replays all 91 migrations clean.
4. Verification check: the smoke-test prints `ALL CHECKS PASSED` and `npx supabase test db` reports `Result: PASS`.
5. Verification check: Primary reports 91 migrations and all five guard assertions return 0.

---

## Acceptance Criteria

- [x] `anon` holds zero SELECT/INSERT/UPDATE/DELETE/TRUNCATE on all 72 public base tables — local and Primary.
- [x] `authenticated` holds zero DELETE and zero TRUNCATE on all 72 public base tables — local and Primary.
- [x] The ten global/reference tables grant `authenticated` no INSERT and no UPDATE.
- [x] `events` and `security_events` grant `authenticated` exactly SELECT + INSERT.
- [x] No `app`-schema function grants EXECUTE to PUBLIC.
- [x] `authenticated` retains SELECT on all 72 tables (read model preserved, not over-revoked).
- [x] The four Phase-8 outbox RPCs remain EXECUTE-able by `orvion_integration`.
- [x] `supabase/tests/10_grant_model_test.sql` passes as part of the suite.
- [x] Smoke-test's ten invariants still pass on Primary after the change.

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (remediation pass)

Outcome: Complete

Step results:
- Step 1: Applied — migration authored with the full root-cause account in its header.
- Step 2: Applied — `10_grant_model_test.sql`, five assertions, catalog-driven so future tables are covered automatically.
- Step 3: Applied — `npx supabase db reset` replayed 91 migrations clean.
- Step 4: Applied — smoke-test `ALL CHECKS PASSED (72 tables, …)`; `npx supabase test db` → `Files=10, Tests=33 … Result: PASS`.
- Step 5: Applied — `apply_migration` to Primary returned success; Primary now reports 91 migrations and all five assertions return 0.

Evidence (live Primary, after):
`t1_anon_dml = 0 · t2_auth_delete = 0 · t3_global_writable = 0 · t4_audit_model = 0 · t5_public_execute = 0 · auth_select = 72 · migrations = 91`

Evidence (live Primary, before): `anon` held SELECT/INSERT/UPDATE/DELETE on all 72 tables; `pg_default_acl` showed `postgres → public → r → anon=arwdDxtm/postgres, authenticated=arwdDxtm/postgres`.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (remediation pass)

Verdict: Confirmed Complete

Findings: Every acceptance criterion was re-checked against live Primary after the apply, not against the migration text. The five guard assertions all return 0; `authenticated` still holds SELECT on 72/72 tables, confirming the revoke was not over-broad; the four outbox RPCs remain executable by `orvion_integration`; and the smoke-test's ten invariants were re-executed live and all pass. The local suite (10 files, 33 tests) passes after a clean `db reset`, and the new guard passes locally too — confirming it asserts the intended end state rather than merely describing the hosted environment.

One unanticipated result was found and investigated rather than accepted: `orvion_integration` lost EXECUTE on `app.record_offline_conversion`. Root cause: that RPC never had an explicit grant to the integration role — its reachability came solely from the implicit PUBLIC grant. It is `security invoker`, resolves tenant through `app.current_tenant_id()` (which requires `auth.uid()`) and gates on `app.authorize('MANAGE_MARKETING_CAMPAIGN')`, so `orvion_integration` could never have executed it successfully. No re-grant was made; the documentation claim is corrected by SPEC-125 instead.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state.

---

## Notes

**Approval basis.** Authored and executed under the owner's directive of 2026-08-21 ("Full Remediation, Hardening & Governance Completion Pass"), which explicitly commissioned security hardening and instructed that findings be fixed and independently verified. This CR restores an already-ratified model rather than deciding a new one, so it introduces no new architectural decision and completes autonomously per `CR_LIFECYCLE.md` §5.

**Deliberately NOT decided here (escalated as SEC-1).** Whether `authenticated` should hold direct `INSERT`/`UPDATE` on tenant tables at all is a genuine open architectural question and is not answered by this CR. RLS scopes **rows**, not **permissions**: a logged-in user with the lowest ORVION role can currently `PATCH` a booking's status, an invoice's total, or a booking item's cost straight through PostgREST, bypassing `app.authorize()`, the state machines, and event emission entirely — because every write RPC enforces RBAC inside the function, while the tables themselves remain directly writable. Migration `202607043400` chose that model consciously ("RLS scopes which rows"), so changing it is an owner decision with direct consequences for the frontend architecture, not a defect to fix unilaterally.

**`app.record_offline_conversion` and `orvion_integration`.** `manifest.md` and `MASTER_INTEGRATION_CATALOG.md` record the Phase-8 integration surface as "4 outbox RPCs + `record_offline_conversion` executable by `orvion_integration`". The second half was never true in any useful sense — see Verification Notes. The integration surface is the **four** outbox RPCs. SPEC-125 corrects the wording.
