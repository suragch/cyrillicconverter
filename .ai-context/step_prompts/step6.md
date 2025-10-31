**Goal:** Create the main two-column layout of the application, including the Cyrillic input text area, Traditional Mongolian output area, and action buttons, using SvelteKit's layout system and Tailwind CSS.

**Context:**
*   You have a scaffolded SvelteKit project in `frontend/`.
*   Tailwind CSS is configured.
*   The design philosophy emphasizes "Instant Clarity" and "Cognitive Breathing Room" with a clean, content-first architecture.

**Instructions for Gemini CLI Agent:**

1.  **Update `frontend/tailwind.config.js` for Custom Colors and Font Family:**
    *   Edit `frontend/tailwind.config.js` to extend the default Tailwind theme with the custom colors from the "Color Palette" and define the `Inter` font family from the "Typography" section of the UX/UI guide.

        ```javascript
        /** @type {import('tailwindcss').Config} */
        export default {
          content: ['./src/**/*.{html,js,svelte,ts}'],
          theme: {
            extend: {
              colors: {
                'near-black': '#1A1A1A',        // Text (Primary)
                'medium-gray': '#6B6B6B',       // Text (Secondary)
                'light-gray': '#E0E0E0',        // Borders/Dividers
                'off-white': '#F9F9F9',         // Surface
                'royal-blue': '#0052FF',        // Primary Action
                'bright-blue': '#0048E0',       // Primary Action (Hover)
                'success-green': '#28A745',     // Semantic Success
                'info-blue': '#007BFF',         // Semantic Information
                'warning-red': '#DC3545',       // Semantic Warning/Error
                'choice-blue': '#0052FF',       // Same as Royal Blue as per spec
              },
              fontFamily: {
                // Defines a custom font stack starting with 'Inter', falling back to generic sans-serif
                inter: ['Inter', 'sans-serif'],
              },
            },
          },
          plugins: [],
        }
        ```
    *   **Note on Font Loading:** For `Inter` to fully render, it typically needs to be imported (e.g., from Google Fonts). For the scope of this step, we assume it's either locally available or the `sans-serif` fallback will be used. A later step can address explicit font loading.

2.  **Edit `frontend/src/routes/+layout.svelte` (Global Layout):**
    *   This file will define the overall application wrapper. It sets up a flex column layout with consistent padding, a white background, and applies the primary text color and font.
    *   Replace its current content (if any) with the following:

        ```svelte
        <script lang="ts">
            import '../app.css'; // Import global Tailwind CSS
        </script>

        <div class="min-h-screen bg-white text-near-black flex flex-col items-center p-4 sm:p-8 font-inter">
            <main class="w-full max-w-7xl flex-grow">
                <slot />
            </main>
        </div>
        ```

3.  **Edit `frontend/src/routes/+page.svelte` (Main Page Content):**
    *   This file will contain the input/output text areas and the action buttons. It implements the responsive two-column grid using Tailwind CSS.
    *   Replace its current content with the following:

        ```svelte
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
        ```

4.  **Save All Changes:**
    *   Ensure `frontend/tailwind.config.js`, `frontend/src/routes/+layout.svelte`, and `frontend/src/routes/+page.svelte` are all saved.

5.  **Verify Implementation (User Instructions):**
    *   Ensure your SvelteKit development server is running (`npm run dev` in the `frontend` directory).
    *   Open your browser to `http://localhost:5173`.
    *   **Desktop View:** You should see two large text areas side-by-side. The left one should have the Cyrillic placeholder and three styled buttons ("Convert," "Copy," "Clear") below it. The right one should have the Traditional Mongolian placeholder and be read-only. The overall background should be white with the main content area centered.
    *   **Mobile View:** Shrink your browser window or use developer tools to simulate a mobile device. The two text areas should stack vertically, with the buttons remaining below the left text area.
    *   Test typing into the left text area and clicking "Convert," "Copy," and "Clear" to see the basic placeholder `console.log` messages or output changes.
