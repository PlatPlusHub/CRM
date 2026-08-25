-- Migration: lead_owner_assignee_coherence
-- Plan reference: SPEC-151. Resolves the `leads.owner_user_id` / `leads.assigned_user_id`
-- duplication that has been recorded as open since SPEC-140.
--
-- THE PROBLEM. Both columns exist, canon 31 lists both without distinguishing them, and every write
-- path sets them to the same value. Two columns holding one fact is the duplicate source of truth the
-- owner's directive names directly: "The same fact must not be represented in multiple competing
-- structures unless there is a clearly defined authoritative source."
--
-- WHAT THE EVIDENCE SAYS, RATHER THAN WHICH NAME READS BETTER. The three RPCs that need to know who
-- is handling a lead -- `app.advance_lead`, `app.convert_lead` and `app.record_lead_interaction` --
-- all read `assigned_user_id` and none reads `owner_user_id`. The business logic already treats
-- `assigned_user_id` as the fact. `owner_user_id` exists to complete the uniform ownership triple
-- (`owner_user_id` / `owner_branch_id` / `owner_department_id`) that the SPEC-137 scope model applies
-- across eight tables, so removing it would make `leads` the one exception to that pattern.
--
-- So neither column is redundant in the sense that it can simply be dropped: one is the authority,
-- the other is the shape the scope model reads. What was actually missing is anything stopping them
-- from disagreeing. The three writers (`assign_lead`, `reassign_lead`, `process_lead_sla`) set both
-- together, but a direct UPDATE could set either alone -- and then "who is handling this lead?" would
-- have two answers, with the RPCs believing one and the read model enforcing the other.
--
-- A CHECK rather than a syncing trigger, deliberately: a trigger would quietly repair the caller's
-- write and hide the fact that something tried to move one without the other. A constraint makes the
-- attempt fail loudly, which is what a divergence between an authority and its mirror deserves.

alter table public.leads
    add constraint leads_owner_matches_assignee_chk
    check (owner_user_id is not distinct from assigned_user_id);

comment on column public.leads.assigned_user_id is
    'AUTHORITATIVE handler of this lead. app.advance_lead, app.convert_lead and app.record_lead_interaction all resolve the handler from this column. Backed by the lead_assignments timeline (SPEC-140).';

comment on column public.leads.owner_user_id is
    'Mirror of assigned_user_id, present so leads carry the same ownership triple the SPEC-137 scope model reads across all eight scope-bearing tables. Constrained equal to assigned_user_id (SPEC-151); assigned_user_id is the authority.';
