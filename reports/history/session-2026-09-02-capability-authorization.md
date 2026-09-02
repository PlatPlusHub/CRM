# ORVION — RBAC-3 / ADR-0027: Capability Grants Become Per-User, and the Ceiling Gets Its Currency

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-02
Author: Claude Opus 5
Status: Complete. `202607059800` + `202607059900` applied to Primary `vrvtsxexkiiiivlkdxzp`; parity re-proven from Primary. SUP-4b deliberately left open.

---

## AUTHORIZATION ARCHITECTURE DECISION

### Verdict: **B — substantially REFACTOR the grant model; PRESERVE the enforcement plane.** Not Preserve, not Rebuild.

**Evidence from ORVION, measured before any opinion was formed:**

```
app.has_permission is resolved by   60 RLS policies
                                    61 triggers
                                    76 functions            = 197 enforcement sites
role_permissions is the ONLY foreign key into public.permissions
                                    72 permissions, 297 role grants, 9 roles
```

Those two numbers decide it. Every enforcement site in ORVION **already delegates the decision to one function**, so the owner's end-state is a change to how that function *resolves* a grant — not to how anything *enforces* one. And the entire gap to the end-state was a single missing edge: **there is no path from a user to a permission except through a role.** That one absence is what makes per-user grant, per-user revoke, deny, and "role as an overridable bundle" impossible.

**Why not Preserve.** Not a matter of taste: with only `role_permissions`, a per-user override is not awkward, it is *unrepresentable*. Every "this user, minus this one capability" would have to become a new role — the role explosion OWASP names explicitly. The model could not reach the owner's end-state at all.

**Why not Rebuild.** A rebuild would rewrite 197 enforcement sites to arrive at behaviour identical to today's, and each rewritten site is a chance to silently drop a rule that was *earned by a real defect* — SEC-1b, SEC-1c, PAR-4, BOOK-1, ADMIN-1, FIN-10, SUP-2. Maximum risk for zero security gain. A rebuild is justified when the thing being replaced is **wrong**; this one is **incomplete**, and nothing in the enforcement plane was found defective during the inventory.

### Evidence from current best practice

| Source | What it says | Effect on the decision |
|---|---|---|
| **Supabase RBAC** | permissions live in `role_permissions`, consulted at query time via a SECURITY DEFINER function used by RLS; the JWT carries only a **role reference** | ORVION already *is* this pattern, and is stricter — it resolves the actor from `public.users`, so a revocation binds on the next statement. **Permissions were deliberately NOT moved into custom claims:** doing so would *add* a revocation-latency window ORVION does not currently have |
| **PostgreSQL row security** | default-deny when no policy matches; PERMISSIVE combines with `OR`, RESTRICTIVE with `AND` | ORVION already runs default-deny on 75/75 tables; the plane needed no change |
| **PostgreSQL function security** | SECURITY DEFINER needs a safe `search_path` and no stray PUBLIC EXECUTE | Asserted structurally (test 92 assertion 3); the grant guard caught two real PUBLIC EXECUTE leaks during this work |
| **OWASP Authorization** | deny-by-default, least privilege, server-side only, ABAC preferred to RBAC to avoid role explosion | Deny-by-default and server-side already hold. The ABAC point is **answered without a policy engine**: ORVION is already a hybrid whose decision composes role + tenant + branch/department/assigned scope + plan entitlement + MFA level |
| **AWS IAM / Azure RBAC / Azure DevOps** | explicit deny overrides any allow | Deny-override **adopted verbatim rather than invented** |

### What the current model could and could not support

| Owner requirement | Before | After |
|---|---|---|
| capability-level permissions | ✅ 72 capability-keyed | ✅ unchanged |
| grant a capability to a user | ❌ **impossible** | ✅ |
| revoke it from a user | ❌ **impossible** | ✅ (`is_active = false`) |
| deny (override a role bundle) | ❌ **impossible** | ✅ deny-override |
| roles as overridable bundles | ❌ hard boundary | ✅ |
| View vs Manage | partial (naming convention only) | ✅ `action_kind`, enforced separately |
| capability groups for a dashboard | ❌ none | ✅ `capability_group`, derived from canon 28 |
| explain effective permissions | ❌ none | ✅ `app.effective_permissions` |
| server-side enforcement / RLS / DEFINER / direct table / PostgREST | ✅ already | ✅ **untouched** |
| tenant isolation, auditability | ✅ already | ✅ + first producer for `permission_granted`/`permission_revoked` |
| scopes | ✅ `scope_type` + ADR-0026 predicates | ✅ unchanged |

### Target model, and what was implemented now

`user_permission_grants` (user × permission × grant/deny), and `app.has_permission` resolving:

```
active DENY (user)  ->  refused, unconditionally
active GRANT (user) ->  held
role grant          ->  held
then, always        ->  the PLAN entitlement gate
```

The plan gate stays **last** for both paths, so a tenant administrator can never grant past a commercial entitlement — canon 28: *"Plan denial overrides user role permission."* That is the one thing a per-user grant must not be able to do, and it is asserted.

**Migration impact: nil for existing grants.** The table is additive; role grants behave exactly as before. **No privilege is expanded** — with the table empty, `has_permission` returns precisely what it returned before, and that is pinned as an assertion (test 92 #5, a set comparison against the role bundle) rather than asserted in prose.

**Security impact:** strictly narrowing options become available (deny), and one dead permission becomes live — `MANAGE_PERMISSIONS`, defined in canon 28, held by owner/ceo, and governing nothing at all until now (RBAC-2's class), is the administration gate for the new table.

**Dashboard impact:** grouping and View/Manage are **data, not code**, so the owner can regroup or rename from the dashboard without a migration. That matters immediately: canon files `ASSIGN_SUPPLIER` under *Booking* and `MANAGE_SUPPLIER_CREDIT` under *Finance*, while the owner thinks of both as "Supplier Management". That disagreement is now the owner's to settle, not code's.

**Intentionally deferred:** no policy engine, no ABAC/ReBAC, no external authorization service, no permission-to-JWT migration, and no scope column on a grant (ADR-0015 keeps permissions binary; ADR-0026's predicate remains how scope is expressed). Three permissions were left **ungrouped** rather than guessed.

---

## The owner's Supplier decision

`finance_manager` gains **`ASSIGN_SUPPLIER`** — expressed as a **role** grant, because the decision is about the role, and putting a role-level fact in the per-user layer is the duplicated-authority mistake this repository keeps finding. Measured first: `ASSIGN_SUPPLIER` gates exactly `app.create_supplier`, `app.link_internal_supplier`, and the `suppliers` / `internal_supplier_links` table doors — **nothing unrelated**.

Finance Manager's supplier capabilities are now `ASSIGN_SUPPLIER` + `MANAGE_SUPPLIER_CREDIT` + `VIEW_FINANCIAL_DOCUMENTS`. **No `VIEW_SUPPLIER` was minted**: `suppliers` is tenant-readable under `tenant_isolation`, so such a permission would be a *new restriction on every role*, not an expression of this decision.

---

## SUP-4 REPORT

**1. Authoritative exposure definition.** `app.supplier_balance` — cost from `booking_items` where `cost_locked_at is not null`, not archived, status not `cancelled`/`no_show`, minus `payments` with `payment_direction_code = 'supplier_payment'`; published by `reporting.supplier_outstanding`. This **is** authoritative for the supplier payable.

**2. Authoritative currency semantics — this is where the real defect was.** `supplier_balance` returns **one row per currency**; the ceiling was a **currency-less scalar**. Measured: **eleven** public tables carry a money amount, **ten** carry `currency_code` beside it, and `suppliers` was the only one that did not — against canon 30's explicit standard (*"Currency code should be stored separately"*, `not null`, referencing `currencies.code`). So the comparison was not *undecided*, it was **ill-formed**, and the cause was canon's own money standard unapplied to one column. **Fixed** (`credit_limit_currency_code`, FK + paired CHECK).

The comparison *form* was then settled by precedent, not by asking: `app.advance_booking` (ADR-0020) compares `customer_balance` **per currency, never converted**, which is why no exchange rate and no base currency were introduced. `tenants.default_currency_code` was measured to have a producer and **no consumer at all** and was deliberately not pressed into service.

**3. Operations governed by the ceiling — STILL OPEN (SUP-4b).** Locking a booking-item cost is the only existing event that raises `outstanding_payable`, but whether it should be *refused*, *warned*, or *overridden* is commercial. ADR-0020's shape needs an override permission, and canon 28 names none for supplier credit.

**4. Supplier scope — STILL OPEN.** Canon 25 registers `credit_limit` as a `supplier_payment_term` value and says nothing about it gating anything.

**5. Enforcement point.** For *who may set* the ceiling: two BEFORE row triggers on `public.suppliers`, so PostgREST, the RPC and any future client meet the same rule. For *the ceiling being exceeded*: **none — the ceiling is still not enforced.**

**6. Concurrency.** Nothing shipped here has a read-modify-write on an aggregate, so no race exists in what was delivered. For SUP-4b: ORVION's only existing financial ceiling (FIN-10) is a `CONSTRAINT TRIGGER … DEFERRABLE INITIALLY DEFERRED` doing an **unlocked aggregate re-read at commit** — that is the pattern to reuse, but it is a deferred re-read, **not a lock**. Whether two simultaneous commits can both pass is **UNPROVEN**; I did not reproduce it and am **not** claiming FIN-10 is defective. The package that builds enforcement must settle it rather than assume the deferral suffices.

**7. Every write path to `suppliers.credit_limit_amount`:** `app.create_supplier` · `public.create_supplier` (PostgREST) · direct `INSERT` · direct `UPDATE`/PATCH · session-less/platform (exempt by `auth.uid() is null`, canon 35 principle 6, **pinned by assertion**). No view, reporting function, scheduled job or integration writes it — confirmed by searching every `pg_proc` body and `pg_views` definition. All authoritative paths carry the same authorization.

**8. Tests** — below. **9. Remaining owner decisions** — SUP-4b's three. **10. Is the ceiling actually enforced? — NO, and that is stated plainly rather than implied.**

---

## Testing

**pgTAP 92 files / 1301 assertions**, Pass A and Pass B (Pass B under all six HTTP suites' residue). **HTTP 395, 0 failed.** Smoke `ALL CHECKS PASSED (76 tables …)`.

New — `92_capability_grant_model_test.sql` (26): capability isolation measured as a **set difference** (grant adds exactly one; deny removes exactly one); View vs Manage (an actor with Manage still cannot read the field, and gains no financial visibility); role bundles (individual grant adds, individual deny removes, deny beats a co-existing grant); revoke and expiry; the **plan gate surviving a per-user grant**; explainer agreeing with the decision function for **every** permission; no self-escalation; cross-tenant actor refused by the composite FK; and a PAR-4 injection that removes the deny row and flips behaviour back.

`91_supplier_credit_permission_test.sql` (26) and `90_…` (17, +2 for the canon-30 class guard) updated for the owner's decision.

**Mutation quality.** Every mutation asserts its own precondition before the behaviour is measured — the deny row is counted live before it is deleted; `has_permission` is echoed before and after each grant/revoke. Two mutation defects were found and fixed in this package, both of the same family:

- **Test 90's PAR-4 pair broke when SUP-3 added a second enforcement point** — dropping one guard on a credit-only write left the other, so the `lives_ok` failed and the paired `throws_ok` would have kept passing on the survivor **while measuring nothing**. Retargeted at a write where the credit guard is the sole refuser.
- **Test 92's own plan count disagreed with pgTAP's counter** — a final `rollback to savepoint` rolls back pgTAP's bookkeeping too, so `finish()` reported "planned 25 but ran 24" while every assertion passed. A mismatch that still prints `ok` is exactly the quiet wrongness this suite refuses; closed with the restore half.

---

## Regression: four class guards demanded justification, and one caught a real defect

| Guard | What it refused | Resolution |
|---|---|---|
| `14_tenant_qualified_fk_test` #1 | my `created_by` FK was **single-column to a tenant-scoped table** | **A real defect in my own table** — made composite per TENANT-1 |
| `verify_database.sql` CHECK 7 | `ON DELETE SET NULL` and a default `NO ACTION` | both changed to RESTRICT, the Referential Action Standard |
| `10_grant_model_test` #5/#7 | PUBLIC EXECUTE on two freshly-`CREATE`d wrappers (a drop takes the old revoke with it) | revoked explicitly |
| `10_grant_model_test` #6/#7, `35_…` #22, `83_…` #23, smoke CHECK 2 | the new writable table, the gate exemption, the actor column, the table count | each raised **with its justification recorded**, and `user_permission_grants.user_id` classified in the register **before** the assertion was edited, per that assertion's own rule |

The `suppliers` CHECK also rejected five test fixtures that set an amount with no currency — the constraint working on its first run.

---

## Primary parity

| | Primary | Local |
|---|---|---|
| ledger | `188 \| 0b98c574902c95689cf5111d6e39294f` | identical |
| functions | `b8a72aa22579faa9009c9d9aa0d0ec4d` (256) | identical |
| structure | `1fa67c9a20a59faf884c111b8059bcfe` (3,441 across ten surfaces) | identical |

Both migrations were transcribed to Primary through `apply_migration`; the matching **function hash independently confirms the text applied identically**. GUARD-1 recurred on both and both ledger versions were normalised.

---

## Migrations and canonical files changed

`202607059800_capability_grants_are_per_user_not_only_per_role.sql` · `202607059900_a_ceiling_with_no_currency_is_not_an_amount.sql` — both additive; no RLS policy, guard trigger or grant was altered by the first, and the second changes only the two supplier guards and the supplier RPC/reader.

Canon: **`28_permissions_matrix.md`** (amendment 5, where `VIEW_DEPARTMENT_RECORDS` is recorded) · **`31_schema_draft.md`** (the new column). Governance: **ADR-0027** · `MASTER_GAP_REGISTER.md` (RBAC-3, SUP-4a, SUP-4b) · `manifest.md` · `MASTER_EXECUTION_PLAN.md` · `reports/README.md`. **Canon 25 deliberately untouched** — its list is headed "Initial values" and two prior permissions were minted past it; `public.permissions` is the live registry.

---

## Remaining limitations

1. **The ceiling is still not enforced** (SUP-4b) — three commercial questions, stated above. `MANAGE_SUPPLIER_CREDIT` governs who may *set* it; nothing makes it *bind*.
2. **FIN-10's simultaneous-commit behaviour is UNPROVEN.** Flagged for SUP-4b's implementer, not claimed as a defect.
3. **Three permissions are ungrouped** — `ARCHIVE_RECORD`, `VIEW_ADVANCED_DASHBOARDS`, `VIEW_DEPARTMENT_RECORDS`. Canon 28 places none of them in a section; the dashboard should surface them as ungrouped rather than have code guess.
4. **`action_kind` is derived from a naming convention**, not from canon prose. It is right for all 15 `VIEW_*` keys, but it is an inference about intent and the owner may recategorise any of them from the dashboard.
5. **No UI exists.** Everything here is server-side; the dashboard is future work and this package only makes it expressible.
6. **`tenants.default_currency_code` still has a producer and no consumer** (DEAD-1's class), recorded during the SUP-4 measurement and deliberately not fixed here.
7. **Field-level visibility is not general.** The owner's end-state mentions sensitive fields; ORVION does this today with column grants plus a gated reader (`booking_items`, `booking_item_passengers`, `suppliers`), which is a per-field pattern rather than a generic mechanism. Nothing in this package changes that, and no requirement was found that needs it changed yet.
