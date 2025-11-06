You are an expert SvelteKit developer with a strong understanding of client-side data management. Your task is to complete Step 11 of the project plan by building the core client-side conversion engine and integrating it into the main UI.

**Step 11: Implement Client-Side Conversion Engine**

**Task:**
Develop the TypeScript/JavaScript logic that performs the text conversion. This involves fetching data from IndexedDB, handling ambiguities, and displaying the result in the UI. You will also create placeholder components for handling user choices when ambiguities arise.

**Instructions:**

### Part 1: Create the Conversion Engine

1.  **Create the Engine File:**
    *   Create a new file at `frontend/src/lib/conversionEngine.ts`.
    *   This file will contain all the core logic.

2.  **Define Data Structures and Initialization:**
    *   Inside `conversionEngine.ts`, import the `db` instance from `$lib/db.ts`.
    *   Create in-memory `Map` objects to hold the dictionary data for fast lookups.
    *   Create an `initialize` function that loads all data from the `abbreviations`, `expansions`, and `traditionalConversions` tables in IndexedDB and populates the `Map`s.

    ```typescript
    // frontend/src/lib/conversionEngine.ts
    import { db } from '$lib/db';

    // In-memory dictionaries for performance
    const abbreviationsMap = new Map<string, { expansion: string }[]>();
    const conversionsMap = new Map<string, { traditional: string }[]>();

    // Call this on application startup
    export async function initializeEngine() {
        console.log("Initializing conversion engine...");
        const allAbbrs = await db.abbreviations.toArray();
        const allExps = await db.expansions.toArray();
        // TODO: Load traditionalConversions and cyrillicWords as well

        // Example loading logic (needs to be completed)
        // You will need to join these tables to build the maps correctly.
        // For now, you can populate with dummy data to test the logic.
        
        // Dummy data for testing:
        abbreviationsMap.set('АН', [
            { expansion: 'Ардчилсан Нам' },
            { expansion: 'Америкийн Нэгдсэн Улс' },
        ]);
        conversionsMap.set('Монгол', [{ traditional: 'ᠮᠣᠩᠭᠣᠯ' }]);
        conversionsMap.set('хүн', [{ traditional: 'ᠬᠦᠮᠦᠨ' }]);

        console.log("Engine initialized.");
    }
    ```

3.  **Define the Core `convert` Function:**
    *   This function will be the main entry point for converting text. It needs to handle words, punctuation, and whitespace correctly.
    *   It must return a structured array that represents the conversion result, including unconverted words and ambiguities.

    ```typescript
    // Add these interfaces to conversionEngine.ts
    export type ConversionResultSegment =
      | { type: 'converted'; original: string; converted: string }
      | { type: 'unconverted'; original: string }
      | { type: 'ambiguous_abbreviation'; original: string; options: string[] }
      | { type: 'whitespace'; value: string };

    export function convert(text: string): ConversionResultSegment[] {
        const segments: ConversionResultSegment[] = [];
        // Regex to split text by words, abbreviations, and keep whitespace/punctuation
        const parts = text.split(/(\s+)/); 

        for (const part of parts) {
            if (part.match(/^\s+$/)) { // It's whitespace
                segments.push({ type: 'whitespace', value: part });
                continue;
            }
            if (part === '') continue;

            // Check if it's an abbreviation with multiple options
            if (abbreviationsMap.has(part) && abbreviationsMap.get(part)!.length > 1) {
                segments.push({
                    type: 'ambiguous_abbreviation',
                    original: part,
                    options: abbreviationsMap.get(part)!.map(o => o.expansion),
                });
            } else if (conversionsMap.has(part)) {
                // For now, assume the first conversion is correct
                const conversion = conversionsMap.get(part)![0];
                segments.push({
                    type: 'converted',
                    original: part,
                    converted: conversion.traditional,
                });
            } else {
                segments.push({ type: 'unconverted', original: part });
            }
        }
        return segments;
    }
    ```

### Part 2: Integrate with the Svelte UI

1.  **Modify the Main Page (`+page.svelte`):**
    *   Open `frontend/src/routes/+page.svelte`.
    *   Import the `initializeEngine`, `convert`, and `ConversionResultSegment` types.
    *   Use the `onMount` lifecycle hook to call `initializeEngine()`.
    *   Create state variables to hold the user's input text and the structured conversion result.
    *   Wire the "Convert" button's `on:click` event to call the `convert` function and update the result state.

    ```svelte
    <!-- frontend/src/routes/+page.svelte -->
    <script lang="ts">
        import { onMount } from 'svelte';
        import { initializeEngine, convert, type ConversionResultSegment } from '$lib/conversionEngine';
        // Placeholder for the popover component you will create next
        // import AmbiguityResolver from '$lib/components/AmbiguityResolver.svelte';

        let inputText = 'АНУ-ын иргэн Монгол хүн.';
        let conversionResult: ConversionResultSegment[] = [];
        
        // This will hold the context for the popover later
        let ambiguityContext: ConversionResultSegment | null = null;

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
    </script>
    
    <!-- (Your existing textarea and button layout) -->
    <textarea bind:value={inputText}></textarea>
    <button on:click={handleConvert}>Convert</button>

    <!-- Output Panel -->
    <div class="output-panel">
        {#each conversionResult as segment}
            {#if segment.type === 'converted'}
                <span>{segment.converted}</span>
            {:else if segment.type === 'unconverted'}
                <span class="unconverted">{segment.original}</span>
            {:else if segment.type === 'whitespace'}
                <span>{segment.value}</span>
            {/if}
        {/each}
    </div>

    <!-- This will be the popover for ambiguity, hidden by default -->
    {#if ambiguityContext}
        <!-- For now, just show the data to prove it works -->
        <div class="popover-placeholder">
            <h3>Choose an option for "{ambiguityContext.original}"</h3>
            {#if ambiguityContext.type === 'ambiguous_abbreviation'}
                {#each ambiguityContext.options as option}
                    <button>{option}</button>
                {/each}
            {/if}
        </div>
    {/if}

    <style>
        .unconverted {
            text-decoration: underline;
            text-decoration-style: dotted;
            text-decoration-color: red;
            text-underline-offset: 3px;
        }
        .popover-placeholder {
            border: 1px solid #ccc;
            padding: 1rem;
            margin-top: 1rem;
        }
    </style>
    ```

2.  **Manually Add Test Data to IndexedDB:**
    *   Since the API for fetching the dictionary isn't built yet, you must manually add data to test the full flow.
    *   Open your app in the browser and go to Developer Tools -> Application -> IndexedDB.
    *   Add a few records to the `abbreviations` and `expansions` tables to match the dummy data. This will ensure your `initializeEngine` function can load real data from IndexedDB.

Execute the plan. The primary goal is to make the "Convert" button take the input text, process it through the engine, and render a result that correctly identifies converted, unconverted, and (initially) ambiguous words.