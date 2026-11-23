# Change Request — SPEC-333

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Give the one member-writable door that no test writes through its targeted negative test, under the CRM `B6-EXIT` criterion EC-6. A sweep of the 101 doors on which `authenticated` holds INSERT, UPDATE or DELETE at 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1 finds exactly one without a test: UPDATE on `customer_contact_methods`. One pgTAP test (Test 189) proves that door's seven controls refuse what they exist to refuse, and the EC-6 reading cites the sweep.

## Business Reason

EC-6's exit requires every security- or integrity-sensitive surface to have at least one negative test, not merely a positive one. At 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1 (277 migrations) the 188 test files write through 100 of the 101 member-writable doors (52 INSERT, 49 UPDATE, no DELETE). The customer contact-method UPDATE door carries seven controls, and no test exercises any of them on UPDATE: the tenant policy, the customer foreign key, value normalization, one primary per channel, the active-catalog trigger, the write-capability trigger and the subscription write gate. A control that no test touches can be dropped and the whole suite still passes (DEC-33 rule 9).

## Risks

A refusal could come from a different control than the one named, so each mutation removes exactly one control and the assertion that names it must fail. A test could pass because every update is refused, so assertion 1 is a positive control and assertions 12 and 14 read back the unchanged value. A cross-tenant write could be refused silently, so assertions 13 and 14 prove the other tenant sees nothing and changes nothing. This contract changes no migration, function, policy, grant or database object, and no exit criterion is marked met: whether each tested door pins every negative case stays with the gate evaluation, so EC-6 stays partial.

## Supersedes / Depends On

Extends the SPEC-332 business-key proof (Test 188) and the SPEC-218 contact event parity (Test 124, migration `20260924160000`). Uses the existing controls on `public.customer_contact_methods`. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-333-a-contact-method-change-is-refused-at-the-update-door.md`
- `supabase/tests/189_a_contact_method_change_is_refused_at_the_update_door_test.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md` the exit criterion EC-6.
- `reports/master/MASTER_SURFACE_DISPOSITION.md` the `customer_contact_methods` row.
- `supabase/tests/124_customer_contact_event_parity_test.sql`.
- `supabase/tests/188_every_business_key_is_unique_and_every_event_type_is_registered_test.sql`.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1
- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: One new pgTAP test, Test 189, with a two-tenant fixture rolled back at the end. It declares its attack classes for Check 24. Assertions 1–2 are the positive control: an employee with CREATE_CUSTOMER changes a phone value and its verification, and both persist. Assertions 3–10 refuse a tenant move, a foreign customer, an unnormalized email and phone, a second primary, and an unregistered, retired and other-tenant channel. Assertions 11–12 refuse a trainee without CREATE_CUSTOMER and read back the unchanged value. Assertions 13–14 prove the other tenant neither sees nor changes the row. Assertion 15 refuses a write under a lapsed subscription. The plan and manifest record the result.

Pass 2 Adversarial Review: Applied in a rolled-back transaction, a mutation set failed every one of the 15 assertions. It refused the positive update, widened the tenant policy to admit the other tenant, dropped the customer foreign key, the normalization check and the one-primary index, disabled the catalog, capability and subscription triggers, and opened the policy to every tenant. The unmutated database passes all 15.

Pass 3 Evidence Refresh: 2026-11-23. In an isolated clone at 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1 carrying the payload:
- Test 189 passed 15 of 15 on the local stack (277 migrations), and the mutation set failed 15 of 15.
- `readiness_population.ps1` reported REGISTRY complete with no COMPLETED member.
- Native repository consistency was CLEAN.
- All five hosted guard suites passed with 0 failed.

Selected Version: SPEC-333; selected: one adversarial pgTAP test for the only member-writable door no test wrote through at 2f8c19a, UPDATE on customer_contact_methods, with the plan and manifest records, the smallest change that closes the one untested door the EC-6 sweep found without any database change

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Contact-method update-door proof | Full pgTAP suite, Check 24 and the `B6-EXIT` gate evaluation | WRITE | Test 189 adds 15 assertions and names its attack classes; the suite grows to 189 files and 3506 assertions. |
| EC-6 reading | Exit criteria | WRITE | It cites the door sweep and Test 189; no criterion is marked met. |
| Surface disposition and register | Check 22 and Check 29 | UNAFFECTED | The `customer_contact_methods` row is already AUDITED / ADVERSARIAL; no finding is added. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Check 24 and the five hosted guard suites pass | BEFORE_COMPLETION | 1 | 3 | 4 |
| Full DATABASE readiness with Test 189 | BEFORE_COMPLETION | NONE | NONE | 4 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The pgTAP suite and its behavioural precedents, `supabase/tests/124_customer_contact_event_parity_test.sql` for the contact-method fixture and `supabase/tests/188_every_business_key_is_unique_and_every_event_type_is_registered_test.sql` for the mutation-proven form.

Added Property: On UPDATE, `customer_contact_methods` refuses a tenant move, a foreign customer, an unnormalized value, a second primary per channel, a channel that is not active in the tenant's catalog, a member without CREATE_CUSTOMER, a cross-tenant write and a write under a lapsed subscription, while admitting an authorized change.

Causal Negative: At 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1, dropping any of the door's seven controls on UPDATE passes the whole suite.

Positive Test Design: On the unmutated database Test 189 passes 15 of 15.

Negative Test Design: In a rolled-back transaction, each mutation fails its assertion: the positive update is refused, the policy admits the other tenant and then every tenant, the foreign key, the normalization check and the one-primary index are dropped, and the catalog, capability and subscription triggers are disabled.

Non-Empty Population Obligation: The fixture holds two tenants on the `enterprise` plan, an employee and a trainee in the first tenant and an employee in the second, a customer in each tenant, one retired channel and one other-tenant channel, and three contact methods; assertion 1 fails on an empty population.

Mutation Obligation: The mutation set above must fail all 15 assertions.

Post-Implementation Proof Obligation: The native Finish runs the full DATABASE protocol with Test 189 and all five hosted guard suites through Additional Verification with zero failures. Hosted preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `supabase/tests/189_a_contact_method_change_is_refused_at_the_update_door_test.sql` contains `select plan(15);`; if so record Already Applied when its Git blob is 85f9d02296a20357411b5df659b9eeab9bb3d36e, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the contact-method update-door test), and change nothing else:

   ```text
   -- pgTAP: Batch 6 exit -- a contact method change is refused at the UPDATE door for every rule its INSERT door keeps.
   --
   -- EC-6: every sensitive path needs a targeted negative test. Swept at `2f8c19a` (CRM SPEC-332), the only
   --   member-writable table door with no test aimed at it is UPDATE on public.customer_contact_methods: authenticated
   --   holds UPDATE, the tenant_isolation policy covers it, and seven controls stand on it (the RLS
   --   WITH CHECK, the tenant-bound customer key, the value_normalized check, the one-primary-per-type index, the
   --   enforce_catalog_codes trigger, the guard_write_capability trigger and the subscription write gate), yet every
   --   existing contact test (124 and the customer door tests) writes through INSERT only.
   --   Assertions 1-2 are the positive control: an employee changes a value and its verification. Assertions 3-12
   --   attack the same door as that employee and as a trainee: a move to another tenant, a move to another tenant's
   --   customer, a value that is not normalized (email and phone), a second primary, and a type code that is unknown,
   --   inactive in its own tenant or active only in another tenant; a trainee without CREATE_CUSTOMER is refused and
   --   the row stays as it was. Assertions 13-14 prove another tenant neither sees nor changes the row. Assertion 15
   --   proves a lapsed subscription refuses the change. No migration: each control already holds (PROVEN on the local
   --   stack before this test was written); this test pins them so a later change cannot drop one unseen.
   -- ATTACK-CLASSES: AUTH TENANT DOOR INPUT PRIVILEGE BUSINESS STATE CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(15);

   insert into auth.users (id, email, email_confirmed_at) values
     ('c1890000-0000-0000-0000-0000000000a1','employee@a189.test', now()),
     ('c1890000-0000-0000-0000-0000000000a2','trainee@a189.test', now()),
     ('c1890000-0000-0000-0000-0000000000b1','employee@b189.test', now());
   insert into public.tenants (id, name, slug, status) values
     ('c1890000-0000-0000-0000-000000000001','A189 Travel','a189-travel','active'),
     ('c1890000-0000-0000-0000-000000000002','B189 Travel','b189-travel','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select t.id, sp.id, 'active'
     from (values ('c1890000-0000-0000-0000-000000000001'::uuid), ('c1890000-0000-0000-0000-000000000002'::uuid)) t(id)
    cross join public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('c1890000-0000-0000-0000-00000000000a','c1890000-0000-0000-0000-000000000001','Main A','a189-main'),
     ('c1890000-0000-0000-0000-00000000000b','c1890000-0000-0000-0000-000000000002','Main B','b189-main');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('c1890000-0000-0000-0000-0000000000da','c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-00000000000a','sales','Sales'),
     ('c1890000-0000-0000-0000-0000000000db','c1890000-0000-0000-0000-000000000002','c1890000-0000-0000-0000-00000000000b','sales','Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('c1890000-0000-0000-0000-000000000011','c1890000-0000-0000-0000-000000000001','Employee A','employee@a189.test',true,'c1890000-0000-0000-0000-0000000000a1'),
     ('c1890000-0000-0000-0000-000000000012','c1890000-0000-0000-0000-000000000001','Trainee A','trainee@a189.test',true,'c1890000-0000-0000-0000-0000000000a2'),
     ('c1890000-0000-0000-0000-000000000021','c1890000-0000-0000-0000-000000000002','Employee B','employee@b189.test',true,'c1890000-0000-0000-0000-0000000000b1');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-000000000011','c1890000-0000-0000-0000-00000000000a','c1890000-0000-0000-0000-0000000000da',true),
     ('c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-000000000012','c1890000-0000-0000-0000-00000000000a','c1890000-0000-0000-0000-0000000000da',true),
     ('c1890000-0000-0000-0000-000000000002','c1890000-0000-0000-0000-000000000021','c1890000-0000-0000-0000-00000000000b','c1890000-0000-0000-0000-0000000000db',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.t, v.u, r.id, 'tenant'
     from (values ('c1890000-0000-0000-0000-000000000001'::uuid,'c1890000-0000-0000-0000-000000000011'::uuid,'employee'),
                  ('c1890000-0000-0000-0000-000000000001'::uuid,'c1890000-0000-0000-0000-000000000012'::uuid,'trainee'),
                  ('c1890000-0000-0000-0000-000000000002'::uuid,'c1890000-0000-0000-0000-000000000021'::uuid,'employee')) v(t, u, code)
     join public.roles r on r.code = v.code;
   insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
     ('c1890000-0000-0000-0000-0000000000c1','c1890000-0000-0000-0000-000000000001','person','A189 Customer','+201000018901'),
     ('c1890000-0000-0000-0000-0000000000c2','c1890000-0000-0000-0000-000000000002','person','B189 Customer','+201000018902');
   insert into public.catalog_values (tenant_id, catalog_type_code, code, label, is_active) values
     ('c1890000-0000-0000-0000-000000000001','contact_method_type','a189_retired','A189 retired channel',false),
     ('c1890000-0000-0000-0000-000000000002','contact_method_type','b189_only','B189 own channel',true);
   insert into public.customer_contact_methods (id, tenant_id, customer_id, contact_method_type_code, value, is_primary) values
     ('c1890000-0000-0000-0000-0000000000e1','c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-0000000000c1','primary_phone','+201000018911',true),
     ('c1890000-0000-0000-0000-0000000000e2','c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-0000000000c1','primary_phone','+201000018912',false),
     ('c1890000-0000-0000-0000-0000000000e3','c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-0000000000c1','email','a189@example.com',false);

   -- The employee of tenant A works through the authenticated door.
   select set_config('request.jwt.claims', '{"sub":"c1890000-0000-0000-0000-0000000000a1"}', true);
   set local role authenticated;

   -- 1-2. Positive control: an employee changes a contact value and its verification, and the change is kept.
   select lives_ok(
     $$update public.customer_contact_methods set value = '+201000018921', is_verified = true
        where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
     'an employee changes a contact value and its verification through the UPDATE door (positive control)'
   );
   select is(
     (select value || ' ' || is_verified::text from public.customer_contact_methods where id = 'c1890000-0000-0000-0000-0000000000e2'),
     '+201000018921 true',
     'the changed value and verification are kept'
   );

   -- 3. TENANT: a contact method cannot be moved into another tenant.
   select throws_ok(
     $$update public.customer_contact_methods set tenant_id = 'c1890000-0000-0000-0000-000000000002'
        where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
     '42501', 'new row violates row-level security policy for table "customer_contact_methods"',
     'TENANT: a contact method cannot be moved into another tenant'
   );

   -- 4. TENANT: a contact method cannot be moved onto another tenant's customer.
   select throws_ok(
     $$update public.customer_contact_methods set customer_id = 'c1890000-0000-0000-0000-0000000000c2'
        where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
     '23503', null,
     'TENANT: a contact method cannot be moved onto another tenant''s customer'
   );

   -- 5-6. INPUT: a changed value must stay in normal form.
   select throws_ok(
     $$update public.customer_contact_methods set value = 'A189@Example.COM'
        where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
     '23514', null,
     'INPUT: an email changed to a value that is not normalized is refused'
   );
   select throws_ok(
     $$update public.customer_contact_methods set value = '+20 100 001 8931'
        where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
     '23514', null,
     'INPUT: a phone changed to a value that is not normalized is refused'
   );

   -- 7. BUSINESS: a change cannot make a second primary of the same type.
   select throws_ok(
     $$update public.customer_contact_methods set is_primary = true
        where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
     '23505', null,
     'BUSINESS: a change that makes a second primary phone for the customer is refused'
   );

   -- 8-10. INPUT and TENANT: a changed type code must be active in the row's own tenant catalog.
   select throws_matching(
     $$update public.customer_contact_methods set contact_method_type_code = 'telegram'
        where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
     '"telegram" is not an active value of catalog family "contact_method_type"',
     'INPUT: a type code the catalog does not hold is refused'
   );
   select throws_matching(
     $$update public.customer_contact_methods set contact_method_type_code = 'a189_retired'
        where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
     '"a189_retired" is not an active value of catalog family "contact_method_type"',
     'INPUT: a type code that is inactive in the own tenant catalog is refused'
   );
   select throws_matching(
     $$update public.customer_contact_methods set contact_method_type_code = 'b189_only'
        where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
     '"b189_only" is not an active value of catalog family "contact_method_type"',
     'TENANT: a type code active only in another tenant catalog is refused'
   );

   -- 11-12. AUTH and PRIVILEGE: a trainee without CREATE_CUSTOMER cannot change a contact, and the row stays.
   select set_config('request.jwt.claims', '{"sub":"c1890000-0000-0000-0000-0000000000a2"}', true);
   select throws_ok(
     $$update public.customer_contact_methods set value = '+201000018941'
        where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
     '42501', 'permission denied: one of CREATE_CUSTOMER is required to write customer_contact_methods',
     'PRIVILEGE: a trainee without CREATE_CUSTOMER cannot change a contact method'
   );
   reset role;
   select is(
     (select value from public.customer_contact_methods where id = 'c1890000-0000-0000-0000-0000000000e2'),
     '+201000018921',
     'AUTH: the refused trainee change left the contact value as it was'
   );

   -- 13-14. TENANT: another tenant's employee neither sees nor changes the row.
   select set_config('request.jwt.claims', '{"sub":"c1890000-0000-0000-0000-0000000000b1"}', true);
   set local role authenticated;
   select is(
     (select count(*)::int from public.customer_contact_methods where tenant_id = 'c1890000-0000-0000-0000-000000000001'),
     0,
     'TENANT: another tenant''s employee sees no contact method of tenant A'
   );
   update public.customer_contact_methods set value = '+201000018951' where id = 'c1890000-0000-0000-0000-0000000000e2';
   reset role;
   select is(
     (select value from public.customer_contact_methods where id = 'c1890000-0000-0000-0000-0000000000e2'),
     '+201000018921',
     'TENANT: another tenant''s employee changes no contact method of tenant A'
   );

   -- 15. STATE: a lapsed subscription refuses the change and keeps reads.
   update public.subscriptions set subscription_status_code = 'expired' where tenant_id = 'c1890000-0000-0000-0000-000000000001';
   select set_config('request.jwt.claims', '{"sub":"c1890000-0000-0000-0000-0000000000a1"}', true);
   set local role authenticated;
   select throws_ok(
     $$update public.customer_contact_methods set value = '+201000018961'
        where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
     '42501', 'subscription state "expired" does not permit writes on public.customer_contact_methods (reads remain available so the tenant can inspect and export its own data)',
     'STATE: a lapsed subscription refuses a contact method change'
   );
   reset role;

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 85f9d02296a20357411b5df659b9eeab9bb3d36e.

2. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-23 (CRM exit bundle H, SPEC-333.`; if so record Already Applied when its Git blob is 3e5a77c722aaa1bd496b6c6e0cc282d8528429bc, and otherwise stop and report. Otherwise make exactly these 4 edits (the EC-6 reading cites the door sweep and Test 189, and the dated SPEC-333 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-23 (CRM exit bundle G, SPEC-332. Test 188 proves R8/B3 and N1: the five business keys are validated, each refuses a duplicate inside its owner and admits it in another tenant, and `app.record_event` refuses an unregistered event type and severity. DC-5, RC-4 and RC-1 are settled on their existing tests, so the six-finding registry row leaves.)
   ```
   with
   ```text
   Last updated: 2026-11-23 (CRM exit bundle H, SPEC-333. The EC-6 door sweep at `2f8c19a` finds one member-writable door that no test writes through, UPDATE on `customer_contact_methods`. Test 189 proves that door refuses a tenant move, a foreign customer, an unnormalized value, a second primary, an unregistered, retired or foreign channel, a member without CREATE_CUSTOMER, a cross-tenant write and a lapsed subscription.)

   Previously: 2026-11-23 (CRM exit bundle G, SPEC-332. Test 188 proves R8/B3 and N1: the five business keys are validated, each refuses a duplicate inside its owner and admits it in another tenant, and `app.record_event` refuses an unregistered event type and severity. DC-5, RC-4 and RC-1 are settled on their existing tests, so the six-finding registry row leaves.)
   ```

   b) replace the line
   ```text
   **CRM exit evidence at `5bed4ed`, measured 2026-11-23 (SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```
   with
   ```text
   **CRM exit evidence at `2f8c19a`, measured 2026-11-23 (SPEC-333, Test 189; SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```

   c) replace the line
   ```text
   - **EC-6 (partial):** Check 24 admits the recorded adversarial labels. Verify that every sensitive path has a targeted negative test. Retain the existing evaluation and delivery triggers for the three partial surfaces. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision.
   ```
   with
   ```text
   - **EC-6 (partial):** Check 24 admits the recorded adversarial labels. SPEC-333 sweeps the 101 member-writable doors at `2f8c19a` (52 INSERT, 49 UPDATE, no DELETE): exactly one, UPDATE on `customer_contact_methods`, had no test writing through it, and Test 189 is its targeted negative test across seven controls. The sweep finds untested doors; whether each tested door pins every negative case stays with the gate evaluation. Retain the existing evaluation and delivery triggers for the three partial surfaces. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision.
   ```

   d) immediately after the lines
   ```text
   **Recorded exception, 2026-11-23, CRM exit bundle G.** After CRM SPEC-331 at `5bed4ed52cf3612b58c73b09f054b296c968bcf5`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-332 adds Test 188, which proves the five R8/B3 business keys and the N1 event registry, the two of the six terminal-in-substance findings that had no test. The other four are settled on their existing tests, the five register rows carry settled statuses with their superseded text, and the registry row leaves. It changes no migration or database object. The Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-23, CRM exit bundle H.** After CRM SPEC-332 at `2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-333 adds Test 189, the targeted negative test of the one member-writable door the EC-6 sweep found untested, UPDATE on `customer_contact_methods`, and the EC-6 reading cites the sweep. It changes no migration or database object, and EC-6 stays partial. The Original and release gates remain enforced.

   ```

   The resulting file's Git blob is 3e5a77c722aaa1bd496b6c6e0cc282d8528429bc.

3. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **189 files / 3506 assertions**.`; if so record Already Applied when its Git blob is bb7314e9e0e2bc86d8aa3412607ae0cfa6a746f9, and otherwise stop and report. Otherwise make exactly this one edit (the measured suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **188 files / 3491 assertions**.
   ```
   with
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **189 files / 3506 assertions**.
   ```

   The resulting file's Git blob is bb7314e9e0e2bc86d8aa3412607ae0cfa6a746f9.

4. **Establish readiness and verify.** Run the native DATABASE readiness: full SQL tests at 277 migrations with 189 files and 3506 assertions including Test 189 at 15 of 15, smoke and HTTP, and API generation with the API contract unchanged. Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no COMPLETED member. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-333: A contact-method change is refused at the update door.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] Test 189 proves the contact-method update door's seven controls. `check: blob supabase/tests/189_a_contact_method_change_is_refused_at_the_update_door_test.sql 85f9d02296a20357411b5df659b9eeab9bb3d36e`
- [ ] The EC-6 reading cites the door sweep and Test 189. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 3e5a77c722aaa1bd496b6c6e0cc282d8528429bc`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **189 files / 3506 assertions**"`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`
- [ ] The surface disposition is unchanged. `check: same reports/master/MASTER_SURFACE_DISPOSITION.md @2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`
- [ ] The gap register is unchanged. `check: same reports/master/MASTER_GAP_REGISTER.md @2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`
- [ ] The cold-start guard suite is preserved. `check: same scripts/test_cold_start_state_guard.ps1 @2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`
- [ ] Full DATABASE readiness and all five hosted guard suites pass in the native Finish; no exit criterion is marked met.

## Execution Log

None.


### 2026-11-23 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1 and every source anchor matched there; Draft allocated as a21083f and approved as e955978 with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `supabase/tests/189_a_contact_method_change_is_refused_at_the_update_door_test.sql` edited exactly as the step states; blob 85f9d02296a20357411b5df659b9eeab9bb3d36e (182 insertions, 0 deletions (created)).
- Step 3 Applied: `reports/master/MASTER_EXECUTION_PLAN.md` edited exactly as the step states; blob 3e5a77c722aaa1bd496b6c6e0cc282d8528429bc (7 insertions, 3 deletions).
- Step 4 Applied: `_ORVION_CANONICAL/manifest.md` edited exactly as the step states; blob bb7314e9e0e2bc86d8aa3412607ae0cfa6a746f9 (1 insertions, 1 deletions).
- Step 5 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-23 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-333 only under DEC-02 in the owner AFK Mode (owner-2026-11-23-modes-any-session.txt, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73), continuing Batch 6 under the owner OD-9 decision of 2026-11-22 (SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D). Exact Draft SHA-256 E103650BBB3A30F0A27340981A304F758D35970DC90D1F02DA683DCFCE771562, Git blob c7f8e40fa492ae26b90d4cca3349521b66bb2657, CRM baseline 2f8c19a. Native isolated Approve c3ca31f and implement 6cf113f passed with 3 committed blobs verified, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 5173E6EC8992142A1C8D27BD97C8299618920B189993E31D1E5EE563114528C9). One pgTAP test and records; no migration, no Primary write. Gate 1 only. Immediately before allocation the hash, the Draft blob c7f8e40fa492ae26b90d4cca3349521b66bb2657, all 2 source anchors, the baseline HEAD 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1 against refreshed origin/main 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as a21083f. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1 (SPEC-332 Complete and released; main is 2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1).

Authority: DELEGATED under the owner's AFK Mode, answered by the constitution; never typed by the owner. The owner's words of 2026-11-23, Workbench `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73, make AFK Mode a tool that decides by the project's rules and widens nothing; the owner's words of 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D, direct Batch 6 to finish first. This contract grants nothing beyond them. The door sweep is Workbench `data/records/batch6/exit-bundle-h/spec333/sweep/`.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `7a90aeb9aea0310a0a9726e5ff27e6c265e533bf` |
| `_ORVION_CANONICAL/manifest.md` | `a108028142374d26c6b2b9b6ef29785b762d0a04` |
