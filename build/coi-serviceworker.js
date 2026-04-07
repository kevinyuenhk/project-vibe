/*
 * Cross-Origin Isolation Service Worker
 * Sets COOP/COEP headers on all responses so SharedArrayBuffer (required for
 * Godot thread support) works on GitHub Pages.
 */

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
    event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
    // Skip opaque requests that can't be cloned
    if (event.request.cache === 'only-if-cached' && event.request.mode !== 'same-origin') {
        return;
    }

    event.respondWith(
        fetch(event.request).then((response) => {
            // Don't modify opaque (cross-origin no-cors) responses
            if (response.status === 0) {
                return response;
            }

            const newHeaders = new Headers(response.headers);
            newHeaders.set('Cross-Origin-Opener-Policy', 'same-origin');
            newHeaders.set('Cross-Origin-Embedder-Policy', 'require-corp');
            newHeaders.set('Cross-Origin-Resource-Policy', 'cross-origin');

            return new Response(response.body, {
                status: response.status,
                statusText: response.statusText,
                headers: newHeaders,
            });
        }).catch((err) => {
            console.warn('[coi-sw] fetch failed:', err);
        })
    );
});
