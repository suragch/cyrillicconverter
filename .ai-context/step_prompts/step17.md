**Role:** DevOps & Frontend Engineer
**Context:** You are working on a SvelteKit project located in a `frontend/` subdirectory within a monorepo.
**Objective:** Configure the SvelteKit application for static site generation (SSG) and set up a GitHub Actions workflow to automatically deploy it to GitHub Pages on every push to the `main` branch.

**Please execute the following 4 steps:**

### Step 1: Switch to Static Adapter
The default `adapter-auto` requires a Node.js server, but GitHub Pages hosts static files.
*   In `frontend/package.json`:
    *   Remove `@sveltejs/adapter-auto`.
    *   Add `@sveltejs/adapter-static` to `devDependencies`.
*   Run `npm install` inside the `frontend` directory to update the lockfile.

### Step 2: Update Svelte Configuration
Modify `frontend/svelte.config.js` to use the static adapter.
*   Change the import from `adapter-auto` to `adapter-static`.
*   Update the `kit.adapter` configuration:
    ```javascript
    adapter: adapter({
        pages: 'build',
        assets: 'build',
        fallback: '404.html', // Required for SPA routing on GitHub Pages
        precompress: false,
        strict: true
    })
    ```

### Step 3: Enable Prerendering
Since this is a Static Site, we need to tell SvelteKit to prerender the routes.
*   Create (or update) the file `frontend/src/routes/+layout.ts`.
*   Add the following line to enable prerendering for the entire app:
    ```typescript
    export const prerender = true;
    ```

### Step 4: Create Deployment Workflow
Create a new file at `.github/workflows/frontend-deploy.yml` in the root of the project (outside the `frontend` folder).
*   **Trigger:** On `push` to `main` branch.
*   **Permissions:** Write permissions for `contents`.
*   **Job Steps:**
    1.  Checkout the code (`actions/checkout@v4`).
    2.  Setup Node.js (`actions/setup-node@v4` with node-version 20).
    3.  Install dependencies (run `npm ci` inside the `frontend` directory).
    4.  Build the project (run `npm run build` inside the `frontend` directory).
    5.  Deploy to GitHub Pages using `peaceiris/actions-gh-pages@v3`.
        *   `github_token`: `${{ secrets.GITHUB_TOKEN }}`
        *   `publish_dir`: `./frontend/build`

**Note:** Ensure all file paths in the workflow correctly reference the `frontend/` subdirectory, as the `package.json` is not in the repo root.