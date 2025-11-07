<script lang="ts">
    import { authStore } from '$lib/stores/authStore';
    import { pb } from '$lib/pocketbase';
    import { goto } from '$app/navigation';

    function logout() {
        pb.authStore.clear();
        goto('/login');
    }
</script>

<nav class="bg-gray-800 text-white p-4">
    <div class="container mx-auto flex justify-between items-center">
        <a href="/" class="text-xl font-bold">Cyrillic Converter</a>
        <div class="flex items-center space-x-4">
            {#if $authStore}
                <span>{$authStore.email}</span>
                <button on:click={logout} class="hover:underline">Logout</button>
            {:else}
                <a href="/login" class="hover:underline">Login</a>
                <a href="/register" class="hover:underline">Register</a>
            {/if}
        </div>
    </div>
</nav>
