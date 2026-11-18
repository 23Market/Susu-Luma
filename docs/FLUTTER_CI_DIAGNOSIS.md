# Flutter CI diagnosis (18 Nov 2026)

Status: **diagnosis only. No Flutter or Dart file was changed.** The failing items sit in PR #6's code and in an unpinned SDK, not in E7 (database) or the web console, and PR #6 must not be modified without its owner.

## Method
Job logs are not readable from the reviewing session (they return 404 behind the proxy), so a diagnostic workflow was run on **scratch branches that are never merged**. It runs `dart format`, `flutter analyze` and `flutter test` independently, so one failure cannot hide the next, and publishes the output as check-run annotations.

| Subject | Scratch branch | Commit | Run |
|---|---|---|---|
| `main` baseline | `diag/flutter-main-baseline-20261118` | `f7f7e57a49f0ab86a0c74dd3687d83df692aa520` (parent `a9155f4`) | [44205435780](https://github.com/23Market/Susu-Luma/actions/runs/44205435780) |
| PR #6 head (same Dart code as PR #76) | `diag/flutter-pr6-head-20261118` | `7a11134d6f7282a631f7d293aee7f90a42676af1` (parent `ac93679`) | [44205439191](https://github.com/23Market/Susu-Luma/actions/runs/44205439191) |
| Viewport hypothesis (one test file edited, scratch only) | `diag/flutter-pr6-viewport-hypothesis-20261118` | `837ea8576381ed86a3c6638dfff4c28c5fdf4eaf` | [44256583303](https://github.com/23Market/Susu-Luma/actions/runs/44256583303) |

CI environment: Flutter **3.50.0** (stable, 9 Nov 2026), Dart **3.14.0**. The workflow uses `channel: stable` with no pinned version, and **no `pubspec.lock` is committed**, so the SDK moves under the project.

PR #76 changes no Dart or `pubspec` file relative to PR #6's head, so its Flutter result is PR #6's result.

## Findings

### On `main` (baseline): the app does not compile. INHERITED.
| Step | Result | Cause |
|---|---|---|
| `dart format` | fails | `lib/main.dart` cannot be parsed: a string literal is broken across lines 106 and 107 (`'Business starts` / `with a better connection.'`) |
| `flutter analyze` | 28 issues, mostly errors | The same broken string cascades; plus `test/widget_test.dart` uses `EditableText` without importing `package:flutter/material.dart` |
| `flutter test` | compile error | Same |

`main`'s own Flutter runs have failed since 17 Oct (two push runs). PR #6's commit "corrected malformed strings/parentheses and test imports" is the fix; `docs/BUILD_STATUS.md` on PR #6 says so.

### On PR #6 head (and PR #76): format passes, analyze has 5 `info` notices, 2 tests fail
| Item | Class | Evidence |
|---|---|---|
| `dart format` passes | fixed by PR #6 | exit 0 |
| `flutter analyze`: **0 errors, 0 warnings, 5 info** (info is fatal by default, so the job is red) | | |
| - 4 x `deprecated_member_use` on `package:flutter/material.dart` (`lib/admin/admin_dashboard.dart`, `lib/main.dart`, `test/admin_dashboard_test.dart`, `test/widget_test.dart`) | **Environment-specific**: Flutter 3.50 deprecates that import ("after v3.47.0-0.0.pre") and the SDK is unpinned. The import appears in inherited code (`lib/main.dart`) and in files PR #6 added or edited, so the notice count is partly PR #6's but the trigger is the SDK moving. | run 44205439191 |
| - 1 x `prefer_const_constructors` at `lib/main.dart:499` | **Inherited**: same `CircleAvatar(...)` code as `main` line 173; PR #6 only shifted line numbers | both runs |
| `flutter test`: 3 admin tests **pass**, `discover tab` **passes**, 2 marketplace tests **fail** | see below | run 44205439191 |

Test failures (both in `test/widget_test.dart`, marketplace code, not admin):
- *shows the Susu Luma marketplace home*: `Sample listings` not found. **Cause confirmed:** the item is built lazily outside the default 800x600 test viewport. With a tall viewport the test **passes** (run 44256583303). The text exists in both `main` and PR #6, so this is a test/layout mismatch. Whether it is inherited cannot be proven, because `main` does not compile.
- *request quote creates a local draft...*: with the viewport fixed the test gets past `ensureVisible` and taps, then fails because `My RFQs` is not found after the tap. **A second cause that was not diagnosed:** stale test or changed app behaviour. It is marketplace logic, so it was not pursued.

## Why nothing was repaired here
The task says repair where safe and relevant, and do not modify unrelated work to make CI green. Every failing item is in PR #6's Flutter code or in the unpinned SDK. None is in the E7 database work or the web console. Changing PR #6's files would silently alter another engineer's PR, and its Flutter `/admin` shell is superseded by the B1 decision anyway. The owner of the marketplace app is **UNASSIGNED**.

## Recommended fixes for PR #6's owner (not done)
1. Pin the Flutter version in `.github/workflows/flutter.yml` and commit `pubspec.lock`, so SDK drift cannot turn CI red. Decide the version deliberately (security patches versus stability).
2. Decide the `material.dart` deprecation: migrate to the replacement package, pin an older SDK, or temporarily run `flutter analyze --no-fatal-infos`. Owner decision.
3. Add `const` at `lib/main.dart:499`.
4. Fix the two marketplace tests: give the test a tall viewport or use `scrollUntilVisible`, and correct or explain the `My RFQs` expectation after tapping Request quote.
5. After B1 is accepted, remove the Flutter admin files; that removes 3 of the 5 notices.

## Effect on other branches
- **PR #77 (web console):** its `Flutter checks` job also fails, at `dart format`, because its base is `main` where `lib/main.dart` does not parse. The web work changes no Dart. Its own `admin-web` job passes.
- **PR #76:** `database-security` passes; `flutter` fails for the inherited reasons above.

## Cleanup
The three `diag/*` scratch branches are diagnostic only and are safe for a repository owner to delete. They were not deleted here.
