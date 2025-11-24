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


If dashboards or flows fail to provision, restart those services:

```bash
docker compose restart grafana nodered
```

---

## Upload & explore

1. Open **Node‑RED dashboard** → `http://localhost:1880/ui` → *CSV Upload* panel.  
   - Drag‑and‑drop one or more BirdNET CSVs.  
   - The flow validates rows, records `received_at` and `inserted_at`, batches, and writes to the hypertable.
2. Open **Grafana** → `http://localhost:3000` and select the **ChirpCheck** dashboards.  
   - Use the templated variables (**species**, **site**, **confidence**) to filter views.  
   - Explore **Overview → Comparative → Data‑quality** rows.  
   - Export tables via **Panel → Inspect → Data → Download CSV**.

---

## Example data

The repository includes small CSVs under `examples/` so you can verify the full path quickly.  
Upload an example file through the Node‑RED dashboard and confirm charts populate in Grafana.

> If your deployment does **not** include `examples/`, use any BirdNET‑style CSV that includes timestamp, species label, confidence, and (optionally) site/device metadata.

---

## Configuration

Configuration is **declarative** and versioned in-repo:

- **Node‑RED** flows under `nodered/` (auto‑loaded at startup)
- **Grafana** provisioning under `grafana/provisioning/`
- **SQL** migrations and helper views under `sql/`

Key `.env` entries (example):

```dotenv
# Postgres / TimescaleDB
POSTGRES_DB=chirpcheck
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
DB_PORT=5432

# Grafana
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
GRAFANA_PORT=3000

# Node-RED
NODERED_PORT=1880

# MQTT (optional)
ENABLE_MQTT=true
MQTT_PORT=1883
```

> Change passwords for non‑local deployments. For remote use, also set `GF_SERVER_ROOT_URL`, TLS, and proper firewalling.

---

## Data model

Detections are stored in a TimescaleDB **hypertable** (example schema shown for reference):

```sql
-- Base table (created & converted to hypertable by migrations/flows)
CREATE TABLE IF NOT EXISTS detections (
  time           TIMESTAMPTZ NOT NULL,
  site           TEXT,
  species        TEXT NOT NULL,
  confidence     DOUBLE PRECISION,
  source         TEXT DEFAULT 'csv',
  meta           JSONB,
  received_at    TIMESTAMPTZ,
  inserted_at    TIMESTAMPTZ DEFAULT now()
);

-- Metrics & errors (optional tables)
CREATE TABLE IF NOT EXISTS ingestion_metrics (
  window_start   TIMESTAMPTZ,
  window_end     TIMESTAMPTZ,
  rows_ingested  BIGINT,
  p50_latency_ms DOUBLE PRECISION,
  p95_latency_ms DOUBLE PRECISION
);

CREATE TABLE IF NOT EXISTS sensor_errors (
  time           TIMESTAMPTZ,
  source         TEXT,
  raw_line       TEXT,
  error          TEXT
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
docker compose logs -f nodered
docker compose logs -f grafana
docker compose logs -f db
```

---

## Security notes

Ships with local‑dev defaults. For any network‑exposed deployment:
- Change all default passwords and enable TLS where applicable.
- Restrict inbound ports to trusted hosts.
- Do not upload sensitive data without appropriate governance.

---

### Tests

For local usage, the stack bind-mounts service data directories so users can inspect and back up configuration files directly. For continuous integration, we provide a compose.ci.yml override that replaces these bind mounts with Docker-managed named volumes, avoiding host-specific permission issues on CI runners while preserving identical container configuration across environments.

