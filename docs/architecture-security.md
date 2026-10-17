# Architecture and security decisions (Gate G2 draft)

## Recommendation
Use Flutter for the Android-first mobile client and Supabase for managed PostgreSQL, Auth, private object storage and selectively enabled Realtime. This is a pragmatic early-stage cost/operations balance while keeping core data in PostgreSQL and reducing dependence on a proprietary domain model.

## Trust boundaries
- Flutter is an untrusted client. Enforce authorization and state transitions in Postgres RLS and reviewed server-side functions, not in hidden UI controls.
- Only publishable client credentials may ship in the app. Never include service-role or secret keys in Dart, assets, build config committed to Git, or crash logs.
- Separate development, staging and production projects; no production personal/business data in development.
- Verification documents, private RFQs, conversations, order evidence and support cases are private by default. Use private storage buckets and short-lived signed URLs only after authorization.
- Treat role/permission information as server-controlled. Never authorize using user-editable profile metadata.
- Audit privileged operations with actor, timestamp, action, reason and relevant entity reference. Restrict who can read audit data.
- Add rate limits, upload type/size limits, abuse reporting, moderation queue and retention/deletion policy before pilot.

## Domain boundaries
- Local amounts carry explicit ISO currency codes; quantities carry explicit units. No implicit currency or unit conversions.
- Quote versions are immutable once submitted; order acceptance snapshots the exact quote version and terms.
- payment_status begins at pending_unverified. Do not add wallet, escrow, lending, deposit-taking, payment settlement, or funds custody. An eventual external payment status integration requires legal/compliance review, provider approval, authenticated webhooks and reconciliation.
- Supplier verification is private review workflow; public display must state only the approved scope/status. Sample UI data is not proof of real verification.
- Controlled/high-risk goods stay blocked or manually gated pending policy and permit review.

## Migration status
supabase/migrations/20261017000100_marketplace_foundation.sql is a draft schema only. It has not been applied to a Supabase project and is not production approved. It intentionally has no broad client write policies for RFQ routing, quote acceptance, orders, payment status, verification decisions or audit events. Organization onboarding needs a reviewed transaction/RPC to create the organization and its owner membership atomically before it is usable.

## Gate criteria
- G0: sponsor, product owner, pilot scope and resource assumptions.
- G1: stakeholder-approved workflows, taxonomy, verification/prohibited-goods policy, local legal/privacy review and open decisions.
- G2: UX, API/data contract, RLS matrix, threat model, hosting, environments, recovery and test strategy approved.
- G3: code review, CI, unit/widget tests, migration review and security/dependency checks pass.
- G4: role-based negative tests, network retry/idempotency, end-to-end flows and restore test pass.
- G5: UAT, privacy/security approval, support and incident runbooks, rollback/restore and training.
- G6: limited pilot and explicit sponsor GO; no unresolved severe trust/safety issue.
- G7: monitoring, incident management, monthly KPI review and change control.
