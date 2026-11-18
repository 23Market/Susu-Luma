// Fails if the production bundle contains mock data or anything that looks like a server secret.
// Run after `npm run build`. Plain Node, no dependencies.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const FORBIDDEN = [
  [/Synthetic Supplier/, 'mock records'],
  [/Mock network failure/, 'mock scenario code'],
  [/00000000-0000-4000-8000-000000000001/, 'the mock user id'],
  [/service[_-]?role/i, 'a service-role reference'],
  [/sb_secret/i, 'a Supabase secret key prefix'],
  [/eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\./, 'a JWT-shaped value'],
];

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) yield* walk(p);
    else yield p;
  }
}

let files = 0;
const problems = [];
for (const file of walk('dist')) {
  if (!/\.(js|css|html|map)$/.test(file)) continue;
  files++;
  const text = readFileSync(file, 'utf8');
  for (const [re, what] of FORBIDDEN) if (re.test(text)) problems.push(`${file}: contains ${what}`);
}
if (files === 0) problems.push('dist/ has no files: run `npm run build` first');
if (problems.length) {
  console.error(problems.join('\n'));
  process.exit(1);
}
console.log(`check-bundle: ${files} files scanned, no mock data or secrets in the production bundle.`);
