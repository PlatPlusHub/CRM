# Change Request — SPEC-328

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Carry the cancelled SPEC-327 delivery forward unchanged and close it. A journal entry balances in one currency: the deferred balance trigger refuses an entry whose lines carry more than one currency, on the RPC and the platform's direct writes alike, until DC-11 decides the translation model (JE-2 contained fail-closed). A payment row carries value: one validated `amount > 0` CHECK on `payments` (PAY-4). Platinum Primary already holds the migration; this contract writes nothing to Primary and verifies it read-only.

## Business Reason

SPEC-327 applied migration `20261122100000` to Platinum Primary `vrvtsxexkiiiivlkdxzp` and read it back (277 migrations, fingerprint `7d224a770526c87f171b9525b0817701`). Its approved plan bytes kept the header `Last updated: 2026-11-21` under a body line dated 2026-11-22, so the native consistency guard (STALE-1) refused the record step and SPEC-327 was cancelled by delegated authority without rollback, as SPEC-278's Cancel left its deployed migration for SPEC-279. The repository must record what Primary holds, and the B6-EXIT evidence for JE-2 and PAY-4 is due now.

## Risks

No database write happens; the risk is a record that differs from Primary. Every carried file is pinned to its Git blob, and the Primary step is read-only and stops on any difference from the recorded ledger, function definition, CHECK, surface hashes or row counts. Preserve every grant, policy, trigger binding, RPC body and open item. The rollback path for the deployed schema remains a separately authorized corrective migration.

## Supersedes / Depends On

- `changes/SPEC-327-a-ledger-entry-balances-in-one-currency-and-a-payment-carries-value.md` (Cancelled; allocate `1c42645`, Approve `9da4c45`, Cancel `ac6bc7a`; its migration is deployed on Platinum Primary; this contract is its successor and carries its delivery forward byte for byte, with the dated plan header added).
- Depends on SPEC-221 and SPEC-238 (payments on every door), SPEC-245 (journal lines written only with their entry, the deferred balance trigger and JE-4), the recorded JE-2 standard research and the SPEC-279 successor precedent. Supersedes only the Test 145 assertion that pinned JE-2 as OPEN and the event count that followed from it.

## Write Scope

- `changes/SPEC-328-a-ledger-entry-balances-in-one-currency-and-a-payment-carries-value.md`
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

All other paths, any Primary write, Founder Secondary, integration activation, email delivery, UI, DC-11's translation model and each tenant's functional currency (owner decisions), multi-currency lines, the booking-scoped balance (PAY-9), refunds, payment direction, journal events (FIN-9), LI-3 and GitHub configuration are outside scope.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9; `ENGINEERING_METHOD.md` §§2, 4 and 5.
- `changes/SPEC-327-a-ledger-entry-balances-in-one-currency-and-a-payment-carries-value.md` and the SPEC-279 successor precedent.
- `reports/master/MASTER_EXECUTION_PLAN.md` action registry; JE-2, DC-11, PAY-4, PAY-9 and FIN-9 in the gap register.

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
- `pwsh -NoProfile -File scripts/test_future_date_guard.ps1`
- `pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1`
- `pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1`
- `pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1`
- `pwsh -NoProfile -File scripts/readiness_selftest.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Carry, do not redesign. Every SPEC-327 file is carried by its exact deployed or approved bytes: the migration Primary holds, Test 145, Test 185, the Primary evidence, the manifest Live state, the gap register, the disposition and the plan, whose only new content is the dated `Last updated` header naming SPEC-328 with the previous header kept as `Previously`. The Primary step is a read-only Already Applied verification.

Pass 2 Adversarial Review: SPEC-327's design stands: a balanced single-currency entry in USD or EGP still posts, a numerically balanced cross-currency entry is refused before the totals, the platform's direct writes reach the same trigger, and zero is refused on the owner door, the platform write and an UPDATE while the smallest positive amount passes. SPEC-327's only failure was the stale plan header (STALE-1), which Step 8 fixes. A Primary that differs from the recorded ledger would make the carried records false, so Step 10 stops on any difference instead of writing.

Pass 3 Evidence Refresh: 2026-11-22. On CRM baseline ac6bc7a9aea091d93a02a43ae2734fdbe0e716cb the carried tree passes the native repository consistency check CLEAN in the isolated prototype. Primary `vrvtsxexkiiiivlkdxzp` was read 2026-11-22 15:22 UTC: 277 migrations, latest `20261122100000`, fingerprint `7d224a770526c87f171b9525b0817701`, `payments_amount_positive_check` validated, the single-currency branch present, zero rows in journal_entries, journal_entry_lines, payments and payment_allocations. SPEC-327's isolated proof (185 files and 3456 assertions, smoke, HTTP 35 assertions, API unchanged) covers the same bytes. Recheck live at Step 10.

Selected Version: SPEC-328; selected: the cancelled SPEC-327 delivery carried byte for byte (the deployed migration, Test 185, Test 145 and every record edit) with a read-only Already Applied Primary verification, the smallest successor rule 3 of the delegated Cancel allows

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Journal entry balance rule | `app.create_journal_entry`, the journal_entries and journal_entry_lines doors, the two deferred balance triggers | WRITE | The carried migration and Test 185 prove the refusal on the RPC and the platform door with USD and EGP positive controls; Test 145 keeps JE-3/JE-4 and moves JE-2 to CONTAINED. |
| Payment amount | `app.record_payment`, `app.record_supplier_payment`, the payments table door, allocations | WRITE | Test 185 proves zero refused on every door and the smallest positive amount accepted; Test 140 passes unchanged. |
| Journal and payment events | Timeline and audit readers | VERIFY | No producer changes; Test 145's event count asserts the refused entry records nothing. |
| B6-EXIT evidence | JE-2, PAY-4 and the journal_entry_lines and payments disposition rows | WRITE | Carried records; DC-11 keeps the translation model; PAY-9, FIN-9 and LI-3 keep their own triggers. |
| Contract evidence | Generated API, Primary ledger and parity, manifest and discovery | WRITE | Carried evidence, re-verified read-only; the API contract is unchanged. |
| Founder, integrations, email and frontend | Existing workflows | UNAFFECTED | No product action, integration or client changes. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| SPEC-327 is Cancelled and Primary already holds its migration at the recorded ledger | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Repository records agree with the recorded Primary ledger and surfaces | BEFORE_COMPLETION | NONE | 8 | 10 |
| Live Primary equals the recorded evidence | BEFORE_COMPLETION | NONE | NONE | 11 |

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

Post-Implementation Proof Obligation: A fresh read-only Primary readback agrees with the recorded ledger and structural fingerprints. Re-run native consistency and readiness evidence and retain DC-11, PAY-9, FIN-9 and LI-3 at their recorded triggers.

## Implementation Steps

1. Check whether `supabase/migrations/20261122100000_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value.sql` contains `-- B6-EXIT bundle C: a ledger entry balances in one currency, and a payment row carries value.`; if so record Already Applied when its Git blob is 606ce8ad8a5d8bf928cb11b920fbae0e79714a9b, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the deployed single-currency containment and payment value migration, byte for byte), and change nothing else:

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

4. Check whether `reports/evidence/primary-ledger-evidence.json` contains `"migration_count": 277,`; if so record Already Applied when its Git blob is 2db7dde875ec85455c89bbbb960a48923a854e32, and otherwise stop and report. Otherwise make exactly these 4 edits (the recorded Platinum Primary readback after the SPEC-327 apply), each matched once, and change nothing else:

   a) replace the line
   ```text
     "read_at": "2026-11-21T14:30:55.511486Z",
   ```
   with
   ```text
     "read_at": "2026-11-22T08:18:51.697771Z",
   ```

   b) replace the lines
   ```text
     "repository_head": "cc22ea99d82d2c6eee1a54afe9be436aaf2faed1",
     "migration_count": 276,
     "ledger_fingerprint": "3d6fe3908078c02f611c70b4eb070623",
     "function_surface_hash": "fb9b700aa2c6c0a013af6576314ae3b9",
   ```
   with
   ```text
     "repository_head": "9da4c45a25bacb8ea78b5acb480ca1d21d745dbe",
     "migration_count": 277,
     "ledger_fingerprint": "7d224a770526c87f171b9525b0817701",
     "function_surface_hash": "ca519b79e522cff13cd309456f618a14",
   ```

   c) replace the lines
   ```text
     "structural_surface_hash": "3c6ea07a196c3cf0a3ff801397931e0e",
     "structural_object_count": 3203,
     "surface_read_queries": "Independent read from Platinum Primary in read-only transactions after convergence to migration 20261121110000. scripts/parity_surface.sql supplied all ten section signatures and the combined signature. The ordered ledger and every section match the Original local stack.",
   ```
   with
   ```text
     "structural_surface_hash": "0bb1e5b10e0bde5bd344f706366150ee",
     "structural_object_count": 3204,
     "surface_read_queries": "Independent read from Platinum Primary in read-only transactions after convergence to migration 20261122100000. scripts/parity_surface.sql supplied nine section signatures; the grants section and the combined signature came from its ACL variant (pg_class.relacl, same rows), because the read-only role cannot see other roles' grants in information_schema.role_table_grants. The ordered ledger and every section match the Original local stack.",
   ```

   d) replace the line
   ```text
       "20261121110000_a_refund_a_conversation_and_a_settlement_are_recorded_on_every_door"
   ```
   with
   ```text
       "20261121110000_a_refund_a_conversation_and_a_settlement_are_recorded_on_every_door",
       "20261122100000_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value"
   ```

   The resulting file's Git blob is 2db7dde875ec85455c89bbbb960a48923a854e32.

5. Check whether `_ORVION_CANONICAL/manifest.md` contains `at 277 migrations** (latest`; if so record Already Applied when its Git blob is efff5b2e48fed35dc26ab983ad54324889df346f, and otherwise stop and report. Otherwise make exactly this one edit (the Live state at 277 migrations with the matched surface hashes), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 276 migrations** (latest `20261121110000`), ledger `3d6fe3908078c02f611c70b4eb070623`. full-function-surface hash `fb9b700aa2c6c0a013af6576314ae3b9` (358 functions), structural-surface hash `3c6ea07a196c3cf0a3ff801397931e0e` (3,203 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-21. **80 client RPCs**. Suite **184 files / 3445 assertions**.
   ```
   with
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **185 files / 3456 assertions**.
   ```

   The resulting file's Git blob is efff5b2e48fed35dc26ab983ad54324889df346f.

6. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `CONTAINED FAIL-CLOSED 2026-11-22 (CRM SPEC-327`; if so record Already Applied when its Git blob is b442d9f1ad801e1041e07d4eb76951afc06c249b, and otherwise stop and report. Otherwise make exactly these 3 edits (PAY-4 fixed and JE-2 contained, with the dated header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-21 (CRM SPEC-326 fixes RFD-3, CHAT-2, PAY-5 and FIN-11 on Platinum Primary. FIN-9 keeps its journal-event half; PAY-9, PAY-4, JE-2 and LI-3 keep their own statuses.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM SPEC-327 fixes PAY-4 and contains JE-2 fail-closed on Platinum Primary: a ledger entry balances in one currency and a payment row carries value on every door. DC-11 still decides the translation model.)

   Previously: 2026-11-21 (CRM SPEC-326 fixes RFD-3, CHAT-2, PAY-5 and FIN-11 on Platinum Primary. FIN-9 keeps its journal-event half; PAY-9, PAY-4, JE-2 and LI-3 keep their own statuses.)
   ```

   b) replace the line
   ```text
   | PAY-4 | **The payments table accepts a zero-value row coded as a customer refund** | financial integrity / input | Low | R | 6 | — | 📋 | **OPEN — independently reproduced during Slice 20; not absorbed by SPEC-221.** A direct INSERT persisted a `payments` row with amount 0 and `payment_direction_code` `customer_refund`. Row-shape and direction-catalog integrity are a different authority from PAY-2's capability charging and are not changed by it. Reopening trigger: a payment entry-shape rule derived from the sanctioned RPCs and the refund model. No owner decision is pending. | — | SPEC-221-payment-write-capability-parity | 09-25 | 09-25 |
   ```
   with
   ```text
   | PAY-4 | **The payments table accepts a zero-value row coded as a customer refund** | financial integrity / input | Low | R | 6 | — | ✅ | **FIXED 2026-11-22 (CRM SPEC-327, `20261122100000`).** A payment row now carries value on every door: `payments_amount_positive_check` (`amount > 0`) refuses a zero or negative amount at the table door exactly as `app.record_payment` and `app.record_supplier_payment` already did, and a refund remains a `refunds` row written by `app.record_refund`. `payments_amount_nonneg_check` is kept. Both pgTAP runs, including Test 185, verified the zero `customer_refund` INSERT refused with 23514 and a positive payment accepted. Platinum Primary readback confirmed the exact migration, the validated constraint, zero payment rows and ten-surface parity. History: **OPEN — independently reproduced during Slice 20; not absorbed by SPEC-221.** A direct INSERT persisted a `payments` row with amount 0 and `payment_direction_code` `customer_refund`. Row-shape and direction-catalog integrity are a different authority from PAY-2's capability charging and are not changed by it. Reopening trigger: a payment entry-shape rule derived from the sanctioned RPCs and the refund model. No owner decision is pending. | — | SPEC-221-payment-write-capability-parity; SPEC-327-a-ledger-entry-balances-in-one-currency-and-a-payment-carries-value | 09-25 | 11-22 |
   ```

   c) replace the line
   ```text
   | JE-2 | **A journal entry can "balance" across two different currencies** | financial integrity | Medium | R | 6 | — | 📋 | **RECORDED, DELIBERATELY NOT FIXED — it is not derivable and fixing it would foreclose a Batch-4 decision.** REPRODUCED: a 100 **USD** debit and a 100 **EGP** credit, two lines, survived the deferred `enforce_journal_entry_balanced` and committed — the trigger sums `debit_amount` and `credit_amount` across currencies and compares the totals. **Both doors behave identically**, so this is NOT an ADR-0024 two-door gap: `app.create_journal_entry` sums the same way and validates no currency at all. **Why it is not fixed here:** canon 31 lists `currency_code` on the line and states only the debit/credit exclusivity rule; canon defines no single-currency-per-entry rule, and **DC-10 (opening balances) and DC-11 (realized FX) are deferred to Batch 4**. The two standard answers — one currency per entry, or transaction-currency plus a base-currency translation column — are an accounting-model choice, and adding a same-currency CHECK now would foreclose the second, which is the model DC-11 anticipates. `AGENTS.md §6`: never invent business policy to make an implementation convenient. **Trigger:** Batch 4's finance-depth package, where DC-11 is decided | engineering: decide with DC-11 | session-2026-09-01-finance-periphery | 09-01 | 09-01 |
   ```
   with
   ```text
   | JE-2 | **A journal entry can "balance" across two different currencies** | financial integrity | Medium | R | 6 | — | 🛡 | **CONTAINED FAIL-CLOSED 2026-11-22 (CRM SPEC-327, `20261122100000`); DC-11 still decides the translation model.** The deferred `app.enforce_journal_entry_balanced` now refuses, with 23514 and before the balance rules, an entry whose lines carry more than one currency, so the RPC and the direct DML door both refuse the 100 USD / 100 EGP entry. It is a branch in a replaceable function, not a structural CHECK, so the transaction-currency plus functional-currency model (IAS 21 paragraph 21) stays open: DC-11 replaces the branch with a functional-currency balance. Both pgTAP runs, including Test 185 and the updated Test 145, verified the refusal on both doors and a single-currency entry still accepted. Platinum Primary readback confirmed the exact function body (prosrc md5 `809c5bbc84937777d9160a173d741e77`), zero journal rows and ten-surface parity. **Remaining trigger:** DC-11 in the finance-depth package. History: **RECORDED, DELIBERATELY NOT FIXED — it is not derivable and fixing it would foreclose a Batch-4 decision.** REPRODUCED: a 100 **USD** debit and a 100 **EGP** credit, two lines, survived the deferred `enforce_journal_entry_balanced` and committed — the trigger sums `debit_amount` and `credit_amount` across currencies and compares the totals. **Both doors behave identically**, so this is NOT an ADR-0024 two-door gap: `app.create_journal_entry` sums the same way and validates no currency at all. **Why it is not fixed here:** canon 31 lists `currency_code` on the line and states only the debit/credit exclusivity rule; canon defines no single-currency-per-entry rule, and **DC-10 (opening balances) and DC-11 (realized FX) are deferred to Batch 4**. The two standard answers — one currency per entry, or transaction-currency plus a base-currency translation column — are an accounting-model choice, and adding a same-currency CHECK now would foreclose the second, which is the model DC-11 anticipates. `AGENTS.md §6`: never invent business policy to make an implementation convenient. **Trigger:** Batch 4's finance-depth package, where DC-11 is decided | engineering: decide with DC-11 | session-2026-09-01-finance-periphery; SPEC-327-a-ledger-entry-balances-in-one-currency-and-a-payment-carries-value | 09-01 | 11-22 |
   ```

   The resulting file's Git blob is b442d9f1ad801e1041e07d4eb76951afc06c249b.

7. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `Last updated: 2026-11-22 (CRM SPEC-327 adds one-currency ledger`; if so record Already Applied when its Git blob is f4fad84038b67bf00686d36e4a3c543314f68581, and otherwise stop and report. Otherwise make exactly these 4 edits (journal_entry_lines and payments AUDITED, with the dated header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-21 (CRM SPEC-326 adds both-door refund, conversation and settlement recording proof. conversations, payment_allocations and refunds become AUDITED because RFD-3, CHAT-2, PAY-5 and FIN-11 are fixed.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM SPEC-327 adds one-currency ledger and positive-payment proof on both doors. journal_entry_lines and payments become AUDITED because JE-2 is contained fail-closed and PAY-4 is fixed.)

   Previously: 2026-11-21 (CRM SPEC-326 adds both-door refund, conversation and settlement recording proof. conversations, payment_allocations and refunds become AUDITED because RFD-3, CHAT-2, PAY-5 and FIN-11 are fixed.)
   ```

   b) replace the line
   ```text
   **78 of 78 recorded · 60 `AUDITED` · 15 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 0 `NOT-RECORDED`.**
   ```
   with
   ```text
   **78 of 78 recorded · 62 `AUDITED` · 13 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 0 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   | `journal_entry_lines` | **AUDITED-OPEN** | ADVERSARIAL | `SPEC-245-a-journal-line-is-written-only-with-its-entry` | JE-2, JE-3, JE-4 | `145_a_journal_line_is_written_only_with_its_entry_test.sql` proves that a `finance_manager` holding CREATE_JOURNAL_ENTRY at aal2 is refused, by the missing grant, rewriting a posted entry balanced in another currency and backdated, moving a posted line onto a retired account or into another entry, and appending a balanced pair to a posted entry. Every entry still says what its `journal_entry_created` event says. The same actor at aal1 can neither post through the RPC nor rewrite at the table, an employee cannot post, and another tenant reads nothing. The RPC, now the lines' one writer, is definer with an empty search_path and still charges permission and step-up. Even the platform cannot empty an entry by moving its lines, while a move that leaves both entries balanced passes. `verify_journey_branches.ps1` proves the bulk append, the upsert rewrite and the PATCH at aal2 and aal1 refused over HTTP. Installed/restored mutations restoring either grant, returning the RPC to invoker, dropping the old-parent check or dropping the lock (two sessions) reopen each attack. Swept and classified as non-defects: FIN-8's set rules, the per-row debit-xor-credit CHECK and MONEY-1's NaN rule are unchanged and pinned by `70_...`; tenant isolation (RLS and composite keys to the entry and the account) held; DELETE has no grant; the subscription gate is unchanged; read scope is tenant-wide, as for `chart_of_accounts`, and canon names no finer journal read (ADR-0021: a finance-read RLS decision); FIN-9's residue is now the platform writer alone; lines have no other producer or reader. **JE-2 remains OPEN** (a 100 USD debit still balances a 100 EGP credit, on both doors): one currency per entry or translation to a base currency is the accounting-model decision DC-11 owns. JE-5 is the `journal_entries` header's question and stays with that surface |
   ```
   with
   ```text
   | `journal_entry_lines` | **AUDITED** | ADVERSARIAL | `SPEC-245-a-journal-line-is-written-only-with-its-entry` | JE-2, JE-3, JE-4 | `145_a_journal_line_is_written_only_with_its_entry_test.sql` proves that a `finance_manager` holding CREATE_JOURNAL_ENTRY at aal2 is refused, by the missing grant, rewriting a posted entry balanced in another currency and backdated, moving a posted line onto a retired account or into another entry, and appending a balanced pair to a posted entry. Every entry still says what its `journal_entry_created` event says. The same actor at aal1 can neither post through the RPC nor rewrite at the table, an employee cannot post, and another tenant reads nothing. The RPC, now the lines' one writer, is definer with an empty search_path and still charges permission and step-up. Even the platform cannot empty an entry by moving its lines, while a move that leaves both entries balanced passes. `verify_journey_branches.ps1` proves the bulk append, the upsert rewrite and the PATCH at aal2 and aal1 refused over HTTP. Installed/restored mutations restoring either grant, returning the RPC to invoker, dropping the old-parent check or dropping the lock (two sessions) reopen each attack. Swept and classified as non-defects: FIN-8's set rules, the per-row debit-xor-credit CHECK and MONEY-1's NaN rule are unchanged and pinned by `70_...`; tenant isolation (RLS and composite keys to the entry and the account) held; DELETE has no grant; the subscription gate is unchanged; read scope is tenant-wide, as for `chart_of_accounts`, and canon names no finer journal read (ADR-0021: a finance-read RLS decision); FIN-9's residue is now the platform writer alone; lines have no other producer or reader. **JE-2 remains OPEN** (a 100 USD debit still balances a 100 EGP credit, on both doors): one currency per entry or translation to a base currency is the accounting-model decision DC-11 owns. JE-5 is the `journal_entries` header's question and stays with that surface **2026-11-22 (CRM SPEC-327):** `AUDITED`, because JE-2 is contained fail-closed in the gap register: `20261122100000` and `185_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value_test.sql` (with the updated `145_...`) prove that the deferred balance trigger refuses an entry mixing USD and EGP lines with 23514 on the RPC and on the platform's direct writes, while a balanced single-currency entry still posts on both, verified on Platinum Primary. DC-11 still decides the translation model, which replaces the refusal; JE-5 stays with `journal_entries`. |
   ```

   d) replace the line
   ```text
   | `payments` | **AUDITED-OPEN** | ADVERSARIAL | `SPEC-238-payment-is-recorded-on-every-door` | PAY-2, PAY-3, PAY-4 | `126_payment_write_capability_parity_test.sql` proves an employee who sees the payment but lacks RECORD_PAYMENT is refused by the guard's own message on direction, customer, supplier, booking, item, account, currency, method, paid time and rate, with both customers' balances unchanged; same-value assignments, reference edits, the owner's amount correction and a session-less guarded change still land. An installed amount-only mutant lets the same employee's direction, customer and currency rewrites persist and move real balances; the original function is restored byte-identically. **2026-09-28 (SPEC-238):** `140_payment_is_recorded_on_every_door_test.sql` closes **PAY-3** — one deferred-trigger creation event per customer or supplier payment on the RPC, table and platform doors (refund directions stay PAY-4's), `payment_recorded` for customer and `supplier_payment_recorded` for supplier payments, with an in-file mutation. **PAY-4 remains OPEN.** |
   ```
   with
   ```text
   | `payments` | **AUDITED** | ADVERSARIAL | `SPEC-238-payment-is-recorded-on-every-door` | PAY-2, PAY-3, PAY-4 | `126_payment_write_capability_parity_test.sql` proves an employee who sees the payment but lacks RECORD_PAYMENT is refused by the guard's own message on direction, customer, supplier, booking, item, account, currency, method, paid time and rate, with both customers' balances unchanged; same-value assignments, reference edits, the owner's amount correction and a session-less guarded change still land. An installed amount-only mutant lets the same employee's direction, customer and currency rewrites persist and move real balances; the original function is restored byte-identically. **2026-09-28 (SPEC-238):** `140_payment_is_recorded_on_every_door_test.sql` closes **PAY-3** — one deferred-trigger creation event per customer or supplier payment on the RPC, table and platform doors (refund directions stay PAY-4's), `payment_recorded` for customer and `supplier_payment_recorded` for supplier payments, with an in-file mutation. **PAY-4 remains OPEN.** **2026-11-22 (CRM SPEC-327):** `AUDITED`, because PAY-4 is fixed in the gap register: `20261122100000` adds the validated `payments_amount_positive_check` (`amount > 0`) and `185_...` proves a zero `customer_refund` row refused at the table door for the owner at aal2 and for the platform, a recorded payment that cannot be emptied to zero, the smallest positive amount and `app.record_payment` still accepted, verified on Platinum Primary. |
   ```

   The resulting file's Git blob is f4fad84038b67bf00686d36e4a3c543314f68581.

8. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-22 (CRM exit bundle C, SPEC-328.`; if so record Already Applied when its Git blob is a28c51c3b52f50e6c7b0de8ab8a9131d63f43287, and otherwise stop and report. Otherwise make exactly these 5 edits (the grouped selection, the per-item registry closure and the dated SPEC-328 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-21 (CRM exit bundle B, SPEC-326. The Action registry records the owner's grouped selection of RFD-3, CHAT-2 and the PAY-5/FIN-11 unit, whose events and invoice settlement belong to each table's own producer on every door.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM exit bundle C, SPEC-328. The Action registry records the grouped selection of JE-2, through the fail-closed single-currency containment, and PAY-4, which share the finance-ledger write boundary; SPEC-327 delivered and deployed it and was cancelled, and this contract carries it forward.)

   Previously: 2026-11-21 (CRM exit bundle B, SPEC-326. The Action registry records the owner's grouped selection of RFD-3, CHAT-2 and the PAY-5/FIN-11 unit, whose events and invoice settlement belong to each table's own producer on every door.)
   ```

   b) replace the lines
   ```text
   | PAY-4 | VERIFIED DEFECT | engineering | `FIRST-PAYMENT` | — | Low. The table accepts a zero-value payment coded as a customer refund. A payment entry-shape rule derived from the sanctioned RPCs |
   | JE-2, DC-11 | VERIFIED DEFECT | engineering | `FIRST-JOURNAL-ENTRY` | the finance model (OD-1) | Medium. An entry can balance across two currencies. Decide DC-11, or contain the gap fail-closed by refusing a mixed-currency entry until the model is decided; launch never presents a false balance |
   ```
   with
   ```text
   | PAY-4 | VERIFIED DEFECT | engineering | `FIRST-PAYMENT` | — | SPEC-327 and Test 185 close it on Platinum Primary: `payments_amount_positive_check` requires `amount > 0` on every door, the rule `app.record_payment` and `app.record_supplier_payment` already enforce. |
   | JE-2, DC-11 | VERIFIED DEFECT | engineering | `FIRST-JOURNAL-ENTRY` | the finance model (OD-1) | Medium. SPEC-327 and Test 185 contain JE-2 fail-closed on Platinum Primary: the deferred balance trigger refuses an entry whose lines carry more than one currency, on every door. DC-11 still decides the translation model; launch never presents a false balance. |
   ```

   c) replace the line
   ```text
   | `journal_entry_lines` | SURFACE | engineering | `B6-EXIT` | JE-2 and DC-11 | SPEC-245 and test 145 close JE-3/JE-4 and the STEPUP-1 member. JE-2 needs the existing accounting decision or the recorded fail-closed single-currency containment. Resolve the exit evidence for that invariant. |
   ```
   with
   ```text
   | `journal_entry_lines` | SURFACE | engineering | `B6-EXIT` | JE-2 and DC-11 | SPEC-245 and test 145 close JE-3/JE-4 and the STEPUP-1 member. SPEC-327 and Test 185 close JE-2's exit evidence on Platinum Primary with the recorded fail-closed single-currency containment. DC-11 keeps the translation model. |
   ```

   d) replace the line
   ```text
   | `payments` | SURFACE | engineering | `B6-EXIT` | PAY-4 and exit integrity evidence | SPEC-221/238 and tests 126/140 close PAY-2/PAY-3. PAY-4 still needs a sanctioned payment-entry shape at first payment. Preserve its trigger and resolve the explicit exit obligation. |
   ```
   with
   ```text
   | `payments` | SURFACE | engineering | `B6-EXIT` | PAY-4 and exit integrity evidence | SPEC-221/238 and tests 126/140 close PAY-2/PAY-3. SPEC-327 and Test 185 close PAY-4 on Platinum Primary: a payment row carries `amount > 0` on every door. The payment trigger is preserved. |
   ```

   e) immediately after the lines
   ```text
   **Recorded exception, 2026-11-21, CRM exit bundle B.** After CRM SPEC-325 at `7c5975a09b9351308a3178f1c1579798747fbe51`, the owner's 2026-11-20 directive authorized grouping items that share evidence, tests and a release boundary while keeping per-item acceptance. SPEC-326 selects RFD-3, CHAT-2 and the PAY-5/FIN-11 unit, which share one boundary: a refund transition, a conversation transition and an allocation's invoice settlement are recorded by the table's own producer on every door, and the RPCs stop emitting them a second time. Test 184 proves each selected effect on one isolated schema. PAY-9, PAY-4, JE-2, CAMP-4, BRANCH-2 and PAX-8 keep their own triggers. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle C.** After CRM SPEC-326 at `17ec05a0904f9b5eac676b2d0024d71850886441`, the owner's 2026-11-20 directive authorized grouping items that share evidence, tests and a release boundary while keeping per-item acceptance. SPEC-327 selects JE-2, through the recorded fail-closed single-currency containment while DC-11 stays open, and PAY-4, through the entry-shape rule derived from the sanctioned payment RPCs. Both are the exit evidence of the `journal_entry_lines` and `payments` surfaces and share the finance-ledger write boundary: the deferred balance trigger refuses a mixed-currency entry and a payment row carries `amount > 0`, on every door. Test 185 proves each selected effect on one isolated schema. PAY-9 keeps FIRST-BOOKING and DC-11 keeps the finance model. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```

   The resulting file's Git blob is a28c51c3b52f50e6c7b0de8ab8a9131d63f43287.

9. **Confirm the exact API contract.** After the local CRM stack is rebuilt with the carried migration, run the repository API generator. The resulting Git blob must be 62af74be28b058e41b6b6bcfbe43457f15acfd33, unchanged. In a stack-free isolated rehearsal this step is deferred to Original DATABASE readiness.

10. **Establish readiness and verify Primary read-only.** Run the native DATABASE readiness, including full SQL tests, HTTP and smoke, API generation and Git blob comparison: 277 migrations, latest `20261122100000`, fingerprint `7d224a770526c87f171b9525b0817701`, 185 files and 3456 assertions. Read live Primary project `vrvtsxexkiiiivlkdxzp` through the read-only route only: require 277 migrations, latest `20261122100000`, fingerprint `7d224a770526c87f171b9525b0817701`, the validated `payments_amount_positive_check`, the single-currency branch in `app.enforce_journal_entry_balanced`, full-function-surface hash `ca519b79e522cff13cd309456f618a14` and structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee`. Record Already Applied. On any difference stop and report; make no Primary write. Require repository consistency PASS, then set Runtime Checkpoint DONE and commit the implementation.

11. **Verify and release through the native lifecycle.** Run timed and watched Finish, independent Review, Complete and bind with exact evidence. Set `Last Completed: **SPEC-328: A ledger entry balances in one currency, and a payment carries value.**`, clear the active pointer, regenerate discovery and bind the exact candidate. Publish, hosted preflight, Promote, main checks and Remote Certify use separate native exact-candidate records and the current delegated authority.

## Acceptance Criteria

- [ ] The deployed migration is carried byte for byte. `check: blob supabase/migrations/20261122100000_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value.sql 606ce8ad8a5d8bf928cb11b920fbae0e79714a9b`
- [ ] Test 145 pins JE-2 as CONTAINED and keeps JE-3/JE-4. `check: blob supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql 926f2eac4f1c96b5a5814a9c134115d34343e253`
- [ ] Test 185 proves every selected effect on every door with its positive controls. `check: blob supabase/tests/185_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value_test.sql 67a626e1efa1d1f69109bd107bb8cfe3ae6141af`
- [ ] The recorded Primary evidence is carried. `check: blob reports/evidence/primary-ledger-evidence.json 2db7dde875ec85455c89bbbb960a48923a854e32`
- [ ] PAY-4 is fixed and JE-2 contained in the gap register. `check: blob reports/master/MASTER_GAP_REGISTER.md b442d9f1ad801e1041e07d4eb76951afc06c249b`
- [ ] journal_entry_lines and payments are AUDITED. `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md f4fad84038b67bf00686d36e4a3c543314f68581`
- [ ] The grouped selection, the per-item registry closure and the dated header are exact. `check: blob reports/master/MASTER_EXECUTION_PLAN.md a28c51c3b52f50e6c7b0de8ab8a9131d63f43287`
- [ ] The generated API contract is unchanged. `check: blob reports/master/MASTER_API_CONTRACT.md 62af74be28b058e41b6b6bcfbe43457f15acfd33`
- [ ] Native selection stays intact. `check: same scripts/batch6_select_target.ps1 @ac6bc7a9aea091d93a02a43ae2734fdbe0e716cb`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **185 files / 3456 assertions**"`
- [ ] Live Primary equals the recorded ledger and surfaces, read only; no Primary write. DC-11, PAY-9, FIN-9 and LI-3 keep their recorded triggers.

## Execution Log

None.


### 2026-11-22 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was ac6bc7a9aea091d93a02a43ae2734fdbe0e716cb and every source anchor matched there; Draft allocated as 42adaf8 and approved as ffab0c5 with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `supabase/migrations/20261122100000_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value.sql` edited exactly as the step states; blob 606ce8ad8a5d8bf928cb11b920fbae0e79714a9b (99 insertions, 0 deletions (created)).
- Step 3 Applied: `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql` edited exactly as the step states; blob 926f2eac4f1c96b5a5814a9c134115d34343e253 (12 insertions, 7 deletions).
- Step 4 Applied: `supabase/tests/185_a_ledger_entry_balances_in_one_currency_and_a_payment_carries_value_test.sql` edited exactly as the step states; blob 67a626e1efa1d1f69109bd107bb8cfe3ae6141af (142 insertions, 0 deletions (created)).
- Step 5 Applied: `reports/evidence/primary-ledger-evidence.json` edited exactly as the step states; blob 2db7dde875ec85455c89bbbb960a48923a854e32 (10 insertions, 9 deletions).
- Step 6 Applied: `_ORVION_CANONICAL/manifest.md` edited exactly as the step states; blob efff5b2e48fed35dc26ab983ad54324889df346f (1 insertions, 1 deletions).
- Step 7 Applied: `reports/master/MASTER_GAP_REGISTER.md` edited exactly as the step states; blob b442d9f1ad801e1041e07d4eb76951afc06c249b (5 insertions, 3 deletions).
- Step 8 Applied: `reports/master/MASTER_SURFACE_DISPOSITION.md` edited exactly as the step states; blob f4fad84038b67bf00686d36e4a3c543314f68581 (6 insertions, 4 deletions).
- Step 9 Applied: `reports/master/MASTER_EXECUTION_PLAN.md` edited exactly as the step states; blob a28c51c3b52f50e6c7b0de8ab8a9131d63f43287 (9 insertions, 5 deletions).
- Step 10 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-22 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-328 only, the successor of Cancelled SPEC-327, under DEC-02 and Batch 6 PLAN section 2 run mode 2 as redefined by the owner on 2026-11-21 (owner-2026-11-21-run-modes-redefined.txt, SHA-256 35E35600BB9D2D69EBF0A85BE8E6256260617F9A8B47F74A091565BC53AF69DD). Exact Draft SHA-256 6B5CDD693E4233C3A624903C06B62BF51B1C463DA928F205C37225E7DDA0EB6F, Git blob c14b731cb71b18ec08d1de0e69c1942aa1b91cac, CRM baseline ac6bc7a (SPEC-327 Cancel, carried). Native isolated Approve 6acbbe2 and implement da3c429 passed with 8 committed blobs verified, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 E1F61862C7996D270931A8B40D340D668384CF03C220BF4F1EA494CCBBE40B79). No Primary write: the Primary step is a read-only Already Applied verification. Gate 1 only. Immediately before allocation the hash, the Draft blob c14b731cb71b18ec08d1de0e69c1942aa1b91cac, all 6 source anchors, the baseline HEAD ac6bc7a9aea091d93a02a43ae2734fdbe0e716cb against refreshed origin/main 17ec05a0904f9b5eac676b2d0024d71850886441 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 42adaf8. No implementation performed before this transition.

## Review Gate

- [ ] Exact approved payload and allowed scope.
- [ ] Carried bytes equal the SPEC-327 delivery; native SQL, smoke, HTTP and API evidence pass.
- [ ] Read-only Primary identity, ledger and surfaces equal the records.
- [ ] Existing open items and governance gates retained.

## Notes

Baseline: ac6bc7a9aea091d93a02a43ae2734fdbe0e716cb.

Owner authority: Workbench `data/records/batch6/owner-words/owner-2026-11-20-batch-more-work-directive.txt`, SHA-256 `383D3198EBC1E7E0B46CE19945B0FBF35A062A5A74B3AF0792DEE13EB6734840`. Run mode: Workbench `data/records/batch6/owner-words/owner-2026-11-21-run-modes-redefined.txt`, SHA-256 `35E35600BB9D2D69EBF0A85BE8E6256260617F9A8B47F74A091565BC53AF69DD`. Delegated Cancel and successor decision: Workbench `data/records/batch6/exit-bundle-c/spec327/DELEGATED-CANCEL.md`. This Draft conveys no Original or release approval and no Primary write.

Isolated proof: Workbench `data/records/batch6/exit-bundle-c/` `RECHECK.md`, `prototype-pgtap.log`, `prototype-smoke.log`, `prototype-http.log`, `prototype-api.md`, `prototype-catalog.log`, `prototype-parity.log`, `spec327/runtime/original-primary-postdeploy-read.json` and `spec327-successor/primary-already-applied-read.log`.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql` | `26176d95881764bd6e6becc3bdaeca007f9befe6` |
| `reports/evidence/primary-ledger-evidence.json` | `f0d1b0cb4fc9d188d3f9929577784b9cae164f6e` |
| `_ORVION_CANONICAL/manifest.md` | `abcb94a58064c708050aa846daa58a4a085dc489` |
| `reports/master/MASTER_GAP_REGISTER.md` | `136559c79ac79bdf02c15e81381f124d79a503ed` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `b39d9b881fee06994a402f69ecfb6540270a464f` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `b766c82547d6c870d3cc2ecf16a51e387668a7d4` |
