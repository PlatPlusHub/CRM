# Change Request — SPEC-133

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Seed `countries`, `nationalities` and `languages`, and resolve the nationality-vocabulary question REF-1 left open, so no employee is the person who discovers that a required reference table is empty.

---

## Business Reason

All three tables existed, were FK-referenced by four columns, and held **zero rows**. Any employee supplying a real country or nationality would have hit a foreign-key error; in practice the four columns could only ever be null.

The deferral was legitimately governed — migration `202607045300`'s header defers the seeds "until a hard requirement earns them" — but the trigger it named is the first UI, which is exactly the moment an employee would find the hole. The owner directive is explicit that no employee should be the person who discovers a reference-data gap, so the trigger is met now rather than waited for.

---

## Risks

Very low. Additive inserts on empty tables, `on conflict do nothing`, and every code already satisfies the shape CHECKs SPEC-126 added, so the seed cannot introduce a casing variant.

---

## Supersedes / Depends On

Depends on `changes/SPEC-126-*.md` (the ISO-shape CHECKs). Resolves REF-1.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607051000_seed_geo_reference_data.sql`
- `supabase/tests/18_reference_data_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-133-seed-geo-reference-data.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `supabase/migrations/202607045300_seed_currencies.sql` (its curated-set precedent is followed, not amended)

---

## Minimum Reading List

- `supabase/migrations/202607045300_seed_currencies.sql`
- `_ORVION_CANONICAL/25_catalog_registry.md` §Reference Data
- `supabase/migrations/202607042000_create_geo_reference_tables.sql`

---

## Implementation Steps

1. Verification check: `countries` has rows. If empty, seed the curated ISO 3166-1 alpha-2 set.
2. Verification check: `nationalities` has rows. If empty, seed the same codes with demonym labels.
3. Verification check: `languages` has rows. If empty, seed the ISO 639-1 set.
4. Verification check: `nationalities_code_format_chk` exists. If absent, add it now that the vocabulary is decided.
5. Verification check: `db reset` replays clean, smoke passes, suite passes, Primary agrees by fingerprint.

---

## Acceptance Criteria

- [x] `countries`, `nationalities` and `languages` are seeded (82 / 82 / 20).
- [x] Every nationality names a real country — one vocabulary, asserted not assumed.
- [x] A passenger can be given a real nationality and passport-issuing country.
- [x] A customer can be given a real preferred language.
- [x] Every seeded code is in its canonical ISO shape.
- [x] Suite 18 files / 109 tests PASS; smoke passes; repo = local = Primary (99 migrations).

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (foundation freeze gate)

Outcome: Complete

All steps applied. `db reset` 99 clean; smoke `ALL CHECKS PASSED`; `Files=18, Tests=109 … PASS`. Primary: ledger `5103449432e5fbbf39a9f5b59759a45b`, countries 82, nationalities 82, languages 20, zero orphan nationalities.

One fixture error was caught by the suite: the passenger insert omitted `first_name`/`family_name`, which are NOT NULL. Fixed rather than worked around.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (foundation freeze gate)

Verdict: Confirmed Complete

Findings: Assertion 4 is the one that keeps the vocabulary decision honest — it requires every nationality code to name a real country, which is the only thing that makes "one vocabulary" true rather than merely intended. Assertions 5 and 6 are the employee-facing proof: they insert a passenger with a real nationality and passport-issuing country, and a customer with a real language, which is precisely what was impossible before this migration. Assertion 7 re-checks ISO shape across all three tables, because a hand-written seed is the most likely place to reintroduce the casing variant SPEC-126 exists to prevent.

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

**Approval basis.** Owner directive 2026-08-21, which required REF-1 to be reviewed and seeded now rather than at the first UI.

**Scope follows precedent, not exhaustiveness.** SPEC-074 seeded 18 curated currencies rather than all 180 of ISO 4217, on the reasoning that a reference table carries what ORVION needs and grows on demand. The same judgement gives 82 countries covering Egyptian travel-agency reality — the GCC and wider MENA, the Umrah/Hajj corridor, main European/Asian/American destinations and usual source markets — rather than 249 rows transcribed by hand, which would carry real transcription risk for rows nothing yet reads. Adding a country later is one INSERT.

**The nationality vocabulary decision, which REF-1 left open.** Nationalities reuse ISO 3166-1 alpha-2 country codes with the demonym in the label, rather than a separate demonym code set. Three pieces of evidence, none of them preference:

1. `passengers` already carries both `nationality_code` and `passport_issuing_country_code`. With one vocabulary, "is this passenger travelling on their own country's passport?" is an equality test rather than a mapping lookup.
2. Every travel document that carries nationality — passports, PNRs, visa applications, IATA passenger data — expresses it as the ISO country code, so a second code set would need translating at every integration boundary.
3. One vocabulary cannot drift out of sync with itself; a parallel code set is a second home for the same fact, which `GOVERNANCE.md` §6 exists to prevent.

`nationalities.code` was deliberately left unconstrained by SPEC-126 *because* this was open. It is now constrained.

**Deliberately not a foreign key.** `nationalities.code -> countries.code` is asserted by test 18, not enforced by FK: they are peer reference tables, and an FK would impose a load order between two independent seeds for a guarantee the test already provides.
