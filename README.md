# ORVION

ORVION is the working repository for a travel CRM / operations / revenue platform for Egyptian travel agencies (flights, Umrah, Hajj, visa, hotels, tours). The backend is Supabase/PostgreSQL — SQL migrations + `app`-schema RPCs.

**This file has one job: orient you inside the repository and route you to the right authority in a single hop.** It does not restate the boot sequence, the rules, or the current status — each of those has exactly one home, linked below (One Authority — `GOVERNANCE.md §2`). It is a router, not a second authority.

## Start here

**To develop, review, or operate ORVION — human or AI → run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Boot`.** `AGENTS.md §3–§4` defines the conduct and fallback routing; Boot derives live state and the smallest required context from repository authorities.

**Repository initialization is deterministic.** Boot determines whether the repository is ready, blocked, or in PLAN; reading remains unrestricted, while implementation writes require an active approved CR.

## Where things live (authorities)

| You want… | Go to |
|---|---|
| Runtime mode / exact next action | `scripts/check_agent_continuity.ps1 -Boot` + `AGENTS.md §3–§4` |
| How work is done — conduct, standing authorities, decision tiers | `AGENTS.md` |
| Where every fact lives — SSOT matrix, decision & document lifecycles, write-permissions | `GOVERNANCE.md` |
| Change Request state machine & command vocabulary | `CR_LIFECYCLE.md` |
| Current phase, module, and Active Change Request (live state) | `_ORVION_CANONICAL/manifest.md` |
| Business & schema canon (source of truth for domain/schema intent) | `_ORVION_CANONICAL/**` |
| As-built schema truth | `supabase/migrations/**` |
| Coding / SQL / API / security standards | `CODING_STANDARDS.md` |
| Project identity, vision, boundaries | `PROJECT_CONTEXT.md` |
| Rationale, findings, ADRs, deferred backlog | `reports/` (index: `reports/README.md`) |
| Full document registry (what each file owns) | `GOVERNANCE.md §5` |

**Repository policy:** the repository is self-describing and has no chat-history prerequisite. `AGENTS.md` governs execution conduct and the boot process; `GOVERNANCE.md` governs knowledge authority and placement; the boot process routes each question to the current authoritative document and ground truth. There is exactly one start instruction, and it is the Boot command above.
