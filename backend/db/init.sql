-- =============================================================================
-- init.sql (Complete & Self-Contained)
--
-- PostgreSQL initialization script for the Cyrillic-Traditional Mongolian
-- Converter application.
--
-- INSTRUCTIONS:
-- 1. This script should be run by a superuser (e.g., 'postgres').
-- 2. Ensure the database 'cyrillic_converter_db' exists before running.
--
-- =============================================================================

-- Stop on errors
\set ON_ERROR_STOP on

-- Set timezone to UTC for consistency
SET timezone = 'UTC';

-- =============================================================================
-- Create User using psql meta-commands
-- =============================================================================

-- Check if the 'converter_user' role exists.
-- The query returns 't' (true) or 'f' (false).
-- '\gset' stores the result into a psql variable named 'user_exists'.
SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'converter_user') AS user_exists \gset

-- '\if' is a psql command. It checks the value of the 'user_exists' variable.
-- Note the single quotes around the variable name.
\if :user_exists
    -- If the user exists, do nothing. We can optionally print a message.
    \echo 'Role "converter_user" already exists, skipping creation.'
\else
    -- If the variable is false, then we create the role.
    -- This CREATE ROLE command is now in a plain SQL context where psql
    -- can safely substitute the password variable.
    CREATE ROLE converter_user WITH LOGIN PASSWORD :'db_user_password';
    \echo 'Role "converter_user" created.'
\endif


-- Create a function to automatically update the 'updated_at' timestamp on row modification.
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';


-- =============================================================================
-- Table: CyrillicWords
-- Description: Stores the unique Cyrillic words.
-- =============================================================================
CREATE TABLE IF NOT EXISTS CyrillicWords (
    word_id BIGSERIAL PRIMARY KEY,
    cyrillic_word TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cyrillic_word ON CyrillicWords (cyrillic_word);


-- =============================================================================
-- Table: TraditionalConversions
-- Description: Stores possible traditional Mongolian conversions for Cyrillic words.
-- =============================================================================
CREATE TABLE IF NOT EXISTS TraditionalConversions (
    conversion_id BIGSERIAL PRIMARY KEY,
    word_id BIGINT NOT NULL REFERENCES CyrillicWords(word_id) ON DELETE CASCADE,
    traditional TEXT NOT NULL,
    context TEXT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'pending',
    approval_count INTEGER NOT NULL DEFAULT 0,
    contributor_id VARCHAR(30) NULL,
    contributor_ip_hash VARCHAR(64) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(word_id, traditional)
);

CREATE INDEX IF NOT EXISTS idx_conversions_status ON TraditionalConversions (status);

-- Drop trigger if it exists before creating it, to make the script re-runnable
DROP TRIGGER IF EXISTS update_traditionalconversions_updated_at ON TraditionalConversions;
CREATE TRIGGER update_traditionalconversions_updated_at
BEFORE UPDATE ON TraditionalConversions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- =============================================================================
-- Table: Abbreviations
-- Description: Stores unique Cyrillic abbreviations.
-- =============================================================================
CREATE TABLE IF NOT EXISTS Abbreviations (
    abbreviation_id BIGSERIAL PRIMARY KEY,
    cyrillic_abbreviation TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =============================================================================
-- Table: Expansions
-- Description: Stores possible Cyrillic expansions for abbreviations.
-- =============================================================================
CREATE TABLE IF NOT EXISTS Expansions (
    expansion_id BIGSERIAL PRIMARY KEY,
    abbreviation_id BIGINT NOT NULL REFERENCES Abbreviations(abbreviation_id) ON DELETE CASCADE,
    cyrillic_expansion TEXT NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'pending',
    approval_count INTEGER NOT NULL DEFAULT 0,
    contributor_id VARCHAR(30) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(abbreviation_id, cyrillic_expansion)
);

CREATE INDEX IF NOT EXISTS idx_expansions_status ON Expansions (status);

-- Drop trigger if it exists before creating it
DROP TRIGGER IF EXISTS update_expansions_updated_at ON Expansions;
CREATE TRIGGER update_expansions_updated_at
BEFORE UPDATE ON Expansions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- =============================================================================
-- Table: ModeratorActions
-- Description: Logs every moderation action for auditing.
-- =============================================================================
CREATE TABLE IF NOT EXISTS ModeratorActions (
    action_id BIGSERIAL PRIMARY KEY,
    conversion_id BIGINT NULL REFERENCES TraditionalConversions(conversion_id) ON DELETE SET NULL,
    expansion_id BIGINT NULL REFERENCES Expansions(expansion_id) ON DELETE SET NULL,
    moderator_id VARCHAR(30) NOT NULL,
    action_type VARCHAR(10) NOT NULL,
    "timestamp" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_action_target CHECK (
        (conversion_id IS NOT NULL AND expansion_id IS NULL) OR
        (conversion_id IS NULL AND expansion_id IS NOT NULL)
    )
);


-- =============================================================================
-- Table: ModeratorApplications
-- Description: Tracks applications to become a moderator.
-- =============================================================================
CREATE TABLE IF NOT EXISTS ModeratorApplications (
    application_id SERIAL PRIMARY KEY,
    user_id VARCHAR(30) NOT NULL,
    test_score INTEGER NOT NULL,
    test_answers JSONB,
    self_description TEXT,
    status VARCHAR(10) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =============================================================================
-- Grant Permissions & Change Ownership
-- =============================================================================

-- Grant privileges for the application user on all created objects.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO converter_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO converter_user;

-- Change the ownership of all objects to the application user for good practice.
ALTER TABLE CyrillicWords OWNER TO converter_user;
ALTER TABLE TraditionalConversions OWNER TO converter_user;
ALTER TABLE Abbreviations OWNER TO converter_user;
ALTER TABLE Expansions OWNER TO converter_user;
ALTER TABLE ModeratorActions OWNER TO converter_user;
ALTER TABLE ModeratorApplications OWNER TO converter_user;
ALTER FUNCTION update_updated_at_column() OWNER TO converter_user;


-- =============================================================================
-- End of script
-- =============================================================================
\echo 'Database initialization complete.'
\echo 'Role "converter_user" created and granted permissions.'