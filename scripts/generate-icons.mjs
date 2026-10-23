import { mkdir } from 'node:fs/promises';
import sharp from 'sharp';

const cream = { r: 255, g: 248, b: 241, alpha: 1 };
const source = sharp('icon-512.png').resize(1024, 1024, { fit: 'fill' });

await mkdir('assets', { recursive: true });
await source.clone().png().toFile('assets/icon.png');

// Inset the artwork so Android's circular mask and the PWA maskable icon
// keep the paw inside the safe zone.
const inset = await sharp('icon-512.png')
  .resize(680, 680, { fit: 'fill' })
  .png()
  .toBuffer();
await sharp({ create: { width: 1024, height: 1024, channels: 4, background: cream } })
  .composite([{ input: inset, gravity: 'centre' }])
  .png()
  .toFile('assets/icon-foreground.png');
await sharp({ create: { width: 1024, height: 1024, channels: 4, background: cream } })
  .png()
  .toFile('assets/icon-background.png');

const maskInset = await sharp('icon-512.png').resize(340, 340, { fit: 'fill' }).png().toBuffer();
await sharp({ create: { width: 512, height: 512, channels: 4, background: cream } })
  .composite([{ input: maskInset, gravity: 'centre' }])
  .png()
  .toFile('icon-maskable-512.png');

const splashIcon = await sharp('icon-512.png').resize(860, 860, { fit: 'fill' }).png().toBuffer();
await sharp({ create: { width: 2732, height: 2732, channels: 4, background: cream } })
  .composite([{ input: splashIcon, gravity: 'centre' }])
  .png()
  .toFile('assets/splash.png');
await sharp({ create: { width: 2732, height: 2732, channels: 4, background: { r: 23, g: 18, b: 15, alpha: 1 } } })
  .composite([{ input: splashIcon, gravity: 'centre' }])
  .png()
  .toFile('assets/splash-dark.png');

console.log('icons ready');
