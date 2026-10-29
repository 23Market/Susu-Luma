# Authentication security and deployment

## Session boundary

The Flutter web build does not initialise Supabase Auth and does not persist access or refresh tokens in `localStorage`. Browser authentication goes through the same-origin `/api/auth/` route. The `auth-api` Edge Function sets `__Host-` cookies with `Secure`, `HttpOnly`, `SameSite=Strict` and `Path=/`. Its CSRF cookie is readable only so the client can echo it in the `X-CSRF-Token` header; it contains no authentication credential.

Production hosting must reverse proxy `/api/auth/*` to the `auth-api` function without changing the browser-visible origin. Disable CDN caching for this route and preserve every `Set-Cookie` header. Direct cross-site use of the function is unsupported because `SameSite=Strict` cookies would not be sent.

Android and iOS store the native Supabase session through `flutter_secure_storage` (Android Keystore and iOS Keychain). No service-role key is present in any client build.

## Required server secrets

Configure these only in Supabase Edge Function secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` or the project publishable key
- `SUPABASE_SERVICE_ROLE_KEY`
- `AUTH_SECURITY_PEPPER`: at least 32 random bytes
- `AUTH_BACKUP_SIGNING_KEY`: a separate key with at least 32 random bytes
- `AUTH_ALLOWED_ORIGINS`: comma-separated exact HTTPS origins
- `PASSWORD_RESET_REDIRECT_URL`: approved same-site password reset page
- `TURNSTILE_SECRET_KEY`

The web build receives only `AUTH_API_BASE_URL` and `TURNSTILE_SITE_KEY` through `--dart-define`.

## Provider settings required before pilot

Apply `supabase/config.toml`, then confirm the remote hosted settings because local configuration does not prove production state:

1. Minimum password length `12`; require lowercase, uppercase, number and symbol.
2. Enable Supabase leaked-password protection backed by Have I Been Pwned. This hosted feature must be enabled in Auth settings and verified with a known test password.
3. Enable email confirmation, secure password changes, refresh-token rotation and 10-minute OTP expiry.
4. Enable Cloudflare Turnstile and configure the production site and secret keys.
5. Configure sign-in/sign-up and verification limits at `5`; the BFF additionally enforces five attempts per 15-minute IP/account bucket.
6. Enable `hook_password_verification_attempt` as the Password Verification Hook on an eligible Supabase plan. This protects direct provider sign-ins with account lockout and exponential backoff.
7. Configure production SMTP and keep password-reset redirect URLs allowlisted.
8. Configure signup and recovery email templates to send the token hash to the same-origin application, which exchanges it through `POST /api/auth/verify-otp`; do not place access or refresh tokens in browser-readable URLs.

## MFA and admin authorization

TOTP enrollment and verification use Supabase MFA. The `aal` JWT claim is checked by both the admin API middleware and the database helper `is_platform_admin_aal2()`. Every `/admin/*` server route passes through the central middleware before dispatch. Frontend checks control presentation only.

Ten random backup codes are created after initial AAL2 verification. Only keyed hashes are stored, redemption is atomic, each code works once, and the resulting recovery grant expires after 10 minutes. Regenerating codes invalidates the previous set.

Platform-admin membership must be provisioned by a trusted operator in `platform_admins`; there is no client insert policy. Never derive administrative authority from profile metadata or a client claim.

## Abuse controls

The auth API applies the following to login, signup, password recovery/reset, email OTP, TOTP and backup-code routes:

- combined IP and account buckets with five attempts per 15 minutes;
- CAPTCHA required after three failures;
- exponential delay after each failure, capped at five minutes;
- 30-minute account lock after five failures;
- security-event logging using keyed hashes instead of raw email/IP values;
- generic recovery responses to prevent account enumeration;
- `Cache-Control: private, no-store`, exact-origin CORS and CSRF validation.

Operational alerts should cover lockout spikes, repeated CAPTCHA failure, backup-code use and admin access denial. Retention for `auth_security_events` must be approved before production.

The `backend-security` CI job type-checks the Edge Function, applies every migration to a fresh local Supabase database, runs database linting and executes the pgTAP security suite in `supabase/tests/database`. This gate verifies the rate-limit boundary, CAPTCHA escalation, server-only function grants, atomic backup-code redemption and AAL2 administrator checks without using a shared backend.

## Admin dashboard data boundary

The dashboard reads one server-built snapshot instead of querying privileged tables from Flutter. Browser requests use `GET /admin/dashboard`; mutations use CSRF-protected `/admin/suppliers/review`, `/admin/listings/review` and `/admin/support/resolve` routes. The central admin middleware verifies the session, platform-admin assignment, and either AAL2 or a short-lived redeemed backup-code grant before dispatch. The Edge Function then calls service-role-only database functions with the verified actor ID.

Android and iOS call authenticated wrapper functions directly. Those wrappers require `is_platform_admin_aal2()` and delegate to the same internal operations. Supplier, listing and support decisions create `audit_events`. Revenue, subscription and support tables grant no direct client access.

## Password checks

The client provides immediate strength feedback and blocks short, incomplete and common passwords. The auth API independently enforces the same structural rules and queries the Have I Been Pwned range API using k-anonymity. It fails closed if the breach check is unavailable. Supabase password policy and leaked-password protection remain the final enforcement layer for direct provider traffic.
