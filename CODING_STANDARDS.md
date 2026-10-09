# CODING_STANDARDS.md

## 1. Naming Conventions
Use English names for all code, files, and identifiers. Use clear, descriptive terms and avoid abbreviations that are not standard. Use PascalCase for types and classes, camelCase for variables and functions, and snake_case for PostgreSQL database objects.

## 2. Project Structure
Organize code by domain or responsibility rather than by technical layer alone. Keep related logic together and separate concerns that differ in purpose. Maintain a consistent folder structure across modules and preserve existing repository boundaries.

## 3. General Coding Rules
Write code that is explicit, readable, and easy to review. Prefer small, focused units over large abstractions. Avoid duplicated logic. Avoid magic values and unexplained shortcuts. Keep behavior predictable and make intent clear in the code.

**Boring Engineering Wins (permanent principle, evidence-institutionalized 2026-07-17).** When two solutions produce the same verified outcome, choose the boring one — simpler, more predictable, more maintainable — over the clever one. Clever is what a future engineer (human or AI) has to decode at 3am. Evidence for this repo, not assertion: session-of-record showed clever first drafts (a lateral-join count expression; a direct-wrap view over a tenant-raising function) each *replaced* by the boring equivalent (`get diagnostics row_count`; lateral-gated view) with identical behavior and far less to misread. This is `AGENTS.md §3` Earn-It applied at code altitude; it is the *default*, invoked without ceremony.

**Two related proposals evaluated 2026-07-17 and REJECTED as new principles — already owned, more strongly, elsewhere (recorded so they are not re-litigated, per `GOVERNANCE.md §19`):** (1) *Strict TDD (test-first).* Rejected: for SQL migrations a pgTAP/behavioral assertion cannot meaningfully precede the schema it inspects, and the genuine value (regression safety + design pressure) is already delivered by **Test-before-trust** (`AGENTS.md §2`) + the **discovery-to-guard loop** (`GOVERNANCE.md §18`) — every non-trivial change already ships an executable check (self-gating smoke, behavioral test, pgTAP invariant) run on every `db reset` and in CI. The standard is *test-verified*, not *test-first*. (2) *"Every new capability should eventually eliminate unnecessary complexity."* Rejected as a weaker, unbounded restatement of the **Anti-entropy / boy-scout invariant** (`AGENTS.md §2`: every session leaves the repo at least as clean and reduces entropy where the work touches) + **Retention Earn-It** (`GOVERNANCE.md §18`). The existing wording is measurable (the guard must stay CLEAN; no new duplicate authority); "eventually" is not.

## 4. SQL Standards

Use PostgreSQL-compatible SQL and keep statements clear and deterministic. Prefer explicit constraints, sensible defaults, and consistent naming. Avoid implicit behavior and ensure schema changes preserve data integrity. Keep queries readable and maintainable.

### PostgreSQL Requirements

- Primary keys: UUID on every table
- Timestamps: TIMESTAMPTZ for all timestamp columns
- Money: NUMERIC for all monetary values
- Naming: snake_case for all database objects
- Queries: No SELECT *
- Foreign keys: explicit constraint names on every FK
- Indexes: explicit names on every index
- Constraints: CHECK constraints where appropriate
- Documentation: comments on all tables and all columns

## 5. API Standards
Design APIs to be consistent, predictable, and explicit. Use clear request and response shapes, stable naming, and consistent error behavior. Avoid unnecessary parameters and ensure the contract is understandable without hidden assumptions.

## 6. Error Handling
Handle errors explicitly and fail in a controlled way. Preserve useful context for diagnosis without exposing sensitive information. Avoid silent failures and ensure abnormal conditions are surfaced in a consistent manner.

## 7. Logging
Use logging to support diagnosis and operational awareness. Log meaningful events, include sufficient context, and avoid excessive or redundant output. Keep logging consistent across the codebase and avoid logging sensitive data.

## 8. Security
Protect secrets, credentials, and sensitive data at all times. Validate input, enforce authorization boundaries, and avoid unsafe assumptions. Follow least-privilege principles and preserve trust boundaries in every change.

## 9. Performance
Write code that is efficient enough for the intended workload without unnecessary complexity. Favor clear implementation over premature optimization. Use indexes and query structure decisions only when they are justified by measurable need.

## 10. Code Review Checklist
Review every change for correctness, clarity, maintainability, security, and consistency with these standards. Confirm that the change is necessary, scoped correctly, and does not introduce ambiguity or unnecessary risk. Verify that the change does not conflict with the canonical documentation.

## 11. Canonical Architecture

All implementation must remain consistent with the canonical architecture.

Never bypass or contradict canonical design decisions without explicit approval.

## 12. PowerShell traps

Repository scripts run under PowerShell 7. Each trap below has already cost this repository a wrong result or a damaged working tree, and each rule names that evidence.

- **Variable names are case-insensitive.** `$r` and `$R` are one variable: in `SPEC-238`'s readiness script `$r` overwrote the repository root `$R`, every later path resolved under `C:\scripts\`, and the suites after it failed with exit 64. A loop's `$l` later emptied a line array named `$L`. Give every variable a distinct descriptive name, and never a one-letter one beside another.
- **An alias wins over a function of the same name.** A helper named `Rd` ran the built-in `rd` alias, which deletes files, and removed `AGENTS.md` from the working tree; Git restored it (2026-10-08). Name helpers `Verb-Noun`, and check that `Get-Alias <name>` finds nothing before defining a short one.
- **Comparisons are case-insensitive by default.** `-match 'FAIL\b'` matches the prose "fail-closed", and a watcher reported prose as a failure until it used `-cmatch`. Use `-cmatch`, `-cnotmatch` and `-ceq` wherever case carries meaning, as Check 22 does.
- **Integrity checks compare exactly, and text is built deliberately.** Where code decides that text is unchanged (frozen authority, append-only evidence, a recorded hash), compare with `[string]::Equals(a,b,[StringComparison]::Ordinal)`, `.StartsWith(x,[StringComparison]::Ordinal)` and a `[StringComparer]::Ordinal` dictionary. `-eq`, `-ne`, `-cne`, a bare `StartsWith(string)` and `@{}` keys are not exact: on PowerShell 7.6 they treat NUL, backspace, zero-width space and soft hyphen as absent and a composed and a decomposed letter as equal, and the evidence check admitted those edits until `SPEC-254` (CTRL-4). Building the text is a separate hazard. In `"…"` and `@"…"@` a backtick is an escape: `` `0 `` committed a NUL to `SPEC-250` and `` `a `` a BEL to `SPEC-239`. A Unicode escape sequence passed through an agent's file-writing tool arrived as the invisible character itself in `SPEC-251`'s prototype. Write literal text with `'…'` or `@'…'@`, make a control character with `[char]`, and before committing scan for characters below 0x20 other than TAB and LF.
- **`-match` rebinds `$Matches`.** A second `-match` inside a block that still reads `$Matches` returns the second pattern's groups. Use `[regex]::Match` for any value that must survive (`Get-RegisterFindingState`).
- **Assigning `$LASTEXITCODE` inside a function creates a local shadow**, and every later read in that function returns the stale value instead of the native command's code. That made the historical-immutability guard read ACTIVE for every ref (`SPEC-212`). Capture each exit code into a distinct local immediately.
- **`Start-Process -ArgumentList` does not keep a path containing a space together.** This checkout's own path (`Platinum Plus`) split into two arguments. Pass one argument string with each path in double quotes (`scripts/watch_selftest.ps1`).
- **.NET file APIs ignore `Set-Location`.** `[IO.File]` and `[IO.Directory]` resolve a relative path against the process directory, so a script working in a scratch worktree wrote into the main checkout. Give .NET absolute paths built from the root.
- **Write repository text with LF.** A CRLF `ai-map.json` fails `git diff --check`, and a migration written with CRLF carries the CR bytes into the function text it defines. Write with `[IO.File]::WriteAllText` after replacing CRLF, as the generators do.
