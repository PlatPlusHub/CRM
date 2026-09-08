# Batch 6 slice 11 — bootstrap blocked on Primary access

Class: History (immutable)
Date: 2026-09-09

## 0. HANDOFF

- **INHERITED** — Slice 10 at `6bc14f3f00253bceea27c950cc8cae801f7e7a1c`; Slice 11 targets `customers`. The prior report is `session-2026-09-08-batch6-slice10-invoices.md`.
- **PROVEN** — fetched origin/main equals HEAD; initially clean tree; 209 migration files; local ledger and measured hashes match the recorded baseline; repository consistency CLEAN, Checks 1–25; selector ranks customers first, exposure 17.
- **UNPROVEN** — live Primary identity, ledger, functions, structure and parity; reset-derived local baseline; current behavioral/HTTP results; full decision reconciliation; customer adversarial assurance.
- **CHANGED** — documentation only: this report, the latest-session pointer, manifest access status and generated ai-map. The containing git commit identifies this handoff; no migration or product repair.
- **REMAINING** — the entire Slice-11 adversarial audit and its verification protocol, after Primary access is restored. Coverage remains 11/77; customers stays NOT-RECORDED.
- **DO NOT TOUCH** — Secondary; database state to compensate for missing access; CUST-3 as a new business question; later slices. No cloud-to-local overwrite.
- **NEXT** — restore callable Primary access for `vrvtsxexkiiiivlkdxzp`, prove project identity and all three parity values live, then resume Slice 11.

## 1. DISCOVERED

This is a blocked bootstrap, not a completed customer audit. The available account-level Supabase MCP denied both read-only calls:

1. `supabase_get_project_url(project_id=vrvtsxexkiiiivlkdxzp)`.
2. `supabase_execute_sql` on that project, querying only migration count, latest version and ledger fingerprint.

Both returned `ProtocolError: MCP error -32600: You do not have permission to perform this action` (`isError=true`). This proves a connector access failure, **not** a database outage or database divergence. No SQL result was returned from Primary.

`.mcp.json` names `supabase-primary`, `postgres-local`, `n8n` and `context7`. Only Context7 has callable dedicated tools in this session. Tool discovery found account-level Supabase tools, but no dedicated Primary, postgres-local or n8n tools. Configuration presence does not prove availability. `MASTER_INTEGRATION_CATALOG.md §0` already distinguishes account-level access from dedicated Primary access; rule 11 explicitly requires stopping if Primary is unreachable.

## 2. VERIFIED

| Evidence class / command | Observed result |
|---|---|
| REPOSITORY — `git fetch origin`, `git rev-parse HEAD origin/main` | Both `6bc14f3f00253bceea27c950cc8cae801f7e7a1c` |
| REPOSITORY — `git status --short`, `git remote -v` | Initially clean; canonical `https://PlatPlusHub@github.com/PlatPlusHub/CRM.git` for fetch/push |
| REPOSITORY — migration file count | 209; latest `202607062000` |
| REPOSITORY — `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` | CLEAN, Checks 1–25, exit 0; scope is files, including recorded Primary evidence |
| REPOSITORY — Check 15 | 110 pgTAP files / 1739 declared assertions agree with manifest; not an execution result |
| LOCAL RUNTIME — `docker ps` | ORVION database container up and healthy; other local services running |
| LOCAL RUNTIME — `pwsh -NoProfile -File scripts/check_database_parity.ps1` without unavailable Primary values | Guard printed `DATABASE PARITY: UNPROVEN`; no Primary comparison performed |
| LOCAL RUNTIME — ledger read by parity guard | 209 migrations, `102a08f0009493b58d2583ae28a0c17c` |
| LOCAL RUNTIME — function surface | 280 functions, `d0b08965d902ee9d9bc0bbb4c5d10745` |
| LOCAL RUNTIME — structural surface | 3568 objects, `34add22404df8f87411f295bf72c069c` |
| GENERATED — parity guard Check L3 | Generated comparison of API contract matches local surface: 75 RPCs, 8 reporting views, 73 tenant-reachable tables |
| LOCAL RUNTIME + REPOSITORY — `pwsh -NoProfile -File scripts/batch6_select_target.ps1` | 66 NOT-RECORDED candidates; customers exposure 17 first; quotations/users exposure 15 next |
| LOCAL RUNTIME — information_schema query | Customers has nullable numeric `credit_limit_amount` and nullable text `credit_limit_currency_code` |
| CONNECTOR — GitHub `get_repo(PlatPlusHub/CRM)` | Successful repository read |
| CONNECTOR — Context7 `resolve_library_id(Supabase)` | Successful documentation-index read |
| REMOTE CI — `gh run list --repo PlatPlusHub/CRM --commit 6bc14f3f00253bceea27c950cc8cae801f7e7a1c --json databaseId,name,status,conclusion --limit 10` | Migration CI `34271146299` and Repository Consistency `34271146253`: completed/success |

The parity guard's concluding phrase that local matches the repository is bounded here: **no reset ran in this session**. Its ledger, hashes and generated-contract comparison were observed; a fresh reconstruction from migrations was not. The guard was invoked through a Windows PowerShell parent which reported process exit 1; its explicit verdict was UNPROVEN, never CLEAN.

The prior report records 110/1739 for Pass A and Pass B and 445 HTTP assertions (29/122/74/120/40/60). Those are HISTORICAL results, not re-run results. HTTP, pgTAP, smoke, races and mutation tests were deliberately not started after the prerequisite failed.

## 3. FIXED

No product defects were reproduced or repaired. Bootstrap access status is now visible through the repository's existing handoff mechanism. No customer disposition or coverage credit was added.

The first documentation draft failed Check 5 (manifest 7360 characters against 7000, and a 1214-character field against 1200) and Check 9 (renamed the required `Live state:` label). Corrected by shortening the completed-capability narrative and restoring the label; no budget or guard was weakened. Regeneration and the subsequent Checks 1–25 run returned CLEAN, exit 0.

## 4. NOT FIXED

The requested customer surface discovery, authorization pairs, identity merge races/replay, financial identity tests, cross-tenant tests, numeric probes, mechanism substitution tests and final verification remain unperformed. No attack class is declared N/A merely because execution was blocked.

Decision reconciliation started but did not reach the required implementation/tests/Primary standard. In particular, **AUDIT-2** retains an OPEN table row while a later reconciliation paragraph calls its storage half implemented/superseded; **PD-23** still references PLAN-1's supposedly missing Limited ceilings although PLAN-1's current row rejects that premise. **MONEY-2** explicitly calls itself engineering work deferred to each column's slice while remaining on the manifest's owner list. These are reconciliation leads, not newly established owner decisions or authorized reasons to add constraints. Their canonical status was not rewritten without the missing investigation.

## 5. BLOCKED

Required external action: make the dedicated `supabase-primary` MCP callable in the active agent session, authenticated for Primary `vrvtsxexkiiiivlkdxzp` (the catalog associates it with the Platinum Plus Tours account). Complete any account authorization directly in the connector/browser; do not send credentials to the agent. The next agent must verify by successful project-URL and database reads, not by a green connection indicator.

The cause inside account/OAuth configuration was not proven, so reauthentication is not claimed to be a guaranteed fix. No configuration was rewritten, no token inspected and no alternate project substituted. `postgres-local` and `n8n` MCP reads also remain UNPROVEN because their tools are absent; local Docker/psql access works.

## 6. GOVERNANCE

The owner's Slice-11 request permits repair of reproduced engineering defects and canonical synchronization, but requires a verified baseline. `AGENTS.md §4` and `MASTER_INTEGRATION_CATALOG.md §0` require the live Primary evidence and the stop taken here. This report fulfills the session-record duty; it does not waive the baseline or advance the roadmap. No workflow redesign or new governance rule.

### OWNER DECISIONS

**No new business decision was established by this blocked session.** The manifest's ten inherited candidates remain visible below; they are not certified as genuinely open after full reconciliation. Their status/evidence authority remains `MASTER_GAP_REGISTER.md`.

| ID | Registered question / boundary to reconcile |
|---|---|
| MAIL-1 | Which transactional email provider and approved data-transfer arrangement? Owner/counsel review; no mail-provider choice made here. |
| RET-1 | Which approved retention period applies per document type? Mechanism already implemented; finite values need counsel. Preserve the no-policy state pending approved values. |
| AUDIT-2 | Are limit storage, unlimited encoding or Enterprise scope still undecided? Later evidence disputes the OPEN row; investigate before asking the owner. |
| PD-23 | What numeric quotas actually require enforcement? Separate implementation scheduling from PLAN-1's resolved scope-word interpretation. |
| FA-2 | May an account receive a payment in another currency, with what conversion evidence? No treasury policy or fix selected. |
| MONEY-2 | Which of opening balance, quotation total and quotation-item total legitimately permit negative values? Inspect signed/overdraft/adjustment semantics; no blanket non-negative constraint. |
| PAX-5 | When is an issued passenger manifest immutable, and who may correct it? No policy chosen. |
| PAX-6 | Are manifest changes business events, and under what canonical vocabulary? No event vocabulary invented. |
| BOOK-8 | May a finance-approval requirement be withdrawn, and by whom? No authority broadened. |
| BOOK-9 | What authority permits reassignment of a booked service's owner? No permission minted. |

The recommendations, alternatives and approval requirements for these inherited candidates must be derived after the required reconciliation. Presenting all ten as newly confirmed business choices would repeat the stale-decision defect the request forbids. None is the reason this session stopped: Primary access is the blocker.

### DECISIONS REJECTED AS NOT ACTUALLY OPEN

- **CUST-3** is already owner-decided, not a new YES/NO. Its current register row and implementation section record resolution; migration `202607060300_a_customer_ceiling_that_warns_and_converts.sql` quotes the owner's approval explicitly. The nullable ceiling columns exist locally. Recommendation: retain the approved direction; no approval requested again. Full behavior and Primary deployment remain UNPROVEN this session.
- **SUP-4c** is recorded implemented by `202607060600_the_supplier_ceiling_reaches_parity_with_the_customer_one.sql`; no conversion-instant question reopened. Runtime revalidation remains outstanding.
- **VOID-1** is recorded implemented by `202607060400_an_internal_void_that_does_not_speak_for_the_tax_authority.sql`; no external tax lifecycle proposed.
- **PLAN-1** and **CANON-26-1** have current resolved rows; do not resurrect questions from historical paragraphs. Their runtime justifications were not re-tested here.
- **DOC-LC-3** is classified engineering in its current row; it is not permission to collapse the lifecycle and generic archive fields. No repair attempted.

## 7. ENVIRONMENT

PowerShell on Windows, local Docker services available, git fetch and GitHub read available, Context7 available. Dedicated Primary/local-Postgres/n8n tools absent from this session. Account-level Supabase reachable as a tool but refuses Primary reads. This is an environment access limitation, not evidence that ORVION is defective.

## 8. CURRENT STATE

Phase 8 remains in progress; Active Change Request remains None; last completed capability remains Slice 10. Migration set unchanged at 209 / `202607062000`. Customer disposition NOT-RECORDED; Batch 6 coverage 11/77, all recorded surfaces ADVERSARIAL; Batch 6 NOT complete. No schema, grants, RLS, triggers, policies, permissions, tests or production data changed. Prior Primary ledger evidence remains historical and was not refreshed from local values.

This documentation package is committed after regeneration of ai-map and a fresh repository consistency run. Its commit is the commit containing this file; remote CI is checked after push and reported in the user handoff, without rewriting immutable history to predict a future run.

## 9. NEXT STEP

Restore callable Primary access and re-prove the three-state baseline before resuming **Batch 6 slice 11 — customers**.
