To implement Step 14, "Implement Frontend-to-Backend Contribution Sync," you will modify three key frontend files. The goal is to send user contributions to the backend API when online and queue them for later submission using the Service Worker's Background Sync API if the user is offline.

This implementation will follow a robust "outbox" pattern: all submissions are first saved to a local "outbox" in IndexedDB, then the network request is attempted. This ensures no data is lost.

### 👉 **Step 1: Update the IndexedDB Schema**

First, define a new "outbox" table in your client-side database to temporarily store submissions that need to be synced with the server.

**File to Edit:** `frontend/src/lib/db.ts`

**Instructions:**
Add a new object store named `syncQueue` to your Dexie database schema. This store will hold the contribution payloads. An auto-incrementing primary key `id` is sufficient.

```typescript
import Dexie, { type Table } from 'dexie';

// Define the structure of the data you'll queue
export interface QueuedContribution {
  id?: number;
  payload: {
    cyrillic_word: string;
    menksoft: string;
    context: string;
  };
  timestamp: number;
}

export class MySubClassedDexie extends Dexie {
  // Define tables (object stores)
  cyrillicWords!: Table<any>;
  traditionalConversions!: Table<any>;
  abbreviations!: Table<any>;
  expansions!: Table<any>;
  userContributions!: Table<any>;
  syncQueue!: Table<QueuedContribution>; // <<< ADD THIS LINE

  constructor() {
    super('mongol-converter-db');
    this.version(2).stores({ // <<< INCREMENT THE VERSION NUMBER
      cyrillicWords: '++id, cyrillic_word',
      traditionalConversions: '++id, word_id, traditional',
      abbreviations: '++id, cyrillic_abbreviation',
      expansions: '++id, abbreviation_id',
      userContributions: '++id, cyrillic_word',
      syncQueue: '++id, timestamp' // <<< ADD THIS SCHEMA DEFINITION
    });
  }
}

export const db = new MySubClassedDexie();
```

**Note:** Incrementing the database `version()` is crucial for the new schema to be applied.

### 👉 **Step 2: Update the Contribution Modal Logic**

Modify the modal to save submissions to the `syncQueue`, attempt to send them to the server, and register a background sync task if the network request fails.

**File to Edit:** `frontend/src/lib/components/ContributionModal.svelte`

**Instructions:**
1.  Import the `db` instance.
2.  Create a new `handleSubmitAndSync` function.
3.  This function will first write the contribution to the `syncQueue` table in IndexedDB.
4.  It will then register a background sync task with the service worker using a specific tag (e.g., `'sync-contributions'`). This ensures that even if the initial network request fails, the service worker will attempt to sync later.

```svelte
<script lang="ts">
	import { db } from '$lib/db';
	import { createEventDispatcher } from 'svelte';

	export let word: string;
	export let context: string;

	let menksoftInput = '';
	let dispatch = createEventDispatcher();

	// This function handles the "Save & Submit" action
	async function handleSubmitAndSync() {
		if (!menksoftInput.trim()) {
			alert('Please enter the traditional Mongolian conversion.');
			return;
		}

		try {
			// 1. Prepare the payload
			const contributionPayload = {
				cyrillic_word: word,
				menksoft: menksoftInput,
				context: context
			};

			// 2. Save the submission to the local "outbox" (syncQueue)
			await db.syncQueue.add({
				payload: contributionPayload,
				timestamp: Date.now()
			});

			// 3. Get the Service Worker registration
			const registration = await navigator.serviceWorker.ready;
			
			// 4. Request a background sync. This will trigger the 'sync' event
			//    in the service worker, even if the user navigates away or closes the tab.
			await registration.sync.register('sync-contributions');

			// 5. Provide immediate feedback to the user and close the modal
			alert('Contribution saved and will be submitted to the community!');
			dispatch('close');

		} catch (error) {
			console.error('Failed to queue contribution for sync:', error);
			// Fallback for browsers that might not support background sync
			alert('Could not save contribution. Please try again later.');
		}
	}

	function handleSaveLocally() {
		// Existing logic to save to userContributions store...
		console.log('Saved locally.');
		dispatch('close');
	}
</script>

<!-- Assume your modal HTML structure is here -->
<div class="modal-content">
	<h2>Add to Dictionary</h2>
	<p>Context: "<em>{context}</em>"</p>
	<p>Cyrillic: <strong>{word}</strong></p>
	
	<input
		type="text"
		bind:value={menksoftInput}
		placeholder="Enter Menksoft equivalent"
	/>

	<div class="actions">
		<button on:click={handleSaveLocally}>Save Locally</button>
		<button on:click={handleSubmitAndSync} class="primary">Save & Submit</button>
	</div>
</div>
```

### 👉 **Step 3: Implement the Service Worker Sync Handler**

Finally, add the logic to the service worker to process the sync events. It will read the queued items from IndexedDB and attempt to POST them to the backend.

**File to Edit:** `frontend/src/service-worker.ts`

**Instructions:**
1.  Import the `db` instance.
2.  Add a `'sync'` event listener to the service worker's global scope (`self`).
3.  Inside the listener, check if the event's `tag` matches `'sync-contributions'`.
4.  If it matches, call a function (`syncContributions`) that reads all items from the `syncQueue`, attempts to `fetch` them to the `/api/conversions` endpoint, and deletes them from the queue upon success.

```typescript
/// <reference types="@sveltejs/kit" />
import { build, files, version } from '$service-worker';
import { db, type QueuedContribution } from '$lib/db';

const CACHE = `cache-${version}`;
const ASSETS = [...build, ...files];

// Standard install and activate event listeners
self.addEventListener('install', (event) => {
	async function addFilesToCache() {
		const cache = await caches.open(CACHE);
		await cache.addAll(ASSETS);
	}
	event.waitUntil(addFilesToCache());
});

self.addEventListener('activate', (event) => {
	async function deleteOldCaches() {
		for (const key of await caches.keys()) {
			if (key !== CACHE) await caches.delete(key);
		}
	}
	event.waitUntil(deleteOldCaches());
});

// Fetch handler remains the same
self.addEventListener('fetch', (event) => {
	if (event.request.method !== 'GET') return;
	async function respond() {
		const url = new URL(event.request.url);
		const cache = await caches.open(CACHE);
		if (ASSETS.includes(url.pathname)) {
			return cache.match(event.request);
		}
		try {
			const response = await fetch(event.request);
			if (response.status === 200) {
				cache.put(event.request, response.clone());
			}
			return response;
		} catch {
			return cache.match(event.request);
		}
	}
	event.respondWith(respond());
});

// --- NEW SYNC EVENT LISTENER ---
self.addEventListener('sync', (event) => {
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
```

With these changes, your application will now correctly handle online and offline contribution submissions, ensuring data integrity and a seamless user experience.