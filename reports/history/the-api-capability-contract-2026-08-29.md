# ORVION — The API Capability Contract, and Two Defects in the Thing That Measures

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: `scripts/generate-api-contract.ps1`, `reports/master/MASTER_API_CONTRACT.md`,
`check_database_parity.ps1` Check L3; the evaluation of ten owner recommendations; SEC-2 reproduced
and bounded; API-2, API-3, CONV-3.
Status: Complete; pushed. **No migration** — this package changes no database behaviour.

**Branch:** `main` · **Start HEAD:** `d4438a8` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Starting state, re-proven

HEAD = `d4438a8`, tree clean, 159 migrations / 67 test files. Local ledger
`28cd2ca6d89881750b5cd2bfb84f9238`, function surface `1c63f2545d2452cece517e324c5b25c7` — both
matching Primary, read independently.

---

## 2. The owner's ten recommendations, evaluated

Nine ACCEPT, one ACCEPT-with-finding. **None changed the execution order.** One refined it, and that
refinement is the substance of this package.

| # | Verdict | Basis |
|---|---|---|
| 1 API contract next | **ACCEPT**, refined | Already the recorded next step. Refinement: it must cover the TABLE surface too — see §3. |
| 2 WeWeb first, no mobile | **ACCEPT** | Nothing mobile-specific exists or is needed; `DELETE` is granted on zero tables, so there is no offline/soft-delete machinery to design around. |
| 3 No premature n8n/WhatsApp/AI | **ACCEPT** + finding | Data model verified ready; the missing piece is a door, not a model — **CONV-3**. |
| 4 Attribution end-to-end | **ACCEPT** | Already enforced by ATTR-3 (first-touch immutable, no session-less exemption) and CONV-1. |
| 5 SLA as a product requirement | **ACCEPT** | SLA-1, LEAD-3, LEAD-4, ATTR-3 all shipped; `lead_timeline` gives the manager the read surface. |
| 6 Don't let SEC-2 block | **ACCEPT** | Reproduced and bounded rather than argued — §4. |
| 7 HTTP evidence per endpoint | **ACCEPT** standard, **DEFER** deliverable | 33 of 71 uncovered; ~200 assertions in one sitting would be the count-theatre the directive forbids. **API-3**. |
| 8 Integrations use the same contract | **ACCEPT** | Already true: API-1 excluded `record_event`, `authorize`, `has_permission`, `platform_*`; `orvion_integration` holds four narrow definer grants. |
| 9 Guard scepticism | **ACCEPT** | Vindicated three times in two days; twice more in this package. |
| 10 Don't expand the product | **ACCEPT** | The contract is a document plus a guard, not runtime infrastructure. |

---

## 3. The refinement that mattered: a contract for the RPCs alone would describe a minority

`authenticated` holds **SELECT on 69 tables, INSERT on 54, UPDATE on 54, DELETE on none.** PostgREST
serves tables directly, so `POST /rest/v1/complaints` is exactly as reachable from a browser as
`POST /rest/v1/rpc/create_complaint` — which is how SEC-1b was found in the previous package.

A contract listing only the 71 RPC endpoints would have documented the smaller half of the door.
`MASTER_API_CONTRACT.md` §4 therefore documents all **71 tenant-reachable tables** with their SIUD
grants, INSERT guard, UPDATE guard and RLS policies.

### Generated, not written

Every row is derived from `pg_catalog` and `app.status_transitions`. `check_database_parity.ps1`
gains **Check L3**, which regenerates the file into a temp path and fails on any difference.

**Proven in both directions**, because a guard never seen to fail is a guard not yet verified:
appending one tampered line produced `CONTRACT STALE`; regenerating cleared it.

The reason for generating rather than writing is the whole recent history of this programme: a
hand-maintained interface document is a claim, and GUARD-1, PAR-1, PAR-1a and SEC-1b were all
unverified claims. Same shape as `ai-map.json` and Check 7.

---

## 4. SEC-2, reproduced and bounded

The owner asked that SEC-2 not block the contract. It does not — and now the reason is measured
rather than asserted. A `trainee` holding `CREATE_LEAD = f`, `CLOSE_LEAD = f`, `CREATE_COMPLAINT = f`:

```
probe A: rename the lead ASSIGNED to them   ->  SUCCEEDED, title = 'Renamed by a trainee'
probe B: edit an EMPLOYEE-owned complaint   ->  visible rows 0, UPDATE 0
```

Probe B is the control that makes probe A meaningful: **RLS scope still holds.** So the exposure is
*descriptive columns of rows the actor can already read* — not cross-tenant, not cross-scope, and not
a route to anything governed. Monetary columns (FIN-3), status transitions, acquisition lineage
(ATTR-3), assignment history (TRANS-2) and message content (CONV-2) are each separately guarded, and
DELETE is granted nowhere.

**The structural detector lies here exactly as SEC-1b's did.** Eighteen tables *appear* to carry an
UPDATE capability trigger, but `enforce_status_transition` and `enforce_archive_authority` return
early when status and archive flags are unchanged — so a descriptive edit sails through. The contract
therefore prints `conditional`, never `yes`, in the update-guard column, and says why.

It stays **BLOCKED — BUSINESS DECISION**, and the contract confirms *why* it is not derivable: across
all 71 exposed endpoints there is **no `update_customer`, no `edit_booking`, no `amend_complaint`** —
no function anywhere to read an edit permission out of. The minimum ruling needed is one sentence:
does editing cost the create permission, a new `EDIT_*` per family, or nothing because RLS scope is
deliberately the whole control? The third is a legitimate answer and would close it as INTENTIONAL.

---

## 5. CONV-3 — the WhatsApp/AI model is ready; the door is not

The owner asked whether today's structures support
`Customer → WhatsApp → AI → qualification → human → lead` without rework. Verified rather than
assumed:

**Ready.** `conversations.external_conversation_id` exists; `customer_id` and `owner_user_id` are
**nullable**, so a thread can exist before the customer is identified and before any human is
assigned; `conversation_messages.sender_user_id` is nullable with `external_message_id` present;
`sender_type_code` already offers `customer`, `system`, `external_provider`; `channel_code` and
`lead_source_code` both include `whatsapp`; and `capture_attribution_click` is already granted to
`orvion_integration`, so a WhatsApp-originated click can be captured with no session.

**Not ready.** All three conversation RPCs are `SECURITY INVOKER`, granted to `authenticated` only —
**none to `orvion_integration`** — and `start_conversation` requires a branch placement
(*"you have no primary branch assignment"*), which an inbound message from an unknown customer does
not have. Today that flow would require impersonating an employee JWT, which is precisely what must
not be built.

**DEFER, not defect.** The precedent is already in-house: `capture_attribution_click` and
`claim_conversion_deliveries` are SECURITY DEFINER, granted to `orvion_integration`, taking an
explicit tenant. The future needs one function, not a redesign. One vocabulary question rides along
and is deliberately not decided: `sender_type_code = 'system'` for an AI author (adequate today) or a
new `ai_agent` value — canon owns catalogs, and the answer is not needed until the integration exists.

---

## 6. Two defects in the generator, caught before it shipped

**The permission column understated authority.** The first version picked the permission with a
first-match `CASE`, so `advance_lead` reported only `CLOSE_LEAD` and silently omitted the TRANS-2
handler rule governing its other transitions. Composed now:
`CLOSE_LEAD + per transition: ASSIGN_LEAD, CLOSE_LEAD`. **A contract that understates authority is
worse than no contract**, and this is the same first-instance-shape failure as SEC-1b — I wrote it
into the tool built to expose that very class.

**The coverage column under-counted 38 as 1.** It matched the literal string `rpc/<name>`, but the
suites call through a `Rpc $VAR 'name'` helper, so that literal appears almost nowhere. Detection now
matches the two real call shapes exactly.

Both were found by reading the generated output rather than trusting the run to be green.

---

## 7. Verification

| Axis | Value |
|---|---|
| Migrations | **159** — unchanged; this package alters no database behaviour |
| Ledger fingerprint | `28cd2ca6d89881750b5cd2bfb84f9238` — repo, local, Primary |
| Function surface | `1c63f2545d2452cece517e324c5b25c7` (230) — identical both sides |
| pgTAP **Pass A** | **67 files / 805 assertions / 0 failures** |
| pgTAP **Pass B** | **67 files / 805 assertions / 0 failures** |
| End-to-end HTTP | **220/220** across six suites |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Guards | repository CLEAN · parity CLEAN (ledger, functions **and** contract freshness) |
| Contract stability | byte-identical after a fresh `db reset` **and** under full HTTP residue — it derives from schema, not data |
| Guard negative proof | tampered file → `CONTRACT STALE`; regenerated → clean |

---

## 8. Classification

**DELIVERED** — API-2: the contract, its generator, and Check L3.

**OPEN (engineering)** — API-3: 33 of 71 endpoints have no HTTP evidence. Visible and payable down
deliberately; notably `advance_lead` and `convert_lead`, the lead state machine, which has no HTTP
walk of its own despite being the revenue spine.

**DEFER** — CONV-3, to the integration phase, with the in-house precedent named.

**BLOCKED — BUSINESS DECISION** — SEC-2, now reproduced, bounded, and with the minimum ruling stated.

**INTENTIONAL** — generating rather than hand-writing the contract; stating platform rules once
rather than per endpoint; documenting the table surface alongside the RPCs.

---

## 9. Next logical work

**API-3, starting with the lead state machine.** `advance_lead` and `convert_lead` are uncovered over
HTTP, and leads are where acquisition becomes revenue — the one place the owner's attribution and SLA
requirements both land. Then the service-request lifecycle.

Owner-blocked and unchanged: DOC-EXP-1, SEC-2, SCHED-1, RET-1, RET-2, AUTH-1, FIN-5, SYSADMIN-1,
VOID-1, SPP-3, PH8-2, TRANS-1.
