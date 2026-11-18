import { ApiError, type AdminApi, type DataSection } from './types';

export const unconfiguredApi: AdminApi = {
  source: 'unconfigured',
  async getAccess() {
    throw new ApiError('configuration', 'Admin access is not configured.');
  },
  async signIn() {
    throw new ApiError('configuration', 'Sign-in is not configured.');
  },
  async signOut() {},
  async getSection(_section: DataSection) {
    throw new ApiError('configuration', 'Admin access is not configured.');
  },
};

export async function createAdminApi(): Promise<AdminApi> {
  if (import.meta.env.MODE === 'mock') {
    const { mockApi } = await import('./mockApi');
    return mockApi;
  }
  return unconfiguredApi;
}
