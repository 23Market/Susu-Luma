# G1 — Requirements baseline: approval record

**Status: UNSIGNED. This document does not approve anything.**

This is the instrument the G1 approvers sign. It gathers every policy decision recorded on issue #7 into one place, separates approved rules from provisional ones, lists what is still open, and provides the signature blocks the gate register requires. **G1 remains open until the signature table below is complete.**

- **Gate:** G1 — Requirements baseline
- **Required exit evidence** (gate register): PRD reviewed; requirements, acceptance criteria, KPIs, exclusions and assumptions signed; unresolved TBDs risk-accepted or resolved
- **Required approvers:** Sponsor, Product Owner, Operations, Engineering/Security, Finance/Legal, pilot buyer/supplier
- **Source of every value below:** issue #7 decision records of 17–18 Nov 2026. Nothing here is inferred, and no value has been invented. Where a value was never supplied it is listed as open, not filled with a placeholder.
- **Baseline document:** Susu Luma PRD & User Stories v1.0 (17 Oct 2026), still marked *draft for stakeholder review*.

Reading key: **Approved rule** = Product Owner decision, usable for design and build. **Provisional** = depends on local legal review; not final. **Open** = no value supplied.

---

## 1. Exit-criteria coverage

| G1 exit criterion | Evidence | State |
|---|---|---|
| PRD reviewed | PRD v1.0 still marked draft for stakeholder review | **Not met** — no recorded review |
| Requirements signed | `docs/requirements-traceability.md`; gap analysis (PR #6) | Documented, **unsigned** |
| Acceptance criteria signed | Per-ticket acceptance on #28–#72 | Documented, **unsigned** |
| KPIs signed | D8 metric set named; definitions open | **Partial** |
| Exclusions and assumptions signed | MVP boundary (§2, D1) | Documented, **unsigned** |
| Unresolved TBDs risk-accepted or resolved | §4 register below | **Not met** — no risk acceptances recorded |
| Approver signatures | §6 | **Not met** |

---

## 2. Non-negotiable MVP boundary (D1 — approved as written)

- **P0:** ADM-01 to 07, ADM-13, ADM-14. **P1:** ADM-08 to 12. Foundation tickets #70–#72 are P0.
- No Susu Luma-operated wallet, stored value, escrow, lending, credit scoring, deposit-taking or payment settlement.
- Order, payment and fulfilment states remain separate.
- Admin console is a **separate responsive web console**, not Flutter (decision of 18 Nov).

---

## 3. Recorded decisions

### D1 — P0/P1 scope and MVP boundary · **Approved as written**
See §2. Success-measure definitions depend on D8 and are open.

### D2 — Supplier verification · **Approved rules, with gaps**
| Item | Value |
|---|---|
| Re-verification | Every **12 months**, or earlier on risk |
| Second reviewer | Independent second reviewer for high-risk approvals, policy exceptions and rejected-to-approved decisions |
| Self-approval | **Prohibited** |
| Decision history | Immutable |
| Evidence privacy | Private; buyers never see verification documents |
| Case states | `pending`, `in_review`, `approved`, `rejected`, `expired` |
| Public wording | States only what was checked; never implies government endorsement, solvency, certification or quality |

**Open:** the evidence document list; the definition of **"high risk"** (blocks acceptance of the implemented risk policy).

### D3 — RFQ routing · **Approved rules, with gaps**
| Item | Value |
|---|---|
| Recipient cap | Maximum **5 verified** suppliers per RFQ |
| Eligibility | Verified suppliers only |
| Routing reason | Every routed recipient has a stored reason: category match, district match, or admin assignment |
| Visibility | Only routed suppliers can see an RFQ |
| Override | Admins may assign or override with a note |

**Open:** whether buyers may pick suppliers directly.

### D4 — Quotes and order intent · **Approved rules, with gaps**
| Item | Value |
|---|---|
| Quote validity | **24 hours to 30 days** |
| Supplier confirmation window | **48 hours** |
| Acceptance | Buyer accepts a submitted, unexpired quote; server creates the order atomically with an **immutable snapshot** of that quote version |
| Initial order state | `awaiting_seller_confirmation` |
| Meaning | Acceptance is order intent, **not** payment |
| Revisions | A revision creates a new version; submitted versions never change |
| Expired / withdrawn | Cannot be accepted |

**Open:** cancellation rights — who may cancel in which order state, and the consequence.

### D5 — Payments · **Approved as written**
| Item | Value |
|---|---|
| Model | **Record-only.** No payment provider in the MVP; payment happens outside the app |
| States | `pending_unverified`, `externally_confirmed`, `under_review`, `not_applicable` |
| Who may confirm | **Finance Officers only** record external confirmation |
| Cash in person | Requires **both parties' acknowledgment plus Finance review** |
| Default | Never shown as paid because a user said so |
| Recordable methods | JubaSecure, Orange Money, Afrimoney, Ezipay, GTPay, PayPal, cash in person — **recorded only, none integrated** |
| Adding a provider later | A new decision requiring legal/compliance review, authenticated webhooks and reconciliation |

**Note:** no check has been made of which of the seven operate in Sierra Leone or what licences they hold. That belongs to the legal review.

### D6 — Delivery and disputes · **Approved rules, with gaps**
| Item | Value |
|---|---|
| Dispute window | **72 hours after buyer-confirmed receipt** |
| Liability | Platform coordinates and records; holds no goods or funds, so liability sits between buyer and supplier under the accepted quote terms — **local counsel must confirm this wording** |
| Proof of delivery | A `proof_of_delivery` event with private evidence, actor and timestamp |
| Dispute flow | Either party opens an issue → order becomes `disputed` → support case → admin reviews evidence |
| Outcomes | Recorded decisions, listing or account actions. **No refunds or fund movements** |

**Open:** who confirms delivery (buyer, supplier or both); escalation beyond admin review; counsel's confirmation of the liability wording.

### D7 — Support · **Approved rules, with gaps**
| Item | Value |
|---|---|
| Support hours | **Monday–Saturday, 08:00–18:00 UTC** |
| Ticket intake | Continuous |
| P1 out-of-hours escalation | Approved |
| P1 | 1-hour response · 24-hour resolution target |
| P2 | 4 support-hour response · 2-business-day resolution target |
| P3 | 1-business-day response · 5-business-day resolution target |
| P4 | 2-business-day response · 10-business-day resolution target |
| Accountable role | **Operations Lead — UNASSIGNED** |
| Status | **Targets, not guarantees** |

**Open:** what qualifies as P1/P2/P3/P4; the definition of "business day" and any holiday calendar; the out-of-hours P1 contact route and on-call roster; the named Operations Lead.

### D8 — Privacy and analytics · **Approved rules; legal/privacy review mandatory**
- No bulk row-level pilot exports · privacy-protected aggregate reporting · controlled legal access · essential analytics only by default · consent for non-essential tracking where required · no advertising trackers by default.
- P0 metric set (from ADM-07): active suppliers, published listings, RFQ volume, first-response time, quote rate, order states, complaints, verification backlog.
- Every export is role-gated and logs actor, scope and time, and must match the filters and role scope the person sees.

**Open:** metric definitions (e.g. what starts and stops "first-response time", what counts as an "active supplier"); consent wording; what "privacy-protected" means numerically (e.g. minimum group size).

### D9 — Pilot geography and language · **Approved**
| Item | Value |
|---|---|
| First pilot footprint | **All 16 in-force districts** (decision of 18 Nov ~01:40; replaces both "Western Area only" and the earlier "all 18") |
| Regions | Eastern, Northern, North West, Southern, Western |
| 16 active districts | Kailahun, Kenema, Kono · Bombali, Falaba, Koinadugu, Tonkolili · Kambia, Karene, Port Loko · Bo, Bonthe, Moyamba, Pujehun · Western Area Urban, Western Area Rural |
| Bandajuma, Kpanguma | **Proposed, not in force — inactive.** No published boundaries |
| Areas / localities | **Inactive.** No areas list verified or loaded |
| Official language | **English** |
| Local languages | Supported via **voice notes**, not translated screens |
| Direction | Simple, WhatsApp-like: few screens, little text, conversation-first |
| Pilot caps | Max **150 invited buyers**, max **50 verified suppliers** |

⚠️ **Activation gate:** a footprint wider than the Western Area is a material scope change, and the directive requires **Security and Legal review**. No reviewer is assigned. **No district outside the Western Area may go live until that review is recorded.**

**Open:** the areas source file and layer (**190 chiefdoms** or **446 electoral wards** — pick one and supply an official file: Electoral Commission 2017 ward list, or Statistics Sierra Leone chiefdom list); whether the two proposed districts become selectable later; the `district` field is free text with **no area column** in the draft schema, so adding areas is a schema change.

### D10 — Retention · **PROVISIONAL** (pending local legal review)
| Data class | Period |
|---|---|
| Active account records | While legitimately required |
| Closed profiles | 12 months |
| Verification evidence | 12 months after closure |
| Orders, quotations, payment records | **7 years** after closure |
| Support records | 24 months |
| Fraud / dispute records | 3 years |
| Audit records | 12 months |

**Open:** legal holds, deletion procedures and backup retention need documented controls (not written). **Voice notes have no retention line.** See the conflict in §5.

### D11 — Restricted goods · **Approved rules; legal review before activation**
- Illegal and dangerous goods prohibited. Regulated and age-restricted categories stay **unavailable** until approved controls, permits and moderation exist. Legal review required before any restricted category is activated. Category edits must not silently break existing listings (ADM-13).

**Open:** the actual prohibited and restricted category lists.

---

## 4. Open-item register — owner and due date required

The gate register requires unresolved TBDs to be **risk-accepted or resolved**, and #7's acceptance criteria require **an owner and a due date for every unresolved item**. Owner is recorded as Joseph Momoh for all items; **no due dates have been set**. Each row needs either a resolution, or a dated owner, or a recorded risk acceptance.

| # | Open item | Decision | Needs | Owner | Due | Risk-accepted? |
|---|---|---|---|---|---|---|
| 1 | Evidence document list | D2 | Ops + Legal | | | |
| 2 | Definition of "high risk" | D2 | Security Lead | | | |
| 3 | May buyers pick suppliers directly | D3 | Product Owner | | | |
| 4 | Cancellation rights per order state | D4 | Product Owner + Legal | | | |
| 5 | Who confirms delivery | D6 | Product Owner | | | |
| 6 | Dispute escalation beyond admin | D6 | Operations | | | |
| 7 | Liability wording confirmation | D6 | Local counsel | | | |
| 8 | P1–P4 qualification criteria | D7 | Operations Lead | | | |
| 9 | "Business day" + holiday calendar | D7 | Operations Lead | | | |
| 10 | Out-of-hours P1 route + on-call roster | D7 | Operations Lead | | | |
| 11 | Named Operations Lead | D7 | Sponsor | | | |
| 12 | Metric definitions | D8 | Product + Analyst | | | |
| 13 | Consent wording | D8 | Legal | | | |
| 14 | "Privacy-protected" minimum group size | D8 | Legal + Product | | | |
| 15 | Areas layer + official source file | D9 | Product Owner | | | |
| 16 | Proposed-district handling | D9 | Product Owner | | | |
| 17 | Security/Legal reviewers for 16-district footprint | D9 | Sponsor | | | |
| 18 | Retention legal-basis review | D10 | Local counsel | | | |
| 19 | Legal hold, deletion, backup controls | D10 | Legal + Engineering | | | |
| 20 | Voice-note retention line | D10 | Legal | | | |
| 21 | Audit-retention conflict (§5) | D10 | Product Owner + Legal | | | |
| 22 | Prohibited / restricted category lists | D11 | Legal | | | |
| 23 | Voice notes as a baseline change | D9 | Product Owner (CCB) | | | |

---

## 5. Contradiction requiring a decision before G1

**D10 sets audit records at 12 months. `audit_events` and `verification_decisions` are append-only by design** — no update, delete or truncate — and D2 separately requires an *immutable* verification decision history. These cannot both hold without a deliberate mechanism.

Three options; one must be chosen and recorded:

| Option | Effect | Cost |
|---|---|---|
| **A** — Audit retention excludes decision history | 12-month purge applies to operational audit events only; `verification_decisions` kept indefinitely | Needs an audited, legal-hold-aware purge path for `audit_events`, which does not exist |
| **B** — Audit records kept indefinitely | Append-only design stands unchanged; D10's audit line is amended | Requires legal confirmation that indefinite retention is lawful and proportionate |
| **C** — Full purge path for both | D10 applies as written | Contradicts D2's immutability requirement; **not recommended** |

---

## 6. Approver signatures — G1

G1 is **not** passed until every row is signed. A signature records that the signer has reviewed §1–§5 and either accepts the open items in §4 as risk-accepted or requires them resolved first.

| Approver role | Name | Decision (Approve / Revise / Reject) | Date | Conditions |
|---|---|---|---|---|
| Sponsor | | | | |
| Product Owner | | | | |
| Operations | | | | |
| Engineering / Security | | | | |
| Finance / Legal | | | | |
| Pilot buyer representative | | | | |
| Pilot supplier representative | | | | |

### Roles that must be named first

Five roles are referenced by these decisions and are **unassigned in every repository document**. G1 cannot be signed by roles that do not exist.

| Role | Purpose | Named person |
|---|---|---|
| Operations Lead | Accountable for D7 support targets | |
| Security Lead | Define "high risk"; accept the verification risk policy | |
| Independent DB/security reviewer | Review PR #76 | |
| Security reviewer — scope change | 16-district footprint | |
| Legal reviewer — scope change | 16-district footprint; D6, D8, D10, D11 | |

---

## 7. What signing this does **not** approve

- **Not** a G2 approval. UX, architecture and security design are a separate gate.
- **Not** authority to deploy. No deployment to production until G0–G5 have documented exit approval and G6 explicitly authorises the pilot.
- **Not** authority to activate any district outside the Western Area — that needs the §6 scope-change review.
- **Not** authority to apply a migration to any shared, staging or production database, or to create a Supabase project.
- **Not** approval of any payment integration. The model stays record-only.
- **Not** approval of restricted or age-restricted categories; they stay unavailable.
- **Not** acceptance of provisional retention periods as legally final.
