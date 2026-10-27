// BusWhere service worker: app shell works offline; map tiles cached as seen.
const VERSION = 'bw-v2';
const SHELL = ['./', 'index.html', 'manifest.json', 'favicon.png', 'icons/Icon-192.png', 'flutter_bootstrap.js', 'flutter.js', 'main.dart.js', 'assets/FontManifest.json', 'assets/AssetManifest.bin.json'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION && k !== 'bw-tiles').map((k) => caches.delete(k)))).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Map tiles: cache-first, keep a bounded set.
  if (url.hostname === 'tile.openstreetmap.org') {
    e.respondWith(
      caches.open('bw-tiles').then(async (c) => {
        const hit = await c.match(req);
        if (hit) return hit;
        const res = await fetch(req);
        if (res.ok || res.type === 'opaque') {
          c.put(req, res.clone());
          const keys = await c.keys();
          if (keys.length > 400) c.delete(keys[0]);
        }
        return res;
      })
    );
    return;
  }

  if (url.origin !== self.location.origin) return;

  // Pages: network first so updates land; fall back to the cached shell offline.
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).catch(() => caches.match('index.html')));
    return;
  }

  // Everything else from our origin: stale-while-revalidate.
  e.respondWith(
    caches.open(VERSION).then(async (c) => {
      const hit = await c.match(req);
      const net = fetch(req).then((res) => { if (res.ok) c.put(req, res.clone()); return res; }).catch(() => hit);
      return hit || net;
    })
  );
});
