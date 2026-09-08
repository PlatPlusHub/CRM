# Batch 6 slice 9 — `leads`: the door that answered its own authority question, and two incidental defences that had been standing in for an authorization model

Class: History (immutable)
Date: 2026-09-08
Migration: `202607061900_the_lead_door_that_answered_its_own_authority_question.sql`
Test: `supabase/tests/109_lead_authority_and_lifecycle_test.sql` — 20 assertions, eight attack classes, two declared `N/A` with reasons
Consolidation: the seventh adversarial-loop rule given its **diagnostic vs evidence** distinction and its sharpest application (**INCIDENTAL DEFENSE ≠ INTENTIONAL CONTROL**) in `MASTER_EXECUTION_PLAN.md`; BOOK-5's rule given its third occurrence; a mangled paragraph in the same file repaired; **LI-3's evidence corrected against the live catalog**

---

## 0. HANDOFF

- **INHERITED** — one open question, and it had the right answer for the wrong reason. Slice 8's
  sibling sweep recorded the `leads` seize-plus-transition as a **VERIFIED NON-DEFECT**, "refused
  23514 by `leads_owner_matches_assignee_chk`". That measurement was real and it was made with **one
  column** in the SET list. Re-run with the pair that constraint actually couples, it is satisfied
  and something else refuses (§ 2).
- **PROVEN** — reproduced at `aal2` as an `employee` who is not the handler, who **holds CREATE_LEAD**
  and holds neither `ASSIGN_LEAD` nor `REASSIGN_LEAD`, with the actor and the reach both asserted
  before any attack. **LEAD-1**: with `leads_owner_matches_assignee_chk` and
  `leads_require_assignment_history` removed inside a transaction, that employee seized a colleague's
  lead **and** transitioned it in one statement, every guard on the table returning NEW — so the
  authorization model was open and two unrelated mechanisms were holding it shut. **LEAD-2**: a lead
  inserted directly at `won`. **LEAD-3**: `converted` written with `customer_id` NULL, which
  `app.convert_lead` refuses. **LEAD-4**: the handler flipped their own lead `assigned → contacted`
  with zero interactions logged, the one edge `app.advance_lead` refuses by name. All four closed by
  `202607061900` and verified by 20 assertions, by mutation in both directions, and over HTTP.
- **UNPROVEN** — nothing is asserted here without a behavioural or catalog measurement, and two
  inferences are labelled where they are drawn. `109_...` assertion 20 is a **text tripwire** over
  `prosrc` and says so; it cannot prove the guard is correct, only that it names `old` (the
  behavioural proof is 3-6 and 15-18). And the claim that LEAD-2's `won` leads would reach Google Ads
  through `app.map_outcomes_to_conversions` is a **read of that function's source, not a reproduced
  upload** — Primary carries zero business rows and no real conversion has ever been sent.
- **CHANGED** — one migration (two functions replaced, one new guard function + trigger, one CHECK
  constraint, three revokes), one new pgTAP file, `108_...` 11-12 re-pointed from the incidental
  defence onto the intentional control, seven new HTTP assertions in `verify_lifecycle_branches.ps1`,
  the governance set, and both generated artifacts. **`MASTER_API_CONTRACT.md` did not change**:
  `leads` was already `SIU-` and stays `SIU-`, because nothing here revokes a grant — this slice
  charges for a write rather than removing one.
- **DO NOT TOUCH** — the `else` branch of the `leads` block in `app.guard_write_capability`. The
  relationship shortcut must survive, and it must read `old`: deleting it entirely would force every
  handler edit through the permission list, and a `trainee` handler holds none of
  CREATE_LEAD/ASSIGN_LEAD/CLOSE_LEAD/REASSIGN_LEAD and would lose their own lead. Assertions 7-8 fail
  loudly if anyone tries. Also do not "fix" `109_...` 20's over-matching: it is a tripwire and errs
  toward review deliberately. Also unchanged and deliberately so: **LI-3**, which this slice
  explicitly does not answer (§ 4).
- **REMAINING** — nothing from this slice is unfinished. **LI-3 remains open on `lead_interactions`**
  and its *evidence* was corrected here, not its status: it said `app.process_lead_sla` escalates on
  `last_contact_at`, and no function, view or policy in this database reads that column at all (§ 4).
  It is still pinned by `108_...` assertion 14. The pre-existing debt list (`ai-map.json` timestamp
  churn, RECOVER-1's residual process gap, DISP prose residual, PAX-4's remaining members, CUST-6,
  IDENT-2, DELIV-1, GOV-20, DOC-LC-3, PH8-2, RBAC-6, the three dead catalog families in `12_...`
  assertion 9, and `public.totp_enrollments`) is unchanged by this session.
- **NEXT** — **Batch 6 slice 10**, ranked by `scripts/batch6_select_target.ps1` on the repaired
  exposure ordering: `invoices` (18) then `customers` (17). `leads` was 22 and is now `AUDITED`.

---

## 1. What the surface is

`leads` is where acquisition becomes revenue: 30 columns, RLS `scope_isolation` for ALL commands,
`INSERT`/`SELECT`/`UPDATE` granted to `authenticated`, nine triggers, seven composite FKs, and
eighteen registered rows in `app.status_transitions`. Twelve `app` functions read or write it, of
which five are its sanctioned writers — `create_lead`, `assign_lead`, `reassign_lead`, `advance_lead`,
`convert_lead` — plus `record_lead_interaction` and the session-less `process_lead_sla`.

The authorization model is layered, and the layering is what made the defect hard to see. Trigger
BEFORE-row order is by NAME, so on an UPDATE the sequence is `derive_created_by` →
`enforce_archive_authority` → `enforce_catalog_codes` → `enforce_status_transition` →
`enforce_subscription_write_gate` → `forbid_acquisition_lineage_rewrite` → `guard_write_capability`,
then CHECK constraints, then the AFTER trigger `require_assignment_history`.

---

## 2. The inherited question, re-measured — and INCIDENTAL DEFENSE ≠ INTENTIONAL CONTROL

Slice 8 ran this:

```sql
update public.leads set assigned_user_id = <me>, lead_status_code = 'contacted' where id = <B's lead>;
--> 23514  leads_owner_matches_assignee_chk
```

and concluded the seize was refused. It is. But `leads_owner_matches_assignee_chk` is
`owner_user_id IS NOT DISTINCT FROM assigned_user_id` — a constraint about **two columns agreeing**,
and an attacker simply sets both:

```
A.  seize + transition (both columns)  -> 23514  app.require_assignment_history
A3. seize (assigned_user_id only)      -> 23514  leads_owner_matches_assignee_chk   <- slice 8's probe
C.  transition only                    -> 42501  app.require_lead_handler
```

The mechanism behind the constraint is `app.require_assignment_history`, whose own error message
states its purpose: *"every assignment must remain visible in the lead timeline (canon 04)"*. It never
asks who the actor is or what they hold. It refuses the seize only because writing `lead_assignments`
is capability-gated **somewhere else**.

So two mechanisms, neither of them the authorization model, were the entire defence. The only way to
learn that is to remove them and ask again, which is what `109_...` 15-18 does inside a savepoint:

```
constraint dropped + require_assignment_history dropped
  seize + transition, employee at aal2, no ASSIGN_LEAD, no REASSIGN_LEAD
  --> ACCEPTED.  every guard on the table returned NEW.
```

**"The attack currently fails" and "the intended authorization invariant is enforced" are different
claims.** They had come apart here, and nothing in the repository would have announced it on the day
someone relaxed the coherence constraint for an unrelated reason. The distinction and its five-step
procedure are now recorded as the sharpest application of the seventh adversarial-loop rule (§ 5).

---

## 3. LEAD-1 — BOOK-5's shape, third occurrence, and the widest one

`app.guard_write_capability` carried a shortcut for this one table:

```sql
if tg_op = 'UPDATE' and tg_table_name = 'leads' then
    v_relationship_ok := app.current_user_id() in (NEW.assigned_user_id, NEW.owner_user_id);
end if;
if v_relationship_ok then return new; end if;
```

Both columns are supplied by the attacking statement. Naming yourself in the SET list therefore
answered *"are you the handler?"* — and the answer did not merely authorize the assignment change, it
returned NEW **before any permission check, any `app.authorize` call and any MFA test, for every
other column in the same statement**. `app.enforce_status_transition`'s `leads` fallback read the
same forged image one trigger earlier.

Three tables, one sentence: BOOK-5 was `set owner_user_id = <me>, cost_amount = 555`; LI-1 was
`set lead_id = <my lead>`; this is `set assigned_user_id = <me>`. The standing question the rule
already carried — *does the predicate read `new` to decide AUTHORITY, or only to validate CONTENT?* —
had never been asked of this branch, fourteen days and two slices after it was written down.

**The repair is two clauses and neither invents a rule.** The shortcut is decided from `old`: you may
edit a lead without a permission because you *already* handle it, not because you just wrote your
name on it. And moving the assignment costs **ASSIGN_LEAD or REASSIGN_LEAD**, copied verbatim from
`app.assign_lead` and `app.reassign_lead`. It REPLACES the permission set rather than appending —
the `suppliers`/CUST-5 shape rather than the `customers` one — and the containment was measured
before choosing: owner, ceo, branch_manager and department_manager hold both an assignment key and
CREATE_LEAD, while employee, senior_employee and trainee hold neither key. Nothing legitimate loses a
door; the three roles that lose the seize are exactly the three that were never entitled to it.

Re-measured with both incidental defences **still removed**:

```
seize + transition -> 42501  permission denied: one of ASSIGN_LEAD or REASSIGN_LEAD is required to write leads
seize alone        -> 42501  (same)
```

The guard now stands alone. That is what "intentional control" means, and `109_...` 15-18 is written
so it cannot quietly stop being true: it removes the two incidental defences, asserts the refusal is
**42501** and not 23514, then removes the repaired guard as well and asserts the seize **succeeds**
and that the row **moved** — before rolling back, re-establishing the session (TEST-3) and asserting
the refusal returns.

---

## 4. LEAD-2 / LEAD-3 / LEAD-4 — the state machine guards its edges and not its preconditions

`app.enforce_status_transition` is BEFORE **UPDATE** and validates exactly one thing: that the edge
`old → new` exists in `app.status_transitions`. Everything else canon 26 says about a lead's lifecycle
lives inside the RPCs — and `authenticated` reaches the table directly through PostgREST.

**LEAD-2.** `app.create_lead` hardcodes `'new'`; the door accepted `lead_status_code = 'won'` on a
bare INSERT, in SQL and over HTTP. The graph was enforced only for leads that entered through the
graph. Closed by an entry rule in a new `app.guard_lead_lifecycle` — completion of an existing
mechanism's coverage, not a new rule, since the entry status is the one the sole sanctioned writer
already writes.

**LEAD-3.** `won → converted` carries a NULL `permission_key`, so the handler fallback passes it.
`app.convert_lead` refuses without a customer and links one in the same statement; at the door the
handler produced `converted` with `customer_id` NULL and no closure reason. Closed by a **CHECK
constraint** rather than a line in the guard, deliberately: the invariant has no session in it, so it
binds the platform paths every trigger guard here exempts. The cheapest correct enforcement layer is
the one that cannot be reached around.

**LEAD-4, and the hypothesis that measurement killed.** The obvious SLA finding was that a non-handler
could write `last_contact_at` and silence escalation. **That hypothesis is false, and it was false
because LI-3's own evidence is wrong.** LI-3 says *"`app.process_lead_sla` escalates on
`last_contact_at`"*. Measured against the live catalog: **no function, view or policy in this database
reads `leads.last_contact_at` at all.** The SLA loop scans `where l.lead_status_code = 'assigned'`,
derives its window from `lead_assignments.assigned_at` and its idempotency from the `events` ledger.
A lead leaves the working set by changing **status**.

Which is the real finding, one column over. `assigned → contacted` is the one edge **no RPC offers**:
`app.advance_lead` excludes it by name ("owned by other RPCs") and refuses it when asked, and its only
sanctioned producer is `app.record_lead_interaction`, as a *consequence* of a qualifying interaction.
At the door the handler flipped their own lead to `contacted` with zero interactions and
`last_contact_at` still NULL — a one-statement, no-evidence escape from the escalation canon 10
requires. Closed by requiring a qualifying interaction (`phone_call`, `whatsapp_message`,
`chat_opened`, `customer_reply` — the set transcribed from the RPC, which took it from canon 26) to
exist on the lead.

**This deliberately does not answer LI-3.** LI-3 asks whether a bare INSERT into `lead_interactions`
should *advance* the lifecycle; LEAD-4 asks only that the evidence exist before the lifecycle claims
it did. A handler who logs a real call at the door and then marks the lead contacted is permitted
exactly as before, and `108_...` assertion 14 — written to fail when LI-3 is repaired — still passes.
LI-3's row is corrected on its mechanism and left open on its question.

---

## 5. Consolidation: what a proxy is allowed to do

The seventh rule named the failure (PROXY-TO-INVARIANT CONFUSION) and never said what a proxy is
*permitted* to do, which matters because half this repository's measuring layer is proxies doing it
legitimately. The line is now drawn between two uses, in `MASTER_EXECUTION_PLAN.md`:

* **DIAGNOSTIC PROXY — allowed.** Ranking, suggesting, flagging for review, narrowing an
  investigation. `batch6_select_target.ps1` still ranks on a file-co-occurrence proxy and that is
  fine, because its output is a suggestion a human then verifies. What a diagnostic owes the reader is
  the label.
* **EVIDENCE OF AN INVARIANT — must observe the state that DEFINES the invariant**, or a formally
  equivalent state the repository controls.

The forbidden step is always the same one: *"P is correlated with Q"* → *"P proves Q"* — a class
promotion out of **INFERENCE** in the `AGENTS.md §5a` evidence table, which stays the single authority
on the classes. Its sharpest application is the one this slice earned, **INCIDENTAL DEFENSE ≠
INTENTIONAL CONTROL**, with the five-step procedure whose fifth step is the one that cannot be
skipped: *remove or relax the incidental defence inside a transaction and ask again.*

Two more things were repaired in the same file rather than written around. A paragraph of the fifth
rule had been **split in half** by the sixth rule's block being inserted mid-sentence, leaving an
orphan fragment ("population it cannot judge…") stranded three paragraphs later — reassembled, with
no wording changed. And BOOK-5's rule now records its third occurrence and states the distinction the
third one made plain: **content validation** may read `new`; **authority validation** may not.

No new rule was added. LEAD-1 is BOOK-5's existing rule, third instance; the incidental-defence
distinction is an application of the seventh, not an eighth.

---

## 6. Verification

| Layer | Result |
|---|---|
| `109_...` | 20/20; mutation removes both incidental defences (still refused **42501**), then the guard itself (seize **succeeds**, row **moved**), then restores and re-asserts |
| Full pgTAP suite | **109 files / 1,714 assertions**, Pass A = Pass B |
| Six HTTP suites | **437 / 0** (29 · 114 · 74 · 120 · 40 · 60) — `verify_lifecycle_branches` +7, PATCH and POST through PostgREST with ground truth read back |
| Smoke | `ALL CHECKS PASSED` (77 tables) |
| Cross-path impact (§5b) | **two caught, both by existing guards.** `10_grant_model_test` 5 caught the missing `revoke execute … from public` on the new function — `create function` grants EXECUTE to PUBLIC by default and this one is SECURITY DEFINER (SECDEF-1's shape). `108_...` 11 caught its own pin firing: it asserted 23514 from the incidental constraint, and the mechanism is now the intentional guard. Both are recorded rather than quietly fixed |
| Repository consistency | Checks 1–25 CLEAN |
| Database parity | ledger, function surface and structural surface all read **from Primary**, all ten sub-surfaces matching individually |

Two hypotheses were killed by measurement before any code was written: the `last_contact_at` SLA
suppression (§ 4), and a `trainee` escalation path (a trainee holds only `VIEW_ASSIGNED_LEADS`, so RLS
shows them nothing but their own leads and there is nothing to seize).

---

## 7. Primary

Deployed to Primary `vrvtsxexkiiiivlkdxzp`, the ref verified against `MASTER_INTEGRATION_CATALOG.md §0`
before the call. Primary read **207 / `202607061800`** before and **208 / `202607061900`** after; the
MCP-assigned ledger version `20260908184430` was normalised to the repository version, as in slices
6, 7 and 8. **GUARD-1 held**: the repository's own filename-list md5 (`1caf71daa1f4df9d89d03f3df0aa9d25`)
was proven equal to the fingerprint read from Primary *before* the evidence file was written.

Function surface `e119612311b7200505934bb860997e4a` / 279 functions (278 + `guard_lead_lifecycle`).
Structural surface `c446dec0c85724da31514168b4c4b14f`, **3,566 objects** — three more than slice 8's
3,563, and the three are exactly this migration's additions: one trigger, one constraint, one
function. All ten sub-surfaces compared individually and identical.
