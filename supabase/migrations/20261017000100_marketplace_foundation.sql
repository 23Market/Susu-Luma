-- Susu Luma foundation schema (draft; review and test before applying to any shared project).
-- This migration deliberately does not create wallet, escrow, lending or settlement tables.
create extension if not exists pgcrypto;

create type public.listing_status as enum ('draft', 'pending_review', 'published', 'paused', 'rejected', 'archived');
create type public.price_mode as enum ('fixed', 'quote_only', 'indicative');
create type public.rfq_status as enum ('draft', 'submitted', 'open', 'quoted', 'accepted', 'cancelled', 'closed');
create type public.quote_status as enum ('draft', 'submitted', 'revised', 'accepted', 'declined', 'expired', 'withdrawn');
create type public.order_status as enum ('awaiting_seller_confirmation', 'confirmed', 'in_fulfilment', 'partially_delivered', 'delivered', 'disputed', 'cancelled');
create type public.payment_status as enum ('pending_unverified', 'externally_confirmed', 'not_applicable', 'under_review');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null check (length(trim(legal_name)) between 2 and 180),
  display_name text not null check (length(trim(display_name)) between 2 and 120),
  organization_type text not null default 'business',
  country_code text not null default 'SL' check (country_code = 'SL'),
  district text,
  locality text,
  public_description text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_memberships (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  member_role text not null check (member_role in ('owner', 'admin', 'buyer', 'seller', 'staff')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

-- Platform administrators are provisioned only through a trusted operational
-- process. Clients cannot list or modify administrator assignments; access is
-- evaluated by the server-side AAL2 helper added by the security migration.
create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.supplier_verification_cases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending', 'in_review', 'approved', 'rejected', 'expired')),
  verification_scope text,
  reviewer_id uuid references auth.users(id) on delete restrict,
  decision_reason text,
  evidence_object_paths text[] not null default '{}',
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  expires_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  title text not null check (length(trim(title)) between 3 and 180),
  description text not null default '',
  category text not null,
  specifications jsonb not null default '{}'::jsonb,
  quantity_unit text not null check (length(trim(quantity_unit)) between 1 and 40),
  minimum_order_quantity numeric(18,4) check (minimum_order_quantity is null or minimum_order_quantity > 0),
  price_mode public.price_mode not null default 'quote_only',
  price_amount numeric(18,2) check (price_amount is null or price_amount >= 0),
  currency_code text,
  availability text,
  lead_time_days integer check (lead_time_days is null or lead_time_days >= 0),
  district text,
  locality text,
  status public.listing_status not null default 'draft',
  published_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((price_mode = 'quote_only' and price_amount is null) or (price_mode <> 'quote_only' and (price_amount is null or currency_code is not null))),
  check (currency_code is null or currency_code ~ '^[A-Z]{3}$')
);
create index listings_discovery_idx on public.listings (status, category, district, created_at desc);
create index listings_org_idx on public.listings (organization_id, status);

create table public.rfqs (
  id uuid primary key default gen_random_uuid(),
  reference_code text not null unique default ('SL-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  buyer_organization_id uuid not null references public.organizations(id) on delete restrict,
  status public.rfq_status not null default 'draft',
  destination_district text,
  destination_locality text,
  target_delivery_date date,
  notes text,
  created_by uuid not null references auth.users(id) on delete restrict,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.rfq_items (
  id uuid primary key default gen_random_uuid(),
  rfq_id uuid not null references public.rfqs(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete set null,
  product_title text not null,
  specifications jsonb not null default '{}'::jsonb,
  quantity numeric(18,4) not null check (quantity > 0),
  quantity_unit text not null check (length(trim(quantity_unit)) between 1 and 40),
  created_at timestamptz not null default now()
);

create table public.rfq_recipients (
  rfq_id uuid not null references public.rfqs(id) on delete cascade,
  supplier_organization_id uuid not null references public.organizations(id) on delete restrict,
  routed_at timestamptz not null default now(),
  primary key (rfq_id, supplier_organization_id)
);

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  rfq_id uuid not null references public.rfqs(id) on delete restrict,
  supplier_organization_id uuid not null references public.organizations(id) on delete restrict,
  version integer not null check (version > 0),
  status public.quote_status not null default 'draft',
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  lead_time_days integer check (lead_time_days is null or lead_time_days >= 0),
  validity_until timestamptz,
  terms text,
  exclusions text,
  submitted_by uuid not null references auth.users(id) on delete restrict,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (rfq_id, supplier_organization_id, version)
);

create table public.quote_lines (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  rfq_item_id uuid not null references public.rfq_items(id) on delete restrict,
  unit_price numeric(18,2) not null check (unit_price >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  quantity_unit text not null,
  fees_description text,
  created_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  rfq_id uuid not null references public.rfqs(id) on delete restrict,
  accepted_quote_id uuid not null references public.quotes(id) on delete restrict,
  buyer_organization_id uuid not null references public.organizations(id) on delete restrict,
  supplier_organization_id uuid not null references public.organizations(id) on delete restrict,
  status public.order_status not null default 'awaiting_seller_confirmation',
  payment_status public.payment_status not null default 'pending_unverified',
  accepted_quote_snapshot jsonb not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  seller_confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.delivery_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  event_type text not null check (event_type in ('ready', 'dispatched', 'in_transit', 'partial_delivery', 'delivered', 'exception', 'proof_of_delivery')),
  note text,
  evidence_object_path text,
  quantity numeric(18,4) check (quantity is null or quantity >= 0),
  quantity_unit text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete restrict,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Enable RLS on every exposed table. Access is intentionally conservative until
-- reviewed RPCs and role-specific policies are implemented and tested.
alter table public.organizations enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.platform_admins enable row level security;
alter table public.supplier_verification_cases enable row level security;
alter table public.listings enable row level security;
alter table public.rfqs enable row level security;
alter table public.rfq_items enable row level security;
alter table public.rfq_recipients enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_lines enable row level security;
alter table public.orders enable row level security;
alter table public.delivery_events enable row level security;
alter table public.audit_events enable row level security;

-- Membership rows are visible only to the member. This supports scoped
-- membership checks without exposing a complete organization roster.
create policy membership_read_self on public.organization_memberships
  for select to authenticated using (user_id = (select auth.uid()));

create policy organization_read_member on public.organizations
  for select to authenticated using (
    exists (select 1 from public.organization_memberships m
      where m.organization_id = id and m.user_id = (select auth.uid()))
  );

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.platform_admins administrator
    where administrator.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

-- Creates the organisation and its owner membership atomically. This avoids an
-- organisation that its creator cannot access if the second insert fails.
create or replace function public.create_organization(
  organization_legal_name text,
  organization_display_name text,
  organization_district text default null,
  organization_locality text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  organization_id uuid;
begin
  if caller_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if organization_legal_name is null or
      length(trim(organization_legal_name)) not between 2 and 180 then
    raise exception 'legal name must contain 2 to 180 characters' using errcode = '22023';
  end if;
  if organization_display_name is null or
      length(trim(organization_display_name)) not between 2 and 120 then
    raise exception 'display name must contain 2 to 120 characters' using errcode = '22023';
  end if;

  insert into public.organizations (
    legal_name,
    display_name,
    district,
    locality,
    created_by
  ) values (
    trim(organization_legal_name),
    trim(organization_display_name),
    nullif(trim(organization_district), ''),
    nullif(trim(organization_locality), ''),
    caller_id
  ) returning id into organization_id;

  insert into public.organization_memberships (
    organization_id,
    user_id,
    member_role
  ) values (
    organization_id,
    caller_id,
    'owner'
  );

  return organization_id;
end;
$$;

revoke all on function public.create_organization(text, text, text, text) from public;
grant execute on function public.create_organization(text, text, text, text) to authenticated;

create policy listing_read_published on public.listings
  for select to anon, authenticated using (status = 'published');

create policy listing_read_own_org on public.listings
  for select to authenticated using (
    exists (select 1 from public.organization_memberships m
      where m.organization_id = listings.organization_id and m.user_id = (select auth.uid()))
  );

create policy listing_insert_member on public.listings
  for insert to authenticated with check (
    created_by = (select auth.uid()) and exists (
      select 1 from public.organization_memberships m
      where m.organization_id = listings.organization_id and m.user_id = (select auth.uid())
        and m.member_role in ('owner', 'admin', 'seller'))
  );

-- Deliberately no client write policies for verification decisions, RFQ routing,
-- quote acceptance, orders, payment state, delivery evidence or audit events.
-- Add those only through reviewed server-side actions with explicit authorization.
