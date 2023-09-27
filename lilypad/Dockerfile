FROM ubuntu:22.04

# Install required packges
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    wget; \
    rm -rf /var/lib/apt/lists/*

# Download Lilypad CLI.
RUN set -eux; \
    wget https://github.com/bacalhau-project/lilypad/releases/download/v2.0.0-b7e9e04/lilypad; \
    chmod +x /lilypad

ENTRYPOINT ["/lilypad"]
