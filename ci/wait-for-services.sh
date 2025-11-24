#!/usr/bin/env bash
set -e

COMPOSE="docker compose -f compose.yml -f compose.ci.yml"

# wait loop for Node-RED (1880), Postgres (5432), Grafana (3000)
echo "Waiting for services to become ready"

for i in {1..30}; do
    NR_OK=0
    #GF_OK=0
    PG_OK=0

    if curl -fsS http://localhost:1880/ >/dev/null 2>&1; then
        NR_OK=1
    fi

    #if curl -fsS http://localhost:3000/ >/dev/null 2>&1; then
    #    GF_OK=1
    #fi

    if nc -z localhost 5432 >/dev/null 2>&1; then
        PG_OK=1
    fi

    #if [ "$NR_OK" -eq 1 ] && [ "$GF_OK" -eq 1 ] && [ "$PG_OK" -eq 1 ]; then
    if [ "$NR_OK" -eq 1 ] && [ "$PG_OK" -eq 1 ]; then
        echo "All services are up"
        exit 0
    fi

    #echo "Waiting ($i/60) - NR:${NR_OK} GF:${GF_OK} PG:${PG_OK}"
    echo "Waiting ($i/60) - NR:${NR_OK} PG:${PG_OK}"
    sleep 2
done

echo "Services did not become ready in time"
echo "Docker compose status:"
$COMPOSE ps || true
echo "Recent logs:"
$COMPOSE logs --tail=50 || true
exit 1
