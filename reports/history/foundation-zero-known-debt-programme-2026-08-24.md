# ORVION — Foundation Completion, Hardening & Zero-Known-Debt Programme

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-24
Author: Claude Opus 5
Scope: Owner directive of 2026-08-24 (third directive)
Evidence: this session's work only. Local database only — see §10.

---

# 15. FOUNDATION FREEZE STATUS

# FOUNDATION FREEZE — NOT EARNED

**One blocker remains, and it is not an engineering one.**

Both blockers recorded at the previous gate are addressed. The lifecycle-bypass blocker is closed
(SPEC-149). The Primary blocker is not, and cannot be closed from here.

---

# 1. What was inspected

Repository, HEAD, working tree, branch, remote, push state. The boot chain as a fresh agent follows
it. Canon, manifest, roadmap, gap register. MCP configuration and **all three** Primary access paths.
Local Supabase stack and migration ledger. Live database: grants, policies, triggers, functions,
indexes, catalogs, reference data, DELETE privileges, archive columns. Every `advance_*` RPC's
transition map, extracted from `pg_proc`. The `orvion_integration` contract. Google Cloud SDK
environment. Consistency and smoke guards.

---

# 2. What was discovered

Defects **not** in any previous report:

| # | Finding | Severity |
| --- | --- | --- |
| D1 | **Lifecycle transitions were decorative on the direct path.** Reproduced: an employee **without** `ISSUE_BOOKING` ran `update bookings set booking_status_code='issued'` and the booking went `draft → issued`, skipping pending_approval / confirmed / in_progress, with **zero events**, no authorization, no validation, no negative-balance check | **Critical** |
| D2 | **Archiving — which in ORVION *is* deletion — was ungoverned on 12 of 13 tables.** `authenticated` correctly holds no DELETE grant anywhere, which makes `is_archived` the removal mechanism. An ordinary employee archived a booking **and a customer** with plain SQL, `archived_by` left null, then un-archived the booking. Only `documents` had a governed path | **High** |
| D3 | **Transition logic is not confined to `advance_*` RPCs.** `app.assign_lead`, `app.record_lead_interaction` and `app.convert_lead` all move a lead's status. Found because the first transition registry, built from `advance_*` alone, failed test 24 immediately | **High** (methodological) |
| D4 | **`leads.owner_user_id` / `assigned_user_id` could diverge.** Every RPC set them together; nothing stopped a direct UPDATE moving one alone, after which "who is handling this lead?" has two answers | Medium |
| D5 | **The manifest asserted a stale ledger fingerprint and a parity claim that no longer held**, listed `reassign_lead` as outstanding after SPEC-140 delivered it, and carried a garbled CR list | Medium (governance) |

**How D2 was found is worth recording.** Every earlier pass audited DELETE grants, found none, and
concluded records were safe. The grant audit was correct; the conclusion drawn from it was wrong. The
question that exposed it was *"if nobody can DELETE, what actually removes a record?"*

---

# 3. What was fixed

| CR | Migration | Substance |
| --- | --- | --- |
| SPEC-149 | `202607052700` | `app.status_transitions` registry (104 transitions, 10 tables) extracted from `pg_proc`; trigger enforcing **validity** (`23514`) and **authority** (`42501`) independently |
| SPEC-150 | `202607052800` | `ARCHIVE_RECORD` permission; trigger on all 13 `is_archived` tables authorizing in both directions and stamping `archived_at`/`archived_by` |
| SPEC-151 | `202607052900` | CHECK forcing `owner_user_id` to mirror `assigned_user_id` |
| — | — | Manifest repaired (twice — see §5); canon 26 and canon 28 extended; smoke check 5g added |

---

# 4. What was tested

| File | Assertions | Subject |
| --- | --- | --- |
| `32_lifecycle_transition_test.sql` | 11 | The exact bypass; validity vs authority as separate failures; drift guard |
| `33_archive_authority_test.sql` | 9 | Employee cannot archive or restore; manager can; attribution stamped and cleared |
| `21`, `31` | fixtures | Rewritten to production-shaped assignment |

---

# 5. What was intentionally not changed, and why

| Item | Reason |
| --- | --- |
| The `advance_*` RPCs | They remain the author of the transition rules. The registry mirrors them and test 32 fails on divergence — rewriting them to read the registry would remove the independent second opinion the drift guard depends on |
| Revoking `authenticated` DML entirely | 35 tables still have no RPC; it would make those entities unusable |
| Detecting "did this come through an RPC" | Every signal available to a trigger is forgeable — `set_config` is public, and the RPCs are deliberately SECURITY INVOKER so RLS applies, which rules out `current_user` |
| Event emission on archive | Only 2 archive event types exist; covering the rest means minting 12 and would double-emit for `documents`. `archived_at`/`archived_by` carry the attribution instead |
| Dropping either lead user column | `assigned_user_id` is the authority; `owner_user_id` completes the ownership triple the scope model reads across 8 tables. Removing it would make `leads` the one exception |
| `ASSIGN_SUPPLIER` split into a `CREATE_SUPPLIER` | Verified: `app.create_supplier` and `app.link_internal_supplier` both authorize `ASSIGN_SUPPLIER`. Canon names no `CREATE_SUPPLIER`. The precedent holds |
| `MANAGE_ROLES` / `MANAGE_PERMISSIONS` enforcement points | The three RBAC catalog tables grant `authenticated` **SELECT only** — no writable surface to guard. Stronger than a permission check |

**A mistake, recorded rather than buried.** SPEC-150 was committed while
`check_repository_consistency.ps1` reported 2 issues — the exact thing AGENTS.md §4 step 8 forbids.
The failures were real (manifest bloat: 7028 chars against a 7000 budget, one line at 1246 against
1200, because the next-capability field had become a changelog). Corrected in the following commit
(`f3d90d3`), which says so.

---

# 6. Re-verified from §42, closed

| Item | Result |
| --- | --- |
| Archive/delete policy | **VERIFIED** — `authenticated` holds DELETE on **zero** tables |
| `approval_requests` dual representation (REL-2) | **VERIFIED** — two CHECK constraints make the polymorphic pair and the typed FK unable to disagree |
| `nationality_code` / `passport_issuing_country_code` | **VERIFIED** — both ISO alpha-2, 82 rows each, directly comparable |
| `ASSIGN_SUPPLIER` semantics | **VERIFIED** — governs creation and linking; no new permission warranted |
| Role self-escalation | **VERIFIED** — test 22 |
| Document privacy, finance write bypass, cost lock, plan gating, branch isolation, department continuity, financial privacy | **VERIFIED** — tests 21, 23, 28, 29, 30 |

---

# 7. Integration readiness

**n8n.** `orvion_integration` holds EXECUTE on exactly the four workflow RPCs, `USAGE` on `app` and
`public`, and **zero table grants**. The role is `nologin` in migrations by design — LOGIN was enabled
manually on Primary so the password never entered the repository (Integration Catalog §3.3). That is
correct practice, and the repository already documents it.

**Google Ads / Google Cloud.** SDK 580.0.0; project `orvion-data-manager`;
`datamanager.googleapis.com` **ENABLED**; authenticated account present. Matches the documented
assumptions; no stale assumption found. No workflow created, no conversion data sent.

---

# 8. Remaining items

## BLOCKER

- **Primary carries none of this work and cannot be reached.** `supabase-primary` MCP disconnected;
  `supabase/.temp/project-ref` absent; `SUPABASE_ACCESS_TOKEN` unset. All three checked, not assumed.
  Primary is **16 migrations behind**. Requires interactive re-authorization (`/mcp` or `claude mcp`).

## REQUIRED BEFORE FREEZE

- **Column-by-column sweep of all 72 tables.** Performed across the security, lifecycle, archive,
  duplicate-prevention, vocabulary and reporting dimensions — not yet exhaustively per column.
- **Employee 360 / Supplier 360 / Branch 360 read primitives.** Customer 360 and Lead 360 exist
  (`app.customer_timeline`, `app.lead_timeline`, measured). The other three have no dedicated
  primitive; the data supports them, nothing packages them.

## FUTURE SCOPE

- Subscription-*state* gating (`read_only` write restriction) — canon 35 §8 keeps it distinct from
  plan gating.
- Numeric plan ceilings are readable (`app.plan_limit`) but nothing counts against them;
  `usage_counters` is empty and counting is a separate additive mechanism.
- Archive events per entity, if archive RPCs are built.

## BUSINESS DECISION

1. The three features canon marks **"Limited"** with no ceiling defined anywhere: Basic Reporting
   (Starter), Integrations and Offline Conversion (Professional). Seeded enabled and uncapped rather
   than guessed.
2. Whether `MANAGE_SUBSCRIPTION` stays platform-only. No role holds it; `subscriptions` is
   service-role-writable only. Canon 28 gives Owner/CEO "Limited".
3. Whether branch managers should see branch margins. Canon 28 marks `VIEW_FINANCIAL_DOCUMENTS`
   *Optional* for that role; not granted.

---

# 9. Security verification status

| Control | Status |
| --- | --- |
| Tenant isolation | **VERIFIED** behaviourally |
| Branch isolation | **VERIFIED** |
| Department continuity | **VERIFIED** |
| Employee financial privacy | **VERIFIED** |
| Document privacy (incl. travel vs financial split) | **VERIFIED** |
| Notification privacy | **VERIFIED** |
| Role self-escalation | **VERIFIED** closed |
| Plan gating (3 surfaces) | **VERIFIED** |
| Finance write authority | **VERIFIED** |
| **Lifecycle transition bypass** | **VERIFIED closed** (SPEC-149) |
| **Archive/delete authority** | **VERIFIED closed** (SPEC-150) |
| Access revocation (leave / expire / role off) | **VERIFIED** |

---

# 10. Local, repository and Primary state

| Metric | Value |
| --- | --- |
| Local migrations | **118**, replay clean from empty |
| Ledger fingerprint (repo = local) | `5d3d4cbe27ec1ad5b75e9b4f91432eaa` |
| Test files / assertions | **33 / 296**, `Result: PASS` |
| Test files running as `authenticated` | **10** |
| Permissions | **66 of 71** enforced at a real check point |
| Smoke (`verify_database.sql`) | `ALL CHECKS PASSED` |
| Consistency guard | `CLEAN` |
| Working tree / push | clean, 0 unpushed |
| **Primary** | **UNVERIFIED — 16 migrations behind, unreachable** |

The 5 permissions without a check point: `MANAGE_ROLES` and `MANAGE_PERMISSIONS` (no writable
surface — stronger than a check); `ACCESS_API_FULL`, `ACCESS_API_READ_ONLY`,
`VIEW_ADVANCED_DASHBOARDS` (gate surfaces that do not exist yet, all plan-mapped so they deny
correctly the moment a consumer appears).

---

End of report.
