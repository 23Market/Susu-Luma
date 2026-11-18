import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import App from './App';
import { ApiError, type AdminApi } from './api/types';

const access = {
  user_id: 'reviewer-1',
  aal: 'aal2',
  mfa_satisfied: true,
  roles: ['verification_reviewer'],
  capabilities: ['verification.review'],
};
const row = {
  id: 'SYN-2001',
  subject: 'Demo supplier',
  submittedAt: '2026-11-18',
  status: 'pending' as const,
  summary: 'Synthetic record',
};

function api(overrides: Partial<AdminApi> = {}): AdminApi {
  return {
    source: 'unconfigured',
    getAccess: vi.fn().mockResolvedValue(access),
    signIn: vi.fn().mockResolvedValue(undefined),
    signOut: vi.fn().mockResolvedValue(undefined),
    getSection: vi.fn().mockResolvedValue([row]),
    ...overrides,
  };
}

afterEach(() => {
  window.location.hash = '';
  window.history.replaceState(null, '', '/');
});

describe('admin shell and session states', () => {
  it('renders only the server-capability navigation and labels mock data', async () => {
    render(<App api={api({ source: 'mock' })} />);
    expect(await screen.findByRole('heading', { name: 'Overview' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Verification queue' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Audit trail' })).not.toBeInTheDocument();
    expect(screen.getByRole('note')).toHaveTextContent('MOCK DATA');
  });

  it.each([
    ['unauthenticated', 'Sign in to Luma administration'],
    ['expired', 'Your session has expired'],
    ['forbidden', 'You do not have access'],
    ['server', 'Admin service unavailable'],
  ] as const)('maps a %s response to the expected state', async (kind, heading) => {
    render(<App api={api({ getAccess: vi.fn().mockRejectedValue(new ApiError(kind)) })} />);
    expect(await screen.findByRole('heading', { name: heading })).toBeInTheDocument();
  });

  it('blocks staff data until the session has completed MFA', async () => {
    render(
      <App
        api={api({
          getAccess: vi.fn().mockResolvedValue({
            ...access,
            aal: 'aal1',
            mfa_satisfied: false,
          }),
        })}
      />,
    );
    expect(await screen.findByRole('heading', { name: 'Multi-factor sign-in required' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('uses the service response for a typed route even when the link is hidden', async () => {
    const getSection = vi.fn().mockRejectedValue(new ApiError('forbidden'));
    render(<App api={api({ getSection })} />);
    await screen.findByRole('heading', { name: 'Overview' });
    window.location.hash = '#/audit';
    window.dispatchEvent(new HashChangeEvent('hashchange'));
    expect(await screen.findByRole('heading', { name: 'Access denied' })).toBeInTheDocument();
    expect(getSection).toHaveBeenCalledWith('audit');
    expect(screen.queryByRole('link', { name: 'Audit trail' })).not.toBeInTheDocument();
  });

  it('renders authorized queue, record details and a timeline', async () => {
    render(<App api={api()} />);
    await screen.findByRole('heading', { name: 'Overview' });
    window.location.hash = '#/verification';
    window.dispatchEvent(new HashChangeEvent('hashchange'));
    expect(await screen.findByRole('table', { name: 'Read-only administration queue' })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Record details' })).toBeInTheDocument();
    expect(screen.getByText('Synthetic record')).toBeInTheDocument();
    expect(screen.getByRole('list', { name: 'Record history' })).toBeInTheDocument();
  });

  it('moves the entire shell to the expired state when a module request expires', async () => {
    render(<App api={api({ getSection: vi.fn().mockRejectedValue(new ApiError('expired')) })} />);
    await screen.findByRole('heading', { name: 'Overview' });
    window.location.hash = '#/verification';
    window.dispatchEvent(new HashChangeEvent('hashchange'));
    expect(await screen.findByRole('heading', { name: 'Your session has expired' })).toBeInTheDocument();
  });

  it('moves to signed out when a module request returns 401', async () => {
    render(<App api={api({ getSection: vi.fn().mockRejectedValue(new ApiError('unauthenticated')) })} />);
    await screen.findByRole('heading', { name: 'Overview' });
    window.location.hash = '#/verification';
    window.dispatchEvent(new HashChangeEvent('hashchange'));
    expect(await screen.findByRole('heading', { name: 'Sign in to Luma administration' })).toBeInTheDocument();
  });

  it('shows a service-error state when no live adapter is configured', async () => {
    const { unconfiguredApi } = await import('./api/createApi');
    render(<App api={unconfiguredApi} />);
    expect(await screen.findByRole('heading', { name: 'Admin service unavailable' })).toBeInTheDocument();
  });

  it('exposes an operable mobile navigation toggle', async () => {
    render(<App api={api()} />);
    await screen.findByRole('heading', { name: 'Overview' });
    const menu = screen.getByRole('button', { name: 'Menu' });
    expect(menu).toHaveAttribute('aria-expanded', 'false');
    await userEvent.click(menu);
    await waitFor(() => expect(menu).toHaveAttribute('aria-expanded', 'true'));
  });
});
