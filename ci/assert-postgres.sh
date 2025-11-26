#!/usr/bin/env bash
set -e

COMPOSE="docker compose -f compose.yml -f compose.ci.yml"

echo "Checking Postgres responds to a simple query inside the container"

# try up to 30 times to connect and run a simple query
for i in {1..30}; do
    if $COMPOSE exec -T postgres \
        psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL' >/dev/null 2>&1; then
\dt sensors
\dt sensor_data
\dt ingestion_metrics
\dt sensor_errors
SELECT COUNT(*) FROM sensors;
SQL
        echo "Postgres responded correctly on attempt $i"
        exit 0
    fi

    echo "Postgres not ready yet ($i/30)"
    sleep 2
done

echo "Postgres query failed"
echo "Last Postgres logs:"
$COMPOSE logs postgres --tail=50 || true
exit 1

