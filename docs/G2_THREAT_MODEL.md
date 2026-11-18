# G2 — Threat model

**Status: DRAFT for G2 approval. Not approved, and not an independent security review.**

G2 requires a threat model; this is it. It is written by the same person holding every other role, so it is a **self-assessment**. An independent security reviewer is required before G4 (G1 approval record §6).

Status values: **Implemented** = in code and tested · **Planned** = designed, not built · **GAP** = no mitigation exists.

---

## 1. What is being protected

Ranked by consequence of compromise.

| # | Asset | Why it matters |
|---|---|---|
| 1 | **Verification evidence** (ID and business documents) | Identity documents of real people. Disclosure enables identity fraud and is the most serious single loss |
| 2 | **Cross-organisation commercial data** (RFQs, quotations, prices, orders) | A competitor seeing another's pricing or demand destroys trust in the marketplace and is commercially damaging |
| 3 | **Payment records and evidence** | Enables payment fraud and impersonation of settled transactions |
| 4 | **Private correspondence** (messages, voice notes) | Personal content between parties; voice is biometric-adjacent |
| 5 | **Audit and verification decision history** | The record that makes every other control provable. If tampered with, nothing else can be trusted |
| 6 | **Contact details** (phone, email) | Harvesting target; enables off-platform scam approaches |
| 7 | **Platform integrity** (verified badges, listing authenticity) | A fake "verified" supplier is the highest-leverage attack on buyers |

---

## 2. Trust boundaries

| Boundary | Crossing | Assumption |
|---|---|---|
| B1 | Mobile client → Supabase | **Client is hostile.** Anything it sends is attacker-controlled, including role and membership claims |
| B2 | Admin web console → Admin API | Authenticated staff, but the console is still a client: it cannot be an authorisation point |
| B3 | Organisation → organisation | **Default deny.** No tenant may reach another's data by any path |
| B4 | Staff → marketplace data | Capability- and scope-limited; every privileged read is audited |
| B5 | Platform → private storage | Access only by authorised, time-limited signed URL |
| B6 | Platform → external payment providers | **No integration.** Payment is recorded, never transacted |
| B7 | Build pipeline → repository | Dependencies and CI config are an attack surface |

---

## 3. Threats

### Tenancy and authorisation

| ID | Threat | Vector | Mitigation | Status |
|---|---|---|---|---|
| T1 | **Cross-tenant read** of RFQs, quotes, orders or messages | Direct PostgREST query with a valid token for another org | RLS on every exposed table; org isolation as the central invariant; cross-org denial tested with separate identities | **Planned** — RLS drafted, untested against a real backend |
| T2 | **Privilege escalation via client claims** | Forged or mutated JWT metadata / profile fields claiming a staff role | Role and membership read server-side from authoritative tables; client claims never trusted | **Planned** (stated rule; needs test evidence) |
| T3 | **Unrouted supplier reads an RFQ** | Guessing RFQ identifiers | Only routed suppliers may read; routing rows are the authorisation source | **Planned** |
| T4 | **Buyer demand harvesting** | A supplier farms RFQ volume to profile competitors' buyers | Max 5 routed suppliers per RFQ; routing reason stored; verified suppliers only | **Planned** |
| T5 | **Admin console treated as the control** | Calling the API directly, bypassing hidden UI | "UI visibility is not authorisation"; server authorises every request | **Implemented** in design; needs direct-API tests at G4 |
| T6 | **Capability self-grant** | A staff actor grants itself a capability | Role administration is Super Admin only; an actor may not grant itself | **Planned** |

### Evidence and storage

| ID | Threat | Vector | Mitigation | Status |
|---|---|---|---|---|
| T7 | **Verification evidence disclosure** | Public bucket, guessable path, or a leaked long-lived URL | Private buckets; time-limited signed URLs only; access audited; buyers never see evidence | **Planned** — signed-URL function **not started** |
| T8 | **Malicious file upload** | Malware, or a file whose declared type lies, stored and later served | Content/magic-byte validation; malware scanning; never serve user files from a trusted origin | **GAP** — none of it exists. **No real evidence may be accepted until built** |
| T9 | **Stored XSS via uploaded or free-text content** | SVG/HTML upload, or script in a description or message rendered by the console | Strict content types; never render user HTML; CSP on the console | **Partial** — CSP defect found and fixed in the web foundation; upload side is a GAP |
| T10 | **Voice note abuse** | Harassment, illegal content, or malware in audio; hard to moderate at scale | Private by default; parties only; 12-month retention; report route | **GAP** — moderation approach for audio undefined |

### Commercial integrity

| ID | Threat | Vector | Mitigation | Status |
|---|---|---|---|---|
| T11 | **Accepted-quote tampering** | Editing terms after acceptance to change what was agreed | Order creation is atomic with an **immutable snapshot** of the accepted quote version; submitted versions never change; ordinary admins cannot rewrite agreed terms | **Planned** |
| T12 | **Fraudulent payment confirmation** | A user, or a non-Finance actor, asserting payment to obtain goods | Payment stays `pending_unverified` without authoritative evidence; **Finance only** may record confirmation; cash needs both parties plus Finance review; never "paid because a user said so" | **Implemented** in policy; enforcement **Planned** |
| T13 | **Payment state inferred from delivery** | Treating a delivered order as paid | Payment, order and fulfilment states are independent by design | **Planned** |
| T14 | **Duplicate RFQ or order from retries** | Poor connectivity → repeated submits | Idempotency keys on retryable writes; duplicate prevention | **Planned** — called for in the gap analysis; untested |
| T15 | **Quantity or currency confusion** | Silent unit/currency conversion creating a disputed obligation | Explicit currency and unit on every price and quantity; **no silent conversion** ever | **Implemented** in design and console |

### Identity and trust

| ID | Threat | Vector | Mitigation | Status |
|---|---|---|---|---|
| T16 | **Fake verified supplier** | Forged documents, or a verified account resold | Evidence review with recorded reviewer and reason; re-verification every 12 months; public wording states only what was checked and never implies endorsement or guarantee | **Planned** |
| T17 | **Self-approval of verification** | A reviewer approves their own or their org's case | No self-approval; independent second reviewer for high-risk, exceptions and rejected-to-approved | **Implemented** in policy and DB tests; **cannot currently be met by distinct humans** |
| T18 | **Review-flag downgrade then approve** | Lowering a review-requirement flag, then approving alone | Explicit standing rule; enforced in the risk policy | **Implemented** — *this was a real defect found in review; tests, CI and 41 mutants had missed it* |
| T19 | **Account takeover** | SIM swap or OTP interception — a material risk in the pilot market | Session and auth controls; sensitive actions re-authorised | **GAP** — auth contract not finalised; SIM-swap resistance not designed |
| T20 | **Impersonation of staff** | Phishing a staff session to reach admin capability | Token in memory only, never storage/cookie/URL; short-lived tokens; MFA for staff | **GAP** — staff MFA and token lifetime undecided |

### Privacy

| ID | Threat | Vector | Mitigation | Status |
|---|---|---|---|---|
| T21 | **PII harvesting by staff** | Repeated reveals or searches to build a contact list | Masked by default; reveal needs a stated purpose and is audited; search is server-side, returns ids only, audited without the term | **Implemented** in design |
| T22 | **Bulk exfiltration via export** | Exporting row-level data under a reporting pretext | No bulk row-level pilot exports; aggregates only; exports role-gated, logged, and must match the viewer's filters and scope | **Implemented** in policy |
| T23 | **Re-identification from aggregates** | Small-group statistics identifying a single supplier or buyer | Privacy-protected aggregation | **GAP** — minimum group size not set |
| T24 | **Contact scraping from public listings** | Automated collection of seller contact details | Contact details not published in listing responses; rate limiting | **Planned** |

### Audit and platform

| ID | Threat | Vector | Mitigation | Status |
|---|---|---|---|---|
| T25 | **Audit tampering** | Updating or deleting entries to hide an action | `audit_events` and `verification_decisions` **append-only**: no update, delete or truncate | **Implemented** and DB-tested |
| T26 | **Purge path abused to erase evidence** | The future 12-month purge used to destroy an inconvenient record | Purge is server-side only, skips legal holds, writes its own audit record, cannot touch decision history | **Planned** — path does not exist yet |
| T27 | **Secret leakage into the client** | Service-role key shipped in the Flutter app or repo | Publishable key only in clients; secrets outside source control; secret scanning | **Partial** — detect-secrets clean on both branches, but **GitHub secret scanning is disabled** |
| T28 | **Supply-chain compromise** | Malicious or vulnerable dependency | Dependency audit; lockfiles; advisory review | **Partial GAP** — 0 vulnerabilities in shipped web deps, but **Dependabot and code scanning disabled** and **no `pubspec.lock` committed**, so Flutter deps cannot be scanned |
| T29 | **Unauthorised migration against a shared database** | Applying a draft migration to staging or production | No migration applied to any shared database; no Supabase project approved | **Implemented** by process; no environment exists to protect yet |
| T30 | **Messaging/broadcast abuse** | Mass messaging suppliers, or using broadcast as a spam channel | Consent per channel; opt-out; frequency and recipient caps; second-admin approval above a threshold; every send audited | **Implemented** in the console prototype; server enforcement **Planned** |

---

## 4. Top residual risks

The five the approvers should weigh hardest.

| Rank | Risk | Why | Required before |
|---|---|---|---|
| 1 | **T8 — no upload hardening** | Accepting identity documents with no content validation and no malware scanning is the single largest exposure. It also makes T7 and T9 worse | **Any real verification evidence** |
| 2 | **T1/T2 untested against a real backend** | RLS and server-side authorisation are the load-bearing controls and have never run against a real Supabase project | G4 |
| 3 | **T17/T18 cannot be satisfied by distinct humans** | Separation of duties is enforced in code but one person holds every role, so no independent approval exists today | G4 (independent reviewer) |
| 4 | **T19/T20 — auth not designed** | Account takeover and staff session compromise have no designed mitigation; SIM swap is a live threat in this market | G4 |
| 5 | **T28 — Flutter dependencies unscannable** | No committed lockfile and scanning disabled means an unknown dependency posture on the client | G3 |

---

## 5. Explicitly out of scope

Because the MVP boundary excludes them. Each returns the moment the boundary moves.

- Payment settlement, wallet, stored value, escrow, lending, deposit-taking — **no funds move through the platform**, so settlement fraud, chargeback abuse and money-laundering typologies are out of scope for this gate.
- Live payment provider integration: webhook forgery and reconciliation attacks are deferred until a provider is approved.
- Precise location tracking: not collected, so location-inference threats are limited to district granularity.

---

## 6. Review

| Role | Signed by | Decision | Date |
|---|---|---|---|
| Security (independent) | **VACANT — required before G4** | | |
| Engineering | | | |
| Product | | | |
| Operations | | | |
| Legal | | | |
