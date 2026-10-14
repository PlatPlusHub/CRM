-- Batch 6 Slice 42 -- chart_of_accounts. COA-1 and COA-2.
--
-- A chart account is what a journal line MEANS: `app.create_journal_entry` resolves each line by the
-- account's code, and the account's type classifies the money posted to it. A posted entry is
-- corrected by a reversal, never by mutation (canon 07 and 30; JE-3, JE-5). Canon 14 lets a company
-- customize its chart "according to permissions", and the sanctioned writer,
-- `app.seed_default_chart_of_accounts`, charges `app.authorize('CREATE_JOURNAL_ENTRY')`, step-up
-- included. `authenticated` holds INSERT and UPDATE on the table, and the door asked only
-- `app.has_permission`.
--
-- MEASURED on the local stack, in rolled-back transactions:
--   * COA-1. A `finance_manager` at aal1 -- where both RPCs refuse for want of step-up -- retyped
--     the revenue account 4000 to `expense` and recoded it to 4999 after a 1000 credit had been
--     posted to it, so the posted entry now reads as an expense. Then account 5000 (Cost of Sales)
--     took the code 4000, so the RPC's next "4000" posting lands on an expense account. No event
--     recorded any of it.
--   * COA-2 (STEPUP-1's member on this table). Every write above was made at aal1, where the seed
--     RPC refuses the same act (42501, multi-factor authentication required).
--
-- THE INVARIANT: an account's code and type are fixed once a journal line is posted to it, and the
-- door charges what the seed RPC charges. Renaming, re-parenting and retiring stay the tenant's
-- customization: nothing reads `name` or `parent_account_id`, and `is_active` is read only to refuse
-- a NEW posting (JE-1). `account_type` stays plain text (ADR-0006); its vocabulary is not enforced
-- here.
--
-- The integrity rule applies to every caller, session-less included (FIN-8, PAY-6). The capability
-- check keeps canon 35 principle 6's platform path, as every guard here does. SECURITY DEFINER for
-- BOOK-1's reason: under INVOKER the line read would be RLS-filtered. Precedent for "fixed once
-- used": `app.forbid_used_account_redenomination` on `financial_accounts`.
-- NOT CHANGED: grants, policies, the seed and posting RPCs, the catalog and subscription gates, the
-- unique key on (tenant, code), and the event catalog (canon 27 registers no chart-account event).

create or replace function app.guard_chart_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    -- COA-2: the door charges what the seed RPC charges, step-up included.
    if (select auth.uid()) is not null then
        perform app.authorize('CREATE_JOURNAL_ENTRY');
    end if;

    -- COA-1: what a posted line means does not move. The FOR UPDATE conflicts with the KEY SHARE a
    -- concurrent posting's foreign key holds, so a posting in flight is waited for and then seen.
    -- `old`, never `new`, says which account is asked about.
    if tg_op = 'UPDATE'
       and (new.code is distinct from old.code or new.account_type is distinct from old.account_type) then
        perform 1 from public.chart_of_accounts where id = old.id for update;
        if exists (select 1 from public.journal_entry_lines l
                    where l.tenant_id = old.tenant_id and l.chart_account_id = old.id) then
            raise exception 'chart account %: its code and type are fixed once a journal line is posted to it',
                old.code using errcode = '23514';
        end if;
    end if;

    return new;
end
$fn$;

comment on function app.guard_chart_account() is
    'COA-1/2: a used chart account keeps its code and type, and the door charges CREATE_JOURNAL_ENTRY with step-up.';
revoke all on function app.guard_chart_account() from public;

create trigger chart_of_accounts_guard
    before insert or update on public.chart_of_accounts
    for each row execute function app.guard_chart_account();
