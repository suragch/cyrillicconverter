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
