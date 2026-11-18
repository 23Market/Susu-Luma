import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const dist = fileURLToPath(new URL('../dist/', import.meta.url));
async function findAssets(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map((entry) => {
      const path = join(directory, entry.name);
      return entry.isDirectory() ? findAssets(path) : /\.(js|css|html)$/.test(entry.name) ? [path] : [];
    }),
  );
  return nested.flat();
}

const assets = await findAssets(dist);
if (assets.length === 0) throw new Error('Production bundle is empty.');

const forbidden = [
  'MOCK_FIXTURE_ONLY',
  'SYN-1001',
  'synthetic-reviewer',
  'SUPABASE_SERVICE_ROLE_KEY',
  'service_role',
];
for (const file of assets) {
  const content = await readFile(file, 'utf8');
  const match = forbidden.find((value) => content.includes(value));
  if (match) throw new Error(`Production bundle contains prohibited content: ${match}`);
}

console.log(`check:bundle: ${assets.length} production assets contain no mock data or service secrets.`);
