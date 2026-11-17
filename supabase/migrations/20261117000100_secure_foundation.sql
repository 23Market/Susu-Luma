-- E7 secure foundation (DRAFT: review before applying to any shared project).
--
-- Additive to 20261017000100_marketplace_foundation.sql and
-- 20261112000100_listing_submission_guard.sql. Nothing here creates wallet, escrow,
-- custody, settlement or payment-gateway objects.
--
-- Scope: server-controlled platform roles, least-privilege grants, atomic
-- organisation + owner onboarding, append-only audit trail, supplier verification
-- workflow (private evidence, second reviewer, 12-month expiry) and private storage.
--
-- Engineering defaults that policy owners may change in a later migration:
--   * verification validity 12 months; risk-flagged review is treated as high risk
--   * platform staff roles require an aal2 (MFA) session
--   * evidence bucket: 10 MiB per object; PDF, JPEG and PNG only; max 20 files per case
-- Rollback: see docs/SECURE_FOUNDATION.md (disposable development databases only).

-- ---------------------------------------------------------------------------
-- 0. Private schema for internal helpers (not exposed through the Data API).
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, anon;

create function private.try_uuid(p_value text) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  return p_value::uuid;
exception when invalid_text_representation then
  return null;
end $$;

create function private.forbid_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception '% on % is not allowed: the table is append-only', tg_op, tg_table_name
    using errcode = '42501';
end $$;

-- ---------------------------------------------------------------------------
-- 1. Platform roles: server-controlled, never read from client-editable metadata.
-- ---------------------------------------------------------------------------
create table public.platform_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in (
    'platform_admin', 'verification_reviewer', 'finance_officer', 'support_agent', 'analyst')),
  granted_by uuid references auth.users (id) on delete set null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (user_id, role)
);
alter table public.platform_roles enable row level security;
-- No client policies: roles are changed only by grant_platform_role/revoke_platform_role
-- (platform_admin, aal2) or by the project owner through service-role SQL.

create function private.has_platform_role(p_role text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.platform_roles r
    where r.user_id = (select auth.uid())
      and r.role = p_role
      and r.revoked_at is null
  ) and coalesce((select auth.jwt()) ->> 'aal', '') = 'aal2'
$$;

create function private.is_org_member(p_org uuid, p_roles text[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.member_role = any (p_roles)
  )
$$;

-- ---------------------------------------------------------------------------
-- 2. Audit trail: append-only; readable only by platform_admin (aal2).
-- ---------------------------------------------------------------------------
create function private.write_audit(
  p_action text, p_entity_type text, p_entity_id uuid, p_reason text, p_metadata jsonb
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_events (actor_user_id, action, entity_type, entity_id, reason, metadata)
  values ((select auth.uid()), p_action, p_entity_type, p_entity_id, p_reason, coalesce(p_metadata, '{}'::jsonb));
end $$;

create trigger audit_events_append_only
  before update or delete on public.audit_events
  for each row execute function private.forbid_mutation();
create trigger audit_events_no_truncate
  before truncate on public.audit_events
  for each statement execute function private.forbid_mutation();

create policy audit_read_platform_admin on public.audit_events
  for select to authenticated using (private.has_platform_role('platform_admin'));

-- ---------------------------------------------------------------------------
-- 3. Least-privilege grants. RLS stays on, but clients also lose every privilege
--    they do not need, and future tables are not auto-granted to client roles.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from anon, authenticated;

grant select on public.organizations, public.organization_memberships to authenticated;
grant select on public.audit_events to authenticated; -- rows limited by audit_read_platform_admin
-- Discovery must not expose the creating user's id to anyone, signed in or not.
grant select (
  id, organization_id, title, description, category, specifications, quantity_unit,
  minimum_order_quantity, price_mode, price_amount, currency_code, availability,
  lead_time_days, district, locality, status, published_at, created_at, updated_at
) on public.listings to anon, authenticated;
grant insert on public.listings to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Atomic organisation + owner membership, with integrity guards.
-- ---------------------------------------------------------------------------
alter table public.organizations add column creation_key uuid;
create unique index organizations_creation_key_uidx
  on public.organizations (created_by, creation_key) where creation_key is not null;

create function private.assert_org_has_owner() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.organization_memberships m
    where m.organization_id = new.id and m.member_role = 'owner'
  ) then
    raise exception 'organization % must have an owner membership', new.id using errcode = '23514';
  end if;
  return null;
end $$;

create constraint trigger organizations_require_owner
  after insert on public.organizations
  deferrable initially deferred
  for each row execute function private.assert_org_has_owner();

create function private.protect_last_owner() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.member_role = 'owner'
     and (tg_op = 'DELETE' or new.member_role <> 'owner' or new.user_id <> old.user_id)
  then
    -- Serialise concurrent owner changes within one organisation. Without this lock two
    -- owners removing each other at the same moment each see the other as the remaining
    -- owner and both commit, leaving the organisation with none (write skew).
    -- NO KEY UPDATE does not block inserts of new members (they only take KEY SHARE).
    perform 1 from public.organizations o where o.id = old.organization_id for no key update;
    -- Not found means the organisation itself is being deleted (cascade): allow it.
    if found and not exists (
         select 1 from public.organization_memberships m
         where m.organization_id = old.organization_id
           and m.member_role = 'owner' and m.user_id <> old.user_id)
    then
      raise exception 'organization % must keep at least one owner', old.organization_id
        using errcode = '23514';
    end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

create trigger organization_memberships_protect_last_owner
  before update or delete on public.organization_memberships
  for each row execute function private.protect_last_owner();

create function public.create_organization_with_owner(
  p_legal_name text,
  p_display_name text,
  p_organization_type text default 'business',
  p_district text default null,
  p_locality text default null,
  p_public_description text default null,
  p_creation_key uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_org uuid;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_organization_type is null or p_organization_type not in ('buyer', 'supplier', 'business') then
    raise exception 'invalid organization_type' using errcode = '22023';
  end if;
  if length(coalesce(p_district, '')) > 120 or length(coalesce(p_locality, '')) > 120
     or length(coalesce(p_public_description, '')) > 2000 then
    raise exception 'district, locality or description too long' using errcode = '22023';
  end if;

  if p_creation_key is not null then
    select o.id into v_org from public.organizations o
    where o.created_by = v_uid and o.creation_key = p_creation_key;
    if found then
      return v_org;
    end if;
  end if;

  insert into public.organizations (
    legal_name, display_name, organization_type, district, locality,
    public_description, created_by, creation_key)
  values (
    p_legal_name, p_display_name, p_organization_type, nullif(trim(p_district), ''),
    nullif(trim(p_locality), ''), nullif(trim(p_public_description), ''), v_uid, p_creation_key)
  on conflict (created_by, creation_key) where creation_key is not null do nothing
  returning id into v_org;

  if v_org is null then
    -- A concurrent request with the same key committed first: return its organization.
    select o.id into v_org from public.organizations o
    where o.created_by = v_uid and o.creation_key = p_creation_key;
    return v_org;
  end if;

  insert into public.organization_memberships (organization_id, user_id, member_role)
  values (v_org, v_uid, 'owner');

  perform private.write_audit('organization.created', 'organization', v_org, null,
    jsonb_build_object('organization_type', p_organization_type));
  return v_org;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Supplier verification: private evidence, reviewer authorization,
--    second reviewer, no self-approval, immutable decision history, expiry.
-- ---------------------------------------------------------------------------
alter table public.supplier_verification_cases
  drop constraint supplier_verification_cases_status_check;
alter table public.supplier_verification_cases
  add constraint supplier_verification_cases_status_check
  check (status in ('pending', 'in_review', 'awaiting_second_review', 'approved', 'rejected', 'expired'));
alter table public.supplier_verification_cases
  add column risk_level text not null default 'standard' check (risk_level in ('standard', 'high')),
  add column first_reviewer_id uuid references auth.users (id) on delete restrict;
create unique index supplier_verification_one_open_case
  on public.supplier_verification_cases (organization_id)
  where status in ('pending', 'in_review', 'awaiting_second_review');

create table public.verification_decisions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.supplier_verification_cases (id) on delete restrict,
  decision text not null check (decision in (
    'approve', 'reject', 'request_more_information', 'flag_for_early_review')),
  decided_by uuid not null references auth.users (id) on delete restrict,
  decided_at timestamptz not null default now(),
  reason text not null check (length(trim(reason)) between 1 and 2000),
  policy_exception boolean not null default false,
  is_second_review boolean not null default false
);
alter table public.verification_decisions enable row level security;
create trigger verification_decisions_append_only
  before update or delete on public.verification_decisions
  for each row execute function private.forbid_mutation();
create trigger verification_decisions_no_truncate
  before truncate on public.verification_decisions
  for each statement execute function private.forbid_mutation();

-- Organisation owners/admins see their own case status. Reviewer identity, decision
-- reasons and risk level stay internal (column grant) and are read through RPCs.
create policy verification_case_read_org on public.supplier_verification_cases
  for select to authenticated using (private.is_org_member(organization_id, array['owner', 'admin']));
grant select (id, organization_id, status, verification_scope, evidence_object_paths,
  submitted_at, reviewed_at, expires_at) on public.supplier_verification_cases to authenticated;

-- Private evidence bucket and storage policies.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('verification-evidence', 'verification-evidence', false, 10485760,
  array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do update set
  public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy verification_evidence_insert_own_org on storage.objects
  for insert to authenticated with check (
    bucket_id = 'verification-evidence'
    and array_length(storage.foldername(name), 1) = 1
    and private.is_org_member(private.try_uuid((storage.foldername(name))[1]), array['owner', 'admin'])
  );
create policy verification_evidence_read_own_org on storage.objects
  for select to authenticated using (
    bucket_id = 'verification-evidence'
    and private.is_org_member(private.try_uuid((storage.foldername(name))[1]), array['owner', 'admin'])
  );
-- No update/delete policies: evidence is immutable once uploaded. Reviewers never read
-- the bucket directly; they call authorize_evidence_access() and a server function
-- issues a short-lived signed URL.

create function public.submit_supplier_verification(
  p_organization_id uuid, p_evidence_paths text[]
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_type text;
  v_case uuid;
  v_path text;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_org_member(p_organization_id, array['owner', 'admin']) then
    raise exception 'not allowed to submit verification for this organization' using errcode = '42501';
  end if;
  select o.organization_type into v_type from public.organizations o where o.id = p_organization_id;
  if v_type is null or v_type not in ('supplier', 'business') then
    raise exception 'only supplier or business organizations can be verified' using errcode = '22023';
  end if;
  if p_evidence_paths is null or cardinality(p_evidence_paths) < 1 or cardinality(p_evidence_paths) > 20 then
    raise exception 'between 1 and 20 evidence files are required' using errcode = '22023';
  end if;
  foreach v_path in array p_evidence_paths loop
    if v_path is null or v_path not like (p_organization_id::text || '/%')
       or v_path like '%..%' or length(v_path) > 300 then
      raise exception 'evidence path is outside the organization folder' using errcode = '22023';
    end if;
    if not exists (
      select 1 from storage.objects so
      where so.bucket_id = 'verification-evidence' and so.name = v_path
    ) then
      raise exception 'evidence file has not been uploaded' using errcode = '22023';
    end if;
  end loop;

  insert into public.supplier_verification_cases (organization_id, evidence_object_paths, created_by)
  values (p_organization_id, p_evidence_paths, v_uid)
  returning id into v_case; -- a second open case for the organization raises unique_violation

  perform private.write_audit('verification.submitted', 'supplier_verification_case', v_case, null,
    jsonb_build_object('organization_id', p_organization_id, 'evidence_count', cardinality(p_evidence_paths)));
  return v_case;
end $$;

create function public.review_supplier_verification(
  p_case_id uuid,
  p_decision text,
  p_reason text,
  p_verification_scope text default null,
  p_policy_exception boolean default false,
  p_risk_level text default null
) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_case public.supplier_verification_cases%rowtype;
  v_requires_second boolean;
  v_status text;
  v_second boolean := false;
begin
  if not private.has_platform_role('verification_reviewer') then
    raise exception 'verification reviewer role (aal2) required' using errcode = '42501';
  end if;
  if p_decision is null or p_decision not in ('approve', 'reject', 'request_more_information') then
    raise exception 'invalid decision' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) < 1 then
    raise exception 'a decision reason is required' using errcode = '22023';
  end if;
  if p_risk_level is not null and p_risk_level not in ('standard', 'high') then
    raise exception 'invalid risk level' using errcode = '22023';
  end if;

  select * into v_case from public.supplier_verification_cases c where c.id = p_case_id for update;
  if not found then
    raise exception 'verification case not found' using errcode = 'P0002';
  end if;
  if v_case.status not in ('pending', 'in_review', 'awaiting_second_review') then
    raise exception 'case is not open for review (status %)', v_case.status using errcode = '55000';
  end if;

  -- No self-approval and no conflicts: the submitter and any member of the supplier
  -- organization can never decide its case.
  if v_case.created_by = v_uid or exists (
    select 1 from public.organization_memberships m
    where m.organization_id = v_case.organization_id and m.user_id = v_uid
  ) then
    raise exception 'reviewer has a conflict of interest with this case' using errcode = '42501';
  end if;

  if v_case.status = 'awaiting_second_review' then
    if p_decision = 'request_more_information' then
      raise exception 'second review can only approve or reject' using errcode = '22023';
    end if;
    if v_case.first_reviewer_id = v_uid and p_decision = 'approve' then
      raise exception 'a different reviewer must give the second approval' using errcode = '42501';
    end if;
    v_second := true;
  elsif p_risk_level is not null then
    v_case.risk_level := p_risk_level;
  end if;

  if p_decision = 'approve' and (p_verification_scope is null or length(trim(p_verification_scope)) < 1)
     and v_case.verification_scope is null then
    raise exception 'approval must state what was verified' using errcode = '22023';
  end if;

  v_requires_second := v_case.risk_level = 'high' or coalesce(p_policy_exception, false) or exists (
    select 1 from public.supplier_verification_cases c
    join public.verification_decisions d on d.case_id = c.id
    where c.organization_id = v_case.organization_id and d.decision = 'reject');

  if p_decision = 'reject' then
    v_status := 'rejected';
  elsif p_decision = 'request_more_information' then
    v_status := 'in_review';
  elsif v_second or not v_requires_second then
    v_status := 'approved';
  else
    v_status := 'awaiting_second_review';
  end if;

  update public.supplier_verification_cases c set
    status = v_status,
    risk_level = v_case.risk_level,
    verification_scope = coalesce(nullif(trim(p_verification_scope), ''), c.verification_scope),
    first_reviewer_id = case when v_status = 'awaiting_second_review' then v_uid else c.first_reviewer_id end,
    reviewer_id = case when v_status in ('approved', 'rejected') then v_uid else c.reviewer_id end,
    decision_reason = case when v_status in ('approved', 'rejected') then trim(p_reason) else c.decision_reason end,
    reviewed_at = case when v_status in ('approved', 'rejected') then now() else c.reviewed_at end,
    expires_at = case when v_status = 'approved' then now() + interval '12 months' else c.expires_at end
  where c.id = p_case_id;

  insert into public.verification_decisions (case_id, decision, decided_by, reason, policy_exception, is_second_review)
  values (p_case_id, p_decision, v_uid, trim(p_reason), coalesce(p_policy_exception, false), v_second);

  perform private.write_audit(
    case when v_status = 'awaiting_second_review' then 'verification.first_approval'
         when v_status = 'approved' then 'verification.approved'
         when v_status = 'rejected' then 'verification.rejected'
         else 'verification.more_information_requested' end,
    'supplier_verification_case', p_case_id, trim(p_reason),
    jsonb_build_object('status', v_status, 'second_review', v_second, 'risk_level', v_case.risk_level,
      'policy_exception', coalesce(p_policy_exception, false)));
  return v_status;
end $$;

create function public.flag_supplier_for_early_review(p_case_id uuid, p_reason text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_case public.supplier_verification_cases%rowtype;
begin
  if not private.has_platform_role('verification_reviewer') then
    raise exception 'verification reviewer role (aal2) required' using errcode = '42501';
  end if;
  if p_reason is null or length(trim(p_reason)) < 1 then
    raise exception 'a reason is required' using errcode = '22023';
  end if;
  select * into v_case from public.supplier_verification_cases c where c.id = p_case_id for update;
  if not found then
    raise exception 'verification case not found' using errcode = 'P0002';
  end if;
  if v_case.status <> 'approved' then
    raise exception 'only an approved case can be flagged (status %)', v_case.status using errcode = '55000';
  end if;
  if v_case.created_by = v_uid or exists (
    select 1 from public.organization_memberships m
    where m.organization_id = v_case.organization_id and m.user_id = v_uid
  ) then
    raise exception 'reviewer has a conflict of interest with this case' using errcode = '42501';
  end if;

  -- Verification lapses immediately; re-approval is treated as high risk (second reviewer).
  update public.supplier_verification_cases c set
    status = 'in_review', risk_level = 'high', expires_at = now(),
    first_reviewer_id = null, reviewer_id = null
  where c.id = p_case_id;
  insert into public.verification_decisions (case_id, decision, decided_by, reason)
  values (p_case_id, 'flag_for_early_review', v_uid, trim(p_reason));
  perform private.write_audit('verification.flagged_for_early_review', 'supplier_verification_case',
    p_case_id, trim(p_reason), jsonb_build_object('status', 'in_review'));
  return 'in_review';
end $$;

create function public.reviewer_list_verification_cases(p_status text default null)
returns setof public.supplier_verification_cases
language plpgsql security definer set search_path = '' as $$
begin
  if not private.has_platform_role('verification_reviewer') then
    raise exception 'verification reviewer role (aal2) required' using errcode = '42501';
  end if;
  return query
    select * from public.supplier_verification_cases c
    where p_status is null or c.status = p_status
    order by c.submitted_at;
end $$;

create function public.reviewer_list_verification_decisions(p_case_id uuid)
returns setof public.verification_decisions
language plpgsql security definer set search_path = '' as $$
begin
  if not private.has_platform_role('verification_reviewer') then
    raise exception 'verification reviewer role (aal2) required' using errcode = '42501';
  end if;
  return query
    select * from public.verification_decisions d where d.case_id = p_case_id order by d.decided_at, d.id;
end $$;

-- Authorizes (and audits) a reviewer reading one evidence file. A server function
-- then issues a short-lived signed URL; clients never receive bucket-wide access.
create function public.authorize_evidence_access(p_case_id uuid, p_path text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_case public.supplier_verification_cases%rowtype;
begin
  if not private.has_platform_role('verification_reviewer') then
    raise exception 'verification reviewer role (aal2) required' using errcode = '42501';
  end if;
  select * into v_case from public.supplier_verification_cases c where c.id = p_case_id;
  if not found or p_path is null or not (p_path = any (v_case.evidence_object_paths)) then
    raise exception 'evidence file is not part of this case' using errcode = '42501';
  end if;
  if v_case.created_by = v_uid or exists (
    select 1 from public.organization_memberships m
    where m.organization_id = v_case.organization_id and m.user_id = v_uid
  ) then
    raise exception 'reviewer has a conflict of interest with this case' using errcode = '42501';
  end if;
  perform private.write_audit('verification.evidence_accessed', 'supplier_verification_case',
    p_case_id, null, jsonb_build_object('path', p_path));
  return true;
end $$;

-- A supplier is verified only while an approved, unexpired case exists. Computed
-- server-side so lapsed approvals never display as verified, even before the job runs.
create function public.supplier_is_verified(p_organization_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.supplier_verification_cases c
    where c.organization_id = p_organization_id and c.status = 'approved' and c.expires_at > now()
  )
$$;

create function public.expire_lapsed_verifications() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_case uuid;
  v_count integer := 0;
begin
  for v_case in
    update public.supplier_verification_cases c set status = 'expired'
    where c.status = 'approved' and c.expires_at <= now()
    returning c.id
  loop
    v_count := v_count + 1;
    perform private.write_audit('verification.expired', 'supplier_verification_case', v_case, null,
      jsonb_build_object('status', 'expired'));
  end loop;
  return v_count;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Platform role administration (platform_admin, aal2; no self-grants).
-- ---------------------------------------------------------------------------
create function public.grant_platform_role(p_user_id uuid, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if not private.has_platform_role('platform_admin') then
    raise exception 'platform_admin role (aal2) required' using errcode = '42501';
  end if;
  if p_user_id = v_uid then
    raise exception 'platform roles cannot be granted to yourself' using errcode = '42501';
  end if;
  if p_role is null or p_role not in (
    'platform_admin', 'verification_reviewer', 'finance_officer', 'support_agent', 'analyst') then
    raise exception 'unknown platform role' using errcode = '22023';
  end if;
  insert into public.platform_roles (user_id, role, granted_by)
  values (p_user_id, p_role, v_uid)
  on conflict (user_id, role) do update
    set revoked_at = null, granted_by = excluded.granted_by, granted_at = now();
  perform private.write_audit('platform_role.granted', 'platform_role', p_user_id, null,
    jsonb_build_object('role', p_role));
end $$;

create function public.revoke_platform_role(p_user_id uuid, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if not private.has_platform_role('platform_admin') then
    raise exception 'platform_admin role (aal2) required' using errcode = '42501';
  end if;
  if p_user_id = v_uid then
    raise exception 'platform roles cannot be revoked from yourself' using errcode = '42501';
  end if;
  update public.platform_roles r set revoked_at = now()
  where r.user_id = p_user_id and r.role = p_role and r.revoked_at is null;
  if not found then
    raise exception 'no active role to revoke' using errcode = 'P0002';
  end if;
  perform private.write_audit('platform_role.revoked', 'platform_role', p_user_id, null,
    jsonb_build_object('role', p_role));
end $$;

-- ---------------------------------------------------------------------------
-- 7. Function privileges: closed by default, opened one by one.
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.try_uuid(text) to anon, authenticated;
grant execute on function private.has_platform_role(text) to authenticated;
grant execute on function private.is_org_member(uuid, text[]) to authenticated;

revoke all on function public.create_organization_with_owner(text, text, text, text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.submit_supplier_verification(uuid, text[]) from public, anon, authenticated;
revoke all on function public.review_supplier_verification(uuid, text, text, text, boolean, text) from public, anon, authenticated;
revoke all on function public.flag_supplier_for_early_review(uuid, text) from public, anon, authenticated;
revoke all on function public.reviewer_list_verification_cases(text) from public, anon, authenticated;
revoke all on function public.reviewer_list_verification_decisions(uuid) from public, anon, authenticated;
revoke all on function public.authorize_evidence_access(uuid, text) from public, anon, authenticated;
revoke all on function public.supplier_is_verified(uuid) from public, anon, authenticated;
revoke all on function public.expire_lapsed_verifications() from public, anon, authenticated;
revoke all on function public.grant_platform_role(uuid, text) from public, anon, authenticated;
revoke all on function public.revoke_platform_role(uuid, text) from public, anon, authenticated;

grant execute on function public.create_organization_with_owner(text, text, text, text, text, text, uuid) to authenticated;
grant execute on function public.submit_supplier_verification(uuid, text[]) to authenticated;
grant execute on function public.review_supplier_verification(uuid, text, text, text, boolean, text) to authenticated;
grant execute on function public.flag_supplier_for_early_review(uuid, text) to authenticated;
grant execute on function public.reviewer_list_verification_cases(text) to authenticated;
grant execute on function public.reviewer_list_verification_decisions(uuid) to authenticated;
grant execute on function public.authorize_evidence_access(uuid, text) to authenticated;
grant execute on function public.supplier_is_verified(uuid) to anon, authenticated;
grant execute on function public.expire_lapsed_verifications() to service_role;
grant execute on function public.grant_platform_role(uuid, text) to authenticated;
grant execute on function public.revoke_platform_role(uuid, text) to authenticated;
