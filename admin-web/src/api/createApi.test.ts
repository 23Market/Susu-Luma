import { describe, expect, it } from 'vitest';
import { createApi, createUnconfiguredApi, type MockProvider } from './createApi';
import { createMockApi, MOCK_SCENARIOS, type MockScenario } from './mockApi';
import { ApiError } from './types';

const mock: MockProvider = {
  scenarios: MOCK_SCENARIOS,
  create: (s) => createMockApi(s as MockScenario),
};

async function kindOf(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
    return 'resolved';
  } catch (error) {
    return error instanceof ApiError ? error.kind : 'other';
  }
}

describe('createApi: mock data can never reach a production build', () => {
  it('uses mock data only when asked to in a non-production build', async () => {
    const api = createApi({ dataSource: 'mock', isProduction: false, mock });
    expect(api.source).toBe('mock');
    expect((await api.getAccess()).roles).toEqual(['verification_reviewer']);
  });

  it('ignores a mock setting in a production build', () => {
    expect(createApi({ dataSource: 'mock', isProduction: true, mock }).source).toBe('unconfigured');
  });

  it('ignores a ?scenario= override in a production build', () => {
    expect(createApi({ dataSource: 'mock', isProduction: true, scenario: 'admin', mock }).source).toBe(
      'unconfigured',
    );
  });

  it('fails closed when no mock provider was loaded, even in a development build', () => {
    expect(createApi({ dataSource: 'mock', isProduction: false }).source).toBe('unconfigured');
  });

  it.each([undefined, '', 'live', 'MOCK', 'true'])('fails closed for data source %j', (dataSource) => {
    expect(createApi({ dataSource, isProduction: false, mock }).source).toBe('unconfigured');
  });

  it('selects a known scenario and falls back to the reviewer for an unknown one', async () => {
    const admin = createApi({ dataSource: 'mock', isProduction: false, scenario: 'admin', mock });
    expect((await admin.getAccess()).roles).toEqual(['platform_admin']);
    const odd = createApi({ dataSource: 'mock', isProduction: false, scenario: '__proto__', mock });
    expect((await odd.getAccess()).roles).toEqual(['verification_reviewer']);
  });
});

describe('unconfigured API', () => {
  it('has no data and cannot sign in', async () => {
    const api = createUnconfiguredApi();
    expect(await kindOf(api.getAccess())).toBe('server');
    expect(await kindOf(api.loadSection('verification'))).toBe('server');
    expect(await kindOf(api.signIn())).toBe('server');
  });

  it('allows sign-out so a person is never trapped', async () => {
    await expect(createUnconfiguredApi().signOut()).resolves.toBeUndefined();
  });
});
