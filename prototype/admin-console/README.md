> ## Status: prototype — not production, not the Flutter app
>
> This is a **clickable prototype** of the operations/admin web console, held to the
> gate register's rule that *"build work is a prototype and draft foundation only"*.
> It exists to give **G2 (UX, architecture and security design)** a concrete
> admin-console design to review, and to give **#72** a reference to build against.
>
> - **Not** the Flutter mobile client in `lib/`. The project README plans admin
>   tooling as a separate responsive web console; this is that console's first draft.
> - **No backend.** Every figure is generated in the browser. There is no API URL,
>   no credential and no endpoint reaching a real system anywhere in this folder.
> - **Not acceptance evidence.** A rendering interface is not a passed gate.
> - May move to its own repository once the separate-web-console plan is confirmed.
>
> Open `index.html` in a browser. Nothing to install.

---

# Susu Luma admin console (prototype)

## Why this exists

Susu Luma is a B2B marketplace. Its operational chain is:

**Supplier verification → Listing publication → Buyer RFQ → Supplier quotation → Quote acceptance → Order confirmation → Fulfilment → Payment-status reconciliation → Support and dispute resolution**

This console is the administrative surface for that chain. It is kept separate from the marketplace application and from the existing Laravel system, and it is deliberately buildable before the Admin API exists: each unbuilt module carries the column shape, permissions and proposed endpoint it is waiting on, so a backend has something concrete to be built against.

## What is in it

**24 modules in four groups.** Full inventory, statuses, endpoints and permissions: [`docs/MODULES.md`](docs/MODULES.md).

| Group | Modules |
|---|---|
| Management | Executive Overview · Buyers & Organisations · Sellers & Suppliers · Verification & Compliance |
| Marketplace Operations | Listings · Categories & Attributes · RFQ · Quotations · Orders & Fulfilment · Delivery & Logistics · Payment Reconciliation |
| Trust, Safety & Service | Reports & Moderation · Support & Cases · Reviews & Reputation · Inquiry & Chat Hub · Ads & Promotions |
| Intelligence & Governance | Analytics & Reports · Global Search · Locations · Data & Privacy Requests · Bulk Catalogue Import · Security & Audit Logs · System Health · Settings & Permissions |

### Working today (Demo)

- **Executive Overview** — KPIs, 14-day registrations chart, category mix, work queues, service health, audit trail, critical alerts.
- **Listings Management** — search and filters, lifecycle transitions, **bulk moderation**, quality signals (duplicate / misleading price / suspicious), promotion, recategorisation.
- **Sellers & Suppliers** — accounts, verification state, abuse signals, listing history. Contact details are **masked by default** with purpose-based reveal, and the reveal is audited.
- **Reports & Moderation** — report inbox, action or dismiss with audit.
- **Inquiry & Chat Hub** — 1:1 seller threads, automatic notices fired by moderation actions, and **segmented broadcast** with an audience builder, per-channel reach, cost estimate, consent handling and a second-admin approval gate.
- **Settings & Permissions** — the live 13 × 6 role and capability matrix.

### Awaiting the Admin API

RFQ, Quotations, Orders & Fulfilment, Payment Reconciliation, Support & Cases, Verification & Compliance, Analytics, Reviews, Privacy Requests, Bulk Import, Organisations, Delivery. Each screen shows its approved KPI set, its column shape, its gate permission and its proposed endpoints.

## Roles

Six approved roles, enforced in the interface and intended to be enforced again on the server:

`Super Admin` · `Operations Lead` · `Trust & Safety` · `Support` · `Finance` · `Analyst`

Use the **Viewing as** selector in the sidebar. A module outside your role shows a permission-denied state naming the missing capability, and Trust & Safety is additionally scoped to a subset of categories.

**UI visibility is not authorisation.** The server must validate every request and every resource-level permission. The console hides what a role may not do as a convenience only, and treats every refusal from a server as final.

## Implementation status terminology

| Status | Meaning |
|---|---|
| **Demo** | Works here on generated sample data. |
| **Partial** | Some functionality exists, but the complete workflow is not implemented. |
| **API pending** | Requires a backend endpoint or data contract. |
| **Proposed** | Specified in the gap analysis, not yet built. |

A screen must not be marked *Integrated* or *Production approved* merely because its interface renders. Demo data and a successful build are not production acceptance evidence.

## Operating rules the console assumes

These come from the gap analysis and are reflected in the screens:

- **Payment and fulfilment are independent.** A delivered order is not automatically paid; a confirmed payment does not prove delivery. A user assertion alone can never mark a payment confirmed — it needs authoritative provider evidence or an authorised reconciliation.
- **Accepted quotations are snapshotted.** Order terms match the accepted quote version; ordinary administrators cannot rewrite agreed commercial terms.
- **Currency and units are explicit.** Nothing is silently converted. Any conversion must be explicit, sourced, timestamped and shown separately from the original offer.
- **Partial delivery preserves delivered and outstanding quantities.**
- **Every change and every refusal is audited** with actor, time, reason and request reference. Retryable writes carry an idempotency key.
- **Reasons are required** for privileged decisions, and destructive actions require confirmation.
- **Personal data is masked by default**, revealed only with a stated purpose, and that reveal is logged.
- **Susu Luma does not hold funds**, operate escrow or settle. The payments module records and investigates status only.

## Running it

```sh
# nothing to install
open index.html          # macOS
xdg-open index.html      # Linux
```

Or serve it:

```sh
python3 -m http.server 8000
```

Light and dark themes follow the system setting and can be toggled in the header. The layout works down to phone width.

## Roadmap

Phase 1 (P0) is the operational transaction chain, in this order:

1. RFQ Management
2. Quotation Management (including side-by-side comparison)
3. Orders & Fulfilment
4. Payment Status & Reconciliation
5. Support & Case Management
6. Supplier Verification completion
7. Real operational Overview and Analytics

Phase 2 (P1): Organisations & membership, Global Search, Reviews, Data & Privacy Requests, Bulk Catalogue Import, governed Locations.

Phase 3: capacity and resilience, incident and recovery operations, advanced reporting, audit integrity, staff access lifecycle.

## Backend integration is contract-gated

A real Admin API may be connected only after its contract, RBAC, audit requirements and release gate are approved. Before then, no environment URL belongs in this repository.
