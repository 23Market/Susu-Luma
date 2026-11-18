import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { createAdminApi } from './api/createApi';
import './styles.css';

async function start() {
  const api = await createAdminApi();
  createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <App api={api} />
    </React.StrictMode>,
  );
}

void start();
