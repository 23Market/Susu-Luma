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

export function parseAccess(raw: unknown): PlatformAccess {
  if (!isRecord(raw)) throw new ApiError('server', 'Unreadable access response.');
  const { user_id, aal, mfa_satisfied, roles, capabilities } = raw;
  if (
    typeof user_id !== 'string' ||
    user_id.length === 0 ||
    (aal !== 'aal1' && aal !== 'aal2') ||
    typeof mfa_satisfied !== 'boolean' ||
    !Array.isArray(roles) ||
    !Array.isArray(capabilities)
  ) {
    throw new ApiError('server', 'Unreadable access response.');
  }
  if (mfa_satisfied !== (aal === 'aal2')) {
    throw new ApiError('server', 'Inconsistent access response.');
  }
  return {
    userId: user_id,
    aal,
    mfaSatisfied: mfa_satisfied,
    roles: roles.filter((role): role is PlatformRole => ROLES.includes(role as PlatformRole)),
    capabilities: mfa_satisfied
      ? capabilities.filter((capability): capability is Capability =>
          CAPABILITIES.includes(capability as Capability),
        )
      : [],
  };
}
