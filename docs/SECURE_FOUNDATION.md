# Secure Supabase foundation (E7 Phase 2–3, backend)

Status: **DRAFT for independent review. Not applied to any shared or production database.**
Migrations: `supabase/migrations/20261117000100_secure_foundation.sql` (additive; stacked on PR #6's `20261112000100_listing_submission_guard.sql`) and `supabase/migrations/20261118000100_verification_risk_policy.sql` (B7: risk policy and the web-console access contract; see `docs/VERIFICATION_RISK_POLICY.md`).
Gate impact: **none claimed.** G0/G1/G2 stay as recorded in `docs/waterfall-gate-register.md`. Nothing here adds wallet, escrow, custody, settlement or a payment gateway.

## What it adds

| Area | Change |
|---|---|
| Platform roles | `platform_roles` (platform_admin, verification_reviewer, finance_officer, support_agent, analyst). Server-controlled: no client privilege on the table; changed only by `grant_platform_role` / `revoke_platform_role` (platform_admin, MFA session, no self-grant, audited) or service-role SQL. **Client metadata (`app_metadata`, `user_metadata`) is never read for authorization.** |
| Grants | `anon`/`authenticated` lose all default table, sequence and function privileges. Re-granted narrowly: select on `organizations`, `organization_memberships`, `audit_events` (RLS-limited); listing discovery columns (no `created_by`); listing insert (RLS-limited); case status columns for org owners/admins. |
| Onboarding | `create_organization_with_owner(...)`: one transaction creates the organisation, the owner membership and an audit event. Idempotent on `(created_by, creation_key)`; safe under concurrent retries. Direct client inserts into `organizations` / `organization_memberships` are no longer possible. |
| Integrity | Deferred constraint: an organisation cannot commit without an owner. Last owner cannot be removed or demoted (row-locked, so two owners cannot remove each other concurrently). |
| Audit | `audit_events` is append-only (update, delete and truncate raise 42501 even for the table owner). Readable only by platform_admin on an MFA session. Privileged actions write audit rows inside the same transaction. |
| Verification | `submit_supplier_verification`, `review_supplier_verification`, `flag_supplier_for_early_review`, reviewer list RPCs, `authorize_evidence_access`, `supplier_is_verified`, `expire_lapsed_verifications`. Append-only `verification_decisions`. |
| Evidence storage | Private `verification-evidence` bucket (10 MiB, PDF/JPEG/PNG). Policies on `storage.objects` by `{organisation_id}/file` path; org owners/admins insert and read their own folder only; **no update/delete**. Reviewers and admins have no direct bucket access. |

## Authorization rules implemented

- Staff roles require an **aal2 (MFA) JWT**: `has_platform_role` returns false otherwise.
- **No self-approval / no conflicts:** the case submitter and any member of the supplier organisation can never review, flag or open evidence for that case (even if they hold a reviewer role).
- **Independent second reviewer** is required when the case is high risk, a policy exception is declared, the organisation has any earlier rejection (rejected-to-approved), or the case was pulled back by an early-review flag. The second approval must come from a different reviewer. Second review can only approve or reject. **The requirement is sticky** (`second_review_required`): neither a reviewer nor the table owner can lower `risk_level` or clear it (trigger `protect_risk_controls`). Declaring high risk, a policy exception and an early-review flag each need a documented reason of at least 10 characters.
- **Verified means:** an `approved` case whose `expires_at` is still in the future. Approval sets `expires_at = now() + 12 months`; `supplier_is_verified()` ignores lapsed approvals immediately, before any job runs. A flag sets expiry to now and restarts review.
- One open case per organisation (partial unique index); duplicate or concurrent submissions are refused with 23505.
- Evidence paths must sit in the organisation's own folder, contain no `..`, and exist in the bucket.

## RPC contract (all `SECURITY DEFINER`, `search_path=''`)

| Function | Callable by | Typical errors |
|---|---|---|
| `create_organization_with_owner(legal_name, display_name, type, district, locality, description, creation_key)` | authenticated | 28000 no subject; 22023 bad input; 23514 constraint |
| `submit_supplier_verification(org_id, evidence_paths[])` | org owner/admin | 42501 not a member; 22023 bad type/paths; 23505 open case exists |
| `review_supplier_verification(case_id, decision, reason, scope, policy_exception, risk_level, risk_reason)` returns new status | verification_reviewer (aal2) | 42501 role/conflict/same second reviewer/lowering risk; 22023 missing or short reason; 55000 case not open |
| `my_platform_access()` returns jsonb `{user_id, aal, mfa_satisfied, roles, capabilities}` | authenticated | 28000 no subject |
| `flag_supplier_for_early_review(case_id, reason)` | verification_reviewer (aal2) | 42501; 55000 not approved |
| `reviewer_list_verification_cases(status)`, `reviewer_list_verification_decisions(case_id)` | verification_reviewer (aal2) | 42501 |
| `authorize_evidence_access(case_id, path)` | verification_reviewer (aal2), audited | 42501 |
| `supplier_is_verified(org_id)` | anon, authenticated | none |
| `expire_lapsed_verifications()` | service_role only | n/a |
| `grant_platform_role` / `revoke_platform_role` | platform_admin (aal2) | 42501 self/role; 22023; P0002 |

## Client contract changes (breaking for any future client code; none exists on this branch)

- No direct `insert` on `organizations` or `organization_memberships`: use `create_organization_with_owner` and send a client-generated `creation_key` UUID so retries are safe.
- `select *` on `listings` is refused. Name the discovery columns (no `created_by`).
- Evidence upload path must be `{organisation_id}/{file}`; submit via `submit_supplier_verification`.
- PR #6's test assertion for direct organisation inserts now expects `permission denied for table organizations` (denied one layer earlier than the RLS message; still 42501).

## Engineering defaults awaiting owner / Security confirmation

1. **MFA (aal2) required for every platform role.** Secure default, not an owner decision. Needs Supabase MFA enrolment in the admin client.
2. **"High risk" classification:** the directive does not define it. Implemented as reviewer-declared (`risk_level` with a documented reason), plus a mandatory second review for policy exceptions, earlier rejections and early-review flags. Not accepted until Security Lead review.
3. Evidence limits: 10 MiB per file, PDF/JPEG/PNG, max 20 files per case.
4. Only `platform_admin` can read the audit trail (support and analyst roles get no audit access until their scope is approved).

## NOT included (NOT STARTED)

Signed-URL Edge Function for evidence (the RPC only authorizes and audits); scheduling of `expire_lapsed_verifications` (verification already reads as expired without it); Flutter onboarding screens; admin console; RFQ recipient limits (max 5 verified suppliers), quotes, orders, payments, delivery, disputes, support, reporting; rate limiting and abuse controls at the API layer; staging environment; backup-restore test; monitoring.

## Verification evidence (what was actually run)

Local throwaway PostgreSQL 16 plus pgTAP, with `scripts/local-db/supabase_stub.sql` standing in for the Supabase roles, `auth` and `storage` schemas. **This is an approximation, not Supabase and not approval evidence.** The authoritative result is the `database-security` CI job (real Supabase local stack) for this branch.

| Check | Command | Result (18 Nov 2026) |
|---|---|---|
| pgTAP (7 files) | `./scripts/local-db/run-tests.sh` | **235 passed, 0 failed** (6 + 23 + 20 + 62 + 68 + 29 + 27) |
| Concurrency (real parallel sessions) | `./scripts/local-db/concurrency-test.sh` | **13 passed, 0 failed**, repeated runs stable |
| Rollback | `./scripts/local-db/rollback-test.sh` | **7 passed**: schema and grants after rolling back both E7 migrations equal the pre-E7 baseline |
| Mutation check | `python3 scripts/local-db/mutation-check.py` | **41 of 41** deliberate security regressions caught by the suite (25 foundation + 16 B7) |

Run with `export PGHOST=<socket dir> PGPORT=<port> PGUSER=postgres` against a local server that has pgTAP. The scripts refuse hosted hosts.

Defect found by the B7 review and fixed in the second migration: **a single reviewer could lower an early-review flag and approve alone** (reproduced on `cc84f70`; earlier tests and mutants missed it). Defects found by earlier testing and fixed before commit: (1) concurrency test exposed a write-skew in the last-owner guard (two owners removing each other left none): fixed with a row lock; (2) the rollback test exposed leftover column-level grants: fixed in the down script; (3) one stale assertion in PR #6's test (message text only).

Security scenarios covered: unauthenticated denial, cross-tenant denial (rows, evidence folder, bucket), privilege escalation (forged metadata, missing MFA, self-grant, reviewer to admin), self-approval and conflict of interest, second-reviewer rules, private-document isolation including path traversal, audit and decision-history immutability, duplicate and concurrent submissions, membership integrity, and an allow-list guard that fails if any new public table, sequence or function becomes client-reachable.

**Not covered:** secret scanning tooling, dependency vulnerability scans, real Supabase behaviour (storage policy ownership, auth hook claims), staging E2E, load, backup-restore, monitoring.

## Rollback and recovery

- **Disposable development database only:** `PGOPTIONS="-c luma.allow_data_loss=yes" psql -v ON_ERROR_STOP=1 -f supabase/rollback/20261117000100_secure_foundation.down.sql`. It refuses to run without that setting, and refuses if the evidence bucket holds objects. It is outside `supabase/migrations` so the CLI never applies it.
- **Shared or production databases:** do not run the down script. Use a forward-fix migration and restore from backup/point-in-time recovery. **Backup-restore has not been tested** (G4 item).
- Apply to a shared database only after independent review and approval of an isolated environment.

## Known limitations and risks

- Reviewer list RPCs return full case rows (including evidence paths) to verification reviewers by design.
- `district` remains free text; the 18-district reference table and areas are not implemented (areas list unsourced).
- `organization_type` is validated in the RPC, not by a table constraint (PR #6 baseline left it open).
- The service-role key must never reach Flutter, frontend bundles or the repository. Nothing in this change uses or stores it.
