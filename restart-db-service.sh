#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔁 Restarting Postgres container..."

echo "🛑 Stopping container if running..."
docker-compose down

echo "🔄 Starting container with new environment settings..."
docker-compose up -d

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
