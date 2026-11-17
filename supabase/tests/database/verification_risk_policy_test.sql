-- B7: verification risk classification, sticky second review, documented reasons,
-- reviewer and role-escalation limits, and the my_platform_access() contract.
-- Synthetic data only.
--
-- Fixed identities (all synthetic):
--   S1..S4 supplier owners of O1..O4           RV1/RV2/RV3 verification reviewers
--   RVR reviewer whose role was revoked         AD platform admin
--   FO finance officer                          X ordinary user with no platform role
begin;
select plan(62);

insert into auth.users(id) values
  ('a1000000-0000-0000-0000-000000000001'), ('a1000000-0000-0000-0000-000000000002'),
  ('a1000000-0000-0000-0000-000000000003'), ('a1000000-0000-0000-0000-000000000004'),
  ('a1000000-0000-0000-0000-000000000011'), ('a1000000-0000-0000-0000-000000000012'),
  ('a1000000-0000-0000-0000-000000000013'), ('a1000000-0000-0000-0000-000000000014'),
  ('a1000000-0000-0000-0000-000000000021'), ('a1000000-0000-0000-0000-000000000022'),
  ('a1000000-0000-0000-0000-000000000031'), ('a1000000-0000-0000-0000-000000000041');
insert into public.organizations(id, legal_name, display_name, organization_type, created_by) values
  ('a2000000-0000-0000-0000-000000000001', 'Synthetic Supplier A1', 'Supplier A1', 'supplier', 'a1000000-0000-0000-0000-000000000001'),
  ('a2000000-0000-0000-0000-000000000002', 'Synthetic Supplier A2', 'Supplier A2', 'supplier', 'a1000000-0000-0000-0000-000000000002'),
  ('a2000000-0000-0000-0000-000000000003', 'Synthetic Supplier A3', 'Supplier A3', 'supplier', 'a1000000-0000-0000-0000-000000000003'),
  ('a2000000-0000-0000-0000-000000000004', 'Synthetic Supplier A4', 'Supplier A4', 'supplier', 'a1000000-0000-0000-0000-000000000004');
insert into public.organization_memberships(organization_id, user_id, member_role) values
  ('a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'owner'),
  ('a2000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000002', 'owner'),
  ('a2000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000003', 'owner'),
  ('a2000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000004', 'owner'),
  ('a2000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000041', 'staff');
insert into public.platform_roles(user_id, role, revoked_at) values
  ('a1000000-0000-0000-0000-000000000011', 'verification_reviewer', null),
  ('a1000000-0000-0000-0000-000000000012', 'verification_reviewer', null),
  ('a1000000-0000-0000-0000-000000000013', 'verification_reviewer', null),
  ('a1000000-0000-0000-0000-000000000014', 'verification_reviewer', now()),
  ('a1000000-0000-0000-0000-000000000021', 'platform_admin', null),
  ('a1000000-0000-0000-0000-000000000022', 'finance_officer', null),
  ('a1000000-0000-0000-0000-000000000041', 'verification_reviewer', null);
insert into storage.objects(bucket_id, name) values
  ('verification-evidence', 'a2000000-0000-0000-0000-000000000001/registration.pdf'),
  ('verification-evidence', 'a2000000-0000-0000-0000-000000000002/registration.pdf'),
  ('verification-evidence', 'a2000000-0000-0000-0000-000000000003/registration.pdf'),
  ('verification-evidence', 'a2000000-0000-0000-0000-000000000004/registration.pdf');

-- ============================================ A. early-review flag: risk cannot be lowered
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('a2000000-0000-0000-0000-000000000001', array['a2000000-0000-0000-0000-000000000001/registration.pdf'])$$,
  'A: supplier 1 submits verification');
reset role;
do $$ begin
  perform set_config('luma.case_o1', (select id::text from public.supplier_verification_cases
    where organization_id = 'a2000000-0000-0000-0000-000000000001'), true);
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select is(public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve',
    'Registration certificate matches', 'Business registration'),
  'approved', 'A: standard-risk case approved by one independent reviewer');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000012","role":"authenticated","aal":"aal2"}';
select is(public.flag_supplier_for_early_review(current_setting('luma.case_o1')::uuid, 'Trading licence reported revoked'),
  'in_review', 'A: a reviewer flags the approved case for early review');
reset role;
select is((select risk_level from public.supplier_verification_cases where id = current_setting('luma.case_o1')::uuid),
  'high', 'A: the flag sets the risk level to high');
select is((select second_review_required from public.supplier_verification_cases where id = current_setting('luma.case_o1')::uuid),
  true, 'A: the flag makes the second review mandatory');
select is((select risk_reason from public.supplier_verification_cases where id = current_setting('luma.case_o1')::uuid),
  'Trading licence reported revoked', 'A: the flag reason is stored as the documented risk reason');
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'Looks fine to me', null, false, 'standard')$$,
  '42501', 'a high risk level cannot be lowered by a reviewer',
  'A: REGRESSION: a reviewer cannot lower the flag and approve alone');
select is(public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve',
    'Licence reinstated and documents re-checked', 'Business registration and licence'),
  'awaiting_second_review', 'A: the flagged case still needs an independent second reviewer');
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'second approval by the same person')$$,
  '42501', 'a different reviewer must give the second approval', 'A: the first approver cannot give the second approval');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000013","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'Independent confirmation', null, false, 'standard')$$,
  '42501', 'a high risk level cannot be lowered by a reviewer', 'A: the second reviewer cannot lower the flag either');
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'request_more_information', 'asking for more detail')$$,
  '22023', 'second review can only approve or reject', 'A: second review cannot reopen the case');
select is(public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'Independent confirmation'),
  'approved', 'A: an independent second reviewer completes the approval');
reset role;
select throws_ok(
  $$update public.supplier_verification_cases set risk_level = 'standard' where id = current_setting('luma.case_o1')::uuid$$,
  '42501', 'a high risk level cannot be lowered', 'A: no writer, not even the table owner, can lower the risk level');
select throws_ok(
  $$update public.supplier_verification_cases set second_review_required = false where id = current_setting('luma.case_o1')::uuid$$,
  '42501', 'the second-review requirement cannot be removed from a case',
  'A: no writer, not even the table owner, can remove the second-review requirement');
select is((select count(*)::int from public.verification_decisions
           where case_id = current_setting('luma.case_o1')::uuid and evidence_reference is not null
             and evidence_reference = array['a2000000-0000-0000-0000-000000000001/registration.pdf']), 4,
  'A: all four decisions record the evidence reference that was reviewed');
select is((select count(*)::int from public.verification_decisions
           where case_id = current_setting('luma.case_o1')::uuid and risk_level = 'high'), 3,
  'A: decisions record the risk level in force (flag and both post-flag approvals are high)');

-- ============================================ B. declared high risk needs a documented reason
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('a2000000-0000-0000-0000-000000000002', array['a2000000-0000-0000-0000-000000000002/registration.pdf'])$$,
  'B: supplier 2 submits verification');
reset role;
do $$ begin
  perform set_config('luma.case_o2', (select id::text from public.supplier_verification_cases
    where organization_id = 'a2000000-0000-0000-0000-000000000002'), true);
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o2')::uuid, 'approve', 'Documents consistent', 'Business registration', false, 'high')$$,
  '22023', 'a documented risk reason (at least 10 characters) is required to declare high risk',
  'B: declaring high risk without a reason is refused');
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o2')::uuid, 'approve', 'Documents consistent', 'Business registration', false, 'high', 'too short')$$,
  '22023', 'a documented risk reason (at least 10 characters) is required to declare high risk',
  'B: a token risk reason is refused');
select is(public.review_supplier_verification(current_setting('luma.case_o2')::uuid, 'approve',
    'Documents consistent; declared high risk', 'Business registration', false, 'high', 'New trader with unusual order volume'),
  'awaiting_second_review', 'B: declared high risk waits for a second reviewer');
reset role;
select is((select risk_reason from public.supplier_verification_cases where id = current_setting('luma.case_o2')::uuid),
  'New trader with unusual order volume', 'B: the risk reason is stored on the case');
select is((select second_review_required from public.supplier_verification_cases where id = current_setting('luma.case_o2')::uuid),
  true, 'B: declared high risk makes the second review mandatory');
select is((select risk_reason from public.verification_decisions where case_id = current_setting('luma.case_o2')::uuid and decision = 'approve'),
  'New trader with unusual order volume', 'B: the decision record carries the risk reason');

-- ============================================ C. policy exceptions need a reason and a second reviewer
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('a2000000-0000-0000-0000-000000000003', array['a2000000-0000-0000-0000-000000000003/registration.pdf'])$$,
  'C: supplier 3 submits verification');
reset role;
do $$ begin
  perform set_config('luma.case_o3', (select id::text from public.supplier_verification_cases
    where organization_id = 'a2000000-0000-0000-0000-000000000003'), true);
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o3')::uuid, 'approve', 'ok', 'Trader evidence', true)$$,
  '22023', 'a documented reason (at least 10 characters) is required for a policy exception',
  'C: a policy exception without a documented reason is refused');
select is(public.review_supplier_verification(current_setting('luma.case_o3')::uuid, 'approve',
    'Exception: registration pending renewal, trader evidence accepted', 'Trader evidence', true),
  'awaiting_second_review', 'C: a policy exception needs a second reviewer');
reset role;
select is((select second_review_required from public.supplier_verification_cases where id = current_setting('luma.case_o3')::uuid),
  true, 'C: a policy exception makes the second review mandatory');
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000012","role":"authenticated","aal":"aal2"}';
select is(public.review_supplier_verification(current_setting('luma.case_o3')::uuid, 'approve', 'Independent check of the exception'),
  'approved', 'C: an independent reviewer completes the exception');

-- ============================================ D. rejected-to-approved needs a second reviewer
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000004","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('a2000000-0000-0000-0000-000000000004', array['a2000000-0000-0000-0000-000000000004/registration.pdf'])$$,
  'D: supplier 4 submits verification');
reset role;
do $$ begin
  perform set_config('luma.case_o4', (select id::text from public.supplier_verification_cases
    where organization_id = 'a2000000-0000-0000-0000-000000000004'), true);
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select is(public.review_supplier_verification(current_setting('luma.case_o4')::uuid, 'reject', 'Registration document is illegible'),
  'rejected', 'D: the case is rejected');
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o4')::uuid, 'approve', 'Changed my mind later', 'Business registration')$$,
  '55000', 'case is not open for review (status rejected)', 'D: a rejected case cannot be flipped to approved');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000004","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('a2000000-0000-0000-0000-000000000004', array['a2000000-0000-0000-0000-000000000004/registration.pdf'])$$,
  'D: the supplier resubmits after the rejection');
reset role;
do $$ begin
  perform set_config('luma.case_o4b', (select id::text from public.supplier_verification_cases
    where organization_id = 'a2000000-0000-0000-0000-000000000004' and status = 'pending'), true);
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select is(public.review_supplier_verification(current_setting('luma.case_o4b')::uuid, 'approve',
    'Resubmitted documents are valid', 'Business registration'),
  'awaiting_second_review', 'D: rejected-to-approved waits for a second reviewer');
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o4b')::uuid, 'approve', 'second approval by the same person')$$,
  '42501', 'a different reviewer must give the second approval', 'D: the first approver cannot approve again');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000013","role":"authenticated","aal":"aal2"}';
select is(public.review_supplier_verification(current_setting('luma.case_o4b')::uuid, 'approve', 'Independent check of the resubmission'),
  'approved', 'D: an independent reviewer completes the approval');
reset role;
select is((select second_review_required from public.supplier_verification_cases where id = current_setting('luma.case_o4b')::uuid),
  true, 'D: the requirement is recorded on the case');

-- ============================================ E. role escalation and unauthorized transitions
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000022","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(gen_random_uuid(), 'approve', 'finance officer attempt', 'x')$$,
  '42501', 'verification reviewer role (aal2) required', 'E: a finance officer cannot review');
select throws_ok(
  $$select public.flag_supplier_for_early_review(gen_random_uuid(), 'finance officer attempt')$$,
  '42501', 'verification reviewer role (aal2) required', 'E: a finance officer cannot flag');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.flag_supplier_for_early_review(gen_random_uuid(), 'short')$$,
  '22023', 'a documented reason (at least 10 characters) is required', 'E: an early-review flag needs a documented reason');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000041","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.flag_supplier_for_early_review(current_setting('luma.case_o3')::uuid, 'Member of the supplier flagging own case')$$,
  '42501', 'reviewer has a conflict of interest with this case', 'E: a reviewer who belongs to the supplier cannot flag its case');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal1"}';
select throws_ok(
  $$select public.review_supplier_verification(gen_random_uuid(), 'approve', 'no MFA attempt', 'x')$$,
  '42501', 'verification reviewer role (aal2) required', 'E: a reviewer without MFA cannot review');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000014","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(gen_random_uuid(), 'approve', 'revoked reviewer attempt', 'x')$$,
  '42501', 'verification reviewer role (aal2) required', 'E: a reviewer whose role was revoked cannot review');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000031","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(gen_random_uuid(), 'approve', 'no role attempt', 'x')$$,
  '42501', 'verification reviewer role (aal2) required', 'E: a user with no platform role cannot review');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000021","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(gen_random_uuid(), 'approve', 'platform admin attempt', 'x')$$,
  '42501', 'verification reviewer role (aal2) required', 'E: a platform admin is not automatically a reviewer');
select throws_ok(
  $$select public.grant_platform_role('a1000000-0000-0000-0000-000000000021', 'verification_reviewer')$$,
  '42501', 'platform roles cannot be granted to yourself', 'E: a platform admin cannot grant themselves a reviewer role');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.grant_platform_role('a1000000-0000-0000-0000-000000000011', 'platform_admin')$$,
  '42501', 'platform_admin role (aal2) required', 'E: a reviewer cannot escalate themselves to admin');
select throws_ok(
  $$select public.grant_platform_role('a1000000-0000-0000-0000-000000000031', 'verification_reviewer')$$,
  '42501', 'platform_admin role (aal2) required', 'E: a reviewer cannot grant roles to others');
select throws_ok(
  $$update public.supplier_verification_cases set status = 'approved'$$,
  '42501', 'permission denied for table supplier_verification_cases', 'E: clients cannot update cases directly');
select throws_ok(
  $$insert into public.verification_decisions(case_id, decision, decided_by, reason) values (gen_random_uuid(), 'approve', 'a1000000-0000-0000-0000-000000000011', 'forged decision record')$$,
  '42501', 'permission denied for table verification_decisions', 'E: clients cannot write decision records');

-- ============================================ F. my_platform_access(): the server tells the console
set local role anon;
select throws_ok($$select public.my_platform_access()$$,
  '42501', 'permission denied for function my_platform_access', 'F: anon cannot call the access contract');
set local role authenticated;
set local request.jwt.claims = '{"role":"authenticated","aal":"aal2"}';
select throws_ok($$select public.my_platform_access()$$,
  '28000', 'authentication required', 'F: no subject is refused');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000031","role":"authenticated","aal":"aal2"}';
select is(public.my_platform_access() -> 'roles', '[]'::jsonb, 'F: an ordinary user has no roles');
select is(public.my_platform_access() -> 'capabilities', '[]'::jsonb, 'F: an ordinary user has no capabilities');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select is(public.my_platform_access() -> 'roles', '["verification_reviewer"]'::jsonb, 'F: a reviewer sees their role');
select is(public.my_platform_access() -> 'capabilities', '["verification.review"]'::jsonb, 'F: a reviewer on MFA gets the review capability');
select is((public.my_platform_access() ->> 'mfa_satisfied')::boolean, true, 'F: an aal2 session is reported as MFA-satisfied');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000011","role":"authenticated","aal":"aal1"}';
select is(public.my_platform_access() -> 'roles', '["verification_reviewer"]'::jsonb, 'F: the role is listed so the console can ask for MFA');
select is(public.my_platform_access() -> 'capabilities', '[]'::jsonb, 'F: no capabilities without MFA');
select is((public.my_platform_access() ->> 'mfa_satisfied')::boolean, false, 'F: an aal1 session is not MFA-satisfied');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000021","role":"authenticated","aal":"aal2"}';
select is(public.my_platform_access() -> 'capabilities', '["audit.view", "roles.manage"]'::jsonb, 'F: an admin on MFA gets the admin capabilities');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000014","role":"authenticated","aal":"aal2"}';
select is(public.my_platform_access() -> 'roles', '[]'::jsonb, 'F: a revoked role is not listed');
set local request.jwt.claims = '{"sub":"a1000000-0000-0000-0000-000000000031","role":"authenticated","aal":"aal2","app_metadata":{"role":"platform_admin","roles":["platform_admin"]},"user_metadata":{"role":"platform_admin"}}';
select is(public.my_platform_access() -> 'roles', '[]'::jsonb, 'F: forged client metadata grants nothing');

select * from finish();
rollback;
