import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { AdminForm, ConfirmDialog, QueueTable, TextField } from './SharedComponents';

const rows = [
  { id: 'SYN-1', subject: 'Cocoa supplier', submittedAt: '2026-11-18', status: 'pending' as const, summary: 'Synthetic' },
  { id: 'SYN-2', subject: 'Rice supplier', submittedAt: '2026-11-17', status: 'in_review' as const, summary: 'Synthetic' },
];

describe('shared accessible components', () => {
  it('filters a read-only queue and identifies its status', async () => {
    render(<QueueTable rows={rows} />);
    expect(screen.getByRole('table', { name: 'Read-only administration queue' })).toBeInTheDocument();
    expect(screen.getByText('Pending')).toBeInTheDocument();
    await userEvent.type(screen.getByRole('searchbox', { name: 'Filter by subject' }), 'cocoa');
    expect(screen.getByText('Cocoa supplier')).toBeInTheDocument();
    expect(screen.queryByText('Rice supplier')).not.toBeInTheDocument();
  });

  it('associates form labels and values', async () => {
    const onChange = vi.fn();
    render(<TextField id="reason" label="Review reason" value="" onChange={onChange} required />);
    const field = screen.getByRole('textbox', { name: 'Review reason' });
    expect(field).toBeRequired();
    await userEvent.type(field, 'Needs review');
    expect(onChange).toHaveBeenCalled();
  });

  it('submits the reusable form without navigating away', async () => {
    const onSubmit = vi.fn();
    render(
      <AdminForm label="Review details" submitLabel="Save draft" onSubmit={onSubmit}>
        <TextField id="note" label="Note" value="" onChange={vi.fn()} />
      </AdminForm>,
    );
    await userEvent.click(screen.getByRole('button', { name: 'Save draft' }));
    expect(onSubmit).toHaveBeenCalledOnce();
    expect(screen.getByRole('form', { name: 'Review details' })).toBeInTheDocument();
  });

  it('provides clearly labelled confirmation and cancellation controls', async () => {
    const user = userEvent.setup();
    const onCancel = vi.fn();
    render(
      <ConfirmDialog
        open
        title="Confirm change"
        description="This operation cannot be undone."
        onCancel={onCancel}
        onConfirm={vi.fn()}
      />,
    );
    const dialog = screen.getByRole('alertdialog', { name: 'Confirm change' });
    expect(dialog).toHaveAccessibleDescription('This operation cannot be undone.');
    expect(screen.getByRole('button', { name: 'Cancel' })).toHaveFocus();
    expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Confirm' })).toBeInTheDocument();
    await user.tab();
    expect(screen.getByRole('button', { name: 'Confirm' })).toHaveFocus();
    await user.tab();
    expect(screen.getByRole('button', { name: 'Cancel' })).toHaveFocus();
    await user.keyboard('{Escape}');
    expect(onCancel).toHaveBeenCalledOnce();
  });
});
