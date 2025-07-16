#!/bin/bash

# Load environment variables from .env
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔍 Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "🚫 Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
else
    echo "✅ Docker is installed."
fi

echo "🔍 Checking if container is running..."
if [ "$(docker ps -q -f name=postgres_container)" == "" ]; then
    echo "🚀 Starting Postgres container..."
    docker-compose up -d
else
    echo "✅ Postgres container is already running."
fi

echo "🕰️ Waiting for Postgres to finish initializing..."

ready=0
for i in {1..10}; do
    docker exec postgres_container psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1;" &> /dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Database is ready!"
        ready=1
        break
    else
        echo "⏳ Waiting... ($i/10)"
        sleep 2
    fi
done

if [ $ready -eq 0 ]; then
    echo "❌ Database still not ready after waiting."
    exit 1
fi

echo "🧪 Checking DB health..."
docker exec postgres_container psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1;" &> /dev/null

if [ $? -ne 0 ]; then
    echo "❌ Could not connect to the database."
    exit 1
else
    echo "✅ Database is up and accepting connections."
fi

echo "🔍 Checking PostGIS version..."
docker exec postgres_container psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT PostGIS_Version();"

echo "🌐 Connection Details:"
echo "Host: ${CUSTOM_HOST:-localhost}"
echo "Port: ${CUSTOM_PORT:-5432}"
echo "Database: ${POSTGRES_DB}"
echo "User: ${POSTGRES_USER}"
