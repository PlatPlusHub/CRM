-- Migration: a_device_record_its_own_subject_could_rewrite
-- Batch 6 slice 7 -- `trusted_devices`. Closes TD-1 and TD-2.
--
-- WHAT THIS SURFACE ACTUALLY IS. Like `otp_challenges` (OTP-1, `202607061600`), this table was
-- carried as "correctly unguarded because it is pre-authentication". It is not pre-authentication:
-- `anon` holds NO grant on it, and the attack below confirms that behaviourally. It is an
-- `auth.uid()`-owned Human Identity artifact (canon 34, ADR-0017), written by three SECURITY INVOKER
-- RPCs from `202607044200`, and reachable at `aal1` by the human the record is ABOUT.
--
-- THE INHERITED QUESTION WAS BOOK-3's: does direct DML bypass what `app.record_trusted_device`
-- charges? Reproduced on the local stack 2026-09-07 as `authenticated`, `current_user` asserted in
-- the same transaction (an earlier run of this battery silently executed as the owner, because
-- `set local role` outside a transaction block is a no-op -- the results below are from the
-- corrected run, and that near-miss is recorded in the session report as its own finding):
--
--   -- HELD, and these are the boundaries that make this a Medium and not a High:
--   A5  insert ... (auth_user_id = <another human>)      -> ERROR new row violates RLS policy
--   A6  update ... where device_identifier='victim-D'    -> UPDATE 0   (another human's row)
--   A8  update ... set auth_user_id = <self>             -> UPDATE 0   (cannot steal a row)
--   A7  delete from public.trusted_devices               -> ERROR permission denied (no DELETE grant)
--   A9  select as anon                                   -> ERROR permission denied
--   A10 insert as anon                                   -> ERROR permission denied
--
--   -- BROKE, all as the subject, over its own row:
--   A1  insert ... status_code = 'SUPER_TRUSTED_FOREVER'  -> INSERT 0 1, stored verbatim
--         (the family `trusted_device_status` is SEEDED AND ACTIVE: expired/revoked/trusted)
--   A2  update ... set verified_at = <73 years hence>     -> UPDATE 1
--   A3  update ... set first_seen_at='2001-01-01',
--                      created_at  ='2001-01-01'          -> UPDATE 1
--
-- TD-1 -- THE VOCABULARY WAS SEEDED AND NEVER ENFORCED. `202607051300` says it extended
-- `app.enforce_catalog_codes` "to every catalog-backed column that was previously validated only on
-- its RPC path", and lists its exclusions under the heading "DELIBERATE EXCLUSIONS, each with a
-- reason rather than an oversight". `trusted_devices.status_code` is in NEITHER set: not enforced,
-- and not excused. It is an omission from a migration that claimed completeness in prose, and no
-- guard could see the difference because no guard measured the claim.
--
-- The fix is the existing mechanism with nothing added to it: the same generic trigger function, the
-- same declarative column->family mapping, the family that `202607043100` already seeded. ADR-0006
-- names exactly this option. This is not a new architecture; it is the row `202607051300` should
-- have carried.
--
-- TD-2 -- THE DOOR DID NOT ENFORCE WHAT THE RPC CHARGES. `app.record_trusted_device` states its own
-- rule in a comment and in code: "The FIRST verification is the one worth keeping; re-seeing a
-- device is not re-verifying it" -- `verified_at = coalesce(public.trusted_devices.verified_at, now())`.
-- A direct UPDATE rewrites it freely, and `first_seen_at` / `created_at` likewise. This is SEC-1's
-- shape on a security-domain record: a rule enforced on the RPC path only is not enforced, because
-- PostgREST exposes the table itself. The consequence is anti-forensic rather than privilege-
-- gaining -- a subject can make a device look long-established and long-verified in the one record
-- a security investigation would read.
--
-- `app.forbid_trusted_device_record_rewrite` follows the ratified idiom for this exact problem
-- (`app.forbid_message_rewrite`, `app.forbid_assignment_history_rewrite`): a small table-specific
-- trigger naming the columns that may change, erroring 42501 on the rest. It is deliberately NOT a
-- new generic mechanism -- `app.forbid_acquisition_lineage_rewrite` is already generic over
-- `tg_argv`, but its message says "is acquisition lineage", which would be actively misleading in a
-- device-trust investigation.
--
-- MEASURED AND DELIBERATELY NOT REPAIRED HERE:
--
--   * REVOCATION IS NOT DURABLE, AND THAT IS THE DESIGN, NOT A DEFECT. A revoked device can be
--     re-trusted by direct DML (`set status_code='trusted', revoked_at=null`) -- but A4b proved
--     `app.record_trusted_device` DOES EXACTLY THE SAME THING on its sanctioned path: its
--     ON CONFLICT clause sets `revoked_at = null`. Direct DML gains nothing the RPC does not
--     already offer, so revoking the write grant would not close it and would break the RPC, which
--     is SECURITY INVOKER. Whether revocation SHOULD survive a re-record is a device-trust policy
--     question (canon 34 defines no device-trust lifecycle), registered as TD-3. Inventing an
--     answer here would be inventing the lifecycle this migration has no authority to invent.
--
--   * WHY TD-3 IS NOT URGENT, AND THE CONDITION THAT MAKES IT SO. Nothing in this database consumes
--     `trusted_devices` for an authorization decision. `app.mfa_satisfied()` reads
--     `app.requires_mfa()` and the JWT `aal` claim and NOTHING ELSE; no RLS policy references the
--     table. Device trust is currently a RECORD, not a GATE, which is why forged evidence and
--     non-durable revocation both stop at integrity and never reach privilege. That condition is
--     the whole reason the severity is what it is -- so it is pinned as an executable membership
--     assertion in `107_trusted_device_record_integrity_test.sql` rather than left as a sentence
--     here. The day someone wires device trust into an authorization path, that test fails and TD-3
--     must be answered before the wiring lands.
--
-- BLAST RADIUS. Both triggers are additive and fire only on paths that were previously unguarded.
-- The three RPCs continue to work unchanged and are proved to still work by the test, not assumed:
-- `record_trusted_device` changes only `last_seen_at`, `status_code`, `revoked_at` and a NULL
-- `verified_at`; `revoke_trusted_device` changes only `status_code` and `revoked_at`. Every existing
-- row carries `trusted` or `revoked`, both active values of the family, so no historical row becomes
-- unwritable. `authenticated` holds no DELETE grant, so the rewrite guard is scoped to UPDATE.

-- ---------------------------------------------------------------------------------------------
-- TD-1 -- the seeded vocabulary becomes authoritative at the point of use.
-- ---------------------------------------------------------------------------------------------

create trigger trusted_devices_enforce_catalog_codes
    before insert or update on public.trusted_devices
    for each row execute function app.enforce_catalog_codes(
        'status_code', 'trusted_device_status');

-- ---------------------------------------------------------------------------------------------
-- TD-2 -- the table door enforces the rule the RPC already charges.
-- ---------------------------------------------------------------------------------------------

create or replace function app.forbid_trusted_device_record_rewrite()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    -- The subject of the record is the record's identity. Swapping either would make the row
    -- attest to a verification that never happened for that human or that device.
    if new.auth_user_id is distinct from old.auth_user_id
       or new.device_identifier is distinct from old.device_identifier then
        raise exception
            'a trusted-device record may not change which human or which device it is about '
            '(auth_user_id, device_identifier)'
            using errcode = '42501';
    end if;

    -- app.record_trusted_device: "The FIRST verification is the one worth keeping; re-seeing a
    -- device is not re-verifying it." NULL -> a value is that first verification and is allowed.
    if old.verified_at is not null
       and new.verified_at is distinct from old.verified_at then
        raise exception
            'trusted_devices.verified_at records the FIRST verification and may not be rewritten '
            '("%" -> "%")', old.verified_at, new.verified_at
            using errcode = '42501';
    end if;

    if new.first_seen_at is distinct from old.first_seen_at
       or new.created_at is distinct from old.created_at then
        raise exception
            'trusted_devices.first_seen_at and created_at are when this device was first seen; '
            'only last_seen_at, status_code and revoked_at may change'
            using errcode = '42501';
    end if;

    return new;
end;
$$;

-- `create function` grants EXECUTE to PUBLIC by default, and `202607050200` established that no
-- ORVION function may carry it. Test 10 assertion 5 caught this omission in the first draft of this
-- migration -- the guard working, exactly as `202607061200` did for the sibling forbid_* trigger.
revoke execute on function app.forbid_trusted_device_record_rewrite() from public;

comment on function app.forbid_trusted_device_record_rewrite() is
    'TD-2: a trusted-device record is evidence about its own subject. Only last_seen_at, '
    'status_code and revoked_at may change -- exactly what app.record_trusted_device and '
    'app.revoke_trusted_device write.';

create trigger trusted_devices_forbid_record_rewrite
    before update on public.trusted_devices
    for each row execute function app.forbid_trusted_device_record_rewrite();
