# Decision record: admin console technology and pilot geography (18 Nov 2026)

Status: **Product Owner decision recorded. Not a gate sign-off.** G0, G1 and G2 stay as written in `docs/waterfall-gate-register.md`. Nothing here is merged or deployed.

Source: Product Owner (Joseph Momoh) replies in the working session, Wed 18 Nov 2026, 00:29 Europe/Berlin. Mirrored to issue #7: https://github.com/23Market/Susu-Luma/issues/7#issuecomment-6964124275

## Decision 1: the admin console is a separate web console

> "it should be a separate web console"

- **Decided:** the admin console is a **separate responsive web console**, not a screen set inside the Flutter marketplace app. This matches the README wording and the direction of the static prototype in PR #75.
- **Does not match this decision (owners must revise; nothing was changed here):**
  - Issue #72 and its Flutter widget-test acceptance criteria.
  - PR #6's `lib/admin` Flutter admin shell.
- **Unaffected:** the Supabase foundation in this PR. Staff authorization lives in the database (`platform_roles`, MFA/aal2, audited RPCs), so it works for any client. The web console must use the same RPCs and must never hold a service-role key.
- **Still undecided (engineering to propose, owner to approve):** web framework and hosting, and how the console enrols staff in MFA. No choice is made here.
- **Security note for the console (carried from G2 requirements):** staff sign-in requires MFA; no service-role key in browser code or in the repository; evidence is opened only through the authorized, audited path.

## Decision 2: pilot geography is all 18 districts and their areas

> "I choose 18 districts and it's areas"

- **Decided:** the pilot and the listing location fields use **18 districts and their areas**. This **replaces** the E7 directive's "Western Area Urban and Western Area Rural only".
- **The 18:** the 16 districts in force plus **Bandajuma** and **Kpanguma**. Source and status per district are in the Project document `susu-luma-location-reference-2026-11-17`.
  - Bandajuma and Kpanguma are **proposed, not in force**, with no published boundaries.
- **Still open:**
  1. **The areas list.** No official source file has been supplied or verified. Two official layers exist (chiefdoms and electoral wards); the owner has not picked one. No areas data is in the repository.
  2. **Handling of the two proposed districts** in pilot operations and in the selectable list.
  3. **Security and Legal review.** The directive requires it for material scope changes. A pilot footprint wider than the directive's two Western Area districts is such a change. **No reviewer is assigned.**
- **Pilot limits unchanged by this decision:** max 150 invited buyers, max 50 verified suppliers, record-only payments, mandatory audit logging, support escalation and emergency pause. Widening the footprint does not raise these caps.

## Update, 18 Nov 2026 (~01:40 Europe/Berlin): the pilot-scope conflict was resolved by the Product Owner

A later directive said "Initial pilot restricted to Western Area Urban and Western Area Rural", which conflicted with Decision 2 above. The Product Owner was asked which applies and chose:

> **First pilot = all 16 in-force districts.**

- **Supersedes both** "Western Area only" (the directive) and "all 18" (Decision 2) **for the first pilot.**
- **Bandajuma and Kpanguma stay proposed and inactive.** They are not in force and have no published boundaries.
- **Data model:** keep all districts in the reference data; only the 16 in-force districts may be selectable in the pilot. The five regions and sixteen districts register stands.
- **Gate:** operating outside the Western Area still needs the Security and Legal review the directive requires for material scope changes. **No reviewer is assigned**, so no district outside the Western Area should go live until one has reviewed. Unverified localities (areas) stay inactive until an authoritative source is confirmed.
- **Caps unchanged:** max 150 invited buyers, max 50 verified suppliers, record-only payments, mandatory audit logging.
- Not a gate sign-off. The areas source file and layer (wards or chiefdoms) are still open.

Decision 1 update: the web console framework is **recommended** (not approved) as React + TypeScript + Vite in draft PR #77; hosting and MFA enrolment remain undecided.

## What the code does and does not do today

- `organizations.district` and `listings.district` remain **free text**. There is no districts reference table and no areas data. See `docs/SECURE_FOUNDATION.md`, "Known limitations".
- Nothing in the code restricts the pilot to any geography.

## Next steps

1. Owner supplies the official areas source file and picks the layer (wards or chiefdoms), or approves a time-boxed search. Until then areas stay unimplemented.
2. Owner assigns Security and Legal reviewers for the wider footprint.
3. Owners of issue #72 and PR #6 revise the admin console scope to a web console.
4. Engineering proposes web console framework, hosting and MFA enrolment for owner approval.
