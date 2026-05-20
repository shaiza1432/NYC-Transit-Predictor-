My Role & Contributions
I co-developed this project with my partner,Javeria Saqlain. While the original architecture lives in the main repository, my primary technical responsibilities on this codebase included:
1.Data Engineering:Developed the Apache PySpark pipeline to process 2.1M transit rows and engineered the spatial coordinates.
2.Machine Learning:Built the group-by-trip data split strategy and tuned the Random Forest Regressor using Spark MLlib.
3.DevOps:Containerized the application stack with Docker Compose and set up the GitHub Actions CI pipeline.

# NYC Transit Predictor

End-to-end **Big Data + Machine Learning** pipeline that predicts the
scheduled travel time between consecutive subway stops, using the public
**GTFS** feed from MTA New York City Transit. Built on **Apache Spark**,
**Spark MLlib (Random Forest)**, and **Streamlit**, packaged as a
single-command **Docker Compose** stack — no host installation needed.

> Project layout follows the production-data-pipeline pattern: a CLI
> entrypoint runs the full training job, the trained model is persisted
> to disk, and a multi-page Streamlit dashboard serves metrics, plots,
> and an interactive prediction interface.

---

## Table of Contents

1. [Trained-model results](#trained-model-results)
2. [Quick start](#quick-start)
3. [Architecture](#architecture)
4. [Project structure](#project-structure)
5. [Tech stack](#tech-stack)
6. [Dataset](#dataset)
7. [The ML pipeline](#the-ml-pipeline)
8. [The dashboard](#the-dashboard)
9. [Configuration](#configuration)
10. [Development workflow](#development-workflow)
11. [Testing and code quality](#testing-and-code-quality)
12. [Continuous integration](#continuous-integration)
13. [Production hardening](#production-hardening)
14. [Troubleshooting](#troubleshooting)
15. [Future enhancements](#future-enhancements)

---

## Trained-model results

Numbers below come from a **group-by-trip split** so that all stops of a
given trip live in exactly one of the train or test partitions. A naive
row-level split would put neighbouring segments of the same trip in
both partitions and inflate the score; this evaluation reflects how the
model performs on **completely unseen trips**.

### Headline scores (group-split, 80 / 20)

| Metric                         | Value           | Notes                                              |
|--------------------------------|----------------:|----------------------------------------------------|
| Test RMSE                      | **56.04 s**     | Honest — no row-level leakage                      |
| Test MAE                       | **34.50 s**     | Median absolute error ~30 s                        |
| Test R²                        | **0.4046**      | Explains ~40% of the variance in travel time       |
| Baseline RMSE (mean predictor) | 73.10 s         | A model must beat this to be useful                |
| **Lift over baseline**         | **−23.3%**      | RMSE reduction vs predicting the global mean       |
| Train RMSE                     | 56.43 s         | Used for overfit detection                         |
| **Overfit gap**                | **−0.7%**       | Test is ~0.4 s *better* than train — no overfit    |
| Feature rows                   | 563,344         | After joins + filtering                            |
| Train / test rows              | 451,387 / 111,957 | 80 / 20 by trip_id                                |
| Training time                  | 4 min 31 s      | Spark 3.5, single-machine 8-core local mode        |

### Feature importance

| Feature         | Importance |
|-----------------|-----------:|
| `stop_lat`      | 0.36       |
| `stop_lon`      | 0.34       |
| `stop_sequence` | 0.28       |
| `hour_of_day`   | 0.02       |
| `is_peak`       | 0.001      |

Spatial features dominate — different parts of the NYC subway network
have systematically different inter-stop schedules. Time-of-day adds
little once you know *where* on the network the train is, which matches
the intuition that subway dwell times are mostly determined by
infrastructure (track curvature, station spacing) rather than congestion.

### Why these numbers are honest

* **No row-level leakage.** Naive `randomSplit` would have put
  neighbouring segments of the same trip in both train and test. We
  hash on `trip_id` so every trip lands in one partition only.
* **Baseline comparison reported.** RMSE alone is meaningless without
  reference; we compute the mean-predictor RMSE on the same target and
  publish the lift.
* **Train-test gap reported.** Both train and test metrics are logged
  so you can see at a glance whether the model is over-fitting.
* **Deterministic.** `random_seed=42` everywhere; re-running the
  pipeline on the same data yields identical splits and identical
  metrics.

### Diagnostic plots (saved to `dashboard/static/plots/`)

| File | What it shows |
|---|---|
| `feature_importance.png`    | Bar chart above — spatial features dominate |
| `pred_vs_actual.png`        | Scatter; well-calibrated below 250 s, under-predicts above |
| `residuals.png`             | Residuals vs predicted; funnel shape = heteroscedasticity |
| `residual_distribution.png` | Histogram of residuals; tight peak near zero, left tail |
| `hourly_avg.png`            | Mean travel time per hour of day (post-midnight bucket visible) |

---

## Quick start

**Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows / macOS / Linux). Nothing else — no Python, no Java, no Spark installation required.

### Option A — Make / PowerShell task runner

```bash
make build        # build the Docker image (~5 min first time)
make train        # train the model end-to-end (~2-5 min)
make dashboard    # http://localhost:8501
make down         # stop everything
```

On Windows PowerShell:

```powershell
.\tasks.ps1 build
.\tasks.ps1 train
.\tasks.ps1 dashboard
```

### Option B — Raw Docker Compose

```bash
docker compose build
docker compose run --rm pipeline      # trains the model
docker compose up -d dashboard        # http://localhost:8501
docker compose down                   # stop everything
```

The dashboard hot-reloads on file changes; edit any page under
`dashboard/views/` and refresh the browser.

---

## Architecture

```
┌──────────────────┐    ┌─────────────────┐    ┌───────────────────┐
│   GTFS feed      │───▶│  Spark loader   │───▶│  Preprocessing    │
│  (CSVs in data/) │    │  (data_loader)  │    │  (feature build)  │
└──────────────────┘    └─────────────────┘    └────────┬──────────┘
                                                        │
                                                        ▼
┌──────────────────┐    ┌─────────────────┐    ┌───────────────────┐
│  Streamlit       │◀───│  Trained model  │◀───│  Spark ML Pipeline│
│  dashboard       │    │  (rf_pipeline)  │    │  RF Regressor     │
└──────────────────┘    └─────────────────┘    └───────────────────┘
        │
        ├── Metrics page   (RMSE, MAE, R²)
        ├── Predict page   (single-record inference)
        ├── Map page       (Pydeck stops visualisation)
        └── About page     (architecture, tech-stack)
```

Two Docker services share one image:

| Service     | Lifetime          | Command                       |
|-------------|-------------------|-------------------------------|
| `pipeline`  | One-shot          | `python -m dashboard.pipeline`|
| `dashboard` | Long-running      | `streamlit run dashboard/app.py` |
| `notebook`  | Dev profile only  | `jupyter notebook` (port 8888) |

---

## Project structure

```
nyc-transit-predictor/
├── dashboard/
│   ├── app.py                   # Streamlit entrypoint (theme + nav + sidebar)
│   ├── pipeline.py              # CLI training pipeline entrypoint
│   ├── views/                   # Streamlit pages (loaded by st.navigation)
│   │   ├── 0_Home.py            #   - Overview / KPIs / activity
│   │   ├── 1_Metrics.py         #   - Performance / diagnostics
│   │   ├── 2_Predict.py         #   - Predict workspace + saved scenarios
│   │   ├── 3_Map.py             #   - Stops map (Pydeck)
│   │   ├── 4_About.py           #   - Methodology (model card)
│   │   ├── 5_Health.py          #   - System health + validation
│   │   ├── 6_Pipeline.py        #   - Pipeline runs history
│   │   └── 7_Settings.py        #   - Theme + runtime defaults
│   ├── src/                     # Core library (imported by app + pipeline)
│   │   ├── config.py            #   - env-driven config (12-factor)
│   │   ├── logger.py            #   - loguru wrapper
│   │   ├── spark_session.py     #   - SparkSession builder
│   │   ├── data_loader.py       #   - GTFS reader
│   │   ├── preprocessing.py     #   - feature engineering
│   │   ├── train_model.py       #   - RF training + persistence
│   │   ├── evaluate.py          #   - metrics + diagnostic plots
│   │   ├── predict.py           #   - inference helpers
│   │   ├── retry.py             #   - generic retry decorator
│   │   ├── startup.py           #   - boot-time validation
│   │   ├── styling.py           #   - design system (themes + primitives)
│   │   └── weather.py           #   - optional weather enrichment
│   └── static/plots/            # Diagnostic plots written by the pipeline
│
├── data/raw/                    # GTFS CSV feed (~45 MB)
├── models/                      # rf_pipeline/ + metrics.json (artefacts)
├── notebooks/01_eda.ipynb       # Exploratory analysis
├── logs/                        # Rotating loguru logs
│
├── Dockerfile                   # Single image, Python 3.11 + Java 17
├── docker-compose.yml           # Three services (pipeline / dashboard / notebook)
├── .dockerignore
├── .env.example                 # Copy to .env to override defaults
├── .gitignore
├── requirements.txt
└── README.md
```

---

## Tech stack

| Layer            | Tool                                    |
|------------------|-----------------------------------------|
| Language         | Python 3.11                             |
| Distributed engine | Apache Spark 3.5 (PySpark)            |
| ML library       | Spark MLlib — RandomForestRegressor     |
| Data format      | GTFS (General Transit Feed Specification) |
| DataFrame ops    | PySpark SQL, Window functions, joins    |
| Visualisation    | Matplotlib, Pydeck, Streamlit native    |
| Dashboard        | Streamlit 1.36 (multipage)              |
| Logging          | Loguru (rotation + retention)           |
| Config           | python-dotenv + env vars                |
| Containerisation | Docker + Docker Compose                 |
| Java runtime     | OpenJDK 17 (Spark requirement)          |

---

## Dataset

Raw GTFS feed from MTA NYC Transit, shipped under `data/raw/`:

| File              | Size    | Description                                    |
|-------------------|---------|------------------------------------------------|
| `agency.txt`      | <1 KB   | Operating agency metadata                      |
| `routes.txt`      | 11 KB   | Subway lines (A, B, C, …)                      |
| `stops.txt`       | 63 KB   | All stations with lat/lon                      |
| `trips.txt`       | 1.6 MB  | Individual scheduled trips                     |
| `stop_times.txt`  | 37 MB   | Scheduled stop arrivals (the large fact table) |
| `shapes.txt`      | 5 MB    | Geographic path points                         |
| `calendar.txt`    | <1 KB   | Service days of week                           |
| `calendar_dates.txt` | <1 KB | Service exceptions                            |
| `transfers.txt`   | 8.5 KB  | Transfer rules between stops                   |
| `feed_info.txt`   | <1 KB   | Feed publisher / version                       |

The pipeline derives the training target — **`scheduled_travel_time`** —
as the seconds between consecutive `departure_seconds` values along the
same trip, using a Spark window function (`lag` over `stop_sequence`
partitioned by `trip_id`).

---

## The ML pipeline

**Entry point:** `dashboard/pipeline.py` (or `python -m dashboard.pipeline`).

| Step | Module                  | What it does |
|------|-------------------------|--------------|
| 1    | `spark_session.get_spark` | Builds SparkSession with GTFS-compatible time parsing (`ansi.enabled=false`, `legacy.timeParserPolicy=LEGACY`). |
| 2    | `data_loader.load_all`    | Reads all GTFS CSVs as Spark DataFrames. |
| 3    | `preprocessing.build_feature_table` | Normalises times, joins `stop_times × trips × routes × stops`, derives `hour_of_day`, `is_peak`, and `scheduled_travel_time`. |
| 4    | `train_model.train_model` | 80/20 split → Imputer → VectorAssembler → StandardScaler → RandomForestRegressor (`numTrees=100`, `maxDepth=10`). |
| 5    | `evaluate.*`              | Computes RMSE / MAE / R², saves four diagnostic plots. |
| 6    | `train_model.save_model` + `save_metrics` | Persists `models/rf_pipeline/` and `models/metrics.json`. |

### Features used

| Feature         | Type    | Notes                                       |
|-----------------|---------|---------------------------------------------|
| `hour_of_day`   | int     | 0 – 47 (GTFS allows post-midnight hours)    |
| `is_peak`       | binary  | 1 if 7-9 AM or 4-7 PM                       |
| `stop_sequence` | int     | Index of stop on its trip                   |
| `stop_lat`      | double  | Latitude of the *current* stop              |
| `stop_lon`      | double  | Longitude of the *current* stop             |

### Target

`scheduled_travel_time` — seconds between consecutive stops on a trip,
clipped to `(0, 3600)` to drop terminal-stop nulls and obviously bad rows.

---

## The dashboard

Four pages, all auto-discovered by Streamlit:

| Page         | Purpose                                                              |
|--------------|----------------------------------------------------------------------|
| Home         | Headline metrics + pipeline status + quick links                     |
| Metrics      | Detailed scores + four diagnostic plots (importance, residuals, …)   |
| Predict      | Interactive form — pick a real stop, hour, peak flag → instant prediction |
| Map          | Pydeck WebGL map of every stop in the feed, with name filter         |
| About        | Architecture diagram, tech stack, run instructions                   |

The Predict page caches the Spark session and the trained model
(`@st.cache_resource`) so each prediction takes well under a second
after the first call warms up the JVM.

---

## Configuration

All runtime knobs are environment variables. Copy `.env.example` to
`.env` and override what you need:

| Variable                 | Default              | Used by                |
|--------------------------|----------------------|------------------------|
| `SPARK_DRIVER_MEMORY`    | `4g`                 | SparkSession builder   |
| `SPARK_EXECUTOR_MEMORY`  | `4g`                 | SparkSession builder   |
| `SPARK_SHUFFLE_PARTITIONS` | `8`                | SparkSession builder   |
| `RF_NUM_TREES`           | `100`                | RandomForestRegressor  |
| `RF_MAX_DEPTH`           | `10`                 | RandomForestRegressor  |
| `RF_MAX_BINS`            | `64`                 | RandomForestRegressor  |
| `TEST_SIZE`              | `0.2`                | Train/test split       |
| `RANDOM_SEED`            | `42`                 | Reproducibility        |
| `LOG_LEVEL`              | `INFO`               | Loguru filter          |
| `STREAMLIT_PORT`         | `8501`               | Docker compose         |
| `WEATHER_API_KEY`        | *(empty)*            | Optional weather enrichment |

Docker Compose reads `.env` automatically — variables defined there
flow into the running containers without further plumbing.

---

## Development workflow

### Run a Jupyter notebook in Docker

```bash
docker compose --profile dev up notebook
```

Then open <http://localhost:8888>. The `notebooks/` directory is
bind-mounted, so changes persist on the host.

### Edit code with live reload

The Dockerfile bakes the project code into the image, but you can
bind-mount the source directory to get instant reload while developing:

```bash
docker compose run --rm \
  -v "${PWD}/dashboard:/app/dashboard" \
  -p 8501:8501 \
  dashboard
```

Streamlit watches the filesystem and reruns on save.

### Native (non-Docker) execution

If you'd rather run on the host directly:

```bash
python -m venv .venv
source .venv/bin/activate          # PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m dashboard.pipeline       # train
streamlit run dashboard/app.py     # serve
```

Java 17 must be on PATH for PySpark to work natively.

---

## Testing and code quality

The project ships with a complete dev tooling stack: **ruff** for linting
and formatting, **mypy** for type checking, **pytest** for tests. All are
configured in `pyproject.toml` so you get consistent behaviour locally
and in CI.

```bash
make lint                # ruff check .
make format              # ruff format .
make typecheck           # mypy dashboard
make test                # pytest -m "not slow"  (fast tests, with coverage)
make test-integration    # pytest -m "integration"
make test-all            # everything
```

The test suite covers:

| File                                | What it verifies                                              |
|-------------------------------------|---------------------------------------------------------------|
| `tests/test_preprocessing.py`       | GTFS time conversion (incl. post-midnight), feature derivation |
| `tests/test_predict.py`             | Input validation: missing fields, out-of-range values         |
| `tests/test_config.py`              | Env-var overrides actually flow through to dataclasses        |
| `tests/test_data_loader.py`         | Missing required files fail loud and early                    |
| `tests/test_pipeline_integration.py`| Train → save → load → predict round-trip on a synthetic feed  |

A session-scoped `spark` fixture in `tests/conftest.py` boots the JVM once
for the whole run, so unit tests stay fast despite hitting a real Spark
session.

---

## Continuous integration

`.github/workflows/ci.yml` runs four jobs on every push and PR:

| Job              | What it does                                              |
|------------------|-----------------------------------------------------------|
| `quality`        | ruff lint + format check, mypy, fast pytest with coverage |
| `integration`    | Slow / integration tests, in parallel with quality        |
| `docker`         | Verifies the Docker image still builds (with buildx cache)|
| `audit`          | `pip-audit` dependency vulnerability scan                 |

Concurrency control cancels in-flight runs when a new commit lands on
the same branch.

---

## Production hardening

What makes this project production-grade — not just a notebook in a
folder:

| Concern                  | How it's addressed                                              |
|--------------------------|-----------------------------------------------------------------|
| **Reproducibility**      | Pinned `requirements.txt`, fixed `random_seed`, Docker image    |
| **Observability**        | Loguru with rotating files (`logs/*.log`), structured fields    |
| **Configuration**        | 12-factor: env vars + dataclasses, `.env.example` for defaults  |
| **Idempotency**          | Pipeline can re-run safely; model overwrite-on-save             |
| **Failure handling**     | Exit codes `0/1/2/3` from pipeline, graceful UI on missing model |
| **Performance**          | Single-pass metrics, broadcast joins, MEMORY_AND_DISK caching   |
| **Input validation**     | `predict.py` validates types and ranges before Spark call       |
| **Resource cleanup**     | `cache()` ↔ `unpersist()` balanced, `spark.stop()` in finally   |
| **Security**             | No secrets in code, `.env` gitignored, pip-audit in CI          |
| **Type safety**          | Type hints + mypy enforcement                                   |
| **Style consistency**    | Ruff lint + format, CI-enforced                                 |
| **Container security**   | `tini` as PID 1, non-root user path, healthcheck                |
| **Documentation**        | README, ARCHITECTURE.md, CONTRIBUTING.md, inline docstrings     |

---

## Troubleshooting

| Symptom                                              | Likely cause / fix |
|------------------------------------------------------|--------------------|
| `Could not find a valid JDK`                         | Use the Docker workflow — host needs Java 17 otherwise. |
| Pipeline OOMs / dies                                 | Lower `SPARK_DRIVER_MEMORY` to fit free RAM, or reduce `stop_times.txt` sample size in `data_loader.py`. |
| Dashboard says “Model not yet trained”               | Run `docker compose run --rm pipeline` once. |
| Map page empty                                       | `stops.txt` not under `data/raw/`. Re-check volume mount. |
| Port `8501` already in use                           | Set `STREAMLIT_PORT=8502` in `.env`. |
| Slow first prediction in dashboard                   | JVM warm-up — subsequent predictions are sub-second thanks to the cached Spark session. |

---

## Future enhancements

- [ ] Live weather enrichment from OpenWeatherMap (skeleton in `weather.py`).
- [ ] Real-time GTFS-RT feed ingestion for actual-vs-scheduled comparison.
- [ ] Hyperparameter tuning with `CrossValidator` + `ParamGridBuilder`.
- [ ] Spark History Server in a sidecar container.
- [ ] Postgres + MLflow tracking for experiment registry.
- [ ] CI workflow that builds the image and runs a sample pipeline on every push.

---

## License

This project ships GTFS data published by MTA New York City Transit
under their public-data licence. Project source code is provided as-is
for educational and portfolio purposes.
