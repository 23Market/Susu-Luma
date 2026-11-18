import { ApiError, type AdminApi } from './types';

/** Fails closed: nothing is readable, nothing can be signed into. */
export function createUnconfiguredApi(): AdminApi {
  const refuse = (): never => {
    throw new ApiError('server', 'The secure admin service is not configured. No data is available.');
  };
  return {
    source: 'unconfigured',
    getAccess: async () => refuse(),
    loadSection: async () => refuse(),
    signIn: async () => refuse(),
    signOut: async () => undefined,
  };
}

/**
 * Supplies mock data. It is injected, never imported here, so that a production build does not
 * contain the mock records at all (main.tsx only loads the mock module in development).
 */
export interface MockProvider {
  scenarios: readonly string[];
  create(scenario: string): AdminApi;
}

export interface CreateApiOptions {
  /** Value of VITE_ADMIN_DATA_SOURCE. */
  dataSource: string | undefined;
  /** True in production builds. Mock data is ignored there, whatever the configuration says. */
  isProduction: boolean;
  /** Optional ?scenario= value (development only). */
  scenario?: string | null;
  /** Present in development builds only. */
  mock?: MockProvider;
}

export function createApi({ dataSource, isProduction, scenario, mock }: CreateApiOptions): AdminApi {
  if (dataSource === 'mock' && !isProduction && mock) {
    const chosen = mock.scenarios.find((s) => s === scenario) ?? 'reviewer';
    return mock.create(chosen);
  }
  // A live Supabase adapter is intentionally NOT part of this foundation. It needs the isolated
  // Supabase project (B2) and an approved contract. Until then everything else fails closed.
  return createUnconfiguredApi();
}
