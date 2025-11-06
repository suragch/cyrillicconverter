
<script lang="ts">
    import { onMount } from 'svelte';
    import { initializeEngine, convert, type ConversionResultSegment } from '$lib/conversionEngine';
    import ContributionModal from '$lib/components/ContributionModal.svelte';
    import { db } from '$lib/db.ts';
    let inputText = '';
    let conversionResult: ConversionResultSegment[] = [];
    let modalContext: { word: string; context: string } | null = null;

    // This will hold the context for the popover later
    let ambiguityContext: ConversionResultSegment | null = null;

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
                traditional: menksoft
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

    onMount(async () => {
        await initializeEngine();
    });

    function handleConvert() {
        const results = convert(inputText);
        const firstAmbiguity = results.find(r => r.type.startsWith('ambiguous'));
        
        if (firstAmbiguity) {
            ambiguityContext = firstAmbiguity;
        } else {
            ambiguityContext = null;
            conversionResult = results;
        }
    }

    const handleCopy = (text: string) => {
        // Placeholder for copy logic
        navigator.clipboard.writeText(text).then(() => {
            console.log('Copied:', text);
        }).catch(err => {
            console.error('Could not copy text: ', err);
        });
    };

    const handleClear = () => {
        // Placeholder for clear logic
        inputText = '';
        conversionResult = [];
        ambiguityContext = null;
        console.log('Cleared inputs');
    };
</script>

<!-- Main content grid: 1 column on small screens, 2 columns on medium screens and up -->
<div class="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-8 min-h-[calc(100vh-8rem)]">
    <!-- Left Panel: Cyrillic Input & Actions -->
    <div class="flex flex-col space-y-4">
        <textarea
            bind:value={inputText}
            placeholder="Та кирилл монгол бичвэрээ энд буулгана уу..."
            class="flex-grow p-4 border border-light-gray rounded-lg focus:outline-none focus:border-royal-blue resize-none text-lg leading-relaxed text-near-black bg-white placeholder-medium-gray"
            rows={10}
        ></textarea>

        <div class="flex space-x-4">
            <button
                on:click={handleConvert}
                class="px-6 py-3 bg-royal-blue text-white rounded-lg font-medium text-base hover:bg-bright-blue transition-colors duration-200 shadow-md"
            >
                Convert
            </button>
            <button
                on:click={() => handleCopy(conversionResult.map(s => s.type === 'converted' ? s.converted : s.type === 'whitespace' ? s.value : s.original).join(''))}
                class="px-6 py-3 border border-light-gray text-near-black rounded-lg font-medium text-base hover:bg-off-white transition-colors duration-200 shadow-sm"
            >
                Copy
            </button>
            <button
                on:click={handleClear}
                class="px-6 py-3 border border-light-gray text-near-black rounded-lg font-medium text-base hover:bg-off-white transition-colors duration-200 shadow-sm"
            >
                Clear
            </button>
        </div>
    </div>

    <!-- Right Panel: Traditional Mongolian Output -->
    <div class="flex flex-col space-y-4">
        <div
            class="output-panel flex-grow p-4 border border-light-gray rounded-lg focus:outline-none focus:border-royal-blue resize-none text-lg leading-relaxed text-near-black bg-off-white"
        >
            {#each conversionResult as segment}
                {#if segment.type === 'converted'}
                    <span>{segment.converted}</span>
                {:else if segment.type === 'unconverted'}
                    <button class="unconverted-word" on:click={() => openModal(segment.original)}>
                        {segment.original}
                    </button>
                {:else if segment.type === 'whitespace'}
                    <span>{segment.value}</span>
                {/if}
            {/each}
        </div>
    </div>
</div>

<!-- Add the modal component, controlled by the state variable -->
{#if modalContext}
    <ContributionModal
        cyrillicWord={modalContext.word}
        context={modalContext.context}
        on:close={() => (modalContext = null)}
        on:save={handleSaveContribution}
    />
{/if}

<!-- This will be the popover for ambiguity, hidden by default -->
{#if ambiguityContext}
    <div class="popover-placeholder fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
        <div class="bg-white p-8 rounded-lg shadow-xl">
            <h3 class="text-xl font-semibold mb-4">Choose an option for "{ambiguityContext.original}"</h3>
            {#if ambiguityContext.type === 'ambiguous_abbreviation'}
                <div class="flex flex-col space-y-2">
                    {#each ambiguityContext.options as option}
                        <button class="px-4 py-2 border rounded-lg hover:bg-gray-100">{option}</button>
                    {/each}
                </div>
            {/if}
        </div>
    </div>
{/if}

<style>
    .unconverted-word {
        background: none;
        border: none;
        padding: 0;
        font: inherit;
        cursor: pointer;
        text-decoration: underline;
        text-decoration-style: dotted;
        text-decoration-color: #dc3545; /* Red from style guide */
        color: #dc3545;
        text-underline-offset: 3px;
    }
</style>