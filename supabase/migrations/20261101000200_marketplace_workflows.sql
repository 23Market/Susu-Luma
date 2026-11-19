-- Susu Luma: tenant read rules and server-side workflows for buyers and suppliers.
-- All state transitions (RFQ routing, quoting, acceptance, orders, delivery, verification submission)
-- happen in the SECURITY DEFINER functions below. Clients get SELECT through RLS and nothing else.
-- Payments are NOT processed here: payment records only track external status (see architecture-security.md).

------------------------------------------------------------------------------------------
-- 1. Fix gaps in the foundation draft
------------------------------------------------------------------------------------------
alter table public.organizations alter column organization_type drop default;
alter table public.organizations
  add constraint organizations_type_check check (organization_type in ('buyer', 'supplier')),
  add column status text not null default 'active' check (status in ('active', 'suspended'));

-- Direct inserts created organisations with no owner membership; creation now goes through create_organization().
drop policy organization_create_self on public.organizations;
-- Sellers could insert a listing already 'published' (bypassing moderation). Replace the policy and guard status.
drop policy listing_insert_member on public.listings;
alter table public.listings add column moderation_reason text;

create policy listing_insert_member_draft on public.listings
  for insert to authenticated with check (
    created_by = (select auth.uid()) and status = 'draft' and exists (
      select 1 from public.organization_memberships m
      where m.organization_id = listings.organization_id and m.user_id = (select auth.uid())
        and m.member_role in ('owner', 'admin', 'seller')));
create policy listing_update_member_unpublished on public.listings
  for update to authenticated
  using (status in ('draft', 'rejected') and exists (
      select 1 from public.organization_memberships m
      where m.organization_id = listings.organization_id and m.user_id = (select auth.uid())
        and m.member_role in ('owner', 'admin', 'seller')))
  with check (status in ('draft', 'rejected'));
create policy listing_delete_member_draft on public.listings
  for delete to authenticated using (status = 'draft' and exists (
      select 1 from public.organization_memberships m
      where m.organization_id = listings.organization_id and m.user_id = (select auth.uid())
        and m.member_role in ('owner', 'admin')));

create function public.listings_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    if current_user in ('anon', 'authenticated') and (
        new.status is distinct from old.status
        or new.published_at is distinct from old.published_at
        or new.organization_id is distinct from old.organization_id
        or new.created_by is distinct from old.created_by) then
      raise exception 'listing status is server-controlled' using errcode = '42501';
    end if;
    new.updated_at := now();
  end if;
  return new;
end $$;
create trigger listings_guard_update before update on public.listings
  for each row execute function public.listings_guard();

-- One order per RFQ and per accepted quote: acceptance can never double-create.
alter table public.orders
  add constraint orders_one_per_rfq unique (rfq_id),
  add constraint orders_one_per_quote unique (accepted_quote_id);

-- Verification dossiers: checklist, reviewer and richer lifecycle.
alter table public.supplier_verification_cases drop constraint supplier_verification_cases_status_check;
alter table public.supplier_verification_cases
  add constraint supplier_verification_cases_status_check
    check (status in ('pending', 'in_review', 'info_required', 'approved', 'rejected', 'suspended', 'expired')),
  add column checklist jsonb not null default
    '[{"item":"Business or cooperative registration","done":false},{"item":"Tax clearance / TIN","done":false},{"item":"Owner identity document","done":false},{"item":"Premises or stock evidence","done":false},{"item":"Mobile-money / bank account in business name","done":false}]'::jsonb,
  add column assigned_reviewer uuid references auth.users(id) on delete set null,
  add column history jsonb not null default '[]'::jsonb;

------------------------------------------------------------------------------------------
-- 2. New tables
------------------------------------------------------------------------------------------
create table public.payment_records (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete restrict,
  expected_amount numeric(18,2) not null check (expected_amount >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  arrangement text,
  status text not null default 'pending_unverified'
    check (status in ('pending_unverified', 'externally_confirmed', 'failed', 'reversed', 'disputed', 'under_review')),
  reconciliation text not null default 'unmatched' check (reconciliation in ('unmatched', 'matched', 'exception')),
  provider_reference text,
  evidence_object_paths text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.payment_events (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payment_records(id) on delete cascade,
  kind text not null check (kind in ('system', 'assertion', 'provider', 'recon')),
  body text not null check (length(body) between 1 and 1000),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.threads (
  id uuid primary key default gen_random_uuid(),
  buyer_organization_id uuid not null references public.organizations(id) on delete restrict,
  supplier_organization_id uuid not null references public.organizations(id) on delete restrict,
  rfq_id uuid references public.rfqs(id) on delete set null,
  subject text not null check (length(trim(subject)) between 2 and 160),
  created_at timestamptz not null default now(),
  unique nulls not distinct (buyer_organization_id, supplier_organization_id, rfq_id)
);
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete restrict,
  sender_organization_id uuid not null references public.organizations(id) on delete restrict,
  body text not null check (length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index messages_thread_idx on public.messages (thread_id, created_at);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  entity_type text,
  entity_id uuid,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index notifications_org_idx on public.notifications (organization_id, created_at desc);

alter table public.payment_records enable row level security;
alter table public.payment_events enable row level security;
alter table public.threads enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;

------------------------------------------------------------------------------------------
-- 3. Membership / visibility helpers (SECURITY DEFINER so policies do not recurse)
------------------------------------------------------------------------------------------
create function public.is_org_member(p_org uuid, p_roles text[] default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.organization_memberships m
    where m.organization_id = p_org and m.user_id = (select auth.uid())
      and (p_roles is null or m.member_role = any (p_roles)))
$$;
create function public.org_is_active(p_org uuid, p_type text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.organizations o
    where o.id = p_org and o.status = 'active' and o.organization_type = p_type)
$$;
create function public.rfq_buyer_member(p_rfq uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.rfqs r where r.id = p_rfq and public.is_org_member(r.buyer_organization_id))
$$;
create function public.rfq_recipient_member(p_rfq uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.rfq_recipients rr
    where rr.rfq_id = p_rfq and public.is_org_member(rr.supplier_organization_id))
$$;
create function public.can_see_rfq(p_rfq uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.rfq_buyer_member(p_rfq)
      or (public.rfq_recipient_member(p_rfq)
          and exists (select 1 from public.rfqs r where r.id = p_rfq and r.status <> 'draft'))
$$;
create function public.can_see_quote(p_quote uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.quotes q where q.id = p_quote and (
      public.is_org_member(q.supplier_organization_id)
      or (q.status <> 'draft' and public.rfq_buyer_member(q.rfq_id))))
$$;
create function public.can_see_order(p_order uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.orders o where o.id = p_order and (
      public.is_org_member(o.buyer_organization_id) or public.is_org_member(o.supplier_organization_id)))
$$;
create function public.org_is_verified(p_org uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.supplier_verification_cases c
    where c.organization_id = p_org and c.status = 'approved' and c.expires_at > now())
$$;
create function public.notify_org(p_org uuid, p_kind text, p_title text, p_body text, p_entity_type text, p_entity_id uuid)
returns void language sql security definer set search_path = '' as $$
  insert into public.notifications (organization_id, kind, title, body, entity_type, entity_id)
  values (p_org, p_kind, p_title, p_body, p_entity_type, p_entity_id)
$$;
revoke all on function public.notify_org(uuid, text, text, text, text, uuid) from public, anon, authenticated;
revoke execute on function public.is_org_member(uuid, text[]), public.org_is_active(uuid, text),
  public.rfq_buyer_member(uuid), public.rfq_recipient_member(uuid), public.can_see_rfq(uuid),
  public.can_see_quote(uuid), public.can_see_order(uuid), public.org_is_verified(uuid) from public, anon;
grant execute on function public.is_org_member(uuid, text[]), public.org_is_active(uuid, text),
  public.rfq_buyer_member(uuid), public.rfq_recipient_member(uuid), public.can_see_rfq(uuid),
  public.can_see_quote(uuid), public.can_see_order(uuid) to authenticated;
grant execute on function public.org_is_verified(uuid) to anon, authenticated;

------------------------------------------------------------------------------------------
-- 4. Read policies (tenant isolation). No client write policies except draft listings above.
------------------------------------------------------------------------------------------
create policy rfq_read_parties on public.rfqs for select to authenticated using (public.can_see_rfq(id));
create policy rfq_items_read on public.rfq_items for select to authenticated using (public.can_see_rfq(rfq_id));
-- Suppliers see only their own routing row; competitors are never revealed to each other.
create policy rfq_recipients_read on public.rfq_recipients for select to authenticated using (
  public.is_org_member(supplier_organization_id) or public.rfq_buyer_member(rfq_id));
create policy quotes_read on public.quotes for select to authenticated using (public.can_see_quote(id));
create policy quote_lines_read on public.quote_lines for select to authenticated using (public.can_see_quote(quote_id));
create policy orders_read_parties on public.orders for select to authenticated using (public.can_see_order(id));
create policy delivery_events_read on public.delivery_events for select to authenticated using (public.can_see_order(order_id));
create policy verification_read_own_org on public.supplier_verification_cases for select to authenticated
  using (public.is_org_member(organization_id, array['owner', 'admin']));
create policy payment_records_read on public.payment_records for select to authenticated using (public.can_see_order(order_id));
create policy payment_events_read on public.payment_events for select to authenticated using (
  exists (select 1 from public.payment_records p where p.id = payment_id and public.can_see_order(p.order_id)));
create policy threads_read on public.threads for select to authenticated using (
  public.is_org_member(buyer_organization_id) or public.is_org_member(supplier_organization_id));
create policy messages_read on public.messages for select to authenticated using (
  exists (select 1 from public.threads t where t.id = thread_id
          and (public.is_org_member(t.buyer_organization_id) or public.is_org_member(t.supplier_organization_id))));
create policy notifications_read on public.notifications for select to authenticated using (public.is_org_member(organization_id));
-- Members may see co-members of their own organisation (needed to show who acted).
create policy membership_read_org on public.organization_memberships for select to authenticated
  using (public.is_org_member(organization_id));

-- Defence in depth: remove write privileges where no client write policy exists.
revoke insert, update, delete, truncate on public.organizations, public.organization_memberships,
  public.supplier_verification_cases, public.rfqs, public.rfq_items, public.rfq_recipients, public.quotes,
  public.quote_lines, public.orders, public.delivery_events, public.payment_records, public.payment_events,
  public.threads, public.messages, public.notifications from anon, authenticated;
revoke all on public.payment_records, public.payment_events, public.threads, public.messages,
  public.notifications, public.rfqs, public.rfq_items, public.rfq_recipients, public.quotes, public.quote_lines,
  public.orders, public.delivery_events, public.supplier_verification_cases from anon;

-- Public supplier directory: safe columns only, for suppliers that have a published listing.
create view public.supplier_directory as
  select o.id, o.display_name, o.district, o.locality, public.org_is_verified(o.id) as verified
  from public.organizations o
  where o.organization_type = 'supplier' and o.status = 'active'
    and exists (select 1 from public.listings l where l.organization_id = o.id and l.status = 'published');
grant select on public.supplier_directory to anon, authenticated;

------------------------------------------------------------------------------------------
-- 5. Workflows
------------------------------------------------------------------------------------------
create function public.create_organization(p_legal_name text, p_display_name text, p_type text, p_district text, p_locality text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if p_type not in ('buyer', 'supplier') then raise exception 'invalid_organization_type' using errcode = '22023'; end if;
  if (select count(*) from public.organization_memberships where user_id = v_uid and member_role = 'owner') >= 5 then
    raise exception 'organization_limit_reached' using errcode = '54000';
  end if;
  insert into public.organizations (legal_name, display_name, organization_type, district, locality, created_by)
  values (p_legal_name, p_display_name, p_type, nullif(trim(p_district), ''), nullif(trim(p_locality), ''), v_uid)
  returning id into v_id;
  insert into public.organization_memberships (organization_id, user_id, member_role) values (v_id, v_uid, 'owner');
  perform public.write_audit('organization.create', 'organization', v_id, null, 'info', jsonb_build_object('type', p_type));
  return v_id;
end $$;

create function public.submit_listing_for_review(p_listing uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare v_l public.listings; v_pre boolean; v_new text;
begin
  select * into v_l from public.listings where id = p_listing for update;
  if not found or not public.is_org_member(v_l.organization_id, array['owner', 'admin', 'seller']) then
    raise exception 'not_permitted' using errcode = '42501';
  end if;
  if not public.org_is_active(v_l.organization_id, 'supplier') then raise exception 'organization_not_active_supplier' using errcode = '42501'; end if;
  if v_l.status not in ('draft', 'rejected') then raise exception 'invalid_state' using errcode = 'P0001'; end if;
  if length(trim(v_l.title)) < 3 then raise exception 'title_too_short' using errcode = '22023'; end if;
  select c.pre_moderate into v_pre from public.categories c where c.id = v_l.category;
  -- Pre-moderated categories (and unverified suppliers) always go to the moderation queue.
  v_new := case when coalesce(v_pre, true) or not public.org_is_verified(v_l.organization_id) then 'pending_review' else 'published' end;
  update public.listings set status = v_new::public.listing_status, published_at = case when v_new = 'published' then now() end,
    moderation_reason = null where id = p_listing;
  perform public.write_audit('listing.submit', 'listing', p_listing, null, 'info', jsonb_build_object('result', v_new));
  return v_new;
end $$;

create function public.submit_verification(p_org uuid, p_scope text, p_evidence text[]) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not public.is_org_member(p_org, array['owner', 'admin']) then raise exception 'not_permitted' using errcode = '42501'; end if;
  if not public.org_is_active(p_org, 'supplier') then raise exception 'organization_not_active_supplier' using errcode = '42501'; end if;
  if exists (select 1 from public.supplier_verification_cases c
             where c.organization_id = p_org and c.status in ('pending', 'in_review', 'info_required')) then
    raise exception 'verification_already_open' using errcode = 'P0001';
  end if;
  if coalesce(array_length(p_evidence, 1), 0) < 1 or array_length(p_evidence, 1) > 20 then
    raise exception 'evidence_required' using errcode = '22023';
  end if;
  -- Evidence must live under the organisation's own storage prefix.
  if exists (select 1 from unnest(p_evidence) e where e not like p_org::text || '/%') then
    raise exception 'evidence_path_invalid' using errcode = '22023';
  end if;
  insert into public.supplier_verification_cases (organization_id, verification_scope, evidence_object_paths, created_by,
                                                  history)
  values (p_org, nullif(trim(p_scope), ''), p_evidence, (select auth.uid()),
          jsonb_build_array(jsonb_build_object('at', now(), 'text', 'Dossier submitted by supplier')))
  returning id into v_id;
  perform public.write_audit('verification.submit', 'verification_case', v_id, null);
  return v_id;
end $$;

create function public.create_rfq(
  p_buyer_org uuid, p_destination_district text, p_destination_locality text, p_target_delivery_date date,
  p_notes text, p_items jsonb, p_supplier_orgs uuid[] default '{}') returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid()); v_rfq uuid; v_item jsonb; v_l public.listings;
  v_title text; v_unit text; v_qty numeric; v_recipients uuid[] := coalesce(p_supplier_orgs, '{}'); v_org uuid; v_ref text;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if not public.is_org_member(p_buyer_org, array['owner', 'admin', 'buyer']) then raise exception 'not_permitted' using errcode = '42501'; end if;
  if not public.org_is_active(p_buyer_org, 'buyer') then raise exception 'organization_not_active_buyer' using errcode = '42501'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 20 then
    raise exception 'items_invalid' using errcode = '22023';
  end if;
  if p_target_delivery_date is not null and p_target_delivery_date < current_date then
    raise exception 'target_date_in_past' using errcode = '22023';
  end if;
  insert into public.rfqs (buyer_organization_id, status, destination_district, destination_locality,
                           target_delivery_date, notes, created_by, submitted_at)
  values (p_buyer_org, 'open', nullif(trim(p_destination_district), ''), nullif(trim(p_destination_locality), ''),
          p_target_delivery_date, nullif(trim(p_notes), ''), v_uid, now())
  returning id, reference_code into v_rfq, v_ref;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item ->> 'quantity')::numeric;
    if v_qty is null or v_qty <= 0 then raise exception 'quantity_invalid' using errcode = '22023'; end if;
    if nullif(v_item ->> 'listing_id', '') is not null then
      select * into v_l from public.listings where id = (v_item ->> 'listing_id')::uuid and status = 'published';
      if not found then raise exception 'listing_unavailable' using errcode = 'P0001'; end if;
      v_title := v_l.title; v_unit := v_l.quantity_unit; v_recipients := v_recipients || v_l.organization_id;
    else
      v_title := trim(v_item ->> 'product_title'); v_unit := trim(v_item ->> 'quantity_unit');
    end if;
    if coalesce(length(v_title), 0) < 3 or coalesce(length(v_unit), 0) < 1 then raise exception 'item_invalid' using errcode = '22023'; end if;
    insert into public.rfq_items (rfq_id, listing_id, product_title, quantity, quantity_unit)
    values (v_rfq, nullif(v_item ->> 'listing_id', '')::uuid, v_title, v_qty, v_unit);
  end loop;
  insert into public.rfq_recipients (rfq_id, supplier_organization_id)
  select distinct v_rfq, o.id from public.organizations o
  where o.id = any (v_recipients) and o.organization_type = 'supplier' and o.status = 'active' and o.id <> p_buyer_org;
  if not exists (select 1 from public.rfq_recipients where rfq_id = v_rfq) then raise exception 'no_valid_recipients' using errcode = 'P0001'; end if;
  if (select count(*) from public.rfq_recipients where rfq_id = v_rfq) > 10 then raise exception 'too_many_recipients' using errcode = '22023'; end if;
  for v_org in select supplier_organization_id from public.rfq_recipients where rfq_id = v_rfq loop
    perform public.notify_org(v_org, 'rfq.received', 'New request for quotation', v_ref, 'rfq', v_rfq);
  end loop;
  perform public.write_audit('rfq.create', 'rfq', v_rfq, null);
  return v_rfq;
end $$;

create function public.cancel_rfq(p_rfq uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_r public.rfqs;
begin
  select * into v_r from public.rfqs where id = p_rfq for update;
  if not found or not public.is_org_member(v_r.buyer_organization_id, array['owner', 'admin', 'buyer']) then
    raise exception 'not_permitted' using errcode = '42501';
  end if;
  if v_r.status not in ('open', 'quoted') then raise exception 'invalid_state' using errcode = 'P0001'; end if;
  update public.rfqs set status = 'cancelled', updated_at = now() where id = p_rfq;
  perform public.write_audit('rfq.cancel', 'rfq', p_rfq, null);
end $$;

-- p_lines: [{"rfq_item_id": uuid, "unit_price": number}]. Units are copied from the RFQ item, never client-supplied.
create function public.submit_quote(
  p_rfq uuid, p_supplier_org uuid, p_currency text, p_lead_time_days integer, p_validity timestamptz,
  p_terms text, p_exclusions text, p_lines jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_r public.rfqs; v_q uuid; v_ver integer; v_line jsonb; v_n integer; v_item public.rfq_items;
begin
  select * into v_r from public.rfqs where id = p_rfq for update;
  if not found then raise exception 'not_permitted' using errcode = '42501'; end if;
  if not public.is_org_member(p_supplier_org, array['owner', 'admin', 'seller']) then raise exception 'not_permitted' using errcode = '42501'; end if;
  if not public.org_is_active(p_supplier_org, 'supplier') then raise exception 'organization_not_active_supplier' using errcode = '42501'; end if;
  if not exists (select 1 from public.rfq_recipients where rfq_id = p_rfq and supplier_organization_id = p_supplier_org) then
    raise exception 'not_a_recipient' using errcode = '42501';
  end if;
  if v_r.status not in ('open', 'quoted') then raise exception 'rfq_not_open' using errcode = 'P0001'; end if;
  if p_currency !~ '^[A-Z]{3}$' then raise exception 'currency_invalid' using errcode = '22023'; end if;
  if p_validity is null or p_validity <= now() then raise exception 'validity_in_past' using errcode = '22023'; end if;
  if p_lead_time_days is not null and p_lead_time_days < 0 then raise exception 'lead_time_invalid' using errcode = '22023'; end if;
  if jsonb_typeof(p_lines) <> 'array' then raise exception 'lines_invalid' using errcode = '22023'; end if;
  select count(*) into v_n from public.rfq_items where rfq_id = p_rfq;
  if jsonb_array_length(p_lines) <> v_n
     or (select count(distinct (l ->> 'rfq_item_id')) from jsonb_array_elements(p_lines) l) <> v_n then
    raise exception 'every_item_must_be_priced_once' using errcode = '22023';
  end if;
  select coalesce(max(version), 0) + 1 into v_ver from public.quotes where rfq_id = p_rfq and supplier_organization_id = p_supplier_org;
  update public.quotes set status = 'revised'
   where rfq_id = p_rfq and supplier_organization_id = p_supplier_org and status = 'submitted';
  insert into public.quotes (rfq_id, supplier_organization_id, version, status, currency_code, lead_time_days,
                             validity_until, terms, exclusions, submitted_by, submitted_at)
  values (p_rfq, p_supplier_org, v_ver, 'submitted', p_currency, p_lead_time_days, p_validity,
          nullif(trim(p_terms), ''), nullif(trim(p_exclusions), ''), v_uid, now())
  returning id into v_q;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_item from public.rfq_items where id = (v_line ->> 'rfq_item_id')::uuid and rfq_id = p_rfq;
    if not found then raise exception 'unknown_rfq_item' using errcode = '22023'; end if;
    if (v_line ->> 'unit_price')::numeric is null or (v_line ->> 'unit_price')::numeric < 0 then
      raise exception 'unit_price_invalid' using errcode = '22023';
    end if;
    insert into public.quote_lines (quote_id, rfq_item_id, unit_price, currency_code, quantity_unit)
    values (v_q, v_item.id, (v_line ->> 'unit_price')::numeric, p_currency, v_item.quantity_unit);
  end loop;
  update public.rfqs set status = 'quoted', updated_at = now() where id = p_rfq;
  perform public.notify_org(v_r.buyer_organization_id, 'quote.received', 'New quotation received', v_r.reference_code, 'quote', v_q);
  perform public.write_audit('quote.submit', 'quote', v_q, null, 'info', jsonb_build_object('version', v_ver));
  return v_q;
end $$;

-- Accepting snapshots the exact quote terms into the order; later changes cannot alter it.
create function public.accept_quote(p_quote uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid()); v_q public.quotes; v_r public.rfqs; v_order uuid; v_total numeric; v_snap jsonb;
begin
  select * into v_q from public.quotes where id = p_quote for update;
  if not found then raise exception 'not_permitted' using errcode = '42501'; end if;
  select * into v_r from public.rfqs where id = v_q.rfq_id for update;
  if not public.is_org_member(v_r.buyer_organization_id, array['owner', 'admin', 'buyer']) then raise exception 'not_permitted' using errcode = '42501'; end if;
  if not public.org_is_active(v_r.buyer_organization_id, 'buyer') then raise exception 'organization_not_active_buyer' using errcode = '42501'; end if;
  if v_r.status <> 'quoted' or v_q.status <> 'submitted' then raise exception 'quote_not_acceptable' using errcode = 'P0001'; end if;
  if v_q.validity_until is not null and v_q.validity_until <= now() then raise exception 'quote_expired' using errcode = 'P0001'; end if;
  select sum(l.unit_price * i.quantity) into v_total
  from public.quote_lines l join public.rfq_items i on i.id = l.rfq_item_id where l.quote_id = p_quote;
  select jsonb_build_object(
    'rfq_reference', v_r.reference_code, 'quote_id', v_q.id, 'quote_version', v_q.version,
    'currency_code', v_q.currency_code, 'total', v_total, 'lead_time_days', v_q.lead_time_days,
    'terms', v_q.terms, 'exclusions', v_q.exclusions, 'accepted_at', now(),
    'lines', (select jsonb_agg(jsonb_build_object('product_title', i.product_title, 'quantity', i.quantity,
              'quantity_unit', i.quantity_unit, 'unit_price', l.unit_price, 'currency_code', l.currency_code))
              from public.quote_lines l join public.rfq_items i on i.id = l.rfq_item_id where l.quote_id = p_quote))
  into v_snap;
  update public.quotes set status = 'accepted' where id = p_quote;
  update public.quotes set status = 'declined' where rfq_id = v_q.rfq_id and id <> p_quote and status = 'submitted';
  update public.rfqs set status = 'accepted', updated_at = now() where id = v_q.rfq_id;
  insert into public.orders (rfq_id, accepted_quote_id, buyer_organization_id, supplier_organization_id,
                             status, payment_status, accepted_quote_snapshot, created_by)
  values (v_q.rfq_id, p_quote, v_r.buyer_organization_id, v_q.supplier_organization_id,
          'awaiting_seller_confirmation', 'pending_unverified', v_snap, v_uid)
  returning id into v_order;
  insert into public.payment_records (order_id, expected_amount, currency_code) values (v_order, v_total, v_q.currency_code);
  perform public.notify_org(v_q.supplier_organization_id, 'order.created', 'Quotation accepted — confirm the order', v_r.reference_code, 'order', v_order);
  perform public.write_audit('quote.accept', 'order', v_order, null, 'info', jsonb_build_object('quote', p_quote));
  return v_order;
end $$;

create function public.confirm_order(p_order uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_o public.orders;
begin
  select * into v_o from public.orders where id = p_order for update;
  if not found or not public.is_org_member(v_o.supplier_organization_id, array['owner', 'admin', 'seller']) then
    raise exception 'not_permitted' using errcode = '42501';
  end if;
  if v_o.status <> 'awaiting_seller_confirmation' then raise exception 'invalid_state' using errcode = 'P0001'; end if;
  update public.orders set status = 'confirmed', seller_confirmed_at = now(), updated_at = now() where id = p_order;
  insert into public.delivery_events (order_id, event_type, note, created_by) values (p_order, 'ready', 'Order confirmed by supplier', (select auth.uid()));
  perform public.notify_org(v_o.buyer_organization_id, 'order.confirmed', 'Supplier confirmed your order', null, 'order', p_order);
  perform public.write_audit('order.confirm', 'order', p_order, null);
end $$;

create function public.add_delivery_event(
  p_order uuid, p_type text, p_note text, p_quantity numeric, p_unit text, p_evidence text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_o public.orders; v_new public.order_status;
begin
  select * into v_o from public.orders where id = p_order for update;
  if not found or not public.is_org_member(v_o.supplier_organization_id, array['owner', 'admin', 'seller']) then
    raise exception 'not_permitted' using errcode = '42501';
  end if;
  if p_type not in ('ready', 'dispatched', 'in_transit', 'partial_delivery', 'delivered', 'proof_of_delivery') then
    raise exception 'event_type_invalid' using errcode = '22023';
  end if;
  if v_o.status not in ('confirmed', 'in_fulfilment', 'partially_delivered') then raise exception 'invalid_state' using errcode = 'P0001'; end if;
  if p_type = 'partial_delivery' and (p_quantity is null or p_quantity <= 0 or coalesce(p_unit, '') = '') then
    raise exception 'quantity_and_unit_required' using errcode = '22023';
  end if;
  if p_evidence is not null and p_evidence not like v_o.supplier_organization_id::text || '/%' then
    raise exception 'evidence_path_invalid' using errcode = '22023';
  end if;
  v_new := case p_type when 'partial_delivery' then 'partially_delivered' when 'delivered' then 'delivered'
                       when 'proof_of_delivery' then v_o.status else 'in_fulfilment' end;
  insert into public.delivery_events (order_id, event_type, note, evidence_object_path, quantity, quantity_unit, created_by)
  values (p_order, p_type, nullif(trim(p_note), ''), p_evidence, p_quantity, nullif(trim(p_unit), ''), (select auth.uid()));
  update public.orders set status = v_new, updated_at = now() where id = p_order;
  perform public.notify_org(v_o.buyer_organization_id, 'order.delivery', 'Delivery update: ' || replace(p_type, '_', ' '), null, 'order', p_order);
  perform public.write_audit('order.delivery_event', 'order', p_order, null, 'info', jsonb_build_object('type', p_type));
end $$;

create function public.report_delivery_problem(p_order uuid, p_text text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_o public.orders;
begin
  select * into v_o from public.orders where id = p_order for update;
  if not found or not public.is_org_member(v_o.buyer_organization_id, array['owner', 'admin', 'buyer']) then
    raise exception 'not_permitted' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_text, ''))) < 3 then raise exception 'description_required' using errcode = '22023'; end if;
  if v_o.status not in ('confirmed', 'in_fulfilment', 'partially_delivered', 'delivered') then raise exception 'invalid_state' using errcode = 'P0001'; end if;
  update public.orders set status = 'disputed', updated_at = now() where id = p_order;
  insert into public.delivery_events (order_id, event_type, note, created_by) values (p_order, 'exception', left(trim(p_text), 1000), (select auth.uid()));
  perform public.notify_org(v_o.supplier_organization_id, 'order.problem', 'Buyer reported a problem', left(trim(p_text), 200), 'order', p_order);
  perform public.write_audit('order.problem_reported', 'order', p_order, left(trim(p_text), 200), 'warn');
end $$;

-- A party's claim that payment was made is recorded but NEVER changes the payment status.
create function public.assert_payment_made(p_order uuid, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_p public.payment_records;
begin
  select p.* into v_p from public.payment_records p where p.order_id = p_order;
  if not found or not public.can_see_order(p_order) then raise exception 'not_permitted' using errcode = '42501'; end if;
  insert into public.payment_events (payment_id, kind, body, created_by)
  values (v_p.id, 'assertion', 'Party asserted payment was made (unverified): ' || left(coalesce(nullif(trim(p_note), ''), 'no note'), 500), (select auth.uid()));
end $$;

create function public.set_payment_arrangement(p_order uuid, p_arrangement text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_see_order(p_order) then raise exception 'not_permitted' using errcode = '42501'; end if;
  if length(trim(coalesce(p_arrangement, ''))) < 3 then raise exception 'arrangement_required' using errcode = '22023'; end if;
  update public.payment_records set arrangement = left(trim(p_arrangement), 120), updated_at = now() where order_id = p_order;
end $$;

create function public.open_thread(p_buyer_org uuid, p_supplier_org uuid, p_rfq uuid, p_subject text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not (public.is_org_member(p_buyer_org) or public.is_org_member(p_supplier_org)) then raise exception 'not_permitted' using errcode = '42501'; end if;
  if not public.org_is_active(p_buyer_org, 'buyer') or not public.org_is_active(p_supplier_org, 'supplier') then
    raise exception 'organization_not_active' using errcode = '42501';
  end if;
  if p_rfq is not null and not exists (select 1 from public.rfqs r where r.id = p_rfq and r.buyer_organization_id = p_buyer_org) then
    raise exception 'rfq_mismatch' using errcode = '22023';
  end if;
  select id into v_id from public.threads
   where buyer_organization_id = p_buyer_org and supplier_organization_id = p_supplier_org and rfq_id is not distinct from p_rfq;
  if v_id is null then
    insert into public.threads (buyer_organization_id, supplier_organization_id, rfq_id, subject)
    values (p_buyer_org, p_supplier_org, p_rfq, p_subject) returning id into v_id;
  end if;
  return v_id;
end $$;

create function public.send_message(p_thread uuid, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_t public.threads; v_org uuid; v_id uuid;
begin
  select * into v_t from public.threads where id = p_thread;
  if not found then raise exception 'not_permitted' using errcode = '42501'; end if;
  v_org := case when public.is_org_member(v_t.buyer_organization_id) then v_t.buyer_organization_id
                when public.is_org_member(v_t.supplier_organization_id) then v_t.supplier_organization_id end;
  if v_org is null then raise exception 'not_permitted' using errcode = '42501'; end if;
  insert into public.messages (thread_id, sender_user_id, sender_organization_id, body)
  values (p_thread, (select auth.uid()), v_org, trim(p_body)) returning id into v_id;
  perform public.notify_org(case when v_org = v_t.buyer_organization_id then v_t.supplier_organization_id else v_t.buyer_organization_id end,
                            'message.received', 'New message', left(trim(p_body), 120), 'thread', p_thread);
  return v_id;
end $$;

create function public.mark_notifications_read(p_org uuid) returns void
language sql security definer set search_path = '' as $$
  update public.notifications set read_at = now()
  where organization_id = p_org and read_at is null and public.is_org_member(p_org)
$$;

-- Everything above is for signed-in users only.
revoke all on function
  public.create_organization(text, text, text, text, text), public.submit_listing_for_review(uuid),
  public.submit_verification(uuid, text, text[]),
  public.create_rfq(uuid, text, text, date, text, jsonb, uuid[]), public.cancel_rfq(uuid),
  public.submit_quote(uuid, uuid, text, integer, timestamptz, text, text, jsonb), public.accept_quote(uuid),
  public.confirm_order(uuid), public.add_delivery_event(uuid, text, text, numeric, text, text),
  public.report_delivery_problem(uuid, text), public.assert_payment_made(uuid, text),
  public.set_payment_arrangement(uuid, text), public.open_thread(uuid, uuid, uuid, text),
  public.send_message(uuid, text), public.mark_notifications_read(uuid)
from public, anon;
grant execute on function
  public.create_organization(text, text, text, text, text), public.submit_listing_for_review(uuid),
  public.submit_verification(uuid, text, text[]),
  public.create_rfq(uuid, text, text, date, text, jsonb, uuid[]), public.cancel_rfq(uuid),
  public.submit_quote(uuid, uuid, text, integer, timestamptz, text, text, jsonb), public.accept_quote(uuid),
  public.confirm_order(uuid), public.add_delivery_event(uuid, text, text, numeric, text, text),
  public.report_delivery_problem(uuid, text), public.assert_payment_made(uuid, text),
  public.set_payment_arrangement(uuid, text), public.open_thread(uuid, uuid, uuid, text),
  public.send_message(uuid, text), public.mark_notifications_read(uuid)
to authenticated;
