COPY (
    SELECT "__timestamp__:rfc3339", COUNT(id)
    FROM '/data/raw/year=2023/month=8/saturn_node_info.csv.gz'
    WHERE state='active'
    GROUP BY "__timestamp__:rfc3339"
    ORDER BY "__timestamp__:rfc3339"
) TO '/data/saturn_active_nodes.csv';
