/// <reference types="@sveltejs/kit" />
/// <reference no-default-lib="true"/>
/// <reference lib="esnext" />
/// <reference lib="webworker" />

import { build, files, version } from '$service-worker';
import { db, type QueuedContribution } from './lib/db';

const CACHE = `cache-${version}`;
const ASSETS = [...build, ...files];

// Standard install and activate event listeners
self.addEventListener('install', (event: any) => {
    async function addFilesToCache() {
        const cache = await caches.open(CACHE);
        await cache.addAll(ASSETS);
    }
    event.waitUntil(addFilesToCache());
});

self.addEventListener('activate', (event: any) => {
    async function deleteOldCaches() {
        for (const key of await caches.keys()) {
            if (key !== CACHE) await caches.delete(key);
        }
    }
    event.waitUntil(deleteOldCaches());
});

// Fetch handler remains the same
self.addEventListener('fetch', (event: any) => {
    if (event.request.method !== 'GET') return;
    async function respond() {
        const url = new URL(event.request.url);
        const cache = await caches.open(CACHE);
        if (ASSETS.includes(url.pathname)) {
            const fromCache = await cache.match(event.request);
            if (fromCache) return fromCache;
        }
        try {
            const response = await fetch(event.request);
            if (response.status === 200) {
                cache.put(event.request, response.clone());
            }
            return response;
        } catch {
            const fromCache = await cache.match(event.request);
            if (fromCache) return fromCache;
            throw new Error("failed to fetch");
        }
    }
    event.respondWith(respond());
});

// --- NEW SYNC EVENT LISTENER ---
self.addEventListener('sync', (event: any) => {
    if (event.tag === 'sync-contributions') {
        console.log('Service Worker: Sync event for contributions received.');
        event.waitUntil(syncContributions());
    }
});

async function syncContributions() {
    console.log('Service Worker: Starting contribution sync process.');
    const queuedItems = await db.syncQueue.toArray();

    for (const item of queuedItems) {
        try {
            const response = await fetch('/api/conversions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(item.payload)
            });

            if (response.ok) {
                console.log(`Service Worker: Successfully synced contribution ID: ${item.id}`);
                // If the POST was successful, remove it from the queue
                await db.syncQueue.delete(item.id!);
            } else {
                console.error(`Service Worker: API error for contribution ID ${item.id}. Status: ${response.status}`);
                // If there was a server error, we leave it in the queue for the next sync.
            }
        } catch (error) {
            console.error(`Service Worker: Network error syncing contribution ID ${item.id}. Will retry later.`);
            // If a network error occurs, break the loop and wait for the next sync event.
            return;
        }
    }
    console.log('Service Worker: Contribution sync process finished.');
}
