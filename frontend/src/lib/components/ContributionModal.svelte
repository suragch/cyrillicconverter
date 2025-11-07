<!-- frontend/src/lib/components/ContributionModal.svelte -->
<script lang="ts">
    import { db } from '$lib/db';
    import { createEventDispatcher, onMount } from 'svelte';

    export let cyrillicWord: string;
    export let context: string; // The full sentence for context

    let menksoftInput = '';
    let inputElement: HTMLInputElement;

    const dispatch = createEventDispatcher();

    async function handleSubmitAndSync() {
        if (!menksoftInput.trim()) {
            alert('Please enter the traditional Mongolian conversion.');
            return;
        }

        try {
            // 1. Prepare the payload
            const contributionPayload = {
                cyrillic_word: cyrillicWord,
                menksoft: menksoftInput,
                context: context
            };

            // 2. Save the submission to the local "outbox" (syncQueue)
            await db.syncQueue.add({
                payload: contributionPayload,
                timestamp: Date.now()
            });

            // 3. Get the Service Worker registration
            const registration = await navigator.serviceWorker.ready;

            // 4. Request a background sync. This will trigger the 'sync' event
            //    in the service worker, even if the user navigates away or closes the tab.
            await registration.sync.register('sync-contributions');

            // 5. Provide immediate feedback to the user and close the modal
            alert('Contribution saved and will be submitted to the community!');
            dispatch('close');

        } catch (error) {
            console.error('Failed to queue contribution for sync:', error);
            // Fallback for browsers that might not support background sync
            alert('Could not save contribution. Please try again later.');
        }
    }

    function handleSaveLocally() {
        if (menksoftInput.trim()) {
            // Existing logic to save to userContributions store...
            console.log('Saved locally.');
            dispatch('save', { menksoft: menksoftInput.trim() });
        }
    }

    function handleClose() {
        dispatch('close');
    }

    // Focus the input field when the modal appears
    onMount(() => {
        inputElement.focus();
    });
</script>

<div class="overlay" on:click={handleClose}></div>

<div class="modal-box" role="dialog" aria-modal="true">
    <h2 class="display-title">Add Translation for "{cyrillicWord}"</h2>
    
    <div class="context-snippet">
        <p><strong>Context:</strong> "{context}"</p>
    </div>

    <div class="form-group">
        <label for="menksoft-input">Traditional Mongolian (Menksoft)</label>
        <input 
            type="text" 
            id="menksoft-input" 
            bind:this={inputElement}
            bind:value={menksoftInput}
            placeholder="Enter Menksoft translation..."
            on:keydown={(e) => e.key === 'Enter' && handleSubmitAndSync()}
        />
    </div>

    <div class="live-preview">
        <!-- For now, a simple text preview. This can be enhanced later. -->
        <p>Preview: {menksoftInput}</p>
    </div>
    
    <div class="actions">
        <button class="secondary" on:click={handleSaveLocally}>Save Locally</button>
        <button class="primary" on:click={handleSubmitAndSync}>Save & Submit</button>
    </div>
</div>

<style>
    /* Add basic modal styles based on the UX Guide */
    .overlay {
        position: fixed;
        inset: 0;
        background-color: rgba(0, 0, 0, 0.5);
        z-index: 999;
    }
    .modal-box {
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background-color: white;
        padding: 24px;
        border-radius: 8px;
        z-index: 1000;
        width: 90%;
        max-width: 500px;
    }
    .display-title { font-size: 24px; font-weight: 500; margin-bottom: 16px; }
    .context-snippet { background-color: #F9F9F9; padding: 8px; border-radius: 4px; margin-bottom: 16px; font-style: italic; color: #6B6B6B; }
    .actions { margin-top: 24px; display: flex; justify-content: flex-end; gap: 8px; }
    /* Add button, input, etc. styles as needed */
</style>