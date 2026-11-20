import { useCallback, useEffect, useState } from 'react';
import { parseAccess } from '../api/contract';
import { ApiError, type AdminApi, type PlatformAccess } from '../api/types';

export type SessionState =
  | { status: 'loading' }
  | { status: 'unauthenticated' }
  | { status: 'expired' }
  | { status: 'mfa_required' }
  | { status: 'forbidden' }
  | { status: 'error'; message: string }
  | { status: 'ready'; access: PlatformAccess };

function stateForError(error: unknown): SessionState {
  if (error instanceof ApiError) {
    if (error.kind === 'unauthenticated') return { status: 'unauthenticated' };
    if (error.kind === 'expired') return { status: 'expired' };
    if (error.kind === 'forbidden') return { status: 'forbidden' };
  }
  return {
    status: 'error',
    message: error instanceof ApiError ? error.message : 'The administration service is unavailable.',
  };
}

export function useAdminSession(api: AdminApi) {
  const [state, setState] = useState<SessionState>({ status: 'loading' });

  const refresh = useCallback(async () => {
    setState({ status: 'loading' });
    try {
      const access = parseAccess(await api.getAccess());
      if (access.roles.length === 0) setState({ status: 'forbidden' });
      else if (!access.mfaSatisfied || access.aal !== 'aal2') {
        setState({ status: 'mfa_required' });
      } else setState({ status: 'ready', access });
    } catch (error) {
      setState(stateForError(error));
    }
  }, [api]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const signIn = useCallback(async () => {
    try {
      await api.signIn();
      await refresh();
    } catch (error) {
      setState(stateForError(error));
    }
  }, [api, refresh]);

  const signOut = useCallback(async () => {
    try {
      await api.signOut();
      setState({ status: 'unauthenticated' });
    } catch (error) {
      setState(stateForError(error));
    }
  }, [api]);

  const expire = useCallback(() => setState({ status: 'expired' }), []);
  const unauthenticate = useCallback(() => setState({ status: 'unauthenticated' }), []);

  return { state, refresh, signIn, signOut, expire, unauthenticate };
}
