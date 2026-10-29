# Release-readiness gate: current status

**Status: NOT APPROVED FOR PRODUCTION OR PILOT.** CI passing proves code-level checks in an isolated environment; it does not prove hosted services or operational controls are configured.

## Local web preview
- [ ] Run the GitHub Actions web build and confirm the `susu-luma-web-release` artifact exists.
- [ ] Extract the artifact contents into `build/web/` (the folder should contain `index.html`, `flutter_bootstrap.js`, and `main.dart.js`).
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\tool\serve_web.ps1`.
- [ ] Open `http://localhost:8000`, not a `file://` URL.
- [ ] If blank, capture Console errors and failed Network requests from Chrome DevTools.

## Hosted authentication and security — evidence required
- [ ] Create and identify separate approved development/staging/production Supabase projects; no project credentials are assumed to exist.
- [ ] Apply migrations to an approved staging project only after review; verify RLS with buyer, supplier, and platform-admin test identities.
- [ ] Set Edge Function secrets in Supabase (never in the Flutter app or repository): `SUPABASE_URL`, publishable/anon key, service-role key, `AUTH_SECURITY_PEPPER`, `AUTH_BACKUP_SIGNING_KEY`, `AUTH_ALLOWED_ORIGINS`, `PASSWORD_RESET_REDIRECT_URL`, and `TURNSTILE_SECRET_KEY`.
- [ ] Deploy `supabase/functions/auth-api` and configure a same-origin HTTPS reverse proxy for `/api/auth/*`; preserve `Set-Cookie`, disable caching on auth routes, and verify CSRF protections.
- [ ] Configure and test Turnstile, email confirmation, password requirements, leaked-password protection, password verification hook, SMTP, redirect allowlists, rate limits, and session rotation in hosted Auth settings.
- [ ] Test TOTP enrollment, AAL2 admin authorization, one-time backup-code redemption, lockout/backoff, password recovery, and cookie flags against staging.
- [ ] Validate Android Keystore and iOS Keychain behavior on physical devices; document supported-device results.
- [ ] Complete security review, privacy/retention review, operational alerting, incident runbooks, backup/restore, and UAT sign-off.

## Product and financial scope
- The current product supports discovery, RFQs, quotations, messaging, and order/fulfilment coordination.
- No wallet, stored value, escrow, lending, payment settlement, deposit-taking, or unapproved money transmission is enabled or authorized.
- Sample marketplace/admin metrics are prototype data, not live business results.
- Do not enable real users, privileged admin access, production traffic, or a pilot until the appropriate requirements, design, testing, security, operations, and UAT gates are formally approved.
