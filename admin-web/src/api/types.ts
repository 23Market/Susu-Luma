export type PlatformRole =
  | 'platform_admin'
  | 'verification_reviewer'
  | 'finance_officer'
  | 'support_agent'
  | 'analyst';

export type Capability = 'audit.view' | 'roles.manage' | 'verification.review';
export type DataSection = 'verification' | 'audit';
export type SectionId = 'overview' | DataSection;
export type ApiErrorKind = 'unauthenticated' | 'expired' | 'forbidden' | 'configuration' | 'server';

export interface PlatformAccess {
  userId: string;
  aal: 'aal1' | 'aal2';
  mfaSatisfied: boolean;
  roles: PlatformRole[];
  capabilities: Capability[];
}

export interface QueueItem {
  id: string;
  subject: string;
  submittedAt: string;
  status: 'pending' | 'in_review' | 'complete';
  summary: string;
}

export class ApiError extends Error {
  constructor(
    readonly kind: ApiErrorKind,
    message = 'The administration service is unavailable.',
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export interface AdminApi {
  readonly source: 'live' | 'mock' | 'unconfigured';
  getAccess(): Promise<unknown>;
  signIn(): Promise<void>;
  signOut(): Promise<void>;
  getSection(section: DataSection): Promise<QueueItem[]>;
}

export const SECTION_CAPABILITY: Record<DataSection, Capability> = {
  verification: 'verification.review',
  audit: 'audit.view',
};

export const SECTION_LABEL: Record<SectionId, string> = {
  overview: 'Overview',
  verification: 'Verification queue',
  audit: 'Audit trail',
};
