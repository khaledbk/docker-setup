#!/bin/bash

# ------------------------------------------------------------------------------
# author @khaledbk
# up.sh
#
# Automates setup and restart of Docker containers for Postgres and Redis
# without docker-compose.
# ------------------------------------------------------------------------------

# 🚨 Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "🚫 Docker not found. Please install Docker first."
    exit 1
else
    echo "✅ Docker is installed."
fi

# 🚨 Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please open Docker and rerun this script."
    exit 1
fi

# 📦 Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

# 🔁 Ensure Postgres container
if [ "$(docker ps -aq -f name=postgres_container)" ]; then
    echo "🔄 Postgres container exists."
    docker start postgres_container || {
        echo "🛑 Restarting Postgres..."
        docker rm -f postgres_container
        docker run -d \
            --name postgres_container \
            -e POSTGRES_USER=$POSTGRES_USER \
            -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
            -e POSTGRES_DB=$POSTGRES_DB \
            -p ${CUSTOM_PORT}:5432 \
            -v postgres_data:/var/lib/postgresql/data \
            -v $(pwd)/init.sql:/docker-entrypoint-initdb.d/init.sql \
            postgis/postgis:latest
    }
else
    echo "🚀 Creating Postgres container..."
    docker run -d \
        --name postgres_container \
        -e POSTGRES_USER=$POSTGRES_USER \
        -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
        -e POSTGRES_DB=$POSTGRES_DB \
        -p ${CUSTOM_PORT}:5432 \
        -v postgres_data:/var/lib/postgresql/data \
        -v $(pwd)/init.sql:/docker-entrypoint-initdb.d/init.sql \
        postgis/postgis:latest
fi

# 🔁 Ensure Redis container
if [ "$(docker ps -aq -f name=redis_container)" ]; then
    echo "🔄 Redis container exists."
    docker start redis_container || {
        echo "🛑 Restarting Redis..."
        docker rm -f redis_container
        docker run -d \
            --name redis_container \
            -e REDIS_PASSWORD=$REDIS_PASSWORD \
            -p ${REDIS_PORT}:6379 \
            -v redis_data:/data \
            postgres-dev-redis:latest \
            redis-server --requirepass $REDIS_PASSWORD
    }
else
    echo "🚀 Creating Redis container..."
    docker run -d \
        --name redis_container \
        -e REDIS_PASSWORD=$REDIS_PASSWORD \
        -p ${REDIS_PORT}:6379 \
        -v redis_data:/data \
        postgres-dev-redis:latest \
        redis-server --requirepass $REDIS_PASSWORD
fi

# 🕰️ Wait for Postgres
echo "🕰️ Waiting for Postgres..."
for i in {1..10}; do
    docker exec postgres_container psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" &> /dev/null && {
        echo "✅ Postgres is ready!"
        break
    }
    echo "⏳ Waiting for Postgres... ($i/10)"
    sleep 2
done

# 🕰️ Wait for Redis
echo "🕰️ Waiting for Redis..."
for i in {1..10}; do
    docker exec redis_container redis-cli -a "$REDIS_PASSWORD" PING | grep PONG &> /dev/null && {
        echo "✅ Redis is ready!"
        break
    }
    echo "⏳ Waiting for Redis... ($i/10)"
    sleep 2
done

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


# 🕰️ Wait for Postgres (readiness + Docker health)
echo "🕰️ Waiting for Postgres..."
for i in {1..10}; do
    docker exec postgres_container psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" &> /dev/null
    if [ $? -eq 0 ]; then
        status=$(docker inspect --format='{{.State.Health.Status}}' postgres_container)
        if [[ "$status" == "healthy" ]]; then
            echo "✅ Postgres is healthy (Docker status)"
            break
        else
            echo "⏳ Postgres health: $status ($i/10)"
        fi
    else
        echo "⏳ Waiting for Postgres... ($i/10)"
    fi
    sleep 3
done

# 🕰️ Wait for Redis (readiness + Docker health)
echo "🕰️ Waiting for Redis..."
for i in {1..10}; do
    docker exec redis_container redis-cli -a "$REDIS_PASSWORD" PING | grep PONG &> /dev/null
    if [ $? -eq 0 ]; then
        status=$(docker inspect --format='{{.State.Health.Status}}' redis_container)
        if [[ "$status" == "healthy" ]]; then
            echo "✅ Redis is healthy (Docker status)"
            break
        else
            echo "⏳ Redis health: $status ($i/10)"
        fi
    else
        echo "⏳ Waiting for Redis... ($i/10)"
    fi
    sleep 3
done
