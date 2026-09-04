-- =================================================================================================
-- FIN-7 — the invoice state machine was never missing; it was enforced on ONE of the two doors.
--
-- FIN-7 was carried for a week as `BLOCKED — BUSINESS DECISION`, on the reading that "canon 26
-- defines no Invoice State Machine" and that naming the legal transitions "would be inventing
-- business policy". Re-derived from the implementation rather than from the label, that is wrong.
-- The machine is already written, already enforced, and already owner-approved by use:
--
--   * `app.issue_invoice`  raises `only a draft invoice can be issued (is %)` -- so the ONLY move
--     into `issued` is from `draft`, and it charges CREATE_INVOICE.
--   * `app.record_payment` raises `only an issued/partially_paid/overdue invoice can be paid (is %)`
--     and then does not CHOOSE the next state at all -- it DERIVES it:
--         v_new_status := case when v_new_total >= v_inv.total_amount
--                              then 'paid' else 'partially_paid' end;
--     and it charges RECORD_PAYMENT.
--
-- Nothing here is invented. Every row below is read off those two functions, including its
-- permission. What was genuinely missing is that `app.status_transitions` held ZERO `invoices` rows
-- and `public.invoices` carried NO `enforce_status_transition` trigger, so those rules bound the RPC
-- door and not the direct PostgREST door -- while `authenticated` holds INSERT/SELECT/UPDATE on the
-- table. That is the "test both doors" class this repository has already closed five times
-- (BOOK-1, ADMIN-1, FIN-8, FIN-10, QUO-1), not a policy question.
--
-- REPRODUCED BEFORE FIXING (2026-09-04, local, inside a rolled-back transaction):
--     update public.invoices set status_code = 'draft' where id = <id>;
--     update public.invoices set status_code = 'paid'  where id = <id>;   -- skips `issued`
--   -> ACCEPTED. An invoice went from draft to paid without ever being issued and without a payment.
--
-- WHAT FIN-6 DID AND DID NOT DO. FIN-6 (`guard_financial_capability`) governs WHO may write the
-- column. It has no opinion about WHICH move is legal. Both guards are needed and neither replaces
-- the other; this migration adds only the second.
--
-- TWO STATES ARE DELIBERATELY NOT REGISTERED, each for a measured reason:
--
--   * `-> overdue` has NO PRODUCER. No function in `app` or `public` writes the literal 'overdue'.
--     Registering a transition nothing performs would invent a capability to satisfy a catalog
--     value (EVT-2's class). `record_payment` still accepts `overdue` as a FROM state, so the two
--     `overdue -> ...` rows below are registered: they are what the RPC's own contract offers.
--     If a future ageing job learns to SET `overdue`, it must add its own row -- and until then the
--     trigger refuses that move, which is the correct fail-closed answer.
--   * `-> voided` is VOID-1, a genuine OPEN owner decision (draft-only voiding vs an ETA-shaped
--     cancellation window vs a credit-note model). No writer exists, no permission is defined, and
--     choosing one would be choosing an accounting model. Leaving it unregistered means the table
--     door refuses it, which is strictly safer than the status quo, where it was permitted.
--
-- NO INSERT BRANCH, by design -- the DOC-LC-1 precedent. `app.create_invoice` sets the status at
-- creation and a state machine governs MOVES, not births; `invoices_guard_financial_capability`
-- already charges the permission on the INSERT path.
--
-- SAFE ON PART PAYMENTS: `app.enforce_status_transition` returns early when
-- `v_new is not distinct from v_old`, so a second partial payment
-- (`partially_paid -> partially_paid`) is not a transition and cannot trip the trigger.
-- =================================================================================================

insert into app.status_transitions (table_name, status_column, from_status, to_status, permission_key)
values
    -- app.issue_invoice: the only door into `issued`, and only from `draft`.
    ('invoices', 'status_code', 'draft',          'issued',         'CREATE_INVOICE'),

    -- app.record_payment: the next state is DERIVED from the amount, never chosen. Both outcomes
    -- are reachable from each of the three FROM states its own guard admits.
    ('invoices', 'status_code', 'issued',         'partially_paid', 'RECORD_PAYMENT'),
    ('invoices', 'status_code', 'issued',         'paid',           'RECORD_PAYMENT'),
    ('invoices', 'status_code', 'partially_paid', 'paid',           'RECORD_PAYMENT'),
    ('invoices', 'status_code', 'overdue',        'partially_paid', 'RECORD_PAYMENT'),
    ('invoices', 'status_code', 'overdue',        'paid',           'RECORD_PAYMENT');

create trigger invoices_enforce_status_transition
    before update on public.invoices
    for each row
    execute function app.enforce_status_transition('status_code');

comment on trigger invoices_enforce_status_transition on public.invoices is
    'FIN-7. Enforces the invoice state machine on the DIRECT table door. The machine itself is not '
    'defined here -- it is read off app.issue_invoice and app.record_payment, which have always '
    'enforced it on the RPC door. `-> overdue` is unregistered because nothing produces it; '
    '`-> voided` is unregistered because VOID-1 is an open owner decision.';
