#!/usr/bin/env bash
set -e

echo "Checking Postgres responds to a simple query"

# compose.yml servuce name: 'postgres'
docker compose -f compose.yml exec -T postgres psql -U postgres -d postgres -c "SELECT 1;" || {
    echo "Postgres query failed ❌"
    exit 1
}

echo "Postgres responded correctly ✅"
