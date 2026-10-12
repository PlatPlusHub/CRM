# ORVION delivery assessment and owner-decision package

Class: 🟠 Historical-Immutable — research and proposal record
Date: 2026-10-11
Status: Proposal only. Nothing in it is approved except what a later owner decision says. Recorded on 2026-10-12 by SPEC-269 from the session that produced it, because the analysis and its eight open decisions existed only in a chat transcript.
Purpose: Preserve the 2026-10-11 independent assessment, its proposed decisions D1–D9 and its delivery plan, so the register rows OD-1…OD-9 have their evidence in the repository.

---

## §0 HANDOFF

- **INHERITED:** `main` at `f6c30d0` on 2026-10-12. The assessment was made on 2026-10-11 in PLAN mode with no write authority. It read the repository, Primary, n8n and current Google documentation, and changed nothing.
- **PROVEN:** the facts in §1, each read on 2026-10-11, and PAY-9's measurement, which the register owns.
- **UNPROVEN:** the time estimates, and every proposed default in §8. They are recommendations, not decisions.
- **CHANGED:** nothing then. On 2026-10-12, SPEC-269 recorded this report and the register rows OD-1, OD-2, OD-3, OD-5, OD-8 and OD-9.
- **REMAINING:** the owner's answers to OD-1…OD-9. D4 was decided by the owner and is carried by SPEC-265; D6 is DC-10/DC-28; D7 is OPS-1.
- **DO NOT TOUCH:** do not treat any default below as decided. Do not reorder Batch 6 on the strength of this report: OD-9 is the owner's to answer.
- **NEXT:** the Action registry in `MASTER_EXECUTION_PLAN.md` lists these decisions as BLOCKED on the owner, with their boundaries.

**Superseded since this was written, and kept as it was:**
- §2's Google Ads access path. Google retired developer tokens on 2026-09-09. The owner then decided D4 (ORVION never modifies Google Ads; read-only reporting is a Day-1 requirement), and SPEC-265 chose a free read-only Google Ads script delivered through n8n. The API is the upgrade path.
- §3's "PAY-9 placement" item. SPEC-269 classifies PAY-9 in the Action registry.

---

## §1 Current reality

**The short version:** ORVION has a strong, heavily tested backend that nobody has ever used. There is no application, no automation and no ad-data feed, and it holds no real data.

| Fact | Evidence (2026-10-11) |
|---|---|
| Backend | 78 tables, 80 client RPCs, 8 reporting views, 251 migrations. Repository, local stack and Primary are identical. 2,936 database assertions and 464 HTTP assertions. |
| Security audit (Batch 6) | 41 of 78 tables audited adversarially. At about 2 slices a day, the remainder is roughly 3 weeks of work. |
| Primary usage | 0 tenants, 0 login users, 0 business rows. Only reference data exists. |
| Frontend | None. ADR-0014 already chose a server-rendered web app that talks to Supabase directly. |
| n8n | 0 workflows and 2 credentials: the Postgres integration role, and the Data Manager OAuth credential. That credential is still in Google "Testing" mode, so its token expires every 7 days. |
| Google conversions | The Data Manager outbox is fully built in the database, and one validate-only test call was made. Nothing has been delivered. |
| Google Ads reporting | Not built. `campaign_daily_metrics` exists, but nothing writes to it. |
| Finance: exists | Invoices, payments, allocations, receipts, refunds and supplier payments. Cost, selling price and profit per booking item. Commission fixed at 10% of gross profit. Customer and supplier balances. A 6-account chart with manual journal entries. |
| Finance: missing | Operating expenses, rent, salaries, commission payable or paid, ad-spend ingestion, period close, a single reporting currency, and tax. Payments never post to the journal automatically. |
| Readiness tooling | 131 findings unsettled. PAY-9 was unclassified: a fully paid booking still owes its whole invoice in the booking-level balance. |

Most domains are implemented and tested at the database level. None is integrated, usable by an employee, or production-ready.

## §2 Target architecture

- **Supabase stays the only authority.** The app talks to PostgREST and the RPCs as the logged-in user, so RLS and `app.authorize` decide everything. No business rule is copied into frontend code.
- **Frontend:**
  - Next.js (App Router) with TypeScript and `@supabase/ssr`;
  - shadcn/ui on Radix, which handles right-to-left layout;
  - next-intl for Arabic first, then English;
  - react-hook-form with zod, and TanStack Table;
  - typed wrappers generated from `supabase gen types` and the generated API contract;
  - Playwright end-to-end and accessibility tests against the local stack.
- **Refinement 1: a tiny privileged server module.** Creating login accounts and provisioning a tenant need `service_role`. They live in one isolated module that first proves the caller is authorized. No employee workflow uses that key.
- **Refinement 2: n8n is never in the path of a business write.** It handles:
  - Data Manager delivery;
  - a daily ad-reporting sync;
  - email once MAIL-1 clears;
  - provider retries.

  It writes only through `orvion_integration` RPCs.
- **Refinement 3:** any future Google Ads change goes request → approve → execute. It is not needed for launch, and D4 now excludes it.
- **Refinement 4: a proportionate check profile for the app.** The UI holds no authority, so it needs end-to-end, accessibility and "logged in but not permitted" tests, not the per-table adversarial process. That is a governance change for the owner (OD-9).

**The smallest correct finance foundation (OD-1):**

| Layer | Content | Status |
|---|---|---|
| Operational sub-ledgers | Bookings, receivables, cash, payables | Exists. Needs PAY-9, PAY-5/FIN-11, RFD-3, PAY-4 and JE-2 fixed |
| Operating expense register | One new table: category mapped to an account; amount, currency and rate; period; paid-from account; payee. Optional branch, department, campaign and employee. Attachment, approval, then locked, with corrections by reversal. Salaries are monthly totals per employee, never a payroll engine | New |
| Ad spend | Daily Google Ads cost into `campaign_daily_metrics` through n8n | New writer |
| Management P&L read model | Revenue and cash, then gross profit, contribution after commission and attributable ad spend, operating profit, and net profit only where every input exists; then cash flow and aging. Every number drills down to its source rows, in one reporting currency with the rate disclosed | New views |
| Period lock | A "closed through" date per tenant; corrections are dated in the open period | New, small |

Industry reference points: an agent reports its margin as revenue under IFRS 15 and EAS 48's principal-versus-agent rule. Mature ERPs report contribution margin and do not spread rent or salaries across bookings.

**Rules against double counting, each to be enforced by a test:**
- Commission: the P&L uses the derived accrued commission, and a payout is a cash movement, never a second expense.
- Google Ads: spend comes only from the ad feed, and paying Google's invoice is a cash movement.
- Shared costs appear only at branch or company level.
- Statutory books stay with the external accountant. ORVION's figures are management accounting, labelled unaudited until one month-end is reconciled.

## §3 Unified action queue (as proposed; now carried by the Action registry)

| Class | Items | Who | Latest safe boundary |
|---|---|---|---|
| Proven defects | SUB-4, USR-3, BOOK-11/12, PAY-5+FIN-11, RFD-3, PAY-4, JE-2/DC-11, PAY-9, ARCH-2, ENTRY-1, LI-3, queue item 10 | Engineering | before the workflow concerned is enabled |
| Engineering prerequisites | DC-2 idempotency keys; the integration RPC for ad metrics; register hygiene for N1, DC-5, RC-4, R8 and RC-1 | Engineering | DC-2 before the first finance screen writes |
| Owner policy | OPS-1, DC-10/28, DC-12, the decisions in §8 | Owner | before the first production tenant |
| External / legal | MAIL-1, RET-1, PH8-10, DC-4, DC-22, R3/BF-4, Google OAuth verification | Owner, counsel, Google | the feature stays off until cleared |
| Unproven | STEPUP-1, PAX-4; SEC-2 re-measured against real UI journeys | Engineering | each table's audit slice |
| Future-only | the full GL with automatic posting (CDD-5), payroll engine, keyword planning, Meta CAPI, WhatsApp, multi-tenant onboarding UI | — | their triggers |

## §4 Critical launch blockers

1. No one can log in in a production-safe way. Canon 20 requires an email code on a new device, and email is blocked by MAIL-1 (OD-5).
2. No application exists.
3. No tenant has ever been set up on Primary, and doing so needs the privileged path in §2.
4. Finance correctness: PAY-9, JE-2 and the closure queue. There is also no expense, salary or ad-spend input, so profitability is NOT READY.
5. Recovery: RPO and RTO are unset, and no restore has been rehearsed (OPS-1).
6. Integrations: zero n8n workflows, and an OAuth token that expires every 7 days.
7. Zero hours of real use.

## §5 Parallel workstreams

Only the migration stream must stay single-file: one migration contract at a time, with Batch 6 keeping priority.

| Stream | Needs migrations? | Conflicts with Batch 6? |
|---|---|---|
| A. Batch 6 slices | Yes | — |
| B. Frontend foundation and read-only journeys against the local stack | No | No |
| C. Finance model design, as canon and ADR drafts | No | No |
| D. Google access and one read-only reporting query (now SPEC-265's script route) | No | No |
| E. Counsel and policy: MAIL-1, DC-4, tax status, the accountant's revenue policy | No | No |
| F. n8n Data Manager workflow | No | kept after Batch 6, as the owner ordered |

## §6 Roadmap, event-based

| Phase | Ends when | Contents |
|---|---|---|
| P0, now | Batch 6's EC-1…EC-11 hold | A, plus B (foundation, login with MFA, app shell, Customer 360 and lead inbox, read-only), C, D and E |
| P1, gate preparation | the first readiness-gate evaluation | the closure queue including PAY-9; DC-2; expense register, ad-metrics writer, period lock and P&L views; write screens journey by journey, from lead to supplier |
| P2, integrations | each one's gate passes | the n8n Data Manager workflow and the call feedback loop; the Google Ads daily sync and marketing dashboard; email once MAIL-1 clears; a restore drill |
| P3, pilot | one month-end reconciled | real staff use ORVION alongside the current process, and its P&L is reconciled with the accountant |
| Go-live | per-workflow READY | profitability reported as management accounts once P3 reconciles |

## §7 First execution candidates

- **FE-0, web foundation and the first read-only journey:**
  - **Scope:** a UI-stack ADR and an `apps/web` scaffold; Supabase login with mandatory MFA for owner, CEO, finance manager and system administrator; membership selection; navigation from `effective_permissions` and `tenant_capabilities`; Arabic right-to-left and English on desktop and mobile; customer search, Customer 360 and the lead inbox; Playwright in CI.
  - **Touches:** no migrations, no Primary.
  - **Acceptance:** a non-permitted role sees neither the entry nor the data; a tenant-B user gets nothing; a high-risk role without MFA is refused; accessibility checks are clean in both languages at 390 px.
- **FIN-0, the profitability model decision package:**
  - **Scope:** the waterfall definitions, each line's source, the double-counting tests and the drill-down keys; canon 01, 07 and 14 amendment drafts and an ADR draft; the gap list that becomes the expense-register contract.
  - **Touches:** documents only.
- **GADS-0, Google access and a read-only feasibility proof:** superseded by D4 and SPEC-265.

## §8 Owner decisions, each with its proposed default

| | Decision | Proposed default | Now |
|---|---|---|---|
| D1 | Launch scope | Include the expense register, salary totals and the management P&L, plus read-only Google Ads, in release 1, framed as management accounting, not statutory books and not a payroll engine | OD-1 |
| D2 | Revenue policy | Show gross booking value and net revenue; the P&L revenue line is the net margin for agent services; recognize at issuance; the accountant confirms | OD-2 |
| D3 | Reporting currency | EGP, at ORVION's manual exchange rate for the transaction date | OD-3 |
| D4 | Google Ads changes from ORVION in v1 | No: read-only plus deep links | **decided by the owner**; SPEC-265 |
| D5 | Login | An authenticator app (TOTP) for all staff at launch; email codes after MAIL-1; changes canon 20 | OD-5 |
| D6 | Legacy data | Start clean; open customer and supplier balances as opening items; in-flight bookings entered by hand | DC-10, DC-28 |
| D7 | Recovery and cost | Supabase point-in-time recovery, an RTO of 4 hours, web hosting in Primary's EU region; a cost approval | OPS-1 |
| D8 | Salary visibility | Monthly totals per employee, visible only to a new view-payroll permission | OD-8 |
| D9 | Sequence exception | Run streams B–E beside Batch 6 with a proportionate app check profile; keep the n8n workflow after Batch 6 | OD-9 |

## §9 Critique of the owner's assumptions, as given

- **Agreed:**
  - the split of duties between Supabase, the frontend, n8n and secure server code;
  - read-only reporting and account management as separate capabilities;
  - Data Manager and the Google Ads API kept distinct;
  - reporting NOT READY rather than hiding it;
  - starting the frontend early, because real journeys expose defects the database tests never asked about.
- **Would change:**
  - Expose each module when its journey passes the gate, not merely because it is implemented.
  - The honest launch claim is management operating profit, not net profit.
  - Do not rebuild a Google Ads editor.
  - The largest risk is zero real usage, so a reconciled one-month parallel run should be a launch criterion.
  - Build for one tenant first.
