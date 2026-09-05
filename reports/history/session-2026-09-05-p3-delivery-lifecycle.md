# ORVION — P3: the delivery ledger gets its lifecycle, and a divergence gets closed before it grows

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-05
Author: Claude Opus 5
Status: **COMPLETE — two migrations (`202607060900`, `202607061000`), deployed to Primary and parity-verified on all three surfaces. Repository = GitHub = local = Primary. A live GitHub/Primary divergence was found in preflight and closed first.**

---

## 0. HANDOFF (read this first — `AGENTS.md §6`)

- **INHERITED, and the preflight found it wrong.** HEAD `1df2f06` = `origin/main`, but the working tree held three uncommitted migrations that had **already been deployed to Primary** in the previous session. So `origin/main` carried 194 migration files while Primary ran 197 — **RECOVER-1's exact shape, in production, right now**. Closed before any new work: commit `8a59ebf`, pushed, four-way parity restored.
- **PROVEN (behavioural evidence, this session):** 199 migrations apply clean from scratch; pgTAP **100 files / 1476 assertions PASS**; smoke `ALL CHECKS PASSED (77 tables … 71/611 catalog)`; six HTTP suites **430 / 0**; consistency **CLEAN 1–20**; **Primary parity PROVEN on all three surfaces, values READ FROM Primary** — ledger `829b15676b66b7d0cc744ebb9ecbddc1`, functions `0344913a0040acaf78806c041bd231ed` (276), structure `9f5d544b6b1bc4d2cfe833bd85336fc5` (3,532 across ten surfaces).
- **UNPROVEN, and not claimed:** no email has ever been sent by ORVION and none was sent here. The dispatcher does not exist. Every assertion in this session is about the DATABASE's delivery state machine; none is about a provider, deliverability, or an actual message reaching a person. Concurrency is likewise proven only as far as one pgTAP session allows — the claim's `skip locked` is exercised, two genuinely simultaneous dispatchers are not.
- **CHANGED:** `202607060900`, `202607061000`; `100_notification_delivery_lifecycle_test.sql` (new, 22); `63_sla_escalation_test.sql` (+1); `88_parent_state_on_every_door_test.sql` (PARENT-1 expectation + seventh non-defect); `scripts/verify_database.sql` (catalog pin 607 → 611); manifest; Gap Register; **`MASTER_EXECUTION_PLAN.md` item 4 (two stale claims)**; ledger evidence; `ai-map.json`; reports index.
- **REMAINING:** **MAIL-1** is still the only open owner decision and it now blocks exactly one thing — the n8n workflow's send node. **DELIV-1** is now cheap and is the recommended next engineering step.
- **DO NOT TOUCH:** do not add `next_attempt_at` — it is derived at claim time deliberately, so the retry schedule has one authority; materialising it is an upgrade path, not a fix. Do not "simplify" the four inline delivery inserts in `process_lead_sla` into a trigger on `notifications` — that would silently give an email obligation to all eleven notification types and decide D4's channel policy by accident. Do not give `orvion_integration` a table grant; it has none, by design, and both new RPCs preserve that.
- **NEXT:** §7.

---

## 1. THE PREFLIGHT FINDING, WHICH OUTRANKED THE BRIEF

The directive's §5 states the rule as *never leave LOCAL > GITHUB or LOCAL > PRIMARY*. The measured state was worse than either, because it was the version that has already bitten this repository:

| Surface | Migrations |
|---|---|
| `origin/main` (committed) | **194** |
| Working tree | 197 (uncommitted) |
| Local database | 197 |
| **Primary** | **197** |

**Primary was running three migrations `origin/main` had never received.** Not local-ahead-of-cloud — *cloud ahead of the repository*, which is RECOVER-1 verbatim: *"Primary ran four migrations the repository did not have, for a day, while every guard reported CLEAN."* It existed because the previous session deployed and did not commit.

Proven from both ends before acting (`git ls-tree -r origin/main` counted 194 migration files; Primary's ledger counted 197), then closed by commit `8a59ebf` and a push, then re-verified: `0 0` ahead/behind, 197 files on `origin/main`, working tree clean.

**One commit, not three, and the reason is a rule rather than convenience.** `AGENTS.md §98` requires the Primary-ledger evidence to be refreshed *in the same commit* as a migration-set change. Three commits would each have carried an evidence file describing a different migration count, so Check 19 would have failed on two of the three — green at the tip, red in the history CI actually checks.

---

## 2. THE RECOMMENDATIONS, JUDGED

| # | Proposition | Verdict |
|---|---|---|
| **A** | P3 is the correct next capability | **ADOPTED.** And it is the n8n prerequisite — see §6 |
| **B** | Provider neutrality; PostgreSQL owns state, n8n owns dispatch | **ADOPTED**, and it survived contact: the migration contains no provider name, no API shape, no template, no suppression list |
| **C** | Model `attempt_count`, `last_attempt_at`, `next_attempt_at`, `last_error`, dead-letter, claim/lease | **PARTLY REJECTED — three of six.** See below |
| **D** | Don't assume the claim is safe; determine what concurrency actually needs | **ADOPTED**, and it needs less than the list suggests |
| **E** | Answer the lost-ack question without optimism | **ANSWERED FROM PRECEDENT**, not invented |
| **F** | `process_lead_sla` writes notifications but not deliveries | **CONFIRMED live**, and closed in the same capability |
| **G** | Improve governance/workflow/handoff continuously | **ADOPTED** — §1, §5 |

**Where C was rejected, and why.** The brief asked that every field have a demonstrated purpose. Applying that test to the brief's own list:

- **`last_error` — already exists.** `notification_deliveries.error_message` has been there since the table was created. Adding a second column for it would have been the duplicate-authority mistake this repository keeps finding.
- **`last_attempt_at` — already exists**, as `created_at` / `sent_at` / `failed_at`, because one row *is* one attempt.
- **`attempt_count` — rejected.** SPEC-123 models attempts as ROWS. A counter on a shared row would be a second, different retry model in the same database, and it keeps only the last error where the row model keeps every one.
- **`next_attempt_at` — rejected as a column, adopted as behaviour.** The claim query derives eligibility from the previous attempt's `failed_at` and its `attempt_number`. Storing it would put the schedule in two places — the writer that computes it and the reader that trusts it. **Ceiling stated in the migration:** a derived predicate is not directly indexable, so materialising it is the upgrade path if the table ever outgrows the partial index.
- **Dead-letter state — adopted, and it is the one place SPEC-123 is *worse*.** There, a conversion that has failed five times is simply never selected again: indistinguishable from one still waiting. DELIV-1 already complains about exactly that.
- **Claim/lease — adopted, minimally.** One column.

Net: **three columns and one catalog value**, where the brief's list implied six or seven.

---

## 3. WHAT CONCURRENCY ACTUALLY NEEDED (D)

PostgreSQL 17's own documentation settles the mechanism and states its own limitation: *"With `SKIP LOCKED`, any selected rows that cannot be immediately locked are skipped. Skipping locked rows provides an inconsistent view of the data, so this is not suitable for general purpose work, but can be used to avoid lock contention with multiple consumers accessing a queue-like table."* That is this table, described exactly.

Two details follow from the docs rather than from habit. The `ORDER BY` sits **inside** the locking sub-select, which is the form the Caution note about `ORDER BY` with a locking clause at READ COMMITTED recommends. And the composite index over the columns the claim searches is partial on `pending`, because every row it exists to find is pending and the terminal states are dead weight in it.

**Rejected: claim tokens, worker identity, heartbeats, stale-claim recovery beyond the lease.** n8n runs one scheduled workflow. A transaction-scoped row lock plus a 30-minute lease already make a crashed run recoverable, and the brief's own instruction was not to build a worker system n8n does not require.

---

## 4. THE LOST-ACK QUESTION (E), ANSWERED FROM PRECEDENT

*What happens if n8n sends the email but PostgreSQL never records the result?*

The row stays `pending` with `claimed_at` set. Thirty minutes later the next claim sweeps it to `failed` with `LEASE_EXPIRED`, and the backoff eventually opens attempt N+1. **The email is sent twice.** ORVION is at-least-once and this migration does not pretend otherwise.

The minimum mechanism to *prevent* the duplicate is a provider-side idempotency key, and this repository has already decided what that key must be. `MASTER_INTEGRATION_CATALOG.md §2a` item 4 fixed the identical problem for conversions: *"set `transactionId` to the row's `conversion_id` … stable and immutable across every retry and reclaim."* The delivery id is **not** that key — it changes with every attempt, which is the whole point of the row model. The stable key here is **`notification_id` + `channel_code`**, and the claim RPC returns `notification_id` precisely so the workflow can use it.

Choosing *which* provider header carries it is MAIL-1's, and inventing it now would have been the provider-specific decision the brief forbids.

---

## 5. THE CLASS GUARD THAT EARNED ITS KEEP

Wiring the SLA's delivery obligation broke `88_parent_state_on_every_door_test` assertion 25 — the PARENT-1 detector, which enumerates every `app` function that reads a registered parent's status and writes another table without a matching table-door guard, and compares the list to an exact expected string.

It was right to fire: `process_lead_sla -> notification_deliveries (leads)` is a genuinely new pair. It was **run down against the catalog rather than pattern-matched**, as that file's own header demands:

- `public.notification_deliveries` has **no `lead_id` column** — so a table-door guard there would have no lead to read, the identical argument the file already accepts for `record_payment -> payments (invoices)`.
- `process_lead_sla -> notifications (leads)` is **already** an accepted non-defect, and this is that same pair one level deeper on the same path.
- A guard that refused the obligation when the lead moved would suppress the very alert the lead moving is the reason for — canon 10 requires the manager notice regardless of what the lead does next.

Recorded as the **seventh verified non-defect** with that reasoning, not silenced.

The catalog pin in `scripts/verify_database.sql` moved 607 → 611 for the same reason: four new values (one status, three event types), each named in the comment beside the pin.

---

## 6. WHEN CAN ORVION REALISTICALLY START BUILDING n8n?

**Now, for the offline-conversion workflow — that contract has been complete and HTTP-verified since SPEC-123, and P3 was never its blocker.** For the notification-dispatch workflow, the database contract is complete as of today, so the only remaining prerequisite is **MAIL-1**: the provider *and* the Egyptian PDPC cross-border transfer licence naming its destination country, which decides which providers are eligible at all. **P3 did not have to be complete before n8n work could begin, but it did have to be complete before the notification workflow could be built against a stable contract — and it now is.**

---

## 7. NEXT

**DELIV-1** — one `reporting` view over work that has exhausted its retries, covering both outboxes. It is engineering-owned, needs no owner input, and `dead_lettered` has just made it trivial: exhaustion is now a value to select rather than an absence to infer.

Two things deliberately left for it rather than done here: SPEC-123's conversion outbox still has **no terminal state** (a five-times-failed conversion is invisible in exactly the way this session fixed for notifications), and the **six call sites** that now write the `notifications` + `notification_deliveries` pair justify an `app.notify(...)` helper. Both are recorded rather than folded into P3 — the first because it means changing a shipped outbox, the second because it means rewriting two owner-approved functions for zero behavioural gain.

---

## 8. VERIFICATION

| Gate | Result |
|---|---|
| `npx supabase db reset` | **199** migrations apply cleanly from scratch |
| `npx supabase test db` | **100 files / 1476 assertions — All tests successful** (was 99/1453) |
| `scripts/verify_database.sql` | `ALL CHECKS PASSED (77 tables … 71/611 catalog …)` |
| six HTTP suites | 29 + 120 + 107 + 40 + 74 + 60 = **430 passed, 0 failed** |
| `check_repository_consistency.ps1` | **CLEAN**, Checks 1–20 |
| `check_database_parity.ps1` + three Primary values | ledger, function surface and structural surface **all match**; contract matches live |
| `generate-api-contract.ps1` | **no change** — both new functions are `app`-schema and granted only to `orvion_integration`, so they are correctly not PostgREST endpoints |

**Primary values were READ FROM PRIMARY** through the `supabase-primary` MCP using the same `scripts/parity_surface.sql` both sides run (GUARD-1). As last session, `apply_migration` stamped its own timestamp version and the ledger rows were corrected to the repository's synthetic scheme before comparing.

End of report.
