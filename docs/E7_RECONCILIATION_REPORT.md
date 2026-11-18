# E7 repository reconciliation report (Phase 1)

Status: **IN PROGRESS: reconciliation evidence complete; sign-offs outstanding.** This is an evidence document, not an approval. It claims **no gate passed, nothing merged, nothing deployed.**

Verified against live GitHub (REST API) and git on **18 Nov 2026**. Earlier SHAs in other documents are treated as historical. Companion to (and does not modify) `docs/E7_RECONCILIATION_CHECKPOINT.md` on `work/luma-e7-reconciliation-20261117`.

## 1. Safe development baseline

| Use | Baseline | Why |
|---|---|---|
| Database / security work (E7 Phase 2–3) | **`docs/admin-dashboard-workstreams` @ `ac93679b0208bc6bb9aaf112a999f5435c1a5cb1`** (PR #6 head), stacked **without merging** | It is the only line containing the listing-guard migration, `supabase/config.toml`, the pgTAP test and the `database-security` CI job. Its `database-security` check passes. |
| `main` | `a9155f49b77996c96f99c1233ce05235d7430ae4` | Unchanged. **Not** a safe baseline for DB work: it lacks all of the above. Its `flutter` check is red. |
| E7 branch `work/luma-e7-reconciliation-20261117` | `37cd9044182d62a7665870194099892b6225afe2` | One docs-only commit on top of `main` (1 file). **Diverged from PR #6** (ahead 1, behind 3). It does not contain PR #6's migration, tests or CI job. Left untouched. |

Implementation branch (mine): `work/luma-e7-secure-foundation-20261117`, created from `ac93679`. Its PR is opened with base `docs/admin-dashboard-workstreams` so the diff shows only E7 changes. **Merge order if approved: #6 first, then this PR retargeted to `main`.**

Local checkout: shallow clone whose base equals `origin/docs/admin-dashboard-workstreams` (`ac93679`). Because it is shallow, local `git merge-base`/ahead-behind counts are unreliable; all ancestry figures here come from the GitHub compare API.

## 2. Branch and PR inventory

| Ref | Head SHA | Base | State | Files | Reviews | CI at head |
|---|---|---|---|---|---|---|
| PR #6 `docs/admin-dashboard-workstreams` | `ac93679b0208bc6bb9aaf112a999f5435c1a5cb1` | main (ahead 3, behind 0) | open, ready | 11 | 2× Copilot bot "changes recommended" (12 Nov); 1 human comment "good" (not an approval). **No approving review.** | database-security **success**, copilot success, flutter **failure** |
| PR #73 `chore/backend-environment-foundation` | `6de5905d9f8a8a51fce6d87e590e396a84cfb49f` | main | open, draft | 3 (`.env.example`, `.gitignore`, `docs/ENVIRONMENT_SETUP.md`) | none | flutter **failure** |
| PR #75 `prototype/admin-console-shell` | `111970b53ed5ddceac1def596b5d715fd86b654b` | main | open, draft | 3 (static HTML prototype under `prototype/admin-console/`) | none | flutter **failure** |
| PR #2 `feat/rfq-domain-validation` | `3494eb959a4dd33881dadcc570be4c3facb520b2` | main | open, draft (29 Oct) | ≥101 | none | backend-security, flutter, android-apk all **failure** |
| PR #1 `docs/prd-traceability-gate-register` | `6117175ac5703bb48f3bb14bb7f8913d02489e2e` | main | **merged** 17 Oct | n/a | n/a | n/a |

CI evidence (check-run IDs; URL form `https://github.com/23Market/Susu-Luma/runs/<id>`): main flutter `117269013767`; PR #6 database-security `131494273398`, flutter `131494270722`; PR #73 flutter `131494153994`; PR #75 flutter `134388794830`; PR #2 backend-security `123201535359`, flutter `123201534700`, android-apk `123201518556`. Job logs return 404 from this environment; per-step conclusions via the jobs API show `dart format` failing on `main` and the main-based PRs, and `flutter analyze` failing on PR #6. The cause of PR #2's failures was not diagnosed.

## 3. Overlaps and conflicts

- **PR #2 vs PR #6** overlap on 4 files: `.github/workflows/flutter.yml`, `README.md`, `lib/admin/admin_dashboard.dart`, `lib/main.dart`. PR #2 also shares `.gitignore` with #73. PRs #6, #73 and #75 do not overlap each other. **Disposition of PR #2 is a Product Owner / Technical Lead decision (superseded or not); nothing was closed or cherry-picked.**
- No existing PR was merged, rebased or force-pushed. No uncommitted or externally authored work was found in the checkout beyond mine.

## 4. Findings

| # | Finding | Evidence | Action |
|---|---|---|---|
| F1 | E7 branch is not built on PR #6. | compare API: E7 `diverged`, ahead 1, behind 3. | Stack on PR #6 (done). Do not treat the E7 branch as a DB baseline. |
| F2 | **Issue #24 is closed as `duplicate`** (closed 12 Nov by `23Market`). The live backend ADM-06 issue is **#44** (frontend #43, integration #45; #23/#24/#25 are the closed duplicates). The directive and the E7 checkpoint still cite #24. | issue API `state_reason: duplicate`; search shows #44 open with the same title. | Use **#44** for traceability. Not reopened. Owner to confirm. |
| F3 | Issue #70 (Supabase foundation) is open, no comments. Issue #7 is open (3 comments: two earlier, one decision record posted 17 Nov). | issue API. | Reuse #70 and #44. No new duplicates created. |
| F4 | No `AGENTS.md` / `CLAUDE.md` exists in the repository. | `git ls-tree` on main and PR #6. | Repository rules were taken from `docs/*.md`, README and the directive. |
| F5 | CI never runs on `work/**`, and PRs not based on `main` get no checks (`flutter.yml` triggers on push to `main` and PRs to `main` only). The E7 branch has **no check runs**. | workflow file; check-runs empty at `37cd904`. | `work/**` added to the push trigger in this PR. **Superseded by the CI cost-controls change** (`docs/CI_COST_CONTROLS.md`): `pull_request` now runs for any base branch and the `work/**` push trigger is gone. |
| F6 | `docs/BUILD_STATUS.md` (PR #6) records that its author could not run format or DB tests locally (no Docker). The `database-security` CI job on that head is nonetheless **green**. | `docs/BUILD_STATUS.md`; check run `131494273398`. | Treated as the baseline CI signal for the two existing migrations. |
| F7 | The E7 checkpoint describes PR #6 as "planning/admin gap analysis, not an implemented admin backend". PR #6 also ships a real migration, pgTAP test and CI job. | PR #6 file list. | Noted; no change to the other branch. |
| F8 | **Admin console technology was unresolved**: README says "separate responsive web console"; PR #6 builds `lib/admin` in Flutter with widget-test acceptance (#72); PR #75 is a static HTML prototype. | README, PR #6/#75 file lists. | **RESOLVED by Product Owner decision, 18 Nov 2026: separate web console** (`docs/decisions/2026-11-18-admin-console-and-pilot-geography.md`; issue #7 comment 6964124275). Knock-on: #72 and PR #6's `lib/admin` no longer match; their owners must revise. Nothing changed in them. Web framework and hosting still undecided. |

## 5. Reconciliation of Product Owner decisions, issue #7, PRD and gates

Decision slots refer to the #7 decision record (D1 to D11).

| Directive rule (E7) | #7 slot | Status | Remaining |
|---|---|---|---|
| Max 5 verified supplier recipients per RFQ | D3 | Fills "verified only" (option A) and the cap | "May buyers pick suppliers directly?" still blank |
| Quote validity 24 h to 30 days; supplier confirmation window 48 h | D4 | Fills validity and seller window | Cancellation rights by state/role still blank |
| Payment states `pending_unverified`, `externally_confirmed`, `under_review`, `not_applicable`; only Finance Officers record confirmation; cash in person needs both parties plus Finance review | D5 | Fills all open sub-items; resolves the state mismatch (no failed/reversed/disputed) | Record-only list (JubaSecure, Orange Money, Afrimoney, Ezipay, GTPay, PayPal, cash) already confirmed |
| Delivery dispute window 72 h after buyer-confirmed receipt | D6 | Fills window and "buyer confirms" | Escalation path; local-counsel wording check |
| Re-verification every 12 months or earlier on risk; independent second reviewer (high-risk approvals, policy exceptions, rejected-to-approved); no self-approval; immutable history | D2 | Fills validity and second reviewer | **Exact evidence document list**; definition of "high risk" (see B7) |
| Pilot caps: 150 buyers, 50 verified suppliers | not in #7 | New | Needs recording in #7 |
| ~~Pilot geography: Western Area Urban and Rural only~~ | D9 | **Superseded by Product Owner decision, 18 Nov 2026 (~01:40): first pilot = all 16 in-force districts.** Bandajuma and Kpanguma (proposed, not in force) stay inactive. This replaces both Western-Area-only and the earlier "all 18". | **Open:** the areas list (no official source supplied; wards vs chiefdoms not chosen); **Security/Legal review of any footprint wider than the Western Area (directive requires it for material scope changes; no reviewer assigned), so nothing outside the Western Area goes live until reviewed.** Caps (150 buyers, 50 suppliers) unchanged. |
| D7 support hours/SLA, D8 analytics, D10 retention, D11 prohibited goods | D7, D8, D10, D11 | **Still blank** | Owner/Ops/Legal values |

Provenance: these rule values come from the directive. On 18 Nov 2026 the Product Owner approved recording them, and they were **posted to #7** (comment 6964124275). They are owner decisions, **not a G1 sign-off**: no specialist or stakeholder approval exists and no #7 checkbox was ticked.

Gate register (`docs/waterfall-gate-register.md`) is unchanged and remains authoritative: **G0 open, G1 open, G2 in progress / not approved, G3–G5 not evidenced, G6 not authorised, G7 not evidenced.** Owner decisions are not specialist or stakeholder sign-offs. **No gate is marked passed by this report.**

Outstanding sign-offs (none obtained): sponsor and Product Owner naming (G0); PRD approval record (G1); role/permission matrix, threat model, data classification, admin-console design (G2); Security, Legal, Operations, Finance reviewers (unassigned in any repository document).

## 6. Ownership (nothing invented)

| Role | Holder |
|---|---|
| Product Owner / Executive Sponsor | Joseph Momoh (per owner's 17 Nov replies; formal G0 naming not recorded in the repo) |
| Accountable Technical Lead | Acting: Claude, under the E7 directive. **No human technical lead is named.** |
| Backend and Supabase | **UNASSIGNED** (acting work: this PR) |
| Marketplace application (Flutter) | **UNASSIGNED** |
| Admin dashboard | **UNASSIGNED** |
| QA and security | **UNASSIGNED** (independent reviewer for this PR required) |
| DevOps and release | **UNASSIGNED** |
| Legal / Finance / Operations reviewers | **UNASSIGNED** |

## 7. Next implementation actions

1. Independent human review of the secure-foundation PR; read the CI `database-security` result for that branch (authoritative; local runs are approximations).
2. Product Owner decisions still open: areas source file and layer (wards or chiefdoms), Security/Legal reviewers for any pilot footprint wider than the Western Area (the two proposed districts are settled: inactive), the D2 evidence list and "high risk" definition, and values for D3 (buyer picks), D4 (cancellation), D6 (escalation, counsel check), D7, D8, D10, D11. **Resolved 18 Nov:** admin console = separate web console (B1); pilot = 18 districts and areas (B5, scope review still open); directive rule values recorded on #7.
3. Provision an isolated Supabase dev project (cost and ownership approval needed, B2) so staging verification and backup-restore testing can start.
