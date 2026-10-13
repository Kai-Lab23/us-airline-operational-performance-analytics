-- ============================================================
-- U.S. Airline Operational Performance Analytics 2025
-- PostgreSQL Schema
-- Run this script inside the airline_analytics_2025 database
-- before running 04_load_postgresql_airline_2025.ipynb.
-- ============================================================

BEGIN;

-- ============================================================
-- DIMENSION TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS dim_airline (
    airline_code VARCHAR(10),
    airline_key INTEGER PRIMARY KEY,
    airline_name VARCHAR(150) NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_airport (
    airport_key INTEGER PRIMARY KEY,
    airport_code VARCHAR(10) NOT NULL,
    city_name VARCHAR(150),
    state_code VARCHAR(10),
    state_name VARCHAR(100),
    airport_label VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS dim_date (
    date_key INTEGER PRIMARY KEY,
    date DATE NOT NULL,
    year SMALLINT NOT NULL,
    quarter SMALLINT NOT NULL,
    month_number SMALLINT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    day_of_month SMALLINT NOT NULL,
    day_of_week_number SMALLINT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    weekend_flag SMALLINT NOT NULL
);

-- ============================================================
-- FACT TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS fact_flights (
    date_key INTEGER,
    airline_key INTEGER,
    origin_airport_key INTEGER,
    destination_airport_key INTEGER,

    flight_number INTEGER,
    tail_number VARCHAR(20),
    route VARCHAR(30),

    crs_dep_time NUMERIC,
    dep_time NUMERIC,
    dep_delay NUMERIC,
    dep_delay_minutes NUMERIC,
    dep_del15 NUMERIC,
    dep_time_blk VARCHAR(20),
    taxi_out NUMERIC,

    crs_arr_time NUMERIC,
    arr_time NUMERIC,
    arr_delay NUMERIC,
    arr_delay_minutes NUMERIC,
    arr_del15 NUMERIC,
    arr_time_blk VARCHAR(20),
    taxi_in NUMERIC,

    cancelled NUMERIC,
    cancellation_code VARCHAR(10),
    diverted NUMERIC,

    crs_elapsed_time NUMERIC,
    actual_elapsed_time NUMERIC,
    air_time NUMERIC,
    distance NUMERIC,

    carrier_delay NUMERIC,
    weather_delay NUMERIC,
    nas_delay NUMERIC,
    security_delay NUMERIC,
    late_aircraft_delay NUMERIC,

    scheduled_dep_hour INTEGER,
    departure_period VARCHAR(20),

    valid_arrival_flag NUMERIC,
    arrival_delayed15_flag NUMERIC,
    on_time_arrival_flag NUMERIC,
    severe_delay_flag NUMERIC,

    arrival_status VARCHAR(30),
    delay_severity VARCHAR(30),

    total_cause_delay_minutes NUMERIC,
    net_delay_change_minutes NUMERIC,
    distance_band VARCHAR(30),

    CONSTRAINT fk_fact_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key),

    CONSTRAINT fk_fact_airline
        FOREIGN KEY (airline_key)
        REFERENCES dim_airline(airline_key),

    CONSTRAINT fk_fact_origin_airport
        FOREIGN KEY (origin_airport_key)
        REFERENCES dim_airport(airport_key),

    CONSTRAINT fk_fact_destination_airport
        FOREIGN KEY (destination_airport_key)
        REFERENCES dim_airport(airport_key)
);

COMMIT;
