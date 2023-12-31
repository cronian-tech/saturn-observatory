CREATE TABLE IF NOT EXISTS saturn_node_info AS FROM '/inputs/saturn_node_info.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_creation AS FROM '/inputs/saturn_node_creation_timestamp.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_estimated_earnings AS FROM '/inputs/saturn_node_estimated_earnings.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_bandwidth_served AS FROM '/inputs/saturn_node_bandwidth_served.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_retrievals AS FROM '/inputs/saturn_node_retrievals.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_sent_bytes AS FROM '/inputs/saturn_node_sent_bytes.csv.gz';


-- Calculate paid network traffic over time.
CREATE TEMP VIEW paid_traffic AS
SELECT
    observed_at,
    sum(bandwidth_served_bytes) as paid_bytes
FROM saturn_node_bandwidth_served
GROUP BY observed_at;


-- Returns paid network traffic ratio over time.
COPY (
    WITH total_traffic AS (
        SELECT
            observed_at,
            sum(sent_bytes) as total_bytes
        FROM saturn_node_sent_bytes
        GROUP BY observed_at
    )
    SELECT
        observed_at,
        paid_bytes / total_bytes
    FROM total_traffic
    JOIN paid_traffic USING (observed_at)
    ORDER BY observed_at  -- Ordering is required for deterministic results.
) TO '/outputs/saturn_traffic_ratio.csv';


-- Returns network traffic over time.
COPY (
    SELECT *
    FROM paid_traffic
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
WHERE
    -- Earnings on the first day of a month are abnormally high. Need to figure out this later.
    dayofmonth(observed_at) != 1
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
        WHERE created_at != 'nan'
        GROUP BY node_id
    ),
    -- For every active node returns its last observed age (in days).
    node_age AS (
        SELECT
            node_id,
            -- Some created_at values are DOUBLE so we have to cast to BIGINT.
            datepart('day', last_active_at - epoch_ms(CAST(created_at AS BIGINT))) AS age_days
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
    WHERE
        -- Earnings on the first day of a month are abnormally high. Need to figure out this later.
        dayofmonth(observed_at) != 1
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
