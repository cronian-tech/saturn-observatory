CREATE TABLE IF NOT EXISTS saturn_node_info AS FROM '/inputs/saturn_node_info.csv.gz';
CREATE TABLE IF NOT EXISTS saturn_node_creation AS FROM '/inputs/saturn_node_creation_timestamp.csv.gz';

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
        t1.node_id,
        datepart('day', observed_at - epoch_ms(created_at)) AS age_days
    FROM (
        SELECT node_id, max(observed_at) AS observed_at
        FROM saturn_node_info
        WHERE state = 'active'
        GROUP BY node_id
    ) t1, (
        SELECT node_id, any_value(created_at) AS created_at
        FROM saturn_node_creation
        GROUP BY node_id
    ) t2
    WHERE t1.node_id = t2.node_id
    ORDER BY age_days -- Ordering is required for deterministic results.
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
