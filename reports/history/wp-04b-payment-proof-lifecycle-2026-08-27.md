# ORVION — WP-04-B: The Subscription Payment-Proof Lifecycle, and the Narrowed Document Gate

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: Migration `202607054500`. Makes the subscription renewal-proof journey executable end to end,
and replaces WP-03's blanket document exemption with the narrow rule canon 28 always specified.

Predecessor: `wp-04a-document-write-integrity-2026-08-27.md`.

> **Written for a reader who knows nothing about ORVION.** ORVION is a multi-tenant travel CRM built
> Supabase-native (SQL migrations plus `app`-schema RPCs). Tenants are travel agencies. A tenant's
> commercial subscription has seven states; when it lapses to `read_only` the tenant may still read
> and export its data but may not write. The one exception canon has always specified is that a
> lapsed tenant must still be able to upload proof of a bank transfer so the Platform Owner can
> reactivate it — otherwise a lapsed tenant is trapped with no way back.

---

## 1. OBJECTIVE

Implement the payment-proof capability as a **complete business lifecycle**, not a catalog value —
and then narrow the document exemption that WP-03 had to leave wide open until this existed.

## 2. STARTING STATE (re-proven live, not carried from the previous report)

| | |
|---|---|
| Starting commit | `45a9463` |
| Starting migrations | **133**, fingerprint `721d571fb9fa7fdbc7e79f4d91eb0e87` |
| `payment_proof` document type on Primary | **0** — DOC-2 genuinely still open |
| Subscription-gate triggers on the three document tables | **0** — exemption genuinely still blanket |
| `storage.buckets` | **0** |
| `upload_document` still takes `p_storage_path` | **no** — WP-04-A confirmed live on Primary |
| Guards | repository CLEAN · parity CLEAN (local proven; primary proven) |

## 3. DISCOVERIES — the capability was broken in five places, not one

The previous pass recorded "no `payment_proof` document type". Re-introspection found that was the
smallest of five layers:

1. **`document_type` has no `payment_proof`** — a mandatory business concept could only be filed as
   `other`.
2. **`subscription_payment` IS ALREADY a `document_link_target_type`**, but `app.upload_document` has
   no branch for it, so it falls through to `else false` and raises. The vocabulary was seeded and
   the code path was never written.
3. **`document_links.subscription_payment_proof_id` had no producer at all.**
4. **`subscription_payment_proofs.status_code` was unconstrained free text** — no catalog, no FK, no
   trigger. `'banana'` was a valid status.
5. **No review path existed**, so `REVIEW_SUBSCRIPTION_PAYMENT` — held by no role, correctly, because
   canon 28 makes review a *Platform Owner* action — had nothing to govern.

**The circular dependency.** `subscription_payment_proofs.document_id` is NOT NULL, so the proof needs
a document first; but `document_links.subscription_payment_proof_id` needs the proof id. Adding a
parameter to `upload_document` could not express this — that function returns after creating the
link, with no proof to link to. The only correct resolution is one transaction creating
document → version → proof → link in that order.

## 4. FIXED — `202607054500`

* **`payment_proof` document type**, and added to `app.is_financial_document_type`. That is a
  classification, not a new rule: it routes the type through the `documents` RLS branch
  `is_confidential AND VIEW_FINANCIAL_DOCUMENTS AND is_financial_document_type`, so Owner/CEO/Finance
  can read the company's bank transfer and a frontline employee cannot. Leaving it unclassified would
  have made it an ordinary linked document any employee could open.
* **`status_code` gains the catalog trigger** every other status column in ORVION already uses.
  **No new vocabulary was invented:** canon 26's approval machine is pending → approved / rejected /
  cancelled with rejected → pending for resubmission, and the catalog family `approval_status_code`
  already held exactly those four codes. Reused verbatim.
* **`app.upload_subscription_payment_proof`** — one transaction, four rows, resolving the circular
  dependency. Actor is `MANAGE_TENANT_SETTINGS` (Owner + CEO): canon 09 calls this actor "the tenant
  admin", and SPEC-158 already uses the same permission for redeeming a licence — same person, same
  commercial responsibility. `UPLOAD_DOCUMENT` was **rejected** as the gate because every operational
  role holds it, and the company's bank transfer is not frontline work. Uses `app.authorize` so MFA
  composes, since canon 28 requires TOTP for owner and ceo.
* **`app.platform_review_payment_proof`** — `service_role` only, per canon 28. Only a `pending` proof
  can be decided (canon 26), which also makes review **non-replayable**: a second approval is refused
  rather than silently re-activating a subscription again.
* **Approval and activation are separate but can be atomic.** A bank transfer does not itself say
  which plan or period it bought, so approving cannot infer terms. When the Platform Owner knows
  them they are passed and the subscription activates in the same transaction, delegating to
  `app.platform_activate_subscription` so the canon-26 transition check, the end-date derivation and
  the lifetime rule keep exactly one home. Canon 09 describes precisely this: *"The platform owner
  reviews the proof and activates renewal."*
* **The narrowed gate.** `app.enforce_document_subscription_gate` on `documents`,
  `document_versions` and `document_links`: if the subscription permits writes, allow; otherwise
  allow **only** when the row is, or belongs to, a `payment_proof` document. Canon 28's Read-Only
  Subscription Mode is the authority and already said this — *"Upload subscription renewal proof"*
  allowed, *"Upload business document"* blocked. It had simply never been enforced.

**Why the narrowing could not have come first:** it needs a discriminator. `payment_proof` is the
document type by which the gate tells a renewal proof from ordinary work. Sequencing §5 before §1
would have meant inventing a placeholder.

**Why a separate trigger name.** WP-03 attaches a *generated* `..._enforce_subscription_write_gate`
to 42 tables via an exemption list. These three tables stay off that list and gain a **specialised**
gate under a different name, so WP-03's coverage test still reads true in both directions — every
non-exempt table carries the generated gate, and no exempt table carries it.

## 5. ATOMICITY — stated honestly

Everything above is one PostgreSQL transaction, so a failure at any step leaves no half-created
document, no orphan proof and no orphan link. **That guarantee covers the metadata only.** When an
object store is added (WP-04-C), the binary upload will sit *outside* this transaction and no
database transaction can roll it back — an orphaned object is possible and must be reconciled by the
storage package. The migration says so in its own header rather than implying a guarantee that does
not exist.

## 6. TESTS

| Guard | Result |
|---|---|
| `47_payment_proof_lifecycle_test.sql` (new) | **16/16** |
| Suite | **47 files / 526 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` (73 tables, 69/593 catalog) |

The tenant under test is deliberately `read_only`, because that is the only state in which this
feature matters. Decisive assertions:

* a `read_only` tenant **can** upload its renewal proof — creating a pending proof against a
  confidential `payment_proof` document, and populating the link that had no producer;
* the **same** lapsed tenant, in the **same** session, **cannot** create an ordinary passport
  document — via the RPC *or* by direct DML;
* reads of what it already has remain available;
* the tenant admin, proven able to **see** its own proof, still changes nothing when it tries to
  approve itself;
* no tenant user may execute the review function at all;
* the Platform Owner approves and reactivates in one call — `approved:active:annual`;
* reviewing an already-approved proof is **refused**, so approval cannot be replayed.

## 7. REGRESSION FOUND AND CORRECTED — in a test, and it was the right kind

`35_subscription_write_gate_test.sql` assertions 15–17 failed on the first full run. Cause: its
fixture created the proof's document with `document_type_code = 'other'` and the title *"Renewal
payment proof"* — a **stand-in**, written when no `payment_proof` type existed, that quietly
documented DOC-2. The exemption it exercised was blanket, so any type passed.

The fixture was corrected to use the real type. That is not weakening a guard to make a suite green:
the test now says what it always meant, and `47_payment_proof_lifecycle_test.sql` asserts the other
half — that an ordinary document from the same lapsed tenant is refused. The old fixture would now
pass only because the gate was blanket, which is exactly the defect this package removed.

## 8. CROSS-PATH SWEEP

Asked of the catalog, not inferred:

* **Trigger inventory after the change** — `documents`: emit_superseded, archive_authority,
  catalog_codes, **document_subscription_gate**, set_updated_at; `document_versions`: catalog_codes,
  **document_subscription_gate**, integrity; `document_links`: **document_subscription_gate**;
  `subscription_payment_proofs`: **catalog_codes**. Exactly as designed, nothing displaced.
* **Every function touching these tables**: `upload_document`, `add_document_version`,
  `archive_document`, `expiring_documents`, `financial_documents`,
  `upload_subscription_payment_proof` — all **SECURITY INVOKER**. The only two DEFINER functions are
  the new gate itself and `platform_review_payment_proof` (service_role only).
* **No batch, scheduled or multi-tenant path touches documents** — `cron.job` holds two entries (lead
  SLA, subscription lifecycle) and neither does. A **raising** trigger is therefore correct here:
  this is a single-tenant interactive write path, not a WP-03-shaped batch where one tenant's refusal
  could abort another's run.
* **Behaviour change worth recording:** `archive_document` is INVOKER and updates `documents`, so a
  lapsed tenant can no longer archive a non-proof document. That is correct — canon 28 blocks
  "Change operational statuses" in read-only mode — but it is a real change, so it is written down
  rather than discovered later.
* **`is_financial_document_type` changed**, and its callers are the `documents` RLS policy and
  `app.financial_documents`. The change affects only rows of type `payment_proof`, which did not
  exist before, so no existing row's visibility moved. `28_document_scope_test` passed unchanged.

## 9. DEPLOYMENT, PRIMARY VERIFICATION, PARITY

Applied to Primary and reconciled from the `apply_migration` version stamp to `202607054500`. Primary
re-read live rather than assumed:

```
migrations = 134   pp_type = 1   doc_gates = 3   pp_is_financial = true
svc_review = true  auth_review = false           auth_upload = true
```

`DATABASE PARITY: CLEAN (local proven; primary proven)` — repository, local and Primary all at
**134 migrations**, fingerprint `198ff244ecdd84c14c14059a067f637e`.

## 10. NOT FIXED — recorded with IDs, none hidden in prose

* **PP-1 — `subscription_payment_proofs.reviewed_by` cannot hold the reviewer.** The column
  references `public.users`, which contains only **tenant** users; a Platform Owner is not one. Any
  value written there would be a lie, so platform reviews leave it NULL and the reviewer is recorded
  in the event and in `security_events` instead. **Classified: INTENTIONAL BY DESIGN, with a
  schema-level correction owed** — the column is modelled for a tenant-side reviewer that canon 28
  says does not exist. Resolving it means either dropping the column or repointing it at a platform
  identity, and platform identity has no table today.
* **PP-2 — `document_links` RLS has no branch for `subscription_payment_proof_id`.** The insert
  succeeds only because `has_tenant_wide_read()` (VIEW_ALL_BRANCHES = Owner + CEO) is exactly the
  role set holding `MANAGE_TENANT_SETTINGS`. That coupling is real but implicit: granting
  `MANAGE_TENANT_SETTINGS` to a role without `VIEW_ALL_BRANCHES` would break proof upload with a
  confusing RLS error. Not fixed here because rewriting a live RLS policy to add one branch is the
  high-risk change the directive's §17 warns about, and the policy has eight existing branches that
  would all need re-proving. **Classified: PLANNED — WP-04-C**, to be done with the storage policies
  when that file is being rewritten anyway.
* **`suppliers.credit_limit_amount` readable by `authenticated`** — unchanged from the previous
  session. **BLOCKED — BUSINESS DECISION**: it is the agency's commercial terms with a supplier, not
  an employee's private margin, and no canon evidence settles whether frontline staff should see it.

## 11. BLOCKED

Unchanged: **BLOCKED-4**, **BLOCKED-5**, **CANON-26-1**, **LIC-1**, **PLAN-1**. New: **PP-1** (schema
correction owed, blocked on there being no platform-identity table), **PP-2** (planned, WP-04-C).

## 12. PLAN AND GOVERNANCE

`MASTER_EXECUTION_PLAN.md` Batch 6 extended: WP-04-B marked done with its five layers recorded, and
**WP-04-C** defined as the storage-provider evaluation plus the object-store implementation, now
carrying PP-2. `MASTER_GAP_REGISTER.md` gains **DOC-2** as resolved. `manifest.md`,
`reports/README.md` and `ai-map.json` synchronized. The manifest remains well under budget — the
pointer-not-restatement structure adopted two sessions ago continues to hold.

## 13. NEXT EXECUTABLE STEP

**WP-04-C — the storage-provider evaluation, then the object store end to end.** The evaluation
compares Supabase Storage, Google Cloud Storage, Google Drive and OneDrive/SharePoint on tenant
isolation, private objects, signed URLs, versioning, retention, deletion, recovery, backup,
encryption, access logging, auditability, size limits, performance, scalability, n8n integration,
operational complexity, cost and lock-in — with **fact separated from recommendation**, and cost as a
factor rather than the deciding one. One constraint is already evidence: every non-Supabase option
needs an external credential the owner must enter directly (AGENTS.md §6), which is a genuine
**BLOCKED — EXTERNAL DEPENDENCY** step for those options and must be weighed openly rather than
allowed to decide the outcome silently.

The object-key design is already settled and tested (`tenant/document/version`, tenant-first,
provider-independent), so whichever provider is chosen inherits a security model that is already
proven rather than one invented afterwards. WP-04-C also carries **PP-2**.
