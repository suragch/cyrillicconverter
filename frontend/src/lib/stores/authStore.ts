// frontend/src/lib/stores/authStore.ts
import { writable } from 'svelte/store';
import { pb } from '$lib/pocketbase';
import type { Admin, Record } from 'pocketbase';

export const currentUser = writable<Record | Admin | null>(pb.authStore.model);

pb.authStore.onChange(() => {
    currentUser.set(pb.authStore.model);
});