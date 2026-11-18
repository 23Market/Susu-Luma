import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { CONTENT_SECURITY_POLICY, cspPlugin } from '../csp.ts';

// Read as plain files (Vite deliberately refuses to import `.env*` files as modules).
// Plain strings are used on purpose: under jsdom the global URL class is not Node's.
const here = dirname(fileURLToPath(import.meta.url));
const readRoot = (name: string): string => readFileSync(resolve(here, '..', name), 'utf8');
const envExample = readRoot('.env.example');
const envMock = readRoot('.env.mock');
const indexHtml = readRoot('index.html');

/**
 * Repository-level guardrails for the browser bundle. They read the source as text so that a
 * future change that weakens one of these rules fails CI instead of passing review by accident.
 */
const sources = import.meta.glob(['./**/*.ts', './**/*.tsx', '!./**/*.test.ts', '!./**/*.test.tsx'], {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>;

const entries = Object.entries(sources);

describe('browser bundle guardrails', () => {
  it('scans a meaningful set of source files', () => {
    expect(entries.length).toBeGreaterThanOrEqual(8);
  });

  it.each(['service_role', 'service-role', 'SERVICE_ROLE', 'serviceRole', 'sb_secret', 'SUPABASE_SECRET'])(
    'never mentions %s in browser source',
    (needle) => {
      const hits = entries.filter(([, text]) => text.includes(needle)).map(([file]) => file);
      expect(hits).toEqual([]);
    },
  );

  it('never reads client-controlled role metadata to decide anything', () => {
    const hits = entries
      .filter(([, text]) => /app_metadata|user_metadata/.test(text.replace(/\/\/.*$/gm, '').replace(/\/\*[\s\S]*?\*\//g, '')))
      .map(([file]) => file);
    expect(hits).toEqual([]);
  });

  it('does not persist roles, tokens or capabilities in browser storage', () => {
    const hits = entries.filter(([, text]) => /localStorage|sessionStorage|indexedDB|document\.cookie/.test(text)).map(([file]) => file);
    expect(hits).toEqual([]);
  });

  it('never renders HTML from data', () => {
    const hits = entries.filter(([, text]) => /dangerouslySetInnerHTML|innerHTML|eval\(|new Function\(/.test(text)).map(([file]) => file);
    expect(hits).toEqual([]);
  });

  it('keeps external hosts out of the shell', () => {
    const hits = entries.filter(([, text]) => /https?:\/\/(?!localhost)/.test(text)).map(([file]) => file);
    expect(hits).toEqual([]);
  });
});

describe('configuration guardrails', () => {
  it('declares only a data-source switch for mock builds', () => {
    const keys = envMock
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l && !l.startsWith('#'))
      .map((l) => l.split('=')[0]);
    expect(keys).toEqual(['VITE_ADMIN_DATA_SOURCE']);
  });

  it('warns against a service-role key and sets no secret-looking value', () => {
    expect(envExample).toMatch(/NEVER put a service-role key/);
    const assigned = envExample
      .split('\n')
      .filter((l) => /^[A-Z_]+=/.test(l.trim()))
      .map((l) => l.split('=')[0]);
    expect(assigned.every((k) => k?.startsWith('VITE_ADMIN_'))).toBe(true);
    expect(envExample).not.toMatch(/eyJ[A-Za-z0-9_-]{20,}/); // JWT-shaped value
  });

  it('defines a restrictive Content-Security-Policy', () => {
    const csp = CONTENT_SECURITY_POLICY;
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain("script-src 'self'");
    expect(csp).toContain("base-uri 'none'");
    expect(csp).not.toMatch(/unsafe-eval|unsafe-inline|\*/);
  });

  it('injects the policy into the production page and nothing else', async () => {
    const html = '<!doctype html><html><head><title>x</title></head><body></body></html>';
    const plugin = cspPlugin();
    expect(plugin.apply).toBe('build'); // never into the dev server, which needs inline styles
    const hook = plugin.transformIndexHtml as (h: string) => string;
    const out = hook(html);
    expect(out).toContain(`http-equiv="Content-Security-Policy" content="${CONTENT_SECURITY_POLICY}"`);
    expect(() => hook('<html></html>')).toThrow(/no <head>/);
  });

  it('keeps index.html free of inline script and remote script', () => {
    expect(indexHtml).not.toMatch(/<script(?![^>]*src="\/src\/main\.tsx")[^>]*>/);
    expect(indexHtml).not.toMatch(/https?:\/\//);
  });
});
