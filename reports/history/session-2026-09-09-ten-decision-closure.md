# Ten-decision closure

Class: 🟠 Historical-Immutable — session record
Date: 2026-09-09
Status: Complete — verified locally and deployed/parity-proven on Primary
Purpose: Close the interrupted ten-decision package without starting Batch 6 Slice 12

---

## §0 HANDOFF

- **INHERITED:** `main` at `37849ed`, equal to fetched `origin/main`; six untracked decision migrations, four untracked tests, and one modified inherited test were preserved and audited before any edit. Primary began at 211 migrations; Batch 6 was 12/77.
- **PROVEN:** clean reset; pgTAP Pass A and Pass B each 117 files / 1,915 assertions; six HTTP suites 449/449; smoke `ALL CHECKS PASSED`; Primary ledger/function/structure values read live and parity guard CLEAN at 218 migrations.
- **UNPROVEN:** no real Resend send, credential, webhook, or production n8n workflow was created; compliance authorization and counsel-supplied retention periods remain external prerequisites.
- **CHANGED:** seven migrations, tests 103–105 and 112–117, API/HTTP guards, canon/register/backlog/integration/evidence/manifest/report artifacts; committed by the commit containing this report and pushed to `origin/main`.
- **REMAINING:** MAIL-1 production authorization/PDPC destination confirmation and RET-1 counsel-supplied per-type periods only; neither is unresolved architecture.
- **DO NOT TOUCH:** do not start Batch 6 Slice 12 in this session; do not send real email or create/store provider credentials; do not deploy this repository to Secondary; do not invent retention periods or numeric quota enforcement.
- **NEXT:** Decision-closure complete. Start Batch 6 Slice 12 on quotations in a NEW session.

---

## §1 DISCOVERED

The inherited implementation was directionally sound but its first whole-suite run exposed cross-path contract drift: BOOK-8 changed two historical denial messages; BOOK-9 became a second enforcer inside BOOK-5's mutation probe; four new private RPCs had no public HTTP wrappers and retained implicit PUBLIC execute; the API endpoint classification omitted them; the money/currency class detector recognized row CHECKs but not FA-2's necessarily cross-table trigger. RET-1 also lacked an executable legal-hold representation. AUDIT-2's old backlog premise was false: the database already held 66 entitlement rows and 12 numeric limits.

## §2 VERIFIED

| Evidence | Result |
|---|---|
| `git fetch origin --prune`; local/upstream comparison | `0/0` at inheritance |
| `npx supabase db reset --local` | all 218 repository migrations replayed cleanly |
| `npx supabase test db` Pass A / Pass B | 117 files, 1,915 assertions, PASS both times; Pass B ran after all HTTP suites without reset |
| Six `verify_*` HTTP suites | 33 + 122 + 74 + 120 + 40 + 60 = **449 passed, 0 failed** |
| `scripts/verify_database.sql` | `ALL CHECKS PASSED`; 77 tables, 71/618 catalog |
| Primary live reads | 218 migrations; ledger `70ba44e108ff9936f5d5f1bf8e27e349`; 296 functions hash `32d4b5546e0914afb5a451a42f02a4e6`; 3,620 structural objects hash `31ea232c2c2f57d232632193688615d1` |
| `check_database_parity.ps1` | `DATABASE PARITY: CLEAN` across ledger, functions, and all ten structural surfaces |
| Generated API contract | 79 client RPCs, all 79 with HTTP evidence; 8 reporting views; 73 API-visible tables |
| Supabase advisors | no new security error; one pre-existing `moddatetime`-in-public warning. Performance advisor remains informational on the existing broad FK/index portfolio; no speculative index package was added |

The first Pass A failure was retained as evidence and fixed rather than hidden: tests 103, 10, and 53 each caught one of the integration issues above. The final complete runs are green.

## §3 FIXED

- **MONEY-2:** quotation header/line totals non-negative; header derivation has one enforcement home; signed account opening balances preserved.
- **FA-2:** cross-currency payments require a correct positive FX row and server-derived account-currency evidence; same-currency/no-account paths remain explicit.
- **PAX-5/PAX-6:** manifest freezes at issue; authorized reasoned corrections remain; link/replace/remove emit exactly one event.
- **BOOK-8/BOOK-9:** finance withdrawal and booked-service reassignment have independent capabilities, fresh reasons, server stamps, events, and table-door enforcement.
- **RET-1/RET-2 mechanism:** legal hold is executable and blocks both multi-tenant scanning and claim-time execution without aborting another tenant.
- **AUDIT-2/PD-23:** storage and NULL semantics reconciled; numeric non-enforcement mechanically pinned; boolean plan gating unchanged.
- **MAIL-1 architecture:** Resend selected technically; PostgreSQL provider-neutral; n8n execution contract, idempotency, webhook deduplication, credential boundary, and compliance activation gate documented.

## §4 NOT FIXED

Numeric quotas were not activated: provisional commercial ceilings have no justified enforcement behavior, and current-state versus periodic metrics need different implementations at the recorded trigger. The pre-existing Supabase advisor portfolio was not converted into an unrelated index/extension migration. No Batch 6 surface disposition changed; the programme remains exactly 12/77.

## §5 BLOCKED

MAIL-1 production activation requires the owner and counsel to authorize Resend for the actual processing destination and satisfy the applicable Egyptian PDPC/privacy-notice requirements. RET-1 operational configuration requires counsel-supplied positive per-document-type retention periods. Safe defaults remain no send and retain forever.

## §6 GOVERNANCE

The ten decisions are classified in `MASTER_GAP_REGISTER.md`; eight are resolved, while MAIL-1 and RET-1 remain on the manifest only as exact external prerequisites. Canon, permissions, events, schema draft, integration contract, evidence library, future backlog, generated API contract, Primary ledger evidence, manifest, ai-map, and this report were synchronized. Batch 6 stays 12/77 and Slice 12 was not started.

## §7 ENVIRONMENT

During iteration Windows accumulated stale duplicate MCP helper processes and prevented `npx` from spawning (`uv_spawn UNKNOWN`). The exact duplicate helper population was measured; 339 stale matching processes were stopped while retaining the newest two per helper group. Docker and repository data were untouched, `npx supabase --version` recovered, and every final verification run completed normally.

## §8 CURRENT STATE

Repository/local/Primary: 218 migrations, latest `20260909180403_a_legal_hold_always_overrides_retention`; hashes and counts as recorded in §2. Active CR `None`. Open manifest items: MAIL-1 and RET-1 external prerequisites only. Batch 6: 12/77. Working tree and upstream synchronization are reported after the final commit/push in the user handoff.

## §9 NEXT STEP

**Decision-closure complete. Start Batch 6 Slice 12 on quotations in a NEW session.**
