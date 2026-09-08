# Batch 6 slice 8 — `lead_interactions`: the contact log that could be moved onto another lead, and the measuring layer audited against its own rule

Class: History (immutable)
Date: 2026-09-08
Migration: `202607061800_an_interaction_log_that_could_be_moved_and_rewritten.sql`
Test: `supabase/tests/108_lead_interaction_log_integrity_test.sql` — 15 assertions, ten attack classes, one declared `N/A` with a reason
Consolidation: seventh adversarial-loop rule recorded in `MASTER_EXECUTION_PLAN.md`; `scripts/batch6_select_target.ps1` ranking repaired; `107_...` assertion 15 semantics corrected and widened; `75_...` assertion 25 added; `MASTER_GAP_REGISTER.md` Status vocabulary closed and IDENT-3 narrowed

---

## 0. HANDOFF

- **INHERITED** — two things, and both turned out stale. (a) The manifest named `lead_interactions` as the
  next slice on the grounds that "the selector no longer discriminates". True, but the reason recorded was
  wrong, and finding the real reason repaired the selector (§ 4). (b) `202607056100` §3 recorded this table
  as *"BLOCKED, BUSINESS DECISION … the RPC and direct DML charge exactly the same thing, which is nothing."*
  **Both halves are now false, in opposite directions** (§ 2).
- **PROVEN** — reproduced at `aal1` as an `employee` who is not the handler and holds no `ASSIGN_LEAD`, with
  the actor asserted as the first statement of the battery (`current_user = authenticated`, `auth.uid()`
  resolved, `app.current_user_id()` resolved, `has_permission('ASSIGN_LEAD') = false`). **LI-1**: handler B's
  private interaction re-parented onto handler A's lead, still attributed to B — confirmed against ground
  truth read as `postgres` after `reset role`. **LI-2**: `interaction_at` backdated to 2001-01-01 and
  `summary` replaced. Equally proven are the four controls that HELD — cross-handler INSERT refused 42501 on
  *both* doors, invented vocabulary refused 23514, forged `user_id` overwritten with the caller's real id —
  and they are why LI-1 is High and not Critical. Verified by 15 assertions, mutation-tested (restoring the
  UPDATE grant fails **4 of 15**, including the ground-truth read), and re-verified through the full suite:
  **108 files / 1,694 assertions**, Pass A = Pass B.
- **UNPROVEN** — nothing here is asserted without a behavioural or catalog measurement. Three inferences are
  labelled where they are drawn: `107_...` assertion 15 matches function TEXT and cannot see application-layer
  code (§ 3); the selector's `coverage` remains a file-co-occurrence proxy and is now *documented* as one
  rather than repaired, because its only consumer is a human reading a ranking (§ 4); and LI-3's failure
  direction is argued from the SLA reading `last_contact_at`, not from a reproduced escalation (§ 2).
- **CHANGED** — one migration (a single `revoke`, plus a table comment), one new pgTAP file, one guard
  strengthened (`75_...` 25), one assertion's semantics corrected and widened (`107_...` 15), the selector
  script, the governance set, a regenerated `ai-map.json`, and **`MASTER_API_CONTRACT.md`, which DID change
  this time**: `lead_interactions` moved `SIU-` → `SI--`. One line, regenerated, never hand-edited.
- **DO NOT TOUCH** — the `INSERT` grant on `lead_interactions`. `app.record_lead_interaction` is SECURITY
  INVOKER, so that grant *is* the sanctioned path; widening this slice's revoke to `revoke insert, update`
  breaks the RPC, and assertions 9-10 exist to fail loudly if anyone tries. Also do not "fix" `107_...`
  assertion 15's over-matching of the two `emit_*` helpers: it is a tripwire and errs toward review
  deliberately (§ 3). Also unchanged and deliberately so: `public.totp_enrollments` (§ 5).
- **REMAINING** — nothing from this slice is unfinished, and nothing is left undocumented. Genuinely open,
  each recorded where it belongs: **LI-3** (the door enforces the RPC's authority and none of its derived
  state) is registered, argued, and pinned by `108_...` assertion 14, which is written to FAIL when LI-3 is
  repaired so the row cannot drift. `public.totp_enrollments` remains owner-writable with no writer — the
  only such table in the schema — classified, not repaired, for the reason in § 5. The pre-existing debt list
  (`ai-map.json` timestamp churn, RECOVER-1's residual process gap, DISP prose residual, PAX-4's remaining
  members, CUST-6, IDENT-2, DELIV-1, GOV-20, DOC-LC-3, PH8-2, RBAC-6, and the three dead catalog families
  named in `12_...` assertion 9) is unchanged by this session.
- **NEXT** — **Batch 6 slice 9: `leads`.** Ranked, not derived — the first slice since the selector was
  repaired, and `leads` tops the exposure ordering at **22**, the highest on the board. It is also where this
  slice's sibling sweep left a live question: `app.enforce_status_transition` authorizes a `leads` transition
  by reading `new.assigned_user_id`, and the only thing that refuses the seize is
  `leads_owner_matches_assignee_chk` — an incidental constraint, not a deliberate answer (§ 3).

---

## 1. What the surface is

`lead_interactions` is the contact log for a lead: who spoke to the customer, when, of what type, with a
free-text summary. Nine columns, one composite FK to `leads (tenant_id, id)`, one RLS policy for ALL commands,
and — before this slice — `INSERT`, `SELECT` and `UPDATE` granted to `authenticated`.

It carries four `BEFORE` triggers, and reading them is what corrected the inherited note:

| Trigger | Fires | What it does |
|---|---|---|
| `lead_interactions_guard_handler_authority` | INS, UPD | `app.require_lead_handler(assigned_user_id of new.lead_id)` — assigned handler or `ASSIGN_LEAD`, plus MFA |
| `lead_interactions_derive_actor` | INS, UPD | `user_id := app.current_user_id()` on INSERT; `:= old.user_id` on UPDATE |
| `lead_interactions_enforce_catalog_codes` | INS, UPD | `interaction_type_code` against the `lead_interaction_type` family |
| `lead_interactions_enforce_subscription_write_gate` | INS, UPD, DEL | subscription state |

The only consumer anywhere in the database is `app.record_lead_interaction`, and it only ever INSERTs.

---

## 2. The inherited question, answered in both directions

`202607056100` §3 left this table open with a stated reason: the RPC *"authorizes nothing … there is no
bypass here: the RPC and direct DML charge exactly the same thing, which is nothing."*

**The authority half stopped being true.** `guard_lead_interaction_authority` was added afterwards and
replicates exactly what the RPC charges. Measured: the same actor was refused **42501** by the table door and
**42501** by the RPC, on the same lead. That half needed no repair — it is asserted rather than assumed in
`108_...` 2-6 so it cannot be quietly removed.

**The "no bypass" half was never true about what the RPC MAINTAINS.** `app.record_lead_interaction` does four
things; the triggers replicate two of them:

```
BEFORE  lead A status=assigned  last_contact_at=NULL
  -- direct DML: insert ... interaction_type_code = 'phone_call'
AFTER DIRECT DML  lead A status=assigned   last_contact_at=NULL      events: 2
  -- the identical contact through app.record_lead_interaction
AFTER RPC         lead A status=contacted  last_contact_at=03:32:09  events: 3
```

A qualifying interaction inserted at the table door leaves the lead reading as **never contacted**, while its
own contact log says otherwise — and `app.process_lead_sla` escalates on `last_contact_at`. That is **LI-3**,
registered and deliberately not half-built: the repair is an AFTER INSERT trigger replicating the RPC's
derived-state maintenance, which double-fires when the RPC itself inserts, and it needs a deliberate answer to
a question a migration must not invent — *should a bare table INSERT advance a lead's lifecycle at all?* The
failure direction is conservative (a contacted lead gets escalated; never a silent un-escalation), which is
why it is Medium and not blocking.

---

## 3. LI-1 — BOOK-5's shape, second occurrence, fourteen days later

`guard_lead_interaction_authority` asks exactly one question: *who handles `new.lead_id`?* On INSERT that is
the whole question. On UPDATE it is the wrong question, because `lead_id` is a column the attacking statement
supplies.

```sql
update public.lead_interactions
   set lead_id = <A's own lead>
 where lead_id = <B's lead>;          -- accepted; B's private note now sits on A's lead
```

RLS permitted the row: its `USING` clause tests the tenant and the *existence* of the parent lead, never who
handles it. The guard then asked who handles the lead the row was moving **to** — A, so yes — and never asked
about the one it was moving **from**. `derive_interaction_actor` faithfully preserved `old.user_id`, so the
stolen row still reads as authored by B.

This is the **sixth rule of the adversarial loop**, earned by BOOK-5 on `booking_items` fourteen days earlier
and written down as a standing question: *does the predicate read `new` to decide AUTHORITY, or only to
validate CONTENT?* `set owner_user_id = <me>, cost_amount = 555` and `set lead_id = <my lead>` are the same
sentence. Nobody had asked it of this guard.

**The sibling sweep the rule obliges.** Every UPDATE-firing trigger function naming
`require_`/`has_permission`/`authorize`/`is_my_` was enumerated and then **read** — the text census that
generated the candidates is itself a proxy and produced two false positives (`guard_financial_capability` and
`enforce_status_transition` both read the old row via `to_jsonb(old)`, which no substring count can see). One
real instance exists elsewhere: `app.enforce_status_transition` authorizes a `leads` transition with
`app.require_lead_handler((to_jsonb(new) ->> 'assigned_user_id')::uuid)`. It is **not exploitable**, and that
was proven rather than argued:

```
SEIZE+TRANSITION  refused 23514  leads_owner_matches_assignee_chk
TRANSITION-ONLY   refused 42501  not the assigned handler and lacks ASSIGN_LEAD
GROUND TRUTH      assigned_user_id unchanged, status still 'assigned'
```

Recorded as a **verified non-defect and pinned** (`108_...` 11-12), because the defence is *incidental* — a
constraint about owner/assignee coherence, not a deliberate answer to BOOK-5. Relax that constraint and the
shape goes live with nothing else in the way.

---

## 4. The repair, and why it is not a new mechanism

LI-1 and LI-2 both require `UPDATE`, and **no function in this database updates this table**. So
`authenticated`'s UPDATE grant had no sanctioned writer behind it, and the rule the canon-34 family arrived at
one slice earlier applies unchanged:

> **A write grant is kept exactly where a sanctioned writer needs it.**

That is also `202607056100`'s own stated preference, quoted from its category 1: *"REMOVE AN UNNECESSARY WRITE
RATHER THAN INVENT A BUSINESS PERMISSION FOR IT."* One `revoke update` closes both findings. `INSERT` is kept
deliberately — the RPC is SECURITY INVOKER and the grant is its path, the `trusted_devices` lesson rather than
the `otp_challenges` one — and assertions 9-10 **call** the RPC after the revoke to prove it.

What this costs, stated rather than discovered later: there is no longer any way to correct a typo in a
`summary`. That capability was never offered — ORVION exposes no RPC to amend an interaction — so what is
removed is an ungoverned path, not a feature.

---

## 5. The consolidation pass: naming the mechanism that keeps recurring

The six existing rules of the adversarial loop are all special cases of one shape, now recorded as the
**seventh**: **proxy-to-invariant confusion** — measuring `P` and concluding `Q`, where `P` is an
implementation-dependent proxy `Q` does not depend on. Once named, it appeared five more times the same day.

**In the selector (`batch6_select_target.ps1`), two live instances.** `negative` coverage counted `throws_ok`
*anywhere in a file that merely named a surface*, so a fixture-heavy file paid every table it touched: `users`
scored coverage **450** (87 files name it) and `branches` **458**, for being in everybody's fixture. Since
`Score = exposure − coverage` and coverage is unbounded while exposure is not, the ranking became
approximately the *inverse* of exposure — the Top 12 opened with `languages`, `nationalities` and `countries`,
all of which have exposure **0** and cannot repay an hour of attacking, while `leads` at 22 sat near the
bottom. Separately, `unguarded` — the heaviest weight on the board, documented as *"the only component that
means there is no control here"* — detected controls by trigger function **NAME** against
`guard_|capability|authoriz`, missing ORVION's actual `forbid_`/`enforce_`/`derive_` idiom (21 trigger
functions use it; 13 matched the regex). It reported `trusted_devices` as having no control at all on the very
day TD-1/TD-2 fitted it with two. Both repaired: the sort key is now EXPOSURE with coverage as tie-break,
`Score` survives as a diagnostic, and the header documents what coverage really measures. After the fix,
exactly **one** table in the 77-table schema scores `unguarded = 1`.

**In my own instrumentation, twice, and both nearly became false findings.** A regex for `is(current_user` was
used as a proxy for "this test proves its actor" and reported 75 files failing — the repository's convention is
a `POSITIVE CONTROL` assertion, which is *stronger*. And `grep -cE '^not ok'` missed leading whitespace and
reported zero failures where there were two.

**The actor-boundary audit, and why NO test was changed.** Slice 7's battery ran as the table owner because
`set local role` outside a transaction is a silent no-op. Measured across the committed suite: all 107 files
open an explicit transaction as their second executable line, so the failure mode cannot occur there. And if
it could, it would fail **loudly**, not silently — every role-switching file carries at least one assertion
expecting *less* than a superuser sees. Two mutations establish this: nulling `app.current_user_id()` fails
**48 of 107 files**, and neutering the role switches in `48_document_storage_test.sql` — the one file that
survived every other elimination (role-switching, no `throws_ok`, mutation-survivor) — fails assertions 7 and
10. The vulnerable artifact is the **ad-hoc battery**, where no expectation is encoded and a false result is
indistinguishable from a true one. The prevention therefore belongs in the method, not in a new guard.

**`107_...` assertion 15 was overstating.** It is a tripwire and correctly over-matches; what it claimed was
too strong. It now says plainly that it proves no *database* function, view or policy references
`trusted_devices` outside a named set, and does **not** prove the table can never *be* a gate — it cannot see
an Edge Function or any application-layer check. Widened at the same time to cover views and all non-system
schemas, which was free: the narrower form returned the identical string.

**`totp_enrollments`, classified by derivation.** Canon 31 §9 defines it and deliberately gives it no secret
column; canon 34 §84 mandates it; Supabase's `auth.mfa_factors` — which that security note anticipates — holds
the real factor. Zero functions, zero views, zero triggers, zero rows. The existing ORVION vocabulary already
names this state: **Fundamental Domain Structure awaiting a flow** (`AGENTS.md §3`). Not orphaned, not legacy,
not compatibility, not reserved-future. Attacked anyway, actor proven: a subject **can** plant, re-activate and
backdate their own enrolment, while cross-identity read and write correctly refuse. **Not repaired**, and the
reason is the standing constraint rather than indifference: nothing reads the table, so no behaviour is
defended by changing it, and `202607056100` §3 explicitly ratified owner-write here — reversing a ratified
decision needs proof a change is required. What *is* now true is that the dormancy is executable:
`75_...` assertion 25 pins the whole family, mutation-proved.

**IDENT-3 was stale and is narrowed.** It grouped three tables as intentionally owner-writable; two have since
been repaired (TD-1 wired the vocabulary, OTP-1 revoked the grants), so it was reporting a closed hole as an
accepted one.

**The register's Status vocabulary was closed against its own data.** The legend declared
`OPEN · DESIGN-READY · RESOLVED · VERIFIED` while rows already used `INTENTIONAL` and
`RESOLVED BY DERIVATION`. Both are now declared, and a five-state table distinguishes a *critical unresolved
decision* from *non-blocking debt*, *intentional dormant state*, *historical evidence* and *closed* — with the
explicit statement that `CRITICAL UNRESOLVED ITEMS: NONE` speaks only to the first of those and is never a
claim that the repository carries no debt.

---

## 6. Verification

| Layer | Result |
|---|---|
| `108_...` | 15/15; mutation (restore the UPDATE grant) fails **4 of 15** incl. the ground-truth read |
| Full pgTAP suite | **108 files / 1,694 assertions**, Pass A = Pass B |
| `75_...` 25 | mutation (revoke `totp_enrollments` INSERT/UPDATE) fails it — proved, then restored |
| Identity mutation | `app.current_user_id() → null` fails **48 of 107** files; restored from a captured `pg_get_functiondef` |
| Repository consistency | Checks 1–25 CLEAN |
| Database parity | ledger, function surface and structural surface all read **from Primary**, all ten sub-surfaces matching individually |

## 7. Primary

Deployed with explicit owner authorization given this session. Primary read at **206 / `202607061700`** before
the change and **207 / `202607061800`** after; the MCP-assigned ledger version was normalised to the repository
version, as in slices 6 and 7. GUARD-1 held: the repository's own filename-list md5
(`65a7de77bdd4f81e623bb624ea03e4b4`) was proven equal to the fingerprint read from Primary before the evidence
file was written. Structural surface `e3ac05e61c9bf1a93873884bc978fe6e`, 3,563 objects — one fewer than slice
7's 3,564, and the missing object is exactly the revoked grant.
