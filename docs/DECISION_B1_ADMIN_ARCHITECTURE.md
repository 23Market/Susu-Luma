# Luma B1 — Admin architecture decision

Status: PRODUCT OWNER APPROVED, 18 November 2026. This is an architecture direction, not G2 exit sign-off.

- Buyer/supplier marketplace remains Flutter mobile.
- Admin dashboard is a separate responsive web application.
- Supabase provides Auth, PostgreSQL/RLS, private storage and reviewed server functions; all privileged Admin actions require server-enforced authorization.
- Reconcile PR #6 (Flutter-related Admin foundation) and PR #75 (HTML prototype) without discarding other engineers' work. Inventory reusable design, contracts, tests and code. Do not merge either PR automatically.
- Web framework, deployment topology and API contract require engineering review; security, privacy, staging and release gates remain mandatory.
- Track B2 isolated Supabase project/ownership, B3 independent review of draft PR #76, B6 issue #7 policy synchronization and legal signoffs, B7 risk classification/MFA and independent verification review.
- No production deployment, destructive database operations, live payment integration or release-gate bypass authorized.
