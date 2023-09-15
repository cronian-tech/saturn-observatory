BACALHAU_DUCKDB_VER := 0.0.1

# Bacalhau supports only amd64 images.
bacalhau-build:
	docker build --platform linux/amd64 -t 31z4/bacalhau-duckdb:${BACALHAU_DUCKDB_VER} bacalhau

bacalhau-push:
	docker push 31z4/bacalhau-duckdb:${BACALHAU_DUCKDB_VER}

bacalhau-analytics:
	docker run -it --rm ghcr.io/bacalhau-project/bacalhau \
		docker run --input ipfs://bafybeigg47cfb6ntyplz2oypkned3jfsp26reqdmpmzfvi6aipdxlsgla4 \
		31z4/bacalhau-duckdb:${BACALHAU_DUCKDB_VER} -- \
		./duckdb -init /init.sql -echo -s $(shell printf %q "`cat analytics.sql`") db

duckdb-analytics:
	docker compose -f duckdb/compose.yaml run -i --rm \
		duckdb -echo -s $(shell printf %q "`cat analytics.sql`") db

web3-storage-upload-inputs:
	docker compose -f web3-storage/compose.yaml run -i --rm \
		w3 put data/inputs/year=2023 --name saturn-observatory-inputs-$(shell date +%Y%m%d-%H%M%S)

web3-storage-upload-outputs:
	docker compose -f web3-storage/compose.yaml run -i --rm \
		w3 put data/outputs/year=2023 --name saturn-observatory-outputs-$(shell date +%Y%m%d-%H%M%S)

web3-storage-token:
	docker compose -f web3-storage/compose.yaml run -i --rm \
		w3 token

web-serve:
	python3 -m http.server -d web
