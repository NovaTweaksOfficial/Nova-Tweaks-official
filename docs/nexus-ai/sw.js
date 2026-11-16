const VERSION = 'v1'
const SHELL_CACHE = `nexus-shell-${VERSION}`
const ASSET_CACHE = `nexus-assets-${VERSION}`

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL_CACHE)
      await cache.addAll([new URL('./', self.registration.scope).href]).catch(() => undefined)
      await self.skipWaiting()
    })(),
  )
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keep = new Set([SHELL_CACHE, ASSET_CACHE])
      for (const name of await caches.keys()) {
        if (!keep.has(name)) await caches.delete(name)
      }
      await self.clients.claim()
    })(),
  )
})

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting()
})

self.addEventListener('fetch', (event) => {
  const req = event.request
  if (req.method !== 'GET') return
  const url = new URL(req.url)
  if (url.origin !== self.location.origin) return

  if (req.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const res = await fetch(req, { cache: 'reload' })
          const cache = await caches.open(SHELL_CACHE)
          cache.put(new URL('./', self.registration.scope).href, res.clone())
          return res
        } catch {
          const cache = await caches.open(SHELL_CACHE)
          const shell = (await cache.match(new URL('./', self.registration.scope).href)) || (await cache.match(req))
          if (shell) return shell
          return new Response('NEXUS AI is offline.', { status: 503, headers: { 'Content-Type': 'text/plain' } })
        }
      })(),
    )
    return
  }

  event.respondWith(
    (async () => {
      const cache = await caches.open(ASSET_CACHE)
      const hit = await cache.match(req)
      const network = fetch(req).then((res) => { if (res.ok) cache.put(req, res.clone()); return res }).catch(() => null)
      if (hit) { network.catch(() => undefined); return hit }
      const res = await network
      if (res) return res
      return new Response('', { status: 504 })
    })(),
  )
})