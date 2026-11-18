# Susu Luma — Sierra Leone B2B Marketplace

Flutter-first mobile marketplace for business buyers and suppliers in Sierra Leone. This repository is the development baseline; it is not production-ready.

## Product scope

- Search and browse supplier listings
- Business profiles and supplier verification status
- RFQs and structured quotations
- Buyer–supplier inquiry messaging
- Quote acceptance and order coordination
- Delivery milestones, reporting and support
- Operations/admin tooling planned as a separate responsive web console

## Recommended architecture

- **Flutter** mobile client, with feature-first folders and a thin presentation layer.
- **Supabase** managed PostgreSQL, Auth, private Storage and Realtime where justified. This balances MVP cost and managed operations while preserving SQL portability and room to scale.
- **Postgres RLS** on every exposed table; client uses only a publishable key. Never ship a service-role/secret key in the app.
- **Database constraints and server-side RPC/Edge Functions** for privileged state transitions (verification decisions, RFQ routing, quote acceptance, order snapshots, moderation). Do not trust client-supplied role claims or mutable profile metadata for authorization.
- **Private buckets** for verification documents and order evidence; time-limited signed access after authorization.
- **Environments:** local/dev, staging and production separated. Secrets managed outside source control.
- **Observability:** privacy-minimised events, audit trail for privileged actions, crash reporting and operational alerts.

## Financial/regulatory boundary

MVP supports discovery, RFQs, quotes and order/fulfilment coordination only. No platform-operated wallet, stored value, escrow, lending, deposit-taking, payment settlement or unapproved money transmission. Payment status remains `pending_unverified` unless authoritative evidence from an approved provider or authorized reconciliation confirms it. Do not advertise escrow or buyer protection without documented legal/operational approval.

## Sierra Leone defaults to validate

- Sierra Leone launch market; English-first, translation-ready.
- Display local currency as SLE when applicable; every price has explicit currency and every quantity explicit unit. No silent conversion.
- Location should be district/city/area as validated with pilot users; avoid unnecessary precise location.
- Validate supplier evidence, categories/prohibited goods, tax/invoicing, data retention, complaints, delivery and legal obligations with local counsel/operations.

## Current scaffold status

The initial commit introduces a lightweight Flutter app shell and a draft database migration. Screens currently use sample data and do not connect to a backend. No Supabase project, credentials, payment provider or live integrations have been configured.

## Local development

1. Install the Flutter stable SDK and an Android toolchain.
2. Run `flutter pub get`.
3. Run `flutter analyze` and `flutter test`.
4. Run `flutter run` on an Android emulator/device.

## Admin web foundation

The separate responsive Admin console is in `admin-web/`. It is a read-only foundation, uses server-provided capabilities, and has no live authentication or Supabase adapter. Unconfigured builds fail closed; the labelled synthetic-data mode is development-only.

1. Install Node.js 22.
2. From `admin-web/`, run `npm ci`.
3. Use `npm run dev:mock` to view the clearly labelled synthetic-data shell, or `npm run dev` to exercise the unconfigured fail-closed state.
4. Run `npm run verify` for typechecking, tests, production build and a mock-data/secret bundle check.

Do not treat this foundation as production-ready. A live adapter, sign-in/MFA enrollment, write actions, hosting headers and independent review remain outstanding.

Before connecting Supabase, create separate dev/staging/prod projects, review the SQL migration with the team, test RLS against buyer/supplier/admin personas, and configure only the publishable client key via environment/build configuration. Never commit credentials.

## Waterfall gates

G0 initiation/feasibility → G1 requirements baseline → G2 UX/architecture/security design → G3 build/component verification → G4 integration/system tests → G5 UAT/security/operational readiness → G6 controlled pilot → G7 operations/change control. Each gate requires documented approval; production remains NO-GO until required evidence is complete.
