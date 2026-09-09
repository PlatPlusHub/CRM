# Session report — Batch 6 Slice 11 (`customers`)

Date: 2026-09-09
Class: **Batch 6 surface audit / integrity repair**

## 0. HANDOFF

- **INHERITED** — Primary access restored after the bootstrap interruption; Slice 10 (invoices) complete; Slice 12 is out of scope.
- **PROVEN** — Primary project ref, 210-migration ledger, function surface and ten-surface structural parity were read live; local reset, smoke, pgTAP, HTTP suites and concurrency proof passed.
- **UNPROVEN** — No customer business rows were present on Primary, so production-row distribution was not inferred from fixtures.
- **CHANGED** — customers_slice11_integrity repairs merge re-pointing, archived-target rejection, mixed credit/update authority, archive metadata/insert enforcement and threshold concurrency; test 111 and the concurrency verifier were added.
- **REMAINING** — No open engineering finding on customers; Batch 6 remains incomplete at 12/77 surfaces.
- **DO NOT TOUCH** — Secondary project; CUST-3 business policy; Slice 12; the n8n workflow.
- **NEXT** — Stop after this slice. A later session may use the selector's next ranked surface.

## Findings and method

The planned discriminating, mutation, concurrency, incidental-defense and mechanism-substitution proofs were completed. The first merge reproduction failed because `app.guard_invoice_integrity` treated the SECURITY DEFINER re-point as an external identity rewrite; the repair exempts only the trusted `postgres` execution path, while direct authenticated invoice identity DML still refuses. A second discriminating merge proved an archived target was accepted; the merge now rejects it. A finance manager could combine a credit-limit write with an unrelated customer rewrite; the update guard now charges each changed field family, so a mixed statement requires both permissions. Two overlapping invoice updates crossed one customer ceiling with no warning event; locking the customer row before aggregation reduces this to one event. Archived metadata-only edits and archived inserts were tested directly, and the shared archive guard now freezes metadata and covers INSERT.

The mechanism-substitution proof used the existing invoice-integrity test's savepoint mutation: dropping the trigger allowed the intended direct-DML path to be exercised and the authenticated identity rewrite remained refused only when the guard was present. The customer suite also removed incidental constraints where applicable and verified the resulting refusal came from the intended authority or lifecycle guard. Numeric boundary probes covered zero, negative, NaN and infinity; tenant crossing, replay/reverse merge, RLS and all dependent customer references were exercised.

## Verification

- `npx supabase db reset --local` — 210 migrations applied.
- `supabase/tests/111_customer_surface_test.sql` — 45/45 assertions.
- `npx supabase test db` Pass A and Pass B — 111 files, 1784/1784 assertions.
- Six HTTP suites — 445/445 assertions; Pass B repeated after HTTP residue.
- `scripts/verify_customer_concurrency.py` — two overlapping sessions, exposure 1200, one threshold event.
- `scripts/verify_database.sql` — `ALL CHECKS PASSED (77 tables)`.
- Primary live reads: ledger `b189b86098856c5e422f285bf1315ec3`, functions `ee3cdfe7d25b9f8290d819c23582174f`, structure `1e3704c47e31a7935fc731dfdaf883d6`; all matched local.

## Governance and disposition

The four findings are registered as CUST-7 through CUST-10 and resolved in migration `20260909060754`. The `customers` row is now `ADVERSARIAL` in `MASTER_SURFACE_DISPOSITION.md`; the manifest, ledger evidence and report index point to this report. CUST-3 remains the already-approved engineering implementation and is not reopened as a business decision.

## Current state

Repository and Primary are synchronized at 210 migrations. The working tree still needs the final documentation-generation, consistency/parity guard run, commit and push for this unit.

## Next step

Run the generated-contract refresh, repository consistency guard and database parity guard; if clean, commit and push Slice 11 and stop.
