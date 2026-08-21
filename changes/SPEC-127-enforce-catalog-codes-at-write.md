# Change Request — SPEC-127

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Make ORVION's controlled vocabulary authoritative at the point of use, so a catalog-backed column on a table with no RPC write path can no longer hold an invented value, and so deactivating a catalog value actually prevents its selection for new records.

---

## Business Reason

SPEC-126 made the catalog itself canonical — codes cannot exist in casing or whitespace variants, cannot belong to an unregistered family, and are correctly tenant-scoped. It did **not** make the catalog authoritative where it is consumed.

A consuming column is plain `text` by ADR-0006, validated only by the RPC that writes it. The second health gate established that **35 of 72 tables have no RPC write path at all**, so for those tables the controlled vocabulary was enforced by nothing whatsoever. Reproduced on the local database:

```
tasks:         task_type_code='TOTALLY_MADE_UP'  task_status_code='not_a_status'  priority_code='SUPER_URGENT'   -- ACCEPTED
suppliers:     supplier_type_code='MADE_UP_SUPPLIER'  payment_term_code='pay_whenever'                          -- ACCEPTED
conversations: channel_code='carrier_pigeon'  conversation_status_code='vibing'                                 -- ACCEPTED
```

This is the same "one logical value, many spellings" failure SPEC-126 fixed, displaced from the catalog to its consumers — and it is precisely the free-text bypass an employee would hit first, because tasks, conversations, complaints, service requests and suppliers are daily operational work.

It also resolves **CAT-4**. Canon 25's deactivate-don't-delete rule only means something if a deactivated value stops being selectable for new work while historical rows keep theirs. None of the 27 catalog lookups filters `is_active`, so deactivation did nothing at all. The trigger enforces it on the correct path only: every mapped column on INSERT, and on UPDATE **only columns whose value actually changed** — so an old row referencing a since-deactivated code remains editable, which is what makes "history keeps its values" true rather than aspirational.

---

## Risks

Low, and bounded by design. The trigger is applied only to tables with **no** RPC write path — the exact set where the defect was proven and where nothing else validates — so no existing RPC behaviour changes. All target tables hold zero rows. A legitimate write with a valid catalog value is unaffected, which is asserted explicitly rather than assumed (test 12 case 4).

The one behavioural change is intended: a direct table write with an invented code now raises `23514` instead of silently succeeding.

---

## Supersedes / Depends On

Depends on `changes/SPEC-126-canonical-input-and-catalog-governance.md` (canonical catalog) and `changes/SPEC-124-restore-least-privilege-grant-model.md` (its no-PUBLIC-EXECUTE invariant governs the trigger function). Partially resolves CAT-4 raised in SPEC-126. Supersedes nothing.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050400_enforce_catalog_codes_at_write.sql`
- `supabase/tests/12_catalog_code_enforcement_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-127-enforce-catalog-codes-at-write.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `supabase/tests/11_vocabulary_and_input_governance_test.sql` (its CAT-4 tripwire stays until the remaining lookups are covered)
- `_ORVION_CANONICAL/25_catalog_registry.md` (the vocabulary is unchanged — this CR enforces it)

---

## Minimum Reading List

- `supabase/migrations/202607041300_create_system_catalog_tables.sql`
- `supabase/migrations/202607049100_event_type_registry_enforcement.sql` (the precedent: the same enforcement already exists for `events.event_type_code`)
- `reports/architecture-decision-records.md` ADR-0006
- `_ORVION_CANONICAL/25_catalog_registry.md`

---

## Implementation Steps

1. Verification check: `app.enforce_catalog_codes` exists. If absent, create it — `security definer`, `search_path=''`, reading `(column, family)` pairs from `TG_ARGV`, validating existence + `is_active` + tenant visibility, and skipping unchanged columns on UPDATE. Revoke PUBLIC EXECUTE.
2. Verification check: `tasks_enforce_catalog_codes` exists. If absent, create the twelve triggers with their explicit column→family mappings.
3. Verification check: `npx supabase db reset` replays 93 migrations clean; smoke-test passes; `npx supabase test db` reports PASS.
4. Verification check: Primary reports 93 migrations, 12 enforcement triggers, and refuses all three invented codes.

---

## Acceptance Criteria

- [x] An invented `task_type_code`, `supplier_type_code` or `channel_code` is refused — local and Primary.
- [x] A valid catalog value is still accepted (the guard does not block legitimate writes).
- [x] A deactivated value cannot be chosen for a new record.
- [x] A historical row referencing a since-deactivated value can still be edited.
- [x] That row cannot be moved onto a deactivated value.
- [x] `app.enforce_catalog_codes` is not executable by PUBLIC.
- [x] Twelve enforcement triggers exist on Primary.
- [x] Full suite 12 files / 54 tests PASS; smoke-test's ten invariants pass on Primary.
- [x] Repository, local and Primary ledgers agree by fingerprint.

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (second health gate)

Outcome: Complete

Step results:
- Step 1: Applied — one generic function; the mapping is declared at each trigger rather than in a registry table, so it is readable where it applies and there is nothing to keep in sync.
- Step 2: Applied — twelve triggers across `tasks`, `conversations`, `conversation_messages`, `complaints`, `service_requests`, `suppliers`, `marketing_campaigns`, `customer_contact_methods`, `notification_deliveries`, `financial_accounts`, `exchange_rate_adjustments`, `subscriptions`.
- Step 3: Applied — `db reset` 93 clean; smoke `ALL CHECKS PASSED`; `Files=12, Tests=54 … Result: PASS`.
- Step 4: Applied — Primary at 93 migrations, 12 enforcement triggers, all three invented codes refused, PUBLIC EXECUTE still 0.

An in-flight defect was caught by the test suite before deployment: the tenant-visibility predicate compared `uuid = text` (`42883: operator does not exist`), so every enforced write failed rather than only invalid ones. Fixed with an explicit cast, and the cast is commented because the NULL case is load-bearing — it correctly narrows platform-scoped tables with no `tenant_id` column to global catalog values only.

Ledger fingerprint, all three environments: `e98a4699c1e98ef49f99a57b1e5ef991` (93).

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (second health gate)

Verdict: Confirmed Complete

Findings: Every assertion is behavioural — the forbidden write is attempted and required to raise, on **live Primary** as well as locally. The deactivation trio is the substantive one: it proves the implemented rule is "inactive values cannot be chosen for new work, but history keeps what it already references", not the blunt "inactive is illegal" that would have made old rows uneditable and would have been a worse defect than the one being fixed. Case 4 (a valid code is accepted) is included deliberately so the suite would fail if the trigger were over-broad rather than only if it were absent.

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

**Approval basis.** Authored and executed under the owner's directive of 2026-08-21 ("Deep Foundation / CRM Coherence / Future-Readiness Audit"), which granted implementation authority for proven defects and asked explicitly whether an employee can bypass the catalog through a free-text field. They can, and this closes the path where nothing else guarded it.

**This is not a new architecture.** ADR-0006 ratified that status/type codes are plain text and named the alternative it deliberately left available: *"Hard DB enforcement (validation trigger, or constant type column + composite FK) is optional per column."* This is that sanctioned option, applied where evidence shows enforcement is absent. The precedent already exists in-repo: migration `202607049100` enforces `events.event_type_code` the same way.

**Scope boundary, and why CAT-4 is not fully closed.** The trigger covers tables with no RPC write path. Catalog columns that *are* written by an RPC remain validated only on that path — which is sufficient today, because the RPC is their only intended write path, but is not sufficient against a direct PostgREST write (**SEC-1**). Extending the trigger to those columns would close both gaps at once and is the natural CAT-4 completion step; it is not bundled here because it would change behaviour on ~25 further columns across paths this CR has gathered no evidence about, and because doing it in the same change would make a regression impossible to attribute. CAT-4 therefore stays open with its scope narrowed and the tripwire in test 11 retained.
