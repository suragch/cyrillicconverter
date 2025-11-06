You are an expert SvelteKit developer. Your task is to complete Step 12 of the project plan by creating the "Add Word" contribution modal and connecting it to the client-side database.

**Step 12: Implement "Add Word" Contribution Modal**

**Task:**
Create a reusable Svelte modal component that appears when a user clicks on an unconverted (red-underlined) word. The modal will allow the user to input the Traditional Mongolian equivalent and save it directly to the local `userContributions` store in IndexedDB for immediate use.

**Instructions:**

### Part 1: Create the Contribution Modal Component

1.  **Create the Component File:**
    *   Create a new file at `frontend/src/lib/components/ContributionModal.svelte`.

2.  **Define Props and Events:**
    *   The component needs to receive the unconverted word and its context as props.
    *   It needs to emit `save` and `close` events to communicate with the parent page.

3.  **Build the Modal UI:**
    *   Use HTML and Tailwind CSS to build the modal structure according to the UX guide (overlay, centered box).
    *   Include a display for the context, a large input field for the Menksoft translation, and action buttons. For this step, we will only implement the "Save Locally" functionality.

    ```svelte
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
    ```

### Part 2: Integrate the Modal into the Main Page

1.  **Modify `+page.svelte`:**
    *   Open `frontend/src/routes/+page.svelte`.
    *   Import the new `ContributionModal` component and the `db` instance.
    *   Create a state variable to manage the modal's visibility and context.

2.  **Make Unconverted Words Clickable:**
    *   In the `#each` loop that renders the `conversionResult`, change the `<span>` for unconverted words into a `<button>` that triggers the modal.

3.  **Implement the Save and Close Logic:**
    *   Create handlers for the modal's `save` and `close` events. The `save` handler will write the new data to IndexedDB and then trigger a re-conversion to update the UI instantly.

    ```svelte
    <!-- In <script> section of frontend/src/routes/+page.svelte -->
    <script lang="ts">
        // ... (existing imports)
        import ContributionModal from '$lib/components/ContributionModal.svelte';
        import { db } from '$lib/db.ts';

        // ... (existing state variables)
        let modalContext: { word: string; context: string } | null = null;

        function openModal(word: string) {
            modalContext = { word, context: inputText };
        }

        async function handleSaveContribution(event: CustomEvent<{ menksoft: string }>) {
            if (!modalContext) return;
            
            const { menksoft } = event.detail;
            const cyrillicWord = modalContext.word;

            try {
                // 1. Save to the local userContributions store
                await db.userContributions.add({
                    cyrillic_word: cyrillicWord,
                    // In a real schema, this would be a menksoft field
                    // For now, let's assume the table has this structure
                    traditional: menksoft, 
                });

                // 2. TODO: Update the in-memory engine map for instant feedback
                // (This will be improved by updating conversionEngine.ts later)

                // 3. Close the modal
                modalContext = null;

                // 4. Re-run the conversion to show the new word
                handleConvert();

            } catch (error) {
                console.error("Failed to save contribution:", error);
                // Optionally show an error toast to the user
            }
        }
    </script>

    <!-- ... (existing layout) ... -->

    <!-- Replace the existing output panel with this -->
    <div class="output-panel">
        {#each conversionResult as segment}
            {#if segment.type === 'converted'}
                <!-- ... -->
            {:else if segment.type === 'unconverted'}
                <button class="unconverted-word" on:click={() => openModal(segment.original)}>
                    {segment.original}
                </button>
            {:else if segment.type === 'whitespace'}
                <!-- ... -->
            {/if}
        {/each}
    </div>

    <!-- Add the modal component, controlled by the state variable -->
    {#if modalContext}
        <ContributionModal 
            cyrillicWord={modalContext.word}
            context={modalContext.context}
            on:close={() => modalContext = null}
            on:save={handleSaveContribution}
        />
    {/if}

    <style>
        /* ... (existing styles) ... */
        .unconverted-word {
            background: none;
            border: none;
            padding: 0;
            font: inherit;
            cursor: pointer;
            text-decoration: underline;
            text-decoration-style: dotted;
            text-decoration-color: #DC3545; /* Red from style guide */
            color: #DC3545;
            text-underline-offset: 3px;
        }
    </style>
    ```

Execute the plan. The goal is to be able to click on any red-underlined word, have a modal pop up, submit a new translation, and see that word instantly get converted in the main output text area upon saving.