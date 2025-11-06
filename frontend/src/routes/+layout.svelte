<script lang="ts">
    import { onMount } from 'svelte';
    import '../app.css'; // Import global Tailwind CSS
    import { db } from '$lib/db';

    onMount(async () => {
        try {
            await db.open();
            console.log('Database opened successfully');
        } catch (error) {
            console.error('Failed to open database:', error);
        }
    });
</script>

<div class="min-h-screen bg-white text-near-black flex flex-col items-center p-4 sm:p-8 font-inter">
    <main class="w-full max-w-7xl flex-grow">
        <slot />
    </main>
</div>