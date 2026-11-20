# G1 — Requirements baseline: approval record

**Status: APPROVED BY THE ACCOUNTABLE OWNER — single-signer, with recorded risk acceptances.**

This is a **single-signer approval**. Joseph Momoh holds every approver role and has signed in each. That satisfies the gate register's requirement for recorded approval, and it does **not** constitute independent review. The independence gap is recorded in §5 as an accepted risk, and later gates (G4 integration, G5 UAT and security readiness, G6 pilot authorisation) will be scrutinised against it.

- **Gate:** G1 — Requirements baseline
- **Required exit evidence** (gate register): PRD reviewed; requirements, acceptance criteria, KPIs, exclusions and assumptions signed; unresolved TBDs risk-accepted or resolved
- **Approved:** 18 November 2026 by Joseph Momoh, Owner
- **Source of every value below:** issue #7 decision records of 17–18 Nov 2026. Nothing is inferred, and no value has been invented. Where a value was never supplied it is listed as open and risk-accepted, not filled with a placeholder.
- **Baseline document:** Susu Luma PRD & User Stories v1.0 (17 Oct 2026)

Reading key: **Approved rule** = owner decision, usable for design and build. **Provisional** = depends on local legal review; not final. **Risk-accepted** = unresolved, consciously carried, with the condition attached.

---

## 1. Exit-criteria coverage

| G1 exit criterion | Evidence | State |
|---|---|---|
| PRD reviewed | PRD v1.0; reviewed by the Owner | **Met** (owner review; no stakeholder panel) |
| Requirements signed | `docs/requirements-traceability.md`; gap analysis (PR #6) | **Signed** (§6) |
| Acceptance criteria signed | Per-ticket acceptance on #28–#72 | **Signed** (§6) |
| KPIs signed | D8 metric set named; definitions risk-accepted (§4 item 12) | **Met with condition** |
| Exclusions and assumptions signed | MVP boundary (§2, D1) | **Signed** (§6) |
| Unresolved TBDs risk-accepted or resolved | §4 register — 23 items, each resolved or risk-accepted | **Met** |
| Approver signatures | §6 | **Met** (single signer) |

---

## 2. Non-negotiable MVP boundary (D1 — approved as written)

- **P0:** ADM-01 to 07, ADM-13, ADM-14. **P1:** ADM-08 to 12. Foundation tickets #70–#72 are P0.
- No Susu Luma-operated wallet, stored value, escrow, lending, credit scoring, deposit-taking or payment settlement.
- Order, payment and fulfilment states remain separate.
- Admin console is a **separate responsive web console**, not Flutter.

---

## 3. Recorded decisions

### D1 — Scope and MVP boundary · **Approved as written**
See §2. Success-measure definitions depend on D8 (§4 item 12).

### D2 — Supplier verification · **Approved**
Re-verification every **12 months**, or earlier on risk · independent **second reviewer** for high-risk approvals, policy exceptions and rejected-to-approved decisions · **self-approval prohibited** · immutable decision history · evidence private, never visible to buyers · case states `pending`, `in_review`, `approved`, `rejected`, `expired` · public wording states only what was checked and never implies government endorsement, solvency, certification or quality.

### D3 — RFQ routing · **Approved**
Maximum **5 verified** suppliers per RFQ · verified suppliers only · every routed recipient carries a stored reason (category match, district match, or admin assignment) · only routed suppliers can see an RFQ · admins may assign or override with a note.

### D4 — Quotes and order intent · **Approved**
Quote validity **24 hours to 30 days** · supplier confirmation window **48 hours** · buyer accepts a submitted, unexpired quote and the server creates the order atomically with an **immutable snapshot** of that quote version · initial state `awaiting_seller_confirmation` · acceptance is order intent, **not** payment · a revision creates a new version and submitted versions never change · expired and withdrawn quotes cannot be accepted.

### D5 — Payments · **Approved as written**
**Record-only.** No payment provider in the MVP; payment happens outside the app · states `pending_unverified`, `externally_confirmed`, `under_review`, `not_applicable` · **Finance Officers only** record external confirmation · **cash in person** requires both parties' acknowledgment plus Finance review · never shown as paid because a user said so · recordable methods: JubaSecure, Orange Money, Afrimoney, Ezipay, GTPay, PayPal, cash in person — **recorded only, none integrated** · adding a provider later is a new decision requiring legal/compliance review, authenticated webhooks and reconciliation.

> **Not verified:** which of the seven operate in Sierra Leone, or what licences they hold. Carried as a risk (§4 item 24).

### D6 — Delivery and disputes · **Approved, liability wording risk-accepted**
Dispute window **72 hours after buyer-confirmed receipt** · platform coordinates and records, holds no goods or funds, so liability sits between buyer and supplier under the accepted quote terms · proof of delivery is a `proof_of_delivery` event with private evidence, actor and timestamp · dispute flow: either party opens an issue → order becomes `disputed` → support case → admin reviews evidence · outcomes are recorded decisions and listing or account actions, with **no refunds or fund movements**.

**Owner decisions added at approval:** delivery is confirmed by the **buyer**, with supplier-submitted proof of delivery as supporting evidence. Escalation beyond admin review goes to the **Owner**.

### D7 — Support · **Approved**
Monday–Saturday, **08:00–18:00 UTC** · continuous ticket intake · P1 out-of-hours escalation approved · **P1** 1-hour response / 24-hour resolution · **P2** 4 support-hour response / 2-business-day resolution · **P3** 1-business-day response / 5-business-day resolution · **P4** 2-business-day response / 10-business-day resolution · accountable role **Operations Lead (Joseph Momoh, acting)** · **targets, not guarantees**.

**Owner decisions added at approval:** "business day" means Monday–Saturday excluding Sierra Leone public holidays. Out-of-hours P1 routes to the Owner. P1–P4 qualification criteria remain open and risk-accepted (§4 item 8).

### D8 — Privacy and analytics · **Approved rules; legal review risk-accepted**
No bulk row-level pilot exports · privacy-protected aggregate reporting · controlled legal access · essential analytics only by default · consent for non-essential tracking where required · no advertising trackers by default · every export role-gated and logged with actor, scope and time, matching the filters and role scope the person sees.
P0 metric set: active suppliers, published listings, RFQ volume, first-response time, quote rate, order states, complaints, verification backlog.

### D9 — Pilot geography and language · **Approved**
First pilot footprint: **all 16 in-force districts** · five regions: Eastern, Northern, North West, Southern, Western · 16 active districts: Kailahun, Kenema, Kono · Bombali, Falaba, Koinadugu, Tonkolili · Kambia, Karene, Port Loko · Bo, Bonthe, Moyamba, Pujehun · Western Area Urban, Western Area Rural · **Bandajuma and Kpanguma remain proposed, not in force, inactive** · areas and localities **inactive**, none verified or loaded · official language **English** · local languages via **voice notes**, not translated screens · direction: simple, WhatsApp-like · pilot caps **150 invited buyers**, **50 verified suppliers**.

⚠️ **The scope-change review for the 16-district footprint has not been performed by an independent reviewer.** The Owner has risk-accepted it (§4 item 17, §5). It is recorded as an accepted risk, **not** as a satisfied review.

### D10 — Retention · **PROVISIONAL** (legal basis risk-accepted)
| Data class | Period |
|---|---|
| Active account records | While legitimately required |
| Closed profiles | 12 months |
| Verification evidence | 12 months after closure |
| Orders, quotations, payment records | **7 years** after closure |
| Support records | 24 months |
| Fraud / dispute records | 3 years |
| Audit records (operational events) | 12 months — see §5 |
| **Voice notes** | **12 months** (owner decision added at approval) |

### D11 — Restricted goods · **Approved rules; list risk-accepted**
Illegal and dangerous goods prohibited · regulated and age-restricted categories stay **unavailable** until approved controls, permits and moderation exist · legal review required before any restricted category is activated · category edits must not silently break existing listings (ADM-13).

**Interim position adopted at approval:** deny-by-default. No regulated or age-restricted category is activated during the pilot, so the absence of a definitive list does not block the pilot.

---

## 4. Open-item register — resolved or risk-accepted

Owner for every item: **Joseph Momoh**. The gate register permits unresolved TBDs to be **risk-accepted or resolved**; this register does both. Due dates are expressed as **conditions** (tied to a gate or event) rather than invented calendar dates.

| # | Open item | Dec. | Disposition | Condition / due |
|---|---|---|---|---|
| 1 | Evidence document list | D2 | **Risk-accepted** | Before any real verification evidence is accepted |
| 2 | Definition of "high risk" | D2 | **Risk-accepted** (owner, acting Security) | Before second-reviewer logic goes live |
| 3 | May buyers pick suppliers directly | D3 | **Resolved: No** for the pilot | — |
| 4 | Cancellation rights per order state | D4 | **Risk-accepted** | Before G3 build of ADM-03 |
| 5 | Who confirms delivery | D6 | **Resolved: buyer confirms** | — |
| 6 | Dispute escalation beyond admin | D6 | **Resolved: escalates to Owner** | — |
| 7 | Liability wording confirmation | D6 | **Risk-accepted — cannot be self-certified** | External counsel before G5 |
| 8 | P1–P4 qualification criteria | D7 | **Risk-accepted** | Before pilot support goes live (G6) |
| 9 | "Business day" + holidays | D7 | **Resolved: Mon–Sat, excl. SL public holidays** | — |
| 10 | Out-of-hours P1 route + roster | D7 | **Resolved: routes to Owner** | Roster needed when staff are hired |
| 11 | Named Operations Lead | D7 | **Resolved: Joseph Momoh, acting** | Re-assign on hire |
| 12 | Metric definitions | D8 | **Risk-accepted** | Before ADM-07 build (G3) |
| 13 | Consent wording | D8 | **Risk-accepted — cannot be self-certified** | External counsel before any non-essential tracking |
| 14 | "Privacy-protected" min. group size | D8 | **Risk-accepted** | Before any aggregate report is published |
| 15 | Areas layer + official source file | D9 | **Risk-accepted; areas stay inactive** | Owner to supply EC ward or StatsSL chiefdom file |
| 16 | Proposed-district handling | D9 | **Resolved: inactive, flagged `proposed`** | Re-decide on enactment |
| 17 | Scope-change review, 16 districts | D9 | **Risk-accepted by Owner — not an independent review** | External Security/Legal before G6 |
| 18 | Retention legal-basis review | D10 | **Risk-accepted — cannot be self-certified** | External counsel before G5 |
| 19 | Legal hold, deletion, backup controls | D10 | **Open — engineering work** | Must be written before G4 |
| 20 | Voice-note retention line | D10 | **Resolved: 12 months** | Legal basis per item 18 |
| 21 | Audit-retention contradiction | D10 | **Resolved: Option A** (§5) | — |
| 22 | Prohibited / restricted lists | D11 | **Risk-accepted; deny-by-default interim** | External counsel before activating any restricted category |
| 23 | Voice notes as a baseline change | D9 | **Approved as a scope change** | Tickets to be raised; not yet in the PRD |
| 24 | Payment-method licensing in SL | D5 | **Risk-accepted** | External counsel before any integration |

**Five items cannot be self-certified** (7, 13, 18, 22, and the legal half of 14). They are statements about Sierra Leone law, not product decisions. They are carried as accepted risks with the conditions above, and **each must be reviewed by external counsel before the gate named in its condition.**

---

## 5. Decisions taken at approval

### Audit retention — **Option A adopted**

D10 set audit records at 12 months, while `audit_events` and `verification_decisions` are append-only by design and D2 requires an immutable decision history. **Option A** is adopted: the 12-month period applies to **operational audit events only**; `verification_decisions` are retained indefinitely as immutable decision history.

Option A was chosen because B amends a recorded retention decision and C directly contradicts D2's immutability requirement. **Consequence:** an audited, legal-hold-aware purge path for `audit_events` must be built; it does not exist yet, and until it does, operational audit events are retained rather than purged. That is a deliberate, recorded over-retention.

### Independence gap — **risk accepted**

Every approver role in §6 is held by one person. There has therefore been **no independent review** of requirements, security design, legal position or operational readiness at G1. The Owner accepts this risk on the basis that:

- the pilot is capped at 150 invited buyers and 50 verified suppliers;
- payments are record-only, so no funds move through the platform;
- no production deployment is authorised by this gate;
- the five legal items above are carried with external-counsel conditions attached.

**This acceptance does not carry forward.** G4, G5 and G6 each require evidence that one person cannot produce alone — integration and cross-tenant testing, UAT by real buyers and suppliers, and a security readiness review. Independent reviewers must be engaged before those gates.

---

## 6. Approver signatures — G1

All roles are held by the Owner, acting in each capacity. Titles are recorded as capacities, not as separate people.

| Approver role | Signed by | Decision | Date | Conditions |
|---|---|---|---|---|
| Sponsor | Joseph Momoh | **Approve** | 18 Nov 2026 | §4 risk acceptances |
| Product Owner | Joseph Momoh | **Approve** | 18 Nov 2026 | §4 risk acceptances |
| Operations | Joseph Momoh (acting Operations Lead) | **Approve** | 18 Nov 2026 | P1–P4 criteria before G6 |
| Engineering / Security | Joseph Momoh (acting Engineer) | **Approve** | 18 Nov 2026 | Independent reviewer before G4 |
| Finance / Legal | Joseph Momoh (acting Finance/Legal liaison) | **Approve** | 18 Nov 2026 | **External counsel on items 7, 13, 14, 18, 22, 24** |
| Pilot buyer representative | **VACANT** | — | — | Required at G5 UAT |
| Pilot supplier representative | **VACANT** | — | — | Required at G5 UAT |

**Pilot representatives are deliberately left vacant.** They cannot be the Owner: their purpose is to test whether real buyers and suppliers can use the product. They must be named before G5.

### Role register

| Role | Capacity held by | Re-assign when |
|---|---|---|
| Sponsor | Joseph Momoh | — |
| Product Owner | Joseph Momoh | — |
| Operations Lead | Joseph Momoh (acting) | Operations hire |
| Engineer | Joseph Momoh (acting) | Engineering hire |
| UX | Joseph Momoh (acting) | Design hire |
| Security Lead | Joseph Momoh (acting) | **Before G4** — independent review required |
| Legal | Joseph Momoh (acting liaison only; **not** a legal determination) | **External counsel** for items 7, 13, 18, 22, 24 |
| Independent DB/security reviewer | **VACANT** | Before G4 |
| Pilot buyer representative | **VACANT** | Before G5 |
| Pilot supplier representative | **VACANT** | Before G5 |

---

## 7. What this approval does **not** authorise

- **Not** a G2 approval. UX, architecture and security design are a separate gate, and four of its seven required artifacts do not yet exist.
- **Not** authority to deploy. No production deployment until G0–G5 have documented exit approval and G6 explicitly authorises the pilot.
- **Not** authority to apply a migration to any shared, staging or production database, or to create a Supabase project.
- **Not** approval of any payment integration. The model stays record-only.
- **Not** approval of restricted or age-restricted categories; deny-by-default stands.
- **Not** a legal determination on retention, liability, consent or prohibited goods. Those remain risk-accepted pending external counsel.
- **Not** authority to accept real verification evidence: upload hardening (content validation, malware scanning, signed URLs) does not exist.
- **Not** a substitute for independent review at G4, G5 and G6.
