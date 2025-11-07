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
</style>