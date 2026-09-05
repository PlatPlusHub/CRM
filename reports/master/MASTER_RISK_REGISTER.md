# ORVION MASTER RISK REGISTER

Status: **Permanent cumulative risk register.** Never recreate; evolve. Risk = the production/compliance/architectural consequence if a finding is NOT addressed before its trigger. Cross-reference: `MASTER_GAP_REGISTER.md`.

Last updated: 2026-09-05 (**this header was corrected, no risk row changed — STALE-1.** It had read `2026-07-11` while RK-01 below carried a mitigation dated 2026-07-13; Check 21 now fails the build on that. Prior entry follows.)

Previously: 2026-07-15 (**the header outlived two edits to its own body.** RK-01 was marked **✅RESOLVED (SPEC-118)** on the strength of the 2026-07-13 money-precision widening, and the Repository Recovery of 2026-07-15 — a commit whose message says it "reconciled every lagging status column" — changed exactly that one line here and left the header at 2026-07-11. No risk row has moved since.)

Likelihood × Impact → Risk. Trigger = the event after which the risk becomes materially harder/impossible to mitigate.

| Risk ID | Description | Finding | Likelihood | Impact | Risk | Trigger (mitigate before) | Mitigation |
|---|---|---|---|---|---|---|---|
| RK-01 | Financial amounts truncated for 3-dp GCC currencies; balances un-reconcilable | DC-1/R7 | High (GCC market) | Critical | **✅RESOLVED (SPEC-118)** | first real finance rows | widened to numeric(19,4) 2026-07-13 |
| RK-02 | Duplicate payments/bookings/invoices on client retry | DC-2 | High | High | **High** | first client/API write | idempotency keys |
| RK-03 | Oversold Umrah/Hajj departures & allotments; lost updates | DC-3 | Med-High | High | **High** | inventory/allotment go-live | locking discipline |
| RK-04 | PK index fragmentation/write-amplification on hot tables; painful PK migration later | DC-13 | High at scale | Med-High | **High** | before event/message volume | UUIDv7 at PG18 (DEFERRED; cost-neutral default swap — see gap register DC-13) |
| RK-05 | Structural retrofit breaks a built RPC (customer_balance, finance gate, merge) with no regression net | DC-16 | High during Batch 0 | High | **High** | before running retrofits | pgTAP first |
| RK-06 | GDPR erasure request unsatisfiable vs immutable audit; EU-ad-integrated CRM | DC-4 | Medium | High (legal) | **High** | EU launch / first request | pseudonymization boundary |
| RK-07 | Sensitive-doc bytes accessible around row RLS via Storage | DC-5 | Medium | High | **High** | DML grants / client go-live | Storage RLS mirror |
| RK-08 | service_role/Edge bug exposes cross-tenant data | DC-15 | Low-Med | Critical | **High** | first Edge integration | least-privilege + assertions |
| RK-09 | Unbounded RLS scans at scale (per-row function eval, missing indexes) | A1/A2 | High at scale | Medium | **Medium-High** | production data volume | init-plan wrap + indexes |
| RK-10 | Duplicate business keys corrupt lookups/operator trust | R8/B3 | Medium | Medium | **Medium** | before real booking/quote data | unique constraints |
| RK-11 | Day-one balances wrong; agency keeps AR/AP in Excel | DC-10 | High (onboarding real agencies) | Medium | **Medium** | first live tenant migration | opening-balance model |
| RK-12 | FX gain/loss invisible in P&L; ledger drifts from cash | DC-11 | Medium | Medium | **Medium** | cross-currency settlements | realized-FX posting |
| RK-13 | Mahram/family untracked; Umrah/Hajj visa compliance gap → WhatsApp/Excel | DC-12 | Med (KSA departments) | Medium | **Medium** | Umrah/Hajj group selling | passenger_relationships |
| RK-14 | PNR/ticket + fare-hold deadline outside system → lost PNRs, no reconciliation | BF-1/DC-7 | High (ticketing) | Medium | **Medium** | real ticketing use | references + deadline |
| RK-15 | Invariant drift via direct-SQL/service_role writers (only 12 CHECKs exist) | B2 | Low-Med | Medium | **Medium** | production writers | DB CHECK constraints |
| RK-16 | No entitlement enforcement once DML grants land | RC-1/N2 | Medium | Medium | **Medium** | plan-gated capability ships | has_feature + gate |
| RK-17 | Event contract drift breaks RI/AI/ad delivery (free-text codes) | N1 | Medium | Medium | **Medium** | RI/integration build | event_type registry |
| RK-18 | Stuck internal states accumulate silently (no self-healing) | DC-8 | Medium | Low-Med | **Low-Med** | as stateful workflows grow | reconciliation sweepers |
| RK-19 | No structured observability/DR posture documented | OPS-1 | Med | Med | **Medium** | production launch | logging/metrics + RPO/RTO |
| RK-20 | Tenant exit/portability request unsatisfiable | DC-14 | Low-Med | Med (contract) | **Medium** | first churn/enterprise contract | export/purge |

**Top of register (act in Batch 0):** RK-01, RK-05, RK-04, then RK-02/03/06/07 (Batch 1–2). Tenant isolation itself is audited **solid** (no RK entry — see certification).
