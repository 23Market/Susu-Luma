# Luma test suite plan

**Product:** Luma Industrial Marketplace, Sierra Leone  
**Platforms:** Android, iOS, responsive web admin  
**Architecture:** Flutter client, Supabase PostgreSQL/Auth/Edge Functions  
**Status:** Working test baseline for development, staging, pilot and release gates

## 1. Purpose

This plan defines the automated and manual evidence required to show that Luma is usable, secure and reliable for buyers, suppliers and platform administrators. Testing prioritizes the workflows that can affect marketplace trust, organization data isolation, RFQ accuracy, administrator actions and account security.

Passing local or continuous-integration tests is necessary but does not approve a production release. Hosted staging configuration, physical-device checks, user acceptance testing and operational readiness must also pass.

## 2. Quality goals

1. A user can understand the home screen and complete the primary tasks with limited reading.
2. English and Krio guidance is understandable and never blocks visual navigation.
3. Buyers can find products and create accurate RFQs with explicit quantities, units and delivery details.
4. Suppliers can manage only their own organization data.
5. Administrators must authenticate with MFA and receive authorization from the backend for every privileged operation.
6. Authentication resists account enumeration, credential attacks, session theft and OTP abuse.
7. The app remains usable on common Android devices and slow or intermittent mobile networks.
8. Release artifacts are reproducible, installable, correctly branded and free of embedded secrets.

## 3. Test pyramid and execution frequency

| Layer | Purpose | Expected volume | Execution |
|---|---|---:|---|
| Unit | Domain validation, parsing, state transitions and pure security rules | High | Every commit |
| Widget/component | Flutter screens, controls, validation, accessibility semantics and navigation | High | Every pull request |
| Database/security | Constraints, RLS, privileged functions, audit records and concurrency | Medium | Every pull request in isolated Supabase |
| API/contract | Auth API, admin API and client/server payload compatibility | Medium | Every pull request and staging deployment |
| Integration | Flutter plus staging Supabase, email, CAPTCHA and storage | Medium | Nightly and before release |
| End to end | Critical buyer, supplier and administrator journeys | Low | Staging, nightly and release candidate |
| Manual/UAT | Usability, Krio comprehension, device behavior and operations | Focused | Before pilot and major release |

## 4. Current baseline and gaps

### Existing automated coverage

- App configuration validation.
- Password policy checks and weak-password UI blocking.
- MFA code-format validation.
- Organization onboarding required fields.
- RFQ line and draft validation.
- Home, catalogue search and local RFQ widget flows.
- Admin dashboard contract parsing and basic rendering.
- Database tests for authentication security and administrator APIs.
- CI analysis, formatting, Flutter tests, Android APK build, web build, database lint and Edge Function type checking.

### Highest-priority gaps

- No full client-to-staging tests for authentication, cookies, native secure storage or MFA.
- Marketplace catalogue, RFQs, quotes, orders, messages and favourites remain mostly local or incomplete.
- RLS coverage must expand across every marketplace table and every buyer/supplier/admin persona.
- No automated accessibility, visual regression or low-bandwidth suite.
- No iOS build or physical iOS device evidence in CI.
- No complete end-to-end buyer, supplier or administrator journey.
- No measured performance, load, backup/restore or recovery evidence.

## 5. Functional test suites

### A. Home, navigation and language guidance

| ID | Scenario | Level | Priority |
|---|---|---|---|
| HOME-001 | Home shows logo, Find Products, Building, Farming, Tools, Food, Ask for Price and Sell an Item | Widget | P0 |
| HOME-002 | Every principal button opens the correct destination and category | Widget | P0 |
| HOME-003 | Bottom navigation preserves the expected screen state | Widget | P1 |
| HOME-004 | English Listen control speaks the correct guide and Stop ends playback | Widget/device | P1 |
| HOME-005 | Krio selection speaks the approved Krio script | Widget/device/UAT | P0 |
| HOME-006 | Missing text-to-speech service shows a useful message and navigation still works | Widget/device | P1 |
| HOME-007 | Screen remains usable at large text sizes and in portrait/landscape layouts | Accessibility/device | P1 |

The Krio script must be reviewed by Sierra Leonean speakers. Automated tests can verify selection and playback calls, but comprehension requires user testing.

### B. Authentication and account recovery

| ID | Scenario | Level | Priority |
|---|---|---|---|
| AUTH-001 | Sign-up rejects passwords below the backend policy and common/breached passwords | Unit/API | P0 |
| AUTH-002 | Login succeeds with valid credentials and rotates the session | API/integration | P0 |
| AUTH-003 | Web session uses Secure, HttpOnly, SameSite=Strict, Path=/ cookies and no tokens in localStorage | Integration/security | P0 |
| AUTH-004 | Android and iOS sessions survive restart in Keystore/Keychain and are removed on logout | Device | P0 |
| AUTH-005 | Five failures trigger lockout; CAPTCHA begins after three; backoff increases | API/database | P0 |
| AUTH-006 | IP and account buckets prevent bypass by changing only one identifier | API/database | P0 |
| AUTH-007 | Recovery response does not reveal whether an account exists | API/security | P0 |
| AUTH-008 | OTP expires after the configured period and cannot be reused | API/integration | P0 |
| AUTH-009 | TOTP enrollment, verification, cancellation and recovery work | Integration/E2E | P0 |
| AUTH-010 | Backup codes are one time, regeneration revokes old codes and recovery grants expire | Database/API | P0 |
| AUTH-011 | CSRF, unapproved origin and cached auth requests are rejected | API/security | P0 |
| AUTH-012 | Failed attempts and lockouts create privacy-minimized security events | Database/integration | P0 |

### C. Organization and supplier onboarding

Test owner membership creation as one atomic transaction, duplicate organization handling, invitation acceptance, expired invitations, role changes, suspended organizations, supplier profile editing, evidence upload type/size limits and private evidence access. Verify that failed onboarding leaves no partial organization or membership record.

### D. Catalogue, discovery and favourites

Test keyword and category search, district/location filters, pagination, stable sorting, empty/error/retry states, published versus suspended visibility, explicit units and currency, quote-only listings, image placeholders, saved items and cross-account favourite isolation. Include Sierra Leone categories and diacritic/case-insensitive search inputs.

### E. RFQ workflow

| ID | Scenario | Level | Priority |
|---|---|---|---|
| RFQ-001 | Create an RFQ with one and multiple line items | Unit/E2E | P0 |
| RFQ-002 | Reject blank product, zero, negative, infinite or missing quantity/unit | Unit | P0 |
| RFQ-003 | Reject a past delivery date and accept an approved future date | Unit/widget | P0 |
| RFQ-004 | Save, resume and submit a draft after app restart or network interruption | Integration/device | P0 |
| RFQ-005 | Route the RFQ only to eligible intended suppliers | Database/integration | P0 |
| RFQ-006 | Buyer can read own RFQ; unrelated organizations cannot read or mutate it | RLS | P0 |
| RFQ-007 | Duplicate submit or retry creates one RFQ | API/concurrency | P0 |
| RFQ-008 | Attachment type, size, malware policy and private access are enforced | Integration/security | P1 |

### F. Quotations, acceptance and orders

Cover quote creation, revision, expiry, withdrawal, MOQ, lead time, delivery terms and validity. Compare differing currencies and units with clear warnings. Acceptance must be atomic and idempotent, create an immutable order snapshot and reject expired or superseded quotes. Concurrent acceptance attempts must produce one accepted outcome. Client-supplied payment claims must never create a paid state; status remains `pending_unverified` without authoritative evidence.

### G. Messaging, fulfilment and support

Verify participant-only message access, thread creation, rate limits, attachment controls, report/block flows and retention. Verify allowed fulfilment transitions, partial delivery, proof-of-delivery evidence, actor/timestamp audit, issue opening and support escalation. Reject invalid transitions and unauthorized historical-record access.

### H. Admin dashboard

| ID | Scenario | Level | Priority |
|---|---|---|---|
| ADM-001 | Anonymous, non-admin and AAL1 users cannot load any admin API | API/database | P0 |
| ADM-002 | AAL2 platform admin can load the dashboard snapshot | API/contract | P0 |
| ADM-003 | Every admin mutation rechecks server authorization | API/security | P0 |
| ADM-004 | Supplier review, listing moderation and support resolution validate status transitions | Database/integration | P0 |
| ADM-005 | Every privileged action records actor, target, decision and timestamp | Database | P0 |
| ADM-006 | Suspended listings disappear from discovery but remain in authorized history | Integration | P0 |
| ADM-007 | Dashboard handles empty, loading, expired session and backend failure states | Widget/integration | P1 |
| ADM-008 | Revenue figures derive from recognized revenue events and label prototype/target values correctly | Contract/database | P0 |
| ADM-009 | Pagination, filters and export do not leak data outside the authorized scope | Integration/security | P1 |

## 6. Security and privacy suite

Use three normal personas in two organizations plus a platform administrator at AAL1 and AAL2. For every exposed table and storage bucket, test read, insert, update and delete permissions with each persona.

Required security cases:

- Cross-organization denial for profiles, listings, RFQs, quotes, orders, messages, favourites, evidence and support cases.
- Direct database and API attempts that bypass the Flutter UI.
- Service-role and secret-key absence from Android, iOS and web artifacts.
- JWT tampering, expired sessions, replay, session rotation and logout invalidation.
- SQL injection, stored/reflected XSS, malicious filenames and oversized payloads.
- CSRF, CORS, cookie flags and cache-control behavior.
- TOTP, OTP, backup-code and password-recovery abuse controls.
- Administrator endpoint authorization and audit completeness.
- Private storage signed-URL expiry and evidence-access logging.
- Dependency and secret scanning, static analysis and a pre-pilot penetration test.

## 7. Accessibility and usability

- Meet WCAG 2.2 AA for the web admin and applicable mobile accessibility guidance.
- Verify semantic labels, focus order, keyboard navigation, screen-reader output, touch targets, contrast and error announcements.
- Test at 200% text scale without clipped primary actions.
- Conduct task-based sessions with buyers and suppliers who have varied literacy and smartphone experience.
- Validate picture/category recognition and the English/Krio audio instructions with target users.
- Acceptance target: at least 80% of representative users complete Find Product and Ask for Price without facilitator help; record errors and revise the design before pilot.

## 8. Performance, reliability and network conditions

| Area | Initial target | Test |
|---|---|---|
| Cold start | Usable home within 3 seconds on a supported mid-range Android device | Device benchmark |
| Search | First page within 2 seconds at p95 on staging under expected pilot load | API/load |
| Admin dashboard | Snapshot within 3 seconds at p95 | API/load |
| Crash-free sessions | At least 99.5% during controlled pilot | Monitoring |
| App size | Track release APK/AAB size and fail on unexplained material growth | CI trend |
| Network | Core screens handle offline, timeout, packet loss, duplicate responses and reconnect | Integration/device |
| Recovery | Approved RPO/RTO demonstrated by restoring a staging backup | Operational exercise |

Run network tests at offline, high latency, 2G-like bandwidth and intermittent connectivity. Confirm drafts are not lost, actions are not duplicated and retry status is clear.

## 9. Compatibility matrix

### Android

- Minimum supported API level from project configuration.
- Current release and two preceding major Android versions.
- At least one low/mid-range device and one Samsung device.
- Small and large screens, light/dark system settings and English locale.
- Clean install, upgrade from previous release, background/foreground, reboot and revoked permissions.

### iOS

- Minimum supported iOS version plus current and preceding major versions.
- One smaller iPhone and one current standard-size iPhone.
- Clean install, upgrade, Keychain persistence, app termination and permission changes.

### Web admin

- Current and previous Chrome, Edge, Safari and Firefox releases.
- Desktop widths and tablet breakpoint.
- Keyboard-only and screen-reader checks.

## 10. Test environments and data

Maintain isolated local, CI, staging and production environments. Automated tests must never use production data.

Create deterministic fixtures for:

- Buyer A and Supplier A in Organization A.
- Buyer B and Supplier B in Organization B.
- Platform admin at AAL1 and AAL2.
- Active, suspended and expired listings.
- Draft, open, closed and expired RFQs and quotes.
- Pending, partially delivered, delivered and disputed orders.
- Open and resolved support cases.

Use synthetic names, contact details and verification evidence. Reset staging fixtures between automated runs and keep seed data versioned.

## 11. Automation and CI gates

### Every pull request

1. Dependency resolution and lockfile consistency.
2. Dart formatting and static analysis.
3. Unit and widget tests with machine-readable results.
4. Edge Function type check.
5. Fresh local Supabase migration, schema lint and pgTAP tests.
6. Android release APK and web release build.
7. Secret scan and dependency vulnerability scan.
8. Test artifact, APK and web artifact upload.

### Nightly

- API contract and staging integration tests.
- Critical buyer, supplier and admin end-to-end journeys.
- Accessibility scan and visual regression comparison.
- Slow/intermittent-network scenarios.
- Broader dependency and security scans.

### Release candidate

- Signed Android AAB/APK and iOS IPA build verification.
- Clean install and upgrade on the compatibility matrix.
- Full staging regression, security suite and UAT.
- Backup restore and operational alert exercise.
- Artifact secret scan, version/icon/name/signing verification and checksum recording.

## 12. Coverage and quality thresholds

- 100% of P0 acceptance criteria mapped to at least one test case.
- 100% of database tables with RLS tested for allowed and denied personas.
- 100% of admin routes tested for anonymous, non-admin, AAL1 and AAL2 access.
- At least 80% line coverage for domain and service code; use risk coverage rather than a blanket UI line target.
- Zero unresolved P0/P1 defects at pilot release.
- Zero known critical/high security findings.
- No flaky test may remain in a required gate; quarantine requires an owner, issue and expiry date.

## 13. Entry and exit criteria

### Feature test entry

- Acceptance criteria and error states are defined.
- Test identities, fixtures and environment are available.
- Security and privacy impact has been assessed.
- Code is analyzable and deployable to the test environment.

### Pull-request exit

- Required CI jobs pass.
- New behavior has appropriate unit/widget/API/database coverage.
- No unexplained coverage regression or unresolved P0/P1 defect.
- Reviewer can reproduce the primary scenario.

### Pilot exit

- All P0 journeys pass in staging and on supported physical devices.
- Security review, RLS matrix, accessibility review and UAT are signed off.
- Monitoring, alerting, incident response and backup restore are proven.
- Known limitations and operational ownership are documented.

## 14. Implementation order

### Phase 1: strengthen the current baseline

1. Add navigation and audio-controller tests for the simplified home.
2. Add widget tests for catalogue empty/error/retry and all principal buttons.
3. Expand RLS tests into a complete persona/table matrix.
4. Add Auth API request tests for cookies, CSRF, rate limits, CAPTCHA, OTP and backup codes.
5. Add admin API authorization and mutation contract tests.

### Phase 2: backend-connected marketplace

1. Add repository/service unit tests around persistent catalogue, RFQ and favourites.
2. Add staging integration tests for organization onboarding and private storage.
3. Add RFQ idempotency, routing and cross-organization tests.
4. Add quote acceptance concurrency and immutable order snapshot tests.
5. Add messaging, fulfilment and support authorization tests.

### Phase 3: pilot readiness

1. Automate critical end-to-end journeys.
2. Add Android/iOS device and upgrade testing.
3. Run accessibility and target-user usability sessions in English and Krio.
4. Establish performance baselines and pilot-load tests.
5. Complete penetration testing, backup restore and operational exercises.

## 15. Critical end-to-end journeys

The release suite must keep these journeys small and stable:

1. **Buyer:** register → create organization → find listing → create RFQ → receive quote → accept quote → view order.
2. **Supplier:** register → complete supplier profile → create listing → receive RFQ → submit/revise quote → update fulfilment.
3. **Administrator:** login with TOTP → review supplier → moderate listing → resolve support case → verify audit record.
4. **Recovery:** trigger account lockout → complete approved recovery → redeem one backup code → confirm reuse fails.
5. **Isolation:** Organization A attempts direct access to every Organization B resource and receives no data.

## 16. Test evidence and ownership

Each run should record build SHA, environment, test-data version, device/browser, result, logs/screenshots, defects and approver. Product owns acceptance criteria and UAT; engineering owns automated functional and integration coverage; security owns threat-based validation; operations owns monitoring, backup and incident exercises. A named release owner collects the evidence and makes the gate recommendation.

