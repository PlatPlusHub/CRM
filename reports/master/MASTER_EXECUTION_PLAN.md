# ORVION MASTER EXECUTION PLAN

Status: **Permanent cumulative execution plan.** Never recreate; evolve. Batches are ordered by *foundation-reopen risk first*, not by roadmap phase. Implementation timing is the owner's; this plan states the safest order and dependencies so any batch can be executed directly from the Master documents. Cross-reference: `MASTER_GAP_REGISTER.md`, `MASTER_DEPENDENCY_GRAPH.md`.

Last updated: 2026-09-02 (**supplier credit authority — SUP-2.** The table-by-table audit's next slice, chosen by measuring the writable surface rather than from a list; three candidate classes were discarded by that measurement before the fourth produced a defect. The entry is in Batch 6 below, and the NEXT SLICE pointer was replaced in the SAME edit rather than left to go stale as it did on 2026-09-01. Prior entry follows.)

Previously: 2026-09-01 (**care/conversation re-audit — PARENT-1.** The slice was re-entered from live state and produced a class fix (`202607059400`); the entry is in Batch 6 below. **One staleness corrected while there, and it is the kind this header already warns about:** Batch 6 still carried "NEXT SLICE: ATTR-2" after `202607059300` closed ATTR-2 on 2026-09-01 — the same day this document recorded SEC-1c and SUP-1 and left the pointer alone. A plan that names a finished slice as the next one is worse than a plan that names none. Prior entry follows.)

Previously: 2026-08-29 (**pre-Phase-10 program reconciliation.** Batch 6's open list corrected against live evidence — two items were already closed by later packages and had stayed open (**GOV-6**), and the table-count scopes were refreshed. The header itself had read "2026-07-15" while Batch 6 below runs to 2026-08-29; a plan whose own date is six weeks stale invites a reader to distrust the statuses too. Seven findings this document *defined* rather than referenced — LIC-1, DEAD-1, DEAD-2, BLOCKED-4, BLOCKED-5, CANON-26-1 and A3 — now have rows in `MASTER_GAP_REGISTER.md` per `GOVERNANCE.md §2` (**GOV-3**), and Check 11 enforces it.)

**Guarantee:** once Batch 0 + Batch 1 are designed into canon and implemented, no later batch reopens the foundation. Every later batch is additive new tables/logic.

---

## Batch 0 — Foundation-lock + safety net (before more finance/CRM/PII data)
*These are the only items that get more expensive as data accrues. Do the test net first.*
1. **DC-16 pgTAP harness** — ✅ **DONE (SPEC-113)**. `supabase/tests/**` wired into CI; catalog-driven invariants live: RLS coverage (V5, negative-checked), append-only forbid_mutation backbone, and the money-currency scale invariant carried as a `todo` that surfaces DC-1 (have:22 want:0) without failing CI. *Was the precondition for the rest of Batch 0 — now satisfied.*
2. **Record consolidated ADRs** (design only): Party (CDD-1), Product/Inventory (CDD-2), Pricing+Tax (CDD-3/4), Accounting-depth (CDD-5), Integration+selective-outbox (CDD-7), Event-contract+registry (CDD-8/N1), Engagement+consent (CDD-10/N5), Subscription two-plane + feature flags, Franchise-read-path (CDD-9/C1), Localization (CDD-11). **Amend** ADR-0002 (UUIDv7 DC-13), ADR-0006 (event registry N1), ADR-0021 (INV-1..4).
3. **Built-table structural retrofits:** R1 (events dims), R2 (JE dims — hooks), R3 (invoice_lines — hooks), R4 (booking_items product/ref + DC-7 ticketing_deadline + BF-1), **R5 (attribution consent) ✅ DONE (SPEC-119)**, R6 (party_id + credit terms), **R7/DC-1 money precision ✅ DONE (SPEC-118)**, R8/B3 (unique keys). *(DC-13 UUIDv7 REMOVED from Batch 0 by Evidence Validation session 4 → DEFERRED with trigger; see `PENDING_ARCHITECTURE_FINDINGS.md`.)*
4. **Substrate hooks:** DC-2 idempotency-keys table, DC-4 PII-erasure boundary decision (which columns, satellite vs crypto-shred).

## Batch 1 — Cross-cutting substrate (design once; consumed everywhere)
Party + contact-identities + **single consent** (CDD-1/N5) · accounting dimensions model (CDD-5 base) · `document_sequences` + numbering (CDD-6) · **event_type registry** (N1) · integration providers/outbox/webhook-inbox (CDD-7) · **DC-3 concurrency discipline** · **DC-6 sensitive-read log** · **DC-8 reconciliation sweepers** · **DC-9 timezone anchor** · i18n translations (CDD-11 base) · feature-flags + permission×feature rule (N2) · DC-4 erasure implementation.

## Batch 2 — Pre-production hardening (all additive; no completed-phase file changed)
~~A1 (RLS init-plan wrapping)~~ ✅ **DONE (SPEC-117)** — all 63 policies wrap `current_tenant_id()` in a scalar subquery + pgTAP-guarded · ~~A2 (18 tenant_id indexes)~~ ✅ **DONE bare-index portion (SPEC-114)** — 18 tenant_id indexes added + pgTAP-guarded; composite refinements (tenant_id+status/customer_id/booking_id) still deferred to their access-path capabilities · B5 (DML grants + anon scope) + **DC-5 storage RLS** · **DC-15 service_role bounding** · B2 (CHECK constraints) · B6 (naming normalization) · B1 (reference-data integrity) · **OPS-1** (structured logging/metrics/tracing + documented RPO/RTO).

## Batch 3 — Phase 8 Offline Conversion (on the substrate)
Attribution/outbox/event-registry ready → click capture at intake, attribution engine, conversion events, delivery+retry. **Owner-Decision open:** Google Ads Data Manager transport + consent (legacy import blocked 2026-06-15).

## Batch 4 — Finance depth
invoice_lines + tax (BF-4/CDD-4) · dimension posting (R2/CDD-5) · AP `supplier_bills` (BF-7) · **DC-10 opening balances** · **DC-11 realized FX** · accounting periods · treasury/reconciliation (BF-6) · currency revaluation · amendment/change-fee/ADM (BF-10) · price-components (CDD-3).

## Batch 5 — Operational domains (pulled on owner demand; each additive)
Product/Inventory/Allotments (CDD-2) · Groups + **DC-12 passenger_relationships** (BF-2) · Engagement build-out + **DC-17 realtime** (CDD-10/RC-2) · HR/Payroll/commission (BF-5) · Procurement · Fleet/Resources (BF-12) · Franchise-consolidation + **DC-14 offboarding** (CDD-9) · Subscription/billing lifecycle (RC-1) · **RC-4 reporting/dashboard read-model layer** (first views/matviews; BF-11 statements) · Localization build-out · fraud/chargeback (BF-8/9) · **DC-18 pgvector**/AI · FOE modules (assets-depreciation, insurance-claims, workflow-engine, loyalty) as owner scopes them.

---

## Batch 6 — Foundation Completion Programme (owner-directed 2026-08-24 → current)
*Added 2026-08-27. This batch did not exist when Batches 0–5 were written: it is the owner's
zero-known-debt programme, executed package-by-package with EARN-IT. It does not supersede Batches
0–5; it runs ahead of them because each item is a LIVE defect or a day-one blocker rather than
additive capability.*

**Closed (each EARNED with behavioural proof, see `reports/history/`):**

| Package | Migration | What it actually fixed |
|---|---|---|
| WP-00 | `202607053000` | Audit-spine forgery: any employee could INSERT a forged, backdated event blamed on a colleague into an append-only table |
| WP-03 / SPEC-152 | `202607053100` | Subscription state was INVERTED — `read_only` permitted writes, `suspended`/`expired`/`cancelled` denied reads |
| WP-03 discovery | `202607053200` | Two cross-tenant aborts the gate introduced: one lapsed tenant aborted the shared SLA run and stalled the n8n conversion cursor |
| WP-01 | `202607053300` | Four creation events with real producers that never fired; timelines began mid-relationship |
| WP-02 / SPEC-153 | `202607053400` | Five Class A events + a Finance-visibility defect (`payment_allocation` events were invisible to `finance_manager`) |
| SPEC-154 | `202607053500`, `202607053600` | The ordinary employee could not quote or book — 15 canon-mandated permissions were never seeded; and `create_booking` was broken on the direct path for every role |
| SPEC-154-A | `202607053700` | The financial guard authorized by ROLE only, so canon's `assigned` scope on ENTER_COST/ENTER_SELLING_PRICE could not be honoured; guard made scope-aware and both permissions granted |
| SPEC-155 | `202607053800` | An employee could set the basis of their own commission; commission is now system-derived (10% of gross profit), overwritten on every write path, with commission_amount/company_profit exposed through the existing financial accessor. **Closes BLOCKED-3.** |

**Open, ordered by evidence (highest day-one/business impact first):**

1. **`app.create_booking_item` accepts a `p_commission_rate` parameter that is now silently ignored.**
   A caller (future UI, n8n) can pass a value, get no error and no effect — a misleading contract.
   Classified **A / FIX NOW**; separated only because removing a parameter is an integration-contract
   change that deserves its own package. **DONE 2026-08-27 — SPEC-156 (`202607053900`).** Dropped
   rather than replaced, so no stale overload survived; guarded in `41_commission_derivation_test.sql`.
1b. **Subscription lifecycle, trial and platform authority — DONE 2026-08-27, SPEC-157
   (`202607054000`).** Closes **BLOCKED-1**, **BLOCKED-2** and canon **C5**. Three defects were
   proven live first: (i) `app.provision_tenant` created **no subscription row**, and
   `app.subscription_allows_write` fails closed on absence, so **every newly provisioned tenant was
   unable to write on all 42 gated tables** — day one of a real agency failed; (ii) `ends_at` /
   `grace_ends_at` / `read_only_started_at` were **decorative** — read by one reporting view,
   consumed by no logic, advanced by no job, so an expired trial kept write access forever;
   (iii) `tenants.status` was unconstrained free text nothing read, a second lifecycle competing
   with the authority canon 35 §8 names. Fixed: 30-day full-feature (Enterprise) trial created at
   provisioning; write-once trial stamp on `tenants`; dates load-bearing in the gate **and** advanced
   by a daily `pg_cron` job per canon 26; 5-value `subscription_period` catalog with **lifetime
   modelled as `ends_at is null`** under CHECK constraints; the 11 subscription event types given
   their first producers. Platform authority is `service_role`-only functions, **not** a tenant
   permission — `app.has_permission` is tenant-bound by construction, so `MANAGE_SUBSCRIPTION`
   remains held by no role and a test now pins that. Guard: `42_subscription_lifecycle_test.sql`.
1c. **SPEC-158 — tenant license activation credential — DONE 2026-08-27 (`202607054100`).** Closes
   canon **C4**, open since 2026-07-15, where canon 09 recorded the activation-code idea and said it
   "requires security review before implementation". That review's outcome: **deliberately not
   TOTP** — `totp_enrollments` stores no secret by design and canon 34 / ADR-0017 place every
   authentication factor in Supabase Auth, so a per-tenant TOTP seed would be the first auth secret
   ORVION ever stored; and TOTP is a *repeating* credential where a *single-use* one is required.
   Built instead: a single-use, hashed (SHA-256), expiring token whose plaintext is returned once and
   never persisted, carrying the plan/period/auto-renew terms the Platform Owner fixes at issuance so
   redemption can apply them but never choose them. Replay closed by consumption, rotation is
   re-issuance (which revokes the outstanding token), revocation is a platform function.
   `public.security_events` gained its **first producers** — a gap open since the WP-00 sweep.
   Guard: `43_license_activation_test.sql`. **Known limitation LIC-1:** a *refused* redemption is not
   audited — `raise` rolls back its own audit row and PostgreSQL has no autonomous transaction. The
   first version shipped that INSERT anyway and its own test caught that the row was never written;
   rather than keep code that looks like auditing and never runs, the limitation is stated in the
   function body, pinned by an assertion, and classified **BLOCKED BY EXTERNAL DEPENDENCY**
   (an out-of-transaction audit hop). Successful redemptions *are* audited; replay is closed
   regardless; a 128-bit token makes guessing infeasible.
1d. **SPEC-159 — employee performance & earnings report — DONE 2026-08-27 (`202607054300`).**
   `reporting.my_sales_performance`, a `security_invoker` view scoped by
   `sales_owner_user_id = app.current_user_id()`. Money comes from
   `cross join lateral app.item_financials(bi.id)` — `authenticated` cannot SELECT `cost_amount` or
   `commission_rate` (proven), so a view naming them would fail for every employee; this is what
   keeps SPEC-139 intact rather than weakened. A colleague's rows are **absent, not masked**: a
   masked row still discloses that a colleague sold something, to whom, and when. Archived and
   `cancelled`/`no_show` items are excluded, reusing `app.booking_item_profit`'s existing rule.
   LEFT joins deliberately, because an item can be the caller's while its parent booking is not
   visible to them — an inner join would under-report the employee's own commission.
   **Exactly one view** was added: the employee already reads their own leads, quotations, customers
   and bookings under RLS, and `reporting.sales_activity` / `lead_performance` already aggregate per
   owner, so only the money needed a new object. **No EXPORT permission invented** — canon 25 defines
   none, every listed filter is a WHERE clause over exposed columns, and PostgREST serves the same
   view as CSV. Airline reporting is `supplier_type_code = 'airline'`; canon 32 defers airline
   reference tables, so no dimension was invented. Guard: `45_employee_performance_test.sql`.
1e. **SPEC-159-A — per-passenger financial authority — DONE 2026-08-27 (`202607054200`).**
   **A prerequisite discovered inside SPEC-159's lineage pass and inserted rather than skipped.**
   `booking_item_passengers.cost_amount_override` / `selling_amount_override` — the per-passenger
   fare and cost — had none of the protection their `booking_items` siblings have carried since
   SPEC-139/145/154-A: the column was **readable by `authenticated`** (proven live, while
   `booking_items.cost_amount` is not), writable through `link_passenger_to_booking_item` on **any
   item the caller could see** with only `CREATE_BOOKING_ITEM` and no scope check, and writable by
   direct DML besides. RLS made it reachable rather than theoretical — department continuity means a
   colleague's item is visible. It survived four financial packages because
   `link_passenger_to_booking_item` had **zero test coverage**. Fixed with the same permissions, the
   same `app.is_my_booking_item` scope test and the same tenant-wide exemption the parent table uses;
   enforced by a trigger because direct DML was the unguarded path. Guard:
   `44_passenger_financial_authority_test.sql`. Related open items, both recorded not hidden:
   **DEAD-1** the override columns still have no reader (kept, not dropped — per-passenger pricing is
   inevitable in a travel agency and AGENTS.md §3 keeps inevitable structure); **DEAD-2**
   `refunds.booking_item_id` and `payments.booking_item_id` have no producer, so item-level refund
   and payment attribution is a genuine gap for the finance package.
2. **SPEC-154-B — RESOLVED 2026-08-31 (`202607058700`).** The binary gate genuinely could not express
   canon's "assigned related only", and granting it would have regressed SPEC-139 — so the scope was
   expressed as a *predicate* instead (`app.is_document_responsible`), minting nothing. Owner adopted
   Option C. Status and evidence: `MASTER_GAP_REGISTER.md`; the durable rule is **ADR-0026**.
3. **WP-04 — documents/storage. NEXT.** Discovery pass run 2026-08-27; findings proven live and
   recorded here so the package starts from evidence rather than from a re-scan:
   * **`storage.buckets` = 0, `storage.objects` = 0, `pg_policies` in schema `storage` = 0 on
     Primary**, while `document_versions.storage_path` is **NOT NULL**. Every upload is therefore
     required to record a path into storage that does not exist.
   * **DOC-1 / DOC-3 — DONE 2026-08-27 as WP-04-A (`202607054400`).** Re-introspection found DOC-1
     was wider than first recorded: `app.add_document_version` takes `p_storage_path` too, and
     `authenticated` holds INSERT/UPDATE on `document_versions` directly — three caller-controlled
     paths, not one. **DOC-3** (new): nothing forced anyone through the RPC, so a version's
     `storage_path` could be rewritten by direct DML with no permission check and no event — the
     WP-00 forgery class in the document domain. Fixed by derivation, not validation:
     `app.document_storage_path` is the single source of the object key (tenant-first, so storage
     policy can isolate on segment 1, and provider-independent by design), and a trigger derives
     `version_number` / `storage_path` / `uploaded_by` on INSERT while freezing a version's identity
     on UPDATE. Direct DML now costs `CREATE_DOCUMENT_VERSION` — verified safe first: every role
     holding `UPLOAD_DOCUMENT` already holds it. Guard: `46_document_write_integrity_test.sql`.
     *Correction recorded:* a partial unique index for "one current version" was attempted and
     rejected by the database — `202607041900` already created it, so that invariant was never open.
   * **WP-04-B — DONE 2026-08-27 (`202607054500`).** DOC-2 turned out to be **five** layers, not
     three: the missing type; `subscription_payment` already a link-target type with no branch in
     `upload_document`; `document_links.subscription_payment_proof_id` with no producer;
     `subscription_payment_proofs.status_code` as **unconstrained free text** (no catalog, no FK, no
     trigger); and no review path, so `REVIEW_SUBSCRIPTION_PAYMENT` governed nothing. Delivered as
     one capability: `app.upload_subscription_payment_proof` (one transaction, four rows, resolving
     the circular dependency), `app.platform_review_payment_proof` (service_role only, canon-26
     pending-only so approval cannot be replayed, optionally activating in the same transaction), the
     `payment_proof` type added to `app.is_financial_document_type`, the status column given canon
     26's existing `approval_status_code` family, and **the narrowed gate**: a lapsed tenant may
     upload a renewal proof and nothing else, which is what canon 28's Read-Only Subscription Mode
     always said and had never enforced. Guard: `47_payment_proof_lifecycle_test.sql`.
     *Regression corrected:* `35_subscription_write_gate_test` used `document_type_code = 'other'`
     titled "Renewal payment proof" as a stand-in — the fixture now uses the real type, and the old
     one would pass today only because the exemption was blanket.
     New items: **PP-1** `subscription_payment_proofs.reviewed_by` references `public.users`, which
     holds only tenant users, so a Platform Owner reviewer cannot be recorded there — left NULL and
     audited via events; a schema correction is owed but blocked on there being no platform-identity
     table. **PP-2** `document_links` RLS has no branch for `subscription_payment_proof_id`; the
     insert works only because `VIEW_ALL_BRANCHES` and `MANAGE_TENANT_SETTINGS` happen to be the same
     role set — an implicit coupling to be made explicit in WP-04-C when that policy is rewritten.
   * **WP-04-C — DONE 2026-08-27 (`202607054600`/`4700`/`4800`).** **Provider decided on evidence:
     Supabase Storage**, on one decisive property and explicitly NOT on being already present —
     `storage.objects` is a PostgreSQL table with RLS (verified live: `relkind='r'`,
     `relrowsecurity=true`, 0 policies, i.e. fail-closed), so object authorization and row
     authorization are the **same mechanism**: an object is visible exactly when its
     `document_versions` row is visible, with no visibility rule restated. Rejected with reasons:
     **GCS** — dynamically generated IAM policies are unsupported on GCP and IAM policy size becomes
     a ceiling as tenants multiply, with a "token vending machine" service as the escape (the second
     authorization system canon 35 forbids); **Drive/OneDrive/SharePoint** — collaboration products
     whose per-tenant OAuth, shared quota *pool* and 250 MB Graph PUT cap fight multi-tenant
     isolation, and all need an external credential. Cost did not decide it. Delivered: a **private**
     bucket with store-enforced MIME and size limits, read + insert policies keyed on document
     visibility plus a tenant-prefix defence, and deliberately **no update/delete policy** (documents
     are versioned; overwriting would defeat the audit trail). **PP-2 closed** — `document_links`
     gained the `subscription_payment_proof_id` branch it always needed; all nine branches
     transcribed verbatim and pinned by a structural assertion (§17).
     **Two defects found by a FAILING assertion in this package's own test — SPP-1/SPP-2:**
     `subscription_payment_proofs` gated **neither** reads nor inserts while its parent
     `subscriptions` gated both, so any tenant user could read the agency's whole payment history and
     **forge a pending proof by direct DML**. Fixed to parity (read → `VIEW_SUBSCRIPTION_STATUS`;
     insert → `MANAGE_TENANT_SETTINGS`, deliberately not `MANAGE_SUBSCRIPTION`, which no role holds).
     **This is the third occurrence of the sibling-table class and my own WP-04-B missed it** — that
     package touched this table without comparing its RLS to its parent. Guards:
     `48_document_storage_test.sql`, `47_payment_proof_lifecycle_test.sql`.
   * **WP-04-D — CLOSED 2026-08-27 (`202607054900`, `202607055000`, `202607055100`, `202607055200`).**
     Delivered on a fact read live before any design: **the database cannot delete a storage object.**
     `storage.protect_delete()` is a Supabase-installed BEFORE DELETE trigger on `storage.objects` and
     `storage.buckets` that raises 42501 unless `storage.allow_delete_query` is set, and `pg_net` is
     not installed on either environment — so the database can neither destroy bytes nor call the
     Storage API. Setting that GUC in a DEFINER function was rejected twice over: it works around a
     control the platform installed deliberately, and it would delete only the row while the S3 object
     survived unnameable — manufacturing the very orphan this package detects. **The architecture is
     therefore a split: the database owns the DECISION, an external executor owns the BYTES.** Built:
     `app.document_retention_days()` (NULL = undecided = retain forever, so "delete immediately" is
     unreachable *by default* rather than by validation); `public.document_storage_findings` (one
     table, deny-all, `service_role` only); `app.reconcile_document_storage()` (per-tenant,
     skip-never-raise, idempotent by unique index, re-detection reopens, cross-tenant safety
     structural via the path prefix); `app.platform_resolve_storage_finding()` (the executor's only
     way back, and the one path in ORVION that deletes a `document_versions` row, only on a confirmed
     byte deletion and only after re-checking eligibility); daily cron. Guarded by
     `49_document_retention_test.sql` (25). **Blocked and recorded, not guessed:** RET-1 (retention
     period), RET-2 (a departed tenant's data), DEL-1 (the byte executor).
   * **Also closed by WP-04-D's post-package sweep:** **POL-1** (four policies scoped `to public`
     rather than `to authenticated` — all four mine, all from one omitted clause;
     `50_policy_role_scope_test.sql`), **RBAC-1** (ORVION audited privilege grants made through one
     RPC and nothing else — `user_role_assignments` had *no triggers at all*, so revocation was never
     recorded, direct-DML grants were unaudited, and the destructive path cost no MFA while the safe
     one did; fixed on the table, one trigger, single producer;
     `51_role_change_audit_test.sql`), **CUR-1** (`integration_cursors` grants contradicted its own
     RLS). **EVT-2** registered: 42 event types remain producerless, now pinned by a `<= 42` ceiling
     in `07_event_vocabulary_registry_test.sql` so the debt can only shrink.
   * **WP-04-E — CLOSED 2026-08-27 (`202607055300`, `202607055400`, Edge Function `storage-executor`).**
     The byte half of WP-04-D's split now exists. **Chosen on one property, as WP-04-C was: the number
     of new secrets.** The Supabase Edge runtime injects `SUPABASE_SERVICE_ROLE_KEY` itself, so the
     credential is never created, pasted, stored or passed through an agent — zero new secrets. n8n
     would require the owner to create a service_role credential by hand (AGENTS.md §6) that must
     then live somewhere forever; a direct Postgres connection would require the database password.
     The executor **decides nothing** — `app.claim_storage_actions` answers every eligibility question
     (retention configured, version still superseded, `current_version_id` agreement, tenant not
     restricted) before it sees a row, so no second authorization system exists outside the database.
     **No lease, deliberately**: it marks nothing in flight, so a crash leaves the finding untouched
     and the next run retries; adding PH8-1's lease would introduce the stranding state that lease
     exists to escape. Authentication verified live on Primary: no header → 401 from the gateway, a
     valid **anon** JWT → 403 from the function's own service-key check (the platform's default
     `verify_jwt` alone would have admitted any visitor to a function that destroys documents).
     **STORAGE IS NOW PROVEN END TO END** — `scripts/verify_storage_end_to_end.ps1`, 36 assertions with
     real bytes over real HTTP: upload, cross-tenant and unauthenticated denial, signed URLs,
     supersession, reconciliation against a populated bucket, retention, byte destruction, audit
     survival, idempotency. Also closed **FND-1** (a failed storage action was permanently hidden —
     PH8-1's shape, and mine from the previous day) and **GRANT-1**.
   * **API-1 — CLOSED 2026-08-28 (`202607055500`).** ORVION stops being unreachable. Executed as a
     CAPABILITY AUDIT, not a wrapper factory: 137 `app` functions minus 20 triggers, 7 RLS helpers,
     4 view helpers, 6 platform-only and 14 system/batch left 86 granted to `authenticated`, of which
     **15 are internal helpers deliberately excluded** — `record_event` above all, the audit spine's
     sole writer, which "expose the `app` schema" would have published as an endpoint (audit forgery
     through the front door). **71 capabilities + 8 reporting views** exposed; every wrapper
     `security invoker` so it adds reachability and precisely zero authority; named-argument
     delegation so an `app` signature change fails at migration time; all VOLATILE for one uniform
     POST convention. Deployed by generating identical DDL on Primary and then PROVING equality
     rather than assuming it — surface hash `731cbd41ce480d714802b3de9a255c7a` on both, 81 objects.
     Verified on Primary over HTTP with correct arguments: endpoints 401, internal helpers and
     `platform_*` 404 PGRST202. Guarded by `53_api_surface_test.sql`, which pins the exposed set BY
     NAME. **Deployment criteria gained a permanent step:** any migration touching a `public`
     function or view must be followed by `notify pgrst, 'reload schema'`.
   * **PHASE B FIRST PASS — CLOSED 2026-08-28.** `scripts/verify_api_end_to_end.ps1` (29 assertions)
     walks the real revenue lifecycle as real JWT-bearing users: customer → lead → assignment →
     interaction → quotation → pricing → send → booking → booking item → passenger → document →
     invoice → payment → receipt → personal performance. Gross 6000 → commission 600 → company
     profit 5400, read from the employee's own report endpoint. Cross-tenant isolation proven against
     a fully privileged owner of another agency. Found LEAD-2 (no `walk_in` lead source) and
     confirmed that an employee's inability to assign leads is correct design, not a gap.
   * **PHASE C FIRST PASS — CLOSED 2026-08-28 (`202607055600`).** Walked the journey branches an
     agency actually works, over HTTP as real users — 26 assertions covering tasks, conversations,
     document versioning, complaints, service requests, supplier payment, finance approvals, refunds,
     cancellation and cross-colleague financial privacy. Found and fixed **FIN-2** (an employee could
     not REQUEST finance approval: the guard treated writing `finance_approval_status_code='pending'`
     as APPROVING, so the workflow was dead for the only role that needs it) and **TASK-1** (an
     employee could create and complete a task but not START one). Fixing TASK-1 did not fix it,
     which exposed **TRANS-1**: transition permissions live in TWO sources -- the `advance_*` inline
     lists and `app.status_transitions`, which `enforce_status_transition` reads on both the RPC and
     direct-DML paths -- so editing one left a live drift. Both corrected; parity is now a permanent
     guard. Also confirmed a cancelled booking item pays no commission, and that an employee sees
     their own item's profit while a colleague in the same branch sees none of it.
   * **RLS-1 — NEW PACKAGE: read scope is write scope on eleven tables.** WHY IT EXISTS: `bookings`,
     `booking_items`, `leads`, `quotations`, `tasks`, `documents`, `document_links`, `complaints`,
     `conversations`, `customer_notes` and `service_requests` carry `for ALL` policies whose USING and
     WITH CHECK both include `app.has_tenant_wide_read()` = `has_permission('VIEW_ALL_BRANCHES')`, so
     a READ permission confers WRITE authority. DISCOVERY SOURCE: Phase C policy sweep.
     DEPENDENCIES: none. SCOPE: introduce `app.has_tenant_wide_write()` and use it in WITH CHECK, so
     the two concepts are separable; behaviour is identical today because only owner and ceo hold
     VIEW_ALL_BRANCHES and both hold every write permission. NON-GOALS: narrowing what owner/ceo can
     write; splitting the policies into per-command sets. ACCEPTANCE: no `WITH CHECK` expression
     references a read predicate. SECURITY CRITERIA: a role holding only VIEW_ALL_BRANCHES must gain
     no write. TEST CRITERIA: a read-only fixture role proves the denial, with owner as the positive
     control. CROSS-PATH: direct DML and RPC both re-verified on all eleven tables. DEPLOYMENT:
     migration to Primary, parity re-proven. REPORTING: the eleven policies listed with before/after.
   * **PHASE C ROLE JOURNEYS — CLOSED 2026-08-28 (`202607055700`, `202607055800`).** The first
     role-by-role walk ORVION has had: senior employee, branch manager, department manager, finance
     manager, CEO, owner and platform owner, each with a positive control proving it can do its job
     and negatives proving it cannot do someone else's. 27 HTTP assertions. Found **RBAC-4** -- a
     department manager saw ZERO bookings in the department they manage while every employee under
     them saw them all, because `VIEW_DEPARTMENT_RECORDS` (canon 28's department-read gate for
     bookings, booking items and quotations) was granted to employee and senior_employee and not to
     the manager. Fixed and guarded as a CLASS: a manager may never hold fewer department read gates
     than their staff, and must still hold no branch-wide read. Closed **TASK-2** on canon evidence:
     canon 26 lists five task events and no start event, and `app.assign_task` already owns
     `task_assigned`, so the start transition now emits nothing rather than inflating assignment
     counts with a falsehood. **TRANS-1 investigated and deliberately left guarded** -- the
     de-duplication needs an event column on `app.status_transitions` and rewriting nine functions,
     a larger risk than the guarded duplication.
   * **SEC-1 — REPRODUCED 2026-08-28, and now the largest open item. OWNER DECISION.** WHY IT EXISTS:
     RLS scopes which rows a caller reaches; it does not enforce what they may do. Capability lives
     in the `app.*` RPCs, which direct DML bypasses, and in a partial set of guard triggers covering
     only archive, status transitions and financial columns. DISCOVERY SOURCE: Phase C -- a role
     holding only `VIEW_ALL_BRANCHES` and `VIEW_ASSIGNED_LEADS` (CREATE_BOOKING false, CREATE_TASK
     false) renamed a booking, retitled a task and INSERTED a customer, all by direct DML.
     MEASURED: 59 tables accept a direct INSERT from `authenticated`; 19 have any permission trigger;
     **40 have none**. RLS-1 is merged in as its concrete instance. DEPENDENCIES: an owner decision
     between two architectures. SCOPE (whichever is chosen): either revoke `authenticated`'s table
     writes and make the RPCs the only door -- which requires converting them to SECURITY DEFINER,
     a change to the whole authorization model -- or enforce canon 28's matrix on every table with a
     capability trigger. NON-GOALS: choosing between them without the owner; inventing which
     permission governs creation for tables canon does not name. ACCEPTANCE: the unguarded count
     reaches zero, or every remaining table is explicitly justified. SECURITY CRITERIA: a role with
     read permissions only must write nothing anywhere. TEST CRITERIA: the reproduction above becomes
     a failing-then-passing test; the ceilings in `10_grant_model_test.sql` drop to 0. CROSS-PATH:
     RPC, direct DML, batch and system paths re-verified per table. DEPLOYMENT: migration to Primary,
     parity re-proven. REPORTING: the per-table capability map as the client contract.
     **Until it is decided, the exposure is capped by assertion so it cannot grow.**
   * **FIN-3 / FIN-4 — CLOSED 2026-08-28 (`202607055900`).** The SEC-1 inventory revealed that every
     money table's policy named `VIEW_FINANCIAL_DOCUMENTS` -- a READ permission -- OR'd with a plain
     visibility test, so the effective rule was "you may write money about anything you can see".
     REPRODUCED: an employee with no `RECORD_PAYMENT` inserted a 999,999 EGP payment by direct DML.
     `journal_entries` had required `CREATE_JOURNAL_ENTRY` all along -- the ledger was guarded and the
     cash was not. Six tables (payments, payment_allocations, receipts, refunds, invoices,
     quotation_items) now charge EXACTLY the permission their own RPC charges, read out of the
     functions rather than chosen. FIN-4: `approval_requests.requested_by` is derived from the
     caller, so a request cannot be opened in a colleague's name. SEC-1's unguarded ceiling FELL from
     40 to 36. Guarded by `56_financial_write_capability_test.sql` (12).
   * **SEC-1 INVENTORY — COMPLETE 2026-08-28, decision still owed.** The systematic classification the
     directive required: 36 `SECURITY DEFINER` vs 81 `SECURITY INVOKER` app functions, of which **56
     write tables directly** -- so Option A (revoke `authenticated` writes) means converting 56
     functions to DEFINER, a change to the whole authorization model, not a configuration tweak.
     `authenticated` holds INSERT/UPDATE on 59 tables and DELETE on none. Enforcement: 19 by
     capability trigger, 30 by a policy `WITH CHECK` naming a permission, 36 by either, **23 by
     neither** -- correcting the previously reported 40, which counted triggers only. And "names a
     permission" proved not to mean "requires the right one": the money tables named a READ
     permission (FIN-3). The remaining non-money unguarded tables must each be classified against
     canon before either option is chosen.
   * **SEC-1 PARTIAL — CLOSED 2026-08-28 (`202607056000`).** FIN-3's rule generalised: for every table
     `authenticated` may INSERT with no capability enforcement, find every `app.*` function that
     inserts into it and the permission that function authorizes. ONE RPC/ONE PERMISSION -> guard it.
     TWO RPCs/TWO PERMISSIONS -> guard the UNION, which is exactly what the code already permits.
     NO RPC, or an RPC that authorizes nothing -> no evidence-based answer, left to SEC-1 rather than
     guessed. Nine tables guarded: approval_requests, conversation_messages,
     customer_contact_methods, customer_identity_signals, customer_identity_merges,
     internal_supplier_links, offline_conversions, document_links (union), lead_assignments (union).
     `approval_requests` is INSERT-only -- `review_finance_approval` updates it and `finance_manager`
     does NOT hold `CREATE_BOOKING_ITEM`, so charging it on UPDATE would have broken FIN-2's
     workflow; verified before writing. SEC-1's residue: 40 (mis-measured, triggers only) -> 23 ->
     **13**, now classified individually rather than counted -- 3 auth artifacts already owner-scoped
     by policy, 5 system-written, 5 whose RPCs authorize nothing. Guarded by
     `57_write_capability_map_test.sql` (12).
   * **SEC-1 RESIDUE — CLOSED 2026-08-28 (`202607056100`), one table left.** Counting the thirteen
     implied they shared an answer. They did not, and the three groups needed opposite actions.
     **Five are system-owned** (`attribution_clicks`, `notifications`, `notification_deliveries`,
     `offline_conversion_deliveries`, `usage_counters`): every writer is SECURITY DEFINER and none is
     executable by `authenticated` (`orvion_integration` / `service_role`), and two have no writer at
     all -- so the table grant was a second door only direct DML used. REVOKED rather than
     permissioned, which is the directive's own preference. `notifications` keeps a column-level
     `update (is_read, read_at)`: dismissing your own notification is a real user act with no RPC, and
     removing the whole UPDATE would have deleted a capability instead of closing a hole.
     **Four are tenant configuration** (`branch_business_hours`, `holidays`, `financial_accounts`,
     `company_assets`) with no writer at all, so direct DML was the only path and it was open to a
     trainee. Guarded with the permission ORVION already charges for the same object: `branches` ->
     MANAGE_BRANCHES; `chart_of_accounts` / `journal_entries` -> CREATE_JOURNAL_ENTRY; `holidays`
     takes the MANAGE_BRANCHES-or-MANAGE_TENANT_SETTINGS union because `branch_id` is nullable and
     both resolve to {ceo, owner}. **Three are INTENTIONAL, not residue**: canon 34 states that
     `otp_challenges`, `totp_enrollments` and `trusted_devices` belong to the Human Identity and that
     row-ownership by `auth.uid()` IS their model -- now proven behaviourally rather than trusted.
     Left open: **`lead_interactions` only**, where `record_lead_interaction` (SECURITY INVOKER,
     granted to authenticated) authorizes nothing, so there is no bypass to close -- only an
     undecided question about what logging an interaction costs. Ceilings 59/27/13 -> **54/18/4**.
     Guarded by `58_write_grants_and_config_capability_test.sql` (27).
   * **LIFECYCLE BRANCHES + THE TRAINEE — CLOSED 2026-08-28** (`scripts/verify_lifecycle_branches.ps1`,
     57 HTTP assertions; no migration). Every journey the last two reports listed as UNPROVEN is now
     executed over real HTTP: the trainee's full first morning; quotation rejected / revised /
     expired and both revival paths; booking approved -> issued -> reissue -> issued with the
     authority split proven at each step; deposit-then-balance payment allocated exactly; the
     supplier-failure chain (service request parked on `awaiting_supplier`, line cancelled, refund
     completed, commission gone); document expiry as a real window; and the returning customer with
     both trips on one 360 timeline. HTTP coverage 118 -> **175** across five scripts.
     Found: **DOC-EXP-1** — `expiring_documents` works, but the `document_expiry` notification type
     has no producer, so an expiring passport tells nobody. Pinned as an assertion, recorded as a
     business decision (who, how far ahead, how often). Also pinned: over-payment is REFUSED, and
     `upload_document` refuses a passport linked to anything but a passenger.
     One error of mine worth keeping: the script's tenant slug collided with
     `32_lifecycle_transition_test`. pgTAP files roll back so tests never collide with each other;
     the HTTP scripts do not, so a script slug must be unique against every TEST slug too. It
     surfaced only in the order-independent regime introduced one package earlier. All five scripts
     were then checked against all 58 test files: no other collision exists.
   * **TRANS-2 + SEC-1's LAST TABLE — CLOSED 2026-08-28 (`202607056200`).** Begins with a
     CORRECTION: `202607056100` recorded that `app.record_lead_interaction` "authorizes nothing" and
     left `lead_interactions` open. It does authorize -- "the assigned handler, OR ASSIGN_LEAD, plus
     MFA", inline with `app.has_permission` and an explicit raise. The error was in my detector,
     which searched for `app.authorize('PERM')` and so could not see an assignment-shaped rule.
     Chasing the rule into `app.status_transitions` found the larger half: eight `leads` rows carry
     a NULL `permission_key`, and the trigger applied a permission only `if not null` -- so direct
     DML could walk a COLLEAGUE'S lead from `contacted` to `won` and on to `converted` with no check
     at all, while every RPC refused anyone but the handler. Reachable, because canon 28 gives
     `employee` VIEW_DEPARTMENT_QUEUE. Fixed by `app.require_lead_handler`, called from the
     transition trigger where the permission is null and from a new guard on `lead_interactions`;
     nothing became stricter than the RPC that walks it. AND THE CLASS: a null permission_key now
     means "apply this table's named fallback", and a table with neither FAILS CLOSED.
     TRANS-1 investigated per the directive: no live disagreement (all ten functions vs all 104
     rows), and an `event` column is NOT proven to be the right home -- the inline lists carry
     is_closure, sub-status and sometimes a constant permission, so unifying needs a decision on
     where per-entity extras live. It stays open, narrowed. But its guard was broken:
     `54_transition_permission_parity_test` was checking ONE function out of ten because its regex
     matched only advance_booking's tuple shape. Rewritten to parse every function's VALUES block,
     to fail if any stops parsing, and to check the reverse direction -- which is exactly where
     TRANS-2 was hiding. Ceilings 54/18/4 -> **54/17/3**, and the three that remain are the canon-34
     Human Identity tables: **SEC-1 has no unexplained residue left.** The detector in `10` was
     widened for the same reason the defect existed.
   * **SCHED-1 — INVESTIGATED, PARTIALLY ADDRESSED 2026-08-28 (`202607056300`).** Three of the four
     recurring jobs are already scheduled; the storage executor is the fourth and has no scheduler.
     Three routes exist and all three need ONE owner-placed secret: pg_cron+pg_net+Vault (pg_cron
     installed, pg_net available but not installed, **supabase_vault IS installed** -- which improves
     the position from when pg_net was first declined, though installing it still gives the DATABASE
     outbound HTTP); n8n schedule -> HTTP (keeps HTTP out of the DB, adds an uptime dependency on a
     core retention path); or a scheduled GitHub Action (couples the data plane to CI). Choosing is a
     security trade-off, so it stays BLOCKED -- EXTERNAL DEPENDENCY + ARCHITECTURAL DECISION and
     pg_net was NOT installed to make a metric move. What needed no decision: the gap was SILENT.
     `app.storage_action_backlog()` reports pending actions, THE AGE OF THE OLDEST, already-failed
     attempts, last attempt time and unresolved findings, service_role only. It calls
     `app.claim_storage_actions` rather than restating its rules, and `60_...` (11) asserts the
     monitor's count EQUALS what the executor would claim -- including under the RET-2 suspension
     exclusion, where a hand-written monitor would most easily have drifted. HTTP 175 -> **179**.
   * **ATTR-1 — CLOSED 2026-08-28 (`202607056400`).** Found by sweeping the CLASS rather than
     tripping over an instance: every table `authenticated` may INSERT was checked for columns
     naming an actor. `archived_by`, `document_versions.uploaded_by` and
     `approval_requests.requested_by` are already derived -- `created_by` was NOT, on twenty tables.
     Every RPC sets it from the session; direct DML did not have to, so any tenant user could create
     a customer, booking, invoice or payment ATTRIBUTED TO A COLLEAGUE. On `documents` that is worse
     than misleading: `scope_isolation` reads `created_by = current_user_id()` as a VISIBILITY GRANT.
     `app.derive_created_by()` applies FIN-4's ratified shape -- DERIVE, DO NOT VALIDATE -- on INSERT
     and holds it IMMUTABLE on UPDATE, which is safe because no function anywhere updates the column
     (verified against every body first). Session-less platform paths keep their own attribution.
     `61_...` (8) pins the class: every insertable table with the column must carry the trigger.
     Recorded, not swept in: **ATTR-2**, the ACTION attributions (`voided_by`, `reviewed_by`), which
     are stamped at the moment of the action and need a different trigger shape.
     Also widened here: `10`'s PUBLIC-EXECUTE guard covered the `app` schema ONLY, leaving `public`
     -- where API-1 put the 74 endpoints and where `pg_default_acl` grants EXECUTE by default
     (SPEC-124's class) -- unchecked. It now covers both, excluding extension-owned functions by
     `pg_depend` rather than by name. Same shape of mistake as the transition guard that covered one
     function out of ten, found by the same sweep.
   * **ATTR-2 — CLOSED 2026-08-28 (`202607056500`), 2 of 5, and the other three were not what the
     name suggested.** Reading the five columns individually rather than as a group split them three
     ways. DERIVED: `subscription_payment_proofs.uploaded_by` (an INSERT-time attribution that ATTR-1
     missed only because the column is not called `created_by`) and `approval_requests.reviewed_by`
     (derived on UPDATE WHEN IT CHANGES, so an unrelated edit to a decided request does not
     re-attribute the decision to whoever touched it last -- assertion 6 is what justifies that
     condition). NOT an attribution defect: `invoices.voided_by` / `journal_entries.voided_by`, where
     NOTHING writes the columns and `app.status_transitions` has no rows for either table -- voiding
     is unimplemented, recorded as **VOID-1**, and deriving an attribution for an action nobody can
     perform would dress a missing capability as a solved one. STRUCTURALLY UNFILLABLE:
     `subscription_payment_proofs.reviewed_by`, whose FK points at the TENANT membership table while
     the reviewer is the PLATFORM -- recorded as **SPP-3**.
   * **SEC-2 — RESOLVED 2026-08-29, and it was never one question.** Searching the evidence split it
     in two. DESCRIPTIVE fields: INTENTIONAL, derived from three independent facts — the permission
     catalog holds only SPECIFIC mutation permissions (`EDIT_LOCKED_COST`, `UPDATE_BOOKING_ITEM_STATUS`)
     and no generic `EDIT_<entity>`; not one `app` function updates a descriptive field; canon 28
     names none. There is no `update_customer` anywhere, so the table endpoint is not a bypass of an
     intended door -- it IS the door, and RLS scope is the control ORVION chose. CONSEQUENCE-BEARING
     fields with no guard: DEFECTS, and searching for them found **FIN-6**.
   * **FIN-6 — CLOSED 2026-08-29 (`202607057100`).** An employee holding CREATE_INVOICE = f and
     RECORD_PAYMENT = f marked a 50,000 EGP invoice PAID with no payment; changing its AMOUNT was
     refused in the same transaction, which is what made it conclusive. `guard_financial_capability`
     charged capability on UPDATE only for MONETARY columns -- right for refunds and quotations,
     whose status is governed by canon machines, wrong for invoices, where canon defines no machine
     and `app.status_transitions` has no rows. Status and tax-submission columns now cost the
     permission the table already charges; finance proven still able to advance an invoice.
     **FIN-6b** found alongside: the guard mapped `receipts` to a column that does not exist, so its
     UPDATE branch had been inert since FIN-3 -- the price of the `to_jsonb` comparison that fixed
     SPEC-159-A. A class assertion now checks every mapped column against the catalog.
     **FIN-7** recorded: canon defines sixteen state machines and no INVOICE one, so WHICH status
     changes are legal remains undecided. **DOC-LC-1** recorded: canon's Document Lifecycle machine
     was never wired into `status_transitions`; derivable, next package.
   * **API-3 — first instalment paid down (33 → 30).** The lead state machine now has an HTTP walk
     in `verify_lifecycle_branches.ps1` (57 → 72 assertions): create, assign, contact, qualify,
     quote, negotiate, win, convert -- plus the discovery that `assigned -> contacted` is owned by
     `record_lead_interaction` and not `advance_lead` (TRANS-1's documented split; the first draft
     assumed otherwise and was refused), **TRANS-2's handler rule proven over HTTP for the first
     time** (the employee can SEE a colleague's lead and cannot advance it), and ATTR-3's acquisition
     source proven to survive the whole machine.
   * **API-3 CLOSED — TASK-1 / TASK-2 / SUP-1, 2026-08-30 (`202607058600`).**
     The final three endpoints (`assign_task`, `financial_documents`, `link_internal_supplier`) now
     carry HTTP execution evidence: **71 of 71**. **TASK-1 (High):** `app.assign_task` charges
     ASSIGN_TASK (managers only) while `public.tasks` charged CREATE_TASK, which `employee` also
     holds — genuinely different role sets, unlike ASSIGN_LEAD/REASSIGN_LEAD. Reproduced in one
     transaction: the RPC refused an employee, their direct UPDATE returned UPDATE 1, and
     `task_assigned` events numbered 0. Closed with a trigger firing ONLY on a change of owner,
     chosen over widening `guard_write_capability` because that guard cannot see which column moved
     and would have stopped an employee completing their own task. **TASK-2 (Medium):** a THIRD,
     narrower copy of "current placement" (`ends_at is null`) — a Cairo task handed to Giza staff
     with a scheduled transfer kept CAIRO. Fixed with PLACE-1's strictly-additive shape.
     **SUP-1 (Low):** provider pair, derived requester and item lifecycle were all absent from the
     supplier-link table; all three reproduced. Severity is Low because `internal_supplier_links`
     has **no consumer** — measured, not assumed — so corrupt rows misstate history and change no
     behaviour today.
     **financial_documents produced EVIDENCE, not a fix:** the confidentiality boundary IS enforced
     (a confidential invoice is invisible to an employee through the table) but a NON-confidential
     one is readable there while the endpoint refuses them. That breadth is **SPEC-154-B**, which
     canon 28 frames on both sides at once, so it was pinned by assertion rather than decided.
     Test 81 (20); HTTP 349 → 360; **API-3 6 → 3 → 0.** `202607058600` verified but **NOT
     deployed**; Primary stays at 169, now six migrations behind by intent.
   * **SPEC-154-B — decided by the owner and implemented, 2026-08-31 (`202607058700`).** The pin left
     by the session above became a rule. Reproduced first with a control that made responsibility the
     ONLY variable: two `employee`s in the same branch, department, role and permission set, one
     owning the booking and one not, read the manager-uploaded invoice document identically — the
     read arriving through the *department* axis, because a visible LINK was the whole test the
     policy applied. Owner adopted **Option C**; the scope is a predicate, not a grant (**ADR-0026**).
     `quotation` left `app.is_financial_document_type` on canon evidence, and the measured cost — a
     `finance_manager` without VIEW_TRAVEL_DOCUMENTS no longer sees quotation *documents* — is
     asserted rather than left to be discovered. Also **TEST-3**, found in test 80 from the session
     above: a pgTAP mutation assertion placed last is never counted, because `rollback to savepoint`
     undoes the temp-table counter — the harness printed `planned 18 but ran 17` and the suite's PASS
     hid it. Both files now re-assert after the rollback, which is also PAR-4's missing closing move.
     Test 82 (21); HTTP 360 → 366. **ADR-0024/0025/0026 ratified**, the ADR record shape extended,
     and the undefined `LESSON 4`/`LESSON 6` ordinals resolved. `202607058700` verified but **NOT
     deployed**; Primary stays at 169, now seven migrations behind by intent.
   * **LIC-2 / LIC-3 / PP-4 — API-3 SUBSCRIPTION-LICENSING FAMILY, 2026-08-30**
     (`202607058400`, `202607058500`). **LIC-2 (High):** the single-use activation code could be
     redeemed TWICE, concurrently. `redeem_license_token` checked `consumed_at is null` and then
     updated `where id = ...` -- check-then-act with no guard on the act, so under READ COMMITTED the
     second redeemer's UPDATE re-evaluates only the id and still matches. **The repository states the
     opposite twice** -- the function comment and test 43 assertion 11 both say replay is closed --
     and both are true only in sequence (LESSON 4). Reproduced with TWO LIVE psql sessions:
     `security_events` recorded **2** redemptions of one token and the subscription activated twice,
     while the row said consumed once. Closed with a compare-and-swap raising the same generic
     message, and the FUNCTION is the complete layer here -- measured, not assumed: `authenticated`
     holds no grant on `tenant_license_activations` and its RLS is `platform_only`, so unlike
     BOOK-1/ASGN-1/CM-2 there is no second door. The identical experiment after the fix produced one
     redemption. **LIC-3 (High):** `UPLOAD_DOCUMENT` and `CREATE_DOCUMENT_VERSION` both carry
     `required_feature_code = documents`, which `starter` disables -- so the entry-level tenant could
     not file the payment proof canon 09/28 call *the only way back from read_only*. WP-04-B narrowed
     the SUBSCRIPTION gate for exactly this case; the PLAN gate was never considered. Proven by a
     discriminating experiment: two tenants identical but for the plan, same role, same claim --
     professional succeeds, starter is refused. **PP-4 (Medium):** an employee could plant a
     confidential `payment_proof` document by direct DML (SPP-2 one table over). Both closed by
     charging `MANAGE_TENANT_SETTINGS` for payment-proof documents -- the permission the RPC already
     charges, and the only one not gated on the entitlement the tenant is trying to restore:
     **paying for your plan cannot itself be a plan feature.** The `starter` entitlement was
     deliberately NOT changed -- plan contents are a commercial decision belonging to the owner.
     **CAP-1 recorded, not reproducible:** `tenant_capabilities` is the only one of eight subscription
     readers without "latest row wins", but `provision_tenant` is the sole inserter and no role holds
     MANAGE_SUBSCRIPTION, so a second row is unreachable. **Two fixture corrections:** test 35 used an
     `employee` for a block whose subject is the subscription gate (PP-4 correctly refused it), and my
     first draft of the guard named a record field inside a CASE shared by 21 tables -- the suite
     caught both. Test 80 (18); HTTP 339 -> 349; **API-3 6 -> 3.** Both migrations verified,
     **NOT deployed**; Primary stays at 169, now five migrations behind by intent.
   * **PLACE-1 / CM-1 / CM-2 — API-3 CUSTOMER-DATA FAMILY, 2026-08-30 (`202607058300`).**
     Every defect here was resolved against a rule the repository had ALREADY written down, which
     is why none of them needed an owner decision. **PLACE-1 (High):** `app.current_placement()`
     matched `ends_at is null` only, so an employee with a SCHEDULED transfer — canon 03 provides
     for exactly that — returned NOTHING. Its **five** consumers (`create_customer`,
     `create_quotation`, `create_complaint`, `create_service_request`, `start_conversation`) all
     read it with `SELECT ... INTO`, so empty is not an error but a silent NULL. Reproduced end to
     end: an owner set `ends_at = now() + 30 days` through the door RLS already permits, the
     function returned 0 rows, and the next customer was stored with `first_registered_branch_id`
     NULL — re-creating what `create_customer`'s own comment says it had fixed. The repository
     already held the better answer: `eligible_lead_handlers` (LEAD-3) tests the full window. The
     fix is **strictly additive** — ordering prefers the open-ended row, so every answer the old
     predicate gave is unchanged and only the empty case is filled. **CM-2 (High):**
     `202607052100` claimed its unique index made the duplicate check hold "on the direct path";
     it does not, because that index covers the RAW value. Reproduced: the RPC stored
     `mona@example.com` and a direct INSERT of `'  MONA@example.com  '` succeeded, while the
     identical value was REFUSED on `customers.primary_email`. The CHECK reuses
     `normalize_email`/`normalize_phone` (verified IMMUTABLE) rather than restating them.
     **CM-1 (Medium):** the RPC demoted "primary" across ALL channels while the index encodes one
     per channel — adding a primary email silently unset the primary phone.
     **PLACE-2 recorded UNPROVEN:** `current_placement` still omits a `starts_at` test, diverging
     from `eligible_lead_handlers`; no harm was reproduced and adding it would change behaviour in
     an unproven case, which is why the fix stayed additive.
     Test 79 (19); HTTP 328 → 339; **API-3 9 → 6.** `202607058300` is verified but **NOT
     deployed**; Primary stays at 169, now three migrations behind by intent.
   * **CONV-4 / CONV-5 / CAMP-1 — API-3 MARKETING-CAMPAIGN FAMILY, 2026-08-30 (`202607058200`).**
     The family Phase 8's offline-conversion pipeline consumes, and the reason its defects matter
     more than their row count: `app.claim_conversion_deliveries` returns `conversion_value` and
     `currency_code` **verbatim** into the payload n8n hands to the Google Data Manager API, and
     filters only on platform, delivery status and attempt count — so a value that should never
     have existed is not caught downstream, it is DELIVERED. **CONV-4 (High):** the RPC refuses a
     negative value; nothing else did. Reproduced as an `owner` with `aal2` over the real
     `authenticated` role, in the same transaction the RPC had just refused — a direct INSERT
     stored **-5000.0000 EGP**. **CONV-5 (High):** an amount with NO currency, same door,
     **7777.0000 / NULL**. **CAMP-1 (Medium):** a campaign INSERTed with no status was permanently
     unadvanceable while `advance_marketing_campaign` reported "campaign not found in your tenant"
     about a row that existed. All three closed with **row-level constraints rather than triggers**
     — each is decidable from the single row, and a constraint cannot be reached around by any door
     or session-less path. **Every legal writer proven compatible BEFORE the constraint was
     written:** `payments_amount_nonneg_check` and a NOT NULL currency make the session-less
     `map_outcomes_to_conversions` structurally incapable of violating either money rule.
     **H-M4 was investigated and is NOT a defect** — `app.enforce_status_transition` already
     refuses an illegal campaign transition on the table door, so nothing was changed there.
     **CAMP-2 recorded UNPROVEN:** INSERT does not constrain which state a row opens in, but no
     harm was reproduced and the question spans every status-bearing table, not this family.
     `64_acquisition_lineage_test`'s positive control was corrected (TEST-64): it set an amount
     with no currency — a row the RPC has always refused — and passed only because nothing
     enforced the pair. Test 78 (19); HTTP 315 → 328; **API-3 12 → 9.** `202607058200` is verified
     but **NOT deployed**; Primary stays at 169, now two migrations behind by intent.
     Next: the customer-data group (`add_customer_contact_method`, `find_customer_duplicates`,
     `current_placement`).
   * **LEAD-6 / ASGN-1/2/3 — API-3 LEAD-ROUTING FAMILY, 2026-08-30 (`202607058100`).**
     Two of the four endpoints had no coverage but a NAME: `assign_lead_round_robin` and
     `lead_booking_readiness` appeared only in `53_api_surface_test`'s inventory, the CUST-2 shape,
     and all four had zero HTTP evidence. **LEAD-6 (High):** canon 04 routes round-robin "among
     ELIGIBLE employees", and LEAD-3 had already resolved "eligible" from the permission matrix
     (`CLOSE_LEAD`) — but applied it to `process_lead_sla` and nothing else. Round-robin still
     selected on PLACEMENT, the definition LEAD-3 rejected in writing. Reproduced: the pool
     returned ONE eligible candidate, round-robin's predicate returned TWO, and it chose the
     **trainee** — then refused `permission denied: CLOSE_LEAD` on the lead they owned. Fixed by
     CALLING the DEFINER authority, not inlining it: `user_role_assignments` carries `scope_read`
     RLS, so the join inside an INVOKER function would be row-filtered and silently wrong. The
     EXECUTE grant it needed ships with a tenant guard, because a DEFINER function taking
     `p_tenant_id` would otherwise be a cross-tenant staff-enumeration oracle. **ASGN-1 (High):**
     two current assignments for one lead by direct DML — closed with a partial unique index after
     verifying all three legal writers compatible first. **ASGN-2 (High):** `assigned_by` was
     caller-supplied, recording a manager's act as a subordinate's — ATTR-1's class in a column
     its twenty tables never reached. **ASGN-3:** a lead legally advanced to `lost` was refused by
     the RPC and accepted by the table door in the same transaction.
     Both new guards mutation-tested; **two existing guards caught regressions in this package's
     own drafts** — `10_grant_model_test` on a function inheriting EXECUTE TO PUBLIC, and **Pass B**
     on a slug collision with a committed HTTP fixture (TEST-2 class, Pass A green / Pass B dead).
     **No owner decision created.** Test 77 (22); HTTP 298 → 315; **API-3 16 → 12.** `202607058100`
     is verified but **NOT deployed** — Primary stays at 169 pending owner approval.
     Next: the marketing-campaign family, which Phase 8's pipeline consumes.
   * **ADMIN-1 — API-3 TENANT-ADMINISTRATION FAMILY, 2026-08-30 (`202607058000`).**
     The group that CREATES the unlinked memberships IDENT-1 exploited and GRANTS the roles it
     inherited. **ADMIN-1 (High):** `create_tenant_user` accepted `p_auth_user_id` from the caller
     and validated it against NOTHING — the FK proves an identity exists, not whose it is. Canon 34
     settles the rule: the Human Identity owns the verified email, the membership owns only what the
     person may DO. Reproduced — Agency A’s owner bound ‘Alice’ to BOB’S identity from Agency B:
     actions misattributed, the real Alice PERMANENTLY LOCKED OUT, and Bob’s `my_memberships()`
     returned both agencies. Fixed with a BEFORE I/U trigger on `users`, **layer chosen by
     measurement and deliberately unlike IDENT-1’s**: 120 linked rows carry ZERO divergent emails,
     and `users.scope_update` lets any MANAGE_USERS holder rebind by direct DML, so a function-only
     check was a half-fix. SECURITY DEFINER is mandatory because `authenticated` cannot read
     `auth.users` — under INVOKER the guard would allow every divergence.
     **Proven NOT defects, each by experiment rather than inspection:** zero-owner is unreachable
     (ADMIN-2 — `emit_role_change` is AFTER and re-checks MANAGE_USERS once the granting row is
     inactive; real but ACCIDENTAL, so test 76 pins it), 42 unproduced event codes are Fundamental
     Domain Structure (ADMIN-3), and `one_primary_idx`, the department-name index and the
     transfer/role events all work. **MEAS-1:** my own ‘no producer’ detector over-reported by 7
     because generic emitters carry the code in TRIGGER ARGUMENTS — caught by a contradiction with a
     test I had just run, and corrected before any finding was recorded. **TEST-65:** ten fixture
     rows modelled impossible humans; the static pre-check missed them and the suite caught them.
     **No owner decision was needed from this family** — every question was derivable from canon,
     schema or experiment. Test 76 (23); HTTP 282 → 298; **API-3 20 → 16.**
     Next: the lead-routing family (`assign_lead_round_robin`, `reassign_lead`, `lead_origin`,
     `lead_booking_readiness`) — the largest remaining coherent group, and the one carrying
     acquisition-attribution consequences.
   * **IDENT-1 / IDENT-4 — API-3 CANON-34 IDENTITY FAMILY, 2026-08-30 (`202607057800`, `202607057900`).**
     The family SEC-1 called INTENTIONAL because its tables are owned by `auth.uid()` rather than by
     a tenant permission. That classification was asserted STRUCTURALLY and never tested
     BEHAVIOURALLY: before this package the family’s entire coverage was a name-existence list in
     `53_api_surface_test.sql` — the CUST-2 shape, a guard that cannot see what an endpoint does.
     **IDENT-1 (Critical) was an account takeover.** `activate_membership()` claimed a
     pre-provisioned membership on an email STRING match, its own comment asserting that an
     `auth.users` row proves Supabase verified the address. `config.toml` sets
     `enable_confirmations = false`, and `email_confirmed_at` appeared NOWHERE in the repository.
     An attacker signing up as the CEO’s address claimed the membership and held APPROVE_FINANCE,
     VIEW_FINANCIAL_DOCUMENTS and MANAGE_USERS. **Fixed in the FUNCTION, not a trigger** — the
     alternate paths were measured closed first (direct UPDATE 0 rows, INSERT 42501), and 49 test
     files create `auth.users` without that column, so a trigger would break all 49 and would also
     impose confirmation on the ADMIN provisioning path. Banned and soft-deleted identities are
     refused in the same breath, because a JWT issued before a ban outlives it.
     **IDENT-4 (Medium), found by continuing after the first fix looked correct:** the claim matches
     case-INSENSITIVELY while `users_tenant_email_key` is case-SENSITIVE, so two case-variant rows
     in one tenant locked that human out permanently with a raw 23505. Fixed at the CONSTRAINT
     layer — a case-insensitive unique index — because the real fault was that two rows for one
     human existed at all; the failure now lands at provisioning time, where it is actionable.
     **IDENT-2 and IDENT-3 recorded, not invented into rules.** IDENT-2 (the claim emits no event)
     is blocked on the same side-effect question as FIN-9/FIN-11, with a specific obstacle:
     `record_event` validates the tenant against `current_tenant_id()`, which is `limit 1` with no
     ORDER BY, so a multi-tenant claim would audit one tenant arbitrarily. IDENT-3 records that
     `otp_challenges`/`totp_enrollments` have zero consumers (MFA runs off the JWT `aal2` claim), so
     they are Fundamental Domain Structure rather than dead code.
     Test **75** (24) is the family’s first behavioural test. HTTP 267 → 282. **API-3 25 → 20.**
     Next: the tenant-administration family (`create_tenant_user`, `assign_user_branch`,
     `revoke_user_role`, `create_department`) — the group that CREATES the unlinked memberships
     IDENT-1 exploited and GRANTS the roles it inherited.
   * **BOOK-1 — API-3 BOOKING/PASSENGER FAMILY, 2026-08-30 (`202607057700`).**
     **Begins with a correction:** the previous report named this family as the next of API-3's 25
     uncovered endpoints. It was wrong — all three ALREADY had HTTP evidence and none is among the
     25. The audit was run regardless, because a 200 is not evidence of a capability, and it found a
     High-severity money defect behind endpoints that had been "covered" for weeks.
     **BOOK-1:** both writer RPCs refuse to attach to a closed booking; nothing else did. Reproduced
     as an ordinary employee holding every permission the RPC charges — RPC refused, direct INSERT
     succeeded with **selling 5000 on a CANCELLED booking**, `commission_rate` 0.10 derived
     automatically, and **no event**, so unaudited too. The RLS `WITH CHECK` requires the PARENT TO
     BE VISIBLE rather than the actor permitted, and the financial guard checks scope against a
     caller-supplied column.
     Closed with BEFORE INSERT/UPDATE triggers carrying the RPCs' rules verbatim. Three decisions
     recorded as decisions: plain BEFORE rather than deferred (this invariant holds at every
     instant, unlike FIN-8/FIN-10); **no trigger on `bookings`**, because cancelling a booking that
     already has items is correct behaviour — deliberately asymmetric with FIN-10; SECURITY DEFINER
     plus a mandatory REVOKE, because under INVOKER the check would be RLS-blind to the parent.
     **NOT the aggregate-across-rows subclass** — SEC-1's clause-3 filter would not have found it.
     `10_grant_model_test.sql` caught the first draft leaving EXECUTE to PUBLIC. **BOOK-2** recorded
     and NOT fixed: the per-passenger overrides are read by nothing, so no invariant is derivable.
     **API-3 stays at 25.** Next by evidence: the canon-34 identity family (`my_trusted_devices`,
     `record_trusted_device`, `revoke_trusted_device`, `my_memberships`, `activate_membership`) —
     SEC-1 found those the ONLY writable tables with no governing trigger, classified INTENTIONAL,
     and that classification has never been tested over HTTP.
   * **PAR-3 / PAR-4 — VERIFICATION-METHODOLOGY REVIEW, 2026-08-30. No migration; the database did
     not change.** The owner asked that ORVION's METHODS of discovery, testing and measurement be
     reviewed adversarially rather than extended. Done by controlled mutation on local — never on
     Primary — rather than by reading the scripts.
     **PAR-3, the finding: the parity guard compared 233 objects out of 3,341.** It proved the
     migration ledger and the FUNCTION surface, and was blind to triggers, RLS policies, RLS
     *enablement*, grants, constraints, columns, views, indexes and the `app.status_transitions`
     rows — which is to say, blind to the deliverable of DOC-LC-1, FIN-8, FIN-10 and QUO-1, every
     one of which shipped a TRIGGER. Reproduced by dropping `payment_allocations_within_invoice_total`
     on a clean reset: repository guard CLEAN exit 0, parity guard **CLEAN exit 0**, API contract
     "matches the live surface", smoke ALL CHECKS PASSED — and only `72_*.sql` failed. **pgTAP runs
     against LOCAL only**, so nothing could have caught the same drift on Primary.
     Closed with **Check L4/P4** over ten surfaces, SQL in **`scripts/parity_surface.sql` which BOTH
     SIDES RUN** (PAR-1a: two hand-copied queries is how two databases agree while differing).
     `-PrimaryStructureHash` is required for CLEAN, per AUD-05's rule that unmeasured is not passed.
     **The fix was then attacked and found incomplete** — `DISABLE ROW LEVEL SECURITY` left the hash
     byte-identical, because `pg_policies` lists policies that cannot fire; RLS enablement added as a
     tenth surface, and `ordinal_position` added to columns because CUST-1 was positional.
     **PAR-4:** tests 70/72/73 now prove their own enforcer is load-bearing — drop the named trigger
     in a savepoint, the violation must SUCCEED, roll back, it must be REFUSED again. Suite 899 → 905.
     **VER-1** the contract's `http` column restated as a repository fact (audited first: no current
     false positive; comment lines now excluded). **VER-2 REJECTED on measurement** — a mechanical
     vacuous-test detector matched 31 sites across 15 of 73 files and its one tightened hit was a
     false positive, because what makes a test vacuous is whether the actor can SEE the rows it
     selects, which is not statically decidable. Also rejected: mutation tooling, property-based
     testing, a contract broker, a runtime coverage file, a second handoff document, and raising the
     manifest budget Check 5 tripped on this session's own additions.
     **Deferred with a trigger:** catalog-row parity beyond `status_transitions` (`role_permissions`
     is the authorization matrix) — not bundled here because it needs its own reproduction.
     **THE ROADMAP IS UNCHANGED. API-3 remains next, booking/passenger family.**
   * **SEC-1 EVALUATED 2026-08-29 — ACCEPT WITH REFINEMENT, awaiting owner ratification.** The
     owner's proposed model was tested against the live system, not judged by opinion, and it is
     **not a change of direction**: it is what ORVION has already converged on. Measured writable
     surface — 54 tables, of which 35 carry a capability trigger, 15 are permission-gated in RLS
     `WITH CHECK`, one is guarded by DOC-3's integrity trigger, and the residual three are the
     canon-34 Human Identity tables (INTENTIONAL). **Option A (revoke `authenticated` writes) is NOT
     recommended**: it needs 56 INVOKER functions converted to DEFINER, replacing RLS with 56
     hand-written tenant checks — the second authorization system canon 35 forbids.
     **Refinement 1:** clause 3 needs a decision procedure. "Has no business invariant" is not
     decidable by inspection — FIN-8, FIN-10 and QUO-1 all looked fine. The operational test that
     actually found them: *a rule comparing an AGGREGATE ACROSS ROWS cannot be a CHECK constraint,
     so it will live in exactly one function unless deliberately extracted.*
     **Refinement 2:** authorization guards exempt session-less platform paths (canon 35 principle
     6); **integrity constraints must not** — now pinned by assertion in three tests.
   * **FIN-10 + QUO-1 — CLOSED 2026-08-29 (`202607057500`, `202607057600`), the refinement applied.**
     FIN-10: `record_payment` refuses to over-allocate an invoice and takes an advisory lock doing
     it — nothing else did, so a `finance_manager` put **1300 against a 1000 invoice** by direct DML.
     Guarded on BOTH sides of the inequality, since the total can also shrink beneath the
     allocations. QUO-1: `quotations.total_amount` is DEFINED as the sum of its items and maintained
     on one path, so an employee left a quotation reading **1000 while its items summed to 6000** —
     the price offered to a customer. Recomputed rather than refused, because a derived value with
     no independent source can simply be kept right. **FIN-11** recorded (missing status/event side
     effect on the direct path — one answer wanted with FIN-9, not two bolted-on producers).
   * **GOV-7 — the consumer-impact rule, made durable 2026-08-29.** `AGENTS.md §3 5b` gains a SECOND
     question: *which code consumes, parses or derives from the structure this package changed?*
     Guarded narrowly rather than broadly — the consumers that change meaning without their own
     source changing are the catalog-driven ones, ORVION has exactly one, and test 71 pins that set.
   * **API-3, second instalment — the two named endpoints, and both hid a defect (2026-08-29,
     `202607057300`/`202607057400`).** The owner's instruction was not to manufacture HTTP
     assertions but to audit the capability behind each uncovered endpoint. Both delivered.
     **`create_journal_entry` -> FIN-8**: the double-entry invariant lived only inside the RPC, so a
     `finance_manager` INSERTed a single 1,000,000-debit line with no credit by direct DML in the
     same transaction the RPC refused it, emitting no event. `debit_xor_credit` is PER-ROW and
     cannot express a statement about a SET of rows. Closed with deferred CONSTRAINT triggers
     carrying the RPC's own three rules, and **no session-less exemption** — integrity, not
     authorization. **FIN-9** recorded: a transactional client can still create a *valid* entry with
     no event, and an event trigger would double-emit.
     **`merge_customer_identity` -> CUST-1**, the more serious of the two: it archived the source,
     wrote its audit row, emitted a CRITICAL event and **re-pointed nothing** — a silent no-op since
     2026-08-21, because **TENANT-1's composite FKs turned the loop's first-key-column into
     `tenant_id`**. A prior fix broke it and nothing noticed. Closed by pairing `conkey` with
     `confkey`, plus the contact-method collision handling the correct loop immediately exposes
     (delete an exact duplicate, DEMOTE a colliding primary — the target is the surviving identity).
     **CUST-2** records why no guard caught it: the only tests naming the function checked its event
     VOCABULARY and its endpoint's EXISTENCE. **API-3 30 -> 25**; contract regenerated to 46 of 71.
   * **DOC-LC-1 — CLOSED 2026-08-29 (`202607057200`).** Canon 26's Document Lifecycle machine had
     never been wired: `app.status_transitions` held zero rows for `documents`, and
     `enforce_archive_authority` returns early unless `is_archived` changes -- it watches the
     BOOLEAN, so `lifecycle_status_code` was governed only by the catalog check, which asks whether
     a code EXISTS and never whether the MOVE is legal. REPRODUCED: a `trainee` with
     ARCHIVE_DOCUMENT = false, proven to SEE the document first, was refused by the RPC and
     succeeded by direct DML in the same transaction. Not cosmetic -- both document write paths read
     `archived` as a refusal condition, so any tenant user could **permanently freeze a colleague's
     passport**. Two transitions registered (`active`/`superseded` -> `archived`, ARCHIVE_DOCUMENT
     read out of `archive_document`), and `archived -> active` now refused, which canon lists
     nowhere. No role gained or lost authority. **`active -> superseded` deliberately NOT
     registered** -- nothing produces that state (**DOC-LC-2**); supersede is an EVENT about the
     version pointer, not a document status. **DOC-LC-3** recorded: the `is_archived` boolean and
     the status column are two representations of one concept and an authorized holder can still
     split them -- blocked on a canonical contradiction, pinned rather than guessed.
     Guard: `69_document_lifecycle_test.sql` (19) plus 6 HTTP assertions including
     `PATCH /rest/v1/documents`, the real attack shape. **API-3 30 -> 29**: `archive_document` had no
     HTTP evidence at all before this, which was a poor thing to be true of the endpoint that
     retires a customer's passport. Also repaired here: `54_transition_permission_parity_test`'s
     final assertion hardcoded `lead_status_code` because every exclusion was a `leads` row when it
     was written; the status column is now derived per table from `app.status_transitions`.
   * **PAR-1b — a correction to yesterday's correction.** The API-contract report claimed Primary's
     `document_retention_days` was restored to the repository's exact text. It was not: I read it out
     of a LOCAL database that had been hand-modified mid-session, so the "fix" moved Primary away
     from the repository. Settled by experiment -- the migration file's own statement and a clean
     `db reset` both produce the 27-character form, which both environments now hold, and the
     function returns NULL on both, so RET-1 was never at risk. The parity script's header now says
     that local equals the repository ONLY immediately after a reset.
   * **API CAPABILITY CONTRACT — DELIVERED 2026-08-29 (API-2).** `MASTER_API_CONTRACT.md`, GENERATED
     from `pg_catalog` and `app.status_transitions` by `scripts/generate-api-contract.ps1` and kept
     honest by a new **Check L3** in `check_database_parity.ps1` that regenerates and diffs it
     (proven to fail on a tampered file and pass when regenerated). It covers the 71 RPC endpoints,
     the 8 reporting views AND the 71 tenant-reachable TABLES, because PostgREST serves tables too
     and that is where SEC-1b lived. Platform-wide rules (auth, tenant derivation, MFA step-up, 204
     on void, error classes, pagination/filter/sort, RLS returning empty rather than 403) are stated
     once rather than repeated per endpoint. Two defects were found in the GENERATOR before it
     shipped: a first-match CASE that reported only half of `advance_lead`'s authority model, and an
     HTTP-coverage column that under-counted 38 as 1. Recorded as **API-3**: 33 of 71 endpoints
     still have no HTTP evidence, now visible and payable down deliberately rather than assumed.
   * **Owner recommendations evaluated 2026-08-29 (10 items).** ACCEPT × 9, ACCEPT-with-finding × 1.
     None changed the execution order; one refined it — the contract must cover the TABLE surface,
     not only the RPCs. **SEC-2 reproduced and bounded** rather than left abstract: a trainee renamed
     a lead assigned to them, but could not touch a colleague-owned complaint, so the exposure is
     descriptive columns within existing read scope and it does NOT block the contract.
     **CONV-3 recorded**: the WhatsApp/AI data model is ready (nullable customer/owner/sender,
     external ids, whatsapp catalog values, `orvion_integration` attribution capture) but there is
     no session-less inbound DOOR; deferred to the integration phase, precedent already in-house.
   * **COMPLAINTS + CONVERSATIONS OVER HTTP — CLOSED 2026-08-29 (`202607057000`).** Both lifecycles
     walked end to end over real JWTs: the complaint state machine through all nine transitions
     including reopen, the conversation machine including the escalate/close authority split, plus
     tenant isolation and the trainee's scope. New suite `scripts/verify_care_journeys.ps1` (38).
   * **SEC-1b — SEC-1 was NOT closed, and the ceiling is why.** `10_grant_model_test`'s detector
     asked whether a table had a trigger MENTIONING app.authorize, never WHEN it fires;
     `enforce_status_transition` and `enforce_archive_authority` are BEFORE UPDATE ONLY, so thirteen
     tables were credited for protection on a path they did not have. Corrected predicate: residue
     3 -> 15. REPRODUCED: a `trainee` holding no write permission inserted a complaint AND a
     conversation by direct DML in the same transaction that `app.create_complaint` refused, and
     again over the wire via POST /rest/v1/complaints. Twelve tables now guarded ON INSERT with the
     permission each one's own creating RPC charges; INSERT only, because charging CREATE_BOOKING on
     UPDATE would break finance issuing a booking. Detector fixed too — the middle ceiling rose
     17 -> 18 while exposure fell, and the file explains why. Residual UPDATE axis recorded as
     **SEC-2**, genuinely underivable: there is no `update_customer` RPC to read a permission from.
   * **ATTR-4 / CONV-2 / COMP-1.** A conversation message could name any colleague as its sender
     (reproduced: "Colleague | I never wrote this"), could be rewritten after sending, and could be
     deleted. All three closed, with `external_message_id` and `metadata` deliberately left writable
     so the WhatsApp delivery writer is not blocked. And `complaints.resolution_notes` — declared in
     canon 31, written by nothing — now records the reason given for RESOLVING, that transition only.
   * **TEST-2 / PAR-1a — two guard-integrity findings the package produced about itself.** Pass B
     DIED where Pass A was green: the new HTTP suite and the new pgTAP file both used
     `emp@care.test`, and `auth.users.email` is globally unique with no tenant column to scope by —
     the one identifier the slug-collision discipline never mentioned. Swept the class: 117 fixture
     emails, zero other collisions. And the comparison used to close PAR-1 yesterday was itself
     wrong: `'--[^\n]*'` in a POSIX bracket expression means "not a backslash and not the letter n",
     so yesterday's "all 228 byte-identical" was true only under a weaker normalization. The guard's
     own `chr(10)` form found `app.document_retention_days` still differing. Behaviour verified
     first (both NULL — RET-1 intact), then restored, and the guard header now forbids the pattern.
   * **SCHEDULED / BACKGROUND EXECUTION AUDIT — CLOSED 2026-08-29 (`202607056900`).** All six
     background paths inventoried and traced CRON -> FUNCTION -> TABLES -> TRIGGERS -> RLS -> EVENTS
     -> CURSORS -> RETRIES -> OBSERVABILITY. `reconcile_document_storage` already had per-tenant
     exception isolation, a persisted failure finding and self-healing; `process_lead_sla`,
     `process_subscription_lifecycle` and `map_outcomes_to_conversions` had none of the three. The
     exemplar was in-house, so the fix is that pattern applied where it was missing, not a new one.
   * **CONV-1 — the finding that was NOT latent.** The mapper filtered restricted tenants out of its
     set-based INSERT and advanced the cursor past their events anyway. REPRODUCED: a lapsed
     tenant's conversion was destroyed, and restoring the tenant to good standing recovered nothing
     on run 2 or run 3. Everywhere else in ORVION "a batch skips a lapsed tenant" means DEFER --
     `process_lead_sla` retries a minute later, `platform_resolve_storage_finding` leaves the
     finding open. The mapper was the only place it meant discard, and only because it owns a
     cursor. Now: the skip is recorded BEFORE the cursor moves, each run reconsiders deferrals whose
     tenant is writable again, and the cursor still advances so no tenant blocks another. Two
     alternative fixes were costed and rejected in the register.
   * **PAR-1 — the parity guard had never compared the function surface.** A full comparison of all
     228 `app`+`public` functions found SIX whose stored source on Primary differed from the
     repository -- reformatted, comment-stripped transcriptions from earlier hand-pasted deploys.
     Behaviour was proven identical FIRST (whitespace-insensitive hashes matched on all 228), so
     this was documentation loss on the deployed system, not a logic difference. The real defect is
     that parity had only ever compared the migration-ledger fingerprint plus the functions each
     package had just changed -- so drift anywhere else was invisible by construction, while every
     report cited the guard as evidence. Fixed on all three axes: Primary's six restored to the
     repository's exact text, `check_database_parity.ps1` given `-PrimaryLogicHash` and a
     full-surface Check L2/P2, and a permanent rule that `apply_migration` receives migration text
     VERBATIM. Byte-level parity now proven: `4821a18a9bf8193a4bc8c7dea6e345a8` on both sides.
   * **LEAD-4 — CLOSED the day after it was recorded.** `reassignment_blocked` is now durable in
     `scheduled_job_findings`, not merely returned to a cron that discards it.
   * **ATTR-3 / §8 item J — CLOSED 2026-08-29 (`202607056700`).** The owner's ATTRIBUTION BUSINESS
     RULE requires that reassignment never rewrite acquisition lineage. Item J's question is answered
     by measurement and now asserted on BOTH paths: `app.reassign_lead` and `app.process_lead_sla`
     move ownership and touch no lineage column. The STRONGER half of the rule was false —
     `authenticated` holds UPDATE on `leads` and `scope_isolation` covers the whole department queue,
     so any employee could re-anchor a lead to a different click, moving a future Google Ads
     conversion and the revenue credited with it between campaigns. ORVION's own
     `capture_attribution_click` already stated the rule ("First-touch anchor ... where
     attribution_click_id is null"); it lived in the RPC and not on the table. One trigger,
     `app.forbid_acquisition_lineage_rewrite`, now applies first-touch to the named lineage columns
     of `leads` AND of `offline_conversions` — the revenue end of the same chain, where a ceo or
     owner could re-point an already-recorded conversion. NO session-less exemption, because the only
     post-insert writer performs the one transition the guard permits.
   * **LEAD-3 — RESOLVED AND FIXED 2026-08-29 (`202607056800`).** Filed as an owner decision ("does
     'another eligible employee' include a manager?"). The permission matrix answers it: CLOSE_LEAD,
     CREATE_LEAD, CREATE_QUOTATION and VIEW_DEPARTMENT_QUEUE resolve to the same six roles, managers
     among them — so managers stay. Underneath was a defect, reproduced first: the pool was everyone
     PLACED in the branch and department, so an SLA-overdue lead was reassigned to a **trainee**
     (`can_close_lead=f`, `can_quote=f`), and `finance_manager` and `system_administrator` were
     equally eligible. SEC-1's shape in the one place with no human in the loop — capability by
     proximity instead of by authority. `app.eligible_lead_handlers` now requires CLOSE_LEAD through
     an active role assignment; when nobody qualifies the lead STAYS and the pass reports
     `reassignment_blocked` (**LEAD-4**: nothing consumes that on a cron run yet). The HUMAN path is
     deliberately untouched and this is settled, not deferred — `verify_lifecycle_branches` already
     asserts that a trainee may work a lead they are ASSIGNED.
   * **Business-decision audit 2026-08-29, per the owner's closure directive.** Every BLOCKED —
     BUSINESS DECISION re-evaluated against canon, live evidence and the accumulated intent. SIX
     resolved without asking again: **LEAD-2** (canon 25 declares `lead_source` a Tenant-Extendable
     System Catalog with "Tenant additions: Allowed with admin permission", and
     `catalog_tenant_insert` enforces exactly that — proven behaviourally, so ORVION must NOT ship
     `walk_in` as a system default); **LEAD-3**; **RBAC-2** (`roles`/`role_permissions`/`permissions`
     grant `authenticated` SELECT only — tenant-side role administration does not exist, so
     MANAGE_ROLES gates nothing BY DESIGN, and attaching it to `assign_user_role` would have
     mislabelled user administration); **PERM-1** (all three carry a `required_feature_code` and are
     plan entitlements; API-1's surface is ORVION's OWN data path, so gating it on ACCESS_API_* would
     disable the product per plan — the answer is no); **TASK-3** (canon 26 names both start
     transitions and lists five required events, none of them a start — a choice, not a silence);
     **ORPH-1** (a tenant cannot create an orphan through the API, so an orphan implies platform-side
     failure — reviewed, never destroyed on sight). TWO narrowed with new evidence: **FIN-5** (six of
     seven approval types have no producer at all, so the map is EVT-2's class, not a permission
     decision) and **VOID-1** (canon DOES register a `voided` invoice status; void-vs-credit-note
     remains an accounting model choice). The rest stay blocked on facts that are genuinely external
     — a statutory retention period, one owner-placed secret, where platform-operator identity lives.
   * **GUARD-1 — recorded and mitigated 2026-08-29.** `check_database_parity.ps1` printed "Primary
     matches the repository" for a fingerprint **I** passed it — the repository's own expected value.
     `apply_migration` had stamped its own `version` into Primary's ledger, so Primary actually
     produced `ca253f45...` against the repository's `0c48b1fd...`. Caught by querying Primary
     independently, not by the guard. The ledger rows were normalised to the repository convention,
     and the script's success line now carries the caveat its header always had.
   * **SLA-1 — CLOSED 2026-08-29 (`202607056600`).** canon 04 and canon 10 both require the
     employee's MANAGER to be notified at 15 minutes and again on reassignment, and canon 10 lists
     "Manager escalation" among the notifications a user CANNOT MUTE. It had never fired.
     REPRODUCED first, with a positive control: in the standard configuration -- managers PLACED in
     the branch through `user_branch_assignments`, holding TENANT-scoped roles, which is exactly what
     `app.assign_user_role` produces by default -- one SLA pass gave the employee 1 notification and
     both managers 0, while the same transaction proved they CAN see the lead. Root cause is the
     recurring shape, this time in the operational layer: the lookup asked
     `user_role_assignments.branch_id/department_id` ALONE, while ORVION's authoritative definition
     of governance (`visible_branch_ids` / `visible_department_ids`) is a UNION that also includes
     PLACEMENT -- the only source populated by default. Second instance in the same function: the
     reassignment branch had no manager notification at all. Fixed with
     `app.lead_responsible_managers`, used by BOTH paths so no second copy of the predicate exists,
     and carrying the `is_active`/`starts_at`/`ends_at` bounds the inline version omitted.
     NOT changed: which roles escalate, the 15/30 windows, the reassignment pool, the event
     vocabulary. No existing test caught this -- 34 and 36 assert the EVENT and the tenant isolation,
     never the recipient. Recorded while proving it: **LEAD-3**, the reassignment pool includes
     managers and the tie broke to the branch manager; canon 04 says "another eligible employee" and
     defines neither term, so it is an owner decision and was deliberately left alone.
   * **TEST-1 — CLOSED 2026-08-28.** `38_class_a_events_test` failed on a composite FK because its
     fixture read `from public.payments p, public.invoices i limit 1` -- unscoped, running as
     `postgres` with RLS off, and duly paired this fixture's payment with an invoice
     `verify_role_journeys.ps1` had left behind. Scanning all 58 files found **40+ fixture subqueries
     across 11 files** selecting their own rows by a non-unique attribute with no tenant predicate:
     bounded only by RLS, and only while the actor happens to be `authenticated`. All scoped. The fix
     is verified by REGIME, not by a green run: the suite is now proven order-independent -- 672
     assertions, 0 failures, both on a fresh `db reset` and immediately after every HTTP suite has
     deposited its deliberately non-teardownable residue.
   * **TABLE-BY-TABLE AUDIT — SLICE 1 DONE 2026-08-31 (`202607058800`, `202607058900`).** The 54
     tables `authenticated` can write were ranked by guard and test coverage, and the ranking was
     ATTACKED before it was used: a first pass keyed on `guard_write_capability` scored the finance
     tables as unguarded, which is false (FIN-3 gave them dedicated triggers under other names).
     Corrected, it produced three clean results — SPEC-138 covers every identity/organization write
     with per-command `MANAGE_*` policies; the accounting core requires its exact canon-28
     permission and journal entries must balance; every FK into `exchange_rates` is tenant-qualified
     — and four defects. **FX-1** a negative or zero exchange rate was insertable (`rate = -48.5`
     returned `INSERT 0 1`); **FX-2** its `set_by` was accepted from the caller; **FX-3 (Medium)**
     `user_role_assignments.assigned_by` — the record of who GRANTED a role — was accepted from the
     caller, reproduced two-door in one transaction where `app.assign_user_role` recorded the owner
     who called it and the direct INSERT recorded **the manager being promoted**; **FX-4**
     `subscription_payment_proofs.reviewed_by`, unreachable today (no role holds
     REVIEW_SUBSCRIPTION_PAYMENT and the platform path never writes it) and guarded anyway because
     canon 28 assigns that permission. `otp_challenges`/`totp_enrollments` were found owner-scoped
     with NO reader and deliberately left alone — inventing a consumer to justify a guard is this
     audit's stated non-goal. **The durable output is not the migrations.** A hand-written
     actor-column list reported ONE gap and looked finished; adding `assigned_by` produced FX-3 and
     `reviewed_by` produced FX-4, so the detector became `83_actor_attribution_test.sql` assertion
     22, which asks `information_schema` with **no exemption list** and **closes GOV-8**. Test 83
     (22); HTTP unchanged at 366. No ADR added: all four are instances of ADR-0024/0025.
   * **CARE/CONVERSATION SLICE — DONE 2026-08-31 (`202607059000`), DEPLOYED.** Four of the five
     tables clean and checked rather than counted: `complaints` and `service_requests` carry seven
     triggers each; `conversation_messages` derives its sender and forbids rewriting a sent message;
     `conversations` lacks two guards its siblings have and has neither `is_archived` nor an actor
     column for them to apply to. `quotation_items` failed twice, both with the RPC as positive
     control. **QUO-2 (Medium):** a line could be added to — and repriced on — a quotation already
     SENT to the customer (a 7,777 line landed; an existing line went 10,000 → 1). The repricing half
     has **no RPC at all**, so direct DML was the only path, and the rule for it is derived from
     `add_quotation_item`'s stated reason rather than from a second function. **QUO-3:** the table
     carried **no CHECK constraints whatsoever** and stored `-5000` and `quantity 0`, while
     `total_amount` feeds `quotations.total_amount`. **QUO-4 is an OWNER DECISION**, reproduced and
     deliberately not fixed: canon 28 scopes CREATE_QUOTATION "Assigned only" for `employee` and
     NEITHER door enforces it — but canon's own scope column reads "assigned/department", so the
     answer is a business rule, not a derivation. **ATTR-2:** assertion 22 was widened from a
     hand-written name list to every column ending `_by`, which found **eight** more caller-supplied
     actor columns. Test 84 (17); HTTP unchanged at 366. No ADR added: QUO-2/QUO-3 are instances of
     ADR-0024/0025.
     *(The "NEXT SLICE: ATTR-2" line that stood here was **stale from 2026-09-01**, when
     `202607059300` closed ATTR-2 — this plan recorded SEC-1c and SUP-1 that day and never replaced
     the pointer. Corrected 2026-09-01 in the care/conversation re-audit; the entry below is the
     current one.)*
   * **CARE/CONVERSATION RE-AUDIT — PARENT-1, DONE 2026-09-01 (`202607059400`), DEPLOYED.** The
     slice was re-entered from live state rather than from the report above, and the four tables
     previously recorded as "checked, not counted" were re-measured against the doors the earlier
     pass had not walked: the status machines (all three governed, every row carrying a
     `permission_key`, `enforce_status_transition` failing closed on an unregistered transition),
     resolution attributability, terminal-state immutability, tenant/branch/department scope, and
     grants. **`conversations` and `complaints`/`service_requests` came back genuinely clean, and
     this time the reason is recorded rather than the count:** `resolved_at` / `closed_at` /
     `resolution_notes` have **no consumer anywhere** (no view, no function, no policy — measured),
     and CREATE_COMPLAINT and RESOLVE_COMPLAINT are held by **identical role sets**, so
     `guard_write_capability`'s union is behaviour-neutral; `conversations.current_branch_id` /
     `current_department_id` are written by `start_conversation` and read by nothing (DEAD-1's
     class); descriptive-field editability is SEC-2's ratified INTENTIONAL half.
     **`conversation_messages` failed**, and it turned out to be a CLASS — see **PARENT-1** in
     `MASTER_GAP_REGISTER.md`: four RPCs refuse a write because of the PARENT row's state
     (`create_booking`, `request_finance_approval`, `add_document_version`,
     `send_conversation_message`) and **not one of those rules existed on the table door**. Derived
     from `app.status_transitions` + `pg_proc` + `pg_trigger`, not from a list; twelve candidate
     pairs reduced to four by READING the function bodies rather than trusting the match. All four
     reproduced live with the RPC as positive control. Closed by one guard function and four BEFORE
     INSERT triggers. Test 88 (25) + 5 HTTP; suite 87/1186 → **88/1211**, HTTP 371 → **376**.
     **QUO-4 remains the only open OWNER decision from this batch** and was not reopened (§10).
   * **FINANCE PERIPHERY — PAY-1 / JE-1 / DEV-1, DONE 2026-09-01 (`202607059500`), DEPLOYED.** The
     slice was chosen from the catalog, not from a list: of the 54 tables `authenticated` can write,
     the ones with no capability guard AND no test **subjectship**. That ranking was ATTACKED before
     use, twice — counting BEFORE triggers scores `moddatetime` and `emit_*` as protection, and
     counting test-file mentions scores `branches`/`users`/`tenants` at 60–76 because every test
     builds a tenant fixture. **Appearance is not subjectship.**
     **PAY-1 (High):** `app.record_payment` refuses a draft, voided or archived invoice and
     `payment_allocations` carried neither rule — 1,000 EGP allocated against a **voided** invoice,
     and FIN-10's ceiling stayed green because it caps the AMOUNT and never reads the STATE.
     **JE-1:** a line posted to a **retired** chart account; two of the RPC's three line rules were
     already on the table door and were deliberately not re-added. **DEV-1:** two rows for one
     device, reproduced **through the RPC alone** with two concurrent sessions — LIC-2's shape —
     severity Low because `app.mfa_satisfied()` was measured to consult only the JWT.
     **MEAS-5, the finding about my own guard:** PARENT-1's detector could not see PAY-1, because
     `invoices` has no `app.status_transitions` rows (FIN-7) — a detector anchored on a catalog of
     TRANSITIONS was blind to a STATE. Widened to catalog-coded columns read from trigger arguments,
     narrowed by FK and writability (46 noisy pairs → 9 classified), counterexample-tested both ways.
     Its residual — boolean-flag state — is stated in the test rather than hidden, and JE-1 is that
     residual. **JE-2 recorded, NOT fixed:** a 100 USD debit balances a 100 EGP credit, on both
     doors; canon defines no single-currency rule and DC-11 owns the model.
     **DEAD-4 recorded:** `campaign_daily_metrics`, `exchange_rate_adjustments` and
     `financial_accounts` have neither producer nor consumer — measured in both directions.
     Test 89 (21); suite 88/1211 → **89/1232**, HTTP 376 → **381**.
     *(The "NEXT SLICE" pointer that stood here is replaced by the entry below rather than left to
     go stale a second time — the failure this document's own header records.)*
   * **SUPPLIER CREDIT AUTHORITY — SUP-2, DONE 2026-09-02 (`202607059600`), DEPLOYED.** The slice
     was chosen by MEASURING the surface rather than from a list, and three candidate classes were
     discarded by that measurement before a fourth produced a defect: `authenticated` holds **zero
     DELETE** on all 75 tables, no granted command lacks an RLS policy, and every SECURITY DEFINER
     function in `app`/`public` already pins `search_path` and is closed to `anon`. What remained was
     a five-column class — every column `authenticated` cannot SELECT but CAN insert or update. Four
     carry dedicated column-aware financial guards (SPEC-139/154-A/159-A). **The fifth,
     `suppliers.credit_limit_amount`, carried only the table's ASSIGN_SUPPLIER charge**, and
     ASSIGN_SUPPLIER and VIEW_FINANCIAL_DOCUMENTS are held by **different role sets** — so
     branch_manager, department_manager and senior_employee could SET the ceiling SUP-1 refuses to
     show them, which for those three defeats the withholding entirely: an actor who sets a value
     knows it. Reproduced as `senior_employee` on BOTH doors with the refusal established FIRST in
     the same session, and the writes verified by reading the values back WITH rights.
     **It survived two packages that both read this exact column**, because each recorded the other
     as owning the half it skipped — and SEC-1c's proof used a *trainee*, who lacks ASSIGN_SUPPLIER,
     so it measured "the weakest actor is refused" and never "the authority is sufficient".
     No permission minted: the floor is forced by SUP-1's own guarantee — the write must cost at
     least the read. **SUP-3 recorded, NOT decided** — whether `finance_manager` should hold
     ASSIGN_SUPPLIER is commercial, and SUP-2 is correct under either answer. One existing test
     CORRECTED rather than re-run: test 85's PAR-4 mutation dropped `suppliers_guard_write_capability`
     and asserted the write then succeeded, which a second guard on that column would have made
     measure nothing. Test 90 (15) + 9 HTTP, each with defect injection at its own layer; suite
     89/1232 → **90/1247**, HTTP 381 → **390**.
     **CLASSES MEASURED CLEAN in the same pass, recorded so the next slice does not re-measure them
     without new evidence** (LOCAL RUNTIME on a fresh `db reset`, 2026-09-02): (i) `authenticated`
     holds **zero DELETE** on all 75 tables — that surface is closed by B5, not merely unexercised;
     (ii) **no granted command lacks an RLS policy** — zero SELECT/INSERT/UPDATE grants to
     `authenticated` sit on a table with no matching policy; (iii) all **24** SECURITY DEFINER
     functions reachable by `authenticated` pin `search_path=""` and **none** is executable by
     `anon`; (iv) **archive authority is complete** — every table carrying `is_archived` has an
     `enforce_archive_authority` trigger, with no exceptions; (v) all **8 reporting views are
     `security_invoker`** and none is a read-door around a withheld column — `supplier_outstanding`
     takes its money from the gated `app.supplier_balance`, and `booking_item_profit` was proven
     against a REAL priced item owned by a COLLEAGUE (the first probe returned zero rows and was
     discarded as vacuous per `AGENTS.md 6`): with the employee's four controls established, the
     view returned `selling_amount 10000` and **`cost_amount`/`profit` NULL**.
     **NEXT SLICE: the remaining Batch-6 tables** — the table-by-table audit below still owns the
     order. The write-without-read class is now closed on all five of its columns, and the five
     classes above are measured rather than assumed; a next slice needs a class none of them covers.
   * **PHASE C CONTINUED — the table-by-table audit.** WHY IT EXISTS: every package so far has
     found defects beside the one it was chartered for, and the remaining surface has never been
     swept as a whole. DISCOVERY SOURCE: the standing owner directive. SCOPE: all 75 tables and their
     relationships — schema, FKs, RLS, grants, functions, SECURITY DEFINER, triggers, catalogs,
     permissions, events and their producers/consumers, reporting views, scheduled jobs,
     integrations, RPCs, direct-DML surfaces, test families, governance — inspected for BEHAVIOURAL
     consistency, not existence. Plus the journey branches not yet walked over HTTP: refund,
     cancellation, complaint, service request, supplier payment, finance approvals, conversations,
     tasks. NON-GOALS: inventing features to give registered vocabulary a producer; adding reports
     because mature CRMs have them. ACCEPTANCE: every finding classified PROVEN/UNPROVEN/FAILED/
     BLOCKED and, if an engineering defect, fixed. TEST CRITERIA: each fix carries positive and
     negative controls plus the relevant direct-DML/RPC/system/cross-tenant paths. DEPLOYMENT:
     migrations to Primary, parity re-proven, PostgREST cache reloaded when the surface changes.
   * *(historical, superseded)* **API-1 as originally scoped: the database is
     complete and unreachable.** WHY IT EXISTS: proven live against Primary, PostgREST serves only
     `public` and `graphql_public`, so all 137 `app.*` functions and all 8 `reporting` views return
     404/406. DISCOVERY SOURCE: WP-04-E, when the executor needed to call its own RPC over HTTP.
     Invisible for the whole programme because every RPC test speaks SQL, not HTTP — 600 passing
     assertions coexisted with a completely unreachable API. DEPENDENCIES: none blocking. SCOPE:
     enumerate the client-facing RPCs and reporting views; wrap each in `public` as **`security
     invoker`**; grant deliberately per role; prove each **over HTTP**. NON-GOALS: exposing the `app`
     schema (it would publish every internal helper RLS depends on — a permission-probing oracle and a
     frozen internal API); wrapping internal helpers; inventing endpoints for capabilities that do not
     exist. SECURITY CRITERIA: no wrapper is ever `SECURITY DEFINER` (it would check the inner EXECUTE
     grant against the owner and bridge into the private schema); every wrapper pins `search_path`;
     no wrapper is executable by `anon` unless deliberately intended. TEST CRITERIA: the class guards
     in `52_public_api_and_executor_contract_test.sql` plus a per-endpoint HTTP proof with a positive
     control and a cross-tenant negative. CROSS-PATH CRITERIA: each endpoint must behave identically
     to its `app.*` function under RLS — the wrapper adds reachability and zero authority. DEPLOYMENT:
     migrations to Primary, parity re-proven. REPORTING: an endpoint inventory that survives as the
     client contract. Also decides whether `ACCESS_API_FULL`/`ACCESS_API_READ_ONLY` gate the surface
     (PERM-1).
   * *(historical, superseded)* **WP-04-E as originally scoped: the storage executor.** WP-04-D stops at the database boundary because that is
     where the database's authority stops; the split it establishes is half-built, and
     `retention_expired` findings accumulate unresolved (safe — nothing is destroyed — but not
     finished). Acceptance criteria: an executor authenticating as `service_role`, polling open
     findings, performing exactly the byte operation each finding names through the Storage API,
     reporting back through the one RPC, idempotent under retry, unable to act on a finding whose
     tenant is restricted, and never touching an object outside the finding's own tenant prefix. Edge
     Function vs n8n to be decided on evidence in that package.
   * *(historical, superseded)* **WP-04-D as originally scoped: document retention, deletion, recovery and orphan reconciliation.** Storage
     now exists on Primary, so an orphaned object is physically possible from this point: the byte
     upload happens *after* the metadata transaction and cannot be rolled back by it. Acceptance
     criteria: a scheduled reconciliation finds metadata without objects and objects without
     metadata, per-tenant and **skip-never-raise** (the WP-03 shape); archival/deletion are
     `service_role` lifecycle operations emitting `document_archived`; superseded versions stay
     retrievable for the retention window; cross-tenant reconciliation proven not to touch another
     tenant's objects. **The retention period itself is BLOCKED — BUSINESS DECISION** (Egyptian
     record-keeping obligations for travel documents are not in canon). Should land before any client
     begins uploading bytes.
   * *(historical, superseded)* **WP-04-C as originally scoped: storage-provider evaluation, then the object store end to end.** Compare
     Supabase Storage / GCS / Google Drive / OneDrive-SharePoint on tenant isolation, private
     objects, signed URLs, versioning, retention, deletion, recovery, backup, encryption, access
     logging, auditability, size limits, performance, scalability, n8n integration, operational
     complexity, cost and lock-in — **fact separated from recommendation**, cost a factor and not the
     decider. Every non-Supabase option carries a genuine **BLOCKED — EXTERNAL DEPENDENCY** step (the
     owner enters external credentials directly, AGENTS.md §6) which must be weighed openly rather
     than allowed to decide silently. The object key is already settled and tested
     (`tenant/document/version`, tenant-first, provider-independent), so the chosen provider inherits
     a proven security model rather than one invented afterwards. Also carries **PP-2**.
   * *(historical, superseded by the two entries above)* **DOC-2 as first recorded — three layers.** (i) the `document_type` catalog has no
     `payment_proof` value; (ii) **`subscription_payment` IS already a `document_link_target_type`
     but `app.upload_document` has no branch for it**, so it falls through to `else false` and
     raises; (iii) `document_links.subscription_payment_proof_id` is populated by no code path. A
     circular dependency (`subscription_payment_proofs.document_id` is NOT NULL while the link needs
     the proof id) means the fix is a dedicated transactional RPC —
     `app.upload_subscription_payment_proof` — not another parameter on `upload_document`. Then the
     platform-side review that transitions the subscription and emits
     `subscription_payment_approved` / `_rejected`.
   * **The subscription-gate exemption (owner directive §7) belongs with WP-04-B.** Confirmed live:
     **zero** gate triggers on `documents` / `document_versions` / `document_links`, so a suspended
     tenant can create ANY document, not merely a renewal proof. Narrowing it requires
     `payment_proof` to exist first — that type is the discriminator by which the gate tells a
     renewal proof from an ordinary document — so sequencing it before DOC-2 would have meant
     inventing a placeholder.
   * SPEC-154-B's document-classification boundary is **no longer carried here** — it was decided by
     the owner and closed on 2026-08-31 by `202607058700`, ahead of this package.
   * **Provider evaluation is the gate** (owner directive §14): decided on tenant isolation, private
     objects, signed URLs, versioning, retention, deletion, recovery, backups, size limits,
     operational simplicity, scalability, auditability and n8n integration — explicitly **not** on
     cost or on Supabase already being present. Options to compare: Supabase Storage, Google Cloud
     Storage, Google Drive, OneDrive/SharePoint. One constraint is already evidence, not preference:
     every non-Supabase option needs an external credential, which AGENTS.md §6 requires the owner to
     enter directly into its destination — so those options carry a BLOCKED — EXTERNAL DEPENDENCY
     step that Supabase Storage does not, and the evaluation must weigh that honestly rather than let
     it silently decide the outcome.
4. **Notifications — NARROWED 2026-08-29 (GOV-6), verified live before editing.** This read
   "`notifications` / `notification_deliveries` have **no producer at all**"; `notifications` gained
   its first producer on 2026-08-29 when SLA-1 wired the manager escalation. What remains true:
   **`notification_deliveries` still has no producer** — nothing records that a notification was
   actually *delivered* on any channel — and `app.process_lead_sla` is still the **only** writer of
   `notifications`, which is why an expiring passport notifies nobody (**DOC-EXP-1**, owner-blocked
   on recipient/lead-time/cadence). So the delivery half is an engineering gap and the producer half
   is one owner decision, not a single undifferentiated hole.
5. **Employee / Supplier / Branch 360 primitives.** Customer 360 and Lead 360 exist
   (`app.customer_timeline`, `app.lead_timeline` — re-verified live 2026-08-29); these three do not.
6. ~~**`public.security_events` has zero producers.**~~ **OBSOLETE 2026-08-29 (GOV-6).** It has
   **four**, all added by SPEC-158 on 2026-08-27: `platform_issue_license_token`,
   `platform_review_payment_proof`, `platform_revoke_license_tokens`, `redeem_license_token`. This
   item contradicted **item 1c of this same document**, which records SPEC-158 giving the table "its
   first producers" — an intra-document contradiction that survived because Check 2 could not see
   modern finding IDs (**GOV-4**) and nothing at all checks prose open-items against the database.
   Kept struck through rather than deleted: the 13 *authentication* event types are still Supabase
   Auth events with no ORVION hook, which is **AUTH-1**'s territory, not a producer gap.
7. **Table/column completeness sweep** across all **75** tables — never finished.
8. ~~**SEC-1 write-path model** — remains the open owner decision~~ — **DECIDED 2026-09-01 (OWNER-1).
   No longer an owner blocker; struck through rather than deleted because the three forgeries of
   authoritative history recorded as its evidence are what earned the decision.** The owner ratified
   the refined architecture: **RLS carries row scope · capability enforcement sits on the actual
   writable surfaces · business mutation rules stay in the owning RPC · integrity constraints are
   path-independent.** RPC-only authenticated writes were **rejected** — all 76 public RPCs are
   `SECURITY INVOKER`, and converting them would replace RLS with 76 hand-written tenant checks, the
   second authorization system canon 35 forbids. What remains under SEC-1 is *engineering*, not a
   question: **SEC-1b** closed the INSERT path, **SEC-1c** (`202607059100`) closed the UPDATE path on
   the thirteen tables that had a capability trigger on one side only, and **SUP-1**
   (`202607059200`) closed the read half of the supplier-credit case. Status and evidence:
   `MASTER_GAP_REGISTER.md`.

**Blocked on commercial decisions (none blocks the above):**
~~BLOCKED-1 trial plan tier + duration at provisioning~~ — **RESOLVED 2026-08-27**: owner set a
30-day full-feature trial; "full feature" resolved to the Enterprise plan on evidence (it is the only
plan with all 22 entitlements enabled), implemented in SPEC-157.
~~BLOCKED-2 what `MANAGE_SUBSCRIPTION` "Limited" means for Owner/CEO~~ — **RESOLVED 2026-08-27**, and
resolved in the opposite direction to the obvious reading: it is granted to **neither**. Platform
authority cannot be a tenant permission at all, because `app.has_permission` resolves the caller
through `public.users` joined on `current_tenant_id()` — every role holder is inside exactly one
tenant by construction. SPEC-157 places it on `service_role` instead.
~~BLOCKED-3 who may set `commission_rate`~~ — **RESOLVED 2026-08-27** by owner rule (10% of gross
profit, system-derived), implemented in SPEC-155.
**New, and none blocks current work:** **BLOCKED-4** — once booking-item ownership becomes
transferable (it is not today: `create_booking_item` sets all three ownership fields to the creator
and no reassignment path exists), does commission follow the new sales owner or stay with the
original seller? Pure compensation policy. **BLOCKED-5** — may the Platform Owner ever deliberately
re-grant a trial? Implemented conservatively as never (write-once stamp). **CANON-26-1** — canon 26
admits `suspended` only from `read_only`, so an active tenant cannot be suspended in one step;
`active -> cancelled` is available. Encoded as canon states rather than widened by assumption.

**Standing method for this batch** (`AGENTS.md §3 5b`, §6): every package ends with a cross-path
impact sweep classifying each affected execution path, and no security test may pass vacuously.

---

## Tooling / environment enablement (supports execution quality — see ARB report §Tooling)
- **Now:** pgTAP (DC-16); CR-invariant guard hook; secret scanning.
- **Recommended:** Supabase/Postgres MCP server (replaces `docker exec psql` verification with direct queries); `sqlfluff`/`squawk` migration linters in CI.
- App-facing tools (Playwright/Sentry/Stripe) remain future-gated (no app surface yet).
