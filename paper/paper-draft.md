**Target journal:**

[Journal of Open-Source Software (JOSS)](https://joss.theoj.org/)

**Authors:**

Alvaro Leon¹, Paul Phan¹, Timothy Wiley¹, Ian Peake¹, Ben Cheng¹, Martino E. Malerba²

**Keywords:**

Biodiversity monitoring; Acoustic sensors; AI classification; Time-series database; Grafana; Node-RED; MQTT; TimescaleDB

**GitHub:**

<https://github.com/alvaropenaleon/visualisation-for-advanced-biodiversity-monitoring-using-ai-driven-acoustic-technology>

**1. Title**

"ChirpCheck: A GUI Tool to visualise and explore BirdNET output files for passive acoustic monitoring"

**2. Summary *(150--300 words) WORD COUNT: 214***

Passive acoustic monitoring coupled with classifiers such as BirdNET ([Kahl et al., 2021](#Khal)) is rapidly becoming a cornerstone of ecological research, enabled by low-cost recorders deployed at big scale ([Hill et al., 2018](#Hill)). This form of monitoring produces large volumes of timestamped species detections, but turning those CSV files into trustworthy summaries and exploratory plots typically requires scripting skills and ad-hoc notebooks, which slows field feedback and makes QA difficult.

ChirpCheck is an open-source, containerised application that ingests BirdNET-style CSVs and exposes pre-provisioned, reproducible dashboards for exploration. A single Docker compose stack launches a file-upload interface in Node-RED ([Node-RED, 2025](#NodeRed)), canonical storage in PostgreSQL ([PostgreSQL, 2025](#Postgresql)) with a TimescaleDB hypertable ([Timescale Docs. Hypertables, 2025](#timescale)), and Grafana dashboards ([Grafana Labs, 2025](#Grafana)). Beyond CSV upload, an optional MQTT input ([OASIS, 2019](#Oasis)) and lightweight REST API let edge devices such as Raspberry Pi recorders publish detections directly.

Users can inspect overview statistics, time-series trends, daily and hourly heatmaps, and aligned period comparisons, while ingestion timestamps enable operational panels for latency and throughput so ecological signal can be distinguished from pipeline artefacts when streaming is enabled. The result is a short path from a pile of files, or device streams, to defensible exploratory analysis, timeseries comparisons, and reproducible figures for ecologists, students, and land managers without writing code.

**3. Statement of Need *WORD COUNT: 234***

A BirdNET classifier typically defines the CSV schema many users start from ([Kahl et al., 2021](#Khal)). BirdNET-Analyzer and similar pipelines provide code-driven post-processing but assume scripting and do not expose ingestion observability that can confound downstream ecology ([BirdNET-Analyzer, 2025](#BirdnetAnalyzer)). Existing BirdNET workflows therefore skew toward code-centric notebooks or tool-specific visualisers, with limited attention to reproducibility and data-pipeline health that addresses missing intervals or backpressure. Aggregating and interrogating dozens of files usually requires R or Python, creating a barrier for non-programmers who need rapid situational awareness like device health, shifts in calling activity, and field summaries.

Commercial workbenches such as Wildlife Acoustics Kaleidoscope ([Wildlife Acoustics, 2025](#Kaleidoscope)) and ARBIMON ([ARBIMON, 2025](#Arbimon)) offer rich UIs but are proprietary and cloud-centred, making them unfit for reproducible, offline, local open deployments. Open ecoacoustics platforms like OpenSoundscape library ([Kitzes Lab, 2023](#Kitzes)) or Open Ecoacoustics Workbench platform ([QUT Ecoacoustics, 2025](#Qut)) emphasise analysis libraries or broad data portals rather than a minimal CSV-first, machine-local workflow with ingestion QA.

These local, GUI-first deployments are valuable where data governance, offline use, or teaching contexts preclude cloud services. ChirpCheck specifically targets CSV-first, local, reproducible exploration with packaging ingestion, automated normalisation, diagnostics, and curated dashboards into a single, versioned stack. It provides low-friction detections analysis for non-programmers, and operational, analytical and tactical observability to contextualise ecological patterns. This complements existing analysers and workbenches by emphasising local reproducibility and pipeline health rather than replacing specialist modelling tools.

**4. Implementation *WORD COUNT: 114***

ChirpCheck comprises a three-tier architecture for post-classification time-series analysis:

**Ingestion (Node-RED)**. Flows that parse CSV rows, normalise fields (timestamps, species, confidence, site), batch inserts for throughput, and stamp each record with received_at/ inserted_at to expose latency and backpressure. Additionally, optional MQTT and REST endpoints support continuous data streaming or programmatic data ingest and retrieval.

**Storage (PostgreSQL/TimescaleDB).** Detections are stored in a time-partitioned hypertable indexed on timestamp; auxiliary tables capture metrics and structured errors. Indexes on common predicates support interactive queries; optional continuous aggregates power heavy roll-ups ([Freedman & Blackwood-Sewell, 2025](#NodeRed)).

**Visualisation (Grafana).** Dashboards are JSON-provisioned and use templated variables (species, confidence) for consistent drill-down workflows. Panel queries are exportable as CSV for downstream analyses.

![A diagram of data storage Description automatically generated](media/image1.jpeg){width="5.35in" height="2.7270833333333333in"}

**Figure 1**: Architecture diagram showing Ingestion, Storage, and Visualisation tiers with optional MQTT/REST inputs, a detections hypertable, and provisioned dashboards.

**5. Key Features *WORD COUNT: 124***

ChirpCheck's functionality is designed to match the practical needs of ecological monitoring while maintaining a small, maintainable code footprint:

-   CSV ingestion through file uploads with chunked parsing, live progress, and parse feedback.

-   Unified schema via canonical normalisation of time, species, confidence, and site for consistent queries/exports.

-   Observability and error auditing with per row received_at, inserted_at, latency, and throughput panels, plus a structured sensor_errors table with raw payloads and diagnostics for gap detection.

-   Accessible dashboards containing prebuilt heatmaps, data-quality, time-series, and categorical overview panels, with time-shift overlays and SQL-aligned comparisons; Species and confidence filters, per-panel information tooltips, and CSV export of panel queries.

-   Optional API /detections POST/GET endpoints.

-   Reproducible and extensible deployment through Docker Compose with versioned flows and JSON-provisioned dashboards with optional MQTT/ streaming.

![page38image38943984](media/image2.png){width="5.5710312773403325in" height="3.348837489063867in"}

**Figure 2**. Overview dashboard (Grafana). Pre-provisioned panels summarise hourly activity, daily composition, and weekly composition by species. The templated controls along the top (site, species, confidence, date range) filter all panels; each panel's query is exportable as CSV. This view supports fast exploratory analysis while keeping ingestion health visible via time-windowed selectors.

**6. Availability *WORD COUNT: 145***

ChirpCheck is open source under the MIT licence in a public [GitHub repository](https://github.com/alvaropenaleon/visualisation-for-advanced-biodiversity-monitoring-using-ai-driven-acoustic-technology) and is available in two forms:

-   **Packaged (CSV-first, recommended).** Download the bundle, run with Docker Compose, open the upload UI, and upload BirdNET-style CSVs. Runs fully offline without needed code changes on Windows, macOS, and Linux.

-   **Source (for extensibility)**. A Docker Compose stack with Node-RED flows, TimescaleDB schema, and JSON-provisioned Grafana dashboards. Supports programmatic ingest via REST and MQTT, and is intended for enabling streaming, custom panels, or schema tweaks.

Once ingested, explore the pre-provisioned Grafana dashboards (Overview, heatmaps, comparisons, data-quality). Panel queries are exportable as CSV for downstream analysis. The repository includes tagged releases, example data, CI smoke tests (stack boots and asserts the TimescaleDB hypertable), and CITATION.cff. Default ports, message schemas, screenshots, and advanced options (confidence thresholds, species filters, continuous aggregates, MQTT/REST enablement) are documented in the README and docs/.

**8. Acknowledgements *WORD COUNT: 30***

We thank colleagues and testers for feedback on ecological requirements and workflow design, and acknowledge the Node-RED, TimescaleDB, and Grafana communities whose open tooling made a transparent, reproducible stack feasible.

**9. References**

[]{#Khal .anchor}Kahl, S., Wood, C. M., Eibl, M., & Klinck, H. (2021). BirdNET: A deep learning solution for avian diversity monitoring. *Ecological Informatics, 61*, 101236. <https://doi.org/10.1016/j.ecoinf.2021.101236>

[]{#Hill .anchor}Hill, A. P., Prince, P., Piña Covarrubias, E., Doncaster, C. P., Snaddon, J. L., & Rogers, A. (2018). AudioMoth: Evaluation of a smart open acoustic device for monitoring biodiversity and the environment. *Methods in Ecology and Evolution, 9*(5), 1199--1211. <https://doi.org/10.1111/2041-210X.12955>

Docker. Docker Compose documentation. <https://docs.docker.com/compose/>

[]{#Grafana .anchor}Grafana Labs. Grafana: Open-source analytics & monitoring. <https://grafana.com/>

[]{#timescale .anchor}Timescale Documentation. Hypertables. "Creating and managing hypertables". <https://github.com/timescale/docs/blob/latest/use-timescale/hypertables/index.md>

[]{#NodeRed .anchor}Freedman, M. J., & Blackwood-Sewell, J. (2025). *Timescale Architecture for Real-Time Analytics.* Timescale, Inc. [https://assets.timescale.com/docs/downloads/Timescale_Architecture_for_Real-time_Analytics.pdf](https://assets.timescale.com/docs/downloads/Timescale_Architecture_for_Real-time_Analytics.pdf?utm_source=chatgpt.com)

Node-RED. Low-code programming for event-driven applications. <https://nodered.org/>

[]{#Oasis .anchor}OASIS. (2019). MQTT Version 5.0 Plus Errata 01: OASIS Standard. <https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html>

[]{#Postgresql .anchor}PostgreSQL Global Development Group. PostgreSQL: The world's most advanced open source relational database. <https://www.postgresql.org/>

[]{#BirdnetAnalyzer .anchor}BirdNET-Analyzer documentation and repository. [https://birdnet-team.github.io/BirdNET-Analyzer/](https://birdnet-team.github.io/BirdNET-Analyzer/?utm_source=chatgpt.com)

[]{#Kaleidoscope .anchor}Wildlife Acoustics. *Kaleidoscope Bioacoustics Sound Analysis Software.* [https://www.wildlifeacoustics.com/products/kaleidoscope](https://www.wildlifeacoustics.com/products/kaleidoscope?utm_source=chatgpt.com)

[]{#Arbimon .anchor}ARBIMON platform. [https://arbimon.org/](https://arbimon.org/?utm_source=chatgpt.com) and [https://github.com/rfcx/arbimon](https://github.com/rfcx/arbimon?utm_source=chatgpt.com)

[]{#Kitzes .anchor}Kitzes Lab. *OpenSoundscape: An open-source bioacoustics analysis package for Python.* *Methods in Ecology and Evolution.* <https://doi.org/10.1111/2041-210X.14196>

[]{#Qut .anchor}QUT Ecoacoustics. *Acoustic Workbench / Open Ecoacoustics* (open-source platform). [https://github.com/QutEcoacoustics/workbench](https://github.com/QutEcoacoustics/workbench?utm_source=chatgpt.com); ARDC project DOI: <https://doi.org/10.47486/PL050>
