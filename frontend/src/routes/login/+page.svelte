<script lang="ts">
    import { pb } from '$lib/pocketbase';
    import { goto } from '$app/navigation';
    

    let email = '';
    let password = '';
    let errorMessage: string | null = null;

    async function login() {
        errorMessage = null;
        try {
            await pb.collection('users').authWithPassword(email, password);
            // The authStore will update automatically via the onChange hook
            goto('/');
        } catch (err: any) {
            errorMessage = `Failed to login: ${err.message}`;
            console.error("Login failed:", err);
        }
    }
</script>

<div class="flex justify-center items-center h-full">
    <div class="w-full max-w-md p-8 space-y-6 bg-white rounded-lg shadow-md">
        <h1 class="text-2xl font-bold text-center">Login</h1>
        <form on:submit|preventDefault={login} class="space-y-6">
            <div>
                <label for="email" class="block mb-2 text-sm font-medium">Email</label>
                <input type="email" id="email" bind:value={email} class="w-full px-3 py-2 border rounded-lg" required />
            </div>
            <div>
                <label for="password" class="block mb-2 text-sm font-medium">Password</label>
                <input type="password" id="password" bind:value={password} class="w-full px-3 py-2 border rounded-lg" required />
            </div>
            {#if errorMessage}
                <p class="text-red-500 text-sm">{errorMessage}</p>
            {/if}
            <button type="submit" class="w-full px-4 py-2 text-white bg-blue-600 rounded-lg hover:bg-blue-700">Login</button>
        </form>
    </div>
</div>
