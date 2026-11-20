/**
 * Contract between the web Admin console and the server.
 *
 * The browser NEVER decides who may do what. It asks the server (Supabase RPC
 * `my_platform_access()`, defined in supabase/migrations/20261118000100_verification_risk_policy.sql
 * on PR #76) and renders what comes back. Every data call is authorised again on the server
 * (RLS and SECURITY DEFINER functions), and a refusal from the server is final.
 */

export type PlatformRole =
  | 'platform_admin'
  | 'verification_reviewer'
  | 'finance_officer'
  | 'support_agent'
  | 'analyst';

/** Capabilities the server currently advertises. Nothing is listed that is not implemented. */
export type Capability = 'audit.view' | 'roles.manage' | 'verification.review';

export interface PlatformAccess {
  userId: string;
  aal: 'aal1' | 'aal2';
  /** True only for an MFA (aal2) session. Capabilities are empty otherwise. */
  mfaSatisfied: boolean;
  roles: PlatformRole[];
  capabilities: Capability[];
}

export type SectionId = 'overview' | 'verification' | 'audit';
export type DataSection = Exclude<SectionId, 'overview'>;

export interface SectionTable {
  title: string;
  columns: string[];
  rows: string[][];
  /** ISO timestamp supplied by the server. */
  updatedAt: string;
}

/** `unconfigured` fails closed: no data, no sign-in, nothing to click through. */
export type DataSource = 'mock' | 'live' | 'unconfigured';

export type ApiErrorKind =
  | 'unauthenticated' // no session (HTTP 401 / Postgres 28000)
  | 'session_expired' // session existed and lapsed (HTTP 401 with expiry)
  | 'forbidden' // authenticated but not allowed (HTTP 403 / Postgres 42501)
  | 'network' // could not reach the server
  | 'server'; // the server answered with an error or an unreadable response

export class ApiError extends Error {
  readonly kind: ApiErrorKind;
  constructor(kind: ApiErrorKind, message: string) {
    super(message);
    this.name = 'ApiError';
    this.kind = kind;
  }
}

export interface AdminApi {
  readonly source: DataSource;
  /** Maps to the `my_platform_access()` RPC. */
  getAccess(): Promise<PlatformAccess>;
  /**
   * Maps to `reviewer_list_verification_cases()` and an RLS-limited read of `audit_events`.
   * The server throws `forbidden` when the caller lacks the capability.
   */
  loadSection(section: DataSection): Promise<SectionTable>;
  signIn(): Promise<void>;
  signOut(): Promise<void>;
}

/** Which capability a module needs. Used ONLY to decide which menu entries to offer. */
export const SECTION_CAPABILITY: Record<DataSection, Capability> = {
  verification: 'verification.review',
  audit: 'audit.view',
};

export const SECTION_LABEL: Record<SectionId, string> = {
  overview: 'Overview',
  verification: 'Verification queue',
  audit: 'Audit log',
};
