# Customer modules — 19 November 2026

## Implemented
- discover_listings: public published/active catalogue search, category/district/availability filters, UUID keyset cursor, maximum 100 rows. UUID order is deterministic, not a recency ranking. New availability values are not invented; filters use existing listing values.
- saved_products and set_saved_product: per-user RLS reads, idempotent set/unset; live app restores saves, waits for server success, propagates errors, and clears saves on logout.
- send_message: existing participant RPC retained; validates active parties and body, serializes send/block decisions and limits technical bursts to 30 messages per sender per minute. Notifications omit message body. Server acceptance is not a delivery/read receipt.
- set_thread_block: either participating organisation may prevent further sending; each may remove only its own block.
- Support: organization-scoped submission (including thread abuse reports), public replies, private internal notes, MFA/permission-controlled assignment/escalation/resolution, and atomic audit writes. No SLA or escalation destination is presumed.

## Verification
Synthetic PostgreSQL persona tests run through the existing CI harness. This is not a hosted Supabase Auth/PostgREST end-to-end pass. PR checks are the current evidence source.

## Remaining UI and live verification
The discovery RPC and support/block client boundary are available in lib/backend/customer_modules.dart, but discovery pagination/filter controls, support-case screens, and conversation block/report controls still need UI wiring. Live saved-product persistence is wired to the existing save controls. No live notification delivery, read receipts or automatic retry of sends is claimed. No public-demo update, merge or hosted migration is included.

To test against a hosted environment, use synthetic accounts in a separate development project; apply reviewed migrations, verify cross-account denial through Auth/PostgREST, and test network interruptions before release. Existing demo data remains in-memory.
