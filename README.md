# Banking Infrastructure

Infrastructure and local development environment for the Banking System
microservices project. This repository owns the **one shared PostgreSQL
instance** and the **one shared Docker network** that every banking
service connects to — application repositories (`banking-identity`,
`banking-accounts`) never start their own database or create their own
network.

## Prerequisites

- Docker
- Docker Compose

## Topology

```
                shared Docker network: banking                host loopback only
 ┌──────────────────────────────────────────────┐
 │  banking-postgres (postgres:17)              │  127.0.0.1:5432 → 5432
 │  volume: postgres_data (persistent)          │
 │    ├── banking_identity   (role banking_identity)
 │    ├── banking_accounts   (role banking_accounts)
 │    ├── banking_identity_test (role identity_test)
 │    └── banking_accounts_test (role accounts_test)
 └──────────────────────────────────────────────┘
        ▲ joins as external network ▲    ▲ joins as external network ▲
 ┌────────────────────┐              ┌────────────────────┐
 │ banking-identity   │              │ banking-accounts   │
 │ 127.0.0.1:8000     │              │ 127.0.0.1:8001     │
 └────────────────────┘              └────────────────────┘
```

- The `banking` network is created **here**, with a fixed name — never a
  compose-generated `<project>_default` name. Application compose files
  declare it `external: true` and fail with a clear error if this stack
  is not up yet (that ordering guarantee is intentional).
- Inside the Docker network, services reach PostgreSQL at
  `banking-postgres:5432`. From the host (uv, alembic, tests), use
  `localhost:5432` — the published port is bound to `127.0.0.1` only.
- PostgreSQL data lives in the named volume `postgres_data` and survives
  `docker compose down`. Only `docker compose down -v` deletes it —
  never do that just to re-run initialization (see below for the safe
  repair path).

## Service databases

Each microservice owns its own database and login role inside the shared
PostgreSQL container (see `postgres/init/01-create-service-databases.sql`):

| Service | Database | Role | Test database | Test role |
|---|---|---|---|---|
| banking-identity | `banking_identity` | `banking_identity` | `banking_identity_test` | `identity_test` |
| banking-accounts | `banking_accounts` | `banking_accounts` | `banking_accounts_test` | `accounts_test` |

Separate test databases keep test runs isolated from development data.
The bootstrap superuser (`banking` / `POSTGRES_PASSWORD`) exists only for
container initialization and administration — services connect with
their own roles and never touch each other's databases.

The credentials in the init script are **local-development defaults**
(`*_dev` / `*_test` passwords). Change them for any real deployment;
secrets never live in source control.

## Configuration

1. Copy `.env.example` to `.env`.
2. Set a local value for `POSTGRES_PASSWORD` (the bootstrap `banking`
   user; only required when the data volume is first initialized).
3. Never commit `.env` or real credentials.

## Lifecycle

```bash
docker compose up -d        # start postgres (creates the banking network)
docker compose ps           # status (wait for "healthy")
docker compose exec postgres pg_isready -U banking -d banking   # readiness
docker compose logs -f postgres
docker compose down         # stop; the postgres_data volume is retained
```

## First initialization vs an existing volume

`/docker-entrypoint-initdb.d` scripts run **only when the data volume is
created for the first time**. On an existing volume they are not executed
again — this is PostgreSQL's official image behavior, not a bug.

The init script is **idempotent**: it creates each role (in a `DO` block)
and each database (via psql `\gexec`) only when missing, and never
touches existing objects or data. That makes one command the universal
repair when databases or roles are missing (for example after the init
script gained new services on an already-initialized volume):

```bash
docker compose exec -T postgres psql -U banking -d banking \
  < postgres/init/01-create-service-databases.sql
```

It is safe to re-run any number of times — everything that already
exists is skipped. **Do not delete the volume (`down -v`) to make
initialization "work" — that destroys all local data.**

### Verifying databases and roles

```bash
docker compose exec -T postgres psql -U banking -d banking -Atc \
  "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY 1;"
# expect: banking, banking_accounts, banking_accounts_test,
#         banking_identity, banking_identity_test, postgres

docker compose exec -T postgres psql -U banking -d banking -Atc \
  "SELECT rolname FROM pg_roles WHERE rolcanlogin AND rolname IN
   ('banking','banking_identity','banking_accounts','identity_test','accounts_test')
   ORDER BY 1;"
```

## Starting the whole local environment

```bash
# 1. this repository: postgres + shared network
docker compose up -d

# 2. each application repository (identity shown; accounts is analogous
#    with service name "accounts" and port 8001):
cd ../banking-identity
cp .env.example .env                      # once; see that repo's README
docker compose run --rm identity alembic upgrade head   # explicit migration step
docker compose up -d identity

# 3. health checks
curl http://localhost:8000/health/ready   # identity (SELECT 1 against postgres)
curl http://localhost:8001/health/ready   # accounts
```

Application repositories join the `banking` network as an external
network, so this stack must be up before theirs. Stopping is symmetric
and never removes data: `docker compose down` in each app repo stops
only that service; `docker compose down` here stops postgres and keeps
the `postgres_data` volume.

## Architecture principles

- Each microservice owns its data — one database and one login role per
  service; cross-database foreign keys and cross-database transactions
  are impossible by construction.
- Services must not directly modify another service's database.
- One PostgreSQL instance, one Docker network, owned here — application
  repositories duplicate neither.
- Shared infrastructure does not imply shared business logic.
- Local development credentials must not be reused in production.
