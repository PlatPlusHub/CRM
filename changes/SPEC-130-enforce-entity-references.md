# Change Request — SPEC-130

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Give the polymorphic `related_entity_type` / `related_entity_id` link on `tasks`, `notifications` and `approval_requests` a controlled vocabulary and real referential and tenant integrity, without abandoning the open-ended relationship canon defines.

---

## Business Reason

The pair had no vocabulary, no referential integrity and no tenant safety. Reproduced before the fix:

```
insert into tasks (..., related_entity_type, related_entity_id)
values (..., 'BoOkInG', '7777...7777');            -- ACCEPTED
select count(*) from tasks t
 where not exists (select 1 from bookings b where b.id = t.related_entity_id);   -- 1
```

So `'booking'`, `'Booking'` and `'BoOkInG'` were three different things, and the id could name a row in another tenant or no row at all. This is the same class of defect as VOCAB-1 and TENANT-1, surviving in the one place neither of those fixes could reach: SPEC-127 governs catalog-backed *code* columns, and SPEC-129 governs real *foreign keys* — a polymorphic id is neither.

---

## Risks

Low. Zero rows on all three tables. The two values ORVION's existing RPCs already write — `'lead'` (lead SLA escalation) and `'booking_item'` (finance approval) — are both in the seeded family, so no existing write path breaks; the suite confirms it.

The trigger adds one catalog lookup and one existence check per write on three tables, which is immaterial at ORVION's volumes and is skipped entirely on UPDATEs that do not touch either column.

---

## Supersedes / Depends On

Depends on `changes/SPEC-126-*.md` (catalog code format), `changes/SPEC-127-*.md` (the trigger-enforcement precedent) and `changes/SPEC-129-*.md` (tenant-qualified FKs, whose polymorphic blind spot this closes). Resolves REL-1.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050700_enforce_entity_references.sql`
- `supabase/tests/15_entity_reference_test.sql`
- `scripts/verify_database.sql` (catalog baseline 67/569 → 68/583)
- `_ORVION_CANONICAL/25_catalog_registry.md`
- `_ORVION_CANONICAL/29_relationship_map.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-130-enforce-entity-references.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `supabase/migrations/202607050400_enforce_catalog_codes_at_write.sql` (a separate mechanism for a separate column class)

---

## Minimum Reading List

- `_ORVION_CANONICAL/29_relationship_map.md` §Customer/Lead To Task
- `_ORVION_CANONICAL/25_catalog_registry.md` §document_link_target_type
- `supabase/migrations/202607042800_create_document_links_table.sql` (the typed-FK alternative)
- `supabase/migrations/202607050400_enforce_catalog_codes_at_write.sql`

---

## Implementation Steps

1. Verification check: catalog family `related_entity_type` exists. If absent, add the type and its fourteen singular values.
2. Verification check: `app.enforce_entity_reference` exists. If absent, create it — `security definer`, `search_path=''`, taking the type and id column names from `TG_ARGV`, enforcing pairing, vocabulary, existence and tenant. Revoke PUBLIC EXECUTE.
3. Verification check: `tasks_enforce_entity_reference` exists. If absent, create the three triggers.
4. Verification check: `scripts/verify_database.sql` asserts 68/583. If not, update the frozen catalog baseline.
5. Verification check: `db reset` replays clean, smoke-test passes, full suite passes, Primary agrees by ledger fingerprint.

---

## Acceptance Criteria

- [x] A mis-cased `related_entity_type` is refused.
- [x] A `related_entity_id` identifying no row is refused.
- [x] A reference to an entity in **another tenant** is refused.
- [x] A type without an id, and an id without a type, are both refused.
- [x] A task about a real same-tenant customer is accepted.
- [x] A task with no related entity at all is accepted.
- [x] Every seeded `related_entity_type` value resolves to an existing tenant-scoped table.
- [x] Smoke-test passes at the updated 68/583 baseline; suite 15 files / 75 tests PASS.
- [x] repo = local = Primary by ledger fingerprint, catalog counts equal on both.

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (foundation gate)

Outcome: Complete

Steps 1–5 applied. `db reset` 96 clean; smoke `ALL CHECKS PASSED (…68/583 catalog…)`; suite `Files=15, Tests=75 … PASS`. Primary: ledger `85e40cdba1e99c205ad9f53011b37b37`, 96 migrations, 68 types / 583 values, 3 reference triggers, and the three bad writes (mis-cased type, dangling id, unpaired type) all refused there.

Two self-inflicted errors were caught by the suite rather than shipped: the smoke-test's frozen catalog baseline still asserted 67/569 after the family was added (correctly a failure — the baseline is meant to notice catalog growth), and the test fixture used `…u1` as a UUID, which is not hexadecimal.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (foundation gate)

Verdict: Confirmed Complete

Findings: All eight assertions are behavioural. The pairing, existence and cross-tenant cases each attempt the specific bad write and require the specific SQLSTATE; the two `lives_ok` cases exist so that an over-broad trigger — one that simply refused every reference — could not pass. Assertion 8 is the one that makes the design safe rather than merely working: it re-derives `code || 's'` for every value in the family and requires the result to be a real tenant-scoped table, so a future catalog value that breaks the derivation fails in CI instead of at an employee's first write.

Independently re-verified on Primary after apply, not inferred from the local run.

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

**Approval basis.** Owner directive 2026-08-21, which required REL-1 to be implemented rather than registered and granted authority to resolve it directly where the correct design is technically determinable.

**The design decision, and why the obvious answer was rejected.** The starting assumption was the typed-FK pattern `document_links` already uses — one nullable FK column per target plus a CHECK that exactly one is set. It was rejected on evidence, not preference: `29_relationship_map.md` states the domain intent as *"Task may relate to **any** business entity via related_entity_type / related_entity_id"*. Enumerating targets as columns contradicts that intent and turns every newly relatable entity into a schema migration. Amending canon to fit an implementation preference is backwards; the shape was kept and the guarantees were added to it.

Scored against the criteria the directive listed, the enforced-polymorphic design wins on extensibility (a new target is one catalog row, not a migration), ties on referential integrity, tenant isolation, vocabulary control and auditability, and loses only on `ON DELETE` behaviour — which a trigger cannot provide.

**Why losing `ON DELETE` costs nothing here.** ORVION is archive-not-delete: no `app.*` RPC issues `DELETE` anywhere across all 96 migrations, and SPEC-124 removed `DELETE` from `authenticated` entirely. There is no path by which a referenced row can be physically removed, so the single guarantee a real foreign key would add over this trigger has no scenario in which it applies. That is an evidence-based conclusion about this system, not a general claim about triggers versus foreign keys.

**No mapping table.** The target is derived as `code || 's'`. All fourteen values were verified against `to_regclass` and for a `tenant_id` column before seeding; the trigger re-checks at run time and raises a clear error rather than silently skipping; and assertion 8 makes the rule permanent. A mapping table would have been a second place for the same fact to drift.

**Observed but not changed — `approval_requests` carries both forms.** It has `related_entity_type` / `related_entity_id` *and* typed `booking_item_id` / `document_id` foreign keys, so the same fact can be expressed two ways. Both are now individually sound, but which is authoritative is undefined. Recorded as **REL-2** rather than resolved here: deciding it means choosing which representation the approval domain should own, and that choice belongs with the approval workflow's own change, not with a fix to the polymorphic mechanism.
