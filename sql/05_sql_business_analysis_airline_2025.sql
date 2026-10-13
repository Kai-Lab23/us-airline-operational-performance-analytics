-- ============================================================
-- 0. DATA VALIDATION
-- ============================================================

SELECT
    COUNT(*) AS total_flights,
    SUM(valid_arrival_flag)::BIGINT AS valid_arrivals,
    SUM(arrival_delayed15_flag)::BIGINT AS delayed_arrivals_15_plus,
    SUM(cancelled)::BIGINT AS cancelled_flights,
    SUM(diverted)::BIGINT AS diverted_flights
FROM fact_flights;


-- ============================================================
-- 1. BUSINESS QUESTION 1
-- How reliable were U.S. airline operations in 2025?
-- ============================================================

SELECT
    COUNT(*) AS total_flights,

    SUM(valid_arrival_flag)::BIGINT AS valid_arrivals,

    SUM(on_time_arrival_flag)::BIGINT AS on_time_arrivals,

    SUM(arrival_delayed15_flag)::BIGINT AS delayed_arrivals_15_plus,

    ROUND(
        100.0 * SUM(on_time_arrival_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS on_time_arrival_rate_pct,

    ROUND(
        100.0 * SUM(arrival_delayed15_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(cancelled)
        / COUNT(*),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        100.0 * SUM(diverted)
        / COUNT(*),
        2
    ) AS diversion_rate_pct,

    ROUND(
        AVG(arr_delay)
        FILTER (WHERE arrival_delayed15_flag = 1),
        2
    ) AS avg_delay_minutes_delayed_flights,

    ROUND(
        100.0 * SUM(severe_delay_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct

FROM fact_flights;


-- ============================================================
-- 2. BUSINESS QUESTION 2
-- When do delays and disruptions occur most frequently?
-- ============================================================

-- 2A. Monthly performance
SELECT
    d.month_number,
    d.month_name,

    COUNT(*) AS total_flights,

    SUM(f.valid_arrival_flag)::BIGINT AS valid_arrivals,

    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.on_time_arrival_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS on_time_arrival_rate_pct,

    ROUND(
        100.0 * SUM(f.cancelled)
        / COUNT(*),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        100.0 * SUM(f.diverted)
        / COUNT(*),
        2
    ) AS diversion_rate_pct,

    ROUND(
        100.0 * SUM(f.severe_delay_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct

FROM fact_flights f
JOIN dim_date d
    ON f.date_key = d.date_key

GROUP BY
    d.month_number,
    d.month_name

ORDER BY
    d.month_number;


-- 2B. Scheduled departure hour
SELECT
    scheduled_dep_hour,

    COUNT(*) AS total_flights,

    ROUND(
        100.0 * SUM(arrival_delayed15_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(severe_delay_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct

FROM fact_flights

GROUP BY scheduled_dep_hour

ORDER BY scheduled_dep_hour;


-- 2C. Departure period
SELECT
    departure_period,

    COUNT(*) AS total_flights,

    SUM(arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(arrival_delayed15_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct

FROM fact_flights

GROUP BY departure_period

ORDER BY
    CASE departure_period
        WHEN 'Night' THEN 1
        WHEN 'Morning' THEN 2
        WHEN 'Afternoon' THEN 3
        WHEN 'Evening' THEN 4
        ELSE 5
    END;


-- 2D. Day of week
SELECT
    d.day_of_week_number,
    d.day_name,

    COUNT(*) AS total_flights,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct

FROM fact_flights f
JOIN dim_date d
    ON f.date_key = d.date_key

GROUP BY
    d.day_of_week_number,
    d.day_name

ORDER BY
    d.day_of_week_number;


-- ============================================================
-- 3. BUSINESS QUESTION 3
-- Which airlines have the strongest and weakest performance?
-- ============================================================

SELECT
    a.airline_code,
    a.airline_name,

    COUNT(*) AS total_flights,

    SUM(f.valid_arrival_flag)::BIGINT AS valid_arrivals,

    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.on_time_arrival_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS on_time_arrival_rate_pct,

    ROUND(
        100.0 * SUM(f.severe_delay_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.cancelled)
        / COUNT(*),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        AVG(f.arr_delay)
        FILTER (WHERE f.arrival_delayed15_flag = 1),
        2
    ) AS avg_delay_minutes_delayed_flights

FROM fact_flights f
JOIN dim_airline a
    ON f.airline_key = a.airline_key

GROUP BY
    a.airline_code,
    a.airline_name

ORDER BY
    arrival_delay_rate_pct DESC;


-- ============================================================
-- 4. BUSINESS QUESTION 4
-- Which airports and routes experience the highest disruption?
-- ============================================================

-- 4A. Origin airport departure performance
-- Minimum 10,000 departing flights for meaningful comparison
SELECT
    ap.airport_code,
    ap.city_name,
    ap.state_code,

    COUNT(*) AS total_departing_flights,

    SUM(
        CASE
            WHEN f.cancelled = 0
             AND f.dep_del15 IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS valid_departures,

    SUM(
        CASE
            WHEN f.dep_del15 = 1
            THEN 1
            ELSE 0
        END
    ) AS delayed_departures_15_plus,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN f.dep_del15 = 1
                THEN 1
                ELSE 0
            END
        )
        / NULLIF(
            SUM(
                CASE
                    WHEN f.cancelled = 0
                     AND f.dep_del15 IS NOT NULL
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS departure_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.cancelled)
        / COUNT(*),
        2
    ) AS cancellation_rate_pct

FROM fact_flights f
JOIN dim_airport ap
    ON f.origin_airport_key = ap.airport_key

GROUP BY
    ap.airport_code,
    ap.city_name,
    ap.state_code

HAVING COUNT(*) >= 10000

ORDER BY
    departure_delay_rate_pct DESC;


-- 4B. Destination airport arrival performance
-- Minimum 10,000 arriving flights
SELECT
    ap.airport_code,
    ap.city_name,
    ap.state_code,

    COUNT(*) AS total_arriving_flights,

    SUM(f.valid_arrival_flag)::BIGINT AS valid_arrivals,

    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.severe_delay_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct

FROM fact_flights f
JOIN dim_airport ap
    ON f.destination_airport_key = ap.airport_key

GROUP BY
    ap.airport_code,
    ap.city_name,
    ap.state_code

HAVING COUNT(*) >= 10000

ORDER BY
    arrival_delay_rate_pct DESC;


-- 4C. Route performance
-- Minimum 1,000 flights
SELECT
    f.route,

    COUNT(*) AS total_flights,

    SUM(f.valid_arrival_flag)::BIGINT AS valid_arrivals,

    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.severe_delay_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct,

    ROUND(
        AVG(f.arr_delay)
        FILTER (WHERE f.arrival_delayed15_flag = 1),
        2
    ) AS avg_delay_minutes_delayed_flights,

    ROUND(
        SUM(
            CASE
                WHEN f.arrival_delayed15_flag = 1
                THEN f.arr_delay
                ELSE 0
            END
        ),
        0
    ) AS delayed_arrival_minutes,

    ROUND(
        SUM(
            CASE
                WHEN f.arrival_delayed15_flag = 1
                THEN f.arr_delay
                ELSE 0
            END
        ) / 60.0,
        2
    ) AS delay_burden_hours

FROM fact_flights f

GROUP BY
    f.route

HAVING COUNT(*) >= 1000

ORDER BY
    delay_burden_hours DESC;


-- ============================================================
-- 5. BUSINESS QUESTION 5
-- What are the primary causes of flight delays?
-- ============================================================

WITH delay_causes AS (

    SELECT
        'Carrier' AS delay_cause,
        SUM(COALESCE(carrier_delay, 0)) AS delay_minutes
    FROM fact_flights

    UNION ALL

    SELECT
        'Weather',
        SUM(COALESCE(weather_delay, 0))
    FROM fact_flights

    UNION ALL

    SELECT
        'NAS',
        SUM(COALESCE(nas_delay, 0))
    FROM fact_flights

    UNION ALL

    SELECT
        'Security',
        SUM(COALESCE(security_delay, 0))
    FROM fact_flights

    UNION ALL

    SELECT
        'Late Aircraft',
        SUM(COALESCE(late_aircraft_delay, 0))
    FROM fact_flights

),

cause_total AS (

    SELECT
        SUM(delay_minutes) AS total_delay_minutes
    FROM delay_causes

)

SELECT
    d.delay_cause,

    ROUND(
        d.delay_minutes,
        0
    ) AS delay_minutes,

    ROUND(
        d.delay_minutes / 60.0,
        2
    ) AS delay_hours,

    ROUND(
        100.0 * d.delay_minutes
        / NULLIF(c.total_delay_minutes, 0),
        2
    ) AS delay_share_pct

FROM delay_causes d
CROSS JOIN cause_total c

ORDER BY
    delay_share_pct DESC;


-- ============================================================
-- 6. BUSINESS QUESTION 6
-- Where should operational improvement efforts be prioritized?
-- ============================================================

-- Route priority:
-- combines meaningful route volume with total delayed-arrival burden.
SELECT
    f.route,

    COUNT(*) AS total_flights,

    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN f.arrival_delayed15_flag = 1
                THEN f.arr_delay
                ELSE 0
            END
        ) / 60.0,
        2
    ) AS delay_burden_hours

FROM fact_flights f

GROUP BY
    f.route

HAVING COUNT(*) >= 1000

ORDER BY
    delay_burden_hours DESC

LIMIT 20;


-- ============================================================
-- 7. CREATE POWER BI ANALYTICAL VIEWS
-- ============================================================

DROP VIEW IF EXISTS vw_monthly_performance;
DROP VIEW IF EXISTS vw_airline_performance;
DROP VIEW IF EXISTS vw_origin_airport_performance;
DROP VIEW IF EXISTS vw_destination_airport_performance;
DROP VIEW IF EXISTS vw_route_performance;
DROP VIEW IF EXISTS vw_departure_hour_performance;
DROP VIEW IF EXISTS vw_departure_period_performance;
DROP VIEW IF EXISTS vw_delay_cause_summary;


-- 7A. Monthly Performance View
CREATE VIEW vw_monthly_performance AS
SELECT
    d.month_number,
    d.month_name,
    COUNT(*) AS total_flights,
    SUM(f.valid_arrival_flag)::BIGINT AS valid_arrivals,
    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,
    SUM(f.on_time_arrival_flag)::BIGINT AS on_time_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.on_time_arrival_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS on_time_arrival_rate_pct,

    ROUND(
        100.0 * SUM(f.cancelled)
        / COUNT(*),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        100.0 * SUM(f.diverted)
        / COUNT(*),
        2
    ) AS diversion_rate_pct,

    ROUND(
        100.0 * SUM(f.severe_delay_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct

FROM fact_flights f
JOIN dim_date d
    ON f.date_key = d.date_key

GROUP BY
    d.month_number,
    d.month_name;


-- 7B. Airline Performance View
CREATE VIEW vw_airline_performance AS
SELECT
    a.airline_code,
    a.airline_name,

    COUNT(*) AS total_flights,

    SUM(f.valid_arrival_flag)::BIGINT AS valid_arrivals,

    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.on_time_arrival_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS on_time_arrival_rate_pct,

    ROUND(
        100.0 * SUM(f.severe_delay_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.cancelled)
        / COUNT(*),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        AVG(f.arr_delay)
        FILTER (WHERE f.arrival_delayed15_flag = 1),
        2
    ) AS avg_delay_minutes_delayed_flights

FROM fact_flights f
JOIN dim_airline a
    ON f.airline_key = a.airline_key

GROUP BY
    a.airline_code,
    a.airline_name;


-- 7C. Origin Airport Performance View
CREATE VIEW vw_origin_airport_performance AS
SELECT
    ap.airport_code,
    ap.city_name,
    ap.state_code,

    COUNT(*) AS total_departing_flights,

    SUM(
        CASE
            WHEN f.cancelled = 0
             AND f.dep_del15 IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS valid_departures,

    SUM(
        CASE
            WHEN f.dep_del15 = 1
            THEN 1
            ELSE 0
        END
    ) AS delayed_departures_15_plus,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN f.dep_del15 = 1
                THEN 1
                ELSE 0
            END
        )
        / NULLIF(
            SUM(
                CASE
                    WHEN f.cancelled = 0
                     AND f.dep_del15 IS NOT NULL
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS departure_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.cancelled)
        / COUNT(*),
        2
    ) AS cancellation_rate_pct

FROM fact_flights f
JOIN dim_airport ap
    ON f.origin_airport_key = ap.airport_key

GROUP BY
    ap.airport_code,
    ap.city_name,
    ap.state_code;


-- 7D. Destination Airport Performance View
CREATE VIEW vw_destination_airport_performance AS
SELECT
    ap.airport_code,
    ap.city_name,
    ap.state_code,

    COUNT(*) AS total_arriving_flights,

    SUM(f.valid_arrival_flag)::BIGINT AS valid_arrivals,

    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.severe_delay_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct

FROM fact_flights f
JOIN dim_airport ap
    ON f.destination_airport_key = ap.airport_key

GROUP BY
    ap.airport_code,
    ap.city_name,
    ap.state_code;


-- 7E. Route Performance View
CREATE VIEW vw_route_performance AS
SELECT
    f.route,

    COUNT(*) AS total_flights,

    SUM(f.valid_arrival_flag)::BIGINT AS valid_arrivals,

    SUM(f.arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(f.arrival_delayed15_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(f.severe_delay_flag)
        / NULLIF(SUM(f.valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct,

    ROUND(
        AVG(f.arr_delay)
        FILTER (WHERE f.arrival_delayed15_flag = 1),
        2
    ) AS avg_delay_minutes_delayed_flights,

    ROUND(
        SUM(
            CASE
                WHEN f.arrival_delayed15_flag = 1
                THEN f.arr_delay
                ELSE 0
            END
        ) / 60.0,
        2
    ) AS delay_burden_hours

FROM fact_flights f

GROUP BY
    f.route;


-- 7F. Departure Hour Performance View
CREATE VIEW vw_departure_hour_performance AS
SELECT
    scheduled_dep_hour,

    COUNT(*) AS total_flights,

    ROUND(
        100.0 * SUM(arrival_delayed15_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        100.0 * SUM(severe_delay_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS severe_delay_rate_pct

FROM fact_flights

GROUP BY
    scheduled_dep_hour;


-- 7G. Departure Period Performance View
CREATE VIEW vw_departure_period_performance AS
SELECT
    departure_period,

    COUNT(*) AS total_flights,

    SUM(arrival_delayed15_flag)::BIGINT AS delayed_arrivals,

    ROUND(
        100.0 * SUM(arrival_delayed15_flag)
        / NULLIF(SUM(valid_arrival_flag), 0),
        2
    ) AS arrival_delay_rate_pct

FROM fact_flights

GROUP BY
    departure_period;


-- 7H. Delay Cause Summary View
CREATE VIEW vw_delay_cause_summary AS

WITH delay_causes AS (

    SELECT
        'Carrier' AS delay_cause,
        SUM(COALESCE(carrier_delay, 0)) AS delay_minutes
    FROM fact_flights

    UNION ALL

    SELECT
        'Weather',
        SUM(COALESCE(weather_delay, 0))
    FROM fact_flights

    UNION ALL

    SELECT
        'NAS',
        SUM(COALESCE(nas_delay, 0))
    FROM fact_flights

    UNION ALL

    SELECT
        'Security',
        SUM(COALESCE(security_delay, 0))
    FROM fact_flights

    UNION ALL

    SELECT
        'Late Aircraft',
        SUM(COALESCE(late_aircraft_delay, 0))
    FROM fact_flights

),

cause_total AS (

    SELECT
        SUM(delay_minutes) AS total_delay_minutes
    FROM delay_causes

)

SELECT
    d.delay_cause,

    ROUND(
        d.delay_minutes,
        0
    ) AS delay_minutes,

    ROUND(
        d.delay_minutes / 60.0,
        2
    ) AS delay_hours,

    ROUND(
        100.0 * d.delay_minutes
        / NULLIF(c.total_delay_minutes, 0),
        2
    ) AS delay_share_pct

FROM delay_causes d
CROSS JOIN cause_total c;


-- ============================================================
-- 8. VALIDATE ANALYTICAL VIEWS
-- ============================================================

SELECT
    'vw_monthly_performance' AS view_name,
    COUNT(*) AS row_count
FROM vw_monthly_performance

UNION ALL

SELECT
    'vw_airline_performance',
    COUNT(*)
FROM vw_airline_performance

UNION ALL

SELECT
    'vw_origin_airport_performance',
    COUNT(*)
FROM vw_origin_airport_performance

UNION ALL

SELECT
    'vw_destination_airport_performance',
    COUNT(*)
FROM vw_destination_airport_performance

UNION ALL

SELECT
    'vw_route_performance',
    COUNT(*)
FROM vw_route_performance

UNION ALL

SELECT
    'vw_departure_hour_performance',
    COUNT(*)
FROM vw_departure_hour_performance

UNION ALL

SELECT
    'vw_departure_period_performance',
    COUNT(*)
FROM vw_departure_period_performance

UNION ALL

SELECT
    'vw_delay_cause_summary',
    COUNT(*)
FROM vw_delay_cause_summary

ORDER BY view_name;


-- ============================================================
-- 9. QUICK CHECKS FOR POWER BI
-- ============================================================

SELECT *
FROM vw_monthly_performance
ORDER BY month_number;

SELECT *
FROM vw_airline_performance
ORDER BY arrival_delay_rate_pct DESC;

SELECT *
FROM vw_delay_cause_summary
ORDER BY delay_share_pct DESC;

SELECT *
FROM vw_route_performance
WHERE total_flights >= 1000
ORDER BY delay_burden_hours DESC
LIMIT 20;