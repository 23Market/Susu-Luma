# G2 — User journeys

**Status: DRAFT for G2 approval. Not approved.**

G2 requires approved journeys; these are them. Each journey states its actor, the rules it must enforce, and how it fails — because in this market the failure paths matter as much as the happy ones.

Provenance: **[recorded]** = decided on #7 or in the G1 approval record · **[proposed]** = drafted here for G2 approval.

**Design direction** [recorded]: simple and WhatsApp-like. Few screens, little text, conversation-first. English is the official language; local languages are supported through voice notes, not translated screens. Pilot: 16 in-force districts, 150 invited buyers, 50 verified suppliers.

---

## The spine

The transaction chain every P0 journey sits on:

**Supplier verification → Listing publication → Buyer RFQ → Supplier quotation → Quote acceptance → Order confirmation → Fulfilment → Payment-status reconciliation → Support and dispute resolution**

---

## J1 — Supplier onboarding and verification

**Actor:** supplier org owner · **Admin counterpart:** ADM-06

1. Registers, creates a supplier organisation, selects its district from the 16 active ones.
2. Submits verification evidence (business documents, identity).
3. Case enters `pending`, then `in_review` when a reviewer picks it up.
4. Reviewer approves, rejects, or requests more information — recording reviewer, reason, what was checked, and an expiry.
5. On approval the org is verified and may publish listings and receive RFQs.

**Enforced** [recorded]: evidence is private and buyers never see it · **no self-approval** · an independent second reviewer for high-risk approvals, policy exceptions and rejected-to-approved reversals · an actor may not lower a review-requirement flag then approve alone · decision history is immutable · re-verification every 12 months or earlier on risk · public wording states only what was checked and never implies government endorsement, solvency, certification or quality.

**Failure paths:** rejection returns a reason and allows resubmission · "more information" keeps the case open without losing prior evidence · expiry returns the org to unverified and stops new RFQ routing · upload interrupted on poor connectivity resumes without duplicating evidence.

> ⚠️ **Blocked:** no real evidence may be accepted until upload hardening exists — content validation, malware scanning, signed-URL delivery. [recorded]

---

## J2 — Supplier publishes a listing

**Actor:** verified supplier · **Admin counterpart:** ADM-13

1. Creates a listing with product, specification, **explicit quantity unit**, MOQ, and quote-only or indicative pricing.
2. Selects category and district.
3. Submits; listing enters moderation if the category pre-moderates.
4. Admin approves, rejects with a reason, or recategorises.
5. Published listing is discoverable.

**Enforced** [recorded]: every quantity carries an explicit unit and every price an explicit currency · **no silent conversion** · regulated and age-restricted categories are **unavailable** (deny-by-default) · category edits must not silently break existing listings · unverified suppliers cannot publish.

**Failure paths:** missing mandatory field blocks submission with the field named · rejection gives a reason and allows editing and resubmission · a draft survives a dropped connection.

---

## J3 — Buyer raises an RFQ

**Actor:** buyer org member · **Admin counterpart:** ADM-01

1. Creates an RFQ with one or more line items: product, **quantity + unit**, specification.
2. Sets destination district and target delivery date.
3. Adds notes and attachments.
4. Submits; the platform routes it to **at most 5 verified suppliers**, storing a reason for each (category match, district match, or admin assignment).
5. Buyer sees response counts as quotations arrive.

**Enforced** [recorded]: verified suppliers only · maximum 5 recipients · only routed suppliers can read the RFQ · every recipient has a stored routing reason · **buyers may not pick suppliers directly** in the pilot · administrative intervention must not silently change the buyer's commercial request.

**Failure paths:** **a retry on poor connectivity must create exactly one RFQ** (idempotency) · no eligible supplier in the category or district → RFQ is recorded as unrouted and surfaced to operations, not silently dropped · no response by the target date → RFQ becomes overdue and appears in the admin queue · a failed notification is distinguishable from a supplier declining to quote.

---

## J4 — Supplier quotes

**Actor:** routed supplier · **Admin counterpart:** ADM-02

1. Opens the RFQ (only if routed).
2. Quotes per line: unit price, **currency**, quantity, **unit**, MOQ, taxes and fees where known, delivery or collection terms, lead time, exclusions, notes.
3. Sets validity between **24 hours and 30 days**.
4. Submits. A later change creates a **new version**; the submitted version is frozen.
5. May withdraw a quote before acceptance.

**Enforced** [recorded]: validity bounds · submitted versions never change · every revision is retrievable · withdrawn quotes stay visible in history · expired quotes cannot be accepted.

**Failure paths:** declining to quote is recorded as a decline, not silence · expiry moves the quote to `expired` and it cannot be revived.

---

## J5 — Buyer compares and accepts

**Actor:** buyer org member · **Admin counterpart:** ADM-02 comparison

1. Views quotations side by side.
2. Comparison preserves currency, unit, quantity, MOQ, delivery terms, lead time, validity, taxes and fees, exclusions.
3. Accepts one submitted, unexpired quote.
4. The server creates the order **atomically** with an **immutable snapshot** of that quote version. Order state: `awaiting_seller_confirmation`.

**Enforced** [recorded]: **no silent currency or unit conversion** — any conversion must be explicit, sourced, timestamped and shown separately from the original offer · comparison must not imply a misleading lowest-price ranking when currencies or units differ · **acceptance is order intent, not payment** · order terms thereafter match the snapshot, and ordinary administrators cannot rewrite agreed commercial terms.

**Failure paths:** accepting an expired or withdrawn quote is refused with the reason · a retry cannot create two orders.

---

## J6 — Supplier confirms, then fulfils

**Actor:** supplier · **Admin counterpart:** ADM-03

1. Confirms within **48 hours**.
2. Records fulfilment milestones: ready for dispatch → dispatched → in transit, or ready for collection → collected; then delivered or **partially delivered**.
3. Attaches delivery evidence (private).
4. Buyer confirms receipt. A `proof_of_delivery` event records evidence, actor and timestamp.

**Enforced** [recorded]: **the buyer confirms delivery**, with supplier proof as supporting evidence · **partial delivery preserves delivered and outstanding quantities** · each milestone records event type, timestamp, actor, organisation, quantity affected, unit, mode, evidence reference and any exception flag · duplicate event delivery must not duplicate a milestone · evidence is access-controlled.

**Failure paths:** no confirmation within 48 hours → the order is surfaced as unconfirmed · a delivery exception is a distinct state requiring a reason · a late delivery flags in the admin queue.

---

## J7 — Payment is recorded (never transacted)

**Actor:** buyer and supplier, out of app · **Finance confirms** · **Admin counterpart:** ADM-04

1. Parties agree a method outside the app and pay outside the app.
2. Either party records the method and a reference. State stays **`pending_unverified`**.
3. **Finance** reviews authoritative evidence and records `externally_confirmed`, or `under_review`.
4. Cash in person needs **both parties' acknowledgment plus Finance review**.

**Enforced** [recorded]: **no payment provider in the MVP; nothing is integrated and no funds move through the platform** · states are `pending_unverified`, `externally_confirmed`, `under_review`, `not_applicable` · **only Finance** records external confirmation · never shown as paid because a user said so · **payment state is never inferred from order or delivery state** · a delivered order is not paid and a confirmed payment does not prove delivery · recordable methods — JubaSecure, Orange Money, Afrimoney, Ezipay, GTPay, PayPal, cash in person — are **recorded only**.

**Failure paths:** contested payment → `under_review` and a support case · a reversal is a distinct state preserving the original event · repeated provider events are idempotent.

> The interface must never imply Susu Luma holds, routes or settles funds. [recorded]

---

## J8 — Dispute

**Actor:** either party · **Admin counterpart:** ADM-03 + ADM-05

1. Either party raises an issue within **72 hours after buyer-confirmed receipt**.
2. Order becomes `disputed`; a support case opens with a reference.
3. Admin reviews evidence from both sides.
4. Outcome is a **recorded decision** plus any listing or account action. Escalation beyond admin review goes to the **Owner**.

**Enforced** [recorded]: **no refunds and no fund movements** — the platform holds neither goods nor funds, so liability sits between buyer and supplier under the accepted quote terms · outcomes are recorded decisions, not settlements · critical safety and fraud categories enter the approved escalation process.

> ⚠️ The liability wording is **risk-accepted pending external counsel** (G1 §4 item 7).

---

## J9 — Inquiry messaging

**Actor:** buyer and supplier · **Admin counterpart:** Inquiry & Chat Hub

1. Buyer messages a supplier about a listing or RFQ.
2. Text, and **voice notes** for local languages. [recorded]
3. Either party reports a message.

**Enforced** [recorded]: messages are visible only to the two parties, and to staff on an assigned case · voice notes are private, Restricted-class, retained **12 months** · report route available.

**Failure paths:** send fails on poor connectivity → clear failed state and safe manual retry without duplicate sends · a long voice note must be bounded in length and size.

> ⚠️ **Gaps:** voice notes are a **scope addition** not yet in the PRD, with tickets still to be raised; the moderation approach for audio is undefined. [recorded]

---

## J10 — Review after a completed order

**Actor:** buyer · **Admin counterpart:** ADM-08

Only an **eligible completed order** can produce a review. Authors cannot rewrite or delete a published review through administrative intervention; hiding one always requires a reason; a review is never presented as proof of supplier verification. [recorded]

---

## J11 — Support case

**Actor:** any user · **Admin counterpart:** ADM-05

1. User raises a complaint and receives a **case reference**.
2. Case is categorised, prioritised P1–P4, assigned.
3. Operator adds internal notes and sends user-visible responses — **never confused with each other**.
4. Resolution is recorded; reopening follows policy.

**Enforced** [recorded]: targets are **targets, not guarantees** — P1 1-hour response/24-hour resolution, P2 4 support-hours/2 business days, P3 1/5 business days, P4 2/10 business days · support hours Monday–Saturday 08:00–18:00 UTC with continuous intake · out-of-hours P1 routes to the Owner · the status shown to a user is a safe summary, never internal investigative content · sensitive evidence is role-restricted.

> ⚠️ P1–P4 qualification criteria are **risk-accepted** (G1 §4 item 8), required before pilot support goes live.

---

## J12 — Privacy request

**Actor:** any user · **Admin counterpart:** ADM-10

Identity and authority check → scope determination → hold and retention flags → approval or rejection with a reason → completion evidence → irreversible-action confirmation. The request itself is always audited, and **no request is silently marked complete**. [recorded]

---

## Cross-cutting requirements

Apply to every journey. [recorded]

| Requirement | Rule |
|---|---|
| **Low bandwidth** | Clear saving, submitted and failed states · upload progress · safe manual retry · draft persistence · duplicate prevention · bounded payloads · large evidence not loaded until requested |
| **Retry safety** | A retried write never duplicates an RFQ, order, payment record or milestone |
| **Failure vs empty** | A failed request shows an error and retry, never a falsely empty result |
| **Explicitness** | Every price has a currency; every quantity a unit; no silent conversion anywhere |
| **Accessibility** | WCAG 2.2 AA: keyboard navigation, visible focus, accessible labels, adequate contrast, clear validation errors, touch-friendly controls, responsive layout |
| **Authorisation** | Hidden UI is never a control; the server authorises every request |
| **Audit** | Every privileged change and every refusal is recorded with actor, time, reason and request reference |
| **Location** | District granularity only; areas inactive; no precise location collected |

---

## Open items

| Item | Status |
|---|---|
| Voice-note tickets and PRD change request | Open (G1 §4 item 23) |
| Audio moderation approach | **GAP** (threat model T10) |
| P1–P4 qualification criteria | Risk-accepted — before G6 |
| Cancellation rights per order state | Risk-accepted — before ADM-03 build |
| Areas within districts | Risk-accepted; areas stay inactive |
| Liability wording | Risk-accepted — external counsel before G5 |
| UAT by real pilot representatives | **VACANT** — required at G5 |

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
