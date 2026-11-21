# Change Request — SPEC-326

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close three reproduced two-door gaps by moving each side effect from the RPC to the table's own producer, in the existing SPEC-262 producer shape. A refund's request and each refund transition are recorded once on both doors, with the RPC reason carried through `app.transition_reason` (RFD-3). A conversation's transition is recorded once on both doors, a signed-in close stamps `closed_at` and a reopen requires a reason (CHAT-2). An allocation derives its invoice's `partially_paid` or `paid` status and emits the invoice event on both doors, forward only and under `app.record_payment`'s own advisory lock (PAY-5 and FIN-11). The RPCs stop emitting or deriving a second time.

## Business Reason

Each gap was reproduced at CRM `7c5975a` in rolled-back transactions. A finance user at aal2 requested, approved and completed a refund at the table door with no refund event, where the RPC door records three. An employee assigned, closed and reopened a conversation at the table door with no transition event, `closed_at` left null after the close and no reopen reason. An owner at aal2 allocated a full payment at the table door and the invoice stayed `issued` with no invoice event, where `app.record_payment` moves it to `paid` with one `invoice_paid`. The employee's direct escalate was already refused by the existing per-edge transition guard, so no authority changes. The owner's 2026-11-20 directive groups items that share evidence, tests and a release boundary while keeping per-item acceptance.

## Risks

CREATE TRIGGER and CREATE OR REPLACE FUNCTION take locks on refunds, conversations and payment_allocations. Measure the lock state before the write; Primary holds zero rows in every scoped table. Preserve every grant, policy, permission, RLS predicate, the per-edge transition guards, the SPEC-264 allocation floor and serialisation, and the void guard. A settlement never walks back and a zero allocation settles nothing. Session-less platform paths remain exempt from the conversation guard. The rollback path is a separately authorized corrective migration that drops the five new triggers and functions and restores the four previous RPC definitions. Do not rewrite existing business rows.

## Supersedes / Depends On

Depends on SPEC-217 (refund door integrity), SPEC-220 (conversation creation parity), SPEC-237 (`app.transition_reason`), SPEC-238 (payments on every door), SPEC-262 (the producer shape), SPEC-264 (allocation authority, floor and serialisation) and the CRM SPEC-325 baseline. Supersedes only the Test 54, 96, 140 and 155 assertions that recorded `app.record_payment` as the invoice status's deriver.

## Write Scope

- `changes/SPEC-326-a-refund-a-conversation-and-a-settlement-are-recorded-on-every-door.md`
- `supabase/migrations/20261121110000_a_refund_a_conversation_and_a_settlement_are_recorded_on_every_door.sql`
- `supabase/tests/54_transition_permission_parity_test.sql`
- `supabase/tests/96_invoice_void_and_eta_boundary_test.sql`
- `supabase/tests/140_payment_is_recorded_on_every_door_test.sql`
- `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql`
- `supabase/tests/184_refund_conversation_and_settlement_are_recorded_on_every_door_test.sql`
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

All other paths, Founder Secondary, integration activation, email delivery, UI, the booking-scoped balance (PAY-9), first-payment evidence (PAY-4), journal entries (JE-2), refund severities, LI-3, CAMP-4, BRANCH-2, PAX-8 and GitHub configuration are outside scope.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9; `ENGINEERING_METHOD.md` §§2, 4 and 5.
- Canon 27 on transition reasons and severities.
- SPEC-262 producer shape, SPEC-237 `app.transition_reason`, SPEC-264 migration and `app.record_payment`, `app.record_refund`, `app.advance_refund` and `app.advance_conversation`.
- `reports/master/MASTER_EXECUTION_PLAN.md` action registry; RFD-3, CHAT-2, PAY-5, FIN-9, FIN-11 and PAY-9 in the gap register.
- `supabase/tests/123_refund_door_integrity_test.sql`, `supabase/tests/125_conversation_creation_parity_test.sql`, `supabase/tests/140_payment_is_recorded_on_every_door_test.sql` and `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql`.

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

Pass 1 Design: Reuse the SPEC-262 table producer shape and SPEC-237 `app.transition_reason` rather than adding a new mechanism. Refunds get AFTER INSERT and AFTER UPDATE OF refund_status_code producers. Conversations get a signed-in BEFORE UPDATE guard that stamps `closed_at` and refuses a reasonless reopen, and an AFTER UPDATE producer for assigned, escalated, closed and reopened. Payment allocations get one AFTER INSERT OR UPDATE OF the allocated amounts producer that derives the invoice status under `app.record_payment`'s advisory lock, on issued, partially_paid or overdue invoices only. `app.record_refund`, `app.advance_refund` and `app.advance_conversation` stop emitting, and `app.record_payment` stops deriving, so each effect has one source.

Pass 2 Adversarial Review: Rolled-back reproductions at the baseline prove each gap and its consequence, and that conversation escalate authority already holds. There is no DELETE grant on payment_allocations, a lowering never walks a settlement back, and the SPEC-264 floor already refuses reductions under `paid`. The first full run found that a zero allocation settled its invoice (Test 155 #16); the producer now settles nothing on zero, and Test 184 asserts it. Tests 54, 96, 140 and 155 moved to the derived status with their intent kept; Test 96 writes its void fixture allocation with only the settlement trigger off, so the void guard is still what it proves. Test 184 checks one emission per door, the RPC reason carried through, the stamp and reopen refusal, the settlement on both doors, forward-only behaviour, zero settling nothing, the session-less exemption and trigger timing. Refund severities keep the RPC's, and PAY-9, PAY-4 and JE-2 stay at their recorded triggers.

Pass 3 Evidence Refresh: 2026-11-21. On isolated CRM baseline 7c5975a09b9351308a3178f1c1579798747fbe51, the repaired schema has 276 migration rows, latest `20261121110000`, ledger fingerprint `3d6fe3908078c02f611c70b4eb070623`, with five new triggers, five new functions, four replaced RPC bodies and unchanged API grants. The full pgTAP run passed 184 files and 3445 assertions. Database smoke passed, and the existing HTTP suite passed 35 assertions on the isolated API through its local container adapter. The regenerated API contract changes only the `record_payment` row. Primary `vrvtsxexkiiiivlkdxzp` was read separately at 275 migrations, latest `20261121100000`, fingerprint `5213d0d035d53e635a839f0ce9bb7693`, with the target absent and zero rows in refunds, conversations, payment_allocations, invoices and payments. Recheck live at the deployment boundary.

Selected Version: SPEC-326; selected: table-door producers in the SPEC-262 shape for refunds and conversations and one forward-only allocation settlement producer, with the RPCs stripped of their duplicate emission and derivation, proven in one suite with four aligned test files

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Refund request and transition events | `app.record_refund`, `app.advance_refund`, the refunds table door, timeline and audit readers | WRITE | Test 184 proves one emission per door with the RPC reason carried through and server-stamped completion. Test 123 passes unchanged, and refund entry and authority are untouched. |
| Conversation transition, close stamp and reopen reason | `app.advance_conversation`, the conversations table door, the per-edge transition guard | WRITE | Test 184 proves one emission per door, the `closed_at` stamp, the 23514 reasonless-reopen refusal, warning severity for escalated and reopened, and the session-less exemption. Test 125 passes unchanged, and escalate authority is unchanged. |
| Invoice settlement status and invoice events | `app.record_payment`, the payment_allocations door, SPEC-264 floor and serialisation, the invoice transition guard, the void guard | WRITE | Test 184 proves settlement on both doors, forward only, nothing on zero, under the existing lock. Tests 54, 96, 140 and 155 move to the derived status with their intent kept. The invoice UPDATE stays charged RECORD_PAYMENT. |
| `payment_recorded` event invoice status | Its readers and Test 140 | VERIFY | The event reports the status the allocation derived; Test 140 asserts `paid`. |
| B6-EXIT evidence | RFD-3, CHAT-2, PAY-5, FIN-11, FIN-9 and the three disposition rows | WRITE | Record closure after hosted proof. PAY-9, PAY-4, JE-2 and LI-3 keep their own triggers. |
| Contract evidence | Generated API, Primary ledger and parity, manifest and discovery | WRITE | Reuse native generation and evidence methods; the API contract changes only in the `record_payment` row. |
| Founder, integrations, email and frontend | Existing workflows | UNAFFECTED | No product action, integration or client changes. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 10 (Platinum Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact approved payload, local functional proof, fresh target identity and recovery evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 9 |
| Recorded ledger reflects the actual Platinum Primary ledger | BEFORE_COMPLETION | Step 1 | Step 11 | Step 12 |
| Repository and local figures match the pre-deploy payload | BEFORE_IRREVERSIBLE_ACTION | Step 1 | Step 9 | Step 10 |
| Generated evidence agrees with the deployed structure | BEFORE_COMPLETION | Step 10 | Step 11 | Step 12 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The SPEC-262 table producer shape, SPEC-237 `app.transition_reason`, the existing per-edge transition guards and SPEC-264's allocation floor and `app.record_payment` advisory lock.

Added Property: On refunds, conversations and payment_allocations, each transition and each invoice settlement is recorded once by the table itself, whichever door wrote it.

Causal Negative: Workbench reproduction `repro-7c5975a` at `7c5975a` shows the table door writing without these effects where this change records them.

Positive Test Design: Test 184 requires one event per transition on both doors, the RPC reason preserved, the `closed_at` stamp, a reopen with a reason accepted, and an invoice moving to `partially_paid` then `paid` with one event each on both doors.

Negative Test Design: Test 184 requires the reasonless reopen refused with 23514 and nothing stored, no second emission from any RPC, no settlement on a zero allocation or a non-settleable invoice, and no walk-back on a lowering. Tests 54 and 155 pin the deriver and the floor.

Non-Empty Population Obligation: Test 184 establishes tenants, real permission holders at aal1 and aal2, customers, invoices, payments, refunds and conversations before testing refusals and valid writes.

Mutation Obligation: Disabling any of the five new triggers in a rolled-back transaction must turn a Test 184 assertion red; the baseline reproduction must differ in exactly the recorded behaviors.

Post-Implementation Proof Obligation: Fresh approved Primary apply and separate readback agree with local ledger and structural fingerprints. Re-run native consistency and readiness evidence and retain PAY-9, PAY-4, JE-2 and LI-3 at their recorded triggers.

## Implementation Steps

1. Check whether `supabase/migrations/20261121110000_a_refund_a_conversation_and_a_settlement_are_recorded_on_every_door.sql` contains `-- B6-EXIT bundle B: a refund's life, a conversation's life and an invoice's settlement are produced by`; if so record Already Applied when its Git blob is 52bb1f1577f4346b439a1c33c47b233de5d4935d, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the refund, conversation and settlement producer migration), and change nothing else:

   ```text
   -- B6-EXIT bundle B: a refund's life, a conversation's life and an invoice's settlement are produced by
   -- the table, so the table door records them exactly as the RPC door does.
   --
   -- `authenticated` holds table-level INSERT and UPDATE on `public.refunds`, `public.conversations` and
   -- `public.payment_allocations`, and `app.record_refund`, `app.advance_refund`,
   -- `app.advance_conversation` and `app.record_payment` are SECURITY INVOKER through those same grants,
   -- so PostgREST serves each table beside its RPC. Measured at `7c5975a` on the local stack in
   -- rolled-back transactions (Workbench data/records/batch6/exit-bundle-b/repro-7c5975a.sql):
   --   * RFD-3: an aal2 finance_manager inserted a refund `requested`, then moved it `approved` and
   --     `completed` at the table: 0 events. The RPC door recorded refund_requested, refund_approved and
   --     refund_completed (warning) with their reasons. `completed_at` is already server-stamped on both
   --     doors by `app.guard_refund_integrity`.
   --   * CHAT-2: an employee moved a conversation `open -> assigned -> closed -> open` at the table: no
   --     transition event (only conversation_started), `closed_at` left null after the close, and the
   --     reopen accepted with no reason. The RPC recorded assigned, closed and reopened, all at `info`,
   --     where canon 26 and 27 require a reopen reason and make `conversation_escalated` and
   --     `conversation_reopened` warnings. The employee's direct escalate was already refused 42501 by
   --     the per-edge transition guard: authority needs no change.
   --   * PAY-5 / FIN-11: an aal2 owner inserted a 5000 payment and a 5000 allocation against a 5000
   --     invoice: the invoice stayed `issued`, 0 invoice events, and `payment_recorded` reported
   --     `invoice_new_status` `issued`. `app.record_payment` alone derived `paid` and emitted
   --     invoice_paid, so the settlement belonged to one door instead of the table.
   --
   -- THE SHAPE is SPEC-262's (`20261011090000`): SECURITY INVOKER guard and producers; one AFTER producer
   -- per event, and its RPC loses its own `record_event`, so no act is recorded twice; the RPC's reason
   -- reaches the guard and the producer through SPEC-237's transaction-local `app.transition_reason`
   -- (`20260928160000`), which the producer consumes. The conversation guard is signed-in only (canon 35
   -- principle 6): it stamps `closed_at` as the RPC does and refuses a reopen without a reason. The
   -- settlement producer is record_payment's own derivation moved onto `payment_allocations`: under the
   -- same per-invoice advisory lock it sums the allocations, sets `paid` / `partially_paid` and emits
   -- invoice_paid / invoice_partially_paid with the same payload. Its invoice UPDATE runs as the caller,
   -- exactly as record_payment's did, so `app.enforce_status_transition` still charges RECORD_PAYMENT and
   -- `app.guard_financial_capability` still prices it. A raised allocation re-derives forward; nothing
   -- walks a settled invoice back (no such edge exists). The trigger sorts after
   -- `payment_allocations_emit_created`, so the allocation is recorded before the settlement it causes.
   --
   -- NOT CHANGED: every grant, policy, permission charge, state transition and other trigger; the
   -- reasons and payloads each event already carried; the refund severities (completed stays warning);
   -- record_payment's validations, lock, outstanding check and inserts.

   -- ===================================================================== RFD-3 refunds
   create or replace function app.emit_refund_requested()
   returns trigger
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   begin
       perform app.record_event(
           new.tenant_id, 'refund_requested', 'refund', new.id,
           case when (select auth.uid()) is null then null else app.current_user_id() end,
           null, new.refund_status_code, new.refund_reason_code,
           jsonb_build_object('customer_id', new.customer_id, 'booking_id', new.booking_id,
                              'amount', new.amount, 'currency_code', new.currency_code),
           'info');
       return null;
   end;
   $$;
   revoke execute on function app.emit_refund_requested() from public;

   create trigger refunds_emit_requested
   after insert on public.refunds
   for each row execute function app.emit_refund_requested();

   create or replace function app.emit_refund_transition()
   returns trigger
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_reason text := nullif(current_setting('app.transition_reason', true), '');
       v_event text;
   begin
       -- Consumed: a later transition in the same transaction carries only its own reason.
       perform set_config('app.transition_reason', '', true);
       v_event := case new.refund_status_code
           when 'approved' then 'refund_approved'
           when 'rejected' then 'refund_rejected'
           when 'cancelled' then 'refund_cancelled'
           when 'processing' then 'refund_processing'
           when 'completed' then 'refund_completed'
       end;
       if v_event is null then
           return null;
       end if;
       perform app.record_event(
           new.tenant_id, v_event, 'refund', new.id,
           case when (select auth.uid()) is null then null else app.current_user_id() end,
           old.refund_status_code, new.refund_status_code, v_reason,
           jsonb_build_object('customer_id', new.customer_id, 'amount', new.amount,
                              'currency_code', new.currency_code),
           case when new.refund_status_code = 'completed' then 'warning' else 'info' end);
       return null;
   end;
   $$;
   revoke execute on function app.emit_refund_transition() from public;

   create trigger refunds_emit_transition
   after update of refund_status_code on public.refunds
   for each row
   when (new.refund_status_code is distinct from old.refund_status_code)
   execute function app.emit_refund_transition();

   -- The complete current SECURITY INVOKER RPC, removing only its event call.
   create or replace function app.record_refund(
       p_customer_id uuid,
       p_amount numeric,
       p_currency_code text,
       p_refund_reason_code text,
       p_booking_id uuid default null,
       p_original_payment_id uuid default null
   )
   returns uuid
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_tenant uuid := app.current_tenant_id();
       v_actor uuid;
       v_refund_id uuid;
   begin
       if v_tenant is null then
           raise exception 'no active tenant for caller';
       end if;
       if p_amount is null or p_amount <= 0 then
           raise exception 'refund amount must be greater than zero';
       end if;
       if not exists (
           select 1 from public.catalog_values
           where catalog_type_code = 'refund_reason_code' and code = p_refund_reason_code
       ) then
           raise exception 'unknown refund_reason: %', p_refund_reason_code;
       end if;

       perform 1 from public.customers where id = p_customer_id and tenant_id = v_tenant;
       if not found then
           raise exception 'customer is not in your tenant';
       end if;
       if p_booking_id is not null then
           perform 1 from public.bookings where id = p_booking_id and tenant_id = v_tenant;
           if not found then
               raise exception 'booking is not in your tenant';
           end if;
       end if;
       if p_original_payment_id is not null then
           perform 1 from public.payments where id = p_original_payment_id and tenant_id = v_tenant;
           if not found then
               raise exception 'original payment is not in your tenant';
           end if;
       end if;

       perform app.authorize('RECORD_REFUND');

       select id into v_actor
       from public.users
       where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

       -- RFD-3: `refund_requested` is produced by `refunds_emit_requested` on every door.
       insert into public.refunds (
           tenant_id, payment_direction_code, original_payment_id, customer_id, booking_id,
           refund_reason_code, currency_code, amount, refund_status_code, requested_at, created_by
       ) values (
           v_tenant, 'customer_refund', p_original_payment_id, p_customer_id, p_booking_id,
           p_refund_reason_code, p_currency_code, p_amount, 'requested', now(), v_actor
       ) returning id into v_refund_id;

       return v_refund_id;
   end;
   $$;

   -- The complete current SECURITY INVOKER RPC, removing only its event call; its reason reaches
   -- `refunds_emit_transition` through `app.transition_reason`.
   create or replace function app.advance_refund(
       p_refund_id uuid,
       p_to_status text,
       p_reason text default null
   )
   returns text
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_tenant uuid := app.current_tenant_id();
       v_rf record;
       v_event text;
   begin
       if v_tenant is null then
           raise exception 'no active tenant for caller';
       end if;

       select id, refund_status_code, customer_id, amount, currency_code
         into v_rf
       from public.refunds
       where id = p_refund_id and tenant_id = v_tenant;
       if not found then
           raise exception 'refund is not in your tenant';
       end if;

       select t.ev into v_event
       from (values
           ('requested',  'approved',   'refund_approved'),
           ('requested',  'rejected',   'refund_rejected'),
           ('requested',  'cancelled',  'refund_cancelled'),
           ('approved',   'processing', 'refund_processing'),
           ('approved',   'completed',  'refund_completed'),
           ('approved',   'cancelled',  'refund_cancelled'),
           ('processing', 'completed',  'refund_completed'),
           ('processing', 'cancelled',  'refund_cancelled')
       ) as t(frm, to_s, ev)
       where t.frm = v_rf.refund_status_code and t.to_s = p_to_status;

       if v_event is null then
           raise exception 'refund transition not allowed: % -> %', v_rf.refund_status_code, p_to_status;
       end if;

       perform app.authorize('RECORD_REFUND');

       perform set_config('app.transition_reason', coalesce(p_reason, ''), true);
       update public.refunds
       set refund_status_code = p_to_status,
           completed_at = case when p_to_status = 'completed' then now() else completed_at end,
           updated_at = now()
       where id = p_refund_id;

       return p_to_status;
   end;
   $$;

   -- ===================================================================== CHAT-2 conversations
   create or replace function app.guard_conversation_transition()
   returns trigger
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_reason text;
       v_entered boolean;
   begin
       -- Session-less platform writes keep their latitude (canon 35 principle 6).
       if (select auth.uid()) is null then
           return new;
       end if;
       v_entered := new.conversation_status_code is distinct from old.conversation_status_code;
       if v_entered and old.conversation_status_code = 'closed' and new.conversation_status_code = 'open' then
           v_reason := nullif(btrim(current_setting('app.transition_reason', true)), '');
           if v_reason is null then
               raise exception 'a closed conversation is reopened with a reason (canon 26, 27); use app.advance_conversation with p_reason'
                   using errcode = '23514';
           end if;
       end if;
       -- The server stamps closed_at, as app.advance_conversation does.
       new.closed_at := case
           when v_entered and new.conversation_status_code = 'closed' then now()
           when v_entered and new.conversation_status_code = 'open' then null
           else old.closed_at
       end;
       return new;
   end;
   $$;
   revoke execute on function app.guard_conversation_transition() from public;

   create trigger conversations_guard_transition
   before update on public.conversations
   for each row execute function app.guard_conversation_transition();

   create or replace function app.emit_conversation_transition()
   returns trigger
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_reason text := nullif(current_setting('app.transition_reason', true), '');
       v_reopen boolean := old.conversation_status_code = 'closed'
                           and new.conversation_status_code = 'open';
       v_event text;
   begin
       -- Consumed: a later transition in the same transaction carries only its own reason.
       perform set_config('app.transition_reason', '', true);
       v_event := case
           when v_reopen then 'conversation_reopened'
           else case new.conversation_status_code
               when 'assigned' then 'conversation_assigned'
               when 'escalated' then 'conversation_escalated'
               when 'closed' then 'conversation_closed'
           end
       end;
       -- 26_state_machines.md: the pending_* moves require no event.
       if v_event is null then
           return null;
       end if;
       perform app.record_event(
           new.tenant_id, v_event, 'conversation', new.id,
           case when (select auth.uid()) is null then null else app.current_user_id() end,
           old.conversation_status_code, new.conversation_status_code, v_reason, null,
           case when v_reopen or new.conversation_status_code = 'escalated' then 'warning' else 'info' end);
       return null;
   end;
   $$;
   revoke execute on function app.emit_conversation_transition() from public;

   create trigger conversations_emit_transition
   after update of conversation_status_code on public.conversations
   for each row
   when (new.conversation_status_code is distinct from old.conversation_status_code)
   execute function app.emit_conversation_transition();

   -- The complete current SECURITY INVOKER RPC, removing only its event call; its reason reaches the
   -- guard and `conversations_emit_transition` through `app.transition_reason`.
   create or replace function app.advance_conversation(
       p_conversation_id uuid,
       p_to_status text,
       p_reason text default null
   )
   returns void
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_tenant uuid := app.current_tenant_id();
       v_status text;
       v_event text;
       v_perm text;
       v_matched boolean := false;
   begin
       if v_tenant is null then raise exception 'no active tenant for caller'; end if;

       select conversation_status_code into v_status
       from public.conversations where id = p_conversation_id and tenant_id = v_tenant;
       if v_status is null then raise exception 'conversation not found in your tenant'; end if;

       -- 26_state_machines.md, Conversation State Machine. ev is null where canon requires no event.
       select true, t.ev, t.perm into v_matched, v_event, v_perm
       from (values
           ('open',             'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
           ('assigned',         'pending_customer',  null,                    'SEND_MESSAGE'),
           ('assigned',         'pending_internal',  null,                    'SEND_MESSAGE'),
           ('pending_customer', 'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
           ('pending_internal', 'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
           ('assigned',         'escalated',        'conversation_escalated', 'ESCALATE_CONVERSATION'),
           ('escalated',        'assigned',         'conversation_assigned',  'ESCALATE_CONVERSATION'),
           ('assigned',         'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
           ('pending_customer', 'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
           ('escalated',        'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
           ('closed',           'open',             'conversation_reopened',  'CLOSE_CONVERSATION')
       ) as t(frm, to_s, ev, perm)
       where t.frm = v_status and t.to_s = p_to_status;

       if not v_matched then
           raise exception 'invalid conversation transition % -> %', v_status, p_to_status; end if;
       perform app.authorize(v_perm);

       perform set_config('app.transition_reason', coalesce(p_reason, ''), true);
       update public.conversations
       set conversation_status_code = p_to_status,
           closed_at = case when p_to_status = 'closed' then now()
                            when p_to_status = 'open' then null else closed_at end,
           updated_at = now()
       where id = p_conversation_id and tenant_id = v_tenant;
   end;
   $$;

   -- ===================================================================== PAY-5 / FIN-11 settlement
   create or replace function app.derive_invoice_payment_status()
   returns trigger
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_inv record;
       v_total numeric;
       v_new text;
   begin
       -- Forward only: a raised allocation re-derives; a lowered one never walks a settlement back.
       if tg_op = 'UPDATE' and coalesce(new.allocated_amount_invoice_currency, new.allocated_amount)
                               <= coalesce(old.allocated_amount_invoice_currency, old.allocated_amount) then
           return null;
       end if;
       -- A zero allocation settles nothing: it moves no status and records no settlement.
       if tg_op = 'INSERT' and coalesce(new.allocated_amount_invoice_currency, new.allocated_amount) <= 0 then
           return null;
       end if;

       -- record_payment's own serialisation: concurrent allocations to one invoice settle in turn.
       perform pg_advisory_xact_lock(hashtextextended(new.invoice_id::text, 0));

       select id, status_code, total_amount into v_inv
       from public.invoices
       where id = new.invoice_id and tenant_id = new.tenant_id;
       if not found or v_inv.status_code not in ('issued', 'partially_paid', 'overdue') then
           return null;
       end if;

       select coalesce(sum(coalesce(pa.allocated_amount_invoice_currency, pa.allocated_amount)), 0)
         into v_total
       from public.payment_allocations pa
       where pa.invoice_id = new.invoice_id and pa.tenant_id = new.tenant_id;

       v_new := case when v_total >= v_inv.total_amount then 'paid' else 'partially_paid' end;

       update public.invoices
       set status_code = v_new,
           updated_at = now()
       where id = new.invoice_id and tenant_id = new.tenant_id;
       if not found then
           -- Fail closed: an allocation never stands beside an invoice its writer could not settle.
           raise exception 'invoice % could not be settled by this caller', new.invoice_id
               using errcode = '42501';
       end if;

       perform app.record_event(
           new.tenant_id,
           case when v_new = 'paid' then 'invoice_paid' else 'invoice_partially_paid' end,
           'invoice', new.invoice_id,
           case when (select auth.uid()) is null then null else app.current_user_id() end,
           v_inv.status_code, v_new, null,
           jsonb_build_object('payment_id', new.payment_id, 'allocated_total', v_total,
                              'total_amount', v_inv.total_amount),
           'info');
       return null;
   end;
   $$;
   revoke execute on function app.derive_invoice_payment_status() from public;

   create trigger payment_allocations_settle_invoice
   after insert or update of allocated_amount, allocated_amount_invoice_currency on public.payment_allocations
   for each row execute function app.derive_invoice_payment_status();

   -- The complete current SECURITY INVOKER RPC, removing only its settlement: the invoice status and its
   -- event are produced by `payment_allocations_settle_invoice` from the allocation below.
   create or replace function app.record_payment(
       p_invoice_id uuid,
       p_amount numeric,
       p_payment_method_code text,
       p_paid_at timestamptz default now(),
       p_reference_number text default null
   )
   returns uuid
   language plpgsql
   security invoker
   set search_path = ''
   as $$
   declare
       v_tenant uuid := app.current_tenant_id();
       v_actor uuid;
       v_inv record;
       v_already numeric;
       v_remaining numeric;
       v_payment_id uuid;
   begin
       if v_tenant is null then
           raise exception 'no active tenant for caller';
       end if;
       if p_amount is null or p_amount <= 0 then
           raise exception 'payment amount must be greater than zero';
       end if;
       if not exists (
           select 1 from public.catalog_values
           where catalog_type_code = 'payment_method' and code = p_payment_method_code
       ) then
           raise exception 'unknown payment_method: %', p_payment_method_code;
       end if;

       select id, customer_id, currency_code, total_amount, status_code, voided_at, is_archived
         into v_inv
       from public.invoices
       where id = p_invoice_id and tenant_id = v_tenant;
       if not found then
           raise exception 'invoice is not in your tenant';
       end if;
       if v_inv.is_archived or v_inv.voided_at is not null then
           raise exception 'invoice is archived or voided';
       end if;
       if v_inv.status_code not in ('issued', 'partially_paid', 'overdue') then
           raise exception 'only an issued/partially_paid/overdue invoice can be paid (is %)', v_inv.status_code;
       end if;

       perform app.authorize('RECORD_PAYMENT');

       -- Serialise allocation for this invoice so concurrent payments cannot over-allocate.
       perform pg_advisory_xact_lock(hashtextextended(p_invoice_id::text, 0));

       select coalesce(sum(coalesce(pa.allocated_amount_invoice_currency, pa.allocated_amount)), 0) into v_already
       from public.payment_allocations pa
       where pa.invoice_id = p_invoice_id and pa.tenant_id = v_tenant;

       v_remaining := v_inv.total_amount - v_already;
       if p_amount > v_remaining then
           raise exception 'payment % exceeds invoice outstanding % (total %, already allocated %)',
               p_amount, v_remaining, v_inv.total_amount, v_already;
       end if;

       select id into v_actor
       from public.users
       where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

       insert into public.payments (
           tenant_id, payment_direction_code, customer_id, currency_code,
           payment_method_code, reference_number, amount, paid_at, received_by, created_by
       ) values (
           v_tenant, 'customer_payment', v_inv.customer_id, v_inv.currency_code,
           p_payment_method_code, p_reference_number, p_amount, p_paid_at, v_actor, v_actor
       ) returning id into v_payment_id;

       -- PAY-5 / FIN-11: `payment_allocations_settle_invoice` moves the invoice to partially_paid / paid
       -- and records invoice_partially_paid / invoice_paid on every door.
       insert into public.payment_allocations (
           tenant_id, payment_id, invoice_id, allocated_amount, currency_code, created_by
       ) values (
           v_tenant, v_payment_id, p_invoice_id, p_amount, v_inv.currency_code, v_actor
       );

       -- PAY-3: `payment_recorded` is produced at commit by `payments_emit_recorded` on every door,
       -- from this payment and the allocation above.

       return v_payment_id;
   end;
   $$;
   ```

   The resulting file's Git blob is 52bb1f1577f4346b439a1c33c47b233de5d4935d.

2. Check whether `supabase/tests/54_transition_permission_parity_test.sql` contains `on payment_allocations (B6-EXIT PAY-5 / FIN-11), so the`; if so record Already Applied when its Git blob is c4b1b3e8549fd8820ae39eeda99c3e9edcb1dda7, and otherwise stop and report. Otherwise make exactly these 2 edits (the invoice transition attribution), each matched once, and change nothing else:

   a) replace the lines
   ```text
     -- into `issued`; `app.record_payment` performs every move into `partially_paid`/`paid` and DERIVES
     -- which one from the amount rather than choosing it.
   ```
   with
   ```text
     -- into `issued`; every move into `partially_paid`/`paid` is DERIVED from the allocated amount by
     -- `app.derive_invoice_payment_status` on payment_allocations (B6-EXIT PAY-5 / FIN-11), so the
     -- table door and `app.record_payment` settle the invoice through one producer.
   ```

   b) replace the lines
   ```text
     ('invoices','issued',        'partially_paid','app.record_payment'),
     ('invoices','issued',        'paid',          'app.record_payment'),
     ('invoices','partially_paid','paid',          'app.record_payment'),
     ('invoices','overdue',       'partially_paid','app.record_payment'),
     ('invoices','overdue',       'paid',          'app.record_payment'),
   ```
   with
   ```text
     ('invoices','issued',        'partially_paid','app.derive_invoice_payment_status'),
     ('invoices','issued',        'paid',          'app.derive_invoice_payment_status'),
     ('invoices','partially_paid','paid',          'app.derive_invoice_payment_status'),
     ('invoices','overdue',       'partially_paid','app.derive_invoice_payment_status'),
     ('invoices','overdue',       'paid',          'app.derive_invoice_payment_status'),
   ```

   The resulting file's Git blob is c4b1b3e8549fd8820ae39eeda99c3e9edcb1dda7.

3. Check whether `supabase/tests/96_invoice_void_and_eta_boundary_test.sql` contains `Since SPEC-326 an allocation derives partially_paid itself (PAY-5)`; if so record Already Applied when its Git blob is 72e2107b07178f352a634606fcbd7173bdf39a23, and otherwise stop and report. Otherwise make exactly these 3 edits (the void fixture with the settlement trigger held off), each matched once, and change nothing else:

   a) immediately after the line
   ```text
   -- the platform path, so the fixtures themselves are not what is under test.
   ```
   insert
   ```text
   -- Since SPEC-326 an allocation derives partially_paid itself (PAY-5), which the transition table alone
   -- would then refuse to void. f3 keeps the state this test exists for -- money allocated while the
   -- status word still says `issued`, as every door allocation before SPEC-326 left it -- by writing its
   -- allocation with only the settlement trigger off, so the void guard, not the status, is what refuses.
   ```

   b) immediately after the line
   ```text
     ('96000000-0000-0000-0000-0000000000e1','96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000d1','customer_payment','bank_transfer','EGP', 400, now());
   ```
   insert
   ```text
   alter table public.payment_allocations disable trigger payment_allocations_settle_invoice;
   ```

   c) immediately after the line
   ```text
     ('96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000e1','96000000-0000-0000-0000-0000000000f3', 400, 'EGP');
   ```
   insert
   ```text
   -- Its two deferred ceilings run now (the table cannot be altered with them pending) and defer again.
   set constraints payment_allocations_within_invoice_total, payment_allocations_within_payment_amount immediate;
   alter table public.payment_allocations enable trigger payment_allocations_settle_invoice;
   set constraints payment_allocations_within_invoice_total, payment_allocations_within_payment_amount deferred;
   ```

   The resulting file's Git blob is 72e2107b07178f352a634606fcbd7173bdf39a23.

4. Check whether `supabase/tests/140_payment_is_recorded_on_every_door_test.sql` contains `which its allocation settled (PAY-5)`; if so record Already Applied when its Git blob is d132e48e82f068588148df658d9eeedc4d2b15d7, and otherwise stop and report. Otherwise make exactly this one edit (the settled invoice status), each matched once, and change nothing else:

   a) replace the lines
   ```text
     '1/14000000-0000-0000-0000-000000000011/payment_recorded/-/{"amount": 5000.0000, "invoice_id": "' || (select v from s140 where k='inv2') || '", "currency_code": "EGP", "invoice_new_status": "issued"}',
     'PAY-3: a door payment allocated to an invoice in the same transaction records ONE payment_recorded naming its writer and that invoice -- before the PAY-3 migration it had zero events');
   ```
   with
   ```text
     '1/14000000-0000-0000-0000-000000000011/payment_recorded/-/{"amount": 5000.0000, "invoice_id": "' || (select v from s140 where k='inv2') || '", "currency_code": "EGP", "invoice_new_status": "paid"}',
     'PAY-3: a door payment allocated to an invoice in the same transaction records ONE payment_recorded naming its writer and that invoice, which its allocation settled (PAY-5) -- before the PAY-3 migration it had zero events');
   ```

   The resulting file's Git blob is d132e48e82f068588148df658d9eeedc4d2b15d7.

5. Check whether `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql` contains `Since SPEC-326 a door allocation derives the invoice's partially_paid or paid status itself (PAY-5, Test 184)`; if so record Already Applied when its Git blob is f85481f019a59ea756ba93a056140cc3576fc423, and otherwise stop and report. Otherwise make exactly these 12 edits (the door allocation scenario), each matched once, and change nothing else:

   a) replace the line
   ```text
   --   A door allocation still leaves the invoice status where it was (PAY-5, not this contract's).
   ```
   with
   ```text
   --   Since SPEC-326 a door allocation derives the invoice's partially_paid or paid status itself (PAY-5, Test 184),
   --   so every correction below happens where the invoice's recorded status still allows it.
   ```

   b) replace the line
   ```text
               '15500000-0000-0000-0000-0000000000e1',8,'USD','15500000-0000-0000-0000-00000000ee01');
   ```
   with
   ```text
               '15500000-0000-0000-0000-0000000000e1',4,'USD','15500000-0000-0000-0000-00000000ee01');
   ```

   c) replace the line
   ```text
     '30. FA-2 permits a cross-currency allocation with its rate: 8 USD to C1''s EGP invoice');
   ```
   with
   ```text
     '30. FA-2 permits a cross-currency allocation with its rate: 4 USD to C1''s EGP invoice');
   ```

   d) replace the lines
   ```text
     '8.0000/400.0000', '31. the invoice-currency amount is derived from the rate: 8 USD at 50 is 400 EGP');
   select throws_ok($$select app.record_payment('15500000-0000-0000-0000-0000000000e1',0.0001,'cash')$$,
     'P0001','payment 0.0001 exceeds invoice outstanding 0.0000 (total 1000.0000, already allocated 1000.0000)',
     '32. app.record_payment reads the invoice in its own currency: 600 EGP + 8 USD fill it (face value would leave 392)');
   ```
   with
   ```text
     '4.0000/200.0000', '31. the invoice-currency amount is derived from the rate: 4 USD at 50 is 200 EGP');
   select throws_ok($$select app.record_payment('15500000-0000-0000-0000-0000000000e1',200.0001,'cash')$$,
     'P0001','payment 200.0001 exceeds invoice outstanding 200.0000 (total 1000.0000, already allocated 800.0000)',
     '32. app.record_payment reads the invoice in its own currency: 600 EGP + 4 USD leave 200 (face value would leave 396)');
   ```

   e) replace the line
   ```text
       update public.payment_allocations set allocated_amount=0 where id='15500000-0000-0000-0000-00000000aa02';
   ```
   with
   ```text
       update public.payment_allocations set allocated_amount=2 where id='15500000-0000-0000-0000-00000000aa02';
   ```

   f) replace the line
   ```text
     '35. RECORD_PAYMENT still corrects an amount');
   ```
   with
   ```text
     '35. RECORD_PAYMENT still corrects an amount, while the invoice it part-paid stays part-paid (4 -> 2 USD)');
   ```

   g) replace the line
   ```text
     '0.0000/0.0000', '36. ...and the invoice-currency amount follows it');
   ```
   with
   ```text
     '2.0000/100.0000', '36. ...and the invoice-currency amount follows it');
   ```

   h) replace the line
   ```text
     '37. the correction a misplaced allocation needs, where no recorded status rests on it: zero it, allocate again');
   ```
   with
   ```text
     '37. the correction a misplaced allocation needs, while the invoice stays part-paid on what remains: zero it, allocate again');
   ```

   i) replace the line
   ```text
     '0.0000/600.0000', '38. ...moving C1''s 600 from IA to IC, both rows kept as history');
   ```
   with
   ```text
     '100.0000/600.0000', '38. ...moving C1''s 600 from IA to IC, both rows kept as history');
   ```

   j) replace the line
   ```text
     'payment_allocation_created:info:->8.0000:->400.0000:true | payment_allocation_amount_changed:warning:8.0000>0.0000:400.0000>0.0000:true',
   ```
   with
   ```text
     'payment_allocation_created:info:->4.0000:->200.0000:true | payment_allocation_amount_changed:warning:4.0000>2.0000:200.0000>100.0000:true',
   ```

   k) replace the lines
   ```text
     'PA155-IA:issued:0.0000 | PA155-IB:paid:1000.0000 | PA155-ID:partially_paid:100.0000',
     '60. the floor refuses and moves no status: the door''s IA stays issued (PAY-5), IB paid, ID partially_paid');
   ```
   with
   ```text
     'PA155-IA:partially_paid:100.0000 | PA155-IB:paid:1000.0000 | PA155-ID:partially_paid:100.0000',
     '60. the floor refuses and moves no status: the door''s IA stays part-paid on what remains (PAY-5), IB paid, ID partially_paid');
   ```

   l) replace the line
   ```text
     '62. a session-less correction on an issued invoice passes every check');
   ```
   with
   ```text
     '62. a session-less correction on a part-paid invoice that stays part-paid passes every check');
   ```

   The resulting file's Git blob is f85481f019a59ea756ba93a056140cc3576fc423.

6. Check whether `supabase/tests/184_refund_conversation_and_settlement_are_recorded_on_every_door_test.sql` contains `select plan(36);`; if so record Already Applied when its Git blob is be2fc2e45076505879939d0a8accc0fa0f28656b, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the three-unit regression test), and change nothing else:

   ```text
   -- B6-EXIT bundle B: RFD-3 a refund's life, CHAT-2 a conversation's life and PAY-5 / FIN-11 an
   -- invoice's settlement are produced by the table, so the table door and the RPC door record the same
   -- acts once each. Each table-door case below recorded nothing (or settled nothing) at 7c5975a.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(36);

   insert into auth.users (id, email) values
       ('18400000-0000-0000-0000-0000000000a1', 'owner@door184.test'),
       ('18400000-0000-0000-0000-0000000000a2', 'finance@door184.test'),
       ('18400000-0000-0000-0000-0000000000a3', 'emp@door184.test');
   insert into public.tenants (id, name, slug, status)
   values ('18400000-0000-0000-0000-000000000001', 'Door 184 Travel', 'door-184', 'active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '18400000-0000-0000-0000-000000000001', id, 'active'
   from public.subscription_plans where plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug)
   values ('18400000-0000-0000-0000-00000000000a', '18400000-0000-0000-0000-000000000001', 'HQ', 'door-184-hq');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
   values ('18400000-0000-0000-0000-00000000000b', '18400000-0000-0000-0000-000000000001',
           '18400000-0000-0000-0000-00000000000a', 'sales', 'Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
       ('18400000-0000-0000-0000-000000000011', '18400000-0000-0000-0000-000000000001', 'Owner', 'owner@door184.test', true, '18400000-0000-0000-0000-0000000000a1'),
       ('18400000-0000-0000-0000-000000000012', '18400000-0000-0000-0000-000000000001', 'Finance', 'finance@door184.test', true, '18400000-0000-0000-0000-0000000000a2'),
       ('18400000-0000-0000-0000-000000000013', '18400000-0000-0000-0000-000000000001', 'Emp', 'emp@door184.test', true, '18400000-0000-0000-0000-0000000000a3');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
   select tenant_id, id, '18400000-0000-0000-0000-00000000000a', '18400000-0000-0000-0000-00000000000b', true
   from public.users where tenant_id = '18400000-0000-0000-0000-000000000001';
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '18400000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
   from (values ('18400000-0000-0000-0000-000000000011'::uuid, 'owner'),
                ('18400000-0000-0000-0000-000000000012'::uuid, 'finance_manager'),
                ('18400000-0000-0000-0000-000000000013'::uuid, 'employee')) v(u, rc)
   join public.roles r on r.code = v.rc;
   insert into public.customers (id, tenant_id, customer_type_code, full_name)
   values ('18400000-0000-0000-0000-0000000000d1', '18400000-0000-0000-0000-000000000001', 'person', 'Buyer');
   insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id)
   values ('18400000-0000-0000-0000-0000000000b1', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-00000000000a',
           '18400000-0000-0000-0000-00000000000b', '18400000-0000-0000-0000-0000000000d1', 'draft', 'Trip', 'BR-DOOR184-1',
           '18400000-0000-0000-0000-000000000013');
   -- Four issued invoices of 5000 (session-less fixture, test 111 pattern): e1 RPC, e2 one full door
   -- allocation, e3 two partial door allocations, e4 an allocation lowered then raised.
   insert into public.invoices (id, tenant_id, customer_id, booking_id, invoice_number, invoice_date, currency_code, total_amount, status_code)
   select ('18400000-0000-0000-0000-0000000000e' || n)::uuid, '18400000-0000-0000-0000-000000000001',
          '18400000-0000-0000-0000-0000000000d1', '18400000-0000-0000-0000-0000000000b1', 'INV-184-' || n,
          current_date, 'EGP', 5000, 'issued'
   from generate_series(1, 4) n;
   insert into public.conversations (id, tenant_id, customer_id, channel_code, conversation_status_code, owner_user_id,
       owner_branch_id, owner_department_id, current_branch_id, current_department_id, external_conversation_id)
   select ('18400000-0000-0000-0000-0000000000c' || n)::uuid, '18400000-0000-0000-0000-000000000001',
          '18400000-0000-0000-0000-0000000000d1', 'whatsapp', 'open', '18400000-0000-0000-0000-000000000013',
          '18400000-0000-0000-0000-00000000000a', '18400000-0000-0000-0000-00000000000b',
          '18400000-0000-0000-0000-00000000000a', '18400000-0000-0000-0000-00000000000b', 'door-184-cv-' || n
   from generate_series(1, 2) n;
   create temporary table r (k text primary key, v uuid);
   grant all on r to authenticated;

   -- ===== RFD-3: finance at aal2, the table door beside the RPC door.
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"18400000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select lives_ok($$insert into public.refunds (id, tenant_id, payment_direction_code, customer_id, booking_id, refund_reason_code, currency_code, amount, refund_status_code)
                     values ('18400000-0000-0000-0000-0000000000f1', '18400000-0000-0000-0000-000000000001', 'customer_refund',
                             '18400000-0000-0000-0000-0000000000d1', '18400000-0000-0000-0000-0000000000b1', 'customer_cancelled', 'EGP', 100, 'requested')$$,
                   'RFD-3: a refund is requested at the table door');
   select lives_ok($$update public.refunds set refund_status_code = 'approved' where id = '18400000-0000-0000-0000-0000000000f1'$$,
                   'RFD-3: the table door approves it');
   select lives_ok($$update public.refunds set refund_status_code = 'completed' where id = '18400000-0000-0000-0000-0000000000f1'$$,
                   'RFD-3: the table door completes it');
   insert into r values ('rf_rpc', app.record_refund('18400000-0000-0000-0000-0000000000d1', 100, 'EGP', 'customer_cancelled',
                                                     '18400000-0000-0000-0000-0000000000b1', null));
   select app.advance_refund((select v from r where k = 'rf_rpc'), 'approved', 'ok');
   select app.advance_refund((select v from r where k = 'rf_rpc'), 'completed', 'paid out');
   reset role;

   select results_eq(
       $$select event_type_code, severity_code, previous_state, new_state, reason, actor_user_id, payload->>'amount'
         from public.events where entity_id = '18400000-0000-0000-0000-0000000000f1' order by seq$$,
       $$values ('refund_requested', 'info', null::text, 'requested', 'customer_cancelled', '18400000-0000-0000-0000-000000000012'::uuid, '100.0000'),
                ('refund_approved', 'info', 'requested', 'approved', null, '18400000-0000-0000-0000-000000000012'::uuid, '100.0000'),
                ('refund_completed', 'warning', 'approved', 'completed', null, '18400000-0000-0000-0000-000000000012'::uuid, '100.0000')$$,
       'RFD-3: the table door records the request, the approval and the completion once each, under the caller');
   select results_eq(
       $$select event_type_code, severity_code, previous_state, new_state, reason
         from public.events where entity_id = (select v from r where k = 'rf_rpc') order by seq$$,
       $$values ('refund_requested', 'info', null::text, 'requested', 'customer_cancelled'),
                ('refund_approved', 'info', 'requested', 'approved', 'ok'),
                ('refund_completed', 'warning', 'approved', 'completed', 'paid out')$$,
       'RFD-3: the RPC door records the same three acts once each, with its reasons');
   select is((select count(*)::int from public.refunds
              where tenant_id = '18400000-0000-0000-0000-000000000001' and completed_at is not null), 2,
             'RFD-3: completed_at is server-stamped on both doors');

   -- ===== CHAT-2: the employee at the table door (c1) and the RPC door (c2).
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"18400000-0000-0000-0000-0000000000a3"}', true);
   select lives_ok($$update public.conversations set conversation_status_code = 'assigned' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                   'CHAT-2: the table door assigns');
   select lives_ok($$update public.conversations set conversation_status_code = 'closed', closed_at = '2001-01-01' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                   'CHAT-2: the table door closes, offering a forged closed_at');
   select ok((select closed_at > now() - interval '1 minute' from public.conversations where id = '18400000-0000-0000-0000-0000000000c1'),
             'CHAT-2: closing stamps closed_at from the server, not the forged value');
   update public.conversations set closed_at = '2001-01-01' where id = '18400000-0000-0000-0000-0000000000c1';
   select ok((select closed_at > now() - interval '1 minute' from public.conversations where id = '18400000-0000-0000-0000-0000000000c1'),
             'CHAT-2: a later update cannot rewrite closed_at');
   select throws_ok($$update public.conversations set conversation_status_code = 'open' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                    '23514', 'a closed conversation is reopened with a reason (canon 26, 27); use app.advance_conversation with p_reason',
                    'CHAT-2: the table door cannot reopen without a reason');
   select lives_ok($$select set_config('app.transition_reason', 'customer replied', true);
                     update public.conversations set conversation_status_code = 'open' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                   'CHAT-2: a reopen carrying a reason is accepted');
   select is((select closed_at from public.conversations where id = '18400000-0000-0000-0000-0000000000c1'), null,
             'CHAT-2: reopening clears closed_at');
   select lives_ok($$update public.conversations set conversation_status_code = 'assigned' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                   'CHAT-2: the table door reassigns after the reopen');
   select throws_ok($$update public.conversations set conversation_status_code = 'escalated' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                    '42501', 'permission denied: ESCALATE_CONVERSATION',
                    'CHAT-2: the employee still cannot escalate at the table');
   select lives_ok($$select app.advance_conversation('18400000-0000-0000-0000-0000000000c2', 'assigned', 'picked');
                     select app.advance_conversation('18400000-0000-0000-0000-0000000000c2', 'closed', 'done')$$,
                   'CHAT-2: the RPC door assigns and closes');
   select throws_ok($$select app.advance_conversation('18400000-0000-0000-0000-0000000000c2', 'open', null)$$,
                    '23514', 'a closed conversation is reopened with a reason (canon 26, 27); use app.advance_conversation with p_reason',
                    'CHAT-2: the RPC door cannot reopen without a reason either');
   select lives_ok($$select app.advance_conversation('18400000-0000-0000-0000-0000000000c2', 'open', 'customer replied')$$,
                   'CHAT-2: the RPC door reopens with a reason');
   select set_config('request.jwt.claims', '{"sub":"18400000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select lives_ok($$update public.conversations set conversation_status_code = 'escalated' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                   'CHAT-2: the owner escalates at the table');
   reset role;

   select results_eq(
       $$select event_type_code, severity_code, previous_state, new_state, reason, actor_user_id
         from public.events where entity_id = '18400000-0000-0000-0000-0000000000c1' and event_type_code <> 'conversation_started' order by seq$$,
       $$values ('conversation_assigned', 'info', 'open', 'assigned', null::text, '18400000-0000-0000-0000-000000000013'::uuid),
                ('conversation_closed', 'info', 'assigned', 'closed', null, '18400000-0000-0000-0000-000000000013'::uuid),
                ('conversation_reopened', 'warning', 'closed', 'open', 'customer replied', '18400000-0000-0000-0000-000000000013'::uuid),
                ('conversation_assigned', 'info', 'open', 'assigned', null, '18400000-0000-0000-0000-000000000013'::uuid),
                ('conversation_escalated', 'warning', 'assigned', 'escalated', null, '18400000-0000-0000-0000-000000000011'::uuid)$$,
       'CHAT-2: every table-door move is recorded once, reopen and escalation as warnings, the reason consumed by its own move');
   select results_eq(
       $$select event_type_code, severity_code, reason
         from public.events where entity_id = '18400000-0000-0000-0000-0000000000c2' and event_type_code <> 'conversation_started' order by seq$$,
       $$values ('conversation_assigned', 'info', 'picked'), ('conversation_closed', 'info', 'done'),
                ('conversation_reopened', 'warning', 'customer replied')$$,
       'CHAT-2: the RPC door records the same moves once each, with its reasons');

   -- ===== PAY-5 / FIN-11: the owner at aal2.
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"18400000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   insert into r values ('pay_rpc', app.record_payment('18400000-0000-0000-0000-0000000000e1', 5000, 'cash', now(), 'R-184'));
   select lives_ok($$insert into public.payments (id, tenant_id, payment_direction_code, customer_id, currency_code, payment_method_code, amount, paid_at) values
                       ('18400000-0000-0000-0000-000000000133', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 1000, now());
                     insert into public.payment_allocations (id, tenant_id, payment_id, invoice_id, allocated_amount, currency_code) values
                       ('18400000-0000-0000-0000-000000000233', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000133', '18400000-0000-0000-0000-0000000000e4', 0, 'EGP')$$,
                   'PAY-5: a zero allocation is written at the table door');
   select is((select status_code from public.invoices where id = '18400000-0000-0000-0000-0000000000e4'), 'issued',
             'PAY-5: a zero allocation settles nothing, so the invoice stays issued');
   select lives_ok($$insert into public.payments (id, tenant_id, payment_direction_code, customer_id, currency_code, payment_method_code, amount, paid_at) values
                       ('18400000-0000-0000-0000-000000000102', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 5000, now()),
                       ('18400000-0000-0000-0000-000000000131', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 2000, now()),
                       ('18400000-0000-0000-0000-000000000132', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 3000, now()),
                       ('18400000-0000-0000-0000-000000000104', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 5000, now());
                     insert into public.payment_allocations (id, tenant_id, payment_id, invoice_id, allocated_amount, currency_code) values
                       ('18400000-0000-0000-0000-000000000202', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000102', '18400000-0000-0000-0000-0000000000e2', 5000, 'EGP'),
                       ('18400000-0000-0000-0000-000000000231', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000131', '18400000-0000-0000-0000-0000000000e3', 2000, 'EGP');
                     insert into public.payment_allocations (id, tenant_id, payment_id, invoice_id, allocated_amount, currency_code) values
                       ('18400000-0000-0000-0000-000000000232', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000132', '18400000-0000-0000-0000-0000000000e3', 3000, 'EGP'),
                       ('18400000-0000-0000-0000-000000000204', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000104', '18400000-0000-0000-0000-0000000000e4', 3000, 'EGP')$$,
                   'PAY-5: payments and allocations are written at the table door');
   select is((select status_code from public.invoices where id = '18400000-0000-0000-0000-0000000000e4'), 'partially_paid',
             'PAY-5: a partial door allocation settles the invoice partially_paid');
   select lives_ok($$update public.payment_allocations set allocated_amount = 1000 where id = '18400000-0000-0000-0000-000000000204'$$,
                   'PAY-5: a door allocation is lowered');
   select is((select status_code from public.invoices where id = '18400000-0000-0000-0000-0000000000e4'), 'partially_paid',
             'PAY-5: a lowered allocation never walks the settlement back');
   select lives_ok($$update public.payment_allocations set allocated_amount = 5000 where id = '18400000-0000-0000-0000-000000000204'$$,
                   'PAY-5: the door allocation is raised to the full total');
   set constraints payments_emit_recorded immediate;
   reset role;

   select results_eq(
       $$select invoice_number, status_code from public.invoices where tenant_id = '18400000-0000-0000-0000-000000000001' order by 1$$,
       $$values ('INV-184-1', 'paid'), ('INV-184-2', 'paid'), ('INV-184-3', 'paid'), ('INV-184-4', 'paid')$$,
       'PAY-5: every invoice covered by its allocations is paid, on either door');
   select results_eq(
       $$select i.invoice_number, e.event_type_code, e.previous_state, e.new_state, e.actor_user_id, (e.payload->>'allocated_total')::numeric
         from public.events e join public.invoices i on i.id = e.entity_id
         where i.tenant_id = '18400000-0000-0000-0000-000000000001' order by i.invoice_number, e.seq$$,
       $$values ('INV-184-1', 'invoice_paid', 'issued', 'paid', '18400000-0000-0000-0000-000000000011'::uuid, 5000::numeric),
                ('INV-184-2', 'invoice_paid', 'issued', 'paid', '18400000-0000-0000-0000-000000000011'::uuid, 5000),
                ('INV-184-3', 'invoice_partially_paid', 'issued', 'partially_paid', '18400000-0000-0000-0000-000000000011'::uuid, 2000),
                ('INV-184-3', 'invoice_paid', 'partially_paid', 'paid', '18400000-0000-0000-0000-000000000011'::uuid, 5000),
                ('INV-184-4', 'invoice_partially_paid', 'issued', 'partially_paid', '18400000-0000-0000-0000-000000000011'::uuid, 3000),
                ('INV-184-4', 'invoice_paid', 'partially_paid', 'paid', '18400000-0000-0000-0000-000000000011'::uuid, 5000)$$,
       'PAY-5: each settlement is recorded once on either door, and a lowering records none');
   select is((select payload->>'payment_id' from public.events
              where entity_id = '18400000-0000-0000-0000-0000000000e2' and event_type_code = 'invoice_paid'),
             '18400000-0000-0000-0000-000000000102', 'PAY-5: the settlement names the payment that caused it');
   select ok((select max(seq) filter (where event_type_code = 'payment_allocation_created')
                   < max(seq) filter (where event_type_code = 'invoice_paid')
              from public.events where entity_id in ('18400000-0000-0000-0000-000000000202', '18400000-0000-0000-0000-0000000000e2')),
             'PAY-5: the allocation is recorded before the settlement it causes');
   select results_eq(
       $$select entity_id, payload->>'invoice_new_status' from public.events
         where event_type_code = 'payment_recorded' and entity_id in ((select v from r where k = 'pay_rpc'), '18400000-0000-0000-0000-000000000102')
         order by payload->>'invoice_id'$$,
       $$values ((select v from r where k = 'pay_rpc'), 'paid'), ('18400000-0000-0000-0000-000000000102'::uuid, 'paid')$$,
       'PAY-5: payment_recorded reports the settled invoice status on both doors');

   -- ===== Shape: invoker producers on the tables, and no RPC emits what its table now produces.
   select is((select count(*)::int from pg_proc where pronamespace = 'app'::regnamespace and not prosecdef
              and proname in ('emit_refund_requested', 'emit_refund_transition', 'guard_conversation_transition',
                              'emit_conversation_transition', 'derive_invoice_payment_status')), 5,
             'the guard and the four producers are SECURITY INVOKER');
   select results_eq(
       $$select tgname::text collate "default", (tgtype & 2) = 2 from pg_trigger
         where tgname in ('refunds_emit_requested', 'refunds_emit_transition', 'conversations_guard_transition',
                          'conversations_emit_transition', 'payment_allocations_settle_invoice') order by 1$$,
       $$values ('conversations_emit_transition', false), ('conversations_guard_transition', true),
                ('payment_allocations_settle_invoice', false), ('refunds_emit_requested', false), ('refunds_emit_transition', false)$$,
       'the conversation guard fires BEFORE, the four producers AFTER');
   select is((select count(*)::int from pg_proc where pronamespace = 'app'::regnamespace
              and proname in ('record_refund', 'advance_refund', 'advance_conversation', 'record_payment')
              and pg_get_functiondef(oid) ~ 'record_event'), 0,
             'no restated RPC records the events its table now produces');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is be2fc2e45076505879939d0a8accc0fa0f28656b.

7. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Recorded exception, 2026-11-21, CRM exit bundle B`; if so record Already Applied when its Git blob is 365802be3af139d61dea8b62c548cdd7d6809989, and otherwise stop and report. Otherwise make exactly these 2 edits (the current owner-authorized grouped selection), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-21 (CRM exit bundle A, SPEC-324. The Action registry records the owner's grouped selection of the ARCH-2, ENTRY-1 and STEPUP-1 members that share the table-door write boundary.)
   ```
   with
   ```text
   Last updated: 2026-11-21 (CRM exit bundle B, SPEC-326. The Action registry records the owner's grouped selection of RFD-3, CHAT-2 and the PAY-5/FIN-11 unit, whose events and invoice settlement belong to each table's own producer on every door.)

   Previously: 2026-11-21 (CRM exit bundle A, SPEC-324. The Action registry records the owner's grouped selection of the ARCH-2, ENTRY-1 and STEPUP-1 members that share the table-door write boundary.)
   ```

   b) immediately after the lines
   ```text
   **Recorded exception, 2026-11-20, CRM exit bundle A.** After CRM SPEC-322 Remote Certify at `73b02a1ac820683846a7566c88d5704bf3171884`, the owner's 2026-11-20 directive authorized grouping items that share evidence, tests and a release boundary while keeping per-item acceptance. SPEC-324 selects the leads, quotations, booking items and invoices members of ARCH-2, the booking-item member of ENTRY-1 and the campaign_daily_metrics and exchange_rate_adjustments members of STEPUP-1, which share the table-door write boundary. Test 183 proves each selected effect on one isolated schema. Campaign entry, CAMP-2 and JE-2 keep their own triggers. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-21, CRM exit bundle B.** After CRM SPEC-325 at `7c5975a09b9351308a3178f1c1579798747fbe51`, the owner's 2026-11-20 directive authorized grouping items that share evidence, tests and a release boundary while keeping per-item acceptance. SPEC-326 selects RFD-3, CHAT-2 and the PAY-5/FIN-11 unit, which share one boundary: a refund transition, a conversation transition and an allocation's invoice settlement are recorded by the table's own producer on every door, and the RPCs stop emitting them a second time. Test 184 proves each selected effect on one isolated schema. PAY-9, PAY-4, JE-2, CAMP-4, BRANCH-2 and PAX-8 keep their own triggers. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```

   The resulting file's Git blob is 365802be3af139d61dea8b62c548cdd7d6809989.

8. **Regenerate the exact API contract.** After the Original carries Steps 1–7 and the local CRM stack is rebuilt with the exact new migration, run the repository API generator from that state. The resulting Git blob must be 62af74be28b058e41b6b6bcfbe43457f15acfd33. Accept only the `record_payment` row change. The script and all other rows stay pinned. In a stack-free isolated rehearsal this step is deferred to Original DATABASE readiness.

9. **Establish readiness and the exact Primary preflight.** Run the native DATABASE readiness, including full SQL tests, HTTP and smoke, API generation and Git blob comparison. Verify 276 migrations, latest `20261121110000`, fingerprint `3d6fe3908078c02f611c70b4eb070623`, 184 files and 3445 assertions. Compare the catalog against the isolated evidence. Verify the five new trigger bindings, the five new function definitions, the four replaced RPC definitions and the expected function and trigger differences with all other parity signatures stable. Read live Primary project `vrvtsxexkiiiivlkdxzp`: require 275 migrations, latest `20261121100000`, fingerprint `5213d0d035d53e635a839f0ce9bb7693`, absent target and certified Primary parity. Preserve scoped baseline row counts, fresh lock evidence and the native exact-DDL and recovery prerequisites. Verify the tracked file Git blob, SHA-256 and the MD5 received by the intended connected Primary route.

   While these measurements agree, update only the manifest Live state on the uncommitted tree to the following:

   ```text
   Live state: SPEC-326 pre-deploy verification. **Repository and local stack at 276 migrations** (latest `20261121110000`), ledger `3d6fe3908078c02f611c70b4eb070623`. **Platinum Primary `vrvtsxexkiiiivlkdxzp` verified separately at 275 migrations**, with the target absent. Structural parity awaits Gate 2. **80 client RPCs**. Suite **184 files / 3445 assertions**.
   ```

   Require the unchanged consistency guard to report only the missing exact Primary row under RECOVER-1. In the isolated Sandbox, use native Approve and literal replay and check only this expected refusal. The real implementation commit and DONE belong after Primary readback, parity and record updates.

10. **Apply the exact migration once after Gate 2 with separately recorded current authority.** Use the authorized CRM Platinum Primary path for `vrvtsxexkiiiivlkdxzp`. Reconfirm project, baseline, raw file MD5, active Draft, lock window and recovery readiness immediately before the write. Afterward verify one expected ledger row, the five trigger bindings, the nine function definitions, catalog fingerprints and scoped row counts. If the connector allocates a temporary ledger version, reconcile only that exact row in a guarded transaction once the stored migration statement digest and intended version absence are proven. On error or ambiguity preserve the actual database state and follow the native RECOVER-1 decision; no blind retry. A reversal requires a separately authorized corrective migration restoring the prior function and trigger definitions.

11. **Record verified closure and resolve RECOVER-1.** From actual live Primary and local evidence, record ordered ledger and all ten parity surfaces, replace the interim Live state with the literal native fields `full-function-surface hash` and `structural-surface hash` carrying the matched hashes, retain suite count and regenerate discovery. In the gap register, with readback evidence, record RFD-3, CHAT-2, PAY-5 and FIN-11 fixed by SPEC-326 with their previous status kept as history, note on FIN-9 that FIN-11's half is answered while JE-2 and DC-11 keep journal events, and keep PAY-9, PAY-4, JE-2 and LI-3 at their recorded status. In the action registry of `reports/master/MASTER_EXECUTION_PLAN.md`, replace the one line that begins `| PAY-5, FIN-11 |`, the one that begins `| RFD-3 |`, the one that begins `| CHAT-2, CAMP-4, BRANCH-2, PAX-8 |` and the `conversations`, `payment_allocations` and `refunds` surface rows with these lines, in the same order. No other plan line changes after Step 7. The resulting file's Git blob is b766c82547d6c870d3cc2ecf16a51e387668a7d4.

   ```text
   | PAY-5, FIN-11 | VERIFIED DEFECT | engineering | `ENABLE-INVOICING` | — | SPEC-326 and Test 184 close the unit on Platinum Primary: `app.derive_invoice_payment_status` on payment_allocations derives the invoice's status and emits its event on both doors, and `app.record_payment` no longer derives it. A zero allocation settles nothing and no settlement walks back. |
   | RFD-3 | VERIFIED DEFECT | engineering | `ENABLE-REFUNDS` | — | SPEC-326 and Test 184 close it on Platinum Primary: the refunds table records each refund transition once on both doors, with the RPC reason carried through `app.transition_reason`. The RPC severities are kept. |
   | CHAT-2, CAMP-4, BRANCH-2, PAX-8 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Low. Audit and timeline evidence is missing at a table door, and each finding's measured bound is that nothing reads it. At the gate the bound is re-measured: if it holds, the item becomes an explicit accepted residual; otherwise it is repaired. Never deferred silently. SPEC-326 and Test 184 close CHAT-2 on Platinum Primary: the conversation guard stamps `closed_at` and requires a reopen reason, and the table records each transition once on both doors. |
   | `conversations` | SURFACE | engineering | `B6-EXIT` | CHAT-2 and the explicit surface boundary | SPEC-220 and test 125 close creator attribution and initial state. SPEC-326 and Test 184 close CHAT-2's transition time, reopen reason and event gap on Platinum Primary. |
   | `payment_allocations` | SURFACE | engineering | `B6-EXIT` | FIN-11/PAY-5 and PAY-9 | SPEC-264 and test 155 cover allocation authority, audit and concurrency. SPEC-326 and Test 184 close the PAY-5/FIN-11 invoice status and event unit on Platinum Primary. PAY-9 remains the booking-balance unit at first booking, and the PAY-11 residual remains an owner policy question. |
   | `refunds` | SURFACE | engineering | `B6-EXIT` | RFD-3 and exit lifecycle evidence | SPEC-217 and test 123 close RFD-1/RFD-2 and refund entry. SPEC-326 and Test 184 close RFD-3 on Platinum Primary with the RPC reason preserved and one emission. The refund enablement gate is preserved. |
   ```

   In the disposition, mark conversations, payment_allocations and refunds AUDITED with the SPEC-326 proof and update the status counts by those three rows, with all other statuses intact. Date both report headers with a new `Last updated` line and keep the previous one as `Previously`. The native registry must report only the expected B6-EXIT reduction: RFD-3, CHAT-2, PAY-5 and FIN-11 and the conversations, payment_allocations and refunds surfaces move to COMPLETED, while payments and journal_entry_lines stay due, without changing exit criteria or unrelated triggers. Require repository consistency and parity evidence PASS before Runtime Checkpoint DONE and the implementation commit.

12. **Verify and release through the native lifecycle.** Run timed and watched Finish, independent Review, Complete and bind with exact evidence. Set `Last Completed: **SPEC-326: A refund, a conversation and a settlement are recorded on every door.**`, clear the active pointer, regenerate discovery and bind the exact candidate. Publish, hosted preflight, Promote, main checks and Remote Certify use separate native exact-candidate records and the current delegated authority.

## Acceptance Criteria

- [ ] Exact migration moves each effect to its table's producer and strips the RPC duplicates. `check: blob supabase/migrations/20261121110000_a_refund_a_conversation_and_a_settlement_are_recorded_on_every_door.sql 52bb1f1577f4346b439a1c33c47b233de5d4935d`
- [ ] Test 54 attributes invoice transitions to the allocation producer. `check: blob supabase/tests/54_transition_permission_parity_test.sql c4b1b3e8549fd8820ae39eeda99c3e9edcb1dda7`
- [ ] Test 96 still proves the void guard on an issued invoice holding money. `check: blob supabase/tests/96_invoice_void_and_eta_boundary_test.sql 72e2107b07178f352a634606fcbd7173bdf39a23`
- [ ] Test 140 records the derived settled status. `check: blob supabase/tests/140_payment_is_recorded_on_every_door_test.sql d132e48e82f068588148df658d9eeedc4d2b15d7`
- [ ] Test 155 keeps the misplaced-allocation correction on a part-paid invoice. `check: blob supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql f85481f019a59ea756ba93a056140cc3576fc423`
- [ ] Test 184 proves every selected effect, its authorized path and its exemption. `check: blob supabase/tests/184_refund_conversation_and_settlement_are_recorded_on_every_door_test.sql be2fc2e45076505879939d0a8accc0fa0f28656b`
- [ ] The recorded grouped selection and the per-item registry closure are exact. `check: blob reports/master/MASTER_EXECUTION_PLAN.md b766c82547d6c870d3cc2ecf16a51e387668a7d4`
- [ ] The generated API reports only the expected `record_payment` row change. `check: blob reports/master/MASTER_API_CONTRACT.md 62af74be28b058e41b6b6bcfbe43457f15acfd33`
- [ ] Native selection stays intact. `check: same scripts/batch6_select_target.ps1 @7c5975a09b9351308a3178f1c1579798747fbe51`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **184 files / 3445 assertions**"`
- [ ] Verified Primary and local ledger and all ten surfaces agree. RFD-3, CHAT-2, PAY-5 and FIN-11 close per item with evidence; PAY-9, PAY-4, JE-2 and LI-3 keep their recorded triggers.

## Execution Log

None.

### 2026-11-21 — Original implementation

- Steps 1–7 reproduced the exact frozen Git blobs: migration 52bb1f1577f4346b439a1c33c47b233de5d4935d, Tests 54 c4b1b3e8549fd8820ae39eeda99c3e9edcb1dda7, 96 72e2107b07178f352a634606fcbd7173bdf39a23, 140 d132e48e82f068588148df658d9eeedc4d2b15d7, 155 f85481f019a59ea756ba93a056140cc3576fc423 and 184 be2fc2e45076505879939d0a8accc0fa0f28656b, and the plan b766c82547d6c870d3cc2ecf16a51e387668a7d4.
- Step 8 regenerated the approved API blob 62af74be28b058e41b6b6bcfbe43457f15acfd33, in which only the `record_payment` row differs.
- Step 9 readiness ran two pgTAP passes of 184 files and 3445 assertions, native HTTP 35 passed and 0 failed, and smoke. Local catalog and parity matched 276 / 20261121110000 / 3d6fe3908078c02f611c70b4eb070623. Native pre-deploy consistency reported only RECOVER-1.
- Step 10 used the separate DELEGATED Gate 2 record for one apply to Platinum Primary vrvtsxexkiiiivlkdxzp after a lock read showing 275 / 5213d0d035d53e635a839f0ce9bb7693, the target absent, zero locks and zero rows on the five tables. SQL SHA-256 C73CF263E190D520D3B80BBE4D2D51CC861F878D068CABD991FDB330AC054D6C and MD5 28b4a3013130fe9337d1fe8d67d9c342 (22430 bytes) match the approved payload and the stored statement. The connector's temporary version 20261121142834 was reconciled to 20261121110000 under the one-row guard. Final readback: 276 entries, ledger 3d6fe3908078c02f611c70b4eb070623, all ten surfaces equal local (combined 3c6ea07a196c3cf0a3ff801397931e0e, 3203 objects), five bindings enabled, nine function bodies equal local and zero rows. Founder Secondary was not touched.
- Step 11 refreshed attributable Primary ledger evidence, the manifest live state, the plan and the API contract. RFD-3, CHAT-2, PAY-5 and FIN-11 are fixed; FIN-9 records its answered half and keeps its journal-event half open; PAY-9, PAY-4, JE-2 and LI-3 keep their statuses. `conversations`, `payment_allocations` and `refunds` are AUDITED; coverage is 60 AUDITED, 15 AUDITED-OPEN and 3 PARTIAL.
- Step 12 proceeds to the timed and watched Original Finish on this implementation commit, followed by Review, Complete, bind and the native release gates.

Evidence: Workbench `data/records/batch6/exit-bundle-b/spec326/` (`runtime/`, `GATE1-SPEC-326-DELEGATED.md`, `GATE2-SPEC-326-DELEGATED.md`, `DRAFT.md`).

## Verification Notes

None.


### 2026-11-21 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-326 only, DEC-02 and Batch 6 PLAN section 2 run mode 2 as redefined by the owner on 2026-11-21 (owner-2026-11-21-run-modes-redefined.txt, SHA-256 35E35600BB9D2D69EBF0A85BE8E6256260617F9A8B47F74A091565BC53AF69DD). Exact Draft SHA-256 05F67B185E3AAA8B9A8E09D46FFB1081D566D6344CCAED6B7FD745F44E6FDCF8, Git blob b124b765a1f6e40a5c2c948bc6be76cbd39eea8c, CRM baseline 7c5975a. Native isolated Approve f11b429e7eb3074ce71b76224aa2f5f23a7ba5e6 passed, literal Steps 1-7 matched, and the unchanged consistency guard reported RECOVER-1 only after the Step 9 text. This record is Gate 1 only. Gate 2 is separate and depends on the exact artifact, current target, readiness and recovery. Immediately before allocation the hash, the Draft blob b124b765a1f6e40a5c2c948bc6be76cbd39eea8c, all 5 source anchors, the baseline HEAD 7c5975a09b9351308a3178f1c1579798747fbe51 against refreshed origin/main 7c5975a09b9351308a3178f1c1579798747fbe51 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 727cb98. No implementation performed before this transition.

## Review Gate

- [ ] Exact approved payload and allowed scope.
- [ ] Isolated causal negatives and native SQL, smoke, HTTP and API evidence.
- [ ] Verified Primary identity, ledger, parity and per-item registry changes.
- [ ] Existing open items and governance gates retained.

## Notes

Baseline: 7c5975a09b9351308a3178f1c1579798747fbe51.

Owner authority: Workbench `data/records/batch6/owner-words/owner-2026-11-20-batch-more-work-directive.txt`, SHA-256 `383D3198EBC1E7E0B46CE19945B0FBF35A062A5A74B3AF0792DEE13EB6734840`. Run mode: Workbench `data/records/batch6/owner-words/owner-2026-11-21-run-modes-redefined.txt`, SHA-256 `35E35600BB9D2D69EBF0A85BE8E6256260617F9A8B47F74A091565BC53AF69DD`. Grouping keeps per-item acceptance, and native Gate 1 and Gate 2 remain. This Draft conveys no Original, deployment or release approval.

Isolated proof: Workbench `data/records/batch6/exit-bundle-b/` `RECHECK.md`, `repro-7c5975a.sql`, `repro-7c5975a.log`, `prototype-pgtap.log`, `prototype-smoke.log`, `prototype-http.log`, `prototype-api.md`, `prototype-catalog.log`, `prototype-parity.log` and `primary-preflight-read.log`.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/54_transition_permission_parity_test.sql` | `05fb9a92860d4c1f305eb44f999cd27993812fe9` |
| `supabase/tests/96_invoice_void_and_eta_boundary_test.sql` | `dfa0b23e384fe29ec369008f4a60b419dc9a3b28` |
| `supabase/tests/140_payment_is_recorded_on_every_door_test.sql` | `0f027d1ab4b873b3eae178166d73909a3476232d` |
| `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql` | `d48cccf93cc1b20aa24bf3385704e1e8b712f0eb` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `171d70f4a107af5b7827fc0a67636d3bb267b74c` |
