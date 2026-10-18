import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.76.1'

const supabaseUrl = requiredEnv('SUPABASE_URL')
const publishableKey = requiredEnv('SUPABASE_ANON_KEY')
const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY')
const securityPepper = requiredEnv('AUTH_SECURITY_PEPPER')
const backupSigningKey = requiredEnv('AUTH_BACKUP_SIGNING_KEY')
const turnstileSecret = requiredEnv('TURNSTILE_SECRET_KEY')
const allowedOrigins = new Set(
  requiredEnv('AUTH_ALLOWED_ORIGINS').split(',').map((value) => value.trim()),
)

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
})

type RateAction =
  | 'login'
  | 'signup'
  | 'forgot_password'
  | 'reset_password'
  | 'verify_otp'
  | 'verify_totp'
  | 'backup_code'

type RateDecision = {
  allowed: boolean
  captcha_required: boolean
  retry_after_seconds: number
}

Deno.serve(async (request) => {
  const origin = request.headers.get('origin')
  if (!origin || !allowedOrigins.has(origin)) {
    return json({ error: 'origin_not_allowed' }, 403)
  }
  if (request.method === 'OPTIONS') return corsResponse(origin)

  const route = new URL(request.url).pathname.split('/auth-api/')[1] ?? ''
  try {
    // Central middleware boundary for every current and future admin API route.
    if (route.startsWith('admin/')) {
      return await handleAdminRoute(request, origin, route)
    }
    switch (`${request.method} ${route}`) {
      case 'POST login':
        return await login(request, origin)
      case 'POST signup':
        return await signup(request, origin)
      case 'POST forgot-password':
        return await forgotPassword(request, origin)
      case 'POST reset-password':
        return await resetPassword(request, origin)
      case 'POST verify-otp':
        return await verifyEmailOtp(request, origin)
      case 'POST mfa/enroll':
        return await enrollTotp(request, origin)
      case 'POST mfa/verify':
        return await verifyTotp(request, origin)
      case 'POST mfa/backup-codes':
        return await generateBackupCodes(request, origin)
      case 'POST mfa/backup-code/verify':
        return await verifyBackupCode(request, origin)
      case 'GET session':
        return await sessionInfo(request, origin)
      case 'POST logout':
        return await logout(request, origin)
      default:
        return json({ error: 'not_found' }, 404, origin)
    }
  } catch (error) {
    console.error('auth-api request failed', error instanceof Error ? error.name : 'unknown')
    return json({ error: 'request_failed' }, 500, origin)
  }
})

async function login(request: Request, origin: string): Promise<Response> {
  const body = await readJson(request)
  const email = normalizeEmail(body.email)
  const password = stringValue(body.password)
  const context = await rateContext(request, email, 'login')
  const blocked = await enforceRateLimit(context, body.captchaToken)
  if (blocked) return withCors(blocked, origin)

  const client = publicClient()
  const captchaToken = stringValue(body.captchaToken)
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
    options: captchaToken ? { captchaToken } : undefined,
  })
  await recordAttempt(context, !error, error?.code)
  if (error || !data.session || !data.user) {
    return json({ error: 'invalid_credentials' }, 401, origin)
  }

  const isAdmin = await platformAdmin(data.user.id)
  const aal = jwtClaim(data.session.access_token, 'aal')
  const factorId = data.user.factors?.find(
    (factor) => factor.factor_type === 'totp' && factor.status === 'verified',
  )?.id
  const response = json(
    {
      authenticated: true,
      mfaRequired: isAdmin && aal !== 'aal2',
      factorId: isAdmin && aal !== 'aal2' ? factorId ?? null : null,
    },
    isAdmin && aal !== 'aal2' ? 202 : 200,
    origin,
  )
  setSessionCookies(response.headers, data.session.access_token, data.session.refresh_token)
  setCsrfCookie(response.headers)
  return response
}

async function signup(request: Request, origin: string): Promise<Response> {
  const body = await readJson(request)
  const email = normalizeEmail(body.email)
  const password = stringValue(body.password)
  const context = await rateContext(request, email, 'signup')
  const blocked = await enforceRateLimit(context, body.captchaToken)
  if (blocked) return withCors(blocked, origin)

  const passwordError = await validatePassword(password)
  if (passwordError) {
    await recordAttempt(context, false, passwordError)
    return json({ error: passwordError }, 422, origin)
  }
  const captchaToken = stringValue(body.captchaToken)
  const { data, error } = await publicClient().auth.signUp({
    email,
    password,
    options: captchaToken ? { captchaToken } : undefined,
  })
  await recordAttempt(context, !error, error?.code)
  if (error) return json({ error: 'signup_rejected' }, 400, origin)

  const response = json(
    { authenticated: data.session != null, confirmationRequired: data.session == null },
    201,
    origin,
  )
  if (data.session) {
    setSessionCookies(response.headers, data.session.access_token, data.session.refresh_token)
    setCsrfCookie(response.headers)
  }
  return response
}

async function forgotPassword(request: Request, origin: string): Promise<Response> {
  const body = await readJson(request)
  const email = normalizeEmail(body.email)
  const context = await rateContext(request, email, 'forgot_password')
  const blocked = await enforceRateLimit(context, body.captchaToken)
  if (blocked) return withCors(blocked, origin)
  const redirectTo = requiredEnv('PASSWORD_RESET_REDIRECT_URL')
  const { error } = await publicClient().auth.resetPasswordForEmail(email, {
    redirectTo,
    captchaToken: stringValue(body.captchaToken) || undefined,
  })
  await recordAttempt(context, !error, error?.code)
  // Prevent account enumeration.
  return json({ accepted: true }, 202, origin)
}

async function resetPassword(request: Request, origin: string): Promise<Response> {
  const auth = await authenticated(request, true)
  if (auth.response) return withCors(auth.response, origin)
  const body = await readJson(request)
  const password = stringValue(body.password)
  const context = await rateContext(request, auth.user!.email ?? auth.user!.id, 'reset_password')
  const blocked = await enforceRateLimit(context, body.captchaToken)
  if (blocked) return withCors(blocked, origin)
  const passwordError = await validatePassword(password)
  if (passwordError) {
    await recordAttempt(context, false, passwordError)
    return json({ error: passwordError }, 422, origin)
  }
  const { error } = await auth.client!.auth.updateUser({ password })
  await recordAttempt(context, !error, error?.code)
  return error
    ? json({ error: 'password_update_failed' }, 400, origin)
    : json({ updated: true }, 200, origin)
}

async function verifyEmailOtp(request: Request, origin: string): Promise<Response> {
  const body = await readJson(request)
  const tokenHash = stringValue(body.tokenHash)
  const type = stringValue(body.type)
  if (!['email', 'signup', 'recovery'].includes(type)) {
    return json({ error: 'invalid_otp_type' }, 400, origin)
  }
  if (type === 'recovery' && !tokenHash) {
    return json({ error: 'token_hash_required' }, 400, origin)
  }
  const email = tokenHash ? '' : normalizeEmail(body.email)
  const context = await rateContext(
    request,
    email || `token:${tokenHash.slice(0, 12)}`,
    'verify_otp',
  )
  const blocked = await enforceRateLimit(context, body.captchaToken)
  if (blocked) return withCors(blocked, origin)
  const client = publicClient()
  const verification = tokenHash
    ? await client.auth.verifyOtp({
        token_hash: tokenHash,
        type: type as 'email' | 'signup' | 'recovery',
      })
    : await client.auth.verifyOtp({
        email,
        token: stringValue(body.token),
        type: type as 'email' | 'signup',
      })
  const { data, error } = verification
  await recordAttempt(context, !error, error?.code)
  if (error || !data.session) return json({ error: 'invalid_or_expired_otp' }, 401, origin)
  const response = json({ authenticated: true }, 200, origin)
  setSessionCookies(response.headers, data.session.access_token, data.session.refresh_token)
  setCsrfCookie(response.headers)
  return response
}

async function enrollTotp(request: Request, origin: string): Promise<Response> {
  const auth = await authenticated(request, true)
  if (auth.response) return withCors(auth.response, origin)
  const { data, error } = await auth.client!.auth.mfa.enroll({ factorType: 'totp' })
  return error ? json({ error: 'mfa_enrollment_failed' }, 400, origin) : json(data, 200, origin)
}

async function verifyTotp(request: Request, origin: string): Promise<Response> {
  const auth = await authenticated(request, true)
  if (auth.response) return withCors(auth.response, origin)
  const body = await readJson(request)
  const context = await rateContext(request, auth.user!.id, 'verify_totp')
  const blocked = await enforceRateLimit(context, body.captchaToken)
  if (blocked) return withCors(blocked, origin)
  const { data: challenge, error: challengeError } = await auth.client!.auth.mfa.challenge({
    factorId: stringValue(body.factorId),
  })
  if (challengeError) {
    await recordAttempt(context, false, challengeError.code)
    return json({ error: 'mfa_challenge_failed' }, 400, origin)
  }
  const { data, error } = await auth.client!.auth.mfa.verify({
    factorId: stringValue(body.factorId),
    challengeId: challenge.id,
    code: stringValue(body.code),
  })
  await recordAttempt(context, !error, error?.code)
  if (error || !data.access_token || !data.refresh_token) {
    return json({ error: 'invalid_or_expired_totp' }, 401, origin)
  }
  const response = json({ verified: true }, 200, origin)
  setSessionCookies(response.headers, data.access_token, data.refresh_token)
  return response
}

async function generateBackupCodes(request: Request, origin: string): Promise<Response> {
  const auth = await authenticated(request, true)
  if (auth.response) return withCors(auth.response, origin)
  if (jwtClaim(auth.accessToken!, 'aal') !== 'aal2') {
    return json({ error: 'aal2_required' }, 403, origin)
  }
  const codes = Array.from({ length: 10 }, () => randomCode())
  const rows = await Promise.all(codes.map(async (code) => ({
    user_id: auth.user!.id,
    code_hash: await keyedHash(`${auth.user!.id}:${code}`),
  })))
  await admin.from('auth_backup_codes').delete().eq('user_id', auth.user!.id)
  const { error } = await admin.from('auth_backup_codes').insert(rows)
  return error
    ? json({ error: 'backup_code_generation_failed' }, 500, origin)
    : json({ codes }, 201, origin)
}

async function verifyBackupCode(request: Request, origin: string): Promise<Response> {
  const auth = await authenticated(request, true)
  if (auth.response) return withCors(auth.response, origin)
  const body = await readJson(request)
  const context = await rateContext(request, auth.user!.id, 'backup_code')
  const blocked = await enforceRateLimit(context, body.captchaToken)
  if (blocked) return withCors(blocked, origin)
  const codeHash = await keyedHash(`${auth.user!.id}:${stringValue(body.code).toUpperCase()}`)
  const { data, error } = await admin.rpc('redeem_auth_backup_code', {
    p_user_id: auth.user!.id,
    p_code_hash: codeHash,
  })
  const valid = !error && data === true
  await recordAttempt(context, valid, valid ? null : 'invalid_backup_code')
  if (!valid) return json({ error: 'invalid_backup_code' }, 401, origin)
  const response = json({ verified: true }, 200, origin)
  response.headers.append(
    'Set-Cookie',
    cookie('__Host-sl_backup', await backupGrant(auth.user!.id), 600),
  )
  return response
}

async function sessionInfo(request: Request, origin: string): Promise<Response> {
  const auth = await authenticated(request, false)
  if (auth.response) return withCors(auth.response, origin)
  const response = json({
    authenticated: true,
    email: auth.user!.email,
    aal: jwtClaim(auth.accessToken!, 'aal'),
    csrfToken: cookieValue(request, '__Host-sl_csrf'),
  }, 200, origin)
  if (auth.sessionRotated) {
    setSessionCookies(response.headers, auth.accessToken!, auth.refreshToken!)
  }
  return response
}

async function handleAdminRoute(
  request: Request,
  origin: string,
  route: string,
): Promise<Response> {
  const auth = await authenticated(request, false)
  if (auth.response) return withCors(auth.response, origin)
  if (!await platformAdmin(auth.user!.id)) return json({ allowed: false }, 403, origin)
  const aal2 = jwtClaim(auth.accessToken!, 'aal') === 'aal2'
  const backup = await validBackupGrant(request, auth.user!.id)
  if (!aal2 && !backup) {
    return json({ allowed: false, mfaRequired: true }, 403, origin)
  }
  if (`${request.method} ${route}` === 'GET admin/access') {
    return json({ allowed: true }, 200, origin)
  }
  return json({ error: 'not_found' }, 404, origin)
}

async function logout(request: Request, origin: string): Promise<Response> {
  const auth = await authenticated(request, true)
  if (auth.client) await auth.client.auth.signOut({ scope: 'local' })
  const response = json({ signedOut: true }, 200, origin)
  for (const name of ['__Host-sl_access', '__Host-sl_refresh', '__Host-sl_backup']) {
    response.headers.append('Set-Cookie', cookie(name, '', 0))
  }
  response.headers.append('Set-Cookie', cookie('__Host-sl_csrf', '', 0, false))
  return response
}

async function authenticated(request: Request, requireCsrf: boolean) {
  if (requireCsrf && !validCsrf(request)) return { response: json({ error: 'csrf_failed' }, 403) }
  const accessToken = cookieValue(request, '__Host-sl_access')
  const refreshToken = cookieValue(request, '__Host-sl_refresh')
  if (!accessToken || !refreshToken) return { response: json({ error: 'authentication_required' }, 401) }
  const client = publicClient()
  await client.auth.setSession({ access_token: accessToken, refresh_token: refreshToken })
  const { data, error } = await client.auth.getUser()
  if (error || !data.user) return { response: json({ error: 'authentication_required' }, 401) }
  const { data: sessionData } = await client.auth.getSession()
  const activeSession = sessionData.session
  if (!activeSession) return { response: json({ error: 'authentication_required' }, 401) }
  return {
    client,
    user: data.user,
    accessToken: activeSession.access_token,
    refreshToken: activeSession.refresh_token,
    sessionRotated: activeSession.access_token !== accessToken ||
      activeSession.refresh_token !== refreshToken,
  }
}

function publicClient(): SupabaseClient {
  return createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
}

async function rateContext(request: Request, account: string, action: RateAction) {
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown'
  return {
    ipHash: await keyedHash(`ip:${ip}`),
    accountHash: await keyedHash(`account:${account.toLowerCase()}`),
    action,
  }
}

async function enforceRateLimit(
  context: Awaited<ReturnType<typeof rateContext>>,
  captchaToken: unknown,
): Promise<Response | null> {
  const { data, error } = await admin.rpc('auth_rate_limit_precheck', {
    p_ip_hash: context.ipHash,
    p_account_hash: context.accountHash,
    p_action: context.action,
  })
  if (error) return json({ error: 'security_control_unavailable' }, 503)
  const decision = data as RateDecision
  if (!decision.allowed) {
    await logSecurityEvent(context, 'rate_limited')
    const response = json({ error: 'rate_limited', retryAfter: decision.retry_after_seconds }, 429)
    response.headers.set('Retry-After', String(decision.retry_after_seconds))
    return response
  }
  if (decision.captcha_required && !await verifyTurnstile(stringValue(captchaToken), context.ipHash)) {
    await recordAttempt(context, false, 'captcha_failed')
    return json({ error: 'captcha_required', captchaRequired: true }, 403)
  }
  return null
}

async function logSecurityEvent(
  context: Awaited<ReturnType<typeof rateContext>>,
  reason: string,
) {
  await admin.from('auth_security_events').insert({
    ip_hash: context.ipHash,
    account_hash: context.accountHash,
    action: context.action,
    succeeded: false,
    reason,
  })
}

async function recordAttempt(
  context: Awaited<ReturnType<typeof rateContext>>,
  succeeded: boolean,
  reason?: string | null,
) {
  await admin.rpc('auth_rate_limit_record', {
    p_ip_hash: context.ipHash,
    p_account_hash: context.accountHash,
    p_action: context.action,
    p_succeeded: succeeded,
    p_reason: reason ?? null,
  })
}

async function validatePassword(password: string): Promise<string | null> {
  if (password.length < 12) return 'password_too_short'
  if (!/[a-z]/.test(password) || !/[A-Z]/.test(password) ||
      !/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password)) {
    return 'password_missing_required_characters'
  }
  if (/password|qwerty|123456|letmein|admin/i.test(password)) return 'password_too_common'
  const digest = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(password))
  const hash = [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('').toUpperCase()
  const response = await fetch(`https://api.pwnedpasswords.com/range/${hash.slice(0, 5)}`, {
    headers: { 'Add-Padding': 'true', 'User-Agent': 'Susu-Luma-Auth/1.0' },
  })
  if (!response.ok) return 'password_breach_check_unavailable'
  const breached = (await response.text()).split('\n')
    .some((line) => line.split(':')[0] === hash.slice(5))
  return breached ? 'password_found_in_breach' : null
}

async function verifyTurnstile(token: string, remoteIpHash: string): Promise<boolean> {
  if (!token) return false
  const form = new FormData()
  form.set('secret', turnstileSecret)
  form.set('response', token)
  form.set('idempotency_key', crypto.randomUUID())
  const response = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST', body: form,
  })
  if (!response.ok) return false
  const result = await response.json()
  if (result.success !== true) console.warn('captcha rejected', remoteIpHash.slice(0, 8))
  return result.success === true
}

async function platformAdmin(userId: string): Promise<boolean> {
  const { data, error } = await admin.from('platform_admins').select('user_id').eq('user_id', userId).maybeSingle()
  return !error && data != null
}

function setSessionCookies(headers: Headers, access: string, refresh: string) {
  headers.append('Set-Cookie', cookie('__Host-sl_access', access, 3600))
  headers.append('Set-Cookie', cookie('__Host-sl_refresh', refresh, 60 * 60 * 24 * 7))
}

function setCsrfCookie(headers: Headers) {
  headers.append('Set-Cookie', cookie('__Host-sl_csrf', randomToken(32), 3600, false))
}

function validCsrf(request: Request): boolean {
  const cookieToken = cookieValue(request, '__Host-sl_csrf')
  const headerToken = request.headers.get('x-csrf-token')
  return Boolean(cookieToken && headerToken && cookieToken === headerToken)
}

function cookie(name: string, value: string, maxAge: number, httpOnly = true): string {
  return `${name}=${encodeURIComponent(value)}; Path=/; Max-Age=${maxAge}; Secure; SameSite=Strict${httpOnly ? '; HttpOnly' : ''}`
}

function cookieValue(request: Request, name: string): string | null {
  const pair = request.headers.get('cookie')?.split(';')
    .map((part) => part.trim()).find((part) => part.startsWith(`${name}=`))
  return pair ? decodeURIComponent(pair.slice(name.length + 1)) : null
}

async function backupGrant(userId: string): Promise<string> {
  const expires = Math.floor(Date.now() / 1000) + 600
  const payload = `${userId}.${expires}`
  return `${payload}.${await hmac(payload, backupSigningKey)}`
}

async function validBackupGrant(request: Request, userId: string): Promise<boolean> {
  const value = cookieValue(request, '__Host-sl_backup')
  if (!value) return false
  const [subject, expires, signature] = value.split('.')
  if (subject !== userId || Number(expires) < Date.now() / 1000) return false
  return await verifyHmac(`${subject}.${expires}`, signature, backupSigningKey)
}

async function keyedHash(value: string): Promise<string> {
  return hmac(value, securityPepper)
}

async function hmac(value: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(value))
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

async function verifyHmac(value: string, signature: string, secret: string): Promise<boolean> {
  if (!/^[a-f0-9]{64}$/.test(signature)) return false
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'],
  )
  const bytes = Uint8Array.from(signature.match(/.{2}/g)!, (byte) => Number.parseInt(byte, 16))
  return crypto.subtle.verify('HMAC', key, bytes, new TextEncoder().encode(value))
}

function jwtClaim(token: string, claim: string): unknown {
  try {
    const payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    return JSON.parse(atob(payload))[claim]
  } catch {
    return null
  }
}

function randomToken(bytes: number): string {
  const data = crypto.getRandomValues(new Uint8Array(bytes))
  return btoa(String.fromCharCode(...data)).replace(/[+/=]/g, '')
}

function randomCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  const bytes = crypto.getRandomValues(new Uint8Array(12))
  return [...bytes].map((value) => alphabet[value % alphabet.length]).join('')
}

function normalizeEmail(value: unknown): string {
  const email = stringValue(value).trim().toLowerCase()
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('invalid email')
  return email
}

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

async function readJson(request: Request): Promise<Record<string, unknown>> {
  if (!request.headers.get('content-type')?.startsWith('application/json')) {
    throw new Error('json required')
  }
  const body = await request.json()
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('invalid body')
  return body as Record<string, unknown>
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

function json(body: unknown, status = 200, origin?: string): Response {
  const headers = new Headers({
    'Content-Type': 'application/json',
    'Cache-Control': 'private, no-store',
    'Pragma': 'no-cache',
    'X-Content-Type-Options': 'nosniff',
  })
  if (origin) addCors(headers, origin)
  return new Response(JSON.stringify(body), { status, headers })
}

function withCors(response: Response, origin: string): Response {
  addCors(response.headers, origin)
  return response
}

function corsResponse(origin: string): Response {
  const headers = new Headers()
  addCors(headers, origin)
  return new Response(null, { status: 204, headers })
}

function addCors(headers: Headers, origin: string) {
  headers.set('Access-Control-Allow-Origin', origin)
  headers.set('Access-Control-Allow-Credentials', 'true')
  headers.set('Access-Control-Allow-Headers', 'content-type,x-csrf-token')
  headers.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
  headers.set('Vary', 'Origin')
}
