import { useEffect, useMemo, useState } from 'react';
import { SECTION_CAPABILITY, SECTION_LABEL, type AdminApi, type DataSection, type SectionId } from './api/types';
import { SectionPanel } from './components/SectionPanel';
import { StateScreen } from './components/StateScreen';
import { useAdminSession } from './session/useAdminSession';

const SECTIONS: readonly SectionId[] = ['overview', 'verification', 'audit'];

function sectionFromHash(hash: string): SectionId {
  const section = hash.replace(/^#\/?/, '');
  return SECTIONS.find((candidate) => candidate === section) ?? 'overview';
}

function useHashSection() {
  const [section, setSection] = useState(() => sectionFromHash(window.location.hash));
  useEffect(() => {
    const update = () => setSection(sectionFromHash(window.location.hash));
    window.addEventListener('hashchange', update);
    return () => window.removeEventListener('hashchange', update);
  }, []);
  return section;
}

function offeredSections(capabilities: string[]): DataSection[] {
  return (Object.keys(SECTION_CAPABILITY) as DataSection[]).filter((section) =>
    capabilities.includes(SECTION_CAPABILITY[section]),
  );
}

export default function App({ api }: { api: AdminApi }) {
  const { state, refresh, signIn, signOut, expire, unauthenticate } = useAdminSession(api);
  const section = useHashSection();
  const [menuOpen, setMenuOpen] = useState(false);
  const offered = useMemo(
    () => (state.status === 'ready' ? offeredSections(state.access.capabilities) : []),
    [state],
  );

  if (state.status === 'loading') {
    return <StateScreen title="Checking your access"><p role="status">Contacting the administration service…</p></StateScreen>;
  }
  if (state.status === 'unauthenticated') {
    return (
      <StateScreen title="Sign in to Luma administration">
        <p>Staff access is verified by the service. Sign-in requires multi-factor authentication.</p>
        <button className="button button-primary" type="button" onClick={() => void signIn()}>Sign in</button>
      </StateScreen>
    );
  }
  if (state.status === 'expired') {
    return (
      <StateScreen title="Your session has expired">
        <p>For your security, sign in again. No changes were made.</p>
        <button className="button button-primary" type="button" onClick={() => void signIn()}>Sign in again</button>
      </StateScreen>
    );
  }
  if (state.status === 'mfa_required') {
    return (
      <StateScreen title="Multi-factor sign-in required">
        <p>Your staff account has not completed multi-factor verification. No admin data is available.</p>
        <button className="button" type="button" onClick={() => void signOut()}>Sign out</button>
      </StateScreen>
    );
  }
  if (state.status === 'forbidden') {
    return (
      <StateScreen title="You do not have access">
        <p>Your account has no platform permissions. Contact a platform administrator if you need access.</p>
        <button className="button" type="button" onClick={() => void signOut()}>Sign out</button>
      </StateScreen>
    );
  }
  if (state.status === 'error') {
    return (
      <StateScreen title="Admin service unavailable">
        <p>{state.message} No changes have been made.</p>
        <button className="button button-primary" type="button" onClick={() => void refresh()}>Retry</button>
      </StateScreen>
    );
  }

  return (
    <>
      <a className="skip-link" href="#main">Skip to main content</a>
      <header className="topbar">
        <button
          className="button menu-toggle"
          type="button"
          aria-expanded={menuOpen}
          aria-controls="primary-nav"
          onClick={() => setMenuOpen((open) => !open)}
        >
          Menu
        </button>
        <span className="brand">Susu Luma <span>Administration</span></span>
        <span className="session-indicator">MFA verified</span>
        <button className="button" type="button" onClick={() => void signOut()}>Sign out</button>
      </header>
      {api.source === 'mock' && (
        <aside role="note" className="mock-banner">
          <strong>MOCK DATA.</strong> Synthetic records only. No live service or permissions are connected.
        </aside>
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
            <section aria-labelledby="section-title">
              <h1 id="section-title">Overview</h1>
              <dl className="facts">
                <dt>Platform roles</dt><dd>{state.access.roles.join(', ')}</dd>
                <dt>Sign-in strength</dt><dd>Multi-factor verified</dd>
                <dt>Available modules</dt>
                <dd>{offered.length ? offered.map((item) => SECTION_LABEL[item]).join(', ') : 'None at this time.'}</dd>
              </dl>
              <p className="muted">
                Navigation reflects server-provided capabilities only. The server independently authorizes every request.
              </p>
            </section>
          ) : (
            <SectionPanel
              key={section}
              api={api}
              section={section}
              onSessionExpired={expire}
              onUnauthenticated={unauthenticate}
            />
          )}
        </main>
      </div>
    </>
  );
}
