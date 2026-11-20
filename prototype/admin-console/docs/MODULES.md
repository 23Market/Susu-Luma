# Susu Luma Admin — module inventory

Generated from the module registry in `index.html`. Status terminology follows the gap analysis, section 1.1.

| Status | Meaning |
|---|---|
| Demo | Works on generated sample data in the browser. |
| Partial | Some functionality exists; the complete workflow does not. |
| API pending | Requires a backend endpoint or data contract. |
| Proposed | Specified in the gap analysis, not yet built. |

A screen is never marked **Integrated** or **Production approved** merely because its interface renders.

## Management

| Module | Spec | Priority | Status | Gate permission |
|---|---|---|---|---|
| Executive Overview `#overview` | ADM-07 | P0 | Partial | `overview.view` |
| Buyers & Organisations `#orgs` | ADM-06 | P0 | API pending | `organisations.view` |
| Sellers & Suppliers `#users` | ADM-06 | P0 | Demo | `users.view` |
| Verification & Compliance `#verification` | ADM-06 | P0 | API pending | `verification.view` |

## Marketplace Operations

| Module | Spec | Priority | Status | Gate permission |
|---|---|---|---|---|
| Listings Management `#listings` | ADM-— | P0 | Demo | `listings.view` |
| Categories & Attributes `#categories` | ADM-— | P1 | Proposed | `categories.view` |
| RFQ Management `#rfqs` | ADM-01 | P0 | API pending | `rfqs.view` |
| Quotation Management `#quotes` | ADM-02 | P0 | API pending | `quotes.view` |
| Orders & Fulfilment `#orders` | ADM-03 | P0 | API pending | `orders.view` |
| Delivery & Logistics `#delivery` | ADM-03 | P1 | API pending | `fulfilment.view` |
| Payment Reconciliation `#payments` | ADM-04 | P0 | API pending | `payments.view` |

## Trust, Safety & Service

| Module | Spec | Priority | Status | Gate permission |
|---|---|---|---|---|
| Reports & Moderation `#reports` | ADM-05 | P0 | Demo | `reports.view` |
| Support & Case Management `#cases` | ADM-05 | P0 | API pending | `support.cases.view` |
| Reviews & Reputation `#reviews` | ADM-08 | P1 | API pending | `reviews.view` |
| Inquiry & Chat Hub `#messaging` | ADM-— | P0 | Demo | `messaging.send` |
| Ads & Promotions `#ads` | ADM-— | P1 | Partial | `listings.feature` |

## Intelligence & Governance

| Module | Spec | Priority | Status | Gate permission |
|---|---|---|---|---|
| Analytics & Reports `#analytics` | ADM-07 | P0 | API pending | `analytics.view` |
| Global Search `#search` | ADM-09 | P1 | Proposed | `search.listings` |
| Locations `#locations` | ADM-— | P1 | Proposed | `organisations.view` |
| Data & Privacy Requests `#privacy` | ADM-10 | P1 | API pending | `privacy.requests.view` |
| Bulk Catalogue Import `#imports` | ADM-11 | P1 | API pending | `catalogue.import` |
| Security & Audit Logs `#audit` | ADM-— | P0 | Partial | `audit.view` |
| System Health & Resilience `#system` | ADM-12 | P1 | Partial | `system.health.view` |
| Settings & Permissions `#settings` | ADM-— | P0 | Demo | `overview.view` |

## Proposed endpoints

None of these are implemented. They are the contract each module is built against.

### Buyers & Organisations (ADM-06)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/organisations` | Organisation directory |
| GET | `/admin/v1/organisations/{id}` | Organisation detail |
| GET | `/admin/v1/organisations/{id}/members` | Membership list |

### Verification & Compliance (ADM-06)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/verifications` | Verification queue |
| GET | `/admin/v1/verifications/{id}` | Verification dossier |
| GET | `/admin/v1/verifications/{id}/evidence` | Authorised evidence access |
| POST | `/admin/v1/verifications/{id}/request-information` | Request more information |
| POST | `/admin/v1/verifications/{id}/decision` | Record decision |

### Categories & Attributes (ADM-—)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/taxonomy` | Published + draft taxonomy |
| PATCH | `/admin/v1/categories/{id}` | Edit draft category |
| POST | `/admin/v1/taxonomy/publish` | Publish draft version |

### RFQ Management (ADM-01)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/rfqs` | Paginated RFQ directory |
| GET | `/admin/v1/rfqs/{id}` | RFQ detail |
| GET | `/admin/v1/rfqs/{id}/routing` | Supplier routing history |
| GET | `/admin/v1/rfqs/{id}/quotations` | Related quotations |
| POST | `/admin/v1/rfqs/{id}/notes` | Add internal note |
| POST | `/admin/v1/rfqs/{id}/flags` | Flag for investigation |

### Quotation Management (ADM-02)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/quotations` | Quote directory |
| GET | `/admin/v1/quotations/{id}` | Quote detail |
| GET | `/admin/v1/quotations/{id}/versions` | Version history |
| GET | `/admin/v1/quotations/{id}/acceptance` | Acceptance record |
| GET | `/admin/v1/rfqs/{id}/quote-comparison` | Side-by-side comparison |

### Orders & Fulfilment (ADM-03)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/orders` | Order directory |
| GET | `/admin/v1/orders/{id}` | Order detail |
| GET | `/admin/v1/orders/{id}/timeline` | Fulfilment history |
| GET | `/admin/v1/orders/{id}/quote-snapshot` | Accepted quote snapshot |
| GET | `/admin/v1/orders/{id}/evidence` | Permitted evidence |
| GET | `/admin/v1/orders/{id}/issues` | Related delivery issues |

### Delivery & Logistics (ADM-03)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/orders/{id}/timeline` | Fulfilment milestones |
| GET | `/admin/v1/orders/{id}/evidence` | Delivery evidence references |

### Payment Reconciliation (ADM-04)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/payments` | Payment directory |
| GET | `/admin/v1/payments/{id}` | Payment detail |
| GET | `/admin/v1/payments/{id}/events` | Provider / reconciliation events |
| POST | `/admin/v1/payments/{id}/reconcile` | Authorised reconciliation decision |
| POST | `/admin/v1/payments/{id}/refer` | Refer an exception |

### Support & Case Management (ADM-05)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/support/cases` | Case queue |
| GET | `/admin/v1/support/cases/{id}` | Case detail |
| POST | `/admin/v1/support/cases/{id}/claim` | Claim case |
| POST | `/admin/v1/support/cases/{id}/assign` | Assign case |
| POST | `/admin/v1/support/cases/{id}/notes` | Internal note |
| POST | `/admin/v1/support/cases/{id}/responses` | User-visible response |
| POST | `/admin/v1/support/cases/{id}/escalate` | Escalate |
| POST | `/admin/v1/support/cases/{id}/resolve` | Resolve |

### Reviews & Reputation (ADM-08)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/reviews` | Review queue |
| GET | `/admin/v1/reviews/{id}` | Review detail |
| POST | `/admin/v1/reviews/{id}/moderation` | Record moderation decision |
| GET | `/admin/v1/reviews/{id}/history` | Moderation history |

### Ads & Promotions (ADM-—)

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/admin/v1/listings/{id}/promotion` | Apply promotion |
| POST | `/admin/v1/listings/{id}/promotion/end` | End promotion |

### Analytics & Reports (ADM-07)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/analytics/overview` | Executive KPI summary |
| GET | `/admin/v1/analytics/rfqs` | RFQ metrics |
| GET | `/admin/v1/analytics/quotes` | Quotation metrics |
| GET | `/admin/v1/analytics/orders` | Order metrics |
| GET | `/admin/v1/analytics/definitions` | Metric definitions |
| POST | `/admin/v1/analytics/exports` | Authorised export |

### Global Search (ADM-09)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/search?q={query}&types={types}` | Permission-scoped global search |

### Locations (ADM-—)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/locations` | Location directory |
| PATCH | `/admin/v1/locations/{id}` | Governed correction |

### Data & Privacy Requests (ADM-10)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/privacy/requests` | Request queue |
| GET | `/admin/v1/privacy/requests/{id}` | Request detail |
| POST | `/admin/v1/privacy/requests/{id}/assign` | Assign owner |
| POST | `/admin/v1/privacy/requests/{id}/decision` | Record decision |
| POST | `/admin/v1/privacy/requests/{id}/complete` | Record completion |

### Bulk Catalogue Import (ADM-11)

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/admin/v1/catalogue/imports` | Start import |
| POST | `/admin/v1/catalogue/imports/{id}/validate` | Validate rows |
| GET | `/admin/v1/catalogue/imports/{id}` | Import detail |
| POST | `/admin/v1/catalogue/imports/{id}/commit` | Commit drafts |
| GET | `/admin/v1/catalogue/imports/{id}/errors` | Error report |

### Security & Audit Logs (ADM-—)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/audit` | Paginated audit log |
| POST | `/admin/v1/audit/exports` | Permission-controlled export |

### System Health & Resilience (ADM-12)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/v1/system/health` | Service health |
| GET | `/admin/v1/system/metrics` | Performance metrics |
| GET | `/admin/v1/system/incidents` | Incident history |
| GET | `/admin/v1/system/backups` | Backup freshness |
| GET | `/admin/v1/system/recovery` | RPO / RTO and restore evidence |

## Permissions referenced

- `analytics.definitions.manage`
- `analytics.export`
- `analytics.financial.view`
- `analytics.view`
- `audit.export`
- `audit.view`
- `catalogue.import`
- `catalogue.import.commit`
- `catalogue.import.history.view`
- `catalogue.import.validate`
- `categories.edit`
- `categories.publish`
- `categories.view`
- `fulfilment.evidence.view`
- `fulfilment.view`
- `listings.feature`
- `listings.view`
- `messaging.send`
- `orders.export`
- `orders.history.view`
- `orders.investigate`
- `orders.view`
- `organisations.members.view`
- `organisations.view`
- `overview.view`
- `payments.evidence.view`
- `payments.export`
- `payments.reconcile`
- `payments.view`
- `privacy.requests.assign`
- `privacy.requests.complete`
- `privacy.requests.decide`
- `privacy.requests.review`
- `privacy.requests.view`
- `quotes.compare`
- `quotes.export`
- `quotes.history.view`
- `quotes.investigate`
- `quotes.view`
- `reports.view`
- `revenue.view`
- `reviews.appeals.view`
- `reviews.moderate`
- `reviews.restore`
- `reviews.view`
- `rfqs.export`
- `rfqs.investigate`
- `rfqs.notes.manage`
- `rfqs.routing.view`
- `rfqs.view`
- `search.cases`
- `search.listings`
- `search.orders`
- `search.organisations`
- `search.rfqs`
- `search.users`
- `support.cases.assign`
- `support.cases.claim`
- `support.cases.escalate`
- `support.cases.notes.manage`
- `support.cases.resolve`
- `support.cases.respond`
- `support.cases.view`
- `support.evidence.view`
- `system.capacity.view`
- `system.health.view`
- `system.incidents.view`
- `system.operations.manage`
- `system.recovery.view`
- `users.view`
- `verification.assign`
- `verification.decide`
- `verification.evidence.view`
- `verification.suspend`
- `verification.view`
