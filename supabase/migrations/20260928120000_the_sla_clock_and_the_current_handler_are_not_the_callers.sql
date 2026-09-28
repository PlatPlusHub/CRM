-- SPEC-232 / Batch 6 Slice 30: `lead_assignments` -- ASGN-4 and ASGN-5.
--
-- `app.process_lead_sla` supervises a lead through ONE row: the lead's current assignment, whose
-- `assigned_at` is the SLA clock. canon 04 makes the escalation mandatory and canon 10 lists manager
-- escalation among the notices nobody may mute. Both inputs were writable at the table door by any
-- ASSIGN_LEAD or REASSIGN_LEAD holder, and either write took a lead out of supervision for good, with
-- no event and no notice to anyone:
--
-- ASGN-4: a manager closed the handler's current row and wrote nothing after it. The lead still read
-- `assigned` to that handler, the timeline said they had been unassigned, and the SLA, finding no
-- current row, skipped the lead on every pass. `app.require_assignment_history` guards the other
-- direction only: it fires when the LEAD's assignee moves, and here nothing on the lead moved.
--
-- ASGN-5: a manager closed the current row and re-inserted it with `assigned_at` a century ahead, so
-- the elapsed time was negative on every pass. A department manager did it to their own lead and the
-- branch manager was never told. Backdated, the same column named a colleague as a lead's first
-- handler in `app.lead_origin` and reordered round-robin and SLA reassignment. The column is already
-- frozen on UPDATE by `app.forbid_assignment_history_rewrite`; nothing owned it on INSERT.
--
-- Both repairs reuse an existing owner:
--   * ASGN-5 is ASGN-2's trigger deriving one more column, exactly as SPEC-231 derived a document
--     version's clock in the trigger that already derived its author. Session-less platform paths keep
--     the value they set, as they keep `assigned_by`.
--   * ASGN-4 is FIN-8's deferred constraint trigger. The invariant is false between the statements of
--     every legitimate handover -- `app.reassign_lead` and the SLA close the old row, insert the new one,
--     then move the lead -- so it can only be checked at COMMIT. No session-less exemption, for FIN-8's
--     reason: it is data integrity, not authorization, and every sanctioned writer already satisfies it.
--     A CLOSED history row is still legal (`verify_lifecycle_branches` asserts it over HTTP); only the
--     CURRENT row must name the lead's assignee.

create or replace function app.derive_assignment_actor()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    -- Session-less platform paths keep the attribution they set: app.process_lead_sla writes
    -- assigned_by => null deliberately, because no human performed that assignment.
    if (select auth.uid()) is null then
        return new;
    end if;
    new.assigned_by := app.current_user_id();

    -- ASGN-5: the SLA clock. Every RPC takes the column default; so does this door now.
    new.assigned_at := now();
    return new;
end
$fn$;

comment on function app.derive_assignment_actor() is
    'ASGN-2 / ASGN-5: lead_assignments.assigned_by and assigned_at are derived from the session and the server clock on INSERT, never accepted from the caller. assigned_at is the SLA clock and the round-robin order. UPDATE is already frozen by app.forbid_assignment_history_rewrite.';

create or replace function app.enforce_lead_current_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_assignee uuid;
    v_current uuid;
begin
    select l.assigned_user_id into v_assignee
    from public.leads l
    where l.id = new.lead_id and l.tenant_id = new.tenant_id;

    select la.assigned_user_id into v_current
    from public.lead_assignments la
    where la.lead_id = new.lead_id and la.tenant_id = new.tenant_id and la.is_current;

    if v_current is distinct from v_assignee then
        raise exception 'a lead''s current assignment must name the lead''s assignee: hand a lead over with app.reassign_lead'
            using errcode = '23514';
    end if;
    return null;
end
$fn$;

-- SECURITY DEFINER for ASGN-3's reason: under INVOKER the read of the parent lead is RLS-filtered.
-- It reads and never writes; a trigger function needs no EXECUTE grant.
revoke all on function app.enforce_lead_current_assignment() from public;

create constraint trigger lead_assignments_current_names_the_assignee
    after insert or update on public.lead_assignments
    deferrable initially deferred
    for each row execute function app.enforce_lead_current_assignment();
