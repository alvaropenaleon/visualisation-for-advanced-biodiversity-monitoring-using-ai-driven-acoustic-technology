-- Convert sensor_data into a TimescaleDB hypertable

SELECT create_hypertable(
    'sensor_data',
    'time',
    if_not_exists => TRUE
);
