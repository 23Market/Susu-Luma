import type { ReactNode } from 'react';

export function StateScreen({
  title,
  children,
  actions,
}: {
  title: string;
  children: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <main className="state-screen" aria-labelledby="state-title">
      <div className="state-card">
        <p className="eyebrow">Susu Luma · Administration</p>
        <h1 id="state-title">{title}</h1>
        {children}
        {actions && <div className="button-row">{actions}</div>}
      </div>
    </main>
  );
}
