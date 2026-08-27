# ORVION — WP-04-A: Document Write Integrity

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: The first executable slice of WP-04 — making the document storage path system-derived and a
document version's identity immutable (migration `202607054400`), plus the whole-schema sibling audit
the continuation directive made mandatory.

Predecessor: `employee-performance-and-financial-lineage-2026-08-27.md`.

---

## 1. OBJECTIVE

Begin WP-04. The directive required the document/security lineage and a whole-schema audit for the
FIN-1 *class* of bug **before** any storage provider is chosen — and required that nothing
technically fixable be deferred. This slice delivers the parts that are **provider-independent**:
they are correct whichever object store WP-04 eventually selects, so they did not have to wait on
that evaluation.

## 2. STARTING ENVIRONMENT (re-proven, not carried over)

| | |
|---|---|
| Starting commit | `8c9e6d5` |
| Starting migrations | **132**, latest `202607054300`, fingerprint `a08dfe6c109937ab82932332d7944fd4` |
| Repository guard | CLEAN · Database parity | CLEAN (local proven; primary proven) |
| Tree | clean, `main` == `origin/main` |

Both ledgers were read live through MCP and both guards re-run. The previous report was used as a map
of what to inspect, never as evidence that it was still true.

## 3. THE WHOLE-SCHEMA SIBLING AUDIT (directive §14/§15) — and what it cleared

FIN-1 showed that one table can be protected while its sibling is not. The same class was searched
across the entire schema, by query rather than by reading:

| Class searched | Result |
|---|---|
| Sensitive columns readable by `authenticated` (cost / commission / margin / profit / credit / token / secret / password) | **Clean.** `cost_amount`, `commission_rate`, `cost_amount_override`, `token_hash` all unreadable. Only `booking_items.cost_locked_at` (a timestamp flag, not a money value) and `suppliers.credit_limit_amount` are readable — the latter recorded as a question, not silently accepted |
| Views bypassing RLS | **Clean.** All **8** `reporting` views are `security_invoker = true`; none runs as owner |
| Policies with `using (true)` | **10, all correct** — countries, currencies, languages, nationalities, catalog_types, permissions, roles, role_permissions, subscription_plans, feature_entitlements. Every one is platform-global reference vocabulary; `catalog_values`, which carries tenant rows, is properly scoped |
| SECURITY DEFINER without `search_path`, PUBLIC EXECUTE, single-column FKs into tenant-scoped tables, RLS tables with no policy | **Clean** — each is already a permanent guard (`05`, `10`, `14`, smoke check 4) and all pass |
| Caller-supplied security-sensitive values in RPC signatures | **One real finding, below.** Every `p_tenant_id` is accounted for: `capture_attribution_click` (orvion_integration only), the four `platform_*` functions (service_role only), `record_event` (WP-00 pins a session-ful caller to their own tenant), `subscription_allows_write` (read-only predicate) |

The audit's value was as much in what it cleared as in what it found: five whole classes are now
proven closed by query rather than assumed closed by memory.

## 4. DISCOVERIES

### DOC-1 — the storage path was caller-supplied, on three paths (not one)

The prior discovery pass recorded `app.upload_document`. Re-introspection found **`app.add_document_version`
takes `p_storage_path` too**, and that `authenticated` holds **INSERT and UPDATE directly** on
`public.document_versions`. So the object key a document points at was chosen by the caller on three
separate paths.

Nothing bad happens today only because there is no storage: `storage.buckets` = 0 on Primary. The
moment a bucket exists, a caller can write a path under another tenant's prefix — and the ordinary
defence, a storage policy keyed on the first path segment, is defeated by the very value the attacker
supplied. This is a cross-tenant path designed in **before** storage exists.

### DOC-3 — a document version could be rewritten by direct DML

`app.add_document_version` does everything correctly — authorizes `CREATE_DOCUMENT_VERSION`, computes
the next version number, demotes the previous current version, updates `documents.current_version_id`,
emits the event. **Nothing forced anyone through it.** `document_versions` RLS admits any row whose
*parent document* is visible, and `authenticated` holds INSERT/UPDATE, so a user could insert a
version with an arbitrary `storage_path`, or UPDATE an existing one, with no permission check, no
sequencing and no event. An invoice, a passport or a payment proof could be made to point at a
different object while every reader still saw the same document id. That is the WP-00 audit-forgery
class, one domain over.

### A wrong assumption of mine, caught by the database

I intended to add a partial unique index making "two current versions" unrepresentable. Applying the
migration failed: `relation "document_versions_one_current_idx" already exists` — the original
document-core migration (`202607041900`) created exactly that index in the first place. **So the
one-current-version invariant was already enforced, and DOC-3 is narrower than the discovery pass
first read it:** an attacker could mis-point or rewrite a version, but never produce two current
ones. The index was removed from the migration and the correction written into it, because a wrong
assumption caught by the database is worth more to the next reader than a silent fix.

## 5. FIXED

**`202607054400` — WP-04-A.**

* `app.document_storage_path(tenant, document, version)` — one home for the object key, **tenant
  first**, so a storage policy can isolate on `(storage.foldername(name))[1]` whichever provider is
  chosen. Deliberately provider-independent, because that evaluation is not yet decided.
* **No caller string enters the object key at all.** The human file name stays in
  `document_versions.file_name` where it belongs; the key is opaque and structural. That removes path
  traversal, unicode normalisation and extension spoofing from the *design* rather than trying to
  sanitise them.
* `app.enforce_document_version_integrity()` — a trigger, because direct DML was the unguarded path
  and the RPC was never the problem. On INSERT it **derives** `version_number`, `storage_path` and
  `uploaded_by`, discarding whatever the caller sent — that discarding is the security property, the
  same shape SPEC-155 uses for `commission_rate` and WP-00 for the event actor. On UPDATE it freezes
  the identity columns; `is_current` is deliberately *not* frozen, because `add_document_version`
  legitimately demotes the previous version and the pre-existing unique index keeps that honest.
* Direct DML now costs the same permission the RPC always charged (`CREATE_DOCUMENT_VERSION`).
  Verified against the live seed first: **every role holding `UPLOAD_DOCUMENT` also holds
  `CREATE_DOCUMENT_VERSION`**, so this adds no barrier to any legitimate upload.
* Both RPCs lose `p_storage_path`, via `drop` then `create` — `create or replace` with a shorter
  argument list would have left the old signature callable as a second overload **still accepting a
  caller-supplied path**, which is the entire defect (the SPEC-156 lesson).

## 6. TESTS

| Guard | Result |
|---|---|
| `46_document_write_integrity_test.sql` (new) | **14/14** |
| Suite | **46 files / 510 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` (73 tables, 69/591 catalog) |

The decisive assertions are the ones where a caller **supplies** a path and it does not survive:

* a direct INSERT naming **another tenant's** storage prefix and version number `99` is *accepted* —
  and neither the foreign prefix nor the `99` survives; both are derived (`.../3`).
* repointing an existing version at another object → **refused**; renumbering it → **refused**.
* `uploaded_by` is taken from the session, so attribution cannot be forged either.
* a **trainee**, proven to genuinely lack `CREATE_DOCUMENT_VERSION`, is refused a direct INSERT —
  the RPC is no longer the only thing charging for it.
* the honest path still works end to end, and the derived key is exactly `tenant/document/version`.

## 7. REGRESSIONS

None. All 45 pre-existing files passed unchanged, including `28_document_scope_test`,
`33_archive_authority_test` and `38_class_a_events_test` — the three that exercise documents most
heavily. Their fixtures insert `document_versions` directly as postgres with explicit paths; the
trigger's session-less branch preserves those, which is why the service_role/migration path is
exempted exactly as every other guard here exempts it.

## 8. CROSS-PATH SWEEP

Asked of the catalog, not inferred: **exactly three functions** touch `document_versions` or
`storage_path` — `upload_document`, `add_document_version` and the new trigger function — and **all
three are SECURITY INVOKER** (`prosecdef = false`), so no definer path bypasses the guard.
`document_versions` carries exactly two triggers (catalog codes, then integrity). No view, batch,
scheduled job or n8n path touches the table. No RLS policy was altered, so no policy branch could be
dropped (directive §17).

## 9. DEPLOYMENT AND PARITY

Applied to Primary and reconciled from the `apply_migration` version stamp to `202607054400`. Primary
re-read live: **2** document RPCs (one signature each, no stale overload) and **2** triggers on
`document_versions`. `DATABASE PARITY: CLEAN (local proven; primary proven)` — repository, local and
Primary all at **133 migrations**, fingerprint `721d571fb9fa7fdbc7e79f4d91eb0e87`.

## 10. NOT FIXED / STILL OPEN — with reasons, none hidden

* **DOC-2 — the payment-proof path, and it is deeper than the catalog.** Re-introspection found three
  layers, not one: the `document_type` catalog has no `payment_proof` value; **`subscription_payment`
  IS already in the `document_link_target_type` catalog but `app.upload_document` has no branch for
  it**, so it falls to `else false` and raises; and `document_links.subscription_payment_proof_id`
  cannot be populated by any code path. There is also a circular dependency —
  `subscription_payment_proofs.document_id` is NOT NULL while the link row needs the proof id — which
  means the fix is a dedicated transactional RPC, not another parameter on `upload_document`. That is
  WP-04-B, specified in the plan, not deferred.
* **§7, the subscription-gate exemption.** Confirmed live: **zero** gate triggers on `documents`,
  `document_versions`, `document_links`, so a suspended tenant can create *any* document, not merely
  a renewal proof. Narrowing it depends on `payment_proof` existing as a type — it is the mechanism
  by which the gate can tell a renewal proof from an ordinary document — so it belongs in WP-04-B
  with DOC-2, and doing it first would have meant inventing a placeholder discriminator.
* **`suppliers.credit_limit_amount` is readable by `authenticated`.** Recorded rather than changed:
  it is the agency's commercial terms with a supplier, not an employee's private margin, so SPEC-139's
  rationale does not obviously extend to it. Whether frontline staff should see supplier credit limits
  is a business question, and no evidence in canon settles it.

## 11. BLOCKED

Unchanged: **BLOCKED-4**, **BLOCKED-5**, **CANON-26-1**, **LIC-1**, **PLAN-1**. No new blockers. The
storage provider evaluation is **not** blocked — it is the next design step, and this slice was built
to be correct regardless of its outcome.

## 12. PLAN AND GOVERNANCE

`MASTER_EXECUTION_PLAN.md` Batch 6 extended (never replaced): WP-04 split into **WP-04-A (done)** and
**WP-04-B**, with DOC-2's three layers and the gate narrowing specified from evidence.
`MASTER_GAP_REGISTER.md` gains **DOC-1/DOC-3** as resolved. `manifest.md`, `reports/README.md` and
`ai-map.json` synchronized. The manifest stays under budget without further trimming — the
pointer-not-restatement structure adopted last session is holding.

## 13. NEXT EXECUTABLE STEP

**WP-04-B — the subscription payment-proof path, end to end, and the narrowed subscription gate.**
Concretely: add the `payment_proof` document type (and to `app.is_financial_document_type`, since a
bank transfer receipt is a financial document); add `app.upload_subscription_payment_proof` as a
single transactional RPC that resolves the circular dependency between `documents`,
`document_versions`, `subscription_payment_proofs` and `document_links`; add the platform-side review
that transitions the subscription and emits `subscription_payment_approved` / `_rejected`; then
replace the blanket document exemption with a gate that permits **only** the renewal-proof path for a
`read_only` / `expired` tenant, exactly as canon 28's read-only mode allows. The storage provider
evaluation follows, and the object key it will use is already settled and tested.
