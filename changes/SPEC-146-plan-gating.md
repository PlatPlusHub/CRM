# Change Request — SPEC-146

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Make canon 28's "Plan denial overrides user role permission" true, and close the last read
permissions that were enforced nowhere.

---

## Business Reason

SPEC-141 seeded the plan matrix — 66 rows straight from canon 28 and canon 17 — and **nothing read
it**. A Starter tenant whose plan excludes Booking could create bookings all day, because the only
question anyone asked was whether the *role* permitted it. PLAN-1 recorded this as data without a
gate.

Three read permissions were also still enforced nowhere: `VIEW_MARKETING_DASHBOARD`,
`VIEW_SUBSCRIPTION_STATUS`, and the `assigned` scope itself — which asked no permission at all, so
`VIEW_ASSIGNED_LEADS` and `VIEW_ASSIGNED_TASKS` did nothing.

---

## Risks

The material risk is placing the gate somewhere a caller can route around. That is why it sits inside
`app.has_permission()` and nowhere else: it is the single function every RLS policy and every
`app.authorize()` already calls, so one change covers the RPC path, the direct PostgREST read path,
the direct PostgREST write path, any future n8n call and any future UI, without those paths having to
cooperate. A check placed per-RPC, or in a wrapper the UI is trusted to call, would have left the
direct path open — the exact failure this hardening pass exists to eliminate. Test 30 attacks all
three surfaces separately for that reason.

Second risk: locking out tenants who have no subscription. Addressed by failing open on absence — see
Notes.

---

## Supersedes / Depends On

Resolves PLAN-1's enforcement half (SPEC-141 delivered the data). Settles the decision canon 35 §8
deferred to implementation. Depends on SPEC-145 (the financial trigger that test 30 uses to prove the
direct write path is gated).

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052500_plan_gating.sql`
- `supabase/tests/30_plan_gating_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-146-plan-gating.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- Subscription-*state* gating (`read_only` write restriction). Canon 35 §8 keeps that a distinct
  concern from plan gating; conflating them here would decide something canon separates.

---

## Minimum Reading List

- `_ORVION_CANONICAL/28_permissions_matrix.md` §Feature Access By Plan
- `_ORVION_CANONICAL/17_saas_plan_matrix.md` §Plan Limits
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` §8

---

## Implementation Steps

1. Add `permissions.required_feature_code`, CHECK-constrained to canon's 16 feature codes, and map
   the unambiguous permission→feature pairs.
2. Add `app.plan_allows`, `app.plan_limit`, `app.tenant_capabilities`.
3. Compose `app.plan_allows` into `app.has_permission`, after the role check.
4. Grant `VIEW_ASSIGNED_LEADS`/`VIEW_ASSIGNED_TASKS` to `trainee` (canon: "Limited"), then gate the
   `assigned` clause on those permissions.
5. Gate `marketing_campaigns` / `campaign_daily_metrics` reads on `VIEW_MARKETING_DASHBOARD`, and
   `subscriptions` reads on `VIEW_SUBSCRIPTION_STATUS`.
6. Verification check: test 30 attacks the RPC path, the direct read path and the direct write path.

---

## Acceptance Criteria

- [x] A role that grants `CREATE_BOOKING` does not grant it on a plan that excludes Booking.
- [x] The RPC path, the direct read path and the direct write path are all gated.
- [x] Ungated permissions are untouched — the plan removes only what it excludes.
- [x] Upgrading the plan restores the permission with no role or policy change.
- [x] A suspended subscription denies plan-gated permissions on any tier.
- [x] A tenant with no subscription is unrestricted.
- [x] `app.tenant_capabilities()` reports "Unlimited" as a null ceiling.
- [x] Clean `db reset` replays; full suite passes; smoke passes.
- [ ] **UNVERIFIED — Primary.** MCP disconnected, no linked project, no access token.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Final Foundation Hardening)

Outcome: Complete

Applied. `db reset` replays 114 clean; suite `Files=30, Tests=266 ... PASS`; smoke `ALL CHECKS PASSED`.

Permission coverage is **65 of 70 enforced at a real check point** — corrected from an earlier
figure of 68, which came from a coverage query that wrongly excluded plan-gated permissions from the
unenforced list. Being plan-gated only *removes* a permission; something still has to check it.

The five without a check point divide cleanly:

- `MANAGE_ROLES`, `MANAGE_PERMISSIONS` — deliberately none. `roles`, `permissions` and
  `role_permissions` grant `authenticated` **SELECT only**, so no tenant user has a writable surface
  to guard. That is stronger than a permission check, and minting an RPC to "enforce" them would
  create the surface rather than protect it.
- `ACCESS_API_FULL`, `ACCESS_API_READ_ONLY`, `VIEW_ADVANCED_DASHBOARDS` — they gate surfaces that do
  not exist yet (PostgREST access tiers; advanced reporting views). All three are plan-mapped, so
  they will deny correctly the moment a consumer appears; wiring a check to nothing would be
  ceremony.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Final Foundation Hardening)

Verdict: Confirmed Complete

Findings: assertion 1 is what makes the rest of the file evidence. It proves the *role* grants
`CREATE_BOOKING` before anything is refused — so every refusal that follows is demonstrably the plan
speaking and not a missing grant. Without it the whole file could pass against a broken role seed.

Assertion 8 is the one that shows the two axes are genuinely independent: the plan is upgraded and the
permission returns, with no edit to any role, policy or grant. Assertion 11 guards the opposite
mistake — a suspended subscription denies the plan-gated permissions and leaves the ungated ones
alone, so suspension is not a blanket lockout invented here under cover of a plan gate.

The three attack surfaces in assertions 4, 6 and 7 are not redundancy. A gate that held only in
`app.authorize` would leave direct SQL open; one that held only in a policy would leave the RPC's
`authorize` path reporting success. They are separate code paths that happen to share one function,
and the test proves the sharing is real.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state (local; Primary deployment outstanding).

---

## Notes

**Approval basis.** Owner directive 2026-08-24 (second directive) §4, which requires that
"role says YES + plan says NO = access still succeeds" must not remain true, and names the properties
the implementation must have.

**Fail-open on absence is a reading of canon, not a convenience.** Canon says plan *denial* overrides
role permission; a denial requires a plan that denies. A tenant with no subscription row has not been
sold anything and so has not been denied anything, and the same holds for a feature the matrix does
not mention. Failing closed would instead lock out every tenant the platform has not yet provisioned.
It cannot be abused: SPEC-138 gated `subscriptions` writes behind `MANAGE_SUBSCRIPTION`, which no role
holds, so a tenant cannot delete their own subscription to escape a restriction.

**Permissions deliberately left ungated by plan.** `MANAGE_BRANCHES` is *not* gated on `multi_branch`:
Starter excludes the feature but is entitled to one branch (`max_branches = 1`), so the numeric ceiling
is the correct control and the switch would have prevented a Starter tenant from creating any branch
at all. `crm`, `customers` and `basic_reporting` are enabled on every plan, so gating their permissions
would add machinery that can never fire. `automation`, `integrations`, `offline_conversion` and
`ai_dashboard` have no permission to attach to — they are RPC- and integration-driven, and inventing a
permission to hang the gate on would be fabricating canon.

**Numeric ceilings are readable but not enforced.** `app.plan_limit` and `app.tenant_capabilities`
expose them; nothing counts against them yet, because `usage_counters` is empty and counting is a
separate mechanism. The shape is deliberately additive — a future counter can enforce a ceiling without
changing the gate or the matrix.
