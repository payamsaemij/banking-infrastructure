-- One database and one login role per service (architecture decision,
-- 2026-10-19): the data-ownership boundary becomes physical — cross-database
-- foreign keys and cross-database transactions are impossible by construction.
--
-- These credentials are LOCAL DEVELOPMENT defaults. Change them for any
-- real deployment; secrets never live in source control.
--
-- IMPORTANT: this directory is mounted at /docker-entrypoint-initdb.d and
-- runs only when the data volume is FIRST created. For an existing volume
-- apply the same statements manually:
--   docker compose exec -T postgres psql -U banking -d banking < postgres/init/01-create-service-databases.sql
-- (tolerate "already exists" errors on re-runs).

-- Accounts Service -----------------------------------------------------------
CREATE ROLE banking_accounts LOGIN PASSWORD 'banking_accounts_dev';
CREATE DATABASE banking_accounts OWNER banking_accounts;

CREATE ROLE accounts_test LOGIN PASSWORD 'accounts_test';
CREATE DATABASE banking_accounts_test OWNER accounts_test;

-- Identity Service -------------------------------------------------------------
-- The Identity service currently points at the shared 'banking' database;
-- these are ready for it to migrate onto its own database.

CREATE ROLE banking_identity LOGIN PASSWORD 'banking_identity_dev';
CREATE DATABASE banking_identity OWNER banking_identity;

CREATE ROLE identity_test LOGIN PASSWORD 'identity_test';
CREATE DATABASE banking_identity_test OWNER identity_test;
