/* global Plotly:readonly */

import * as d3 from 'https://cdn.jsdelivr.net/npm/d3@7.8.5/+esm'
import 'https://cdn.plot.ly/plotly-2.26.0.min.js'

const params = new URL(window.location.href).searchParams
let year = params.get('year')
if (year === null) {
    year = '2024'
}
let month = params.get('month')
if (month === null) {
    month = '05'
}

function dataUrl (file) {
    return `outputs/year=${year}/month=${month}/${file}`
}

const PLOTLY_CONF = {
    responsive: true,
    displayModeBar: false,
    scrollZoom: false,
}

function parseActiveNode (text) {
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
        }
    })
}

function parseActiveNodeStats (text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            id: d[0],
            age_days: +d[1],
            estimated_earnings_fil: +d[2],
            bandwidth_served_bytes: +d[3],
        }
    })
}

function parseCountryStats (text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            country: d[0],
            active_node_count: +d[1],
            estimated_earnings_fil: +d[2],
            bandwidth_served_bytes: +d[3],
        }
    })
}

function parseActiveNodeByCountry (text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            country: d[1],
            active_node_count: +d[2],
        }
    })
}

function parseTrafficByCountry (text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            country: d[1],
            traffic: +d[2],
        }
    })
}

function parseEarningsByCountry (text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            country: d[1],
            earnings: +d[2],
        }
    })
}

function parseTraffic (text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            traffic: +d[1],
        }
    })
}

function parseRetrievals (text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            retrievals: +d[1],
        }
    })
}

function parseTrafficRatio (text) {
    return d3.csvParseRows(text, (d, i) => {
        return {
            date: new Date(d[0]),
            ratio: +d[1],
        }
    })
}

// Plot the number of active Saturn nodes and network traffic over time.
function plotActiveNodeAndTraffic (nodeData, TrafficData) {
    const x = []; const y = []
    nodeData.forEach((e) => {
        x.push(e.date)
        y.push(e.active_count)
    })

    const x1 = []; const y1 = []
    TrafficData.forEach((e) => {
        x1.push(e.date)
        y1.push(e.traffic)
    })

    const traces = [{
        x,
        y,
        name: 'Active nodes',
    }, {
        x: x1,
        y: y1,
        yaxis: 'y2',
        name: 'Traffic',
    }]

    const layout = {
        yaxis2: {
            overlaying: 'y',
            side: 'right',
            fixedrange: true,
            title: {
                text: 'Traffic',
            },
            tickformat: '.2~s',
            ticksuffix: 'B',
        },
        yaxis: {
            fixedrange: true,
            title: {
                text: 'Number of nodes',
            },
        },
        xaxis: {
            fixedrange: true,
        },
        hovermode: 'x unified',
        legend: {
            orientation: 'h',
        },
    }

    const element = document.getElementById('saturn-active-node')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Plot the number of network retrievals over time.
function plotRetrievals (data) {
    const x = []; const y = []
    data.forEach((e) => {
        x.push(e.date)
        y.push(e.retrievals)
    })

    const traces = [{
        x,
        y,
        type: 'bar',
    }]

    const layout = {
        yaxis: {
            fixedrange: true,
            title: {
                text: 'Number of retrievals',
            },
        },
        xaxis: {
            fixedrange: true,
        },
        hovermode: 'x unified',
        legend: {
            orientation: 'h',
        },
    }

    const element = document.getElementById('saturn-retrievals')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Plot paid network traffic ration over time.
function plotTrafficRatio (data) {
    const x = []; const y = []
    data.forEach((e) => {
        x.push(e.date)
        y.push(e.ratio)
    })

    const traces = [{
        x,
        y,
    }]

    const layout = {
        yaxis: {
            fixedrange: true,
            title: {
                text: 'Traffic ratio',
            },
            tickformat: '.0%',
        },
        xaxis: {
            fixedrange: true,
        },
        hovermode: 'x unified',
        legend: {
            orientation: 'h',
        },
    }

    const element = document.getElementById('saturn-traffic-ratio')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Plot the number of active Saturn nodes and network traffic by country over time.
function plotActiveNodeByCountry (nodeData, trafficData, earningsData) {
    let contries = new Map()
    const newTrace = () => {
        return {
            nodes: { x: [], y: [] },
            traffic: { x: [], y: [] },
            earnings: { x: [], y: [] },
        }
    }

    nodeData.forEach((e) => {
        let trace = contries.get(e.country)
        if (trace === undefined) {
            trace = newTrace()
            contries.set(e.country, trace)
        }

        trace.nodes.x.push(e.date)
        trace.nodes.y.push(e.active_node_count)
    })

    trafficData.forEach((e) => {
        let trace = contries.get(e.country)
        if (trace === undefined) {
            trace = newTrace()
            contries.set(e.country, trace)
        }

        trace.traffic.x.push(e.date)
        trace.traffic.y.push(e.traffic)
    })

    earningsData.forEach((e) => {
        let trace = contries.get(e.country)
        if (trace === undefined) {
            trace = newTrace()
            contries.set(e.country, trace)
        }

        trace.earnings.x.push(e.date)
        trace.earnings.y.push(e.earnings)
    })

    contries = new Map([...contries.entries()].sort())

    const traces = []
    const menus = {
        buttons: [],
        xanchor: 'left',
        yanchor: 'top',
        x: 0,
        y: 1.2,
    }
    const layout = {
        yaxis3: {
            side: 'left',
            domain: [0, 0.5],
            fixedrange: true,
            tickformat: '.3~f',
            ticksuffix: ' FIL',
            title: {
                text: 'Estimated earnings',
            },
        },
        yaxis2: {
            overlaying: 'y',
            side: 'right',
            domain: [0, 0.5],
            fixedrange: true,
            tickformat: '.2~s',
            ticksuffix: 'B',
            title: {
                text: 'Traffic',
            },
        },
        yaxis1: {
            side: 'left',
            domain: [0.5, 1],
            fixedrange: true,
            title: {
                text: 'Number of nodes',
            },
        },
        xaxis1: {
            fixedrange: true,
        },
        hovermode: 'x unified',
        updatemenus: [menus],
        legend: {
            orientation: 'h',
        },
    }

    const makeArgs = (x) => {
        const args = new Array(contries.size * 3)

        args.fill(false)
        args.fill(true, x * 3, x * 3 + 3)

        return ['visible', args]
    }

    let i = 0
    for (const [country, trace] of contries) {
        traces.push({
            x: trace.earnings.x,
            y: trace.earnings.y,
            xaxis: 'x1',
            yaxis: 'y3',
            visible: false,
            name: 'Earnings',
        })
        traces.push({
            x: trace.nodes.x,
            y: trace.nodes.y,
            xaxis: 'x1',
            yaxis: 'y1',
            visible: false,
            name: 'Nodes',
        })
        traces.push({
            x: trace.traffic.x,
            y: trace.traffic.y,
            xaxis: 'x1',
            yaxis: 'y2',
            visible: false,
            name: 'Traffic',
        })

        menus.buttons.push({
            method: 'restyle',
            args: makeArgs(i),
            label: country,
        })

        i++
    }

    traces[0].visible = true
    traces[1].visible = true
    traces[2].visible = true

    const element = document.getElementById('saturn-active-node-and-traffic')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Plot the percentage of active Saturn nodes that do not receive traffic.
function plotActiveNodeWithoutTraffic (data) {
    const x = []; const y2h = []; const y6h = []; const y12h = []; const y24h = []
    data.forEach((e) => {
        x.push(e.date)

        y2h.push(e.active_not_serving_2h_count / e.active_2h_count)
        y6h.push(e.active_not_serving_6h_count / e.active_6h_count)
        y12h.push(e.active_not_serving_12h_count / e.active_12h_count)
        y24h.push(e.active_not_serving_24h_count / e.active_24h_count)
    })

    const traces = [{
        x,
        y: y2h,
        name: '2 hours',
    }, {
        x,
        y: y6h,
        name: '6 hours',
    }, {
        x,
        y: y12h,
        name: '12 hours',
    }, {
        x,
        y: y24h,
        name: '1 day',
    }]

    const layout = {
        hovermode: 'x unified',
        legend: {
            orientation: 'h',
        },
        xaxis: {
            fixedrange: true,
        },
        yaxis: {
            fixedrange: true,
            title: {
                text: 'Percent of nodes',
            },
            tickformat: '.0%',
        },
    }

    const element = document.getElementById('saturn-active-node-without-traffic')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Plot Saturn active node age historgram.
function plotActiveNodeAge (data) {
    const x = data.map((e) => e.age_days)

    const traces = [{
        x,
        type: 'histogram',
    }]

    const layout = {
        hovermode: 'x unified',
        xaxis: {
            fixedrange: true,
            title: {
                text: 'Node age (days)',
            },
        },
        yaxis: {
            fixedrange: true,
            title: {
                text: 'Number of nodes',
            },
        },
    }

    const element = document.getElementById('saturn-active-node-age')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Plot correlation between node age and earnings and traffic.
function plotNodeAgeCorrelation (data) {
    const x = []; const y = []; const y1 = []

    data.forEach((e) => {
        x.push(e.age_days)
        y.push(e.estimated_earnings_fil)
        y1.push(e.bandwidth_served_bytes)
    })

    const traces = [{
        x,
        y,
        mode: 'markers',
        type: 'scatter',
        name: 'Earnings',
    }, {
        x,
        y: y1,
        yaxis: 'y2',
        mode: 'markers',
        type: 'scatter',
        name: 'Traffic',
    }]

    const layout = {
        grid: {
            rows: 2,
            columns: 1,
        },
        xaxis: {
            fixedrange: true,
            title: {
                text: 'Node age (days)',
            },
        },
        yaxis: {
            fixedrange: true,
            title: {
                text: 'Estimated earnings',
            },
            tickformat: '.3~f',
            ticksuffix: ' FIL',
        },
        xaxis2: {
            fixedrange: true,
        },
        yaxis2: {
            fixedrange: true,
            tickformat: '.2~s',
            ticksuffix: 'B',
            title: {
                text: 'Traffic',
            },
        },
        legend: {
            orientation: 'h',
        },
    }

    const element = document.getElementById('saturn-node-age-correlation')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Plot the number of active Saturn nodes on a world map.
function plotActiveNodeOnMap (data) {
    const locations = []; const z = []; const customdata = []

    data.forEach((e) => {
        locations.push(e.country)
        customdata.push(e.active_node_count)
        // Use log scale because node distribution is quite skewed in some areas.
        z.push(Math.log10(e.active_node_count))
    })

    const traces = [{
        type: 'choropleth',
        locationmode: 'country names',
        locations,
        z,
        colorscale: 'Blues',
        reversescale: true,
        customdata,
        hovertemplate: '%{customdata}<extra>%{location}</extra>',
        colorbar: {
            title: 'Number of nodes',
            tickvals: [0, 0.48, 1, 1.48, 2, 2.48, 3, 3.54],
            ticktext: ['1', '3', '10', '30', '100', '300', '1000', '3500'],
        },
    }]

    const element = document.getElementById('saturn-active-node-world')
    Plotly.newPlot(element, traces, {}, PLOTLY_CONF)
}

// Plot earnings per node, node count and traffic by country.
function plotCountryStats (data) {
    const stats = data.map((e) => {
        return {
            country: e.country,
            earnings_per_node: e.estimated_earnings_fil / e.active_node_count,
            active_node_count: e.active_node_count,
            bandwidth_served_bytes: e.bandwidth_served_bytes,
        }
    })

    // Order data by descending earnings per node.
    const sorted = Array.from(stats).sort((a, b) => {
        return b.earnings_per_node - a.earnings_per_node
    })

    const locations = []; const earnings = []; const nodeCount = []; const traffic = []
    sorted.forEach((e) => {
        locations.push(e.country)
        earnings.push(e.earnings_per_node)
        nodeCount.push(e.active_node_count)
        traffic.push(e.bandwidth_served_bytes)
    })

    locations.reverse()
    earnings.reverse()
    nodeCount.reverse()
    traffic.reverse()

    const traces = [{
        type: 'bar',
        x: earnings,
        y: locations,
        orientation: 'h',
        offsetgroup: 1,
        name: 'Earnings',
    }, {
        type: 'bar',
        x: nodeCount,
        y: locations,
        orientation: 'h',
        xaxis: 'x2',
        offsetgroup: 2,
        name: 'Nodes',
    }, {
        x: traffic,
        y: locations,
        xaxis: 'x3',
        name: 'Traffic',
    }]

    const layout = {
        xaxis: {
            side: 'top',
            domain: [0, 0.7],
            fixedrange: true,
            title: {
                text: 'Estimated earnings per node',
            },
            tickformat: '.3~f',
            ticksuffix: ' FIL',
        },
        xaxis2: {
            overlaying: 'x',
            side: 'bottom',
            domain: [0, 0.7],
            fixedrange: true,
            title: {
                text: 'Number of nodes',
            },
        },
        xaxis3: {
            side: 'top',
            domain: [0.7, 1],
            fixedrange: true,
            title: {
                text: 'Total traffic',
            },
            tickformat: '.2~s',
            ticksuffix: 'B',
        },
        barmode: 'group',
        hovermode: 'y unified',
        legend: {
            orientation: 'h',
        },
    }

    const element = document.getElementById('saturn-country-stats')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Plot earnings and traffic distribution (x percent of nodes receive y percent of traffic).
function plotActiveNodeDistribution (data) {
    let earningsTotal = 0; let bandwidthTotal = 0
    const earningsData = []; const bandwidthData = []
    data.forEach((e) => {
        const earnings = e.estimated_earnings_fil
        const bandwith = e.bandwidth_served_bytes

        earningsTotal += earnings
        bandwidthTotal += bandwith

        earningsData.push(earnings)
        bandwidthData.push(bandwith)
    })

    // Sort earnings and bandwidth in descending order.
    earningsData.sort((a, b) => {
        return b - a
    })
    bandwidthData.sort((a, b) => {
        return b - a
    })

    const x = []; const y = []
    let earningsSum = 0
    for (let i = 0; i < earningsData.length; i++) {
        const nodePercent = i / earningsData.length
        x.push(nodePercent)

        earningsSum += earningsData[i]
        const earningsPercent = earningsSum / earningsTotal
        y.push(earningsPercent)
    }

    const x1 = []; const y1 = []
    let bandwithSum = 0
    for (let i = 0; i < bandwidthData.length; i++) {
        const nodePercent = i / bandwidthData.length
        x1.push(nodePercent)

        bandwithSum += bandwidthData[i]
        const bandwidthPercent = bandwithSum / bandwidthTotal
        y1.push(bandwidthPercent)
    }

    const traces = [{
        x,
        y,
        name: 'Earnings',
    }, {
        x: x1,
        y: y1,
        name: 'Traffic',
    }]

    const layout = {
        hovermode: 'x unified',
        legend: {
            orientation: 'h',
        },
        xaxis: {
            fixedrange: true,
            title: {
                text: 'Percent of nodes',
            },
            tickformat: '.2~%',
            type: 'log',
            autorange: true,
        },
        yaxis: {
            fixedrange: true,
            tickformat: '.0%',
            type: 'log',
            autorange: true,
        },
    }

    const element = document.getElementById('saturn-active-node-distribution')
    Plotly.newPlot(element, traces, layout, PLOTLY_CONF)
}

// Concurrently download all data.
const text = await Promise.all([
    d3.text(dataUrl('saturn_active_node.csv')),
    d3.text(dataUrl('saturn_active_node_stats.csv')),
    d3.text(dataUrl('saturn_country_stats.csv')),
    d3.text(dataUrl('saturn_traffic.csv')),
    d3.text(dataUrl('saturn_active_node_by_country.csv')),
    d3.text(dataUrl('saturn_traffic_by_country.csv')),
    d3.text(dataUrl('saturn_earnings_by_country.csv')),
    d3.text(dataUrl('saturn_retrievals.csv')),
    d3.text(dataUrl('saturn_traffic_ratio.csv')),
])

const activeNodeData = parseActiveNode(text[0])
const activeNodeStatsData = parseActiveNodeStats(text[1])
const countryStatsData = parseCountryStats(text[2])
const trafficData = parseTraffic(text[3])
const activeNodeByCountryData = parseActiveNodeByCountry(text[4])
const trafficByCountryData = parseTrafficByCountry(text[5])
const earningsByCountryData = parseEarningsByCountry(text[6])
const retrievalsData = parseRetrievals(text[7])
const trafficRatioData = parseTrafficRatio(text[8])

plotActiveNodeAndTraffic(activeNodeData, trafficData)
plotRetrievals(retrievalsData)

plotActiveNodeOnMap(countryStatsData)
plotCountryStats(countryStatsData)
plotActiveNodeByCountry(activeNodeByCountryData, trafficByCountryData, earningsByCountryData)

plotActiveNodeWithoutTraffic(activeNodeData)
plotTrafficRatio(trafficRatioData)
plotActiveNodeDistribution(activeNodeStatsData)

plotActiveNodeAge(activeNodeStatsData)
plotNodeAgeCorrelation(activeNodeStatsData)
