-- B7: verification risk classification, reviewer authorization hardening and the
-- server-side access contract for the separate web Admin console.
-- (DRAFT: review before applying to any shared project; not applied anywhere.)
--
-- Additive to 20261117000100_secure_foundation.sql. Nothing here creates wallet, escrow,
-- custody, settlement or payment-gateway objects.
--
-- Defect fixed (found by the B7 review, reproduced against commit cc84f70):
--   A single reviewer could pass p_risk_level => 'standard' on a case that an early-review
--   flag had set to 'high', then approve it alone. The second-review requirement was derived
--   from the mutable risk level, so it could be silently removed.
--
-- Policy implemented (engineering defaults pending Security Lead review):
--   1. Staff roles require an aal2 (MFA) session (unchanged, has_platform_role).
--   2. Declaring high risk requires a documented reason (>= 10 characters).
--   3. Rejected-to-approved, policy-exception, declared-high-risk and early-review-flagged
--      cases all require an independent second reviewer.
--   4. The second-review requirement is STICKY: second_review_required can never go back to
--      false and risk_level can never be lowered, by any writer (trigger, also binds the
--      table owner). Lowering a risk level is not supported; it needs a policy decision.
--   5. No self-approval, no conflict-of-interest reviewers (unchanged).
--   6. Every decision records actor, time, reason, risk level and risk reason, and a snapshot
--      of the evidence references that were in front of the reviewer.

-- ---------------------------------------------------------------------------
-- 1. Sticky second-review requirement and documented risk reason.
-- ---------------------------------------------------------------------------
alter table public.supplier_verification_cases
  add column second_review_required boolean not null default false,
  add column risk_reason text check (risk_reason is null or length(trim(risk_reason)) >= 10);

update public.supplier_verification_cases
set second_review_required = true
where risk_level = 'high';

alter table public.verification_decisions
  add column risk_level text check (risk_level is null or risk_level in ('standard', 'high')),
  add column risk_reason text,
  add column evidence_reference text[];

create function private.protect_risk_controls() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.second_review_required and not new.second_review_required then
    raise exception 'the second-review requirement cannot be removed from a case'
      using errcode = '42501';
  end if;
  if old.risk_level = 'high' and new.risk_level <> 'high' then
    raise exception 'a high risk level cannot be lowered'
      using errcode = '42501';
  end if;
  return new;
end $$;

create trigger supplier_verification_cases_protect_risk
  before update on public.supplier_verification_cases
  for each row execute function private.protect_risk_controls();

-- ---------------------------------------------------------------------------
-- 2. Review decision: risk can be raised with a documented reason, never lowered.
-- ---------------------------------------------------------------------------
drop function public.review_supplier_verification(uuid, text, text, text, boolean, text);

create function public.review_supplier_verification(
  p_case_id uuid,
  p_decision text,
  p_reason text,
  p_verification_scope text default null,
  p_policy_exception boolean default false,
  p_risk_level text default null,
  p_risk_reason text default null
) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_case public.supplier_verification_cases%rowtype;
  v_requires_second boolean;
  v_status text;
  v_second boolean := false;
  v_exception boolean := coalesce(p_policy_exception, false);
  v_risk_reason text := nullif(trim(coalesce(p_risk_reason, '')), '');
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
  if v_exception and length(trim(p_reason)) < 10 then
    raise exception 'a documented reason (at least 10 characters) is required for a policy exception'
      using errcode = '22023';
  end if;
  if p_risk_level = 'high' and (v_risk_reason is null or length(v_risk_reason) < 10) then
    raise exception 'a documented risk reason (at least 10 characters) is required to declare high risk'
      using errcode = '22023';
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

  -- Risk classification may be raised (with a documented reason) but never lowered.
  if p_risk_level = 'standard' and v_case.risk_level = 'high' then
    raise exception 'a high risk level cannot be lowered by a reviewer' using errcode = '42501';
  end if;
  if p_risk_level = 'high' and v_case.risk_level = 'standard' then
    v_case.risk_level := 'high';
    v_case.risk_reason := v_risk_reason;
    v_case.second_review_required := true;
  end if;

  if v_case.status = 'awaiting_second_review' then
    if p_decision = 'request_more_information' then
      raise exception 'second review can only approve or reject' using errcode = '22023';
    end if;
    if v_case.first_reviewer_id = v_uid and p_decision = 'approve' then
      raise exception 'a different reviewer must give the second approval' using errcode = '42501';
    end if;
    v_second := true;
  end if;

  if p_decision = 'approve' and (p_verification_scope is null or length(trim(p_verification_scope)) < 1)
     and v_case.verification_scope is null then
    raise exception 'approval must state what was verified' using errcode = '22023';
  end if;

  if v_exception then
    v_case.second_review_required := true;
  end if;
  v_requires_second := v_case.second_review_required or exists (
    select 1 from public.supplier_verification_cases c
    join public.verification_decisions d on d.case_id = c.id
    where c.organization_id = v_case.organization_id and d.decision = 'reject');
  if v_requires_second then
    v_case.second_review_required := true;
  end if;

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
    risk_reason = v_case.risk_reason,
    second_review_required = v_case.second_review_required,
    verification_scope = coalesce(nullif(trim(p_verification_scope), ''), c.verification_scope),
    first_reviewer_id = case when v_status = 'awaiting_second_review' then v_uid else c.first_reviewer_id end,
    reviewer_id = case when v_status in ('approved', 'rejected') then v_uid else c.reviewer_id end,
    decision_reason = case when v_status in ('approved', 'rejected') then trim(p_reason) else c.decision_reason end,
    reviewed_at = case when v_status in ('approved', 'rejected') then now() else c.reviewed_at end,
    expires_at = case when v_status = 'approved' then now() + interval '12 months' else c.expires_at end
  where c.id = p_case_id;

  insert into public.verification_decisions (
    case_id, decision, decided_by, reason, policy_exception, is_second_review,
    risk_level, risk_reason, evidence_reference)
  values (
    p_case_id, p_decision, v_uid, trim(p_reason), v_exception, v_second,
    v_case.risk_level, v_case.risk_reason, v_case.evidence_object_paths);

  perform private.write_audit(
    case when v_status = 'awaiting_second_review' then 'verification.first_approval'
         when v_status = 'approved' then 'verification.approved'
         when v_status = 'rejected' then 'verification.rejected'
         else 'verification.more_information_requested' end,
    'supplier_verification_case', p_case_id, trim(p_reason),
    jsonb_build_object('status', v_status, 'second_review', v_second, 'risk_level', v_case.risk_level,
      'second_review_required', v_case.second_review_required, 'policy_exception', v_exception));
  return v_status;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Early-review flag: documented reason, sticky second-review requirement.
-- ---------------------------------------------------------------------------
create or replace function public.flag_supplier_for_early_review(p_case_id uuid, p_reason text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_case public.supplier_verification_cases%rowtype;
begin
  if not private.has_platform_role('verification_reviewer') then
    raise exception 'verification reviewer role (aal2) required' using errcode = '42501';
  end if;
  if p_reason is null or length(trim(p_reason)) < 10 then
    raise exception 'a documented reason (at least 10 characters) is required' using errcode = '22023';
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

  -- Verification lapses immediately; re-approval needs an independent second reviewer
  -- and that requirement can no longer be removed (protect_risk_controls).
  update public.supplier_verification_cases c set
    status = 'in_review', risk_level = 'high', risk_reason = trim(p_reason),
    second_review_required = true, expires_at = now(),
    first_reviewer_id = null, reviewer_id = null
  where c.id = p_case_id;
  insert into public.verification_decisions (
    case_id, decision, decided_by, reason, risk_level, risk_reason, evidence_reference)
  values (
    p_case_id, 'flag_for_early_review', v_uid, trim(p_reason), 'high', trim(p_reason),
    v_case.evidence_object_paths);
  perform private.write_audit('verification.flagged_for_early_review', 'supplier_verification_case',
    p_case_id, trim(p_reason), jsonb_build_object('status', 'in_review', 'risk_level', 'high'));
  return 'in_review';
end $$;

-- ---------------------------------------------------------------------------
-- 4. Access contract for the web Admin console. The browser never decides who may do
--    what: it asks the server. Roles come from platform_roles only (never from client
--    metadata) and capabilities are returned only for an aal2 (MFA) session.
--    Capabilities listed here exist today; nothing is advertised that is not implemented.
-- ---------------------------------------------------------------------------
create function public.my_platform_access() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_aal text := coalesce((select auth.jwt()) ->> 'aal', 'aal1');
  v_roles text[];
  v_caps text[] := '{}';
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select coalesce(array_agg(r.role order by r.role), '{}') into v_roles
  from public.platform_roles r
  where r.user_id = v_uid and r.revoked_at is null;

  if v_aal = 'aal2' then
    select coalesce(array_agg(distinct cap order by cap), '{}') into v_caps
    from unnest(v_roles) as ur(role_name),
         lateral unnest(case ur.role_name
           when 'platform_admin' then array['audit.view', 'roles.manage']
           when 'verification_reviewer' then array['verification.review']
           else array[]::text[] end) as cap;
  end if;

  return jsonb_build_object(
    'user_id', v_uid, 'aal', v_aal, 'mfa_satisfied', v_aal = 'aal2',
    'roles', to_jsonb(v_roles), 'capabilities', to_jsonb(v_caps));
end $$;

-- ---------------------------------------------------------------------------
-- 5. Function privileges: closed by default, opened one by one.
-- ---------------------------------------------------------------------------
revoke all on function private.protect_risk_controls() from public, anon, authenticated;
revoke all on function public.review_supplier_verification(uuid, text, text, text, boolean, text, text) from public, anon, authenticated;
revoke all on function public.my_platform_access() from public, anon, authenticated;

grant execute on function public.review_supplier_verification(uuid, text, text, text, boolean, text, text) to authenticated;
grant execute on function public.my_platform_access() to authenticated;
