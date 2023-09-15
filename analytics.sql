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

-- For every active node returns its age (in days).
COPY (
    SELECT
        node_id,
        datepart('day', observed_at - epoch_ms(created_at)) AS age_days
    FROM (
        SELECT
            node_id,
            max(observed_at) AS observed_at
        FROM saturn_node_info
        WHERE state = 'active'
        GROUP BY node_id
    )
    JOIN (
        SELECT
            node_id,
            any_value(created_at) AS created_at
        FROM saturn_node_creation
        GROUP BY node_id
    )
    USING (node_id)
    ORDER BY node_id -- Ordering is required for deterministic results.
) TO '/outputs/saturn_active_node_age.csv';

-- Returns the number of active nodes by country.
COPY (
    SELECT
        geoloc_country,
        count(DISTINCT node_id)
    FROM saturn_node_info
    WHERE state = 'active'
    GROUP BY geoloc_country
    ORDER BY geoloc_country -- Ordering is required for deterministic results.
) TO '/outputs/saturn_active_node_by_country.csv';

-- For every active node returns its approximate estimated earnings.
COPY (
    SELECT
        node_id,
        coalesce(estimated_earnings_fil, 0) as estimated_earnings_fil,
    FROM (
        SELECT DISTINCT node_id
        FROM saturn_node_info
        WHERE state = 'active'
    )
    LEFT OUTER JOIN (
        SELECT
            node_id,
            sum(estimated_earnings_fil) as estimated_earnings_fil
        FROM saturn_node_estimated_earnings
        WHERE observed_at >= '2023-08-02' -- Earnings on 2023-08-01 looks too high. Need to figure out this later.
        GROUP BY node_id
    )
    USING (node_id)
    ORDER BY node_id
) TO '/outputs/saturn_active_node_estimated_earnings.csv';

-- For every active node returns how much traffic it served.
COPY (
    SELECT
        node_id,
        coalesce(bandwidth_served_bytes, 0) as bandwidth_served_bytes,
    FROM (
        SELECT DISTINCT node_id
        FROM saturn_node_info
        WHERE state = 'active'
    )
    LEFT OUTER JOIN (
        SELECT
            node_id,
            sum(bandwidth_served_bytes) as bandwidth_served_bytes
        FROM saturn_node_bandwidth_served
        GROUP BY node_id
    )
    USING (node_id)
    ORDER BY node_id
) TO '/outputs/saturn_active_node_bandwidth_served.csv';
