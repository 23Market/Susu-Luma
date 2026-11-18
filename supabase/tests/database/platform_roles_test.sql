-- Server-controlled platform roles and privilege-escalation denial. Synthetic data only.
begin;
select plan(20);

insert into auth.users(id) values
  ('22222222-0000-0000-0000-000000000001'),  -- platform admin
  ('22222222-0000-0000-0000-000000000002'),  -- verification reviewer
  ('22222222-0000-0000-0000-000000000003'),  -- ordinary user
  ('22222222-0000-0000-0000-000000000004');  -- grant target
insert into public.platform_roles(user_id, role) values
  ('22222222-0000-0000-0000-000000000001', 'platform_admin'),
  ('22222222-0000-0000-0000-000000000002', 'verification_reviewer');

-- 1. Anonymous callers cannot reach role administration.
set local role anon;
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'support_agent')$$,
  '42501', 'permission denied for function grant_platform_role', 'anon cannot grant roles');
select throws_ok(
  $$select private.has_platform_role('platform_admin')$$,
  '42501', null, 'anon cannot call the internal role check directly');

-- 3. An ordinary signed-in user cannot grant roles, even with aal2.
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'support_agent')$$,
  '42501', 'platform_admin role (aal2) required', 'ordinary user cannot grant roles');

-- 4. Client-controlled metadata claims never confer a platform role.
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2","app_metadata":{"role":"platform_admin","platform_role":"platform_admin"},"user_metadata":{"role":"platform_admin","is_admin":true}}';
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'support_agent')$$,
  '42501', 'platform_admin role (aal2) required', 'forged metadata claims grant nothing');

-- 5-6. A real admin without an MFA (aal2) session is refused.
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}';
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'support_agent')$$,
  '42501', 'platform_admin role (aal2) required', 'admin at aal1 is refused');
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'support_agent')$$,
  '42501', 'platform_admin role (aal2) required', 'admin with no aal claim is refused');

-- 7-9. An admin at aal2 can grant a role; the grant is recorded and audited.
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'verification_reviewer')$$,
  'admin at aal2 can grant a role');
reset role;
select is((select count(*)::int from public.platform_roles
           where user_id = '22222222-0000-0000-0000-000000000004'
             and role = 'verification_reviewer' and revoked_at is null
             and granted_by = '22222222-0000-0000-0000-000000000001'), 1,
  'role row recorded with the granting admin');
select is((select count(*)::int from public.audit_events
           where action = 'platform_role.granted' and actor_user_id = '22222222-0000-0000-0000-000000000001'), 1,
  'role grant audited');

-- 10-11. No self-grants and no unknown roles.
set local role authenticated;
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000001', 'finance_officer')$$,
  '42501', 'platform roles cannot be granted to yourself', 'admin cannot grant to self');
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'superuser')$$,
  '22023', 'unknown platform role', 'unknown role rejected');

-- 12-14. Clients have no direct table access to roles.
select throws_ok($$select * from public.platform_roles$$,
  '42501', 'permission denied for table platform_roles', 'clients cannot read the roles table');
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$insert into public.platform_roles(user_id, role) values ('22222222-0000-0000-0000-000000000003', 'platform_admin')$$,
  '42501', 'permission denied for table platform_roles', 'clients cannot insert themselves a role');
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$update public.platform_roles set revoked_at = null$$,
  '42501', 'permission denied for table platform_roles', 'even an admin cannot update the table directly');

-- 15-17. Revocation works, is recorded, and cannot target self or a missing role.
select lives_ok(
  $$select public.revoke_platform_role('22222222-0000-0000-0000-000000000004', 'verification_reviewer')$$,
  'admin can revoke a role');
reset role;
select isnt((select revoked_at from public.platform_roles
             where user_id = '22222222-0000-0000-0000-000000000004' and role = 'verification_reviewer'),
  null, 'revocation timestamp recorded');
set local role authenticated;
select throws_ok(
  $$select public.revoke_platform_role('22222222-0000-0000-0000-000000000004', 'verification_reviewer')$$,
  'P0002', 'no active role to revoke', 'revoking a missing role is an error');
select throws_ok(
  $$select public.revoke_platform_role('22222222-0000-0000-0000-000000000001', 'platform_admin')$$,
  '42501', 'platform roles cannot be revoked from yourself', 'admin cannot revoke own role');

-- 19. A reviewer is not an admin.
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'platform_admin')$$,
  '42501', 'platform_admin role (aal2) required', 'reviewer cannot escalate to admin');

-- 20. A revoked admin loses all admin powers immediately.
reset role;
update public.platform_roles set revoked_at = now()
where user_id = '22222222-0000-0000-0000-000000000001' and role = 'platform_admin';
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select throws_ok(
  $$select public.grant_platform_role('22222222-0000-0000-0000-000000000004', 'support_agent')$$,
  '42501', 'platform_admin role (aal2) required', 'revoked admin is refused');

select * from finish();
rollback;
