#!/bin/bash

# ------------------------------------------------------------------------------
# author @khaledbk
# up.sh
#
# This script automates the setup and restart of Docker containers for a 
# development environment using Postgres and Redis. It performs the following:
#
# 1. Checks if Docker is installed; installs it if missing.
# 2. Verifies Docker is running; attempts to start it if not.
# 3. Loads environment variables from the .env file.
# 4. Stops any running containers and restarts them with updated settings.
# 5. Waits for Postgres and Redis to initialize and verifies their health.
#    - Postgres is checked using a simple SQL query.
#    - Redis is checked using the PING command with authentication.
# 6. Displays connection details for both services.
#
# This script is useful for quickly refreshing the local dev stack with updated
# configuration, especially when environment variables or container settings change.
# ------------------------------------------------------------------------------

# 🚨 Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "🚫 Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
else
    echo "✅ Docker is installed."
fi

# 🚨 Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running."
    read -p "👉 Do you want to try starting Docker now? (y/N): " start_docker

    if [[ "$start_docker" =~ ^[Yy]$ ]]; then
        echo "🚀 Attempting to start Docker..."

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo systemctl start docker
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            open --background -a Docker
        else
            echo "⚠️ Automatic start not supported on this OS. Please start Docker manually."
            exit 1
        fi

        sleep 5
        if ! docker info > /dev/null 2>&1; then
            echo "❌ Docker still not running. Please start it manually and try again."
            exit 1
        else
            echo "✅ Docker started successfully!"
        fi
    else
        echo "🚫 Aborting. Please start Docker and rerun the script."
        exit 1
    fi
fi

# 📦 Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

# 🔐 Create Redis CLI config file for secure auth
echo "auth $REDIS_PASSWORD" > ~/.rediscli.rc
chmod 600 ~/.rediscli.rc  # Restrict permissions


echo "🔁 Restarting containers..."

echo "🛑 Stopping containers if running..."
docker-compose down

echo "🔄 Starting containers with new environment settings..."
docker-compose up -d

echo "✅ You are inside redis-container, type 'exit' to continue ...⬇️"
docker exec -it redis_container sh
redis-cli -a "$REDIS_PASSWORD" ping



# 🕰️ Wait for Postgres
echo "🕰️ Waiting for Postgres to finish initializing..."
ready_pg=0
for i in {1..10}; do
    docker exec postgres_container psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1;" &> /dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Postgres is ready!"
        ready_pg=1
        break
    else
        echo "⏳ Waiting for Postgres... ($i/10)"
        sleep 2
    fi
done

if [ $ready_pg -eq 0 ]; then
    echo "❌ Postgres still not ready after waiting."
    exit 1
fi

# 🕰️ Wait for Redis (with password)
echo "🕰️ Waiting for Redis to finish initializing..."
ready_redis=0
for i in {1..10}; do
    docker exec redis_container redis-cli -a "$REDIS_PASSWORD" PING | grep PONG &> /dev/null
    echo "⚠️ This is a standard security warning from redis-cli."
    if [ $? -eq 0 ]; then
        echo "✅ Redis is ready!"
        ready_redis=1
        break
    else
        echo "⏳ Waiting for Redis... ($i/10)"
        sleep 2
    fi
done

if [ $ready_redis -eq 0 ]; then
    echo "❌ Redis still not ready after waiting."
    exit 1
fi

# 🧪 Final health checks
echo "🧪 Checking Postgres health..."
docker exec postgres_container psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1;" &> /dev/null
if [ $? -ne 0 ]; then
    echo "❌ Could not connect to Postgres."
    exit 1
else
    echo "✅ Postgres is up and accepting connections."
fi

echo "🧪 Checking Redis health..."
if [[ $(docker inspect --format='{{.State.Health.Status}}' redis_container) == "healthy" ]]; then
  echo "✅ Redis is healthy"
else
  echo "❌ Redis is not healthy"
fi


# 🌐 Connection Details
echo ""
echo "🌐 Postgres Connection:"
echo "Host: ${CUSTOM_HOST:-localhost}"
echo "Port: ${CUSTOM_PORT:-5432}"
echo "Database: ${POSTGRES_DB}"
echo "User: ${POSTGRES_USER}"

echo ""
echo "🌐 Redis Connection:"
echo "Host: ${REDIS_HOST:-localhost}"
echo "Port: ${REDIS_PORT:-6379}"
echo "Password: ${REDIS_PASSWORD}"
echo "Cleaning .rediscli.rc .."

rm -f ~/.rediscli.rc
echo "✅ Clean!   >  ~/.rediscli.rc"
