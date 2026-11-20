import { useCallback, useEffect, useRef, useState } from 'react';
import { ApiError, type AdminApi, type PlatformAccess } from '../api/types';

export type SessionState =
  | { status: 'loading' }
  | { status: 'unauthenticated' }
  | { status: 'expired' }
  | { status: 'mfa_required'; access: PlatformAccess }
  | { status: 'forbidden' }
  | { status: 'error'; message: string }
  | { status: 'ready'; access: PlatformAccess };

/**
 * Turns the server's answer into a screen. The server's word is final:
 *  - no platform role      -> forbidden
 *  - role but no MFA       -> mfa_required (the server returns no capabilities for aal1)
 *  - role and MFA          -> ready (menu comes from the server-provided capabilities)
 */
export function classifyAccess(access: PlatformAccess): SessionState {
  if (access.roles.length === 0) return { status: 'forbidden' };
  if (!access.mfaSatisfied) return { status: 'mfa_required', access };
  return { status: 'ready', access };
}

export function stateFromError(error: unknown): SessionState {
  if (error instanceof ApiError) {
    switch (error.kind) {
      case 'unauthenticated':
        return { status: 'unauthenticated' };
      case 'session_expired':
        return { status: 'expired' };
      case 'forbidden':
        return { status: 'forbidden' };
      default:
        return { status: 'error', message: error.message };
    }
  }
  return { status: 'error', message: 'Something went wrong. Nothing was changed.' };
}

export function useAdminSession(api: AdminApi) {
  const [state, setState] = useState<SessionState>({ status: 'loading' });
  const run = useRef(0);

  const refresh = useCallback(async () => {
    const id = ++run.current;
    setState({ status: 'loading' });
    try {
      const access = await api.getAccess();
      if (id === run.current) setState(classifyAccess(access));
    } catch (error) {
      if (id === run.current) setState(stateFromError(error));
    }
  }, [api]);

  useEffect(() => {
    void refresh();
    return () => {
      run.current++; // ignore answers that arrive after unmount or an API swap
    };
  }, [refresh]);

  const signIn = useCallback(async () => {
    try {
      await api.signIn();
    } catch (error) {
      setState(stateFromError(error));
      return;
    }
    await refresh();
  }, [api, refresh]);

  const signOut = useCallback(async () => {
    run.current++;
    await api.signOut();
    setState({ status: 'unauthenticated' });
  }, [api]);

  /** A data call came back 401: the whole session is no longer valid. */
  const expire = useCallback(() => {
    run.current++;
    setState({ status: 'expired' });
  }, []);

  return { state, refresh, signIn, signOut, expire };
}
