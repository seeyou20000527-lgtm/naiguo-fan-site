const CACHE = "naiguo-app-v11";
const CORE = [
  "./index.html",
  "./admin-config.js",
  "./public-data.js",
  "./manifest.webmanifest",
  "./assets/app-icon.png",
  "./assets/icon-192.png",
  "./assets/icon-512.png",
  "./assets/logo.png",
  "./assets/character-short.png",
  "./assets/character-long.png"
];
self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith("naiguo-app-") && key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) return;
  const url = new URL(request.url);
  if (request.mode === "navigate" && (url.pathname.endsWith("/") || url.pathname.endsWith("/index.html"))) {
    event.respondWith(caches.match("./index.html").then(cached => cached || fetch(request)));
    return;
  }
  event.respondWith(caches.match(request).then(cached => cached || fetch(request)));
});
