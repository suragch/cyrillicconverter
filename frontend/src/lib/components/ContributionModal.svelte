<!-- frontend/src/lib/components/ContributionModal.svelte -->
<script lang="ts">
    import { createEventDispatcher, onMount } from 'svelte';

    export let cyrillicWord: string;
    export let context: string; // The full sentence for context

    let menksoftInput = '';
    let inputElement: HTMLInputElement;

    const dispatch = createEventDispatcher();

    function handleSave() {
        if (menksoftInput.trim()) {
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
            on:keydown={(e) => e.key === 'Enter' && handleSave()}
        />
    </div>

    <div class="live-preview">
        <!-- For now, a simple text preview. This can be enhanced later. -->
        <p>Preview: {menksoftInput}</p>
    </div>
    
    <div class="actions">
        <button class="secondary" on:click={handleClose}>Cancel</button>
        <button class="primary" on:click={handleSave}>Save Locally</button>
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