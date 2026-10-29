begin;

select plan(16);

select has_table('public', 'supplier_subscriptions', 'supplier subscriptions exist');
select has_table('public', 'revenue_events', 'revenue events exist');
select has_table('public', 'support_cases', 'support cases exist');

select has_function(
  'public',
  'admin_dashboard_snapshot_for',
  array['uuid'],
  'the internal dashboard snapshot exists'
);

select ok(
  not has_function_privilege(
    'anon', 'public.admin_dashboard_snapshot_for(uuid)', 'execute'
  ),
  'anonymous clients cannot execute the internal dashboard snapshot'
);

select ok(
  has_function_privilege(
    'service_role', 'public.admin_dashboard_snapshot_for(uuid)', 'execute'
  ),
  'the web authentication service can execute the internal snapshot'
);

select ok(
  has_function_privilege(
    'authenticated', 'public.admin_dashboard_snapshot()', 'execute'
  ),
  'authenticated native clients can call the AAL2 dashboard wrapper'
);

select ok(
  not has_table_privilege('authenticated', 'public.revenue_events', 'select'),
  'authenticated clients cannot read revenue rows directly'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '20000000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'dashboard-test@example.invalid',
  'not-a-real-password', now(), now(), now()
);

insert into public.platform_admins (user_id)
values ('20000000-0000-0000-0000-000000000001');

insert into public.organizations (
  id, legal_name, display_name, district, created_by
) values (
  '20000000-0000-0000-0000-000000000002',
  'Kono Trade Limited', 'Kono Trade', 'Kono',
  '20000000-0000-0000-0000-000000000001'
);

insert into public.supplier_verification_cases (
  id, organization_id, verification_scope, created_by
) values (
  '20000000-0000-0000-0000-000000000003',
  '20000000-0000-0000-0000-000000000002',
  'Business identity',
  '20000000-0000-0000-0000-000000000001'
);

insert into public.listings (
  id, organization_id, title, category, quantity_unit, status, created_by
) values (
  '20000000-0000-0000-0000-000000000004',
  '20000000-0000-0000-0000-000000000002',
  'Local rice', 'Food', 'bag', 'pending_review',
  '20000000-0000-0000-0000-000000000001'
);

insert into public.support_cases (
  id, organization_id, priority, category, subject, opened_by
) values (
  '20000000-0000-0000-0000-000000000005',
  '20000000-0000-0000-0000-000000000002',
  'high', 'Listing', 'Listing review is delayed',
  '20000000-0000-0000-0000-000000000001'
);

insert into public.revenue_events (
  organization_id, stream, status, gross_amount
) values (
  '20000000-0000-0000-0000-000000000002',
  'subscription', 'recognized', 200
);

select is(
  (public.admin_dashboard_snapshot_for(
    '20000000-0000-0000-0000-000000000001'
  ) #>> '{overview,monthlyRevenue}')::numeric,
  200::numeric,
  'the snapshot reports recognized monthly revenue'
);

select is(
  public.admin_dashboard_snapshot_for(
    '20000000-0000-0000-0000-000000000001'
  ) #>> '{suppliers,verificationQueue,0,supplier}',
  'Kono Trade',
  'the snapshot includes the supplier verification queue'
);

select public.admin_review_supplier_for(
  '20000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000003',
  'approved',
  'Evidence confirmed'
);

select is(
  (select status from public.supplier_verification_cases
   where id = '20000000-0000-0000-0000-000000000003'),
  'approved',
  'supplier review updates the verification case'
);

select is(
  (select count(*)::integer from public.audit_events
   where entity_id = '20000000-0000-0000-0000-000000000003'),
  1,
  'supplier review creates an audit event'
);

select public.admin_review_listing_for(
  '20000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000004',
  'published', null
);

select is(
  (select status::text from public.listings
   where id = '20000000-0000-0000-0000-000000000004'),
  'published',
  'listing moderation publishes an approved listing'
);

select public.admin_resolve_support_case_for(
  '20000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000005',
  'Supplier was contacted and the review completed'
);

select is(
  (select status from public.support_cases
   where id = '20000000-0000-0000-0000-000000000005'),
  'resolved',
  'support resolution closes the case'
);

select is(
  (select resolution_note from public.support_cases
   where id = '20000000-0000-0000-0000-000000000005'),
  'Supplier was contacted and the review completed',
  'support resolution retains the administrator note'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',
  true
);

select ok(
  public.admin_dashboard_snapshot() ? 'overview',
  'an AAL2 platform administrator can use the native wrapper'
);

select * from finish();
rollback;
