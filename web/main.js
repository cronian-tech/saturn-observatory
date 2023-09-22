import * as d3 from "https://cdn.jsdelivr.net/npm/d3@7.8.5/+esm";
import "https://cdn.plot.ly/plotly-2.26.0.min.js";

const DATA_BASE_URL = "https://ipfs.io/ipfs/bafybeiejnkkjzuhrpyxnwgz3yfhccsao2yxudiwyczjznbshidksfru3sa/year=2023/month=8";

function parseActiveNode(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            active_count: +d[1],
            active_2h_count: +d[2],
            active_not_serving_2h_count: +d[3],
            active_6h_count: +d[4],
            active_not_serving_6h_count: +d[5],
            active_12h_count: +d[6],
            active_not_serving_12h_count: +d[7],
            active_24h_count: +d[8],
            active_not_serving_24h_count: +d[9],
        };
    });
}

function parseActiveNodeStats(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            id: d[0],
            age_days: +d[1],
            estimated_earnings_fil: +d[2],
            bandwidth_served_bytes: +d[3],
        };
    });
}

function parseCountryStats(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            country: d[0],
            active_node_count: +d[1],
            estimated_earnings_fil: +d[2],
            bandwidth_served_bytes: +d[3],
        };
    });
}

function parseActiveNodeByCountry(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            country: d[1],
            active_node_count: +d[2],
        };
    });
}

function parseTrafficByCountry(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            country: d[1],
            traffic: +d[2],
        };
    });
}

function parseEarningsByCountry(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            country: d[1],
            earnings: +d[2],
        };
    });
}

function parseTraffic(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            traffic: +d[1],
        };
    });
}

function parseRetrievals(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            retrievals: +d[1],
        };
    });
}

function parseResponseDuration(text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            p5: +d[2],
            p50: +d[3],
            p95: +d[4],
        };
    });
}

// Plot the number of active Saturn nodes and network traffic over time.
function plotActiveNodeAndTraffic(node_data, traffic_data) {
    const x = [], y = [];
    node_data.forEach((e) => {
        x.push(e.date);
        y.push(e.active_count);
    });

    const x1 = [], y1 = [];
    traffic_data.forEach((e) => {
        x1.push(e.date);
        y1.push(e.traffic);
    });

    const traces = [{
        x: x,
        y: y,
    }, {
        x: x1,
        y: y1,
        yaxis: 'y2',
    }];

    const layout = {
        yaxis2: {
            overlaying: 'y',
            side: 'right'
        }
    };

    const element = document.getElementById("saturn-active-node");
    Plotly.newPlot(element, traces, layout, { responsive: true });
}

// Plot the number of network retrievals over time.
function plotRetrievals(retrievals_data, duration_data) {
    const x = [], y = [];
    retrievals_data.forEach((e) => {
        x.push(e.date);
        y.push(e.retrievals);
    });

    const x1 = [], y5 = [], y50 = [], y95 = [];
    duration_data.forEach((e) => {
        x1.push(e.date);
        y5.push(e.p5);
        y50.push(e.p50);
        y95.push(e.p95);
    });

    const traces = [{
        x: x,
        y: y,
        type: 'bar',
        opacity: 0.5,
    }, {
        x: x1,
        y: y5,
        yaxis: 'y2',
    }, {
        x: x1,
        y: y50,
        yaxis: 'y2',
    }, {
        x: x1,
        y: y95,
        yaxis: 'y2',
    }];

    const layout = {
        yaxis2: {
            overlaying: 'y',
            side: 'right'
        },
        hovermode: 'x unified',
    };

    const element = document.getElementById("saturn-retrievals");
    Plotly.newPlot(element, traces, layout, { responsive: true });
}

// Plot the number of active Saturn nodes and network traffic by country over time.
function plotActiveNodeByCountry(node_data, traffic_data, earnings_data) {
    let contries = new Map();
    const newTrace = () => {
        return {
            nodes: { x: [], y: [] },
            traffic: { x: [], y: [] },
            earnings: { x: [], y: [] },
        };
    };

    node_data.forEach((e) => {
        let trace = contries.get(e.country);
        if (trace === undefined) {
            trace = newTrace();
            contries.set(e.country, trace);
        }

        trace.nodes.x.push(e.date);
        trace.nodes.y.push(e.active_node_count);
    });

    traffic_data.forEach((e) => {
        let trace = contries.get(e.country);
        if (trace === undefined) {
            trace = newTrace();
            contries.set(e.country, trace);
        }

        trace.traffic.x.push(e.date);
        trace.traffic.y.push(e.traffic);
    });

    earnings_data.forEach((e) => {
        let trace = contries.get(e.country);
        if (trace === undefined) {
            trace = newTrace();
            contries.set(e.country, trace);
        }

        trace.earnings.x.push(e.date);
        trace.earnings.y.push(e.earnings);
    });

    contries = new Map([...contries.entries()].sort());

    const traces = [];
    const menus = {
        buttons: [],
    };
    const layout = {
        yaxis3: {
            side: 'left',
            domain: [0, 0.5],
        },
        yaxis2: {
            overlaying: 'y',
            side: 'right',
            domain: [0, 0.5],
        },
        yaxis1: {
            side: 'left',
            domain: [0.5, 1],
        },
        hovermode: 'x unified',
        updatemenus: [menus],
    };

    const makeArgs = (x) => {
        const args = new Array(contries.size * 3);

        args.fill(false);
        args.fill(true, x * 3, x * 3 + 3);

        return ['visible', args];
    };

    let i = 0;
    for (const [country, trace] of contries) {
        traces.push({
            x: trace.earnings.x,
            y: trace.earnings.y,
            xaxis: 'x1',
            yaxis: 'y3',
            visible: false,
        });
        traces.push({
            x: trace.nodes.x,
            y: trace.nodes.y,
            xaxis: 'x1',
            yaxis: 'y1',
            visible: false,
        });
        traces.push({
            x: trace.traffic.x,
            y: trace.traffic.y,
            xaxis: 'x1',
            yaxis: 'y2',
            visible: false,
        });

        menus.buttons.push({
            method: 'restyle',
            args: makeArgs(i),
            label: country,
        });

        i++;
    }

    traces[0].visible = true;
    traces[1].visible = true;
    traces[2].visible = true;

    const element = document.getElementById("saturn-active-node-and-traffic");
    Plotly.newPlot(element, traces, layout, { responsive: true });
}

// Plot the percentage of active Saturn nodes that do not receive traffic.
function plotActiveNodeWithoutTraffic(data) {
    const x = [], y_2h = [], y_6h = [], y_12h = [], y_24h = [];
    data.forEach((e) => {
        x.push(e.date);

        if (e.active_2h_count > 0) {
            y_2h.push((e.active_not_serving_2h_count / e.active_2h_count) * 100);
        } else {
            y_2h.push(0);
        }

        if (e.active_6h_count > 0) {
            y_6h.push((e.active_not_serving_6h_count / e.active_6h_count) * 100);
        } else {
            y_6h.push(0);
        }

        if (e.active_12h_count > 0) {
            y_12h.push((e.active_not_serving_12h_count / e.active_12h_count) * 100);
        } else {
            y_12h.push(0);
        }

        if (e.active_24h_count > 0) {
            y_24h.push((e.active_not_serving_24h_count / e.active_24h_count) * 100);
        } else {
            y_24h.push(0);
        }
    });

    const traces = [{
        x: x,
        y: y_2h,
    }, {
        x: x,
        y: y_6h,
    }, {
        x: x,
        y: y_12h,
    }, {
        x: x,
        y: y_24h,
    }];

    const element = document.getElementById("saturn-active-node-without-traffic");
    Plotly.newPlot(element, traces, { responsive: true });
}

// Plot Saturn active node age historgram.
function plotActiveNodeAge(data) {
    const x = data.map((e) => e['age_days']);

    const element = document.getElementById("saturn-active-node-age");
    Plotly.newPlot(element, [{
        x: x,
        type: 'histogram',
    }], {}, { responsive: true });
}

// Plot correlation between node age and earnings and traffic.
function plotNodeAgeCorrelation(data) {
    const x = [], y = [], y1 = [];

    data.forEach((e) => {
        x.push(e['age_days']);
        y.push(e['estimated_earnings_fil']);
        y1.push(e['bandwidth_served_bytes']);
    });

    const traces = [{
        x: x,
        y: y,
        mode: 'markers',
        type: 'scatter'
    }, {
        x: x,
        y: y1,
        xaxis: 'x2',
        yaxis: 'y2',
        mode: 'markers',
        type: 'scatter'
    }];

    const layout = {
        grid: {
            rows: 1,
            columns: 2,
            pattern: 'independent',
        }
    };

    const element = document.getElementById("saturn-node-age-correlation");
    Plotly.newPlot(element, traces, layout, { responsive: true });
}

// Plot the number of active Saturn nodes by country.
function plotActiveNodeOnMap(data) {
    const locations = [], z = [];

    data.forEach((e) => {
        locations.push(e['country']);
        z.push(e['active_node_count']);
    });

    const traces = [{
        type: "choropleth",
        locationmode: "country names",
        locations: locations,
        z: z,
        colorscale: "Blues",
        reversescale: true,
    }];

    const element = document.getElementById("saturn-active-node-by-country");
    Plotly.newPlot(element, traces, {}, { responsive: true });
}

// Plot earnings per node, node count and traffic by country.
function plotCountryStats(data) {
    const stats = data.map((e) => {
        return {
            country: e.country,
            earnings_per_node: e.estimated_earnings_fil / e.active_node_count,
            active_node_count: e.active_node_count,
            bandwidth_served_bytes: e.bandwidth_served_bytes,
        }
    });

    // Order data by descending earnings per node.
    const sorted = Array.from(stats).sort((a, b) => {
        return b.earnings_per_node - a.earnings_per_node;
    });

    const locations = [], earnings = [], node_count = [], traffic = [];
    sorted.forEach((e) => {
        locations.push(e.country);
        earnings.push(e.earnings_per_node);
        node_count.push(e.active_node_count);
        traffic.push(e.bandwidth_served_bytes);
    });

    locations.reverse();
    earnings.reverse();
    node_count.reverse();
    traffic.reverse();

    const traces = [{
        type: 'bar',
        x: earnings,
        y: locations,
        orientation: 'h',
        offsetgroup: 1,
    }, {
        type: 'bar',
        x: node_count,
        y: locations,
        orientation: 'h',
        xaxis: 'x2',
        offsetgroup: 2,
    }, {
        x: traffic,
        y: locations,
        xaxis: 'x3',
    }];

    const layout = {
        xaxis: {
            side: 'top',
            domain: [0, 0.5],
        },
        xaxis2: {
            overlaying: 'x',
            side: 'bottom',
            domain: [0, 0.5],
        },
        xaxis3: {
            side: 'top',
            domain: [0.5, 1],
        },
        barmode: 'group',
        bargap: 0.5,
        hovermode: 'y unified',
    };

    const element = document.getElementById("saturn-country-stats");
    Plotly.newPlot(element, traces, layout, { responsive: true });
}

// Plot earnings and traffic distribution (x percent of nodes receive y percent of traffic).
function plotActiveNodeDistribution(data) {
    let earnings_total = 0, bandwidth_total = 0;
    const earnings_data = [], bandwidth_data = [];
    data.forEach((e) => {
        const earnings = e['estimated_earnings_fil'];
        const bandwith = e['bandwidth_served_bytes'];

        earnings_total += earnings;
        bandwidth_total += bandwith;

        earnings_data.push(earnings);
        bandwidth_data.push(bandwith);
    });

    // Sort earnings and bandwidth in descending order.
    earnings_data.sort((a, b) => {
        return b - a;
    });
    bandwidth_data.sort((a, b) => {
        return b - a;
    });

    const x = [], y = [];
    let earnings_sum = 0;
    for (let i = 0; i < earnings_data.length; i++) {
        const node_percent = (i / earnings_data.length) * 100;
        x.push(node_percent);

        earnings_sum += earnings_data[i];
        const earnings_percent = (earnings_sum / earnings_total) * 100;
        y.push(earnings_percent);
    }

    let x1 = [], y1 = [];
    let bandwith_sum = 0;
    for (let i = 0; i < bandwidth_data.length; i++) {
        const node_percent = (i / bandwidth_data.length) * 100;
        x1.push(node_percent);

        bandwith_sum += bandwidth_data[i];
        const bandwidth_percent = (bandwith_sum / bandwidth_total) * 100;
        y1.push(bandwidth_percent);
    }

    const element = document.getElementById("saturn-active-node-distribution");
    Plotly.newPlot(element, [
        { x: x, y: y },
        { x: x1, y: y1 },
    ], {}, { responsive: true });
}

// Concurrently download all data.
const text = await Promise.all([
    d3.text(DATA_BASE_URL + "/saturn_active_node.csv"),
    d3.text(DATA_BASE_URL + "/saturn_active_node_stats.csv"),
    d3.text(DATA_BASE_URL + "/saturn_country_stats.csv"),
    d3.text(DATA_BASE_URL + "/saturn_traffic.csv"),
    d3.text(DATA_BASE_URL + "/saturn_active_node_by_country.csv"),
    d3.text(DATA_BASE_URL + "/saturn_traffic_by_country.csv"),
    d3.text(DATA_BASE_URL + "/saturn_earnings_by_country.csv"),
    d3.text(DATA_BASE_URL + "/saturn_retrievals.csv"),
    d3.text(DATA_BASE_URL + "/saturn_response_duration.csv"),
]);

const active_node_data = parseActiveNode(text[0]);
const active_node_stats_data = parseActiveNodeStats(text[1]);
const country_stats_data = parseCountryStats(text[2]);
const traffic_data = parseTraffic(text[3]);
const active_node_by_country_data = parseActiveNodeByCountry(text[4]);
const traffic_by_country_data = parseTrafficByCountry(text[5]);
const earnings_by_country_data = parseEarningsByCountry(text[6]);
const retrievals_data = parseRetrievals(text[7]);
const duration_data = parseResponseDuration(text[8]);

plotActiveNodeAndTraffic(active_node_data, traffic_data);
plotActiveNodeWithoutTraffic(active_node_data);
plotActiveNodeAge(active_node_stats_data);
plotNodeAgeCorrelation(active_node_stats_data);
plotActiveNodeOnMap(country_stats_data);
plotCountryStats(country_stats_data);
plotActiveNodeDistribution(active_node_stats_data);
plotActiveNodeByCountry(active_node_by_country_data, traffic_by_country_data, earnings_by_country_data);
plotRetrievals(retrievals_data, duration_data);
