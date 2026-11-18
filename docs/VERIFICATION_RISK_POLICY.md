# Verification risk classification and reviewer authorization policy (B7)

Status: **IMPLEMENTED AND LOCALLY TESTED. NOT ACCEPTED.** This policy is an engineering baseline written to the Product Owner's B7 requirements. It is **not fully accepted until the Security Lead reviews it** (no Security Lead is assigned in any repository document). Nothing here is applied to any shared or production database.

Code: `supabase/migrations/20261118000100_verification_risk_policy.sql` (on top of `20261117000100_secure_foundation.sql`, draft PR #76).
Tests: `supabase/tests/database/verification_risk_policy_test.sql` (62 assertions) plus the workflow, grants and platform-role suites.

## 1. Baseline requirement to control to test

| # | Requirement (B7) | Control | Evidence |
|---|---|---|---|
| 1 | Privileged staff access requires MFA | `private.has_platform_role()` needs an `aal2` JWT and an unrevoked role. Client `app_metadata` / `user_metadata` are never read. `my_platform_access()` returns capabilities only for `aal2`. | `E:` and `F:` assertions (no MFA, revoked role, no role, forged metadata) |
| 2 | Reviewer-declared high risk needs a documented reason | Declaring `high` requires `p_risk_reason` of at least 10 characters. Stored on the case and on the decision record. | `B:` assertions (missing reason, token reason, stored reason) |
| 3 | Rejected-to-approved needs independent second review | Any earlier `reject` decision for the organisation makes the second review mandatory. A rejected case cannot be re-opened or flipped. | `D:` assertions |
| 4 | Policy exceptions need independent second review | `p_policy_exception => true` needs a documented reason (at least 10 characters) and makes the second review mandatory. | `C:` assertions |
| 5 | Early-review risk flags trigger independent second review | The flag sets `risk_level = high`, `second_review_required = true`, expiry to now, and needs a documented reason. | `A:` assertions |
| 6 | No self-approval | The submitter and any member of the supplier organisation can never review, flag or open evidence. The first approver cannot give the second approval. | `A:`, `D:`, `E:` assertions and the existing workflow suite |
| 7 | Decisions record actor, time, reason, evidence reference, history | `verification_decisions` (append-only) stores `decided_by`, `decided_at`, `reason`, `policy_exception`, `is_second_review`, `risk_level`, `risk_reason` and a snapshot `evidence_reference` of the files the reviewer was shown. Audit events carry the same facts. | `A:` assertions (evidence reference and risk level on every decision), existing immutability tests |
| 8 | Reviewers cannot silently remove risk flags or bypass second approval | `risk_level` can be raised, never lowered. `second_review_required` is sticky. Both are enforced by a trigger that also binds the table owner (`private.protect_risk_controls`). The review RPC refuses a lowering attempt with 42501. | `A:` assertions, including the regression below |
| 9 | Test unauthorized transitions and role escalation | Closed cases cannot be re-decided; finance, admin, no-role, no-MFA and revoked-role users cannot review or flag; reviewers cannot grant roles or escalate themselves; clients cannot write cases or decisions directly. | `E:` assertions |

### Defect found and fixed by this review (reported honestly)
In commit `cc84f70` (PR #76 before this change), `review_supplier_verification` let a single reviewer pass `p_risk_level => 'standard'` on a case that an early-review flag had set to `high`, and then approve it alone. The second-review requirement was derived from the mutable risk level, so it could be silently removed. This broke the intent of baseline items 5 and 8 even though CI was green and the earlier 173 local tests passed, because none of them tried to lower the risk. It was reproduced against `cc84f70` before the fix (`approved` returned for one reviewer) and is now covered by a regression assertion and by mutation checks.

## 2. How risk is classified

| Trigger | Risk level | Second review | Who sets it | Reason required |
|---|---|---|---|---|
| Default | `standard` | No (unless a rule below applies) | system | no |
| Reviewer declares high risk | `high` | **Yes, sticky** | verification reviewer | **Yes**, at least 10 characters |
| Early-review flag on an approved case | `high` | **Yes, sticky** | verification reviewer | **Yes**, at least 10 characters |
| Policy exception | unchanged | **Yes, sticky** | verification reviewer | **Yes**, at least 10 characters |
| Earlier rejection for the organisation | unchanged | **Yes** | system | no |

The 10-character minimum is an engineering default to stop empty or token reasons. It is not a quality control. **"High risk" has no Product Owner or Security Lead definition yet**; the criteria a reviewer should apply are an open decision.

**Lowering a risk level is deliberately unsupported.** If the business needs a downgrade path, it must be designed as a separate, audited, second-reviewed action.

## 3. Evidence limits: review of the provisional 10 MiB PDF/JPEG/PNG control

Status: **provisional implementation control, NOT approved.**

| Aspect | What is implemented | What is NOT validated |
|---|---|---|
| Size | Bucket `file_size_limit` 10 MiB. Max 20 files per case (RPC). | Whether 10 MiB suits low-bandwidth pilot users or large scanned PDFs. Owner decision. |
| Type | Bucket `allowed_mime_types`: PDF, JPEG, PNG. | **File content.** As far as I know, Supabase Storage checks the declared content type, not the file's actual bytes. A mislabelled file would be accepted. **To be verified in the isolated Supabase environment (B2); not verified here.** |
| Access permissions | Private bucket. Organisation owners/admins can insert and read only their own folder. No update or delete. Reviewers never read the bucket directly; `authorize_evidence_access()` checks the case, the file and the conflict rule, and writes an audit event. | The Edge Function that issues a short-lived signed URL is **NOT STARTED**. |
| Malware handling | **None.** No scanning, no quarantine state. | Everything. A reviewer who opens an uploaded PDF or image is exposed to a malicious file. |

Recommended before approval (not implemented, for Security Lead decision):
1. Make a case reviewable only after server-side checks pass: magic-byte type check, size and page-count limits, filename normalisation.
2. Scan every upload with antivirus before any reviewer can open it, with a `quarantined` outcome that blocks the case.
3. Serve evidence only through the signed-URL function with `Content-Disposition: attachment` and `X-Content-Type-Options: nosniff`, and open it only in a sandboxed viewer.
4. Decide retention for evidence (the Product Owner's provisional D10 says 12 months after closure; no purge mechanism exists yet).

## 4. Known limits of this policy
- A holder of the Supabase service role or database owner can still change data directly. The trigger blocks lowering risk, and the append-only tables block editing history, but a privileged operator remains outside the application trust boundary. Service-role access must be restricted and audited at the platform level (not implemented here).
- `request_more_information` moves a case to `in_review`, but **no RPC lets the supplier add evidence to an existing case yet**. A new submission is only possible after the case closes.
- Reviewer list RPCs return full case rows (including evidence paths) by design.
- `my_platform_access()` advertises only capabilities that exist today: `verification.review`, `audit.view`, `roles.manage`. Finance, support and analyst roles have none yet.
- The web console role vocabulary in PR #75's prototype (Super Admin, Operations Lead, Trust & Safety, Support, Finance, Analyst) does not match these five database roles. Reconciling them is a G2 role-and-permission-matrix decision; no roles were added here.
