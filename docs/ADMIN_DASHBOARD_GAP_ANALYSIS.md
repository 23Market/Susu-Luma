# Susu Luma Admin Dashboard Gap Analysis & Delivery Plan

**Status:** Proposed delivery baseline; requires Product Owner and stakeholder approval  
**Source baseline:** Susu Luma PRD & User Stories v1.0 (17 October 2026, draft for stakeholder review)  
**Repository:** 23Market/Susu-Luma  
**Workstream rule:** Frontend and Backend are independently tracked GitHub workstreams. Integration is a third coordination/test workstream. This document does not claim that proposed screens, endpoints, or integrations already exist.

## 1. Purpose and status vocabulary

This document turns the PRD into an implementation plan for the responsive operations/admin console and its supporting backend. Use these labels in reviews:

- **Existing:** confirmed in the repository today.
- **Partial:** some foundation exists but does not satisfy the complete requirement.
- **Proposed:** target capability described here, not yet implemented.
- **Blocked by decision:** implementation depends on an outstanding product, legal, operational, or architecture decision.
- **Verified:** demonstrated by automated tests and/or recorded UAT evidence.

The repository README describes a Flutter-first mobile app, Supabase as the recommended managed backend, and a responsive web/admin console as planned. It also states that the current scaffold uses sample data, has no live Supabase project/credentials/integrations configured, and is not production-ready. The architecture/security note says the initial SQL migration is draft-only and not applied to a Supabase project. Treat live admin/backend integration as **not yet established** until proven by code and environment evidence.

## 2. PRD traceability and scope

| Admin capability | PRD requirements | User stories | Priority |
|---|---|---|---|
| Supplier verification and organisation administration | FR-001/002/003, FR-020, FR-022 | SL-003, SL-004, SL-024, SL-027 | P0 |
| Listing/category moderation | FR-004/005/007, FR-020, FR-022 | SL-006, SL-007, SL-009, SL-010, SL-024, SL-034 | P0 |
| RFQ operations | FR-008/009, FR-020 | SL-011, SL-012 | P0 |
| Quotations and comparison oversight | FR-010/011, FR-022 | SL-013, SL-014, SL-015 | P0 |
| Order and fulfilment oversight | FR-013/015/016, FR-022 | SL-017, SL-018, SL-020, SL-021 | P0 |
| Payment status/reconciliation evidence | FR-014, FR-022 | SL-019, SL-035 | P0 |
| Support, complaints and reports | FR-021/022 | SL-025, SL-028 | P0 |
| Audit trail | FR-022 | SL-027 | P0 |
| Operational reporting | FR-023 | SL-026 | P0 |
| Reviews/reputation moderation | FR-018 | SL-022 | P1 |
| Data access/correction/deletion requests | FR-026 | SL-031 | P1 |
| Bulk catalogue import | FR-004 + operations | SL-032 | P1 |
| Low-bandwidth and localization readiness | FR-024/025 | SL-029, SL-030 | P0 |
| Global cross-entity search | supports FR-020/021 | related admin stories | P1 |

### MVP financial boundary

The PRD excludes a Susu Luma-operated wallet, stored value, escrow, lending, credit scoring, deposit-taking and payment settlement from the MVP. The admin console may record payment method intent, provider/reference/status and authorised reconciliation evidence, but must not represent an unverified report as paid or imply that Susu Luma holds or settles customer funds. Payment state, order state and fulfilment state must remain separate.

## 3. Recommended navigation

1. Overview
2. Marketplace
   - Listings
   - Categories & attributes
   - Listing reports / moderation queue
3. Suppliers & organisations
   - Supplier directory
   - Verification queue
   - Organisation memberships
4. Procurement
   - RFQs
   - Quotations
   - Orders
   - Fulfilment & delivery issues
   - Payment status records
5. Trust & support
   - Support cases
   - Complaints and suspicious activity
   - Reviews & reputation (P1)
6. Analytics & reports
7. Audit & governance
   - Audit log
   - Data/privacy requests (P1)
8. Catalogue operations
   - Bulk import (P1)
9. System operations
   - Service health, backups and resilience (P1)
10. Settings & access
    - Staff roles and permissions
    - Operational configuration

Navigation visibility is not a security boundary. Every API read and write must enforce server-side permissions and record scope.

## 4. Delivery workstreams — keep separate in GitHub

### Workstream A — Frontend

**GitHub label:** `susu-luma-frontend`  
**Owns:** responsive admin console UX, screens, navigation, tables, detail views, timelines, filters, forms, client-side validation, accessible interactions and loading/empty/error/success/offline states.

Frontend deliverables:
- Admin app shell, role-aware navigation and responsive layout.
- Overview cards and operational dashboards.
- Searchable, filterable, server-paginated queues.
- Detail pages with status history, evidence previews and related records.
- Reasoned action dialogs for approve/reject/pause/restore/assign/escalate.
- Clear separation of internal notes and user-visible responses.
- Masked PII by default; reveal UI only when permitted and purpose is supplied.
- Export controls gated by role and explained before download.
- English-first strings, localization-ready labels, explicit currency and units.
- Accessibility, keyboard operation, touch targets and low-bandwidth feedback.

Frontend must not invent authorization based on hidden buttons. It consumes permissions supplied by the authenticated backend and gracefully handles 401/403/409/422/429/5xx responses.

### Workstream B — Backend

**GitHub label:** `susu-luma-backend`  
**Owns:** database schema/migrations, API/data contracts, authentication/authorization, RLS, validation, business rules, audit events, idempotency, integrations, privacy controls and automated tests.

Backend deliverables:
- Canonical data model and migration review.
- Server-side RBAC and organisation/record scoping.
- Secure verification evidence access and review decisions.
- Listing/category moderation transitions with reason and audit.
- RFQ ownership, recipient routing and access checks.
- Quote versions and immutable accepted-quote/order snapshots.
- Separate order, payment and fulfilment state machines.
- Payment provider/reference evidence; no false paid state.
- Case lifecycle, assignment, escalation and internal/public note distinction.
- Append-only audit events for privileged actions.
- Idempotent writes and safe retry semantics.
- Data export/deletion request controls under approved retention policy.
- Contract, RLS, security, migration and integration tests.

Backend must be the authority for permissions, validation, transitions, timestamps, audit and record visibility. Never trust client-supplied role claims or mutable profile metadata.

### Workstream C — Shared integration

**GitHub label:** `susu-luma-integration`  
**Owns:** agreed API schemas, generated/client models where useful, contract versioning, frontend/backend integration, environment configuration, end-to-end tests, release coordination and cross-workstream defect triage.

Integration deliverables:
- OpenAPI/JSON schema or equivalent versioned contract for each feature.
- Example success and error payloads.
- Contract compatibility checks in CI.
- Dev/staging/prod environment separation and secret handling.
- E2E tests against a disposable or staging environment.
- Test personas for buyer, supplier, support, operations, finance and super-admin.
- Release evidence and rollback notes.

### Ownership and dependency rules

- Create distinct Frontend and Backend issues for each feature; create an Integration issue when a feature crosses the boundary.
- Frontend issue links to its Backend contract dependency. Backend issue links to the consuming Frontend issue.
- Backend contract is agreed before UI integration; UI can use clearly marked mocks while the contract is pending.
- No feature is Done until both workstreams pass their acceptance criteria and integration tests pass.
- Do not combine frontend and backend changes into one issue merely for convenience.
- Use branches such as `feat/frontend-rfq-workbench`, `feat/backend-rfq-api`, and `test/integration-rfq-flow`; use PRs into main after review and checks.

## 5. Admin capability specifications

Each module below needs separate frontend/backend issues. API paths are **proposed contract examples**, not existing endpoints.

### ADM-01 — RFQ management (P0)

**Frontend screens**
- RFQ queue with status, age, buyer organisation, item count, destination, target date, response state and assigned operator.
- Filters for status, date, category, buyer, supplier, overdue and flagged.
- RFQ detail: line items, quantities/units, destination, attachments, buyer notes, invited/matched suppliers, routing history, linked quotes and messages.
- Actions: view, assign, flag, add internal note, investigate report, escalate and apply an authorised status action.

**Backend**
- Permission-scoped list/detail reads, stable pagination and filters.
- Enforce buyer/organisation ownership and eligible supplier access.
- Routing record includes recipient and reason/eligibility explanation.
- Audit admin assignment, flags and privileged status changes.
- Idempotent write operations and attachment authorization.

**Proposed contracts:** `GET /admin/rfqs`, `GET /admin/rfqs/{id}`, `GET /admin/rfqs/{id}/routing`, `POST /admin/rfqs/{id}/assign`, `POST /admin/rfqs/{id}/notes`, `POST /admin/rfqs/{id}/flags`.

**Acceptance**
- Unauthorized users cannot enumerate or open RFQs outside scope.
- Queue filters and pagination are server-backed.
- Every routing recipient is explainable and only eligible parties can access the RFQ.
- Retry does not create duplicate assignment/note/action records.
- Admin actions are auditable with actor, timestamp and reason.

### ADM-02 — Quotation management (P0)

**Frontend**
- Quote queue and RFQ-linked comparison view.
- Quote detail with line items, price, currency, unit, MOQ, fees/taxes where known, lead time, validity, delivery/collection terms, exclusions and version history.
- Highlight unit/currency differences; never silently convert totals.
- Show withdrawn, expired, revised and accepted versions distinctly.

**Backend**
- Preserve quote versions and revision/withdrawal actor/time.
- Validate quantities, units, currency and validity.
- Buyer comparison only for quotes accessible to that buyer.
- Accepted quote creates an immutable order snapshot.
- Audit privileged intervention; protect commercial data by organisation membership.

**Proposed contracts:** `GET /admin/quotes`, `GET /admin/quotes/{id}`, `GET /admin/rfqs/{id}/quotes`, `GET /admin/quotes/{id}/versions`.

**Acceptance**
- Version history is complete and immutable.
- Different units/currencies are not combined into misleading totals.
- Accepted quote snapshot matches the exact revision accepted.
- Access is denied across unrelated organisations.

### ADM-03 — Orders & fulfilment (P0)

**Frontend**
- Order queue with order status, fulfilment status and payment status displayed as separate fields.
- Order detail with accepted quote snapshot, parties, terms, milestone timeline, partial deliveries, evidence, exceptions and support cases.
- Actions: assign investigation, add internal note, flag, view evidence and apply permitted operational transitions.

**Backend**
- Enforce valid order and fulfilment state transitions.
- Preserve immutable accepted commercial snapshot.
- Record milestone actor, timestamp, quantity/unit and evidence references.
- Support partial delivery and issue workflows.
- Keep historical order data available to authorised participants if a listing/supplier is suspended.

**Proposed contracts:** `GET /admin/orders`, `GET /admin/orders/{id}`, `GET /admin/orders/{id}/timeline`, `POST /admin/orders/{id}/notes`, `POST /admin/orders/{id}/investigations`.

**Acceptance**
- Delivered never implies paid; payment confirmation never implies delivery.
- Partial delivery is represented explicitly.
- Evidence access is private and permission-checked.
- Invalid state transitions are rejected and logged where security-relevant.

### ADM-04 — Payment status & reconciliation evidence (P0)

**Frontend**
- Payment records queue with pending/unverified, confirmed, failed, reversed and disputed states where supported by the approved model.
- Detail includes provider, external reference, amount/currency, evidence source, reconciliation actor/time and linked order.
- Clear “reported” vs “verified” distinction.

**Backend**
- Store provider/reference/status evidence; validate idempotent provider callbacks or authorised reconciliation.
- Restrict confirmation/reversal to approved permissions and evidence.
- Append audit event for reconciliation.
- Do not implement wallet, stored value, escrow, lending or settlement under this scope.

**Proposed contracts:** `GET /admin/payment-records`, `GET /admin/payment-records/{id}`, `POST /admin/payment-records/{id}/reconcile`, `POST /admin/payment-records/{id}/evidence`.

**Acceptance**
- Unverified report remains pending/unverified.
- Duplicate provider event does not duplicate state changes.
- All confirmation/reversal actions identify actor/evidence.
- UI never describes Susu Luma as holding or settling funds.

### ADM-05 — Support & case management (P0)

**Frontend**
- Unified queue for help requests, complaints, suspicious-activity reports, delivery issues and listing reports.
- Filters for type, severity, status, owner, age and SLA/overdue.
- Case detail with reference, reporter, related entities, private evidence, public replies, internal notes, assignment and escalation timeline.
- Actions: claim, assign/reassign, request information, escalate, resolve and reopen where policy allows.

**Backend**
- Case lifecycle and status validation.
- Separate internal notes from user-visible messages.
- Enforce attachment and reporter privacy.
- Audit assignment, escalation, status and sensitive evidence access.
- Define notification events and delivery/retry behavior.

**Proposed contracts:** `GET /admin/cases`, `GET /admin/cases/{id}`, `POST /admin/cases/{id}/assign`, `POST /admin/cases/{id}/notes`, `POST /admin/cases/{id}/reply`, `POST /admin/cases/{id}/transition`.

**Acceptance**
- Every case has a reference and traceable status history.
- Internal notes are never exposed to end users.
- Critical reports can be identified for the PRD's proposed one-business-day initial review target (target requires stakeholder approval).
- Every privileged case action is audited.

### ADM-06 — Supplier verification & organisation administration (P0)

**Frontend**
- Verification queue with completeness, age, risk flags and assigned reviewer.
- Dossier with submitted business details, evidence checklist, expiry/validity, review history and request-more-information workflow.
- Organisation profile with owners, members, roles and membership history.
- Explicit separation between identity/business verification and any endorsement of product quality or solvency.

**Backend**
- Private evidence storage and signed, short-lived access after authorization.
- Atomic organisation + owner membership creation.
- Duplicate prevention, verification state transitions and reviewer separation-of-duties where policy requires.
- Record reason, actor, time and before/after for privileged decisions.

**Proposed contracts:** `GET /admin/verification-cases`, `GET /admin/verification-cases/{id}`, `POST /admin/verification-cases/{id}/decision`, `POST /admin/verification-cases/{id}/request-information`, `GET /admin/organisations/{id}`, `POST /admin/organisations/{id}/memberships`.

**Acceptance**
- Buyers cannot access private verification documents.
- Only authorized reviewers can approve/reject/request information.
- Organisation ownership/membership is consistent and duplicate-safe.
- Verification decision has an auditable reason and reviewer identity.

### ADM-07 — Operational analytics & reporting (P0)

**Frontend**
- Overview of active suppliers, published listings, RFQ volume, first-response time, quote rate, order states, complaints and verification backlog.
- Date range and relevant category/district/status filters.
- Metric definitions, timezone and last-updated timestamp.
- Role-gated exports.

**Backend**
- Define canonical metric formulas, source events, timezone and refresh cadence.
- Permission-scoped aggregation and export.
- Privacy minimization; avoid exposing unnecessary PII in analytics.
- Record export actor, scope and time.

**Proposed contracts:** `GET /admin/metrics/overview`, `GET /admin/metrics/rfqs`, `GET /admin/metrics/verification`, `POST /admin/exports`.

**Acceptance**
- Metric definitions are documented and consistent.
- Export data matches visible filters and role scope.
- PRD targets are clearly marked as proposed planning baselines, not actual performance.

### ADM-08 — Reviews & reputation moderation (P1)

**Frontend:** eligible review queue, linked order context, report reasons, moderation decision and history.  
**Backend:** enforce completed-transaction eligibility, prevent duplicate/fraudulent reviews, record moderation reason and audit.  
**Proposed contracts:** `GET /admin/reviews`, `GET /admin/reviews/{id}`, `POST /admin/reviews/{id}/decision`.  
**Acceptance:** only eligible transactions can create reviews; moderation does not erase audit history.

### ADM-09 — Global search (P1)

**Frontend:** unified search across permitted users, organisations, listings, RFQs, quotes, orders and cases; result type and status clearly identified.  
**Backend:** permission-filtered search, bounded query length, rate limits, PII masking and audit for sensitive search/reveal.  
**Proposed contract:** `GET /admin/search?q=...`.  
**Acceptance:** search cannot bypass entity-level access controls or expose masked personal data.

### ADM-10 — Data & privacy requests (P1)

**Frontend:** request queue, identity/authority check, scope, legal hold/retention flags, tasks, approval and completion evidence.  
**Backend:** controlled access/correction/export/deletion/closure workflows, retention rules, legal holds, irreversible-action confirmation and completion audit.  
**Proposed contracts:** `GET /admin/data-requests`, `GET /admin/data-requests/{id}`, `POST /admin/data-requests/{id}/decision`, `POST /admin/data-requests/{id}/complete`.  
**Acceptance:** no deletion occurs without approved policy and authority; legally required records are retained.

### ADM-11 — Bulk catalogue import (P1)

**Frontend:** downloadable template, upload progress, column mapping, row validation, preview, error report and import history.  
**Backend:** file validation, size/type limits, all-or-nothing draft creation, duplicate detection, idempotent submission and audit.  
**Proposed contracts:** `POST /admin/catalogue-imports`, `GET /admin/catalogue-imports/{id}`, `POST /admin/catalogue-imports/{id}/commit`.  
**Acceptance:** invalid batches do not partially publish; import creates drafts for moderation, not public listings.

### ADM-12 — System health & resilience (P1)

**Frontend:** service status, recent incidents, queue/backlog indicators, backup/restore evidence, maintenance notices and last successful checks.  
**Backend/operations:** health probes, privacy-minimized observability, alerting, backup/restore drills, RPO/RTO evidence and incident audit.  
**Proposed contracts:** `GET /admin/system/health`, `GET /admin/system/incidents`, `GET /admin/system/recovery-evidence`.  
**Acceptance:** health distinguishes internal faults from third-party outages; recovery claims are backed by a non-production restore drill.

## 6. Shared interface and API standards

### Frontend standards
- Server-side pagination/filtering for operational queues.
- Consistent loading, empty, error, permission-denied and stale-data states.
- Detail pages show last-updated time and source context.
- Destructive actions require confirmation and a reason where policy specifies.
- Mask personal data by default; display purpose and authorization state for reveal.
- Explicit currency and quantity units; no silent conversion.
- Clear upload progress, retry and offline/draft behavior.
- Accessible keyboard focus, labels, contrast and touch targets.
- Avoid optimistic success for privileged actions until server confirms.

### Backend standards
- Server-side permission checks on every read/write; scope queries before returning records.
- RLS for exposed Supabase tables; client receives only publishable key.
- Validate all inputs server-side; enforce constraints in database where possible.
- Idempotency keys for retryable mutations and provider callbacks.
- Audit event written atomically with privileged state change; include actor, timestamp, action, reason and before/after where feasible.
- Private storage for verification and delivery evidence; signed URLs time-limited and authorized.
- Stable error envelope with field errors and correlation/request ID.
- No secrets or service-role key in Flutter app or repository.
- Automated tests for RLS, cross-organisation access, state transitions, replay, audit failure and authorization refusal.

### Integration standards
- Contract changes reviewed by both workstreams before implementation.
- Version API schemas; document required/optional fields, enum values and error behavior.
- Contract tests run in CI; E2E verifies business-critical journeys.
- Dev, staging and production are separate; secrets stored outside source control.
- Migrations are reviewed, reversible where feasible, and tested on a disposable database before staging.
- Release notes state migrations, feature flags, operational steps and rollback approach.

## 7. Proposed permission groups

These are functional permission groups, not final role names. Map them to the approved role model before implementation.

| Permission group | Typical scope |
|---|---|
| Super administrator | Full platform administration; sensitive actions still audited |
| Operations | Listings, RFQs, orders, fulfilment and supplier operations |
| Trust & Safety | Verification, reports, moderation and investigations |
| Support | Cases, user-visible replies and limited related-record access |
| Finance/reconciliation | Payment records and reconciliation evidence only |
| Analyst | Aggregated metrics and approved exports; no unnecessary PII |

Use least privilege, record-level scope, separation of duties for high-risk decisions and periodic access review. Hiding a menu item is not authorization.

## 8. UAT and release gates

Mandatory end-to-end scenarios from the PRD should include:
1. Supplier registers, submits evidence, receives a request for more information, resubmits and is approved; private documents remain inaccessible to buyers.
2. Approved supplier publishes a complete listing with explicit unit and price mode; admin moderates it; buyer discovers it.
3. Buyer submits a multi-item RFQ; network interruption/retry creates one RFQ only; only eligible recipients access it.
4. Two suppliers submit quotes with different currencies/units; comparison flags differences and avoids misleading converted totals.
5. Buyer accepts one quote revision; seller confirms; order snapshot matches accepted version.
6. Payment is reported without provider confirmation; state remains pending/unverified and no paid badge appears.
7. Supplier records dispatch and partial delivery; buyer opens issue; admin reviews evidence; transitions retain actor/time.
8. Admin suspends supplier/listing; discovery visibility changes but historical order records remain available to authorized parties.
9. Cross-organisation access attempts against listing, RFQ, message, verification document and order are denied and security events logged.
10. Backup is restored in non-production and documented RPO/RTO is measured.

Release gates:
- **Product:** approved PRD baseline, policy decisions and metric definitions.
- **Design/architecture:** UX review, data model, threat model, API contracts and RLS design.
- **Build:** frontend/backend unit and component tests, migration checks and code review.
- **Integration:** contract tests and E2E journeys pass in staging.
- **Security/privacy:** access-control tests, secret scan, evidence-storage review and audit verification.
- **Operations/UAT:** support procedures, incident response, backup restore, user acceptance and stakeholder sign-off.
- **Production:** explicit approval; current repository baseline is not production-ready.

## 9. Decisions that must remain visible blockers

Do not silently resolve these in code:
- Supplier verification evidence and renewal policy.
- RFQ supplier routing/matching rules.
- Quote acceptance, seller confirmation, cancellation and expiry rules.
- Approved payment provider and out-of-app payment/reconciliation model.
- Delivery liability, proof-of-delivery and dispute escalation.
- Support operating hours and escalation SLA.
- Analytics/consent policy and export permissions.
- Pilot geography, district coverage and localization priorities.
- Data retention, deletion and legal hold rules.
- Category/prohibited goods and controlled commodity policy.

## 10. Delivery sequence

1. Confirm G1 requirements baseline and decisions needed for G2.
2. Approve data model, role/permission matrix, audit model and API contracts.
3. Establish admin shell, navigation, auth and role-aware empty states (Frontend) alongside schema/RLS/auth foundations (Backend).
4. Deliver supplier verification and listing moderation.
5. Deliver RFQ and quotation operations.
6. Deliver order, fulfilment and payment-status visibility.
7. Deliver support/case management and audit.
8. Deliver reporting.
9. Deliver P1 reviews, privacy requests, bulk import and system resilience.
10. Run UAT, security review, restore drill and controlled pilot readiness.

**Definition of Done:** frontend acceptance criteria met; backend authorization/validation/audit/idempotency tests pass; contract and E2E tests pass; documentation updated; no unresolved critical security issue; operational owner and release evidence recorded.

## 11. GitHub work item breakdown

Create separate issues, linked by feature ID. Suggested epics:
- **Frontend epic:** Admin console shell and all ADM-01..ADM-12 screens/interactions.
- **Backend epic:** Admin data/API/RLS/audit foundations and all ADM-01..ADM-12 service capabilities.
- **Integration epic:** contract registry, environments, CI contract tests and critical E2E journeys.

For each ADM feature, create one frontend issue and one backend issue; create an integration issue when the feature has cross-boundary behavior. Include the ADM identifier in every issue title and use the workstream labels `susu-luma-frontend`, `susu-luma-backend`, `susu-luma-integration` when those labels are available in the repository. Until labels are created, keep the exact workstream identifier in each issue title/body.

## 12. Important source notes

This plan is derived from the Susu Luma PRD & User Stories v1.0, which is explicitly a draft for stakeholder review. PRD success measures (including RFQ response, listing completeness, report triage and availability targets) are proposed planning baselines, not measured live performance or approved service commitments. User-story IDs and FR references should be retained in issue descriptions for traceability. Any change to the approved baseline should follow the PRD's change-control process.
