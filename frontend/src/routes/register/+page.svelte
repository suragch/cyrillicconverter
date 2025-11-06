<script lang="ts">
    import { pb } from '$lib/pocketbase';
    import { goto } from '$app/navigation';

    let email = '';
    let password = '';
    let passwordConfirm = '';
    let errorMessage: string | null = null;

    async function register() {
        errorMessage = null;
        if (password !== passwordConfirm) {
            errorMessage = "Passwords do not match.";
            return;
        }

        try {
            await pb.collection('users').create({
                email,
                password,
                passwordConfirm,
            });
            // Optional: automatically log the user in
            await pb.collection('users').authWithPassword(email, password);
            goto('/');
        } catch (err: any) {
            errorMessage = `Failed to register: ${err.message}`;
            console.error("Registration failed:", err);
        }
    }
</script>

<div class="flex justify-center items-center h-full">
    <div class="w-full max-w-md p-8 space-y-6 bg-white rounded-lg shadow-md">
        <h1 class="text-2xl font-bold text-center">Register</h1>
        <form on:submit|preventDefault={register} class="space-y-6">
            <div>
                <label for="email" class="block mb-2 text-sm font-medium">Email</label>
                <input type="email" id="email" bind:value={email} class="w-full px-3 py-2 border rounded-lg" required />
            </div>
            <div>
                <label for="password" class="block mb-2 text-sm font-medium">Password</label>
                <input type="password" id="password" bind:value={password} class="w-full px-3 py-2 border rounded-lg" required />
            </div>
            <div>
                <label for="passwordConfirm" class="block mb-2 text-sm font-medium">Confirm Password</label>
                <input type="password" id="passwordConfirm" bind:value={passwordConfirm} class="w-full px-3 py-2 border rounded-lg" required />
            </div>
            {#if errorMessage}
                <p class="text-red-500 text-sm">{errorMessage}</p>
            {/if}
            <button type="submit" class="w-full px-4 py-2 text-white bg-blue-600 rounded-lg hover:bg-blue-700">Register</button>
        </form>
    </div>
</div>
