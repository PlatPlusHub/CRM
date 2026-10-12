# Change Request — SPEC-271

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[x] Cancelled

## Objective

Upgrade the project-local Supabase CLI to exactly v2.120.0 and prove that ORVION's local stack and database verification still work.

## Business Reason

The project currently declares and runs Supabase CLI v2.109.0. The owner requested a bounded upgrade to v2.120.0 without changing application dependencies or local infrastructure configuration.

## Risks

The new CLI may change local container creation, especially Vector's Docker socket mount. A fresh local database reset destroys local data. Execution must stop unless the shared project-local npm installation is free for the update, the ORVION stack is exclusively available, and its local data is confirmed disposable or protected. Exclusive stack use must continue through `-Finish`.

## Supersedes / Depends On

None.

## Write Scope

- `package.json`
- `package-lock.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/config.toml`
- `supabase/seed.sql`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `changes/TEMPLATE.md`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md` §§1–4
- `package.json`
- `package-lock.json`
- `supabase/config.toml`

## Runtime Checkpoint

Resume Step: 2
Blocker: VECTOR_SOCKET_MISSING
Recovery Attempt: 2

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- `npm ls supabase --depth=0`
- `npx supabase db reset`
- `npx supabase test db`
- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_care_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_storage_end_to_end.ps1`
- `npx supabase test db`
- `Get-Content -Raw scripts/verify_database.sql | docker exec -i supabase_db_ORVION psql -v ON_ERROR_STOP=1 -U postgres -d postgres -f -`

## Pre-Approval Evidence

Change Class: Routine

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Project-local Supabase CLI changes from 2.109.0 to 2.120.0 | npm lockfile and executable; local stack, migrations, pgTAP and HTTP suites | VERIFY | `npm ls supabase --depth=0` and the executable currently report 2.109.0; the lockfile currently resolves `node_modules/supabase` to 2.109.0. The listed verification exercises the actual new executable and database paths. The two `test db` commands are distinct Pass A after reset and Pass B after the HTTP suites, matching `ENGINEERING_METHOD.md` §4. |
| CR lifecycle updates the manifest's active pointer and completion state | Boot, Check 7, generated projections | WRITE | `ai-map.json` and `repository-index.md` are in Write Scope for the existing generator and consistency check. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: 3 (Finish runs the local reset only after Step 2 establishes exclusive use and data protection)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Working tree and upstream are clean and synchronized | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Shared npm installation has no dependent active process | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Existing stack has no other user, local data is protected, and no other project is affected, continuously through Finish | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | 2 |
| New CLI, fresh-start runtime, migrations and tests are verified | BEFORE_COMPLETION | 1 | 2 | 3 |

## Implementation Steps

1. Check whether `package.json` declares `supabase` as exactly `2.120.0`, `package-lock.json` resolves `node_modules/supabase` to `2.120.0`, and `node_modules/.bin/supabase.cmd --version` reports `2.120.0`; if all three match, record Already Applied. Otherwise confirm that no other active process or work session depends on the shared project-local npm installation; process counts alone do not establish this. If exclusive use is unproven, stop before npm writes. Then run `npm install --save-dev --save-exact supabase@2.120.0` from the repository root. Confirm those three values and inspect `git diff` to ensure only `package.json` and `package-lock.json` changed and the `@supabase/ssr` and `@supabase/supabase-js` declarations and resolutions did not change. Stop on any unexpected change.
2. Check the installed project-local CLI and current Docker container IDs against an Execution Log entry that records a fresh start using exactly v2.120.0, those same resulting IDs and creation times, healthy required services, and Vector's inspected Docker socket mount; record Already Applied only if all still match. A version check or an old log alone is insufficient. Otherwise establish exclusive use of the ORVION stack, protection or disposability of its local data, and no interference with another project's Docker resources; keep that exclusive window open through Step 3 and `-Finish`. If any condition is unproven, record a blocker and stop without touching the stack. Record the pre-start ORVION container IDs, then use the project-local CLI's supported `stop` (without `--all` or `--no-backup`) and `start` commands. Confirm the expected ORVION containers were created or recreated by comparing IDs and creation times; confirm required health; inspect Vector's effective `.Mounts` for a read-only bind from `/var/run/docker.sock` to `/var/run/docker.sock` and confirm the socket exists inside Vector. Record actual command exit codes, IDs, health, and mount results. Do not patch Docker containers manually.
3. Check whether the Runtime Checkpoint already reads `Resume Step: DONE`; if so, record Already Applied. Otherwise confirm Steps 1 and 2 succeeded, synchronize the CR's Execution Log and Runtime Checkpoint to `DONE`, and commit the coherent execution boundary. Immediately before `-Finish`, reconfirm exclusive stack use and data protection, and keep the window exclusive until the reset and every verification command completes; stop before `-Finish` if either condition is unproven. Run `-Finish` only after this committed checkpoint; it executes the derived REPOSITORY profile and Additional Verification commands. If any test fails, preserve its real exit code and evidence and follow the bounded recovery rule without weakening a check.

## Acceptance Criteria

- [ ] `package.json` pins `supabase` to `2.120.0`, and `package-lock.json` resolves it to `2.120.0` while preserving the two application Supabase dependency declarations and resolutions.
- [ ] The project-local executable reports `2.120.0`.
- [ ] A newly created ORVION local stack started by that executable has healthy required containers and Vector's working Docker socket mount without a manual patch.
- [ ] The tracked implementation diff contains no application, SQL, Docker, CI or workstation changes.

## Execution Log

### 2026-10-12 22:42 — Codex

Outcome: Blocked

Step results:
- Step 1: Applied — `npm install --save-dev --save-exact supabase@2.120.0` exited 0; declaration, lock, installed package, and project-local executable each report 2.120.0. Only `package.json` and `package-lock.json` changed; `jose` 6.2.12 satisfies the new CLI's `^6.2.10` requirement. The lockfile root name was preserved as `ORVION`.
- Step 2: Failed — project-specific `stop --project-id ORVION` exited 0 with backup enabled; project-local v2.120.0 `start` exited 0 and recreated all twelve ORVION containers, but new Vector `7cf25140fb7b` (created 2026-10-12 22:40:54 EEST) is restarting and unhealthy. Its effective `.Mounts` is `[]`, `DOCKER_HOST` is `http://host.docker.internal:2375`, and its logs report connection refused at `192.168.65.254:2375`. The socket probe inside Vector exited 1 because the container was restarting. The old Vector `d1af37046680` was healthy with a read-only `/var/run/docker.sock` bind. No manual Docker patch was made.
- Step 3: Failed — not attempted because Step 2 did not satisfy the required runtime invariant; `-Finish` and post-upgrade database tests were not run.

Commits: `5467328` (dependency and Step-2 checkpoint)

Blocker: The supported v2.120.0 start created Vector without the required Docker socket bind and selected an unavailable TCP endpoint instead. Correcting Docker/container configuration is outside this Change Request's approved Write Scope and forbidden by its Implementation Steps; runtime compatibility remains unproven.

### 2026-10-12 23:40 — Claude

Outcome: Blocked (Recovery Attempt 2: history, live runtime and upstream source)

Step results:
- Step 1: Verified — `package.json` pins `2.120.0`; the lock changes only the `supabase` CLI package family; `@supabase/ssr` 0.12.0 and `@supabase/supabase-js` 2.110.0 are unchanged; `node_modules/.bin/supabase.cmd --version` reports 2.120.0.
- Step 2: Blocked — re-inspected live: eleven ORVION containers are up and Vector `7cf25140fb7b` has `.Mounts` `[]`, `DOCKER_HOST=http://host.docker.internal:2375` and RestartCount 12. The Docker context is `desktop-linux` (`npipe`), `ExposeDockerAPIOnTCP2375` is false, and nothing listens on port 2375.
- Step 3: Not attempted.

Root cause: Criterion 3 cannot be satisfied by a Windows-native CLI start, in either version. For an `npipe` daemon host, v2.109.0 (`apps/cli-go/internal/start/start.go`, `case "npipe"`) and v2.120.0 (`apps/cli/src/commands/start/services/vector.service.ts`, `resolveVectorDockerSocketPlan`) both set `DOCKER_HOST=http://host.docker.internal:2375` and create no bind. v2.109.0 prints "Analytics on Windows requires Docker daemon exposed on tcp://localhost:2375". Upstream `main` is unchanged. The upgrade introduced no regression.

The socket-bound Vector `d1af37046680` was not created by the CLI. A Codex session on 2026-10-12, 21:17–21:20 EEST, created `supabase_vector_ORVION_repair_probe` with a manual read-only `/var/run/docker.sock` bind and renamed it into place. Before that, `reports/history` records Vector restarting continuously from 2026-08-21 to 2026-09-09. The Pre-Approval baseline was therefore a manual patch.

The Consumer Closure missed one consumer: `.github/workflows/migration-ci.yml` pins `supabase/setup-cli` to 2.109.1.

Remote acceptance of `5467328` (run 38305453692, Ubuntu, a fresh `db reset` with v2.120.0): the Gate, mutation suite and guard attack pass, and every migration applies. pgTAP fails 1 of 2969 tests: `155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql` #68 reports `service_role` DELETE on `public.payment_allocations` as `true`. Root cause is an upstream regression. With `[api].auto_expose_new_tables` unset, v2.109.0 (`ApplyApiPrivileges`) revokes the Data API default privileges for `postgres` in `public`. v2.120.0 (`apps/cli/src/command-internal/db-bootstrap/db-setup.ts`, `applyApiPrivileges`, `Option.getOrElse(..., () => true)`) skips that revoke. Upstream `main` is unchanged. The two bundled Postgres images, 17.6.1.140 and 17.11.0.004, ship identical default ACLs, so the image change is not the cause. Primary, read-only: `service_role` already holds DELETE on all 78 `public` tables, so test 68 matches the old local stack but not Primary.

No repair exists inside this contract. Exposing port 2375 is forbidden. A manual container patch is excluded by Criterion 3. Setting `[analytics] enabled = false` in `supabase/config.toml` is Out of Scope, and it removes Vector, so Criterion 3 still could not be true. The stack was not touched, and Docker was not reconfigured.

### 2026-10-13 — Cancelled by human command before Complete

- **The owner's decision of 2026-10-13:** cancel this blocked contract through the canonical lifecycle and prepare one narrowly scoped successor Draft (Option A). That Draft keeps project-local CLI 2.120.0, sets `[analytics] enabled = false` once evidence shows nothing in ORVION depends on local Supabase Analytics or Vector, and sets `[api] auto_expose_new_tables = false`. It does not waive its own approval gate and does not modify Primary.
- **The defect.** Criterion 3 is false as written. A Windows-native CLI start cannot create a socket-bound Vector, and the baseline it described was a manual patch. A fresh v2.120.0 database also fails pgTAP 155 #68. Both findings are in the Execution Log and Verification Notes above.
- **Alternative evidence kept for the record.** A standalone Linux v2.120.0 binary running inside Ubuntu WSL2 (isolated project `supabase-vector-probe`) recreated a healthy Vector, `c7ba553b0c17`, with a read-only `/var/run/docker.sock` bind and no port 2375. That binary is not this contract's lockfile-pinned project-local executable, and it does not affect the pgTAP regression. It remains a possible future alternative, not an ORVION dependency.
- **Preserved:** every commit of this contract (`1975890`, `303bb9c`, `7718f01`, `4ad937f`, `5467328`) and all of its evidence. Nothing is rewritten. The 2.120.0 pin is carried forward to the successor as Already Applied.

## Verification Notes

### 2026-10-12 — Independent Review of the In Progress execution at `5467328`

Verdict: Needs Corrective Change Request

1. Criterion 1: true (see the Step 1 result above).
2. Criterion 2: true. The executable reports 2.120.0, but its fresh `db reset` no longer revokes the Data API default privileges (see the Execution Log). Pinning `[api] auto_expose_new_tables = false` in `supabase/config.toml` restores the v2.109.0 behaviour, and that file is Out of Scope here.
3. Criterion 3: false. It cannot be met on a Windows Docker Desktop host without exposing an unauthenticated daemon or patching a container manually.
4. Criterion 4: true. `5a32f5b..5467328` changes only `package.json`, `package-lock.json`, `_ORVION_CANONICAL/manifest.md`, `ai-map.json` and this contract.

Completing the upgrade needs a human decision: cancel this contract, then approve a replacement whose criterion matches what the supported CLI does on this platform.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.
