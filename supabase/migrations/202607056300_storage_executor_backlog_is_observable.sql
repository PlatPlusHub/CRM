-- SCHED-1 (partial) -- an executor nobody invokes is now visible instead of silent.
--
-- ================================================================================================
-- WHAT SCHED-1 ACTUALLY IS, MEASURED RATHER THAN ASSUMED
--
-- Re-proven live on Primary: three pg_cron jobs exist and cover three of the four recurring jobs --
-- `app.reconcile_document_storage` (daily 00:30), `app.process_lead_sla` (every minute) and
-- `app.process_subscription_lifecycle` (daily 00:10). The FOURTH recurring job, the storage
-- executor, has no scheduler at all. It is an Edge Function (ACTIVE, `verify_jwt = true`) that
-- claims work through `public.claim_storage_actions`, destroys bytes through the Storage API and
-- reports the outcome back. Every part of it is proven end to end by
-- `scripts/verify_storage_end_to_end.ps1` -- except that nothing ever calls it.
--
-- WHY IT IS NOT SCHEDULED HERE. Every available route needs the owner to place ONE secret, and none
-- of them can be chosen without a security trade-off that is the owner's to make:
--
--   A. pg_cron + pg_net + Vault. `pg_cron` 1.6.4 is installed, `pg_net` 0.20.4 is available but NOT
--      installed, and `supabase_vault` IS installed -- so the invocation secret could live encrypted
--      in Vault rather than in a migration, a column or a log, which is a materially better position
--      than the one recorded when pg_net was first declined. The cost is real all the same:
--      installing pg_net gives the DATABASE outbound HTTP, a capability ORVION does not have today.
--   B. n8n schedule -> HTTP request. n8n is live (0 workflows, 2 credentials) and keeps outbound
--      HTTP out of the database, at the cost of making a core retention path depend on n8n's uptime.
--   C. A scheduled GitHub Action, which couples data-plane operations to CI.
--
-- All three are BLOCKED -- EXTERNAL DEPENDENCY on one owner-placed secret, and choosing between them
-- is BLOCKED -- ARCHITECTURAL DECISION. Installing pg_net unilaterally to make a metric move would be
-- exactly the "select a scheduler because it is convenient" the directive forbids.
--
-- WHAT NEEDED NO DECISION, AND IS DONE HERE. Today the gap is SILENT. If the executor never runs --
-- or is scheduled and then breaks -- retention-expired findings simply accumulate, bytes ORVION has
-- undertaken to destroy stay on disk, and nothing anywhere says so. `document_storage_findings` is
-- readable by the platform, but reading a table is not a signal: a backlog is only visible if
-- someone thinks to look and knows what "too old" means.
--
-- `app.storage_action_backlog()` answers the one question that distinguishes "working" from "never
-- ran": HOW OLD IS THE OLDEST PIECE OF UNDONE WORK. It reuses `app.claim_storage_actions`'
-- eligibility rules verbatim rather than restating them, because a monitor that measures a different
-- population than the worker consumes is worse than none -- it reports zero while work piles up.
-- ================================================================================================

create or replace function app.storage_action_backlog()
returns table (
    pending_actions        integer,
    oldest_pending_age     interval,
    attempted_and_failed   integer,
    last_attempt_at        timestamptz,
    unresolved_findings    integer
)
language sql
stable
security definer
set search_path = ''
as $fn$
    with claimable as (
        -- Deliberately `select *` from the claim function: one definition of "actionable", used by
        -- the worker and by the monitor, so the two can never disagree about what is outstanding.
        select * from app.claim_storage_actions(500)
    ),
    src as (
        select f.first_seen_at, f.attempt_count, f.last_attempt_at
        from public.document_storage_findings f
        join claimable c on c.finding_id = f.id
    )
    select
        (select count(*)::int from src),
        (select now() - min(first_seen_at) from src),
        (select count(*)::int from src where attempt_count > 0),
        (select max(last_attempt_at) from public.document_storage_findings),
        (select count(*)::int from public.document_storage_findings where resolved_at is null);
$fn$;

revoke execute on function app.storage_action_backlog() from public;
grant  execute on function app.storage_action_backlog() to service_role;

-- The platform surface, following the same shape as `public.claim_storage_actions`: a SECURITY
-- INVOKER wrapper granted to service_role only, so the backlog is reachable over HTTP by the
-- platform and by nobody else. A tenant must not be able to read platform operational state, and an
-- unauthenticated caller must not be able to probe how far behind ORVION is.
create or replace function public.storage_action_backlog()
returns table (
    pending_actions        integer,
    oldest_pending_age     interval,
    attempted_and_failed   integer,
    last_attempt_at        timestamptz,
    unresolved_findings    integer
)
language sql
stable
set search_path = ''
as $fn$
    select * from app.storage_action_backlog();
$fn$;

revoke execute on function public.storage_action_backlog() from public, anon, authenticated;
grant  execute on function public.storage_action_backlog() to service_role;

notify pgrst, 'reload schema';
