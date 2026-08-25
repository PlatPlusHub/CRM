# ORVION — Controlled Production Synchronization Gate

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-25
Author: Claude Opus 5
Scope: Owner-approved deployment of the 16 pending migrations to Primary `vrvtsxexkiiiivlkdxzp`,
and verification of the result. No unrelated engineering was performed.

---

## RESULT — repo = local = Primary, PROVEN

All 16 migrations applied in strict ledger order. **Zero failures.** No migration was skipped,
repaired, improvised or bypassed. No historical migration was modified. No business data was
introduced, modified or lost. No credential was displayed, changed or committed.

---

## 1. Deployment

| | |
| --- | --- |
| Applied | `202607051400` → `202607052900`, **16 migrations**, strict version order |
| Failures | **0** |
| Primary ledger | 102 → **118** |
| Latest | `202607052900_lead_owner_assignee_coherence` |

### The documented hazard occurred, exactly as predicted

`apply_migration` stamps its **own** 14-digit `YYYYMMDDHHMMSS` version rather than the repository
filename's version — recorded in `MASTER_INTEGRATION_CATALOG.md §131-141` before this session began.
All 16 rows landed stamped. The documented reconciliation UPDATE mapped each `name` back to its repo
version: **0 stamped rows remain.**

This is why the hazard was written down. It cost one query instead of a corrupted ledger.

---

## 2. Parity — five independent proofs, not a migration count

The directive forbade claiming parity on the strength of "118 = 118". It is not claimed on that.

| # | Proof | Local | Primary | Result |
| --- | --- | --- | --- | --- |
| 1 | Ledger fingerprint (md5 of `version_name` list) | `5d3d4cbe27ec1ad5b75e9b4f91432eaa` | `5d3d4cbe27ec1ad5b75e9b4f91432eaa` | **identical** |
| 2 | Object comparison, 16 metrics | see below | see below | **all 16 identical** |
| 3 | RLS policy digest (116 policies: table, cmd, roles, USING, WITH CHECK) | `cb5138777400741cd77e80274ae14aa2` | `cb5138777400741cd77e80274ae14aa2` | **identical** |
| 4 | Function security digest (104 fns: signature, DEFINER/INVOKER, volatility, `search_path`) | `4a12cf0d69f17a67e4badc0bf6b405da` | `4a12cf0d69f17a67e4badc0bf6b405da` | **identical** |
| 5 | Function bodies, all 104 | — | — | **code-identical** (see §3) |

**Metrics compared in proof 2, all equal:** 72 tables · 104 `app` functions · 116 policies ·
26 `scope_isolation` policies · 71 permissions · 29 plan-gated permissions · 276 role_permissions ·
68/583 catalog types/values · 66 feature entitlements · 104 status transitions · 10 transition
triggers · 13 archive triggers · 277 FKs · 191 composite tenant FKs · 270 indexes · 20 unindexed
leading-column FKs.

---

## 3. Function bodies — a real finding, honestly bounded

Raw byte comparison of all 104 `app` function bodies: **85 identical, 19 differing.**

**None of the 19 is a function this deployment touched.** All 19 originate in migrations 1–102,
which were on Primary before this session.

Stripping whitespace **and** inline `--` comments makes all **19 of 19 identical**. Verified by
reading one in full (`app.enforce_catalog_codes`): Primary's copy is the same executable logic with
the explanatory comments removed. This is the same re-typing hazard as §1, from an earlier session.

**Conclusion: 104 of 104 functions are code-identical. The residue is comments, not logic.**

Two things this does *not* claim. It is **not** a byte-level match on those 19 — Primary's copies
carry no inline commentary, so an engineer reading them from the database sees less than the
repository holds. And I did **not** repair them: they lie outside the 16 approved migrations, and
the directive forbade expanding scope. Recorded as a follow-up, not silently fixed.

Nine *other* functions — ones this deployment did introduce — had the same comment loss and **were**
restored verbatim, because those were this deployment's own artefact and in scope to correct.

---

## 4. Structural verification on Primary

`scripts/verify_database.sql` — all 20 assertions — executed against Primary: **ALL CHECKS PASSED.**

**Negative control run first.** A pass that cannot fail proves nothing, so a deliberately false
assertion was executed against Primary and correctly surfaced as `P0001 ... found 72`. The pass is
therefore meaningful.

---

## 5. Supabase advisors on Primary

**Security: exactly two findings — the same two as before deployment.** `integration_cursors` RLS
without policy (INFO; intentional, locked to SECURITY DEFINER paths) and `moddatetime` in `public`
(WARN; known cosmetic). **The 16 migrations introduced zero new security findings.**

**Performance: 266 findings, every one INFO** — 206 unindexed foreign keys, 60 unused indexes. No
WARN, no ERROR. `unused_index` carries no signal on a database with no rows. The unindexed-FK
profile is **identical on local** (20 unindexed leading-column FKs, 270 indexes on both), so it is a
property of the schema, not of this deployment — it remains the open item recorded previously, whose
recommendation is unchanged: **measure before adding indexes.**

---

## 6. Behavioural verification on Primary

Existence of a constraint is not evidence that it binds. Seven invariants were exercised as a real
`authenticated` user against Primary, inside a transaction forced to roll back.

| # | Invariant | CR | Result |
| --- | --- | --- | --- |
| T2 | **Baseline** — employee sees their own branch's lead | — | **PASS** |
| T1 | Branch isolation — other branch invisible | SPEC-137 | **PASS** |
| T3 | Employee cannot grant themselves the owner role | SPEC-138 | **PASS** (42501) |
| T4 | Lead owner/assignee cannot diverge | SPEC-151 | **PASS** (23514) |
| T5 | Archiving without `ARCHIVE_RECORD` refused | SPEC-150 | **PASS** (42501) |
| T6 | Direct-DML lifecycle bypass refused (`new → won`) | SPEC-149 | **PASS** (23514) |
| T7 | Margin columns unreadable by employees | SPEC-139 | **PASS** (42501) |

**T2 exists to stop the rest being vacuous.** Six "cannot see / cannot do" assertions would all pass
against a broken fixture that returns nothing. T2 proves the fixture resolves and the user is real,
so the denials below it are denials rather than emptiness.

---

## 7. Integration role — unchanged and least-privileged

| Property | Value | Assessment |
| --- | --- | --- |
| Table grants | **0** | least-privilege contract intact |
| Function EXECUTE | **4** — `capture_attribution_click`, `claim_conversion_deliveries`, `map_outcomes_to_conversions`, `record_conversion_delivery_result` | exactly the four workflow RPCs |
| `rolsuper` / `rolbypassrls` / `rolcreaterole` / `rolcreatedb` | **0** | no elevation |
| `LOGIN` | enabled | the **documented deliberate divergence** (Integration Catalog §3.3) — untouched |

No credential was read, printed, altered or committed.

---

## 8. Business data — zero, before and after

`tenants` 0 · `users` 0 · `auth.users` 0 · `customers` 0 · `leads` 0 · `bookings` 0 · `branches` 0 ·
`events` 0 · `security_events` 0.

`auth.users = 0` independently confirms the §6 probe rolled back completely. Reference and
configuration data present as expected: 583 catalog values, 71 permissions, 276 role_permissions,
66 feature entitlements, 104 status transitions.

**Nothing was introduced, modified or lost.**

---

## 9. Approved repairs

**The manifest was wrong, and its own guard could not see it.** It asserted 112 migrations, latest
`202607052300`, a superseded fingerprint, 70 permissions, and "Primary is 15 BEHIND" when the gap
was 16. Corrected to the verified state.

**Check 9 added to `check_repository_consistency.ps1`.** The ledger fingerprint is md5 of the
comma-joined `version_name` list — which is the migration filenames minus extension. So the
manifest's **count**, **latest version** and **fingerprint** are all derivable from
`supabase/migrations/` with no database and no network.

**Negative-tested against all three drift classes, using the exact stale values the manifest really
carried:**

```
MIGRATION STATE DRIFT: manifest says 112 migrations, repository holds 118
MIGRATION STATE DRIFT: manifest says latest migration is 202607052300, repository's latest is 202607052900
MIGRATION STATE DRIFT: manifest asserts ledger fingerprint 5cdd944b..., but the migration files produce 5d3d4cbe...
```

All three fire; the manifest restored returns CLEAN. Guard now reports **CLEAN** across nine checks.

Why this class of check matters: checks 1–8 reported CLEAN for three sessions while the manifest
carried a wrong migration count. Check 5 measures the manifest's *size*; nothing measured the
*truth* of its numbers.

---

## 10. Still open — not touched, by instruction

| Item | Why |
| --- | --- |
| Inline comments absent from 19 pre-existing Primary functions (§3) | Outside the 16 approved migrations |
| 16 CR files still carry `[ ] UNVERIFIED — Primary` in Acceptance Criteria | Now factually stale; not in the approved scope of this gate |
| 206 unindexed FKs (advisor) / 140 by the stricter earlier count | Unchanged pre-existing item; measure before indexing |
| Column-by-column sweep of all 72 tables | Foundation Freeze prerequisite, not deployment work |
| Employee 360 / Supplier 360 / Branch 360 primitives | Same |

---

## Verdict

**The one blocker that gated the Foundation Freeze across three sessions is closed.** Primary now
carries every migration in the repository, proven by fingerprint, object comparison, policy digest,
function security digest, code-identical bodies, a structural suite with a negative control, and
seven behavioural invariants exercised live.

Deployment scope is complete. **Stopped, as instructed — no further engineering performed.**
