# CI cost controls (18 Nov 2026)

Status: **DRAFT for review. Not merged.** Product Owner asked for a change that cuts GitHub Actions spend. This changes workflow files only. No application, database or Flutter code is touched.

## Where the minutes went (Susu-Luma, 1-18 Nov 2026, from the Actions jobs API)
Billed minutes = each job rounded up to a whole minute. Dollars are not computed here: the billing API is not reachable from the working session.

| Job | Runs | Billed minutes |
|---|---|---|
| `database-security` | 7 | 21 |
| `flutter` | 11 | 16 |
| Copilot's own review and agent jobs (`copilot`, `copilot-pull-request-reviewer`) | 8 | 15 |
| `diagnose` (throwaway Flutter diagnosis, now finished) | 3 | 6 |
| `admin-web` | 1 | 1 |
| **Total** | | **59** |

At standard Linux-runner rates this is cents to under a dollar. The account's net bill for the month was about $0.07 after the included allowance. These controls are cheap insurance, not a large saving.

## What changed
| Change | Why | Saves |
|---|---|---|
| `database-security` moved to its own workflow, `database-security.yml`, same job name and same steps, running only when `supabase/**` or the workflow itself changes | The database job is the most expensive job (2 to 3 minutes per run) and ran on every push, even for docs-only changes | The full run for pull requests that do not touch the database |
| `flutter.yml` skips changes that touch only `docs/`, `supabase/`, `admin-web/`, `prototype/`, `scripts/local-db/`, `*.md` or the other workflows | The web console pull request ran Flutter checks on every push, and they failed for reasons unrelated to it | 1 to 2 minutes per web-only or docs-only push; removes a misleading red check |
| `concurrency` with `cancel-in-progress` for pull requests | A newer push makes the older run pointless | The older run, when pushes land close together |
| `timeout-minutes` (10 for Flutter, 15 for database) | The default limit is 6 hours; a hung job is the only way to spend real money | Caps a runaway job |
| `work/**` push trigger removed; `pull_request` now runs for any base branch | A `work/**` branch with a pull request to `main` would have been built twice (push and pull request). Stacked pull requests still get checks through the pull request event. | One duplicate run per commit |
| `workflow_dispatch` on both workflows | Lets a person run a check on demand, for example the database check on a docs-only head | n/a |

## How it behaves (read before relying on it)
- **Path filters on a pull request compare the whole pull request, not the latest commit.** A pull request that already changes `supabase/**` keeps running the database job on every push. The saving is for pull requests that never touch those paths.
- **A skipped workflow leaves no status for that commit.** Evidence must cite the last run that covered the files. Example: the database code has not changed since `1f5ce93`, so its run applies to later docs-only heads. A passing database run is **not independent approval**.
- **No required status checks exist today.** Branch protection and rulesets are unavailable on this plan (the API answers "Upgrade to GitHub Pro or make this repository public"). If they are enabled later, a path-filtered workflow that never starts will block merges as "Expected, waiting for status". Revisit this file then.
- Flutter results are unchanged: those checks still fail for the reasons in `docs/FLUTTER_CI_DIAGNOSIS.md`. This change does not repair them.

## Not changed on purpose
- **Flutter SDK pin and `pubspec.lock`**: a stability decision for the app owner (see the Flutter CI diagnosis), not a cost control.
- **`supabase start` service list**: trimming services could hide a real authentication or storage regression.
- **Copilot review runs** (15 of 59 minutes): these are controlled by Copilot settings on the account or repository, not by workflow files.
- **`admin-web.yml`** (draft PR #77) already has path filters and concurrency. It has no `timeout-minutes` yet; add one when that pull request is next touched.
