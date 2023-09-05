FROM ubuntu:22.04

# Install required packges
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    unzip \
    wget; \
    rm -rf /var/lib/apt/lists/*

# Download and unzip DuckDB.
RUN set -eux; \
    wget https://github.com/duckdb/duckdb/releases/download/v0.8.1/duckdb_cli-linux-aarch64.zip; \
    unzip duckdb_cli-linux-aarch64.zip

ENTRYPOINT ["./duckdb"]
