import axe from 'axe-core';
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import App from './App';
import { ConfirmDialog } from './components/SharedComponents';
import type { AdminApi } from './api/types';

const api: AdminApi = {
  source: 'mock',
  async getAccess() {
    return {
      user_id: 'staff',
      aal: 'aal2',
      mfa_satisfied: true,
      roles: ['verification_reviewer'],
      capabilities: ['verification.review'],
    };
  },
  async signIn() {},
  async signOut() {},
  async getSection() {
    return [];
  },
};

describe('accessibility', () => {
  it('has no axe violations in the authenticated shell', async () => {
    const { container } = render(<App api={api} />);
    await screen.findByRole('heading', { name: 'Overview' });
    expect(await axe.run(container, { rules: { 'color-contrast': { enabled: false } } })).toHaveProperty(
      'violations',
      [],
    );
  });

  it('has no axe violations in the confirmation dialog', async () => {
    const { container } = render(
      <ConfirmDialog
        open
        title="Confirm action"
        description="Review the action before continuing."
        onCancel={() => {}}
        onConfirm={() => {}}
      />,
    );
    expect(await axe.run(container, { rules: { 'color-contrast': { enabled: false } } })).toHaveProperty(
      'violations',
      [],
    );
  });
});
