begin;

select plan(15);

select has_table('public', 'auth_rate_buckets', 'rate-limit buckets exist');
select has_table('public', 'auth_security_events', 'security event log exists');
select has_table('public', 'auth_backup_codes', 'backup-code store exists');
select has_table('public', 'auth_account_lockouts', 'provider lockout store exists');

select has_function(
  'public',
  'auth_rate_limit_precheck',
  array['text', 'text', 'text'],
  'rate-limit precheck function exists'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.auth_rate_limit_precheck(text, text, text)',
    'execute'
  ),
  'anonymous clients cannot execute the rate limiter'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.auth_rate_limit_precheck(text, text, text)',
    'execute'
  ),
  'the service role can execute the rate limiter'
);

select is(
  (public.auth_rate_limit_precheck(
    repeat('a', 64), repeat('b', 64), 'login'
  )->>'allowed')::boolean,
  true,
  'the first login attempt is allowed'
);

select public.auth_rate_limit_record(
  repeat('c', 64), repeat('d', 64), 'login', false, 'test_failure'
) from generate_series(1, 3);

select is(
  (public.auth_rate_limit_precheck(
    repeat('c', 64), repeat('d', 64), 'login'
  )->>'captcha_required')::boolean,
  true,
  'CAPTCHA is required after three failures'
);

select public.auth_rate_limit_precheck(
  repeat('e', 64), repeat('f', 64), 'signup'
) from generate_series(1, 5);

select is(
  (public.auth_rate_limit_precheck(
    repeat('e', 64), repeat('f', 64), 'signup'
  )->>'allowed')::boolean,
  false,
  'the sixth attempt inside 15 minutes is denied'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '10000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'security-test@example.invalid',
  'not-a-real-password',
  now(),
  now(),
  now()
);

insert into public.auth_backup_codes (user_id, code_hash)
values (
  '10000000-0000-0000-0000-000000000001',
  repeat('1', 64)
);

select is(
  public.redeem_auth_backup_code(
    '10000000-0000-0000-0000-000000000001', repeat('1', 64)
  ),
  true,
  'an unused backup code can be redeemed'
);

select is(
  public.redeem_auth_backup_code(
    '10000000-0000-0000-0000-000000000001', repeat('1', 64)
  ),
  false,
  'a redeemed backup code cannot be reused'
);

select is(
  public.hook_password_verification_attempt(
    '{"user_id":"10000000-0000-0000-0000-000000000001","valid":false}'::jsonb
  )->>'decision',
  'continue',
  'the provider password hook records a failed verification'
);

insert into public.platform_admins (user_id)
values ('10000000-0000-0000-0000-000000000001');

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',
  true
);

select is(
  public.is_platform_admin_aal2(),
  true,
  'an AAL2 platform administrator is authorized'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',
  true
);

select is(
  public.is_platform_admin_aal2(),
  false,
  'an AAL1 platform administrator is denied'
);

select * from finish();
rollback;
