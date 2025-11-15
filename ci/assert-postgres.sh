#!/usr/bin/env bash
set -e

echo "Checking Postgres responds to a simple query inside the container"

# try up to 30 times to connect and run a simple query
for i in {1..30}; do
    if docker compose -f compose.yml exec -T postgres \
        psql -U postgres -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        echo "Postgres responded correctly on attempt $i"
        exit 0
    fi

    echo "Postgres not ready yet ($i/30)"
    sleep 2
done

echo "Postgres query failed"
echo "Last Postgres logs:"
docker compose -f compose.yml logs postgres --tail=50 || true
exit 1

