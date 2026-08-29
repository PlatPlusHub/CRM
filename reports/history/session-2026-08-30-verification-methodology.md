# ORVION — Master Verification & Audit-Methodology Review: the Guard That Could Not See Its Own Deliverable

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Scope: Adversarial review of ORVION's verification system, proven by controlled mutation on the local
database. **PAR-3** (parity guard blind to 3,108 of 3,341 objects) and **PAR-4** (three tests could
not prove their own enforcer) fixed; **VER-1** fixed; **VER-2** measured and rejected. New file
`scripts/parity_surface.sql`; `check_database_parity.ps1` gains Check L4/P4; tests 70/72/73 gain
mutation pairs. No migration — the database did not change.
Status: Complete; verified; committed and pushed.

**Branch:** `main` · **Start HEAD:** `a4a4f80` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 0. The one-sentence result

The verification system is stronger than this session expected in the places it was built
deliberately, and had one hole exactly where nobody had looked: **the only bridge between the
repository and Primary compared 233 objects out of 3,341, and was blind to every object type the
last four packages shipped.**

---

## 1. Re-introspection (ground truth, read before any analysis)

| Fact | Value | Source |
|---|---|---|
| Clock | `2026-08-29 22:01 UTC` = **`2026-08-30 01:01 +0300`** | `date -u` and `date` |
| HEAD / remote | `a4a4f80` = `a4a4f80a3e2eb…` | `git ls-remote` |
| Working tree | clean | `git status` |
| Migrations | 165 repo / 165 local / **165 Primary** | files, psql, MCP |
| Ledger fingerprint | `6f6595de1f1d3d784457e6c60d882fd7` both sides | read independently |
| Function surface | `b511e0edeeec052514fead7ddea5e0ba`, 233 | read independently |
| n8n | 0 workflows (unchanged) | prior session, not re-read this session |

**A date note, because AUD-01 was exactly this class.** UTC was still 2026-08-29 while the operator's
clock read 2026-08-30. ORVION dates are the operator's local dates — commit author dates are `+0300`
— so this session is **2026-08-30**, and Check 12 (which uses `(Get-Date).Date`) agrees. The two
never disagree by more than that window, but the window is real and it is the one AUD-01 fell into.

---

## 2. The finding: PAR-3

`check_database_parity.ps1` proved two things — the migration ledger, and the **function** surface
(PAR-1's fix). Nothing else was ever compared between local and Primary.

**Reproduced as a controlled mutation on a freshly reset local database** — never on Primary. The
mutation chosen was the most damaging one available: drop `payment_allocations_within_invoice_total`,
FIN-10's financial ceiling, a High-severity fix shipped the previous day.

```
docker exec … psql -c "drop trigger payment_allocations_within_invoice_total on public.payment_allocations;"
```

| layer | verdict with the financial guard deleted |
|---|---|
| `check_repository_consistency.ps1` | `REPOSITORY CONSISTENCY: CLEAN` — **exit 0** |
| `check_database_parity.ps1` | `DATABASE PARITY: CLEAN` — **exit 0** |
| `MASTER_API_CONTRACT.md` | "matches the live surface" |
| `scripts/verify_database.sql` | `ALL CHECKS PASSED (75 tables …)` |
| `supabase/tests/72_*.sql` | **FAILED 2 of 16** ← the only layer that noticed |

The one layer with the sensitivity is pgTAP, and **pgTAP runs against local only** — it can never be
run against Primary. So for the environment that will hold real customer money, nothing in the
repository could have detected a missing trigger, a widened grant, a rewritten policy, a dropped
constraint or a deleted transition row.

**Measured coverage before: 233 of 3,341 objects — 7%.** And the 93% not covered is where the last
four packages (DOC-LC-1, FIN-8, FIN-10, QUO-1) shipped their entire deliverable, because every one of
them shipped a **trigger**.

### The fix, and why it is one file

`scripts/parity_surface.sql` defines the surface **once**, and **both sides run that file** — local
via psql, Primary via the `supabase-primary` MCP. This is not tidiness. PAR-1a was two databases
agreeing while genuinely differing, because a comment-stripping regex written as `'--[^\n]*'` means
"not a backslash and not the letter n" inside a POSIX bracket expression. Two hand-copied variants of
this query is precisely how that recurs, so there is only one variant.

Ten surfaces: functions · triggers · policies · **RLS enablement** · constraints · grants · columns ·
views · indexes · `app.status_transitions`.

`-PrimaryStructureHash` joins the other two in what a CLEAN verdict *requires*. Leaving it optional
would have rebuilt the defect AUD-05 fixed — a value that was never measured quietly counting as one
that passed.

### Proven in both directions

```
mutated local  → PRIMARY STRUCTURE DRIFT: Primary 6ec6e8cd… , local b50de752…   exit 1
                 (breakdown named the surfaces: triggers 229→228, constraints 440→439)
npx supabase db reset
restored local → Primary's structural surface matches local (4bca45c7…)          exit 0
```

Restoration was a full `db reset`, never a hand-recreated trigger — PAR-1b's rule that local equals
the repository only immediately after a reset.

---

## 3. Then the fix was attacked, and it had a hole

The hypothesis under test was my own. Second mutation:

```sql
alter table public.invoices disable row level security;
```

The tenant isolation boundary on `invoices` is now gone. The policy is **still listed in
`pg_policies`**. The combined hash was **byte-identical** — `b50de752…`, unchanged.

`pg_policies` describes a policy whether or not row security is enabled on its table, so a policy
that cannot fire hashes exactly like one that can. `relrowsecurity` / `relforcerowsecurity` were
added as a tenth surface. (`verify_database.sql` CHECK 3 *does* catch this — and runs on local only,
which is the entire reason this file exists.)

`ordinal_position` was added to the column surface in the same pass, because **CUST-1 was a positional
assumption**: a loop reading the first column of each key silently became a no-op when TENANT-1 made
those keys composite. Position is meaning to anything catalog-driven.

**Final state: local = repository = Primary at `4bca45c73e058581190505ac878688fc`, 3,341 objects,
read independently from both sides.** Parity is now proven 14× deeper than it was this morning — and
it was, in fact, already true. PAR-3 was a **false-negative capability**, not a hidden drift.

---

## 4. PAR-4 — the tests could not prove their own enforcer

PAR-3's most uncomfortable detail is that pgTAP was the *only* layer that noticed. That makes it
worth knowing precisely which assertion does the noticing — and none of them could say.

Tests 70, 72 and 73 each proved the violation *is* refused. None proved **what refuses it**. A test
that passes for the wrong reason goes quiet the moment the real enforcer is removed.

Each now carries a mutation pair, inside a `savepoint` that is rolled back:

```
drop the named trigger  → the identical violation must SUCCEED
rollback to savepoint   → the identical violation must be REFUSED again
```

One half without the other proves half of it. QUO-1's reads the other way round, because it
*recomputes* rather than refuses: with the trigger gone the total must go **stale**, and on restore
the next write must repair it.

**Two initial failures, recorded rather than tidied away, because both are the lesson:**

- Test 70's probe died on `23503` — TENANT-1's composite FK — because `journal_entries.created_by`
  defaults from the JWT and the *cross-tenant* assertion above had left the rival tenant's session in
  place.
- Test 72's died on `42501: permission denied: CREATE_INVOICE`, because the *employee* session from
  the authorization assertion was still current.

Both are the exact confusion `AGENTS.md §6` warns about — **"operation denied" and "operation never
attempted" are different results** — met in practice, in tests written the day before by the author
of that rule. Each fix restores the correct session and says why in a comment.

Suite: **899 → 905 assertions, 73 files, 0 failures.**

---

## 5. What was rejected, and why that matters more than what was built

### VER-2 — a mechanical vacuous-test detector. **REJECTED on measurement.**

`AGENTS.md §6` bans vacuous security tests in prose. The question was whether a guard could enforce
it. The demonstrated shape — a `lives_ok`/`throws_ok` wrapping an `INSERT … SELECT`, which silently
inserts zero rows when the actor cannot see the source — occurs **31 times across 15 of 73 files**,
nearly all legitimate. A detector flagging those would cry wolf, which the repository guard's own
header forbids ("precision over recall — it must not cry wolf, or agents will learn to ignore it").

A tightened variant requiring a `count()` control flagged exactly one file. Inspection showed a
**false positive**: `62_action_attribution_test.sql` controls its insert with a scalar `is()` on the
inserted row, which is an equally strong control — arguably stronger, since it proves the row exists
*and* carries the right value.

What actually distinguishes a vacuous test is **whether the acting role can see the rows being
selected**. That is semantic, not syntactic, and not statically decidable. **PAR-4's mutation pattern
is the mechanism that works**, because it observes behaviour instead of matching shapes.

### Option: a runtime-emitted HTTP coverage file. **REJECTED.**

It would be stale whenever the suites had not just run — trading a theoretical false positive for a
guaranteed one, which is the "checks that become stale" failure mode.

### Option: raising the manifest character budget. **REJECTED.**

Check 5 flagged this session's own additions as `MANIFEST BLOAT` at 7,344 / 7,000. Raising the budget
to fit the work is weakening a test to make it green. The manifest was trimmed instead — including a
line of *history* that the manifest's own rule already said belongs in the register.

---

## 6. VER-1 — the contract claimed execution and measured text

`MASTER_API_CONTRACT.md`'s `http` column said "whether a suite **actually calls** the endpoint over
the wire". It was a regex over `verify_*.ps1` source.

**Audited before assuming:** all 46 endpoints then marked covered do have a live, non-comment
invocation. There was **no current false positive**. The one concrete way to manufacture one is a
commented-out call, so comment lines are now excluded — the count stayed 46, which proves the change
non-destructive. The column is now stated as a **REPOSITORY fact, not an execution fact**, and §6
records that the whole contract describes *one* database — the local one it was generated from — and
is not evidence about Primary.

---

## 7. The review the owner asked for (A–L)

### A. What the verification system actually is

Eleven mechanisms, and they are genuinely layered rather than redundant: `check_repository_consistency.ps1`
(12 file-only checks) · `check_database_parity.ps1` (ledger, functions, **structure**, contract
freshness) · `verify_database.sql` (smoke, 75 tables) · 73 pgTAP files / 905 assertions · six HTTP
suites / 259 assertions · `generate-api-contract.ps1` and `generate-ai-map.ps1` (generated, and
diffed against the committed copy) · `AGENTS.md §4` boot sequence · `MASTER_GAP_REGISTER.md` as the
findings SSOT · CI on every push.

### B. Verified strengths — keep these, they are load-bearing

1. **The separation of repository facts from database facts is real and enforced.** The repository
   guard prints its own scope limit on success. That single line is why the 2026-08-26 incident
   cannot recur silently.
2. **Three-outcome parity (AUD-05).** `exit 2 UNPROVEN` for "Primary not contacted" is the single
   most important design decision in the whole system: *not measured* is not a kind of *passed*.
3. **Generated-and-diffed artifacts.** The contract and ai-map are regenerated and compared, so a
   stale claim fails a gate rather than sitting quietly.
4. **The manifest character budget.** It fired on this session's own work, correctly.
5. **Check 12's refusal to have an exemption list.** It flagged its own explanatory comment, and the
   fix was to stop quoting the date rather than to add an exemption.
6. **pgTAP's sensitivity is real** — it caught the FIN-10 mutation with no help.

### C. Blind spots that remain (stated, not hidden)

| # | Cannot prove | Class | Judgement |
|---|---|---|---|
| 1 | pgTAP and smoke **never run against Primary** | structural | Accepted. They need role switching and write test data. Check L4/P4 is the compensating control, and it is why it now covers ten surfaces. |
| 2 | Seeded **catalog** rows other than `status_transitions` (`permissions`, `role_permissions`, `catalog_values`) are not compared | UNPROVEN | **Next candidate.** `role_permissions` is the authorization matrix; a divergent row changes `app.authorize` on Primary alone. Deliberately not bundled here — it needs its own reproduction. |
| 3 | `http = yes` is source text, not execution | documented | Accepted, VER-1. |
| 4 | No guard proves an **HTTP suite ran**; the evidence is the session report | procedural | Accepted; the report is the SSOT and Check 10 keeps its pointer current. |
| 5 | n8n / external systems have no automated verification | BLOCKED | Correct — nothing is built to verify. |

### D. Where GREEN could still be wrong

- Any Primary value is **caller-supplied**. All three now print that caveat, and GUARD-1 exists
  because a near-miss passed the repository's own expected value back to the guard. This is a
  procedural control, not a mechanical one, and it should stay visible.
- A CLEAN parity run says nothing about **whether the migrations are correct** — only that both sides
  have the same thing. Correctness is pgTAP's job.
- **Local drifts from the repository the moment a migration is hand-applied** (PAR-1b). Every
  structural reading this session was taken after a full `db reset`, for that reason.

### E. Practice comparison

| Practice | Source | ORVION's position |
|---|---|---|
| **Mutation testing / defect injection** — mutate the system, require the suite to fail; the score measures *discriminative power*, not size | [Tricentis](https://www.tricentis.com/learn/mutation-testing), [Testsigma](https://testsigma.com/blog/mutation-testing/) | **Adopted, narrowly.** PAR-3 and PAR-4 are both defect injection. Full mutation-testing tooling is **rejected** — ORVION's logic is SQL triggers and RLS, which no mutation framework targets, and the hand-picked mutations are the high-value ones anyway. |
| **Improper Protection of Alternate Path (CWE-424)** | [OWASP WSTG Authorization Testing](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/05-Authorization_Testing/02-Testing_for_Bypassing_Authorization_Schema), [OWASP Top 10:2025 A01](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/) | **This is exactly what FIN-8, FIN-10 and QUO-1 were** — the RPC enforced, the table did not. ORVION reached the same conclusion independently; the citation is worth having because it names the class. |
| **State-based vs migration-based drift detection** — "with state-based you diff two schemas directly; with migration-based you must first replay history, then diff" | [Bytebase](https://www.bytebase.com/blog/what-is-database-schema-drift/), [Atlas](https://atlasgo.io/monitoring/drift-detection), [Liquibase](https://www.liquibase.com/blog/database-drift) | ORVION now does **both**: `db reset` replays history to produce the expected state, then Check L4/P4 diffs it against Primary. Before today it did only the first. |
| Property-based testing | — | **Rejected for now.** ORVION's invariants are already expressed as database constraints, which is a stronger guarantee than a generator that samples inputs. |
| Full contract-testing frameworks (Pact et al.) | — | **Rejected.** There is one consumer surface and it is generated from `pg_catalog`. A broker would be ceremony. |

### F. The verification model

The owner's proposed V0–V11 is **too many levels, and two of them are not levels at all**. What
survives contact with the evidence is **six layers plus an orthogonal evidence class**:

| Layer | Proves | Runs against |
|---|---|---|
| **L1 Repository** | files agree with each other | files only — *never* a database |
| **L2 Schema/state** | the database is what the migrations say | local, after reset |
| **L3 Behaviour** | rules hold, on every write path, for every actor | local (pgTAP) |
| **L4 Interface** | the door is reachable and refuses correctly | local over HTTP |
| **L5 Parity** | Primary is the same system as the repository | local ↔ Primary |
| **L6 External** | integrations behave | not yet buildable |

The owner's V3 (adversarial), V4 (direct DML) and V5 (RPC) are **not separate levels** — they are the
*paths* L3 must cover for one object, which is what the existing cross-path matrix already says.
V9 (clean reset) is not a level either; it is the **precondition** for L2–L4 meaning anything. And
V0 (documentation) is not verification at all: it is a claim awaiting one.

Cutting across all six, unchanged and still right, are the four verdicts — **PROVEN · UNPROVEN ·
FAILED · BLOCKED** — and the evidence classes (repository · database · Primary · HTTP · external ·
intent · inference). Those are what must never be collapsed, and they are the part of the owner's
model that is doing the real work.

### G–H. Guards and test rules added

Only what a demonstrated gap justified: **Check L4/P4** (PAR-3) and **the mutation pairs** (PAR-4).
No new guard script, no new governance document. `AGENTS.md §4` step 8b was updated because it
*names the parameters* a boot must pass.

### I. Continuity

**Assessed and found sufficient — no change needed beyond recording the new value.** `AGENTS.md §4`
is already a three-stage boot (Orient → Verify → Ready) that explicitly forbids trusting chat
history, and Checks 3, 6, 7, 9, 10 and 11 mechanically enforce that its routers resolve, its phase
agrees, its generated artifacts are fresh, its migration state matches the files, its session pointer
is current and its decision IDs exist. Building a second handoff mechanism would violate One
Authority for no gain. What *was* required: the manifest now records the structural hash, so the next
session knows what to compare Primary against.

### J. Rejected

Full mutation-testing tooling · property-based testing · a contract broker · a mechanical
vacuous-test detector (VER-2) · a runtime coverage file · raising the manifest budget · a separate
handoff document.

### K–L. Order, and effect on the roadmap

Done now because it is cheap and each was proven by reproduction: PAR-3, PAR-4, VER-1. Deferred with
a trigger: catalog-row parity (blind spot 2). **The roadmap is unchanged.** No migration was written,
no schema changed, no package was reordered. **API-3 remains the next executable item, with 25
endpoints and the booking/passenger family next**, exactly as `MASTER_EXECUTION_PLAN.md` had it
before this session.

---

## 8. Verification

| Axis | Result | Evidence class |
|---|---|---|
| Migrations | **165** — repository, local, Primary | repository + database + Primary |
| Ledger fingerprint | `6f6595de1f1d3d784457e6c60d882fd7` | read independently from both |
| Function surface (233) | `b511e0edeeec052514fead7ddea5e0ba` | read independently from both |
| **Structural surface (3,341)** | **`4bca45c73e058581190505ac878688fc`** | **read independently from both** |
| pgTAP | **73 files / 905 assertions / 0 failures** | local |
| Smoke | `ALL CHECKS PASSED (75 tables …)` | local |
| Repository guard | **CLEAN**, 12 checks | files only |
| Parity guard | **CLEAN exit 0**, all three Primary values supplied | local ↔ Primary |
| API contract | 71 endpoints, 46 with HTTP evidence — **unchanged** | repository |
| HTTP suites | **not re-run this session** — no database or endpoint changed | UNPROVEN, stated |

**The HTTP suites were deliberately not re-run.** This package changed no migration, no function and
no endpoint; the last proven result (259/259, 2026-08-29) still describes the system. Saying so is
the point — an untested claim is UNPROVEN, not green.

---

## 9. Classification

**PROVEN DEFECT (fixed)** — **PAR-3** (High, verification integrity), **PAR-4** (Medium),
**VER-1** (Low).
**INTENTIONAL (measured, rejected)** — **VER-2**.
**UNPROVEN (stated)** — catalog-row parity beyond `status_transitions`; HTTP suites not re-run.
**BLOCKED** — unchanged; no owner decision was consumed or created by this package.

**No business policy was invented, and no schema changed.**

---

## 10. Next executable step

**API-3, unchanged: the booking/passenger family — `create_booking_item`,
`link_passenger_to_booking_item`, `advance_booking_item`** — the densest remaining concentration of
money rules (commission derivation, per-passenger financial authority), audited by capability rather
than status code, and now with the mutation discipline available where an invariant is found.

**Evidence the next session must verify before trusting this one:** re-read all three Primary hashes
live (never pass the repository's own values back), run `db reset` before reading any structure from
local, and treat the HTTP row above as UNPROVEN until a suite is actually run.

**Phase position unchanged:** Phase 8 current; **Phase 10 NOT READY** — n8n holds zero workflows and
the Foundation Completion gate is shut. **SEC-1 still awaits owner ratification**; nothing is blocked
on it.
