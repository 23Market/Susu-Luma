# G2 — Role and permission matrix

**Status: DRAFT for G2 approval. Not approved.**

The canonical authorisation model for Susu Luma: who exists, what each may do, and how it is enforced. G2 requires this artifact; this is it.

Provenance is marked throughout: **[recorded]** = decided on #7 or in the G1 approval record · **[proposed]** = drafted here and needing G2 approval · **[existing]** = already implemented in code.

---

## 1. The governing rule

**UI visibility is not authorisation.** [recorded]

The server authorises every request against the caller's role and scope, independently of what any interface shows. A client hiding a control is a convenience, never a control. Three consequences bind every item below:

1. **Deny by default.** A capability not granted is denied. No implicit inheritance between roles.
2. **Never trust client-supplied claims.** Role, organisation membership and verification status are read server-side from authoritative tables — never from client-supplied JWT metadata or mutable profile fields. [recorded]
3. **Privileged state transitions run server-side**, in RPC or Edge Functions with database constraints, not as client-issued table writes. This covers verification decisions, RFQ routing, quote acceptance, order snapshots, payment confirmation and moderation. [recorded]

---

## 2. Actors

Two populations, authorised differently.

### 2.1 Marketplace actors — authorised by organisation membership + RLS

| Actor | Definition | Authorisation basis |
|---|---|---|
| Anonymous | Not signed in | Public listing read only, if any [proposed] |
| Buyer org member | Belongs to a buyer organisation | Org membership row + role within org |
| Buyer org owner | Created or administers the buyer org | Org membership role `owner` |
| Supplier org member | Belongs to a supplier organisation | Org membership row + role within org |
| Supplier org owner | Administers the supplier org | Org membership role `owner` |

**Cross-organisation denial is the central RLS invariant.** No actor may read or write another organisation's RFQs, quotations, orders, payment records, messages or evidence. This must be tested with separate buyer, supplier and administrator identities. [recorded]

### 2.2 Administrative roles — authorised by staff role + capability

Six roles. [recorded]

| Role | Purpose | Currently held by |
|---|---|---|
| **Super Admin** | Full administrative authority; role administration | Joseph Momoh |
| **Operations Lead** | Day-to-day marketplace operations; accountable for support targets | Joseph Momoh (acting) |
| **Trust & Safety** | Moderation, reports, abuse investigation; category-scoped | Joseph Momoh (acting) |
| **Support** | Buyer and supplier assistance; case handling; permitted PII access | Joseph Momoh (acting) |
| **Finance** | Payment status and reconciliation; financial reporting | Joseph Momoh (acting) |
| **Analyst** | Read-only aggregate reporting | Joseph Momoh (acting) |

> All six are currently one person. The independence gap is recorded as an accepted risk in the G1 approval record §5, and does not carry past G4.

---

## 3. Capability matrix

Thirteen capabilities across six roles. [recorded]

| Capability | Super Admin | Operations Lead | Trust & Safety | Support | Finance | Analyst |
|---|---|---|---|---|---|---|
| Overview | Full | Full | Limited | Limited | Financial view | Read |
| RFQ inspection | Yes | Yes | Investigations | Related cases | No by default | Aggregate |
| Quote inspection | Yes | Yes | Investigations | Related cases | Approved scope | Aggregate |
| Order inspection | Yes | Yes | Related cases | Related cases | Payment scope | Aggregate |
| Payment reconciliation | Governed | No by default | No | No | **Yes** | No |
| Verification decisions | Governed | Yes | Approved scope | No | No | Aggregate |
| Case assignment | Yes | Yes | Yes | Yes | Related cases | No |
| Case resolution | Governed | Yes | Yes | Yes | Related cases | No |
| Review moderation | Yes | Yes | Yes | No | No | Aggregate |
| Analytics | Full | Operations | Trust | Support | Financial | Read |
| Privacy requests | Governed | No by default | Approved scope | No | No | No |
| Audit export | Governed | Limited | Limited | No | Limited | No |
| Role administration | **Yes** | No | No | No | No | No |

**Qualifier meanings** [proposed]

| Term | Meaning |
|---|---|
| **Full** | Unrestricted within the capability |
| **Yes** | Granted |
| **Governed** | Granted, but requires a second actor or a recorded justification; not exercisable alone |
| **Limited** | A defined subset only, named per module |
| **Related cases** | Only records linked to a case assigned to that actor |
| **Investigations** | Only records flagged for investigation, with a recorded reason |
| **Approved scope** | Only within an explicitly assigned scope |
| **Aggregate** | Counts and distributions only; no record-level personal data |
| **Payment / Financial scope** | Only payment and commercial fields; no verification evidence or message content |
| **No by default** | Denied unless separately granted and recorded |
| **No** | Denied |

---

## 4. Separation of duties

Non-negotiable constraints the server must enforce. [recorded]

| Constraint | Rule |
|---|---|
| **No self-approval** | No actor may approve a verification case, appeal or exception they submitted or that concerns their own organisation |
| **Second reviewer** | High-risk approvals, policy exceptions and rejected-to-approved reversals require an independent second reviewer |
| **Early-review flag** | An actor may not lower a review-requirement flag and then approve the same case. *(This defect was found in review and fixed; the matrix records it as a standing rule.)* |
| **Payment confirmation** | Only Finance may record external payment confirmation. Cash in person additionally needs both parties' acknowledgment plus Finance review |
| **Role administration** | Super Admin only. An actor may not grant themselves a capability |
| **Audit immutability** | No role may update, delete or truncate `audit_events` or `verification_decisions` |

> With one person holding all roles, several of these cannot currently be satisfied by distinct humans. They must still be **enforced in code** so they bind the moment a second person exists. Until then, the constraint is recorded as unmet in the G1 risk register, not disabled.

---

## 5. Scope

**Category scope** [recorded] — Trust & Safety is limited to an assigned set of top-level categories. An action on a listing outside that set is refused `403 out_of_scope` and the refusal is audited against the listing.

**Geographic scope** [recorded] — the pilot covers the 16 in-force districts. Bandajuma and Kpanguma are inactive. Areas and localities are inactive, none verified or loaded. Enforcement is a reference table with an `active` flag; nothing outside it is selectable.

**Organisational scope** [recorded] — administrative roles are not members of any marketplace organisation and must never gain org-member access by that route.

---

## 6. Permission identifiers

The admin console gates on 75 permission strings, grouped by module. These are **[proposed]** capability names to be reconciled with the implemented catalogue before build. Canonical list: `prototype/admin-console/docs/MODULES.md`.

| Module | Permissions |
|---|---|
| Overview | `overview.view` |
| Organisations | `organisations.view`, `organisations.members.view` |
| Verification | `verification.view`, `verification.evidence.view`, `verification.assign`, `verification.decide`, `verification.suspend` |
| Listings | `listings.view`, `listings.moderate`, `listings.remove`, `listings.restore`, `listings.recategorize`, `listings.feature`, `listings.bulk` |
| Categories | `categories.view`, `categories.edit`, `categories.publish` |
| RFQ | `rfqs.view`, `rfqs.routing.view`, `rfqs.investigate`, `rfqs.notes.manage`, `rfqs.export` |
| Quotations | `quotes.view`, `quotes.compare`, `quotes.history.view`, `quotes.investigate`, `quotes.export` |
| Orders | `orders.view`, `orders.history.view`, `fulfilment.view`, `fulfilment.evidence.view`, `orders.investigate`, `orders.export` |
| Payments | `payments.view`, `payments.evidence.view`, `payments.reconcile`, `payments.export` |
| Reports | `reports.view`, `reports.resolve` |
| Support cases | `support.cases.view`, `support.cases.assign`, `support.cases.claim`, `support.cases.notes.manage`, `support.cases.respond`, `support.cases.escalate`, `support.cases.resolve`, `support.evidence.view` |
| Reviews | `reviews.view`, `reviews.moderate`, `reviews.restore`, `reviews.appeals.view` |
| Users / PII | `users.view`, `users.pii.search`, `users.pii.reveal`, `users.restrict`, `users.suspend`, `users.reinstate`, `users.verify`, `users.cases` |
| Analytics | `analytics.view`, `analytics.financial.view`, `analytics.export`, `analytics.definitions.manage` |
| Search | `search.users`, `search.organisations`, `search.listings`, `search.rfqs`, `search.orders`, `search.cases` |
| Privacy | `privacy.requests.view`, `privacy.requests.assign`, `privacy.requests.review`, `privacy.requests.decide`, `privacy.requests.complete` |
| Catalogue import | `catalogue.import`, `catalogue.import.validate`, `catalogue.import.commit`, `catalogue.import.history.view` |
| System | `system.health.view`, `system.capacity.view`, `system.incidents.view`, `system.recovery.view`, `system.operations.manage` |
| Audit | `audit.view`, `audit.export` |
| Messaging | `messaging.send`, `messaging.broadcast` |
| Revenue | `revenue.view` |

---

## 7. Personal data access

[recorded]

- Contact details are **masked by the server** in every list and detail response. The masked form is the only form a client holds.
- Revealing real contact details requires `users.pii.reveal`, a **stated purpose** from a fixed list (`ticket`, `fraud`, `legal`, `recovery`), and writes an audit entry. The next read is masked again.
- Searching by email or phone requires `users.pii.search`, runs **server-side**, returns identifiers only, and is audited **without recording the search term**.
- Verification evidence and order evidence are private, accessed only through authorised, time-limited signed URLs. Buyers never see verification documents.
- Analyst receives aggregates only, never record-level personal data.

---

## 8. Refusals are events

[recorded] Every `403` — missing capability or out-of-scope — writes an `access.denied` audit entry with the actor, the capability or record, and `warn` severity. Clients must not probe: a client requests only what its role may read.

---

## 9. Enforcement requirements for build

[proposed] — the testable obligations this matrix places on G3 and G4.

1. RLS on every exposed table, verified with separate buyer, supplier and administrator identities, including cross-organisation denial.
2. Capability checks server-side on every request, independent of client state.
3. Privileged transitions only via RPC or Edge Functions with database constraints.
4. Separation-of-duties constraints (§4) enforced in the database, not only in application code.
5. Scope checks (§5) applied before any mutation, with refusals audited.
6. Masking applied in the response layer, so an unmasked value cannot leak through any read path.
7. Append-only enforcement on `audit_events` and `verification_decisions`.
8. Permission revocation takes effect on the next server request; a client must refresh its access state.

---

## 10. Open items

| Item | Status |
|---|---|
| Reconcile the 75 proposed permission names with the implemented catalogue | Open — before G3 |
| Definition of "high risk" for the second-reviewer rule | Risk-accepted (G1 §4 item 2) |
| Whether buyers may pick suppliers directly | Resolved: **no** for the pilot |
| "Limited" and "Approved scope" subsets per module | **Open — needs definition before G3** |
| Independent reviewer for the separation-of-duties implementation | Required before G4 |

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
