// Yalnızca sayfanın kendi dosyalarını (uygulama kabuğunu) önbelleğe alır;
// Whisper modeli gibi büyük, başka kökenden gelen dosyalara hiç dokunmaz —
// onların önbelleklemesi worker.js'teki ChunkedCache'in işi.
//
// CACHE_NAME'i her anlamlı dosya değişikliğinde artırın: bu hem eski
// önbelleği temizletir hem de kurulum sırasında dosyaların taze (tarayıcı
// HTTP önbelleğinden değil, ağdan) alınmasını garanti eder.
const CACHE_NAME = "odt-altyazici-app-shell-v4";
const APP_SHELL = [
  "./index.html",
  "./app.js",
  "./worker.js",
  "./srt.mjs",
  "./chatgpt-prompts.mjs",
  "./styles.css",
  "./manifest.webmanifest",
  "./fonts/DepartureMono-Regular.woff2",
  "./icons/icon.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) =>
        Promise.all(
          APP_SHELL.map((url) =>
            fetch(url, { cache: "reload" }).then((resp) => cache.put(url, resp))
          )
        )
      )
      .then(() => self.skipWaiting())
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
  // Ağ varsa her zaman taze sürümü al (ve önbelleği güncelle); yalnızca ağ
  // başarısız olursa (çevrimdışıyken) önbellekten sun. Bu sayede bir deploy
  // sonrası ilk yenilemede bile eski sürümde takılı kalınmaz — ayrı bir
  // "yeni sürüm var" bildirimine gerek kalmaz.
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
