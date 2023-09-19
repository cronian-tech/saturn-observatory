CREATE TABLE IF NOT EXISTS saturn_node_info AS FROM '/inputs/saturn_node_info.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_creation AS FROM '/inputs/saturn_node_creation_timestamp.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_estimated_earnings AS FROM '/inputs/saturn_node_estimated_earnings.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_bandwidth_served AS FROM '/inputs/saturn_node_bandwidth_served.csv.gz';

-- Returns the number of active nodes over time.
COPY (
    SELECT
        observed_at,
        count(node_id)
    FROM saturn_node_info
    WHERE state = 'active'
    GROUP BY observed_at
    ORDER BY observed_at -- Ordering is required for deterministic results.
) TO '/outputs/saturn_active_node.csv';

-- Returns network traffic over time.
COPY (
    SELECT
        observed_at,
        sum(bandwidth_served_bytes)
    FROM saturn_node_bandwidth_served
    GROUP BY observed_at
    ORDER BY observed_at -- Ordering is required for deterministic results.
) TO '/outputs/saturn_traffic.csv';

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
WHERE observed_at >= '2023-08-02'
GROUP BY node_id;

-- Return the number of active nodes, estimated earnings and traffic by country.
COPY (
    WITH
    -- For every node return its country.
    node_country AS (
        SELECT
            node_id,
            -- There's a little chance that some nodes changed their location.
            -- But we simply ignore it by taking any known location of a node.
            any_value(geoloc_country) as geoloc_country
        FROM saturn_node_info
        GROUP BY node_id
    ),
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
