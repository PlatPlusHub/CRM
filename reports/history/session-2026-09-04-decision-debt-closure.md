# ORVION — Decision-debt closure: eight "owner decisions" that were not, and the GitHub identity a re-clone silently undid

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: **CLOSED for the decision analysis; four implementations SCHEDULED and deliberately not built here.** Eight of fifteen mandated open decisions were resolved from engineering evidence and **none of the eight required the owner**. Eight genuine business decisions remain, each narrowed to one question with a recommendation. Three new findings. GitHub identity repaired at its actual cause. **No migration; Primary and the local database were not written to.**

---

## 1. EXECUTIVE SUMMARY

The owner's directive was that no open decision may sit unresolved merely because a document labels it an "Owner Decision", and that engineering must resolve whatever engineering evidence can settle.

**Applying that rule cost eight labels.** Six items carried `BLOCKED — BUSINESS DECISION` or `OWNER DECISION` in the register and, re-derived from the implementation rather than trusted, were not business decisions at all. The most consequential:

**FIN-7 said canon defines no Invoice State Machine and that inventing the legal transitions would be inventing business policy. The transitions already exist, in code, enforced.** `app.issue_invoice` raises `only a draft invoice can be issued (is %)`. `app.record_payment` refuses anything outside `issued/partially_paid/overdue` and then does not *choose* the next state — it **derives** it: `v_new_status := case when v_new_total >= v_inv.total_amount then 'paid' else 'partially_paid' end`. Nothing needs deciding. What is missing is that `invoices` has **no `enforce_status_transition` trigger** and **zero rows** in `app.status_transitions`, so those rules bind the RPC door and not the direct PostgREST door — the class this repository has already fixed five times (BOOK-1, ADMIN-1, FIN-8, FIN-10, QUO-1).

**Three findings emerged that nobody had recorded**, two of them about the registry itself:

- **TAX-1** — `invoices.external_submission_status_code` is guarded against a catalog type **that does not exist**, so the column can only ever hold NULL.
- **GOV-15** — TRANS-1 carried two detail blocks disagreeing on **both** Status and Owner, invisible to Check 2 because `IN PROGRESS` and `BLOCKED` are both open forms.
- **GOV-16** — nothing binds the register's open rows to the manifest's decision line. A census found ~45 non-closed rows; the manifest surfaced 15. The entire **DC-\*** family and **PH8-3…PH8-8** are invisible at boot.

**On the GitHub identity**, the previous session's recommendation was wrong about where the fix belonged. The 2026-08-26 session had *already* qualified the remote — and `git reflog` shows `clone: from https://github.com/PlatPlusHub/CRM.git` on **2026-08-30**, which recreated `.git/config` and discarded it. **`.git/config` is not tracked by git**, so a fix that lives only there cannot survive the operation that most often rebuilds the environment. The real cause was in a **tracked** file: `bootstrap.ps1` hardcoded the unqualified URL and clones from it.

---

## 2. INITIAL REPOSITORY STATE

Fetched first, per the directive.

| Axis | Value |
|---|---|
| Branch | `main` |
| HEAD = origin/main = ls-remote | `ea181e7b4d58be1e00e57694813ff139c4787289` |
| Ahead / behind | 0 / 0 |
| Working tree | clean |
| Migrations | **190**, latest `202607060100` |
| Active Change Request | `None` |

---

## 3. GITHUB IDENTITY INVESTIGATION

### 3.1 What was already correct

| Layer | Value | Verdict |
|---|---|---|
| `user.name` (global) | `PlatPlusHub` | ✅ already correct |
| `user.email` | `platplustours@gmail.com` | ✅ |
| `remote.origin.url` repo | `https://github.com/PlatPlusHub/CRM.git` | ⚠️ correct repo, **no username** |
| `.git/config` | no `Shehabhub` anywhere | ✅ |
| `gh` CLI | **not installed** | ✅ the `gh:github.com:Shehabhub` keyring entry the 2026-08-26 report cited is gone |

### 3.2 Exactly why `Shehabhub` was selected

Git Credential Manager keys credentials **by URL**. With no username in the URL, git asks GCM for `git:https://github.com` — and Windows Credential Manager holds:

| Target | User |
|---|---|
| `git:https://github.com` | **`Shehabhub`** ← what an unqualified URL resolves to |
| `git:https://PlatPlusHub@github.com` | **`PlatPlusHub`** ← reachable only from a qualified URL |
| `GitHub - https://api.github.com/PlatPlusHub` | `PlatPlusHub` (GitHub Desktop namespace; git never reads it) |

`Shehabhub` is the **pre-migration** account — this repository was migrated `Shehabhub/ORVION` → `PlatPlusHub/CRM`. Historically this produced `403 Permission to PlatPlusHub/CRM.git denied to Shehabhub`; once that credential went stale it became a **non-interactive hang** waiting for a username.

### 3.3 Why the previous fix vanished — proven from the reflog, not inferred

```
09adf19 HEAD@{23}: clone: from https://github.com/PlatPlusHub/CRM.git   2026-08-30 12:57:47
```

The 2026-08-26 session recorded `origin` re-qualified as a completed fix. **Four days later the repository was re-cloned from the unqualified URL**, which built a fresh `.git/config`. Git does not track `.git/config`, so the fix could not survive.

**And the clone URL is not incidental — it is committed.** [bootstrap.ps1:12](../../bootstrap.ps1#L12) held `$RepoUrl = "https://github.com/PlatPlusHub/CRM.git"` and line 29 clones from it. Every machine rebuilt through the documented one-command path is *born* with the wrong identity.

### 3.4 What was changed

1. **`git remote set-url origin https://PlatPlusHub@github.com/PlatPlusHub/CRM.git`** — the same value the 2026-08-26 session ratified. Not invented; the identical repository with the username qualified.
2. **`bootstrap.ps1`** — `$RepoUrl` now carries the qualifier, with a comment explaining that it is load-bearing and recording why (so it is not "simplified" away again). **This is the durable half**: it is tracked, so it survives clones.
3. **`.workstation/doctor.ps1`** — a new `[GitHub identity]` section asserting `origin` is qualified and `user.name` is `PlatPlusHub`, with the remedy printed on failure.

### 3.5 Verification — non-destructive, and both directions

```
git fetch origin                    → exit 0, no prompt
git push --dry-run origin main      → "Everything up-to-date", exit 0, no prompt
```

Both run with `GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never`, so a fallback to an interactive prompt would have failed instead of hanging. **The push path authenticates as `PlatPlusHub` with no human present.**

The new check was **mutation-tested**, per `AGENTS.md §6` (a detector nobody has attacked is a hypothesis):

| State induced | doctor output |
|---|---|
| `origin` reverted to the unqualified URL (the exact 2026-08-30 regression) | `[FAIL] origin is 'https://github.com/PlatPlusHub/CRM.git' - NOT username-qualified` + remedy |
| restored | `[ OK ] origin is username-qualified as PlatPlusHub` |

### 3.6 What remains, stated exactly rather than claimed complete

**ORVION has no operational dependency on `Shehabhub`.** The credential is bypassed, not relied upon — proven by a push that authenticates without it.

**The stale `git:https://github.com` → `Shehabhub` entry is still in Windows Credential Manager, and was deliberately NOT deleted.** It is **machine-wide**, not repository-scoped: any *other* repository on this machine cloned from an unqualified `github.com` URL resolves to it. Deleting it is outside "do not silently make unrelated Git configuration changes", and I cannot enumerate the owner's other repositories to know what would break.

> **If the owner wants it gone** (safe only if no other local repository depends on the `Shehabhub` account):
> ```
> cmdkey /delete:LegacyGeneric:target=git:https://github.com
> ```
> One command, no GUI. ORVION is unaffected either way — it no longer uses that entry.

*Unrelated and out of scope, noted only so it is not mistaken for a GitHub association later:* Windows Credential Manager also holds **Docker Hub** entries under `docker/auth/hub/shehabhub`. Docker is used here only for the local Supabase stack, which requires no Docker Hub login.

---

## 4. DECISION INVENTORY — WHAT THE CENSUS ACTUALLY FOUND

The manifest listed **15**. A census of `MASTER_GAP_REGISTER.md` (1,165 lines) found **roughly 45 non-closed rows**. The difference is not sloppiness — it is **GOV-16**: Check 11 verifies every manifest id resolves in the register, and Check 14 that none is already decided, but **neither checks the converse**, so a register row can stay open indefinitely without ever appearing at boot.

Invisible to the manifest, and therefore never triaged: the whole **DC-\*** family (DC-6, DC-8, DC-10 … DC-29 — several labelled `PENDING (OPTIONAL / NEEDS MORE EVIDENCE)`, i.e. **evidence gaps the owner's directive says must not remain owner decisions**), **PH8-3…PH8-8**, **AUDIT-2/4/5**, **CAT-5/6**, **DEAD-2/3/4**, **FIN-9/11**, **IDENT-2**, **OPS-1**, **PP-1**, **BOOK-2**, **RPC-1**, **SYNC-1**, **BLOCKED-4/5**, **RET-2**.

**This report does not claim to have triaged all forty-five.** It triaged the fifteen the owner mandated, plus `RET-2` which is the same class as `RET-1`. The remainder are recorded in GOV-16 as a *measured population with a named guard gap*, which is the honest state — not a claim of completeness.

---

## 5. DECISION-BY-DECISION RESULT

Full analysis with evidence is in `MASTER_GAP_REGISTER.md` → **"Decision-debt closure pass — 2026-09-04"**. Summary:

### Closed by engineering — no owner input needed (8)

| ID | Was | Resolution |
|---|---|---|
| **FIN-7** | BLOCKED — BUSINESS DECISION | The machine exists in the RPCs. Six transitions read off the code. Only the second door is unguarded. **Implementation scheduled.** |
| **VERIFY-1** | OPEN, owner/engineering | Canon 07 makes verifying and approving **one act**, already implemented via `approval_requests`. Columns must never get a writer. **No code.** |
| **TRANS-1** | BLOCKED — ARCHITECTURAL | Keep the guarded duplication. The cure needs a sparse or jsonb column — trading a machine-checked duplication for polymorphism no constraint can check. **No code.** |
| **LIC-1** | BLOCKED — EXTERNAL DEP | Accept the residual. A 128-bit single-use token makes the enumeration attack the audit would detect infeasible; an autonomous-transaction extension on the security path is a net loss. **No code.** |
| **DELIV-1** | OPEN (subsumed by PH8-2) | Observability, not policy. **Implementation scheduled.** |
| **PH8-2** | OPEN, owner | Its own text says "observability, not enforcement". The four states already exist. **Implementation scheduled.** |
| **QUO-4** | OWNER DECISION | Canon 28's scope column reads "assigned/**department**" and the 2026-08-24 directive granted department continuity. Behaviour already correct. **Documentation only.** |
| **DOC-LC-2** | BLOCKED — BUSINESS DECISION | A **version** supersedes; a **document** does not. The implementation is right, canon 26 is wrong. **Recommend canon amendment.** |

### Reclassified — no longer blocking (1)

**RET-1** — `document_retention_days()` returns NULL, NULL means retain-forever, and the retention scan's `WHERE` is unsatisfiable, so **nothing is ever selected for destruction**. The conservative outcome is the *default*, not a step someone must remember. Only a **finite** period needs counsel. Recommendation: leave NULL.

### Narrowed to one question each (7 genuine business decisions) — see §7

---

## 6. EXTERNAL RESEARCH — WHERE IT CHANGED AN ANSWER

Research was used for comparison, never as a requirement, and only where it materially moved a recommendation.

**VOID-1 — the register's dichotomy was false.** It framed the choice as "void **or** credit note". Egypt's ETA e-invoicing uses **both**, separated by time and issuance: cancellation is permitted **within 7 days** (buyer approval required, never after 60 days, never once a credit note exists), and corrections after that window require **credit/debit notes referencing the original UUID**; validated invoices cannot be edited. That reframes the owner's choice entirely — and it is why the recommendation is *draft-only voiding now*, which is the whole of what today's columns can honour.

**Deliberately NOT adopted:** nothing from Salesforce/Dynamics/HubSpot was imported. TRANS-1's resolution explicitly **rejects** the DRY-maximising refactor those platforms' metadata-driven designs would suggest, because ORVION's duplication is already machine-checked and the cure introduces unconstrained polymorphism. A practice being common elsewhere was not treated as a requirement here.

Sources: [ETA e-invoicing cancellation & credit notes](https://rtcsuite.com/how-to-cancel-e-invoice/) · [Egypt e-invoicing compliance guide](https://www.2b-cs.com/blog/2b-1/e-invoicing-egypt-compliance-guide-39) · [ETA FAQ & integration guide](https://orchidatax.com/eta-e-invoicing-egypt-faq/)

---

## 7. DECISIONS THAT GENUINELY REQUIRE THE OWNER

Each is one question with a recommendation. None can be settled by engineering without inventing a business rule.

**1. SUP-4c — the conversion instant.** Base currency (`tenants.default_currency_code`), rate source (`exchange_rates`, tenant-maintained, `set_by`) and as-of rule (`effective_at`, made unique by DUP-1) **all already exist** — nothing needs inventing. The only question: convert at **(A) the evaluation instant** or **(B) each item's cost-lock instant**? *Recommend (A)* — a ceiling is a present-risk control and SUP-4b already re-evaluates on every write. Not blocking.

**2. CUST-3 — do customers get a receivable ceiling at all?** Engineering is pre-solved (SUP-4b's pattern, one migration). And if yes: warn like suppliers, or actually **stop** a booking? A payable and a receivable ceiling are different commercial instruments.

**3. VOID-1 — (A)** draft-only voiding now, credit notes deferred; **(B)** plus an ETA-shaped cancellation window on issued invoices; **(C)** full credit-note model. *Recommend (A).* Separately, engineering's view: `journal_entries` should be **reversed**, never voided — those three columns are wrong there regardless.

**4. PLAN-1 — three integers.** Canon marks Basic Reporting (Starter), Integrations (Professional) and Offline Conversion (Professional) as "Limited" and defines no value. Seeded uncapped (safe). Give three numbers, or say "unlimited".

**5. CANON-26-1 — admit `active → suspended`?** *Recommend yes.* Today suspension must pass through `read_only`, which still permits reads and export — so a tenant you have decided to suspend keeps transacting through the window. One canon line, one row. Stays with the owner because suspending a paying customer without warning is a commercial-relationship call.

**6. DOC-LC-3 — does un-archiving exist?** Canon 26 lists no path back to `active`; `enforce_archive_authority` says "restoring is the same authority as archiving". The **integrity half is engineering** and is scheduled. Only the collapse of the two fields waits on this.

**7. RET-1 — a finite retention period** for superseded document versions (counsel). *Recommend leaving NULL.* Not blocking.

**8. RET-2 — what ORVION owes a departed tenant's data.** Export window then destruction, indefinite retention, or a platform purge authority outside canon 28's read-only promise? Added to the manifest line, which had never carried it (GOV-16).

---

## 8. CHANGES MADE

| File | Change |
|---|---|
| `bootstrap.ps1` | Clone URL qualified with `PlatPlusHub`, with the rationale recorded — **the durable identity fix** |
| `.workstation/doctor.ps1` | New `[GitHub identity]` section; mutation-tested both directions |
| `reports/master/MASTER_GAP_REGISTER.md` | New "Decision-debt closure pass" section (+120 lines): 13 analysed items, 3 new findings; header updated |
| `_ORVION_CANONICAL/manifest.md` | Open-decision line rewritten (8 closed, `RET-2` added); `Last Completed`; `Next capability` re-pointed |
| `ai-map.json` | Regenerated |
| `reports/README.md` | Latest-session pointer |
| *(git config)* | `remote.origin.url` re-qualified — **untracked, machine-local** |

**No migration. No SQL. No database write.** The database was read only, through `postgres-local`.

---

## 9. WHAT WAS DELIBERATELY NOT DONE

**Four implementations are scheduled, not built** — recorded here so the next agent does not re-derive them:

1. **FIN-7's second door** — register the six transitions, attach `enforce_status_transition` to `invoices`. A fail-closed trigger on a live financial table needs a positive control per RPC path and a full `§5a` run; that is a package, not a line in a decision pass.
2. **TAX-1** — remove the `tax_submission_status` guard argument that guards an empty set (or seed it).
3. **DOC-LC-3's integrity half** — refuse the divergent pair.
4. **DELIV-1 + PH8-2** — one `reporting` view.

**Canon 26 was not amended** for DOC-LC-2. The answer is evidenced and recorded; amending canon is an owner-ratified act in this repository's governance, and the recommendation costs nothing to accept later.

**Checks for GOV-15 and GOV-16 were not written.** Both are guard changes and, per `AGENTS.md §6`, a guard is not earned until mutation-proven in both directions. They are registered, not silently deferred.

**Roughly thirty register rows outside the mandated fifteen were not triaged.** Stated plainly rather than implied complete — the population is measured and GOV-16 names why they were invisible.

---

## 10. VERIFICATION

| Check | Result |
|---|---|
| `check_repository_consistency.ps1` | **CLEAN — Checks 1–19, exit 0** |
| Check 19 (Primary ledger evidence) | **CLEAN** — 190 migrations, `1eaa2ec7…`; evidence commit remains an ancestor of HEAD |
| `check_database_parity.ps1` | **local matches the repository**; **Primary NOT CONTACTED — exit 2, `UNPROVEN`** |
| `.workstation/doctor.ps1` | all-green, including both new identity checks |
| `git fetch` / `git push --dry-run` | exit 0, non-interactive, as `PlatPlusHub` |

**PRIMARY PARITY = UNPROVEN.** Primary was not contacted in this session and this is **not** reported as a pass. No SQL changed, so nothing could have drifted; the recorded ledger evidence (Check 19) remains valid and attributable because the guard requires ancestry, not an exact HEAD.

**Tests were not re-run.** No migration, no test file and no SQL changed, so the `§5a` protocol was not triggered. Last executed state stands: 93 files / 1326 assertions, Pass A = Pass B; HTTP 414 / 0.

---

## 11. CURRENT STATE

- Migrations **190**, latest `202607060100` — unchanged
- Active Change Request `None`
- Open owner decisions: **SUP-4c · CUST-3 · VOID-1 · PLAN-1 · DOC-LC-3 · CANON-26-1 · RET-1 · RET-2** (was 15)
- New findings open to engineering: **TAX-1 · GOV-15 · GOV-16**

## 12. NEXT STEP (exactly one)

**FIN-7's second door** — register the six invoice transitions and attach `enforce_status_transition` to `invoices`, with a positive control per RPC path and a full `§5a` run. It needs **no owner input**, it closes the highest-severity item this pass opened, and it precedes the Batch-6 table sweep under the owner's rule: *eliminate resolvable decision debt first, then continue execution.*
