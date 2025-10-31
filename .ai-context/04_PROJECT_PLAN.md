## 1. Project Setup: Backend Infrastructure
- [x] Step 1: Initialize Backend Services with Docker Compose
  - **Task**: Create a `docker-compose.yml` file to define and configure the three core backend services: the Dart API (`api`), PostgreSQL (`db`), and PocketBase (`auth`). This setup ensures all backend components can be started with a single command.
  - **Files**:
    - `backend/docker-compose.yml`: Define services for `api`, `db`, and `auth`. Configure ports, volumes for data persistence, and environment variables for PostgreSQL and PocketBase credentials.
    - `backend/api/Dockerfile`: Create a Dockerfile for the Dart Shelf application. This will be a multi-stage build, starting from the Dart SDK to build the application, then copying the compiled output to a lean runtime image.
    - `backend/.env`: Store sensitive information like database passwords and JWT secrets, which will be loaded by Docker Compose.
  - **Step Dependencies**: None
  - **User Instructions**: Run `docker-compose up -d` from the `backend` directory to build and start all services. Verify that the containers are running using `docker ps`.

- [x] Step 2: Initialize PostgreSQL Database Schema
  - **Task**: Create an initial SQL script that defines the schema for all required tables (`CyrillicWords`, `TraditionalConversions`, `Abbreviations`, `Expansions`, `ModeratorActions`, `ModeratorApplications`). This script will be automatically executed by PostgreSQL upon its first initialization, setting up the normalized database structure.
  - **Files**:
    - `backend/db/init.sql`: Write `CREATE TABLE` statements for the six main tables. This includes defining primary keys, foreign keys with `ON DELETE CASCADE`, indexes, and unique constraints as specified in the "Data Models" section of the technical specification.
    - `backend/docker-compose.yml`: Modify the `db` service definition to mount the `init.sql` script to `/docker-entrypoint-initdb.d/init.sql`. This is the standard mechanism for initializing a PostgreSQL container.
  - **Step Dependencies**: Step 1
  - **User Instructions**: If Step 1 was already run, you will need to stop the containers (`docker-compose down`), remove the PostgreSQL volume to allow re-initialization (`docker volume rm backend_db-data`), and then run `docker-compose up -d` again.

- [x] Step 3: Scaffold Dart Shelf API and Health Check Endpoint
  - **Task**: Create a basic Dart Shelf application. This includes setting up the project structure, adding dependencies, and creating a simple health-check endpoint (e.g., `GET /ping`) to verify that the API server is running correctly inside its Docker container.
  - **Files**:
    - `backend/api/pubspec.yaml`: Define project metadata and add dependencies like `shelf` and `shelf_router`.
    - `backend/api/bin/server.dart`: The main entry point for the application. It will initialize a Shelf server and listen on the configured port.
    - `backend/api/lib/api_router.dart`: Create a simple router with a `/ping` route that returns a `200 OK` response with a body of "pong".
  - **Step Dependencies**: Step 1
  - **User Instructions**: After running `docker-compose up -d --build`, navigate to `http://localhost:8080/ping` in your browser or use `curl`. You should see the "pong" response, confirming the API server is active.

- [ ] Step 4: Configure Nginx as a Reverse Proxy
  - **Task**: Add an Nginx service to the `docker-compose.yml` file to act as a reverse proxy. This will be the single public entry point for the backend, routing traffic to the appropriate service based on the URL path (`/api/*` to the Dart API, `/pb/*` to PocketBase). This standardizes access and simplifies SSL termination.
  - **Files**:
    - `backend/docker-compose.yml`: Add a new `nginx` service. It will be mapped to port 80 and 443 of the host machine and depend on the `api` and `auth` services.
    - `backend/nginx/nginx.conf`: Create the Nginx configuration file. Define `upstream` blocks for the API and PocketBase services. Create a `server` block that listens on port 80 and defines `location` blocks to proxy requests to the correct upstream based on the path.
  - **Step Dependencies**: Step 1, Step 3
  - **User Instructions**: Run `docker-compose up -d --build`. Access `http://localhost/ping`. The request should be routed through Nginx to the Dart API, and you should see the "pong" response.

## 2. Project Setup: Frontend Application
- [x] Step 5: Scaffold SvelteKit Frontend Application
  - **Task**: Initialize a new SvelteKit project using the official command-line tool. Set up the basic project structure, including TypeScript, Tailwind CSS for styling, and Prettier for code formatting, as per the technology stack recommendations.
  - **Files**:
    - `frontend/package.json`: Manages project dependencies.
    - `frontend/svelte.config.js`: SvelteKit configuration file.
    - `frontend/vite.config.ts`: Vite build tool configuration.
    - `frontend/tailwind.config.js`: Configuration file for Tailwind CSS.
    - `frontend/src/app.html`: The main HTML shell for the application.
  - **Step Dependencies**: None
  - **User Instructions**: In a new directory named `frontend`, run `npm create svelte@latest .`. Follow the prompts to select a "Skeleton project" and add TypeScript, ESLint, Prettier, and Tailwind CSS. After initialization, run `npm install` and then `npm run dev` to start the development server.

- [ ] Step 6: Implement Basic UI Layout
  - **Task**: Create the main two-column layout of the application. This involves setting up a global layout component in SvelteKit and creating the primary user interface elements: the Cyrillic input text area on the left and the Traditional Mongolian output area on the right.
  - **Files**:
    - `frontend/src/routes/+layout.svelte`: A root layout component that will apply to all pages. It will contain the main grid or flexbox container for the two-column design.
    - `frontend/src/routes/+page.svelte`: The main page component. It will contain the two `<textarea>` elements, a "Convert" button, and placeholders for "Copy" and "Clear" buttons. Use Tailwind CSS for styling.
    - `frontend/src/app.css`: Global styles, including the import statements for Tailwind CSS.
  - **Step Dependencies**: Step 5
  - **User Instructions**: With the development server running, view the application in your browser. You should see the two text areas and a "Convert" button arranged in a two-column layout on desktop and a stacked single-column layout on mobile.

- [ ] Step 7: Setup PWA and Offline Capabilities
  - **Task**: Configure the SvelteKit application to be a Progressive Web App (PWA). This involves creating a web app manifest and a service worker to enable offline functionality and application caching.
  - **Files**:
    - `frontend/static/manifest.json`: Define PWA properties like the app's name, icons, start URL, and display mode.
    - `frontend/src/app.html`: Link to the `manifest.json`.
    - `frontend/src/service-worker.ts`: Create the service worker file. Implement basic caching strategies for the application shell and static assets using SvelteKit's built-in `$service-worker` module.
  - **Step Dependencies**: Step 5
  - **User Instructions**: Build the app (`npm run build`) and preview it (`npm run preview`). In your browser's developer tools (Application tab), you should see the manifest loaded and the service worker registered and activated.

- [ ] Step 8: Client-Side Database (IndexedDB) Setup
  - **Task**: Integrate a lightweight wrapper library for IndexedDB, such as `dexie.js`, to simplify database interactions. Define the database schema with object stores that mirror the normalized backend structure: `cyrillicWords`, `traditionalConversions`, `abbreviations`, `expansions`, and a separate `userContributions` store.
  - **Files**:
    - `frontend/src/lib/db.ts`: Create a module to initialize and configure Dexie. Define the database version and the schema for all object stores. This file will export a singleton `db` instance to be used throughout the application.
    - `frontend/package.json`: Add `dexie` as a dependency.
  - **Step Dependencies**: Step 5
  - **User Instructions**: After adding the dependency (`npm install dexie`), the application should still build and run correctly. Use the browser's developer tools to verify that an IndexedDB database with the correct name and object stores has been created.

## 3. Core Feature: Authentication
- [ ] Step 9: Implement User Authentication UI
  - **Task**: Create Svelte components for user registration, login, and a user profile display. Use the PocketBase JavaScript SDK to handle the client-side authentication logic. Manage the global authentication state using Svelte stores.
  - **Files**:
    - `frontend/src/lib/pocketbase.ts`: Initialize the PocketBase JS client with the server URL.
    - `frontend/src/lib/stores/authStore.ts`: Create a Svelte store to manage the current user's authentication state and JWT.
    - `frontend/src/routes/login/+page.svelte`: The login page component with a form for email and password.
    - `frontend/src/routes/register/+page.svelte`: The registration page component.
    - `frontend/src/lib/components/Navbar.svelte`: A navigation bar component that conditionally shows "Login/Register" or "Logout" based on the auth store.
  - **Step Dependencies**: Step 4, Step 5
  - **User Instructions**: Navigate to the `/login` and `/register` pages. You should be able to create a new user account and log in. After logging in, the navbar should update to show a logout option.

- [ ] Step 10: Implement API JWT Authentication Middleware
  - **Task**: In the Dart Shelf API, create a middleware that protects specific endpoints. This middleware will extract the JWT from the `Authorization` header of incoming requests, validate it, and reject any unauthorized requests with a `401` or `403` status code.
  - **Files**:
    - `backend/api/lib/auth_middleware.dart`: The middleware function. It will parse the "Bearer" token from the header.
    - `backend/api/lib/jwt_service.dart`: A service class responsible for JWT validation. It may need to call PocketBase's API or use its public key to verify the token signature.
    - `backend/api/bin/server.dart`: Apply the new authentication middleware to a new, protected test route (e.g., `/api/protected/ping`).
  - **Step Dependencies**: Step 3, Step 9
  - **User Instructions**: After logging in on the frontend, use the browser's developer tools to copy the JWT. Use a tool like Postman or `curl` to make a request to the new `/api/protected/ping` endpoint, including the JWT in the `Authorization` header. The request should succeed. Making the same request without the token should result in an error.

## 4. Core Feature: Conversion & Contribution
- [ ] Step 11: Implement Client-Side Conversion Engine
  - **Task**: Develop the core text conversion logic in JavaScript. This engine will load dictionaries from IndexedDB into memory, perform a pre-processing pass to expand abbreviations, and then convert word-by-word. It must include logic to handle one-to-many ambiguities (both abbreviations and conversions) by interacting with the UI.
  - **Files**:
    - `frontend/src/lib/conversionEngine.ts`: The main file containing the conversion logic. It will export functions to initialize (load dictionaries) and convert text.
    - `frontend/src/routes/+page.svelte`: Import and use the `conversionEngine`. Wire the "Convert" button to trigger the conversion. Implement UI components (e.g., popovers) to handle ambiguity selection when the engine requires it.
  - **Step Dependencies**: Step 6, Step 8
  - **User Instructions**: Manually add test data to IndexedDB. Type Cyrillic text containing an abbreviation with multiple expansions; the UI should prompt you to choose one. Type a word with multiple traditional spellings; the UI should allow you to select the correct one in the output.

- [ ] Step 12: Implement "Add Word" Contribution Modal
  - **Task**: Create a modal that appears when a user clicks on a highlighted, unconverted word. The modal will display the word, its context, and provide an input for the user to submit its Traditional Mongolian (Menksoft) equivalent. New contributions should be saved immediately to the local `userContributions` store in IndexedDB.
  - **Files**:
    - `frontend/src/lib/components/ContributionModal.svelte`: A reusable modal component. It will receive the unconverted word as a prop and contain the form for submission.
    - `frontend/src/routes/+page.svelte`: Add an event handler that listens for clicks on the highlighted word spans. This handler will open the `ContributionModal` and pass the relevant word data to it. On modal close/save, it should update the local database and re-run the conversion.
  - **Step Dependencies**: Step 11
  - **User Instructions**: Click on a red-underlined word. The contribution modal should pop up. Submitting a new translation should close the modal and instantly update the word in the main output text area.

- [ ] Step 13: Implement Contribution API Endpoints
  - **Task**: Create the backend endpoints to receive new contributions: `POST /api/conversions` for word conversions and `POST /api/abbreviations` for new abbreviations and expansions. The endpoints will validate incoming data and insert it into the appropriate PostgreSQL tables with a 'pending' status.
  - **Files**:
    - `backend/api/lib/api_router.dart`: Add new route handlers for `POST /api/conversions` and `POST /api/abbreviations`.
    - `backend/api/lib/conversion_service.dart`: Create a service to handle the business logic for word contributions, including finding/creating the `CyrillicWords` entry and inserting into `TraditionalConversions`.
    - `backend/api/lib/models/conversion_model.dart`: A Dart data class representing a contribution payload.
  - **Step Dependencies**: Step 2, Step 3
  - **User Instructions**: Use a tool like Postman to send a valid JSON payload to the `http://localhost/api/conversions` endpoint. Verify that new rows are created in the `cyrillic_words` and `traditional_conversions` tables in your PostgreSQL database.

- [ ] Step 14: Implement Frontend-to-Backend Contribution Sync
  - **Task**: Connect the frontend contribution modal to the backend API. When a user chooses to "Save & Submit," the new conversion will be sent to the backend `POST /api/conversions` endpoint. Implement logic to handle offline submissions using the Service Worker's Background Sync API.
  - **Files**:
    - `frontend/src/lib/components/ContributionModal.svelte`: Modify the save logic. If the user chooses to submit, make a `fetch` request to the backend API.
    - `frontend/src/service-worker.ts`: Add a 'sync' event listener. When a submission fails due to being offline, tag it for background sync. The sync event will later attempt to resend the data when connectivity is restored.
  - **Step Dependencies**: Step 12, Step 13
  - **User Instructions**: Submit a new word while online; verify it appears in the database. Go offline using browser dev tools and submit another word. The UI should indicate it's queued. Go back online; the service worker should automatically sync the submission, and the new data should appear in the database.

## 5. Moderation and Community Features
- [ ] Step 15: Implement Moderation Endpoints
  - **Task**: Create the secure backend API endpoints required for moderators to review and act upon pending submissions. This includes endpoints for fetching pending conversions and expansions, and for approving or rejecting them (`POST /api/moderation/conversion/{id}/approve`, etc.).
  - **Files**:
    - `backend/api/lib/api_router.dart`: Add new protected routes under `/api/moderation/`.
    - `backend/api/lib/moderation_service.dart`: Implement the business logic for fetching pending submissions and handling the approval/rejection logic. Use database transactions to prevent race conditions when updating counts.
    - `backend/api/lib/auth_middleware.dart`: Ensure the moderation routes are protected by the JWT middleware and that it checks for a 'moderator' role.
  - **Step Dependencies**: Step 10, Step 13
  - **User Instructions**: Manually set a user's `is_moderator` flag to `true` in the PocketBase UI. Using that user's JWT, make API calls to the new moderation endpoints via Postman to ensure they are functional and properly secured.

- [ ] Step 16: Build Moderation Dashboard UI
  - **Task**: Develop the frontend interface for moderators. This will be a new, protected route that displays lists of pending conversions and expansions fetched from the API and provides buttons to approve or reject each one.
  - **Files**:
    - `frontend/src/routes/moderation/+page.svelte`: The main dashboard component. It will fetch pending items on load and display them.
    - `frontend/src/routes/moderation/+layout.svelte`: A layout for the moderation section that checks the user's role from the `authStore` and redirects if they are not a moderator.
    - `frontend/src/lib/stores/authStore.ts`: Add logic to parse the JWT or user object from PocketBase to determine if the user has a moderator role.
  - **Step Dependencies**: Step 9, Step 15
  - **User Instructions**: Log in as a moderator. You should be able to access the `/moderation` route and see lists of pending submissions. Non-moderators should be redirected or shown an error. Approving/rejecting a submission should remove it from the list.

## 6. Deployment and Automation
- [ ] Step 17: Configure Frontend CI/CD with GitHub Actions
  - **Task**: Create a GitHub Actions workflow to automate the deployment of the SvelteKit PWA to GitHub Pages. The workflow should trigger on a push to the `main` branch, install dependencies, build the static site, and push the build artifacts to the `gh-pages` branch.
  - **Files**:
    - `frontend/.github/workflows/deploy.yml`: The GitHub Actions workflow file. It will define the job with steps for checking out the code, setting up Node.js, building the project, and using a community action (like `peaceiris/actions-gh-pages`) to deploy.
  - **Step Dependencies**: Step 5
  - **User Instructions**: Push a commit to the `main` branch of the `frontend` repository. Go to the "Actions" tab in GitHub to monitor the workflow. Once it completes successfully, configure the repository's GitHub Pages settings to serve from the `gh-pages` branch.

- [ ] Step 18: Configure Backend CI/CD with GitHub Actions
  - **Task**: Create a GitHub Actions workflow to automate building and publishing the backend Docker images. The workflow will trigger on a push to the `main` branch, log in to Docker Hub, and then build and push the `api` and `nginx` images with an appropriate tag (e.g., the commit SHA or a version number).
  - **Files**:
    - `backend/.github/workflows/build-push.yml`: The workflow file for the backend. It will have steps to log in to a container registry (like Docker Hub), build each Docker image using `docker build`, and push them using `docker push`.
  - **Step Dependencies**: Step 1, Step 4
  - **User Instructions**: Add `DOCKER_USERNAME` and `DOCKER_PASSWORD` as secrets to your GitHub repository. Push a commit to the `main` branch of the `backend` repository. Verify in the "Actions" tab that the workflow runs and successfully pushes the images to your Docker Hub account.