web3-storage-upload:
	docker compose -f web3-storage/compose.yaml run -i --rm w3 put /data/raw --name saturn-observatory

web3-storage-token:
	docker compose -f web3-storage/compose.yaml run -i --rm w3 token
