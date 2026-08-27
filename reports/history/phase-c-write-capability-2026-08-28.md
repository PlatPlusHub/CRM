# ORVION — Phase C: Write Capability Wherever Canon Already Answers It

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migration `202607056000`, test `57_write_capability_map_test.sql`, `10` (ceilings tightened
again). Applies FIN-3's rule to every table where the evidence is unambiguous, and classifies the
residue individually instead of counting it.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `79135d2` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective

The directive's §3–4 made a pattern permanent policy: *a read predicate authorizing a write* is a
high-priority audit pattern, and a defect must be chased as a **class**, not an instance. FIN-3 fixed
that class in the money family. This session asks: where else, and can it be fixed without inventing
business policy?

---

## 2. Starting state, re-proven live

| Axis | Evidence |
|---|---|
| GitHub | `origin/main` = `79135d22b124…` = local HEAD; tree clean |
| Repository | 148 migrations, 56 test files |
| Local + Primary | 148 migrations, fingerprint `54bdef85d1d286ae77f92ed0681baaff` |

---

## 3. The class map — every write authorization shape in the schema

Classifying all 119 policies by what their `WITH CHECK` actually requires:

| shape | policies | meaning |
|---|---|---|
| write/other permission | 31 | correct — a real write capability |
| **TENANT ONLY** | 18 | membership is the only requirement |
| **READ PERMISSION ONLY** | 14 | `VIEW_*` OR visibility — the FIN-3 pattern |
| **BARE VISIBILITY** | 8 | "the parent row exists" |
| owner-only | 5 | the caller's own rows |
| deny-all | 3 | platform tables |

The middle three groups — 40 policies — are where a write is authorized by something that is not a
write capability.

---

## 4. The rule, and why it needs no decision

For every table `authenticated` may INSERT with no capability enforcement, find **every `app.*`
function that inserts into it** and the permission that function authorizes:

- **One RPC, one permission** → canon has already answered. Guard it.
- **Two RPCs, two permissions** → guard the **union**, which is exactly what the existing code
  permits. Requiring both would forbid writes ORVION performs today; picking one would silently
  retire a working path.
- **No RPC, or an RPC that authorizes nothing** → there is no evidence-based answer. **Left to
  SEC-1**, not guessed.

Nine tables had an unambiguous answer:

| table | permission | from |
|---|---|---|
| `approval_requests` | `CREATE_BOOKING_ITEM` | `request_finance_approval` |
| `conversation_messages` | `SEND_MESSAGE` | `send_conversation_message` |
| `customer_contact_methods` | `CREATE_CUSTOMER` | `add_customer_contact_method` |
| `customer_identity_signals` | `CREATE_CUSTOMER` | `create_customer` |
| `customer_identity_merges` | `MERGE_CUSTOMER_IDENTITY` | `merge_customer_identity` |
| `internal_supplier_links` | `ASSIGN_SUPPLIER` | `link_internal_supplier` |
| `offline_conversions` | `MANAGE_MARKETING_CAMPAIGN` | `record_offline_conversion` |
| `document_links` | `UPLOAD_DOCUMENT` **or** `MANAGE_TENANT_SETTINGS` | `upload_document` / `upload_subscription_payment_proof` |
| `lead_assignments` | `ASSIGN_LEAD` **or** `REASSIGN_LEAD` | `assign_lead` / `reassign_lead` |

`has_permission` is used to find *which* alternative the caller holds, then `authorize` runs on that
one — because `authorize` is what also composes the MFA step-up, and a bare `has_permission` check
would silently drop it for the roles canon 28 requires it from.

---

## 5. The exception that mattered — checked before writing, not after breaking

Only three of the nine are updated by any `app.*` function:

```
customer_contact_methods <- add_customer_contact_method  (charges CREATE_CUSTOMER: same permission)
lead_assignments         <- reassign_lead                (charges REASSIGN_LEAD: inside the union)
                         <- process_lead_sla             (session-less: exempt)
approval_requests        <- review_finance_approval      (charges APPROVE_FINANCE)
```

**`approval_requests` carries the guard on INSERT only.** `review_finance_approval` is how finance
*decides* a request, and `finance_manager` does **not** hold `CREATE_BOOKING_ITEM` — charging the
insert permission on UPDATE would have broken the approval workflow **FIN-2 repaired one migration
earlier**. Its UPDATE is already correctly guarded by `scope_update`, which switches on
`approval_type_code`. Assertion 9 of the new test proves finance can still decide; assertion 12
proves the exclusion is structural (the trigger genuinely has no UPDATE bit) rather than a comment.

---

## 6. The residue — 13 tables, understood rather than counted

| ceiling | before | after |
|---|---|---|
| tables `authenticated` may INSERT | 59 | 59 |
| …with no capability **trigger** | 36 | **27** |
| …with **no capability enforcement of any kind** | — | **13** |

And those 13 are now individually classified rather than left as a number:

- **The caller's own auth artifacts, owner-scoped by policy** — `otp_challenges`,
  `totp_enrollments`, `trusted_devices`. Capability here is "being that user", which the policy
  already enforces.
- **System-written** — `attribution_clicks`, `notifications`, `notification_deliveries`,
  `offline_conversion_deliveries`, `usage_counters`.
- **No RPC authorizes anything** — `branch_business_hours`, `company_assets`, `financial_accounts`,
  `holidays`, `lead_interactions`. `app.record_lead_interaction` and
  `app.capture_attribution_click` charge no permission at all, so no permission can be *derived*;
  choosing one would be inventing business policy.

All 13 remain under SEC-1.

---

## 7. Tests: added, failed first, corrected

Suite **56 files / 633 assertions → 57 files / 646 assertions**, 0 failures. Plus 118 HTTP
assertions across four scripts, all re-run and unchanged.

`57_write_capability_map_test.sql` (12) — the trainee (holding only `VIEW_ASSIGNED_LEADS` and
`VIEW_ASSIGNED_TASKS`) refused, the employee permitted on the **same row**, the union case proven
from both sides, the `approval_requests` UPDATE exclusion proven behaviourally *and* structurally,
and the map proven complete (exactly nine triggers, every one on a mapped table).

| What failed first | Cause | Resolution |
|---|---|---|
| trainee positive control on `conversations` | **My test was vacuous-in-the-making**: a trainee cannot see conversations at all, so the denial would have proved only unreachability | moved both controls onto `customers`/`customer_contact_methods`, which the trainee *can* see — the table under test was changed rather than the assertion weakened |
| `body` / `phone` invalid | my fixture invented a column and a catalog value | read the real ones |
| employee `conversation_messages` insert refused by **RLS** | the fixture's conversation had no branch or assignment, so the employee could not see the parent either | both controls consolidated onto one reachable row, so the two assertions differ in exactly one variable: capability |

---

## 8. Environment, parity and guards — final state

| Axis | Value |
|---|---|
| Migrations | **149** — repository, local, Primary |
| Fingerprint | **`c76d13a17ce0bf6dcb9888ba741e3b39`** on all three |
| Logic hash (`guard_write_capability` + its nine triggers, incl. type bits) | **`3d93685767c201ca224b118dbe8ae999`** identical local and Primary |
| pgTAP | **57 files / 646 assertions / 0 failures** |
| End-to-end HTTP | **118/118** — storage 36 · employee 29 · branches 26 · roles 27 |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN (local proven; primary proven) |

---

## 9. Classification

**PROVEN** — nine tables charge the permission their own RPC charges, on INSERT and (where safe)
UPDATE, with positive and negative controls on the same row; FIN-2's approval workflow survives; all
four HTTP journeys unchanged; the guard map is complete and refuses rather than passes on an
unmapped table.

**UNPROVEN** — the trainee's full journey over HTTP (only its denial path is proven here); the
remaining lifecycle branches (quotation rejected/expired/revised, booking modified, partial payment,
supplier failure, document expiry, repeat booking).

**FAILED** — none outstanding.

**BLOCKED** — **SEC-1** (13 residue tables, individually classified; owner decision) · FIN-5 ·
SYSADMIN-1 · TRANS-1 · TASK-3 · SCHED-1 · RET-1, RET-2, ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5,
CANON-26-1 · DEL-1 (partial) · PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — `approval_requests` guarded on INSERT only; the union rule for two-RPC tables;
system paths exempt from the check and never from the record.

---

## 10. Next logical work

**SEC-1's remaining 13 need a decision, not more discovery.** Every table with an evidence-based
answer now has one. The residue splits three ways — auth artifacts already owner-scoped, system-written
tables that arguably should not be `authenticated`-writable at all, and five tables whose RPCs
authorize nothing — and each branch needs a different call.

**Independent of that:** the trainee's full journey; the remaining lifecycle branches over HTTP;
TRANS-1's de-duplication; SCHED-1.
