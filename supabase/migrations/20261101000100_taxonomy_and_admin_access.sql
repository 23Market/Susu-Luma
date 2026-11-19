-- Susu Luma: B2B taxonomy, admin access control (RBAC with MFA) and append-only audit.
-- Authorisation is decided here, in Postgres. The web console and Flutter app are untrusted clients.
-- Draft: review and test against dev/staging projects before any production use.

------------------------------------------------------------------------------------------
-- 1. Taxonomy (B2B categories). Admin edits go through reviewed publish steps, not client writes.
------------------------------------------------------------------------------------------
create table public.categories (
  id text primary key check (id ~ '^[a-z][a-z0-9_-]{1,40}$'),
  name text not null check (length(trim(name)) between 2 and 80),
  parent_id text references public.categories(id) on delete restrict,
  required_unit text not null check (length(trim(required_unit)) between 1 and 40),
  pre_moderate boolean not null default false,
  attributes text[] not null default '{}',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.categories enable row level security;
create policy categories_read_active on public.categories
  for select to anon, authenticated using (is_active);
revoke insert, update, delete, truncate on public.categories from anon, authenticated;

insert into public.categories (id, name, parent_id, required_unit, pre_moderate, attributes, sort_order) values
  ('construction', 'Construction', null, 'bag', false, '{"Grade / standard","Pack size","Origin"}', 10),
  ('agriculture', 'Agriculture', null, 'kg', false, '{"Variety","Moisture %","Harvest date","Origin district"}', 20),
  ('metals', 'Metals & Hardware', null, 'length', false, '{"Grade","Dimensions","Coating"}', 30),
  ('equipment', 'Equipment & Machinery', null, 'unit', true, '{"Brand","Power rating","Condition","Warranty"}', 40),
  ('food', 'Food & Beverage', null, 'carton', true, '{"Shelf life","Storage","Certification","Pack size"}', 50),
  ('energy', 'Energy & Power', null, 'unit', true, '{"Rated power","Voltage","Warranty","Certification"}', 60),
  ('packaging', 'Packaging & Office', null, 'bundle', false, '{"Material","Dimensions","Minimum order"}', 70),
  ('logistics', 'Logistics & Services', null, 'trip', false, '{"Coverage area","Vehicle type","Transit time"}', 80);
insert into public.categories (id, name, parent_id, required_unit, pre_moderate, attributes, sort_order) values
  ('construction-cement', 'Cement & aggregates', 'construction', 'bag', false, '{"Grade / standard","Pack size","Origin"}', 11),
  ('construction-roofing', 'Roofing', 'construction', 'sheet', false, '{"Grade / standard","Pack size","Origin"}', 12),
  ('agriculture-grains', 'Grains & flour', 'agriculture', 'sack', false, '{"Variety","Moisture %","Harvest date"}', 21),
  ('agriculture-cocoa', 'Cocoa & coffee', 'agriculture', 'kg', false, '{"Variety","Moisture %","Harvest date"}', 22),
  ('metals-rebar', 'Rebar & rods', 'metals', 'length', false, '{"Grade","Dimensions","Coating"}', 31),
  ('equipment-power', 'Generators & pumps', 'equipment', 'unit', true, '{"Brand","Power rating","Condition","Warranty"}', 41);

-- Listings must use a real category (the foundation schema stored free text).
alter table public.listings
  add constraint listings_category_fk foreign key (category) references public.categories(id);

------------------------------------------------------------------------------------------
-- 2. Admin RBAC. Roles and permissions are rows, never user-editable metadata.
------------------------------------------------------------------------------------------
create table public.admin_permissions (code text primary key check (code ~ '^[a-z][a-z0-9_.]+$'), description text);
create table public.admin_roles (
  code text primary key check (code ~ '^[a-z][a-z_]+$'),
  label text not null,
  all_permissions boolean not null default false
);
create table public.admin_role_permissions (
  role_code text not null references public.admin_roles(code) on delete cascade,
  permission_code text not null references public.admin_permissions(code) on delete cascade,
  primary key (role_code, permission_code)
);
-- No rows for a role = all categories. Rows restrict moderation to those categories.
create table public.admin_role_scopes (
  role_code text not null references public.admin_roles(code) on delete cascade,
  category_id text not null references public.categories(id) on delete cascade,
  primary key (role_code, category_id)
);
create table public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role_code text not null references public.admin_roles(code),
  display_name text not null check (length(trim(display_name)) between 2 and 80),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.admin_permissions enable row level security;
alter table public.admin_roles enable row level security;
alter table public.admin_role_permissions enable row level security;
alter table public.admin_role_scopes enable row level security;
alter table public.admin_users enable row level security;
revoke insert, update, delete, truncate on public.admin_permissions, public.admin_roles,
  public.admin_role_permissions, public.admin_role_scopes, public.admin_users from anon, authenticated;

-- GENERATED by supabase/tools/gen-admin-permissions.mjs from admin/app.js — do not edit by hand.
insert into public.admin_permissions (code) values
  ('analytics.definitions.manage'),
  ('analytics.export'),
  ('analytics.financial.view'),
  ('analytics.view'),
  ('audit.export'),
  ('audit.view'),
  ('catalogue.import'),
  ('catalogue.import.commit'),
  ('catalogue.import.history.view'),
  ('catalogue.import.validate'),
  ('categories.edit'),
  ('categories.publish'),
  ('categories.view'),
  ('fulfilment.evidence.view'),
  ('fulfilment.view'),
  ('listings.bulk'),
  ('listings.feature'),
  ('listings.moderate'),
  ('listings.recategorize'),
  ('listings.remove'),
  ('listings.restore'),
  ('listings.view'),
  ('locations.manage'),
  ('messaging.broadcast'),
  ('messaging.send'),
  ('orders.export'),
  ('orders.history.view'),
  ('orders.investigate'),
  ('orders.view'),
  ('organisations.members.view'),
  ('organisations.view'),
  ('overview.view'),
  ('payments.evidence.view'),
  ('payments.export'),
  ('payments.reconcile'),
  ('payments.view'),
  ('privacy.requests.assign'),
  ('privacy.requests.complete'),
  ('privacy.requests.decide'),
  ('privacy.requests.review'),
  ('privacy.requests.view'),
  ('quotes.compare'),
  ('quotes.export'),
  ('quotes.history.view'),
  ('quotes.investigate'),
  ('quotes.view'),
  ('reports.resolve'),
  ('reports.view'),
  ('revenue.view'),
  ('reviews.appeals.view'),
  ('reviews.moderate'),
  ('reviews.restore'),
  ('reviews.view'),
  ('rfqs.export'),
  ('rfqs.investigate'),
  ('rfqs.notes.manage'),
  ('rfqs.routing.view'),
  ('rfqs.view'),
  ('roles.manage'),
  ('search.cases'),
  ('search.listings'),
  ('search.orders'),
  ('search.organisations'),
  ('search.rfqs'),
  ('search.users'),
  ('support.cases.assign'),
  ('support.cases.claim'),
  ('support.cases.escalate'),
  ('support.cases.notes.manage'),
  ('support.cases.resolve'),
  ('support.cases.respond'),
  ('support.cases.view'),
  ('support.evidence.view'),
  ('system.capacity.view'),
  ('system.health.view'),
  ('system.incidents.view'),
  ('system.operations.manage'),
  ('system.recovery.view'),
  ('users.cases'),
  ('users.pii.reveal'),
  ('users.pii.search'),
  ('users.reinstate'),
  ('users.restrict'),
  ('users.suspend'),
  ('users.verify'),
  ('users.view'),
  ('verification.assign'),
  ('verification.decide'),
  ('verification.evidence.view'),
  ('verification.suspend'),
  ('verification.view')
on conflict do nothing;

insert into public.admin_roles (code, label, all_permissions) values
  ('superadmin', 'Super Admin', true),
  ('operations', 'Operations Lead', false),
  ('trust', 'Trust & Safety', false),
  ('support', 'Support', false),
  ('finance', 'Finance', false),
  ('analyst', 'Analyst', false)
on conflict do nothing;

insert into public.admin_role_permissions (role_code, permission_code) values
  ('operations', 'overview.view'),
  ('operations', 'listings.view'),
  ('operations', 'listings.moderate'),
  ('operations', 'listings.remove'),
  ('operations', 'listings.restore'),
  ('operations', 'listings.recategorize'),
  ('operations', 'listings.bulk'),
  ('operations', 'listings.feature'),
  ('operations', 'categories.view'),
  ('operations', 'categories.edit'),
  ('operations', 'categories.publish'),
  ('operations', 'rfqs.view'),
  ('operations', 'rfqs.routing.view'),
  ('operations', 'rfqs.investigate'),
  ('operations', 'rfqs.notes.manage'),
  ('operations', 'rfqs.export'),
  ('operations', 'quotes.view'),
  ('operations', 'quotes.compare'),
  ('operations', 'quotes.history.view'),
  ('operations', 'quotes.export'),
  ('operations', 'orders.view'),
  ('operations', 'orders.history.view'),
  ('operations', 'fulfilment.view'),
  ('operations', 'fulfilment.evidence.view'),
  ('operations', 'orders.investigate'),
  ('operations', 'orders.export'),
  ('operations', 'payments.view'),
  ('operations', 'organisations.view'),
  ('operations', 'organisations.members.view'),
  ('operations', 'verification.view'),
  ('operations', 'verification.evidence.view'),
  ('operations', 'verification.assign'),
  ('operations', 'verification.decide'),
  ('operations', 'support.cases.view'),
  ('operations', 'support.cases.assign'),
  ('operations', 'support.cases.claim'),
  ('operations', 'support.cases.notes.manage'),
  ('operations', 'support.cases.respond'),
  ('operations', 'support.cases.escalate'),
  ('operations', 'support.cases.resolve'),
  ('operations', 'reports.view'),
  ('operations', 'reports.resolve'),
  ('operations', 'reviews.view'),
  ('operations', 'reviews.moderate'),
  ('operations', 'analytics.view'),
  ('operations', 'analytics.export'),
  ('operations', 'catalogue.import'),
  ('operations', 'catalogue.import.validate'),
  ('operations', 'catalogue.import.commit'),
  ('operations', 'catalogue.import.history.view'),
  ('operations', 'system.health.view'),
  ('operations', 'messaging.send'),
  ('operations', 'users.view'),
  ('operations', 'search.listings'),
  ('operations', 'search.rfqs'),
  ('operations', 'search.orders'),
  ('operations', 'search.users'),
  ('operations', 'search.organisations'),
  ('operations', 'search.cases'),
  ('operations', 'audit.view'),
  ('operations', 'audit.export'),
  ('trust', 'overview.view'),
  ('trust', 'listings.view'),
  ('trust', 'listings.moderate'),
  ('trust', 'listings.remove'),
  ('trust', 'listings.restore'),
  ('trust', 'listings.recategorize'),
  ('trust', 'listings.bulk'),
  ('trust', 'reports.view'),
  ('trust', 'reports.resolve'),
  ('trust', 'rfqs.view'),
  ('trust', 'rfqs.investigate'),
  ('trust', 'quotes.view'),
  ('trust', 'quotes.investigate'),
  ('trust', 'orders.view'),
  ('trust', 'orders.investigate'),
  ('trust', 'support.cases.view'),
  ('trust', 'support.cases.assign'),
  ('trust', 'support.cases.claim'),
  ('trust', 'support.cases.notes.manage'),
  ('trust', 'support.cases.respond'),
  ('trust', 'support.cases.escalate'),
  ('trust', 'support.cases.resolve'),
  ('trust', 'support.evidence.view'),
  ('trust', 'reviews.view'),
  ('trust', 'reviews.moderate'),
  ('trust', 'reviews.restore'),
  ('trust', 'reviews.appeals.view'),
  ('trust', 'users.view'),
  ('trust', 'users.restrict'),
  ('trust', 'users.suspend'),
  ('trust', 'users.reinstate'),
  ('trust', 'verification.view'),
  ('trust', 'privacy.requests.view'),
  ('trust', 'privacy.requests.review'),
  ('trust', 'analytics.view'),
  ('trust', 'messaging.send'),
  ('trust', 'search.users'),
  ('trust', 'search.listings'),
  ('trust', 'search.cases'),
  ('trust', 'audit.view'),
  ('trust', 'audit.export'),
  ('support', 'overview.view'),
  ('support', 'users.view'),
  ('support', 'users.pii.search'),
  ('support', 'users.pii.reveal'),
  ('support', 'users.cases'),
  ('support', 'users.restrict'),
  ('support', 'users.reinstate'),
  ('support', 'users.verify'),
  ('support', 'organisations.view'),
  ('support', 'organisations.members.view'),
  ('support', 'reports.view'),
  ('support', 'listings.view'),
  ('support', 'rfqs.view'),
  ('support', 'quotes.view'),
  ('support', 'orders.view'),
  ('support', 'payments.view'),
  ('support', 'support.cases.view'),
  ('support', 'support.cases.assign'),
  ('support', 'support.cases.claim'),
  ('support', 'support.cases.notes.manage'),
  ('support', 'support.cases.respond'),
  ('support', 'support.cases.escalate'),
  ('support', 'support.cases.resolve'),
  ('support', 'support.evidence.view'),
  ('support', 'analytics.view'),
  ('support', 'messaging.send'),
  ('support', 'search.users'),
  ('support', 'search.cases'),
  ('support', 'search.orders'),
  ('finance', 'overview.view'),
  ('finance', 'revenue.view'),
  ('finance', 'payments.view'),
  ('finance', 'payments.evidence.view'),
  ('finance', 'payments.reconcile'),
  ('finance', 'payments.export'),
  ('finance', 'orders.view'),
  ('finance', 'orders.history.view'),
  ('finance', 'quotes.view'),
  ('finance', 'listings.view'),
  ('finance', 'listings.feature'),
  ('finance', 'organisations.view'),
  ('finance', 'analytics.view'),
  ('finance', 'analytics.financial.view'),
  ('finance', 'analytics.export'),
  ('finance', 'messaging.broadcast'),
  ('finance', 'search.orders'),
  ('finance', 'audit.view'),
  ('finance', 'audit.export'),
  ('analyst', 'overview.view'),
  ('analyst', 'analytics.view'),
  ('analyst', 'analytics.export'),
  ('analyst', 'listings.view'),
  ('analyst', 'users.view'),
  ('analyst', 'organisations.view'),
  ('analyst', 'rfqs.view'),
  ('analyst', 'quotes.view'),
  ('analyst', 'orders.view'),
  ('analyst', 'reviews.view'),
  ('analyst', 'search.listings'),
  ('analyst', 'search.orders')
on conflict do nothing;

insert into public.admin_role_scopes (role_code, category_id) values
  ('trust', 'construction'),
  ('trust', 'metals'),
  ('trust', 'equipment'),
  ('trust', 'energy')
on conflict do nothing;


------------------------------------------------------------------------------------------
-- 3. Permission functions. Admin power requires an active admin row AND an MFA session (aal2).
------------------------------------------------------------------------------------------
create function public.current_admin_role() returns text
language sql stable security definer set search_path = '' as $$
  select au.role_code
  from public.admin_users au
  where au.user_id = (select auth.uid())
    and au.is_active
    and coalesce((select auth.jwt()) ->> 'aal', 'aal1') = 'aal2'
$$;

create function public.has_admin_permission(p_permission text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.admin_users au
    join public.admin_roles r on r.code = au.role_code
    where au.user_id = (select auth.uid())
      and au.is_active
      and coalesce((select auth.jwt()) ->> 'aal', 'aal1') = 'aal2'
      and (r.all_permissions or exists (
        select 1 from public.admin_role_permissions rp
        where rp.role_code = r.code and rp.permission_code = p_permission))
  )
$$;

create function public.admin_is_super() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.admin_users au join public.admin_roles r on r.code = au.role_code
    where au.user_id = (select auth.uid()) and au.is_active and r.all_permissions
      and coalesce((select auth.jwt()) ->> 'aal', 'aal1') = 'aal2')
$$;

create function public.admin_in_scope(p_category text) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.current_admin_role() is not null and (
    not exists (select 1 from public.admin_role_scopes s where s.role_code = public.current_admin_role())
    or exists (select 1 from public.admin_role_scopes s
               where s.role_code = public.current_admin_role() and s.category_id = p_category))
$$;

-- A signed-in admin who holds the role but not an MFA session, or a user with no admin row, gets nothing.
create policy admin_users_read_self on public.admin_users
  for select to authenticated using (user_id = (select auth.uid()) and public.current_admin_role() is not null);
create policy admin_catalogue_read on public.admin_role_permissions
  for select to authenticated using (public.current_admin_role() is not null);
create policy admin_roles_read on public.admin_roles
  for select to authenticated using (public.current_admin_role() is not null);
create policy admin_scopes_read on public.admin_role_scopes
  for select to authenticated using (public.current_admin_role() is not null);
create policy admin_permissions_read on public.admin_permissions
  for select to authenticated using (public.current_admin_role() is not null);
create policy categories_read_admin on public.categories
  for select to authenticated using (public.has_admin_permission('categories.view'));

------------------------------------------------------------------------------------------
-- 4. Audit: append-only, readable only with audit.view; PII-access entries need Super Admin.
------------------------------------------------------------------------------------------
alter table public.audit_events
  add column severity text not null default 'info' check (severity in ('info', 'warn', 'critical')),
  add column actor_role text,
  add column request_ref text,
  add column idempotency_key text;

create function public.audit_events_append_only() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'audit_events is append-only' using errcode = '42501';
end $$;
create trigger audit_events_no_update_delete before update or delete on public.audit_events
  for each row execute function public.audit_events_append_only();
create trigger audit_events_no_truncate before truncate on public.audit_events
  for each statement execute function public.audit_events_append_only();
revoke insert, update, delete, truncate on public.audit_events from anon, authenticated;

create policy audit_read_admin on public.audit_events
  for select to authenticated using (
    public.has_admin_permission('audit.view')
    and (public.admin_is_super() or action not like '%pii%'));

-- Internal writer, callable only from other SECURITY DEFINER functions (never by clients).
create function public.write_audit(
  p_action text, p_entity_type text, p_entity_id uuid, p_reason text,
  p_severity text default 'info', p_metadata jsonb default '{}'::jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
  insert into public.audit_events (actor_user_id, actor_role, action, entity_type, entity_id, reason,
                                   severity, metadata, request_ref, idempotency_key)
  values ((select auth.uid()), public.current_admin_role(), p_action, p_entity_type, p_entity_id, nullif(p_reason, ''),
          p_severity, coalesce(p_metadata, '{}'::jsonb),
          'REQ-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)),
          p_metadata ->> 'idempotency_key')
  returning id into v_id;
  return v_id;
end $$;

-- Permission gate for admin RPCs. Returns false (and logs a refusal, durably, because nothing is raised)
-- only when the caller is a real admin lacking the permission; strangers get false without writing audit rows.
create function public.admin_guard(p_permission text, p_action text, p_entity_type text, p_entity_id uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if public.has_admin_permission(p_permission) then return true; end if;
  if exists (select 1 from public.admin_users au
             where au.user_id = (select auth.uid()) and au.is_active
               and coalesce((select auth.jwt()) ->> 'aal', 'aal1') = 'aal2') then
    perform public.write_audit('access.denied', p_entity_type, p_entity_id, 'Missing permission ' || p_permission,
                               'warn', jsonb_build_object('attempted', p_action));
  end if;
  return false;
end $$;

revoke all on function public.write_audit(text, text, uuid, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.admin_guard(text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.audit_events_append_only() from public, anon, authenticated;
grant execute on function public.current_admin_role() to authenticated;
grant execute on function public.has_admin_permission(text) to authenticated;
grant execute on function public.admin_is_super() to authenticated;
grant execute on function public.admin_in_scope(text) to authenticated;
revoke execute on function public.current_admin_role() from anon, public;
revoke execute on function public.has_admin_permission(text) from anon, public;
revoke execute on function public.admin_is_super() from anon, public;
revoke execute on function public.admin_in_scope(text) from anon, public;

------------------------------------------------------------------------------------------
-- 5. Role administration (Super Admin only). The first Super Admin is bootstrapped from the SQL
--    editor / service role: insert into public.admin_users (user_id, role_code, display_name) values (...);
------------------------------------------------------------------------------------------
create function public.admin_grant_role(p_user uuid, p_role text, p_display_name text, p_reason text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not public.admin_guard('roles.manage', 'grant_role', 'admin_user', p_user) then
    return jsonb_build_object('ok', false, 'error', 'permission_denied');
  end if;
  if length(trim(coalesce(p_reason, ''))) < 8 then return jsonb_build_object('ok', false, 'error', 'reason_required'); end if;
  if not exists (select 1 from public.admin_roles where code = p_role) then
    return jsonb_build_object('ok', false, 'error', 'unknown_role');
  end if;
  insert into public.admin_users (user_id, role_code, display_name, created_by)
  values (p_user, p_role, p_display_name, (select auth.uid()))
  on conflict (user_id) do update set role_code = excluded.role_code, display_name = excluded.display_name,
    is_active = true, updated_at = now();
  perform public.write_audit('admin.grant_role', 'admin_user', p_user, p_reason, 'critical', jsonb_build_object('role', p_role));
  return jsonb_build_object('ok', true);
end $$;

create function public.admin_revoke_role(p_user uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not public.admin_guard('roles.manage', 'revoke_role', 'admin_user', p_user) then
    return jsonb_build_object('ok', false, 'error', 'permission_denied');
  end if;
  if p_user = (select auth.uid()) then return jsonb_build_object('ok', false, 'error', 'cannot_revoke_self'); end if;
  if length(trim(coalesce(p_reason, ''))) < 8 then return jsonb_build_object('ok', false, 'error', 'reason_required'); end if;
  update public.admin_users set is_active = false, updated_at = now() where user_id = p_user;
  perform public.write_audit('admin.revoke_role', 'admin_user', p_user, p_reason, 'critical');
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.admin_grant_role(uuid, text, text, text) from public, anon;
revoke all on function public.admin_revoke_role(uuid, text) from public, anon;
grant execute on function public.admin_grant_role(uuid, text, text, text) to authenticated;
grant execute on function public.admin_revoke_role(uuid, text) to authenticated;
