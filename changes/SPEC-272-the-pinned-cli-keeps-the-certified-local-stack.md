# Change Request — SPEC-272

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Restore ORVION's certified local database and runtime behaviour under the pinned project-local Supabase CLI v2.120.0.

## Business Reason

SPEC-271 pinned the project-local CLI to v2.120.0 and was cancelled by human command on 2026-10-13 (`3c93c1c`). Two verified defects blocked it.

- v2.120.0 treats an unset `[api] auto_expose_new_tables` as `true`, while v2.109.0 treated it as `false`. A fresh local database therefore keeps 434 Data API privileges that the certified baseline does not have, including `anon` and `authenticated` access to three sequences. pgTAP 155 #68 fails.
- On Windows Docker Desktop, every CLI version can reach the daemon for Vector only through an unauthenticated `tcp://:2375`, so Vector restart-loops. Nothing in ORVION consumes local Analytics or Vector.

`migration-ci.yml` also keeps a second CLI pin (2.109.1), so the two CI database lanes test different CLIs. The owner selected Option A on 2026-10-13: keep v2.120.0, pin default-deny grants, disable local Analytics, and leave one CLI version authority.

## Risks

The local `db reset` run by `-Finish` destroys local data. The current local data is 30 MB of test residue. Step 4 takes a dump first, validates the host copy with `pg_restore -l`, and fails closed before any stop or reset if creation, copying or validation fails. Disabling local Analytics removes Studio's local log explorer. Edge Function logs remain available through `docker logs`. If the `auto_expose_new_tables` key is ever removed upstream, a later CLI upgrade must re-verify grants; this contract changes no Primary grant. If `migration-ci.yml` installs the CLI from the lockfile, `npm ci` must succeed on the runner, which is already true for ORVION Acceptance. No Primary write occurs.

## Supersedes / Depends On

- `changes/SPEC-271-upgrade-project-local-supabase-cli-to-2-120-0.md` (Cancelled; this contract is its successor and carries its v2.120.0 pin forward unchanged)

## Write Scope

- `supabase/config.toml`
- `.github/workflows/migration-ci.yml`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `package.json`
- `package-lock.json`
- `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `.workstation/manifest.md`
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `changes/TEMPLATE.md`
- `changes/SPEC-271-upgrade-project-local-supabase-cli-to-2-120-0.md`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md` §§1–4
- `supabase/config.toml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`
- `changes/SPEC-271-upgrade-project-local-supabase-cli-to-2-120-0.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- `npm ls supabase --depth=0`
- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_care_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_storage_end_to_end.ps1`
- `Get-Content -Raw scripts/verify_database.sql | docker exec -i supabase_db_ORVION psql -v ON_ERROR_STOP=1 -U postgres -d postgres -f -`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Local Data API default privileges for new `public` entities: unset, which v2.120.0 reads as `true`, becomes an explicit `false` | pgTAP, especially 155 #68 and the grant-model tests; the six HTTP suites; `verify_database.sql` | VERIFY | 2026-10-13 isolated probe (`orvion-grant-probe`, same 252 migrations and 156 test files, project-local v2.120.0). Unset: pgTAP 1/2969 fail (155 #68: `have false/false/true/true`). Unset adds 434 privileges and removes none (service_role SELECT/INSERT/UPDATE/DELETE on 84–87 relations, EXECUTE on 79 functions, and `anon`/`authenticated` USAGE/SELECT on 3 sequences). `false` after `db reset`: pgTAP 2969/2969 PASS, `pg_default_acl` `postgres=arwdDxtm/postgres,service_role=Dxtm/postgres`. All 671 API-role grant rows are identical (0 differences) to the live 2.109.0-built ORVION database that SPEC-270's HTTP suites certified. Final proof: the `-Finish` DATABASE protocol. |
| The same setting, as seen by Primary | Primary `vrvtsxexkiiiivlkdxzp` | UNAFFECTED | No tracked script or workflow runs `supabase link`, `config push` or `db push`. `supabase/.temp` holds no project ref. The setting acts only inside the CLI's local database bootstrap. Primary's legacy `service_role` grants (read-only, 2026-10-12: DELETE on all 78 `public` tables) are a separate assessment and are not changed here. |
| v2.120.0 parsing of `auto_expose_new_tables = false` | CLI config loader | VERIFY | `db-config.toml-read.ts` (v2.120.0) reads a present key as `Some(bool)`, and `applyApiPrivileges` runs the revoke unless the value is `true`. Only `true` prints the deprecation warning. The probe ran `db reset` with `false`: exit 0, revoke applied. |
| Local Supabase Analytics (Logflare) and Vector are no longer created | Scripts, pgTAP and HTTP suites, workflows, MCP servers, Edge Function `storage-executor`, `doctor.ps1`, Boot, `-Finish`, watchers | UNAFFECTED | A scan of 466 tracked code and config files finds `analytics`, Logflare, Vector and port 54327 only in `supabase/config.toml`. The only containers referenced by name are `supabase_db_ORVION` and `supabase_edge_runtime_ORVION`. `doctor.ps1` checks engine readiness, not container counts. Reports from 2026-08-21 to 2026-09-09 record Vector restart-looping through certified runs with no effect. Distinct from GA4, ad attribution and ORVION's own `public.events`, which this setting does not touch. |
| `migration-ci.yml` obtains the CLI from the lockfile instead of a second pin | Its four database steps; remote certification expecting Migration CI on `main` when a watched path changes; the DATABASE path agreement in `scripts/check_agent_continuity.ps1` | WRITE | Job name, step names and `on:` path filters stay byte-identical, so certification expectations and the path agreement are unchanged. The install mirrors ORVION Acceptance's `npm ci` plus `node_modules/.bin/supabase`, which runs on Ubuntu without `setup-node`. The remote run is proven by `-Certify` after push. |
| Misleading `[api]` comment ("When unset, new entities are NOT auto-exposed") | Readers of `supabase/config.toml` | WRITE | The statement is false for the pinned v2.120.0 and is rewritten in Step 2. |
| Project-local CLI stays at 2.120.0 | `package.json`, `package-lock.json`, `npm ci` on another laptop | VERIFY | Out of Scope and unchanged. Step 1 verifies the pin. A fresh clone at `5467328` restored exactly 2.120.0 with `npm ci` on 2026-10-12 and changed no tracked file. `.workstation/manifest.md` records versions as dated evidence, not pins, so it is not edited. |
| Which CLI the `-Finish` run executes | The DATABASE profile's mandatory `npx supabase db reset` and two `npx supabase test db` passes (fixed in `scripts/check_agent_continuity.ps1`, Out of Scope); `npx supabase status -o json` inside each HTTP suite | VERIFY | `-Finish` runs the profile's commands first and then only those Additional Verification lines that are not verbatim copies, so restating or rewording them in this contract cannot replace them. Step 5 runs `-Finish` with `npm_config_offline=true` after checking the project-local version. Tested 2026-10-13: in the repository, offline `npx supabase --version` exits 0 and reports the local 2.120.0; outside it, offline `npx` exits 1 (`cache mode is 'only-if-cached'`) instead of downloading. Both pgTAP passes and their order are unchanged. |
| Manifest active pointer | Boot, Check 7, the generator | WRITE | `ai-map.json` and `repository-index.md` are in Write Scope for `scripts/generate-ai-map.ps1`. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: 5 (`-Finish` runs the local `db reset` only after Step 4 records exclusive use and a pre-reset dump whose host copy `pg_restore -l` has validated, and after Step 5 re-validates it)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Working tree is clean and the branch is not behind its upstream | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| ORVION stack has no other user, local data is dumped and its host copy validated by `pg_restore -l`, and no other project is affected, continuously through `-Finish` | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | 5 |
| Config, CI source and a freshly created stack are verified | BEFORE_COMPLETION | 2 | 4 | 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: ORVION Acceptance already installs the CLI with `npm ci` and calls only `node_modules/.bin/supabase`, and its comment explains why a second `uses:` pin is a defect. `migration-ci.yml` runs the same four database steps but kept `supabase/setup-cli` pinned to 2.109.1. No new control is added; the existing workflow reuses the existing mechanism.

Added Property: Both CI database lanes and local `-Finish` run one CLI version, the one `package-lock.json` resolves.

Causal Negative: Already reproduced with an identical `supabase/**` tree. `5a32f5b` and `5467328` differ only in package and contract files. With the lockfile's 2.109.0, ORVION Acceptance passed (run 38273853547). With 2.120.0, it failed pgTAP 155 #68 (run 38305453692). `migration-ci.yml`, pinned to 2.109.1, would have reported green on a tree the lockfile CLI fails.

Positive Test Design: After push, Migration CI runs on the promoted SHA because `supabase/config.toml` changed. `npm ci`, `node_modules/.bin/supabase start`, `db reset`, `test db` and the smoke test all succeed.

Negative Test Design: With the second authority removed, a version mismatch cannot arise. If `npm ci` did not provide the executable, `node_modules/.bin/supabase start` exits non-zero instead of fetching another version. Review searches the workflow for `supabase/setup-cli` and expects no match.

Non-Empty Population Obligation: `migration-ci.yml` has four CLI invocations (`start`, `db reset`, `test db`, `stop`). All four must read `node_modules/.bin/supabase`, and the file must contain `npm ci` exactly once.

Mutation Obligation: Re-adding a `uses: supabase/setup-cli` step, or reverting any of the four invocations to bare `supabase`, falsifies Acceptance Criterion 3. The independent Review checks that criterion against the file.

Post-Implementation Proof Obligation: The certified `-Finish` passes the full DATABASE protocol. After push, `-Certify` proves ORVION Acceptance on the candidate, and Migration CI plus the other required workflows on the promoted SHA.

## Implementation Steps

1. Check whether `package.json` declares `"supabase": "2.120.0"`, `package-lock.json` resolves `node_modules/supabase` to `2.120.0`, and `node_modules/.bin/supabase.cmd --version` reports `2.120.0`. If all three match, record Already Applied. Otherwise stop and report the mismatch without any write; this contract does not modify either package file.
2. Check whether `supabase/config.toml` already contains BOTH target blocks below byte-for-byte: the six-line `[api]` block of (a), ending `auto_expose_new_tables = false`, and the three-line block of (b) directly under `[analytics]`, ending `enabled = false`, with each corrected comment present. Only if both blocks match exactly, record Already Applied. If both settings match but either comment differs, or only one block matches, stop and report the discrepancy; do not guess. Otherwise make exactly these two edits and nothing else.

   (a) In `[api]`, replace the six consecutive lines from the line starting `# Controls whether new tables` through the line `# auto_expose_new_tables = true` (lines 19–24 at `3c93c1c`) with these six lines:

   ```toml
   # Controls whether new tables, views, sequences and functions created in the `public` schema by
   # `postgres` are reachable through the Data API roles (`anon`, `authenticated`, `service_role`)
   # without explicit GRANTs. Pinned to `false` (default-deny): every exposure is an explicit GRANT in
   # a migration. Do not leave it unset: CLI v2.109.0 read unset as `false`, but the pinned v2.120.0
   # reads unset as `true` and keeps the legacy grants (SPEC-272). `true` is deprecated upstream.
   auto_expose_new_tables = false
   ```

   (b) In `[analytics]`, replace the single line `enabled = true` with these three lines:

   ```toml
   # Disabled (SPEC-272): nothing in ORVION reads local Logflare or Vector, and on Windows Docker
   # Desktop the CLI reaches the daemon for Vector only through an unauthenticated tcp://:2375.
   enabled = false
   ```

   Keep `port = 54327`, `backend = "postgres"` and every other line byte-identical. Confirm with `git diff -- supabase/config.toml` that only these two hunks changed.
3. Check whether `.github/workflows/migration-ci.yml` contains `run: npm ci` exactly once, contains no `supabase/setup-cli`, and runs the CLI in exactly four places, all as `node_modules/.bin/supabase` (`start`, `db reset`, `test db`, `stop || true`), with no bare `run: supabase` line left. Only if all of this holds, record Already Applied. If it holds only in part, stop and report the discrepancy. Otherwise replace the five-line comment block that starts `Pin an explicit CLI version` together with the following `Set up Supabase CLI` step (its `uses:`, `with:` and `version: 2.109.1` lines) with these lines, at the existing step indentation:

   ```yaml
   # The Supabase CLI is the lockfile's, installed by `npm ci` exactly as ORVION Acceptance does.
   # A `uses:` pin here was a second version authority: it stayed at 2.109.1 after the lockfile
   # moved to 2.120.0, so the two CI database lanes tested different CLIs (SPEC-272).
   - name: Install pinned toolchain
     run: npm ci
   ```

   Then change `run: supabase start`, `run: supabase db reset`, `run: supabase test db` and `run: supabase stop || true` to use `node_modules/.bin/supabase` in place of `supabase`. Keep `name`, `on:`, the path filters, the job and every step name byte-identical.
4. Check whether an Execution Log entry records a start by the project-local v2.120.0 executable after Step 2, with the same current container IDs, no `supabase_vector_ORVION` or `supabase_analytics_ORVION` container, every remaining ORVION container running, and healthy where it has a healthcheck. Record Already Applied only if all of this still matches the live state. Otherwise establish exclusive use of the ORVION stack: `pg_stat_activity` on `supabase_db_ORVION` shows no client backend other than the check itself, no other agent or job is using the stack, and no other project's Docker resources are touched. If exclusivity is unproven, record a blocker and stop without touching the stack. Then protect local data before any container is stopped. Run each command on its own, read `$LASTEXITCODE` directly after it, and never pipe a command's output into `Select-Object -First`, which ends the pipeline early and loses the exit code. If any command below exits non-zero, or a condition is false, record a blocker and stop without `stop`, `start`, `db reset` or `-Finish`:
   - create `$env:LOCALAPPDATA\ORVION` if it is absent;
   - run `docker exec supabase_db_ORVION pg_dump -U postgres -d postgres -Fc -f /tmp/spec-272-pre-reset.dump` and require exit 0;
   - run `docker cp supabase_db_ORVION:/tmp/spec-272-pre-reset.dump "$env:LOCALAPPDATA\ORVION\spec-272-pre-reset.dump"`, require exit 0, and require the host file to exist with a length greater than zero;
   - validate the HOST copy with PostgreSQL tools that match the server: set `$img` to the output of `docker inspect supabase_db_ORVION --format '{{.Config.Image}}'`, then run `docker run --rm -v "$env:LOCALAPPDATA\ORVION:/backup:ro" --entrypoint pg_restore $img -l /backup/spec-272-pre-reset.dump`. Require exit 0 and a table of contents whose header names `dbname: postgres`. A non-empty file alone is not sufficient.

   Record in the Execution Log: each command above, its exit code, the backup's full host path, its size in bytes, the image used for validation, and the validation result (exit code and table-of-contents line count). Then record the ORVION container IDs, then run `node_modules/.bin/supabase.cmd stop --project-id ORVION` (no `--all`, no `--no-backup`) and `node_modules/.bin/supabase.cmd start`. Confirm every expected container was recreated (new IDs), that no `supabase_vector_ORVION` or `supabase_analytics_ORVION` container exists, and that every remaining container is running, healthy where it has a healthcheck. Record command exit codes, IDs, health and the dump size. Do not patch containers manually, and do not change Docker's TCP exposure.
5. Check whether the Runtime Checkpoint already reads `Resume Step: DONE`; if so, record Already Applied. Otherwise confirm Steps 1–4 succeeded, synchronize the Execution Log and Runtime Checkpoint to `DONE`, and commit the implementation and checkpoint together. Immediately before `-Finish`, do all of the following, and stop before `-Finish` if any of them fails:
   - reconfirm exclusive stack use, and keep the stack exclusive until every verification command completes;
   - re-run the Step 4 `pg_restore -l` validation of the host copy and require exit 0;
   - require `node_modules/.bin/supabase.cmd --version` to report `2.120.0`.

   Then, in the same PowerShell process, set `$env:npm_config_offline = 'true'` and run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish`. Every `npx supabase` that `-Finish` runs (the DATABASE profile's `db reset` and both pgTAP passes, and `npx supabase status` inside each HTTP suite) then resolves only to the installed project-local 2.120.0, or fails closed instead of fetching another version. Record the setting, the version check and the `-Finish` result. If any test fails, preserve its real exit code and evidence and follow bounded recovery without weakening any assertion.

## Acceptance Criteria

- [x] `package.json` and `package-lock.json` are byte-identical to `3c93c1c` and pin `supabase` to `2.120.0`, and `node_modules/.bin/supabase.cmd --version` reports `2.120.0`.
- [x] `supabase/config.toml` sets `auto_expose_new_tables = false` under `[api]` and `enabled = false` under `[analytics]`. Its diff from `3c93c1c` contains only those two settings and their comments, and no comment in it states a default the pinned CLI does not have.
- [x] `.github/workflows/migration-ci.yml` contains no `supabase/setup-cli`, contains `npm ci` exactly once, and invokes the CLI in all four places only as `node_modules/.bin/supabase`. Its `on:` block is byte-identical to `3c93c1c`.
- [x] A newly created ORVION stack started by the project-local executable after Step 2 has no `supabase_vector_ORVION` or `supabase_analytics_ORVION` container. Every other ORVION container was recreated and is running, healthy where it has a healthcheck, without a manual patch or port 2375.
- [x] After the local reset, `pg_default_acl` for role `postgres` on tables in `public` reads `postgres=arwdDxtm/postgres,service_role=Dxtm/postgres`.
- [x] The tracked implementation diff touches only Write Scope: no migration, test, application, package, workstation or other workflow file changes.

## Execution Log

### 2026-10-13 01:18 — Claude

Outcome: Complete

Step results:
- Step 1: Already Applied. `package.json` declares `2.120.0`, the lock resolves `node_modules/supabase` to `2.120.0`, and `node_modules/.bin/supabase.cmd --version` reports `2.120.0`. Both package files are identical to `3c93c1c`.
- Step 2: Applied. Neither target block was present, so each old block matched exactly once and was replaced. `git diff -- supabase/config.toml` shows exactly two hunks: the `[api]` comment plus `auto_expose_new_tables = false`, and the `[analytics]` comment plus `enabled = false`. `port = 54327`, `backend = "postgres"` and CRLF line endings are unchanged.
- Step 3: Applied. `migration-ci.yml` now contains `run: npm ci` once and `supabase/setup-cli` zero times. All four CLI calls (`start`, `db reset`, `test db`, `stop || true`) use `node_modules/.bin/supabase`, and no bare `run: supabase` remains. The `on:` block is byte-identical to `3c93c1c`, as are the job and step names other than the replaced install step. CRLF is preserved. No YAML parser is installed locally, so the CI profile's remote run proves the syntax.
- Step 4: Applied.
  - Exclusivity. `pg_stat_activity` showed no non-idle client backend other than the check; the 23 idle ones are the stack's own service pools. No process was running a `supabase`, `verify_*`, `pg_prove` or Gate command. `ORVION` was the only running Supabase project. The Codex desktop app was open but drove nothing against the stack.
  - Backup. `docker exec supabase_db_ORVION pg_dump -U postgres -d postgres -Fc -f /tmp/spec-272-pre-reset.dump` exited 0. `docker cp` to `C:\Users\My Lab\AppData\Local\ORVION\spec-272-pre-reset.dump` exited 0, giving 2586200 bytes with SHA-256 `5810f90e75e0e736b3384ee248a083c332b3f9c3ca8dc35c6375e93de8838c87`. The host copy was validated with `docker run --rm -v "C:\Users\My Lab\AppData\Local\ORVION:/backup:ro" --entrypoint pg_restore public.ecr.aws/supabase/postgres:17.11.0.004 -l /backup/spec-272-pre-reset.dump`: exit 0, a 2961-line table of contents, header `dbname: postgres`, and 133 `TABLE DATA` entries.
  - Before stop, 12 containers: analytics `6c24beb92a4c`, auth `0a385fb2e499`, db `8da6178c5f2e`, edge_runtime `54d34da1d045`, inbucket `99be30387f98`, kong `5abc511ba46f`, pg_meta `f0419f29288b`, realtime `713ec4803e2e`, rest `6639057fc9aa`, storage `de4138d53268`, studio `35591b2765dc`, vector `7cf25140fb7b`.
  - `node_modules/.bin/supabase.cmd stop --project-id ORVION` exited 0 with backup kept, leaving 0 containers. `node_modules/.bin/supabase.cmd start` exited 0.
  - After start, 10 containers, each with a new ID and running: auth `421a6355c1dc` healthy, db `87bb106031ce` healthy, edge_runtime `3495df0bc21b` (no healthcheck), inbucket `162ecb4aba18` healthy, kong `f27cab589d47` healthy, pg_meta `f62d58a94cce` healthy, realtime `50e4a16b8a16` healthy, rest `5f20aa1d6af3` (no healthcheck), storage `68e900baadcd` healthy, studio `a93914ac0bac` healthy. No `supabase_vector_ORVION` or `supabase_analytics_ORVION` exists, and `supabase status` lists both as stopped services. Nothing listens on port 2375. No container was patched.
- Step 5: Applied. The Runtime Checkpoint is synchronized to `DONE` and committed with the implementation. `-Finish` follows offline, after re-validating the backup and the CLI version.

Commits: the implementation and checkpoint commit that carries this entry.

## Verification Notes

### 2026-10-13 01:31 — Claude (Independent Review of `4343b15`)

Verdict: Confirmed Complete

Findings: re-checked against the live repository and runtime after `-Finish`, not against the Execution Log.

1. **Criterion 1.** `git diff --quiet 3c93c1c HEAD -- package.json package-lock.json` exits 0. `package.json`, the lock entry `node_modules/supabase` and `node_modules/.bin/supabase.cmd --version` each read `2.120.0`.
2. **Criterion 2.** `git diff -U0 3c93c1c HEAD -- supabase/config.toml` has two hunks: the `[api]` comment rewrite with `auto_expose_new_tables = false`, and the `[analytics]` comment with `enabled = false`. The old "When unset, new entities are NOT auto-exposed" text is gone.
3. **Criterion 3.** `migration-ci.yml` has `run: npm ci` once and `supabase/setup-cli` zero times. All four CLI calls use `node_modules/.bin/supabase` (`start`, `db reset`, `test db`, `stop || true`), and no bare `run: supabase` remains. Everything before `jobs:` is byte-identical to `3c93c1c`.
4. **Criterion 4.** There is no `supabase_vector_ORVION` or `supabase_analytics_ORVION` container. Ten ORVION containers are running. Auth, db, inbucket, kong, pg_meta, realtime, storage and studio are healthy. Rest and edge_runtime have no configured healthcheck and show 0 restarts. Nothing listens on port 2375. Step 4 recorded recreation with new IDs, and `db reset` later recreated db again (`5c53e77dc02f`).
5. **Criterion 5.** `pg_default_acl` for `postgres` on tables in `public` reads `postgres=arwdDxtm/postgres,service_role=Dxtm/postgres`, and `has_table_privilege('service_role','public.payment_allocations','DELETE')` is false.
6. **Criterion 6.** `git diff --name-only 3c93c1c HEAD` lists exactly `.github/workflows/migration-ci.yml`, `_ORVION_CANONICAL/manifest.md`, `ai-map.json`, `supabase/config.toml` and this contract. The migrations, tests, packages, `.workstation/**`, the other workflows and the control scripts are untouched.
7. **Local certification.** `-Finish` at `4343b15` ran with `npm_config_offline=true` after the backup was re-validated (`pg_restore -l` exit 0, SHA-256 `5810f90e…8c87`) and the CLI version was checked. Every mandatory and additional command passed: `npx supabase db reset`, pgTAP Pass A, the six HTTP suites, pgTAP Pass B after them, `verify_database.sql` (in the suite slot and again in its protocol position), `check_database_parity_evidence.ps1`, `check_repository_consistency.ps1`, `git diff --check` and `npm ls supabase --depth=0`. Result: `LOCAL_CERTIFY: READY`, 7.5 min, `concurrent=0`.
8. **Supersedes.** `changes/SPEC-271-upgrade-project-local-supabase-cli-to-2-120-0.md` is `Cancelled` at `3c93c1c` and is unchanged here.
9. **No new architectural decision.** Both settings restore the behaviour certified under v2.109.0, and `migration-ci.yml` reuses ORVION Acceptance's existing install mechanism. The owner authorized completion in advance (Gate 2, 2026-10-13).

Recommendation to human: Set Status to Complete (performed by the executing agent under the owner's advance Gate 2 authorization and `CR_LIFECYCLE.md` §5).

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **Alternative kept, not adopted.** A standalone Linux v2.120.0 binary running inside Ubuntu WSL2 (project `supabase-vector-probe`, 2026-10-13) recreated a healthy Vector, `c7ba553b0c17`, with a read-only `/var/run/docker.sock` bind and no port 2375. Adopting it would add a second, Linux-side toolchain outside the lockfile, and it does not address the grant regression. It stays available if local Analytics is ever needed.
- **Separate security assessment, out of this contract.** Primary grants `service_role` DELETE (and the legacy defaults) on every `public` table, while pgTAP 155 #68 asserts no API role can delete an allocation. That divergence predates this work. It needs its own explicitly scoped assessment and owner decision; nothing here changes Primary grants or keys.
- **Recorded, not repaired here.** Migration CI's re-run on `main` duplicates ORVION Acceptance (backlog CI-2). Removing it would reach remote certification and control scripts, so this contract only removes its second CLI pin.
- **Why Additional Verification lists no `npx` line.** The DATABASE protocol (`db reset`, pgTAP Pass A, the HTTP suites, pgTAP Pass B, the smoke test) is derived mandatory and lives in `scripts/check_agent_continuity.ps1`. Lines that copy it verbatim are de-duplicated and add nothing. Rewriting them as `node_modules/.bin/supabase.cmd …` would make them extra commands that run after the smoke test: a third reset and two back-to-back pgTAP passes, while the profile's `npx` calls still run. The no-network guarantee is therefore given by Step 5's offline `-Finish`, which also covers the HTTP suites' own `npx supabase status`. Changing the profile's command text is a separate CONTROL change.
- **Backup validation, measured 2026-10-13** on a disposable container of the same image (`public.ecr.aws/supabase/postgres:17.11.0.004`), with a host path containing spaces. `pg_restore -l` on the host copy exited 0 with a 188-line table of contents. A corrupt file and a missing file each exited 1. A pipeline truncated by `Select-Object -First` had reported 0, which is why Step 4 forbids it.
- **Upstream.** The v2.120.0 TypeScript `applyApiPrivileges` reads unset as `true` (`Option.getOrElse(..., () => true)`), contradicting the v2.109.0 Go behaviour and the CLI's own comment. Upstream `main` is unchanged as of 2026-10-12.
