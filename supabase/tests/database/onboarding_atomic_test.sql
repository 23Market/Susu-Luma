-- Atomic organisation + owner onboarding (E7 Phase 2/3). Synthetic data only.
begin;
select plan(23);

insert into auth.users(id) values
  ('11111111-0000-0000-0000-000000000001'),
  ('11111111-0000-0000-0000-000000000002');

-- 1. Unauthenticated callers cannot onboard.
set local role anon;
select throws_ok(
  $$select public.create_organization_with_owner('Anon Org', 'Anon Org')$$,
  '42501', 'permission denied for function create_organization_with_owner',
  'anon cannot call the onboarding RPC');

-- 2. A token with no subject is rejected even with the authenticated role.
set local role authenticated;
set local request.jwt.claims = '{"role":"authenticated"}';
select throws_ok(
  $$select public.create_organization_with_owner('No Subject Org', 'No Subject Org')$$,
  '28000', 'authentication required', 'token without subject is rejected');

-- 3. Authenticated user creates an organisation.
set local request.jwt.claims = '{"sub":"11111111-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.create_organization_with_owner('Test Buyer Ltd', 'Test Buyer', 'buyer',
      'Western Area Urban', 'Freetown', 'Synthetic buyer', 'aaaaaaaa-0000-0000-0000-000000000001')$$,
  'authenticated user can onboard an organisation');

-- 4-6. Organisation, owner membership and audit event exist together.
reset role;
select is((select count(*)::int from public.organizations where legal_name = 'Test Buyer Ltd'), 1,
  'exactly one organisation created');
select is((select count(*)::int from public.organization_memberships m
           join public.organizations o on o.id = m.organization_id
           where o.legal_name = 'Test Buyer Ltd'
             and m.user_id = '11111111-0000-0000-0000-000000000001' and m.member_role = 'owner'), 1,
  'owner membership created in the same transaction');
select is((select count(*)::int from public.audit_events
           where action = 'organization.created' and actor_user_id = '11111111-0000-0000-0000-000000000001'), 1,
  'creation audit event written');

-- 7. created_by is taken from the verified token, never from client input.
select is((select created_by from public.organizations where legal_name = 'Test Buyer Ltd'),
  '11111111-0000-0000-0000-000000000001'::uuid, 'created_by comes from the token');

-- 8-9. Retrying with the same idempotency key returns the same organisation, no duplicates.
set local role authenticated;
select is(
  public.create_organization_with_owner('Test Buyer Ltd', 'Test Buyer', 'buyer', null, null, null,
    'aaaaaaaa-0000-0000-0000-000000000001'),
  (select id from public.organizations where legal_name = 'Test Buyer Ltd'),
  'same idempotency key returns the existing organisation');
reset role;
select is(
  (select count(*)::int from public.organizations where creation_key = 'aaaaaaaa-0000-0000-0000-000000000001'
     and created_by = '11111111-0000-0000-0000-000000000001')
  + (select count(*)::int from public.audit_events where action = 'organization.created'
     and actor_user_id = '11111111-0000-0000-0000-000000000001'),
  2, 'retry created no second organisation and no second audit event');

-- 10. The same key from another user is a different organisation (key is per creator).
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-0000-0000-0000-000000000002","role":"authenticated"}';
select lives_ok(
  $$select public.create_organization_with_owner('Other Buyer Ltd', 'Other Buyer', 'buyer', null, null, null,
      'aaaaaaaa-0000-0000-0000-000000000001')$$,
  'a different user can reuse the same key value');
reset role;
select is((select count(distinct id)::int from public.organizations
           where creation_key = 'aaaaaaaa-0000-0000-0000-000000000001'), 2,
  'idempotency keys do not collide across users');

-- 11-13. Invalid input is rejected and leaves nothing behind.
set local role authenticated;
select throws_ok(
  $$select public.create_organization_with_owner('Bad Type Ltd', 'Bad Type', 'wallet')$$,
  '22023', 'invalid organization_type', 'unknown organisation type rejected');
select throws_ok(
  $$select public.create_organization_with_owner('Long District Ltd', 'Long District', 'buyer', repeat('x', 121))$$,
  '22023', 'district, locality or description too long', 'oversized district rejected');
select throws_ok(
  $$select public.create_organization_with_owner('X', 'X', 'buyer')$$,
  '23514', null, 'too-short legal name rejected by table constraint');
reset role;
select is((select count(*)::int from public.organizations
           where legal_name in ('Bad Type Ltd', 'Long District Ltd', 'X')), 0,
  'failed onboarding leaves no organisation behind');

-- 14. Blank district is stored as null rather than an empty string.
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.create_organization_with_owner('Blank District Ltd', 'Blank District', 'business', '   ')$$,
  'blank district accepted');
reset role;
select is((select district from public.organizations where legal_name = 'Blank District Ltd'), null,
  'blank district normalised to null');

-- 16. A client cannot self-join another organisation by inserting a membership row.
set local role authenticated;
select throws_ok(
  $$insert into public.organization_memberships(organization_id, user_id, member_role)
    select id, '11111111-0000-0000-0000-000000000001', 'owner'
    from public.organizations where legal_name = 'Other Buyer Ltd'$$,
  '42501', 'permission denied for table organization_memberships',
  'client cannot insert membership rows');

-- 17. An organisation cannot be committed without an owner membership.
reset role;
select throws_ok(
  $$insert into public.organizations(legal_name, display_name, created_by)
    values ('Ownerless Ltd', 'Ownerless', '11111111-0000-0000-0000-000000000001');
    set constraints all immediate$$,
  '23514', null, 'organisation without an owner fails the deferred integrity check');

-- 18-19. The last owner cannot be removed or demoted.
select throws_ok(
  $$delete from public.organization_memberships m
    using public.organizations o
    where o.id = m.organization_id and o.legal_name = 'Test Buyer Ltd'$$,
  '23514', null, 'last owner cannot be deleted');
select throws_ok(
  $$update public.organization_memberships m set member_role = 'admin'
    from public.organizations o
    where o.id = m.organization_id and o.legal_name = 'Test Buyer Ltd'$$,
  '23514', null, 'last owner cannot be demoted');

-- 20. With a second owner present, ownership can change hands.
insert into public.organization_memberships(organization_id, user_id, member_role)
select id, '11111111-0000-0000-0000-000000000002', 'owner'
from public.organizations where legal_name = 'Test Buyer Ltd';
select lives_ok(
  $$update public.organization_memberships m set member_role = 'admin'
    from public.organizations o
    where o.id = m.organization_id and o.legal_name = 'Test Buyer Ltd'
      and m.user_id = '11111111-0000-0000-0000-000000000001'$$,
  'an owner can be demoted when another owner remains');

-- 21. Deleting an organisation still cascades to its memberships (guard does not block it).
select lives_ok(
  $$delete from public.organizations where legal_name = 'Test Buyer Ltd'$$,
  'organisation deletion cascades past the last-owner guard');

select * from finish();
rollback;
