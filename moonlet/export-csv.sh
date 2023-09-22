#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$0")

# Use hive partitioning.
# See https://duckdb.org/docs/data/partitioning/hive_partitioning#hive-partitioning
DATA_DIR='data/inputs/year=2023/month=8'

# This script assumes that VictoriaMetrics container is already running.
# If it's not start it with the following command:
# docker compose -f moonlet/compose.yaml up -d

function curl_export {
    local METRIC_NAME=${1}
    local METRIC_FORMAT=${2}
    local CSV_HEADER=${3}

    echo "${CSV_HEADER}" > "${DATA_DIR}/${METRIC_NAME}.csv"

    curl http://localhost:8428/api/v1/export/csv \
        -d "format=${METRIC_FORMAT}" \
        -d "match[]=${METRIC_NAME}" \
    >> "${DATA_DIR}/${METRIC_NAME}.csv"

    gzip "${DATA_DIR}/${METRIC_NAME}.csv"
}

function python_export {
    local METRIC_NAME=${1}
    local METRIC_QUERY=${2}
    local CSV_HEADER=${3}

    echo "${CSV_HEADER}" > "${DATA_DIR}/${METRIC_NAME}.csv"

    python3 "${SCRIPT_DIR}/export.py" \
        "${METRIC_QUERY}" \
        "2023-08-01T00:00:00Z" \
        "2023-09-01T00:00:00Z" \
        "${DATA_DIR}/${METRIC_NAME}.csv"

    gzip "${DATA_DIR}/${METRIC_NAME}.csv"
}

mkdir -p "${DATA_DIR}"

curl_export 'saturn_node_info' \
    '__timestamp__:rfc3339,id,state,core,ip_address,sunrise,cassini,geoloc_region,geoloc_city,geoloc_country,geoloc_country_code,sppedtest_isp,sppedtest_server_location,sppedtest_server_country' \
    'observed_at,node_id,state,core,ip_address,sunrise,cassini,geoloc_region,geoloc_city,geoloc_country,geoloc_country_code,sppedtest_isp,sppedtest_server_location,sppedtest_server_country'

curl_export 'saturn_node_creation_timestamp' \
    '__timestamp__:rfc3339,id,__value__' \
    'observed_at,node_id,created_at'

curl_export 'saturn_node_response_duration_milliseconds' \
    '__timestamp__:rfc3339,id,quantile,__value__' \
    'observed_at,node_id,quantile,duration_milliseconds'

python_export 'saturn_node_bandwidth_served' \
    'increase(saturn_node_bandwidth_served_bytes_total)' \
    'observed_at,node_id,bandwidth_served_bytes'

python_export 'saturn_node_retrievals' \
    'increase(saturn_node_retrievals_total)' \
    'observed_at,node_id,retrievals'

python_export 'saturn_node_estimated_earnings' \
    'increase(saturn_node_estimated_earnings_fil_total)' \
    'observed_at,node_id,estimated_earnings_fil'
