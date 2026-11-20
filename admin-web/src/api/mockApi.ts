import { parseAccess } from './contract';
import {
  ApiError,
  SECTION_CAPABILITY,
  type AdminApi,
  type DataSection,
  type SectionTable,
} from './types';

/**
 * MOCK DATA ONLY. Synthetic records, no network, no credentials, no live service.
 * The "server" half of this file (`serverAccess`, `serverLoad`) plays the part of Supabase:
 * it decides, and the UI only renders. It is never bundled into a production build's data
 * path (see createApi).
 */
export type MockScenario =
  | 'reviewer'
  | 'admin'
  | 'finance'
  | 'no_role'
  | 'no_mfa'
  | 'signed_out'
  | 'expired'
  | 'error';

export const MOCK_SCENARIOS: readonly MockScenario[] = [
  'reviewer',
  'admin',
  'finance',
  'no_role',
  'no_mfa',
  'signed_out',
  'expired',
  'error',
];

const USER = '00000000-0000-4000-8000-000000000001';

// Shapes copied from the SQL function's output.
const RAW: Record<Exclude<MockScenario, 'signed_out' | 'expired' | 'error'>, unknown> = {
  reviewer: {
    user_id: USER,
    aal: 'aal2',
    mfa_satisfied: true,
    roles: ['verification_reviewer'],
    capabilities: ['verification.review'],
  },
  admin: {
    user_id: USER,
    aal: 'aal2',
    mfa_satisfied: true,
    roles: ['platform_admin'],
    capabilities: ['audit.view', 'roles.manage'],
  },
  finance: {
    user_id: USER,
    aal: 'aal2',
    mfa_satisfied: true,
    roles: ['finance_officer'],
    capabilities: [],
  },
  no_role: { user_id: USER, aal: 'aal2', mfa_satisfied: true, roles: [], capabilities: [] },
  no_mfa: {
    user_id: USER,
    aal: 'aal1',
    mfa_satisfied: false,
    roles: ['verification_reviewer'],
    capabilities: [],
  },
};

const VERIFICATION: SectionTable = {
  title: 'Verification queue',
  columns: ['Reference', 'Organisation (synthetic)', 'Status', 'Risk', 'Second review'],
  rows: [
    ['VC-0001', 'Synthetic Supplier A', 'pending', 'standard', 'not required'],
    ['VC-0002', 'Synthetic Supplier B', 'awaiting_second_review', 'high', 'required'],
    ['VC-0003', 'Synthetic Supplier C', 'in_review', 'high', 'required'],
  ],
  updatedAt: '2026-11-18T00:00:00Z',
};

const AUDIT: SectionTable = {
  title: 'Audit log',
  columns: ['Time (UTC)', 'Action', 'Entity', 'Actor (synthetic)'],
  rows: [
    ['2026-11-18T08:01:00Z', 'verification.submitted', 'supplier_verification_case', 'user-a'],
    ['2026-11-18T08:07:00Z', 'verification.first_approval', 'supplier_verification_case', 'user-b'],
    ['2026-11-18T08:09:00Z', 'platform_role.granted', 'platform_role', 'user-c'],
  ],
  updatedAt: '2026-11-18T00:00:00Z',
};

export function createMockApi(scenario: MockScenario): AdminApi {
  let signedIn = scenario !== 'signed_out' && scenario !== 'expired';
  const raw = (): unknown => {
    if (scenario === 'signed_out' || scenario === 'expired') return RAW.reviewer;
    if (scenario === 'error') throw new ApiError('network', 'Mock network failure.');
    return RAW[scenario];
  };

  // ---- "server" side: authoritative decisions live here, not in the UI ----
  const serverAccess = () => {
    if (!signedIn) {
      throw new ApiError(
        scenario === 'expired' ? 'session_expired' : 'unauthenticated',
        scenario === 'expired' ? 'Session expired.' : 'Not signed in.',
      );
    }
    return parseAccess(raw());
  };
  const serverLoad = (section: DataSection): SectionTable => {
    const access = serverAccess();
    if (!access.mfaSatisfied || !access.capabilities.includes(SECTION_CAPABILITY[section])) {
      throw new ApiError('forbidden', 'The server refused this request.');
    }
    return section === 'verification' ? VERIFICATION : AUDIT;
  };

  return {
    source: 'mock',
    getAccess: async () => serverAccess(),
    loadSection: async (section) => serverLoad(section),
    signIn: async () => {
      signedIn = true;
    },
    signOut: async () => {
      signedIn = false;
    },
  };
}
