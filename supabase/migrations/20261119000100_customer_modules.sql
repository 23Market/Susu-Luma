-- Discovery and customer-service foundation. No deployment or live-provider changes.
create function public.discover_listings(p_query text default '', p_category text default null,
  p_district text default null, p_availability text default null, p_after uuid default null,
  p_limit integer default 20) returns setof public.listings
language sql stable security invoker set search_path = '' as $$
  select l.* from public.listings l
  join public.organizations o on o.id = l.organization_id
  join public.categories c on c.id = l.category
  where l.status = 'published' and o.status = 'active' and c.is_active
    and (coalesce(trim(p_query),'') = '' or
      strpos(lower(l.title || ' ' || l.description || ' ' || o.display_name),lower(trim(p_query))) > 0)
    and (p_category is null or l.category = p_category)
    and (p_district is null or l.district = p_district)
    and (p_availability is null or l.availability = p_availability)
    and (p_after is null or l.id > p_after)
  order by l.id limit greatest(1,least(coalesce(p_limit,20),100))
$$;
-- Use existing security-definer supplier directory to avoid private organization
-- RLS hiding published listings from unrelated buyers.
create or replace function public.discover_listings(p_query text default '', p_category text default null,
  p_district text default null, p_availability text default null, p_after uuid default null,
  p_limit integer default 20) returns setof public.listings
language sql stable security definer set search_path = '' as $$
  select l.* from public.listings l
  join public.organizations o on o.id = l.organization_id
  join public.categories c on c.id = l.category
  where l.status = 'published' and o.status = 'active' and c.is_active
    and (coalesce(trim(p_query),'') = '' or
      strpos(lower(l.title || ' ' || l.description || ' ' || o.display_name),lower(trim(p_query))) > 0)
    and (p_category is null or l.category = p_category)
    and (p_district is null or l.district = p_district)
    and (p_availability is null or l.availability = p_availability)
    and (p_after is null or l.id > p_after)
  order by l.id limit greatest(1,least(coalesce(p_limit,20),100))
$$;
revoke all on function public.discover_listings(text,text,text,text,uuid,integer) from public;
grant execute on function public.discover_listings(text,text,text,text,uuid,integer) to anon, authenticated;

create table public.saved_products (
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,listing_id)
);
alter table public.saved_products enable row level security;
create policy saved_read_self on public.saved_products for select to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.saved_products from anon,authenticated;
grant select on public.saved_products to authenticated;
create function public.set_saved_product(p_listing uuid,p_saved boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_permitted' using errcode='42501'; end if;
  if p_saved is null then raise exception 'saved_required' using errcode='22023'; end if;
  if p_saved then
    if not exists(select 1 from public.listings l join public.organizations o on o.id=l.organization_id
      where l.id=p_listing and l.status='published' and o.status='active') then
      raise exception 'listing_unavailable' using errcode='22023';
    end if;
    insert into public.saved_products(user_id,listing_id) values(auth.uid(),p_listing)
      on conflict do nothing;
  else
    delete from public.saved_products where user_id=auth.uid() and listing_id=p_listing;
  end if;
end $$;

create table public.thread_blocks (
  thread_id uuid not null references public.threads(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  created_by uuid not null references auth.users(id),
  primary key(thread_id,organization_id)
);
alter table public.thread_blocks enable row level security;
revoke all on public.thread_blocks from anon,authenticated;
create function public.set_thread_block(p_thread uuid,p_blocked boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.threads; org uuid;
begin
  select * into t from public.threads where id=p_thread;
  org := case when public.is_org_member(t.buyer_organization_id) then t.buyer_organization_id
    when public.is_org_member(t.supplier_organization_id) then t.supplier_organization_id end;
  if org is null then raise exception 'not_permitted' using errcode='42501'; end if;
  if p_blocked is null then raise exception 'blocked_required' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_thread::text,0));
  if p_blocked then
    insert into public.thread_blocks values(p_thread,org,auth.uid()) on conflict do nothing;
  else delete from public.thread_blocks where thread_id=p_thread and organization_id=org;
  end if;
end $$;

-- Preserve the original RPC signature and notification semantics.
create or replace function public.send_message(p_thread uuid,p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare t public.threads; org uuid; msg uuid;
begin
  select * into t from public.threads where id=p_thread;
  org := case when public.is_org_member(t.buyer_organization_id) then t.buyer_organization_id
    when public.is_org_member(t.supplier_organization_id) then t.supplier_organization_id end;
  if org is null or not public.org_is_active(t.buyer_organization_id,'buyer')
    or not public.org_is_active(t.supplier_organization_id,'supplier') then
    raise exception 'not_permitted' using errcode='42501';
  end if;
  if p_body is null or length(trim(p_body)) not between 1 and 4000 then
    raise exception 'message_invalid' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_thread::text,0));
  if exists(select 1 from public.thread_blocks where thread_id=p_thread) then
    raise exception 'conversation_blocked' using errcode='42501';
  end if;
  -- Technical burst limit; serialize across threads for the same sender.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
  if (select count(*) from public.messages where sender_user_id=auth.uid()
    and created_at > now()-interval '1 minute') >= 30 then
    raise exception 'message_rate_limited' using errcode='P0001';
  end if;
  insert into public.messages(thread_id,sender_user_id,sender_organization_id,body)
    values(p_thread,auth.uid(),org,trim(p_body)) returning id into msg;
  perform public.notify_org(case when org=t.buyer_organization_id then t.supplier_organization_id
    else t.buyer_organization_id end,'message.received','New message',null,'thread',p_thread);
  return msg;
end $$;

create table public.support_cases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  created_by uuid not null references auth.users(id),
  subject text not null check(length(trim(subject)) between 3 and 160),
  description text not null check(length(trim(description)) between 3 and 4000),
  thread_id uuid references public.threads(id),
  status text not null default 'open' check(status in ('open','assigned','escalated','resolved')),
  assigned_to uuid references public.admin_users(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.support_replies (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.support_cases(id),
  author_id uuid not null references auth.users(id),
  body text not null check(length(trim(body)) between 1 and 4000),
  internal boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.support_cases enable row level security;
alter table public.support_replies enable row level security;
revoke all on public.support_cases,public.support_replies from anon,authenticated;
grant select on public.support_cases,public.support_replies to authenticated;
create policy support_case_read on public.support_cases for select to authenticated using(
  public.is_org_member(organization_id) or public.has_admin_permission('support.cases.view'));
create policy support_reply_read on public.support_replies for select to authenticated using(
  (not internal and exists(select 1 from public.support_cases c where c.id=case_id and public.is_org_member(c.organization_id)))
  or public.has_admin_permission('support.cases.view'));
create function public.create_support_case(p_org uuid,p_subject text,p_description text,p_thread uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if not public.is_org_member(p_org) then raise exception 'not_permitted' using errcode='42501'; end if;
  if p_thread is not null and not exists(select 1 from public.threads t where t.id=p_thread
    and p_org in(t.buyer_organization_id,t.supplier_organization_id)) then
    raise exception 'not_permitted' using errcode='42501';
  end if;
  insert into public.support_cases(organization_id,created_by,subject,description,thread_id)
    values(p_org,auth.uid(),trim(p_subject),trim(p_description),p_thread) returning id into result;
  perform public.write_audit('support.created','support_case',result,null);
  return result;
end $$;
create function public.reply_support_case(p_case uuid,p_body text,p_internal boolean default false)
returns uuid language plpgsql security definer set search_path = '' as $$
declare c public.support_cases; result uuid; staff boolean;
begin
  select * into c from public.support_cases where id=p_case for update;
  staff := public.has_admin_permission('support.cases.respond');
  if not found or not (staff or public.is_org_member(c.organization_id))
    or (coalesce(p_internal,false) and not public.has_admin_permission('support.cases.notes.manage')) then
    raise exception 'not_permitted' using errcode='42501';
  end if;
  if c.status='resolved' then raise exception 'case_resolved' using errcode='22023'; end if;
  insert into public.support_replies(case_id,author_id,body,internal)
    values(p_case,auth.uid(),trim(p_body),coalesce(p_internal,false)) returning id into result;
  perform public.write_audit('support.reply','support_case',p_case,null);
  return result;
end $$;
create function public.admin_transition_support_case(p_case uuid,p_status text,p_assignee uuid,p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.support_cases; perm text;
begin
  perm := case p_status when 'assigned' then 'support.cases.assign'
    when 'escalated' then 'support.cases.escalate' when 'resolved' then 'support.cases.resolve' end;
  if perm is null or not public.has_admin_permission(perm) then raise exception 'not_permitted' using errcode='42501'; end if;
  if length(trim(coalesce(p_reason,''))) < 8 then raise exception 'reason_required' using errcode='22023'; end if;
  select * into c from public.support_cases where id=p_case for update;
  if not found or c.status='resolved' then raise exception 'invalid_state' using errcode='22023'; end if;
  if p_status='assigned' and not exists(select 1 from public.admin_users where user_id=p_assignee and is_active) then
    raise exception 'assignee_invalid' using errcode='22023';
  end if;
  update public.support_cases set status=p_status,
    assigned_to=case when p_status='assigned' then p_assignee else assigned_to end,updated_at=now() where id=p_case;
  perform public.write_audit('support.'||p_status,'support_case',p_case,p_reason);
end $$;
revoke all on function public.set_saved_product(uuid,boolean),public.set_thread_block(uuid,boolean),
 public.create_support_case(uuid,text,text,uuid),public.reply_support_case(uuid,text,boolean),
 public.admin_transition_support_case(uuid,text,uuid,text) from public,anon;
grant execute on function public.set_saved_product(uuid,boolean),public.set_thread_block(uuid,boolean),
 public.create_support_case(uuid,text,text,uuid),public.reply_support_case(uuid,text,boolean),
 public.admin_transition_support_case(uuid,text,uuid,text) to authenticated;
