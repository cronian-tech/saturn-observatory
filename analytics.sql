CREATE TABLE IF NOT EXISTS saturn_node_info AS FROM '/inputs/saturn_node_info.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_creation AS FROM '/inputs/saturn_node_creation_timestamp.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_estimated_earnings AS FROM '/inputs/saturn_node_estimated_earnings.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_bandwidth_served AS FROM '/inputs/saturn_node_bandwidth_served.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_retrievals AS FROM '/inputs/saturn_node_retrievals.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_response_duration AS FROM '/inputs/saturn_node_response_duration_milliseconds.csv.gz';


-- Returns network traffic over time.
COPY (
    SELECT
        observed_at,
        sum(bandwidth_served_bytes)
    FROM saturn_node_bandwidth_served
    GROUP BY observed_at
    ORDER BY observed_at -- Ordering is required for deterministic results.
) TO '/outputs/saturn_traffic.csv';


-- Returns network retrievals over time.
COPY (
    SELECT
        max(observed_at) as observed_at,
        sum(retrievals)
    FROM saturn_node_retrievals
    GROUP BY
        datepart('year', observed_at),
        datepart('month', observed_at),
        datepart('day', observed_at),
        datepart('hour', observed_at)
    ORDER BY observed_at -- Ordering is required for deterministic results.
) TO '/outputs/saturn_retrievals.csv';


-- Calculate traffic served per node.
CREATE TEMP VIEW bandwidth_served_by_node AS
SELECT
    node_id,
    sum(bandwidth_served_bytes) as bandwidth_served_bytes
FROM saturn_node_bandwidth_served
GROUP BY node_id;


-- Calculate estimated earnings per node.
CREATE TEMP VIEW estimated_earnings_by_node AS
SELECT
    node_id,
    sum(estimated_earnings_fil) as estimated_earnings_fil
FROM saturn_node_estimated_earnings
-- Earnings on 2023-08-01 looks abnormally high. Need to figure out this later.
WHERE
    observed_at >= '2023-08-02'
    -- Explicitly filter out core node earnings.
    AND node_id NOT IN (
        SELECT DISTINCT node_id
        FROM saturn_node_info
        WHERE core = true
    )
GROUP BY node_id;


-- For every node return its country.
CREATE TEMP VIEW node_country AS
SELECT
    node_id,
    -- There's a little chance that some nodes changed their location.
    -- But we simply ignore it by taking any known location of a node.
    any_value(geoloc_country) as geoloc_country
FROM saturn_node_info
GROUP BY node_id;


-- Return the number of active nodes, estimated earnings and traffic by country.
COPY (
    WITH
    -- Return the number of active nodes by country.
    active_nodes AS (
        SELECT
            geoloc_country,
            count(DISTINCT node_id) as active_node_count
        FROM saturn_node_info
        WHERE state = 'active'
        GROUP BY geoloc_country
    ),
    -- Return estimated earnings and traffic by country.
    country_stats AS (
        SELECT
            geoloc_country,
            sum(estimated_earnings_fil) as estimated_earnings_fil,
            sum(bandwidth_served_bytes) as bandwidth_served_bytes
        FROM node_country
        LEFT OUTER JOIN estimated_earnings_by_node USING (node_id)
        LEFT OUTER JOIN bandwidth_served_by_node USING (node_id)
        GROUP BY geoloc_country
    )
    -- Join estimated earnings and traffic with active node count.
    SELECT
        geoloc_country,
        active_node_count,
        estimated_earnings_fil,
        bandwidth_served_bytes
    FROM country_stats
    JOIN active_nodes USING (geoloc_country)
    ORDER BY geoloc_country -- Ordering is required for deterministic results.
) TO '/outputs/saturn_country_stats.csv';


-- For every active node return various calculated stats.
COPY (
    WITH
    -- When a node was last observed active.
    last_active AS (
        SELECT
            node_id,
            max(observed_at) AS last_active_at
        FROM saturn_node_info
        WHERE state = 'active'
        GROUP BY node_id
    ),
    -- When a node was created.
    created AS (
        SELECT
            node_id,
            any_value(created_at) AS created_at
        FROM saturn_node_creation
        GROUP BY node_id
    ),
    -- For every active node returns its last observed age (in days).
    node_age AS (
        SELECT
            node_id,
            datepart('day', last_active_at - epoch_ms(created_at)) AS age_days
        FROM last_active
        JOIN created
        USING (node_id)
    ),
    -- List all active nodes.
    active_node AS (
        SELECT DISTINCT node_id
        FROM saturn_node_info
        WHERE state = 'active'
    )
    -- Final join.
    SELECT
        node_id,
        age_days,
        coalesce(estimated_earnings_fil, 0) as estimated_earnings_fil,
        coalesce(bandwidth_served_bytes, 0) as bandwidth_served_bytes,
    FROM active_node
    JOIN node_age USING (node_id)
    LEFT OUTER JOIN estimated_earnings_by_node USING (node_id)
    LEFT OUTER JOIN bandwidth_served_by_node USING (node_id)
    ORDER BY node_id -- Ordering is required for deterministic results.
) TO '/outputs/saturn_active_node_stats.csv';


-- Count how many nodes were active at the specified point in time.
CREATE OR REPLACE MACRO active(analyzed_at) AS
(
    SELECT count(DISTINCT node_id)
    FROM saturn_node_info
    WHERE
        state = 'active' AND
        observed_at = analyzed_at
);


-- Return the number of nodes that were continiously active for the given time interval i.
CREATE OR REPLACE MACRO active_interval(analyzed_at, i) AS
(
    WITH
    -- For every active node return it's longest activity interval.
    activity AS (
        SELECT
            node_id,
            max(observed_at) - min(observed_at) AS active
        FROM saturn_node_info
        WHERE
            state = 'active' AND
            observed_at BETWEEN CAST(analyzed_at AS DATETIME) - CAST(i AS INTERVAL) AND CAST(analyzed_at AS DATETIME)
        GROUP BY node_id
    )
    -- Count how many nodes were active during time interval i.
    SELECT count(*)
    FROM activity
    WHERE active >= CAST(i AS INTERVAL)
);


-- Return the number of nodes that were continiously active
-- but didn't receive any traffic for the given time interval i.
CREATE OR REPLACE MACRO active_not_serving_interval(analyzed_at, i) AS
(
    WITH
    -- For every active node return it's longest activity interval.
    activity AS (
        SELECT
            node_id,
            max(observed_at) - min(observed_at) AS active
        FROM saturn_node_info
        WHERE
            state = 'active' AND
            observed_at BETWEEN CAST(analyzed_at AS DATETIME) - CAST(i AS INTERVAL) AND CAST(analyzed_at AS DATETIME)
        GROUP BY node_id
    ),
    -- Return nodes that were active during time interval i.
    active_interval AS (
        SELECT node_id
        FROM activity
        WHERE active >= CAST(i AS INTERVAL)
    ),
    -- For every node calculate traffic during time interval i.
    bandwidth_served AS (
        SELECT
            node_id,
            sum(bandwidth_served_bytes) as bandwidth_served_bytes
        FROM saturn_node_bandwidth_served
        WHERE
            observed_at BETWEEN CAST(analyzed_at AS DATETIME) - CAST(i AS INTERVAL) AND CAST(analyzed_at AS DATETIME)
        GROUP BY node_id
    ),
    -- For every node active during time interval i return its traffic.
    active_served AS (
        SELECT
            node_id,
            coalesce(bandwidth_served_bytes, 0) as bandwidth_served_bytes
        FROM active_interval
        LEFT OUTER JOIN bandwidth_served USING (node_id)
    )
    -- Finally, count how many nodes didn't receive any traffic.
    SELECT count(*)
    FROM active_served
    WHERE bandwidth_served_bytes = 0
);


-- Return the total number of active nodes and the number of nodes that haven't been receiving traffic over time.
-- This query is pretty heavy. There's probably a way to optimize it.'
COPY (
    SELECT
        observed_at,
        active(observed_at) as active_count,
        -- 3 minute is a magic number that ensures correct intervals.
        -- It depends on input metrics scrapping interval which is 3 minutes now.
        active_interval(observed_at, '2 hour 3 minute') AS active_2h_count,
        active_not_serving_interval(observed_at, '2 hour 3 minute') AS active_not_serving_2h_count,
        active_interval(observed_at, '6 hour 3 minute') AS active_6h_count,
        active_not_serving_interval(observed_at, '6 hour 3 minute') AS active_not_serving_6h_count,
        active_interval(observed_at, '12 hour 3 minute') AS active_12h_count,
        active_not_serving_interval(observed_at, '12 hour 3 minute') AS active_not_serving_12h_count,
        active_interval(observed_at, '24 hour 3 minute') AS active_24h_count,
        active_not_serving_interval(observed_at, '24 hour 3 minute') AS active_not_serving_24h_count,
    FROM (
        SELECT
            max(observed_at) AS observed_at
        FROM saturn_node_info
        -- Probably groupping could be replaced with some faster way to generate observation timestamps.
        GROUP by
            datepart('year', observed_at),
            datepart('month', observed_at),
            datepart('day', observed_at),
            datepart('hour', observed_at)
    )
    ORDER BY observed_at  -- Ordering is required for deterministic results.
) TO '/outputs/saturn_active_node.csv';


-- For every country return the number of active nodes over time.
COPY (
    SELECT
        max(observed_at) AS observed_at,
        geoloc_country,
        count(DISTINCT node_id) AS active_node_count
    FROM saturn_node_info
    WHERE STATE = 'active'
    GROUP BY
        datepart('year', observed_at),
        datepart('month', observed_at),
        datepart('day', observed_at),
        datepart('hour', observed_at),
        geoloc_country
    ORDER BY -- Ordering is required for deterministic results.
        observed_at,
        geoloc_country
) TO '/outputs/saturn_active_node_by_country.csv';


-- For every country return traffic over time.
COPY (
    SELECT
        observed_at,
        geoloc_country,
        sum(bandwidth_served_bytes) AS bandwidth_served_bytes
    FROM saturn_node_bandwidth_served
    JOIN node_country USING (node_id)
    GROUP BY
        observed_at,
        geoloc_country
    ORDER BY -- Ordering is required for deterministic results.
        observed_at,
        geoloc_country
) TO '/outputs/saturn_traffic_by_country.csv';


-- For every country return estimated earnings over time.
COPY (
    SELECT
        observed_at,
        geoloc_country,
        sum(estimated_earnings_fil) AS estimated_earnings_fil
    FROM saturn_node_estimated_earnings
    JOIN node_country USING (node_id)
    -- Earnings on 2023-08-01 looks abnormally high. Need to figure out this later.
    WHERE
        observed_at >= '2023-08-02'
        -- Explicitly filter out core node earnings.
        AND node_id NOT IN (
            SELECT DISTINCT node_id
            FROM saturn_node_info
            WHERE core = true
        )
    GROUP BY
        observed_at,
        geoloc_country
    ORDER BY -- Ordering is required for deterministic results.
        observed_at,
        geoloc_country
) TO '/outputs/saturn_earnings_by_country.csv';


-- Returns average response duration percentiles over time.
-- NB: Somehow this query must be the last in the file.
--     Otherwise I get parser error from DuckDB. Probably a bug.
COPY (
    WITH avg_response_duration AS (
        -- This is a simplified PIVOT syntax supported by DuckDB.
        PIVOT saturn_node_response_duration
        ON quantile
        USING avg(duration_milliseconds)
        GROUP BY observed_at
    )
    SELECT
        max(observed_at) AS observed_at,
        avg("0.01") AS p1,
        avg("0.05") AS p5,
        avg("0.5") AS p50,
        avg("0.95") AS p95,
        avg("0.99") AS p99
    FROM avg_response_duration
    GROUP BY
        datepart('year', observed_at),
        datepart('month', observed_at),
        datepart('day', observed_at),
        datepart('hour', observed_at)
    ORDER BY observed_at -- Ordering is required for deterministic results.
) TO '/outputs/saturn_response_duration.csv';
