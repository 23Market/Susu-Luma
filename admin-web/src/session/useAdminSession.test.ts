import { describe, expect, it } from 'vitest';
import { ApiError, type PlatformAccess } from '../api/types';
import { classifyAccess, stateFromError } from './useAdminSession';

const base: PlatformAccess = {
  userId: 'u',
  aal: 'aal2',
  mfaSatisfied: true,
  roles: ['verification_reviewer'],
  capabilities: ['verification.review'],
};

describe('classifyAccess', () => {
  it('is ready for a role with MFA', () => {
    expect(classifyAccess(base).status).toBe('ready');
  });

  it('is forbidden without any platform role, even with MFA', () => {
    expect(classifyAccess({ ...base, roles: [], capabilities: [] }).status).toBe('forbidden');
  });

  it('requires MFA for a role on a password-only session', () => {
    expect(
      classifyAccess({ ...base, aal: 'aal1', mfaSatisfied: false, capabilities: [] }).status,
    ).toBe('mfa_required');
  });

  it('prefers "forbidden" over "mfa_required" when there is no role at all', () => {
    expect(
      classifyAccess({ ...base, aal: 'aal1', mfaSatisfied: false, roles: [], capabilities: [] }).status,
    ).toBe('forbidden');
  });
});

describe('stateFromError', () => {
  it.each([
    ['unauthenticated', 'unauthenticated'],
    ['session_expired', 'expired'],
    ['forbidden', 'forbidden'],
    ['network', 'error'],
    ['server', 'error'],
  ] as const)('maps %s to %s', (kind, status) => {
    expect(stateFromError(new ApiError(kind, 'm')).status).toBe(status);
  });

  it('shows a generic message for an unknown failure and never leaks its details', () => {
    const state = stateFromError(new Error('SELECT * FROM secrets failed at 10.0.0.5'));
    expect(state).toEqual({ status: 'error', message: 'Something went wrong. Nothing was changed.' });
  });
});
