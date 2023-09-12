import csv
import json
import sys
from datetime import datetime
from urllib import request

API_URL = "http://localhost:8428/api/v1/query_range"

# 60m is the best step for the metrics that this script is assumed to be working with:
# - saturn_node_bandwidth_served_bytes_total
# - saturn_node_retrievals_total
# - saturn_node_estimated_earnings_fil_total
#
# Intervals higher than 60m will result in less accurate metric values.
# Intervals lower than 60m doesn't make sense because changes
# in the exported metrics observed every hour.
QUERY_STEP = "60m"


def query_url(query, start, end):
    return f"{API_URL}?query={query}&step={QUERY_STEP}&start={start}&end={end}"


if __name__ == "__main__":
    _, query, start, end, output_path = sys.argv

    with request.urlopen(query_url(query, start, end)) as response:
        response = json.loads(response.read())

        with open(output_path, "a") as f:
            w = csv.writer(f)

            for r in response["data"]["result"]:
                node_id = r["metric"]["id"]
                for ts, v in r["values"]:
                    observed_at = datetime.utcfromtimestamp(ts).isoformat()
                    w.writerow((observed_at + "Z", node_id, v))
