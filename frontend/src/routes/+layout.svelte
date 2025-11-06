<script lang="ts">
    import { onMount } from 'svelte';
    import '../app.css'; // Import global Tailwind CSS
    import { db } from '$lib/db';
    import Navbar from '$lib/components/Navbar.svelte';

    onMount(async () => {
        try {
            await db.open();
            console.log('Database opened successfully');
        } catch (error) {
            console.error('Failed to open database:', error);
        }
    });
</script>

<Navbar />

<main class="container mx-auto p-4">
    <slot />
</main>