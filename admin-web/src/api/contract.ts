import { ApiError, type Capability, type PlatformAccess, type PlatformRole } from './types';

const ROLES: readonly PlatformRole[] = [
  'platform_admin',
  'verification_reviewer',
  'finance_officer',
  'support_agent',
  'analyst',
];
const CAPABILITIES: readonly Capability[] = ['audit.view', 'roles.manage', 'verification.review'];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Validates the JSON returned by the `my_platform_access()` RPC:
 *   { user_id, aal, mfa_satisfied, roles: [...], capabilities: [...] }
 * Unknown roles or capabilities are dropped (the server may be newer than this build).
 * Anything malformed is treated as a server error, never as access.
 */
export function parseAccess(raw: unknown): PlatformAccess {
  if (!isRecord(raw)) throw new ApiError('server', 'Unreadable access response.');
  const { user_id, aal, mfa_satisfied, roles, capabilities } = raw;
  if (typeof user_id !== 'string' || user_id.length === 0) {
    throw new ApiError('server', 'Unreadable access response.');
  }
  if (aal !== 'aal1' && aal !== 'aal2') throw new ApiError('server', 'Unreadable access response.');
  if (typeof mfa_satisfied !== 'boolean' || !Array.isArray(roles) || !Array.isArray(capabilities)) {
    throw new ApiError('server', 'Unreadable access response.');
  }
  // MFA state must agree with the session level. If the server contradicts itself, fail closed.
  if (mfa_satisfied !== (aal === 'aal2')) throw new ApiError('server', 'Inconsistent access response.');
  return {
    userId: user_id,
    aal,
    mfaSatisfied: mfa_satisfied,
    roles: roles.filter((r): r is PlatformRole => ROLES.includes(r as PlatformRole)),
    // Capabilities are only honoured for an MFA session, whatever the payload claims.
    capabilities: mfa_satisfied
      ? capabilities.filter((c): c is Capability => CAPABILITIES.includes(c as Capability))
      : [],
  };
}
