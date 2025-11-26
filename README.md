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
- [Cite this project](#cite-this-project)
- [License](#license)

---

## Quickstart

**Requirements**: Docker & Docker Compose on Linux/macOS/Windows.

```bash
# 1) Clone the repo
git clone https://github.com/alvaropenaleon/visualisation-for-advanced-biodiversity-monitoring-using-ai-driven-acoustic-technology.git
cd visualisation-for-advanced-biodiversity-monitoring-using-ai-driven-acoustic-technology

# 2) (Optional) Copy .env template and tweak ports/creds
cp .env.example .env

# 3) Launch services
docker compose up -d

# 4) Check containers
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

After `docker compose up -d`, run a couple of quick checks:

```bash
# 1) Check that Postgres is reachable
docker compose exec postgres pg_isready -U postgres -d postgres

# 2) Confirm that migrations ran and tables exist
docker compose exec postgres \
  psql -U postgres -d postgres -c '\dt'
```

The below should show:

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

1. Open **Node‑RED dashboard** → `http://localhost:1880/ui` → *CSV Upload* panel.  
   - Drag‑and‑drop one or more BirdNET CSVs.  
   - The flow validates rows, records `received_at` and `inserted_at`, batches, and writes to the hypertable.
2. Open **Grafana** → `http://localhost:3000` and select the **Demo Dashboard** dashboard.  
   - Use the templated variables (**species**, **site**, **confidence**) to filter views.  
   - Explore **Overview → Comparative → Data‑quality** rows.  
   - Export tables via **Panel → Inspect → Data → Download CSV**.

---

## Example data

The repository includes small CSVs under `examples/` so you can verify the full path quickly.  
Upload an example file through the Node‑RED dashboard and confirm charts populate in Grafana. Any BirdNET-style CSV that includes timestamp, species label, and confidence.

> If your deployment does **not** include `examples/`, use any BirdNET‑style CSV that includes timestamp, species label, confidence, and (optionally) site/device metadata.

---

## Configuration

Configuration is **declarative** and versioned in-repo:

- **Node-RED** flows under `nodered-data/` (auto-loaded at startup)
- **Grafana** provisioning under `grafana/provisioning/`
- **SQL migrations** under `db/migrations/` (applied automatically by `db-bootstrap`)

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

> Some deployments enable **continuous aggregates** for heavy rollups (e.g., daily site×species counts).

---

## Optional ingestion paths

Besides CSV upload via dashboard, you can ingest via **HTTP** or **MQTT** (if enabled):

### HTTP (developer/testing)
```bash
curl -X POST http://localhost:1880/detections \  -H 'Content-Type: application/json' \  -d '[{"time":"2025-01-01T12:00:00Z","site":"S1","species":"Carduelis carduelis","confidence":0.92}]'
```

### MQTT (pilot/streaming)
```bash
mosquitto_pub -h localhost -p 1883 -t sensors/detections -m '{"time":"2025-01-01T12:00:00Z","site":"S1","species":"Carduelis carduelis","confidence":0.92}'
```

Node‑RED flows parse, validate and normalise these payloads before insert.

---

## Backups & persistence

Docker volumes persist data and configuration:

- `db-data/` — PostgreSQL/TimescaleDB
- `grafana-data/` — Grafana SQLite & plugins
- `nodered-data/` — Node‑RED flows & runtime

Back up by stopping the stack and archiving named volumes or binding directories.

---

## Troubleshooting

- **Nothing shows in Grafana**: confirm CSV upload succeeded (Node‑RED debug tab), and that `detections` has rows.
- **Provisioning loop**: check `grafana` logs for JSON errors; ensure dashboard UIDs are unique.
- **DB rejects CSV**: a malformed row will be recorded in `sensor_errors`; export and inspect a few sample lines.
- **High latency**: check Docker resource limits; batch sizes in Node‑RED can be tuned for your hardware.
- **Port conflicts**: adjust ports in `.env` and re‑`docker compose up -d`.

View logs:
```bash
docker compose logs -f postgres
docker compose logs -f db-bootstrap
docker compose logs -f nodered
docker compose logs -f grafana
```

---

## Security notes

Ships with local‑dev defaults. For any network‑exposed deployment:
- Change all default passwords and enable TLS where applicable.
- Restrict inbound ports to trusted hosts.
- Do not upload sensitive data without appropriate governance.

---

### Tests

We provide a GitHub Actions CI workflow that launches the full stack using Docker Compose, applies SQL migrations via a one-shot db-bootstrap container, and runs an integration smoke test inside the Postgres service. The test asserts that all core tables (sensors, sensor_data, ingestion_metrics, sensor_errors) exist and that initial sensor metadata has been seeded. This guarantees that the published Compose files, migrations, and Node-RED flows remain deployable and consistent across local machines, CI runners, and future demo deployments.

