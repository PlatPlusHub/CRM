# Change Request — SPEC-141

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Resolve CAT-5 and CAT-6 on their merits rather than uniformly, and seed the subscription plan matrix
canon defines but the database never received.

---

## Business Reason

**CAT-5.** `booking_items.sub_status_code` is the one catalog-backed column whose governing family
depends on another column: canon 26's Sub-Status Rule gives ticket, visa and hotel separate
vocabularies keyed by `service_type_code`. SPEC-136 excluded it because a static column→family
mapping cannot express a conditional relationship, and forcing it in would have produced a trigger
that was confidently wrong. That was the right call then. What has changed is only the diagnosis: the
rule is not missing or ambiguous — `app.create_booking_item` already implements exactly this mapping,
citing canon 13. It is enforced on one path and not the other, which is precisely the defect SPEC-127
and SPEC-136 closed for every other such column.

**CAT-6.** Four columns, four different right answers:

| Column | Answer | Why |
| --- | --- | --- |
| `user_role_assignments.scope_type` | CHECK (done in SPEC-137) | became security-critical when it began deciding read authority |
| `catalog_types.ownership_type` | CHECK | platform metadata with a two-value domain; a catalog family would imply tenants may extend it |
| `feature_entitlements.feature_code` | CHECK + seed | a real controlled vocabulary canon 28 and canon 17 both define |
| `branches.branch_type`, `company_assets.asset_type` | left alone | canon gives them no vocabulary anywhere; inventing one is fabricating canon |

**The finding inside CAT-6.** `feature_entitlements` had **zero rows and no reader** — no function in
`app` or `reporting` references it. Canon 28 states "Plan denial overrides user role permission",
canon 09 and canon 17 define the matrix in full, and none of it existed. The three plans were seeded;
what each plan actually grants was not. A tenant on Starter was, as far as the database was concerned,
entitled to nothing and restricted by nothing.

---

## Risks

Low for CAT-5 and the CHECKs — all are proven behaviourally, and CAT-5's rule already ran in
production code, so the trigger cannot reject anything the RPC would have accepted.

The plan seed carries one honest imprecision, recorded rather than hidden. Canon uses three states —
Yes / No / **Limited** — and the table has two columns (`is_enabled`, `limit_value`). "Limited" is
representable as enabled-with-a-ceiling wherever canon 17 supplies the number: Automation via
`max_automations` (5/100/unlimited) and Multi Branch via `max_branches` (1/3/unlimited). For **Basic
Reporting (Starter), Integrations (Professional) and Offline Conversion (Professional)**, canon marks
"Limited" and defines no ceiling anywhere. Those three are seeded enabled and uncapped, which makes
them indistinguishable from "Yes". Setting an invented number would have been worse — it would look
authoritative. **What each of those three limits is, is an owner business decision**, and it is
flagged here rather than guessed.

---

## Supersedes / Depends On

Resolves CAT-5 and CAT-6. Depends on `202607051300_complete_catalog_enforcement.sql` (SPEC-136),
which recorded both. Raises PLAN-1 (plan gating is seeded but not enforced).

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607052000_conditional_vocabulary_and_plan_matrix.sql`
- `supabase/tests/25_conditional_vocabulary_and_plans_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/25_catalog_registry.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-141-conditional-vocabulary-and-plan-matrix.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `app.create_booking_item` — it now shares `app.sub_status_family` with the trigger, but its own
  validation is left in place: it produces a better error before the write is attempted, and both
  read the rule from the same function so they cannot drift
- Any plan-gating enforcement — see the Notes

---

## Minimum Reading List

- `_ORVION_CANONICAL/26_state_machines.md` §Sub-Status Rule
- `_ORVION_CANONICAL/28_permissions_matrix.md` §Feature Access By Plan
- `_ORVION_CANONICAL/17_saas_plan_matrix.md` §Plan Limits
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` §8 (subscription gating is a
  distinct concern, decided at implementation)

---

## Implementation Steps

1. Extract the service-type→family mapping into `app.sub_status_family` and enforce it with a trigger
   on `booking_items`, including the `is_active` rule every other catalog column obeys.
2. CHECK `catalog_types.ownership_type`.
3. CHECK `feature_entitlements.feature_code` against the canon 28 + canon 17 vocabulary.
4. Seed the matrix: 16 capability switches and 6 numeric ceilings across 3 plans.
5. Verification check: test 25 proves the mapping is genuinely conditional in both directions.

---

## Acceptance Criteria

- [x] A ticket may be `ticketed` and a hotel may not; a hotel may be `checked_in` and a ticket may not.
- [x] A service type with no sub-status family rejects any sub-status, and is valid with none.
- [x] A deactivated sub-status cannot be used.
- [x] `ownership_type` and `feature_code` reject values outside their domains.
- [x] The plan matrix is seeded — 66 rows — and matches canon 28 / canon 17.
- [x] "Unlimited" is a null ceiling, not a sentinel number.
- [x] Clean `db reset` replays; full suite passes (`Files=25, Tests=202`); smoke passes.
- [ ] **UNVERIFIED — Primary.** The `supabase-primary` MCP disconnected and requires
      re-authorization. Not applied to Primary; parity not confirmed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Outcome: Complete

Applied. `db reset` replays 108 clean; suite `Files=25, Tests=202 ... PASS`; smoke `ALL CHECKS PASSED`.

The CAT-5 assertions are deliberately written in opposing pairs — a hotel rejecting `ticketed` proves
little on its own, because a rule that rejected *everything* would also pass it. Each rejection is
paired with the acceptance that must accompany it, and then reversed, so the test can only pass if
the mapping is genuinely conditional rather than merely restrictive.

The plan matrix seed is the part a reader should look at hardest, because it converts a prose table
into data and that conversion is where meaning gets lost. Two decisions govern it: "Unlimited" and
"Custom" are both recorded as a **null** ceiling on an enabled row — the absence of a limit, not a
large number that a later reader would mistake for one — and "Limited" is expressed by the matching
numeric ceiling wherever canon 17 supplies it.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Verdict: Confirmed Complete

Findings: the fixture failed on the first run with `23502` (null `currency_code`), and that failure is
worth recording because of what it did *not* invalidate. The negative assertions had already passed —
with `23514`, the sub-status error code, not `23502`. A BEFORE trigger fires ahead of the NOT NULL
check, so those rejections were genuinely the new rule and not an artefact of a broken fixture. The
fixture was completed anyway so that no assertion depends on that reasoning holding.

CAT-6 is recorded as resolved on the strength of having *answered* each column, not having
constrained each one. Two of the five are deliberately left as free text, and that is the resolution:
canon defines no vocabulary for `branches.branch_type` (listed as "optional") or
`company_assets.asset_type`, and manufacturing one would put invented values into a catalog that the
rest of the system treats as authoritative. The owner's directive draws exactly this line — "Do not
force every field into a catalog. Do not leave an unresolved vocabulary problem." An answered
question is not an unresolved problem.

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

**Approval basis.** Owner directive 2026-08-24 §16, which required CAT-5 and CAT-6 to be investigated
fully rather than marked small, and named the exact questions answered above.

**PLAN-1 — the matrix is seeded but not enforced, deliberately.** Canon 35 principle 8 settles where
that decision belongs: subscription-state gating "is a distinct concern from tenant isolation and must
not be conflated with it … handle read-only/suspended enforcement at the service layer for MVP, or
later as a separate RLS predicate routed through the same resolution layer — **decided at
implementation, not here**." Seeding the reference data is Foundation work and is done. Choosing the
gate — an `app.plan_allows()` check inside every write RPC, an RLS predicate, or a service-layer
guard — is the deferred decision canon names, and `usage_counters` (also empty) is its counterpart for
the numeric ceilings. Recorded in the gap register so an empty enforcement path is visible rather than
implied by a now-populated table.
