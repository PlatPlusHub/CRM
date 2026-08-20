# Change Request — SPEC-123

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Resolve **PH8-1** — a delivery claimed but never acked is stranded `pending` forever — by adding the standard outbox **lease / visibility timeout** to `app.claim_conversion_deliveries`, plus the permanent behavioral guard that keeps the defect closed.

---

## Business Reason

`app.claim_conversion_deliveries` excludes any conversion holding a `pending` or `sent` delivery, and `app.record_conversion_delivery_result` only accepts a delivery that is currently `pending`. The retry design therefore recovers `failed` deliveries only. An n8n run interrupted between Claim and Ack — deploy, execution timeout, OAuth expiry mid-run, rate-limit abort, platform incident — leaves its delivery `pending` permanently: never re-claimed, never retried, never acked, never counted as failed, and invisible to the retry ceiling (which counts delivery rows, not outcomes). The result is silent, unbounded revenue-attribution loss with no operator signal.

This is the one gap the repository records as **mandatory before the Phase-8 workflow may run unattended on its 15-minute schedule** (`MASTER_GAP_REGISTER.md` PH8-1; `MASTER_INTEGRATION_CATALOG.md §4`). Owner-approved 2026-08-20: *"I approve PH8-1. Proceed with the Lease / Visibility Timeout solution."*

---

## Risks

Low, and bounded by measurement rather than assertion.

- **No schema change to existing columns, no data migration, no RLS change.** One `create or replace function`, one additive partial index.
- **The one real risk is a lease shorter than a legitimate run**, which would reclaim rows still in flight and double-deliver to Google (Google would double-count, since ORVION sends no deduplication key today — see Findings). Mitigated by deriving the lease from the enforced workflow timeout with a 3x margin, and by requiring the workflow to set its own `Timeout Workflow` (§Lease derivation).
- The claim path gains one indexed sweep per call; measured at 0.173 ms against 200k delivery rows.

---

## Supersedes / Depends On

Depends on `202607049200_offline_conversion_core.sql` (the claim/ack pair and the delivery table) and `202607043100_seed_system_catalogs.sql` (the `offline_conversion_delivery_status` vocabulary this reuses). Supersedes nothing.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050100_conversion_delivery_lease.sql` (new)
- `supabase/tests/09_conversion_delivery_lease_test.sql` (new)
- `changes/SPEC-123-conversion-delivery-lease.md`
- `reports/master/MASTER_GAP_REGISTER.md` (PH8-1 row + detail)
- `reports/master/MASTER_INTEGRATION_CATALOG.md` (§2 contract, §2a, §4)
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json` (regenerated, never hand-edited)

## Out of Scope — Files Forbidden to Modify

- Any other `supabase/migrations/**` file — in particular `202607049200`, which stays the historical record of the original claim/ack design.
- `app.record_conversion_delivery_result` — deliberately unchanged; its refusal to resolve a non-`pending` delivery is what makes a late "zombie" ack safe.
- Canon, ADRs, `AGENTS.md`, `GOVERNANCE.md`.
- The n8n workflow itself (not yet built; explicitly out of scope this CR).

---

## Minimum Reading List

- `supabase/migrations/202607049200_offline_conversion_core.sql` — claim/ack, retry ceiling, `retire_failed`
- `reports/master/MASTER_GAP_REGISTER.md` — PH8-1 evidence
- `reports/master/MASTER_INTEGRATION_CATALOG.md §2`/`§2a` — the workflow contract this must not break
- `supabase/tests/08_status_vocabulary_registry_test.sql` — the status-vocabulary guard any new status literal must satisfy

---

## Lease derivation (why 30 minutes, not an arbitrary number)

The lease must exceed the longest a *live* worker can legitimately hold a claimed row; anything shorter reclaims in-flight work and double-delivers.

| Input | Value | Source |
|---|---|---|
| Schedule interval | 15 min | `MASTER_INTEGRATION_CATALOG.md §2` |
| Claim batch | 50 rows | `§2` step 2, `p_batch` default |
| Work per row | 1 Data Manager HTTP POST + 1 ack RPC | `§2` steps 4–5 |
| Pessimistic per-row latency | ~5 s | HTTP call with retry headroom |
| Worst-case legitimate run | 50 x 5 s + map/claim ≈ **5 min** | derived |
| n8n Cloud max execution time | **plan-dependent** | n8n docs, verified 2026-08-20: *"For n8n Cloud users, the maximum available timeout is determined by the specific subscription plan"* |

Because n8n Cloud's own cap is plan-dependent and could change under us, ORVION must not depend on it. **The workflow is required to set its own `Timeout Workflow` = 10 minutes** (2x the pessimistic worst case; hard-kills a hung run). The lease is then **30 minutes = 3x that enforced timeout and 6x the realistic worst case**.

Recovery latency is at most the lease plus one schedule tick (~45 min) — far inside Google's offline-conversion ingestion window, so nothing is lost by being conservative.

**Invariant to preserve: `lease > workflow timeout > worst-case run duration`.** If the schedule, batch size, or workflow timeout changes, the lease must be revisited. The lease is a function-local constant rather than a parameter so an orchestrator cannot weaken the safety property from outside — the same rationale as the existing fixed retry ceiling of 5.

---

## Implementation Steps

1. Create `supabase/migrations/202607050100_conversion_delivery_lease.sql`: `create or replace function app.claim_conversion_deliveries` with a **Step 0** lease sweep ahead of the unchanged claim query. The sweep terminalizes every `pending` delivery for the platform whose `created_at` is older than the lease to `failed`, stamping `failed_at` and an explicit `LEASE_EXPIRED: …` `error_message`, and emits `offline_conversion_failed` per row with payload `expired_lease: true`. Re-state the existing revoke/grant pair. Verification: file absent before, present after; `db reset` applies it clean.
2. In the same migration add the partial index `offline_conversion_deliveries_pending_lease_idx (platform_code, created_at) where delivery_status_code = 'pending'` — only after measuring that the plan requires it (see Verification Notes). Verification: `pg_indexes` lists it after reset.
3. Create `supabase/tests/09_conversion_delivery_lease_test.sql` — 17 pgTAP assertions covering every behavior in the owner's test list. Verification: `supabase test db` green.
4. Run `npx supabase db reset`, the full pgTAP suite, and the smoke-test. Verification: all three clean.
5. Verify real database behavior beyond the test suite: reproduce PH8-1 pre-fix, prove two-session concurrency, and exercise the fixed path as `orvion_integration`. Verification: recorded in Verification Notes.
6. Sync `MASTER_GAP_REGISTER.md`, `MASTER_INTEGRATION_CATALOG.md`, `manifest.md`; regenerate `ai-map.json`; run the consistency guard. Verification: guard prints `REPOSITORY CONSISTENCY: CLEAN`.

---

## Design decisions (and why the alternatives were rejected)

- **Terminalize expired leases to `failed`, do not add an `expired` status.** `failed` already exists in the `offline_conversion_delivery_status` catalog, so no new status vocabulary and no canon change is needed, and the guard in test 08 stays satisfied. More importantly the **entire existing retry machinery then applies unchanged**: the conversion becomes claimable again, `retire_failed` retires the row to `retried` on the next attempt, and the ceiling of 5 delivery rows still counts the expired attempt — so a crashed worker *consumes* an attempt and cannot bypass the limit. `LEASE_EXPIRED` in `error_message` keeps the two causes distinguishable for audit.
- **Sweep inside `claim_conversion_deliveries`, not in a new RPC.** The owner's constraint was to avoid an extra n8n node unless technically unavoidable. It is not: the sweep is a pure function of time and needs no orchestration, so the workflow contract stays exactly the 7 nodes of `§2`. A separate `requeue_stale_*` RPC would have added a node, a failure mode, and a second thing to schedule, for no gain.
- **No new column.** A `pending` row is INSERTed at claim time, so `created_at` *is* the lease start. A `lease_expires_at` column would have been derived data duplicating it.
- **`record_conversion_delivery_result` left untouched.** Its existing refusal to resolve a non-`pending` delivery is exactly what makes a late zombie ack safe — verified below.

---

## Acceptance Criteria

- [x] A fresh `pending` lease is not reclaimable; an expired one is.
- [x] Reclaiming creates exactly one new delivery row and leaves exactly one active (`pending`) delivery.
- [x] Attempt history is neither reset nor bypassed: the reclaimed attempt is number 2, expired attempts count toward the ceiling of 5, and a ceiling-exhausted expired lease terminalizes to `failed` instead of looking in-flight forever.
- [x] A `sent` delivery is never reclaimed, however old.
- [x] A late ack from the crashed run is refused rather than marking a reclaimed conversion `sent`.
- [x] Concurrent workers cannot double-claim, and a concurrent expiry race emits exactly one event and creates exactly one new attempt.
- [x] No unrelated tenant's data is read, altered, or affected.
- [x] Lease expiry is observable as a canonical event (`offline_conversion_failed`, `expired_lease: true`).
- [x] `db reset` clean, full pgTAP suite green, smoke-test `ALL CHECKS PASSED`, consistency guard CLEAN.
- [x] No file outside Scope modified.

---

## Execution Log

### 2026-08-20 — Claude (Opus 5)

Outcome: Complete

- Step 1–2: `202607050100_conversion_delivery_lease.sql` created; applied clean by `db reset` (89 → 90 migrations).
- Step 3: `supabase/tests/09_conversion_delivery_lease_test.sql` created — 17 assertions.
- Step 4: `db reset` clean; `supabase test db` → **Files=9, Tests=28, Result: PASS**; smoke-test → `ALL CHECKS PASSED` (72 tables … grant/schema-usage completeness).
- Step 5: live verification — see Verification Notes.
- Step 6: registers, catalog, manifest synced; `ai-map.json` regenerated; guard CLEAN.

Commits: see repository history for this CR's commit hash.

---

## Verification Notes

### 2026-08-20 — Claude (Opus 5)

Verdict: **Confirmed Complete** — every claim below was executed against the live local database and its real output observed, not inferred.

**1. PH8-1 reproduced BEFORE the fix** (rolled-back fixture on the local database). Claim #1 returned 1; claim #2 returned 0; after backdating the delivery 24 hours claim #3 still returned 0; the delivery remained `pending / attempt 1` — stranded exactly as the finding describes.

**2. pgTAP suite.** 9 files, 28 tests, `Result: PASS` on a clean `db reset`. The 17 new assertions cover every item on the owner's list except cross-session concurrency, which a single transaction cannot express and which is covered structurally (the test asserts `for update … skip locked` and the `LEASE_EXPIRED` step are still present, so neither can be silently removed) plus the live proof below.

**3. Two-session concurrency — no double-claim.** Session A opened a transaction, claimed (1 row) and held its locks for 6 s; session B claimed concurrently and returned **0**; exactly **one** delivery row existed afterwards.

**4. Two-session concurrency — expiry race.** With the pending lease backdated 31 minutes, session A ran the sweep + reclaim inside a held transaction and session B ran concurrently. A reclaimed 1, B got **0**, and the final state was exactly two rows (attempt 1 `retried` carrying `LEASE_EXPIRED:…`, attempt 2 `pending`) with exactly **one** `expired_lease` event — no duplicate events, no duplicate active deliveries.

**5. Verified as the real production caller.** Under `set role orvion_integration` (not superuser): claim succeeded, the expired lease was reclaimed, and the late zombie ack from the "crashed" run was **refused** — `delivery … is retried — only pending deliveries can be resolved`. A reclaimed conversion can therefore never be marked `sent` by the run that lost its lease.

**6. Index justified by measurement, not assumption.** With 200,000 synthetic delivery rows (rolled back), the expiry predicate planned as a Parallel Seq Scan, 2,858 buffers, **57.0 ms**, growing without bound; with the partial index, an Index Scan, 37 buffers, **0.173 ms**. The index is **16 kB** against a 22 MB table because it is partial on the in-flight set only, which is bounded by (runs in flight x batch) rather than by history. On a sweep that runs every 15 minutes forever against an append-only table, this meets the "add only if the plan requires it" bar.

**7. Clean-state confirmation.** After the final `db reset` the local database holds 0 tenants and 0 deliveries — every fixture used above is gone. No synthetic conversion or click identifier was ever created outside a local rolled-back transaction, and none reached Google.

Recommendation to human: Status Complete.

### 2026-08-20 — Claude (Opus 5) — deployment run

Outcome: **Complete — deployed and verified live on BOTH Primary and Secondary.** Owner-approved: *"Deploy SPEC-123 to Primary and Secondary."*

- Target refs re-verified immediately before any write (`MASTER_INTEGRATION_CATALOG.md §0` rule 6): Primary `vrvtsxexkiiiivlkdxzp` (via `get_project_url`), Secondary `brplkqmbzffpxqgkkdzo` (via `list_projects`). Neither retired ref was contacted.
- Pre-deploy state captured on both and identical: 89 migrations, latest `202607050000`, no `202607050100`, no `LEASE_EXPIRED` in the function, no partial index.
- Applied the verbatim migration body to both. MCP-assigned versions (`20260820153356` Primary, `20260820153447` Secondary) reconciled to `202607050100`, matching the repository filename (SPEC-122 precedent).
- Post-deploy verified on both: 90 migrations; `202607050100` present; function contains the `LEASE_EXPIRED` sweep **and** `for update of oc skip locked`; partial index present; `orvion_integration` holds `EXECUTE` + schema `USAGE`. **Behavioral proof:** `app.claim_conversion_deliveries('google_ads', 50)` executed successfully on each, returning 0 rows (correct against empty tables).
- **Synchronization proven by fingerprint, not assertion:** the ordered `version:name` manifest of all 90 migrations hashes identically on both — `dffb38c1fcc5457da1b6f35dbec0c5dc`.
- No data created or modified; `tenants` / `offline_conversions` / `offline_conversion_deliveries` all remain 0 rows on both.

Full deployment record: `MASTER_INTEGRATION_CATALOG.md §4` ("SPEC-123 deployment — 2026-08-20").

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] Every Acceptance Criteria item is confirmed true by observed output.
- [x] The repository is in a clean, releasable state.

### Excellence Check

- **Anything overlooked?** Yes — three findings raised to the owner rather than silently absorbed (see `MASTER_GAP_REGISTER.md` PH8-5, and the PH8-1 detail's operator note). None is required to make PH8-1 correct.
- **Simpler equivalent?** The sweep-inside-claim design is the smallest thing that works: no new RPC, no new node, no new column, no new status.
- **Unnecessary complexity?** None added; the claim query itself is byte-for-byte the original.
- **Reusable concept?** Yes — the lease is channel-generic via `platform_code`, so Meta CAPI (Phase 10, same outbox per ADR-0023) inherits it for free.
- **Multi-role usability.** Operations/marketing gain a real answer to "was this conversion delivered?": a crashed run now produces a visible `offline_conversion_failed` event flagged `expired_lease` instead of silence. The residual observability gap (no single delivery-health surface) is PH8-2, unchanged and still owner-gated.
