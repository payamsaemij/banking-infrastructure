-- One database and one login role per service (architecture decision,
-- 2026-10-19): the data-ownership boundary becomes physical — cross-database
-- foreign keys and cross-database transactions are impossible by construction.
--
-- These credentials are LOCAL DEVELOPMENT defaults. Change them for any
-- real deployment; secrets never live in source control.
--
-- The script is IDEMPOTENT: every role is created only if missing (DO
-- block) and every database only if missing (psql \gexec), so it is safe
-- to re-run against an existing volume — it creates exactly what is
-- missing and never touches existing objects or data.
--
-- IMPORTANT: this directory is mounted at /docker-entrypoint-initdb.d and
-- runs automatically only when the data volume is FIRST created. On an
-- existing volume, apply the same file manually (see README.md,
-- "Repairing an existing volume"):
--   docker compose exec -T postgres psql -U banking -d banking \
--     < postgres/init/01-create-service-databases.sql
--
-- Do NOT delete the volume to make the automatic init run — that would
-- destroy all local data.

-- Accounts Service -----------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'banking_accounts') THEN
    CREATE ROLE banking_accounts LOGIN PASSWORD 'banking_accounts_dev';
  END IF;
END
$$;

SELECT 'CREATE DATABASE banking_accounts OWNER banking_accounts'
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_database WHERE datname = 'banking_accounts')\gexec

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'accounts_test') THEN
    CREATE ROLE accounts_test LOGIN PASSWORD 'accounts_test';
  END IF;
END
$$;

SELECT 'CREATE DATABASE banking_accounts_test OWNER accounts_test'
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_database WHERE datname = 'banking_accounts_test')\gexec

-- Identity Service ------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'banking_identity') THEN
    CREATE ROLE banking_identity LOGIN PASSWORD 'banking_identity_dev';
  END IF;
END
$$;

SELECT 'CREATE DATABASE banking_identity OWNER banking_identity'
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_database WHERE datname = 'banking_identity')\gexec

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'identity_test') THEN
    CREATE ROLE identity_test LOGIN PASSWORD 'identity_test';
  END IF;
END
$$;

SELECT 'CREATE DATABASE banking_identity_test OWNER identity_test'
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_database WHERE datname = 'banking_identity_test')\gexec
