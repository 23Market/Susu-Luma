# Supabase backend

Postgres is the authority. The Flutter app and the web console are **untrusted clients**: they hold only a publishable key, read data through row-level security (RLS) and change state only through the reviewed `SECURITY DEFINER` functions below. Nothing here has been applied to a hosted project — create separate dev / staging / prod projects first (see the root README).

## Migrations (apply in order)

| File | What it adds |
| --- | --- |
| `20261017000100_marketplace_foundation.sql` | Original draft schema (organisations, listings, RFQs, quotes, orders, delivery, audit). |
| `20261101000100_taxonomy_and_admin_access.sql` | B2B category taxonomy; admin roles/permissions (seed **generated from `admin/app.js`**); `aal2` (MFA) enforcement; append-only audit; role administration. |
| `20261101000200_marketplace_workflows.sql` | Fixes foundation gaps (a seller could insert a pre-published listing; organisations had no owner). Tenant read rules; RPCs for organisations, listings, verification, RFQ → quote → accept → order → delivery, payment *assertions*, messaging, notifications. |
| `20261101000300_admin_operations.sql` | Admin read policies; evidence-masking verification view; `admin_*` RPCs: verification, listing moderation (category scoped), payment reconciliation, order disputes. |
| `20261101000400_storage_policies.sql` | Private `evidence` bucket and policies (skipped where the `storage` schema is absent). |
| `20261101000500_counterparty_visibility.sql` | Parties to an RFQ/order/thread can read each other's organisation row; competitors cannot. |

## Rules enforced in the database

- **No client writes** to RFQs, quotes, orders, delivery, payments, verification, audit or admin tables — only RPCs. Listings may be created as `draft`; status changes are server-controlled.
- **Tenant isolation**: a supplier sees an RFQ only if routed to it, and only its own routing row and quotes; buyers see only their own RFQs/orders.
- **Quote acceptance** locks rows, checks the buyer, validity and state, snapshots the exact terms into the order, declines competing quotes and creates a `pending_unverified` payment record — atomically, once.
- **Units and currency** are explicit; quote-line units are copied from the RFQ item, never client supplied.
- **Payments are never processed here.** A party's "I paid" claim is recorded but cannot change status. Only `admin_reconcile_payment` can confirm, and only with a provider reference and an exact amount + currency match; a mismatch becomes `under_review`.
- **Verification approval** requires a complete checklist, scope and expiry. Evidence paths are visible only to roles with `verification.evidence.view`; opening a file is logged.
- **Admin power needs MFA**: every admin function requires an active `admin_users` row *and* an `aal2` JWT. Refusals by a real admin are written to the audit log; the audit table cannot be updated or deleted (trigger + revoked privileges).
- **Roles** are rows (`admin_roles`, `admin_role_permissions`, `admin_role_scopes`), editable only by Super Admin. Never authorise from user-editable metadata.

## Tests

`supabase/tests/run.sh` creates a scratch database, applies a small stub of Supabase auth (`00_stub_supabase.sql`) and every migration, then runs persona tests (`10_access_and_workflows.sql`, 77 assertions: isolation, MFA gating, scope, payment/verification rules, audit immutability, privilege-escalation attempts) and seeds a scenario (`20_scenario_seed.sql`).

```bash
PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres supabase/tests/run.sh
```

CI runs this against a PostgreSQL 16 service container. These tests run on **plain PostgreSQL with stubbed auth**, not on a hosted Supabase project; repeat the negative tests on staging with real Auth/MFA before any pilot gate.

## Bootstrapping

1. Create the project, apply the migrations (Supabase CLI `supabase db push`, or the SQL editor).
2. In *Authentication*, enable email sign-in and (recommended) email confirmation. MFA (TOTP) must be enabled for the project.
3. Create the first Super Admin user in *Authentication → Users*, then in the SQL editor (service role / owner only — clients cannot do this):
   ```sql
   insert into public.admin_users (user_id, role_code, display_name)
   values ('<auth user uuid>', 'superadmin', 'Your Name');
   ```
   Further admins are granted from the console/RPC `admin_grant_role` by a Super Admin.
4. **Web console**: edit `admin/config.js` with the project URL and *publishable* key (never a service-role/secret key), and serve `admin/` over HTTPS with the response headers `Content-Security-Policy: frame-ancestors 'none'` and `X-Content-Type-Options: nosniff`. Sign-in requires password + TOTP.
5. **Flutter app**: `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…` (use `--dart-define-from-file` with an uncommitted file). Without these the app starts in labelled demo mode.

## Regenerating the permission seed

The admin role matrix lives in `admin/app.js` (`PERMS`). After changing it:

```bash
node supabase/tools/gen-admin-permissions.mjs   # review output; add a NEW migration with the delta
```

CI fails if the generated seed and migration `…000100` drift apart.

## Known limits (honest status)

- Not applied to any hosted project; storage policies untested against real Storage.
- Web console live mode covers: overview counts, listings moderation, suppliers/organisations (read), verification, RFQs, quotations, orders, delivery, payments, categories (read), audit (read). Cases, reviews, privacy requests, imports, analytics, locations, promotions, system health, reports and messaging have **no tables yet** and show "not connected" in live mode. Internal notes/flags, exports and category edits are disabled in live mode because the database does not store them yet.
- The app supports single-item RFQs and quotes; multi-item RFQs created elsewhere display but cannot be quoted in the app. Supplier verification evidence upload is not in the app yet.
- Passwords-only sign-in for app users; add phone/OTP, rate limits, abuse reporting and retention policy before pilot (see `docs/architecture-security.md`).
