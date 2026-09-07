# ORVION MASTER SURFACE DISPOSITION

Status: **Permanent cumulative assurance record — the SSOT for one fact and one only: what audit disposition each database surface has been given, by which session, and what remains.** Never recreate; evolve. One row per `public` table. It owns no findings (those are `MASTER_GAP_REGISTER.md`), no narrative (that is the named session report), no schema (that is the catalog and `MASTER_DOMAIN_CATALOG.md`), and no test inventory (that is `supabase/tests/**`). Every cell that is not the disposition itself is a **pointer**, deliberately, so nothing here can drift from a fact it restates. Cross-reference: `MASTER_EXECUTION_PLAN.md` Batch 6 exit criteria **EC-1**, which this file exists to satisfy.

Last updated: 2026-09-07 (**slice 5 — `booking_items`, the booked service that had no door of its own.** Coverage **5 → 6 of 77**. This slice was **NOT selector-chosen**: slice 4 had reproduced a High finding on it (**BOOK-3**) before its sweep began, and a reproduced defect outranks a ranking. The sweep then found four more, and the ranking's own blindness is why: the selector SUBTRACTS test coverage, and `booking_items` is one of the best-covered tables in the repository. **BOOK-5 is the finding worth carrying forward** — a guard that charged the correct permission unconditionally on every path was still defeated, because it asked "is this item mine?" of the post-image the attacking statement had just supplied. Nothing textual can measure that; only a discriminating pair found it. Also this session, and NOT part of the target: **GOV-19** (a register row that contradicted itself for fourteen days) and **GOV-16** (**Check 25**), which measured that seven registered decisions were invisible on the manifest's boot line. `MASTER_GAP_REGISTER.md` owns all nine.)

Previously: 2026-09-07 (**slice 4 — `booking_item_passengers`, and the ceiling that had been crediting it.** Coverage **4 → 5 of 77**. The slice was chosen by `scripts/batch6_select_target.ps1` (score -2; exposure 10, coverage 12 — the highest-ranked `NOT-RECORDED` surface) and closed **PAX-1**, **PAX-2** and **PAX-3** via `202607061400`. The disposition is `AUDITED-OPEN` rather than `AUDITED` because two findings remain and **neither is engineering**: **PAX-5** is an owner decision (when does a manifest become immutable) and **PAX-6** a canon one (no event vocabulary exists for a manifest change, so the swap is now authorized but still not audited). **The row that matters most is not this one:** `booking_items` gains a `Next` note carrying **BOOK-3**, PAX-1's defect on the parent table, found by root-causing why the SEC-1 ceiling had rated this surface protected — it CREDITED a conditional guard (**MEAS-2**). `MASTER_GAP_REGISTER.md` owns all eight.)

Previously: 2026-09-06 (**slice 3 — `company_assets`, and a residue found in a row that already read AUDITED.** Coverage **3 → 4 of 77**. The slice was chosen by `scripts/batch6_select_target.ps1` and closed **CA-1**, **CA-2** and — by attacking its own draft repair — **MONEY-1**, a class defect in every money CHECK in the repository. It also found that slice 1 left `campaign_daily_metrics` able to record spend denominated in nothing (**CDM-3**); that row keeps its `AUDITED` disposition and gains the finding, because a disposition records what was assessed and the currency question was not asked. `MASTER_GAP_REGISTER.md` owns all five.)

Previously: 2026-09-05 (**created — EC-1.** Batch 6's exit criteria named a per-surface disposition record as the first thing that had to exist, because without one "how much has been audited?" is unanswerable: all 77 tables are named somewhere in `reports/**`, so *mention* is saturated and proves nothing, and 75 of 77 are named in some pgTAP file, which is a floor and not coverage. Seeded with all **77** surfaces and the first slice's **2**.)

---

## How to read this file

**`NOT-RECORDED` is a statement about THIS RECORD, not about the surface.** It means no Batch 6 disposition has been recorded for that table. Many of these surfaces have been inspected, repaired and guarded by closed packages in `reports/history/` — `notification_deliveries` on 2026-09-05, `subscription_payment_proofs` on 2026-08-27, `lead_interactions` on 2026-08-28 — and none of that work is erased by a `NOT-RECORDED` row. What the row says is that the surface has **not been assessed against Batch 6's exit criteria**, which is a different and stricter question than "has anyone ever looked at it". Converting a row requires the assessment, not a memory of the earlier work.

**Disposition** — one of five, and the vocabulary is closed so `Check 22` can validate it:

| Value | Means |
|---|---|
| `NOT-RECORDED` | no Batch 6 disposition recorded (see above — not a claim that nothing was ever done) |
| `AUDITED` | swept against the EC checklist; nothing open for this surface |
| `AUDITED-OPEN` | swept; one or more findings remain open, each with a row in the gap register |
| `PARTIAL` | some axes swept and the unswept ones named in `Next` |
| `EXEMPT` | deliberately out of Batch 6 scope, with the reason in `Next` |

**Assurance** — one of three, and it is **not** a synonym for "has tests" (`MASTER_EXECUTION_PLAN.md` §10):

| Value | Means |
|---|---|
| `—` | nothing recorded |
| `TESTED` | functional coverage exists and passes |
| `ADVERSARIAL` | specific attempts were made to violate this surface's assumptions and it resisted them — negative controls, not only positive ones |

There is deliberately **no `EXHAUSTIVE` value.** Exhaustive adversarial audit is a claim about the *programme*, not about one row, and it requires every row to hold at `ADVERSARIAL` at once. Making it a per-surface label would let the strongest claim in ORVION be asserted one table at a time without anyone ever checking the whole.

**Session** — the immutable report that performed the work and holds the evidence. `Check 22` requires the file to exist. **Findings** — ids only; `Check 22` requires each to resolve in `MASTER_GAP_REGISTER.md`, which owns their status. **Next** — the exact remaining action for this surface, or `—`.

---

## Coverage

**6 of 77 recorded · 3 `AUDITED` · 3 `AUDITED-OPEN` · 0 `PARTIAL` · 0 `EXEMPT` · 71 `NOT-RECORDED`.**

**All 5 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.

This count is the honest one and it is meant to be uncomfortable. It replaces two numbers that read better and mean less: "all 77 tables appear in the reports" (true, and worthless — mention is not audit) and "75 of 77 tables appear in a pgTAP file" (true, and a floor — a table named once in an unrelated fixture is not a swept surface).

| Surface | Disposition | Assurance | Session | Findings | Next |
|---|---|---|---|---|---|
| `approval_requests` | NOT-RECORDED | — | — | — | — |
| `attribution_clicks` | NOT-RECORDED | — | — | — | — |
| `booking_item_passengers` | **AUDITED-OPEN** | ADVERSARIAL | `session-2026-09-07-batch6-slice4-booking-item-passengers` | PAX-1, PAX-2, PAX-3, PAX-5, PAX-6 | PAX-5 (owner: manifest immutability after issuance) and PAX-6 (canon: no event vocabulary for a manifest change) — both decisions, neither engineering |
| `booking_items` | **AUDITED-OPEN** | ADVERSARIAL | session-2026-09-07-batch6-slice5-booking-items | BOOK-8, BOOK-9 | `105_booking_item_service_door_test.sql` — **44 assertions, all ten attack classes, none N/A.** `202607061500` closed **BOOK-3** (the bare booked service, and its whole UPDATE half: service type, currency, ownership and re-parenting were all free), **BOOK-4** (a cross-tenant existence-and-state oracle, PAX-3 one table up), **BOOK-5** (the canon-28 scope check read the attacker's own post-image), **BOOK-6** (the finance execution gate was clearable) and **BOOK-7** (a priced item could be redenominated). `AUDITED-OPEN` rather than `AUDITED` because two remain and **neither is engineering**: **BOOK-8** is a business decision (may a finance-approval requirement be withdrawn) and **BOOK-9** a canon one (booking items have no reassignment permission where leads have REASSIGN_LEAD) |
| `bookings` | NOT-RECORDED | — | — | — | — |
| `branch_business_hours` | NOT-RECORDED | — | — | — | — |
| `branches` | NOT-RECORDED | — | — | — | — |
| `campaign_daily_metrics` | **AUDITED** | ADVERSARIAL | `session-2026-09-05-batch6-evidence-foundation` | CDM-1, CDM-2, CDM-3 | — |
| `catalog_types` | NOT-RECORDED | — | — | — | — |
| `catalog_values` | NOT-RECORDED | — | — | — | — |
| `chart_of_accounts` | NOT-RECORDED | — | — | — | — |
| `company_assets` | **AUDITED** | ADVERSARIAL | `session-2026-09-06-batch6-slice3-company-assets` | CA-1, CA-2, MONEY-1 | — |
| `complaints` | NOT-RECORDED | — | — | — | — |
| `conversation_messages` | NOT-RECORDED | — | — | — | — |
| `conversations` | NOT-RECORDED | — | — | — | — |
| `countries` | NOT-RECORDED | — | — | — | — |
| `currencies` | NOT-RECORDED | — | — | — | — |
| `customer_contact_methods` | NOT-RECORDED | — | — | — | — |
| `customer_identity_merges` | NOT-RECORDED | — | — | — | — |
| `customer_identity_signals` | NOT-RECORDED | — | — | — | — |
| `customer_notes` | NOT-RECORDED | — | — | — | — |
| `customers` | NOT-RECORDED | — | — | — | — |
| `departments` | NOT-RECORDED | — | — | — | — |
| `document_links` | NOT-RECORDED | — | — | — | — |
| `document_retention_policies` | NOT-RECORDED | — | — | — | — |
| `document_storage_findings` | NOT-RECORDED | — | — | — | — |
| `document_versions` | NOT-RECORDED | — | — | — | — |
| `documents` | NOT-RECORDED | — | — | — | — |
| `events` | NOT-RECORDED | — | — | — | — |
| `exchange_rate_adjustments` | **AUDITED** | ADVERSARIAL | `session-2026-09-05-batch6-evidence-foundation` | ERA-1 | — |
| `exchange_rates` | NOT-RECORDED | — | — | — | — |
| `feature_entitlements` | NOT-RECORDED | — | — | — | — |
| `financial_accounts` | **AUDITED-OPEN** | ADVERSARIAL | `session-2026-09-05-batch6-adversarial-program` | FA-1, FA-2 | FA-2 is an owner question: may a bank account receive a payment in another currency? |
| `holidays` | NOT-RECORDED | — | — | — | — |
| `integration_cursors` | NOT-RECORDED | — | — | — | — |
| `internal_supplier_links` | NOT-RECORDED | — | — | — | — |
| `invoices` | NOT-RECORDED | — | — | — | — |
| `journal_entries` | NOT-RECORDED | — | — | — | — |
| `journal_entry_lines` | NOT-RECORDED | — | — | — | — |
| `languages` | NOT-RECORDED | — | — | — | — |
| `lead_assignments` | NOT-RECORDED | — | — | — | — |
| `lead_interactions` | NOT-RECORDED | — | — | — | — |
| `leads` | NOT-RECORDED | — | — | — | — |
| `marketing_campaigns` | NOT-RECORDED | — | — | — | — |
| `nationalities` | NOT-RECORDED | — | — | — | — |
| `notification_deliveries` | NOT-RECORDED | — | — | — | — |
| `notifications` | NOT-RECORDED | — | — | — | — |
| `offline_conversion_deliveries` | NOT-RECORDED | — | — | — | — |
| `offline_conversions` | NOT-RECORDED | — | — | — | — |
| `otp_challenges` | NOT-RECORDED | — | — | — | — |
| `passengers` | NOT-RECORDED | — | — | — | — |
| `payment_allocations` | NOT-RECORDED | — | — | — | — |
| `payments` | NOT-RECORDED | — | — | — | — |
| `permissions` | NOT-RECORDED | — | — | — | — |
| `quotation_items` | NOT-RECORDED | — | — | — | — |
| `quotations` | NOT-RECORDED | — | — | — | — |
| `receipts` | NOT-RECORDED | — | — | — | — |
| `refunds` | NOT-RECORDED | — | — | — | — |
| `role_permissions` | NOT-RECORDED | — | — | — | — |
| `roles` | NOT-RECORDED | — | — | — | — |
| `scheduled_job_findings` | NOT-RECORDED | — | — | — | — |
| `security_events` | NOT-RECORDED | — | — | — | — |
| `service_requests` | NOT-RECORDED | — | — | — | — |
| `subscription_payment_proofs` | NOT-RECORDED | — | — | — | — |
| `subscription_plans` | NOT-RECORDED | — | — | — | — |
| `subscriptions` | NOT-RECORDED | — | — | — | — |
| `suppliers` | NOT-RECORDED | — | — | — | — |
| `tasks` | NOT-RECORDED | — | — | — | — |
| `tenant_license_activations` | NOT-RECORDED | — | — | — | — |
| `tenants` | NOT-RECORDED | — | — | — | — |
| `totp_enrollments` | NOT-RECORDED | — | — | — | — |
| `trusted_devices` | NOT-RECORDED | — | — | — | — |
| `usage_counters` | NOT-RECORDED | — | — | — | — |
| `user_branch_assignments` | NOT-RECORDED | — | — | — | — |
| `user_permission_grants` | NOT-RECORDED | — | — | — | — |
| `user_role_assignments` | NOT-RECORDED | — | — | — | — |
| `users` | NOT-RECORDED | — | — | — | — |

---

## The surface set is not maintained by hand

`Check 22` derives the expected set from `supabase/migrations/**` — every `create table` less every `drop table` — and fails if this file names a surface that does not exist or omits one that does. So a migration that adds a table makes the build red until the table has a row here, which is the only mechanism that keeps a coverage record honest as the schema grows.

**Its ceiling, stated because a registry that oversells a guard is the failure this repository keeps finding (MEAS-1).** It parses DDL text. A table created by dynamic SQL, or renamed by `ALTER TABLE ... RENAME`, would fool it. That is bounded rather than open: the derivation is cross-checked from the other side by `scripts/verify_database.sql`'s table-count assertion and by `check_database_parity.ps1`'s structural surface, both of which read the live catalog. Today the derivation returns exactly the 77 tables the catalog holds.

End of document.
