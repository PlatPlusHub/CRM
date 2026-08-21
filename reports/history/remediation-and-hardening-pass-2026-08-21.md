# Remediation, Hardening & Governance Completion Pass — 2026-08-21

Class: **HISTORICAL-IMMUTABLE** (dated execution record; do not edit after this session — supersede with a newer dated report).
Type: **Non-canonical working record.** Owner-directed remediation pass executed immediately after `pre-workflow-ground-truth-audit-2026-08-21.md`, before the first n8n Workflow implementation. Not an ADR, not canon. The changes it describes are governed by `changes/SPEC-124-*.md` and `changes/SPEC-125-*.md`.
Method: the audit's findings were re-verified against current ground truth rather than trusted, then remediated under the `Inspect → Cause → Resolve → Implement → Verify → Cross-check → Govern → Re-verify → Evidence` loop. Every completion claim below rests on an independent check of the resulting state, not on the fact that a change was made.

**State at close: repository HEAD `8b01de3`, Primary at 91 migrations. No n8n workflow was created — `search_workflows` returns 0.**

---

## O. Final readiness decision

**`READY FOR FIRST N8N WORKFLOW`**

Nothing found in this pass blocks the workflow build. The ORVION-side pipeline is implemented, deployed and verified live; the repository, local stack and Primary agree on all 91 migrations by a shared ledger fingerprint; the full invariant battery passes on the production project, not only locally.

**One decision should be made before the first frontend, not before the workflow.** `SEC-1` — whether `authenticated` keeps direct table write access — does not affect n8n, which reaches the database only through four `SECURITY DEFINER` RPCs as a dedicated role holding no table privileges at all. It does affect the WeWeb question, and it becomes materially more expensive to change once a UI is built against it.

---

## A. Before → after

| Axis | Before | After |
|---|---|---|
| `anon` DML grants on public tables | 360 (72 tables × 5 privileges) | **0** |
| `authenticated` DELETE/TRUNCATE grants | 144 | **0** |
| Writable grants on the 10 reference tables | 20 | **0** |
| PUBLIC EXECUTE on `app` functions | 63 | **0** |
| pgTAP assertions | 28 (9 files) | **33 (10 files)** |
| Manifest cold-boot cost | 13,556 chars | **6,491 chars** |
| Mandatory `§2a` build corrections | 6 | **8** |
| Gap-register rows | 78 | **86** |
| Ledger verification method | row count (blind to version drift) | **md5 fingerprint, three-way** |
| Repo / local / Primary agreement | counts matched | **all three = `0cf2331ba21d412ba7925dbb1abe4fd1`** |
| Manifest leanness guard | lines only — passed while defect present | **lines + characters + per-line** |
| Topology guard (Check 8) | scanned whole file; false-positived | **scoped to §0** |
| Reference-data deferral | tracking row closed while work undone | **re-tracked as REF-1 with an explicit trigger** |
| Phase-8 integration surface | recorded as 5 RPCs | **corrected to the 4 that exist and work** |

---

## B. Disposition of every original audit finding

| Finding | Action | Evidence / verification | Status |
|---|---|---|---|
| **I1** — reference-data seeds undone, tracking row closed | Row re-scoped to track the seed half; registered as **REF-1** with an explicit trigger. **Not seeded.** | Live: `countries/nationalities/languages = 0`. The deferral is already governed by migration `202607045300`'s header; the defect was lost tracking, so restoring tracking is the fix | Tracking fixed |
| **I2** — manifest changelog + guard blind spot | Check 5 given character and per-line budgets; manifest trimmed | Guard observed **failing** on the untrimmed file (`13428 chars`, `line 28 is 5609 chars`), then CLEAN. 13,556 → 6,491 chars | Fixed |
| **I3** — workstation manifest stale | Every tool re-verified by executing it | Git 2.55.0.windows.4, Node v24.19.0, Docker 29.6.2, Python 3.12.10, PowerShell 7.6.5. Two unobservable values marked unconfirmed rather than restated | Fixed |
| **P1** — `catalog_type_code` has no FK to its registry | Registered as **CAT-1**, OPEN, with a named next action. **Not implemented.** | 0 orphan values today (569/569 resolve). SPEC-024 F1 recorded only that no canon *required* the FK — not a decision against it, so it is not closed as "intentional" | Open, tracked |
| **P2** — `moddatetime` in `public` | Closed as accepted risk on live evidence — **SEC-3** | `has_schema_privilege(…,'public','CREATE')` is `false` for all four roles, so the shadowing threat is unreachable; and 36 historical `create trigger` statements resolve the name unqualified, so relocating it would break replay | Accepted, evidenced |
| **P3** — `functional_role_code` unmarked near-duplicate | Canon marked superseded by `department_type`, retained not deleted | Its six values are an exact subset of the live, seeded, FK-referenced `department_type` | Fixed |
| **P4** — 101 registered events with no emitter | Confirmed by design; no change | Vocabulary seeded ahead of consumers per Fundamental Domain Structure. Only the Phase-8 pair is a real gap and was already PH8-6 | No action needed |

---

## C. Newly discovered during remediation

Eight issues the read-only audit did not find. Two were found by fixing something else; two were found by this pass auditing its own work.

### SEC-2 — `anon` held full DML on all 72 tables on live Primary — FIXED AND VERIFIED

Migration `202607043400` states two explicit decisions in its own header: **"anon: nothing (login required)"** and **"DELETE is intentionally withheld (archive-not-delete)"**. Live Primary contradicted both. `anon` held `SELECT/INSERT/UPDATE/DELETE` on all 72 public tables; `authenticated` held `DELETE` and `TRUNCATE` on all 72 plus full DML on the ten platform-managed reference tables.

The `authenticated` DELETE was *reachable*, not theoretical: the `tenant_isolation` policies are `FOR ALL`, so their `USING` clause permits DELETE of in-tenant rows. A logged-in user could have deleted their tenant's bookings, invoices, payments or passengers directly through PostgREST, in a system whose canonical convention is archive-not-delete.

**Root cause, verified rather than inferred:** Supabase's hosted projects carry a default-ACL entry granting ALL on tables created by `postgres` in `public`, so every `create table` in this repository silently inherited it. **This is the first defect class found here that `db reset` plus the smoke-test structurally cannot detect** — the local stack has no such default, so locally the grants already matched intent. Every prior verification was correct and still missed it.

```
before (Primary): pg_default_acl -> postgres | public | r | anon=arwdDxtm/postgres, authenticated=arwdDxtm/postgres
after  (Primary): anon_dml=0 · auth_delete=0 · global_writable=0 · audit_model=0 · public_execute=0 · auth_select=72
guard:            supabase/tests/10_grant_model_test.sql — 5 catalog-driven assertions, covers future tables automatically
```

Safety was established before the change, not assumed: **no `app.*` function issues `DELETE` or `TRUNCATE` anywhere**, no policy targets `anon`, and Primary holds zero tenants and zero users. The migration also revokes the default ACL so future tables cannot re-inherit it.

### SEC-1 — RLS scopes rows, not permissions — ESCALATED, NOT FIXED

Found while fixing SEC-2, and deliberately not fixed. `authenticated` holds `INSERT`/`UPDATE` on tenant tables by the conscious design of migration `202607043400` ("RLS scopes which rows"). But row-scoping is not permission-scoping: every write RPC enforces RBAC *inside* the function via `app.authorize()`, while the tables themselves stay directly writable.

A logged-in user holding ORVION's lowest role can therefore `PATCH` a booking's status, an invoice's total, or a booking item's cost straight through PostgREST — with no permission check, no state-machine validation, and no event emitted. The audit trail has no record, because events are written by the RPCs that were bypassed.

Changing this is an architectural decision with direct frontend consequences, so it is escalated rather than implemented. It is the write-side counterpart to the already-registered **AUDIT-3** (read-side scope).

### Remaining new findings

| Finding | What it was | Disposition |
|---|---|---|
| **Check 8 precision defect** | The topology guard's message claims it inspects `§0`; the code scanned the *whole file* for the word "unverified" and fired on §4's n8n *credential* language — a false positive about a different subject | **Guard scoped to §0.** Rewording the honest documentation to dodge the check was rejected as gaming it. Verified three ways: silent on the current file, **still fires** on "unverified" injected into §0, silent on §4 |
| **`apply_migration` ledger hazard** | The Supabase MCP tool stamps its *own* 14-digit timestamp as the ledger version instead of using the repository filename. Primary recorded `20260821123512` for a file named `202607050200`. Invisible to a row count — both sides read 91 | **Corrected on Primary; recorded as a required post-apply step.** Verification standard upgraded from counting to fingerprinting. Found by this pass re-auditing its own change |
| **DOC-1 — false capability claim** | The manifest and catalog recorded `record_offline_conversion` as executable by `orvion_integration`. It is `security invoker`, resolves tenant through `auth.uid()` and gates on `app.authorize()` — that role could never have run it. Its EXECUTE came only from the implicit PUBLIC grant | **Corrected.** The Phase-8 surface is **four** RPCs. Surfaced by SPEC-124's cross-check flagging an unexpected privilege loss, which was investigated rather than accepted |
| **Backlog "fully locked" claim** | Asserted `authenticated` had no DML and end-user clients "cannot access any table yet". Untrue in this repository's own migration `202607043400`, and further untrue on Primary | **Corrected** with both halves stated explicitly |
| **PH8-7 — `encoding` unset** | Data Manager API requires the request-level `encoding` field when uploading hashed `UserData`. The build spec mandates lowercase-hex digests but never says the request must *declare* HEX — a mismatch silently matches nothing while still returning success | Registered; mandatory `§2a` correction 7 |
| **PH8-8 — `fieldWarnings` ignored** | `IngestEventsResponse` returns row-level `fieldWarnings[]` on an HTTP-200. Acking a warned row as success marks a conversion permanently `sent`, and `claim_conversion_deliveries` excludes `sent` forever — the same permanent-loss shape as the `validateOnly` defect, through a different door | Registered; mandatory `§2a` correction 8 |
| **Process error (self-reported)** | The SPEC-125 commit was made while the consistency guard was failing. The command piped the guard through `\| tail`, so the shell reported *tail's* exit status, not the guard's | **Corrected in the next commit**, which gates on the guard's real exit code. History not rewritten, per `AGENTS.md §6` |

---

## D. Changes applied

| Commit | Change | Proof |
|---|---|---|
| `0376e38` | **SPEC-124** — migration `202607050200` restores the grant model, revokes the hosted default ACL, removes PUBLIC EXECUTE on `app`; new guard `10_grant_model_test.sql` | Local `db reset` 91 clean · smoke-test `ALL CHECKS PASSED` · 10 files / 33 tests PASS · applied to Primary and all five assertions re-verified live · smoke-test's ten invariants re-run live |
| `e30447b` | **SPEC-125** — 8 register rows; backlog corrections; canon supersede note; Check 5 three-axis budget; manifest trimmed; workstation re-verified; `§2a` corrections 7–8 | Guard shown failing on the pre-trim manifest then CLEAN · every workstation version obtained by executing the tool |
| `e500897` | Check 8 scoped to `§0` (precision defect) | Verified in three directions, including that detection power is retained |
| `8b01de3` | `apply_migration` ledger hazard + fingerprint verification standard | Three-way md5 agreement recorded |

One migration was written. No historical migration was rewritten, no schema object redesigned, no architecture changed, and no n8n workflow created.

---

## E. Deferred — genuinely, with governance

Nothing here was closed by relabelling it. Each has an owner, a reason and a trigger.

| ID | Why deferred | Trigger | Blocks Phase 8? |
|---|---|---|---|
| **REF-1** | The deferral was already governed at migration level and the referencing columns are nullable with no consumer. Seeding 249 ISO countries by hand ahead of any consumer fails Earn-It and risks transcription errors in data that only matters once something reads it | First UI/API path that must persist a real country, nationality or language | No — Phase 8 touches only `currencies`, which is seeded |
| **CAT-1** | Additive integrity improvement, zero current impact (569/569 resolve). Belongs in the next schema-touching CR rather than a migration written solely for it | Next schema-touching CR | No |
| **PH8-7 / PH8-8** | Both workflow-side; no ORVION code change exists to make | Applied when the workflow is built | No — they are build inputs |
| **SEC-3** | Closed as accepted, on a live privilege check rather than an assertion; relocating the extension would break historical migration replay | Re-open if any role gains CREATE on `public` | No |

---

## F. Decisions that require the owner

### SEC-1 — the write-path model

Three realistic options, in ascending strictness:

- **(a) Status quo** — keep direct `INSERT`/`UPDATE` with RLS. Cheapest, fastest to build a UI against, and what migration `202607043400` chose. Accepts that RBAC and the state machines are advisory for any client that talks to PostgREST directly.
- **(b) Hybrid** — reads stay direct (the reporting views and table reads are already the read model), writes go RPC-only by revoking `INSERT`/`UPDATE` from `authenticated`. Every write then passes `app.authorize()`, the state machine and event emission. This matches what ORVION has actually built: 63 RPCs already exist and already enforce all three.
- **(c) Full RPC** — reads also move behind functions/views. Strongest, most work, probably more than the domain needs today.

**Recommendation: (b)**, decided before the first frontend rather than after. The RPC layer already exists and already carries the rules; the only thing missing is closing the door that lets clients walk past it. Deciding after a UI is built means retrofitting every write path in that UI.

### Other open decisions

| ID | Decision needed | When |
|---|---|---|
| REF-1 | Seed scope (ISO 3166-1 / ISO 639-1), and whether `nationalities` reuses ISO alpha-2 codes with demonym names or a separate code set | At its trigger |
| PH8-2 / PH8-3 | Consent-denied operational surface; default-country-code policy for E.164 | Pre-go-live |
| AUDIT-2 | `feature_entitlements` seed — four enumerated sub-questions, all business policy | Subscription lifecycle |
| AUDIT-3 / AUDIT-4 | Employee-UI RLS scope; durable customer consent record | First UI / privacy review |
| C4 / C5 · A3 | Activation code, subscription grace; money-storage ADR | Pre-existing, unchanged |

---

## G. Governance, security & integrity improvements

**Governance.** Two guards were made able to see their own invariants — Check 5 now measures cold-boot cost in characters, not newlines; Check 8 now inspects the section its error message always named. Both were verified *failing* on the real defect before being verified clean; a guard proven in one direction only is not proven. Nothing important now lives in prose: REF-1 and CAT-1 existed only in a migration comment and an immutable historical report, and both are now in the findings SSOT, satisfying `GOVERNANCE.md §19`. Two false claims were removed from Living documents, each replaced with the true state and why the old one was wrong. Cold-boot cost was halved and is now mechanically prevented from regressing.

**Security.** `anon` reduced from full DML on 72 tables to none. `authenticated` lost `DELETE`/`TRUNCATE` everywhere, restoring archive-not-delete as an enforced property rather than a convention. The ten platform-managed reference tables are read-only again, so a tenant user can no longer mint a role, permission, plan, currency or country. PUBLIC `EXECUTE` was removed from all 63 `app` functions, 13 of which are `SECURITY DEFINER` — previously one accidental `grant usage on schema app to anon` away from mass exposure. The hosted default ACL is revoked, so this cannot silently recur on the next table.

**Data integrity & auditability.** The integrity layer was re-examined and found genuinely strong: 274 FKs with zero deviations from the Referential Action Standard, RLS on 72/72 tables, append-only triggers on both audit tables, and the SPEC-123 delivery lease verified in live source. The one real integrity gap found is CAT-1, registered rather than quietly fixed. The most consequential auditability finding is SEC-1 itself: events are emitted by RPCs, so any write bypassing an RPC is also invisible to the audit trail — an argument for option (b), and why the decision is worth making before a UI exists.

---

## K/L. n8n and Google Ads readiness

**Ready.** The backend contract is verified end-to-end on Primary: four `SECURITY DEFINER` outbox RPCs executable by `orvion_integration`, that role holding `app` schema USAGE, login enabled, and — confirmed by this pass — **no table privileges whatsoever**, the correct least-privilege shape, now enforced rather than incidental. The delivery lease, consent gate and `pending`/`sent` exclusion were read in live function source, not assumed.

**Google Data Manager API — current field contract confirmed 2026-08-21** against `developers.google.com/data-manager/api`. `IngestEventsRequest`: `destinations[]`, `events[]`, `consent`, `validateOnly`, `encoding`, `encryptionInfo`. `Event`: `transactionId`, `eventTimestamp` (RFC 3339, required), `userData`, `adIdentifiers` (`gclid`/`gbraid`/`wbraid`), `conversionValue`, `currency`, `conversionCount`. Response: `requestId`, `fieldWarnings[]`. Batch ceiling 2000 — far above the 50-row claim batch, so no chunking. `transactionId` is confirmed as the deduplication key, validating correction 4. Two new requirements became corrections 7 and 8. One operational fact: Google documents a **14-day trial period per conversion action during which value updates are disabled** — relevant because ORVION's five Conversion Actions are newly created.

**What remains unproven, and will stay unproven until first execution.** Only credential *existence* is agent-verified — 2 credentials, matching the recorded IDs. Each credential's target, the `datamanager` scope, and whether either actually authenticates cannot be checked read-only, because the n8n MCP exposes no credential-detail or credential-test capability. Neither has ever been observed to authenticate. This boundary was re-verified, not relaxed. Google Auth Platform remains in Testing status, so refresh tokens expire every 7 days until OAuth verification — a pre-go-live gate, not a build blocker.

---

## M. WeWeb assessment

**CONDITIONALLY RECOMMENDED** — conditional on resolving SEC-1 first, and on one compatibility test that must be run before committing. No migration was performed and no WeWeb work started; this is an assessment only.

WeWeb fits ORVION's architecture in shape: it is a front-end builder that talks to Supabase directly, keeps business logic in the database, and WeWeb's own documentation instructs you to "secure your data in Supabase RLS … so unauthorized users cannot retrieve protected records another way" — exactly ORVION's model. Sessions are managed by Supabase, so the JWT the isolation model depends on is in principle available. Nothing about WeWeb requires abandoning Supabase, the RPC layer or the RLS design.

**The decisive risk is not WeWeb — it is SEC-1 combined with WeWeb.** A client-side builder puts the anon key and the user's JWT in the browser. Whatever `authenticated` is permitted to do at the table level becomes directly exercisable by anyone who opens devtools, entirely bypassing the WeWeb UI. Under option (a) a tenant's own staff can rewrite bookings, invoices and costs with no permission check and no audit event. Under option (b) the same browser can only call RPCs that enforce RBAC. WeWeb is a reasonable choice under (b); under (a) it materially amplifies an already-open gap.

**One compatibility item must be tested, not assumed.** Community reports describe `auth.uid()` not resolving as expected in RLS policies under WeWeb, with `user_id` passed in the payload instead. Every one of ORVION's 76 policies resolves through `app.current_tenant_id()`, which is `where u.auth_user_id = (select auth.uid())`. If WeWeb does not propagate a genuine Supabase JWT on data requests, tenant isolation returns zero rows or behaves inconsistently. This is a one-hour spike — log in through WeWeb, call `app.my_memberships()`, confirm it returns the caller's memberships — and it should gate the decision.

**Boundaries that must remain server-side regardless:** all RBAC (`app.authorize()`), every state transition, all money math and journal entries, tenant resolution, the event log, and the Phase-8 outbox. WeWeb should render and call — never compute authority.

---

## N. Final ground truth

| Axis | State at close |
|---|---|
| Repository | Clean tree, no untracked files, no stash. HEAD `8b01de3` |
| GitHub | Synchronized — `git ls-remote` equals local HEAD; 0 commits unpushed |
| Migrations | 91 · repo = local = Primary, fingerprint `0cf2331ba21d412ba7925dbb1abe4fd1` |
| Primary schema | 72 tables · 0 without RLS · 274 FKs · 76 policies · 63 `app` functions, all `search_path`-pinned |
| Privilege model | anon DML 0 · authenticated DELETE/TRUNCATE 0 · reference tables read-only · PUBLIC EXECUTE 0 |
| Catalogs | 67 types / 569 values · 0 orphan values · 0 unregistered event or status literals in live source |
| Data | 0 tenants, 0 conversions, 0 deliveries — pre-production, as expected |
| Tests | 10 pgTAP files, 33 assertions, all pass after a clean `db reset`; smoke-test's 10 invariants pass on Primary |
| Consistency guard | `REPOSITORY CONSISTENCY: CLEAN`, with Check 5 strengthened and Check 8 made precise |
| Documentation | Manifest 63 lines / 6,491 chars · 86 register rows · no finding in prose only · no known false claim |
| Workstation | Re-verified by execution; unobservable values marked unconfirmed |
| n8n | 0 workflows, 0 executions, 2 credentials (existence only) |

**Honest limits of this pass.** Three things were assessed but not proven: the WeWeb `auth.uid()` behaviour (needs a live spike), the two n8n credentials' targets and scopes (not checkable read-only), and Google's exact enum spellings for `encoding` (must be confirmed against the docs at build time, as `§2a` already requires for the rest of the payload). Nothing in this report claims those as verified. One process error occurred and is reported in §C rather than omitted.

---

End of report.
