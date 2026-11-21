# Change Request — SPEC-327

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close the last two due B6-EXIT surface obligations at the finance-ledger write boundary. A journal entry balances in one currency: the existing deferred balance trigger refuses an entry whose lines carry more than one currency, on the RPC and the platform's direct writes alike, until DC-11 decides the translation model (JE-2, the registry's recorded fail-closed containment). A payment row carries value: one validated `amount > 0` CHECK on `payments` applies the rule `app.record_payment` and `app.record_supplier_payment` already enforce to every door (PAY-4).

## Business Reason

Both gaps were reproduced at CRM `17ec05a` in rolled-back transactions. `app.create_journal_entry` accepted a 100 USD debit against a 100 EGP credit and the deferred trigger committed it, because both sum amounts across currencies; no accounting standard or ERP balances an entry that way (IAS 21 paragraph 21 records a foreign transaction in the functional currency at the spot rate). An owner at aal2 persisted a zero-value `payments` row coded `customer_refund` at the table door, where every sanctioned writer refuses `amount <= 0` and a refund is a `refunds` row. The CRM Action Registry makes `journal_entry_lines` and `payments` B6-EXIT members and B6-EXIT is next, so their exit evidence is due now. The owner's 2026-11-20 directive groups items that share evidence, tests and a release boundary while keeping per-item acceptance.

## Risks

CREATE OR REPLACE FUNCTION and ADD CONSTRAINT take locks on the balance trigger function and on payments; the CHECK validates by scanning payments. Measure the lock state before the write; Primary holds zero rows in journal_entries, journal_entry_lines, payments and payment_allocations. Preserve every grant, policy, permission charge, trigger binding, event, the three existing balance rules, the JE-4 entry lock, `payments_amount_nonneg_check` and every RPC body. A balanced single-currency entry in any currency still posts. The rollback path is a separately authorized corrective migration that restores the previous `app.enforce_journal_entry_balanced` definition and drops `payments_amount_positive_check`. Do not rewrite existing business rows.

## Supersedes / Depends On

Depends on SPEC-221 and SPEC-238 (payments on every door), SPEC-245 (journal lines written only with their entry, the deferred balance trigger and JE-4), the CRM SPEC-326 baseline and the recorded JE-2 standard research. Supersedes only the Test 145 assertion that pinned JE-2 as OPEN (the mixed-currency entry living) and the event count that followed from it.

## Write Scope

- `changes/SPEC-327-a-ledger-entry-balances-in-one-currency-and-a-payment-carries-value.md`
- `supabase/migrations/20261122100000_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value.sql`
- `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql`
- `supabase/tests/185_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value_test.sql`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/config.toml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/readiness_population.ps1`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

All other paths, Founder Secondary, integration activation, email delivery, UI, DC-11's translation model and each tenant's functional currency (owner decisions), multi-currency lines, the booking-scoped balance (PAY-9), refunds, payment direction, journal events (FIN-9), LI-3 and GitHub configuration are outside scope.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9; `ENGINEERING_METHOD.md` §§2, 4 and 5.
- SPEC-245's migration, `app.enforce_journal_entry_balanced` and `app.create_journal_entry`; `app.record_payment`, `app.record_supplier_payment` and `app.record_refund`.
- `reports/master/MASTER_EXECUTION_PLAN.md` action registry; JE-2, DC-11, PAY-4, PAY-9 and FIN-9 in the gap register.
- `supabase/tests/140_payment_is_recorded_on_every_door_test.sql` and `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql`.

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/test_future_date_guard.ps1`
- `pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1`
- `pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1`
- `pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1`
- `pwsh -NoProfile -File scripts/readiness_selftest.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Reuse the two existing controls rather than add a mechanism. The deferred balance trigger `app.enforce_journal_entry_balanced` already judges every entry on both doors at commit; one branch, evaluated before the three copied rules, refuses an entry whose lines carry more than one currency with 23514 and names the currencies. It is a replaceable refusal, not a structural CHECK, so DC-11's translation model (a transaction amount, a rate and a functional amount per line) can replace it with a functional-currency balance and forecloses nothing. `payments` gets one validated `amount > 0` CHECK, the rule both sanctioned payment writers already apply; `payments_amount_nonneg_check` is kept rather than rewritten.

Pass 2 Adversarial Review: Rolled-back reproductions at the baseline prove both gaps. A balanced entry wholly in USD still posts, so the rule is one currency per entry and not EGP only. An entry that balances numerically across USD and EGP lines is refused, so the currency rule is checked before the totals. The platform's direct writes reach the same trigger, with a one-currency positive control. The CHECK refuses zero on the owner's table door, on the platform's write and on a later UPDATE to zero, while the RPC and the smallest positive amount pass. The first full run found that a forced immediate check inside one DO block left the session immediate, so the next platform case was judged on its bare entry row; Test 185 restores deferral after each forced check. Test 145 moved JE-2 from OPEN to CONTAINED with its intent kept, and its event count follows from the refused entry. PAY-9, DC-11's model and FIN-9 stay at their recorded triggers.

Pass 3 Evidence Refresh: 2026-11-21. On isolated CRM baseline 17ec05a0904f9b5eac676b2d0024d71850886441, the repaired schema has 277 migration rows, latest `20261122100000`, ledger fingerprint `7d224a770526c87f171b9525b0817701`, with one replaced function body, one new validated CHECK, unchanged trigger bindings and unchanged API grants. The full pgTAP run passed 185 files and 3456 assertions. Database smoke passed, and the existing HTTP suite passed 35 assertions on the isolated API through its local container adapter. The regenerated API contract is unchanged. Primary `vrvtsxexkiiiivlkdxzp` was read separately at 276 migrations, latest `20261121110000`, fingerprint `3d6fe3908078c02f611c70b4eb070623`, with the target absent, the pre-change function body and zero rows in journal_entries, journal_entry_lines, payments and payment_allocations. Recheck live at the deployment boundary.

Selected Version: SPEC-327; selected: a fail-closed single-currency branch in the existing deferred balance trigger and one validated amount > 0 CHECK on payments, proven in one suite with one new and one aligned test file

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Journal entry balance rule | `app.create_journal_entry`, the journal_entries and journal_entry_lines doors, the two deferred balance triggers | WRITE | Test 185 proves the refusal on the RPC and the platform door, the named currencies, and single-currency positive controls in USD and EGP. Test 145 keeps JE-3/JE-4 and moves JE-2 to CONTAINED. |
| Payment amount | `app.record_payment`, `app.record_supplier_payment`, the payments table door, allocations | WRITE | Test 185 proves zero refused on the owner door, the platform write and an UPDATE, with the RPC and the smallest positive amount accepted. Test 140 passes unchanged. |
| Journal and payment events | Timeline and audit readers | VERIFY | No producer changes; a refused write records nothing because it does not exist. Test 145's event count asserts it. |
| B6-EXIT evidence | JE-2, PAY-4 and the journal_entry_lines and payments disposition rows | WRITE | Record closure after hosted proof. DC-11 keeps the translation model; PAY-9, FIN-9 and LI-3 keep their own triggers. |
| Contract evidence | Generated API, Primary ledger and parity, manifest and discovery | WRITE | Reuse native generation and evidence methods; the API contract is unchanged. |
| Founder, integrations, email and frontend | Existing workflows | UNAFFECTED | No product action, integration or client changes. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 7 (Platinum Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact approved payload, local functional proof, fresh target identity and recovery evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 6 |
| Recorded ledger reflects the actual Platinum Primary ledger | BEFORE_COMPLETION | Step 1 | Step 8 | Step 9 |
| Repository and local figures match the pre-deploy payload | BEFORE_IRREVERSIBLE_ACTION | Step 1 | Step 6 | Step 7 |
| Generated evidence agrees with the deployed structure | BEFORE_COMPLETION | Step 7 | Step 8 | Step 9 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: SPEC-245's deferred balance trigger `app.enforce_journal_entry_balanced` on both journal tables, and the existing CHECK constraints on `payments`.

Added Property: Every committed journal entry carries lines in one currency, and every payment row carries an amount greater than zero, whichever door wrote it.

Causal Negative: Workbench reproduction `repro-17ec05a` at `17ec05a` shows the mixed-currency entry committed and the zero-value payment stored where this change refuses them.

Positive Test Design: Test 185 requires a balanced entry wholly in USD and the same platform write wholly in EGP to post, the sanctioned payment RPC to record a positive payment, and the smallest positive amount to be accepted.

Negative Test Design: Test 185 requires 23514 for a mixed-currency entry on the RPC, for one balancing numerically across currencies, for the platform's direct write, and for a zero payment on the owner door, the platform write and an UPDATE. Test 145 pins JE-2 as CONTAINED.

Non-Empty Population Obligation: Test 185 establishes a tenant, an owner at aal2 holding the posting and payment permissions, a seeded chart of accounts, a customer and an issued invoice before testing refusals and valid writes.

Mutation Obligation: Restoring the previous trigger body or dropping the new CHECK in a rolled-back transaction must turn a Test 185 assertion red; the baseline reproduction must differ in exactly the recorded behaviors.

Post-Implementation Proof Obligation: Fresh approved Primary apply and separate readback agree with local ledger and structural fingerprints. Re-run native consistency and readiness evidence and retain DC-11, PAY-9, FIN-9 and LI-3 at their recorded triggers.

## Implementation Steps

1. Check whether `supabase/migrations/20261122100000_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value.sql` contains `-- B6-EXIT bundle C: a ledger entry balances in one currency, and a payment row carries value.`; if so record Already Applied when its Git blob is 606ce8ad8a5d8bf928cb11b920fbae0e79714a9b, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the single-currency containment and payment value migration), and change nothing else:

   ```text
   -- B6-EXIT bundle C: a ledger entry balances in one currency, and a payment row carries value.
   --
   -- The CRM Action Registry makes `journal_entry_lines`, `payments` and `payment_allocations` B6-EXIT
   -- surfaces. Measured at `17ec05a` on the local stack in rolled-back transactions (Workbench
   -- data/records/batch6/finance-evidence/repro-17ec05a.sql):
   --   * JE-2: `app.create_journal_entry` accepted a 100 USD debit against a 100 EGP credit, and the
   --     deferred `app.enforce_journal_entry_balanced` committed it, because both sum debit and credit
   --     across currencies. The registry's named exit option is the fail-closed containment: refuse a
   --     mixed-currency entry until DC-11 decides the model. It lives in the deferred balance trigger,
   --     which already judges both doors (the RPC and the platform's direct DML), so one control covers
   --     both. It is a refusal in a replaceable function, NOT a structural CHECK: DC-11's translation
   --     model (a transaction-currency amount, a rate and a functional-currency amount per line, IAS 21
   --     paragraph 21) replaces this branch with a functional-currency balance and forecloses nothing.
   --   * PAY-4: an owner's direct INSERT persisted a `payments` row with amount 0 coded
   --     `customer_refund`. Every sanctioned door that writes a payment -- `app.record_payment` and
   --     `app.record_supplier_payment` -- refuses an amount that is not greater than zero, and the
   --     refund model's own door, `app.record_refund`, writes `refunds`, not `payments`, under the same
   --     rule. The entry-shape rule derived from them: a payment row carries value, `amount > 0`, on
   --     every door.
   --
   -- NOT CHANGED: every grant, policy, trigger binding, permission charge and event; the three balance
   -- rules (at least two lines, debits equal credits, non-zero total); the RPCs' bodies; the direction
   -- column (rewriting a payment's direction is PAY-2's capability charge, already in force);
   -- `payments_amount_nonneg_check`, which the new rule implies and which is kept rather than rewritten.
   -- Primary carried 0 payments and 0 journal lines when read, so the new CHECK validates on deploy.

   create or replace function app.enforce_journal_entry_balanced()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO ''
   AS $function$
   declare
       v_entries uuid[];
       v_entry uuid;
       v_debit numeric;
       v_credit numeric;
       v_lines int;
       v_currencies text[];
   begin
       -- DELETE carries no NEW; the affected entry is the one the removed row pointed at. A line that
       -- moved between entries affects both (JE-4).
       -- Sorted, so two transactions moving lines between the same two entries lock them in one order.
       select array_agg(distinct x order by x) into v_entries
         from unnest(case tg_table_name
                       when 'journal_entries'      then array[coalesce((to_jsonb(new) ->> 'id')::uuid,
                                                                       (to_jsonb(old) ->> 'id')::uuid)]
                       when 'journal_entry_lines'  then array[(to_jsonb(new) ->> 'journal_entry_id')::uuid,
                                                              (to_jsonb(old) ->> 'journal_entry_id')::uuid]
                     end) x
        where x is not null;
       if v_entries is null then
           return null;
       end if;

       foreach v_entry in array v_entries
       loop
           -- The entry may have been deleted in this same transaction (lines first, then the entry,
           -- because the FK is ON DELETE RESTRICT). Removing a whole entry is legitimate; there is
           -- nothing left to balance, so skip rather than refuse. The lock serializes two transactions
           -- that change one entry's lines, so each counts the other's committed lines (JE-4).
           perform 1 from public.journal_entries je where je.id = v_entry for no key update;
           continue when not found;

           select coalesce(sum(l.debit_amount), 0), coalesce(sum(l.credit_amount), 0), count(*),
                  array_agg(distinct l.currency_code order by l.currency_code)
             into v_debit, v_credit, v_lines, v_currencies
           from public.journal_entry_lines l
           where l.journal_entry_id = v_entry;

           -- JE-2 containment (B6-EXIT bundle C). The sums below are only meaningful in one currency:
           -- until DC-11 decides the translation model, an entry whose lines carry more than one
           -- currency is refused rather than "balanced" across currencies. Judged first, so the
           -- refusal names the cause and not a misleading total.
           if cardinality(v_currencies) > 1 then
               raise exception 'journal entry % mixes currencies (%): an entry balances in one currency until DC-11 decides the translation model (JE-2)',
                   v_entry, array_to_string(v_currencies, ', ') using errcode = '23514';
           end if;

           -- The three rules below are COPIED from app.create_journal_entry, not chosen here.
           if v_lines < 2 then
               raise exception 'journal entry % has % line(s): a double-entry record requires at least two',
                   v_entry, v_lines using errcode = '23514';
           end if;
           if v_debit <> v_credit then
               raise exception 'journal entry % is not balanced: debits % <> credits %',
                   v_entry, v_debit, v_credit using errcode = '23514';
           end if;
           if v_debit = 0 then
               raise exception 'journal entry % totals zero', v_entry using errcode = '23514';
           end if;
       end loop;

       return null;
   end;
   $function$;

   alter table public.payments
       add constraint payments_amount_positive_check check (amount > 0);
   ```

   The resulting file's Git blob is 606ce8ad8a5d8bf928cb11b920fbae0e79714a9b.

2. Check whether `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql` contains `JE-2 CONTAINED: a 100 USD debit against a 100 EGP credit is refused through the RPC`; if so record Already Applied when its Git blob is 926f2eac4f1c96b5a5814a9c134115d34343e253, and otherwise stop and report. Otherwise make exactly these 3 edits (the JE-2 pin moved from OPEN to CONTAINED), each matched once, and change nothing else:

   a) replace the lines
   ```text
   -- JE-2 stays OPEN and is pinned as OPEN, not as desired behaviour: this fails when DC-11 decides
   -- whether an entry is one currency or is translated to a base currency.
   ```
   with
   ```text
   -- JE-2 is CONTAINED (20261122100000): an entry balances in one currency until DC-11 decides the
   -- translation model, so a 100 USD debit no longer balances a 100 EGP credit. The refusal is the
   -- deferred balance trigger's, so the check is fired inside the call; `185_...` pins both doors.
   ```

   b) replace the lines
   ```text
   select lives_ok($q$select app.create_journal_entry('manual_entry', current_date, 'JE-2',
       '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":100,"currency":"EGP"}]'::jsonb)$q$,
     'JE-2 OPEN: a 100 USD debit still balances a 100 EGP credit through the RPC -- the accounting-model decision DC-11 owns');
   ```
   with
   ```text
   select throws_ok($q$do $x$ begin
       perform app.create_journal_entry('manual_entry', current_date, 'JE-2',
         '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":100,"currency":"EGP"}]'::jsonb);
       execute 'set constraints all immediate';
     end $x$$q$,
     '23514', null,
     'JE-2 CONTAINED: a 100 USD debit against a 100 EGP credit is refused through the RPC');
   ```

   c) replace the lines
   ```text
     4,
     'OBSERVABILITY: every entry in the tenant has at least two lines and balances');
   ```
   with
   ```text
     3,
     'OBSERVABILITY: every entry in the tenant has at least two lines and balances -- E1, E2 and E4; the refused JE-2 entry left nothing');
   ```

   The resulting file's Git blob is 926f2eac4f1c96b5a5814a9c134115d34343e253.

3. Check whether `supabase/tests/185_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value_test.sql` contains `select plan(11);`; if so record Already Applied when its Git blob is 67a626e1efa1d1f69109bd107bb8cfe3ae6141af, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the two-unit regression test), and change nothing else:

   ```text
   -- pgTAP: Batch 6 exit -- a ledger entry balances in one currency, and a payment carries value.
   --
   -- ATTACK-CLASSES: DOOR BUSINESS INPUT STATE AUTH=N/A PRIVILEGE=N/A TENANT=N/A OBSERVABILITY=N/A REPLAY=N/A CONCURRENCY=N/A
   --   AUTH/PRIVILEGE/TENANT=N/A -- who may post or pay is unchanged and pinned by `56_...`, `140_...` and `145_...`;
   --     this file asks what an entry and a payment must BE, on every door, the platform's included.
   --   OBSERVABILITY=N/A -- no event changes; a refused write records nothing because it does not exist.
   --   REPLAY/CONCURRENCY=N/A -- both rules judge one entry or one row; the balance trigger's two-session
   --     proof is JE-4's (`145_...`).
   --
   -- JE-2: `app.create_journal_entry` accepted a 100 USD debit against a 100 EGP credit -- two amounts in
   --   different units summed as if one. No standard and no ERP balances an entry that way (IAS 21.21
   --   records a foreign transaction in the functional currency at the spot rate). Until DC-11 decides
   --   the translation model, an entry balances in ONE currency. The refusal lives in the deferred
   --   balance trigger, so it binds the RPC and the platform's direct writes alike.
   -- PAY-4: a zero-value payment coded `customer_refund` was accepted at the table door. Both sanctioned
   --   writers refuse `amount <= 0` and a refund is a `refunds` row, so a payment row carries value.
   --
   -- ON `set constraints all immediate` BELOW: the balance triggers fire at COMMIT, which pgTAP never
   -- reaches; each ledger case forces the check inside its own DO block (the `70_...` pattern).
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(11);

   insert into auth.users (id, email) values
     ('18500000-0000-0000-0000-0000000000a1','own@j185.test');
   insert into public.tenants (id, name, slug, status) values
     ('18500000-0000-0000-0000-000000000001','J185 Travel','j185-travel','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '18500000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('18500000-0000-0000-0000-00000000000a','18500000-0000-0000-0000-000000000001','HQ','j185-hq');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('18500000-0000-0000-0000-0000000000c1','18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-00000000000a','sales','Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('18500000-0000-0000-0000-000000000011','18500000-0000-0000-0000-000000000001','Owner','own@j185.test',true,'18500000-0000-0000-0000-0000000000a1');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-000000000011','18500000-0000-0000-0000-00000000000a','18500000-0000-0000-0000-0000000000c1',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-000000000011', r.id, 'tenant' from public.roles r where r.code = 'owner';
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('18500000-0000-0000-0000-0000000000d1','18500000-0000-0000-0000-000000000001','person','Buyer');
   -- One issued invoice, session-less fixture (the `111_...` pattern), for the sanctioned RPC.
   insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code) values
     ('18500000-0000-0000-0000-0000000000e1','18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-0000000000d1','J185-INV-1',current_date,'EGP',5000,'issued');

   select set_config('request.jwt.claims','{"sub":"18500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
   set local role authenticated;
   select app.seed_default_chart_of_accounts();
   reset role;

   -- =============================================================================================
   -- 1-5. JE-2: an entry balances in one currency, on every door.
   -- =============================================================================================
   set local role authenticated;
   select throws_ok($q$do $x$ begin
       perform app.create_journal_entry('manual_entry', current_date, 'JE-2',
         '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":100,"currency":"EGP"}]'::jsonb);
       execute 'set constraints all immediate';
     end $x$$q$,
     '23514', null,
     'JE-2: the RPC no longer balances a 100 USD debit against a 100 EGP credit');

   select throws_like($q$do $x$ begin
       perform app.create_journal_entry('manual_entry', current_date, 'JE-2b',
         '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":60,"currency":"USD"},
           {"account_code":"4100","credit":40,"currency":"EGP"}]'::jsonb);
       execute 'set constraints all immediate';
     end $x$$q$,
     '%mixes currencies (EGP, USD)%(JE-2)',
     'JE-2: an entry that would balance as numbers across USD and EGP lines is refused, and the refusal names both currencies');

   select lives_ok($q$do $x$ begin
       perform app.create_journal_entry('manual_entry', current_date, 'USD-1',
         '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":100,"currency":"USD"}]'::jsonb);
       execute 'set constraints all immediate';
     end $x$$q$,
     'POSITIVE CONTROL: a balanced entry wholly in USD still posts -- the rule is one currency per entry, not EGP only');
   reset role;
   -- The forced check above leaves the session in immediate mode; restore deferral so each platform
   -- case below is judged with all its lines written, not on its bare entry row.
   set constraints all deferred;

   select throws_like($q$do $x$ begin
       insert into public.journal_entries (id, tenant_id, source_type_code, entry_date)
       values ('18500000-0000-0000-0000-0000000000f1','18500000-0000-0000-0000-000000000001','manual_entry', current_date);
       insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
       select '18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-0000000000f1', id,
              case code when '1000' then 100 else 0 end, case code when '4000' then 100 else 0 end,
              case code when '1000' then 'USD' else 'EGP' end
         from public.chart_of_accounts where tenant_id = '18500000-0000-0000-0000-000000000001' and code in ('1000','4000');
       execute 'set constraints all immediate';
     end $x$$q$,
     '%mixes currencies (EGP, USD)%(JE-2)',
     'JE-2: the platform''s direct writes are judged by the same trigger and refused for the currency rule -- no session-less exemption');
   set constraints all deferred;

   select lives_ok($q$do $x$ begin
       insert into public.journal_entries (id, tenant_id, source_type_code, entry_date)
       values ('18500000-0000-0000-0000-0000000000f2','18500000-0000-0000-0000-000000000001','manual_entry', current_date);
       insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
       select '18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-0000000000f2', id,
              case code when '1000' then 100 else 0 end, case code when '4000' then 100 else 0 end, 'EGP'
         from public.chart_of_accounts where tenant_id = '18500000-0000-0000-0000-000000000001' and code in ('1000','4000');
       execute 'set constraints all immediate';
     end $x$$q$,
     'POSITIVE CONTROL: the same platform write in one currency passes, so the refusal above is the currency rule');

   -- =============================================================================================
   -- 6-11. PAY-4: a payment row carries value, on every door.
   -- =============================================================================================
   select is((select pg_get_constraintdef(c.oid) || ' ' || c.convalidated::text from pg_constraint c
               where c.conrelid = 'public.payments'::regclass and c.conname = 'payments_amount_positive_check'),
     'CHECK ((amount > (0)::numeric)) true',
     'STRUCTURE: payments carries a validated amount > 0 CHECK -- one control for every writer');

   select set_config('request.jwt.claims','{"sub":"18500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
   set local role authenticated;
   select throws_ok($q$insert into public.payments (tenant_id, payment_direction_code, customer_id, payment_method_code, currency_code, amount, paid_at)
                      values ('18500000-0000-0000-0000-000000000001','customer_refund','18500000-0000-0000-0000-0000000000d1','cash','EGP',0,now())$q$,
     '23514', 'new row for relation "payments" violates check constraint "payments_amount_positive_check"',
     'PAY-4: the owner at aal2 cannot record a zero-value payment coded customer_refund at the table door');

   select lives_ok($q$select app.record_payment('18500000-0000-0000-0000-0000000000e1', 5000, 'cash', now(), 'J185-PAY')$q$,
     'POSITIVE CONTROL: the sanctioned RPC still records a positive payment');
   reset role;

   select throws_ok($q$insert into public.payments (tenant_id, payment_direction_code, customer_id, payment_method_code, currency_code, amount, paid_at)
                      values ('18500000-0000-0000-0000-000000000001','customer_payment','18500000-0000-0000-0000-0000000000d1','cash','EGP',0,now())$q$,
     '23514', 'new row for relation "payments" violates check constraint "payments_amount_positive_check"',
     'PAY-4: the platform cannot write a zero-value payment either');

   select lives_ok($q$insert into public.payments (tenant_id, payment_direction_code, customer_id, payment_method_code, currency_code, amount, paid_at)
                      values ('18500000-0000-0000-0000-000000000001','customer_payment','18500000-0000-0000-0000-0000000000d1','cash','EGP',0.0001,now())$q$,
     'BOUNDARY: the smallest positive amount the column holds is a payment');

   select throws_ok($q$update public.payments set amount = 0 where reference_number = 'J185-PAY'$q$,
     '23514', 'new row for relation "payments" violates check constraint "payments_amount_positive_check"',
     'PAY-4: a recorded payment cannot be emptied to zero afterwards');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 67a626e1efa1d1f69109bd107bb8cfe3ae6141af.

4. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Recorded exception, 2026-11-22, CRM exit bundle C`; if so record Already Applied when its Git blob is 101cced6d1713f3ff09d2d81030b298382932886, and otherwise stop and report. Otherwise make exactly this one edit (the current owner-authorized grouped selection), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   **Recorded exception, 2026-11-21, CRM exit bundle B.** After CRM SPEC-325 at `7c5975a09b9351308a3178f1c1579798747fbe51`, the owner's 2026-11-20 directive authorized grouping items that share evidence, tests and a release boundary while keeping per-item acceptance. SPEC-326 selects RFD-3, CHAT-2 and the PAY-5/FIN-11 unit, which share one boundary: a refund transition, a conversation transition and an allocation's invoice settlement are recorded by the table's own producer on every door, and the RPCs stop emitting them a second time. Test 184 proves each selected effect on one isolated schema. PAY-9, PAY-4, JE-2, CAMP-4, BRANCH-2 and PAX-8 keep their own triggers. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle C.** After CRM SPEC-326 at `17ec05a0904f9b5eac676b2d0024d71850886441`, the owner's 2026-11-20 directive authorized grouping items that share evidence, tests and a release boundary while keeping per-item acceptance. SPEC-327 selects JE-2, through the recorded fail-closed single-currency containment while DC-11 stays open, and PAY-4, through the entry-shape rule derived from the sanctioned payment RPCs. Both are the exit evidence of the `journal_entry_lines` and `payments` surfaces and share the finance-ledger write boundary: the deferred balance trigger refuses a mixed-currency entry and a payment row carries `amount > 0`, on every door. Test 185 proves each selected effect on one isolated schema. PAY-9 keeps FIRST-BOOKING and DC-11 keeps the finance model. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```

   The resulting file's Git blob is 101cced6d1713f3ff09d2d81030b298382932886.

5. **Regenerate the exact API contract.** After the Original carries Steps 1–4 and the local CRM stack is rebuilt with the exact new migration, run the repository API generator from that state. The resulting Git blob must be 62af74be28b058e41b6b6bcfbe43457f15acfd33, unchanged. The script and all rows stay pinned. In a stack-free isolated rehearsal this step is deferred to Original DATABASE readiness.

6. **Establish readiness and the exact Primary preflight.** Run the native DATABASE readiness, including full SQL tests, HTTP and smoke, API generation and Git blob comparison. Verify 277 migrations, latest `20261122100000`, fingerprint `7d224a770526c87f171b9525b0817701`, 185 files and 3456 assertions. Compare the catalog against the isolated evidence. Verify the replaced `app.enforce_journal_entry_balanced` definition, the validated `payments_amount_positive_check`, unchanged trigger bindings and the expected function and constraint differences with all other parity signatures stable. Read live Primary project `vrvtsxexkiiiivlkdxzp`: require 276 migrations, latest `20261121110000`, fingerprint `3d6fe3908078c02f611c70b4eb070623`, absent target and certified Primary parity. Preserve scoped baseline row counts, fresh lock evidence and the native exact-DDL and recovery prerequisites. Verify the tracked file Git blob, SHA-256 and the MD5 received by the intended connected Primary route.

   While these measurements agree, update only the manifest Live state on the uncommitted tree to the following:

   ```text
   Live state: SPEC-327 pre-deploy verification. **Repository and local stack at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. **Platinum Primary `vrvtsxexkiiiivlkdxzp` verified separately at 276 migrations**, with the target absent. Structural parity awaits Gate 2. **80 client RPCs**. Suite **185 files / 3456 assertions**.
   ```

   Require the unchanged consistency guard to report only the missing exact Primary row under RECOVER-1. In the isolated Sandbox, use native Approve and literal replay and check only this expected refusal. The real implementation commit and DONE belong after Primary readback, parity and record updates.

7. **Apply the exact migration once after Gate 2 with separately recorded current authority.** Use the authorized CRM Platinum Primary path for `vrvtsxexkiiiivlkdxzp`. Reconfirm project, baseline, raw file MD5, active Draft, lock window and recovery readiness immediately before the write. Afterward verify one expected ledger row, the replaced function definition, the validated CHECK, unchanged trigger bindings, catalog fingerprints and scoped row counts. If the connector allocates a temporary ledger version, reconcile only that exact row in a guarded transaction once the stored migration statement digest and intended version absence are proven. On error or ambiguity preserve the actual database state and follow the native RECOVER-1 decision; no blind retry. A reversal requires a separately authorized corrective migration restoring the prior function definition and dropping the new CHECK.

8. **Record verified closure and resolve RECOVER-1.** From actual live Primary and local evidence, record ordered ledger and all ten parity surfaces, replace the interim Live state with the literal native fields `full-function-surface hash` and `structural-surface hash` carrying the matched hashes, retain suite count and regenerate discovery. In the gap register, with readback evidence, record PAY-4 fixed by SPEC-327 and JE-2 contained fail-closed by SPEC-327, each with its previous status kept as history, note that DC-11 still decides the translation model, and keep PAY-9, FIN-9 and LI-3 at their recorded status. In the action registry of `reports/master/MASTER_EXECUTION_PLAN.md`, replace the one line that begins `| PAY-4 |`, the one that begins `| JE-2, DC-11 |` and the `journal_entry_lines` and `payments` surface rows with these lines, in the same order. No other plan line changes after Step 4. The resulting file's Git blob is c7b0769ff041b39e33dbdf92287ba848463331af.

   ```text
   | PAY-4 | VERIFIED DEFECT | engineering | `FIRST-PAYMENT` | — | SPEC-327 and Test 185 close it on Platinum Primary: `payments_amount_positive_check` requires `amount > 0` on every door, the rule `app.record_payment` and `app.record_supplier_payment` already enforce. |
   | JE-2, DC-11 | VERIFIED DEFECT | engineering | `FIRST-JOURNAL-ENTRY` | the finance model (OD-1) | Medium. SPEC-327 and Test 185 contain JE-2 fail-closed on Platinum Primary: the deferred balance trigger refuses an entry whose lines carry more than one currency, on every door. DC-11 still decides the translation model; launch never presents a false balance. |
   | `journal_entry_lines` | SURFACE | engineering | `B6-EXIT` | JE-2 and DC-11 | SPEC-245 and test 145 close JE-3/JE-4 and the STEPUP-1 member. SPEC-327 and Test 185 close JE-2's exit evidence on Platinum Primary with the recorded fail-closed single-currency containment. DC-11 keeps the translation model. |
   | `payments` | SURFACE | engineering | `B6-EXIT` | PAY-4 and exit integrity evidence | SPEC-221/238 and tests 126/140 close PAY-2/PAY-3. SPEC-327 and Test 185 close PAY-4 on Platinum Primary: a payment row carries `amount > 0` on every door. The payment trigger is preserved. |
   ```

   In the disposition, mark journal_entry_lines and payments AUDITED with the SPEC-327 proof and update the status counts by those two rows, with all other statuses intact. Date both report headers with a new `Last updated` line and keep the previous one as `Previously`. The native registry must report only the expected B6-EXIT reduction: PAY-4 and the journal_entry_lines and payments surfaces move to COMPLETED, without changing exit criteria or unrelated triggers. Require repository consistency and parity evidence PASS before Runtime Checkpoint DONE and the implementation commit.

9. **Verify and release through the native lifecycle.** Run timed and watched Finish, independent Review, Complete and bind with exact evidence. Set `Last Completed: **SPEC-327: A ledger entry balances in one currency, and a payment carries value.**`, clear the active pointer, regenerate discovery and bind the exact candidate. Publish, hosted preflight, Promote, main checks and Remote Certify use separate native exact-candidate records and the current delegated authority.

## Acceptance Criteria

- [ ] Exact migration adds the single-currency refusal to the balance trigger and the payment value CHECK. `check: blob supabase/migrations/20261122100000_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value.sql 606ce8ad8a5d8bf928cb11b920fbae0e79714a9b`
- [ ] Test 145 pins JE-2 as CONTAINED and keeps JE-3/JE-4. `check: blob supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql 926f2eac4f1c96b5a5814a9c134115d34343e253`
- [ ] Test 185 proves every selected effect on every door with its positive controls. `check: blob supabase/tests/185_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value_test.sql 67a626e1efa1d1f69109bd107bb8cfe3ae6141af`
- [ ] The recorded grouped selection and the per-item registry closure are exact. `check: blob reports/master/MASTER_EXECUTION_PLAN.md c7b0769ff041b39e33dbdf92287ba848463331af`
- [ ] The generated API contract is unchanged. `check: blob reports/master/MASTER_API_CONTRACT.md 62af74be28b058e41b6b6bcfbe43457f15acfd33`
- [ ] Native selection stays intact. `check: same scripts/batch6_select_target.ps1 @17ec05a0904f9b5eac676b2d0024d71850886441`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **185 files / 3456 assertions**"`
- [ ] Verified Primary and local ledger and all ten surfaces agree. PAY-4 closes and JE-2 is contained per item with evidence; DC-11, PAY-9, FIN-9 and LI-3 keep their recorded triggers.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Exact approved payload and allowed scope.
- [ ] Isolated causal negatives and native SQL, smoke, HTTP and API evidence.
- [ ] Verified Primary identity, ledger, parity and per-item registry changes.
- [ ] Existing open items and governance gates retained.

## Notes

Baseline: 17ec05a0904f9b5eac676b2d0024d71850886441.

Owner authority: Workbench `data/records/batch6/owner-words/owner-2026-11-20-batch-more-work-directive.txt`, SHA-256 `383D3198EBC1E7E0B46CE19945B0FBF35A062A5A74B3AF0792DEE13EB6734840`. Run mode: Workbench `data/records/batch6/owner-words/owner-2026-11-21-run-modes-redefined.txt`, SHA-256 `35E35600BB9D2D69EBF0A85BE8E6256260617F9A8B47F74A091565BC53AF69DD`. Grouping keeps per-item acceptance, and native Gate 1 and Gate 2 remain. This Draft conveys no Original, deployment or release approval.

Isolated proof: Workbench `data/records/batch6/finance-evidence/` `RECHECK.md`, `repro-17ec05a.sql` and `repro-17ec05a.log`; Workbench `data/records/batch6/exit-bundle-c/` `RECHECK.md`, `prototype-pgtap.log`, `prototype-smoke.log`, `prototype-http.log`, `prototype-api.md`, `prototype-catalog.log`, `prototype-parity.log` and `primary-preflight-read.log`.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql` | `26176d95881764bd6e6becc3bdaeca007f9befe6` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `b766c82547d6c870d3cc2ecf16a51e387668a7d4` |
