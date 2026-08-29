# ORVION — The Program Reconciled Before Phase 10, and the Documents That Measured Themselves

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-30
Author: Claude Opus 5
Scope: Pre-Phase-10 program reconciliation per the owner's MASTER PROGRAM RECONCILIATION directive.
No migration. Phase 8/9/10 readiness determined from evidence; GOV-2…GOV-6 found and fixed; seven
orphan findings registered; consistency guard gained Check 11 and had three defects repaired inside
Check 2.
Status: Complete; verified, committed and pushed. **No product defect was found — every finding is
in the measuring, recording and governing layer.**

**Branch:** `main` · **Start HEAD:** `fc046e3` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective, and the one rule that shaped it

The owner asked for reconciliation before Phase 10, with an explicit instruction not to take the
starting hypothesis on trust: *"Treat the following as the starting hypothesis, NOT as unquestioned
truth: Phase 8 is complete. Phase 9 is complete. Phase 10 is next."*

**The first two halves of that hypothesis disagree with the evidence, and the disagreement is the
main result of this session.** Phase 9 is complete. **Phase 8 is not**, and no document in the
repository ever claimed it was — the roadmap and the manifest have both said *In Progress*
throughout. So the reconciliation's job was not to correct the repository toward the hypothesis but
to state plainly why the repository is right, and to make the reason impossible to miss next time.

Everything below was verified live before it was written down. Where I could not verify something, it
is marked UNPROVEN rather than narrowed.

---

## 2. Findings matrix (directive §23)

| Area | Current state | Evidence | Conflict | Action | Owner input |
|---|---|---|---|---|---|
| Repository | HEAD `fc046e3`, clean, = `origin/main` | `git status`, `git rev-parse` | none | — | no |
| Local Supabase | 160 migrations, fp `9e5fb52c…` | live query | none | — | no |
| Primary Supabase | 160 migrations, fp `9e5fb52c…`, surface `d98abbdd…` (230 fn) | live query **on Primary** | none | — | no |
| Parity | **PROVEN** on ledger + full function surface + API contract | `check_database_parity.ps1` L1/P1/L2/P2/L3 | none | — | no |
| Phase 8 | **In Progress** — n8n holds **0 workflows** | live n8n query | hypothesis said complete | roadmap rewritten with the reason isolated | **yes — release the gate** |
| Phase 9 | **Complete**, all six outputs live | 8 `reporting` views, live | none | acceptance recorded in the roadmap | no |
| Phase 10 | **NOT READY** | Phase 8 incomplete + gate shut | hypothesis said next | verdict + prerequisites written into canon 32 | **yes** |
| Roadmap (canon 32) | Phase-8 block said "Primary carries 90 migrations"; gate list named AUDIT-3, resolved 08-24 | live vs text | stale current-state claims | rewritten; live state now referenced, not restated | no |
| Master plan | Header dated 2026-07-15 while content ran to 08-29; two open items already closed | live query | **intra-document contradiction** | GOV-6 fixed; header dated | no |
| Gap register | Header dated 08-21 while rows ran to 08-29; **7 findings defined elsewhere had no row** | ID sweep | SSOT violation (`GOVERNANCE.md §2`) | GOV-3: 7 rows added + Check 11 | no |
| Reports index | Folder counts 14/5/34 vs real 15/5/78 | `ls` | stale | counts removed, API contract listed | no |
| Certification status | Recorded Primary at **90 migrations** — and it is the newcomer's *first* document | live query | 70 migrations stale | GOV-5: restatement removed | no |
| Repository health | Primary 90 migrations, HEAD `c5590c4`, invariants missing Checks 9–11, parity guard absent | live | stale + incomplete | GOV-5 + registry completed | no |
| Domain catalog | 2026-07-15 counts presented as current ("0 views"; there are 8) | live | stale | dated as a design snapshot | no |
| Governance | `MASTER_API_CONTRACT.md` Living-Authoritative with **no SSOT row** | `GOVERNANCE.md §2/§5` | unregistered authority | GOV-2 fixed; v1.9 → v1.10 | no |
| Guards | Check 2 blind to every ID minted since 2026-07 | probe | guard measured less than it claimed | GOV-4 fixed (three defects) | no |
| API surface | 71 RPCs + 8 views + 71 tables; 41/71 with HTTP evidence | generated contract | none | API-3 continues | no |
| CRM journey | 235 HTTP assertions green across six suites | live run | none | — | no |
| Integrations | n8n 0 workflows; credentials **present but never observed to authenticate** | live | none | left UNPROVEN, not narrowed | **yes** |
| Business decisions | 25 open ids; 5 had no register row | ID sweep | manifest promised otherwise | registered; none invented | **yes** |
| Engineering debt | no new avoidable product defect found | full sweep | — | — | no |

---

## 3. Is Phase 10 ready? No — and the two reasons are one reason

**Verdict: NOT READY.**

1. **Phase 8 is not complete.** Its sole remaining deliverable is the n8n workflow. Queried live:
   **the instance holds zero workflows.** Nothing delivers a conversion to Google Ads, so the
   founding feedback loop the phase exists to close is open.
2. **The Foundation Completion Programme gate is still shut** (owner-directed 2026-08-21). Batch 6
   carries open engineering items and open owner decisions, **SEC-1**'s write-path architecture
   chief among them.

**These are the same blocker seen twice.** Phase 10's own first listed output is *"n8n workflows"*,
and Phase 8's remaining deliverable **is** an n8n workflow. Starting Phase 10 now would mean
building Phase 8's deliverable under a different label — changing the name of the work, not its
dependency. That is why the roadmap now says so in the Phase 10 block itself, where someone about to
start it will actually look.

**What is *not* blocking, checked rather than assumed:** Phase 9 (all six outputs re-proven live);
the database foundation (parity proven on three axes); API reachability (71 endpoints live — API-3's
30 uncovered endpoints are a *coverage* debt, not a reachability one); and the architecture itself,
which does not make Phase 10 impossible — **CONV-3** already records the one real gap, the missing
session-less inbound door, as integration-phase work with an in-house precedent.

**Phase 9 acceptance, re-proven rather than inherited:** the `reporting` schema holds 8 views, each
exposed over HTTP and pinned by name in `53_api_surface_test.sql`, and all six required outputs map
to one — lead performance, sales activity, booking pipeline, outstanding balances (customer +
supplier), profit by booking item, subscription state. The eighth, `my_sales_performance`, arrived
later with SPEC-159.

---

## 4. The through-line: this time the defects were *entirely* in the meta-layer

The previous session's lesson was that three of its findings were defects in the things that
*measure*. This session went looking for product defects across the whole program and found **none**
— and six defects in the layer that records and governs the product. That is worth stating plainly
rather than dressing up as a clean bill of health: **the engineering is in better shape than the
bookkeeping about the engineering.**

### GOV-2 — a Living authority nobody registered

`MASTER_API_CONTRACT.md` was created 2026-08-29 as a Living-Authoritative Master. It was never given
an SSOT row in `GOVERNANCE.md §2` or a registry entry in `§5`, and `§5` still counted "14" Masters
while 15 existed. Nothing recorded that the file is **generated**, that
`scripts/generate-api-contract.ps1` owns it, or that hand-editing it is a defect — so the one
property that makes it trustworthy was undocumented in the document that governs trust. Fixed, and
GOVERNANCE advanced v1.9 → v1.10 through its own §15 lifecycle rather than edited silently.

### GOV-3 — seven findings the register never held

`GOVERNANCE.md §2` is explicit: the gap register is SSOT for accepted findings, and *"ALL other
Masters reference finding **IDs**, never restate the finding."* Seven findings were **defined** in
`MASTER_EXECUTION_PLAN.md` and had no register row at all: **LIC-1, DEAD-1, DEAD-2, BLOCKED-4,
BLOCKED-5, CANON-26-1** — and **A3**, whose real home is `MASTER_ARCHITECTURE_DECISIONS.md`.

Five of them are ids `manifest.md` raises as open owner decisions, on a line that promises *"every
definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`."* **That promise was false
for one id in five**, and the boot sequence walks exactly that path: a fresh agent told to look up
LIC-1 or BLOCKED-4 reached a dead end in the governance chain.

All seven now carry rows. A3's is deliberately a **pointer** row — restating it would have created
the second authority §2 exists to prevent — which also settles the design question for the guard:
one lookup path, no special cases.

Worth separating, because the names invite conflation: **DEAD-1 has no reader and is INTENTIONAL**
(per-passenger pricing is inevitable structure, `AGENTS.md §3`); **DEAD-2 has no writer and is
OPEN** — `refunds.booking_item_id` and `payments.booking_item_id` express an attribution the finance
domain needs and nothing populates. Only one of the two loses information.

### GOV-4 — the check that could not see a month of findings

`check_repository_consistency.ps1` Check 2 detects a finding shown OPEN in one place and resolved in
another. Its ID pattern enumerated the 2026-07 prefixes literally:

```
DC- | R | A | B | N | CDD- | BF- | RC- | OPS- | INV-
```

It therefore matched **none** of the IDs minted since — SEC, FIN, ATTR, CONV, LEAD, SCHED, TRANS,
API, PAR, TEST, GOV, DOC-EXP — while still printing a verdict every run. Every report in the last
month cited a CLEAN that was, for those findings, structurally unable to fail.

This is the class the programme keeps re-finding: **a guard written against the first instance takes
that instance's shape** — SEC-1b's trigger-timing ceiling, `54_transition_permission_parity_test`'s
regex that read one function out of ten, and now this.

**Widening it immediately exposed two more defects inside the same check**, which is the part worth
keeping:

1. **A false positive, instantly.** It reported AUDIT-2 as contradicting itself. AUDIT-2 is
   legitimately OPEN; its *title* prose reads "(`subscription_plans` itself resolved by SPEC-120)" —
   about a different object — and the resolved-marker test matched the whole line, case-insensitively.
   Fixed by requiring the marker to **lead a table cell**, the same discipline the OPEN test already
   used. The script's header demands precision over recall — *"it must not cry wolf, or agents will
   learn to ignore it"* — so a widened check that cried wolf on its first run would have been worse
   than the narrow one.
2. **A false negative that mattered more.** A cross-line probe did **not** fire. The check read a
   detail block's verdict only from its `###` heading — but the register overwhelmingly writes the
   verdict as a `- **Status:** FIXED` field on a body line. **The row-vs-detail contradiction Check 2
   was built for (the DC-16 bug) was invisible in the exact form the register actually writes.**
   Fixed by tracking the current block and reading its Status field.

Proven in both directions afterwards: a synthetic modern-prefix contradiction fires; the real
register reports zero; the probe was removed.

### GOV-5 — four documents that restated live state, and all four went stale

| Document | What it claimed | Reality |
|---|---|---|
| `MASTER_CERTIFICATION_STATUS.md` | Primary at **90 migrations** | 160 |
| `MASTER_REPOSITORY_HEALTH.md` | Primary 90; HEAD `c5590c4`; 72 tables / 63 app fn / 7 views; 34 history reports | 160; `fc046e3`; 75 / 154 / 8; 78 |
| `MASTER_DOMAIN_CATALOG.md` | 71 tables, **0 views**, 55 RPCs (as current) | 75, 8, 71 |
| `reports/README.md` | master 14 · history 34 | 15 · 78 |

`MASTER_CERTIFICATION_STATUS.md` is the document `reports/README.md` sends a newcomer to **first**.
The first thing a fresh reader met was seventy migrations out of date.

**The fix is removal, not refreshment**, and that distinction is the whole finding. `GOVERNANCE.md
§2`: *"Every other mention must reference it by pointer, never restate it."* Restating live state is
the defect; updating the copies would have reset the same trap for whoever came next. So
certification and health now point at the manifest and keep only what they genuinely own; the domain
catalog's numbers are **dated as the 2026-07-15 design snapshot they are** and kept, because the
domain map was drawn against them and deleting them would strand the analysis from its basis; the
README's folder counts are gone, because a count that must be hand-maintained every commit is a
stale number waiting to happen and `ls` answers it exactly.

Two genuine gaps surfaced while doing it. `MASTER_REPOSITORY_HEALTH.md §2b` calls itself *"a single
discoverable list of every automatic check"* and was missing Checks 9, 10 and 11 — **and the entire
`check_database_parity.ps1` guard**. Worse, its framing (*"If one fails, CI is red"*) would have been
false for parity: **no CI job can reach Primary**, so the three live-parity invariants are session
gates, not CI gates. They are now listed under their own heading saying exactly that, because a
reader who assumes "listed ⇒ enforced by CI" would have been wrong about the only guard that watches
production.

### GOV-6 — two open items that later packages had already closed

- *"`public.security_events` has zero producers"* — it has **four**, all from SPEC-158 on 2026-08-27.
  **This contradicted item 1c of the same document**, which records SPEC-158 giving the table "its
  first producers". An intra-document contradiction that survived because Check 2 could not see the
  ID (GOV-4) and nothing checks prose open-items against the database.
- *"`notifications` / `notification_deliveries` have no producer at all"* — `notifications` gained
  `app.process_lead_sla` on 2026-08-29 via SLA-1.

The second is **narrowed, not deleted**, and the narrowing is the useful part: `notification_
deliveries` still has no producer — nothing records that a notification was actually *delivered* on
any channel — and `process_lead_sla` remains the only writer of `notifications`, which is precisely
why an expiring passport notifies nobody (**DOC-EXP-1**). One engineering gap plus one owner
decision, not a single undifferentiated hole.

The `security_events` item is struck through rather than deleted: the 13 *authentication* event
types are still Supabase Auth events with no ORVION hook, which is **AUTH-1**'s territory.

---

## 5. Check 11 — the new guard

Every open-decision ID `manifest.md` raises must resolve to a row in `MASTER_GAP_REGISTER.md`.

Proven in both directions before shipping. Against the repository as found:

```
ORPHAN ID: manifest raises 'A3' but MASTER_GAP_REGISTER.md defines no such finding
ORPHAN ID: manifest raises 'BLOCKED-4' ...
ORPHAN ID: manifest raises 'BLOCKED-5' ...
ORPHAN ID: manifest raises 'CANON-26-1' ...
ORPHAN ID: manifest raises 'LIC-1' ...
```

After the seven rows landed: `all 33 manifest decision IDs resolve in the register`.

**Checks 1, 10 and 11 are three different questions about a reference, and none substitutes for
another** — does it *resolve* (1), is it the *current* one (10, GOV-1 yesterday), and does the ID the
boot sequence is told to look up actually *exist* (11). Each was found only after the previous one
had been declared sufficient, which is itself worth remembering.

Deliberately **not** built: a rule that every history report be indexed, or that every finding ID
anywhere in any Master resolve. The first was rejected yesterday for good reason (77 reports, ~60
never indexed — noise, not signal); the second would fire on historical narrative prose that
legitimately mentions ids in passing. The guard encodes the convention that exists.

---

## 6. What I did NOT change, and why

- **No migration, no schema change, no permission change.** The reconciliation found no product
  defect, and manufacturing one to justify a migration would be the opposite of the directive.
- **No third roadmap.** Canon 32 owns phases; `MASTER_EXECUTION_PLAN.md` owns batches. The
  relationship was already correct and is left alone.
- **No new ownership-map document.** The directive asked for an explicit ownership map; `GOVERNANCE.md
  §2` already **is** one. Adding a second would have been the duplicate authority §2 forbids, so the
  work went into *fixing* §2 (GOV-2) rather than into a parallel copy.
- **No history rewritten.** Historical statements that were true when written — "137 `app` functions"
  in the API-1 record, "all 228 functions" in PAR-1 — are left exactly as they are. Only
  **current-state claims** were corrected. The register's and plan's superseded header entries are
  preserved beneath the new ones.
- **No business policy invented.** Every blocked decision was re-searched per directive §10; none
  proved newly derivable. The six resolved on 2026-08-29 stay resolved. **FIN-7, DOC-EXP-1, SEC-1,
  SCHED-1, RET-1/2, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3, PH8-2, TRANS-1, BLOCKED-4/5,
  CANON-26-1, A3, LIC-1** remain blocked on facts that are genuinely external or genuinely the
  owner's.
- **n8n credentials left UNPROVEN.** They are verified *present*; neither has been observed to
  authenticate, and neither's target or scope is independently verified. I did not narrow that to
  "ready".

---

## 7. Verification

| Axis | Result |
|---|---|
| Migrations | **160** — repository, local, Primary |
| Ledger fingerprint | `9e5fb52c92ce30a8b6d0559be3da7110` — read independently from local **and** Primary |
| Function surface (230) | `d98abbdd9aea724630f2d97f91a21b08` — identical both sides |
| pgTAP **Pass A** (fresh `db reset`) | **68 files / 816 assertions / 0 failures** |
| pgTAP **Pass B** (post-HTTP residue) | **68 files / 816 assertions / 0 failures** |
| End-to-end HTTP | **235/235** — storage 43 · api 29 · branches 26 · roles 27 · lifecycle 72 · care 38 |
| Smoke | `ALL CHECKS PASSED (75 tables, … 71/601 catalog …)` |
| Repository guard | **CLEAN**, now 11 checks |
| Parity guard | **CLEAN** — ledger, full function surface, API-contract freshness |
| n8n | **0 workflows**, 2 credentials (presence only) |

Parity was re-run *after* a clean `npx supabase db reset`, which is the only state in which local
equals the repository (**PAR-1b**) — so the comparison means what it says.

---

## 8. Classification

**FIXED (governance/guard)** — GOV-2, GOV-3, GOV-4 (three defects in one check), GOV-5, GOV-6.

**REGISTERED, not newly decided** — A3, LIC-1, BLOCKED-4, BLOCKED-5, CANON-26-1, DEAD-1
(INTENTIONAL), DEAD-2 (OPEN).

**DETERMINED from evidence** — Phase 9 complete; Phase 8 In Progress; **Phase 10 NOT READY**.

**UNPROVEN (stated, not narrowed)** — n8n credential authentication and scope.

**BLOCKED — unchanged.** No previously blocked decision became derivable this session.

**NOT FIXED, deliberately** — `notification_deliveries` has no producer (engineering, queued in
Batch 6); the 13 authentication event types have no ORVION hook (AUTH-1, owner).

---

## 9. Next executable step

**DOC-LC-1** — wire canon 26's Document Lifecycle machine into `app.status_transitions` and attach
`enforce_status_transition`. It is derivable (`ARCHIVE_DOCUMENT` for `→ archived`,
`CREATE_DOCUMENT_VERSION` for `→ superseded`, both read from the existing writers), bounded, and the
last canon-defined state machine with no runtime wiring. Then **API-3** (30 endpoints left;
`create_journal_entry` and `merge_customer_identity` next), then Batch 6's remaining engineering
items.

**Next broader phase:** Phase 8 remains current. Phase 10 does not begin until the owner releases the
Foundation Completion gate and the n8n workflow is built and verified against
`MASTER_INTEGRATION_CATALOG.md §2` with its `§2a` corrections.

**The single decision that would unblock the most:** **SEC-1** — the write-path architecture. It is
the largest open item, it is part of the Phase-8 gate, and it has been open since 2026-08-28.
