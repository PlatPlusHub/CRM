# Change Request — SPEC-179

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Exclude from the local certification fingerprint exactly the `ai-map.json` values the completion act itself is required to rewrite, so a Change Request that scopes the generated map can reach `Complete`, while every key nothing else guards stays fingerprinted.

## Business Reason

`-Finish` records a fingerprint of the Write Scope's file content, and the local `Complete` Gate refuses the transition if that fingerprint no longer matches. The skip list is `@($Rel,'_ORVION_CANONICAL/manifest.md')` — the governing contract and the manifest — and the doctrine above it states the reason: "including them would make every receipt stale the instant completion began."

`ai-map.json` is the third file in that class and was left out of the list. The completion arm's own comment already names it: "it necessarily rewrites the manifest and the generated `ai-map.json` mirror, which certifying earlier cannot have covered." `Complete` clears `Active Change Request` and replaces `Last Completed` in the manifest, Check 7 requires the generated map to agree with the manifest by value, so regenerating it is mandatory — and regenerating it invalidates the receipt that completion requires. Any contract scoping `ai-map.json` is therefore unable to complete, and the Gate rejects its own mandatory bookkeeping as a changed implementation.

Measured on the real path, not inferred: after a successful `-Finish` returning `LOCAL_CERTIFY: READY`, the legal completion bookkeeping produced `COMPLETION_PREREQUISITE: stale certification receipt - the implementation changed after it was certified`, with `ai-map.json` the only fingerprinted path that had changed (both implementation scripts unmodified, contract and manifest on the skip list) and `REPOSITORY CONSISTENCY: CLEAN` over the same final state. The diff was three lines: `generated_at`, `live_state.active_change_request`, `live_state.last_completed`. The class has now reproduced on two unrelated contracts.

Dropping the file from the fingerprint is refused on evidence. In a clean worktree at the canonical base, `boot_order[0]` and `authority.execution_conduct` were rewritten to name files that do not exist; Repository Consistency reported `CLEAN`, exit 0. Check 7 compares only the `live_state` fields the generator extracts and says so — "no other ai-map key is brought under comparison by this" — so the receipt is the only authority that observes those keys at all, and removing it would leave the cold-start map's boot pointers unguarded.

The delegation the narrow exclusion relies on was proven in the same worktree rather than assumed: with `live_state.active_change_request` set to a phantom contract, Repository Consistency failed with `AI-MAP STALE: ... the cold-start handoff pointer disagrees with its own SSOT`, exit 1. Each excluded field is one Check 7 already compares by value against the manifest that owns it.

## Risks

Low, and bounded by what is excluded.

- Four values stop being fingerprinted. Three of them — `live_state.active_change_request`, `live_state.last_completed`, `live_state.next_capability` — are the fields `CR_LIFECYCLE.md` §9 requires the completion act to rewrite, and each is independently compared by value against the manifest by Check 7. The fourth, `generated_at`, is a timestamp that carries no authority and moves on every generator run. No key loses its last guard.
- `live_state.source` and `live_state.phase` stay fingerprinted deliberately: completion does not own them, and Check 7 tests `phase` for presence rather than by value.
- The material risk is a projection that silently stops excluding the intended field after the generator renames it. That direction fails LOUDLY — the receipt goes stale and completion is refused — never open. A structural assertion additionally ties the excluded names to the names the generator emits.
- A second risk is a projection that is not stable between `-Finish` and the completion Gate. The fingerprint is only ever compared against itself, on one machine, minutes apart, so a canonical re-serialization is sufficient; an unparseable map falls back to hashing raw bytes, which fails closed.
- The receipt remains an anti-omission and anti-staleness control, not a trust boundary. This change does not alter that, and it does not touch the Gate, the completion prerequisites, or the receipt's other three bindings.

## Supersedes / Depends On

None. This Change Request repairs the certification lifecycle only. It exists because an unpublished blocked Change Request could not legally complete, and it deliberately records no identity for that work.

## Write Scope

- `changes/SPEC-179-completion-owned-generated-state.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `scripts/generate-ai-map.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_future_date_guard.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `.githooks/pre-commit`
- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `CODING_STANDARDS.md`
- `changes/TEMPLATE.md`
- `supabase/migrations`
- `reports/history`

## Required Reading

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/generate-ai-map.ps1`
- `CR_LIFECYCLE.md`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Implementation Steps

1. Verification check: `scripts/check_agent_continuity.ps1` contains the string `AiMap-CertifiedProjection`. If it matches, record Already Applied and skip. Otherwise, immediately before `Implementation-Fingerprint`, add exactly one function named `AiMap-CertifiedProjection` taking a file path. It reads the file as text; attempts `ConvertFrom-Json`; on failure returns the raw text unchanged so an unparseable map is fingerprinted by its bytes; on success removes the top-level property `generated_at` and, when a `live_state` property exists, removes from it exactly the properties `active_change_request`, `last_completed` and `next_capability`, then returns `ConvertTo-Json` of the result at a depth sufficient for the whole document. Introduce no new file, module or class. Add a comment stating that these are the values the completion act is required to rewrite, that each of the three `live_state` fields is compared by value against the manifest by Check 7, and that the file is deliberately NOT removed from the fingerprint because no other authority observes its remaining keys.

2. Verification check: within `Implementation-Fingerprint`, the hashed bytes for a scoped path are obtained through `AiMap-CertifiedProjection` when that path is `ai-map.json`. If it matches, record Already Applied and skip. Otherwise, in `Implementation-Fingerprint` only, where the file's bytes are read for hashing, hash the UTF-8 bytes of `AiMap-CertifiedProjection` applied to that file when and only when the scoped relative path is exactly `ai-map.json`; hash the file's raw bytes in every other case. Leave untouched: the `$skip` list, the `absent` sentinel and its comment, the sort order of scoped paths, the accumulator format `"$p $h`n"`, and the final hash of the accumulator.

3. Verification check: `scripts/test_agent_continuity.ps1` contains the string `completion-owned`. If it matches, record Already Applied and skip. Otherwise add exactly two behavioural cases to the certification group, using the existing fixture harness — `Reset-Fixture`, `ContractText`, `ManifestText`, `Put`, `Rebase`, `Run` and `Assert` — and adding no new harness function. Both use a contract whose Write Scope includes `ai-map.json` and a fixture `ai-map.json` carrying a `generated_at` value, a `live_state` object with the three completion-owned fields, and at least one further key outside `live_state`. The MUST-ACCEPT case runs `-Finish`, then rewrites `ai-map.json` changing ONLY `generated_at` and the three completion-owned `live_state` fields alongside the normal completion bookkeeping, and asserts the Gate accepts the completion. The MUST-REJECT case runs `-Finish`, then changes ONLY a key outside `live_state`, and asserts the Gate refuses it with `COMPLETION_PREREQUISITE:stale certification receipt`.

4. Verification check: `scripts/test_agent_continuity.ps1` contains the string `certified projection excludes exactly`. If it matches, record Already Applied and skip. Otherwise add exactly one STRUCTURAL case asserting, against the real repository sources the suite already reads, that the field names `AiMap-CertifiedProjection` removes are exactly `generated_at`, `active_change_request`, `last_completed` and `next_capability`, and that `scripts/generate-ai-map.ps1` emits each of those four names. Delete no existing assertion, change no existing assertion's number, name or condition, and weaken no existing negative case.

## Acceptance Criteria

- [ ] `Implementation-Fingerprint` excludes exactly four values from `ai-map.json` — `generated_at`, `live_state.active_change_request`, `live_state.last_completed`, `live_state.next_capability` — and treats no other scoped path specially.
- [ ] `ai-map.json` remains inside the fingerprint: a change to any key outside those four still changes it.
- [ ] An unparseable `ai-map.json` is fingerprinted by its raw bytes rather than skipped.
- [ ] The `$skip` list, the `absent` sentinel, the accumulator format and the final accumulator hash in `Implementation-Fingerprint` are unchanged.
- [ ] `scripts/test_agent_continuity.ps1` carries a MUST-ACCEPT case proving completion-owned bookkeeping after `-Finish` does not invalidate certification.
- [ ] `scripts/test_agent_continuity.ps1` carries a MUST-REJECT case proving a non-completion-owned `ai-map.json` mutation after `-Finish` is refused as a stale certification receipt.
- [ ] A structural case ties the four excluded names to the names `scripts/generate-ai-map.ps1` emits.
- [ ] The existing stale-receipt, missing-receipt, wrong-Change-Request and wrong-profile rejections are unchanged and still fail; no assertion was deleted, renumbered or weakened.
- [ ] No file outside Write Scope was created, modified or deleted, and no new test file exists.

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

## Notes

Scope deliberately NOT taken. Making Check 7 regenerate `ai-map.json` and diff the whole document would let the fingerprint drop the file entirely and would close the `boot_order` hole as a side effect. It is refused here on cost and on authority: it requires a comparison mode in the generator, a rewrite of Check 7, and a decision about the `generated_at` stamp that changes on every run — three owners for one blocking defect, when the blocking defect is that a three-file class was implemented as a two-file list. The unguarded-key finding is recorded as an Engineering Observation for its own Change Request; this one does not widen to absorb it, and deliberately leaves those keys under the receipt rather than removing their only observer.

`CR_LIFECYCLE.md` is not in Write Scope. Its §8 summary already describes the receipt as carrying "a fingerprint of the Write Scope's file content" without enumerating the two exclusions the implementation has always had, so its level of precision is unchanged by a third; the enumerated authority is the comment beside the code.

The existing negative cases are the reason this repair is narrow rather than a redesign. Case 95 proves a missing receipt still refuses completion, 96 and 97 prove a receipt bound to another Change Request or another profile set is refused, and 98 proves a real implementation edit after certification is refused. Those four remain the anti-forgery and anti-staleness spine and are not touched.
