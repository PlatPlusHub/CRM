# Change Request — SPEC-297

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Move the project-local Supabase CLI from 2.120.0 to 3.0.0 and set the two auth provider switches with the keys 3.0.0 reads, keeping the certified local stack behaviour unchanged.

## Business Reason

The owner instructed on 2026-11-08 to adopt Supabase CLI 3.0.0 and fix what it shows before Batch 6 continues. `package-lock.json` is the one CLI version authority since SPEC-272: local `npx supabase`, `-Finish`, Migration CI and ORVION Acceptance all run the CLI that `npm ci` installs from it, so one pin moves every lane together. CLI 3.0.0 deprecates `[auth.email] enable_signup` and `[auth.sms] enable_signup` (warned now, removed in v4); their v3 keys are `enabled`, and the generated GoTrue environment is identical before and after. The `[api]` comment calls v2.120.0 "the pinned" version, which stops being true with this change.

## Risks

The DATABASE protocol of `-Finish` resets the local ORVION database; local data is disposable test residue, and every DATABASE Finish already resets it. The stack running before this change was created by 2.120.0, so before `-Finish` the operator runs `npm ci` and recreates the stack with the project-local 3.0.0 (`supabase stop`, then `supabase start`); this is an operating precondition outside the literal steps, recorded in the Review. If `npm ci` did not install 3.0.0, Additional Verification `npm ls supabase --depth=0` fails instead of passing on another version. Hosted CI installs 3.0.0 through the same lockfile; its result is POST_PUSH evidence for the separately governed publication, never claimed here. 3.0.0 `db reset` prints one JSON status line on stdout; no tracked script parses that output. Primary (hosted) is untouched: nothing links, pushes or changes remote configuration. Gate 1 of this contract is DELEGATED under the owner's instruction of 2026-11-08 and the owner's standing approval of proposals of the same day, never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `package.json`
- `package-lock.json`
- `supabase/config.toml`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/verify_database.sql`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`
- `changes/TEMPLATE.md`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `package.json`
- `supabase/config.toml`
- `changes/SPEC-272-the-pinned-cli-keeps-the-certified-local-stack.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local

## Additional Verification

- `npm ls supabase --depth=0`
- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_care_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_storage_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: SPEC-297-V1 changes only the pin (`package.json` and the lockfile entries `npm install` wrote for 3.0.0: the CLI and its eight platform packages), the two provider keys with the v3 template comments, and one stale word in the `[api]` comment; the DATABASE protocol of `-Finish` plus the six HTTP suites prove the stack.

Pass 2 Adversarial Review: SPEC-297-V2 challenged each part. Keeping the deprecated keys was rejected: 3.0.0 warns on every command and v4 removes them. Replacing them with `[auth] enable_signup` was rejected: in v3 that key blocks signups for every provider, while `[auth.email] enabled` / `[auth.sms] enabled` switch the provider; the isolated stack produced the same GoTrue environment as 2.120.0 (`EXTERNAL_EMAIL_ENABLED=true`, `EXTERNAL_PHONE_ENABLED=false`, `DISABLE_SIGNUP=false`). `npm install` rewrote the lockfile root `name` to the folder name; that hunk is excluded, so the lockfile diff holds only 3.0.0 entries. A pre-reset dump (SPEC-272) was rejected as cost without value: the local data is disposable and the stack was rebuilt on 2026-11-08. The ORVION evaluator's deprecated `--local` flag lives in a control file and is a separate change before v4.

Pass 3 Evidence Refresh: 2026-11-08. SPEC-297-V3 re-ran the full DATABASE protocol on an isolated clone with the project-local 3.0.0 (own project id and ports, push disabled): `db reset`, pgTAP pass A, the six HTTP suites, pgTAP pass B, `verify_database.sql` and the parity evidence, all passing with parity CLEAN; re-read the v3 `config.toml` template for the provider-key comments, the profile mapping (`supabase/config.toml` derives DATABASE; the package files derive none) and SPEC-272 (one CLI version authority; CI installs from the lockfile). The exact sandbox native lifecycle must pass before the original delegated approval.

Selected Version: SPEC-297-V3; selected: the smallest change that moves the one CLI version authority to 3.0.0 and removes its only deprecation warnings, proven by the full DATABASE protocol in isolation

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Project-local CLI 2.120.0 becomes 3.0.0 | `npm ci` locally, in Migration CI and in ORVION Acceptance | WRITE | One lockfile authority (SPEC-272); both workflows call `node_modules/.bin/supabase` and stay byte-identical; hosted runs prove the runner after publication |
| Which CLI `-Finish` executes | DATABASE profile `npx supabase db reset` / `test db`, and `npx supabase status` inside each HTTP suite | VERIFY | After `npm ci`, `npx` resolves the project-local 3.0.0; Additional Verification `npm ls supabase --depth=0` fails on any other version |
| `[auth.email]` / `[auth.sms]` `enable_signup` become `enabled` | Local GoTrue configuration | WRITE | Same GoTrue environment before and after in the isolated stack; `[auth] enable_signup = true` unchanged |
| `auto_expose_new_tables = false` read by 3.0.0 | pgTAP grant-model tests | VERIFY | Isolated 3.0.0 `db reset` and `test db`: every pgTAP file passed |
| `[api]` comment naming v2.120.0 the pin | Readers of `supabase/config.toml` | WRITE | Only the words "the pinned" are removed; the SPEC-272 history it states stays true |
| Running local stack created by 2.120.0 | `-Finish` | VERIFY | Recreated by the project-local 3.0.0 before `-Finish`; recorded in the Review |
| `db reset` JSON status line on stdout | Scripts reading CLI output | UNAFFECTED | No tracked script parses `db reset` output; the isolated protocol passed |
| Primary (hosted) project | Remote database and configuration | UNAFFECTED | No tracked script or step links, pushes or changes remote configuration |
| Active task and generated discovery | Native Boot and manifest projections | WRITE | Existing pointer/completion synchronization and native generator only |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Selected bytes and baseline anchors | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Project-local 3.0.0 installed by `npm ci` and the stack recreated by it | BEFORE_COMPLETION | NONE | NONE | NONE |
| Own native profiles and fresh verification | BEFORE_COMPLETION | NONE | NONE | NONE |

## Implementation Steps

1. Check whether `package.json` contains `"supabase": "3.0.0"`; if so record Already Applied when its Git blob is 08e4a0bf21990111d23cb0a29b31b8a72ec92c2d, and otherwise stop and report. Otherwise make exactly this one edit (project-local Supabase CLI pinned to 3.0.0), each matched once, and change nothing else:

   a) replace the line
   ```text
       "supabase": "2.120.0"
   ```
   with
   ```text
       "supabase": "3.0.0"
   ```

   The resulting file's Git blob is 08e4a0bf21990111d23cb0a29b31b8a72ec92c2d.

2. Check whether `package-lock.json` contains `supabase-3.0.0.tgz`; if so record Already Applied when its Git blob is d2a801b4468c06d0148b501b2cdb33fe2ded622a, and otherwise stop and report. Otherwise make exactly these 11 edits (lockfile resolves the CLI and its eight platform packages at 3.0.0; root name unchanged), each matched once, and change nothing else:

   a) replace the line
   ```text
           "supabase": "2.120.0"
   ```
   with
   ```text
           "supabase": "3.0.0"
   ```

   b) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-darwin-arm64/-/cli-darwin-arm64-2.120.0.tgz",
         "integrity": "sha512-GXjW2+J4dGYjbZW0oeDs9y8+Eo/AloRYkbc7LpZmKagc1NYVPzQyviSHZ8LzidCXGlNF3Gds3k8UetjTQQmXbQ==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-darwin-arm64/-/cli-darwin-arm64-3.0.0.tgz",
         "integrity": "sha512-6N/clanDjhKWcPsHBqXcSt7HCZ0bBTjkGGrHgM4834zFu/PBIVBS6u9YJVXxOdQnbwyw/rTwumSYvgwwJgoIug==",
   ```

   c) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-darwin-x64/-/cli-darwin-x64-2.120.0.tgz",
         "integrity": "sha512-o6ISS9smQnNfpws2nqs3e9lxA0UTsWGI9LAvz2zMymRm11Iy8vZIeOXHV8BbGQWtqxLgfiHHCVvBLE9/41AKQA==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-darwin-x64/-/cli-darwin-x64-3.0.0.tgz",
         "integrity": "sha512-e2DKOLIqK82XRp/GSmm0oMXx2CLBSTWJGobro1POPhmn3o+NWRQPI1QvjLFYIeI/9ZfSuo5PUJN4KI9OSjzAng==",
   ```

   d) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-linux-arm64/-/cli-linux-arm64-2.120.0.tgz",
         "integrity": "sha512-pmR61xpBmzUc79gkh3sE42KtBkludBXex1TIQTVY6jkTjs2+JhJYNKxR7udeaFgxFpiV+zTeAyqJBYXLibxQJw==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-linux-arm64/-/cli-linux-arm64-3.0.0.tgz",
         "integrity": "sha512-sjdzBJGa+zfXSxUczRkqAJpuVgE2PFWXJazYxOnrqYWVPiS9Q0e2m06JdUXwZz/GqxKuLuDQN1OyLFu8DLfQDA==",
   ```

   e) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-linux-arm64-musl/-/cli-linux-arm64-musl-2.120.0.tgz",
         "integrity": "sha512-+4IwiBpGOQgLFeEG6RImxSUrMHo+LDsFNGJ4WLoLBOozFaippoz5J6CnNpVSTeJj9QaOX3G9iVsL/wYF6P1Cxw==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-linux-arm64-musl/-/cli-linux-arm64-musl-3.0.0.tgz",
         "integrity": "sha512-Bxe2bggo4dLW6tvlA6Qmjzth3VPGNEzjEaxYZohalP+q4jynov6OE6ibeLEdBtalykDMRbUXQ9j7r1p10RI/hQ==",
   ```

   f) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-linux-x64/-/cli-linux-x64-2.120.0.tgz",
         "integrity": "sha512-IWJ0yFefhX/69ofcgJfN8MyOC9TtCG4SLrlMCvXjH3vZXxnRkiVNggxQqUCIhshS9Afa+q17DRbQen7/IZTL4A==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-linux-x64/-/cli-linux-x64-3.0.0.tgz",
         "integrity": "sha512-cR4S5e3nygMaBShbbt6FOiMumtrFJjwdKMXMimC1y7FpxITlwLv36BveaifQZ8aY+v1u+w8oYANU2H72Y4ibWA==",
   ```

   g) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-linux-x64-musl/-/cli-linux-x64-musl-2.120.0.tgz",
         "integrity": "sha512-YIrqu1+hBiLwYIk1HKesrfIm2ycQIsOfN5VGV3r/okQx8JyWl9Jrw7emKVS/F+1afe+1MqKEBP70B0PbuvX+jQ==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-linux-x64-musl/-/cli-linux-x64-musl-3.0.0.tgz",
         "integrity": "sha512-ANyJ6h2X4HgM8f3PAFLGNH1XzYNho2M4kev/z5Ryq6on3ArI9FA+4KrrUqs1SFGji8E5WGyx/H+CHxmcXf5rTg==",
   ```

   h) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-windows-arm64/-/cli-windows-arm64-2.120.0.tgz",
         "integrity": "sha512-U+IDegKWC4xXxk7aCRUUy2ZTJ4bwwrcVlnzG1VJqC7nB7SLgMiyUMyvuo1tB+Xt8hHf0hkuViNtohnXPdZHCIQ==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-windows-arm64/-/cli-windows-arm64-3.0.0.tgz",
         "integrity": "sha512-Xox3X7BXpe+/X9XpAgo5/Qrv5qtJaItc3gLlAwJ2d2AcGrBnfh4/b0MvbNbyO7I2Fj1c7yrPmMI4lEicVvIGGw==",
   ```

   i) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-windows-x64/-/cli-windows-x64-2.120.0.tgz",
         "integrity": "sha512-y96p4JdUuKygzUDCRo1T8yEiLbyWIiL/4Qdnmgu/X84WJOZmji/TlW5ThqDllsQuGWbkgovy+6LLqWKHk330XQ==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/@supabase/cli-windows-x64/-/cli-windows-x64-3.0.0.tgz",
         "integrity": "sha512-nBfd1Rz8MwstIJXHo5fyIQgjmYgLxDbBIuCmuttYAQwTafc7jUOofIAAUUARkhalHu0kBOEyRuEqe2rfKr/l5w==",
   ```

   j) replace the lines
   ```text
         "version": "2.120.0",
         "resolved": "https://registry.npmjs.org/supabase/-/supabase-2.120.0.tgz",
         "integrity": "sha512-NF8ueHsOZMbyiFJARKbiZy9AhNtj5E5R49P+cVqlv2u/T2JpMtsvp29YgPgrIWkVUjsfhJseTmKEdckatSeWZQ==",
   ```
   with
   ```text
         "version": "3.0.0",
         "resolved": "https://registry.npmjs.org/supabase/-/supabase-3.0.0.tgz",
         "integrity": "sha512-FB+V+RzXYTmCzbchaN3CUdxLPpcKzJd4RSOc/dAE6cAtI7TZE8J5OLJYXjJae9C/fbi2xxzZJLL/Y2N1zbzf9A==",
   ```

   k) replace the lines
   ```text
           "@supabase/cli-darwin-arm64": "2.120.0",
           "@supabase/cli-darwin-x64": "2.120.0",
           "@supabase/cli-linux-arm64": "2.120.0",
           "@supabase/cli-linux-arm64-musl": "2.120.0",
           "@supabase/cli-linux-x64": "2.120.0",
           "@supabase/cli-linux-x64-musl": "2.120.0",
           "@supabase/cli-windows-arm64": "2.120.0",
           "@supabase/cli-windows-x64": "2.120.0"
   ```
   with
   ```text
           "@supabase/cli-darwin-arm64": "3.0.0",
           "@supabase/cli-darwin-x64": "3.0.0",
           "@supabase/cli-linux-arm64": "3.0.0",
           "@supabase/cli-linux-arm64-musl": "3.0.0",
           "@supabase/cli-linux-x64": "3.0.0",
           "@supabase/cli-linux-x64-musl": "3.0.0",
           "@supabase/cli-windows-arm64": "3.0.0",
           "@supabase/cli-windows-x64": "3.0.0"
   ```

   The resulting file's Git blob is d2a801b4468c06d0148b501b2cdb33fe2ded622a.

3. Check whether `supabase/config.toml` contains `# Allow/disallow the phone provider.`; if so record Already Applied when its Git blob is 407043518661d6f3a7c5e2f5d80d803537f3e269, and otherwise stop and report. Otherwise make exactly these 3 edits (v3 provider keys for [auth.email] and [auth.sms], and the [api] comment no longer calls v2.120.0 the pin), each matched once, and change nothing else:

   a) replace the line
   ```text
   # a migration. Do not leave it unset: CLI v2.109.0 read unset as `false`, but the pinned v2.120.0
   ```
   with
   ```text
   # a migration. Do not leave it unset: CLI v2.109.0 read unset as `false`, but v2.120.0
   ```

   b) replace the lines
   ```text
   # Allow/disallow new user signups via email to your project.
   enable_signup = true
   ```
   with
   ```text
   # Allow/disallow the email provider. When false, users can't sign up or sign in with email.
   # To block new signups only, set enable_signup = false under [auth] instead.
   enabled = true
   ```

   c) replace the lines
   ```text
   # Allow/disallow new user signups via SMS to your project.
   enable_signup = false
   ```
   with
   ```text
   # Allow/disallow the phone provider. When false, users can't sign up or sign in with SMS.
   # To block new signups only, set enable_signup = false under [auth] instead.
   enabled = false
   ```

   The resulting file's Git blob is 407043518661d6f3a7c5e2f5d80d803537f3e269.

## Acceptance Criteria

- [ ] Exact scoped source output; `check: blob package.json 08e4a0bf21990111d23cb0a29b31b8a72ec92c2d`
- [ ] Exact scoped source output; `check: blob package-lock.json d2a801b4468c06d0148b501b2cdb33fe2ded622a`
- [ ] Exact scoped source output; `check: blob supabase/config.toml 407043518661d6f3a7c5e2f5d80d803537f3e269`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @df9f1bda82d082cb382da007d6d9c0c2434b5c99`
- [ ] Migration CI remains exact; `check: same .github/workflows/migration-ci.yml @df9f1bda82d082cb382da007d6d9c0c2434b5c99`
- [ ] Independent Review confirms the stack used by `-Finish` was recreated by the project-local 3.0.0 after `npm ci`, and that no hosted result is claimed.

## Execution Log

None.


### 2026-11-08 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was df9f1bda82d082cb382da007d6d9c0c2434b5c99 and every source anchor matched there; Draft allocated as 426ddd6 and approved as 26f86dc with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `package.json` edited exactly as the step states; blob 08e4a0bf21990111d23cb0a29b31b8a72ec92c2d (1 insertions, 1 deletions).
- Step 3 Applied: `package-lock.json` edited exactly as the step states; blob d2a801b4468c06d0148b501b2cdb33fe2ded622a (36 insertions, 36 deletions).
- Step 4 Applied: `supabase/config.toml` edited exactly as the step states; blob 407043518661d6f3a7c5e2f5d80d803537f3e269 (7 insertions, 5 deletions).
- Step 5 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.

## Verification Notes

None.


### 2026-11-08 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instruction of 2026-11-08 (~11:20 Cairo, Supabase CLI 3.0.0 first) and standing approval of proposals (~10:20 Cairo); Draft SHA-256 5503B0867F657EEBD7705EC4C50D9BB9F1AD4F9800A38834E2889FDAB4D03A09, decision SHA-256 ABD7D8AE527D4A97B998F78EC40BE733F3BB291775986D4478D0D4DCC691C294. No fabricated human future-digest approval. Own fresh original native verification/Review/Complete/binding required; sandbox receipt certifies no original. Immediately before allocation the hash, the Draft blob 2554e2f2312ab1a3722b94a2d1fc3e2d0ef6f583, all 3 source anchors, the baseline HEAD df9f1bda82d082cb382da007d6d9c0c2434b5c99 against refreshed origin/main df9f1bda82d082cb382da007d6d9c0c2434b5c99 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 426ddd6. No implementation performed before this transition. Batch 6 remains ON HOLD; CTRL-19 remains OPEN.


Verdict: Confirmed Complete

Independent current Git evidence: selected Draft 5503B0867F657EEBD7705EC4C50D9BB9F1AD4F9800A38834E2889FDAB4D03A09, allocated blob 2554e2f2312ab1a3722b94a2d1fc3e2d0ef6f583, the three literal outputs (package.json and package-lock.json at Supabase CLI 3.0.0 with the lockfile root name unchanged; config.toml with the v3 [auth.email]/[auth.sms] provider keys and the corrected [api] comment), regenerated discovery, unchanged native evaluator and Migration CI, and declared scope verified. Before -Finish, npm ci installed the project-local CLI and the stack was recreated by it (STACK READY: original root C:\Users\My Lab\Documents\GitHub\CRM, CLI 3.0.0, 10 containers). This original root owns fresh receipt d56608cfdcb4711b4c1d1ea87531a676618f214966cede6546fa0688e60bb43b, finishHead cd4df454c9edbc2fe6f9b0a844edc5d9720ccba0, profiles DATABASE,REPOSITORY, in a native timed/watched Finish (npm offline) observed READY/END0, which ran the DATABASE protocol, the six HTTP suites and npm ls supabase as Additional Verification. Native Complete/range/binder still own full receipt/criterion validation. No publication or hosted result asserted. Correction: the Gate 1 and implementation entries above carry a fixed tool sentence that Batch 6 remains ON HOLD; that is stale, the owner lifted the hold on 2026-11-08 (Workbench tool defect, fixed separately).

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-297: project-local Supabase CLI 3.0.0 with the v3 auth provider keys; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. Candidate binding follows Complete and is never a pre-Complete criterion. Publication and promotion follow the native release path separately.

Exact baseline df9f1bda82d082cb382da007d6d9c0c2434b5c99 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `package.json` | `d2b9e035731bbc071a541995ce2bc9f37fe0b4ad` |
| `package-lock.json` | `87980c4ed6d61326d1b590b71c29309a9be9af8c` |
| `supabase/config.toml` | `f40d994133d50ee4f22a4e1a9578722c40fb37a4` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md, SPEC-272 and the Supabase CLI 3.0.0 `config.toml` template at df9f1bda82d082cb382da007d6d9c0c2434b5c99; the owner's instruction and standing approval of 2026-11-08 (recorded outside this repository). Three identified snapshots and selection reasons are retained externally; correctness remains native and independent.

Snapshot identities: V1 4A012E23B95D57A1221B74ADA0000187E7E6277320433E7DBD03C3746643B9A3; V2 1DA0852FC00966C6933A670E70708F9B0D3F62DDFAF89FE0D72DA3D5F056D6EC. V3 adds this linkage and the final selection; its own SHA-256 is external.
