Step 5: Scaffold SvelteKit Frontend Application.

**Goal:** Initialize a new SvelteKit project, setting up the basic project structure with TypeScript, Tailwind CSS, and Prettier.

**Context:**
*   This is a new, independent part of the project.
*   The `frontend` directory should be created for this.

**Instructions for Gemini CLI Agent:**

1.  **Create Frontend Directory:**
    *   Create a new directory named `frontend` at the root of your project: `mkdir frontend`
    *   Change into this new directory: `cd frontend`

2.  **Scaffold SvelteKit Project:**
    *   Run the SvelteKit project creation command: `npm create svelte@latest .`
    *   Follow the interactive prompts from the SvelteKit CLI. Here are the recommended selections:
        *   **Which Svelte project template?** `Skeleton project`
        *   **Add type checking with TypeScript?** `Yes, using TypeScript syntax`
        *   **Add ESLint for code linting?** `Yes, using ESLint`
        *   **Add Prettier for code formatting?** `Yes, using Prettier`
        *   **Add Playwright for browser testing?** `No` (or `Yes` if testing is desired, but for this step, `No` is simpler)
        *   **Add Vitest for unit testing?** `No` (or `Yes` if testing is desired, but for this step, `No` is simpler)

3.  **Install Node.js Dependencies:**
    *   After the scaffolding is complete, install the necessary npm packages: `npm install`

4.  **Install and Configure Tailwind CSS:**
    *   Install Tailwind CSS, PostCSS, and Autoprefixer: `npm install -D tailwindcss postcss autoprefixer`
    *   Initialize Tailwind CSS configuration files: `npx tailwindcss init -p`
        *   This will create `tailwind.config.js` and `postcss.config.js`.

5.  **Configure Tailwind CSS in `tailwind.config.js`:**
    *   Edit `frontend/tailwind.config.js` to configure the `content` property. This tells Tailwind where to find your Svelte files so it can tree-shake unused styles.
        ```javascript
        /** @type {import('tailwindcss').Config} */
        export default {
          content: ['./src/**/*.{html,js,svelte,ts}'], // Important line
          theme: {
            extend: {},
          },
          plugins: [],
        }
        ```

6.  **Add Tailwind Directives to Global CSS:**
    *   Edit `frontend/src/app.css` and add the following Tailwind directives at the very top of the file. This imports Tailwind's base, components, and utilities styles.
        ```css
        @tailwind base;
        @tailwind components;
        @tailwind utilities;

        /* Your existing global styles can go below */
        ```

7.  **Verify Implementation (User Instructions):**
    *   Start the SvelteKit development server: `npm run dev`
    *   Open your web browser and navigate to `http://localhost:5173` (or the port indicated in your terminal).
    *   You should see the default SvelteKit welcome page. To verify Tailwind CSS is working, you can temporarily add a Tailwind class to `frontend/src/routes/+page.svelte`. For example, change:
        ```html
        <h1 class="text-3xl font-bold underline">Welcome to SvelteKit</h1>
        ```
        to:
        ```html
        <h1 class="text-blue-500 text-center text-4xl font-extrabold p-8">Welcome to SvelteKit</h1>
        ```
        *   If the text color, alignment, size, font weight, and padding change, Tailwind CSS is correctly configured. Remove this test class afterward.
