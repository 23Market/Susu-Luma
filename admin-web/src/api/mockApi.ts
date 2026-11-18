import { ApiError, type AdminApi, type DataSection } from './types';

const fixtureLabel = 'MOCK_FIXTURE_ONLY';
const records = [
  {
    id: 'SYN-1001',
    subject: 'Kono Cocoa Cooperative',
    submittedAt: '2026-11-17',
    status: 'pending' as const,
    summary: 'Synthetic supplier identity review for demonstration.',
  },
  {
    id: 'SYN-1002',
    subject: 'Western Area Produce Group',
    submittedAt: '2026-11-16',
    status: 'in_review' as const,
    summary: 'Synthetic business-document review for demonstration.',
  },
];

export const mockApi: AdminApi = {
  source: 'mock',
  async getAccess() {
    void fixtureLabel;
    const scenario = new URLSearchParams(window.location.search).get('scenario');
    if (scenario === 'signed-out') throw new ApiError('unauthenticated');
    if (scenario === 'expired') throw new ApiError('expired');
    if (scenario === 'error') throw new ApiError('server');
    if (scenario === 'forbidden') {
      return {
        user_id: 'synthetic-user',
        aal: 'aal2',
        mfa_satisfied: true,
        roles: [],
        capabilities: [],
      };
    }
    if (scenario === 'mfa') {
      return {
        user_id: 'synthetic-user',
        aal: 'aal1',
        mfa_satisfied: false,
        roles: ['verification_reviewer'],
        capabilities: ['verification.review'],
      };
    }
    return {
      user_id: 'synthetic-reviewer',
      aal: 'aal2',
      mfa_satisfied: true,
      roles: ['verification_reviewer'],
      capabilities: ['verification.review'],
    };
  },
  async signIn() {},
  async signOut() {},
  async getSection(section: DataSection) {
    const access = (await this.getAccess()) as { capabilities: string[] };
    const required = section === 'verification' ? 'verification.review' : 'audit.view';
    if (!access.capabilities.includes(required)) throw new ApiError('forbidden');
    return section === 'verification' ? records : [];
  },
};
