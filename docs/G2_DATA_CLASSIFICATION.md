# G2 — Data classification and retention schedule

**Status: DRAFT for G2 approval. Retention periods are PROVISIONAL pending external legal review.**

G2 requires a data classification and retention artifact; this is it. It was blocked on the audit-retention contradiction, which the G1 approval resolved as **Option A**.

Provenance: **[recorded]** = decided on #7 or in the G1 approval record · **[proposed]** = drafted here for G2 approval.

> **Legal status.** The retention periods in §3 are **Product Owner decisions, risk-accepted without legal review** (G1 §4 items 18, 20). They are not a legal determination of what Sierra Leone law requires. External counsel must review them before G5.

---

## 1. Classification scheme

[proposed] Four levels. Classification drives storage, access control and retention.

| Level | Definition | Controls required |
|---|---|---|
| **R — Restricted** | Identity and verification evidence; anything whose disclosure could enable fraud or cause serious harm | Private bucket; authorised time-limited signed URL only; access audited; never in a list response; never in an export |
| **C — Confidential** | Commercial terms and private correspondence between two organisations | RLS-enforced org isolation; no cross-org read; masked identifiers where shown to staff |
| **I — Internal** | Operational and administrative records | Staff capability check; aggregate-only for Analyst |
| **P — Public** | Deliberately published marketplace content | Readable per listing visibility rules |

**Personal data** is a cross-cutting attribute, not a level: any class may contain it, and masking rules in §4 apply wherever it does.

---

## 2. Data inventory and classification

[proposed] classification; [recorded] where a decision already named the item.

| Data class | Level | Contains personal data | Storage | Access control |
|---|---|---|---|---|
| Organisation profile | I | Limited (contact) | Table | Public subset; full to staff with `organisations.view` |
| User account and membership | C | Yes | Table | Self + org owner + staff `users.view` (masked) |
| **Verification evidence** (ID, business documents) | **R** | Yes | **Private bucket** | Signed URL only, `verification.evidence.view`, audited. **Buyers never see it** [recorded] |
| Verification decision history | I | Reviewer identity | Table, **append-only** [recorded] | `verification.view`; immutable |
| Listings and catalogue | P | Seller identity | Table | Public per visibility rules |
| RFQ (items, quantities, units, destination) | C | Requester identity | Table | Buyer org + **routed** suppliers only [recorded] |
| RFQ routing records | I | — | Table | `rfqs.routing.view` |
| Quotation, line prices, terms | C | — | Table | Issuing supplier + recipient buyer only |
| Accepted-quote snapshot | C | — | Table, **immutable** [recorded] | Parties + staff `orders.view` |
| Order and commercial terms | C | — | Table | Parties + staff |
| **Payment records** (provider, reference, amount) | **R** | Yes (payer reference) | Table | `payments.view`; confirmation `payments.reconcile` (Finance only) [recorded] |
| Payment evidence | **R** | Yes | Private bucket | Signed URL, `payments.evidence.view`, audited |
| **Delivery / order evidence** | **R** | Possibly (images) | Private bucket | Signed URL, `fulfilment.evidence.view` [recorded] |
| Inquiry messages (text) | C | Yes (free text) | Table | Parties only; staff on an assigned case |
| **Voice notes** | **R** | Yes (voice is biometric-adjacent) | Private bucket | Parties only; staff on an assigned case. **New in scope** [recorded] |
| Support cases and internal notes | I | Yes | Table | `support.cases.view`; internal notes never user-visible [recorded] |
| Reviews | P | Author identity | Table | Public once published |
| **Audit events** (operational) | I | Actor identity | Table, **append-only** [recorded] | `audit.view`; export `audit.export` |
| Privacy requests | **R** | Yes | Table | `privacy.requests.view` only |
| Analytics events | I | Pseudonymous | Table | Aggregate only [recorded] |
| Backups | Inherits highest class in scope | Yes | Managed | Controls **not yet written** — see §6 |

---

## 3. Retention schedule

[recorded] periods, **provisional** pending legal review.

| Data class | Retention | Trigger | Basis |
|---|---|---|---|
| Active account records | While legitimately required | — | Provisional |
| Closed profiles | 12 months | Closure | Provisional |
| Verification evidence | 12 months | After closure | Provisional |
| Orders, quotations, payment records | **7 years** | After closure | Provisional — likely tax/commercial driven; **counsel to confirm** |
| Support records | 24 months | Case closure | Provisional |
| Fraud / dispute records | 3 years | Case closure | Provisional |
| **Audit events (operational)** | **12 months** | Event date | Provisional — **Option A**, see §5 |
| **Verification decision history** | **Indefinite** | — | **Option A** [recorded] |
| **Voice notes** | **12 months** | Creation | [recorded] at G1 approval |
| Analytics events | Not specified | — | **Open** — see §6 |
| Backups | Not specified | — | **Open** — see §6 |

A **legal hold overrides deletion** for any class. [recorded]

---

## 4. Masking and minimisation

[recorded]

- Phone numbers and email addresses are masked **by the server** in every response. Masked form only ever leaves the server, except through a purpose-stated reveal.
- Reveal requires `users.pii.reveal` + a purpose from `ticket`, `fraud`, `legal`, `recovery`; it is audited; the next read re-masks.
- Email and phone search runs server-side, returns identifiers only, and is audited **without storing the search term**.
- No bulk row-level pilot exports. Reporting is privacy-protected aggregate. [recorded]
- Essential analytics only by default; consent for non-essential tracking; no advertising trackers. [recorded]
- Location is captured at **district** granularity. Areas are inactive. Precise location is not collected. [recorded]
- Analyst receives no record-level personal data.

**Open:** what "privacy-protected" means numerically — a minimum group size for any published aggregate. Risk-accepted (G1 §4 item 14); **must be set before any aggregate is published**.

---

## 5. Audit retention — Option A as adopted

[recorded] The conflict: D10 set audit records at 12 months, while `audit_events` and `verification_decisions` are append-only by design and D2 requires immutable decision history.

**Option A is adopted.** The 12-month period applies to **operational audit events only**. `verification_decisions` are retained indefinitely as immutable decision history.

**Consequence, recorded and unresolved:** enforcing 12 months requires an **audited, legal-hold-aware purge path** that does not exist. Until it is built, operational audit events are **deliberately over-retained**. This is a known, accepted divergence from the schedule, not a defect.

Requirements for that purge path [proposed]:

1. Runs as a privileged server-side job, never a client-reachable deletion.
2. Skips any record under legal hold, and records what it skipped.
3. Writes its own audit record: scope, count, actor, time — the purge is itself auditable.
4. Cannot touch `verification_decisions`.
5. Is covered by tests proving legal-hold records survive it.

---

## 6. Controls that do not yet exist

These are gaps, named rather than glossed. [recorded as missing]

| Gap | Impact | Required before |
|---|---|---|
| Legal hold mechanism | Cannot suspend deletion for a dispute or legal request | G4 |
| Deletion procedures | No documented or tested path for any class | G4 |
| Backup retention and restore controls | Backups may outlive the schedule; RPO/RTO unmeasured | G4 |
| Audit purge path | §5 — schedule unenforceable | G4 |
| **Evidence upload hardening** | No content/magic-byte validation, no malware scanning, no signed-URL function. **No real verification evidence may be accepted until this exists** | Before any real evidence |
| Analytics event retention | Unspecified | G5 |
| External legal review | Periods are provisional; legal basis unconfirmed | G5 |
| Repository scanning | Secret scanning, Dependabot and code scanning disabled | G3 |

---

## 7. Privacy requests

[recorded] Handled through ADM-10: identity and authority check → scope determination → hold and retention flags → approval → completion evidence → irreversible-action confirmation. The request itself is always audited. No request is silently marked complete.

Request types: access, correction, deletion/closure, retention review, other approved type.

**Open:** who approves a deletion; and the consent wording (both risk-accepted, counsel required).

---

## 8. Open items

| Item | Status |
|---|---|
| Legal review of every retention period | Risk-accepted (G1 §4 item 18) — counsel before G5 |
| Consent wording | Risk-accepted (G1 §4 item 13) — counsel before non-essential tracking |
| Minimum aggregate group size | Risk-accepted (G1 §4 item 14) — before publishing aggregates |
| Legal hold, deletion, backup controls | **Open engineering work** (G1 §4 item 19) — before G4 |
| Analytics and backup retention periods | Open |
| Whether voice notes raise additional obligations | Open — counsel; voice is biometric-adjacent |

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
