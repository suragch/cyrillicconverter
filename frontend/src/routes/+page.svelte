<script lang="ts">
    // Reactive variables to hold the text input and output
    let cyrillicInput: string = '';
    let traditionalOutput: string = '';
    // These will be wired to actual conversion logic in later steps
    const handleConvert = () => {
        // Placeholder for conversion logic
        console.log('Converting:', cyrillicInput);
        traditionalOutput = `Converting "${cyrillicInput}"... (placeholder)`;
    };
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
        cyrillicInput = '';
        traditionalOutput = '';
        console.log('Cleared inputs');
    };
</script>

<!-- Main content grid: 1 column on small screens, 2 columns on medium screens and up -->
<div class="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-8 min-h-[calc(100vh-8rem)]">
    <!-- Left Panel: Cyrillic Input & Actions -->
    <div class="flex flex-col space-y-4">
        <textarea
            bind:value={cyrillicInput}
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
                on:click={() => handleCopy(traditionalOutput)}
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
        <textarea
            bind:value={traditionalOutput}
            readonly
            placeholder="Converted Traditional Mongolian text will appear here."
            class="flex-grow p-4 border border-light-gray rounded-lg focus:outline-none focus:border-royal-blue resize-none text-lg leading-relaxed text-near-black bg-off-white"
            rows={10}
        ></textarea>
        <!-- As per the UX/UI guide, primary actions are linked to the input.
             The output panel is primarily for display.
             Copy/Clear functionality is provided with the input actions for simplicity. -->
    </div>
</div>