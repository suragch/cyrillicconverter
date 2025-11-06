
You are an expert SvelteKit developer. Your task is to complete Step 9 of the project plan by implementing the user interface and client-side logic for user authentication.

**Step 9: Implement User Authentication UI**

**Task:**
Your goal is to create the Svelte components and stores necessary for user registration, login, and managing the global authentication state using the PocketBase JavaScript SDK.

**Instructions:**

1.  **Install the Dependency:** In the `frontend` directory, add the `pocketbase` JavaScript SDK as a project dependency.
    ```bash
    npm install pocketbase
    ```

2.  **Initialize the PocketBase Client:**
    *   Create a new file at `frontend/src/lib/pocketbase.ts`.
    *   In this file, import `PocketBase`, create a new client instance, and export it. This singleton will be used by the rest of the application. For now, use a placeholder URL for the backend, which will be updated when the Nginx reverse proxy is configured.
    ```typescript
    // frontend/src/lib/pocketbase.ts
    import PocketBase from 'pocketbase';

    // The URL will eventually point to your Nginx reverse proxy
    export const pb = new PocketBase('http://127.0.0.1:8090'); 
    ```
    *(Note: PocketBase's default unproxied port is 8090. We use this as a placeholder).*

3.  **Create the Global Authentication Store:**
    *   Create a new file at `frontend/src/lib/stores/authStore.ts`.
    *   This file will contain a custom Svelte store to manage the application's authentication state.
    *   The store should:
        *   Be a `writable` store.
        *   Hold the current logged-in user model from PocketBase.
        *   Initialize its state by checking if a user is already logged in via `pb.authStore.model`.
        *   Expose methods for `login`, `register`, and `logout` that interact with the PocketBase client and update the store's value.

    ```typescript
    // frontend/src/lib/stores/authStore.ts
    import { writable } from 'svelte/store';
    import { pb } from '$lib/pocketbase';
    import type { Admin, Record } from 'pocketbase';

    export const currentUser = writable<Record | Admin | null>(pb.authStore.model);

    pb.authStore.onChange(() => {
        currentUser.set(pb.authStore.model);
    });
    ```

4.  **Implement the Registration Page:**
    *   Create a new route file at `frontend/src/routes/register/+page.svelte`.
    *   Build a simple HTML form with input fields for:
        *   Email (`type="email"`)
        *   Password (`type="password"`)
        *   Password Confirm (`type="password"`)
    *   On form submission, call the PocketBase `pb.collection('users').create(...)` method.
    *   Handle success by logging the user in automatically or redirecting them to the login page.
    *   Handle errors by displaying a message to the user (e.g., "Password confirmation does not match").

5.  **Implement the Login Page:**
    *   Create a new route file at `frontend/src/routes/login/+page.svelte`.
    *   Build an HTML form with input fields for:
        *   Email (`type="email"`)
        *   Password (`type="password"`)
    *   On form submission, call the `pb.collection('users').authWithPassword(...)` method.
    *   Use the `currentUser` store to reflect the new login state.
    *   Upon successful login, redirect the user to the homepage (`/`).
    *   Handle errors by displaying a message (e.g., "Invalid credentials").

6.  **Create a Reactive Navigation Bar:**
    *   Create a new component at `frontend/src/lib/components/Navbar.svelte`.
    *   This component will subscribe to the `currentUser` store.
    *   Use an `{#if ...}` block to conditionally render content:
        *   If a user is logged in (`$currentUser` is not null), display their email and a "Logout" button. The logout button should call `pb.authStore.clear()`.
        *   If no user is logged in, display "Login" and "Register" links pointing to the `/login` and `/register` routes.

7.  **Integrate the Navbar into the Global Layout:**
    *   Open the main layout file at `frontend/src/routes/+layout.svelte`.
    *   Import and include the `<Navbar />` component so that it appears on every page of the application.

Execute the plan.