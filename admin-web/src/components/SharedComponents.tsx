import { useEffect, useId, useMemo, useRef, useState } from 'react';
import type { FormEvent, KeyboardEvent, ReactNode } from 'react';
import type { QueueItem } from '../api/types';

const STATUS_LABEL: Record<QueueItem['status'], string> = {
  pending: 'Pending',
  in_review: 'In review',
  complete: 'Complete',
};

export function StatusBadge({ status }: { status: QueueItem['status'] }) {
  return <span className={`status-badge status-${status}`}>{STATUS_LABEL[status]}</span>;
}

export function FilterBar({
  value,
  onChange,
  label = 'Filter records',
}: {
  value: string;
  onChange: (value: string) => void;
  label?: string;
}) {
  return (
    <label className="filter-field">
      <span>{label}</span>
      <input type="search" value={value} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}

export function QueueTable({ rows }: { rows: QueueItem[] }) {
  const [filter, setFilter] = useState('');
  const visibleRows = useMemo(
    () => rows.filter((row) => row.subject.toLowerCase().includes(filter.toLowerCase())),
    [filter, rows],
  );
  return (
    <div className="queue">
      <FilterBar value={filter} onChange={setFilter} label="Filter by subject" />
      {visibleRows.length === 0 ? (
        <p className="empty-state">No records match this filter.</p>
      ) : (
        <div className="table-scroll">
          <table>
            <caption>Read-only administration queue</caption>
            <thead>
              <tr>
                <th scope="col">Reference</th>
                <th scope="col">Subject</th>
                <th scope="col">Submitted</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {visibleRows.map((row) => (
                <tr key={row.id}>
                  <td>{row.id}</td>
                  <td>{row.subject}</td>
                  <td>
                    <time dateTime={row.submittedAt}>{row.submittedAt}</time>
                  </td>
                  <td>
                    <StatusBadge status={row.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export function TextField({
  id,
  label,
  value,
  onChange,
  required = false,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  required?: boolean;
}) {
  return (
    <label className="form-field" htmlFor={id}>
      <span>{label}</span>
      <input
        id={id}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        required={required}
      />
    </label>
  );
}

export function AdminForm({
  label,
  submitLabel,
  onSubmit,
  children,
}: {
  label: string;
  submitLabel: string;
  onSubmit: () => void;
  children: ReactNode;
}) {
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    onSubmit();
  }
  return (
    <form aria-label={label} onSubmit={submit}>
      <div className="form-fields">{children}</div>
      <button className="button button-primary" type="submit">{submitLabel}</button>
    </form>
  );
}

export function RecordDetails({ record }: { record: QueueItem }) {
  const titleId = useId();
  return (
    <article className="detail-card" aria-labelledby={titleId}>
      <h2 id={titleId}>Record details</h2>
      <dl className="facts">
        <dt>Reference</dt><dd>{record.id}</dd>
        <dt>Subject</dt><dd>{record.subject}</dd>
        <dt>Submitted</dt><dd><time dateTime={record.submittedAt}>{record.submittedAt}</time></dd>
        <dt>Status</dt><dd><StatusBadge status={record.status} /></dd>
        <dt>Summary</dt><dd>{record.summary}</dd>
      </dl>
    </article>
  );
}

export function RecordTimeline({ events }: { events: { at: string; label: string }[] }) {
  return (
    <ol className="timeline" aria-label="Record history">
      {events.map((event) => (
        <li key={`${event.at}-${event.label}`}>
          <time dateTime={event.at}>{event.at}</time>
          <span>{event.label}</span>
        </li>
      ))}
    </ol>
  );
}

export function ConfirmDialog({
  title,
  description,
  open,
  onCancel,
  onConfirm,
}: {
  title: string;
  description: string;
  open: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const titleId = useId();
  const descriptionId = useId();
  const dialogRef = useRef<HTMLDivElement>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) return;
    const previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    cancelRef.current?.focus();
    return () => previousFocus?.focus();
  }, [open]);

  if (!open) return null;
  function handleKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === 'Escape') {
      event.preventDefault();
      onCancel();
      return;
    }
    if (event.key !== 'Tab') return;
    const controls = dialogRef.current?.querySelectorAll<HTMLElement>(
      'button:not([disabled]), a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    );
    if (!controls?.length) return;
    const first = controls[0];
    const last = controls[controls.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }
  return (
    <div
      ref={dialogRef}
      role="alertdialog"
      aria-modal="true"
      aria-labelledby={titleId}
      aria-describedby={descriptionId}
      className="dialog-backdrop"
      onKeyDown={handleKeyDown}
    >
      <section className="dialog">
        <h2 id={titleId}>{title}</h2>
        <p id={descriptionId}>{description}</p>
        <div className="button-row">
          <button ref={cancelRef} type="button" className="button" onClick={onCancel}>
            Cancel
          </button>
          <button type="button" className="button button-danger" onClick={onConfirm}>
            Confirm
          </button>
        </div>
      </section>
    </div>
  );
}
