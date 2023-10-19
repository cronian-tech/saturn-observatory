# 🔭 Saturn Observatory

The goal of this project is to increase the transparency of 🪐 [Filecoin Saturn](https://saturn.tech) network – the fastest growing, community-run distributed content delivery network (CDN) for Web3.

We use historical data about the network gathered by 🌖 [Saturn Moonlet](https://github.com/31z4/saturn-moonlet) to prepare and publish analytical reports on Saturn Observatory [website](https://31z4.github.io/saturn-observatory) every month. Raw data that is used to generate the reports [is available](https://ipfs.io/ipfs/bafybeib4mvhfuly764igrqvlwknsc23xquj3sbvbjwfrwritpfwfkg4e3e) on IPFS and Filecoin.

Saturn Observatory compliments official tools like [Saturn Node Dashboard](https://dashboard.saturn.tech) and [Saturn Explorer](https://explorer.saturn.tech), aiming to provide better insights into the network state and performance. To highlight a few:

#### [Network Size & Traffic](https://31z4.github.io/saturn-observatory/#network-size-and-traffic) shows the number of Saturn nodes and network traffic over time.

<img width="931" alt="image" src="https://github.com/31z4/saturn-observatory/assets/3657959/0d89ae2b-6f8c-4227-a425-e75aa83e5737">

#### [Earnings & Traffic by Country](https://31z4.github.io/saturn-observatory/#earnings-and-traffic-by-country) can help node operators identify saturated (in terms of node count) regions and find the most advantageous geographical locations.

<img width="917" alt="image" src="https://github.com/31z4/saturn-observatory/assets/3657959/2abdeaa8-019f-46c1-bc59-23988102cb21">

#### [Nodes Without Traffic](https://31z4.github.io/saturn-observatory/#nodes-without-traffic) may highlight issues with network traffic distribution.

<img width="887" alt="image" src="https://github.com/31z4/saturn-observatory/assets/3657959/d09b73d8-b6d3-4040-98c4-fe4146d5eebb">

Head over to Saturn Observatory [website](https://31z4.github.io/saturn-observatory) to see the full report. If you're curious, you can see [how the project is made](#how-its-made).

Saturn Observatory is neither affiliated with the [Filecoin Saturn](https://github.com/filecoin-saturn) project nor the [Protocol Labs](https://protocol.ai) organization.
However, it was built during the [Open Data Hack](https://ethglobal.com/showcase/saturn-moonlet-c4583) powered by Filecoin.

## 🛠 How it's made

To create reports we export historical data about the Saturn network from a running [Saturn Moonlet](http://demo.moonlet.zanko.dev) instance into a set of [CSV](https://en.wikipedia.org/wiki/Comma-separated_values) files. We run a bunch of analytical [SQL queries](analytics.sql) against these files and output results into CSVs. Finally, we use the results to generate plots and publish them on the Saturn Observatory website.

The following is a more detailed explanation of each step.

1. Everything starts with making a snapshot of the Prometheus database on a running Saturn Moonlet instance:

        ./moonlet/export-snapshot.sh

    It will take a few minutes and the output will be the file called `snapshot.tar.gz` which we copy to a local machine.

2. Now, to convert the Prometheus snapshot into a set of CSV files we spin up a [VictoriaMetrics](https://victoriametrics.com/products/open-source/) instance and import the snapshot there.

        docker compose -f moonlet/compose.yaml up -d
        ./moonlet/import-snapshot.sh 2023-09-01 2023-10-01

    We use VictoriaMetrics because it has a convenient [API to export metrics](https://docs.victoriametrics.com/url-examples.html#apiv1exportcsv) into CSV. In the future, we may consider switching Saturn Moonlet from Prometheus to VictoriaMetrics.

3. Once the import finishes, we export metrics into CVS:

        ./moonlet/export-csv.sh 2023-09-01 2023-10-01

    This [shell script](moonlet/export-csv.sh) uses VictoriaMetrics export API for some metrics and a small [Python script](moonlet/export.py) for others. This is because for some metrics we need to run an aggregation query (e.g., `increase(saturn_node_retrievals_total)`).

4. Now we have raw CSV data that we upload and pin to IPFS and store on Filecoin using [web3.storage](https://web3.storage):

        make web3-storage-upload-inputs

    Before running this command for the first time, we need to set our web3.storage token: `make web3-storage-token`.

5. To perform the actual analysis we run a [Bacalhau]() job that uses [DuckDB]() to execute a bunch of [SQL queries](analytics.sql) on the input CSV data that we previously pinned to IPFS:

        make bacalhau-analytics cid=bafybeiarymtc6w32n2ud6w27vbhjqf2seax65l2rrfsfyucxc4gjutugni

    We wanted to use [Lilypad](https://docs.lilypadnetwork.org) to run the analysis and made a couple of PRs ([one](https://github.com/bacalhau-project/lilypad-modicum/pull/80), [two](https://github.com/bacalhau-project/lilypad-docs/pull/9), [three](https://github.com/31z4/lilypad-duckdb)) with a custom DuckDB module. But, by the time of writing the module is not yet available on Lilypad testnet. This was mostly blocked on Lilypad's team.

6. Once the Bacalhau job finishes we download its results and make sure that these results are adequate (check for outliers, empty values, compare with the previous month, etc.). Then store the results in IPFS and Filecoin using web3.storage:

        make web3-storage-upload-outputs

7. Finally, we plug the CID that we get from the previous step into `dataUrl` function of [`web/main.js`](web/main.js). We commit and push this change to the project's repo and the Saturn Observatory website gets published using GitHub pages.

8. When you open the Saturn Observatory website, CSV data from step 6 is fetched using the [Saturn browser client](https://github.com/filecoin-saturn/browser-client) and then plotted using [PlotlyJS](https://plotly.com/javascript).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
