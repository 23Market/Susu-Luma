# Supabase isolated dev environment (B2)

Status: **BLOCKED. No approved Supabase dev project exists. Nothing was created, restored, resumed, migrated or configured. No secret was handled.**
Checked on 18 Nov 2026 with the read-only Supabase connector (list organizations, get organization, list projects).

## 1. What exists (verified)

| Item | Value |
|---|---|
| Organisation | `23Market` (`bbfshluzvdsuucltsnnb`), plan **free** |
| Projects | **1**: `23Market's Project`, ref `zpoezxbtjovnxckexubw`, region `eu-west-1`, status **INACTIVE (paused)**, Postgres 17, created 2 Sep 2026 |
| Approval record for that project | **None found** in any repository document, issue or project doc |
| Environment separation | **None**: no dev / staging / production split exists |

**The paused project was not touched.** Its purpose and owner are unknown. It sits in the same organisation as the repository and may belong to another 23Market product. Restoring or reusing it could expose or overwrite data that is not Luma's, and a restore may start billing. Reuse needs an explicit owner decision naming the project.

## 2. Decisions needed before anything is provisioned (owner: Joseph Momoh, the Product Owner)

| # | Decision | Notes |
|---|---|---|
| 1 | Approve creating a **new, Luma-only dev project**, or name the existing one for reuse | Dev only; synthetic data only |
| 2 | **Cost**: free tier or paid; who owns the bill | Any paid service needs written approval. Free-plan limits (project count, auto-pause, backups) must be checked against Supabase's current pricing page before approval. Not asserted here. |
| 3 | **Region** for dev | Synthetic data, so low risk. The **production** region is a separate decision that needs the legal/privacy review required by D8/D10. |
| 4 | **Secret custodian** | One named person holds the dashboard and database password and the service-role key. No such person is named anywhere. |
| 5 | **Independent DB/security reviewer** | Required before applying PR #76's migrations. Currently UNASSIGNED. |

## 3. Rules when it is provisioned
- Three separate projects eventually (dev, staging, production), as the README already requires. Only **dev** is in scope now.
- Browser-safe values only (project URL, anon/publishable key) may reach the Flutter app or the web console. The **service-role key and database password never go in the repository, a `VITE_*` variable, the Flutter app or the web bundle**. Server-side jobs (for example `expire_lapsed_verifications`) get it from the host's secret store.
- No production credentials and no customer data in dev. Synthetic data only.
- Migrations are applied **only after review**, to dev only, one at a time, in order: `20261017000100`, `20261112000100`, `20261117000100`, `20261118000100`. Record the migration list afterwards. The rollback scripts in `supabase/rollback/` are for disposable dev databases only.
- CI keeps using a throwaway local stack (`supabase start`); it needs no hosted project and no secrets.

## 4. Test plan to run once the environment exists (NOT STARTED)
The local harness (Postgres 16 + pgTAP + a stub) is an approximation. These need real Supabase:

| Area | What to prove | Why the local stub cannot |
|---|---|---|
| Auth and MFA | A real TOTP enrolment gives an `aal2` JWT; `my_platform_access()` returns capabilities only then; an `aal1` session gets none | The stub fakes the JWT claims |
| RLS and onboarding | `create_organization_with_owner`, last-owner protection, roles | Real role and grant setup |
| Private storage | Evidence bucket: org-folder isolation, no public URL, size limit, **MIME validation (upload a PDF-labelled executable and a mislabelled image)** | The stub has no Storage service |
| Negative cross-tenant | Org A cannot read, write or enumerate org B's rows or evidence; a reviewer who belongs to the supplier's organisation is refused | Real PostgREST and Storage paths |
| Reviewer authorization | Second-review rules, no self-approval, no risk lowering, through the real API | End-to-end path |
| Job scheduling | Who runs `expire_lapsed_verifications` and with which key | Needs the host |

## 5. Evidence record (empty until the tests run)
| Field | Value |
|---|---|
| Project id / name | NOT CREATED |
| Environment | n/a |
| Migration versions applied | none |
| Test results | not run |
| Rollback result | not run |
| Secrets in this record | none (by rule) |
