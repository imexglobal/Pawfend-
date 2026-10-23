// Service worker: shows chat notifications and opens the right chat when one is tapped.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('push', e => {
  const d = e.data ? e.data.json() : {};
  e.waitUntil(self.registration.showNotification(d.title || '멍냥이웃', {
    body: d.body || '',
    tag: d.tag,
    renotify: true,
    icon: 'icon-192.png',
    badge: 'icon-192.png',
    data: {url: d.url || './'},
  }));
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = new URL(e.notification.data?.url || './', self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({type: 'window', includeUncontrolled: true}).then(list => {
    const open = list[0];
    if (open){ open.postMessage({type: 'open', url}); return open.focus(); }
    return self.clients.openWindow(url);
  }));
});
