# ORVION MASTER SURFACE DISPOSITION

Status: **Permanent cumulative assurance record — the SSOT for one fact and one only: what audit disposition each database surface has been given, by which session, and what remains.** Never recreate; evolve. One row per `public` table. It owns no findings (those are `MASTER_GAP_REGISTER.md`), no narrative (that is the named session report), no schema (that is the catalog and `MASTER_DOMAIN_CATALOG.md`), and no test inventory (that is `supabase/tests/**`). Every cell that is not the disposition itself is a **pointer**, deliberately, so nothing here can drift from a fact it restates. Cross-reference: `MASTER_EXECUTION_PLAN.md` Batch 6 exit criteria **EC-1**, which this file exists to satisfy.

Last updated: 2026-09-05 (**created — EC-1.** Batch 6's exit criteria named a per-surface disposition record as the first thing that had to exist, because without one "how much has been audited?" is unanswerable: all 77 tables are named somewhere in `reports/**`, so *mention* is saturated and proves nothing, and 75 of 77 are named in some pgTAP file, which is a floor and not coverage. Seeded with all **77** surfaces and the first slice's **2**.)

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

**2 of 77 recorded · 2 `AUDITED` · 0 `AUDITED-OPEN` · 0 `PARTIAL` · 0 `EXEMPT` · 75 `NOT-RECORDED`.**

This count is the honest one and it is meant to be uncomfortable. It replaces two numbers that read better and mean less: "all 77 tables appear in the reports" (true, and worthless — mention is not audit) and "75 of 77 tables appear in a pgTAP file" (true, and a floor — a table named once in an unrelated fixture is not a swept surface).

| Surface | Disposition | Assurance | Session | Findings | Next |
|---|---|---|---|---|---|
| `approval_requests` | NOT-RECORDED | — | — | — | — |
| `attribution_clicks` | NOT-RECORDED | — | — | — | — |
| `booking_item_passengers` | NOT-RECORDED | — | — | — | — |
| `booking_items` | NOT-RECORDED | — | — | — | — |
| `bookings` | NOT-RECORDED | — | — | — | — |
| `branch_business_hours` | NOT-RECORDED | — | — | — | — |
| `branches` | NOT-RECORDED | — | — | — | — |
| `campaign_daily_metrics` | **AUDITED** | ADVERSARIAL | `session-2026-09-05-batch6-evidence-foundation` | CDM-1, CDM-2 | — |
| `catalog_types` | NOT-RECORDED | — | — | — | — |
| `catalog_values` | NOT-RECORDED | — | — | — | — |
| `chart_of_accounts` | NOT-RECORDED | — | — | — | — |
| `company_assets` | NOT-RECORDED | — | — | — | — |
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
| `financial_accounts` | NOT-RECORDED | — | — | — | — |
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
