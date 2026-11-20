import type { Plugin } from 'vite';

/**
 * Content-Security-Policy for the PRODUCTION build only.
 *
 * The meta tag is a second line of defence. Real headers (CSP, frame-ancestors, HSTS,
 * X-Content-Type-Options, Referrer-Policy) must be set by whatever hosts the files; this folder
 * does not choose a host. It is injected at build time, not written into index.html, because the
 * Vite dev server injects inline styles and a WebSocket that a strict policy would block, which
 * silently leaves the development page unstyled.
 */
export const CONTENT_SECURITY_POLICY = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self'",
  "img-src 'self' data:",
  "connect-src 'self'",
  "base-uri 'none'",
  "form-action 'self'",
].join('; ');

export function cspPlugin(): Plugin {
  return {
    name: 'luma-admin-csp',
    apply: 'build',
    transformIndexHtml(html) {
      const tag = `<meta http-equiv="Content-Security-Policy" content="${CONTENT_SECURITY_POLICY}" />`;
      if (!html.includes('<head>')) throw new Error('index.html has no <head>; cannot inject the CSP.');
      return html.replace('<head>', `<head>\n    ${tag}`);
    },
  };
}
