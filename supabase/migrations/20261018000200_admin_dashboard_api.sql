-- Live administration and business-model reporting. All exposed operations are
-- server-authorized; the underlying commercial and support tables have no
-- client policies.

create table public.supplier_subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  plan_code text not null check (plan_code in ('basic', 'verified', 'pro', 'enterprise')),
  status text not null check (status in ('trialing', 'active', 'past_due', 'cancelled', 'expired')),
  monthly_amount numeric(18,2) not null default 0 check (monthly_amount >= 0),
  currency_code text not null default 'SLE' check (currency_code ~ '^[A-Z]{3}$'),
  started_at timestamptz not null default now(),
  current_period_ends_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index supplier_subscriptions_one_current_idx
  on public.supplier_subscriptions (organization_id)
  where status in ('trialing', 'active', 'past_due');

create table public.revenue_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  stream text not null check (stream in (
    'subscription', 'qualified_rfq', 'featured_placement', 'enterprise_service'
  )),
  status text not null default 'pending' check (status in ('pending', 'recognized', 'reversed')),
  gross_amount numeric(18,2) not null check (gross_amount >= 0),
  currency_code text not null default 'SLE' check (currency_code ~ '^[A-Z]{3}$'),
  external_reference text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index revenue_events_reporting_idx
  on public.revenue_events (status, currency_code, occurred_at desc);

create table public.support_cases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  category text not null,
  subject text not null check (length(trim(subject)) between 3 and 180),
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  assigned_to uuid references auth.users(id) on delete set null,
  opened_by uuid not null references auth.users(id) on delete restrict,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index support_cases_queue_idx
  on public.support_cases (status, priority, created_at);

alter table public.supplier_subscriptions enable row level security;
alter table public.revenue_events enable row level security;
alter table public.support_cases enable row level security;

create or replace function public.admin_dashboard_snapshot_for(p_actor_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  month_start timestamptz := date_trunc('month', now());
  qualified_rfqs integer;
  month_orders integer;
  month_revenue numeric(18,2);
  month_gmv numeric(18,2);
begin
  if not exists (
    select 1 from public.platform_admins administrator
    where administrator.user_id = p_actor_user_id
  ) then
    raise exception 'platform administrator required' using errcode = '42501';
  end if;

  select count(*)::integer into qualified_rfqs
  from public.rfqs
  where status in ('submitted', 'open', 'quoted', 'accepted')
    and coalesce(submitted_at, created_at) >= month_start;

  select count(*)::integer into month_orders
  from public.orders where created_at >= month_start;

  select coalesce(sum(gross_amount), 0) into month_revenue
  from public.revenue_events
  where status = 'recognized' and currency_code = 'SLE'
    and occurred_at >= month_start;

  select coalesce(sum(
    case
      when accepted_quote_snapshot->>'total_amount' ~ '^[0-9]+([.][0-9]+)?$'
        then (accepted_quote_snapshot->>'total_amount')::numeric
      else 0
    end
  ), 0) into month_gmv
  from public.orders where created_at >= month_start;

  return jsonb_build_object(
    'generatedAt', now(),
    'overview', jsonb_build_object(
      'monthlyRevenue', month_revenue,
      'marketplaceGmv', month_gmv,
      'qualifiedRfqs', qualified_rfqs,
      'conversionRate', case when qualified_rfqs = 0 then 0
        else round(month_orders::numeric * 100 / qualified_rfqs, 1) end
    ),
    'marketplace', jsonb_build_object(
      'openRfqs', (select count(*) from public.rfqs where status in ('submitted', 'open', 'quoted')),
      'ordersThisMonth', month_orders,
      'disputedOrders', (select count(*) from public.orders where status = 'disputed'),
      'recentRfqs', coalesce((
        select jsonb_agg(to_jsonb(row_data)) from (
          select r.id, r.reference_code as "referenceCode", o.display_name as buyer,
            coalesce(item.product_title, 'Unspecified request') as category,
            r.status::text, r.created_at as "createdAt"
          from public.rfqs r
          join public.organizations o on o.id = r.buyer_organization_id
          left join lateral (
            select product_title from public.rfq_items
            where rfq_id = r.id order by created_at limit 1
          ) item on true
          order by r.created_at desc limit 25
        ) row_data
      ), '[]'::jsonb)
    ),
    'suppliers', jsonb_build_object(
      'activeSuppliers', (select count(distinct organization_id) from public.listings where status = 'published'),
      'verifiedSuppliers', (select count(distinct organization_id) from public.supplier_verification_cases where status = 'approved'),
      'proSuppliers', (select count(*) from public.supplier_subscriptions where plan_code = 'pro' and status in ('trialing', 'active')),
      'atRiskSuppliers', (select count(*) from public.supplier_subscriptions where status = 'past_due'),
      'verificationQueue', coalesce((
        select jsonb_agg(to_jsonb(row_data)) from (
          select c.id, c.organization_id as "organizationId", o.display_name as supplier,
            o.district, c.verification_scope as scope, c.status,
            c.submitted_at as "submittedAt"
          from public.supplier_verification_cases c
          join public.organizations o on o.id = c.organization_id
          where c.status in ('pending', 'in_review')
          order by c.submitted_at limit 25
        ) row_data
      ), '[]'::jsonb)
    ),
    'revenue', jsonb_build_object(
      'monthlyTotal', month_revenue,
      'streams', coalesce((
        select jsonb_agg(to_jsonb(row_data)) from (
          select stream, count(*)::integer as volume, sum(gross_amount) as amount
          from public.revenue_events
          where status = 'recognized' and currency_code = 'SLE'
            and occurred_at >= month_start
          group by stream order by amount desc
        ) row_data
      ), '[]'::jsonb),
      'history', coalesce((
        select jsonb_agg(to_jsonb(row_data) order by row_data.month) from (
          select date_trunc('month', months.month)::date as month,
            coalesce(sum(e.gross_amount), 0) as amount
          from generate_series(month_start - interval '5 months', month_start, interval '1 month') months(month)
          left join public.revenue_events e
            on e.status = 'recognized' and e.currency_code = 'SLE'
            and e.occurred_at >= months.month and e.occurred_at < months.month + interval '1 month'
          group by months.month
        ) row_data
      ), '[]'::jsonb)
    ),
    'operations', jsonb_build_object(
      'verificationBacklog', (select count(*) from public.supplier_verification_cases where status in ('pending', 'in_review')),
      'listingsInReview', (select count(*) from public.listings where status = 'pending_review'),
      'supportCases', (select count(*) from public.support_cases where status in ('open', 'in_progress')),
      'highPriorityCases', (select count(*) from public.support_cases where status in ('open', 'in_progress') and priority in ('high', 'urgent')),
      'listingQueue', coalesce((
        select jsonb_agg(to_jsonb(row_data)) from (
          select l.id, l.title, o.display_name as supplier, l.category, l.status::text,
            l.created_at as "createdAt"
          from public.listings l
          join public.organizations o on o.id = l.organization_id
          where l.status = 'pending_review'
          order by l.created_at limit 25
        ) row_data
      ), '[]'::jsonb),
      'supportQueue', coalesce((
        select jsonb_agg(to_jsonb(row_data)) from (
          select c.id, c.priority, c.category, c.subject, c.status,
            o.display_name as organization, c.created_at as "createdAt"
          from public.support_cases c
          left join public.organizations o on o.id = c.organization_id
          where c.status in ('open', 'in_progress')
          order by case c.priority when 'urgent' then 0 when 'high' then 1 else 2 end,
            c.created_at limit 25
        ) row_data
      ), '[]'::jsonb)
    )
  );
end;
$$;

create or replace function public.admin_dashboard_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_platform_admin_aal2() then
    raise exception 'AAL2 platform administrator required' using errcode = '42501';
  end if;
  return public.admin_dashboard_snapshot_for((select auth.uid()));
end;
$$;

create or replace function public.admin_review_supplier_for(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_decision text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.platform_admins where user_id = p_actor_user_id) then
    raise exception 'platform administrator required' using errcode = '42501';
  end if;
  if p_decision not in ('in_review', 'approved', 'rejected') then
    raise exception 'invalid supplier review decision' using errcode = '22023';
  end if;
  update public.supplier_verification_cases
  set status = p_decision,
      reviewer_id = p_actor_user_id,
      decision_reason = nullif(trim(p_reason), ''),
      reviewed_at = case when p_decision in ('approved', 'rejected') then now() else null end
  where id = p_case_id and status in ('pending', 'in_review');
  if not found then raise exception 'review case not found or already decided' using errcode = 'P0002'; end if;
  insert into public.audit_events (actor_user_id, action, entity_type, entity_id, reason)
  values (p_actor_user_id, 'supplier_verification_' || p_decision, 'supplier_verification_case', p_case_id, nullif(trim(p_reason), ''));
end;
$$;

create or replace function public.admin_review_supplier(p_case_id uuid, p_decision text, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_platform_admin_aal2() then raise exception 'AAL2 platform administrator required' using errcode = '42501'; end if;
  perform public.admin_review_supplier_for((select auth.uid()), p_case_id, p_decision, p_reason);
end;
$$;

create or replace function public.admin_review_listing_for(p_actor_user_id uuid, p_listing_id uuid, p_decision text, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.platform_admins where user_id = p_actor_user_id) then raise exception 'platform administrator required' using errcode = '42501'; end if;
  if p_decision not in ('published', 'rejected') then raise exception 'invalid listing review decision' using errcode = '22023'; end if;
  update public.listings set status = p_decision::public.listing_status, updated_at = now()
  where id = p_listing_id and status = 'pending_review';
  if not found then raise exception 'listing not found or already decided' using errcode = 'P0002'; end if;
  insert into public.audit_events (actor_user_id, action, entity_type, entity_id, reason)
  values (p_actor_user_id, 'listing_' || p_decision, 'listing', p_listing_id, nullif(trim(p_reason), ''));
end;
$$;

create or replace function public.admin_review_listing(p_listing_id uuid, p_decision text, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_platform_admin_aal2() then raise exception 'AAL2 platform administrator required' using errcode = '42501'; end if;
  perform public.admin_review_listing_for((select auth.uid()), p_listing_id, p_decision, p_reason);
end;
$$;

create or replace function public.admin_resolve_support_case_for(p_actor_user_id uuid, p_case_id uuid, p_resolution text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.platform_admins where user_id = p_actor_user_id) then raise exception 'platform administrator required' using errcode = '42501'; end if;
  if length(trim(p_resolution)) < 3 then raise exception 'resolution is required' using errcode = '22023'; end if;
  update public.support_cases set status = 'resolved', assigned_to = p_actor_user_id,
    resolution_note = trim(p_resolution), resolved_at = now(), updated_at = now()
  where id = p_case_id and status in ('open', 'in_progress');
  if not found then raise exception 'support case not found or already resolved' using errcode = 'P0002'; end if;
  insert into public.audit_events (actor_user_id, action, entity_type, entity_id, reason)
  values (p_actor_user_id, 'support_case_resolved', 'support_case', p_case_id, trim(p_resolution));
end;
$$;

create or replace function public.admin_resolve_support_case(p_case_id uuid, p_resolution text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_platform_admin_aal2() then raise exception 'AAL2 platform administrator required' using errcode = '42501'; end if;
  perform public.admin_resolve_support_case_for((select auth.uid()), p_case_id, p_resolution);
end;
$$;

revoke all on table public.supplier_subscriptions, public.revenue_events, public.support_cases from anon, authenticated;

revoke all on function public.admin_dashboard_snapshot_for(uuid) from public, anon, authenticated;
revoke all on function public.admin_review_supplier_for(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.admin_review_listing_for(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.admin_resolve_support_case_for(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.admin_dashboard_snapshot_for(uuid) to service_role;
grant execute on function public.admin_review_supplier_for(uuid, uuid, text, text) to service_role;
grant execute on function public.admin_review_listing_for(uuid, uuid, text, text) to service_role;
grant execute on function public.admin_resolve_support_case_for(uuid, uuid, text) to service_role;

revoke all on function public.admin_dashboard_snapshot() from public, anon;
revoke all on function public.admin_review_supplier(uuid, text, text) from public, anon;
revoke all on function public.admin_review_listing(uuid, text, text) from public, anon;
revoke all on function public.admin_resolve_support_case(uuid, text) from public, anon;
grant execute on function public.admin_dashboard_snapshot() to authenticated;
grant execute on function public.admin_review_supplier(uuid, text, text) to authenticated;
grant execute on function public.admin_review_listing(uuid, text, text) to authenticated;
grant execute on function public.admin_resolve_support_case(uuid, text) to authenticated;
