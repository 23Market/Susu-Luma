-- Server-only authentication abuse controls for the same-origin auth API.
-- Apply after marketplace_foundation. Hash IP and account identifiers in the
-- Edge Function before passing them to these functions.

create table public.auth_rate_buckets (
  key_hash text not null,
  action text not null check (action in (
    'login', 'signup', 'forgot_password', 'reset_password',
    'verify_otp', 'verify_totp', 'backup_code'
  )),
  window_started_at timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  failures integer not null default 0 check (failures >= 0),
  last_failed_at timestamptz,
  locked_until timestamptz,
  primary key (key_hash, action)
);

create table public.auth_security_events (
  id bigint generated always as identity primary key,
  ip_hash text not null,
  account_hash text,
  action text not null,
  succeeded boolean not null,
  reason text,
  created_at timestamptz not null default now()
);
create index auth_security_events_created_idx
  on public.auth_security_events (created_at desc);

create table public.auth_backup_codes (
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  created_at timestamptz not null default now(),
  used_at timestamptz,
  primary key (user_id, code_hash)
);

create table public.auth_account_lockouts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  failed_attempts integer not null default 0 check (failed_attempts >= 0),
  last_failed_at timestamptz,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.auth_rate_buckets enable row level security;
alter table public.auth_security_events enable row level security;
alter table public.auth_backup_codes enable row level security;
alter table public.auth_account_lockouts enable row level security;

-- There are deliberately no client policies on these tables. Only the
-- service-role Edge Function and the functions below may access them.

create or replace function public.auth_rate_limit_precheck(
  p_ip_hash text,
  p_account_hash text,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_time timestamptz := now();
  bucket_key text;
  bucket public.auth_rate_buckets%rowtype;
  allowed boolean := true;
  captcha_required boolean := false;
  retry_after_seconds integer := 0;
  delay_seconds integer;
begin
  if p_action not in (
    'login', 'signup', 'forgot_password', 'reset_password',
    'verify_otp', 'verify_totp', 'backup_code'
  ) then
    raise exception 'unsupported authentication action' using errcode = '22023';
  end if;

  foreach bucket_key in array array[p_ip_hash, p_account_hash]
  loop
    continue when bucket_key is null or length(bucket_key) < 32;

    insert into public.auth_rate_buckets (key_hash, action)
    values (bucket_key, p_action)
    on conflict (key_hash, action) do nothing;

    select * into bucket
    from public.auth_rate_buckets
    where key_hash = bucket_key and action = p_action
    for update;

    if bucket.window_started_at <= current_time - interval '15 minutes' then
      update public.auth_rate_buckets
      set window_started_at = current_time,
          attempts = 0,
          failures = 0,
          last_failed_at = null,
          locked_until = null
      where key_hash = bucket_key and action = p_action
      returning * into bucket;
    end if;

    captcha_required := captcha_required or bucket.failures >= 3;
    if bucket.locked_until is not null and bucket.locked_until > current_time then
      allowed := false;
      retry_after_seconds := greatest(
        retry_after_seconds,
        ceil(extract(epoch from bucket.locked_until - current_time))::integer
      );
    end if;

    if bucket.last_failed_at is not null and bucket.failures > 0 then
      delay_seconds := least(300, power(2, least(bucket.failures - 1, 8))::integer);
      if bucket.last_failed_at + make_interval(secs => delay_seconds) > current_time then
        allowed := false;
        retry_after_seconds := greatest(
          retry_after_seconds,
          ceil(extract(epoch from (
            bucket.last_failed_at + make_interval(secs => delay_seconds) - current_time
          )))::integer
        );
      end if;
    end if;

    if bucket.attempts >= 5 then
      allowed := false;
      retry_after_seconds := greatest(
        retry_after_seconds,
        ceil(extract(epoch from (
          bucket.window_started_at + interval '15 minutes' - current_time
        )))::integer
      );
    elsif allowed then
      update public.auth_rate_buckets
      set attempts = attempts + 1
      where key_hash = bucket_key and action = p_action;
    end if;
  end loop;

  return jsonb_build_object(
    'allowed', allowed,
    'captcha_required', captcha_required,
    'retry_after_seconds', greatest(0, retry_after_seconds)
  );
end;
$$;

create or replace function public.auth_rate_limit_record(
  p_ip_hash text,
  p_account_hash text,
  p_action text,
  p_succeeded boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  bucket_key text;
begin
  foreach bucket_key in array array[p_ip_hash, p_account_hash]
  loop
    continue when bucket_key is null or length(bucket_key) < 32;
    insert into public.auth_rate_buckets (
      key_hash, action, attempts, failures, last_failed_at
    ) values (
      bucket_key,
      p_action,
      1,
      case when p_succeeded then 0 else 1 end,
      case when p_succeeded then null else now() end
    )
    on conflict (key_hash, action) do update
    set failures = case
          when p_succeeded then 0
          else public.auth_rate_buckets.failures + 1
        end,
        last_failed_at = case when p_succeeded then null else now() end,
        locked_until = case
          when p_succeeded then null
          when public.auth_rate_buckets.failures + 1 >= 5
            then now() + interval '30 minutes'
          else public.auth_rate_buckets.locked_until
        end;
  end loop;

  insert into public.auth_security_events (
    ip_hash, account_hash, action, succeeded, reason
  ) values (
    p_ip_hash, p_account_hash, p_action, p_succeeded, left(p_reason, 240)
  );
end;
$$;

create or replace function public.redeem_auth_backup_code(
  p_user_id uuid,
  p_code_hash text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  redeemed_count integer;
begin
  update public.auth_backup_codes
  set used_at = now()
  where user_id = p_user_id
    and code_hash = p_code_hash
    and used_at is null;
  get diagnostics redeemed_count = row_count;
  return redeemed_count = 1;
end;
$$;

revoke all on function public.auth_rate_limit_precheck(text, text, text) from public;
revoke all on function public.auth_rate_limit_record(text, text, text, boolean, text) from public;
revoke all on function public.redeem_auth_backup_code(uuid, text) from public;
grant execute on function public.auth_rate_limit_precheck(text, text, text) to service_role;
grant execute on function public.auth_rate_limit_record(text, text, text, boolean, text) to service_role;
grant execute on function public.redeem_auth_backup_code(uuid, text) to service_role;

-- Optional Supabase Password Verification Hook. Enable this hook in the hosted
-- project so password attempts that bypass the BFF still receive account
-- lockout and exponential backoff. Supabase exposes this hook on eligible plans.
create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  subject uuid := (event->>'user_id')::uuid;
  password_valid boolean := coalesce((event->>'valid')::boolean, false);
  state public.auth_account_lockouts%rowtype;
  delay_seconds integer;
begin
  insert into public.auth_account_lockouts (user_id)
  values (subject)
  on conflict (user_id) do nothing;

  select * into state
  from public.auth_account_lockouts
  where user_id = subject
  for update;

  if state.locked_until is not null and state.locked_until > now() then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'Sign-in is temporarily locked. Try again later.',
      'should_logout_user', false
    );
  end if;

  if state.last_failed_at is not null and state.failed_attempts > 0 then
    delay_seconds := least(300, power(2, least(state.failed_attempts - 1, 8))::integer);
    if state.last_failed_at + make_interval(secs => delay_seconds) > now() then
      return jsonb_build_object(
        'decision', 'reject',
        'message', 'Wait before trying to sign in again.',
        'should_logout_user', false
      );
    end if;
  end if;

  if password_valid then
    update public.auth_account_lockouts
    set failed_attempts = 0,
        last_failed_at = null,
        locked_until = null,
        updated_at = now()
    where user_id = subject;
  else
    update public.auth_account_lockouts
    set failed_attempts = failed_attempts + 1,
        last_failed_at = now(),
        locked_until = case
          when failed_attempts + 1 >= 5 then now() + interval '30 minutes'
          else locked_until
        end,
        updated_at = now()
    where user_id = subject;
  end if;

  insert into public.auth_security_events (
    ip_hash, account_hash, action, succeeded, reason
  ) values (
    'provider-hook-no-ip',
    encode(public.digest(subject::text, 'sha256'), 'hex'),
    'login',
    password_valid,
    case when password_valid then null else 'invalid_password' end
  );

  return jsonb_build_object('decision', 'continue');
end;
$$;

revoke all on function public.hook_password_verification_attempt(jsonb) from public;
grant execute on function public.hook_password_verification_attempt(jsonb)
  to supabase_auth_admin;

-- Every platform-admin database policy is additionally constrained to AAL2.
-- This function is used by future restrictive policies and server RPCs.
create or replace function public.is_platform_admin_aal2()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((auth.jwt()->>'aal') = 'aal2', false)
    and exists (
      select 1 from public.platform_admins administrator
      where administrator.user_id = (select auth.uid())
    );
$$;

revoke all on function public.is_platform_admin_aal2() from public;
grant execute on function public.is_platform_admin_aal2() to authenticated;

-- Supersede the earlier role-only helper so no admin check can omit AAL2.
drop function if exists public.is_platform_admin();
