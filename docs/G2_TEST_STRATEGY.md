# G2 — Test strategy

**Status: DRAFT for G2 approval. Not approved.**

G2 requires a test strategy; this is it. It defines what is tested, at which level, what evidence each gate needs, and what cannot currently be tested at all.

Governing rule from the gate register: **do not mark a gate passed based on code presence alone.** A rendering interface and a green build are not acceptance evidence.

---

## 1. Levels

| Level | Scope | Tooling | Runs |
|---|---|---|---|
| **L1 Static** | Types, lint, format, dead code | `tsc`, `flutter analyze`, `dart format` | Every push |
| **L2 Unit / widget** | Pure logic, single components | `vitest` (web), `flutter test` (mobile) | Every push |
| **L3 Database policy** | RLS, constraints, triggers, separation of duties | **pgTAP** | Every push |
| **L4 Mutation** | Whether the tests would actually catch a defect | mutation runs over policy and logic tests | Per change to policy or logic |
| **L5 Integration** | Real Supabase: auth, RLS, storage, RPC | API-level suite against an isolated dev project | **Blocked — no environment** |
| **L6 End-to-end** | Buyer → supplier → order journeys across clients | browser + Flutter integration driver | Blocked on L5 |
| **L7 Accessibility** | WCAG 2.2 AA | axe in real Chromium, across states, widths and themes | Every push (web) |
| **L8 Resilience** | Low bandwidth, retry, duplicate prevention, failure paths | integration + fault injection | Blocked on L5 |
| **L9 Security scanning** | Secrets, dependencies, code | detect-secrets; `npm audit`; Dependabot; code scanning | **Partly blocked — scanning disabled** |
| **L10 Recovery** | Backup restore, measured RPO/RTO | restore drill against the dev project | **Blocked — no environment** |

---

## 2. The authorisation test matrix

The load-bearing controls are tenancy and authorisation, so they get a dedicated matrix rather than incidental coverage. **Every cell must be a test.**

### Identities

Six test identities, minimum: buyer-org-A owner, buyer-org-A member, buyer-org-B owner, supplier-org-X owner, supplier-org-Y owner, and one staff identity per administrative role.

### Required assertions

| Case | Assertion |
|---|---|
| **Cross-org read** | Buyer B cannot read any RFQ, quotation, order, payment record, message or evidence belonging to Buyer A — by any path, including direct API query |
| **Unrouted supplier** | Supplier Y, not routed to an RFQ, cannot read it even with a valid identifier |
| **Routed supplier** | Supplier X, routed, can read only that RFQ and only the permitted fields |
| **Client-claim forgery** | A token or profile field asserting a staff role grants nothing |
| **Capability denial** | Each role is denied every capability the matrix does not grant it, tested **against the API directly**, not through the interface |
| **Scope denial** | Trust & Safety acting outside its assigned categories receives `403 out_of_scope`, and the refusal is audited |
| **Self-approval** | An actor cannot approve a verification case they submitted or that concerns their own organisation |
| **Second reviewer** | A high-risk approval cannot complete with one reviewer |
| **Flag downgrade** | An actor cannot lower a review-requirement flag and then approve the same case |
| **Payment confirmation** | Only Finance can record external confirmation; every other role is refused |
| **Audit immutability** | No role can update, delete or truncate `audit_events` or `verification_decisions` |
| **Masking** | No read path returns an unmasked phone or email except a purpose-stated, audited reveal |
| **Revocation** | Removing a capability takes effect on the next server request |

---

## 3. Commercial invariants

Each is a test, not a convention.

| Invariant | Test |
|---|---|
| Accepted-quote snapshot is immutable | Mutate the source quote after acceptance; order terms are unchanged |
| Submitted quote versions never change | Revise a quote; prior version is byte-identical |
| Expired or withdrawn quotes cannot be accepted | Acceptance is refused |
| Quote validity bounds | Outside 24 hours – 30 days is rejected |
| Supplier confirmation window | 48-hour window enforced |
| RFQ recipient cap | A sixth routed supplier is rejected |
| Verified-only routing | An unverified supplier is never routed |
| Payment independence | A delivered order is not paid; a confirmed payment does not imply delivery |
| Partial delivery | Delivered and outstanding quantities both preserved and summing correctly |
| Explicit units and currency | No code path converts either |
| Idempotency | The same key replays the first result; a different body with the same key conflicts |
| Dispute window | 72 hours after buyer-confirmed receipt enforced |

---

## 4. Current evidence

What exists today, and what it does and does not prove.

| Evidence | Result | Proves | Does not prove |
|---|---|---|---|
| Web foundation suite | **93 tests pass**; typecheck, build and bundle check pass (CI run 44205181730) | The console shell and its states behave | Nothing about a real backend |
| Accessibility | **0 axe WCAG 2.2 AA violations** across 36 page states (9 states × 2 widths × light/dark), no overflow, no console errors | The console meets AA in the states tested | Accessibility of the Flutter client |
| Database policy | **235 pgTAP assertions pass**, rollback 7/7 (CI `database-security`, run 44257592716) | Policy logic holds against a local Postgres approximation | Behaviour against real Supabase auth and storage |
| Mutation | **41/41 mutants killed** (policy); 14/15 (web, 1 equivalent) | The tests detect injected defects | That the test set is complete — it missed T18 until review found it |
| Secrets | detect-secrets clean on both branches | No secret-shaped strings committed | Ongoing protection (GitHub scanning is off) |
| Dependencies | 0 vulnerabilities in shipped web deps; one dev-tooling advisory (`picomatch`, no fix) | Shipped web dependency posture | Flutter dependencies — **unscannable** |

> **A caution the approvers should note.** T18 — an actor lowering a review flag then approving alone — passed 235 assertions, CI and 41 mutants, and was found only by human review. Automated evidence here is necessary and demonstrably not sufficient.

---

## 5. What cannot be tested today

| Blocked | Cause | Unblocks when |
|---|---|---|
| L5 integration (auth, RLS, storage, RPC against real Supabase) | **No approved Supabase project** | A Luma-only dev project is approved with a cost owner and secret custodian |
| L6 end-to-end journeys | Depends on L5 | — |
| L8 resilience, retry, duplicate prevention | Depends on L5 | — |
| L10 backup restore, RPO/RTO | Depends on L5 | — |
| Flutter test suite on `main` | **`main` does not compile** (a string literal split across two lines in `lib/main.dart`); PR #6 fixes it. 2 marketplace tests still fail on PR #6 head | PR #6 merged and the two failures fixed |
| Flutter dependency scanning | **No `pubspec.lock` committed** | Lockfile committed |
| Automated secret / dependency / code scanning | **Disabled or blocked for the repository** | Enabled in settings |
| Upload validation and malware scanning tests | **The feature does not exist** | Upload hardening built |
| Independent review of either PR | **No reviewer assigned** | A reviewer is named |

---

## 6. Evidence required per gate

| Gate | Required | Status |
|---|---|---|
| **G3 — Build and component verification** | L1, L2, L3, L4 green and linked; §2 matrix complete; §3 invariants covered; dependency and secret scans enabled and clean | **Not met** — scanning disabled, no lockfile, §2 and §3 partly uncovered, Flutter CI failing |
| **G4 — Integration and system tests** | L5, L6, L8, L10; cross-tenant denial proven against real Supabase; audit checks; measured RPO/RTO | **Not startable** — no environment |
| **G5 — UAT and operational readiness** | Buyer, supplier and admin UAT by **real pilot representatives**; accessibility evidence; runbooks; privacy and retention controls; legal approvals | **Not met** — representatives VACANT, legal items risk-accepted |
| **G6 — Controlled pilot** | Approved cohort, support coverage, rollback and kill-switch, monitored metrics, go/no-go record | Not started |

---

## 7. Standing rules

1. **No test against production or real customer data.** Ever.
2. **No migration applied to a shared database** to make a test pass.
3. Every authorisation test runs **against the API directly**, never only through an interface.
4. A failing test is not disabled to achieve a green gate; it is fixed or recorded as a known failure with an owner.
5. Mutation testing accompanies any change to policy or authorisation logic.
6. CI results are **linked** from the gate record; a passing job referenced from nowhere is not evidence.
7. **Automated evidence never substitutes for independent review** at G4 and G5 — see §4.

---

## 8. Open items

| Item | Status |
|---|---|
| Isolated Supabase dev project | **Blocked** — approval, cost owner, secret custodian |
| Independent DB/security reviewer | **VACANT** — before G4 |
| Pilot buyer and supplier representatives | **VACANT** — before G5 |
| Repository scanning enabled | Open — before G3 |
| `pubspec.lock` committed | Open — before G3 |
| Flutter `main` compile fix and 2 failing tests | Open — PR #6 owner |
| Upload hardening and its tests | Open — before any real evidence |
| Performance and load targets | **Not defined** — needed for L8 |

---

## Approval

| Role | Signed by | Decision | Date |
|---|---|---|---|
| Product | | | |
| UX | | | |
| Engineering | | | |
| Security | | | |
| Operations | | | |
| Legal | | | |
