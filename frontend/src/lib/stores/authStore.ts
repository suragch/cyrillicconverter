// frontend/src/lib/stores/authStore.ts

import { writable, derived } from 'svelte/store';
import { pb as pocketbase } from '$lib/pocketbase'; // Your PocketBase client instance
import type { AuthModel } from 'pocketbase';

// Your existing writable store
export const authStore = writable<AuthModel | null>(pocketbase.authStore.model);

// Keep the store in sync with PocketBase's authStore
pocketbase.authStore.onChange((auth) => {
    console.log('Auth store changed:', auth);
    authStore.set(pocketbase.authStore.model);
});

// --- NEW DERIVED STORE ---
// This store derives its value from authStore.
// It provides a simple boolean indicating if the logged-in user is a moderator.
export const isModerator = derived(
  authStore,
  ($authStore) => {
    // If not logged in ($authStore is null), not a moderator.
    // Otherwise, check for the custom 'is_moderator' field.
    return $authStore ? ($authStore as any).is_moderator === true : false;
  }
);