import { describe, expect, it } from 'vitest';
import { parseAccess } from './contract';
import { ApiError } from './types';

const USER = '00000000-0000-4000-8000-0000000000aa';
const valid = {
  user_id: USER,
  aal: 'aal2',
  mfa_satisfied: true,
  roles: ['verification_reviewer'],
  capabilities: ['verification.review'],
};

describe('parseAccess (my_platform_access() contract)', () => {
  it('maps a well-formed MFA session', () => {
    expect(parseAccess(valid)).toEqual({
      userId: USER,
      aal: 'aal2',
      mfaSatisfied: true,
      roles: ['verification_reviewer'],
      capabilities: ['verification.review'],
    });
  });

  it('drops roles and capabilities this build does not know about', () => {
    const access = parseAccess({
      ...valid,
      roles: ['verification_reviewer', 'super_admin_from_the_future'],
      capabilities: ['verification.review', 'payments.release'],
    });
    expect(access.roles).toEqual(['verification_reviewer']);
    expect(access.capabilities).toEqual(['verification.review']);
  });

  it('never honours capabilities for a session without MFA, whatever the payload says', () => {
    const access = parseAccess({
      ...valid,
      aal: 'aal1',
      mfa_satisfied: false,
      capabilities: ['verification.review', 'audit.view', 'roles.manage'],
    });
    expect(access.mfaSatisfied).toBe(false);
    expect(access.capabilities).toEqual([]);
  });

  it('fails closed when the server contradicts itself about MFA', () => {
    expect(() => parseAccess({ ...valid, aal: 'aal1', mfa_satisfied: true })).toThrow(ApiError);
    expect(() => parseAccess({ ...valid, aal: 'aal2', mfa_satisfied: false })).toThrow(ApiError);
  });

  it.each([
    ['null', null],
    ['a string', 'platform_admin'],
    ['an array', []],
    ['an empty object', {}],
    ['a missing user id', { ...valid, user_id: undefined }],
    ['an empty user id', { ...valid, user_id: '' }],
    ['an unknown aal', { ...valid, aal: 'aal3' }],
    ['a non-boolean mfa flag', { ...valid, mfa_satisfied: 'true' }],
    ['roles that are not a list', { ...valid, roles: 'platform_admin' }],
    ['capabilities that are not a list', { ...valid, capabilities: { 'audit.view': true } }],
  ])('treats %s as a server error, never as access', (_name, payload) => {
    try {
      parseAccess(payload);
      throw new Error('should have thrown');
    } catch (error) {
      expect(error).toBeInstanceOf(ApiError);
      expect((error as ApiError).kind).toBe('server');
    }
  });

  it('does not read client-controlled metadata fields', () => {
    const access = parseAccess({
      ...valid,
      roles: [],
      capabilities: [],
      app_metadata: { role: 'platform_admin' },
      user_metadata: { role: 'platform_admin' },
    });
    expect(access.roles).toEqual([]);
    expect(access.capabilities).toEqual([]);
  });
});
