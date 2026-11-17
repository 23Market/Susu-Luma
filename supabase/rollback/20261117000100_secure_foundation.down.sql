-- ROLLBACK for 20261117000100_secure_foundation.sql
--
-- DISPOSABLE DEVELOPMENT DATABASES ONLY. This is deliberately NOT in supabase/migrations
-- so the Supabase CLI never applies it. It drops tables and columns that hold data
-- (platform roles, decision history, risk flags, idempotency keys) and deletes the
-- evidence bucket. Never run it against staging or production: restore from a backup
-- (docs/SECURE_FOUNDATION.md, "Recovery") instead.
--
-- Usage:
--   PGOPTIONS="-c luma.allow_data_loss=yes" psql -v ON_ERROR_STOP=1 -f <this file>
--
-- Restores the pre-migration schema and the Supabase default client grants. Verified by
-- scripts/local-db/rollback-test.sh (schema dump equals the two-migration baseline).
begin;

do $$ begin
  if coalesce(current_setting('luma.allow_data_loss', true), '') <> 'yes' then
    raise exception 'Refusing to roll back: this destroys platform_roles, verification_decisions and related data. Disposable development databases only; set luma.allow_data_loss=yes to proceed.';
  end if;
  if exists (select 1 from storage.objects where bucket_id = 'verification-evidence') then
    raise exception 'Refusing to roll back: the verification-evidence bucket still holds objects. Remove them deliberately first.';
  end if;
end $$;

-- RPCs
drop function if exists public.revoke_platform_role(uuid, text);
drop function if exists public.grant_platform_role(uuid, text);
drop function if exists public.expire_lapsed_verifications();
drop function if exists public.supplier_is_verified(uuid);
drop function if exists public.authorize_evidence_access(uuid, text);
drop function if exists public.reviewer_list_verification_decisions(uuid);
drop function if exists public.reviewer_list_verification_cases(text);
drop function if exists public.flag_supplier_for_early_review(uuid, text);
drop function if exists public.review_supplier_verification(uuid, text, text, text, boolean, text);
drop function if exists public.submit_supplier_verification(uuid, text[]);
drop function if exists public.create_organization_with_owner(text, text, text, text, text, text, uuid);

-- Storage policies and bucket
drop policy if exists verification_evidence_read_own_org on storage.objects;
drop policy if exists verification_evidence_insert_own_org on storage.objects;
delete from storage.buckets where id = 'verification-evidence';

-- Verification workflow
drop policy if exists verification_case_read_org on public.supplier_verification_cases;
drop table if exists public.verification_decisions;
drop index if exists public.supplier_verification_one_open_case;
update public.supplier_verification_cases set status = 'in_review' where status = 'awaiting_second_review';
alter table public.supplier_verification_cases
  drop constraint supplier_verification_cases_status_check;
alter table public.supplier_verification_cases
  add constraint supplier_verification_cases_status_check
  check (status in ('pending', 'in_review', 'approved', 'rejected', 'expired'));
alter table public.supplier_verification_cases
  drop column if exists risk_level,
  drop column if exists first_reviewer_id;

-- Organisation integrity
drop trigger if exists organization_memberships_protect_last_owner on public.organization_memberships;
drop trigger if exists organizations_require_owner on public.organizations;
drop index if exists public.organizations_creation_key_uidx;
alter table public.organizations drop column if exists creation_key;

-- Audit trail
drop policy if exists audit_read_platform_admin on public.audit_events;
drop trigger if exists audit_events_no_truncate on public.audit_events;
drop trigger if exists audit_events_append_only on public.audit_events;

-- Platform roles and the private helper schema
drop table if exists public.platform_roles;
drop schema if exists private cascade;

-- Restore the Supabase default grants that the migration revoked. Column-level grants
-- (listings discovery columns, verification case columns) survive a table-level GRANT,
-- so revoke everything first; REVOKE ALL on a table also clears its column privileges.
revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant all on all functions in schema public to anon, authenticated, service_role;

commit;
