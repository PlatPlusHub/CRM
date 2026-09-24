-- SPEC-216 / DOC-4, DOC-5, DOC-6, DOC-LC-3 -- Batch 6 slice 16, `documents`.
--
-- THE RULE. The table door may not give a document a state its own RPCs cannot give it.
-- `app.upload_document` and `app.upload_subscription_payment_proof` create a document `active`,
-- unarchived, not under legal hold and with no version, then point it at the version they have just
-- made current; `app.add_document_version` moves the pointer only to the version it has just made
-- current; `app.archive_document` moves `lifecycle_status_code` and `is_archived` together; and no
-- RPC ever changes a document's type. `authenticated` holds table-level INSERT and UPDATE here, and
-- all five RPCs are SECURITY INVOKER through that same grant, so PostgREST serves the table beside
-- them. Measured before this migration, each by a role that could not reach the state any other way:
--   * DOC-4 -- an `employee` (UPLOAD_DOCUMENT, no MANAGE_TENANT_SETTINGS) was refused placing a
--     legal hold by UPDATE and then INSERTed a document born held, its hold reason, time (2019) and
--     placer (the owner) all its own choice, with no `document_legal_hold_placed` event. It could
--     equally forge the evidence of a hold "released". `app.guard_document_legal_hold` and its
--     event are UPDATE triggers, and nothing judged the INSERT.
--   * the ARCH-2 and ENTRY-1 instances on this table: the same employee INSERTed a document born
--     archived (archiver = the owner, 2019, a reason of its own), and documents born `archived`
--     and `superseded` -- `superseded` being a state nothing writes (DOC-LC-2).
--   * DOC-5 -- the same employee pointed its own document at another document's version -- a
--     confidential one it cannot see -- or at nothing, on UPDATE and on INSERT. The FK checks the
--     tenant only.
--   * DOC-6 -- PP-4's unmeasured half. `app.guard_write_capability` charges MANAGE_TENANT_SETTINGS
--     for a `payment_proof` by the NEW type only, so a `finance_manager` retyped the owner's
--     pending subscription payment proof to `receipt` and, now outside the class, added a version:
--     the file the Platform Owner reviews was replaced by a role that holds no MANAGE_TENANT_SETTINGS
--     and cannot even see the proof row.
--   * DOC-LC-3 -- a `branch_manager` archived a document through `app.archive_document` and moved
--     `is_archived` back alone, leaving `archived/false`: a document neither write path will
--     version while the boolean reports it live. Its decided fix is the constraint below.
--
-- THE SHAPE is `app.guard_quotation_integrity`'s (SPEC-214), deliberately: SECURITY INVOKER so
-- `current_user` names the caller, and `postgres` -- migrations, fixtures and every definer path --
-- passes through. `service_role` holds no INSERT or UPDATE here, so no other session-less writer
-- exists. The version lookup is read as the caller, as `app.add_document_version` reads it: a
-- version's visibility is its parent's, so an invisible version fails closed. Refusing a document
-- born held or archived, rather than authorizing and stamping it, is the entry state the RPCs
-- define; placing a hold and archiving remain the governed UPDATE acts they already are.
--
-- NOT CHANGED: every grant, policy and other trigger, every RPC, and `app.guard_write_capability`
-- -- a frozen type makes its NEW-only reading sufficient, without touching the function 26 tables
-- share. The title, expiry and confidentiality stay writable exactly as before.
create or replace function app.guard_document_integrity()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
    if current_user = 'postgres' then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if new.lifecycle_status_code is distinct from 'active' then
            raise exception
                'a document is created active (canon 26); it cannot be created already % -- use app.archive_document',
                new.lifecycle_status_code using errcode = '23514';
        end if;
        if new.is_archived or new.archived_at is not null or new.archived_by is not null
           or new.archive_reason is not null then
            raise exception 'a document is created unarchived; archive it with app.archive_document'
                using errcode = '23514';
        end if;
        if new.legal_hold_active or new.legal_hold_reason is not null
           or new.legal_hold_changed_at is not null or new.legal_hold_changed_by is not null then
            raise exception 'a document is created without a legal hold; place one with app.set_document_legal_hold'
                using errcode = '23514';
        end if;
        if new.current_version_id is not null then
            raise exception 'a new document has no version to point at; upload it with app.upload_document'
                using errcode = '23514';
        end if;
        return new;
    end if;

    if new.document_type_code is distinct from old.document_type_code then
        raise exception 'a document keeps the type it was uploaded as; upload a new document instead'
            using errcode = '23514';
    end if;

    if new.current_version_id is distinct from old.current_version_id
       and not exists (select 1 from public.document_versions dv
                        where dv.id = new.current_version_id
                          and dv.document_id = new.id
                          and dv.is_current) then
        raise exception 'a document points only at its own current version; add one with app.add_document_version'
            using errcode = '23514';
    end if;

    return new;
end;
$$;

revoke execute on function app.guard_document_integrity() from public;

create trigger documents_guard_integrity
    before insert or update on public.documents
    for each row execute function app.guard_document_integrity();

alter table public.documents
    add constraint documents_archived_status_is_archived_check
    check (lifecycle_status_code <> 'archived' or is_archived);
