# Change Request — SPEC-126

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Make ORVION's controlled vocabulary and its customer-identity anchor enforceable by the database rather than by convention, closing five defects that were each reproduced behaviorally before being fixed.

---

## Business Reason

Two governance properties ORVION documents were not actually enforced anywhere, and both were proven false by attempting the bad write:

**Controlled vocabulary was not controlled.** `'whatsapp'`, `'WHATSAPP'` and `' whatsapp '` could all coexist as separate `lead_source` values, and `'Direct Call'` could sit beside the canonical `'direct_call'`. A value could be created under a catalog family that does not exist. This is the "Egypt / egypt / EGYPT" failure mode, in ORVION's own catalog — the exact thing a governed vocabulary exists to prevent, and it becomes unfixable once real rows reference the variants.

**Tenant catalog extension was structurally broken.** `catalog_values` is tenant-scoped and canon 25 explicitly designs for tenant additions, but uniqueness was global on `(catalog_type_code, code)`. Tenant B could not create a code Tenant A had already used, and the resulting unique-violation error leaked the existence of another tenant's private value.

**Customer identity matching was case- and whitespace-sensitive.** Every comparison in `app.find_customer_duplicates` and `app.create_customer` was exact string equality, so `Ahmed@Gmail.com` and `ahmed@gmail.com` become two customers, `+20 123` and `+20123` become two customers, and the in-tenant primary-phone uniqueness guard is defeated by adding a single space. Customers are the CRM's identity anchor: duplicates there corrupt balances, history, attribution, and the Phase-8 conversion match rate.

---

## Risks

Low. Every constraint is additive against data that already complies — all 569 catalog values and 67 catalog types already match the code format (0 violations), all 18 currencies already match ISO 4217 shape, and `customers` / `customer_identity_signals` hold zero rows. `app.create_customer` is the **only** write path into the normalized columns (verified across all 92 migrations), so the contract has one enforcement point plus the CHECK backstop.

The one behavioural change for callers is intentional: an employee may still type `Ahmed@Gmail.com` or `+20 123 456`, and the RPC normalizes it — but a direct table write with a non-normalized value is now refused rather than silently creating a duplicate identity.

---

## Supersedes / Depends On

Depends on `changes/SPEC-124-restore-least-privilege-grant-model.md` (its no-PUBLIC-EXECUTE invariant governs the two helper functions added here). Resolves finding CAT-1 raised in `changes/SPEC-125-remediation-governance-reconciliation.md`. Supersedes nothing.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050300_canonical_input_and_catalog_governance.sql`
- `supabase/tests/11_vocabulary_and_input_governance_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-126-canonical-input-and-catalog-governance.md`

---

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607044800_customer_identity.sql` and all other historical migrations (never rewritten; the RPCs are redefined forward)
- `_ORVION_CANONICAL/25_catalog_registry.md` (the canonical code convention is unchanged — this CR enforces it, it does not redefine it)
- `scripts/verify_database.sql`

---

## Minimum Reading List

- `supabase/migrations/202607041300_create_system_catalog_tables.sql`
- `supabase/migrations/202607044800_customer_identity.sql`
- `supabase/migrations/202607043400_grant_authenticated_access_and_memberships.sql`
- `_ORVION_CANONICAL/25_catalog_registry.md`

---

## Implementation Steps

1. Verification check: `catalog_values_code_format_chk` exists. If absent, add lowercase-snake-case CHECKs to `catalog_types.code` and `catalog_values.code`.
2. Verification check: `catalog_values_catalog_type_code_fkey` exists. If absent, add the FK to `catalog_types(code)` with restrict/no-action per ADR-0007.
3. Verification check: `catalog_values_tenant_code_key` exists. If absent, drop `catalog_values_type_code_key` and create the two partial unique indexes (global and per-tenant).
4. Verification check: `currencies_code_format_chk` exists. If absent, add ISO-shape CHECKs to `countries`, `currencies`, `languages`. Leave `nationalities` unconstrained (REF-1 open).
5. Verification check: `app.normalize_email` exists. If absent, create both helpers IMMUTABLE with `search_path=''`, revoke PUBLIC EXECUTE, grant to `authenticated`.
6. Verification check: `customers_primary_email_normalized_chk` exists. If absent, add the three normalization CHECKs.
7. Verification check: `app.create_customer` source contains `app.normalize_phone`. If absent, redefine `create_customer` and `find_customer_duplicates` with normalization, body otherwise preserved verbatim.
8. Verification check: `npx supabase db reset` replays 92 migrations clean, smoke-test passes, `npx supabase test db` reports PASS.
9. Verification check: Primary reports 92 migrations and every bad write is refused there.

---

## Acceptance Criteria

- [x] Uppercase, padded and space-containing catalog codes are refused — local and Primary.
- [x] A catalog value under an unregistered family is refused by foreign key.
- [x] Two different tenants may define the same catalog code; one tenant may not define it twice; global codes stay unique.
- [x] A lowercase country code is refused.
- [x] A non-normalized customer email or a phone containing formatting characters is refused.
- [x] `app.normalize_email` / `app.normalize_phone` output always satisfies the corresponding CHECK.
- [x] Neither helper is executable by PUBLIC (SPEC-124 invariant preserved).
- [x] All 569 pre-existing catalog values survive unchanged; 0 orphan values.
- [x] `supabase/tests/11_*` passes as part of the suite; full suite 11 files / 46 tests PASS.
- [x] Smoke-test's ten invariants still pass on Primary.
- [x] Repository, local and Primary ledgers agree by md5 fingerprint.

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (health gate)

Outcome: Complete

Step results:
- Steps 1–7: Applied — migration `202607050300` authored with the full behavioural evidence in its header.
- Step 8: Applied — `db reset` 92 clean; smoke-test `ALL CHECKS PASSED`; suite `Files=11, Tests=46 … Result: PASS`.
- Step 9: Applied — `apply_migration` to Primary succeeded; ledger version reconciled from the tool's 14-digit stamp to `202607050300` per the recorded post-apply step; all five bad writes refused on Primary.

Evidence (defects reproduced BEFORE the fix, local, in a rolled-back transaction):
```
lead_source rows coexisting:  ' whatsapp ' | 'Direct Call' | 'direct_call' | 'whatsapp' | 'WHATSAPP'
unregistered family accepted: not_a_real_family | x
tenant collision:             ERROR duplicate key ... Key (catalog_type_code, code)=(lead_source, expo_booth) already exists
```

Evidence (after, Primary): all five equivalent writes raise; `app.normalize_email('  Ahmed@Gmail.COM ')` → `ahmed@gmail.com`; `app.normalize_phone(' +20 (123) 456-7890 ')` → `+201234567890`; `catalog_values` FKs = 3, partial unique indexes = 2; CHECK constraints 11 → 19; FKs 274 → 275; catalog values 569 with 0 orphans.

An in-flight regression was caught by an existing guard and fixed inside this CR: the two new helper functions inherited PostgreSQL's default PUBLIC EXECUTE, which failed `10_grant_model_test.sql` assertion 5. The migration now revokes PUBLIC as part of creating them. This is exactly what SPEC-124's guard was written to do.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (health gate)

Verdict: Confirmed Complete

Findings: Every acceptance criterion was verified by attempting the forbidden write against **live Primary** and requiring it to raise, not by checking that a constraint object exists — a constraint that exists but does not bite is the false comfort this gate was meant to eliminate. The five bad writes were executed inside a `DO` block that raises unless all five are refused; it completed silently. Normalization output was checked on real messy input. The pre-existing 569 catalog values were re-counted after the constraint additions (unchanged, 0 orphans), confirming the change was additive rather than destructive. Repository, local and Primary ledgers agree at md5 `384ec4114530c662e1fe732ec9dc2cb6` across 92 migrations.

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

**Approval basis.** Authored and executed under the owner's directive of 2026-08-21 ("Final Repository & Database Health Gate"), which granted full technical authority to remediate proven defects and explicitly required that reference/catalog data must not drift into duplicate or contradictory values, and that employee-entered data receive appropriate normalization and validation.

**Deliberately NOT decided here.**
- **Phone numbers are normalized for formatting only** — whitespace, hyphens, parentheses and dots are removed. No country code is inferred and no E.164 conversion is performed, because selecting a default country code is an open owner decision (**PH8-3**). This makes phone matching reliable today without pre-empting that decision; when PH8-3 is answered, E.164 conversion layers on top of an already-canonical value.
- **`nationalities.code` is left unconstrained**, because its vocabulary — ISO 3166-1 alpha-2 with demonym names, or a separate demonym code set — is the open question recorded in **REF-1**. Constraining it now would silently decide REF-1.
- **A tenant value may still shadow a global code.** This is harmless with the current lookup pattern (all 27 catalog lookups use `exists`, which is unaffected by a second matching row) and prohibiting it would need a trigger. Left permitted, with the tenant-scoping guard making any such row visible.

**Known remaining gap in this area — CAT-4, registered not fixed.** None of the 27 catalog lookups filters `is_active`, so deactivating a catalog value does not prevent its further use, which is the entire purpose of canon 25's deactivate-don't-delete rule. Fixing it means redefining roughly twenty RPCs, a blast radius disproportionate to a defect whose current impact is zero (0 deactivated values). Instead, test 11 carries a **tripwire**: it asserts no catalog value is deactivated, so the first deactivation fails the suite and forces the lookups to be corrected in the same change. A latent silent defect has been converted into a loud one.
