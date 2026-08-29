-- DOC-LC-1 -- canon 26 defines a Document Lifecycle State Machine. It had never been wired.
--
-- REPRODUCED BEFORE IT WAS FIXED, with the positive control that makes it conclusive: a `trainee`
-- holding ARCHIVE_DOCUMENT = false, who can SEE a colleague's document because RLS gives them the
-- department queue, was refused by the RPC and succeeded by direct DML in the same transaction:
--
--     baseline                 : lifecycle=active   is_archived=false
--     trainee ARCHIVE_DOCUMENT : false
--     trainee SEES the doc     : rows=1                     <- not a vacuous denial
--     app.archive_document(...): ERROR permission denied: ARCHIVE_DOCUMENT
--     update documents set lifecycle_status_code='archived' : 1 row
--     after                    : lifecycle=archived  is_archived=false
--
-- WHY THE EXISTING GUARD DID NOT CATCH IT. `app.enforce_archive_authority` is attached to
-- `documents` and charges ARCHIVE_DOCUMENT -- but its second statement is
-- `if new.is_archived is not distinct from old.is_archived then return new; end if`. It watches the
-- BOOLEAN. `lifecycle_status_code` is a different column and was governed by nothing except
-- `enforce_catalog_codes`, which only asks whether the code exists in the catalog, never whether the
-- MOVE is legal. This is the same shape as FIN-6 one domain over: a guard was present, working, and
-- watching the wrong column.
--
-- WHAT IT BUYS AN ATTACKER, and it is not cosmetic. `lifecycle_status_code = 'archived'` is read as
-- a refusal condition by BOTH document write paths:
--   * `app.add_document_version` raises 'document is already archived'  -> no further version, ever
--   * `app.archive_document`      raises 'document is already archived'  -> the LEGITIMATE archive
--                                                                          path is blocked too
-- So a trainee with no write permission at all can permanently freeze any document they can see,
-- and leave `is_archived = false` so nothing that reads the boolean reports it as archived. A
-- passport that can no longer be re-versioned, in an agency whose most common way to lose a
-- departure is an expired passport.
--
-- ---------------------------------------------------------------------------------------------
-- WHAT IS REGISTERED, AND WHAT IS DELIBERATELY NOT
-- ---------------------------------------------------------------------------------------------
-- Canon 26 "Document Lifecycle State Machine" names three states (active, archived, superseded)
-- and three transitions. Only two of them are registered here, and the omission is the considered
-- part of this package rather than an oversight:
--
--   active     -> archived    REGISTERED. `app.archive_document` performs it and charges
--                             ARCHIVE_DOCUMENT, read out of the function, not chosen here.
--   superseded -> archived    REGISTERED. Same function, same permission: `archive_document`
--                             refuses only when the document is ALREADY archived, so it archives
--                             from any other state including `superseded`. Registering it keeps
--                             the RPC's own behaviour legal if superseding is ever implemented.
--   active     -> superseded  **NOT REGISTERED.**
--
-- Why not: `documents.lifecycle_status_code = 'superseded'` HAS NO PRODUCER. Verified against every
-- writer of the column (`add_document_version`, `archive_document`, `expiring_documents`,
-- `financial_documents`, `upload_document`, `upload_subscription_payment_proof`) -- not one sets it.
-- `app.add_document_version` moves `current_version_id` and flips `is_current` on the VERSION rows;
-- the DOCUMENT stays `active`. That is not an accident: SPEC-110 recorded the divergence as an
-- Engineering Observation in Phase 7 ("canon-26 'new version -> superseded' diverges from the frozen
-- current_version_id intra-document versioning design; document-level supersede reserved for a
-- future explicit op"), and canon 32's Phase 7 entry still carries it.
--
-- The `document_superseded` EVENT is produced -- by `documents_emit_superseded`, an AFTER UPDATE
-- trigger keyed on `current_version_id` changing. So in the implemented design "supersede" is an
-- event about the version pointer, never a document-level status.
--
-- Registering `active -> superseded` would therefore permit direct DML to move a document into a
-- state nothing writes and nothing reads -- inventing a capability to satisfy a document, which is
-- exactly what this programme forbids. The canon-vs-implementation divergence is recorded as
-- **DOC-LC-2** in MASTER_GAP_REGISTER.md and left to the owner, because deciding whether a document
-- supersedes is a business question about how an agency thinks of its records.
--
-- NOTE ON FAIL-CLOSED. `app.enforce_status_transition` raises 23514 for any move not in the
-- registry, so this migration also closes `archived -> active` -- canon lists no transition back
-- into `active`, and a control that let anyone un-archive would make the archive meaningless
-- (`enforce_archive_authority` says exactly that about its own column).
--
-- SESSION-LESS PATHS are unaffected: `enforce_status_transition` returns early when `auth.uid()` is
-- null (canon 35 principle 6). Checked rather than assumed -- `app.reconcile_document_storage` and
-- `app.platform_resolve_storage_finding` READ `superseded` on document_versions and never write
-- `documents.lifecycle_status_code`.

insert into app.status_transitions (table_name, status_column, from_status, to_status, permission_key)
values
    ('documents', 'lifecycle_status_code', 'active',     'archived', 'ARCHIVE_DOCUMENT'),
    ('documents', 'lifecycle_status_code', 'superseded', 'archived', 'ARCHIVE_DOCUMENT');

-- BEFORE UPDATE only. There is no INSERT branch by design: `app.upload_document` and
-- `app.upload_subscription_payment_proof` set the column at creation, and a state machine governs
-- MOVES, not births. `documents_guard_write_capability` (SEC-1b) already charges the permission on
-- the INSERT path.
create trigger documents_enforce_status_transition
    before update on public.documents
    for each row
    execute function app.enforce_status_transition('lifecycle_status_code');
