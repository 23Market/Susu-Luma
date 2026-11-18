# G2 — UX, architecture and security design: approval record

**Status: UNSIGNED. This document does not approve anything.**

G2's exit evidence is seven named artifacts. This index records which exist, where they are, and which are missing, then provides the signature blocks. **G2 remains "in progress / not approved" until every artifact exists and the signature table is complete.**

- **Required exit evidence** (gate register): approved journeys · role/permission matrix · threat model · data classification/retention · architecture · admin-console design · test strategy
- **Required approvers:** Product, UX, Engineering, Security, Operations and Legal
- **Dependency:** G2 approves designs built on the G1 baseline. Approving G2 while G1 is unsigned would approve a design against unapproved requirements. **G1 should be signed first**, or G2's approval must record which G1 items it treats as settled.

---

## Artifact status

| # | Required artifact | Document | Where | State |
|---|---|---|---|---|
| 1 | Approved journeys | `docs/G2_USER_JOURNEYS.md` | — | **MISSING** |
| 2 | Role / permission matrix | `docs/G2_ROLE_PERMISSION_MATRIX.md` | — | **MISSING** as a canonical doc. Content exists in the admin console (6 roles × 13 capabilities) and the PRD |
| 3 | Threat model | `docs/G2_THREAT_MODEL.md` | — | **MISSING** |
| 4 | Data classification and retention | `docs/G2_DATA_CLASSIFICATION.md` | — | **MISSING** as a schedule. D10 periods recorded on #7 but **provisional**, and they conflict with the append-only design (see G1 record §5) |
| 5 | Architecture | `docs/architecture-security.md` · `docs/ADMIN_WEB_ARCHITECTURE.md` | main · PR #77 | **Exists**, unapproved |
| 6 | Admin-console design | `docs/ADMIN_WEB_ARCHITECTURE.md` + draft PR #77 implementation · prototype PR #75 | PR #77 · PR #75 | **Exists**, unapproved and **unreviewed** |
| 7 | Test strategy | `docs/G2_TEST_STRATEGY.md` | — | **MISSING** |

**Four artifacts do not exist.** They are drafting work, not decisions, and do not require a policy answer to begin — except the data classification schedule, which cannot be finalised until the audit-retention contradiction in the G1 record §5 is decided.

---

## Evidence already available to the approvers

Not approval, but the material G2 reviewers will want:

| Evidence | Result | Source |
|---|---|---|
| Admin web foundation tests | 93 tests pass; typecheck, build and bundle check pass | `admin-web` CI run 44205181730 |
| Accessibility | Real Chromium, 36 page states (9 states × 2 widths × light/dark): **0 axe WCAG 2.2 AA violations**, no overflow, no console errors | local run, PR #77 |
| Database security policy | 235 pgTAP assertions pass; **41/41 mutants killed**; rollback 7/7 | local + `database-security` CI run 44257592716 |
| Dependency posture | 0 vulnerabilities in shipped web dependencies; one dev-tooling advisory (`picomatch`, no fix published) recorded | `npm audit` |
| Secret scan | 0 findings on both branches | detect-secrets |
| Defect found by review | A reviewer could lower an early-review flag and approve alone — found, fixed, covered | B7 review |

### Gaps the approvers must weigh

- **No independent review of either PR.** PR #76 and PR #77 are both draft and unreviewed; no reviewer is assigned.
- **GitHub secret scanning, Dependabot and code scanning are disabled or blocked** for the repository.
- **No `pubspec.lock` committed**, so Flutter dependencies cannot be scanned.
- **Flutter CI fails** (inherited: `main` does not compile). Diagnosed, not repaired.
- **Evidence-upload hardening not started**: no content/magic-byte validation, no malware scanning, no signed-URL function. Must be decided and built before any real verification evidence is accepted.
- **No isolated Supabase environment**, so auth, RLS and storage behaviour has not been tested against a real backend.

---

## Approver signatures — G2

| Approver role | Name | Decision (Approve / Revise / Reject) | Date | Conditions |
|---|---|---|---|---|
| Product | | | | |
| UX | | | | |
| Engineering | | | | |
| Security | | | | |
| Operations | | | | |
| Legal | | | | |

---

## What signing this does **not** approve

- **Not** a G3 build-verification approval, and not evidence that any feature is complete.
- **Not** authority to deploy, to apply a migration to a shared database, or to create a Supabase project.
- **Not** approval of the admin console implementation — PR #77 is draft and unreviewed.
- **Not** acceptance of the provisional retention periods as legally final.
- **Not** authority to accept real verification evidence until upload hardening exists.
