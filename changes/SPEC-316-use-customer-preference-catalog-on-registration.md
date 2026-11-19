# Change Request — SPEC-316

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Use the canonical customer communication preference catalog when registering a customer. The stored preference can be email, phone, social, WhatsApp or null on registration and edit.

## Business Reason

Canon 25 defines preferred_contact_method_code as the customer communication preference. The customer table already enforces it. The registration RPC instead checks contact_method_type, whose codes describe individual contact details. The intersection accepts email and WhatsApp and rejects phone and social at registration. The owner directive of 2026-11-19 requires the authoritative catalog to govern when existing policy decides the values. This is the ranked obligation carried from S17.

## Risks

The correction makes phone and social available at registration. An invalid detail code can now fail in the RPC before reaching the existing table trigger. The API signature, error for unknown input, authorization, grant, tenant scope, table trigger and stored rows are preserved. The current code and tests contain no caller requiring the old error order for the rejected detail codes. Primary deployment requires its own exact migration approval.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-316-use-customer-preference-catalog-on-registration.md`
- `supabase/migrations/20261119054533_use_customer_preference_catalog_on_registration.sql`
- `supabase/tests/79_customer_data_integrity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `_ORVION_CANONICAL/25_catalog_registry.md`
- `supabase/config.toml`
- `supabase/migrations/202607052100_duplicate_prevention.sql`
- `supabase/migrations/202607051300_complete_catalog_enforcement.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `scripts/check_agent_continuity.ps1`

## Required Reading

- `AGENTS.md`, `CR_LIFECYCLE.md`, and `ENGINEERING_METHOD.md`
- `_ORVION_CANONICAL/25_catalog_registry.md`, both contact families
- `supabase/migrations/202607052100_duplicate_prevention.sql` and `supabase/migrations/202607051300_complete_catalog_enforcement.sql`
- `supabase/tests/79_customer_data_integrity_test.sql` and S17's recorded contact-method probes

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

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Point the existing registration check at the seeded preference family. Keep the authoritative table check on both write paths. Extend existing customer integrity test 79 using its employee fixture.

Pass 2 Adversarial Review: Transplanting the contact-detail family into the table would change the canon and permit detail codes on edit. Adding a third validator would duplicate the native guard. The baseline test rejects phone and social while edit succeeds. The proposed change preserves the function's whole metadata, ACL and surrounding body and refuses detail codes and unknown input.

Pass 3 Evidence Refresh: 2026-11-19. Isolated clone at dd19c8095172b42d67e20c97b22e2114d082d345, pinned CLI 3.0.0. Baseline test 79 fails only 22, 23 and 25. The full suite passes 181 files and 3347 assertions with the migration, including 33/33 in test 79. The same native smoke passes 78 tables. Regenerated API contract is identical. The isolated ledger contains 271 migrations with fingerprint a7e29073df56d35463b6fce7e1a13f88, function hash 06dcbc81fc389bfa1d4d457eeac890b6 and structural hash d09b57f6f419d7c54a888c3a8c17c59c. Product baseline parity holds at the released S17 heads. Post-change hosted parity remains pending. Raw results are in the Workbench contact-preference packet.

Selected Version: SPEC-316; selected: a one-literal catalog-family correction with the existing table guard and customer integrity test

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Registration accepts the stored preference family | app.create_customer and its public invoker RPC | WRITE | Exact function and ACL comparison differs only at the catalog family. Test 79 proves every persisted value and null. |
| Direct edits | customers_enforce_catalog_codes and tenant write policy | VERIFY | Test 79 proves all four values and clearing, plus the refusal of a detail code. The table trigger and RLS are unchanged. |
| Contact details and identity matching | customer_contact_methods and identity signal consumers | UNAFFECTED | Separate catalog and no signature or side-effect change. Existing suite passes. |
| Published ledger and evidence | manifest, RECOVER-1, API and discovery projections, finding and disposition | WRITE | Record actual released state only from measured evidence. Native API generation is byte-identical. |
| Current Module and Next capability pinned manifest lines | Boot and the Batch 6 programme | UNAFFECTED | Both lines and their pins remain as written at the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 4 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact payload, local proof and fresh verified target before deployment | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 3 |
| Hosted parity and recorded ledger, generated artifacts and test count | BEFORE_COMPLETION | Step 1 | Step 5 | Step 6 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES
Existing Mechanism: Existing customer integrity pgTAP file, authenticated employee fixture, native CI and Finish.
Added Property: Registration and edit persist the same four canonical preferences.
Causal Negative: Baseline test 79 fails assertions 22, 23 and 25 when registration uses the detail catalog.
Positive Test Design: Persist all four codes and null through the public invoker. Update an existing visible customer to each value and clear it, asserting returned rows.
Negative Test Design: A valid detail code remains inadmissible as a preference on both paths. An unknown code is refused at registration.
Non-Empty Population Obligation: Test 79 verifies a real employee capability and inspects the stored customer rows and UPDATE RETURNING population.
Mutation Obligation: Reverting the family choice must reproduce the measured failure for phone and social.
Post-Implementation Proof Obligation: Require all 33 assertions of test 79 plus native database verification and hosted CI on the exact candidate.

## Implementation Steps

1. Check whether `supabase/migrations/20261119054533_use_customer_preference_catalog_on_registration.sql` contains `preferred_contact_method_code`; if so record Already Applied when its Git blob is 648f35f2ba93a9c69c42b989f1be6e8ddb6152eb, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the registration preference-family migration), and change nothing else:

   ```text
   -- Canon 25: registration uses the same communication preferences as the customers catalog trigger.
   create or replace function app.create_customer(
       p_customer_type_code text,
       p_full_name text,
       p_first_name text default null,
       p_family_name text default null,
       p_company_name text default null,
       p_primary_phone text default null,
       p_primary_email text default null,
       p_whatsapp text default null,
       p_preferred_language_code text default null,
       p_preferred_contact_method_code text default null,
       p_marketing_opt_in boolean default false,
       p_branch_id uuid default null,
       p_allow_duplicate boolean default false
   )
   returns uuid
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_tenant uuid := app.current_tenant_id();
       v_actor uuid;
       v_customer uuid;
       v_dupe uuid;
       v_branch uuid;
       v_phone text := app.normalize_phone(p_primary_phone);
       v_email text := app.normalize_email(p_primary_email);
       v_whatsapp text := app.normalize_phone(p_whatsapp);
       v_full_name text := nullif(btrim(p_full_name), '');
       v_first_name text := nullif(btrim(p_first_name), '');
       v_family_name text := nullif(btrim(p_family_name), '');
       v_company_name text := nullif(btrim(p_company_name), '');
   begin
       if v_tenant is null then
           raise exception 'no active tenant for caller';
       end if;
       perform app.authorize('CREATE_CUSTOMER');

       if not exists (
           select 1 from public.catalog_values
           where catalog_type_code = 'customer_type' and code = p_customer_type_code
       ) then
           raise exception 'unknown customer_type_code: %', p_customer_type_code;
       end if;

       if p_preferred_contact_method_code is not null and not exists (
           select 1 from public.catalog_values
           where catalog_type_code = 'preferred_contact_method_code' and code = p_preferred_contact_method_code
       ) then
           raise exception 'unknown preferred_contact_method_code: %', p_preferred_contact_method_code;
       end if;

       if p_branch_id is not null and not exists (
           select 1 from public.branches where id = p_branch_id and tenant_id = v_tenant
       ) then
           raise exception 'branch is not in your tenant';
       end if;

       -- Primary-phone uniqueness (05). This check survives for the error message; the partial unique
       -- index added by SPEC-142 is what makes it true under concurrency and on the direct path.
       if v_phone is not null and not p_allow_duplicate then
           select id into v_dupe from public.customers
           where tenant_id = v_tenant and is_archived = false and primary_phone = v_phone
           limit 1;
           if v_dupe is not null then
               raise exception 'duplicate primary phone for customer %; pass p_allow_duplicate to override', v_dupe
                   using errcode = 'unique_violation';
           end if;
       end if;

       select id into v_actor
       from public.users
       where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

       -- An explicit branch still wins; otherwise the customer is registered where the employee taking
       -- them on actually works. Leaving it null was how canon 03's requirement quietly went unrecorded.
       v_branch := coalesce(p_branch_id, (select cp.branch_id from app.current_placement() cp));

       insert into public.customers (
           tenant_id, customer_type_code, first_name, family_name, full_name, company_name,
           primary_phone, primary_email, preferred_language_code, preferred_contact_method_code,
           marketing_opt_in, first_registered_branch_id, first_registered_user_id, created_by,
           duplicate_phone_approved
       )
       values (
           v_tenant, p_customer_type_code, v_first_name, v_family_name, v_full_name, v_company_name,
           v_phone, v_email, p_preferred_language_code, p_preferred_contact_method_code,
           p_marketing_opt_in, v_branch, v_actor, v_actor,
           p_allow_duplicate and v_phone is not null
       )
       returning id into v_customer;

       -- Seed identity signals (only for provided values) so duplicate detection has data to match on.
       insert into public.customer_identity_signals (tenant_id, customer_id, signal_type_code, signal_value)
       select v_tenant, v_customer, t.st, t.sv
       from (values
           ('phone',    v_phone),
           ('whatsapp', v_whatsapp),
           ('email',    v_email)
       ) as t(st, sv)
       where t.sv is not null;

       return v_customer;
   end;
   $$;
   ```

   The resulting file's Git blob is 648f35f2ba93a9c69c42b989f1be6e8ddb6152eb.

2. Check whether `supabase/tests/79_customer_data_integrity_test.sql` contains `select plan(33);`; if so record Already Applied when its Git blob is efe552ad654dbfcfa1d7921b564799e9bc271f7d, and otherwise stop and report. Otherwise make exactly these 2 edits (customer registration and edit preference regression in the existing test), each matched once, and change nothing else:

   a) replace the line
   ```text
   select plan(19);
   ```
   with
   ```text
   select plan(33);
   ```

   b) immediately after the lines
   ```text
     'TENANT ISOLATION: the RIVAL tenant customer holding the SAME phone number is not returned -- find_customer_duplicates is SECURITY INVOKER, so RLS bounds it');

   ```
   insert
   ```text
   -- Customer communication preference uses the same catalog at registration and on edit (canon 25).
   create temp table preference_creates (test_case text primary key, customer_id uuid not null);

   select lives_ok(
     $$insert into preference_creates
       select 'email', public.create_customer('person', 'Prefers email', p_preferred_contact_method_code => 'email')$$,
     'registration accepts email');
   select lives_ok(
     $$insert into preference_creates
       select 'whatsapp', public.create_customer('person', 'Prefers WhatsApp', p_preferred_contact_method_code => 'whatsapp')$$,
     'registration accepts whatsapp');
   select lives_ok(
     $$insert into preference_creates
       select 'phone', public.create_customer('person', 'Prefers phone', p_preferred_contact_method_code => 'phone')$$,
     'registration accepts phone');
   select lives_ok(
     $$insert into preference_creates
       select 'social', public.create_customer('person', 'Prefers social', p_preferred_contact_method_code => 'social')$$,
     'registration accepts social');
   select lives_ok(
     $$insert into preference_creates
       select 'unset', public.create_customer('person', 'Preference unset')$$,
     'registration permits an unspecified preference');
   select results_eq(
     $$select p.test_case, c.preferred_contact_method_code
       from preference_creates p join public.customers c on c.id = p.customer_id
       order by p.test_case$$,
     $$values ('email'::text, 'email'::text), ('phone', 'phone'), ('social', 'social'),
              ('unset', null), ('whatsapp', 'whatsapp')$$,
     'registration persisted all four preferences and the nullable case');

   with changed as (
     update public.customers set preferred_contact_method_code = 'phone'
     where id = (select id from cust)
     returning preferred_contact_method_code
   )
   select is((select preferred_contact_method_code from changed), 'phone', 'edit stores phone');

   with changed as (
     update public.customers set preferred_contact_method_code = 'social'
     where id = (select id from cust)
     returning preferred_contact_method_code
   )
   select is((select preferred_contact_method_code from changed), 'social', 'edit stores social');

   with changed as (
     update public.customers set preferred_contact_method_code = 'email'
     where id = (select id from cust)
     returning preferred_contact_method_code
   )
   select is((select preferred_contact_method_code from changed), 'email', 'edit stores email');

   with changed as (
     update public.customers set preferred_contact_method_code = 'whatsapp'
     where id = (select id from cust)
     returning preferred_contact_method_code
   )
   select is((select preferred_contact_method_code from changed), 'whatsapp', 'edit stores whatsapp');

   with changed as (
     update public.customers set preferred_contact_method_code = null
     where id = (select id from cust)
     returning preferred_contact_method_code
   )
   select ok((select count(*) = 1 and bool_and(preferred_contact_method_code is null) from changed),
     'edit can clear an existing preference');

   select throws_matching(
     $$select public.create_customer('person', 'Wrong family', p_preferred_contact_method_code => 'primary_phone')$$,
     'preferred_contact_method_code',
     'registration rejects a code from the contact-detail catalog');
   select throws_ok(
     $$update public.customers set preferred_contact_method_code = 'primary_phone'
       where id = (select id from cust)$$,
     '23514', null,
     'edit rejects a code from the contact-detail catalog');
   select throws_matching(
     $$select public.create_customer('person', 'Unknown preference', p_preferred_contact_method_code => 'unknown')$$,
     'preferred_contact_method_code',
     'registration rejects an unknown code');

   ```

   The resulting file's Git blob is efe552ad654dbfcfa1d7921b564799e9bc271f7d.

3. **Verify before deployment.** Confirm the two exact payloads and restore the native product local stack from the migration files. Run focused test 79, the native required database tests and smoke, API-contract byte comparison, scope check and git diff check. Read only Platinum Primary project vrvtsxexkiiiivlkdxzp. Confirm the full current ledger, absence of the migration, existing function definition and ACL, structure and customer counts. Compare to the approved baseline and record expected delta. Stop on any unexplained result.
4. **Apply the one migration only after a separate exact-SHA deployment authorization.** Recheck the target and unchanged baseline and verify the transmitted file's MD5 server-side before applying. Verify the single ledger entry, the expected function diff and ACL, unchanged customer counts and local-to-Primary parity on readback. If the connector allocates a temporary version, rename only the single just-created ledger entry after verifying the exact stored statement hash and absence of the chosen version. Stop on any discrepancy. Use Platinum Primary only.
5. **Record the proved result.** Write fresh Primary ledger evidence, update the manifest's measured Live state and Suite **181 files / 3347 assertions**, and regenerate the API and discovery artifacts. Add settled CUST-17 to the gap register after CUST-16, identifying the reproduced registration rejection, exact migration, existing table guard and test 79. Add CUST-17 to the customers finding-ID list without changing its existing disposition. Keep Current Module and Next capability as owned by the existing programme. Record the readbacks and verified scope and set Runtime Checkpoint to DONE before the implementation commit.
6. **Run timed, watched native Finish and Review.** Require a matching certification receipt and Confirmed Complete. Complete in the native lifecycle with the manifest Active Change Request cleared, Last Completed set to the verified contact-preference contract, and projections regenerated. Bind the exact candidate. Release follows its separate native authority.

## Acceptance Criteria

- [x] The exact migration payload was used; `check: blob supabase/migrations/20261119054533_use_customer_preference_catalog_on_registration.sql 648f35f2ba93a9c69c42b989f1be6e8ddb6152eb`
- [x] Existing test 79 was extended with the exact test payload; `check: blob supabase/tests/79_customer_data_integrity_test.sql efe552ad654dbfcfa1d7921b564799e9bc271f7d`
- [x] The suite figure is measured; `check: has _ORVION_CANONICAL/manifest.md "Suite **181 files / 3347 assertions**"`
- [x] The evaluator is preserved; `check: same scripts/check_agent_continuity.ps1 @dd19c8095172b42d67e20c97b22e2114d082d345`
- [x] The public registration and edit paths persist all four preferences and null. Detail and unknown codes are rejected as applicable, with original guards preserved.
- [x] The single separately authorized Primary migration reads back against its own local stack, with receipt, no customer-row rewrite and settled CUST-17 recorded.
- [x] No product deployment is inferred from local test evidence.

## Execution Log

### 2026-11-19 — CRM Original Steps 1–3 and readiness

Gate 1 passed at 4c63864c341349437dda1d794e0c71dde9ac95c0. The exact migration and test 79 blobs were applied locally. After native local reset, focused 33/33, native database passes A and B (181 files, 3347 assertions each), the employee HTTP journey (35/35), the 78-table smoke and the API-contract byte comparison passed. Git scope and diff checks passed. The fresh pre-deployment read confirmed the 270-entry Primary baseline without the candidate.

### 2026-11-19 — Owner Gate 2 and Platinum Primary readback (Step 4)

The owner authorized this CRM Original through remote Certify in the context of the exact Step 4 migration and target. The private owner receipt digest is 83025B89D948952314510B28967B1787A74E8265F62BD96709AFF10A76235F43. Applied only migration 20261119054533 to Platinum Primary vrvtsxexkiiiivlkdxzp, SHA-256 5C29B9C824BD744A54E544D23C75B9A14CF3643FB8190ED74670E84128AF329D, server precheck and stored statement MD5 94cf43a4cb664343d8be39f5c7ff066d. The connector's one temporary ledger row was matched and renamed to the frozen version with the guarded update. Readback 2026-11-19T08:17:19Z has 271 ordered migrations, ledger a7e29073df56d35463b6fce7e1a13f88, 351 functions 06dcbc81fc389bfa1d4d457eeac890b6, and 3186 structural objects d09b57f6f419d7c54a888c3a8c17c59c. All match the Original local stack. The app.create_customer lookup changed only its catalog family, function ACLs and the public wrapper were unchanged, and Primary customer count stayed 0. Workbench post-deployment artifact SHA-256 C5BCE4BA1E2DFF9554967316AD3CCCEC7B535EE7873602F60AD584B86BD3F653.

### 2026-11-19 — Verified records (Step 5)

Recorded Primary evidence, measured manifest state, CUST-17 and its existing customers disposition, and regenerated API and discovery output. The exact tested migration is committed with the test and measured records. Native Finish and independent Review follow.

## Verification Notes

None.


### 2026-11-19 — Gate 1 approval recorded

The owner explicitly approved CRM SPEC-316 Original Gate 1 for SHA-256 61181551A47C9B897DF47F6DD17A526028F4E7DC1A1DD46588E42BDE87B000D3. The exact owner message is preserved in the private Workbench GATE1-SPEC-316-OWNER.md receipt, SHA-256 DDD1BDBEFCF70B15382CF06E8A7B55428BDCD3666DB3D8A0A07F8E6E42A75716. Immediately before allocation the hash, the Draft blob b9a3d69ddf4042d3243b2d97bc25bb667834e101, all 1 source anchors, the baseline HEAD dd19c8095172b42d67e20c97b22e2114d082d345 against refreshed origin/main dd19c8095172b42d67e20c97b22e2114d082d345 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 80dba48. No implementation performed before this transition. The owner reserved Supabase deployment for a separate approval. Original execution is authorized through pre-deployment readiness.


Verdict: Confirmed Complete

Review of committed implementation a38640fc3ed9222e2366396537e88b4d2c11fb5a verified the two payload blobs against the frozen Draft 61181551A47C9B897DF47F6DD17A526028F4E7DC1A1DD46588E42BDE87B000D3, the 181-file and 3347-assertion inventory in the manifest, the CUST-17 and customers disposition records, and the exact declared write scope. Git proves the continuity evaluator and Migration CI are identical to the approved baseline.

Test 79 and both native database passes confirm the existing registration and edit paths accept email, phone, social and WhatsApp and permit null. The same test verifies the refusal of a contact-detail code on both paths and an unknown code at registration. The HTTP suite and 78-table smoke passed. The live API contract regenerated byte-identically.

The independently recorded Primary readback at 08:17:19 UTC shows exactly one migration at 20261119054533 and matching transmitted and stored MD5. Primary matched the local migration ledger and all structural fingerprints. The app function changed only its lookup family, with its ACL unchanged. The public wrapper and customer count were unchanged. This is hosted database readback evidence.

The original timed and watched native Finish returned LOCAL_CERTIFY READY, including the DATABASE and REPOSITORY profiles and required HTTP verification, with own receipt ad77c9cca218c50b0b07324d71b67ba4dd8bfe09b65fdb601d5a2e977a670314 for a38640fc3ed9222e2366396537e88b4d2c11fb5a. Runner, watcher and host observer exited zero. All acceptance and Review Gate items are satisfied.


Local original native verification and truthful Review complete. Preserve this root's receipt ad77c9cca218c50b0b07324d71b67ba4dd8bfe09b65fdb601d5a2e977a670314 and selected bytes. Candidate binding follows Complete; publication/promotion remain separately governed.

## Review Gate

- [x] Every change matches the accepted implementation steps.
- [x] All changed paths are within Write Scope.
- [x] Every acceptance criterion is confirmed.
- [x] Native Finish and independent review evidence is present.

## Notes

Baseline: dd19c8095172b42d67e20c97b22e2114d082d345.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/79_customer_data_integrity_test.sql` | `fa01969b1adf6c0547274ecc6bcf69681966b09e` |
