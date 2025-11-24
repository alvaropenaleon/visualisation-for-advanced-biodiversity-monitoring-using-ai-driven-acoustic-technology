-- Core schema: extension, dimension table, main data, metrics, errors

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Dimension table
CREATE TABLE IF NOT EXISTS sensors (
    id       SERIAL PRIMARY KEY,
    type     VARCHAR(50),
    location VARCHAR(50)
);

-- Avoid duplicated sensor seeds
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'sensors_type_location_uniq'
    ) THEN
        ALTER TABLE sensors
        ADD CONSTRAINT sensors_type_location_uniq
        UNIQUE (type, location);
    END IF;
END$$;

-- Main data
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

-- Ingestion metrics
CREATE TABLE IF NOT EXISTS ingestion_metrics (
    received_at TIMESTAMPTZ NOT NULL,
    inserted_at TIMESTAMPTZ NOT NULL
);

-- Error log
CREATE TABLE IF NOT EXISTS sensor_errors (
    time        TIMESTAMPTZ DEFAULT NOW(),
    error_msg   TEXT NOT NULL,
    raw_payload JSONB
);
