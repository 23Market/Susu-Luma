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

## Prototype status

Two clickable prototypes with illustrative sample data. Neither connects to a backend; no Supabase project, credentials, payment provider or live integration is configured.

| Part | Where | What it demonstrates |
| --- | --- | --- |
| Mobile app (Flutter) | `lib/` | Buyer and supplier demo personas. Buyer: browse/search, product detail, RFQ form, compare quotes, accept quote, order + delivery tracking, report a problem, saved items, chat. Supplier: dashboard, listings (submitted for review), RFQ inbox, send/revise quotes, confirm orders, post delivery updates, chat. |
| Master Admin console (web) | `admin/` | 24 role-gated modules on generated demo data: executive overview and pipeline; buyer organisations; supplier verification dossiers; listings, categories/taxonomy and bulk catalogue import; the full RFQ → quotation → order → delivery → payment-reconciliation chain; support cases; reviews; promotions; analytics; global search; locations; privacy requests; system health; audit log; and a six-role permission matrix. |

Domain rules enforced in the prototypes: every price has an explicit currency and every quantity an explicit unit, with no silent conversion; accepting a quote snapshots its terms into the order; payment stays `pending_unverified` unless an authorised reconciler records matching external evidence (amount, currency and a provider reference — a mismatch is flagged, never confirmed); order, payment and fulfilment statuses move independently; privileged actions need a reason and are written to an append-only audit log; verification approval needs a complete checklist; catalogue imports create drafts only and are idempotent; contact details are masked and every reveal is logged; no escrow/wallet/stored value.

The two prototypes do not share data yet. Integration (shared Supabase backend, real auth/MFA, server-side RPCs for privileged transitions, signed evidence URLs, RLS tests) is the next gate.

## Local development

### Mobile app

1. Install the Flutter stable SDK (and an Android toolchain for devices/emulators).
2. `flutter pub get`
3. `flutter analyze` and `flutter test`
4. `flutter run` (Android) or `flutter run -d chrome` (web preview).

### Admin console

No build step and no dependencies. Serve the folder with any static server:

```bash
cd admin && python3 -m http.server 8080   # then visit http://localhost:8080
```

Files: `index.html` (shell), `styles.css`, `app.js` (core: overview, listings, users, reports, messaging, role/permission model), `modules.js` (marketplace modules and the shared directory/drawer/form framework), `boot.js` (start-up).

Use **Viewing as role** in the sidebar to switch between Super Admin, Operations Lead, Trust & Safety, Support, Finance and Analyst; the console enforces the matrix in Settings & Permissions (disabled actions, hidden evidence, refused and audited attempts). Everything runs on generated sample data held in memory — reloading resets it. UI visibility is **not** authorisation: a production build must enforce the same rules server-side (the screens document the proposed `/admin/v1` API surface). The listed status labels (Demo / Partial / API pending / Proposed) are deliberately not "production approved".

Before connecting Supabase, create separate dev/staging/prod projects, review the SQL migration with the team, test RLS against buyer/supplier/admin personas, and configure only the publishable client key via environment/build configuration. Never commit credentials.

## Waterfall gates

G0 initiation/feasibility → G1 requirements baseline → G2 UX/architecture/security design → G3 build/component verification → G4 integration/system tests → G5 UAT/security/operational readiness → G6 controlled pilot → G7 operations/change control. Each gate requires documented approval; production remains NO-GO until required evidence is complete.
