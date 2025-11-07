### **Objective: Implement Step 16**

Your goal is to create a new, protected section in the SvelteKit frontend where users with a 'moderator' role can view and act upon pending submissions. This involves updating the global authentication store to recognize moderators, creating a protected layout to guard the route, and building the dashboard page itself to fetch data and handle moderation actions.

### 👉 **Part 1: Update the Authentication Store to Expose Moderator Role**

First, enhance the global `authStore` to make it easy for any component to know if the current user is a moderator. A Svelte derived store is perfect for this.

**File to Edit:** `frontend/src/lib/stores/authStore.ts`

**Instructions:**
1.  Import `derived` from `svelte/store`.
2.  Assuming your main `authStore` holds the PocketBase user model (which includes the custom `is_moderator` field), create a new derived store called `isModerator`.
3.  This new store will automatically update whenever the main `authStore` changes, providing a simple boolean `true` or `false`.

```typescript
// frontend/src/lib/stores/authStore.ts

import { writable, derived } from 'svelte/store';
import pocketbase from '$lib/pocketbase'; // Your PocketBase client instance
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
```

### 👉 **Part 2: Create a Protected Layout for the Moderation Section**

Next, create a SvelteKit layout that acts as a guard. Any route inside `/moderation/` will use this layout, which will check the user's role and redirect them if they are not a moderator.

**File to Create:** `frontend/src/routes/moderation/+layout.svelte`

**Instructions:**
1.  Create the new file.
2.  In the script section, import `onMount` from `svelte`, `goto` from `$app/navigation`, and the `isModerator` store.
3.  Use `onMount` to ensure the code runs only on the client-side.
4.  Subscribe to the `isModerator` store. In the subscription callback, if the value is `false`, use `goto('/')` to redirect the user to the homepage immediately.
5.  The `<slot />` component is crucial; it renders the actual page content (like `+page.svelte`) if the user is authorized.

```svelte
<!-- frontend/src/routes/moderation/+layout.svelte -->

<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { isModerator } from '$lib/stores/authStore';

	onMount(() => {
		const unsubscribe = isModerator.subscribe((isMod) => {
			// This check runs whenever the moderator status changes.
			// If the user is definitively not a moderator, redirect them.
			if (isMod === false) {
				console.log('Access Denied: User is not a moderator. Redirecting...');
				goto('/');
			}
		});

		// Clean up the subscription when the component is destroyed
		return () => unsubscribe();
	});
</script>

<!-- If the user is a moderator, the page content will be rendered here -->
<div class="moderation-container">
	<slot />
</div>

<style>
	.moderation-container {
		padding: 2rem;
		max-width: 1200px;
		margin: 0 auto;
	}
</style>```

### 👉 **Part 3: Build the Moderation Dashboard Page Component**

Finally, create the page that fetches and displays pending submissions and allows moderators to take action.

**File to Create:** `frontend/src/routes/moderation/+page.svelte`

**Instructions:**
1.  Create the main page component.
2.  Import `onMount`, the `authStore`, and necessary types.
3.  In the `<script>` block:
    a. Define state variables for `pendingSubmissions`, `isLoading`, and the user's `token`.
    b. Use `onMount` to fetch the pending submissions from the `/api/moderation/conversions/pending` endpoint.
    c. You **must** get the JWT from the `authStore` and include it in the `Authorization: Bearer <token>` header of your `fetch` request.
    d. Create `async` functions `handleApprove(id)` and `handleReject(id)`.
    e. These functions will make `POST` requests to the respective moderation endpoints (e.g., `/api/moderation/conversion/${id}/approve`), also including the auth header.
    f. For a responsive UI, upon successful approval/rejection, filter the local `pendingSubmissions` array to immediately remove the item without needing a full page reload.
4.  In the HTML template:
    a. Show a loading message while `isLoading` is true.
    b. If not loading and the submission list is empty, show a "No pending submissions" message.
    c. Use an `{#each}` block to loop through `pendingSubmissions` and display them in a table or list.
    d. For each item, display the Cyrillic word, the proposed Traditional conversion, and the context.
    e. Add "Approve" and "Reject" buttons with `on:click` handlers that call your `handleApprove` and `handleReject` functions, passing the item's `conversion_id`.

```svelte
<!-- frontend/src/routes/moderation/+page.svelte -->

<script lang="ts">
	import { onMount } from 'svelte';
	import { authStore } from '$lib/stores/authStore';

	interface PendingSubmission {
		conversion_id: number;
		cyrillic_word: string;
		traditional: string;
		context: string;
		approval_count: number;
	}

	let pendingSubmissions: PendingSubmission[] = [];
	let isLoading = true;
	let errorMessage: string | null = null;
	let token: string | null = null;

	// Get the auth token to make API requests
	authStore.subscribe((value) => {
		token = value?.token ?? null;
	});

	async function fetchPendingSubmissions() {
		if (!token) return;
		isLoading = true;
		errorMessage = null;

		try {
			const response = await fetch('/api/moderation/conversions/pending', {
				headers: {
					Authorization: `Bearer ${token}`
				}
			});

			if (!response.ok) {
				throw new Error(`Failed to fetch: ${response.statusText}`);
			}
			pendingSubmissions = await response.json();
		} catch (err: any) {
			errorMessage = err.message;
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		// Fetch data as soon as the component is mounted and we have a token
		if (token) {
			fetchPendingSubmissions();
		}
	});

	async function handleAction(id: number, action: 'approve' | 'reject') {
		if (!token) return;

		try {
			const response = await fetch(`/api/moderation/conversion/${id}/${action}`, {
				method: 'POST',
				headers: {
					Authorization: `Bearer ${token}`
				}
			});

			if (!response.ok) {
				throw new Error(`Action failed: ${response.statusText}`);
			}
			
			// For instant UI feedback, remove the item from the list
			pendingSubmissions = pendingSubmissions.filter((item) => item.conversion_id !== id);
		} catch (err: any) {
			alert(`Error: ${err.message}`);
		}
	}
</script>

<div class="dashboard">
	<h1>Moderation Dashboard</h1>
	<p>Review new community submissions for Traditional Mongolian conversions.</p>

	{#if isLoading}
		<p>Loading submissions...</p>
	{:else if errorMessage}
		<p class="error">Error: {errorMessage}</p>
	{:else if pendingSubmissions.length === 0}
		<p>No pending submissions to review. Great job!</p>
	{:else}
		<table>
			<thead>
				<tr>
					<th>Cyrillic Word</th>
					<th>Proposed Traditional</th>
					<th>Context</th>
					<th>Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each pendingSubmissions as item (item.conversion_id)}
					<tr>
						<td>{item.cyrillic_word}</td>
						<td>{item.traditional}</td>
						<td class="context">"{item.context}"</td>
						<td class="actions">
							<button class="approve" on:click={() => handleAction(item.conversion_id, 'approve')}>
								Approve
							</button>
							<button class="reject" on:click={() => handleAction(item.conversion_id, 'reject')}>
								Reject
							</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	{/if}
</div>

<style>
	/* Add some basic styling for clarity */
	table {
		width: 100%;
		border-collapse: collapse;
		margin-top: 1.5rem;
	}
	th, td {
		border: 1px solid #e0e0e0;
		padding: 0.75rem;
		text-align: left;
	}
	th {
		background-color: #f9f9f9;
	}
	.context {
		font-style: italic;
		color: #6b6b6b;
	}
	.actions {
		display: flex;
		gap: 0.5rem;
	}
	.approve { background-color: #28a745; color: white; }
	.reject { background-color: #dc3545; color: white; }
</style>
```

After completing these steps, a logged-in moderator can navigate to the `/moderation` route, view pending submissions, and approve or reject them, with all actions being securely communicated to the backend. Non-moderators will be redirected away from this page.