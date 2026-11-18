import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import axe from 'axe-core';
import { describe, expect, it, vi } from 'vitest';
import App from './App';
import { createUnconfiguredApi } from './api/createApi';
import { createMockApi, type MockScenario } from './api/mockApi';
import { ApiError, type AdminApi } from './api/types';

function mount(api: AdminApi) {
  return render(<App api={api} />);
}
const mockApp = (scenario: MockScenario) => mount(createMockApi(scenario));

/** Accessibility scan. Colour contrast needs a real layout engine, so it is checked in the browser pass. */
async function expectNoA11yViolations(container: HTMLElement) {
  const results = await axe.run(container, { rules: { 'color-contrast': { enabled: false } } });
  expect(results.violations.map((v) => `${v.id}: ${v.help}`)).toEqual([]);
}

describe('session states (full-page)', () => {
  it('shows a loading state while the server is asked who you are', async () => {
    mount({
      source: 'mock',
      getAccess: () => new Promise(() => undefined), // never answers
      loadSection: () => new Promise(() => undefined),
      signIn: async () => undefined,
      signOut: async () => undefined,
    });
    expect(await screen.findByRole('heading', { name: 'Checking your access' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('asks a signed-out visitor to sign in, then shows the console after sign-in', async () => {
    const user = userEvent.setup();
    mockApp('signed_out');
    expect(
      await screen.findByRole('heading', { name: 'Sign in to Luma administration' }),
    ).toBeInTheDocument();
    expect(screen.queryByText('Synthetic Supplier A')).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByRole('heading', { name: 'Overview' })).toBeInTheDocument();
  });

  it('tells a person whose session lapsed, and lets them sign in again', async () => {
    const user = userEvent.setup();
    mockApp('expired');
    expect(await screen.findByRole('heading', { name: 'Your session has expired' })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Sign in again' }));
    expect(await screen.findByRole('heading', { name: 'Overview' })).toBeInTheDocument();
  });

  it('demands MFA from a privileged account on a password-only session and shows no data', async () => {
    mockApp('no_mfa');
    expect(
      await screen.findByRole('heading', { name: 'Multi-factor sign-in required' }),
    ).toBeInTheDocument();
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
    expect(screen.queryByText(/Verification queue/)).not.toBeInTheDocument();
  });

  it('denies an account with no platform role', async () => {
    mockApp('no_role');
    expect(await screen.findByRole('heading', { name: 'You do not have access' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('shows an error with Retry, and recovers when the service comes back', async () => {
    const user = userEvent.setup();
    const ok = createMockApi('reviewer');
    const getAccess = vi
      .fn<AdminApi['getAccess']>()
      .mockRejectedValueOnce(new ApiError('network', 'Could not reach the service.'))
      .mockImplementation(() => ok.getAccess());
    mount({ ...ok, getAccess });
    expect(await screen.findByRole('heading', { name: 'Admin service unavailable' })).toBeInTheDocument();
    expect(screen.getByText(/Could not reach the service\. No changes have been made\./)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Retry' }));
    expect(await screen.findByRole('heading', { name: 'Overview' })).toBeInTheDocument();
    expect(getAccess).toHaveBeenCalledTimes(2);
  });

  it('does not leak the text of an unexpected failure', async () => {
    mount({
      ...createMockApi('reviewer'),
      getAccess: async () => {
        throw new Error('connection string postgres://user:pw@10.0.0.5/db refused');
      },
    });
    expect(await screen.findByRole('heading', { name: 'Admin service unavailable' })).toBeInTheDocument();
    expect(screen.queryByText(/postgres:\/\//)).not.toBeInTheDocument();
  });

  it('fails closed when the console is not configured', async () => {
    mount(createUnconfiguredApi());
    expect(await screen.findByRole('heading', { name: 'Admin service unavailable' })).toBeInTheDocument();
    expect(screen.getByText(/not configured/)).toBeInTheDocument();
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('signs out back to the sign-in screen', async () => {
    const user = userEvent.setup();
    mockApp('reviewer');
    await user.click(await screen.findByRole('button', { name: 'Sign out' }));
    expect(
      await screen.findByRole('heading', { name: 'Sign in to Luma administration' }),
    ).toBeInTheDocument();
  });
});

describe('console shell', () => {
  it('offers only the modules the server granted, and labels mock data', async () => {
    mockApp('reviewer');
    const nav = await screen.findByRole('navigation', { name: 'Admin modules' });
    expect(within(nav).getByRole('link', { name: 'Overview' })).toBeInTheDocument();
    expect(within(nav).getByRole('link', { name: 'Verification queue' })).toBeInTheDocument();
    expect(within(nav).queryByRole('link', { name: 'Audit log' })).not.toBeInTheDocument();
    expect(screen.getByRole('note')).toHaveTextContent(/MOCK DATA/);
  });

  it('shows the audit log to a platform admin, not the verification queue', async () => {
    mockApp('admin');
    const nav = await screen.findByRole('navigation', { name: 'Admin modules' });
    expect(within(nav).getByRole('link', { name: 'Audit log' })).toBeInTheDocument();
    expect(within(nav).queryByRole('link', { name: 'Verification queue' })).not.toBeInTheDocument();
  });

  it('says plainly when a role has no module yet (finance)', async () => {
    mockApp('finance');
    expect(await screen.findByText(/No module is available for your role at this stage/)).toBeInTheDocument();
    const nav = screen.getByRole('navigation', { name: 'Admin modules' });
    expect(within(nav).getAllByRole('link')).toHaveLength(1);
  });

  it('loads a module on demand and renders a read-only table', async () => {
    const user = userEvent.setup();
    mockApp('reviewer');
    await user.click(await screen.findByRole('link', { name: 'Verification queue' }));
    const table = await screen.findByRole('table');
    expect(within(table).getByText('Synthetic Supplier B')).toBeInTheDocument();
    expect(within(table).getAllByRole('columnheader').length).toBeGreaterThan(3);
    expect(screen.queryByRole('button', { name: /approve|reject|grant/i })).not.toBeInTheDocument();
  });

  it('shows a loading indicator while a module loads', async () => {
    window.location.hash = '#/verification';
    const ok = createMockApi('reviewer');
    mount({ ...ok, loadSection: () => new Promise(() => undefined) });
    // The session check resolves first (its own "status" screen), then the module shows its own.
    expect(await screen.findByText(/Loading verification queue/i)).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Verification queue' })).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });

  it('hiding a menu entry is not security: a typed URL still gets the server refusal', async () => {
    window.location.hash = '#/audit'; // a reviewer has no audit.view capability
    mockApp('reviewer');
    expect(await screen.findByRole('alert')).toHaveTextContent(/Access denied/);
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
    expect(screen.queryByText('platform_role.granted')).not.toBeInTheDocument();
  });

  it('treats a 401 on a data call as an expired session for the whole console', async () => {
    window.location.hash = '#/verification';
    const ok = createMockApi('reviewer');
    mount({
      ...ok,
      loadSection: async () => {
        throw new ApiError('session_expired', 'Session expired.');
      },
    });
    expect(await screen.findByRole('heading', { name: 'Your session has expired' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('shows a module error with Retry, and recovers', async () => {
    window.location.hash = '#/verification';
    const user = userEvent.setup();
    const ok = createMockApi('reviewer');
    const loadSection = vi
      .fn<AdminApi['loadSection']>()
      .mockRejectedValueOnce(new ApiError('server', 'The service had a problem.'))
      .mockImplementation((s) => ok.loadSection(s));
    mount({ ...ok, loadSection });
    expect(await screen.findByRole('alert')).toHaveTextContent(/Could not load this module/);
    await user.click(screen.getByRole('button', { name: 'Retry' }));
    expect(await screen.findByRole('table')).toBeInTheDocument();
  });

  it('shows an empty state instead of an empty table', async () => {
    window.location.hash = '#/verification';
    const ok = createMockApi('reviewer');
    mount({
      ...ok,
      loadSection: async () => ({ title: 'Verification queue', columns: ['A'], rows: [], updatedAt: 'now' }),
    });
    expect(await screen.findByText('No records.')).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });

  it('does not show the mock banner for a live data source', async () => {
    const ok = createMockApi('reviewer');
    mount({ ...ok, source: 'live' });
    await screen.findByRole('heading', { name: 'Overview' });
    expect(screen.queryByRole('note')).not.toBeInTheDocument();
  });

  it('collapses the menu behind a button on small screens and keeps it keyboard reachable', async () => {
    const user = userEvent.setup();
    mockApp('reviewer');
    const toggle = await screen.findByRole('button', { name: 'Menu' });
    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    expect(screen.getByRole('navigation', { name: 'Admin modules' })).toHaveAttribute('data-open', 'false');
    await user.click(toggle);
    expect(toggle).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByRole('navigation', { name: 'Admin modules' })).toHaveAttribute('data-open', 'true');
  });

  it('has a skip link to the main content', async () => {
    mockApp('reviewer');
    const skip = await screen.findByRole('link', { name: 'Skip to main content' });
    expect(skip).toHaveAttribute('href', '#main');
  });
});

describe('accessibility (axe-core, jsdom)', () => {
  it.each<MockScenario>(['signed_out', 'expired', 'no_mfa', 'no_role', 'error'])(
    'has no violations on the %s screen',
    async (scenario) => {
      const { container } = mockApp(scenario);
      await screen.findByRole('heading', { level: 1 });
      await expectNoA11yViolations(container);
    },
  );

  it('has no violations on the overview', async () => {
    const { container } = mockApp('reviewer');
    await screen.findByRole('heading', { name: 'Overview' });
    await expectNoA11yViolations(container);
  });

  it('has no violations on a data table', async () => {
    window.location.hash = '#/verification';
    const { container } = mockApp('reviewer');
    await screen.findByRole('table');
    await expectNoA11yViolations(container);
  });

  it('has no violations on the access-denied panel', async () => {
    window.location.hash = '#/audit';
    const { container } = mockApp('reviewer');
    await screen.findByText(/Access denied/);
    await expectNoA11yViolations(container);
  });
});
