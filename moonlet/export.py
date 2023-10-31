import csv
import gzip
import json
import os
import sys
from base64 import standard_b64encode
from datetime import datetime
from urllib import request

EXPORTER_USER = "exporter"
EXPORTER_PASSWORD = os.environ["EXPORTER_PASSWORD"]

API_URL = "https://victoria.moonlet.zanko.dev/api/v1/query_range"

# 60m is the best step for the metrics that this script is assumed to be working with:
# - saturn_node_bandwidth_served_bytes_total
# - saturn_node_retrievals_total
# - saturn_node_estimated_earnings_fil_total
#
# Intervals higher than 60m will result in less accurate metric values.
# Intervals lower than 60m doesn't make sense because changes
# in the exported metrics observed every hour.
QUERY_STEP = "60m"


def make_request(query, start, end):
    credentials = f"{EXPORTER_USER}:{EXPORTER_PASSWORD}".encode()
    return request.Request(
        f"{API_URL}?query={query}&step={QUERY_STEP}&start={start}&end={end}",
        headers={
            "Authorization": b"Basic " + standard_b64encode(credentials),
            "Accept-Encoding": "gzip",
        },
    )

if __name__ == "__main__":
    _, query, start, end, output_path = sys.argv

    with request.urlopen(make_request(query, start, end)) as response:
        content = gzip.decompress(response.read())
        response = json.loads(content)

        with open(output_path, "a") as f:
            w = csv.writer(f)

            for r in response["data"]["result"]:
                node_id = r["metric"]["id"]
                for ts, v in r["values"]:
                    observed_at = datetime.utcfromtimestamp(ts).isoformat()
                    w.writerow((observed_at + "Z", node_id, v))
