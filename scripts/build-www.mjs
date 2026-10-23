import { cp, mkdir, rm } from 'node:fs/promises';

const files = [
  'index.html',
  'config.js',
  'sw.js',
  'manifest.webmanifest',
  'icon-192.png',
  'icon-512.png',
  'icon-maskable-512.png',
  'privacy.html',
  'support.html',
  'terms.html',
];

await rm('www', { recursive: true, force: true });
await mkdir('www', { recursive: true });
for (const file of files) await cp(file, `www/${file}`);
console.log('www/ ready');
