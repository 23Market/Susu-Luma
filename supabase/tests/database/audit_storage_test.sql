-- Audit-trail integrity and private evidence storage isolation. Synthetic data only.
begin;
select plan(29);

insert into auth.users(id) values
  ('55555555-0000-0000-0000-000000000001'),  -- platform admin
  ('55555555-0000-0000-0000-000000000002'),  -- supplier owner O1
  ('55555555-0000-0000-0000-000000000003'),  -- supplier owner O2
  ('55555555-0000-0000-0000-000000000004'),  -- verification reviewer
  ('55555555-0000-0000-0000-000000000005');  -- ordinary user
insert into public.organizations(id, legal_name, display_name, organization_type, created_by) values
  ('66666666-0000-0000-0000-000000000001', 'Synthetic Evidence One', 'Evidence One', 'supplier', '55555555-0000-0000-0000-000000000002'),
  ('66666666-0000-0000-0000-000000000002', 'Synthetic Evidence Two', 'Evidence Two', 'supplier', '55555555-0000-0000-0000-000000000003');
insert into public.organization_memberships(organization_id, user_id, member_role) values
  ('66666666-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000002', 'owner'),
  ('66666666-0000-0000-0000-000000000002', '55555555-0000-0000-0000-000000000003', 'owner');
insert into public.platform_roles(user_id, role) values
  ('55555555-0000-0000-0000-000000000001', 'platform_admin'),
  ('55555555-0000-0000-0000-000000000004', 'verification_reviewer');
insert into public.audit_events(action, entity_type, reason) values ('test.seed', 'test', 'original');
insert into storage.buckets(id, name, public) values ('unrelated-bucket', 'unrelated-bucket', false);
insert into storage.objects(bucket_id, name) values
  ('verification-evidence', '66666666-0000-0000-0000-000000000001/registration.pdf');

-- ------------------------------------------------------------- audit integrity
select throws_ok($$update public.audit_events set reason = 'tampered'$$,
  '42501', 'UPDATE on audit_events is not allowed: the table is append-only', 'audit rows cannot be edited, even by the table owner');
select throws_ok($$delete from public.audit_events$$,
  '42501', 'DELETE on audit_events is not allowed: the table is append-only', 'audit rows cannot be deleted');
select throws_ok($$truncate public.audit_events$$,
  '42501', 'TRUNCATE on audit_events is not allowed: the table is append-only', 'audit table cannot be truncated');

set local role authenticated;
set local request.jwt.claims = '{"sub":"55555555-0000-0000-0000-000000000005","role":"authenticated","aal":"aal2"}';
select throws_ok($$insert into public.audit_events(action, entity_type) values ('forged', 'test')$$,
  '42501', 'permission denied for table audit_events', 'clients cannot forge audit events');
select throws_ok($$update public.audit_events set reason = 'x'$$,
  '42501', 'permission denied for table audit_events', 'clients cannot update audit events');
select is((select count(*)::int from public.audit_events), 0, 'ordinary users read no audit rows');

set local request.jwt.claims = '{"sub":"55555555-0000-0000-0000-000000000004","role":"authenticated","aal":"aal2"}';
select is((select count(*)::int from public.audit_events), 0, 'a verification reviewer is not an audit reader');

set local request.jwt.claims = '{"sub":"55555555-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}';
select is((select count(*)::int from public.audit_events), 0, 'platform admin without MFA reads no audit rows');
set local request.jwt.claims = '{"sub":"55555555-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select cmp_ok((select count(*)::int from public.audit_events), '>=', 1, 'platform admin at aal2 can read the audit trail');

set local role anon;
select throws_ok($$select * from public.audit_events$$,
  '42501', 'permission denied for table audit_events', 'anonymous users cannot read audit events');

-- ------------------------------------------------------- private evidence bucket
reset role;
select is((select public from storage.buckets where id = 'verification-evidence'), false,
  'evidence bucket is private');
select is((select allowed_mime_types from storage.buckets where id = 'verification-evidence'),
  array['application/pdf', 'image/jpeg', 'image/png'], 'evidence bucket only accepts PDF, JPEG and PNG');
select is((select file_size_limit from storage.buckets where id = 'verification-evidence'), 10485760::bigint,
  'evidence bucket limits files to 10 MiB');

set local role authenticated;
set local request.jwt.claims = '{"sub":"55555555-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select lives_ok(
  $$insert into storage.objects(bucket_id, name) values ('verification-evidence', '66666666-0000-0000-0000-000000000001/id-card.png')$$,
  'owner can upload evidence into the own organisation folder');
select throws_ok(
  $$insert into storage.objects(bucket_id, name) values ('verification-evidence', '66666666-0000-0000-0000-000000000002/planted.pdf')$$,
  '42501', 'new row violates row-level security policy for table "objects"', 'cannot upload into another organisation folder');
select throws_ok(
  $$insert into storage.objects(bucket_id, name) values ('verification-evidence', 'not-a-uuid/planted.pdf')$$,
  '42501', 'new row violates row-level security policy for table "objects"', 'cannot upload into a folder that is not an organisation id');
select throws_ok(
  $$insert into storage.objects(bucket_id, name) values ('verification-evidence', '66666666-0000-0000-0000-000000000001/nested/planted.pdf')$$,
  '42501', 'new row violates row-level security policy for table "objects"', 'nested folders are refused');
select throws_ok(
  $$insert into storage.objects(bucket_id, name) values ('verification-evidence', '../66666666-0000-0000-0000-000000000002/planted.pdf')$$,
  '42501', 'new row violates row-level security policy for table "objects"', 'path traversal upload refused');
select throws_ok(
  $$insert into storage.objects(bucket_id, name) values ('unrelated-bucket', '66666666-0000-0000-0000-000000000001/planted.pdf')$$,
  '42501', 'new row violates row-level security policy for table "objects"', 'no policy opens any other bucket');
select cmp_ok((select count(*)::int from storage.objects where bucket_id = 'verification-evidence'), '=', 2,
  'owner reads own evidence only');
select lives_ok($$update storage.objects set name = name || '.x' where bucket_id = 'verification-evidence'$$,
  'rename attempt runs but matches no row (no update policy)');
select is((select count(*)::int from storage.objects where name like '%.x'), 0,
  'uploaded evidence cannot be renamed or replaced');
select lives_ok($$delete from storage.objects where bucket_id = 'verification-evidence'$$,
  'delete attempt runs but matches no row (no delete policy)');
select cmp_ok((select count(*)::int from storage.objects where bucket_id = 'verification-evidence'), '=', 2,
  'uploaded evidence cannot be deleted by the client');

set local request.jwt.claims = '{"sub":"55555555-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}';
select is((select count(*)::int from storage.objects
           where name like '66666666-0000-0000-0000-000000000001/%'), 0,
  'another tenant cannot read the evidence');
set local request.jwt.claims = '{"sub":"55555555-0000-0000-0000-000000000004","role":"authenticated","aal":"aal2"}';
select is((select count(*)::int from storage.objects where bucket_id = 'verification-evidence'), 0,
  'reviewers have no direct bucket access (they go through authorize_evidence_access)');
set local request.jwt.claims = '{"sub":"55555555-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select is((select count(*)::int from storage.objects where bucket_id = 'verification-evidence'), 0,
  'platform admins have no direct bucket access either');
set local role anon;
select throws_ok(
  $$insert into storage.objects(bucket_id, name) values ('verification-evidence', '66666666-0000-0000-0000-000000000001/anon.pdf')$$,
  '42501', 'new row violates row-level security policy for table "objects"', 'anonymous upload refused');
select is((select count(*)::int from storage.objects where bucket_id = 'verification-evidence'), 0,
  'anonymous users read no evidence');

select * from finish();
rollback;
