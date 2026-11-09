// Yalnızca sayfanın kendi dosyalarını (uygulama kabuğunu) önbelleğe alır;
// Whisper modeli gibi büyük, başka kökenden gelen dosyalara hiç dokunmaz —
// onların önbelleklemesi worker.js'teki ChunkedCache'in işi.
const CACHE_NAME = "odt-altyazici-app-shell-v1";
const APP_SHELL = [
  "./index.html",
  "./app.js",
  "./worker.js",
  "./srt.mjs",
  "./styles.css",
  "./manifest.webmanifest",
  "./fonts/DepartureMono-Regular.woff2",
  "./icons/icon.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((names) => Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== "GET" || url.origin !== self.location.origin) {
    return; // Başka kökenden gelen istekleri (model, CDN) olduğu gibi bırak.
  }
  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request))
  );
});
