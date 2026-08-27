# ORVION — WP-04-C: Storage Provider Evaluation, the Object Store, and Two Sibling Defects

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: Migrations `202607054600`, `202607054700`, `202607054800`. Selects the storage provider on
evidence, creates ORVION's first object store with authorization that is the *same mechanism* as row
authorization, closes PP-2, and closes two defects found by a failing assertion in this package's own
new test.

Predecessor: `wp-04b-payment-proof-lifecycle-2026-08-27.md`.

> **For a reader who knows nothing about ORVION.** ORVION is a multi-tenant travel CRM for Egyptian
> travel agencies, built Supabase-native: PostgreSQL migrations plus `app`-schema RPCs, with Row Level
> Security as the security boundary. Each tenant is an agency. Documents (passports, tickets,
> vouchers, invoices, payment proofs) have had metadata tables since the beginning, but until this
> session there was **no object store at all** — `storage.buckets` was empty on Primary while
> `document_versions.storage_path` was `NOT NULL`.

---

## SESSION / DATE / OBJECTIVE

WP-04-C, 2026-08-27. Evaluate storage providers on evidence, implement the chosen one end to end,
and close PP-2 — without letting "Supabase is already here" decide the outcome.

## STARTING STATE — re-proven, not carried forward

Per the directive, every claim from the previous report was re-verified before use:

| Fact | Method | Result |
|---|---|---|
| Repository guard | `check_repository_consistency.ps1` | CLEAN |
| Migration files | filesystem count | **134** |
| Primary ledger | MCP `execute_sql` | **134**, `198ff244ecdd84c14c14059a067f637e`, latest `202607054500` |
| Parity | `check_database_parity.ps1 -PrimaryFingerprint` | CLEAN (local proven; primary proven) |
| GitHub | `gh api …/commits/main` | `ea228b6c6d50…` == local HEAD `ea228b6` |
| n8n | MCP `search_workflows` | **0 workflows** |
| Primary storage | MCP | **0 buckets** |
| Primary business rows | MCP | **0 tenants** |
| Test files | filesystem count | **47** |

**WP-04-C was confirmed as next by evidence, not assumed.**

## PROVIDER EVALUATION — fact separated from recommendation

**ORVION's requirements are facts established by earlier packages, not preferences:**

* **R1** the object key is `tenant/document/version`, derived server-side and tenant-first (WP-04-A);
* **R2** canon 35 principle 4 — every policy calls an `app.*` primitive so the mechanism evolves in
  one place;
* **R3** document visibility is already solved and tested (`documents.scope_isolation` carries
  confidential / financial / branch / ownership branches);
* **R4** AGENTS.md §6 — an external credential is entered by the owner directly, never through the
  agent;
* **R5** tenants are many small agencies; documents are numerous, small, and strictly isolated.

**FACTS**

* **Supabase Storage** — `storage.objects` is a PostgreSQL **table**. Verified live on Primary:
  `relkind = 'r'`, `relrowsecurity = true`, **policies = 0** (fail-closed today). Bucket rows carry
  `file_size_limit` and `allowed_mime_types`, so size and MIME are enforceable by the store itself
  and not only by the RPC that records metadata.
* **Google Cloud Storage** — prefix-per-tenant plus IAM is the standard shared-infrastructure
  pattern, but current practice reports that **dynamically generated IAM policies are not supported
  on GCP** and that IAM policy size becomes a ceiling as tenants multiply; the recommended escape is
  a "token vending machine", an additional always-on service. Project-per-tenant gives the strongest
  isolation and is disproportionate for small agencies.
* **Google Drive / OneDrive / SharePoint** — collaboration products, not application storage
  backends: per-tenant OAuth, change detection and pagination become sustained infrastructure work;
  SharePoint's quota is a shared tenant **pool** rather than per-customer allocation, the opposite of
  predictable isolation; Microsoft Graph caps a single PUT at 250 MB. All three also require an
  external credential (R4).

**RECOMMENDATION — Supabase Storage, on one decisive property, and it is not "already here".**

It is the only candidate where **object authorization and row authorization are the same
mechanism**. Because `storage.objects` is a Postgres table with RLS, the very
`app.current_tenant_id()` primitive that governs `documents` governs the bytes — and as implemented,
an object is visible **exactly when its `document_versions` row is visible**. Every other candidate
requires a second authorization system that cannot see ORVION's RLS, which would mean maintaining the
document-visibility rules twice and keeping them in agreement forever. That is the duplicated
authority canon 35 exists to prevent, and R2 forbids it.

**Cost did not decide this and is not cited as a reason.** **Rejected with reasons recorded:** GCS on
IAM scalability plus the extra service R2 forbids; Drive/OneDrive/SharePoint on being collaboration
products whose quota and identity models fight multi-tenant isolation. If ORVION ever needs an
external store (data residency, or files far beyond CRM documents), the object key is already
provider-independent, so the migration is a copy plus a policy rewrite — not a redesign.

## DEFECTS FOUND

### PP-2 — `document_links` had a column with no policy branch (carried from WP-04-B)

`scope_isolation` had a branch for every link target **except** `subscription_payment_proof_id`. The
payment-proof link therefore satisfied the policy only through the unrelated `has_tenant_wide_read()`
branch, which happens to be true because `VIEW_ALL_BRANCHES` (Owner + CEO) is exactly the role set
holding `MANAGE_TENANT_SETTINGS`. The link was authorized **for the wrong reason** — it worked by
coincidence, and granting `MANAGE_TENANT_SETTINGS` to a role without `VIEW_ALL_BRANCHES` would have
broken subscription renewal with a confusing RLS error.

### SPP-1 and SPP-2 — found by a FAILING ASSERTION in this package's own test

Assertion 10 of the new `48_document_storage_test.sql` asserted an employee cannot see a
payment-proof link. It failed. The cause was not the link policy but its sibling:

| | `subscriptions` | `subscription_payment_proofs` |
|---|---|---|
| read | tenant **AND `VIEW_SUBSCRIPTION_STATUS`** | tenant **only** ← **SPP-1** |
| insert | tenant **AND `MANAGE_SUBSCRIPTION`** | tenant **only** ← **SPP-2** |
| update | tenant AND `MANAGE_SUBSCRIPTION` | tenant AND `REVIEW_SUBSCRIPTION_PAYMENT` (correct) |

* **SPP-1** — every tenant user, down to a trainee, could read every payment proof: when the agency
  paid, who uploaded it, the reviewer's notes, the decision. `subscriptions` is properly restricted
  to Owner/CEO; the sibling leaked the same commercial history.
* **SPP-2** — any tenant user could **forge a pending payment proof by direct DML**, needing no
  permission at all. They could not approve it (update was already gated), but a fabricated proof is
  audit pollution and a plausible way to mislead the Platform Owner into approving an unpaid renewal.

**§19 SELF-CORRECTION.** This is a defect **my own WP-04-B package should have caught**: it added the
review path, the catalog trigger and the narrowed gate to this very table without ever comparing its
RLS against its parent. That is exactly the sibling-table audit the programme has now been bitten by
**three times** — FIN-1 (`booking_items` vs `booking_item_passengers`), DOC-1/DOC-3 (`documents` vs
`document_versions`), and now this. Earlier tests missed it because no test had ever asked an
*ordinary employee* to read a payment proof; every prior fixture used Owner or postgres.

## DEFECTS FIXED

* **`202607054600`** — the private bucket and two storage policies. Bucket `public = false`, so no
  anonymous URL exists; `file_size_limit` 10 MB and `allowed_mime_types` mirroring what
  `app.upload_document` accepts, so metadata and bytes cannot drift apart. The read and insert
  policies deliberately **do not restate who may see a document** — they ask whether the caller can
  see the `document_versions` row whose `storage_path` equals the object name, and that subquery is
  itself subject to that table's RLS. The entire document-visibility model therefore applies to the
  bytes with no rule duplicated. A tenant-prefix test is included as defence in depth.
  **No UPDATE and no DELETE policy exists, by design**: RLS with no policy denies, documents are
  versioned, and overwriting an object in place would defeat the audit trail. Retention and deletion
  are `service_role` lifecycle work, recorded as WP-04-D rather than improvised.
* **`202607054700`** — PP-2. All nine branches transcribed verbatim from the live expression, with
  the new one added. `subscription_payment_proofs` carries its own RLS, so the branch admits only a
  proof the caller could already see: the link becomes visible for the right reason.
* **`202607054800`** — SPP-1 and SPP-2. Read now requires `VIEW_SUBSCRIPTION_STATUS`, identical to
  the parent. Insert requires **`MANAGE_TENANT_SETTINGS`, not `MANAGE_SUBSCRIPTION`** — the one place
  the two tables must legitimately differ, because `MANAGE_SUBSCRIPTION` is deliberately held by no
  role (platform authority, SPEC-157) and requiring it would make proof upload impossible for
  everyone and destroy the only route back from a lapsed subscription. `MANAGE_TENANT_SETTINGS` is
  what the RPC already authorizes, so RLS and the RPC now agree.

## A VACUOUS TEST I WROTE, AND CAUGHT

The first version of the SPP-2 assertion had the employee run
`insert … select … from public.subscriptions`. Once SPP-1 made `subscriptions` invisible to that
employee, the SELECT returned **zero rows**, so the INSERT inserted nothing and threw nothing — the
test "passed the forgery attempt" by doing nothing at all. `throws_ok` caught it because nothing
threw. Fixed by capturing the ids as postgres into a temp table first, so the employee's INSERT is a
real single-row attempt the policy must refuse on its own merits. This is precisely the failure mode
AGENTS.md §6 exists to prevent, and it is recorded rather than quietly corrected.

## TESTS

| Guard | Result |
|---|---|
| `48_document_storage_test.sql` (new) | **12/12** |
| `47_payment_proof_lifecycle_test.sql` (extended for SPP-1/SPP-2) | **19/19** |
| Suite | **48 files / 541 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` (73 tables, 69/593 catalog) |

Decisive assertions: the owner can see an object **because** they can see its version row; the
employee provably **cannot see the version row** and therefore cannot see the object — one mechanism,
not two; all nine `document_links` branches survive the policy rewrite (the §17 guard, since a
dropped branch is a regression even when the new branch works); no UPDATE or DELETE policy exists on
`storage.objects`; the employee can no longer read the agency's payment history nor forge a proof.

## CROSS-PATH REVIEW

* **Storage policies are additive** — `storage.objects` had **0** policies (fail-closed), so nothing
  that previously worked could break; the change can only widen from "nobody" to "the document's
  authorized readers".
* **`document_links` policy rewrite** — the highest-risk edit in the session. Mitigated by
  transcribing all nine branches verbatim and pinning them with a structural assertion.
* **`subscription_payment_proofs` policy rewrite** — checked against every writer:
  `app.upload_subscription_payment_proof` is SECURITY INVOKER run by Owner/CEO, who hold both new
  permissions; `app.platform_review_payment_proof` is SECURITY DEFINER and runs as the owner, so the
  Platform Owner keeps reviewing proofs it could never read as a tenant user — the intended
  asymmetry, not a hole. Test 35's exemption fixtures run as postgres and are unaffected.
* **No batch, cron or n8n path** touches documents, storage or payment proofs — `cron.job` holds two
  entries (lead SLA, subscription lifecycle) and n8n has **0 workflows**.

## ENVIRONMENT

* **Supabase/local/Primary:** all at **137 migrations**, fingerprint
  `e126307a4df8738ab20744990a3a5739`. Parity CLEAN (local proven; primary proven).
* **Primary live re-read:** bucket `documents` exists and is **private**; **2** storage policies
  (select + insert, none for update/delete); 3 policies on `subscription_payment_proofs`; 1 on
  `document_links`.
* **n8n impact:** none — 0 workflows; no contract changed.
* **GitHub impact:** commit and push below.

## ITEMS INTENTIONALLY NOT FIXED, each with its reason

* **WP-04-D — retention, deletion, recovery and orphan reconciliation.** Deliberately not improvised
  here. An object upload happens *after* the metadata transaction and cannot be rolled back by it, so
  an orphaned object (metadata rolled back, bytes written) or an orphaned metadata row (bytes never
  arrived) are both possible. Reconciliation needs a scheduled sweep and a documented retention rule;
  the retention period itself is a **BLOCKED — BUSINESS DECISION** (Egyptian record-keeping
  obligations for travel documents are not in canon).
* **PP-1 — `subscription_payment_proofs.reviewed_by` references `public.users`,** which holds only
  tenant users, so a Platform Owner reviewer cannot be recorded there. Left NULL and audited via
  events. **BLOCKED — ARCHITECTURAL DEPENDENCY:** resolving it means dropping the column or
  repointing it at a platform identity, and no platform-identity table exists.
* **`suppliers.credit_limit_amount` readable by `authenticated`** — **BLOCKED — BUSINESS DECISION**;
  it is the agency's commercial terms with a supplier, not an employee's private margin, and no canon
  evidence settles whether frontline staff should see it.
* **Signed-URL generation and download flow** — a client/API concern (`createSignedUrl`), not a
  database one. The database boundary is proven; nothing to implement server-side until a client
  exists.

## BUSINESS DECISIONS STILL REQUIRED

**BLOCKED-4** (commission after booking-item reassignment) · **BLOCKED-5** (may a trial ever be
re-granted) · **CANON-26-1** (may an ACTIVE tenant be suspended in one step) · **PLAN-1** (three
undefined "Limited" plan ceilings) · **document retention period** (new) ·
**`suppliers.credit_limit_amount` visibility**.

## EXTERNAL DEPENDENCIES

**LIC-1** — a refused licence redemption is not audited, because `raise` rolls back its own audit row
and PostgreSQL has no autonomous transaction. Unchanged.

## NEW RISKS

Storage now exists on Primary, so from this point an orphaned object is physically possible. Nothing
uploads bytes yet (no client), so the window is not open in practice — but WP-04-D should land before
any client does.

## PLAN / GAP REGISTER / GOVERNANCE CHANGES

`MASTER_EXECUTION_PLAN.md` Batch 6: WP-04-C marked done with the provider decision recorded, and
**WP-04-D** defined. `MASTER_GAP_REGISTER.md` gains **PP-2**, **SPP-1/SPP-2** as resolved.
`manifest.md`, `reports/README.md`, `ai-map.json` synchronized. No guard budget was raised and no
history deleted.

## STATUS SUMMARY

* **FIXED:** PP-2, SPP-1, SPP-2, storage provider selected and implemented, one vacuous test of mine.
* **IN PROGRESS:** none — WP-04-C is complete.
* **BLOCKED:** PP-1 (architectural), LIC-1 (external), retention period + supplier credit visibility
  (business), BLOCKED-4/5, CANON-26-1, PLAN-1.
* **UNPROVEN:** end-to-end byte upload and signed-URL download — no client exists to exercise them;
  the database boundary is proven, the HTTP path is not.
* **INTENTIONAL:** no UPDATE/DELETE policy on `storage.objects`; `reviewed_by` left NULL.

## NEXT LOGICAL WORK PACKAGE

**WP-04-D — document retention, deletion, recovery and orphan reconciliation.**

**Acceptance criteria:** a scheduled reconciliation identifies metadata rows with no object and
objects with no metadata row, per-tenant and skip-never-raise (the WP-03 shape); archival and
deletion are `service_role` lifecycle operations that emit `document_archived` and leave an audit
trail; superseded versions remain retrievable for the retention window; the retention period is
recorded as a business decision rather than guessed; and cross-tenant reconciliation is proven not to
touch another tenant's objects. After it, the whole-system post-WP-04 discovery pass resumes.
