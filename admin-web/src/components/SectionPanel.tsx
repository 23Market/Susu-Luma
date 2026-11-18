import { useCallback, useEffect, useRef, useState } from 'react';
import { ApiError, SECTION_LABEL, type AdminApi, type DataSection, type SectionTable } from '../api/types';

type PanelState =
  | { status: 'loading' }
  | { status: 'denied' }
  | { status: 'error'; message: string }
  | { status: 'ready'; table: SectionTable };

interface Props {
  api: AdminApi;
  section: DataSection;
  /** The server said the session is gone (401). The whole console must leave `ready`. */
  onSessionExpired: () => void;
}

/**
 * Loads one module. It always asks the server, even when the menu entry was hidden:
 * hiding navigation is a convenience, never security. A 403 is shown as final.
 */
export function SectionPanel({ api, section, onSessionExpired }: Props) {
  const [state, setState] = useState<PanelState>({ status: 'loading' });
  const run = useRef(0);
  const heading = useRef<HTMLHeadingElement>(null);

  const load = useCallback(async () => {
    const id = ++run.current;
    setState({ status: 'loading' });
    try {
      const table = await api.loadSection(section);
      if (id === run.current) setState({ status: 'ready', table });
    } catch (error) {
      if (id !== run.current) return;
      if (error instanceof ApiError) {
        if (error.kind === 'session_expired' || error.kind === 'unauthenticated') {
          onSessionExpired();
          return;
        }
        if (error.kind === 'forbidden') {
          setState({ status: 'denied' });
          return;
        }
        setState({ status: 'error', message: error.message });
        return;
      }
      setState({ status: 'error', message: 'Something went wrong. Nothing was changed.' });
    }
  }, [api, section, onSessionExpired]);

  useEffect(() => {
    void load();
    return () => {
      run.current++;
    };
  }, [load]);

  useEffect(() => {
    heading.current?.focus();
  }, [section]);

  return (
    <section aria-labelledby="section-title" aria-busy={state.status === 'loading'}>
      <h1 id="section-title" tabIndex={-1} ref={heading}>
        {SECTION_LABEL[section]}
      </h1>

      {state.status === 'loading' && (
        <p role="status" className="muted">
          Loading {SECTION_LABEL[section].toLowerCase()}…
        </p>
      )}

      {state.status === 'denied' && (
        <div role="alert" className="notice notice-denied">
          <strong>Access denied.</strong> The server did not allow this request for your account.
          Nothing was shown and nothing was changed.
        </div>
      )}

      {state.status === 'error' && (
        <div role="alert" className="notice notice-error">
          <strong>Could not load this module.</strong> {state.message} Nothing was changed.
          <div className="notice-actions">
            <button type="button" className="btn" onClick={() => void load()}>
              Retry
            </button>
          </div>
        </div>
      )}

      {state.status === 'ready' && (
        <>
          <p className="muted">Updated {state.table.updatedAt} (UTC). Read-only.</p>
          {state.table.rows.length === 0 ? (
            <p>No records.</p>
          ) : (
            <div className="table-wrap" tabIndex={0} role="region" aria-label={`${state.table.title} table`}>
              <table>
                <caption className="visually-hidden">{state.table.title}</caption>
                <thead>
                  <tr>
                    {state.table.columns.map((c) => (
                      <th key={c} scope="col">
                        {c}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {state.table.rows.map((row, i) => (
                    <tr key={i}>
                      {row.map((cell, j) => (
                        <td key={j}>{cell}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
    </section>
  );
}
