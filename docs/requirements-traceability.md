# Susu Luma MVP requirements traceability

**Source:** `Susu_Luma_PRD_User_Stories.docx`, v1.0, draft for stakeholder review, 17 October 2026.  
**Status:** Working traceability aid; not a signed requirements baseline.  
**Gate:** G1 requirements baseline approval is outstanding. IDs below are grouped by capability and do not replace the canonical user-story IDs in the PRD.

## Scope and evidence

| Capability | PRD requirement / workflow | Current repository evidence | Gap before acceptance |
|---|---|---|---|
| Account and organisation membership | Business accounts, individual account owner and organisation membership | Draft schema has organisations and memberships | Authentication, secure onboarding, owner membership transaction, invitation/join flows and role tests |
| Supplier verification | Private evidence, review decision, scope and expiry/review date; verification is not a quality guarantee | Admin verification queue and audited server-side decisions; draft evidence model | Private storage, upload limits, expiry workflow, evidence access audit and copy explaining verification scope |
| Catalogue and moderation | Structured listing fields, status, availability, units, location, price/quote-only and moderation | Prototype has illustrative hard-coded products; draft listings table | Data-driven forms, full category/attribute model, moderation states, pagination, filters, report/disable workflow |
| Search | Keyword/category and practical filters; pagination, empty and retry states | Local in-memory text/category filter | Server-side search and filters, pagination, loading/error/retry states, availability and verification filters |
| RFQ | One or more products, quantity/unit, delivery location/date, notes and attachments | Local RFQ draft only; draft RFQ tables | Persistent multi-item RFQs, validation, attachment policy, routing, supplier recipient rules and status transitions |
| Quotations | Structured price/currency/unit, MOQ, lead time, delivery terms, validity, revision and comparison | No working quote workflow | Supplier quote create/revise/expire, currency/unit mismatch warnings, compare UX and authorization tests |
| Quote acceptance / order intent | Acceptance creates order record and immutable snapshot; not evidence of payment | Draft quote/order tables | Server-authoritative atomic acceptance, immutable snapshot, concurrency/idempotency tests and order participant access tests |
| Messaging | Buyer–supplier inquiry messaging with reporting and abuse controls | Local placeholder only | Authenticated persistent threads, participant-only access, rate limits, report/block and retention policy |
| Fulfilment | Confirmation, preparation, dispatch/collection, partial delivery, proof of delivery and issue handling | Draft delivery events; no UI flow | Allowed transition model, evidence access policy, actor/timestamp trail, complaint workflow and partial delivery tests |
| Favourites | Shortlist/favourites | Local saved set | Persist per user, empty/loading/error states and cross-account isolation |
| Notifications | Notifications for key events | Placeholder notification button | Approved delivery provider, event catalogue, preferences, retry/failure handling and no sensitive content in lock-screen payloads |
| Reviews/support | Eligible post-completion reviews, help and complaints | Admin support queue and audited resolution API | User-facing case creation, eligibility, moderation, triage SLA, evidence and abuse prevention |
| Operations console | Responsive web admin for verification, listings, categories, cases, audit and reporting | Responsive live dashboard; server-authorized supplier, listing and support actions; revenue reporting | Category management, audit-log viewer, pagination/export and staging UAT |
| Low-bandwidth experience | Lightweight pages, compressed images, saved/resumable drafts, clear retry status | Static local prototype | Compression/size limits, draft persistence, network failure testing and accessibility/usability tests |
| Price, unit and currency clarity | Explicit currency and unit; no silent conversions; price exclusions visible | Sample listings show quote-only labels and indicative unit | Typed currency/unit fields, explicit exclusions and quote-comparison mismatch tests |
| Security and privacy | RLS, private evidence, actor traceability, cross-organisation isolation | Draft SQL RLS and security guidance | Execute migration only after review; test policies with buyer/supplier/admin personas; secret scan, threat model and penetration test |
| Payments boundary | No platform custody/settlement; payment stays pending/unverified absent authoritative confirmation | Draft enum defaults to `pending_unverified`; README boundary | Ensure no paid badge or success state from client claims; legal/finance approval for any future provider integration |

## Required acceptance evidence

Before G4 system integration exit, link test cases and results for:
- Cross-organisation access denial for listing, RFQ, message, verification evidence and order.
- Search pagination, filters, empty state, network error and retry.
- RFQ creation with multiple items and validation of quantities/units.
- Quote revisions, expiry, unit/currency differences and immutable accepted quote snapshot.
- Payment reported without authoritative confirmation remains pending/unverified.
- Dispatch, partial delivery, issue opening and admin case review retain actor/timestamp evidence.
- Suspended listings disappear from discovery while authorised historical records remain available.
- Restore a backup in non-production and measure approved RPO/RTO.

## Change control

After G1 baseline approval, any scope or acceptance-criteria change requires a documented change request with rationale, requirements affected, security/privacy/regulatory impact, cost/schedule/test impact, decision-maker, and CCB approval before implementation. The PRD remains a draft until its approval record is signed.
