
I am working on step 2 in the project plan. However, I'm not using docker in this first time through. Instead, I'm getting everything set up locally on my mac. Later when I get everything working, I'll set up docker.
Write me a tutorial for what I need to do in step two. Actually, write a tutorial for an AI agent to accomplish these tasks at the command line.

---


### Tutorial for AI Agent: Step 2 - Initialize PostgreSQL Database Schema Locally

**Objective:** To create the necessary database, user, and tables in a local PostgreSQL instance for the Cyrillic-Traditional Mongolian Converter project.

---

#### **Phase 1: Ensure PostgreSQL is Installed and Running**

First, verify that the necessary tools are available. We will use Homebrew to install PostgreSQL.

**ACTION 1.1: Check for Homebrew and install if missing.**

```bash
# Check if Homebrew is installed. If the command fails, it's not installed.
if ! command -v brew &> /dev/null
then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed."
fi
```

**ACTION 1.2: Install PostgreSQL via Homebrew.**

```bash
# Check if PostgreSQL is installed. If not, install it.
if ! brew list postgresql &> /dev/null
then
    echo "PostgreSQL not found. Installing with Homebrew..."
    brew install postgresql
else
    echo "PostgreSQL is already installed."
fi
```

**ACTION 1.3: Start the PostgreSQL service.**

```bash
# Start the PostgreSQL service using brew services.
# This will also register it to start on login.
brew services start postgresql
echo "PostgreSQL service started."
```

#### **Phase 2: Create the Project Database and User**

For security and organization, the application will have its own database and user role.

**ACTION 2.1: Create the database and user.**

See `db/README.md` for more details.

#### **Phase 3: Define the Database Schema**

Now, create the `init.sql` file containing the table definitions as specified in the technical documentation.

**ACTION 3.1: Create the directory for the SQL script.**

```bash
# Assuming the current working directory is the project root.
mkdir -p backend/db
```

**ACTION 3.2: Write the `init.sql` file.**

See `db/init.sql` for actual SQL code.

#### **Phase 4: Execute the Schema Script**

Apply the newly created schema to the project database.

**ACTION 4.1: Run the `init.sql` script against the database.**

See `db/README.md` for more details.

#### **Phase 5: Verify Schema Creation**

The final step is to connect to the database and confirm that the tables exist.

**ACTION 5.1: List tables in the database to verify success.**

```bash
# Connect to the database and run the '\dt' command to list tables.
# The output should list the four tables you created.
psql -d converter -c "\dt"

echo "Verification complete. Expected tables: wordconversionpairs, abbreviationexpansions, moderatoractions, moderatorapplications."
```

---
**Conclusion:** The local PostgreSQL database `converter` is now fully initialized with the required schema. The project is ready for the backend application to connect and interact with these tables.