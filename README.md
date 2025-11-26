# Visualisation for Advanced Biodiversity Monitoring Using AI-Driven Acoustic Technology

*A containerised GUI for exploring BirdNET detection CSVs in passive acoustic monitoring.*

Visualisation for Advanced Biodiversity Monitoring Using AI-Driven Acoustic Technology lets ecologists, students, land managers, and citizen scientists explore large batches of BirdNET-style CSV outputs without writing code. With **one Docker command**, you get a local stack with:

- **Node‑RED** — CSV upload + normalisation (optional HTTP & MQTT ingestion)
- **TimescaleDB (PostgreSQL 16)** — time-series storage (hypertable)
- **Grafana OSS** — pre-provisioned dashboards (overview → compare → drill‑down)

> **Why?** It focuses on the *post‑classification* gap: turning CSVs into canonical, auditable records; visualising both **ecological signals** and **ingestion health** (latency, throughput, errors); and enabling **period comparisons** (WoW/MoM/YoY) with a non‑technical UI.

---

## Contents

- [Quickstart](#quickstart)
- [Verify the stack](#verify-the-stack)
- [Upload & explore](#upload--explore)
- [Example data](#example-data)
- [Configuration](#configuration)
- [Data model](#data-model)
- [Optional ingestion paths](#optional-ingestion-paths)
- [Backups & persistence](#backups--persistence)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)
- [Tests](#tests)
- [Cite this project](#cite-this-project)
- [License](#license)

---

## Quickstart

**Requirements**: Docker & Docker Compose on Linux/macOS/Windows.


1. Clone the repo
```bash
git clone https://github.com/alvaropenaleon/visualisation-for-advanced-biodiversity-monitoring-using-ai-driven-acoustic-technology.git
````
```bash
cd visualisation-for-advanced-biodiversity-monitoring-using-ai-driven-acoustic-technology
```

2. (Optional) Copy .env template and tweak ports/creds
```bash
cp .env.example .env
```

3. Launch services (includes automatic DB migrations)
```bash
docker compose up -d
```

4. Check containers
```bash
docker compose ps
```

**Default ports** (override in `.env`):
- Node‑RED: `http://localhost:1880` (dashboard UI at `/ui`)
- Grafana: `http://localhost:3000`
- PostgreSQL: `localhost:5432`
- MQTT (Mosquitto, optional): `localhost:1883`

> Grafana default creds are typically `admin` / `admin` unless overridden in `.env`. Change on first login.

---

## Verify the stack

On first start, a one-shot `db-bootstrap` container runs the SQL migrations in `db/migrations/` against the `postgres` service and then exits.

After `docker compose up -d`, run:

1. Check that Postgres is reachable
```bash
docker compose exec postgres pg_isready -U postgres -d postgres
```

2. Confirm that migrations ran and tables exist
```bash
docker compose exec postgres \
  psql -U postgres -d postgres -c '\dt'
```

Expected output:

```text
               List of relations
 Schema |       Name        | Type  |  Owner
--------+-------------------+-------+----------
 public | ingestion_metrics | table | postgres
 public | sensor_data       | table | postgres
 public | sensor_errors     | table | postgres
 public | sensors           | table | postgres
(4 rows)
```

If dashboards or flows fail to provision, restart those services:

```bash
docker compose restart grafana nodered
```

---

## Upload & explore

1. Open **Node‑RED dashboard** at `http://localhost:1880/ui` to access the *CSV Upload* panel.  
   - Select one or more BirdNET CSVs.  
   - The flow:
        - parses CSV in chunks,
        - normalises fields (timestamps, species names, confidence, sensor IDs),
        - stamps `received_at` / `inserted_at`,
        - writes rows into the `sensor_data` hypertable and `ingestion_metrics`.
2. Open **Grafana** at `http://localhost:3000` and select the **demo dashboard**.  
   - Use the templated variables (**species**, **confidence**) to filter views.  
   - Explore:
        - **Overview**: total detections, species composition, basic time series
        - **Comparative**: period comparisons between species or time windows
        - **Data-quality / ingestion health**: latency, throughput, missing-data gaps, errors
3. Export data for downstream analysis via **Panel → Inspect → Data → Download CSV**.

---

## Example data

The repository includes small CSVs under examples/ so you can verify the full path quickly.

1. Upload one of the example files through the **CSV Upload** dashboard.
2. Confirm that charts and tables populate in Grafana (time series, species breakdown, etc.).

Note: Any BirdNET-style CSV will work as long as it provides:
- a timestamp (directly or derivable from the file path),
- a species label (scientific and/or common name),
- a confidence score,

Typical headers supported by the normalisation flow include:
- `File`, `Start (s)`, `End (s)`, `Scientific name`, `Common name`, `Confidence`
- or JSON fields like `time`, `sensor_id`, `scientific_name`, `common_name`, `confidence`.

---

## Configuration

Configuration is **declarative** and versioned in-repo:

- **Node-RED** flows and dashboard stored under `nodered-data/` (mounted to /data and auto-loaded at startup).
- **Grafana** data and dashboards under `grafana-data/` (mounted to `/var/lib/grafana`, includes pre-provisioned dashboards).
- **SQL migrations** under `db/migrations/`, applied automatically at startup by the one-shot `db-bootstrap` service.

Key `.env` entries (example):

```dotenv
# Postgres / TimescaleDB
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Grafana
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin

# Node-RED
NODERED_PORT=1880

# MQTT (optional)
MQTT_PORT=1883
```

> Change passwords for non‑local deployments. For remote use, also set `GF_SERVER_ROOT_URL`, TLS, and proper firewalling.

---

## Data model

The stack uses a small, explicit schema designed for time-series analysis and ingestion tracking.

```sql
-- Dimension table sensor metadata
CREATE TABLE IF NOT EXISTS sensors (
    id       SERIAL PRIMARY KEY,
    type     VARCHAR(50),
    location VARCHAR(50)
);

-- Avoid duplicated sensor seeds
ALTER TABLE sensors
ADD CONSTRAINT IF NOT EXISTS sensors_type_location_uniq
UNIQUE (type, location);

-- Main detections table converted to hypertable on "time"
CREATE TABLE IF NOT EXISTS sensor_data (
    time            TIMESTAMPTZ NOT NULL,
    sensor_id       INTEGER,
    start_seconds   INTEGER,
    end_seconds     INTEGER,
    scientific_name VARCHAR(50),
    common_name     VARCHAR(50),
    confidence      DOUBLE PRECISION,
    FOREIGN KEY (sensor_id) REFERENCES sensors (id)
);

-- Per-row timestamps ingestion latency metrics
CREATE TABLE IF NOT EXISTS ingestion_metrics (
    received_at TIMESTAMPTZ NOT NULL,
    inserted_at TIMESTAMPTZ NOT NULL
);

-- Error log for rejected rows / failures
CREATE TABLE IF NOT EXISTS sensor_errors (
    time        TIMESTAMPTZ DEFAULT NOW(),
    error_msg   TEXT NOT NULL,
    raw_payload JSONB
);

-- Convert sensor_data into a TimescaleDB hypertable
SELECT create_hypertable(
    'sensor_data',
    'time',
    if_not_exists => TRUE
);
```

> Some deployments enable **continuous aggregates** for heavy rollups such as daily species counts.

---

## Optional ingestion paths

Besides CSV upload via the dashboard, you can ingest detections via **HTTP** or **MQTT** using the unified ingestion pipeline in Node-RED.

### HTTP (developer/testing)

The stack exposes:

- `POST /detections` on Node-RED (`http://localhost:1880/detections`)

Example:

```bash
curl -X POST http://localhost:1880/detections \
  -H "Content-Type: application/json" \
  -d '[
    {
      "time": "2025-01-01T12:00:00Z",
      "sensor_id": 1,
      "start_seconds": 5,
      "end_seconds": 8,
      "scientific_name": "Geocrinia laevis",
      "common_name": "Southern Smooth Froglet",
      "confidence": 0.92
    }
  ]'
```
The Node-RED flow validates and normalises this payload and writes to `sensor_data` and `ingestion_metrics`. For debugging there is also a `GET /detections` API that queries `sensor_data` with time/species filters.

### MQTT (pilot/streaming)

MQTT ingestion listens on the `detector/data` topic:

```bash
mosquitto_pub -h localhost -p 1883 \
  -t detector/data \
  -m '{
    "time": "2025-01-01T12:00:00Z",
    "sensor_id": 1,
    "start_seconds": 5,
    "end_seconds": 8,
    "scientific_name": "Geocrinia laevis",
    "common_name": "Southern Smooth Froglet",
    "confidence": 0.92
  }'
```

There is also a `POST /config` endpoint in Node-RED that publishes config messages to `detector/config/<sensor_id>` over MQTT, for edge device configuration pilots.

---

## Backups & persistence

Service data and configuration are persisted via bind mounts:

- `./postgres-16-data`: TimescaleDB / PostgreSQL data
- `./grafana-data`: Grafana data (SQLite, dashboards, plugins)
- `./nodered-data`: Node-RED project (flows, dashboard, settings)
- `./mosquitto-data`: Mosquitto broker configuration and persistence

To back up a local deployment:

1. Stop the stack:

```bash
docker compose down
```

2. Archive the relevant directories:

```bash
tar czf backup.tgz postgres-16-data grafana-data nodered-data mosquitto-data
```

In CI, these are replaced by Docker-managed named volumes via `compose.ci.yml` to avoid host-specific permissions while keeping the same container configuration.

---

## Troubleshooting

- **Nothing shows in Grafana**: 
1. Check Node-RED debug tab for CSV parsing/insert errors.
2. Confirm sensor_data has rows:

```bash
docker compose exec postgres \
psql -U postgres -d postgres -c "SELECT COUNT(*) FROM sensor_data;"
```

- **Errors during ingestion**

Failed rows are logged into sensor_errors with error_msg and raw_payload.

```bash
docker compose exec postgres \
psql -U postgres -d postgres -c "SELECT * FROM sensor_errors LIMIT 20;"
```

- **Services not starting / timing out**

Check migration logs:

```bash
docker compose logs db-bootstrap
```
Check individual services:

```bash
docker compose logs -f postgres
docker compose logs -f nodered
docker compose logs -f grafana
```

- **Port conflicts**

Adjust ports in .env and restart:

```bash
docker compose down
docker compose up -d
```

---

## Security notes

The default configuration is for **local development**:

- Default passwords are simple and stored in .env.example.
- HTTP endpoints are unencrypted and unauthenticated.
- MQTT has no auth.

For any network-exposed deployment:

- Change all default passwords and rotate them regularly.
- Enable TLS where supported (Grafana, reverse proxies, etc.).
- Restrict inbound ports to trusted IPs (firewall, security groups).
- Ensure CSVs and logs do not contain sensitive information without proper governance.

---

## Tests

We provide a GitHub Actions **CI smoke test** workflow that:
1. Launches the full stack using `docker compose` with `compose.yml` and `compose.ci.yml`.
2. Applies SQL migrations via a one-shot `db-bootstrap` container.
3. Runs an integration smoke test inside the `postgres` service, asserting that:
    - all core tables (`sensors`, `sensor_data`, `ingestion_metrics`, `sensor_errors`) exist, and
    - initial sensor metadata has been seeded.

This guarantees that the published Compose files, migrations, and Node-RED flows remain deployable and consistent across local machines, CI runners, and future demo deployments.

## License

This project is licensed under the MIT License – see the [LICENSE](./LICENSE) file for details.

## Acknowledgements

An early version of this stack was inspired by the [Digitalisation AIO Package](https://github.com/ctch3ng/Digitalisation-AIO-Package), which provided an initial scaffold for combining Node-RED, PostgreSQL, Mosquitto, and Grafana. The current architecture, including the BirdNET focused schema, SQL migrations, Node-RED ingestion flows, ingestion metrics, Grafana dashboards, and CI smoke tests has been engineered specifically for this project.

