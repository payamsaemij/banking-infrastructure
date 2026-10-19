# Banking Infrastructure

Infrastructure and local development environment for the Banking System microservices project.

## Prerequisites

- Docker
- Docker Compose

## Services

| Service | Purpose |
|---|---|
| PostgreSQL | Relational database for local development |

## Service databases

Each microservice owns its own database and login role inside the shared
PostgreSQL container (see `postgres/init/01-create-service-databases.sql`):
`banking_accounts` (+ `banking_accounts_test`) for the Accounts service,
`banking_identity` (+ `banking_identity_test`) for the Identity service.

The init script runs only when the data volume is **first created**. On an
existing volume, apply it manually:

```bash
docker compose exec -T postgres psql -U banking -d banking \
  < postgres/init/01-create-service-databases.sql
```

(re-runs are safe apart from harmless "already exists" errors). The
credentials in the script are local-development defaults only.

## Configuration

1. Copy `.env.example` to `.env`.
2. Set a local value for `POSTGRES_PASSWORD`.
3. Never commit `.env` or real credentials.

## Start the environment

```bash
docker compose up -d
```

## Check status

```bash
docker compose ps
docker compose exec postgres pg_isready -U banking -d banking
```

## Stop the environment

```bash
docker compose down
```

The PostgreSQL data volume is retained when the containers are stopped.

## Architecture principles

- Each microservice owns its data.
- Services must not directly modify another service's database.
- Shared infrastructure does not imply shared business logic.
- Local development credentials must not be reused in production.
