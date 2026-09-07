# Batch 6 slice 5 — `booking_items`: the booked service that had no door of its own

Class: History (immutable)
Date: 2026-09-07
Migration: `202607061500_the_booked_service_itself_had_no_door.sql`
Test: `supabase/tests/105_booking_item_service_door_test.sql` — 44 assertions, ten attack classes, none N/A
Guard added: Check 25 (`scripts/check_repository_consistency.ps1`)

---

## 0. HANDOFF

- **INHERITED** — `BOOK-3` (High, OPEN), recorded by slice 4 as the parent-table twin of PAX-1, with a stated
  reason for deferral and a stated obstacle.
- **PROVEN** — all five `booking_items` defects were reproduced behaviourally on the live local stack BEFORE any
  repair, four of them by attacks slice 4 had not anticipated. Every repair is verified by a 44-assertion pgTAP
  file, mutation-tested in both directions, and re-verified through all six HTTP journey suites (430 assertions).
  Local, repository and Primary carry identical ledger, function and structural hashes.
- **UNPROVEN** — nothing in this slice is claimed without a behavioural or catalog measurement. Two items are
  recorded as *residuals with assertions that assert the residual* rather than as proven-safe: `BOOK-9` (an
  ownership grab without money still succeeds for a capability holder — assertion 15 asserts that it SUCCEEDS)
  and the currency guard's silence on genuinely unpriced items (assertion 26).
- **CHANGED** — three `app` functions (`enforce_booking_item_lifecycle`, `guard_booking_item_financials`,
  `guard_write_capability`), one new trigger on `public.booking_items`, one new pgTAP file, two guard-of-guard
  tests updated with reasons, one new consistency check, and the governance set.
- **DO NOT TOUCH** — the seven-permission UPDATE arm. Each entry is read out of an enforcer that already exists.
  Removing `APPROVE_FINANCE`, `EDIT_LOCKED_COST`, `ARCHIVE_RECORD` or `ASSIGN_SUPPLIER` locks `finance_manager`
  out of work it legitimately does on items it does not own; assertions 28-31 are that lockout, in test form.
- **REMAINING** — `BOOK-8` (business), `BOOK-9` (canon). Neither is engineering.
- **NEXT** — Batch 6 slice 6, `branch_business_hours` (selector top rank, score -4).

---

## 1. Preflight, and the discrepancy that mattered

Repository, local stack and Primary all verified at 203 migrations, `HEAD == origin/main == 6ee6392`, working
tree clean. No discrepancy in state.

**The discrepancy was in the record, not the state**, and it was load-bearing. `BOOK-3`'s own register row
explained why slice 4 had not repaired it:

> the UPDATE arm needs the CUST-3 treatment (finance holds `ENTER_COST` without `CREATE_BOOKING_ITEM`)

Measured against the live database before it was believed:

| Permission | Roles holding it |
|---|---|
| `CREATE_BOOKING_ITEM` | branch_manager, ceo, department_manager, employee, owner, senior_employee |
| `ENTER_COST` | branch_manager, ceo, department_manager, employee, owner, senior_employee |
| `ENTER_SELLING_PRICE` | branch_manager, ceo, department_manager, employee, owner, senior_employee |
| `UPDATE_BOOKING_ITEM_STATUS` | branch_manager, ceo, department_manager, employee, owner, senior_employee |
| `APPROVE_FINANCE` | ceo, finance_manager, owner |
| `EDIT_LOCKED_COST` | ceo, finance_manager, owner |
| `ARCHIVE_RECORD` | branch_manager, ceo, department_manager, finance_manager, owner |
| `ASSIGN_SUPPLIER` | branch_manager, ceo, department_manager, finance_manager, owner, senior_employee |

`finance_manager` holds **neither** `ENTER_COST` nor `CREATE_BOOKING_ITEM`, and the two are held by exactly the
same six roles. The stated obstacle did not exist. The **real** constraint is its mirror image: finance locks
cost, approves, archives and assigns suppliers on items it does not own — so the UPDATE arm must carry those
four or the repair locks finance out.

`105_...` assertion 4 is a `set_eq` pinning the two role sets, so the claim cannot decay again; if canon ever
separates them, the suite fails and the arm must be revisited.

---

## 2. The five findings, and how each was reproduced

Every one was measured before a line of the migration was written. Static reading produced the leads; none of
them was accepted as a verdict (`MEAS-1`).

### BOOK-3 — High. The booked service had no door.

`app.create_booking_item` charges `CREATE_BOOKING_ITEM`. The table charged nothing.

- A `finance_manager` INSERTed a bare item by direct DML; it persisted.
- A `trainee` — holding **none** of the eight booking-item permissions — did the same; it persisted.
- The UPDATE half was **wider than the register recorded**: on a row the actor owned, `service_type_code` and
  `currency_code` were rewritten, `owner_user_id` was seized, and the item was moved onto a different booking of
  the same tenant. No RPC offers any of those, and none cost anything.

### BOOK-4 — Low. A cross-tenant existence-and-state oracle.

`app.enforce_booking_item_lifecycle` is SECURITY DEFINER, looked its parent up by id alone, and BEFORE ROW
triggers run before the RLS `WITH CHECK`. Three probes, one distinguishable:

| Target booking | Answer before |
|---|---|
| foreign, CANCELLED | `23514 cannot attach a booking item to a cancelled booking` |
| foreign, ACTIVE | `23503` (composite FK) |
| does not exist | `23503` (composite FK) |

The first leaked both existence and state of another tenant's booking. Repaired by scoping the lookup to
`app.current_tenant_id()`. **The `new.tenant_id` draft was rejected for the reason it was rejected in slice 4:
the attacker supplies it.**

### BOOK-5 — High, and the finding of the slice.

`app.guard_booking_item_financials` computed canon-28 assignment scope from `new` on both paths. On UPDATE that
is the row the attacking statement just wrote. Reproduced as a **discriminating pair**, one clause apart, by an
`employee` who genuinely holds `ENTER_COST` and was not assigned the item:

```
update booking_items set cost_amount = 555 where id = e1;
  -> REFUSED: ENTER_COST is scoped to items assigned to you (canon 28: assigned)

update booking_items set owner_user_id = <self>, sales_owner_user_id = <self>, cost_amount = 555 where id = e1;
  -> SUCCEEDED
```

Ground truth read as `postgres`, not through the attacker's own RLS (slice 4's test-12 lesson): `cost_amount`
100 → 555, ownership seized.

The repair is four lines: on UPDATE the scope is taken from `old`. On INSERT there is no pre-image and none is
wanted — the creator naming themselves is the normal act and already costs `CREATE_BOOKING_ITEM` at the door.

### BOOK-6 — Medium. The execution gate was clearable.

`advance_booking_item` refuses execution while `finance_approval_required` is true and the approval is not
`approved`. Nothing guarded the column.

**A first probe of this was a no-op and is recorded rather than discarded.** The column is `NOT NULL DEFAULT
false`, so setting it to `false` on a fresh fixture changed nothing and raised nothing — it *looked* like a
successful attack and was neither. Re-run against a row where the flag was genuinely raised, the clearance took.
That is the vacuous-evidence class in its most dangerous direction: a probe that appears to confirm a finding it
never tested.

Authority read out of the RPC surface, not invented: `create_booking_item` sets it at birth,
`request_finance_approval` raises it under `CREATE_BOOKING_ITEM`, `advance_booking_item` only reads it, and
**nothing lowers it**. So raising is priced at what the RPC charges and lowering is refused. Whether a
requirement may *ever* be withdrawn is **BOOK-8**, and it is deliberately not answered.

### BOOK-7 — Medium. A priced item could be redenominated.

`currency_code` was unguarded, so EGP 100 became USD 100 without touching a guarded column. `MONEY-1` /
`SUP-4a` / `CA-2`'s family: canon 30 makes the amount and its currency one value.

**The first draft was a tautology and re-running the probe caught it.** Written as `old.cost_amount is not
null`, which is always true because both money columns are `NOT NULL DEFAULT 0` — it would have charged
`ENTER_COST` for the currency of every bare item ever created. Assertion 26 is the anti-tautology control.

---

## 3. Repair shape

One migration, three functions, one trigger. No second authorization engine, no per-column authority model, no
invented permission.

- `booking_items` joins the tables priced by `app.guard_write_capability`, base arm `CREATE_BOOKING_ITEM`.
- The UPDATE arm is a **floor** — "hold some authority over booked services" — carrying the seven permissions
  the existing enforcers already charge. Per-column rules stay where they live: money in
  `guard_booking_item_financials`, archive in `enforce_archive_authority`, status in `enforce_status_transition`.
- No DELETE arm, measured rather than assumed: `authenticated` holds INSERT and UPDATE and no DELETE grant.

---

## 4. Adversarial coverage

| Class | Where | Evidence |
|---|---|---|
| AUTH | 2-6, 10 | trainee holds none of the eight; refused outright |
| TENANT | 32-35 | rival cannot see; `tenant_id` rewrite refused by RLS; foreign re-parent refused by composite FK |
| DOOR | 7-12, 38 | RPC and table both priced; trigger fires on INSERT *and* UPDATE |
| STATE | 12, 21 | row-hop refused; own cancelled booking still refuses attachment |
| INPUT | 25-27 | currency change priced on a priced item, silent on an unpriced one |
| BUSINESS | 22-24 | the finance gate may be raised, never withdrawn |
| CONCURRENCY | 40 | the scope decision is taken from the row version the statement locked |
| REPLAY | 39 | no uniqueness on any business column — DC-2, pinned not claimed |
| PRIVILEGE | 13-16, 36-37 | scope self-assignment closed; no PUBLIC EXECUTE; `search_path` pinned on all three |
| OBSERVABILITY | 17-21 | three foreign-booking probes now answer identically |

**Two assertions were rewritten during authoring because the first versions were tautologies** — `count(distinct
...)` over literal values, restating what the `throws_ok` calls above them already pinned. They were replaced
with real coverage (the BOOK-9 residual, and the oracle's UPDATE entrance). This is recorded because writing a
vacuous assertion while explicitly hunting vacuous assertions is the failure mode worth remembering.

## 5. Mutation results

| Mutation | Result |
|---|---|
| drop `booking_items_guard_write_capability` | assertion 10 fails; trainee books freely again |
| restore the `new`-image scope computation | assertion 14 fails; the ownership grab works again |
| remove the tenant predicate from the lifecycle trigger (external) | assertions 17 and 20 fail |
| all restored | **44/44 PASS** |

Each in-file mutation is rolled back and RE-asserted (TEST-3), so the file leaves the schema byte-identical to
the migration (PAR-2).

## 6. Guard-of-guard

Two existing tests **caught this change and were updated with reasons, not silenced**:

- `10_grant_model_test` assertion 9 (MEAS-2): the bespoke-guard population fell **ten → nine**, because
  `booking_items` acquired the unconditional guard and left by construction. That is how the number is meant to
  move.
- `58_write_grants_and_config_capability_test` assertions 25-26: 26 → 27 tables, allowlist extended.

## 7. What was NOT done, and why

- **BOOK-8** — business. Whether a finance-approval requirement may ever be withdrawn. The shipped behaviour is
  the conservative reading; an RPC follows the answer and the door does not need reopening for it.
- **BOOK-9** — canon. Canon 28 gives leads `ASSIGN_LEAD` and `REASSIGN_LEAD` and gives booking items neither.
  Assertion 15 asserts the residual *succeeds*, so it is a recorded fact rather than a blind spot.
- **PAX-4's other 19 tables** — each needs its own slice; inventing 20 mappings in one migration is what this
  programme forbids.

## 8. Governance, and the two fixes that were not the target

Reconciling **PAX-5** across the Masters, as instructed, ran straight into a contradiction: PAX-5 was registered
as an open owner/business decision while `manifest.md` read *"Open owner decisions — MAIL-1, and nothing else."*

- **GOV-19 FIXED** — `CAT-6` sat under two rows with opposite verdicts. Its engineering half had been settled by
  SPEC-141 on 2026-08-24 and the register never caught up for fourteen days. Re-assessed live from
  `pg_constraint`, per column. This had to go first: GOV-19 itself recorded that CAT-6 must not reach the
  manifest's decision line while the register contradicted itself.
- **GOV-16 FIXED — Check 25.** The 2026-09-04 census was right to leave this unwritten and its reason became the
  design: bind *decisions*, not open rows. The mechanical signal was already in the register's eleventh column,
  which either names a decider or carries a queue position. **First run measured seven rows awaiting a decider
  against a manifest naming one.**
- **Check 25's own first draft carried the MEAS-2 defect** and running it is what found that: testing the whole
  status cell for resolution words silently exonerated three of the six, because `MONEY-2` and `PAX-5` cite
  *other findings'* resolutions deep in their prose. Anchored to the cell's opening 80 characters.

**PAX-5 itself remains open, and that is the evidence-backed answer, not a deferral.** Canon 31 defines
`booking_item_passengers` as "Links passengers to booking items" with no immutability rule; canon 26 defines the
item state machine including `issued`/`reissue` without mentioning the manifest; canon 28 assigns the lifecycle
authorities and says nothing about `passenger_id`. Both halves of the question — the freeze point and the
overriding permission — are commercial.

## 9. Verification

- 204 migrations replayed clean from scratch.
- pgTAP **105 files / 1646 assertions**, Pass A = Pass B.
- Six HTTP suites **430 passed / 0 failed** (29 + 40 + 74 + 107 + 120 + 60).
- Smoke: `ALL CHECKS PASSED (77 tables …)`.
- `REPOSITORY CONSISTENCY: CLEAN` (Checks 1-25).
- `DATABASE PARITY: CLEAN`.

| Surface | Local | Primary |
|---|---|---|
| migrations | 204 (`202607061500`) | 204 (`202607061500`) |
| ledger | `e9549f90784fb38b0924b6353a56d94f` | `e9549f90784fb38b0924b6353a56d94f` |
| functions | `8c012ce5ee5749923d94c0d54e6b867f` (277) | `8c012ce5ee5749923d94c0d54e6b867f` (277) |
| structure | `a48b275de685f89c073058de385d3ad8` (3,563) | `a48b275de685f89c073058de385d3ad8` (3,563) |

All ten structural sub-surfaces matched individually, not only in the combined hash. Primary's values were read
**from Primary**, via the same `scripts/parity_surface.sql` both sides run (GUARD-1, PAR-1a).

**One deployment-order note, recorded because it is RECOVER-1's exact hazard:** `202607061500` was applied to
Primary before it was committed and pushed. It was committed and pushed in the same session, and the
current-state report of the same date records the closing evidence. Applying before committing is the sequence
that created the 2026-09-02 divergence and should not be repeated.

## 10. Next

**Batch 6 slice 6 — `branch_business_hours`** (selector top rank, score -4). Every remaining candidate now
scores negative, which says the ranking has stopped discriminating rather than that the surfaces are safe;
slices 4 and 5 both found High defects inside green ceilings, and the selector subtracts coverage.
