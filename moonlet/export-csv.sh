#!/bin/bash

set -e

EXPORTER_PASSWORD=${EXPORTER_PASSWORD?must be set}

SCRIPT_DIR=$(dirname "$0")

# Start and end date must be in a form of YYYY-MM-DD.
START_DATE=${1}
END_DATE=${2}

YEAR=${START_DATE:0:4}
MONTH=${START_DATE:5:2}

# Use hive partitioning.
# See https://duckdb.org/docs/data/partitioning/hive_partitioning#hive-partitioning
DATA_DIR="data/inputs/year=${YEAR}/month=${MONTH}"

function curl_export {
    local METRIC_NAME=${1}
    local METRIC_FORMAT=${2}
    local CSV_HEADER=${3}

    echo "${CSV_HEADER}" > "${DATA_DIR}/${METRIC_NAME}.csv"

    curl --compressed https://victoria.moonlet.zanko.dev/api/v1/export/csv \
        -u "exporter:${EXPORTER_PASSWORD}" \
        -d "format=${METRIC_FORMAT}" \
        -d "match[]=${METRIC_NAME}" \
        -d "start=${START_DATE}T00:00:00Z" \
        -d "end=${END_DATE}T00:00:00Z" \
    >> "${DATA_DIR}/${METRIC_NAME}.csv"

    gzip "${DATA_DIR}/${METRIC_NAME}.csv"
}

function python_export {
    local METRIC_NAME=${1}
    local METRIC_QUERY=${2}
    local CSV_HEADER=${3}

    echo "${CSV_HEADER}" > "${DATA_DIR}/${METRIC_NAME}.csv"

    EXPORTER_PASSWORD="${EXPORTER_PASSWORD}" \
    python3 "${SCRIPT_DIR}/export.py" \
        "${METRIC_QUERY}" \
        "${START_DATE}T00:00:00Z" \
        "${END_DATE}T00:00:00Z" \
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

python_export 'saturn_node_bandwidth_served' \
    'increase(saturn_node_bandwidth_served_bytes_total)' \
    'observed_at,node_id,bandwidth_served_bytes'

python_export 'saturn_node_retrievals' \
    'increase(saturn_node_retrievals_total)' \
    'observed_at,node_id,retrievals'

python_export 'saturn_node_estimated_earnings' \
    'increase(saturn_node_estimated_earnings_fil_total)' \
    'observed_at,node_id,estimated_earnings_fil'
