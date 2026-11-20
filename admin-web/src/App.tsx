import { useEffect, useMemo, useState } from 'react';
import {
  SECTION_CAPABILITY,
  SECTION_LABEL,
  type AdminApi,
  type DataSection,
  type PlatformAccess,
  type SectionId,
} from './api/types';
import { SectionPanel } from './components/SectionPanel';
import { StateScreen } from './components/StateScreen';
import { useAdminSession } from './session/useAdminSession';

const SECTIONS: readonly SectionId[] = ['overview', 'verification', 'audit'];

function sectionFromHash(hash: string): SectionId {
  const id = hash.replace(/^#\/?/, '');
  return SECTIONS.find((s) => s === id) ?? 'overview';
}

function useHashSection(): SectionId {
  const [section, setSection] = useState<SectionId>(() => sectionFromHash(window.location.hash));
  useEffect(() => {
    const onChange = () => setSection(sectionFromHash(window.location.hash));
    window.addEventListener('hashchange', onChange);
    return () => window.removeEventListener('hashchange', onChange);
  }, []);
  return section;
}

/** Menu entries come from the capabilities the SERVER returned. Hiding an entry is not security. */
function offeredSections(access: PlatformAccess): DataSection[] {
  return (Object.keys(SECTION_CAPABILITY) as DataSection[]).filter((s) =>
    access.capabilities.includes(SECTION_CAPABILITY[s]),
  );
}

function Overview({ access, offered }: { access: PlatformAccess; offered: DataSection[] }) {
  return (
    <section aria-labelledby="section-title">
      <h1 id="section-title" tabIndex={-1}>
        {SECTION_LABEL.overview}
      </h1>
      <dl className="facts">
        <dt>Your platform roles</dt>
        <dd>{access.roles.join(', ')}</dd>
        <dt>Sign-in strength</dt>
        <dd>Multi-factor verified</dd>
        <dt>Modules available to you</dt>
        <dd>
          {offered.length === 0
            ? 'None yet. No module is available for your role at this stage.'
            : offered.map((s) => SECTION_LABEL[s]).join(', ')}
        </dd>
      </dl>
      <p className="muted">
        This list comes from the server. Hiding or showing a menu entry is a convenience only: the
        server decides every request.
      </p>
    </section>
  );
}

export default function App({ api }: { api: AdminApi }) {
  const { state, refresh, signIn, signOut, expire } = useAdminSession(api);
  const section = useHashSection();
  const [menuOpen, setMenuOpen] = useState(false);
  const offered = useMemo(
    () => (state.status === 'ready' ? offeredSections(state.access) : []),
    [state],
  );

  switch (state.status) {
    case 'loading':
      return (
        <StateScreen title="Checking your access" tone="status">
          <p>Asking the secure service who you are. This usually takes a moment.</p>
        </StateScreen>
      );
    case 'unauthenticated':
      return (
        <StateScreen
          title="Sign in to Luma administration"
          tone="alert"
          actions={
            <button type="button" className="btn btn-primary" onClick={() => void signIn()}>
              Sign in
            </button>
          }
        >
          <p>Staff accounts only. Access is checked by the server and needs multi-factor sign-in.</p>
        </StateScreen>
      );
    case 'expired':
      return (
        <StateScreen
          title="Your session has expired"
          tone="alert"
          actions={
            <button type="button" className="btn btn-primary" onClick={() => void signIn()}>
              Sign in again
            </button>
          }
        >
          <p>For your security you were signed out. Nothing was changed.</p>
        </StateScreen>
      );
    case 'mfa_required':
      return (
        <StateScreen
          title="Multi-factor sign-in required"
          tone="alert"
          actions={
            <button type="button" className="btn" onClick={() => void signOut()}>
              Sign out
            </button>
          }
        >
          <p>
            Your account has a staff role, but this session has not completed multi-factor
            verification. No admin data is available until it has.
          </p>
        </StateScreen>
      );
    case 'forbidden':
      return (
        <StateScreen
          title="You do not have access"
          tone="alert"
          actions={
            <button type="button" className="btn" onClick={() => void signOut()}>
              Sign out
            </button>
          }
        >
          <p>Your account has no platform role. Ask a platform administrator if you need access.</p>
        </StateScreen>
      );
    case 'error':
      return (
        <StateScreen
          title="Admin service unavailable"
          tone="alert"
          actions={
            <button type="button" className="btn btn-primary" onClick={() => void refresh()}>
              Retry
            </button>
          }
        >
          <p>{state.message} No changes have been made.</p>
        </StateScreen>
      );
    case 'ready':
      break;
  }

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to main content
      </a>
      <header className="topbar">
        <button
          type="button"
          className="btn nav-toggle"
          aria-expanded={menuOpen}
          aria-controls="primary-nav"
          onClick={() => setMenuOpen((open) => !open)}
        >
          Menu
        </button>
        <span className="brand">Luma administration</span>
        <span className="who">Multi-factor verified</span>
        <button type="button" className="btn" onClick={() => void signOut()}>
          Sign out
        </button>
      </header>
      {api.source === 'mock' && (
        <div role="note" className="mock-banner">
          <strong>MOCK DATA.</strong> Synthetic records only. No live service, authentication or
          permissions are connected.
        </div>
      )}
      <div className="layout">
        <nav id="primary-nav" aria-label="Admin modules" data-open={menuOpen}>
          <ul>
            {(['overview', ...offered] as SectionId[]).map((id) => (
              <li key={id}>
                <a
                  href={`#/${id}`}
                  aria-current={section === id ? 'page' : undefined}
                  onClick={() => setMenuOpen(false)}
                >
                  {SECTION_LABEL[id]}
                </a>
              </li>
            ))}
          </ul>
        </nav>
        <main id="main">
          {section === 'overview' ? (
            <Overview access={state.access} offered={offered} />
          ) : (
            <SectionPanel key={section} api={api} section={section} onSessionExpired={expire} />
          )}
        </main>
      </div>
    </>
  );
}
