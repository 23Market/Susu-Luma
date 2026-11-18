import { useEffect, useRef, type ReactNode } from 'react';

interface Props {
  title: string;
  /** `status` is polite (loading); `alert` is assertive (something needs attention). */
  tone: 'status' | 'alert';
  children?: ReactNode;
  actions?: ReactNode;
}

/** Full-page state (loading, signed out, expired, MFA, forbidden, error). Moves focus to the title. */
export function StateScreen({ title, tone, children, actions }: Props) {
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    heading.current?.focus();
  }, [title]);
  return (
    <main className="state-screen" id="main" aria-labelledby="state-title">
      <section className="state-card" role={tone}>
        <h1 id="state-title" tabIndex={-1} ref={heading}>
          {title}
        </h1>
        {children ? <div className="state-body">{children}</div> : null}
        {actions ? <div className="state-actions">{actions}</div> : null}
      </section>
    </main>
  );
}
