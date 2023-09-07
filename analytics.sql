COPY (
    SELECT observed_at, COUNT(node_id)
    FROM '/inputs/year=2023/month=8/saturn_node_info.csv.gz'
    WHERE state='active'
    GROUP BY observed_at
    ORDER BY observed_at
) TO '/outputs/saturn_active_nodes.csv';
