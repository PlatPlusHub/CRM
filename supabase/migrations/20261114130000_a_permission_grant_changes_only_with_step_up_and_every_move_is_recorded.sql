-- Batch 6 slice 9 (`user_permission_grants`). Measured on the local stack before this file (probes UPG1-UPG4):
--   * USR-3: a ceo at aal1 granted itself a permission at the table door; MANAGE_PERMISSIONS was charged through RLS,
--     never the step-up `app.authorize` charges every MFA-bound role (the user_branch_assignments half closed in SPEC-300);
--   * a live grant was re-pointed to another user, to another permission (MANAGE_PERMISSIONS) and turned from grant to
--     deny by UPDATE, and `app.emit_permission_change` recorded none of it: it compared only liveness, which stayed true.
-- Repair: every session write charges `app.authorize('MANAGE_PERMISSIONS')`; the emitter records the old row leaving
-- effect and the new row taking effect whenever the user, permission, effect or tenant of a live row changes, with the
-- same event types, entity and payload as before.

create or replace function app.guard_permission_grant_authority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    perform app.authorize('MANAGE_PERMISSIONS');
    return new;
end;
$fn$;

revoke execute on function app.guard_permission_grant_authority() from public;

create trigger user_permission_grants_guard_authority
    before insert or update on public.user_permission_grants
    for each row execute function app.guard_permission_grant_authority();

create or replace function app.record_permission_change(
    p_tenant uuid, p_user uuid, p_permission uuid, p_effect text, p_now_live boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_key text;
begin
    select p.key into v_key from public.permissions p where p.id = p_permission;
    perform app.record_event(
        p_tenant,
        case when (p_effect = 'grant') = p_now_live then 'permission_granted' else 'permission_revoked' end,
        'user', p_user,
        (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = p_tenant),
        null, null, null,
        jsonb_build_object('permission_key', v_key, 'effect', p_effect, 'now_live', p_now_live),
        'warning');
end;
$fn$;

revoke execute on function app.record_permission_change(uuid, uuid, uuid, text, boolean) from public;

create or replace function app.emit_permission_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    -- OLD is read only on the branches where it is assigned (UPDATE, DELETE), NEW only where it is (INSERT, UPDATE).
    v_was_live boolean := false;
    v_now_live boolean := false;
    v_moved boolean := false;
begin
    if tg_op <> 'INSERT' then
        v_was_live := old.is_active and (old.ends_at is null or old.ends_at > now());
    end if;
    if tg_op <> 'DELETE' then
        v_now_live := new.is_active and (new.ends_at is null or new.ends_at > now());
    end if;
    if tg_op = 'UPDATE' then
        v_moved := (old.tenant_id, old.user_id, old.permission_id, old.effect)
                   is distinct from (new.tenant_id, new.user_id, new.permission_id, new.effect);
    end if;

    -- Only a change in EFFECTIVE privilege is an event: an edit to `reason` stays silent.
    if v_was_live and (v_moved or not v_now_live) then
        perform app.record_permission_change(old.tenant_id, old.user_id, old.permission_id, old.effect, false);
    end if;
    if v_now_live and (v_moved or not v_was_live) then
        perform app.record_permission_change(new.tenant_id, new.user_id, new.permission_id, new.effect, true);
    end if;
    return null;
end;
$fn$;
