# ORVION — Scheduled Execution, and the Guard That Never Looked

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: Migration `202607056900`; test `66_scheduled_job_isolation_test.sql`; the scheduled/background
execution audit (directive §7); CONV-1; SCHED-2; LEAD-4; PAR-1; DELIV-1.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `fe21781` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Starting state, re-proven from live evidence

| Axis | Evidence |
|---|---|
| git | branch `main`, HEAD = `origin/main` = `fe21781…`, tree clean |
| GitHub | `gh api repos/PlatPlusHub/CRM/commits/main` = the same sha |
| Repo / local / Primary | **157** migrations, `0c48b1fd30c03d2dcf3137cfb4b171f3` on all three, each read directly |
| Primary shape | 74 tables · 119 policies · 3 cron jobs · 75 `public` functions |

The reported baseline held. What did **not** hold is described in §6.

---

## 2. The inventory (§7), traced rather than skimmed

Six background paths exist. Reading them side by side is the whole finding:

| job | one item aborts all? | failure persisted? | discoverable after the run? |
|---|---|---|---|
| `reconcile_document_storage` | NO — per-tenant `exception` block | YES — `tenant_scan_failed` | YES |
| `process_lead_sla` | **YES** | **NO** | **NO** |
| `process_subscription_lifecycle` | **YES** | **NO** | **NO** |
| `map_outcomes_to_conversions` | **YES** — set-based | **NO** | **NO** |
| conversion-delivery lease | n/a | YES | partly |
| storage-executor lease | n/a | YES (FND-1) | YES |

**The exemplar was already in the codebase.** `reconcile_document_storage` wraps each tenant in
`begin … exception when others then … end`, records a finding, resolves that finding when a later
scan of the same tenant succeeds, counts failures into its return value, and nests a *second*
handler in case recording the failure itself fails. Its three siblings had none of that.

So this package is not a new pattern. It is the in-house pattern applied where it was missing.

One trace worth stating: `cron.job_run_details` **does** record a failed job — but it lives in the
`cron` schema, is unexposed to PostgREST and ungranted to `service_role`. No operator can reach it
through the API. A raise was recorded somewhere nobody can read.

---

## 3. CONV-1 — the finding that was not latent

`app.map_outcomes_to_conversions` filtered restricted tenants **out** of its set-based INSERT and
then advanced `integration_cursors.last_seq` past their events unconditionally. Two tenants, one
attributed lead each, tenant B in `read_only`:

```
run 1 (B read_only)          inserted 1    conv-good 1 | conv-lapsed 0
B restored to good standing
run 2                        inserted 0    conv-good 1 | conv-lapsed 0
run 3                        inserted 0    conv-good 1 | conv-lapsed 0
```

The conversion is not deferred. It is **destroyed** — and the victim is the tenant who paid late,
losing exactly the acquisition-to-revenue lineage that justifies their ad spend.

**This is a defect, not a business decision, because ORVION had already decided what "skip" means.**
WP-03 established that batch callers skip lapsed tenants. Everywhere else that means *defer*:
`process_lead_sla` skips and retries sixty seconds later; `platform_resolve_storage_finding` refuses
explicitly and leaves the finding open. The mapper was the only place skip meant *discard*, and only
because it owns a cursor. It also contradicts the owner's Google Ads requirement — *"Preserve
attribution lineage from acquisition through revenue"* — which yesterday's `202607056700` existed to
protect at the other end of the same chain.

### Two fixes costed and rejected

* **Do not advance the cursor past a skipped event.** Correct on loss; converts one tenant's lapse
  into head-of-line blocking for every tenant, and a *departed* tenant stalls the mapper forever.
  That is the trade the original author was avoiding, and they were right to.
* **Re-scan history for conversion events with no `offline_conversions` row.** Needs no storage and
  reuses the `source_event_seq` key that already exists — but the permanently-unconvertible
  remainder (events whose lead carries no attribution click) grows without bound and starves the
  backfill's own limit. Correct today, degrading forever.

### What was built

The skip is recorded as deferred work **before** the cursor moves past it; each run reconsiders the
deferrals whose tenant can be written again; the cursor still advances, so no tenant blocks another.
Recovery is safe to repeat because `source_event_seq` is unique with `on conflict do nothing` — the
idempotency key this fix leans on already existed. After the fix, the identical probe recovers on
run 2 and adds nothing on run 3.

---

## 4. SCHED-2 — isolation, and being honest that it is latent

No naturally reachable raise exists in either loop body today; every write was traced. **The defect
is latent, and it was fixed anyway** — because the property that matters is isolation, and a fix
aimed at today's reachable raise sources would measure *the list* rather than *the property*. The
list is what changes. WP-03 was precisely that: a trigger correct for a user write and dangerous
inside a batch.

The test therefore injects a raise on one fixture row, and says so in its header. Measuring the
property means the guard survives the next trigger somebody adds.

What a stalled job actually costs is worth stating plainly:
`process_subscription_lifecycle` drives the state that gates every write in ORVION. One raising
tenant would have silently kept lapsed tenants writable and paying tenants un-renewed, every day.

**The store.** `public.scheduled_job_findings` mirrors `public.document_storage_findings` — upsert on
a natural key, `last_seen_at`, `attempt_count`, `resolved_at`, re-observation reopens. That table
appears **nowhere in canon**: it is engineering-owned platform-operational state, created by WP-04
without a canon amendment, because operational health is not business vocabulary. That is the
precedent this one stands on. Deliberately not built: no notification, no event type, no alert
routing — §8 asks for enough evidence to answer nine questions, and a table plus a reader answers
all nine.

It is deliberately **exempt** from the subscription write gate, and the reason inverts the usual
one: a restricted tenant is exactly the case those rows exist to record. Gating it would make a
deferral unrecordable for the very tenant being deferred — which is how CONV-1 happened.

---

## 5. Two guards caught me; one had never been looking

`10_grant_model_test` §5 caught a missing `revoke execute … from public` on the new trigger function
yesterday. `35_subscription_write_gate_test` §22 and `53_api_surface_test` §1 caught the new table
and the new endpoint today, forcing both to be **declared** rather than assumed. That is what a
working guard looks like.

Then the parity guard.

---

## 6. PAR-1 — the guard every session report cites was measuring a subset

Deploying is done through `apply_migration`, because `supabase db push` needs a database password and
external credentials never pass through the agent. After deploying, I compared the logic hash of
**all 228** `app` and `public` functions rather than only the ones I had changed.

They did not match.

Narrowing by first letter, then by name: **six functions differed** — `add_customer_contact_method`,
`assign_task`, `claim_conversion_deliveries`, `create_marketing_campaign`, `create_supplier`,
`record_offline_conversion`. None from this session.

**Behaviour was established before anything was changed.** Under whitespace-insensitive comparison
all 228 hashed identically on both environments (`19416a6b008f7202fe61fccac6e814e4`). The six
differences were formatting and **stripped comments** — hand-transcribed, reflowed SQL applied to
Primary by earlier sessions. `create_supplier` on Primary had lost the paragraph explaining why
supplier names are compared case-insensitively.

**The documentation loss is the smaller half.** The larger half is that nothing would have caught a
*real* divergence. Parity had only ever compared:

1. the migration-ledger fingerprint — which proves the same migration **names** were applied and says
   nothing whatever about what the applied SQL created; and
2. the logic hash of the functions each package had just changed.

Drift anywhere else was invisible **by construction** — and this is the guard I have been quoting as
evidence in every session report. It is §3's instruction turned on the verification layer: *"If an
existing guard reports something as CLEAN, independently verify what the guard actually measures."*

Fixed on three axes:

* the six re-applied to Primary with the repository's exact text — strict byte-level hash now
  `4821a18a9bf8193a4bc8c7dea6e345a8` on both sides, each read independently;
* `check_database_parity.ps1` gains `-PrimaryLogicHash`, a Check L2/P2 over the **full** function
  surface, and a verdict that names the ledger and the functions separately instead of collapsing
  both into the word "proven";
* the ledger rows those repairs created were deleted, because **nothing in the repository changed** —
  the repair made Primary match what the existing migrations already specify, and inventing a
  migration file for it would have been a no-op replay.

**Permanent rule, recorded because it is the root cause:** SQL sent to `apply_migration` is pasted
**verbatim** from its repository file. This package's own nine new functions were, and matched
byte-for-byte on the first comparison.

*(Yesterday's GUARD-1 was the same guard's other half: it reported "primary proven" for a fingerprint
I had supplied it. Two blind spots, one guard, found a day apart.)*

---

## 7. Siblings audited and found clean (§26)

Recorded so the sweep is verifiable rather than asserted. The **conversion-delivery lease** already
persists failure (`delivery_status_code = 'failed'`, `error_message`, `failed_at`, plus an
`offline_conversion_failed` event) and recovers a crashed worker through SPEC-123's 30-minute lease.
The **storage executor** does the same through FND-1. Neither needed changing.

One hypothesis I formed and then disproved, stated because the disproof is the useful part: I
expected the mapper's copy of `customers.primary_email` / `primary_phone` into
`offline_conversions` to be able to violate that table's normalization CHECKs and kill the batch.
It cannot — `customers` carries the identical constraints, so source and destination already agree.

What both leases still lack is an **operator surface** for work that has exhausted its retries.
Recorded as **DELIV-1**, and deliberately not built: PH8-1's residual and PH8-2 already own that
question, and PH8-2 is an owner decision about what such a surface must distinguish.

---

## 8. Verification

| Axis | Value |
|---|---|
| Migrations | **158** — repository, local, Primary |
| Ledger fingerprint | **`cbd05efe6959946df51c83d288851627`** — read independently from local and from Primary |
| Function surface (all 228) | **`4821a18a9bf8193a4bc8c7dea6e345a8`** — byte-identical, read independently from both |
| pgTAP **Pass A** (fresh `db reset`) | **66 files / 781 assertions / 0 failures** |
| pgTAP **Pass B** (after all five HTTP suites' residue) | **66 files / 781 assertions / 0 failures** |
| End-to-end HTTP | **182/182** — storage 43 · employee 29 · branches 26 · roles 27 · lifecycle 57 |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Guards | repository CLEAN · parity CLEAN (ledger **and** functions) |

---

## 9. Classification

**PROVEN DEFECT (fixed)** — CONV-1 (a lapsed tenant's conversions destroyed rather than deferred);
PAR-1 (parity never compared the function surface, and six functions had drifted).

**PROVEN DEFECT, LATENT (fixed)** — SCHED-2: `process_lead_sla`, `process_subscription_lifecycle`
and `map_outcomes_to_conversions` had no per-item isolation and no persisted failure.

**FIXED same-cycle** — LEAD-4, recorded yesterday and closed today.

**AUDITED, NO CHANGE NEEDED** — the conversion-delivery lease; the storage-executor lease;
`reconcile_document_storage`, which was the exemplar.

**OPEN** — DELIV-1, subsumed by PH8-2's owner decision.

**INTENTIONAL** — the new table's exemption from the subscription write gate; `finding_type_code` as
a CHECK rather than a catalog family; no notification, event type or alert routing.

---

## 10. Next logical work

Executable without the owner: continue §11's CRM lifecycle walk — **complaints and conversations**
are the least-exercised branches over HTTP — and then §19's API capability contract, which must
precede any WeWeb work.

Still owner-blocked, unchanged: DOC-EXP-1 (recipient, lead time, repeat cadence — the largest
remaining operational hole), SCHED-1's route and its one secret, RET-1, RET-2, AUTH-1, FIN-5,
SYSADMIN-1, VOID-1, SPP-3, PH8-2, TRANS-1.
