# Susu Luma waterfall gate register

**Current decision:** G1 is approved by the accountable owner as a single-signer approval with recorded risk acceptances (`G1_APPROVAL_RECORD.md`). G0 and G2 evidence remains incomplete. Build work is a prototype and draft foundation only. No production release or live backend activation is authorised by this document, and independent review is required before G4.

The PRD v1.0 is marked **Draft for stakeholder review**. No gate may be treated as passed without recorded approval and evidence.

| Gate | Exit evidence required | Current status | Owner / decision needed |
|---|---|---|---|
| G0 — Initiation and feasibility | Named sponsor and Product Owner; pilot hypothesis; feasibility, budget, risks, legal/compliance dependencies | **Open** | Sponsor to name accountable owners and confirm funding/pilot |
| G1 — Requirements baseline | PRD reviewed; requirements, acceptance criteria, KPIs, exclusions and assumptions signed; unresolved TBDs risk-accepted or resolved | **Approved by owner 18 Nov 2026 — single-signer, risks accepted** ([record](G1_APPROVAL_RECORD.md)) | Signed by Joseph Momoh in all capacities. Pilot buyer/supplier representatives VACANT (required at G5). Independent reviewer required before G4 |
| G2 — UX, architecture and security design | Approved journeys, role/permission matrix, threat model, data classification/retention, architecture, admin-console design, test strategy | **In progress / not approved** — 4 of 7 artifacts do not exist ([index](G2_DESIGN_PACK_INDEX.md)) | Product, UX, Engineering, Security, Operations and Legal |
| G3 — Build and component verification | Feature implementation mapped to approved requirements; code review; static analysis; unit/widget/component tests; dependency and secret scans | **Not evidenced** | Engineering lead; CI results must be linked |
| G4 — Integration and system tests | Staging integrations; RLS and cross-tenant tests; quote/order invariants; failure/retry tests; audit checks; backup restore and measured RPO/RTO | **Not evidenced** | QA and Engineering/Security |
| G5 — UAT, security and operational readiness | Buyer/supplier/admin UAT sign-off; accessibility/usability evidence; incident/support runbooks; privacy/retention; legal and operational approvals | **Not evidenced** | Product Owner, Operations, Security, Legal/Finance and pilot users |
| G6 — Controlled pilot | Approved pilot cohort, support coverage, rollback/kill-switch plan, monitored success/safety metrics, go/no-go record | **Not authorised** | Sponsor and gate approvers |
| G7 — Operations and change control | Production ownership, incident and release process, monitoring, backups, access review, change-control board and post-launch review | **Not evidenced** | Operations and accountable service owner |

## Non-negotiable release controls

- No deployment to production until G0–G5 have documented exit approval and G6 explicitly authorises the pilot.
- The PRD approval record must be completed; implementation cannot silently turn proposed requirements into approved policy.
- Never ship Supabase service-role or other secret credentials in Flutter, repository files, build artifacts, or client configuration.
- Test row-level security using separate buyer, supplier, and administrator identities, including cross-organisation denial.
- Keep verification documents and order evidence private; grant only authorised, time-limited access.
- Payment status must remain pending/unverified without authoritative confirmation. Do not build wallet, stored value, escrow, lending, deposit-taking, money transmission, or platform settlement without explicit scope approval and local legal/regulatory review.
- Supplier verification must state what was checked and must not imply government endorsement, solvency, product certification or guaranteed quality.
- Restricted/high-risk goods categories remain blocked until category policy and required permits/moderation are approved.
- Currency, unit, quantity, delivery terms, tax/fees and exclusions must be explicit; never silently convert currency or units.
- Any post-baseline scope change requires a change request and CCB decision before work begins.

## Immediate next actions

1. Name the sponsor, Product Owner, engineering/security lead, operations lead, finance/legal reviewer and pilot representatives.
2. Review the PRD's assumptions, targets, role matrix, story acceptance criteria and open decisions; record Approve/Revise/Reject at G1.
3. Approve UX and permission/data-flow designs at G2 before implementing sensitive workflows.
4. Establish staging and test identities before applying the migration to any shared backend.
5. Link CI results and requirement-level test evidence as they become available; do not mark a gate passed based on code presence alone.
