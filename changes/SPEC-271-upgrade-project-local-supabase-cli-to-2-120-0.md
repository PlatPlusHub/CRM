# Change Request — SPEC-271

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

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
Blocker: None
Recovery Attempt: 0

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

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.
