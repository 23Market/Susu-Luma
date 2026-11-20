# Susu Luma web Admin console (foundation)

Status: **foundation shell, mock data only. Not a live console. Not production. Not independently reviewed.**

The Flutter app stays the buyer/supplier marketplace. Operations/admin staff use this separate
responsive web console (owner decision B1, Option A, 18 Nov 2026; see
[`docs/ADMIN_WEB_ARCHITECTURE.md`](../docs/ADMIN_WEB_ARCHITECTURE.md)).

## What exists

- Responsive shell (phone to desktop, light and dark, keyboard and screen-reader friendly).
- States: loading, signed out, session expired, MFA required, no access, service error with retry,
  module loading, module denied, module error, empty module.
- Access comes from the **server** (`my_platform_access()` on PR #76). The browser renders what the
  server returns; it never decides who may do what, and it never reads client-controlled metadata.
- Two read-only demo modules (Verification queue, Audit log) on synthetic data.

## What does not exist yet

- A live Supabase adapter and sign-in/MFA enrolment screens (needs the isolated Supabase project, B2).
- Any write action (approve, reject, grant a role). Reviewer actions stay in the database layer for now.
- Hosting and HTTP response headers (CSP, frame-ancestors, HSTS) - set by the host, not by this folder.
- Independent review and G2 role/permission matrix sign-off.

## Commands (Node 22)

```bash
cd admin-web
npm ci
npm run dev:mock     # http://localhost:5173/?scenario=reviewer  (development only)
npm run verify       # typecheck + tests + production build + bundle check
```

`?scenario=` values (development only): `reviewer`, `admin`, `finance`, `no_role`, `no_mfa`,
`signed_out`, `expired`, `error`.

## Safety rules enforced by tests and CI

| Rule | Where enforced |
|---|---|
| No service-role/secret key in browser source | `src/security.test.ts`, `scripts/check-bundle.mjs` |
| Mock data cannot be reached, or even shipped, in a production build | `createApi.ts` (injected provider), dev-only dynamic import in `main.tsx`, `check:bundle` |
| Console fails closed when unconfigured | `createUnconfiguredApi`, `App.test.tsx` |
| Capabilities honoured only for an MFA (aal2) session | `contract.ts`, `contract.test.ts` |
| Hidden menu entry is not security: a typed URL still gets the server's refusal | `App.test.tsx` |
| No role/token persisted in browser storage; no HTML injection | `src/security.test.ts` |
| Content-Security-Policy injected into the production page | `csp.ts`, `src/security.test.ts` |
| Dependency audit for shipped packages | `.github/workflows/admin-web.yml` |

Only browser-safe (anon/publishable) values may ever be configured here. **Never put a service-role key
in this folder, in a `VITE_*` variable, or anywhere in the repository.**
