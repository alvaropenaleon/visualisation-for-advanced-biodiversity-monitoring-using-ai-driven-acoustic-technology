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
    affiliation: '1'
    orcid: '0009-0007-9994-1909'
  - name: Paul Phan
    affiliation: '2'
  - name: Timothy Wiley
    affiliation: '1'
  - name: Ian D. Peake
    affiliation: '3'
  - name: Chi-Tsun Cheng
    affiliation: '1'
  - name: Martino E. Malerba
    affiliation: '2'
affiliations:
  - name: School of Computing Technologies, RMIT University, Melbourne, Australia
    index: 1
  - name: Centre for Nature Positive Solutions, School of Science, RMIT University, Melbourne, Australia
    index: 2
  - name: STEM Hub for Digital Innovation, RMIT University
    index: 3
date: 3 December 2025
bibliography: paper.bib
---

# Summary

Passive acoustic monitoring (PAM) involves the deployment of autonomous recorders to capture sounds in the environment, allowing scientists to continuously, and non-invasively detect vocal species. PAM, in conjunction with classifier algorithms like BirdNET [@kahl2021birdnet] and increasingly affordable recorders [@hill2018audiomoth], can generate very large volumes of timestamped detections. However, turning these CSV outputs into interpretable summaries and meaningful visualisations often still demands coding skills and careful data handling.

ChirpCheck is a containerised tool that transforms BirdNET-style CSV files into queryable time-series data with preconfigured interactive dashboards. It runs as a Docker Compose stack combining a Node-RED upload and ingestion interface [@nodered] with optional MQTT/REST inputs for near real-time ingestion from field devices [@oasis2019mqtt], PostgreSQL with TimescaleDB for time-series storage [@postgresql; @timescaledbHypertables], and Grafana dashboards for exploration [@grafana].

The dashboard panels support rapid inspection of temporal patterns and statistics alongside ingestion-health signals when streaming is enabled. This provides a fast, code-free route from raw files or live device streams to exploratory analysis and reproducible figures for ecologists, students, and land managers.

# Statement of need

BirdNET-style CSV files have emerged as a common starting point for many detection analysis workflows [@kahl2021birdnet]. In practice, however, these files still require early-stage validation before they can be analysed with confidence. Practitioners need to confirm that detections arrive consistently across sensors and time, identify gaps or delays that could bias summary statistics, and establish baseline temporal patterns before investing effort in downstream modelling.

These questions are often addressed with project-specific scripts and manual plotting, which creates barriers for non-programmers and makes results harder to reproduce across teams or deployments. The problem becomes more acute when monitoring involves many CSV files, multiple sensors, or partial uploads from field devices, because ingestion failures can silently distort interpretation unless surfaced explicitly.

ChirpCheck addresses this need by bundling ingestion, automated normalisation, diagnostics, and dashboards into a single versioned package that lowers the programming burden for non-technical users. It provides a fully local, CSV-first workflow for early-stage validation and exploratory inspection of detections. ChirpCheck standardises outputs into a queryable time-series dataset and exposes diagnostics that make ingestion problems visible, reducing the risk that gaps or delays are mistaken for ecological patterns. Designed as an accessible, reproducible stack, ChirpCheck complements specialised modelling tools by ensuring upstream data are organised, quality-checked, and easy to explore prior to further analysis.

# State of the field

Several tools support post-processing and exploration of acoustic classifier outputs. Most workflows remain script-based in R or Python because they are flexible, but they require programming expertise and leave users to assemble their own plotting and data-checking routines. BirdNET-Analyzer provides useful post-processing of BirdNET outputs, but it is oriented towards batch workflows and does not focus on rapid, dashboard-led inspection of temporal structure alongside ingestion issues that can affect interpretation [@birdnetAnalyzer].

Other commercial platforms such as Wildlife Acoustics Kaleidoscope [@kaleidoscope] and ARBIMON [@arbimon] provide polished interfaces, but they are proprietary and commonly deployed as cloud services, which can be problematic where internet access is unreliable, where data must remain local for governance reasons, or where transparent and reproducible pipelines are required. Furthermore, they also do not natively align with BirdNET’s CSV outputs, despite BirdNET being one of the most widely used AI classifiers for biodiversity monitoring. Additional open-source ecosystems such as OpenSoundscape [@opensoundscape] and the Open Ecoacoustics / Acoustic Workbench platform [@qutEcoacousticsWorkbench] provide powerful analysis and data-sharing capabilities, but they are broader libraries or portal-style systems rather than lightweight, machine-local tooling optimised for a CSV-first validation and exploration.

ChirpCheck was built to target this gap, a self-contained workflow that ingests BirdNET-style CSVs into a consistent time-series schema and provides preconfigured dashboards for rapid, reproducible inspection, including checks that surface ingestion issues that can affect interpretation without requiring custom scripting.

# Software design

ChirpCheck adopts a three-tier architecture (ingestion, storage, visualisation) that keeps the system understandable to non-specialists while remaining scalable and maintainable. This workflow prioritises CSV as the primary input format, enabling reproducible re-ingestion and straightforward comparison across datasets, with MQTT/ REST inputs following the same ingestion pathway so batch and streaming deployments share an identical storage and dashboard model.

In the **ingestion** tier, Node-RED makes parsing, validation, normalisation, and error routing explicit as editable flows rather than hidden in a bespoke service. Records are inserted in batches for throughput, and both detection and arrival times are stored per record, enabling inspection of delays, gaps, and partial uploads. The database schema is applied via versioned SQL migrations at startup, ensuring consistent deployments across machines.

At the **storage** layer, PostgreSQL with TimescaleDB stores detections in a time-partitioned hypertable optimised for fast time-series queries, with additional tables for ingestion metrics and error logs. Indexes on commonly filtered fields keep interactive exploration responsive, and continuous aggregates support efficient roll-ups when required [@freedmanBlackwoodTimescaleArch]. In the **visualisation** tier, Grafana dashboards are provisioned from version-controlled JSON so plots and filters are reproducible rather than manually configured. ChirpCheck favours a set of curated panels that answer common monitoring questions quickly, while still allowing users to export data for downstream analysis.

![Architecture diagram showing ingestion, storage, and visualisation tiers.](fig1-architecture.png)

# Research impact statement

ChirpCheck was developed within an interdisciplinary collaboration across the Schools of Computing Technologies, Engineering, and Science at RMIT University to support biodiversity monitoring teams with daily validation of BirdNET detection outputs. It has provided a consistent way to confirm uploads and streams are being ingested as expected across sensors and time ranges, display missing intervals and ingestion interruptions before they bias summaries, and produce consistent figures for internal reporting and project discussions.

Its significance is in making CSV files reproducible outside a single project, allowing others to use the same ingestion and visualisation workflow, audit the pipeline configuration, and extend it with new panels or ingestion paths without re-building the system from scratch. This supports reliable interpretation of AI detections by making data ready for exploratory inspection straightforward across users and deployments.

# Key features

ChirpCheck’s functionality is built around the practical needs of ecological monitoring:

- **From CSVs to dashboards**: UI-based import with chunked ingestion, progress feedback, and clear error reporting.
- **Query-ready storage**: detections are normalised into a consistent TimescaleDB schema for fast time-window and species-level queries.
- **Data quality and pipeline health**: arrival timestamps, throughput/latency signals, and an error log table expose missing data and ingestion problems early.
- **Exploration built in**: provisioned Grafana panels (heatmaps, summaries, comparisons) with filters and CSV export from any panel.
- **Reproducible and adaptable**: containerised stack runs offline; optional REST/MQTT ingestion supports near real-time field devices.

![Pre-provisioned hourly, daily, and weekly panels for activity, composition, and data quality, filtered by species, confidence, and date range.](fig2-dashboard.png)

# Availability

ChirpCheck is open source under the MIT licence in a public [GitHub repository](https://github.com/alvaropenaleon/visualisation-for-advanced-biodiversity-monitoring-using-ai-driven-acoustic-technology) and is available in two forms:

- **Packaged (CSV-first, recommended)**: Download the bundle, run with Docker Compose, open the upload UI, and upload BirdNET-style CSVs. Runs fully offline without needed code changes on Windows, macOS, and Linux.
- **Source (for extensibility)**: This option provides the full Docker Compose stack, including Node-RED flows, the TimescaleDB schema, and JSON-provisioned Grafana dashboards. It supports programmatic ingestion via REST or MQTT and is suited for users who want to enable streaming, add custom panels, or adjust the database schema.

# AI usage disclosure

AI tools were used only to assist with proofreading and improving clarity in project documentation (README). All architectural decisions, implementation, and technical content were created and checked by authors.

# Acknowledgements

We thank the Centre for Nature Positive Solutions and the School of Computing Technologies at RMIT, and the broader project team involved in the underlying biodiversity monitoring programmes for feedback on ecological requirements and workflow design, and acknowledge the Node-RED, TimescaleDB, and Grafana communities whose open tooling made a transparent, reproducible stack feasible. Dr Malerba thanks the support of the Australian Government through the Australian Research Council (project ID: DE220100752).

# References