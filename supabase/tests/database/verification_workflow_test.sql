-- Supplier verification workflow: authorisation, no self-approval, second reviewer,
-- immutable decision history, expiry and cross-tenant isolation. Synthetic data only.
--
-- Fixed identities (all synthetic):
--   S1/S2/S3 supplier owners of O1/O2/O3   B1 buyer owner of OB   X1 outsider
--   M1 staff member of O1 who also holds a reviewer role (conflict of interest)
--   RV1/RV2/RV3 verification reviewers      FO finance officer (no verification role)
begin;
select plan(68);

insert into auth.users(id) values
  ('33333333-0000-0000-0000-000000000001'), ('33333333-0000-0000-0000-000000000002'),
  ('33333333-0000-0000-0000-000000000003'), ('33333333-0000-0000-0000-000000000004'),
  ('33333333-0000-0000-0000-000000000005'), ('33333333-0000-0000-0000-000000000006'),
  ('33333333-0000-0000-0000-000000000011'), ('33333333-0000-0000-0000-000000000012'),
  ('33333333-0000-0000-0000-000000000013'), ('33333333-0000-0000-0000-000000000021');
insert into public.organizations(id, legal_name, display_name, organization_type, created_by) values
  ('44444444-0000-0000-0000-000000000001', 'Synthetic Supplier One', 'Supplier One', 'supplier', '33333333-0000-0000-0000-000000000001'),
  ('44444444-0000-0000-0000-000000000002', 'Synthetic Supplier Two', 'Supplier Two', 'supplier', '33333333-0000-0000-0000-000000000002'),
  ('44444444-0000-0000-0000-000000000003', 'Synthetic Supplier Three', 'Supplier Three', 'supplier', '33333333-0000-0000-0000-000000000003'),
  ('44444444-0000-0000-0000-000000000004', 'Synthetic Buyer Four', 'Buyer Four', 'buyer', '33333333-0000-0000-0000-000000000004');
insert into public.organization_memberships(organization_id, user_id, member_role) values
  ('44444444-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'owner'),
  ('44444444-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000006', 'staff'),
  ('44444444-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000002', 'owner'),
  ('44444444-0000-0000-0000-000000000003', '33333333-0000-0000-0000-000000000003', 'owner'),
  ('44444444-0000-0000-0000-000000000004', '33333333-0000-0000-0000-000000000004', 'owner');
insert into public.platform_roles(user_id, role) values
  ('33333333-0000-0000-0000-000000000011', 'verification_reviewer'),
  ('33333333-0000-0000-0000-000000000012', 'verification_reviewer'),
  ('33333333-0000-0000-0000-000000000013', 'verification_reviewer'),
  ('33333333-0000-0000-0000-000000000001', 'verification_reviewer'),
  ('33333333-0000-0000-0000-000000000006', 'verification_reviewer'),
  ('33333333-0000-0000-0000-000000000021', 'finance_officer');
insert into storage.objects(bucket_id, name) values
  ('verification-evidence', '44444444-0000-0000-0000-000000000001/registration.pdf'),
  ('verification-evidence', '44444444-0000-0000-0000-000000000002/registration.pdf'),
  ('verification-evidence', '44444444-0000-0000-0000-000000000003/registration.pdf'),
  ('verification-evidence', '44444444-0000-0000-0000-000000000004/registration.pdf');

-- ---------------------------------------------------------------- submission
set local role anon;
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array['44444444-0000-0000-0000-000000000001/registration.pdf'])$$,
  '42501', 'permission denied for function submit_supplier_verification', 'anon cannot submit verification');

set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000005","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array['44444444-0000-0000-0000-000000000001/registration.pdf'])$$,
  '42501', 'not allowed to submit verification for this organization', 'outsider cannot submit for an organisation');

set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array['44444444-0000-0000-0000-000000000001/registration.pdf'])$$,
  '42501', 'not allowed to submit verification for this organization', 'another tenant cannot submit for O1');

set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array['44444444-0000-0000-0000-000000000002/registration.pdf'])$$,
  '22023', 'evidence path is outside the organization folder', 'evidence from another tenant folder rejected');
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array['44444444-0000-0000-0000-000000000001/../44444444-0000-0000-0000-000000000002/registration.pdf'])$$,
  '22023', 'evidence path is outside the organization folder', 'path traversal rejected');
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array['44444444-0000-0000-0000-000000000001/missing.pdf'])$$,
  '22023', 'evidence file has not been uploaded', 'evidence that was never uploaded rejected');
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array[]::text[])$$,
  '22023', 'between 1 and 20 evidence files are required', 'empty evidence set rejected');

set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000004","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000004', array['44444444-0000-0000-0000-000000000004/registration.pdf'])$$,
  '22023', 'only supplier or business organizations can be verified', 'buyer organisation cannot be verified as supplier');

set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array['44444444-0000-0000-0000-000000000001/registration.pdf'])$$,
  'owner can submit verification for own organisation');
select throws_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000001', array['44444444-0000-0000-0000-000000000001/registration.pdf'])$$,
  '23505', null, 'duplicate open submission rejected');

reset role;
do $$ begin
  perform set_config('luma.case_o1', (select id::text from public.supplier_verification_cases
    where organization_id = '44444444-0000-0000-0000-000000000001'), true);
end $$;
select is((select count(*)::int from public.supplier_verification_cases
           where organization_id = '44444444-0000-0000-0000-000000000001' and status = 'pending'
             and created_by = '33333333-0000-0000-0000-000000000001'), 1,
  'exactly one pending case, created by the submitter');
select is((select count(*)::int from public.audit_events
           where action = 'verification.submitted' and entity_id = current_setting('luma.case_o1')::uuid), 1,
  'submission audited');

-- Tenant isolation on reads and on sensitive columns.
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select is((select count(*)::int from public.supplier_verification_cases
           where organization_id = '44444444-0000-0000-0000-000000000001'), 0,
  'another tenant cannot see the case');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select is((select count(*)::int from public.supplier_verification_cases
           where organization_id = '44444444-0000-0000-0000-000000000001'), 1,
  'owner can see own case status');
select throws_ok($$select reviewer_id from public.supplier_verification_cases$$,
  '42501', null, 'reviewer identity is hidden from the organisation');
select throws_ok($$update public.supplier_verification_cases set status = 'approved'$$,
  '42501', 'permission denied for table supplier_verification_cases', 'client cannot change case status directly');
select throws_ok(
  $$insert into public.verification_decisions(case_id, decision, decided_by, reason)
    values (current_setting('luma.case_o1')::uuid, 'approve', auth.uid(), 'self approve')$$,
  '42501', 'permission denied for table verification_decisions', 'client cannot write decisions directly');

-- ------------------------------------------------ reviewer authorisation / SoD
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000021","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'ok', 'Business registration')$$,
  '42501', 'verification reviewer role (aal2) required', 'finance officer cannot review verification');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal1"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'ok', 'Business registration')$$,
  '42501', 'verification reviewer role (aal2) required', 'reviewer without MFA session is refused');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000005","role":"authenticated","aal":"aal2","app_metadata":{"role":"verification_reviewer"},"user_metadata":{"role":"verification_reviewer"}}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'ok', 'Business registration')$$,
  '42501', 'verification reviewer role (aal2) required', 'forged metadata cannot make a reviewer');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'ok', 'Business registration')$$,
  '42501', 'reviewer has a conflict of interest with this case', 'submitter cannot approve own case (self-approval)');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000006","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'ok', 'Business registration')$$,
  '42501', 'reviewer has a conflict of interest with this case', 'member of the supplier organisation cannot approve');

set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'maybe', 'unsure')$$,
  '22023', 'invalid decision', 'unknown decision rejected');
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', '   ', 'Business registration')$$,
  '22023', 'a decision reason is required', 'decision without a reason rejected');
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'Looks fine')$$,
  '22023', 'approval must state what was verified', 'approval without a verification scope rejected');

-- ---------------------------------------- standard-risk approval (single reviewer)
select is(
  public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve',
    'Registration certificate matches trading name', 'Business registration and owner identity'),
  'approved', 'standard-risk case approved by one independent reviewer');
reset role;
select is((select expires_at from public.supplier_verification_cases where id = current_setting('luma.case_o1')::uuid),
  now() + interval '12 months', 'verification expires after 12 months');
select is((select reviewer_id from public.supplier_verification_cases where id = current_setting('luma.case_o1')::uuid),
  '33333333-0000-0000-0000-000000000011'::uuid, 'deciding reviewer recorded');
set local role anon;
select is(public.supplier_is_verified('44444444-0000-0000-0000-000000000001'), true,
  'supplier reads as verified only after approval');
reset role;
select is((select count(*)::int from public.verification_decisions
           where case_id = current_setting('luma.case_o1')::uuid
             and decided_by = '33333333-0000-0000-0000-000000000011' and not is_second_review), 1,
  'decision recorded in history');
select throws_ok($$update public.verification_decisions set reason = 'tampered'$$,
  '42501', 'UPDATE on verification_decisions is not allowed: the table is append-only', 'decision history cannot be edited');
select throws_ok($$delete from public.verification_decisions$$,
  '42501', 'DELETE on verification_decisions is not allowed: the table is append-only', 'decision history cannot be deleted');
select throws_ok($$truncate public.verification_decisions$$,
  '42501', 'TRUNCATE on verification_decisions is not allowed: the table is append-only', 'decision history cannot be truncated');
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000012","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'reject', 'changed mind')$$,
  '55000', 'case is not open for review (status approved)', 'a decided case cannot be decided again');

-- ----------------------- high risk: independent second reviewer, no self second-approval
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000002', array['44444444-0000-0000-0000-000000000002/registration.pdf'])$$,
  'second supplier submits verification');
reset role;
do $$ begin
  perform set_config('luma.case_o2', (select id::text from public.supplier_verification_cases
    where organization_id = '44444444-0000-0000-0000-000000000002'), true);
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select is(
  public.review_supplier_verification(current_setting('luma.case_o2')::uuid, 'approve',
    'Documents consistent; flagged high risk', 'Business registration', false, 'high'),
  'awaiting_second_review', 'high-risk approval waits for a second reviewer');
set local role anon;
select is(public.supplier_is_verified('44444444-0000-0000-0000-000000000002'), false,
  'not verified while awaiting second review');
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o2')::uuid, 'approve', 'approving again')$$,
  '42501', 'a different reviewer must give the second approval', 'first reviewer cannot give the second approval');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000012","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.review_supplier_verification(current_setting('luma.case_o2')::uuid, 'request_more_information', 'more please')$$,
  '22023', 'second review can only approve or reject', 'second review cannot loop back');
select is(
  public.review_supplier_verification(current_setting('luma.case_o2')::uuid, 'approve', 'Independent check agrees'),
  'approved', 'independent second reviewer completes approval');
reset role;
select is((select count(distinct decided_by)::int from public.verification_decisions
           where case_id = current_setting('luma.case_o2')::uuid), 2,
  'two distinct reviewers recorded');
select is((select count(*)::int from public.audit_events
           where entity_id = current_setting('luma.case_o2')::uuid
             and action in ('verification.first_approval', 'verification.approved')), 2,
  'both approval steps audited');
set local role anon;
select is(public.supplier_is_verified('44444444-0000-0000-0000-000000000002'), true,
  'verified after the second reviewer approves');

-- ------------------------------- rejected-to-approved requires a second reviewer
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000003', array['44444444-0000-0000-0000-000000000003/registration.pdf'])$$,
  'third supplier submits verification');
reset role;
do $$ begin
  perform set_config('luma.case_o3a', (select id::text from public.supplier_verification_cases
    where organization_id = '44444444-0000-0000-0000-000000000003'), true);
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select is(
  public.review_supplier_verification(current_setting('luma.case_o3a')::uuid, 'reject', 'Registration number not found'),
  'rejected', 'case rejected with a recorded reason');
set local role anon;
select is(public.supplier_is_verified('44444444-0000-0000-0000-000000000003'), false, 'rejected supplier is not verified');
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.submit_supplier_verification('44444444-0000-0000-0000-000000000003', array['44444444-0000-0000-0000-000000000003/registration.pdf'])$$,
  'supplier can resubmit after a rejection');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select is(
  public.review_supplier_verification(
    (select id from public.reviewer_list_verification_cases('pending') where organization_id = '44444444-0000-0000-0000-000000000003'),
    'approve', 'New certificate supplied', 'Business registration'),
  'awaiting_second_review', 'rejected-to-approved needs a second reviewer');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000013","role":"authenticated","aal":"aal2"}';
select is(
  public.review_supplier_verification(
    (select id from public.reviewer_list_verification_cases('awaiting_second_review') where organization_id = '44444444-0000-0000-0000-000000000003'),
    'approve', 'Second check confirms the new certificate'),
  'approved', 'second reviewer completes rejected-to-approved decision');

-- ---------------------------------------------------- reviewer reads and evidence
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select throws_ok($$select * from public.reviewer_list_verification_cases()$$,
  '42501', 'verification reviewer role (aal2) required', 'supplier cannot list review cases');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal1"}';
select throws_ok($$select * from public.reviewer_list_verification_cases()$$,
  '42501', 'verification reviewer role (aal2) required', 'reviewer without MFA cannot list cases');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select cmp_ok((select count(*)::int from public.reviewer_list_verification_cases()), '>=', 4,
  'reviewer can list all cases');
select is((select count(*)::int from public.reviewer_list_verification_decisions(current_setting('luma.case_o2')::uuid)), 2,
  'reviewer can read the decision history of a case');
select is(public.authorize_evidence_access(current_setting('luma.case_o2')::uuid,
    '44444444-0000-0000-0000-000000000002/registration.pdf'), true,
  'reviewer is authorised to open evidence that belongs to the case');
select throws_ok(
  $$select public.authorize_evidence_access(current_setting('luma.case_o2')::uuid, '44444444-0000-0000-0000-000000000001/registration.pdf')$$,
  '42501', 'evidence file is not part of this case', 'evidence from another case is refused');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.authorize_evidence_access(current_setting('luma.case_o1')::uuid, '44444444-0000-0000-0000-000000000001/registration.pdf')$$,
  '42501', 'reviewer has a conflict of interest with this case', 'a conflicted user cannot open own evidence as reviewer');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.authorize_evidence_access(current_setting('luma.case_o2')::uuid, '44444444-0000-0000-0000-000000000002/registration.pdf')$$,
  '42501', 'verification reviewer role (aal2) required', 'supplier cannot use the reviewer evidence path');
reset role;
select is((select count(*)::int from public.audit_events
           where action = 'verification.evidence_accessed' and entity_id = current_setting('luma.case_o2')::uuid), 1,
  'evidence access audited');

-- ----------------------------- early risk-triggered review and re-verification
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000012","role":"authenticated","aal":"aal2"}';
select is(public.flag_supplier_for_early_review(current_setting('luma.case_o1')::uuid, 'Trading licence reported revoked'),
  'in_review', 'reviewer can pull a verification back for early review');
set local role anon;
select is(public.supplier_is_verified('44444444-0000-0000-0000-000000000001'), false,
  'flagged supplier stops reading as verified immediately');
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000012","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.flag_supplier_for_early_review(current_setting('luma.case_o1')::uuid, 'again')$$,
  '55000', 'only an approved case can be flagged (status in_review)', 'only approved cases can be flagged');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select is(public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve',
    'Licence reinstated, documents re-checked', 'Business registration and licence'),
  'awaiting_second_review', 're-approval after a risk trigger needs a second reviewer');
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000013","role":"authenticated","aal":"aal2"}';
select is(public.review_supplier_verification(current_setting('luma.case_o1')::uuid, 'approve', 'Independent confirmation'),
  'approved', 're-verification completes with an independent reviewer');

-- ---------------------------------------------------------------- expiry
reset role;
update public.supplier_verification_cases set expires_at = now() - interval '1 day'
where organization_id = '44444444-0000-0000-0000-000000000003' and status = 'approved';
set local role anon;
select is(public.supplier_is_verified('44444444-0000-0000-0000-000000000003'), false,
  'lapsed approval stops reading as verified even before the expiry job runs');
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-0000-0000-0000-000000000011","role":"authenticated","aal":"aal2"}';
select throws_ok($$select public.expire_lapsed_verifications()$$,
  '42501', 'permission denied for function expire_lapsed_verifications', 'clients cannot run the expiry job');
set local role service_role;
select is(public.expire_lapsed_verifications(), 1, 'expiry job expires exactly the lapsed case');
reset role;
select is((select count(*)::int from public.supplier_verification_cases
           where organization_id = '44444444-0000-0000-0000-000000000003' and status = 'expired'), 1,
  'lapsed case stored as expired');
select is((select count(*)::int from public.audit_events where action = 'verification.expired'), 1,
  'expiry audited');

select * from finish();
rollback;
