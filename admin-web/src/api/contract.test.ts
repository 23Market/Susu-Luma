import { describe, expect, it } from 'vitest';
import { parseAccess } from './contract';
import { ApiError } from './types';

const response = {
  user_id: 'staff-1',
  aal: 'aal2',
  mfa_satisfied: true,
  roles: ['verification_reviewer'],
  capabilities: ['verification.review'],
};

describe('parseAccess', () => {
  it('accepts a valid server-provided permission response', () => {
    expect(parseAccess(response)).toEqual({
      userId: 'staff-1',
      aal: 'aal2',
      mfaSatisfied: true,
      roles: ['verification_reviewer'],
      capabilities: ['verification.review'],
    });
  });

  it('drops unknown roles and capabilities instead of granting them', () => {
    expect(parseAccess({ ...response, roles: ['root'], capabilities: ['all'] })).toMatchObject({
      roles: [],
      capabilities: [],
    });
  });

  it('never honors capabilities without MFA', () => {
    expect(
      parseAccess({
        ...response,
        aal: 'aal1',
        mfa_satisfied: false,
        capabilities: ['verification.review'],
      }).capabilities,
    ).toEqual([]);
  });

  it.each([null, [], {}, { ...response, user_id: '' }, { ...response, aal: 'aal3' }])(
    'rejects malformed responses',
    (value) => {
      expect(() => parseAccess(value)).toThrow(ApiError);
    },
  );

  it('fails closed when the MFA claim contradicts the session assurance level', () => {
    expect(() => parseAccess({ ...response, aal: 'aal1' })).toThrow(/Inconsistent/);
  });
});
