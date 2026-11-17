#!/usr/bin/env python3
"""Mutation check for the secure-foundation migration (runs on a scratch COPY only).

Each mutation breaks one security property. The suite must fail for it ("killed").
A surviving mutation means a missing or weak test.
"""
import os, re, shutil, subprocess, sys, tempfile
from pathlib import Path

# Usage: PGHOST=<local socket dir> PGPORT=<port> PGUSER=postgres python3 scripts/local-db/mutation-check.py
# Throwaway local PostgreSQL only. Works on a temporary COPY; the repository is never modified.
SRC = str(Path(__file__).resolve().parents[2])
WORK = tempfile.mkdtemp(prefix="luma-mutation-")
MIG = "supabase/migrations/20261117000100_secure_foundation.sql"
MIG2 = "supabase/migrations/20261118000100_verification_risk_policy.sql"

shutil.copytree(f"{SRC}/supabase", f"{WORK}/supabase")
shutil.copytree(f"{SRC}/scripts", f"{WORK}/scripts")
orig = open(f"{WORK}/{MIG}").read()
orig2 = open(f"{WORK}/{MIG2}").read()

M = [
 ("no-aal2-requirement", "      and r.revoked_at is null\n  ) and coalesce((select auth.jwt()) ->> 'aal', '') = 'aal2'", "      and r.revoked_at is null\n  )"),
 ("revoked-role-still-valid", "      and r.revoked_at is null\n  ) and coalesce", "  ) and coalesce"),
 ("no-self-approval-check", "if v_case.created_by = v_uid or exists (", "if false and exists (", MIG2),
 ("second-reviewer-can-be-first", "if v_case.first_reviewer_id = v_uid and p_decision = 'approve' then", "if false then", MIG2),
 ("no-second-review-after-reject", "v_requires_second := v_case.second_review_required or exists (", "v_requires_second := v_case.second_review_required or false and exists (", MIG2),
 ("validity-36-months", "expires_at = case when v_status = 'approved' then now() + interval '12 months'", "expires_at = case when v_status = 'approved' then now() + interval '36 months'", MIG2),
 ("verified-ignores-expiry", " and c.expires_at > now()\n  )\n$$;", "\n  )\n$$;"),
 ("expiry-job-open-to-clients", "grant execute on function public.expire_lapsed_verifications() to service_role;", "grant execute on function public.expire_lapsed_verifications() to service_role, authenticated;"),
 ("audit-editable", "create trigger audit_events_append_only\n  before update or delete on public.audit_events\n  for each row execute function private.forbid_mutation();", ""),
 ("audit-truncatable", "create trigger audit_events_no_truncate\n  before truncate on public.audit_events\n  for each statement execute function private.forbid_mutation();", ""),
 ("decisions-editable", "create trigger verification_decisions_append_only\n  before update or delete on public.verification_decisions\n  for each row execute function private.forbid_mutation();", ""),
 ("last-owner-unprotected", "create trigger organization_memberships_protect_last_owner\n  before update or delete on public.organization_memberships\n  for each row execute function private.protect_last_owner();", ""),
 ("ownerless-org-allowed", "create constraint trigger organizations_require_owner\n  after insert on public.organizations\n  deferrable initially deferred\n  for each row execute function private.assert_org_has_owner();", ""),
 ("idempotency-key-global", "    where o.created_by = v_uid and o.creation_key = p_creation_key;\n    if found then", "    where o.creation_key = p_creation_key;\n    if found then"),
 ("no-creation-audit", "  perform private.write_audit('organization.created', 'organization', v_org, null,\n    jsonb_build_object('organization_type', p_organization_type));\n", ""),
 ("evidence-upload-any-folder", "  for insert to authenticated with check (\n    bucket_id = 'verification-evidence'\n    and array_length(storage.foldername(name), 1) = 1\n    and private.is_org_member(private.try_uuid((storage.foldername(name))[1]), array['owner', 'admin'])\n  );", "  for insert to authenticated with check (bucket_id = 'verification-evidence');"),
 ("evidence-read-any-folder", "    bucket_id = 'verification-evidence'\n    and private.is_org_member(private.try_uuid((storage.foldername(name))[1]), array['owner', 'admin'])\n  );\n-- No update", "    bucket_id = 'verification-evidence'\n  );\n-- No update"),
 ("bucket-public", "values ('verification-evidence', 'verification-evidence', false, 10485760,", "values ('verification-evidence', 'verification-evidence', true, 10485760,"),
 ("no-table-revoke", "revoke all on all tables in schema public from anon, authenticated;\n", ""),
 ("created-by-exposed", "lead_time_days, district, locality, status, published_at, created_at, updated_at\n) on public.listings to anon, authenticated;", "lead_time_days, district, locality, status, published_at, created_at, updated_at, created_by\n) on public.listings to anon, authenticated;"),
 ("unpinned-search-path", "create function public.submit_supplier_verification(\n  p_organization_id uuid, p_evidence_paths text[]\n) returns uuid\nlanguage plpgsql security definer set search_path = '' as $$", "create function public.submit_supplier_verification(\n  p_organization_id uuid, p_evidence_paths text[]\n) returns uuid\nlanguage plpgsql security definer as $$"),
 ("admin-self-grant", "if p_user_id = v_uid then\n    raise exception 'platform roles cannot be granted to yourself'", "if false then\n    raise exception 'platform roles cannot be granted to yourself'"),
 ("cases-readable-by-any-member", "create policy verification_case_read_org on public.supplier_verification_cases\n  for select to authenticated using (private.is_org_member(organization_id, array['owner', 'admin']));", "create policy verification_case_read_org on public.supplier_verification_cases\n  for select to authenticated using (true);"),
 ("rpc-open-to-anon", "grant execute on function public.review_supplier_verification(uuid, text, text, text, boolean, text, text) to authenticated;", "grant execute on function public.review_supplier_verification(uuid, text, text, text, boolean, text, text) to authenticated, anon;", MIG2),
 ("path-traversal-allowed", "       or v_path like '%..%' or length(v_path) > 300 then", "       or length(v_path) > 300 then"),
 # --- evidence authorization conflict check (still defined in the foundation migration)
 ("evidence-access-no-conflict-check", "  if v_case.created_by = v_uid or exists (\n    select 1 from public.organization_memberships m\n    where m.organization_id = v_case.organization_id and m.user_id = v_uid\n  ) then\n    raise exception 'reviewer has a conflict of interest with this case' using errcode = '42501';\n  end if;\n  perform private.write_audit('verification.evidence_accessed'", "  perform private.write_audit('verification.evidence_accessed'"),
 # --- B7 risk policy (migration 20261118000100)
 ("risk-can-be-lowered-by-reviewer", "if p_risk_level = 'standard' and v_case.risk_level = 'high' then", "if false then", MIG2),
 ("risk-guard-trigger-missing", "create trigger supplier_verification_cases_protect_risk\n  before update on public.supplier_verification_cases\n  for each row execute function private.protect_risk_controls();", "", MIG2),
 ("second-review-flag-removable", "if old.second_review_required and not new.second_review_required then", "if false then", MIG2),
 ("high-risk-reason-not-required", "if p_risk_level = 'high' and (v_risk_reason is null or length(v_risk_reason) < 10) then", "if false then", MIG2),
 ("policy-exception-reason-not-required", "if v_exception and length(trim(p_reason)) < 10 then", "if false then", MIG2),
 ("policy-exception-no-second-review", "  if v_exception then\n    v_case.second_review_required := true;\n  end if;\n", "", MIG2),
 ("declared-high-risk-not-sticky", "    v_case.risk_reason := v_risk_reason;\n    v_case.second_review_required := true;", "    v_case.risk_reason := v_risk_reason;", MIG2),
 ("flag-does-not-require-second-review", "second_review_required = true, expires_at = now(),", "expires_at = now(),", MIG2),
 ("flag-reason-not-required", "if p_reason is null or length(trim(p_reason)) < 10 then", "if false then", MIG2),
 ("flag-conflict-check-missing", "  if v_case.created_by = v_uid or exists (\n    select 1 from public.organization_memberships m\n    where m.organization_id = v_case.organization_id and m.user_id = v_uid\n  ) then\n    raise exception 'reviewer has a conflict of interest with this case' using errcode = '42501';\n  end if;\n\n  -- Verification lapses", "  -- Verification lapses", MIG2),
 ("decision-omits-evidence-reference", "v_case.risk_level, v_case.risk_reason, v_case.evidence_object_paths);", "v_case.risk_level, v_case.risk_reason, null);", MIG2),
 ("access-contract-ignores-mfa", "if v_aal = 'aal2' then", "if true then", MIG2),
 ("access-contract-lists-revoked-roles", "where r.user_id = v_uid and r.revoked_at is null;", "where r.user_id = v_uid;", MIG2),
 ("access-contract-open-to-anon", "grant execute on function public.my_platform_access() to authenticated;", "grant execute on function public.my_platform_access() to authenticated, anon;", MIG2),
 ("risk-trigger-function-exposed", "revoke all on function private.protect_risk_controls() from public, anon, authenticated;\n", "", MIG2),
]

if any(h in os.environ.get("PGHOST", "") for h in ("supabase.co", "supabase.com", "amazonaws.com", "neon.tech")):
    sys.exit("REFUSING: PGHOST looks like a hosted database.")
env = dict(os.environ, LUMA_TEST_DB="luma_mut_test")
survivors, killed, na = [], [], []
for entry in M:
    name, old, new = entry[:3]
    target = entry[3] if len(entry) > 3 else MIG
    base = orig2 if target == MIG2 else orig
    if base.count(old) < 1:
        na.append(name); print(f"N/A      {name}: pattern not found"); continue
    open(f"{WORK}/{MIG}", "w").write(orig)
    open(f"{WORK}/{MIG2}", "w").write(orig2)
    open(f"{WORK}/{target}", "w").write(base.replace(old, new, 1))
    p = subprocess.run([f"{WORK}/scripts/local-db/run-tests.sh"], env=env, capture_output=True, text=True)
    out = p.stdout + p.stderr
    failed = re.findall(r"^FAIL (\S+)", out, re.M)
    mig_err = "ERROR" in out and "== tests ==" not in out
    if p.returncode != 0:
        killed.append(name)
        how = "migration error" if mig_err else "FAIL " + ",".join(failed)
        print(f"killed   {name}: {how}")
    else:
        survivors.append(name); print(f"SURVIVED {name}")
open(f"{WORK}/{MIG}", "w").write(orig)
open(f"{WORK}/{MIG2}", "w").write(orig2)
print(f"\nkilled={len(killed)} survived={len(survivors)} not_applicable={len(na)}")
print("survivors:", survivors)
print("not applicable:", na)
shutil.rmtree(WORK, ignore_errors=True)
sys.exit(1 if survivors or na else 0)
