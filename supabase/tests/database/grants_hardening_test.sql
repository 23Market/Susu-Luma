-- Least-privilege grants, function allow-lists and listing visibility. Synthetic data only.
-- The allow-list assertions are regression guards: any new public table, sequence or
-- function that is reachable by client roles fails this file until it is reviewed.
begin;
select plan(27);

insert into auth.users(id) values
  ('77777777-0000-0000-0000-000000000001'),  -- owner of Z
  ('77777777-0000-0000-0000-000000000002');  -- owner of Y
insert into public.organizations(id, legal_name, display_name, organization_type, created_by) values
  ('88888888-0000-0000-0000-000000000001', 'Synthetic Seller Z', 'Seller Z', 'supplier', '77777777-0000-0000-0000-000000000001'),
  ('88888888-0000-0000-0000-000000000002', 'Synthetic Seller Y', 'Seller Y', 'supplier', '77777777-0000-0000-0000-000000000002');
insert into public.organization_memberships(organization_id, user_id, member_role) values
  ('88888888-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000001', 'owner'),
  ('88888888-0000-0000-0000-000000000002', '77777777-0000-0000-0000-000000000002', 'owner');
insert into public.listings(id, organization_id, title, category, quantity_unit, status, published_at, created_by) values
  ('99999999-0000-0000-0000-000000000001', '88888888-0000-0000-0000-000000000001', 'Published cement', 'Construction', 'bag', 'published', now(), '77777777-0000-0000-0000-000000000001'),
  ('99999999-0000-0000-0000-000000000002', '88888888-0000-0000-0000-000000000001', 'Draft cement', 'Construction', 'bag', 'draft', null, '77777777-0000-0000-0000-000000000001');

-- ------------------------------------------------------------ structural guards
select is_empty(
  $$select tablename from pg_tables where schemaname = 'public' and not rowsecurity$$,
  'row level security is enabled on every public table');

select is_empty(
  $$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and c.relname <> 'listings'
      and (has_table_privilege('anon', c.oid, 'select,insert,update,delete,truncate,references,trigger')
           or has_any_column_privilege('anon', c.oid, 'select,insert,update,references'))$$,
  'anon holds no privilege on any public table except listing discovery');

select is_empty(
  $$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and c.relname <> 'listings'
      and has_any_column_privilege('authenticated', c.oid, 'insert,update,references')$$,
  'authenticated holds no write privilege on any public table except listing insert');

select is_empty(
  $$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and has_table_privilege('authenticated', c.oid, 'delete,truncate,trigger')$$,
  'authenticated can never delete or truncate any public table');

select set_eq(
  $$select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and has_table_privilege('authenticated', c.oid, 'select')$$,
  array['organizations', 'organization_memberships', 'audit_events'],
  'authenticated has whole-table select only where RLS policies were reviewed');

select is_empty(
  $$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'S'
      and (has_sequence_privilege('anon', c.oid, 'usage,select,update')
           or has_sequence_privilege('authenticated', c.oid, 'usage,select,update'))$$,
  'client roles hold no privilege on public sequences');

select is_empty(
  $$select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
      and p.proname <> 'supplier_is_verified'$$,
  'anon can execute only the verified-supplier check');

select set_eq(
  $$select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')$$,
  array['create_organization_with_owner', 'submit_supplier_verification', 'review_supplier_verification',
        'flag_supplier_for_early_review', 'reviewer_list_verification_cases', 'reviewer_list_verification_decisions',
        'authorize_evidence_access', 'supplier_is_verified', 'grant_platform_role', 'revoke_platform_role'],
  'authenticated can execute exactly the reviewed public RPCs');

select set_eq(
  $$select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and has_function_privilege('authenticated', p.oid, 'execute')$$,
  array['try_uuid', 'has_platform_role', 'is_org_member'],
  'authenticated can execute only the policy helpers in the private schema');

select is_empty(
  $$select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prosecdef
      and not coalesce(p.proconfig::text ilike '%search_path=%', false)$$,
  'every SECURITY DEFINER function pins its search_path');

-- ------------------------------------------------------------ anon, behaviourally
set local role anon;
select throws_ok($$select * from public.organizations$$, '42501', 'permission denied for table organizations',
  'anon cannot read organisations');
select throws_ok($$select * from public.organization_memberships$$, '42501', 'permission denied for table organization_memberships',
  'anon cannot read memberships');
select throws_ok($$select * from public.platform_roles$$, '42501', 'permission denied for table platform_roles',
  'anon cannot read platform roles');
select throws_ok($$select * from public.supplier_verification_cases$$, '42501', 'permission denied for table supplier_verification_cases',
  'anon cannot read verification cases');
select throws_ok($$select * from public.orders$$, '42501', 'permission denied for table orders',
  'anon cannot read orders');
select is((select count(*)::int from public.listings), 1, 'anon sees published listings only');
select throws_ok($$select created_by from public.listings$$, '42501', null,
  'anon cannot read which user created a listing');
select throws_ok($$select * from public.listings$$, '42501', null,
  'select * on listings is refused: clients must name the discovery columns');

-- --------------------------------------------------------- authenticated, behaviourally
set local role authenticated;
set local request.jwt.claims = '{"sub":"77777777-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}';
select is((select count(*)::int from public.listings where organization_id = '88888888-0000-0000-0000-000000000001'), 2,
  'a member sees the draft and published listings of the own organisation');
select throws_ok($$select created_by from public.listings$$, '42501', null,
  'members cannot read listing creators either');
select throws_ok($$update public.listings set status = 'published'$$, '42501', 'permission denied for table listings',
  'clients cannot publish by updating a listing');
select throws_ok($$delete from public.listings$$, '42501', 'permission denied for table listings',
  'clients cannot delete listings');
select throws_ok($$insert into public.orders(id) values (gen_random_uuid())$$, '42501', 'permission denied for table orders',
  'clients cannot create orders directly');
select throws_ok($$insert into public.quotes(id) values (gen_random_uuid())$$, '42501', 'permission denied for table quotes',
  'clients cannot create quotes directly');

set local request.jwt.claims = '{"sub":"77777777-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}';
select is((select count(*)::int from public.listings where organization_id = '88888888-0000-0000-0000-000000000001'), 1,
  'another tenant sees only the published listing, never the draft');
select is((select count(*)::int from public.organizations where id = '88888888-0000-0000-0000-000000000001'), 0,
  'another tenant cannot read the organisation');
select is((select count(*)::int from public.organization_memberships
           where organization_id = '88888888-0000-0000-0000-000000000001'), 0,
  'another tenant cannot read the membership roster');

select * from finish();
rollback;
