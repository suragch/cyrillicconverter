// frontend/src/lib/pocketbase.ts
import PocketBase from 'pocketbase';

// The URL will eventually point to your Nginx reverse proxy
export const pb = new PocketBase('http://127.0.0.1:8090');