# Admin web architecture, reuse inventory and file dispositions (B1)

Status: **DRAFT FOR INDEPENDENT REVIEW. Nothing here is merged, deployed or approved by anyone other than the author.**
Decision authority: Product Owner approved **B1 Option A** on 18 Nov 2026: a separate responsive web Admin console; Flutter remains the buyer/supplier marketplace. The decision record is `docs/DECISION_B1_ADMIN_ARCHITECTURE.md` on branch `work/luma-e7-reconciliation-20261117` (commit `b441c42`); it is not on `main` and was not modified here.

## 1. Framework recommendation (with assumptions)

**Recommendation: React 18 + TypeScript + Vite single-page app; Vitest + Testing Library + axe-core for tests; Supabase JS (anon key only) once the isolated project exists.**

| Assumption (none was stated by the owner) | If it is wrong |
|---|---|
| No existing web framework or team skill constraint | Switching costs little now: the shell is ~20 small modules, and the server contract (`AdminApi`) is framework-independent |
| Authorization lives in the database (RLS + SECURITY DEFINER RPCs), not in a web server | A server-rendered framework would only be needed if a trusted server-side secret becomes necessary; that would need a Security Lead decision |
| Staff-only, behind sign-in; no SEO or public pages | SSR (e.g. Next.js) would be reconsidered |

| Option | Verdict | Why |
|---|---|---|
| React + TS + Vite SPA | **Recommended** | Static files only (no server of our own to secure), mature accessibility and testing tooling, large hiring pool. Authority stays in Postgres. |
| Next.js / other SSR | Not now | Adds a server runtime and a second place secrets could leak, for no stated need. |
| Flutter Web | Not recommended for the console | It is what B1 chose to step away from; dense data tables, keyboard and screen-reader behaviour need extra work. Flutter stays for the marketplace. |
| Svelte / Vue | Viable | Not chosen only because nothing favours them over React here. Owner or tech lead may overrule. |

The toolchain is current (Vite 8, Vitest 5, Node 22). The older Vite 5 / Vitest 2 line was rejected because of audit findings in dev tooling.

## 2. Security model (what the shell does and does not claim)

- **Server decides.** On load the console calls `my_platform_access()` (PR #76) and renders what comes back. Menu entries appear only for capabilities the server lists, but hiding a menu entry is **not** security: a typed URL still calls the server and shows the server's refusal (tested).
- **MFA.** Capabilities are honoured only when the session is `aal2`; a contradictory response fails closed (tested).
- **No client-controlled role data** (`app_metadata`, `user_metadata`, local storage) is read or stored (tested by source scan).
- **No service-role key** exists in the browser source or bundle (tested; `npm run check:bundle`).
- **Fails closed** when not configured. **Mock data** loads only through a development-only dynamic import, so the production bundle does not contain it (verified; negative control included).
- **Headers.** A CSP meta tag is injected at production build time as defence in depth. Real response headers (CSP, frame-ancestors, HSTS, X-Content-Type-Options, Referrer-Policy) must be set by the host. **No host has been chosen or provisioned.**
- **Not yet addressed:** sign-in and MFA enrolment screens, session refresh, CSRF/CORS settings of the real project, rate limiting, hosting, and any write action. These need B2 and review.

## 3. REST `/admin/v1` (PR #6/#75) mapped to what exists in the database (PR #76)

The earlier plans assumed a REST Admin API. The recommended architecture calls Supabase RPCs under RLS instead; there is no separate Admin API server.

| Proposed endpoint (PR #6 / #75) | Database function today | Status |
|---|---|---|
| (new) caller identity and capabilities | `my_platform_access()` | Implemented, tested locally |
| `GET /admin/v1/verifications` | `reviewer_list_verification_cases()` | Implemented, tested locally |
| `GET /admin/v1/verifications/{id}/evidence` | `authorize_evidence_access()` (+ signed-URL Edge Function, not started) | Partly implemented |
| `POST /admin/v1/verifications/{id}/decision` | `review_supplier_verification(...)`, `flag_supplier_for_early_review(...)` | Implemented in DB; no web screen |
| decision history | `reviewer_list_verification_decisions()` | Implemented, tested locally |
| roles | `grant_platform_role()`, `revoke_platform_role()` | Implemented in DB; no web screen |
| audit log read | RLS-limited read of `audit_events` | Implemented in DB; mock screen only |
| every other module (RFQ, quotations, orders, payments status, support, analytics, privacy requests, imports, categories, locations, health, settings, messaging, ads, reviews) | none | **Not started** |

## 4. Role vocabulary mismatch (decision needed, not guessed)

| PR #75 prototype roles | Database `platform_role` values (PR #76) |
|---|---|
| Super Admin | `platform_admin` |
| Operations Lead | none |
| Trust & Safety | `verification_reviewer` (closest; not equal) |
| Support | `support_agent` |
| Finance | `finance_officer` |
| Analyst | `analyst` |

The prototype's 13 x 6 capability matrix is a design input for the **G2 role-and-permission matrix**, which has no recorded approver. This PR adds no roles and changes no matrix. `Operations Lead` has no database role; the D7 text names an accountable Operations Lead but no named person exists.

## 5. Inventory and disposition: PR #6 (`docs/admin-dashboard-workstreams`, head `ac93679b0208bc6bb9aaf112a999f5435c1a5cb1`, open, not merged)

PR #6 is **not modified, closed or merged** by this work. "Disposition" is a recommendation for the owner and reviewers.

| File (changes) | What it is | Disposition | Reason |
|---|---|---|---|
| `lib/admin/admin_dashboard.dart` (+205) | Flutter `/admin` shell with an injectable read boundary, loading/retry/empty states | **Supersede** (keep as reference) | Same states are rebuilt in the web console. Its good idea, an unconfigured repository that fails closed, is carried over as `createUnconfiguredApi`. |
| `test/admin_dashboard_test.dart` (+76) | 3 Flutter widget tests of that shell | **Supersede**; scenarios migrated | The three scenarios (fails closed with retry; loading/empty/retry success; navigation scoping and search) are covered by `App.test.tsx`. Search/filter is **not** migrated (not built). |
| `lib/main.dart` (+448/-69) | Mixed: 2 admin-related lines (import and `'/admin'` route) plus marketplace app changes | **Split; remove only the `/admin` route if B1 is accepted**; the rest stays with PR #6's owner | Only the 2 admin lines were classified; the remaining ~446 added lines were not reviewed here and are not claimed to be admin work. |
| `test/widget_test.dart` (+5/-1) | Marketplace test fix (import, scroll before tap) | **Keep** (unrelated to admin) | Not admin work. |
| `docs/ADMIN_DASHBOARD_GAP_ANALYSIS.md` (+497) | PRD traceability, ADM-01..14 capability specs, workstreams, decisions that stay blockers | **Keep and migrate**: the ADM specs, permission groups, UAT gates and open decisions are architecture-neutral | Edit the "Flutter shell" wording in a follow-up change; not done here to avoid touching PR #6's file. |
| `docs/BUILD_STATUS.md` (+52) | Status of the Flutter increment and honest verification limits | **Keep as reference** | Historical; records that Flutter test/analyzer runs were blocked in that session and that no analyzer pass was claimed. |
| `README.md` (+8) | Says `/admin` is available as a development console in the Flutter app | **Update when B1 is accepted** (point to `admin-web/`) | Statement becomes inaccurate once the Flutter route is removed. |
| `.github/workflows/flutter.yml` (+13) | Adds a `database-security` job (Supabase CLI local stack, lint, pgTAP) | **Keep; reconcile with PR #76** | Unrelated to the web console. PR #76 has its own database tests and a job of the same name, so a naming/merge-order decision is needed. Not touched here. |
| `supabase/config.toml` (+27) | Local Supabase config (`project_id = "luma-local"`, Postgres 15) | **Keep; reconcile** | Not admin specific; needed by the local Supabase CLI job. |
| `supabase/migrations/20261112000100_listing_submission_guard.sql` (+18) | Supplier listing submission guard | **Keep** | Not admin work. PR #76 is stacked on it (see 7). |
| `supabase/tests/database/listing_submission_test.sql` (+37) | pgTAP tests for that guard | **Keep** | Not admin work. |

## 6. Inventory and disposition: PR #75 (`prototype/admin-console-shell`, head `111970b53ed5ddceac1def596b5d715fd86b654b`, draft, not merged)

| File (changes) | What it is | Disposition | Reason |
|---|---|---|---|
| `prototype/admin-console/index.html` (+1172) | Single-file clickable prototype: 24 modules, 6 roles, masked contact details, second-admin approval gate for broadcasts, generated data | **Keep as the G2 design reference; do not ship.** Migrate design ideas module by module as each server contract exists | Generated data, role enforcement only in the browser, no accessibility or test evidence. The masking, purpose-based reveal and second-approval patterns are worth rebuilding on server enforcement. |
| `prototype/admin-console/docs/MODULES.md` (+303) | Module inventory, statuses, proposed REST endpoints and permissions | **Keep and migrate** | The module list and priorities feed the roadmap; the REST endpoints map to RPCs as in section 3. The word "Admin API" is superseded. |
| `prototype/admin-console/README.md` (+121) | Prototype status and role list | **Keep** | Already states it is a prototype, not production, and that the console is planned as a separate web app (consistent with B1). |

No file from PR #75 is copied into `admin-web/`. Its design is a reference only.

## 7. PR #6 merge dependency (for PR #76) given the web architecture

**Finding (verified with the GitHub API and `git merge-base`):** PR #76's base branch is `docs/admin-dashboard-workstreams`, which is PR #6's head. PR #6's head `ac93679` is an ancestor of PR #76's branch. PR #76 is therefore **stacked on the whole of PR #6**, including the Flutter `/admin` shell, not only on its migration. PR #76's own diff (16 files) is just the E7 work, but merging the pair means PR #6 reaches `main` first.

The database work genuinely depends on PR #6's migration `20261112000100_listing_submission_guard.sql`, since the E7 migration is additive on top of it. It does **not** depend on PR #6's Flutter admin files.

| Option | Effect | Who can do it |
|---|---|---|
| A. Merge PR #6 as is, then retarget PR #76 to `main`; remove the Flutter `/admin` route in a follow-up | Flutter admin code lands on `main` and is removed later (churn, but nothing is rewritten) | PR #6 owner / reviewers |
| B. Ask PR #6's owner to drop the Flutter admin files from PR #6 before merge | Cleanest history; changes PR #6 | PR #6 owner (**not done here: PR #6 must not be silently changed**) |
| C. Open a new "extraction" PR from `main` containing only the non-admin files (migration, its test, `config.toml`, the `database-security` workflow job), then retarget PR #76 to it | Leaves PR #6 untouched; creates a competing PR | Owner decision |

**Recommendation: B, falling back to A.** Option C is available on request but was **not** done, to avoid a second PR competing with PR #6 without the owner's say. **No rebase, merge, retarget or force-push was performed.** Whichever option is chosen, PR #76 must stay draft until an independent DB/security reviewer has reviewed it.

## 8. Flutter-specific admin work: supersede, reference, migrate

| Item | Action |
|---|---|
| Flutter `/admin` route and `AdminDashboard` | Supersede (recommend removal after owner accepts this PR) |
| Flutter admin widget tests | Superseded by web tests; scenarios migrated |
| `AdminRepository` abstraction idea | Migrated as the `AdminApi` contract |
| ADM specs, permission groups, UAT gates, blockers | Keep and migrate (architecture-neutral) |
| Prototype design (modules, roles, masking, approval gates) | Reference for G2; migrate per module |

## 9. Review and approval status

- Independent reviewer: **UNASSIGNED** (no reviewer is named in any repository document and the collaborator list is not readable by this session). Review requested in the PR; **not given**.
- G2 sign-off: **not given.** This work is a draft foundation, not gate evidence.
