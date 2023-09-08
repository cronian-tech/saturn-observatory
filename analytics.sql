CREATE TABLE saturn_node_info AS FROM '/inputs/year=2023/month=8/saturn_node_info.csv.gz';
CREATE TABLE saturn_node_creation AS FROM '/inputs/year=2023/month=8/saturn_node_creation_timestamp.csv.gz';

COPY (
    SELECT
        observed_at,
        count(node_id)
    FROM saturn_node_info
    WHERE state = 'active'
    GROUP BY observed_at
    ORDER BY observed_at
) TO '/outputs/saturn_active_nodes.csv';

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
    ORDER BY age_days
) TO '/outputs/saturn_active_node_age.csv';
