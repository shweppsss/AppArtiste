/* =============================================================================
 * NONAME × DEGZZY — Service Worker
 * =============================================================================
 * Rôles :
 *   1. Cache offline (l'app s'ouvre sans réseau avec la dernière version connue).
 *   2. Auto-update : nouvelle version → bascule au prochain boot.
 *
 * Push notifications removed — the underlying notifications-table INSERT
 * webhook never fired (frontend stores everything in workspace.state JSON),
 * so the entire push subsystem was dead code.
 *
 * IMPORTANT — bump CACHE_VERSION à chaque release pour invalider le cache offline.
 * ============================================================================= */

const CACHE_VERSION = 'noname-v1';
const RUNTIME_CACHE = 'noname-runtime-v1';

// Ressources mises en cache au moment de l'install. Garde la liste minimale :
// l'app est mono-fichier, donc index.html + manifest + icônes suffisent.
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png'
];

// ============================================================================
// INSTALL — pré-cache des ressources statiques
// ============================================================================
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => {
      // addAll est atomique : si une seule URL échoue, l'install échoue.
      // On utilise add() individuel pour tolérer les ressources absentes (icônes manquantes).
      return Promise.all(
        PRECACHE_URLS.map((url) =>
          cache.add(url).catch((err) => console.warn('[SW] precache miss:', url, err))
        )
      );
    }).then(() => self.skipWaiting())
  );
});

// ============================================================================
// ACTIVATE — nettoyage des anciens caches
// ============================================================================
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== CACHE_VERSION && k !== RUNTIME_CACHE)
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// ============================================================================
// FETCH — stratégies par type de requête
// ============================================================================
// Règles :
//   • API Supabase (REST + Realtime + Auth) → toujours réseau, jamais cache.
//   • Navigation HTML (/, /index.html) → Network First, fallback cache offline.
//   • Reste (CDN, images, manifest, icônes) → Cache First, refresh en arrière-plan.
// ============================================================================
self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Ne touche pas aux requêtes non-GET (POST/PATCH/DELETE Supabase, etc.)
  if (req.method !== 'GET') return;

  // Bypass total pour les domaines API (Supabase, WebSocket, auth)
  if (
    url.hostname.endsWith('.supabase.co') ||
    url.hostname.endsWith('.supabase.in') ||
    url.protocol === 'wss:' ||
    url.protocol === 'ws:'
  ) {
    return; // laisse le navigateur faire son fetch normal
  }

  // Navigation HTML — Network First avec fallback offline
  if (req.mode === 'navigate' || req.destination === 'document') {
    event.respondWith(networkFirst(req));
    return;
  }

  // Tout le reste — Cache First avec revalidation en arrière-plan
  event.respondWith(cacheFirst(req));
});

async function networkFirst(req) {
  try {
    const fresh = await fetch(req);
    if (fresh && fresh.ok) {
      const cache = await caches.open(RUNTIME_CACHE);
      cache.put(req, fresh.clone()).catch(() => {});
    }
    return fresh;
  } catch (err) {
    const cached = await caches.match(req) || await caches.match('/index.html') || await caches.match('/');
    if (cached) return cached;
    return new Response('Offline — pas de version en cache', { status: 503, statusText: 'Offline' });
  }
}

async function cacheFirst(req) {
  const cached = await caches.match(req);
  if (cached) {
    // Revalidate en arrière-plan (stale-while-revalidate)
    fetch(req).then((fresh) => {
      if (fresh && fresh.ok) {
        caches.open(RUNTIME_CACHE).then((c) => c.put(req, fresh).catch(() => {}));
      }
    }).catch(() => {});
    return cached;
  }
  try {
    const fresh = await fetch(req);
    if (fresh && fresh.ok) {
      const cache = await caches.open(RUNTIME_CACHE);
      cache.put(req, fresh.clone()).catch(() => {});
    }
    return fresh;
  } catch (err) {
    return new Response('', { status: 504 });
  }
}

// ============================================================================
// MESSAGE — protocole interne (l'app peut demander au SW de se mettre à jour)
// ============================================================================
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
