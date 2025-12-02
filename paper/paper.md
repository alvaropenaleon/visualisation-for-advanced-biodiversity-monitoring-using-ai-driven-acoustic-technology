---
title: "ChirpCheck: A GUI tool to visualise and explore BirdNET output files for passive acoustic monitoring"
tags:
  - biodiversity monitoring
  - ecoacoustics
  - AI classification
  - time-series database
  - Grafana
  - Node-RED
  - MQTT
  - TimescaleDB
authors:
  - name: Alvaro Peña Leon
    affiliation: 1
  - name: Paul Phan
    affiliation: 2
  - name: Timothy Wiley
    affiliation: 1
  - name: Ian Peake
    affiliation: 1
  - name: Chi-Tsun Cheng
    affiliation: 1
  - name: Martino E. Malerba
    affiliation: 2
affiliations:
  - name: School of Computing Technologies, RMIT University, Melbourne, Australia
    index: 1
  - name: Centre for Nature Positive Solutions, School of Science, RMIT University, Melbourne, Australia
    index: 2
date: 2025-02-XX
bibliography: paper.bib
---

# Summary

Passive acoustic monitoring coupled with classifiers such as BirdNET [@kahl2021birdnet] is rapidly becoming a cornerstone of ecological research, enabled by low-cost recorders deployed at large scale [@hill2018audiomoth]. This form of monitoring produces large volumes of timestamped species detections, but turning those CSV files into trustworthy summaries and exploratory plots typically requires scripting skills and ad hoc notebooks, which slows field feedback and makes quality assurance difficult.

ChirpCheck is an open-source, containerised application that ingests BirdNET-style CSVs and exposes pre-provisioned, reproducible dashboards for exploration. A single Docker Compose stack launches a file-upload interface in Node-RED [@nodered], canonical storage in PostgreSQL [@postgresql] with a TimescaleDB hypertable [@timescaledbHypertables], and Grafana dashboards [@grafana]. Beyond CSV upload, an optional MQTT input [@oasis2019mqtt] and lightweight REST API let edge devices such as Raspberry Pi recorders publish detections directly.

Users can inspect overview statistics, time-series trends, daily and hourly heatmaps, and aligned period comparisons, while ingestion timestamps enable operational panels for latency and throughput so ecological signal can be distinguished from pipeline artefacts when streaming is enabled. The result is a short path from a pile of files, or device streams, to defensible exploratory analysis, time-series comparisons, and reproducible figures for ecologists, students, and land managers without writing code.

# Statement of need

A BirdNET classifier typically defines the CSV schema many users start from [@kahl2021birdnet]. BirdNET-Analyzer and similar pipelines provide code-driven post-processing but assume scripting and do not expose ingestion observability that can confound downstream ecology [@birdnetAnalyzer]. Existing BirdNET workflows therefore skew towards code-centric notebooks or tool-specific visualisers, with limited attention to reproducibility and data-pipeline health that addresses missing intervals or backpressure. Aggregating and interrogating dozens of files usually requires R or Python, creating a barrier for non-programmers who need rapid situational awareness such as device health, shifts in calling activity, and field summaries.

Commercial workbenches such as Wildlife Acoustics Kaleidoscope [@kaleidoscope] and ARBIMON [@arbimon] offer rich user interfaces but are proprietary and cloud-centred, making them unfit for reproducible, offline, local open deployments. Open ecoacoustics platforms like the OpenSoundscape library [@opensoundscape] or the Open Ecoacoustics / Acoustic Workbench platform [@qutEcoacousticsWorkbench] emphasise analysis libraries or broad data portals rather than a minimal CSV-first, machine-local workflow with ingestion quality assurance.

These local, GUI-first deployments are valuable where data governance, offline use, or teaching contexts preclude cloud services. ChirpCheck specifically targets CSV-first, local, reproducible exploration by packaging ingestion, automated normalisation, diagnostics, and curated dashboards into a single, versioned stack. It provides low-friction detections analysis for non-programmers, and operational, analytical, and tactical observability to contextualise ecological patterns. This complements existing analysers and workbenches by emphasising local reproducibility and pipeline health rather than replacing specialist modelling tools.

# Implementation

ChirpCheck comprises a three-tier architecture for post-classification time-series analysis.

## Ingestion (Node-RED)

Node-RED flows parse CSV rows, normalise fields (timestamps, species, confidence, site), batch inserts for throughput, and stamp each record with `received_at` / `inserted_at` to expose latency and backpressure. Optional MQTT and REST endpoints support continuous data streaming or programme-controlled data ingest and retrieval.

## Storage (PostgreSQL / TimescaleDB)

Detections are stored in a time-partitioned hypertable indexed on timestamp; auxiliary tables capture metrics and structured errors. Indexes on common predicates support interactive queries; optional continuous aggregates power heavy roll-ups [@freedmanBlackwoodTimescaleArch].

## Visualisation (Grafana)

Dashboards are JSON-provisioned and use templated variables (for example species and confidence) for consistent drill-down workflows. Panel queries are exportable as CSV for downstream analyses.

![Architecture diagram showing ingestion, storage, and visualisation tiers with optional MQTT/REST inputs, a detections hypertable, and provisioned dashboards.](fig1-architecture.png)

# Key features

ChirpCheck's functionality is designed to match the practical needs of ecological monitoring while maintaining a small, maintainable code footprint:

- CSV ingestion through file uploads with chunked parsing, live progress, and parse feedback.
- Unified schema via canonical normalisation of time, species, confidence, and site for consistent queries and exports.
- Observability and error auditing with per-row `received_at`, `inserted_at`, latency, and throughput panels, plus a structured `sensor_errors` table with raw payloads and diagnostics for gap detection.
- Accessible dashboards containing prebuilt heatmaps, data-quality, time-series, and categorical overview panels, with time-shift overlays and SQL-aligned comparisons; species and confidence filters, per-panel information tooltips, and CSV export of panel queries.
- Optional `/detections` POST/GET endpoints for programme-controlled ingest and retrieval.
- Reproducible and extensible deployment through Docker Compose with versioned flows and JSON-provisioned dashboards, with optional MQTT streaming.

![Overview dashboard (Grafana). Pre-provisioned panels summarise hourly activity, daily composition, and weekly composition by species. The templated controls along the top (site, species, confidence, date range) filter all panels; each panel's query is exportable as CSV. This view supports fast exploratory analysis while keeping ingestion health visible via time-windowed selectors.](fig2-dashboard.png)

# Quality control

The repository includes a continuous integration (CI) smoke test that exercises the deployed stack. A GitHub Actions workflow:

1. launches the full Docker Compose stack (with CI-specific volumes),
2. waits for Node-RED and PostgreSQL to become reachable, and
3. executes a small integration script inside the PostgreSQL container that:

   - verifies that the core tables (`sensors`, `sensor_data`, `ingestion_metrics`, `sensor_errors`) exist, and  
   - confirms that initial sensor metadata has been seeded as defined by the SQL migrations.

This test asserts that the Compose files, migrations, and database bootstrap remain consistent over time and that new changes do not silently break provisioning of the back-end schema. In addition, we validate the Node-RED ingestion flows and Grafana dashboards manually using example BirdNET-style CSV files included with the repository.

# Availability

ChirpCheck is open source under the MIT licence in a public GitHub repository:

> <https://github.com/alvaropenaleon/visualisation-for-advanced-biodiversity-monitoring-using-ai-driven-acoustic-technology>

It is available in two forms:

- **Packaged (CSV-first, recommended).** Download the bundle, run with Docker Compose, open the upload user interface, and upload BirdNET-style CSVs. It runs fully offline without code changes on Windows, macOS, and Linux.
- **Source (for extensibility).** A Docker Compose stack with Node-RED flows, TimescaleDB schema, and JSON-provisioned Grafana dashboards. This supports programme-controlled ingest via REST and MQTT, and is intended for enabling streaming, custom panels, or schema tweaks.

Once ingested, users can explore the pre-provisioned Grafana dashboards (overview, heatmaps, comparisons, data-quality). Panel queries are exportable as CSV for downstream analysis. The repository includes tagged releases, example data, CI smoke tests, and a `CITATION.cff` file. Default ports, message schemas, screenshots, and advanced options (confidence thresholds, species filters, continuous aggregates, MQTT/REST enablement) are documented in the `README`.

# Acknowledgements

We thank colleagues and testers for feedback on ecological requirements and workflow design, and acknowledge the Node-RED, TimescaleDB, and Grafana communities whose open tooling made a transparent, reproducible stack feasible.

This work was developed as part of an internal Work-Integrated Learning capstone project at RMIT University. We acknowledge the support of the Centre for Nature Positive Solutions and the School of Computing Technologies at RMIT, and the broader project team involved in the underlying biodiversity monitoring programmes.

# References
