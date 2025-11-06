You are an expert software developer. Your task is to complete Step 8 of the project plan.

**Step 8: Client-Side Database (IndexedDB) Setup**

**Task:**
Your goal is to set up the client-side database using `dexie.js`. You will need to install the dependency and then create a configuration file that defines the database schema. This schema should mirror the structure defined in the technical specification and include a separate table for local user contributions.

**Instructions:**

1.  **Install the Dependency:** In the `frontend` directory, add `dexie.js` as a project dependency. The current version is `^3.2.2` or higher.

2.  **Create the Database Module:** Inside the `frontend/src/lib/` directory, create a new file named `db.ts`.

3.  **Define the Schema:** In the `db.ts` file, write the code to perform the following actions:
    *   Import `Dexie`.
    *   Create a new class that extends `Dexie`.
    *   Inside the class constructor, define the database name as `'mongol-converter-db'`.
    *   Define the database schema for version 1.
    *   The schema must include the following five object stores (tables) with the specified indexes. The `++` indicates an auto-incrementing primary key, and `&` indicates a unique index.
        *   `cyrillicWords`: `++word_id, &cyrillic_word`
        *   `traditionalConversions`: `++conversion_id, word_id, status, &[word_id+traditional]`
        *   `abbreviations`: `++abbreviation_id, &cyrillic_abbreviation`
        *   `expansions`: `++expansion_id, abbreviation_id, status, &[abbreviation_id+cyrillic_expansion]`
        *   `userContributions`: `++id, cyrillic_word` (This table is for local-only contributions before they are synced).
    *   Instantiate your new class to create a singleton `db` object.
    *   Export the `db` object so it can be used throughout the application.

Execute the plan.