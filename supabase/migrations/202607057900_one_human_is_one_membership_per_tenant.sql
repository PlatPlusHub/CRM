-- IDENT-4 -- the claim matched case-insensitively; uniqueness was case-sensitive.
--
-- `app.activate_membership()` matches `lower(u.email) = lower(v_email)` and its comment asserted the
-- result was "bounded to one row per tenant by users_tenant_email_key". That constraint is
-- `UNIQUE (tenant_id, email)` -- CASE-SENSITIVE. The two disagree, so the bound does not hold.
--
-- REPRODUCED on a clean local reset. A tenant holding both `ceo@case.test` and `CEO@case.test` --
-- legal today, because the constraint sees them as different people -- and one confirmed identity
-- for that address:
--
--     activate_membership()  ->  23505 duplicate key value violates unique constraint
--                                "users_tenant_auth_key"
--
-- The UPDATE targets BOTH rows and tries to put one `auth_user_id` on each, which
-- `UNIQUE (tenant_id, auth_user_id)` correctly refuses. The user is then **permanently unable to
-- onboard**, cannot fix it themselves, and sees a raw PostgreSQL error that names neither the cause
-- nor a remedy. It fails closed, so this is availability and data quality rather than a security
-- hole -- but it is unrecoverable without an administrator editing rows by hand.
--
-- WHY THE CONSTRAINT AND NOT THE FUNCTION. The reflex fix is to make the claim deterministic (take
-- one row per tenant). That papers over the actual fault: **two rows for one human existed at all.**
-- An email address is one identity; a tenant holding `ceo@x` and `CEO@x` has a duplicate person, and
-- every later question -- who owns this lead, whose commission is this, which one do we email --
-- inherits the ambiguity. The rule is a uniqueness invariant on the data, so it belongs in a UNIQUE
-- INDEX. That is also the layer that makes the function's comment true rather than merely quieter.
--
-- CROSS-PATH SWEEP (`AGENTS.md 3 5b`), both questions, measured rather than assumed:
--   Q1 -- what rule does this change?  Membership provisioning. `app.create_tenant_user` can no
--     longer create a case-variant duplicate of an existing email in the same tenant; it now gets a
--     23505 at insert time, which is the correct answer and arrives before the duplicate exists,
--     instead of at claim time when the invitee is already locked out.
--   Q2 -- what CONSUMES the structure?  `users_tenant_email_key` is referenced nowhere in the
--     repository except its own DDL and two prose comments -- grepped, not assumed -- so no code
--     parses it, catches it by name, or branches on it. Live check on a clean reset returned
--     **zero** existing case-variant groups, so this index cannot fail to build on current data, and
--     Primary holds zero business rows.
--
-- The existing case-sensitive constraint is DELIBERATELY LEFT IN PLACE. The new index is strictly
-- stronger and subsumes it, so it is redundant rather than wrong; dropping a named constraint is a
-- consumer risk (error-path matching, guard counts) for no functional gain, and this package already
-- carries a security fix that should not be entangled with a drop.

create unique index if not exists users_tenant_email_lower_key
    on public.users (tenant_id, lower(email));

comment on index public.users_tenant_email_lower_key is
'IDENT-4: one human is one membership per tenant. app.activate_membership matches email case-insensitively; this is the constraint that actually bounds it to one row.';
