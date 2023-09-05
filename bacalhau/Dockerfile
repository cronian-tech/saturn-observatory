FROM ubuntu:22.04

# Install required packges
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    unzip \
    wget; \
    rm -rf /var/lib/apt/lists/*

# Download and unzip DuckDB.
# Bacalhau supports only amd64 images.
RUN set -eux; \
    wget https://github.com/duckdb/duckdb/releases/download/v0.8.1/duckdb_cli-linux-amd64.zip; \
    unzip duckdb_cli-linux-amd64.zip

COPY init.sql /

ENTRYPOINT ["./duckdb",  "-init",  "/init.sql"]
