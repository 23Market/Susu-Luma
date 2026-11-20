import { describe, expect, it } from 'vitest';
import { createMockApi, MOCK_SCENARIOS } from './mockApi';
import { ApiError } from './types';

async function kindOf(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
    return 'resolved';
  } catch (error) {
    return error instanceof ApiError ? error.kind : 'other';
  }
}

describe('mock server: authorisation lives in the "server", not in the UI', () => {
  it('lets a verification reviewer read the queue but refuses the audit log', async () => {
    const api = createMockApi('reviewer');
    expect(api.source).toBe('mock');
    expect((await api.loadSection('verification')).rows.length).toBeGreaterThan(0);
    expect(await kindOf(api.loadSection('audit'))).toBe('forbidden');
  });

  it('lets a platform admin read the audit log but refuses the verification queue', async () => {
    const api = createMockApi('admin');
    expect((await api.loadSection('audit')).rows.length).toBeGreaterThan(0);
    expect(await kindOf(api.loadSection('verification'))).toBe('forbidden');
  });

  it('refuses every module for a role that has no capability yet (finance)', async () => {
    const api = createMockApi('finance');
    expect((await api.getAccess()).roles).toEqual(['finance_officer']);
    expect(await kindOf(api.loadSection('verification'))).toBe('forbidden');
    expect(await kindOf(api.loadSection('audit'))).toBe('forbidden');
  });

  it('refuses every module for an account with no platform role', async () => {
    const api = createMockApi('no_role');
    expect((await api.getAccess()).roles).toEqual([]);
    expect(await kindOf(api.loadSection('verification'))).toBe('forbidden');
  });

  it('refuses data to a privileged account whose session has no MFA', async () => {
    const api = createMockApi('no_mfa');
    const access = await api.getAccess();
    expect(access.roles).toEqual(['verification_reviewer']);
    expect(access.capabilities).toEqual([]);
    expect(await kindOf(api.loadSection('verification'))).toBe('forbidden');
  });

  it('reports a signed-out visitor as unauthenticated for every call', async () => {
    const api = createMockApi('signed_out');
    expect(await kindOf(api.getAccess())).toBe('unauthenticated');
    expect(await kindOf(api.loadSection('verification'))).toBe('unauthenticated');
  });

  it('reports a lapsed session as session_expired until the person signs in again', async () => {
    const api = createMockApi('expired');
    expect(await kindOf(api.getAccess())).toBe('session_expired');
    await api.signIn();
    expect((await api.getAccess()).roles).toEqual(['verification_reviewer']);
  });

  it('revokes data access immediately on sign-out', async () => {
    const api = createMockApi('reviewer');
    expect((await api.loadSection('verification')).rows.length).toBeGreaterThan(0);
    await api.signOut();
    expect(await kindOf(api.loadSection('verification'))).toBe('unauthenticated');
  });

  it('surfaces a network failure as a distinct error kind', async () => {
    expect(await kindOf(createMockApi('error').getAccess())).toBe('network');
  });

  it('contains only synthetic records', async () => {
    const all = JSON.stringify([
      await createMockApi('reviewer').loadSection('verification'),
      await createMockApi('admin').loadSection('audit'),
    ]);
    expect(all).toMatch(/synthetic/i);
    expect(all).not.toMatch(/@[a-z0-9-]+\.[a-z]{2,}/i); // no email addresses
    // No phone-like numbers (international "+232 …" form, or 3-3-4 digit groups). ISO dates are fine.
    expect(all).not.toMatch(/\+\d[\d\s-]{7,}|\b\d{3}[\s-]\d{3}[\s-]\d{3,4}\b/);
  });

  it('covers every documented scenario', () => {
    expect([...MOCK_SCENARIOS].sort()).toEqual(
      ['admin', 'error', 'expired', 'finance', 'no_mfa', 'no_role', 'reviewer', 'signed_out'].sort(),
    );
  });
});
