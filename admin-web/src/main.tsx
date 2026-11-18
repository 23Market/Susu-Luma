import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { createApi, type MockProvider } from './api/createApi';
import './styles.css';

/**
 * `import.meta.env.DEV` is replaced by a constant at build time, so in a production build this
 * branch and the mock module it loads are removed from the bundle (checked by `npm run check:bundle`).
 */
async function loadMock(): Promise<MockProvider | undefined> {
  if (!import.meta.env.DEV) return undefined;
  const { createMockApi, MOCK_SCENARIOS } = await import('./api/mockApi');
  return {
    scenarios: MOCK_SCENARIOS,
    create: (scenario) => createMockApi(MOCK_SCENARIOS.find((s) => s === scenario) ?? 'reviewer'),
  };
}

async function start() {
  const api = createApi({
    dataSource: import.meta.env.VITE_ADMIN_DATA_SOURCE as string | undefined,
    isProduction: import.meta.env.PROD,
    // Development convenience: ?scenario=admin|no_mfa|expired|... (mock data source only).
    scenario: new URLSearchParams(window.location.search).get('scenario'),
    mock: await loadMock(),
  });
  const root = document.getElementById('root');
  if (!root) throw new Error('Missing #root element');
  createRoot(root).render(
    <StrictMode>
      <App api={api} />
    </StrictMode>,
  );
}

void start();
