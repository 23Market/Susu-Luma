import { useEffect, useState } from 'react';
import type { AdminApi, DataSection, QueueItem } from '../api/types';
import { ApiError, SECTION_LABEL } from '../api/types';
import { QueueTable, RecordDetails, RecordTimeline } from './SharedComponents';

export function SectionPanel({
  api,
  section,
  onSessionExpired,
  onUnauthenticated,
}: {
  api: AdminApi;
  section: DataSection;
  onSessionExpired: () => void;
  onUnauthenticated: () => void;
}) {
  const [result, setResult] = useState<
    | { status: 'loading' }
    | { status: 'ready'; rows: QueueItem[] }
    | { status: 'forbidden' }
    | { status: 'error' }
  >({ status: 'loading' });

  useEffect(() => {
    let active = true;
    setResult({ status: 'loading' });
    api.getSection(section).then(
      (rows) => {
        if (active) setResult({ status: 'ready', rows });
      },
      (error: unknown) => {
        if (!active) return;
        if (error instanceof ApiError && error.kind === 'forbidden') setResult({ status: 'forbidden' });
        else if (error instanceof ApiError && error.kind === 'expired') onSessionExpired();
        else if (error instanceof ApiError && error.kind === 'unauthenticated') onUnauthenticated();
        else setResult({ status: 'error' });
      },
    );
    return () => {
      active = false;
    };
  }, [api, onSessionExpired, onUnauthenticated, section]);

  if (result.status === 'loading') return <p role="status">Loading {SECTION_LABEL[section]}…</p>;
  if (result.status === 'forbidden') {
    return (
      <section aria-labelledby="section-title">
        <h1 id="section-title">Access denied</h1>
        <p role="alert">The server denied access to this module.</p>
      </section>
    );
  }
  if (result.status === 'error') {
    return (
      <section aria-labelledby="section-title">
        <h1 id="section-title">{SECTION_LABEL[section]}</h1>
        <p role="alert">This module is unavailable. No changes were made.</p>
      </section>
    );
  }
  return (
    <section aria-labelledby="section-title">
      <h1 id="section-title">{SECTION_LABEL[section]}</h1>
      <p className="muted">Read-only foundation. Decisions and other write actions are not enabled.</p>
      <QueueTable rows={result.rows} />
      {result.rows[0] && <RecordDetails record={result.rows[0]} />}
      <h2>Recent activity</h2>
      <RecordTimeline
        events={result.rows.map((row) => ({
          at: row.submittedAt,
          label: `${row.id} entered the queue`,
        }))}
      />
    </section>
  );
}
