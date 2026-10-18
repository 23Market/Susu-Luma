# Susu Luma — Sierra Leone B2B Marketplace

Flutter-first mobile marketplace for business buyers and suppliers in Sierra Leone. This repository is the development baseline; it is not production-ready.

## Product scope

- Search and browse supplier listings
- Business profiles and supplier verification status
- RFQs and structured quotations
- Buyer–supplier inquiry messaging
- Quote acceptance and order coordination
- Delivery milestones, reporting and support
- Responsive operations/admin dashboard for supplier plans, RFQs, verification, revenue modelling and service queues

## Recommended architecture

- **Flutter** mobile client, with feature-first folders and a thin presentation layer.
- **Supabase** managed PostgreSQL, Auth, private Storage and Realtime where justified. This balances MVP cost and managed operations while preserving SQL portability and room to scale.
- **Postgres RLS** on every exposed table; client uses only a publishable key. Never ship a service-role/secret key in the app.
- **Database constraints and server-side RPC/Edge Functions** for privileged state transitions (verification decisions, RFQ routing, quote acceptance, order snapshots, moderation). Do not trust client-supplied role claims or mutable profile metadata for authorization.
- **Private buckets** for verification documents and order evidence; time-limited signed access after authorization.
- **Environments:** local/dev, staging and production separated. Secrets managed outside source control.
- **Observability:** privacy-minimised events, audit trail for privileged actions, crash reporting and operational alerts.
- **Authentication:** web sessions terminate at a same-origin auth API using Secure, HttpOnly, SameSite=Strict cookies; native sessions use Android Keystore/iOS Keychain storage. Admin access requires a server-authorised role and AAL2 MFA.

## Financial/regulatory boundary

MVP supports discovery, RFQs, quotes and order/fulfilment coordination only. No platform-operated wallet, stored value, escrow, lending, deposit-taking, payment settlement or unapproved money transmission. Payment status remains `pending_unverified` unless authoritative evidence from an approved provider or authorized reconciliation confirms it. Do not advertise escrow or buyer protection without documented legal/operational approval.

## Sierra Leone defaults to validate

- Sierra Leone launch market; English-first, translation-ready.
- Display local currency as SLE when applicable; every price has explicit currency and every quantity explicit unit. No silent conversion.
- Location should be district/city/area as validated with pilot users; avoid unnecessary precise location.
- Validate supplier evidence, categories/prohibited goods, tax/invoicing, data retention, complaints, delivery and legal obligations with local counsel/operations.

## Current scaffold status

The repository contains Android, iOS and web runner projects around a shared Flutter codebase. The marketplace catalogue still uses local sample data. The admin dashboard is connected in code to the Supabase reporting and moderation API: it reads live RFQ, supplier, revenue and operations data and can review suppliers, moderate listings and resolve support cases. Authentication remains disabled unless valid build-time configuration is supplied. No shared Supabase project or payment provider has been configured from this repository.

The admin dashboard is available through the Business profile screen or the `/admin` route on web. Its financial figures come from recognized `revenue_events`; plan prices and unit-economics thresholds are business targets rather than financial results. Web reads and mutations pass through the same-origin auth API. Native builds use AAL2-protected database functions. Every moderation mutation rechecks platform-admin membership on the server and writes an audit event.

## Local development

1. Install the Flutter stable SDK and an Android toolchain.
2. Run `flutter pub get`.
3. Run `flutter analyze` and `flutter test`.
4. Run `flutter run` on an Android emulator/device, iOS simulator/device, or browser.

To connect an approved non-production Supabase project, provide its HTTPS URL and publishable client key at build or run time:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

The app deliberately stays in offline prototype mode when either value is absent or invalid. Never supply a Supabase service-role key to a Flutter build.

For web deployment, configure `AUTH_API_BASE_URL` and `TURNSTILE_SITE_KEY`, deploy `supabase/functions/auth-api`, and reverse proxy the auth path on the same HTTPS origin. Follow [docs/auth-security.md](docs/auth-security.md); a direct browser-to-Supabase session is deliberately disabled on web.

Release builds:

- Android: `flutter build appbundle --release` for Play Store delivery or `flutter build apk --release` for direct installation.
- iOS: `flutter build ipa --release` on macOS with Xcode and configured Apple signing.
- Web: `flutter build web --release`.

Before connecting Supabase, create separate dev/staging/prod projects, review the SQL migration with the team, test RLS against buyer/supplier/admin personas, and configure only the publishable client key via environment/build configuration. Never commit credentials.

## Waterfall gates

G0 initiation/feasibility → G1 requirements baseline → G2 UX/architecture/security design → G3 build/component verification → G4 integration/system tests → G5 UAT/security/operational readiness → G6 controlled pilot → G7 operations/change control. Each gate requires documented approval; production remains NO-GO until required evidence is complete.
