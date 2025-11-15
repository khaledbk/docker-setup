# Tunisie Vacance Dev Environment

This project provides a fully automated local development environment for the Tunisie Vacance platform, using Docker to orchestrate Postgres (with PostGIS) and Redis, along with a setup script to streamline initialization and health checks.

---

## Features

- One-command setup via `up.sh`
- Postgres with PostGIS extension
- Redis with password authentication
- Secure environment variable loading
- Health checks for both services
- Auto-initialization via `init.sql`
- Cleanup of Redis CLI credentials

---

## Project Structure

```bash
.
├── .env                 # Environment variables
├── docker-compose.yml   # Docker service definitions
├── Dockerfile           # Base images (Postgres, Redis)
├── init.sql             # Postgres initialization script
└── up.sh                # Setup and restart script

```

---

## Requirements

- Docker installed and running
- Bash shell (`.sh` compatible)
- Internet connection (for Docker installation if missing)

---

## Environment Variables (.env)

# Postgres

```bash
POSTGRES_USER=admin
POSTGRES_PASSWORD=password
POSTGRES_DB=mydatabase
CUSTOM_HOST=10.0.0.19
CUSTOM_PORT=5436
```

# Redis

```bash
REDIS_HOST=10.0.0.19
REDIS_PORT=6380
REDIS_PASSWORD=cahepassword
```

---

## Database Initialization (init.sql)

-- Create database if it doesn't exist

```bash
DO

$$
BEGIN
   IF NOT EXISTS (
      SELECT
      FROM   pg_catalog.pg_database
      WHERE  datname = 'mydatabase'
      ) THEN
      CREATE DATABASE mydatabase;
   END IF;
END
$$;
```

-- Create user with specified password

```bash
DO
$$

BEGIN
IF NOT EXISTS (
SELECT
FROM pg_catalog.pg_roles
WHERE rolname = 'admin'
) THEN
CREATE USER admin WITH PASSWORD 'password';
END IF;
END

$$
;
```
-- Connect to the database and set up PostGIS

```bash
\c mydatabase admin
CREATE EXTENSION IF NOT EXISTS postgis;
```
-- Reindex database and refresh collation version to handle collation mismatch

```bash
REINDEX DATABASE mydatabase;
ALTER DATABASE mydatabase REFRESH COLLATION VERSION;
```
-- Grant necessary permissions to the user

```bash
ALTER ROLE admin CREATEDB;
```
-- Grant privileges on the database to the user

```bash
GRANT ALL PRIVILEGES ON DATABASE mydatabase TO admin;
```
-------------------------------------------------------------------------------

## Docker Compose (docker-compose.yml)
```bash
version: '3.8'

services:
  postgres:
    image: postgis/postgis:latest
    platform: linux/amd64
    container_name: postgres_container
    env_file:
      - .env
    ports:
      - "${CUSTOM_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"]
      interval: 5s
      timeout: 3s
      retries: 5

  redis:
    image: redis:latest
    platform: linux/amd64
    container_name: redis_container
    env_file:
      - .env
    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD}"]
    ports:
      - "${REDIS_PORT}:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test:
        [
          "CMD-SHELL",
          'redis-cli -a "$REDIS_PASSWORD" ping | grep PONG || exit 1',
        ]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  postgres_data:
  redis_data:
```
-------------------------------------------------------------------------------

## Setup Script (up.sh)

Run the following command to initialize and start your development environment:

bash up.sh

This script will:

1. Install Docker if missing
2. Start Docker if not running
3. Load environment variables from `.env`
4. Restart containers with updated settings
5. Wait for Postgres and Redis to become healthy
6. Display connection details

-------------------------------------------------------------------------------

## Connection Info

Postgres
- Host: ${CUSTOM_HOST}
- Port: ${CUSTOM_PORT}
- Database: ${POSTGRES_DB}
- User: ${POSTGRES_USER}

Redis
- Host: ${REDIS_HOST}
- Port: ${REDIS_PORT}
- Password: ${REDIS_PASSWORD}

-------------------------------------------------------------------------------

## Cleanup

The script automatically removes the temporary Redis CLI auth file (`~/.rediscli.rc`) after setup.

-------------------------------------------------------------------------------

## Author

Created by @khaledbk
Feel free to contribute or fork for your own dev stack!
$$
