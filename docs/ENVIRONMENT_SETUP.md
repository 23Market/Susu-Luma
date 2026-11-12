# Susu Luma environment and backend foundation

**Status:** Setup guide only. No Supabase project is currently connected and no migration is applied.

## Environment separation

Provision independent Supabase projects for development, staging and production. Do not reuse production personal/business data in development. Record project owner, project reference, region, purpose, access owners and backup responsibility in the private operations register; do not commit project secrets or credentials.

## Client configuration

1. Copy `.env.example` to an untracked local `.env` for reference, or provide values through the build/CI secret store.
2. Configure only `SUPABASE_URL` and the project's publishable key in a Flutter client build.
3. Keep `service_role`, secret API keys, database passwords and signing credentials in server-side secret storage only. Never use a `--dart-define` to pass privileged secrets into a mobile build.
4. Use different values for each environment. Never paste secrets into issues, pull requests, logs or screenshots.
5. Rotate any credential that has been exposed.

The current Flutter dependency manifest does not yet include the Supabase client package. Add and pin it only in the implementation change that wires the approved client integration, and commit the lockfile.

## Database and migration gate

The existing `supabase/migrations/20261017000100_marketplace_foundation.sql` is a draft. It has not been applied to a Supabase project and must not be treated as production schema.

Before applying it anywhere shared:
- Review schema, constraints, indexes, enum/state design and data retention with product and engineering owners.
- Complete the permission matrix and threat model.
- Test all exposed-table RLS policies for buyer, supplier, support, operations, finance and admin personas.
- Implement and test atomic organisation plus owner-membership onboarding.
- Verify private storage access for verification and order evidence.
- Confirm rollback/recovery approach and take a verified backup.
- Apply first to a disposable development database, run tests and advisors, then seek explicit approval for staging.
- Production requires a separate release approval and backup/restore evidence.

Do not create permissive client write policies to make the scaffold work. Privileged transitions (verification, RFQ routing, quote acceptance, order snapshots, payment reconciliation, moderation and audit) require reviewed server-side authorization and auditable transactions.

## Required backend implementation sequence

1. Confirm project ownership and create isolated dev/staging/prod Supabase projects.
2. Agree G1 policy decisions in issue #7; unresolved legal/operational choices remain blockers.
3. Review the draft schema and create migrations through the Supabase CLI workflow.
4. Implement authentication, server-controlled permissions and organization membership.
5. Add RLS and negative/positive cross-organisation tests.
6. Add private storage policies and short-lived authorized evidence access.
7. Implement audited, idempotent server-side state transitions.
8. Configure CI secrets only after CI environment owners are assigned.
9. Run migration, security, contract and end-to-end checks before any shared deployment.

## Existing CI

The repository already has `.github/workflows/flutter.yml` running dependency resolution, formatting, `flutter analyze` and `flutter test` on pushes and pull requests to `main`. Extend that workflow or add separate workflows when backend code and a reproducible local Supabase test environment are introduced. Do not add placeholder credentials or make CI depend on a live production project.

## Open prerequisites

- Supabase organization/project owner and project references.
- Environment and region decision.
- Approved G1 verification, routing, payment, delivery, support, analytics, geography and retention policies.
- Approved permission matrix and reviewed migration.
- Named owners for deployment, backups, incident response and key rotation.
