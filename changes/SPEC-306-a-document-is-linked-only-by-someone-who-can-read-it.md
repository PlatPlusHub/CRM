# Change Request — SPEC-306

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 50 makes a document link writable only by someone who can already read its document, and records every moved link, so a branch employee can no longer read another branch's passport scan or invoice by linking it onto their own booking, and no document leaves the record it belongs to unrecorded (DOC-9, DOC-10).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `789e056`, on the live local catalog, ranks `document_links` first: Exposure 6, coverage 54, NOT-RECORDED (runner-up `exchange_rates` 6/66). The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** A link decides who reads a document: the `documents` policy admits a non-confidential document through any `document_links` row the caller can see, and a link is visible when its target record is (SPEC-144). `app.is_document_responsible` makes the writer of a link onto their own work responsible for a financial document (SPEC-154-B). The link's own `scope_isolation` policy checks only the target. `app.upload_document`, the one RPC that links, links only the document it has just created; the table door (`authenticated` holds INSERT and UPDATE, charged by `guard_write_capability` with `UPLOAD_DOCUMENT`, held by every branch role from `employee` up) checks nothing about the document.
- **Measured at `789e056`** on the local stack, probe fixtures rolled back (one tenant with Giza and Suez branches, a Giza and a Suez `employee`, an owner and a trainee; another tenant):
  - **DOC-9 (Medium).** The Giza employee inserted a link from Suez's passport scan onto their own booking, or re-pointed their own ticket link at it, and then read the document, its version and its storage path; the same insert of Suez's invoice made them read it as responsible. A confidential document stayed hidden. The only precondition is the document's id.
  - **DOC-10 (Low).** The Giza employee moved their booking's ticket link to another of their bookings; the tenant's events did not move and `app.derive_created_by` keeps the creator, so nothing showed who took the ticket off the booking.
- **The repair**, in the SPEC-301 shape (authority BEFORE, record AFTER):
  - `app.guard_document_link_readable`, BEFORE INSERT OR UPDATE (SECURITY INVOKER on purpose, empty `search_path`, executable by no client role), session writes only: the writer must already read the link's document under the `documents` policy. It runs before the row exists, so a link cannot vouch for itself. A write with no session (migrations, seeds, provisioning, `service_role`, fixtures) is exempt, as in every sibling guard.
  - `app.emit_document_link_move`, AFTER UPDATE (SECURITY DEFINER, empty `search_path`, executable by no client role), session writes only: `document_linked`, the code `app.upload_document` already records for its link, on the document, with the link id and the previous and current document and target; an update that moves neither records nothing.
  - No grant, policy, RPC, event code or the other three triggers change. DELETE has no grant.
- **No existing file moves for a test or count.** The guard calls no `app.authorize`, so test 10's MEAS-2 inventory does not move; no event code is added, so the smoke catalog count stays 626; the generated API contract is identical (both functions are trigger functions); a first full suite run passed with no other change. `_ORVION_CANONICAL/27_event_catalog.md` gains one paragraph under `document_linked` saying what it now also records.
- **Swept and found sound, pinned rather than changed:** another tenant's document is refused (now by the guard; before by the composite foreign key); re-tenanting a link and a link with no target are refused by RLS and the single-target CHECK; a trainee without `UPLOAD_DOCUMENT` and an `aal1` owner are refused by `guard_write_capability` and step-up; DELETE has no grant; `app.upload_subscription_payment_proof` writes its proof link through the same table and passes test 47 unchanged.
- **Recorded positions, not repaired:** a new link is attributed by its own derived, immutable `created_by` and records no event of its own; `created_at` is caller-supplied on INSERT and read by nothing that decides (SPEC-216's schema-wide question).
- **Latent on Primary:** `vrvtsxexkiiiivlkdxzp` holds 0 tenants, 0 documents and 0 links (read-only, 2026-11-12, ledger 259), so no stored row is affected and no data repair is needed.

## Risks

- **A writer who cannot read a document can no longer link it** (42501, "a document can be linked only by someone who can already read it"); every caller that links through `app.upload_document` creates the document first and reads it as its creator. Tests 28, 35, 47, 48, 50, 57, 58, 80, 82, 88 and 89, which write links, pass unchanged.
- **Trigger order.** BEFORE triggers fire in name order, so a writer refused by both guards now sees this guard's message before `guard_write_capability`'s; the capability guard still refuses a non-holder whose document is readable, and tests 57 and 58 pass unchanged.
- **Primary deployment is irreversible** and runs only under the exact-SHA Gate-2 record of Step 7. Approval of this contract does not authorize it. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions (class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo; publish, promote and hosted deploy ~12:05; slice 8 in run mode 2, 2026-11-12 ~17:02 Cairo), recorded outside this repository; never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-306-a-document-is-linked-only-by-someone-who-can-read-it.md`
- `supabase/migrations/20261112150000_a_document_is_linked_only_by_someone_who_can_read_it.sql`
- `supabase/tests/165_a_document_is_linked_only_by_someone_who_can_read_it_test.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607047900_upload_document.sql`
- `supabase/migrations/202607052300_document_read_scope.sql`
- `supabase/migrations/202607054400_document_write_integrity.sql`
- `supabase/migrations/202607054500_subscription_payment_proof_lifecycle.sql`
- `supabase/migrations/202607054700_document_links_payment_proof_branch.sql`
- `supabase/migrations/202607055000_policy_role_scope_consistency.sql`
- `supabase/migrations/202607058700_a_financial_document_follows_the_work_not_the_department.sql`
- `supabase/migrations/20260924140000_document_door_parity.sql`
- `supabase/migrations/20261111150000_a_retention_period_changes_only_with_step_up_and_a_record.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/28_document_scope_test.sql`
- `supabase/tests/47_payment_proof_lifecycle_test.sql`
- `supabase/tests/48_document_storage_test.sql`
- `supabase/tests/57_write_capability_map_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/82_financial_document_responsibility_test.sql`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/readiness_population.ps1`
- `scripts/parity_surface.sql`
- `scripts/check_database_parity.ps1`
- `scripts/check_primary_ledger.ps1`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `reports/architecture-decision-records.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `supabase/migrations/202607052300_document_read_scope.sql` (the documents and links policies, the one-directional chain) and `202607058700_a_financial_document_follows_the_work_not_the_department.sql` (`app.is_document_responsible`)
- `supabase/tests/28_document_scope_test.sql` and `82_financial_document_responsibility_test.sql`
- `changes/SPEC-144-document-read-scope.md`; `reports/master/MASTER_GAP_REGISTER.md` (DOC-1…DOC-8); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11
- `changes/SPEC-301-a-department-stays-in-its-branch-and-changes-only-with-authority-and-a-record.md` (the guard and emitter shape)

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: one BEFORE INSERT OR UPDATE guard on `document_links`, session writes only, requires the writer's own read of the link's document; one AFTER UPDATE emitter records every moved link as `document_linked` with both values; test 165 pins each refused link and re-point beside the reads they would have opened, the RPC's own link, a link of a readable document, the creator attribution, the move's single record, a no-op update, another tenant's owner, the tenant-wide owner and the session-less exemption; the register and disposition record DOC-9, DOC-10 and the surface; canon 27 says what `document_linked` now also records.

Pass 2 Adversarial Review: the design was challenged on the prototype. A WITH CHECK clause on the links policy was rejected: the `documents` policy reads `document_links`, and the one-directional chain (SPEC-144) forbids the reverse read. A SECURITY DEFINER guard re-stating the read rule was rejected: it would copy the `documents` policy and drift from it; the invoker reads the policy itself, and mutant M2 shows the definer form admits every document. Revoking INSERT and UPDATE from `authenticated` behind a new RPC was rejected: a new client surface for a door whose only flaw is the missing read precondition. Refusing every move was rejected: moving a misfiled link between records the writer reads is legitimate; it is now checked and recorded. Recording every new link was rejected: `app.upload_document` already records its link, and a direct link is attributed by its derived, immutable `created_by`. A new event code was rejected: `document_linked` already describes a link, at `info` like the RPC's. Refusing session-less writes was rejected: every sibling guard exempts them, and provisioning and the fixtures of eleven tests write links without a session. Attacks run on the final bytes: tests 28, 35, 47, 48, 50, 57, 58, 80, 82, 88 and 89 pass unchanged; the full suite passed first run with no other file moving; the generated API contract is identical; the confidential clause, the composite foreign key, the single-target CHECK, RLS on re-tenanting, the capability guard and step-up were each probed and hold. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-12. Re-measured on byte-identical files in a disposable clone of `789e056` with the project-local CLI 3.0.0: the clean reset, test 165 and tests 28, 82 and 48 alone, pgTAP Pass A and B, the three declared HTTP suites, smoke, the probes, all four mutants, the causal negative, the structural fingerprints before and after, the API-contract generator (identical), the map generator and repository consistency; and Primary and Founder Secondary read read-only for their ledgers, triggers, tenants, documents and links.

Selected Version: SPEC-306; selected: the smallest repair that closes DOC-9 and DOC-10 on every session path (one invoker guard that requires the writer's own read of the linked document, one emitter that records a moved link with the existing code; no grant, policy, RPC or event code changed), proven on byte-identical files by the full local protocol, four killed mutants, the probes and the causal negative

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Every session link and re-point requires the writer's read of the document | the table door (RLS insert and update) of every `UPLOAD_DOCUMENT` holder; `app.upload_document`; `app.upload_subscription_payment_proof` | WRITE | Migration SHA-256 `5bfb8e52155d367b5aab3e516e7b295d2ea30b3f0589df935396cbd0a37af9f3`, md5 `149882262bc6f900927121fcc13005b4`, 4684 bytes, LF, ASCII. A clean reset gives 260 migrations, latest `20261112150000`, ledger `5f6e412ee282edaf1e16346c3d5b5805`; guard `md5(prosrc)` `692eee1f6c5a0944a5d06e18f5a3a655`, SECURITY INVOKER, ACL `{postgres=X/postgres}`; trigger `document_links_guard_document_readable` BEFORE INSERT OR UPDATE. Both RPCs create the document first and pass tests 28, 47 and 48 unchanged. |
| Every moved link is recorded once | readers of `public.events`; canon 27 | WRITE | Emitter `md5(prosrc)` `57bdf4c9574caf29f59c651b32dc7888`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; trigger `document_links_emit_move` AFTER UPDATE; the existing code `document_linked`, catalog 71/626 unchanged. |
| The readers of links | the `documents` and `document_versions` policies; `app.is_document_responsible`; `app.financial_documents` | VERIFY | No body changes; tests 28 and 82 pass unchanged; the probes after the repair find no document opened by a refused link. |
| Test 165 | `supabase/tests` | WRITE | SHA-256 `0d20b1d701ed1e351b6613cbdecc371cb2a26a7f786e6ab1def8a92aa3b7612e`, md5 `a27697b8d7f1ad5f5812e7605f6f78e7`, 12594 bytes, LF, ASCII, `plan(16)`: 16/16. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=165, Tests=3117`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 165/3117, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/626 catalog). 165 files whose literal `plan(N)` values sum to 3117. Test 10 and `scripts/verify_database.sql` do not move. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (259): functions `e11c0124eec937fa08c1f7fe567b1249`/339, triggers `b5c21e213844e603ed5e1a6f9b0be455`/326, `_combined` `0e398aeac8e622fabeda83ac1900bf9d`/3156, equal to the recorded Primary evidence. After (260, local): functions `73b0bbffade0a788aff53c10266a97dc`/341 (+2), triggers `8f39469bf723f0ea53cccb3c96fb65fd`/328 (+2), `_combined` `4a7b00b15007fbdb9072203d1f46ad19`/3160; policies, constraints, grants, columns, views, indexes, status transitions and RLS unchanged. Step 9 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC is added, removed or changed; the two functions are trigger functions executable by no client role. The canonical generator, run on the final bytes, reproduces the committed contract exactly (no line differs). It is in Write Scope only because Check L3 regenerates it; Step 9 regenerates it and it must not change. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 259 → 260 migrations, latest `20261112150000`, ledger fingerprint `5f6e412ee282edaf1e16346c3d5b5805`; 164 → 165 files and 3101 → 3117 assertions; coverage 50 → 51 of 78. Tables 78 and client RPCs 80 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 10 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin. |
| DOC-9 and DOC-10 fixed; the surface recorded; canon 27 | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `27_event_catalog.md`; Checks 21, 22, 24, 25, 29 | WRITE | No `DOC-9` or `DOC-10` row exists at `789e056`. Test 165's `-- ATTACK-CLASSES:` line declares ten classes with STATE, CONCURRENCY and REPLAY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Each DOC row has Owner `—` and is settled. Coverage 51: 27 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 27 `NOT-RECORDED`; all 51 `ADVERSARIAL`. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–5 applied and the contract present, consistency reports exactly the six measured-state items (259 vs 260 migrations, latest, ledger fingerprint, 164 vs 165 files, 3101 vs 3117 assertions, the Primary-evidence record) and Checks 21–29 pass. Step 9 makes them true; the one implementation commit is made only after it. |
| The four CI-only guard self-tests | `scripts/test_*_guard.ps1`; `orvion-acceptance` | VERIFY | Unchanged scripts, run by `orvion-acceptance` on the exact candidate SHA before `main` may move to it; their controls require the measured state of Step 9, so they are not run locally (timed once in slice 47: 618 s locally, 84 s in hosted CI). |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 8 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, probes, mutants and causal negative hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 6 |
| Primary lacks the target migration and its ledger and structure equal the recorded evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 8 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 9 | Step 10 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 9 | Step 10 |
| The map matches its generators | BEFORE_COMPLETION | NONE | NONE | Step 10 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: the links policy checks the target's visibility only; `guard_write_capability` charges `UPLOAD_DOCUMENT`, not the document; the `documents` policy reads links but cannot be read back by the links policy (SPEC-144's one-directional chain); `app.derive_created_by` fixes `created_by` at creation only; `app.upload_document` records its own link only. Nothing ties a link to its writer's read of the document, or records a move.

Added Property: For every session, a document link is created or re-pointed only by a writer who can already read its document, and every link moved to another document or target is recorded once with its actor and both values.

Causal Negative: On the stack with both triggers removed, test 165 fails assertions 1, 4–7, 12 and 13; on the `789e056` schema it stops at assertion 1. The probes there return: the Giza employee links Suez's passport scan or invoice onto their own booking, or re-points their own link at the scan, and reads the document, its version and its storage path; a moved ticket link leaves the events unchanged.

Positive Test Design: One tenant with Giza and Suez branches, a Giza and a Suez `employee` and an owner, Suez documents including a passport scan and an invoice, Giza bookings; another tenant with an owner. Positive controls: `app.upload_document` links the document it creates; the Giza employee links a document they read onto another of their bookings, attributed to them; the tenant-wide owner at `aal2` links Suez's scan; a session-less write lands without a check.

Negative Test Design:
- **Auth:** the owner's write passes only at `aal2` (`guard_write_capability`, unchanged).
- **Tenant:** another tenant's owner is refused 42501.
- **Door:** the table door is charged on INSERT and UPDATE; DELETE has no grant; both RPCs keep linking their own documents.
- **Input:** a re-point to an unreadable document is refused like a new link.
- **Privilege:** the Giza employee, holding `UPLOAD_DOCUMENT` without tenant-wide read, is refused both Suez documents and the re-point, and afterwards still reads neither.
- **Business:** a link is a read grant, so it requires the read it would grant.
- **Observability:** a moved link is recorded once as `document_linked` with the link id and both values; a no-op update and a session-less write record nothing.

Non-Empty Population Obligation: The fixture holds two tenants, two branches, four users, three bookings, three documents and three links before the first assertion. Each refusal is asserted by SQLSTATE 42501 and, for the link guard, its exact message; each record by its exact field list.

Mutation Obligation: Each mutant is installed inside test 165's own rolled-back transaction, proven installed by a diag line (the guard's `md5(pg_get_functiondef)`, its definer flag and the table's trigger count), run, and rolled back; the restored shape (guard `dcb651faf92a8aacf8a67bf3e5b5649d`, invoker, emitter `910d0cfbbde2108e0555b88b6facff2d`, 5 triggers) is read after the last. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | the guard trigger dropped | 165 assertions 1, 4–7, 12 and 13 |
| M2 | the guard runs as SECURITY DEFINER (reads every document) | 165 assertions 2, 4–7, 12 and 13 |
| M3 | the emitter trigger dropped | 165 assertions 1, 12 and 13 |
| M4 | the emitter records an update that moves nothing | 165 assertion 13 |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts, repository consistency and the recorded Primary evidence. Before Step 8: the focused tests, the probes, the mutants, the causal negative and the fresh Primary baseline of Step 6.

## Implementation Steps

1. Check whether `supabase/migrations/20261112150000_a_document_is_linked_only_by_someone_who_can_read_it.sql` contains `Batch 6 slice 50 (DOC-9, DOC-10)`; if so record Already Applied when its Git blob is f61e88618e7092a2eb13d78fb42f08820b2c80f0, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the migration: the link guard and the move emitter), and change nothing else:

   ```text
   -- Batch 6 slice 50 (DOC-9, DOC-10) -- a document is linked only by someone who can read it, and a
   -- moved link is recorded.
   --
   -- =================================================================================================
   -- THE MEASURED DEFECTS (2026-11-12 at 789e056 on the local stack, probe fixtures rolled back)
   --
   -- DOC-9  A link decides who reads a document: the `documents` policy admits a non-confidential
   --        document through any `document_links` row the caller can see, and a link is visible when
   --        its target record is. The link's own policy checks only the TARGET, so an `employee` of one
   --        branch who holds `UPLOAD_DOCUMENT` inserted a link from another branch's passport scan onto
   --        their own booking, or re-pointed their own link at it, and then read the document, its
   --        version and its storage path -- the boundary DOC-1 (SPEC-144) closed. The same insert of
   --        another branch's invoice made the employee "responsible" for it through
   --        `app.is_document_responsible` and read it past SPEC-154-B. The only precondition is the
   --        document's id. `app.upload_document`, the one door that links, links only the document it
   --        has just created.
   -- DOC-10 Re-pointing a link by UPDATE moved a document off the record it belonged to (a ticket off
   --        its booking) and recorded nothing: `derive_created_by` keeps the creator, and no event is
   --        written. A new link is attributed by its own row (`created_by` is derived and immutable).
   --
   -- =================================================================================================
   -- THE REPAIR, IN THE SPEC-301 SHAPE: authority is a precondition and runs BEFORE; the record is a
   -- fact and runs AFTER.
   --
   -- 1. `app.guard_document_link_readable`, BEFORE INSERT OR UPDATE, session writes only: the caller
   --    must already read the link's document. SECURITY INVOKER on purpose: the check IS the caller's
   --    own read of `documents` under its policy (creator, tenant-wide read, the financial and
   --    confidential clauses, an existing visible link). It runs BEFORE the row exists, so a link
   --    cannot vouch for itself. A policy clause cannot do this: `documents` reads `document_links`,
   --    and the one-directional chain (SPEC-144) forbids the reverse. No session (migrations, seeds,
   --    provisioning, service_role, the tests' fixtures): no check, as in every sibling guard.
   -- 2. `app.emit_document_link_move`, AFTER UPDATE, session writes only: `document_linked` (the code
   --    `app.upload_document` already records for its link) on the document, with the link id and the
   --    previous and current document and target. An UPDATE that moves neither records nothing.
   --
   -- DELETE is not included: `authenticated` holds no DELETE on this table.
   -- NOT CHANGED: every grant and policy, the other three triggers, both RPCs, the documents policy.
   -- =================================================================================================

   create or replace function app.guard_document_link_readable()
   returns trigger
   language plpgsql
   set search_path = ''
   as $fn$
   begin
       if (select auth.uid()) is null then
           return new;
       end if;
       if not exists (select 1 from public.documents d where d.id = new.document_id) then
           raise exception 'a document can be linked only by someone who can already read it'
               using errcode = 'insufficient_privilege';
       end if;
       return new;
   end;
   $fn$;

   revoke execute on function app.guard_document_link_readable() from public;

   create trigger document_links_guard_document_readable
       before insert or update on public.document_links
       for each row execute function app.guard_document_link_readable();

   create or replace function app.emit_document_link_move()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   declare
       v_prev jsonb := jsonb_strip_nulls(to_jsonb(old) - array['id', 'tenant_id', 'created_by', 'created_at']);
       v_next jsonb := jsonb_strip_nulls(to_jsonb(new) - array['id', 'tenant_id', 'created_by', 'created_at']);
   begin
       if (select auth.uid()) is null or v_prev = v_next then
           return null;
       end if;

       perform app.record_event(
           new.tenant_id, 'document_linked', 'document', new.document_id, null,
           null, null, null,
           jsonb_build_object('link_id', new.id, 'previous', v_prev, 'current', v_next),
           'info');
       return null;
   end;
   $fn$;

   revoke execute on function app.emit_document_link_move() from public;

   create trigger document_links_emit_move
       after update on public.document_links
       for each row execute function app.emit_document_link_move();
   ```

   The resulting file's Git blob is f61e88618e7092a2eb13d78fb42f08820b2c80f0.

2. Check whether `supabase/tests/165_a_document_is_linked_only_by_someone_who_can_read_it_test.sql` contains `plan(16)`; if so record Already Applied when its Git blob is 3628685dd2c90e7aa0e8f2979fd36ccc9327177d, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 165, 16 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 50 (DOC-9, DOC-10) --
   -- a document is linked only by someone who can already read it, and a moved link is recorded
   -- (`20261112150000`).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
   --   STATE=N/A -- a link has no lifecycle; its only change is a move, which is checked and recorded here.
   --   CONCURRENCY=N/A -- the check reads committed visibility of one document; no counter or claim.
   --   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(16);

   insert into auth.users (id, email) values
     ('16500000-0000-0000-0000-0000000000a1','giza@c165.test'),
     ('16500000-0000-0000-0000-0000000000a2','suez@c165.test'),
     ('16500000-0000-0000-0000-0000000000a3','owner@c165.test'),
     ('16500000-0000-0000-0000-0000000000a9','other@c165.test');
   insert into public.tenants (id, name, slug, status) values
     ('16500000-0000-0000-0000-000000000001','Link Travel','link-travel-165','active'),
     ('16500000-0000-0000-0000-000000000002','Other Travel','other-travel-165','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select t.id, sp.id, 'active' from public.subscription_plans sp cross join (values ('16500000-0000-0000-0000-000000000001'::uuid), ('16500000-0000-0000-0000-000000000002'::uuid)) t(id) where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-000000000001','Giza','giza-165'),
     ('16500000-0000-0000-0000-00000000000b','16500000-0000-0000-0000-000000000001','Suez','suez-165');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('16500000-0000-0000-0000-0000000000c1','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000a','sales','Giza Sales'),
     ('16500000-0000-0000-0000-0000000000c2','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000b','sales','Suez Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('16500000-0000-0000-0000-000000000011','16500000-0000-0000-0000-000000000001','Giza','giza@c165.test',true,'16500000-0000-0000-0000-0000000000a1'),
     ('16500000-0000-0000-0000-000000000012','16500000-0000-0000-0000-000000000001','Suez','suez@c165.test',true,'16500000-0000-0000-0000-0000000000a2'),
     ('16500000-0000-0000-0000-000000000013','16500000-0000-0000-0000-000000000001','Owner','owner@c165.test',true,'16500000-0000-0000-0000-0000000000a3'),
     ('16500000-0000-0000-0000-000000000019','16500000-0000-0000-0000-000000000002','Other','other@c165.test',true,'16500000-0000-0000-0000-0000000000a9');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-000000000011','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1',true),
     ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-000000000012','16500000-0000-0000-0000-00000000000b','16500000-0000-0000-0000-0000000000c2',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.tid, v.uid, r.id, 'tenant'
   from (values ('16500000-0000-0000-0000-000000000001'::uuid,'16500000-0000-0000-0000-000000000011'::uuid,'employee'),
                ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-000000000012','employee'),
                ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-000000000013','owner'),
                ('16500000-0000-0000-0000-000000000002','16500000-0000-0000-0000-000000000019','owner')) v(tid, uid, role_code)
   join public.roles r on r.code = v.role_code;
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('16500000-0000-0000-0000-0000000000d1','16500000-0000-0000-0000-000000000001','person','Link Customer');
   insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                                owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
     ('16500000-0000-0000-0000-0000000000f1','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1','16500000-0000-0000-0000-0000000000d1','16500000-0000-0000-0000-000000000011','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1','draft','Giza booking','BK-165-1'),
     ('16500000-0000-0000-0000-0000000000f2','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1','16500000-0000-0000-0000-0000000000d1','16500000-0000-0000-0000-000000000011','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1','draft','Giza booking 2','BK-165-2'),
     ('16500000-0000-0000-0000-0000000000f3','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000b','16500000-0000-0000-0000-0000000000c2','16500000-0000-0000-0000-0000000000d1','16500000-0000-0000-0000-000000000012','16500000-0000-0000-0000-00000000000b','16500000-0000-0000-0000-0000000000c2','draft','Suez booking','BK-165-3');
   -- Dg: Giza's ticket on Giza's booking. Ds and Di: Suez's passport scan and invoice on Suez's booking.
   insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential, created_by) values
     ('16500000-0000-0000-0000-0000000000e1','16500000-0000-0000-0000-000000000001','ticket','Dg','active',false,'16500000-0000-0000-0000-000000000011'),
     ('16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-000000000001','passport','Ds','active',false,'16500000-0000-0000-0000-000000000012'),
     ('16500000-0000-0000-0000-0000000000e3','16500000-0000-0000-0000-000000000001','invoice','Di','active',false,'16500000-0000-0000-0000-000000000012');
   insert into public.document_links (id, tenant_id, document_id, booking_id) values
     ('16500000-0000-0000-0000-0000000000b1','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e1','16500000-0000-0000-0000-0000000000f1'),
     ('16500000-0000-0000-0000-0000000000b2','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-0000000000f3'),
     ('16500000-0000-0000-0000-0000000000b3','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e3','16500000-0000-0000-0000-0000000000f3');

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.document_links'::regclass and not tgisinternal
        and tgname in ('document_links_guard_document_readable', 'document_links_emit_move')),
     2, 'both triggers are installed on document_links');

   select is(
     (select prosecdef from pg_proc where oid = 'app.guard_document_link_readable'::regproc),
     false, 'the guard is SECURITY INVOKER: the check is the caller''s own read of the document');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16500000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

   select is((select count(*)::int from public.documents where title in ('Ds','Di')), 0,
     'the Giza employee reads neither Suez document -- the anchor for what follows');

   -- DOC-9: a link may not carry a document its writer cannot read.
   select throws_ok(
     $$insert into public.document_links (tenant_id, document_id, booking_id) values
       ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-0000000000f1')$$,
     '42501', 'a document can be linked only by someone who can already read it',
     'DOC-9: the Giza employee cannot link the Suez passport scan onto their own booking');

   select throws_ok(
     $$insert into public.document_links (tenant_id, document_id, booking_id) values
       ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e3','16500000-0000-0000-0000-0000000000f1')$$,
     '42501', 'a document can be linked only by someone who can already read it',
     'DOC-9: ...nor the Suez invoice, which would make them "responsible" for it (SPEC-154-B)');

   select throws_ok(
     $$update public.document_links set document_id = '16500000-0000-0000-0000-0000000000e2'
       where id = '16500000-0000-0000-0000-0000000000b1'$$,
     '42501', 'a document can be linked only by someone who can already read it',
     'DOC-9: ...nor re-point their own link at the Suez passport scan');

   select is((select count(*)::int from public.documents where title in ('Ds','Di')), 0,
     'and still reads neither Suez document');

   -- The legitimate door and the legitimate direct link still work.
   select lives_ok(
     $$select app.upload_document('other','Giza upload','g.pdf','pdf','booking','16500000-0000-0000-0000-0000000000f1')$$,
     'app.upload_document still links the document it has just created');

   select lives_ok(
     $$insert into public.document_links (tenant_id, document_id, booking_id) values
       ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e1','16500000-0000-0000-0000-0000000000f2')$$,
     'a document the writer reads may be linked onto another record the writer reads');

   select is(
     (select count(*)::int from public.document_links l join public.users u on u.id = l.created_by
      where l.document_id = '16500000-0000-0000-0000-0000000000e1' and l.booking_id = '16500000-0000-0000-0000-0000000000f2'
        and u.full_name = 'Giza'),
     1, 'a new link is attributed by its own row: created_by is the writer');

   -- DOC-10: a moved link is recorded, with the previous and the current target.
   select lives_ok(
     $$update public.document_links set booking_id = '16500000-0000-0000-0000-0000000000f2'
       where id = '16500000-0000-0000-0000-0000000000b1'$$,
     'the Giza employee may move their own ticket link between two Giza bookings');

   reset role;

   select is(
     (select count(*)::int from public.events e join public.users u on u.id = e.actor_user_id
      where e.tenant_id = '16500000-0000-0000-0000-000000000001' and e.event_type_code = 'document_linked'
        and e.entity_id = '16500000-0000-0000-0000-0000000000e1' and u.full_name = 'Giza'
        and e.payload -> 'previous' ->> 'booking_id' = '16500000-0000-0000-0000-0000000000f1'
        and e.payload -> 'current' ->> 'booking_id' = '16500000-0000-0000-0000-0000000000f2'
        and e.payload ->> 'link_id' = '16500000-0000-0000-0000-0000000000b1'),
     1, 'DOC-10: the move is recorded once, as document_linked by the mover, with both targets');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16500000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
   update public.document_links set booking_id = '16500000-0000-0000-0000-0000000000f2'
    where id = '16500000-0000-0000-0000-0000000000b1';
   reset role;

   select is(
     (select count(*)::int from public.events
      where tenant_id = '16500000-0000-0000-0000-000000000001' and event_type_code = 'document_linked'
        and payload ? 'previous'),
     1, 'an update that moves nothing records nothing');

   -- TENANT: another tenant's owner sees none of this tenant's documents, so links none of them.
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16500000-0000-0000-0000-0000000000a9","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.document_links (tenant_id, document_id, booking_id) values
       ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-0000000000f3')$$,
     '42501', null,
     'TENANT: another tenant''s owner cannot link this tenant''s document');

   -- The owner reads every document of the tenant (tenant-wide read), so may link any of them.
   select set_config('request.jwt.claims', '{"sub":"16500000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
   select lives_ok(
     $$insert into public.document_links (tenant_id, document_id, booking_id) values
       ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-0000000000f1')$$,
     'the owner, who reads every document of the tenant, may link the Suez passport scan anywhere');
   reset role;

   -- The platform path (no session) is not checked, as in every sibling guard.
   select lives_ok(
     $$insert into public.document_links (tenant_id, document_id, booking_id) values
       ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e3','16500000-0000-0000-0000-0000000000f2')$$,
     'a session-less platform write is not checked');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 3628685dd2c90e7aa0e8f2979fd36ccc9327177d.

3. Check whether `_ORVION_CANONICAL/27_event_catalog.md` contains `and when a link is moved by UPDATE to another document or target`; if so record Already Applied when its Git blob is 609c2a90947eb29b7e56ca7aa5ceecfd2832ae98, and otherwise stop and report. Otherwise make exactly this one edit (the document_linked entry: what it now also records), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   ## document_linked

   Severity: info

   ```
   insert
   ```text
   Created when `app.upload_document` links the document it has just created, and when a link is moved by UPDATE to another document or target, with the link id and the previous and current document and target; an update that moves neither records nothing (DOC-10, SPEC-306). A new link is attributed by its own `created_by`.

   ```

   The resulting file's Git blob is 609c2a90947eb29b7e56ca7aa5ceecfd2832ae98.

4. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| DOC-9 |`; if so record Already Applied when its Git blob is 3048e1ceeac1c0131febd63bf0d4fb09e861ff80, and otherwise stop and report. Otherwise make exactly these 2 edits (the Slice 50 freshness entry and the DOC-9 and DOC-10 rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-11 (**Slice 49 — `document_retention_policies` selected live at Exposure 6, coverage 36; runner-up `document_links` at 6/54.** **RET-3** (Medium) and **RET-4** (Medium) are new and fixed. The table is its own only writer and its RLS charged `MANAGE_TENANT_SETTINGS` without step-up, so an `owner` at `aal1` set a 1-day period and a `ceo` at `aal1` shortened a ten-year one to 1 day, and after each the storage scan made a superseded version a `delete_object` claim, while the legal hold that overrides retention refuses the same session; no change was recorded and the ceo's change still named the owner. SPEC-305 charges the step-up and records every change. STEPUP-1 loses its `document_retention_policies` member. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-12 (**Slice 50 — `document_links` selected live at Exposure 6, coverage 54; runner-up `exchange_rates` at 6/66.** **DOC-9** (Medium) and **DOC-10** (Low) are new and fixed. A link decides who reads a non-confidential document, and the link's policy checked only its target, so a branch `employee` linked another branch's passport scan or invoice onto their own booking, or re-pointed their own link at it, and read the document and its storage path; a link moved by UPDATE was recorded nowhere. SPEC-306 refuses a link whose document its writer cannot already read and records every move. No other row changed.)

   Previously: 2026-11-11 (**Slice 49 — `document_retention_policies` selected live at Exposure 6, coverage 36; runner-up `document_links` at 6/54.** **RET-3** (Medium) and **RET-4** (Medium) are new and fixed. The table is its own only writer and its RLS charged `MANAGE_TENANT_SETTINGS` without step-up, so an `owner` at `aal1` set a 1-day period and a `ceo` at `aal1` shortened a ten-year one to 1 day, and after each the storage scan made a superseded version a `delete_object` claim, while the legal hold that overrides retention refuses the same session; no change was recorded and the ceo's change still named the owner. SPEC-305 charges the step-up and records every change. STEPUP-1 loses its `document_retention_policies` member. No other row changed.)
   ```

   b) immediately after the line
   ```text
   | RET-4 | **No change to a document retention policy was recorded, and an UPDATE kept the creator's name, so a file deletion could not be traced to whoever set its period** | audit completeness · observability | Medium | R | 6 | M | ✅ | **✅ FIXED 2026-11-11 (SPEC-305, `20261111150000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-305; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `53146b3`: no trigger or function recorded a policy's creation, shortening, re-type or deactivation (tenant events unchanged across all of them), and `app.derive_created_by` keeps `created_by` on UPDATE, so after the ceo's shortening the row still named the owner. The legal hold, the other retention lever, records every transition as critical (canon 27). **Repaired:** `app.guard_document_retention_policy_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, session writes only) charges `app.authorize('MANAGE_TENANT_SETTINGS')`, the legal hold's own charge, on every column; `app.emit_document_retention_policy_change` (AFTER INSERT OR UPDATE) records the new code `document_retention_policy_changed` (critical) with the actor and the previous and current type, period, active flag and reason. `164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql` pins both. A no-change update and a session-less write record nothing. | — | SPEC-305-a-retention-period-changes-only-with-step-up-and-a-record | 11-11 | 11-11 |
   ```
   insert
   ```text
   | DOC-9 | **A link decides who reads a document, and its writer needed to read only the link's target, so a branch employee linked another branch's passport scan or invoice onto their own booking and read it** | security · privacy scope · authorization | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-12 locally (SPEC-306, `20261112150000`); Primary deployment pending.** **MEASURED** at `789e056`: the `documents` policy admits a non-confidential document through any `document_links` row the caller can see, and a link is visible when its target record is; the link's own `scope_isolation` policy checks only the target. An `employee` of Giza (`UPLOAD_DOCUMENT`, no tenant-wide read) inserted a link from Suez's passport scan onto their own booking, or re-pointed their own ticket link at it, and then read the document, its version and its storage path, the boundary DOC-1 (SPEC-144) closed; the same insert of Suez's invoice made them responsible for it through `app.is_document_responsible` and read it past SPEC-154-B. A confidential document stayed hidden. The only precondition is the document's id. `app.upload_document`, the one door that links, links only the document it has just created. **Repaired:** `app.guard_document_link_readable` (BEFORE INSERT OR UPDATE, SECURITY INVOKER, session writes only) refuses a link whose document the writer cannot already read under the `documents` policy; `app.emit_document_link_move` (AFTER UPDATE, SECURITY DEFINER) records a moved link as `document_linked` with the link id and the previous and current document and target. `165_a_document_is_linked_only_by_someone_who_can_read_it_test.sql` pins both. | — | SPEC-306-a-document-is-linked-only-by-someone-who-can-read-it | 11-12 | 11-12 |
   | DOC-10 | **A link moved by UPDATE took a document off the record it belonged to and was recorded nowhere** | audit completeness · observability | Low | R | 6 | M | 🛡 | **FIXED 2026-11-12 locally (SPEC-306, `20261112150000`); Primary deployment pending.** **MEASURED** at `789e056`: an `employee` moved the ticket link of their booking to another of their bookings; the tenant's events did not move and `app.derive_created_by` keeps the creator, so nothing showed who took the ticket off the booking. A new link is attributed by its own row (`created_by` derived and immutable); `app.upload_document` records `document_linked` for its link. **Repaired:** `app.guard_document_link_readable` (BEFORE INSERT OR UPDATE, SECURITY INVOKER, session writes only) refuses a link whose document the writer cannot already read under the `documents` policy; `app.emit_document_link_move` (AFTER UPDATE, SECURITY DEFINER) records a moved link as `document_linked` with the link id and the previous and current document and target. `165_a_document_is_linked_only_by_someone_who_can_read_it_test.sql` pins both. An update that moves nothing and a session-less write record nothing. | — | SPEC-306-a-document-is-linked-only-by-someone-who-can-read-it | 11-12 | 11-12 |
   ```

   The resulting file's Git blob is 3048e1ceeac1c0131febd63bf0d4fb09e861ff80.

5. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**51 of 78 recorded · 27 `; if so record Already Applied when its Git blob is 57392a42d2d6879b77c0d2016cb10e1735028afc, and otherwise stop and report. Otherwise make exactly these 4 edits (the freshness entry, coverage 51 of 78 and the document_links row), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-11 (**slice 49 — `document_retention_policies` selected by Exposure 6, coverage 36; runner-up `document_links` at 6/54.** Coverage **49 → 50 of 78**. RET-3: an `owner` or `ceo` at `aal1` set or shortened a retention period at the table, and a superseded version became a `delete_object` claim, while the legal hold refuses the same session. RET-4: no policy change was recorded. SPEC-305 closes both here, so the row is `AUDITED`.)
   ```
   with
   ```text
   Last updated: 2026-11-12 (**slice 50 — `document_links` selected by Exposure 6, coverage 54; runner-up `exchange_rates` at 6/66.** Coverage **50 → 51 of 78**. DOC-9: a branch employee linked another branch's document onto their own booking and read it. DOC-10: a moved link was recorded nowhere. SPEC-306 closes both here, so the row is `AUDITED`.)

   Previously: 2026-11-11 (**slice 49 — `document_retention_policies` selected by Exposure 6, coverage 36; runner-up `document_links` at 6/54.** Coverage **49 → 50 of 78**. RET-3: an `owner` or `ceo` at `aal1` set or shortened a retention period at the table, and a superseded version became a `delete_object` claim, while the legal hold refuses the same session. RET-4: no policy change was recorded. SPEC-305 closes both here, so the row is `AUDITED`.)
   ```

   b) replace the line
   ```text
   **50 of 78 recorded · 26 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 28 `NOT-RECORDED`.**
   ```
   with
   ```text
   **51 of 78 recorded · 27 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 27 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 50 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 51 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `document_links` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `document_links` | **AUDITED** | ADVERSARIAL | `SPEC-306-a-document-is-linked-only-by-someone-who-can-read-it` | DOC-9, DOC-10 | `165_a_document_is_linked_only_by_someone_who_can_read_it_test.sql` (16 assertions, ten attack classes declared, STATE, CONCURRENCY and REPLAY N/A) proves that a branch employee can neither link another branch's passport scan or invoice onto their own booking nor re-point their own link at it, and still reads neither; that `app.upload_document` still links the document it creates, a document the writer reads may be linked onto another record the writer reads, and a new link names its writer; that a moved link is recorded once as `document_linked` with both targets and a no-change update records nothing; that another tenant's owner is refused, the tenant-wide owner may link any document of the tenant, and a session-less write is not checked. Tests 28, 35, 47, 48, 50, 57, 58, 80, 82, 88 and 89 pass unchanged. **Swept and classified as non-defects:** a confidential document stays hidden through a link (its own clause); another tenant's document (refused by the composite foreign key); re-tenanting a link and a link with no target (refused by RLS and the single-target CHECK); a trainee without `UPLOAD_DOCUMENT` and an `aal1` owner (refused by `guard_write_capability` and step-up); no DELETE grant; caller-supplied `created_at` on INSERT is read by nothing that decides (SPEC-216's schema-wide question). 0 hosted links and documents. |
   ```

   The resulting file's Git blob is 57392a42d2d6879b77c0d2016cb10e1735028afc.

6. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–5 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the migration and test 165, which must equal Consumer Closure;
   - on the local stack holding the migration: the guard's and the emitter's `md5(prosrc)`, security mode and ACL, the triggers of `document_links`, and the catalog count; test 165 and tests 28, 82 and 48 alone; the probes; mutants M1–M4, the restored shape proven equal;
   - the causal negative on a local stack without the migration, then the stack restored with it;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
   - the API-contract generator, whose output must equal `MASTER_API_CONTRACT.md`; the map generator, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary and the six measured-state items of Consumer Closure.

   Read a fresh Primary baseline, read-only: the project URL, the full ordered ledger and the absence of the target migration; the function and structural surfaces; the triggers of `document_links` and the absence of both functions; the tenant, document and link counts. Record the predicted delta. If any reading differs, stop.
7. **Check** that an exact-SHA Gate-2 record for the migration is in the Execution Log: the owner's own, or one marked DELEGATED naming this contract, the migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If absent, write it only when Step 6 passed and those instructions cover a migration that drops no table or column and deletes or rewrites no business row; otherwise stop after Step 6 and present the Gate-2 package.
8. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261112150000_a_document_is_linked_only_by_someone_who_can_read_it`. If it is absent and Step 7 is recorded:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the triggers of `document_links`.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of `document_links`; both functions' `md5(prosrc)`, security mode and ACL; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
9. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the client RPC figure unchanged.
   - Confirm that `supabase/tests` holds 165 files whose literal `plan(N)` values sum to 3117, then set `Suite **165 files / 3117 assertions**`. If either differs, stop.
   - In each of the two rows DOC-9 and DOC-10 of the register, replace the text `` | 🛡 | **FIXED 2026-11-12 locally (SPEC-306, `20261112150000`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-12 (SPEC-306, `20261112150000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-306; the fresh Primary ledger, functions and structure equal local.** `` (each span's one leading and one trailing space are delimiters, not text). Change nothing else in the register.
   - Regenerate `MASTER_API_CONTRACT.md`, which must not change, and `ai-map.json` and `repository-index.md` (stored LF) with the canonical generators.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.

   If Primary is unproven, stop.
10. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [x] The migration is the frozen bytes; `check: blob supabase/migrations/20261112150000_a_document_is_linked_only_by_someone_who_can_read_it.sql f61e88618e7092a2eb13d78fb42f08820b2c80f0`
- [x] Test 165 is the frozen bytes; `check: blob supabase/tests/165_a_document_is_linked_only_by_someone_who_can_read_it_test.sql 3628685dd2c90e7aa0e8f2979fd36ccc9327177d`
- [x] Canon 27 says what `document_linked` now also records; `check: has _ORVION_CANONICAL/27_event_catalog.md "and when a link is moved by UPDATE to another document or target"`
- [x] The disposition record carries `document_links` AUDITED / ADVERSARIAL and coverage 51 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 57392a42d2d6879b77c0d2016cb10e1735028afc`
- [x] DOC-9 and DOC-10 are fixed and deployed in the register; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-306"`
- [x] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **165 files / 3117 assertions**"`
- [x] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @789e05660930d98df678dd9a1ba90bc08bfb5c15`
- [x] The document read scope migration remains exact; `check: same supabase/migrations/202607052300_document_read_scope.sql @789e05660930d98df678dd9a1ba90bc08bfb5c15`
- [x] The generated API contract remains exact; `check: same reports/master/MASTER_API_CONTRACT.md @789e05660930d98df678dd9a1ba90bc08bfb5c15`
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write, after a recorded Step 6 readiness gate and Step 7 Gate-2 record; Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] Mutants M1–M4 are each killed with installation proven and the restored shape read, and the causal negative is recorded.

## Execution Log

### 2026-11-12 — Steps 1–5 applied

- **Lifecycle:** allocate `d08a944`, Approve `8c917ee` (APPROVAL_EVIDENCE PASS; 9 of 11 criteria Gate-checked), DELEGATED Gate 1 recorded in Verification Notes.
- **Steps 1–5** by the literal-step replay, each result at its pinned blob: migration `f61e88618e7092a2eb13d78fb42f08820b2c80f0`, test 165 `3628685dd2c90e7aa0e8f2979fd36ccc9327177d`, canon 27 `609c2a90947eb29b7e56ca7aa5ceecfd2832ae98`, register `3048e1ceeac1c0131febd63bf0d4fb09e861ff80`, disposition `57392a42d2d6879b77c0d2016cb10e1735028afc`; 0 mismatches. Uncommitted until Step 9: the pre-commit guard refuses the measured-state items before the deploy.

### 2026-11-12 — Pre-deploy readiness gate (Step 6)

From the main checkout at HEAD `8c917ee`, Steps 1–5 applied and uncommitted, project-local CLI 3.0.0, the local stack recreated by the rig, one logged script (17:33–17:35 Cairo):
- **Bytes.** Migration SHA-256 `5bfb8e52155d367b5aab3e516e7b295d2ea30b3f0589df935396cbd0a37af9f3`, md5 `149882262bc6f900927121fcc13005b4`, 4684 bytes; test 165 SHA-256 `0d20b1d701ed1e351b6613cbdecc371cb2a26a7f786e6ab1def8a92aa3b7612e`, md5 `a27697b8d7f1ad5f5812e7605f6f78e7`, 12594 bytes; both LF (0 CR) and ASCII. Equal to Consumer Closure.
- **Causal negative.** `db reset --version 20261111150000`: 259 migrations, ledger `cfd3fcd7719bb2b519efd4bf700636ac`; both functions absent, three triggers on `document_links`; catalog 71/626. Test 165 FAIL at assertion 1 (the functions are absent). Probes: the Giza employee links Suez's passport scan and invoice onto their own booking, and re-points their own ticket link at the scan, and reads each document, its version and its storage path; a confidential document stays hidden; a moved ticket link leaves the events unchanged. DOC-9 and DOC-10 reproduced.
- **Fingerprints** (`scripts/parity_surface.sql`). Before (259): functions `e11c0124eec937fa08c1f7fe567b1249`/339, triggers `b5c21e213844e603ed5e1a6f9b0be455`/326, `_combined` `0e398aeac8e622fabeda83ac1900bf9d`/3156. After a clean reset (260, latest `20261112150000`, ledger `5f6e412ee282edaf1e16346c3d5b5805`): functions `73b0bbffade0a788aff53c10266a97dc`/341, triggers `8f39469bf723f0ea53cccb3c96fb65fd`/328, `_combined` `4a7b00b15007fbdb9072203d1f46ad19`/3160; the other eight surfaces unchanged. Guard `md5(prosrc)` `692eee1f6c5a0944a5d06e18f5a3a655`, SECURITY INVOKER; emitter `57bdf4c9574caf29f59c651b32dc7888`, SECURITY DEFINER; each ACL `{postgres=X/postgres}`; triggers `document_links_guard_document_readable` and `document_links_emit_move` added; catalog 71/626.
- **Focused tests:** 165 16/16, 28 10/10, 82 21/21, 48 12/12, each PASS. Probes on the final bytes: the three links and the re-point refused ("a document can be linked only by someone who can already read it"), the moved ticket link recorded once (events 12 → 13), the RPC upload still links and records (events +2), the `aal2` owner links, the `aal1` owner refused (MFA).
- **Mutants**, each proven installed and restored: M1 (guard trigger dropped) 165 fails 1, 4–7, 12, 13; M2 (guard as SECURITY DEFINER) 2, 4–7, 12, 13; M3 (emitter dropped) 1, 12, 13; M4 (emitter records a no-change update) 13; the causal negative (both triggers dropped) 1, 4–7, 12, 13. All killed; the restored shape equal (guard `dcb651fa…`, invoker, emitter `910d0cfb…`, 5 triggers).
- **Generators, scope and diff.** The API-contract generator reproduces `MASTER_API_CONTRACT.md` exactly, as Consumer Closure states; `generate-ai-map.ps1 -Check` exit 0. Only the five Step 1–5 paths changed; `git diff --check` clean.
- **Consistency:** exactly the six expected pre-deploy items, the same as the sandbox: 259 vs 260 migrations, latest, ledger fingerprint, 164 vs 165 files, 3101 vs 3117 assertions, RECOVER-1 (Primary evidence).
- **Fresh Primary baseline**, read-only (15:42 UTC by the server clock; the grants surface through the Primary write connector inside `BEGIN TRANSACTION READ ONLY`): URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 259 `cfd3fcd7719bb2b519efd4bf700636ac`, latest `20261111150000`, target absent by version and by name; both functions absent; `document_links` triggers `document_links_derive_created_by`, `document_links_enforce_document_subscription_gate`, `document_links_guard_write_capability`; `document_linked` at 56; catalog 71/626; 0 tenants, 0 documents, 0 links, 0 events. `parity_surface.sql`: every surface equal to the local stack at 259, `_combined` `0e398aeac8e622fabeda83ac1900bf9d`/3156, equal to the recorded evidence.
- **Predicted delta:** ledger 260 `5f6e412e…`; functions `73b0bbff…`/341; triggers `8f39469b…`/328; `_combined` `4a7b00b1…`/3160; guard `692eee1f…`; emitter `57bdf4c9…`; the two new triggers; catalog 71/626 unchanged; business counts unchanged.

### 2026-11-12 — Gate 2 (Step 7), DELEGATED

DELEGATED exact-SHA Gate-2 record for SPEC-306: migration `supabase/migrations/20261112150000_a_document_is_linked_only_by_someone_who_can_read_it.sql`, SHA-256 `5bfb8e52155d367b5aab3e516e7b295d2ea30b3f0589df935396cbd0a37af9f3`, md5 `149882262bc6f900927121fcc13005b4`, 4684 bytes, to Primary `vrvtsxexkiiiivlkdxzp` only, under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo), 2026-11-11 (Batch 6 decisions 1-9 ~19:50 Cairo) and 2026-11-12 (priority order waiving no gate ~12:20 Cairo; slice 8 in run mode 2 ~17:02 Cairo), recorded outside this repository. Step 6 passed. The migration's top-level statements are two `create or replace function`, each with its `revoke`, and two `create trigger`: it drops no table or column and deletes or rewrites no business row. Not a human-typed digest. Secondary `brplkqmbzffpxqgkkdzo` is not a target.

### 2026-11-12 — Primary deployment (Step 8)

Through the Primary write connector from this VS Code session, 15:43–15:44 UTC by the server clock; Secondary `brplkqmbzffpxqgkkdzo` not contacted:
- **Immediate re-read, exact match** (inside `BEGIN TRANSACTION READ ONLY`, 15:43:44 UTC). HEAD `8c917ee89b0646f81ec08c6bcfb0d12165c4aaf8`; migration SHA-256 `5bfb8e52155d367b5aab3e516e7b295d2ea30b3f0589df935396cbd0a37af9f3`, md5 `149882262bc6f900927121fcc13005b4`, 4684 bytes, LF, ASCII; URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 259 `cfd3fcd7719bb2b519efd4bf700636ac`, latest `20261111150000`, target absent by version and by name; both functions absent; triggers of `document_links` as in Step 6; 0 tenants, 0 documents, 0 links, 0 events.
- **Transmitted text** proven server-side in the same read: `md5` `149882262bc6f900927121fcc13005b4`, equal to the file. Applied once with `apply_migration` (`a_document_is_linked_only_by_someone_who_can_read_it`).
- **Guarded rename.** The connector stored version `20261112154358`: exactly one new row, one stored statement with md5 `14988226…` and 4684 bytes, no existing target. One guarded `UPDATE` (row count required 1) renamed it to `20261112150000`.
- **Fresh reads** (15:44:21 UTC). Ledger 260 `5f6e412ee282edaf1e16346c3d5b5805`, latest `20261112150000`, equal to the migration files; `parity_surface.sql`: functions `73b0bbffade0a788aff53c10266a97dc`/341, triggers `8f39469bf723f0ea53cccb3c96fb65fd`/328, the other eight surfaces unchanged, `_combined` `4a7b00b15007fbdb9072203d1f46ad19`/3160, each equal to the local stack after a clean reset; guard `md5(prosrc)` `692eee1f6c5a0944a5d06e18f5a3a655`, SECURITY INVOKER, and emitter `57bdf4c9574caf29f59c651b32dc7888`, SECURITY DEFINER, each ACL `{postgres=X/postgres}`; triggers `document_links_guard_document_readable` (BEFORE INSERT OR UPDATE) and `document_links_emit_move` (AFTER UPDATE) added to the three; catalog 71/626 with `document_linked` at 56; 0 tenants, 0 documents, 0 links, 0 events. No business row was written.

### 2026-11-12 — Post-deploy records (Step 9)

- `reports/evidence/primary-ledger-evidence.json` from the Step 8 readings only (read 2026-11-12T15:44:21Z): 260 entries whose fingerprint recomputes to `5f6e412e…`, functions `73b0bbff…`/341, structure `4a7b00b1…`/3160.
- Manifest `Live state` set from the same readings; the client RPC figure unchanged. `supabase/tests` holds 165 files whose literal `plan(N)` sum to 3117; `Suite **165 files / 3117 assertions**`.
- DOC-9 and DOC-10 register rows replaced with the DEPLOYED text, nothing else changed.
- `MASTER_API_CONTRACT.md` regenerated byte-identical (80 RPC endpoints), as Consumer Closure states; `ai-map.json` and `repository-index.md` regenerate byte-identical, LF. Repository consistency CLEAN.
- Runtime Checkpoint DONE; Status Approved → In Progress; one implementation commit.
## Verification Notes

None.


### 2026-11-12 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo), 2026-11-11 (Batch 6 decisions 1-9 ~19:50 Cairo) and 2026-11-12 (priority order waiving no gate ~12:20 Cairo; slice 8 in run mode 2 ~17:02 Cairo); Draft SHA-256 D4725E3B87816DFDC5D442FC5B8C094189E9C27E2C9EF9A7CB94DF51D654EF2B, decision SHA-256 F15C55AF0CCC19FBE8B5C231C1213439E6BF2E59A4C26CB9FB9630EA2381B256. No fabricated human future-digest approval. Gate 2 (Primary deploy) is a separate exact-SHA record in Step 7. Immediately before allocation the hash, the Draft blob a8a7c3a10bd83102e303c016a04934b5206aa0e9, all 3 source anchors, the baseline HEAD 789e05660930d98df678dd9a1ba90bc08bfb5c15 against refreshed origin/main 789e05660930d98df678dd9a1ba90bc08bfb5c15 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as d08a944. No implementation performed before this transition.


Verdict: Confirmed Complete

Independent current Git evidence: selected Draft D4725E3B87816DFDC5D442FC5B8C094189E9C27E2C9EF9A7CB94DF51D654EF2B, allocated blob a8a7c3a10bd83102e303c016a04934b5206aa0e9, the five literal outputs (migration, test 165, canon 27, register and disposition), the recorded Step 6 readiness gate, the DELEGATED exact-SHA Gate-2 record, the Primary deploy of only 20261112150000 to vrvtsxexkiiiivlkdxzp with the fresh post-deploy ledger, functions and structure equal to local, the Step 9 records (ledger evidence, manifest Live state and suite 165/3117, DOC-9 and DOC-10 DEPLOYED, API contract identical), regenerated discovery, unchanged native evaluator, document read scope migration and API contract, and declared scope verified; Secondary was never contacted. This original root owns fresh receipt 88b4d8fb99758da732cedc5af658fe0eacde8e4073acf87f470f0e44d0b3b989, finishHead f96318fbea22213d84ef726e410a63e29b023c45, profiles DATABASE,REPOSITORY, in a native timed/watched Finish observed READY/END0. Native Complete/range/binder still own full receipt/criterion validation. No publication or hosted result asserted.


Local original native verification and truthful Review complete. Preserve this root's receipt 88b4d8fb99758da732cedc5af658fe0eacde8e4073acf87f470f0e44d0b3b989 and selected bytes. Candidate binding follows Complete; publication/promotion remain separately governed.

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-306: Batch 6 Slice 50 — a document is linked only by someone who can read it, and a moved link is recorded (DOC-9, DOC-10), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline 789e05660930d98df678dd9a1ba90bc08bfb5c15 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `_ORVION_CANONICAL/27_event_catalog.md` | `433cb885bcad27ad194dac6533eaaf9e68574646` |
| `reports/master/MASTER_GAP_REGISTER.md` | `d37c92ccd018b1dae15b9538f2d2cc347446ae4a` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `02e45e273f4bcf374b3633751464981c2cba8d49` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md, SPEC-144 and SPEC-301 at 789e05660930d98df678dd9a1ba90bc08bfb5c15; the owner's instructions of 2026-11-08 and 2026-11-12 (recorded outside this repository). This is the one Draft for this surface, finalized after the adversarial review and the evidence refresh its Draft Assurance records; correctness remains native and independent.
