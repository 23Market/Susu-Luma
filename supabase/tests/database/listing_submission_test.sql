begin;
select plan(6);

insert into auth.users(id) values ('10000000-0000-0000-0000-000000000001');
insert into public.organizations(id, legal_name, display_name, created_by)
values ('20000000-0000-0000-0000-000000000001', 'Synthetic seller', 'Synthetic seller',
  '10000000-0000-0000-0000-000000000001');
insert into public.organization_memberships(organization_id, user_id, member_role)
values ('20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001', 'owner');

set local role authenticated;
set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok($$insert into public.listings(organization_id,title,category,quantity_unit,created_by)
values ('20000000-0000-0000-0000-000000000001','Draft cement','Construction','bag',auth.uid())$$,
  'Owner can create a draft');
select lives_ok($$insert into public.listings(organization_id,title,category,quantity_unit,status,created_by)
values ('20000000-0000-0000-0000-000000000001','Review cement','Construction','bag','pending_review',auth.uid())$$,
  'Owner can submit for review');
select throws_ok($$insert into public.listings(organization_id,title,category,quantity_unit,status,created_by)
values ('20000000-0000-0000-0000-000000000001','Bypass cement','Construction','bag','published',auth.uid())$$,
  '42501', 'new row violates row-level security policy for table "listings"', 'Direct publication denied');
select throws_ok($$insert into public.listings(organization_id,title,category,quantity_unit,published_at,created_by)
values ('20000000-0000-0000-0000-000000000001','Dated cement','Construction','bag',now(),auth.uid())$$,
  '42501', 'new row violates row-level security policy for table "listings"', 'Client publication timestamp denied');
select throws_ok($$insert into public.organizations(legal_name,display_name,created_by)
values ('Orphan organization','Orphan organization',auth.uid())$$,
  '42501', 'new row violates row-level security policy for table "organizations"', 'Non-atomic onboarding denied');

set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok($$insert into public.listings(organization_id,title,category,quantity_unit,created_by)
values ('20000000-0000-0000-0000-000000000001','Unrelated cement','Construction','bag',auth.uid())$$,
  '42501', 'new row violates row-level security policy for table "listings"', 'Unrelated user cannot create supplier listings');

select * from finish();
rollback;
